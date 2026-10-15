class_name BossLibrary
extends RefCounted
## Bibliothèque de boss (passe M2) : 48 boss réutilisables par tous les modes (Donjons aujourd'hui ; Tour, Ruée, Siège,
## Survie, Survivant ensuite). Données : data/bosses.json ; mécaniques : briques de BossBricks (une mécanique = une
## brique + des paramètres, aucun code propre à un boss). Un boss = un monstre d'Eden (modèle, animations), un nom,
## 2 à 4 briques, un jeu d'attaques de base (kit), des PV × hp sur les PV fixes du palier (Dungeons.boss_hp, passe P11),
## une zone (décor, niveau, monstres des salles) et un thème de butin (panoplie + deux emplacements).
##
## API (voir conception/nuit_15_10/R_M2.md) :
##   BossLibrary.spawn(id, tier, {director, pos, level, [hp], [hp_mult], [atk_mult], [main], [lieutenant]}) -> Monster
##   BossLibrary.ids() / get_def(id) / for_zone(zid) / zone_boss(zid) / full_name(id) / bricks_of(id, tier)
##   BossLibrary.hp(id, level, tier, rush) / families_of(id) / mechanic_names(id) / loot(id)
## Palier (tier) : 0 Normal, 1 Héroïque, 2 Mythique : PV fixes du palier, mécaniques plus fréquentes (PACE), et en
## Mythique l'Impatience (frenzy) s'ajoute si le boss ne l'a pas. Un coup de boss ne retire jamais plus de HIT_CAP des
## PV max du héros (jamais de mort en un coup) ; une zone persistante, au plus le tiers par seconde.

const PATH := "res://data/bosses.json"
const HIT_CAP := 0.4
const PACE := [1.0, 0.85, 0.72]
const MYTHIC_EXTRA := "frenzy"
## PV d'un lieutenant (mini-boss de la 3e salle d'un donjon) : part des PV du boss du donjon.
const LIEUTENANT_HP := 0.25

static var _defs: Array = []
static var _by_id := {}


static func _load() -> void:
	if not _defs.is_empty():
		return
	var data = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if typeof(data) != TYPE_DICTIONARY:
		push_error("BossLibrary : %s illisible" % PATH)
		return
	_defs = data.get("bosses", [])
	for d in _defs:
		_by_id[String(d.id)] = d


static func all() -> Array:
	_load()
	return _defs


static func ids() -> Array:
	return all().map(func(d): return String(d.id))


static func has(id: String) -> bool:
	_load()
	return _by_id.has(id)


static func get_def(id: String) -> Dictionary:
	_load()
	return _by_id.get(id, {})


## Boss de la zone [param zid], dans l'ordre (le boss de la zone d'abord).
static func for_zone(zid: String) -> Array:
	return all().filter(func(d): return String(d.zone) == zid).map(func(d): return String(d.id))


## Boss d'origine de la zone (mêmes mécaniques qu'en Survie).
static func zone_boss(zid: String) -> String:
	for d in all():
		if String(d.zone) == zid and d.get("legacy", false):
			return String(d.id)
	return ""


## « Latif, Roi du ciel » (nom seul s'il n'a pas de titre).
static func full_name(id: String) -> String:
	var d := get_def(id)
	if d.is_empty():
		return id
	return String(d.name) + (", " + String(d.title) if String(d.get("title", "")) != "" else "")


static func short_name(id: String) -> String:
	return String(get_def(id).get("name", id))


## Briques normalisées du boss [param id] au palier [param tier] (Mythique : l'Impatience en plus).
static func bricks_of(id: String, tier: int) -> Array:
	var out: Array = []
	var types: Array = []
	for b in get_def(id).get("bricks", []):
		var n := BossBricks.normalize(b)
		if not n.is_empty():
			out.append(n)
			types.append(n.type)
	if tier >= 2 and not MYTHIC_EXTRA in types:
		out.append(BossBricks.normalize({"type": MYTHIC_EXTRA}))
	return out


static func brick_types(id: String) -> Array:
	return (get_def(id).get("bricks", []) as Array).map(func(b): return String(b.type))


## Familles de mécaniques du boss (BossBricks.FAMILIES), sans doublon.
static func families_of(id: String) -> Array:
	var out: Array = []
	for t in brick_types(id):
		var f := BossBricks.family_of(t)
		if f != "" and not f in out:
			out.append(f)
	return out


## Noms des mécaniques (« Bourrasque », « Pluie de météores »…).
static func mechanic_names(id: String) -> Array:
	return brick_types(id).map(func(t): return BossBricks.name_of(t))


## Phrase d'entrée : l'intro du boss, sinon le conseil de sa première mécanique (une idée, une phrase).
static func intro(id: String) -> String:
	var d := get_def(id)
	if String(d.get("intro", "")) != "":
		return String(d.intro)
	var hint := BossBricks.hint_of(String(brick_types(id)[0])) if not brick_types(id).is_empty() else ""
	return (hint.left(1).to_upper() + hint.substr(1) + " !") if hint != "" else short_name(id)


## Thème de butin : {archetype, slots}.
static func loot(id: String) -> Dictionary:
	var d := get_def(id)
	return {"archetype": String(d.get("archetype", "storm")), "slots": d.get("slots", [])}


## PV fixes du boss [param id] de niveau [param level] au palier [param tier] (Ruée : × Dungeons.RUSH_BOSS).
static func hp(id: String, level: int, tier: int, rush := false) -> float:
	return Dungeons.boss_hp(level, tier, rush) * float(get_def(id).get("hp", 1.0))


## Fait apparaître le boss [param id] au palier [param tier]. [param ctx] :
##   director (RunDirector, obligatoire : apparition, invocations, messages), pos (Vector3), level (int) ;
##   hp (PV imposés ; sinon hp()), hp_mult (alliés, trio…), atk_mult ;
##   main (défaut true : devient le boss de la salle, director._boss, cible des invocations) ;
##   lieutenant (true : mini-boss, une seule brique sans invocation, PV LIEUTENANT_HP).
static func spawn(id: String, tier: int, ctx: Dictionary) -> Monster:
	var def := get_def(id)
	var d = ctx.get("director")
	if def.is_empty() or d == null:
		push_error("BossLibrary.spawn : boss « %s » inconnu ou directeur absent" % id)
		return null
	tier = clampi(tier, 0, PACE.size() - 1)
	var level := int(ctx.get("level", 1))
	var lieutenant := bool(ctx.get("lieutenant", false))
	var m: Monster = d._spawn_monster(int(def.monster), ctx.get("pos", Vector3.ZERO), level, true)
	m.set_meta("boss_id", id)
	m.display_name = "<Boss> " + (short_name(id) + ", lieutenant" if lieutenant else full_name(id))
	m.atk *= float(ctx.get("atk_mult", 1.0))
	var h := float(ctx.get("hp", hp(id, level, tier))) * float(ctx.get("hp_mult", 1.0)) * (LIEUTENANT_HP if lieutenant else 1.0)
	m.max_hp = h
	m.hp = h
	if bool(ctx.get("main", not lieutenant)):
		d._boss = m
	if m.brain == null:
		return m
	var list := bricks_of(id, tier)
	if lieutenant:
		var calm := list.filter(func(b): return BossBricks.family_of(String(b.type)) != "summon" and String(b.kind) == "every")
		list = calm.slice(0, 1)
	if d.has_signal("message"):
		m.brain.announce.connect(func(t): d.message.emit(t, 2.5))
		m.brain.enraged_phase.connect(func(): d.message.emit("%s entre en fureur !" % short_name(id), 2.5))
		m.reflect_started.connect(func(): d.message.emit("Miroir ! Ne frappe pas pendant 3 s", 2.0))
	m.brain.setup_bricks(list, d, String(def.get("hazard", "lava")), def.get("kit", []), float(PACE[tier]), HIT_CAP)
	return m
