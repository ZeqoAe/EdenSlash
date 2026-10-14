extends Node
## Mode farm (carte de la run) : objets cassables, coffres d'équipement par qualité, enclume,
## autel du scribe, fontaine, aimant, cupidité, défi :
## godot --headless --path game res://tests/test_farm.tscn

var fails := 0
var world: Node


func check(label: String, ok: bool) -> void:
	print(("OK    " if ok else "ÉCHEC ") + label)
	if not ok:
		fails += 1


func _ready() -> void:
	world = load("res://scenes/world.tscn").instantiate()
	get_tree().root.add_child.call_deferred(world)
	await get_tree().create_timer(6.0).timeout
	var d: RunDirector = world.director
	var player: Player = world.player
	d.set_process(false)
	for m in get_tree().get_nodes_in_group("monsters"):
		m.queue_free()
	_close_cards()
	var map: ProcMap = d.map
	var br: Breakables = map.breakables
	check("carte remplie : %d objets à casser (jarres %d, caisses %d, or %d, cristaux %d)" % [br.count(), br.count("pot"), br.count("crate"),
		br.count("gold"), br.count("gem")], br.count() > 600 and br.count("gem") >= 10 and br.count("gold") >= 30)
	var tiers := [0, 0, 0]
	for t in map.chest_tiers:
		tiers[int(t)] += 1
	check("30 coffres dont %d ouvragés et %d dorés" % [tiers[1], tiers[2]], map.chests.size() >= 25 and tiers[1] >= 8 and tiers[2] >= 3)
	var kinds := {}
	for st in map.stations:
		kinds[st.kind] = int(kinds.get(st.kind, 0)) + 1
	check("lieux : %s" % [kinds], kinds.size() == 6)
	check("%d lieux de décor, %d plateaux" % [map.sites.size(), map.plateaus.size()], map.sites.size() >= 18 and map.plateaus.size() >= 5)

	# jarre : un coup suffit, de l'or
	var pot := _nearest(br, "pot", player.global_position)
	var gold0 := Run.gold
	var n0 := br.count()
	br.hit_area(pot + Vector3(0.5, 0, 0), Vector3.LEFT, 2.0, 360.0)
	check("jarre cassée d'un coup : de l'or (+%d)" % (Run.gold - gold0), br.count() < n0 and Run.gold > gold0)
	# tas d'or : ramassé en passant
	var heap := _nearest(br, "gold", player.global_position)
	gold0 = Run.gold
	br.touch(heap)
	check("tas d'or ramassé en passant (+%d)" % (Run.gold - gold0), Run.gold - gold0 >= 10)
	# cristal : 3 coups, des gemmes
	var gem := _nearest(br, "gem", player.global_position)
	var loot0 := get_tree().get_nodes_in_group("loot").size()
	for i in 2:
		br.hit_area(gem + Vector3(0.5, 0, 0), Vector3.LEFT, 2.0, 360.0)
	var still := br.alive_list().any(func(x): return x[0] == gem)
	br.hit_area(gem + Vector3(0.5, 0, 0), Vector3.LEFT, 2.0, 360.0)
	await get_tree().process_frame
	check("cristal : intact après 2 coups, brisé au 3e, gemmes au sol", still and get_tree().get_nodes_in_group("loot").size() > loot0)

	# coffre ouvragé : équipement au choix, au moins rare
	var chest: Interactable = null
	for it in map.interactables:
		if it.kind == "chest" and int(it.get_meta("tier", 0)) == 1:
			chest = it
	Profile.keys = 0
	Profile.gold = 0
	var price := d.chest_price(1)
	d._interact(chest)
	check("coffre ouvragé trop cher sans or (prix %d, coffre simple %d)" % [price, d.chest_price(0)], not chest.used and price > d.chest_price(0))
	Profile.gold = price
	d._interact(chest)
	var cards: Array = world.cards._cards
	check("coffre ouvragé ouvert : 3 pièces d'équipement au choix, rare ou mieux", chest.used and cards.size() == 3
		and cards.all(func(c): return c.type == "gear" and int(c.item.rarity) >= 2))
	var inv0 := Profile.inventory.size()
	Run.apply_card(cards[0])
	check("la pièce choisie rejoint le sac", Profile.inventory.size() == inv0 + 1)
	_close_cards()

	# enclume : +1 garanti sur une pièce portée
	var w := Items.generate(5, 0.0, "weapon", Run.class_id, 1, "", 2)
	Profile.equipped["weapon"] = w
	var up0 := int(w.upgrade)
	_use("anvil")
	cards = world.cards._cards
	check("enclume : choix de pièces portées", not cards.is_empty() and cards.all(func(c): return c.type == "anvil"))
	var pick: Dictionary = cards.filter(func(c): return c.slot == "weapon")[0]
	Run.apply_card(pick)
	check("enclume : arme +%d → +%d" % [up0, int(Profile.equipped.weapon.upgrade)], int(Profile.equipped.weapon.upgrade) == up0 + 1)
	_close_cards()
	# autel du scribe
	_use("scribe")
	cards = world.cards._cards
	var key := String(cards[0].key) if not cards.is_empty() else ""
	var bag0 := int(Profile.bag.get(key, 0))
	if not cards.is_empty():
		Run.apply_card(cards[0])
	check("autel du scribe : un parchemin d'enchantement au choix (%s)" % key, key.begins_with("scroll:") and int(Profile.bag.get(key, 0)) == bag0 + 1)
	_close_cards()
	# fontaine, cupidité
	player.hp = player.max_hp * 0.3
	_use("well")
	check("fontaine de vie : PV au maximum", is_equal_approx(player.hp, player.max_hp))
	_use("greed")
	check("autel de cupidité : pacte actif", d.greed)
	# défi : 3 élites, puis un coffre de récompense au sol
	_use("challenge")
	var elites := get_tree().get_nodes_in_group("monsters").filter(func(m): return m.is_elite)
	check("défi : %d élites surgissent" % elites.size(), elites.size() >= 3 or (d._elites.is_empty() and d._challenges.size() == 1))
	d.dev_kill_all()
	await get_tree().process_frame
	d._update_challenges()
	await get_tree().process_frame
	var chest_drop := get_tree().get_nodes_in_group("loot").any(func(l): return (l as LootDrop).item.has("chest"))
	check("défi réussi : coffre de récompense au sol", d._challenges.is_empty() and chest_drop)
	print("\n%s (%d échec(s))" % ["TOUT EST OK" if fails == 0 else "ÉCHECS", fails])
	get_tree().quit()


func _nearest(br: Breakables, kind: String, from: Vector3) -> Vector3:
	var best := Vector3.INF
	for x in br.alive_list():
		if x[1] == kind and (best == Vector3.INF or (x[0] as Vector3).distance_to(from) < best.distance_to(from)):
			best = x[0]
	return best


func _use(kind: String) -> void:
	for it in world.director.map.interactables:
		if it.kind == kind and not it.used:
			world.director._interact(it)
			return
	check("lieu %s présent" % kind, false)


func _close_cards() -> void:
	world.cards._queue.clear()
	world.cards._show_next()
