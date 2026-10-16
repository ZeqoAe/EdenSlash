class_name AutochessShop
extends HBoxContainer
## L'Échiquier (lot AC-G) : la boutique, 5 offres (SPEC §5.2, §7.1). Une carte = bord et bandeau de la couleur du coût,
## portrait, nom, 2 traits, coût, et les copies déjà possédées (pastilles : la dernière qui manque pour une étoile de plus
## fait briller la carte). Achat : clic, A à la manette (UiNav), touches 1 à 5 (l'écran). Une carte trop chère reste
## navigable mais grisée ; une case achetée reste vide jusqu'à la prochaine actualisation.

signal buy_requested(slot: int)

const CARD_H := 108.0
const CARD_W := 148.0
const CARD_W_WIDE := 176.0

var cards: Array = []  # Button par case
var hovered := -1  # carte sous la souris (-1 : aucune)
var _sig := ""


func _init() -> void:
	name = "AcShop"
	add_theme_constant_override("separation", 8)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i in AutochessData.SHOP_SIZE:
		var b := Button.new()
		b.name = "AcShopCard_%d" % i
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(CARD_W, CARD_H)
		b.clip_contents = true
		b.set_meta("ac_shop", i)
		b.pressed.connect(func(): buy_requested.emit(i))
		b.mouse_entered.connect(func(): hovered = i)
		b.mouse_exited.connect(func():
			if hovered == i:
				hovered = -1)
		add_child(b)
		cards.append(b)
		_build_card(b)


func _build_card(b: Button) -> void:
	var m := MarginContainer.new()
	m.set_anchors_preset(Control.PRESET_FULL_RECT)
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for s in ["left", "right"]:
		m.add_theme_constant_override("margin_" + s, 8)
	m.add_theme_constant_override("margin_top", 10)
	m.add_theme_constant_override("margin_bottom", 4)
	b.add_child(m)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 1)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m.add_child(v)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(h)
	var ic := TextureRect.new()
	ic.name = "Icon"
	ic.custom_minimum_size = Vector2(40, 40)
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(ic)
	var nm := AutochessHud.lbl("", 15, UiTheme.TEXT, "bold")
	nm.name = "Name"
	nm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nm.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	nm.max_lines_visible = 2
	h.add_child(nm)
	var tr := AutochessHud.lbl("", 14, UiTheme.MUTED)
	tr.name = "Traits"
	tr.clip_text = true
	tr.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	v.add_child(tr)
	var sp := Control.new()
	sp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(sp)
	var foot := HBoxContainer.new()
	foot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(foot)
	var pips := Pips.new()
	pips.name = "Pips"
	foot.add_child(pips)
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	foot.add_child(gap)
	var cost := AutochessHud.lbl("", 16, UiTheme.GOLD, "bold")
	cost.name = "Cost"
	foot.add_child(cost)
	var key := AutochessHud.lbl("", 12, Color(UiTheme.MUTED, 0.7))
	key.name = "Key"
	key.position = Vector2(CARD_W - 16, 3)
	key.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(key)


## Rappel de la touche (1 à 5) au clavier, rien à la manette.
func refresh_keys() -> void:
	for i in cards.size():
		var key: Label = (cards[i] as Button).find_child("Key", true, false)
		key.text = "" if Gamepad.active else str(i + 1)


## Met les 5 cartes à jour pour le stratège [param pi].
func refresh(g: Autochess, pi: int) -> void:
	var p: Dictionary = g.players[pi]
	var wide := get_viewport_rect().size.x >= 1500.0
	var sig := "%s|%d|%s|%s|%s" % [str(p.shop), int(p.gold), str(g.units_of(pi).map(func(u): return [u.id, u.stars])), wide,
		Gamepad.active]
	if sig == _sig:
		return
	_sig = sig
	for i in cards.size():
		var b: Button = cards[i]
		b.custom_minimum_size.x = CARD_W_WIDE if wide else CARD_W
		var id := String(p.shop[i]) if i < (p.shop as Array).size() else ""
		var icon: TextureRect = b.find_child("Icon", true, false)
		var nm: Label = b.find_child("Name", true, false)
		var tr: Label = b.find_child("Traits", true, false)
		var cost_l: Label = b.find_child("Cost", true, false)
		var pips: Pips = b.find_child("Pips", true, false)
		var key: Label = b.find_child("Key", true, false)
		key.text = "" if Gamepad.active else str(i + 1)
		key.position.x = b.custom_minimum_size.x - 14.0
		b.set_meta("unit_id", id)
		if id == "":
			icon.texture = null
			nm.text = ""
			tr.text = ""
			cost_l.text = ""
			pips.need = 0
			pips.queue_redraw()
			b.tooltip_text = ""
			b.modulate = Color(1, 1, 1, 0.55)
			_style(b, Color(0.25, 0.27, 0.4), false, true)
			continue
		var d := AutochessData.unit(id)
		var cost := int(d.get("cost", 1))
		icon.texture = UiTheme.texture(String(GameData.class_data(id).get("icon", "")))
		nm.text = AutochessData.unit_name(id)
		tr.text = " · ".join((d.get("traits", []) as Array).map(func(t): return String(AutochessData.TRAITS.get(t, {}).get("name", t))))
		cost_l.text = "%d or" % cost
		var have := 0
		for u in g.units_of(pi):
			if String(u.id) == id and int(u.stars) == 1:
				have += 1
		var need := int(g._need(p, id, 1))
		pips.need = need
		pips.have = mini(have, need - 1)
		pips.queue_redraw()
		var star_up := have + 1 >= need
		var afford := int(p.gold) >= cost
		b.modulate = Color(1, 1, 1, 1) if afford else Color(0.75, 0.75, 0.8, 0.6)
		b.tooltip_text = "%s · %s\n%s" % [AutochessData.unit_name(id), String(AutochessData.ROLES.get(String(d.get("role", "")), {}).get("name", "")),
			"Une copie de plus : une étoile !" if star_up else "Trois copies : une étoile de plus."]
		_style(b, AutochessBoard.cost_color(cost), star_up, false)


func _style(b: Button, col: Color, glow: bool, empty: bool) -> void:
	var bg := Color(0.07, 0.08, 0.19, 0.96) if not empty else Color(0.05, 0.05, 0.12, 0.6)
	var n := AutochessHud.box(bg, col.darkened(0.1) if not glow else UiTheme.GOLD, 3 if glow else 2, 8, 0, 0)
	n.border_width_top = 6
	if glow:
		n.shadow_color = Color(UiTheme.GOLD, 0.45)
		n.shadow_size = 8
	var hv := n.duplicate() as StyleBoxFlat
	hv.bg_color = bg.lightened(0.12)
	hv.border_color = UiTheme.GOLD
	for st in ["normal", "disabled", "focus"]:
		b.add_theme_stylebox_override(st, n)
	b.add_theme_stylebox_override("hover", hv)
	b.add_theme_stylebox_override("pressed", hv)


## Copies possédées vers l'étoile suivante.
class Pips extends Control:
	var need := 0
	var have := 0

	func _init() -> void:
		custom_minimum_size = Vector2(44, 16)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		if need <= 0:
			return
		for i in need:
			var c := Vector2(7.0 + i * 14.0, size.y * 0.5)
			var pts := PackedVector2Array([c + Vector2(0, -5), c + Vector2(5, 0), c + Vector2(0, 5), c + Vector2(-5, 0)])
			if i < have:
				draw_colored_polygon(pts, UiTheme.GOLD)
			elif i == need - 1:
				draw_colored_polygon(pts, Color(UiTheme.GOLD, 0.25))
			pts.append(pts[0])
			draw_polyline(pts, UiTheme.GOLD_DIM, 1.2, true)
