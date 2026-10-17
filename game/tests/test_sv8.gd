extends Node
## Lot S8 du Survivant (conception/survivor/R_S8.md) : paliers de difficulté I à V (règles lisibles et différentes, multiplicateurs,
## ouverture par une victoire au palier précédent dans ce mode seulement, mode dev), récompenses par palier (légendaire dès le II,
## plafonds par palier, titre du V), mode visible et jouable par tous (activité, quêtes, Guide, nouveauté), page du lobby (sélecteur,
## palier par défaut), vrai parcours lobby -> palier IV (Menace, soins, vitesse, mécanique de boss en plus) -> victoire -> palier V
## ouvert -> palier V (deux gardiens à 15:00, rage plus tôt) -> abandon -> hub intact.
## godot --headless --path game res://tests/test_sv8.tscn

const LOBBY := "res://scenes/lobby.tscn"

var fails := 0


func check(label: String, ok: bool) -> void:
	print(("OK    " if ok else "ÉCHEC ") + label)
	if not ok:
		fails += 1


func _ready() -> void:
	if name == "Sv8Driver":
		_run.call_deferred()
		return
	var d: Node = (load("res://tests/test_sv8.gd") as GDScript).new()
	d.name = "Sv8Driver"
	get_tree().root.add_child.call_deferred(d)


# --- outils ------------------------------------------------------------------------------------------------------
func _wait(secs: float) -> void:
	await get_tree().create_timer(secs, true, false, true).timeout


func _until(cond: Callable, limit: float, label := "") -> bool:
	var t := 0.0
	while t < limit:
		if cond.call():
			return true
		await _wait(0.1)
		t += 0.1
	if label != "":
		print("   (délai dépassé : %s)" % label)
	return cond.call()


func _scene() -> Node:
	return get_tree().current_scene


func _is_lobby() -> bool:
	var s := _scene()
	return s != null and s.has_method("_start_survivor")


func _is_world() -> bool:
	var s := _scene()
	return s != null and s.has_method("end_run") and "director" in s and s.director != null and "player" in s and is_instance_valid(s.player) and s.get("hud") != null


func _results() -> ResultsPanel:
	var s := _scene()
	if s == null:
		return null
	for c in s.get_children():
		if c is ResultsPanel:
			return c
	return null


func _all_text(root: Node) -> String:
	var out := ""
	for c in root.find_children("*", "Label", true, false):
		out += String(c.text) + "\n"
	for c in root.find_children("*", "Button", true, false):
		out += String(c.text) + "\n"
	return out


func _norm(v: Variant) -> String:
	return JSON.stringify(JSON.parse_string(JSON.stringify(v)), "", true)


## Empreinte du hub, sans ce que le Survivant a le droit de donner (SurvivorRewards.hub_view).
func _hub() -> String:
	var vault: Array = Profile.vault.map(func(it): return _norm(it))
	vault.sort()  # (l'ordre du coffre n'est pas une modification)
	var parts := ["vault=" + str(vault), "loadout=" + _norm(Profile.loadout), "presets=" + _norm(Profile.presets)]
	for k in Survivor.HUB_KEYS:
		parts.append("%s=%s" % [k, _norm(SurvivorRewards.hub_view(k, Profile.get(k)))])
	return "\n".join(parts)


func _hub_diff(ref: String) -> String:
	var a := ref.split("
")
	var b := _hub().split("
")
	var out: Array = []
	for i in mini(a.size(), b.size()):
		if a[i] != b[i]:
			var k := 0
			while k < mini(a[i].length(), b[i].length()) and a[i][k] == b[i][k]:
				k += 1
			out.append("%s -> %s" % [a[i].substr(maxi(k - 60, 0), 160), b[i].substr(maxi(k - 60, 0), 160)])
	return "; ".join(out)


## Une run terminée sur [param res] au palier [param tier] (avancée [param time] s, [param guardians] gardiens).
func _end(res: String, tier: int, time := 1300.0, guardians := 3) -> Dictionary:
	Survivor.start("warrior", "limestone", tier)
	SurvivorRewards.stats = {"time": time, "guardians": guardians, "arena": time >= 1200.0, "early": 0.0}
	RunJournal._time = 30.0
	Run.finish(res)
	var out := {"chests": Run.new_reward_chests().map(func(c): return String(c.type)), "last": SurvivorRewards.last.duplicate(true)}
	Profile.end_run_survival()
	return out


# --- le déroulé ----------------------------------------------------------------------------------------------------
func _run() -> void:
	Settings.reset_all()
	Profile.selected_class = "warrior"
	Profile.reset_all()
	Profile.in_run = false
	Quests.set_day("2026-10-20")
	Profile.save_profile()
	_table()
	_unlock()
	_rewards()
	_rules()
	_visible()
	await _flow()
	Quests.set_day("")
	Settings.set_v("interface", "dev_mode", false)
	print("\n%s (%d échec(s))" % ["TOUT EST OK" if fails == 0 else "ÉCHECS", fails])
	Profile.reset_all()
	get_tree().quit(1 if fails > 0 else 0)


## Les cinq paliers : chacun ajoute UNE règle lisible et différente, sans pourcentage dans le texte permanent.
func _table() -> void:
	var t: Array = Survivor.PALIERS
	var mult: Array = ModeRules.SURVIVOR.palier_mult
	check("cinq paliers, cinq multiplicateurs (%s)" % [mult], t.size() == 5 and mult.size() == 5 and is_equal_approx(float(mult[0]), 1.0))
	var up := true
	for i in range(1, 5):
		up = up and float(mult[i]) > float(mult[i - 1])
	check("multiplicateurs strictement croissants", up)
	var rules := t.map(func(x): return String(x.rule))
	var distinct := true
	for i in rules.size():
		distinct = distinct and String(rules[i]) != "" and rules.count(rules[i]) == 1 and not String(rules[i]).contains("%") and not String(t[i].tip).contains("%")
	check("une règle par palier, toutes différentes, sans pourcentage (%s)" % [rules], distinct)
	# chaque palier garde ce que le précédent avait (cumulatif) et ajoute quelque chose qui n'est pas que des PV
	var adds: Array = []
	for i in range(1, 5):
		var a: Dictionary = t[i - 1]
		var b: Dictionary = t[i]
		var keep := float(b.speed) >= float(a.speed) and (bool(b.heal_half) or not bool(a.heal_half)) and int(b.menace) >= int(a.menace) \
			and int(b.bricks) >= int(a.bricks) and (bool(b.twin) or not bool(a.twin)) and float(b.rage_at) <= float(a.rage_at)
		var new: Array = []
		for k in ["speed", "heal_half", "menace", "bricks", "twin", "rage_at"]:
			if str(a[k]) != str(b[k]):
				new.append(k)
		adds.append(new)
		check("palier %s : garde les règles du %s et en ajoute (%s)" % [Survivor.numeral(i + 1), Survivor.numeral(i), new], keep and not new.is_empty())
	check("noms et chiffres romains", Survivor.numeral(1) == "I" and Survivor.numeral(5) == "V" and String(t[4].name) != "")


## Ouverture des paliers : seulement par les victoires dans ce mode, jamais par la progression du compte.
func _unlock() -> void:
	Profile.records.erase(SurvivorRewards.KEY)
	Settings.set_v("interface", "dev_mode", false)
	check("compte neuf : palier I seul ouvert", Survivor.palier_open(1) and not Survivor.palier_open(2) and Survivor.top_palier() == 1)
	Profile.records["epochs_cleared"] = 4
	Profile.runs_won = 30
	check("la progression du compte n'ouvre rien", not Survivor.palier_open(2))
	var r := _end("defaite", 1, 1250.0, 3)
	check("défaite au palier I : le II reste fermé", not Survivor.palier_open(2) and int(r.last.opened) == 0 and SurvivorRewards.wins(1) == 0)
	r = _end("victoire", 1)
	check("victoire au palier I : le II s'ouvre, annoncé au bilan", Survivor.palier_open(2) and int(r.last.opened) == 2 and SurvivorRewards.wins(1) == 1)
	check("bilan : « Palier II ouvert ! »", ResultsScreen.survivor_notes(r.last).has("Palier II ouvert !"))
	r = _end("victoire", 1)
	check("2e victoire au palier I : comptée, rien de nouveau à annoncer", SurvivorRewards.wins(1) == 2 and int(r.last.opened) == 0)
	check("le III reste fermé tant que le II n'est pas gagné", not Survivor.palier_open(3) and Survivor.top_palier() == 2)
	r = _end("abandon", 2, 1300.0, 3)
	check("abandon au palier II : le III reste fermé", not Survivor.palier_open(3))
	r = _end("victoire", 2)
	check("victoire au palier II : le III s'ouvre", Survivor.palier_open(3) and int(r.last.opened) == 3 and Survivor.top_palier() == 3)
	Settings.set_v("interface", "dev_mode", true)
	check("mode dev : tous ouverts, le palier par défaut reste celui des victoires", Survivor.palier_open(5) and Survivor.top_palier() == 5 and Survivor.top_palier(false) == 3)
	Settings.set_v("interface", "dev_mode", false)
	# profil d'avant S8 : seule la récompense « win:1 » existe
	Profile.records[SurvivorRewards.KEY] = {"first": ["win:1"], "day": Quests.today(), "today": []}
	check("ancien profil : la récompense de victoire du palier I ouvre le II", Survivor.palier_open(2) and SurvivorRewards.wins(1) == 1)
	r = _end("victoire", 5)
	check("victoire au palier V : rien à ouvrir après", int(r.last.opened) == 0 and SurvivorRewards.wins(5) == 1)
	Profile.records.erase(SurvivorRewards.KEY)


## Récompenses par palier : coffres « première fois » par palier, légendaire au boss dès le II, titre de chaque palier.
func _rewards() -> void:
	Profile.records.erase(SurvivorRewards.KEY)
	Profile.extra_titles = []
	var insignia := Profile.insignia
	var r := _end("victoire", 1)
	check("palier I, victoire : commun, rare, mythique (%s)" % [r.chests], r.chests == ["look_common", "look_rare", "look_epic"])
	r = _end("victoire", 1)
	check("palier I, 2e victoire du jour : commun et rare du jour seulement (%s)" % [r.chests], r.chests == ["look_common", "look_rare"])
	r = _end("victoire", 3)
	check("palier III, même jour : les trois « première fois » du palier, légendaire au boss (%s)" % [r.chests], r.chests == ["look_common", "look_rare", "look_legend"])
	check("palier III : titre « %s »" % String(r.last.title), String(r.last.title) == SurvivorRewards.title_of(3) and bool(r.last.new_title))
	for p in range(2, 6):
		check("tableau du palier %s : boss vaincu = coffre légendaire" % Survivor.numeral(p), String(SurvivorRewards.board(p)[2].type) == "look_legend")
	check("titre du palier V : « Maître des survivants »", SurvivorRewards.title_of(5) == "Maître des survivants")
	check("aucune récompense de progression (insignes) dans le mode", Profile.insignia == insignia)
	Profile.records.erase(SurvivorRewards.KEY)


## Règles du palier hors monde : multiplicateurs, rage, mécaniques ajoutées, gardiens, soins (posés et retirés).
func _rules() -> void:
	var mult: Array = ModeRules.SURVIVOR.palier_mult
	for p in range(1, 6):
		Survivor.palier = p
		var m := float(mult[p - 1])
		check("palier %s : gardiens, boss et monstres × %s" % [Survivor.numeral(p), m], is_equal_approx(SurvivorDirector.final_boss_hp(), Survivor.BOSS_HP * m)
			and is_equal_approx(SurvivorDirector.guardian_hp(2), float(Survivor.GUARDIAN_HP[2]) * m)
			and is_equal_approx(float(SurvivorDirector.spawn_plan(600.0).hp_mult), Survivor.HP0 * pow(Survivor.HP_GROWTH, 10.0) * m))
	Survivor.palier = 5
	check("palier V : gardiens et boss ont le multiplicateur entier dès le départ", is_equal_approx(SurvivorDirector.final_boss_hp(), Survivor.BOSS_HP * float(mult[4]))
		and is_equal_approx(SurvivorDirector.guardian_hp(0), float(Survivor.GUARDIAN_HP[0]) * float(mult[4])))
	Survivor.palier = 1
	var hp0_1 := float(SurvivorDirector.spawn_plan(0.0).hp_mult)
	Survivor.palier = 5
	check("palier V à 0:00 : monstres comme au palier I", is_equal_approx(float(SurvivorDirector.spawn_plan(0.0).hp_mult), hp0_1))
	Survivor.palier = 4
	check("palier IV : trois gardiens", SurvivorDirector.guardian_total() == 3)
	Survivor.palier = 5
	check("palier V : quatre gardiens (deux à 15:00)", SurvivorDirector.guardian_total() == 4)
	# mécaniques ajoutées au boss : jamais une famille qu'il a déjà, toujours des briques connues
	var have: Array = [BossBricks.normalize({"type": "marks"}), BossBricks.normalize({"type": "meteors"})]
	var add := SurvivorDirector.extra_bricks(have, 2)
	var fams: Array = add.map(func(t): return BossBricks.family_of(String(t)))
	check("mécaniques ajoutées : 2, de familles absentes du boss (%s)" % [add], add.size() == 2 and not "position" in fams and not "ground" in fams
		and fams[0] != fams[1] and add.all(func(t): return BossBricks.DEFS.has(String(t))))
	check("boss sans mécanique : la première de la liste", SurvivorDirector.extra_bricks([], 1) == [Survivor.EXTRA_BRICKS[0]])
	# soins ÷ 2 du palier III : posés au lancement, retirés à la fin de la run (rien ne suit le héros ailleurs)
	Survivor.start("warrior", "limestone", 3)
	check("palier III : soins reçus ÷ 2 pendant la run", ModeRules.modifiers.has("heal_half") and is_equal_approx(float(Modifiers.apply("heal_mult", 100.0, ModeRules.modifiers)), 50.0))
	SurvivorRewards.stats = {"time": 30.0, "guardians": 0, "arena": false, "early": 0.0}
	Run.finish("abandon")
	Profile.end_run_survival()
	check("fin de run : plus aucun modificateur", ModeRules.modifiers.is_empty())
	Survivor.start("warrior", "limestone", 2)
	check("palier II : soins normaux", ModeRules.modifiers.is_empty())
	Run.finish("abandon")
	Profile.end_run_survival()
	Survivor.palier = 1
	Profile.records.erase(SurvivorRewards.KEY)


## Le mode est visible et jouable par tous dès le départ.
func _visible() -> void:
	Settings.set_v("interface", "dev_mode", false)
	var a := Activities.get_def("survivor")
	check("Survivor.READY : visible hors mode dev", Survivor.READY and Survivor.visible() and not Activities.hidden(a))
	check("activité sans verrou, rangée Aventure, 2e après la Survie", not a.has("unlock") and String(a.row) == "adventure"
		and Activities.LIST.filter(func(x): return String(x.row) == "adventure")[1].id == "survivor")
	check("illustration propre au mode (différente de la Survie)", String(a.get("img", a.id)) == "survivor" and ResourceLoader.exists(Activities.IMG % "survivor"))  # (« img » facultatif depuis ILL-2)
	check("quêtes du Survivant tirables (porte « survivor » ouverte)", QuestPool.gate_ok("survivor"))
	var blocks: Array = Guide.blocks_for("modes")
	var b: Array = blocks.filter(func(x): return String(x.id) == "mode_survivor")
	check("Guide, chapitre Modes : le Survivant, 3-4 lignes", b.size() == 1 and String(b[0].text).count("\n") >= 2 and String(b[0].text).count("\n") <= 3)
	var card: Dictionary = Tutorial.CARDS.get("survivor", {})
	check("nouveauté « Survivant » au chapitre Modes, publiée avec cette version", not card.is_empty() and String(card.chapter) == "modes" and bool(card.get("news", true))
		and Tutorial._vkey(String(card.version)) <= Tutorial._vkey(Version.NUMBER))
	for txt in [a.name, a.sub, a.desc, String(Guide.ROLES.survivor), String(card.short)] + card.lines:
		if String(txt).contains("Eden") or String(txt).contains("%"):
			check("texte sans « Eden » ni pourcentage : %s" % txt, false)


## Le vrai parcours : lobby (sélecteur, palier par défaut) -> palier IV -> victoire -> V ouvert -> palier V -> abandon.
func _flow() -> void:
	Settings.set_v("interface", "dev_mode", false)
	Quests.set_day("2026-10-25")
	Profile.records[SurvivorRewards.KEY] = {"wins": {"1": 1, "2": 1, "3": 1}, "first": [], "day": "", "today": []}
	Profile.save_profile()
	SurvivorRewards.reset()  # (comme au lancement du jeu : aucune run jouée dans la session)
	get_tree().change_scene_to_file.call_deferred(LOBBY)
	check("lobby chargé", await _until(_is_lobby, 40.0, "lobby"))
	await _wait(0.8)
	var hub := _hub()  # (après le lobby : il range la panoplie de départ d'un compte neuf)
	var lobby := _scene()
	lobby._sv_palier = 0
	lobby._show_menu("survivor")
	var txt := _all_text(lobby._sub)
	check("page du mode : section Palier, I à III ouverts, IV choisi par défaut, V grisé", txt.contains("Palier") and txt.contains("III\n")
		and lobby._sv_palier == 4 and txt.contains(String(Survivor.PALIERS[3].rule)))
	# (lot ICO-1 : le cadenas est un pictogramme posé par Ico.lock, plus un « 🔒 » dans le texte)
	var locked: Array = lobby._sub.find_children("*", "Button", true, false).filter(func(x): return x.text == "V")
	check("palier V : bouton grisé avec sa condition", locked.size() == 1 and locked[0].disabled and String(locked[0].tooltip_text).contains("IV"))
	var b2: Array = lobby._sub.find_children("*", "Button", true, false).filter(func(x): return x.text == "II")
	if not b2.is_empty():
		b2[0].pressed.emit()
	check("clic sur II : palier choisi, ses coffres affichés", lobby._sv_palier == 2 and _all_text(lobby._sub).contains("Monstres plus rapides"))
	lobby._sv_palier = 4
	lobby._sv_zone = "limestone"
	lobby._show_menu("survivor")
	lobby._start_survivor()
	check("monde du palier IV chargé", await _until(_is_world, 90.0, "monde"))
	var w := _scene()
	var d: RunDirector = w.director
	check("palier IV en cours", Survivor.active and Survivor.palier == 4 and d.sv != null)
	check("palier IV : Menace 2 dès le départ, soins ÷ 2", Menace.level == 2 and ModeRules.modifiers.has("heal_half"))
	if await _until(func(): return w.cards.is_open(), 30.0, "choix de départ"):
		w.cards._opened_at -= CardPicker.CONFIRM_DELAY_MS
		w.cards._choose(0)
	w.player.autoplay = true
	await _wait(1.0)
	var mon := Monster.new()
	mon.move_speed = 4.0
	mon.max_hp = 100.0
	mon.atk = 10.0
	d.sv.scale_monster(mon, false)
	check("palier IV : monstres plus rapides (4 -> %.2f)" % mon.move_speed, is_equal_approx(mon.move_speed, 4.0 * float(Survivor.PALIERS[3].speed)))
	mon.free()
	check("palier IV : rage du boss à 4:00", is_equal_approx(d.sv.boss_rage_at(), 240.0))
	# l'arène : le boss gagne une mécanique d'une famille qu'il n'a pas
	w.player.dev_invincible = true
	d.time = 1199.8
	check("20:00 : arène", await _until(func(): return d.state == "boss" and is_instance_valid(d._boss), 15.0, "arène"))
	await _wait(0.6)
	var boss: Monster = d._boss
	var types: Array = boss.brain.bricks.map(func(br): return String(br.type)) if boss and boss.brain else []
	var extra := types.filter(func(t): return t in Survivor.EXTRA_BRICKS)
	check("palier IV : une mécanique de boss en plus (%s)" % [types], extra.size() >= 1 and boss.brain.bricks.size() == boss.brain._brick_t.size())
	boss.take_damage(boss.max_hp * 10.0 + 1e9, w.player)
	check("boss vaincu : bilan", await _until(func(): return _results() != null, 25.0, "bilan"))
	var panel := _results()
	await _wait(ResultsPanel.LOCK_SECS + 1.0)
	check("bilan : « Palier V ouvert ! » et le titre du palier IV", _all_text(panel).contains("Palier V ouvert") and _all_text(panel).contains(SurvivorRewards.title_of(4)))
	check("après la run : modificateurs retirés, V ouvert", ModeRules.modifiers.is_empty() and Survivor.palier_open(5) and not Survivor.active)
	check("hub identique après la victoire " + _hub_diff(hub), _hub() == hub)
	panel.buttons[panel.buttons.size() - 1].pressed.emit()
	check("retour au lobby", await _until(_is_lobby, 40.0, "lobby"))
	await _wait(0.8)
	lobby = _scene()
	lobby._sv_palier = 0
	lobby._show_menu("survivor")
	check("retour du bilan : le palier joué (IV) reste choisi, plus de cadenas", lobby._sv_palier == 4 and not _all_text(lobby._sub).contains("🔒"))
	var b5: Array = lobby._sub.find_children("*", "Button", true, false).filter(func(x): return x.text == "V")
	if not b5.is_empty():
		b5[0].pressed.emit()
	check("clic sur V : palier V choisi", lobby._sv_palier == 5)
	lobby._sv_zone = "limestone"
	lobby._start_survivor()
	check("monde du palier V chargé", await _until(_is_world, 90.0, "monde V"))
	w = _scene()
	d = w.director
	if await _until(func(): return w.cards.is_open(), 30.0, "choix de départ V"):
		w.cards._opened_at -= CardPicker.CONFIRM_DELAY_MS
		w.cards._choose(0)
	w.player.autoplay = true
	w.player.dev_invincible = true
	check("palier V : rage du boss après 3:00, une résurrection", is_equal_approx(d.sv.boss_rage_at(), 180.0) and w.revives_left == 1)
	d.time = 899.6
	check("palier V : deux gardiens surgissent à 15:00", await _until(func(): return d.sv.guardians.filter(func(e): return int(e.n) == 2).size() == 2, 6.0, "gardiens jumeaux"))
	check("HUD : quatre losanges de gardiens", d.sv.status_text().count("◇") + d.sv.status_text().count("◆") == 4)
	w.pause_menu.abandon_requested.emit()
	check("abandon : bilan", await _until(func(): return _results() != null, 25.0, "bilan V"))
	panel = _results()
	await _wait(ResultsPanel.LOCK_SECS + 1.0)
	check("bilan du palier V : « palier V » et gardiens x / 4", _all_text(panel).contains("palier V") and _all_text(panel).contains("/ 4"))
	check("hub identique à la fin " + _hub_diff(hub), _hub() == hub)
	panel.buttons[panel.buttons.size() - 1].pressed.emit()
	check("retour au lobby, état propre", await _until(_is_lobby, 40.0, "lobby") and not Run.active and not Survivor.active and ModeRules.modifiers.is_empty())
	await _wait(0.5)
