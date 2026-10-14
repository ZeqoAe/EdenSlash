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
	"magnet": Color(0.45, 0.8, 1.0), "greed": Color(1.0, 0.82, 0.3), "challenge": Color(1.0, 0.35, 0.3)}
const STATION_VERBS := {"anvil": "forger (+1 gratuit sur une pièce portée)", "scribe": "choisir un parchemin d'enchantement",
	"well": "boire (tous les PV)", "magnet": "attirer toute l'expérience et le butin",
	"greed": "pacte : +50 % d'or et de butin, monstres +25 %", "challenge": "défi : vaincre une escouade d'élites (coffre de récompense)"}


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
	match kind:
		"chest":
			return "[F] Ouvrir — %s" % title
		"dungeon":
			return "[F] Entrer dans le donjon"
		"tower_chest":
			return "[F] Ouvrir — %s" % title
		"tower_stairs":
			return "[F] Monter — %s" % title
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
