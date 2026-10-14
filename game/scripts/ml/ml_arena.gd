class_name MlArena
extends Node3D
## Arène d'apprentissage : un héros piloté par une IA (programme Python du dossier ia/) contre
## un ou plusieurs adversaires, sur un sol plat entouré d'un mur. Le jeu et Python se parlent
## par une connexion locale (une ligne JSON par message) et avancent au même pas : Python
## envoie une action, le jeu simule REPEAT images puis renvoie ce que l'IA voit, la récompense
## et la fin de l'épisode.
## Lancement (voir ia/eden_env.py) :
##   Godot --headless --fixed-fps 60 --path game res://scenes/ml_arena.tscn -- --port=50001
##   --watch : fenêtre en temps réel avec caméra et bandeau (regarder l'IA jouer).
##   --brain=res://data/cerveaux/<nom>.json --scenario=hardcore : le jeu fait jouer un cerveau
##   exporté tout seul, sans Python (MlBrain) ; --episodes=N : N combats puis bilan et sortie ;
##   --temperature=0.5 : choix tirés au sort (moins fort, plus humain) ; --hero=mage : classe jouée.
##   --scenario=duel --foe=cleric [--foe-brain=...] : IA contre IA (même cerveau par défaut).
## Scénarios (message « reset ») :
##   dummy   : mannequin qui ne bouge pas (apprendre combos, sorts et enchaînements) ;
##   flee    : adversaire de classe fuyard (jouer agressif, esquives d'annulation pour suivre) ;
##   monster : monstres d'Eden, héros à 1 PV (apprendre à esquiver les zones rouges) ;
##   rival   : adversaire de classe (ClassRival), difficulté 0 à 3 ;
##   duel    : héros ennemi aux mêmes mécaniques que le joueur (Player.foe), piloté par un
##             cerveau dans le jeu (foe_brain, sinon le cerveau de --brain) : IA contre IA.

const RADIUS := 15.0  # rayon de l'arène (m)
const REPEAT := 3  # images physiques par décision : 20 décisions par seconde
const LEVEL := 10
const SCENARIOS := ["dummy", "flee", "monster", "rival"]  # duel : vu comme « rival »
const HERO_STATES := ["idle", "attack", "skill", "dodge", "jump", "stun"]
const ENEMY_STATES := ["idle", "chase", "attack", "hurt", "cast"]
const HERO_STATUSES := ["fury", "barrier", "titan", "survival", "frenzy", "scar", "chill", "root"]
const ENEMY_STATUSES := ["stun", "bleed", "scar", "purgatory", "chill", "freeze", "shock"]
const BUTTONS := 8  # rien, attaque, sort 1 à 4, esquive, saut
## Classes connues du cerveau, dans un ordre FIXE (le cerveau voit la classe jouée et celle de
## l'adversaire à leur rang dans cette liste) : ajouter une classe à la fin seulement.
const ML_CLASSES := ["samurai", "warrior", "thief", "hunter", "cleric", "magician", "bard", "knight", "engineer",
	"martial_artist", "illusionist", "blade_dancer", "shaman", "templar", "ranger", "warlock", "sage", "dragon_knight",
	"luminary", "inquisitor", "berserker", "shielder", "arch_elementalist", "stormcaster", "trainer", "devil_hunter",
	"adjudicator", "equilibrian", "assassin", "kage", "battlefield_poet", "life_worshipper", "executioner",
	"glacier_knight", "mecha_ares", "annihilator", "asura", "rakshasa", "demon_tamer", "chronologist", "blade_acrobat",
	"elegant_dancer", "druid", "archimage", "dawnbreaker", "paladin", "absolute_arrow", "holy_arrow", "dark_envoy",
	"conjurer", "blade_master", "master_fencer", "psalmist", "orator", "dragon_soul", "dragon_rider", "black_blade",
	"light_blade", "reaver", "rifleteer"]
## Fiche d'un sort vue par le cerveau : type, chiffres, effets (voir _skill_card).
const SKILL_KINDS := ["buff", "ground", "bolt", "spin", "cone", "heal", "dash", "flurry", "fan", "blink", "line"]
const DOTS := ["bleed", "burn", "poison"]
const WEAKEN := ["purgatory", "shock", "scar", "chill", "cranes"]
const OFF_BUFFS := ["fury", "might", "keen", "frenzy", "marduk", "swift", "grace", "hunter_stance", "haste"]
const DEF_BUFFS := ["barrier", "titan", "resolve", "evasion", "regen", "invisible", "vitality", "thorns", "angel",
	"solar", "shrine", "survival"]
const SKILL_CARD := 25  # nombres par fiche de sort

var player: Player
var enemies: Array[Combatant] = []
var _peer := StreamPeerTCP.new()
var _buf := ""
var _watch := false
var _static: Array[Node] = []
var _bot := BotInput.new()
var _wait := 0
var _ep := {}  # paramètres de l'épisode (message reset)
var _t := 0.0
var _max_time := 60.0
var _low_hp := 0.0  # PV max du héros pendant l'épisode (0 : normal)
var _prev_enemy_hp := 0.0
var _enemy_max_total := 0.0
var _class_obs: Array = []  # classe jouée et fiches de ses 12 sorts (fixes pendant un combat)
var foe_hero: Player  # héros ennemi du duel
var _foe_bot := BotInput.new()
var _foe_brain: MlBrain
var _foe_class_obs: Array = []
var _foe_last := 0
var _foe_temperature := 0.0
var _foe_arg := "random"
var _foe_brain_arg := ""
var _brains := {}  # chemin -> MlBrain (cerveaux des héros ennemis)
var _prev_hero_hp := 0.0
var _prev_counts := {}
var _total := {}
var _last_button := 0
var _monster_pool: Array = []
var _cam: Camera3D
var _label: Label
var _ep_reward := 0.0
var _results: Array = []
var center := Vector3.ZERO  # centre de l'arène (0 ici ; le duel du jeu a son arène ailleurs : MlDuelPilot)
var _capture := ""
var _brain: MlBrain  # cerveau joué par le jeu lui-même (sans Python)
var _brain_scen := {}
var _temperature := 0.0
var _episodes := 0
var _hero_arg := "warrior"
var _done_count := 0
var _wins := 0
var _level := LEVEL  # --level= : niveau des deux héros (équilibrage JcJ)
var _hero_build := ""  # --hero-build= : profil type joué par le héros (nom, RivalBuilds)
var _foe_build := ""  # --foe-build= : profil type du héros ennemi (duel)
var _fight_times: Array = []  # durée des combats finis (victoire ou défaite)
## Scénarios du mode cerveau (mêmes réglages que ia/curriculum.py).
const PRESETS := {
	"mannequin": {"scenario": "dummy", "skills": 12, "max_time": 30},
	"fuyard": {"scenario": "flee", "skills": 12, "difficulty": 2, "max_time": 40},
	"survie": {"scenario": "monster", "skills": 12, "hero_hp": 1, "max_time": 40, "enemy_hp": 20.0, "cc_immune": true},
	"facile": {"scenario": "rival", "skills": 12, "difficulty": 0, "max_time": 90, "enemy_class": "random"},
	"normal": {"scenario": "rival", "skills": 12, "difficulty": 1, "max_time": 90, "enemy_class": "random"},
	"difficile": {"scenario": "rival", "skills": 12, "difficulty": 2, "max_time": 90, "enemy_class": "random"},
	"hardcore": {"scenario": "rival", "skills": 12, "difficulty": 3, "max_time": 180, "enemy_class": "random"},
	"toutes": {"scenario": "rival", "skills": 12, "difficulty": 3, "max_time": 180, "enemy_class": "random"},
	"duo": {"scenario": "rival", "skills": 12, "difficulty": 3, "max_time": 180, "enemy_class": "random", "count": 2, "enemy_hp": 0.6},
	"duel": {"scenario": "duel", "skills": 12, "difficulty": 3, "max_time": 180},
}


func _ready() -> void:
	process_physics_priority = -100  # l'action est posée avant que le héros ne bouge
	var port := 50001
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--port="):
			port = int(arg.trim_prefix("--port="))
		elif arg == "--watch":
			_watch = true
		elif arg.begins_with("--capture="):
			_capture = arg.trim_prefix("--capture=")  # capture d'écran à 4 s du 1er combat
		elif arg.begins_with("--brain="):
			_brain = MlBrain.load_file(arg.trim_prefix("--brain="))
		elif arg.begins_with("--scenario="):
			_brain_scen = PRESETS.get(arg.trim_prefix("--scenario="), PRESETS.hardcore).duplicate()
		elif arg.begins_with("--temperature="):
			_temperature = float(arg.trim_prefix("--temperature="))
		elif arg.begins_with("--episodes="):
			_episodes = int(arg.trim_prefix("--episodes="))
		elif arg.begins_with("--hero="):
			_hero_arg = _class_from_name(arg.trim_prefix("--hero="))  # classe jouée (random : au hasard)
		elif arg.begins_with("--foe="):
			_foe_arg = _class_from_name(arg.trim_prefix("--foe="))  # classe du héros ennemi (duel)
		elif arg.begins_with("--foe-brain="):
			_foe_brain_arg = arg.trim_prefix("--foe-brain=")
		elif arg.begins_with("--level="):
			_level = clampi(int(arg.trim_prefix("--level=")), 1, 101)
		elif arg.begins_with("--hero-build="):
			_hero_build = arg.trim_prefix("--hero-build=")
		elif arg.begins_with("--foe-build="):
			_foe_build = arg.trim_prefix("--foe-build=")
		elif arg.begins_with("--foe-temperature="):
			_foe_temperature = float(arg.trim_prefix("--foe-temperature="))
	_setup_game_state()
	_build_arena()
	for m in GameData.monsters.values():
		var model := String(m.get("model", ""))
		if int(m.get("rank", 2)) in [2, 3] and ResourceLoader.exists("res://assets/monsters/%s/%s.glb" % [model, model]):
			_monster_pool.append(int(m.id))
	_static.assign(get_children())
	if _brain:
		if _brain_scen.is_empty():
			_brain_scen = PRESETS.hardcore.duplicate()
		_brain_scen["hero_class"] = _hero_arg
		_brain_scen["foe_class"] = _foe_arg
		if _foe_brain_arg != "":
			_brain_scen["foe_brain"] = _foe_brain_arg
		_reset(_brain_scen)
		if _obs().size() != _brain.obs_size:
			push_error("cerveau d'une ancienne version de l'arène (%d entrées, l'arène en donne %d)" % [_brain.obs_size, _obs().size()])
			get_tree().quit(1)
		return
	if _peer.connect_to_host("127.0.0.1", port) != OK:
		push_error("arène ML : connexion impossible au port %d" % port)
		get_tree().quit(1)
		return
	var waited := 0
	while _peer.get_status() == StreamPeerTCP.STATUS_CONNECTING and waited < 30000:
		_peer.poll()
		OS.delay_msec(5)
		waited += 5
	if _peer.get_status() != StreamPeerTCP.STATUS_CONNECTED:
		push_error("arène ML : pas de programme Python sur le port %d" % port)
		get_tree().quit(1)
		return
	_peer.set_no_delay(true)


## Réglages neutres et rien d'écrit sur le disque : profil vierge sans équipement, combat au
## clavier, pas d'arrêt sur impact (il ralentit le temps), pas de chiffres sans fenêtre.
func _setup_game_state() -> void:
	Training.active = true  # aucune sauvegarde pendant l'apprentissage
	Training.hero_god = false
	Training.enemies_immortal = false
	Training.enemies_passive = false
	Training.no_cd = false
	Vfx.silent = not _watch
	Settings.data["game"] = {"move_mode": "keyboard", "aim_mode": "smart", "attack_mode": "manual",
		"auto_skills": [false, false, false, false], "auto_target": "any"}
	var ui: Dictionary = Settings.data.get("interface", {})
	ui["hit_stop"] = false
	ui["attack_zone"] = false
	ui["move_marker"] = false
	ui["damage_numbers"] = "all" if _watch else "off"
	Settings.data["interface"] = ui
	Profile.reset_all()
	Profile.selected_class = "warrior"
	Run.start("warrior")
	Profile.equipped = {}


func _build_arena() -> void:
	var ground := StaticBody3D.new()
	ground.collision_layer = GameData.PHYS_WORLD
	var gs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(RADIUS * 3.0, 1.0, RADIUS * 3.0)
	gs.shape = box
	gs.position.y = -0.5
	ground.add_child(gs)
	add_child(ground)
	# mur circulaire : 36 pans
	var n := 36
	for i in n:
		var a := TAU * i / n
		var wall := StaticBody3D.new()
		wall.collision_layer = GameData.PHYS_WORLD
		var ws := CollisionShape3D.new()
		var wb := BoxShape3D.new()
		wb.size = Vector3(TAU * RADIUS / n + 0.4, 4.0, 1.0)
		ws.shape = wb
		wall.add_child(ws)
		add_child(wall)
		wall.position = Vector3(sin(a), 0, cos(a)) * (RADIUS + 0.5) + Vector3.UP * 2.0
		wall.rotation.y = a
		if _watch:
			# bordure basse (le mur invisible fait 4 m, il ne cache pas le combat)
			var wm := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3(wb.size.x, 0.4, 0.6)
			wm.mesh = bm
			wm.position.y = -1.8
			var cm := StandardMaterial3D.new()
			cm.albedo_color = Color(0.22, 0.2, 0.18)
			wm.material_override = cm
			wall.add_child(wm)
	if not _watch:
		return
	var gm := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = RADIUS + 1.0
	disc.bottom_radius = RADIUS + 1.0
	disc.height = 0.1
	gm.mesh = disc
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.32, 0.36, 0.3)
	gm.material_override = mat
	gm.position.y = -0.05
	add_child(gm)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, 35, 0)
	sun.shadow_enabled = true
	add_child(sun)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.12, 0.13, 0.16)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.6, 0.6, 0.65)
	add_child(env)
	_cam = Camera3D.new()
	_cam.fov = 50.0
	add_child(_cam)
	var layer := CanvasLayer.new()
	_label = Label.new()
	_label.position = Vector2(16, 12)
	_label.add_theme_font_size_override("font_size", 20)
	_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_label.add_theme_constant_override("outline_size", 6)
	layer.add_child(_label)
	add_child(layer)


func _process(_delta: float) -> void:
	if not _watch or player == null or not is_instance_valid(player):
		return
	var e := _nearest_enemy()
	var mid := player.global_position
	if e:
		mid = mid.lerp(e.global_position, 0.35)
	_cam.global_position = _cam.global_position.lerp(mid + Vector3(0, 15, 11), 0.1)
	_cam.look_at(mid, Vector3.UP)
	var txt := "IA Eden Slash · scénario %s%s · %.1f s / %d s\n" % [_ep.get("scenario", ""),
		(" (difficulté %s)" % ClassRival.NAMES[int(_ep.get("difficulty", 0))]) if _ep.get("scenario", "") in ["rival", "flee"] else "", _t, int(_max_time)]
	txt += "%s (IA) %d / %d PV" % [player.display_name, player.hp, player.max_hp]
	if e:
		txt += "   ·   %s%s %d / %d PV" % [e.display_name, " (IA)" if e is Player else "", e.hp, e.max_hp]
	txt += "\nRécompense de l'épisode : %.2f   ·   parfaits %d, enchaînements %d, esquives %d" % [_ep_reward,
		player.ml_counts.perfect, player.ml_counts.chain, player.ml_counts.dodged]
	if not _results.is_empty():
		txt += "\nDerniers combats : " + " ".join(_results.slice(-12))
	_label.text = txt
	if _capture != "" and _t > 4.0:
		get_viewport().get_texture().get_image().save_png(_capture)
		_capture = ""


# --- boucle d'échange avec Python ---------------------------------------------------------
func _physics_process(delta: float) -> void:
	if _brain == null and _peer.get_status() != StreamPeerTCP.STATUS_CONNECTED:
		return
	if _wait > 0:
		_wait -= 1
		_t += delta
		PvpCaps.elapsed = _t
		_bot.pulse.clear()  # une touche n'est appuyée qu'à la première image de la décision
		_foe_bot.pulse.clear()
		if _low_hp > 0.0 and player and not player.is_dead:
			player.hp = minf(player.hp, _low_hp)
		if _wait > 0:
			return
		if _brain:
			_brain_step()
			return
		_send_step()
	elif _brain:
		_apply(_brain.act(_obs(), _temperature))
		_foe_act()
		_wait = REPEAT
		return
	_serve()


## Mode cerveau : fin de décision, combat suivant si celui-ci est fini, puis décision suivante.
func _brain_step() -> void:
	var res := _step_result()
	if res.done:
		_done_count += 1
		if res.info.result == "win":
			_wins += 1
		if res.info.result != "timeout":
			_fight_times.append(float(res.info.t))
		print("combat %d (%s) : %s en %.1f s, dégâts %d %%, subis %d %% (victoires %d / %d)" % [_done_count, res.info.hero, res.info.result,
			res.info.t, roundi(res.info.dealt * 100), roundi(res.info.taken * 100), _wins, _done_count])
		if _episodes > 0 and _done_count >= _episodes:
			var avg := 0.0
			for t in _fight_times:
				avg += float(t) / maxf(_fight_times.size(), 1)
			print("BILAN %s : %d victoires sur %d combats, %d sans vainqueur, durée moyenne %.1f s" % [_brain_scen.get("scenario", ""), _wins, _done_count,
				_done_count - _fight_times.size(), avg])
			get_tree().quit()
			return
		_reset(_brain_scen)
	_apply(_brain.act(_obs(), _temperature))
	_foe_act()
	_wait = REPEAT


## Décision du héros ennemi (duel) par son cerveau, de son point de vue.
func _foe_act() -> void:
	if foe_hero == null or not is_instance_valid(foe_hero) or foe_hero.is_dead or _foe_brain == null:
		return
	var obs := _obs_for(foe_hero, [player], _foe_class_obs, _foe_last, 0.0)
	_foe_last = _apply_for(_foe_bot, foe_hero, [player], _foe_brain.act(obs, _foe_temperature))


## Lit les ordres de Python jusqu'à une action (le jeu reste figé en attendant).
func _serve() -> void:
	while true:
		var msg := _read_msg()
		match String(msg.get("cmd", "close")):
			"reset":
				_reset(msg)
				_send({"obs": _obs(), "r": 0.0, "done": false, "info": {}})
			"step":
				_apply(msg.get("a", [0, 0, 0]))
				_foe_act()
				_wait = REPEAT
				return
			_:
				_peer.disconnect_from_host()
				get_tree().quit()
				return


func _read_msg() -> Dictionary:
	while true:
		var i := _buf.find("\n")
		if i >= 0:
			var line := _buf.substr(0, i)
			_buf = _buf.substr(i + 1)
			var d: Variant = JSON.parse_string(line)
			return d if d is Dictionary else {}
		_peer.poll()
		if _peer.get_status() != StreamPeerTCP.STATUS_CONNECTED:
			return {"cmd": "close"}
		var n := _peer.get_available_bytes()
		if n > 0:
			var got: Array = _peer.get_data(n)
			_buf += (got[1] as PackedByteArray).get_string_from_utf8()
		else:
			OS.delay_usec(30)
	return {}


func _send(d: Dictionary) -> void:
	_peer.put_data((JSON.stringify(d) + "\n").to_utf8_buffer())


# --- épisodes -----------------------------------------------------------------------------
func _reset(msg: Dictionary) -> void:
	for c in get_children():
		if not _static.has(c):
			remove_child(c)
			c.queue_free()
	Engine.time_scale = 1.0
	if msg.has("seed"):
		seed(int(msg.seed))
	_ep = msg.duplicate()  # la classe tirée est notée ici, pas dans les réglages (tirage à chaque combat)
	var scen := String(msg.get("scenario", "dummy"))
	_max_time = float(msg.get("max_time", 60.0))
	var hero_class := String(msg.get("hero_class", "warrior"))
	if hero_class == "random" or not GameData.classes.has(hero_class):
		hero_class = String(ML_CLASSES.pick_random())
	var hb := _build(_hero_build)
	if not hb.is_empty():
		hero_class = String(hb["class"])
	_ep["hero_class"] = hero_class
	Run.class_id = hero_class
	Run.hero_level = _level
	Profile.selected_class = hero_class
	var hk := _pick_kit(hero_class, int(msg.get("skills", 4)), String(msg.get("loadout", "default")) == "random")
	if not hb.is_empty():
		hk = Duel.kit_from_grid(hero_class, hb.get("spells", []))
	Run.skills = hk.skills
	Run.chains = hk.chains
	# règles du duel du jeu (PvpCaps) pour les essais d'équilibrage ; l'apprentissage reste au
	# niveau 10 sans équipement, avec l'échelle des héros d'origine
	Duel.active = scen == "duel" and (_level != LEVEL or _hero_build != "" or _foe_build != "")
	_bot.clear()
	player = Player.new()
	player.level = _level
	if not hb.is_empty():
		player.use_build(hb, _level)
	player.bot = _bot
	add_child(player)
	var hero_at := _random_point(5.0)
	player.global_position = hero_at + Vector3.UP * 0.1
	_low_hp = float(msg.get("hero_hp", 0.0))
	if _low_hp > 0.0:
		player.hp = _low_hp
	enemies.clear()
	foe_hero = null
	if scen == "duel":
		_spawn_foe(msg, hero_at)
	var diff := int(msg.get("difficulty", 1))
	var enemy_class := String(msg.get("enemy_class", "warrior"))
	var count := 0 if scen == "duel" else (int(msg.get("count", 1)) if scen in ["monster", "rival"] else 1)
	for i in count:
		var e: Monster
		if scen == "monster":
			var m := Monster.new()
			var pool: Array = msg.get("monsters", _monster_pool)
			m.configure(GameData.monster(int(pool.pick_random())), false, LEVEL)
			e = m
		else:
			var r := ClassRival.new()
			# "random" : une classe au hasard parmi les 60 (tirée pour chaque adversaire)
			var cid := String(GameData.classes.keys().pick_random()) if enemy_class == "random" else enemy_class
			r.setup(cid, LEVEL, 0 if scen == "dummy" else diff)
			r.passive = scen == "dummy"
			r.flee = scen == "flee"
			r.flee_center = Vector3.ZERO
			r.flee_radius = RADIUS
			e = r
		e.max_hp *= float(msg.get("enemy_hp", 1.0))
		e.hp = e.max_hp
		e.atk *= float(msg.get("enemy_atk", 1.0))
		e.cc_immune = bool(msg.get("cc_immune", false))
		add_child(e)
		var ang := randf() * TAU
		var d := randf_range(float(msg.get("min_dist", 4.0)), float(msg.get("max_dist", 9.0)))
		var at := hero_at + Vector3(sin(ang), 0, cos(ang)) * d
		at = at.limit_length(RADIUS - 2.0)
		e.global_position = at + Vector3.UP * 0.4
		e.face_direction(hero_at - at, 1.0, 100.0)
		enemies.append(e)
	player.face_direction(enemies[0].global_position - hero_at, 1.0, 100.0)
	_t = 0.0
	_wait = 0
	_last_button = 0
	_ep_reward = 0.0
	_prev_enemy_hp = _enemy_hp()
	_class_obs = _build_class_obs(player)
	_enemy_max_total = 0.0
	for e in enemies:
		_enemy_max_total += e.max_hp
	_prev_hero_hp = player.hp
	_prev_counts = player.ml_counts.duplicate()
	_total = {"dealt": 0.0, "taken": 0.0}
	if _brain and _done_count == 0 and foe_hero:
		await get_tree().physics_frame
		print("  ", _sheet(player), "
  ", _sheet(foe_hero))


## Jeu de sorts de la classe [param cid] : 4 cases, puis 2 enchaînements par case (12 sorts).
## [param random_pick] : sorts tirés au hasard parmi ceux de la classe (n'importe quel jeu de
## sorts, comme une run ou la Tour), sinon les premiers de la liste. {skills, chains}.
func _pick_kit(cid: String, n: int, random_pick := false) -> Dictionary:
	var all: Array = GameData.class_data(cid).get("skills", []).duplicate()
	if random_pick:
		all.shuffle()
	var skills: Array = []
	var chains := {}
	for i in mini(4, all.size()):
		skills.append({"id": int(all[i].id), "rank": 1})
	if n > 4:
		for slot in 4:
			var ch: Array = []
			for k in 2:
				var idx := 4 + slot * 2 + k
				if idx < all.size() and idx < n:
					ch.append({"id": int(all[idx].id), "rank": 1})
			if not ch.is_empty():
				chains[slot] = ch
	return {"skills": skills, "chains": chains}


## Classe jouée (rang dans ML_CLASSES), ses statistiques de base et la fiche de ses 12 sorts
## (case 1 : sort principal puis ses 2 enchaînements, etc.).
func _build_class_obs(me: Player) -> Array:
	var o: Array = []
	_one_hot(o, ML_CLASSES.find(me.class_id), ML_CLASSES.size())
	var base: Dictionary = GameData.class_data(me.class_id).get("base", {})
	o.append(float(base.get("hp", 1.0)) / 2.0)
	o.append(float(base.get("atk", 1.0)) / 2.0)
	o.append(float(base.get("matk", 0.5)) / 2.0)
	o.append(1.0 if String(me._weapon_type().get("dmg_type", "phys")) == "mag" else 0.0)
	o.append(1.0 if me.attack_reach() > 6.0 else 0.0)
	for slot in 4:
		var ids: Array = [int(me.kit()[slot].id)] if slot < me.kit().size() else []
		for e in me.kit_chain(slot):
			ids.append(int(e.id))
		for k in 3:
			o.append_array(_skill_card(me.kit_skill_def(ids[k]) if k < ids.size() else {}))
	return o


## Fiche d'un sort (SKILL_CARD nombres) : présent, type, dégâts, zone, portée, élan, coups,
## recharge, contrôle, dégâts sur la durée, affaiblissement, buff offensif / défensif, soin.
func _skill_card(sk: Dictionary) -> Array:
	var o: Array = []
	if sk.is_empty():
		return _zeros(SKILL_CARD)
	o.append(1.0)
	_one_hot(o, SKILL_KINDS.find(String(sk.get("kind", ""))), SKILL_KINDS.size())
	o.append(clampf(float(sk.get("mult", 0.0)) / 3.0, 0.0, 2.0))
	o.append(clampf(float(sk.get("radius", 0.0)) / 10.0, 0.0, 2.0))
	o.append(float(sk.get("arc", 0.0)) / 360.0)
	o.append(clampf(float(sk.get("range", 0.0)) / 15.0, 0.0, 2.0))
	o.append(clampf(float(sk.get("dash", 0.0)) / 10.0, 0.0, 2.0))
	o.append(clampf(float(sk.get("hits", 1)) / 5.0, 0.0, 2.0))
	o.append(clampf(float(sk.get("cooldown", 0.0)) / 30.0, 0.0, 2.0))
	var applies: Dictionary = sk.get("applies", {})
	var buff: Dictionary = sk.get("buff", {})
	o.append(1.0 if applies.keys().any(func(k): return k in Combatant.CC_TYPES) else 0.0)
	o.append(1.0 if applies.keys().any(func(k): return k in DOTS) else 0.0)
	o.append(1.0 if applies.keys().any(func(k): return k in WEAKEN) else 0.0)
	o.append(1.0 if buff.keys().any(func(k): return k in OFF_BUFFS) else 0.0)
	o.append(1.0 if buff.keys().any(func(k): return k in DEF_BUFFS) else 0.0)
	o.append(clampf(float(sk.get("heal", 0.0)), 0.0, 1.0))
	return o


## Héros ennemi du duel : classe foe_class (random : au hasard), 12 sorts, piloté par le
## cerveau foe_brain (sinon celui de --brain).
func _spawn_foe(msg: Dictionary, hero_at: Vector3) -> void:
	var fcls := String(msg.get("foe_class", "random"))
	if fcls == "random" or not GameData.classes.has(fcls):
		fcls = String(ML_CLASSES.pick_random())
	var fb := _build(_foe_build)
	if not fb.is_empty():
		fcls = String(fb["class"])
	var fk := _pick_kit(fcls, int(msg.get("skills", 12)), String(msg.get("foe_loadout", msg.get("loadout", "default"))) == "random")
	if not fb.is_empty():
		fk = Duel.kit_from_grid(fcls, fb.get("spells", []))
	foe_hero = Player.new()
	foe_hero.foe = true
	foe_hero.class_id = fcls
	foe_hero.level = _level
	if not fb.is_empty():
		foe_hero.use_build(fb, _level)
	foe_hero.kit_skills = fk.skills
	foe_hero.kit_chains = fk.chains
	_foe_bot.clear()
	foe_hero.bot = _foe_bot
	add_child(foe_hero)
	var ang := randf() * TAU
	var at := (hero_at + Vector3(sin(ang), 0, cos(ang)) * randf_range(5.0, 8.0)).limit_length(RADIUS - 2.0)
	foe_hero.global_position = at + Vector3.UP * 0.1
	foe_hero.face_direction(hero_at - at, 1.0, 100.0)
	enemies.append(foe_hero)
	_foe_class_obs = _build_class_obs(foe_hero)
	_foe_last = 0
	var path := String(msg.get("foe_brain", ""))
	if path == "":
		_foe_brain = _brain
	else:
		if not _brains.has(path):
			_brains[path] = MlBrain.load_file(path)
		_foe_brain = _brains[path]


## Profil type nommé [param name] (RivalBuilds), ou « classe:niveau » (profil « opti » généré,
## tools/gen_profiles.gd) ; vide si aucun.
func _build(name: String) -> Dictionary:
	if name == "":
		return {}
	# les profils du jeu, même si la ligne de commande met RivalBuilds en mode test
	var all = JSON.parse_string(FileAccess.get_file_as_string(RivalBuilds.PATH))
	if not all is Array:
		return {}
	if name.contains(":"):
		for b in all:
			if String(b.get("auto", "")) != "" and String(b.get("class", "")) == _class_from_name(name.get_slice(":", 0)) 					and int(b.get("level", 0)) == int(name.get_slice(":", 1)):
				return b
	for b in all:
		if String(b.get("name", "")) == name:
			return b
	push_error("profil type introuvable : " + name)
	return {}


## Fiche courte d'un héros (essais d'équilibrage JcJ).
static func _sheet(h: Player) -> String:
	return "%s niv. %d : PV %d, att. %d, att. mag. %d, déf. %d, crit %d %%, esq. %d %%" % [h.display_name if h.display_name != "" else h.class_id,
		h.level, h.max_hp, h.atk, h.matk, h.defense, roundi(h.crit * 100), roundi(h.evasion_chance * 100)]


## Identifiant de classe d'après un identifiant ou un nom français (« magicien », « Samouraï »,
## « mage »), sans tenir compte des accents ni des majuscules ; random si inconnu ou vide.
func _class_from_name(name: String) -> String:
	if GameData.classes.has(name):
		return name
	var want := _plain(name)
	if want in ["mage"]:
		return "magician"
	for cid in GameData.classes:
		if _plain(String(GameData.classes[cid].get("name_fr", ""))) == want or _plain(cid) == want:
			return cid
	return "random"


static func _plain(t: String) -> String:
	var out := t.to_lower().strip_edges().replace("-", " ").replace("_", " ")
	for pair in [["é", "e"], ["è", "e"], ["ê", "e"], ["ë", "e"], ["à", "a"], ["â", "a"], ["î", "i"], ["ï", "i"],
			["ô", "o"], ["ù", "u"], ["û", "u"], ["ç", "c"]]:
		out = out.replace(pair[0], pair[1])
	return out


func _random_point(r: float) -> Vector3:
	var a := randf() * TAU
	var d := sqrt(randf()) * r
	return Vector3(sin(a) * d, 0.0, cos(a) * d)


func _apply(a: Array) -> void:
	_last_button = _apply_for(_bot, player, enemies, a)


## Pose l'action [déplacement, touche, visée] sur [param bot] (héros [param me] face à
## [param opps]) ; rend la touche appuyée.
func _apply_for(bot: BotInput, me: Player, opps: Array, a: Array) -> int:
	var move := int(a[0]) if a.size() > 0 else 0
	var button := int(a[1]) if a.size() > 1 else 0
	var aim := int(a[2]) if a.size() > 2 else 0
	var f := _fwd_for(me, opps)
	var s := _side(f)
	bot.hold.clear()
	bot.pulse.clear()
	bot.move = Vector3.ZERO
	if move > 0:
		var ang := (move - 1) * PI / 4.0
		bot.move = (f * cos(ang) + s * sin(ang)).normalized()
	match button:
		1:
			bot.hold["attack"] = true
		2, 3, 4, 5:
			bot.pulse["skill_%d" % (button - 1)] = true
		6:
			bot.pulse["dodge"] = true
		7:
			bot.pulse["jump"] = true
	var e := _nearest(me, opps)
	if e:
		var v := e.velocity
		v.y = 0.0
		bot.aim = e.global_position + v * (0.25 * aim)
	else:
		bot.aim = me.global_position + me.forward() * 3.0
	return button


func _send_step() -> void:
	_send(_step_result())


## Récompense, fin d'épisode et bilan de la décision qui vient de se jouer.
func _step_result() -> Dictionary:
	var r := 0.0
	var e_hp := _enemy_hp()
	var dealt := maxf(0.0, _prev_enemy_hp - e_hp)
	var taken := maxf(0.0, _prev_hero_hp - player.hp)
	_prev_enemy_hp = e_hp
	_prev_hero_hp = player.hp
	_total.dealt += dealt
	_total.taken += taken
	r += 10.0 * dealt / maxf(_enemy_max_hp(), 1.0)
	r -= float(_ep.get("w_taken", 1.0)) * 10.0 * taken / maxf(player.max_hp, 1.0)
	var bonus: Dictionary = _ep.get("bonus", {})
	for k in player.ml_counts:
		var dk: int = int(player.ml_counts[k]) - int(_prev_counts.get(k, 0))
		if dk > 0:
			r += dk * float(bonus.get(k, 0.0))
	_prev_counts = player.ml_counts.duplicate()
	r -= float(_ep.get("time_penalty", 0.002))
	var done := false
	var result := ""
	if _nearest_enemy() == null:
		done = true
		result = "win"
		r += float(_ep.get("win_bonus", 5.0))
	elif player.is_dead:
		done = true
		result = "loss"
		r -= float(_ep.get("loss_penalty", 5.0))
	elif _t >= _max_time:
		done = true
		result = "timeout"
		r += float(_ep.get("timeout_reward", -1.0))
	_ep_reward += r
	var info := {}
	if done:
		info = {"result": result, "t": _t, "dealt": _total.dealt / maxf(_enemy_max_hp(), 1.0),
			"taken": _total.taken / maxf(player.max_hp, 1.0), "perfect": player.ml_counts.perfect,
			"chain": player.ml_counts.chain, "dodged": player.ml_counts.dodged, "reward": _ep_reward,
			"hero": String(_ep.get("hero_class", ""))}
		_results.append({"win": "V", "loss": "D", "timeout": "-"}[result])
	return {"obs": _obs(), "r": r, "done": done, "info": info}


func _enemy_hp() -> float:
	var t := 0.0
	for e in enemies:
		if is_instance_valid(e):
			t += maxf(e.hp, 0.0)
	return t


## PV max cumulés des adversaires au début du combat (un adversaire mort et retiré compte toujours).
func _enemy_max_hp() -> float:
	return _enemy_max_total


func _nearest_enemy() -> Combatant:
	return _nearest(player, enemies)


## Adversaire vivant le plus proche de [param me] parmi [param opps].
func _nearest(me: Combatant, opps: Array) -> Combatant:
	var best: Combatant = null
	var bd := INF
	for e in opps:
		if is_instance_valid(e) and not e.is_dead:
			var d: float = e.global_position.distance_squared_to(me.global_position)
			if d < bd:
				bd = d
				best = e
	return best


## Repère de l'IA : avant = vers l'adversaire le plus proche (horizontal).
func _fwd() -> Vector3:
	return _fwd_for(player, enemies)


func _fwd_for(me: Player, opps: Array) -> Vector3:
	var e := _nearest(me, opps)
	var to := (e.global_position - me.global_position) if e else me.forward()
	to.y = 0.0
	return to.normalized() if to.length() > 0.01 else Vector3.FORWARD


func _side(f: Vector3) -> Vector3:
	return Vector3(f.z, 0.0, -f.x)


# --- ce que voit l'IA ----------------------------------------------------------------------
func _obs() -> Array:
	return _obs_for(player, enemies, _class_obs, _last_button, _low_hp)


## Ce que voit le cerveau du héros [param me] face à [param opps] (le héros du joueur, ou un
## héros ennemi en duel : même disposition, chacun de son point de vue).
func _obs_for(me: Player, opps: Array, class_obs: Array, last_button: int, low_hp: float) -> Array:
	var o: Array = []
	var p := me
	var f := _fwd_for(me, opps)
	var s := _side(f)
	var scen := String(_ep.get("scenario", "dummy"))
	_one_hot(o, SCENARIOS.find("rival" if scen == "duel" else scen), SCENARIOS.size())
	o.append_array(class_obs)
	o.append(float(_ep.get("difficulty", 0)) / 3.0)
	o.append(1.0 if int(_ep.get("skills", 4)) > 4 else 0.0)
	o.append(1.0 if low_hp > 0.0 else 0.0)
	o.append(clampf(_t / maxf(_max_time, 1.0), 0.0, 1.0))
	# --- héros
	o.append(p.hp / maxf(p.max_hp, 1.0))
	_one_hot(o, HERO_STATES.find(p._state), HERO_STATES.size())
	var acting := p._state in ["attack", "skill"]
	o.append(clampf(p._state_time / 2.0, 0.0, 1.0))
	o.append(clampf((float(p._hits[0]) - p._state_time) / 1.5, 0.0, 1.0) if acting and not p._hits.is_empty() else 0.0)
	o.append(1.0 if acting and p._action.get("hit_done", false) else 0.0)
	o.append(1.0 if p._state == "skill" and p._action.get("hit_done", false) and p._time - p._last_hit_at <= Player.PERFECT_WINDOW else 0.0)
	o.append(clampf(p._state_len / 2.0, 0.0, 1.0) if acting else 0.0)
	var cs := p.combo_state()
	o.append(float(cs.x) / maxf(cs.y, 1.0))
	o.append(clampf(p._combo_expire - p._time, 0.0, 1.0))
	o.append(p.dodge_cooldown().x / Player.DODGE_COOLDOWN)
	o.append(clampf((p._skill_lock_until - p._time) / 1.5, 0.0, 1.0))
	o.append(1.0 if p.is_on_floor() else 0.0)
	o.append(clampf(p.velocity.y / 15.0, -1.0, 1.0))
	o.append(p._jumps_used / 2.0)
	o.append(p._air_dashes / 2.0)
	o.append(p.flow_state().x / 4.0)
	for slot in 4:
		var sk := p.skill_in_slot(slot)
		if sk.is_empty():
			o.append_array([0.0, 0.0, 0.0, 0.0, 0.0, 0.0])
			continue
		var cd := p.cooldown_left(slot)
		var ch := p.chain_state(slot)
		o.append(1.0 if cd <= 0.0 else 0.0)
		o.append(clampf(cd / 20.0, 0.0, 1.0))
		o.append(1.0 if not ch.is_empty() and ch.phase == "lock" else 0.0)
		o.append(float(ch.p) if not ch.is_empty() and ch.phase == "bar" else 0.0)
		o.append(1.0 if not ch.is_empty() else 0.0)
		o.append(p.kit_chain(slot).size() / 2.0)
	for st in HERO_STATUSES:
		o.append(1.0 if p.has_status(st) else 0.0)
	var off := p.global_position - center
	off.y = 0.0
	o.append(off.dot(s) / RADIUS)
	o.append(off.dot(f) / RADIUS)
	o.append(clampf((RADIUS - off.length()) / RADIUS, 0.0, 1.0))
	var pf := p.forward()
	o.append(pf.dot(s))
	o.append(pf.dot(f))
	o.append(clampf(p.velocity.dot(s) / 15.0, -1.5, 1.5))
	o.append(clampf(p.velocity.dot(f) / 15.0, -1.5, 1.5))
	o.append(clampf(p.attack_reach() / 10.0, 0.0, 1.0))
	# --- adversaire le plus proche (monstre, adversaire de classe ou héros ennemi)
	var e := _nearest(me, opps)
	var hero := e as Player
	if e == null:
		o.append_array(_zeros(29 + Combatant.CC_TYPES.size()))
	else:
		var to := e.global_position - p.global_position
		to.y = 0.0
		o.append(e.hp / maxf(e.max_hp, 1.0))
		o.append(clampf(to.length() / 20.0, 0.0, 1.5))
		o.append(clampf((to.length() - e.radius - p.attack_reach()) / 5.0, -1.0, 1.0))
		var ef := e.forward()
		o.append(ef.dot(s))
		o.append(ef.dot(f))
		o.append(clampf(e.velocity.dot(s) / 15.0, -1.5, 1.5))
		o.append(clampf(e.velocity.dot(f) / 15.0, -1.5, 1.5))
		var eo := e.global_position - center
		eo.y = 0.0
		o.append(eo.dot(s) / RADIUS)
		o.append(eo.dot(f) / RADIUS)
		var mon := e as Monster
		if mon:
			_one_hot(o, ENEMY_STATES.find(mon._state), ENEMY_STATES.size())
			o.append(clampf((mon._hit_time - mon._state_time) / 1.5, 0.0, 1.0) if mon._state == "attack" and not mon._hit_done else 0.0)
			var rival := e as ClassRival
			o.append(1.0 if rival and rival.is_invulnerable() else 0.0)
			o.append(rival._charges / 3.0 if rival else 0.0)
			o.append(1.0 if mon._time < mon._dash_until else 0.0)
		else:
			# héros ennemi : ses états traduits dans ceux d'un adversaire de classe
			var hs := String({"idle": "chase", "jump": "chase", "dodge": "chase", "dive": "chase", "attack": "attack",
				"skill": "attack", "stun": "hurt"}.get(hero._state, "idle"))
			_one_hot(o, ENEMY_STATES.find(hs), ENEMY_STATES.size())
			var hit_t := float(hero._hits[0]) - hero._state_time if hero._state in ["attack", "skill"] and not hero._hits.is_empty() else -1.0
			o.append(clampf(hit_t / 1.5, 0.0, 1.0) if hit_t >= 0.0 else 0.0)
			o.append(1.0 if hero.is_invulnerable() else 0.0)
			o.append((0.0 if hero.dodge_cooldown().x > 0.0 else 1.0) / 3.0)
			o.append(1.0 if hero._state == "dodge" else 0.0)
		o.append(1.0 if e.is_disabled() or (hero != null and hero._state == "stun") else 0.0)
		o.append(0.0 if e.is_on_floor() else 1.0)
		for st in ENEMY_STATUSES:
			o.append(1.0 if e.has_status(st) else 0.0)
		# insensibilités aux contrôles (temps restant) : alterner les types de contrôle
		for cc in Combatant.CC_TYPES:
			o.append(clampf((float(e.statuses.get("imm_" + cc, 0.0)) - e.clock) / 5.0, 0.0, 1.0))
		o.append(clampf(e.radius, 0.0, 2.0) / 2.0)
		o.append(minf(opps.filter(func(x): return is_instance_valid(x) and not x.is_dead).size(), 4) / 4.0)
	# --- menaces : les 2 zones qui vont frapper le plus tôt (zones rouges des monstres et des
	# adversaires de classe, et zone du coup en cours d'un héros ennemi)
	var threats := _threats_for(me, opps)
	for i in 2:
		if i >= threats.size():
			o.append_array(_zeros(11))
			continue
		var th: Dictionary = threats[i]
		var rel: Vector3 = th.pos - p.global_position
		rel.y = 0.0
		var dir := Vector3(sin(th.yaw), 0.0, cos(th.yaw))
		o.append(1.0)
		o.append(clampf(float(th.left) / 1.5, 0.0, 1.0))
		o.append(1.0 if th.inside else 0.0)
		_one_hot(o, ["circle", "cone", "line"].find(th.shape), 3)
		o.append(clampf(rel.dot(s) / RADIUS, -2.0, 2.0))
		o.append(clampf(rel.dot(f) / RADIUS, -2.0, 2.0))
		o.append(dir.dot(s))
		o.append(dir.dot(f))
		o.append(clampf(float(th.size) / 12.0, 0.0, 1.5))
	# --- projectile le plus proche qui vise ce héros
	var best: Node3D = null
	var best_dir := Vector3.ZERO
	var pd := INF
	for c in get_children():
		var pr := c as Projectile
		var hb := c as HeroBolt
		var aimed := (pr != null and not me.foe) or (hb != null and is_instance_valid(hb.shooter) and hb.shooter != me)
		if not aimed:
			continue
		var d := (c as Node3D).global_position.distance_squared_to(p.global_position)
		if d < pd:
			pd = d
			best = c
			best_dir = pr.dir if pr else hb.dir
	if best:
		var rel := best.global_position - p.global_position
		rel.y = 0.0
		o.append_array([1.0, clampf(rel.dot(s) / RADIUS, -2.0, 2.0), clampf(rel.dot(f) / RADIUS, -2.0, 2.0), best_dir.dot(s), best_dir.dot(f)])
	else:
		o.append_array(_zeros(5))
	# classe de l'adversaire le plus proche (aucune pour les monstres) et sa portée
	var rv := e as ClassRival
	_one_hot(o, ML_CLASSES.find(rv.cid) if rv else (ML_CLASSES.find(hero.class_id) if hero else -1), ML_CLASSES.size())
	o.append(clampf(rv._attack_range() / 15.0, 0.0, 1.0) if rv else (clampf(hero.attack_reach() / 15.0, 0.0, 1.0) if hero else 0.0))
	_one_hot(o, last_button, BUTTONS)
	return o


## Zones qui vont frapper [param me], triées par temps avant l'impact : {left, inside, shape,
## pos, yaw, size}. Zones rouges au sol (elles ne visent que le héros du joueur) et coup en
## cours de chaque héros adverse (même forme que sa zone bleue).
func _threats_for(me: Player, opps: Array) -> Array:
	var out: Array = []
	if not me.foe:
		for c in get_children():
			var tg := c as Telegraph
			if tg and tg.is_processing() and tg.color != Telegraph.PLAYER_COLOR:
				out.append({"left": tg.delay - tg._t, "inside": tg.contains(me.global_position, me.radius),
					"shape": "circle" if tg.shape == "ring" else tg.shape, "pos": tg.global_position, "yaw": tg.rotation.y,
					"size": tg.length if tg.shape == "line" else tg.radius})
	for x in opps:
		var h := x as Player
		if h == null or not is_instance_valid(h) or h.is_dead or not (h._state in ["attack", "skill"]) or h._hits.is_empty():
			continue
		var a: Dictionary = h._action
		var kind := String(a.get("kind", "cone"))
		if kind in ["buff", "heal"]:
			continue
		var r := float(a.get("radius", Player.ATTACK_RANGE))
		var th := {"left": float(h._hits[0]) - h._state_time, "pos": h.global_position, "yaw": h.rotation.y}
		if kind == "ground" and a.has("target"):
			th.merge({"shape": "circle", "size": r}, true)
			th["pos"] = a.target
		elif kind in ["bolt", "line"] or float(a.get("range", 0.0)) > r + 1.0:
			th.merge({"shape": "line", "size": maxf(float(a.get("range", 0.0)), r),
				"width": maxf(1.2, minf(r, 3.0)) if kind == "line" else 1.2})
		elif float(a.get("arc", 360.0)) >= 359.0 or kind == "spin":
			th.merge({"shape": "circle", "size": r})
		else:
			th.merge({"shape": "cone", "size": r, "angle": float(a.get("arc", 90.0))})
		th["inside"] = _zone_hits(th, me.global_position, me.radius)
		out.append(th)
	out.sort_custom(func(u, v): return float(u.left) < float(v.left))
	return out


## Le point [param at] (rayon [param margin]) est-il dans la zone [param th] ?
func _zone_hits(th: Dictionary, at: Vector3, margin: float) -> bool:
	var to: Vector3 = at - th.pos
	to.y = 0.0
	var fwd := Vector3(sin(th.yaw), 0.0, cos(th.yaw))
	match String(th.shape):
		"line":
			var along := to.dot(fwd)
			var lateral := absf(to.dot(Vector3(fwd.z, 0.0, -fwd.x)))
			return along >= -margin and along <= float(th.size) + margin and lateral <= float(th.get("width", 1.2)) * 0.5 + margin
		"cone":
			if to.length() > float(th.size) + margin:
				return false
			return to.length() < 0.8 or rad_to_deg(fwd.angle_to(to.normalized())) <= float(th.angle) * 0.5
		_:
			return to.length() <= float(th.size) + margin


func _one_hot(o: Array, i: int, n: int) -> void:
	for k in n:
		o.append(1.0 if k == i else 0.0)


func _zeros(n: int) -> Array:
	var z: Array = []
	z.resize(n)
	z.fill(0.0)
	return z
