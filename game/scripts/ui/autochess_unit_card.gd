class_name AutochessUnitCard
extends PanelContainer
## L'Échiquier (lot AC-G) : fiche d'une unité (« Qui est-ce ? », SPEC §7.1), en panneau latéral. Montrée au survol de la
## souris ou quand le cadre de la manette est posé sur une case, une carte de la boutique ou un objet du banc d'objets :
## portrait, nom, étoiles, coût, rôle, 2 traits (compte actuel / palier suivant), sort signature (type, mana), PV, attaque
## et portée en barres, objets portés. Texte permanent sans pourcentage : les chiffres sont dans les infobulles.
## Rapport : conception/autochess/R_AC_G.md.

const W := 236.0
const STAR_COLORS := AutochessBoard.STAR_COLORS

var _icon: TextureRect
var _name: Label
var _stars: Label
var _cost: Label
var _role: Label
var _body: VBoxContainer
var _what := ""  # ce qui est montré (évite de tout refaire à chaque image)

static var _max_base := {}  # plus grandes valeurs de base (hp, atk) parmi les 60 classes


func _init() -> void:
	name = "AcUnitCard"
	custom_minimum_size = Vector2(W, 0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_stylebox_override("panel", AutochessHud.box(AutochessHud.BG, UiTheme.GOLD_DIM, 2, 10, 12, 10))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(v)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(head)
	_icon = TextureRect.new()
	_icon.custom_minimum_size = Vector2(46, 46)
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(_icon)
	var hv := VBoxContainer.new()
	hv.add_theme_constant_override("separation", 0)
	hv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(hv)
	_name = AutochessHud.lbl("", 18, UiTheme.GOLD, "title")
	_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hv.add_child(_name)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hv.add_child(row)
	_stars = AutochessHud.lbl("", 16, STAR_COLORS[0], "bold")
	row.add_child(_stars)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(sp)
	_cost = AutochessHud.lbl("", 15, UiTheme.GOLD, "bold")
	row.add_child(_cost)
	_role = AutochessHud.lbl("", 14, UiTheme.MUTED)
	v.add_child(_role)
	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", 5)
	_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(_body)
	visible = false


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
	_name.text = AutochessData.unit_name(id)
	_stars.text = "★".repeat(stars)
	_stars.add_theme_color_override("font_color", STAR_COLORS[stars - 1])
	_cost.text = "%d or" % cost
	_cost.add_theme_color_override("font_color", AutochessBoard.cost_color(cost))
	var role: Dictionary = AutochessData.ROLES.get(String(d.get("role", "")), {})
	_role.text = "%s · %s" % [String(role.get("name", "")), String(AutochessData.PLACES.get(String(d.get("place", "")), ""))]
	_role.tooltip_text = String(role.get("short", ""))
	_role.mouse_filter = Control.MOUSE_FILTER_PASS
	add_theme_stylebox_override("panel", AutochessHud.box(AutochessHud.BG, AutochessBoard.cost_color(cost).darkened(0.15), 2, 10, 12, 10))
	_clear()
	# traits : nom, compte actuel / palier suivant
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
		r.add_theme_constant_override("separation", 6)
		r.mouse_filter = Control.MOUSE_FILTER_PASS
		r.tooltip_text = "%s\n%s" % [String(td.short), String(td.tip)]
		var badge := AutochessTraitPanel.badge(n if not counts.is_empty() else 0, tier)
		r.add_child(badge)
		var tl := AutochessHud.lbl(String(td.name), 15, UiTheme.TEXT if tier > 0 else UiTheme.MUTED, "bold")
		tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		r.add_child(tl)
		if not counts.is_empty():
			r.add_child(AutochessHud.lbl("%d / %d" % [n, nxt] if nxt > 0 else "%d" % n, 14, UiTheme.MUTED))
		_body.add_child(r)
	_body.add_child(_sep())
	# sort signature
	var spell := HBoxContainer.new()
	spell.mouse_filter = Control.MOUSE_FILTER_PASS
	spell.add_theme_constant_override("separation", 6)
	var sk := _skill(cls, int(d.get("skill_id", 0)))
	var sic := TextureRect.new()
	sic.custom_minimum_size = Vector2(30, 30)
	sic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	sic.texture = UiTheme.texture(String(sk.get("icon", "")))
	sic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spell.add_child(sic)
	var sv := VBoxContainer.new()
	sv.add_theme_constant_override("separation", 0)
	sv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spell.add_child(sv)
	var sname := AutochessHud.lbl(String(sk.get("name", d.get("skill_name", ""))), 15, UiTheme.GOLD, "bold")
	sname.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sv.add_child(sname)
	var kind := String(AutochessData.SPELL_TYPE_NAMES.get(String(d.get("spell_type", "")), ""))
	sv.add_child(AutochessHud.lbl("%s · %d mana" % [kind, int(d.get("mana", 0))], 14, UiTheme.MUTED))
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
	_body.add_child(_bar("PV", sqrt(float(base.get("hp", 1.0)) * mult / (float(mb.hp) * top_mult)), UiTheme.HP, mult_tip))
	_body.add_child(_bar("Attaque", sqrt(float(base.get("atk", 1.0)) * mult / (float(mb.atk) * top_mult)), UiTheme.GOLD, mult_tip))
	var rng := int(d.get("range", 1))
	_body.add_child(_bar("Portée", float(rng) / 4.0, Color(0.45, 0.7, 1.0),
		"Mêlée" if rng <= 1 else "%d cases" % rng))
	# objets portés
	if not items.is_empty():
		_body.add_child(_sep())
		for it in items:
			_body.add_child(item_row(String(it)))
	elif from_shop:
		pass
	visible = true


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
	_name.text = item_name(id)
	_stars.text = ""
	_cost.text = ""
	add_theme_stylebox_override("panel", AutochessHud.box(AutochessHud.BG, UiTheme.GOLD_DIM, 2, 10, 12, 10))
	var parts: Array = d.get("parts", [])
	if AutochessData.COMPONENTS.has(String(info.id)):
		_role.text = "Composant"
	elif String(info.id) in ["embleme", "couronne", "marteau_reforge"]:
		_role.text = "Objet rare"
	else:
		_role.text = "Objet"
	_clear()
	var s := AutochessHud.lbl(String(d.get("short", "")), 15, UiTheme.TEXT)
	s.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	s.custom_minimum_size.x = W - 24.0
	s.tooltip_text = String(d.get("tip", ""))
	s.mouse_filter = Control.MOUSE_FILTER_PASS
	_body.add_child(s)
	if AutochessData.ITEMS.has(String(info.id)) and parts.size() == 2:
		_body.add_child(_sep())
		var r := AutochessHud.lbl("%s + %s" % [AutochessData.item(String(parts[0])).get("name", ""),
			AutochessData.item(String(parts[1])).get("name", "")], 14, UiTheme.MUTED)
		r.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		r.custom_minimum_size.x = W - 24.0
		_body.add_child(r)
	elif AutochessData.COMPONENTS.has(String(info.id)):
		var r := AutochessHud.lbl("Pose-le sur un héros : deux composants font un objet.", 14, UiTheme.MUTED)
		r.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		r.custom_minimum_size.x = W - 24.0
		_body.add_child(r)
	visible = true


func hide_card() -> void:
	_what = ""
	visible = false


func shown_key() -> String:
	return _what


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
	r.add_child(ic)
	r.add_child(AutochessHud.lbl(item_name(id), 14, UiTheme.TEXT))
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
	s.color = Color(UiTheme.GOLD_DIM, 0.35)
	s.custom_minimum_size = Vector2(0, 1)
	s.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return s


## Barre de stat : libellé, jauge (0-1), infobulle.
static func _bar(label: String, ratio: float, col: Color, tip: String) -> Control:
	var r := HBoxContainer.new()
	r.add_theme_constant_override("separation", 8)
	r.mouse_filter = Control.MOUSE_FILTER_PASS
	r.tooltip_text = tip
	var l := AutochessHud.lbl(label, 14, UiTheme.MUTED)
	l.custom_minimum_size.x = 62
	r.add_child(l)
	var pb := ProgressBar.new()
	pb.show_percentage = false
	pb.max_value = 1.0
	pb.value = clampf(ratio, 0.04, 1.0)
	pb.custom_minimum_size = Vector2(0, 10)
	pb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pb.add_theme_stylebox_override("background", AutochessHud.box(Color(UiTheme.INK, 0.85), Color(UiTheme.GOLD_DIM, 0.5), 1, 4, 0, 0))
	pb.add_theme_stylebox_override("fill", AutochessHud.box(col, col, 0, 4, 0, 0))
	r.add_child(pb)
	return r
