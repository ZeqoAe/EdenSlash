class_name SurvivorGear
extends RefCounted
## Pièces et arme du Survivant (lot S2, DECISIONS_JOUEUR §1-§2 qui priment sur SPEC §3-§4).
## - Stats D'ORIGINE de la pièce d'Eden (Items.from_template, rareté d'Eden), puissance = niveau du héros plafonné à 90
##   (champ `sv`, Items.power_level) ; seule part aléatoire : la qualité, de 100 à 120 % (jet parfait = 120 %).
## - Passifs (effets des cartes communes, Cards.passive_effects) dans `sv_passives` : [{id, at, power}] (at 0 = fixe).
##   Le passif FIXE est déterministe (fixed_passive : famille du set + rang du set + emplacement ; accessoires et armes :
##   rang du modèle) et différent pour chaque pièce d'un même set. À +6, +8 et +10 la pièce gagne un passif tiré au
##   hasard, différent des siens : il est tiré QUAND la carte d'amélioration est proposée (upgrade_offer), mémorisé dans
##   l'offre et affiché ; prendre l'offre l'applique (apply_upgrade). Une pièce +10 porte 4 passifs distincts.
## - Les passifs s'ajoutent aux tables de la run (Run.passives, Run.passive_power) : cumulables entre pièces, plafonnés
##   par effet (boon_cap) ; lus par Run.passive_stats / passive_procs comme les cartes communes.
## - Emplacements verrouillés à vie : une pièce posée ne se retire ni ne se remplace (equip refuse, Profile.equip /
##   unequip / equip_offhand / swap_weapons et la page d'inventaire de la pause aussi : locked).
## - Arme : n'importe lequel des 17 types, gardée à vie ; carte d'amélioration = +N, passif de palier et une amélioration
##   d'auto-attaque (WeaponAttacks.roll_upgrade, tirée à la proposition) fusionnée dans Run.weapon_ups["weapon"].
## Les pièces sont posées dans Profile.equipped SANS Profile.equip (ni préréglage, ni coffre du hub) : la fin de run
## remet l'équipement du hub (Profile.end_run_survival).

## Passifs fixes des pièces de set, par famille (SurvivorPool.family) : la pièce j (SET_SLOT_ORDER) du r-ième set de la
## famille prend l'effet (r × 5 + j) modulo la taille de la liste : 5 effets consécutifs, donc tous différents dans un set.
const FAMILY_PASSIVES := {
	"str": ["sharpened", "brute", "giant_slayer", "heavy_finisher", "keen_edge", "battle_trance", "shockwave", "volatile",
		"executioner", "toughness", "vigor", "bloodthirst"],
	"agi": ["combo_flow", "precision", "swift_blade", "hunter_eye", "wind_step", "light_step", "multishot", "piercing",
		"ricochet", "long_reach", "ember", "keen_edge"],
	"int": ["arcana", "incantation", "wide_arc", "static_blade", "frost_edge", "echo", "deep_wounds", "lingering", "focus",
		"frost_nova", "momentum", "ember"],
	"wis": ["vigor", "toughness", "second_wind", "focus", "frost_nova", "magnet", "scholar", "fortune", "wind_step",
		"bloodthirst", "incantation", "light_step"],
}
## Passifs fixes des pièces hors set (rang du modèle dans l'emplacement, par numéro d'Eden croissant).
const SLOT_PASSIVES := {
	"back": ["toughness", "vigor", "second_wind", "wind_step", "light_step", "frost_nova", "magnet", "fortune"],
	"necklace": ["arcana", "focus", "incantation", "scholar", "echo", "static_blade", "deep_wounds", "lingering", "momentum"],
	"ring": ["precision", "keen_edge", "hunter_eye", "battle_trance", "sharpened", "giant_slayer", "brute", "ember", "fortune"],
}
## Passifs fixes des armes (auto-attaque) : rang du modèle + 3 × rang du type d'arme.
const WEAPON_PASSIVES := ["heavy_finisher", "combo_flow", "incantation", "multishot", "piercing", "ricochet", "shockwave",
	"long_reach", "wide_arc", "precision", "swift_blade", "deep_wounds"]
## Statistiques à unité entière ou déjà plafonnées : plafond du passif = son max (sinon 1,5 × max).
const WHOLE_STATS := ["proj", "pierce", "bounce", "area"]
## Pièces maudites (lot SVX-4, BM-SURV SV-R2) : une pièce tirée sur curse_every (profil « survivor ») porte une malédiction
## (champ `sv_curse`) : jet parfait, un gros bonus et sa contrepartie, écrits sur la carte (la contrepartie en fraise) ; la pièce
## est gardée à vie, la malédiction aussi. Jamais l'arme (le premier choix reste simple), jamais hors du Survivant.
## Effets sur le héros (apply_curses, crochet Survivor.cap_hero, avant les plafonds du mode) : dmg (dégâts ×), hp (PV max ×),
## atk_speed (vitesse d'attaque +), defense (défense ×), move (vitesse de déplacement ×), crit_dmg (dégâts critiques +), area
## (zone des sorts +), cdr (recharge : négatif = plus longue), pickup (rayon de ramassage ×). Valeurs mesurées : R_SVX4.
const CURSES := {
	"avide": {"name": "Lame avide", "bonus": {"dmg": 0.3}, "malus": {"hp": -0.25}},
	"titan": {"name": "Fardeau du titan", "bonus": {"hp": 0.5}, "malus": {"move": -0.15}},
	"fievre": {"name": "Hâte fébrile", "bonus": {"atk_speed": 0.3}, "malus": {"defense": -0.4}},
	"main_lourde": {"name": "Main lourde", "bonus": {"crit_dmg": 0.6}, "malus": {"atk_speed": -0.15}},
	"cyclope": {"name": "Œil du cyclope", "bonus": {"area": 0.25}, "malus": {"cdr": -0.15}},
	"aimant": {"name": "Aimant brisé", "bonus": {"dmg": 0.2}, "malus": {"pickup": -0.4}},
}
const CURSE_STAT_NAMES := {"dmg": "dégâts", "hp": "PV max", "atk_speed": "vitesse d'attaque", "defense": "défense",
	"move": "vitesse", "crit_dmg": "dégâts critiques", "area": "zone des sorts", "cdr": "recharge des sorts", "pickup": "ramassage"}

static var _rng := RandomNumberGenerator.new()
static var _seeded := false


static func _r(rng: RandomNumberGenerator) -> RandomNumberGenerator:
	if rng != null:
		return rng
	if not _seeded:
		_rng.randomize()
		_seeded = true
	return _rng


# --- passifs fixes ----------------------------------------------------------------------------------------------------
## Passif fixe du modèle d'Eden [param e] (pièce de set, pièce hors set ou arme) ; "" si aucun.
## [param any_model] (Battle royale, pièces des coffres de tout niveau) : un modèle hors du pool du Survivant prend son
## rang d'après son numéro d'Eden (toujours le même passif pour le même modèle) au lieu du premier de la liste.
static func fixed_passive(e: Dictionary, any_model := false) -> String:
	if e.is_empty():
		return ""
	var sid := String(e.get("set", ""))
	if sid != "" and sid in SurvivorPool.sets():
		var fam := SurvivorPool.family(sid)
		var same: Array = SurvivorPool.sets().filter(func(s): return SurvivorPool.family(String(s)) == fam)
		var pool := _existing(FAMILY_PASSIVES[fam])
		var j := SurvivorPool.SET_SLOT_ORDER.find(String(e.slot))
		return String(pool[(same.find(sid) * SurvivorPool.SET_SLOT_ORDER.size() + maxi(j, 0)) % pool.size()]) if not pool.is_empty() else ""
	if e.has("wtype"):
		var wt := String(e.wtype)
		var pool := _existing(WEAPON_PASSIVES)
		var rank := _rank(SurvivorPool.weapons(wt), e, any_model)
		return String(pool[(rank + 3 * maxi(SurvivorPool.weapon_types().find(wt), 0)) % pool.size()]) if not pool.is_empty() else ""
	var pool2 := _existing(SLOT_PASSIVES.get(String(e.slot), Cards.PASSIVE_EFFECTS))
	return String(pool2[_rank(SurvivorPool.pieces(String(e.slot)), e, any_model) % pool2.size()]) if not pool2.is_empty() else ""


static func _existing(ids: Array) -> Array:
	var ok := Cards.passive_effects()
	return ids.filter(func(id): return id in ok)


## Rang du modèle [param e] dans [param list], par numéro d'Eden croissant (0 s'il n'y est pas ; son numéro d'Eden avec
## [param by_id]).
static func _rank(list: Array, e: Dictionary, by_id := false) -> int:
	var ids: Array = list.map(func(x): return int(x.id))
	ids.sort()
	var i := ids.find(int(e.id))
	return i if i >= 0 else (absi(int(e.get("id", 0))) if by_id else 0)


## Ids des passifs d'une pièce (fixe puis paliers).
static func passives_of(item: Dictionary) -> Array:
	return (item.get("sv_passives", []) as Array).map(func(p): return String(p.id))


## Lignes des passifs d'une pièce (cartes, page Build) : « Lame large : Rayon des zones +14 % », avec le palier.
static func passive_lines(item: Dictionary) -> PackedStringArray:
	var out: PackedStringArray = []
	for p in item.get("sv_passives", []):
		var at := int(p.get("at", 0))
		out.append(("%s%s" % ["" if at == 0 else "+%d · " % at, Cards.effect_line(String(p.id), float(p.get("power", 1.0)))]))
	return out


# --- fabrication -------------------------------------------------------------------------------------------------------
## Qualité tirée : de quality_min à perfect_quality (100 à 120 %), par pas de 1 %, uniforme.
static func roll_quality(rng: RandomNumberGenerator = null) -> float:
	var lo := roundi(Survivor.rule("quality_min") * 100.0)
	var hi := roundi(Survivor.rule("perfect_quality") * 100.0)
	return float(_r(rng).randi_range(lo, maxi(lo, hi))) / 100.0


## Pièce du Survivant tirée du modèle d'Eden [param e] : stats d'origine, qualité, passif fixe.
static func from_eden(e: Dictionary, rng: RandomNumberGenerator = null) -> Dictionary:
	if e.is_empty():
		return {}
	var item := Items.from_template(e, maxi(Run.hero_level, 1), int(e.rarity))
	item.erase("passive")  # passifs d'arme d'Eden : remplacés par les passifs du Survivant
	if not String(e.get("set", "")) in SurvivorPool.sets():
		item.erase("set")
	item["sv"] = true
	item["quality"] = roll_quality(rng)
	item["upgrade"] = 0
	var fp := fixed_passive(e)
	item["sv_passives"] = [{"id": fp, "at": 0, "power": Survivor.rule("passive_power")}] if fp != "" else []
	maybe_curse(item, rng)
	return item


# --- pièces maudites (lot SVX-4, SV-R2) ------------------------------------------------------------------------------
## Maudit [param item] une fois sur curse_every (Survivant seulement, jamais l'arme) : malédiction tirée, jet parfait.
static func maybe_curse(item: Dictionary, rng: RandomNumberGenerator = null) -> void:
	var every := Survivor.rule("curse_every")
	if not Survivor.active or every <= 0.0 or String(item.get("slot", "")) == "weapon" or item.has("wtype"):
		return
	var r := _r(rng)
	if r.randf() >= 1.0 / every:
		return
	curse(item, String(CURSES.keys()[r.randi() % CURSES.size()]))


## Pose la malédiction [param id] sur [param item] (tests, tirage) : jet parfait.
static func curse(item: Dictionary, id: String) -> void:
	if not CURSES.has(id):
		return
	item["sv_curse"] = id
	item["quality"] = Survivor.rule("perfect_quality")


## Malédictions portées (ids, une par pièce maudite).
static func curses_worn() -> Array:
	var out: Array = []
	for it in Profile.equipped.values():
		if (it as Dictionary).has("sv_curse") and CURSES.has(String(it.sv_curse)):
			out.append(String(it.sv_curse))
	return out


## Effet cumulé des malédictions portées : {clé : somme des parts}.
static func curse_totals() -> Dictionary:
	var out := {}
	for id in curses_worn():
		var c: Dictionary = CURSES[id]
		for part in [c.bonus, c.malus]:
			for k in part:
				out[k] = float(out.get(k, 0.0)) + float(part[k])
	return out


## Applique les malédictions portées au héros [param p] (crochet de Survivor.cap_hero, Survivant seulement).
static func apply_curses(p: Object) -> void:
	var t := curse_totals()
	if t.is_empty():
		return
	p.dmg_mult = maxf(0.1, float(p.dmg_mult) * (1.0 + float(t.get("dmg", 0.0))))
	p.max_hp = maxf(1.0, float(p.max_hp) * (1.0 + float(t.get("hp", 0.0))))
	p.atk_speed = maxf(0.3, float(p.atk_speed) + float(t.get("atk_speed", 0.0)))
	p.defense = maxf(0.0, float(p.defense) * (1.0 + float(t.get("defense", 0.0))))
	p.move_mult = maxf(0.3, float(p.move_mult) * (1.0 + float(t.get("move", 0.0))))
	p.crit_dmg = float(p.crit_dmg) + float(t.get("crit_dmg", 0.0))
	p.area_mult = maxf(0.3, float(p.area_mult) + float(t.get("area", 0.0)))
	p.cdr = clampf(float(p.cdr) + float(t.get("cdr", 0.0)), -0.5, 0.5)
	p.pickup_mult = maxf(0.2, float(p.pickup_mult) * (1.0 + float(t.get("pickup", 0.0))))


## Texte d'une part de malédiction : « +30 % dégâts », « PV max −25 % » (sur la carte : les nombres sont le choix).
static func curse_part_text(part: Dictionary, bonus: bool) -> String:
	var out: PackedStringArray = []
	for k in part:
		var v := float(part[k])
		var name := String(CURSE_STAT_NAMES.get(k, k))
		if k == "cdr":
			v = -v  # (recharge : une part négative allonge la recharge)
		var pct := "%d %%" % roundi(absf(v) * 100.0)
		out.append(("+%s %s" % [pct, name]) if bonus else ("%s %s%s" % [name.substr(0, 1).to_upper() + name.substr(1), "+" if v > 0.0 else "−", pct]))
	return " · ".join(out)


## {name, bonus, malus} de la malédiction de [param item] ({} : pièce saine).
static func curse_info(item: Dictionary) -> Dictionary:
	var id := String(item.get("sv_curse", ""))
	if not CURSES.has(id):
		return {}
	var c: Dictionary = CURSES[id]
	return {"id": id, "name": String(c.name), "bonus": curse_part_text(c.bonus, true), "malus": curse_part_text(c.malus, false)}


## Pièce venue d'ailleurs (coffre du Battle royale) faite pièce « à la Survivant » : rareté, niveau et stats gardés,
## puissance au niveau du héros (`sv`), jet de qualité de 100 à 120 % (tiré, ou le sien ramené dans la fourchette avec
## [param keep_quality]), passif fixe de son modèle (fixed_passive, any_model) ; le passif d'Eden est remplacé. Hors
## Survivant : ni verrou ni bonus de set du Survivant (Survivor.active).
static func adopt(item: Dictionary, rng: RandomNumberGenerator = null, keep_quality := false) -> Dictionary:
	if item.is_empty():
		return item
	item.erase("passive")
	item["sv"] = true
	var lo := Survivor.rule("quality_min")
	var hi := Survivor.rule("perfect_quality")
	item["quality"] = clampf(float(item.get("quality", 1.0)), lo, hi) if keep_quality else roll_quality(rng)
	if not item.has("sv_passives"):
		var e: Dictionary = GameData.eden_by_id.get(int(item.get("eden", -1)), {})
		var fp := fixed_passive(e, true) if not e.is_empty() else ""
		var all := Cards.passive_effects()
		var guard := 0
		while fp != "" and ("passive:" + fp) in Run.banned and guard < all.size():
			guard += 1
			fp = String(all[(all.find(fp) + 1) % all.size()])  # passif banni de la partie : le suivant de la liste
		item["sv_passives"] = [{"id": fp, "at": 0, "power": Survivor.rule("passive_power")}] if fp != "" else []
	return item


## Retire de la run les passifs de [param item] (pièce enlevée : Battle royale, pièce tombée ou échangée). Le plafond
## d'un passif n'est pas rejoué : on retire la puissance de la pièce, sans descendre sous zéro.
static func release(item: Dictionary) -> void:
	for p in item.get("sv_passives", []):
		var id := String(p.id)
		if not Run.passives.has(id):
			continue
		Run.passive_power[id] = maxf(0.0, float(Run.passive_power.get(id, 0.0)) - float(p.get("power", 1.0)))
		Run.passives[id] = int(Run.passives[id]) - 1
		if int(Run.passives[id]) <= 0 or float(Run.passive_power[id]) <= 0.0001:
			Run.passives.erase(id)
			Run.passive_power.erase(id)
	Run.changed.emit()


## Nouvelle pièce pour l'emplacement [param slot] ({} : aucune). [param ctx] : rng, eden (modèle imposé), et le contexte
## de tirage de SurvivorPool.draw (armor, worn, banned, exclude ; défaut : SurvivorPool.context()).
static func make_piece(slot: String, ctx := {}) -> Dictionary:
	var rng: RandomNumberGenerator = _r(ctx.get("rng"))
	var e: Dictionary = GameData.eden_by_id.get(int(ctx.get("eden", 0)), {})
	if e.is_empty():
		e = SurvivorPool.draw(slot, rng, ctx if ctx.has("worn") else SurvivorPool.context(ctx))
	return from_eden(e, rng)


## [param n] pièces pour [param slot], jamais deux du même set (cartes d'un coffre d'emplacement, gardien…).
static func piece_offers(slot: String, n: int, ctx := {}) -> Array:
	var rng: RandomNumberGenerator = _r(ctx.get("rng"))
	var out: Array = []
	for e in SurvivorPool.draw_many(slot, n, rng, ctx if ctx.has("worn") else SurvivorPool.context(ctx)):
		out.append({"type": "sv_piece", "slot": slot, "item": from_eden(e, rng)})
	return out


## Nouvelle arme du type [param wtype] ({} : aucune) : modèle de niveau 90 du type, variante d'auto-attaque au hasard.
static func make_weapon(wtype: String, ctx := {}) -> Dictionary:
	var rng: RandomNumberGenerator = _r(ctx.get("rng"))
	var list := SurvivorPool.weapons(wtype)
	if list.is_empty():
		return {}
	var item := from_eden(list[rng.randi() % list.size()], rng)
	item["wtype"] = wtype
	item["auto_variant"] = rng.randi() % maxi(WeaponAttacks.variants(wtype).size(), 1)
	return item


## Offre d'armes du premier choix (S3) : [param n] armes de types différents ; le type de la classe ×2, les types de même
## nature de dégâts ×1,5 (SPEC §4.1).
static func weapon_offers(n := 3, ctx := {}) -> Array:
	var rng: RandomNumberGenerator = _r(ctx.get("rng"))
	var cid := String(ctx.get("class", Run.class_id if Run.class_id != "" else Profile.selected_class))
	var own := Items.default_weapon_type(cid)
	var dmg := String(GameData.weapon_type(own).get("dmg_type", "phys"))
	var types: Array = SurvivorPool.weapon_types().filter(func(w): return not SurvivorPool.weapons(String(w)).is_empty())
	var out: Array = []
	while out.size() < n and not types.is_empty():
		var ws: Array = types.map(func(w): return 2.0 if w == own else (1.5 if String(GameData.weapon_type(String(w)).get("dmg_type", "phys")) == dmg else 1.0))
		var total := 0.0
		for w in ws:
			total += float(w)
		var r := rng.randf() * total
		var pick := 0
		for i in ws.size():
			r -= float(ws[i])
			if r <= 0.0:
				pick = i
				break
		var wt := String(types[pick])
		types.remove_at(pick)
		out.append({"type": "sv_weapon", "slot": "weapon", "wtype": wt, "item": make_weapon(wt, {"rng": rng})})
	return out


# --- équipement verrouillé ------------------------------------------------------------------------------------------
## Pièce du Survivant posée dans [param slot] (verrouillée jusqu'à la fin de la run) ?
static func locked(slot: String) -> bool:
	return Survivor.active and bool((Profile.equipped.get(slot, {}) as Dictionary).get("sv", false))


## L'objet [param item] est-il une pièce verrouillée (portée en Survivant) ?
static func item_locked(item: Dictionary) -> bool:
	return Survivor.active and bool(item.get("sv", false)) and is_same(Profile.equipped.get(String(item.get("slot", "")), {}), item)


## Texte du verrou (infobulle, bouton).
const LOCK_TEXT := "Gardée toute la partie"


## Porte [param item] pour toute la run (emplacement verrouillé) ; faux si l'emplacement est déjà pris. Ses passifs
## s'ajoutent à la run.
static func equip(item: Dictionary) -> bool:
	if item.is_empty():
		return false
	var slot := String(item.get("slot", ""))
	if not slot in Items.SLOTS or (Profile.equipped.get(slot, {}) as Dictionary).get("sv", false):
		return false
	item["sv"] = true
	Profile.equipped[slot] = item
	if slot == "weapon":
		Run.weapon_ups["weapon"] = {}
	for p in item.get("sv_passives", []):
		_grant(String(p.id), float(p.get("power", 1.0)))
	Profile.changed.emit()
	Run.changed.emit()
	return true


## Emplacements encore libres (Items.SLOTS).
static func free_slots() -> Array:
	return Items.SLOTS.filter(func(s): return not Profile.equipped.has(s))


## Pièces portées.
static func worn() -> Array:
	return Profile.equipped.values()


# --- passifs de la run ------------------------------------------------------------------------------------------------
## Plafond de puissance du passif [param id] (en cartes communes) : son max pour les statistiques à unité entière ou
## déjà plafonnées (projectiles, perforation, rebonds, zone), passive_cap_mult (1,5) × max sinon.
static func boon_cap(id: String) -> float:
	var d := Boons.get_def(id)
	if d.is_empty():
		return 0.0
	var mx := float(d.get("max", 10))
	var whole := (d.get("stat", {}) as Dictionary).keys().any(func(k): return k in WHOLE_STATS)
	return mx if whole else mx * Survivor.rule("passive_cap_mult")


## Ajoute [param power] au passif [param id] de la run, au plus jusqu'à son plafond ; renvoie la puissance ajoutée.
static func _grant(id: String, power: float) -> float:
	if id == "":
		return 0.0
	var cur := float(Run.passive_power.get(id, Run.passives.get(id, 0)))
	var add := clampf(boon_cap(id) - cur, 0.0, power)
	Run.passives[id] = int(Run.passives.get(id, 0)) + 1
	Run.passive_power[id] = cur + add
	return add


## Passif du palier [param tier] (+6, +8 ou +10) de [param piece] : tiré parmi les effets que la pièce n'a pas (ni le
## fixe ni ceux des paliers déjà acquis) et hors [param exclude] ; les effets déjà au plafond dans la run en dernier
## recours. "" si plus rien n'est possible.
static func roll_tier_passive(piece: Dictionary, tier: int, rng: RandomNumberGenerator = null, exclude := []) -> String:
	var own := passives_of(piece)
	var cands: Array = Cards.passive_effects().filter(func(id): return not id in own and not id in exclude)
	var open: Array = cands.filter(func(id): return float(Run.passive_power.get(id, 0.0)) < boon_cap(String(id)) - 0.001)
	var pool := open if not open.is_empty() else cands
	if pool.is_empty() or not tier in Survivor.WAKE_AT:
		return ""
	return String(pool[_r(rng).randi() % pool.size()])


## Offre d'amélioration de la pièce de [param slot] (carte « Amélioration de pièce » ou « d'arme », S3) : +[param step],
## et pour chaque palier +6 / +8 / +10 franchi, le passif tiré MAINTENANT (affiché sur la carte ; une relance ou un
## bannissement tirent une autre offre). Arme : l'amélioration d'auto-attaque tirée aussi. {} si la pièce est au maximum.
## {type, slot, uid, from, to, tier, passives: [{at, id, power}], auto?}. [param exclude] : passifs jamais tirés (bannis, S3).
static func upgrade_offer(slot: String, card_tier := "common", rng: RandomNumberGenerator = null, step := Survivor.UP_STEP, exclude: Array = []) -> Dictionary:
	var item: Dictionary = Profile.equipped.get(slot, {})
	var from := int(item.get("upgrade", 0))
	if item.is_empty() or from >= Items.MAX_UPGRADE:
		return {}
	var to := mini(from + maxi(step, 1), Items.MAX_UPGRADE)
	var offer := {"type": "sv_weapon_up" if slot == "weapon" else "sv_piece_up", "slot": slot, "uid": String(item.get("uid", "")),
		"from": from, "to": to, "tier": card_tier, "passives": []}
	var taken: Array = exclude.duplicate()
	for at in Survivor.WAKE_AT:
		if from < int(at) and int(at) <= to:
			var id := roll_tier_passive(item, int(at), rng, taken)
			if id != "":
				taken.append(id)
				offer.passives.append({"at": int(at), "id": id, "power": Survivor.rule("passive_power") * Cards.tier_mult(card_tier)})
	if slot == "weapon":
		offer["auto"] = WeaponAttacks.roll_upgrade(WeaponAttacks.spec_for(item), card_tier, Run.weapon_ups.get("weapon", {}))
	return offer


## L'offre est-elle encore valable (même pièce, même +N) ?
static func offer_valid(offer: Dictionary) -> bool:
	var item: Dictionary = Profile.equipped.get(String(offer.get("slot", "")), {})
	return not item.is_empty() and String(item.get("uid", "")) == String(offer.get("uid", "")) and int(item.get("upgrade", 0)) == int(offer.get("from", -1))


## Applique une offre d'amélioration : +N, passifs des paliers (ajoutés à la run), auto-attaque de l'arme.
## {text, woke : nombre de passifs gagnés} ; texte vide si l'offre n'est plus valable.
static func apply_upgrade(offer: Dictionary) -> Dictionary:
	if not offer_valid(offer):
		return {"text": "", "woke": 0}
	var slot := String(offer.slot)
	var item: Dictionary = Profile.equipped[slot]
	item["upgrade"] = int(offer.to)
	var list: Array = item.get("sv_passives", [])
	for p in offer.get("passives", []):
		if String(p.id) in passives_of(item):
			continue
		list.append({"id": String(p.id), "at": int(p.at), "power": float(p.power)})
		_grant(String(p.id), float(p.power))
	item["sv_passives"] = list
	if slot == "weapon" and offer.has("auto"):
		var cur: Dictionary = Run.weapon_ups.get("weapon", {})
		WeaponAttacks.merge_upgrade(cur, offer.auto)
		cur["rank"] = int(item.upgrade)  # le niveau de l'auto-attaque suit le +N de l'arme (effet légendaire à +4)
		if int(cur.rank) >= WeaponAttacks.SIG_RANK:
			cur["sig"] = true
		Run.weapon_ups["weapon"] = cur
	Profile.changed.emit()
	Run.changed.emit()
	var woke := (offer.get("passives", []) as Array).size()
	return {"text": "%s +%d → +%d" % [Items.SLOT_NAMES.get(slot, slot), int(offer.from), int(offer.to)], "woke": woke}


## Amélioration directe de la pièce de [param slot] (enclume, tests) : offre tirée puis appliquée.
static func upgrade(slot: String, tier: String) -> Dictionary:
	return apply_upgrade(upgrade_offer(slot, tier))


## Passifs gagnés par [param item] (fixe compris).
static func wake(item: Dictionary) -> int:
	return (item.get("sv_passives", []) as Array).size()


## Qualité maximale (jet parfait).
static func is_perfect(item: Dictionary) -> bool:
	return float(item.get("quality", 1.0)) >= Survivor.rule("perfect_quality") - 0.0001
