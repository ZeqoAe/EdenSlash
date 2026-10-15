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
var biomes: Dictionary = {}
var talents: Dictionary = {}
var weapon_types: Dictionary = {}  # katana, axe, dagger, bow, scepter, staff (tools/build_classes.py)  # classe -> arbre de talents et certificats (tools/build_talents.py)  # id -> textures, ambiance, décors (tools/build_biomes.py)
var levels: Array = []
var classes: Dictionary = {}  # id -> classe (compétences, passifs, apparence...)
var motion_keys: Dictionary = {}  # kfm -> animation -> {hit, sounds, trail, len}
var minimaps: Dictionary = {}  # map -> {image, ppm, ox, oy}
## Tous les équipements d'Eden (tools/build_items.py) : par type (emplacement ou type
## d'arme), par identifiant et par code de modèle.
var eden_items: Array = []
var eden_by_slot: Dictionary = {}
var eden_by_id: Dictionary = {}
var eden_by_code: Dictionary = {}
var cosmetics: Array = []
var eden_sets: Dictionary = {}  # "e<id>" -> {name, pieces, bonus}
var eden_bands: Array = []  # [min, max] des niveaux d'Eden de chaque zone (ordre de zones.json)
## Entrées de l'archive d'Eden hors équipement : apparences (cat. 1-4), montures (29),
## familiers (30), boîte arcanique (31), autres objets (32, dont les auras).
var collection: Array = []
var collection_by_id: Dictionary = {}
var auras: Array = []  # entrées avec "aura" : {fx, stat, kind (star / luna / other)}
var cosmetic_by_code: Dictionary = {}  # code K d'Eden -> cosmétique (tenue, tête, dos)
var skin_by_code: Dictionary = {}  # code K d'Eden -> apparence d'arme {model, texture, wtype}


func _ready() -> void:
	var raw: Dictionary = _load_json("res://data/monsters.json")
	for key in raw:
		monsters[int(key)] = raw[key]
	zones = _load_json("res://data/zones.json")
	if FileAccess.file_exists("res://data/weapon_types.json"):
		weapon_types = _load_json("res://data/weapon_types.json")
	if FileAccess.file_exists("res://data/talents.json"):
		talents = _load_json("res://data/talents.json")
	if FileAccess.file_exists("res://data/biomes.json"):
		biomes = _load_json("res://data/biomes.json")
	levels = _load_json("res://data/levels.json")
	classes = _load_json("res://data/classes.json")
	# passifs communs (Corps aguerri, sauts…) recopiés dans chaque classe : ce sont des cartes
	# communes à toutes les classes (Boons.all) ; la classe ne garde que ses certificats d'Eden
	for cid in classes:
		var keep: Array = []
		for p in classes[cid].get("passives", []):
			if p.has("eden"):
				keep.append(p)
			elif not common_passives.any(func(q): return q.id == p.id):
				common_passives.append(p)
		classes[cid]["passives"] = keep
	_balance_damage_types()
	motion_keys = _load_json("res://data/motion_keys.json")
	minimaps = _load_json("res://data/minimaps.json")
	var cat_path := "res://data/eden_catalog.json" if FileAccess.file_exists("res://data/eden_catalog.json") else "res://data/eden_items.json"
	if FileAccess.file_exists(cat_path):
		var ei: Dictionary = _load_json(cat_path)
		eden_sets = ei.get("sets", {})
		eden_items = ei.get("items", [])
		# entrées de test du client d'Eden (« Available ID (JP) », « Testing ID »…) : écartées
		var junk := RegEx.create_from_string("(?i)^(test|testing|available id)\\b")
		cosmetics = (ei.get("cosmetics", []) as Array).filter(func(c): return junk.search(String(c.get("name", ""))) == null)
		collection = (ei.get("collection", []) as Array).filter(func(c): return junk.search(String(c.get("name", ""))) == null)
		for c: Dictionary in collection:
			collection_by_id[int(c.id)] = c
			if c.has("aura"):
				auras.append(c)
			if c.has("skin"):
				skin_by_code[String(c.code)] = c.skin
		for c: Dictionary in cosmetics:
			for code in c.get("codes", []):
				cosmetic_by_code[String(code)] = c
		for e: Dictionary in eden_items:
			var key := String(e.get("wtype", e.slot))
			if not eden_by_slot.has(key):
				eden_by_slot[key] = []
			eden_by_slot[key].append(e)
			eden_by_id[int(e.id)] = e
			eden_by_code[String(e.code)] = e
		NamesFr.apply(self)  # noms français (data/names_fr.json) : avant les modifications du mode dev
		DevEdits.load_and_apply()  # modifications du mode dev (data/dev_edits.json)


	_build_eden_bands()


## Pièce « Awaken » d'Eden (éveillée) : le nom d'origine fait foi, le nom affiché est français.
func is_awakened(e: Dictionary) -> bool:
	return String(e.get("name_en", e.get("name", ""))).begins_with("Awaken ")


## Niveaux d'Eden couverts par chaque zone, dans l'ordre chronologique d'Eden : de son
## niveau de carte (zones.json -> levels) jusqu'à celui de la zone suivante ; la dernière
## zone va jusqu'au niveau 100.
func _build_eden_bands() -> void:
	eden_bands = []
	for i in zones.size():
		var lo := 1 if i == 0 else int(zones[i].get("levels", [1, 1])[0])
		var hi := 100 if i == zones.size() - 1 else int(zones[i + 1].get("levels", [100, 100])[0]) - 1
		eden_bands.append([lo, maxi(lo, hi)])


## Niveaux de run d'une zone : du départ (1 + bonus) au plafond de la rage.
func zone_run_levels(zi: int) -> Vector2i:
	var z: Dictionary = zones[clampi(zi, 0, zones.size() - 1)]
	var s := 1 + int(z.get("level_bonus", 0))
	return Vector2i(s, int(z.get("max_level", 15)) + 3)


## Niveau d'Eden des objets qui tombent au niveau de run [param level] dans la zone
## [param zi] : la tranche d'Eden de la zone est parcourue au fil de la run.
func eden_level_at(zi: int, level: int) -> int:
	if eden_bands.is_empty():
		return level
	var b: Array = eden_bands[clampi(zi, 0, eden_bands.size() - 1)]
	var r := zone_run_levels(zi)
	var t := clampf(float(level - r.x) / float(maxi(r.y - r.x, 1)), 0.0, 1.0)
	return roundi(lerpf(float(b[0]), float(b[1]), t))


## Niveau de puissance (niveau de run) d'un objet d'Eden de niveau [param eden_level] :
## position de ce niveau dans la tranche de sa zone (objets donnés hors run).
func power_level_of(eden_level: int) -> int:
	for i in eden_bands.size():
		var b: Array = eden_bands[i]
		if eden_level <= int(b[1]) or i == eden_bands.size() - 1:
			var r := zone_run_levels(i)
			var t := clampf(float(eden_level - int(b[0])) / float(maxi(int(b[1]) - int(b[0]), 1)), 0.0, 1.0)
			return roundi(lerpf(float(r.x), float(r.y), t))
	return eden_level


## Zone (indice) dont la tranche d'Eden contient [param eden_level].
func zone_of_eden_level(eden_level: int) -> int:
	for i in eden_bands.size():
		if eden_level <= int(eden_bands[i][1]):
			return i
	return maxi(eden_bands.size() - 1, 0)


func weapon_type(id: String) -> Dictionary:
	return weapon_types.get(id, weapon_types.get("katana", {}))


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


## Passifs communs à toutes les classes (cartes communes), tirés de data/classes.json.
var common_passives: Array = []


func class_data(id: String) -> Dictionary:
	return classes.get(id, {})


## Clés d'animation d'Eden (motion.ini) : instants d'impact, sons, traînée.
func anim_keys(kfm: String, anim: String) -> Dictionary:
	return motion_keys.get(kfm, {}).get(anim, {})


## Cohérence physique / magique : une classe dont la majorité des sorts d'attaque sont magiques est une
## classe magique (type de dégâts « mag », attaque magique de base comme les classes magiques d'origine),
## sinon ses sorts magiques s'appuieraient sur une attaque magique de base trop faible.
func _balance_damage_types() -> void:
	for cid in classes:
		var c: Dictionary = classes[cid]
		var mag := 0
		var phys := 0
		for s in c.get("skills", []):
			if s.get("shared", false) or String(s.get("kind", "")) in ["buff", "heal"]:
				continue
			if String(s.get("dmg_type", "phys")) == "mag":
				mag += 1
			else:
				phys += 1
		if mag > phys and String(c.get("dmg_type", "phys")) != "mag":
			c["dmg_type"] = "mag"
			var b: Dictionary = c.get("base", {})
			b["atk"] = 0.6
			b["matk"] = 1.1
			c["base"] = b


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
