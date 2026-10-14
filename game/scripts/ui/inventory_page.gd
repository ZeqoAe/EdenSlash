class_name InventoryPage
extends HBoxContainer
## Inventaire (maquette de l'utilisateur) :
## - au centre, le héros entouré de son équipement (5 cases de chaque côté), la puissance
##   d'équipement, la classe dont on prépare le set, le set actif, les 5 statistiques
##   principales et un bouton « Détail » (toutes les statistiques) ;
## - à droite, l'inventaire sans limite de place : familles (Tous, Armes, Armures,
##   Accessoires, Fournitures, Matériaux, Divers), recherche, tri, et la fiche de l'objet
##   choisi avec ses raccourcis (Équiper, Forge, Démonter).
## Hors run : coffre commun et préréglage de la classe affichée. Pendant la run : sac de la
## run, or, matériaux et fournitures. Forge et démontage partout : hors run, la forge prend
## les fournitures de la réserve et se paie en cristaux à la place de l'or (Forge.price).

signal class_changed

const LEFT_SLOTS := ["weapon", "necklace", "head", "chest", "legs"]
const RIGHT_SLOTS := ["back", "gloves", "boots", "ring", "trophy"]
const SLOT_CAPTIONS := {"weapon": "Arme principale", "necklace": "Collier"}
const FAMILIES := [["all", "Tous", "all"], ["weapon", "Armes", "weapon"], ["armor", "Armures", "armor"],
	["acc", "Accessoires", "ring"], ["cons", "Fournitures", "potion"], ["mat", "Matériaux", "gem"], ["misc", "Divers", "misc"]]
const SORTS := ["Rareté", "Niveau", "Nom", "Type", "Amélioration"]
const COLUMNS := 9
const CELL := 66.0
const ICON_GOLD := Color(0.98, 0.8, 0.42)
const MAT_NAMES := {"crystal": "Cristaux", "keys": "Clés"}
const MAT_RARITY := {"crystal": 3, "keys": 2}

var player: Player  # null hors run
var class_card := true  # carte « Classe affichée » (non dans l'écran Héros : la classe y est en haut)

var _doll := {}  # emplacement -> ItemSlot
var _preview: EquipmentPage.HeroPreview
var _power: Label
var _class_icon: TextureRect
var _class_name: Label
var _class_card: Button
var _set_text: Label
var _stat_vals := {}  # clé -> Label
var _family := "all"
var _slot_filter := ""  # case de la poupée cliquée : l'inventaire ne montre que ses pièces
var _slot_chip: Button
var _fam_buttons := {}
var _search: LineEdit
var _sort: OptionButton
var _grid: GridContainer
var _count: Label
var _selected: Dictionary = {}  # entrée : {kind: item|stack|mat|gold, item, key, count}
var _calc: Player  # héros fictif pour calculer les statistiques hors run
# fiche de l'objet
var _d_slot: ItemWidgets.ItemSlot
var _d_name: Label
var _d_badge: PanelContainer
var _d_badge_label: Label
var _d_type: Label
var _d_level: Label
var _d_stats: RichTextLabel
var _d_next: Label
var _d_flavor: RichTextLabel
var _d_set: RichTextLabel
var _b_equip: Button
var _b_upgrade: Button
var _b_dismantle: Button
var _armed_dismantle := false
var _msg: Label


static func gold_icon(name: String, px := 22.0) -> TextureRect:
	var t := TextureRect.new()
	t.texture = MenuWidgets.icon(name)
	t.custom_minimum_size = Vector2(px, px)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	t.modulate = ICON_GOLD
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t


## Cadre des grands panneaux : bleu nuit translucide, double liseré doré.
static func frame_box(radius := 12, alpha := 0.9) -> StyleBoxFlat:
	var sb := UiTheme.flat_box(Color(0.05, 0.05, 0.13, alpha), Color(0.78, 0.6, 0.3, 0.9), 2, radius)
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 14
	sb.content_margin_bottom = 14
	sb.shadow_color = Color(0, 0, 0, 0.5)
	sb.shadow_size = 10
	return sb


## Petite carte (classe, set, statistiques).
static func card_box(active := false) -> StyleBoxFlat:
	var sb := UiTheme.flat_box(Color(0.08, 0.08, 0.18, 0.92) if not active else Color(0.3, 0.22, 0.08, 0.95),
		Color(0.62, 0.48, 0.25, 0.85) if not active else UiTheme.GOLD, 1 if not active else 2, 8, false)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	return sb


func _ready() -> void:
	add_theme_constant_override("separation", 14)
	_build_center()
	_build_right()


func _exit_tree() -> void:
	if is_instance_valid(_calc):
		_calc.free()


# --- centre : héros, équipement, classe, set, statistiques -----------------------------------
func _build_center() -> void:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", frame_box())
	panel.custom_minimum_size = Vector2(540, 0)
	add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	panel.add_child(v)
	var doll := HBoxContainer.new()
	doll.add_theme_constant_override("separation", 8)
	doll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(doll)
	_doll_column(doll, LEFT_SLOTS)
	var mid := Control.new()
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	doll.add_child(mid)
	var circle := MagicCircle.new()
	circle.set_anchors_preset(Control.PRESET_FULL_RECT)
	circle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mid.add_child(circle)
	_preview = EquipmentPage.HeroPreview.new()
	_preview.set_anchors_preset(Control.PRESET_FULL_RECT)
	_preview.spin = false
	_preview.idle_pose = true
	mid.add_child(_preview)
	_preview.frame(5.3, 0.95, 0.35)  # en pied, de trois-quarts face (glisser pour tourner)
	_doll_column(doll, RIGHT_SLOTS)
	# puissance d'équipement
	var pw := HBoxContainer.new()
	pw.alignment = BoxContainer.ALIGNMENT_CENTER
	pw.add_theme_constant_override("separation", 12)
	v.add_child(pw)
	pw.add_child(gold_icon("power", 46))
	var pv := VBoxContainer.new()
	pv.add_theme_constant_override("separation", -4)
	pw.add_child(pv)
	Hud._label(pv, "Puissance d'équipement", 14, UiTheme.TEXT)
	_power = Label.new()
	UiTheme.title(_power, 30, UiTheme.GOLD)
	pv.add_child(_power)
	# classe affichée et set
	var cards := HBoxContainer.new()
	cards.add_theme_constant_override("separation", 10)
	v.add_child(cards)
	_class_card = Button.new()
	_class_card.focus_mode = Control.FOCUS_NONE
	_class_card.custom_minimum_size = Vector2(0, 66)
	_class_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_class_card.add_theme_stylebox_override("normal", card_box())
	_class_card.add_theme_stylebox_override("hover", card_box(true))
	_class_card.add_theme_stylebox_override("pressed", card_box(true))
	_class_card.add_theme_stylebox_override("disabled", card_box())
	_class_card.pressed.connect(_pick_class)
	_class_card.visible = class_card
	cards.add_child(_class_card)
	var ch := HBoxContainer.new()
	ch.set_anchors_preset(Control.PRESET_FULL_RECT)
	ch.offset_left = 12
	ch.offset_right = -10
	ch.add_theme_constant_override("separation", 10)
	ch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_class_card.add_child(ch)
	_class_icon = TextureRect.new()
	_class_icon.custom_minimum_size = Vector2(44, 44)
	_class_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_class_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_class_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_class_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ch.add_child(_class_icon)
	var cv := VBoxContainer.new()
	cv.alignment = BoxContainer.ALIGNMENT_CENTER
	cv.add_theme_constant_override("separation", -2)
	cv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ch.add_child(cv)
	Hud._label(cv, "Classe affichée  ▾", 13, UiTheme.MUTED).mouse_filter = Control.MOUSE_FILTER_IGNORE
	_class_name = Hud._label(cv, "", 22, UiTheme.TEXT)
	_class_name.add_theme_font_override("font", UiTheme.title_font())
	_class_name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var set_card := PanelContainer.new()
	set_card.add_theme_stylebox_override("panel", card_box())
	set_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cards.add_child(set_card)
	var sh := HBoxContainer.new()
	sh.add_theme_constant_override("separation", 8)
	set_card.add_child(sh)
	sh.add_child(gold_icon("all", 22))
	var sv := VBoxContainer.new()
	sv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sv.add_theme_constant_override("separation", -2)
	sh.add_child(sv)
	Hud._label(sv, "Set d'équipement", 15, UiTheme.TEXT)
	_set_text = Hud._label(sv, "", 12, UiTheme.MUTED)
	_set_text.clip_text = true
	var see := _small_button("Voir les sets", _show_sets)
	see.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	sh.add_child(see)
	# 5 statistiques principales
	var stats := PanelContainer.new()
	stats.add_theme_stylebox_override("panel", card_box())
	v.add_child(stats)
	var srow := HBoxContainer.new()
	srow.add_theme_constant_override("separation", 4)
	stats.add_child(srow)
	for s in [["hp", "PV", "heart"], ["atk", "Attaque", "attack"], ["def", "Défense", "defense"], ["speed", "Vitesse", "speed"], ["agi", "Agilité", "agility"]]:
		var cell := HBoxContainer.new()
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cell.add_theme_constant_override("separation", 6)
		srow.add_child(cell)
		cell.add_child(gold_icon(String(s[2]), 26))
		var cv2 := VBoxContainer.new()
		cv2.add_theme_constant_override("separation", -3)
		cell.add_child(cv2)
		Hud._label(cv2, String(s[1]), 12, UiTheme.MUTED)
		_stat_vals[s[0]] = Hud._label(cv2, "", 19, UiTheme.TEXT)
		_stat_vals[s[0]].add_theme_font_override("font", UiTheme.bold_font())
	var det := _small_button("Détail", _show_stat_detail)
	det.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	det.tooltip_text = "Toutes les statistiques du héros"
	srow.add_child(det)


func _doll_column(parent: Control, slots: Array) -> void:
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 4)
	parent.add_child(col)
	for slot in slots:
		var cell := VBoxContainer.new()
		cell.add_theme_constant_override("separation", 0)
		col.add_child(cell)
		var s := ItemWidgets.ItemSlot.new(78.0)
		s.slot_id = slot
		s.source = "equipped"
		s.placeholder = ""
		s.ghost = _ghost_icon(slot)
		s.can_drop = func(data): return data.source == "inventory" and data.item.slot == slot
		s.on_drop = func(data): _equip(data.item)
		s.pressed.connect(func():
			# case de la poupée : l'inventaire montre les pièces de cet emplacement (les
			# meilleures d'abord), pour équiper la case vide ou comparer avec la pièce portée
			var it: Dictionary = Profile.equipped.get(slot, {})
			_slot_filter = "" if _slot_filter == slot and not it.is_empty() else slot
			_select({"kind": "item", "item": it} if not it.is_empty() else {})
			_refresh_grid())
		s.activated.connect(func(): _unequip(slot))
		s.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		cell.add_child(s)
		var cap := Hud._label(cell, String(SLOT_CAPTIONS.get(slot, Items.SLOT_NAMES[slot])), 12, UiTheme.MUTED)
		cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_doll[slot] = s


## Icône fantôme d'une case vide (pièce d'Eden représentative).
func _ghost_icon(slot: String) -> String:
	if slot == "weapon":
		var cls := GameData.class_data(_cls())
		var ws: Array = GameData.weapon_type(String(cls.get("weapon_type", "katana"))).get("weapons", [])
		return String(ws[0].icon) if not ws.is_empty() else ""
	var list: Array = Items.icons().get(slot, [])
	return String(list[0]) if not list.is_empty() else ""


func _small_button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 34)
	b.add_theme_font_size_override("font_size", 13)
	b.add_theme_font_override("font", UiTheme.bold_font())
	var n := UiTheme.flat_box(Color(0.1, 0.08, 0.16, 0.95), UiTheme.GOLD_DIM, 1, 6, false)
	n.content_margin_left = 12
	n.content_margin_right = 12
	b.add_theme_stylebox_override("normal", n)
	var h := UiTheme.flat_box(Color(0.3, 0.22, 0.08, 1.0), UiTheme.GOLD, 1, 6, false)
	h.content_margin_left = 12
	h.content_margin_right = 12
	b.add_theme_stylebox_override("hover", h)
	b.add_theme_stylebox_override("pressed", h)
	b.pressed.connect(cb)
	return b


# --- droite : familles, recherche, grille, fiche --------------------------------------------
func _build_right() -> void:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", frame_box())
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	panel.add_child(v)
	var fams := HBoxContainer.new()
	fams.add_theme_constant_override("separation", 6)
	v.add_child(fams)
	for f in FAMILIES:
		var b := Button.new()
		b.text = String(f[1])
		b.icon = MenuWidgets.icon(String(f[2]))
		b.expand_icon = false
		b.add_theme_constant_override("icon_max_width", 15)
		b.add_theme_constant_override("h_separation", 4)
		b.focus_mode = Control.FOCUS_NONE
		b.toggle_mode = true
		b.custom_minimum_size = Vector2(0, 38)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.clip_text = true
		b.add_theme_font_size_override("font_size", 11)
		b.add_theme_font_override("font", UiTheme.bold_font())
		var id := String(f[0])
		b.pressed.connect(func():
			_family = id
			_slot_filter = ""
			_refresh_grid())
		fams.add_child(b)
		_fam_buttons[id] = b
	var filters := HBoxContainer.new()
	filters.add_theme_constant_override("separation", 10)
	v.add_child(filters)
	var sbox := PanelContainer.new()
	sbox.add_theme_stylebox_override("panel", card_box())
	sbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	filters.add_child(sbox)
	var shb := HBoxContainer.new()
	sbox.add_child(shb)
	shb.add_child(gold_icon("search", 20))
	_search = LineEdit.new()
	_search.placeholder_text = "Rechercher un objet…"
	_search.flat = true
	_search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_search.text_changed.connect(func(_t): _refresh_grid())
	shb.add_child(_search)
	_count = Hud._label(filters, "", 13, UiTheme.MUTED)
	_count.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_slot_chip = Button.new()
	_slot_chip.focus_mode = Control.FOCUS_NONE
	_slot_chip.visible = false
	_slot_chip.tooltip_text = "Revoir tout l'inventaire"
	_slot_chip.pressed.connect(func():
		_slot_filter = ""
		_refresh_grid())
	filters.add_child(_slot_chip)
	_sort = OptionButton.new()
	for s in SORTS:
		_sort.add_item("Trier : " + s)
	_sort.custom_minimum_size = Vector2(170, 0)
	_sort.item_selected.connect(func(_i): _refresh_grid())
	filters.add_child(_sort)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	_grid = GridContainer.new()
	_grid.columns = COLUMNS
	_grid.add_theme_constant_override("h_separation", 7)
	_grid.add_theme_constant_override("v_separation", 7)
	scroll.add_child(_grid)
	_build_detail(v)


func _build_detail(parent: Control) -> void:
	var card := PanelContainer.new()
	var sb := frame_box(10, 0.95)
	sb.border_color = UiTheme.GOLD
	card.add_theme_stylebox_override("panel", sb)
	card.custom_minimum_size = Vector2(0, 290)
	parent.add_child(card)
	var cv := VBoxContainer.new()
	cv.add_theme_constant_override("separation", 8)
	card.add_child(cv)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 14)
	h.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cv.add_child(h)
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 6)
	h.add_child(left)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 12)
	left.add_child(top)
	_d_slot = ItemWidgets.ItemSlot.new(92.0)
	_d_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(_d_slot)
	var tv := VBoxContainer.new()
	tv.add_theme_constant_override("separation", 0)
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(tv)
	var nh := HBoxContainer.new()
	nh.add_theme_constant_override("separation", 10)
	tv.add_child(nh)
	_d_name = Hud._label(nh, "", 21, UiTheme.TEXT)
	_d_name.add_theme_font_override("font", UiTheme.title_font())
	_d_name.clip_text = true
	_d_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_d_badge = PanelContainer.new()
	_d_badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	nh.add_child(_d_badge)
	_d_badge_label = Hud._label(_d_badge, "", 12, Color.WHITE)
	_d_type = Hud._label(tv, "", 13, UiTheme.MUTED)
	_d_level = Hud._label(tv, "", 17, UiTheme.TEXT)
	_d_level.add_theme_font_override("font", UiTheme.bold_font())
	_d_stats = ItemWidgets.rich(left, 14)
	_d_stats.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_d_stats.custom_minimum_size = Vector2(0, 96)  # jamais écrasée (sinon une barre de défilement inutile)
	_d_next = Hud._label(left, "", 13, UiTheme.MUTED)
	_d_flavor = ItemWidgets.rich(left, 12)
	_d_flavor.fit_content = true
	var right := VBoxContainer.new()
	right.custom_minimum_size = Vector2(250, 0)
	right.add_theme_constant_override("separation", 8)
	h.add_child(right)
	var setp := PanelContainer.new()
	setp.add_theme_stylebox_override("panel", card_box())
	setp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(setp)
	_d_set = ItemWidgets.rich(setp, 13)
	_msg = Hud._label(right, "", 13, UiTheme.BUFF)
	_msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var acts := HBoxContainer.new()
	acts.add_theme_constant_override("separation", 10)
	cv.add_child(acts)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.size_flags_stretch_ratio = 0.6
	acts.add_child(spacer)
	_b_equip = _action(acts, "Équiper", "", _on_equip, true)
	_b_upgrade = _action(acts, "Forge", "upgrade", _on_upgrade)
	_b_dismantle = _action(acts, "Démonter", "dismantle", _on_dismantle)


func _action(parent: Control, text: String, icon_name: String, cb: Callable, accent := false) -> Button:
	var b := Button.new()
	b.text = text
	if icon_name != "":
		b.icon = MenuWidgets.icon(icon_name)
		b.expand_icon = false
		b.add_theme_constant_override("icon_max_width", 18)
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 44)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.clip_text = true
	b.add_theme_font_size_override("font_size", 14)
	b.add_theme_font_override("font", UiTheme.bold_font())
	var n := UiTheme.flat_box(Color(0.36, 0.26, 0.08, 1.0) if accent else Color(0.09, 0.08, 0.16, 0.95),
		UiTheme.GOLD if accent else UiTheme.GOLD_DIM, 2 if accent else 1, 8, false)
	b.add_theme_stylebox_override("normal", n)
	var hv := UiTheme.flat_box(Color(0.5, 0.36, 0.1, 1.0) if accent else Color(0.22, 0.17, 0.08, 1.0), Color(1, 0.9, 0.6), 2, 8, false)
	b.add_theme_stylebox_override("hover", hv)
	b.add_theme_stylebox_override("pressed", hv)
	var d := UiTheme.flat_box(Color(0.07, 0.06, 0.1, 0.8), Color(0.3, 0.27, 0.35), 1, 8, false)
	b.add_theme_stylebox_override("disabled", d)
	b.add_theme_color_override("font_color", Color(1, 0.95, 0.85))
	b.pressed.connect(cb)
	parent.add_child(b)
	return b


# --- données ---------------------------------------------------------------------------------
func _cls() -> String:
	return Run.class_id if Profile.in_run else Profile.selected_class


func _level() -> int:
	if player:
		return player.level
	return 1 + int(GameData.zone(Profile.selected_zone).get("level_bonus", 0))


## Héros dont on lit les statistiques (le vrai pendant la run, un héros fictif sinon).
func _stats_player() -> Player:
	if player:
		return player
	if not is_instance_valid(_calc):
		_calc = Player.new()
	var cid := _cls()
	if not Run.active:
		Run.class_id = cid
	_calc.class_id = cid
	_calc.cls = GameData.class_data(cid)
	_calc.level = _level()
	_calc.recalc_stats()
	_calc.hp = _calc.max_hp
	return _calc


func _entries() -> Array:
	var out: Array = []
	for it in Profile.inventory:
		out.append({"kind": "item", "item": it})
	var sup: Dictionary = Profile.bag if Profile.in_run else Profile.stash
	for k in sup:
		if int(sup[k]) > 0:
			out.append({"kind": "stack", "key": String(k), "count": int(sup[k])})
	for m in Profile.materials:  # cristaux : gardés entre les runs
		if int(Profile.materials[m]) > 0:
			out.append({"kind": "mat", "key": String(m), "count": int(Profile.materials[m])})
	if Profile.in_run:
		if Profile.keys > 0:
			out.append({"kind": "mat", "key": "keys", "count": Profile.keys})
		if Profile.gold > 0:
			out.append({"kind": "gold", "key": "gold", "count": Profile.gold})
	return out


static func family_of(e: Dictionary) -> String:
	match String(e.kind):
		"item":
			var slot := String(e.item.slot)
			return "weapon" if slot == "weapon" else ("acc" if slot in Items.ACCESSORIES else "armor")
		"stack":
			return "mat" if String(e.key).begins_with("gem:") else "cons"
		"mat":
			return "mat"
	return "misc"


static func entry_name(e: Dictionary) -> String:
	match String(e.kind):
		"item":
			return Items.display_name(e.item)
		"stack":
			return Craft.label(String(e.key))
		"mat":
			return String(MAT_NAMES.get(e.key, e.key))
	return "Or"


static func entry_rarity(e: Dictionary) -> int:
	match String(e.kind):
		"item":
			return int(e.item.rarity)
		"stack":
			return Craft.rarity(String(e.key))
		"mat":
			return int(MAT_RARITY.get(e.key, 1))
	return 2


static func entry_icon(e: Dictionary) -> String:
	match String(e.kind):
		"item":
			return String(e.item.get("icon", ""))
		"stack":
			return Craft.icon(String(e.key))
	return Items.material_icon(String(e.key))


## Objet d'affichage pour une case (les piles ont un pseudo-objet sans statistiques).
static func entry_display(e: Dictionary) -> Dictionary:
	if String(e.kind) == "item":
		return e.item
	return {"uid": "stack:" + String(e.key), "name": entry_name(e), "icon": entry_icon(e), "rarity": entry_rarity(e),
		"level": 0, "slot": "", "stack": true}


func _sorted(list: Array) -> Array:
	var mode := _sort.selected
	list.sort_custom(func(a, b):
		var ka: Array
		var kb: Array
		match mode:
			1:
				ka = [int(a.get("item", {}).get("level", 0)), entry_rarity(a)]
				kb = [int(b.get("item", {}).get("level", 0)), entry_rarity(b)]
			2:
				return entry_name(a).naturalnocasecmp_to(entry_name(b)) < 0
			3:
				ka = [-FAMILIES.map(func(f): return f[0]).find(family_of(a)), entry_rarity(a)]
				kb = [-FAMILIES.map(func(f): return f[0]).find(family_of(b)), entry_rarity(b)]
			4:
				ka = [int(a.get("item", {}).get("upgrade", 0)), entry_rarity(a)]
				kb = [int(b.get("item", {}).get("upgrade", 0)), entry_rarity(b)]
			_:
				ka = [entry_rarity(a), int(a.get("item", {}).get("level", 0))]
				kb = [entry_rarity(b), int(b.get("item", {}).get("level", 0))]
		return ka > kb)
	return list


# --- rafraîchissement ------------------------------------------------------------------------
func refresh() -> void:
	if not is_inside_tree():
		return
	var cid := _cls()
	var cd := GameData.class_data(cid)
	for slot in _doll:
		var s: ItemWidgets.ItemSlot = _doll[slot]
		s.set_item(Profile.equipped.get(slot, {}))
		s.ghost = _ghost_icon(slot)
		s.selected = _selected.get("kind", "") == "item" and is_same(Profile.equipped.get(slot), _selected.get("item"))
		if s.item.is_empty():
			s.tooltip_text = "%s : vide (glisse un objet ici)" % SLOT_CAPTIONS.get(slot, Items.SLOT_NAMES[slot])
		s.queue_redraw()
	_preview.show_hero(cid, Profile.weapon_code())
	_class_icon.texture = UiTheme.texture(String(cd.get("icon", "")))
	_class_name.text = String(cd.get("name_fr", cid))
	_class_name.add_theme_color_override("font_color", ClassPicker.tier_color(cid))
	_class_card.disabled = Profile.in_run
	_class_card.tooltip_text = "Pendant la run, la classe est fixée." if Profile.in_run else "Choisir la classe dont tu prépares le set (chaque classe a son préréglage)."
	var power := 0
	for it in Profile.equipped.values():
		power += EquipmentPage._power_of(it)
	_power.text = str(power)
	var sets := Items.active_set_bonuses(Profile.equipped)
	_set_text.text = ("%s · %d pièces" % [Items.set_def(sets[-1].set).get("name", ""), int(sets[-1].pieces)]) if not sets.is_empty() else "Aucun bonus actif"
	var p := _stats_player()
	var mag := String(cd.get("dmg_type", "phys")) == "mag"
	_stat_vals.hp.text = str(roundi(p.max_hp))
	_stat_vals.atk.text = str(roundi(p.matk if mag else p.atk))
	_stat_vals.def.text = str(roundi(p.defense))
	_stat_vals.speed.text = str(roundi(p.atk_speed * 100.0))
	_stat_vals.agi.text = str(roundi(float(p.attrs.get("agi", 0.0))))
	for id in _fam_buttons:
		_fam_buttons[id].set_pressed_no_signal(id == _family)
		_style_family(_fam_buttons[id], id == _family)
	_refresh_grid()
	_refresh_detail()


func _style_family(b: Button, on: bool) -> void:
	var sb := UiTheme.flat_box(Color(0.62, 0.45, 0.14, 1.0) if on else Color(0.08, 0.07, 0.16, 0.92),
		UiTheme.GOLD if on else Color(0.45, 0.36, 0.22, 0.8), 1, 7, false)
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("pressed", sb)
	b.add_theme_stylebox_override("hover", UiTheme.flat_box(Color(0.3, 0.22, 0.09, 1.0), UiTheme.GOLD, 1, 7, false))
	b.add_theme_color_override("font_color", Color(0.12, 0.08, 0.02) if on else Color(0.92, 0.88, 0.8))
	b.add_theme_color_override("font_pressed_color", Color(0.12, 0.08, 0.02))
	b.add_theme_color_override("icon_normal_color", Color(0.12, 0.08, 0.02) if on else ICON_GOLD)
	b.add_theme_color_override("icon_pressed_color", Color(0.12, 0.08, 0.02))


func _refresh_grid() -> void:
	for id in _fam_buttons:
		_fam_buttons[id].set_pressed_no_signal(id == _family)
		_style_family(_fam_buttons[id], id == _family)
	for c in _grid.get_children():
		c.queue_free()
	var q := _search.text.strip_edges().to_lower()
	var all := _entries()
	var list := all.filter(func(e): return (_family == "all" or family_of(e) == _family) and (q == "" or entry_name(e).to_lower().contains(q)))
	if _slot_filter != "":
		list = all.filter(func(e): return String(e.kind) == "item" and String(e.item.slot) == _slot_filter and (q == "" or entry_name(e).to_lower().contains(q)))
		list.sort_custom(func(a, b): return EquipmentPage._power_of(a.item) > EquipmentPage._power_of(b.item))
	else:
		list = _sorted(list)
	_count.text = "%d objet(s)" % list.size() if list.size() == all.size() else "%d / %d" % [list.size(), all.size()]
	_slot_chip.visible = _slot_filter != ""
	_slot_chip.text = "%s ✕" % Items.SLOT_NAMES.get(_slot_filter, "")
	if _slot_filter != "" and list.is_empty():
		_count.text = "Aucune pièce « %s » en stock" % Items.SLOT_NAMES.get(_slot_filter, "")
	for slot in _doll:
		(_doll[slot] as ItemWidgets.ItemSlot).selected = slot == _slot_filter
		_doll[slot].queue_redraw()
	for e in list:
		_grid.add_child(_cell(e))
	# cases vides jusqu'à remplir les lignes (inventaire sans limite : la grille s'allonge)
	var n := maxi(COLUMNS * 5, ceili(float(list.size()) / COLUMNS) * COLUMNS)
	for i in n - list.size():
		_grid.add_child(_empty_cell())


func _cell(e: Dictionary) -> Control:
	var s := StackSlot.new(CELL)
	s.entry = e
	s.set_item(entry_display(e))
	s.source = "inventory" if String(e.kind) == "item" else ""
	s.show_compare = String(e.kind) == "item"
	s.badge = ("%d" % int(e.count)) if e.has("count") else ""
	if String(e.kind) == "item" and not Profile.in_run and not Profile.item_users(String(e.item.uid)).is_empty():
		s.badge = "★"
	s.selected = _same(e, _selected)
	s.can_drop = func(data): return data.source == "equipped"
	s.on_drop = func(data): _unequip(String(data.slot))
	s.pressed.connect(func(): _select(e))
	s.activated.connect(func():
		if String(e.kind) == "item":
			_equip(e.item))
	return s


func _empty_cell() -> Control:
	var s := ItemWidgets.ItemSlot.new(CELL)
	s.can_drop = func(data): return data.source == "equipped"
	s.on_drop = func(data): _unequip(String(data.slot))
	s.mouse_filter = Control.MOUSE_FILTER_PASS
	return s


static func _same(a: Dictionary, b: Dictionary) -> bool:
	if a.is_empty() or b.is_empty() or String(a.kind) != String(b.kind):
		return false
	if String(a.kind) == "item":
		return is_same(a.item, b.item)
	return String(a.key) == String(b.key)


func _select(e: Dictionary) -> void:
	_selected = e
	_armed_dismantle = false
	_msg.text = ""
	for c in _grid.get_children():
		if c is StackSlot:
			c.selected = _same(c.entry, e)
			c.queue_redraw()
	for slot in _doll:
		_doll[slot].selected = e.get("kind", "") == "item" and is_same(Profile.equipped.get(slot), e.get("item"))
		_doll[slot].queue_redraw()
	_refresh_detail()


func _is_equipped(it: Dictionary) -> bool:
	return Profile.equipped.values().any(func(x): return is_same(x, it))


# --- fiche de l'objet ------------------------------------------------------------------------
func _refresh_detail() -> void:
	var e := _selected
	if e.get("kind", "") == "item" and not (_is_equipped(e.item) or Profile.inventory.any(func(x): return is_same(x, e.item))):
		e = {}  # objet vendu, démonté ou archivé
		_selected = {}
	if e.is_empty():
		_d_slot.set_item({})
		_d_name.text = "Choisis un objet"
		_d_name.add_theme_color_override("font_color", UiTheme.TEXT)
		_d_badge.visible = false
		_d_type.text = "Clique une case de l'inventaire ou de l'équipement."
		_d_level.text = ""
		_d_stats.text = "[color=#c8c8d4]Double-clic (ou glisser-déposer) : équiper / retirer.\n★ : objet utilisé dans le préréglage d'une classe.[/color]"
		_d_next.text = ""
		_d_flavor.text = ""
		_d_set.text = "[b]Bonus de set[/b]\n[color=#9a98a8]Les pièces de set ont un cadre vert ; 2, 4 et 6 pièces portées donnent des bonus.[/color]"
		for b in [_b_equip, _b_upgrade, _b_dismantle]:
			b.disabled = true
		_b_equip.text = "Équiper"
		_b_dismantle.text = "Démonter"
		return
	var disp := entry_display(e)
	_d_slot.set_item(disp)
	_d_slot.queue_redraw()
	var rar := entry_rarity(e)
	var col: Color = Items.RARITIES[rar].color if String(e.kind) != "item" else Items.color_of(e.item)
	_d_name.text = entry_name(e)
	_d_name.add_theme_color_override("font_color", col)
	_d_badge.visible = true
	_d_badge_label.text = String(Items.RARITIES[rar].name)
	var bs := UiTheme.flat_box(Color(col, 0.25), col, 1, 5, false)
	bs.content_margin_left = 8
	bs.content_margin_right = 8
	bs.content_margin_top = 2
	bs.content_margin_bottom = 2
	_d_badge.add_theme_stylebox_override("panel", bs)
	_d_badge_label.add_theme_color_override("font_color", col.lightened(0.3))
	if String(e.kind) != "item":
		_d_type.text = {"stack": "Fourniture", "mat": "Matériau", "gold": "Monnaie"}.get(String(e.kind), "")
		_d_level.text = "Quantité : %d" % int(e.count)
		var key := String(e.key)
		_d_stats.text = Craft.describe_key(key) if String(e.kind) == "stack" else String({
			"crystal": "Réforger une stat bonus d'un objet et polir sa qualité (Forge).",
			"keys": "Ouvre un coffre de la carte sans payer.",
			"gold": "Coffres de la carte, marchands ambulants, amélioration +1 à +10 (Forge)."}.get(key, ""))
		_d_next.text = ""
		_d_flavor.text = "[color=#9a98a8]%s[/color]" % ("Fournitures : gardées à l'extraction ou à la victoire, perdues si le héros tombe." if String(e.kind) == "stack" else
			("Gardés entre les runs (on les obtient en démontant des objets)." if key == "crystal" else "Perdu(es) en fin de run : à dépenser !"))
		_d_set.text = "[b]Utilisation[/b]\n[color=#c8c8d4]%s[/color]" % ("Forge : gemmes, formules d'enchantement, parchemins de fortification, pierres de sûreté ; fusion de 3 gemmes identiques." if String(e.kind) == "stack" else "Voir l'aide « ? » : Monnaies.")
		for b in [_b_equip, _b_dismantle]:
			b.disabled = true
		# gemmes : la Forge propose la fusion
		_b_upgrade.disabled = not (Profile.in_run and String(e.kind) == "stack" and key.begins_with("gem"))
		_b_upgrade.tooltip_text = "Fusion de 3 gemmes identiques (Forge)"
		return
	var it: Dictionary = e.item
	var equipped := _is_equipped(it)
	var slot_name := String(SLOT_CAPTIONS.get(it.slot, Items.SLOT_NAMES[it.slot]))
	var kind := String(GameData.weapon_type(Items.weapon_type_of(it)).get("name", "")) if it.slot == "weapon" else \
		String(GameData.eden_by_id.get(int(it.get("eden", 0)), {}).get("armor", ""))
	_d_type.text = slot_name + ((" - " + kind.capitalize()) if kind != "" else "") + ("  · porté" if equipped else "")
	_d_level.text = "Niv. %d%s" % [int(it.level), ("   +%d" % int(it.get("upgrade", 0))) if int(it.get("upgrade", 0)) > 0 else ""]
	_d_stats.text = _stats_compare(it, equipped)
	_d_next.text = ("Prochain niveau : %d %% de réussite" % roundi(Craft.success_chance(it) * 100.0)) if int(it.get("upgrade", 0)) < Items.MAX_UPGRADE else "Amélioration maximale"
	var eden: Dictionary = GameData.eden_by_id.get(int(it.get("eden", 0)), {})
	var fl: PackedStringArray = []
	if not eden.is_empty():
		fl.append("« %s » : objet d'Eden (niveau %d dans le jeu d'origine)." % [eden.name, int(eden.level)])
	var sockets: Array = it.get("sockets", [])
	if not sockets.is_empty() or it.has("enchant"):
		fl.append("Emplacements : %d / 2%s" % [sockets.size(), ("  · enchanté") if it.has("enchant") else ""])
	if not Profile.in_run:
		var users := Profile.item_users(String(it.uid))
		if not users.is_empty():
			fl.append("★ Utilisé par : " + ", ".join(users))
	_d_flavor.text = "[i][color=#b8b4c8]%s[/color][/i]" % "\n".join(fl)
	_d_set.text = _set_bbcode(it)
	_b_equip.disabled = false
	_b_equip.text = "Retirer" if equipped else "Équiper"
	_b_upgrade.disabled = false
	_b_dismantle.disabled = equipped
	_b_upgrade.tooltip_text = "" if Profile.in_run else "Hors run : fournitures de ta réserve, or remplacé par des cristaux (1 pour %d or)." % Forge.GOLD_PER_CRYSTAL
	var users := Profile.item_users(String(it.get("uid", ""))) if not Profile.in_run else []
	_b_dismantle.tooltip_text = "Retire d'abord l'objet." if equipped else (("Attention : utilisé par le préréglage de " + ", ".join(users)) if not users.is_empty() else "")
	_b_dismantle.text = "Confirmer ?" if _armed_dismantle else "Démonter"


## Statistiques de l'objet comparées à la pièce portée (écart en vert / rouge).
func _stats_compare(it: Dictionary, equipped: bool) -> String:
	var st := Items.stats(it)
	var worn: Dictionary = Profile.equipped.get(it.slot, {}) if not equipped else {}
	var wst := Items.stats(worn) if not worn.is_empty() else {}
	var keys := st.keys()
	for k in wst:
		if not k in keys:
			keys.append(k)
	var lines: PackedStringArray = []
	for k in keys.slice(0, 7):
		var v := float(st.get(k, 0.0))
		var pct: bool = k in Items.PERCENT_STATS
		var name := String(Items.STAT_NAMES.get(k, Items.EXTRA_STAT_NAMES.get(k, k)))
		var val := ("%d %%" % roundi(v * 100.0)) if pct else str(roundi(v))
		var diff := ""
		if not worn.is_empty():
			var dv := v - float(wst.get(k, 0.0))
			if absf(dv) > 0.0001:
				var dtxt := ("%+d %%" % roundi(dv * 100.0)) if pct else ("%+d" % roundi(dv))
				diff = "  [color=%s](%s)[/color]" % ["#7fe08a" if dv > 0 else "#ff7a7a", dtxt]
		lines.append("[color=#c8c8d4]%s[/color]  [b]%s[/b]%s" % [name, val, diff])
	if not worn.is_empty():
		lines.append("[color=#8a86a0]Écarts par rapport à %s[/color]" % Items.display_name(worn))
	return "\n".join(lines)


func _set_bbcode(it: Dictionary) -> String:
	var sid := String(it.get("set", ""))
	var s := Items.set_def(sid)
	if s.is_empty():
		return "[b]Bonus de set[/b]\n[color=#9a98a8]Cet objet n'appartient à aucun set.[/color]"
	var worn := int(Items.set_counts(Profile.equipped).get(sid, 0))
	var lines: PackedStringArray = ["[b][color=#%s]%s[/color][/b]  (%d pièce(s) portée(s))" % [Items.SET_COLOR.to_html(false), s.name, worn]]
	for n in Items.set_tiers(sid):
		var ok: bool = worn >= n
		lines.append("[color=%s](%d pièces) %s[/color]" % ["#7fe08a" if ok else "#c8c8d4", n, " ; ".join(Items.bonus_lines(Items.set_bonus(sid, n)))])
	var pieces: Array = s.get("pieces", [])
	if not pieces.is_empty():
		var names: PackedStringArray = []
		for pid in pieces:
			names.append(String(GameData.eden_by_id.get(int(pid), {}).get("name", "?")))
		lines.append("[color=#8a86a0]Pièces : %s[/color]" % ", ".join(names))
	return "\n".join(lines)


# --- actions ---------------------------------------------------------------------------------
func _equip(it: Dictionary) -> void:
	if it.is_empty() or _is_equipped(it):
		return
	Profile.equip(it)
	_after_change({"kind": "item", "item": it})


func _unequip(slot: String) -> void:
	var it: Dictionary = Profile.equipped.get(slot, {})
	if it.is_empty():
		return
	Profile.unequip(slot)
	_after_change({"kind": "item", "item": it})


func _after_change(e: Dictionary) -> void:
	if player:
		player.recalc_stats()
	else:
		Profile.save_profile()
	_selected = e
	refresh()


func _on_equip() -> void:
	if _selected.get("kind", "") != "item":
		return
	if _is_equipped(_selected.item):
		_unequip(String(_selected.item.slot))
	else:
		_equip(_selected.item)


func _on_dismantle() -> void:
	if _selected.get("kind", "") != "item" or _is_equipped(_selected.item):
		return
	if not _armed_dismantle:
		_armed_dismantle = true
		_refresh_detail()
		return
	var it: Dictionary = _selected.item
	var got := Profile.disassemble(it)
	_selected = {}
	refresh()
	_msg.text = "%s démonté : %s" % [Items.display_name(it), ItemWidgets.materials_text(got, true)]


## Forge (pendant la run) : améliorer, réforger, polir, sertir, enchanter l'objet choisi ;
## sur une gemme : la fusion.
func _on_upgrade() -> void:
	var w := get_tree().get_first_node_in_group("world")
	var mu: MerchantUI
	if Profile.in_run and w:
		mu = w.merchant_ui
	else:
		mu = _lobby_forge()
	mu.open_forge(_selected.item if _selected.get("kind", "") == "item" else {})
	if not mu._forge.closed.is_connected(refresh):
		mu._forge.closed.connect(refresh)


## Forge hors run (lobby) : celle des marchands, sans héros ni run ; le temps qu'elle est
## ouverte, le « sac » de la forge est la réserve de fournitures.
var _forge_ui: MerchantUI


func _lobby_forge() -> MerchantUI:
	if _forge_ui == null:
		_forge_ui = MerchantUI.new()
		get_tree().current_scene.add_child(_forge_ui)
		_forge_ui.setup(null, null)
		_forge_ui._forge.closed.connect(func():
			Profile.bag = {}
			Profile.save_profile())
	Profile.bag = Profile.stash  # même dictionnaire : la forge puise dans la réserve
	return _forge_ui


func _pick_class() -> void:
	if Profile.in_run:
		return
	var p := ClassPicker.open(self, Profile.selected_class, false)
	p.picked.connect(func(cid):
		if cid == Profile.selected_class:
			return
		Profile.selected_class = cid
		Profile.save_profile()
		_selected = {}
		class_changed.emit()
		refresh())


func _show_stat_detail() -> void:
	var p := _stats_player()
	var lines: PackedStringArray = []
	for row in p.stat_sheet():
		if String(row[1]) == "":
			lines.append("\n[color=#f5c75a][b]%s[/b][/color]" % String(row[0]).replace("—", "").strip_edges())
		else:
			lines.append("%s : [b]%s[/b]" % [row[0], row[1]])
	var extra := "" if player else "\n\n[color=#9a98a8]Hors run : héros niveau %d (début de la zone choisie), équipement porté, talents, certificats et bonus de l'archive compris.[/color]" % _level()
	InfoDialog.open(self, "Statistiques — %s" % GameData.class_data(_cls()).get("name_fr", ""), "\n".join(lines).strip_edges() + extra)


func _show_sets() -> void:
	var lines: PackedStringArray = []
	var counts := Items.set_counts(Profile.equipped)
	# sets des objets que tu possèdes (portés ou dans l'inventaire)
	var owned := {}
	for it in Profile.equipped.values() + Profile.inventory:
		if String(it.get("set", "")) != "":
			owned[String(it.set)] = true
	for sid in owned:
		var s := Items.set_def(sid)
		if s.is_empty():
			continue
		var worn := int(counts.get(sid, 0))
		lines.append("[b][color=#%s]%s[/color][/b]  — %d pièce(s) portée(s)" % [Items.SET_COLOR.to_html(false), s.name, worn])
		for n in Items.set_tiers(sid):
			lines.append("   [color=%s](%d) %s[/color]" % ["#7fe08a" if worn >= n else "#c8c8d4", n, " ; ".join(Items.bonus_lines(Items.set_bonus(sid, n)))])
		lines.append("")
	if lines.is_empty():
		lines.append("[color=#9a98a8]Aucune pièce de set pour l'instant.[/color]")
	InfoDialog.open(self, "Sets d'équipement", "[color=#c8c8d4]Les sets d'Eden sont des pièces mythiques (orange) : boss et fabrication. Bonus à 2 et 5 pièces portées.[/color]\n\n" + "\n".join(lines))


# --- widgets ---------------------------------------------------------------------------------
## Case d'inventaire : objet ou pile (fournitures, matériaux, or) avec sa quantité.
class StackSlot extends ItemWidgets.ItemSlot:
	var entry: Dictionary = {}

	func _make_custom_tooltip(for_text: String) -> Object:
		if entry.get("kind", "") == "item":
			return super._make_custom_tooltip(for_text)
		var txt := "[b]%s[/b]  ×%d" % [InventoryPage.entry_name(entry), int(entry.get("count", 0))]
		if entry.get("kind", "") == "stack":
			txt += "\n" + Craft.describe_key(String(entry.key))
		return ItemWidgets.tip_card(txt)


## Cercle magique doré sous le héros.
class MagicCircle extends Control:
	var _t := 0.0

	func _process(delta: float) -> void:
		if is_visible_in_tree():
			_t += delta
			queue_redraw()

	func _draw() -> void:
		var c := Vector2(size.x * 0.5, size.y * 0.79)
		var r := minf(size.x * 0.42, 150.0)
		var sq := 0.32  # perspective : cercle aplati
		for k in 3:
			var rr := r * (1.0 - k * 0.18)
			var pts := PackedVector2Array()
			for i in 65:
				var a := TAU * i / 64.0
				pts.append(c + Vector2(cos(a) * rr, sin(a) * rr * sq))
			draw_polyline(pts, Color(0.55, 0.65, 1.0, 0.55 - k * 0.12), 2.0, true)
		for i in 12:
			var a := TAU * i / 12.0 + _t * 0.3
			var p1 := c + Vector2(cos(a) * r * 0.64, sin(a) * r * 0.64 * sq)
			var p2 := c + Vector2(cos(a + PI * 5.0 / 6.0) * r * 0.64, sin(a + PI * 5.0 / 6.0) * r * 0.64 * sq)
			draw_line(p1, p2, Color(0.6, 0.7, 1.0, 0.25), 1.5, true)
		var glow := PackedVector2Array()
		for i in 33:
			var a := TAU * i / 32.0
			glow.append(c + Vector2(cos(a) * r * 0.5, sin(a) * r * 0.5 * sq))
		draw_colored_polygon(glow, Color(0.4, 0.5, 1.0, 0.12))


## Fenêtre d'information (statistiques détaillées, sets).
class InfoDialog extends CanvasLayer:
	static func open(host: Node, title: String, bbcode: String) -> void:
		var d := InfoDialog.new()
		d.layer = 95
		d.process_mode = Node.PROCESS_MODE_ALWAYS
		host.get_tree().root.add_child(d)
		var dim := ColorRect.new()
		dim.color = Color(0, 0, 0, 0.6)
		dim.set_anchors_preset(Control.PRESET_FULL_RECT)
		dim.gui_input.connect(func(ev):
			if ev is InputEventMouseButton and ev.pressed:
				d.queue_free())
		d.add_child(dim)
		var panel := PanelContainer.new()
		panel.add_theme_stylebox_override("panel", InventoryPage.frame_box(12, 0.98))
		panel.set_anchors_preset(Control.PRESET_CENTER)
		panel.custom_minimum_size = Vector2(620, 600)
		panel.position = Vector2(-310, -300)
		d.add_child(panel)
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 10)
		panel.add_child(v)
		var t := Label.new()
		t.text = title
		UiTheme.title(t, 24)
		v.add_child(t)
		var r := ItemWidgets.rich(v, 15)
		r.size_flags_vertical = Control.SIZE_EXPAND_FILL
		r.scroll_active = true
		r.text = bbcode
		var close := Button.new()
		close.text = "Fermer"
		close.focus_mode = Control.FOCUS_NONE
		close.custom_minimum_size = Vector2(0, 40)
		close.pressed.connect(d.queue_free)
		v.add_child(close)

	func _unhandled_input(event: InputEvent) -> void:
		if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
			get_viewport().set_input_as_handled()
			queue_free()


## Amélioration rapide depuis l'inventaire (pendant la run) : coût, chances, pierres de
## chance et de protection, comme la forge du village.
