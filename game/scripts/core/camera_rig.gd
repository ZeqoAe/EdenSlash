class_name CameraRig
extends Node3D
## Caméra de hack and slash : vue plongeante qui suit le héros, zoom à la molette.

var target: Node3D
var distance := 15.0
var pitch_deg := 52.0
var yaw_deg := 0.0
var camera: Camera3D

var _shake := 0.0


func _ready() -> void:
	distance = float(Settings.get_v("camera", "distance"))
	camera = Camera3D.new()
	camera.fov = 45.0
	camera.far = 400.0
	add_child(camera)
	camera.current = true


const ROTATE_SPEED := 0.3  # degrés par pixel de souris


var allow_input := true  # désactivé pendant les tests automatiques


func _unhandled_input(event: InputEvent) -> void:
	if not allow_input:
		return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			distance = maxf(7.0, distance - 1.0)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			distance = minf(28.0, distance + 1.0)
	# clic droit maintenu (réglable ; clic molette si le clic droit sert à se déplacer) :
	# rotation (gauche/droite) et inclinaison (haut/bas)
	elif event is InputEventMouseMotion and (event.button_mask & Settings.camera_rotate_mask()):
		var speed := ROTATE_SPEED * float(Settings.get_v("camera", "rotate_speed"))
		var inv := -1.0 if Settings.get_v("camera", "invert_y") else 1.0
		yaw_deg = wrapf(yaw_deg - event.relative.x * speed, -180.0, 180.0)
		pitch_deg = clampf(pitch_deg + event.relative.y * speed * 0.6 * inv, 25.0, 75.0)



func shake(amount: float) -> void:
	_shake = maxf(_shake, amount * float(Settings.get_v("camera", "shake")))


func _process(delta: float) -> void:
	if target == null:
		return
	global_position = global_position.lerp(target.global_position, clampf(10.0 * delta, 0.0, 1.0))
	var pitch := deg_to_rad(pitch_deg)
	var yaw := deg_to_rad(yaw_deg)
	var offset := Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch)) * distance
	camera.position = offset
	camera.look_at(global_position + Vector3.UP * 1.0, Vector3.UP)
	# position du héros pour le shader du décor (trou de visibilité)
	var vp := get_viewport().get_visible_rect().size
	var hero := target.global_position + Vector3.UP * 1.0
	RenderingServer.global_shader_parameter_set("hero_screen", camera.unproject_position(hero) / vp)
	RenderingServer.global_shader_parameter_set("hero_depth", camera.global_position.distance_to(hero))
	RenderingServer.global_shader_parameter_set("hero_world", target.global_position)
	if _shake > 0.0:
		camera.position += Vector3(randf_range(-1, 1), randf_range(-1, 1), 0) * _shake * 0.15
		_shake = maxf(0.0, _shake - delta * 4.0)
