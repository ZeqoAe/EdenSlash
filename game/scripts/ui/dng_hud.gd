class_name DngHud
extends Control
## HUD des modes de boss, lot DNG-3 (backlog BM-DNG P1), posé par BossBar.attach à côté de la barre de boss :
##   - la pastille « Relève 1 » collée aux PV (Relief : Donjons et Ruée en Normal / Héroïque, Tour sauf Hardcore) ;
##   - Ruée : le fil des temps par boss (vaincus avec leur temps et le record, celui en cours qui tourne, les suivants), le
##     temps total et le record du tirage (RushDirector.trail) ;
##   - Siège : le tableau des trois (dégâts au boss et aux lieutenants, chutes, dernier coup : SiegeScore) et les trois objectifs
##     en direct (★ tenu, ☆ encore possible, ✗ manqué) ;
##   - S'entraîner : le panneau de la salle d'entraînement (BossPractice, F3 pour le replier).
## Tout est dans la pile de gauche du HUD (sous les objectifs) : jamais sur la barre de boss, la frise, la mini-carte ni les sorts.
## Lecture seule : rien ici ne change le combat.

const REFRESH := 0.2
const W := 300.0

var hud: Hud
var relief: Label  # (tests)
var trail: PanelContainer  # (tests) fil des temps de la Ruée
var board: PanelContainer  # (tests) tableau du Siège
var practice: PanelContainer  # (tests) panneau d'entraînement
var practice_body: VBoxContainer
var _trail_box: VBoxContainer
var _board_box: VBoxContainer
var _t := 0.0
var _sig := ""


static func attach(root: Control, h: Hud) -> DngHud:
	var n := DngHud.new()
	n.hud = h
	n.name = "DngHud"
	root.add_child(n)
	return n


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


func _process(delta: float) -> void:
	_t -= delta
	if _t > 0.0:
		return
	_t = REFRESH
	if hud == null or hud.director == null:
		return
	_update_relief()
	var td = hud.director.tower
	if td == null or not Tower.active:
		return
	if Tower.rush and td.has_method("trail"):
		_update_trail(td)
	if Tower.siege:
		_update_board(td)
	if BossPractice.active:
		_update_practice(td)


func _input(event: InputEvent) -> void:
	if BossPractice.active and practice != null and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F3:
		practice_body.visible = not practice_body.visible
		get_viewport().set_input_as_handled()


# --- relève ---------------------------------------------------------------------------------------
func _update_relief() -> void:
	var txt := Relief.pill_text()
	if txt == "" or hud._action_root == null:
		if relief != null:
			relief.visible = false
		return
	if relief == null:
		relief = BossBar.pill(txt, "pomme", 15, -6.0)
		relief.tooltip_text = "Relève : un coup fatal ne finit pas la partie, tu te relèves sur place. Une au départ, rendue à chaque boss."
		hud._action_root.add_child(relief)
	# collée aux PV : juste après le bout droit de la jauge de vie (HUD v2, lot HUD-2), sans rien recouvrir
	var g: Control = hud._hp_orb
	if g != null and g.get_parent() == relief.get_parent():
		relief.position = g.position + Vector2(g.size.x + 8.0, (g.size.y - relief.size.y) * 0.5)
	else:
		relief.position = Vector2(40, 22)
	relief.visible = true
	if relief.text != txt:
		relief.text = txt
		relief.add_theme_stylebox_override("normal", UiTheme.sticker("pomme" if Relief.left > 0 else "gris", {"radius": 10, "shadow": 3, "pad": Vector2(9, 1), "gloss": false}))


# --- petites briques --------------------------------------------------------------------------------
func _well(title: String) -> Array:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UiTheme.well_style(Vector2(10, 7), 14))
	p.custom_minimum_size = Vector2(W, 0)
	p.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(v)
	var head := _text(v, title, 15, UiTheme.color("papier.100"), true)
	head.name = "Head"
	hud._left.add_child(p)
	return [p, v, head]


static func _text(parent: Control, t: String, size: int, col: Color, bold := false) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_override("font", UiTheme.bold_font() if bold else UiTheme.body_font())
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_constant_override("outline_size", 3)
	l.add_theme_color_override("font_outline_color", UiTheme.color("encre.900"))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l


## Ligne à deux colonnes (texte à gauche, valeur à droite).
static func _pair(parent: Control, left: String, right: String, col: Color, size := 14) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(h)
	var a := _text(h, left, size, col)
	a.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	a.clip_text = true
	a.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	var b := _text(h, right, size, col, true)
	b.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	return h


static func _clear(box: Container, keep := 1) -> void:
	for i in range(box.get_child_count() - 1, keep - 1, -1):
		var c := box.get_child(i)
		box.remove_child(c)
		c.queue_free()


# --- Ruée : fil des temps ---------------------------------------------------------------------------
func _update_trail(td) -> void:
	if trail == null:
		var w := _well("")
		trail = w[0]
		_trail_box = w[1]
	var tb: Array = td.total_and_best()
	(_trail_box.get_node("Head") as Label).text = "Ruée · %s%s" % [BestTimes.fmt(float(tb[0])), ("  (record %s)" % BestTimes.fmt(float(tb[1]))) if float(tb[1]) > 0.0 else ""]
	_clear(_trail_box)
	var paper := UiTheme.color("papier.100")
	var muted := UiTheme.color("encre.100")
	var sun := UiTheme.color("bonbon.soleil.base")
	var tang := UiTheme.color("bonbon.mandarine.clair")
	for r in td.trail():
		var state := String(r.state)
		var right := ""
		var col := muted
		if state == "done":
			col = paper
			right = BestTimes.fmt(float(r.t))
			if bool(r.new) and float(r.best) > 0.0:
				right += "  ★"
				col = sun
			elif float(r.best) > 0.0:
				right += "  (%s)" % BestTimes.fmt(float(r.best))
		elif state == "now":
			col = tang
			right = BestTimes.fmt(float(r.t)) + (("  /  %s" % BestTimes.fmt(float(r.best))) if float(r.best) > 0.0 else "")
		else:
			right = ("record %s" % BestTimes.fmt(float(r.best))) if float(r.best) > 0.0 else ""
		_pair(_trail_box, "%d  %s" % [int(r.n), String(r.name)], right, col, 14 if state != "now" else 15)


# --- Siège : tableau des trois, objectifs --------------------------------------------------------------
func _update_board(td) -> void:
	if board == null:
		var w := _well("Tableau des trois")
		board = w[0]
		_board_box = w[1]
	_clear(_board_box)
	var paper := UiTheme.color("papier.100")
	var lagon := UiTheme.color("bonbon.lagon.clair")
	var rows := SiegeScore.rows()
	for i in rows.size():
		var r: Dictionary = rows[i]
		var tail := ""
		if int(r.falls) > 0:
			tail += "  ✝%d" % int(r.falls)
		if bool(r.last):
			tail += "  ⚔"
		_pair(_board_box, ("♛ " if i == 0 and float(r.dmg) > 0.0 else "") + String(r.name), SiegeScore.fmt(float(r.dmg)) + tail,
			lagon if bool(r.me) else paper)
	# objectifs en direct (Siege.STARS) : ★ tenu, ☆ encore possible, ✗ manqué ; un par ligne (la pile garde sa largeur)
	var sep := ColorRect.new()
	sep.color = Color(UiTheme.color("encre.100"), 0.35)
	sep.custom_minimum_size = Vector2(0, 2)
	sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_board_box.add_child(sep)
	var boss_down: bool = Tower.reached > Siege.WAVES
	for st in Siege.STARS:
		var id := String(st.id)
		var state := siege_star_state(id, boss_down, td)
		var glyph := String({"done": "★", "open": "☆", "lost": "✗"}[state])
		var col: Color = UiTheme.color("bonbon.soleil.base") if state == "done" else (UiTheme.color("encre.100") if state == "lost" else paper)
		var extra := ""
		if id == "fast" and state == "open" and td != null and td.has_method("fury_left") and td.fury_left() > 0.0:
			extra = BestTimes.fmt(td.fury_left())
		_pair(_board_box, "%s %s" % [glyph, String(st.name)], extra, col, 13)


## État d'un objectif du Siège en cours : « done », « open », « lost ».
static func siege_star_state(id: String, boss_down: bool, td) -> String:
	match id:
		"boss":
			return "done" if boss_down else "open"
		"allies":
			if Siege.ally_fell:
				return "lost"
			return "done" if boss_down else "open"
		"fast":
			if boss_down:
				return "done" if "fast" in Siege.stars_done else "lost"
			if td != null and td.has_method("is_enraged") and td.is_enraged():
				return "lost"
			return "open"
	return "open"


# --- S'entraîner ------------------------------------------------------------------------------------
func _update_practice(td) -> void:
	var m: Monster = td._boss if is_instance_valid(td._boss) else null
	var p := hud.player
	if p != null:
		p.immortal = BossPractice.god
	var sig := "%d|%s" % [m.get_instance_id() if m != null else 0, str(BossPractice.god)]
	if practice == null:
		var w := _well("S'entraîner · %s" % BossLibrary.short_name(BossPractice.boss))
		practice = w[0]
		practice.mouse_filter = Control.MOUSE_FILTER_PASS
		var v: VBoxContainer = w[1]
		v.mouse_filter = Control.MOUSE_FILTER_PASS
		_text(v, "Rien n'est gagné ni perdu ici · F3 : replier", 13, UiTheme.color("encre.100"))
		practice_body = VBoxContainer.new()
		practice_body.add_theme_constant_override("separation", 4)
		v.add_child(practice_body)
	if sig == _sig and practice_body.get_child_count() > 0:
		_refresh_seen(m)
		return
	_sig = sig
	_clear(practice_body, 0)
	var god := _button(practice_body, ("✔ " if BossPractice.god else "") + "Héros invincible", "lagon" if BossPractice.god else "papier")
	god.tooltip_text = "Tu prends les coups (chiffres, « Ce qui t'a battu »), mais tes PV ne baissent pas."
	god.pressed.connect(func():
		BossPractice.god = not BossPractice.god
		_t = 0.0)
	if m != null and m.brain != null:
		for i in m.brain.bricks.size():
			var type := String(m.brain.bricks[i].type)
			var b := _button(practice_body, "Rejouer : %s" % BossBar.mech_name(type), "papier")
			b.icon = BossBar.icon_of(type)
			b.expand_icon = true
			b.set_meta("type", type)
			b.tooltip_text = BossBricks.hint_of(type)
			var idx := i
			b.pressed.connect(func(): _replay(idx))
	var full := _button(practice_body, "Boss à pleine vie", "papier")
	full.pressed.connect(func(): BossPractice.refill(td._boss if is_instance_valid(td._boss) else null))
	var out := _button(practice_body, "Quitter l'entraînement", "fraise")
	out.pressed.connect(func(): BossPractice.leave(get_tree()))
	_refresh_seen(m)


func _replay(i: int) -> void:
	var td = hud.director.tower if hud != null and hud.director != null else null
	if td == null or not BossPractice.replay(td._boss, i):
		hud.show_message("Le boss est occupé : réessaie dans un instant", 1.5)


func _refresh_seen(_m: Monster) -> void:
	for b in practice_body.get_children():
		if b is Button and b.has_meta("type"):
			var type := String(b.get_meta("type"))
			var n := BossPractice.seen(type)
			(b as Button).text = "Rejouer : %s%s" % [BossBar.mech_name(type), (" · vue %d" % n) if n > 0 else ""]


func _button(parent: Control, text: String, tone: String) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.custom_minimum_size = Vector2(W - 20.0, 30)
	b.clip_text = true
	b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	UiTheme.style_button(b, tone, 14, {"radius": 10, "shadow": 3, "pad": Vector2(8, 2), "gloss": false})
	b.add_theme_constant_override("icon_max_width", 22)
	parent.add_child(b)
	return b
