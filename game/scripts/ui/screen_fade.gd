class_name ScreenFade
extends CanvasLayer
## Fondu au noir autour d'un changement de carte (donjon, étape suivante) : l'écran s'assombrit,
## le jeu est mis en pause pendant que [param work] génère la nouvelle carte (l'à-coup ne se voit
## pas), puis l'image revient.

const OUT := 0.3
const IN := 0.45

var _rect: ColorRect


static func run(tree: SceneTree, work: Callable) -> void:
	var f := ScreenFade.new()
	f.layer = 90
	f.process_mode = Node.PROCESS_MODE_ALWAYS
	tree.root.add_child(f)
	await f._play(tree, work)


## Apparition depuis le noir (début d'une run, après un chargement).
static func reveal(tree: SceneTree, duration := 0.7) -> void:
	var f := ScreenFade.new()
	f.layer = 90
	f.process_mode = Node.PROCESS_MODE_ALWAYS
	tree.root.add_child(f)
	f._rect = ColorRect.new()
	f._rect.color = Color(0.01, 0.0, 0.02, 1.0)
	f._rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	f._rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	f.add_child(f._rect)
	var tw := f.create_tween()
	tw.tween_interval(0.1)
	tw.tween_property(f._rect, "color:a", 0.0, duration)
	tw.tween_callback(f.queue_free)


func _play(tree: SceneTree, work: Callable) -> void:
	_rect = ColorRect.new()
	_rect.color = Color(0.01, 0.0, 0.02, 0.0)
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_rect)
	var was_paused := tree.paused
	tree.paused = true
	var tw := create_tween()
	tw.tween_property(_rect, "color:a", 1.0, OUT)
	await tw.finished
	work.call()
	await tree.process_frame
	await tree.process_frame
	tree.paused = was_paused
	var tw2 := create_tween()
	tw2.tween_property(_rect, "color:a", 0.0, IN)
	await tw2.finished
	queue_free()
