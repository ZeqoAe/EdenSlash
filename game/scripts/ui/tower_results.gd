class_name TowerResults
extends ResultsPanel
## Bilan de fin d'ascension de la Tour : étage atteint, record, maîtrise gagnée, butin gardé.

const TITLES := {"victoire": "SOMMET DE LA TOUR !", "defaite": "CHUTE DANS LA TOUR", "abandon": "ASCENSION ARRÊTÉE"}


## [param got] : Tower.finish() {best, new_record, xp, levels, items, crystals, chests, looks}.
func show_results(result: String, floor_reached: int, got: Dictionary) -> void:
	var diff: String = Tower.DIFF_NAMES[Tower.difficulty]
	var cls := Run.class_data()
	var record := bool(got.get("new_record", false))
	var duels := Tower.duel_index(floor_reached) - Tower.duel_index(Tower.start_floor - 1)
	var gained: Array = [row("Maîtrise %s" % cls.get("name_fr", ""), "+%d" % int(got.get("xp", 0)), "", "expertise")]
	if int(got.get("levels", 0)) > 0:
		gained.append(row("Niveau %d de maîtrise" % Profile.expertise_level(Run.class_id), "", "", "expertise"))
	if record:
		gained.append(row("Nouveau record", "étage %d" % int(got.get("best", 0)), diff, "stats"))
	var kept: Array = []
	if int(got.get("items", 0)) > 0:
		kept.append(row("Objets des coffres", str(int(got.items)), "Ils rejoignent ton coffre commun", "equipment"))
	if int(got.get("crystals", 0)) > 0:
		kept.append(row("Cristaux", str(int(got.crystals)), "", "crystal"))
	kept.append_array(chest_rows(got.get("chests", [])))
	if int(got.get("looks", 0)) > 0:
		kept.append(row("Coffre d'apparence", "×%d" % int(got.looks) if int(got.looks) > 1 else "", "Palier franchi", "chest"))
	var build: PackedStringArray = []
	for e in Run.all_skills():
		build.append("%s r%d" % [Run.skill_def(int(e.id)).get("name", "?"), int(e.rank)])
	for id in Run.passives:
		build.append("%s ×%d" % [Run.passive_def(String(id)).get("name", id), int(Run.passives[id])])
	show_spec({
		"title": TITLES.get(result, "FIN DE L'ASCENSION"),
		"tone": "win" if result == "victoire" else "lose",
		"subtitle": "%s · %s" % [cls.get("name_fr", ""), diff],
		"tiles": [
			["%d / %d" % [floor_reached, Tower.FLOORS], "étage atteint", "", record],
			[str(int(got.get("best", 0))), "record %s" % diff.to_lower()],
			["%d / %d" % [duels, Tower.duel_count()], "duels gagnés"],
			[str(Run.max_level), "niveau"],
			[Run.duration_text(), "durée"],
			[str(Run.kills), "monstres"],
		],
		"gained": gained,
		"kept": kept,
		"lost": [row("Build de l'ascension", "", "Sorts, cartes et équipement de la Tour", "equipment")],
		"footnote": ("Build : " + "  ·  ".join(build)) if not build.is_empty() else "",
		"buttons": [
			{"text": "Rejouer (étage %d, %s)" % [Tower.start_floor, diff], "primary": true, "call": func():
				get_tree().paused = false
				Tower.start(Profile.selected_class, Tower.difficulty, Tower.start_floor)
				get_tree().change_scene_to_file("res://scenes/world.tscn")},
			{"text": "Retour au lobby", "call": func(): Tower.leave(get_tree())},
		],
	})
	print("[tour] fin : %s, étage %d, record %d, %d objet(s) gardés, coffre commun : %d objet(s)" % [result, floor_reached, int(got.get("best", 0)), int(got.get("items", 0)), Profile.inventory.size()])
