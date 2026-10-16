class_name GearShopPage
extends HBoxContainer
## Atelier > Fabriquer (hub, ex-Armurerie ; lot A3 de la refonte) : le catalogue des pièces que les coffres d'emplacement
## de la Survie peuvent proposer (Completion.armory_ids). Une pièce choisie une fois dans un coffre est « découverte »
## (Profile.seen_gear) : c'est son plan. Elle se fabrique avec les insignes gagnés en Survie (mêmes prix qu'avant) ;
## fabriquée, elle rejoint le coffre commun (+0) : collection, JcJ non normalisé et toute l'optimisation du hub (forge,
## gemmes, enchantements). Les plans pas encore trouvés se voient en silhouette (« Plans à découvrir »), avec l'époque
## et la carte où les trouver. Filtres : statut, emplacement, époque, classe. Les noms internes (`_buy`, `_on_buy`,
## états « buy » / « owned » / « locked ») restent ceux d'avant : seuls les textes lus par le joueur changent.

const COLS := 12
const ROWS := 7
const CELL := 70.0
## Statuts affichables : [id, libellé].
const STATUSES := [["buy", "À fabriquer"], ["owned", "Fabriquées"], ["locked", "Plans à découvrir"], ["all", "Tous"]]

var _f_status: OptionButton
var _f_slot: OptionButton
var _f_epoch: OptionButton
var _f_class: OptionButton
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
	var left := ItemWidgets.panel(self, 0, true)
	var hh := HBoxContainer.new()
	left.add_child(hh)
	var head := Hud._label(hh, "Fabriquer", 20, UiTheme.GOLD)
	head.add_theme_font_override("font", UiTheme.title_font())
	head.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_count = Hud._label(hh, "", 18, UiTheme.TEXT)
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 6)
	left.add_child(bar)
	_f_status = _option(bar, STATUSES.map(func(s): return String(s[1])))
	_f_slot = _option(bar, ["Emplacement"])
	_f_epoch = _option(bar, ["Époque"])
	_f_class = _option(bar, ["Classe"])
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(sp)
	_prev = _pager_button(bar, "‹", -1)
	_page_label = Hud._label(bar, "", 15, UiTheme.MUTED)
	_page_label.custom_minimum_size = Vector2(70, 0)
	_page_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_next = _pager_button(bar, "›", 1)
	var holder := Control.new()
	holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_child(holder)
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
	var right := ItemWidgets.panel(self, 420)
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
	_buy = MenuWidgets.gold_button("Fabriquer", 20, Vector2(0, 52))
	_buy.pressed.connect(_on_buy)
	right.add_child(_buy)


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
	_rows = _all.filter(func(r):
		if status != "all" and r.state != status:
			return false
		if slot != "" and r.slot != slot:
			return false
		if epoch > 0 and int(r.epoch) != epoch:
			return false
		if wtype != "" and r.slot == "weapon" and String(r.e.get("wtype", "")) != wtype:
			return false
		return true)
	var kk := "k1" if status == "all" else "k0"
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
			sil.tooltip_text = "Plan pas encore découvert"
			cell = sil
		else:
			var it := make(row.e)
			var s := ItemWidgets.ItemSlot.new(CELL)
			s.set_item(it)
			s.show_compare = row.state == "buy"
			s.badge = "✓" if row.state == "owned" else "%d" % price(row.e)
			s.dim = row.state == "owned"
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
	r.text = Items.describe(it) + _compare_text(it)
	var place := Completion.plan_place(int(row.id))
	if place != "":
		var pl := Hud._label(_detail_box, "Plan trouvé : %s" % place, 15, UiTheme.MUTED)
		pl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		pl.tooltip_text = "La première carte dont un coffre propose cette pièce."
	var p := price(row.e)
	if row.state == "owned":
		_buy.text = "Dans ton coffre"
		_buy.disabled = true
		if not Profile.equipped.values().any(func(w): return int(w.get("eden", -1)) == int(row.id)):
			_short.text = "À équiper : Héros > Équipement"  # la fabrication ne la pose pas : le dernier pas du parcours
			_short.add_theme_color_override("font_color", UiTheme.BUFF)
	else:
		_buy.text = "Fabriquer · %s insignes" % GearPower.fmt(p)
		_buy.disabled = Profile.insignia < p
		if Profile.insignia < p:
			_short.text = "Il te manque %s insignes" % GearPower.fmt(p - Profile.insignia)


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


## Comparaison courte avec la pièce portée au même emplacement : le verdict et les trois plus gros écarts.
func _compare_text(it: Dictionary) -> String:
	var worn: Dictionary = Profile.equipped.get(String(it.get("slot", "")), {})
	if worn.is_empty():
		return "\n\n[color=#c8c8d4]Emplacement libre.[/color]"
	var c := Items.compare_to_equipped(it)
	var dpe := GearPower.delta_if_equipped(it)
	var out := "\n\n[b][color=%s]%s %+d %%[/color][/b]   [color=%s]PE %s%s[/color]" % ["#7fe08a" if c >= 0 else "#ff7a7a",
		"▲ Meilleur" if c >= 0.02 else ("▼ Moins bien" if c <= -0.02 else "≈ Équivalent"), roundi(c * 100.0),
		"#7fe08a" if dpe >= 0 else "#ff7a7a", "+" if dpe >= 0 else "", GearPower.fmt(dpe)]
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


func _on_buy() -> void:
	var row := _row_of(_sel)
	if row.is_empty() or row.state != "buy":
		return
	var e: Dictionary = row.e
	var p := price(e)
	if owned(int(e.id)) or Profile.insignia < p:
		return
	Profile.insignia -= p
	Profile.add_item(make(e))
	Profile.save_profile()
	Sfx.ui("confirm")
	_just_bought = true
	refresh()


## Case d'un plan pas encore découvert : un « ? », son emplacement et son niveau (rien de plus : pas de spoiler).
class Silhouette extends Button:
	var selected := false
	var slot_name := ""
	var level := 0

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
