class_name Training
extends RefCounted
## Zone d'entraînement (comme le mode entraînement de LoL) : la carte de la zone choisie,
## sans minuterie, sans vagues ni rage, et sans rien gagner ni perdre : la sauvegarde n'est
## pas écrite pendant l'entraînement et elle est rechargée à la sortie. Le panneau
## (TrainingPanel, F3) règle le niveau, les sorts, les cartes, les recharges et les ennemis
## (invincibles, passifs, monstres au choix, mannequin), avec un compteur de DPS.

static var active := false
static var no_cd := false  # recharges à zéro
static var hero_god := true  # le héros ne perd pas de PV
static var enemies_immortal := false  # les ennemis ne meurent pas (les dégâts s'affichent)
static var enemies_passive := false  # les ennemis n'attaquent pas et ne bougent pas
static var total := 0.0  # dégâts infligés depuis la remise à zéro
static var _first := 0.0
static var _last := 0.0
static var _hits: Array = []  # [temps (s), dégâts] des 5 dernières secondes

const WINDOW := 5.0


## Lance l'entraînement avec la classe [param cid] (scène de run).
static func start(cid: String) -> void:
	active = true
	reset_meter()
	Run.start(cid)
	# 4 premiers sorts de la classe d'office (modifiables dans le panneau)
	for sk in Run.class_data().get("skills", []).slice(0, Run.MAX_SKILLS):
		Run.skills.append({"id": int(sk.id), "rank": 1})


## Dégâts infligés par le héros (Combatant.take_damage).
static func record(dmg: float) -> void:
	if not active:
		return
	var t := Time.get_ticks_msec() / 1000.0
	if total <= 0.0:
		_first = t
	total += dmg
	_last = t
	_hits.append([t, dmg])
	while not _hits.is_empty() and t - float(_hits[0][0]) > WINDOW:
		_hits.pop_front()


## DPS sur les 5 dernières secondes (ou depuis le premier coup, si plus récent).
static func dps() -> float:
	var t := Time.get_ticks_msec() / 1000.0
	var sum := 0.0
	for h in _hits:
		if t - float(h[0]) <= WINDOW:
			sum += float(h[1])
	var span := clampf(t - _first, 1.0, WINDOW) if total > 0.0 else WINDOW
	return sum / span


## Durée du combat en cours (du premier au dernier coup).
static func fight_time() -> float:
	return maxf(0.0, _last - _first) if total > 0.0 else 0.0


static func reset_meter() -> void:
	total = 0.0
	_first = 0.0
	_last = 0.0
	_hits.clear()


## Quitte l'entraînement : la sauvegarde est rechargée telle qu'avant (rien n'est gardé).
static func leave(tree: SceneTree) -> void:
	active = false
	Run.active = false
	Profile.in_run = false
	Profile.load_profile()
	Profile.gold = 0
	Profile.keys = 0
	Profile.bag = {}
	Profile._lobby_view()
	tree.paused = false
	tree.change_scene_to_file.call_deferred("res://scenes/lobby.tscn")


## Change de classe sans quitter l'entraînement (la scène est relancée).
static func restart(cid: String, tree: SceneTree) -> void:
	Profile.in_run = false
	Profile.load_profile()
	Profile.selected_class = cid
	Profile._lobby_view()
	start(cid)
	tree.paused = false
	tree.change_scene_to_file.call_deferred("res://scenes/world.tscn")
