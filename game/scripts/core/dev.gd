extends Node
## Mode dev : F10 ouvre l'écran DevScreen (lobby ou run) quand le mode dev est activé dans
## les Paramètres (Caméra & interface). Rien n'apparaît pour un joueur qui ne l'a pas activé.

var screen: DevScreen


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func enabled() -> bool:
	return bool(Settings.get_v("interface", "dev_mode"))


## Scène de run en cours (world.gd), sinon null.
func world() -> Node:
	return get_tree().get_first_node_in_group("world")


func toggle() -> void:
	if not enabled():
		return
	if is_instance_valid(screen) and screen.is_open():
		screen.close_ui()
		return
	open()


func open(page := 0) -> void:
	if is_instance_valid(screen):
		screen.queue_free()
	screen = DevScreen.new()
	var w := world()
	(w if w else get_tree().current_scene).add_child(screen)
	screen.setup(w)
	screen.open(page)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_F10:
		get_viewport().set_input_as_handled()
		toggle()
