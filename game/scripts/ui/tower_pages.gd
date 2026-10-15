class_name TowerPages
extends RefCounted
## La Tour dans le lobby : ligne d'un étage (type, ennemi, verrou) et fiche d'infos en
## panneau (ce qui attend le joueur : ennemis, sorts, équipement), lues dans Tower.spec().
## Pas de chiffres d'équilibrage (PV, défense) : ils ne servent pas à choisir un étage.

const FLOORS_PER_PAGE := 5
const MAX_SHEET_H := 520.0


static func _count(n: int, one: String, many: String) -> String:
	return "%d %s" % [n, one if n <= 1 else many]


## Titre et sous-titre de la ligne de l'étage [param f].
static func floor_line(f: int, diff: int) -> Array:
	var s := Tower.spec(f, diff)
	var what := ""
	match String(s.type):
		"duel":
			what = "Duel %d/%d : %s" % [int(s.index), Tower.duel_count(), GameData.class_data(String(s["class"])).get("name_fr", "")]
		"boss":
			what = "Boss : %s" % GameData.monster(int(s.boss)).get("name", "?")
		"elite":
			what = "%s et %s" % [_count(int(s.count), "monstre", "monstres"), _count(int(s.elites), "élite", "élites")]
		_:
			what = _count(int(s.count), "monstre", "monstres")
	var state := "battu" if f <= Tower.best(diff) else ("à battre" if f == Tower.best(diff) + 1 else ("ouvert (mode dev)" if Tower.dev_unlock_all() else "verrouillé"))
	return ["Étage %d · %s" % [f, what], "%s · niveau %d · %s" % [s.zone.name, int(s.level), state]]


static func _gold() -> String:
	return "#%s" % UiTheme.GOLD.to_html(false)


## Fiche de l'étage en BBCode.
static func info_text(s: Dictionary) -> String:
	var f := int(s.floor)
	var lines: PackedStringArray = []
	lines.append("[font_size=24][color=%s]Étage %d · %s[/color][/font_size]" % [_gold(), f, Tower.TYPE_NAMES.get(String(s.type), "")])
	lines.append("[color=#b8b8c8]%s · niveau %d · %s[/color]" % [s.zone.name, int(s.level), Tower.DIFF_NAMES[int(s.diff)]])
	lines.append("")
	match String(s.type):
		"duel":
			lines.append_array(_duel_lines(s))
		"boss":
			lines.append_array(_boss_lines(s))
		_:
			lines.append_array(_monster_lines(s))
	lines.append("")
	lines.append("[color=#9fd0ff]Récompense : une carte, puis un coffre.[/color]")
	return "\n".join(lines)


static func _duel_lines(s: Dictionary) -> PackedStringArray:
	var out: PackedStringArray = []
	var r := Tower.make_rival(s)
	var cd := GameData.class_data(r.cid)
	out.append("[font_size=19]Duel %d/%d : [b]%s[/b][/font_size]" % [int(s.index), Tower.duel_count(), cd.get("name_fr", r.cid)])
	out.append("")
	out.append("[color=%s][b]Sorts[/b][/color]" % _gold())
	if r._skills.is_empty():
		out.append("Aucun : seulement l'auto-attaque de son arme")
	for sk in r._skills:
		out.append("• [b]%s[/b]\n   [color=#b8b8c8]%s[/color]" % [sk.get("name", "?"), sk.get("desc", "")])
	if not r.auto_step.is_empty():
		out.append("• [b]Auto-attaque[/b] (%s) : %s" % [r.wtype.get("name", ""), String(r.auto_step.get("name", "?"))])
	out.append("")
	out.append("[color=%s][b]Équipement[/b][/color]" % _gold())
	for it in r.gear:
		out.append("• [color=#%s]%s[/color]" % [Items.color_of(it).to_html(false), Items.display_name(it)])
	r.free()
	return out


static func _boss_lines(s: Dictionary) -> PackedStringArray:
	var out: PackedStringArray = []
	var st := Tower.monster_stats(int(s.boss), s, true)
	var dungeon: Dictionary = s.zone.get("dungeon", {})
	out.append("[font_size=19]Boss : [b]%s[/b][/font_size]" % st.name)
	if String(dungeon.get("intro", "")) != "":
		out.append(String(dungeon.intro))
	out.append("Ses attaques sont annoncées en rouge au sol. Des renforts arrivent toutes les 14 s.")
	return out


static func _monster_lines(s: Dictionary) -> PackedStringArray:
	var out: PackedStringArray = []
	var line := "[font_size=19][b]%s[/b][/font_size], %d en même temps au plus" % [_count(int(s.count), "monstre", "monstres"), int(s.alive)]
	if String(s.type) == "elite":
		line += " · dont %s dès le début" % _count(int(s.elites), "élite", "élites")
	out.append(line)
	out.append("")
	var ids: Array = s.zone.get("monsters", [])
	var elites: PackedStringArray = []
	var plain: PackedStringArray = []
	if String(s.type) == "elite":
		for id in s.zone.get("elites", []).slice(0, 5):
			var nm := String(Tower.monster_stats(int(id), s).name)
			if not nm in elites:
				elites.append(nm)
	for id in ids.slice(0, 10):
		var nm := String(Tower.monster_stats(int(id), s).name)
		if not nm in plain and not nm in elites:
			plain.append(nm)
	if not elites.is_empty():
		out.append("[color=#ffb070][b]Élites[/b][/color]")
		out.append("  ·  ".join(elites))
		out.append("")
	out.append("[color=%s][b]Monstres[/b][/color]" % _gold())
	out.append("  ·  ".join(plain))
	return out


## Panneau de la fiche : se ferme par Échap / B, par un clic à côté ou par Fermer.
class Sheet extends CanvasLayer:
	var scroll: ScrollContainer
	var rt: RichTextLabel

	func _unhandled_input(event: InputEvent) -> void:
		if event.is_action_pressed("ui_cancel"):
			get_viewport().set_input_as_handled()
			queue_free()

	## La zone de texte prend la hauteur du texte (une fois la largeur posée), sans dépasser MAX_SHEET_H.
	func fit() -> void:
		await get_tree().process_frame
		await get_tree().process_frame
		if is_instance_valid(scroll) and is_instance_valid(rt):
			scroll.custom_minimum_size.y = clampf(rt.get_combined_minimum_size().y, 60.0, TowerPages.MAX_SHEET_H)


## Fiche de l'étage en panneau par-dessus l'écran (fond assombri).
static func info_popup(anchor: Node, s: Dictionary) -> CanvasLayer:
	var layer := Sheet.new()
	layer.layer = 60
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.01, 0.05, 0.7)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed:
			layer.queue_free())
	layer.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(center)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", MenuWidgets.glass(14, UiTheme.GOLD, 0.97))
	panel.custom_minimum_size = Vector2(640, 0)
	center.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	panel.add_child(v)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size.y = 240.0
	v.add_child(scroll)
	var rt := RichTextLabel.new()
	rt.bbcode_enabled = true
	rt.fit_content = true
	rt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rt.add_theme_font_size_override("normal_font_size", 16)
	rt.add_theme_font_size_override("bold_font_size", 16)
	rt.text = info_text(s)
	scroll.add_child(rt)
	var close := MenuWidgets.glass_button("Fermer", 18, Vector2(200, 44))
	close.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close.pressed.connect(layer.queue_free)
	v.add_child(close)
	layer.scroll = scroll
	layer.rt = rt
	anchor.get_tree().current_scene.add_child(layer)
	layer.fit()
	return layer
