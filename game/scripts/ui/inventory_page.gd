class_name InventoryPage
extends HBoxContainer
## Inventaire (maquette de l'utilisateur) :
## - au centre, les 5 préréglages d'équipement de la classe (hors run), le héros entouré de son
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
const SORTS := ["Rareté", "Niveau", "Nom", "Type", "Amélioration", "Pour ma classe"]
const COLUMNS := 9
const COLUMNS_NARROW := 6  # fenêtre étroite (1280 px) : la grille ne doit pas pousser la page hors de l'écran
const CELL := 66.0
const ICON_GOLD := Color(0.98, 0.8, 0.42)
const MAT_NAMES := {"crystal": "Cristaux", "keys": "Clés"}
const MAT_RARITY := {"crystal": 3, "keys": 2}
const LOCK_WORN := Color(1.0, 0.69, 0.44)  # lot H3 : pièce portée au-dessus du niveau de héros (gardée)

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
# lot GX-3 : objectif, pastilles de filtre, démontage en masse, cadenas, aperçu des stats au survol
const CHIPS := [["class", "Ma classe", "Les pièces que ta classe peut porter (arme de son type)."],
	["wear", "Portables", "Les pièces de ton niveau de héros."],
	["new", "Nouveautés", "Les pièces arrivées depuis ta dernière visite (pastille « neuf »)."],
	["kept", "Gardées", "Les pièces au cadenas : jamais démontées."],
	["useless", "Inutiles", "Moins bonnes que d'autres pièces du coffre pour tous les profils de classe, sans amélioration ni gemme, ni portées ni dans un préréglage, ni gardées."]]
var _chip := ""
var _chip_row: HBoxContainer
var _chip_buttons := {}
var _mass_btn: Button
var _undo_btn: Button
var _undo := {}  # dernier démontage en masse de la séance : {items, gained}
var _b_lock: Button
var _goal_bar: GoalBar
var _gate: Label
var _hover := {}  # pièce survolée dans le sac : écarts des stats du héros
var _base_stats := {}
var _stat_deltas := {}  # clé -> Label (écart de la pièce survolée)
var _d_verdict: RichTextLabel
var _best_btn: Button
var _useless: Array = []
var _useless_dirty := true
var _best := {}  # ClassGear.best_gear de la classe affichée (▲ sur les cases de la poupée)


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


## Cadre des grands panneaux : bleu nuit translucide, double liseré doré (autres écrans ; l'Équipement a frame_v2).
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


## Cadre des panneaux de l'Équipement (DA v2, lot GX-3) : autocollant d'encre (contour, ombre dure), sans filet doré.
static func frame_v2(shadow := 6, pad := Vector2(14, 12)) -> StyleBox:
	var sb := UiTheme.sticker("nuit", {"shadow": shadow, "radius": 16, "gloss": false, "cel_top": 0.0, "cel_bottom": 0.0, "pad": pad})
	sb.content_margin_top = pad.y
	sb.content_margin_bottom = pad.y + shadow
	return sb


## Petite carte de l'Équipement (DA v2) : puits d'encre plus sombre, contour d'encre ; [param tone] : un bonbon (choisie…).
static func card_v2(tone := "") -> StyleBox:
	if tone != "":
		return UiTheme.sticker(tone, {"shadow": 3, "radius": 12, "gloss": false, "cel_top": 0.0, "cel_bottom": 0.3, "pad": Vector2(12, 4)})
	var sb := UiTheme.well_style(Vector2(12, 6), 12)
	sb.bg_color = Color("231b40")
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
	panel.add_theme_stylebox_override("panel", frame_v2())
	panel.custom_minimum_size = Vector2(470 if _narrow() else 540, 0)  # 1280 px : la colonne du sac garde sa grille de 6 (lot GX-3)
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
	var prow := HBoxContainer.new()
	prow.add_theme_constant_override("separation", 12)
	pv.add_child(prow)
	_power = Label.new()
	UiTheme.title(_power, 24 if _short() else 30, UiTheme.GOLD)
	prow.add_child(_power)
	# lot GX-3 : à quoi sert ce chiffre (la difficulté de donjon suivante et l'écart)
	_gate = Hud._label(prow, "", UiTheme.MIN_TEXT, UiTheme.MUTED)
	_gate.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_gate.mouse_filter = Control.MOUSE_FILTER_PASS
	# lot GX-3 (P0-8) : « Le meilleur ▲N » sort de « Gérer » : combien de pièces il change, la liste avant / après, puis Appliquer
	_best_btn = ForgeWidgets.candy_button("", "lagon", 15, 38)
	_best_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_best_btn.pressed.connect(func(): preset_bar._open_best())
	pw.add_child(_best_btn)
	# panoplie active
	var set_card := PanelContainer.new()
	set_card.add_theme_stylebox_override("panel", card_v2())
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
	stats.add_theme_stylebox_override("panel", card_v2())
	stats.tooltip_text = "Survole une pièce du sac : l'écart qu'elle ferait sur ton héros s'affiche ici."
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
		# l'intitulé laisse la place à l'écart de la pièce survolée (lot GX-3 : « ▲+120 », la colonne ne s'élargit pas)
		_stat_deltas[s[0]] = Hud._label(cv2, String(s[1]), 12, UiTheme.MUTED)
		_stat_deltas[s[0]].set_meta("title", String(s[1]))
		_stat_vals[s[0]] = Label.new()
		_stat_vals[s[0]].add_theme_font_size_override("font_size", 19 if not _narrow() else 17)
		_stat_vals[s[0]].add_theme_color_override("font_color", UiTheme.TEXT)
		_stat_vals[s[0]].add_theme_font_override("font", UiTheme.number_font())
		cv2.add_child(_stat_vals[s[0]])
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
		s.wear_check = true  # pièce portée au-dessus du niveau de héros : signalée (lot H3)
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
		s.set_meta("pad_x", "Retirer")  # manette : X = clic droit, dessiné dans la barre d'aide (lot GX-4)
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
	if SurvivorGear.locked(_item_slot(slot)):
		return false  # Survivant : emplacement verrouillé à vie
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
		if _refused(data.item):
			return
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
	if Ico.has("slot_" + slot):  # silhouette de l'emplacement (lot ICO-1) plutôt qu'une pièce au hasard
		return Ico.path("slot_" + slot, 64)
	var list: Array = Items.icons().get(slot, [])
	return String(list[0]) if not list.is_empty() else ""


func _small_button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 34)
	UiTheme.style_button(b, "nuit", UiTheme.MIN_TEXT, {"shadow": 3})  # DA v2 (lot GX-3)
	b.pressed.connect(cb)
	return b


# --- droite : familles, recherche, grille, fiche --------------------------------------------
func _build_right() -> void:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", frame_v2())
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6 if _short() else 8)
	panel.add_child(v)
	# lot GX-3 : l'objectif épinglé (pièce visée, ce qui manque, « Y aller »), hors partie
	_goal_bar = GoalBar.new(_narrow())
	_goal_bar.narrow = _narrow()
	_goal_bar.visible = not Profile.in_run
	v.add_child(_goal_bar)
	var fams := HBoxContainer.new()
	fams.add_theme_constant_override("separation", 4)
	v.add_child(fams)
	for f in FAMILIES:
		var b := Button.new()
		b.text = String(f[1]) if not _narrow() or String(f[0]) == "all" else ""  # 1280 : les noms seraient coupés, l'icône et l'infobulle suffisent
		b.tooltip_text = String(f[1])
		b.icon = MenuWidgets.icon(String(f[2]))
		b.expand_icon = false
		# icône à gauche du nom (centrée, Godot la dessine sous le texte) ; seule, au centre
		b.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT if b.text != "" else HORIZONTAL_ALIGNMENT_CENTER
		b.add_theme_constant_override("icon_max_width", 15 if not _narrow() else 18)
		b.add_theme_constant_override("h_separation", 4)
		b.focus_mode = Control.FOCUS_NONE
		b.toggle_mode = true
		b.custom_minimum_size = Vector2(0, 36)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.clip_text = true
		var id := String(f[0])
		b.pressed.connect(func():
			_family = id
			_slot_filter = ""
			_refresh_grid())
		fams.add_child(b)
		_fam_buttons[id] = b
	var filters := HBoxContainer.new()
	filters.add_theme_constant_override("separation", 8)
	v.add_child(filters)
	var sbox := PanelContainer.new()
	sbox.add_theme_stylebox_override("panel", card_v2())
	sbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sbox.custom_minimum_size = Vector2(110, 0)
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
	_sort.fit_to_longest_item = false  # 1280 px : la rangée ne pousse plus la colonne hors de l'écran (lot GX-3)
	_sort.clip_text = true
	_sort.custom_minimum_size = Vector2(150 if _narrow() else 190, 0)
	_sort.add_theme_font_size_override("font_size", UiTheme.MIN_TEXT)
	_sort.item_selected.connect(func(_i): _refresh_grid())
	filters.add_child(_sort)
	# lot GX-3 : pastilles de filtre et actions en masse (hors partie)
	_chip_row = HBoxContainer.new()
	_chip_row.add_theme_constant_override("separation", 4)
	_chip_row.visible = not Profile.in_run
	v.add_child(_chip_row)
	for c in CHIPS:
		var cb := Button.new()
		cb.text = String(c[1])
		cb.tooltip_text = String(c[2])
		cb.toggle_mode = true
		cb.focus_mode = Control.FOCUS_NONE
		cb.clip_text = true
		cb.custom_minimum_size = Vector2(0, 30)
		cb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		UiTheme.style_button(cb, "nuit", 13, {"shadow": 2, "selected_tone": "mandarine", "pad": Vector2(4, 2)})
		var cid := String(c[0])
		cb.pressed.connect(func():
			_chip = "" if _chip == cid else cid
			_slot_filter = ""
			_refresh_grid())
		_chip_row.add_child(cb)
		_chip_buttons[cid] = cb
	var mass := HBoxContainer.new()
	mass.add_theme_constant_override("separation", 6)
	v.add_child(mass)
	_mass_btn = ForgeWidgets.candy_button("", "fraise", 15, 34)
	_mass_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_mass_btn.tooltip_text = "Démonte d'un coup les pièces inutiles (jamais une pièce gardée, portée, dans un préréglage ou la meilleure de sa case)."
	_mass_btn.pressed.connect(_on_mass_dismantle)
	mass.add_child(_mass_btn)
	_undo_btn = ForgeWidgets.candy_button("Annuler le démontage", "lagon", 15, 34)
	_undo_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_undo_btn.pressed.connect(_on_undo_dismantle)
	mass.add_child(_undo_btn)
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
	_d_card.add_theme_stylebox_override("panel", card_v2())
	_d_card.custom_minimum_size = Vector2(0, 250 if _short() else 286)
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
	_d_slot.wear_check = true
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
	# 1280 px (lot GX-3) : la colonne « Pièce portée » se replie ; le verdict passe sous le niveau
	_d_verdict = RichTextLabel.new()
	_d_verdict.bbcode_enabled = true
	_d_verdict.fit_content = true
	_d_verdict.scroll_active = false
	_d_verdict.autowrap_mode = TextServer.AUTOWRAP_OFF
	_d_verdict.add_theme_font_size_override("normal_font_size", UiTheme.MIN_TEXT)
	_d_verdict.add_theme_font_size_override("bold_font_size", UiTheme.MIN_TEXT)
	_d_verdict.visible = _narrow()
	tv.add_child(_d_verdict)
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
	right.visible = not _narrow()  # 1280 px : la fiche reste dans la colonne (lot GX-3)
	h.add_child(right)
	# la pièce portée à côté de celle qu'on regarde
	_d_cmp = PanelContainer.new()
	_d_cmp.add_theme_stylebox_override("panel", frame_v2(3, Vector2(10, 6)))
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
	setp.add_theme_stylebox_override("panel", frame_v2(3, Vector2(10, 6)))
	setp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(setp)
	_d_set = ItemWidgets.rich(setp, 13)
	var acts := HBoxContainer.new()
	acts.add_theme_constant_override("separation", 6 if _narrow() else 10)
	cv.add_child(acts)
	_b_equip = _action(acts, "Équiper", "", _on_equip, true)
	_b_equip.size_flags_stretch_ratio = 1.5  # « Niveau 70 requis » tient dans le bouton (lot GX-3)
	_b_offhand = _action(acts, "Secondaire", "", _on_offhand)
	_b_offhand.tooltip_text = "Arme secondaire : elle ne frappe pas seule ; « Changer d'arme » la met en main en plein combat."
	_b_upgrade = _action(acts, "Forge", "upgrade", _on_upgrade)
	# lot GX-3 : cadenas (L) : une pièce gardée ne se démonte jamais, ni seule ni en masse
	_b_lock = _action(acts, "Garder", "", _on_lock)
	_b_dismantle = _action(acts, "Démonter", "dismantle", _on_dismantle)


func _action(parent: Control, text: String, icon_name: String, cb: Callable, accent := false) -> Button:
	var b := Button.new()
	b.text = text
	if icon_name != "" and not _narrow():  # 1280 px : le texte seul tient dans le bouton (lot GX-3)
		b.icon = MenuWidgets.icon(icon_name)
		b.expand_icon = false
		b.add_theme_constant_override("icon_max_width", 18)
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 40 if _short() else 44)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.clip_text = true
	# DA v2 (lot GX-3) : action principale soleil, démonter fraise, le reste en puits d'encre
	UiTheme.style_button(b, "soleil" if accent else ("fraise" if icon_name == "dismantle" else "nuit"), 15, {"shadow": 3, "pad": Vector2(6, 2)})
	if accent or icon_name == "dismantle":
		b.add_theme_font_override("font", UiTheme.bold_font())  # Mochiy reste au bouton primaire de l'écran
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
	if mode == 5:  # lot GX-3 : « Pour ma classe » : la valeur de la pièce au profil de la classe (les pièces d'abord)
		var prof := ClassGear.profile(_cls())
		var pairs: Array = []
		for e in list:
			pairs.append([GearPower.item_power(e.item, prof) if String(e.kind) == "item" and String(e.item.get("slot", "")) in Items.SLOTS else -1, e])
		pairs.sort_custom(func(a, b): return int(a[0]) > int(b[0]))
		return pairs.map(func(x): return x[1])
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
				if slot == "weapon" else "Arme secondaire : n'importe quelle arme ; [%s] en combat la met en main" % Settings.action_label("swap_weapon", 1)
		s.queue_redraw()
	_preview.show_hero(cid, Profile.weapon_code())
	preset_bar.refresh(cid)
	_power.text = GearPower.fmt(GearPower.hero_power())
	_power.tooltip_text = GearPower.summary(maxi(Profile.best_level, 1)) + "
Elle ouvre les difficultés Héroïque et Mythique des donjons et les butins légendaires."
	_set_preview()
	_useless_dirty = true
	_base_stats = _hero_stats(_stats_player())
	for k in _stat_vals:
		_stat_vals[k].text = str(roundi(float(_base_stats[k])))
	_hover = {}
	_clear_deltas()
	# lot GX-3 : la difficulté de donjon suivante et l'écart de PE ; ▲ sur les cases de la poupée quand le coffre a mieux
	var gate := next_gate()
	_gate.visible = not gate.is_empty() and not Profile.in_run
	if _gate.visible:
		var gap := int(gate.need) - GearPower.hero_power()
		if gap <= 0:
			_gate.text = "%s ✓" % gate.name
		elif _narrow():
			_gate.text = "%s : −%s" % [gate.name, GearPower.fmt(gap)]
		else:
			_gate.text = "%s à %s · −%s" % [gate.name, GearPower.fmt(int(gate.need)), GearPower.fmt(gap)]
		_gate.tooltip_text = "PE requise pour la difficulté %s du donjon ouvert le plus facile : %s." % [String(gate.name), GearPower.fmt(int(gate.need))]
	_best = ClassGear.best_gear(cid) if not Profile.in_run and not Modes.sealed() else {}
	var plan := EquipmentPage.PresetBar.best_plan(cid)
	_best_btn.visible = not plan.is_empty()
	_best_btn.text = ("Meilleur ▲%d" if _narrow() else "Le meilleur ▲%d") % plan.size()
	_best_btn.tooltip_text = "Pour chaque emplacement, la meilleure pièce du coffre pour le profil %s : la liste avant de l'appliquer." % ClassGear.profile_name(ClassGear.profile_id(cid))
	for slot in _doll:
		var b: Dictionary = _best.get(slot, {})
		var cur: Dictionary = Profile.equipped.get(slot, {})
		_doll[slot].better = not b.is_empty() and String(b.get("uid", "")) != String(cur.get("uid", "")) and (cur.is_empty() or Items.profile_gain(b) >= 0.02)
	if is_instance_valid(_goal_bar):
		_goal_bar.visible = not Profile.in_run
		_goal_bar.refresh()
	for id in _fam_buttons:
		_fam_buttons[id].set_pressed_no_signal(id == _family)
		_style_family(_fam_buttons[id], id == _family)
	_refresh_grid()
	_refresh_detail()


## Les 5 statistiques montrées sous la poupée, pour le héros [param p].
func _hero_stats(p: Player) -> Dictionary:
	var mag := String(GameData.class_data(_cls()).get("dmg_type", "phys")) == "mag"
	return {"hp": p.max_hp, "atk": p.matk if mag else p.atk, "def": p.defense, "speed": p.atk_speed * 100.0, "agi": float(p.attrs.get("agi", 0.0))}


## Lot GX-3 (P0-9) : l'écart que ferait la pièce survolée [param it] sur les statistiques du héros (hors partie ; {} : rien).
func _preview_stats(it: Dictionary) -> void:
	if Profile.in_run or player != null:
		return
	if it.is_empty() or not String(it.get("slot", "")) in Items.SLOTS or _is_equipped(it) or HeroLevel.wear_block(it) > 0:
		_hover = {}
		_clear_deltas()
		return
	if is_same(_hover, it):
		return
	_hover = it
	var slot := "offhand" if String(it.slot) == "weapon" and not Profile.can_be_main(it) else String(it.slot)
	var orig := Profile.equipped
	var tmp := orig.duplicate()
	tmp[slot] = it
	Profile.equipped = tmp
	var after := _hero_stats(_stats_player())
	Profile.equipped = orig
	_stats_player()
	for k in _stat_deltas:
		var d := roundi(float(after[k]) - float(_base_stats.get(k, 0.0)))
		_stat_deltas[k].text = String(_stat_deltas[k].get_meta("title")) if d == 0 else ("▲ +%s" % GearPower.fmt(d) if d > 0 else "▼ −%s" % GearPower.fmt(-d))
		_stat_deltas[k].add_theme_color_override("font_color", UiTheme.MUTED if d == 0 else (ForgeWidgets.GAIN if d > 0 else ForgeWidgets.PERTE))


func _clear_deltas() -> void:
	for k in _stat_deltas:
		_stat_deltas[k].text = String(_stat_deltas[k].get_meta("title"))
		_stat_deltas[k].add_theme_color_override("font_color", UiTheme.MUTED)


## La difficulté de donjon suivante que la PE ouvre : {name, need} (Héroïque, puis Mythique ; la plus facile des donjons
## ouverts) ; {} si aucun donjon n'est ouvert ou tout est ouvert.
static func next_gate() -> Dictionary:
	var zones := Dungeons.zone_ids().filter(func(z): return Dungeons.is_open(String(z)))
	if zones.is_empty():
		return {}
	for d in [1, 2]:
		var need := -1
		for z in zones:
			var n := Dungeons.power_required(String(z), d)
			if need < 0 or n < need:
				need = n
		if need > GearPower.hero_power() or d == 2:
			return {"name": ["Normal", "Héroïque", "Mythique"][d], "need": need}
	return {}


func _style_family(b: Button, on: bool) -> void:
	if b.has_meta("fam_on") and bool(b.get_meta("fam_on")) == on:
		return  # déjà habillé (DA v2, lot GX-3 : onglet actif mandarine, les autres en puits d'encre)
	b.set_meta("fam_on", on)
	UiTheme.style_button(b, "mandarine" if on else "nuit", 13, {"shadow": 2, "pad": Vector2(4, 2)})
	b.add_theme_font_override("font", UiTheme.bold_font())
	b.add_theme_stylebox_override("pressed", b.get_theme_stylebox("normal"))
	b.add_theme_color_override("icon_normal_color", Color.WHITE if on else ICON_GOLD)
	b.add_theme_color_override("icon_pressed_color", Color.WHITE)


func _refresh_grid() -> void:
	for id in _fam_buttons:
		_fam_buttons[id].set_pressed_no_signal(id == _family)
		_style_family(_fam_buttons[id], id == _family)
	for c in _grid.get_children():
		c.queue_free()
	var q := _search.text.strip_edges().to_lower()
	var all := _entries()
	var list := all.filter(func(e): return (_family == "all" or family_of(e) == _family) and (q == "" or entry_name(e).to_lower().contains(q)))
	# lot GX-3 : pastilles de filtre
	if _useless_dirty:
		_useless = useless_items() if not Profile.in_run else []
		_useless_dirty = false
	var useless := _useless
	if _chip != "":
		list = list.filter(func(e): return _chip_ok(e, useless))
	if _slot_filter != "":
		list = all.filter(func(e): return String(e.kind) == "item" and String(e.item.slot) == _item_slot(_slot_filter) and (q == "" or entry_name(e).to_lower().contains(q)))
		list.sort_custom(func(a, b): return EquipmentPage._power_of(a.item) > EquipmentPage._power_of(b.item))
	else:
		list = _sorted(list)
	for id in _chip_buttons:
		_chip_buttons[id].set_pressed_no_signal(id == _chip)
	_chip_buttons["useless"].text = "Inutiles · %d" % useless.size() if not useless.is_empty() else "Inutiles"
	var n_new := Profile.inventory.filter(func(x): return Profile.is_new(x)).size()
	_chip_buttons["new"].text = "Nouveautés · %d" % n_new if n_new > 0 else "Nouveautés"
	_mass_btn.visible = _chip == "useless" and not useless.is_empty() and not Profile.in_run
	_mass_btn.text = "Démonter les %s" % GearPower.plural(useless.size(), "pièce inutile", "pièces inutiles")
	_undo_btn.visible = not _undo.is_empty() and not Profile.in_run
	_mass_btn.get_parent().visible = _mass_btn.visible or _undo_btn.visible
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
	s.wear_check = String(e.kind) == "item"
	s.badge = ("%d" % int(e.count)) if e.has("count") else ""
	if String(e.kind) == "item" and not Profile.in_run and not Profile.item_users(String(e.item.uid)).is_empty():
		s.badge = "P"  # dans un préréglage (le ★ est celui des objectifs, lot GX-3)
	s.selected = _same(e, _selected)
	s.can_drop = func(data): return data.source == "equipped"
	s.on_drop = func(data): _unequip(String(data.slot))
	s.pressed.connect(func(): _select(e))
	if String(e.kind) == "item":  # survol : l'écart sur les stats du héros (lot GX-3)
		s.mouse_entered.connect(func(): _preview_stats(e.item))
		s.mouse_exited.connect(func(): _preview_stats({}))
	s.activated.connect(func():
		if String(e.kind) == "item":
			_equip(e.item))
	if String(e.kind) == "item":
		s.set_meta("pad_x", "Équiper")  # manette : X = clic droit (lot GX-4)
	return s


# --- lot GX-3 : pastilles, pièces inutiles, démontage en masse, cadenas -----------------------------------------------
## L'entrée [param e] passe la pastille choisie ([member _chip]) ; [param useless] : useless_items().
func _chip_ok(e: Dictionary, useless: Array) -> bool:
	if String(e.kind) != "item":
		return false
	var it: Dictionary = e.item
	match _chip:
		"class":
			return String(it.slot) in Items.SLOTS and (String(it.slot) != "weapon" or Items.weapon_type_of(it) == Items.default_weapon_type(_cls()))
		"wear":
			return String(it.slot) in Items.SLOTS and HeroLevel.can_wear(it)
		"new":
			return Profile.is_new(it)
		"kept":
			return Profile.is_locked(it)
		"useless":
			return useless.any(func(x): return is_same(x, it))
	return true


## Pièces « inutiles » du coffre commun : ni gardées (cadenas), ni portées, ni dans un préréglage d'une classe, ni
## améliorées, serties ou enchantées, ni la pièce d'un objectif, ni la meilleure de leur emplacement (arme : de leur type)
## pour l'un des profils de classe ou pour la PE. Ce sont les seules que « Démonter les N pièces inutiles » touche.
static func useless_items() -> Array:
	if Profile.in_run:
		return []
	var used := {}
	for cls in Profile.presets:
		for s in Profile.presets[cls].get("sets", []):
			for uid in (s.get("slots", {}) as Dictionary).values():
				used[String(uid)] = true
	for it in Profile.equipped.values():
		used[String(it.get("uid", ""))] = true
	var all := Profile.all_items().filter(func(it): return String(it.get("slot", "")) in Items.SLOTS)
	# la meilleure de chaque case pour chaque profil (et pour la PE commune) reste
	var keep := {}
	var profiles: Array = [{}]
	for pid in ClassGear.profile_ids():
		var p: Dictionary = (ClassGear.data().profiles[pid] as Dictionary).duplicate()
		p["id"] = pid
		profiles.append(p)
	for prof in profiles:
		var best := {}
		for it in all:
			var key := String(it.slot) + ("|" + Items.weapon_type_of(it) if String(it.slot) == "weapon" else "")
			var r := float(GearPower.item_power(it, prof))  # valeur au profil × niveau (comme « Équiper le meilleur »)
			if not best.has(key) or r > float(best[key][0]):
				best[key] = [r, it]
		for key in best:
			keep[String(best[key][1].get("uid", ""))] = true
	var out: Array = []
	for it in Profile.inventory:
		var uid := String(it.get("uid", ""))
		var gems := 0
		for g in it.get("sockets", []):
			if g is Dictionary:
				gems += 1
		if not String(it.get("slot", "")) in Items.SLOTS or Profile.is_locked(it) or used.has(uid) or keep.has(uid) \
				or int(it.get("upgrade", 0)) > 0 or it.has("enchant") or it.get("sv", false) or gems > 0 or Goals.is_goal_item(it):
			continue
		if Items.profile_gain(it) > 0.0:
			continue  # mieux que la pièce portée de la classe affichée : jamais « inutile »
		out.append(it)
	return out


## « Démonter les N pièces inutiles » : confirmation (ce que ça rend), puis démontage ; annulable pendant la séance.
func _on_mass_dismantle() -> void:
	var list := useless_items()
	if list.is_empty():
		return
	var total := {}
	for it in list:
		var y := Items.disassemble_yield(it)
		for k in y:
			total[k] = int(total.get(k, 0)) + int(y[k])
	var go := func(): _mass_dismantle(list)
	if skip_confirm:
		go.call()
		return
	InfoCard.ask(self, "Démonter %s ?" % GearPower.plural(list.size(), "pièce", "pièces"),
		"Elles rendent %s. Jamais une pièce gardée, portée, dans un préréglage ou la meilleure de sa case. Annulable tant que tu restes ici." % ItemWidgets.materials_text(total, true),
		"Démonter", go)


## Tests : démontage en masse sans la carte de confirmation.
static var skip_confirm := false


func _mass_dismantle(list: Array) -> void:
	var got := Profile.disassemble_many(list.filter(func(it): return not Profile.is_locked(it)))
	_undo = {"items": list, "gained": got}
	_selected = {}
	refresh()
	_say("%s démontées : %s" % [GearPower.plural(list.size(), "pièce", "pièces"), ItemWidgets.materials_text(got, true)])


func _on_undo_dismantle() -> void:
	if _undo.is_empty():
		return
	var ok := Profile.undo_disassemble(_undo.items, _undo.gained)
	var n: int = (_undo.items as Array).size()
	_undo = {}
	refresh()
	_say("Démontage annulé : %s de retour." % GearPower.plural(n, "pièce", "pièces") if ok else "Trop tard : les cristaux ont déjà servi.", UiTheme.BUFF if ok else ItemWidgets.LOCK_TEXT)


## Cadenas de la pièce choisie (bouton « Garder », touche L).
func _on_lock() -> void:
	if _selected.get("kind", "") != "item":
		return
	var it: Dictionary = _selected.item
	Profile.set_locked(it, not Profile.is_locked(it))
	_armed_dismantle = false
	_useless_dirty = true
	_refresh_grid()
	_refresh_detail()
	_say("Gardée : elle ne sera jamais démontée." if Profile.is_locked(it) else "Cadenas retiré.")


func _unhandled_key_input(event: InputEvent) -> void:
	if not is_visible_in_tree() or not (event is InputEventKey) or not event.pressed or event.echo:
		return
	if event.keycode == KEY_L and not event.ctrl_pressed and _selected.get("kind", "") == "item" and not Profile.in_run \
			and not (get_viewport().gui_get_focus_owner() is LineEdit):
		_on_lock()
		get_viewport().set_input_as_handled()


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
	if e.get("kind", "") == "item":
		Profile.mark_seen(e.item)  # regardée : plus « neuf » (lot GX-3)
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
func _say(text: String, color := UiTheme.BUFF) -> void:
	_msg.add_theme_color_override("font_color", color)
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
			("Gardés entre les parties (on les obtient en démontant des objets)." if key == "crystal" else "Perdus en fin de partie : à dépenser !"))
		_d_set.text = "[b]Utilisation[/b]\n[color=#c8c8d4]%s[/color]" % ("Forge : gemmes, formules d'enchantement, parchemins de fortification, pierres de sûreté ; fusion de 3 gemmes identiques." if String(e.kind) == "stack" else "Voir l'aide « ? » : Monnaies.")
		for b in [_b_equip, _b_dismantle]:
			b.disabled = true
		_b_offhand.visible = false
		_b_lock.visible = false
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
	# lot H3 : au-dessus du niveau de héros, le niveau en rouge (orange si la pièce est déjà portée : elle reste) ; la phrase
	# entière en infobulle, sur le bouton et au refus (1280 px : la fiche n'a pas la place d'une ligne de plus)
	var req := HeroLevel.wear_block(it)
	_d_level.add_theme_color_override("font_color", UiTheme.TEXT if req == 0 else (LOCK_WORN if equipped else ItemWidgets.LOCK_TEXT))
	_d_level.tooltip_text = "" if req == 0 else HeroLevel.lock_text(it) + (" · déjà portée, elle reste" if equipped else "")
	_d_level.mouse_filter = Control.MOUSE_FILTER_PASS if req > 0 else Control.MOUSE_FILTER_IGNORE
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
			fl.append("Préréglage : " + ", ".join(users))
	_d_flavor.text = "[i][color=#b8b4c8]%s[/color][/i]" % "\n".join(fl)
	_d_set.text = _set_bbcode(it)
	_refresh_compare(it, equipped)
	_b_equip.disabled = false
	_b_equip.text = "Retirer" if equipped else "Équiper"
	_b_equip.tooltip_text = ""
	if req > 0 and not equipped:
		_b_equip.disabled = true  # lot H3 : le bouton dit pourquoi
		_b_equip.text = "Niveau %d requis" % req
		_b_equip.tooltip_text = HeroLevel.lock_text(it)
	if it.slot == "trophy":
		_b_equip.disabled = true  # ancien trophée : les trophées se trouvent pendant la run (collection)
		_b_equip.tooltip_text = "Les trophées ne s'équipent plus : jusqu'à %d par partie, trouvés dans les coffres de trophée." % Run.MAX_TROPHIES
	var off: Dictionary = Profile.equipped.get("offhand", {})
	_b_offhand.visible = it.slot == "weapon" and worn_slot != "offhand" and (worn_slot != "weapon" or Profile.can_be_main(off))
	_b_offhand.text = "Échanger" if worn_slot == "weapon" else "Secondaire"
	if it.slot == "weapon" and not equipped and not Profile.can_be_main(it) and req == 0:
		_b_equip.text = "Équiper (secondaire)"  # une arme d'un autre type que la classe
		_b_offhand.visible = false
	if req > 0 and not equipped:
		_b_offhand.visible = false
	if SurvivorGear.locked(String(it.slot)):
		_b_equip.disabled = true  # Survivant : la pièce posée reste toute la run, l'emplacement aussi
		_b_equip.text = SurvivorGear.LOCK_TEXT
		_b_offhand.visible = false
	_b_upgrade.disabled = false
	var up := "Amélioration maximale" if int(it.get("upgrade", 0)) >= Items.MAX_UPGRADE else "Prochain niveau : %d %% de réussite" % roundi(Craft.success_chance(it) * 100.0)
	_b_upgrade.tooltip_text = up if Profile.in_run else up + "\nHors partie : fournitures de ta réserve, or remplacé par des cristaux (1 pour %d or)." % Forge.GOLD_PER_CRYSTAL
	var users := Profile.item_users(String(it.get("uid", ""))) if not Profile.in_run else []
	_b_dismantle.tooltip_text = "Retire d'abord l'objet." if equipped else (("Attention : utilisé par le préréglage de " + ", ".join(users)) if not users.is_empty() else "")
	_b_dismantle.text = "Confirmer ?" if _armed_dismantle else "Démonter"
	# lot GX-3 : cadenas
	var locked := Profile.is_locked(it)
	_b_lock.visible = not Profile.in_run and String(it.slot) != "trophy"
	_b_lock.text = "Gardée" if locked else "Garder"
	_b_lock.tooltip_text = "Gardée : jamais démontée, ni seule ni en masse. Clic (ou L) : retirer le cadenas." if locked \
		else "Garder (L) : la pièce ne pourra plus être démontée, ni seule ni en masse."
	if not _b_lock.has_meta("locked_tone") or bool(_b_lock.get_meta("locked_tone")) != locked:
		_b_lock.set_meta("locked_tone", locked)
		UiTheme.style_button(_b_lock, "lagon" if locked else "nuit", 15, {"shadow": 3, "pad": Vector2(6, 2)})
	if locked:
		_b_dismantle.disabled = true
		_b_dismantle.tooltip_text = "Pièce gardée : retire d'abord le cadenas."
	else:
		_b_dismantle.disabled = equipped


## Pièce portée à l'emplacement où irait [param it] (l'arme d'un autre type que la classe va en secondaire).
func _compare_target(it: Dictionary) -> Dictionary:
	if it.slot == "weapon" and not Profile.can_be_main(it):
		return Profile.equipped.get("offhand", {})
	return Profile.equipped.get(it.slot, {})


## Carte « Pièce portée » : la pièce en place et ce que change l'échange (mieux ou moins bien, puissance).
func _refresh_compare(it: Dictionary, equipped: bool) -> void:
	_d_cmp.visible = not equipped
	_d_verdict.text = ""
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
	else:
		_d_cmp_name.text = Items.display_name(worn)
		_d_cmp_name.add_theme_color_override("font_color", Items.color_of(worn))
		_d_cmp_level.text = "Niv. %d%s" % [int(worn.level), ("   +%d" % int(worn.get("upgrade", 0))) if int(worn.get("upgrade", 0)) > 0 else ""]
	# lot GX-3 : le mot au profil de la classe, le chiffre en PE (jamais de pourcentage)
	var v := Items.verdict(it, worn)
	txt = "[b][color=%s]%s[/color][/b]" % [String(Items.TONE_COLORS[v.tone]), String(v.word).replace(" pour ", "\npour ") if _narrow() else String(v.word)]
	if String(it.slot) in Items.SLOTS and not (it.slot == "weapon" and not Profile.can_be_main(it)):
		var dpe := int(v.dpe)
		txt += "\n[color=%s]PE %s%s[/color]" % ["#c3f07a" if dpe >= 0 else "#ff9db0", "+" if dpe >= 0 else "−", GearPower.fmt(absi(dpe))]
	_d_cmp_verdict.text = txt
	if HeroLevel.wear_block(it) == 0:
		_d_verdict.text = txt.replace("\npour ", " pour ").replace("\n", "   ")


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
	for k in keys.slice(0, 6 if _short() else 8):  # 720 px : la grille du sac garde deux rangées (lot GX-3)
		var v := float(st.get(k, 0.0))
		var pct: bool = k in Items.PERCENT_STATS
		var name := String(Items.STAT_NAMES.get(k, Items.EXTRA_STAT_NAMES.get(k, k)))
		var val := ("%d %%" % roundi(v * 100.0)) if pct else str(roundi(v))
		var diff := ""
		if not worn.is_empty():
			var dv := v - float(wst.get(k, 0.0))
			if absf(dv) > 0.0001:
				var dtxt := ("%+d %%" % roundi(dv * 100.0)) if pct else ("%+d" % roundi(dv))
				diff = "  [color=%s]%s %s[/color]" % ["#c3f07a" if dv > 0 else "#ff9db0", "▲" if dv > 0 else "▼", dtxt]  # lot GX-3 : plus de parenthèses
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
	if _refused(it):
		return
	Profile.equip(it)
	_after_change({"kind": "item", "item": it})


## Lot H3 : pièce au-dessus du niveau de héros ; le dit en une ligne (« Niveau 60 requis · tu es niveau 34 »).
func _refused(it: Dictionary) -> bool:
	var t := HeroLevel.lock_text(it)
	if t == "":
		return false
	_select({"kind": "item", "item": it})
	_say(t, ItemWidgets.LOCK_TEXT)
	Sfx.ui("error")
	return true


func _unequip(slot: String, confirmed := false) -> void:
	var it: Dictionary = Profile.equipped.get(slot, {})
	if it.is_empty():
		return
	var req := HeroLevel.wear_block(it)
	if req > 0 and not confirmed:
		# pièce portée d'avant le niveau de héros : la retirer, c'est ne plus pouvoir la remettre tout de suite
		InfoCard.ask(self, "Retirer cette pièce ?", "Tu ne pourras la remettre qu'au niveau %d." % req,
			"Retirer", func(): _unequip(slot, true))
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
	if not _is_equipped(_selected.item) and _refused(_selected.item):
		return
	Profile.equip_offhand(_selected.item)
	_after_change({"kind": "item", "item": _selected.item})


func _on_dismantle() -> void:
	if _selected.get("kind", "") != "item" or _is_equipped(_selected.item) or Profile.is_locked(_selected.item):
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
			w.hud.show_message("Survie : l'amélioration des pièces se fait au hub (Atelier)", 3.0)
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
	var extra := "" if player else "\n\n[color=#9a98a8]Hors partie : héros niveau %d avec l'équipement porté, les talents, les certificats et la collection.[/color]" % _level()
	InfoDialog.open(self, "Statistiques — %s" % GameData.class_data(_cls()).get("name_fr", ""), "\n".join(lines).strip_edges() + extra)


## Aperçu de la panoplie (lot GX-4) : la panoplie la plus portée, même sans bonus encore (« 1 / 6 · bonus à 2 »), le
## palier suivant ; au survol, ses paliers (✓ = actif). Sans aucune pièce de panoplie : d'où elles viennent.
func _set_preview() -> void:
	var counts := Items.set_counts(Profile.set_gear())
	var best := ""
	for sid in counts:
		if not Items.set_def(String(sid)).is_empty() and (best == "" or int(counts[sid]) > int(counts[best])):
			best = String(sid)
	if best == "":
		_set_text.text = "Aucune panoplie portée"
		_set_text.tooltip_text = "Les panoplies viennent des donjons (coffre de set) ; 2, 4 et 6 pièces portées donnent des bonus."
		_set_text.add_theme_color_override("font_color", UiTheme.MUTED)
		return
	var n := int(counts[best])
	var tiers := Items.set_tiers(best)
	var full := int(tiers[-1]) if not tiers.is_empty() else n
	var next := 0
	for t in tiers:
		if int(t) > n:
			next = int(t)
			break
	var nm := String(Items.set_def(best).get("name", ""))
	_set_text.text = "%s · %d / %d · %s" % [nm, n, full, ("bonus à %d" % next) if next > 0 else "complète"]
	var tips: PackedStringArray = [nm]
	for t in tiers:
		tips.append("%s %d : %s" % ["✓" if n >= int(t) else "·", int(t), " ; ".join(Items.bonus_lines(Items.set_bonus(best, int(t))))])
	_set_text.tooltip_text = "\n".join(tips)
	_set_text.mouse_filter = Control.MOUSE_FILTER_PASS
	_set_text.add_theme_color_override("font_color", UiTheme.TEXT if n >= (int(tiers[0]) if not tiers.is_empty() else 2) else UiTheme.MUTED)


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
