class_name AutochessArena
extends Node3D
## L'Échiquier, lot AC-V : la mise en scène. Le plateau (AutochessBoard, posé à l'origine de ce nœud) et le combat regardé se
## jouent dans l'arène du Duel (ProcMap.generate_arena, cuvette ronde fermée de falaises, torches, ciel, brouillard et
## lumière du biome, musique du duel) au lieu d'un socle isolé ; les dangers de l'arène ne sont pas posés. Le biome change
## avec l'étape (ARENA_BIOMES, l'étape 1 = l'arène du Duel). Le centre de l'arène est aplani (ProcMap.arena_flat) : la
## grille y est tracée au sol, 2 cm au-dessus (GROUND). Rapport : conception/autochess/R_AC_V.md.
##
## Caméra : en préparation, celle du plateau (AutochessBoard.frame_camera, deux zooms à la molette : les cases se visent) ;
## en combat (combat_camera) une caméra large et inclinée comme celle de l'arène du Duel, centrée sur le plateau, qui
## arrive en douceur : molette (et stick droit vertical, changé en molette par Gamepad) = zoom, stick droit horizontal ou
## clic droit maintenu = rotation, bornée.

const ARENA_BIOMES := ["arid", "rainbowfall", "beluga", "wetlands", "delphi", "avila", "blackflame"]
const FLAT := 18.0  # m : centre plat de l'arène (plateau, bancs, allée du stratège : 12,2 m au plus)
const GROUND := AutochessBoard.TOP - 0.02  # sol de l'arène dans le repère du plateau : cases 2 cm au-dessus
## Caméra du combat (repère du plateau) : comme la caméra de l'arène du Duel (CameraRig : inclinaison 52°, champ 45°).
const CAM_AT := Vector3(0.0, 0.6, 0.6)
const CAM_PITCH := 50.0
const CAM_DIST := 27.0
const CAM_DIST_RANGE := Vector2(15.0, 36.0)
const CAM_PITCH_RANGE := Vector2(32.0, 72.0)
const CAM_YAW_SPAN := 50.0  # degrés de part et d'autre de la vue de son camp
const CAM_BLEND := 0.7  # s : passage de la caméra du plateau à celle du combat (et retour)
const PAD_TURN := 110.0  # degrés par seconde, stick au bout

var biome := ""
var map: ProcMap
var env: Environment
var sun: DirectionalLight3D
var camera: Camera3D
## Caméra du combat active (sinon la caméra appartient au plateau).
var cam_free := false
var cam_yaw := 0.0  # vue de son camp (0 : camp 0 près de la caméra, 180 : camp 1)
var cam_yaw_off := 0.0
var cam_pitch := CAM_PITCH
var cam_dist := CAM_DIST
var _blend := 1.0
var _from := Transform3D.IDENTITY
var _to_prep := Transform3D.IDENTITY
var _blend_prep := 1.0


func _init() -> void:
	name = "AutochessArena"


func _ready() -> void:
	_build_environment()


## Biome de l'arène pour l'étape [param stage] : l'arène du Duel d'abord, puis les autres décors des arènes.
static func biome_for(stage: int) -> String:
	return String(ARENA_BIOMES[posmod(stage - 1, ARENA_BIOMES.size())])


## Construit (ou garde) l'arène du biome [param b] ; [param seed_value] : graine du décor (rochers).
func build(b: String, seed_value := 0) -> void:
	if b == biome and map != null and is_instance_valid(map):
		return
	biome = b if GameData.biomes.has(b) else "arid"
	if map != null and is_instance_valid(map):
		map.remove_from_group("map")
		map.queue_free()
	map = ProcMap.new()
	map.name = "AcArenaMap"
	map.biome = biome
	map.arena_flat = FLAT
	add_child(map)
	map.generate_arena(seed_value, "ring")
	# hors du groupe « map » : les unités ne cherchent pas de chemin (plateaux cachés loin du maillage de navigation)
	map.remove_from_group("map")
	map.position = Vector3(-map.size * 0.5, GROUND, -map.size * 0.5)
	_apply_biome()


## Ciel, brouillard, lumière et soleil, comme le monde du jeu (World._build_environment) ; teintes du biome.
func _build_environment() -> void:
	var sky_mat := ProceduralSkyMaterial.new()
	var sky := Sky.new()
	sky.sky_material = sky_mat
	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.78, 0.78, 0.82)
	env.ambient_light_energy = 0.6
	env.glow_enabled = true
	env.glow_intensity = 0.3
	env.glow_bloom = 0.0
	env.glow_hdr_threshold = 1.2
	env.fog_enabled = true
	env.fog_light_color = Color(0.85, 0.89, 0.91)
	env.fog_density = 0.0018
	env.fog_sky_affect = 0.15
	Gfx.style_sky(sky_mat)
	Gfx.style_environment(env)
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -35, 0)
	sun.light_energy = 1.25
	sun.light_color = Color(1.0, 0.96, 0.88)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 80.0
	Gfx.style_sun(sun)
	add_child(sun)


func _apply_biome() -> void:
	var e: Dictionary = (GameData.biomes.get(biome, {}) as Dictionary).get("env", {})
	if e.is_empty() or env == null:
		return
	var c := func(k: String, fallback: Color) -> Color:
		var a: Array = e.get(k, [])
		return Color(a[0], a[1], a[2]) if a.size() >= 3 else fallback
	var sky_mat := env.sky.sky_material as ProceduralSkyMaterial
	sky_mat.sky_top_color = c.call("sky_top", sky_mat.sky_top_color)
	sky_mat.sky_horizon_color = c.call("horizon", sky_mat.sky_horizon_color)
	sky_mat.ground_horizon_color = (c.call("horizon", sky_mat.sky_horizon_color) as Color).darkened(0.15)
	env.fog_light_color = c.call("fog", env.fog_light_color)
	env.fog_density = float(e.get("fog_density", 0.0018))
	env.ambient_light_color = c.call("ambient", env.ambient_light_color)
	sun.light_color = c.call("sun", sun.light_color)


# --- caméra -----------------------------------------------------------------------------------------------------------
## Passe à la caméra du combat (arrivée en douceur depuis la vue du plateau) ; [param my_side] : camp du joueur (1 : la
## caméra passe de l'autre côté, son équipe reste devant) ; [param instant] : sans transition (tests).
func combat_camera(cam: Camera3D, my_side := 0, instant := false) -> void:
	camera = cam
	cam_free = true
	cam_yaw = 180.0 if my_side == 1 else 0.0
	cam_yaw_off = 0.0
	cam_pitch = CAM_PITCH
	cam_dist = CAM_DIST
	_from = cam.global_transform
	_blend = 1.0 if instant else 0.0
	_blend_prep = 1.0
	_place_camera(0.0)


## Rend la caméra au plateau : [param target] = pose voulue (celle de AutochessBoard.frame_camera), rejointe en douceur.
func prep_camera(cam: Camera3D, target: Transform3D, instant := false) -> void:
	camera = cam
	cam_free = false
	_from = cam.global_transform
	_to_prep = target
	_blend_prep = 1.0 if instant else 0.0
	if instant:
		cam.global_transform = target


## Pose de la caméra du combat (repère du monde), autour du plateau affiché.
func orbit_pose() -> Transform3D:
	var center := global_transform * CAM_AT
	var yaw := deg_to_rad(cam_yaw + cam_yaw_off)
	var pitch := deg_to_rad(cam_pitch)
	var off := Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch)) * cam_dist
	var t := Transform3D(Basis.IDENTITY, center + off)
	return t.looking_at(center, Vector3.UP)


func _place_camera(delta: float) -> void:
	if camera == null or not is_instance_valid(camera):
		return
	if cam_free:
		var goal := orbit_pose()
		if _blend < 1.0:
			_blend = minf(1.0, _blend + delta / CAM_BLEND)
			var k := ease(_blend, -2.0)
			camera.global_transform = _from.interpolate_with(goal, k)
		else:
			camera.global_transform = camera.global_transform.interpolate_with(goal, minf(1.0, delta * 10.0)) if delta > 0.0 else goal
		camera.fov = 45.0
	elif _blend_prep < 1.0:
		_blend_prep = minf(1.0, _blend_prep + delta / CAM_BLEND)
		camera.global_transform = _from.interpolate_with(_to_prep, ease(_blend_prep, -2.0))


func _process(delta: float) -> void:
	if cam_free and not get_tree().paused:
		_pad_camera(delta)
	_place_camera(delta)


func _pad_camera(delta: float) -> void:
	if Input.get_connected_joypads().is_empty():
		return
	var x := Input.get_joy_axis(0, JOY_AXIS_RIGHT_X)
	if absf(x) > 0.25:
		cam_yaw_off = clampf(cam_yaw_off - x * PAD_TURN * delta, -CAM_YAW_SPAN, CAM_YAW_SPAN)


func _unhandled_input(ev: InputEvent) -> void:
	if not cam_free:
		return
	var mb := ev as InputEventMouseButton
	if mb != null and mb.pressed:
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			cam_dist = maxf(CAM_DIST_RANGE.x, cam_dist - 1.5)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			cam_dist = minf(CAM_DIST_RANGE.y, cam_dist + 1.5)
	elif ev is InputEventMouseMotion and ((ev as InputEventMouseMotion).button_mask & Settings.camera_rotate_mask()):
		var mm := ev as InputEventMouseMotion
		var speed := CameraRig.ROTATE_SPEED * float(Settings.get_v("camera", "rotate_speed"))
		cam_yaw_off = clampf(cam_yaw_off - mm.relative.x * speed, -CAM_YAW_SPAN, CAM_YAW_SPAN)
		cam_pitch = clampf(cam_pitch + mm.relative.y * speed * 0.6, CAM_PITCH_RANGE.x, CAM_PITCH_RANGE.y)
