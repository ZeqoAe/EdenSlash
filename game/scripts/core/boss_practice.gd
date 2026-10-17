class_name BossPractice
extends RefCounted
## « S'entraîner » contre un boss (lot DNG-3, backlog BM-DNG P1-4 ; « mode Explorateur » de FFXIV) : la salle du boss d'un donjon,
## sans rien gagner ni perdre. Le moteur est celui des Donjons (Tower.start_dungeon, reprise à la salle du boss) ; à la sortie la
## sauvegarde est rechargée telle qu'avant (comme la zone d'entraînement) : ni butin, ni maîtrise, ni niveau de héros, ni
## records, ni étoiles, ni rencontres. Le panneau (PracticePanel, F3) : héros invincible au choix (oui par défaut), chaque
## mécanique du boss à rejouer tout de suite, boss remis à pleine vie, sortie vers la page Donjons. K.O. : on se relève aussitôt ;
## boss vaincu : il revient à pleine vie.
## Ouvert depuis la page Donjons (« S'entraîner ») et depuis le bilan d'une chute (le boss qui t'a battu).

static var active := false
static var boss := ""  # boss de la bibliothèque
static var diff := 0
static var god := true  # héros invincible (il prend les coups, ses PV ne baissent pas)


## Lance l'entraînement contre [param bid] en difficulté [param p_diff] avec la classe [param cid] (la scène de partie suit).
static func start(cid: String, bid: String, p_diff: int) -> void:
	var zid := Dungeons.boss_zone(bid)
	Tower.start_dungeon(cid, zid, p_diff, [], bid, Dungeons.ROOMS.size())
	active = true
	boss = bid
	diff = clampi(p_diff, 0, Dungeons.DIFF_NAMES.size() - 1)
	Relief.left = 0


## Le boss de l'entraînement peut être ouvert ici : sa zone est ouverte.
static func can_start(bid: String) -> bool:
	return BossLibrary.has(bid) and Dungeons.is_open(Dungeons.boss_zone(bid))


## Rejoue la mécanique [param i] (indice dans les briques du cerveau) du boss [param m] : une périodique part tout de suite
## (son minuteur tombe à zéro), une mécanique à seuil est lancée tout de suite. Renvoie false si le boss est occupé.
static func replay(m: Monster, i: int) -> bool:
	if m == null or not is_instance_valid(m) or m.is_dead or m.brain == null:
		return false
	var br: BossBrain = m.brain
	if i < 0 or i >= br.bricks.size():
		return false
	var b: Dictionary = br.bricks[i]
	if String(b.kind) == "every":
		br._brick_t[i] = 0.0
		return true
	if br._busy:
		return false
	return BossBricks.run(br, b) or true


## Boss à pleine vie (et ses seuils à nouveau à venir).
static func refill(m: Monster) -> void:
	if m == null or not is_instance_valid(m) or m.is_dead:
		return
	m.hp = m.max_hp
	m.health_changed.emit(m.hp, m.max_hp)
	if m.brain != null:
		m.brain._thresholds_done.clear()


## Fois que la mécanique [param type] a été vue pendant l'entraînement (le journal des rencontres la compte en partie, mais
## l'entraînement ne l'écrit jamais : Encounters n'est pas validé à la sortie).
static func seen(type: String) -> int:
	var p: Dictionary = Encounters._pending.get(boss, {})
	return int((p.get("seen", {}) as Dictionary).get(type, 0))


## Fin de l'entraînement : la sauvegarde est rechargée telle qu'avant (rien n'est gardé), retour à la page Donjons sur ce boss.
static func leave(tree: SceneTree, go := true) -> void:
	var bid := boss
	active = false
	Tower.active = false
	Tower.dungeon = ""
	Tower.dungeon_boss = ""
	Tower.allies = []
	Run.active = false
	Profile.in_run = false
	Profile.load_profile()
	Profile.gold = 0
	Profile.keys = 0
	Profile.bag = {}
	Profile._lobby_view()
	HitLog.reset()
	BestTimes.reset()
	Encounters.reset()
	DungeonPage.sel = bid
	DungeonPage.lobby_request = "dungeon"
	tree.paused = false
	if go:  # (tests : false, la scène reste)
		LoadScreen.to_lobby(tree)
