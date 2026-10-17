extends Node
## Lot NET-A : partie entre amis à DEUX PROCESSUS (et plus) sur cette machine. Ce test est l'hôte (arène réelle, héros au
## pilote) ; il lance de vrais clients Godot SANS « -- » (comme un ami : EdenSlash.exe --join=…), chacun avec son
## emplacement de sauvegarde (--profil=…) :
##   1. un client d'une autre version : refusé (code 2, message clair) ;
##   2. un client au pilote, 14 s de mesure : chacun voit l'autre bouger, changer d'animation, attaquer et lancer ses sorts,
##      les coups font baisser les PV, événements visuels rejoués, ping, débit < 5 Ko/s, retards mesurés ; il part
##      proprement (l'hôte voit « a quitté ») ; il n'est pas en mode test et n'écrit que dans user://instances/<nom>/ ;
##   3. un client qui reste : l'hôte ferme la partie, le client reçoit « L'hôte a fermé la partie » et quitte (code 0).
## Plus : formats des paquets, adresses, chemins par instance, et rien d'actif hors du Mode amis.
## godot --headless --path game res://tests/test_net_a.tscn

const CLIENT_SECS := 14.0
const WAIT := 150.0  # délai d'un client (démarrage lent sur une machine chargée)

var fails := 0
var arena: NetArena
var port := 0
var dir := ""
var left_reasons := {}  # case -> raison
var joined := []


func check(label: String, ok: bool) -> void:
	print(("OK    " if ok else "ÉCHEC ") + label)
	if not ok:
		fails += 1


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	port = 21000 + rng.randi() % 30000  # port au hasard : plusieurs essais en parallèle sur la machine
	dir = OS.get_user_data_dir().path_join("neta_test")
	DirAccess.make_dir_recursive_absolute(dir)
	_unit_checks()
	await _game_checks()
	_cleanup()
	print("TOUT EST OK (0 échec(s))" if fails == 0 else "ÉCHECS : %d" % fails)
	get_tree().quit(fails)


# --- sans réseau ------------------------------------------------------------------------------------
func _unit_checks() -> void:
	check("rien d'actif hors du Mode amis (NetEvents éteint)", not NetEvents.on and not NetEvents.sink.is_valid())
	check("réglage « Mode amis » éteint par défaut", Settings.DEFAULTS.net.friends == false)
	check("sans --profil, les chemins de sauvegarde ne changent pas", NetLaunch.user_path("user://profile.json") == "user://profile.json")
	NetLaunch._instance = "zz_essai"
	var p := NetLaunch.user_path("user://profile.json")
	check("--profil=zz_essai : profil dans user://instances/zz_essai/", p == "user://instances/zz_essai/profile.json")
	check("le dossier de l'instance est créé", DirAccess.dir_exists_absolute("user://instances/zz_essai"))
	NetLaunch._instance = "?"
	DirAccess.remove_absolute("user://instances/zz_essai")
	check("adresse « 100.64.0.7:25000 »", NetLaunch.parse_address("100.64.0.7:25000") == ["100.64.0.7", 25000])
	check("adresse sans port : port par défaut", NetLaunch.parse_address(" 192.168.1.20 ") == ["192.168.1.20", NetProtocol.PORT])
	check("adresse IPv6 entre crochets", NetLaunch.parse_address("[::1]:24690") == ["::1", 24690])
	check("adresse Tailscale reconnue", NetArena.is_tailscale("100.101.5.6") and not NetArena.is_tailscale("192.168.1.2"))
	# entrées
	var inp := {"seq": 77, "move": Vector3(0.6, 0, -0.8), "aim": Vector3(1.5, 0.1, -3.0), "attack": true,
		"counts": {"skill_1": 3, "dodge": 257, "jump": 1}}
	var raw := NetProtocol.encode_input(inp)
	var b := NetProtocol.reader(raw)
	check("paquet d'entrées : type", b.get_u8() == NetProtocol.INPUT)
	var back := NetProtocol.decode_input(b)
	check("paquet d'entrées : %d octets avec visée (≤ 30)" % raw.size(), raw.size() <= 30)
	check("entrées relues (numéro, attaque, compteurs)", int(back.seq) == 77 and bool(back.attack) and int(back.counts.skill_1) == 3
		and int(back.counts.dodge) == 1 and int(back.counts.skill_4) == 0)
	check("entrées relues (déplacement, visée)", (back.move as Vector3).distance_to(Vector3(0.6, 0, -0.8)) < 0.01
		and (back.aim as Vector3).distance_to(Vector3(1.5, 0.1, -3.0)) < 0.001)
	# instantanés
	var rows := [{"slot": 0, "flags": 1, "pos": Vector3(1, 2, 3), "yaw": 0.5, "anim": 4, "apos": 0.25, "aspeed": 1.0, "hp": 900.0,
		"max_hp": 1000.0, "ack": 12}, {"slot": 3, "flags": 0, "pos": Vector3(-4, 0, 7), "yaw": -2.0, "anim": 1, "apos": 0.0,
		"aspeed": 1.2, "hp": 10.0, "max_hp": 50.0, "ack": 0}]
	var snap := NetProtocol.encode_snap(12.5, rows)
	check("instantané : %d octets pour 2 héros (6 + 2 × %d)" % [snap.size(), NetProtocol.HERO_BYTES], snap.size() == 6 + 2 * NetProtocol.HERO_BYTES)
	var sb := NetProtocol.reader(snap)
	sb.get_u8()
	var s := NetProtocol.decode_snap(sb)
	check("instantané relu", absf(float(s.t) - 12.5) < 0.001 and s.heroes.has(3) and int(s.heroes[0].flags) == 1
		and (s.heroes[3].pos as Vector3).distance_to(Vector3(-4, 0, 7)) < 0.001 and int(s.heroes[0].ack) == 12)
	var hb := NetProtocol.reader(NetProtocol.hello("0.1.999", "cleric", "Léa"))
	hb.get_u8()
	var h := NetProtocol.read_hello(hb)
	check("poignée de main relue (protocole, version, classe, nom accentué)", int(h.protocol) == NetProtocol.PROTOCOL
		and h.version == "0.1.999" and h["class"] == "cleric" and h.name == "Léa")


# --- à plusieurs processus ----------------------------------------------------------------------------
func _client(tag: String, extra: Array) -> Dictionary:
	var rep := dir.path_join("client_%s.json" % tag)
	if FileAccess.file_exists(rep):
		DirAccess.remove_absolute(rep)
	var args := ["--headless", "--path", ProjectSettings.globalize_path("res://"), "res://scenes/net_arena.tscn",
		"--join=127.0.0.1:%d" % port, "--profil=neta_%s" % tag, "--net-report=" + rep] + extra
	var pid := OS.create_process(OS.get_executable_path(), args)
	print("client %s lancé (pid %d) : %s" % [tag, pid, " ".join(extra)])
	return {"pid": pid, "report": rep, "t0": Time.get_ticks_msec()}


func _wait_exit(c: Dictionary) -> int:
	while OS.is_process_running(int(c.pid)) and Time.get_ticks_msec() - int(c.t0) < WAIT * 1000.0:
		await get_tree().create_timer(0.25).timeout
	if OS.is_process_running(int(c.pid)):
		OS.kill(int(c.pid))
		return -1
	return OS.get_process_exit_code(int(c.pid))


func _read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return d if d is Dictionary else {}


func _game_checks() -> void:
	var real_before := FileAccess.file_exists("user://profile.json")
	var real_time := FileAccess.get_modified_time("user://profile.json") if real_before else 0
	arena = load("res://scenes/net_arena.tscn").instantiate()
	add_child(arena)
	await get_tree().process_frame
	check("arène : menu « Jouer ensemble » affiché sans session", arena.panel.visible and arena.panel.state == "menu" and arena.session == null)
	arena.intent.pilot = true
	arena.bind_ip = "127.0.0.1"
	arena.cid = "warrior"
	arena.panel.cid = "warrior"
	arena.start_host(port)
	check("hôte : port %d ouvert, son héros créé" % port, arena.host != null and arena.heroes.size() == 1 and NetEvents.on)
	if arena.host == null:
		return
	arena.host.left.connect(func(slot, reason, _who): left_reasons[slot] = reason)
	arena.host.joined.connect(func(slot, _c, _n): joined.append(slot))
	# 1. autre version : refusée ; 2. client au pilote (en même temps)
	var refused := _client("r", ["--net-version=0.0.1-ancienne", "--net-class=cleric"])
	var a := _client("a", ["--net-class=magician", "--net-name=Amie", "--net-pilot", "--net-secs=%d" % int(CLIENT_SECS)])
	var code_r: int = await _wait_exit(refused)
	var rep_r := _read(String(refused.report))
	check("autre version : refusée (code %d, « %s »)" % [code_r, String(rep_r.get("fin", "?"))], code_r == 2
		and String(rep_r.get("fin", "")).contains("version %s attendue" % Version.NUMBER))
	var code_a: int = await _wait_exit(a)
	check("client au pilote : fini proprement (code %d)" % code_a, code_a == 0)
	await get_tree().create_timer(1.0).timeout
	var rep := _read(String(a.report))
	check("client : rapport écrit", not rep.is_empty())
	var seen_host: Dictionary = arena._seen.get(1, {})
	check("hôte : le héros de l'amie a bougé (%.1f m)" % float(seen_host.get("m", 0.0)), float(seen_host.get("m", 0.0)) > 5.0)
	check("hôte : ses animations ont changé (%d)" % (seen_host.get("anims", {}) as Dictionary).size(), (seen_host.get("anims", {}) as Dictionary).size() >= 3)
	check("hôte : elle a attaqué ou lancé des sorts (%d)" % int(seen_host.get("actions", 0)), int(seen_host.get("actions", 0)) >= 3)
	check("hôte : des coups ont porté (%d)" % arena.host.hits, arena.host.hits >= 1)
	check("hôte : elle est partie proprement (« a quitté »)", left_reasons.get(1, -1) == NetProtocol.LEFT)
	check("hôte : son héros est retiré", not arena.heroes.has(1))
	if not rep.is_empty():
		var vus: Dictionary = rep.get("vus", {})
		var vh: Dictionary = vus.get("0", {})
		var vm: Dictionary = vus.get("1", {})
		check("client : pas en mode test (lancé sans « -- »)", rep.get("mode_test", true) == false)
		check("client : sauvegarde de son instance (%s)" % String(rep.get("profil", "")), String(rep.get("profil", "")).begins_with("user://instances/neta_a/"))
		check("client : réglages de son instance", String(rep.get("reglages", "")).begins_with("user://instances/neta_a/"))
		check("client : voit l'hôte bouger (%.1f m)" % float(vh.get("m", 0.0)), float(vh.get("m", 0.0)) > 5.0)
		check("client : voit ses animations (%d) et ses attaques (%d)" % [int(vh.get("anims", 0)), int(vh.get("actions", 0))],
			int(vh.get("anims", 0)) >= 3 and int(vh.get("actions", 0)) >= 3)
		check("client : son propre héros bouge (%.1f m)" % float(vm.get("m", 0.0)), float(vm.get("m", 0.0)) > 5.0)
		check("client : événements visuels rejoués (%d)" % int(rep.get("evenements_joues", 0)), int(rep.get("evenements_joues", 0)) >= 10)
		var down := float(rep.get("reception_ko_s", {}).get("med", 99.0))
		check("client : débit reçu %.2f Ko/s (< 5)" % down, down > 0.5 and down < 5.0)
		var up := float(rep.get("envoi_ko_s", {}).get("med", 99.0))
		check("client : débit envoyé %.2f Ko/s (< 3)" % up, up > 0.2 and up < 3.0)
		check("client : ping mesuré (%s ms)" % str(rep.get("rtt_ms", {}).get("med", "—")), int(rep.get("rtt_ms", {}).get("n", 0)) >= 3)
		var il := float(rep.get("retard_entree_ms", {}).get("med", -1.0))
		check("client : retard d'entrée %.0f ms (en local < 150)" % il, il > 0.0 and il < 150.0)
		var felt: Dictionary = rep.get("ressenti_ms", {})
		check("client : retard ressenti mesuré (%s ms, %d fois)" % [str(felt.get("med", "—")), int(felt.get("n", 0))],
			int(felt.get("n", 0)) >= 1 and float(felt.get("med", 0.0)) > 0.0)
		print("[net] mesures du client : " + JSON.stringify({"reception_ko_s": rep.get("reception_ko_s"), "envoi_ko_s": rep.get("envoi_ko_s"),
			"rtt_ms": rep.get("rtt_ms"), "retard_entree_ms": rep.get("retard_entree_ms"), "ressenti_ms": felt}))
	var hrep := arena.host.report()
	print("[net] mesures de l'hôte : " + JSON.stringify({"envoi_ko_s": hrep.envoi_ko_s, "instantane_octets": hrep.instantane_octets,
		"evenements_par_paquet": hrep.evenements_par_paquet, "ressenti_ms": NetSession.stats(arena._felt)}))
	check("hôte : instantané de 2 héros = %s octets (6 + 2 × %d)" % [str(hrep.instantane_octets.get("med", "?")), NetProtocol.HERO_BYTES],
		int(hrep.instantane_octets.get("med", 0)) == 6 + 2 * NetProtocol.HERO_BYTES)
	# 3. client qui reste : l'hôte ferme la partie
	var c := _client("c", ["--net-class=knight"])
	var t0 := Time.get_ticks_msec()
	while joined.size() < 2 and Time.get_ticks_msec() - t0 < WAIT * 1000.0 and OS.is_process_running(int(c.pid)):
		await get_tree().create_timer(0.25).timeout
	check("3e client arrivé", joined.size() >= 2)
	await get_tree().create_timer(1.5).timeout
	arena._leave()
	var code_c: int = await _wait_exit(c)
	var rep_c := _read(String(c.report))
	check("client : « %s » puis quitte (code %d)" % [String(rep_c.get("fin", "?")), code_c], code_c == 0
		and String(rep_c.get("fin", "")) == "L'hôte a fermé la partie.")
	var t1 := Time.get_ticks_msec()
	while arena.session != null and Time.get_ticks_msec() - t1 < 5000:
		await get_tree().process_frame
	check("hôte : session close, retour au menu", arena.session == null and arena.panel.state == "menu" and not NetEvents.on)
	check("vraie sauvegarde jamais écrite par les clients", FileAccess.file_exists("user://profile.json") == real_before
		and (not real_before or FileAccess.get_modified_time("user://profile.json") == real_time))
	check("la sauvegarde de l'instance est à part", FileAccess.file_exists("user://instances/neta_a/profile.json"))
	arena.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	check("arène quittée : entraînement et effets remis comme avant", not Training.active and not NetEvents.on)


func _cleanup() -> void:
	for tag in ["a", "c", "r"]:
		_rm_tree("user://instances/neta_%s" % tag)
	_rm_tree("user://neta_test")


func _rm_tree(path: String) -> void:
	var d := DirAccess.open(path)
	if d == null:
		return
	for f in d.get_files():
		d.remove(f)
	for sub in d.get_directories():
		_rm_tree(path.path_join(sub))
	DirAccess.remove_absolute(path)
