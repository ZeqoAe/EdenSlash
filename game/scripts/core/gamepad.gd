extends Node
## Manette (autoload Gamepad). Boutons réassignables (Settings.pad_binds, Paramètres > Touches >
## Manette) ; disposition par défaut, noms Xbox ou PlayStation selon la manette : stick gauche
## déplacement, stick droit caméra, RB RT LB LT les 4 sorts (et leurs enchaînements), X attaque,
## B esquive, Y saut, A interagir / valider, Menu pause, Vue carte, croix : zoom (haut / bas),
## objectifs (gauche), équiper l'objet trouvé (droite).
## Dans les menus (jeu en pause ou lobby) c'est UiNav qui navigue (croix ou stick gauche : cadre doré,
## A valide, B retour, X clic droit, LB / RB onglets, stick droit défile ; le cadre n'apparaît qu'après un premier
## mouvement de croix / stick, avec une petite barre d'aide A / B / LB-RB en bas à gauche) ; Y passe en « curseur libre »
## où le stick gauche déplace la souris et A clique (ancien comportement, pour les zones sans bouton).
## [member active] : la dernière entrée vient de la manette (visée automatique, libellés des
## touches) ; la souris ou le clavier la rendent au clavier.

signal device_changed(pad: bool)

const DEAD := 0.22
const CURSOR_SPEED := 1500.0  # pixels par seconde, stick au bout
const SCROLL_EVERY := 0.07

var active := false
var _scroll_t := 0.0
var _last_warp := Vector2(-1, -1)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


## Mémorise un déplacement de souris voulu (navigation au cadre) : il ne rend pas la main à la souris.
func mark_warp(p: Vector2) -> void:
	_last_warp = p


func _set_active(on: bool) -> void:
	if on != active:
		active = on
		device_changed.emit(on)


func _input(ev: InputEvent) -> void:
	if ev is InputEventJoypadButton:
		_set_active(true)
	elif ev is InputEventJoypadMotion:
		if absf(ev.axis_value) > 0.5:
			_set_active(true)
	elif ev is InputEventMouseMotion:
		# les déplacements du curseur par la manette ne comptent pas
		if ev.position.distance_to(_last_warp) > 2.0 and ev.relative.length() > 3.0:
			_set_active(false)
	elif ev is InputEventKey and ev.pressed and ev.device >= 0:
		_set_active(false)
	elif ev is InputEventMouseButton and ev.pressed and ev.device >= 0:
		_set_active(false)


## Menus : jeu en pause, ou pas de héros en jeu (lobby, écran titre).
func menu_mode() -> bool:
	return get_tree().paused or get_tree().get_first_node_in_group("player") == null


static func stick(axis_x: JoyAxis, axis_y: JoyAxis) -> Vector2:
	var v := Vector2(Input.get_joy_axis(0, axis_x), Input.get_joy_axis(0, axis_y))
	if v.length() < DEAD:
		return Vector2.ZERO
	return v.normalized() * ((v.length() - DEAD) / (1.0 - DEAD))


func _process(delta: float) -> void:
	if Input.get_connected_joypads().is_empty() or not menu_mode():
		return
	var vp := get_viewport()
	var l := stick(JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y)
	if l != Vector2.ZERO and UiNav.free_mode:
		var size := vp.get_visible_rect().size
		var p := (vp.get_mouse_position() + l * l.length() * CURSOR_SPEED * delta).clamp(Vector2.ZERO, size - Vector2.ONE)
		_last_warp = p
		vp.warp_mouse(p)
	var r := stick(JOY_AXIS_RIGHT_X, JOY_AXIS_RIGHT_Y)
	_scroll_t -= delta
	if absf(r.y) > 0.3 and _scroll_t <= 0.0:
		_scroll_t = SCROLL_EVERY / absf(r.y)
		if not UiNav.free_mode and UiNav.cursor != null and is_instance_valid(UiNav.cursor):
			var at: Vector2 = UiNav.rect_of(UiNav.cursor).get_center()
			vp.warp_mouse(at)  # la molette agit là où est le curseur au cadre
			_last_warp = at
		_click(MOUSE_BUTTON_WHEEL_DOWN if r.y > 0.0 else MOUSE_BUTTON_WHEEL_UP)


func _unhandled_input(ev: InputEvent) -> void:
	if not ev is InputEventJoypadButton or not menu_mode():
		return
	match ev.button_index:
		JOY_BUTTON_A:
			# curseur libre : clic gauche là où est la souris (sinon UiNav valide le cadre)
			if UiNav.free_mode:
				_click(MOUSE_BUTTON_LEFT, ev.pressed)
				get_viewport().set_input_as_handled()
		JOY_BUTTON_Y:
			if ev.pressed and UiNav.free_mode:
				UiNav.free_mode = false  # retour au cadre de navigation
				get_viewport().set_input_as_handled()
		JOY_BUTTON_B:
			if ev.pressed:
				var k := InputEventKey.new()
				k.physical_keycode = KEY_ESCAPE
				k.keycode = KEY_ESCAPE
				k.pressed = true
				k.device = -1
				Input.parse_input_event(k)
				var up := k.duplicate()
				up.pressed = false
				Input.parse_input_event(up)
				get_viewport().set_input_as_handled()


## Clic de souris simulé (bouton [param pressed], ou appui + relâché pour la molette).
func _click(button: MouseButton, pressed := true) -> void:
	var mp := get_viewport().get_mouse_position()
	var e := InputEventMouseButton.new()
	e.button_index = button
	e.position = mp
	e.global_position = mp
	e.pressed = pressed
	e.device = -1  # simulé : ne rend pas la main à la souris
	if pressed and button == MOUSE_BUTTON_LEFT:
		e.button_mask = MOUSE_BUTTON_MASK_LEFT
	Input.parse_input_event(e)
	if button in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		var r := e.duplicate()
		r.pressed = false
		Input.parse_input_event(r)
