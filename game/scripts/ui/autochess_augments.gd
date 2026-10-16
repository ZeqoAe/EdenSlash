class_name AutochessChoicePanel
extends Control
## L'Échiquier (lot AC-G) : les choix à cartes de la préparation (SPEC §5.3, §7.1) : l'atout (3 grandes cartes de la même
## rareté, [Relancer] une fois), et les autres choix de la partie, même écran : premier héros (ouverture, 1 parmi 4), héros
## légendaire, objet complet, composant, famille (Cœur de famille), trait d'un Emblème. Le choix partagé a son propre écran
## (AutochessCarousel). Posé par l'écran sur un calque au-dessus du plateau (la manette n'y voit que ces cartes) ;
## [Voir le plateau] le replie le temps de regarder (l'écran affiche un bouton pour revenir). Texte permanent court et sans
## pourcentage : le détail chiffré n'apparaît que sur la carte visée (souris ou cadre de la manette).

signal chosen(index: int)
signal reroll_requested
signal hide_requested

const RARITY_COLORS := {"argent": Color(0.80, 0.85, 0.95), "or": Color(0.98, 0.78, 0.35), "eclat": Color(0.78, 0.56, 1.0)}
const TITLES := {
	"atout": "Choisis un atout", "ouverture": "Choisis ton premier héros", "heros": "Choisis un héros légendaire",
	"objet": "Choisis un objet", "composant": "Choisis un composant", "famille": "Choisis une famille",
	"embleme": "Choisis le trait de l'Emblème",
}
const SUBTITLES := {
	"atout": "Il reste toute la partie.", "ouverture": "Les autres stratèges reçoivent le leur.",
	"heros": "Il arrive déjà avec deux étoiles.", "objet": "Il va au banc d'objets.", "composant": "Il va au banc d'objets.",
	"famille": "Elle compte une unité de plus.", "embleme": "Son porteur gagne ce trait.",
}

var cards: Array = []  # Button par option
var reroll_button: Button
var hide_button: Button
var kind := ""
var _title: Label
var _sub: Label
var _row: HBoxContainer
var _details: Array = []  # Label de détail par carte (montré sur la carte visée)
var _hover := -1


func _init() -> void:
	name = "AcChoice"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.02, 0.07, 0.72)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(v)
	_title = AutochessHud.lbl("", 30, UiTheme.GOLD, "title")
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_title)
	_sub = AutochessHud.lbl("", 16, UiTheme.MUTED)
	_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_sub)
	_row = HBoxContainer.new()
	_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_row.add_theme_constant_override("separation", 16)
	_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(_row)
	var foot := HBoxContainer.new()
	foot.alignment = BoxContainer.ALIGNMENT_CENTER
	foot.add_theme_constant_override("separation", 14)
	foot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(foot)
	reroll_button = AutochessHud.button("Relancer", "plain", 40.0)
	reroll_button.name = "AcChoiceReroll"
	reroll_button.custom_minimum_size.x = 180
	reroll_button.pressed.connect(func(): reroll_requested.emit())
	foot.add_child(reroll_button)
	hide_button = AutochessHud.button("Voir le plateau", "plain", 40.0)
	hide_button.name = "AcChoiceHide"
	hide_button.custom_minimum_size.x = 180
	hide_button.pressed.connect(func(): hide_requested.emit())
	foot.add_child(hide_button)
	visible = false


## Montre le choix [param c] (Autochess.pending : {kind, options, rerolls, rarity, stars}).
func open(c: Dictionary) -> void:
	kind = String(c.get("kind", ""))
	var opts: Array = c.get("options", [])
	_title.text = String(TITLES.get(kind, "Choisis"))
	var sub := String(SUBTITLES.get(kind, ""))
	if kind == "atout":
		sub = "Rareté %s · %s" % [String(AutochessData.RARITY_NAMES.get(String(c.get("rarity", "")), "")), sub.to_lower()]
	_sub.text = sub
	for b in cards:
		_row.remove_child(b)
		b.queue_free()
	cards.clear()
	_details.clear()
	var vw := get_viewport_rect().size.x
	var n := maxi(opts.size(), 1)
	var w := clampf((vw - 120.0 - 16.0 * (n - 1)) / n, 170.0, 270.0 if kind == "atout" else 230.0)
	var tall := get_viewport_rect().size.y >= 800.0
	var h := (280.0 if tall else 250.0) if kind == "atout" else (300.0 if tall else 280.0)
	for i in opts.size():
		var b := _card(i, opts[i], c, Vector2(w, h))
		_row.add_child(b)
		cards.append(b)
	reroll_button.visible = kind == "atout"
	var left := int(c.get("rerolls", 0))
	reroll_button.disabled = left <= 0
	reroll_button.text = "Relancer" if left > 0 else "Déjà relancé"
	visible = true
	if not cards.is_empty():
		UiNav.focus(cards[0])


func _card(i: int, opt: Variant, c: Dictionary, sz: Vector2) -> Button:
	var b := Button.new()
	b.name = "AcChoiceCard_%d" % i
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = sz
	b.pressed.connect(func(): chosen.emit(i))
	b.mouse_entered.connect(func(): _hover = i)
	b.mouse_exited.connect(func():
		if _hover == i:
			_hover = -1)
	var col := UiTheme.GOLD
	var head := ""
	var title := ""
	var short := ""
	var tip := ""
	var icon: Texture2D = null
	match kind:
		"atout":
			var a := AutochessData.augment(String(opt))
			col = RARITY_COLORS.get(String(a.get("rarity", "")), UiTheme.GOLD)
			head = String(AutochessData.RARITY_NAMES.get(String(a.get("rarity", "")), ""))
			title = String(a.get("name", opt))
			short = String(a.get("short", ""))
			tip = String(a.get("tip", ""))
		"ouverture", "heros":
			var d := AutochessData.unit(String(opt))
			var cost := int(d.get("cost", 1))
			col = AutochessBoard.cost_color(cost)
			var stars := int(c.get("stars", 1))
			head = "★".repeat(stars) + "   %d or" % cost
			title = AutochessData.unit_name(String(opt))
			short = " · ".join((d.get("traits", []) as Array).map(func(t): return String(AutochessData.TRAITS.get(t, {}).get("name", t))))
			var role: Dictionary = AutochessData.ROLES.get(String(d.get("role", "")), {})
			tip = "%s : %s" % [String(role.get("name", "")), String(role.get("short", ""))]
			icon = UiTheme.texture(String(GameData.class_data(String(opt)).get("icon", "")))
		"objet", "composant":
			var it := AutochessData.item(String(opt))
			head = "Composant" if AutochessData.COMPONENTS.has(String(opt)) else "Objet"
			title = String(it.get("name", opt))
			short = String(it.get("short", ""))
			tip = String(it.get("tip", ""))
			icon = AutochessUnitCard.item_icon(String(opt))
		"famille", "embleme":
			var td: Dictionary = AutochessData.TRAITS.get(String(opt), {})
			head = "Famille" if String(td.get("kind", "")) == "famille" else "Arme"
			title = String(td.get("name", opt))
			short = String(td.get("short", ""))
			tip = String(td.get("tip", ""))
		_:
			title = str(opt)
	var n := AutochessHud.box(Color(0.07, 0.08, 0.19, 0.97), col.darkened(0.1), 2, 12, 0, 0)
	n.border_width_top = 8
	var hv := n.duplicate() as StyleBoxFlat
	hv.border_color = col.lightened(0.25)
	hv.bg_color = Color(0.11, 0.12, 0.27, 0.98)
	hv.shadow_color = Color(col, 0.4)
	hv.shadow_size = 10
	for st in ["normal", "focus", "disabled"]:
		b.add_theme_stylebox_override(st, n)
	b.add_theme_stylebox_override("hover", hv)
	b.add_theme_stylebox_override("pressed", hv)
	var m := MarginContainer.new()
	m.set_anchors_preset(Control.PRESET_FULL_RECT)
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for s in ["left", "right"]:
		m.add_theme_constant_override("margin_" + s, 16)
	m.add_theme_constant_override("margin_top", 20)
	m.add_theme_constant_override("margin_bottom", 14)
	b.add_child(m)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m.add_child(v)
	var hl := AutochessHud.lbl(head, 15, col, "bold")
	hl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(hl)
	if icon != null:
		var ic := TextureRect.new()
		ic.texture = icon
		ic.custom_minimum_size = Vector2(0, 64)
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(ic)
	var tl := AutochessHud.lbl(title, 22, UiTheme.TEXT, "title")
	tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(tl)
	var sl := AutochessHud.lbl(short, 16, UiTheme.TEXT)
	sl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(sl)
	var sp := Control.new()
	sp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(sp)
	var dl := AutochessHud.lbl(tip, 14, UiTheme.MUTED)
	dl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dl.modulate.a = 0.0
	v.add_child(dl)
	_details.append(dl)
	return b


func _process(_delta: float) -> void:
	if not visible:
		return
	var aim := _hover
	if Gamepad.active and UiNav.cursor != null and is_instance_valid(UiNav.cursor):
		aim = cards.find(UiNav.cursor)
	for i in _details.size():
		(_details[i] as Label).modulate.a = 1.0 if i == aim else 0.0
