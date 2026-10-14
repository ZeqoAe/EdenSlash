class_name TestTools
extends CanvasLayer
## Outils pour tester le jeu et faire des retours :
##   F1 aide · F2 infos de débogage · F4 se débloquer · F9 signaler un problème
##   mode dev seulement : F5 +1 niveau · F6 aller à l'entrée du donjon · F7 entrer dans le donjon
##   · F8 déclencher la rage
## Les rapports F9 (capture + état + note) vont dans EdenSlash/feedback/.

var player: Player
var director: RunDirector

var _help: PanelContainer
var _help_label: RichTextLabel
var _overlay: Label
var _report_box: PanelContainer
var _report_edit: LineEdit
var _toast: Label
var _pending_shot: Image

## Aide : reflète les touches et le mode de jeu choisis dans les Paramètres.
static func help_text() -> String:
	var k := func(a: String) -> String: return Settings.action_label(a)
	var move: String = {
		"click": "%s (maintenu) : se déplacer vers le curseur / attaquer le monstre cliqué" % Settings.action_label("attack", 1),
		"rts": "%s : se déplacer / attaquer le monstre cliqué" % Settings.action_label("move_order", 1),
	}.get(Settings.move_mode(), "%s : attaquer (sur un monstre : auto-attaque)" % k.call("attack"))
	var skills: PackedStringArray = []
	for i in 4:
		skills.append(Settings.action_label("skill_%d" % (i + 1), 1))
	var dev := "\nMode dev : F5 +1 niveau      F6 aller à l'entrée du donjon      F7 arène du boss      F8 déclencher la rage" if dev_keys() else ""
	var mask := Settings.camera_rotate_mask()
	var cam := "Clic molette" if mask == MOUSE_BUTTON_MASK_MIDDLE else Settings.action_label("camera_rotate", 1)
	return """[b]Contrôles[/b]  (Échap > Paramètres pour les changer)
%s / %s / %s / %s : se déplacer      %s : sauter      %s : esquive (invulnérable)
%s      %s maintenu : tourner la caméra
%s : compétences      %s : interagir (coffre, PNJ, donjon)      %s : carte      %s : objectifs      %s : menu
Molette : zoom

[b]Tests et retours[/b]
Alt + clic droit sur n'importe quoi : note sur cet élément (objet, apparence, bouton, monstre…)
F9 : signaler un problème de carte (capture + position + ta note, dossier feedback)
F4 : se débloquer      F2 : infos de débogage (position, FPS...)%s
F1 : afficher / masquer cette aide""" % [
		Settings.action_label("move_forward", 1), Settings.action_label("move_left", 1),
		Settings.action_label("move_back", 1), Settings.action_label("move_right", 1),
		k.call("jump"), k.call("dodge"), move, cam, " ".join(skills), k.call("interact"),
		k.call("map"), Settings.action_label("objectives", 1), Settings.action_label("pause", 1), dev]


## Touches de test F5 à F8 (niveau, téléportation, rage) : en mode dev seulement.
static func dev_keys() -> bool:
	return bool(Settings.get_v("interface", "dev_mode"))


func setup(p: Player, d: RunDirector) -> void:
	player = p
	director = d
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()


func _build() -> void:
	_help = PanelContainer.new()
	_help.add_theme_stylebox_override("panel", _style())
	_help.set_anchors_preset(Control.PRESET_CENTER)
	_help.position = Vector2(-430, -150)
	_help.custom_minimum_size = Vector2(860, 0)
	var rt := RichTextLabel.new()
	rt.bbcode_enabled = true
	rt.fit_content = true
	rt.text = help_text()
	_help_label = rt
	rt.add_theme_font_size_override("normal_font_size", 17)
	rt.add_theme_font_size_override("bold_font_size", 19)
	_help.add_child(rt)
	_help.visible = false
	add_child(_help)

	_overlay = Label.new()
	_overlay.position = Vector2(18, 130)
	_overlay.add_theme_font_size_override("font_size", 14)
	_overlay.add_theme_constant_override("outline_size", 4)
	_overlay.add_theme_color_override("font_outline_color", Color.BLACK)
	_overlay.visible = false
	add_child(_overlay)

	_report_box = PanelContainer.new()
	_report_box.add_theme_stylebox_override("panel", _style())
	_report_box.set_anchors_preset(Control.PRESET_CENTER)
	_report_box.position = Vector2(-330, -60)
	_report_box.custom_minimum_size = Vector2(660, 0)
	var v := VBoxContainer.new()
	_report_box.add_child(v)
	var l := Label.new()
	l.text = "Décris le problème (Entrée pour enregistrer, Échap pour annuler) :"
	v.add_child(l)
	_report_edit = LineEdit.new()
	_report_edit.placeholder_text = "ex : bloqué entre le rocher et la clôture, impossible de sortir"
	_report_edit.text_submitted.connect(_save_report)
	v.add_child(_report_edit)
	_report_box.visible = false
	add_child(_report_box)

	_toast = Label.new()
	_toast.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_toast.position = Vector2(-300, -170)
	_toast.custom_minimum_size = Vector2(600, 0)
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.add_theme_font_size_override("font_size", 18)
	_toast.add_theme_constant_override("outline_size", 6)
	_toast.add_theme_color_override("font_outline_color", Color.BLACK)
	add_child(_toast)

	var hint := Label.new()
	hint.text = "F1 : aide   ·   F9 : signaler un problème"
	hint.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	hint.position = Vector2(14, -28)
	hint.add_theme_font_size_override("font_size", 13)
	hint.modulate = Color(1, 1, 1, 0.65)
	add_child(hint)


func _unhandled_input(event: InputEvent) -> void:
	if _report_box.visible:
		if event.is_action_pressed("ui_cancel"):
			_close_report()
		return
	if event.is_action_pressed("help"):
		_help_label.text = help_text()
		_help.visible = not _help.visible
	elif event.is_action_pressed("debug_overlay"):
		_overlay.visible = not _overlay.visible
	elif event.is_action_pressed("feedback"):
		_open_report()
	elif event.is_action_pressed("unstuck"):
		player.unstuck()
		_show_toast("Débloqué")
	elif not dev_keys():
		return
	elif event.is_action_pressed("debug_level"):
		player.gain_xp(GameData.xp_to_next(player.level) - player.xp)
	elif event.is_action_pressed("debug_gateway"):
		if director.teleport_to_gateway():
			_show_toast("Téléporté à l'entrée du donjon")
		else:
			_show_toast("Pas d'entrée de donjon sur cette map")
	elif event.is_action_pressed("debug_dungeon"):
		director.debug_enter_dungeon()
	elif event.is_action_pressed("debug_rage"):
		director.debug_start_rage()


func _process(_delta: float) -> void:
	if _overlay.visible and player:
		var p := player.global_position
		_overlay.text = "Map %s  |  pos %.1f, %.1f, %.1f (Eden x=%.1f y=%.1f)\nÉtat %s  |  niveau %d  |  au sol %s  |  monstres %d  |  %d FPS" % [
			director.map.map_id if director.map else "?", p.x, p.y, p.z, p.x, -p.z,
			director.state, player.level, player.is_on_floor(),
			get_tree().get_nodes_in_group("monsters").size(), Engine.get_frames_per_second()]


func _open_report() -> void:
	# capture avant d'afficher la boîte de saisie
	_pending_shot = get_viewport().get_texture().get_image()
	_report_box.visible = true
	_report_edit.text = ""
	_report_edit.grab_focus()
	get_tree().paused = true


func _close_report() -> void:
	_report_box.visible = false
	get_tree().paused = false


func _save_report(note: String) -> void:
	var stamp := Time.get_datetime_string_from_system().replace(":", "-")
	var dir := Feedback.folder().path_join(stamp)
	DirAccess.make_dir_recursive_absolute(dir)
	if _pending_shot:
		_pending_shot.save_png(dir.path_join("capture.png"))
	var p := player.global_position
	var report := {
		"note": note,
		"version": Version.NUMBER,
		"date": Time.get_datetime_string_from_system(),
		"map": director.map.map_id if director.map else "",
		"position_godot": [p.x, p.y, p.z],
		"position_eden": [p.x, -p.z, p.y],
		"au_sol": player.is_on_floor(),
		"etat_zone": director.state,
		"niveau": player.level,
		"pv": [player.hp, player.max_hp],
		"monstres": get_tree().get_nodes_in_group("monsters").size(),
		"fps": Engine.get_frames_per_second(),
	}
	var f := FileAccess.open(dir.path_join("rapport.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify(report, "  "))
	f.close()
	_close_report()
	_show_toast("Rapport enregistré dans feedback/%s — merci !" % stamp)


func _show_toast(text: String) -> void:
	_toast.text = text
	_toast.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_interval(2.5)
	tw.tween_property(_toast, "modulate:a", 0.0, 0.6)


func _style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.07, 0.14, 0.92)
	sb.set_corner_radius_all(10)
	sb.border_color = Color(0.98, 0.78, 0.35, 0.6)
	sb.set_border_width_all(2)
	sb.content_margin_left = 18
	sb.content_margin_right = 18
	sb.content_margin_top = 14
	sb.content_margin_bottom = 14
	return sb
