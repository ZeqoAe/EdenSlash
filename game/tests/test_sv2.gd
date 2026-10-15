extends Node
## Lot S2 du Survivant (conception/survivor, DECISIONS_JOUEUR §1-§3) : pool des sets de niveau 90, stats d'origine,
## qualité 100 à 120 %, passif fixe sans doublon dans un set, 4 passifs distincts à +10 (passif tiré à la proposition),
## verrouillage à vie, bonus de set 2 / 3 / 5 en Survivant seulement, armes des 17 types, hub intact, fréquence du 5/5 :
## godot --headless --path game res://tests/test_sv2.tscn

var fails := 0


func check(label: String, ok: bool) -> void:
	print(("OK    " if ok else "ÉCHEC ") + label)
	if not ok:
		fails += 1


func _ready() -> void:
	Settings.reset_all()
	Profile.selected_class = "warrior"
	Profile.reset_all()
	Profile.in_run = false
	Profile.save_profile()
	var hub := _hub()
	_pool()
	_fixed_table()
	Survivor.start("warrior", "limestone")
	_pieces()
	_tiers()
	_lock()
	_sets()
	_weapons()
	Run.finish("abandon")
	Profile.end_run_survival()
	check("hub intact après la run (coffre, préréglages, loadout, équipement porté)", _hub() == hub)
	_frequency()  # (après la run : la simulation joue ses propres runs)
	check("hub intact après les runs simulées", _hub() == hub)
	check("noms des sets sans nom propre : la fin commune des pièces (%s, %s)" % [SurvivorPool.panoply_name("e447"), SurvivorPool.panoply_name("e448")],
		SurvivorPool.sets().all(func(x): return not SurvivorPool.panoply_name(String(x)).right(1).is_valid_int()))
	check("hors Survivant : les sets d'Eden gardent leurs paliers d'origine", not Items.set_def("e340").get("sv", false)
		and Items.set_bonus("e340", 5).has("eden"))
	print("\n%s (%d échec(s))" % ["TOUT EST OK" if fails == 0 else "ÉCHECS", fails])
	Profile.reset_all()
	get_tree().quit(1 if fails > 0 else 0)


func _hub() -> String:
	var eq := {}
	for s in Profile.equipped:
		eq[s] = String(Profile.equipped[s].get("uid", ""))
	return JSON.stringify([Profile.vault.map(func(it): return String(it.get("uid", ""))), Profile.loadout, Profile.presets, eq], "", true)


# --- pool ---------------------------------------------------------------------------------------------------------------
func _pool() -> void:
	var sm := SurvivorPool.summary()
	print("   pool : %s" % sm)
	check("13 sets de niveau 90 (%d)" % int(sm.sets), int(sm.sets) == 13)
	var all5 := true
	for sid in SurvivorPool.sets():
		var ps := SurvivorPool.set_pieces(String(sid))
		all5 = all5 and ps.size() == 5 and ps.all(func(e): return int(e.level) == 90)
	check("chaque set : 5 pièces de niveau 90 (tête, torse, jambes, gants, bottes)", all5
		and SurvivorPool.set_slots().size() == 5 and SurvivorPool.set_slots().all(func(s): return s in SurvivorPool.SET_SLOT_ORDER))
	var acc := true
	for slot in ["back", "necklace", "ring"]:
		acc = acc and SurvivorPool.pieces(slot).size() >= 3 and SurvivorPool.pieces(slot).all(func(e): return int(e.level) == 90 and not e.has("set"))
	check("8 emplacements hors arme ont des pièces (cape, collier, bague : hors set, niveau 90)", SurvivorPool.slots().size() == 8 and acc)
	check("trois types d'armure (plates, cuir, tissu)", (sm.armors as Dictionary).size() == 3)
	check("17 types d'arme, chacun avec des modèles", SurvivorPool.weapon_types().size() == 17
		and SurvivorPool.weapon_types().all(func(w): return not SurvivorPool.weapons(String(w)).is_empty()))
	var reusable := true
	for id in Cards.passive_effects():
		var d := Boons.get_def(String(id))
		reusable = reusable and not d.get("instant", false) and (d.get("requires", []) as Array).is_empty()
	check("passifs réutilisables : effets des cartes communes (%d)" % Cards.passive_effects().size(), Cards.passive_effects().size() >= 30 and reusable)


func _fixed_table() -> void:
	var dup := 0
	var bad := 0
	print("   table des passifs fixes (set : tête, torse, jambes, gants, bottes)")
	for sid in SurvivorPool.sets():
		var ids: Array = SurvivorPool.set_pieces(String(sid)).map(func(e): return SurvivorGear.fixed_passive(e))
		var seen := {}
		for id in ids:
			if seen.has(id):
				dup += 1
			seen[id] = true
			if not id in Cards.passive_effects():
				bad += 1
		print("   %s %-26s %-6s %-4s %s" % [sid, SurvivorPool.panoply_name(String(sid)), SurvivorPool.armor_of(String(sid)), SurvivorPool.family(String(sid)), ", ".join(ids)])
	check("passif fixe : aucun doublon dans un set (13 sets)", dup == 0)
	check("passif fixe : toujours un effet des cartes communes", bad == 0)
	var stable := true
	for sid in SurvivorPool.sets():
		for e in SurvivorPool.set_pieces(String(sid)):
			stable = stable and SurvivorGear.fixed_passive(e) == SurvivorGear.fixed_passive(e.duplicate())
	check("passif fixe : déterministe", stable)
	var others := true
	for slot in ["back", "necklace", "ring"]:
		for e in SurvivorPool.pieces(slot):
			others = others and SurvivorGear.fixed_passive(e) in Cards.passive_effects()
	for w in SurvivorPool.weapon_types():
		for e in SurvivorPool.weapons(String(w)):
			others = others and SurvivorGear.fixed_passive(e) in Cards.passive_effects()
	check("accessoires et armes : un passif fixe chacun", others)


# --- pièces : stats d'origine, qualité --------------------------------------------------------------------------------
func _pieces() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var ok_base := true
	var ok_q := true
	var ok_aff := true
	var qs := {}
	for slot in SurvivorPool.slots():
		for e in SurvivorPool.pieces(slot):
			for k in 3:
				var it := SurvivorGear.from_eden(e, rng)
				var ref := Items.from_template(e, 1, int(e.rarity))
				ok_base = ok_base and JSON.stringify(it.base) == JSON.stringify(ref.base) and int(it.rarity) == int(e.rarity)
				ok_q = ok_q and float(it.quality) >= 1.0 - 0.0001 and float(it.quality) <= 1.2 + 0.0001
				ok_aff = ok_aff and (it.affixes as Dictionary).is_empty() and not it.has("passive") and it.sv
				qs[roundi(float(it.quality) * 100.0)] = true
	check("stats d'origine : base = celle de la pièce d'Eden (rareté d'Eden), sans affixe ni passif d'Eden", ok_base and ok_aff)
	check("qualité de 100 à 120 %", ok_q)
	check("qualité : 100 %% et le jet parfait 120 %% sortent (%d valeurs)" % qs.size(), qs.has(100) and qs.has(120) and qs.size() >= 15)
	var it := SurvivorGear.make_piece("chest", {"rng": rng})
	it.quality = 1.2
	check("jet parfait reconnu (120 %)", SurvivorGear.is_perfect(it) and not SurvivorGear.is_perfect({"quality": 1.19}))
	Run.hero_level = 37
	check("puissance = niveau du héros (37)", Items.power_level(it) == 37)
	var st37 := Items.stats(it)
	Run.hero_level = 150
	check("puissance plafonnée à 90", Items.power_level(it) == 90)
	Run.hero_level = 37
	it.quality = 1.0
	var st100 := Items.stats(it, false)
	it.quality = 1.1
	var st110 := Items.stats(it, false)
	var k := "hp" if st100.has("hp") else String(st100.keys()[0])
	check("qualité : 110 %% = stats ×1,1 (%s %.1f → %.1f)" % [k, float(st100[k]), float(st110[k])], absf(float(st110[k]) / float(st100[k]) - 1.1) < 0.001)
	check("carte de la pièce lisible, avec son passif (Items.describe)", Items.describe(it).length() > 50 and not st37.is_empty()
		and Items.describe(it).contains("✶ " + Cards.effect_line(String(it.sv_passives[0].id))))
	check("pièce de set : garde son set d'Eden", SurvivorPool.sets().has(String(SurvivorGear.make_piece("head", {"rng": rng}).get("set", ""))))
	check("pièce hors set (bague) : pas de set", not SurvivorGear.make_piece("ring", {"rng": rng}).has("set"))
	var offers := SurvivorGear.piece_offers("legs", 3, {"rng": rng})
	var sets_in: Array = offers.map(func(o): return String(o.item.get("set", "")))
	check("offre de 3 pièces : 3 sets différents (%s)" % [sets_in], offers.size() == 3 and sets_in[0] != sets_in[1] and sets_in[1] != sets_in[2] and sets_in[0] != sets_in[2]
		and offers.all(func(o): return o.type == "sv_piece" and o.slot == "legs"))
	var none := SurvivorGear.piece_offers("legs", 3, {"rng": rng, "banned": SurvivorPool.sets().slice(0, 12)})
	check("set banni jamais proposé (12 bannis : 1 seule pièce possible)", none.size() == 1 and String(none[0].item.set) == String(SurvivorPool.sets()[12]))


# --- passifs de palier ------------------------------------------------------------------------------------------------
func _tiers() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var four := true
	var shown_is_applied := true
	var fixed_kept := true
	var woke_ok := true
	for i in 120:
		Run.passives.clear()
		Run.passive_power.clear()
		Profile.equipped.erase("gloves")
		var it := SurvivorGear.make_piece("gloves", {"rng": rng})
		var fixed := String(it.sv_passives[0].id)
		SurvivorGear.equip(it)
		var woke := 0
		while int(it.upgrade) < 10:
			var offer := SurvivorGear.upgrade_offer("gloves", "rare", rng)
			var shown: Array = (offer.passives as Array).map(func(p): return String(p.id))
			var res := SurvivorGear.apply_upgrade(offer)
			woke += int(res.woke)
			var now := SurvivorGear.passives_of(it)
			for id in shown:
				shown_is_applied = shown_is_applied and id in now
		var ids := SurvivorGear.passives_of(it)
		var uniq := {}
		for id in ids:
			uniq[id] = true
		four = four and ids.size() == 4 and uniq.size() == 4
		fixed_kept = fixed_kept and ids[0] == fixed
		woke_ok = woke_ok and woke == 3 and (it.sv_passives as Array).map(func(p): return int(p.at)) == [0, 6, 8, 10]
	check("pièce +10 : 4 passifs distincts (fixe + +6, +8, +10), 120 essais", four)
	check("le passif fixe reste le premier", fixed_kept)
	check("paliers à +6, +8, +10 (cartes +2 : 3 passifs gagnés)", woke_ok)
	check("le passif affiché sur l'offre est celui appliqué", shown_is_applied)
	# offre tirée à la proposition, puis relance : une autre offre, la pièce ne bouge pas tant qu'on ne prend pas
	Profile.equipped.erase("boots")
	var b := SurvivorGear.make_piece("boots", {"rng": rng})
	SurvivorGear.equip(b)
	b.upgrade = 4
	var o1 := SurvivorGear.upgrade_offer("boots", "common", rng)
	check("offre vers +6 : porte un passif tiré (%s)" % [o1.passives], (o1.passives as Array).size() == 1 and int(o1.passives[0].at) == 6
		and not String(o1.passives[0].id) in SurvivorGear.passives_of(b) and o1.to == 6)
	check("proposer ne change rien à la pièce", int(b.upgrade) == 4 and SurvivorGear.passives_of(b).size() == 1)
	var o2 := SurvivorGear.upgrade_offer("boots", "legendary", rng, 4)
	check("offre +4 (6 → … ) franchissant +6 et +8 : deux passifs distincts", (o2.passives as Array).size() == 2 and o2.passives[0].id != o2.passives[1].id
		and is_equal_approx(float(o2.passives[0].power), Cards.tier_mult("legendary")))
	SurvivorGear.apply_upgrade(o1)
	check("offre périmée refusée (la pièce a changé)", SurvivorGear.apply_upgrade(o2).text == "" and int(b.upgrade) == 6)
	var never_own := true
	for i in 200:
		never_own = never_own and not SurvivorGear.roll_tier_passive(b, 8, rng) in SurvivorGear.passives_of(b)
	check("roll_tier_passive : jamais un passif de la pièce", never_own)
	check("roll_tier_passive : palier invalide -> rien", SurvivorGear.roll_tier_passive(b, 7, rng) == "")
	# cumul dans la run et plafond
	Run.passives.clear()
	Run.passive_power.clear()
	for i in 9:
		SurvivorGear._grant("multishot", 1.0)
		SurvivorGear._grant("sharpened", 1.0)
	check("passifs cumulés dans la run (Fil aiguisé ×9 = %.1f)" % Run.power("sharpened"), is_equal_approx(Run.power("sharpened"), 9.0)
		and is_equal_approx(float(Run.passive_stats().get("dmg_pct", 0.0)), 0.72))
	check("plafond par passif (Projectile supplémentaire : %.1f, plafond %d)" % [Run.power("multishot"), int(SurvivorGear.boon_cap("multishot"))], is_equal_approx(Run.power("multishot"), 5.0))
	check("textes des passifs en français", SurvivorGear.passive_lines(b).size() == 2 and SurvivorGear.passive_lines(b)[1].begins_with("+6 · "))


# --- verrouillage -----------------------------------------------------------------------------------------------------
func _lock() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	Profile.equipped.erase("head")
	var a := SurvivorGear.make_piece("head", {"rng": rng})
	var b := SurvivorGear.make_piece("head", {"rng": rng})
	check("pose dans un emplacement libre", SurvivorGear.equip(a) and is_same(Profile.equipped.head, a))
	check("emplacement verrouillé : une 2e pièce est refusée", not SurvivorGear.equip(b) and is_same(Profile.equipped.head, a))
	check("verrou visible (locked, item_locked, carte de la pièce)", SurvivorGear.locked("head") and SurvivorGear.item_locked(a) and not SurvivorGear.locked("ring")
		and Items.describe(a).contains(SurvivorGear.LOCK_TEXT) and not Items.describe(b).contains(SurvivorGear.LOCK_TEXT))
	Profile.inventory.append(b)
	Profile.equip(b)
	check("Profile.equip refusé sur un emplacement verrouillé", is_same(Profile.equipped.head, a) and b in Profile.inventory)
	Profile.unequip("head")
	check("Profile.unequip refusé", is_same(Profile.equipped.head, a))
	Profile.inventory.erase(b)
	check("pas de remplacement dans les emplacements libres", "ring" in SurvivorGear.free_slots() and not "head" in SurvivorGear.free_slots())
	# page d'inventaire de la pause : bouton « Gardée toute la run » désactivé
	var page = load("res://scripts/ui/inventory_page.gd")
	check("page d'inventaire : garde-fou présent", page != null and FileAccess.get_file_as_string("res://scripts/ui/inventory_page.gd").contains("SurvivorGear.locked"))


# --- bonus de set -------------------------------------------------------------------------------------------------------
func _sets() -> void:
	var all_ok := true
	for sid in SurvivorPool.sets():
		var t := Items.set_tiers(String(sid))
		var five := Items.set_bonus(String(sid), 5)
		all_ok = all_ok and t == [2, 3, 5] and not Items.set_bonus(String(sid), 2).get("stat", {}).is_empty() \
			and (Items.set_bonus(String(sid), 3).get("stat", {}) as Dictionary).size() == 2 and not (five.get("procs", []) as Array).is_empty() \
			and not Items.set_bonus(String(sid), 5).has("eden")
		print("   %s %s : 2 = %s · 3 = %s · 5 = %s" % [sid, SurvivorPool.set_def(String(sid)).name, " ; ".join(Items.bonus_lines(Items.set_bonus(String(sid), 2))),
			" ; ".join(Items.bonus_lines(Items.set_bonus(String(sid), 3))), " ; ".join(Items.bonus_lines(five))])
	check("tous les sets : bonus à 2, 3 et 5 pièces (règle du Survivant)", all_ok)
	# porter 2, 3 puis 5 pièces d'un set
	var sid := String(SurvivorPool.sets()[0])
	for s in SurvivorPool.SET_SLOT_ORDER:
		Profile.equipped.erase(s)
	Run.passives.clear()
	Run.passive_power.clear()
	var pieces := SurvivorPool.set_pieces(sid)
	var tiers_seen: Array = []
	var stats_before := Profile.equipment_stats()
	for i in pieces.size():
		SurvivorGear.equip(SurvivorGear.from_eden(pieces[i]))
		var act: Array = Items.active_set_bonuses(Profile.set_gear()).filter(func(b): return b.set == sid).map(func(b): return int(b.pieces))
		tiers_seen.append(act)
	check("paliers actifs à 1..5 pièces : %s" % [tiers_seen], tiers_seen == [[], [2], [2, 3], [2, 3], [2, 3, 5]])
	var procs := Items.gear_procs(Profile.set_gear()).filter(func(p): return String(p.id).begins_with("set_%s_5" % sid))
	check("palier 5 : effet déclenché actif", procs.size() == 1)
	var st := Profile.equipment_stats()
	var two: Dictionary = Items.set_bonus(sid, 2).stat
	var k2 := String(two.keys()[0])
	check("bonus de set dans les stats du héros (%s)" % k2, float(st.get(k2, 0.0)) >= float(two[k2]) - 0.0001 and st.size() >= stats_before.size())
	check("5 pièces : 5 passifs fixes distincts dans la run", Run.passives.size() == 5)


# --- armes --------------------------------------------------------------------------------------------------------------
func _weapons() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var ok := true
	var codes := true
	for w in SurvivorPool.weapon_types():
		var it := SurvivorGear.make_weapon(String(w), {"rng": rng})
		ok = ok and not it.is_empty() and Items.weapon_type_of(it) == w and it.sv and it.has("auto_variant") and not it.has("passive") \
			and float(it.quality) >= 1.0 and SurvivorGear.passives_of(it).size() == 1
		codes = codes and String(it.get("weapon", "")) != ""
	check("17 types d'arme fabriqués (stats d'origine, variante, passif fixe)", ok)
	check("chaque arme a un modèle visible", codes)
	var offers := SurvivorGear.weapon_offers(3, {"rng": rng})
	var types: Array = offers.map(func(o): return String(o.wtype))
	check("offre d'armes : 3 types différents (%s)" % [types], offers.size() == 3 and types[0] != types[1] and types[1] != types[2] and types[0] != types[2]
		and offers.all(func(o): return o.type == "sv_weapon" and Items.weapon_type_of(o.item) == o.wtype))
	Profile.equipped.erase("weapon")
	var other := "bow" if Items.default_weapon_type("warrior") != "bow" else "staff"
	var wpn := SurvivorGear.make_weapon(other, {"rng": rng})
	check("arme d'un autre type que la classe portée à vie", SurvivorGear.equip(wpn) and Run.weapon_type() == other and Survivor.weapon_type() == other
		and Profile.weapon_code() == String(wpn.weapon))
	check("arme verrouillée : une autre refusée", not SurvivorGear.equip(SurvivorGear.make_weapon("katana", {"rng": rng})) and is_same(Profile.equipped.weapon, wpn))
	Profile.inventory.append(SurvivorGear.make_weapon("katana", {"rng": rng}))
	Profile.equip_offhand(Profile.inventory[0])
	check("pas d'arme secondaire en Survivant", not Profile.equipped.has("offhand"))
	Profile.inventory.clear()
	var sig := false
	var spec_ok := true
	while int(wpn.upgrade) < 10:
		var o := SurvivorGear.upgrade_offer("weapon", "common", rng)
		spec_ok = spec_ok and o.type == "sv_weapon_up" and o.has("auto") and float(o.auto.get("dmg", 0.0)) > 0.0
		SurvivorGear.apply_upgrade(o)
		if int(wpn.upgrade) == 4:
			sig = bool(Run.weapon_ups.weapon.get("sig", false))
	check("amélioration d'arme : +2 et amélioration d'auto-attaque tirée à la proposition", spec_ok)
	check("auto-attaque : niveau = +N de l'arme (%d), effet légendaire à +4" % int(Run.weapon_ups.weapon.rank), int(Run.weapon_ups.weapon.rank) == 10 and sig)
	check("arme +10 : 4 passifs distincts", SurvivorGear.passives_of(wpn).size() == 4)
	check("stats du héros : l'arme de la run, jamais celle du hub", float(Profile.equipment_stats().get("patk", 0.0)) > 0.0
		and Profile.equipped.values().all(func(x): return x.get("sv", false)))


# --- fréquence du 5/5 -------------------------------------------------------------------------------------------------
func _frequency() -> void:
	var sim = load("res://tools/sv_set_sim.gd")
	# (lot S3 : mesuré avec le vrai tirage des cartes, tools/sv_cards_sim ; le modèle de sv_set_sim l'estimait avant S3)
	var real: Dictionary = (load("res://tools/sv_cards_sim.gd") as GDScript).simulate(300, 5, "chercheur")
	var full := float(real.target5) / float(real.runs)
	check("5/5 rare pour un joueur qui cherche un set : %.1f %% (1 run sur %.0f, cible 20 à 30)" % [100.0 * full, 1.0 / maxf(full, 0.0001)],
		full >= 1.0 / 60.0 and full <= 1.0 / 12.0)
	var p: Dictionary = sim.simulate(1500, 5, "plates", "preneur")
	check("5/5 sans le chercher : presque jamais (%.2f %%)" % (100.0 * p.full), p.full < 0.01)
