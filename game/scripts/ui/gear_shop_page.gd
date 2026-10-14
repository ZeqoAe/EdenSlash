class_name GearShopPage
extends HBoxContainer
## Collection > Armurerie (hub) : les pièces d'Eden choisies au moins une fois dans un coffre
## d'emplacement de la Survie (Profile.seen_gear), achetables avec les insignes gagnés en
## Survie. Achetée, une pièce rejoint le coffre commun (+0) : collection, JcJ non normalisé,
## et toute l'optimisation du hub (forge, gemmes, enchantements).

var _grid: ItemWidgets.ItemGrid
var _detail_box: CenterContainer
var _buy: Button
var _wallet: Label
var _head: Label


## Prix en insignes : selon la rareté et le niveau d'Eden de la pièce.
static func price(e: Dictionary) -> int:
	if String(e.get("name", "")).begins_with("Awaken "):
		return 250
	var lv := int(e.get("level", 1))
	return 80 + 2 * lv if int(e.get("rarity", 0)) >= Items.LEGENDARY else 30 + lv


## Pièce d'Eden [param id] déjà achetée (dans le coffre commun ou portée) ?
static func owned(id: int) -> bool:
	for it in Profile.all_items():
		if int(it.get("eden", -1)) == id:
			return true
	return false


## Aperçu (ou pièce achetée) de la pièce d'Eden [param e] : +0, à son niveau.
static func make(e: Dictionary) -> Dictionary:
	var it := Items.from_template(e, int(e.level), int(e.rarity))
	it["upgrade"] = 0
	it["quality"] = 1.0
	if String(e.name).begins_with("Awaken "):
		it["awakened"] = true
	return it


func _ready() -> void:
	add_theme_constant_override("separation", 14)
	var left := ItemWidgets.panel(self, 0, true)
	var hh := HBoxContainer.new()
	left.add_child(hh)
	_head = Hud._label(hh, "Armurerie", 20, UiTheme.GOLD)
	_head.add_theme_font_override("font", UiTheme.title_font())
	_head.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_wallet = Hud._label(hh, "", 17, Color(0.75, 0.85, 1.0))
	Hud._label(left, "Les pièces que tu as choisies dans les coffres de la Survie, à acheter avec tes insignes : elles rejoignent ton coffre commun (collection, JcJ, forge).", 13, UiTheme.MUTED).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_grid = ItemWidgets.ItemGrid.new(false, 9, 72.0)
	_grid.set_empty_text("Aucune pièce découverte : en Survie, choisis des pièces dans les coffres d'emplacement.")
	_grid.badge_fn = func(it): return "✓" if owned(int(it.get("eden", -1))) else "%d" % price(GameData.eden_by_id.get(int(it.eden), {}))
	_grid.dim_fn = func(it): return owned(int(it.get("eden", -1)))
	_grid.selection_changed.connect(_show)
	left.add_child(_grid)
	var right := ItemWidgets.panel(self, 420)
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right.add_child(sc)
	_detail_box = CenterContainer.new()
	_detail_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(_detail_box)
	_buy = MenuWidgets.gold_button("Acheter", 20, Vector2(0, 52))
	_buy.pressed.connect(_on_buy)
	right.add_child(_buy)


func refresh() -> void:
	if not is_inside_tree():
		return
	var items: Array = []
	for id in Profile.seen_gear:
		var e: Dictionary = GameData.eden_by_id.get(int(id), {})
		if not e.is_empty():
			items.append(make(e))
	_grid.set_items(items)
	_wallet.text = "%d insignes" % Profile.insignia
	if _grid.selection().is_empty() and not _grid.shown().is_empty():
		_grid.select_item(_grid.shown()[0])
	_show()


func _show() -> void:
	for c in _detail_box.get_children():
		c.queue_free()
	var it := _grid.first_selected()
	_buy.visible = not it.is_empty()
	if it.is_empty():
		return
	_detail_box.add_child(ItemWidgets.item_card(it))
	var id := int(it.get("eden", -1))
	var p := price(GameData.eden_by_id.get(id, {}))
	if owned(id):
		_buy.text = "Déjà dans ton coffre"
		_buy.disabled = true
	else:
		_buy.text = "Acheter · %d insignes" % p
		_buy.disabled = Profile.insignia < p


func _on_buy() -> void:
	var it := _grid.first_selected()
	if it.is_empty():
		return
	var e: Dictionary = GameData.eden_by_id.get(int(it.get("eden", -1)), {})
	var p := price(e)
	if e.is_empty() or owned(int(e.id)) or Profile.insignia < p:
		return
	Profile.insignia -= p
	Profile.add_item(make(e))
	Profile.save_profile()
	Sfx.ui("confirm")
	refresh()
