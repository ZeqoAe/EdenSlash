class_name RoyaleResults
extends ResultsPanel
## Bilan d'une partie de Battle royale : place finale, éliminations, niveau, coffres, temps, récompenses.
## Passe M1 : maîtrise et titre dans « Gagné » (progression), insignes et coffre d'apparence dans « Gardé ».


## Lignes de Royale.settle rangées comme les autres bilans (DuelResults._report_rows).
static func report_rows(got: Dictionary) -> Dictionary:
	var out := {"gained": [], "kept": []}
	if int(got.get("mastery", 0)) > 0:
		out.gained.append(row("Maîtrise %s" % GameData.class_data(Run.class_id).get("name_fr", ""), "+%d" % int(got.mastery), "", "expertise"))
	for t in got.get("text", []):
		var line := String(t)
		if line.begins_with("Maîtrise : "):
			continue  # déjà en tête de « Gagné »
		if line.begins_with("Titre : "):
			out.gained.append(row("Titre " + line.trim_prefix("Titre : "), "", "", "user"))
		else:
			out.kept.append(reward_row(line))
	return out


func show_results(place: int, kills: int, level: int, chests: int, secs: float, got: Dictionary) -> void:
	var won := place == 1
	var best := int(Profile.records.get("royale_best", 0))
	var rep := report_rows(got)
	var tiles: Array = [
		["%d / %d" % [place, Royale.PLAYERS], "place", "", won],
		[str(kills), "élimination" if kills <= 1 else "éliminations"],
		[str(level), "niveau"],
		[str(chests), "coffre" if chests <= 1 else "coffres"],
		["%d min %02d s" % [int(secs) / 60, int(secs) % 60], "durée"],
	]
	if best > 0:
		tiles.append([str(best), "meilleure place", "Victoires : %d" % int(Profile.records.get("royale_wins", 0))])
	show_spec({
		"title": "VICTOIRE !" if won else ("TOP %d" % place if place <= 3 else "ÉLIMINÉ"),
		"tone": "win" if place <= 3 else "lose",
		"subtitle": "Dernier debout sur %d héros" % Royale.PLAYERS if won else "Place %d sur %d" % [place, Royale.PLAYERS],
		"tiles": tiles,
		"gained": rep.gained,
		"kept": rep.kept,
		"lost": [row("Équipement et potions", "", "Ils restent dans la partie", "equipment")],
		"quest": Compass.after("royale", {"looks": 1 if (got.get("text", []) as Array).any(func(t): return String(t).begins_with("Coffre d'apparence")) else 0}),
		"buttons": [
			{"text": "Rejouer", "primary": true, "call": func():
				get_tree().paused = false
				Royale.start(Profile.selected_class)
				get_tree().change_scene_to_file("res://scenes/world.tscn")},
			{"text": "Retour au lobby", "call": func(): Royale.leave(get_tree())},
		],
	})
