class_name RoyaleCombat
extends RefCounted
## Lisibilité et retours des coups entre héros du Battle royale (lot BR-I3, backlog P1 n° 19 et « chiffres sobres ») :
## - chiffres de dégâts sobres (crochet de DamageNumber.spawn quand Royale.active) : UN nombre par cible qui additionne
##   la rafale (coups, effets sur la durée) pendant BURST s, grossit un peu à chaque coup puis s'efface ; chiffres en
##   M PLUS Rounded 900 contourés d'encre (Bible § 10), « ! » et soleil pour un critique, fraise pour les dégâts subis
##   (dans leur colonne, à gauche) ; plus de « (max) » technique ; réglage « Chiffres de dégâts » respecté ;
## - coup donné par le joueur à un héros : « tic » et courte vibration, « Critique ! » en onomatopée (une fois par
##   CRIT_GAP s) ; élimination : « K.O. ! », éclat d'étoiles et vibration (RoyaleHud) ; coup reçu : arc (HitArc).

const BURST := 0.45  # s : coups additionnés dans un même nombre
const LIFE := 0.55  # s après le dernier coup
const FADE := 0.3
const CRIT_GAP := 1.2
const LANE_TAKEN := -1.4  # m (vers la gauche de l'écran) : dégâts subis par le héros
const LANE_DEALT := 0.9  # m (vers la droite) : à côté de la cible, jamais sur sa plaque
const HEIGHT := 1.7  # m : à hauteur du torse (la plaque est au-dessus de la tête)

static var announce: RoyaleAnnounce  # onomatopées (posé par RoyaleHud)
static var _crit_ms := -100000


## Chiffre sobre : vrai si le nombre est pris en charge ici (DamageNumber n'écrit alors rien).
static func number(target: Node3D, amount: float, crit: bool, on_player: bool, _dot := false) -> bool:
	if not Royale.active or target == null or not target.is_inside_tree():
		return false
	var now := Time.get_ticks_msec()
	var by_me := now - int(target.get_meta("rc_hit_ms", -1000)) < 60  # (Combatant.damaged part juste avant)
	if crit and by_me and now - _crit_ms > int(CRIT_GAP * 1000.0):
		_crit_ms = now
		if announce != null and is_instance_valid(announce):
			announce.word("Critique !", RoyaleHudStyle.SUN)
		RoyaleAmbience.cue("crit")
	var cur = target.get_meta("rc_num") if target.has_meta("rc_num") else null
	if cur is Label3D and is_instance_valid(cur) and not (cur as Node).is_queued_for_deletion() and now - int(cur.get_meta("first", 0)) < int(BURST * 1000.0):
		var l := cur as Label3D
		l.set_meta("total", float(l.get_meta("total")) + amount)
		l.set_meta("hits", int(l.get_meta("hits")) + 1)
		l.set_meta("last", now)
		l.set_meta("crit", bool(l.get_meta("crit")) or crit)
		_refresh(l)
		return true
	var l := Label3D.new()
	l.name = "RoyaleNumber"
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.fixed_size = true
	l.pixel_size = 0.0011
	l.font = UiTheme.number_font()
	l.outline_size = 10
	l.outline_modulate = RoyaleHudStyle.INK
	l.render_priority = 2
	l.outline_render_priority = 1
	l.set_meta("total", amount)
	l.set_meta("hits", 1)
	l.set_meta("first", now)
	l.set_meta("last", now)
	l.set_meta("crit", crit)
	l.set_meta("taken", on_player)
	target.get_tree().current_scene.add_child(l)
	var cam := target.get_viewport().get_camera_3d()
	var right: Vector3 = cam.global_transform.basis.x if cam else Vector3.RIGHT
	l.set_meta("anchor", target.global_position + Vector3.UP * HEIGHT + right * (LANE_TAKEN if on_player else LANE_DEALT))
	l.set_meta("side", right * LANE_DEALT)
	l.global_position = l.get_meta("anchor")
	target.set_meta("rc_num", l)
	_refresh(l)
	var t := l.create_tween()
	t.set_loops()
	t.tween_callback(_tick.bind(l, weakref(target))).set_delay(0.05)
	return true


## Texte, taille et couleur d'un nombre (il grossit d'un point par coup, 6 au plus).
static func _refresh(l: Label3D) -> void:
	var total := float(l.get_meta("total"))
	var crit := bool(l.get_meta("crit"))
	var taken := bool(l.get_meta("taken"))
	l.text = Hud._big_number(roundf(total)) + ("!" if crit else "")
	l.font_size = (30 if taken else (34 if crit else 26)) + mini(int(l.get_meta("hits")) - 1, 6)
	l.modulate = RoyaleHudStyle.danger()[0] if taken else (RoyaleHudStyle.SUN[1] if crit else RoyaleHudStyle.PAPER)
	l.scale = Vector3.ONE * 1.3
	l.create_tween().tween_property(l, "scale", Vector3.ONE, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Vie d'un nombre : monte doucement au-dessus de sa cible, s'efface LIFE s après le dernier coup.
static func _tick(l: Label3D, target: WeakRef) -> void:
	if not is_instance_valid(l):
		return
	var now := Time.get_ticks_msec()
	var age := float(now - int(l.get_meta("first"))) / 1000.0
	var t = target.get_ref()
	var anchor: Vector3 = l.get_meta("anchor")
	if t != null and is_instance_valid(t) and (t as Node3D).is_inside_tree() and not bool(l.get_meta("taken")):
		anchor = (t as Node3D).global_position + Vector3.UP * HEIGHT + (l.get_meta("side") as Vector3)
	l.global_position = anchor + Vector3.UP * minf(age, 1.2) * 0.4
	var idle := float(now - int(l.get_meta("last"))) / 1000.0 - LIFE
	if idle > 0.0:
		l.modulate.a = clampf(1.0 - idle / FADE, 0.0, 1.0)
		if idle >= FADE:
			if t != null and is_instance_valid(t) and (t as Node).get_meta("rc_num", null) == l:
				(t as Node).remove_meta("rc_num")
			l.queue_free()


## Coup reçu par un héros scripté (signal Combatant.damaged) : s'il vient du joueur, « tic » et courte vibration.
static func on_hero_damaged(_amount: float, source: Combatant, who: Combatant, player: Player) -> void:
	if source == null or source != player or not is_instance_valid(who):
		return
	who.set_meta("rc_hit_ms", Time.get_ticks_msec())
	RoyaleAmbience.cue("hit")
