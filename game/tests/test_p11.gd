extends Node
## Passe P11 (conception/nuit_15_10/R_P11.md) : boss de la Survie à PV FIXES par carte et par époque (jamais d'après
## le niveau ou la PE du héros), rage du boss (ses coups montent chaque minute après Epochs.BOSS_RAGE_AT), et temps
## pour tuer mesuré par la sonde res://tools/boss_ttk.tscn : une bonne run tue le boss de la carte 1 en 30 s à 2 min,
## une run rushée n'a pas fini le boss de la carte 2 au début de sa rage.
## godot --headless --path game res://tests/test_p11.tscn [-- --no-probe]  (la sonde lance 2 combats, ≈ 1 min)

var fails := 0
var world: Node


func check(label: String, ok: bool) -> void:
	print(("OK    " if ok else "ÉCHEC ") + label)
	if not ok:
		fails += 1


func _ready() -> void:
	_test_table()
	Profile.selected_zone = String(GameData.zones[0].id)
	world = load("res://scenes/world.tscn").instantiate()
	get_tree().root.add_child.call_deferred(world)
	await get_tree().create_timer(6.0).timeout
	world.cards._queue.clear()
	world.cards._show_next()
	await _test_fixed_hp()
	_test_boss_rage()
	if not "--no-probe" in OS.get_cmdline_user_args():
		_test_probe()
	print("TOUS LES TESTS PASSENT" if fails == 0 else "%d ÉCHEC(S)" % fails)
	get_tree().quit(1 if fails > 0 else 0)


## Table des PV : croissante par carte et par époque, « démesurée » aux cartes 2 et 3 (avant : ≈ 40 000 à 120 000 partout).
func _test_table() -> void:
	var ok := true
	for e in range(1, 5):
		for k in range(1, 4):
			if k > 1 and Epochs.boss_hp(e, k) <= Epochs.boss_hp(e, k - 1):
				ok = false
			if e > 1 and Epochs.boss_hp(e, k) <= Epochs.boss_hp(e - 1, k):
				ok = false
	check("PV des boss croissants par carte et par époque (%s)" % str(Epochs.BOSS_HP_MAP), ok)
	check("carte 2 ≥ 4 × carte 1 et carte 3 ≥ 4 × carte 2 (dégâts du héros ×4 et ×3 d'une carte à l'autre, mesurés)",
		Epochs.boss_hp(1, 2) >= 4.0 * Epochs.boss_hp(1, 1) and Epochs.boss_hp(1, 3) >= 4.0 * Epochs.boss_hp(1, 2))
	var rage_ok := true
	for k in range(1, 4):
		rage_ok = rage_ok and Epochs.boss_rage_at(k) >= 120.0 and (k == 1 or Epochs.boss_rage_at(k) >= Epochs.boss_rage_at(k - 1))
	check("rage du boss : après 2 min au moins, plus tard aux cartes suivantes (%s)" % str(Epochs.BOSS_RAGE_AT), rage_ok)


## PV fixes : même boss à l'entrée de l'arène, que le héros soit niveau 3 ou 35, nu ou équipé.
func _test_fixed_hp() -> void:
	var d: RunDirector = world.director
	var p: Player = world.player
	d.set_process(false)
	p.immortal = true
	Run.stage = 2
	p.level = 3
	p.recalc_stats()
	d.debug_enter_dungeon()
	await get_tree().physics_frame
	var hp_low := d._boss.max_hp
	check("boss de la carte 2 (époque %d) au niveau 3 : %.0f PV = table (%.0f)" % [Run.epoch, hp_low, Epochs.boss_hp(Run.epoch, 2)],
		is_equal_approx(hp_low, Epochs.boss_hp(Run.epoch, 2) * (1.0 + Epochs.HEROIC_HP * Run.heroic_rank)))
	d.state = "explore"
	p.level = 35
	Profile.install_gear(StarterGear.scenario("4.3.10.4", Run.class_id))
	p.recalc_stats()
	d.debug_enter_dungeon()
	await get_tree().physics_frame
	check("niveau 35 et équipement d'époque IV : mêmes PV (%.0f)" % d._boss.max_hp, is_equal_approx(d._boss.max_hp, hp_low))


## Rage du boss : rien avant BOSS_RAGE_AT, puis ×1,1, ×2, ×11 sur ses dégâts (pas ses PV), une minute par palier.
func _test_boss_rage() -> void:
	var d: RunDirector = world.director
	var b: Monster = d._boss
	var atk0 := b.atk
	var hp0 := b.max_hp
	var at := Epochs.boss_rage_at(Run.stage)
	d._boss_time = 0.0
	d._update_boss(at - 1.0)
	check("avant %d s : pas de rage (« %s »)" % [int(at), d.boss_rage_text()], d.boss_rage_tier() == 0 and is_equal_approx(b.atk, atk0)
		and d.boss_rage_text().begins_with("Rage du boss dans 0:0"))
	d._update_boss(2.0)
	check("à %d s : palier 1, dégâts ×1,1 (« %s »)" % [int(at), d.boss_rage_text()], d.boss_rage_tier() == 1 and is_equal_approx(b.atk, atk0 * 1.1)
		and d.boss_rage_text().begins_with("RAGE ×1,1 · 0:5"))
	d._update_boss(RunDirector.RAGE_STEP)
	check("une minute plus tard : dégâts ×2", d.boss_rage_tier() == 2 and is_equal_approx(b.atk, atk0 * 2.0))
	d._update_boss(RunDirector.RAGE_STEP)
	check("deux minutes plus tard : dégâts ×11, PV inchangés", d.boss_rage_tier() == 3 and is_equal_approx(b.atk, atk0 * 11.0) and is_equal_approx(b.max_hp, hp0))
	check("objectif du combat : « %s »" % d._objective_text().replace("\n", " / "), d._objective_text().contains("RAGE ×11"))


## Sonde de DPS (vrai combat, héros invincible, aide « Bot », boss sans mécaniques) : bornes de temps pour tuer.
func _test_probe() -> void:
	var good := _probe(["--epoch=1", "--stage=1", "--class=warrior", "--hub=new", "--level=15", "--cards=16", "--trophies=4",
		"--finds=0.7", "--anvil=1", "--seed=7", "--max=200"])
	check("bonne run, carte 1 : boss tué en %.0f s (30 s à 2 min)" % float(good.get("ttk", -1.0)),
		String(good.get("res", "")) == "tué" and float(good.ttk) >= 30.0 and float(good.ttk) <= 120.0)
	var at := Epochs.boss_rage_at(2)
	var rush := _probe(["--epoch=1", "--stage=2", "--class=warrior", "--hub=new", "--level=17", "--cards=16", "--trophies=1",
		"--finds=0.3", "--anvil=0", "--seed=7", "--max=%d" % int(at)])
	check("run rushée, carte 2 : boss pas fini au début de sa rage (%s, %.0f s, %.0f %% de PV retirés)" % [rush.get("res", "?"), float(rush.get("ttk", -1.0)),
		100.0 * float(rush.get("dps", 0.0)) * float(rush.get("ttk", 0.0)) / maxf(float(rush.get("hp", 1.0)), 1.0)], String(rush.get("res", "")) == "temps")


func _probe(args: Array) -> Dictionary:
	var out: Array = []
	var cmd := PackedStringArray(["--headless", "--fixed-fps", "60", "--path", ProjectSettings.globalize_path("res://"), "res://tools/boss_ttk.tscn", "--", "--pure"])
	cmd.append_array(PackedStringArray(args))
	OS.set_environment("EDEN_PROFILE", "user://sim_test_p11.json")
	OS.execute(OS.get_executable_path(), cmd, out, true)
	var text := "\n".join(out)
	# (sortie lue en Latin-1 par OS.execute sous Windows : seules les parties ASCII de la ligne servent)
	var re := RegEx.create_from_string("sultat=(\\S+) ttk=([\\d.]+) pv_boss=(\\d+) boss_niv=\\d+ dps=(\\d+)")
	var m := re.search(text)
	if m == null:
		print("  sonde sans résultat : ", text.right(600))
		return {}
	var res := m.get_string(1)
	return {"res": "tué" if res.begins_with("tu") else res, "ttk": float(m.get_string(2)), "hp": float(m.get_string(3)), "dps": float(m.get_string(4))}
