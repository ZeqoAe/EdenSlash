class_name AutochessMoment
extends Control
## L'Échiquier, lot ACX-2 : les « moments manga » (BIBLE v2 §8, étude BM-AUTO §5 n° 12-13 et §6 n° 7-8). Un seul calque
## au-dessus du plateau, qui ne prend jamais la souris :
##   - bannière inclinée (banner) : autocollant contouré d'encre, Mochiy blanc contouré, incliné de −4°, traits de vitesse
##     et étincelles derrière ; arrive en ressort de la gauche, tient, repart à droite. Une à la fois, en file (jamais deux
##     superposées) : « Combat ! », « Victoire ! », « Défaite », « ★★★ ! », « Objet complet ! », « Niveau 7 ! »… ;
##   - éclat sur place (burst) : une onomatopée courte au-dessus d'une figurine (fusion, objet), étoiles + anneau d'UiFeel ;
##   - vignette d'élimination (elimination) : à droite, « Daphné · 7e », portrait qui se grise et tombe.
## Son et vibration de la manette par UiFeel.cue ; « Réduire les animations » : rien ne bouge (fondu seul), sans traits.
## Le texte reste court et sans pourcentage.

const TILT := -4.0  # degrés
const IN_TIME := 0.22
const OUT_TIME := 0.18
const LINES := 26  # traits de vitesse
## Tons d'une bannière : [fond, texte].
const TONES := {
	"soleil": ["soleil", Color.WHITE], "pomme": ["pomme", Color.WHITE], "fraise": ["fraise", Color.WHITE],
	"lagon": ["lagon", Color.WHITE], "amethyste": ["amethyste", Color.WHITE], "papier": ["papier", AutochessHud.INK],
}

var shown: Array = []  ## textes des bannières déjà montrées (tests), dans l'ordre
var _queue: Array = []
var _busy := false
var _lines_t := -1.0
var _lines_c := Vector2.ZERO
var _lines_r := 120.0
var _lines_seed := 0
var _elims: VBoxContainer


func _init() -> void:
	name = "AcMoments"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	_elims = VBoxContainer.new()
	_elims.name = "AcElims"
	_elims.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_elims.anchor_left = 1.0
	_elims.anchor_right = 1.0
	_elims.anchor_top = 0.5
	_elims.anchor_bottom = 0.5
	_elims.offset_left = -AutochessHud.s(AutochessHud.MARGIN + AutochessHud.SIDE_W + 230.0)
	_elims.offset_right = -AutochessHud.s(AutochessHud.MARGIN + AutochessHud.SIDE_W + 14.0)
	_elims.alignment = BoxContainer.ALIGNMENT_END
	_elims.add_theme_constant_override("separation", roundi(AutochessHud.s(8)))
	add_child(_elims)


func busy() -> bool:
	return _busy or not _queue.is_empty()


## Bannière inclinée [param text] (ton [param tone] : soleil, pomme, fraise, lagon, amethyste, papier), petite ligne
## [param sub] dessous ; [param sfx] / [param db] / [param pitch] : son ; [param vib] : [faible, fort, s].
## [param hold] : durée tenue (s). En file derrière la bannière en cours.
func banner(text: String, tone := "soleil", sub := "", sfx := "", db := -8.0, pitch := 1.0, vib: Array = [], hold := 0.75) -> void:
	shown.append(text)
	_queue.append({"text": text, "tone": tone, "sub": sub, "sfx": sfx, "db": db, "pitch": pitch, "vib": vib, "hold": hold})
	if not _busy:
		_next()


## Vide la file (nouvelle partie, fin).
func clear_all() -> void:
	_queue.clear()
	for c in get_children():
		if c != _elims:
			c.queue_free()
	for c in _elims.get_children():
		c.queue_free()
	_busy = false
	_lines_t = -1.0
	queue_redraw()


func _next() -> void:
	if _queue.is_empty():
		_busy = false
		return
	_busy = true
	var e: Dictionary = _queue.pop_front()
	var tone: Array = TONES.get(String(e.tone), TONES.soleil)
	var holder := Control.new()
	holder.name = "AcBanner_%s" % String(e.text).left(12)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(holder)
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := AutochessHud.sticker(AutochessHud.candy(String(tone[0])) if String(tone[0]) != "papier" else AutochessHud.PAPER,
		16.0, 7.0, 3.0, 34.0, 6.0)
	panel.add_theme_stylebox_override("panel", sb)
	holder.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", -4)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(v)
	var t := AutochessHud.pop_lbl(String(e.text), 48, tone[1])
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	if String(e.sub) != "":
		var s := AutochessHud.ink_lbl(String(e.sub), 18, AutochessHud.INK if String(tone[0]) in ["papier", "soleil", "pomme"] else Color.WHITE, 900)
		s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		if String(tone[0]) not in ["papier", "soleil", "pomme"]:
			s.add_theme_constant_override("outline_size", 4)
			s.add_theme_color_override("font_outline_color", AutochessHud.INK)
		v.add_child(s)
	panel.reset_size()
	var vs := get_viewport_rect().size
	var sz := panel.get_combined_minimum_size()
	panel.size = sz
	holder.size = sz
	holder.pivot_offset = sz * 0.5
	var home := Vector2((vs.x - sz.x) * 0.5, vs.y * 0.36 - sz.y * 0.5)
	holder.position = home
	holder.rotation = deg_to_rad(TILT)
	UiFeel.cue(String(e.sfx), float(e.db), float(e.pitch), e.vib)
	var calm := UiFeel.reduce_motion
	if not calm:
		_lines_t = 0.0
		_lines_c = home + sz * 0.5
		_lines_r = maxf(sz.x, sz.y) * 0.55
		_lines_seed = randi()
		UiFeel.sparkle(_lines_c + Vector2(sz.x * 0.45, -sz.y * 0.4), 3, ["soleil", "papier", "lagon"], 10.0)
	var tw := holder.create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	if calm:
		holder.modulate.a = 0.0
		tw.tween_property(holder, "modulate:a", 1.0, 0.12)
		tw.tween_interval(float(e.hold))
		tw.tween_property(holder, "modulate:a", 0.0, 0.15)
	else:
		holder.position = home + Vector2(-vs.x * 0.35, 0.0)
		holder.scale = Vector2.ONE * 1.25
		tw.set_parallel()
		tw.tween_property(holder, "position", home, IN_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(holder, "scale", Vector2.ONE, IN_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.chain().tween_interval(float(e.hold))
		tw.chain().tween_property(holder, "position", home + Vector2(vs.x * 0.3, -10.0), OUT_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.parallel().tween_property(holder, "modulate:a", 0.0, OUT_TIME)
	tw.chain().tween_callback(func():
		holder.queue_free()
		_next())


## Éclat sur place : onomatopée [param text] en Mochiy au point [param at] de l'écran (au-dessus d'une figurine), étoiles
## de [param colors] et anneau ; son et vibration comme banner.
func burst(at: Vector2, text: String, tone := "soleil", sfx := "", db := -8.0, pitch := 1.0, vib: Array = []) -> void:
	shown.append(text)
	UiFeel.cue(sfx, db, pitch, vib)
	var l := AutochessHud.pop_lbl(text, 30, AutochessHud.candy(tone, 0) if tone != "papier" else Color.WHITE)
	l.rotation = deg_to_rad(TILT)
	add_child(l)
	l.reset_size()
	l.pivot_offset = l.size * 0.5
	l.position = at - l.size * 0.5
	UiFeel.ring(at, 18.0)
	UiFeel.sparkle(at, 4, [tone, "papier", "soleil", "lagon"], 14.0)
	var tw := l.create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	if UiFeel.reduce_motion:
		tw.tween_interval(0.7)
	else:
		l.scale = Vector2.ONE * 0.5
		tw.tween_property(l, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(l, "position:y", l.position.y - 26.0, 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_interval(0.25)
	tw.tween_property(l, "modulate:a", 0.0, 0.25)
	tw.tween_callback(l.queue_free)


## Vignette d'élimination d'un autre stratège : « [param who] · 7e » avec son portrait ([param icon]) qui se grise et
## tombe (300 ms), son sourd. Reste 2,6 s.
func elimination(who: String, place: int, icon: Texture2D) -> void:
	shown.append("%s · %s" % [who, AutochessPlayers.place_text(place)])
	UiFeel.cue("error", -10.0, 0.62, [0.0, 0.3, 0.12])
	var row := PanelContainer.new()
	row.name = "AcElim_%s" % who
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_stylebox_override("panel", AutochessHud.sticker(AutochessHud.PAPER, 14.0, 5.0, 3.0, 10.0, 6.0))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", roundi(AutochessHud.s(10)))
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(h)
	var face := TextureRect.new()
	face.texture = icon
	face.custom_minimum_size = Vector2.ONE * AutochessHud.s(40)
	face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(face)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", -2)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(v)
	v.add_child(AutochessHud.ink_lbl(who, 17, AutochessHud.INK, 900))
	var sub := AutochessHud.ink_lbl("éliminé · %s" % AutochessPlayers.place_text(place), 14, AutochessHud.LOSS, 800)
	v.add_child(sub)
	_elims.add_child(row)
	var tw := row.create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	if not UiFeel.reduce_motion:
		row.modulate.a = 0.0
		tw.tween_property(row, "modulate:a", 1.0, 0.15)
		tw.tween_property(face, "modulate", Color(0.55, 0.55, 0.6, 0.8), 0.3)
		tw.parallel().tween_property(face, "rotation", deg_to_rad(18.0), 0.3).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	else:
		face.modulate = Color(0.55, 0.55, 0.6, 0.8)
	tw.tween_interval(2.6)
	tw.tween_property(row, "modulate:a", 0.0, 0.3)
	tw.tween_callback(row.queue_free)


func _process(delta: float) -> void:
	if _lines_t < 0.0:
		return
	_lines_t += delta
	if _lines_t > 0.9:
		_lines_t = -1.0
	queue_redraw()


## Traits de vitesse : rayons blancs fins depuis le centre de la bannière (BIBLE §8), 0,9 s, sur l'événement seulement.
func _draw() -> void:
	if _lines_t < 0.0:
		return
	var k := _lines_t / 0.9
	var r := RandomNumberGenerator.new()
	r.seed = _lines_seed
	var alpha := (1.0 - k) * 0.85
	for i in LINES:
		var a := TAU * float(i) / float(LINES) + r.randf_range(-0.08, 0.08)
		var d := Vector2(cos(a), sin(a) * 0.55)
		var r0 := _lines_r * (1.05 + r.randf() * 0.25) + 40.0 * k
		var r1 := r0 + _lines_r * (0.35 + r.randf() * 0.5)
		draw_line(_lines_c + d * r0, _lines_c + d * r1, Color(1, 1, 1, alpha), 2.0 + r.randf() * 2.0, true)
