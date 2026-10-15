class_name PauseMenu
extends CanvasLayer
## Menu pause (Échap), plein écran, même structure que le lobby : page « Run »
## (compétences, cartes, sac, bilan, actions), page « Héros » (équipement, statistiques,
## sac de la run) et page « Aide » (formules des statistiques et des dégâts, valeurs du héros).
## Grimoire et paramètres s'ouvrent par-dessus.

signal abandon_requested
signal extract_requested

var player: Player
var settings: SettingsMenu
var grimoire: Grimoire
var _screen: PageScreen
var _run: RunPage
var _equip: InventoryPage
var _info: InfoPage
var _confirm: Confirm


func setup(p: Player) -> void:
	player = p
	layer = 15
	process_mode = Node.PROCESS_MODE_ALWAYS
	_screen = PageScreen.new("Pause", 15)
	_screen.pause_game = true
	add_child(_screen)
	_run = RunPage.new()
	_run.player = player
	_screen.add_page("Run", _run)
	_equip = InventoryPage.new()
	_equip.player = player
	_screen.add_page("Héros", _equip)
	_info = InfoPage.new()
	_info.player = player
	_screen.add_page("Aide", _info)
	_run.resume_requested.connect(close)
	_run.extract_requested.connect(func():
		close()
		extract_requested.emit())
	_confirm = Confirm.new()
	add_child(_confirm)
	_run.lobby_requested.connect(func():
		var t := leave_texts()
		_confirm.ask(t.title, t.text, t.ok, func(): abandon_requested.emit()))
	_run.quit_requested.connect(func(): _confirm.ask("Quitter le jeu ?", "La run en cours sera perdue.", "Quitter le jeu", func(): get_tree().quit()))
	_run.grimoire_requested.connect(func(): grimoire.open())
	_run.settings_requested.connect(func(): settings.open())
	# par-dessus l'écran (Échap les ferme d'abord)
	settings = SettingsMenu.new()
	_screen.add_child(settings)
	grimoire = Grimoire.new()
	_screen.add_child(grimoire)


func is_open() -> bool:
	return _screen != null and _screen.is_open()


func open(page := -1) -> void:
	_screen.set_title("Pause", "%s · niveau %d · %s" % [Run.class_data().get("name_fr", ""), player.level, Run.duration_text()])
	_screen.show_wallet(true)
	_screen.open(page)


func close() -> void:
	_confirm.hide_now()
	if settings.is_open():
		settings.close()
	if grimoire.is_open():
		grimoire.close_ui()
	_screen.close_ui()


## Textes du départ de la partie selon le mode : bouton de la page Run, titre et texte de la confirmation.
static func leave_texts() -> Dictionary:
	if Training.active:
		return {"button": "Quitter l'entraînement", "title": "Quitter l'entraînement ?", "text": "Rien de l'entraînement n'est gardé.", "ok": "Quitter"}
	if Royale.active:
		return {"button": "Abandonner la partie", "title": "Abandonner le Battle royale ?", "text": "Tu termines dernier (%de). Seules les récompenses de cette place sont gardées." % Royale.PLAYERS, "ok": "Abandonner"}
	if Duel.active:
		return {"button": "Abandonner le duel", "title": "Abandonner le duel ?", "text": "Le duel compte comme perdu.", "ok": "Abandonner"}
	if Tower.active:
		var what := "le siège" if Tower.siege else ("le donjon" if Tower.is_dungeon() else "la Tour")
		return {"button": "Quitter %s" % what, "title": "Quitter %s ?" % what, "text": "Les récompenses déjà gagnées sont gardées.", "ok": "Quitter"}
	return {"button": "Abandonner la run", "title": "Abandonner la run ?", "text": "L'or, les clés et les fournitures seront perdus.\nLes coffres ramassés et les insignes sont gardés.", "ok": "Abandonner"}


## Fenêtre de confirmation dans le style du jeu (au-dessus de tout, Échap ou B = annuler).
class Confirm extends CanvasLayer:
	var _title: Label
	var _text: Label
	var _ok: Button
	var _cancel: Button
	var _on_ok: Callable

	func _init() -> void:
		layer = 40
		process_mode = Node.PROCESS_MODE_ALWAYS
		visible = false
		var root := Control.new()
		root.set_anchors_preset(Control.PRESET_FULL_RECT)
		add_child(root)
		var dim := ColorRect.new()
		dim.color = Color(0.02, 0.01, 0.05, 0.7)
		dim.set_anchors_preset(Control.PRESET_FULL_RECT)
		root.add_child(dim)
		var center := CenterContainer.new()
		center.set_anchors_preset(Control.PRESET_FULL_RECT)
		root.add_child(center)
		var panel := PanelContainer.new()
		panel.add_theme_stylebox_override("panel", UiTheme.panel_box(34, 26))
		panel.custom_minimum_size = Vector2(560, 0)
		center.add_child(panel)
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 14)
		panel.add_child(v)
		_title = Label.new()
		UiTheme.title(_title, 30)
		_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(_title)
		_text = Hud._label(v, "", 18, UiTheme.TEXT)
		_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_text.custom_minimum_size = Vector2(480, 0)
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 16)
		v.add_child(row)
		_cancel = MenuWidgets.glass_button("Annuler", 20, Vector2(200, 54))
		_cancel.pressed.connect(hide_now)
		row.add_child(_cancel)
		_ok = MenuWidgets.glass_button("", 20, Vector2(240, 54))
		_ok.add_theme_stylebox_override("normal", UiTheme.flat_box(Color(0.38, 0.1, 0.12, 0.95), Color(1.0, 0.5, 0.45), 2, 12))
		_ok.add_theme_stylebox_override("hover", UiTheme.flat_box(Color(0.55, 0.14, 0.16, 1.0), Color(1.0, 0.7, 0.6), 2, 12))
		_ok.pressed.connect(func():
			var cb := _on_ok
			hide_now()
			if cb.is_valid():
				cb.call())
		row.add_child(_ok)

	func ask(title: String, text: String, ok_text: String, on_ok: Callable) -> void:
		_title.text = title
		_text.text = text
		_ok.text = ok_text
		_on_ok = on_ok
		visible = true

	func hide_now() -> void:
		visible = false

	func _input(event: InputEvent) -> void:
		if visible and (event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause")):
			get_viewport().set_input_as_handled()
			hide_now()
