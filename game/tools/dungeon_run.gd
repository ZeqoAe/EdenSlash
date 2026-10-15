extends Node
## Passe M2 : un donjon à la carte joué en entier par le pilote automatique (aide « Bot » : déplacement, attaques et
## sorts automatiques ; cartes et passage des salles seuls), pour mesurer sa durée, la mort ou non, et les dégâts subis.
##   godot --headless --fixed-fps 60 --path game res://tools/dungeon_run.tscn -- --boss=latif --diff=0 --class=warrior
##         --hub=E.C.N.G [--human=0.5] [--max=1500] [--seed=1]
## --human : part des coups évitée (Run.test_taken) ; sans : 0,5. Ligne lue : « [donjon] … ». Profil jetable (EDEN_PROFILE).

var boss := "latif"
var diff := 0
var cid := "warrior"
var hub := "new"
var human := 0.5
var max_t := 1500.0
var _taken := 0.0
var _hp_last := 0.0
var _room_t: Array = []


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=")
		if kv.size() < 2:
			continue
		match kv[0]:
			"boss": boss = kv[1]
			"diff": diff = int(kv[1])
			"class": cid = kv[1]
			"hub": hub = kv[1]
			"human": human = float(kv[1])
			"max": max_t = float(kv[1])
			"seed": seed(int(kv[1]))
	Settings.reset_all(false)
	Profile.selected_class = cid
	Profile.save_profile()
	if hub != "new":
		Profile.install_gear(StarterGear.scenario(hub, cid))
	Tower.start_dungeon(cid, Dungeons.boss_zone(boss), diff, [], boss)
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
	_hp_last = p.hp
	p.health_changed.connect(func(now, _m):
		if now < _hp_last:
			_taken += _hp_last - now
		_hp_last = now)
	var t := 0.0
	var room := Tower.floor_n
	var boss_t0 := -1.0
	var res := "temps"
	while t < max_t:
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
		if Tower.floor_n != room:
			_room_t.append(snappedf(t, 1.0))
			room = Tower.floor_n
			if Tower.is_boss_floor(room):
				boss_t0 = t
		if not Tower.active:
			res = "victoire" if Tower.reached >= 4 else "défaite"
			break
		if not is_instance_valid(p) or p.is_dead:
			res = "mort"
			break
	if res == "temps":
		# salle bloquée : qui reste, où (diagnostic)
		for m in get_tree().get_nodes_in_group("monsters"):
			print("[donjon] reste %s pv=%d pos=%s héros=%s" % [m.display_name, int(m.hp), str(m.global_position.round()), str(p.global_position.round())])
		print("[donjon] phase=%s gauche=%d" % [world.director.tower.phase, world.director.tower.left])
	print("[donjon] boss=%s diff=%d classe=%s hub=%s résultat=%s durée=%.0f salles=%s boss_ttk=%.0f subis_min=%.2f" % [boss, diff, cid, hub, res, t,
		",".join(_room_t.map(func(x): return str(int(x)))), (t - boss_t0) if boss_t0 >= 0.0 else -1.0,
		_taken / maxf(p.max_hp if is_instance_valid(p) else 1.0, 1.0) / maxf(t / 60.0, 0.01)])
	get_tree().quit()
