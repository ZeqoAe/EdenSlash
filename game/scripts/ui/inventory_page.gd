class_name InventoryPage
extends HBoxContainer
## Inventaire (maquette de l'utilisateur) :
## - au centre, les 3 préréglages d'équipement de la classe (hors run), le héros entouré de son
##   équipement (5 cases de chaque côté), la puissance d'équipement, la panoplie active, les 5
##   statistiques principales et un bouton « Détail » (toutes les statistiques) ;
## - à droite, l'inventaire sans limite de place : familles (Tous, Armes, Armures,
##   Accessoires, Fournitures, Matériaux, Divers), recherche, tri, et la fiche de l'objet
##   choisi avec ses raccourcis (Équiper, Forge, Démonter).
## Hors run : coffre commun et préréglage de la classe affichée. Pendant la run : sac de la
## run, or, matériaux et fournitures. Forge et démontage partout : hors run, la forge prend
## les fournitures de la réserve et se paie en cristaux à la place de l'or (Forge.price).

signal preset_changed  # préréglage changé ou copié : l'écran Héros se met à jour

const LEFT_SLOTS := ["weapon", "necklace", "head", "chest", "legs"]
const RIGHT_SLOTS := ["offhand", "back", "gloves", "boots", "ring"]
const SLOT_CAPTIONS := {"weapon": "Arme principale", "offhand": "Arme secondaire", "necklace": "Collier"}
const FAMILIES := [["all", "Tous", "all"], ["weapon", "Armes", "weapon"], ["armor", "Armures", "armor"],
	["acc", "Accessoires", "ring"], ["cons", "Fournitures", "potion"], ["mat", "Matériaux", "gem"], ["misc", "Divers", "misc"]]
const SORTS := ["Rareté", "Niveau", "Nom", "Type", "Amélioration"]
const COLUMNS := 9
const COLUMNS_NARROW := 6  # fenêtre étroite (1280 px) : la grille ne doit pas pousser la page hors de l'écran
const CELL := 66.0
const ICON_GOLD := Color(0.98, 0.8, 0.42)
const MAT_NAMES := {"crystal": "Cristaux", "keys": "Clés"}
const MAT_RARITY := {"crystal": 3, "keys": 2}

var player: Player  # null hors run

## Préréglages d'équipement de la classe (hors run). La session « équiper le meilleur » y ajoute ses
## entrées : preset_bar.extra_actions.append({"label": ..., "call": Callable(cid) -> message}).
var preset_bar: EquipmentPage.PresetBar
var _doll := {}  # emplacement -> ItemSlot
var _preview: EquipmentPage.HeroPreview
var _power: Label
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
var _empty: Label  # grille sans objet : une phrase
var _selected: Dictionary = {}  # entrée : {kind: item|stack|mat|gold, item, key, count}
var _calc: Player  # héros fictif pour calculer les statistiques hors run
# fiche de l'objet (cachée tant qu'aucun objet n'est choisi)
var _d_card: PanelContainer
var _d_cmp: PanelContainer  # comparaison avec la pièce portée
var _d_cmp_slot: ItemWidgets.ItemSlot
var _d_cmp_name: Label
var _d_cmp_level: Label
var _d_cmp_verdict: RichTextLabel
var _d_slot: ItemWidgets.ItemSlot
var _d_name: Label
var _d_badge: PanelContainer
var _d_badge_label: Label
var _d_type: Label
var _d_level: Label
var _d_stats: RichTextLabel
var _d_flavor: RichTextLabel
var _d_set: RichTextLabel
var _b_equip: Button
var _b_offhand: Button  # armes : porter en arme secondaire / échanger
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


## Petite carte (panoplie, statistiques, comparaison).
static func card_box(active := false) -> StyleBoxFlat:
	var sb := UiTheme.flat_box(Color(0.08, 0.08, 0.18, 0.92) if not active else Color(0.3, 0.22, 0.08, 0.95),
		Color(0.62, 0.48, 0.25, 0.85) if not active else UiTheme.GOLD, 1 if not active else 2, 8, false)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	return sb


## Fenêtre étroite ou basse (1280 × 720) : colonnes en moins, cases et marges plus petites.
func _narrow() -> bool:
	return get_viewport().get_visible_rect().size.x < 1500.0


func _short() -> bool:
	return get_viewport().get_visible_rect().size.y < 840.0


func _cols() -> int:
	return COLUMNS_NARROW if _narrow() else COLUMNS


func _ready() -> void:
	add_theme_constant_override("separation", 14)
	_build_center()
	_build_right()


func _exit_tree() -> void:
	if is_instance_valid(_calc):
		_calc.free()


# --- centre : préréglages, héros, équipement, panoplie, statistiques -----------------------------------
func _build_center() -> void:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", frame_box())
	panel.custom_minimum_size = Vector2(520 if _narrow() else 540, 0)
	add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6 if _short() else 10)
	panel.add_child(v)
	preset_bar = EquipmentPage.PresetBar.new()
	preset_bar.changed.connect(_on_preset_changed)
	v.add_child(preset_bar)
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
	pw.add_child(gold_icon("power", 36 if _short() else 46))
	var pv := VBoxContainer.new()
	pv.add_theme_constant_override("separation", -4)
	pw.add_child(pv)
	Hud._label(pv, "Puissance d'équipement", 14, UiTheme.TEXT)
	_power = Label.new()
	UiTheme.title(_power, 24 if _short() else 30, UiTheme.GOLD)
	pv.add_child(_power)
	# panoplie active
	var set_card := PanelContainer.new()
	set_card.add_theme_stylebox_override("panel", card_box())
	v.add_child(set_card)
	var sh := HBoxContainer.new()
	sh.add_theme_constant_override("separation", 8)
	set_card.add_child(sh)
	sh.add_child(gold_icon("all", 22))
	_set_text = Hud._label(sh, "", 14, UiTheme.TEXT)
	_set_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_set_text.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_set_text.clip_text = true
	var see := _small_button("Panoplies", _show_sets)
	see.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	see.tooltip_text = "Bonus à 2, 4 et 6 pièces portées"
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
		var s := ItemWidgets.ItemSlot.new(52.0 if _short() else 78.0)
		s.slot_id = slot
		s.source = "equipped"
		s.placeholder = ""
		s.ghost = _ghost_icon(slot)
		s.can_drop = func(data): return _can_drop_on(slot, data)
		s.on_drop = func(data): _drop_on(slot, data)
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


## Type d'objet d'une case de la poupée (l'arme secondaire est une arme).
static func _item_slot(slot: String) -> String:
	return "weapon" if slot == "offhand" else slot


## L'arme principale est du type de la classe ; la secondaire, de n'importe quel type.
func _can_drop_on(slot: String, data) -> bool:
	if data.source == "inventory":
		return data.item.slot == _item_slot(slot) and (slot != "weapon" or Profile.can_be_main(data.item))
	# échange entre les deux cases d'arme (si l'arme secondaire peut être la principale)
	return data.source == "equipped" and String(data.slot) in ["weapon", "offhand"] and slot in ["weapon", "offhand"] \
		and String(data.slot) != slot and Profile.can_be_main(Profile.equipped.get("offhand", {}))


## Dépôt sur la case [param slot] : équipe, ou échange l'arme principale et la secondaire.
func _drop_on(slot: String, data) -> void:
	if data.source == "equipped":
		Profile.swap_weapons()
		_after_change({"kind": "item", "item": Profile.equipped.get(slot, {})})
	elif slot == "offhand":
		Profile.equip_offhand(data.item)
		_after_change({"kind": "item", "item": data.item})
	else:
		_equip(data.item)


## Icône fantôme d'une case vide (une pièce représentative de l'emplacement).
func _ghost_icon(slot: String) -> String:
	if slot in ["weapon", "offhand"]:
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
		b.text = String(f[1]) if not _narrow() or String(f[0]) == "all" else ""  # 1280 : les noms seraient coupés, l'icône et l'infobulle suffisent
		b.tooltip_text = String(f[1])
		b.icon = MenuWidgets.icon(String(f[2]))
		b.expand_icon = false
		# icône à gauche du nom (centrée, Godot la dessine sous le texte) ; seule, au centre
		b.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT if b.text != "" else HORIZONTAL_ALIGNMENT_CENTER
		b.add_theme_constant_override("icon_max_width", 15 if not _narrow() else 20)
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
	_search.placeholder_text = "Rechercher…"
	_search.flat = true
	_search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_search.text_changed.connect(func(_t): _refresh_grid())
	shb.add_child(_search)
	_count = Hud._label(filters, "", 13, UiTheme.MUTED)
	_count.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_slot_chip = Button.new()
	_slot_chip.focus_mode = Control.FOCUS_NONE
	_slot_chip.visible = false
	_slot_chip.tooltip_text = "Revoir tous les objets"
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
	_msg = Hud._label(v, "", 14, UiTheme.BUFF)
	_msg.visible = false
	_empty = Hud._label(v, "", 14, UiTheme.MUTED)
	_empty.visible = false
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	_grid = GridContainer.new()
	_grid.columns = _cols()
	_grid.add_theme_constant_override("h_separation", 7)
	_grid.add_theme_constant_override("v_separation", 7)
	scroll.add_child(_grid)
	_build_detail(v)


func _build_detail(parent: Control) -> void:
	_d_card = PanelContainer.new()
	var sb := frame_box(10, 0.95)
	sb.border_color = UiTheme.GOLD
	_d_card.add_theme_stylebox_override("panel", sb)
	_d_card.custom_minimum_size = Vector2(0, 286)
	_d_card.visible = false  # rien de choisi : la grille prend toute la place
	parent.add_child(_d_card)
	var cv := VBoxContainer.new()
	cv.add_theme_constant_override("separation", 8)
	_d_card.add_child(cv)
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
	_d_name = Hud._label(tv, "", 20, UiTheme.TEXT)
	_d_name.add_theme_font_override("font", UiTheme.title_font())
	_d_name.clip_text = true
	_d_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var nh := HBoxContainer.new()
	nh.add_theme_constant_override("separation", 10)
	tv.add_child(nh)
	_d_type = Hud._label(nh, "", 13, UiTheme.MUTED)
	_d_type.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_d_badge = PanelContainer.new()
	_d_badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	nh.add_child(_d_badge)
	_d_badge_label = Hud._label(_d_badge, "", 12, Color.WHITE)
	_d_level = Hud._label(tv, "", 17, UiTheme.TEXT)
	_d_level.add_theme_font_override("font", UiTheme.bold_font())
	_d_stats = ItemWidgets.rich(left, 14)
	_d_stats.fit_content = true  # sa hauteur suit les statistiques : jamais de barre de défilement
	_d_stats.scroll_active = false
	_d_stats.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_d_stats.add_theme_constant_override("table_h_separation", 18)
	_d_stats.add_theme_constant_override("table_v_separation", 3)
	_d_flavor = ItemWidgets.rich(left, 12)
	_d_flavor.fit_content = true
	var right := VBoxContainer.new()
	right.custom_minimum_size = Vector2(280, 0)
	right.add_theme_constant_override("separation", 8)
	h.add_child(right)
	# la pièce portée à côté de celle qu'on regarde
	_d_cmp = PanelContainer.new()
	_d_cmp.add_theme_stylebox_override("panel", card_box())
	right.add_child(_d_cmp)
	var cmv := VBoxContainer.new()
	cmv.add_theme_constant_override("separation", 4)
	_d_cmp.add_child(cmv)
	Hud._label(cmv, "Pièce portée", 12, UiTheme.MUTED)
	var cmh := HBoxContainer.new()
	cmh.add_theme_constant_override("separation", 10)
	cmv.add_child(cmh)
	_d_cmp_slot = ItemWidgets.ItemSlot.new(48.0)
	_d_cmp_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_d_cmp_slot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	cmh.add_child(_d_cmp_slot)
	var cmt := VBoxContainer.new()
	cmt.add_theme_constant_override("separation", -2)
	cmt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cmt.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	cmh.add_child(cmt)
	_d_cmp_name = Hud._label(cmt, "", 14, UiTheme.TEXT)
	_d_cmp_name.clip_text = true
	_d_cmp_level = Hud._label(cmt, "", 12, UiTheme.MUTED)
	_d_cmp_verdict = ItemWidgets.rich(cmv, 13)
	_d_cmp_verdict.fit_content = true
	_d_cmp_verdict.scroll_active = false
	_d_cmp_verdict.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var setp := PanelContainer.new()
	setp.add_theme_stylebox_override("panel", card_box())
	setp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(setp)
	_d_set = ItemWidgets.rich(setp, 13)
	var acts := HBoxContainer.new()
	acts.add_theme_constant_override("separation", 10)
	cv.add_child(acts)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.size_flags_stretch_ratio = 0.6
	acts.add_child(spacer)
	_b_equip = _action(acts, "Équiper", "", _on_equip, true)
	_b_offhand = _action(acts, "Secondaire", "", _on_offhand)
	_b_offhand.tooltip_text = "Arme secondaire : son auto-attaque part seule, à %d %% des dégâts et %d %% de ses stats." % [
		roundi(WeaponAttacks.OFFHAND_DMG * 100.0), roundi(WeaponAttacks.OFFHAND_STATS * 100.0)]
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
		if slot in ["weapon", "offhand"]:
			s.tooltip_text = ("Arme principale : une arme de type « %s » (celui de la classe)" % GameData.weapon_type(Profile.main_weapon_type()).get("name", "")) \
				if slot == "weapon" else "Arme secondaire : n'importe quelle arme ; elle frappe seule (%d %% des dégâts)" % roundi(WeaponAttacks.OFFHAND_DMG * 100.0)
		s.queue_redraw()
	_preview.show_hero(cid, Profile.weapon_code())
	preset_bar.refresh(cid)
	_power.text = GearPower.fmt(GearPower.hero_power())
	_power.tooltip_text = GearPower.summary(maxi(Profile.best_level, 1)) + "
Elle ouvre les difficultés Héroïque et Mythique des donjons et les butins légendaires."
	var sets := Items.active_set_bonuses(Profile.set_gear())
	_set_text.text = ("%s · %d pièces" % [Items.set_def(sets[-1].set).get("name", ""), int(sets[-1].pieces)]) if not sets.is_empty() else "Aucune panoplie active"
	_set_text.add_theme_color_override("font_color", UiTheme.TEXT if not sets.is_empty() else UiTheme.MUTED)
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
	sb.content_margin_left = 6
	sb.content_margin_right = 6
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
		list = all.filter(func(e): return String(e.kind) == "item" and String(e.item.slot) == _item_slot(_slot_filter) and (q == "" or entry_name(e).to_lower().contains(q)))
		list.sort_custom(func(a, b): return EquipmentPage._power_of(a.item) > EquipmentPage._power_of(b.item))
	else:
		list = _sorted(list)
	_count.text = GearPower.plural(list.size(), "objet") if list.size() == all.size() else "%d / %d" % [list.size(), all.size()]
	_slot_chip.visible = _slot_filter != ""
	_slot_chip.text = "%s ✕" % Items.SLOT_NAMES.get(_slot_filter, "")
	if _slot_filter != "" and list.is_empty():
		_count.text = "Aucune pièce « %s » en stock" % Items.SLOT_NAMES.get(_slot_filter, "")
	for slot in _doll:
		(_doll[slot] as ItemWidgets.ItemSlot).selected = slot == _slot_filter
		_doll[slot].queue_redraw()
	_empty.visible = all.is_empty()
	_empty.text = "Ton sac est vide." if Profile.in_run else "Ton coffre est vide : le butin de la Survie arrive ici."
	for e in list:
		_grid.add_child(_cell(e))
	# cases vides jusqu'à remplir les lignes (inventaire sans limite : la grille s'allonge)
	var n := maxi(_cols() * 5, ceili(float(list.size()) / _cols()) * _cols())
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
	_say("")
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
## Message court au-dessus de la grille (objet démonté, équipement copié...) ; "" l'efface.
func _say(text: String) -> void:
	_msg.text = text
	_msg.visible = text != ""


func _refresh_detail() -> void:
	var e := _selected
	if e.get("kind", "") == "item" and not (_is_equipped(e.item) or Profile.inventory.any(func(x): return is_same(x, e.item))):
		e = {}  # objet vendu, démonté ou archivé
		_selected = {}
	_d_card.visible = not e.is_empty()
	if e.is_empty():
		return
	_b_upgrade.visible = not (Profile.in_run and Run.survival)  # la forge est au hub
	_d_set.tooltip_text = ""
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
		_d_cmp.visible = false
		_d_type.text = {"stack": "Fourniture", "mat": "Matériau", "gold": "Monnaie"}.get(String(e.kind), "")
		_d_level.text = "Quantité : %d" % int(e.count)
		var key := String(e.key)
		_d_stats.text = Craft.describe_key(key) if String(e.kind) == "stack" else String({
			"crystal": "Réforger une stat bonus d'un objet et polir sa qualité (Forge).",
			"keys": "Ouvre un coffre de la carte sans payer.",
			"gold": "Coffres de la carte, marchands ambulants, amélioration +1 à +10 (Forge)."}.get(key, ""))
		_d_flavor.text = "[color=#9a98a8]%s[/color]" % ("Fournitures : gardées à l'extraction ou à la victoire, perdues si le héros tombe." if String(e.kind) == "stack" else
			("Gardés entre les runs (on les obtient en démontant des objets)." if key == "crystal" else "Perdus en fin de run : à dépenser !"))
		_d_set.text = "[b]Utilisation[/b]\n[color=#c8c8d4]%s[/color]" % ("Forge : gemmes, formules d'enchantement, parchemins de fortification, pierres de sûreté ; fusion de 3 gemmes identiques." if String(e.kind) == "stack" else "Voir l'aide « ? » : Monnaies.")
		for b in [_b_equip, _b_dismantle]:
			b.disabled = true
		_b_offhand.visible = false
		# gemmes : la Forge propose la fusion
		_b_upgrade.disabled = not (Profile.in_run and String(e.kind) == "stack" and key.begins_with("gem"))
		_b_upgrade.tooltip_text = "Fusion de 3 gemmes identiques (Forge)"
		return
	var it: Dictionary = e.item
	var equipped := _is_equipped(it)
	var worn_slot := Profile.slot_of(it)
	var slot_name := String(SLOT_CAPTIONS.get(worn_slot if worn_slot != "" else it.slot, Items.SLOT_NAMES[it.slot]))
	var kind := String(GameData.weapon_type(Items.weapon_type_of(it)).get("name", "")) if it.slot == "weapon" else ""
	_d_type.text = slot_name + ((" · " + kind) if kind != "" else "") + ("  · porté" if equipped else "")
	_d_level.text = "Niv. %d%s" % [int(it.level), ("   +%d" % int(it.get("upgrade", 0))) if int(it.get("upgrade", 0)) > 0 else ""]
	_d_stats.text = _stats_compare(it, equipped)
	if it.slot == "weapon":
		var ws := WeaponAttacks.spec_for(it)
		_d_stats.text = "[color=#ffcf6b][b]%s[/b][/color] [color=#9a98a8](auto-attaque)[/color] : %s\n" % [ws.name, ws.desc] + _d_stats.text
	var fl: PackedStringArray = []
	var sockets: Array = it.get("sockets", [])
	if not sockets.is_empty() or it.has("enchant"):
		fl.append("Emplacements : %d / 2%s" % [sockets.size(), ("  · enchanté") if it.has("enchant") else ""])
	if not Profile.in_run:
		var users := Profile.item_users(String(it.uid))
		if not users.is_empty():
			fl.append("★ Utilisé par : " + ", ".join(users))
	_d_flavor.text = "[i][color=#b8b4c8]%s[/color][/i]" % "\n".join(fl)
	_d_set.text = _set_bbcode(it)
	_refresh_compare(it, equipped)
	_b_equip.disabled = false
	_b_equip.text = "Retirer" if equipped else "Équiper"
	if it.slot == "trophy":
		_b_equip.disabled = true  # ancien trophée : les trophées se trouvent pendant la run (collection)
		_b_equip.tooltip_text = "Les trophées ne s'équipent plus : jusqu'à %d par run, trouvés dans les coffres de trophée." % Run.MAX_TROPHIES
	var off: Dictionary = Profile.equipped.get("offhand", {})
	_b_offhand.visible = it.slot == "weapon" and worn_slot != "offhand" and (worn_slot != "weapon" or Profile.can_be_main(off))
	_b_offhand.text = "Échanger" if worn_slot == "weapon" else "Secondaire"
	if it.slot == "weapon" and not equipped and not Profile.can_be_main(it):
		_b_equip.text = "Équiper (secondaire)"  # une arme d'un autre type que la classe
		_b_offhand.visible = false
	_b_upgrade.disabled = false
	var up := "Amélioration maximale" if int(it.get("upgrade", 0)) >= Items.MAX_UPGRADE else "Prochain niveau : %d %% de réussite" % roundi(Craft.success_chance(it) * 100.0)
	_b_upgrade.tooltip_text = up if Profile.in_run else up + "\nHors run : fournitures de ta réserve, or remplacé par des cristaux (1 pour %d or)." % Forge.GOLD_PER_CRYSTAL
	var users := Profile.item_users(String(it.get("uid", ""))) if not Profile.in_run else []
	_b_dismantle.tooltip_text = "Retire d'abord l'objet." if equipped else (("Attention : utilisé par le préréglage de " + ", ".join(users)) if not users.is_empty() else "")
	_b_dismantle.text = "Confirmer ?" if _armed_dismantle else "Démonter"


## Pièce portée à l'emplacement où irait [param it] (l'arme d'un autre type que la classe va en secondaire).
func _compare_target(it: Dictionary) -> Dictionary:
	if it.slot == "weapon" and not Profile.can_be_main(it):
		return Profile.equipped.get("offhand", {})
	return Profile.equipped.get(it.slot, {})


## Carte « Pièce portée » : la pièce en place et ce que change l'échange (mieux ou moins bien, puissance).
func _refresh_compare(it: Dictionary, equipped: bool) -> void:
	_d_cmp.visible = not equipped
	if equipped:
		return
	var worn := _compare_target(it)
	_d_cmp_slot.set_item(worn)
	_d_cmp_slot.queue_redraw()
	var txt := ""
	if worn.is_empty():
		_d_cmp_name.text = "Emplacement libre"
		_d_cmp_name.add_theme_color_override("font_color", UiTheme.MUTED)
		_d_cmp_level.text = ""
		txt = "[b][color=#7fe08a]▲ Nouvelle[/color][/b]"
	else:
		_d_cmp_name.text = Items.display_name(worn)
		_d_cmp_name.add_theme_color_override("font_color", Items.color_of(worn))
		_d_cmp_level.text = "Niv. %d%s" % [int(worn.level), ("   +%d" % int(worn.get("upgrade", 0))) if int(worn.get("upgrade", 0)) > 0 else ""]
		var wr := Items.rating(worn)
		var c := (Items.rating(it) - wr) / maxf(wr, 0.01)
		txt = "[b][color=%s]%s %+d %%[/color][/b]" % ["#7fe08a" if c >= 0.0 else "#ff7a7a",
			"▲" if c >= 0.02 else ("▼" if c <= -0.02 else "≈"), roundi(c * 100.0)]
	if String(it.slot) in Items.SLOTS and not (it.slot == "weapon" and not Profile.can_be_main(it)):
		var dpe := GearPower.delta_if_equipped(it)
		txt += "   [color=%s]Puissance %s%s[/color]" % ["#7fe08a" if dpe >= 0 else "#ff7a7a", "+" if dpe >= 0 else "", GearPower.fmt(dpe)]
	_d_cmp_verdict.text = txt


## Statistiques de l'objet comparées à la pièce portée (écart en vert / rouge).
func _stats_compare(it: Dictionary, equipped: bool) -> String:
	var st := Items.stats(it)
	var worn: Dictionary = _compare_target(it) if not equipped else {}
	var wst := Items.stats(worn) if not worn.is_empty() else {}
	var keys := st.keys()
	for k in wst:
		if not k in keys:
			keys.append(k)
	var cells: PackedStringArray = []
	for k in keys.slice(0, 8):
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
		cells.append("[cell][color=#c8c8d4]%s[/color]  [b]%s[/b]%s[/cell]" % [name, val, diff])
	if cells.size() % 2 == 1:
		cells.append("[cell] [/cell]")
	return "[table=2]" + "".join(cells) + "[/table]"


func _set_bbcode(it: Dictionary) -> String:
	var sid := String(it.get("set", ""))
	var s := Items.set_def(sid)
	_d_set.tooltip_text = ""
	if s.is_empty():
		return "[b]Panoplie[/b]\n[color=#9a98a8]Cet objet n'appartient à aucune panoplie.[/color]"
	var worn := int(Items.set_counts(Profile.set_gear()).get(sid, 0))
	var lines: PackedStringArray = ["[b][color=#%s]%s[/color][/b]  [color=#9a98a8]%d portée%s[/color]" % [Items.SET_COLOR.to_html(false), s.name, worn, "s" if worn > 1 else ""]]
	for n in Items.set_tiers(sid):
		var ok: bool = worn >= n
		lines.append("[color=%s](%d) %s[/color]" % ["#7fe08a" if ok else "#c8c8d4", n, " ; ".join(Items.bonus_lines(Items.set_bonus(sid, n)))])
	var pieces: Array = s.get("pieces", [])
	if not pieces.is_empty():
		var names: PackedStringArray = []
		for pid in pieces:
			names.append(String(GameData.eden_by_id.get(int(pid), {}).get("name", "?")))
		_d_set.tooltip_text = "Pièces : " + ", ".join(names)
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
		_unequip(Profile.slot_of(_selected.item))
	else:
		_equip(_selected.item)


func _on_offhand() -> void:
	if _selected.get("kind", "") != "item" or _selected.item.get("slot", "") != "weapon":
		return
	Profile.equip_offhand(_selected.item)
	_after_change({"kind": "item", "item": _selected.item})


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
	_say("%s démonté : %s" % [Items.display_name(it), ItemWidgets.materials_text(got, true)])


## Forge (pendant la run) : améliorer, réforger, polir, sertir, enchanter l'objet choisi ;
## sur une gemme : la fusion.
func _on_upgrade() -> void:
	var w := get_tree().get_first_node_in_group("world")
	if Profile.in_run and Run.survival:
		if w:
			w.hud.show_message("Survie : l'amélioration des pièces se fait au hub (Atelier) ; en run, l'enclume ajoute un bonus à un emplacement, une fois par carte", 3.0)
		return
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


## Préréglage changé, copié ou renommé : l'équipement porté et la fiche suivent.
func _on_preset_changed(message: String) -> void:
	_selected = {}
	preset_changed.emit()
	refresh()
	_say(message)


func _show_stat_detail() -> void:
	var p := _stats_player()
	var lines: PackedStringArray = []
	for row in p.stat_sheet():
		if String(row[1]) == "":
			lines.append("\n[color=#f5c75a][b]%s[/b][/color]" % String(row[0]).replace("—", "").strip_edges())
		else:
			lines.append("%s : [b]%s[/b]" % [row[0], row[1]])
	var extra := "" if player else "\n\n[color=#9a98a8]Hors run : héros niveau %d avec l'équipement porté, les talents, les certificats et la collection.[/color]" % _level()
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
		lines.append("[b][color=#%s]%s[/color][/b]  — %s" % [Items.SET_COLOR.to_html(false), s.name, GearPower.plural(worn, "pièce portée", "pièces portées")])
		for n in Items.set_tiers(sid):
			lines.append("   [color=%s](%d) %s[/color]" % ["#7fe08a" if worn >= n else "#c8c8d4", n, " ; ".join(Items.bonus_lines(Items.set_bonus(sid, n)))])
		lines.append("")
	if lines.is_empty():
		lines.append("[color=#9a98a8]Aucune pièce de panoplie pour l'instant.[/color]")
	InfoDialog.open(self, "Panoplies", "\n".join(lines))


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


## Fenêtre d'information (statistiques détaillées, sets) : compacte, B / Échap ou la croix la ferment.
class InfoDialog extends CanvasLayer:
	var _prev: Control

	static func open(host: Node, title: String, bbcode: String) -> void:
		var d := InfoDialog.new()
		d.layer = 95
		d.process_mode = Node.PROCESS_MODE_ALWAYS
		host.get_tree().root.add_child(d)
		var dim := ColorRect.new()
		dim.color = Color(0.02, 0.01, 0.05, 0.5)
		dim.set_anchors_preset(Control.PRESET_FULL_RECT)
		dim.gui_input.connect(func(ev):
			if ev is InputEventMouseButton and ev.pressed:
				d.close())
		d.add_child(dim)
		var center := CenterContainer.new()
		center.set_anchors_preset(Control.PRESET_FULL_RECT)
		center.mouse_filter = Control.MOUSE_FILTER_IGNORE
		d.add_child(center)
		var panel := PanelContainer.new()
		panel.add_theme_stylebox_override("panel", InventoryPage.frame_box(12, 0.98))
		panel.custom_minimum_size = Vector2(540, 480)
		center.add_child(panel)
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 10)
		panel.add_child(v)
		var t := Label.new()
		t.text = title
		UiTheme.title(t, 22)
		v.add_child(t)
		var r := ItemWidgets.rich(v, 15)
		r.size_flags_vertical = Control.SIZE_EXPAND_FILL
		r.scroll_active = true
		r.text = bbcode
		var close := Button.new()
		close.text = "Fermer"
		close.focus_mode = Control.FOCUS_NONE
		close.custom_minimum_size = Vector2(0, 38)
		close.pressed.connect(d.close)
		v.add_child(close)
		if is_instance_valid(UiNav.cursor):
			d._prev = UiNav.cursor
		UiNav.focus(close)

	func close() -> void:
		if is_instance_valid(_prev) and _prev.is_visible_in_tree():
			UiNav.focus(_prev)
		queue_free()

	func _input(event: InputEvent) -> void:
		if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel") 				or (event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_B):
			get_viewport().set_input_as_handled()
			close()


## Amélioration rapide depuis l'inventaire (pendant la run) : coût, chances, pierres de
## chance et de protection, comme la forge du village.
