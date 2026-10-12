class_name MapBackdrop
extends Node3D
## Décor 3D des menus : une map d'Eden générée (ciel, brume et lumière de son biome).
## - écran titre (fly_over) : la caméra survole les maps des zones, qui défilent avec un fondu ;
## - lobby (show_zone + hero_root) : vue posée sur la zone choisie, le héros au premier plan.
## Les dernières maps restent en mémoire d'une scène à l'autre (release() avant de changer
## de scène) : le retour au lobby après une run est immédiat.

signal zone_shown(zone: Dictionary)

const FLY_TIME := 15.0
const FADE := 0.7
const CACHE_MAX := 2
const SEED := 7310

static var _cache: Dictionary = {}  # "biome:graine" -> ProcMap (hors de l'arbre)
static var _order: Array = []

var map: ProcMap
var zone: Dictionary = {}
var camera: Camera3D
var env: Environment
var sun: DirectionalLight3D
var hero_root: Node3D  # lobby : le héros, posé dans la map face à la caméra
var _fade: ColorRect
var _fly := false
var _fly_zones: Array = []
var _fly_index := -1
var _t := 0.0
var _from := Vector3.ZERO
var _to := Vector3.ZERO
var _switching := false
var _snap: SubViewport
var _released := false


func _ready() -> void:
	var sky_mat := ProceduralSkyMaterial.new()
	var sky := Sky.new()
	sky.sky_material = sky_mat
	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_energy = 0.6
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 0.85
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.12
	env.adjustment_saturation = 1.2
	env.glow_enabled = true
	env.glow_intensity = 0.35
	env.glow_hdr_threshold = 1.2
	env.fog_enabled = true
	env.fog_sky_affect = 0.2
	Gfx.style_sky(sky_mat)
	Gfx.style_environment(env)
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -35, 0)
	sun.light_energy = 1.25
	sun.shadow_enabled = true
	sun.shadow_opacity = 0.65
	sun.directional_shadow_max_distance = 90.0
	add_child(sun)
	Gfx.style_sun(sun)
	camera = Camera3D.new()
	camera.fov = 50.0
	camera.far = 900.0
	add_child(camera)
	camera.make_current()
	hero_root = Node3D.new()
	add_child(hero_root)
	var layer := CanvasLayer.new()  # fondu au noir, sous les menus
	layer.layer = 0
	add_child(layer)
	_fade = ColorRect.new()
	_fade.color = Color(0.02, 0.01, 0.05, 1.0)
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_fade)
	_apply_env({})


## Map d'une zone (générée ou reprise du cache), ambiance de son biome.
func show_zone(zone_id: String, with_minimap := false) -> void:
	zone = GameData.zone(zone_id)
	var biome := String(zone.get("biome", "limestone"))
	var key := "%s:%d" % [biome, SEED]
	if map:
		_stash(map)
		map = null
	var cached = _cache.get(key)
	var m: ProcMap = cached if cached != null and is_instance_valid(cached) else null
	if m == null or (with_minimap and m.minimap_info().texture == null):
		if m != null and not m.is_inside_tree():
			m.free()
		m = ProcMap.new()
		m.biome = biome
		add_child(m)
		m.generate_scenery(SEED, with_minimap)
		_cache[key] = m
	else:
		add_child(m)
	_order.erase(key)
	_order.append(key)
	_trim_cache()
	map = m
	_apply_env(GameData.biomes.get(biome, {}).get("env", {}))
	zone_shown.emit(zone)


## Écran titre : survol des zones [param zone_ids], l'une après l'autre.
func fly_over(zone_ids: Array) -> void:
	_fly = true
	_fly_zones = zone_ids
	_fly_index = -1
	_next_flight(true)


## Lobby : le héros sur le point de départ de la map, la caméra face à lui, le paysage
## (vers le village) derrière ; [param screen_offset] décale le héros vers la droite.
func stage_hero(screen_offset := 1.5) -> void:
	_fly = false
	var h := map.start
	var look := map.village if map.village != Vector3.INF else Vector3(map.size * 0.5, 0, map.size * 0.5)
	var away := Vector3(h.x - look.x, 0, h.z - look.z).normalized()
	if away == Vector3.ZERO:
		away = Vector3.BACK
	h.y = map.height_at(h.x, h.z)
	hero_root.position = h
	hero_root.rotation.y = atan2(away.x, away.z)
	var right := away.cross(Vector3.UP).normalized()
	var cam := h + away * 5.2 + Vector3.UP * 1.7
	cam.y = maxf(cam.y, map.height_at(cam.x, cam.z) + 1.2)
	camera.fov = 42.0
	camera.position = cam
	camera.look_at(h + Vector3.UP * 1.25 + right * screen_offset)
	sun.directional_shadow_max_distance = 40.0
	_fade_to(0.0)


## Lobby : changement de zone avec un fondu (la génération se fait dans le noir).
func change_zone(zone_id: String, then := Callable()) -> void:
	_fade_to(1.0, func():
		await get_tree().process_frame
		show_zone(zone_id, true)
		stage_hero()
		if then.is_valid():
			then.call())


## Image de la zone (vue haute depuis le village), rendue une fois dans une SubViewport.
func snapshot(px := Vector2i(420, 150)) -> Texture2D:
	if _snap and is_instance_valid(_snap):
		_snap.queue_free()
	var vp := SubViewport.new()
	_snap = vp
	vp.size = px
	vp.world_3d = get_world_3d()
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	vp.msaa_3d = Viewport.MSAA_2X
	add_child(vp)
	var cam := Camera3D.new()
	cam.fov = 55.0
	cam.far = 900.0
	vp.add_child(cam)
	var a := map.village if map.village != Vector3.INF else map.start
	var b := map.start if a != map.start else Vector3(map.size * 0.5, 0, map.size * 0.5)
	var dir := Vector3(b.x - a.x, 0, b.z - a.z).normalized()
	var p := a - dir * 28.0
	p.y = map.height_at(p.x, p.z) + 14.0
	cam.position = p
	var target := a + dir * 30.0
	target.y = map.height_at(target.x, target.z) + 2.0
	cam.look_at(target)
	cam.current = true
	return vp.get_texture()


## Avant de changer de scène : la map reste en mémoire pour la scène suivante.
func release() -> void:
	_released = true
	if map:
		_stash(map)
		map = null


## Sortie sans release() (fermeture du jeu, tests) : le cache est vidé.
func _exit_tree() -> void:
	if _released:
		return
	for k in _cache.keys():
		var m = _cache[k]
		if m != null and is_instance_valid(m) and not m.is_inside_tree() and m != map:
			m.free()
	_cache.clear()
	_order.clear()


func _stash(m: ProcMap) -> void:
	if m.get_parent():
		m.get_parent().remove_child(m)


static func _trim_cache() -> void:
	while _order.size() > CACHE_MAX:
		var old: String = _order.pop_front()
		var m = _cache.get(old)
		_cache.erase(old)
		if m != null and is_instance_valid(m) and not m.is_inside_tree():
			m.free()


func _apply_env(e: Dictionary) -> void:
	var c := func(k: String, def: Color) -> Color:
		var a: Array = e.get(k, [])
		return Color(a[0], a[1], a[2]) if a.size() >= 3 else def
	var sky_mat := env.sky.sky_material as ProceduralSkyMaterial
	sky_mat.sky_top_color = c.call("sky_top", Color(0.36, 0.58, 0.9))
	sky_mat.sky_horizon_color = c.call("horizon", Color(0.82, 0.88, 0.95))
	sky_mat.ground_horizon_color = sky_mat.sky_horizon_color.darkened(0.15)
	sky_mat.ground_bottom_color = Color(0.3, 0.38, 0.28)
	env.fog_light_color = c.call("fog", Color(0.85, 0.89, 0.91))
	env.fog_density = float(e.get("fog_density", 0.0018))
	env.ambient_light_color = c.call("ambient", Color(0.78, 0.78, 0.82))
	sun.light_color = c.call("sun", Color(1.0, 0.96, 0.88))


func _fade_to(a: float, then := Callable()) -> void:
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", a, FADE)
	if then.is_valid():
		tw.tween_callback(then)


# --- survol -----------------------------------------------------------------------------
func _next_flight(first := false) -> void:
	_switching = true
	if first:
		_fade.color.a = 1.0
		_load_flight.call_deferred()
	else:
		_fade_to(1.0, _load_flight)


func _load_flight() -> void:
	await get_tree().process_frame  # l'écran est noir : la génération ne se voit pas
	_fly_index = (_fly_index + 1) % maxi(_fly_zones.size(), 1)
	show_zone(String(_fly_zones[_fly_index]) if not _fly_zones.is_empty() else "limestone")
	# trajet : départ -> village, ou village -> entrée du donjon (une zone sur deux)
	var pts := [map.start, map.village, map.dungeon].filter(func(p): return p != Vector3.INF)
	var a: Vector3 = pts[_fly_index % pts.size()]
	var b: Vector3 = pts[(_fly_index + 1) % pts.size()]
	var dir := Vector3(b.x - a.x, 0, b.z - a.z)
	if dir.length() < 40.0:
		dir = dir.normalized() * 120.0 if dir.length() > 0.1 else Vector3(120, 0, 0)
	_from = a - dir.normalized() * 30.0
	_to = a + dir * 0.85
	_t = 0.0
	camera.fov = 50.0
	env.fog_density *= 0.45  # vue haute et lointaine : moins de brume
	sun.directional_shadow_max_distance = 120.0
	_place_fly_camera()
	_switching = false
	_fade_to(0.0)


func _place_fly_camera() -> void:
	var k := clampf(_t / FLY_TIME, 0.0, 1.0)
	var p := _from.lerp(_to, k)
	var dir := (_to - _from).normalized()
	var side := dir.cross(Vector3.UP).normalized() * sin(_t * 0.25) * 6.0
	p += side
	var ground := maxf(map.height_at(p.x, p.z), map.height_at(p.x + dir.x * 20.0, p.z + dir.z * 20.0))
	p.y = ground + 13.0
	camera.position = camera.position.lerp(p, 0.08) if _t > 0.0 else p
	var target := p + dir * 30.0
	target.y = map.height_at(target.x, target.z) + 3.0
	camera.look_at(target)


func _process(delta: float) -> void:
	if not _fly or map == null or _switching:
		return
	_t += delta
	_place_fly_camera()
	if _t > FLY_TIME - FADE:
		_next_flight()
