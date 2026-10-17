class_name RoyaleHud
extends Control
## HUD d'état du Battle royale, v2 (lot BR-I1, backlog P0 n° 1 à 5 de `conception/benchmark/BATTLE_ROYALE.md` ; maquette 1
## de `battle_royale_maquettes/index.html`), dans la DA « autocollant manga » (RoyaleHudStyle) :
## - en haut à gauche, l'objectif court (titre + une ligne) à la place du panneau d'objectifs ;
## - sous la mini-carte, 3 tuiles d'encre (en vie, éliminations, niveau / plafond), la barre de l'anneau et son minuteur,
##   le fil des éliminations en pastilles ;
## - par-dessus le monde : flèches (zone sûre, héros proches hors de la vue, repère : RoyaleEdge) et arc de coup reçu (HitArc) ;
## - repère personnel (RoyalePing) : clic molette au sol, L3 à la manette (devant le héros) ;
## - grande carte v2 (RoyaleMap), ouverte seule pendant le vol.
## Lot BR-I3 (backlog P1-P2) : cadre de cible v2 (RoyaleTarget), annonces centrales une à la fois et onomatopées
## (RoyaleAnnounce, par le crochet de Hud.show_message), aide du largage à touches dessinées et altimètre (RoyaleDropHint),
## « Voir les sons » (RoyaleCues), son et ambiance (RoyaleAmbience), chiffres sobres et retours de coups (RoyaleCombat),
## premiers pas du mode (TIPS), « Niveau max » de l'anneau (rythme des récompenses).
## Posé par Hud (Hud._build) quand Royale.active ; aucune règle de jeu ne change. Coût mesuré par `test_bri1` (`tick`).

const COL_W := 230.0  # largeur de la colonne de droite (celle de la mini-carte)
const COL_X := -246.0  # comme la mini-carte (Hud._build_minimap)
const COL_Y := 252.0  # sous la mini-carte
const FEED_MAX := 4
const FEED_W := 340.0  # le fil déborde à gauche de la colonne : une élimination tient sur une ligne
## Premiers pas du mode (backlog P1 n° 15) : une fiche par moment, une fois par profil (records.royale_tips) ; ≤ 125 signes.
const TIPS := {
	"chute": {"title": "Le largage", "icon": "speed", "body": "Dirige ta chute vers ton repère. Piqué pour descendre vite, planeur pour finir en douceur. Personne ne frappe en l'air."},
	"anneau": {"title": "L'anneau", "icon": "clock", "body": "Dehors, l'anneau violet te ronge. Chaque anneau relève le niveau maximal : reste dedans et monte de niveau."},
	"butin": {"title": "Les dépouilles", "icon": "chest", "body": "Un héros tombé laisse une dépouille : fouille-la. « Tout le meilleur » prend d'un coup ce qui te sert."},
}

static var current: RoyaleHud  # (moments signalés par le directeur : RoyaleHud.moment)

var hud: Hud
var player: Player
var director: RunDirector
var edge: RoyaleEdge
var arc: HitArc
var map: RoyaleMap

var _goal: PanelContainer
var _goal_title: Label
var _goal_sub: Label
var _col: VBoxContainer
var _tiles: Array = []  # [{box, value, caption, kind}]
var _ring_box: PanelContainer
var _ring_name: Label
var _ring_time: Label
var _ring_gauge: Control
var _ring_ratio := 0.0
var _ring_tones: Array = RoyaleHudStyle.AMETHYST
var _feed: VBoxContainer
var _feed_sig := ""
var _ride_opened := false  # la carte s'est ouverte d'office pour ce vol
var _was_riding := false
var target: RoyaleTarget
var announce: RoyaleAnnounce
var drop_hint: RoyaleDropHint
var cues: RoyaleCues
var ambience: RoyaleAmbience
var _hooked := {}  # héros scripté (id) -> signaux branchés
var _hook_t := 0.0
var _cap_phase := -1  # anneau pour lequel « Niveau max » a été annoncé
var tips_shown: Array = []  # fiches montrées dans cette partie (tests)
## Pile des fiches du mode : à gauche, au milieu de l'écran (à droite, la colonne de la mini-carte et le fil sont pris).
var tips_cards: InfoCard


## Pose le HUD du Battle royale sur [param h] (après Hud._build).
static func attach(h: Hud, root: Control) -> RoyaleHud:
	var r := RoyaleHud.new()
	r.hud = h
	r.player = h.player
	r.director = h.director
	r.name = "RoyaleHud"
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	RoyalePing.reset()
	# flèches et arc : sous les panneaux du HUD (juste au-dessus du liseré de vie basse)
	r.edge = RoyaleEdge.new()
	r.edge.name = "RoyaleEdge"
	root.add_child(r.edge)
	root.move_child(r.edge, 1)
	r.edge.setup(r.player, r.director)
	r.arc = HitArc.attach(root, r.player)
	r.cues = RoyaleCues.new()  # « Voir les sons » : sous les panneaux, comme les flèches
	root.add_child(r.cues)
	root.move_child(r.cues, 2)
	r.cues.setup(r.player, r.director)
	root.add_child(r)
	r._build(h)
	r.map = RoyaleMap.new()
	root.add_child(r.map)  # au-dessus de tout le HUD
	r.map.setup(r.player, r.director)
	current = r
	return r


func _build(h: Hud) -> void:
	# objectif court (haut gauche), à la place du panneau d'objectifs
	_goal = PanelContainer.new()
	_goal.add_theme_stylebox_override("panel", UiTheme.panel_style(5, Vector2(16, 9)))
	_goal.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_goal.custom_minimum_size = Vector2(Hud.PANEL_W, 0)
	_goal.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var gv := VBoxContainer.new()
	gv.add_theme_constant_override("separation", 2)
	_goal.add_child(gv)
	_goal_title = RoyaleHudStyle.label(gv, "", 20, RoyaleHudStyle.INK, RoyaleHudStyle.title_font(), true)
	_goal_sub = RoyaleHudStyle.label(gv, "", 16, RoyaleHudStyle.INK_300, null, true)
	_goal_sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_goal_sub.custom_minimum_size = Vector2(Hud.PANEL_W - 40.0, 0)
	var left: VBoxContainer = h.get("_left")
	if left != null:
		left.add_child(_goal)
		left.move_child(_goal, 0)
	var obj = h.get("_obj_panel")
	if obj != null:
		obj.visible = false
	# colonne de droite : tuiles, anneau, fil
	_col = VBoxContainer.new()
	_col.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_col.position = Vector2(COL_X, COL_Y)
	_col.custom_minimum_size = Vector2(COL_W, 0)
	_col.add_theme_constant_override("separation", 8)
	_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_col)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_col.add_child(row)
	for kind in ["alive", "kills", "level"]:
		var box := PanelContainer.new()
		box.add_theme_stylebox_override("panel", RoyaleHudStyle.box("nuit", Vector2(4, 2), 3))
		box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		box.mouse_filter = Control.MOUSE_FILTER_PASS  # infobulle
		row.add_child(box)
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", -2)
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(v)
		var val := RoyaleHudStyle.label(v, "", 26, RoyaleHudStyle.PAPER, RoyaleHudStyle.num_font())
		val.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var cap := RoyaleHudStyle.label(v, {"alive": "en vie", "kills": "élim.", "level": "niveau"}[kind], 15, RoyaleHudStyle.INK_100, null)
		cap.add_theme_constant_override("outline_size", 0)
		cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.tooltip_text = {"alive": "Héros encore en jeu (toi compris)", "kills": "Tes éliminations", "level": "Ton niveau / le niveau maximal de cet anneau"}[kind]
		_tiles.append({"box": box, "value": val, "kind": kind, "shown": ""})
	_ring_box = PanelContainer.new()
	_ring_box.add_theme_stylebox_override("panel", RoyaleHudStyle.box("papier", Vector2(12, 6), 4))
	_ring_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_col.add_child(_ring_box)
	var rv := VBoxContainer.new()
	rv.add_theme_constant_override("separation", 3)
	_ring_box.add_child(rv)
	var rh := HBoxContainer.new()
	rv.add_child(rh)
	_ring_name = RoyaleHudStyle.label(rh, "", 15, RoyaleHudStyle.INK, null, true)
	_ring_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_ring_time = RoyaleHudStyle.label(rh, "", 17, RoyaleHudStyle.INK, RoyaleHudStyle.num_font(), true)
	_ring_gauge = Control.new()
	_ring_gauge.custom_minimum_size = Vector2(0, 18)
	_ring_gauge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ring_gauge.draw.connect(func(): RoyaleHudStyle.draw_gauge(_ring_gauge, Rect2(Vector2.ZERO, _ring_gauge.size - Vector2(3, 3)), _ring_ratio, _ring_tones))
	rv.add_child(_ring_gauge)
	_feed = VBoxContainer.new()
	_feed.add_theme_constant_override("separation", 5)
	_feed.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_feed.position = Vector2(COL_X + COL_W - FEED_W, COL_Y + 140.0)
	_feed.custom_minimum_size = Vector2(FEED_W, 0)
	_feed.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_feed)
	# lot BR-I3 : cadre de cible, aide du largage, annonces (au-dessus du reste du HUD), ambiance
	target = RoyaleTarget.new()
	add_child(target)
	drop_hint = RoyaleDropHint.new()
	add_child(drop_hint)
	drop_hint.setup(player, director)
	announce = RoyaleAnnounce.new()
	announce.player = player
	add_child(announce)
	RoyaleCombat.announce = announce
	ambience = RoyaleAmbience.new()
	ambience.setup(player, director)
	add_child(ambience)
	player.leveled_up.connect(_on_level_up)
	tips_cards = InfoCard.in_control(self)
	var box: Control = tips_cards.get("_box")
	box.anchor_left = 0.0
	box.anchor_right = 0.0
	box.offset_left = 14.0
	box.offset_right = 14.0 + InfoCard.W
	box.offset_top = -130.0  # (sous l'objectif et le fil de butin, au-dessus de l'aide du largage)
	box.offset_bottom = -130.0
	box.grow_horizontal = Control.GROW_DIRECTION_END


func _rd() -> RoyaleDirector:
	return director.royale if director != null else null


func map_open() -> bool:
	return map != null and map.is_open


func toggle_map() -> void:
	if map != null:
		map.toggle()
		if map.is_open:
			hud.hide_banner()


func _process(delta: float) -> void:
	tick(delta)


## Mise à jour d'une image (textes seulement s'ils changent) ; mesurée par test_bri1.
func tick(delta: float) -> void:
	var rd := _rd()
	if rd == null or player == null:
		visible = false
		return
	visible = true
	_update_goal(rd)
	_update_tiles(rd)
	_update_ring(rd)
	_update_feed(rd)
	_feed.position.y = _col.position.y + _col.size.y + 8.0  # (sous la barre de l'anneau)
	_update_ride(rd)
	var covered: bool = map.is_open and map.visible
	_update_target(rd, covered)
	var hint = hud.get("_drop_box")
	if hint != null:
		(hint as CanvasItem).visible = false  # (lot BR-I3 : remplacée par RoyaleDropHint, touches dessinées)
	# récapitulatif de mort ouvert : il dit déjà le retour, et rien ne passe derrière lui
	var recap_open: bool = rd.recap_view != null and is_instance_valid(rd.recap_view) and rd.recap_view.is_card_open()
	drop_hint.update(covered or recap_open)
	announce.visible = not recap_open
	_cover(covered)
	edge.bottom_extra = 120.0 if drop_hint.line.visible else 0.0  # (les flèches restent au-dessus de l'aide du largage)
	if player.is_dead and String(announce.current.get("kind", "")) in ["danger", "bounty_me"]:
		announce.clear()  # (un avertissement pour le joueur n'a plus de sens une fois tombé)
	_hook_t -= delta
	if _hook_t <= 0.0:
		_hook_t = 0.5
		_hook_heroes(rd)
		_tips(rd)


# --- objectif court -----------------------------------------------------------------------------------
func _update_goal(rd: RoyaleDirector) -> void:
	var title := ""
	var sub := ""
	if rd.spectating:
		var lines: Array = rd.objective_lines()  # (spectateur : textes du directeur, lot BR-I2)
		title = _strip(String(lines[0])) if lines.size() > 0 else "Tu regardes la fin"
		sub = " · ".join(lines.slice(1, 3).map(func(l): return _strip(String(l))))
	elif rd.phase == "drop":
		var ride: bool = rd.jump != null and rd.jump.on_board(player)
		title = "Largage"
		sub = "Choisis où sauter" if ride else ("Personne ne frappe en l'air" if rd.jump != null and rd.jump.airborne(player) else "L'anneau part quand tous sont au sol")
	else:
		var n := mini(int(rd.ring.get("phase", 0)) + 1, Royale.PHASES.size() - 1)
		title = "Dernier cercle" if String(rd.ring.get("state", "")) == "final" else "Anneau %d / %d" % [n, Royale.PHASES.size() - 1]
		if rd.bounty == player:
			sub = "★ Tu es mis à prix : tous te voient"
		elif edge != null and not edge.safe_zone().is_empty() and bool(edge.safe_zone()[2]):
			sub = "Rejoins la zone sûre !"
		elif rd.event != null and rd.event.objective() != "":
			sub = rd.event.objective()  # (lot BR-R1 : autel du gardien, losange sur la carte)
		elif not rd.active_drop().is_empty():
			sub = "★ Largage : étoile dorée sur la carte"
		elif rd.bounty != null and is_instance_valid(rd.bounty) and not rd.bounty.is_dead:
			sub = "★ %s est mis à prix" % rd.bounty.display_name.get_slice(" ·", 0)
		else:
			sub = "Pille, monte de niveau, reste dans l'anneau" if Royale.mod == "" else "%s en cours" % RoyaleMods.name_of(Royale.mod)  # (lot BR-R1)
	if _goal_title.text != title:
		_goal_title.text = title
	if _goal_sub.text != sub:
		_goal_sub.text = sub
	_goal_sub.visible = sub != ""


## Enlève les puces des lignes d'objectif (◆ ◇ ◉ ⚔).
static func _strip(t: String) -> String:
	for pre in ["◆ ", "◇ ", "◉ ", "⚔ ", "✔ "]:
		t = t.trim_prefix(pre)
	return t


# --- tuiles ---------------------------------------------------------------------------------------------
func _update_tiles(rd: RoyaleDirector) -> void:
	for t in _tiles:
		var text := ""
		var col := RoyaleHudStyle.PAPER
		match String(t.kind):
			"alive":
				text = str(rd.alive_count())
			"kills":
				text = str(Royale.kills)
				if rd.bounty == player:
					col = RoyaleHudStyle.STRAWBERRY[0]  # mis à prix : la tuile passe en fraise
			"level":
				text = "%d/%d" % [player.level, Royale.level_cap_now]
				if player.level >= Royale.level_cap_now:
					col = RoyaleHudStyle.SUN[0]  # au plafond de l'anneau
		var key := text + col.to_html()
		if t.shown == key:
			continue
		t.shown = key
		var val: Label = t.value
		val.text = text
		val.add_theme_color_override("font_color", col)
		val.add_theme_font_size_override("font_size", 26 if text.length() <= 3 else 21)


## Valeurs des tuiles (tests) : {alive, kills, level}.
func tile_values() -> Dictionary:
	var out := {}
	for t in _tiles:
		out[String(t.kind)] = (t.value as Label).text
	return out


# --- anneau ----------------------------------------------------------------------------------------------
func _update_ring(rd: RoyaleDirector) -> void:
	var name_ := ""
	var time := ""
	var ratio := 0.0
	var tones: Array = RoyaleHudStyle.AMETHYST
	if rd.phase == "drop":
		var down: int = Royale.PLAYERS - (rd.jump.count_airborne() if rd.jump != null else 0)
		name_ = "Au sol"
		time = "%d / %d" % [down, Royale.PLAYERS]
		ratio = float(down) / float(Royale.PLAYERS)
		tones = RoyaleHudStyle.LAGOON
	else:
		var ring := rd.ring
		var i := clampi(int(ring.get("phase", 0)), 0, Royale.PHASES.size() - 1)
		var ph: Dictionary = Royale.PHASES[i]
		var left := float(ring.get("left", 0.0))
		var secs := ceili(left)
		time = "%d:%02d" % [secs / 60, secs % 60]
		match String(ring.get("state", "hold")):
			"hold":
				name_ = "Se referme"
				ratio = left / maxf(float(ph.hold), 1.0)
			"shrink":
				name_ = "Se resserre"
				ratio = left / maxf(float(ph.shrink), 1.0)
				tones = RoyaleHudStyle.STRAWBERRY
			_:
				name_ = "Dernier cercle"
				time = ""
				ratio = 1.0
				tones = RoyaleHudStyle.STRAWBERRY
	if _ring_name.text != name_:
		_ring_name.text = name_
	if _ring_time.text != time:
		_ring_time.text = time
	if absf(ratio - _ring_ratio) > 0.002 or tones != _ring_tones:
		_ring_ratio = ratio
		_ring_tones = tones
		_ring_gauge.queue_redraw()


## Textes de la barre de l'anneau (tests).
func ring_texts() -> Array:
	return [_ring_name.text, _ring_time.text]


# --- fil des éliminations ---------------------------------------------------------------------------------
func _update_feed(rd: RoyaleDirector) -> void:
	var now: float = rd.clock
	var lines: Array = rd.kill_feed.filter(func(e): return now - float(e[1]) < 8.0)
	# petits écrans : pas plus de 3 pastilles (la barre d'action est proche)
	var cap := FEED_MAX if get_viewport_rect().size.y >= 800.0 else 3
	if lines.size() > cap:
		lines = lines.slice(lines.size() - cap)
	var sig := str(lines)
	if sig == _feed_sig:
		return
	_feed_sig = sig
	for c in _feed.get_children():
		_feed.remove_child(c)
		c.queue_free()
	for e in lines:
		var t := String(e[0])
		var mine := t.begins_with("Tu ")
		var pill := PanelContainer.new()
		pill.add_theme_stylebox_override("panel", RoyaleHudStyle.box("soleil" if mine else "papier", Vector2(12, 1), 3, 13))
		pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pill.size_flags_horizontal = Control.SIZE_SHRINK_END
		var l := RoyaleHudStyle.label(pill, t, 15, RoyaleHudStyle.INK, null, true)
		l.tooltip_text = t
		_feed.add_child(pill)
		# une ligne trop longue pour le fil est coupée (« … ») : jamais deux lignes par élimination
		var w := RoyaleHudStyle.text_font().get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x + 30.0
		if w > FEED_W:
			l.clip_text = true
			l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			l.custom_minimum_size = Vector2(FEED_W - 30.0, 0)


func feed_lines() -> Array:
	return _feed.get_children().map(func(p): return (p.get_child(0) as Label).text)


## Grande carte ouverte : le reste du HUD s'efface (une idée par écran) ; Hud rétablit ses panneaux à l'image suivante.
func _cover(open: bool) -> void:
	_col.visible = not open
	_feed.visible = not open
	edge.visible = not open
	var holder: Control = hud.minimap.get_parent().get_parent() if hud.minimap != null else null
	if holder != null:
		holder.visible = not open
	if open:
		target.visible = false
		announce.clear()
	cues.visible = not open
	if open:
		for key in ["_left", "_target_box", "_action_root"]:  # (Hud les remet à chaque image)
			var c = hud.get(key)
			if c != null:
				(c as CanvasItem).visible = false


# --- cadre de cible (lot BR-I3) ------------------------------------------------------------------------------
## Même cible que le cadre commun de Hud (verrouillée, sinon le héros le plus proche ; rien pendant un choix de carte),
## montrée dans le cadre v2 ; le cadre commun est caché.
func _update_target(rd: RoyaleDirector, covered: bool) -> void:
	var box = hud.get("_target_box")
	var t: Combatant = null
	if box != null and (box as CanvasItem).visible and not covered and not rd.spectating:
		var ref = hud.get("_target_ref")
		t = (ref as WeakRef).get_ref() as Combatant if ref is WeakRef else null
	if box != null:
		(box as CanvasItem).visible = false
	target.show_target(t, player, rd.bounty)


# --- annonces, moments, retours (lot BR-I3) -------------------------------------------------------------------
## Crochet de Hud.show_message : vrai si le message devient une annonce centrale (sinon Hud le garde : fil de butin).
func announce_message(text: String, duration: float) -> bool:
	if map_open() and not text.begins_with("Hors de l'anneau"):
		return true  # (la grande carte du vol dit déjà tout)
	return announce.push(text, duration)


## Moment signalé par le directeur : « gold_chest » (coffre doré ou largage ouvert : rayons et étincelles).
static func moment(kind: String) -> void:
	if current == null or not is_instance_valid(current):
		return
	match kind:
		"gold_chest":
			var at := current._hero_screen()
			UiFeel.ring(at, 30.0)
			UiFeel.sparkle(at, 6, ["soleil", "papier", "soleil", "mandarine"], 24.0)
			current.announce.word("Trésor !", RoyaleHudStyle.SUN)
		"jump":  # (lot BR-R1, backlog P2 n° 23 : petite fête au saut)
			UiFeel.sparkle(current._hero_screen(), 4, ["soleil", "lagon", "pomme", "fraise"], 20.0)
			current.announce.word("Hop !", RoyaleHudStyle.LAGOON)
		"thanks":  # remercier l'aigle
			UiFeel.sparkle(current._hero_screen(), 4, ["fraise", "papier", "fraise", "soleil"], 18.0)
			current.announce.word("Merci l'aigle !", RoyaleHudStyle.STRAWBERRY)


## Position du héros à l'écran (repère de la fenêtre, pour UiFeel).
func _hero_screen() -> Vector2:
	var cam := get_viewport().get_camera_3d()
	if cam == null or player == null or cam.is_position_behind(player.global_position):
		return get_viewport_rect().size * 0.5
	return cam.unproject_position(player.global_position + Vector3.UP * 1.6)


func _on_level_up(level: int) -> void:
	var rd := _rd()
	if rd == null or player.is_dead:
		return
	announce.word("Niveau !", RoyaleHudStyle.APPLE)
	# rythme des récompenses : au plafond de l'anneau, le joueur sait quand il pourra remonter
	var ph := int(rd.ring.get("phase", 0)) if not rd.ring.is_empty() else 0
	if level >= Royale.level_cap_now and _cap_phase != ph:
		_cap_phase = ph
		var nxt := Royale.level_cap(ph + 1)
		if nxt > Royale.level_cap_now:
			announce.push("Niveau max !\nLe prochain anneau ouvre le niveau %d" % nxt, 2.5)
		else:
			announce.push("Niveau max !\nTu es au sommet", 2.5)


## Branche les héros scriptés (nouveaux et revenants) : coups donnés par le joueur, éliminations.
func _hook_heroes(rd: RoyaleDirector) -> void:
	for a in rd.ais:
		if not is_instance_valid(a) or _hooked.has(a.get_instance_id()):
			continue
		_hooked[a.get_instance_id()] = true
		a.damaged.connect(RoyaleCombat.on_hero_damaged.bind(a, player))
		a.died.connect(_on_hero_died)


func _on_hero_died(who: Combatant, killer: Combatant) -> void:
	if killer != player or not is_instance_valid(who):
		return
	announce.word("K.O. !", RoyaleHudStyle.danger())
	RoyaleAmbience.cue("ko")
	var cam := get_viewport().get_camera_3d()
	if cam != null and not cam.is_position_behind(who.global_position):
		var at := cam.unproject_position(who.global_position + Vector3.UP * 1.4)
		UiFeel.ring(at, 26.0)
		UiFeel.sparkle(at, 4, ["fraise", "soleil", "papier", "lagon"], 18.0)


# --- premiers pas du mode (backlog P1 n° 15) -------------------------------------------------------------------
func _tips(rd: RoyaleDirector) -> void:
	if player.autoplay or bool(Profile.tutorial.get("cards_off", false)):
		return
	if tips_cards.count() > 0 or map_open() or get_tree().paused:
		return
	var j := rd.jump
	if j != null and j.airborne(player) and not j.on_board(player):
		show_tip("chute")
	elif rd.phase == "fight" and not rd.spectating and not player.is_dead:
		if rd.elapsed > 4.0:
			show_tip("anneau")
		if rd.kill_feed.size() > 0:
			show_tip("butin")


## Montre la fiche [param id] (TIPS) si ce profil ne l'a jamais vue ; vrai si elle est montrée.
func show_tip(id: String) -> bool:
	var seen: Array = Profile.records.get("royale_tips", [])
	if id in seen or not TIPS.has(id):
		return false
	seen.append(id)
	Profile.records["royale_tips"] = seen  # (gardé à la fin de la partie : Profile.reload_keep_records)
	tips_shown.append(id)
	var t: Dictionary = TIPS[id]
	tips_cards.add_card({"id": "royale_" + id, "icon": String(t.icon), "title": String(t.title), "body": String(t.body),
		"duration": 9.0, "kicker": "Battle royale", "buttons": [{"label": "Compris", "kind": "primary"}]})
	return true


# --- largage : carte d'office ------------------------------------------------------------------------------
func _update_ride(rd: RoyaleDirector) -> void:
	var riding: bool = rd.jump != null and rd.jump.on_board(player)
	if riding and not _ride_opened and not get_tree().paused and not map.is_open:
		_ride_opened = true
		map.open(true)
		hud.hide_banner()
	if _was_riding and not riding and map.is_open and map.for_ride:
		map.close()  # saut (touche, bouton ou saut automatique) : on voit sa chute
	_was_riding = riding
	if get_tree().paused and map.is_open:
		map.visible = false  # (choix de carte, menu : la carte attend)
	elif map.is_open:
		map.visible = true


# --- repère personnel ------------------------------------------------------------------------------------
## Souris : un clic sans glisser (en mode « clic droit », le clic molette maintenu tourne la caméra : pas de repère alors).
const PING_CLICK_PX := 8.0
const PING_CLICK_MS := 400
var _ping_down := Vector2.INF
var _ping_down_ms := 0


func _unhandled_input(event: InputEvent) -> void:
	if get_tree().paused or not event.is_action("ping"):
		return
	var rd := _rd()
	if rd == null or rd.spectating or player.is_dead:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed:
			_ping_down = mb.position
			_ping_down_ms = Time.get_ticks_msec()
		elif _ping_down != Vector2.INF and mb.position.distance_to(_ping_down) < PING_CLICK_PX and Time.get_ticks_msec() - _ping_down_ms < PING_CLICK_MS:
			_ping_down = Vector2.INF
			place_ping(event)
		return  # (la caméra garde son glisser)
	if event.is_pressed() and not event.is_echo():
		get_viewport().set_input_as_handled()
		place_ping(event)


## Repère : sur la grande carte (curseur), sous la souris (clic molette) ou devant le héros (manette).
func place_ping(event: InputEvent = null) -> void:
	if map.is_open and Gamepad.active:
		map.ping_at(map.cursor)
		map.cursor_shown = true
		return
	var m: Node = director.map
	var p := Vector3.INF
	if event is InputEventMouseButton:
		p = RoyalePing.under_cursor(get_viewport().get_camera_3d(), (event as InputEventMouseButton).position, m)
	if p == Vector3.INF:
		p = RoyalePing.ahead_of(player, m)
	RoyalePing.toggle(p, _rd())
