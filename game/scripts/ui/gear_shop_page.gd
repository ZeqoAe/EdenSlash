class_name GearShopPage
extends HBoxContainer
## Atelier > Fabriquer (hub, ex-Armurerie ; lot A3 de la refonte) : le catalogue des pièces que les coffres d'emplacement
## de la Survie peuvent proposer (Completion.armory_ids). Une pièce choisie une fois dans un coffre est « découverte »
## (Profile.seen_gear) : c'est son plan. Elle se fabrique avec les insignes gagnés en Survie (mêmes prix qu'avant) ;
## fabriquée, elle rejoint le coffre commun (+0) : collection, JcJ non normalisé et toute l'optimisation du hub (forge,
## gemmes, enchantements). Les plans pas encore trouvés se voient en silhouette (« Plans à découvrir »), avec l'époque
## et la carte où les trouver. Filtres : statut, emplacement, époque, classe. Les noms internes (`_buy`, `_on_buy`,
## états « buy » / « owned » / « locked ») restent ceux d'avant : seuls les textes lus par le joueur changent.
## Fabriquer v2 (lot GX-2) : vue par défaut « paliers » : à gauche les douze cartes (x / 9 pièces du kit fabriquées, « ta
## bande » en lagon), au centre la poupée du kit de la classe pour ce palier (fabriquée / plan connu et prix / plan à
## trouver et où), « Fabriquer les N plans connus » (confirmation du coût) ; à droite la fiche, « il en manque N ≈ X
## cartes de Survie » et « Fabriquer et porter ». Le catalogue filtrable d'avant reste derrière « Catalogue complet ».

const COLS := 12
const ROWS := 7
const CELL := 70.0
## Statuts affichables : [id, libellé].
## « wear » (lot H3) : les plans trouvés que le niveau de héros permet de porter (fabriquer au-dessus reste permis).
const STATUSES := [["buy", "À fabriquer"], ["owned", "Fabriquées"], ["locked", "Plans à découvrir"], ["all", "Tous"], ["wear", "Portables"],
	["goal", "★ Objectifs"]]

var _f_status: OptionButton
var _f_slot: OptionButton
var _f_epoch: OptionButton
var _f_class: OptionButton
var _f_search: LineEdit  # recherche par nom (lot GX-4)
var _slot_ids: Array = []  # emplacement de chaque entrée de _f_slot ("" : tous)
var _class_ids: Array = []  # classe de chaque entrée de _f_class ("" : toutes)
var _count: Label
var _grid: GridContainer
var _empty: Label
var _prev: Button
var _next: Button
var _page_label: Label
var _detail_box: VBoxContainer
var _right: Control  # le panneau de droite (caché quand il n'y a rien à montrer)
var _short: Label
var _buy: Button
var _all: Array = []  # [{id, e, state, epoch, slot, level}] : tout le catalogue
var _rows: Array = []  # le catalogue filtré et trié
var _cells := {}  # id -> case affichée
var _page := 0
var _sel := -1  # id d'Eden de la pièce choisie
var _filters_ready := false
var _just_bought := false
## Lot GX-2 : vue « tiers » (paliers, défaut) ou « catalog » ; palier choisi (époque, carte) ; widgets de la vue.
var view := "tiers"
var _tier := Vector2i.ZERO
var _tier_list: VBoxContainer
var _tier_buttons := {}
var _kit_box: VBoxContainer
var _kit_grid: GridContainer
var _kit_title: Label
var _kit_sub: Label
var _kit_all: Button
var _kit_miss: Label
var _kit: Array = []
var _bar: HBoxContainer
var _holder: Control
var _view_btn: Button
var _tier_col: Control
var _head: Label
var _wear: Button
var _goal_bar: GoalBar  # lot GX-3 : l'objectif épinglé, en haut de la colonne des paliers
## Tests : « Fabriquer les N plans connus » sans la carte de confirmation.
static var skip_confirm := false


func subtitle() -> String:
	return "Pièces dont tu as le plan"


## Prix en insignes : selon la rareté et le niveau de la pièce, remisé quand son palier est entamé (Economy, lot E5).
static func price(e: Dictionary) -> int:
	return Economy.armory_price(e)


## Ids des pièces déjà possédées (dans le coffre commun ou portées).
static func owned_ids() -> Dictionary:
	var out := {}
	for it in Profile.all_items():
		var id := int(it.get("eden", -1))
		if id >= 0:
			out[id] = true
	return out


## Pièce [param id] déjà fabriquée (dans le coffre commun ou portée) ?
static func owned(id: int) -> bool:
	for it in Profile.all_items():
		if int(it.get("eden", -1)) == id:
			return true
	return false


## Aperçu (ou pièce fabriquée) de la pièce [param e] : +0, à son niveau.
static func make(e: Dictionary) -> Dictionary:
	var it := Items.from_template(e, int(e.level), int(e.rarity))
	it["upgrade"] = 0
	it["quality"] = 1.0
	if GameData.is_awakened(e):
		it["awakened"] = true
	return it


## Fenêtre de 1280 × 720 : moins de colonnes et de lignes (la grille passait sous la fiche de droite).
func _grid_cols() -> int:
	return COLS if get_viewport().get_visible_rect().size.x >= 1500.0 else 9


func _grid_rows() -> int:
	return ROWS if get_viewport().get_visible_rect().size.y >= 840.0 else 6


func _ready() -> void:
	add_theme_constant_override("separation", 14)
	Completion.warm_armory.call_deferred()  # le catalogue vient du cache disque, sinon se calcule par tranches pendant l'affichage (P2)
	# 1) colonne des paliers (lot GX-2)
	var col := ItemWidgets.panel(self, 250.0 if _narrow() else 300.0)
	var th := Hud._label(col, "Paliers", 20, UiTheme.GOLD)
	th.add_theme_font_override("font", UiTheme.title_font())
	_goal_bar = GoalBar.new(true)
	_goal_bar.narrow = true
	col.add_child(_goal_bar)
	col.move_child(_goal_bar, 0)
	var tsc := ScrollContainer.new()
	tsc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tsc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(tsc)
	_tier_list = VBoxContainer.new()
	_tier_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tier_list.add_theme_constant_override("separation", 6)
	tsc.add_child(_tier_list)
	_tier_col = col.get_parent()
	# 2) centre : la poupée du palier, ou le catalogue
	var left := ItemWidgets.panel(self, 0, true)
	var hh := HBoxContainer.new()
	left.add_child(hh)
	var head := Hud._label(hh, "Fabriquer", 20, UiTheme.GOLD)
	head.add_theme_font_override("font", UiTheme.title_font())
	head.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_head = head
	_count = Hud._label(hh, "", 18, UiTheme.TEXT)
	_count.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_view_btn = ForgeWidgets.candy_button("Catalogue complet", "nuit", 14, 34)
	_view_btn.tooltip_text = "Tous les plans, avec des filtres (statut, emplacement, époque, classe)."
	_view_btn.pressed.connect(func(): set_view("catalog" if view == "tiers" else "tiers"))
	hh.add_child(_view_btn)
	_build_kit_box(left)
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 6)
	left.add_child(bar)
	_bar = bar
	_f_status = _option(bar, STATUSES.map(func(s): return String(s[1])))
	_f_slot = _option(bar, ["Emplacement"])
	_f_epoch = _option(bar, ["Époque"])
	_f_class = _option(bar, ["Classe"])
	# lot GX-4 : recherche par nom dans les plans découverts (les plans à découvrir restent anonymes)
	_f_search = LineEdit.new()
	_f_search.placeholder_text = "Chercher"
	_f_search.clear_button_enabled = true
	_f_search.custom_minimum_size = Vector2(110, 0)
	_f_search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_f_search.add_theme_font_size_override("font_size", 14)
	_f_search.text_changed.connect(func(_t):
		_page = 0
		_sel = -1
		_apply())
	bar.add_child(_f_search)
	_prev = _pager_button(bar, "‹", -1)
	_page_label = Hud._label(bar, "", 15, UiTheme.MUTED)
	_page_label.custom_minimum_size = Vector2(70, 0)
	_page_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_next = _pager_button(bar, "›", 1)
	var holder := Control.new()
	holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_child(holder)
	_holder = holder
	_grid = GridContainer.new()
	_grid.columns = _grid_cols()
	_grid.add_theme_constant_override("h_separation", 6)
	_grid.add_theme_constant_override("v_separation", 6)
	holder.add_child(_grid)
	_empty = Hud._label(holder, "", 17, UiTheme.MUTED)
	_empty.set_anchors_preset(Control.PRESET_FULL_RECT)
	_empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_empty.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var right := ItemWidgets.panel(self, 360.0 if _narrow() else 420.0)
	_right = right.get_parent()
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right.add_child(sc)
	_detail_box = VBoxContainer.new()
	_detail_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail_box.add_theme_constant_override("separation", 10)
	sc.add_child(_detail_box)
	_short = Hud._label(right, "", 15, UiTheme.DEBUFF)
	_short.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_buy = MenuWidgets.gold_button("Fabriquer", 20, Vector2(0, 46 if _short_screen() else 52))
	_buy.pressed.connect(_on_buy)
	right.add_child(_buy)
	_wear = ForgeWidgets.candy_button("Fabriquer et porter", "lagon", 17, 40 if _short_screen() else 44)
	_wear.pressed.connect(func(): _on_buy(true))
	right.add_child(_wear)
	set_view(view)


## Vue « paliers » : titre du palier, ligne du kit, la grille 3 × 3, la légende, puis « Fabriquer les N plans connus ».
func _build_kit_box(parent: Control) -> void:
	_kit_box = VBoxContainer.new()
	_kit_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_kit_box.add_theme_constant_override("separation", 6)
	parent.add_child(_kit_box)
	_kit_title = Hud._label(_kit_box, "", 22, ForgeWidgets.TEXTE)
	_kit_title.add_theme_font_override("font", UiTheme.bold_font())
	_kit_sub = Hud._label(_kit_box, "", 15, ForgeWidgets.TEXTE_2)
	var cc := CenterContainer.new()
	cc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_kit_box.add_child(cc)
	_kit_grid = GridContainer.new()
	_kit_grid.columns = 3
	_kit_grid.add_theme_constant_override("h_separation", 22)
	_kit_grid.add_theme_constant_override("v_separation", 2 if _short_screen() else 8)
	cc.add_child(_kit_grid)
	var leg := Hud._label(_kit_box, "Pleine : fabriquée · voilée : plan connu · « ? » : plan à trouver", 14, ForgeWidgets.TEXTE_2)
	leg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	leg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_kit_all = ForgeWidgets.candy_button("", "lagon", 17, 40 if _short_screen() else 46)
	_kit_all.pressed.connect(_on_kit_all)
	_kit_box.add_child(_kit_all)
	_kit_miss = Hud._label(_kit_box, "", 14, ForgeWidgets.TEXTE_2)
	_kit_miss.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_kit_miss.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


func _option(parent: Control, labels: Array) -> OptionButton:
	var o := OptionButton.new()
	o.focus_mode = Control.FOCUS_NONE
	o.fit_to_longest_item = false  # largeur du choix affiché (1280 px : la page ne doit pas sortir de l'écran)
	o.add_theme_font_size_override("font_size", 14)
	for l in labels:
		o.add_item(String(l))
	o.item_selected.connect(func(_i):
		_page = 0
		_sel = -1  # un autre filtre : on repart de la première pièce
		_apply())
	parent.add_child(o)
	return o


func _pager_button(parent: Control, text: String, delta: int) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(38, 32)
	b.add_theme_font_size_override("font_size", 18)
	b.pressed.connect(func():
		_page += delta
		_apply())
	parent.add_child(b)
	return b


## Les listes d'emplacements, d'époques et de classes (au premier affichage : le catalogue est alors calculé).
func _ensure_filters() -> void:
	if _filters_ready:
		return
	_filters_ready = true
	var slots := {}
	for r in _all:
		slots[String(r.slot)] = true
	_slot_ids = [""]
	_f_slot.clear()
	_f_slot.add_item("Tous les emplacements")
	for s in Items.SLOTS:
		if slots.has(s):
			_slot_ids.append(s)
			_f_slot.add_item(String(Items.SLOT_NAMES.get(s, s)))
	_f_epoch.clear()
	_f_epoch.add_item("Toutes les époques")
	for ep in range(1, Epochs.count() + 1):
		_f_epoch.add_item(String(Epochs.get_def(ep).name))
	var names := {}
	for cid in GameData.classes:
		names[String(cid)] = String(GameData.class_data(String(cid)).get("name_fr", cid))
	var order: Array = names.keys()
	order.sort_custom(func(a, b): return names[a] < names[b])
	_class_ids = [""]
	_f_class.clear()
	_f_class.add_item("Toutes les classes")
	for cid in order:
		_class_ids.append(cid)
		_f_class.add_item(names[cid])


func refresh() -> void:
	if not is_inside_tree():
		return
	_build_all()
	_ensure_filters()
	_refresh_goal()
	if view == "tiers":
		_count.text = "%s / %s plans" % [GearPower.fmt(Completion.armory_done()), GearPower.fmt(maxi(Completion.armory_done(), Completion.armory_total()))]
		if _tier == Vector2i.ZERO:
			_tier = default_tier()
		_show_tier()
	else:
		_apply()


## Tout le catalogue avec l'état de chaque pièce : « buy » (plan trouvé, à fabriquer), « owned » (fabriquée), « locked » (plan à découvrir).
func _build_all() -> void:
	var have := owned_ids()
	var seen := {}
	for id in Profile.seen_gear:
		seen[int(id)] = true
	var cat := Completion.armory_ids()
	var ids: Array = cat.keys()
	for id in seen:
		if not cat.has(id):
			ids.append(id)  # une pièce vue hors des tirages actuels reste visible
	_all.clear()
	for id in ids:
		var e: Dictionary = GameData.eden_by_id.get(int(id), {})
		if e.is_empty() or String(e.get("slot", "")) == "trophy":
			continue
		var st := "owned" if have.has(int(id)) else ("buy" if seen.has(int(id)) else "locked")
		var row := {"id": int(id), "e": e, "state": st, "epoch": int(cat.get(id, 0)), "slot": String(e.slot), "level": int(e.get("level", 1))}
		row["k0"] = _sort_key(row, false, RANK)  # clés de tri calculées une fois (P2) : le tri ne rappelle plus _sort_key à chaque comparaison
		row["k1"] = _sort_key(row, true, RANK)
		_all.append(row)


## Filtre, trie et affiche la page courante.
func _apply() -> void:
	var status := String(STATUSES[maxi(_f_status.selected, 0)][0])
	var slot := String(_slot_ids[_f_slot.selected]) if _f_slot.selected >= 0 and _f_slot.selected < _slot_ids.size() else ""
	var epoch := _f_epoch.selected  # 0 : toutes
	var cid := String(_class_ids[_f_class.selected]) if _f_class.selected >= 0 and _f_class.selected < _class_ids.size() else ""
	var wtype := Items.default_weapon_type(cid) if cid != "" else ""
	var hl := HeroLevel.level()
	var q := _f_search.text.strip_edges() if _f_search else ""
	_rows = _all.filter(func(r):
		if q != "" and (r.state == "locked" or not ItemWidgets.ItemGrid.name_matches(r.e, q)):
			return false
		if status == "wear":
			if r.state == "locked" or int(r.level) > hl:
				return false
		elif status == "goal":
			if not Goals.has(Goals.piece_id(int(r.id))):
				return false
		elif status != "all" and r.state != status:
			return false
		if slot != "" and r.slot != slot:
			return false
		if epoch > 0 and int(r.epoch) != epoch:
			return false
		if wtype != "" and r.slot == "weapon" and String(r.e.get("wtype", "")) != wtype:
			return false
		return true)
	var kk := "k1" if status in ["all", "wear", "goal"] else "k0"
	_rows.sort_custom(func(a, b): return a[kk] < b[kk])
	var per := _grid_cols() * _grid_rows()
	var pages := maxi(1, ceili(_rows.size() / float(per)))
	_page = clampi(_page, 0, pages - 1)
	# la pièce choisie reste choisie après sa fabrication, même si le filtre ne la montre plus (pas de double fabrication par un double clic)
	if _row_of(_sel).is_empty() or (not _rows.any(func(r): return int(r.id) == _sel) and not _just_bought):
		_sel = int(_rows[0].id) if not _rows.is_empty() else -1
	_just_bought = false
	_count.text = "%s / %s plans découverts" % [GearPower.fmt(Completion.armory_done()), GearPower.fmt(maxi(Completion.armory_done(), Completion.armory_total()))]
	_prev.visible = pages > 1
	_next.visible = pages > 1
	_page_label.visible = pages > 1
	_prev.disabled = _page <= 0
	_next.disabled = _page >= pages - 1
	_page_label.text = "%d / %d" % [_page + 1, pages]
	_fill_grid(per)
	_show_detail()


const RANK := {"buy": 0, "owned": 1, "locked": 2}


func _sort_key(r: Dictionary, by_state: bool, rank: Dictionary) -> float:
	var s := float(rank[r.state]) if by_state else 0.0
	return ((s * 10.0 + float(r.epoch)) * 20.0 + float(maxi(Items.SLOTS.find(r.slot), 0))) * 1000.0 + float(r.level) + float(r.id) * 0.000001


func _row_of(id: int) -> Dictionary:
	for r in _all:
		if int(r.id) == id:
			return r
	return {}


func _fill_grid(per: int) -> void:
	for c in _grid.get_children():
		_grid.remove_child(c)
		c.queue_free()
	_cells.clear()
	for r in _rows.slice(_page * per, (_page + 1) * per):
		var row: Dictionary = r
		var cell: Control
		if row.state == "locked":
			var sil := Silhouette.new(CELL)
			sil.slot_name = String(Items.SLOT_NAMES.get(row.slot, row.slot))
			sil.level = int(row.level)
			sil.goal = Goals.has(Goals.piece_id(int(row.id)))
			sil.tooltip_text = "Plan pas encore découvert"
			cell = sil
		else:
			var it := make(row.e)
			var s := ItemWidgets.ItemSlot.new(CELL)
			s.set_item(it)
			s.show_compare = row.state == "buy"
			s.badge = "✓" if row.state == "owned" else "%d" % price(row.e)
			s.dim = row.state == "owned"
			s.wear_check = true  # au-dessus du niveau de héros : en rouge (lot H3)
			cell = s
		cell.set("selected", int(row.id) == _sel)
		cell.pressed.connect(_select.bind(int(row.id)))
		_grid.add_child(cell)
		_cells[int(row.id)] = cell
	_empty.text = "" if not _rows.is_empty() else _empty_text()
	_empty.visible = _rows.is_empty()
	_right.visible = not _rows.is_empty()


func _empty_text() -> String:
	match String(STATUSES[maxi(_f_status.selected, 0)][0]):
		"buy":
			return "Aucun plan trouvé pour l'instant.\nEn Survie, chaque coffre d'emplacement en révèle trois." if Completion.armory_done() == 0 \
				else "Rien à fabriquer pour l'instant.\nLa Survie révèle d'autres plans, époque après époque."
		"owned":
			return "Tu n'as encore fabriqué aucune pièce."
		"locked":
			return "Tous les plans sont découverts."
		"wear":
			return "Aucun plan à ton niveau pour l'instant."
		"goal":
			return "Aucun objectif.\nChoisis une pièce puis « ★ Objectif » : ce qui manque s'affiche dans Héros et ici."
	return "Aucun plan pour ces filtres."


func _select(id: int) -> void:
	_sel = id
	for k in _cells:
		_cells[k].set("selected", int(k) == id)
		_cells[k].queue_redraw()
	_show_detail()


func _show_detail() -> void:
	for c in _detail_box.get_children():
		_detail_box.remove_child(c)
		c.queue_free()
	_short.text = ""
	_short.add_theme_color_override("font_color", UiTheme.DEBUFF)
	var row := _row_of(_sel)
	_buy.visible = not row.is_empty() and row.state != "locked"
	_wear.visible = false
	if row.is_empty():
		return
	if row.state == "locked":
		_detail_locked(row)
		return
	var it := make(row.e)
	var r := ItemWidgets.rich(_detail_box, 15)
	r.fit_content = true
	r.scroll_active = false
	r.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	r.text = Items.describe(it, false) + _compare_text(it)  # fiche d'achat : sans « prochaine amélioration » ni niveau de puissance (GX-2)
	var place := Completion.plan_place(int(row.id))
	if place != "":
		var pl := Hud._label(_detail_box, "Plan trouvé : %s" % place, 15, UiTheme.MUTED)
		pl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		pl.tooltip_text = "La première carte dont un coffre propose cette pièce."
	if row.state != "owned":
		_goal_button(int(row.id))
	var p := price(row.e)
	if row.state == "owned":
		_buy.text = "Dans ton coffre"
		_buy.disabled = true
		if not Profile.equipped.values().any(func(w): return int(w.get("eden", -1)) == int(row.id)):
			var lock := HeroLevel.lock_text(it)
			_short.text = lock if lock != "" else "Fabriquée : tu peux la porter"
			_short.add_theme_color_override("font_color", UiTheme.BUFF if lock == "" else UiTheme.DEBUFF)
			_wear.visible = lock == "" and Profile.can_be_main(it) if String(it.slot) == "weapon" else lock == ""
			_wear.text = "Porter"
			_wear.disabled = false
	else:
		_buy.text = "Fabriquer · %s insignes" % GearPower.fmt(p)
		_buy.disabled = Profile.insignia < p
		var wear_lock := HeroLevel.lock_text(it)
		_wear.visible = true
		_wear.text = "Fabriquer et porter"
		_wear.disabled = Profile.insignia < p or wear_lock != ""
		_wear.tooltip_text = wear_lock if wear_lock != "" else "La pièce rejoint aussitôt ton équipement (l'ancienne va au coffre commun)."
		if Profile.insignia < p:
			_short.text = "Il te manque %s insignes ≈ %s" % [GearPower.fmt(p - Profile.insignia), GearPower.plural(Economy.maps_for(p - Profile.insignia), "carte de Survie", "cartes de Survie")]
		elif HeroLevel.wear_block(it) > 0:
			_short.text = "À porter au niveau %d · tu es niveau %d" % [HeroLevel.wear_block(it), HeroLevel.level()]  # fabriquer reste permis
			_short.add_theme_color_override("font_color", UiTheme.MUTED)


## Un plan pas encore découvert : la silhouette de la pièce et où le trouver.
func _detail_locked(row: Dictionary) -> void:
	var big := Silhouette.new(120.0)
	big.disabled = true
	big.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_detail_box.add_child(big)
	var t := Hud._label(_detail_box, "Plan à découvrir", 22, UiTheme.GOLD)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var lines := ["%s · niveau %d" % [String(Items.SLOT_NAMES.get(row.slot, row.slot)), int(row.level)]]
	var place := Completion.plan_place(int(row.id))
	lines.append("Plan à trouver : %s" % place if place != "" else "Coffres d'emplacement de la Survie")
	for l in lines:
		var lab := Hud._label(_detail_box, l, 16, UiTheme.MUTED)
		lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lab.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_goal_button(int(row.id))


## Lot GX-3 (P0-6) : « ★ Objectif » : suivre (et épingler) la pièce [param id] ; le bouton dit si elle est déjà suivie.
func _goal_button(id: int) -> void:
	var gid := Goals.piece_id(id)
	var on := Goals.has(gid)
	var b := ForgeWidgets.candy_button("★ Objectif suivi" if on else "★ Objectif", "mandarine" if on else "nuit", 16, 40 if _short_screen() else 44)
	b.tooltip_text = "Ne plus suivre cette pièce." if on else "Viser cette pièce : ce qui manque (plan, insignes, niveau) s'affiche dans Héros et en haut de cette page."
	b.pressed.connect(func():
		_say(Goals.toggle(gid), UiTheme.BUFF)
		_refresh_goal()
		_show_detail()
		_mark_cells())
	_detail_box.add_child(b)


## ★ sur les cases du palier et du catalogue (objectifs).
func _mark_cells() -> void:
	for id in _cells:
		var c: Control = _cells[id]
		if c is Silhouette:
			(c as Silhouette).goal = Goals.has(Goals.piece_id(int(id)))
		c.queue_redraw()


func _refresh_goal() -> void:
	if is_instance_valid(_goal_bar):
		_goal_bar.refresh()


## Ouvre la page sur l'objectif [param gid] (barre d'objectif, « Fabriquer ») : son palier et sa pièce choisie.
func show_goal(gid: String) -> void:
	if Goals.is_dungeon(gid) or not GameData.eden_by_id.has(int(gid)):
		return
	var id := int(gid)
	var e: Dictionary = GameData.eden_by_id[id]
	var wtype := Items.default_weapon_type(Profile.selected_class)
	var found := Vector2i.ZERO
	if String(e.get("slot", "")) in KIT_SLOTS:
		for ep in range(1, Epochs.count() + 1):  # le premier palier dont la poupée propose la pièce
			for st in range(1, 4):
				if found != Vector2i.ZERO:
					continue
				for x in tier_pool(ep, st, String(e.slot), wtype):
					if int(x.id) == id:
						found = Vector2i(ep, st)
	if view != "tiers" or found == Vector2i.ZERO:
		set_view("catalog")
		_f_status.select(STATUSES.size() - 1)
		_apply()
		_select(id)
		return
	_tier = found
	_sel = id
	_show_tier()
	if _sel != id and _row_of(id).size() > 0:
		_select(id)


## Comparaison courte avec la pièce portée au même emplacement : le verdict et les trois plus gros écarts.
func _compare_text(it: Dictionary) -> String:
	var worn: Dictionary = Profile.equipped.get(String(it.get("slot", "")), {})
	if worn.is_empty():
		return "\n\n[color=#c8c8d4]Emplacement libre.[/color]"
	var out := "\n\n" + FabricationPage.verdict_text(it)  # le mot et l'écart de PE, sans pourcentage (lot GX-2)
	var a := Items.stats(worn)
	var b := Items.stats(it)
	var deltas: Array = []
	for k in b:
		var d := float(b[k]) - float(a.get(k, 0.0))
		if is_zero_approx(d):
			continue
		deltas.append([k, d, absf(d) / maxf(maxf(absf(float(a.get(k, 0.0))), absf(float(b[k]))), 0.0001)])
	for k in a:
		if not b.has(k):
			deltas.append([k, -float(a[k]), 1.0])
	deltas.sort_custom(func(x, y): return x[2] > y[2])
	var parts: PackedStringArray = []
	for d in deltas.slice(0, 3):
		var pct: bool = d[0] in Items.PERCENT_STATS
		var shown := roundi(float(d[1]) * (100.0 if pct else 1.0))
		if shown == 0:
			continue
		parts.append("[color=%s]%s%d%s %s[/color]" % ["#7fe08a" if d[1] > 0 else "#ff7a7a", "+" if d[1] > 0 else "", shown,
			" %" if pct else "", Items.STAT_NAMES.get(d[0], Items.EXTRA_STAT_NAMES.get(d[0], d[0]))])
	if not parts.is_empty():
		out += "\n" + "   ".join(parts)
	return out


## Fabrique la pièce choisie ; [param wear] : « Fabriquer et porter » (ou « Porter » une pièce déjà fabriquée).
func _on_buy(wear := false) -> void:
	var row := _row_of(_sel)
	if row.is_empty():
		return
	if row.state == "owned" and wear:
		for it in Profile.inventory:
			if int(it.get("eden", -1)) == int(row.id):
				var ok := HeroLevel.lock_text(it) == "" and Profile.equip(it)
				refresh()
				_say(("Portée : %s" % Items.display_name(it)) if ok else HeroLevel.lock_text(it), UiTheme.BUFF if ok else UiTheme.DEBUFF)
				return
		return
	if row.state != "buy":
		return
	var e: Dictionary = row.e
	var p := price(e)
	if owned(int(e.id)) or Profile.insignia < p:
		return
	Profile.insignia -= p
	var it := make(e)
	Profile.add_item(it)
	var msg := ForgeWidgets.wear_new(it) if wear else ""
	Profile.save_profile()
	Sfx.ui("confirm")
	_just_bought = true
	refresh()
	if msg != "":
		_say(msg, UiTheme.BUFF if msg.begins_with("Fabriqué et porté") else UiTheme.MUTED)


## Case d'un plan pas encore découvert : un « ? », son emplacement et son niveau (rien de plus : pas de spoiler).
class Silhouette extends Button:
	var selected := false
	var slot_name := ""
	var level := 0
	var goal := false  # lot GX-3 : plan d'un objectif (★)

	func _init(px := 70.0) -> void:
		custom_minimum_size = Vector2(px, px)
		focus_mode = Control.FOCUS_NONE
		flat = true

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		var bg := StyleBoxFlat.new()
		bg.bg_color = Color(0.21, 0.19, 0.31, 0.95) if not is_hovered() else Color(0.27, 0.24, 0.39, 1.0)
		bg.border_color = UiTheme.GOLD if selected else Color(0.3, 0.28, 0.4, 0.9)
		bg.set_border_width_all(3 if selected else 2)
		bg.set_corner_radius_all(8)
		draw_style_box(bg, r)
		var font := UiTheme.bold_font()
		HudWidgets.text_center(self, "?", r.get_center() + Vector2(0, -size.y * 0.06), font, maxi(16, roundi(size.x * 0.4)), Color(1, 1, 1, 0.4), 3)
		if slot_name != "" and size.x < 100.0:
			HudWidgets.text_center(self, slot_name, Vector2(size.x * 0.5, size.y - 9.0), font, 11, Color(1, 1, 1, 0.55), 3)
		if level > 0 and size.x < 100.0:
			HudWidgets.text_center(self, str(level), Vector2(size.x - 11.0, 11.0), font, 11, Color(1, 1, 1, 0.55), 3)
		if goal:
			ForgeWidgets.star(self, Vector2(12, 12), 9.0, ForgeWidgets.ENCRE)
			ForgeWidgets.star(self, Vector2(12, 12), 7.0, ForgeWidgets.SOLEIL)


# --- Fabriquer v2 (lot GX-2) : paliers, poupée du palier, palier entier -----------------------------------------------
## Les neuf emplacements du kit d'un palier (ceux de la PE), dans l'ordre de la poupée (3 × 3).
const KIT_SLOTS := ["weapon", "head", "chest", "legs", "gloves", "boots", "back", "necklace", "ring"]
## Pièces de chaque palier : « époque|carte|emplacement|type d'arme » -> modèles d'Eden (tirages des coffres, gardés).
static var _pool_cache := {}


## Modèles d'Eden que les coffres d'emplacement de la carte [param stage] de l'époque [param ep] proposent pour
## [param slot] (arme : du type [param wtype]).
static func tier_pool(ep: int, stage: int, slot: String, wtype: String) -> Array:
	var key := "%d|%d|%s|%s" % [ep, stage, slot, wtype if slot == "weapon" else ""]
	if not _pool_cache.has(key):
		var box := "jewel" if slot in ["ring", "necklace"] else slot
		_pool_cache[key] = SlotChests.pool(box, ep, stage, wtype if slot == "weapon" else "").filter(func(e): return String(e.get("slot", "")) == slot)
	return _pool_cache[key]


## Kit du palier (époque [param ep], carte [param stage]) pour la classe [param cid] : neuf entrées {slot, state, e} ;
## state : « owned » (une pièce du palier fabriquée), « buy » (plan connu : la meilleure pour la classe), « locked » (plan à
## trouver). [param owned] / [param seen] : ids possédés / découverts (calculés au besoin).
static func kit(ep: int, stage: int, cid: String, owned = null, seen = null) -> Array:
	var have: Dictionary = owned if owned is Dictionary else owned_ids()
	var known: Dictionary = seen if seen is Dictionary else _seen_ids()
	var prof := ClassGear.profile(cid)
	var wtype := Items.default_weapon_type(cid)
	var out: Array = []
	for slot in KIT_SLOTS:
		var cands := tier_pool(ep, stage, slot, wtype)
		var entry := {"slot": slot, "state": "locked", "e": cands[0] if not cands.is_empty() else {}}
		for e in cands:  # lot GX-3 : un plan à trouver qui est un objectif se montre (★) plutôt qu'un autre du palier
			if Goals.has(Goals.piece_id(int(e.id))):
				entry.e = e
				break
		# la meilleure pièce connue du palier pour la classe : fabriquée, ou plan à fabriquer s'il est meilleur
		var best := -1.0
		for e in cands:
			var got := have.has(int(e.id))
			if not got and not known.has(int(e.id)):
				continue
			var r := Items.rating(make(e), prof) * (1.0001 if got else 1.0)  # à note égale, la pièce déjà fabriquée
			if r > best:
				best = r
				entry = {"slot": slot, "state": "owned" if got else "buy", "e": e}
		out.append(entry)
	return out


## Pièces du palier fabriquées (emplacements du kit qui ont au moins une pièce du palier), sans calcul de note.
static func kit_done(ep: int, stage: int, cid: String, owned: Dictionary) -> int:
	var wtype := Items.default_weapon_type(cid)
	var n := 0
	for slot in KIT_SLOTS:
		if tier_pool(ep, stage, slot, wtype).any(func(e): return owned.has(int(e.id))):
			n += 1
	return n


static func _seen_ids() -> Dictionary:
	var out := {}
	for id in Profile.seen_gear:
		out[int(id)] = true
	return out


## Palier de « ta bande » : la plus haute carte dont la bande de niveau contient le niveau de héros.
static func band_tier(hl: int) -> Vector2i:
	var best := Vector2i(1, 1)
	for ep in range(1, Epochs.count() + 1):
		for st in range(1, 4):
			var b := Epochs.band(ep, st)
			if hl >= b.x:
				best = Vector2i(ep, st)
	return best


## Palier montré à l'ouverture : « ta bande » s'il y a un plan connu à y fabriquer, sinon le plus haut palier qui en a
## un (fabriquer, c'est l'action de la page), sinon « ta bande ».
static func default_tier() -> Vector2i:
	var band := band_tier(HeroLevel.level())
	var have := owned_ids()
	var known := _seen_ids()
	var wtype := Items.default_weapon_type(Profile.selected_class)
	var best := Vector2i.ZERO
	for ep in range(1, Epochs.count() + 1):
		for st in range(1, 4):
			for slot in KIT_SLOTS:
				var pool := tier_pool(ep, st, slot, wtype)
				if pool.any(func(e): return known.has(int(e.id))) and not pool.any(func(e): return have.has(int(e.id))):
					if Vector2i(ep, st) == band:
						return band
					best = Vector2i(ep, st)
					break
	return best if best != Vector2i.ZERO else band


## « II-2 » : le palier en court.
static func tier_code(ep: int, stage: int) -> String:
	return "%s-%d" % [String(Epochs.get_def(ep).name).trim_prefix("Époque "), stage]


static func tier_zone(ep: int, stage: int) -> String:
	var zid := Epochs.zone(ep, stage)
	return String(GameData.zone(zid).get("name", zid))


## Paliers au prix des plans connus et pas encore fabriqués du kit : [ids], total en insignes.
static func kit_to_craft(entries: Array) -> Dictionary:
	var ids: Array = []
	var total := 0
	var tiers := Economy.owned_tiers()
	for k in entries:
		if String(k.state) == "buy":
			ids.append(int(k.e.id))
			total += Economy.armory_price(k.e, tiers)
	return {"ids": ids, "total": total}


## Fabrique les pièces [param ids] (plans connus) tant que les insignes suffisent ; renvoie les pièces fabriquées.
static func craft_ids(ids: Array) -> Array:
	var made: Array = []
	for id in ids:
		var e: Dictionary = GameData.eden_by_id.get(int(id), {})
		if e.is_empty() or owned(int(id)) or not (int(id) in Profile.seen_gear):
			continue
		var p := price(e)
		if Profile.insignia < p or Profile.inventory.size() >= Profile.INVENTORY_MAX:
			break
		Profile.insignia -= p
		var it := make(e)
		Profile.add_item(it)
		made.append(it)
	if not made.is_empty():
		Profile.save_profile()
	return made


## Colonne des paliers : les douze cartes, jauge des pièces fabriquées du kit (x / 9), « ta bande » en lagon.
func _fill_tiers() -> void:
	for c in _tier_list.get_children():
		_tier_list.remove_child(c)
		c.queue_free()
	var have := owned_ids()
	var cid := Profile.selected_class
	var band := band_tier(HeroLevel.level())
	for ep in range(1, Epochs.count() + 1):
		for st in range(1, 4):
			var t := Vector2i(ep, st)
			var done := kit_done(ep, st, cid, have)
			var closed := ep > Epochs.unlocked()
			var on := t == _tier
			var b := ForgeWidgets.candy_button("", "mandarine" if on else ("lagon" if t == band else "nuit"), 15, 52 if not _short_screen() else 44)
			b.alignment = HORIZONTAL_ALIGNMENT_LEFT
			b.text = "%s %s%s" % [tier_code(ep, st), tier_zone(ep, st), "  · ta bande" if t == band else ""]
			b.tooltip_text = "%s · %s · %s%s" % [Epochs.get_def(ep).name, tier_zone(ep, st), Epochs.band_text(ep, st),
				" · époque encore fermée" if closed else ""]
			if closed and not on:
				b.modulate = Color(1, 1, 1, 0.6)
			var g := ProgressBar.new()
			g.min_value = 0
			g.max_value = KIT_SLOTS.size()
			g.value = done
			g.show_percentage = false
			g.mouse_filter = Control.MOUSE_FILTER_IGNORE
			g.anchor_left = 0.0
			g.anchor_right = 1.0
			g.anchor_top = 1.0
			g.anchor_bottom = 1.0
			g.offset_left = 12
			g.offset_right = -64
			g.offset_top = -14
			g.offset_bottom = -7
			g.add_theme_stylebox_override("background", ForgeWidgets.box(ForgeWidgets.ENCRE, ForgeWidgets.ENCRE, 4, 1, 0))
			g.add_theme_stylebox_override("fill", ForgeWidgets.box(ForgeWidgets.POMME, ForgeWidgets.ENCRE, 4, 1, 0))
			b.add_child(g)
			var n := Label.new()
			n.text = "%d / %d%s" % [done, KIT_SLOTS.size(), " ✓" if done >= KIT_SLOTS.size() else ""]
			n.mouse_filter = Control.MOUSE_FILTER_IGNORE
			n.add_theme_font_size_override("font_size", 13)
			n.add_theme_color_override("font_color", ForgeWidgets.POMME_CLAIR if done >= KIT_SLOTS.size() else ForgeWidgets.TEXTE_2)
			n.add_theme_color_override("font_outline_color", ForgeWidgets.ENCRE)
			n.add_theme_constant_override("outline_size", 3)
			n.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			n.anchor_left = 1.0
			n.anchor_right = 1.0
			n.anchor_top = 1.0
			n.anchor_bottom = 1.0
			n.offset_left = -60
			n.offset_right = -8
			n.offset_top = -22
			n.offset_bottom = -2
			b.add_child(n)
			b.pressed.connect(func():
				_tier = t
				_sel = -1
				_show_tier())
			_tier_list.add_child(b)
			_tier_buttons[t] = b


## La poupée du palier choisi : neuf grandes cases (pleine = fabriquée, voilée = plan connu avec son prix, « ? » = plan
## à trouver avec le lieu), puis « Fabriquer les N plans connus ».
func _show_tier() -> void:
	if _kit_grid == null:
		return
	if _tier == Vector2i.ZERO:
		_tier = band_tier(HeroLevel.level())
	_cells.clear()
	_fill_tiers()
	for c in _kit_grid.get_children():
		_kit_grid.remove_child(c)
		c.queue_free()
	var cid := Profile.selected_class
	_kit = kit(_tier.x, _tier.y, cid)
	var done := kit_done(_tier.x, _tier.y, cid, owned_ids())  # emplacements qui ont une pièce du palier (comme la jauge)
	_kit_title.text = "%s · %s" % [tier_zone(_tier.x, _tier.y), Epochs.band_text(_tier.x, _tier.y).to_lower()]
	_kit_sub.text = "Kit %s · %s · %d fabriquées sur %d" % [_class_de(cid), String(GameData.weapon_type(Items.default_weapon_type(cid)).get("name", "")),
		done, KIT_SLOTS.size()]
	var cell_px := 84.0 if _short_screen() else 104.0
	var first_buy := -1
	var first_any := -1
	for k in _kit:
		var e: Dictionary = k.e
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 2)
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_kit_grid.add_child(v)
		var slot_name := String(Items.SLOT_NAMES.get(k.slot, k.slot))
		var cell: Control
		var cap := ""
		if e.is_empty() or k.state == "locked":
			var sil := Silhouette.new(cell_px)
			sil.slot_name = ""
			sil.level = int(e.get("level", 0)) if not e.is_empty() else 0
			sil.goal = not e.is_empty() and Goals.has(Goals.piece_id(int(e.id)))
			sil.tooltip_text = "Plan à trouver : %s" % (Completion.plan_place(int(e.id)) if not e.is_empty() else "aucun coffre")
			cell = sil
			var where := Completion.plan_place(int(e.id)) if not e.is_empty() else ""
			cap = "%s · %s" % [slot_name, where.get_slice(" · ", 1) if where != "" else "à trouver"]
		else:
			var s := ItemWidgets.ItemSlot.new(cell_px)
			s.set_item(make(e))
			s.wear_check = true
			s.show_compare = false  # verdict au profil de la classe dans la fiche (le ▲ générique pouvait le contredire)
			s.dim = k.state == "buy"
			s.badge = "✓" if k.state == "owned" else ""
			cell = s
			cap = ("%s ✓" % slot_name) if k.state == "owned" else "%s · %s" % [slot_name, GearPower.fmt(price(e))]
			if k.state == "buy" and first_buy < 0:
				first_buy = int(e.id)
		if not e.is_empty():
			if first_any < 0:
				first_any = int(e.id)
			cell.set("selected", int(e.id) == _sel)
			cell.pressed.connect(_select.bind(int(e.id)))
			if not _row_of(int(e.id)).is_empty():
				_cells[int(e.id)] = cell
		cell.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		v.add_child(cell)
		var l := Hud._label(v, cap, 14, ForgeWidgets.POMME_CLAIR if k.state == "owned" else (ForgeWidgets.TEXTE if k.state == "buy" else ForgeWidgets.TEXTE_2))
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.clip_text = true
		l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		l.custom_minimum_size = Vector2(cell_px + 56.0, 0)
	if not _kit.any(func(k): return not k.e.is_empty() and int(k.e.id) == _sel):
		_sel = first_buy if first_buy >= 0 else first_any
		for id in _cells:
			_cells[id].set("selected", int(id) == _sel)
	var todo := kit_to_craft(_kit)
	var n: int = (todo.ids as Array).size()
	_kit_all.visible = n > 0
	_kit_all.text = "Fabriquer %s · %s insignes" % ["le plan connu" if n == 1 else "les %d plans connus" % n, GearPower.fmt(int(todo.total))]
	_kit_all.disabled = Profile.insignia < int(todo.total)
	_kit_miss.text = Economy.missing_text(int(todo.total)) if n > 0 else ("Kit complet." if done >= KIT_SLOTS.size() else "Aucun plan connu à fabriquer : les coffres de ces cartes en révèlent.")
	_kit_miss.add_theme_color_override("font_color", ItemWidgets.LOCK_TEXT if _kit_all.disabled and n > 0 else ForgeWidgets.TEXTE_2)
	_right.visible = _sel >= 0
	_show_detail()


static func _class_de(cid: String) -> String:
	var n := String(GameData.class_data(cid).get("name_fr", cid))
	return ("de l'" if n.substr(0, 1).to_lower() in ["a", "e", "é", "è", "i", "o", "u", "h"] else "du ") + n


## « Fabriquer les N plans connus » : confirmation du coût, puis fabrication.
func _on_kit_all() -> void:
	var todo := kit_to_craft(_kit)
	var ids: Array = todo.ids
	if ids.is_empty() or Profile.insignia < int(todo.total):
		return
	var go := func():
		var made := craft_ids(ids)
		Sfx.ui("confirm")
		_just_bought = true
		refresh()
		_say("%s · %s" % [GearPower.plural(made.size(), "pièce fabriquée", "pièces fabriquées"), GearPower.plural(int(todo.total), "insigne")], UiTheme.BUFF)
	if skip_confirm:
		go.call()
		return
	InfoCard.ask(self, "Fabriquer %s ?" % GearPower.plural(ids.size(), "pièce"), "Coût : %s insignes. Il t'en restera %s." % [
		GearPower.fmt(int(todo.total)), GearPower.fmt(Profile.insignia - int(todo.total))], "Fabriquer", go, false)


func _say(text: String, col: Color) -> void:
	_short.text = text
	_short.add_theme_color_override("font_color", col)


func _narrow() -> bool:
	return get_viewport().get_visible_rect().size.x < 1500.0


func _short_screen() -> bool:
	return get_viewport().get_visible_rect().size.y < 840.0


## Deux vues : « tiers » (paliers et poupée, défaut) et « catalog » (la grille filtrable de tous les plans).
func set_view(v: String) -> void:
	view = v
	if _bar == null:
		return
	var tiers := view == "tiers"
	_tier_col.visible = tiers  # le catalogue reprend toute la largeur (sa grille tient alors en 1280 × 720)
	_kit_box.visible = tiers
	_bar.visible = not tiers
	_holder.visible = not tiers
	_view_btn.text = "Catalogue complet" if tiers else "Retour aux paliers"
	_head.text = "Fabriquer" if not tiers else "Kit du palier"
	if tiers:
		_show_tier()
	else:
		_apply()
