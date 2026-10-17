class_name AutochessUnitCard
extends PanelContainer
## L'Échiquier (lot AC-G, bulle v2 du lot ACX-1) : fiche d'une unité (« Qui est-ce ? », SPEC §7.1). Bulle papier qui sort de
## ce qu'on vise (souris ou cadre de la manette : case du plateau ou du banc, carte de la boutique, objet du banc d'objets),
## avec une queue tournée vers lui ; elle ne cache jamais la colonne des traits (AutochessScreen la place : place_near).
## Portrait, nom, étoiles, coût, rôle, 2 traits (compte actuel / palier suivant), sort signature (type, mana), PV, attaque
## et portée en jauges, objets portés. Texte permanent sans pourcentage : les chiffres sont dans les infobulles.
## Rapports : conception/autochess/R_AC_G.md, R_ACX1.md.

const W := 250.0
const STAR_COLORS := AutochessBoard.STAR_COLORS
const TAIL := 12.0  # px : longueur de la queue de la bulle
const SHADOW := 6.0  # px : ombre dure de la bulle (réservée en bas du rectangle)

var _icon: TextureRect
var _name: Label
var _stars: Label
var _cost: Label
var _role: Label
var _body: VBoxContainer
var _what := ""  # ce qui est montré (évite de tout refaire à chaque image)
var _tail_side := ""  # left, right, top, bottom : côté de la bulle où sort la queue ("" : aucune)
var _tail_at := 0.0  # position de la queue le long de ce côté (px)

static var _max_base := {}  # plus grandes valeurs de base (hp, atk) parmi les 60 classes


func _init() -> void:
	name = "AcUnitCard"
	custom_minimum_size = Vector2(AutochessHud.s(W), 0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_set_panel(AutochessHud.INK)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", roundi(AutochessHud.s(6.0)))
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(v)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", roundi(AutochessHud.s(8.0)))
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(head)
	var tile := PanelContainer.new()
	tile.name = "Tile"
	tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	head.add_child(tile)
	_icon = TextureRect.new()
	_icon.custom_minimum_size = Vector2(AutochessHud.s(44.0), AutochessHud.s(44.0))
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile.add_child(_icon)
	var hv := VBoxContainer.new()
	hv.add_theme_constant_override("separation", 0)
	hv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(hv)
	_name = AutochessHud.pop_lbl("", 18, AutochessHud.INK)
	_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hv.add_child(_name)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hv.add_child(row)
	_stars = AutochessHud.ink_lbl("", 17, STAR_COLORS[0], 900)
	_stars.add_theme_constant_override("outline_size", 4)
	_stars.add_theme_color_override("font_outline_color", AutochessHud.INK)
	row.add_child(_stars)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(sp)
	_cost = AutochessHud.ink_lbl("", 14, AutochessHud.INK, 900)
	row.add_child(_cost)
	_role = AutochessHud.ink_lbl("", 14, AutochessHud.INK_300, 700)
	v.add_child(_role)
	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", roundi(AutochessHud.s(5.0)))
	_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(_body)
	visible = false


func _set_panel(_border: Color) -> void:
	if not has_theme_stylebox_override("panel"):
		add_theme_stylebox_override("panel", AutochessHud.paper_panel(SHADOW, 12.0, 10.0, 16.0))


## Unité [param u] ({id, stars, items}) ; [param counts] : compte de chaque trait du stratège (Autochess.trait_counts).
func show_unit(u: Dictionary, counts: Dictionary = {}, from_shop := false) -> void:
	var id := String(u.get("id", ""))
	var stars := clampi(int(u.get("stars", 1)), 1, AutochessData.MAX_STARS)
	var items: Array = u.get("items", [])
	var key := "u:%s/%d/%s/%s/%s" % [id, stars, ",".join(items), str(counts), from_shop]
	if key == _what and visible:
		return
	_what = key
	var d := AutochessData.unit(id)
	if d.is_empty():
		hide_card()
		return
	var cls := GameData.class_data(id)
	var cost := int(d.get("cost", 1))
	_icon.texture = UiTheme.texture(String(cls.get("icon", "")))
	(_icon.get_parent() as PanelContainer).add_theme_stylebox_override("panel",
		AutochessHud.sticker(AutochessHud.cost_candy(cost, 0), 10.0, 0.0, 2.0, 2.0, 2.0))
	_name.text = AutochessData.unit_name(id)
	_stars.text = "★".repeat(stars)
	_stars.add_theme_color_override("font_color", STAR_COLORS[stars - 1])
	_cost.text = "%d or" % cost
	_cost.add_theme_stylebox_override("normal", AutochessHud.sticker(AutochessHud.cost_candy(cost, 0), 8.0, 0.0, 2.0, 6.0, 0.0))
	var role: Dictionary = AutochessData.ROLES.get(String(d.get("role", "")), {})
	_role.text = "%s · %s" % [String(role.get("name", "")), String(AutochessData.PLACES.get(String(d.get("place", "")), ""))]
	_role.tooltip_text = String(role.get("short", ""))
	_role.mouse_filter = Control.MOUSE_FILTER_PASS
	_set_panel(AutochessHud.INK)
	_clear()
	# traits : pastille, nom, compte actuel / palier suivant
	var traits := Autochess.unit_traits(u)
	for t in traits:
		var td: Dictionary = AutochessData.TRAITS.get(String(t), {})
		if td.is_empty():
			continue
		var n := int(counts.get(t, 0))
		var tier := AutochessData.trait_tier(String(t), n)
		var ths: Array = AutochessData.trait_thresholds(String(t))
		var nxt := 0
		for th in ths:
			if n < int(th):
				nxt = int(th)
				break
		var r := HBoxContainer.new()
		r.add_theme_constant_override("separation", roundi(AutochessHud.s(6.0)))
		r.mouse_filter = Control.MOUSE_FILTER_PASS
		r.tooltip_text = "%s\n%s" % [String(td.short), String(td.tip)]
		var badge := AutochessTraitPanel.badge(n if not counts.is_empty() else 0, tier if not counts.is_empty() else 1, String(t))
		r.add_child(badge)
		var tl := AutochessHud.ink_lbl(String(td.name), 15, AutochessHud.INK if tier > 0 or counts.is_empty() else AutochessHud.INK_300, 800)
		tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		r.add_child(tl)
		if not counts.is_empty():
			r.add_child(AutochessHud.ink_lbl("%d / %d" % [n, nxt] if nxt > 0 else "%d" % n, 14, AutochessHud.INK_300, 900))
		_body.add_child(r)
	_body.add_child(_sep())
	# sort signature
	var spell := HBoxContainer.new()
	spell.mouse_filter = Control.MOUSE_FILTER_PASS
	spell.add_theme_constant_override("separation", roundi(AutochessHud.s(7.0)))
	var sk := _skill(cls, int(d.get("skill_id", 0)))
	var st := PanelContainer.new()
	st.mouse_filter = Control.MOUSE_FILTER_IGNORE
	st.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	st.add_theme_stylebox_override("panel", AutochessHud.sticker(AutochessHud.INK_500, 8.0, 0.0, 2.0, 1.0, 1.0))
	var sic := TextureRect.new()
	sic.custom_minimum_size = Vector2(AutochessHud.s(30.0), AutochessHud.s(30.0))
	sic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	sic.texture = UiTheme.texture(String(sk.get("icon", "")))
	sic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	st.add_child(sic)
	spell.add_child(st)
	var sv := VBoxContainer.new()
	sv.add_theme_constant_override("separation", 0)
	sv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spell.add_child(sv)
	var sname := AutochessHud.ink_lbl(String(sk.get("name", d.get("skill_name", ""))), 15, AutochessHud.candy("lagon", 2), 900)
	sname.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sv.add_child(sname)
	var kind := String(AutochessData.SPELL_TYPE_NAMES.get(String(d.get("spell_type", "")), ""))
	sv.add_child(AutochessHud.ink_lbl("%s · %d mana" % [kind, int(d.get("mana", 0))], 14, AutochessHud.INK_300, 700))
	var tip := String(sk.get("desc", ""))
	if stars >= AutochessData.MAX_STARS:
		tip += "\nTrois étoiles : un second sort suit le premier."
	spell.tooltip_text = tip
	_body.add_child(spell)
	# PV, attaque, portée
	var base: Dictionary = cls.get("base", {})
	var mult := AutochessData.stat_mult(cost, stars)
	var mb := _max_bases()
	var top_mult := AutochessData.stat_mult(5, AutochessData.MAX_STARS)
	var mult_tip := "Coût %d et %d étoile(s) : ×%s" % [cost, stars, String.num(mult, 2).replace(".", ",")]
	_body.add_child(_bar("PV", sqrt(float(base.get("hp", 1.0)) * mult / (float(mb.hp) * top_mult)), AutochessHud.candy("fraise"), mult_tip))
	_body.add_child(_bar("Attaque", sqrt(float(base.get("atk", 1.0)) * mult / (float(mb.atk) * top_mult)), AutochessHud.candy("soleil"), mult_tip))
	var rng := int(d.get("range", 1))
	_body.add_child(_bar("Portée", float(rng) / 4.0, AutochessHud.candy("lagon"),
		"Mêlée" if rng <= 1 else "%d cases" % rng))
	# objets portés
	if not items.is_empty():
		_body.add_child(_sep())
		for it in items:
			_body.add_child(item_row(String(it)))
	elif from_shop:
		pass
	visible = true
	reset_size()


## Objet [param id] du banc d'objets (composant, objet complet, emblème, marteau).
func show_item(id: String) -> void:
	var key := "i:" + id
	if key == _what and visible:
		return
	_what = key
	var info := Autochess.parse_item(id)
	var d := AutochessData.item(String(info.id))
	if d.is_empty():
		hide_card()
		return
	_icon.texture = item_icon(id)
	(_icon.get_parent() as PanelContainer).add_theme_stylebox_override("panel",
		AutochessHud.sticker(AutochessHud.INK_500, 10.0, 0.0, 2.0, 2.0, 2.0))
	_name.text = item_name(id)
	_stars.text = ""
	_cost.text = ""
	_cost.remove_theme_stylebox_override("normal")
	_set_panel(AutochessHud.INK)
	var parts: Array = d.get("parts", [])
	if AutochessData.COMPONENTS.has(String(info.id)):
		_role.text = "Composant"
	elif String(info.id) in ["embleme", "couronne", "marteau_reforge"]:
		_role.text = "Objet rare"
	else:
		_role.text = "Objet"
	_clear()
	var s := AutochessHud.ink_lbl(String(d.get("short", "")), 15, AutochessHud.INK, 700)
	s.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	s.custom_minimum_size.x = AutochessHud.s(W) - 26.0
	s.tooltip_text = String(d.get("tip", ""))
	s.mouse_filter = Control.MOUSE_FILTER_PASS
	_body.add_child(s)
	if AutochessData.ITEMS.has(String(info.id)) and parts.size() == 2:
		_body.add_child(_sep())
		var r := AutochessHud.ink_lbl("%s + %s" % [AutochessData.item(String(parts[0])).get("name", ""),
			AutochessData.item(String(parts[1])).get("name", "")], 14, AutochessHud.INK_300, 700)
		r.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		r.custom_minimum_size.x = AutochessHud.s(W) - 26.0
		_body.add_child(r)
	elif AutochessData.COMPONENTS.has(String(info.id)):
		var r := AutochessHud.ink_lbl("Pose-le sur un héros : deux composants font un objet.", 14, AutochessHud.INK_300, 700)
		r.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		r.custom_minimum_size.x = AutochessHud.s(W) - 26.0
		_body.add_child(r)
	visible = true
	reset_size()


func hide_card() -> void:
	_what = ""
	visible = false


func shown_key() -> String:
	return _what


## Pose la bulle près de [param target] (rectangle visé, à l'écran) : à droite, sinon à gauche, sinon au-dessus, sans
## chevaucher [param avoid] (panneaux du cadre) et dans l'écran ; la queue pointe vers la cible.
func place_near(target: Rect2, avoid: Array) -> void:
	var vs := get_viewport_rect().size
	var sz := get_combined_minimum_size()
	size = sz
	var gap := AutochessHud.s(TAIL) + 4.0
	var mid := target.get_center()
	var face_h := sz.y - AutochessHud.s(SHADOW)  # hauteur de la bulle sans son ombre
	var cands := [
		["left", Vector2(target.end.x + gap, mid.y - face_h * 0.5)],
		["right", Vector2(target.position.x - gap - sz.x, mid.y - face_h * 0.5)],
		["bottom", Vector2(mid.x - sz.x * 0.5, target.position.y - gap - face_h)],
		["top", Vector2(mid.x - sz.x * 0.5, target.end.y + gap)],
	]
	var best: Array = []
	var best_cost := INF
	for c in cands:
		var p: Vector2 = c[1]
		p.x = clampf(p.x, 4.0, vs.x - sz.x - 4.0)
		p.y = clampf(p.y, 4.0, vs.y - sz.y - 4.0)
		var r := Rect2(p, sz)
		var cost := 0.0
		for a in avoid:
			cost += r.intersection(a as Rect2).get_area()
		cost += r.intersection(target).get_area() * 4.0  # ne jamais cacher ce qu'on vise
		if cost < best_cost - 0.5:
			best_cost = cost
			best = [c[0], p]
	if best.is_empty():
		return
	position = best[1]
	_tail_side = String(best[0])
	match _tail_side:
		"left", "right":
			_tail_at = clampf(mid.y - position.y, 18.0, face_h - 18.0)
		_:
			_tail_at = clampf(mid.x - position.x, 18.0, sz.x - 18.0)
	queue_redraw()


## Queue de la bulle (papier, bords d'encre) vers la cible.
func _draw() -> void:
	if _tail_side == "":
		return
	var t := AutochessHud.s(TAIL)
	var w := t * 0.9
	var a: Vector2
	var b: Vector2
	var tip: Vector2
	match _tail_side:
		"left":
			a = Vector2(1.5, _tail_at - w)
			b = Vector2(1.5, _tail_at + w)
			tip = Vector2(-t, _tail_at)
		"right":
			a = Vector2(size.x - 1.5, _tail_at - w)
			b = Vector2(size.x - 1.5, _tail_at + w)
			tip = Vector2(size.x + t, _tail_at)
		"bottom":
			var fb := size.y - AutochessHud.s(SHADOW)  # bas de la face (l'ombre dure est dessous)
			a = Vector2(_tail_at - w, fb - 1.5)
			b = Vector2(_tail_at + w, fb - 1.5)
			tip = Vector2(_tail_at, fb + t)
		_:
			a = Vector2(_tail_at - w, 1.5)
			b = Vector2(_tail_at + w, 1.5)
			tip = Vector2(_tail_at, -t)
	draw_colored_polygon(PackedVector2Array([a, tip, b]), AutochessHud.PAPER)
	draw_polyline(PackedVector2Array([a, tip, b]), AutochessHud.INK, 3.0, true)


# --- aides ----------------------------------------------------------------------------------------------------------
## Nom affiché d'un objet (emblème : « Emblème d'Ombre »).
static func item_name(id: String) -> String:
	var info := Autochess.parse_item(id)
	if String(info.id) == "embleme":
		var t := String(info["trait"])
		return "Emblème" if t == "" else "Emblème : %s" % String(AutochessData.TRAITS.get(t, {}).get("name", t))
	return String(AutochessData.item(String(info.id)).get("name", id))


static func item_icon(id: String) -> Texture2D:
	var info := Autochess.parse_item(id)
	var icon := String(AutochessData.item(String(info.id)).get("icon", ""))
	var path := String(Boons.ICONS.get(icon, ""))
	if path == "":
		path = "res://assets/ui/icons/gem.png" if AutochessData.COMPONENTS.has(String(info.id)) else "res://assets/ui/icons/jewel.png"
	return UiTheme.texture(path)


## Ligne d'objet : icône + nom ; infobulle chiffrée.
static func item_row(id: String) -> Control:
	var r := HBoxContainer.new()
	r.add_theme_constant_override("separation", 6)
	r.mouse_filter = Control.MOUSE_FILTER_PASS
	var info := Autochess.parse_item(id)
	r.tooltip_text = String(AutochessData.item(String(info.id)).get("tip", ""))
	var ic := TextureRect.new()
	ic.custom_minimum_size = Vector2(22, 22)
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ic.texture = item_icon(id)
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tile := PanelContainer.new()  # icônes claires : sur une tuile d'encre
	tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile.add_theme_stylebox_override("panel", AutochessHud.sticker(AutochessHud.INK_500, 6.0, 0.0, 2.0, 1.0, 1.0))
	tile.add_child(ic)
	r.add_child(tile)
	var nm := AutochessHud.ink_lbl(item_name(id), 14, AutochessHud.INK, 800)
	nm.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	r.add_child(nm)
	return r


static func _skill(cls: Dictionary, skill_id: int) -> Dictionary:
	for s in cls.get("skills", []):
		if s is Dictionary and int(s.get("id", -1)) == skill_id:
			return s
	return {}


static func _max_bases() -> Dictionary:
	if _max_base.is_empty():
		_max_base = {"hp": 0.1, "atk": 0.1}
		for id in AutochessData.unit_ids():
			var b: Dictionary = GameData.class_data(String(id)).get("base", {})
			_max_base.hp = maxf(float(_max_base.hp), float(b.get("hp", 1.0)))
			_max_base.atk = maxf(float(_max_base.atk), float(b.get("atk", 1.0)))
	return _max_base


func _clear() -> void:
	for c in _body.get_children():
		_body.remove_child(c)
		c.queue_free()


static func _sep() -> Control:
	var s := ColorRect.new()
	s.color = Color(AutochessHud.INK, 0.2)
	s.custom_minimum_size = Vector2(0, 2)
	s.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return s


## Barre de stat : libellé, jauge contourée (0-1), infobulle.
static func _bar(label: String, ratio: float, col: Color, tip: String) -> Control:
	var r := HBoxContainer.new()
	r.add_theme_constant_override("separation", 8)
	r.mouse_filter = Control.MOUSE_FILTER_PASS
	r.tooltip_text = tip
	var l := AutochessHud.ink_lbl(label, 14, AutochessHud.INK_300, 800)
	l.custom_minimum_size.x = AutochessHud.s(64.0)
	r.add_child(l)
	var pb := AutochessHud.gauge(ProgressBar.new(), col, 11.0)
	pb.max_value = 1.0
	pb.value = clampf(ratio, 0.04, 1.0)
	pb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	r.add_child(pb)
	return r
