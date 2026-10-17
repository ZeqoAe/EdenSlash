class_name NetPanel
extends Control
## Fenêtre « Jouer ensemble » du Mode amis (lot NET-A) : papier autocollant (DA v2) au centre de l'arène d'essai.
## Trois états : menu (héros, Héberger, Rejoindre une adresse), connexion en cours (Annuler), et en partie (Échap :
## adresses à donner, joueurs, Reprendre, Quitter la partie). Le jeu ne se met jamais en pause (réseau).

signal host_pressed(port: int)
signal join_pressed(address: String)
signal cancel_pressed
signal back_pressed
signal resume_pressed
signal quit_pressed

const W := 700.0

var cid := "warrior"
var classes: Array = []  # ids des classes, par nom
var state := ""
var _body: VBoxContainer
var _title: Label
var _status: Label
var _addr: LineEdit
var _class_label: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(UiTheme.INK, 0.28)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	var cc := CenterContainer.new()
	cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(cc)
	var p := PanelContainer.new()
	UiTheme.paper(p, 7, Vector2(26, 20))
	p.custom_minimum_size = Vector2(W, 0)
	cc.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	p.add_child(v)
	_title = Label.new()
	UiTheme.title(_title, 30)
	_title.set_meta("ink_keep", true)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_title)
	var orn := MenuWidgets.Ornament.new()
	orn.custom_minimum_size = Vector2(420, 12)
	orn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(orn)
	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", 12)
	v.add_child(_body)
	_status = Hud._label(v, "", 16, UiTheme.MUTED)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.custom_minimum_size = Vector2(W - 60, 0)
	for id in GameData.classes:
		classes.append(String(id))
	classes.sort_custom(func(a, b): return _cname(a).naturalnocasecmp_to(_cname(b)) < 0)


static func _cname(id: String) -> String:
	return String(GameData.class_data(id).get("name_fr", id))


func _clear() -> void:
	for c in _body.get_children():
		_body.remove_child(c)
		c.queue_free()
	_addr = null
	_class_label = null


func set_status(text: String, bad := false) -> void:
	_status.text = text
	_status.add_theme_color_override("font_color", UiTheme.DEBUFF if bad else UiTheme.MUTED)
	_status.visible = text != ""


## Menu : héros, Héberger, Rejoindre.
func show_menu(status := "", bad := false) -> void:
	state = "menu"
	visible = true
	_clear()
	_title.text = "Jouer ensemble"
	var intro := Hud._label(_body, "Une arène d'essai pour vous voir jouer. Rien n'est gagné ni perdu, ta sauvegarde n'est pas touchée.", 16, UiTheme.TEXT)
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	intro.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	intro.custom_minimum_size = Vector2(W - 60, 0)
	# héros
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	_body.add_child(row)
	Hud._label(row, "Ton héros", 18, UiTheme.TEXT)
	var prev := MenuWidgets.paper_button("◀", 18, Vector2(52, 46))
	prev.pressed.connect(_step_class.bind(-1))
	row.add_child(prev)
	_class_label = Hud._label(row, _cname(cid), 20, UiTheme.GOLD)
	_class_label.custom_minimum_size = Vector2(230, 0)
	_class_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var next := MenuWidgets.paper_button("▶", 18, Vector2(52, 46))
	next.pressed.connect(_step_class.bind(1))
	row.add_child(next)
	# héberger
	var host := MenuWidgets.gold_button("Héberger", 24, Vector2(380, 62))
	host.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	host.pressed.connect(func(): host_pressed.emit(int(Settings.get_v("net", "port"))))
	_body.add_child(host)
	var hint := Hud._label(_body, "Tu héberges : tes amis te rejoignent avec ton adresse (affichée ensuite).", 14, UiTheme.MUTED)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# rejoindre
	var jr := HBoxContainer.new()
	jr.alignment = BoxContainer.ALIGNMENT_CENTER
	jr.add_theme_constant_override("separation", 10)
	_body.add_child(jr)
	_addr = LineEdit.new()
	_addr.placeholder_text = "Adresse de l'hôte (ex. 100.64.0.7)"
	_addr.text = String(Settings.get_v("net", "join"))
	_addr.custom_minimum_size = Vector2(380, 50)
	_addr.add_theme_font_size_override("font_size", 18)
	_addr.text_submitted.connect(func(_t): _join())
	jr.add_child(_addr)
	var join := MenuWidgets.paper_button("Rejoindre", 20, Vector2(190, 50))
	join.pressed.connect(_join)
	jr.add_child(join)
	var back := MenuWidgets.paper_button("Retour", 18, Vector2(200, 46))
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back.pressed.connect(func(): back_pressed.emit())
	_body.add_child(back)
	set_status(status, bad)


func _step_class(d: int) -> void:
	var i := classes.find(cid)
	cid = String(classes[wrapi(i + d, 0, classes.size())])
	if _class_label:
		_class_label.text = _cname(cid)


func _join() -> void:
	var t := _addr.text.strip_edges() if _addr else ""
	if t == "":
		set_status("Écris l'adresse que ton ami t'a donnée.", true)
		return
	join_pressed.emit(t)


## Connexion en cours.
func show_connecting(text: String) -> void:
	state = "connecting"
	visible = true
	_clear()
	_title.text = "Connexion"
	var l := Hud._label(_body, text, 18, UiTheme.TEXT)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var b := MenuWidgets.paper_button("Annuler", 18, Vector2(200, 46))
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.pressed.connect(func(): cancel_pressed.emit())
	_body.add_child(b)
	set_status("")


## En partie (Échap) : [param lines] = textes d'information (adresses, joueurs).
func show_game(title: String, lines: Array) -> void:
	state = "game"
	visible = true
	_clear()
	_title.text = title
	for t in lines:
		var l := Hud._label(_body, String(t), 17, UiTheme.TEXT)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(W - 60, 0)
	var resume := MenuWidgets.gold_button("Reprendre", 22, Vector2(320, 58))
	resume.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	resume.pressed.connect(func(): resume_pressed.emit())
	_body.add_child(resume)
	var quit := MenuWidgets.paper_button("Quitter la partie", 18, Vector2(320, 48))
	quit.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	quit.pressed.connect(func(): quit_pressed.emit())
	_body.add_child(quit)
	set_status("Le jeu continue pendant que ce menu est ouvert.")


func hide_panel() -> void:
	visible = false
	state = "hidden"
