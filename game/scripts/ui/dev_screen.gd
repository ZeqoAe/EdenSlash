class_name DevScreen
extends PageScreen
## Écran du mode dev (F10, seulement si le mode dev est activé dans Paramètres > Caméra &
## interface) : Objets (tout le catalogue et ses filtres, ajout au coffre ou au sac),
## Ressources, Progression et, pendant une run, Run (niveau, invincibilité, apparitions...).
## Ouvert par-dessus tout le reste ; met le jeu en pause pendant une run.


func _init() -> void:
	super._init("Mode dev", 70)


func setup(world: Node) -> void:
	add_page("Objets", DevPages.ItemsPage.new())
	add_page("Ressources", DevPages.ResourcesPage.new())
	add_page("Progression", DevPages.ProgressPage.new())
	if world:
		var run := DevPages.RunActionsPage.new()
		run.world = world
		add_page("Run", run)
	pause_game = world != null
	set_title("Mode dev", "Réservé aux tests · F10 ou Échap pour fermer")


func _input(event: InputEvent) -> void:
	if is_open() and event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_F10:
		get_viewport().set_input_as_handled()
		close_ui()
		return
	super._input(event)
