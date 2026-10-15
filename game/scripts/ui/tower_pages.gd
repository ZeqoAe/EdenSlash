class_name TowerPages
extends RefCounted
## La Tour dans le lobby : ligne d'un étage (type, ennemi, verrou) et fiche d'infos en
## panneau (ce qui attend le joueur : ennemis, sorts, équipement), lues dans Tower.spec().
## Pas de chiffres d'équilibrage (PV, défense) : ils ne servent pas à choisir un étage.

const FLOORS_PER_PAGE := 5
const MAX_SHEET_H := 520.0


static func _count(n: int, one: String, many: String) -> String:
	return "%d %s" % [n, one if n <= 1 else many]


## Icône du type de l'étage [param f] (Tower.TYPE_ICONS).
static func floor_icon(f: int) -> String:
	return String(Tower.TYPE_ICONS.get(Tower.floor_type(f), "attack"))


## Ce qui attend à l'étage, en quelques mots : « Ombre · Mage », « Boss : Latif, Roi du ciel », « Élites · Bond, Éventail ».
static func floor_what(s: Dictionary) -> String:
	match String(s.type):
		"duel":
			return "Duelliste %d/%d : %s" % [int(s.index), Tower.count_type("duel", 1, Tower.FLOORS), Tower.hero_title(s)]
		"shadow":
			return Tower.hero_title(s)
		"boss":
			return "Boss : %s" % BossLibrary.full_name(String(s.boss_id)) if String(s.get("boss_id", "")) != "" else "Boss"
		"rest":
			return "Halte"
		"cursed":
			return "Maudit · %s" % String(Tower.CURSES.get(String(s.curse), {}).get("name", ""))
		"elite":
			return "Élites · %s" % ", ".join(_mech_names(s))
	return "Monstres · élite : %s" % ", ".join(_mech_names(s))


static func _mech_names(s: Dictionary) -> PackedStringArray:
	var out: PackedStringArray = []
	for b in s.get("mechanics", []):
		var nm := BossBricks.name_of(String(b))
		if not nm in out:
			out.append(nm)
	return out


## Titre et sous-titre de la ligne de l'étage [param f].
static func floor_line(f: int, diff: int) -> Array:
	var s := Tower.spec(f, diff)
	var state := "battu" if f <= Tower.best(diff) else ("à battre" if f == Tower.best(diff) + 1 else ("ouvert (mode dev)" if Tower.dev_unlock_all() else "verrouillé"))
	return ["Étage %d · %s" % [f, floor_what(s)], "%s · niveau %d · %s" % [s.zone.name, int(s.level), state]]


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
		"duel", "shadow":
			lines.append_array(_duel_lines(s))
		"boss":
			lines.append_array(_boss_lines(s))
		"rest":
			lines.append("[font_size=19][b]Halte[/b][/font_size]")
			lines.append("Pas de combat : reprends ton souffle avant le boss.")
		_:
			lines.append_array(_monster_lines(s))
	lines.append("")
	var gives := String(Tower.TYPE_GIVES.get(String(s.type), Tower.TYPE_GIVES.monsters))
	lines.append("[color=#9fd0ff]Récompense : %s[/color]" % (gives.left(1).to_lower() + gives.substr(1)))
	return "\n".join(lines)


static func _duel_lines(s: Dictionary) -> PackedStringArray:
	var out: PackedStringArray = []
	var r := Tower.make_rival(s)
	out.append("[font_size=19][b]%s[/b][/font_size]" % floor_what(s))
	match String(s.get("kind", "")):
		"self":
			out.append("Ta classe, tes sorts et ton équipement, joués par l'IA.")
		"brain":
			out.append("Un cerveau d'IA la joue, avec tous ses sorts : le défi le plus dur de la Tour.")
		"class":
			out.append("Un héros joué par l'IA : ses coups sont annoncés au sol.")
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
	var bid := String(s.get("boss_id", ""))
	if bid == "":
		out.append("[font_size=19]Boss : [b]%s[/b][/font_size]" % Tower.monster_stats(int(s.boss), s, true).name)
		return out
	out.append("[font_size=19]Boss : [b]%s[/b][/font_size]" % BossLibrary.full_name(bid))
	out.append(BossLibrary.intro(bid))
	out.append("")
	out.append("[color=%s][b]Mécaniques[/b][/color]" % _gold())
	for t in BossLibrary.brick_types(bid):
		out.append("• [b]%s[/b] : %s" % [BossBricks.name_of(String(t)), BossBricks.hint_of(String(t))])
	out.append("Ses attaques sont annoncées en rouge au sol.")
	return out


static func _monster_lines(s: Dictionary) -> PackedStringArray:
	var out: PackedStringArray = []
	var line := "[font_size=19][b]%s[/b][/font_size], %d en même temps au plus" % [_count(int(s.count), "monstre", "monstres"), int(s.alive)]
	out.append(line)
	if String(s.get("curse", "")) != "":
		var c: Dictionary = Tower.CURSES.get(String(s.curse), {})
		out.append("[color=#ff8070][b]Malédiction : %s[/b][/color] · %s" % [String(c.get("name", "")), String(c.get("desc", ""))])
	out.append("")
	var mechs: Array = s.get("mechanics", [])
	if not mechs.is_empty():
		out.append("[color=#ffb070][b]%s[/b][/color]" % _count(mechs.size(), "Élite", "Élites"))
		for b in mechs:
			out.append("• [b]%s[/b] : %s" % [BossBricks.name_of(String(b)), BossBricks.hint_of(String(b))])
		out.append("")
	var plain: PackedStringArray = []
	for id in Tower.floor_species(int(s.floor)):
		var nm := String(Tower.monster_stats(int(id), s).name)
		if not nm in plain:
			plain.append(nm)
	if not plain.is_empty():
		out.append("[color=%s][b]Monstres[/b][/color]" % _gold())
		out.append("  ·  ".join(plain))
	return out


## Légende des types d'étage (icône et nom ; au survol : ce que le type donne), sous la liste des étages.
static func legend(parent: Control) -> HFlowContainer:
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 14)
	flow.add_theme_constant_override("v_separation", 4)
	parent.add_child(flow)
	for t in ["monsters", "elite", "shadow", "cursed", "rest", "boss"]:
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 4)
		h.tooltip_text = "%s : %s" % [Tower.TYPE_NAMES[t], String(Tower.TYPE_GIVES[t]).left(1).to_lower() + String(Tower.TYPE_GIVES[t]).substr(1)]
		h.mouse_filter = Control.MOUSE_FILTER_PASS
		var ic := TextureRect.new()
		ic.texture = MenuWidgets.icon(String(Tower.TYPE_ICONS[t]))
		ic.custom_minimum_size = Vector2(20, 20)
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_child(ic)
		var l := Label.new()
		l.text = String(Tower.TYPE_NAMES[t])
		l.add_theme_font_size_override("font_size", 14)
		l.add_theme_color_override("font_color", UiTheme.MUTED)
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_child(l)
		flow.add_child(h)
	return flow


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
