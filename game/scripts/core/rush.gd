class_name Rush
extends RefCounted
## Ruée des boss (passe M6) : huit boss tirés de la bibliothèque (BossLibrary, 6 par zone), un par zone dans l'ordre des
## zones (le niveau monte de boss en boss en Normal et Héroïque ; en Mythique, tous au niveau 90, leurs PV montent avec
## MYTHIC_RAMP). Le tirage varie les mécaniques : deux boss qui se suivent ne partagent ni famille de mécaniques ni brique
## quand la zone le permet, et un boss de la Ruée précédente n'est repris que si sa zone n'a pas mieux. Il est fixé par une
## graine affichée sur la page (« Tirage n° 4821 ») : il reste le même tant que la Ruée n'est pas vaincue (on peut
## réessayer les mêmes boss), « Nouveau tirage » en donne un autre, une Ruée terminée aussi.
## Modificateurs au choix (MODS, idée de la passe M6) : plus durs, plus de cristaux.
##
## Moteur : celui des Donjons (Tower.rush, RushDirector qui prolonge TowerDirector). PV fixes du palier (passe P11 :
## BossLibrary.hp(id, niveau, palier, true) = Dungeons.boss_hp × RUSH_BOSS × le boss), carte et soin partiel entre deux.

const MODS := {
	"no_heal": {"name": "Sans répit", "desc": "Aucun soin entre deux boss.", "bonus": 0.3},
	"enraged": {"name": "Boss enragés", "desc": "Les boss frappent plus fort et lancent leurs mécaniques plus souvent.", "bonus": 0.4,
		"atk": 1.25, "pace": 0.85},
	"blind": {"name": "À l'aveugle", "desc": "Les boss à venir restent cachés.", "bonus": 0.15},
}
const MOD_ORDER := ["no_heal", "enraged", "blind"]
## PV des boss de la Ruée Mythique (tous au niveau 90) : × 0,8 pour le 1er jusqu'à × 1,2 pour le 8e.
const MYTHIC_RAMP := [0.8, 1.2]
## PE conseillée (rapport à la PE attendue au niveau du boss du milieu) : Normal, Héroïque, Mythique. Mesurée au pilote
## (conception/nuit_15_10/R_M6.md) : « Équilibré » avec l'équipement de l'époque II gagnée en Normal (≈ 11 500, l'époque où
## la Ruée s'ouvre), au verrou en Héroïque (≈ 42 600), à l'équipement complet optimisé en Mythique (≈ 61 200).
const ADVISED := [1.3, 3.7, 3.4]

static var seed := 0  # tirage de la Ruée en cours
static var lineup: Array = []  # ses huit boss (ids de BossLibrary), dans l'ordre
static var mods: Array = []  # ses modificateurs (MOD_ORDER)
static var _cache := {}  # graine -> tirage


# --- tirage -------------------------------------------------------------------------------------
## Graine du tirage proposé (Profile.records.rush_seed ; tirée la première fois).
static func current_seed() -> int:
	var s := int(Profile.records.get("rush_seed", 0))
	if s <= 0:
		s = _fresh_seed(0)
		Profile.records["rush_seed"] = s
	return s


## Nouveau tirage : les boss de l'actuel sont évités au suivant (quand leur zone en a d'autres).
static func reroll() -> int:
	var old := current_seed()
	Profile.records["rush_prev"] = _mask(lineup_for(old))
	_cache.clear()
	var s := _fresh_seed(old)
	Profile.records["rush_seed"] = s
	return s


static func _fresh_seed(old: int) -> int:
	var s := old
	while s == old:
		s = randi_range(1000, 9999)
	return s


## Les huit boss du tirage [param s] : un par zone (ordre des zones), mécaniques variées d'un boss au suivant.
static func lineup_for(s: int) -> Array:
	if _cache.has(s):
		return _cache[s]
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(["rush", s])
	var avoid := int(Profile.records.get("rush_prev", 0))
	var ids := BossLibrary.ids()
	var out: Array = []
	var fam_count := {}
	for zid in Dungeons.zone_ids():
		var pool: Array = BossLibrary.for_zone(String(zid))
		if pool.is_empty():
			continue
		var best := ""
		var best_score := INF
		for id in pool:
			var score := rng.randf() * 1.5
			if not out.is_empty():
				score += 3.0 * _shared(BossLibrary.families_of(out[-1]), BossLibrary.families_of(id))
				score += 2.0 * _shared(BossLibrary.brick_types(out[-1]), BossLibrary.brick_types(id))
			if out.size() >= 2:
				score += 1.0 * _shared(BossLibrary.families_of(out[-2]), BossLibrary.families_of(id))
			for f in BossLibrary.families_of(id):
				score += 0.6 * float(fam_count.get(f, 0))  # une famille déjà souvent vue pèse
			var bit := ids.find(id)
			if bit >= 0 and bit < 62 and (avoid >> bit) & 1 == 1:
				score += 2.5
			if score < best_score:
				best_score = score
				best = String(id)
		out.append(best)
		for f in BossLibrary.families_of(best):
			fam_count[f] = int(fam_count.get(f, 0)) + 1
	_cache[s] = out
	return out


static func _shared(a: Array, b: Array) -> int:
	var n := 0
	for x in a:
		if x in b:
			n += 1
	return n


## Ensemble de boss en bits (index dans BossLibrary.ids()).
static func _mask(list: Array) -> int:
	var ids := BossLibrary.ids()
	var m := 0
	for id in list:
		var bit := ids.find(id)
		if bit >= 0 and bit < 62:
			m |= 1 << bit
	return m


# --- modificateurs -----------------------------------------------------------------------------
## Modificateurs cochés sur la page (gardés d'une Ruée à l'autre).
static func chosen() -> Array:
	var bits := int(Profile.records.get("rush_mods", 0))
	return MOD_ORDER.filter(func(k): return (bits >> MOD_ORDER.find(k)) & 1 == 1)


static func toggle(mod: String) -> void:
	var i := MOD_ORDER.find(mod)
	if i >= 0:
		Profile.records["rush_mods"] = int(Profile.records.get("rush_mods", 0)) ^ (1 << i)


static func has(mod: String) -> bool:
	return mod in mods


## Cristaux de la Ruée en cours × ce facteur (1 + les bonus des modificateurs).
static func bonus(list: Array = mods) -> float:
	var b := 1.0
	for k in list:
		b += float(MODS.get(k, {}).get("bonus", 0.0))
	return b


static func atk_mult() -> float:
	return float(MODS.enraged.atk) if has("enraged") else 1.0


static func pace_mult() -> float:
	return float(MODS.enraged.pace) if has("enraged") else 1.0


# --- la Ruée en cours ---------------------------------------------------------------------------
## Début d'une Ruée (Tower.start_dungeon) : le tirage proposé et les modificateurs cochés.
static func start() -> void:
	seed = current_seed()
	lineup = lineup_for(seed).duplicate()
	mods = chosen()


static func reset() -> void:
	seed = 0
	lineup = []
	mods = []


## Boss [param f] (1 à 8) de la Ruée en cours ("" hors Ruée).
static func boss_at(f: int) -> String:
	if f < 1 or f > lineup.size():
		return ""
	return String(lineup[f - 1])


## Nom affiché du boss [param f] de la Ruée en cours : « ??? » à l'aveugle tant qu'il n'est pas devant toi
## ([param current] : l'étage du joueur).
static func shown_name(f: int, current: int) -> String:
	var id := boss_at(f)
	if id == "":
		return ""
	if has("blind") and f > current:
		return "???"
	return BossLibrary.short_name(id)


## PV du boss [param f] de la Ruée (niveau [param lvl], difficulté [param diff], [param allies] alliés).
static func boss_hp(f: int, lvl: int, diff: int, allies: int) -> float:
	var hp := BossLibrary.hp(boss_at(f), lvl, diff, true) * (1.0 + Dungeons.ALLY_HP_STEP * allies)
	if diff >= 2:
		hp *= lerpf(float(MYTHIC_RAMP[0]), float(MYTHIC_RAMP[1]), float(f - 1) / maxf(float(Dungeons.rush_floors() - 1), 1.0))
	return hp


## PE conseillée pour la Ruée en difficulté [param diff] (au moins la PE requise pour y entrer).
static func advised(diff: int) -> int:
	var lv := Dungeons.rush_level((Dungeons.rush_floors() + 1) / 2, diff)
	return maxi(GearPower.required(lv, float(ADVISED[clampi(diff, 0, 2)])), Dungeons.power_required(Dungeons.RUSH, diff))


## Ruée terminée (les huit boss tombés) : le tirage suivant sera neuf.
static func cleared() -> void:
	reroll()
