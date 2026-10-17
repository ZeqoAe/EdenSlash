class_name AutochessScreen
extends Node3D
## L'Échiquier (lot AC-G) : l'écran jouable (scenes/autochess.tscn). Monte le plateau (AC-F : AutochessBoard, curseur),
## le cadre (AutochessHud : boutique, traits, stratèges, frise, minuteur), les choix (AutochessChoicePanel, AutochessCarousel)
## et la partie (AC-B : Autochess) contre 7 stratèges au hasard (Autochess.RandomStrategist) avec le combat provisoire
## (Autochess.power_fight, montré COMBAT_SHOW s) : une partie complète se joue déjà de bout en bout, souris ou manette.
## Les lots suivants remplacent les stratèges (AC-D), le combat (AC-E / AC-C) et l'entrée / la fin (AC-I).
## Lot AC-V (mise en scène) : tout se joue dans l'arène du Duel (AutochessArena : décor, ciel, musique du duel ; le plateau
## y est tracé au sol, AutochessBoard.arena_style) ; le combat est le vrai combat (AutochessDirector, plateau du joueur
## regardé dans l'arène, les autres cachés), caméra large du combat (AutochessArena.combat_camera) ; durées réduites
## (config « fast », tests) : combat de données instantané (même couche d'effets).
##   godot --path game res://scenes/autochess.tscn [-- --seed=N --ac-resume --autoplay]
## Commandes : manette (UiNav sur le plateau et les panneaux, A prend / pose / achète, X maintenu vend, Y Prêt, LB XP,
## RB boutique, LT actualiser, RT verrou, Start pause) ; clavier 1-5 achète, D actualise, F XP, V verrou, E vend,
## Espace Prêt, Échap pause ; souris : clic ou glisser-déposer. Rapport : conception/autochess/R_AC_G.md.
## Lot AC-I (entrée et fin) : lancé depuis le lobby avec config.diff (0 Recrue … 3 Légende ; stratèges AutochessAi, mélange
## de la difficulté), la difficulté et les exploits vivent dans players[me].meta.aci (sauvegardés avec la partie). Fin :
## AutochessRewards.finish (hub remis, coffres d'apparence, titres, quêtes) puis le bilan commun (AutochessResults :
## Rejouer, Statistiques, Retour au lobby). Fiches de découverte ac_shop / ac_stars / ac_traits à la 1re rencontre.
##   godot --path game res://scenes/autochess.tscn -- --ac-diff=1 [--seed=N --autoplay --auto-quit]  (ligne « [autochess] fin »)

const COMBAT_SHOW := 3.0  # s (×1) : combat provisoire montré avant le bilan (power_fight est instantané)
const OPENING_RECAP := 0.6  # s : manches sans combat (ouverture, choix partagé)
const CAROUSEL_END := 1.2  # s : l'anneau reste ouvert une fois tous les choix faits
const AUTOPLAY_PREP := 0.4  # s de préparation au pilote automatique
const TRIGGER_ON := 0.6
## Noms des stratèges adverses (tirés à la graine de la partie : une partie reprise garde les mêmes).
const AI_NAMES := ["Aldric", "Bérénice", "Corentin", "Daphné", "Élouan", "Faustine", "Gauvain", "Héloïse", "Ysolde",
	"Perceval", "Mélisende", "Tristan", "Aliénor", "Baudouin"]

static var speed := 1  # vitesse du combat montré (×1 / ×2), gardée entre les parties
## Réglages de lancement (tests, AC-I) : seed, resume, save_path, autoplay, fast (durées réduites), real, diff (0-3 :
## stratèges AutochessAi et récompenses ; absent : stratèges au hasard, sans récompense), auto_quit.
static var config := {}
## Fiches de découverte de l'écran (Tutorial.CARDS), dans l'ordre où elles peuvent venir.
const TIPS := ["ac_shop", "ac_stars", "ac_traits"]

var game: Autochess
var board: AutochessBoard
var cursor: AutochessCursor
var camera: Camera3D
var hud: AutochessHud
var choice: AutochessChoicePanel
var carousel: AutochessCarousel
var cards: InfoCard
var me := 0
var identities: Array = []
var phase := ""  # côté écran : prep, combat, recap, over
var timer := 0.0
var timer_total := 0.0
var scouted := -1
var foe := -1
var autoplay := false
var fast := false
var save_path := Autochess.SAVE_PATH
## Lot AC-I : difficulté (-1 : stratèges au hasard, sans récompense), fin de partie (bilan commun), durée jouée.
var diff := -1
var auto_quit := false
var results: AutochessResults
var _pilot: Variant = null  # stratège du pilote automatique (Vétéran quand les adversaires sont des AutochessAi)
var _played := 0.0  # s de partie (temps réel, pauses exclues), gardées dans meta.aci.secs
## Lot AC-V : l'arène, le directeur du vrai combat, le combat du joueur (indice dans game.fights, son camp).
var arena: AutochessArena
var director: AutochessDirector
var real := false  # la manche en cours se joue en vrai (sinon : combat de données)
var real_combat := true  # config « real » (par défaut : vrai sauf durées réduites) : combats montrés en vrai
var my_fight := -1
var my_side := 0
var _real_done := false
var _stage_built := -1
## Lot AC-V : HUD par-dessus l'arène (barres d'équipe, compteur de dégâts) et statistiques façon TFT (bilan de manche,
## bilan de partie : cumul AutochessStats de tes héros, gardé le temps de la partie).
var team_bars: AutochessTeamBars
var meter: AutochessMeter
var recap: AutochessRecap
var game_stats := {}
var _data_ctx: Dictionary = {}  # contexte d'effets du combat du joueur, en combat de données
const RECAP_HOLD := 20.0  # s : le bilan de manche ouvert retient la manche suivante au plus ce temps

var _ui: CanvasLayer
var _top: CanvasLayer
var _dirty := true
var _counts := {}
var _phase_t := 0.0
var _phase_len := 0.0
var _choice_hidden := false
var _paused := false
var _cr_revealed := 0
var _cr_t := 0.0
var _cr_pick := -1.0  # s restantes pour choisir (-1 : pas encore ton tour)
var _cr_done := -1.0
var _items_before: Array = []
var _trig := [false, false]
var _combat_text := ""


func _ready() -> void:
	var cfg: Dictionary = config
	autoplay = bool(cfg.get("autoplay", false))
	fast = bool(cfg.get("fast", false))
	save_path = String(cfg.get("save_path", Autochess.SAVE_PATH))
	real_combat = bool(cfg.get("real", not fast))
	diff = int(cfg.get("diff", -1))
	auto_quit = bool(cfg.get("auto_quit", false))
	var seed_ := int(cfg.get("seed", 0))
	var resume := bool(cfg.get("resume", false))
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--seed="):
			seed_ = int(a.get_slice("=", 1))
		elif a == "--ac-resume":
			resume = true
		elif a == "--autoplay":
			autoplay = true
		elif a.begins_with("--ac-diff="):
			diff = clampi(int(a.get_slice("=", 1)), 0, AutochessData.DIFFICULTIES.size() - 1)
		elif a == "--auto-quit":
			auto_quit = true
	_build_world()
	board = AutochessBoard.new()
	board.arena_style = true  # tracé au sol de l'arène (AC-V)
	add_child(board)
	camera = Camera3D.new()
	camera.far = 600.0
	add_child(camera)
	camera.current = true
	board.frame_camera(camera, 0)
	director = AutochessDirector.new()  # mode scellé tant que l'écran est ouvert
	director.view = board
	add_child(director)
	director.round_finished.connect(func(_res): _real_done = true)
	cursor = AutochessCursor.new()
	add_child(cursor)
	cursor.setup(board, camera)
	_ui = CanvasLayer.new()
	_ui.name = "AcUi"
	_ui.layer = AutochessCursor.LAYER  # même calque que les cases : la croix passe du banc à la boutique
	add_child(_ui)
	hud = AutochessHud.new()
	_ui.add_child(hud)
	_top = CanvasLayer.new()
	_top.name = "AcChoices"
	_top.layer = AutochessCursor.LAYER + 2  # au-dessus du plateau : la manette ne voit que les cartes du choix
	add_child(_top)
	choice = AutochessChoicePanel.new()
	_top.add_child(choice)
	carousel = AutochessCarousel.new()
	_top.add_child(carousel)
	cards = InfoCard.in_layer(self, 128.0, 28.0)
	board.unit_placed.connect(_on_placed)
	board.unit_sold.connect(_on_sold)
	board.item_given.connect(_on_item)
	board.placement_refused.connect(func(why: String): hud.toast(why))
	cursor.zoom_changed.connect(func(_z):
		_dirty = true
		arena.prep_camera(camera, camera.global_transform, true))  # la molette prend la main sur l'arrivée de la caméra
	hud.reroll_pressed.connect(_reroll)
	hud.xp_pressed.connect(_buy_xp)
	hud.lock_pressed.connect(_lock)
	hud.ready_pressed.connect(_ready_pressed)
	hud.speed_pressed.connect(_toggle_speed)
	hud.choice_pressed.connect(func():
		_choice_hidden = false
		_open_choices())
	hud.replay_pressed.connect(_replay)
	hud.stats_pressed.connect(_open_game_stats)
	team_bars = AutochessTeamBars.new()
	team_bars.visible = false
	_ui.add_child(team_bars)
	meter = AutochessMeter.new()
	meter.position = Vector2(16.0, AutochessHud.COMBAT_TOP)
	meter.visible = false
	_ui.add_child(meter)
	var rl := CanvasLayer.new()
	rl.name = "AcRecapLayer"
	rl.layer = AutochessCursor.LAYER + 3  # au-dessus des choix : la manette n'y voit que le bilan
	add_child(rl)
	recap = AutochessRecap.new()
	rl.add_child(recap)
	hud.back_pressed.connect(_quit)
	hud.shop.buy_requested.connect(_buy)
	hud.traits.detail_requested.connect(_trait_card)
	hud.players.scout_requested.connect(_scout)
	choice.chosen.connect(_on_choice)
	choice.reroll_requested.connect(_on_choice_reroll)
	choice.hide_requested.connect(func():
		_choice_hidden = true
		choice.visible = false
		hud.choice_button.visible = true)
	carousel.picked.connect(_on_carousel_pick)
	new_game(seed_ if seed_ != 0 else randi(), resume)


## Nouvelle partie (ou reprise de la partie sauvegardée si [param resume] et qu'il y en a une).
func new_game(seed_: int, resume := false) -> void:
	game = null
	if resume:
		game = Autochess.load_game(save_path, [])
		if game != null:
			var saved: Dictionary = (game.players[me].get("meta", {}) as Dictionary).get("aci", {})
			diff = int(saved.get("diff", diff))
			_played = float(saved.get("secs", 0.0))
			game.set_strategists(_resumed_strategists(game))
	if game == null:
		game = Autochess.new()
		game.save_path = save_path
		game.start(seed_, _lineup(seed_))
		_played = 0.0
	var meta: Dictionary = game.players[me].meta
	if not meta.get("aci") is Dictionary:
		meta["aci"] = {"diff": diff, "flags": {}, "secs": _played}
		game.save()  # la difficulté est gardée dès la 1re préparation (la reprise retrouve les mêmes stratèges)
	_pilot = AutochessAi.make(1, "econome", game.seed_value) if diff >= 0 else Autochess.RandomStrategist.new()
	if diff >= 0 and not AutochessRewards.has_snapshot():
		AutochessRewards.begin()  # hub intact : remis tel quel à la fin (mode scellé)
	game.fight = _data_fight  # combats non montrés (durées réduites) : la même couche d'effets, instantanée (AC-V)
	game_stats = AutochessStats.new_game_stats()
	_stage_built = -1
	game.changed.connect(func(_pi): _dirty = true)
	_make_identities()
	hud.players.identities = identities
	hud.players.history.clear()
	scouted = -1
	foe = -1
	_choice_hidden = false
	hud.set_mode("prep")
	_enter_prep()


## Les 8 stratèges d'une nouvelle partie : 7 AutochessAi au mélange de la difficulté, sinon 7 stratèges au hasard (tests).
func _lineup(seed_: int) -> Array:
	if diff >= 0:
		return AutochessAi.lineup(diff, seed_, me)
	var strats: Array = []
	for i in AutochessData.PLAYERS:
		strats.append(null if i == me else Autochess.RandomStrategist.new())
	return strats


## Stratèges d'une partie reprise : les IA refaites d'après leur meta (AutochessAi.restore) ; le joueur reste le joueur.
func _resumed_strategists(g: Autochess) -> Array:
	var out: Array = AutochessAi.restore(g) if diff >= 0 else []
	out.resize(AutochessData.PLAYERS)
	for i in AutochessData.PLAYERS:
		if i == me:
			out[i] = null
		elif out[i] == null:
			out[i] = Autochess.RandomStrategist.new()
	return out


func _make_identities() -> void:
	var r := RandomNumberGenerator.new()
	r.seed = game.seed_value
	var names: Array = AI_NAMES.duplicate()
	for i in range(names.size() - 1, 0, -1):
		var j := r.randi_range(0, i)
		var t: Variant = names[i]
		names[i] = names[j]
		names[j] = t
	var ids := AutochessData.unit_ids()
	ids.sort()
	identities.clear()
	for pi in AutochessData.PLAYERS:
		if pi == me:
			var shown := Profile.hero_name.strip_edges()
			identities.append({"name": shown if shown != "" else "Toi", "class_id": Profile.selected_class})
		else:
			identities.append({"name": String(names[pi % names.size()]), "class_id": String(ids[r.randi_range(0, ids.size() - 1)])})


func name_of(pi: int) -> String:
	return String(identities[pi].name) if pi >= 0 and pi < identities.size() else ""


# --- déroulé --------------------------------------------------------------------------------------------------------
func _enter_prep() -> void:
	phase = "prep"
	_arena_prep()
	_cr_done = -1.0
	timer_total = game.prep_time()
	timer = AUTOPLAY_PREP if autoplay else timer_total
	cursor.enabled = true
	board.show_figures(true)
	board.set_enemy({})
	scouted = -1
	foe = -1
	hud.set_mode("prep")
	_sync()
	if autoplay:
		_pilot.decide(game, me)
	var inc: Dictionary = game.players[me].income
	if int(inc.get("total", 0)) > 0:
		var parts: Array = ["%d de base" % int(inc.base)]
		if int(inc.interest) > 0:
			parts.append("%d d'intérêts" % int(inc.interest))
		if int(inc.streak) > 0:
			parts.append("%d de série" % int(inc.streak))
		if int(inc.bonus) > 0:
			parts.append("%d d'atout" % int(inc.bonus))
		hud.show_banner(String(AutochessHud.KIND_NAMES.get(game.round_kind(), "")), "+%d or" % int(inc.total),
			" · ".join(parts), UiTheme.GOLD, 2.0)
	_open_choices()
	_tip_check()


## Ouvre le choix en attente du joueur (atout, ouverture, objet… ou choix partagé), sinon ferme les cartes.
func _open_choices() -> void:
	if game == null or phase != "prep":
		return
	var c := game.pending(me)
	if autoplay:
		var guard := 0
		while not c.is_empty() and guard < 32:
			guard += 1
			if String(c.kind) == "choix_partage" and not _my_carousel_turn():
				break
			game.choose(me, 0)
			c = game.pending(me)
	var wants_carousel := not game.carousel.is_empty() and int((game.carousel.order as Array).find(me)) >= 0 \
		and (c.is_empty() or String(c.kind) == "choix_partage")
	if wants_carousel and not carousel.visible and _cr_done < 0.0:
		_cr_revealed = 0
		_cr_t = 0.0
		_cr_pick = -1.0
		carousel.open(game, identities.map(func(d): return String(d.name)))
		choice.visible = false
		hud.choice_button.visible = false
		return
	if carousel.visible:
		return
	if c.is_empty() or String(c.kind) == "choix_partage":
		choice.visible = false
		hud.choice_button.visible = false
		return
	if _choice_hidden:
		choice.visible = false
		hud.choice_button.visible = true
		return
	choice.open(c)
	hud.choice_button.visible = false


func _my_carousel_turn() -> bool:
	if game.carousel.is_empty():
		return false
	var h := int((game.carousel.order as Array).find(me))
	return h >= 0 and _cr_revealed >= h and String(game.pending(me).get("kind", "")) == "choix_partage"


## Fin de la préparation (minuteur, Prêt) : choix restants faits d'office, puis combat (ou bilan direct).
func _end_prep() -> void:
	if phase != "prep":
		return
	cursor.cancel()
	game.set_ready(me)
	if not game.end_prep():
		return
	choice.visible = false
	carousel.visible = false
	_cr_done = -1.0
	hud.choice_button.visible = false
	_choice_hidden = false
	_close_trait_cards()
	if game.phase == "combat":
		_start_combat()
	else:
		phase = "recap"
		_phase_t = 0.0
		_phase_len = 0.05 if fast or autoplay else OPENING_RECAP
	_dirty = true


func _start_combat() -> void:
	phase = "combat"
	_phase_t = 0.0
	_phase_len = 0.05 if fast or autoplay else COMBAT_SHOW
	cursor.enabled = false
	_items_before = (game.players[me].items as Array).duplicate()
	_combat_text = "Combat"
	for f in game.fights:
		if int(f.a) != me and int(f.b) != me:
			continue
		var kind := String(f.kind)
		if kind == "jcj":
			foe = int(f.b) if int(f.a) == me else int(f.a)
			if foe < 0:
				foe = int(f.ghost_of)
			var their: Array = f.board_b if int(f.a) == me else f.board_a
			board.set_enemy(their, {"class_id": String(identities[foe].class_id), "name": name_of(foe)})
			_combat_text = ("Combat contre l'écho de %s" if int(f.b) < 0 and int(f.a) == me else "Combat contre %s") % name_of(foe)
		elif kind == "gardien":
			_combat_text = "Combat contre le gardien"
		else:
			_combat_text = "Combat contre les monstres"
	hud.set_mode("combat")
	hud.set_combat(_combat_text, 0.0, speed)
	_arena_combat()


# --- arène et vrai combat (lot AC-V) --------------------------------------------------------------------------------
## Préparation dans l'arène : combat de la manche effacé, cases allumées, décor de l'étape, caméra du plateau,
## modèles de la manche suivante préchargés.
func _arena_prep() -> void:
	real = false
	my_fight = -1
	if director != null:
		director.clear()
	board.light_up(true, fast or autoplay)
	if game.stage != _stage_built:
		_stage_built = game.stage
		arena.build(AutochessArena.biome_for(game.stage), game.seed_value + game.stage)
	arena.global_position = board.global_position
	camera.fov = 42.0
	arena.prep_camera(camera, _prep_pose(), fast or autoplay or not camera.is_inside_tree())
	if not fast:
		AutochessDirector.prepare(game)


## Pose de la caméra du plateau (AutochessBoard.frame_camera, zoom du curseur), sans la poser. Zoom de base : le plateau,
## le banc et le banc d'objets sont cadrés au plus grand dans ce que le cadre laisse libre (lot ACX-1, _fit_board).
func _prep_pose() -> Transform3D:
	var probe := Camera3D.new()
	add_child(probe)
	var z := cursor.zoom if cursor != null else 0
	board.frame_camera(probe, z)
	if z == 0 and hud != null:
		_fit_board(probe)
	var t := probe.global_transform
	probe.free()
	return t


## Cadrage du plateau (lot ACX-1) : la caméra de AutochessBoard.frame_camera garde son angle ; elle avance (ou recule) et
## glisse dans son plan pour que les 8 rangées, le banc et le banc d'objets tiennent au plus grand entre les panneaux du
## cadre (frise, traits, stratèges, boutique et onglet de l'or), avec une marge.
func _fit_board(cam: Camera3D) -> void:
	var ext := board_points()
	var vs := get_viewport().get_visible_rect().size
	var avoid: Array = _frame_guess(vs)
	var free := Rect2(Vector2(AutochessHud.s(AutochessHud.MARGIN + AutochessHud.SIDE_W), AutochessHud.s(8.0 + AutochessHud.TOP_H)),
		Vector2.ZERO)
	free.end = Vector2(vs.x - free.position.x, vs.y - AutochessHud.BOTTOM_GAP - AutochessHud.s(AutochessHud.SHOP_H + 38.0))
	var base := cam.global_transform
	var at := board.to_global(Vector3(-0.6, 0.0, 3.6))
	var back := base.origin - at
	var best := base
	var f := 1.45
	while f >= 0.8:
		var t := Transform3D(base.basis, at + back / f)
		cam.global_transform = t
		# recentrer le cadre projeté sur la zone libre (deux passes : la perspective déplace un peu le centre)
		for _pass in 2:
			var bb := _proj_box(cam, ext)
			var off := free.get_center() - bb.get_center()
			var dist := (cam.global_position - at).length()
			var px := 2.0 * dist * tan(deg_to_rad(cam.fov) * 0.5) / vs.y  # m par px au point visé
			t.origin += t.basis.x * (-off.x * px) + t.basis.y * (off.y * px)
			cam.global_transform = t
		if _fits(cam, ext, avoid, vs):
			best = t
			break
		f -= 0.025
	cam.global_transform = best


## Points du monde qui bornent le plateau (bords des 8 rangées, banc, banc d'objets, têtes des figurines) : cadrage, tests.
func board_points() -> Array:
	var pts: Array = []
	for r in AutochessBoard.ROWS:
		for c in [0, AutochessBoard.COLS - 1]:
			pts.append(board.to_global(AutochessBoard.cell_position(c, r)))
			pts.append(board.to_global(AutochessBoard.cell_position(c, r, true)))
	for i in [0, AutochessData.BENCH_SIZE - 1]:
		pts.append(board.to_global(board.slot_position(AutochessBoard.bench_slot(i))))
	for i in AutochessData.ITEM_BENCH_SIZE:
		pts.append(board.to_global(board.slot_position(AutochessBoard.items_slot(i))))
	var ext: Array = []
	for p in pts:
		for d in [Vector3(1.0, 0, 0), Vector3(-1.0, 0, 0), Vector3(0, 0, 1.0), Vector3(0, 0, -1.0), Vector3(0, 1.6, 0)]:
			ext.append((p as Vector3) + d)
	return ext


## Rectangles du cadre en préparation, calculés (les conteneurs ne sont pas encore posés à la 1re préparation) ; la colonne
## des traits compte sur toute sa hauteur possible.
func _frame_guess(vs: Vector2) -> Array:
	var pad := AutochessHud.s(10.0)
	var side := AutochessHud.s(AutochessHud.MARGIN + AutochessHud.SIDE_W) + pad
	var col_top := AutochessHud.s(AutochessHud.TOP_Y)
	var players_h := AutochessHud.s(60.0) + AutochessData.PLAYERS * AutochessHud.s(AutochessPlayers.ROW_H + 2.0) + pad
	var foot := AutochessHud.BOTTOM_GAP + AutochessHud.s(AutochessHud.SHOP_H + 38.0) + pad
	var top_w := AutochessHud.s(600.0)
	return [Rect2(Vector2((vs.x - top_w) * 0.5, 0), Vector2(top_w, AutochessHud.s(8.0 + AutochessHud.TOP_H) + pad)),
		Rect2(Vector2(0, col_top - pad), Vector2(side, vs.y - col_top - foot + pad)),
		Rect2(Vector2(vs.x - side, col_top - pad), Vector2(side, players_h)),
		Rect2(Vector2(0, vs.y - foot), Vector2(vs.x, foot))]


static func _proj_box(cam: Camera3D, pts: Array) -> Rect2:
	var bb := Rect2(cam.unproject_position(pts[0]), Vector2.ZERO)
	for p in pts:
		bb = bb.expand(cam.unproject_position(p))
	return bb


static func _fits(cam: Camera3D, pts: Array, avoid: Array, vs: Vector2) -> bool:
	var screen := Rect2(Vector2(4, 4), vs - Vector2(8, 8))
	for p in pts:
		if cam.is_position_behind(p):
			return false
		var q := cam.unproject_position(p)
		if not screen.has_point(q):
			return false
		for a in avoid:
			if (a as Rect2).has_point(q):
				return false
	return true


## Début du combat : le combat du joueur se joue en vrai dans l'arène (sauf durées réduites) ; cases estompées, caméra large.
func _arena_combat() -> void:
	my_fight = _fight_of(me)
	my_side = 1 if my_fight >= 0 and int(game.fights[my_fight].a) != me else 0
	board.light_up(false, fast or autoplay)
	real = AutochessDirector.real_combat and real_combat and my_fight >= 0
	if not real:
		return
	_real_done = false
	director.set_speed(float(speed))
	director.begin(game.fights, my_fight)
	arena.global_position = board.global_position
	arena.combat_camera(camera, my_side)
	_watch_changed(my_fight)
	meter.visible = true


## Combat de la manche où joue le stratège [param pi] (-1 : aucun).
func _fight_of(pi: int) -> int:
	for i in game.fights.size():
		var f: Dictionary = game.fights[i]
		if int(f.a) == pi or int(f.b) == pi:
			return i
	return -1


## Regarde le combat [param i] de la manche : l'arène et la caméra le suivent.
func _watch_fight(i: int) -> void:
	if not real or i < 0 or i >= director.arenas.size():
		return
	director.watch(i)
	arena.global_position = board.global_position
	arena.cam_yaw = 0.0 if i != my_fight else (180.0 if my_side == 1 else 0.0)
	_watch_changed(i)


## Combat de données (durées réduites et combats non montrés) : AutochessDirector.data_fight.
## Le contexte du combat du joueur est gardé pour ses statistiques.
func _data_fight(board_a: Array, board_b: Array, fctx: Dictionary) -> Dictionary:
	var r := AutochessStats.data_fight(board_a, board_b, fctx)
	if int(fctx.get("a", -2)) == me or int(fctx.get("b", -2)) == me:
		_data_ctx = r.ctx
	return r.result


## Barres d'équipe et compteur sur le combat [param i] (vu du camp du joueur si c'est le sien).
func _watch_changed(i: int) -> void:
	if i < 0 or i >= director.arenas.size():
		return
	var side := my_side if i == my_fight else 0
	var ctx: Dictionary = director.arenas[i].ctx
	team_bars.show_fight(ctx, side, _fight_names(i, side))
	meter.show_fight(ctx, side)


## Noms des deux camps du combat [param i] vu du camp [param side] : [ce camp, l'autre].
func _fight_names(i: int, side: int) -> Array:
	var f: Dictionary = game.fights[i]
	var a := int(f.a)
	var b := int(f.b)
	var other := "Monstres"
	if String(f.kind) == "gardien":
		other = "Gardien"
	elif b >= 0:
		other = name_of(b)
	elif int(f.get("ghost_of", -1)) >= 0:
		other = "Écho de %s" % name_of(int(f.ghost_of))
	var names := [name_of(a), other]
	return names if side == 0 else [names[1], names[0]]


## Contexte d'effets du combat du joueur qui vient de finir ({} : aucun).
func _round_ctx() -> Dictionary:
	if real:
		return director.arenas[my_fight].ctx if my_fight >= 0 and my_fight < director.arenas.size() else {}
	return _data_ctx


## Bilan de la partie (fin de partie, bouton Statistiques).
func _open_game_stats() -> void:
	var p: Dictionary = game.players[me]
	var place := int(p.place) if int(p.place) > 0 else 1
	recap.open_game(game_stats, "Bilan de la partie", "%s · %d manches gagnées" % [AutochessPlayers.place_text(place), int(p.stats.won)],
		name_of(me))


func _resolve_combat() -> void:
	_data_ctx = {}
	if real:
		game.finish_combat(director.results.duplicate(true))
	else:
		game.run_fights()
	var rctx := _round_ctx()
	AutochessStats.add_round(game_stats, rctx, my_side)
	_track()
	team_bars.visible = false
	meter.visible = false
	hud.players.record(game)
	var p: Dictionary = game.players[me]
	var last: Dictionary = p.last
	var res := String(last.get("result", ""))
	var gained: Array = []
	var before := _items_before.duplicate()
	for it in p.items:
		var k := before.find(it)
		if k >= 0:
			before.remove_at(k)
		else:
			gained.append(AutochessUnitCard.item_name(String(it)))
	var detail := ("Butin : " + ", ".join(gained)) if not gained.is_empty() else ""
	match res:
		"victoire":
			var gold := int(last.get("gold", 0))
			hud.show_banner("Victoire", "+%d or" % gold if gold > 0 else "", detail, UiTheme.GOLD)
		"defaite":
			hud.show_banner("Défaite", "−%d PV" % int(last.get("damage", 0)), detail, UiTheme.DEBUFF)
		"egalite":
			hud.show_banner("Égalité", "−%d PV" % int(last.get("damage", 0)), detail, UiTheme.MUTED)
	phase = "recap"
	_phase_t = 0.0
	_phase_len = 0.05 if fast or autoplay else AutochessData.ROUND_RECAP
	if real and not autoplay and not rctx.is_empty():
		# bilan de la manche (« Qui a compté ? ») à la place du bandeau : même résultat en tête
		var parts := hud.banner_text().split("|")
		hud._banner.visible = false
		var col := UiTheme.GOLD if res == "victoire" else (UiTheme.DEBUFF if res == "defaite" else UiTheme.MUTED)
		var line := " · ".join(Array(parts.slice(1)).filter(func(x): return String(x) != ""))
		recap.open_round(rctx, my_side, parts[0] if parts.size() > 0 and parts[0] != "" else "Bilan du combat", line, col,
			_fight_names(my_fight, my_side) if my_fight >= 0 else [name_of(me), ""])
	_dirty = true


func _next_round() -> void:
	if game.is_over() or not bool(game.players[me].alive):
		_show_end()
		return
	game.next_round()
	if game.is_over():
		_show_end()
		return
	_enter_prep()


func _show_end() -> void:
	phase = "over"
	if director != null and director.running:
		director.clear()
	real = false
	cursor.enabled = false
	choice.visible = false
	carousel.visible = false
	recap.close()
	cards.dismiss_all()
	var p: Dictionary = game.players[me]
	var place := int(p.place) if int(p.place) > 0 else 1
	_track()
	var info := end_info()
	var got: Dictionary = AutochessRewards.finish(info) if diff >= 0 else {}
	Autochess.clear_save(save_path)  # éliminé avant la fin des autres : la partie gardée n'a plus lieu d'être (ni de reprise du combat perdu)
	hud.set_mode("over")
	print("[autochess] fin : place %d, manches %d (%s), difficulté %d, %d s, coffres %d, titres %d" % [place, game.rounds_played,
		game.round_key(), diff, int(_played), (got.get("chests", []) as Array).size(), (got.get("titles", []) as Array).size()])
	results = AutochessResults.new()
	add_child(results)
	results.show_results(info, game_stats, got, {"replay": _replay, "stats": _results_stats, "back": _quit})
	if auto_quit:
		get_tree().quit()


## Ce que la fin de partie retient (bilan, récompenses, quêtes).
func end_info() -> Dictionary:
	var p: Dictionary = game.players[me]
	var meta: Dictionary = p.meta.get("aci", {})
	return {"diff": maxi(diff, 0), "place": int(p.place) if int(p.place) > 0 else 1, "stage": game.stage, "hp": int(p.hp), "rerolls": int(p.stats.rerolls),
		"rounds": game.rounds_played + 1, "rounds_won": int(p.stats.won), "secs": _played, "abandoned": bool(p.get("abandoned", false)),
		"flags": (meta.get("flags", {}) as Dictionary).duplicate()}


## Exploits de plateau (AutochessRewards.track) et durée jouée, gardés dans meta.aci (sauvegardés avec la partie).
func _track() -> void:
	if game == null:
		return
	var meta: Dictionary = game.players[me].meta
	if not meta.get("aci") is Dictionary:
		meta["aci"] = {"diff": diff, "flags": {}, "secs": 0.0}
	var flags: Dictionary = meta.aci.get("flags", {})
	AutochessRewards.track(game, me, flags)
	meta.aci["flags"] = flags
	meta.aci["secs"] = _played


## Bilan : Rejouer (même difficulté, nouvelle graine).
func _replay() -> void:
	_close_results()
	new_game(randi(), false)


## Bilan : Statistiques (bilan détaillé d'AC-V) ; le bilan revient quand on le ferme.
func _results_stats() -> void:
	if results == null:
		return
	results.visible = false
	(results.get_child(0) as Control).visible = false
	get_tree().paused = false
	_open_game_stats()
	recap.closed.connect(func():
		if is_instance_valid(results) and phase == "over":
			results.visible = true
			(results.get_child(0) as Control).visible = true
			get_tree().paused = true, CONNECT_ONE_SHOT)


func _close_results() -> void:
	get_tree().paused = false
	if is_instance_valid(results):
		results.queue_free()
	results = null


# --- boucle ---------------------------------------------------------------------------------------------------------
func _process(delta: float) -> void:
	if game == null:
		return
	if phase != "over" and not _paused:
		_played += delta / maxf(Engine.time_scale, 0.01)
	if _dirty:
		_sync()
	hud.set_holding(not cursor.held.is_empty() and String(cursor.held.get("zone", "")) != "items")
	hud.set_overlay(choice.visible or carousel.visible, carousel.visible)
	_update_card()
	_update_highlight()
	match phase:
		"prep":
			if not _paused:
				timer -= delta
			_tick_carousel(delta)
			hud.set_timer(timer, timer_total)
			if timer <= 0.0:
				_end_prep()
		"combat":
			hud.set_timer(0.0, 0.0)
			if real:
				hud.set_combat(_combat_text, _fight_time() / AutochessDirector.draw_at(), speed)
				team_bars.set_clock(_fight_time(), float(speed), "Étape %d · manche %d" % [game.stage, game.round_i])
				if _real_done:
					_resolve_combat()
			else:
				_phase_t += delta * speed
				hud.set_combat(_combat_text, _phase_t / maxf(_phase_len, 0.01), speed)
				if _phase_t >= _phase_len:
					_resolve_combat()
		"recap":
			_phase_t += delta
			if recap.visible and recap.mode == "round" and _phase_t < RECAP_HOLD:
				pass  # le bilan de manche ouvert retient la manche suivante (A / B le ferme)
			elif _phase_t >= _phase_len:
				recap.close()
				_next_round()
	_poll_triggers()


func _sync() -> void:
	_dirty = false
	if game == null:
		return
	board.set_state(game.players[me])
	_counts = game.trait_counts(me)
	hud.refresh(game, me, foe, scouted)


func _tick_carousel(delta: float) -> void:
	if not carousel.visible:
		return
	if game.carousel.is_empty():
		carousel.visible = false
		return
	var order: Array = game.carousel.order
	var done := int(game.carousel.next)
	_cr_t += delta
	var step := 0.02 if fast or autoplay else AutochessData.CAROUSEL_WALK
	if _cr_revealed < done and _cr_t >= step:
		_cr_revealed += 1
		_cr_t = 0.0
	var mine := _my_carousel_turn()
	if mine:
		if _cr_pick < 0.0:
			_cr_pick = AutochessData.CAROUSEL_PICK_TIME
			if not carousel.cards.is_empty():
				for b in carousel.cards:
					if not (b as Button).disabled:
						UiNav.focus(b)
						break
		_cr_pick -= delta
		if autoplay or _cr_pick <= 0.0:
			game.choose(me, 0)  # temps écoulé : la première carte libre
			_cr_pick = 0.0
			mine = false
	carousel.timer_label.text = "%d" % ceili(_cr_pick) if mine else ""
	if mine:
		carousel.info.text = "À toi !"
	elif _cr_revealed < order.size():
		carousel.info.text = "%s choisit…" % name_of(int(order[_cr_revealed]))
	else:
		carousel.info.text = "Tous ont choisi."
		if _cr_done < 0.0:
			_cr_done = 0.0
	if _cr_done >= 0.0:
		_cr_done += delta
		if _cr_done >= (0.05 if fast or autoplay else CAROUSEL_END):
			carousel.visible = false
			_dirty = true
			_open_choices()
			return
	carousel.refresh(game, _cr_revealed, mine, me)


## Fiche d'unité : ce que vise la manette (case, carte de la boutique) ou la souris, en bulle près de la cible (lot ACX-1 :
## la colonne des traits reste toujours visible). Survol d'un trait ou d'une carte de la boutique : _update_highlight.
func _update_card() -> void:
	var card := hud.unit_card
	if phase == "combat" and real:
		card.hide_card()
		hud.traits.visible = false  # le compteur de dégâts prend la colonne (AC-V)
		return
	hud.traits.visible = true
	if phase == "over" or game == null or choice.visible or carousel.visible:
		card.hide_card()
		return
	var s: Dictionary = {}
	var shop_i := -1
	var target := Rect2()
	if Gamepad.active and UiNav.nav_on():
		var c: Control = UiNav.cursor if UiNav.cursor != null and is_instance_valid(UiNav.cursor) else null
		if c != null and c.has_meta("ac_slot"):
			s = c.get_meta("ac_slot")
			target = UiNav.rect_of(c)
		elif c != null and c.has_meta("ac_shop"):
			shop_i = int(c.get_meta("ac_shop"))
	elif hud.shop.hovered >= 0 and hud.shop.cards[hud.shop.hovered].is_visible_in_tree():
		shop_i = hud.shop.hovered
	elif cursor.enabled:
		s = cursor.slot
		var sc: Control = cursor.control_of(s) if not s.is_empty() else null
		if sc != null:
			target = sc.get_global_rect()
	var shop_id := ""
	if shop_i >= 0:
		var sb: Control = hud.shop.cards[shop_i]
		shop_id = String(sb.get_meta("unit_id", ""))
		target = sb.get_global_rect()
		var tab: Control = hud._gold_tab
		if tab.is_visible_in_tree():  # la bulle passe au-dessus de l'onglet de l'or
			target = target.merge(Rect2(Vector2(target.position.x, tab.get_global_rect().position.y), Vector2(target.size.x, 1.0)))
	if not s.is_empty() and String(s.get("zone", "")) == "items":
		var it := board.item_at(s)
		if it != "":
			card.show_item(it)
		else:
			card.hide_card()
	elif not s.is_empty() and not board.unit_at(s).is_empty():
		card.show_unit(board.unit_at(s), _counts)
	elif shop_id != "":
		card.show_unit({"id": shop_id, "stars": 1, "items": []}, _counts, true)
	else:
		card.hide_card()
	if card.visible and target.size != Vector2.ZERO:
		card.place_near(target, hud.frame_rects())


## Lot ACX-1 : survol (souris) ou cadre de la manette sur un trait de la colonne → ses unités (plateau, banc) s'entourent
## de lagon et ses cartes de boutique aussi ; sur une carte de la boutique → les copies déjà possédées s'illuminent et la
## colonne montre les traits qui monteraient (« 2 → 3 »).
func _update_highlight() -> void:
	var t := ""
	var shop_id := ""
	if phase == "prep" and game != null and not choice.visible and not carousel.visible and cursor.held.is_empty():
		if Gamepad.active and UiNav.nav_on():
			var c: Control = UiNav.cursor if UiNav.cursor != null and is_instance_valid(UiNav.cursor) else null
			if c != null and c.has_meta("ac_trait"):
				t = String(c.get_meta("ac_trait"))
			elif c != null and c.has_meta("ac_shop"):
				shop_id = String(c.get_meta("unit_id", ""))
		elif hud.traits.hovered != "":
			t = hud.traits.hovered
		elif hud.shop.hovered >= 0 and hud.shop.cards[hud.shop.hovered].is_visible_in_tree():
			shop_id = String((hud.shop.cards[hud.shop.hovered] as Control).get_meta("unit_id", ""))
	var uids: Array = []
	var rising: Array = []
	if t != "":
		for u in game.units_of(me):
			if Autochess.unit_traits(u).has(t):
				uids.append(int(u.uid))
	elif shop_id != "":
		var placed := false
		for u in game.units_of(me):
			if String(u.id) == shop_id:
				uids.append(int(u.uid))
		for u in game.players[me].board:
			placed = placed or String(u.id) == shop_id
		if not placed:
			rising = (AutochessData.unit(shop_id).get("traits", []) as Array).duplicate()
	board.mark_units(uids)
	hud.shop.mark_trait(t)
	hud.traits.set_marked(t)
	hud.traits.preview(rising)


# --- actions --------------------------------------------------------------------------------------------------------
func _can_act() -> bool:
	return phase == "prep" and not choice.visible and not carousel.visible and bool(game.players[me].alive)


func _buy(slot: int) -> void:
	if phase != "prep":
		return
	var p: Dictionary = game.players[me]
	var id := String(p.shop[slot]) if slot < (p.shop as Array).size() else ""
	if id == "":
		return
	if game.buy(me, slot):
		Sfx.ui("confirm", -8.0)
		_dirty = true
		_tip_check()
		return
	if int(p.gold) < AutochessPool.cost_of(id):
		hud.toast("Pas assez d'or")
	else:
		hud.toast("Banc plein : vends ou place un héros")


func _reroll() -> void:
	if phase != "prep":
		return
	if not game.reroll(me):
		hud.toast("Pas assez d'or")


func _buy_xp() -> void:
	if phase != "prep":
		return
	var p: Dictionary = game.players[me]
	var lv := int(p.level)
	if game.buy_xp(me):
		if int(p.level) > lv:
			hud.toast("Niveau %d : une place de plus sur le plateau" % int(p.level))
	elif lv >= int(p.max_level):
		hud.toast("Niveau maximal")
	else:
		hud.toast("Pas assez d'or")


func _lock() -> void:
	if phase == "prep":
		game.toggle_lock(me)


func _ready_pressed() -> void:
	if phase == "prep":
		_end_prep()


func _toggle_speed() -> void:
	speed = 2 if speed == 1 else 1
	if director != null:
		director.set_speed(float(speed))  # Engine.time_scale pendant le vrai combat seulement
	hud.set_combat(_combat_text, _phase_t / maxf(_phase_len, 0.01), speed)


## Temps du combat regardé (s de combat).
func _fight_time() -> float:
	if not real or director.arenas.is_empty():
		return 0.0
	return float(director.arenas[clampi(director.watched, 0, director.arenas.size() - 1)].t)


func _on_placed(u: Dictionary, _from: Dictionary, to: Dictionary) -> void:
	if phase == "prep":
		var uid := int(u.get("uid", 0))
		match String(to.get("zone", "")):
			"board":
				game.place(me, uid, Vector2i(int(to.col), int(to.row)))
			"bench":
				game.to_bench(me, uid, int(to.index))
	_dirty = true


func _on_sold(u: Dictionary, _from: Dictionary) -> void:
	if phase == "prep":
		var gold := int(game.players[me].gold)
		if game.sell(me, int(u.get("uid", 0))):
			hud.toast("+%d or" % (int(game.players[me].gold) - gold))
			Sfx.ui("gold", -6.0)
	_dirty = true


func _on_item(it: String, u: Dictionary, _from: Dictionary) -> void:
	if phase == "prep":
		var idx := (game.players[me].items as Array).find(it)
		if idx < 0 or not game.equip(me, idx, int(u.get("uid", 0))):
			hud.toast("Cet objet ne va pas sur ce héros")
	_dirty = true


func _on_choice(i: int) -> void:
	var c := game.pending(me)
	if c.is_empty():
		choice.visible = false
		return
	var kind := String(c.kind)
	var opt: Variant = (c.options as Array)[i] if i < (c.options as Array).size() else null
	if not game.choose(me, i):
		return
	match kind:
		"ouverture", "heros":
			hud.toast("%s rejoint ton banc" % AutochessData.unit_name(String(opt)))
		"atout":
			hud.toast("Atout : %s" % String(AutochessData.augment(String(opt)).get("name", "")))
	choice.visible = false
	_choice_hidden = false
	_dirty = true
	_open_choices()


func _on_choice_reroll() -> void:
	if game.reroll_choice(me):
		choice.open(game.pending(me))


func _on_carousel_pick(k: int) -> void:
	if not _my_carousel_turn():
		return
	var c := game.pending(me)
	var idx := (c.get("slots", []) as Array).find(k)
	if idx >= 0 and game.choose(me, idx):
		_cr_pick = 0.0
		hud.toast("%s rejoint ton banc" % AutochessData.unit_name(String(game.carousel.options[k].id)) \
			if not game.carousel.is_empty() else "")
		_dirty = true


func _scout(pi: int) -> void:
	if phase == "combat" and real:
		_watch_fight(_fight_of(pi))  # pendant le vrai combat : regarder un autre combat dans l'arène (AC-V)
		return
	if phase != "prep":
		return
	if pi == me or pi == scouted or not bool(game.players[pi].alive):
		scouted = -1
		board.set_enemy({})
	else:
		scouted = pi
		board.set_enemy(game.players[pi].board, {"class_id": String(identities[pi].class_id), "name": name_of(pi)})
		hud.toast("Plateau de %s" % name_of(pi))
	_dirty = true


func _trait_card(t: String) -> void:
	var td: Dictionary = AutochessData.TRAITS.get(t, {})
	if td.is_empty():
		return
	var ths: Array = AutochessData.trait_thresholds(t).map(func(x): return str(int(x)))
	cards.add_card({"id": "trait_" + t, "title": String(td.name),
		"lines": [String(td.short), "Paliers : " + " · ".join(ths), String(td.tip)],
		"buttons": [{"label": "Compris", "kind": "primary"}]})


func _close_trait_cards() -> void:
	if cards != null:
		for id in cards.ids():
			if String(id).begins_with("trait_"):
				cards.dismiss(String(id), "auto")


func _pause() -> void:
	if _paused or phase == "over":
		return
	_paused = true
	cards.add_card({"id": "pause", "title": "Pause",
		"body": "La partie est gardée au début de chaque manche.",
		"buttons": [
			{"label": "Reprendre", "kind": "primary"},
			{"label": "Quitter", "kind": "plain", "cb": _quit},
			{"label": "Abandonner", "kind": "link", "cb": _ask_abandon},
		],
		"on_close": func(_how): _paused = false})


func _ask_abandon() -> void:
	_paused = true
	InfoCard.ask(self, "Abandonner la partie ?", "Ta place est celle d'aujourd'hui parmi les stratèges encore en lice.",
		"Abandonner", func():
			_paused = false
			game.abandon(me)
			_show_end(),
		true, "Annuler", func(): _paused = false)


func _quit() -> void:
	get_tree().paused = false
	if AutochessRewards.has_snapshot():
		AutochessRewards.restore_hub()  # partie laissée en cours (reprise possible) : le hub est remis tel quel
	get_tree().change_scene_to_file("res://scenes/lobby.tscn")


# --- fiches de découverte (lot AC-I) ----------------------------------------------------------------------------------
## Fiche de la 1re rencontre (boutique, deux copies d'une unité, trait actif ou atout), une à la fois, en préparation.
func _tip_check() -> void:
	if phase != "prep" or cards == null or cards.count() > 0 or autoplay:
		return
	for id in TIPS:
		if Tutorial.card_pending(id) and _tip_due(id):
			Tutorial.mark_seen(id)
			var spec := Tutorial.card_spec(id)
			spec["duration"] = 20.0
			spec["buttons"] = [{"label": "Compris", "kind": "primary"},
				{"label": "Guide", "kind": "plain", "cb": func(): Guide.open_on(self, id)}]
			cards.add_card(spec)
			return


func _tip_due(id: String) -> bool:
	var p: Dictionary = game.players[me]
	match id:
		"ac_shop":
			return game.round_kind() != "ouverture" and not (p.shop as Array).all(func(s): return String(s) == "")
		"ac_stars":
			var seen := {}
			for u in game.units_of(me):
				if int(u.stars) >= 2:
					return true
				seen[String(u.id)] = int(seen.get(String(u.id), 0)) + 1
				if int(seen[String(u.id)]) >= 2:
					return true
		"ac_traits":
			return not game.active_traits(me).is_empty() or String(game.pending(me).get("kind", "")) == "atout"
	return false


# --- entrées --------------------------------------------------------------------------------------------------------
func _input(ev: InputEvent) -> void:
	if game == null or not ev is InputEventJoypadButton or not (ev as InputEventJoypadButton).pressed:
		return
	if cards != null and cards.count() > 0:
		return  # une petite carte ouverte : elle prend A / B
	match (ev as InputEventJoypadButton).button_index:
		JOY_BUTTON_Y:
			if phase == "prep" and _can_act():
				_end_prep()
			elif phase == "combat":
				_toggle_speed()
			get_viewport().set_input_as_handled()
		JOY_BUTTON_LEFT_SHOULDER:
			if _can_act():
				_buy_xp()
				get_viewport().set_input_as_handled()
		JOY_BUTTON_RIGHT_SHOULDER:
			if _can_act() and not hud.shop.cards.is_empty():
				UiNav.focus(hud.shop.cards[0])
				get_viewport().set_input_as_handled()
		JOY_BUTTON_START:
			_pause()
			get_viewport().set_input_as_handled()


## Gâchettes : gauche = actualiser, droite = verrou (sur le front de l'appui).
func _poll_triggers() -> void:
	if not Gamepad.active:
		return
	for k in 2:
		var on := Input.get_joy_axis(0, JOY_AXIS_TRIGGER_LEFT if k == 0 else JOY_AXIS_TRIGGER_RIGHT) > TRIGGER_ON
		if on and not _trig[k] and _can_act() and (cards == null or cards.count() == 0):
			if k == 0:
				_reroll()
			else:
				_lock()
		_trig[k] = on


func _unhandled_input(ev: InputEvent) -> void:
	if game == null or not ev is InputEventKey:
		return
	var ke := ev as InputEventKey
	if not ke.pressed or ke.echo:
		return
	var k := ke.keycode
	if choice.visible and k >= KEY_1 and k <= KEY_5:
		if k - KEY_1 < choice.cards.size():
			_on_choice(k - KEY_1)
		get_viewport().set_input_as_handled()
		return
	var used := true
	match k:
		KEY_1, KEY_2, KEY_3, KEY_4, KEY_5:
			if _can_act():
				_buy(k - KEY_1)
		KEY_D:
			if _can_act():
				_reroll()
		KEY_F:
			if _can_act():
				_buy_xp()
		KEY_V:
			if _can_act():
				_lock()
		KEY_SPACE:
			if phase == "prep" and _can_act():
				_end_prep()
			elif phase == "combat":
				_toggle_speed()
		KEY_ESCAPE:
			_pause()
		_:
			used = false
	if used:
		get_viewport().set_input_as_handled()


# --- décor ----------------------------------------------------------------------------------------------------------
## L'arène du Duel autour du plateau (AutochessArena, lot AC-V : décor de l'étape posé à chaque préparation), musique du duel.
func _build_world() -> void:
	arena = AutochessArena.new()
	add_child(arena)
	Music.play(Music.DUEL)
