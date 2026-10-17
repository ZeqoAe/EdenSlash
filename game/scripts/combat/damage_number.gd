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

## Survivant (lot SVX-1, SV-H2 : dans une horde, des chiffres empilés en tas illisibles) : UN nombre par cible, qui
## additionne les coups et grossit (texte remis à jour toutes les AGG_STEP s au plus), s'efface AGG_LIFE s après le dernier
## coup ; Survivor.NUMBERS_MAX nombres à l'écran au plus (les dégâts subis par le héros passent toujours) ; « EXÉCUTÉ »
## devient une croix fraise. Ailleurs, rien ne change.
const AGG_STEP := 0.15
const AGG_LIFE := 0.7
const AGG_FADE := 0.3
const EXECUTE_ICON := "×"
const TAKEN_SIDE := -2.2  # m : les dégâts subis par le héros, à gauche et au-dessus de la mêlée
const TAKEN_UP := 3.1
var total := 0.0
var hits := 0
var merged := false
var taken := false  # nombre des dégâts subis par le héros
var _crit := false
var _born := 0.0
var _hit_at := 0.0
var _shown_at := -1.0
var _dirty := false
var _target: WeakRef
var _anchor := Vector3.ZERO


func _ready() -> void:
	set_process(merged)


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
	if NetEvents.on:
		NetEvents.emit(NetEvents.TEXT, target, [text, color])  # (lot NET-A) Mode amis : l'hôte rejoue l'effet chez ses amis
	if Vfx.muted(target):
		return
	if not target.is_inside_tree():
		return
	var now := Time.get_ticks_msec() / 1000.0
	if Survivor.active and not target is Player:
		if alive >= Survivor.NUMBERS_MAX or _crowded(target, false):
			return  # (horde : l'écran reste lisible, jamais un mot sur un nombre)
		if text == "EXÉCUTÉ":
			text = EXECUTE_ICON
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
	label.pixel_size = 0.0011 * size_mult()
	label.font_size = 32
	label.outline_size = 12
	label.outline_modulate = Color(0.1, 0.05, 0.1)
	label.modulate = color.lightened(0.25)  # rouge sombre ou violet sur une zone rouge : trop peu de contraste sans
	if text == EXECUTE_ICON:
		label.font_size = 52
		label.modulate = Color(1.0, 0.3, 0.43)  # fraise
	target.get_tree().current_scene.add_child(label)
	if Survivor.active:
		alive += 1  # (Survivant : les textes comptent dans le plafond de l'écran)
		label.tree_exiting.connect(func(): alive -= 1)
	label.global_position = target.global_position + Vector3.UP * (2.7 + _stack(target))
	var tw := _pop(label, 1.25)
	tw.tween_property(label, "global_position", label.global_position + Vector3.UP * 0.8, 0.8)
	tw.tween_property(label, "modulate:a", 0.0, 0.3).set_delay(0.5)
	tw.chain().tween_callback(label.queue_free)


static func spawn(target: Node3D, amount: float, crit: bool, on_player: bool, dot := false, capped := false) -> void:
	if NetEvents.on:
		NetEvents.emit(NetEvents.DMG, target, [amount, crit, on_player, dot, capped])  # (lot NET-A) Mode amis : l'hôte rejoue l'effet chez ses amis
	if Vfx.muted(target):
		return
	if not target.is_inside_tree():
		return
	var mode := String(Settings.get_v("interface", "damage_numbers"))
	if mode == "off" or (mode == "dealt" and on_player) or (mode == "crit" and not crit and not on_player):
		return
	if Survivor.active:
		_merge(target, amount, crit, on_player)
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
	label.pixel_size = 0.0011 * size_mult()
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


## Survivant : ajoute [param amount] au nombre de [param target] (créé s'il n'y en a pas, dans la limite de l'écran ; les
## dégâts subis par le héros, [param on_player], passent toujours, en fraise, dans leur colonne à gauche).
static func _merge(target: Node3D, amount: float, crit: bool, on_player: bool) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	var cur = target.get_meta("dn_merge") if target.has_meta("dn_merge") else null
	if cur is DamageNumber and is_instance_valid(cur) and not (cur as DamageNumber).is_queued_for_deletion():
		var n := cur as DamageNumber
		n.total += amount
		n.hits += 1
		n._crit = n._crit or crit
		n._hit_at = now
		n._dirty = true
		if now - n._shown_at >= AGG_STEP:
			n._refresh(now)
		return
	if alive >= Survivor.NUMBERS_MAX and not on_player:
		return  # (horde : 30 nombres à l'écran au plus)
	if not on_player and _crowded(target, crit):
		return  # (une place d'écran déjà prise par le nombre d'un voisin : pas de tas illisible)
	var label := DamageNumber.new()
	label.merged = true
	label.taken = on_player
	label.total = amount
	label.hits = 1
	label._crit = crit
	label._born = now
	label._hit_at = now
	label._target = weakref(target)
	label._anchor = target.global_position
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.fixed_size = true
	label.pixel_size = 0.0011 * size_mult()
	label.outline_size = 12
	label.outline_modulate = Color(0.1, 0.05, 0.1)
	target.get_tree().current_scene.add_child(label)
	alive += 1
	_live.append(label)
	label.tree_exiting.connect(func():
		alive -= 1
		_live.erase(label))
	target.set_meta("dn_merge", label)
	label._refresh(now)
	label._follow(now)


## Survivant : un nombre nouveau au-dessus de [param target] tomberait sur celui d'un voisin (à moins de SPOT_PX à l'écran,
## en largeur et en hauteur) ; un critique ne cède qu'à un autre critique.
const SPOT_PX := Vector2(78.0, 34.0)
static var _live: Array[DamageNumber] = []  # nombres fusionnés à l'écran


static func _crowded(target: Node3D, crit: bool) -> bool:
	var cam := target.get_viewport().get_camera_3d()
	if cam == null:
		return false
	var at := cam.unproject_position(target.global_position + Vector3.UP * 2.0)
	for lab: DamageNumber in _live:
		if not is_instance_valid(lab) or lab.taken or lab.is_queued_for_deletion() or (crit and not lab._crit):
			continue
		var p := cam.unproject_position(lab.global_position)
		if absf(p.x - at.x) < SPOT_PX.x and absf(p.y - at.y) < SPOT_PX.y:
			return true
	return false


## Texte et taille du nombre fusionné : il grossit avec les coups (jusqu'à +14 points), « ! » et soleil dès un critique.
func _refresh(now: float) -> void:
	_shown_at = now
	_dirty = false
	text = str(int(total)) + ("!" if _crit else "")
	font_size = mini((30 if _crit else 24) + 2 * (hits - 1), 44) if not taken else 40
	modulate = Color(1.0, 0.35, 0.35) if taken else (Color(1.0, 0.82, 0.2) if _crit else Color.WHITE)
	scale = Vector3.ONE * 1.25
	create_tween().tween_property(self, "scale", Vector3.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _process(_delta: float) -> void:
	if not merged:
		return
	var now := Time.get_ticks_msec() / 1000.0
	if _dirty and now - _shown_at >= AGG_STEP:
		_refresh(now)
	_follow(now)
	var idle := now - _hit_at - AGG_LIFE
	if idle > 0.0:
		modulate.a = 1.0 - idle / AGG_FADE
		if idle >= AGG_FADE:
			var t: Object = _target.get_ref() if _target else null
			if t != null and is_instance_valid(t) and t.get_meta("dn_merge", null) == self:
				t.remove_meta("dn_merge")
			queue_free()


## Au-dessus de la cible tant qu'elle est là (sinon à sa dernière place), en montant doucement.
func _follow(now: float) -> void:
	var t: Object = _target.get_ref() if _target else null
	if t != null and is_instance_valid(t) and (t as Node3D).is_inside_tree():
		_anchor = (t as Node3D).global_position
	var side := Vector3.ZERO
	if taken:
		var cam := get_viewport().get_camera_3d()
		side = (cam.global_transform.basis.x if cam else Vector3.RIGHT) * TAKEN_SIDE
	global_position = _anchor + side + Vector3.UP * ((TAKEN_UP if taken else 2.0) + minf(0.7, (now - _born) * 0.6))


## Taille des nombres et textes flottants (lot SVX-4, SV-A1 : réglage interface/number_size, 0,8 / 1 / 1,3).
static func size_mult() -> float:
	return clampf(float(Settings.get_v("interface", "number_size")), 0.6, 1.6)
