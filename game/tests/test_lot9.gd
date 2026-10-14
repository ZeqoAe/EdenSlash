extends Node
## Lot 9 : tutoriel (Premiers pas, fiches, nouveautés), accueil, Guide.
## godot --headless --path game res://tests/test_lot9.tscn

var fails := 0


func check(label: String, ok: bool) -> void:
	print(("OK    " if ok else "ÉCHEC ") + label)
	if not ok:
		fails += 1


func _ready() -> void:
	Training.active = false
	Settings.reset_all()
	Profile.reset_all()
	Tutorial._counts = {}
	check("nouvelle partie : pas de choix de tutoriel", Tutorial.mode() == "")
	# ancienne sauvegarde jouée : explications coupées, nouveautés seules
	Profile.runs_done = 4
	Tutorial.init_for_save()
	check("partie déjà jouée : tutoriel coupé", Tutorial.mode() == "skip" and not Tutorial.guided())
	var news := Tutorial.news_to_show()
	check("nouveautés annoncées une fois, puis la version est notée", news.size() > 0 and Tutorial.news_to_show().is_empty())
	# nouvelle partie guidée
	Profile.reset_all()
	var w := Welcome.new()
	add_child(w)
	await get_tree().process_frame
	w._class = "magician"
	w._control_i = 1
	w._aid = "relax"
	w.finish()
	check("accueil : classe, contrôles et aide appliqués", Profile.selected_class == "magician" and Settings.move_mode() == "click" and Settings.assist_level() != "assisted")
	check("accueil : mode guidé gardé", Tutorial.mode() == "guided")
	# Premiers pas dans la Survie
	Run.start_survival("warrior", 1)
	check("Premiers pas actifs en Survie guidée", Tutorial.guided() and Tutorial.steps_done().is_empty())
	Tutorial.event("weapon")
	check("étape 1 validée : arme choisie", Tutorial.steps_done() == ["weapon"])
	for i in 9:
		Tutorial.event("kill")
	check("9 monstres : étape pas encore validée", not "fight" in Tutorial.steps_done())
	var fin := Tutorial.event("kill")
	check("10e monstre : étape validée", fin.get("id") == "fight")
	Tutorial.event("dodge")
	check("l'événement doit venir dans l'ordre de la liste (esquive attend le saut ? non : chaque étape suit son événement)", "dodge" in Tutorial.steps_done())
	check("texte d'étape avec les touches réelles", Tutorial.step_text(Tutorial.current_step()).contains("[") or Tutorial.current_step().id == "jump")
	for s in ["jump", "card", "skill", "chain", "chest", "seal", "boss"]:
		Tutorial.event(s)
	check("10 étapes faites : Premiers pas terminés", Tutorial.done_all() and not Tutorial.guided())
	# fiches : 1re occurrence seulement
	Tutorial.event("cards_open")
	check("1re ouverture de cartes : fiche en attente", Tutorial.pending_card == "cards")
	check("la fiche est prise une fois", Tutorial.take_card() == "cards" and Tutorial.take_card() == "")
	Tutorial.event("cards_open")
	check("déjà vue : plus jamais proposée", Tutorial.pending_card == "")
	Profile.tutorial["cards_off"] = true
	Tutorial.event("weapon_up")
	check("conseils coupés : aucune fiche", Tutorial.pending_card == "")
	Profile.tutorial["cards_off"] = false
	# passer
	Profile.tutorial["steps"] = []
	Tutorial.skip_steps()
	check("Passer : étapes toutes cochées, rien de bloqué", Tutorial.done_all())
	Run.active = false
	# Guide
	var g := Guide.open_on(self, "commands")
	await get_tree().process_frame
	check("Guide ouvert, chapitres : commandes, étapes, fiches, nouveautés", g._ids.size() >= Tutorial.CARDS.size() + 3 and g._body.text.length() > 20)
	g.select("cards")
	check("chapitre d'une fiche affiché", g._body.text.contains("cartes") or g._body.text.contains("Cartes"))
	g.close()
	get_tree().paused = false
	print("TOUT EST OK (0 échec(s))" if fails == 0 else "ÉCHECS : %d" % fails)
	get_tree().quit(fails)
