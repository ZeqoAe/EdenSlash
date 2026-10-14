extends Node
## Lot 11 : Carnet (succès, titres, complétion, grimoire des cartes, codex des trophées).
## godot --headless --path game res://tests/test_lot11.tscn

var fails := 0


func check(label: String, ok: bool) -> void:
	print(("OK    " if ok else "ÉCHEC ") + label)
	if not ok:
		fails += 1


func _ready() -> void:
	Training.active = true
	Settings.reset_all()
	Profile.reset_all()
	Achievements.refresh()
	check("sauvegarde neuve : aucun succès", Achievements.count().x == 0)
	# accordés pour le passé
	Profile.runs_done = 12
	Profile.runs_won = 3
	Profile.records["kills"] = 1500
	Profile.records["epochs_cleared"] = 2
	var got := Achievements.refresh()
	check("succès accordés d'après les records", "run_10" in got and "kills_1k" in got and "win_1" in got and "epoch_2" in got)
	check("un seuil non atteint reste fermé", not Achievements.owned("kills_10k") and not Achievements.owned("win_10"))
	check("réévaluer n'en donne pas deux fois", Achievements.refresh().is_empty())
	var p := Achievements.progress(Achievements.LIST.filter(func(a): return a.id == "kills_10k")[0])
	check("progression d'un succès : 1500 / 10000", int(p.x) == 1500 and int(p.y) == 10000)
	check("titres gagnés listés", "Habitué" in Achievements.titles())
	Profile.title = "Habitué"
	check("titre porté", Profile.title == "Habitué")
	# complétion
	var cats := Completion.categories()
	check("dix catégories", cats.size() == 10)
	check("classes : au moins les 5 de base", int(cats[0][1]) >= 5 and int(cats[0][2]) == GameData.classes.size())
	check("pourcentage global entre 0 et 100", Completion.percent() >= 0 and Completion.percent() <= 100)
	# trophées et armes
	Profile.note_trophy("storm")
	Profile.note_trophy("storm")
	Profile.note_weapon_legend("katana:0")
	check("trophée découvert une seule fois", Profile.seen_trophies == ["storm"])
	check("variante d'arme légendaire comptée", int(Completion.categories()[5][1]) == 1)
	# persistance
	Training.active = false
	Profile.save_profile()
	var keep := Profile.achievements.duplicate()
	Profile.achievements = {}
	Profile.load_profile()
	check("succès, titre et codex rechargés", Profile.achievements.size() == keep.size() and Profile.title == "Habitué" and Profile.seen_trophies == ["storm"])
	# pages
	var o := CarnetPages.OverviewPage.new()
	add_child(o)
	await get_tree().process_frame
	o.refresh()
	check("vue d'ensemble construite", o._box.get_child_count() > 12)
	var a := CarnetPages.AchievementsPage.new()
	add_child(a)
	a.refresh()
	check("page des succès construite", a._box.get_child_count() > Achievements.LIST.size())
	var c := CarnetPages.CardsPage.new()
	add_child(c)
	c.refresh()
	check("grimoire des cartes construit", c._box.get_child_count() > 10)
	var t := CarnetPages.TrophiesPage.new()
	add_child(t)
	t.refresh()
	check("codex des trophées construit", t._box.get_child_count() > 20)
	print("TOUT EST OK (0 échec(s))" if fails == 0 else "ÉCHECS : %d" % fails)
	get_tree().quit(fails)
