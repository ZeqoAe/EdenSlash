extends Node
## Passe M6 : une Ruée des boss ou un Siège joué en entier par le pilote automatique (aide « Bot » : déplacement, attaques et
## sorts automatiques ; cartes, escaliers et répits seuls), pour mesurer la durée de chaque étape et les dégâts subis.
##   godot --headless --fixed-fps 60 --path game res://tools/m6_run.tscn -- --mode=rush|siege --diff=0..2 --class=warrior
##         --hub=E.C.N.G [--zone=limestone] [--human=0.85] [--max=2400] [--seed=1] [--rush-seed=4821] [--mods=no_heal,enraged]
##         [--immortal=1] [--legacy=1]
## --immortal=1 : le héros ne meurt pas (le pilote n'esquive jamais : il meurt même contre les boss d'avant M6) ; on lit alors
## « PV max perdus » par étape (dégâts subis × la part non évitée --human, rapportés aux PV max). Comme la sonde boss_ttk, les
## totems et les cristaux de soin sont cassés après 8 s (un joueur les casse ; l'aide « Bot » ne vise que le boss).
## --legacy=1 : la Ruée d'avant M6 (boss des zones, renforts) pour comparer. Lignes « [m6run] … ». Profil jetable (APPDATA).
## --hero-level=N (lot H5) : niveau de héros du profil (défaut 90) ; sous le niveau de l'activité, le héros s'y bat à son niveau.

const TOTEM_TIME := 8.0

var mode := "rush"
var diff := 0
var cid := "warrior"
var hub := "new"
var zone := "limestone"
var human := 0.85
var max_t := 2400.0
var rush_seed := 0
var mods: Array = []
var legacy := false
var immortal := false
var hero_lv := 90  # --hero-level=N (lot H5) : niveau de héros ; 90 = toujours au niveau de l'activité (mesures d'avant H5)


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=")
		if kv.size() < 2:
			continue
		match kv[0]:
			"mode": mode = kv[1]
			"diff": diff = int(kv[1])
			"class": cid = kv[1]
			"hub": hub = kv[1]
			"zone": zone = kv[1]
			"human": human = float(kv[1])
			"max": max_t = float(kv[1])
			"seed": seed(int(kv[1]))
			"rush-seed": rush_seed = int(kv[1])
			"mods": mods = Array(kv[1].split(","))
			"legacy": legacy = kv[1] == "1"
			"immortal": immortal = kv[1] == "1"
			"hero-level": hero_lv = clampi(int(kv[1]), 1, HeroLevel.MAX_LEVEL)
	Settings.reset_all(false)
	Profile.selected_class = cid
	Profile.records["epochs_cleared"] = 4
	Profile.records[HeroLevel.KEY] = HeroLevel.total_for(hero_lv)  # lot H5 : niveau de héros du profil de mesure
	if hub != "new":
		Profile.install_gear(StarterGear.scenario(hub, cid))
	var pe := GearPower.hero_power()
	if mode == "siege":
		Tower.start_siege(cid, zone, diff, [])
	else:
		if rush_seed > 0:
			Profile.records["rush_seed"] = rush_seed
		Profile.records["rush_mods"] = 0
		for m in mods:
			if m != "":
				Rush.toggle(m)
		Tower.start_dungeon(cid, Dungeons.RUSH, diff, [])
		if legacy:
			Rush.lineup = []
	var advised := Siege.advised(zone, diff) if mode == "siege" else Rush.advised(diff)
	print("[m6run] début mode=%s diff=%d classe=%s hub=%s PE=%d conseillée=%d rapport=%.2f estimation=%s boss=%s" % [mode, diff, cid, hub, pe, advised,
		float(pe) / maxf(float(advised), 1.0), DifficultyPanel.verdict(pe, advised)[0],
		Rush.lineup if mode == "rush" else [Siege.boss_for(zone)] + Siege.lieutenants_for(zone)])
	Run.test_taken = 1.0 - clampf(human, 0.0, 0.95)
	var world: Node = load("res://scenes/world.tscn").instantiate()
	get_tree().root.add_child.call_deferred(world)
	await get_tree().create_timer(3.0).timeout
	var p: Player = world.player
	world.cards._queue.clear()
	world.cards._show_next()
	p.autoplay = true
	for k in Settings.PRESETS.bot.game:
		Settings.data["game"][k] = Settings.PRESETS.bot.game[k]
	world.revives_left = 0
	p.immortal = immortal
	var t := 0.0
	var step := Tower.floor_n
	var step_t0 := 0.0
	var step_dmg0 := 0.0
	var times: Array = []
	var lost: Array = []  # PV max perdus par étape
	var res := "temps"
	var td = world.director.tower
	var shield_t := 0.0
	var crystal_t := 0.0
	var top := Tower.top()
	var dmg_now := 0.0
	while t < max_t:
		await get_tree().physics_frame
		var dt := get_physics_process_delta_time()
		t += dt
		if world.cards.is_open():
			world.cards._choose(0)
		var boss: Monster = td._boss if is_instance_valid(td) and is_instance_valid(td._boss) else null
		shield_t = shield_t + dt if boss != null and boss.shielded else 0.0
		if shield_t > TOTEM_TIME and boss.brain:
			for tt in boss.brain._totems:
				if is_instance_valid(tt) and not tt.is_dead:
					tt.take_damage(tt.max_hp * 10.0 + 1.0, p)
			shield_t = 0.0
		var crys := get_tree().get_nodes_in_group("monsters").filter(func(m): return m.display_name == "Cristal de soin" and not m.is_dead)
		crystal_t = crystal_t + dt if not crys.is_empty() else 0.0
		if crystal_t > TOTEM_TIME:
			for c in crys:
				c.take_damage(c.max_hp * 10.0 + 1.0, p)
			crystal_t = 0.0
		if Tower.floor_n != step:
			var dmg := _taken()
			times.append(roundi(t - step_t0))
			lost.append(snappedf((dmg - step_dmg0) / maxf(p.max_hp, 1.0), 0.01))
			print("[m6run] étape %d finie en %d s · PV max perdus %.2f · t=%d" % [step, roundi(t - step_t0), lost[-1], roundi(t)])
			step = Tower.floor_n
			step_t0 = t
			step_dmg0 = dmg
		if not is_instance_valid(p) or p.is_dead:
			res = "mort"
			break
		if mode == "siege" and is_instance_valid(td) and td.phase in ["ring", "ffa"]:
			res = "boss_vaincu"
			break
		if not Tower.active:
			res = "victoire" if Tower.reached >= top else "défaite"
			break
		dmg_now = _taken()  # (le journal est remis à zéro à la fin de la partie)
	# dernière étape (inachevée, le dernier boss ou le boss du siège)
	times.append(roundi(t - step_t0))
	lost.append(snappedf((dmg_now - step_dmg0) / maxf(p.max_hp if is_instance_valid(p) else 1.0, 1.0), 0.01))
	var boss_left := -1.0
	if is_instance_valid(td) and is_instance_valid(td._boss) and not td._boss.is_dead:
		boss_left = td._boss.hp / maxf(td._boss.max_hp, 1.0)
	var worst := 0.0
	for x in lost:
		worst = maxf(worst, float(x))
	print("[m6run] fin mode=%s diff=%d classe=%s hub=%s PE=%d résultat=%s étape=%d durée=%d étapes=%s perdus=%s pire=%.2f boss_restant=%.2f étoiles=%s" % [mode, diff,
		cid, hub, pe, res, step, roundi(t), times, lost, worst, boss_left, Siege.stars_done])
	get_tree().quit()


## Dégâts subis par le héros depuis le début (journal de run : boss, monstres, élites, autres).
func _taken() -> float:
	var c := RunJournal.counters
	var s := 0.0
	for k in ["normal", "elite", "boss", "autre"]:
		s += float(c.get("dmg_taken_" + k, 0.0))
	return s
