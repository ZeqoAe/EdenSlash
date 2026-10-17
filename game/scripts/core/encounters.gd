class_name Encounters
extends RefCounted
## Journal des rencontres, couche données (lot DNG-1, backlog BM-DNG P0-9) : une fiche par boss de la bibliothèque (48),
## alimentée par les parties des Donjons, de la Tour, de la Ruée et du Siège. L'onglet du Carnet (« Rencontres », maquette
## conception/benchmark/donjons_maquettes/v2_journal_rencontres.svg) viendra avec la DA v2 : il n'a qu'à lire [method card]
## et [method all].
##
## Stockage : Profile.records[KEY] = {boss -> {met, won: {activité -> n}, seen: {brique -> n}, in: {activité -> n},
## low: meilleure part de PV laissée au boss sans le battre (1 : jamais entamé)}} (clé neuve, rien à migrer).
## Victoires par difficulté des Donjons : les compteurs existants Dungeons.boss_key (« dgb_<boss>_<diff> ») ; meilleurs temps :
## BestTimes. Comme BestTimes, tout est mis de côté pendant la partie et écrit par [method commit] (Tower.finish, après le
## rechargement du profil).

const KEY := "encounters"
const MODES := {"dungeon": "Donjons", "tower": "Tour", "rush": "Ruée", "siege": "Siège", "lieutenant": "Donjons (lieutenant)"}

static var _pending := {}  # boss -> {met, won: {}, seen: {}, in: {}, low}
static var _live: Array = []  # [boss, weakref du monstre, activité] : combats en cours (part des PV laissée à la fin)
## Boss encore debout à la fin de la dernière partie -> part de PV qui lui restait (bilan : « aujourd'hui 22 % »).
static var last_low := {}


static func reset() -> void:
	_pending.clear()
	_live.clear()


## Activité de la partie en cours (Tower) : dungeon, rush, siege, tower ; "" hors de ces modes.
static func mode() -> String:
	if not Tower.active:
		return ""
	if Tower.siege:
		return "siege"
	if Tower.rush:
		return "rush"
	return "dungeon" if Tower.is_dungeon() else "tower"


## Difficulté de l'activité en cours (Donjons, Ruée, Siège : Normal / Héroïque / Mythique ; Tour : Facile … Hardcore).
static func diff() -> int:
	return Tower.dungeon_diff if Tower.is_dungeon() else Tower.difficulty


static func _p(bid: String) -> Dictionary:
	if not _pending.has(bid):
		_pending[bid] = {"met": 0, "won": {}, "seen": {}, "in": {}, "low": 1.0}
	return _pending[bid]


## Le boss [param bid] vient d'apparaître ([param m] : son monstre ; [param lieutenant] : mini-boss d'un donjon). Appelé par
## BossLibrary.spawn ; hors des activités de la Tour (tests, captures), rien n'est noté.
static func met(bid: String, m: Monster, lieutenant := false) -> void:
	var md := mode()
	if md == "" or bid == "" or m == null:
		return
	var e := _p(bid)
	e.met = int(e.met) + 1
	var where := "lieutenant" if lieutenant else md
	e["in"][where] = int(e["in"].get(where, 0)) + 1
	_live.append([bid, weakref(m), where])
	var t0 := BestTimes.clock
	var d := diff()
	m.died.connect(func(_w, _k): _down(bid, where, d, t0, lieutenant))


static func _down(bid: String, where: String, d: int, t0: float, lieutenant: bool) -> void:
	var e := _p(bid)
	e["won"][where] = int(e["won"].get(where, 0)) + 1
	e.low = 0.0
	if not lieutenant and where in ["dungeon", "rush", "tower"]:
		BestTimes.note(BestTimes.boss_key(where, bid, d), BossLibrary.short_name(bid), BestTimes.clock - t0)


## Mécanique [param brick] vue chez le boss [param bid] (BossBrain.note_cast).
static func saw(bid: String, brick: String) -> void:
	if mode() == "" or brick == "" or not BossBricks.DEFS.has(brick):
		return
	var e := _p(bid)
	e["seen"][brick] = int(e["seen"].get(brick, 0)) + 1


## Fin de partie : la part de PV laissée aux boss encore debout, puis tout s'ajoute au profil.
static func commit() -> void:
	last_low.clear()
	for l in _live:
		var m = (l[1] as WeakRef).get_ref()
		if m != null and is_instance_valid(m) and not m.is_dead:
			var e := _p(String(l[0]))
			e.low = minf(float(e.low), m.hp / maxf(m.max_hp, 1.0))
			last_low[String(l[0])] = m.hp / maxf(m.max_hp, 1.0)
	_live.clear()
	if _pending.is_empty():
		return
	var all_t = Profile.records.get(KEY, {})
	var t: Dictionary = (all_t as Dictionary).duplicate(true) if all_t is Dictionary else {}
	for bid in _pending:
		var p: Dictionary = _pending[bid]
		var cur: Dictionary = t.get(bid, {}) if t.get(bid, {}) is Dictionary else {}
		cur["met"] = int(cur.get("met", 0)) + int(p.met)
		for k in ["won", "seen", "in"]:
			var sub: Dictionary = cur.get(k, {}) if cur.get(k, {}) is Dictionary else {}
			for x in p[k]:
				sub[x] = int(sub.get(x, 0)) + int(p[k][x])
			cur[k] = sub
		cur["low"] = minf(float(cur.get("low", 1.0)), float(p.low))
		t[bid] = cur
	Profile.records[KEY] = t
	_pending.clear()


# --- lecture (Carnet > Rencontres, bilans) -------------------------------------------------------
static func raw(bid: String) -> Dictionary:
	var t = Profile.records.get(KEY, {})
	if not t is Dictionary:
		return {}
	var e = (t as Dictionary).get(bid, {})
	return e if e is Dictionary else {}


## Victoires contre [param bid], toutes activités (journal, plus les victoires de donjon d'avant le journal).
static func wins(bid: String) -> int:
	var n := 0
	for k in raw(bid).get("won", {}):
		n += int(raw(bid).won[k])
	var dg := 0
	for d in Dungeons.DIFF_NAMES.size():
		dg += Dungeons.boss_cleared(bid, d)
	return maxi(n, dg)


## État de la fiche : « won » (vaincu), « met » (rencontré), « unknown » (à découvrir : nom caché tant que sa zone n'est
## pas ouverte, conseil toujours lisible).
static func state(bid: String) -> String:
	if wins(bid) > 0:
		return "won"
	if int(raw(bid).get("met", 0)) > 0:
		return "met"
	return "unknown"


## Meilleure part de PV laissée au boss sans le battre (1 : jamais entamé ; 0 : déjà vaincu).
static func best_low(bid: String) -> float:
	return 0.0 if wins(bid) > 0 else float(raw(bid).get("low", 1.0))


## Emplacements du butin du boss qui te manquent encore à sa panoplie (« seul emplacement de Latif qui te manque »).
static func missing_slots(bid: String) -> Array:
	var loot := BossLibrary.loot(bid)
	var arch := String(loot.archetype)
	var have := {}
	for it in Profile.all_items():
		if String(it.get("archetype", "")) == arch:
			have[String(it.get("slot", ""))] = true
	return (loot.slots as Array).filter(func(s): return not have.has(String(s)))


## Fiche du journal du boss [param bid] : {id, name (« ??? » à découvrir et zone fermée), title, zone, zone_name, state,
## met, wins, by_mode ({activité -> victoires}), where (noms des activités où il a été vu), low, bricks ([{type, name, family,
## hint, tip, seen}] : les mécaniques pas encore vues restent lisibles), dungeon (par difficulté des Donjons : [{diff, name,
## wins, best (s, 0 : aucun)}]), slots, archetype, missing (emplacements qui manquent)}.
static func card(bid: String) -> Dictionary:
	var def := BossLibrary.get_def(bid)
	if def.is_empty():
		return {}
	var r := raw(bid)
	var st := state(bid)
	var zid := String(def.get("zone", ""))
	var open := Dungeons.is_open(zid) or st != "unknown"
	var seen: Dictionary = r.get("seen", {})
	var bricks: Array = []
	for t in BossLibrary.brick_types(bid):
		bricks.append({"type": t, "name": BossBricks.name_of(t), "family": BossBricks.family_of(t), "hint": BossBricks.hint_of(t),
			"tip": HitLog.tip_for(t), "seen": int(seen.get(t, 0))})
	var dg: Array = []
	for d in Dungeons.DIFF_NAMES.size():
		dg.append({"diff": d, "name": Dungeons.DIFF_NAMES[d], "wins": Dungeons.boss_cleared(bid, d),
			"best": BestTimes.best(BestTimes.boss_key("dungeon", bid, d)), "full": BestTimes.best(BestTimes.dungeon_key(bid, d))})
	var where: Array = []
	for k in (r.get("in", {}) as Dictionary):
		where.append(String(MODES.get(k, k)))
	var loot := BossLibrary.loot(bid)
	return {"id": bid, "name": BossLibrary.short_name(bid) if open else "???", "title": String(def.get("title", "")) if open else "",
		"zone": zid, "zone_name": Dungeons.name_of(zid), "state": st, "met": int(r.get("met", 0)), "wins": wins(bid),
		"by_mode": r.get("won", {}), "where": where, "low": best_low(bid), "bricks": bricks, "dungeon": dg,
		"slots": loot.slots, "archetype": String(loot.archetype), "missing": missing_slots(bid)}


## Les 48 fiches, dans l'ordre de la bibliothèque (6 par zone).
static func all() -> Array:
	return BossLibrary.ids().map(func(id): return card(String(id)))


## Compteurs du journal : {won, met, total}.
static func counts() -> Dictionary:
	var out := {"won": 0, "met": 0, "total": 0}
	for id in BossLibrary.ids():
		var s := state(String(id))
		out.total += 1
		if s == "won":
			out.won += 1
		if s != "unknown":
			out.met += 1
	return out
