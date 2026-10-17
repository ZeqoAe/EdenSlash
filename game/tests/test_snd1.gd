extends Node
## Bibliothèque de sons d'interface (lot SND-1) : chaque nom de Sfx.UI qui pointe vers game/assets/sfx/ui/ se charge
## (WAV mono 44,1 kHz importé), les sons répétitifs sont courts et ont 3 variantes, UiFeel ne joue que des noms connus,
## anti-répétition de 40 ms, volume « Effets sonores » appliqué, « Réduire les animations » ne coupe pas le son, poids
## total de la bibliothèque ≤ 3 Mo.
## godot --headless --path game res://tests/test_snd1.tscn

var fails := 0


func check(label: String, ok: bool) -> void:
	print(("OK    " if ok else "ÉCHEC ") + label)
	if not ok:
		fails += 1


var played := 0  # sons d'interface lancés (comptés à l'ajout : un son court se libère tout seul en fin de lecture)
var last: AudioStreamPlayer


func _on_added(n: Node) -> void:
	if n is AudioStreamPlayer:
		played += 1
		last = n as AudioStreamPlayer


func _ready() -> void:
	get_tree().create_timer(60.0).timeout.connect(func(): get_tree().quit(1))
	Settings.reset_all(false)
	Settings.apply_all()
	Vfx.silent = false
	get_tree().node_added.connect(_on_added)
	# --- fichiers
	var files := {}
	for k in Sfx.UI:
		var v = Sfx.UI[k]
		for f in (v if v is Array else [v]):
			if String(f).begins_with("ui/"):
				files[String(f)] = true
	check("au moins 40 sons de la bibliothèque référencés (%d)" % files.size(), files.size() >= 40)
	var bad := []
	var long := []
	for f in files:
		var s := Sfx._stream(f)
		if not (s is AudioStreamWAV) or (s as AudioStreamWAV).stereo or (s as AudioStreamWAV).mix_rate != 44100:
			bad.append(f)
		elif s.get_length() > 2.6:
			long.append(f)
	check("chaque fichier se charge en WAV mono 44,1 kHz" + ("" if bad.is_empty() else " : " + str(bad)), bad.is_empty())
	check("aucun son de plus de 2,6 s" + ("" if long.is_empty() else " : " + str(long)), long.is_empty())
	# --- sons répétitifs : 3 variantes, courts
	for n in ["ui_hover", "ui_focus", "ui_press", "ui_release", "ui_coin", "ui_hit", "click"]:
		check("%s : 3 variantes" % n, Sfx.UI[n] is Array and (Sfx.UI[n] as Array).size() == 3)
	var short := {"ui_hover": 0.08, "ui_press": 0.08, "ui_release": 0.16, "ui_focus": 0.22, "ui_tab": 0.25, "ui_toggle_on": 0.2,
		"ui_toggle_off": 0.2, "ui_hit": 0.12, "ui_tick": 0.16}
	for n in short:
		var worst := 0.0
		for f in (Sfx.UI[n] if Sfx.UI[n] is Array else [Sfx.UI[n]]):
			worst = maxf(worst, Sfx._stream(String(f)).get_length())
		check("%s court (%d ms ≤ %d)" % [n, roundi(worst * 1000.0), roundi(float(short[n]) * 1000.0)], worst <= float(short[n]))
	# --- UiFeel ne joue que des noms connus ; plus aucun son provisoire du jeu pour l'interface
	var unknown := []
	for k in UiFeel.SOUNDS:
		var nm := String(UiFeel.SOUNDS[k][0])
		if not Sfx.UI.has(nm):
			unknown.append(nm)
		for f in (Sfx.UI[nm] if Sfx.UI.get(nm) is Array else [Sfx.UI.get(nm, "")]):
			if not String(f).begins_with("ui/"):
				unknown.append(nm + " -> " + String(f))
	check("UiFeel : tous les sons viennent de la bibliothèque" + ("" if unknown.is_empty() else " : " + str(unknown)), unknown.is_empty())
	for k in ["open", "close", "toggle_on", "toggle_off"]:
		check("UiFeel : son « %s »" % k, UiFeel.SOUNDS.has(k))
	check("raretés -> 5 tons", Sfx.reward(0) == "ui_reward_1" and Sfx.reward(2) == "ui_reward_2" and Sfx.reward(4) == "ui_reward_4"
		and Sfx.reward(5) == "ui_reward_5" and Sfx.reward(99) == "ui_reward_5")
	# --- anti-répétition : pas deux fois le même son dans les 40 ms
	await get_tree().process_frame
	var n0 := played
	Sfx.ui("ui_press", -15.0)
	Sfx.ui("ui_press", -15.0)
	check("même son deux fois de suite : un seul joué", played == n0 + 1)
	await get_tree().create_timer(0.06, true, false, true).timeout
	Sfx.ui("ui_press", -15.0)
	check("après 40 ms : rejoué", played == n0 + 2)
	# --- volume « Effets sonores »
	Settings.set_v("audio", "sfx", 0.5)
	Settings.apply_all()
	await get_tree().create_timer(0.06, true, false, true).timeout
	Sfx.ui("ui_release", -13.0)
	check("volume « Effets sonores » appliqué (%.1f dB)" % last.volume_db, is_equal_approx(last.volume_db, -13.0 + linear_to_db(0.5)))
	Sfx.ui("click", -8.0)
	check("ancien nom « click » : correction de volume", is_equal_approx(last.volume_db, -8.0 + linear_to_db(0.5) - 5.0))
	Settings.set_v("audio", "sfx", 1.0)
	Settings.apply_all()
	# --- « Réduire les animations » garde le son
	Settings.set_v("interface", "ui_reduce_motion", true)
	UiFeel.read_settings()
	await get_tree().create_timer(0.06, true, false, true).timeout
	var n1 := played
	UiFeel.page_sound(true)
	check("« Réduire les animations » : le son reste", played == n1 + 1)
	Settings.set_v("interface", "ui_reduce_motion", false)
	UiFeel.read_settings()
	# --- poids
	var total := 0
	var d := DirAccess.open("res://assets/sfx/ui")
	if d != null:
		for f in d.get_files():
			if f.ends_with(".wav"):
				total += FileAccess.get_file_as_bytes("res://assets/sfx/ui/" + f).size()
	check("bibliothèque ≤ 3 Mo (%d Ko)" % (total / 1024), total > 0 and total <= 3 * 1024 * 1024)
	print("RÉSULTAT : %s (%d échec(s))" % ["VERT" if fails == 0 else "ROUGE", fails])
	get_tree().quit(1 if fails > 0 else 0)
