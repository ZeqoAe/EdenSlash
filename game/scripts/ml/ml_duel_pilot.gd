class_name MlDuelPilot
extends MlArena
## Cerveau d'IA (entraîné dans l'arène ML) qui pilote un héros ennemi dans le duel du jeu :
## reprend ce que voit et fait l'IA de l'arène (_obs_for, _apply_for), sans connexion à Python
## ni arène à construire. Le duel l'ajoute comme enfant ; tick() à chaque image
## physique (le nœud le fait lui-même) : une décision toutes les REPEAT images, comme à l'entraînement.
## Fichiers : res://data/cerveaux/cerveau_<palier>.json (débutant … hardcore, actuel), hors git ; le Panthéon
## utilise des copies figées pantheon_<palier>.json, dans git.

const BRAINS := [["debutant", "Débutant"], ["facile", "Facile"], ["normal", "Normal"], ["difficile", "Difficile"],
	["hardcore", "Hardcore"], ["actuel", "Le plus récent"]]

var foe: Player
var target: Player
var brain: MlBrain
var temperature := 0.0
var _pilot_bot := BotInput.new()
var _pilot_obs: Array = []
var _pilot_last := 0
var _pilot_wait := 0


static func brain_path(key: String) -> String:
	# Panthéon : cerveaux figés (pantheon_<id>.json, dans git) pour que les défis ne changent pas avec l'entraînement
	if Duel.mode == "pantheon" and FileAccess.file_exists(frozen_path(key)):
		return frozen_path(key)
	return "res://data/cerveaux/cerveau_%s.json" % key


static func frozen_path(key: String) -> String:
	return "res://data/cerveaux/pantheon_%s.json" % key


## Cerveaux présents (les fichiers sont produits par l'entraînement, hors git).
static func available() -> Array:
	return BRAINS.filter(func(b): return FileAccess.file_exists(brain_path(String(b[0]))))


func _ready() -> void:
	pass  # pas d'arène, pas de Python


func _process(_delta: float) -> void:
	pass


## Décision posée avant que le héros ennemi ne bouge (priorité, comme dans l'arène).
func _physics_process(delta: float) -> void:
	tick(delta)


## Prend en main [param hero] (héros ennemi) contre [param player] avec le cerveau [param key].
## Renvoie false si le cerveau manque ou ne correspond pas à cette version de l'arène.
func setup(hero: Player, player_hero: Player, key: String, arena_center: Vector3, temp := 0.0) -> bool:
	process_physics_priority = -100
	foe = hero
	target = player_hero
	temperature = temp
	center = arena_center
	_ep = {"scenario": "duel", "difficulty": 3, "skills": 12}
	_max_time = 180.0
	brain = MlBrain.load_file(brain_path(key))
	if brain == null:
		return false
	hero.bot = _pilot_bot
	_pilot_obs = _build_class_obs(hero)
	var n := _obs_for(foe, [target], _pilot_obs, 0, 0.0).size()
	if n != brain.obs_size:
		push_warning("cerveau %s : %d entrées attendues, le jeu en donne %d" % [key, brain.obs_size, n])
		return false
	return true


## À chaque image physique du duel (avant le déplacement du héros ennemi).
func tick(delta: float) -> void:
	_t += delta
	if foe == null or not is_instance_valid(foe) or foe.is_dead or brain == null or target == null:
		return
	if _pilot_wait > 0:
		_pilot_wait -= 1
		_pilot_bot.pulse.clear()  # une touche n'est appuyée qu'à la première image de la décision
		return
	var obs := _obs_for(foe, [target], _pilot_obs, _pilot_last, 0.0)
	_pilot_last = _apply_for(_pilot_bot, foe, [target], brain.act(obs, temperature))
	_pilot_wait = REPEAT - 1


## Jeu de sorts du héros ennemi : les 12 sorts de sa classe (comme à l'entraînement).
static func kit_for(cid: String) -> Dictionary:
	var all: Array = GameData.class_data(cid).get("skills", [])
	var skills: Array = []
	var chains := {}
	for i in mini(4, all.size()):
		skills.append({"id": int(all[i].id), "rank": 1})
	for slot in 4:
		var ch: Array = []
		for k in 2:
			var idx := 4 + slot * 2 + k
			if idx < all.size():
				ch.append({"id": int(all[idx].id), "rank": 1})
		if not ch.is_empty():
			chains[slot] = ch
	return {"skills": skills, "chains": chains}
