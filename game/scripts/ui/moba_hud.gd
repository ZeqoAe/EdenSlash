class_name MobaHud
extends Control
## HUD des Deux Voies (lot MB-H ; étude conception/benchmark/MOBA.md § 7.7-7.9, croquis moba_maquettes/v2_hud.svg ; DA v2
## « autocollant manga » : UiTheme, RoyaleHudStyle, UiFeel, Mochiy Pop One / M PLUS Rounded 1c ; rapport R_MB_H.md). Posé par
## Hud._build quand Modes.current() == "moba", par-dessus le HUD commun (dont il cache les objectifs de la Survie, la mini-carte
## ronde et le niveau d'aide ; la barre de niveau montre le niveau de partie 1-12) :
## - en haut au centre, le TABLEAU de la partie : 4 + 4 portraits (niveau, réapparition sur les morts, anneau lagon = toi),
##   éliminations de chaque équipe sur sa couleur et son blason (TeamSigil), temps, tours debout, Sceaux, Bannière ; dessous, les
##   MINUTEURS d'objectifs (Gardien mandarine, Colosse améthyste, Marée puis fin au temps) ; une seule ANNONCE à la fois (HudAlert,
##   file à priorités : premier sang, tour, objectif, série, Marée) et les onomatopées au-dessus du héros ;
## - en haut à droite, la MINI-CARTE entière (voies, tours, Cœurs, camps, fosses, sbires, héros, brouillard tramé hors de la vue
##   de l'équipe, cadre de la caméra, repères ; maintenir le clic regarde ailleurs sans bouger, [M] / Vue l'agrandit) et le FIL
##   des éliminations ;
## - à gauche, les 3 ALLIÉS (PV, niveau, ultime prêt, ce qu'ils font) ;
## - sur la barre d'action : PLOTS d'enchaînements sous chaque case (pomme = débloqué), ultime cerclé de soleil, verrouillé
##   « niv. 5 » ; CHOIX DE NIVEAU non bloquant (Ctrl + 1 / 2 / 3, clic sur la case, [G] / → croix : le conseillé) ; RAPPEL [X] ;
## - en bas à droite, l'OR, la boutique ([P] ; Vue à la base) et l'OBJET CONSEILLÉ avec sa barre (« 1 240 / 2 300 »), les 6 objets ;
## - TABLEAU DES SCORES tant que [Tab] / ← croix est tenu ; ÉCRAN DE MORT (minuteur, qui t'a battu, boutique, regarder un allié) ;
## - REPÈRES (molette / L3 : appui = selon ce que tu vises, maintien = roue) : MobaPings, lus par le coach d'équipe (lot MB-G).
## Aucune règle ne change ici : tout se lit sur MobaDirector (rd.team), MobaHero, MobaItems, MobaJungle et Moba ; les seules
## écritures passent par les appels publics du directeur (choose_chain) et de la boutique (MobaStore -> MobaItems).

static var current: MobaHud

const BAND_W := 640.0
const BAND_H := 74.0
const PORT := 44.0
const PORT_GAP := 6.0
const OBJ_H := 34.0
const MAP_SIZE := Vector2(294, 190)
const MAP_BIG := Vector2(1000, 640)
const ALLY_W := 240.0
const ALLY_H := 64.0
const ALLY_Y := 250.0
const GOLD_SIZE := Vector2(300, 150)
const FEED_LIFE := 8.0
const VISION := 25.0  # m : un adversaire n'est montré que vu par un allié ou une structure alliée (MOBA.md § 7.8)
const FOG_RES := Vector2i(100, 60)  # brouillard : 2 m par pixel sur l'aire de jeu (200 × 120 m)
const DATA_EVERY := 0.25
const DRAW_EVERY := 0.1
const SEEN_EVERY := 0.33
const PING_HOLD := 0.25  # s : un appui plus long ouvre la roue
const LANE_SHORT := ["Soleil", "Brumes"]
const WORDS_TONES := {"Premier sang !": RoyaleHudStyle.STRAWBERRY, "K.O. !": RoyaleHudStyle.SUN, "Tour !": RoyaleHudStyle.MANDARIN,
	"Niveau !": RoyaleHudStyle.LAGOON, "Série !": RoyaleHudStyle.AMETHYST, "Gardien !": RoyaleHudStyle.MANDARIN, "Colosse !": RoyaleHudStyle.AMETHYST}

var hud: Hud
var player: Player
var rd: RunDirector
var data: Dictionary = {}  # MobaDirector.hud_data du joueur, 4 fois par seconde
var seen: Dictionary = {}  # adversaire (héros, sbire) -> vrai : vu par l'équipe (3 fois par seconde)
var feed: Array = []  # [{text, tone, t, a, a_side, b, b_side}]
var recap: Dictionary = {}  # récapitulatif de la dernière mort du joueur
var hits: Array = []  # coups reçus des 10 dernières secondes : {t, amount, name, move}
var announce: Announcer
var band: ScoreBand
var objs: ObjRow
var allies: AllyColumn
var minimap: MobaMinimap
var column: FeedColumn
var marks: Array = []  # SlotMark par case
var choice: ChoiceStrip
var gold_box: GoldBox
var recall: RecallCell
var death: DeathCard
var board: ScoreBoard
var wheel: PingWheel
var pins: PingPins
var store: MobaStore
var store_layer: CanvasLayer
var words: RoyaleAnnounce  # (onomatopées seules : « Premier sang ! », « Tour ! », « Niveau ! »)
var cost_us := 0.0  # (mesures) temps de la dernière mise à jour
var _data_t := 0.0
var _draw_t := 0.0
var _seen_t := 0.0
var _events_seen := 0
var _first_blood_said := false
var _icons: Dictionary = {}
var _look: Node3D  # point regardé quand le clic est tenu sur la mini-carte
var _look_prev: Node3D
var _ping_down := -1.0
var _ping_screen := Vector2.ZERO
var _spectate := -1
var _was_dead := false
var _last_level := 1


## Pose le HUD des Deux Voies sur [param h] (après Hud._build).
static func attach(h: Hud, root: Control) -> MobaHud:
	var m := MobaHud.new()
	m.hud = h
	m.player = h.player
	m.rd = h.director
	m.name = "MobaHud"
	m.set_anchors_preset(Control.PRESET_FULL_RECT)
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	HitArc.attach(root, m.player)  # (arc de coup reçu, comme le Duel et le Battle royale)
	root.add_child(m)
	m._build()
	current = m
	return m


func _exit_tree() -> void:
	if current == self:
		current = null
	if store_layer != null and is_instance_valid(store_layer) and get_tree() != null and get_tree().paused and store != null and store.paused_by_me:
		get_tree().paused = false


## Directeur du mode (null tant qu'il n'est pas monté).
func dd() -> MobaDirector:
	if rd == null or not is_instance_valid(rd.team):
		return null
	return rd.team as MobaDirector


## État de partie du joueur (null en spectateur).
func me() -> MobaHero:
	var d := dd()
	if d == null or player == null:
		return null
	return d.info.get(player) as MobaHero


func _area() -> Vector2:
	return size if size.x > 1.0 else (get_viewport_rect().size if is_inside_tree() else Vector2(1600, 900))


func k() -> float:
	return clampf(_area().y / 900.0, 0.8, 1.0)


func _build() -> void:
	MobaPings.reset()
	for key in ["_obj_panel", "_assist_label", "_map_holder"]:
		var c = hud.get(key)
		if c is CanvasItem:
			(c as CanvasItem).visible = false
	pins = PingPins.new()
	pins.h = self
	add_child(pins)
	band = ScoreBand.new()
	band.h = self
	add_child(band)
	for t in 2:
		var s := TeamSigil.make(t, 20)
		s.name = "Sigil%d" % t
		band.add_child(s)
		s.position = Vector2(BAND_W * 0.5 - 98.0, 6.0) if t == 0 else Vector2(BAND_W * 0.5 + 78.0, 6.0)
		s.size = Vector2(20, 20)
	objs = ObjRow.new()
	objs.h = self
	add_child(objs)
	allies = AllyColumn.new()
	allies.h = self
	add_child(allies)
	minimap = MobaMinimap.new()
	minimap.h = self
	add_child(minimap)
	column = FeedColumn.new()
	column.h = self
	add_child(column)
	gold_box = GoldBox.new()
	gold_box.h = self
	add_child(gold_box)
	var bar: Control = hud.get("_action_root")
	if bar != null:
		var slots: Array = hud.get("_slots")
		for i in slots.size():
			var m := SlotMark.new()
			m.h = self
			m.slot = i
			m.position = (slots[i] as Control).position
			m.size = (slots[i] as Control).size
			bar.add_child(m)
			marks.append(m)
		recall = RecallCell.new()
		recall.h = self
		recall.position = Vector2(Hud.POTION_X - 62.0, Hud.SLOT_Y + 6.0)
		recall.size = Vector2(50, 50)
		bar.add_child(recall)
	choice = ChoiceStrip.new()
	choice.h = self
	add_child(choice)
	death = DeathCard.new()
	death.h = self
	add_child(death)
	board = ScoreBoard.new()
	board.h = self
	board.visible = false
	add_child(board)
	wheel = PingWheel.new()
	wheel.h = self
	wheel.visible = false
	add_child(wheel)
	announce = Announcer.new()
	announce.h = self
	add_child(announce)
	words = RoyaleAnnounce.new()
	words.player = player
	add_child(words)
	if player != null:
		player.damaged.connect(_on_player_hit)
		player.died.connect(_on_player_died)
	_layout()


# --- mise en page ----------------------------------------------------------------------------------------------------

func _layout() -> void:
	var a := _area()
	var kk := k()
	var sc := Vector2(kk, kk)
	band.scale = sc
	band.size = Vector2(BAND_W, BAND_H)
	band.position = Vector2(roundf((a.x - BAND_W * kk) * 0.5), 8.0)
	objs.scale = sc
	objs.size = Vector2(BAND_W + 120.0, OBJ_H + 4.0)
	objs.position = Vector2(roundf((a.x - objs.size.x * kk) * 0.5), band.position.y + (BAND_H + 6.0) * kk)
	var big := minimap.big
	var bar_top := a.y - 204.0
	if big:
		# grande carte : entre les minuteurs et la barre d'action, aux proportions de l'aire de jeu
		var top := objs.position.y + (OBJ_H + 14.0) * kk
		var hh := minf(MAP_BIG.y * kk, bar_top - top - 10.0)
		var bs := Vector2(minf(hh * MAP_BIG.x / MAP_BIG.y, a.x - 40.0), hh)
		minimap.scale = Vector2.ONE
		minimap.size = bs.round()
		minimap.position = Vector2(roundf((a.x - bs.x) * 0.5), roundf(top))
	else:
		minimap.scale = sc
		minimap.size = MAP_SIZE
		minimap.position = Vector2(a.x - (MAP_SIZE.x + 14.0) * kk, 12.0)
	column.scale = sc
	column.size = Vector2(MAP_SIZE.x, 200.0)
	column.position = Vector2(a.x - (MAP_SIZE.x + 14.0) * kk, 12.0 + (MAP_SIZE.y + 10.0) * kk)
	column.visible = not big
	allies.scale = sc
	allies.size = Vector2(ALLY_W, (ALLY_H + 8.0) * 3.0)
	allies.position = Vector2(14.0, ALLY_Y * kk)
	gold_box.scale = sc
	gold_box.size = GOLD_SIZE
	gold_box.position = Vector2(a.x - (GOLD_SIZE.x + 16.0) * kk, a.y - (GOLD_SIZE.y + 30.0) * kk)  # (au-dessus du numéro de version)
	choice.scale = sc
	choice.visible = not big
	choice.size = Vector2(560, 44)
	choice.position = Vector2(roundf((a.x - 560.0 * kk) * 0.5), bar_top - 50.0 * kk)
	death.scale = sc
	death.size = DeathCard.SIZE
	death.position = Vector2(roundf((a.x - DeathCard.SIZE.x * kk) * 0.5), maxf(objs.position.y + 60.0 * kk, a.y - (DeathCard.SIZE.y + 70.0) * kk))
	board.scale = sc
	board.size = ScoreBoard.SIZE
	board.position = ((a - ScoreBoard.SIZE * kk) * 0.5).round()
	wheel.size = a
	pins.size = a
	# cadre de cible (et barre de boss) sous les minuteurs d'objectifs ; les annonces sous lui
	var below := objs.position.y + (OBJ_H + 8.0) * kk
	var tb: Control = hud.get("_target_box")
	if tb != null:
		tb.position.y = below
		if tb.visible:
			below = tb.position.y + tb.size.y + 6.0
	var bb: Control = hud.get("_boss_bar")
	if bb != null and bb.visible:
		bb.offset_top = objs.position.y + (OBJ_H + 8.0) * kk
		below = maxf(below, bb.offset_top + 70.0)
	announce.top_px = below + 8.0
	# la pile de gauche (quête suivie) : en haut à gauche, ou sous les minuteurs quand l'écran est étroit (sinon elle croiserait
	# leurs pastilles) ; les alliés toujours dessous, jamais sur la barre d'action
	var left: Control = hud.get("_left")
	var left_end := 12.0
	if left != null:
		left.position.y = 12.0 if a.x >= 1500.0 else roundf(objs.position.y + (OBJ_H + 8.0) * kk)
		left_end = left.position.y + (left.size.y if left.get_child_count() > 0 and left.visible else 0.0)
	allies.position.y = minf(maxf(ALLY_Y * kk, left_end + 10.0), bar_top - 60.0 - allies.size.y * kk)


func _process(delta: float) -> void:
	var d := dd()
	if d == null:
		return
	var t0 := Time.get_ticks_usec()
	tick(delta)
	cost_us = float(Time.get_ticks_usec() - t0)


## Une image du HUD (le test de coût l'appelle directement) : données, vue de l'équipe, mise en page, dessins à 10 i/s.
func tick(delta: float) -> void:
	var d := dd()
	if d == null:
		return
	_layout()
	var mh = hud.get("_map_holder")
	if mh is CanvasItem and (mh as CanvasItem).visible:
		(mh as CanvasItem).visible = false  # (Hud._apply_hud_prefs la remet à chaque réglage)
	_data_t -= delta
	if _data_t <= 0.0 or data.is_empty():
		_data_t = DATA_EVERY
		data = d.hud_data()
		_level_bar()
	_seen_t -= delta
	if _seen_t <= 0.0:
		_seen_t = SEEN_EVERY
		_update_seen(d)
	_events(d)
	_death_state(d)
	board.visible = Input.is_action_pressed("objectives") and not _store_open() and not d.ended
	_ping_tick(delta)
	_draw_t -= delta
	if _draw_t <= 0.0:
		_draw_t = DRAW_EVERY
		for c in [band, objs, allies, minimap, column, gold_box, choice, death]:
			(c as CanvasItem).queue_redraw()
		for m in marks:
			(m as CanvasItem).queue_redraw()
		if recall != null:
			recall.queue_redraw()
		if board.visible:
			board.queue_redraw()
	if recall != null and me() != null and me().recalling():
		recall.queue_redraw()
	if not MobaPings.list.is_empty() or pins._shown > 0:
		pins.queue_redraw()
	if wheel.visible:
		wheel.queue_redraw()
	announce.tick(delta)


## Barre de niveau du HUD commun : le niveau de partie (1-12) et son XP (jamais le niveau de la fiche).
func _level_bar() -> void:
	var lb = hud.get("_xp_orb")
	if lb == null or data.is_empty():
		return
	var lv := int(data.level)
	var ratio := 1.0 if lv >= MobaData.LEVEL_MAX else clampf(float(data.xp) / maxf(float(data.xp_next), 1.0), 0.0, 1.0)
	lb.set_level(ratio, lv)
	if lv > _last_level:
		lb.flash = 1.0
	_last_level = lv
	(lb as Control).tooltip_text = "Niveau de partie %d sur %d · %d / %d XP" % [lv, MobaData.LEVEL_MAX, int(data.xp), int(data.xp_next)] \
		if lv < MobaData.LEVEL_MAX else "Niveau de partie maximal (%d)" % MobaData.LEVEL_MAX


# --- vue de l'équipe ---------------------------------------------------------------------------------------------------

## Ceux qui voient pour l'équipe du joueur : héros alliés debout et structures alliées debout.
func viewers(d: MobaDirector) -> Array:
	var me_side := TeamMatch.player_team
	var out: Array = []
	for h in d.heroes:
		var hs: MobaHero = d.info[h]
		if hs.side == me_side and not h.is_dead and (h.visible or h == player):
			out.append(h.global_position)
	for s in d.structures:
		if s.side == me_side and not s.is_dead:
			out.append(s.global_position)
	return out


func _update_seen(d: MobaDirector) -> void:
	seen.clear()
	var vs := viewers(d)
	var r2 := VISION * VISION
	var foe := 1 - TeamMatch.player_team
	for list in [d.heroes, d.minions]:
		for u in list:
			if u.is_dead or not u.visible or d.side_of(u) != foe:
				continue
			var p: Vector3 = u.global_position
			for v in vs:
				if (v as Vector3).distance_squared_to(p) <= r2:
					seen[u] = true
					break
	minimap.update_fog(vs)


## L'adversaire [param u] est-il vu par l'équipe ?
func is_seen(u: Node) -> bool:
	return seen.has(u)


# --- événements de la partie : fil et annonces --------------------------------------------------------------------------

func _events(d: MobaDirector) -> void:
	var ev: Array = Moba.events
	while _events_seen < ev.size():
		var e: Dictionary = ev[_events_seen]
		_events_seen += 1
		_on_event(d, e)


func _on_event(d: MobaDirector, e: Dictionary) -> void:
	var me_side := TeamMatch.player_team
	match String(e.type):
		"ko":
			var victim := String(e.get("who", ""))
			var killer := String(e.get("by", ""))
			var vside := int(e.side)
			add_feed({"a": killer, "a_side": 1 - vside if killer != "" else -1, "b": victim, "b_side": vside})
			if killer == "":
				return
			var kh := hero_of(d, killer)
			if not _first_blood_said:
				_first_blood_said = true
				var good := vside != me_side
				announce.push("Premier sang !", "%s élimine %s" % [name_of(killer), name_of(victim)], 3, "soleil" if good else "fraise", 2.4)
				if kh != null and kh.is_player:
					word("Premier sang !")
			elif kh != null and kh.streak >= 3 and kh.streak % 2 == 1:
				announce.push("Série !", "%s : %d éliminations de suite" % [name_of(killer), kh.streak], 2, "amethyste" if kh.side == me_side else "fraise", 2.2)
				if kh.is_player:
					word("Série !")
			if kh != null and kh.is_player:
				word("K.O. !")
		"tower":
			var lane := int(e.get("lane", 0))
			var mine := int(e.side) == me_side
			add_feed({"text": "%s · tour T%d tombée" % [LANE_SHORT[clampi(lane, 0, 1)], int(e.get("tier", 1))] if not mine
				else "Notre tour T%d (%s) tombe" % [int(e.get("tier", 1)), LANE_SHORT[clampi(lane, 0, 1)]], "tone": "soleil" if not mine else "fraise"})
			if not mine:
				word("Tour !")
		"guardian", "colossus":
			var team := int(e.side)
			var nm := "Gardien" if String(e.type) == "guardian" else "Colosse"
			if team >= 0:
				add_feed({"text": "%s pris %s" % [nm, "par vous" if team == me_side else "par l'adversaire"], "tone": "soleil" if team == me_side else "fraise"})
				if team == me_side:
					word(nm + " !")
		"tide":
			add_feed({"text": "Marée finale", "tone": "fraise"})


func add_feed(e: Dictionary) -> void:
	e["t"] = Moba.t
	feed.append(e)
	if feed.size() > 8:
		feed.pop_front()
	column.queue_redraw()


func word(text: String) -> void:
	if words != null:
		words.word(text, WORDS_TONES.get(text, RoyaleHudStyle.SUN))


## Crochet de Hud.show_message : les messages du directeur et de la jungle deviennent des annonces du mode (une à la fois)
## ou nourrissent les pièces du HUD (choix de niveau, écran de mort, rappel). Faux : le HUD commun s'en charge.
func announce_message(text: String, duration: float) -> bool:
	for pre in Hud.FEED_PREFIXES:
		if text.begins_with(pre) and not text.contains("\n"):
			return false
	var lines := text.split("\n", false, 1)
	var title := String(lines[0]) if lines.size() > 0 else ""
	var sub := String(lines[1]) if lines.size() > 1 else ""
	var c := classify(title)
	match String(c[0]):
		"level":
			word("Niveau !")
			choice.pop()
			return true
		"death", "silent":
			return true
	announce.push(title, sub, int(c[1]), String(c[2]), duration)
	return true


## Sorte d'un message du mode d'après son titre : [sorte, rang, ton]. Rang : 0 discret, 1 information, 2 objectif, 3 danger
## ou moment fort.
static func classify(title: String) -> Array:
	if title.begins_with("Niveau "):
		return ["level", 1, "lagon"]
	if title.begins_with("Tu es tombé"):
		return ["death", 3, "fraise"]
	if title.begins_with("Retour à la fontaine") or title == "Retour coupé" or title == "Enchaînement débloqué":
		return ["minor", 0, "lagon"]
	if title.ends_with(" tombe !"):
		return ["tower_lost", 3, "fraise"]
	if title.ends_with(" détruite !"):
		return ["tower_won", 3, "soleil"]
	if title.contains("est à vous"):
		return ["objective_won", 3, "soleil"]
	if title.begins_with("L'équipe adverse prend"):
		return ["objective_lost", 3, "fraise"]
	if title.contains(" arrive dans "):
		return ["objective_soon", 2, "mandarine" if title.begins_with("Gardien") or title.contains("Gardien") else "amethyste"]
	if title.begins_with("Marée finale") or title.begins_with("La Marée"):
		return ["tide", 3, "fraise"]
	if title.begins_with("Plus qu'une minute"):
		return ["end_soon", 3, "mandarine"]
	if title.begins_with("Les Deux Voies"):
		return ["intro", 2, "soleil"]
	if title.contains("fureur"):
		return ["fury", 2, "amethyste"]
	return ["info", 1, "lagon"]


# --- mort du joueur ----------------------------------------------------------------------------------------------------

func _on_player_hit(amount: float, source: Combatant) -> void:
	var nm := "Coups"
	var move := ""
	if source != null and is_instance_valid(source):
		nm = source_name(source)
		var mv = source.get_meta("move", {}) if source.has_meta("move") else {}
		if mv is Dictionary:
			move = String((mv as Dictionary).get("name", ""))
	hits.append({"t": Moba.t, "amount": amount, "name": nm, "move": move})
	while not hits.is_empty() and Moba.t - float(hits[0].t) > 10.0:
		hits.pop_front()


func _on_player_died(_who: Combatant, killer: Combatant) -> void:
	var by := {}
	var total := 0.0
	for e in hits:
		if Moba.t - float(e.t) > 8.0:
			continue
		by[String(e.name)] = float(by.get(String(e.name), 0.0)) + float(e.amount)
		total += float(e.amount)
	var rows: Array = []
	for n in by:
		rows.append([String(n), float(by[n]) / maxf(total, 1.0)])
	rows.sort_custom(func(a, b): return float(a[1]) > float(b[1]))
	var kname := source_name(killer) if killer != null and is_instance_valid(killer) else (String(rows[0][0]) if not rows.is_empty() else "")
	var move := ""
	if killer != null and is_instance_valid(killer) and killer.has_meta("move"):
		var mv = killer.get_meta("move")
		if mv is Dictionary:
			move = String((mv as Dictionary).get("name", ""))
	var kcid := String(killer.get("cid")) if killer != null and is_instance_valid(killer) and killer.get("cid") != null else ""
	recap = {"killer": kname, "cid": kcid, "move": move, "hp": killer.hp / maxf(killer.max_hp, 1.0) if killer != null and is_instance_valid(killer) else -1.0,
		"rows": rows.slice(0, 3), "t": Moba.t}
	hits.clear()


## Nom court d'une source de coups : la classe d'un héros (« Toi »), « Tour », « Sbire », le nom d'un monstre.
func source_name(c: Combatant) -> String:
	if c == null or not is_instance_valid(c):
		return "Coups"
	if c == player:
		return "Toi"
	if c is MobaStructure:
		return "Cœur" if (c as MobaStructure).kind == "core" else "Tour"
	if c is MobaMinion:
		return String(MobaData.MINIONS.get((c as MobaMinion).kind, {}).get("name", "Sbire"))
	var d := dd()
	if d != null and d.info.has(c):
		return name_of(String((d.info[c] as MobaHero).cid))
	return String(c.display_name).replace("<Boss> ", "").get_slice(",", 0) if c.display_name != "" else "Coups"


func _death_state(d: MobaDirector) -> void:
	var dead := player != null and player.is_dead and not d.ended
	if dead != _was_dead:
		_was_dead = dead
		if not dead:
			_spectate = -1
			recap = {}
	death.visible = dead
	var bar: Control = hud.get("_action_root")
	if bar != null:
		bar.visible = not dead


## Mort : regarde l'allié suivant (caméra seule ; la réapparition la rend au héros).
func spectate_next() -> void:
	var d := dd()
	if d == null or d.d.world.rig == null:
		return
	var pool: Array = d.heroes.filter(func(h): return h != player and not h.is_dead and int((d.info[h] as MobaHero).side) == TeamMatch.player_team)
	if pool.is_empty():
		d.d.world.rig.target = player
		return
	_spectate = (_spectate + 1) % (pool.size() + 1)
	d.d.world.rig.target = pool[_spectate] if _spectate < pool.size() else player
	UiFeel.cue("ui_tab", -12.0)


# --- boutique, choix de niveau, entrées --------------------------------------------------------------------------------

func _store_open() -> bool:
	return store != null and is_instance_valid(store) and store.visible


## Ouvre ou ferme la boutique ([param pad] : ouverte à la manette, la partie attend : UiNav navigue l'écran).
func toggle_store(pad := false) -> void:
	if _store_open():
		store.close()
		return
	if store_layer == null:
		store_layer = CanvasLayer.new()
		store_layer.name = "MobaStoreLayer"
		store_layer.layer = 30
		store_layer.process_mode = Node.PROCESS_MODE_ALWAYS
		hud.add_child(store_layer)
	if store == null or not is_instance_valid(store):
		store = MobaStore.new()
		store_layer.add_child(store)
		store.setup(self)
	store.open(pad)
	board.visible = false


func choose(slot: int) -> bool:
	var d := dd()
	if d == null or player == null:
		return false
	var ok := d.choose_chain(player, slot)
	UiFeel.cue("ui_confirm" if ok else "ui_deny", -8.0)
	if ok:
		word("Niveau !")
	return ok


## Le choix conseillé (l'ordre préféré de la classe, MobaHero.auto_choice).
func choose_advised() -> bool:
	var hs := me()
	if hs == null or hs.pending.is_empty():
		return false
	return choose(hs.auto_choice())


func _input(ev: InputEvent) -> void:
	var d := dd()
	if d == null or d.ended or player == null or get_tree().paused:
		return
	var key := ev as InputEventKey
	if key != null and key.pressed and not key.echo:
		if key.ctrl_pressed and key.physical_keycode in [KEY_1, KEY_2, KEY_3]:
			get_viewport().set_input_as_handled()
			choose(key.physical_keycode - KEY_1)
			return
		if key.ctrl_pressed and key.physical_keycode == KEY_Z:
			get_viewport().set_input_as_handled()
			var hs := me()
			if hs != null and MobaItems.undo(hs):
				UiFeel.cue("ui_coin", -10.0, 0.85)
				announce.push("Achat annulé", "", 0, "lagon", 1.0)
			else:
				UiFeel.cue("ui_deny", -10.0)
			return
		if key.physical_keycode == KEY_P and not key.ctrl_pressed:
			get_viewport().set_input_as_handled()
			toggle_store(false)
			return
	if ev.is_action_pressed("quick_equip") and me() != null and not me().pending.is_empty():
		get_viewport().set_input_as_handled()
		choose_advised()
		return
	if ev.is_action_pressed("map"):
		get_viewport().set_input_as_handled()
		var hs := me()
		if ev is InputEventJoypadButton and hs != null and MobaItems.shop_open(hs):
			toggle_store(true)  # (manette : Vue à la base ouvre la boutique)
		else:
			minimap.big = not minimap.big
			UiFeel.page_sound(minimap.big)
		return
	if player.is_dead and ev.is_action_pressed("quick_equip"):
		get_viewport().set_input_as_handled()
		spectate_next()


# --- repères (molette / L3) --------------------------------------------------------------------------------------------

func _unhandled_input(ev: InputEvent) -> void:
	if get_tree().paused or not ev.is_action("ping") or dd() == null:
		return
	if ev.is_pressed() and not ev.is_echo():
		_ping_down = Moba.t
		_ping_screen = ev.position if ev is InputEventMouseButton else _area() * 0.5
		wheel.center = _ping_screen
		get_viewport().set_input_as_handled()
	elif not ev.is_pressed() and _ping_down >= 0.0:
		get_viewport().set_input_as_handled()
		var held := wheel.visible
		_ping_down = -1.0
		wheel.visible = false
		if held:
			var kind := wheel.choice()
			if kind != "":
				place_ping(kind, _ping_world(_ping_screen))
		else:
			place_ping("", _ping_world(_ping_screen if ev is InputEventMouseButton else Vector2.INF))


func _ping_tick(_delta: float) -> void:
	if _ping_down >= 0.0 and not wheel.visible and Moba.t - _ping_down >= PING_HOLD:
		wheel.visible = true
		wheel.open_at = Time.get_ticks_msec()
		UiFeel.cue("ui_hover", -14.0)


func _ping_world(screen: Vector2) -> Vector3:
	var d := dd()
	if screen == Vector2.INF or d == null:
		return RoyalePing.ahead_of(player, d.map if d != null else null)
	var cam := get_viewport().get_camera_3d()
	var p := RoyalePing.under_cursor(cam, screen, d.map)
	return p if p != Vector3.INF else RoyalePing.ahead_of(player, d.map)


## Repère au sol en [param p] ; [param kind] "" : selon ce qui s'y trouve (héros ou structure adverse : « Attaquez ! » ;
## objectif : « Objectif » ; sinon « Ici »). Renvoie l'entrée de MobaPings.
func place_ping(kind: String, p: Vector3) -> Dictionary:
	var d := dd()
	if d == null or p == Vector3.INF:
		return {}
	var target: Node = null
	if kind == "" or kind == "attack":
		var foe := 1 - TeamMatch.player_team
		var best := 4.0
		for list in [d.heroes, d.structures]:
			for u in list:
				if u.is_dead or d.side_of(u) != foe or (u is Combatant and d.info.has(u) and not is_seen(u)):
					continue
				var dist: float = Vector2(u.global_position.x - p.x, u.global_position.z - p.z).length() - float(u.radius)
				if dist < best:
					best = dist
					target = u
		if target != null:
			kind = "attack"
	if kind == "" and d.jungle != null and is_instance_valid(d.jungle):
		var st: Dictionary = d.jungle.objectives_state()
		for key in ["guardian", "colossus"]:
			if st.has(key) and Vector2(st[key].pos.x - p.x, st[key].pos.z - p.z).length() < MobaMap.PIT_R + 4.0:
				kind = "objective"
	if kind == "":
		kind = "here"
	var e := MobaPings.add(kind, p, target)
	UiFeel.cue("ui_notify" if kind in ["attack", "retreat", "help"] else "ui_click", -10.0)
	add_feed({"text": "Repère · " + String(e.text), "tone": MobaPings.tone(kind)})
	return e


# --- outils ----------------------------------------------------------------------------------------------------------

func class_icon(cid: String) -> Texture2D:
	if not _icons.has(cid):
		_icons[cid] = UiTheme.texture(String(GameData.class_data(cid).get("icon", ""))) if cid != "" else null
	return _icons[cid]


## Nom affiché d'un héros d'après sa classe (« Toi » pour le joueur).
func name_of(cid: String) -> String:
	if cid == "":
		return ""
	var hs := me()
	if hs != null and hs.cid == cid:
		return "Toi"
	return String(GameData.class_data(cid).get("name_fr", cid))


func hero_of(d: MobaDirector, cid: String) -> MobaHero:
	for h in d.heroes:
		var hs: MobaHero = d.info[h]
		if hs.cid == cid:
			return hs
	return null


## Héros de l'équipe [param side], le joueur d'abord.
func team_heroes(d: MobaDirector, side: int) -> Array:
	var out: Array = []
	for h in d.heroes:
		if int((d.info[h] as MobaHero).side) == side:
			if h == player:
				out.push_front(h)
			else:
				out.append(h)
	return out


## Tours (et Cœur) encore debout du camp [param side].
static func towers_up(d: MobaDirector, side: int) -> int:
	var n := 0
	for s in d.structures:
		if s.side == side and s.kind == "tower" and not s.is_dead:
			n += 1
	return n


## Le sort ultime du héros [param h] est-il prêt (débloqué et rechargé) ?
func ult_ready(d: MobaDirector, h: Combatant) -> bool:
	var hs: MobaHero = d.info.get(h)
	if hs == null or not hs.ult or h.is_dead:
		return false
	if h == player:
		return player.cooldown_left(3) <= 0.0 and not player.skill_in_slot(3).is_empty()
	var ready = h.get("_skill_ready")
	var now = h.get("_time")
	if ready is Dictionary and now != null:
		return float(now) >= float((ready as Dictionary).get(int(h.get("ult_id")), 0.0))
	return true


## Ce que fait un allié, en quelques mots (l'intention du coach d'équipe si elle existe, lot MB-G ; sinon où il est).
func intent_of(d: MobaDirector, h: Combatant) -> String:
	var hs: MobaHero = d.info[h]
	if h.is_dead:
		return "tombé · revient dans %d s" % ceili(maxf(0.0, hs.respawn_at - Moba.t))
	if hs.recalling():
		return "rentre à la base"
	if hs.ai != null:
		var it = hs.ai.get("intent")
		if it is String and String(it) != "":
			return String(it)
	var p := h.global_position
	if p.distance_to(d.map.moba.fountains[hs.side]) <= MobaHero.SHOP_RADIUS + 4.0:
		return "à la base"
	if player != null and not player.is_dead and p.distance_to(player.global_position) <= 14.0:
		return "avec toi"
	if d.jungle != null and is_instance_valid(d.jungle):
		for key in MobaMap.OBJECTIVES:
			var at := d.map.world(MobaMap.OBJECTIVES[key])
			if p.distance_to(at) <= MobaMap.PIT_R + 8.0:
				return "au Gardien" if key == "guardian" else "au Colosse"
	var l := d.map.local(p)
	for li in 2:
		if d.map.lane_dist(l, li) <= MobaMap.LANE_W + 2.0:
			return "Voie " + ("du Soleil" if li == 0 else "des Brumes")
	return "dans la jungle"


## Texte « m:ss ».
static func clock(secs: float) -> String:
	var s := maxi(0, ceili(secs))
	return "%d:%02d" % [s / 60, s % 60]


static func num(v: float) -> String:
	return RoyaleStyle.number(v)


## Blason d'équipe dessiné (pastille de la couleur et son motif blanc, comme TeamSigil) en [param c], rayon [param r].
static func draw_sigil(ci: CanvasItem, c: Vector2, r: float, t: int) -> void:
	var ink := RoyaleHudStyle.INK
	ci.draw_circle(c + Vector2(0, 2), r, ink)
	ci.draw_circle(c, r, ink)
	ci.draw_circle(c, r - 2.5, TeamMatch.color(t, "base"))
	var m := TeamMatch.motif(t)
	if m == "rond":
		ci.draw_circle(c, (r - 2.5) * 0.46, ink)
		ci.draw_circle(c, (r - 2.5) * 0.46 - 1.5, Color.WHITE)
	elif m == "anneau":
		ci.draw_arc(c, (r - 2.5) * 0.42, 0.0, TAU, 24, Color.WHITE, (r - 2.5) * 0.2, true)
	else:
		var pts := TeamSigil.shape(m, c, (r - 2.5) * 0.55)
		if pts.size() >= 3:
			RoyaleHudStyle.draw_inked_polygon(ci, pts, Color.WHITE, 1.0)


## Clic tenu sur la mini-carte : la caméra regarde [param p] sans bouger le héros ; [method look_end] la rend.
func look_at_point(p: Vector3) -> void:
	var d := dd()
	if d == null or d.d.world.rig == null:
		return
	if _look == null or not is_instance_valid(_look):
		_look = Node3D.new()
		_look.name = "MobaLook"
		d.add_child(_look)
	_look.global_position = p
	var rig = d.d.world.rig
	if rig.target != _look:
		_look_prev = rig.target
		rig.target = _look


func look_end() -> void:
	var d := dd()
	if d == null or d.d.world.rig == null:
		return
	var rig = d.d.world.rig
	if rig.target == _look:
		rig.target = _look_prev if _look_prev != null and is_instance_valid(_look_prev) else player
	_look_prev = null


# =====================================================================================================================
# Pièces dessinées
# =====================================================================================================================

## Tableau de la partie (haut centre) : 4 + 4 portraits, éliminations et blasons, temps, tours debout, Sceaux, Bannière.
class ScoreBand extends Control:
	var h: MobaHud
	var text := ""  # (tests) « 3 - 1 · 4:12 · tours 5 - 5 »

	func _init() -> void:
		name = "MobaScore"
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var d := h.dd()
		if d == null:
			return
		var W := MobaHud.BAND_W
		RoyaleHudStyle.draw_sticker(self, Rect2(0, 6, W, 62), RoyaleHudStyle.PAPER, 18.0, 4.0)
		var me := TeamMatch.player_team
		for side in 2:
			var t := me if side == 0 else 1 - me
			var list := h.team_heroes(d, t)
			for i in mini(list.size(), 4):
				var x := 10.0 + i * (MobaHud.PORT + MobaHud.PORT_GAP) if side == 0 else W - 10.0 - MobaHud.PORT - (3 - i) * (MobaHud.PORT + MobaHud.PORT_GAP)
				_portrait(d, Rect2(x, 15, MobaHud.PORT, MobaHud.PORT), list[i], t == me)
		# puits central : éliminations, temps, tours
		var cr := Rect2(W * 0.5 - 104.0, 10, 208, 54)
		RoyaleHudStyle.draw_sticker(self, cr, RoyaleHudStyle.WELL, 14.0, 0.0)
		var kills: Array = [int(Moba.hero_kills[me]), int(Moba.hero_kills[1 - me])]
		var f := RoyaleHudStyle.num_font()
		RoyaleHudStyle.draw_text(self, Vector2(cr.position.x + 8.0, 50.0), str(kills[0]), 30, TeamMatch.color(me, "clair"), f, HORIZONTAL_ALIGNMENT_CENTER, 52.0)
		RoyaleHudStyle.draw_text(self, Vector2(cr.end.x - 60.0, 50.0), str(kills[1]), 30, TeamMatch.color(1 - me, "clair"), f, HORIZONTAL_ALIGNMENT_CENTER, 52.0)
		var clock := MobaHud.clock(Moba.t)
		draw_string(f, Vector2(cr.position.x, 35.0), clock, HORIZONTAL_ALIGNMENT_CENTER, cr.size.x, 21, RoyaleHudStyle.PAPER)
		var tw := "tours %d – %d" % [MobaHud.towers_up(d, me), MobaHud.towers_up(d, 1 - me)]
		draw_string(RoyaleHudStyle.text_font(), Vector2(cr.position.x, 57.0), tw, HORIZONTAL_ALIGNMENT_CENTER, cr.size.x, 14, RoyaleHudStyle.INK_100)
		text = "%d - %d · %s · %s" % [kills[0], kills[1], clock, tw]
		# Sceaux (Gardien : 3 au plus) sous chaque blason ; Bannière du Colosse : drapeau améthyste
		var j: MobaJungle = d.jungle if d.jungle != null and is_instance_valid(d.jungle) else null
		for side in 2:
			var t := me if side == 0 else 1 - me
			var sx := W * 0.5 - 88.0 if side == 0 else W * 0.5 + 88.0
			var n := int(j.seals[t]) if j != null else 0
			for i in int(MobaData.SEAL.max):
				var c := Vector2(sx + (i - 1) * 9.0, 72.0)
				draw_circle(c, 4.5, RoyaleHudStyle.INK)
				draw_circle(c, 3.0, RoyaleHudStyle.MANDARIN[1] if i < n else RoyaleHudStyle.INK_300)
			if j != null and float(j.banner_until[t]) > Moba.t:
				var fp := Vector2(sx + (18.0 if side == 0 else -18.0), 58.0)
				draw_line(fp, fp + Vector2(0, 18), RoyaleHudStyle.INK, 3.0)
				RoyaleHudStyle.draw_inked_polygon(self, PackedVector2Array([fp, fp + Vector2(12, 4), fp + Vector2(0, 9)]), RoyaleHudStyle.AMETHYST[1], 1.5)

	func _portrait(d: MobaDirector, r: Rect2, node: Combatant, ally: bool) -> void:
		var hs: MobaHero = d.info[node]
		var tones := RoyaleHudStyle.family_tones(hs.cid)
		if node == h.player:
			RoyaleHudStyle.draw_sticker(self, r.grow(3.0), RoyaleHudStyle.LAGOON[0], 12.0, 0.0, 2.0)
		# allié : coins ronds ; adversaire : coins coupés (lisible sans la couleur, MOBA.md § 7.9)
		if ally:
			RoyaleHudStyle.draw_sticker(self, r, tones[1], 10.0, 2.0, 2.5)
		else:
			var c := 9.0
			var pts := PackedVector2Array([r.position + Vector2(c, 0), Vector2(r.end.x - c, r.position.y), Vector2(r.end.x, r.position.y + c),
				r.end - Vector2(0, c), Vector2(r.end.x - c, r.end.y), Vector2(r.position.x + c, r.end.y), Vector2(r.position.x, r.end.y - c),
				r.position + Vector2(0, c)])
			RoyaleHudStyle.draw_inked_polygon(self, pts, tones[1], 2.5)
		var tex := h.class_icon(hs.cid)
		if tex != null:
			draw_texture_rect(tex, r.grow(-4.0), false, Color(1, 1, 1, 0.45) if node.is_dead else Color.WHITE)
		if node.is_dead:
			draw_rect(r.grow(-2.5), Color(RoyaleHudStyle.WELL, 0.62))
			RoyaleHudStyle.draw_halftone(self, r.grow(-3.0), Color(1, 1, 1, 0.12), 6.0, 1.1)
			RoyaleHudStyle.draw_text(self, Vector2(r.position.x, r.position.y + 30.0), str(ceili(maxf(0.0, hs.respawn_at - Moba.t))), 19,
				RoyaleHudStyle.WHITE, RoyaleHudStyle.num_font(), HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
		# niveau de partie : pastille d'encre en bas à droite
		var bc := r.end - Vector2(3, 3)
		draw_circle(bc, 9.5, RoyaleHudStyle.INK)
		draw_string(RoyaleHudStyle.num_font(), Vector2(bc.x - 10.0, bc.y + 5.0), str(hs.level), HORIZONTAL_ALIGNMENT_CENTER, 20.0, 14, RoyaleHudStyle.PAPER)
		# ultime prêt (alliés seulement) : point soleil en haut à gauche
		if ally and h.ult_ready(d, node):
			var uc := r.position + Vector2(3, 3)
			draw_circle(uc, 6.0, RoyaleHudStyle.INK)
			draw_circle(uc, 4.0, RoyaleHudStyle.SUN[1])


## Minuteurs d'objectifs sous le tableau : Gardien, Colosse, puis la Marée finale (ou la fin au temps), et la Bannière.
class ObjRow extends Control:
	var h: MobaHud
	var pills: Array = []  # (tests) [texte]

	func _init() -> void:
		name = "MobaObjectives"
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	## Pastilles à dessiner : [[texte, tons, avancée (-1 : aucune)]].
	static func entries(hh: MobaHud, d: MobaDirector) -> Array:
		var out: Array = []
		var t := Moba.t
		var j: MobaJungle = d.jungle if d.jungle != null and is_instance_valid(d.jungle) else null
		if j != null:
			var st: Dictionary = j.objectives_state()
			for key in ["guardian", "colossus"]:
				if not st.has(key):
					continue
				var o: Dictionary = st[key]
				var nm := "Gardien" if key == "guardian" else "Colosse"
				var tones: Array = RoyaleHudStyle.MANDARIN if key == "guardian" else RoyaleHudStyle.AMETHYST
				if String(o.state) == "alive":
					out.append(["%s · %s" % [nm, "au combat" if bool(o.engaged) else "en jeu"], tones, float(o.hp) if bool(o.engaged) else -1.0])
				else:
					out.append(["%s · %s" % [nm, MobaHud.clock(float(o.spawn_in))], tones, -1.0])
			var me := TeamMatch.player_team
			for side in 2:
				var tt := me if side == 0 else 1 - me
				if float(j.banner_until[tt]) > t:
					out.append(["Bannière %s · %s" % ["" if tt == me else "adverse", MobaHud.clock(float(j.banner_until[tt]) - t)], RoyaleHudStyle.AMETHYST if tt == me else RoyaleHudStyle.danger(), -1.0])
		if t < MobaData.TIDE_AT:
			out.append(["Marée · %s" % MobaHud.clock(MobaData.TIDE_AT - t), RoyaleHudStyle.LAGOON, -1.0])
		else:
			out.append(["Fin · %s" % MobaHud.clock(MobaData.END_AT - t), RoyaleHudStyle.danger() if MobaData.END_AT - t <= MobaData.END_WARN else RoyaleHudStyle.SUN, -1.0])
		return out

	func _draw() -> void:
		var d := h.dd()
		pills = []
		if d == null:
			return
		var es := entries(h, d)
		var f := RoyaleHudStyle.text_font()
		var fs := 15
		var widths: Array = []
		var total := 0.0
		for e in es:
			var w := f.get_string_size(String(e[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 30.0
			widths.append(w)
			total += w + 10.0
		var x := (size.x - total + 10.0) * 0.5
		for i in es.size():
			var e: Array = es[i]
			var r := Rect2(x, 0, float(widths[i]), MobaHud.OBJ_H)
			var tones: Array = e[1]
			RoyaleHudStyle.draw_sticker(self, r, tones[1], 12.0, 3.0)
			RoyaleHudStyle.draw_text(self, Vector2(r.position.x, r.position.y + 23.0), String(e[0]), fs, RoyaleHudStyle.WHITE, f, HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
			if float(e[2]) >= 0.0:
				var g := Rect2(r.position.x + 10.0, r.end.y - 2.0, r.size.x - 20.0, 7.0)
				RoyaleHudStyle.draw_gauge(self, g, float(e[2]), RoyaleHudStyle.STRAWBERRY)
			pills.append(String(e[0]))
			x += float(widths[i]) + 10.0


## Les 3 alliés (gauche) : portrait, nom et niveau, PV, ultime prêt, ce qu'ils font.
class AllyColumn extends Control:
	var h: MobaHud
	var lines: Array = []  # (tests) [« Clerc · 6 · avec toi »]

	func _init() -> void:
		name = "MobaAllies"
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var d := h.dd()
		lines = []
		if d == null:
			return
		var list: Array = h.team_heroes(d, TeamMatch.player_team).filter(func(x): return x != h.player)
		for i in mini(list.size(), 3):
			var node: Combatant = list[i]
			var hs: MobaHero = d.info[node]
			var r := Rect2(0, i * (MobaHud.ALLY_H + 8.0), MobaHud.ALLY_W, MobaHud.ALLY_H)
			var dead := node.is_dead
			RoyaleHudStyle.draw_sticker(self, r, RoyaleHudStyle.PAPER_300 if dead else RoyaleHudStyle.PAPER, 14.0, 3.0)
			if dead:
				RoyaleHudStyle.draw_halftone(self, r.grow(-4.0), Color(RoyaleHudStyle.INK, 0.14), 7.0, 1.2)
			var tones := RoyaleHudStyle.family_tones(hs.cid)
			var c := r.position + Vector2(32, 32)
			draw_circle(c + Vector2(0, 2), 21.0, RoyaleHudStyle.INK)
			draw_circle(c, 21.0, RoyaleHudStyle.INK)
			draw_circle(c, 18.5, RoyaleHudStyle.COMMON[2] if dead else tones[1])
			var tex := h.class_icon(hs.cid)
			if tex != null:
				draw_texture_rect(tex, Rect2(c - Vector2(15, 15), Vector2(30, 30)), false, Color(1, 1, 1, 0.4) if dead else Color.WHITE)
			if dead:
				RoyaleHudStyle.draw_text(self, Vector2(c.x - 20.0, c.y + 7.0), str(ceili(maxf(0.0, hs.respawn_at - Moba.t))), 18, RoyaleHudStyle.WHITE,
					RoyaleHudStyle.num_font(), HORIZONTAL_ALIGNMENT_CENTER, 40.0)
			elif h.ult_ready(d, node):
				var uc := c + Vector2(15, -15)
				draw_circle(uc, 7.0, RoyaleHudStyle.INK)
				draw_circle(uc, 5.0, RoyaleHudStyle.SUN[1])
			var f := RoyaleHudStyle.text_font()
			var nm := "%s · %d" % [h.name_of(hs.cid), hs.level]
			draw_string(f, Vector2(r.position.x + 62.0, r.position.y + 21.0), nm, HORIZONTAL_ALIGNMENT_LEFT, MobaHud.ALLY_W - 70.0, 15, RoyaleHudStyle.INK)
			var intent := h.intent_of(d, node)
			if not dead:
				var g := Rect2(r.position.x + 62.0, r.position.y + 28.0, MobaHud.ALLY_W - 76.0, 11.0)
				RoyaleHudStyle.draw_gauge(self, g, node.hp / maxf(node.max_hp, 1.0), RoyaleHudStyle.safe())
				if h.ult_ready(d, node):
					intent += " · ultime prêt"
			draw_string(RoyaleHudStyle.text_font(), Vector2(r.position.x + 62.0, r.position.y + (56.0 if not dead else 46.0)), intent,
				HORIZONTAL_ALIGNMENT_LEFT, MobaHud.ALLY_W - 70.0, 14, RoyaleHudStyle.INK_300)
			lines.append(nm + " · " + intent)


## Colonne du fil sous la mini-carte : éliminations (« Toi ⚔ Mage »), tours, objectifs, repères, 8 s chacune.
class FeedColumn extends Control:
	var h: MobaHud
	var shown: Array = []  # (tests)

	func _init() -> void:
		name = "MobaFeed"
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		shown = []
		var now := Moba.t
		var f := RoyaleHudStyle.text_font()
		var y := 0.0
		var list: Array = h.feed.filter(func(e): return now - float(e.t) <= MobaHud.FEED_LIFE)
		for e in list.slice(maxi(0, list.size() - 5)):
			var a := clampf(MobaHud.FEED_LIFE - (now - float(e.t)), 0.0, 1.0)
			var r := Rect2(0, y, size.x, 26.0)
			if e.has("b"):
				var kn := h.name_of(String(e.a)) if String(e.a) != "" else "Le camp"
				var vn := h.name_of(String(e.b))
				var mid := "  ⚔  "
				var w := f.get_string_size(kn + mid + vn, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x + 52.0
				r = Rect2(size.x - w, y, w, 26.0)
				RoyaleHudStyle.draw_sticker(self, r, Color(RoyaleHudStyle.WELL, a), 12.0, 2.0, 2.0)
				var x := r.position.x + 10.0
				for part in [[kn, int(e.a_side), String(e.a)], [mid, -2, ""], [vn, int(e.b_side), String(e.b)]]:
					var s := String(part[0])
					if int(part[1]) == -2:
						draw_string(f, Vector2(x, r.position.y + 18.0), s, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(RoyaleHudStyle.INK_100, a))
						x += f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
						continue
					if int(part[1]) >= 0:
						var dc := Vector2(x + 5.0, r.position.y + 13.0)
						draw_circle(dc, 5.5, Color(RoyaleHudStyle.INK, a))
						draw_circle(dc, 4.0, Color(TeamMatch.color(int(part[1]), "base"), a))
						x += 14.0
					var col: Color = RoyaleHudStyle.SUN[0] if s == "Toi" else RoyaleHudStyle.PAPER
					RoyaleHudStyle.draw_text(self, Vector2(x, r.position.y + 18.0), s, 15, Color(col, a), f)
					x += f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
				shown.append(kn + " ⚔ " + vn)
			else:
				var txt := String(e.text)
				var w := f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x + 26.0
				r = Rect2(size.x - w, y, w, 26.0)
				var tones := UiTheme.tones(String(e.get("tone", "papier")))
				var paper := String(e.get("tone", "papier")) == "papier"
				RoyaleHudStyle.draw_sticker(self, r, Color(RoyaleHudStyle.PAPER if paper else tones[1], a), 12.0, 2.0, 2.0)
				if paper:
					draw_string(f, Vector2(r.position.x + 13.0, r.position.y + 18.0), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(RoyaleHudStyle.INK, a))
				else:
					RoyaleHudStyle.draw_text(self, Vector2(r.position.x + 13.0, r.position.y + 18.0), txt, 15, Color(1, 1, 1, a), f)
				shown.append(txt)
			y += 32.0


## Case de sort : plots d'enchaînements (pomme = débloqué), ultime cerclé de soleil et verrouillé « niv. 5 » ; pendant un
## choix de niveau, les cases possibles s'éclairent (clic = choisir, Ctrl + N).
class SlotMark extends Control:
	var h: MobaHud
	var slot := 0
	var state := ""  # (tests) « », « locked », « choice »
	var pips := Vector2i.ZERO  # (tests) (débloqués, total)

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _choosable() -> bool:
		var hs := h.me()
		return hs != null and not hs.pending.is_empty() and slot < 3 and slot in hs.choice_options()

	func _gui_input(ev: InputEvent) -> void:
		var mb := ev as InputEventMouseButton
		if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT and _choosable():
			accept_event()
			h.choose(slot)

	func _draw() -> void:
		var hs := h.me()
		state = ""
		if hs == null:
			return
		var v: Array = h.data.get("slots", [])
		if slot >= v.size():
			return
		var s: Dictionary = v[slot]
		var r := Rect2(Vector2.ZERO, size)
		var can := _choosable()
		mouse_filter = Control.MOUSE_FILTER_STOP if can else Control.MOUSE_FILTER_IGNORE
		tooltip_text = "Choisir son enchaînement (Ctrl + %d)" % (slot + 1) if can else ""
		if slot == 3:
			# ultime : anneau soleil ; verrouillé jusqu'au niveau 5
			HudV2.round_rect(self, r.grow(4.0), Color(0, 0, 0, 0), 16, 3, RoyaleHudStyle.SUN[1])
			if bool(s.locked):
				state = "locked"
				draw_rect(r.grow(-3.0), Color(RoyaleHudStyle.PAPER_300, 0.92))
				RoyaleHudStyle.draw_halftone(self, r.grow(-4.0), Color(RoyaleHudStyle.INK, 0.18), 6.0, 1.1)
				var lock := Ico.tex("lock", 32)
				if lock != null:
					draw_texture_rect(lock, Rect2(r.get_center() - Vector2(12, 18), Vector2(24, 24)), false, RoyaleHudStyle.INK_300)
				draw_string(RoyaleHudStyle.text_font(), Vector2(0, r.end.y - 9.0), "niv. %d" % int(s.unlock_level), HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 14, RoyaleHudStyle.INK)
				return
		var on := int(s.chains_on)
		var total := int(s.chains_total)
		pips = Vector2i(on, total)
		for i in total:
			# sous la case, de part et d'autre de sa touche dessinée (croquis v2_hud : plots sous les cases)
			var off := (24.0 if i == 1 or total == 1 else -24.0) + 12.0 * maxi(i - 1, 0)
			var c := Vector2(r.get_center().x + off, r.end.y + 9.0)
			draw_circle(c, 6.0, RoyaleHudStyle.INK)
			draw_circle(c, 4.2, RoyaleHudStyle.APPLE[1] if i < on else RoyaleHudStyle.PAPER_300)
		if can:
			state = "choice"
			var pulse := 0.55 + 0.45 * sin(Time.get_ticks_msec() * 0.008)
			HudV2.round_rect(self, r.grow(3.0), Color(0, 0, 0, 0), 15, 4, Color(RoyaleHudStyle.APPLE[0], pulse))
			var p := r.position + Vector2(r.size.x - 4.0, 4.0)
			draw_circle(p, 10.0, RoyaleHudStyle.INK)
			draw_circle(p, 8.0, RoyaleHudStyle.APPLE[1])
			draw_line(p + Vector2(-4, 0), p + Vector2(4, 0), RoyaleHudStyle.WHITE, 2.5)
			draw_line(p + Vector2(0, -4), p + Vector2(0, 4), RoyaleHudStyle.WHITE, 2.5)
			RoyaleHudStyle.draw_pill(self, Vector2(r.get_center().x, -12.0), "Ctrl+%d" % (slot + 1), RoyaleHudStyle.APPLE[0], 14)


## Choix de niveau, non bloquant, au-dessus des cases : « Niveau 4 ! Un enchaînement : [Ctrl+1] [Ctrl+2] · [G] conseillé ».
class ChoiceStrip extends Control:
	var h: MobaHud
	var text := ""  # (tests)
	var _pop := 0.0

	func _init() -> void:
		name = "MobaChoice"
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func pop() -> void:
		_pop = 1.0
		queue_redraw()

	func _draw() -> void:
		var hs := h.me()
		text = ""
		if hs == null or hs.pending.is_empty() or h.player.is_dead:
			return
		var opts: Array = hs.choice_options()
		var keys: Array = opts.map(func(s): return "[Ctrl+%d]" % (int(s) + 1))
		var adv := Settings.action_label("quick_equip", 1)
		var line := "Un enchaînement : %s · [%s] conseillé" % [" ".join(keys), adv]
		if int(hs.pending.size()) > 1:
			line += " · %d à choisir" % hs.pending.size()
		var title := "Niveau %d !" % hs.level
		text = title + " " + line
		var tf := RoyaleHudStyle.title_font()
		var tw := tf.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
		var lw := RoyaleHudStyle.key_line_width(line, 15)
		var w := minf(size.x, tw + lw + 50.0)
		var r := Rect2((size.x - w) * 0.5, 0, w, 42.0)
		RoyaleHudStyle.draw_sticker(self, r, RoyaleHudStyle.SUN[1], 14.0, 3.0)
		RoyaleHudStyle.draw_text(self, Vector2(r.position.x + 16.0, r.position.y + 28.0), title, 18, RoyaleHudStyle.WHITE, tf)
		RoyaleHudStyle.draw_key_line(self, Vector2(r.position.x + 30.0 + tw, r.position.y + 21.0), line, 15, RoyaleHudStyle.INK)


## Rappel ([X]) à gauche des potions : case ronde lagon, anneau soleil qui se remplit pendant les 6 s.
class RecallCell extends Control:
	var h: MobaHud

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_PASS
		tooltip_text = "Rappel : quelques secondes sans bouger ni être touché, puis la fontaine."

	func _draw() -> void:
		var hs := h.me()
		if hs == null:
			return
		var c := size * 0.5
		var rad := size.x * 0.5 - 2.0
		draw_circle(c + Vector2(2, 3), rad, RoyaleHudStyle.INK)
		draw_circle(c, rad, RoyaleHudStyle.INK)
		draw_circle(c, rad - 3.0, RoyaleHudStyle.LAGOON[0] if not hs.in_shop else RoyaleHudStyle.COMMON[1])
		var ico := MobaStore.icon("home")
		if ico != null:
			draw_texture_rect(ico, Rect2(c - Vector2(14, 14), Vector2(28, 28)), false, RoyaleHudStyle.INK)
		if hs.recalling():
			var j = h.dd().jungle
			var full := float(j.call("recall_time", h.player)) if j != null and is_instance_valid(j) else MobaData.RECALL_TIME
			var ratio := clampf(1.0 - hs.recall_left / maxf(full, 0.1), 0.0, 1.0)
			draw_arc(c, rad - 1.5, -PI * 0.5, -PI * 0.5 + TAU * ratio, 32, RoyaleHudStyle.SUN[1], 5.0, true)
		HudV2.key_pill(self, Vector2(c.x, size.y + 9.0), Settings.action_label("extract", 1))


## Or, boutique et objet conseillé (bas droite) ; les 6 places d'objets dessous. Un clic ouvre la boutique.
class GoldBox extends Control:
	var h: MobaHud
	var text := ""  # (tests)

	func _init() -> void:
		name = "MobaGold"
		mouse_filter = Control.MOUSE_FILTER_STOP

	func _gui_input(ev: InputEvent) -> void:
		var mb := ev as InputEventMouseButton
		if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			accept_event()
			h.toggle_store(false)

	func _draw() -> void:
		var hs := h.me()
		if hs == null:
			return
		var r := Rect2(Vector2.ZERO, size)
		RoyaleHudStyle.draw_sticker(self, r, RoyaleHudStyle.PAPER, 18.0, 4.0)
		# or
		var gr := Rect2(14, 12, 136, 38)
		RoyaleHudStyle.draw_sticker(self, gr, RoyaleHudStyle.SUN[1], 12.0, 3.0)
		var coin := Ico.tex("coin", 32)
		if coin != null:
			draw_texture_rect(coin, Rect2(gr.position + Vector2(8, 6), Vector2(26, 26)), false)
		RoyaleHudStyle.draw_text(self, Vector2(gr.position.x + 38.0, gr.position.y + 28.0), MobaHud.num(hs.gold), 24, RoyaleHudStyle.WHITE,
			RoyaleHudStyle.num_font(), HORIZONTAL_ALIGNMENT_CENTER, gr.size.x - 44.0)
		# boutique : lagon (pomme quand on est à la base et que l'étape suivante est payable)
		var open := MobaItems.shop_open(hs)
		var adv: Dictionary = h.data.get("advice", {})
		var ready := open and not adv.is_empty() and String(adv.get("step", "")) != ""
		var br := Rect2(162, 12, 124, 38)
		var tone: Array = RoyaleHudStyle.APPLE if ready else RoyaleHudStyle.LAGOON
		var pulse := 0.0 if not ready else (0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.006)) * 3.0
		RoyaleHudStyle.draw_sticker(self, br.grow(pulse), tone[1], 12.0, 3.0)
		RoyaleHudStyle.draw_key_line(self, Vector2(br.position.x + 12.0, br.get_center().y), "Boutique [P]", 15, RoyaleHudStyle.WHITE)
		# objet conseillé
		var cell := Rect2(14, 60, 46, 46)
		if adv.is_empty():
			RoyaleHudStyle.draw_sticker(self, cell, RoyaleHudStyle.APPLE[1], 12.0, 3.0)
			draw_string(RoyaleHudStyle.text_font(), Vector2(70, 82), "Tout est acheté !", HORIZONTAL_ALIGNMENT_LEFT, size.x - 80.0, 15, RoyaleHudStyle.INK)
			text = "%d or · tout acheté" % int(hs.gold)
		else:
			var it := MobaData.item(String(adv.id))
			MobaStore.draw_item_cell(self, cell, String(adv.id), true)
			var nm := "Prochain : " + String(it.get("name", ""))
			draw_string(RoyaleHudStyle.text_font(), Vector2(70, 76), nm, HORIZONTAL_ALIGNMENT_LEFT, size.x - 80.0, 15, RoyaleHudStyle.INK)
			var g := Rect2(70, 84, size.x - 86.0, 12.0)
			RoyaleHudStyle.draw_gauge(self, g, clampf(float(hs.gold) / maxf(float(adv.cost), 1.0), 0.0, 1.0), RoyaleHudStyle.SUN)
			var sub := "%s / %s" % [MobaHud.num(hs.gold), MobaHud.num(float(adv.cost))]
			sub += " · prêt !" if ready else (" · à la base" if not open else "")
			draw_string(RoyaleHudStyle.text_font(), Vector2(70, 112), sub, HORIZONTAL_ALIGNMENT_LEFT, size.x - 80.0, 14, RoyaleHudStyle.INK_300)
			text = "%d or · %s · %s" % [int(hs.gold), nm, sub]
			tooltip_text = "%s : %s\n%s" % [String(it.get("name", "")), String(it.get("text", "")), String(it.get("tip", ""))]
		# les 6 places
		for i in MobaData.SLOTS:
			var sr := Rect2(14 + i * 30.0, 118, 26, 26)
			if i < hs.items.size():
				MobaStore.draw_item_cell(self, sr, String(hs.items[i]), false)
			else:
				RoyaleHudStyle.draw_sticker(self, sr, RoyaleHudStyle.PAPER_300, 7.0, 0.0, 2.0)
				RoyaleHudStyle.draw_halftone(self, sr.grow(-3.0), Color(RoyaleHudStyle.INK, 0.16), 5.0, 1.0)
		var pots := MobaItems.potion_count(hs, "heal")
		RoyaleHudStyle.draw_pill(self, Vector2(size.x - 52.0, 131.0), "soin ×%d" % pots, RoyaleHudStyle.STRAWBERRY[0], 14)


## Écran de mort : « Tombé ! », minuteur de réapparition, qui t'a battu (sort, PV qui lui restaient), d'où venaient les coups,
## et ce qu'on peut faire en attendant (boutique, regarder un allié, la carte). Le jeu continue.
class DeathCard extends Control:
	const SIZE := Vector2(560, 236)
	var h: MobaHud
	var text := ""  # (tests)

	func _init() -> void:
		name = "MobaDeath"
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		visible = false

	func _draw() -> void:
		var hs := h.me()
		if hs == null:
			return
		var r := Rect2(Vector2.ZERO, SIZE)
		RoyaleHudStyle.draw_sticker(self, r, RoyaleHudStyle.PAPER, 20.0, 6.0)
		RoyaleHudStyle.draw_halftone(self, Rect2(4, SIZE.y - 46, SIZE.x - 8, 42), Color(RoyaleHudStyle.INK, 0.1), 7.0, 1.2)
		# titre incliné, fraise
		var tr := Rect2(-10, -18, 190, 46)
		draw_set_transform(tr.get_center(), deg_to_rad(-3.0), Vector2.ONE)
		var lr := Rect2(-tr.size * 0.5, tr.size)
		RoyaleHudStyle.draw_sticker(self, lr, RoyaleHudStyle.danger()[1], 14.0, 4.0)
		RoyaleHudStyle.draw_text(self, Vector2(lr.position.x, 10.0), "Tombé !", 26, RoyaleHudStyle.WHITE, RoyaleHudStyle.title_font(), HORIZONTAL_ALIGNMENT_CENTER, lr.size.x)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		var left := maxf(0.0, hs.respawn_at - Moba.t)
		var nf := RoyaleHudStyle.num_font()
		draw_string(RoyaleHudStyle.text_font(), Vector2(SIZE.x - 210.0, 34.0), "Retour dans", HORIZONTAL_ALIGNMENT_RIGHT, 110.0, 15, RoyaleHudStyle.INK_300)
		RoyaleHudStyle.draw_text(self, Vector2(SIZE.x - 92.0, 46.0), "%d s" % ceili(left), 34, RoyaleHudStyle.SUN[1], nf, HORIZONTAL_ALIGNMENT_CENTER, 84.0)
		text = "Tombé ! Retour dans %d s" % ceili(left)
		var rc := h.recap
		var y := 66.0
		var f := RoyaleHudStyle.text_font()
		if not rc.is_empty() and String(rc.get("killer", "")) != "":
			var cid := String(rc.get("cid", ""))
			var c := Vector2(36, y + 22)
			draw_circle(c, 21.0, RoyaleHudStyle.INK)
			draw_circle(c, 18.5, RoyaleHudStyle.family_tones(cid)[1] if cid != "" else RoyaleHudStyle.COMMON[1])
			var tex := h.class_icon(cid) if cid != "" else null
			if tex != null:
				draw_texture_rect(tex, Rect2(c - Vector2(15, 15), Vector2(30, 30)), false)
			var who := "%s t'a battu" % String(rc.killer)
			if String(rc.get("move", "")) != "":
				who += " · " + String(rc.move)
			draw_string(f, Vector2(66, y + 16), who, HORIZONTAL_ALIGNMENT_LEFT, SIZE.x - 80.0, 17, RoyaleHudStyle.INK)
			text += " · " + who
			if float(rc.get("hp", -1.0)) >= 0.0:
				draw_string(f, Vector2(66, y + 38), "il lui reste", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, RoyaleHudStyle.INK_300)
				RoyaleHudStyle.draw_gauge(self, Rect2(160, y + 27, 180, 12), float(rc.hp), RoyaleHudStyle.danger())
			y += 54.0
			for row in rc.get("rows", []):
				draw_string(f, Vector2(24, y + 13), String(row[0]), HORIZONTAL_ALIGNMENT_LEFT, 150.0, 15, RoyaleHudStyle.INK)
				RoyaleHudStyle.draw_gauge(self, Rect2(170, y + 2, 240, 12), float(row[1]), RoyaleHudStyle.MANDARIN)
				y += 20.0
		else:
			draw_string(f, Vector2(24, y + 20), "Reviens vite : ton équipe t'attend.", HORIZONTAL_ALIGNMENT_LEFT, -1, 17, RoyaleHudStyle.INK)
		var keys := "[P] Boutique   [%s] Regarder un allié   [%s] Carte" % [Settings.action_label("quick_equip", 1), Settings.action_label("map", 1)]
		RoyaleHudStyle.draw_key_line(self, Vector2(22, SIZE.y - 24.0), keys, 15, RoyaleHudStyle.INK)


## Tableau des scores (tant que [Tab] / ← croix est tenu) : les 8 héros, niveau, éliminations / morts / aides, sbires, objets.
class ScoreBoard extends Control:
	const SIZE := Vector2(820, 516)
	const ROW := 44.0
	var h: MobaHud
	var rows: Array = []  # (tests) [texte]

	func _init() -> void:
		name = "MobaBoard"
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var d := h.dd()
		rows = []
		if d == null:
			return
		var r := Rect2(Vector2.ZERO, SIZE)
		RoyaleHudStyle.draw_sticker(self, r, RoyaleHudStyle.PAPER, 20.0, 7.0)
		var tf := RoyaleHudStyle.title_font()
		RoyaleHudStyle.draw_text(self, Vector2(22, 38), "Tableau des scores", 24, RoyaleHudStyle.WHITE, tf)
		var f := RoyaleHudStyle.text_font()
		draw_string(f, Vector2(SIZE.x - 300.0, 34.0), "%s · tours %d – %d" % [MobaHud.clock(Moba.t), MobaHud.towers_up(d, TeamMatch.player_team),
			MobaHud.towers_up(d, 1 - TeamMatch.player_team)], HORIZONTAL_ALIGNMENT_RIGHT, 280.0, 16, RoyaleHudStyle.INK_300)
		var cols := [["Niv.", 300.0], ["É / M / A", 360.0], ["Sbires", 460.0], ["Objets", 540.0]]
		for c in cols:
			draw_string(f, Vector2(float(c[1]), 62.0), String(c[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, RoyaleHudStyle.INK_300)
		var y := 70.0
		var me := TeamMatch.player_team
		for side in 2:
			var t := me if side == 0 else 1 - me
			var hr := Rect2(14, y, SIZE.x - 28, 30)
			RoyaleHudStyle.draw_sticker(self, hr, TeamMatch.color(t, "base"), 10.0, 2.0, 2.5)
			MobaHud.draw_sigil(self, hr.position + Vector2(20, 15), 11.0, t)
			var g := Moba.score(t)
			RoyaleHudStyle.draw_text(self, Vector2(hr.position.x + 40.0, hr.position.y + 21.0), "%s · %d éliminations · %d structures · %d objectifs" % [
				TeamMatch.team_name(t), int(Moba.hero_kills[t]), int(g.structures), int(g.objectives)], 15, RoyaleHudStyle.WHITE, f)
			y += 36.0
			for node in h.team_heroes(d, t):
				var hs: MobaHero = d.info[node]
				var rr := Rect2(14, y, SIZE.x - 28, ROW - 4.0)
				RoyaleHudStyle.draw_sticker(self, rr, RoyaleHudStyle.PAPER_200 if node == h.player else Color(RoyaleHudStyle.PAPER_300, 0.6), 10.0, 0.0, 2.0)
				var c := rr.position + Vector2(22, rr.size.y * 0.5)
				draw_circle(c, 16.0, RoyaleHudStyle.INK)
				draw_circle(c, 14.0, RoyaleHudStyle.family_tones(hs.cid)[1])
				var tex := h.class_icon(hs.cid)
				if tex != null:
					draw_texture_rect(tex, Rect2(c - Vector2(12, 12), Vector2(24, 24)), false, Color(1, 1, 1, 0.45) if node.is_dead else Color.WHITE)
				var nm := h.name_of(hs.cid)
				var role := String(MobaData.ROLES[clampi(hs.role, 0, MobaData.ROLES.size() - 1)].short)
				draw_string(f, Vector2(rr.position.x + 46.0, rr.position.y + 18.0), nm, HORIZONTAL_ALIGNMENT_LEFT, 230.0, 16, RoyaleHudStyle.INK)
				var sub := role + (" · revient dans %d s" % ceili(maxf(0.0, hs.respawn_at - Moba.t)) if node.is_dead else "")
				draw_string(f, Vector2(rr.position.x + 46.0, rr.position.y + 35.0), sub, HORIZONTAL_ALIGNMENT_LEFT, 230.0, 14, RoyaleHudStyle.INK_300)
				var nf := RoyaleHudStyle.num_font()
				draw_string(nf, Vector2(300, rr.position.y + 27.0), str(hs.level), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, RoyaleHudStyle.INK)
				var kda := "%d / %d / %d" % [hs.kills, hs.deaths, hs.assists]
				draw_string(nf, Vector2(360, rr.position.y + 27.0), kda, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, RoyaleHudStyle.INK)
				draw_string(nf, Vector2(460, rr.position.y + 27.0), str(hs.cs), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, RoyaleHudStyle.INK)
				for i in MobaData.SLOTS:
					var ir := Rect2(540 + i * 40.0, rr.position.y + 5.0, 30, 30)
					if i < hs.items.size():
						MobaStore.draw_item_cell(self, ir, String(hs.items[i]), false)
					else:
						RoyaleHudStyle.draw_sticker(self, ir, Color(RoyaleHudStyle.PAPER_300, 0.7), 8.0, 0.0, 2.0)
				rows.append("%s %s niv %d %s" % [nm, role, hs.level, kda])
				y += ROW
			y += 6.0


## Roue des repères (maintien de la molette / L3) : quatre choix autour du point visé ; le relâcher pose le repère choisi.
class PingWheel extends Control:
	const R := 96.0
	var h: MobaHud
	var center := Vector2.ZERO
	var open_at := 0

	func _init() -> void:
		name = "MobaPingWheel"
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	## Sorte visée par la souris (ou le stick droit) ; "" au centre.
	func choice() -> String:
		var v := get_viewport().get_mouse_position() - center
		var pad := Gamepad.stick(JOY_AXIS_RIGHT_X, JOY_AXIS_RIGHT_Y)
		if pad.length() > 0.4:
			v = pad * 100.0
		if v.length() < 26.0:
			return ""
		var a := fposmod(v.angle() + PI * 0.5 + PI * 0.25, TAU)  # 0 = haut, sens horaire
		return String(MobaPings.WHEEL[int(a / (PI * 0.5)) % 4])

	func _draw() -> void:
		var c := center
		draw_circle(c, R + 18.0, Color(RoyaleHudStyle.WELL, 0.86))
		draw_arc(c, R + 18.0, 0.0, TAU, 48, RoyaleHudStyle.INK, 4.0, true)
		var pick := choice()
		var dirs := [Vector2(0, -1), Vector2(1, 0), Vector2(0, 1), Vector2(-1, 0)]
		for i in 4:
			var kind := String(MobaPings.WHEEL[i])
			var p: Vector2 = c + dirs[i] * (R * 0.72)
			var tones := UiTheme.tones(MobaPings.tone(kind))
			var rr := 30.0 if kind == pick else 26.0
			draw_circle(p + Vector2(2, 3), rr, RoyaleHudStyle.INK)
			draw_circle(p, rr, RoyaleHudStyle.INK)
			draw_circle(p, rr - 3.0, tones[1])
			RoyaleHudStyle.draw_text(self, Vector2(p.x - 50.0, p.y + 5.0), String(MobaPings.KINDS[kind].text), 14, RoyaleHudStyle.WHITE, null, HORIZONTAL_ALIGNMENT_CENTER, 100.0)
		draw_circle(c, 16.0, RoyaleHudStyle.INK)
		draw_circle(c, 13.0, RoyaleHudStyle.SUN[1])
		RoyaleHudStyle.draw_pill(self, c + Vector2(0, -R - 34.0), "Les alliés le voient", RoyaleHudStyle.PAPER, 14)


## Repères au sol (écran) : épingle de la couleur de la sorte, son nom et la distance.
class PingPins extends Control:
	var h: MobaHud
	var _shown := 0

	func _init() -> void:
		name = "MobaPings"
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		_shown = 0
		var cam := get_viewport().get_camera_3d()
		if cam == null or h.player == null:
			return
		var inv := get_global_transform_with_canvas().affine_inverse()
		for e in MobaPings.recent():
			var p: Vector3 = e.pos
			var tgt = e.get("target")
			if tgt != null and is_instance_valid(tgt) and not (tgt as Node3D).is_queued_for_deletion():
				p = (tgt as Node3D).global_position
			if cam.is_position_behind(p):
				continue
			var sp: Vector2 = inv * cam.unproject_position(p + Vector3.UP * 0.2)
			var age := Moba.t - float(e.t)
			var a := clampf((MobaPings.LIFE - age) / 1.0, 0.0, 1.0)
			var bounce := maxf(0.0, 1.0 - age / 0.3) * 10.0
			var tip := sp - Vector2(0, bounce)
			var tones := UiTheme.tones(MobaPings.tone(String(e.kind)))
			var pts := PackedVector2Array([tip, tip + Vector2(-10, -18), tip + Vector2(10, -18)])
			RoyaleHudStyle.draw_inked_polygon(self, pts, Color(tones[1], a), 3.0)
			draw_circle(tip + Vector2(0, -22), 12.0, Color(RoyaleHudStyle.INK, a))
			draw_circle(tip + Vector2(0, -22), 9.0, Color(tones[0], a))
			var dist := Vector2(p.x - h.player.global_position.x, p.z - h.player.global_position.z).length()
			RoyaleHudStyle.draw_pill(self, tip + Vector2(0, -46), "%s · %d m" % [String(e.text), roundi(dist)], Color(RoyaleHudStyle.PAPER, a), 14)
			_shown += 1


## Annonces du mode, une à la fois (MOBA.md § 7.9) : la bulle de HudAlert (3 niveaux, sous les minuteurs d'objectifs) et une
## ligne de détail dessous ; file à priorités (une plus importante passe tout de suite, une moins importante attend au plus
## MAX_WAIT s) ; le même titre ravive la bulle au lieu de la rejouer.
class Announcer extends Control:
	const MIN_SHOW := 0.8
	const MAX_WAIT := 4.0
	var h: MobaHud
	var alert: HudAlert
	var top_px := 140.0
	var current: Dictionary = {}  # {title, sub, prio, tone, left, shown}
	var queue: Array = []
	var log: Array = []  # (tests) titres montrés
	var _sub: PanelContainer
	var _sub_label: Label
	var _clock := 0.0

	func _init() -> void:
		name = "MobaAnnounce"
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		process_mode = Node.PROCESS_MODE_ALWAYS

	func _ready() -> void:
		alert = HudAlert.new()
		add_child(alert)
		_sub = PanelContainer.new()
		_sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_sub.add_theme_stylebox_override("panel", RoyaleHudStyle.box("papier", Vector2(14, 3), 3, 12))
		add_child(_sub)
		_sub_label = RoyaleHudStyle.label(_sub, "", 16, RoyaleHudStyle.INK, null, true)
		_sub.visible = false

	## Une annonce : [param prio] 0 discrète … 3 moment fort ; [param tone] : bonbon de la bulle (fraise = danger).
	func push(title: String, sub: String, prio: int, tone: String, duration: float) -> void:
		var a := {"title": title, "sub": sub, "prio": prio, "tone": tone, "duration": clampf(duration, 1.4, 3.6), "at": _clock}
		if not current.is_empty() and String(current.title) == title:
			current.left = maxf(float(current.left), float(a.duration))
			return
		if current.is_empty() or prio > int(current.prio) or (prio == int(current.prio) and float(current.shown) >= MIN_SHOW) 				or float(current.left) <= 0.0:
			_show(a)
		else:
			queue.append(a)
			queue.sort_custom(func(x, y): return int(x.prio) > int(y.prio) or (int(x.prio) == int(y.prio) and float(x.at) < float(y.at)))
			if queue.size() > 3:
				queue.pop_back()

	func _show(a: Dictionary) -> void:
		current = {"title": a.title, "sub": a.sub, "prio": a.prio, "tone": a.tone, "left": a.duration, "shown": 0.0}
		log.append(String(a.title))
		if log.size() > 30:
			log.pop_front()
		var level := 2 if int(a.prio) >= 3 and String(a.tone) == "fraise" else (0 if int(a.prio) == 0 else 1)
		alert.show_alert(String(a.title), level, float(a.duration))
		var tone := String(a.tone)
		if tone == "fraise" and RoyaleHudStyle.colorblind():
			tone = "mandarine"
		if level >= 1:
			alert.box.add_theme_stylebox_override("panel", UiTheme.sticker(tone, {"radius": 14, "shadow": 5, "pad": Vector2(22, 6), "gloss": true}))
		_sub_label.text = String(a.sub)
		_sub.visible = String(a.sub) != ""
		_sub.reset_size()
		_place()

	func _place() -> void:
		var vw := size.x if size.x > 1.0 else get_viewport_rect().size.x
		alert.box.reset_size()
		var bs := alert.box.get_combined_minimum_size()
		alert.box.size = bs
		alert.box.position = Vector2(roundf((vw - bs.x) * 0.5), top_px)
		alert.box.pivot_offset = bs * 0.5
		if _sub.visible:
			var ss := _sub.get_combined_minimum_size()
			_sub.size = ss
			_sub.position = Vector2(roundf((vw - ss.x) * 0.5), top_px + bs.y + 4.0)

	## Efface la file et la bulle (tests, fin de partie).
	func clear() -> void:
		queue.clear()
		current = {}

	## Titre affiché ("" : aucun).
	func shown_title() -> String:
		return String(current.get("title", "")) if not current.is_empty() and alert.shown() else ""

	func tick(delta: float) -> void:
		_clock += delta
		if not current.is_empty():
			current.shown = float(current.shown) + delta
			current.left = float(current.left) - delta
			if float(current.left) <= 0.0:
				current = {}
				_next()
		elif not queue.is_empty():
			_next()
		if alert != null and alert.box != null:
			if alert.box.position.y != top_px and not current.is_empty():
				_place()
			_sub.modulate.a = alert.box.modulate.a
			_sub.visible = _sub_label.text != "" and alert.box.modulate.a > 0.02

	func _next() -> void:
		while not queue.is_empty():
			var a: Dictionary = queue.pop_front()
			if _clock - float(a.at) <= MAX_WAIT:
				_show(a)
				return


## Mini-carte des Deux Voies (haut droite ; [M] / Vue : grande carte au centre) : toute l'aire de jeu (200 × 120 m), relief et
## voies (MobaMap.minimap_info), tours et Cœurs aux couleurs des équipes (une tour tombée : ✕), camps de la jungle (plein :
## en vie), fosses du Gardien et du Colosse, sbires et héros ; un adversaire n'est montré que vu par l'équipe (brouillard tramé
## ailleurs : 25 m autour des alliés et des structures alliées) ; alliés ronds, adversaires à coins coupés ; cadre blanc de la
## caméra ; repères. Clic tenu : la caméra regarde là sans bouger le héros ; clic droit : un repère.
class MobaMinimap extends Control:
	var h: MobaHud
	var big := false
	var fog_tex: ImageTexture
	var drawn := {}  # (tests) {towers, camps, minions, heroes, foes}
	var _fog: Image
	var _fog_base: Image
	var _looking := false

	func _init() -> void:
		name = "MobaMinimap"
		mouse_filter = Control.MOUSE_FILTER_STOP

	func inner() -> Rect2:
		return Rect2(Vector2(10, 10), size - Vector2(20, 20))

	## Rectangle de l'aire de jeu dans la mini-carte (proportions gardées, centré).
	func map_rect() -> Rect2:
		var ir := inner()
		var half := MobaMap.HALF
		var s := minf(ir.size.x / (half.x * 2.0), ir.size.y / (half.y * 2.0))
		var ms := half * 2.0 * s
		return Rect2(ir.position + (ir.size - ms) * 0.5, ms)

	## Monde -> mini-carte.
	func w2m(p: Vector3) -> Vector2:
		var d := h.dd()
		if d == null:
			return Vector2.ZERO
		var l := d.map.local(p)
		var mr := map_rect()
		return mr.position + (l + MobaMap.HALF) / (MobaMap.HALF * 2.0) * mr.size

	## Mini-carte -> monde (au sol).
	func m2w(sp: Vector2) -> Vector3:
		var d := h.dd()
		var mr := map_rect()
		var l := ((sp - mr.position) / mr.size) * MobaMap.HALF * 2.0 - MobaMap.HALF
		l = l.clamp(-MobaMap.HALF, MobaMap.HALF)
		return d.map.world(l) if d != null else Vector3.ZERO

	## Brouillard (3 fois par seconde) : une image de 100 × 60 (2 m le pixel), encre tramée, percée autour de ceux qui voient.
	func update_fog(viewers: Array) -> void:
		var d := h.dd()
		if d == null:
			return
		var W := MobaHud.FOG_RES.x
		var H := MobaHud.FOG_RES.y
		if _fog_base == null:
			_fog_base = Image.create(W, H, false, Image.FORMAT_RGBA8)
			_fog_base.fill(Color(RoyaleHudStyle.WELL, 0.46))
			for y in H:
				for x in W:
					if y % 3 == 0 and (x + (y / 3) % 2 * 2) % 4 == 0:
						_fog_base.set_pixel(x, y, Color(RoyaleHudStyle.PAPER, 0.4))
			_fog = Image.create(W, H, false, Image.FORMAT_RGBA8)
		_fog.copy_from(_fog_base)
		var r := MobaHud.VISION / 2.0
		var clear := Color(0, 0, 0, 0)
		for v in viewers:
			var l := d.map.local(v)
			var cx := (l.x + MobaMap.HALF.x) / 2.0
			var cy := (l.y + MobaMap.HALF.y) / 2.0
			for dy in range(-int(r), int(r) + 1):
				var yy := int(roundf(cy)) + dy
				if yy < 0 or yy >= H:
					continue
				var half := sqrt(maxf(r * r - dy * dy, 0.0))
				var x0 := clampi(int(floorf(cx - half)), 0, W)
				var x1 := clampi(int(ceilf(cx + half)), 0, W)
				if x1 > x0:
					_fog.fill_rect(Rect2i(x0, yy, x1 - x0, 1), clear)
		if fog_tex == null:
			fog_tex = ImageTexture.create_from_image(_fog)
		else:
			fog_tex.update(_fog)

	func _gui_input(ev: InputEvent) -> void:
		var mb := ev as InputEventMouseButton
		if mb != null and mb.button_index == MOUSE_BUTTON_LEFT:
			accept_event()
			if mb.pressed and map_rect().has_point(mb.position):
				_looking = true
				h.look_at_point(m2w(mb.position))
			elif not mb.pressed and _looking:
				_looking = false
				h.look_end()
		elif mb != null and mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed and map_rect().has_point(mb.position):
			accept_event()
			h.place_ping("", m2w(mb.position))
		elif ev is InputEventMouseMotion and _looking:
			accept_event()
			h.look_at_point(m2w((ev as InputEventMouseMotion).position))

	func _notification(what: int) -> void:
		if what == NOTIFICATION_MOUSE_EXIT and _looking:
			_looking = false
			h.look_end()

	func _draw() -> void:
		var d := h.dd()
		drawn = {"towers": 0, "camps": 0, "minions": 0, "heroes": 0, "foes": 0}
		if d == null or d.map == null:
			return
		var r := Rect2(Vector2.ZERO, size)
		RoyaleHudStyle.draw_sticker(self, r, RoyaleHudStyle.PAPER, 18.0, 4.0)
		var ir := inner()
		RoyaleHudStyle.draw_sticker(self, ir, RoyaleHudStyle.PAPER_300, 12.0, 0.0, 2.0)
		var mr := map_rect()
		var info: Dictionary = d.map.minimap_info()
		var tex: Texture2D = info.texture
		var ppm := float(info.ppm)
		var half := MobaMap.HALF
		var src := Rect2((d.map.size * 0.5 - half.x) * ppm, (d.map.size * 0.5 - half.y) * ppm, half.x * 2.0 * ppm, half.y * 2.0 * ppm)
		if tex != null:
			draw_texture_rect_region(tex, mr, src)
		if fog_tex != null:
			draw_texture_rect(fog_tex, mr, false)
		draw_rect(mr, RoyaleHudStyle.INK, false, 2.0)
		var me := TeamMatch.player_team
		var k := 1.6 if big else 1.0
		# structures
		for s in d.structures:
			var sp := w2m(s.global_position)
			var col := TeamMatch.color(int(s.side), "base")
			if s.is_dead:
				var q := 4.0 * k
				draw_line(sp + Vector2(-q, -q), sp + Vector2(q, q), RoyaleHudStyle.INK, 2.5)
				draw_line(sp + Vector2(-q, q), sp + Vector2(q, -q), RoyaleHudStyle.INK, 2.5)
				continue
			drawn.towers = int(drawn.towers) + 1
			if s.kind == "core":
				draw_circle(sp, 8.5 * k, RoyaleHudStyle.INK)
				draw_circle(sp, 6.5 * k, col)
				draw_circle(sp, 2.5 * k, RoyaleHudStyle.WHITE)
			else:
				var tr := Rect2(sp - Vector2(5, 6) * k, Vector2(10, 12) * k)
				draw_rect(tr.grow(2.0), RoyaleHudStyle.INK)
				draw_rect(tr, col)
				var hp: float = s.hp / maxf(s.max_hp, 1.0)
				if hp < 0.99:
					draw_rect(Rect2(tr.position + Vector2(0, tr.size.y * (1.0 - hp)), Vector2(tr.size.x, 2.0)), RoyaleHudStyle.WHITE)
		# jungle : camps et fosses
		var j: MobaJungle = d.jungle if d.jungle != null and is_instance_valid(d.jungle) else null
		if j != null:
			for e in j.camp_list():
				var sp := w2m(e.pos)
				var tones := UiTheme.tones(String(MobaData.CAMPS.get(String(e.get("camp", "")), {}).get("color", "pomme")))
				if String(e.state) == "alive":
					draw_circle(sp, 5.0 * k, RoyaleHudStyle.INK)
					draw_circle(sp, 3.5 * k, tones[1])
					drawn.camps = int(drawn.camps) + 1
				else:
					draw_arc(sp, 4.0 * k, 0.0, TAU, 14, Color(RoyaleHudStyle.INK_300, 0.9), 1.5, true)
			var st: Dictionary = j.objectives_state()
			for key in ["guardian", "colossus"]:
				if not st.has(key):
					continue
				var o: Dictionary = st[key]
				var sp := w2m(o.pos)
				var tones: Array = RoyaleHudStyle.MANDARIN if key == "guardian" else RoyaleHudStyle.AMETHYST
				var q := 7.5 * k
				var pts := PackedVector2Array([sp + Vector2(0, -q), sp + Vector2(q, 0), sp + Vector2(0, q), sp + Vector2(-q, 0)])
				if String(o.state) == "alive":
					RoyaleHudStyle.draw_inked_polygon(self, pts, tones[1], 2.0)
				else:
					var closed := pts.duplicate()
					closed.append(pts[0])
					draw_polyline(closed, tones[2], 2.0, true)
		# sbires (un adversaire seulement s'il est vu)
		for m in d.minions:
			if m.is_dead or not m.visible:
				continue
			if int(m.side) != me and not h.is_seen(m):
				continue
			var sp := w2m(m.global_position)
			draw_rect(Rect2(sp - Vector2(2, 2) * k, Vector2(4, 4) * k), TeamMatch.color(int(m.side), "base"))
			drawn.minions = int(drawn.minions) + 1
		# héros : alliés ronds, adversaires à coins coupés ; toi : flèche soleil
		for hh in d.heroes:
			if hh.is_dead:
				continue
			var hs: MobaHero = d.info[hh]
			if hs.side != me and not h.is_seen(hh):
				continue
			var sp := w2m(hh.global_position)
			var col := TeamMatch.color(hs.side, "base")
			drawn.heroes = int(drawn.heroes) + 1
			if hh == h.player:
				continue
			if hs.side == me:
				draw_circle(sp, 6.5 * k, RoyaleHudStyle.INK)
				draw_circle(sp, 5.0 * k, col)
			else:
				drawn.foes = int(drawn.foes) + 1
				var q := 6.5 * k
				var c := q * 0.4
				var pts := PackedVector2Array([sp + Vector2(-q + c, -q), sp + Vector2(q - c, -q), sp + Vector2(q, -q + c), sp + Vector2(q, q - c),
					sp + Vector2(q - c, q), sp + Vector2(-q + c, q), sp + Vector2(-q, q - c), sp + Vector2(-q, -q + c)])
				RoyaleHudStyle.draw_inked_polygon(self, pts, col, 2.0)
		# repères
		for e in MobaPings.recent():
			var sp := w2m(e.pos)
			var tones := UiTheme.tones(MobaPings.tone(String(e.kind)))
			var pts := PackedVector2Array([sp + Vector2(0, 2), sp + Vector2(-5, -8), sp + Vector2(5, -8)])
			RoyaleHudStyle.draw_inked_polygon(self, pts, tones[1], 1.5)
			draw_circle(sp + Vector2(0, -9), 4.5, RoyaleHudStyle.INK)
			draw_circle(sp + Vector2(0, -9), 3.2, tones[0])
		# cadre de la caméra
		var rig = d.d.world.rig if d.d != null and d.d.world != null else null
		if rig != null and rig.target != null and is_instance_valid(rig.target):
			var c3: Vector3 = (rig.target as Node3D).global_position
			var dist := float(rig.distance)
			var a := w2m(c3 + Vector3(-dist * 0.95, 0, -dist * 0.55))
			var b := w2m(c3 + Vector3(dist * 0.95, 0, dist * 0.55))
			var cr := Rect2(a, b - a).intersection(mr)
			if cr.size.x > 2.0:
				draw_rect(cr, Color(1, 1, 1, 0.9), false, 2.0)
		# toi
		if h.player != null and not h.player.is_dead:
			var sp := w2m(h.player.global_position)
			var f := h.player.forward()
			var dir := Vector2(f.x, f.z).normalized() if Vector2(f.x, f.z).length() > 0.01 else Vector2(0, -1)
			var side := Vector2(-dir.y, dir.x)
			var q := k
			var arrow := PackedVector2Array([sp + dir * 9.0 * q, sp - dir * 5.0 * q + side * 6.0 * q, sp - dir * 2.0 * q, sp - dir * 5.0 * q - side * 6.0 * q])
			RoyaleHudStyle.draw_inked_polygon(self, arrow, RoyaleHudStyle.SUN[1], 2.0)
		if big:
			RoyaleHudStyle.draw_pill(self, Vector2(size.x * 0.5, 4.0), "Carte · [%s] fermer" % Settings.action_label("map", 1), RoyaleHudStyle.PAPER, 15)
