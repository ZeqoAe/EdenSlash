extends CanvasLayer
## Notes du joueur, partout (lobby, menus, run) : Alt + clic droit sur n'importe quoi ouvre une
## petite fenêtre « qu'est-ce qui ne va pas ? ». On enregistre la capture (avec un repère à
## l'endroit du clic), ce qui était sous la souris (objet, apparence, bouton, sort, écran…) et la
## note dans EdenSlash/feedback/<date>/ : la session Claude les lit pour corriger.
## (F9 en run reste le rapport de position pour les problèmes de carte.)

const CATEGORIES := ["Bug", "À changer", "Idée", "Graphisme / modèle", "Équilibrage"]

var _box: PanelContainer
var _target_label: RichTextLabel
var _cat: OptionButton
var _edit: TextEdit
var _toast: Label
var _shot: Image
var _target: PackedStringArray = []
var _mouse := Vector2.ZERO
var _was_paused := false


func _ready() -> void:
	layer = 120
	process_mode = Node.PROCESS_MODE_ALWAYS
	_box = PanelContainer.new()
	_box.add_theme_stylebox_override("panel", UiTheme.flat_box(Color(0.06, 0.05, 0.11, 0.97), UiTheme.GOLD, 2, 12))
	_box.custom_minimum_size = Vector2(620, 0)
	_box.visible = false
	add_child(_box)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	_box.add_child(v)
	var t := Label.new()
	t.text = "Note pour la prochaine version"
	UiTheme.title(t, 20)
	v.add_child(t)
	_target_label = RichTextLabel.new()
	_target_label.bbcode_enabled = true
	_target_label.fit_content = true
	_target_label.scroll_active = false
	_target_label.add_theme_font_size_override("normal_font_size", 13)
	v.add_child(_target_label)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	v.add_child(row)
	var l := Label.new()
	l.text = "Type :"
	row.add_child(l)
	_cat = OptionButton.new()
	for c in CATEGORIES:
		_cat.add_item(c)
	_cat.focus_mode = Control.FOCUS_NONE
	row.add_child(_cat)
	_edit = TextEdit.new()
	_edit.placeholder_text = "Qu'est-ce qui ne va pas, quoi changer ? (ex : les ailes ne sont pas dans le dos, gardent du vert en noir…)"
	_edit.custom_minimum_size = Vector2(0, 120)
	_edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	v.add_child(_edit)
	var btns := HBoxContainer.new()
	btns.add_theme_constant_override("separation", 10)
	btns.alignment = BoxContainer.ALIGNMENT_END
	v.add_child(btns)
	var hint := Label.new()
	hint.text = "Ctrl + Entrée : enregistrer · Échap : annuler"
	hint.add_theme_font_size_override("font_size", 12)
	hint.modulate = Color(1, 1, 1, 0.6)
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btns.add_child(hint)
	var cancel := Button.new()
	cancel.text = "Annuler"
	cancel.focus_mode = Control.FOCUS_NONE
	cancel.pressed.connect(_close)
	btns.add_child(cancel)
	var ok := Button.new()
	ok.text = "Enregistrer la note"
	ok.focus_mode = Control.FOCUS_NONE
	ok.pressed.connect(_save)
	btns.add_child(ok)
	_toast = Label.new()
	_toast.add_theme_font_size_override("font_size", 17)
	_toast.add_theme_constant_override("outline_size", 6)
	_toast.add_theme_color_override("font_outline_color", Color.BLACK)
	_toast.modulate.a = 0.0
	add_child(_toast)


func is_open() -> bool:
	return _box.visible


func _input(event: InputEvent) -> void:
	if _box.visible:
		if event is InputEventKey and event.pressed:
			if event.keycode == KEY_ESCAPE:
				_close()
				get_viewport().set_input_as_handled()
			elif event.keycode in [KEY_ENTER, KEY_KP_ENTER] and event.ctrl_pressed:
				_save()
				get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT and event.alt_pressed:
		get_viewport().set_input_as_handled()
		open_at(event.position)


## Ouvre la fenêtre de note pour ce qui se trouve en [param pos] (coordonnées de l'écran).
func open_at(pos: Vector2) -> void:
	_mouse = pos
	_shot = get_viewport().get_texture().get_image()
	_mark(_shot, pos)
	_target = describe_at(pos)
	_target_label.text = "[color=#c8c8d4]Sous la souris :[/color] [b]%s[/b]%s" % [_target[0] if not _target.is_empty() else "?",
		("\n[color=#9a98a8]%s[/color]" % " · ".join(_target.slice(1, 4))) if _target.size() > 1 else ""]
	_edit.text = ""
	_box.visible = true
	_box.reset_size()
	var vp := get_viewport().get_visible_rect().size
	_box.position = Vector2(clampf(pos.x - _box.size.x * 0.5, 12, vp.x - _box.size.x - 12), clampf(pos.y + 16, 12, vp.y - _box.size.y - 12))
	_edit.grab_focus()
	_was_paused = get_tree().paused
	get_tree().paused = true


func _close() -> void:
	_box.visible = false
	get_tree().paused = _was_paused


## Repère rouge sur la capture à l'endroit du clic.
func _mark(img: Image, pos: Vector2) -> void:
	if img == null:
		return
	var s := Vector2(img.get_size()) / get_viewport().get_visible_rect().size
	var c := Vector2i(pos * s)
	for r in [14, 15, 16]:
		for a in 64:
			var p := c + Vector2i(Vector2.from_angle(TAU * a / 64.0) * r)
			if p.x >= 0 and p.y >= 0 and p.x < img.get_width() and p.y < img.get_height():
				img.set_pixelv(p, Color(1, 0.15, 0.15))


# --- ce qu'il y a sous la souris ---------------------------------------------------------------
## Lignes décrivant la cible : la plus parlante d'abord (méta « report », objet, texte…).
func describe_at(pos: Vector2) -> PackedStringArray:
	var out: PackedStringArray = []
	var c := get_viewport().gui_get_hovered_control()
	var node: Node = c
	var depth := 0
	while node and depth < 10:
		_describe_node(node, out)
		node = node.get_parent()
		depth += 1
	if c == null:
		out.append_array(_describe_world(pos))
	var scene := get_tree().current_scene
	out.append("Écran : %s" % (scene.scene_file_path.get_file().get_basename() if scene else "?"))
	var seen := {}
	var uniq: PackedStringArray = []
	for line in out:
		if line != "" and not seen.has(line):
			seen[line] = true
			uniq.append(line)
	return uniq


func _describe_node(n: Node, out: PackedStringArray) -> void:
	if n.has_meta("report"):
		out.append(String(n.get_meta("report")))
	var it = n.get("item")
	if it is Dictionary and not it.is_empty():
		out.append("Objet : %s (niv. %d, %s, eden %s, +%d)" % [Items.display_name(it), int(it.get("level", 0)), String(it.get("slot", "")),
			str(it.get("eden", "-")), int(it.get("upgrade", 0))])
	var entry = n.get("entry")
	if entry is Dictionary and entry.has("key"):
		out.append("Pile : %s" % String(entry.key))
	if n is Button and String(n.text).strip_edges() != "":
		out.append("Bouton « %s »" % String(n.text).strip_edges().left(80))
	elif n is Label and String(n.text).strip_edges() != "" and out.is_empty():
		out.append("Texte « %s »" % String(n.text).strip_edges().left(80))
	var tip = n.get("tip")
	if tip is String and tip != "":
		out.append("Fiche : %s" % _plain(tip).left(160))
	elif n is Control and n.tooltip_text != "":
		out.append("Infobulle : %s" % n.tooltip_text.left(120))
	var sc: Script = n.get_script()
	if sc and sc.get_global_name() != "":
		out.append("Élément : %s" % sc.get_global_name())


## Hors interface : ce que vise la caméra (monstre, PNJ, décor).
func _describe_world(pos: Vector2) -> PackedStringArray:
	var out: PackedStringArray = []
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return out
	var from := cam.project_ray_origin(pos)
	var q := PhysicsRayQueryParameters3D.create(from, from + cam.project_ray_normal(pos) * 400.0)
	var hit := cam.get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return out
	var n: Node = hit.collider
	var p: Vector3 = hit.position
	while n and not (n.get("display_name") is String) and not n.is_in_group("monsters") and n.get_parent() != get_tree().current_scene:
		n = n.get_parent()
	out.append("Monde : %s (%s) à %.1f, %.1f, %.1f" % [String(n.get("display_name")) if n and n.get("display_name") is String else (n.name if n else "?"),
		n.get_class() if n else "", p.x, p.y, p.z])
	return out


func _plain(bb: String) -> String:
	var r := RegEx.new()
	r.compile("\\[[^\\]]*\\]")
	return r.sub(bb, "", true).replace("\n", " · ")


# --- enregistrement ----------------------------------------------------------------------------
## Dossier des notes : EdenSlash/feedback/ quand on joue depuis le projet ; à côté du jeu
## (dossier feedback/ près de EdenSlash.exe) pour la version exportée à partager.
static func folder() -> String:
	var res := ProjectSettings.globalize_path("res://")
	if res != "" and FileAccess.file_exists(res.path_join("project.godot")):
		return res.path_join("../feedback").simplify_path()
	return OS.get_executable_path().get_base_dir().path_join("feedback")


func _save() -> void:
	var note := _edit.text.strip_edges()
	if note == "":
		_close()
		return
	var stamp := Time.get_datetime_string_from_system().replace(":", "-")
	var dir := folder().path_join(stamp + "_note")
	DirAccess.make_dir_recursive_absolute(dir)
	if _shot:
		_shot.save_png(dir.path_join("capture.png"))
	var report := {
		"note": note,
		"type": CATEGORIES[_cat.selected],
		"cible": Array(_target),
		"souris": [_mouse.x, _mouse.y],
		"version": Version.NUMBER,
		"date": Time.get_datetime_string_from_system(),
		"classe": Run.class_id if Run.active else Profile.selected_class,
		"en_run": Run.active,
	}
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player:
		report["position"] = [player.global_position.x, player.global_position.y, player.global_position.z]
	var f := FileAccess.open(dir.path_join("rapport.json"), FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(report, "  "))
		f.close()
	_close()
	_show_toast("Note enregistrée (feedback/%s) — merci !" % stamp)


func _show_toast(text: String) -> void:
	_toast.text = text
	_toast.reset_size()
	var vp := get_viewport().get_visible_rect().size
	_toast.position = Vector2((vp.x - _toast.size.x) * 0.5, vp.y - 150)
	_toast.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_interval(2.5)
	tw.tween_property(_toast, "modulate:a", 0.0, 0.6)
