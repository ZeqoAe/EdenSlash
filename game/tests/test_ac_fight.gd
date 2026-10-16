extends Node
## L'Échiquier, lot AC-E : le combat réel (AutochessDirector, AutochessUnit). Mode scellé (Modes.current, Modes.sealed et
## les 7 endroits du lot H2, hub intact), 20 combats 5 contre 5 (médiane 15-45 s, sorts à mana pleine, aucun dégât allié,
## aucune unité hors du plateau), 4 plateaux 10 contre 10 en même temps (sans interférence, budget d'image), égalité à 45 s
## et Fureur, vitesse ×2, repli des plateaux cachés sur le combat de données, une manche réelle de bout en bout injectée
## dans Autochess.finish_combat.
## godot --headless --path game res://tests/test_ac_fight.tscn   (AC_FIGHT_QUICK=1 : version courte)

const CID := "warrior"
const SPEED := 2.0

var fails := 0
var dir: AutochessDirector
var rng := RandomNumberGenerator.new()
var quick := false
var out_frames := 0  # unités vues hors du plateau (toutes images de tous les combats)
var max_units := 0
var phys_ms: Array = []
var _measure := false


func check(label: String, ok: bool) -> void:
	print(("OK    " if ok else "ÉCHEC ") + label)
	if not ok:
		fails += 1


func _ready() -> void:
	var t0 := Time.get_ticks_msec()
	quick = OS.get_environment("AC_FIGHT_QUICK") == "1"
	rng.seed = 17
	seed(17)
	Training.active = false
	Settings.reset_all()
	Profile.reset_all()
	Profile.selected_class = CID
	var ui: Dictionary = Settings.data.get("interface", {})
	ui["hit_stop"] = false
	Settings.data["interface"] = ui
	check("hors de L'Échiquier : mode %s, pas scellé" % Modes.current(), Modes.current() != "autochess" and not AutochessDirector.active)
	dir = AutochessDirector.new()
	add_child(dir)
	_test_mode()
	var hub := _hub()
	await _test_fights()
	await _test_parallel()
	await _test_draw_speed()
	await _test_fallback()
	await _test_game()
	check("hub intact après tous les combats (équipement, maîtrise, talents, insignes, cristaux, coffres, records)", _hub() == hub)
	check("aucune unité hors du plateau, à aucune image (%d unités suivies au plus)" % max_units, out_frames == 0)
	dir.queue_free()
	await get_tree().process_frame
	check("directeur retiré : mode « autochess » fini (%s)" % Modes.current(), not AutochessDirector.active and Modes.current() != "autochess")
	check("vitesse rendue après les combats (Engine.time_scale %.1f)" % Engine.time_scale, is_equal_approx(Engine.time_scale, 1.0))
	print("durée : %.1f s" % ((Time.get_ticks_msec() - t0) / 1000.0))
	print("TOUT EST OK (0 échec(s))" if fails == 0 else "ÉCHECS : %d" % fails)
	get_tree().quit(1 if fails > 0 else 0)


## Toutes les unités de tous les combats en cours : sur leur plateau (moins la marge), à chaque image.
func _physics_process(_delta: float) -> void:
	if dir == null or not is_instance_valid(dir) or not dir.running:
		return
	var n := 0
	var hx := AutochessDirector.HALF_X - AutochessData.BOARD_MARGIN + 0.01
	var hz := AutochessDirector.HALF_Z - AutochessData.BOARD_MARGIN + 0.01
	for a in dir.arenas:
		var o: Vector3 = a.origin
		for side in 2:
			for u in a.nodes[side]:
				if not is_instance_valid(u):
					continue
				n += 1
				var p: Vector3 = (u as Node3D).global_position - o
				if absf(p.x) > hx or absf(p.z) > hz or p.y < -0.5 or p.y > 12.0:
					out_frames += 1
					if out_frames <= 5:
						print("      hors du plateau : %s (combat %d) en %s" % [(u as AutochessUnit).unit_label(), int(a.index), str(p)])
	max_units = maxi(max_units, n)
	if _measure:
		phys_ms.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0)


# --- Outils -----------------------------------------------------------------------------------------------------------
func _team(n: int, max_cost := 3, star2 := 0.15) -> Array:
	var out: Array = []
	var ids: Array = AutochessData.unit_ids().filter(func(id): return int(AutochessData.unit(id).get("cost", 1)) <= max_cost)
	var cells := {}
	for i in n:
		var id := String(ids[rng.randi_range(0, ids.size() - 1)])
		var d := AutochessData.unit(id)
		var row := 0 if String(d.get("place", "milieu")) == "avant" else (3 if String(d.get("place", "")) == "arriere" else 1)
		var cell := Vector2i(rng.randi_range(0, 6), row)
		while cells.has(cell):
			cell = Vector2i(rng.randi_range(0, 6), rng.randi_range(0, 3))
		cells[cell] = true
		out.append({"uid": i + 1, "id": id, "stars": 2 if rng.randf() < star2 else 1, "copies": 1, "items": [],
			"cell": [cell.x, cell.y], "cost": int(d.get("cost", 1)), "traits": (d.get("traits", []) as Array).duplicate()})
	return out


func _fight(a: Array, b: Array, s: int, kind := "jcj") -> Dictionary:
	return {"kind": kind, "a": 0, "b": 1, "board_a": a, "board_b": b, "ctx": {"stage": 3, "round": 1, "kind": kind, "seed": s,
		"a": 0, "b": 1, "ghost_of": -1, "augments": [[], []], "guardian_mult": 1.0}}


func _median(xs: Array) -> float:
	if xs.is_empty():
		return 0.0
	var s := xs.duplicate()
	s.sort()
	return float(s[s.size() / 2])


func _round(fights: Array, watch := 0) -> Array:
	dir.begin(fights, watch)
	if dir.running:
		await dir.round_finished
	return dir.results.duplicate(true)


## Lecture de l'état du compte (le mode scellé ne doit rien y changer).
func _hub() -> String:
	return JSON.stringify({"vault": Profile.vault, "loadout": Profile.loadout, "expertise": Profile.expertise, "talents": Profile.talents,
		"certificates": Profile.certificates, "insignia": Profile.insignia, "crystal": Profile.materials.get("crystal", 0),
		"chests": Profile.reward_chests, "records": Profile.records, "outfits": Profile.outfits, "collection": Profile.collection,
		"runs": Profile.runs_done, "archive": Profile.archive})


# --- Mode scellé ------------------------------------------------------------------------------------------------------
func _test_mode() -> void:
	check("Modes.current() = « autochess » (%s)" % Modes.current(), Modes.current() == "autochess")
	check("Modes.sealed() : L'Échiquier est scellé", Modes.sealed() and "autochess" in Modes.SEALED)
	check("profil ModeRules « autochess » (échelle %.3f, égalité à %d s)" % [ModeRules.num("dmg_scale"), int(ModeRules.num("draw_at"))],
		ModeRules.profile_name() == "autochess" and ModeRules.num("dmg_scale") > 0.0 and is_equal_approx(ModeRules.num("draw_at"), AutochessData.DRAW_AT))
	check("pas de règles de duel (PvpCaps) : la couche d'effets résout les coups", not Modes.is_pvp())
	# les 7 endroits du lot H2 (Run.passive_stats, Run.skill_talent, Run.certificate_pool, Run.roll_cards, Player : archive et
	# aura, certificats du compte, HeroLevel.wear_block) : compte « opti » contre compte neuf
	Run.active = true
	Run.survival = true
	Run.class_id = CID
	Run.passives = {}
	Run.passive_power = {}
	Run.skills = []
	Run.chains = {}
	Run.banned = []
	Run.kept = []
	var hero := Player.new()
	add_child(hero)
	hero.set_physics_process(false)
	hero.set_process(false)
	_fresh()
	var fresh := _sheet(hero)
	_opti()
	var opti := _sheet(hero)
	var same := true
	for k in fresh:
		if not is_equal_approx(float(opti[k]), float(fresh[k])):
			same = false
			print("      %s : opti %.4f, neuf %.4f" % [k, float(opti[k]), float(fresh[k])])
	check("compte opti = compte neuf en combat (PV %.0f, attaque %.0f : ni talents, certificats, archive ni aura)" % [opti.hp, opti.atk], same)
	check("aucun talent ni certificat dans les passifs", Run.passive_stats().is_empty())
	var talented := -1
	for id in Profile.talents.get(CID, {}):
		var eff: Dictionary = GameData.talents.get(CID, {}).get("talents", {}).get(id, {}).get("effect", {})
		if String(eff.get("type", "")).begins_with("skill_"):
			talented = int(eff.skill)
			break
	var st := Run.skill_talent(talented)
	check("aucun talent de sort (sort %d)" % talented, st.dmg == 0.0 and st.cd == 0.0 and st.duration == 0.0 and st.power == 0.0)
	check("aucun certificat proposé en carte", Run.certificate_pool().is_empty())
	var all_ids: Array = Run.class_data().get("skills", []).map(func(s): return int(s.id))
	var offered: Array = Run.roll_cards(99, true).map(func(c): return int(c.id))
	all_ids.sort()
	offered.sort()
	check("le kit entier, sans la maîtrise du compte (%d sorts)" % offered.size(), offered == all_ids)
	check("port des pièces jamais bloqué par le niveau de héros (mode scellé)", HeroLevel.wear_block({"id": "x", "level": 999, "slot": "weapon"}) == 0)
	var key := ""
	for c in GameData.talents:
		for p in GameData.talents[c].get("certificates", []):
			var k := "%s/%s" % [c, p]
			if String(TalentsPage.cert_passive(k).get("desc", "")).contains("insensible aux renversements"):
				key = k
				break
		if key != "":
			break
	Profile.certificates = [key]
	check("certificat du compte sans effet (%s)" % key, key != "" and not hero.knock_immune())
	Profile.certificates = []
	_fresh()
	hero.queue_free()
	Run.active = false
	Run.survival = false


func _fresh() -> void:
	Profile.talents = {}
	Profile.cert_board = ["", "", "", "", "", "", ""]
	Profile.archive = {}
	Profile.expertise = {}
	Profile.worn = {}
	Profile._sync_certificates()


func _opti() -> void:
	var b := Duel.opti_build(CID, 90)
	Profile.set_expertise_level(CID, 40)
	Profile.talents = {CID: (b.get("talents", {}) as Dictionary).duplicate()}
	Profile.cert_board = RivalBuilds.cert_board(b)
	Profile._sync_certificates()
	for e: Dictionary in GameData.eden_items:
		if e.has("arch") and Profile.archive.size() < 100:
			Profile.archive["e%d" % int(e.id)] = {}
	for x: Dictionary in GameData.auras:
		if not (x.aura.get("stat", {}) as Dictionary).is_empty():
			Profile.collect(x)
			Profile.set_aura(CID, String(x.aura.kind), int(x.id))
			break


func _sheet(hero: Player) -> Dictionary:
	hero.level = 30
	hero.recalc_stats()
	return {"hp": hero.max_hp, "atk": hero.atk, "matk": hero.matk, "def": hero.defense, "crit": hero.crit,
		"spd": hero.atk_speed, "dmg": hero.dmg_mult, "cdr": hero.cdr}


# --- 20 combats 5 contre 5 ------------------------------------------------------------------------------------------
func _test_fights() -> void:
	dir.fallback_ms = 0.0
	dir.set_speed(SPEED)
	var durations: Array = []
	var draws := 0
	var casts := 0
	var layer_casts := 0
	var cast_units := 0
	var units := 0
	var ally_dmg := 0
	var foreign := 0
	var autos := 0
	var clamps := 0
	var batches := 1 if quick else 2
	for batch in batches:
		var fights: Array = []
		for i in 10:
			fights.append(_fight(_team(5), _team(5), 100 * batch + i))
		dir.begin(fights, 0)
		for a in dir.arenas:
			a.ctx["keep_log"] = true
		if dir.running:
			await dir.round_finished
		for a in dir.arenas:
			var r: Dictionary = a.result
			durations.append(float(r.duration))
			if int(r.winner) < 0:
				draws += 1
			for e in a.ctx.log:
				if String(e.type) == "damage" and int(e.get("src", -1)) >= 0 and float(e.amount) > 0.0 \
						and int(a.ctx.units[int(e.src)].side) == int(a.ctx.units[int(e.dst)].side):
					ally_dmg += 1
			for side in 2:
				for u in a.nodes[side]:
					if not is_instance_valid(u):
						continue
					var au := u as AutochessUnit
					units += 1
					casts += int(au.ac_stats.casts)
					layer_casts += int(a.ctx.units[au.ac_fid].st.casts)
					cast_units += 1 if int(au.ac_stats.casts) + int(au.ac_stats.recasts) > 0 else 0
					foreign += int(au.ac_stats.foreign)
					autos += int(au.ac_stats.autos)
					clamps += int(au.ac_stats.out)
	var med := _median(durations)
	durations.sort()
	print("[ac_fight] %d combats 5 contre 5 : médiane %.1f s (min %.1f, max %.1f), égalités %d, sorts %d (%d unités sur %d), auto-attaques %d, bornes corrigées %d" % [
		durations.size(), med, durations[0], durations[-1], draws, casts, cast_units, units, autos, clamps])
	check("5 contre 5 fini en 15-45 s (médiane %.1f s sur %d combats)" % [med, durations.size()], med >= 15.0 and med <= 45.0)
	check("sorts lancés à mana pleine seulement (%d sorts, la couche en compte %d)" % [casts, layer_casts], casts > 0 and casts == layer_casts)
	check("la plupart des unités lancent leur sort (%d sur %d)" % [cast_units, units], cast_units * 2 >= units)
	check("aucun dégât allié (%d)" % ally_dmg, ally_dmg == 0)
	check("aucun coup venu d'un autre plateau (%d)" % foreign, foreign == 0)
	check("les auto-attaques passent par la couche (%d)" % autos, autos > units)


# --- 4 plateaux 10 contre 10 en même temps ------------------------------------------------------------------------------
func _test_parallel() -> void:
	dir.fallback_ms = 0.0
	dir.set_speed(1.0)
	var fights: Array = []
	for i in 4:
		fights.append(_fight(_team(10, 5, 0.3), _team(10, 5, 0.3), 500 + i))
	phys_ms = []
	_measure = true
	var res: Array = await _round(fights, 1 if not quick else 0)
	_measure = false
	var ok := res.size() == 4 and res.all(func(r): return r is Dictionary and int(r.winner) >= -1 and float(r.duration) > 0.0)
	var foreign := 0
	var sep := true
	for a in dir.arenas:
		for b in dir.arenas:
			if a != b and (a.origin as Vector3).distance_to(b.origin) < AutochessData.BOARD_SPACING - 0.1:
				sep = false
		for side in 2:
			for u in a.nodes[side]:
				if is_instance_valid(u):
					foreign += int((u as AutochessUnit).ac_stats.foreign)
	check("4 plateaux 10 contre 10 en même temps, finis (%s)" % str(res.map(func(r): return "%.0f s" % float(r.duration))), ok)
	check("plateaux à %d m les uns des autres, aucun coup de l'un sur l'autre (%d)" % [int(AutochessData.BOARD_SPACING), foreign], sep and foreign == 0)
	var med := _median(phys_ms)
	phys_ms.sort()
	var p95: float = phys_ms[int(phys_ms.size() * 0.95)] if not phys_ms.is_empty() else 0.0
	print("[ac_fight] budget : 80 unités, image physique médiane %.2f ms, p95 %.2f ms (%d images)" % [med, p95, phys_ms.size()])
	check("budget d'image mesuré : 80 unités sous %d ms (médiane %.2f ms)" % [int(AutochessDirector.FALLBACK_MS), med], med > 0.0 and med < AutochessDirector.FALLBACK_MS)
	var shown_ok := true
	for a in dir.arenas:
		if bool(a.shown) != (int(a.index) == dir.watched):
			shown_ok = false
		for u in a.nodes[0] + a.nodes[1]:
			if is_instance_valid(u) and (u as Node3D).visible != bool(a.shown):
				shown_ok = false
	check("plateau regardé seul rendu (les autres cachés)", shown_ok)
	dir.watch(2)
	check("watch(2) : le combat 2 est rendu, le 1 caché", bool(dir.arenas[2].shown) and not bool(dir.arenas[1].shown))


# --- Égalité à 45 s, Fureur à 30 s, vitesse ×2 -------------------------------------------------------------------------
func _test_draw_speed() -> void:
	dir.fallback_ms = 0.0
	var wall := {"hp": 1.0e6, "atk": 1.0, "as": 0.7, "mana_max": 140.0, "spell_base": 1.0, "def": 50.0, "mdef": 50.0}
	var a := _team(2)
	var b := _team(2)
	for u in a + b:
		u["sheet"] = wall.duplicate()
	var fury := [-1.0]
	var on_fury := func(i: int): fury[0] = float(dir.arenas[i].t)
	dir.fury_started.connect(on_fury)
	dir.set_speed(2.0)
	dir.begin([_fight(a, b, 900)], 0)
	var ts := Engine.time_scale
	var r0 := Time.get_ticks_msec()
	for _i in 120:
		await get_tree().physics_frame
	var ratio := float(dir.arenas[0].t) / maxf((Time.get_ticks_msec() - r0) / 1000.0, 0.001)
	if dir.running:
		await dir.round_finished
	dir.fury_started.disconnect(on_fury)
	var r: Dictionary = dir.results[0]
	check("×2 : Engine.time_scale %.1f pendant le combat, temps du combat %.2f × le temps réel" % [ts, ratio], is_equal_approx(ts, 2.0) and ratio > 1.4 and ratio < 2.6)
	check("×2 rendu à ×1 après le combat (%.1f)" % Engine.time_scale, is_equal_approx(Engine.time_scale, 1.0))
	check("égalité à 45 s : les deux camps debout (vainqueur %d, %.1f s, %s)" % [int(r.winner), float(r.duration), str(r.stars)],
		int(r.winner) == -1 and absf(float(r.duration) - AutochessData.DRAW_AT) < 0.5 and (r.stars[0] as Array).size() == 2 and (r.stars[1] as Array).size() == 2)
	check("Fureur annoncée à %d s (%.1f s)" % [int(AutochessData.SUDDEN_AT), fury[0]], fury[0] >= AutochessData.SUDDEN_AT and fury[0] < AutochessData.SUDDEN_AT + 0.5)
	dir.set_speed(1.0)


# --- Repli : plateaux cachés finis par le combat de données ------------------------------------------------------------
func _test_fallback() -> void:
	var fights: Array = []
	for i in 4:
		fights.append(_fight(_team(3), _team(3), 700 + i))
	dir.fallback_ms = 0.0001  # toute image est « trop longue »
	dir.fallback_after = 0.3
	dir.set_speed(4.0)
	var res: Array = await _round(fights, 0)
	var modes: Array = dir.arenas.map(func(a): return String(a.mode))
	check("repli : les 3 plateaux cachés finis par le combat de données, le regardé en vrai (%s)" % str(modes),
		modes == ["real", "data", "data", "data"])
	check("repli : résultats valides (%s)" % str(res.map(func(r): return "%d/%.0f s" % [int(r.winner), float(r.duration)])),
		res.all(func(r): return int(r.winner) >= -1 and int(r.winner) <= 1 and float(r.duration) > 0.0 and float(r.duration) <= AutochessData.DRAW_AT + 0.2))
	var d := AutochessDirector.data_fight(_team(5), _team(5), {"seed": 3, "kind": "jcj", "augments": [[], []]})
	check("combat de données injectable (vainqueur %d, %.1f s)" % [int(d.winner), float(d.duration)], d.has("stars") and float(d.duration) > 0.0)
	dir.fallback_ms = AutochessDirector.FALLBACK_MS
	dir.fallback_after = AutochessDirector.FALLBACK_AFTER
	dir.set_speed(1.0)


# --- Une partie de la machine : manches réelles injectées dans finish_combat --------------------------------------------
func _test_game() -> void:
	dir.fallback_ms = 0.0
	dir.set_speed(4.0)
	var g := Autochess.new()
	g.save_path = ""
	var strats: Array = []
	for i in AutochessData.PLAYERS:
		strats.append(Autochess.RandomStrategist.new())
	g.start(41, strats)
	var real_rounds := 0
	var pvp_ok := false
	var monsters_ok := false
	var guard := 0
	while not g.is_over() and guard < 40 and not (g.stage == 2 and g.round_i > 1):
		guard += 1
		match g.phase:
			"prep":
				g.end_prep()
			"combat":
				var kind := g.round_kind()
				var hp_before: Array = g.players.map(func(p): return int(p.hp))
				var n := g.fights.size()
				var res: Array = await dir.play_round(g)
				real_rounds += 1
				var valid := res.size() == n and res.all(func(r): return int(r.winner) >= -1 and float(r.duration) > 0.0)
				print("[ac_fight] manche %s (%s) : %d combats réels, %s" % [g.round_key(), kind, n, str(res.map(func(r): return "%d/%.0f s" % [int(r.winner), float(r.duration)]))])
				if kind == "jcj":
					var hp_after: Array = g.players.map(func(p): return int(p.hp))
					pvp_ok = valid and g.phase in ["recap", "over"] and g.results.size() == n and hp_after != hp_before
				elif kind == "monstres":
					monsters_ok = valid and g.phase in ["recap", "over"] and g.results.size() == n
			"recap":
				g.next_round()
	check("manches de monstres jouées en vrai, résultats rendus à la machine", monsters_ok)
	check("manche JcJ 2-1 : combats réels injectés dans Autochess.finish_combat (PV de joueur entamés)", pvp_ok)
	check("réserve intacte après les manches réelles", g.pool_ok())
	dir.set_speed(1.0)
