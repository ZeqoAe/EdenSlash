class_name SiegeScore
extends RefCounted
## Tableau des trois du Siège (lot DNG-3, backlog BM-DNG P1-9 « Siège lisible ») : pour toi et tes deux alliés IA (rivaux après la
## chute du boss), les dégâts faits au boss et aux lieutenants, les chutes, et qui a porté le dernier coup au boss. Lu par le HUD
## (DngHud : tableau, objectifs ★ en direct, fureur) et par le bilan (DungeonResults). Rien ici ne change le combat : on compte.
## Remis à zéro au début de chaque partie (Tower.start).

static var heroes: Array = []  # [{key, name, ref (WeakRef), me, dmg, falls, last}]
static var boss_t0 := -1.0  # BestTimes.clock à l'apparition du boss du siège
static var boss_time := 0.0  # de son apparition à sa chute (0 : pas tombé)
static var last_hit := ""  # nom de celui qui a porté le dernier coup au boss


static func reset() -> void:
	heroes = []
	boss_t0 = -1.0
	boss_time = 0.0
	last_hit = ""


## Inscrit un héros ([param key] : « me » pour le joueur, sinon sa classe) ; un allié remplacé (tombé puis rendu pour le chacun
## pour soi) reprend sa ligne.
static func hero(c: Combatant, key: String, me := false) -> void:
	if c == null:
		return
	for h in heroes:
		if String(h.key) == key:
			var old = (h.ref as WeakRef).get_ref()
			if old == null or not is_instance_valid(old) or old.is_dead or old == c:
				h.ref = weakref(c)
				h.name = _name(c, me, key)
				return
	heroes.append({"key": key, "name": _name(c, me, key), "ref": weakref(c), "me": me, "dmg": 0.0, "falls": 0, "last": false})


static func _name(c: Combatant, me: bool, key := "") -> String:
	if me:
		return "Toi"
	var cls := GameData.class_data(key) if key != "" else {}
	if not cls.is_empty():
		return String(cls.get("name_fr", key))  # (le nom de la classe : « Prêtre », pas « priest · adversaire difficile »)
	return String(c.display_name).trim_prefix("<Duel> ").trim_prefix("<Boss> ")


static func _row_of(c: Combatant) -> Dictionary:
	if c == null:
		return {}
	for h in heroes:
		if (h.ref as WeakRef).get_ref() == c:
			return h
	return {}


## Suit le boss du siège ([param main]) ou un lieutenant : les dégâts reçus vont à leur auteur, le dernier coup au boss est noté.
static func track(m: Monster, main: bool) -> void:
	if m == null:
		return
	m.set_meta("siege_hp", m.hp)
	m.damaged.connect(func(amount, source): _on_hit(m, amount, source))
	if main:
		boss_t0 = BestTimes.clock
		m.died.connect(func(_w, killer): _on_boss_down(killer))


## Coup reçu par [param m] : les dégâts vraiment retirés (le coup de grâce est borné aux PV qui restaient).
static func _on_hit(m: Monster, amount: float, source) -> void:
	var applied := amount
	if is_instance_valid(m):
		if m.hp <= 0.0:
			applied = minf(amount, float(m.get_meta("siege_hp", amount)))
		m.set_meta("siege_hp", m.hp)
	var r := _row_of(source as Combatant) if source is Combatant else {}
	if not r.is_empty():
		r.dmg = float(r.dmg) + applied


static func _on_boss_down(killer) -> void:
	if boss_t0 >= 0.0:
		boss_time = BestTimes.clock - boss_t0
	var r := _row_of(killer as Combatant) if killer is Combatant else {}
	if not r.is_empty():
		r.last = true
		last_hit = String(r.name)


## Une chute (vagues, boss, chacun pour soi).
static func fall(c: Combatant) -> void:
	var r := _row_of(c)
	if not r.is_empty():
		r.falls = int(r.falls) + 1


## Lignes triées (les plus gros dégâts d'abord) : [{name, me, dmg, falls, last, share}].
static func rows() -> Array:
	var total := 0.0
	for h in heroes:
		total += float(h.dmg)
	var out: Array = []
	for h in heroes:
		out.append({"name": String(h.name), "me": bool(h.me), "dmg": float(h.dmg), "falls": int(h.falls), "last": bool(h.last),
			"share": float(h.dmg) / total if total > 0.0 else 0.0})
	out.sort_custom(func(a, b): return float(a.dmg) > float(b.dmg))
	return out


## « 1,2 M », « 845 k », « 920 ».
static func fmt(v: float) -> String:
	if v >= 1.0e6:
		return ("%.1f M" % (v / 1.0e6)).replace(".", ",")
	if v >= 1.0e4:
		return "%d k" % roundi(v / 1000.0)
	return str(roundi(v))
