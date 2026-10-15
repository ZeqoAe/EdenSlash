class_name DuelResults
extends ResultsPanel
## Bilan d'un duel (libre, Ligue, Panthéon, Arènes, Gantelet) : victoire ou défaite, manches, ce que le
## résultat classé rapporte. Même composant que les autres bilans (ResultsPanel).


## Lignes du résultat : maîtrise, promotion de la Ligue, série et titres dans « Gagné » ; insignes, pièces et coffres
## des récompenses (Panthéon, Arènes, Gantelet) dans « Gardé ».
func _report_rows() -> Dictionary:
	var out := {"gained": [], "kept": []}
	var r: Dictionary = Duel.last_report
	if r.is_empty():
		return out
	if bool(r.get("promoted", false)):
		out.gained.append(row("Promotion", League.rank_name(int(r.rank)), "", "new"))
	if int(r.get("mastery", 0)) > 0:
		out.gained.append(row("Maîtrise %s" % Run.class_data().get("name_fr", ""), "+%d" % int(r.mastery), "", "expertise"))
	if String(r.get("mode", "")) == "league":
		out.gained.append(row("Série de victoires", "%d / %d" % [League.streak(), League.WINS_PER_RANK], "", "stats"))
	for t in r.get("text", []):
		var line := String(t)
		if line.begins_with("Maîtrise : "):
			continue  # déjà en tête de « Gagné »
		if line.begins_with("Titre : "):
			out.gained.append(row("Titre " + line.trim_prefix("Titre : "), "", "", "user"))
		else:
			out.kept.append(reward_row(line))
	return out


func show_results(won: bool, score: String, opponent: String, diff: int, total: int) -> void:
	var cd := GameData.class_data(opponent)
	var times: PackedStringArray = []
	for tm in PvpCaps.round_times:
		times.append("%d s" % roundi(float(tm)))
	var rep := _report_rows()
	show_spec({
		"title": "VICTOIRE !" if won else "DÉFAITE",
		"tone": "win" if won else "lose",
		"subtitle": "%s contre %s · %s" % [Run.class_data().get("name_fr", ""), cd.get("name_fr", opponent), ClassRival.NAMES[diff]],
		"tiles": [
			[score, "manches", ("Durée des manches : " + ", ".join(times)) if not times.is_empty() else ""],
			["À l'arme" if Duel.bare else "Équipé", "niveau %d" % Duel.level],
			["%d %%" % roundi(PvpCaps.best_dealt * 100.0), "plus gros coup", "Part des PV de l'adversaire retirée en un coup"],
			["%d %%" % roundi(PvpCaps.best_taken * 100.0), "plus gros coup reçu", "Part de tes PV retirée en un coup"],
			[str(total), "victoires", "Victoires contre cette classe, dans cette difficulté"],
		],
		"gained": rep.gained,
		"kept": rep.kept,
		"buttons": [
			{"text": "Rejouer (même adversaire)", "primary": true, "call": func():
				get_tree().paused = false
				Duel.start(Profile.selected_class, Duel.rival_class, Duel.difficulty)
				get_tree().change_scene_to_file("res://scenes/world.tscn")},
			{"text": "Retour au lobby", "call": func(): Duel.leave(get_tree())},
		],
	})
