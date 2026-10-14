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
	Profile.selected_zone = String(GameData.zones[0].id)  # 1re zone, quelle que soit celle du profil de test
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
	var boxes := {}
	for it in map.interactables:
		if it.kind == "chest":
			boxes[String(it.get_meta("box", ""))] = int(boxes.get(String(it.get_meta("box", "")), 0)) + 1
	check("30 coffres d'emplacement : %s" % [boxes], map.chests.size() >= 25 and boxes.size() == SlotChests.BOXES.size() and not boxes.has(""))
	var kinds := {}
	for st in map.stations:
		kinds[st.kind] = int(kinds.get(st.kind, 0)) + 1
	check("lieux : %s" % [kinds], kinds.size() == 7)
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

	# Survie : départ sans équipement, arme de départ au choix
	_close_cards()
	check("Survie : départ sans équipement (époque %d)" % Run.epoch, Run.survival and not Profile.equipped.has("helmet") and not Profile.equipped.has("head"))
	var starts: Array = d.start_weapon_cards()
	check("arme de départ : 3 armes du palier %d" % int(Epochs.map_def(Run.epoch, 1).weapon), starts.size() == 3 and starts.all(func(c): return c.item.slot == "weapon" and int(c.item.level) == int(Epochs.map_def(Run.epoch, 1).weapon)))
	Run.apply_card(starts[0])
	check("arme choisie : portée tout de suite", Profile.equipped.has("weapon") and String(Profile.equipped.weapon.uid) == String(starts[0].item.uid))
	# coffre de casque : 3 casques du palier de la map, au choix, une relance
	var chest: Interactable = null
	for it in map.interactables:
		if it.kind == "chest" and String(it.get_meta("box", "")) == "head":
			chest = it
	Profile.keys = 0
	Profile.gold = 0
	var price := d.chest_price(0, "head")
	d._interact(chest)
	check("coffre trop cher sans or (prix %d)" % price, not chest.used)
	Profile.gold = price
	d._interact(chest)
	var cards: Array = world.cards._cards
	var tier := int(Epochs.map_def(Run.epoch, Run.stage).armor)
	check("coffre de casque : 3 casques mythiques du palier %d" % tier, chest.used and cards.size() == 3
		and cards.all(func(c): return c.type == "gear" and c.item.slot == "head" and int(c.item.level) == tier and int(c.item.rarity) == Items.MYTHIC))
	check("une relance propre au coffre", world.cards._own_rerolls == 1)
	Run.apply_card(cards[0])
	check("casque choisi : porté et noté pour le hub", Profile.equipped.has("head") and int(cards[0].item.eden) in Run.seen_items)
	_close_cards()
	# enclume : un emplacement, tirage de -2 à +10, une fois par carte
	_use("anvil")
	cards = world.cards._cards
	check("enclume : choix d'emplacements", not cards.is_empty() and cards.all(func(c): return c.type == "anvil_slot"))
	Run.apply_card(cards.filter(func(c): return c.slot == "head")[0])
	var hb := int(Run.slot_bonus.get("head", 99))
	check("enclume : casque %+d (entre -2 et +10)" % hb, hb >= -2 and hb <= 10)
	_close_cards()
	check("enclume : une seule par carte", d.map.interactables.filter(func(i): return is_instance_valid(i) and i.kind == "anvil" and not i.used).is_empty())
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
	# étapes : boss vaincu → portail vers la zone suivante (même run)
	var zone0 := Run.zone_id
	d.debug_enter_dungeon()
	await get_tree().create_timer(1.0).timeout
	var boss: Monster = d._boss
	check("donjon : boss présent", is_instance_valid(boss))
	var looks0 := Profile.reward_chests.filter(func(c): return Rewards.LOOKS.has(String(c.type))).size()
	boss.take_damage(boss.max_hp * 1000.0 + 1e9, player)
	await get_tree().create_timer(0.5).timeout
	check("boss de Survie : un coffre d'apparence", Profile.reward_chests.filter(func(c): return Rewards.LOOKS.has(String(c.type))).size() == looks0 + 1)
	var portal: Interactable = null
	for it in d.map.interactables:
		if is_instance_valid(it) and it.kind == "stage_portal":
			portal = it
	check("boss vaincu : portail vers l'étape 2", portal != null and d.state == "cleared")
	var lv := player.level
	if portal:
		d._interact(portal)
		await get_tree().create_timer(1.0).timeout
	check("étape 2 : %s → %s, carte neuve, niveau gardé" % [zone0, Run.zone_id], Run.stage == 2 and Run.zone_id != zone0 and d.state == "explore"
		and d.time < 2.0 and d.map.breakables != null and d.map.breakables.count() > 600 and player.level == lv)
	_test_reward_zone()
	await _test_fortune()
	await _test_armory()
	_test_look_chests()
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


## Coffre de récompense de la 1re zone ouvert au lobby sur la dernière zone : objets de
## l'époque de sa zone (retour du joueur : trophées niveau 90 proposés à un débutant).
func _test_reward_zone() -> void:
	var was_run := Run.active
	var was_zone := Profile.selected_zone
	Run.active = false
	Profile.selected_zone = String(GameData.zones[-1].id)
	var c := Rewards.make("trophy", 6)
	c["zone"] = String(GameData.zones[0].id)
	var top := 0
	for it in Rewards.offer(c):
		top = maxi(top, int(it.level))
	var g := Rewards.make("gear", 6)
	g["zone"] = String(GameData.zones[0].id)
	var gear: Dictionary = Items.generate(6, 0.8, "", "warrior", Items.MYTHIC, "", Items.MYTHIC)  # sans la zone du coffre
	Items.reward_zone = Rewards.zone_of(g)
	var own: Dictionary = Items.generate(6, 0.8, "", "warrior", Items.MYTHIC, "", Items.MYTHIC)
	Items.reward_zone = ""
	Profile.selected_zone = was_zone  # Rewards.open sauvegarde le profil
	Run.active = was_run
	check("coffre de la 1re zone ouvert au lobby : trophées de son époque (niveau max %d)" % top, top <= 20)
	check("coffre d'équipement : objet de l'époque de sa zone (%d, %d sans elle)" % [int(own.level), int(gear.level)], int(own.level) <= int(gear.level))


## Autel de la fortune : étage 1 gagné, montée, étage 2 gagné, encaissé (or et clés) ; une
## case piégée fait tout perdre.
func _test_fortune() -> void:
	_use("fortune")
	await get_tree().process_frame
	var pop: FortunePopup = null
	for c in get_tree().root.get_children():
		if c is FortunePopup:
			pop = c
	check("autel de la fortune : la pyramide s'ouvre (jeu en pause)", pop != null and get_tree().paused)
	if pop == null:
		return
	check("étage 1 : 8 cases", (pop._rows[1] as Array).size() == 8 and (pop._rows[7] as Array).size() == 2)
	pop._pick(1, (pop._trap + 1) % 8)
	check("case gagnante : gain en attente", pop._won == 1 and not pop._over)
	pop._start_floor(2)
	pop._pick(2, (pop._trap + 1) % 7)
	var gold0 := Profile.gold
	var keys0 := Profile.keys
	pop._leave()
	check("encaissé à l'étage 2 : or et 2 clés (+%d or)" % (Profile.gold - gold0), Profile.gold > gold0 and Profile.keys == keys0 + 2 and pop._over)
	pop._close()
	await get_tree().process_frame
	check("fermé : le jeu reprend", not get_tree().paused)
	var p2 := FortunePopup.open(self, 10, 10, Callable())
	await get_tree().process_frame
	var chests0 := Profile.reward_chests.size()
	p2._pick(1, (p2._trap + 1) % 8)
	p2._start_floor(2)
	p2._pick(2, p2._trap)
	check("case piégée : série perdue, rien d'encaissé", p2._over and p2._won == 0 and Profile.reward_chests.size() == chests0)
	p2._close()
	await get_tree().process_frame


## Armurerie (hub) : une pièce vue en Survie s'achète avec des insignes, une seule fois.
func _test_armory() -> void:
	# une pièce pas encore achetée (le profil de test garde les achats des lancements précédents)
	var free := SlotChests.pool("head", 1, 2).filter(func(e): return not GearShopPage.owned(int(e.id)))
	if free.is_empty():
		free = SlotChests.pool("chest", 1, 3).filter(func(e): return not GearShopPage.owned(int(e.id)))
	var it := GearShopPage.make(free[0])
	Profile.seen_gear = [int(it.eden)]
	Profile.insignia = 500
	var page := GearShopPage.new()
	add_child(page)
	await get_tree().process_frame
	page.refresh()
	var p := GearShopPage.price(GameData.eden_by_id[int(it.eden)])
	page._on_buy()
	check("armurerie : pièce achetée (%d insignes), dans le coffre" % p, Profile.insignia == 500 - p and GearShopPage.owned(int(it.eden)))
	page._on_buy()
	check("armurerie : une seule fois", Profile.insignia == 500 - p)
	page.queue_free()


## Coffres d'apparence : une apparence nouvelle au hasard (jamais un doublon), de la rareté du coffre.
func _test_look_chests() -> void:
	var owned0 := Profile.collection.size()
	var names: Array = []
	var rarities: Array = []
	for t in Rewards.LOOK_TYPES:
		var c := Rewards.make(t, 10, true)
		Profile.reward_chests.append(c)
		var got := Rewards.open(c)
		for x in got.get("looks", []):
			names.append(String(x.name))
			rarities.append(int(x.get("rarity", 0)))
	check("coffres d'apparence : 4 apparences nouvelles %s" % [rarities], names.size() == 4 and Profile.collection.size() == owned0 + 4
		and rarities[2] == 4 and rarities[3] == 5)
	var x0: Dictionary = Rewards.roll_look("look_legend")
	check("jamais une apparence déjà obtenue", not x0.is_empty() and not Profile.collected(x0))
