class_name GiantAltar
extends Node
## Autel du géant (passe P12, idée du joueur inspirée de Megabonk) : 2 par carte, gratuits, une fois chacun,
## pendant l'exploration (pas en rage). [F] fait surgir un géant (GiantMonster) ; vaincu, il donne une carte au
## choix parmi 3, de l'or et ses récompenses d'élite, et fait monter la Menace (Menace.raise : PV des monstres
## et des boss +20 % jusqu'à la fin de la run). Le prix n'est pas de l'or : c'est le risque pour la suite.
## Le nœud attaché au directeur (attach) ne sert qu'aux mesures : --giants=N fait invoquer N géants par carte
## au pilote automatique (à 2:00 puis 4:30), comme un joueur qui irait à l'autel.

const GOLD_BASE := 60  # or d'un géant vaincu : GOLD_BASE + GOLD_PER_LEVEL × niveau (comme deux défis)
const GOLD_PER_LEVEL := 15
const SPAWN_DIST := 7.0  # le géant surgit à quelques pas de l'autel
const AUTO_TIMES := [120.0, 270.0]  # mesures : instants des invocations du pilote automatique sur une carte

var director: RunDirector
var per_map := 0  # mesures : géants à invoquer par carte (--giants=N)
var _stage := 0
var _done := 0


## Nœud de mesure du directeur (lit --giants=N) ; sans l'option, il ne fait rien.
static func attach(d: RunDirector) -> GiantAltar:
	var node := GiantAltar.new()
	node.name = "GiantAltar"
	node.director = d
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--giants="):
			node.per_map = clampi(int(arg.trim_prefix("--giants=")), 0, AUTO_TIMES.size())
	d.add_child(node)
	return node


## [F] sur l'autel [param it] : un géant surgit (l'autel s'éteint). En rage, l'autel se tait (la rage multiplie
## déjà les monstres : un géant y serait un mur, pas un choix).
static func invoke(d: RunDirector, it: Interactable) -> void:
	if d.state != "explore":
		d.message.emit("L'autel se tait : trop tard pour réveiller un géant" if d.state == "rage" else "L'autel se tait", 2.0)
		return
	if d._roster.is_empty():
		return
	it.use_up()
	var dir := (d.player.global_position - it.global_position)
	dir.y = 0.0
	dir = dir.normalized() if dir.length() > 0.1 else Vector3.FORWARD
	spawn(d, it.global_position + dir * SPAWN_DIST)


## Fait surgir un géant près de [param at] : le monstre ordinaire le plus fort du moment, à la taille et à la
## force d'un géant, au niveau d'un camp d'élite.
static func spawn(d: RunDirector, at: Vector3) -> GiantMonster:
	var lvl := d._monster_level(2)
	var g := GiantMonster.new()
	g.ref_elite = GameData.monster(int(d._elites.pick_random())) if not d._elites.is_empty() else {}
	d._spawn_monster(d._pick_monster(lvl), d._around(at, 1.5), lvl, false, g)
	g.spawned_at = d.time
	Menace.giants_summoned += 1
	RunJournal.add("giant_summons")
	Tutorial.event("giant")
	g.died.connect(func(_who: Combatant, _killer: Combatant): _on_giant_died(d, g))
	Sfx.event_at(d, at, "rock", 2.0)
	Vfx.shockwave(d.player, at, 8.0, Color(1.0, 0.4, 0.2))
	d.message.emit("UN GÉANT SURGIT !\nVaincs-le : une carte, mais la Menace monte", 3.5)
	return g


## Géant vaincu : carte au choix, or, Menace +1 (plafonnée).
static func _on_giant_died(d: RunDirector, g: GiantMonster) -> void:
	if not is_instance_valid(d) or not Run.active:
		return
	var up := Menace.raise(d.get_tree())
	RunJournal.add("giant_kills")
	RunJournal.add("giant_ttk_sum", d.time - g.spawned_at)
	Run.add_gold(GOLD_BASE + GOLD_PER_LEVEL * g.level, "geants")
	print("[géant] vaincu en %.0f s · niveau %d · Menace %d (%s)" % [d.time - g.spawned_at, g.level, Menace.level, Menace.mult_text()])
	d.message.emit(("GÉANT VAINCU !\nMenace %s : monstres et boss plus résistants" % Menace.mult_text()) if up
		else "GÉANT VAINCU !\nLa Menace est déjà au maximum", 3.5)
	d.world._offer("Géant vaincu ! Choisis une carte", Run.roll_cards(3), func(): return Run.roll_cards(3))


## Mesures (--giants=N) : le pilote automatique invoque ses géants à heure fixe, sur l'autel le plus proche
## (le géant surgit près du héros, comme s'il y était allé).
func _process(_delta: float) -> void:
	if per_map <= 0 or director == null or director.player == null or not director.player.autoplay:
		return
	if Run.stage != _stage:
		_stage = Run.stage
		_done = 0
	if director.state != "explore" or _done >= per_map or director.time < float(AUTO_TIMES[_done]):
		return
	_done += 1
	var best: Interactable = null
	for it in director.map.interactables:
		if is_instance_valid(it) and it.kind == "giant" and not it.used and (best == null
				or director._flat(it.global_position, director.player.global_position) < director._flat(best.global_position, director.player.global_position)):
			best = it
	if best == null:
		return
	best.use_up()
	var g := spawn(director, director.player.global_position + director.player.forward() * SPAWN_DIST)
	print("[géant] invoqué à %.0f s · niveau %d · PV %.0f · coup %.0f · héros PV %.0f" % [director.time, g.level, g.max_hp, g.atk, director.player.max_hp])
