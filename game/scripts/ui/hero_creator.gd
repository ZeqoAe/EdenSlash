class_name HeroCreator
extends PageScreen
## Création de personnage (lot C1) : nom du héros, coiffure, couleur des cheveux et des yeux, aperçu 3D qui tourne
## (souris : glisser, molette ; manette : stick droit). Une seule page : aperçu à gauche, choix à droite, boutons en pied.
## S'ouvre seule une fois (compte neuf après l'accueil, ancien compte pré-rempli : « Garder tel quel »), puis depuis
## Héros > « Personnage ». Changer est gratuit ; les apparences débloquées (tenues) restent réglées dans Héros > Apparence.
## Règles : HeroLook. Échap : comme « Garder tel quel » / « Annuler » (rien n'est changé).

signal finished(applied: bool)

const LAYER := 44
const SWATCH := Vector2(40, 40)

## Premier passage (ouvert de lui-même) : « Garder tel quel » au lieu d'« Annuler », pas de confirmation.
var first_time := false
var preview: EquipmentPage.HeroPreview
var name_edit: LineEdit
var error_label: Label
var ok_button: Button
var keep_button: Button
var random_button: Button
var reset_button: Button
var _look := {}
var _class := ""
var _classes: Array = []
var _class_label: Label
var _class_row: Control
var _hair_label: Label
var _hair_color_label: Label
var _eye_label: Label
var _hair_swatches := {}  # id -> Button
var _eye_swatches := {}
var _page: Control
var _col: VBoxContainer
var _start := {}  # état à l'ouverture (changements ?)
var _hint: Label


func _init(first := false) -> void:
	super("Ton personnage", LAYER)
	first_time = first


func _ready() -> void:
	super()
	_class = Run.class_id if Profile.in_run else Profile.selected_class
	_classes = GameData.classes.keys().filter(func(c): return Progression.class_unlocked(String(c)))
	_look = HeroLook.current()
	_page = _build()
	add_page("Personnage", _page)
	set_title("Ton personnage", "Ton nom et ton visage.")
	name_edit.text = Profile.hero_name if Profile.hero_name != "" else (HeroLook.random_name() if first_time else "")
	_start = _state()
	open(0)
	_sync()
	get_viewport().size_changed.connect(_fit)
	_fit()


func _state() -> Dictionary:
	return {"name": HeroLook.tidy(name_edit.text), "look": HeroLook.sanitize(_look), "class": _class}


## Quelque chose a-t-il changé depuis l'ouverture ?
func changed_since_open() -> bool:
	var s := _state()
	return s.name != _start.name or str(s.look) != str(_start.look) or s["class"] != _start["class"]


func _build() -> Control:
	var root := HBoxContainer.new()
	root.add_theme_constant_override("separation", 18)
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 6)
	root.add_child(left)
	preview = EquipmentPage.HeroPreview.new()
	preview.spin = false
	preview.idle_pose = true
	preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	preview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_child(preview)
	_hint = Hud._label(left, "", 14, UiTheme.MUTED)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_col = VBoxContainer.new()
	_col.add_theme_constant_override("separation", 10)
	root.add_child(_col)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_col.add_child(scroll)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 8)
	scroll.add_child(box)
	# nom
	_heading(box, "Nom")
	var nr := HBoxContainer.new()
	nr.add_theme_constant_override("separation", 8)
	box.add_child(nr)
	name_edit = LineEdit.new()
	name_edit.max_length = HeroLook.NAME_MAX
	name_edit.placeholder_text = "Ton nom"
	name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_edit.custom_minimum_size = Vector2(0, 46)
	name_edit.add_theme_font_override("font", UiTheme.bold_font())
	name_edit.add_theme_font_size_override("font_size", 20)
	name_edit.add_theme_stylebox_override("normal", UiTheme.flat_box(Color(0.05, 0.05, 0.11, 0.95), MenuWidgets.LINE, 1, 10, false))
	name_edit.add_theme_stylebox_override("focus", UiTheme.flat_box(Color(0.07, 0.06, 0.14, 0.98), UiTheme.GOLD, 2, 10, false))
	name_edit.text_changed.connect(func(_t): _check_name())
	name_edit.text_submitted.connect(func(_t): name_edit.release_focus())
	nr.add_child(name_edit)
	var dice := MenuWidgets.glass_button("Au hasard", 15, Vector2(120, 46))
	dice.pressed.connect(func():
		name_edit.text = HeroLook.random_name()
		_check_name())
	nr.add_child(dice)
	error_label = Hud._label(box, "", 14, Color(1.0, 0.55, 0.5))
	error_label.custom_minimum_size = Vector2(0, 20)
	# classe (aperçu ; choisie en validant)
	_class_row = VBoxContainer.new()
	box.add_child(_class_row)
	_heading(_class_row, "Classe")
	_class_label = _stepper(_class_row, _step_class)
	_class_row.visible = _classes.size() > 1 and not Profile.in_run
	# coiffure
	_heading(box, "Coiffure")
	_hair_label = _stepper(box, _step_hair)
	# couleurs
	_hair_color_label = _heading(box, "Cheveux")
	_swatches(box, HeroLook.HAIR_COLORS, _hair_swatches, func(id): _look.hair_color = id)
	_eye_label = _heading(box, "Yeux")
	_swatches(box, HeroLook.EYE_COLORS, _eye_swatches, func(id): _look.eyes = id)
	# pied épinglé
	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 8)
	_col.add_child(foot)
	random_button = MenuWidgets.glass_button("Aléatoire", 15, Vector2(0, 46))
	random_button.pressed.connect(func():
		_look = HeroLook.random_look()
		_sync())
	foot.add_child(random_button)
	reset_button = MenuWidgets.glass_button("Réinitialiser", 15, Vector2(0, 46))
	reset_button.tooltip_text = "Coiffure et couleurs de la classe"
	reset_button.pressed.connect(func():
		_look = HeroLook.sanitize({})
		_sync())
	foot.add_child(reset_button)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	foot.add_child(sp)
	keep_button = MenuWidgets.glass_button("Garder tel quel" if first_time else "Annuler", 15, Vector2(0, 46))
	keep_button.pressed.connect(close_ui)
	foot.add_child(keep_button)
	ok_button = MenuWidgets.gold_button("Valider", 20, Vector2(140, 46))
	ok_button.pressed.connect(validate)
	foot.add_child(ok_button)
	return root


## Colonne de droite plus étroite sous 1500 px de large (tout tient dans 1280 x 720).
func _fit() -> void:
	if _col != null and is_inside_tree():
		_col.custom_minimum_size.x = 560.0 if get_viewport().get_visible_rect().size.x >= 1500.0 else 470.0


func _heading(parent: Control, text: String) -> Label:
	var l := Hud._label(parent, text, 17, UiTheme.GOLD)
	l.add_theme_font_override("font", UiTheme.bold_font())
	return l


## Ligne « ◀ valeur ▶ » ; renvoie l'étiquette de la valeur.
func _stepper(parent: Control, step: Callable) -> Label:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)
	var prev := MenuWidgets.glass_button("◀", 18, Vector2(56, 42))
	prev.pressed.connect(func(): step.call(-1))
	row.add_child(prev)
	var l := Hud._label(row, "", 18, UiTheme.TEXT)
	l.add_theme_font_override("font", UiTheme.bold_font())
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var next := MenuWidgets.glass_button("▶", 18, Vector2(56, 42))
	next.pressed.connect(func(): step.call(1))
	row.add_child(next)
	return l


## Pastilles de couleur : « D'origine » puis une par couleur ; un clic choisit.
func _swatches(parent: Control, colors: Array, store: Dictionary, pick: Callable) -> void:
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 6)
	flow.add_theme_constant_override("v_separation", 6)
	parent.add_child(flow)
	var orig := Button.new()
	orig.text = "D'origine"
	orig.toggle_mode = true
	orig.focus_mode = Control.FOCUS_NONE
	orig.custom_minimum_size = Vector2(0, SWATCH.y)
	orig.add_theme_font_size_override("font_size", 14)
	orig.tooltip_text = "La couleur de la classe"
	_swatch_style(orig, Color(0.08, 0.08, 0.16))
	orig.pressed.connect(func():
		pick.call("")
		_sync())
	flow.add_child(orig)
	store[""] = orig
	for c in colors:
		var id := String(c[0])
		var b := Button.new()
		b.toggle_mode = true
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = SWATCH
		b.tooltip_text = String(c[1])
		_swatch_style(b, Color8(int(c[2][0]), int(c[2][1]), int(c[2][2])))
		b.pressed.connect(func():
			pick.call(id)
			_sync())
		flow.add_child(b)
		store[id] = b


func _swatch_style(b: Button, col: Color) -> void:
	b.add_theme_stylebox_override("normal", UiTheme.flat_box(col, Color(1, 1, 1, 0.25), 1, 8, false))
	b.add_theme_stylebox_override("hover", UiTheme.flat_box(col.lightened(0.12), UiTheme.GOLD_DIM, 2, 8, false))
	# choisie : anneau blanc hors de la pastille et halo doré (lisible même sur les couleurs claires)
	var on := UiTheme.flat_box(col, Color.WHITE, 3, 9, false)
	on.set_expand_margin_all(3)
	on.shadow_color = Color(UiTheme.GOLD, 0.8)
	on.shadow_size = 5
	b.add_theme_stylebox_override("pressed", on)
	b.add_theme_stylebox_override("hover_pressed", on)


func _step_class(d: int) -> void:
	if _classes.is_empty():
		return
	var i := _classes.find(_class)
	_class = String(_classes[wrapi((i if i >= 0 else 0) + d, 0, _classes.size())])
	_sync()


func _step_hair(d: int) -> void:
	var ids: Array = [""] + HeroLook.HAIRS.map(func(x): return String(x[0]))
	var i := ids.find(String(_look.get("hair", "")))
	_look.hair = String(ids[wrapi((i if i >= 0 else 0) + d, 0, ids.size())])
	_sync()


## Remet l'écran d'accord avec le choix courant (étiquettes, pastilles, aperçu).
func _sync() -> void:
	_look = HeroLook.sanitize(_look)
	_class_label.text = String(GameData.class_data(_class).get("name_fr", _class))
	_hair_label.text = HeroLook.hair_name(_look.hair)
	_hair_color_label.text = "Cheveux · %s" % HeroLook.hair_color_name(_look.hair_color)
	_eye_label.text = "Yeux · %s" % HeroLook.eye_name(_look.eyes)
	for id in _hair_swatches:
		_hair_swatches[id].set_pressed_no_signal(id == _look.hair_color)
	for id in _eye_swatches:
		_eye_swatches[id].set_pressed_no_signal(id == _look.eyes)
	_hint.text = "Stick droit pour tourner" if Gamepad.active else "Glisse pour tourner, molette pour zoomer"
	preview.look_override = _look.duplicate()
	preview.show_hero(_class, Profile.weapon_code() if _class == Profile.selected_class else "")
	_check_name()


## Message sous le nom ; le bouton Valider n'est actif qu'avec un nom valable.
func _check_name() -> bool:
	var err := HeroLook.name_error(name_edit.text)
	error_label.text = err if HeroLook.tidy(name_edit.text) != "" else ""
	ok_button.disabled = err != ""
	return err == ""


## Cadrage : le héros en buste, de face (visage et coiffure lisibles).
func _frame_preview() -> void:
	preview.frame(3.7, 1.15, -0.5)


func open(i := -1) -> void:
	super(i)
	if preview != null:
		_frame_preview()


func _process(delta: float) -> void:
	if not is_open() or preview == null:
		return
	var x := Input.get_joy_axis(0, JOY_AXIS_RIGHT_X)
	if absf(x) > 0.2:
		preview.turn(x * delta * 3.0)


## Valider : nom et visage enregistrés (et la classe montrée choisie) ; plus tard, une petite confirmation.
func validate() -> void:
	if not _check_name():
		return
	if first_time or not changed_since_open():
		_apply()
		return
	InfoCard.ask(self, "Garder ces changements ?", "C'est gratuit : tu pourras les refaire quand tu veux.", "Valider", _apply, false)


func _apply() -> void:
	HeroLook.save(name_edit.text, _look)
	if _class != Profile.selected_class and not Profile.in_run and Progression.class_unlocked(_class):
		Profile.selected_class = _class
		Profile.save_profile()
	_done(true)


## Fermer, Échap, « Garder tel quel » ou « Annuler » : rien ne change (au premier passage, l'écran ne se rouvrira plus seul).
func close_ui() -> void:
	if not is_open():
		return
	if first_time:
		HeroLook.skip()
	_done(false)


func _done(applied: bool) -> void:
	super.close_ui()
	finished.emit(applied)
	queue_free()


## Ouvre l'écran par-dessus [param parent] ; [param on_done] reçoit true si le joueur a validé.
static func open_on(parent: Node, first := false, on_done: Callable = Callable()) -> HeroCreator:
	var c := HeroCreator.new(first)
	if on_done.is_valid():
		c.finished.connect(on_done)
	parent.add_child(c)
	return c
