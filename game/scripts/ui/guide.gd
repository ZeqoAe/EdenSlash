class_name Guide
extends CanvasLayer
## Guide (F1, menu pause, lobby) : les commandes réelles du joueur, les Premiers pas, toutes les
## fiches de découverte et les nouveautés, relisibles à tout moment. En jeu il met la partie en pause.

signal closed

var _list: ItemList
var _body: RichTextLabel
var _ids: Array = []
var _paused_before := false
var _was_open := false


static func open_on(parent: Node, chapter := "") -> Guide:
	for n in parent.get_children():
		if n is Guide:
			(n as Guide).select(chapter)
			return n
	var g := Guide.new()
	parent.add_child(g)
	g.build()
	g.select(chapter)
	return g


## Ferme le Guide s'il est ouvert (touche F1 qui rappuie) ; renvoie vrai s'il l'était.
static func close_in(parent: Node) -> bool:
	for n in parent.get_children():
		if n is Guide:
			(n as Guide).close()
			return true
	return false


func build() -> void:
	layer = 40
	process_mode = Node.PROCESS_MODE_ALWAYS
	_paused_before = get_tree().paused
	get_tree().paused = true
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.01, 0.05, 0.78)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", Hud.style(Color(0.08, 0.07, 0.14, 0.98)))
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-520, -330)
	panel.custom_minimum_size = Vector2(1040, 660)
	root.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	panel.add_child(v)
	var head := HBoxContainer.new()
	v.add_child(head)
	var t := Hud._label(head, "Guide", 30, UiTheme.GOLD)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var x := Button.new()
	x.text = "Fermer  (%s)" % Settings.action_label("help", 1)
	x.focus_mode = Control.FOCUS_NONE
	x.pressed.connect(close)
	head.add_child(x)
	var row := HBoxContainer.new()
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 14)
	v.add_child(row)
	_list = ItemList.new()
	_list.custom_minimum_size = Vector2(290, 0)
	_list.item_selected.connect(func(i): _show(String(_ids[i])))
	row.add_child(_list)
	_body = RichTextLabel.new()
	_body.bbcode_enabled = true
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_theme_font_size_override("normal_font_size", 17)
	row.add_child(_body)
	_fill()
	_was_open = true


func _fill() -> void:
	_ids = ["commands", "steps"]
	_list.add_item("Commandes")
	_list.add_item("Premiers pas")
	for id in Tutorial.CARDS:
		_ids.append(id)
		_list.add_item(String(Tutorial.CARDS[id].title))
	_ids.append("news")
	_list.add_item("Nouveautés")
	_ids.append("tips")
	_list.add_item("Conseils : couper ou remettre")


func select(chapter: String) -> void:
	var i := _ids.find(chapter) if chapter != "" else 0
	i = maxi(i, 0)
	_list.select(i)
	_show(String(_ids[i]))


func _show(id: String) -> void:
	var txt := ""
	match id:
		"commands":
			txt = TestTools.help_text()
		"steps":
			txt = "[b]Premiers pas[/b]  (%s)\n\n" % Tutorial.progress_text()
			for s in Tutorial.STEPS:
				txt += "%s %s\n" % ["[color=#8fe39a]✔[/color]" if s.id in Tutorial.steps_done() else "[color=#888]·[/color]", Tutorial.step_text(s)]
			txt += "\nIls se valident en jouant, dans ta première Survie. Passer ne bloque ni ne débloque rien."
		"news":
			txt = "[b]Nouveautés[/b] (depuis la version 0.1.131)\n\n"
			for cid in Tutorial.news_since("0.1.131"):
				if Tutorial.CARDS[cid].version <= Version.NUMBER:
					txt += "[b]%s[/b] — %s\n" % [Tutorial.CARDS[cid].title, " ".join(Tutorial.CARDS[cid].lines)]
		"tips":
			var off := bool(Profile.tutorial.get("cards_off", false))
			txt = "Les fiches de découverte s'affichent une seule fois, à la première rencontre.\n\nÉtat : [b]%s[/b]\n\nAppuie sur Entrée pour %s." % [
				"coupées" if off else "actives", "les remettre" if off else "les couper"]
		_:
			var c: Dictionary = Tutorial.CARDS.get(id, {})
			txt = "[b][font_size=24]%s[/font_size][/b]\n\n%s" % [c.get("title", id), "\n".join((c.get("lines", []) as Array).map(func(l): return "• " + String(l)))]
	_body.text = txt


func _unhandled_input(event: InputEvent) -> void:
	if not _was_open:
		return
	if event.is_action_pressed("help") or event.is_action_pressed("pause"):
		close()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and event.keycode == KEY_ENTER and _list.get_selected_items().size() > 0 \
			and String(_ids[_list.get_selected_items()[0]]) == "tips":
		Profile.tutorial["cards_off"] = not bool(Profile.tutorial.get("cards_off", false))
		Profile.save_profile()
		_show("tips")


func close() -> void:
	if not _was_open:
		return
	_was_open = false
	get_tree().paused = _paused_before
	closed.emit()
	queue_free()
