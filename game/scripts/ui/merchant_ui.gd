class_name MerchantUI
extends CanvasLayer
## Marchands ambulants (ils remplacent le village) : un écran par marchand, ses offres
## tirées pour lui (cartes d'amélioration de la run, clés, équipement, fournitures),
## rachat des objets contre de l'or (les mythiques et légendaires : coffres de récompense seulement).
## La Forge (améliorer, réforger, polir, sertir, enchanter, fusionner) s'ouvre depuis la
## fiche d'un objet pendant la run (open_forge), partout sur la carte.

const TITLE := "Marchand ambulant"

var player: Player
var director: RunDirector
var offers: Array = []  # offres du marchand ouvert
var _screen: PageScreen
var _forge: PageScreen
var _npc: Node
## Compatibilité avec les tests (--open=merchant) : objets affichés de la page ouverte.
var _shown: Array:
	get:
		var p := _current_item_page()
		return p.grid.shown() if p else []


func setup(p: Player, d: RunDirector) -> void:
	player = p
	director = d
	layer = 16
	process_mode = Node.PROCESS_MODE_ALWAYS
	_screen = PageScreen.new(TITLE, 16)
	_screen.pause_game = true
	add_child(_screen)
	for spec in [["Boutique", MerchantPages.ShopPage.new()], ["Vendre", MerchantPages.SellPage.new(false)]]:
		spec[1].set("ui", self)
		_screen.add_page(spec[0], spec[1])
	_screen.closed.connect(_recalc)
	_forge = PageScreen.new("Forge", 17)
	_forge.pause_game = true
	add_child(_forge)
	var fp := MerchantPages.ForgePage.new()
	fp.ui = self
	_forge.add_page("Forge", fp)
	_forge.closed.connect(_recalc)


func _recalc() -> void:
	if player:
		player.recalc_stats()


func is_open() -> bool:
	return _screen.is_open() or _forge.is_open()


## Ouvre le marchand [param npc] (ses offres sont tirées à la première visite).
func open(npc: Node = null, tab := 0) -> void:
	_npc = npc
	if npc and npc.has_meta("offers"):
		offers = npc.get_meta("offers")
	else:
		offers = roll_offers()
		if npc:
			npc.set_meta("offers", offers)
	_screen.set_title(TITLE, "Achète des cartes et des clés, revends ton butin : l'or est perdu en fin de run")
	_screen.show_wallet(true)
	_screen.open(tab)


## Forge sur l'objet [param item] (déjà choisi dans la grille).
func open_forge(item: Dictionary = {}) -> void:
	_forge.set_title("Forge", "Or : amélioration · cristaux : réforge et polissage · fournitures : gemmes et enchantements" if Profile.in_run
		else "Hors run : fournitures de ta réserve · cristaux pour tout (1 cristal pour %d or)" % Forge.GOLD_PER_CRYSTAL)
	_forge.show_wallet(true)
	_forge.open(0)
	var fp: MerchantPages.ForgePage = _forge.page(0)
	if not item.is_empty():
		fp.grid.select_item(item)


func close_ui() -> void:
	_screen.close_ui()
	_forge.close_ui()


func message(text: String, duration := 2.0) -> void:
	if director:
		director.message.emit(text, duration)
	else:
		_toast(text, duration)  # hors run (forge depuis l'équipement) : message à l'écran
	for s in [_screen, _forge]:
		if s.is_open():
			s.refresh()


var _toast_label: Label


func _toast(text: String, duration: float) -> void:
	if _toast_label == null:
		var layer := CanvasLayer.new()
		layer.layer = 40
		add_child(layer)
		var holder := Control.new()
		holder.set_anchors_preset(Control.PRESET_FULL_RECT)
		holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		layer.add_child(holder)
		_toast_label = Hud._label(holder, "", 22, Color.WHITE)
		_toast_label.add_theme_constant_override("outline_size", 8)
		_toast_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
		_toast_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
		_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_toast_label.position = Vector2(-500, -150)
		_toast_label.size = Vector2(1000, 80)
	_toast_label.text = text
	_toast_label.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_interval(duration)
	tw.tween_property(_toast_label, "modulate:a", 0.0, 0.4)


func _current_item_page() -> MerchantPages.ItemPage:
	var s := _forge if _forge.is_open() else _screen
	return s.page(s.current_page()) as MerchantPages.ItemPage


## Compatibilité (tests) : sélectionne un objet de la page ouverte.
func _on_entry_pressed(it, _index := 0) -> void:
	var p := _current_item_page()
	if p and it is Dictionary:
		p.grid.select_item(it)


## Compatibilité (tests) : sélection rapide jusqu'à une rareté.
func _select_max_rarity(r: int) -> void:
	var p := _current_item_page()
	if p:
		p.grid.select_up_to_rarity(r)


func buy(o: Dictionary) -> void:
	if o.get("sold", false) or Profile.gold < int(o.price):
		return
	if o.has("item"):
		if not Profile.buy(o.item, int(o.price)):
			message("Inventaire plein", 1.5)
			return
	elif o.has("bag"):
		Profile.gold -= int(o.price)
		Profile.add_bag(String(o.bag), int(o.count))
		Profile.save_profile()
	elif o.has("keys"):
		Profile.gold -= int(o.price)
		Profile.keys += int(o.keys)
		Profile.changed.emit()
	else:
		Profile.gold -= int(o.price)
		Profile.save_profile()
		Run.apply_card(o.card)
	o["sold"] = true
	message("Acheté !", 1.2)


## Offres d'un marchand : 3 cartes d'amélioration, une clé, des fournitures, de
## l'équipement rare ou épique du niveau de la zone (dont parfois un trophée).
func roll_offers() -> Array:
	var out: Array = []
	var lvl := player.level if player else 1
	for c in Run.roll_cards(3):
		var base: int = {"skill": 60, "upgrade": 50, "passive": 70}.get(c.type, 60)
		out.append({"card": c, "price": int(base + 14 * lvl)})
	out.append({"keys": 1, "price": 45 + 8 * lvl, "card": {"type": "key", "title": "Clé ×1", "subtitle": "Ouvre un coffre de la carte sans payer",
		"desc": "Une clé ouvre n'importe quel coffre de la carte (son prix en or monte à chaque coffre ouvert). Perdue en fin de run.", "icon": Items.material_icon("keys")}})
	var lv := director.loot_level(lvl) if director else lvl
	var flv := Craft.fortify_level_at(lv)
	out.append(_supply_offer(Craft.fortify_key(["power", "guard"].pick_random(), flv), 2, 30 + 5 * lvl))
	for key in ["drill", Craft.stone_key(["safety", "lucky"].pick_random())]:
		out.append(_supply_offer(key, 2 if key.begins_with("stone") else 1, 40 + 6 * lvl))
	while out.size() < 8 and not Run.survival:  # Survie : l'équipement vient des coffres d'emplacement
		var item := Items.generate(director.loot_level(lvl + 1) if director else lvl, 0.4, "", Run.class_id, 2)
		out.append({"item": item, "price": Items.buy_price(item)})
	out.append(_supply_offer(Craft.random_loot(lv, 1), 1, 60 + 8 * lvl))
	return out


func _supply_offer(key: String, count: int, price: int) -> Dictionary:
	return {"bag": key, "count": count, "price": price, "card": {"type": "supply", "title": "%s ×%d" % [Craft.label(key), count],
		"subtitle": "Fourniture", "desc": Craft.describe_key(key), "icon": Craft.icon(key)}}
