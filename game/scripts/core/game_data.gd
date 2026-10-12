extends Node
## Données du jeu exportées depuis le client Eden Eternal (tools/build_assets.py)
## et réglages d'équilibrage du hack and slash.

const PHYS_WORLD := 1
const PHYS_PLAYER := 2
const PHYS_MONSTER := 4

## Nombre de monstres de son niveau à tuer pour gagner un niveau.
const KILLS_PER_LEVEL := 20
## Chaque coup de monstre est annoncé au sol et peut s'esquiver : il doit
## donc faire mal (une meute de 6 tue en quelques secondes si on reste planté).
const MONSTER_DAMAGE_FACTOR := 1.6
## Lisibilité hack and slash : le héros chibi d'Eden est agrandi, les monstres réduits.
const HERO_SCALE := 1.3
const MONSTER_SCALE := 0.7

var monsters: Dictionary = {}  # id (int) -> Dictionary
var zones: Array = []
var biomes: Dictionary = {}  # id -> textures, ambiance, décors (tools/build_biomes.py)
var levels: Array = []
var classes: Dictionary = {}  # id -> classe (compétences, passifs, apparence...)
var motion_keys: Dictionary = {}  # kfm -> animation -> {hit, sounds, trail, len}
var minimaps: Dictionary = {}  # map -> {image, ppm, ox, oy}


func _ready() -> void:
	var raw: Dictionary = _load_json("res://data/monsters.json")
	for key in raw:
		monsters[int(key)] = raw[key]
	zones = _load_json("res://data/zones.json")
	if FileAccess.file_exists("res://data/biomes.json"):
		biomes = _load_json("res://data/biomes.json")
	levels = _load_json("res://data/levels.json")
	classes = _load_json("res://data/classes.json")
	motion_keys = _load_json("res://data/motion_keys.json")
	minimaps = _load_json("res://data/minimaps.json")


## Zone [param id] (Limestone par défaut).
func zone(id: String) -> Dictionary:
	for z in zones:
		if z.id == id:
			return z
	return zones[0]


func zone_index(id: String) -> int:
	for i in zones.size():
		if zones[i].id == id:
			return i
	return 0


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
	return 45.0 * pow(1.1, level - 1)
