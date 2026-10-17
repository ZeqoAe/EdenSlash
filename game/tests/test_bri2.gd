extends Node
## Lot BR-I2 (Battle royale, backlog P0 n° 6 à 10 de `conception/benchmark/BATTLE_ROYALE.md`) : lieux nommés (6 à 8, ★ à
## ★★★, couvert, mêmes totaux de coffres), annonce d'atterrissage, dépouille groupée (un sac, un faisceau de la meilleure
## rareté, fenêtre de pile ▲ / ▼, « Tout le meilleur »), récapitulatif de mort (retour avant 2 min, puis définitif) et
## spectateur (suit le tueur, LB / RB), bilan v2 (bandeau, chronologie, confettis, Rejouer / Menu principal), cohérence
## (coffres au code de rareté de la Bible, passifs « monstres » bannis, aucun « run », « build », « lobby » ni pourcentage
## dans les textes du mode).
## godot --headless --path game res://tests/test_bri2.tscn

var fails := 0
var world: Node
var messages: Array = []
const FORBIDDEN := "(?i)\\b(run|runs|build|builds|lobby)\\b"


func check(label: String, ok: bool) -> void:
	print(("OK    " if ok else "ÉCHEC ") + label)
	if not ok:
		fails += 1


func _ready() -> void:
	Settings.reset_all()
	_test_static()
	await _test_world()
	await _test_results_alone()
	Royale.active = false
	print("TOUT EST OK (0 échec(s))" if fails == 0 else "ÉCHECS : %d" % fails)
	get_tree().quit(fails)


## Textes visibles d'un nœud (étiquettes, boutons ; [param rich] : aussi les textes riches).
func texts(n: Node, rich := true) -> Array:
	var out: Array = []
	if n is CanvasItem and not (n as CanvasItem).visible:
		return out
	if n is Label:
		out.append((n as Label).text)
	elif n is Button:
		out.append((n as Button).text)
	elif rich and n is RichTextLabel:
		out.append((n as RichTextLabel).get_parsed_text())
	for c in n.get_children():
		out.append_array(texts(c, rich))
	return out


## Mots interdits côté joueur (run, build, lobby) et pourcentages hors fiches d'objet.
func clean(n: Node) -> Array:
	var re := RegEx.create_from_string(FORBIDDEN)
	var bad: Array = []
	for t in texts(n, true):
		if re.search(String(t)) != null:
			bad.append(t)
	for t in texts(n, false):
		if String(t).contains("%"):
			bad.append(t)
	return bad


# --- règles sans partie ---------------------------------------------------------------------------------------
func _test_static() -> void:
	check("coffres au code de rareté de la Bible : commun lilas, rare lagon, doré soleil",
		ProcMap.ROYALE_LOOKS[0].col.is_equal_approx(Color("c9c3d6")) and ProcMap.ROYALE_LOOKS[1].col.is_equal_approx(Color("22b8f0"))
		and ProcMap.ROYALE_LOOKS[2].col.is_equal_approx(Color("ffc928")))
	Royale.active = true
	var on_map := Minimap.icon_color("chest1").is_equal_approx(Color("22b8f0")) and Minimap.icon_color("chest2").is_equal_approx(Color("ffc928"))
	Royale.active = false
	check("mini-carte : mêmes couleurs au Battle royale, celles de la Survie ailleurs", on_map and Minimap.icon_color("chest1") == Minimap.ICONS.chest1)
	var monsters: Array = Boons.all().filter(func(b): return String(b.get("desc", "")).to_lower().contains("monstre")).map(func(b): return String(b.id))
	check("passifs qui parlent de monstres : tous bannis du Battle royale (%s)" % ", ".join(monsters),
		not monsters.is_empty() and monsters.all(func(id): return id in RoyaleLoot.NO_PASSIVES) and "momentum" in RoyaleLoot.NO_PASSIVES)
	Profile.reset_all()
	Royale.start("magician")
	check("bannis pour les pièces et les cartes de niveau", RoyaleLoot.NO_PASSIVES.all(func(id): return ("passive:" + String(id)) in Run.banned and String(id) in Run.banned))
	var offered := {}
	for i in 300:
		for c in Run.roll_cards(3):
			if String(c.get("type", "")) == "passive":
				offered[String(c.id)] = true
	check("aucune carte de niveau « monstres » en 300 tirages", not offered.keys().any(func(id): return id in RoyaleLoot.NO_PASSIVES))
	check("statistiques de partie remises à zéro au départ", float(Royale.stats.dealt) == 0.0 and (Royale.stats.timeline as Array).is_empty())
	Royale.timeline_add("kill", 10.0, "A")
	Royale.timeline_add("kill", 20.0, "B")
	Royale.timeline_add("revive", 30.0)
	Royale.timeline_add("revive", 40.0)
	check("chronologie : une 1re élimination, des retours", (Royale.stats.timeline as Array).size() == 3)
	Royale.active = false
	Run.active = false
	Profile.in_run = false


func _boot_game() -> RoyaleDirector:
	Profile.reset_all()
	Royale.difficulty = 1
	Royale.start("magician")
	world = load("res://scenes/world.tscn").instantiate()
	get_tree().root.add_child.call_deferred(world)
	var waited := 0.0
	while waited < 60.0 and not (world.get("director") != null and world.director.royale != null and world.director.royale.ais.size() == 7):
		await get_tree().create_timer(0.5).timeout
		waited += 0.5
	await get_tree().create_timer(1.0).timeout
	world.cards._queue.clear()
	world.cards._show_next()
	return world.director.royale


func _clear_cards() -> void:
	world.cards._queue.clear()
	world.cards._show_next()
	get_tree().paused = false


# --- dans une vraie partie ---------------------------------------------------------------------------------------
func _test_world() -> void:
	var rd: RoyaleDirector = await _boot_game()
	var d: RunDirector = world.director
	var p: Player = world.player
	d.message.connect(func(t, _s): messages.append(String(t)))
	_test_places(rd, d)
	# atterrissage : annonce du lieu
	rd.jump.land_all()
	await get_tree().physics_frame
	rd.phase = "fight"
	var pl: Dictionary = d.map.places[0]
	p.global_position = pl.pos + Vector3.UP * 0.5
	messages.clear()
	rd._on_landed(p)
	check("atterrissage dans un lieu : « Tu atterris %s »" % String(pl.at), messages.any(func(m): return String(m).begins_with("Tu atterris " + String(pl.at))))
	check("chronologie : le saut est noté", (Royale.stats.timeline as Array).any(func(e): return String(e.kind) == "jump"))
	for a in rd.ais:
		a.passive = true
	var mid: Vector3 = d.map.ground_at(d.map.size * 0.5, d.map.size * 0.5)
	mid = (mid if mid != Vector3.INF else Vector3(d.map.size * 0.5, 2.0, d.map.size * 0.5)) + Vector3.UP * 0.3
	rd.ring = Royale.ring_at(0.0, rd.centers)
	await _test_bag(rd, d, p, mid)
	await _test_death(rd, d, p, mid)
	world.queue_free()
	await get_tree().create_timer(0.5).timeout


func _test_places(rd: RoyaleDirector, d: RunDirector) -> void:
	var pls: Array = d.map.places
	var names := {}
	for pl in pls:
		names[String(pl.name)] = true
	var stars: Array = pls.map(func(pl): return int(pl.stars))
	check("%d lieux nommés (6 à 8), noms distincts : %s" % [pls.size(), ", ".join(names.keys())], pls.size() >= 6 and pls.size() <= 8 and names.size() == pls.size())
	check("richesse : un lieu ★★★, trois ★★, les autres ★ (%s)" % [stars], stars.count(3) == 1 and stars.count(2) == 3 and stars.count(1) == pls.size() - 4)
	var en := RegEx.create_from_string("(?i)\\b(the|of|ruins|tower|old|bones)\\b")
	var fr_ok := true
	for pl in pls:
		var at := String(pl.at)
		if en.search(String(pl.name)) != null or not (at.begins_with("aux ") or at.begins_with("au ") or at.begins_with("à ")) or not at.ends_with(String(pl.name)):
			fr_ok = false
	check("noms en français, forme « à » (%s)" % String(pls[0].at), fr_ok)
	var tiers := [0, 0, 0]
	var near_ok := true
	for pl in pls:
		var c := Vector2(pl.pos.x, pl.pos.z)
		var t := [0, 0, 0]
		for it in d.map.interactables:
			if is_instance_valid(it) and it.kind == "chest" and Vector2(it.global_position.x, it.global_position.z).distance_to(c) < 20.0:
				t[int(it.get_meta("tier", 0))] += 1
		var want: Array = ProcMap.PLACE_CHESTS[int(pl.stars) - 1]
		if t[0] + t[1] + t[2] < int(want[0]) or t[2] < int(want[2]) or t[1] < int(want[1]):
			near_ok = false
	for it in d.map.interactables:
		if is_instance_valid(it) and it.kind == "chest":
			tiers[int(it.get_meta("tier", 0))] += 1
	check("coffres des lieux en couronne, selon leur richesse", near_ok)
	check("mêmes totaux sur la carte : 64 coffres, 18 rares, 8 dorés (%s)" % [tiers], tiers[0] + tiers[1] + tiers[2] == 64 and tiers[1] == 18 and tiers[2] == 8)
	check("du couvert dans chaque lieu (murets, rochers)", pls.all(func(pl): return (pl.cover as Array).size() >= 2) and d.map.get_node_or_null("Cover") != null)
	var api := rd.places()
	check("RoyaleDirector.places() pour les cartes (nom, ★, position, héros qui y visent)", api.size() == pls.size() and api.all(func(e): return e.has("aimed") and e.has("stars") and not e.has("cover")))
	check("place_at : le lieu sous une position", String(rd.place_at(pls[0].pos).get("name", "")) == String(pls[0].name))


func _test_bag(rd: RoyaleDirector, d: RunDirector, p: Player, mid: Vector3) -> void:
	rd.elapsed = 200.0
	var victim: ClassRival = rd.ais[0]
	for k in 6:
		Royale.ai_open_chest(victim, 2)
	var gear: Dictionary = (victim.get_meta("royale").gear as Dictionary).duplicate()
	var expect := RoyaleLoot.drops_of(gear)
	for it in expect:  # (le joueur porte de vieilles pièces : celles qu'il remplace rejoignent la dépouille)
		RoyaleLoot.wear(SurvivorGear.adopt(Items.generate(1, 0.0, String(it.slot), "magician", 0, "", 0)))
	var g0 := rd.ground.size()
	p.global_position = mid + Vector3(8, 0, 0)
	victim.global_position = mid
	victim.hp = 1.0
	victim.take_damage(1e9, p, false)
	await get_tree().physics_frame
	_clear_cards()
	check("héros éliminé : une seule dépouille (%d)" % (rd.ground.size() - g0), rd.ground.size() - g0 == 1)
	var bag: Interactable = rd.ground.back()
	check("la dépouille garde ses %d pièces (sauf l'arme)" % expect.size(), RoyaleLoot.bag_items(bag).size() == expect.size() and expect.size() > 0
		and RoyaleLoot.bag_items(bag).all(func(it): return String(it.slot) != "weapon"))
	var beams := (bag.get_node("BagFx") as Node).get_children().filter(func(n): return n is MeshInstance3D and (n as MeshInstance3D).mesh is CylinderMesh)
	var best := RoyaleLoot.bag_best_rarity(bag)
	var col: Color = (beams[0] as MeshInstance3D).material_override.albedo_color if not beams.is_empty() else Color.BLACK
	check("un seul faisceau, de la meilleure rareté (%s)" % Items.RARITIES[best].name, beams.size() == 1 and Color(col, 1.0).is_equal_approx(RoyaleStyle.RARITY[best]))
	check("invite : « Fouiller » (%s)" % bag.prompt(), bag.prompt().contains("Fouiller") and bag.prompt().contains(str(expect.size())))
	# fenêtre de pile
	var ups_before := RoyaleLoot.bag_upgrades(bag, Profile.equipped, Run.class_id, Run.hero_level).size()
	p.global_position = bag.global_position + Vector3(1, 0.3, 0)
	rd.interact(bag)
	await get_tree().process_frame
	var sh: RoyaleGearSheet = rd._sheet
	check("fenêtre de pile ouverte, jeu en pause", sh != null and sh.is_open() and sh.pile_mode() and get_tree().paused)
	if sh == null:
		return
	var badges := 0
	for s in sh.slot_buttons:
		if sh.compare(String(s)) == 1:
			badges += 1
	check("▲ sur les pièces meilleures que les tiennes (%d)" % ups_before, badges == ups_before and ups_before > 0)
	check("« Tout le meilleur » disponible", sh.best_button != null and not sh.best_button.disabled)
	check("textes de la fenêtre sans run / build / lobby (%s)" % [clean(sh)], clean(sh).filter(func(t): return not String(t).contains("%")).is_empty())
	var n_before := RoyaleLoot.bag_items(bag).size()
	var taken := sh.take_all_best()
	check("« Tout le meilleur » : %d pièces portées, plus rien de meilleur" % taken, taken == ups_before
		and RoyaleLoot.bag_upgrades(bag, Profile.equipped, Run.class_id, Run.hero_level).is_empty())
	check("les pièces remplacées rejoignent la dépouille (%d -> %d)" % [n_before, RoyaleLoot.bag_items(bag).size()],
		RoyaleLoot.bag_items(bag).size() == n_before)
	var any_slot := ""
	for it in RoyaleLoot.bag_items(bag):
		any_slot = String(it.slot)
	if any_slot != "":
		var it: Dictionary = RoyaleLoot.bag_item(bag, any_slot)
		sh.select(any_slot)
		sh.take_selected()
		check("« Prendre » : la pièce désignée est portée", is_same(Profile.equipped.get(any_slot), it))
	var esc := InputEventAction.new()
	esc.action = "ui_cancel"
	esc.pressed = true
	sh._input(esc)
	check("Échap ferme la fenêtre, le jeu reprend", not sh.is_open() and not get_tree().paused)
	await get_tree().process_frame
	# un héros scripté prend dans la dépouille
	var taker: ClassRival = rd.ais[2]
	var tst: Dictionary = taker.get_meta("royale")
	var ups := RoyaleLoot.bag_upgrades(bag, tst.gear, String(tst.cid), int(tst.lv))
	if not ups.is_empty():
		var titem: Dictionary = ups[0]
		taker.global_position = bag.global_position
		var busy := rd._ai_ground(taker, taker.global_position)
		check("héros scripté : prend une pièce dans la dépouille (%s)" % String(titem.slot), busy and is_same(tst.gear.get(String(titem.slot)), titem)
			and not RoyaleLoot.bag_items(bag).any(func(x): return is_same(x, titem)))
	# menu pause du mode : « Partie », ni run ni build
	world.pause_menu.open()
	await get_tree().process_frame
	world.pause_menu._run.refresh()
	await get_tree().process_frame
	var bad := clean(world.pause_menu._run).filter(func(t): return not String(t).contains("%"))
	check("menu pause du Battle royale : page « Partie », ni run ni build (%s)" % [bad], bad.is_empty()
		and world.pause_menu._screen._tab_buttons.any(func(b): return b.text.contains("Partie")))
	check("menu pause : pas d'arme secondaire", not texts(world.pause_menu._run).any(func(t): return String(t).contains("Arme secondaire")))
	world.pause_menu.close()
	get_tree().paused = false


func _test_death(rd: RoyaleDirector, d: RunDirector, p: Player, mid: Vector3) -> void:
	# tombé avant 2 min : récapitulatif court, retour compté
	rd.elapsed = 30.0
	var killer: ClassRival = rd.ais[3]
	killer.global_position = mid + Vector3(-6, 0, 0)
	killer.set_meta("move", {"name": "Lame d'essai", "icon": ""})
	Royale.note_fight(killer, p, rd.clock, 321.0)
	_kill_player(p, killer)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var rv: RoyaleRecap = rd.recap_view
	check("tombé avant 2 min : récapitulatif « retour », pas de spectateur", rv != null and rv.revive_mode() and not rd.spectating)
	check("plus de « tu reviendras » dans le fil", not rd.kill_feed.any(func(e): return String(e[0]).contains("tu reviendras")))
	if rv != null:
		await get_tree().process_frame
		check("récapitulatif : le tueur et son coup (« %s »)" % RoyaleRecap.how_line(rv.data), String(rv.data.name) != "" and String(rv.data.move) == "Lame d'essai"
			and float(rv.data.dmg) > 0.0 and int(rv.data.killer_hp) > 0 and texts(rv).any(func(t): return String(t).begins_with("Retour dans")))
	rd._tick_revives(Royale.REVIVE_DELAY + 0.5)
	await get_tree().physics_frame
	check("de retour : le récapitulatif se ferme", rd.recap_view == null and not p.is_dead)
	rd.jump.land_all()
	await get_tree().physics_frame
	# 2e chute : définitive, récapitulatif complet, spectateur sur le tueur
	rd.elapsed = 200.0
	p.global_position = mid + Vector3(8, 0, 0)
	killer.global_position = mid + Vector3(10, 0, 0)
	Royale.note_fight(killer, p, rd.clock, 222.0)
	_kill_player(p, killer)
	await get_tree().physics_frame
	await get_tree().physics_frame
	rv = rd.recap_view
	check("2e chute : récapitulatif, spectateur sur le tueur", rv != null and not rv.revive_mode() and rd.spectating and rd.watched == killer and rv.is_card_open())
	if rv == null:
		return
	await get_tree().process_frame
	check("récapitulatif : place, dégâts donnés / reçus, temps (%s)" % [texts(rv.card)], int(rv.data.place) >= 2 and float(rv.data.taken) >= 543.0
		and texts(rv.card).any(func(t): return String(t).begins_with("Éliminé · ")) and rv.watch_button != null and rv.results_button != null)
	check("récapitulatif : ni run ni pourcentage (%s)" % [clean(rv)], clean(rv).is_empty())
	var first := rd.watched
	rd.spectate_step(1)
	var second := rd.watched
	rd.spectate_step(-1)
	check("LB / RB : héros suivant puis retour au tueur", second != first and rd.watched == first and world.rig.target == first)
	var lb := InputEventJoypadButton.new()
	lb.button_index = JOY_BUTTON_RIGHT_SHOULDER
	lb.pressed = true
	rd._unhandled_input(lb)
	check("RB de la manette change de héros", rd.watched != first)
	rv.watch()
	await get_tree().process_frame
	check("« Regarder » : la carte se ferme, le bandeau du spectateur reste (« %s »)" % rv.bar_text(), not rv.is_card_open() and rv._bar.visible
		and rv.bar_text().contains("Tu regardes"))
	# « Bilan » : fin de partie et bilan v2
	rv.results_requested.emit()
	check("« Bilan » : la partie se termine à sa place", rd.phase == "over")
	await get_tree().create_timer(1.0).timeout
	var res: RoyaleResults = null
	for c in world.get_children():
		if c is RoyaleResults:
			res = c
	check("bilan v2 affiché", res != null and world._ended)
	if res == null:
		return
	await get_tree().create_timer(ResultsPanel.LOCK_SECS + 0.2, true).timeout
	var kinds: Array = []
	if res.timeline != null:
		for c in res.timeline.get_children():
			if c.has_meta("kind"):
				kinds.append(String(c.get_meta("kind")))
	check("bandeau « Place N » (%s)" % RoyaleResults.banner_text(Royale.rank), res.banner != null and texts(res.banner)[0] == "Place %d" % Royale.rank)
	check("chronologie : saut, retour, fin (%s)" % [kinds], "jump" in kinds and "revive" in kinds and "down" in kinds)
	check("défaite : pas de confettis", res.confetti.is_empty())
	check("Rejouer en bouton principal, Menu principal", res.buttons.size() == 2 and res.buttons[0].text == "Rejouer" and res.buttons[1].text == "Menu principal")
	check("bilan : ni run, ni build, ni lobby (%s)" % [clean(res).filter(func(t): return not String(t).contains("%"))],
		clean(res).filter(func(t): return not String(t).contains("%")).is_empty())
	get_tree().paused = false


func _kill_player(p: Player, killer: Combatant) -> void:
	p.hp = 1.0
	p.evasion_chance = 0.0
	p.parry_chance = 0.0
	p.shield_until = 0.0
	p.take_damage(1e9, killer, false)


# --- bilan de victoire seul ---------------------------------------------------------------------------------------
func _test_results_alone() -> void:
	Royale.reset_stats()
	Royale.stats.dealt = 7820.0
	Royale.stats.clock = 600.0
	for e in [["jump", 15.0], ["kill", 120.0], ["drop", 300.0], ["bounty", 420.0], ["win", 590.0]]:
		Royale.timeline_add(String(e[0]), float(e[1]))
	var r := RoyaleResults.new()
	add_child(r)
	r.show_results(1, 4, 23, 11, 581.0, {"text": ["+110 insignes (victoire, 4 éliminations)", "Coffre d'apparence légendaire"], "mastery": 30})
	await get_tree().create_timer(0.3, true).timeout
	r.finish_now()
	check("victoire : bandeau « N°1 · Victoire ! »", r.banner != null and texts(r.banner)[0] == "N°1 · Victoire !")
	check("victoire : confettis des 5 bonbons (24)", r.confetti.size() == 24)
	check("tuiles : place, éliminations, dégâts, niveau, coffres, durée", texts(r).has("7 820") and texts(r).has("dégâts") and texts(r).has("9:41"))
	var pills := r.timeline.get_children().filter(func(c): return c.has_meta("kind")) if r.timeline != null else []
	var inside := pills.all(func(c): return (c as Control).position.x >= 0.0 and (c as Control).position.x <= RoyaleResults.TIMELINE_W)
	check("chronologie : 5 moments, dans la barre", pills.size() == 5 and inside)
	check("récompense d'apparence dans « Gardé »", texts(r).any(func(t): return String(t).begins_with("Coffre d'apparence")))
	r.queue_free()
	get_tree().paused = false
	await get_tree().process_frame
