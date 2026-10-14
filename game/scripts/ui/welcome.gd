class_name Welcome
extends CanvasLayer
## Accueil d'une nouvelle partie (lot 9) : trois façons de commencer, le choix de la classe parmi les
## 5 classes de base, puis le style de contrôle et le niveau d'aide au combat. Ne verrouille rien :
## les 5 classes restent ouvertes, tout se change ensuite dans les Paramètres.

signal finished(warmup: bool)

const CLASS_TEXT := {
	"warrior": "Mêlée, hache : encaisse et frappe en zone. Le plus simple pour débuter.",
	"thief": "Mêlée rapide, dagues : esquive, critiques et élimination.",
	"hunter": "Distance, arc : tire de loin, perce et touche en zone.",
	"cleric": "Soutien, sceptre : soins, sorts sacrés et défense.",
	"magician": "Distance, bâton : de gros sorts de zone, fragile au contact.",
}
const CONTROLS := [
	["classic", "Clavier + souris", "ZQSD pour bouger, clic pour attaquer, sorts au clavier."],
	["arpg", "Souris seule", "Clic pour se déplacer et attaquer, sorts au clavier vers la souris."],
	["classic", "Manette", "Branche la manette : les boutons s'affichent à l'écran."],
]
const AIDS := [["manual", "Aucune"], ["assisted", "Assistée (conseillé)"], ["relax", "Sorts auto"]]

var _root: Control
var _box: VBoxContainer
var _mode := "guided"
var _warmup := false
var _class := "warrior"
var _control_i := 0
var _aid := "assisted"


func _ready() -> void:
	layer = 45
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.01, 0.05, 0.88)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", Hud.style(Color(0.08, 0.07, 0.14, 0.98)))
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-460, -270)
	panel.custom_minimum_size = Vector2(920, 540)
	_root.add_child(panel)
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 14)
	panel.add_child(_box)
	_step_welcome()


func _reset(title: String, sub: String) -> void:
	for c in _box.get_children():
		c.queue_free()
	var t := Hud._label(_box, title, 34, UiTheme.GOLD)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var s := Hud._label(_box, sub, 16, UiTheme.MUTED)
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	s.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


func _big_button(text: String, sub: String, cb: Callable) -> Button:
	var b := MenuWidgets.glass_button("%s\n%s" % [text, sub], 18, Vector2(0, 76))
	b.pressed.connect(cb)
	_box.add_child(b)
	return b


func _step_welcome() -> void:
	_reset("Bienvenue dans Eden Slash", "Comment veux-tu commencer ?")
	_big_button("Je découvre Eden Slash", "Conseils et « Premiers pas » dans ta première Survie", func():
		_mode = "guided"
		_step_class())
	_big_button("Je m'échauffe d'abord", "Zone d'entraînement : essaie ton héros sans enjeu, puis les Premiers pas", func():
		_mode = "guided"
		_warmup = true
		_step_class())
	_big_button("Je connais déjà", "Aucun tutoriel ; le Guide (F1) garde toutes les règles", func():
		_mode = "skip"
		_step_class())


func _step_class() -> void:
	_reset("Choisis ta classe", "Les 5 classes restent ouvertes : ce choix dit seulement avec laquelle tu commences. Les autres se gagnent à la maîtrise.")
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_box.add_child(row)
	for cid in Progression.START_CLASSES:
		var cd := GameData.class_data(cid)
		var b := Button.new()
		b.custom_minimum_size = Vector2(168, 280)
		b.focus_mode = Control.FOCUS_NONE
		b.toggle_mode = true
		b.button_pressed = cid == _class
		var v := VBoxContainer.new()
		v.set_anchors_preset(Control.PRESET_FULL_RECT)
		v.offset_left = 8
		v.offset_right = -8
		v.offset_top = 8
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(v)
		var ic := TextureRect.new()
		ic.texture = UiTheme.texture(String(cd.get("icon", "")))
		ic.custom_minimum_size = Vector2(0, 96)
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(ic)
		var n := Hud._label(v, String(cd.get("name_fr", cid)), 20, UiTheme.GOLD)
		n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var d := Hud._label(v, String(CLASS_TEXT.get(cid, "")), 13, Color.WHITE)
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		d.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.pressed.connect(func():
			_class = cid
			_step_class())
		row.add_child(b)
	var next := MenuWidgets.gold_button("Continuer", 20, Vector2(0, 52))
	next.pressed.connect(_step_controls)
	_box.add_child(next)


func _step_controls() -> void:
	_reset("Contrôles et aide", "Tout se change ensuite dans Échap > Paramètres. L'aide n'enlève aucune récompense en JcE.")
	Hud._label(_box, "Style de contrôle", 18, UiTheme.GOLD)
	var r1 := HBoxContainer.new()
	r1.add_theme_constant_override("separation", 10)
	_box.add_child(r1)
	for i in CONTROLS.size():
		var b := MenuWidgets.glass_button("%s\n%s" % [CONTROLS[i][1], CONTROLS[i][2]], 15, Vector2(0, 84))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if i == _control_i:
			b.text = "✔  " + b.text
		var idx := i
		b.pressed.connect(func():
			_control_i = idx
			_step_controls())
		r1.add_child(b)
	Hud._label(_box, "Aide au combat", 18, UiTheme.GOLD)
	var r2 := HBoxContainer.new()
	r2.add_theme_constant_override("separation", 10)
	_box.add_child(r2)
	for a in AIDS:
		var b := MenuWidgets.glass_button(("✔  " if a[0] == _aid else "") + String(a[1]), 16, Vector2(0, 56))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var id := String(a[0])
		b.tooltip_text = String(Settings.ASSIST[id].desc)
		b.pressed.connect(func():
			_aid = id
			_step_controls())
		r2.add_child(b)
	Hud._label(_box, String(Settings.ASSIST[_aid].desc), 14, UiTheme.MUTED).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_box.add_child(spacer)
	var go := MenuWidgets.gold_button("C'est parti", 22, Vector2(0, 58))
	go.pressed.connect(finish)
	_box.add_child(go)


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
