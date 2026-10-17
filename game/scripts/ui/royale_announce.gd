class_name RoyaleAnnounce
extends Control
## Annonces centrales du Battle royale (lot BR-I3, backlog P1 n° 18 de `conception/benchmark/BATTLE_ROYALE.md`) : une
## seule à la fois, en haut au centre, dans la DA « autocollant manga » (Bible v2 § 5 et 8) : bandeau autocollant incliné
## de −3°, titre court en Mochiy Pop One contouré d'encre, une ligne de détail, couleur selon le sens (danger fraise,
## anneau améthyste, largage soleil, lieu lagon, le reste sur papier).
## File à priorités (au lieu de bandeaux qui s'écrasent) : une annonce plus importante passe tout de suite, une moins
## importante attend la fin de la courante (au plus MAX_WAIT s, sinon elle est oubliée) ; « 3 héros restants » remplace
## « 4 héros restants » encore en attente ; le même texte ravive l'annonce au lieu de la rejouer.
## Onomatopées (« K.O. ! », « Niveau ! », « Critique ! ») au-dessus du héros : 600 ms, une à la fois, jamais superposées.
## Reçoit tous les messages du directeur par Hud.show_message (crochet du lot BR-I3) ; les lignes de butin restent au fil.

const TOP := 116.0  # haut du bandeau (sous le cadre de cible), à 1600×900
const LEFT_KEEP := 384.0  # place gardée à gauche : l'objectif court (Hud.PANEL_W + marges)
const RIGHT_KEEP := 256.0  # à droite : la mini-carte et sa colonne (RoyaleHud.COL_X)
const MAX_W := 620.0
const MIN_SHOW := 0.7  # s : une annonce de même rang n'en coupe pas une autre avant ce temps
const MAX_WAIT := 4.0  # s : au-delà, une annonce en attente n'a plus de sens
const QUEUE_MAX := 3
const WORD_LIFE := 0.6
const TILT := -3.0
## Sens d'une annonce d'après son texte (premier motif trouvé) : [motif, sorte, rang]. Rang : 0 butin, 1 information,
## 2 anneau / largage / mise à prix, 3 danger immédiat, 4 fin de partie.
const RULES := [
	["Hors de l'anneau", "danger", 3], ["Tu es mis à prix", "bounty_me", 3], ["Victoire", "win", 4], ["remporte la partie", "end", 4],
	["Éliminé", "end", 4], ["Mis à prix", "bounty", 2], ["est mis à prix", "bounty", 2], ["Largage", "drop", 2], ["largage", "drop", 2],
	["Dernier cercle", "ring", 2], ["L'anneau", "ring", 2], ["Anneau", "ring", 2], ["anneau", "ring", 2], ["Tous au sol", "ring", 2],
	["autel", "altar", 2], ["Gardien", "altar", 2], ["gardien", "altar", 2], ["Pluie de météores", "mod", 1], ["Ruée vers l'or", "mod", 1],
	["Anneau pressé", "mod", 1], ["Sources de vie", "mod", 1], ["Chasse ouverte", "mod", 1],
	["héros restant", "count", 1], ["Tu atterris", "place", 1], ["De retour", "info", 2], ["Coffres", "info", 1],
	["ouvert", "loot", 0], ["Pièce portée", "loot", 0], ["Équipé", "loot", 0],
]
## Ton d'UiTheme de chaque sorte (« papier » : texte d'encre ; les bonbons : texte blanc contouré).
const TONES := {"danger": "fraise", "bounty_me": "fraise", "win": "soleil", "end": "papier", "bounty": "soleil", "drop": "soleil",
	"ring": "amethyste", "count": "papier", "place": "lagon", "info": "papier", "loot": "papier", "altar": "mandarine", "mod": "mandarine"}

var player: Node3D
var current: Dictionary = {}  # {title, sub, kind, prio, left, shown}
var queue: Array = []  # [{title, sub, kind, prio, duration, at}]
var words: Array = []  # [{text, tone, age}]
var _holder: Control
var _panel: PanelContainer
var _title: Label
var _sub: Label
var _tw: Tween
var _clock := 0.0
var _word_ref := Vector2.ZERO
var _words: Control


func _init() -> void:
	name = "RoyaleAnnounce"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS  # (le bandeau s'efface aussi pendant un choix de carte)


func _ready() -> void:
	_holder = Control.new()
	_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_holder)
	_panel = PanelContainer.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_holder.add_child(_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(v)
	_title = RoyaleHudStyle.label(v, "", 30, RoyaleHudStyle.WHITE, RoyaleHudStyle.title_font())
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sub = RoyaleHudStyle.label(v, "", 17, RoyaleHudStyle.WHITE)
	_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_panel.modulate.a = 0.0
	_holder.visible = false
	_words = Control.new()  # (au-dessus du bandeau : une onomatopée ne passe jamais dessous)
	_words.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_words.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_words.draw.connect(_draw_words)
	add_child(_words)


## Sorte et rang d'une annonce d'après son texte : [sorte, rang].
static func classify(text: String) -> Array:
	for r in RULES:
		if text.contains(String(r[0])):
			return [String(r[1]), int(r[2])]
	return ["info", 1]


## Reçoit un message ([param text] : titre, puis « \n » et le détail) ; faux si ce n'est pas une annonce (ligne de butin).
func push(text: String, duration: float) -> bool:
	for pre in Hud.FEED_PREFIXES:
		if text.begins_with(pre) and not text.contains("\n"):
			return false
	var lines := text.split("\n", false, 1)
	var title := String(lines[0]) if lines.size() > 0 else ""
	var sub := String(lines[1]) if lines.size() > 1 else ""
	var c := classify(text)
	var a := {"title": title, "sub": sub, "kind": c[0], "prio": c[1], "duration": maxf(duration, 1.2), "at": _clock}
	if not current.is_empty() and String(current.title) == title and String(current.sub) == sub:
		current.left = maxf(float(current.left), a.duration)  # même annonce : ravivée
		return true
	if String(a.kind) == "count":
		queue = queue.filter(func(q): return String(q.kind) != "count")  # (seul le dernier compte compte)
	if current.is_empty() or int(a.prio) > int(current.prio) or (int(a.prio) == int(current.prio) and float(current.shown) >= MIN_SHOW) \
			or float(current.left) <= 0.0:
		_show(a)
	else:
		queue.append(a)
		queue.sort_custom(func(x, y): return int(x.prio) > int(y.prio) or (int(x.prio) == int(y.prio) and float(x.at) < float(y.at)))
		if queue.size() > QUEUE_MAX:
			queue.pop_back()
	return true


func _show(a: Dictionary) -> void:
	current = {"title": a.title, "sub": a.sub, "kind": a.kind, "prio": a.prio, "left": a.duration, "shown": 0.0}
	var tone := String(TONES.get(String(a.kind), "papier"))
	if tone == "fraise" and RoyaleHudStyle.colorblind():
		tone = "mandarine"
	var paper := tone == "papier"
	_panel.add_theme_stylebox_override("panel", UiTheme.sticker(tone, {"pad": Vector2(30, 8), "shadow": 6, "radius": 18}))
	_style(_title, 34 if String(a.kind) in ["win", "end"] else 30, paper, RoyaleHudStyle.title_font())
	_style(_sub, 17, paper, RoyaleHudStyle.text_font())
	_title.text = String(a.title)
	_sub.text = String(a.sub)
	_sub.visible = String(a.sub) != ""
	_fit()
	_holder.visible = true
	if _tw:
		_tw.kill()
	_panel.modulate.a = 0.0
	_panel.scale = Vector2(1.18, 1.18)
	_tw = create_tween().set_parallel()
	_tw.tween_property(_panel, "modulate:a", 1.0, 0.14)
	_tw.tween_property(_panel, "scale", Vector2.ONE, 0.26).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if String(a.kind) in ["danger", "bounty_me", "drop", "win"]:
		RoyaleAmbience.cue({"danger": "danger", "bounty_me": "danger", "drop": "drop", "win": "win"}[String(a.kind)])


## Encre sur papier ; texte blanc contouré d'encre sur un bonbon (Bible § 3).
static func _style(l: Label, size: int, paper: bool, font: Font) -> void:
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", RoyaleHudStyle.INK if paper else RoyaleHudStyle.WHITE)
	l.add_theme_constant_override("outline_size", 0 if paper else RoyaleHudStyle.outline_for(size) * 2)
	l.add_theme_color_override("font_outline_color", RoyaleHudStyle.INK)


## Largeur : jamais plus que l'espace entre l'objectif et la mini-carte ; un titre trop long passe à la ligne.
func _fit() -> void:
	var vw := _area().x
	# centré : la moitié la plus étroite (entre le centre et l'objectif, ou la mini-carte) fixe la largeur ; −3° d'inclinaison
	var room := clampf(2.0 * minf(vw * 0.5 - LEFT_KEEP, vw * 0.5 - RIGHT_KEEP) - 16.0, 360.0, MAX_W)
	var inner := room - 60.0
	var f := _title.get_theme_font("font")
	var wide := f != null and f.get_string_size(_title.text, HORIZONTAL_ALIGNMENT_LEFT, -1, _title.get_theme_font_size("font_size")).x > inner
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if wide else TextServer.AUTOWRAP_OFF
	_title.custom_minimum_size.x = inner if wide else 0.0
	var sf := _sub.get_theme_font("font")
	var sw := sf.get_string_size(_sub.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x if sf != null else 0.0
	_sub.custom_minimum_size.x = minf(sw + 2.0, inner)
	_panel.reset_size()
	_place()


func _place() -> void:
	var ms := _panel.get_combined_minimum_size()
	_panel.size = ms
	_panel.pivot_offset = ms * 0.5
	_panel.rotation_degrees = TILT
	var vw := _area().x
	var k := clampf(_area().y / 900.0, 0.8, 1.0)
	_holder.position = Vector2(roundf((vw - ms.x) * 0.5), TOP * k)


## Taille de la zone du HUD (celle de l'écran, divisée par la taille du HUD quand elle est réglée).
func _area() -> Vector2:
	if size.x > 1.0:
		return size
	return get_viewport_rect().size if is_inside_tree() else Vector2(1600, 900)


## Rectangle du bandeau à l'écran (tests).
func banner_rect() -> Rect2:
	return _panel.get_global_rect() if _holder.visible else Rect2()


func shown_title() -> String:
	return String(current.get("title", "")) if not current.is_empty() else ""


## Efface tout de suite (grande carte ouverte, menu).
func clear() -> void:
	current = {}
	queue.clear()
	if _tw:
		_tw.kill()
	_panel.modulate.a = 0.0
	_holder.visible = false


# --- onomatopées ---------------------------------------------------------------------------------------
## « K.O. ! », « Niveau ! »… au-dessus du héros (600 ms, une à la fois) ; [param tone] : couleur (bonbon [clair, base, foncé]).
func word(text: String, tone: Array = RoyaleHudStyle.SUN) -> void:
	if words.any(func(w): return String(w.text) == text and float(w.age) < 0.2):
		return
	words.append({"text": text, "tone": tone, "age": 0.0})
	if words.size() > 3:
		words.pop_front()


func _process(delta: float) -> void:
	_clock += delta
	if not current.is_empty():
		current.shown = float(current.shown) + delta
		current.left = float(current.left) - delta
		if float(current.left) <= 0.0 and not queue.is_empty() and float(current.shown) >= MIN_SHOW:
			_next()
		elif float(current.left) <= 0.0 and _panel.modulate.a > 0.99 and (_tw == null or not _tw.is_running()):
			_tw = create_tween()
			_tw.tween_property(_panel, "modulate:a", 0.0, 0.3)
			_tw.tween_callback(_faded)
	elif not queue.is_empty():
		_next()
	if not words.is_empty():
		var w: Dictionary = words[0]
		w.age = float(w.age) + delta
		if float(w.age) >= WORD_LIFE:
			words.pop_front()
		_words.queue_redraw()
	elif _word_ref != Vector2.ZERO:
		_word_ref = Vector2.ZERO
		_words.queue_redraw()


func _faded() -> void:
	current = {}
	_holder.visible = false
	if not queue.is_empty():
		_next()


func _next() -> void:
	while not queue.is_empty():
		var a: Dictionary = queue.pop_front()
		if _clock - float(a.at) <= MAX_WAIT:
			_show(a)
			return
	current = {}
	_holder.visible = false


func _draw_words() -> void:
	if words.is_empty() or player == null or not is_instance_valid(player):
		return
	var cam := get_viewport().get_camera_3d()
	if cam == null or cam.is_position_behind(player.global_position):
		return
	var w: Dictionary = words[0]
	var k := float(w.age) / WORD_LIFE
	var base := cam.unproject_position(player.global_position + Vector3.UP * 2.6)
	# (le HUD est peut-être agrandi : on dessine dans son repère)
	base = _words.get_global_transform_with_canvas().affine_inverse() * base
	_word_ref = base
	var size := 40
	var s := 1.0 + 0.35 * maxf(0.0, 1.0 - k * 5.0)  # pop d'entrée
	var a := 1.0 - maxf(0.0, (k - 0.7) / 0.3)
	var f := RoyaleHudStyle.title_font()
	var txt := String(w.text)
	var tw := f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	_words.draw_set_transform(base + Vector2(0, -34.0 * k), deg_to_rad(-6.0), Vector2(s, s))
	var tone: Array = w.tone
	_words.draw_string_outline(f, Vector2(-tw * 0.5, 0), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 18, Color(RoyaleHudStyle.INK, a))
	_words.draw_string(f, Vector2(-tw * 0.5, 0), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(tone[1], a))
	_words.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
