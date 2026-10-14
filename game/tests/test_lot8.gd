extends Node
## Lot 8 : fil d'éveil (Unlocks), Ligue, migration d'une ancienne sauvegarde.
## godot --headless --path game res://tests/test_lot8.tscn

var fails := 0


func check(label: String, ok: bool) -> void:
	print(("OK    " if ok else "ÉCHEC ") + label)
	if not ok:
		fails += 1


func _ready() -> void:
	Training.active = true
	Settings.reset_all()
	Profile.reset_all()
	# nouvelle partie : tout est à gagner
	check("nouvelle partie : Survie et entraînement ouverts", Unlocks.is_open("survival") and Unlocks.is_open("training"))
	check("nouvelle partie : Carnet, Tour, Duel, Donjons fermés", not Unlocks.is_open("collection") and not Unlocks.is_open("tower") and not Unlocks.is_open("duel_free") and not Unlocks.is_open("dungeons"))
	check("une condition en clair", Unlocks.lock_text("tower").contains("époque I"))
	# progression
	Profile.runs_done = 1
	check("1re run terminée : Carnet et Coffres", Unlocks.is_open("collection") and Unlocks.is_open("chests"))
	Profile.runs_done = 3
	check("3 runs : défi de maîtrise", Unlocks.is_open("daily"))
	Profile.records["duel_wins"] = 3
	check("3 duels gagnés : Duel libre et Ligue", Unlocks.is_open("duel_free") and Unlocks.is_open("league"))
	check("Gantelet fermé tant que la Ligue n'est pas Or", not Unlocks.is_open("gauntlet"))
	# on ne reverrouille jamais
	Profile.runs_done = 0
	Profile.records["duel_wins"] = 0
	check("rien n'est reverrouillé", Unlocks.is_open("collection") and Unlocks.is_open("league"))
	# mode dev : tout
	Settings.set_v("interface", "dev_mode", true)
	check("mode dev : tout ouvert", Unlocks.is_open("pantheon") and Unlocks.is_open("heroic"))
	Settings.set_v("interface", "dev_mode", false)
	# migration d'une ancienne sauvegarde utilisée
	Profile.reset_all()
	Profile.runs_done = 5
	Unlocks.migrate(false)
	check("ancienne sauvegarde : Tour, Forge, Duel restent ouverts", Unlocks.is_open("tower") and Unlocks.is_open("forge") and Unlocks.is_open("duel_free"))
	check("ancienne sauvegarde : les nouveautés restent à gagner", not Unlocks.is_open("dungeons") and not Unlocks.is_open("pantheon"))
	Profile.reset_all()
	Unlocks.migrate(false)
	Profile.records = {}
	check("sauvegarde vierge : rien d'ouvert d'avance", not Unlocks.is_open("tower"))
	# activités
	var tower := Activities.get_def("tower")
	check("carte de la Tour grisée tant que verrouillée", Activities.locked(tower))
	# Ligue
	Profile.reset_all()
	check("Ligue : non classé au départ", League.rank_index() == 0 and League.rank_name() == "Non classé")
	for i in League.WINS_PER_RANK - 1:
		League.report(true, "warrior", 2)
	check("2 victoires : pas encore Bronze", League.rank_index() == 0)
	var r := League.report(true, "warrior", 2)
	check("3 victoires d'affilée : Bronze", r.promoted and League.rank_index() == 1)
	League.report(true, "warrior", 2)
	League.report(false, "warrior", 0)
	check("une défaite remet la série à zéro", League.streak() == 0 and League.rank_index() == 1)
	check("Platine = rang 4 ; maîtrise gagnée par duel", League.RANKS.size() == 5 and Profile.expertise.get("warrior", 0) > 0)
	print("TOUT EST OK (0 échec(s))" if fails == 0 else "ÉCHECS : %d" % fails)
	get_tree().quit(fails)
