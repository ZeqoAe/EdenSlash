extends Node
## Journal de run : une ligne par carte avec le style, l'or, la pression.
## godot --headless --path game res://tests/test_journal.tscn

var fails := 0


func check(label: String, ok: bool) -> void:
	print(("OK    " if ok else "ÉCHEC ") + label)
	if not ok:
		fails += 1


func _ready() -> void:
	var path := RunJournal.path()
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	check("journal de test séparé", path.ends_with("journal_test.jsonl"))
	Run.start("warrior")
	RunJournal.context = func(): return {"chests_opened": 3, "chests_total": 10}
	for i in 100:
		RunJournal.tick(0.1, Vector3(i * 0.1, 0, 0))
	var m := Monster.new()
	m.is_boss = true
	RunJournal.player_hit(m, 500.0)
	RunJournal.monster_died(m)
	RunJournal.damage_taken(40.0, m, 400.0)
	Run.add_gold(120, "monstres")
	RunJournal.gold_out(50, "coffres")
	Run.finish("victoire")
	var l: Dictionary = RunJournal.last_line
	check("une ligne écrite", FileAccess.file_exists(path) and not l.is_empty())
	check("style classé : 30 % des coffres sans combat = coffres", l.get("style") == "coffres" and float(l.chest_share) == 0.3)
	check("or par source et par usage", float(l.counters.get("gold_in_monstres", 0)) == 120.0 and float(l.counters.get("gold_out_coffres", 0)) == 50.0)
	check("DPS du boss sur 10 s et temps pour le tuer", float(l.dps_boss_10s) == 50.0 and l.has("ttk_boss"))
	check("pression : dégâts subis par minute et plus gros coup", float(l.dmg_taken_min) > 0.0 and float(l.max_hit_frac) == 0.1)
	check("contexte : mode, classe, aide, version", l.mode == "survival" or l.mode == "run" and l["class"] == "warrior" and l.has("assist") and l.v == Version.NUMBER)
	RunJournal.context = Callable()  # (sinon le rappel vers ce nœud libéré fait planter la sortie)
	m.free()
	print("TOUT EST OK (0 échec(s))" if fails == 0 else "ÉCHECS : %d" % fails)
	get_tree().quit(fails)
