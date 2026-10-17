extends CanvasLayer
## Ressenti du clic (autoload UiFeel, bible de style v2 § 7) : vaut pour CHAQUE BaseButton de l'écran, sans branchement
## par bouton (le contrôle survolé est relu à chaque image, l'appui et le relâchement sont lus dans _input) : tous les
## menus actuels et futurs en profitent sans rien écrire, et un écran chargé ne paie rien de plus.
##   survol : léger agrandissement en ressort + « tic » ; appui : écrasement (quad) + « pop » + vibration courte ;
##   relâchement : rebond en ressort + « clic » ; bouton désactivé cliqué : secousse + « bonk » + vibration sourde ;
##   focus manette (UiNav) : même entrée que le survol + « tic » de focus ; interrupteur : le bouton s'aplatit, étoiles
##   pomme à l'allumage ; bouton primaire : anneau blanc + 4 étincelles au relâchement.
## Seuls scale, rotation (cartes) et modulate bougent : jamais la taille ni la position dans la mise en page (la zone
## cliquable au repos et la navigation manette ne changent pas) ; animations en pause comprises (TWEEN_PAUSE_PROCESS).
##
## Genre d'un contrôle : meta « ui_feel » = button (défaut), primary, tab, toggle, slot, card, row, ou « off » (rien) ;
## UiFeel.attach(contrôle, genre) pour un panneau cliquable qui n'est pas un BaseButton.
## Outils pour les écrans : pop_in / pop_out (fenêtre en ressort), slide_in (contenu d'onglet), count (nombre qui
## monte), sparkle / ring / confetti (particules CPU discrètes, coupées sur un écran chargé ou « Réduire les animations »).
## Réglages (Paramètres > Caméra & interface) : interface/ui_reduce_motion, ui_vibration, ui_fx (intensité 0 à 1,5).

const MAX_GROW_PX := 10.0  # un grand contrôle (ligne pleine largeur) ne grossit jamais de plus de 10 px
const BUSY := 40  # au-delà de 40 boutons visibles, pas de particules (bible § 7)
## Sons d'interface : [nom Sfx, dB, hauteur]. Bibliothèque SND-1 (game/assets/sfx/ui/, tools/art/snd_synth.py) : chaque
## fichier est à la même sonie de référence, ces dB font la hiérarchie de la bible (§ 7) ; survol, focus, appui et
## relâchement ont 3 variantes tirées au hasard (Sfx), hauteur ±3 % en plus ; jamais deux fois le même en 40 ms (Sfx.ui).
const SOUNDS := {
	"hover": ["ui_hover", -26.0, 1.0], "focus": ["ui_focus", -24.0, 1.0], "press": ["ui_press", -15.0, 1.0],
	"release": ["ui_release", -13.0, 1.0], "primary": ["ui_primary", -9.0, 1.0], "deny": ["ui_deny", -13.0, 1.0],
	"tab": ["ui_tab", -16.0, 1.0], "toggle_on": ["ui_toggle_on", -16.0, 1.0], "toggle_off": ["ui_toggle_off", -17.0, 1.0],
	"swoosh": ["ui_swoosh", -15.0, 1.0], "equip": ["ui_equip", -12.0, 1.0], "reward": ["ui_reward", -6.0, 1.0],
	"open": ["ui_open", -17.0, 1.0], "close": ["ui_close", -19.0, 1.0],
}
## Vibrations (faible, fort, durée s), d'après les jetons.
const VIB := {"focus": [0.06, 0.0, 0.025], "press": [0.18, 0.0, 0.04], "primary": [0.25, 0.12, 0.07],
	"deny": [0.0, 0.35, 0.09], "reward": [0.3, 0.45, 0.18], "tab": [0.1, 0.0, 0.03], "toggle": [0.1, 0.0, 0.03]}
const CANDY := ["soleil", "papier", "lagon", "fraise", "pomme", "mandarine", "amethyste"]

var reduce_motion := false
var vibration := true
var intensity := 1.0
var enabled := true
var _fx: Control
var _effects: Array = []
var _focused: Control


func _ready() -> void:
	layer = 121
	process_mode = Node.PROCESS_MODE_ALWAYS
	_fx = Control.new()
	_fx.name = "UiFeelFx"
	_fx.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fx.draw.connect(_draw_fx)
	add_child(_fx)
	get_tree().node_added.connect(_on_node_added)
	Settings.changed.connect(read_settings)
	read_settings()


func read_settings() -> void:
	reduce_motion = bool(Settings.get_v("interface", "ui_reduce_motion"))
	vibration = bool(Settings.get_v("interface", "ui_vibration"))
	intensity = clampf(float(Settings.get_v("interface", "ui_fx")), 0.0, 1.5)
	if not UiTheme.skin_forced:  # --ui-skin=… (essais, captures) l'emporte sur le réglage caché
		UiTheme.set_skin(String(Settings.get_v("interface", "ui_skin")))


func _on_node_added(n: Node) -> void:
	if n is BaseButton and (n as BaseButton).toggle_mode:
		_prepare_toggle(n as BaseButton)
	# zones papier (UiTheme.paper) : un texte ou un bouton ajouté plus tard est adapté à son fond
	if UiTheme.paper_used and (n is Label or n is Button or n is TextureRect or n is RichTextLabel) and UiTheme.in_paper(n):
		UiTheme.ink_watch(n as Control)


# --- branchement ------------------------------------------------------------------------
## Genre du ressenti d'un contrôle ([param kind], voir l'en-tête) ; un panneau cliquable qui n'est pas un BaseButton
## n'a de ressenti qu'après cet appel.
func attach(c: Control, kind := "button") -> void:
	if c != null:
		c.set_meta("ui_feel", kind)


## Bouton à bascule : variation « ToggleButton » s'il n'en a pas (enfoncé = sélectionné, lagon) et contour du texte
## choisi sur papier (constante de thème « sel_outline »).
func _prepare_toggle(b: BaseButton) -> void:
	if b.get_class() == "Button" and b.theme_type_variation == &"" and not (b is UiTheme.Switch):
		b.theme_type_variation = &"ToggleButton"
	if not b.has_meta("_uf_sel"):
		b.set_meta("_uf_sel", true)
		b.draw.connect(_sel_outline.bind(b))


## Godot n'a qu'une épaisseur de contour de texte pour tous les états : sur papier, le texte d'un bouton à bascule est à
## l'encre sans contour, et blanc contouré d'encre quand il est choisi.
func _sel_outline(c: BaseButton) -> void:
	var so := c.get_theme_constant("sel_outline")
	if so <= 0 or c.has_theme_color_override("font_pressed_color") or c.has_theme_stylebox_override("pressed"):
		return  # l'écran a son propre style de bouton choisi : on n'y touche pas
	var want := so if c.button_pressed else 0
	if c.get_theme_constant("outline_size") != want:
		c.add_theme_constant_override("outline_size", want)
		c.queue_redraw.call_deferred()  # (UIK1 : pendant un dessin, Godot ignore la demande d'un nouveau dessin)


func kind_of(c: Control) -> String:
	if c.has_meta("ui_feel"):
		return String(c.get_meta("ui_feel"))
	if c is UiTheme.Switch or c is CheckBox or c is CheckButton:
		return "toggle"
	if c is ItemWidgets.ItemSlot:
		return "slot"  # case d'objet : 1,06 au survol, 0,92 à l'appui, « clac » d'équipement
	if c.size.x >= 260.0 and c.size.y >= 200.0:
		return "card"
	return "button"


func _off(c: Control) -> bool:
	return not enabled or c == null or not is_instance_valid(c) or kind_of(c) == "off"


func _disabled(c: Control) -> bool:
	return c is BaseButton and (c as BaseButton).disabled


## Contrôle qui reçoit le ressenti pour le contrôle [param h] sous la souris : lui-même ou un parent proche (bouton dont
## un enfant laisse passer la souris), s'il est un BaseButton ou porte la meta « ui_feel ».
func target_of(h: Control) -> Control:
	var c := h
	for i in 3:
		if c == null:
			return null
		if c is BaseButton or c.has_meta("ui_feel"):
			return null if _off(c) else c
		c = c.get_parent() as Control
	return null


# --- événements ---------------------------------------------------------------------------
var _hot: Control  # contrôle survolé (souris)
var _down: Control  # contrôle appuyé


## Survol : relu à chaque image (souris déplacée, liste qui défile, contrôle qui apparaît sous la souris).
func _track_hover() -> void:
	var vp := get_viewport()
	var h := target_of(vp.gui_get_hovered_control()) if vp != null else null
	if _hot != null and not is_instance_valid(_hot):
		_hot = null
	if h == _hot:
		return
	var old := _hot
	_hot = h
	if old != null and old != _focused:
		_exit(old)
	if h != null:
		_enter(h, false)


func _input(ev: InputEvent) -> void:
	if not enabled or not (ev is InputEventMouseButton) or (ev as InputEventMouseButton).button_index != MOUSE_BUTTON_LEFT:
		return
	var mb := ev as InputEventMouseButton
	if mb.pressed:
		var c: Control = null
		# clic de la manette (UiNav.activate, souris déplacée dans la même image) : le contrôle sous le cadre
		if mb.device == -1 and UiNav.cursor != null and is_instance_valid(UiNav.cursor) and UiNav.rect_of(UiNav.cursor).has_point(mb.position):
			c = target_of(UiNav.cursor)
		if c == null:
			_track_hover()
			c = _hot
		if c == null:
			return
		if _disabled(c):
			deny(c)
			return
		_down = c
		_press(c)
	elif _down != null:
		var c := _down
		_down = null
		if is_instance_valid(c) and not _disabled(c):
			_release(c)


func _enter(c: Control, from_pad: bool) -> void:
	if _off(c) or _disabled(c):
		return
	if c is BaseButton and (c as BaseButton).toggle_mode:
		_prepare_toggle(c as BaseButton)
	var k := kind_of(c)
	if k != "toggle":
		var a := _amp(c)
		_anim(c, Vector2.ONE * (1.0 + a), UiTheme.dur("survol-entree"), Tween.TRANS_BACK, Tween.EASE_OUT, -1.0 if k == "card" else 0.0)
	_sound("focus" if from_pad else "hover")


func _exit(c: Control) -> void:
	if _off(c) or (c == _focused and UiNav.shown):
		return
	_anim(c, Vector2.ONE, UiTheme.dur("survol-sortie"), Tween.TRANS_CUBIC, Tween.EASE_OUT, 0.0)


func _press(c: Control) -> void:
	var k := kind_of(c)
	var a := _amp(c)
	if k == "toggle":
		_squash(c, 1.2)
	else:
		var sq := Vector2(1.0 + a * 1.5, 1.0 - a * 2.5) if k != "slot" else Vector2.ONE * (1.0 - a * 2.0)
		_anim(c, sq, UiTheme.dur("appui"), Tween.TRANS_QUAD, Tween.EASE_IN, 0.0)
	_sound("press")
	_vibrate("primary" if k == "primary" else "press")


func _release(c: Control) -> void:
	var k := kind_of(c)
	var a := _amp(c)
	if k == "toggle":
		_squash(c, 1.0)
		var on := c is BaseButton and (c as BaseButton).toggle_mode and not (c as BaseButton).button_pressed  # l'état change juste après
		_sound_late("toggle_on" if on else "toggle_off")
		_vibrate("toggle")
		if on:
			sparkle(_center(c), 2, ["pomme"], 10.0)
		return
	var hot := c == _hot or c == _focused
	var rest := Vector2.ONE * (1.0 + a) if hot else Vector2.ONE
	var tw := _anim(c, Vector2(1.0 - a * 0.75, 1.0 + a * 1.25), UiTheme.dur("appui") * 0.8, Tween.TRANS_QUAD, Tween.EASE_OUT, 0.0)
	if tw != null:
		tw.tween_property(c, "scale", rest, UiTheme.dur("relache")).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	match k:
		"primary":
			_sound_late("primary")
			var p := _center(c)
			ring(p, maxf(c.size.x, c.size.y) * 0.5)
			sparkle(p, 4, ["soleil", "papier", "lagon", "fraise"], maxf(c.size.x, c.size.y) * 0.45)
		"tab":
			_sound_late("tab")
			_vibrate("tab")
		"card":
			_sound_late("swoosh")
		"slot":
			_sound_late("equip")
		_:
			_sound_late("release")


## Contrôle désactivé cliqué : secousse horizontale (±4 px, 3 allers-retours en 240 ms), « bonk », vibration sourde.
func deny(c: Control) -> void:
	_sound("deny")
	_vibrate("deny")
	if reduce_motion or c.has_meta("_uf_shake"):
		return
	c.set_meta("_uf_shake", true)
	var x0 := c.position.x
	var tw := c.create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	var step := UiTheme.dur("refus") / 6.0
	for i in 3:
		tw.tween_property(c, "position:x", x0 + 4.0, step)
		tw.tween_property(c, "position:x", x0 - 4.0, step)
	tw.tween_callback(func():
		if is_instance_valid(c):
			c.position.x = x0
			c.remove_meta("_uf_shake")
			if c.get_parent() is Container:
				(c.get_parent() as Container).queue_sort())


## Focus manette (UiNav) : le contrôle quitte / prend l'état « survolé », tic de focus et vibration légère.
func nav_focus(c: Control, prev: Control) -> void:
	if prev != null and is_instance_valid(prev) and prev != c:
		_focused = null
		_exit(prev)
	_focused = c
	if c != null and is_instance_valid(c) and target_of(c) == c:
		_enter(c, true)
	elif c != null:
		_sound("focus")
	_vibrate("focus")


# --- animations -------------------------------------------------------------------------
## Amplitude d'échelle d'un contrôle : 4 % (bible) sans dépasser MAX_GROW_PX, × intensité.
func _amp(c: Control) -> float:
	var big := maxf(maxf(c.size.x, c.size.y), 1.0)
	var base := 0.03 if kind_of(c) == "card" else (0.06 if kind_of(c) == "slot" else 0.04)
	return minf(base, MAX_GROW_PX / big) * intensity


func _anim(c: Control, to: Vector2, d: float, trans: Tween.TransitionType, ease: Tween.EaseType, rot_deg: float) -> Tween:
	if not c.is_inside_tree():
		return null
	var prev: Variant = c.get_meta("_uf_tw") if c.has_meta("_uf_tw") else null
	if prev is Tween and (prev as Tween).is_valid():
		(prev as Tween).kill()
	elif not c.scale.is_equal_approx(Vector2.ONE) and not c.has_meta("_uf_own"):
		return null  # l'écran anime déjà ce contrôle lui-même (apparition…) : on ne s'en mêle pas
	if reduce_motion or intensity <= 0.0:
		c.scale = Vector2.ONE
		c.rotation = 0.0
		return null
	c.set_meta("_uf_own", true)
	c.pivot_offset = Vector2(c.size.x * 0.5, c.size.y) if kind_of(c) == "card" else c.size * 0.5
	var tw := c.create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(c, "scale", to, d).set_trans(trans).set_ease(ease)
	if kind_of(c) == "card":
		tw.parallel().tween_property(c, "rotation", deg_to_rad(rot_deg), d).set_trans(trans).set_ease(ease)
	c.set_meta("_uf_tw", tw)
	return tw


func _squash(c: Control, v: float) -> void:
	if not ("squash" in c) or reduce_motion:
		return
	var tw := c.create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_method(func(x: float): c.set("squash", x); c.queue_redraw(), float(c.get("squash")), v,
		UiTheme.dur("appui") if v > 1.0 else 0.16).set_trans(Tween.TRANS_BACK if v <= 1.0 else Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


## Fenêtre qui apparaît en ressort (0,9 → 1, fondu) ; sans effet avec « Réduire les animations ».
func pop_in(c: Control) -> void:
	if c == null or reduce_motion:
		return
	c.pivot_offset = c.size * 0.5
	c.scale = Vector2.ONE * 0.9
	c.modulate.a = 0.0
	var tw := c.create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.set_parallel()
	tw.tween_property(c, "scale", Vector2.ONE, UiTheme.dur("apparition")).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(c, "modulate:a", 1.0, UiTheme.dur("apparition") * 0.6)


## Fenêtre qui disparaît (1 → 0,94, fondu) puis [param then].
func pop_out(c: Control, then := Callable()) -> void:
	if c == null or reduce_motion:
		if then.is_valid():
			then.call()
		return
	c.pivot_offset = c.size * 0.5
	var tw := c.create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.set_parallel()
	tw.tween_property(c, "scale", Vector2.ONE * 0.94, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(c, "modulate:a", 0.0, 0.12)
	tw.chain().tween_callback(func():
		if is_instance_valid(c):
			c.scale = Vector2.ONE
			c.modulate.a = 1.0
		if then.is_valid():
			then.call())


## Contenu d'un onglet qui glisse de 24 px dans le sens du changement ([param dir] = ±1) en fondu (260 ms).
func slide_in(c: Control, dir: int) -> void:
	if c == null or reduce_motion or dir == 0:
		return
	var free_pos := not (c.get_parent() is Container)
	var x0 := c.position.x
	c.modulate.a = 0.0
	var tw := c.create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.set_parallel()
	if free_pos:
		c.position.x = x0 + 24.0 * float(dir)
		tw.tween_property(c, "position:x", x0, UiTheme.dur("page")).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(c, "modulate:a", 1.0, UiTheme.dur("page") * 0.7)


## Nombre qui monte de [param from] à [param to] dans [param label] (800 ms) ; [param fmt] met en forme (int par défaut).
func count(label: Label, from: float, to: float, fmt := Callable(), d := -1.0) -> void:
	var f := fmt
	if not f.is_valid():
		f = func(x: float) -> String:
			return str(roundi(x))
	if label == null:
		return
	if reduce_motion:
		label.text = f.call(to)
		return
	var tw := label.create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_method(func(x: float): label.text = f.call(x), from, to, d if d > 0.0 else UiTheme.dur("compteur")).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


# --- particules (CPU, dessinées dans un seul Control) ------------------------------------
func _center(c: Control) -> Vector2:
	return c.get_global_transform_with_canvas() * (c.size * 0.5)


func _fx_ok() -> bool:
	if reduce_motion or intensity <= 0.0 or DisplayServer.get_name() == "headless":
		return false
	var n := 0
	for b in get_tree().root.find_children("*", "BaseButton", true, false):
		if (b as CanvasItem).is_visible_in_tree():
			n += 1
			if n > BUSY:
				return false
	return true


## Anneau blanc qui s'élargit (rayon +24 px, 260 ms, 80 % → 0).
func ring(pos: Vector2, r0: float) -> void:
	if not _fx_ok():
		return
	_effects.append({"t": "ring", "p": pos, "r0": r0, "life": 0.26, "age": 0.0})


## [param n] étincelles en étoile à 4 branches, vers l'extérieur (300 ms).
func sparkle(pos: Vector2, n: int, colors: Array, r0 := 12.0) -> void:
	if not _fx_ok():
		return
	for i in int(ceil(n * clampf(intensity, 0.5, 1.5))):
		var a := TAU * float(i) / float(n) + randf_range(-0.3, 0.3) - PI * 0.25
		var dir := Vector2(cos(a), sin(a))
		_effects.append({"t": "star", "p": pos + dir * r0, "v": dir * randf_range(70.0, 110.0), "c": _candy(String(colors[i % colors.size()])),
			"s": randf_range(6.0, 9.0), "life": 0.3, "age": 0.0, "rot": randf() * TAU})


## Confettis des bonbons (récompenses rares, bilans de victoire) : 24 au plus, 1,2 s.
func confetti(pos: Vector2, n := 24) -> void:
	if not _fx_ok():
		return
	for i in mini(n, 24):
		var a := randf_range(-PI * 0.9, -PI * 0.1)
		_effects.append({"t": "confetti", "p": pos, "v": Vector2(cos(a), sin(a)) * randf_range(180.0, 380.0), "c": _candy(CANDY[i % 5]),
			"s": randf_range(5.0, 9.0), "life": 1.2, "age": 0.0, "rot": randf() * TAU, "spin": randf_range(-9.0, 9.0)})


func _candy(n: String) -> Color:
	if n == "papier":
		return Color.WHITE
	return UiTheme.color("bonbon.%s.base" % n, Color.WHITE)


func _process(delta: float) -> void:
	if enabled:
		_track_hover()
		if _hot != null and not reduce_motion and kind_of(_hot) == "primary":
			_hot.queue_redraw()  # rayons de soleil qui tournent derrière le primaire survolé (StickerBox.rays)
	if _focused != null and (not is_instance_valid(_focused) or UiNav.cursor != _focused or not UiNav.shown):
		var old := _focused
		_focused = null
		if is_instance_valid(old) and old.is_inside_tree() and not old.get_global_rect().has_point(old.get_global_mouse_position()):
			_exit(old)  # le cadre de la manette est parti ailleurs (onglet changé, menu fermé)
	if _effects.is_empty():
		return
	for e in _effects:
		e.age += delta
		if e.has("v"):
			e.p += e.v * delta
			e.v *= 1.0 - minf(delta * (2.0 if e.t == "confetti" else 6.0), 0.9)
			if e.t == "confetti":
				e.v.y += 520.0 * delta
				e.rot += e.spin * delta
	_effects = _effects.filter(func(e): return e.age < e.life)
	_fx.queue_redraw()


func _draw_fx() -> void:
	var ink := UiTheme.color("encre.700")
	for e in _effects:
		var k: float = e.age / e.life
		match String(e.t):
			"ring":
				var r: float = e.r0 + 24.0 * ease(k, 0.4)
				_fx.draw_arc(e.p, r, 0.0, TAU, 48, Color(1, 1, 1, 0.8 * (1.0 - k)), 4.0 * (1.0 - k) + 1.0, true)
			"star":
				_star(e.p, e.s * (1.0 - k * 0.5), e.rot, Color(e.c, 1.0 - k * k), ink)
			"confetti":
				_fx.draw_set_transform(e.p, e.rot, Vector2.ONE)
				_fx.draw_rect(Rect2(-e.s * 0.5, -e.s * 0.3, e.s, e.s * 0.6), Color(e.c, 1.0 - maxf(k - 0.7, 0.0) / 0.3))
				_fx.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Étoile à 4 branches contourée d'encre (comme les étincelles des icônes du jeu).
func _star(p: Vector2, s: float, rot: float, col: Color, ink: Color) -> void:
	var pts := PackedVector2Array()
	for i in 8:
		var a := rot + PI * 0.25 * float(i)
		pts.append(p + Vector2(cos(a), sin(a)) * (s if i % 2 == 0 else s * 0.32))
	var outline := PackedVector2Array()
	for i in 8:
		var a := rot + PI * 0.25 * float(i)
		outline.append(p + Vector2(cos(a), sin(a)) * ((s + 2.5) if i % 2 == 0 else s * 0.32 + 2.0))
	_fx.draw_colored_polygon(outline, Color(ink, col.a))
	_fx.draw_colored_polygon(pts, col)


# --- sons et vibrations -----------------------------------------------------------------
## Le survol ne fait de bruit que dans les menus (pas sur le HUD en plein combat).
func _sound(name: String) -> void:
	if not SOUNDS.has(name) or intensity <= 0.0:
		return
	if name == "hover" and not Gamepad.menu_mode():
		return
	if (name == "hover" or name == "focus") and Time.get_ticks_msec() - Sfx.last_ui_ms < 40:
		return  # un tic de survol ne se pose jamais sur un autre son d'interface
	var s: Array = SOUNDS[name]
	Sfx.ui(String(s[0]), float(s[1]), float(s[2]) * randf_range(0.97, 1.03))


## Page ou fenêtre qui s'ouvre ([param open]) ou se ferme (PageScreen) : souffle + pincé ; joué au relâchement du
## bouton qui l'ouvre, il prend la place de son « clic » (_sound_late).
func page_sound(open: bool) -> void:
	_sound("open" if open else "close")


## Son du relâchement, seulement si l'écran n'a pas déjà joué le sien (validation, coffre…) à cet instant.
func _sound_late(name: String) -> void:
	var t0 := Sfx.last_ui_ms
	await get_tree().process_frame
	if Sfx.last_ui_ms != t0 and Time.get_ticks_msec() - Sfx.last_ui_ms < 60:
		return
	_sound(name)


## Moment d'un écran (étoiles, victoire, élimination… : lot ACX-2) : son [param sfx] (nom Sfx, [param db], hauteur
## [param pitch]) et vibration [param vib] = [faible, fort, s] ([] : aucune) ; respecte l'intensité et la vibration réglées.
func cue(sfx: String, db := -8.0, pitch := 1.0, vib: Array = []) -> void:
	if intensity > 0.0 and sfx != "":
		Sfx.ui(sfx, db, pitch * randf_range(0.98, 1.02))
	if vib.size() < 3 or not vibration or not Gamepad.active:
		return
	var pads := Input.get_connected_joypads()
	if pads.is_empty():
		return
	var k := clampf(intensity, 0.3, 1.2)
	Input.start_joy_vibration(int(pads[0]), clampf(float(vib[0]) * k, 0.0, 1.0), clampf(float(vib[1]) * k, 0.0, 1.0), float(vib[2]))


func _vibrate(kind: String) -> void:
	if not vibration or not Gamepad.active or not VIB.has(kind) or not Gamepad.menu_mode():
		return
	var pads := Input.get_connected_joypads()
	if pads.is_empty():
		return
	var v: Array = VIB[kind]
	var k := clampf(intensity, 0.3, 1.2)
	Input.start_joy_vibration(int(pads[0]), clampf(float(v[0]) * k, 0.0, 1.0), clampf(float(v[1]) * k, 0.0, 1.0), float(v[2]))
