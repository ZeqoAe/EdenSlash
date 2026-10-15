class_name Challenge
extends RefCounted
## Défi du jour (lot 10, devenu l'une des trois quêtes du jour en passe M5, voir Quests) : une Survie de l'époque I par jour, avec deux modificateurs imposés et
## trois classes proposées dont au moins une peu maîtrisée. La maîtrise gagnée est doublée, et la
## première réussite du jour rapporte 600 points de plus ; les insignes sont ×1,5. Tout vient de la
## date : le même défi toute la journée.

const BONUS_FIRST := 600
const SURVIVAL_MODS := ["heal_half", "elites_double", "chests_plus", "one_life"]

static var active := false
static var mods: Array = []


static func today() -> String:
	return Quests.today()


static func _rng() -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = hash(today())
	return r


## Les deux modificateurs du jour.
static func modifiers_today() -> Array:
	var pool := SURVIVAL_MODS.duplicate()
	var r := _rng()
	var out: Array = []
	while out.size() < 2 and not pool.is_empty():
		out.append(pool.pop_at(r.randi() % pool.size()))
	return out


## Trois classes proposées : une parmi les moins maîtrisées, deux au hasard, de préférence en retard sur la meilleure
## classe (Economy.lagging) ; classes ouvertes seulement.
static func classes_today() -> Array:
	var open: Array = []
	for cid in GameData.classes:
		if Progression.class_unlocked(cid):
			open.append(cid)
	open.sort_custom(func(a, b): return Profile.expertise_level(a) < Profile.expertise_level(b))
	var r := _rng()
	var out: Array = []
	if open.is_empty():
		return out
	out.append(open[r.randi() % mini(5, open.size())])
	# lot E5 : les deux autres parmi les classes en retard (rattrapage) quand il y en a assez
	var rest := open.filter(func(c): return not c in out)
	var late := rest.filter(func(c): return Economy.lagging(String(c)))
	if late.size() >= 2:
		rest = late
	while out.size() < 3 and not rest.is_empty():
		out.append(rest.pop_at(r.randi() % rest.size()))
	return out


static func done_today() -> bool:
	return String(Profile.records.get("challenge_day", "")) == today()


static var heroic_mods: Array = []  # contraintes d'un rang héroïque (hors Défi de maîtrise)


static func has(mod: String) -> bool:
	return (active and mod in mods) or mod in heroic_mods


## Lance le défi du jour avec la classe [param cid].
static func start(cid: String) -> void:
	Run.start_survival(cid, 1)
	active = true
	mods = modifiers_today()
	ModeRules.modifiers = mods.duplicate()


static func reset() -> void:
	active = false
	mods = []
	heroic_mods = []
	ModeRules.modifiers = []


## Fin de la run : renvoie la maîtrise finale (doublée, plus le bonus de la 1re réussite du jour).
static func settle(gain: int, result: String) -> Dictionary:
	var out := {"gain": gain, "first": false}
	if not active:
		return out
	out.gain = gain * 2
	if result == "victoire" and not done_today():
		out.gain = int(out.gain) + BONUS_FIRST
		out.first = true
		Profile.records["challenge_day"] = today()
		Profile.record_add("challenge_wins", 1)
	return out
