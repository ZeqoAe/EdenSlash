class_name DamageNumber
extends Label3D
## Chiffre de dégâts flottant au-dessus d'un combattant.


static func spawn(target: Node3D, amount: float, crit: bool, on_player: bool) -> void:
	if not target.is_inside_tree():
		return
	var label := DamageNumber.new()
	label.text = str(int(amount)) + ("!" if crit else "")
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.fixed_size = true
	label.pixel_size = 0.0011
	label.font_size = 52 if crit else 36
	label.outline_size = 14
	label.outline_modulate = Color(0.1, 0.05, 0.1)
	if on_player:
		label.modulate = Color(1.0, 0.35, 0.35)
	elif crit:
		label.modulate = Color(1.0, 0.82, 0.2)
	else:
		label.modulate = Color(1.0, 1.0, 1.0)
	target.get_tree().current_scene.add_child(label)
	var jitter := Vector3(randf_range(-0.4, 0.4), 0.0, randf_range(-0.2, 0.2))
	label.global_position = target.global_position + Vector3.UP * 2.0 + jitter
	var tw := label.create_tween().set_parallel()
	tw.tween_property(label, "global_position", label.global_position + Vector3.UP * 1.2, 0.8) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(label, "modulate:a", 0.0, 0.35).set_delay(0.45)
	tw.chain().tween_callback(label.queue_free)
