extends Node
## L'Échiquier, lot AC-U : scénarios courts de l'IA de combat des unités (SPEC §4.2 ; rapport conception/autochess/R_AC_U.md).
## Le soigneur soigne l'allié le plus bas ; le tireur garde sa portée et recule devant une mêlée ; l'assassin atteint
## l'arrière-ligne en moins de 3 s ; une zone ne part tout de suite que sur 2 ennemis ou plus (sinon après l'attente) ;
## 3 mêlées au plus sur une cible ; le tank prend l'ennemi qui frappe un allié fragile ; esquive des zones ennemies, pas
## des alliées ; reciblage ≤ 0,3 s après une chute ; aucune sortie du plateau ; aucun dégât allié.
## godot --headless --fixed-fps 60 --path game res://tests/test_ac_unit_ai.tscn

var fails := 0
var dir: AutochessDirector
var out_frames := 0
var ally_dmg := 0
var stale_max := 0.0  # plus long temps passé à viser une unité tombée (s)
var _stale := {}
var _probe: Callable  # relevé du scénario en cours, à chaque image


func check(label: String, ok: bool) -> void:
	print(("OK    " if ok else "ÉCHEC ") + label)
	if not ok:
		fails += 1


func _ready() -> void:
	var t0 := Time.get_ticks_msec()
	seed(23)
	Training.active = false
	dir = AutochessDirector.new()
	dir.fallback_ms = 0.0
	add_child(dir)
	await _test_heal()
	await _test_ranged()
	await _test_assassin()
	await _test_zone()
	await _test_focus()
	await _test_tank()
	await _test_dodge()
	check("aucune unité hors du plateau, à aucune image", out_frames == 0)
	check("aucun dégât allié (%d)" % ally_dmg, ally_dmg == 0)
	check("reciblage après une chute en %.2f s au plus (≤ 0,3 s)" % stale_max, stale_max <= 0.3)
	dir.queue_free()
	await get_tree().process_frame
	print("durée : %.1f s" % ((Time.get_ticks_msec() - t0) / 1000.0))
	print("TOUT EST OK (0 échec(s))" if fails == 0 else "ÉCHECS : %d" % fails)
	get_tree().quit(1 if fails > 0 else 0)


func _physics_process(delta: float) -> void:
	if dir == null or not is_instance_valid(dir) or not dir.running:
		return
	var lim := AutochessUnit.limits() + Vector2(0.01, 0.01)
	for a in dir.arenas:
		var o: Vector3 = a.origin
		for side in 2:
			for u in a.nodes[side]:
				if not is_instance_valid(u):
					continue
				var n := u as AutochessUnit
				var p := n.global_position - o
				if absf(p.x) > lim.x or absf(p.z) > lim.y or p.y < -0.5:
					out_frames += 1
				if n.is_dead:
					continue
				var t: Variant = n._player
				if t != null and is_instance_valid(t) and (t as Combatant).is_dead:
					_stale[n] = float(_stale.get(n, 0.0)) + delta
					stale_max = maxf(stale_max, float(_stale[n]))
				else:
					_stale.erase(n)
	if _probe.is_valid():
		_probe.call()


# --- Outils -----------------------------------------------------------------------------------------------------------
## Unité [param id] à la case [param col], [param row] ; [param mod] : fiche de base modifiée (hp, hp_start, atk, mana_start…).
func _u(id: String, col: int, row: int, mod := {}, stars := 1) -> Dictionary:
	var d := AutochessData.unit(id)
	var u := {"uid": col * 10 + row, "id": id, "stars": stars, "copies": 1, "items": [], "cell": [col, row],
		"cost": int(d.get("cost", 1)), "traits": []}
	var sh := AutochessDirector.base_sheet(u)
	for k in mod:
		sh[k] = mod[k]
	if mod.has("hp_frac"):
		sh["hp_start"] = float(sh.hp) * float(mod.hp_frac)
		sh.erase("hp_frac")
	if mod.has("mana_full"):
		sh["mana_start"] = float(sh.mana_max)
		sh.erase("mana_full")
	u["sheet"] = sh
	return u


func _fight(a: Array, b: Array, s := 1) -> Dictionary:
	return {"kind": "jcj", "a": 0, "b": 1, "board_a": a, "board_b": b, "ctx": {"stage": 3, "round": 1, "kind": "jcj", "seed": s,
		"a": 0, "b": 1, "ghost_of": -1, "augments": [[], []], "guardian_mult": 1.0, "traits": [{}, {}]}}


## Lance le combat ; rend l'arène (le combat tourne, voir _until).
func _start(f: Dictionary) -> Dictionary:
	dir.begin([f], 0)
	var a: Dictionary = dir.arenas[0]
	a.ctx["keep_log"] = true
	return a


## Attend que [param cond] soit vrai ou [param secs] s de combat ; puis compte les dégâts alliés du journal.
func _until(a: Dictionary, secs: float, cond := Callable()) -> void:
	while dir.running and float(a.t) < secs and not (cond.is_valid() and cond.call()):
		await get_tree().physics_frame
	for e in a.ctx.log:
		if String(e.type) == "damage" and int(e.get("src", -1)) >= 0 and float(e.amount) > 0.0 \
				and int(a.ctx.units[int(e.src)].side) == int(a.ctx.units[int(e.dst)].side):
			ally_dmg += 1
	a.ctx["log"] = []


func _end(a: Dictionary) -> void:
	_probe = Callable()
	if dir.running:
		for side in 2:
			for n in a.nodes[side]:
				if is_instance_valid(n) and not n.is_dead:
					(n as AutochessUnit).ac_stop()
		dir.clear()
	await get_tree().physics_frame


func _node(a: Dictionary, side: int, k: int) -> AutochessUnit:
	return a.nodes[side][k] as AutochessUnit


func _dist(x: Node3D, y: Node3D) -> float:
	var d := x.global_position - y.global_position
	return Vector2(d.x, d.z).length()


# --- Scénarios --------------------------------------------------------------------------------------------------------
## Le soigneur (mana pleine) soigne l'allié le plus bas, pas celui à 80 % ni lui-même ; aucun soin perdu.
func _test_heal() -> void:
	var weak := {"atk": 1.0}
	var a := _start(_fight([_u("cleric", 3, 3, {"mana_full": true}), _u("warrior", 2, 0, {"hp_frac": 0.3}), _u("knight", 4, 0, {"hp_frac": 0.8})],
		[_u("warrior", 3, 0, weak), _u("knight", 4, 0, weak)]))
	var healer := _node(a, 0, 0)
	var low := _node(a, 0, 1)
	var first: Array = [null]
	_probe = func():
		if first[0] == null and healer._ac.get("heal_to") != null:
			first[0] = healer._ac.heal_to
	await _until(a, 4.0, func(): return first[0] != null and int(healer.ac_stats.heals) >= 1)
	check("soigneur : premier soin sur l'allié le plus bas (%s)" % (first[0].unit_label() if first[0] != null else "aucun"), first[0] == low)
	check("soigneur : soin perdu %.0f sur %.0f" % [float(healer.ac_stats.heal_lost), float(healer.ac_stats.heal_req)],
		float(healer.ac_stats.heal_req) > 0.0 and float(healer.ac_stats.heal_lost) <= 0.15 * float(healer.ac_stats.heal_req))
	await _end(a)


## Le tireur garde sa portée et recule d'un bond quand une mêlée arrive ; il tire.
func _test_ranged() -> void:
	var a := _start(_fight([_u("hunter", 3, 3, {"hp": 20000.0})], [_u("martial_artist", 3, 0, {"hp": 20000.0, "atk": 1.0})]))
	var h := _node(a, 0, 0)
	var min_d := [INF]
	_probe = func():
		var m := _node(a, 1, 0)
		if float(a.t) > 3.0 and is_instance_valid(m):
			min_d[0] = minf(min_d[0], _dist(h, m))
	await _until(a, 10.0)
	var st := h.ac_stats
	var in_r := float(st.in_range) / maxf(float(st.range_samples), 1.0)
	check("tireur : à portée de sa cible %.0f %% du temps (≥ 70 %%)" % (100.0 * in_r), in_r >= 0.7)
	check("tireur : recule d'un bond devant la mêlée (%d bonds) et tire (%d coups)" % [int(st.hops), int(st.autos)], int(st.hops) >= 1 and int(st.autos) >= 3)
	await _end(a)


## L'assassin plonge sur l'arrière-ligne (le mage derrière deux mêlées) et l'atteint en moins de 3 s.
func _test_assassin() -> void:
	var tough := {"hp": 20000.0}
	var a := _start(_fight([_u("assassin", 1, 1, tough), _u("warrior", 3, 0, tough), _u("knight", 4, 0, tough)],
		[_u("warrior", 3, 0, tough), _u("knight", 4, 0, tough), _u("magician", 3, 3, tough)]))
	var s := _node(a, 0, 0)
	var mage := _node(a, 1, 2)
	var reached := [-1.0]
	_probe = func():
		if reached[0] < 0.0 and _dist(s, mage) <= s._attack_range() + 0.5:
			reached[0] = float(a.t)
	await _until(a, 5.0, func(): return reached[0] >= 0.0)
	check("assassin : atteint le mage d'arrière-ligne en %.1f s (< 3 s)" % reached[0], reached[0] >= 0.0 and reached[0] < 3.0)
	check("assassin : le mage est sa cible", s._player == mage)
	await _end(a)


## Une zone (Conjurateur, cercle de 4,5 m) part tout de suite sur 2 ennemis groupés, mais attend sur 2 ennemis éloignés.
func _test_zone() -> void:
	for grouped in [true, false]:
		var b: Array = [_u("warrior", 3, 0, {"hp": 20000.0}), _u("knight", 4 if grouped else 0, 0 if grouped else 3, {"hp": 20000.0})]
		if not grouped:
			b[0]["cell"] = [6, 0]
		var a := _start(_fight([_u("conjurer", 3, 3, {"mana_full": true, "hp": 20000.0})], b))
		for n in a.nodes[1]:
			(n as AutochessUnit).passive = true
		var c := _node(a, 0, 0)
		var cast_t := [-1.0]
		_probe = func():
			if cast_t[0] < 0.0 and int(c.ac_stats.casts) >= 1:
				cast_t[0] = float(a.t)
		await _until(a, 4.0, func(): return cast_t[0] >= 0.0 and int(c.ac_stats.zone_hits) >= 1 and float(a.t) > cast_t[0] + 1.5)
		if grouped:
			check("zone sur 2 ennemis groupés : lancée tout de suite (%.2f s), %d touchés" % [cast_t[0], int(c.ac_stats.zone_hits)],
				cast_t[0] >= 0.0 and cast_t[0] < 0.8 and int(c.ac_stats.zone_hits) >= 2)
		else:
			check("zone sur 2 ennemis éloignés : attend une meilleure occasion (%.2f s ≥ %.1f s)" % [cast_t[0], AutochessUnit.ZONE_WAIT],
				cast_t[0] >= AutochessUnit.ZONE_WAIT - 0.05)
		await _end(a)


## 5 mêlées contre 2 ennemis (l'un très faible) : jamais plus de 3 mêlées sur la même cible.
func _test_focus() -> void:
	var tough := {"hp": 20000.0, "atk": 1.0}
	var a := _start(_fight([_u("warrior", 1, 0, tough), _u("knight", 2, 0, tough), _u("templar", 3, 0, tough), _u("shielder", 4, 0, tough),
		_u("martial_artist", 5, 0, tough)], [_u("warrior", 3, 0, {"hp": 20000.0, "hp_frac": 0.1, "atk": 1.0}), _u("knight", 5, 1, tough)]))
	var worst := [0]
	_probe = func():
		var count := {}
		for n in a.nodes[0]:
			var u := n as AutochessUnit
			if is_instance_valid(u) and not u.is_dead and u._player != null:
				count[u._player] = int(count.get(u._player, 0)) + 1
		for k in count:
			worst[0] = maxi(worst[0], int(count[k]))
	await _until(a, 4.0)
	check("focus : au plus %d mêlées sur une même cible (%d vues)" % [AutochessData.AI_MAX_MELEE_PER_TARGET, worst[0]],
		worst[0] <= AutochessData.AI_MAX_MELEE_PER_TARGET)
	await _end(a)


## Le tank prend l'ennemi qui frappe son mage (et pas le plus proche de lui).
func _test_tank() -> void:
	var tough := {"hp": 20000.0, "atk": 1.0}
	var a := _start(_fight([_u("warrior", 0, 0, tough), _u("magician", 6, 3, tough)], [_u("knight", 6, 0, tough), _u("templar", 0, 0, tough)]))
	var tank := _node(a, 0, 0)
	var mage := _node(a, 0, 1)
	var raider := _node(a, 1, 0)
	var near := _node(a, 1, 1)
	# l'ennemi qui frappe arrive au contact du mage, l'autre est collé au tank
	raider.global_position = mage.global_position + (mage.global_position - tank.global_position).normalized() * -1.5
	near.global_position = tank.global_position + Vector3(1.5, 0.0, -1.5 if tank.ac_side == 0 else 1.5)
	await _until(a, 1.5)
	check("tank : prend l'ennemi qui frappe le mage (%s ; cible du pillard : %s)" % [
		tank._player.unit_label() if tank._player else "aucune", raider._player.unit_label() if raider._player else "aucune"],
		raider._player == mage and tank._player == raider)
	await _end(a)


## Esquive : sort d'une zone rouge ennemie avant l'impact ; ignore une zone alliée.
func _test_dodge() -> void:
	var tough := {"hp": 20000.0, "atk": 1.0}
	var a := _start(_fight([_u("warrior", 3, 0, tough), _u("knight", 1, 0, tough)], [_u("templar", 3, 2, tough)]))
	var w := _node(a, 0, 0)
	var mate := _node(a, 0, 1)
	var foe := _node(a, 1, 0)
	foe.passive = true
	w.cfg = w.cfg.duplicate()
	w.cfg["read"] = 1.0
	await _until(a, 0.3)
	var hit := [true, true]
	var tg := Telegraph.spawn(foe, w.global_position, 0.0, {"delay": 1.0, "damage": 1.0, "source": foe, "shape": "circle", "radius": 1.6})
	tg.resolved.connect(func(h): hit[0] = h)
	await _until(a, 1.6)
	check("esquive : sort de la zone rouge ennemie avant l'impact", not hit[0])
	var p := mate.global_position
	var tg2 := Telegraph.spawn(w, p, 0.0, {"delay": 0.8, "damage": 1.0, "source": w, "shape": "circle", "radius": 1.6})
	tg2.resolved.connect(func(h): hit[1] = h)
	var dodges := int(mate.ac_stats.dodges)
	await _until(a, 2.6)
	check("esquive : une zone alliée ne fait ni esquiver ni mal (esquives %d -> %d)" % [dodges, int(mate.ac_stats.dodges)],
		int(mate.ac_stats.dodges) == dodges and not hit[1])
	await _end(a)
