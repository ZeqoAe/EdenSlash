extends Node
## Lot MB-F (Les Deux Voies, conception/benchmark/R_MB_F.md) : jungle neutre et objectifs.
## 1. Règles pures : tables (validate), Marée (vagues resserrées, géant de plus, réapparition × 1,5), décision aux points
##    (structures, Cœur, objectifs, or, sbires), forces des camps et des objectifs, briques jouables d'une fosse.
## 2. Partie réelle dans world.tscn (vagues seules, horloge avancée à 1:20, × 2) : 8 camps et 2 objectifs préparés au
##    chargement (aucune création ensuite), apparition à 1:30, neutres (leur propre chacun-pour-soi, hors de TeamMatch, ne
##    frappent pas qui ne les touche pas), sommeil sans héros, laisse et remise à zéro, Source (recharges), Braise (brûlure
##    et ralenti), bonus qui passent au tueur, Gardien (boss de la bibliothèque, 2 briques sans invocation, annonce, Sceau :
##    dégâts et PV, suivis à la refonte de fiche), Colosse (3 briques, fureur après 90 s retirée à la remise à zéro, Bannière :
##    sbires × 1,5 et plus gros, rappel en 3 s), Cœurs vulnérables à la Marée, interface de l'IA, coût du nœud.
## 3. Fin au temps dans un processus à part (horloge à 24:40, × 4) : la partie s'arrête à 25:00 et la décision est rendue.
## godot --headless --path game res://tests/test_mb_objectives.tscn

var fails := 0
var downs: Array = []


func check(label: String, ok: bool) -> void:
	print(("OK    " if ok else "ÉCHEC ") + label)
	if not ok:
		fails += 1


func _ready() -> void:
	Settings.reset_all()
	_pure_rules()
	await _world()
	_end_at_time()
	print("TOUT EST OK (0 échec(s))" if fails == 0 else "ÉCHECS : %d" % fails)
	get_tree().quit(fails)


func _pure_rules() -> void:
	check("tables cohérentes (camps, objectifs, textes sans pourcentage)", MobaData.validate().is_empty())
	check("Marée : vagues toutes les 30 s jusqu'à 17:40, puis toutes les TIDE_WAVE_EVERY s dès 18:10",
		is_equal_approx(MobaData.wave_time(35), 1060.0) and is_equal_approx(MobaData.wave_time(36), 1090.0)
		and is_equal_approx(MobaData.wave_time(37), 1090.0 + MobaData.TIDE_WAVE_EVERY) and is_equal_approx(MobaData.wave_time(3), 100.0))
	check("Marée : un géant de plus par vague (deux si la T2 adverse est tombée), aucun avant",
		MobaData.wave(36, 1090.0).count("giant") == 1 and MobaData.wave(36, 1090.0, 1).count("giant") == 2
		and MobaData.wave(20, 640.0).count("giant") == 0)
	check("Marée : réapparition × 1,5", is_equal_approx(MobaData.respawn_time(5, 1100.0), 15.0 * 1.5))
	Moba.reset()
	Moba.objectives_taken = [1, 0]
	var w := Moba.decide([1.0, 1.0])
	check("décision au temps : à structures et Cœur égaux, les objectifs (%s)" % Moba.decided_by, w == 0 and Moba.decided_by == "objectifs")
	Moba.objectives_taken = [1, 1]
	Moba.team_gold = [800, 1900]
	w = Moba.decide([1.0, 1.0])
	check("… puis l'or des équipes (%s)" % Moba.decided_by, w == 1 and Moba.decided_by == "or")
	Moba.team_gold = [0, 0]
	w = Moba.decide([1.0, 1.0])
	check("… tout égal : aucune équipe (%s)" % Moba.decided_by, w == -1 and Moba.decided_by == "égalité")
	Moba.structures_down = [1, 2]
	w = Moba.decide([1.0, 0.5], [9000, 0])
	check("… les structures d'abord (%s)" % Moba.decided_by, w == 1 and Moba.decided_by == "structures")
	check("points d'une équipe (tableau)", int(Moba.score(1).structures) == 2 and Moba.score(0).has("objectives"))
	Moba.reset()
	var ps := MobaData.camp_stats("petit", 90.0)
	var bs := MobaData.camp_stats("source", 90.0)
	check("camps : forces relatives au héros attendu (buff > petit)", float(ps.hp) > 0.0 and float(bs.hp) > float(ps.hp) and float(ps.atk) > 0.0)
	var g := MobaData.objective_stats("guardian", 180.0)
	check("Gardien : PV en auto-attaques du héros niveau 5 (au moins)", is_equal_approx(float(g.hp), float(MobaData.OBJECTIVES.guardian.hits) * float(MobaData.ref_hero(5.0).auto)))
	check("Gardien revenu tard : plus fort", float(MobaData.objective_stats("guardian", 900.0).hp) > float(g.hp))
	var bad := []
	var ok2 := 0
	var ok3 := 0
	for id in BossLibrary.ids():
		var list := MobaJungle.pit_bricks(String(id))
		for b in list:
			var t := String(b.type)
			if t in MobaData.BOSS_BANNED.types or BossBricks.family_of(t) in MobaData.BOSS_BANNED.families or t == "frenzy":
				bad.append("%s:%s" % [id, t])
		ok2 += 1 if list.size() >= 2 else 0
		ok3 += 1 if list.size() >= 3 else 0
	check("briques d'une fosse : ni invocation, ni bouclier à invoquer, ni arène (%d boss pour le Gardien, %d pour le Colosse)" % [ok2, ok3],
		bad.is_empty() and ok2 >= 10 and ok3 >= 5)


func _world() -> void:
	seed(77)
	Profile.selected_class = "warrior"
	Moba.launch("warrior", {"heroes": "none", "speed": 2.0, "seed": 77, "clock": 80.0})
	var world: Node = load("res://scenes/world.tscn").instantiate()
	get_tree().root.add_child.call_deferred(world)
	await _until(func(): return world.is_inside_tree() and world.get("director") != null and is_instance_valid(world.director.team), 900)
	var dd: MobaDirector = world.director.team as MobaDirector
	if dd == null:
		check("directeur des Deux Voies monté", false)
		Moba.finish()
		return
	await _until(func(): return dd.map != null and dd.map.nav_ready(), 900)
	var j: MobaJungle = dd.jungle
	check("jungle montée par le directeur", j != null and MobaJungle.active and MobaJungle.current == j)
	if j == null:
		Moba.finish()
		return
	j.neutral_down.connect(func(e, _k, t): downs.append([String(e.key), t]))
	var units := 0
	var parked := true
	for e in j.camps:
		units += (e.units as Array).size()
		for u in e.units:
			parked = parked and u is MobaCamp and u.parked and not u.visible
	check("8 camps (12 monstres : 4 petits de 2, Source, Braise), créés au chargement et en réserve avant 1:30 (%d)" % units,
		j.camps.size() == 8 and units == 12 and parked)
	var gd: Dictionary = j.objectives.get("guardian", {})
	var cd: Dictionary = j.objectives.get("colossus", {})
	check("Gardien et Colosse : deux boss différents de la bibliothèque (%s, %s)" % [gd.get("boss_id", "?"), cd.get("boss_id", "?")],
		not gd.is_empty() and not cd.is_empty() and BossLibrary.has(String(gd.boss_id)) and BossLibrary.has(String(cd.boss_id)) and gd.boss_id != cd.boss_id)
	check("Gardien 2 briques, Colosse 3 (%s / %s)" % [",".join(gd.get("bricks", [])), ",".join(cd.get("bricks", []))],
		(gd.get("bricks", []) as Array).size() == 2 and (cd.get("bricks", []) as Array).size() == 3)
	check("14 monstres neutres préparés (12 + 2 boss), aucun créé en partie (%d)" % int(j.stats.created_load), int(j.stats.created_load) == 14 and int(j.stats.created_live) == 0)
	check("horloge avancée à 1:20 : vagues déjà parties comptées (%d)" % dd.wave_n, Moba.t >= 80.0 and dd.wave_n == 2)
	# --- apparition des camps à 1:30 ---
	await _until(func(): return Moba.t >= 91.0, 60 * 30)
	var alive := 0
	var neutral := true
	for e in j.camps:
		alive += 1 if String(e.state) == "alive" else 0
		for u in e.units:
			neutral = neutral and u.visible and not u.parked and u.ffa_id == MobaData.NEUTRAL_FFA and u.is_in_group("ffa") and TeamMatch.team_of(u) == -1
	check("1:30 : les 8 camps apparaissent", alive == 8)
	check("camps neutres : leur propre chacun-pour-soi, hors de TeamMatch", neutral)
	var petit := _camp(j, "petit", 0)
	var u0: MobaCamp = petit.units[0]
	check("force d'un petit camp à son apparition", absf(u0.max_hp - float(MobaData.camp_stats("petit", 90.0).hp)) / u0.max_hp < 0.05)
	await _until(func(): return _asleep(j) >= 8, 60 * 4)
	check("sans héros à 22 m : les camps dorment (%d monstres)" % _asleep(j), _asleep(j) >= 8)
	# --- neutralité : un héros qui ne frappe pas n'est pas visé ---
	var red := MobaRival.make(dd, "warrior", 3, 2, 1)
	dd.add_child(red)
	red.global_position = petit.pos + Vector3(2.0, 0.4, 0.0)
	j.guests.append(red)
	await _secs(2.0)
	check("neutre : un héros qui passe sans frapper n'est pas pris pour cible", u0._player == null and red.hp >= red.max_hp - 0.5)
	# --- laisse et remise à zéro ---
	var blue := MobaRival.make(dd, "thief", 3, 2, 0)
	dd.add_child(blue)
	blue.global_position = petit.pos + Vector3(-4.0, 0.4, 0.0)
	j.guests.append(blue)
	red.global_position = petit.pos + Vector3(60.0, 0.4, 0.0)
	await _secs(0.3)
	u0.take_damage(u0.max_hp * 0.3, blue)
	await _secs(0.6)
	var u1: MobaCamp = petit.units[1]
	check("frappé : tout le camp vise son agresseur (et se réveille)", petit.aggro.has(blue) and u0._player == blue and u1._player == blue
		and not u0.asleep and not u1.asleep)
	check("frappé : PV entamés", u0.hp < u0.max_hp * 0.75)
	blue.global_position = petit.pos + Vector3(-45.0, 0.4, 0.0)
	await _until(func(): return u0.resetting or (u0.hp >= u0.max_hp - 0.5 and u0._away() < 1.5), 60 * 3)
	check("laisse : l'agresseur s'éloigne de plus de 12 m, le camp revient", (petit.aggro as Dictionary).is_empty())
	await _until(func(): return not u0.resetting and u0.hp >= u0.max_hp - 0.5, 60 * 12)
	check("remise à zéro : PV pleins, de retour au camp (%.1f m)" % u0._away(), u0.hp >= u0.max_hp - 0.5 and u0._away() < 1.5 and not u0.resetting)
	# --- Source : recharges ---
	var src := _camp(j, "source", 0)
	blue.global_position = src.pos + Vector3(-3.0, 0.4, 0.0)
	await _secs(0.3)
	for u in src.units:
		u.take_damage(u.max_hp * 3.0, blue)
	await _secs(0.2)
	check("Source tombée : camp vidé, réapparition dans 150 s", String(src.state) == "dead" and absf(float(src.respawn_at) - Moba.t - 150.0) < 2.0)
	check("Source : le bonus au tueur (%s)" % str(j.buffs_of(blue).keys()), blue.has_status("moba_source") and j.buffs_of(blue).has("source"))
	check("récompense rendue au bon camp (bleu)", downs.any(func(x): return String(x[0]) == String(src.key) and int(x[1]) == 0) and Moba.neutral_kills[0] >= 1)
	blue._skill_ready[987654] = blue._time + 10.0
	var before := float(blue._skill_ready[987654])
	j.tend_hero(blue, 1.0)
	check("Source : les minuteurs de sorts d'un héros scripté avancent plus vite (recharge × 0,8)",
		absf((before - float(blue._skill_ready[987654])) - 0.25) < 0.01)
	blue._skill_ready.erase(987654)
	var reward := j.reward(src)
	check("récompense du camp lisible par l'économie (XP 100, or 100)", int(reward.xp) == 100 and int(reward.gold) == 100)
	# --- Braise : brûlure et ralenti ---
	var br := _camp(j, "braise", 0)
	blue.global_position = br.pos + Vector3(-3.0, 0.4, 0.0)
	await _secs(0.3)
	for u in br.units:
		u.take_damage(u.max_hp * 3.0, blue)
	await _secs(0.2)
	check("Braise : le bonus au tueur", blue.has_status("moba_braise"))
	u0.take_damage(1.0, blue)
	check("Braise : les coups brûlent et ralentissent", u0.has_status("burn") and u0.has_status("chill"))
	var tw: MobaStructure = dd.structure_of(1, 0, 1)
	tw.take_damage(1.0, blue)
	check("Braise : jamais sur une structure", not tw.has_status("burn"))
	j.reset_entry(petit)
	j._on_hero_died(blue, red)
	check("bonus de camp passés au héros adverse qui l'élimine", red.has_status("moba_source") and red.has_status("moba_braise"))
	# --- Gardien : annonce, apparition, Sceau ---
	j.force_spawn("guardian")
	await _secs(0.2)
	var gu: MobaCamp = gd.unit
	check("Gardien : apparu dans sa fosse (%s)" % gu.display_name, String(gd.state) == "alive" and gu.visible and not gu.parked
		and gu.global_position.distance_to(gd.pos) < 2.5 and "Gardien" in gu.display_name)
	check("Gardien : cerveau de boss à ses 2 briques", gu.brain != null and gu.brain.bricks.size() == 2)
	check("Gardien : annoncé au joueur", j.said.any(func(x): return "apparaît" in String(x[1])))
	blue.global_position = gd.pos + Vector3(-4.0, 0.4, 0.0)
	var base_hp := blue.max_hp
	j.tend_hero(blue, 0.016)
	base_hp = blue.max_hp
	await _secs(0.2)
	gu.take_damage(gu.max_hp * 0.1, blue)
	await _secs(0.4)
	check("Gardien : vise son agresseur", gu._player == blue)
	gu.take_damage(gu.max_hp * 3.0, blue)
	await _secs(0.2)
	check("Gardien pris : un Sceau pour l'équipe bleue, revient dans 3 min", j.seals[0] == 1 and j.seals[1] == 0 and int(gd.taken[0]) == 1
		and Moba.objectives_taken[0] == 1 and String(gd.state) == "dead" and absf(float(gd.at) - Moba.t - 180.0) < 2.0)
	check("Sceau : + 4 %% de dégâts (%.3f)" % MobaJungle.dealt_mult(blue), is_equal_approx(MobaJungle.dealt_mult(blue), 1.04)
		and is_equal_approx(MobaJungle.dealt_mult(red), 1.0) and is_equal_approx(blue.damage_dealt_mult(), 1.04))
	j.tend_hero(blue, 0.016)
	check("Sceau : + 4 % de PV max", absf(blue.max_hp / base_hp - 1.04) < 0.002)
	blue.resheet(3)
	j.tend_hero(blue, 0.016)
	check("Sceau : remis après une refonte de fiche (niveau, objets)", absf(blue.max_hp / base_hp - 1.04) < 0.002)
	# --- Colosse : annonce, fureur, remise à zéro, Bannière ---
	cd.at = Moba.t + 20.0
	await _secs(0.2)
	check("Colosse : annoncé 60 s avant (ici 20)", bool(cd.announced) and j.said.any(func(x): return "arrive dans" in String(x[1])))
	j.force_spawn("colossus")
	await _secs(0.2)
	var cu: MobaCamp = cd.unit
	check("Colosse : apparu, 3 briques", String(cd.state) == "alive" and cu.visible and cu.brain != null and cu.brain.bricks.size() == 3)
	blue.global_position = cd.pos + Vector3(-4.0, 0.4, 0.0)
	await _secs(0.2)
	cu.take_damage(cu.max_hp * 0.05, blue)
	cd.engaged_at = Moba.t - 95.0
	await _secs(0.2)
	check("Colosse : fureur après 90 s de combat (cran %d)" % int(cd.fury), int(cd.fury) >= 1 and cu.atk > cu.base_atk * 1.05)
	j.reset_entry(cd)
	await _until(func(): return not cu.resetting, 60 * 10)
	check("remise à zéro du boss : fureur retirée, PV pleins", int(cd.fury) == 0 and is_equal_approx(cu.atk, cu.base_atk) and cu.hp >= cu.max_hp - 0.5)
	cu.take_damage(cu.max_hp * 3.0, blue)
	await _secs(0.2)
	check("Colosse pris : la Bannière aux héros bleus vivants, 150 s", blue.has_status("moba_banner") and float(j.banner_until[0]) > Moba.t + 140.0
		and not red.has_status("moba_banner"))
	check("Bannière : rappel en 3 s", is_equal_approx(j.recall_time(blue), 3.0) and is_equal_approx(j.recall_time(red), MobaData.RECALL_TIME))
	await _until(func(): return _blue_minion(dd) != null, 60 * 30)
	var mm: MobaMinion = _blue_minion(dd)
	if mm != null:
		blue.global_position = mm.global_position + Vector3(3.0, 0.0, 0.0)
		check("Bannière : sbire allié à 12 m × 1,5 (coups et sièges)", is_equal_approx(mm.banner_mult(), 1.5)
			and is_equal_approx(mm.hit_amount(red), mm.atk * dd.minion_aura(mm) * 1.5))
		j._banner_look()
		check("Bannière : sbire plus gros", mm.model.scale.x > mm._base_scale.x * 1.1)
		blue.global_position = mm.global_position + Vector3(40.0, 0.0, 0.0)
		check("Bannière : loin du porteur, rien", is_equal_approx(mm.banner_mult(), 1.0))
		j._banner_look()
		check("Bannière : taille rendue", is_equal_approx(mm.model.scale.x, mm._base_scale.x))
	else:
		check("un sbire bleu en jeu", false)
	# --- Marée : Cœurs vulnérables ---
	var keep := Moba.t
	var inv_before: bool = dd.cores[1].invulnerable()
	Moba.t = MobaData.TIDE_AT + 1.0
	var inv_tide: bool = dd.cores[1].invulnerable()
	Moba.t = keep
	check("Marée : les Cœurs deviennent vulnérables même si leurs T2 tiennent", inv_before and not inv_tide)
	# --- interface de l'IA ---
	var cl := j.camps_alive()
	var os := j.objectives_state()
	check("IA : camps vivants avec position, danger, temps visé (%d)" % cl.size(), cl.size() >= 6 and cl[0].has("pos") and float(cl[0].danger) > 0.0
		and float(cl[0].ttk) > 0.0 and j.camp_list().size() == 8)
	check("IA : état des objectifs (Gardien revient, Colosse pris, Sceaux, Bannière)", os.has("guardian") and float(os.guardian.spawn_in) > 100.0
		and String(os.colossus.state) == "dead" and (os.seals as Array)[0] == 1 and float((os.banner_until as Array)[0]) > Moba.t)
	check("aucun monstre neutre créé pendant la partie", int(j.stats.created_live) == 0)
	var c := j.cost()
	check("coût du nœud de la jungle : %.0f µs par image en moyenne (au pire %.0f)" % [float(c.us_avg), float(c.us_max)], float(c.us_avg) < 300.0)
	TeamMatch.end()
	Moba.reset()
	Engine.time_scale = 1.0
	world.queue_free()
	await get_tree().process_frame
	Run.active = false
	Profile.in_run = false
	check("après la partie : jungle éteinte, menu", not MobaJungle.active and Modes.current() == "menu")


func _camp(j: MobaJungle, camp: String, half: int) -> Dictionary:
	for e in j.camps:
		if String(e.camp) == camp and int(e.half) == half:
			return e
	return {}


func _blue_minion(dd: MobaDirector) -> MobaMinion:
	for m in dd.minions:
		if not m.is_dead and m.side == 0 and m.visible:
			return m
	return null


func _asleep(j: MobaJungle) -> int:
	var n := 0
	for e in j.camps:
		for u in e.units:
			n += 1 if u.asleep else 0
	return n


## Fin au temps dans un processus à part : horloge à 24:40, × 4 ; la ligne « [moba] fin » dit le vainqueur et la raison.
func _end_at_time() -> void:
	var args := ["--headless", "--fixed-fps", "60", "--path", ProjectSettings.globalize_path("res://"), "res://scenes/world.tscn", "--",
		"--moba", "--moba-heroes=none", "--moba-speed=4", "--moba-clock=1480", "--moba-power=1.3,1.0", "--auto-quit"]
	var out := []
	var t0 := Time.get_ticks_msec()
	OS.execute(OS.get_executable_path(), args, out, true)
	var fin := ""
	for chunk in out:
		for l in String(chunk).split("\n"):
			if l.begins_with("[moba] fin"):
				fin = l
	print("[mb-f] fin au temps (%.0f s) : %s" % [(Time.get_ticks_msec() - t0) / 1000.0, fin.left(200)])
	check("fin au temps : la partie s'arrête à 25:00 et la décision est rendue", "(time" in fin and "25:00" in fin)


func _secs(s: float) -> void:
	var t := Moba.t + s
	await _until(func(): return Moba.t >= t, int(s * 60.0 / maxf(Engine.time_scale, 0.1)) + 120)


func _until(cond: Callable, max_frames := 300) -> void:
	for _i in max_frames:
		if cond.call():
			return
		await get_tree().physics_frame
