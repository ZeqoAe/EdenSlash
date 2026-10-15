extends Node
## Barème des insignes et maîtrise des 60 classes (lot E5) : coût de l'Armurerie par époque (prix plein, paliers),
## kit d'une classe, heures de Survie au rythme d'Economy, et Survies victorieuses pour monter une classe.
## godot --headless --path game res://tools/insignia_probe.tscn


func _ready() -> void:
	Profile.in_run = false
	_armory()
	_mastery()
	get_tree().quit()


func _armory() -> void:
	var ids := Completion.armory_ids()
	var per := {}  # époque -> {n, full, tiers: {clé -> [prix]}, weapon_n, armor_n, jewel_n}
	for id in ids:
		var e: Dictionary = GameData.eden_by_id.get(int(id), {})
		if e.is_empty():
			continue
		var ep := int(ids[id])
		if not per.has(ep):
			per[ep] = {"n": 0, "full": 0, "tiers": {}, "weapon": 0, "armor": 0, "jewel": 0}
		var p := Economy.base_price(e)
		var cat := "weapon" if String(e.slot) == "weapon" else ("jewel" if String(e.slot) in ["ring", "necklace"] else "armor")
		per[ep].n += 1
		per[ep].full += p
		per[ep][cat] += 1
		var k := Economy.tier_key(e)
		if not per[ep].tiers.has(k):
			per[ep].tiers[k] = []
		per[ep].tiers[k].append(p)
	print("Armurerie : %d pièces" % ids.size())
	var sum_full := 0
	var sum_tier := 0
	var sum_first := 0
	for ep in range(1, Epochs.count() + 1):
		var d: Dictionary = per.get(ep, {"n": 0, "full": 0, "tiers": {}, "weapon": 0, "armor": 0, "jewel": 0})
		var first := 0
		var tiered := 0
		for k in d.tiers:
			var ps: Array = d.tiers[k]
			ps.sort()
			ps.reverse()  # la plus chère d'abord au prix plein (cas le plus cher)
			first += int(ps[0])
			tiered += int(ps[0])
			for i in range(1, ps.size()):
				tiered += maxi(1, roundi(int(ps[i]) * Economy.TIER_REPEAT))
		var rate := Economy.survival_insignia_per_hour(ep)
		var kit := _kit_cost(ep)
		sum_full += int(d.full)
		sum_tier += tiered
		sum_first += first
		print("Époque %d : %d pièces (armes %d, armure %d, bijoux %d), %d paliers | Survie %d/h | prix plein %d = %.0f h | paliers %d = %.0f h | 1 pièce par palier %d = %.0f h | kit d'une classe %d = %.1f h | 1re pièce %d"
			% [ep, d.n, d.weapon, d.armor, d.jewel, d.tiers.size(), rate, d.full, d.full / float(rate), tiered, tiered / float(rate),
			first, first / float(rate), kit, kit / float(rate), _cheapest(ep)])
	print("Total : prix plein %d, paliers %d, 1 pièce par palier %d" % [sum_full, sum_tier, sum_first])
	print("Survie : défaite carte 1 (40 monstres) = %d insignes ; victoire époque I = %d, IV = %d"
		% [Economy.survival_insignia(1, 40, 0, 1, false), Economy.survival_insignia(3, 600, 10, 1, true), Economy.survival_insignia(3, 600, 10, 4, true)])
	var looks := {}
	for t in Economy.SHOP_CHESTS:
		looks[t] = Economy.chest_has_content(t)
	print("Puits : coffres achetables %s (contenu restant : %s) ; max par semaine %d insignes ; leçons %d/jour"
		% [Economy.SHOP_CHESTS.keys(), looks, _week_sink(), Economy.LESSON_COST * Economy.LESSONS_PER_DAY])


func _week_sink() -> int:
	var s := 0
	for t in Economy.SHOP_CHESTS:
		s += int(Economy.SHOP_CHESTS[t].price) * int(Economy.SHOP_CHESTS[t].week)
	return s


## Prix du kit d'une classe à la carte 3 de l'époque [param ep] : une pièce par emplacement (la moins chère du coffre).
func _kit_cost(ep: int) -> int:
	var sum := 0
	for box in ["weapon", "head", "chest", "legs", "gloves", "boots", "back", "jewel"]:
		var per_slot := {}
		for e in SlotChests.pool(box, ep, 3, "sword"):
			var c := Economy.base_price(e)
			per_slot[String(e.slot)] = mini(int(per_slot.get(String(e.slot), c)), c)
		for s in per_slot:
			sum += int(per_slot[s])
	return sum


func _cheapest(ep: int) -> int:
	var best := 1 << 30
	for box in ["weapon", "head", "chest", "legs", "gloves", "boots", "back", "jewel"]:
		for e in SlotChests.pool(box, ep, 1, "sword"):
			best = mini(best, Economy.base_price(e))
	return best


## Maîtrise : Survies victorieuses pour amener une classe au niveau 16 et 20, avant / après le lot E5.
func _mastery() -> void:
	var need16 := 0
	var need20 := 0
	for l in range(1, 20):
		need20 += Profile.expertise_need(l)
		if l < 16:
			need16 += Profile.expertise_need(l)
	# Survie victorieuse type : niveau 35, 600 monstres, 10 élites, étape 3 ; contrats ≈ 1 275 par run (R_E5)
	var base := 35 * 15 + 600 / 2 + 10 * 10 + 200 + 120 * 2
	var contracts := 1275
	var before := base + contracts
	print("Maîtrise : niveau 16 = %d, niveau 20 = %d ; Survie victorieuse = %d + contrats ≈ %d = %d" % [need16, need20, base, contracts, before])
	print("  avant : %.1f Survies victorieuses pour le niveau 16, %.1f pour le 20" % [need16 / float(before), need20 / float(before)])
	# après : classe en retard (rattrapage ×1,5 jusqu'au niveau 20), 1re victoire à l'époque IV, part de l'arbre reçue
	var after := roundi(before * Economy.CATCHUP_MULT)
	var tree := 1700  # part reçue pendant que la classe d'origine montait de 3 à 20 (10 % de ≈ 17 000)
	var fw := int(Economy.FIRST_WIN[3])
	print("  après (classe en retard, 1re victoire en époque IV %d, part de l'arbre reçue ≈ %d) : %.1f Survies pour le 16, %.1f pour le 20 (%d par Survie)"
		% [fw, tree, maxf(need16 - fw - tree, 0) / float(after), maxf(need20 - fw - tree, 0) / float(after), after])
	print("  sans part de l'arbre : %.1f pour le 20 ; 60 classes au niveau 20 : avant ≈ %d Survies, après ≈ %d"
		% [(need20 - fw) / float(after), roundi(60 * need20 / float(before)), roundi(need20 / float(before) + 59 * maxf(need20 - fw - tree, 0) / float(after))])
