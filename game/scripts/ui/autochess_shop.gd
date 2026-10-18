class_name AutochessShop
extends HBoxContainer
## L'Échiquier (lot AC-G, boutique v2 du lot ACX-1) : 5 offres (SPEC §5.2, §7.1 ; étude BM-AUTO §7.1). Une carte = autocollant
## papier : bandeau de la couleur du coût, icône de classe sur sa tuile, nom, 2 tuiles de trait (couleur de la famille ;
## armes en lagon clair ; flèche pomme sur la tuile d'un trait qui monterait d'un palier), pastille de coût soleil en bas à
## droite, copies déjà possédées en bas à gauche ; quand l'achat fait monter une étoile : halo soleil, étoile autocollant
## dans le coin et mini ★★ / ★★★ du résultat. Survol d'un trait de la colonne : les cartes de ce trait s'entourent de lagon.
## Achat : clic, A à la manette (UiNav), touches 1 à 5 (l'écran). Une carte trop chère reste navigable mais grisée ; une case
## achetée reste vide jusqu'à la prochaine actualisation.
## Lot ACX-3 : les héros visés du planificateur (AutochessPlanner) portent une cible fraise en haut à droite.

signal buy_requested(slot: int)

const CARD_H := 124.0
const CARD_W := 152.0
const CARD_W_WIDE := 176.0
const CARD_H_NARROW := 112.0

var cards: Array = []  # Button par case
var hovered := -1  # carte sous la souris (-1 : aucune)
var marked_trait := ""  # trait survolé dans la colonne : ses cartes s'entourent de lagon
var info: Array = []  # par carte : {id, star_up, stars, rising: [traits], afford}
var _sig := ""


func _init() -> void:
	name = "AcShop"
	add_theme_constant_override("separation", roundi(AutochessHud.s(10.0)))
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i in AutochessData.SHOP_SIZE:
		var b := Button.new()
		b.name = "AcShopCard_%d" % i
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(CARD_W, CARD_H)
		b.set_meta("ac_shop", i)
		b.set_meta("ui_feel", "card")
		b.pressed.connect(func(): buy_requested.emit(i))
		b.mouse_entered.connect(func(): hovered = i)
		b.mouse_exited.connect(func():
			if hovered == i:
				hovered = -1)
		add_child(b)
		cards.append(b)
		info.append({})
		_build_card(b)


func _build_card(b: Button) -> void:
	var halo := Halo.new()
	halo.name = "Halo"
	halo.set_anchors_preset(Control.PRESET_FULL_RECT)
	b.add_child(halo)
	var band := Panel.new()
	band.name = "Band"
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	band.anchor_right = 1.0
	band.offset_left = 3.0
	band.offset_right = -3.0
	band.offset_top = 3.0
	band.offset_bottom = 3.0 + AutochessHud.s(10.0)
	b.add_child(band)
	var m := MarginContainer.new()
	m.set_anchors_preset(Control.PRESET_FULL_RECT)
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for s in ["left", "right"]:
		m.add_theme_constant_override("margin_" + s, roundi(AutochessHud.s(8.0)))
	m.add_theme_constant_override("margin_top", roundi(AutochessHud.s(17.0)))
	m.add_theme_constant_override("margin_bottom", roundi(AutochessHud.s(6.0)))
	b.add_child(m)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", roundi(AutochessHud.s(5.0)))
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m.add_child(v)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", roundi(AutochessHud.s(7.0)))
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(h)
	var tile := PanelContainer.new()
	tile.name = "Tile"
	tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	h.add_child(tile)
	var ic := TextureRect.new()
	ic.name = "Icon"
	var side := AutochessHud.s(40.0)
	ic.custom_minimum_size = Vector2(side, side)
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile.add_child(ic)
	var nm := AutochessHud.ink_lbl("", 15, AutochessHud.INK, 900)
	nm.name = "Name"
	nm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nm.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	nm.max_lines_visible = 2
	nm.add_theme_constant_override("line_spacing", -3)
	h.add_child(nm)
	var tr := HBoxContainer.new()
	tr.name = "Traits"
	tr.add_theme_constant_override("separation", roundi(AutochessHud.s(4.0)))
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(tr)
	for j in 2:
		tr.add_child(_chip())
	var sp := Control.new()
	sp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(sp)
	var foot := HBoxContainer.new()
	foot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	foot.add_theme_constant_override("separation", roundi(AutochessHud.s(4.0)))
	v.add_child(foot)
	var pips := Pips.new()
	pips.name = "Pips"
	foot.add_child(pips)
	var mini := MiniStars.new()
	mini.name = "Stars"
	foot.add_child(mini)
	var third := _chip()  # lot ACX-4 : 3e trait d'une unité pont, dans le pied de la carte (la hauteur ne change pas)
	third.name = "Chip3"
	third.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	foot.add_child(third)
	var cost := CostBadge.new()
	cost.name = "Cost"
	b.add_child(cost)
	var star := StarSticker.new()
	star.name = "StarUp"
	b.add_child(star)
	var key := AutochessHud.key_chip("")
	key.name = "Key"
	b.add_child(key)
	var plan := PlanMark.new()
	plan.name = "Plan"
	b.add_child(plan)


## Tuile de trait : aplat de la couleur du trait, contour d'encre, flèche pomme quand le trait monterait.
func _chip() -> PanelContainer:
	var c := PanelContainer.new()
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 2)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_child(h)
	var up := UpArrow.new()
	up.name = "Up"
	h.add_child(up)
	var l := AutochessHud.ink_lbl("", 14, AutochessHud.INK, 800)
	l.name = "Text"
	h.add_child(l)
	return c


## Rappel de la touche (1 à 5) au clavier, rien à la manette.
func refresh_keys() -> void:
	for i in cards.size():
		_key(cards[i] as Button, i)


## Touche de la carte (1 à 5) en pastille dans le coin haut-droit, sur le bandeau du coût (rien à la manette).
func _key(b: Button, i: int) -> void:
	var key: Label = b.get_node("Key")
	AutochessHud.set_key_chip(key, "" if Gamepad.active else str(i + 1), false)
	key.offset_top = AutochessHud.s(4.0)
	key.offset_bottom = AutochessHud.s(4.0) + 20.0
	key.offset_left -= 12.0
	key.offset_right -= 12.0


## Met les 5 cartes à jour pour le stratège [param pi].
func refresh(g: Autochess, pi: int) -> void:
	var p: Dictionary = g.players[pi]
	var wide := get_viewport_rect().size.x >= 1500.0
	var counts := g.trait_counts(pi)
	var planned := AutochessPlanner.planned()
	var sig := "%s|%d|%s|%s|%s|%s|%s|%s" % [str(p.shop), int(p.gold), str(g.units_of(pi).map(func(u): return [u.id, u.stars])), wide,
		Gamepad.active, str(counts), str(p.augments), str(planned)]
	if sig == _sig:
		return
	_sig = sig
	var on_board := {}
	for u in p.board:
		on_board[String(u.id)] = true
	for i in cards.size():
		var b: Button = cards[i]
		b.custom_minimum_size = Vector2(CARD_W_WIDE if wide else CARD_W, CARD_H if wide else CARD_H_NARROW)
		var id := String(p.shop[i]) if i < (p.shop as Array).size() else ""
		var icon: TextureRect = b.find_child("Icon", true, false)
		var nm: Label = b.find_child("Name", true, false)
		var tr: HBoxContainer = b.find_child("Traits", true, false)
		var cost_b: CostBadge = b.get_node("Cost")
		var pips: Pips = b.find_child("Pips", true, false)
		var mini: MiniStars = b.find_child("Stars", true, false)
		var star: StarSticker = b.get_node("StarUp")
		var plan: PlanMark = b.get_node("Plan")
		plan.visible = id != "" and id in planned
		_key(b, i)
		b.set_meta("unit_id", id)
		if id == "":
			info[i] = {}
			icon.texture = null
			(icon.get_parent() as Control).visible = false
			nm.text = ""
			tr.visible = false
			(b.find_child("Chip3", true, false) as Control).visible = false
			cost_b.cost = 0
			cost_b.queue_redraw()
			pips.need = 0
			pips.queue_redraw()
			mini.stars = 0
			mini.queue_redraw()
			star.visible = false
			b.tooltip_text = ""
			b.modulate = Color(1, 1, 1, 0.75)
			_style(b, 0, false, true, false)
			continue
		(icon.get_parent() as Control).visible = true
		tr.visible = true
		var d := AutochessData.unit(id)
		var cost := int(d.get("cost", 1))
		icon.texture = UiTheme.texture(String(GameData.class_data(id).get("icon", "")))
		(icon.get_parent() as PanelContainer).add_theme_stylebox_override("panel",
			AutochessHud.sticker(AutochessHud.cost_candy(cost, 0), 10.0, 0.0, 2.0, 2.0, 2.0))
		nm.text = AutochessData.unit_name(id)
		# copies possédées, étoile d'amélioration (et ★★★ si les ★★ fusionnent aussi)
		var have := g._count_star(p, id, 1)
		var need := int(g._need(p, id, 1))
		var star_up := have + 1 >= need
		var stars := 1
		if star_up:
			stars = 2
			if g._count_star(p, id, 2) + 1 >= int(g._need(p, id, 2)):
				stars = 3
		pips.need = need
		pips.have = mini(have, need - 1)
		pips.queue_redraw()
		mini.stars = stars if star_up else 0
		mini.queue_redraw()
		star.visible = star_up
		cost_b.cost = cost
		cost_b.queue_redraw()
		# tuiles de trait ; flèche quand l'achat ferait monter le trait d'un palier (héros pas encore sur le plateau)
		var rising: Array = []
		var tl: Array = d.get("traits", [])
		for j in 3:
			var chip: PanelContainer = tr.get_child(j) if j < 2 else b.find_child("Chip3", true, false)
			chip.visible = j < tl.size()
			if j >= tl.size():
				continue
			var t := String(tl[j])
			var n := int(counts.get(t, 0))
			var up := not on_board.has(id) and AutochessData.trait_thresholds(t).has(n + 1)
			if up:
				rising.append(t)
			(chip.find_child("Up", true, false) as Control).visible = up
			(chip.find_child("Text", true, false) as Label).text = String(AutochessData.TRAITS.get(t, {}).get("name", t))
			var fam := String(AutochessData.TRAITS.get(t, {}).get("kind", "")) == "famille"
			var csb := AutochessHud.sticker(AutochessHud.trait_candy(t, 0 if fam else 1), 8.0, 0.0, 2.0, 5.0, 0.0)
			chip.add_theme_stylebox_override("panel", csb)
		var afford := int(p.gold) >= cost
		info[i] = {"id": id, "star_up": star_up, "stars": stars, "rising": rising, "afford": afford, "cost": cost,
			"planned": id in planned}
		b.modulate = Color(1, 1, 1, 1) if afford else Color(0.82, 0.8, 0.88, 0.85)
		var tip := "%s · %s" % [AutochessData.unit_name(id), String(AutochessData.ROLES.get(String(d.get("role", "")), {}).get("name", ""))]
		if star_up:
			tip += "\n" + ("Une copie de plus : trois étoiles !" if stars == 3 else "Une copie de plus : une étoile !")
		else:
			tip += "\nTrois copies : une étoile de plus."
		for t in rising:
			tip += "\n%s monte d'un palier." % String(AutochessData.TRAITS.get(t, {}).get("name", t))
		tip += "\nHéros visé (T pour l'enlever)." if id in planned else "\nT : viser ce héros."
		b.tooltip_text = tip
		_style(b, cost, star_up, false, afford)
	_apply_mark()


## Survol d'un trait de la colonne : les cartes de ce trait s'entourent de lagon ("" : aucune).
func mark_trait(t: String) -> void:
	if t == marked_trait:
		return
	marked_trait = t
	_apply_mark()


## Cases dont l'offre porte le trait marqué (tests).
func marked_cards() -> Array:
	var out: Array = []
	for i in cards.size():
		if (cards[i] as Button).get_meta("marked", false):
			out.append(i)
	return out


func _apply_mark() -> void:
	for i in cards.size():
		var b: Button = cards[i]
		var id := String(b.get_meta("unit_id", ""))
		var on := marked_trait != "" and id != "" and (AutochessData.unit(id).get("traits", []) as Array).has(marked_trait)
		b.set_meta("marked", on)
		var halo: Halo = b.get_node("Halo")
		halo.mark = on
		halo.queue_redraw()


func _style(b: Button, cost: int, glow: bool, empty: bool, afford: bool) -> void:
	var fill := AutochessHud.PAPER if not empty else AutochessHud.PAPER_300
	if not empty and not afford:
		fill = AutochessHud.GRAY
	var n := AutochessHud.sticker(fill, 14.0, 0.0 if empty else 5.0, 3.0, 0.0, 0.0)
	if empty:
		n.border_color = Color(AutochessHud.INK, 0.35)
	var hv := AutochessHud.sticker(Color.WHITE if not empty else fill, 14.0, 0.0 if empty else 8.0, 3.0, 0.0, 0.0)
	var pr := AutochessHud.sticker(AutochessHud.PAPER_300, 14.0, 1.0, 3.0, 0.0, 0.0)
	for st in ["normal", "disabled", "focus"]:
		b.add_theme_stylebox_override(st, n)
	b.add_theme_stylebox_override("hover", hv)
	b.add_theme_stylebox_override("pressed", pr)
	b.add_theme_stylebox_override("hover_pressed", pr)
	var band: Panel = b.get_node("Band")
	band.visible = not empty
	if not empty:
		var bs := StyleBoxFlat.new()
		bs.bg_color = AutochessHud.cost_candy(cost)
		var r := maxi(roundi(14.0 * AutochessHud.k) - 3, 2)
		bs.corner_radius_top_left = r
		bs.corner_radius_top_right = r
		bs.border_color = AutochessHud.INK
		bs.border_width_bottom = 2
		bs.anti_aliasing = true
		band.add_theme_stylebox_override("panel", bs)
	var halo: Halo = b.get_node("Halo")
	halo.glow = glow
	halo.queue_redraw()


# --- petits dessins -------------------------------------------------------------------------------------------------
## Halo autour de la carte : soleil quand l'achat fait monter une étoile, lagon quand son trait est survolé.
class Halo extends Control:
	var glow := false
	var mark := false

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		if not glow and not mark:
			return
		var sb := StyleBoxFlat.new()
		sb.draw_center = false
		sb.set_corner_radius_all(roundi(18.0 * AutochessHud.k))
		sb.anti_aliasing = true
		if glow:
			sb.border_color = AutochessHud.candy("soleil", 0)
			sb.set_border_width_all(5)
			draw_style_box(sb, Rect2(Vector2(-6, -6), size + Vector2(12, 14)))
		if mark:
			sb.border_color = AutochessHud.candy("lagon", 2)
			sb.set_border_width_all(4)
			draw_style_box(sb, Rect2(Vector2(-5, -5), size + Vector2(10, 12)))


## Pastille de coût (soleil, chiffre blanc contouré) qui déborde du coin bas-droit.
class CostBadge extends Control:
	var cost := 0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		anchor_left = 1.0
		anchor_right = 1.0
		anchor_top = 1.0
		anchor_bottom = 1.0
		var d := AutochessHud.s(32.0)
		offset_left = -d + AutochessHud.s(8.0)
		offset_right = AutochessHud.s(8.0)
		offset_top = -d + AutochessHud.s(8.0)
		offset_bottom = AutochessHud.s(8.0)

	func _draw() -> void:
		if cost <= 0:
			return
		var c := size * 0.5
		var r := size.x * 0.5 - 1.0
		draw_circle(c + Vector2(0, 3), r, AutochessHud.INK)
		draw_circle(c, r, AutochessHud.candy("soleil"))
		draw_arc(c, r, 0.0, TAU, 28, AutochessHud.INK, 2.5, true)
		var f := AutochessHud.pop_font()
		var s := str(cost)
		var fs := AutochessHud.fs(18)
		var w := f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var at := Vector2(c.x - w * 0.5, c.y + fs * 0.36)
		draw_string_outline(f, at, s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 5, AutochessHud.INK)
		draw_string(f, at, s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)


## Étoile autocollant inclinée dans le coin haut-gauche : l'achat fait monter une étoile.
class StarSticker extends Control:
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		var d := AutochessHud.s(30.0)
		position = Vector2(-AutochessHud.s(12.0), -AutochessHud.s(13.0))
		size = Vector2(d, d)
		visible = false

	func _draw() -> void:
		var c := size * 0.5
		draw_set_transform(c, deg_to_rad(-12.0))
		AutochessHud.draw_star(self, Vector2(0, 2), size.x * 0.5, AutochessHud.INK, 1.0)
		AutochessHud.draw_star(self, Vector2.ZERO, size.x * 0.5, AutochessHud.candy("soleil"), 2.5)


## Cible fraise du planificateur (lot ACX-3) : héros visé, en haut à droite sous la touche.
class PlanMark extends Control:
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		anchor_left = 1.0
		anchor_right = 1.0
		var d := AutochessHud.s(22.0)
		offset_left = -d - AutochessHud.s(5.0)
		offset_right = -AutochessHud.s(5.0)
		offset_top = AutochessHud.s(30.0)
		offset_bottom = AutochessHud.s(30.0) + d
		visible = false

	func _draw() -> void:
		var c := size * 0.5
		var r := size.x * 0.5 - 1.0
		draw_circle(c + Vector2(0, 2), r, AutochessHud.INK)
		draw_circle(c, r, AutochessHud.candy("fraise"))
		draw_circle(c, r * 0.62, AutochessHud.PAPER)
		draw_circle(c, r * 0.3, AutochessHud.candy("fraise"))
		draw_arc(c, r, 0.0, TAU, 24, AutochessHud.INK, 2.0, true)


## Mini étoiles du résultat de la fusion (★★ ou ★★★).
class MiniStars extends Control:
	var stars := 0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		custom_minimum_size = Vector2(AutochessHud.s(40.0), AutochessHud.s(15.0))

	func _draw() -> void:
		var r := AutochessHud.s(6.5)
		for i in stars:
			AutochessHud.draw_star(self, Vector2(r + 1.0 + i * (r * 1.9), size.y * 0.5), r, AutochessHud.candy("soleil"), 1.5)


## Petite flèche pomme (le trait monte).
class UpArrow extends Control:
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		custom_minimum_size = Vector2(AutochessHud.s(11.0), AutochessHud.s(12.0))
		size_flags_vertical = Control.SIZE_SHRINK_CENTER
		visible = false

	func _draw() -> void:
		var w := size.x
		var h := size.y
		var pts := PackedVector2Array([Vector2(w * 0.5, 0.5), Vector2(w - 0.5, h * 0.62), Vector2(w * 0.7, h * 0.62),
			Vector2(w * 0.7, h - 0.5), Vector2(w * 0.3, h - 0.5), Vector2(w * 0.3, h * 0.62), Vector2(0.5, h * 0.62)])
		draw_colored_polygon(pts, AutochessHud.candy("pomme"))
		pts.append(pts[0])
		draw_polyline(pts, AutochessHud.INK, 1.5, true)


## Copies possédées vers l'étoile suivante : losanges contourés (soleil = possédée, soleil clair = celle qu'on achète).
class Pips extends Control:
	var need := 0
	var have := 0

	func _init() -> void:
		custom_minimum_size = Vector2(AutochessHud.s(40.0), AutochessHud.s(15.0))
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		if need <= 0:
			return
		var r := AutochessHud.s(5.0)
		for i in need:
			var c := Vector2(r + 1.0 + i * (r * 2.5), size.y * 0.5)
			var pts := PackedVector2Array([c + Vector2(0, -r), c + Vector2(r, 0), c + Vector2(0, r), c + Vector2(-r, 0)])
			var col := AutochessHud.PAPER
			if i < have:
				col = AutochessHud.candy("soleil")
			elif i == need - 1 and have >= need - 1:
				col = AutochessHud.candy("soleil", 0)
			draw_colored_polygon(pts, col)
			pts.append(pts[0])
			draw_polyline(pts, AutochessHud.INK, 1.5, true)
