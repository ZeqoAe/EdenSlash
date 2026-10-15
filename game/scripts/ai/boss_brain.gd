class_name BossBrain
extends Node
## Attaques spéciales d'un boss, toutes annoncées au sol (Telegraph) :
##   écrasements en cercle sur le héros, charge en ligne, balayage en cône au
##   corps à corps, salve de projectiles à distance, onde circulaire.
## Sous 50 % de PV : fureur (annonces plus courtes, onde régulière).
## Mécaniques propres au boss : des briques (BossBricks), déclenchées ici (_update_mechanics) ; boss de la
## bibliothèque (BossLibrary) : setup_bricks, sinon setup (mécaniques de la zone).

signal enraged_phase
## Seuil de la 2e phase (part des PV) : repère sur la barre du boss (HUD).
const PHASE2_AT := 0.5
## Annonce d'une mécanique propre au boss (texte affiché par le directeur de run).
signal announce(text: String)

var boss: Monster
var _cooldown := 2.5
var _nova_timer := 0.0
var _phase2 := false
var _busy := false
var _reflect_timer := 12.0
var reflecting := false
var _reflect_ring: Node3D
# --- mécaniques (briques, BossBricks) ---------------------------------------------------------
## Boss de zone d'avant : noms de data/zones.json -> dungeon.mechanics (adds, puddles, meteors, stomp, clones, totems,
## lasers, pet, vortex, reflect), traduits en briques. Boss de la bibliothèque (BossLibrary) : briques de data/bosses.json.
var mechanics: Array = []
var bricks: Array = []  # briques normalisées (BossBricks.normalize)
var kit: Array = KIT  # attaques de base permises
var hazard_style := "lava"
var director: Node
var pace := 1.0  # rythme des briques périodiques (× leur intervalle) : palier, rage, impatience
var hit_cap := 0.0  # > 0 : un coup du boss retire au plus cette part des PV max du héros (bibliothèque)
var home := Vector3.ZERO  # centre de l'arène (position d'apparition)
var wall: Node3D  # mur de l'arène qui se resserre (brique « shrink »)
var barrier_left := 0.0  # barrière (brique « barrier ») : PV qu'elle absorbe encore
var _barrier_max := 0.0
var _barrier_ring: MeshInstance3D
var _last_hp := 0.0
var _stagger := 0.0
var _brick_t: Array = []
var _thresholds_done := {}
var _totems: Array = []
const KIT := ["slams", "charge", "cleave", "barrage", "nova"]


## Mécaniques du boss d'après la salle (zone) ; [param dir] : directeur de run (invocations).
func setup(dungeon: Dictionary, dir: Node) -> void:
	mechanics = dungeon.get("mechanics", [])
	hazard_style = String(dungeon.get("hazard", "lava"))
	director = dir
	if not mechanics.is_empty() and not "reflect" in mechanics:
		_reflect_timer = 1.0e9  # le miroir n'est qu'une mécanique parmi d'autres
	_init_bricks(BossBricks.from_legacy(mechanics, dungeon))


## Boss de la bibliothèque : briques [param list] (déjà normalisées), attaques de base [param base_kit], rythme [param p_pace],
## plafond d'un coup [param cap] (part des PV max du héros). Le miroir n'existe que comme brique.
func setup_bricks(list: Array, dir: Node, style: String, base_kit: Array, p_pace: float, cap: float) -> void:
	director = dir
	hazard_style = style
	kit = base_kit if not base_kit.is_empty() else KIT
	pace = p_pace
	hit_cap = cap
	_reflect_timer = 1.0e9
	_init_bricks(list)


func _init_bricks(list: Array) -> void:
	bricks = list.filter(func(b): return not (b as Dictionary).is_empty())
	home = boss.global_position if is_instance_valid(boss) and boss.is_inside_tree() else Vector3.ZERO
	_brick_t = []
	for br in bricks:
		_brick_t.append(float(br.first))
	for br in bricks:
		if String(br.kind) in ["start", "passive"]:
			BossBricks.run(self, br)


## Nom court du boss (sans « <Boss> » ni titre : « Latif »), pour les annonces.
func short_name() -> String:
	return boss.display_name.trim_prefix("<Boss> ").get_slice(",", 0) if is_instance_valid(boss) else ""


## Point au sol le plus proche de [param p] (arène), sinon [param p].
func ground(p: Vector3) -> Vector3:
	if director != null and director.has_method("ground_point"):
		return director.ground_point(p, p)
	return p


## Le boss chancelle [param t] s : ni attaque ni mécanique (barrière brisée).
func stagger(t: float) -> void:
	_stagger = maxf(_stagger, t)
	boss.add_status("stun", t)


func _physics_process(delta: float) -> void:
	if boss == null or boss.is_dead or _busy:
		return
	if _stagger > 0.0:
		_stagger -= delta
		return
	var player := boss._player
	if player == null or player.is_dead:
		return
	if not _phase2 and boss.hp < boss.max_hp * PHASE2_AT:
		_phase2 = true
		enraged_phase.emit()
		_cast_nova()
		return
	if _update_mechanics(delta):
		return
	_cooldown -= delta
	_nova_timer -= delta
	_reflect_timer -= delta
	if _reflect_timer <= 0.0:
		_start_reflect()
		return
	if _cooldown > 0.0 or boss._state == "attack":
		return
	var d := boss.global_position.distance_to(player.global_position)
	if d > 32.0:
		return
	if _phase2 and _nova_timer <= 0.0 and "nova" in kit:
		_cast_nova()
	elif d < 8.0 and randf() < 0.45 and "cleave" in kit:
		_cast_cleave()
	elif d > 10.0 and randf() < 0.5 and "barrage" in kit:
		_cast_barrage()
	elif randf() < 0.5 and "charge" in kit:
		_cast_charge()
	elif "slams" in kit:
		_cast_slams()
	else:
		_cooldown = 1.0  # attaque tirée absente du jeu de base de ce boss : il frappe au corps à corps


func _speed() -> float:
	return 0.75 if _phase2 else 1.0


func _begin(anim_name: String, duration: float) -> void:
	_busy = true
	boss.begin_cast()
	for a in [anim_name, "magic01", "attack01"]:
		if boss.has_anim(a):
			boss.play(a, 0.1, 1.0, true)
			break
	await boss.get_tree().create_timer(duration, false).timeout
	if is_instance_valid(boss) and not boss.is_dead:
		boss.end_cast()
	_busy = false
	_cooldown = randf_range(1.6, 2.6) * _speed()


## Dégâts d'une attaque (× l'attaque du boss) ; boss de la bibliothèque : jamais plus de [member hit_cap] des PV max
## de sa cible (pas de mort en un coup).
func _dmg(mult: float) -> float:
	var d := boss.atk * mult
	var t: Combatant = boss._player
	if hit_cap > 0.0 and is_instance_valid(t):
		d = minf(d, t.max_hp * hit_cap)
	return d


## Dégâts par seconde d'une zone persistante (× l'attaque) ; bibliothèque : au plus un tiers du plafond d'un coup par seconde.
func _dps(mult: float) -> float:
	var d := boss.atk * mult
	var t: Combatant = boss._player
	if hit_cap > 0.0 and is_instance_valid(t):
		d = minf(d, t.max_hp * hit_cap / 3.0)
	return d


# --- miroir : 3 s pendant lesquelles les coups reçus sont renvoyés ------------------------
func _start_reflect() -> void:
	_reflect_timer = 17.0 if not _phase2 else 12.0
	reflecting = true
	boss.message_reflect()
	_reflect_ring = MeshInstance3D.new()
	var t := TorusMesh.new()
	t.inner_radius = boss.radius + 0.6
	t.outer_radius = boss.radius + 1.0
	(_reflect_ring as MeshInstance3D).mesh = t
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.disable_fog = true  # la brume ne s'ajoute pas aux effets lumineux (carrés pâles)
	m.albedo_color = Color(1.0, 0.85, 0.3, 0.9)
	(_reflect_ring as MeshInstance3D).material_override = m
	boss.add_child(_reflect_ring)
	_reflect_ring.position.y = 1.2
	var tw := _reflect_ring.create_tween().set_loops(6)
	tw.tween_property(_reflect_ring, "scale", Vector3.ONE * 1.15, 0.25)
	tw.tween_property(_reflect_ring, "scale", Vector3.ONE, 0.25)
	await boss.get_tree().create_timer(3.0, false).timeout
	reflecting = false
	if is_instance_valid(_reflect_ring):
		_reflect_ring.queue_free()


# --- attaques -----------------------------------------------------------------------
func _cast_slams() -> void:
	var delay := 1.3 * _speed()
	_begin("magic01", 0.5 * 3 + delay)
	for i in 3:
		if not is_instance_valid(boss) or boss.is_dead:
			return
		var p := boss._player.global_position
		Telegraph.spawn(boss, p, 0.0, {"shape": "circle", "radius": 4.0, "delay": delay, "damage": _dmg(1.4), "source": boss, "stun_time": 1.2})
		await boss.get_tree().create_timer(0.5, false).timeout


func _cast_charge() -> void:
	var delay := 1.0 * _speed()
	var to := boss._player.global_position - boss.global_position
	to.y = 0.0
	var yaw := atan2(to.x, to.z)
	boss.face_direction(to, 1.0, 100.0)
	var t := Telegraph.spawn(boss, boss.global_position, yaw, {"shape": "line", "length": 18.0, "width": 3.5, "delay": delay, "damage": _dmg(1.8), "source": boss, "stun_time": 1.4})
	_begin("move02", delay + 0.4)
	await t.resolved
	if is_instance_valid(boss) and not boss.is_dead:
		var dest := boss.global_position + to.normalized() * 16.0
		boss.create_tween().tween_property(boss, "global_position", Vector3(dest.x, boss.global_position.y, dest.z), 0.3)


func _cast_cleave() -> void:
	var delay := 0.8 * _speed()
	var to := boss._player.global_position - boss.global_position
	boss.face_direction(to, 1.0, 100.0)
	Telegraph.spawn(boss, boss.global_position, atan2(to.x, to.z), {"shape": "cone", "radius": 7.5, "angle": 110.0, "delay": delay, "damage": _dmg(1.7), "source": boss, "stun_time": 1.0})
	_begin("attack02", delay + 0.3)


func _cast_barrage() -> void:
	var delay := 0.7 * _speed()
	var to := boss._player.global_position - boss.global_position
	to.y = 0.0
	var base := atan2(to.x, to.z)
	boss.face_direction(to, 1.0, 100.0)
	_begin("shoot01", delay + 0.6)
	var dirs: Array[float] = []
	for i in 5:
		var yaw := base + deg_to_rad(-30.0 + 15.0 * i)
		dirs.append(yaw)
		# trait fin : la trajectoire du projectile
		Telegraph.spawn(boss, boss.global_position, yaw, {"shape": "line", "length": 22.0, "width": 0.9, "delay": delay, "damage": 0.0, "source": boss})
	await boss.get_tree().create_timer(delay, false).timeout
	if not is_instance_valid(boss) or boss.is_dead:
		return
	for yaw in dirs:
		Projectile.fire(boss, boss.global_position + Vector3.UP * 1.2, Vector3(sin(yaw), 0, cos(yaw)), _dmg(0.9))


func _cast_nova() -> void:
	_nova_timer = 14.0
	var delay := 1.6 * _speed()
	Telegraph.spawn(boss, boss.global_position, 0.0, {"shape": "ring", "radius": 12.0, "inner": 3.0, "delay": delay, "damage": _dmg(2.0), "source": boss, "jumpable": true, "stun_time": 1.5})
	_begin("magic02", delay + 0.3)


# --- mécaniques de salle (briques) ------------------------------------------------------------
## Renvoie true si une mécanique vient d'être lancée (le boss est occupé).
func _update_mechanics(delta: float) -> bool:
	var ratio := boss.hp / boss.max_hp
	# seuils de PV : une fois chacun (renforts, illusions, totems, barrière, rage…)
	for i in bricks.size():
		var br: Dictionary = bricks[i]
		if String(br.kind) != "at":
			continue
		for th in br.at:
			var key := "%d_%s" % [i, th]
			if ratio < float(th) and not _thresholds_done.has(key):
				_thresholds_done[key] = true
				return BossBricks.run(self, br)
	if boss.shielded:
		_totems = _totems.filter(func(t): return is_instance_valid(t) and not t.is_dead)
		if _totems.is_empty():
			boss.shielded = false
			announce.emit("Bouclier brisé : %s est vulnérable !" % short_name())
	# mécaniques périodiques (plus fréquentes en 2e phase et selon le rythme du palier)
	var k := (0.7 if _phase2 else 1.0) * pace
	for i in bricks.size():
		var br: Dictionary = bricks[i]
		if String(br.kind) != "every" or float(br.every) <= 0.0:
			continue
		_brick_t[i] = float(_brick_t[i]) - delta
		if float(_brick_t[i]) > 0.0 or _busy:
			continue
		_brick_t[i] = float(br.every) * k
		if BossBricks.run(self, br):
			return true
	return false


# --- barrière (brique « barrier ») -------------------------------------------------------------
## Barrière de [param amount] PV : les coups la vident au lieu des PV du boss ; un anneau bleu rétrécit avec elle.
func start_barrier(amount: float) -> void:
	barrier_left = amount
	_barrier_max = amount
	_last_hp = boss.hp
	if not boss.health_changed.is_connected(_on_boss_hp):
		boss.health_changed.connect(_on_boss_hp)
	_barrier_ring = MeshInstance3D.new()
	var t := TorusMesh.new()
	t.inner_radius = boss.radius + 1.0
	t.outer_radius = boss.radius + 1.5
	_barrier_ring.mesh = t
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.disable_fog = true
	m.albedo_color = Color(0.45, 0.8, 1.0, 0.9)
	_barrier_ring.material_override = m
	_barrier_ring.position.y = 1.0
	boss.add_child(_barrier_ring)


func end_barrier() -> void:
	barrier_left = 0.0
	if is_instance_valid(_barrier_ring):
		_barrier_ring.queue_free()


## Coup reçu pendant la barrière : la barrière prend les dégâts (le boss garde ses PV), le surplus passe.
func _on_boss_hp(hp_now: float, _max: float) -> void:
	if barrier_left <= 0.0:
		_last_hp = hp_now
		return
	var lost := _last_hp - hp_now
	if lost > 0.0:
		var absorbed := minf(lost, barrier_left)
		barrier_left -= absorbed
		boss.hp = hp_now + absorbed
		if barrier_left <= 0.0:
			end_barrier()
		elif is_instance_valid(_barrier_ring):
			_barrier_ring.scale = Vector3.ONE * clampf(0.35 + 0.65 * barrier_left / maxf(_barrier_max, 1.0), 0.35, 1.0)
	_last_hp = boss.hp


func _summon(ids: Array, count: int, dist: float, elite := false) -> Array:
	var out: Array = []
	if director == null or not director.has_method("summon_for_boss"):
		return out
	for i in count:
		var a := TAU * i / maxf(count, 1) + randf() * 0.4
		var p := boss.global_position + Vector3(cos(a), 0, sin(a)) * dist
		var m = director.summon_for_boss(int(ids.pick_random()) if not ids.is_empty() else 0, p, elite)
		if m != null:
			out.append(m)
	return out


## Zone persistante (lave, poison…) posée après [param wait] s, [param dps_mult] × l'attaque par seconde.
func _hazard_later(at: Vector3, r: float, life: float, wait: float, dps_mult := 0.45) -> void:
	await boss.get_tree().create_timer(wait, false).timeout
	if is_instance_valid(boss) and not boss.is_dead:
		Hazard.spawn(boss, at, {"style": hazard_style, "radius": r, "lifetime": life, "dps": _dps(dps_mult), "source": boss})
