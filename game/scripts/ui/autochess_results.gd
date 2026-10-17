class_name AutochessResults
extends ResultsPanel
## L'Échiquier, lot AC-I : le bilan de fin de partie, par le composant commun des bilans (ResultsPanel). Ta place en grand,
## cinq tuiles (place, manches, dégâts de tes héros, meilleure unité, durée), « Gagné » (coffres d'apparence, titres :
## AutochessRewards.last), la ligne « Ta quête », et trois boutons : Rejouer, Statistiques (le bilan détaillé d'AC-V,
## AutochessRecap.open_game), Retour au lobby. Mode scellé : rien d'autre (ni maîtrise, ni insignes, ni XP de héros).

## [param info] : {diff, place, stage, rounds, rounds_won, secs, abandoned} ; [param acc] : AutochessScreen.game_stats ;
## [param got] : AutochessRewards.last ; [param calls] : {replay, stats, back} (Callable).
func show_results(info: Dictionary, acc: Dictionary, got: Dictionary, calls: Dictionary) -> void:
	var place := int(info.get("place", 8))
	var won := place == 1
	var abandoned := bool(info.get("abandoned", false))
	var title := "VICTOIRE !" if won else ("TOP %d" % place if place <= 4 else "PLACE %d" % place)
	var diff := AutochessRewards.diff_name(int(info.get("diff", 0)))
	var sub := "%s · %s" % [diff, "abandon : ta place du moment" if abandoned else ("seul en lice sur %d stratèges" % AutochessData.PLAYERS if won else "%s sur %d" % [AutochessPlayers.place_text(place), AutochessData.PLAYERS])]
	var mvp := AutochessStats.game_mvp(acc)
	var dealt := 0.0
	for id in (acc.get("units", {}) as Dictionary):
		dealt += float(acc.units[id].get("dealt", 0.0))
	var secs := float(info.get("secs", 0.0))
	var tiles: Array = [
		["%d / %d" % [place, AutochessData.PLAYERS], "place", "Meilleure place en %s : %s" % [diff, _best_text(int(info.get("diff", 0)))], won],
		[str(int(info.get("rounds", 0))), "manches", "Dont %d gagnées" % int(info.get("rounds_won", 0))],
		[number(dealt), "dégâts", "Dégâts de tes héros sur toute la partie"],
		[AutochessData.unit_name(mvp) if mvp != "" else "—", "meilleure unité", _mvp_tip(acc, mvp)],
		["%d min %02d s" % [int(secs) / 60, int(secs) % 60], "durée"],
	]
	var gained: Array = []
	var looks := 0
	for c in got.get("chests", []):
		var t: Dictionary = Rewards.TYPES.get(String(c.type), {})
		gained.append(row(String(t.get("name", "Coffre d'apparence")), "", "%s · %s" % [String(c.text),
			"première fois dans cette difficulté" if String(c.kind) == "first" else "coffre du jour"], "chest"))
		looks += 1
	for t in got.get("titles", []):
		gained.append(row("Titre « %s »" % String(t.title), "nouveau" if bool(t.get("new", false)) else "", String(t.text), "user"))
	var notes: Array = []
	if int(got.get("opened", -1)) >= 0:
		notes.append("Difficulté %s ouverte !" % AutochessRewards.diff_name(int(got.opened)))
	var foot := ""
	if bool(got.get("early", false)):
		foot = "Abandon avant l'étape %d : aucune récompense." % AutochessRewards.ABANDON_MIN_STAGE
	elif gained.is_empty():
		foot = "Les quatre premiers gagnent un coffre d'apparence, une fois par difficulté puis chaque jour."
	show_spec({
		"title": title,
		"tone": "win" if place <= 4 else "lose",
		"subtitle": sub,
		"notes": notes,
		"tiles": tiles,
		"gained": gained,
		"footnote": foot,
		"quest": Compass.after("autochess", {"looks": looks, "titles": (got.get("titles", []) as Array).size()}),
		"buttons": [
			{"text": "Rejouer", "primary": true, "call": calls.get("replay", Callable())},
			{"text": "Statistiques", "call": calls.get("stats", Callable())},
			{"text": "Retour au lobby", "call": calls.get("back", Callable())},
		],
	})


static func _best_text(d: int) -> String:
	var b := AutochessRewards.best(d)
	return AutochessPlayers.place_text(b) if b > 0 else "—"


static func _mvp_tip(acc: Dictionary, id: String) -> String:
	if id == "":
		return ""
	var e: Dictionary = acc.units[id]
	return "%s dégâts · %d élimination%s · meilleure unité de %d manche%s" % [AutochessStats.num(float(e.get("dealt", 0.0))),
		int(e.get("kills", 0)), "s" if int(e.get("kills", 0)) > 1 else "", int(e.get("mvp", 0)), "s" if int(e.get("mvp", 0)) > 1 else ""]
