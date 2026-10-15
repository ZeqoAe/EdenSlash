class_name DamageNumber
extends Label3D
## Chiffre de dégâts flottant au-dessus d'un combattant : apparition en « pop » (plus marquée
## pour un critique), légère dérive sur le côté ; les textes (ESQUIVE, états…) qui se suivent
## sur une même cible s'empilent au lieu de se chevaucher.

const STACK_WINDOW := 0.6  # s : un texte plus récent que ça pousse le suivant vers le haut
const STACK_STEP := 0.42  # m entre deux textes empilés
const SAME_TEXT_GAP := 0.5  # s : le même texte sur la même cible ne se répète pas avant
const MAX_ALIVE := 24  # chiffres à l'écran : au-delà, seuls les critiques et les dégâts subis par le héros s'affichent
const MAX_ALIVE_CRIT := 34  # puis plus que les dégâts subis par le héros
const BUDGET_WINDOW := 0.3  # s : une grosse zone qui touche 20 monstres d'un coup n'écrit pas 20 chiffres
const BUDGET := 8
const BUDGET_CRIT := 12
const LANES := [0.0, 0.8, -0.8, 1.6, -1.6]  # m (sur l'écran) : les chiffres successifs d'une cible se rangent en colonnes, ils ne se chevauchent pas
const LANE_RISE := 0.38  # m : au-delà d'une rangée de colonnes pleine en 0,5 s, les chiffres montent d'un cran
const PLAYER_LANE := -1.5  # m : les dégâts subis par le héros ont leur colonne, à gauche, loin de ceux qu'il inflige

static var alive := 0
static var _window_t := 0.0
static var _window_n := 0


## Hauteur d'empilement pour un nouveau texte sur [param target] (et le note).
static func _stack(target: Node3D) -> float:
	var now := Time.get_ticks_msec() / 1000.0
	var recent: Array = (target.get_meta("dn_stack", []) as Array).filter(func(t): return now - float(t) < STACK_WINDOW)
	var h := STACK_STEP * recent.size()
	recent.append(now)
	target.set_meta("dn_stack", recent)
	return h


## Décalage (x sur l'écran, y en hauteur) d'un nouveau chiffre de [param target] : colonne suivante, et plus haut
## quand la rafale dépasse le nombre de colonnes.
static func _slot(target: Node3D, on_player: bool) -> Vector3:
	var now := Time.get_ticks_msec() / 1000.0
	var recent: Array = (target.get_meta("dn_recent", []) as Array).filter(func(t): return now - float(t) < 0.5)
	recent.append(now)
	target.set_meta("dn_recent", recent)
	var n := int(target.get_meta("dn_n", 0))
	target.set_meta("dn_n", n + 1)
	var cam := target.get_viewport().get_camera_3d()
	var right: Vector3 = cam.global_transform.basis.x if cam else Vector3.RIGHT
	var x: float = PLAYER_LANE if on_player else float(LANES[n % LANES.size()])
	var rise := LANE_RISE * floorf(float(recent.size() - 1) / LANES.size())
	return right * x + Vector3.UP * rise


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
	label.outline_size = 12
	label.outline_modulate = Color(0.1, 0.05, 0.1)
	label.modulate = color.lightened(0.25)  # rouge sombre ou violet sur une zone rouge : trop peu de contraste sans
	target.get_tree().current_scene.add_child(label)
	label.global_position = target.global_position + Vector3.UP * (2.7 + _stack(target))
	var tw := _pop(label, 1.25)
	tw.tween_property(label, "global_position", label.global_position + Vector3.UP * 0.8, 0.8)
	tw.tween_property(label, "modulate:a", 0.0, 0.3).set_delay(0.5)
	tw.chain().tween_callback(label.queue_free)


static func spawn(target: Node3D, amount: float, crit: bool, on_player: bool, dot := false, capped := false) -> void:
	if Vfx.silent:
		return
	if not target.is_inside_tree():
		return
	var mode := String(Settings.get_v("interface", "damage_numbers"))
	if mode == "off" or (mode == "dealt" and on_player) or (mode == "crit" and not crit and not on_player):
		return
	if not on_player:
		if alive >= (MAX_ALIVE_CRIT if crit else MAX_ALIVE):
			return  # mêlée dense : l'écran reste lisible
		var now := Time.get_ticks_msec() / 1000.0
		if now - _window_t > BUDGET_WINDOW:
			_window_t = now
			_window_n = 0
		_window_n += 1
		if _window_n > (BUDGET_CRIT if crit else BUDGET):
			return
	var label := DamageNumber.new()
	label.text = str(int(amount)) + ("!" if crit else "")
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.fixed_size = true
	label.pixel_size = 0.0011
	var crowd := clampf(float(alive) / MAX_ALIVE_CRIT, 0.0, 1.0)  # mêlée dense : les chiffres rapetissent (les dégâts subis non)
	label.font_size = 42 if on_player else (roundi(56.0 - 14.0 * crowd) if crit else (22 if dot else roundi(36.0 - 10.0 * crowd)))
	label.outline_size = 14 if not dot else 9
	label.outline_modulate = Color(0.1, 0.05, 0.1)
	if on_player:
		label.modulate = Color(1.0, 0.35, 0.35)
	elif crit:
		label.modulate = Color(1.0, 0.82, 0.2)
	else:
		label.modulate = Color(1.0, 1.0, 1.0)
	if capped:
		label.modulate = Color(0.68, 0.68, 0.74)  # « il a encaissé le max » : plafond par coup ou rafale du duel
		label.text += " (max)"
	if dot:
		label.modulate.a = 0.7  # effets sur la durée : discrets
	target.get_tree().current_scene.add_child(label)
	alive += 1
	label.tree_exiting.connect(func(): alive -= 1)
	var slot := _slot(target, on_player)
	label.global_position = target.global_position + Vector3.UP * (2.4 if on_player else 2.0) + slot
	var tw := _pop(label, 1.6 if crit else 1.25)
	# monte en gardant sa colonne (les chiffres d'une rafale restent côte à côte)
	tw.tween_property(label, "global_position", label.global_position + Vector3(0.0, 1.2, 0.0), 0.8) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(label, "modulate:a", 0.0, 0.35).set_delay(0.5 if crit else 0.45)
	tw.chain().tween_callback(label.queue_free)
