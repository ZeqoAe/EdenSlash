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
var _confirm: ConfirmationDialog


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
	_run.lobby_requested.connect(func(): _confirm.popup_centered())
	_run.grimoire_requested.connect(func(): grimoire.open())
	_run.settings_requested.connect(func(): settings.open())
	_confirm = ConfirmationDialog.new()
	_confirm.title = "Abandonner la run ?"
	_confirm.dialog_text = "La run sera abandonnée : tu choisiras 1 objet à garder,\nle reste (or, matériaux, butin) est perdu.\nRetourner au lobby ?"
	_confirm.ok_button_text = "Retour au lobby"
	_confirm.cancel_button_text = "Annuler"
	_confirm.confirmed.connect(func(): abandon_requested.emit())
	add_child(_confirm)
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
	if settings.is_open():
		settings.close()
	if grimoire.is_open():
		grimoire.close_ui()
	_screen.close_ui()
