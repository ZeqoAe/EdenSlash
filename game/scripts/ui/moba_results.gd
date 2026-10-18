class_name MobaResults
extends ResultsPanel
## Bilan des Deux Voies (lot MB-H ; croquis moba_maquettes/v2_bilan.svg ; le lot MB-I y ajoutera les récompenses scellées,
## les quêtes et la courbe d'or) : le bilan commun (ResultsPanel) avec le titre, POURQUOI la partie s'est décidée (Cœur
## détruit, ou à 25:00 : structures détruites, Cœur le moins entamé, objectifs, or, sbires : Moba.decided_by), les tuiles
## (structures, durée, éliminations, objectifs, ta ligne), puis le tableau des 8 héros (niveau, éliminations / morts / aides,
## sbires, or gagné, objets) et le meilleur de la partie (★). Boutons : Rejouer, Menu principal (par LoadScreen, règle PERF-1).

const ROW_H := 40.0
const TABLE_W := 940.0

var table: VBoxContainer  # (tests)
var reason := ""  # (tests)
var mvp_cid := ""


## Raison de la fin, en une phrase (jamais de pourcentage).
static func reason_text(how: String, decided: String, won: bool, me: int) -> String:
	var s: Array = Moba.structures_down
	match how:
		"core":
			return "Le Cœur adverse est détruit" if won else "Ton Cœur est détruit"
		"abandon":
			return "Partie abandonnée"
		"time":
			var lead := "Fin au temps (25:00) : "
			match decided:
				"structures":
					return lead + "%s de structures détruites (%d contre %d)" % ["plus" if won else "moins", int(s[me]), int(s[1 - me])]
				"cœur":
					return lead + ("votre Cœur est le moins entamé" if won else "leur Cœur est le moins entamé")
				"objectifs":
					return lead + "%s d'objectifs pris (%d contre %d)" % ["plus" if won else "moins", int(Moba.objectives_taken[me]), int(Moba.objectives_taken[1 - me])]
				"or":
					return lead + ("votre équipe a gagné plus d'or" if won else "leur équipe a gagné plus d'or")
				"sbires":
					return lead + ("vous avez tué plus de sbires" if won else "ils ont tué plus de sbires")
				"égalité":
					return lead + "égalité parfaite"
			return "Fin au temps (25:00)"
	return ""


## Note d'un héros pour « le meilleur de la partie » : éliminations, aides, sbires, objectifs de son équipe ; les morts comptent contre.
static func merit(hs: MobaHero) -> float:
	return hs.kills * 3.0 + hs.assists * 1.5 - hs.deaths * 1.5 + hs.cs / 12.0 + hs.camps * 0.5


## [param d] : le directeur (encore en vie : ses héros et leurs états) ; [param won] : victoire du joueur.
func show_results(d: MobaDirector, won: bool, replay: Callable, lobby: Callable) -> void:
	var me := TeamMatch.player_team
	var how := String(Moba.how)
	reason = reason_text(how, String(Moba.decided_by), won, me)
	var ps: MobaHero = d.info.get(d.player) if d.player != null else null
	var tiles: Array = [
		["%d – %d" % [int(Moba.structures_down[me]), int(Moba.structures_down[1 - me])], "structures détruites", "Tours et Cœur abattus par chaque équipe", true],
		[MobaHud.clock(Moba.t), "durée"],
		["%d – %d" % [int(Moba.hero_kills[me]), int(Moba.hero_kills[1 - me])], "éliminations"],
		["%d – %d" % [int(Moba.objectives_taken[me]), int(Moba.objectives_taken[1 - me])], "objectifs", "Gardiens et Colosses pris"],
	]
	if ps != null:
		tiles.append(["%d / %d / %d" % [ps.kills, ps.deaths, ps.assists], "ta partie", "Éliminations / morts / aides"])
	var best := -INF
	for h in d.heroes:
		var hs: MobaHero = d.info[h]
		var m := merit(hs)
		if m > best:
			best = m
			mvp_cid = hs.cid
	show_spec({
		"title": "VICTOIRE !" if won else ("ABANDON" if how == "abandon" else "DÉFAITE"),
		"tone": "win" if won else "lose",
		"subtitle": "Les Deux Voies · " + reason,
		"tiles": tiles,
		"footnote": "Mode scellé : rien de ton compte n'entre en partie, rien n'en sort.",
		"buttons": [{"text": "Rejouer", "primary": true, "call": replay}, {"text": "Menu principal", "call": lobby}],
	})
	_add_table(d)
	_fit_table.call_deferred()


func _add_table(d: MobaDirector) -> void:
	table = VBoxContainer.new()
	table.name = "MobaTable"
	table.add_theme_constant_override("separation", 3)
	table.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sc := ScrollContainer.new()
	sc.name = "MobaTableScroll"
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.custom_minimum_size = Vector2(TABLE_W, 0)
	sc.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	sc.add_child(table)
	table.custom_minimum_size.x = TABLE_W - 14.0
	_body.add_child(sc)
	_body.move_child(sc, _tiles_index() + 1)
	var me := TeamMatch.player_team
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 0)
	table.add_child(head)
	for c in [["Héros", 330.0], ["Niv.", 60.0], ["É / M / A", 120.0], ["Sbires", 80.0], ["Or", 90.0], ["Objets", 240.0]]:
		var l := Hud._label(head, String(c[0]), 14, UiTheme.MUTED)
		l.custom_minimum_size.x = float(c[1])
	for side in 2:
		var t := me if side == 0 else 1 - me
		for h in d.heroes:
			var hs: MobaHero = d.info[h]
			if hs.side != t:
				continue
			table.add_child(_row(hs, h == d.player))


func _row(hs: MobaHero, mine: bool) -> Control:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UiTheme.sticker("soleil" if mine else ("papier2" if hs.side == TeamMatch.player_team else "gris"),
		{"radius": 10, "shadow": 2, "gloss": false, "pad": Vector2(8, 2)}))
	p.custom_minimum_size = Vector2(0, ROW_H)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 0)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(row)
	var who := Control.new()
	who.custom_minimum_size = Vector2(322, 34)
	who.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(who)
	var sig := TeamSigil.make(hs.side, 22)
	sig.position = Vector2(0, 6)
	sig.size = Vector2(22, 22)
	who.add_child(sig)
	var ic := TextureRect.new()
	ic.texture = UiTheme.texture(String(GameData.class_data(hs.cid).get("icon", "")))
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ic.position = Vector2(28, 2)
	ic.size = Vector2(30, 30)
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	who.add_child(ic)
	var ink := Color.WHITE if mine else UiTheme.color("encre.700")
	var nm := String(GameData.class_data(hs.cid).get("name_fr", hs.cid)) + (" (toi)" if mine else "") + ("  ★ meilleur de la partie" if hs.cid == mvp_cid else "")
	var nl := Hud._label(who, nm, 15, ink)
	nl.position = Vector2(64, 0)
	nl.add_theme_font_override("font", UiTheme.bold_font())
	nl.add_theme_constant_override("outline_size", 4 if mine else 0)
	nl.add_theme_color_override("font_outline_color", UiTheme.color("encre.700"))
	var role := Hud._label(who, String(MobaData.ROLES[clampi(hs.role, 0, MobaData.ROLES.size() - 1)].name), 14, ink if mine else UiTheme.color("encre.500"))
	role.position = Vector2(64, 18)
	role.add_theme_constant_override("outline_size", 4 if mine else 0)
	role.add_theme_color_override("font_outline_color", UiTheme.color("encre.700"))
	for c in [[str(hs.level), 60.0], ["%d / %d / %d" % [hs.kills, hs.deaths, hs.assists], 120.0], [str(hs.cs), 80.0], [RoyaleStyle.number(hs.gold_earned), 90.0]]:
		var l := Hud._label(row, String(c[0]), 16, ink)
		l.add_theme_font_override("font", UiTheme.number_font())
		l.custom_minimum_size.x = float(c[1])
		l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		l.add_theme_constant_override("outline_size", 4 if mine else 0)
		l.add_theme_color_override("font_outline_color", UiTheme.color("encre.700"))
	var items := HBoxContainer.new()
	items.add_theme_constant_override("separation", 4)
	items.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(items)
	for i in MobaData.SLOTS:
		var cell := MobaStore.ItemCell.new()
		cell.id = String(hs.items[i]) if i < hs.items.size() else ""
		cell.custom_minimum_size = Vector2(30, 30)
		cell.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		cell.mouse_filter = Control.MOUSE_FILTER_PASS if cell.id != "" else Control.MOUSE_FILTER_IGNORE
		if cell.id != "":
			cell.tooltip_text = String(MobaData.item(cell.id).get("name", ""))
		items.add_child(cell)
	return p


## Rang des tuiles dans le corps du bilan (le tableau se glisse juste dessous).
func _tiles_index() -> int:
	for i in _body.get_child_count():
		var c := _body.get_child(i)
		if c is HBoxContainer and c.get_child_count() > 0 and c.get_child(0) is PanelContainer:
			return i
	return 2


## En 1280 × 720, le tableau défile plutôt que de pousser les boutons hors de l'écran.
func _fit_table() -> void:
	if table == null or not is_instance_valid(table):
		return
	var sc := table.get_parent() as ScrollContainer
	var vh := get_viewport().get_visible_rect().size.y
	var room := clampf(vh - 470.0, 150.0, 420.0)
	sc.custom_minimum_size.y = minf(table.get_combined_minimum_size().y, room)
