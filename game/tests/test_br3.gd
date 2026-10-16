extends Node
## Lot BR3 (Battle royale) : règles des coffres (une pièce par emplacement vide, jamais d'arme, pièce de remplacement
## seulement nettement meilleure, améliorations du Survivant une fois l'équipement complet), cartes de sorts sans
## technique d'arme, héros scriptés (remplissage puis améliorations, jamais de pièce moins bonne), pièces lâchées à la
## mort (sauf l'arme), ramassage, fiche d'équipement d'un héros tombé et du héros suivi en spectateur.
## godot --headless --path game res://tests/test_br3.tscn

var fails := 0
var world: Node


func check(label: String, ok: bool) -> void:
	print(("OK    " if ok else "ÉCHEC ") + label)
	if not ok:
		fails += 1


func _ready() -> void:
	Settings.reset_all()
	_test_player_rules()
	_test_spell_cards()
	_test_ai()
	await _test_world()
	Royale.active = false
	print("TOUT EST OK (0 échec(s))" if fails == 0 else "ÉCHECS : %d" % fails)
	get_tree().quit(fails)


func _start() -> void:
	Profile.reset_all()
	Royale.difficulty = 1
	Royale.start("magician")
	Run.hero_level = 6


## Coffres du joueur : arme de départ, remplissage, remplacement, améliorations, retrait des passifs.
func _test_player_rules() -> void:
	_start()
	var w := Items.generate(2, 0.0, "weapon", "magician", 0, Run.weapon_type(), 0)
	var wc := RoyaleLoot.start_weapon_cards([{"item": w}])
	var lo := Survivor.rule("quality_min")
	var hi := Survivor.rule("perfect_quality")
	check("arme de départ : carte « Arme » du Survivant (jet %d, passif fixe)" % roundi(float(w.quality) * 100.0),
		wc.size() == 1 and String(wc[0].type) == "sv_weapon" and bool(w.get("sv", false)) and float(w.quality) >= lo - 0.001 \
		and float(w.quality) <= hi + 0.001 and not (w.get("sv_passives", []) as Array).is_empty())
	Run.apply_card(wc[0])
	check("arme portée, son passif fixe compte dans la run", is_same(Profile.equipped.get("weapon"), w) and Run.passives.has(String(w.sv_passives[0].id)))
	# remplissage : une pièce par emplacement vide, jamais d'arme, un emplacement par carte
	var rounds := 0
	var weapon_seen := false
	var dup_slots := false
	var wrong_count := false
	var filled_without_replace := false
	while not RoyaleLoot.is_complete(Profile.equipped) and rounds < 40:
		rounds += 1
		var empties := RoyaleLoot.empty_slots(Profile.equipped).filter(func(s): return s != "weapon")
		var cards := RoyaleLoot.player_cards(1, Run.hero_level)
		var slots := {}
		var fresh := 0
		for c in cards:
			var s := String(c.get("slot", ""))
			if slots.has(s):
				dup_slots = true
			slots[s] = true
			if c.has("item") and String(c.item.get("slot", "")) == "weapon":
				weapon_seen = true
			if String(c.type) == "sv_piece":
				if s in empties:
					fresh += 1
				elif not c.get("replace", false):
					filled_without_replace = true
		if fresh != mini(3, empties.size()):
			wrong_count = true
		for c in cards:
			if String(c.type) == "sv_piece" and not c.get("replace", false):
				Run.apply_card(c)
				break
	check("équipement complet en %d coffres (8 emplacements vides : 8)" % rounds, RoyaleLoot.is_complete(Profile.equipped) and rounds == 8)
	check("une nouvelle pièce par emplacement vide (3 au plus)", not wrong_count)
	check("jamais d'arme proposée, jamais deux cartes pour un même emplacement", not weapon_seen and not dup_slots)
	check("une pièce pour un emplacement pris est toujours un remplacement", not filled_without_replace)
	# remplacement : seulement nettement meilleur (une tête commune de niveau 1, un emplacement encore vide)
	var prof := ClassGear.profile("magician")
	var poor := SurvivorGear.adopt(Items.generate(1, 0.0, "head", "magician", 0, "", 0))
	RoyaleLoot.wear(poor)
	var ring: Dictionary = Profile.equipped.ring
	RoyaleLoot.strip([ring])
	var replaces := 0
	var weak := 0
	for i in 300:
		for c in RoyaleLoot.player_cards(2, Run.hero_level):
			if c.get("replace", false):
				replaces += 1
				var worn: Dictionary = Profile.equipped[String(c.slot)]
				if RoyaleLoot.rate(c.item, prof, Run.hero_level) < RoyaleLoot.rate(worn, prof, Run.hero_level) * RoyaleLoot.REPLACE_RATIO - 0.001:
					weak += 1
	check("remplacements proposés %d fois sur 300 coffres, tous nettement meilleurs" % replaces, replaces > 0 and weak == 0)
	RoyaleLoot.wear(ring)
	# équipement complet : seulement des améliorations (système du Survivant), emplacements différents
	var only_ups := true
	var distinct := true
	var auto_ok := true
	for i in 200:
		var cards := RoyaleLoot.player_cards(i % 4, Run.hero_level)
		var seen := {}
		for c in cards:
			if not String(c.type) in ["sv_piece_up", "sv_weapon_up"]:
				only_ups = false
			if seen.has(String(c.slot)):
				distinct = false
			seen[String(c.slot)] = true
		var pick := CardPicker.auto_pick(cards, true)
		for c in cards:
			if float(c.royale_gain) > float(pick.royale_gain) + 0.0001:
				auto_ok = false
	check("équipement complet : seulement des améliorations de pièces portées", only_ups)
	check("améliorations : un emplacement par carte", distinct)
	check("choix automatique : le plus grand gain, sans bloquer", auto_ok)
	# amélioration : +2 par carte commune, le passif du palier +6 affiché = appliqué
	var head: Dictionary = Profile.equipped.head
	var shown := ""
	var guard := 0
	while int(head.get("upgrade", 0)) < 6 and guard < 10:
		guard += 1
		var c := SurvivorCards.up_card("head", "common")
		for p in c.offer.passives:
			shown = String(p.id)
		Run.apply_card(c)
	check("tête menée à +%d, passif du palier +6 « %s » posé" % [int(head.upgrade), shown], int(head.upgrade) >= 6 and shown != "" \
		and shown in SurvivorGear.passives_of(head) and Run.passives.has(shown))
	# retrait : les passifs d'une pièce enlevée quittent la run
	var own: Array = SurvivorGear.passives_of(head).filter(func(id): return Profile.equipped.values().filter(func(x): return id in SurvivorGear.passives_of(x)).size() == 1)
	RoyaleLoot.strip([head])
	check("pièce retirée : ses passifs quittent la run (%d)" % own.size(), not Profile.equipped.has("head") and own.all(func(id): return not Run.passives.has(id)))


## Cartes de montée de niveau : jamais de technique d'arme, amélioration de sort du Survivant (niveau 5 au moins épique).
func _test_spell_cards() -> void:
	_start()
	var ids: Array = (GameData.class_data("magician").get("skills", []) as Array).map(func(s): return int(s.id))
	Run.skills = [{"id": ids[0], "rank": 4}, {"id": ids[1], "rank": 2}, {"id": ids[2], "rank": 1}, {"id": ids[3], "rank": 1}]
	Profile.equipped["weapon"] = SurvivorGear.adopt(Items.generate(2, 0.0, "weapon", "magician"))
	var weapon_up := false
	var not_sv := false
	var floor_ok := true
	var seen_up := 0
	for i in 400:
		for c in Run.roll_cards(3):
			match String(c.type):
				"weapon_up", "gear", "sv_piece":
					weapon_up = true
				"upgrade":
					seen_up += 1
					if not String(c.get("sv_key", "")).begins_with("spup:"):
						not_sv = true
					if int(c.id) == ids[0] and Cards.TIER_ORDER.find(String(c.tier)) < Cards.TIER_ORDER.find("epic"):
						floor_ok = false
	check("montée de niveau : ni arme ni pièce", not weapon_up)
	check("amélioration de sort du Survivant (%d vues)" % seen_up, seen_up > 0 and not not_sv)
	check("sort mené au niveau 5 : carte au moins épique", floor_ok)
	Royale.active = false
	Run.active = false
	Profile.in_run = false


## Héros scriptés : remplissage (un emplacement vide par coffre), puis améliorations ; jamais une pièce moins bonne.
func _test_ai() -> void:
	Royale.active = true
	var r := Royale.make_ai("warrior", 2, 1)
	var st: Dictionary = r.get_meta("royale")
	var prof := ClassGear.profile("warrior")
	var full_at := -1
	var worse := 0
	var score0 := 0.0
	for i in 40:
		var before: Dictionary = (st.gear as Dictionary).duplicate()
		Royale.ai_open_chest(r, 1)
		var lv := int(st.lv)
		for s in before:
			if RoyaleLoot.rate(st.gear[s], prof, lv) < RoyaleLoot.rate(before[s], prof, lv) - 0.001:
				worse += 1
		if full_at < 0 and RoyaleLoot.is_complete(st.gear):
			full_at = i + 1
			score0 = Royale.gear_score(st.gear, "warrior", lv)
	var w: Dictionary = st.gear.get("weapon", {})
	# (un coffre peut, rarement, offrir à un scripté un remplacement « nettement meilleur » que le meilleur choix retient avant
	# le dernier emplacement vide : 9 coffres au plus tôt, jamais plus de 11 ; le joueur, lui, remplit toujours en 8 coffres)
	check("héros scripté : équipement complet en %d coffres (9 emplacements)" % full_at, full_at >= 9 and full_at <= 11)
	check("héros scripté : une seule arme, du type de sa classe", Items.weapon_type_of(w) == Items.default_weapon_type("warrior") and (st.gear as Dictionary).size() == 9)
	check("héros scripté : jamais une pièce moins bonne (%d)" % worse, worse == 0)
	check("héros scripté : les coffres suivants améliorent ses pièces (note %.1f → %.1f)" % [score0, Royale.gear_score(st.gear, "warrior", int(st.lv))],
		Royale.gear_score(st.gear, "warrior", int(st.lv)) > score0)
	r.free()
	Royale.active = false


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


## Dans une vraie partie : pièces lâchées, dépouille et fiche, ramassage (joueur et héros scripté), mort du joueur.
func _test_world() -> void:
	var rd: RoyaleDirector = await _boot_game()
	var d: RunDirector = world.director
	var p: Player = world.player
	if rd.get("jump") != null and is_instance_valid(rd.jump):
		rd.jump.land_all()  # (largage du lot BR4 : tout le monde au sol)
	await get_tree().physics_frame
	rd.phase = "fight"
	rd.elapsed = 200.0  # (après les deux premières minutes)
	for a in rd.ais:
		a.passive = true
	var victim: ClassRival = rd.ais[0]
	for k in 6:
		Royale.ai_open_chest(victim, 1)
	var gear: Dictionary = (victim.get_meta("royale").gear as Dictionary).duplicate()
	var expect := RoyaleLoot.drops_of(gear).size()
	var g0 := rd.ground.size()
	var mid: Vector3 = d.map.ground_at(d.map.size * 0.5, d.map.size * 0.5)
	mid = (mid if mid != Vector3.INF else Vector3(d.map.size * 0.5, 2.0, d.map.size * 0.5)) + Vector3.UP * 0.3  # (dans l'anneau)
	p.global_position = mid + Vector3(8, 0, 0)  # (le joueur aussi : l'anneau ne l'use pas pendant le test)
	victim.global_position = mid
	victim.hp = 1.0
	victim.take_damage(1e9, p, false)
	await get_tree().physics_frame
	world.cards._queue.clear()
	world.cards._show_next()  # (le niveau gagné a ouvert un choix de carte)
	check("héros éliminé : %d pièces au sol (sauf l'arme)" % (rd.ground.size() - g0), rd.ground.size() - g0 == expect and expect > 0 \
		and rd.ground.all(func(n): return String(n.get_meta("item").slot) != "weapon"))
	var rems: Array = d.map.interactables.filter(func(it): return is_instance_valid(it) and it.kind == "remains")
	check("une dépouille garde sa fiche (niveau, classe, pièces)", rems.size() == 1 and rd.fallen.size() == 1 and (rd.fallen[0].gear as Dictionary).size() == gear.size())
	check("invites : dépouille et pièce au sol", rems.size() == 1 and String(rems[0].prompt()).contains("équipement") and String(rd.ground[0].prompt()).contains("Prendre"))
	# fiche d'équipement : ouverte près de la dépouille, jeu en pause, 9 emplacements, B / Échap la ferme
	rd.interact(rems[0])
	await get_tree().process_frame
	var sh: RoyaleGearSheet = rd._sheet
	check("fiche ouverte, jeu en pause, 9 emplacements", sh != null and sh.is_open() and get_tree().paused and sh.slot_buttons.size() == 9)
	if sh != null:
		var any_drop := ""
		for s in sh.rec.drops:
			any_drop = String(s)
		check("fiche : où est chaque pièce (« %s »)" % sh.where(any_drop), any_drop == "" or sh.where(any_drop).begins_with("Au sol"))
		var esc := InputEventAction.new()
		esc.action = "ui_cancel"
		esc.pressed = true
		sh._input(esc)
		check("Échap ferme la fiche, le jeu reprend", not sh.is_open() and not get_tree().paused)
		await get_tree().process_frame
	# le joueur prend une pièce au sol : portée tout de suite, pièce du Survivant
	var node: Interactable = rd.ground[0]
	var it: Dictionary = node.get_meta("item")
	rd.interact(node)
	check("pièce ramassée : portée (%s), faite pièce du Survivant" % String(it.slot), is_same(Profile.equipped.get(String(it.slot)), it) and bool(it.get("sv", false)) \
		and not rd.ground.has(node))
	# un héros scripté prend une pièce au sol meilleure que la sienne
	var taker: ClassRival = rd.ais[2]
	var tst: Dictionary = taker.get_meta("royale")
	var target: Interactable = null
	for n in rd.ground:
		if is_instance_valid(n) and RoyaleLoot.better(n.get_meta("item"), tst.gear, String(tst.cid), int(tst.lv)):
			target = n
			break
	if target != null:
		var titem: Dictionary = target.get_meta("item")
		taker.global_position = target.global_position
		rd.ring = Royale.ring_at(0.0, rd.centers)  # (toute la carte : la pièce est dans l'anneau)
		var busy := rd._ai_ground(taker, taker.global_position)
		check("héros scripté : ramasse la pièce tombée (%s)" % String(titem.slot), busy and is_same(tst.gear.get(String(titem.slot)), titem) and not rd.ground.has(target))
	# mort du joueur : ses pièces tombent, il garde son arme ; en spectateur, [F] montre l'équipement du héros suivi
	Profile.equipped["weapon"] = SurvivorGear.adopt(Items.generate(2, 0.0, "weapon", "magician"))
	RoyaleLoot.wear(SurvivorGear.adopt(Items.generate(3, 0.0, "boots", "magician")))
	var worn_n := RoyaleLoot.drops_of(Profile.equipped).size()
	var g1 := rd.ground.size()
	var killer: ClassRival = rd.ais[3]
	p.hp = 1.0
	p.evasion_chance = 0.0  # (esquive et parade du héros sont tirées au hasard : le coup fatal doit toujours porter)
	p.parry_chance = 0.0
	p.shield_until = 0.0
	p.take_damage(1e9, killer, false)
	await get_tree().physics_frame
	await get_tree().physics_frame
	check("joueur tombé : %d pièces au sol sur %d, il garde son arme (mort %s, phase %s, équipé %s)" % [rd.ground.size() - g1, worn_n, p.is_dead, rd.phase,
		Profile.equipped.keys()], rd.ground.size() - g1 == worn_n \
		and Profile.equipped.keys() == ["weapon"])
	if rd.spectating and rd.watched != null and is_instance_valid(rd.watched):
		var ev := InputEventAction.new()
		ev.action = "interact"
		ev.pressed = true
		rd._unhandled_input(ev)
		await get_tree().process_frame
		var sh2: RoyaleGearSheet = rd._sheet if is_instance_valid(rd._sheet) else null
		check("spectateur : [F] montre l'équipement du héros suivi", sh2 != null and sh2.is_open() and String(sh2.rec.name) != "" and int(sh2.rec.place) == 0)
		if sh2 != null:
			sh2.close()
	world.queue_free()
	await get_tree().create_timer(0.5).timeout
