extends Node
## Sonde des camps et des objectifs des Deux Voies (lot MB-F, R_MB_F § 3) : des héros scriptés (MobaRival, Difficile) au
## niveau visé combattent un camp ou un objectif, sans vagues autour qui comptent ; une ligne « [moba] sonde … » par essai.
## Lancement : world.tscn -- --moba --moba-heroes=none --moba-clock=600 --moba-probe=<cible>:<héros>:<niveau>[:<essais>]
##   cible : guardian | colossus | source | braise | petit ; ex. guardian:4:5, colossus:4:10, petit:1:2, source:1:3.
## Classes : une par poste (Rempart, Ombre, Traque ou Arcane, Ferveur), tirées à la graine (--moba-seed) ; un seul héros :
## l'Ombre (le jungler). Mesures : temps du premier coup à la chute, héros tombés, PV restants, coût du nœud de la jungle.

const FAMS := [2, 1, 3, 4, 5]

var jungle: MobaJungle
var target := "guardian"
var n_heroes := 4
var lv := 5
var trials := 1
var heroes: Array = []
var _trial := 0
var _t0 := -1.0
var _wait := 0.0
var _rt := 0.0
var _entry: Dictionary = {}
var _started := false
var _done := 0


func start(j: MobaJungle, spec: String) -> void:
	jungle = j
	var p := spec.split(":")
	target = p[0]
	n_heroes = int(p[1]) if p.size() > 1 else 4
	lv = int(p[2]) if p.size() > 2 else 5
	trials = int(p[3]) if p.size() > 3 else 1


func _entry_for() -> Dictionary:
	if jungle.objectives.has(target):
		return jungle.objectives[target]
	for e in jungle.camps:
		if String(e.camp) == target and int(e.half) == 0:
			return e
	return {}


func _physics_process(delta: float) -> void:
	if jungle == null or jungle.director.map == null or not jungle.director.map.nav_ready():
		return
	if not _started:
		_started = true
		_entry = _entry_for()
		if jungle.objectives.has(target):
			jungle.force_spawn(target)
		_make_heroes()
		return
	if String(_entry.state) != "alive":
		if _t0 >= 0.0:
			_report(true)
		_wait += delta
		if _wait > 3.0 and _done < trials:
			_wait = 0.0
			if jungle.objectives.has(target):
				jungle.force_spawn(target)
			else:
				_entry.respawn_at = Moba.t
		return
	if _t0 < 0.0 and float(_entry.engaged_at) >= 0.0:
		_t0 = float(_entry.engaged_at)
	_rt -= delta
	if _rt > 0.0:
		return
	_rt = 0.25
	var units: Array = jungle._units_of(_entry)
	var alive_h := 0
	for h in heroes:
		if h.is_dead:
			continue
		alive_h += 1
		var best: Combatant = null
		for u in units:
			if not u.is_dead and not u.parked and (best == null or h.global_position.distance_to(u.global_position) < h.global_position.distance_to(best.global_position)):
				best = u
		h._player = best
		h.goal = Vector3.INF
	if alive_h == 0 and _t0 >= 0.0:
		_report(false)
	if _t0 >= 0.0 and Moba.t - _t0 > 240.0:
		_report(false)


func _make_heroes() -> void:
	for h in heroes:
		jungle.guests.erase(h)
		h.queue_free()
	heroes = []
	var taken: Array = []
	var fams: Array = [2] if n_heroes == 1 else [1, 2, 3 if jungle.rng.randf() < 0.5 else 5, 4]
	var at: Vector3 = _entry.pos
	for i in n_heroes:
		var cid: String = jungle.director._pick_class([fams[i % fams.size()]], taken)
		taken.append(cid)
		var r := MobaRival.make(jungle.director, cid, lv, 2, 0)
		if "hold_ult" in r:
			r.set("hold_ult", false)  # (l'ultime aussi sur un objectif)
		jungle.director.add_child(r)
		var a := TAU * i / maxf(n_heroes, 1)
		r.global_position = at + Vector3(cos(a), 0, sin(a)) * 7.0 + Vector3.UP * 0.4
		heroes.append(r)
		jungle.guests.append(r)  # (Sceaux, Source, Bannière comme les héros du directeur)
	_trial += 1


func _report(killed: bool) -> void:
	var dead := 0
	var hp := 0.0
	var classes: Array = []
	for h in heroes:
		classes.append(h.cid)
		if h.is_dead:
			dead += 1
		else:
			hp += h.hp / h.max_hp
	var units: Array = jungle._units_of(_entry)
	var left := 0.0
	for u in units:
		if not u.is_dead and not u.parked:
			left += u.hp / u.max_hp
	var c := jungle.cost()
	print("[moba] sonde %s héros=%d niveau=%d essai=%d classes=%s %s temps=%.1f s tombés=%d pv_moyens=%.2f reste=%.2f briques=%s jungle_us=%.1f/%.0f camps_us=%.1f/%.0f sup1ms=%d/%d sur %d pire=%s" % [
		target, n_heroes, lv, _trial, ",".join(classes), "tué" if killed else "échec", Moba.t - _t0, dead,
		hp / maxf(heroes.size() - dead, 1), left, ",".join(_entry.get("bricks", [])), float(c.us_avg), float(c.us_max), float(c.camps_avg), float(c.camp_max), int(c.over_1ms), int(c.camp_over_1ms), int(c.frames), String(c.worst)])
	_t0 = -1.0
	_done += 1
	if _done >= trials:
		_finish()
		return
	if not killed:
		jungle.reset_entry(_entry)
	_make_heroes()


func _finish() -> void:
	print("[moba] sonde fin")
	set_physics_process(false)
	if "--auto-quit" in OS.get_cmdline_user_args():
		get_tree().quit()
