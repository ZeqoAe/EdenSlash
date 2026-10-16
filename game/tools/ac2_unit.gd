extends ClassRival
## AC2 : prototype d'unité d'autochess (« IA v2 ») = ClassRival + corrections minimales mesurées par tools/ac2_probe
## (--mode=bench). À déplacer en ai/autochess_unit.gd au lot AC-E. Corrections (conception/autochess/R_AC2.md §3), chacune
## coupable par opts (ablation) :
##  team / zones : camp par ffa_id : soins et renforts aux équipiers (ClassRival : soi seul), zones des équipiers ignorées ;
##  retreat 0 : pas de repli sous 30 % de PV ; reflex 0 : pas de bond réflexe quand on est touché ;
##  skill_range : sorts choisis selon la distance ; contact : la mêlée colle sa cible en attendant son coup ;
##  range 2 : portée de la classe, sauf auto-attaque de mêlée (Barde, Chantres : 3,2 m au lieu de 10) ;
##  stick (coupé) : plus proche gardé ; read / cancel : esquive de la difficulté (la baisser fait perdre : mesuré).

const RANGED_KEEP := 0.8  # part de la portée de l'arme gardée par un tireur
## Interrupteurs des corrections (banc d'essai, ablation : tools/ac2_probe --v2=read:0.3,reflex:0,…) ; -1 : valeur de la difficulté.
## Valeurs par défaut = meilleure combinaison mesurée (R_AC2 §3.3 : 98 % de victoires contre ClassRival en 3v3 et 5v5 miroir).
static var opts := {"read": -1.0, "cancel": -1.0, "reflex": 0.0, "retreat": 0.0, "stick": 0.0, "contact": 1.0, "range": 2.0,
	"skill_range": 1.0, "team": 1.0, "zones": 1.0}


static func opt(key: String) -> float:
	return float(opts.get(key, 0.0))


## À appeler après setup() / use_sheet().
func ac_tune() -> void:
	cfg = cfg.duplicate()
	if opt("read") >= 0.0:
		cfg["read"] = opt("read")
	if opt("cancel") >= 0.0:
		cfg["cancel"] = opt("cancel")
	if opt("retreat") < 0.5:
		_retreat_ready = INF


func _attack_range() -> float:
	if opt("range") < 0.5:
		return super._attack_range()
	if opt("range") > 1.5:
		# 2 : portée de la classe gardée, sauf auto-attaque de mêlée (Barde, Chantres : 10 m pour une guitare de mêlée)
		return super._attack_range() if auto_step.has("range") else 3.2
	var r := float(auto_step.get("range", 0.0))
	return maxf(6.5, r * RANGED_KEEP) if r > 0.0 else 3.2


func _teammates() -> Array:
	if ffa_id < 0 or opt("team") < 0.5:
		return super._teammates()
	return get_tree().get_nodes_in_group("ffa").filter(func(n): return n is Combatant and n.ffa_id == ffa_id and not n.is_dead)


## Le plus proche, gardé tant qu'il reste à portée ou guère plus loin qu'un autre.
func pick_target(pool: Array, current = null) -> Combatant:
	if opt("stick") < 0.5:
		return super.pick_target(pool, current)
	var best: Combatant = null
	var best_d := INF
	for n in pool:
		var c := n as Combatant
		if c == null or c.is_dead or c == self or c.has_status("invisible"):
			continue
		var d := global_position.distance_to(c.global_position)
		if d < best_d:
			best_d = d
			best = c
	if current != null and is_instance_valid(current) and not current.is_dead and current in pool:
		var dc := global_position.distance_to(current.global_position)
		if dc <= _attack_range() + 1.0 or dc <= best_d + 2.0:
			return current
	return best


## Zones de l'autre camp seulement (ClassRival lisait aussi celles de ses équipiers en chacun pour soi).
func _read_zones() -> void:
	if opt("zones") < 0.5:
		super._read_zones()
		return
	if _time < _zone_check_at or is_invulnerable() or not _can_dodge():
		return
	_zone_check_at = _time + 0.08
	if _seen_zones.size() > 64:
		_seen_zones.clear()
	for n in get_tree().get_nodes_in_group("telegraphs"):
		var tg := n as Telegraph
		if tg == null or tg.is_queued_for_deletion():
			continue
		var src = tg.source
		if is_instance_valid(src) and (src == self or (src.ffa_id >= 0 and src.ffa_id == ffa_id) or (src.ffa_id < 0 and src.team == team)):
			continue
		var iid := tg.get_instance_id()
		if _seen_zones.has(iid) or not tg.contains(global_position, radius):
			continue
		_seen_zones[iid] = true
		var left := tg.delay - tg._t
		if randf() > float(cfg.read) or left < float(cfg.react):
			continue
		var out := global_position - tg.global_position
		out.y = 0.0
		_react_dir = out.normalized() if out.length() > 0.1 else -forward()
		_react_at = _time + clampf(left - DASH_IFRAMES * 0.6, float(cfg.react), maxf(left - 0.04, 0.0))
		return


## Sorts à portée seulement (sinon l'auto-attaque).
func _start_attack() -> void:
	if opt("skill_range") < 0.5 or _player == null:
		super._start_attack()
		return
	var keep := _skills
	var d := global_position.distance_to(_player.global_position) if _player != null else 0.0
	_skills = keep.filter(func(s): return d <= _skill_reach(s))
	super._start_attack()
	_skills = keep


func _skill_reach(s: Dictionary) -> float:
	var kind := String(s.get("kind", "cone"))
	var r := float(s.get("radius", 3.0))
	var rng := float(s.get("range", 0.0))
	if kind in ["bolt", "ground", "line", "fan", "blink"] or rng > r + 1.0:
		return maxf(rng, r) + 0.5
	if kind == "dash":
		return maxf(rng, 6.0) + r
	return r + radius + 0.6


## Pas de bond réflexe sous les coups (ClassRival : 60 % de chances en Difficile, l'unité quittait le combat).
func take_damage(amount: float, source: Combatant = null, crit := false, dot := false) -> void:
	if opt("reflex") >= 0.5:
		super.take_damage(amount, source, crit, dot)
		return
	var keep := _charges
	_charges = 0.0
	super.take_damage(amount, source, crit, dot)
	_charges = keep


## Mêlée qui attend son coup : reste au contact (ClassRival tournait hors de portée du héros, à 4,5 m).
func _update_chase(delta: float) -> Vector3:
	if is_passive() or not _can_target() or flee or goal != Vector3.INF or _ranged() or opt("contact") < 0.5:
		return super._update_chase(delta)
	var ready := _time >= _attack_ready_at and _time >= _dodge_until and not has_status("disarm") and not has_status("fear")
	if ready:
		return super._update_chase(delta)
	var to := _player.global_position - global_position
	to.y = 0.0
	var dist := to.length()
	face_direction(to, delta, 16.0)
	var v := Vector3.ZERO
	if dist > _attack_range():
		v = _path_step(_player.global_position) * move_speed
	if _time >= _dash_until and is_on_floor():
		play(_anim("run", "move02") if v.length() > 0.1 else _battle_anim(), 0.15)
	return v
