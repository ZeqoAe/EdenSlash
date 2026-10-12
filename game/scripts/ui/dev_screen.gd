class_name DevScreen
extends PageScreen
## Écran du mode dev (F10, seulement si le mode dev est activé dans Paramètres > Caméra &
## interface) : Objets (tout le catalogue et ses filtres, ajout au coffre ou au sac),
## Ressources, Progression et, pendant une run, Run (niveau, invincibilité, apparitions...).
## Éditer : stats et bonus des objets possédés et des modèles du catalogue ; Sets : créer et
## modifier des sets (DevEditor, enregistrés dans data/dev_edits.json) ; Cartes : cartes de
## build, raretés tirées et améliorations de sort (DevCards).
## Ouvert par-dessus tout le reste ; met le jeu en pause pendant une run.


func _init() -> void:
	super._init("Mode dev", 70)


func setup(world: Node) -> void:
	var items := DevPages.ItemsPage.new()
	add_page("Objets", items)
	var editor := DevEditor.EditPage.new()
	add_page("Éditer", editor)
	add_page("Sets", DevEditor.SetsPage.new())
	add_page("Cartes", DevCards.CardsPage.new())
	items.edit_requested.connect(func(e):
		show_page(1)
		editor.edit_template(e))
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
