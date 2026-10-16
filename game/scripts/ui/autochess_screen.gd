class_name AutochessScreen
extends Node3D
## L'Échiquier (lot AC-G) : l'écran jouable (scenes/autochess.tscn). Monte le plateau (AC-F : AutochessBoard, curseur),
## le cadre (AutochessHud : boutique, traits, stratèges, frise, minuteur), les choix (AutochessChoicePanel, AutochessCarousel)
## et la partie (AC-B : Autochess) contre 7 stratèges au hasard (Autochess.RandomStrategist) avec le combat provisoire
## (Autochess.power_fight, montré COMBAT_SHOW s) : une partie complète se joue déjà de bout en bout, souris ou manette.
## Les lots suivants remplacent les stratèges (AC-D), le combat (AC-E / AC-C) et l'entrée / la fin (AC-I).
##   godot --path game res://scenes/autochess.tscn [-- --seed=N --ac-resume --autoplay]
## Commandes : manette (UiNav sur le plateau et les panneaux, A prend / pose / achète, X maintenu vend, Y Prêt, LB XP,
## RB boutique, LT actualiser, RT verrou, Start pause) ; clavier 1-5 achète, D actualise, F XP, V verrou, E vend,
## Espace Prêt, Échap pause ; souris : clic ou glisser-déposer. Rapport : conception/autochess/R_AC_G.md.

const COMBAT_SHOW := 3.0  # s (×1) : combat provisoire montré avant le bilan (power_fight est instantané)
const OPENING_RECAP := 0.6  # s : manches sans combat (ouverture, choix partagé)
const CAROUSEL_END := 1.2  # s : l'anneau reste ouvert une fois tous les choix faits
const AUTOPLAY_PREP := 0.4  # s de préparation au pilote automatique
const TRIGGER_ON := 0.6
## Noms des stratèges adverses (tirés à la graine de la partie : une partie reprise garde les mêmes).
const AI_NAMES := ["Aldric", "Bérénice", "Corentin", "Daphné", "Élouan", "Faustine", "Gauvain", "Héloïse", "Ysolde",
	"Perceval", "Mélisende", "Tristan", "Aliénor", "Baudouin"]

static var speed := 1  # vitesse du combat montré (×1 / ×2), gardée entre les parties
## Réglages de lancement (tests, AC-I) : seed, resume, save_path, autoplay, fast (durées réduites).
static var config := {}

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
	var seed_ := int(cfg.get("seed", 0))
	var resume := bool(cfg.get("resume", false))
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--seed="):
			seed_ = int(a.get_slice("=", 1))
		elif a == "--ac-resume":
			resume = true
		elif a == "--autoplay":
			autoplay = true
	_build_world()
	board = AutochessBoard.new()
	add_child(board)
	camera = Camera3D.new()
	add_child(camera)
	camera.current = true
	board.frame_camera(camera, 0)
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
	cursor.zoom_changed.connect(func(_z): _dirty = true)
	hud.reroll_pressed.connect(_reroll)
	hud.xp_pressed.connect(_buy_xp)
	hud.lock_pressed.connect(_lock)
	hud.ready_pressed.connect(_ready_pressed)
	hud.speed_pressed.connect(_toggle_speed)
	hud.choice_pressed.connect(func():
		_choice_hidden = false
		_open_choices())
	hud.replay_pressed.connect(func(): new_game(randi(), false))
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
	var strats: Array = [null]
	for i in AutochessData.PLAYERS - 1:
		strats.append(Autochess.RandomStrategist.new())
	game = null
	if resume:
		game = Autochess.load_game(save_path, strats)
	if game == null:
		game = Autochess.new()
		game.save_path = save_path
		game.start(seed_, strats)
	game.changed.connect(func(_pi): _dirty = true)
	_make_identities()
	hud.players.identities = identities
	hud.players.history.clear()
	scouted = -1
	foe = -1
	_choice_hidden = false
	hud.set_mode("prep")
	_enter_prep()


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
		Autochess.RandomStrategist.new().decide(game, me)
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


func _resolve_combat() -> void:
	game.run_fights()
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
	cursor.enabled = false
	choice.visible = false
	carousel.visible = false
	var p: Dictionary = game.players[me]
	var place := int(p.place) if int(p.place) > 0 else 1
	hud.show_end(place, "Manches gagnées : %d\nOr dépensé : %d" % [int(p.stats.won), int(p.stats.gold_spent)])
	print("[autochess] fin : place %d, manches %d (%s)" % [place, game.rounds_played, game.round_key()])


# --- boucle ---------------------------------------------------------------------------------------------------------
func _process(delta: float) -> void:
	if game == null:
		return
	if _dirty:
		_sync()
	hud.set_holding(not cursor.held.is_empty() and String(cursor.held.get("zone", "")) != "items")
	hud.set_overlay(choice.visible or carousel.visible, carousel.visible)
	_update_card()
	match phase:
		"prep":
			if not _paused:
				timer -= delta
			_tick_carousel(delta)
			hud.set_timer(timer, timer_total)
			if timer <= 0.0:
				_end_prep()
		"combat":
			_phase_t += delta * speed
			hud.set_combat(_combat_text, _phase_t / maxf(_phase_len, 0.01), speed)
			hud.set_timer(0.0, 0.0)
			if _phase_t >= _phase_len:
				_resolve_combat()
		"recap":
			_phase_t += delta
			if _phase_t >= _phase_len:
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


## Fiche d'unité : ce que vise la manette (case, carte de la boutique) ou la souris.
func _update_card() -> void:
	var card := hud.unit_card
	if phase == "over" or game == null or choice.visible or carousel.visible:
		card.hide_card()
		hud.traits.visible = true
		return
	var s: Dictionary = {}
	var shop_id := ""
	if Gamepad.active and UiNav.nav_on():
		var c: Control = UiNav.cursor if UiNav.cursor != null and is_instance_valid(UiNav.cursor) else null
		if c != null and c.has_meta("ac_slot"):
			s = c.get_meta("ac_slot")
		elif c != null and c.has_meta("ac_shop"):
			shop_id = String(c.get_meta("unit_id", ""))
	elif hud.shop.hovered >= 0 and hud.shop.cards[hud.shop.hovered].is_visible_in_tree():
		shop_id = String((hud.shop.cards[hud.shop.hovered] as Control).get_meta("unit_id", ""))
	elif cursor.enabled:
		s = cursor.slot
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
	hud.traits.visible = not card.visible


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
	hud.set_combat(_combat_text, _phase_t / maxf(_phase_len, 0.01), speed)


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
	get_tree().change_scene_to_file("res://scenes/lobby.tscn")


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
## Fond bleu nuit, lumière, sol sombre (comme la démonstration du plateau).
func _build_world() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.035, 0.04, 0.10)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.58, 0.85)
	env.ambient_light_energy = 0.75
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.glow_intensity = 0.5
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(deg_to_rad(-58.0), deg_to_rad(-28.0), 0.0)
	sun.light_energy = 1.15
	sun.light_color = Color(1.0, 0.95, 0.86)
	sun.shadow_enabled = true
	add_child(sun)
	var floor_ := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = AutochessData.ARENA_RADIUS + 25.0
	cm.bottom_radius = cm.top_radius
	cm.height = 0.2
	cm.radial_segments = 64
	floor_.mesh = cm
	floor_.position.y = -0.6
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.045, 0.05, 0.12)
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	floor_.material_override = m
	add_child(floor_)
