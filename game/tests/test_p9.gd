extends Node
## Passe P9 (notes du joueur, conception/nuit_15_10/R_P9.md) : escalade de la rage, pièce portée jamais
## reproposée par un coffre d'emplacement, onglets de l'inventaire (icône à côté du nom), activités
## verrouillées (cadenas), coffres de récompense au niveau de leur zone.
## godot --headless --path game res://tests/test_p9.tscn   (la poursuite de la horde : test_pursuit)

var fails := 0
var world: Node


func check(label: String, ok: bool) -> void:
	print(("OK    " if ok else "ÉCHEC ") + label)
	if not ok:
		fails += 1


func _ready() -> void:
	_test_lock_cards()
	_test_reward_levels()
	await _test_inventory_tabs()
	Profile.selected_zone = String(GameData.zones[0].id)
	world = load("res://scenes/world.tscn").instantiate()
	get_tree().root.add_child.call_deferred(world)
	await get_tree().create_timer(6.0).timeout
	world.cards._queue.clear()
	world.cards._show_next()
	_test_worn_not_offered()
	_test_rage()
	print("TOUS LES TESTS PASSENT" if fails == 0 else "%d ÉCHEC(S)" % fails)
	get_tree().quit(1 if fails > 0 else 0)


## Escalade de la rage : ×1,1 puis ×2, ×11, ×101 (PV et dégâts), une minute par palier ; ni le boss
## ni les monstres d'avant la rage n'y échappent deux fois ; le texte du HUD suit.
func _test_rage() -> void:
	var d: RunDirector = world.director
	d.set_process(false)
	for m in get_tree().get_nodes_in_group("monsters"):
		m.queue_free()
	var id := d._pick_monster(5)
	d.time = RunDirector.RUN_TIME - 1.0  # montée en puissance du début de carte passée
	var m: Monster = d._spawn_monster(id, d._near_player(8.0), 5)
	var hp0 := m.max_hp
	var atk0 := m.atk
	d._process(1.5)  # 10:00 passées : la rage commence
	check("rage : palier 1 dès 10 min (%s)" % d.rage_text(), d.state == "rage" and d.rage_tier() == 1 and d.rage_text().begins_with("RAGE ×1,1 · 0:5"))
	check("palier 1 : PV ×1,1, dégâts ×1,3 (rage) ×1,1 (%.0f -> %.0f PV)" % [hp0, m.max_hp], is_equal_approx(m.max_hp, hp0 * 1.1) and is_equal_approx(m.atk, atk0 * 1.3 * 1.1))
	var expect := [2.0, 11.0, 101.0]
	for i in 3:
		d.time = RunDirector.RUN_TIME + RunDirector.RAGE_STEP * (i + 1) + 0.5
		d._process(0.0)
		check("palier %d à %d min : monstres ×%s (PV %.0f)" % [i + 2, 11 + i, RunDirector.fmt_mult(expect[i]), m.max_hp], d.rage_tier() == i + 2 and is_equal_approx(m.max_hp, hp0 * float(expect[i])) and is_equal_approx(m.atk, atk0 * 1.3 * float(expect[i])))
	d.time += 600.0
	d._process(0.0)
	check("le dernier palier dure (%s, ×101)" % d.rage_text(), d.rage_tier() == 4 and d.rage_text() == "RAGE ×101" and is_equal_approx(m.max_hp, hp0 * 101.0))
	var late := d._spawn_monster(id, d._near_player(8.0), 5)
	# lot H4a : la montée dans le temps de la carte (Epochs.time_ramp) s'ajoute pour un monstre né plus tard
	var ramp := Epochs.time_ramp(d.time) / Epochs.time_ramp(RunDirector.RUN_TIME - 1.0) if Epochs.adventure() else 1.0
	check("un monstre qui apparaît au palier 4 naît ×101 (%.0f PV)" % late.max_hp, is_equal_approx(late.max_hp, hp0 * 101.0 * ramp))
	var boss := d._spawn_monster(id, d._near_player(9.0), 5, true)
	check("le boss n'est pas multiplié par la rage", not boss.has_meta("rage_mult"))
	d.time = RunDirector.RUN_TIME + 20.0
	d._rage_tier = 0
	d._process(0.0)
	check("texte du palier 1 : « %s »" % d.rage_text(), d.rage_text() == "RAGE ×1,1 · 0:39" or d.rage_text() == "RAGE ×1,1 · 0:40")
	check("PV gardés en proportion en redescendant (test) : %.0f" % m.max_hp, is_equal_approx(m.max_hp, hp0 * 1.1))
	d.state = "boss"
	check("plus de palier dans l'arène du boss", d.rage_tier() == 0)
	d.state = "rage"
	for x in get_tree().get_nodes_in_group("monsters"):
		x.queue_free()


## Coffre d'emplacement : la pièce portée (équipement du hub) n'est pas reproposée.
func _test_worn_not_offered() -> void:
	var pool := SlotChests.pool("head", 1, 1)
	if pool.size() < 2:
		check("coffre de casque : au moins 2 pièces au palier (%d)" % pool.size(), false)
		return
	var worn := Items.from_template(pool[0], int(pool[0].level), int(pool[0].rarity))
	var was: Dictionary = Profile.equipped.get("head", {})
	Profile.equipped["head"] = worn
	var seen := false
	for i in 40:
		for it in SlotChests.offer("head", 1, 1, 3):
			seen = seen or int(it.eden) == int(worn.eden)
	check("coffre de casque : la pièce portée (%s) n'est jamais proposée (40 tirages, %d pièces au palier)" % [worn.name, pool.size()], not seen)
	check("pièces portées lues par emplacement (arme : arme secondaire comprise)", SlotChests.worn_eden("head") == [int(worn.eden)] and SlotChests.worn_eden("spell").is_empty())
	if was.is_empty():
		Profile.equipped.erase("head")
	else:
		Profile.equipped["head"] = was


## Activité verrouillée : image assombrie et cadenas enchaîné ; ouverte : rien de tout ça.
func _test_lock_cards() -> void:
	Profile.reset_all()
	var locked_card := Activities.card(Activities.get_def("dungeon"))
	var open_card := Activities.card(Activities.get_def("survival"))
	var has_lock := func(c: Control) -> bool: return c.get_children().any(func(x): return x is Activities.LockOverlay)
	check("Donjons verrouillés (compte neuf) : cadenas enchaîné", Activities.locked(Activities.get_def("dungeon")) and has_lock.call(locked_card))
	check("Survie ouverte : pas de cadenas", not has_lock.call(open_card))
	var lk: Activities.LockOverlay = locked_card.get_children().filter(func(x): return x is Activities.LockOverlay)[0]
	check("le cadenas suit le nom de l'activité (au-dessus, même sur deux lignes)", lk.title != null and lk.title is Label and (lk.title as Label).text == "Donjons")
	locked_card.free()
	open_card.free()


## Coffres de récompense au niveau de leur zone (note du 14/10 : « trophées 90 proposés trop tôt »).
func _test_reward_levels() -> void:
	var zone := String(GameData.zones[0].id)
	var band: Array = GameData.eden_bands[0]
	var gear := Rewards.make("gear", 10)
	gear["zone"] = zone
	var got := Rewards.open(gear)
	var it: Dictionary = got.items[0] if not got.items.is_empty() else {}
	# les pièces mythiques d'Eden commencent au niveau 20-23 : c'est le plancher d'un coffre mythique
	check("coffre d'équipement de niveau 10 (%s, tranche %d-%d) : pièce mythique de niveau %d (23 au plus)" % [zone, band[0], band[1], int(it.get("level", 0))],
		not it.is_empty() and int(it.level) <= maxi(int(band[1]), 23))
	var st := Rewards.make("set", 10)
	st["zone"] = zone
	var offer := Rewards.offer(st)
	check("coffre de set de niveau 10 : les plus petites panoplies (niveaux %s, 23 au plus)" % [offer.map(func(x): return int(x.level))],
		not offer.is_empty() and offer.all(func(x): return int(x.level) <= 23))


## Inventaire du Héros : l'icône de chaque famille est à côté de son nom, plus dessous (note du 15/10, bug).
func _test_inventory_tabs() -> void:
	Profile.reset_all()
	var lobby: Node = load("res://scenes/lobby.tscn").instantiate()
	add_child(lobby)
	await get_tree().create_timer(1.5).timeout
	lobby._open_hero("equipment")
	await get_tree().process_frame
	var inv: Node = lobby._hero.find_children("*", "InventoryPage", true, false).front() if not lobby._hero.find_children("*", "InventoryPage", true, false).is_empty() else null
	if inv == null:
		for n in lobby._hero.find_children("*", "", true, false):
			if n.get_script() != null and String(n.get_script().resource_path).ends_with("inventory_page.gd"):
				inv = n
				break
	var ok := inv != null and not (inv._fam_buttons as Dictionary).is_empty()
	var bad: Array = []
	if ok:
		for id in inv._fam_buttons:
			var b: Button = inv._fam_buttons[id]
			if b.text != "" and b.icon_alignment != HORIZONTAL_ALIGNMENT_LEFT:
				bad.append(id)
	check("onglets de l'inventaire : icône à gauche du nom (%s)" % ("aucun recouvrement" if bad.is_empty() else str(bad)), ok and bad.is_empty())
	lobby._hero.close_ui()
	lobby.queue_free()
	await get_tree().process_frame
