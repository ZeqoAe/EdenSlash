class_name AssaultHud
extends Control
## HUD de L'Assaut (lot TAC-7, étude conception/benchmark/TACTIQUE.md § 7.8, croquis tactique_maquettes/v2_hud_manche.svg ;
## DA v2 « autocollant manga » : RoyaleHudStyle, UiTheme, UiFeel). Posé par Hud._build quand Modes.current() == "assault",
## par-dessus le HUD commun (dont il cache le panneau d'objectifs de la Survie, la barre de niveau et l'or de run) :
## - en haut au centre, le BANDEAU DU SCORE : 4 + 4 portraits (classe, ✕ tramé = à terre, jauge soleil d'ultime des alliés,
##   anneau lagon = toi), score de chaque équipe sur sa couleur et son blason (TeamSigil), minuteur de manche (achat, manche,
##   mèche de la Charge en fraise), « Manche 8 · Attaque » ; dessous, la LIGNE DE LA CHARGE (portée, au sol, pose, posée, désamorçage) ;
## - en bas à gauche, l'OR de manche et la prime de la prochaine défaite (« prochaine manche : +1 500 au moins ») ;
## - sur la barre d'action : cases 2 et 3 non achetées tramées avec cadenas et prix, ultime avec sa jauge de points (x / 7),
##   bouclier d'armure en crans lagon au-dessus de la vie, fiole, deux utilitaires et outil à la place de la barre de niveau ;
## - sur la mini-carte (Minimap -> minimap_overlay) : sites, alliés et ce qu'ils voient, derniers vus « ? », bruits entendus, repère ;
##   dessous, le nom du lieu où tu es et le fil des éliminations en pastilles ;
## - annonces une à la fois (AssaultAnnounce) : manche, Charge, « 2 contre 4 ! », « À toi de jouer ! » ; « K.O. ! » sur le héros ;
## - repère ([ping] : clic molette, L3) posé au sol, vu à l'écran et sur la mini-carte ;
## - lot TAC-8 : carte de fin de manche (5 s, rien n'attend de clic), récapitulatif de chute, spectateur et ordres (AssaultRecap).
## Aucune règle de jeu ne change ici : tout se lit sur AssaultDirector (rd.team) et Assault.

static var current: AssaultHud

const BAND_W := 704.0
const BAND_H := 74.0
const LINE_H := 34.0
const PORT := 44.0
const PORT_GAP := 6.0
const COL_X := -372.0  # colonne de droite sous la mini-carte (comme le fil du Battle royale)
const COL_Y := 250.0
const FEED_LIFE := 8.0
const ROUND_CARD_SECS := 5.0

var hud: Hud
var player: Player
var rd: RunDirector
var announce: AssaultAnnounce
var arc: HitArc
var band: ScoreBand
var charge_line: ChargeLine
var gold_box: GoldBox
var items: ItemRow
var slot_marks: Array = []
var shield: ShieldMark
var column: SideColumn
var pin: PingPin
var round_card: PanelContainer
var recap: AssaultRecap
var _hooked := false
var _redraw_t := 0.0
var _cards_seen := 0
var _round_card_t := 0.0
var _alive_sig := ""
var _solo_said := -1
var _kills_seen := 0
var _views: Array = []  # [PackedVector2Array monde xz] : ce que voient les alliés (mini-carte), recalculé 3 fois par seconde
var _views_t := 0.0
var _icons: Dictionary = {}
var _prev_round := -1


## Pose le HUD de L'Assaut sur [param h] (après Hud._build).
static func attach(h: Hud, root: Control) -> AssaultHud:
	var a := AssaultHud.new()
	a.hud = h
	a.player = h.player
	a.rd = h.director
	a.name = "AssaultHud"
	a.set_anchors_preset(Control.PRESET_FULL_RECT)
	a.mouse_filter = Control.MOUSE_FILTER_IGNORE
	a.arc = HitArc.attach(root, a.player)
	root.add_child(a)
	a._build(root)
	current = a
	return a


## Directeur du mode (null tant qu'il n'est pas monté, ou hors Assaut).
func dd() -> AssaultDirector:
	if rd == null or not is_instance_valid(rd.team):
		return null
	return rd.team as AssaultDirector


func _exit_tree() -> void:
	if current == self:
		current = null


func _build(root: Control) -> void:
	# le HUD commun : ni objectifs de la Survie, ni barre de niveau (fiche fixe), ni niveau d'aide à côté
	for k in ["_obj_panel", "_xp_orb", "_assist_label"]:
		var c = hud.get(k)
		if c is CanvasItem:
			(c as CanvasItem).visible = false
	pin = PingPin.new()
	pin.h = self
	add_child(pin)
	band = ScoreBand.new()
	band.h = self
	add_child(band)
	for t in 2:
		var s := TeamSigil.make(t, 22)
		s.name = "Sigil%d" % t
		band.add_child(s)
		var score_x := 10.0 + 4 * PORT + 3 * PORT_GAP + 8.0  # (bord gauche de la case du score de gauche)
		s.position = Vector2(score_x - 10.0, -6.0) if t == TeamMatch.player_team else Vector2(BAND_W - score_x - 12.0, -6.0)
	charge_line = ChargeLine.new()
	charge_line.h = self
	add_child(charge_line)
	gold_box = GoldBox.new()
	gold_box.h = self
	add_child(gold_box)
	column = SideColumn.new()
	column.h = self
	add_child(column)
	var bar: Control = hud.get("_action_root")
	if bar != null:
		items = ItemRow.new()
		items.h = self
		items.position = Vector2(Hud.LEVEL_X, Hud.SLOT_Y + 2.0)
		items.size = Vector2(Hud.LIFE_X + Hud.LIFE_W - Hud.LEVEL_X, 70.0)
		bar.add_child(items)
		var slots: Array = hud.get("_slots")
		for i in slots.size():
			var m := SlotMark.new()
			m.h = self
			m.slot = i
			m.position = (slots[i] as Control).position
			m.size = (slots[i] as Control).size
			bar.add_child(m)
			slot_marks.append(m)
		var life: Control = hud.get("_hp_orb")
		if life != null:
			shield = ShieldMark.new()
			shield.h = self
			shield.position = life.position + Vector2(0, -9.0)
			shield.size = Vector2(life.size.x, 9.0)
			bar.add_child(shield)
			bar.move_child(shield, 0)  # (sous les cases et leurs touches dessinées)
	round_card = PanelContainer.new()
	round_card.name = "AssaultRoundCard"
	round_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	round_card.visible = false
	add_child(round_card)
	announce = AssaultAnnounce.new()
	announce.name = "AssaultAnnounce"
	announce.player = player
	add_child(announce)
	_layout()


func announce_message(text: String, duration: float) -> bool:
	if announce == null:
		return false
	var d := dd()
	announce.defending = d != null and Assault.team_of(d.player_key) == Assault.defense()
	return announce.push(text, duration)


func _area() -> Vector2:
	return size if size.x > 1.0 else get_viewport_rect().size


func k() -> float:
	return clampf(_area().y / 900.0, 0.8, 1.0)


func _layout() -> void:
	var a := _area()
	var kk := k()
	band.scale = Vector2(kk, kk)
	band.size = Vector2(BAND_W, BAND_H)
	band.position = Vector2(roundf((a.x - BAND_W * kk) * 0.5), 8.0)
	charge_line.scale = band.scale
	charge_line.size = Vector2(BAND_W, LINE_H)
	charge_line.position = Vector2(band.position.x, band.position.y + (BAND_H + 6.0) * kk)
	gold_box.scale = band.scale
	gold_box.size = GoldBox.SIZE
	gold_box.position = Vector2(14.0, a.y - (GoldBox.SIZE.y + 64.0) * kk)
	column.position = Vector2(a.x + COL_X, COL_Y)
	column.size = Vector2(356.0, 360.0)
	pin.size = a
	# la pile de gauche (quête suivie) passe sous le bandeau du score : en 1280 × 720 ils se croiseraient
	var left: Control = hud.get("_left")
	if left != null:
		left.position.y = band.position.y + (BAND_H + 10.0) * kk if a.x < 1500.0 else 12.0
	# cadre de cible sous la ligne de la Charge ; les annonces sous lui
	var tb: Control = hud.get("_target_box")
	var below := charge_line.position.y + (LINE_H + 6.0) * kk
	if tb != null:
		tb.position.y = below
		if tb.visible:
			below = tb.position.y + tb.size.y + 6.0
	# pile sous le bandeau : récapitulatif de chute, carte de fin de manche, puis l'annonce (jamais l'une sur l'autre)
	var top := below + 4.0
	if recap != null and recap.is_card_open():
		top = maxf(top, recap.card.position.y + recap.card.size.y + 8.0)
	if round_card.visible:
		round_card.reset_size()
		round_card.position = Vector2(roundf((a.x - round_card.size.x) * 0.5), top)
		top += round_card.size.y + 10.0
	announce.top_px = top
	if announce._holder != null and announce._holder.visible:
		announce._place()  # (le cadre de cible ou une carte peuvent apparaître pendant une annonce)


func _process(delta: float) -> void:
	var d := dd()
	if d == null:
		return
	_layout()
	_redraw_t -= delta
	if _redraw_t <= 0.0:
		_redraw_t = 0.1
		band.queue_redraw()
		charge_line.queue_redraw()
		gold_box.queue_redraw()
		if items != null:
			items.queue_redraw()
		for m in slot_marks:
			(m as Control).queue_redraw()
		column.queue_redraw()
	if shield != null:
		shield.queue_redraw()
	pin.queue_redraw()
	_views_t -= delta
	if _views_t <= 0.0:
		_views_t = 0.33
		_update_views(d)
	_moments(d)
	_round_cards(d, delta)
	_update_recap(d)
	if Assault.round_n != _prev_round:
		_prev_round = Assault.round_n
		_solo_said = -1


## Ce que voient le joueur et ses alliés debout (mini-carte) : polygones de visibilité d'AssaultVision.
func _update_views(d: AssaultDirector) -> void:
	_views = []
	if d.vision == null or not is_instance_valid(d.vision) or not d.vision.is_inside_tree():
		return
	var t := d.view_team()
	for k in Assault.alive_keys(t):
		var hh := d.hero(String(k))
		if hh != null and not hh.is_dead:
			_views.append(d.vision.visibility_polygon(hh.global_position))


## Moments : « 2 contre 4 ! » à chaque chute (effectifs inégaux), « À toi de jouer ! » quand tu restes seul debout, « K.O. ! ».
func _moments(d: AssaultDirector) -> void:
	if not Assault.phase in ["live", "planted"]:
		_alive_sig = ""
		return
	var me := TeamMatch.player_team
	var a := Assault.alive_keys(me).size()
	var b := Assault.alive_keys(1 - me).size()
	var sig := "%d-%d" % [a, b]
	if _alive_sig != "" and sig != _alive_sig and a > 0 and b > 0:
		if d.player_key != "" and a == 1 and bool(Assault.alive.get(d.player_key, false)) and _solo_said != Assault.round_n:
			_solo_said = Assault.round_n
			announce_message("À toi de jouer !\nTu es le dernier debout : %d contre %d" % [a, b], 2.6)
			UiFeel.cue("ui_banner", -8.0)
		elif a != b:
			announce_message("%d contre %d !" % [a, b], 1.6)
	_alive_sig = sig
	if d.player_key != "":
		var kills := int(Assault.stats.get(d.player_key, {}).get("kills", 0))
		if kills > _kills_seen:
			announce.word("K.O. !", RoyaleHudStyle.SUN)
			UiFeel.cue("ui_star", -10.0)
		_kills_seen = kills


# --- carte de fin de manche (lot TAC-8) ------------------------------------------------------------------------------

func _round_cards(d: AssaultDirector, delta: float) -> void:
	if d.round_cards.size() > _cards_seen:
		_cards_seen = d.round_cards.size()
		show_round_card(d.round_cards[-1])
	if round_card.visible:
		_round_card_t -= delta
		if _round_card_t <= 0.0 or Assault.phase == "done":
			round_card.visible = false


## Carte de fin de manche, non bloquante (5 s) : gagnée / perdue, comment (et qui), l'or gagné, le score.
func show_round_card(c: Dictionary) -> void:
	for ch in round_card.get_children():
		ch.queue_free()
	announce.clear()  # (une annonce de la manche finie n'a plus de sens)
	var mine := int(c.winner) == TeamMatch.player_team
	var last := int(c.get("match", -1)) >= 0
	var tone := "soleil" if mine else "papier"
	round_card.add_theme_stylebox_override("panel", UiTheme.sticker(tone, {"pad": Vector2(28, 10), "shadow": 6, "radius": 18}))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	round_card.add_child(v)
	var how := String(Assault.HOW.get(String(c.how), ""))
	var how_txt: String = {"elim": "Équipe adverse à terre" if mine else "Ton équipe à terre", "charge": "La Charge a explosé",
		"defuse": "Charge désamorcée", "time": "Temps écoulé"}.get(String(c.how), how)
	var title := RoyaleHudStyle.label(v, "Manche gagnée !" if mine else "Manche perdue…", 30, RoyaleHudStyle.WHITE if mine else RoyaleHudStyle.INK,
		RoyaleHudStyle.title_font(), not mine)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var sub := String(how_txt) + (" · " + String(c.by) if String(c.get("by", "")) != "" else "")
	var s := RoyaleHudStyle.label(v, sub, 17, RoyaleHudStyle.WHITE if mine else RoyaleHudStyle.INK, null, not mine)
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var sc: Array = c.get("score", [0, 0])
	var line := "%d - %d" % [int(sc[0]), int(sc[1])]
	var d := dd()
	if d != null and d.player_key != "":
		line += " · Or : +%s · total %s" % [RoyaleStyle.number(maxf(float(c.gold), 0.0)), RoyaleStyle.number(Assault.gold(d.player_key))]
	if bool(c.get("clutch", false)):
		line += " · seul contre trois !"
	if not last and int(c.n) == int(Assault.num("half")):
		line += " · mi-temps : on change de côté"
	var g := RoyaleHudStyle.label(v, line, 16, RoyaleHudStyle.WHITE if mine else RoyaleHudStyle.INK_300, RoyaleHudStyle.num_font(), not mine)
	g.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	g.name = "RoundGold"
	round_card.visible = not last  # (fin de partie : le bilan prend la suite)
	_round_card_t = ROUND_CARD_SECS
	round_card.reset_size()
	round_card.pivot_offset = round_card.size * 0.5
	round_card.rotation_degrees = -2.0
	round_card.modulate.a = 0.0
	round_card.scale = Vector2(1.12, 1.12)
	var tw := round_card.create_tween().set_parallel()
	tw.tween_property(round_card, "modulate:a", 1.0, 0.14)
	tw.tween_property(round_card, "scale", Vector2.ONE, 0.24).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	UiFeel.cue("ui_reward" if mine else "ui_notify", -8.0)
	_layout()


# --- chute, spectateur, ordres (lot TAC-8 : AssaultRecap) -------------------------------------------------------------

func _update_recap(d: AssaultDirector) -> void:
	var down := d.player_key != "" and player.is_dead and Assault.phase in ["live", "planted", "end"]
	if down and recap == null:
		recap = AssaultRecap.open(self, d)
	elif not down and recap != null:
		recap.close()
		recap = null
	var bar: Control = hud.get("_action_root")
	if bar != null:
		bar.visible = recap == null


# --- repère (ping) -----------------------------------------------------------------------------------------------------

const PING_CLICK_PX := 8.0
const PING_CLICK_MS := 400
var _ping_down := Vector2.INF
var _ping_down_ms := 0


func _unhandled_input(event: InputEvent) -> void:
	if get_tree().paused or not event.is_action("ping"):
		return
	var d := dd()
	if d == null or player.is_dead:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed:
			_ping_down = mb.position
			_ping_down_ms = Time.get_ticks_msec()
		elif _ping_down != Vector2.INF and mb.position.distance_to(_ping_down) < PING_CLICK_PX and Time.get_ticks_msec() - _ping_down_ms < PING_CLICK_MS:
			_ping_down = Vector2.INF
			place_ping(RoyalePing.under_cursor(get_viewport().get_camera_3d(), mb.position, d.map))
		return
	if event.is_pressed() and not event.is_echo():
		get_viewport().set_input_as_handled()
		place_ping(Vector3.INF)


## Pose le repère en [param p] (Vector3.INF : devant le héros), ou le retire s'il est tout près du précédent.
func place_ping(p: Vector3) -> bool:
	var d := dd()
	if d == null:
		return false
	if p == Vector3.INF:
		p = RoyalePing.ahead_of(player, d.map)
		var f := player.forward()
		p = d._ground(player.global_position + Vector3(f.x, 0, f.z).normalized() * 10.0)
	var on := d.set_ping(d._ground(p))
	Sfx.ui("confirm" if on else "click", -10.0)
	if on:
		var place := d.place_of(p)
		column.add_line("Repère" + (" · " + place if place != "" else ""), "lagon")
	return on


# --- mini-carte (appelée par Minimap._draw) -----------------------------------------------------------------------------

## Calque de la mini-carte : ce que voient les alliés (lagon clair), sites, alliés, derniers vus « ? », bruits, repère.
func minimap_overlay(mm: Control, w2s: Callable) -> void:
	var d := dd()
	if d == null or d.layout.is_empty():
		return
	var ink := RoyaleHudStyle.INK
	# ce que voit l'équipe : éventails en triangles (un polygone en étoile ne se triangule pas toujours, piège du lot TAC-2)
	var col := Color(RoyaleHudStyle.LAGOON[0], 0.26)
	for poly in _views:
		var pts: PackedVector2Array = poly
		if pts.size() < 3:
			continue
		var c := Vector2.ZERO
		for p in pts:
			c += p
		c /= pts.size()
		var sp := PackedVector2Array()
		sp.append(w2s.call(Vector3(c.x, 0, c.y)))
		for p in pts:
			sp.append(w2s.call(Vector3(p.x, 0, p.y)))
		var idx := PackedInt32Array()
		for i in pts.size():
			idx.append_array([0, i + 1, (i + 1) % pts.size() + 1])
		var cols := PackedColorArray()
		cols.resize(sp.size())
		cols.fill(col)
		RenderingServer.canvas_item_add_triangle_array(mm.get_canvas_item(), idx, sp, cols)
	# sites
	for s in Assault.SITES:
		var sp: Vector2 = w2s.call(d.site_pos(s))
		mm.draw_circle(sp, 9.0, ink)
		mm.draw_circle(sp, 7.0, RoyaleHudStyle.SUN[1])
		mm.draw_string(RoyaleHudStyle.num_font(), sp + Vector2(-4.5, 5.0), s, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, ink)
	# bruits entendus (2 s) : anneaux qui s'élargissent
	if d.vision != null and is_instance_valid(d.vision):
		var vt := d.view_team()
		for n in d.vision.heard_since(vt, 2.0):
			var age := float(d.vision.time) - float(n.t)
			var tone: Array = {"fight": RoyaleHudStyle.STRAWBERRY, "plant": RoyaleHudStyle.SUN, "defuse": RoyaleHudStyle.SUN}.get(String(n.kind), RoyaleHudStyle.COMMON)
			var sp: Vector2 = w2s.call(n.pos)
			mm.draw_arc(sp, 4.0 + age * 6.0, 0.0, TAU, 20, Color(tone[1], clampf(1.0 - age / 2.0, 0.0, 1.0)), 2.0, true)
		# derniers vus : « ? » fraise qui s'efface en 4 s
		var last: Dictionary = d.vision.last_seen(vt)
		for id in last:
			var c = instance_from_id(int(id))
			if not is_instance_valid(c) or (c as Combatant).is_dead or d.vision.sees(vt, c as Combatant):
				continue
			var age := float(d.vision.time) - float(last[id].t)
			if age > AssaultVision.LAST_SEEN:
				continue
			var a := 1.0 - age / AssaultVision.LAST_SEEN
			var sp: Vector2 = w2s.call(last[id].pos)
			mm.draw_circle(sp, 7.0, Color(ink, a))
			mm.draw_circle(sp, 5.5, Color(RoyaleHudStyle.STRAWBERRY[1], a))
			mm.draw_string(RoyaleHudStyle.num_font(), sp + Vector2(-3.5, 4.5), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1, 1, 1, a))
	# alliés (le joueur a déjà sa flèche) : ronds lagon contourés ; à terre : ✕
	for k in Assault.members[TeamMatch.player_team]:
		var key := String(k)
		if key == d.player_key:
			continue
		var hh := d.hero(key)
		if hh == null:
			continue
		var sp: Vector2 = w2s.call(hh.global_position)
		if hh.is_dead or not bool(Assault.alive.get(key, false)):
			mm.draw_line(sp + Vector2(-4, -4), sp + Vector2(4, 4), ink, 2.5)
			mm.draw_line(sp + Vector2(-4, 4), sp + Vector2(4, -4), ink, 2.5)
			continue
		mm.draw_circle(sp, 5.5, ink)
		mm.draw_circle(sp, 4.0, RoyaleHudStyle.LAGOON[1])
	# repère
	if d.ping != Vector3.INF:
		var sp: Vector2 = w2s.call(d.ping)
		var pts := PackedVector2Array([sp + Vector2(0, 2), sp + Vector2(-6, -9), sp + Vector2(6, -9)])
		RoyaleHudStyle.draw_inked_polygon(mm, pts, RoyaleHudStyle.LAGOON[1], 1.5)
		mm.draw_circle(sp + Vector2(0, -10), 5.5, ink)
		mm.draw_circle(sp + Vector2(0, -10), 4.0, RoyaleHudStyle.LAGOON[0])


## Texture d'icône de classe (cache).
func class_icon(cid: String) -> Texture2D:
	if not _icons.has(cid):
		_icons[cid] = UiTheme.texture(String(GameData.class_data(cid).get("icon", ""))) if cid != "" else null
	return _icons[cid]


## Lieu où se tient le héros regardé (« Halle ») : sous la mini-carte.
func view_place() -> String:
	var d := dd()
	if d == null:
		return ""
	var v := d.view_hero()
	return d.place_of(v.global_position) if v != null else ""


# =====================================================================================================================
# Pièces dessinées
# =====================================================================================================================

## Bandeau du score : 4 portraits, score et blason de chaque équipe, minuteur et manche au centre.
class ScoreBand extends Control:
	var h: AssaultHud

	func _init() -> void:
		name = "AssaultScore"
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var d := h.dd()
		if d == null:
			return
		var W := AssaultHud.BAND_W
		RoyaleHudStyle.draw_sticker(self, Rect2(0, 8, W, 58), RoyaleHudStyle.WELL, 16.0, 4.0)
		var me := TeamMatch.player_team
		for side in 2:
			var t := me if side == 0 else 1 - me
			for i in 4:
				var x := 10.0 + i * (AssaultHud.PORT + AssaultHud.PORT_GAP) if side == 0 else W - 10.0 - AssaultHud.PORT - (3 - i) * (AssaultHud.PORT + AssaultHud.PORT_GAP)
				_portrait(d, Rect2(x, 13, AssaultHud.PORT, AssaultHud.PORT), "t%d_%d" % [t, i], t == me)
			var sx := 10.0 + 4 * AssaultHud.PORT + 3 * AssaultHud.PORT_GAP + 8.0 if side == 0 else W - 10.0 - 4 * AssaultHud.PORT - 3 * AssaultHud.PORT_GAP - 8.0 - 56.0
			var sr := Rect2(sx, 2, 56, 66)
			RoyaleHudStyle.draw_sticker(self, sr, TeamMatch.color(t, "base"), 14.0, 4.0)
			draw_rect(Rect2(sr.position + Vector2(3, sr.size.y * 0.62), Vector2(sr.size.x - 6, sr.size.y * 0.38 - 3)), Color(TeamMatch.color(t, "fonce"), 0.45))
			RoyaleHudStyle.draw_text(self, Vector2(sr.position.x, sr.position.y + 48.0), str(int(Assault.score[t])), 38, RoyaleHudStyle.WHITE,
				RoyaleHudStyle.num_font(), HORIZONTAL_ALIGNMENT_CENTER, sr.size.x)
		# minuteur
		var cr := Rect2(W * 0.5 - 78.0, 0, 156, AssaultHud.BAND_H)
		var planted := Assault.phase == "planted"
		var fill := RoyaleHudStyle.PAPER
		if planted:
			fill = RoyaleHudStyle.danger()[1]
		elif Assault.phase == "buy":
			fill = RoyaleHudStyle.PAPER_200
		RoyaleHudStyle.draw_sticker(self, cr, fill, 16.0, 5.0)
		var secs := maxf(Assault.t, 0.0)
		var clock := "%d:%02d" % [int(ceilf(secs)) / 60, int(ceilf(secs)) % 60]
		var sub := "Manche %d · %s" % [Assault.round_n, Assault.side_name(me)]
		var big_col := RoyaleHudStyle.INK
		match Assault.phase:
			"buy":
				sub = "Achat · " + sub
			"planted":
				sub = "Charge en %s" % Assault.site
				big_col = RoyaleHudStyle.WHITE
			"end", "done":
				clock = "%d - %d" % [int(Assault.score[me]), int(Assault.score[1 - me])]
				sub = "Fin de manche"
			"live":
				if secs <= 10.0:
					big_col = RoyaleHudStyle.danger()[2]
		if Assault.in_overtime():
			sub += " · prolongation"
		if big_col == RoyaleHudStyle.WHITE:
			RoyaleHudStyle.draw_text(self, Vector2(cr.position.x, 40.0), clock, 32, big_col, RoyaleHudStyle.num_font(), HORIZONTAL_ALIGNMENT_CENTER, cr.size.x)
			RoyaleHudStyle.draw_text(self, Vector2(cr.position.x, 62.0), sub, 15, RoyaleHudStyle.WHITE, null, HORIZONTAL_ALIGNMENT_CENTER, cr.size.x)
		else:
			draw_string(RoyaleHudStyle.num_font(), Vector2(cr.position.x, 40.0), clock, HORIZONTAL_ALIGNMENT_CENTER, cr.size.x, 32, big_col)
			draw_string(RoyaleHudStyle.text_font(), Vector2(cr.position.x, 62.0), sub, HORIZONTAL_ALIGNMENT_CENTER, cr.size.x, 15, RoyaleHudStyle.INK_300)

	func _portrait(d: AssaultDirector, r: Rect2, key: String, ally: bool) -> void:
		var cid := String(d.classes.get(key, ""))
		var down := not bool(Assault.alive.get(key, false))
		var tones := RoyaleHudStyle.family_tones(cid)
		if key == d.player_key:
			RoyaleHudStyle.draw_sticker(self, r.grow(3.0), RoyaleHudStyle.LAGOON[0], 12.0, 0.0, 2.0)
		RoyaleHudStyle.draw_sticker(self, r, tones[1], 10.0, 2.0, 2.5)
		var tex := h.class_icon(cid)
		if tex != null:
			draw_texture_rect(tex, r.grow(-4.0), false)
		if down:
			draw_rect(r.grow(-2.5), Color(RoyaleHudStyle.WELL, 0.72))
			RoyaleHudStyle.draw_halftone(self, r.grow(-3.0), Color(1, 1, 1, 0.12), 6.0, 1.1)
			var c := r.get_center()
			for s in [1.0, -1.0]:
				draw_line(c + Vector2(-11, -11 * s), c + Vector2(11, 11 * s), RoyaleHudStyle.INK, 8.0, true)
				draw_line(c + Vector2(-11, -11 * s), c + Vector2(11, 11 * s), RoyaleHudStyle.danger()[1], 4.0, true)
		# Charge portée : pastille soleil (l'Attaque la voit toujours ; la Défense seulement si elle voit le porteur)
		if key == d.carrier and d.charge != null and d.charge.state == "carried" and d.charge_seen(TeamMatch.player_team):
			var p := r.position + Vector2(r.size.x - 2.0, 2.0)
			draw_circle(p, 8.0, RoyaleHudStyle.INK)
			draw_circle(p, 6.0, RoyaleHudStyle.SUN[1])
			draw_circle(p + Vector2(-1.5, -1.5), 2.0, RoyaleHudStyle.SUN[0])
		# jauge d'ultime des alliés (points / 7) ; l'adversaire ne la montre pas
		if ally and not down:
			var need := float(Assault.num("ult_points"))
			var ratio := clampf(float(d.ult_points(key)) / maxf(need, 1.0), 0.0, 1.0)
			var gr := Rect2(r.position.x + 2.0, r.end.y + 1.0, r.size.x - 4.0, 6.0)
			RoyaleHudStyle.draw_sticker(self, gr, RoyaleHudStyle.WELL, 3.0, 0.0, 1.5)
			if ratio > 0.0:
				draw_rect(Rect2(gr.position + Vector2(1.5, 1.5), Vector2((gr.size.x - 3.0) * ratio, gr.size.y - 3.0)),
					RoyaleHudStyle.SUN[0] if ratio >= 1.0 else RoyaleHudStyle.SUN[1])


## Ligne de la Charge sous le bandeau : qui la porte, où elle est, pose et désamorçage avec leur avancée.
class ChargeLine extends Control:
	var h: AssaultHud
	var text := ""  # (tests) dernier texte dessiné

	func _init() -> void:
		name = "AssaultChargeLine"
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	## [texte, ton (bonbon [clair, base, foncé]), avancée 0-1 (-1 : aucune), repère de sauvegarde 0-1 (-1 : aucun)].
	static func state(d: AssaultDirector) -> Array:
		if d == null or d.charge == null or not Assault.phase in ["buy", "live", "planted"]:
			return ["", RoyaleHudStyle.SUN, -1.0, -1.0]
		var me := TeamMatch.player_team
		var attack := Assault.attack == me
		var where := ""
		match d.charge.state:
			"planted":
				if d.defuse_by != "":
					var full := d._defuse_full()
					var who := d.hero_name(d.defuse_by)
					return ["Désamorçage · %s" % who if who != "Toi" else "Tu désamorces", RoyaleHudStyle.LAGOON, clampf(d.defuse_t / maxf(full, 0.01), 0.0, 1.0),
						clampf(Assault.num("defuse_save") / maxf(Assault.num("defuse_time"), 0.01), 0.0, 1.0)]
				var saved := " · reprise à %s s" % ("%.1f" % d.defuse_t).replace(".", ",") if d.defuse_t > 0.0 else ""
				return ["Charge posée en %s%s" % [Assault.site, saved], RoyaleHudStyle.danger() if not attack else RoyaleHudStyle.SUN, -1.0, -1.0]
			"ground":
				if not d.charge_seen(me):
					return ["La Charge : pas en vue", RoyaleHudStyle.COMMON, -1.0, -1.0]
				where = d.place_of(d.charge.global_position)
				return ["Charge au sol" + (" · " + where if where != "" else ""), RoyaleHudStyle.MANDARIN, -1.0, -1.0]
			"carried":
				if d.plant_by != "" and Assault.phase == "live":
					var who := d.hero_name(d.plant_by)
					return ["Tu poses la Charge" if who == "Toi" else "Pose · %s" % who, RoyaleHudStyle.SUN,
						clampf(d.plant_t / maxf(d._plant_full(d.plant_by), 0.01), 0.0, 1.0), -1.0]
				if attack:
					if d.carrier == d.player_key:
						return ["Charge : tu la portes · pose-la en A ou en B", RoyaleHudStyle.SUN, -1.0, -1.0]
					return ["Charge : %s la porte" % d.hero_name(d.carrier), RoyaleHudStyle.SUN, -1.0, -1.0]
				if d.charge_seen(me) and d.carrier != "":
					var hh := d.hero(d.carrier)
					where = d.place_of(hh.global_position) if hh != null else ""
					return ["Porteur repéré : %s" % d.hero_name(d.carrier) + (" · " + where if where != "" else ""), RoyaleHudStyle.danger(), -1.0, -1.0]
				return ["Défends A et B : la Charge n'est pas en vue", RoyaleHudStyle.COMMON, -1.0, -1.0]
		return ["", RoyaleHudStyle.SUN, -1.0, -1.0]

	func _draw() -> void:
		var st := state(h.dd())
		text = String(st[0])
		if text == "":
			return
		var tones: Array = st[1]
		var f := RoyaleHudStyle.text_font()
		var fs := 17
		var tw := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var w := tw + 58.0
		var r := Rect2((size.x - w) * 0.5, 2.0, w, 28.0)
		var paper := tones == RoyaleHudStyle.COMMON
		RoyaleHudStyle.draw_sticker(self, r, RoyaleHudStyle.PAPER if paper else tones[1], 14.0, 3.0)
		# pastille de la Charge (boule soleil, mèche fraise)
		var c := r.position + Vector2(18.0, r.size.y * 0.5)
		draw_circle(c, 9.0, RoyaleHudStyle.INK)
		draw_circle(c, 7.0, RoyaleHudStyle.SUN[1])
		draw_circle(c + Vector2(-2, -2), 2.4, RoyaleHudStyle.SUN[0])
		draw_line(c + Vector2(3, -6), c + Vector2(7, -11), RoyaleHudStyle.STRAWBERRY[1], 2.5)
		if paper:
			draw_string(f, Vector2(r.position.x + 34.0, r.position.y + 20.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, RoyaleHudStyle.INK)
		else:
			RoyaleHudStyle.draw_text(self, Vector2(r.position.x + 34.0, r.position.y + 20.0), text, fs, RoyaleHudStyle.WHITE, f)
		var prog := float(st[2])
		if prog >= 0.0:
			var pr := Rect2(r.position.x + 10.0, r.end.y + 1.0, r.size.x - 20.0, 7.0)
			RoyaleHudStyle.draw_gauge(self, pr, prog, tones)
			var save := float(st[3])
			if save > 0.0:
				var x := pr.position.x + 3.0 + (pr.size.x - 6.0) * save
				draw_line(Vector2(x, pr.position.y - 2.0), Vector2(x, pr.end.y + 2.0), RoyaleHudStyle.PAPER, 2.0)


## Or de manche (bas gauche) : l'or, la prime de la prochaine défaite (« au moins ») ; pendant l'achat, le plan de l'équipe.
class GoldBox extends Control:
	const SIZE := Vector2(304, 64)
	var h: AssaultHud
	var text := ""  # (tests)

	func _init() -> void:
		name = "AssaultGold"
		mouse_filter = Control.MOUSE_FILTER_PASS

	## « prochaine manche : +1 500 au moins » ; pendant l'achat, le plan de l'équipe.
	static func second_line() -> String:
		var me := TeamMatch.player_team
		if Assault.phase == "buy" and AssaultItems.plans[me] != "":
			return "Plan : " + String(AssaultItems.PLAN_NAMES.get(AssaultItems.plans[me], "")).to_lower()
		return "prochaine manche : +%s au moins" % RoyaleStyle.number(Assault.next_loss_gold(me))

	func _draw() -> void:
		var d := h.dd()
		if d == null or d.player_key == "":
			return
		var me := TeamMatch.player_team
		var r := Rect2(Vector2.ZERO, SIZE)
		RoyaleHudStyle.draw_sticker(self, r, RoyaleHudStyle.WELL, 14.0, 4.0)
		var coin := Ico.tex("coin", 32)
		if coin != null:
			draw_texture_rect(coin, Rect2(10, 7, 28, 28), false)
		var g := Assault.gold(d.player_key)
		RoyaleHudStyle.draw_text(self, Vector2(44, 32), RoyaleStyle.number(g), 26, RoyaleHudStyle.SUN[0], RoyaleHudStyle.num_font())
		var gw := RoyaleHudStyle.num_font().get_string_size(RoyaleStyle.number(g), HORIZONTAL_ALIGNMENT_LEFT, -1, 26).x
		RoyaleHudStyle.draw_text(self, Vector2(50 + gw, 31), "or", 15, RoyaleHudStyle.INK_100)
		var line := second_line()
		text = "%d or · %s" % [g, line]
		draw_string(RoyaleHudStyle.text_font(), Vector2(12, 54), line, HORIZONTAL_ALIGNMENT_LEFT, SIZE.x - 20.0, 14, RoyaleHudStyle.PAPER)
		tooltip_text = "Or de manche : %s (plafond %s).\nVictoire +%s ; défaite +%s, puis plus à chaque défaite de suite ; élimination +%s ; pose +%s." % [
			RoyaleStyle.number(g), RoyaleStyle.number(Assault.num("gold_cap")), RoyaleStyle.number(Assault.num("win_gold")),
			RoyaleStyle.number(Assault.next_loss_gold(me)), RoyaleStyle.number(Assault.num("kill_gold")), RoyaleStyle.number(Assault.num("plant_gold"))]


## Fiole, deux utilitaires et l'outil, à la place de la barre de niveau : icône, nombre, touche dessinée dessous.
class ItemRow extends Control:
	const CELL := 44.0
	const STEP := 50.0
	var h: AssaultHud
	var cells: Array = []  # (tests) [{id, n, key}]

	func _init() -> void:
		name = "AssaultItems"
		mouse_filter = Control.MOUSE_FILTER_PASS

	static func entries(key: String) -> Array:
		var v := AssaultItems.inv(key)
		var out: Array = []
		out.append({"id": String(v.fiole), "n": 1 if String(v.fiole) != "" else 0, "key": Settings.action_label("potion_1", 1), "what": "Fiole"})
		var ids: Array = (v.utils as Dictionary).keys().filter(func(u): return int(v.utils[u]) > 0)
		for i in 2:
			var id := String(ids[i]) if i < ids.size() else ""
			out.append({"id": id, "n": int(v.utils.get(id, 0)), "key": Settings.action_label("potion_2" if i == 0 else "extract", 1),
				"what": "Utilitaire"})
		out.append({"id": String(v.tool), "n": 1 if String(v.tool) != "" else 0, "key": "", "what": "Outil"})
		return out

	func _draw() -> void:
		var d := h.dd()
		if d == null or d.player_key == "":
			return
		cells = entries(d.player_key)
		var tips: Array = []
		for i in cells.size():
			var e: Dictionary = cells[i]
			var r := Rect2(i * STEP, 4.0, CELL, CELL)
			var empty := String(e.id) == ""
			RoyaleHudStyle.draw_sticker(self, r, RoyaleHudStyle.WELL if not empty else Color(RoyaleHudStyle.WELL, 0.6), 12.0, 3.0)
			if empty:
				RoyaleHudStyle.draw_halftone(self, r.grow(-4.0), Color(1, 1, 1, 0.1), 6.0, 1.1)
			else:
				var tex := Ico.tex(String(AssaultItems.LIST.get(String(e.id), {}).get("icon", "")), 64)
				if tex != null:
					draw_texture_rect(tex, r.grow(-6.0), false)
				if int(e.n) > 1:
					var p := r.position + Vector2(r.size.x - 3.0, 3.0)
					draw_circle(p, 9.0, RoyaleHudStyle.INK)
					draw_circle(p, 7.0, RoyaleHudStyle.STRAWBERRY[1])
					RoyaleHudStyle.draw_text(self, p + Vector2(-8.0, 5.0), str(int(e.n)), 13, RoyaleHudStyle.WHITE, RoyaleHudStyle.num_font(), HORIZONTAL_ALIGNMENT_CENTER, 16.0)
				tips.append("%s : %s%s" % [String(e.what), String(AssaultItems.LIST.get(String(e.id), {}).get("name", e.id)),
					" [%s]" % String(e.key) if String(e.key) != "" else ""])
			if String(e.key) != "":
				HudV2.key_pill(self, Vector2(r.get_center().x, r.end.y + 9.0), String(e.key))
		tooltip_text = "\n".join(tips) if not tips.is_empty() else "Fiole, utilitaires et outil : achète-les pendant l'achat ([B])."


## Case de sort : cadenas et prix tant qu'elle n'est pas achetée ; ultime : jauge de points (x / 7), éclat quand il est prêt.
class SlotMark extends Control:
	var h: AssaultHud
	var slot := 0
	var state := ""  # (tests) "free", "owned", "locked", "ult", "ult_ready"

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	## État de la case [param i] du joueur : free (signature), owned (achetée), locked (à acheter), ult, ult_ready ("" : rien).
	static func state_of(d: AssaultDirector, i: int) -> String:
		if d == null or d.player_key == "":
			return ""
		if i == 0:
			return "free"
		if i == 3:
			return "ult_ready" if d.ult_points(d.player_key) >= int(Assault.num("ult_points")) else "ult"
		return "owned" if i in d.owned_slots(d.player_key) else "locked"

	func _draw() -> void:
		var d := h.dd()
		state = state_of(d, slot)
		if state in ["", "free", "owned"]:
			return
		var r := Rect2(Vector2.ZERO, size)
		if slot == 3:
			var need := int(Assault.num("ult_points"))
			var pts := d.ult_points(d.player_key)
			var ready := state == "ult_ready"
			if not ready:
				draw_rect(r.grow(-3.0), Color(RoyaleHudStyle.WELL, 0.55))
				RoyaleHudStyle.draw_halftone(self, r.grow(-4.0), Color(1, 1, 1, 0.12), 6.0, 1.1)
			# jauge en arc autour de la case : un cran par point
			var c := r.get_center()
			var rad := r.size.x * 0.5 - 3.0
			for i in need:
				var a0 := -PI * 0.5 + TAU * i / need + 0.06
				var a1 := -PI * 0.5 + TAU * (i + 1) / need - 0.06
				draw_arc(c, rad, a0, a1, 8, RoyaleHudStyle.INK, 8.0, true)
				draw_arc(c, rad, a0, a1, 8, RoyaleHudStyle.SUN[0] if ready else (RoyaleHudStyle.SUN[1] if i < pts else RoyaleHudStyle.INK_300), 4.5, true)
			if not ready:
				RoyaleHudStyle.draw_pill(self, Vector2(c.x, r.position.y + 2.0), "%d / %d" % [pts, need], RoyaleHudStyle.PAPER, 13)
			return
		draw_rect(r.grow(-3.0), Color(RoyaleHudStyle.WELL, 0.62))
		RoyaleHudStyle.draw_halftone(self, r.grow(-4.0), Color(1, 1, 1, 0.14), 6.0, 1.1)
		var lock := Ico.tex("lock", 32)
		if lock != null:
			draw_texture_rect(lock, Rect2(r.get_center() - Vector2(13, 17), Vector2(26, 26)), false)
		var sl: Array = AssaultCombat.slots(String(d.classes.get(d.player_key, "")))
		var price := int((sl[slot] as Dictionary).get("price", 0)) if slot < sl.size() else 0
		if price > 0:
			RoyaleHudStyle.draw_pill(self, Vector2(r.get_center().x, r.position.y + 2.0), "%d or" % price, RoyaleHudStyle.SUN[0], 13)


## Bouclier d'armure (gilet, cuirasse) : bande lagon en crans posée sur le haut de la jauge de vie (un cran = un dixième des
## PV max), sous les cases et leurs touches.
class ShieldMark extends Control:
	var h: AssaultHud
	var ratio := 0.0  # (tests)

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	static func ratio_of(p: Player) -> float:
		if p == null or p.is_dead:
			return 0.0
		return clampf(float(p.get_meta("assault_shield", 0.0)) / maxf(p.max_hp, 1.0), 0.0, 1.0)

	func _draw() -> void:
		ratio = ratio_of(h.player)
		if ratio <= 0.0:
			return
		var inner := Rect2(Vector2(14, 0), Vector2(size.x - 28.0, size.y))
		var band := Rect2(inner.position + Vector2(0, 1.0), Vector2(inner.size.x * ratio, 7.0))
		draw_rect(band.grow(1.0), RoyaleHudStyle.INK)
		draw_rect(band, RoyaleHudStyle.LAGOON[1])
		draw_rect(Rect2(band.position, Vector2(band.size.x, 3.0)), RoyaleHudStyle.LAGOON[0])
		var step := inner.size.x * 0.1  # un cran par dixième des PV max
		var x := inner.position.x + step
		while x < band.end.x - 1.0:
			draw_line(Vector2(x, band.position.y), Vector2(x, band.end.y), RoyaleHudStyle.INK, 2.0)
			x += step


## Colonne de droite sous la mini-carte : lieu du héros regardé, fil des éliminations et lignes courtes (repère, réponses
## des alliés aux ordres) en pastilles.
class SideColumn extends Control:
	var h: AssaultHud
	var lines: Array = []  # [{text, tone, t}]
	var shown: Array = []  # (tests) textes affichés

	func _init() -> void:
		name = "AssaultColumn"
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func add_line(text: String, tone := "papier") -> void:
		lines.append({"text": text, "tone": tone, "t": TeamMatch.elapsed})
		if lines.size() > 6:
			lines.pop_front()
		queue_redraw()

	func _draw() -> void:
		var d := h.dd()
		shown = []
		if d == null:
			return
		var f := RoyaleHudStyle.text_font()
		var y := 4.0
		var right := size.x
		var place := h.view_place()
		if place != "":
			var w := f.get_string_size(place, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x + 26.0
			var r := Rect2(right - 230.0 + (230.0 - w) * 0.5 - 0.0, y, w, 26.0)
			RoyaleHudStyle.draw_sticker(self, r, RoyaleHudStyle.PAPER, 13.0, 3.0)
			draw_string(f, Vector2(r.position.x + 13.0, r.position.y + 18.0), place, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, RoyaleHudStyle.INK)
			shown.append(place)
			y += 34.0
		var now := TeamMatch.elapsed
		var entries: Array = []
		for e in d.ko_log:
			if now - float(e.t) <= AssaultHud.FEED_LIFE:
				entries.append({"ko": e, "t": float(e.t)})
		for l in lines:
			if now - float(l.t) <= AssaultHud.FEED_LIFE:
				entries.append({"line": l, "t": float(l.t)})
		entries.sort_custom(func(a, b): return float(a.t) < float(b.t))
		for e in entries.slice(maxi(0, entries.size() - 5)):
			var a := clampf((AssaultHud.FEED_LIFE - (now - float(e.t))) / 1.0, 0.0, 1.0)
			if e.has("ko"):
				y += _ko_pill(d, e.ko, y, right, a)
			else:
				var l: Dictionary = e.line
				var txt := String(l.text)
				var w := f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x + 24.0
				var r := Rect2(right - w, y, w, 24.0)
				var fill: Color = RoyaleHudStyle.LAGOON[1] if String(l.tone) == "lagon" else RoyaleHudStyle.PAPER
				RoyaleHudStyle.draw_sticker(self, r, Color(fill, a), 12.0, 2.0, 2.0)
				if String(l.tone) == "lagon":
					RoyaleHudStyle.draw_text(self, Vector2(r.position.x + 12.0, r.position.y + 17.0), txt, 15, Color(1, 1, 1, a), f)
				else:
					draw_string(f, Vector2(r.position.x + 12.0, r.position.y + 17.0), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(RoyaleHudStyle.INK, a))
				shown.append(txt)
				y += 30.0

	## « Kage ⚔ Paladin » : pastille d'encre, le nom de chaque héros précédé du point de son équipe ; toi en soleil.
	func _ko_pill(d: AssaultDirector, e: Dictionary, y: float, right: float, a: float) -> float:
		var f := RoyaleHudStyle.text_font()
		var kk := String(e.killer)
		var vk := String(e.victim)
		var kn := d.hero_name(kk) if kk != "" else "La Charge"
		var vn := d.hero_name(vk)
		var mid := "  ⚔  "
		var w := f.get_string_size(kn + mid + vn, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x + 52.0
		var r := Rect2(right - w, y, w, 24.0)
		RoyaleHudStyle.draw_sticker(self, r, Color(RoyaleHudStyle.WELL, a), 12.0, 2.0, 2.0)
		var x := r.position.x + 10.0
		var tk := Assault.team_of(kk)
		if kk != "" and tk >= 0:
			draw_circle(Vector2(x + 5.0, r.position.y + 12.0), 5.0, Color(TeamMatch.color(tk, "base"), a))
			x += 14.0
		var kc: Color = RoyaleHudStyle.SUN[0] if kk == d.player_key else RoyaleHudStyle.PAPER
		RoyaleHudStyle.draw_text(self, Vector2(x, r.position.y + 17.0), kn, 15, Color(kc, a), f)
		x += f.get_string_size(kn, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
		draw_string(f, Vector2(x, r.position.y + 17.0), mid, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(RoyaleHudStyle.INK_100, a))
		x += f.get_string_size(mid, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
		var tv := Assault.team_of(vk)
		if tv >= 0:
			draw_circle(Vector2(x + 5.0, r.position.y + 12.0), 5.0, Color(TeamMatch.color(tv, "base"), a))
			x += 14.0
		var vc: Color = RoyaleHudStyle.SUN[0] if vk == d.player_key else RoyaleHudStyle.PAPER
		RoyaleHudStyle.draw_text(self, Vector2(x, r.position.y + 17.0), vn, 15, Color(vc, a), f)
		shown.append(kn + " ⚔ " + vn)
		return 30.0


## Repère du joueur à l'écran : épingle lagon au sol, avec le lieu et la distance.
class PingPin extends Control:
	var h: AssaultHud

	func _init() -> void:
		name = "AssaultPing"
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var d := h.dd()
		if d == null or d.ping == Vector3.INF:
			return
		var cam := get_viewport().get_camera_3d()
		if cam == null or cam.is_position_behind(d.ping):
			return
		var v := d.view_hero()
		var from := v.global_position if v != null else d.ping
		var dist := Vector2(d.ping.x - from.x, d.ping.z - from.z).length()
		if dist < 2.5 and v == h.player:
			return
		var sp := get_global_transform_with_canvas().affine_inverse() * cam.unproject_position(d.ping + Vector3.UP * 0.2)
		var bounce := maxf(0.0, 1.0 - float(Time.get_ticks_msec() - d.ping_ms) / 300.0) * 10.0
		var tip := sp - Vector2(0, bounce)
		var pts := PackedVector2Array([tip, tip + Vector2(-10, -18), tip + Vector2(10, -18)])
		RoyaleHudStyle.draw_inked_polygon(self, pts, RoyaleHudStyle.LAGOON[1], 3.0)
		draw_circle(tip + Vector2(0, -22), 12.0, RoyaleHudStyle.INK)
		draw_circle(tip + Vector2(0, -22), 9.0, RoyaleHudStyle.LAGOON[0])
		var place := d.place_of(d.ping)
		RoyaleHudStyle.draw_pill(self, tip + Vector2(0, -46), "%s%d m" % [place + " · " if place != "" else "", roundi(dist)], RoyaleHudStyle.PAPER, 14)
