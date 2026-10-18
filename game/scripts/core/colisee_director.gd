class_name ColiseeDirector
extends Node
## Le Colisée, lot CO-C (conception/benchmark/R_CO_C.md ; ARENA.md § 6.2, § 6.10) : le directeur du COMBAT de la partie.
## Monté par RunDirector.start (TeamMatch.mount, état « team ») ; la machine de partie est Colisee.game (lot CO-A).
##
## Une manche : préparation (PREP s ; l'interface complète vient au lot CO-G) -> compte à rebours (Colisee.COUNTDOWN)
## -> combats : tous ceux de la manche se jouent EN MÊME TEMPS, pour de vrai (mêmes héros scriptés, mêmes sorts), chacun dans
## son arène de la carte du Colisée (ColiseeArena, anneau de feu, fleurs) -> fin quand un trio est entièrement à terre, ou
## au temps (Colisee.FIGHT_TIME, égalité : PV restants) -> bandeau (RECAP s) -> Colisee.report, éliminations rendues à
## TeamMatch dans le même ordre -> manche suivante, jusqu'à la dernière équipe debout.
##
## Combats cachés (patron AC-E) : seule l'arène REGARDÉE est rendue ; ailleurs, héros invisibles, animations arrêtées, ni
## effets, ni sons, ni chiffres (Vfx.hidden_arenas : EdenFx, Sfx, DamageNumber, Vfx, télégraphes), ni annonces. Repli : si
## une image dépasse FALLBACK_MS pendant FALLBACK_AFTER s (temps réel), les combats cachés encore en cours sont résolus « au
## tableau » (Colisee.resolve_board : PV × frappe), noté dans le journal (« [colisee] repli au tableau »).
## Héros : recréés à chaque manche (un héros scripté tombé disparaît) : l'arène regardée tout de suite, les autres
## SPAWN_PER_FRAME par image ; modèles préchargés au lancement (prepare). Équipes au repos (exempte, éliminées) : personne.
## Mort du joueur : ses alliés continuent, la caméra suit un allié ; trio du joueur éliminé ou combat fini : spectateur de base
## (la caméra passe au combat encore en cours le plus long ; watch(i) / next_watch()).
##
## Lancement direct : world.tscn -- --colisee [--co-format=classique|eclair|grand] [--co-diff=0..4] [--co-seed=N]
## [--autoplay] [--auto-quit] (lignes « [colisee] … »).

const PREP := 3.0  # préparation minimale (lot CO-G : 30 s, écran de préparation)
const PREP_AUTO := 1.0
const RECAP := Colisee.RECAP
const SPAWN_PER_FRAME := 3
## Repli au tableau : images de plus de FALLBACK_MS ms (deux images à 60 i/s) cumulées sur FALLBACK_AFTER s réelles, pas avant
## FALLBACK_GRACE s de combat (l'apparition des héros coûte) ; une image rapide en retire deux fois sa durée. Plus prudent que
## l'Échiquier (20 ms, 2 s) : sur une machine chargée, la première version tranchait des combats au bout de 1,3 s.
const FALLBACK_MS := 33.0
const FALLBACK_AFTER := 3.0
const FALLBACK_GRACE := 5.0
## Page de préparation (lot CO-F, page minimale de test ; l'écran complet : lot CO-G) : montrée hors pilote automatique
## et hors mode sans écran quand le joueur a un choix à faire ; la préparation dure alors celle du format.
static var prep_ui := true
var prep_page: Node = null
## Arène des héros au repos : aucune (ffa_foes ne les voit jamais).
const PARK := 1000
const FOLLOW_SWITCH := 2.0  # s après la fin de ton combat avant de regarder ailleurs

## Mesures (outil tools/colisee_probe) : pas de préparation, combat dès que les héros sont là, pas de repli, pas de fin.
static var probe := false
## Repli au tableau permis (--co-nofallback : jamais, pour mesurer les vrais combats).
static var fallback := true
## Abandon sans changer de scène (outils de capture, tests).
var abandon_stay := false
## IA d'équipe (lot CO-D, R_CO_D.md) : un chef (ColiseeCoach) par camp et par combat, de niveau = difficulté du trio, sauf
## [member coach_levels] (par équipe ; -1 : aucun chef, le héros scripté seul comme au lot CO-C). Banc tools/colisee_games :
## [member watch_only] (le joueur au repos, son trio joué par 3 héros scriptés : parties IA contre IA), [member even_sheets]
## (fiche égale à toutes les difficultés : sans le facteur ClassRival.DUEL_DIFF, seul le jeu compte), ligne JSON de la partie
## à la fin (« [colisee] partie {…} »). Arguments : --co-watch, --co-even, --co-coach=a,b,…, --co-diffs=a,b,…
static var coach_levels: Array = []
static var watch_only := false
static var even_sheets := false

var d: RunDirector
var g: Colisee
var map: ProcMap
var arenas: Array = []  ## ColiseeArena
var fights: Array = []  ## combats de la manche (voir _make_fight)
var phase := "intro"  # intro, prep, countdown, fight, recap, done
var _t := 0.0
var watched := 0  ## combat regardé (indice dans fights)
var _queue: Array = []  # [combat, camp, k] héros à créer
var _slow := 0.0
var _last_us := 0
var _player_out := false
var _done_t := -1.0
var _obj_t := 0.0
var frame_ms: Array = []  ## (sonde) durée de chaque image du combat, en ms réelles
var spawn_ms := 0.0  ## (sonde) temps passé à créer les héros de la manche
var log_lines: Array = []  ## journal de la partie (replis, éliminations)
var fallbacks := 0
var started_ms := 0


func setup(director: RunDirector) -> void:
	d = director
	g = Colisee.game
	if g == null:
		g = Colisee.new("classique", randi())  # (lancé sans Colisee.begin : partie par défaut)
		g.team_diffs = Colisee.team_difficulties(1, g.n, g.rng)
		g.classes = Colisee.compose_teams(g.n, Run.class_id, g.rng)
		Colisee.game = g
	started_ms = Time.get_ticks_msec()
	if "--co-nofallback" in OS.get_cmdline_user_args():
		fallback = false
	_read_bench_args()
	d.zone = GameData.zone(Run.zone_id)
	map = ProcMap.new()
	map.biome = String(d.zone.get("biome", "limestone"))
	map.name = "Colisee"
	d.world._swap_map(map)
	map.generate_colisee(int(g.rng.seed % 100000), arena_count())
	d.map = map
	d.world._apply_biome_env()
	arenas = ColiseeArena.build_all(map, self)
	for a in arenas:
		for fl in (a as ColiseeArena).flowers:
			(fl as ColiseeFlower).picked.connect(_on_flower.bind(int((a as ColiseeArena).index)))
	prepare(g)
	var p := d.player
	p.level = Colisee.LEVEL
	Run.hero_level = Colisee.LEVEL
	Run.max_level = Colisee.LEVEL
	p.recalc_stats()
	p.hp = p.max_hp
	TeamMatch.add(p, TeamMatch.player_team, 0)
	p.died.connect(_on_down.bind(p))
	d._place_player(arenas[0].spawn_point(0, 0, map))
	d.zone_changed.emit({"name": TeamMatch.title(), "levels": [Colisee.LEVEL, Colisee.LEVEL]})
	_log("partie : %s, %d équipes, difficulté %s, trios %s" % [g.format, g.n, Colisee.DIFFS[g.diff], str(g.classes)])
	ColiseeAugments.start()  # (lots CO-E / CO-F) atouts, or, enclumes, sorts : une construction par héros
	if ColiseeBuild.all_of(g).is_empty():
		ColiseeAnvil.setup(g)
	_begin_round()


## Réglages du banc IA contre IA lus sur la ligne de commande (voir [member coach_levels]) ; --co-watch tire aussi le trio
## du joueur au hasard (aucune classe imposée).
func _read_bench_args() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg == "--co-watch" and not watch_only:
			watch_only = true
			g.classes = Colisee.compose_teams(g.n, "", g.rng)
		elif arg == "--co-even":
			even_sheets = true
		elif arg.begins_with("--co-coach="):
			coach_levels = Array(arg.trim_prefix("--co-coach=").split(",")).map(func(x): return int(x))
		elif arg.begins_with("--co-diffs="):
			var ds: Array = Array(arg.trim_prefix("--co-diffs=").split(",")).map(func(x): return clampi(int(x), 0, 3))
			for t in g.n:
				g.team_diffs[t] = int(ds[t % ds.size()])
		elif arg.begins_with("--co-rule="):  # essai : réglage du profil « colisee » (clé:valeur, ex. dmg_scale:0.04)
			var kv := arg.trim_prefix("--co-rule=").split(":")
			var prof: Dictionary = (ModeRules._extra.get(Colisee.MODE, Colisee.PROFILE) as Dictionary).duplicate()
			prof[kv[0]] = float(kv[1])
			ModeRules._extra[Colisee.MODE] = prof
		elif arg.begins_with("--co-tune="):  # essai : réglage du chef (clé de ColiseeCoach.LEVELS, ou attention)
			var kv := arg.trim_prefix("--co-tune=").split(":")
			if kv[0] == "attention":
				ColiseeCoach.attention = float(kv[1])
			elif kv[0] == "read_cap":
				ColiseeCoach.read_cap = float(kv[1])
			else:
				ColiseeCoach.tune[kv[0]] = (kv[1] == "true") if kv[1] in ["true", "false"] else float(kv[1])


## Niveau du chef de l'équipe [param t] (-1 : aucun chef).
func coach_level(t: int) -> int:
	if t >= 0 and t < coach_levels.size():
		return int(coach_levels[t])
	return int(g.team_diffs[t])


## Arènes de la carte : un combat par paire d'équipes (Classique 3, Éclair 2, Grand tournoi 4).
func arena_count() -> int:
	return maxi(1, int(g.n / 2))


## Préchargement (sur un fil du moteur) des modèles des classes de la partie : l'apparition d'une manche ne lit plus le disque.
static func prepare(game: Colisee) -> int:
	var n := 0
	for trio in game.classes:
		for cid in trio:
			var cls := GameData.class_data(String(cid))
			var paths: Array = [String(cls.get("body_model", cls.get("model", "")))] + (cls.get("parts", []) as Array)
			var w: Dictionary = EdenModel.weapon_entry(cls, "")
			for k in w:
				if w[k] is String and String(w[k]).ends_with(".glb"):
					paths.append(String(w[k]))
			for path in paths:
				var sp := String(path)
				if sp != "" and ResourceLoader.exists(sp) and not ResourceLoader.has_cached(sp):
					if ResourceLoader.load_threaded_request(sp) == OK:
						n += 1
	return n


func _verbose() -> bool:
	return d.player.autoplay or probe or "--auto-quit" in OS.get_cmdline_user_args()


func _log(s: String) -> void:
	log_lines.append(s)
	if _verbose():
		print("[colisee] " + s)


# --- manche ------------------------------------------------------------------------------------------------------------

func _begin_round() -> void:
	_clear_heroes()
	var r := g.next_round()
	ColiseeAugments.reset_round()
	ColiseeAnvil.round_start(g, d.player.autoplay or probe)  # (lots CO-E / CO-F) or, offres ; les IA choisissent
	TeamMatch.start_round()
	TeamMatch.set_phase("prep")
	fights = []
	var k := 0
	for pr in r.pairs:
		var a := int(pr[0])
		var b := int(pr[1])
		if b == TeamMatch.player_team:
			var tmp := a
			a = b
			b = tmp  # l'équipe du joueur toujours du côté 0 (devant la caméra)
		fights.append(_make_fight(k, a, b))
		k += 1
	# combat regardé : celui du joueur, sinon le premier
	watched = 0
	for i in fights.size():
		if int(fights[i].a) == TeamMatch.player_team:
			watched = i
	_place_player_for_round()
	_queue = []
	for i in fights.size():
		for side in 2:
			for j in Colisee.SIZE:
				_queue.append([i, side, j])
	_queue.sort_custom(func(x, y): return int(x[0]) == watched and int(y[0]) != watched)
	var t0 := Time.get_ticks_usec()
	_spawn_some(INF, true)
	spawn_ms = float(Time.get_ticks_usec() - t0) / 1000.0
	_set_watch(watched)  # (après l'apparition du combat regardé : la caméra a une cible de cette manche)
	_player_out = false
	_done_t = -1.0
	phase = "prep"
	_t = 0.0 if probe else (PREP_AUTO if d.player.autoplay else PREP)
	_open_prep_page()
	PvpCaps.board = {}
	var f: Dictionary = fights[watched]
	var vs := "%s contre %s" % [TeamMatch.team_name(int(f.a)), TeamMatch.team_name(int(f.b))]
	if int(r.bye) == TeamMatch.player_team:
		d.message.emit("Manche %d · ton trio est exempt : tu regardes %s" % [r.n, vs], 2.5)
	elif not TeamMatch.is_out(TeamMatch.player_team):
		d.message.emit("Manche %d · %s" % [r.n, vs], 2.0)
	_log("manche %d : %s ; exempt %s ; perte %d" % [r.n, str(r.pairs), str(r.bye), int(r.loss)])


func _make_fight(k: int, a: int, b: int) -> Dictionary:
	var arena: ColiseeArena = arenas[k]
	arena.reset([])
	return {"index": k, "arena": arena, "a": a, "b": b, "heroes": [[], []], "max_hp": [0.0, 0.0], "ko": [0, 0], "t": 0.0,
		"done": false, "winner": -1, "result": {}, "mode": "real", "pending": Colisee.SIZE * 2,
		"coach": [null, null], "first_hit": -1.0, "out": [0.0, 0.0], "flowers": [0, 0], "ids": [[], []]}


## Le joueur : dans son combat (côté 0), ou au repos (exempt, éliminé) sans corps ni contrôle.
func _place_player_for_round() -> void:
	var p := d.player
	var mine := -1
	for i in fights.size():
		if int(fights[i].a) == TeamMatch.player_team and not watch_only:
			mine = i
	if mine >= 0:
		var arena: ColiseeArena = fights[mine].arena
		if p.is_dead:
			p.respawn(arena.spawn_point(0, 0, map))
		d._place_player(arena.spawn_point(0, 0, map))
		p.hp = p.max_hp
		p.health_changed.emit(p.hp, p.max_hp)
		p.skill_ready_at.clear()
		p.statuses.clear()
		p.heal_taken = 1.0
		p.arena_id = int(fights[mine].index)
		_apply_player_build()
		p.visible = true
		p.set_physics_process(true)
		(fights[mine].heroes[0] as Array).append(p)
		(fights[mine].ids[0] as Array).append(p.get_instance_id())
		fights[mine].max_hp[0] = float(fights[mine].max_hp[0]) + p.max_hp
		fights[mine].pending = int(fights[mine].pending) - 1
	else:
		p.arena_id = PARK
		p.visible = false
		p.set_physics_process(false)
		d._place_player(map.start + Vector3.UP * 60.0)


func _spawn_some(budget: float, shown_only := false) -> void:
	var n := 0
	while not _queue.is_empty() and n < budget:
		var e: Array = _queue[0]
		var f: Dictionary = fights[int(e[0])]
		if shown_only and int(e[0]) != watched:
			break
		_queue.pop_front()
		var side := int(e[1])
		var j := int(e[2])
		var t := int(f.a) if side == 0 else int(f.b)
		if t == TeamMatch.player_team and j == 0 and not watch_only:
			continue  # le joueur lui-même (banc IA contre IA : un héros scripté à sa place)
		_spawn_hero(f, side, j, t)
		n += 1


func _spawn_hero(f: Dictionary, side: int, j: int, t: int) -> void:
	var cid := String(g.classes[t][j])
	var arena: ColiseeArena = f.arena
	var gb := ColiseeBuild.of(g, t, j)
	var r := TeamMatch.make_hero(cid, Colisee.LEVEL, int(g.team_diffs[t]), t, int(f.index), gb.gear if gb != null else {})
	if even_sheets:
		var k := float(ClassRival.DUEL_DIFF[r.difficulty])  # (banc : fiche égale, sans le facteur de difficulté)
		r.max_hp /= k
		r.hp = r.max_hp
		r.atk /= k
	r.passive = true
	add_child(r)
	r.global_position = arena.spawn_point(side, j, map) + Vector3.UP * 0.4
	r.look_at(Vector3(arena.center.x, r.global_position.y, arena.center.z), Vector3.UP)
	r.rotate_y(PI)
	r.died.connect(_on_down.bind(r))
	var bd := ColiseeBuild.of(g, t, j)
	if bd != null:  # (lots CO-E / CO-F) sa construction : atouts, bonus, sorts gagnés
		ColiseeAugments.apply_hero(r, bd, ColiseeBuild.team_of(g, t))
		ColiseeAnvil.grant_spells(r, bd)
	(f.heroes[side] as Array).append(r)
	(f.ids[side] as Array).append(r.get_instance_id())
	f.max_hp[side] = float(f.max_hp[side]) + r.max_hp
	f.pending = int(f.pending) - 1
	_apply_shown(r, int(f.index) == watched)


func _clear_heroes() -> void:
	for f in fights:
		for side in 2:
			for c in f.heroes[side]:
				if is_instance_valid(c) and c != d.player:
					TeamMatch.remove(c)
					(c as Node).queue_free()
	fights = []


func _ready_to_fight() -> bool:
	return _queue.is_empty() and fights.all(func(f): return int(f.pending) <= 0)


# --- image par image ---------------------------------------------------------------------------------------------------

func update(delta: float) -> void:
	TeamMatch.elapsed += delta
	var now := Time.get_ticks_usec()
	var frame := float(now - _last_us) / 1000.0 if _last_us > 0 else 0.0
	_last_us = now
	if not _queue.is_empty():
		var t0 := Time.get_ticks_usec()
		_spawn_some(SPAWN_PER_FRAME)
		spawn_ms += float(Time.get_ticks_usec() - t0) / 1000.0
	_t -= delta
	match phase:
		"prep":
			if _player_ready():
				_t = minf(_t, 0.2)  # (lot CO-F) le joueur est prêt
			if _t <= 0.0 and _ready_to_fight():
				_end_prep()
				phase = "countdown"
				_t = 0.2 if probe else Colisee.COUNTDOWN
				TeamMatch.set_phase("countdown")
		"countdown":
			var n := ceili(_t)
			if n != ceili(_t + delta) and n > 0 and not probe:
				d.message.emit(str(n), 0.8)
				UiFeel.cue("ui_tick", -8.0)
			if _t <= 0.0:
				_start_fights()
		"fight":
			if probe:
				frame_ms.append(frame)
			PvpCaps.elapsed += delta
			_fight_tick(delta, frame)
		"recap":
			if _t <= 0.0:
				_close_round()
	if phase == "fight":
		_follow()
	_obj_t -= delta
	if _obj_t <= 0.0:
		_obj_t = 0.25
		d.objective_changed.emit(_objective())


func _start_fights() -> void:
	phase = "fight"
	TeamMatch.set_phase("fight")
	PvpCaps.elapsed = 0.0
	_slow = 0.0
	for f in fights:  # (PV max relus : la fiche a pu changer pendant la préparation)
		for side in 2:
			f.max_hp[side] = 0.0
			for c in f.heroes[side]:
				if is_instance_valid(c):
					f.max_hp[side] = float(f.max_hp[side]) + (c as Combatant).max_hp
	ColiseeAugments.begin_fight(self, fights)  # (lot CO-E) Bouclier d'entrée, Ombre jumelle, fleurs
	for f in fights:
		for side in 2:
			for c in f.heroes[side]:
				if is_instance_valid(c) and c is ClassRival:
					(c as ClassRival).passive = false
			var t := int(f.a) if side == 0 else int(f.b)
			var lv := coach_level(t)
			if lv >= 0:  # (lot CO-D) chef d'équipe du trio dans ce combat
				f.coach[side] = ColiseeCoach.new(lv, f.arena, f.heroes[side], f.heroes[1 - side], side, g.rng.randi())
	if not probe:
		d.message.emit("COMBAT !", 1.0)
		UiFeel.cue("ui_go", -8.0)


func _alive(f: Dictionary, side: int) -> Array:
	return (f.heroes[side] as Array).filter(func(c): return is_instance_valid(c) and not (c as Combatant).is_dead)


func _fight_tick(delta: float, frame: float) -> void:
	ColiseeAugments.tick(delta)  # (lot CO-E)
	# repli : images trop longues pendant FALLBACK_AFTER s réelles -> combats cachés résolus au tableau
	if not probe and fallback and PvpCaps.elapsed > FALLBACK_GRACE and frame > 0.0:
		if frame > FALLBACK_MS:
			_slow += frame / 1000.0
			if _slow >= FALLBACK_AFTER:
				_slow = 0.0
				for f in fights:
					if not f.done and int(f.index) != watched:
						_resolve_board(f)
		else:
			_slow = maxf(0.0, _slow - 2.0 * frame / 1000.0)
	for f in fights:
		if f.done:
			continue
		f.t = float(f.t) + delta
		var al_a := _alive(f, 0)
		var al_b := _alive(f, 1)
		(f.arena as ColiseeArena).tick(delta, al_a + al_b)
		for side in 2:
			if f.coach[side] != null:
				var co := f.coach[side] as ColiseeCoach
				co.period = ColiseeCoach.TICK if int(f.index) == watched else ColiseeCoach.TICK_HIDDEN
				co.tick(delta)
		_note_fight(f, delta, al_a, al_b)
		al_a = _alive(f, 0)
		al_b = _alive(f, 1)
		if probe:
			continue
		if al_a.is_empty() or al_b.is_empty():
			var w := -1
			if not al_a.is_empty():
				w = int(f.a)
			elif not al_b.is_empty():
				w = int(f.b)
			_end_fight(f, w)
		elif float(f.t) >= Colisee.FIGHT_TIME:
			_end_fight(f, -1)
	if fights.all(func(x): return x.done):
		ColiseeAugments.end_fight()
		phase = "recap"
		_t = RECAP
		TeamMatch.set_phase("recap")


## Mesures du banc (lot CO-D) : premier coup entre les trios, secondes passées hors de l'anneau par camp.
func _note_fight(f: Dictionary, delta: float, al_a: Array, al_b: Array) -> void:
	var ring: ColiseeRing = (f.arena as ColiseeArena).ring
	var lists := [al_a, al_b]
	for side in 2:
		for c in lists[side]:
			if ring.is_outside(c):
				f.out[side] = float(f.out[side]) + delta
	if float(f.first_hit) < 0.0 and (_dealt(f, 0) > 0.0 or _dealt(f, 1) > 0.0):
		f.first_hit = float(f.t)


func _on_flower(c: Combatant, arena_index: int) -> void:
	for f in fights:
		if int(f.index) != arena_index or f.done:
			continue
		for side in 2:
			if c in (f.heroes[side] as Array):
				f.flowers[side] = int(f.flowers[side]) + 1


## Dégâts infligés par le camp [param side] pendant le combat (tableau de manche PvpCaps.board).
func _dealt(f: Dictionary, side: int) -> float:
	var s := 0.0
	for id in f.ids[side]:
		s += float(PvpCaps.board.get(int(id), {}).get("dealt", 0.0))  # (par id : un héros tombé est libéré avant la fin)
	return s


## Part des PV du camp [param side] encore debout (égalité au temps).
func _left(f: Dictionary, side: int) -> float:
	var s := 0.0
	for c in _alive(f, side):
		s += (c as Combatant).hp
	return s / maxf(float(f.max_hp[side]), 1.0)


func _end_fight(f: Dictionary, winner: int) -> void:
	f.done = true
	f.winner = winner
	f.result = {"a": int(f.a), "b": int(f.b), "winner": winner, "left_a": _left(f, 0), "left_b": _left(f, 1),
		"ko_a": int(f.ko[0]), "ko_b": int(f.ko[1]), "time": snappedf(float(f.t), 0.1), "mode": f.mode}
	f.result.merge(_bench_fields(f))
	for side in 2:
		for c in f.heroes[side]:
			if is_instance_valid(c) and c is ClassRival:
				(c as ClassRival).passive = true
				(c as ClassRival).coach_order = {}
		f.coach[side] = null
	var mine := int(f.a) == TeamMatch.player_team
	var w := int(f.result.get("winner", -1))
	if w < 0:
		w = Colisee.tie_winner(float(f.result.left_a), float(f.result.left_b), int(f.a), int(f.b))
	if mine:
		_done_t = 0.0
		var loss := g.loss_at()
		if w == TeamMatch.player_team:
			d.message.emit("Manche gagnée · %s −%d" % [TeamMatch.team_name(int(f.b)), loss], 2.5)
			UiFeel.cue("reward_1", -6.0)
		elif w < 0:
			d.message.emit("Égalité · les deux trios −%d" % ceili(loss * 0.5), 2.5)
		else:
			d.message.emit("Manche perdue · %s −%d" % [TeamMatch.team_name(TeamMatch.player_team), loss], 2.5)
	_log("combat %s contre %s : %s en %.1f s (%s, PV restants %.2f / %.2f, K.O. %d-%d)" % [TeamMatch.team_name(int(f.a)),
		TeamMatch.team_name(int(f.b)), ("égalité" if w < 0 else TeamMatch.team_name(w)), float(f.t), f.mode,
		float(f.result.left_a), float(f.result.left_b), int(f.ko[0]), int(f.ko[1])])


## Champs de mesure d'un combat (banc tools/colisee_games, lot CO-D) : manche, difficultés, chefs, classes, premier coup,
## dégâts, secondes dans le feu, fleurs prises, décisions des chefs.
func _bench_fields(f: Dictionary) -> Dictionary:
	var a := int(f.a)
	var b := int(f.b)
	var cs := []
	for side in 2:
		var co = f.coach[side]
		cs.append((co as ColiseeCoach).stats.duplicate() if co != null else {})
	return {"round": g.round_n, "arena": int(f.index), "diff_a": int(g.team_diffs[a]), "diff_b": int(g.team_diffs[b]),
		"coach_a": coach_level(a), "coach_b": coach_level(b), "cls_a": g.classes[a], "cls_b": g.classes[b],
		"first_hit": snappedf(float(f.first_hit), 0.1), "dealt_a": roundf(_dealt(f, 0)), "dealt_b": roundf(_dealt(f, 1)),
		"out_a": snappedf(float(f.out[0]), 0.1), "out_b": snappedf(float(f.out[1]), 0.1), "flowers_a": int(f.flowers[0]),
		"flowers_b": int(f.flowers[1]), "chef_a": cs[0], "chef_b": cs[1]}


## Repli « au tableau » d'un combat caché encore en cours (PV × frappe des héros debout).
func _resolve_board(f: Dictionary) -> void:
	if f.done:
		return
	var s := Colisee.resolve_board(_alive(f, 0), _alive(f, 1))
	f.mode = "tableau"
	fallbacks += 1
	_log("repli au tableau : combat %d après %.1f s" % [int(f.index), float(f.t)])
	_end_fight(f, int(f.a) if s == 0 else (int(f.b) if s == 1 else -1))


func _on_down(victim: Combatant, killer: Combatant, who: Combatant) -> void:
	if phase != "fight":
		return
	TeamMatch.note_ko(victim, killer)
	for f in fights:
		for side in 2:
			if who in (f.heroes[side] as Array):
				f.ko[1 - side] = int(f.ko[1 - side]) + 1
				if killer != null and is_instance_valid(killer):
					PvpCaps.board_add(killer, "ko", 1)


# --- fin de manche, fin de partie ----------------------------------------------------------------------------------------

func _close_round() -> void:
	var results: Array = []
	for f in fights:
		results.append(f.result)
	var info := {"fights": results}
	var mine := -1
	for f in fights:
		if int(f.a) == TeamMatch.player_team:
			mine = int(f.result.get("winner", -1))
	TeamMatch.end_round(mine, info)
	var elim := g.report(results)
	for e in elim:
		var place := TeamMatch.eliminate(int(e[0]))
		_log("%s éliminés · %de (PV %d)" % [TeamMatch.team_name(int(e[0])), int(e[1]), int(g.hp[int(e[0])])])
		if place != int(e[1]) and place != 0:
			push_warning("Colisée : place %d (TeamMatch) contre %d (machine)" % [place, int(e[1])])
		if int(e[0]) == TeamMatch.player_team:
			d.message.emit("Ton trio est éliminé · %de" % int(e[1]), 3.0)
		else:
			d.message.emit("%s éliminés · %de" % [TeamMatch.team_name(int(e[0])), int(e[1])], 2.0)
	var hp_line := []
	for t in g.n:
		hp_line.append("%s %d" % [TeamMatch.team_name(t), int(g.hp[t])])
	_log("PV des équipes : " + ", ".join(hp_line))
	if g.is_over():
		_finish()
		return
	_begin_round()


func _finish() -> void:
	phase = "done"
	TeamMatch.set_phase("done")
	_clear_heroes()
	var res := TeamMatch.result()
	var minutes := float(Time.get_ticks_msec() - started_ms) / 60000.0
	var place := int(res.place)
	print("[colisee] fin : place %d / %d (%s), %d manches, %.1f min réelles, %.1f min de jeu, replis au tableau %d" % [place, g.n,
		"victoire" if bool(res.won) else "défaite", g.round_n, minutes, TeamMatch.elapsed / 60.0, fallbacks])
	if _verbose():
		print("[colisee] partie " + JSON.stringify(summary(minutes)))
	Vfx.hidden_arenas = {}
	ColiseeAugments.stop()
	Colisee.finish()  # TeamMatch.end() avant toute récompense (piège 11 de R_MODE0) ; récompenses : lot CO-H
	if "--auto-quit" in OS.get_cmdline_user_args():
		get_tree().quit()
		return
	var title := "VICTOIRE !" if bool(res.won) else "DÉFAITE"
	var panel := ResultsPanel.new()
	d.world.add_child(panel)
	panel.show_spec({"title": "%de · %s" % [place, title], "tone": "win" if bool(res.won) else "lose",
		"subtitle": "Le Colisée · %s" % Colisee.FORMATS[g.format].name,
		"tiles": [["%d / %d" % [place, g.n], "place"], [str(g.round_n), "manches"], [str(int(g.round_wins[0])), "manches gagnées"]],
		"buttons": [{"text": "Menu principal", "primary": true, "call": _to_lobby}]})


# --- préparation (lots CO-E / CO-F) -------------------------------------------------------------------------------------

## Construction du joueur posée sur son héros (atouts, bonus, pièces portées par Profile.equipped).
func _apply_player_build() -> void:
	var pb := ColiseeBuild.player_build(g)
	if pb != null and pb.is_player:
		ColiseeAugments.apply_hero(d.player, pb, ColiseeBuild.team_of(g, TeamMatch.player_team))


func _player_ready() -> bool:
	var pb := ColiseeBuild.player_build(g)
	return prep_page != null and is_instance_valid(prep_page) and pb != null and pb.ready


func _open_prep_page() -> void:
	var pb := ColiseeBuild.player_build(g)
	if not prep_ui or probe or d.player.autoplay or DisplayServer.get_name() == "headless" or pb == null:
		return
	if TeamMatch.is_out(TeamMatch.player_team):
		return
	_t = maxf(_t, float(g.fmt.get("prep", 30.0)))
	prep_page = ColiseePrepPage.open(d.world, g, pb, d.player)


## Fin de la préparation : ce qui attend encore le joueur prend la meilleure option ; sa fiche est refaite.
func _end_prep() -> void:
	ColiseeAnvil.auto_finish(g)
	if prep_page != null and is_instance_valid(prep_page):
		prep_page.queue_free()
	prep_page = null
	if d.player.arena_id != PARK:
		_apply_player_build()


## Bilan de la partie pour le banc (une ligne JSON) : réglages, trios, places, durée, et tous les combats de la machine.
func summary(real_minutes := 0.0) -> Dictionary:
	var fams: Array = []
	var levels: Array = []
	for t in g.n:
		fams.append((g.classes[t] as Array).map(func(c): return Duel.family_of(String(c))))
		levels.append(coach_level(t))
	var fights_out: Array = []
	for h in g.history:
		for r in h.results:
			fights_out.append(r)
	return {"seed": int(g.rng.seed), "format": g.format, "teams": g.n, "diffs": g.team_diffs, "coach": levels,
		"even": even_sheets, "watch": watch_only, "classes": g.classes, "families": fams, "places": g.place, "rounds": g.round_n,
		"game_min": snappedf(TeamMatch.elapsed / 60.0, 0.01), "real_min": snappedf(real_minutes, 0.01), "fallbacks": fallbacks,
		"version": Version.NUMBER, "fights": fights_out}


func _to_lobby() -> void:
	Run.active = false
	Profile.in_run = false
	Profile.reload_keep_records()
	get_tree().paused = false
	LoadScreen.to_lobby(get_tree())  # (lot PERF-1 : écran de chargement)


# --- regarder ------------------------------------------------------------------------------------------------------------

## Regarde le combat [param i] : ses héros, son anneau et ses fleurs sont rendus ; les autres arènes sont cachées.
func watch(i: int) -> void:
	_set_watch(clampi(i, 0, maxi(0, fights.size() - 1)))


func next_watch(step := 1) -> void:
	var running: Array = []
	for f in fights:
		if not f.done:
			running.append(int(f.index))
	if running.is_empty():
		return
	var k := running.find(watched)
	watch(running[posmod(k + step, running.size()) if k >= 0 else 0])


func _set_watch(i: int) -> void:
	watched = i
	var hidden := {}
	for a in arenas:
		var on: bool = int((a as ColiseeArena).index) == i
		(a as ColiseeArena).set_shown(on)
		if not on:
			hidden[int((a as ColiseeArena).index)] = true
	Vfx.hidden_arenas = hidden
	for f in fights:
		for side in 2:
			for c in f.heroes[side]:
				if is_instance_valid(c) and c != d.player:
					_apply_shown(c, int(f.index) == i)
	var tgt := _first_alive(i)
	if tgt != null and d.world.rig != null:
		d.world.rig.target = tgt
		d.world.rig.global_position = tgt.global_position
		TeamMatch.spectate(tgt)


func _apply_shown(c: Combatant, on: bool) -> void:
	c.visible = on
	if c.anim:
		c.anim.active = on


func _first_alive(i: int) -> Combatant:
	if i < 0 or i >= fights.size():
		return null
	var f: Dictionary = fights[i]
	if d.player in (f.heroes[0] as Array) and not d.player.is_dead:
		return d.player
	for side in 2:
		for c in _alive(f, side):
			return c
	return null


## Caméra : le joueur tombé suit un allié de son combat ; combat fini (ou trio éliminé) : le combat le plus long encore en cours.
func _follow() -> void:
	if d.world.rig == null or fights.is_empty():
		return
	var f: Dictionary = fights[watched]
	var tgt = d.world.rig.target  # (non typé : la cible d'une manche finie peut être libérée)
	if f.done:
		if _done_t >= 0.0:
			_done_t += get_process_delta_time()
		var mine_over := TeamMatch.is_out(TeamMatch.player_team) or int(f.a) != TeamMatch.player_team or _done_t >= FOLLOW_SWITCH
		if mine_over:
			var best := -1
			var best_t := -1.0
			for x in fights:
				if not x.done and float(x.t) > best_t:
					best_t = float(x.t)
					best = int(x.index)
			if best >= 0:
				_set_watch(best)
				d.message.emit("Ailleurs : %s contre %s" % [TeamMatch.team_name(int(fights[best].a)), TeamMatch.team_name(int(fights[best].b))], 2.0)
		return
	if not is_instance_valid(tgt) or not tgt is Combatant or (tgt as Combatant).is_dead:
		var nxt := _first_alive(watched)
		if nxt != null:
			d.world.rig.target = nxt
			TeamMatch.spectate(nxt)


## Horloge du HUD (Hud._update_objectives, état « team ») : la manche et le temps du combat regardé.
func clock_text() -> String:
	if g == null or fights.is_empty():
		return TeamMatch.title()
	match phase:
		"prep":
			return "Manche %d · préparation" % g.round_n
		"countdown":
			return "Manche %d" % g.round_n
		"fight":
			var t := float(fights[watched].t)
			return "Manche %d · %d:%02d" % [g.round_n, int(t) / 60, int(t) % 60]
		"recap":
			return "Manche %d · fin" % g.round_n
	return "Fin de la partie"


## Ligne sous le titre du HUD : PV de ton trio, ou le combat regardé si tu n'y es pas ; « Feu · n s » avant un resserrement.
func sub_text() -> String:
	if g == null or fights.is_empty() or phase == "done":
		return ""
	var f: Dictionary = fights[watched]
	var line := ""
	if TeamMatch.is_out(TeamMatch.player_team):
		line = "Spectateur · %s contre %s" % [TeamMatch.team_name(int(f.a)), TeamMatch.team_name(int(f.b))]
	elif int(f.a) != TeamMatch.player_team:
		line = "Ailleurs : %s contre %s · ton trio %d PV" % [TeamMatch.team_name(int(f.a)), TeamMatch.team_name(int(f.b)), int(g.hp[TeamMatch.player_team])]
	else:
		line = "%s · ton trio %d PV" % [(f.arena as ColiseeArena).title(), int(g.hp[TeamMatch.player_team])]
	var warn := ""
	if phase == "fight" and not f.done:
		var nx := (f.arena as ColiseeArena).ring.next_info()
		if not nx.is_empty() and float(nx["in"]) <= ColiseeRing.WARN:
			warn = " · Feu · %d s" % ceili(float(nx["in"]))
	if warn == "" and int(f.a) == TeamMatch.player_team and not TeamMatch.is_out(TeamMatch.player_team):
		warn = " · contre %s" % TeamMatch.team_name(int(f.b))  # (l'annonce du feu passe avant : la ligne tient en 1280 × 720)
	return line + warn


func _objective() -> String:
	if fights.is_empty() or phase == "done":
		return TeamMatch.title()
	var f: Dictionary = fights[watched]
	var a: ColiseeArena = f.arena
	var line := "Manche %d · %s · PV %d" % [g.round_n, a.title(), int(g.hp[TeamMatch.player_team])]
	if phase == "fight" and not f.done:
		var nx := a.ring.next_info()
		if not nx.is_empty() and float(nx["in"]) <= ColiseeRing.WARN:
			line += " · Feu · %d s" % ceili(float(nx["in"]))
	return line


## Mort du joueur (world.gd) : ses alliés continuent ; la caméra suit l'un d'eux.
func player_down(_killer: Combatant) -> void:
	if phase != "fight":
		return
	_player_out = true
	d.message.emit("Tu es tombé : tes alliés se battent encore !", 2.5)


## Abandon (menu pause) : l'équipe du joueur quitte la partie à la dernière place encore en jeu.
func abandon() -> void:
	if phase == "done":
		return
	if not TeamMatch.is_out(TeamMatch.player_team):
		g.hp[TeamMatch.player_team] = -999
		g.out[TeamMatch.player_team] = true
		g.place[TeamMatch.player_team] = g.alive().size() + 1
		TeamMatch.eliminate(TeamMatch.player_team)
	_log("abandon")
	_clear_heroes()
	Vfx.hidden_arenas = {}
	ColiseeAugments.stop()
	phase = "done"
	Colisee.finish()
	if "--auto-quit" in OS.get_cmdline_user_args():
		get_tree().quit()
		return
	if not abandon_stay:
		_to_lobby()


func _exit_tree() -> void:
	Vfx.hidden_arenas = {}
	ColiseeAugments.stop()
