class_name AutochessResults
extends ResultsPanel
## L'Échiquier, lot AC-I : le bilan de fin de partie, par le composant commun des bilans (ResultsPanel). Ta place en grand,
## cinq tuiles (place, manches, dégâts de tes héros, meilleure unité, durée), « Gagné » (coffres d'apparence, titres :
## AutochessRewards.last), la ligne « Ta quête », et trois boutons : Rejouer, Statistiques (le bilan détaillé d'AC-V,
## AutochessRecap.open_game), Menu principal. Mode scellé : rien d'autre (ni maîtrise, ni insignes, ni XP de héros).
## Lot ACX-2 : podium des 8 stratèges sous les tuiles (portrait, place, trait principal ; toi en soleil), « Menu principal »
## (mot de la BIBLE, plus « lobby »).

## [param info] : {diff, place, stage, rounds, rounds_won, secs, abandoned} ; [param acc] : AutochessScreen.game_stats ;
## [param got] : AutochessRewards.last ; [param calls] : {replay, stats, back} (Callable).
func show_results(info: Dictionary, acc: Dictionary, got: Dictionary, calls: Dictionary, podium: Array = []) -> void:
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
			{"text": "Menu principal", "call": calls.get("back", Callable())},
		],
	})
	if not podium.is_empty():
		_add_podium(podium)


## Podium des stratèges ([param list] : {name, class_id, place, trait, me}, classés) : une pastille papier par stratège,
## dans un puits d'encre, sous les tuiles.
func _add_podium(list: Array) -> void:
	var well := PanelContainer.new()
	well.name = "AcPodium"
	well.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ws := AutochessHud.well(14.0, 2.0)
	ws.content_margin_left = 8
	ws.content_margin_right = 8
	ws.content_margin_top = 6
	ws.content_margin_bottom = 6
	well.add_theme_stylebox_override("panel", ws)
	var h := HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_theme_constant_override("separation", 6)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	well.add_child(h)
	for e in list:
		var me := bool(e.get("me", false))
		var chip := PanelContainer.new()
		chip.name = "AcPodium_%d" % int(e.place)
		chip.custom_minimum_size = Vector2(96, 0)
		chip.add_theme_stylebox_override("panel", AutochessHud.sticker(AutochessHud.candy("soleil") if me else AutochessHud.PAPER,
			10.0, 3.0, 2.0, 5.0, 3.0))
		chip.tooltip_text = "%s · %s%s" % [String(e.name), AutochessPlayers.place_text(int(e.place)),
			(" · " + String(e.trait)) if String(e.get("trait", "")) != "" else ""]
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", -2)
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		chip.add_child(v)
		var top := HBoxContainer.new()
		top.add_theme_constant_override("separation", 4)
		top.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(top)
		var pic := TextureRect.new()
		pic.texture = UiTheme.texture(String(GameData.class_data(String(e.class_id)).get("icon", "")))
		pic.custom_minimum_size = Vector2(26, 26)
		pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if int(e.place) > 4:
			pic.modulate = Color(0.75, 0.72, 0.8)
		top.add_child(pic)
		top.add_child(AutochessHud.pop_lbl(str(int(e.place)), 18, AutochessHud.INK))
		var nl := AutochessHud.ink_lbl(String(e.name), 13, AutochessHud.INK, 900)
		nl.clip_text = true
		nl.custom_minimum_size.x = 84
		v.add_child(nl)
		var tl := AutochessHud.ink_lbl(String(e.get("trait", "")), 13, AutochessHud.INK_300, 700)
		tl.clip_text = true
		tl.custom_minimum_size.x = 84
		v.add_child(tl)
		h.add_child(chip)
	var at := -1
	for i in _body.get_child_count():
		if _body.get_child(i) is HBoxContainer:
			at = i + 1
			break
	_body.add_child(well)
	if at >= 0:
		_body.move_child(well, at)


static func _best_text(d: int) -> String:
	var b := AutochessRewards.best(d)
	return AutochessPlayers.place_text(b) if b > 0 else "—"


static func _mvp_tip(acc: Dictionary, id: String) -> String:
	if id == "":
		return ""
	var e: Dictionary = acc.units[id]
	return "%s dégâts · %d élimination%s · meilleure unité de %d manche%s" % [AutochessStats.num(float(e.get("dealt", 0.0))),
		int(e.get("kills", 0)), "s" if int(e.get("kills", 0)) > 1 else "", int(e.get("mvp", 0)), "s" if int(e.get("mvp", 0)) > 1 else ""]
