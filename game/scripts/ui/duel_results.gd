class_name DuelResults
extends ResultsPanel
## Bilan d'un duel (libre, Ligue, Panthéon, Arènes, Gantelet) : victoire ou défaite, manches, ce que le
## résultat classé rapporte. Même composant que les autres bilans (ResultsPanel).


## Lignes du résultat : maîtrise, promotion de la Ligue, série et titres dans « Gagné » ; insignes, pièces et coffres
## des récompenses (Ligue, Panthéon, Arènes, Gantelet) dans « Gardé ».
func _report_rows() -> Dictionary:
	var out := {"gained": [], "kept": []}
	var r: Dictionary = Duel.last_report
	if r.is_empty():
		return out
	if bool(r.get("promoted", false)):
		out.gained.append(row("Promotion", League.rank_name(int(r.rank)), "", "new"))
	if int(r.get("mastery", 0)) > 0:
		out.gained.append(row("Maîtrise %s" % Run.class_data().get("name_fr", ""), "+%d" % int(r.mastery), "", "expertise"))
	if String(r.get("mode", "")) == "league" and League.rank_index() < League.RANKS.size() - 1:
		out.gained.append(row("Série vers %s" % League.rank_name(League.target_rank()), "%d / %d" % [League.streak(), League.WINS_PER_RANK],
			"%s d'affilée font monter de rang ; une défaite remet la série à zéro." % GearPower.plural(League.WINS_PER_RANK, "victoire"), "stats"))
	for t in r.get("text", []):
		var line := String(t)
		if line.begins_with("Maîtrise : "):
			continue  # déjà en tête de « Gagné »
		if line.begins_with("Titre : "):
			out.gained.append(row("Titre " + line.trim_prefix("Titre : "), "", "", "user"))
		else:
			out.kept.append(reward_row(line))
	# coffres d'apparence (promotion de Ligue, Panthéon) : un par ligne, au nom du coffre
	for c in r.get("chests", []):
		out.kept.append(row(String(Rewards.TYPES.get(String(c), {}).get("name", "Coffre")), "", "", "chest"))
	return out


func show_results(won: bool, score: String, opponent: String, diff: int, total: int) -> void:
	var cd := GameData.class_data(opponent)
	var times: PackedStringArray = []
	for tm in PvpCaps.round_times:
		times.append("%d s" % roundi(float(tm)))
	var rep := _report_rows()
	var team := Duel.mode in ["arena2", "arena3", "gauntlet"]
	# en équipe, le sous-titre nomme le mode (le premier adversaire n'est qu'un parmi d'autres)
	var sub := "%s · %s" % [Duel.mode_title(), ClassRival.NAMES[diff]] if team \
		else "%s contre %s · %s" % [HeroLook.who(Run.class_id), cd.get("name_fr", opponent), ClassRival.NAMES[diff]]
	var wins_tile: Array = [str(total), "victoires", "Victoires contre cette classe, dans cette difficulté"]
	if team:
		var key := "%s_wins" % Duel.mode if Duel.mode != "gauntlet" else "gauntlet_%d_wins" % (Duel.extra_foes.size() + 1)
		wins_tile = [str(int(Profile.records.get(key, 0))), "victoires", "Victoires dans ce mode"]
	var replay_text := "Rejouer (même adversaire)"
	match Duel.mode:
		"league":
			replay_text = "Combat suivant"
		"pantheon":
			replay_text = "Rejouer"
		"arena2", "arena3":
			replay_text = "Nouvelle équipe adverse"
		"gauntlet":
			replay_text = "Nouveaux adversaires"
	show_spec({
		"title": ("ABANDON" if Duel.forfeit else "DÉFAITE") if not won else "VICTOIRE !",
		"tone": "win" if won else "lose",
		"subtitle": sub,
		"tiles": [
			[score, "manches", ("Durée des manches : " + ", ".join(times)) if not times.is_empty() else ""],
			["À l'arme" if Duel.bare else "Équipé", "niveau %d" % Duel.level],
			# (lot HUD-2 : le pourcentage n'est que dans l'infobulle)
			[RunPage.hit_word(PvpCaps.best_dealt), "plus gros coup", "Part des PV de l'adversaire retirée en un coup : %d %%" % roundi(PvpCaps.best_dealt * 100.0)],
			[RunPage.hit_word(PvpCaps.best_taken), "plus gros coup reçu", "Part de tes PV retirée en un coup : %d %%" % roundi(PvpCaps.best_taken * 100.0)],
			wins_tile,
		],
		"gained": rep.gained,
		"kept": rep.kept,
		"quest": Compass.after("duel", {"promoted": bool(Duel.last_report.get("promoted", false)), "rank_name": League.rank_name(),
			"mode": String(Duel.last_report.get("mode", "")), "spirit": Duel.last_report.get("text", []).any(func(t): return String(t).begins_with("Pièce de la panoplie des Esprits"))}),
		"buttons": [
			{"text": replay_text, "primary": true, "call": func():
				get_tree().paused = false
				Duel.replay()
				LoadScreen.go(get_tree(), "res://scenes/world.tscn")},
			{"text": "Retour au menu", "call": func(): Duel.leave(get_tree())},
		],
	})
