class_name RoyaleResults
extends ResultsPanel
## Bilan d'une partie de Battle royale : place finale, éliminations, niveau, coffres, temps, récompenses.


func show_results(place: int, kills: int, level: int, chests: int, secs: float, got: Dictionary) -> void:
	var won := place == 1
	var best := int(Profile.records.get("royale_best", 0))
	var kept: Array = []
	for ln in got.get("text", []):
		kept.append(reward_row(String(ln)))
	var tiles: Array = [
		["%d / %d" % [place, Royale.PLAYERS], "place", "", won],
		[str(kills), "éliminations"],
		[str(level), "niveau"],
		[str(chests), "coffres"],
		["%d min %02d s" % [int(secs) / 60, int(secs) % 60], "durée"],
	]
	if best > 0:
		tiles.append([str(best), "meilleure place", "Victoires : %d" % int(Profile.records.get("royale_wins", 0))])
	show_spec({
		"title": "VICTOIRE !" if won else ("TOP %d" % place if place <= 3 else "ÉLIMINÉ"),
		"tone": "win" if place <= 3 else "lose",
		"subtitle": "Dernier debout sur %d héros" % Royale.PLAYERS if won else "Place %d sur %d" % [place, Royale.PLAYERS],
		"tiles": tiles,
		"kept": kept,
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
