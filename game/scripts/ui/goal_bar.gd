class_name GoalBar
extends PanelContainer
## Barre d'objectif (lot GX-3, P0-6 de l'étude BM-GEAR) : l'objectif épinglé (Goals) en une rangée autocollante soleil :
## ★, la pièce visée (case : sa carte au survol), son nom et ce qui manque, les trois étapes (plan, insignes, niveau) en
## pastilles, « Y aller » (là où l'objectif avance), ⇄ (objectif suivant) et ✕ (ne plus suivre).
## [member compact] : une seule ligne, sans étapes (en-tête de l'Atelier) ; sans objectif, la barre se cache (compacte) ou
## dit comment en choisir un.
## Signal [signal go] : l'hôte ouvre l'écran (Lobby._compass_open) ; par défaut la barre le fait elle-même.

signal go(target: Dictionary)

var compact := false
var narrow := false  # colonne étroite : sans ⇄ ni ✕
var _slot: ItemWidgets.ItemSlot
var _name: Label
var _line: Label
var _steps: HBoxContainer
var _go: Button
var _next: Button
var _drop: Button
var _star: Label
var _shown := ""


func _init(is_compact := false) -> void:
	compact = is_compact
	add_theme_stylebox_override("panel", UiTheme.sticker("soleil", {"shadow": 4, "radius": 14, "gloss": false, "cel_top": 0.0,
		"cel_bottom": 0.32, "pad": Vector2(10, 4 if compact else 6)}))
	mouse_filter = Control.MOUSE_FILTER_PASS
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	add_child(h)
	_star = ForgeWidgets.ink_label(h, "★", 20 if compact else 24, Color.WHITE, 5)
	_star.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_star.tooltip_text = "Ton objectif : une pièce que tu vises (Atelier > Fabriquer ou Plans de donjon, « ★ Objectif »)."
	_star.mouse_filter = Control.MOUSE_FILTER_PASS
	_slot = ItemWidgets.ItemSlot.new(34.0 if compact else 44.0)
	_slot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_slot.marks = false
	_slot.wear_check = true
	h.add_child(_slot)
	var tv := VBoxContainer.new()
	tv.add_theme_constant_override("separation", -2)
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tv.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(tv)
	_name = ForgeWidgets.ink_label(tv, "", 15 if compact else 17, Color.WHITE, 4)
	_name.add_theme_font_override("font", UiTheme.bold_font())
	_name.clip_text = true
	_name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_line = ForgeWidgets.ink_label(tv, "", UiTheme.MIN_TEXT, UiTheme.color("encre.700", ForgeWidgets.ENCRE), 0)
	_line.clip_text = true
	_line.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_steps = HBoxContainer.new()  # les étapes (plan, insignes, niveau) sous la ligne : le nom garde sa place
	_steps.add_theme_constant_override("separation", 4)
	_steps.visible = not compact
	tv.add_child(_steps)
	_go = ForgeWidgets.candy_button("Y aller", "lagon", 15, 34 if compact else 38)
	_go.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_go.pressed.connect(_on_go)
	h.add_child(_go)
	_next = ForgeWidgets.candy_button("⇄", "papier", 15, 34 if compact else 38)
	_next.tooltip_text = "Objectif suivant"
	_next.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_next.pressed.connect(func():
		Goals.pin_next()
		refresh())
	h.add_child(_next)
	_drop = ForgeWidgets.candy_button("✕", "papier", 15, 34 if compact else 38)
	_drop.tooltip_text = "Ne plus suivre cet objectif"
	_drop.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_drop.pressed.connect(func():
		Goals.unfollow(Goals.pinned())
		refresh())
	h.add_child(_drop)


func _ready() -> void:
	refresh()


## Relit l'objectif épinglé.
func refresh() -> void:
	var p := Goals.pinned()
	_shown = p
	var none := p == ""
	if compact:
		visible = not none
	for c in _steps.get_children():
		_steps.remove_child(c)
		c.queue_free()
	_slot.visible = not none
	_go.visible = not none
	_next.visible = Goals.count() > 1 and not narrow
	_next.text = "⇄ %d" % Goals.count()
	_drop.visible = not none and not narrow
	if none:
		_name.text = "Aucun objectif"
		_line.text = "Choisis une pièce à viser : Atelier > Fabriquer, « ★ Objectif »."
		return
	var s := Goals.status(p)
	_slot.set_item(s.item)
	_slot.goal = true
	_slot.queue_redraw()
	_name.text = String(s.name)
	_line.text = String(s.line).substr(0, 1).to_upper() + String(s.line).substr(1)
	var tip: PackedStringArray = ["★ Objectif : " + String(s.name), _line.text]
	for st in s.steps:
		tip.append(("✓ " if bool(st.ok) else "· ") + String(st.text))
	tooltip_text = "\n".join(tip)
	_name.tooltip_text = tooltip_text
	_line.tooltip_text = tooltip_text
	_name.mouse_filter = Control.MOUSE_FILTER_PASS
	_line.mouse_filter = Control.MOUSE_FILTER_PASS
	_go.text = "Fabriquer" if bool(s.ready) else ("Porter" if bool(s.owned) and not bool(s.worn) else "Y aller")
	_go.disabled = (s.go as Dictionary).is_empty()
	for st in s.steps:
		var chip := PanelContainer.new()
		chip.add_theme_stylebox_override("panel", ForgeWidgets.box(ForgeWidgets.POMME if bool(st.ok) else ForgeWidgets.PAPIER, ForgeWidgets.ENCRE, 9, 2, 2))
		_steps.add_child(chip)
		var l := Label.new()
		l.text = ("✓ " if bool(st.ok) else "") + String(st.text)
		l.add_theme_font_override("font", UiTheme.bold_font())
		l.add_theme_font_size_override("font_size", 13)
		l.add_theme_color_override("font_color", ForgeWidgets.ENCRE)
		chip.add_child(l)


func _on_go() -> void:
	var p := Goals.pinned()
	if p == "":
		return
	var s := Goals.status(p)
	var target: Dictionary = s.go
	if bool(s.ready):
		target = target.duplicate()
		target["goal"] = p
	if go.get_connections().is_empty():
		open_target(self, target)
	else:
		go.emit(target)


## Ouvre l'écran de [param target] (forme des conseils de la boussole) depuis n'importe quel écran du hub : ferme l'écran
## Héros ou l'Atelier ouvert par-dessus si besoin, puis passe la main au menu principal (Lobby._compass_open).
static func open_target(from: Node, target: Dictionary) -> void:
	if target.is_empty() or from == null or not from.is_inside_tree():
		return
	var lobby := from.get_tree().current_scene
	if lobby == null or not lobby.has_method("_compass_open"):
		return
	var n := from.get_parent()
	while n != null:
		if n is HeroScreen and not target.has("hero"):
			(n as HeroScreen).close_ui()
			break
		if n is PageScreen and not target.has("workshop"):
			(n as PageScreen).close_ui()
			break
		n = n.get_parent()
	lobby.call("_compass_open", target)
	if target.has("workshop") and target.has("goal"):
		var ws = lobby.get("_workshop")
		if ws is PageScreen:
			var pg: Control = (ws as PageScreen).page(int(target.workshop))
			if pg != null and pg.has_method("show_goal"):
				pg.call("show_goal", String(target.goal))
