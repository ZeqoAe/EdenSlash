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
## Lot ACX-2 (rapport conception/autochess/R_ACX2.md) : annuler (Ctrl+Z / Retour arrière / bouton Vue : achat, vente,
## déplacement, objet ; Autochess.undo), vente confirmée (maintien 0,6 s ou « Vendre ? » pour un héros précieux),
## raccourcis W (banc ↔ plateau), Q / R (stratège ou combat précédent / suivant), Espace (retour à son combat) ; combat
## lisible (barres pomme / fraise, objets sous la barre, noms au survol, nom des sorts, chiffres sobres), vitesse ×1 / ×2 /
## ×3 (1, 2, 3), vraie pause, Passer (P, X : fin au combat de données) ; bilan de manche NON bloquant (bandeau
## AutochessRecap.RoundStrip + [Détail]) ; moments manga (AutochessMoment : « Combat ! », victoire / défaite, ★★ / ★★★,
## objet complet, niveau, éliminations) ; réglages (Settings « autochess » : sans minuteur, noms, bilan toujours) ;
## spectateur après élimination (« Regarder la fin » en ×2, Bilan à tout moment, place et récompenses fixées à la chute).

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
## Lot ACX-3 : format (« classique », « eclair »), règle du jour, partie du jour (graine, difficulté et règle du jour fixées).
var format := "classique"
var day_rule := ""
var daily := false
var guide: AutochessGuide  # première partie guidée (null : finie, passée ou pilote automatique)
var strikes: Array = []  # coups au stratège lancés (tests) : {from, to, damage, loser}
var _card_id := ""  # héros montré par la fiche (planificateur : T, clic du stick droit)
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
## Lot ACX-2 : moments manga, bandeau de manche non bloquant, spectateur après élimination.
const RECAP_REAL := 1.8  # s : courte pause après un vrai combat (le bandeau dure plus longtemps et ne bloque rien)
const SPEC_PREP := 0.7  # s : préparation montrée au spectateur (les stratèges décident d'office)
const SPEC_SPEED := 2
var moments: AutochessMoment
var strip: AutochessRecap.RoundStrip
var spectating := false
var _out_card := false  # « Tu es éliminé » ouvert : le déroulé attend
var _got: Dictionary = {}  # récompenses fixées à l'élimination (spectateur)
var _got_done := false
var _final_info: Dictionary = {}  # ce que la fin retient (fixé à l'élimination : le spectateur n'y change rien)
var _alive_prev: Array = []
var _hover_unit: AutochessUnit
var _spec_watch := -1  # stratège regardé par le spectateur
var _speed_before := 1
var _last_ctx: Dictionary = {}
var _last_side := 0
var _last_head := ""
var _last_line := ""
var _last_col := Color.WHITE
var _last_names: Array = []


func _ready() -> void:
	var cfg: Dictionary = config
	autoplay = bool(cfg.get("autoplay", false))
	fast = bool(cfg.get("fast", false))
	save_path = String(cfg.get("save_path", Autochess.SAVE_PATH))
	real_combat = bool(cfg.get("real", not fast))
	diff = int(cfg.get("diff", -1))
	auto_quit = bool(cfg.get("auto_quit", false))
	format = String(cfg.get("format", "classique"))
	day_rule = String(cfg.get("rule", ""))
	daily = bool(cfg.get("daily", false))
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
		elif a.begins_with("--ac-format="):
			format = a.get_slice("=", 1)
		elif a == "--ac-daily":
			daily = true
	if daily:  # partie du jour : la même pour tous les joueurs ce jour-là
		var day := Quests.today()
		seed_ = AutochessData.daily_seed(day)
		diff = AutochessData.DAILY_DIFF
		format = AutochessData.DAILY_FORMAT
		day_rule = AutochessData.daily_rule(day)
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
	meter.set_collapsed(true)  # replié par défaut (lot ACX-2, étude BM-AUTO §7.2) : l'onglet « Dégâts ▸ » l'ouvre
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
	# lot ACX-2 : annuler, pause, passer, bandeau de manche, moments, vente confirmée, réglages
	hud.undo_pressed.connect(_undo)
	hud.pause_pressed.connect(_pause)
	hud.skip_pressed.connect(_skip)
	strip = AutochessRecap.RoundStrip.new()
	_ui.add_child(strip)
	strip.detail_pressed.connect(_open_detail)
	var ml := CanvasLayer.new()
	ml.name = "AcMomentsLayer"
	ml.layer = AutochessCursor.LAYER + 4  # au-dessus de tout le mode, sans prendre la souris
	add_child(ml)
	moments = AutochessMoment.new()
	ml.add_child(moments)
	cursor.confirm_sell = _confirm_sell
	AutochessUnit.show_names = bool(opt("names"))
	new_game(seed_ if seed_ != 0 else randi(), resume)
	if AutochessGuide.wanted() and not autoplay and not fast:
		guide = AutochessGuide.new()
		_ui.add_child(guide)
		_ui.move_child(guide, 0)  # sous le cadre : la fiche d'unité passe par-dessus
		guide.finished.connect(func(_s): guide = null)
		guide.observe(game, me)


## Réglage de l'Échiquier (Settings, section « autochess » : no_timer, names, recap_always).
static func opt(key: String) -> bool:
	return bool(Settings.get_v("autochess", key)) if Settings.get_v("autochess", key) != null else false


## Nouvelle partie (ou reprise de la partie sauvegardée si [param resume] et qu'il y en a une).
func new_game(seed_: int, resume := false) -> void:
	game = null
	if resume:
		game = Autochess.load_game(save_path, [])
		if game != null:
			var saved: Dictionary = (game.players[me].get("meta", {}) as Dictionary).get("aci", {})
			diff = int(saved.get("diff", diff))
			daily = bool(saved.get("daily", false))
			format = game.format
			day_rule = game.day_rule
			_played = float(saved.get("secs", 0.0))
			game.set_strategists(_resumed_strategists(game))
	if game == null:
		game = Autochess.new()
		game.save_path = save_path
		game.configure(format, day_rule)
		game.start(seed_, _lineup(seed_))
		_played = 0.0
	var meta: Dictionary = game.players[me].meta
	if not meta.get("aci") is Dictionary:
		meta["aci"] = {"diff": diff, "flags": {}, "secs": _played, "daily": daily}
		game.save()  # la difficulté est gardée dès la 1re préparation (la reprise retrouve les mêmes stratèges)
	_pilot = AutochessAi.make(1, "econome", game.seed_value) if diff >= 0 else Autochess.RandomStrategist.new()
	if diff >= 0 and not AutochessRewards.has_snapshot():
		AutochessRewards.begin()  # hub intact : remis tel quel à la fin (mode scellé)
	game.fight = _data_fight  # combats non montrés (durées réduites) : la même couche d'effets, instantanée (AC-V)
	game_stats = AutochessStats.new_game_stats()
	_stage_built = -1
	if spectating:
		speed = _speed_before
	spectating = false
	_out_card = false
	_got = {}
	_got_done = false
	_final_info = {}
	_spec_watch = -1
	_alive_prev = game.alive_ids()
	AutochessDirector.viewer = me
	if moments != null:
		moments.clear_all()
	if strip != null:
		strip.hide_now()
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
	if spectating:
		timer_total = 0.0
		timer = SPEC_PREP
	elif opt("no_timer") and not autoplay:
		timer_total = 0.0  # préparation sans minuteur (réglage) : Prêt seulement ; le minuteur et sa barre disparaissent
		timer = 1.0e9
	cursor.enabled = not spectating
	board.show_figures(true)
	board.set_enemy({})
	scouted = -1
	foe = -1
	hud.set_mode("combat" if spectating else "prep")
	_sync()
	if spectating:
		return
	if autoplay:
		_pilot.decide(game, me)
	var inc: Dictionary = game.players[me].income
	if int(inc.get("total", 0)) > 0:
		var parts: Array = ["%d de base" % int(inc.base)]
		var plots: Array = [[parts[0], "lilas"]]
		if int(inc.interest) > 0:
			parts.append("%d d'intérêts" % int(inc.interest))
			plots.append([parts[-1], "pomme"])
		if int(inc.streak) > 0:
			parts.append("%d de série" % int(inc.streak))
			plots.append([parts[-1], "mandarine"])
		if int(inc.bonus) > 0:
			parts.append("%d d'atout" % int(inc.bonus))
			plots.append([parts[-1], "soleil"])
		if strip.visible:
			strip.add_income(int(inc.total), plots)  # le bandeau de la manche finie dit aussi le revenu (un seul bandeau)
		else:
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
	if not fast and not autoplay and not spectating:
		var guard := game.round_kind() == "gardien"
		moments.banner("Gardien !" if guard else "Combat !", "fraise" if guard else "lagon", "", "ui_banner" if guard else "confirm", -10.0, 0.8,
			[0.15, 0.1, 0.08], 0.45)


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
	var watch_i := my_fight
	if spectating:
		watch_i = _spectator_fight()
	real = AutochessDirector.real_combat and real_combat and watch_i >= 0
	if not real:
		return
	_real_done = false
	director.set_speed(float(speed))
	director.begin(game.fights, watch_i)
	arena.global_position = board.global_position
	arena.combat_camera(camera, my_side)
	_watch_changed(watch_i)
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
	phase = "recap"
	_phase_t = 0.0
	_phase_len = 0.05 if fast or autoplay else (RECAP_REAL if real else AutochessData.ROUND_RECAP)
	_announce_eliminations()
	if spectating or not bool(p.alive) and res == "":
		_dirty = true
		return
	# lot ACX-2 : bandeau non bloquant (résultat, PV, or, butin) + moment manga ; le bilan complet sur [Détail]
	var head := ""
	var tone := "lilas"
	var line := ""
	match res:
		"victoire":
			var gold := int(last.get("gold", 0))
			head = "Victoire"
			tone = "pomme"
			line = "+%d or" % gold if gold > 0 else ""
		"defaite":
			head = "Défaite"
			tone = "fraise"
			line = "−%d PV" % int(last.get("damage", 0))
		"egalite":
			head = "Égalité"
			line = "−%d PV" % int(last.get("damage", 0))
	if detail != "":
		line = (line + " · " if line != "" else "") + detail
	var col := UiTheme.GOLD if res == "victoire" else (UiTheme.DEBUFF if res == "defaite" else UiTheme.MUTED)
	_last_ctx = rctx
	_last_side = my_side
	_last_head = head if head != "" else "Bilan du combat"
	_last_line = line
	_last_col = col
	_last_names = _fight_names(my_fight, my_side) if my_fight >= 0 else [name_of(me), ""]
	if head != "":
		strip.show_result(head, tone, line, not rctx.is_empty())
		if not fast and not autoplay:
			if res == "victoire":
				moments.banner("Victoire !", "pomme", line, "confirm", -6.0, 1.15, [0.3, 0.2, 0.14], 0.6)
			elif res == "defaite":
				moments.banner("Défaite", "fraise", line, "error", -10.0, 0.75, [0.1, 0.4, 0.16], 0.55)
	if real and not autoplay and not rctx.is_empty() and opt("recap_always"):
		_open_detail()  # réglage « Toujours montrer le bilan » : l'ancien bilan, qui retient la manche suivante
	if real and not fast and not autoplay and speed <= 1 and my_fight >= 0:
		_strike(my_fight)
	_dirty = true


## Lot ACX-3 (étude BM-AUTO §6 n° 13) : coup au stratège. Les survivants du camp gagnant du combat [param i] tirent sur la
## figurine du stratège perdant (projectiles de la couleur du camp, 1,2 s au plus), qui encaisse ses PV perdus (chiffre
## fraise, secousse de sa ligne dans la colonne des stratèges). Sauté en ×2 et plus, au pilote et en durées réduites.
const STRIKE_MAX := 6
const STRIKE_FLY := 0.42
const STRIKE_GAP := 0.08


func _strike(i: int) -> void:
	if i < 0 or i >= director.arenas.size() or i >= game.results.size():
		return
	var f: Dictionary = game.fights[i]
	var w := int(game.results[i].winner)
	if w < 0:
		return
	var loser_side := 1 - w
	var loser_pi := int(f.a) if loser_side == 0 else int(f.b)
	if loser_pi < 0:
		return  # écho (fantôme) ou monstres : personne à frapper
	var mine := loser_pi == me
	var target: Node3D = board.strategist if mine else board.foe_strategist
	if target == null or not is_instance_valid(target):
		return
	var dmg := int((game.players[loser_pi].last as Dictionary).get("damage", 0))
	if dmg <= 0:
		return
	var from: Array = []
	for n in director.arenas[i].nodes[w]:
		if is_instance_valid(n) and not (n as AutochessUnit).is_dead:
			from.append((n as Node3D).global_position + Vector3.UP * 1.2)
	if from.is_empty():
		return
	from = from.slice(0, STRIKE_MAX)
	var to := target.global_position + Vector3.UP * 1.3
	strikes.append({"from": from.size(), "damage": dmg, "loser": loser_pi})
	var col := AutochessHud.candy("fraise") if mine else AutochessHud.candy("pomme")
	for k in from.size():
		var orb := MeshInstance3D.new()
		var sph := SphereMesh.new()
		sph.radius = 0.2
		sph.height = 0.4
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = col.lightened(0.25)
		mat.emission_enabled = true
		mat.emission = col
		sph.material = mat
		orb.mesh = sph
		orb.visible = false
		add_child(orb)
		orb.global_position = from[k]
		var a: Vector3 = from[k]
		var tw := create_tween()
		tw.tween_interval(STRIKE_GAP * k)
		tw.tween_callback(func(): orb.visible = true)
		tw.tween_method(_orb_step.bind(orb, a, to), 0.0, 1.0, STRIKE_FLY)
		tw.tween_callback(orb.queue_free)
		if k == 0:
			tw.tween_callback(_strike_hit.bind(target, loser_pi, dmg, mine))


## Trajet d'un projectile du coup au stratège : en cloche de 2 m, de [param a] à [param b] ([param t] de 0 à 1).
func _orb_step(t: float, orb: MeshInstance3D, a: Vector3, b: Vector3) -> void:
	if is_instance_valid(orb):
		orb.global_position = a.lerp(b, t) + Vector3.UP * sin(t * PI) * 2.0


func _strike_hit(target: Node3D, pi: int, dmg: int, mine: bool) -> void:
	if not is_instance_valid(target):
		return
	var wp := target.global_position + Vector3.UP * 2.4
	var at := camera.unproject_position(wp) if camera != null and not camera.is_position_behind(wp) else get_viewport().get_visible_rect().size * 0.5
	moments.burst(at, "−%d" % dmg, "fraise" if mine else "pomme", "error" if mine else "confirm", -9.0, 0.8 if mine else 1.2,
		[0.1, 0.35, 0.12] if mine else [])
	hud.players.flash(pi)
	if not UiFeel.reduce_motion:
		var home := target.position
		var tw := create_tween()
		for d in [0.25, -0.2, 0.12, 0.0]:
			tw.tween_property(target, "position", home + Vector3(float(d), 0.0, 0.0), 0.05)


## [Détail] du bandeau : le bilan complet de la dernière manche jouée (meilleur héros, barres, totaux).
func _open_detail() -> void:
	if _last_ctx.is_empty():
		return
	recap.open_round(_last_ctx, _last_side, _last_head, _last_line, _last_col, _last_names)


## Stratèges tombés pendant la manche : vignette « Daphné · 7e » (les autres) ; toi : la fin ou le spectateur (_next_round).
func _announce_eliminations() -> void:
	var now := game.alive_ids()
	for pi in _alive_prev:
		if not int(pi) in now and int(pi) != me:
			var cid := String(identities[int(pi)].class_id) if int(pi) < identities.size() else ""
			moments.elimination(name_of(int(pi)), int(game.players[int(pi)].place),
				UiTheme.texture(String(GameData.class_data(cid).get("icon", ""))))
	_alive_prev = now


func _next_round() -> void:
	if game.is_over():
		_show_end()
		return
	if not bool(game.players[me].alive) and not spectating:
		if autoplay or fast or auto_quit:
			_show_end()  # pilote, tests : la fin tout de suite (comme avant le spectateur)
		else:
			_eliminated()
		return
	game.next_round()
	if game.is_over():
		_show_end()
		return
	_enter_prep()


# --- spectateur (lot ACX-2, étude BM-AUTO §6 n° 14) -----------------------------------------------------------------
## Tu es éliminé : ta place et tes récompenses sont fixées tout de suite (AutochessRewards.finish, hub remis, partie
## gardée effacée) ; « Regarder la fin » (combats des autres en ×2, Bilan à tout moment) ou « Bilan ».
func _eliminated() -> void:
	phase = "out"
	_out_card = true
	_fix_rewards()
	cursor.enabled = false
	var place := int(game.players[me].place)
	moments.banner("Éliminé", "fraise", AutochessPlayers.place_text(place), "error", -8.0, 0.6, [0.0, 0.45, 0.25], 0.9)
	cards.add_card({"id": "ac_out", "title": "Tu es éliminé · %s" % AutochessPlayers.place_text(place),
		"body": "Ta place est gardée. Tu peux regarder la fin de la partie, ou voir ton bilan.",
		"buttons": [{"label": "Regarder la fin", "kind": "primary", "cb": _start_spectating},
			{"label": "Bilan", "kind": "plain", "cb": _out_to_end}],
		"on_close": _out_closed})


func _out_to_end() -> void:
	_out_card = false
	_show_end()


## Carte « Tu es éliminé » fermée sans choisir (croix, Échap) : le bilan.
func _out_closed(how: String) -> void:
	if how != "button" and _out_card and phase == "out":
		_out_to_end()


## Récompenses et fin de la partie pour toi, une seule fois (élimination, abandon, fin) ; la partie n'est plus sauvegardée.
func _fix_rewards() -> void:
	if _got_done:
		return
	_got_done = true
	_track()
	_final_info = end_info()
	_got = AutochessRewards.finish(_final_info) if diff >= 0 else {}
	Autochess.clear_save(save_path)
	game.save_path = ""  # la suite (spectateur) ne se reprend pas


func _start_spectating() -> void:
	_out_card = false
	spectating = true
	_speed_before = speed
	speed = SPEC_SPEED
	_spec_watch = _leader()
	hud.toast("Tu regardes la fin · Bilan : Échap")
	game.next_round()
	if game.is_over():
		_show_end()
		return
	_enter_prep()


## Stratège en tête (le plus de PV), regardé par défaut.
func _leader() -> int:
	var best := -1
	for pi in game.alive_ids():
		if best < 0 or int(game.players[pi].hp) > int(game.players[best].hp):
			best = int(pi)
	return best


## Combat montré au spectateur : celui du stratège regardé (s'il joue encore), sinon le premier.
func _spectator_fight() -> int:
	if _spec_watch < 0 or not bool(game.players[_spec_watch].alive):
		_spec_watch = _leader()
	var i := _fight_of(_spec_watch)
	return i if i >= 0 else (0 if not game.fights.is_empty() else -1)


## Spectateur : stratège regardé suivant ([param d] = ±1), Q / R ou clic sur sa ligne.
func _spec_step(d: int) -> void:
	var alive := game.alive_ids()
	if alive.is_empty():
		return
	var k := alive.find(_spec_watch)
	_spec_watch = int(alive[posmod(k + d, alive.size())])
	if phase == "combat" and real:
		_watch_fight(_fight_of(_spec_watch))
	hud.toast("Tu regardes %s" % name_of(_spec_watch))


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
	_fix_rewards()  # éliminé avant la fin des autres : la partie gardée n'a plus lieu d'être (ni de reprise du combat perdu)
	var info := _final_info
	var got: Dictionary = _got
	if spectating:
		speed = _speed_before
		spectating = false
	moments.clear_all()
	strip.hide_now()
	hud.set_mode("over")
	print("[autochess] fin : place %d, manches %d (%s), difficulté %d, %d s, coffres %d, titres %d" % [place, game.rounds_played,
		game.round_key(), diff, int(_played), (got.get("chests", []) as Array).size(), (got.get("titles", []) as Array).size()])
	results = AutochessResults.new()
	add_child(results)
	results.show_results(info, game_stats, got, {"replay": _replay, "stats": _results_stats, "back": _quit}, podium())
	if auto_quit:
		get_tree().quit()


## Podium des 8 stratèges pour le bilan (lot ACX-2) : nom, classe, place (vivants : rang du moment, par PV), trait principal.
func podium() -> Array:
	var out: Array = []
	var alive := game.alive_ids()
	alive.sort_custom(func(a, b): return int(game.players[a].hp) > int(game.players[b].hp))
	for pi in AutochessData.PLAYERS:
		var p: Dictionary = game.players[pi]
		var place := int(p.place) if int(p.place) > 0 else alive.find(pi) + 1
		var best := ""
		var top := 0
		var counts := game.trait_counts(pi) if bool(p.alive) else {}
		if counts.is_empty():
			for u in p.get("final_board", []):
				for t in Autochess.unit_traits(u):
					counts[t] = int(counts.get(t, 0)) + 1
		for t in counts:
			if int(counts[t]) > top:
				top = int(counts[t])
				best = String(AutochessData.TRAITS.get(t, {}).get("name", ""))
		out.append({"name": name_of(pi), "class_id": String(identities[pi].class_id) if pi < identities.size() else "",
			"place": maxi(place, 1), "trait": best, "me": pi == me})
	out.sort_custom(func(a, b): return int(a.place) < int(b.place))
	return out


## Ce que la fin de partie retient (bilan, récompenses, quêtes).
func end_info() -> Dictionary:
	var p: Dictionary = game.players[me]
	var meta: Dictionary = p.meta.get("aci", {})
	return {"diff": maxi(diff, 0), "place": int(p.place) if int(p.place) > 0 else 1, "stage": game.stage, "hp": int(p.hp), "rerolls": int(p.stats.rerolls),
		"rounds": game.rounds_played + 1, "rounds_won": int(p.stats.won), "secs": _played, "abandoned": bool(p.get("abandoned", false)),
		"flags": (meta.get("flags", {}) as Dictionary).duplicate(), "format": game.format, "rule": game.day_rule,
		"daily": bool(meta.get("daily", daily)), "team": p.get("final_board", []) if not bool(p.alive) else game.board_snapshot(me)}


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
	new_game(AutochessData.daily_seed(Quests.today()) if daily else randi(), false)  # partie du jour : la même graine


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
	hud.undo_button.visible = phase == "prep" and game.can_undo(me) and not spectating
	_update_hover_names()
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
	if guide != null:
		guide.observe(game, me)
		guide.visible = phase == "prep" and not choice.visible and not carousel.visible


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
	if phase == "over" or game == null or choice.visible or carousel.visible or not cursor.held.is_empty():
		card.hide_card()  # (lot ACX-2 : héros en main → la zone « Vendre » et l'aperçu des traits parlent, pas la fiche)
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
	_card_id = ""
	if not s.is_empty() and String(s.get("zone", "")) == "items":
		var it := board.item_at(s)
		if it != "":
			card.show_item(it, have_components())
		else:
			card.hide_card()
	elif not s.is_empty() and not board.unit_at(s).is_empty():
		card.show_unit(board.unit_at(s), _counts)
		_card_id = String(board.unit_at(s).get("id", ""))
	elif shop_id != "":
		card.show_unit({"id": shop_id, "stars": 1, "items": []}, _counts, true)
		_card_id = shop_id
	else:
		card.hide_card()
	if card.visible and target.size != Vector2.ZERO:
		var avoid := hud.frame_rects()
		if guide != null and guide.is_visible_in_tree():
			avoid.append(guide.get_global_rect())  # (lot ACX-3) la fiche évite aussi le guide
		card.place_near(target, avoid)


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
	# lot ACX-2 : héros du banc tenu (pas encore sur le plateau) → aperçu de ses traits dans la colonne (« Ombre 2 → 3 »)
	if phase == "prep" and game != null and not cursor.held.is_empty() and String(cursor.held.get("zone", "")) == "bench":
		var hu := board.unit_at(cursor.held)
		if not hu.is_empty():
			var on_board := false
			for u in game.players[me].board:
				on_board = on_board or String(u.id) == String(hu.id)
			if not on_board:
				rising = (AutochessData.unit(String(hu.id)).get("traits", []) as Array).duplicate()
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


## Composants du joueur (banc d'objets, puis composants seuls sur ses héros) : recettes de la fiche d'un composant.
func have_components() -> Array:
	var out: Array = []
	for it in game.players[me].items:
		if AutochessData.COMPONENTS.has(String(it)):
			out.append(String(it))
	for u in game.units_of(me):
		var lc := AutochessAi.loose_component(u)
		if lc != "":
			out.append(lc)
	return out


## Planificateur (lot ACX-3) : vise ou retire le héros montré par la fiche (T, clic du stick droit).
func _plan_toggle() -> void:
	if _card_id == "" or phase == "over":
		return
	var nm := AutochessData.unit_name(_card_id)
	var was := AutochessPlanner.is_planned(_card_id)
	var on := AutochessPlanner.toggle(_card_id)
	if on:
		hud.toast("%s visé · %d / %d" % [nm, AutochessPlanner.planned().size(), AutochessPlanner.MAX])
		UiFeel.cue("confirm", -12.0, 1.2)
	elif was:
		hud.toast("%s n'est plus visé" % nm)
	else:
		hud.toast("%d héros visés au plus" % AutochessPlanner.MAX)
	_dirty = true


# --- actions --------------------------------------------------------------------------------------------------------
func _can_act() -> bool:
	return phase == "prep" and not choice.visible and not carousel.visible and bool(game.players[me].alive)


## Noms des unités au survol pendant le combat (lot ACX-2 : aucun nom par défaut, BM-AUTO §7.2) : l'unité la plus
## proche de la souris (60 px au plus) montre son nom.
func _update_hover_names() -> void:
	var best: AutochessUnit = null
	if phase == "combat" and real and not Gamepad.active and camera != null and director.watched < director.arenas.size():
		var m := get_viewport().get_mouse_position()
		var best_d := AutochessHud.s(60.0)
		var a: Dictionary = director.arenas[director.watched]
		for side in 2:
			for n in a.nodes[side]:
				if not is_instance_valid(n) or (n as AutochessUnit).is_dead:
					continue
				var wp := (n as Node3D).global_position + Vector3.UP * 1.4
				if camera.is_position_behind(wp):
					continue
				var d := camera.unproject_position(wp).distance_to(m)
				if d < best_d:
					best_d = d
					best = n
	if best != _hover_unit:
		if is_instance_valid(_hover_unit):
			_hover_unit.set_name_shown(false)
		_hover_unit = best
		if best != null:
			best.set_name_shown(true)


## Étoiles de chaque unité du joueur (uid -> étoiles) et objets complets portés : avant / après une action (moments).
func _stars_map() -> Dictionary:
	var out := {}
	for u in game.units_of(me):
		out[int(u.uid)] = int(u.stars)
	return out


func _full_items() -> Dictionary:
	var out := {}
	for u in game.units_of(me):
		var n := 0
		for it in u.items:
			if not AutochessData.COMPONENTS.has(String(it)):
				n += 1
		out[int(u.uid)] = n
	return out


## Position à l'écran au-dessus de la figurine [param uid] (moments), centre de l'écran sinon.
func _figure_point(uid: int) -> Vector2:
	var f := board.figure(uid)
	var vs := get_viewport().get_visible_rect().size
	if f == null or camera == null:
		return vs * 0.5
	var wp := f.global_position + Vector3.UP * 2.2
	return camera.unproject_position(wp) if not camera.is_position_behind(wp) else vs * 0.5


## Fusions de la dernière action ([param before] : _stars_map d'avant) : ★★ = éclat sur la figurine, ★★★ = bannière.
func _star_moments(before: Dictionary) -> void:
	if fast or autoplay:
		return
	board.set_state(game.players[me])  # figurines à jour (la fusion vient d'avoir lieu)
	for u in game.units_of(me):
		var uid := int(u.uid)
		var was := int(before.get(uid, 0))
		var now := int(u.stars)
		if now >= 3 and was < 3:
			moments.banner("Trois étoiles !", "soleil", AutochessData.unit_name(String(u.id)), "ui_star", -6.0, 1.0,
				[0.35, 0.5, 0.25], 0.9)
			UiFeel.confetti(_figure_point(uid), 24)
		elif now == 2 and was < 2:
			moments.burst(_figure_point(uid), "★★ !", "soleil", "ui_star", -9.0, 1.2, [0.25, 0.15, 0.08])


func _buy(slot: int) -> void:
	if phase != "prep":
		return
	var p: Dictionary = game.players[me]
	var id := String(p.shop[slot]) if slot < (p.shop as Array).size() else ""
	if id == "":
		return
	var before := _stars_map()
	if game.buy(me, slot):
		Sfx.ui("confirm", -8.0)
		_star_moments(before)
		_dirty = true
		if guide != null:
			guide.step_done("buy")
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
			if not fast and not autoplay:
				var r := hud.xp_button.get_global_rect()
				moments.burst(Vector2(r.get_center().x, r.position.y - AutochessHud.s(24.0)), "Niveau %d !" % int(p.level), "lagon",
					"ui_level_up", -10.0, 1.0, [0.2, 0.1, 0.07])
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


## Vitesse du combat : ×1 → ×2 → ×3 → ×1 (lot ACX-2 : ×3 ; touches 1, 2, 3 pendant le combat).
func _toggle_speed() -> void:
	_set_speed(speed % 3 + 1)


func _set_speed(v: int) -> void:
	speed = clampi(v, 1, 3)
	if director != null:
		director.set_speed(float(speed))  # Engine.time_scale pendant le vrai combat seulement
	hud.set_combat(_combat_text, _phase_t / maxf(_phase_len, 0.01), speed)


## Passer le combat (lot ACX-2, BM-AUTO §6 n° 11) : fin tout de suite au combat de données (même couche d'effets, à
## partir de l'état du moment : « résultat calculé »).
func _skip() -> void:
	if phase != "combat":
		return
	if real:
		director.skip()
	else:
		_phase_t = _phase_len


## Annuler la dernière action de préparation (lot ACX-2) : Autochess.undo (achat, vente, déplacement, objet donné).
func _undo() -> void:
	if not _can_act() or spectating:
		return
	cursor.cancel()
	var what := game.undo(me)
	if what == "":
		hud.toast("Rien à annuler")
		return
	hud.toast(String({"buy": "Achat annulé", "sell": "Vente annulée", "move": "Déplacement annulé",
		"item": "Objet repris"}.get(what, "Annulé")))
	UiFeel.cue("ui_tab", -10.0, 0.9)
	_dirty = true


## Vente d'un héros précieux sans maintien (curseur) : « Vendre ? » d'abord (BIBLE §6 : destructif = confirmation).
func _confirm_sell(s: Dictionary) -> void:
	var u := board.unit_at(s)
	if u.is_empty() or phase != "prep":
		return
	var items := (u.get("items", []) as Array).size()
	var text := "+%d or%s. Annulable ensuite (Ctrl+Z)." % [board.sell_value(s), " · ses objets reviennent au banc" if items > 0 else ""]
	InfoCard.ask(self, "Vendre %s %s ?" % [AutochessData.unit_name(String(u.id)), "★".repeat(clampi(int(u.stars), 1, 3))], text,
		"Vendre", _sell_slot.bind(s), true)


func _sell_slot(s: Dictionary) -> void:
	if phase == "prep" and not board.unit_at(s).is_empty():
		board.sell(s)


## Raccourci W : le héros sous le curseur passe du banc au plateau (première case libre de sa place) ou l'inverse.
func _swap_bench_board() -> void:
	if not _can_act():
		return
	var s := cursor.slot
	var u := board.unit_at(s) if not s.is_empty() else {}
	if u.is_empty():
		return
	var uid := int(u.get("uid", 0))
	if String(s.zone) == "bench":
		var cell := game.free_cell(me, String(AutochessData.unit(String(u.id)).get("place", "milieu")))
		if game.players[me].board.size() >= game.board_cap(me) or cell.x < 0:
			hud.toast("Plateau plein")
			return
		if game.place(me, uid, cell) and guide != null:
			guide.step_done("place")
	elif String(s.zone) == "board":
		if not game.to_bench(me, uid):
			hud.toast("Banc plein")
			return
	_dirty = true


## Q / R : plateau du stratège précédent / suivant (préparation), combat précédent / suivant (combat), stratège regardé
## (spectateur).
func _cycle_view(d: int) -> void:
	if spectating:
		_spec_step(d)
		return
	var others: Array = game.alive_ids().filter(func(x): return int(x) != me)
	if others.is_empty():
		return
	if phase == "combat" and real:
		var n := director.arenas.size()
		if n > 1:
			var i := posmod(director.watched + d, n)
			_watch_fight(i)
		return
	if phase != "prep":
		return
	var k := others.find(scouted)
	var next := int(others[posmod(k + d, others.size())]) if k >= 0 else int(others[0 if d > 0 else others.size() - 1])
	_scout(next)


## Espace en combat : retour à son propre combat s'il en regarde un autre, sinon la vitesse.
func _space_combat() -> void:
	if real and my_fight >= 0 and director.watched != my_fight:
		_watch_fight(my_fight)
	else:
		_toggle_speed()


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
				if game.place(me, uid, Vector2i(int(to.col), int(to.row))) and guide != null:
					guide.step_done("place")
			"bench":
				game.to_bench(me, uid, int(to.index))
	_dirty = true


func _on_sold(u: Dictionary, _from: Dictionary) -> void:
	if phase == "prep":
		var gold := int(game.players[me].gold)
		if game.sell(me, int(u.get("uid", 0))):
			hud.toast("+%d or · Ctrl+Z pour annuler" % (int(game.players[me].gold) - gold) if not Gamepad.active
				else "+%d or · %s pour annuler" % [int(game.players[me].gold) - gold, Settings.pad_name(JOY_BUTTON_BACK)])
			Sfx.ui("gold", -6.0)
	_dirty = true


func _on_item(it: String, u: Dictionary, _from: Dictionary) -> void:
	if phase == "prep":
		var idx := (game.players[me].items as Array).find(it)
		var before := _full_items()
		if idx < 0 or not game.equip(me, idx, int(u.get("uid", 0))):
			hud.toast("Cet objet ne va pas sur ce héros")
		elif not fast and not autoplay:
			var uid := int(u.get("uid", 0))
			if int(_full_items().get(uid, 0)) > int(before.get(uid, 0)) and AutochessData.COMPONENTS.has(it):
				board.set_state(game.players[me])
				moments.burst(_figure_point(uid), "Objet complet !", "amethyste", "confirm", -5.0, 1.35, [0.25, 0.2, 0.1])
	_dirty = true


func _on_choice(i: int) -> void:
	var c := game.pending(me)
	if c.is_empty():
		choice.visible = false
		return
	var kind := String(c.kind)
	var opt: Variant = (c.options as Array)[i] if i < (c.options as Array).size() else null
	var before := _stars_map()
	if not game.choose(me, i):
		return
	_star_moments(before)
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
	if spectating and pi >= 0 and bool(game.players[pi].alive):
		_spec_watch = pi  # le spectateur suit ce stratège (combat suivant compris)
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
	if phase == "combat" or phase == "recap":
		get_tree().paused = true  # vraie pause (lot ACX-2) : le combat s'arrête aussi
	var buttons: Array = [{"label": "Reprendre", "kind": "primary"}]
	if spectating or phase == "out":
		buttons.append({"label": "Bilan", "kind": "plain", "cb": _out_to_end})
	else:
		buttons.append({"label": "Réglages", "kind": "plain", "cb": _options_card})
	buttons.append({"label": "Menu principal", "kind": "plain", "cb": _quit})
	if not spectating and phase != "out":
		buttons.append({"label": "Abandonner", "kind": "link", "cb": _ask_abandon})
	cards.add_card({"id": "pause", "title": "Pause",
		"body": "Tu regardes la fin de la partie : ta place est gardée." if spectating
			else "La partie est gardée au début de chaque manche.",
		"buttons": buttons, "on_close": _unpause})


var _opt_open := false  # la carte des réglages est (ou va être) ouverte : la pause continue


func _unpause(_how := "") -> void:
	if _opt_open:
		return  # les réglages s'ouvrent à la place de la pause : elle continue
	_paused = false
	get_tree().paused = false


## Réglages de l'Échiquier (lot ACX-2) : une ligne par réglage, le bouton bascule et la carte se refait.
func _options_card() -> void:
	_paused = true
	_opt_open = true
	var on_off := func(k: String) -> String: return "oui" if opt(k) else "non"
	cards.add_card({"id": "ac_options", "title": "Réglages de l'Échiquier",
		"lines": ["Préparation sans minuteur : %s" % on_off.call("no_timer"), "Noms au-dessus des héros : %s" % on_off.call("names"),
			"Bilan à chaque manche : %s" % on_off.call("recap_always")],
		"buttons": [{"label": "Minuteur", "kind": "plain", "cb": _toggle_opt.bind("no_timer")},
			{"label": "Noms", "kind": "plain", "cb": _toggle_opt.bind("names")},
			{"label": "Bilan", "kind": "plain", "cb": _toggle_opt.bind("recap_always")},
			{"label": "Fermer", "kind": "primary", "cb": func(): _opt_reopen = false}],
		"on_close": _options_closed})


var _opt_reopen := false


func _toggle_opt(key: String) -> void:
	set_opt(key, not opt(key))
	_opt_reopen = true


func _options_closed(_how: String) -> void:
	if _opt_reopen:
		_opt_reopen = false
		_options_card.call_deferred()  # la carte se refait avec la nouvelle valeur
		return
	_opt_open = false
	_paused = false
	get_tree().paused = false


## Change un réglage de l'Échiquier (gardé dans les Paramètres) ; sans minuteur : le minuteur en cours disparaît.
func set_opt(key: String, on: bool) -> void:
	Settings.set_v("autochess", key, on)
	match key:
		"names":
			AutochessUnit.show_names = on
		"no_timer":
			if phase == "prep" and not autoplay and not spectating:
				timer_total = 0.0 if on else game.prep_time()
				timer = 1.0e9 if on else timer_total


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
	if phase != "prep" or cards == null or cards.count() > 0 or autoplay or guide != null:
		return  # (lot ACX-3 : la première partie guidée remplace ces fiches)
	for id in TIPS:
		if Tutorial.card_pending(id) and _tip_due(id):
			Tutorial.mark_seen(id)
			var spec := Tutorial.card_spec(id)
			spec["duration"] = 20.0
			spec["buttons"] = [{"label": "Compris", "kind": "primary"},
				{"label": "Guide", "kind": "plain", "cb": func(): Guide.open_on(self, id)}]
			if id == "ac_shop" and not opt("no_timer"):
				# lot ACX-2 (BM-AUTO Q10) : le réglage « sans minuteur » proposé à la 1re partie, dans la fiche de la boutique
				spec["buttons"].append({"label": "Jouer sans minuteur", "kind": "link", "cb": set_opt.bind("no_timer", true)})
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
		JOY_BUTTON_BACK:
			if _can_act():
				_undo()  # lot ACX-2 : bouton Vue = annuler
				get_viewport().set_input_as_handled()
		JOY_BUTTON_X:
			if phase == "combat":
				_skip()  # lot ACX-2 : passer le combat (le curseur de cases est coupé en combat)
				get_viewport().set_input_as_handled()
		JOY_BUTTON_RIGHT_STICK:
			_plan_toggle()  # lot ACX-3 : planificateur
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
	if phase == "combat" and k in [KEY_1, KEY_2, KEY_3]:
		_set_speed(k - KEY_1 + 1)  # lot ACX-2 : 1, 2, 3 = vitesse en combat
		get_viewport().set_input_as_handled()
		return
	var used := true
	match k:
		KEY_Z when ke.ctrl_pressed:
			_undo()
		KEY_BACKSPACE:
			_undo()
		KEY_W:
			_swap_bench_board()
		KEY_Q:
			_cycle_view(-1)
		KEY_R:
			_cycle_view(1)
		KEY_P:
			_skip()
		KEY_T:
			_plan_toggle()
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
				_space_combat()
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
