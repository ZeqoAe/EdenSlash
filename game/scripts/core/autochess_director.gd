class_name AutochessDirector
extends Node3D
## L'Échiquier, lot AC-E : le directeur du COMBAT RÉEL (SPEC §3.3, §4.3, §8 ; rapport conception/autochess/R_AC_E.md).
## Il joue en même temps tous les combats d'une manche de la machine Autochess (AC-B) : un plateau par combat, posés à
## AutochessData.BOARD_SPACING m les uns des autres dans le même monde ; seul le plateau regardé est rendu (les autres :
## invisibles, sans effets, sons ni chiffres de dégâts). Unités = AutochessUnit (ai/autochess_unit.gd), camps en miroir à
## partir des plateaux de la machine (cases d'AutochessBoard), vérité du combat = la couche AutochessEffects (AC-H).
##
## Déroulé d'un combat : apparition (le plateau regardé d'abord, les autres SPAWN_PER_FRAME unités par image),
## AutochessEffects.start, puis à chaque image : positions (set_pos), temps de la couche (tick), miroir des PV ; fin quand un
## camp est à terre ; « Fureur » (mort subite) à AutochessData.SUDDEN_AT s (signal fury_started ; dégâts : la couche) ;
## égalité à draw_at s (profil « autochess » de ModeRules). Vitesse ×1 / ×2 : Engine.time_scale pendant le combat
## seulement (rendu à la fin). Repli : si l'image dépasse fallback_ms pendant fallback_after s, les plateaux cachés encore en
## cours sont finis par le combat de données (data_run, même couche d'effets).
##
## Utilisation :
##   var d := AutochessDirector.new(); add_child(d)     # mode « autochess » actif tant qu'il est dans l'arbre (owns_mode)
##   d.view = plateau (AutochessBoard, facultatif) ; d.camera = caméra (facultative)
##   var res := await d.play_round(partie)             # partie.phase == "combat" : combats réels, puis finish_combat(res)
##   (ou d.begin(fights, regardé) puis await d.round_finished ; d.watch(i) change de plateau regardé ; d.set_speed(2.0))
## Combat de données (instantané, injectable dans la machine à la place de power_fight) : AutochessDirector.data_fight.
## Fiche de base des unités (partagée avec le simulateur AC-C) : AutochessDirector.base_sheet.

signal arena_finished(index: int, result: Dictionary)  ## un combat est fini (résultat au format de la machine)
signal round_finished(results: Array)  ## tous les combats de la manche sont finis (même ordre que les combats)
signal fury_started(index: int)  ## la « Fureur » (mort subite) commence sur ce plateau

## Mode « autochess » en cours (Modes.current, Modes.sealed) : vrai tant qu'un directeur qui en a la charge est dans l'arbre.
static var active := false
## Vrai combat (sinon le lanceur peut jouer la manche par data_fight, instantané).
static var real_combat := true
## Vitesse du combat (×1 / ×2 / ×3), gardée entre les parties.
static var speed := 1.0
## Lot ACX-2 : stratège qui regarde (le joueur) : ses unités ont des barres pomme, l'adversaire fraise, quel que soit
## le camp (a ou b) du combat ; dans un combat des autres, le camp a est pomme. -1 : camp a toujours pomme.
static var viewer := 0
## Lot ACX-2 : chiffres sobres (BIBLE §10) : un coup sous cette part des PV max de la cible s'écrit petit et estompé.
const SMALL_HIT := 0.06

const HALF_X := 7.5  # m : demi-largeur du plateau (bords des cases, 7 colonnes de 2 m + décalage d'une demi-case)
const HALF_Z := 7.2  # m : demi-profondeur (8 rangées de 1,73 m + pointe des hexagones)
const FLOOR_Y := AutochessBoard.TOP  # dessus des cases : pieds des unités
const SPAWN_PER_FRAME := 3  # plateaux cachés : unités créées par image (création 18-48 ms par unité, R_AC2 §5 ; voir prepare)
## Lot PERF-1 (retour du joueur : gel à l'appui sur « Prêt ») : temps de création par image, au moins une unité. Le plateau
## regardé ne se crée plus d'un bloc dans l'image de Prêt (10 à 20 unités : 340-390 ms mesurés) : une unité ou deux par
## image, cachées, et les figurines de la préparation restent à l'écran jusqu'au départ du combat regardé.
const SPAWN_BUDGET_MS := 6.0
const TICK := 0.05  # s : pas de la couche d'effets
const FALLBACK_MS := 20.0  # image plus longue que ça…
const FALLBACK_AFTER := 2.0  # … pendant ce temps (s réelles) : plateaux cachés finis par le combat de données
const DATA_STEP := 0.1  # s : pas du combat de données
const DATA_MOVE := 4.0  # m/s : approche dans le combat de données
## Profil ModeRules « autochess » : dmg_scale = part des PV d'une unité de même coût qu'une auto-attaque retire avant défense
## (comme l'échelle du duel). DMG_REF = celle de la fiche par défaut de la couche (AutochessEffects.BASE_ATK / BASE_HP).
const DMG_REF := AutochessEffects.BASE_ATK / AutochessEffects.BASE_HP
const SPELL_MULT_RANGE := Vector2(1.5, 3.5)  # multiplicateur du sort signature (classes.json « mult ») borné
const CLASS_RATIO_RANGE := Vector2(0.8, 1.25)  # PV et attaque de la classe / moyenne des 60, bornés

var owns_mode := true  ## pose AutochessDirector.active à l'entrée dans l'arbre, l'enlève à la sortie
var view: AutochessBoard  ## plateau affiché (déplacé sur le combat regardé), facultatif
var camera: Camera3D  ## caméra cadrée sur le combat regardé, facultative
var arenas: Array = []  ## un dictionnaire par combat (voir _make_arena)
var results: Array = []
var watched := 0
var running := false
var fallback_ms := FALLBACK_MS  ## 0 : jamais de repli
var fallback_after := FALLBACK_AFTER
var spawn_per_frame := SPAWN_PER_FRAME
## Lot PERF-1 : apparition étalée (budget SPAWN_BUDGET_MS, fichiers lus en tâche de fond, plateau regardé compris). Faux sur
## un serveur sans écran (tests, bancs) : begin crée le plateau regardé tout de suite, comme avant.
var spread_spawn := DisplayServer.get_name() != "headless"
var base_origin := Vector3.ZERO  ## place du combat regardé (celle du plateau affiché s'il y en a un)
var budget_frames: Array = []  ## durée des images (ms réelles) pendant la manche : mesure du budget
var _queue: Array = []  # [arène, camp, indice] à créer
var _slow := 0.0
var _last_us := 0
var _view_home := Vector3.INF

static var _ref := {}  # moyennes des PV et de l'attaque de base des 60 classes
static var _monster_lists := {}


func _enter_tree() -> void:
	if owns_mode:
		active = true


func _exit_tree() -> void:
	if running:
		Engine.time_scale = 1.0
	if owns_mode:
		active = false


# --- Une manche ------------------------------------------------------------------------------------------------------
## Joue en vrai les combats de la manche de [param g] (phase « combat »), regarde le combat [param watch] (-1 : celui du
## joueur humain, sinon le premier), puis rend les résultats à la machine (finish_combat) et les renvoie.
func play_round(g: Autochess, watch := -1) -> Array:
	if g == null or g.phase != "combat":
		return []
	if watch < 0:
		watch = 0
		for i in g.fights.size():
			var a := int(g.fights[i].a)
			if a >= 0 and a < g.strategists.size() and g.strategists[a] == null:
				watch = i
				break
	begin(g.fights, watch)
	if running:
		await round_finished
	var res := results.duplicate(true)
	g.finish_combat(res)
	return res


## Lance les combats [param fights] (entrées de Autochess.fights : board_a, board_b, ctx) ; [param watch] = combat regardé.
func begin(fights: Array, watch := 0) -> void:
	clear()
	results = []
	results.resize(fights.size())
	watched = clampi(watch, 0, maxi(0, fights.size() - 1))
	if view != null and is_instance_valid(view):
		if _view_home == Vector3.INF:
			_view_home = view.global_position
		base_origin = _view_home
	var slot := 1
	for i in fights.size():
		var origin := base_origin
		if i != watched:
			origin = base_origin + Vector3(AutochessData.BOARD_SPACING * slot, 0.0, 0.0)
			slot += 1
		arenas.append(_make_arena(i, fights[i], origin, i == watched))
	if arenas.is_empty():
		round_finished.emit([])
		return
	running = true
	budget_frames = []
	_slow = 0.0
	_last_us = Time.get_ticks_usec()
	Engine.time_scale = speed
	# le plateau regardé tout de suite, les autres au fil des images
	for a in arenas:
		for side in 2:
			for k in (a.fight_boards[side] as Array).size():
				_queue.append([a, side, k])
	_queue.sort_custom(func(x, y): return bool(x[0].shown) and not bool(y[0].shown))
	if not spread_spawn:
		_spawn_some(INF, true)
	else:
		# (PERF-1) modèles de chaque unité (monstres compris) lus en tâche de fond tout de suite ; une unité n'est créée
		# qu'une fois ses fichiers lus (sinon sa lecture figeait l'image : 115-245 ms par monstre)
		for e in _queue:
			var a: Dictionary = e[0]
			var paths := unit_paths(a.fight_boards[e[1]][e[2]], int(a.seed) + int(a.ctx.sides[e[1]][e[2]]))
			for path in paths:
				_request(String(path))
			e.append(paths)
	_frame_camera()  # (PERF-1, spread_spawn : _physics_process crée les unités au fil des images, le plateau regardé d'abord)


## Lot ACX-2 : « Passer » : tous les combats encore en cours (le regardé compris) sont finis tout de suite par le combat
## de données (même couche d'effets, à partir de leur état du moment) ; round_finished part dans la foulée.
func skip() -> void:
	if not running:
		return
	for a in arenas:
		if not a.done:
			finish_by_data(a)
	if running and arenas.all(func(x): return x.done):
		_finish_round()


## Camp [param side] du combat [param a] vu par le stratège qui regarde (viewer) : vrai = « le sien » (barres pomme).
static func is_mine(a: Dictionary, side: int) -> bool:
	var f: Dictionary = a.get("fight", {})
	if viewer >= 0 and int(f.get("b", -2)) == viewer:
		return side == 1
	return side == 0


## Vitesse du combat (×1 / ×2 / ×3) : Engine.time_scale pendant le combat seulement.
func set_speed(s: float) -> void:
	speed = clampf(s, 0.25, 4.0)
	if running:
		Engine.time_scale = speed


## Regarde le combat [param i] : ses unités sont rendues, les autres cachées ; le plateau affiché et la caméra le suivent.
func watch(i: int) -> void:
	if i < 0 or i >= arenas.size():
		return
	watched = i
	for a in arenas:
		var on: bool = int(a.index) == i
		a["shown"] = on
		for side in 2:
			for n in a.nodes[side]:
				if is_instance_valid(n):
					(n as AutochessUnit).set_shown(on)
	if view != null and is_instance_valid(view):
		view.show_figures(false)  # (PERF-1 : sinon tenues jusqu'au départ du 1er plateau regardé)
	_frame_camera()


func _frame_camera() -> void:
	if arenas.is_empty() or watched >= arenas.size():
		return
	var o: Vector3 = arenas[watched].origin
	if view != null and is_instance_valid(view):
		view.global_position = o
		if camera != null:
			view.frame_camera(camera, 0)
	elif camera != null:
		camera.global_position = o + Vector3(0.0, 21.0, 18.0)
		camera.look_at(o, Vector3.UP)


## Retire les unités et les plateaux de la manche précédente.
func clear() -> void:
	for a in arenas:
		if is_instance_valid(a.root):
			(a.root as Node).queue_free()
	arenas = []
	_queue = []
	if running:
		running = false
		Engine.time_scale = 1.0
	if view != null and is_instance_valid(view) and _view_home != Vector3.INF:
		view.global_position = _view_home
		view.show_figures(true)


## Préchargement (pendant la préparation) des modèles des unités de la partie [param g] : corps, tenues et armes des
## classes de tous les plateaux et bancs, chargés sur un fil du moteur ; l'apparition du combat ne lit plus le disque.
## Lot PERF-1 : fichiers que lit la création d'une unité (classe : corps, tenues, armes ; monstre de [param pick] : modèle et
## texture), comme AutochessUnit.setup_unit.
static func unit_paths(u: Dictionary, pick: int) -> Array:
	var id := String(u.get("id", ""))
	if id == "":
		var m := monster_entry(u, pick)
		return ["res://assets/monsters/%s/%s.glb" % [m.model, m.model], "res://assets/monsters/textures/%s.png" % String(m.get("texture", ""))]
	var cls := GameData.class_data(id)
	var paths: Array = [String(cls.get("body_model", cls.get("model", "")))] + (cls.get("parts", []) as Array)
	var w: Dictionary = EdenModel.weapon_entry(cls, "")
	for k in w:
		if w[k] is String and String(w[k]).ends_with(".glb"):
			paths.append(String(w[k]))
	return paths


## Demande la lecture en tâche de fond de [param path] (rien s'il est déjà en mémoire ou en cours) ; vrai si demandée.
static func _request(path: String) -> bool:
	if path == "" or not ResourceLoader.exists(path) or ResourceLoader.has_cached(path):
		return false
	if ResourceLoader.load_threaded_get_status(path) != ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
		return false
	return ResourceLoader.load_threaded_request(path) == OK


static func prepare(g: Autochess) -> int:
	var ids := {}
	for p in g.players:
		for u in (p.board as Array) + (p.bench as Array):
			if u is Dictionary and String(u.get("id", "")) != "":
				ids[String(u.id)] = true
	var n := 0
	for id in ids:
		var cls := GameData.class_data(String(id))
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


# --- Plateaux ---------------------------------------------------------------------------------------------------------
func _make_arena(i: int, f: Dictionary, origin: Vector3, shown: bool) -> Dictionary:
	var fctx: Dictionary = f.get("ctx", {})
	var boards := [_placed(f.get("board_a", []), false), _placed(f.get("board_b", []), true)]
	var ctx := AutochessEffects.context(fctx, boards, func(u): return AutochessDirector.base_sheet(u))
	var root := Node3D.new()
	root.name = "Arena%d" % i
	add_child(root)
	root.global_position = origin
	_build_bounds(root)
	return {"index": i, "fight": f, "fight_boards": boards, "origin": origin, "ctx": ctx, "root": root, "nodes": [[], []],
		"by_fid": {}, "stats": {}, "pending": (boards[0] as Array).size() + (boards[1] as Array).size(), "running": false, "done": false,
		"t": 0.0, "acc": 0.0, "shown": shown, "mode": "real", "fury": false, "seed": int(fctx.get("seed", i)), "result": {}}


## Copie du plateau avec une case pour chaque unité (monstres et gardien : cases de devant, au centre).
static func _placed(board: Array, foe: bool) -> Array:
	var out: Array = []
	var k := 0
	for u in board:
		var c: Dictionary = (u as Dictionary).duplicate(true)
		if not (c.get("cell") is Array and (c.cell as Array).size() >= 2):
			c["cell"] = [3, 1] if c.get("guardian", false) else [[3, 1, 5, 2, 4, 0, 6][k % 7], int(k / 7)]
		k += 1
		out.append(c)
	return out


## Sol et murs du plateau (bornes physiques ; AutochessUnit borne aussi sa position).
func _build_bounds(root: Node3D) -> void:
	var floor_body := StaticBody3D.new()
	floor_body.collision_layer = GameData.PHYS_WORLD
	floor_body.collision_mask = 0
	var fs := CollisionShape3D.new()
	var fb := BoxShape3D.new()
	fb.size = Vector3(HALF_X * 2.0 + 8.0, 2.0, HALF_Z * 2.0 + 8.0)
	fs.shape = fb
	fs.position.y = FLOOR_Y - 1.0
	floor_body.add_child(fs)
	root.add_child(floor_body)
	for k in 4:
		var wall := StaticBody3D.new()
		wall.collision_layer = GameData.PHYS_WORLD
		wall.collision_mask = 0
		var ws := CollisionShape3D.new()
		var wb := BoxShape3D.new()
		var along_x := k < 2
		wb.size = Vector3(HALF_X * 2.0 + 2.0, 8.0, 1.0) if along_x else Vector3(1.0, 8.0, HALF_Z * 2.0 + 2.0)
		ws.shape = wb
		wall.add_child(ws)
		root.add_child(wall)
		var sgn := -1.0 if k % 2 == 0 else 1.0
		wall.position = Vector3(0.0, 4.0, sgn * (HALF_Z + 0.5)) if along_x else Vector3(sgn * (HALF_X + 0.5), 4.0, 0.0)


func _spawn_some(budget: float, shown_only := false) -> void:
	var n := 0
	var t0 := Time.get_ticks_usec()
	while not _queue.is_empty() and n < budget and (n == 0 or not spread_spawn or float(Time.get_ticks_usec() - t0) / 1000.0 < SPAWN_BUDGET_MS):
		var e: Array = _queue[0]
		var a: Dictionary = e[0]
		if shown_only and not a.shown:
			break
		if e.size() > 3 and not a.done and (e[3] as Array).any(func(p): return ResourceLoader.load_threaded_get_status(String(p)) == ResourceLoader.THREAD_LOAD_IN_PROGRESS):
			break  # (PERF-1) ses fichiers se lisent encore en tâche de fond : à une image suivante
		_queue.pop_front()
		if a.done:
			continue
		_spawn_unit(a, int(e[1]), int(e[2]))
		if e.size() > 3:
			for path in e[3]:
				if ResourceLoader.load_threaded_get_status(String(path)) == ResourceLoader.THREAD_LOAD_LOADED:
					ResourceLoader.load_threaded_get(String(path))  # (la tâche rend la ressource : plus rien ne la retient pour rien)
		n += 1
		a["pending"] = int(a.pending) - 1
		if int(a.pending) <= 0:
			_start_arena(a)
	for a in arenas:
		if int(a.pending) <= 0 and not a.running and not a.done:
			_start_arena(a)


func _spawn_unit(a: Dictionary, side: int, k: int) -> void:
	var u: Dictionary = a.fight_boards[side][k]
	var fid: int = a.ctx.sides[side][k]
	var n := AutochessUnit.new()
	n.ac_shown = a.shown
	n.setup_unit(u, side, fid, a, self)
	var cell: Array = u.cell
	var local := AutochessBoard.cell_position(int(cell[0]), int(cell[1]), side == 1)
	(a.root as Node3D).add_child(n)
	if a.shown and not a.running:
		n.visible = false  # (PERF-1 : montrées toutes ensemble au départ du combat, voir _start_arena)
	n.global_position = (a.origin as Vector3) + Vector3(local.x, FLOOR_Y, local.z)
	n.rotation.y = PI if side == 0 else 0.0  # face à l'adversaire (les modèles regardent vers +Z)
	a.nodes[side].append(n)
	a.by_fid[fid] = n


func _start_arena(a: Dictionary) -> void:
	if a.shown:  # (PERF-1) le plateau regardé est complet : ses unités remplacent les figurines de la préparation
		for side in 2:
			for u in a.nodes[side]:
				if is_instance_valid(u):
					(u as AutochessUnit).visible = (u as AutochessUnit).ac_shown
		if view != null and is_instance_valid(view):
			view.show_figures(false)
	a["running"] = true
	a["t"] = 0.0
	on_effects(a, AutochessEffects.start(a.ctx))
	if _over(a):
		_end_arena(a)


# --- Boucle -----------------------------------------------------------------------------------------------------------
func _physics_process(delta: float) -> void:
	if not running:
		return
	_spawn_some(spawn_per_frame)
	for a in arenas:
		if a.running and not a.done:
			_step_arena(a, delta)
	if arenas.all(func(x): return x.done):
		_finish_round()


func _step_arena(a: Dictionary, delta: float) -> void:
	var ctx: Dictionary = a.ctx
	var o: Vector3 = a.origin
	a["t"] = float(a.t) + delta
	a["acc"] = float(a.acc) + delta
	for side in 2:
		for n in a.nodes[side]:
			if is_instance_valid(n) and not n.is_dead:
				var p: Vector3 = (n as Node3D).global_position - o
				AutochessEffects.set_pos(ctx, int(n.ac_fid), Vector2(p.x, -p.z))
	if float(a.acc) >= TICK:
		var dt := float(a.acc)
		a["acc"] = 0.0
		on_effects(a, AutochessEffects.tick(ctx, dt))
	for side in 2:
		for n in a.nodes[side]:
			if is_instance_valid(n) and not n.is_dead:
				if not AutochessEffects.alive(ctx, int(n.ac_fid)):
					(n as AutochessUnit).ac_die(null)  # chute hors du journal (budget d'effets dépassé)
				else:
					(n as AutochessUnit).sync()
	if not a.fury and float(a.t) >= AutochessData.SUDDEN_AT:
		a["fury"] = true
		fury_started.emit(int(a.index))
	if _over(a):
		_end_arena(a)


func _over(a: Dictionary) -> bool:
	var ctx: Dictionary = a.ctx
	return AutochessEffects.living(ctx, 0).is_empty() or AutochessEffects.living(ctx, 1).is_empty() \
		or float(a.t) >= draw_at()


## Égalité (les deux camps debout) : profil « autochess » de ModeRules (AutochessData.DRAW_AT).
static func draw_at() -> float:
	return ModeRules.num("draw_at", AutochessData.DRAW_AT, "autochess")


func _end_arena(a: Dictionary) -> void:
	a["done"] = true
	a["running"] = false
	var r := AutochessEffects.result(a.ctx)
	r["duration"] = float(a.t)
	r["mode"] = String(a.mode)
	a["result"] = r
	results[int(a.index)] = r
	for side in 2:
		for n in a.nodes[side]:
			if is_instance_valid(n):
				(n as AutochessUnit).ac_stop()
	arena_finished.emit(int(a.index), r)


func _finish_round() -> void:
	running = false
	Engine.time_scale = 1.0
	round_finished.emit(results)


## Budget d'image et repli : plateaux cachés finis par le combat de données si la machine ne tient pas l'image.
func _process(_delta: float) -> void:
	if not running:
		return
	var now := Time.get_ticks_usec()
	var ms := (now - _last_us) / 1000.0
	_last_us = now
	budget_frames.append(ms)
	if fallback_ms <= 0.0:
		return
	if not _queue.is_empty():
		_slow = 0.0  # images d'apparition : pas une machine trop lente
		return
	_slow = _slow + ms / 1000.0 if ms > fallback_ms else 0.0
	if _slow >= fallback_after:
		_slow = 0.0
		for a in arenas:
			if not a.done and not a.shown:
				finish_by_data(a)
		if arenas.all(func(x): return x.done):
			_finish_round()


## Finit le combat [param a] par le combat de données (même couche d'effets, à partir de son état du moment).
func finish_by_data(a: Dictionary) -> void:
	if a.done:
		return
	a["mode"] = "data"
	_queue = _queue.filter(func(e): return e[0] != a)
	for side in 2:
		for n in a.nodes[side]:
			if is_instance_valid(n):
				(n as Node).queue_free()
		a.nodes[side] = []
	if not a.ctx.started:
		AutochessEffects.start(a.ctx)
	var r := data_run(a.ctx, float(a.t), draw_at())
	a["t"] = float(r.duration)
	a["done"] = true
	a["running"] = false
	r["mode"] = "data"
	a["result"] = r
	results[int(a.index)] = r
	arena_finished.emit(int(a.index), r)


# --- Effets de la couche ----------------------------------------------------------------------------------------------
## Traite les effets rendus par la couche pour le plateau [param a] : chiffres (plateau regardé), contrôles, chutes, sauts
## des Ombre, relances de sort ; puis le miroir des PV des unités touchées.
func on_effects(a: Dictionary, fx: Array) -> void:
	if fx.is_empty():
		return
	var touched := {}
	for e in fx:
		var kind := String(e.get("type", ""))
		var dst: AutochessUnit = _node(a, int(e.get("dst", -1)))
		if dst != null:
			touched[dst] = true
		match kind:
			"damage":
				if dst != null and a.shown and float(e.amount) >= 1.0:
					# chiffres sobres (lot ACX-2) : critiques en grand, coups modestes petits et estompés, rouges sur les siens
					var crit := bool(e.get("crit", false))
					var small := not crit and float(e.amount) < dst.max_hp * SMALL_HIT
					DamageNumber.spawn(dst, float(e.amount), crit, is_mine(a, dst.ac_side) and not small,
						small or bool(e.get("proc", false)))
					dst._on_damaged(float(e.amount), null)
			"heal":
				if dst != null and a.shown and float(e.amount) >= dst.max_hp * 0.04:
					DamageNumber.spawn_text(dst, "+%d" % int(round(float(e.amount))), AutochessHud.candy("pomme", 0))
			"dodge", "parry":
				if dst != null and a.shown:
					DamageNumber.spawn_text(dst, "Esquive" if kind == "dodge" else "Parade", AutochessHud.candy("lagon", 0))
			"cc":
				if dst != null and not dst.is_dead:
					dst.ac_stun(String(e.get("kind", "stun")), float(e.get("dur", 0.5)))
			"death":
				if dst != null:
					dst.ac_die(_node(a, int(e.get("src", -1))))
			"leap":
				_leap(a, _node(a, int(e.get("src", -1))))
			"recast":
				var s := _node(a, int(e.get("src", -1)))
				if s != null and not s.is_dead:
					s._ac_recast = true
	for n in touched:
		if is_instance_valid(n):
			(n as AutochessUnit).sync()


func _node(a: Dictionary, fid: int) -> AutochessUnit:
	var n: Variant = a.by_fid.get(fid)
	return n as AutochessUnit if n != null and is_instance_valid(n) else null


## Saut d'une Ombre sur l'arrière ennemi (début du combat) : derrière l'ennemi le plus reculé de son camp.
func _leap(a: Dictionary, n: AutochessUnit) -> void:
	if n == null or n.is_dead:
		return
	var o: Vector3 = a.origin
	var best: AutochessUnit = null
	for f in foes_of(n):
		var e := f as AutochessUnit
		# camp 0 en z positif : l'arrière adverse est vers les z négatifs (et l'inverse)
		if best == null or (e.global_position.z < best.global_position.z if n.ac_side == 0 else e.global_position.z > best.global_position.z):
			best = e
	if best == null:
		return
	var back := -1.0 if n.ac_side == 0 else 1.0
	var p := best.global_position + Vector3(0.0, 0.0, back * 1.2)
	var hx := HALF_X - AutochessData.BOARD_MARGIN
	var hz := HALF_Z - AutochessData.BOARD_MARGIN
	p.x = o.x + clampf(p.x - o.x, -hx, hx)
	p.z = o.z + clampf(p.z - o.z, -hz, hz)
	n.global_position = p
	n.face_direction(best.global_position - p, 1.0, 100.0)
	if a.shown:
		n.play(n._anim("jump", "jump01"), 0.05, 1.3, true)


## Ennemis vivants de l'unité [param n] (l'autre camp de son plateau).
func foes_of(n: AutochessUnit) -> Array:
	return _living(n.ac_arena, 1 - n.ac_side)


## Alliés vivants de l'unité [param n] (son camp, elle comprise).
func allies_of(n: AutochessUnit) -> Array:
	return _living(n.ac_arena, n.ac_side)


static func _living(a: Dictionary, side: int) -> Array:
	if a.is_empty():
		return []
	return (a.nodes[side] as Array).filter(func(x): return is_instance_valid(x) and not x.is_dead)


## Unités vivantes d'un camp d'un combat (lecture pour l'interface et les tests).
func units_of(index: int, side: int) -> Array:
	return _living(arenas[index], side) if index >= 0 and index < arenas.size() else []


# --- Fiches -----------------------------------------------------------------------------------------------------------
## Fiche de base d'une unité pour la couche d'effets (partagée avec le simulateur AC-C) : la fiche par défaut de la couche
## (rôle × coût × étoiles, mana et portée des données), avec les différences entre classes (PV et attaque de base de la
## classe rapportés à la moyenne des 60, bornés) et le vrai sort signature (multiplicateur borné × rang des étoiles) ;
## attaque et sort × dmg_scale du profil « autochess » / DMG_REF. Monstres et gardien : fiche de la couche × la même échelle.
static func base_sheet(u: Dictionary) -> Dictionary:
	var b := AutochessEffects.default_base(u)
	var k := ModeRules.num("dmg_scale", DMG_REF, "autochess") / DMG_REF
	var id := String(u.get("id", ""))
	if u.get("guardian", false) or u.has("monster") or id == "" or not GameData.classes.has(id):
		b["atk"] = float(b.atk) * k
		b["spell_base"] = float(b.get("spell_base", 0.0)) * k
		return b
	var cls := GameData.class_data(id)
	var base: Dictionary = cls.get("base", {})
	var magic := String(cls.get("dmg_type", "phys")) in ["mag", "magic"]
	var ref := _class_ref()
	var hp_k := clampf(float(base.get("hp", 1.0)) / float(ref.hp), CLASS_RATIO_RANGE.x, CLASS_RATIO_RANGE.y)
	var atk_k := clampf(float(base.get("matk" if magic else "atk", 1.0)) / float(ref.atk), CLASS_RATIO_RANGE.x, CLASS_RATIO_RANGE.y)
	b["hp"] = float(b.hp) * hp_k
	b["atk"] = float(b.atk) * atk_k * k
	var d := AutochessData.unit(id)
	var sig := AutochessUnit.skill_of(id, int(d.get("skill_id", 0)))
	var sm := clampf(float(sig.get("mult", AutochessEffects.BASE_SPELL)), SPELL_MULT_RANGE.x, SPELL_MULT_RANGE.y)
	b["spell_base"] = float(b.atk) * sm * AutochessData.spell_mult(int(u.get("stars", 1)))
	return b


static func _class_ref() -> Dictionary:
	if not _ref.is_empty():
		return _ref
	var hp := 0.0
	var atk := 0.0
	var n := 0
	for id in AutochessData.unit_ids():
		var cls := GameData.class_data(String(id))
		var base: Dictionary = cls.get("base", {})
		var magic := String(cls.get("dmg_type", "phys")) in ["mag", "magic"]
		hp += float(base.get("hp", 1.0))
		atk += float(base.get("matk" if magic else "atk", 1.0))
		n += 1
	_ref = {"hp": hp / maxf(n, 1), "atk": atk / maxf(n, 1)} if n > 0 else {"hp": 1.0, "atk": 1.0}
	return _ref


## Monstre d'Eden pour un monstre ou le gardien (modèle) : sbire = rang 2, élite = rang 3, gardien = boss (rang 6),
## tiré à [param pick] parmi ceux dont le modèle existe.
static func monster_entry(u: Dictionary, pick: int) -> Dictionary:
	var rank := 6 if u.get("guardian", false) else (3 if String(u.get("monster", "")) == "elite" else 2)
	if not _monster_lists.has(rank):
		var ids: Array = GameData.monsters.keys().filter(func(id): return int(GameData.monsters[id].get("rank", 0)) == rank)
		ids.sort()
		_monster_lists[rank] = ids.filter(func(id):
			var m := String(GameData.monsters[id].get("model", ""))
			return ResourceLoader.exists("res://assets/monsters/%s/%s.glb" % [m, m]))
	var list: Array = _monster_lists[rank]
	if list.is_empty():
		list = _monster_lists.get(2, [])
	if list.is_empty():
		return {"model": "m025", "texture": "m02501", "scale": 0.65}
	return GameData.monsters[list[absi(pick) % list.size()]]


# --- Combat de données (repli, combat injectable) -----------------------------------------------------------------------
## Combat de données de deux plateaux de la machine (même fiche, même couche d'effets, instantané) : injectable à la place
## de Autochess.power_fight (`partie.fight = AutochessDirector.data_fight`), et repli des plateaux cachés.
static func data_fight(board_a: Array, board_b: Array, fctx: Dictionary) -> Dictionary:
	var ctx := AutochessEffects.context(fctx, [_placed(board_a, false), _placed(board_b, true)],
		func(u): return AutochessDirector.base_sheet(u))
	AutochessEffects.start(ctx)
	return data_run(ctx, 0.0, draw_at())


## Joue le contexte d'effets [param ctx] (déjà commencé, positions du moment) de [param t_from] à la fin ou à
## [param t_end] s : chacun marche vers l'ennemi le plus proche, frappe au rythme de sa vitesse d'attaque à sa portée,
## lance son sort à mana pleine. Rôles simplifiés : le vrai simulateur (AC-C) le remplacera.
static func data_run(ctx: Dictionary, t_from: float, t_end: float) -> Dictionary:
	var t := t_from
	var timers := {}
	var ids: Array = (ctx.units as Dictionary).keys()
	while t < t_end - 0.0001:
		if AutochessEffects.living(ctx, 0).is_empty() or AutochessEffects.living(ctx, 1).is_empty():
			break
		AutochessEffects.tick(ctx, DATA_STEP)
		t += DATA_STEP
		for fid in ids:
			var u: Dictionary = ctx.units[fid]
			if not u.alive or AutochessEffects.disabled(ctx, fid):
				continue
			var foes := AutochessEffects.near(ctx, int(u.side), u.pos)
			if foes.is_empty():
				break
			if AutochessEffects.can_cast(ctx, fid):
				AutochessEffects.cast(ctx, fid)
				if String(AutochessData.unit(String(u.id)).get("spell_type", "")) == "soin":
					var low := -1
					for f in AutochessEffects.living(ctx, int(u.side)):
						if low < 0 or AutochessEffects.hp_frac(ctx.units[f]) < AutochessEffects.hp_frac(ctx.units[low]):
							low = f
					if low >= 0:
						AutochessEffects.spell_heal(ctx, fid, low, AutochessEffects.hp_max(ctx, low) * 0.25 * AutochessData.spell_mult(int(u.stars)))
				else:
					AutochessEffects.spell_hit(ctx, fid, foes[0])
				continue
			if AutochessEffects.dist(ctx, fid, foes[0]) > AutochessEffects.stat(ctx, fid, "reach"):
				var p: Vector2 = u.pos
				AutochessEffects.set_pos(ctx, fid, p.move_toward(ctx.units[foes[0]].pos, DATA_MOVE * DATA_STEP * AutochessEffects.stat(ctx, fid, "move")))
				continue
			timers[fid] = float(timers.get(fid, 0.0)) + DATA_STEP * AutochessEffects.stat(ctx, fid, "as")
			if float(timers[fid]) >= 1.0:
				timers[fid] = float(timers[fid]) - 1.0
				AutochessEffects.attack(ctx, fid, foes[0])
	var r := AutochessEffects.result(ctx)
	r["duration"] = t
	return r
