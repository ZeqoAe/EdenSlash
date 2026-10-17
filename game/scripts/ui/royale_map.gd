class_name RoyaleMap
extends Control
## Grande carte du Battle royale, v2 (lot BR-I1, backlog P0 n° 5 ; maquette 2 de
## `conception/benchmark/battle_royale_maquettes/index.html`) : la carte à gauche (terrain, anneau actuel et dehors teinté
## améthyste, prochain anneau en pointillés, trajet de l'aigle et bande « atteignable en chute », lieux nommés s'il y en a,
## coffres, largage, mis à prix, repère, toi), un panneau à droite (légende hors de la carte).
## Pendant le vol elle s'ouvre seule (RoyaleHud) : « Où atterrir ? », saut automatique, « Sauter » (A à la manette),
## repère d'un clic (X à la manette) ; elle se ferme au saut. Ensuite [Carte] l'ouvre et la ferme.
## Souris : clic = repère (un 2e clic au même endroit l'enlève), molette = zoom. Manette : stick (gauche à bord, droit au sol)
## = curseur, X à bord / L3 = repère, R3 = zoom, A = Sauter, B = fermer (à bord). Le jeu n'est pas mis en pause.

const ZOOMS := [1.0, 2.0, 3.5]
const SIDE_W := 420.0  # px à 900 de haut
const GUTTER := 40.0
const CURSOR_SPEED := 520.0  # px/s, stick au bout

var player: Player
var director: RunDirector
var is_open := false
var for_ride := false  # ouverte d'office pendant le vol (fermée au saut)
var zoom_i := 0
var view_center := Vector2.INF  # centre de la vue (m) ; INF : carte entière
var cursor := Vector2.ZERO  # curseur de la manette, dans la vue (px)
var cursor_shown := false

var _veil: ColorRect
var _view: Control
var _side: PanelContainer
var _title: Label
var _ring_line: Label
var _timer_box: Control
var _timer_label: Label
var _gauge: Control
var _info_well: PanelContainer
var _info_a: Label
var _info_b: Label
var _jump_btn: Button
var _close_btn: Button
var _legend: Control
var _hint: Label
var _footer: Label
var _k := 1.0
var _side_size := Vector2.ZERO
var _rig_input := true
var _sig := ""


func setup(p: Player, d: RunDirector) -> void:
	player = p
	director = d
	name = "RoyaleMap"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_build()


func _rd() -> RoyaleDirector:
	return director.royale if director != null else null


# --- construction -----------------------------------------------------------------------------
func _build() -> void:
	_veil = ColorRect.new()
	_veil.color = RoyaleHudStyle.VEIL
	_veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_veil)
	_view = Control.new()
	_view.clip_contents = true
	_view.mouse_filter = Control.MOUSE_FILTER_STOP
	_view.draw.connect(_draw_view)
	_view.gui_input.connect(_view_input)
	add_child(_view)
	_side = PanelContainer.new()
	_side.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_side)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	_side.add_child(v)
	_title = RoyaleHudStyle.label(v, "", 30, RoyaleHudStyle.INK, RoyaleHudStyle.title_font(), true)
	_title.rotation_degrees = -3.0
	_ring_line = RoyaleHudStyle.label(v, "", 16, RoyaleHudStyle.INK_300, null, true)
	_ring_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_timer_box = VBoxContainer.new()
	_timer_box.add_theme_constant_override("separation", 4)
	v.add_child(_timer_box)
	_timer_label = RoyaleHudStyle.label(_timer_box, "", 16, RoyaleHudStyle.INK, null, true)
	_gauge = Control.new()
	_gauge.custom_minimum_size = Vector2(0, 22)
	_gauge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_gauge.draw.connect(_draw_gauge)
	_timer_box.add_child(_gauge)
	_info_well = PanelContainer.new()
	_info_well.add_theme_stylebox_override("panel", UiTheme.well_style(Vector2(12, 10)))
	_info_well.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(_info_well)
	var iv := VBoxContainer.new()
	iv.add_theme_constant_override("separation", 4)
	_info_well.add_child(iv)
	_info_a = RoyaleHudStyle.label(iv, "", 17, RoyaleHudStyle.PAPER)
	_info_a.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info_b = RoyaleHudStyle.label(iv, "", 15, RoyaleHudStyle.INK_100)
	_info_b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_legend = Control.new()
	_legend.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_legend.draw.connect(_draw_legend)
	v.add_child(_legend)
	_jump_btn = _button(v, "Sauter", true)
	_jump_btn.pressed.connect(press_jump)
	_close_btn = _button(v, "Fermer la carte", false)
	_close_btn.pressed.connect(close)
	_hint = RoyaleHudStyle.label(v, "", 15, RoyaleHudStyle.INK_300, null, true)
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_footer = RoyaleHudStyle.label(v, "", 15, RoyaleHudStyle.INK_300, null, true)


## Bouton autocollant : primaire = soleil, texte blanc contouré (Mochiy) ; sinon papier, texte encre.
func _button(parent: Control, text: String, primary: bool) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 64 if primary else 52)
	UiTheme.style_button(b, "soleil" if primary else "papier", 24 if primary else 18, {"shadow": 5, "pad": Vector2(16, 6)})
	# touche en pastille à droite (Bible § 6 : A pomme, B fraise, X lagon, Y soleil ; clavier : papier)
	var glyph := Control.new()
	glyph.set_anchors_preset(Control.PRESET_FULL_RECT)
	glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glyph.draw.connect(func():
		var key := String(b.get_meta("key", ""))
		if key != "" and key != "—":
			var kw := maxf(28.0, RoyaleHudStyle.num_font().get_string_size(key, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x + 14.0)
			RoyaleHudStyle.draw_key(glyph, Vector2(glyph.size.x - 14.0 - kw * 0.5, glyph.size.y * 0.5 - 1.0), key, 15))
	b.add_child(glyph)
	b.set_meta("glyph", glyph)
	parent.add_child(b)
	return b


# --- ouverture ----------------------------------------------------------------------------------
func open(ride := false) -> void:
	if is_open:
		return
	is_open = true
	for_ride = ride
	visible = true
	zoom_i = 0
	view_center = Vector2.INF
	cursor_shown = false
	_layout()
	cursor = _view.size * 0.5
	var rig = director.world.rig if director != null and director.world != null else null
	if rig != null:
		_rig_input = bool(rig.allow_input)
	refresh()


func close() -> void:
	if not is_open:
		return
	is_open = false
	for_ride = false
	visible = false
	var rig = director.world.rig if director != null and director.world != null else null
	if rig != null:
		rig.allow_input = _rig_input


func toggle() -> void:
	if is_open:
		close()
	else:
		open(false)


## Le joueur est à bord de l'aigle (vol en cours).
func riding() -> bool:
	var rd := _rd()
	return rd != null and rd.jump != null and rd.jump.on_board(player)


## « Sauter » : comme la touche de saut (portes ouvertes après Royale.COUNTDOWN).
func press_jump() -> void:
	var rd := _rd()
	if rd == null or rd.jump == null or not rd.jump.on_board(player) or rd.jump.t < Royale.COUNTDOWN:
		return
	rd.jump.jump(player)
	Sfx.ui("confirm", -6.0)
	close()


# --- mise en page ------------------------------------------------------------------------------
## Carte carrée à gauche, panneau à droite, le tout centré ; tient dans 1280×720 comme dans 1600×900.
func _layout() -> void:
	var vp := get_viewport_rect().size
	_k = clampf(vp.y / 900.0, 0.72, 1.3)
	var gutter := GUTTER * _k
	var side_w := clampf(SIDE_W * _k, 320.0, 460.0)
	var s := minf(vp.y - 2.0 * gutter, vp.x - side_w - 3.0 * gutter)
	var x0 := (vp.x - (s + gutter + side_w)) * 0.5
	var y0 := (vp.y - s) * 0.5
	_view.position = Vector2(x0, y0)
	_view.size = Vector2(s, s)
	var pad_h := int(20 * _k)
	_side.position = Vector2(x0 + s + gutter, y0)
	_side.custom_minimum_size = Vector2(side_w, 0)  # (hauteur : celle du contenu, collé en haut de la carte)
	_side.add_theme_stylebox_override("panel", UiTheme.panel_style(7, Vector2(pad_h, int(18 * _k))))
	for l in [_ring_line, _info_a, _info_b, _hint]:
		(l as Label).custom_minimum_size.x = side_w - 2.0 * pad_h - 30.0  # (texte renvoyé à la ligne : largeur connue d'avance)
	_side_size = Vector2(side_w, 0)
	_side.reset_size()


func map_rect() -> Rect2:
	return Rect2(_view.position, _view.size)


func side_rect() -> Rect2:
	return Rect2(_side.position, _side.size)


# --- repères monde <-> carte --------------------------------------------------------------------------
func _map_size() -> float:
	return float(director.map.size) if director != null and director.map != null and "size" in director.map else 512.0


## Mètres de monde par pixel de la vue (selon le zoom).
func _scale() -> float:
	return _view.size.x / (_map_size() / float(ZOOMS[zoom_i]))


func _center() -> Vector2:
	var ms := _map_size()
	if zoom_i == 0 or view_center == Vector2.INF:
		return Vector2(ms, ms) * 0.5
	var half := ms / float(ZOOMS[zoom_i]) * 0.5
	return Vector2(clampf(view_center.x, half, ms - half), clampf(view_center.y, half, ms - half))


## Point du monde -> point de la vue (px).
func world_to_view(p: Vector3) -> Vector2:
	return (Vector2(p.x, p.z) - _center()) * _scale() + _view.size * 0.5


## Point de la vue (px) -> point au sol.
func view_to_world(v: Vector2) -> Vector3:
	var q := (v - _view.size * 0.5) / _scale() + _center()
	return RoyalePing.ground(director.map if director != null else null, q.x, q.y)


## Zoom suivant (ou [param step] crans), centré sur le point de la vue [param at].
func zoom_at(at: Vector2, step := 1) -> void:
	var before := view_to_world(at)
	var ni := clampi(zoom_i + step, 0, ZOOMS.size() - 1)
	if step > 0 and zoom_i == ZOOMS.size() - 1:
		ni = 0  # (R3 : le dernier cran revient à la carte entière)
	if ni == zoom_i:
		return
	zoom_i = ni
	view_center = Vector2.INF
	if zoom_i > 0:
		# le point visé reste sous le curseur (au bord de la carte, la vue s'arrête au bord)
		view_center = Vector2(before.x, before.z) - (at - _view.size * 0.5) / _scale()
	refresh()


## Pose (ou enlève) le repère au point de la vue [param at].
func ping_at(at: Vector2) -> void:
	if not Rect2(Vector2.ZERO, _view.size).has_point(at):
		return
	RoyalePing.toggle(view_to_world(at), _rd())
	refresh()


# --- entrées ---------------------------------------------------------------------------------------
func _view_input(ev: InputEvent) -> void:
	if not is_open:
		return
	if ev is InputEventMouseButton and ev.pressed:
		match ev.button_index:
			MOUSE_BUTTON_LEFT:
				ping_at(ev.position)
				_view.accept_event()
			MOUSE_BUTTON_WHEEL_UP:
				zoom_at(ev.position, 1 if zoom_i < ZOOMS.size() - 1 else 0)
				_view.accept_event()
			MOUSE_BUTTON_WHEEL_DOWN:
				zoom_at(ev.position, -1)
				_view.accept_event()
	elif ev is InputEventMouseMotion:
		cursor_shown = false


## Manette, carte ouverte (le jeu n'est pas en pause : UiNav ne s'en occupe pas).
func _input(ev: InputEvent) -> void:
	if not is_open or get_tree().paused:
		return
	if not (ev is InputEventJoypadButton and ev.pressed):
		return
	var ride := riding()
	var handled := true
	match ev.button_index:
		JOY_BUTTON_A:
			if ride:
				press_jump()
			else:
				handled = false
		JOY_BUTTON_X:
			if ride:
				ping_at(cursor)
				cursor_shown = true
			else:
				handled = false
		JOY_BUTTON_B:
			if ride:
				close()
			else:
				handled = false
		JOY_BUTTON_RIGHT_STICK:
			zoom_at(cursor if cursor_shown else _view.size * 0.5, 1)
		JOY_BUTTON_LEFT_SHOULDER:
			if ride and _rd() != null and _rd().jump != null:
				_rd().jump.thank()  # (lot BR-R1 : remercier l'aigle)
			else:
				handled = false
		_:
			handled = false
	if handled:
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if not is_open:
		return
	if get_viewport_rect().size != _last_vp:
		_last_vp = get_viewport_rect().size
		_layout()
	# curseur de la manette : stick gauche à bord (le héros ne bouge pas), stick droit au sol (la caméra attend)
	var ride := riding()
	var rig = director.world.rig if director.world != null else null
	if rig != null:
		rig.allow_input = _rig_input and (ride or not Gamepad.active)  # (au sol, le stick droit mène le curseur)
	if Gamepad.active and not get_tree().paused:
		var st := Gamepad.stick(JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y) if ride else Gamepad.stick(JOY_AXIS_RIGHT_X, JOY_AXIS_RIGHT_Y)
		if st != Vector2.ZERO:
			cursor_shown = true
			cursor = (cursor + st * CURSOR_SPEED * _k * delta).clamp(Vector2.ZERO, _view.size)
	refresh()


var _last_vp := Vector2.ZERO


# --- contenu -------------------------------------------------------------------------------------------
func refresh() -> void:
	if not is_open:
		return
	var rd := _rd()
	if rd == null:
		return
	var ride := riding()
	var pad := Gamepad.active
	var j := rd.jump
	_title.text = "Où atterrir ?" if ride else "Carte"
	_timer_box.visible = ride
	_jump_btn.visible = ride
	_info_well.visible = true
	if ride:
		var doors := j.t < Royale.COUNTDOWN
		_timer_label.text = ("Portes ouvertes dans %d s" % ceili(Royale.COUNTDOWN - j.t)) if doors else ("Saut automatique dans %d s" % maxi(0, ceili(j.duration - j.t)))
		_jump_btn.disabled = doors
		_jump_btn.set_meta("key", "A" if pad else Settings.action_label("jump", 1))
		_ring_line.text = ""
		_ring_line.visible = false
		var mine := RoyalePing.has()
		var place := RoyalePing.place if mine else ""
		_info_a.text = ("Ton repère : %s" % place) if place != "" and place != "Repère" else ("Repère posé" if mine else "Pas encore de repère")
		if mine:
			_info_b.text = "Atteignable en chute" if reachable(RoyalePing.pos) else "Loin du vol : saute tôt"
			_info_b.add_theme_color_override("font_color", RoyaleHudStyle.APPLE[0] if reachable(RoyalePing.pos) else RoyaleHudStyle.STRAWBERRY[0])
		else:
			_info_b.text = ("Pose-le avec X" if pad else "Pose-le d'un clic sur la carte")
			_info_b.add_theme_color_override("font_color", RoyaleHudStyle.INK_100)
		var aboard := 0
		for c in j.riders:
			if is_instance_valid(c) and j.on_board(c):
				aboard += 1
		_footer.text = "À bord : %d · Sautés : %d" % [aboard, Royale.PLAYERS - aboard]
		if Royale.mod != "":
			_footer.text = "%s · %s" % [RoyaleMods.name_of(Royale.mod), _footer.text]  # (lot BR-R1 : le modificateur de la partie)
		var most := 0
		var hot := ""
		for pl in RoyalePing.places(rd):
			if int(pl.get("aimed", 0)) > most:
				most = int(pl.get("aimed", 0))
				hot = String(pl.get("name", ""))
		if most > 0:
			_footer.text += "
%d héros %s : %s" % [most, "visent" if most > 1 else "vise", hot]  # (lieux nommés du lot BR-I2 : où vont les autres)
		_hint.text = ("Stick : curseur · X : repère · R3 : zoom" if pad else "Clic : repère · Molette : zoom")
		if rd.jump != null and not rd.jump.thanked:
			_hint.text += " · %s : merci l'aigle" % ("LB" if pad else Settings.action_label("interact", 1))  # (lot BR-R1)
	else:
		_ring_line.visible = true
		_ring_line.text = ring_text(rd)
		_info_a.text = ("Ton repère · %d m" % roundi(RoyalePing.distance(player.global_position)) if RoyalePing.place == "Repère"
			else "Ton repère : " + RoyalePing.text(player.global_position)) if RoyalePing.has() else "Pas de repère"
		_info_b.text = "Zone sûre · %d m" % roundi(safe_distance(rd)) if safe_distance(rd) > 0.0 else "Tu es dans la zone sûre"
		_info_b.add_theme_color_override("font_color", RoyaleHudStyle.AMETHYST[0] if safe_distance(rd) > 0.0 else RoyaleHudStyle.APPLE[0])
		_footer.text = ""
		_hint.text = ("Stick droit : curseur · L3 : repère · R3 : zoom" if pad else "Clic : repère · Molette : zoom")
	_close_btn.set_meta("key", "B" if pad and ride else Settings.action_label("map", 1))
	_footer.visible = _footer.text != ""
	_legend.custom_minimum_size = Vector2(0, 0 if ride else _legend_rows().size() * maxf(24.0, 26.0 * _k) + 4.0)
	_legend.visible = not ride
	_gauge.queue_redraw()
	_legend.queue_redraw()
	for b in [_jump_btn, _close_btn]:
		(b.get_meta("glyph") as Control).queue_redraw()
	_view.queue_redraw()
	_side.reset_size()  # (un conteneur grandit seul mais ne rétrécit pas : on le recale sur son contenu)


## « Anneau 3 / 5 · se referme dans 0:42 » (sans pourcentage).
static func ring_text(rd: RoyaleDirector) -> String:
	if rd.phase == "drop":
		return "L'anneau part quand tous sont au sol"
	var ring := rd.ring
	var n := mini(int(ring.get("phase", 0)) + 1, Royale.PHASES.size() - 1)
	var left := ceili(float(ring.get("left", 0.0)))
	var tm := "%d:%02d" % [left / 60, left % 60]
	match String(ring.get("state", "hold")):
		"hold":
			return "Anneau %d / %d · se referme dans %s" % [n, Royale.PHASES.size() - 1, tm]
		"shrink":
			return "Anneau %d / %d · il se resserre (%s)" % [n, Royale.PHASES.size() - 1, tm]
	return "Dernier cercle"


## Distance (m) du joueur à la zone sûre (0 : dedans).
func safe_distance(rd: RoyaleDirector) -> float:
	if rd.ring.is_empty() or rd.phase != "fight":
		return 0.0
	var ring := rd.ring
	var soon := String(ring.state) == "shrink" or (String(ring.state) == "hold" and float(ring.left) < 12.0)
	var c: Vector2 = ring.next_center if soon else ring.center
	var r := float(ring.next_radius) if soon else float(ring.radius)
	return maxf(0.0, Vector2(player.global_position.x, player.global_position.z).distance_to(c) - r)


## Portée de chute depuis la ligne du vol (comme RoyaleDrop.plan, sans sa marge) : [param p] est-il atteignable ?
func reachable(p: Vector3) -> bool:
	var rd := _rd()
	if rd == null or rd.jump == null:
		return false
	return _line_distance(rd.jump, p) <= reach_m()


static func reach_m() -> float:
	return RoyaleDrop.AIR_MOVE * (RoyaleDrop.ALT - RoyaleDrop.GLIDE_AT) / RoyaleDrop.FALL + RoyaleDrop.GLIDE_MOVE * RoyaleDrop.GLIDE_AT / RoyaleDrop.GLIDE_FALL


## Distance (m) de [param p] à ce qui reste du vol (de l'aigle jusqu'à l'arrivée).
static func _line_distance(j: RoyaleDrop, p: Vector3) -> float:
	var a := Vector2(j.eagle_pos().x, j.eagle_pos().z)
	var b := Vector2(j.b.x, j.b.z)
	var q := Vector2(p.x, p.z)
	var ab := b - a
	var t := clampf((q - a).dot(ab) / maxf(ab.length_squared(), 0.001), 0.0, 1.0)
	return q.distance_to(a + ab * t)


# --- dessin ---------------------------------------------------------------------------------------------
func _draw_gauge() -> void:
	var rd := _rd()
	if rd == null or rd.jump == null:
		return
	var j := rd.jump
	var ratio := clampf((j.duration - j.t) / maxf(j.duration, 0.1), 0.0, 1.0)
	RoyaleHudStyle.draw_gauge(_gauge, Rect2(Vector2.ZERO, _gauge.size - Vector2(3, 3)), ratio, RoyaleHudStyle.SUN)


func _legend_rows() -> Array:
	var rows := [["me", "Toi"], ["ring", "Anneau actuel"], ["next", "Prochain anneau"], ["ping", "Ton repère"], ["drop", "Largage"],
		["bounty", "Héros mis à prix"], ["chests", "Coffres : commun, rare, doré"]]
	if not RoyalePing.places(_rd()).is_empty():
		rows.insert(1, ["place", "Lieu (★ : richesse du butin)"])
	var rd := _rd()
	if rd != null and rd.get("event") != null and not rd.event.marker().is_empty():
		rows.insert(rows.size() - 1, ["altar", "Autel du gardien"])  # (lot BR-R1)
	return rows


## Losange mandarine contouré d'encre (autel du gardien, son trésor).
func _altar_mark(ci: CanvasItem, c: Vector2, r: float) -> void:
	var pts := PackedVector2Array([c + Vector2(0, -r), c + Vector2(r, 0), c + Vector2(0, r), c + Vector2(-r, 0)])
	RoyaleHudStyle.draw_inked_polygon(ci, pts, RoyaleHudStyle.MANDARIN[1], 3.0)


func _draw_legend() -> void:
	var row := maxf(24.0, 26.0 * _k)
	var f := RoyaleHudStyle.text_font()
	var i := 0
	for e in _legend_rows():
		var y := row * i + row * 0.5
		var c := Vector2(14.0, y)
		match String(e[0]):
			"me":
				_me_arrow(_legend, c, Vector2.UP, 9.0)
			"place":
				_legend.draw_circle(c, 9.0, RoyaleHudStyle.INK)
				_legend.draw_circle(c, 6.5, RoyaleHudStyle.PAPER)
				_legend.draw_circle(c, 3.5, RoyaleHudStyle.SUN[1])
			"ring":
				_legend.draw_arc(c, 8.0, 0.0, TAU, 24, RoyaleHudStyle.INK, 5.0, true)
				_legend.draw_arc(c, 8.0, 0.0, TAU, 24, RoyaleHudStyle.AMETHYST[1], 2.5, true)
			"next":
				_dashed_circle(_legend, c, 8.0, RoyaleHudStyle.WHITE, 12)
			"ping":
				_pin(_legend, c + Vector2(0, 8.0), 7.0)
			"drop":
				_star(_legend, c, 9.0, RoyaleHudStyle.SUN[1])
			"bounty":
				_star(_legend, c, 9.0, RoyaleHudStyle.STRAWBERRY[1])
			"altar":
				_altar_mark(_legend, c, 9.0)
			"chests":
				var cols := _chest_colors()
				for k in 3:
					_square(_legend, c + Vector2(k * 13.0 - 6.0, 0), 4.5, cols[k])
		_legend.draw_string(f, Vector2(c.x + 30.0, y + 5.0), String(e[1]), HORIZONTAL_ALIGNMENT_LEFT, -1, UiTheme.MIN_TEXT + 1, RoyaleHudStyle.INK)
		i += 1


## Couleurs des coffres (commun, rare, doré) : celles de la carte (ProcMap.ROYALE_ICONS si elle les a, sinon la mini-carte).
static func _chest_colors() -> Array:
	var icons: Dictionary = (ProcMap as Script).get_script_constant_map().get("ROYALE_ICONS", {})
	var out: Array = []
	for k in ["chest", "chest1", "chest2"]:
		out.append(icons.get(k, Minimap.ICONS.get(k, Color.WHITE)))
	return out


static func _marker_color(kind: String) -> Color:
	var icons: Dictionary = (ProcMap as Script).get_script_constant_map().get("ROYALE_ICONS", {})
	return icons.get(kind, Minimap.ICONS.get(kind, Color.WHITE))


func _draw_view() -> void:
	var rd := _rd()
	if rd == null or director.map == null:
		return
	var v := _view
	var sz := v.size
	v.draw_rect(Rect2(Vector2.ZERO, sz), RoyaleHudStyle.WELL)
	var info: Dictionary = director.map.minimap_info()
	var tex: Texture2D = info.get("texture")
	var ms := _map_size()
	var sc := _scale()
	var o := world_to_view(Vector3.ZERO)
	if tex:
		v.draw_texture_rect(tex, Rect2(o, Vector2(ms, ms) * sc), false)
	# anneau : dehors teinté améthyste, l'anneau en trait épais, le prochain en pointillés blancs
	if not rd.ring.is_empty():
		var rc := world_to_view(Vector3(rd.ring.center.x, 0, rd.ring.center.y))
		var rr := float(rd.ring.radius) * sc
		var far := sz.length() * 2.0 + rc.distance_to(sz * 0.5)
		v.draw_arc(rc, (rr + far) * 0.5, 0.0, TAU, 96, Color(RoyaleHudStyle.AMETHYST[1], 0.26), far - rr)
		v.draw_arc(rc, rr, 0.0, TAU, 128, RoyaleHudStyle.INK, 7.0, true)
		v.draw_arc(rc, rr, 0.0, TAU, 128, RoyaleHudStyle.AMETHYST[1], 3.5, true)
		if float(rd.ring.next_radius) < float(rd.ring.radius) - 1.0:
			var nc := world_to_view(Vector3(rd.ring.next_center.x, 0, rd.ring.next_center.y))
			_dashed_circle(v, nc, float(rd.ring.next_radius) * sc, RoyaleHudStyle.WHITE, 48)
	# trajet de l'aigle, bande « atteignable en chute »
	var j := rd.jump
	if j != null and j.flying() and rd.phase == "drop":
		var a := world_to_view(j.a)
		var b := world_to_view(j.b)
		if riding():
			v.draw_line(world_to_view(j.eagle_pos()), b, Color(1, 1, 1, 0.13), reach_m() * sc * 2.0)
		_dashed_line(v, a, b, RoyaleHudStyle.WHITE, 4.0)
		var e := world_to_view(j.eagle_pos())
		var d := (b - a).normalized()
		_me_arrow(v, e, d, 13.0, RoyaleHudStyle.SUN)
	# repères du directeur : coffres, fontaines, largage, mis à prix
	var k := clampf(sc * 2.0, 0.8, 1.6)
	for m in rd.markers():
		var sp := world_to_view(m[0])
		if sz.x <= 8.0 or sz.y <= 8.0 or not Rect2(Vector2.ZERO, sz).grow(-4.0).has_point(sp):
			continue  # (taille nulle tant que la carte n'est pas posée : plus d'erreur de Rect2 négatif, lot BR-R1)
		var kind := String(m[1])
		if kind.begins_with("chest"):
			_square(v, sp, (3.5 if kind == "chest" else 5.0) * k, _marker_color(kind))
		elif kind == "drop":
			_star(v, sp, 11.0, RoyaleHudStyle.SUN[1])
		elif kind == "bounty":
			_star(v, sp, 11.0, RoyaleHudStyle.STRAWBERRY[1])
		elif kind == "altar":
			_altar_mark(v, sp, 11.0)  # (lot BR-R1 : autel du gardien)
		elif kind == "hero":
			v.draw_circle(sp, 5.5, RoyaleHudStyle.INK)
			v.draw_circle(sp, 3.5, RoyaleHudStyle.STRAWBERRY[1])
		else:
			v.draw_circle(sp, 6.0, RoyaleHudStyle.INK)
			v.draw_circle(sp, 4.0, _marker_color(kind))
	# lieux nommés (lot BR-I2 : RoyaleDirector.places), par-dessus les coffres : rond papier (bonbon selon la richesse),
	# nom centré contouré d'encre, étoiles de butin
	var f := RoyaleHudStyle.text_font()
	for pl in RoyalePing.places(rd):
		var pp := world_to_view(pl.get("pos", Vector3.ZERO))
		var stars := clampi(int(pl.get("stars", 0)), 0, 3)
		v.draw_circle(pp, 9.0, RoyaleHudStyle.INK)
		v.draw_circle(pp, 6.5, RoyaleHudStyle.PAPER)
		v.draw_circle(pp, 3.5, [RoyaleHudStyle.INK_300, RoyaleHudStyle.LAGOON[1], RoyaleHudStyle.AMETHYST[1], RoyaleHudStyle.SUN[1]][stars])
		var label := String(pl.get("name", ""))
		var w := f.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
		RoyaleHudStyle.draw_text(v, pp + Vector2(-w * 0.5, 27), label, 15, RoyaleHudStyle.WHITE, f)
		if stars > 0:
			var st := "★".repeat(stars)
			var sw := f.get_string_size(st, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
			RoyaleHudStyle.draw_text(v, pp + Vector2(-sw * 0.5, 44), st, 14, RoyaleHudStyle.SUN[0], f)
	# repère, toi, curseur
	if RoyalePing.has():
		_pin(v, world_to_view(RoyalePing.pos), 11.0)
	if not riding() and not player.is_dead:
		var me := world_to_view(player.global_position)
		var dist := safe_distance(rd)
		if dist > 0.0:
			# dehors : le trajet vers la zone sûre, comme sur la mini-carte
			var ring := rd.ring
			var soon := String(ring.state) == "shrink" or (String(ring.state) == "hold" and float(ring.left) < 12.0)
			var c: Vector2 = ring.next_center if soon else ring.center
			var r := float(ring.next_radius) if soon else float(ring.radius)
			var q := Vector2(player.global_position.x, player.global_position.z)
			var goal := c + (q - c).normalized() * (r - 2.0)
			_dashed_line(v, me, world_to_view(Vector3(goal.x, 0, goal.y)), RoyaleHudStyle.AMETHYST[0], 3.0)
		var fwd := player.forward()
		_me_arrow(v, me.clamp(Vector2(14, 14), sz - Vector2(14, 14)), Vector2(fwd.x, fwd.z).normalized(), 11.0)
	if cursor_shown:
		v.draw_arc(cursor, 14.0, 0.0, TAU, 24, RoyaleHudStyle.INK, 6.0, true)
		v.draw_arc(cursor, 14.0, 0.0, TAU, 24, RoyaleHudStyle.LAGOON[0], 3.0, true)
		for dd in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
			v.draw_line(cursor + dd * 6.0, cursor + dd * 22.0, RoyaleHudStyle.INK, 4.0)
			v.draw_line(cursor + dd * 7.0, cursor + dd * 21.0, RoyaleHudStyle.LAGOON[0], 2.0)
	# cadre de la carte
	RoyaleHudStyle.draw_text(v, Vector2(14, sz.y - 14), "×%s" % str(ZOOMS[zoom_i]).trim_suffix(".0") if zoom_i > 0 else "", 15)
	var frame := StyleBoxFlat.new()
	frame.draw_center = false
	frame.border_color = RoyaleHudStyle.INK
	frame.set_border_width_all(4)
	frame.set_corner_radius_all(18)
	v.draw_style_box(frame, Rect2(Vector2.ZERO, sz))


# --- formes ---------------------------------------------------------------------------------------------
static func _square(ci: CanvasItem, c: Vector2, r: float, col: Color) -> void:
	ci.draw_rect(Rect2(c - Vector2(r, r) - Vector2(2, 2), Vector2(r, r) * 2.0 + Vector2(4, 4)), RoyaleHudStyle.INK)
	ci.draw_rect(Rect2(c - Vector2(r, r), Vector2(r, r) * 2.0), col)


static func _star(ci: CanvasItem, c: Vector2, r: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 10:
		var a := -PI / 2.0 + i * PI / 5.0
		pts.append(c + Vector2(cos(a), sin(a)) * (r if i % 2 == 0 else r * 0.45))
	RoyaleHudStyle.draw_inked_polygon(ci, pts, col, 2.0)


## Flèche du héros (lagon) ou de l'aigle (soleil), pointe vers [param d].
static func _me_arrow(ci: CanvasItem, c: Vector2, d: Vector2, r: float, tones: Array = RoyaleHudStyle.LAGOON) -> void:
	if d.length() < 0.01:
		d = Vector2.UP
	d = d.normalized()
	var side := d.orthogonal()
	var pts := PackedVector2Array([c + d * r * 1.3, c - d * r * 0.8 + side * r * 0.9, c - d * r * 0.3, c - d * r * 0.8 - side * r * 0.9])
	RoyaleHudStyle.draw_inked_polygon(ci, pts, tones[1], 2.5)


## Épingle du repère (pointe sur [param at]).
static func _pin(ci: CanvasItem, at: Vector2, r: float) -> void:
	var head := at - Vector2(0, r * 2.0)
	var pts := PackedVector2Array()
	for i in 17:
		var ang := PI * 0.75 + i * (PI * 1.5) / 16.0
		pts.append(head + Vector2(cos(ang), sin(ang)) * r)
	pts.append(at)
	RoyaleHudStyle.draw_inked_polygon(ci, pts, RoyaleHudStyle.LAGOON[1], 2.5)
	ci.draw_circle(head, r * 0.4, RoyaleHudStyle.WHITE)


static func _dashed_line(ci: CanvasItem, a: Vector2, b: Vector2, col: Color, w: float) -> void:
	ci.draw_dashed_line(a, b, RoyaleHudStyle.INK, w + 3.0, 14.0)
	ci.draw_dashed_line(a, b, col, w, 14.0)


static func _dashed_circle(ci: CanvasItem, c: Vector2, r: float, col: Color, n: int) -> void:
	for i in n:
		var a0 := TAU * i / n
		var a1 := a0 + TAU / n * 0.55
		ci.draw_arc(c, r, a0, a1, 6, RoyaleHudStyle.INK, 5.0, true)
		ci.draw_arc(c, r, a0, a1, 6, col, 2.5, true)


# --- mini-carte (crochet de Minimap._draw) ----------------------------------------------------------------
## Sur la mini-carte : la ligne vers la zone sûre quand on est dehors (ou qu'on va l'être), et le repère personnel.
static func minimap_overlay(mm: Minimap, w2s: Callable) -> void:
	var d := mm.director
	if d == null or d.royale == null or mm.player == null:
		return
	var rd: RoyaleDirector = d.royale
	var p := mm.player.global_position
	if rd.phase == "fight" and not rd.ring.is_empty() and not mm.player.is_dead:
		var ring := rd.ring
		var soon := String(ring.state) == "shrink" or (String(ring.state) == "hold" and float(ring.left) < 12.0)
		var c: Vector2 = ring.next_center if soon else ring.center
		var r := float(ring.next_radius) if soon else float(ring.radius)
		var q := Vector2(p.x, p.z)
		if q.distance_to(c) > r:
			var goal := c + (q - c).normalized() * (r - 2.0)  # point le plus proche de la zone sûre
			var a: Vector2 = w2s.call(p)
			var b: Vector2 = w2s.call(Vector3(goal.x, 0, goal.y))
			mm.draw_line(a, b, RoyaleHudStyle.INK, 5.0, true)
			mm.draw_dashed_line(a, b, RoyaleHudStyle.AMETHYST[0], 3.0, 7.0)
	_minimap_places(mm, w2s, rd)
	if RoyalePing.has():
		var sp: Vector2 = w2s.call(RoyalePing.pos)
		if not mm._inside(sp):
			sp = mm._clamp_edge(sp, mm.size * 0.5)
		_pin(mm, sp + Vector2(0, 6.0), 6.5 if not mm.big else 9.0)


## Lieux nommés sur la mini-carte (lot BR-I3) : un rond à la couleur de leur richesse, et le nom des 3 plus proches du
## héros quand il tient dans le disque (petits caractères contourés d'encre ; le lieu où il se trouve en lagon).
const MINI_NAMES := 3


static func _minimap_places(mm: Minimap, w2s: Callable, rd: RoyaleDirector) -> void:
	var places: Array = RoyalePing.places(rd)
	if places.is_empty():
		return
	var me := mm.player.global_position
	var here := rd.place_at(me)
	var c := mm.size * 0.5
	var lim := minf(mm.size.x, mm.size.y) * 0.5
	var named: Array = places.duplicate()
	named.sort_custom(func(a, b): return me.distance_to(a.get("pos", Vector3.ZERO)) < me.distance_to(b.get("pos", Vector3.ZERO)))
	named = named.slice(0, MINI_NAMES)
	var f := RoyaleHudStyle.text_font()
	var fs := UiTheme.MIN_TEXT
	for pl in places:
		var sp: Vector2 = w2s.call(pl.get("pos", Vector3.ZERO))
		if sp.distance_to(c) > lim - 8.0:
			continue
		var stars := clampi(int(pl.get("stars", 0)), 0, 3)
		mm.draw_circle(sp, 6.0, RoyaleHudStyle.INK)
		mm.draw_circle(sp, 4.0, [RoyaleHudStyle.PAPER, RoyaleHudStyle.LAGOON[1], RoyaleHudStyle.AMETHYST[1], RoyaleHudStyle.SUN[1]][stars])
		if not pl in named:
			continue
		var label := String(pl.get("name", ""))
		var w := f.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var at := sp + Vector2(-w * 0.5, -10.0)
		if at.distance_to(c) > lim - 14.0 or (at + Vector2(w, 0)).distance_to(c) > lim - 14.0:
			continue  # (le nom sortirait du disque)
		var col := RoyaleHudStyle.LAGOON[0] if not here.is_empty() and String(here.get("name", "")) == label else RoyaleHudStyle.WHITE
		RoyaleHudStyle.draw_text(mm, at, label, fs, col, f)
