class_name Tower
extends RefCounted
## Mode de jeu « la Tour » : gravir 200 étages d'affilée. On part avec une arme commune et une
## carte de rareté aléatoire ; chaque étage vidé donne une carte (sorts, passifs, comme en run)
## et un coffre au centre de la salle, à ouvrir tout de suite : son objet s'équipe pour
## l'ascension en cours s'il est meilleur. Un boss tous les 10 étages, une élite tous les 5,
## le décor change tous les 25 étages (les 8 zones). Une seule vie : tomber met fin à
## l'ascension. Rien de la Tour ne reste (ni objets ni or) sauf le record d'étage et
## l'expertise de la classe : la sauvegarde n'est pas écrite pendant l'ascension, elle est
## rechargée à la sortie (comme l'entraînement).

const FLOORS := 200
const FLOORS_PER_ZONE := 25
const RECORD := "tower_best"

static var active := false
static var floor_n := 1  # étage en cours
static var reached := 0  # dernier étage vidé


## Lance l'ascension avec la classe [param cid] (scène de run).
static func start(cid: String) -> void:
	active = true
	floor_n = 1
	reached = 0
	Run.start(cid)
	# on part de rien : une arme commune de la classe, pas d'autre équipement ni de sac
	Profile.equipped = {"weapon": Items.generate(1, 0.0, "weapon", cid, 0, "", 0)}
	Profile.inventory = []
	Profile.bag = {}
	Profile.gold = 0
	Profile.keys = 0
	Profile.changed.emit()


## Zone (décor, monstres, boss) de l'étage [param f].
static func zone_for(f: int) -> Dictionary:
	return GameData.zones[clampi((f - 1) / FLOORS_PER_ZONE, 0, GameData.zones.size() - 1)]


## Niveau du héros et des monstres à l'étage [param f] (1 à l'étage 1, 101 au sommet).
static func level_for(f: int) -> int:
	return 1 + (f - 1) / 2


static func is_boss_floor(f: int) -> bool:
	return f % 10 == 0


static func is_elite_floor(f: int) -> bool:
	return f % 5 == 0 and not is_boss_floor(f)


## Monstres à vaincre à l'étage [param f] (hors boss).
static func monster_count(f: int) -> int:
	return mini(8 + f / 4, 40)


## Monstres en même temps dans la salle.
static func max_alive(f: int) -> int:
	return mini(6 + f / 20, 16)


## PV et dégâts des monstres : la difficulté monte aussi à l'intérieur d'une même zone.
static func monster_mult(f: int) -> float:
	return 1.0 + 0.02 * float((f - 1) % FLOORS_PER_ZONE) + 0.1 * float((f - 1) / FLOORS_PER_ZONE)


## Rareté du coffre de l'étage : meilleure en montant ; mythique ou légendaire sur un boss.
static func chest_item(f: int, class_id: String) -> Dictionary:
	var lv := level_for(f)
	if is_boss_floor(f):
		var rar := Items.LEGENDARY if randf() < 0.25 + f / 400.0 else Items.MYTHIC
		return Items.generate(lv, 1.0, "", class_id, rar, "", rar)
	var luck := clampf(f / 120.0, 0.0, 1.5) + (0.4 if is_elite_floor(f) else 0.0)
	return Items.generate(lv, luck, "", class_id, 1 if f >= 20 else 0, "", 3)  # commun à épique


static func best() -> int:
	return int(Profile.records.get(RECORD, 0))


## Fin de l'ascension : la sauvegarde est rechargée (rien de la Tour n'est gardé), puis le
## record d'étage et l'expertise de la classe sont enregistrés. Renvoie {best, new_record, xp, levels}.
static func finish() -> Dictionary:
	if not active:
		return {}
	active = false
	Run.active = false
	var cid := Run.class_id
	Profile.in_run = false
	Profile.load_profile()
	Profile.gold = 0
	Profile.keys = 0
	Profile.bag = {}
	var old := best()
	Profile.record_max(RECORD, reached)
	var xp := reached * 12 + Run.kills / 3
	var lv := Profile.add_expertise(cid, xp)
	Profile._lobby_view()
	Profile.save_profile()
	return {"best": best(), "new_record": reached > old, "xp": xp, "levels": lv}


static func leave(tree: SceneTree) -> void:
	if active:
		finish()
	tree.paused = false
	tree.change_scene_to_file.call_deferred("res://scenes/lobby.tscn")
