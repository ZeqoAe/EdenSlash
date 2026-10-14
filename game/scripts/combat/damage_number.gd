class_name DamageNumber
extends Label3D
## Chiffre de dégâts flottant au-dessus d'un combattant : apparition en « pop » (plus marquée
## pour un critique), légère dérive sur le côté ; les textes (ESQUIVE, états…) qui se suivent
## sur une même cible s'empilent au lieu de se chevaucher.

const STACK_WINDOW := 0.6  # s : un texte plus récent que ça pousse le suivant vers le haut
const STACK_STEP := 0.42  # m entre deux textes empilés
const SAME_TEXT_GAP := 0.5  # s : le même texte sur la même cible ne se répète pas avant
const MAX_ALIVE := 45  # au-delà, seuls les critiques et les dégâts subis par le héros s'affichent

static var alive := 0


## Hauteur d'empilement pour un nouveau texte sur [param target] (et le note).
static func _stack(target: Node3D) -> float:
	var now := Time.get_ticks_msec() / 1000.0
	var recent: Array = (target.get_meta("dn_stack", []) as Array).filter(func(t): return now - float(t) < STACK_WINDOW)
	var h := STACK_STEP * recent.size()
	recent.append(now)
	target.set_meta("dn_stack", recent)
	return h


static func _pop(label: Label3D, big: float) -> Tween:
	label.scale = Vector3.ONE * big
	var tw := label.create_tween().set_parallel()
	tw.tween_property(label, "scale", Vector3.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	return tw


## Texte flottant (ESQUIVE, SAUT, RENVOI...).
static func spawn_text(target: Node3D, text: String, color: Color) -> void:
	if Vfx.silent:
		return
	if not target.is_inside_tree():
		return
	var now := Time.get_ticks_msec() / 1000.0
	var last: Dictionary = target.get_meta("dn_last", {})
	if now - float(last.get(text, -10.0)) < SAME_TEXT_GAP:
		return  # « ESQUIVE ! » en rafale : un seul
	last[text] = now
	target.set_meta("dn_last", last)
	var label := DamageNumber.new()
	label.text = text
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.fixed_size = true
	label.pixel_size = 0.0011
	label.font_size = 32
	label.outline_size = 11
	label.outline_modulate = Color(0.1, 0.05, 0.1)
	label.modulate = color
	target.get_tree().current_scene.add_child(label)
	label.global_position = target.global_position + Vector3.UP * (2.7 + _stack(target))
	var tw := _pop(label, 1.25)
	tw.tween_property(label, "global_position", label.global_position + Vector3.UP * 0.8, 0.8)
	tw.tween_property(label, "modulate:a", 0.0, 0.3).set_delay(0.5)
	tw.chain().tween_callback(label.queue_free)


static func spawn(target: Node3D, amount: float, crit: bool, on_player: bool, dot := false) -> void:
	if Vfx.silent:
		return
	if not target.is_inside_tree():
		return
	var mode := String(Settings.get_v("interface", "damage_numbers"))
	if mode == "off" or (mode == "dealt" and on_player) or (mode == "crit" and not crit and not on_player):
		return
	if alive >= MAX_ALIVE and not crit and not on_player:
		return  # mêlée dense : l'écran reste lisible
	var label := DamageNumber.new()
	label.text = str(int(amount)) + ("!" if crit else "")
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.fixed_size = true
	label.pixel_size = 0.0011
	label.font_size = 54 if crit else (24 if dot else 36)
	label.outline_size = 14 if not dot else 9
	label.outline_modulate = Color(0.1, 0.05, 0.1)
	if on_player:
		label.modulate = Color(1.0, 0.35, 0.35)
	elif crit:
		label.modulate = Color(1.0, 0.82, 0.2)
	else:
		label.modulate = Color(1.0, 1.0, 1.0)
	if dot:
		label.modulate.a = 0.7  # effets sur la durée : discrets
	target.get_tree().current_scene.add_child(label)
	alive += 1
	label.tree_exiting.connect(func(): alive -= 1)
	var side := randf_range(-1.0, 1.0)
	var jitter := Vector3(side * 0.45, 0.0, randf_range(-0.2, 0.2))
	label.global_position = target.global_position + Vector3.UP * 2.0 + jitter
	var tw := _pop(label, 1.6 if crit else 1.25)
	# monte en dérivant du côté où il est apparu (les chiffres d'une rafale s'écartent)
	tw.tween_property(label, "global_position", label.global_position + Vector3(side * 0.5, 1.2, 0.0), 0.8) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(label, "modulate:a", 0.0, 0.35).set_delay(0.5 if crit else 0.45)
	tw.chain().tween_callback(label.queue_free)
