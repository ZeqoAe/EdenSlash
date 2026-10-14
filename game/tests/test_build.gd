extends Node
## Systèmes de build : combo d'auto-attaque, effets déclenchés (procs), sets
## d'équipement, cartes roguelite (raretés, évolutions, relances), plafond de niveau.
## godot --headless --path game res://tests/test_build.tscn  (profil de test uniquement)

var fails := 0
var world: Node
var player: Player


func check(label: String, ok: bool) -> void:
	print(("OK    " if ok else "ÉCHEC ") + label)
	if not ok:
		fails += 1


func _ready() -> void:
	check("profil de test", Profile.save_path == Profile.TEST_SAVE_PATH)
	Profile.reset_all()
	Profile.selected_class = "samurai"  # combo du katana (on démarre Guerrier sinon)
	Profile.save_profile()
	Run.start("samurai")
	_test_sets()
	_test_cards()
	_test_ban_keep()
	_test_gear_rules()
	_test_spell_presets()
	_test_forge_lobby()
	_test_dev_unlimited()
	_test_rival_spells()
	_test_profile_apply()
	await _test_world()
	print("\n%s (%d échec(s))" % ["TOUT EST OK" if fails == 0 else "ÉCHECS", fails])
	get_tree().quit(1 if fails > 0 else 0)


func _test_sets() -> void:
	var pieces: Array = []
	for slot in ["head", "chest", "legs", "gloves"]:
		var it := Items.generate(10, 1.0, slot, "samurai", 2)
		Items.make_set_piece(it, "storm")
		pieces.append(it)
	check("pièce de set : nom", String(pieces[0].name).ends_with("de la Tempête"))
	var eq := {"head": pieces[0], "chest": pieces[1]}
	check("2 pièces : 1 bonus actif", Items.active_set_bonuses(eq).size() == 1)
	for i in 4:
		Profile.equipped[pieces[i].slot] = pieces[i]
	var b := Items.active_set_bonuses(Profile.equipped)
	check("4 pièces : bonus 2 et 4 actifs", b.size() == 2)
	check("stats de set ajoutées à l'équipement", Profile.equipment_stats().get("atk_speed", 0.0) >= 0.08)
	check("proc de set (foudre) actif", Profile.equipment_procs().filter(func(p): return p.effect == "lightning").size() == 1)
	check("infobulle : bonus de set", Items.describe(pieces[0]).contains("4 pièces"))
	var n_sets := 0
	for i in 200:
		if Items.generate(5, 0.5, "", "samurai", Items.MYTHIC, "", Items.MYTHIC).has("set"):
			n_sets += 1
	check("pièces de set d'Eden sur les mythiques (boss) : %d / 200" % n_sets, n_sets > 10)
	check("pas de set sur le butin courant", range(200).all(func(_i): return not Items.generate(5, 1.0).has("set")))
	for i in 4:
		Profile.equipped.erase(pieces[i].slot)


func _test_cards() -> void:
	var ids := {}
	for i in 300:
		for c in Run.roll_cards(3):
			ids[str(c.id)] = c
	check("cartes de build proposées", ids.has("static_blade") and ids.has("wide_arc"))
	check("évolution absente sans prérequis", not ids.has("storm_lord"))
	check("carte verrouillée (méta-progression) : 2 boss pour Seigneur de la tempête", not Cards.card_unlocked("storm_lord") and Cards.card_unlocked("wide_arc"))
	Profile.unlocked_cards.append("storm_lord")
	Run.apply_card(_common_card("static_blade"))
	var found := false
	for i in 300:
		for c in Run.roll_cards(3):
			found = found or str(c.id) == "storm_lord"
	check("évolution proposée avec son prérequis", found)
	check("carte de base rare, rareté tirée à l'offre", Run.passive_def("static_blade").rarity == "rare" and Run._describe_card({"type": "passive", "id": "static_blade"}).has("tier"))
	check("1 relance par run", Run.rerolls_left() == 1)
	Run.apply_card(_common_card("fortune"))
	check("Bonne étoile : +1 relance", Run.rerolls_left() == 2)
	Run.apply_card(_common_card("static_blade"))
	var p: Dictionary = Run.passive_procs().filter(func(x): return x.id == "static_blade_0")[0]
	check("proc cumulé (2 cartes) : plus de chances et de rebonds", is_equal_approx(float(p.chance), 0.5) and int(p.chain) == 4)
	Run.passives.clear()


func _test_world() -> void:
	world = load("res://scenes/world.tscn").instantiate()
	get_tree().root.add_child.call_deferred(world)
	await get_tree().create_timer(6.0).timeout
	player = world.player
	for m in get_tree().get_nodes_in_group("monsters"):
		m.queue_free()
	world.director.set_process(false)
	world.director.set_physics_process(false)
	world.cards._queue.clear()
	world.cards._show_next()
	await get_tree().create_timer(0.3).timeout

	# plafond de niveau de la map 1
	check("butin plafonné au niveau 15", world.director.loot_level(40) == 15 and world.director.max_level() == 15)
	player.level = 40
	check("monstres plafonnés (hors rage)", world.director._monster_level(2) == 15)
	player.level = 1

	# auto-attaque de l'arme (0.1.127) : toujours la même, plus de combo ni de coup final
	var m := _dummy(1.8)
	var hp_m := m.hp
	player._start_attack(m.global_position)
	check("auto-attaque : coup de l'arme", player._action.get("basic", false) and not player._action.has("finisher") and int(player._action.get("hits", 1)) == 1)
	await _wait_idle()
	check("auto-attaque : touche", m.hp < hp_m)
	player._start_attack(m.global_position)
	check("auto-attaque : la même au coup suivant", player._action.get("basic", false) and int(player._action.get("hits", 1)) == 1)
	await _wait_idle()
	Run.apply_card(_common_card("multishot"))
	check("Projectile supplémentaire : +1 frappe en mêlée", player.extra_proj == 1 and int(WeaponAttacks.action_for(WeaponAttacks.spec_for({"auto_variant": 0, "slot": "weapon"}, "katana"), player).hits) == 2)
	var bow := WeaponAttacks.action_for(WeaponAttacks.spec_for({}, "bow"), player)
	check("Projectile supplémentaire : 2 flèches à l'arc", String(bow.kind) == "bolt" and int(bow.volley) == 2)
	var staff := WeaponAttacks.action_for(WeaponAttacks.spec_for({"auto_variant": 0, "slot": "weapon"}, "staff"), player)
	check("bâton : incantation à 2 zones, délai réglé par la vitesse d'incantation", String(staff.kind) == "cast" and int(staff.zones) == 2 \
		and is_equal_approx(float(staff.delay), 0.65 / player.cast_speed))
	for wt in GameData.weapon_types:
		for v in WeaponAttacks.variants(String(wt)):
			if not (v.has("shape") and v.has("anims") and v.has("mult") and v.has("scales")):
				check("auto-attaque complète : %s" % wt, false)
	check("auto-attaque pour chaque type d'arme", GameData.weapon_types.keys().all(func(k): return WeaponAttacks.SPECS.has(k)))
	check("deux variantes par arme, chacune avec son effet légendaire", WeaponAttacks.SPECS.keys().all(func(k):
		return WeaponAttacks.variants(k).size() == 2 and WeaponAttacks.variants(k).all(func(v): return v.has("sig") and v.has("desc"))))
	# arme principale : toujours celle de la classe
	check("arme principale : type de la classe", String(player.auto_spec().wtype) == Items.default_weapon_type(Run.class_id))
	var foreign := Items.generate(1, 0.0, "weapon", Run.class_id, 0, "cannon" if Run.weapon_type() != "cannon" else "bow")
	Profile.inventory.append(foreign)
	Profile.equip(foreign)
	check("arme d'un autre type : équipée en secondaire", is_same(Profile.equipped.get("offhand"), foreign) and Profile.can_be_main(Profile.equipped.weapon))
	Profile.unequip("offhand")
	# améliorations d'arme : plus la carte est rare, plus elle a d'effets
	var spec := player.auto_spec()
	var up_c := WeaponAttacks.roll_upgrade(spec, "common", {})
	var up_r := WeaponAttacks.roll_upgrade(spec, "rare", {})
	var up_e := WeaponAttacks.roll_upgrade(spec, "epic", {})
	var up_l := WeaponAttacks.roll_upgrade(spec, "legendary", {})
	check("amélioration commune : dégâts seulement", up_c.keys() == ["dmg"])
	check("amélioration rare : dégâts + un bonus", up_r.size() == 2 and up_r.has("dmg"))
	check("amélioration épique : dégâts + deux bonus", up_e.size() >= 2 and up_e.has("dmg") and float(up_e.dmg) > float(up_r.dmg))
	check("amélioration légendaire : effet légendaire", up_l.get("sig", false))
	check("légendaire, effet déjà acquis : trois bonus", not WeaponAttacks.roll_upgrade(spec, "legendary", {"sig": true}).has("sig"))
	var bow_spec := WeaponAttacks.spec_for({"auto_variant": 0, "slot": "weapon"}, "bow")
	var crit_seen := 0
	for i in 60:
		if WeaponAttacks.roll_upgrade(bow_spec, "rare", {}).has("crit"):
			crit_seen += 1
	check("arc : le critique sort souvent sur une rare (%d / 60)" % crit_seen, crit_seen >= 20)
	var wcard := Run._describe_card({"type": "weapon_up", "id": "weapon", "tier": "legendary"})
	Run.apply_card(wcard)
	check("carte d'arme : niveau 1 et effet légendaire", int(Run.weapon_ups.weapon.rank) == 1 and Run.weapon_ups.weapon.get("sig", false))
	var a_up := WeaponAttacks.action_for(spec, player, player.weapon_mods("weapon"))
	var a_base := WeaponAttacks.action_for(spec, player)
	check("carte d'arme : auto-attaque plus forte", float(a_up.mult) > float(a_base.mult))
	check("cartes d'arme proposées", Run.roll_cards(3, false, "weapon").any(func(c): return String(c.type) == "weapon_up"))
	var bow_mods := {"sig": true}
	var volley := WeaponAttacks.action_for(bow_spec, player, bow_mods)
	check("arc, Volée : 4e flèche renforcée", not WeaponAttacks.empower(volley.duplicate(), bow_spec, bow_mods, 3) \
		and WeaponAttacks.empower(volley, bow_spec, bow_mods, 4) and int(volley.volley) == int(WeaponAttacks.action_for(bow_spec, player).volley) + 2)
	Run.weapon_ups = {}
	# arme secondaire trouvée en jeu : jamais du type de la classe
	var offers := SlotChests.offhand_offer(1, 1)
	check("arme secondaire : 3 armes d'autres types (%d)" % offers.size(), offers.size() == 3 \
		and offers.all(func(it): return Items.weapon_type_of(it) != Run.weapon_type() and it.has("auto_variant")))
	check("coffre d'arme : armes du type de la classe", SlotChests.offer("weapon", 1, 1).all(func(it): return Items.weapon_type_of(it) == Run.weapon_type()))
	# arme secondaire : frappe seule, à sa cadence
	var off := Items.generate(1, 0.0, "weapon", Run.class_id, 0, "bow")
	off["auto_variant"] = 0
	Profile.inventory.append(off)
	Profile.equip_offhand(off)
	player.recalc_stats()
	check("arme secondaire portée", not player.offhand_spec().is_empty() and String(player.offhand_spec().wtype) == "bow")
	var hp_o := m.hp
	player._off_ready_at = 0.0
	for i in 40:
		await get_tree().physics_frame
	check("arme secondaire : tire seule", m.hp < hp_o)
	Profile.unequip("offhand")
	player.recalc_stats()
	check("arme secondaire retirée", player.offhand_spec().is_empty())

	# zone et portée
	var sk: Dictionary = Run.class_data().skills[1]  # tourbillon (cercle)
	var r0 := player.skill_radius(sk)
	Run.apply_card(_common_card("wide_arc"))
	check("Lame large : rayon des zones +15 %", is_equal_approx(player.skill_radius(sk), r0 * 1.15))

	# procs : foudre en chaîne
	var pack: Array = [_dummy(3.0, 0.0), _dummy(4.5, 0.6), _dummy(6.0, -0.6)]
	var hp0 := pack.map(func(x): return x.hp)
	Procs.run(player, {"effect": "lightning", "mult": 1.0, "chain": 3, "radius": 7.0}, pack[0], pack[0].global_position)
	var struck := 0
	for i in pack.size():
		if pack[i].hp < hp0[i]:
			struck += 1
	check("foudre : rebondit sur les 3 monstres", struck == 3 and pack[1].has_status("shock"))
	# gel : immobilise et annule l'attaque annoncée
	Procs.run(player, {"effect": "freeze", "duration": 1.5, "radius": 2.0}, pack[2], pack[2].global_position)
	check("gel appliqué", pack[2].has_status("freeze") and pack[2].is_disabled())
	# explosion à la mort (Cadavres explosifs), avec recharge interne
	# l'or du monstre tué recalcule les stats (et donc les procs, venus des cartes et
	# de l'équipement) : on garde ici un proc de test injecté à la main
	Profile.changed.disconnect(player._on_profile_changed)
	player.procs = [{"id": "t_volatile", "trigger": "kill", "chance": 1.0, "cd": 0.0, "effect": "explosion", "mult": 0.5, "radius": 4.0}]
	var victim := _dummy(3.0, 0.0, 1.0)
	victim.xp_reward = 0  # pas de passage de niveau (il recalculerait les procs)
	var near_hp: float = pack[1].hp
	player.proc_hit(victim, 1.0)
	check("explosion à la mort touche les voisins", victim.is_dead and pack[1].hp < near_hp)
	Profile.changed.connect(player._on_profile_changed)
	# exécution des monstres normaux
	player.recalc_stats()
	player.execute = 0.2
	var weak := _dummy(2.0, 0.0, 1000.0)
	weak.hp = 150.0
	player._hit_monster(weak, Vector3.FORWARD, {"mult": 0.01}, false)
	check("Exécuteur : monstre faible exécuté", weak.is_dead)
	player.execute = 0.0
	# Écho : la compétence frappe une 2e fois
	var echo_target := _dummy(2.0, 0.0)
	player._last_skill = {"action": {"mult": 1.0, "radius": 4.0, "arc": 360.0, "kind": "spin"}, "pos": player.global_position, "fwd": player.forward()}
	var before := echo_target.hp
	player.echo_last_skill(0.6)
	await get_tree().create_timer(0.4).timeout
	check("Écho : seconde frappe", echo_target.hp < before)
	# buff temporaire d'un proc
	var spd := player.atk_speed
	Procs.run(player, {"effect": "buff", "status": "frenzy", "duration": 2.0}, null, player.global_position)
	check("Frénésie : +30 % de vitesse d'attaque", is_equal_approx(player.atk_speed, spd + 0.3))
	# déclencheur avec recharge interne
	player.procs = [{"id": "t_cd", "trigger": "dodge", "chance": 1.0, "cd": 5.0, "effect": "buff", "status": "haste", "duration": 1.0}]
	Procs.fire(player, "dodge")
	player.statuses.erase("haste")
	Procs.fire(player, "dodge")
	check("recharge interne respectée", not player.has_status("haste"))
	# trophées : buff sous condition (stats temporaires), double frappe
	for st in Trophies.STATUSES:
		player.statuses.erase(st)
	player.recalc_stats()
	var agi0 := float(player.attrs.agi)
	var crit0 := player.crit
	var tp := Trophies.proc_for("agi", Items.LEGENDARY)
	Procs.run(player, tp, null, player.global_position)
	check("trophée Vivacité : +%d %% d'Agilité pendant %d s" % [roundi(float(tp.stats.agi_pct) * 100), roundi(float(tp.duration))],
		player.has_status("t_agi") and float(player.attrs.agi) > agi0 * 1.2)
	var crit1 := player.crit
	var cd0 := player.crit_dmg
	Procs.run(player, Trophies.proc_for("crit", 3), null, player.global_position)
	check("trophée Instinct : critique et dégâts critiques", player.crit > crit1 + 0.1 and player.crit_dmg > cd0 + 0.2)
	player.statuses.erase("t_agi")
	player.statuses.erase("t_crit")
	player.recalc_stats()
	check("buffs de trophée retirés à la fin", is_equal_approx(float(player.attrs.agi), agi0) and is_equal_approx(player.crit, crit0))
	var dbl := _dummy(2.0, 0.0)
	var hp_before := dbl.hp
	Procs.run(player, Trophies.proc_for("double", 2), dbl, dbl.global_position)
	check("trophée Double frappe : coup supplémentaire", dbl.hp < hp_before)
	check("rareté : buff plus fort sur un légendaire", float(Trophies.proc_for("agi", Items.LEGENDARY).stats.agi_pct) > float(Trophies.proc_for("agi", 2).stats.agi_pct)
		and float(Trophies.proc_for("agi", Items.LEGENDARY).chance) > float(Trophies.proc_for("agi", 0).chance))
	Run.passives.clear()
	player.recalc_stats()
	await _test_card_tiers()
	world.queue_free()


func _wait_idle() -> void:
	for i in 120:
		await get_tree().physics_frame
		if player._state == "idle":
			return


## Monstre immobile et inoffensif à [param dist] m devant le héros.
func _dummy(dist: float, side := 0.0, hp := 1e7) -> Monster:
	var id: int = world.director._pick_monster(1)
	var fwd := player.forward()
	var pos := player.global_position + fwd * dist + fwd.cross(Vector3.UP) * side * dist
	var m: Monster = world.director._spawn_monster(id, pos, 1)
	m.max_hp = hp
	m.hp = hp
	m.set_physics_process(false)
	m.set_process(false)
	return m


## Cartes à rareté, 10 niveaux, totaux cumulés, sorts améliorés, orbes d'expérience.
## Profils types : objet +10 (paliers, gemmes, enchantement) et application au héros.
func _test_profile_apply() -> void:
	var was_in_run := Profile.in_run
	Profile.in_run = false
	var saved := {"vault": Profile.vault.duplicate(), "class": Profile.selected_class, "board": Profile.cert_board.duplicate(),
		"outfits": Profile.outfits.duplicate(true), "worn": Profile.worn.duplicate(true), "loadout": Profile.loadout.duplicate(), "presets": Profile.presets.duplicate(true),
		"equipped": Profile.equipped.duplicate(), "inventory": Profile.inventory.duplicate(), "certs": Profile.certificates.duplicate(), "talents": Profile.talents.duplicate(true), "collection": Profile.collection.duplicate()}
	var b := RivalBuilds.blank("magician", 45)
	RivalBuilds.auto_fill(b)
	b.gear.weapon["upgrade"] = 10
	b.gear.weapon["rolls"] = {"4": "matk", "6": "crit", "8": "matk", "10": "int"}
	b.gear.weapon["gems"] = [Craft.gem_key("sapphire", 4), ""]
	b.gear.weapon["enchant"] = Craft.scroll_key("optimize", 4)
	var t0 := str(int(GameData.talents.magician.rows[0][0].id))
	b["talents"] = {t0: 3}
	b.look["aura"] = int(GameData.auras[0].id)
	b.look["aura_tint"] = [70, 170, 255]
	var w := RivalBuilds.make_item("weapon", b.gear.weapon, 45)
	var ok_item: bool = int(w.upgrade) == 10 and (w.up_rolls as Array).size() == 4 and (w.sockets as Array)[0] is Dictionary and w.has("enchant")
	var msg := RivalBuilds.apply_to_hero(b)
	var eq: Dictionary = Profile.equipped.get("weapon", {})
	check("profil type : arme +10 (4 paliers, gemme, enchantement) appliquée au héros (%s)" % msg,
		ok_item and Profile.selected_class == "magician" and int(eq.get("upgrade", 0)) == 10 and Profile.equipped.size() >= 8
		and not SpellPresets.active("magician").is_empty() and Profile.cert_board.has("magician/" + String(GameData.talents.magician.certificates[0])))
	check("profil type : maîtrise, aura et sa teinture appliquées", int(Profile.talents.get("magician", {}).get(t0, 0)) == 3
		and Profile.aura_tint("magician").a > 0.0 and not Profile.worn_auras("magician").is_empty())
	SpellPresets.remove("magician", SpellPresets.active_index("magician"))
	Profile.vault = saved.vault
	Profile.selected_class = saved["class"]
	Profile.cert_board = saved.board
	Profile.certificates = saved.certs
	Profile.talents = saved.talents
	Profile.collection = saved.collection
	Profile.outfits = saved.outfits
	Profile.worn = saved.worn
	Profile.presets = saved.presets
	Profile.loadout = saved.loadout
	Profile.equipped = saved.equipped
	Profile.inventory = saved.inventory
	Profile.in_run = was_in_run
	if not was_in_run:
		Profile._lobby_view()
	Profile.save_profile()  # la sauvegarde de test redevient celle d'avant


## Duel : 12 sorts de l'adversaire (4 cases × principal et 2 enchaînements).
func _test_rival_spells() -> void:
	var cid := "magician"
	var all: Array = GameData.class_data(cid).get("skills", [])
	if all.size() < 12:
		return
	var grid := Duel.grid12([])
	grid[0] = int(all[11].id)  # case 1 : le 12e sort en principal
	grid[1] = int(all[10].id)  # puis le 11e en enchaînement
	grid[5] = int(all[9].id)  # case 2, 2e enchaînement
	var kit := Duel.kit_from_grid(cid, grid)
	var ok_kit: bool = kit.skills.size() == 4 and int(kit.skills[0].id) == int(all[11].id) and int(kit.chains[0][0].id) == int(all[10].id) \
		and kit.chains[1].size() == 1 and int(kit.chains[1][0].id) == int(all[9].id)
	var full := Duel.grid12([])
	for i in 12:
		full[i] = int(all[i].id)
	var scripted := Duel.scripted_spells(cid, full)
	var old := Duel.grid12([int(all[3].id), 0, 0, 0])
	check("duel : 12 sorts de l'adversaire (cerveau %s, scripté %d sorts, ancien réglage à 4 sorts lu)" % [ok_kit, scripted.size()],
		ok_kit and scripted.size() > 4 and int(old[0]) == int(all[3].id) and old.size() == 12)


## Mode dev : ressources illimitées, puis rendues telles qu'avant.
func _test_dev_unlimited() -> void:
	var dev_was := bool(Settings.get_v("interface", "dev_mode"))
	Settings.data["interface"]["dev_mode"] = true
	var c0 := Profile.amount("crystal")
	var gem := Craft.gem_key(Craft.GEMS.keys()[0], 0)
	var g0 := int(Profile.stash.get(gem, 0))
	Profile.set_unlimited(true)
	var full := Profile.amount("crystal") >= Profile.UNLIMITED and int(Profile.stash.get(gem, 0)) >= Profile.UNLIMITED_SUPPLY
	Profile.pay({"crystal": 1000})
	Profile._refill()
	var still := Profile.amount("crystal") >= Profile.UNLIMITED
	Profile.set_unlimited(false)
	check("mode dev : ressources illimitées (pleines, toujours pleines après un achat), rendues ensuite",
		full and still and Profile.amount("crystal") == c0 and int(Profile.stash.get(gem, 0)) == g0)
	Settings.data["interface"]["dev_mode"] = dev_was


## Forge et démontage hors run : fournitures de la réserve, cristaux à la place de l'or.
func _test_forge_lobby() -> void:
	var was_in_run := Profile.in_run
	Profile.in_run = false
	var saved_vault: Array = Profile.vault.duplicate()
	var saved_stash: Dictionary = Profile.stash.duplicate()
	var saved_crystal := Profile.amount("crystal")
	var it := Items.generate(10, 0.0, "chest", Profile.selected_class, 1, "", 1)
	Profile.inventory.append(it)
	var scroll := Craft.fortify_key(Craft.fortify_kind(it), Craft.fortify_level_for(it))
	Profile.stash[scroll] = 3
	Profile.set_amount("crystal", 500)
	var cost := Forge.price(int(Items.upgrade_cost(it).gold))
	Profile.bag = Profile.stash  # comme la forge du lobby
	var r := Profile.upgrade_item(it)
	Profile.bag = {}
	check("forge hors run : payée en cristaux (%s), parchemin pris dans la réserve (%s)" % [cost, r.get("text", "")],
		cost.has("crystal") and not r.get("error", false) and Profile.amount("crystal") == 500 - int(cost.crystal) and int(Profile.stash.get(scroll, 0)) == 2)
	var c0 := Profile.amount("crystal")
	Profile.disassemble(it)
	check("démontage hors run : l'objet quitte le coffre commun, cristaux gagnés", not Profile.vault.any(func(x): return is_same(x, it)) and Profile.amount("crystal") > c0)
	Profile.vault = saved_vault
	Profile.stash = saved_stash
	Profile.set_amount("crystal", saved_crystal)
	Profile.in_run = was_in_run
	if not was_in_run:
		Profile._lobby_view()


## Presets de sorts : les sorts pris se rangent dans les cases et enchaînements du preset.
func _test_spell_presets() -> void:
	var saved_skills: Array = Run.skills.duplicate(true)
	var saved_chains: Dictionary = Run.chains.duplicate(true)
	var cid := Run.class_id
	var cl: Array = Run.class_data().get("skills", [])
	if cl.size() < 6:
		return
	var ids: Array = cl.map(func(x): return int(x.id))
	# preset : case 1 = sort 3 (enchaîne sort 5), case 2 = sort 1, case 3 = sort 2, case 4 = sort 4
	var cols := SpellPresets.empty_cols()
	cols[0][0] = ids[2]
	cols[0][1] = ids[4]
	cols[1][0] = ids[0]
	cols[2][0] = ids[1]
	cols[3][0] = ids[3]
	var before_active := SpellPresets.active_index(cid)
	var n_before := SpellPresets.list(cid).size()
	SpellPresets.store(cid, "__test__", cols)
	Run.skills = []
	Run.chains = {}
	# obtenus dans le désordre : sort 5 d'abord (il prend une case en attendant), puis 1, 2, 3, 4
	for i in [4, 0, 1, 2, 3]:
		Run.apply_card({"type": "skill", "id": ids[i]})
	var mains: Array = Run.skills.map(func(e): return int(e.id))
	check("preset de sorts : cases dans l'ordre du preset %s" % [mains], mains == [ids[2], ids[0], ids[1], ids[3]])
	check("preset de sorts : enchaînement sous sa case", Run.chain_of(0).size() == 1 and int(Run.chain_of(0)[0].id) == ids[4])
	SpellPresets.remove(cid, SpellPresets.list(cid).size() - 1)
	SpellPresets.set_active(cid, before_active if before_active < n_before else -1)
	Run.skills = saved_skills
	Run.chains = saved_chains


func _test_card_tiers() -> void:
	Run.passives.clear()
	Run.passive_power.clear()
	var c := _common_card("sharpened")
	c["tier"] = "legendary"
	c["mult"] = Cards.tier_mult("legendary")
	Run.apply_card(c)
	check("carte légendaire : ×3 (+24 % de dégâts)", is_equal_approx(float(Run.passive_stats().get("dmg_pct", 0.0)), 0.24))
	var next := Run._describe_card({"type": "passive", "id": "sharpened"})
	check("carte suivante : total avant → après (« +24 % → »)", String(next.desc).contains("+24 % →") and String(next.subtitle).contains("niv. 1 → 2"))
	for i in 9:
		Run.apply_card(_common_card("sharpened"))
	check("passif au niveau 10 : plus proposé", Run.roll_cards(3).all(func(x): return str(x.id) != "sharpened") and int(Run.passives.sharpened) == 10)
	# cartes communes et cartes de classe
	check("passifs communs dans les cartes (Corps aguerri, Saut aérien)", not Boons.get_def("vigor").is_empty() and not Boons.get_def("air_jump").is_empty())
	check("la classe ne garde que ses certificats", GameData.class_data(Run.class_id).get("passives", []).all(func(p): return p.has("eden")))
	var ccs := Cards.class_cards(Run.class_id)
	var sk0: Dictionary = GameData.class_data(Run.class_id).skills[0]
	check("cartes de classe : %d pour %d sorts" % [ccs.size(), GameData.class_data(Run.class_id).skills.size()], ccs.size() >= GameData.class_data(Run.class_id).skills.size() * 2)
	var pow_id := "sk%d_pow" % int(sk0.id)
	var had := Run.skills.any(func(x): return int(x.id) == int(sk0.id))
	if not had:
		Run.skills.append({"id": int(sk0.id), "rank": 1})
	var seen := false
	for i in 200:
		if Run.roll_cards(3).any(func(x): return str(x.id).begins_with("sk%d_" % int(sk0.id))):
			seen = true
			break
	check("carte de sort proposée une fois le sort pris", seen)
	var dm0 := Run.skill_damage_mult(int(sk0.id))
	Run.passives[pow_id] = 1
	Run.passive_power[pow_id] = 1.0
	check("carte « %s » : +20 %% de dégâts du sort (%.2f → %.2f)" % [Cards.class_card(Run.class_id, pow_id).get("name", "?"), dm0, Run.skill_damage_mult(int(sk0.id))],
		is_equal_approx(Run.skill_damage_mult(int(sk0.id)), dm0 * 1.2) or (String(sk0.kind) in ["heal", "buff"]))
	Run.passives.erase(pow_id)
	Run.passive_power.erase(pow_id)
	if not had:
		Run.skills = Run.skills.filter(func(x): return int(x.id) != int(sk0.id))
	# enchaînements : cases pleines, les autres sorts se proposent en suite de case
	var sk_saved: Array = Run.skills.duplicate(true)
	var ch_saved: Dictionary = Run.chains.duplicate(true)
	var cl: Array = Run.class_data().get("skills", [])
	Run.skills = []
	Run.chains = {}
	for i in mini(4, cl.size()):
		Run.skills.append({"id": int(cl[i].id), "rank": 1})
	var saw_chain := false
	var exp_saved: Dictionary = Profile.expertise.duplicate()
	Profile.set_expertise_level(Run.class_id, Profile.EXPERTISE_MAX)
	for i in 60:
		for cc in Run.roll_cards(3):
			if String(cc.type) == "chain":
				saw_chain = true
				Run.apply_card(cc)
	check("cases pleines : cartes d'enchaînement, %d sorts en tout (12 au plus)" % Run.all_skills().size(), saw_chain and Run.all_skills().size() > 4 and Run.all_skills().size() <= 12 and Run.chains.values().all(func(x): return x.size() <= 2))
	var first_chain: int = int(Run.chains.keys()[0]) if not Run.chains.is_empty() else 0
	var cid0 := int(Run.chains.get(first_chain, [{"id": 0}])[0].id)
	Run.remove_skill(int(Run.skills[first_chain].id))
	check("sort principal retiré : ses enchaînements partent avec lui", Run.skill_entry(cid0).is_empty())
	Run.skills = sk_saved
	Run.chains = ch_saved
	Profile.expertise = exp_saved
	# butin plafonné au niveau du héros de la run (première zone)
	var hl0 := Run.hero_level
	var zid0 := Run.zone_id
	Run.zone_id = String(GameData.zones[0].id)
	Run.hero_level = 5
	var over: Array = []
	for i in 120:
		var it := Items.generate(15, 0.3, "", Run.class_id, 0, "", 3)
		if int(it.level) > 5 and it.slot != "trophy":
			over.append("%s %s niv %d" % [it.slot, it.get("wtype", ""), int(it.level)])
	check("butin au niveau 5 du héros : aucun objet au-dessus du niveau 5 (%s)" % ", ".join(over.slice(0, 4)), over.is_empty())
	Run.hero_level = hl0
	Run.zone_id = zid0
	# certificats : ceux posés sont acquis, les autres tombent en run comme des cartes
	var own_certs: Array = GameData.talents.get(Run.class_id, {}).get("certificates", [])
	if not own_certs.is_empty():
		var key := "%s/%s" % [Run.class_id, own_certs[0]]
		var saved_certs: Array = Profile.certificates.duplicate()
		Profile.certificates = []
		check("certificat non posé : dans le tirage des cartes", Run.certificate_pool().any(func(d): return d.cert == key))
		Profile.certificates = [key]
		check("certificat posé : plus dans le tirage", not Run.certificate_pool().any(func(d): return d.cert == key))
		Profile.certificates = saved_certs
		var cd := Run.passive_def("cert:" + key)
		var st0 := Run.passive_stats().duplicate()
		Run.passives["cert:" + key] = 1
		Run.passive_power["cert:" + key] = 1.0
		var sk := String(cd.get("stat", {}).keys()[0]) if not (cd.get("stat", {}) as Dictionary).is_empty() else ""
		check("certificat « %s » pris en run : son bonus s'applique" % cd.get("name", "?"), sk == "" or float(Run.passive_stats().get(sk, 0.0)) > float(st0.get(sk, 0.0)))
		Run.passives.erase("cert:" + key)
		Run.passive_power.erase("cert:" + key)
	check("cartes de sort : seulement celles de la classe jouée", Cards.class_cards(Run.class_id).all(func(d): return d["class"] == Run.class_id))
	# sort de soin amélioré : plus de soins, pas seulement moins de recharge
	var heal_skill := {"id": 9001, "kind": "heal", "heal": 0.3, "cooldown": 10}
	var up := Cards.skill_upgrade(heal_skill, "epic")
	check("amélioration d'un sort de soin : +33 % de soins et -11 % de recharge (épique)", is_equal_approx(float(up.heal), 0.33) and is_equal_approx(float(up.cd), 0.11) and not up.has("dmg"))
	Run.skills.append({"id": 9001, "rank": 1})
	up["rider"] = {"stat": "int", "value": 0.2, "duration": 6.0}
	Run.apply_card({"type": "upgrade", "id": 9001, "up": up})
	check("sort amélioré : soins x1,33, bonus d'Intelligence au lancement", is_equal_approx(Run.skill_heal_mult(9001), 1.33) and Run.skill_riders(9001).size() == 1 and int(Run.skill_entry(9001).rank) == 2)
	Run.skills.pop_back()
	# effets sur la durée plus longs (Venin tenace)
	Run.apply_card(_common_card("lingering"))
	player.recalc_stats()
	var mob := Monster.new()
	mob.configure(GameData.monster(GameData.zone("limestone").monsters[0]))
	add_child(mob)
	mob.add_status("poison", 4.0, player)
	check("Venin tenace : poison 4 s -> 4,6 s", is_equal_approx(float(mob.statuses.poison) - mob.clock, 4.6))
	mob.queue_free()
	# orbes d'expérience : lâchées au sol, ramassées dans la zone de collecte, Rappel
	var orbs := XpOrbs.new()
	add_child(orbs)
	var xp0 := player.xp
	var lvl0 := player.level
	orbs.spawn(player.global_position + Vector3(30, 0, 0), 5.0)
	orbs.spawn(player.global_position + Vector3(1, 0, 0), 5.0)
	player.autoplay = false
	await get_tree().create_timer(0.6).timeout
	check("orbe proche ramassée, orbe lointaine restée au sol", orbs.count() == 1 and (player.xp > xp0 or player.level > lvl0))
	orbs.recall()
	await get_tree().create_timer(1.5).timeout
	check("Rappel : l'orbe lointaine revient", orbs.count() == 0)
	orbs.queue_free()
	Run.passives.clear()
	Run.passive_power.clear()
	player.recalc_stats()


## Équipement : puissance qui suit le héros (plafonnée), stats fixes, coffres seuls à donner
## les mythiques et légendaires.
func _test_gear_rules() -> void:
	var e23: Dictionary = GameData.eden_items.filter(func(x): return int(x.level) == 23 and x.slot == "chest")[0]
	var e90: Dictionary = GameData.eden_items.filter(func(x): return int(x.level) >= 85 and x.slot == "chest")[0]
	var a := Items.from_template(e23, 1)
	var b := Items.from_template(e90, 1)
	Run.hero_level = 10
	check("niveau du héros 10 : objet 23 et objet 90 à la puissance 10", Items.power_level(a) == 10 and Items.power_level(b) == 10)
	Run.hero_level = 30
	check("niveau 30 : l'objet 23 plafonne à 23, l'objet 90 suit (30)", Items.power_level(a) == 23 and Items.power_level(b) == 30)
	Run.hero_level = 1
	var c1 := Items.from_template(e23, 1, 2)
	var c2 := Items.from_template(e23, 1, 2)
	check("stats fixes : deux exemplaires ont les mêmes stats de base (seule la qualité varie)", str(c1.base) == str(c2.base))
	var ch := Rewards.make("gear", 20)
	Profile.reward_chests.append(ch)
	var got := Rewards.open(ch)
	check("coffre d'équipement : mythique ou légendaire", int(got.items[0].rarity) >= Items.MYTHIC)
	check("butin des monstres : jamais mythique ni légendaire", range(300).all(func(_i): return int(Items.generate(10, 0.9).rarity) <= 3))
	# trophées de build : chaque famille a un texte lisible ; esquive -> onde
	var bad: Array = Trophies.KINDS.keys().filter(func(k): return Trophies.describe(Trophies.proc_for(k, 3)).strip_edges() == "" or Trophies.describe(Trophies.proc_for(k, 3)).contains("%d"))
	check("%d familles de trophées, toutes décrites (sans texte : %s)" % [Trophies.KINDS.size(), bad], Trophies.KINDS.size() >= 30 and bad.is_empty())
	check("trophée Onde d'esquive : se déclenche en esquivant", String(Trophies.proc_for("dodge_wave", 3).trigger) == "dodge")


## Bannir et garder des cartes pendant le choix.
func _test_ban_keep() -> void:
	Run.banned.clear()
	Run.kept.clear()
	Run.bans_used = 0
	Run.locks_used = 0
	var shown: Array = [Run._describe_card({"type": "passive", "id": "sharpened"})]
	var rep := Run.ban_card(shown[0], shown)
	check("bannir : carte remplacée, plus jamais proposée", not rep.is_empty() and str(rep.id) != "sharpened"
		and range(100).all(func(_i): return Run.roll_cards(3).all(func(x): return str(x.id) != "sharpened")))
	var k := Run._describe_card({"type": "passive", "id": "long_reach"})
	k["tier"] = "epic"
	check("garder : la carte revient au choix suivant avec sa rareté", Run.keep_card(k) and Run.roll_cards(3).any(func(x): return str(x.id) == "long_reach" and String(x.tier) == "epic"))
	Run.banned.clear()


## Carte de passif tirée en rareté commune (puissance +1), pour des tests déterministes.
func _common_card(id: String) -> Dictionary:
	var c := Run._describe_card({"type": "passive", "id": id})
	c["tier"] = "common"
	c["mult"] = 1.0
	return c
