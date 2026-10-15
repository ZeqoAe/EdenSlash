class_name Welcome
extends CanvasLayer
## Accueil d'une nouvelle partie : trois écrans courts. 1) comment commencer (tutoriel complet, échauffement
## ou rien), 2) la classe parmi les 5 de départ, 3) le style de contrôle et l'aide au combat. Ne verrouille
## rien : tout se change ensuite dans les Paramètres. Le panneau s'adapte à la taille de la fenêtre
## (défilement et bouton d'action épinglé en bas), jamais coupé.

signal finished(warmup: bool)

## Classe -> [rôle, phrase].
const CLASS_TEXT := {
	"warrior": ["Mêlée · hache", "Encaisse et frappe en zone. Le plus simple pour débuter."],
	"thief": ["Mêlée · dagues", "Rapide : esquive, critiques et élimination."],
	"hunter": ["Distance · arc", "Tire de loin, perce et touche en zone."],
	"cleric": ["Soutien · sceptre", "Soins, sorts sacrés et défense."],
	"magician": ["Distance · bâton", "De gros sorts de zone, mais fragile au contact."],
}
## Préréglage de `Settings.apply_preset`, nom, phrase ({keys} = les touches de déplacement du joueur).
const CONTROLS := [
	["classic", "Clavier + souris", "{keys} pour bouger, clic pour attaquer, sorts au clavier."],
	["arpg", "Souris seule", "Clic pour bouger et attaquer, sorts au clavier."],
	["classic", "Manette", "Branche-la : les boutons s'affichent à l'écran."],
]
## Niveau d'aide (`Settings.ASSIST`), phrase.
const AIDS := [
	["manual", "Tu fais tout à la main."],
	["assisted", "Les appuis trop tôt sont gardés, l'annulation parfaite est annoncée."],
	["relax", "Les attaques et les sorts partent seuls. Tu bouges et tu esquives."],
]
const MAX_W := 1040.0
const MAX_H := 640.0

var _root: Control
var _panel: PanelContainer
var _title: Label
var _sub: Label
var _body: VBoxContainer
var _dots: Array[Panel] = []
var _back: Button
var _next: Button
var _foot_gap: Control
var _foot_gap2: Control
var _next_cb: Callable
var _step := 1
var _mode := "guided"
var _warmup := false
var _class := "warrior"
var _control_i := 0
var _aid := "assisted"
var _class_cards := {}
var _control_cards: Array = []
var _aid_cards := {}


func _ready() -> void:
	layer = 45
	process_mode = Node.PROCESS_MODE_ALWAYS
	_control_i = 2 if Gamepad.active else 0
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.01, 0.05, 0.9)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(cc)
	_panel = PanelContainer.new()
	var sb := MenuWidgets.glass(16, UiTheme.GOLD_DIM, 0.97)
	sb.set_content_margin_all(24)
	_panel.add_theme_stylebox_override("panel", sb)
	cc.add_child(_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	_panel.add_child(box)
	_title = Label.new()
	UiTheme.title(_title, 34)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_title)
	_sub = Hud._label(box, "", 16, UiTheme.MUTED)
	_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	_body = VBoxContainer.new()
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override("separation", 12)
	scroll.add_child(_body)
	# pied épinglé : Retour, les trois points, bouton d'action
	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 12)
	box.add_child(foot)
	_back = MenuWidgets.glass_button("Retour", 18, Vector2(230, 50))
	_back.pressed.connect(_go_back)
	foot.add_child(_back)
	var mid := HBoxContainer.new()
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.alignment = BoxContainer.ALIGNMENT_CENTER
	mid.add_theme_constant_override("separation", 10)
	foot.add_child(mid)
	for i in 3:
		var d := Panel.new()
		d.custom_minimum_size = Vector2(12, 12)
		d.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		mid.add_child(d)
		_dots.append(d)
	_next = MenuWidgets.gold_button("Continuer", 20, Vector2(230, 50))
	foot.add_child(_next)
	_foot_gap = Control.new()  # garde la place des boutons à l'écran 1 : les points restent au centre
	_foot_gap.custom_minimum_size = Vector2(230, 50)
	foot.add_child(_foot_gap)
	foot.move_child(_foot_gap, 0)
	_foot_gap2 = Control.new()
	_foot_gap2.custom_minimum_size = Vector2(230, 50)
	foot.add_child(_foot_gap2)
	get_viewport().size_changed.connect(_fit)
	_fit()
	_step_welcome()


## Taille du panneau : toute la fenêtre moins une marge, jusqu'à MAX_W x MAX_H.
func _fit() -> void:
	var vp := get_viewport().get_visible_rect().size
	_panel.custom_minimum_size = Vector2(clampf(vp.x - 48.0, 420.0, MAX_W), clampf(vp.y - 40.0, 340.0, MAX_H))


## Deux colonnes côte à côte si le panneau est assez large, sinon l'une sous l'autre.
func _wide() -> bool:
	return _panel.custom_minimum_size.x >= 900.0


func _reset(step: int, title: String, sub: String) -> void:
	_step = step
	for c in _body.get_children():
		_body.remove_child(c)
		c.queue_free()
	_title.text = title
	_sub.text = sub
	_sub.visible = sub != ""
	for i in _dots.size():
		_dots[i].add_theme_stylebox_override("panel", UiTheme.flat_box(UiTheme.GOLD if i == step - 1 else Color(0.3, 0.28, 0.4), Color(0, 0, 0, 0), 0, 6, false))
	_back.visible = step > 1
	_next.visible = step > 1
	_foot_gap.visible = step == 1
	_foot_gap2.visible = step == 1
	if _next_cb.is_valid() and _next.pressed.is_connected(_next_cb):
		_next.pressed.disconnect(_next_cb)


func _go_back() -> void:
	if _step == 3:
		_step_class()
	elif _step == 2:
		_step_welcome()


# --- écran 1 : comment commencer -----------------------------------------------------------
func _step_welcome() -> void:
	_reset(1, "Bienvenue dans Eden Slash", "Comment veux-tu commencer ?")
	_body.alignment = BoxContainer.ALIGNMENT_CENTER
	var starts := [
		["Je découvre", "Conseils et Premiers pas dans ta première Survie.", "new", "guided", false],
		["Je m'échauffe d'abord", "Un tour en zone d'entraînement, sans enjeu, puis les Premiers pas.", "attack", "guided", true],
		["Je connais déjà", "Aucun conseil. Le Guide garde toutes les règles.", "continue", "skip", false],
	]
	for s in starts:
		var row := MenuWidgets.RowButton.new(String(s[0]), String(s[1]), String(s[2]), 92)
		row.pressed.connect(func():
			_mode = String(s[3])
			_warmup = bool(s[4])
			_step_class())
		_body.add_child(row)


# --- écran 2 : la classe -------------------------------------------------------------------
func _step_class() -> void:
	_reset(2, "Choisis ta classe", "Les autres classes se débloquent en jouant.")
	_body.alignment = BoxContainer.ALIGNMENT_BEGIN
	_class_cards.clear()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body.add_child(row)
	for cid in Progression.START_CLASSES:
		var card := ClassCard.new(cid)
		card.set_pressed_no_signal(cid == _class)
		card.pressed.connect(func():
			_class = cid
			_mark(_class_cards, cid))
		row.add_child(card)
		_class_cards[cid] = card
	_next.text = "Continuer"
	_next_cb = _step_controls
	_next.pressed.connect(_next_cb)


# --- écran 3 : contrôles et aide -----------------------------------------------------------
func _step_controls() -> void:
	_reset(3, "Comment joues-tu ?", "")
	_body.alignment = BoxContainer.ALIGNMENT_CENTER
	_control_cards.clear()
	_aid_cards.clear()
	var holder: BoxContainer = HBoxContainer.new() if _wide() else VBoxContainer.new()
	holder.add_theme_constant_override("separation", 22)
	_body.add_child(holder)
	var left := _column(holder, "Contrôles")
	for i in CONTROLS.size():
		var c := OptionCard.new(String(CONTROLS[i][1]), String(CONTROLS[i][2]).replace("{keys}", _keys()))
		c.set_pressed_no_signal(i == _control_i)
		var idx := i
		c.pressed.connect(func():
			_control_i = idx
			for k in _control_cards.size():
				_control_cards[k].set_pressed_no_signal(k == idx))
		left.add_child(c)
		_control_cards.append(c)
	var right := _column(holder, "Aide au combat")
	for a in AIDS:
		var id := String(a[0])
		var c := OptionCard.new(String(Settings.ASSIST[id].name), String(a[1]), "Conseillé" if id == "assisted" else "")
		c.set_pressed_no_signal(id == _aid)
		c.pressed.connect(func():
			_aid = id
			_mark(_aid_cards, id))
		right.add_child(c)
		_aid_cards[id] = c
	_next.text = "C'est parti"
	_next_cb = finish
	_next.pressed.connect(_next_cb)


func _column(parent: Control, heading: String) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(v)
	var h := Hud._label(v, heading, 20, UiTheme.GOLD)
	h.add_theme_font_override("font", UiTheme.bold_font())
	return v


## Touches de déplacement du joueur (« ZQSD »), lues dans ses réglages.
func _keys() -> String:
	var out := ""
	for a in ["move_forward", "move_left", "move_back", "move_right"]:
		var ev: Array = Settings.binds.get(a, [])
		out += Settings.event_label(ev[0]) if not ev.is_empty() else ""
	return out if out != "" else "Les touches"


## Un seul choix à la fois dans une série de cartes (par identifiant).
func _mark(cards: Dictionary, chosen: String) -> void:
	for id in cards:
		cards[id].set_pressed_no_signal(id == chosen)


## Carte à choix : titre, étiquette facultative, phrase, coche quand elle est choisie.
class OptionCard extends Button:
	var _content: HBoxContainer
	var _base_h := 72.0

	func _init(title_text: String, desc: String, tag := "") -> void:
		toggle_mode = true
		focus_mode = Control.FOCUS_NONE
		custom_minimum_size = Vector2(0, _base_h)
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var off := UiTheme.flat_box(Color(0.07, 0.08, 0.17, 0.9), MenuWidgets.LINE, 1, 10, false)
		var hot := UiTheme.flat_box(Color(0.13, 0.12, 0.26, 0.96), UiTheme.GOLD_DIM, 2, 10, false)
		var on := UiTheme.flat_box(Color(0.17, 0.13, 0.26, 0.98), UiTheme.GOLD, 2, 10, false)
		add_theme_stylebox_override("normal", off)
		add_theme_stylebox_override("hover", hot)
		add_theme_stylebox_override("pressed", on)
		add_theme_stylebox_override("hover_pressed", on)
		_content = HBoxContainer.new()
		_content.set_anchors_preset(Control.PRESET_FULL_RECT)
		_content.offset_left = 16
		_content.offset_right = -16
		_content.add_theme_constant_override("separation", 12)
		_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_content.minimum_size_changed.connect(_fit)
		add_child(_content)
		var v := VBoxContainer.new()
		v.alignment = BoxContainer.ALIGNMENT_CENTER
		v.add_theme_constant_override("separation", 0)
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_content.add_child(v)
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 10)
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(line)
		var t := Hud._label(line, title_text, 18, UiTheme.TEXT)
		t.add_theme_font_override("font", UiTheme.bold_font())
		if tag != "":
			Hud._label(line, tag, 14, UiTheme.GOLD)
		var d := Hud._label(v, desc, 14, UiTheme.MUTED)
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		d.custom_minimum_size.x = 120.0
		var check := Tick.new()
		_content.add_child(check)
		check.visible = button_pressed
		toggled.connect(func(on_: bool): check.visible = on_)
		# set_pressed_no_signal ne prévient pas : la coche suit l'état à chaque redessin
		draw.connect(func(): check.visible = button_pressed)

	func _fit() -> void:
		var want := maxf(_base_h, _content.get_combined_minimum_size().y + 20.0)
		if absf(custom_minimum_size.y - want) > 0.5:
			custom_minimum_size.y = want


## Coche dorée dessinée (la police de symboles la colorerait à sa façon).
class Tick extends Control:
	func _init() -> void:
		custom_minimum_size = Vector2(26, 26)
		size_flags_vertical = Control.SIZE_SHRINK_CENTER
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		draw_polyline(PackedVector2Array([Vector2(3, 14), Vector2(10, 21), Vector2(23, 5)]), UiTheme.GOLD, 3.5, true)


## Carte verticale d'une classe de départ : portrait, nom, rôle, phrase.
class ClassCard extends Button:
	func _init(cid: String) -> void:
		toggle_mode = true
		focus_mode = Control.FOCUS_NONE
		custom_minimum_size = Vector2(112, 380)
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
		size_flags_vertical = Control.SIZE_EXPAND_FILL
		var off := UiTheme.flat_box(Color(0.07, 0.08, 0.17, 0.9), MenuWidgets.LINE, 1, 12, false)
		var hot := UiTheme.flat_box(Color(0.13, 0.12, 0.26, 0.96), UiTheme.GOLD_DIM, 2, 12, false)
		var on := UiTheme.flat_box(Color(0.17, 0.13, 0.26, 0.98), UiTheme.GOLD, 3, 12, false)
		add_theme_stylebox_override("normal", off)
		add_theme_stylebox_override("hover", hot)
		add_theme_stylebox_override("pressed", on)
		add_theme_stylebox_override("hover_pressed", on)
		var cd := GameData.class_data(cid)
		var v := VBoxContainer.new()
		v.set_anchors_preset(Control.PRESET_FULL_RECT)
		v.offset_left = 10
		v.offset_right = -10
		v.offset_top = 12
		v.offset_bottom = -10
		v.add_theme_constant_override("separation", 4)
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(v)
		var ic := TextureRect.new()
		ic.texture = UiTheme.texture(String(cd.get("icon", "")))
		ic.custom_minimum_size = Vector2(0, 116)
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(ic)
		var n := Hud._label(v, String(cd.get("name_fr", cid)), 22, UiTheme.GOLD)
		n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var text: Array = CLASS_TEXT.get(cid, ["", ""])
		var r := Hud._label(v, String(text[0]), 14, UiTheme.TEXT)
		r.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		r.add_theme_font_override("font", UiTheme.bold_font())
		var d := Hud._label(v, String(text[1]), 14, UiTheme.MUTED)
		d.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		d.custom_minimum_size.x = 80.0
		# les trois sorts de départ
		var sep := ColorRect.new()
		sep.color = Color(UiTheme.GOLD_DIM, 0.5)
		sep.custom_minimum_size = Vector2(0, 1)
		sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(sep)
		var skills: Array = cd.get("skills", [])
		for k in mini(int(cd.get("start_skills", 3)), skills.size()):
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 8)
			row.mouse_filter = Control.MOUSE_FILTER_IGNORE
			v.add_child(row)
			var si := TextureRect.new()
			si.texture = UiTheme.texture(String(skills[k].get("icon", "")))
			si.custom_minimum_size = Vector2(30, 30)
			si.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			si.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			si.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			si.mouse_filter = Control.MOUSE_FILTER_IGNORE
			row.add_child(si)
			var sn := Hud._label(row, String(skills[k].get("name", "")), 14, UiTheme.TEXT)
			sn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			sn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			sn.custom_minimum_size.x = 40.0


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
		_go_back()
		get_viewport().set_input_as_handled()


## Applique les choix (classe, contrôles, aide, tutoriel) et ferme l'accueil.
func finish() -> void:
	Profile.selected_class = _class
	Settings.apply_preset(String(CONTROLS[_control_i][0]))
	Settings.set_assist(_aid)
	Tutorial.set_mode(_mode)
	Profile.tutorial["version"] = Version.NUMBER
	Profile.save_profile()
	finished.emit(_warmup)
	queue_free()
