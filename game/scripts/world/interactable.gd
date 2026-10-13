class_name Interactable
extends Node3D
## Élément avec lequel le héros interagit avec [F] : marchand ambulant, coffre (payant),
## entrée du donjon. Le directeur de run gère l'invite et l'action.

var kind := ""  # merchant, chest, dungeon
var title := ""
var radius := 3.5
var used := false
var anim: AnimationPlayer
var _label: Label3D


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
	_label.modulate = Color(1.0, 0.88, 0.5) if kind != "chest" else Color(0.95, 0.95, 1.0)
	_label.position.y = 3.2 * model_scale
	_label.visibility_range_end = 28.0 if kind == "chest" else 60.0
	add_child(_label)


func set_title(t: String) -> void:
	title = t
	if _label:
		_label.text = t


func prompt() -> String:
	match kind:
		"chest":
			return "[F] Ouvrir — %s" % title
		"dungeon":
			return "[F] Entrer dans le donjon"
		"tower_chest":
			return "[F] Ouvrir — %s" % title
		"tower_stairs":
			return "[F] Monter — %s" % title
		_:
			return "[F] Parler à %s" % title


## Coffre : joue l'ouverture puis disparaît doucement.
func open_chest() -> void:
	used = true
	_label.visible = false
	if anim and anim.has_animation("death01"):
		anim.play("death01")
	var tw := create_tween()
	tw.tween_interval(2.5)
	tw.tween_property(self, "scale", Vector3.ONE * 0.01, 0.6)
	tw.tween_callback(queue_free)
