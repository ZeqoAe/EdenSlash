class_name PauseMenu
extends CanvasLayer
## Menu pause (Échap) : reprendre, fiche du personnage (stats, équipement,
## compétences, passifs), bilan de la run, retour au lobby.

signal abandon_requested

var player: Player
var _root: Control
var _panel: CharacterPanel
var _run_label: Label
var _confirm: ConfirmationDialog


func setup(p: Player) -> void:
	player = p
	layer = 15
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.01, 0.05, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)
	var h := HBoxContainer.new()
	h.set_anchors_preset(Control.PRESET_CENTER)
	h.position = Vector2(-640, -300)
	h.add_theme_constant_override("separation", 20)
	_root.add_child(h)

	var menu := VBoxContainer.new()
	menu.custom_minimum_size = Vector2(250, 0)
	menu.add_theme_constant_override("separation", 10)
	h.add_child(menu)
	var title := Hud._label(menu, "PAUSE", 34, Hud.ACCENT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_button(menu, "Reprendre", close)
	_button(menu, "Retour au lobby", func(): _confirm.popup_centered())
	_button(menu, "Quitter le jeu", func(): get_tree().quit())
	_run_label = Hud._label(menu, "", 14, Color(0.85, 0.85, 0.9))
	_run_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_run_label.custom_minimum_size = Vector2(250, 0)

	_panel = CharacterPanel.new()
	_panel.player = player
	h.add_child(_panel)

	_confirm = ConfirmationDialog.new()
	_confirm.title = "Abandonner la run ?"
	_confirm.dialog_text = "Tu gardes l'or et le butin ramassés.\nRetourner au lobby ?"
	_confirm.ok_button_text = "Retour au lobby"
	_confirm.cancel_button_text = "Annuler"
	_confirm.confirmed.connect(func(): abandon_requested.emit())
	add_child(_confirm)
	_root.visible = false
	add_child(_root)


func _button(parent: Control, text: String, cb: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(250, 48)
	b.add_theme_font_size_override("font_size", 18)
	b.add_theme_stylebox_override("normal", Hud.style(Color(0.12, 0.1, 0.2, 0.95)))
	var hover := Hud.style(Color(0.22, 0.18, 0.34, 1.0))
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("focus", hover)
	b.pressed.connect(cb)
	parent.add_child(b)


func is_open() -> bool:
	return _root.visible


func open() -> void:
	_root.visible = true
	get_tree().paused = true
	_run_label.text = "Run en cours\nDurée : %s\nMonstres vaincus : %d\nÉlites : %d\nButin : %d objet(s)\nOr gagné : %d" % [
		Run.duration_text(), Run.kills, Run.elites, Run.loot.size(), Run.gold]
	_panel.refresh()


func close() -> void:
	_root.visible = false
	get_tree().paused = false
