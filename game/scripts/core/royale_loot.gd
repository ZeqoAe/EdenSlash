class_name RoyaleLoot
extends RefCounted
## Battle royale, butin (lot BR3, retours du joueur du 16/10) : l'équipement d'un héros se construit sans jamais changer
## de pièce pour rien.
##   - L'arme choisie au départ (la variante de la classe) est gardée toute la partie : aucun coffre ne propose d'arme
##     au joueur (un héros scripté, parti les mains vides, reçoit la sienne au premier coffre qui la tire).
##   - Un coffre propose d'abord une pièce par emplacement vide (3 au plus, de la qualité du coffre).
##   - Un emplacement rempli garde sa pièce : le coffre propose des améliorations de pièces portées, et une pièce de
##     remplacement seulement si elle est nettement meilleure (jamais une fois l'équipement complet : les 9 emplacements
##     d'Items.SLOTS, cape comprise).
##   - Joueur : les pièces et les améliorations du Survivant (voir « cartes du joueur » plus bas). Héros scriptés : la même
##     logique de remplissage, puis des améliorations internes ([method offer] : mise à niveau, rareté, forge +N, car
##     leurs pièces ne suivent pas leur niveau), l'option au plus grand gain de note (Royale.ai_open_chest).
##   - À la mort d'un héros (joueur compris), ses pièces tombent au sol, sauf son arme ; joueur et héros scriptés les
##     ramassent (une pièce n'est prise que si elle bat celle de l'emplacement : voir [method better]).

## Emplacements d'équipement du Battle royale.
const SLOTS := Items.SLOTS
## Pièce de remplacement : proposée seulement si sa note dépasse celle de la pièce portée (mise à niveau comprise)
## de REPLACE_RATIO fois, et d'au moins REPLACE_MIN.
const REPLACE_RATIO := 1.3
const REPLACE_MIN := 0.6
## Forge : crans gagnés par qualité de coffre (bois, argent, or, largage).
const FORGE_STEP := [1, 2, 3, 4]
## Rareté la plus haute qu'une amélioration atteint, par qualité de coffre (Rare, Épique, Légendaire, Légendaire).
const RARITY_CAP := [2, 3, 5, 5]
## Mise à niveau : proposée quand la pièce a au moins LEVEL_LAG niveaux de retard sur le butin du moment.
const LEVEL_LAG := 2
## Bonus de note d'une pièce pour un emplacement vide (choix automatique, héros scriptés) : l'équipement se remplit d'abord.
const EMPTY_FIRST := 3.0
## Pièces au sol : rayon autour de la dépouille, rayon de ramassage.
const DROP_SPREAD := 2.6
const PICK_RANGE := 2.2


## Note d'une pièce pour la classe (profil [param prof]) d'un héros de niveau [param lv].
static func rate(it: Dictionary, prof: Dictionary, lv: int) -> float:
	if it.is_empty():
		return 0.0
	var was := Run.hero_level
	Run.hero_level = lv  # (la puissance d'une pièce suit le niveau du héros qui la porte)
	var r := Items.rating(it, prof)
	Run.hero_level = was
	return r


static func is_complete(gear: Dictionary) -> bool:
	return SLOTS.all(func(s): return gear.has(s) and not (gear[s] as Dictionary).is_empty())


static func empty_slots(gear: Dictionary) -> Array:
	return SLOTS.filter(func(s): return not gear.has(s) or (gear[s] as Dictionary).is_empty())


## Options d'un coffre de qualité [param tier] pour un héros de la classe [param cid], niveau [param lv], qui porte
## [param gear] : [param n] au plus, chacune {kind: "piece", slot, item, gain, replace} ou
## {kind: "up", slot, up: level | rarity | forge, amount, item (aperçu), gain}. [] : plus rien à améliorer.
static func offer(tier: int, lv: int, cid: String, gear: Dictionary, n := 3) -> Array:
	tier = clampi(tier, 0, Royale.CHEST_TIERS.size() - 1)
	var def: Dictionary = Royale.CHEST_TIERS[tier]
	var prof := ClassGear.profile(cid)
	var out: Array = []
	var empty := empty_slots(gear)
	empty.shuffle()
	for s in empty:
		if out.size() >= n:
			break
		var it := _piece(def, lv, cid, String(s))
		out.append({"kind": "piece", "slot": String(s), "item": it, "gain": rate(it, prof, lv) + EMPTY_FIRST, "replace": false})
	if out.size() >= n:
		return out
	var taken := {}
	# remplacement (équipement incomplet seulement) : nettement meilleur que la pièce portée, même mise à niveau
	if not is_complete(gear):
		var filled := SLOTS.filter(func(s): return s != "weapon" and not s in empty)
		if not filled.is_empty():
			var s: String = filled.pick_random()
			var it := _piece(def, lv, cid, s)
			var worn: Dictionary = gear[s]
			var lifted := worn.duplicate(true)
			_apply(lifted, "level", 0, lv, tier)
			var best_worn := maxf(rate(worn, prof, lv), rate(lifted, prof, lv))
			var r := rate(it, prof, lv)
			if r >= best_worn * REPLACE_RATIO and r >= best_worn + REPLACE_MIN:
				out.append({"kind": "piece", "slot": s, "item": it, "gain": r - rate(worn, prof, lv), "replace": true})
				taken[s] = true
	var cands: Array = []
	for s in SLOTS:
		if s in empty or taken.has(s):
			continue
		var worn: Dictionary = gear[s]
		var base := rate(worn, prof, lv)
		for up in ["level", "rarity", "forge"]:
			var amount := _amount(worn, up, lv, tier)
			if amount <= 0:
				continue
			var prev := worn.duplicate(true)
			_apply(prev, up, amount, lv, tier)
			var g := rate(prev, prof, lv) - base
			if g > 0.001:
				cands.append({"kind": "up", "slot": s, "up": up, "amount": amount, "item": prev, "gain": g})
	# tirage pondéré par le gain, un emplacement par option (les plus utiles sortent le plus souvent)
	while out.size() < n and not cands.is_empty():
		var total := 0.0
		for c in cands:
			total += float(c.gain)
		var roll := randf() * total
		var pick: Dictionary = cands[cands.size() - 1]
		for c in cands:
			roll -= float(c.gain)
			if roll <= 0.0:
				pick = c
				break
		out.append(pick)
		cands = cands.filter(func(c): return String(c.slot) != String(pick.slot))
	return out


static func _piece(def: Dictionary, lv: int, cid: String, slot: String) -> Dictionary:
	return Items.generate(Royale.loot_level(lv), float(def.luck), slot, cid, int(def.min_r), "", int(def.max_r))


## Ampleur de l'amélioration [param up] possible sur [param it] (0 : aucune) : crans de forge, niveaux de retard, 1 rareté.
static func _amount(it: Dictionary, up: String, lv: int, tier: int) -> int:
	match up:
		"forge":
			return mini(int(FORGE_STEP[tier]), Items.MAX_UPGRADE - int(it.get("upgrade", 0)))
		"rarity":
			return 1 if int(it.get("rarity", 0)) < mini(int(RARITY_CAP[tier]), Items.LEGENDARY) else 0
		"level":
			var lag := level_target(it, lv) - int(it.get("level", 0))
			return lag if lag >= LEVEL_LAG else 0
	return 0


## Niveau (affiché) d'une pièce remise au niveau du butin d'un héros de niveau [param lv] : celui d'une pièce neuve
## (Items.eden_target pour une pièce d'Eden, sinon le niveau du butin).
static func level_target(it: Dictionary, lv: int) -> int:
	var loot := Royale.loot_level(lv)
	if not it.has("eden"):
		return loot
	var t := Items.eden_target(loot)
	# la puissance d'une pièce d'Eden est plafonnée par son niveau (Items.power_cap) : au moins celle du butin
	var probe := {"eden": 1, "level": t}
	while Items.power_cap(probe) < loot and int(probe.level) < t + 120:
		probe.level = int(probe.level) + 1
	return int(probe.level)


## Applique l'amélioration [param up] (ampleur [param amount]) à [param it] ; renvoie le texte du résultat.
static func _apply(it: Dictionary, up: String, amount: int, lv: int, tier: int) -> String:
	match up:
		"forge":
			for i in amount:
				Items.upgrade(it)
			return "+%d" % int(it.get("upgrade", 0))
		"rarity":
			var r := int(it.get("rarity", 0))
			var r2 := mini(r + 1, Items.LEGENDARY)
			if r2 == r:
				return ""
			if it.has("base"):
				var k := float(Items.RARITY_MULT[r2]) / float(Items.RARITY_MULT[r])
				var base: Dictionary = (it.base as Dictionary).duplicate()
				for s in base:
					base[s] = float(base[s]) * k
				it["base"] = base
			it["rarity"] = r2
			it["quality"] = maxf(float(it.get("quality", 1.0)), float(Items.QUALITY[r2][0]))
			if not it.has("affixes"):
				it["affixes"] = {}
			if (it.affixes as Dictionary).size() < int(Items.RARITIES[r2].affixes):
				var free := Items.AFFIX_RANGES.keys().filter(func(s): return not (it.affixes as Dictionary).has(s))
				if not free.is_empty():
					var was := Run.hero_level
					Run.hero_level = lv
					Items._add_affix(it, String(free.pick_random()))
					Run.hero_level = was
			return String(Items.RARITIES[r2].name)
		"level":
			var t := level_target(it, lv)
			if t > int(it.get("level", 0)):
				it["level"] = t
			it["plevel"] = maxi(int(it.get("plevel", 0)), Royale.loot_level(lv))
			return "niv. %d" % int(it.level)
	return ""


## Applique l'option [param o] (voir [method offer]) à l'équipement [param gear] (emplacement -> pièce).
static func apply_option(o: Dictionary, gear: Dictionary) -> void:
	if String(o.kind) == "piece":
		gear[String(o.slot)] = o.item
	else:
		gear[String(o.slot)] = o.item  # l'aperçu EST la pièce améliorée (copie de la pièce portée)


## Option préférée d'un héros scripté (et du choix automatique) : le gain de note le plus haut.
static func best(options: Array) -> Dictionary:
	var pick: Dictionary = {}
	for o in options:
		if pick.is_empty() or float(o.get("gain", 0.0)) > float(pick.get("gain", 0.0)):
			pick = o
	return pick


# --- cartes du joueur : le système du Survivant ---------------------------------------------------------------------
## Le joueur joue avec les pièces et les améliorations du Survivant (SurvivorGear, SurvivorCards, SurvivorCardView) :
## pièces des coffres du Battle royale faites pièces du Survivant (SurvivorGear.adopt : jet 100-120 %, passif fixe,
## puissance au niveau du héros), cartes « Nouvelle pièce » (sv_piece), « Amélioration » (sv_piece_up / sv_weapon_up :
## +2, +4 en légendaire, passif tiré et montré aux paliers +6 / +8 / +10, jet relevé) ; l'arme de départ est une carte
## « Arme » (sv_weapon). Les héros scriptés gardent leurs améliorations internes ([method offer]).
## Chance (rareté des améliorations, SurvivorCards.roll_tier) et rareté minimale, par qualité de coffre.
const CARD_LUCK := [0.0, 0.3, 0.6, 1.2]
## Passifs sans objet ici (ni monstre à tuer, ni butin à attirer) : bannis au départ de la partie (Royale.start), ni
## tirés aux paliers ni passifs fixes (SurvivorGear.adopt prend le suivant).
const NO_PASSIVES := ["volatile", "magnet"]
const CARD_FLOOR := ["common", "common", "rare", "epic"]


## Carte de choix venue du système du Survivant (Run.apply_card la passe à [method apply_card]) ?
static func owns(card: Dictionary) -> bool:
	return Royale.active and String(card.get("type", "")) in ["sv_weapon", "sv_piece", "sv_piece_up", "sv_weapon_up"]


## Cartes de l'arme de départ : les variantes de l'arme de la classe ([param cards] de RunDirector.start_weapon_cards),
## faites armes du Survivant.
static func start_weapon_cards(cards: Array) -> Array:
	var out: Array = []
	for c in cards:
		var it: Dictionary = c.get("item", {})
		if not it.is_empty():
			out.append(SurvivorCards.weapon_item_card(SurvivorGear.adopt(it)))
	return out


## Cartes d'un coffre de qualité [param tier] pour le joueur de niveau [param lv] : une nouvelle pièce par emplacement
## vide (jamais d'arme), une pièce nettement meilleure tant que l'équipement est incomplet, sinon des améliorations de
## pièces portées (emplacements différents). [] : plus rien à proposer.
static func player_cards(tier: int, lv: int) -> Array:
	tier = clampi(tier, 0, Royale.CHEST_TIERS.size() - 1)
	var def: Dictionary = Royale.CHEST_TIERS[tier]
	var prof := ClassGear.profile(Run.class_id)
	var gear: Dictionary = Profile.equipped
	var out: Array = []
	var empty := empty_slots(gear).filter(func(s): return s != "weapon")
	empty.shuffle()
	for s in empty.slice(0, 3):
		var it := SurvivorGear.adopt(_piece(def, lv, Run.class_id, String(s)))
		var c := SurvivorCards.piece_card(it)
		c["royale_gain"] = rate(it, prof, lv) + EMPTY_FIRST  # (un emplacement vide d'abord)
		out.append(c)
	var taken := {}
	if out.size() < 3 and not is_complete(gear):
		var filled := SLOTS.filter(func(s): return s != "weapon" and not s in empty)
		if not filled.is_empty():
			var s: String = filled.pick_random()
			var it := SurvivorGear.adopt(_piece(def, lv, Run.class_id, s))
			var r := rate(it, prof, lv)
			var w := rate(gear[s], prof, lv)
			if r >= w * REPLACE_RATIO and r >= w + REPLACE_MIN:
				var c := SurvivorCards.piece_card(it)
				c["replace"] = true
				c["royale_gain"] = r - w
				out.append(c)
				taken[s] = true
	var slots: Array = SLOTS.filter(func(s): return not s in empty and gear.has(s) and not taken.has(s) \
		and int((gear[s] as Dictionary).get("upgrade", 0)) < Items.MAX_UPGRADE)
	while out.size() < 3 and not slots.is_empty():
		var s := String(_weighted_slot(slots))
		slots.erase(s)
		var t := SurvivorCards.at_least(SurvivorCards.roll_tier(float(CARD_LUCK[tier])), String(CARD_FLOOR[tier]))
		var c := SurvivorCards.up_card(s, t)
		if c.is_empty():
			continue
		c["royale_gain"] = up_gain(c, prof, lv)
		out.append(c)
	return out


## Emplacement tiré pour une amélioration : poids du Survivant (w_weapon_up, w_piece_up, ×1,6 si le +2 éveille un passif).
static func _weighted_slot(slots: Array) -> String:
	var ws: Array = slots.map(func(s): return Survivor.rule("w_weapon_up" if s == "weapon" else "w_piece_up") \
		* (1.6 if SurvivorCards.wakes_next(Profile.equipped[s]) else 1.0))
	var total := 0.0
	for w in ws:
		total += float(w)
	var r := randf() * total
	for i in slots.size():
		r -= float(ws[i])
		if r <= 0.0:
			return String(slots[i])
	return String(slots[slots.size() - 1])


## Gain de note d'une carte d'amélioration (choix automatique) : stats après la carte, +1 par passif gagné.
static func up_gain(card: Dictionary, prof: Dictionary, lv: int) -> float:
	var offer: Dictionary = card.get("offer", {})
	var item: Dictionary = Profile.equipped.get(String(card.get("slot", "")), {})
	if item.is_empty():
		return 0.0
	var after := item.duplicate(true)
	after["upgrade"] = int(offer.get("to", item.get("upgrade", 0)))
	after["quality"] = minf(float(item.get("quality", 1.0)) + float(SurvivorCards.QUALITY_UP.get(String(card.get("tier", "common")), 0.0)),
		Survivor.rule("perfect_quality"))
	return rate(after, prof, lv) - rate(item, prof, lv) + float((offer.get("passives", []) as Array).size())


## Applique une carte du système du Survivant au Battle royale : pièce (posée ; une pièce nettement meilleure remplace
## l'ancienne, dont les passifs quittent la run), amélioration (SurvivorCards.apply : +N, passif, jet).
static func apply_card(card: Dictionary) -> void:
	match String(card.get("type", "")):
		"sv_weapon", "sv_piece":
			wear(card.item)
		"sv_piece_up", "sv_weapon_up":
			SurvivorCards.apply(card)


## Porte [param it] (pièce du Survivant) : la pièce de l'emplacement est retirée (ses passifs quittent la run) ; renvoie
## l'ancienne pièce ({} : emplacement vide).
static func wear(it: Dictionary) -> Dictionary:
	var slot := String(it.get("slot", ""))
	var worn: Dictionary = Profile.equipped.get(slot, {})
	if not worn.is_empty():
		SurvivorGear.release(worn)
		Profile.equipped.erase(slot)
	SurvivorGear.equip(it)
	return worn


## Retire les pièces [param items] du joueur (sa mort : elles tombent au sol) et leurs passifs.
static func strip(items: Array) -> void:
	for it in items:
		var slot := String(it.get("slot", ""))
		if is_same(Profile.equipped.get(slot), it):
			SurvivorGear.release(it)
			Profile.equipped.erase(slot)
	Profile.changed.emit()


# --- pièces au sol ------------------------------------------------------------------------------------
## Pièces lâchées à la mort : toutes celles de [param gear] sauf l'arme.
static func drops_of(gear: Dictionary) -> Array:
	var out: Array = []
	for s in SLOTS:
		if s != "weapon" and gear.has(s) and not (gear[s] as Dictionary).is_empty():
			out.append(gear[s])
	return out


## [param it] bat-elle la pièce de son emplacement dans [param gear] (vide compris) pour la classe [param cid] ?
static func better(it: Dictionary, gear: Dictionary, cid: String, lv: int) -> bool:
	var slot := String(it.get("slot", ""))
	if slot == "weapon" or not slot in SLOTS:
		return false
	var worn: Dictionary = gear.get(slot, {})
	if worn.is_empty():
		return true
	var prof := ClassGear.profile(cid)
	return rate(it, prof, lv) > rate(worn, prof, lv) + 0.05


## Pièce au sol (Interactable « gear_drop ») : nom à la couleur de sa rareté, icône qui flotte, colonne de lumière.
static func make_drop(parent: Node, it: Dictionary, pos: Vector3) -> Interactable:
	var node := Interactable.new()
	node.setup("gear_drop", Items.display_name(it), "", "", 1.0, PICK_RANGE)
	node.set_meta("item", it)
	node.set_meta("prompt", func(): return drop_prompt(it))
	parent.add_child(node)
	node.global_position = pos
	var col := Items.color_of(it)
	var lab := node.get_child(node.get_child_count() - 1) as Label3D
	if lab:
		lab.modulate = col.lightened(0.2)
		lab.position.y = 2.0
		lab.font_size = 22
		lab.visibility_range_end = 7.0  # (le nom de près seulement : huit pièces côte à côte restent lisibles ; l'invite dit le reste)
	var icon := Sprite3D.new()
	icon.name = "Icon"
	if String(it.get("icon", "")) != "" and ResourceLoader.exists(String(it.icon)):
		icon.texture = load(String(it.icon))
	icon.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	icon.pixel_size = 0.012
	icon.no_depth_test = true
	icon.position.y = 1.0
	node.add_child(icon)
	var tw := icon.create_tween().set_loops()
	tw.tween_property(icon, "position:y", 1.2, 0.8).set_trans(Tween.TRANS_SINE)
	tw.tween_property(icon, "position:y", 0.9, 0.8).set_trans(Tween.TRANS_SINE)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.disable_fog = true
	mat.albedo_color = Color(col, 0.38)
	var beam := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.04
	cyl.bottom_radius = 0.32
	cyl.height = 4.0 + 1.5 * int(it.get("rarity", 0))
	cyl.cap_top = false
	cyl.cap_bottom = false
	beam.mesh = cyl
	beam.material_override = mat
	beam.position.y = cyl.height * 0.5
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	beam.visibility_range_end = 120.0
	node.add_child(beam)
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.55
	torus.outer_radius = 0.7
	torus.rings = 24
	ring.mesh = torus
	var rmat := mat.duplicate() as StandardMaterial3D
	rmat.albedo_color = Color(col, 0.8)
	ring.material_override = rmat
	ring.position.y = 0.1
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.add_child(ring)
	return node


## Invite d'une pièce au sol pour le joueur : prendre, et ce qu'elle vaut face à sa pièce.
static func drop_prompt(it: Dictionary) -> String:
	var slot := String(it.get("slot", ""))
	var worn: Dictionary = Profile.equipped.get(slot, {})
	var what := "%s · %s" % [Items.SLOT_NAMES.get(slot, slot), Items.RARITIES[clampi(int(it.get("rarity", 0)), 0, 5)].name]
	if worn.is_empty():
		return "[F] Prendre — %s (emplacement libre)" % what
	var cmp := "▲ mieux que ta pièce" if better(it, Profile.equipped, Run.class_id, Run.hero_level) else "▼ moins bien que ta pièce"
	return "[F] Prendre — %s (%s)" % [what, cmp]


## Positions des [param n] pièces autour de [param center] (cercle, sol de la carte [param map]).
static func spread(map, center: Vector3, n: int) -> Array:
	var out: Array = []
	for i in n:
		var a := TAU * float(i) / float(maxi(n, 1)) + randf() * 0.4
		var q := center + Vector3(cos(a), 0.0, sin(a)) * (DROP_SPREAD + (0.8 if n > 5 else 0.0))
		var g: Vector3 = map.ground_at(q.x, q.z) if map != null else Vector3.INF
		out.append((g if g != Vector3.INF else q) + Vector3.UP * 0.05)
	return out
