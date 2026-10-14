class_name LootDrop
extends Node3D
## Objet tombé au sol : icône flottante et colonne de lumière à la couleur de
## sa rareté. Ramassé automatiquement quand le héros passe à côté.

const PICKUP_RADIUS := 1.8

var item: Dictionary
var on_picked: Callable
var _player: Player
var _t := 0.0
var _icon: Sprite3D


func _ready() -> void:
	add_to_group("loot")
	_player = get_tree().get_first_node_in_group("player") as Player
	var color: Color = Items.color_of(item)
	_icon = Sprite3D.new()
	if String(item.get("icon", "")) != "" and ResourceLoader.exists(item.icon):
		_icon.texture = load(item.icon)
	_icon.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_icon.pixel_size = 0.012
	_icon.no_depth_test = true
	_icon.position.y = 1.0
	add_child(_icon)
	var beam := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.05
	cyl.bottom_radius = 0.35
	cyl.height = 3.0 + 1.5 * int(item.rarity)
	beam.mesh = cyl
	beam.position.y = cyl.height * 0.5
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.disable_fog = true  # la brume ne s'ajoute pas aux effets lumineux (carrés pâles)
	m.albedo_color = Color(color.r, color.g, color.b, 0.35)
	beam.material_override = m
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(beam)


func _process(delta: float) -> void:
	_t += delta
	_icon.position.y = 1.0 + sin(_t * 3.0) * 0.15
	if _player and not _player.is_dead and _player.global_position.distance_to(global_position) < PICKUP_RADIUS * _player.pickup_mult:
		if Run.pick_up(item):
			Sfx.ui("pickup", -8.0)
			if on_picked.is_valid():
				on_picked.call(item)
			queue_free()
