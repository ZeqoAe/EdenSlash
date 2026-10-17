extends Node
## L'Échiquier, lot AC-A : tables du mode (AutochessData) et les 60 unités (data/autochess_units.json).
## godot --headless --path game res://tests/test_ac_data.tscn

var fails := 0
var _fr: Object  # détecteur de mots anglais de test_texts_fr (même liste de contrôle)


func check(label: String, ok: bool) -> void:
	print(("OK    " if ok else "ÉCHEC ") + label)
	if not ok:
		fails += 1


## Texte joueur : français (aucun mot de la liste de contrôle), non vide.
func _french(s: String) -> bool:
	return s.strip_edges() != "" and (_fr.call("_english_in", s) as Array).is_empty()


func _ready() -> void:
	_fr = load("res://tests/test_texts_fr.gd").new()
	var units := AutochessData.units()
	var A := AutochessData

	# 1. les 60 unités : une par classe, répartition des coûts, familles et traits d'arme
	check("60 unités", units.size() == 60)
	var all_classes := true
	for id in units:
		all_classes = all_classes and GameData.classes.has(id)
	check("chaque unité est une classe du jeu", all_classes and GameData.classes.size() == 60)
	var by_cost := {}
	var by_trait := {}
	var fam_cost := {}
	for id in units:
		var u: Dictionary = units[id]
		by_cost[int(u.cost)] = int(by_cost.get(int(u.cost), 0)) + 1
		for t in u.traits:
			by_trait[t] = int(by_trait.get(t, 0)) + 1
		var k := "%s/%d" % [u.traits[0], int(u.cost)]
		fam_cost[k] = int(fam_cost.get(k, 0)) + 1
	check("coûts : 10 / 15 / 15 / 10 / 10 unités (%s)" % str(by_cost), by_cost == {1: 10, 2: 15, 3: 15, 4: 10, 5: 10} and by_cost == A.UNITS_PER_COST)
	var fam_ok := true
	for f in A.family_traits():
		fam_ok = fam_ok and int(by_trait.get(f, 0)) == 12
		for c in range(1, 6):
			fam_ok = fam_ok and int(fam_cost.get("%s/%d" % [f, c], 0)) == [2, 3, 3, 2, 2][c - 1]
	check("12 unités par famille, 2 / 3 / 3 / 2 / 2 par coût", fam_ok and A.family_traits().size() == 5)
	var wpn_ok := A.weapon_traits().size() == 10
	for w in A.weapon_traits():
		wpn_ok = wpn_ok and int(by_trait.get(w, 0)) == 6
	check("6 unités par trait d'arme (10 traits)", wpn_ok)

	# 2. chaque unité : traits, portée, rôle, sort signature et mana tirés du vrai code des classes
	var bad: Array = []
	for id in units:
		var u: Dictionary = units[id]
		var cd: Dictionary = GameData.classes[id]
		var wt := String(cd.weapon_type)
		var sk: Array = cd.skills
		var idx := int(u.get("skill_index", -1))
		var sig: Dictionary = sk[idx] if idx >= 0 and idx < sk.size() else {}
		var ok: bool = u.traits == [A.FAMILY_TRAIT[int(cd.family)], A.WEAPON_TRAIT[wt]] \
			and String(u.weapon_type) == wt and int(u.family) == int(cd.family) \
			and int(u.range) == int(A.WEAPON_RANGE[wt]) and A.PLACES.has(String(u.place)) \
			and A.ROLES.has(String(u.role)) and is_equal_approx(float(u.attack_range_m), A.reach_m(int(u.range))) \
			and float(u.preferred_distance_m) > 0.0 and float(u.preferred_distance_m) <= float(u.attack_range_m) \
			and int(sig.get("id", -1)) == int(u.skill_id) and not sig.get("shared", false) \
			and String(u.skill_name) == String(sig.get("name", "")) and String(u.skill_kind) == String(sig.get("kind", "")) \
			and String(u.spell_type) == String(A.SPELL_TYPES.get(String(sig.get("kind", "")), "")) \
			and int(u.mana) == A.mana_for(float(sig.get("cooldown", 0.0)), String(u.role)) and int(u.mana) >= A.MANA_MIN and int(u.mana) <= A.MANA_MAX \
			and int(u.second_skill_id) != int(u.skill_id) and sk.any(func(s): return int(s.id) == int(u.second_skill_id)) \
			and String(u.name) == String(cd.name_fr) and A.unit_name(id) == String(cd.name_fr) \
			and float(u.sim_factor) > 0.0 and not u.has("brain") and not u.has("captain_skill_ids")
		if not ok:
			bad.append(id)
	check("fiches cohérentes avec classes.json (traits, portée, rôle, sort, mana, nom) %s" % str(bad), bad.is_empty())
	var types_ok := true
	for wt in GameData.weapon_types:
		types_ok = types_ok and A.WEAPON_TRAIT.has(wt) and A.WEAPON_RANGE.has(wt)
	for t in A.weapon_traits():
		for wt in A.TRAITS[t].weapons:
			types_ok = types_ok and A.WEAPON_TRAIT[wt] == t
	check("17 types d'arme regroupés en 10 traits (table des traits = WEAPON_TRAIT)", types_ok and A.WEAPON_TRAIT.size() == 17)
	var by_role := {}
	for id in units:
		by_role[units[id].role] = int(by_role.get(units[id].role, 0)) + 1
	check("rôles de l'annexe A : 9 tanks, 15 combattants, 3 assassins, 12 tireurs, 9 mages, 7 soigneurs, 5 soutiens",
		by_role == {"tank": 9, "combattant": 15, "assassin": 3, "tireur": 12, "mage": 9, "soigneur": 7, "soutien": 5})
	check("poids de l'IA : un jeu par rôle, réglage commun Difficile", A.ROLES.keys().all(func(r): return A.AI_WEIGHTS.has(r)) and A.UNIT_DIFF == 2)

	# 3. boutique et réserve
	var odds_ok := true
	for lv in range(1, A.MAX_LEVEL_BONUS + 1):
		var row: Array = A.shop_odds(lv)
		var sum := 0
		for p in row:
			sum += int(p)
		odds_ok = odds_ok and row.size() == 5 and sum == 100
	check("taux de boutique : 100 à chaque niveau (1 à 11)", odds_ok)
	check("réserve : 290 / 330 / 270 / 120 / 100 copies",
		range(1, 6).map(func(c): return int(A.POOL_COPIES[c]) * int(A.UNITS_PER_COST[c])) == [290, 330, 270, 120, 100])
	check("XP par niveau 2 → 10 (et 10 → 11 pour l'atout)", A.xp_to_next(2) == 2 and A.xp_to_next(9) == 84 and A.xp_to_next(10) > 0 and A.xp_to_next(11) == 0)

	# 4. économie et PV de joueur
	check("vente : ★1 1, ★2 coût 2 → 5, ★3 coût 3 → 26", A.sell_value(1, 1) == 1 and A.sell_value(2, 2) == 5 and A.sell_value(3, 3) == 26 and A.sell_value(1, 2) == 3)
	check("intérêts : 57 or → 5, plafond composé 120 or → 10", A.interest(57) == 5 and A.interest(120, A.INTEREST_CAP_COMPOUND) == 10 and A.interest(9) == 0)
	check("séries : 1 → 0, 2 → 1, 4 → 2, 7 → 3", A.streak_gold(1) == 0 and A.streak_gold(2) == 1 and A.streak_gold(4) == 2 and A.streak_gold(-7) == 3)
	check("revenu : 1-2 → 2, 1-4 → 3, 3-5 → 5", A.base_income(1, 2) == 2 and A.base_income(1, 4) == 3 and A.base_income(3, 5) == 5)
	check("dégâts JcJ : étape 3, une ★1 et une ★2 debout → 7", A.pvp_damage(3, [1, 2]) == 7)
	check("dégâts gardien perdu en étape 2 → 7 ; étape 9 → base 20", A.pve_damage(2, 0, true) == 7 and A.stage_damage(9) == 20)
	check("multiplicateurs : coût 5 ★3 = 1,9 × 3,24", is_equal_approx(A.stat_mult(5, 3), 1.9 * 3.24) and is_equal_approx(A.spell_mult(2), 1.5))

	# 5. déroulé
	check("manches : 1-1 ouverture, 2-4 choix, 3-7 gardien, 2-1 atout",
		A.round_kind(1, 1) == "ouverture" and A.round_kind(2, 4) == "choix" and A.round_kind(3, 7) == "gardien" and A.is_augment_round(2, 1) and not A.is_augment_round(2, 2))
	check("butin : 2-7 gagné → 2 composants ; gardien 9-7 = celui de 7-7", int(A.loot(2, 7, true).get("composants", 0)) == 2 and A.loot(9, 7, true) == A.loot(7, 7, true))
	check("préparation : 15 s en étape 1, 35 s à 3-2", is_equal_approx(A.prep_time(1, 2), 15.0) and is_equal_approx(A.prep_time(3, 2), 35.0))

	# 6. traits
	var tr_ok := A.TRAITS.size() == 15
	for t in A.TRAITS:
		var d: Dictionary = A.TRAITS[t]
		tr_ok = tr_ok and (d.tiers as Array).size() == 3 and String(d.effect) != "" and d.scope in ["porteurs", "equipe", "ennemis"]
	check("15 traits (5 familles, 10 armes), 3 paliers chacun", tr_ok)
	check("paliers : Rempart 2 → 0, 3 → 1, 9 → 3 ; Tir 2 → 1, 6 → 3",
		A.trait_tier("rempart", 2) == 0 and A.trait_tier("rempart", 3) == 1 and A.trait_tier("rempart", 9) == 3 and A.trait_tier("tir", 2) == 1 and A.trait_tier("tir", 6) == 3)
	check("paramètres du palier (Fracas à 4 : toutes les 3 attaques)", int(A.trait_params("fracas", 4).get("every", 0)) == 3 and A.trait_params("fracas", 1).is_empty())

	# 7. objets : 9 composants, 36 recettes, une par paire
	check("9 composants (8 de base + Insigne)", A.COMPONENTS.size() == 9 and A.BASE_COMPONENTS.size() == 8)
	var pairs := {}
	var it_ok := A.ITEMS.size() == 36
	for id in A.ITEMS:
		var d: Dictionary = A.ITEMS[id]
		var p: Array = d.parts
		var key := ",".join(PackedStringArray([p[0], p[1]] if String(p[0]) < String(p[1]) else [p[1], p[0]]))
		it_ok = it_ok and not pairs.has(key) and p[0] in A.BASE_COMPONENTS and p[1] in A.BASE_COMPONENTS
		pairs[key] = id
		it_ok = it_ok and A.combine(p[0], p[1]) == id and A.combine(p[1], p[0]) == id and d.trigger in A.TRIGGERS and String(d.effect) != ""
		if String(d.get("icon", "")) != "":
			it_ok = it_ok and not Boons.get_def(String(d.icon)).is_empty()
	check("36 recettes cohérentes (chaque paire une fois, combinaison symétrique, déclencheur connu, icônes existantes)", it_ok and pairs.size() == 36)
	check("Insigne : Emblème avec un composant, Couronne avec un autre Insigne", A.combine("insigne", "lame") == "embleme" and A.combine("insigne", "insigne") == "couronne" and A.combine("lame", "zzz") == "")
	var st := A.item_stats("soif_de_sang")
	check("stats d'un objet = somme de ses composants (Soif de sang : attaque + défense)", is_equal_approx(float(st.get("atk_pct", 0)), 0.10) and int(st.get("def", 0)) == 20)
	var stat_keys_ok := true
	for c in A.COMPONENTS:
		for k in A.COMPONENTS[c].stats:
			stat_keys_ok = stat_keys_ok and k in A.STAT_KEYS
	check("stats des composants : clés connues", stat_keys_ok)

	# 8. atouts : 30, 10 Argent / 11 Or / 9 Éclat
	var au_ok := A.AUGMENTS.size() == 30 and A.augments_of("argent").size() == 10 and A.augments_of("or").size() == 11 and A.augments_of("eclat").size() == 9
	for id in A.AUGMENTS:
		var d: Dictionary = A.AUGMENTS[id]
		au_ok = au_ok and d.trigger in A.TRIGGERS and String(d.effect) != "" and A.AUGMENT_RARITY_WEIGHTS.has(d.rarity)
	check("30 atouts (10 / 11 / 9), déclencheurs et raretés connus", au_ok)
	var w := 0
	for r in A.AUGMENT_RARITY_WEIGHTS:
		w += int(A.AUGMENT_RARITY_WEIGHTS[r])
	check("poids des raretés d'atout : 100", w == 100)
	check("difficultés : 4, 7 adversaires chacune", A.DIFFICULTIES.size() == 4 and A.DIFFICULTIES.all(func(d): return (d.mix as Array).reduce(func(a, b): return a + b, 0) == 7))

	# 9. textes : français, courts, aucun pourcentage dans le texte permanent, noms uniques
	var bad_txt: Array = []
	var names := {}
	var tables := {"trait": A.TRAITS, "composant": A.COMPONENTS, "objet": A.ITEMS, "objet spécial": A.SPECIAL_ITEMS,
		"atout": A.AUGMENTS, "rôle": A.ROLES, "tempérament": A.TEMPERAMENTS}
	for tab in tables:
		for id in tables[tab]:
			var d: Dictionary = tables[tab][id]
			var sh := String(d.get("short", ""))
			if not _french(String(d.name)) or not _french(sh) or sh.contains("%") or sh.length() > 90:
				bad_txt.append("%s %s" % [tab, id])
			if d.has("tip") and not _french(String(d.tip)):
				bad_txt.append("%s %s (infobulle)" % [tab, id])
			if tab in ["objet", "composant", "atout"]:
				var nk := "%s:%s" % [tab, d.name]
				if names.has(nk):
					bad_txt.append("nom en double : " + nk)
				names[nk] = true
	for id in units:
		if not _french(String(units[id].name)) or not _french(String(units[id].skill_name)):
			bad_txt.append("unité " + id)
	for t in [A.PLACES, A.SPELL_TYPE_NAMES, A.RARITY_NAMES]:
		for k in t:
			if not _french(String(t[k])):
				bad_txt.append(String(t[k]))
	check("textes en français, courts, sans pourcentage permanent, noms uniques %s" % str(bad_txt), bad_txt.is_empty())

	_fr.free()
	print("TOUT OK" if fails == 0 else "%d ÉCHEC(S)" % fails)
	get_tree().quit(1 if fails > 0 else 0)
