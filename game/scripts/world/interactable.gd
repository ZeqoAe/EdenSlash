class_name Interactable
extends Node3D
## Élément avec lequel le héros interagit avec [F] : marchand ambulant, coffre (payant),
## entrée du donjon. Le directeur de run gère l'invite et l'action.

var kind := ""  # merchant, chest, dungeon, ou un lieu (ProcMap.STATIONS : anvil, scribe, well…)
var title := ""
var radius := 3.5
var used := false
var anim: AnimationPlayer
var _label: Label3D

## Lieux utilisables une fois : couleur et ce que fait [F].
const STATION_COLORS := {"anvil": Color(1.0, 0.6, 0.3), "scribe": Color(0.6, 0.75, 1.0), "well": Color(0.5, 1.0, 0.7),
	"magnet": Color(0.3, 1.0, 0.95), "greed": Color(1.0, 0.82, 0.3), "challenge": Color(1.0, 0.35, 0.3),
	"fortune": Color(1.0, 0.6, 0.95), "giant": Color(1.0, 0.38, 0.22)}
const STATION_VERBS := {"anvil": "forger (+1 gratuit sur une pièce portée)", "scribe": "choisir un parchemin d'enchantement",
	"well": "boire (tous les PV)", "magnet": "attirer toute l'expérience et le butin",
	"greed": "pacte : plus d'or, de butin et d'insignes, des monstres plus forts", "challenge": "défi : vaincre une escouade d'élites (coffre de récompense)",
	"fortune": "tenter la pyramide de la fortune (8 étages, une case piégée par étage)",
	"giant": "réveiller un géant (une carte, mais la Menace monte)"}


func setup(p_kind: String, p_title: String, model_path := "", texture_path := "", model_scale := 1.0, p_radius := 3.5) -> void:
	kind = p_kind
	title = p_title
	radius = p_radius
	if model_path != "" and ResourceLoader.exists(model_path):
		var model := EdenModel.instantiate(model_path, texture_path if ResourceLoader.exists(texture_path) else "")
		model.scale = Vector3.ONE * model_scale
		add_child(model)
		anim = EdenModel.find_anim_player(model)
		if anim:
			for a in ["stand01", "battle01"]:
				if anim.has_animation(a):
					anim.get_animation(a).loop_mode = Animation.LOOP_LINEAR
					anim.play(a)
					break
			if kind == "chest" and anim.has_animation("death01"):
				# coffre fermé : première image de l'animation d'ouverture
				anim.play("death01")
				anim.seek(0.0, true)
				anim.pause()
	_label = Label3D.new()
	_label.text = title
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.no_depth_test = true
	_label.fixed_size = true
	_label.pixel_size = 0.0010
	_label.font_size = 30
	_label.outline_size = 9
	_label.modulate = (STATION_COLORS.get(kind, Color(1.0, 0.88, 0.5)) as Color).lightened(0.25) if kind != "chest" else Color(0.95, 0.95, 1.0)
	_label.position.y = 3.2 * model_scale
	_label.visibility_range_end = 28.0 if kind == "chest" else 60.0
	add_child(_label)


func set_title(t: String) -> void:
	title = t
	if _label:
		_label.text = t


func prompt() -> String:
	return _prompt().replace("[F]", "[%s]" % Settings.action_label("interact", 1))


func _prompt() -> String:
	if has_meta("prompt"):  # invite propre (Battle royale : pièce au sol, dépouille) : texte ou Callable
		var p = get_meta("prompt")
		return String(p.call()) if p is Callable else String(p)
	match kind:
		"chest":
			return "[F] Ouvrir — %s" % title
		"dungeon":
			return "[F] Entrer dans le donjon"
		"tower_chest":
			return "[F] Ouvrir — %s" % title
		"tower_stairs":
			return "[F] Monter — %s" % title
		"siege_core":
			return "[F] Prendre le cœur et quitter le duel (récompense moindre)"
		"stage_portal":
			return "[F] Étape suivante — %s" % title
		_ when STATION_VERBS.has(kind):
			return "[F] %s : %s" % [title, STATION_VERBS[kind]]
		_:
			return "[F] Parler à %s" % title


var _beam: Node3D


## Pilier de lumière (visible de loin) et cercle au sol, de la couleur [param col].
func add_beam(col: Color, height := 16.0) -> void:
	_beam = Node3D.new()
	add_child(_beam)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.albedo_color = Color(col, 0.28)
	var pillar := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.25
	cyl.bottom_radius = 0.7
	cyl.height = height
	cyl.radial_segments = 12
	cyl.cap_top = false
	cyl.cap_bottom = false
	pillar.mesh = cyl
	pillar.material_override = mat
	pillar.position.y = height * 0.5
	pillar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pillar.visibility_range_end = 220.0
	_beam.add_child(pillar)
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 2.0
	torus.outer_radius = 2.25
	torus.rings = 32
	ring.mesh = torus
	var rmat := mat.duplicate() as StandardMaterial3D
	rmat.albedo_color = Color(col, 0.75)
	ring.material_override = rmat
	ring.position.y = 0.12
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_beam.add_child(ring)


## Coffre du Battle royale (passe BR2), repérable de loin : halo qui pulse au sol, faisceau qui s'éteint vers le haut,
## quelques étincelles qui montent. Tout est additif et sans lumière dynamique (64 coffres et des vagues) ; [param beam_h]
## est la hauteur du faisceau, [param halo_r] le rayon du halo. Le tout se cache à l'ouverture (même nœud que [method add_beam]).
func add_chest_aura(col: Color, beam_h: float, halo_r: float, sparks := 6) -> void:
	_beam = make_aura(col, beam_h, halo_r, sparks)
	add_child(_beam)


## Montre ou cache l'aura du coffre (le largage n'a la sienne qu'une fois posé).
func set_aura_visible(v: bool) -> void:
	if _beam:
		_beam.visible = v


## L'aura seule (halo, faisceau, étincelles), à poser n'importe où : voir [method add_chest_aura].
static func make_aura(col: Color, beam_h: float, halo_r: float, sparks := 6) -> Node3D:
	var root := Node3D.new()
	var halo := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE * halo_r * 2.0
	halo.mesh = plane
	halo.material_override = _aura_material(_HALO_SHADER, col)
	halo.position.y = 0.18
	halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	halo.visibility_range_end = 150.0
	root.add_child(halo)
	var pillar := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.18
	cyl.bottom_radius = 0.55
	cyl.height = beam_h
	cyl.radial_segments = 10
	cyl.rings = 1
	cyl.cap_top = false
	cyl.cap_bottom = false
	pillar.mesh = cyl
	var bm := _aura_material(_BEAM_SHADER, col)
	bm.set_shader_parameter("height", beam_h)
	pillar.material_override = bm
	pillar.position.y = beam_h * 0.5
	pillar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pillar.visibility_range_end = 260.0
	root.add_child(pillar)
	if sparks > 0:
		var p := CPUParticles3D.new()
		p.amount = sparks
		p.lifetime = 2.4
		p.local_coords = true
		p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
		p.emission_sphere_radius = halo_r * 0.45
		p.direction = Vector3.UP
		p.spread = 8.0
		p.gravity = Vector3.ZERO
		p.initial_velocity_min = 0.5
		p.initial_velocity_max = 1.1
		p.scale_amount_min = 0.5
		p.scale_amount_max = 1.0
		var q := QuadMesh.new()
		q.size = Vector2.ONE * 0.26
		var sm := StandardMaterial3D.new()
		sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		sm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		sm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		sm.vertex_color_use_as_albedo = true
		sm.albedo_color = col.lightened(0.5)
		q.material = sm
		p.mesh = q
		var ramp := Gradient.new()
		ramp.set_color(0, Color(1, 1, 1, 0.0))
		ramp.set_color(1, Color(1, 1, 1, 0.0))
		ramp.add_point(0.25, Color(1, 1, 1, 1.0))
		p.color_ramp = ramp
		p.position.y = 0.4
		p.visibility_range_end = 55.0
		p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(p)
	return root


## Nom du coffre : de la couleur de sa qualité, à hauteur du coffre, lisible à courte portée seulement.
func style_label(col: Color, height: float, range_end := 30.0) -> void:
	if _label == null:
		return
	_label.modulate = col.lightened(0.35)
	_label.position.y = height
	_label.visibility_range_end = range_end
	_label.font_size = 34
	_label.outline_size = 12


static func _aura_material(shader: Shader, col: Color) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = shader
	m.set_shader_parameter("col", col)
	return m


const _BEAM_SHADER: Shader = preload("res://shaders/chest_beam.gdshader")
const _HALO_SHADER: Shader = preload("res://shaders/chest_halo.gdshader")


## Lieu utilisé : son nom s'éteint (le décor reste).
func use_up() -> void:
	used = true
	if _beam:
		_beam.visible = false
	_label.modulate = Color(0.6, 0.6, 0.6)
	_label.text = "%s (utilisé)" % title
	_label.visibility_range_end = 20.0


## Coffre : joue l'ouverture puis disparaît doucement.
func open_chest() -> void:
	used = true
	_label.visible = false
	if _beam:
		_beam.visible = false
	if anim and anim.has_animation("death01"):
		anim.play("death01")
	var tw := create_tween()
	tw.tween_interval(2.5)
	tw.tween_property(self, "scale", Vector3.ONE * 0.01, 0.6)
	tw.tween_callback(queue_free)
