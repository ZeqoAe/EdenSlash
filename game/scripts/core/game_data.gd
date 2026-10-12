extends Node
## Données du jeu exportées depuis le client Eden Eternal (tools/build_assets.py)
## et réglages d'équilibrage du hack and slash.

const PHYS_WORLD := 1
const PHYS_PLAYER := 2
const PHYS_MONSTER := 4

## Nombre de monstres de son niveau à tuer pour gagner un niveau.
const KILLS_PER_LEVEL := 14
## Les monstres d'Eden sont réglés pour du MMO : on adoucit leurs dégâts
## car en hack and slash on en affronte beaucoup à la fois.
const MONSTER_DAMAGE_FACTOR := 0.22
## Lisibilité hack and slash : le héros chibi d'Eden est agrandi, les monstres réduits.
const HERO_SCALE := 1.3
const MONSTER_SCALE := 0.7

var monsters: Dictionary = {}  # id (int) -> Dictionary
var zones: Array = []
var levels: Array = []
var classes: Dictionary = {}  # id -> classe (compétences, passifs, apparence...)
var motion_keys: Dictionary = {}  # kfm -> animation -> {hit, sounds, trail, len}
var minimaps: Dictionary = {}  # map -> {image, ppm, ox, oy}


func _ready() -> void:
	var raw: Dictionary = _load_json("res://data/monsters.json")
	for key in raw:
		monsters[int(key)] = raw[key]
	zones = _load_json("res://data/zones.json")
	levels = _load_json("res://data/levels.json")
	classes = _load_json("res://data/classes.json")
	motion_keys = _load_json("res://data/motion_keys.json")
	minimaps = _load_json("res://data/minimaps.json")
	_setup_input()


func class_data(id: String) -> Dictionary:
	return classes.get(id, {})


## Clés d'animation d'Eden (motion.ini) : instants d'impact, sons, traînée.
func anim_keys(kfm: String, anim: String) -> Dictionary:
	return motion_keys.get(kfm, {}).get(anim, {})


func _load_json(path: String) -> Variant:
	return JSON.parse_string(FileAccess.get_file_as_string(path))


func monster(id: int) -> Dictionary:
	return monsters.get(id, {})


## XP donnée par un monstre de niveau [param level] (table c_monster).
func monster_xp(level: int) -> int:
	# monstre normal du niveau le plus proche (inférieur ou égal), +10 % par niveau d'écart
	var best_level := 0
	var best_xp := 186
	for m in monsters.values():
		if int(m.rank) == 2 and int(m.level) <= level and int(m.level) > best_level:
			best_level = int(m.level)
			best_xp = int(m.xp)
	return int(best_xp * pow(1.1, level - maxi(best_level, 1)))


## Il faut de plus en plus de monstres de son niveau pour monter (hordes de la rage).
func xp_to_next(level: int) -> int:
	return int(monster_xp(level) * (KILLS_PER_LEVEL + level * 2.5))


## PV de base du personnage (colonne PV de c_level), doublés pour le hack and slash.
func player_max_hp(level: int) -> float:
	var idx := clampi(level - 1, 0, levels.size() - 1)
	return float(levels[idx].hp) * 2.0


func player_atk(level: int) -> float:
	return 55.0 * pow(1.1, level - 1)


func _setup_input() -> void:
	# Touches physiques : ZQSD sur AZERTY, WASD sur QWERTY.
	_bind_keys("move_forward", [KEY_W, KEY_UP])
	_bind_keys("move_back", [KEY_S, KEY_DOWN])
	_bind_keys("move_left", [KEY_A, KEY_LEFT])
	_bind_keys("move_right", [KEY_D, KEY_RIGHT])
	_bind_keys("attack", [KEY_J])
	_bind_mouse("attack", MOUSE_BUTTON_LEFT)
	_bind_mouse("camera_rotate", MOUSE_BUTTON_RIGHT)
	_bind_keys("jump", [KEY_SPACE])
	_bind_keys("dodge", [KEY_SHIFT])
	# compétences : 1-4, ou A E R T sur AZERTY (Q E R T sur QWERTY)
	_bind_keys("skill_1", [KEY_1, KEY_Q])
	_bind_keys("skill_2", [KEY_2, KEY_E])
	_bind_keys("skill_3", [KEY_3, KEY_R])
	_bind_keys("skill_4", [KEY_4, KEY_T])
	_bind_keys("interact", [KEY_F])
	_bind_keys("map", [KEY_M])
	_bind_keys("pause", [KEY_ESCAPE])
	_bind_keys("unstuck", [KEY_F4])
	_bind_keys("help", [KEY_F1])
	_bind_keys("feedback", [KEY_F9])
	_bind_keys("debug_level", [KEY_F5])
	_bind_keys("debug_gateway", [KEY_F6])
	_bind_keys("debug_dungeon", [KEY_F7])
	_bind_keys("debug_overlay", [KEY_F2])
	_bind_keys("debug_rage", [KEY_F8])


func _bind_keys(action: String, keys: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for k in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = k
		InputMap.action_add_event(action, ev)


func _bind_mouse(action: String, button: MouseButton) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	var ev := InputEventMouseButton.new()
	ev.button_index = button
	InputMap.action_add_event(action, ev)
