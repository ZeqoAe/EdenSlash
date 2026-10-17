extends Node
## Passe M3 : la Tour jouée par le pilote automatique (aide « Bot » : déplacement, attaques et sorts automatiques ; cartes,
## coffres et escaliers seuls) à partir d'un étage, pour mesurer la durée de chaque étage selon son type, la mort ou non,
## et les dégâts subis.
##   godot --headless --fixed-fps 60 --path game res://tools/tower_run.tscn -- --from=1 --floors=10 --diff=1 --class=warrior
##         --hub=E.C.N.G [--human=0.5] [--max=1800] [--seed=1]
## --dodge : le pilote sort des zones rouges annoncées (PilotDodge, passe M8). --god : héros invincible (temps pour tuer). --hub : équipement du hub (StarterGear.scenario, « new » : compte neuf) ; --human : part des coups évitée (Run.test_taken).
## Une ligne « [tour-étage] » par étage, puis « [tour] » (bilan). Profil jetable (EDEN_PROFILE).
## --hero-level=N (lot H5) : niveau de héros du profil (défaut 90) ; sous le niveau de l'étage, le héros s'y bat à son niveau.

var from := 1
var floors := 10
var diff := 1
var cid := "warrior"
var hub := "new"
var human := 0.5
var max_t := 1800.0
var hero_lv := 90  # --hero-level=N (lot H5) : niveau de héros ; 90 = toujours au niveau de l'étage (mesures d'avant H5)
var _taken := 0.0
var _hp_last := 0.0


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=")
		if kv.size() < 2:
			continue
		match kv[0]:
			"from": from = int(kv[1])
			"floors": floors = int(kv[1])
			"diff": diff = int(kv[1])
			"class": cid = kv[1]
			"hub": hub = kv[1]
			"human": human = float(kv[1])
			"max": max_t = float(kv[1])
			"seed": seed(int(kv[1]))
			"hero-level": hero_lv = clampi(int(kv[1]), 1, HeroLevel.MAX_LEVEL)
	Settings.reset_all(false)
	Profile.selected_class = cid
	Profile.records[HeroLevel.KEY] = HeroLevel.total_for(hero_lv)  # lot H5 : niveau de héros du profil de mesure
	Profile.save_profile()
	if hub != "new":
		Profile.install_gear(StarterGear.scenario(hub, cid))
	Tower.start(cid, diff, from)
	Run.test_taken = 1.0 - clampf(human, 0.0, 0.95)
	PilotDodge.enabled = "--dodge" in OS.get_cmdline_user_args()  # passe M8 : le pilote sort des zones rouges
	var world: Node = load("res://scenes/world.tscn").instantiate()
	get_tree().root.add_child.call_deferred(world)
	await get_tree().create_timer(3.0).timeout
	var p: Player = world.player
	world.cards._queue.clear()
	world.cards._show_next()
	p.autoplay = true
	p.dev_invincible = "--god" in OS.get_cmdline_user_args()  # mesure du temps pour tuer seulement
	for k in Settings.PRESETS.bot.game:
		Settings.data["game"][k] = Settings.PRESETS.bot.game[k]
	_hp_last = p.hp
	p.health_changed.connect(func(now, _m):
		if now < _hp_last:
			_taken += _hp_last - now
		_hp_last = now)
	var t := 0.0
	var f := Tower.floor_n
	var f_t := 0.0
	var f_taken := 0.0
	var res := "temps"
	var last := from + floors - 1
	var by_type := {}
	var shield_t := 0.0
	while t < max_t:
		await get_tree().physics_frame
		var dt := get_physics_process_delta_time()
		t += dt
		# totems et cristaux de soin : l'aide « Bot » ne vise que le boss ; un joueur les casse en quelques secondes (comme
		# la sonde tools/boss_ttk : cassés après 8 s)
		var boss = world.director.tower._boss if is_instance_valid(world) and world.director.tower else null  # (non typé : il a pu être libéré)
		var shields: Array = get_tree().get_nodes_in_group("monsters").filter(func(m): return not m.is_dead and m.display_name in ["Cristal de soin", "Totem"])
		if is_instance_valid(boss) and boss.brain:
			shields.append_array(boss.brain._totems.filter(func(x): return is_instance_valid(x) and not x.is_dead))
		shield_t = shield_t + dt if not shields.is_empty() else 0.0
		if shield_t > 8.0:
			for x in shields:
				if is_instance_valid(x) and not x.is_dead:
					x.take_damage(x.max_hp * 10.0 + 1.0, p)
			shield_t = 0.0
		if Tower.floor_n != f or not Tower.active or not is_instance_valid(p) or p.is_dead:
			var dur := t - f_t
			var ok := Tower.reached >= f
			var ty := Tower.floor_type(f)
			print("[tour-étage] %d %s %s durée=%.0f subis=%.2f niveau=%d" % [f, ty, "franchi" if ok else "ÉCHEC", dur,
				(_taken - f_taken) / maxf(p.max_hp if is_instance_valid(p) else 1.0, 1.0), Tower.level_for(f)])
			if ok:
				if not by_type.has(ty):
					by_type[ty] = []
				by_type[ty].append(dur)
			f = Tower.floor_n
			f_t = t
			f_taken = _taken
		if not Tower.active:
			res = "fin"
			break
		if not is_instance_valid(p) or p.is_dead:
			res = "mort à l'étage %d" % Tower.floor_n
			break
		if Tower.reached >= last:
			res = "objectif"
			break
	var td: TowerDirector = world.director.tower if is_instance_valid(world) else null
	if td and is_instance_valid(td._boss) and not td._boss.is_dead:
		print("[tour] boss %s encore à %.0f %% de ses PV" % [td._boss.display_name, 100.0 * td._boss.hp / maxf(td._boss.max_hp, 1.0)])
	if td and is_instance_valid(td._hero) and not td._hero.is_dead:
		print("[tour] %s encore à %.0f %% de ses PV (%d)" % [td._hero.display_name, 100.0 * td._hero.hp / maxf(td._hero.max_hp, 1.0), int(td._hero.max_hp)])
	var parts: PackedStringArray = []
	for ty in by_type:
		var arr: Array = by_type[ty]
		arr.sort()
		parts.append("%s %d× méd. %.0f s (%.0f-%.0f)" % [ty, arr.size(), float(arr[arr.size() / 2]), float(arr[0]), float(arr[-1])])
	print("[tour] de=%d diff=%d classe=%s hub=%s résultat=%s durée=%.0f atteint=%d subis_min=%.2f · %s" % [from, diff, cid, hub, res, t,
		Tower.reached, _taken / maxf(p.max_hp if is_instance_valid(p) else 1.0, 1.0) / maxf(t / 60.0, 0.01), " · ".join(parts)])
	get_tree().quit()
