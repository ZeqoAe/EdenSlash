extends Node
## Passe M8 : équilibre de la Tour entre classes. Joue des étages de la Tour au pilote et écrit une ligne « [m8-étage] » par
## étage (type, issue, durée, PV perdus, temps pour tuer le boss, part du combat où le boss ne perd aucun PV), puis « [m8] ».
##   godot --headless --fixed-fps 60 --path game res://tools/m8_tower.tscn -- --class=warrior --from=10 --floors=1
##         [--hub=auto|new|E.C.N.G] [--diff=1] [--pilot=auto|bot] [--god] [--human=0.5] [--dodge] [--pure] [--max=900] [--seed=1]
## --hub=auto : équipement attendu de l'étage de départ (hub_for : époque I jusqu'au 50, II jusqu'au 90, III jusqu'au 130, IV
## ensuite). --pilot=auto : pilote de mesure (p.autoplay : au contact pour toutes les classes, sorts au hasard) ; bot : aide au
## combat « Bot » du jeu (un tireur garde sa distance, sorts dès qu'ils sont prêts ; étages de duel au pilote de mesure).
## --dodge : le pilote sort des zones rouges annoncées (PilotDodge). --god : héros invincible (temps pour tuer seulement).
## --pure : boss sans mécaniques (DPS seul). Totems et cristaux de soin cassés après 8 s (comme tools/boss_ttk).
## Profil jetable (EDEN_PROFILE).

const SHIELD_TIME := 8.0

var from := 1
var floors := 1
var diff := 1
var cid := "warrior"
var hub := "auto"
var human := 0.5
var max_t := 900.0
var pilot := "auto"
var _taken := 0.0
var _hp_last := 0.0
var _cause := {}  # cause des dégâts subis (zone annoncée, flaque, autre : coups au contact, tirs) -> PV perdus
var _zone_soon := false
var _in_hazard := false


static func hub_for(f: int) -> String:
	if f <= 50:
		return "1.3.5.1"
	if f <= 90:
		return "2.3.10.3"
	if f <= 130:
		return "3.3.10.4"
	return "4.3.10.4"


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	for a in args:
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
			"pilot": pilot = kv[1]
			"seed": seed(int(kv[1]))
	if "--plan" in args:
		# plan des étages (type, malédiction, mécaniques des élites, boss et ses briques), sans jouer
		for f in range(from, from + floors):
			var s := Tower.spec(f, diff)
			var extra := ""
			match String(s.type):
				"boss":
					extra = "%s %s PV=%.0f" % [s.boss_id, BossLibrary.bricks_of(String(s.boss_id), int(s.tier)).map(func(b): return b.type), Tower.boss_hp_fixed(f, diff)]
				"monsters", "elite", "cursed":
					extra = "%d monstres, élites %s %s" % [int(s.count), s.mechanics, s.get("curse", "")]
				"shadow", "duel":
					extra = "%s %s" % [s["class"], s.kind]
			print("[m8-plan] %d %s niv=%d %s" % [f, s.type, int(s.level), extra])
		get_tree().quit()
		return
	if hub == "auto":
		hub = hub_for(from)
	Settings.reset_all(false)
	Profile.selected_class = cid
	Profile.save_profile()
	if hub != "new":
		Profile.install_gear(StarterGear.scenario(hub, cid))
	Tower.start(cid, diff, from)
	Run.test_taken = 1.0 - clampf(human, 0.0, 0.95)
	PilotDodge.enabled = "--dodge" in args
	var world: Node = load("res://scenes/world.tscn").instantiate()
	get_tree().root.add_child.call_deferred(world)
	await get_tree().create_timer(3.0).timeout
	var p: Player = world.player
	world.cards._queue.clear()
	world.cards._show_next()
	for k in Settings.PRESETS.bot.game:
		Settings.data["game"][k] = Settings.PRESETS.bot.game[k]
	p.dev_invincible = "--god" in args
	var pure := "--pure" in args
	_hp_last = p.hp
	p.health_changed.connect(func(now, _m):
		if now < _hp_last:
			_taken += _hp_last - now
			var c := "zone" if _zone_soon else ("flaque" if _in_hazard else "autre")
			_cause[c] = float(_cause.get(c, 0.0)) + (_hp_last - now) / maxf(p.max_hp, 1.0)
		_hp_last = now)
	var t := 0.0
	var f := Tower.floor_n
	var f_t := 0.0
	var f_taken := 0.0
	var res := "temps"
	var last := from + floors - 1
	var shield_t := 0.0
	var boss_t := -1.0  # apparition du boss de l'étage
	var boss_ttk := -1.0
	var boss_hp0 := 0.0
	var idle_t := 0.0  # secondes (par fenêtres de 1 s) où le boss n'a perdu aucun PV
	var win_t := 0.0
	var win_hp := -1.0
	var stripped := false
	var dist_sum := 0.0
	var dist_n := 0
	var deaths := 0
	while t < max_t:
		await get_tree().physics_frame
		var dt := get_physics_process_delta_time()
		t += dt
		if not is_instance_valid(p):
			break
		p.autoplay = pilot == "auto" or Tower.is_duel_floor(Tower.floor_n)
		_zone_soon = false
		for n in get_tree().get_nodes_in_group("telegraphs"):
			var tg := n as Telegraph
			if tg and tg.source != p and tg.delay - tg._t < 0.1 and tg.contains(p.global_position, p.radius):
				_zone_soon = true
		_in_hazard = false
		for n in get_tree().current_scene.get_children():
			if n is Hazard and Vector2(n.global_position.x - p.global_position.x, n.global_position.z - p.global_position.z).length() < n.radius:
				_in_hazard = true
		var td: TowerDirector = world.director.tower if is_instance_valid(world) else null
		var boss = td._boss if td else null  # (non typé : il a pu être libéré)
		if is_instance_valid(boss) and not boss.is_dead:
			if boss_t < 0.0:
				boss_t = t
				boss_hp0 = boss.max_hp
				win_t = 0.0
				win_hp = boss.hp
				stripped = false
			if pure and not stripped and boss.brain:
				boss.brain.mechanics = []
				boss.brain.bricks = []
				boss.brain._reflect_timer = 1.0e9
				stripped = true
			win_t += dt
			if win_t >= 1.0:
				if boss.hp >= win_hp - 0.5:
					idle_t += win_t
				win_hp = boss.hp
				win_t = 0.0
			dist_sum += p.global_position.distance_to(boss.global_position)
			dist_n += 1
		elif boss_t >= 0.0 and boss_ttk < 0.0 and (boss == null or not is_instance_valid(boss) or boss.is_dead):
			boss_ttk = t - boss_t
		# totems et cristaux de soin : cassés après SHIELD_TIME (un joueur les casse en quelques secondes)
		var shields: Array = get_tree().get_nodes_in_group("monsters").filter(func(m): return not m.is_dead and m.display_name in ["Cristal de soin", "Totem"])
		if is_instance_valid(boss) and boss.brain:
			shields.append_array(boss.brain._totems.filter(func(x): return is_instance_valid(x) and not x.is_dead))
		shield_t = shield_t + dt if not shields.is_empty() else 0.0
		if shield_t > SHIELD_TIME:
			for x in shields:
				if is_instance_valid(x) and not x.is_dead:
					x.take_damage(x.max_hp * 10.0 + 1.0, p)
			shield_t = 0.0
		if Tower.floor_n != f or not Tower.active or p.is_dead or Tower.reached >= last:
			var dur := t - f_t
			var ok := Tower.reached >= f
			var ty := Tower.floor_type(f)
			var extra := ""
			if boss_t >= 0.0:
				var fight := (boss_ttk if boss_ttk >= 0.0 else t - boss_t)
				extra = " boss=%s ttk=%.1f pv_boss=%.0f immobile=%.0f%% distance=%.1f solo=%.2f" % [Tower.boss_id(f), fight, boss_hp0,
					100.0 * idle_t / maxf(fight, 0.1), dist_sum / maxf(float(dist_n), 1.0), TowerBalance.solo_mult(cid)]
			print("[m8-étage] classe=%s étage=%d type=%s issue=%s durée=%.0f subis=%.2f niveau=%d%s" % [cid, f, ty,
				"franchi" if ok else "ÉCHEC", dur, (_taken - f_taken) / maxf(p.max_hp, 1.0), Tower.level_for(f), extra])
			f = Tower.floor_n
			f_t = t
			f_taken = _taken
			boss_t = -1.0
			boss_ttk = -1.0
			idle_t = 0.0
			dist_sum = 0.0
			dist_n = 0
		if not Tower.active:
			res = "fin"
			break
		if p.is_dead:
			deaths += 1
			res = "mort à l'étage %d" % Tower.floor_n
			break
		if Tower.reached >= last:
			res = "objectif"
			break
	print("[m8] classe=%s de=%d à=%d diff=%d hub=%s pilote=%s esquive=%s résultat=%s durée=%.0f atteint=%d subis_min=%.2f zone=%.2f flaque=%.2f autre=%.2f" % [cid, from,
		last, diff, hub, pilot, "oui" if PilotDodge.enabled else "non", res.replace(" ", "_"), t, Tower.reached,
		_taken / maxf(p.max_hp if is_instance_valid(p) else 1.0, 1.0) / maxf(t / 60.0, 0.01), float(_cause.get("zone", 0.0)),
		float(_cause.get("flaque", 0.0)), float(_cause.get("autre", 0.0))])
	get_tree().quit()
