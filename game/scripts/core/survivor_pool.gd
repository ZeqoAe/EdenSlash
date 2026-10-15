class_name SurvivorPool
extends RefCounted
## Ce que les cartes du Survivant peuvent proposer (lot S2, DECISIONS_JOUEUR §1 et §5, qui priment sur SPEC §3.5 et §7.1) :
## rien ne dépend de la collection du compte.
## - Pièces : TOUTES les pièces des sets d'Eden de niveau 90 (13 sets de 5 pièces : tête, torse, jambes, gants, bottes ;
##   plates, cuir, tissu). Les emplacements qu'aucun set ne couvre (cape, collier, bague) prennent les pièces de niveau 90
##   hors set, mythiques et légendaires. Le type d'armure de la classe (ClassGear.profile().armor) est proposé plus
##   souvent (armor_pref), jamais exclusivement.
## - Armes : les 17 types (WeaponAttacks.SPECS), modèles de niveau 90 du type.
## - Passifs : Cards.passive_effects() (effets des cartes communes).
## - Panoplies : bonus du Survivant à 2, 3 et 5 pièces (set_def), règle par famille (attribut dominant du set) et type
##   d'armure, actifs seulement en Survivant (crochet de Items.set_def).
## - Mélange des propositions (draw / draw_many) : une offre de plusieurs pièces n'a jamais deux pièces du même set ;
##   un set dont le héros porte déjà 3 pièces ou plus est proposé moins souvent (set_damp : le palier 3 est l'objectif
##   courant, le 5/5 la récompense rare) ; un set banni (S3) jamais.
##   Fréquence du 5/5 mesurée par tools/sv_set_sim.gd (cible : 1 run sur 20 à 30 pour un joueur qui cherche un set).

const LEVEL := 90  # niveau d'Eden des pièces du Survivant
const SET_SLOT_ORDER := ["head", "chest", "legs", "gloves", "boots"]  # ordre d'un set (table des passifs fixes)
const ARMOR_FR := {"plates": "plates", "cuir": "cuir", "tissu": "tissu"}
## Familles de set (attribut dominant des pièces) : nom affiché et bonus. 2 pièces : la statistique de la famille ;
## 3 pièces : les deux statistiques propres au set (SIG_VALUES) ; 5 pièces : bonus fort + effet déclenché de la famille +
## statistique du type d'armure (ARMOR_BONUS).
const FAMILIES := {
	"str": {"name": "Assaut", "two": {"atk_pct": 0.06}, "five": {"dmg_pct": 0.15},
		"proc": {"trigger": "basic_hit", "chance": 0.3, "cd": 1.5, "effect": "explosion", "mult": 2.5, "radius": 5.0}},
	"agi": {"name": "Vivacité", "two": {"atk_speed": 0.08}, "five": {"atk_speed": 0.12},
		"proc": {"trigger": "crit", "chance": 0.5, "cd": 1.0, "effect": "lightning", "mult": 1.5, "chain": 5, "radius": 8.0}},
	"int": {"name": "Sortilège", "two": {"matk_pct": 0.08}, "five": {"area": 0.2},
		"proc": {"trigger": "skill_hit", "chance": 0.35, "cd": 1.5, "effect": "echo", "mult": 0.8}},
	"wis": {"name": "Grâce", "two": {"hp_pct": 0.08}, "five": {"hp_pct": 0.15, "heal_pct": 0.2},
		"proc": {"trigger": "hurt", "chance": 1.0, "cd": 10.0, "effect": "buff", "status": "barrier", "duration": 3.0,
			"then": [{"effect": "heal", "amount": 0.1}]}},
}
## Valeur au palier 3 de chaque statistique propre à un set (les deux stats hors attributs, PV et défense de ses pièces).
const SIG_VALUES := {"crit": 0.04, "mcrit": 0.04, "atk_speed": 0.06, "cdr": 0.05, "eva": 0.03, "parry": 0.04,
	"dmg_pct": 0.05, "crit_dmg": 0.15, "move_speed": 0.05, "def_pct": 0.08, "cast_speed": 0.06, "hp_pct": 0.06}
## Statistique du palier 5 selon le type d'armure.
const ARMOR_BONUS := {"plates": {"def_pct": 0.1}, "cuir": {"move_speed": 0.06}, "tissu": {"cdr": 0.06}}
## Sets signature : bonus écrits à la main qui remplacent la règle (aucun pour l'instant ; set -> {2: …, 3: …, 5: …}).
const SIGNATURE := {}

static var _built := false
static var _sets: Array = []  # ids des sets de niveau 90 (triés)
static var _by_slot: Dictionary = {}  # emplacement -> modèles d'Eden proposables
static var _weapons: Dictionary = {}  # type d'arme -> modèles d'Eden de niveau 90
static var _set_defs: Dictionary = {}  # set -> définition du Survivant (cache)


static func _build() -> void:
	if _built:
		return
	_built = true
	_sets = []
	_by_slot = {}
	_weapons = {}
	_set_defs = {}
	for sid in GameData.eden_sets:
		var pieces := _pieces_of(String(sid))
		if pieces.is_empty() or not pieces.all(func(e): return int(e.level) == LEVEL and not (e.get("r", {}) as Dictionary).is_empty()):
			continue
		_sets.append(String(sid))
		for e in pieces:
			_add(String(e.slot), e)
	_sets.sort_custom(func(a, b): return int(String(a).trim_prefix("e")) < int(String(b).trim_prefix("e")))
	# emplacements qu'aucun set ne couvre : pièces de niveau 90 hors set, mythiques et légendaires
	for slot in Items.SLOTS:
		if slot == "weapon" or _by_slot.has(slot):
			continue
		for e in GameData.eden_by_slot.get(slot, []):
			if int(e.level) == LEVEL and int(e.rarity) >= Items.MYTHIC and not e.has("set") and not e.has("nopool") \
					and not (e.get("r", {}) as Dictionary).is_empty():
				_add(slot, e)
	for wtype in WeaponAttacks.SPECS:
		var list: Array = GameData.eden_by_slot.get(String(wtype), []).filter(
			func(e): return int(e.rarity) >= Items.MYTHIC and not (e.get("r", {}) as Dictionary).is_empty() and not e.has("nopool"))
		var top := 0
		for e in list:
			top = maxi(top, mini(int(e.level), LEVEL))
		_weapons[String(wtype)] = list.filter(func(e): return int(e.level) == top)


static func _add(slot: String, e: Dictionary) -> void:
	if not _by_slot.has(slot):
		_by_slot[slot] = []
	_by_slot[slot].append(e)


static func _pieces_of(sid: String) -> Array:
	var out: Array = []
	for pid in GameData.eden_sets.get(sid, {}).get("pieces", []):
		var e: Dictionary = GameData.eden_by_id.get(int(pid), {})
		if not e.is_empty():
			out.append(e)
	return out


## Recalcule le pool (catalogue modifié en mode dev, tests).
static func reset_cache() -> void:
	_built = false


# --- contenu --------------------------------------------------------------------------------------------------------
## Sets de niveau 90 (ids « e… »), dans l'ordre du catalogue.
static func sets() -> Array:
	_build()
	return _sets


## Pièces (modèles d'Eden) d'un set du Survivant, dans l'ordre SET_SLOT_ORDER.
static func set_pieces(sid: String) -> Array:
	var out := _pieces_of(sid)
	out.sort_custom(func(a, b): return SET_SLOT_ORDER.find(String(a.slot)) < SET_SLOT_ORDER.find(String(b.slot)))
	return out


## Modèles d'Eden proposables pour l'emplacement [param slot] (hors arme).
static func pieces(slot: String) -> Array:
	_build()
	return _by_slot.get(slot, [])


## Emplacements hors arme qui ont des pièces (les 8 normalement).
static func slots() -> Array:
	_build()
	return Items.SLOTS.filter(func(s): return s != "weapon" and _by_slot.has(s))


## Emplacements couverts par les sets.
static func set_slots() -> Array:
	_build()
	var out: Array = []
	for sid in _sets:
		for e in _pieces_of(sid):
			if not String(e.slot) in out:
				out.append(String(e.slot))
	return out


## Types d'arme proposables : les 17 du jeu.
static func weapon_types() -> Array:
	return WeaponAttacks.SPECS.keys()


## Modèles d'Eden de niveau 90 du type d'arme [param wtype].
static func weapons(wtype: String) -> Array:
	_build()
	return _weapons.get(wtype, [])


## Passifs proposables (ids de Boons) : les effets réutilisables des cartes communes.
static func boons() -> Array:
	return Cards.passive_effects()


## Type d'armure d'un set (« plates », « cuir », « tissu ») ; "" si inconnu.
static func armor_of(sid: String) -> String:
	var p := _pieces_of(sid)
	return String(p[0].get("armor", "")) if not p.is_empty() else ""


## Famille d'un set : l'attribut dominant (somme des statistiques de ses pièces) parmi Force, Agilité, Intelligence,
## Sagesse (la Chance, présente partout, ne compte pas).
static func family(sid: String) -> String:
	var tot := {}
	for e in _pieces_of(sid):
		for k in ["str", "agi", "int", "wis"]:
			tot[k] = float(tot.get(k, 0.0)) + float(e.get("r", {}).get(k, 0.0))
	var best := "str"
	for k in ["str", "agi", "int", "wis"]:
		if float(tot.get(k, 0.0)) > float(tot.get(best, 0.0)) + 0.001:
			best = k
	return best


## Les deux statistiques propres au set (hors attributs, PV, défense), de la plus présente à la moins présente.
static func signature_stats(sid: String) -> Array:
	var tot := {}
	for e in _pieces_of(sid):
		for k in e.get("r", {}):
			if SIG_VALUES.has(String(k)):
				tot[String(k)] = float(tot.get(String(k), 0.0)) + float(e.r[k])
	var keys := tot.keys()
	keys.sort_custom(func(a, b): return float(tot[a]) > float(tot[b]) or (is_equal_approx(float(tot[a]), float(tot[b])) and String(a) < String(b)))
	return keys.slice(0, 2)


## Nom affiché d'un set : son nom (français si traduit) ; sans nom propre (« Panoplie 447 »), la fin commune des noms de
## ses pièces (« Casque du Gardien resplendissant », « Bottes du Gardien resplendissant » -> « Gardien resplendissant »).
static func panoply_name(sid: String) -> String:
	var n := String(GameData.eden_sets.get(sid, {}).get("name", ""))
	if n != "" and not n.begins_with("Set ") and not n.right(1).is_valid_int():
		return n
	var p := set_pieces(sid)
	if p.is_empty():
		return n
	var common: Array = String(p[0].name).split(" ")
	for e in p:
		var w: Array = String(e.name).split(" ")
		var k := 0
		while k < mini(common.size(), w.size()) and common[common.size() - 1 - k] == w[w.size() - 1 - k]:
			k += 1
		common = common.slice(common.size() - k)
	while not common.is_empty() and String(common[0]) in ["du", "de", "des", "la", "le", "les"]:
		common.remove_at(0)
	if common.is_empty():
		return n
	var out := " ".join(common)
	return out.substr(0, 1).to_upper() + out.substr(1)


## Définition d'un set dans le Survivant (Items.set_def, quand Survivor.active) : {name, pieces, bonus: {2, 3, 5}} ;
## {} si ce n'est pas un set du Survivant.
static func set_def(sid: String) -> Dictionary:
	_build()
	if not sid in _sets:
		return {}
	if _set_defs.has(sid):
		return _set_defs[sid]
	var base: Dictionary = GameData.eden_sets.get(sid, {})
	var bonus: Dictionary = SIGNATURE.get(sid, {})
	if bonus.is_empty():
		var fam: Dictionary = FAMILIES[family(sid)]
		var three := {}
		for k in signature_stats(sid):
			three[k] = float(SIG_VALUES[k])
		var five: Dictionary = (fam.five as Dictionary).duplicate()
		for k in ARMOR_BONUS.get(armor_of(sid), {}):
			five[k] = float(five.get(k, 0.0)) + float(ARMOR_BONUS[armor_of(sid)][k])
		bonus = {2: {"stat": (fam.two as Dictionary).duplicate()}, 3: {"stat": three},
			5: {"stat": five, "procs": [(fam.proc as Dictionary).duplicate(true)]}}
	var d := {"name": panoply_name(sid), "pieces": base.get("pieces", []), "bonus": bonus, "family": family(sid),
		"armor": armor_of(sid), "sv": true}
	_set_defs[sid] = d
	return d


## Chiffres du pool (rapport, test) : sets, pièces par emplacement, variantes visuelles (icônes distinctes), armes.
static func summary() -> Dictionary:
	_build()
	var per_slot := {}
	var looks := {}
	for slot in _by_slot:
		per_slot[slot] = (_by_slot[slot] as Array).size()
		var icons := {}
		for e in _by_slot[slot]:
			icons[String(e.icon)] = true
		looks[slot] = icons.size()
	var armors := {}
	var fams := {}
	for sid in _sets:
		armors[armor_of(sid)] = int(armors.get(armor_of(sid), 0)) + 1
		fams[family(sid)] = int(fams.get(family(sid), 0)) + 1
	var wcount := {}
	for w in _weapons:
		wcount[w] = (_weapons[w] as Array).size()
	return {"sets": _sets.size(), "pieces": per_slot, "looks": looks, "armors": armors, "families": fams, "weapons": wcount}


# --- tirage des propositions ------------------------------------------------------------------------------------------
## Poids d'un modèle [param e] dans un tirage. [param ctx] : armor (type préféré), worn (set -> pièces portées),
## banned (sets bannis), exclude (sets et ids d'Eden déjà dans l'offre).
static func weight(e: Dictionary, ctx: Dictionary) -> float:
	var sid := String(e.get("set", ""))
	if sid != "" and sid in ctx.get("banned", []):
		return 0.0
	if int(e.id) in ctx.get("exclude", []) or (sid != "" and sid in ctx.get("exclude", [])):
		return 0.0
	var w := 1.0
	if String(ctx.get("armor", "")) != "" and String(e.get("armor", "")) == String(ctx.armor):
		w *= Survivor.rule("armor_pref")
	if sid != "" and int(ctx.get("worn", {}).get(sid, 0)) >= int(Survivor.rule("set_damp_from")):
		w *= Survivor.rule("set_damp")  # 4e et 5e pièces d'un même set plus rares : le 5/5 reste exceptionnel
	return w


## Contexte de tirage par défaut : type d'armure de la classe jouée, sets portés.
static func context(extra := {}) -> Dictionary:
	var ctx := {"armor": String(ClassGear.profile(Run.class_id if Run.class_id != "" else Profile.selected_class).get("armor", "")),
		"worn": Items.set_counts(Profile.equipped), "banned": [], "exclude": []}
	ctx.merge(extra, true)
	return ctx


## Un modèle d'Eden pour [param slot] tiré au poids ({} : aucun).
static func draw(slot: String, rng: RandomNumberGenerator, ctx := {}) -> Dictionary:
	var list := pieces(slot)
	var total := 0.0
	var ws: Array = []
	for e in list:
		var w := weight(e, ctx)
		ws.append(w)
		total += w
	if total <= 0.0:
		return {}
	var r := rng.randf() * total
	for i in list.size():
		r -= float(ws[i])
		if r <= 0.0 and float(ws[i]) > 0.0:
			return list[i]
	for i in range(list.size() - 1, -1, -1):
		if float(ws[i]) > 0.0:
			return list[i]
	return {}


## [param n] modèles distincts pour [param slot], jamais deux du même set (mélange des propositions).
static func draw_many(slot: String, n: int, rng: RandomNumberGenerator, ctx := {}) -> Array:
	var c := ctx.duplicate(true)
	var ex: Array = (c.get("exclude", []) as Array).duplicate()
	c["exclude"] = ex
	var out: Array = []
	for i in n:
		var e := draw(slot, rng, c)
		if e.is_empty():
			break
		out.append(e)
		ex.append(int(e.id))
		if e.has("set"):
			ex.append(String(e.set))
	return out
