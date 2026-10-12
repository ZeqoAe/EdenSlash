class_name VillageUI
extends CanvasLayer
## Village : chaque PNJ a son métier et son écran plein écran (VillagePages) :
## - Alec, marchand : acheter (offres de la run), vendre ;
## - Bryson, forgeron : améliorer, enchanter, réforger / polir ;
## - Starnoc, recycleur : désassembler, convertir les matériaux ;
## - Lertia, joaillière : sertissage, fusion de gemmes.

const NPCS := {
	"merchant": {"name": "Alec, marchand", "sub": "Boutique de la run et rachat de tes objets"},
	"smith": {"name": "Bryson, forgeron", "sub": "Amélioration, enchantement et réforge de l'équipement"},
	"recycler": {"name": "Starnoc, recycleur", "sub": "Désassemblage en matériaux et conversion"},
	"jeweler": {"name": "Lertia, joaillière", "sub": "Emplacements de gemmes, sertissage et fusion"},
}
## Anciens PNJ / onglets vers les nouveaux métiers.
const ALIASES := {"trader": ["merchant", 0]}

var player: Player
var director: RunDirector
var offers: Array = []  # offres de la boutique pour la run
var _screens := {}  # métier -> PageScreen
var _kind := ""
## Compatibilité avec les tests de world.gd (--open=merchant|smith|jeweler)
var _shown: Array:
	get:
		var p := _current_item_page()
		return p.grid.shown() if p else []


func setup(p: Player, d: RunDirector) -> void:
	player = p
	director = d
	layer = 16
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build("merchant", [["Acheter", VillagePages.ShopPage.new()], ["Vendre", VillagePages.SellPage.new(false)]])
	_build("smith", [["Améliorer", VillagePages.UpgradePage.new()], ["Enchanter", VillagePages.EnchantPage.new()], ["Réforger", VillagePages.ReforgePage.new()], ["Fabriquer", VillagePages.CraftPage.new()]])
	_build("recycler", [["Recycler", VillagePages.SellPage.new(true)], ["Convertir", VillagePages.ConvertPage.new()]])
	_build("jeweler", [["Sertissage", VillagePages.SocketPage.new()], ["Fusion de gemmes", VillagePages.FusePage.new()]])


func _build(kind: String, pages: Array) -> void:
	var s := PageScreen.new(String(NPCS[kind].name), 16)
	s.pause_game = true
	add_child(s)
	for spec in pages:
		var page: Control = spec[1]
		page.set("ui", self)
		s.add_page(spec[0], page)
	s.closed.connect(func():
		if player:
			player.recalc_stats())
	_screens[kind] = s


func is_open() -> bool:
	for k in _screens:
		if _screens[k].is_open():
			return true
	return false


func open(kind: String, _npc_name := "") -> void:
	var tab := 0
	if ALIASES.has(kind):
		tab = int(ALIASES[kind][1])
		kind = String(ALIASES[kind][0])
	if not _screens.has(kind):
		kind = "merchant"
	if offers.is_empty():
		_roll_offers()
	_kind = kind
	var s: PageScreen = _screens[kind]
	s.set_title(String(NPCS[kind].name), String(NPCS[kind].sub))
	s.show_wallet(true)
	s.open(tab)


func close_ui() -> void:
	for k in _screens:
		_screens[k].close_ui()


func message(text: String, duration := 2.0) -> void:
	if director:
		director.message.emit(text, duration)
	for k in _screens:
		if _screens[k].is_open():
			_screens[k].refresh()


func _current_item_page() -> VillagePages.ItemPage:
	if not _screens.has(_kind):
		return null
	var s: PageScreen = _screens[_kind]
	var p := s.page(s.current_page())
	return p as VillagePages.ItemPage


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
	else:
		Profile.gold -= int(o.price)
		Profile.save_profile()
		Run.apply_card(o.card)
	o["sold"] = true
	message("Acheté !", 1.2)


## Offres de la run : compétences, améliorations et cartes, fournitures de joaillier,
## équipement rare ou épique du niveau de la zone.
func _roll_offers() -> void:
	offers.clear()
	var lvl := player.level
	for c in Run.roll_cards(4):
		var base: int = {"skill": 60, "upgrade": 50, "passive": 70}.get(c.type, 60)
		offers.append({"card": c, "price": int(base + 14 * lvl)})
	var lv := director.loot_level(lvl)
	for key in ["drill", ["luck", "protect"].pick_random()]:
		offers.append(_supply_offer(key, 2 if key == "luck" else 1, 40 + 6 * lvl))
	while offers.size() < 8:
		var item := Items.generate(director.loot_level(lvl + 1), 0.4, "", Run.class_id, 2)
		offers.append({"item": item, "price": Items.buy_price(item)})
	offers.append(_supply_offer(Craft.random_loot(lv, 1), 1, 60 + 8 * lvl))


func _supply_offer(key: String, count: int, price: int) -> Dictionary:
	return {"bag": key, "count": count, "price": price, "card": {"type": "supply", "title": "%s ×%d" % [Craft.label(key), count],
		"subtitle": "Fourniture de joaillier", "desc": Craft.describe_key(key), "icon": Craft.icon(key)}}
