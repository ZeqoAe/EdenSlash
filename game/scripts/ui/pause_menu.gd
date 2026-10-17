class_name PauseMenu
extends CanvasLayer
## Menu pause (Échap), plein écran, même structure que le lobby : page « Run »
## (compétences, cartes, sac, bilan, actions) et page « Héros » (équipement, statistiques,
## sac de la run). Le bouton « ? Aide » de l'en-tête ouvre le Guide (formules, valeurs du héros).
## Grimoire et paramètres s'ouvrent par-dessus.

signal abandon_requested
signal extract_requested

var player: Player
var settings: SettingsMenu
var grimoire: Grimoire
var _screen: PageScreen
var _run: RunPage
var _equip: InventoryPage
var _help_button: Button
var _confirm: Confirm
var build: SurvivorBuildPage  # Survivant : page « Build » (null ailleurs)


func setup(p: Player) -> void:
	player = p
	layer = 15
	process_mode = Node.PROCESS_MODE_ALWAYS
	_screen = PageScreen.new("Pause", 15)
	_screen.pause_game = true
	add_child(_screen)
	if Survivor.active:
		# Survivant (lot S5) : la page Build d'abord (tout le build, rien ne se retire) ; pas d'inventaire ni de coffre
		build = SurvivorBuildPage.new()
		build.player = player
		build.resume_requested.connect(close)
		_screen.add_page("Build", build)
	_run = RunPage.new()
	_run.player = player
	_screen.add_page("Partie" if Royale.active else "Run", _run)  # (lot BR-I2 : pas de « run » au Battle royale)
	if not Survivor.active:
		_equip = InventoryPage.new()
		_equip.player = player
		_screen.add_page("Héros", _equip)
	_help_button = Button.new()
	_help_button.text = "?  Aide"
	_help_button.tooltip_text = "Le Guide : touches, cartes, modes et formules (%s)" % Settings.action_label("help", 1)
	_help_button.focus_mode = Control.FOCUS_NONE
	_help_button.custom_minimum_size = Vector2(0, 40)
	_help_button.pressed.connect(open_guide)
	_screen.add_header_control(_help_button)
	_run.resume_requested.connect(close)
	_run.extract_requested.connect(func():
		close()
		extract_requested.emit())
	_confirm = Confirm.new()
	add_child(_confirm)
	_run.lobby_requested.connect(func():
		var t := leave_texts()
		_confirm.ask(t.title, t.text, t.ok, func(): abandon_requested.emit()))
	_run.quit_requested.connect(func(): _confirm.ask("Quitter le jeu ?", "La partie en cours sera perdue." if Royale.active else "La run en cours sera perdue.", "Quitter le jeu", func(): get_tree().quit()))
	_run.grimoire_requested.connect(func(): grimoire.open())
	_run.settings_requested.connect(func(): settings.open())
	# par-dessus l'écran (Échap les ferme d'abord)
	settings = SettingsMenu.new()
	_screen.add_child(settings)
	grimoire = Grimoire.new()
	_screen.add_child(grimoire)


func is_open() -> bool:
	return _screen != null and _screen.is_open()


## « ? Aide » : le Guide, sur ses formules, par-dessus la pause (Échap ou F1 le ferme, la pause reste).
func open_guide() -> Guide:
	# même parent que la touche F1 (TestTools) : F1 le referme au lieu d'en ouvrir un second
	var world := get_parent()
	var host: Node = world.get("tools") if world != null and "tools" in world and world.get("tools") != null else get_tree().current_scene
	return Guide.open_on(host, "details")


func open(page := -1) -> void:
	_screen.set_title("Pause", "%s · niveau %d · %s" % [Run.class_data().get("name_fr", ""), player.level, Run.duration_text()])
	_screen.show_wallet(not Royale.active and not Duel.active)  # Battle royale, duel : ni or, ni clés, ni cristaux (passes M1, M7)
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


## Confirmation dans le style du jeu (au-dessus de tout, Échap ou B = annuler) : petit dialogue `InfoCard.ask`.
class Confirm extends CanvasLayer:
	var _ask: InfoCard.Ask
	var _title: Label  # le titre de la confirmation affichée (les tests le lisent)

	func _init() -> void:
		layer = 40
		process_mode = Node.PROCESS_MODE_ALWAYS
		visible = false

	func ask(title: String, text: String, ok_text: String, on_ok: Callable) -> void:
		hide_now()
		_ask = InfoCard.ask(self, title, text, ok_text, on_ok)
		_title = _ask.title_label
		_ask.answered.connect(func(_ok): visible = false)
		visible = true

	func hide_now() -> void:
		if _ask != null and is_instance_valid(_ask):
			_ask.queue_free()
		_ask = null
		visible = false

	## Échap ou B : annule (l'événement est aussi lu par la confirmation elle-même).
	func _input(event: InputEvent) -> void:
		if _ask != null and is_instance_valid(_ask) and visible:
			_ask._input(event)
