class_name AssaultVision
extends Node3D
## Vue, brouillard, voile et bruits de L'Assaut (lot TAC-2, risque n° 1 de l'étude TACTIQUE § 7.7 ; rapport R_TAC_2.md).
##
## - Vue d'équipe (10 fois par seconde) : un adversaire est vu par une équipe si l'un de ses héros debout le voit : à moins
##   de RANGE m, ligne de vue non coupée par un mur plein (couche AssaultMap.SIGHT : murs, barricades) ni par une brume
##   (smoke) ; dans les hautes herbes, seulement à moins de GRASS_SEE m ; invisible, seulement à moins de INVIS_SEE m.
##   Ce que l'équipe du héros regardé ne voit pas est CACHÉ (modèle, plaque, mini-carte), pas grisé.
## - Coups qui testent le décor : blocks_shot / blocks_segment (couche AssaultMap.SHOT : murs, murets, décor) lus par les
##   télégraphes (Telegraph._resolve), les zones du héros (Player._resolve_area), ses projectiles (HeroBolt) et les orbes
##   (Projectile) — seulement quand une partie de l'Assaut tourne (current), rien ne change ailleurs.
## - Voile : ce que TON héros ne voit pas est assombri (encre-500 à 35 % + trame, BIBLE § 3) : polygone de visibilité
##   (rayons de physique vers les angles des murs + un éventail), dessiné dans une petite texture (SubViewport) que lit
##   un quad plein écran (profondeur -> position au sol).
## - Bruits : course (pas) STEPS m, esquive DODGE m, coup ou sort FIGHT m, pose et désamorçage : toute la carte. Une
##   équipe entend un bruit si l'un de ses héros debout est à portée. Ceux de ton équipe deviennent des arcs « Voir les
##   sons » (AssaultCues, activé dans ce mode).
##
## API de perception (pour l'IA d'équipe, lot TAC-6 ; l'IA ne lit JAMAIS la position d'un ennemi que son équipe ne voit pas) :
##   AssaultVision.current                      # la vision de la partie en cours (null hors Assaut)
##   v.sees(équipe, héros) ; v.visible_foes(équipe) ; v.seen_by(équipe, héros) -> qui le voit
##   v.last_seen(équipe) -> {id: {pos, t, who}} (dernière position connue, s'efface après LAST_SEEN s pour l'affichage)
##   v.heard_since(équipe, secondes) -> [{pos, kind, t, src, radius}]
##   v.los(a, b) (vue) ; AssaultVision.blocks_shot(a, b) (coups) ; v.noise(pos, sorte, équipe_source, rayon)
##   signaux spotted(équipe, héros, par), lost(équipe, héros, position), heard(équipe, bruit)
##   AssaultVision.filter_seen(héros, liste) / perceives(héros, cible) : ciblage honnête de ClassRival (Monster._hostile_pool).

signal spotted(team: int, who: Combatant, by: Combatant)
signal lost(team: int, who: Combatant, at: Vector3)
signal heard(team: int, noise: Dictionary)

const RANGE := 22.0
const GRASS_SEE := 3.0
const INVIS_SEE := 5.0
const TOUCH := 2.5  # m : au contact, on se sent (le ciblage n'exige pas la vue)
const EYE := 1.5  # hauteur des yeux (m)
const BODY := 1.1  # hauteur visée sur la cible (m)
const SHOT_H := 1.0  # hauteur d'un coup au sol (m) : les murets (1,2 m) l'arrêtent
const TICK := 0.1
const LAST_SEEN := 4.0
const STEPS := 14.0
const DODGE := 18.0
const FIGHT := 24.0
const RUN_SPEED := 4.2  # m/s : plus vite, les pas s'entendent (la marche lente est silencieuse)
const NOISE_KEEP := 6.0
## Voile : rayons de l'éventail, couleur (encre-500 à 35 %), résolution de la texture.
const FAN := 96
const VEIL_RES := 256
## Arcs « Voir les sons » : sorte de bruit -> sorte de RoyaleCues.
const CUE := {"steps": "steps", "dodge": "steps", "fight": "fight", "plant": "drop", "defuse": "drop"}

static var current: AssaultVision = null

var map: ProcMap
var director: Node
var seen: Array = [{}, {}]  # équipe -> {id d'instance: héros qui le voit}
var last: Array = [{}, {}]  # équipe -> {id: {pos, t, who}}
var noises: Array = [[], []]  # équipe -> bruits entendus
var smokes: Array = []  # [{pos: Vector2 (monde xz), r, until}] : brumes (lot TAC-5), coupent la vue
## Héros révélés à une équipe même sans ligne de vue (lot TAC-4 : cible du Tireur ; TAC-5 : Œil de chouette, piège) :
## équipe -> {id d'instance: [jusqu'à (temps de la vision), révélé par]}.
var reveals: Array = [{}, {}]
var grass: Array = []  # Rect2 (monde xz)
var viewer: Combatant  # héros dont on dessine le voile (le joueur, ou celui que l'on regarde)
var view_team := 0
var time := 0.0
var veil_on := true
## Mesures : rayons tirés, temps du dernier tour (ms), tours.
var stats := {"rays": 0, "ms": 0.0, "ticks": 0, "ms_max": 0.0}
var _t := 0.0
var _q: PhysicsRayQueryParameters3D
var _tg_seen := {}
var _act_seen := {}
var _noise_at := {}
var _corners: Array = []  # angles des murs pleins (monde xz)
var _vp: SubViewport
var _poly: Polygon2D
var _quad: MeshInstance3D
var _veil_mat: ShaderMaterial
var polygon := PackedVector2Array()  # (tests) dernier polygone de visibilité, monde xz


func setup(m: ProcMap, d: Node) -> void:
	map = m
	director = d
	name = "AssaultVision"
	current = self
	_q = PhysicsRayQueryParameters3D.new()
	_q.collide_with_areas = false
	var off: Vector2 = m.assault.get("offset", Vector2.ZERO)
	for g in m.assault.get("data", {}).get("grass", []):
		var r := AssaultMap.rect_of(g.rect)
		grass.append(Rect2(r.position + off, r.size))
	for b in m.assault.get("blocks", []):
		if String(b.kind) == "wall" and b.has("rect"):
			var r: Rect2 = b.rect
			for c in [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]:
				_corners.append(c + off)
	if DisplayServer.get_name() != "headless":
		_build_veil()


func _exit_tree() -> void:
	if current == self:
		current = null


static func active() -> bool:
	return current != null and is_instance_valid(current)


func _heroes() -> Array:
	var out: Array = []
	for k in director.heroes:
		var h = director.heroes[k]
		if is_instance_valid(h):
			out.append(h)
	return out


func team_of(c: Combatant) -> int:
	return TeamMatch.team_of(c)


# --- requêtes ----------------------------------------------------------------------------------------

## Rayon de physique de [param a] à [param b] sur la couche [param mask] : vrai si rien ne l'arrête.
func clear_segment(a: Vector3, b: Vector3, mask: int) -> bool:
	_q.from = a
	_q.to = b
	_q.collision_mask = mask
	stats.rays = int(stats.rays) + 1
	return get_world_3d().direct_space_state.intersect_ray(_q).is_empty()


## Ligne de vue de [param a] (yeux) à [param b] (corps) : murs pleins et brumes.
func los(a: Vector3, b: Vector3) -> bool:
	if _smoke_cuts(Vector2(a.x, a.z), Vector2(b.x, b.z)):
		return false
	return clear_segment(a + Vector3.UP * EYE, b + Vector3.UP * BODY, AssaultMap.SIGHT)


func _smoke_cuts(a: Vector2, b: Vector2) -> bool:
	for s in smokes:
		if float(s.until) > time and Geometry2D.get_closest_point_to_segment(s.pos, a, b).distance_to(s.pos) < float(s.r):
			return true
	return false


func in_grass(p: Vector3) -> bool:
	for r in grass:
		if (r as Rect2).has_point(Vector2(p.x, p.z)):
			return true
	return false


## [param v] voit-il [param e] (distance, herbes, invisibilité, ligne de vue) ?
func can_see(v: Combatant, e: Combatant) -> bool:
	var d := Vector2(v.global_position.x - e.global_position.x, v.global_position.z - e.global_position.z).length()
	if d > RANGE:
		return false
	if e.has_status("invisible") and d > INVIS_SEE:
		return false
	if d > GRASS_SEE and in_grass(e.global_position):
		return false
	return los(v.global_position, e.global_position)


## Un coup au sol de [param from] vers [param to] est-il arrêté par le décor (murs, murets, fontaine) ? Faux hors Assaut.
static func blocks_shot(from: Vector3, to: Vector3) -> bool:
	if not active():
		return false
	return not current.clear_segment(from + Vector3.UP * SHOT_H, to + Vector3.UP * SHOT_H, AssaultMap.SHOT)


## Même chose pour un segment déjà à la bonne hauteur (projectiles en vol).
static func blocks_segment(a: Vector3, b: Vector3) -> bool:
	if not active():
		return false
	return not current.clear_segment(a, b, AssaultMap.SHOT)


## Télégraphe [param tg] de [param src] : la zone touche-t-elle [param target] à travers le décor ? Zone posée au loin : il
## faut aussi la ligne de tir du lanceur au centre (« une zone au sol exige la ligne de vue vers le point visé »).
static func blocks_zone(tg: Node3D, src: Combatant, target: Combatant) -> bool:
	if not active():
		return false
	var o := tg.global_position
	if src != null and is_instance_valid(src) and Vector2(src.global_position.x - o.x, src.global_position.z - o.z).length() > 2.0:
		if blocks_shot(src.global_position, o):
			return true
	return blocks_shot(o, target.global_position)


## Révèle [param c] à l'équipe [param team] pendant [param secs] s (vu « par » [param by] : dernière position, contour).
func reveal(team: int, c: Combatant, secs: float, by: Combatant = null) -> void:
	if team < 0 or team >= reveals.size() or c == null or not is_instance_valid(c):
		return
	var id := c.get_instance_id()
	var until := time + secs
	if float((reveals[team] as Dictionary).get(id, [0.0])[0]) < until:
		reveals[team][id] = [until, by]


func sees(team: int, c: Combatant) -> bool:
	return team >= 0 and team < seen.size() and c != null and (seen[team] as Dictionary).has(c.get_instance_id())


func seen_by(team: int, c: Combatant) -> Combatant:
	if not sees(team, c):
		return null
	var w = seen[team][c.get_instance_id()]
	return w as Combatant if is_instance_valid(w) else null


func visible_foes(team: int) -> Array:
	var out: Array = []
	for id in seen[team]:
		var c = instance_from_id(id)
		if is_instance_valid(c) and not (c as Combatant).is_dead:
			out.append(c)
	return out


func last_seen(team: int) -> Dictionary:
	return last[team]


func heard_since(team: int, secs: float) -> Array:
	return (noises[team] as Array).filter(func(n): return time - float(n.t) <= secs)


## Ciblage honnête (ClassRival._hostile_pool) : ce que l'équipe de [param c] voit, plus ce qui la touche presque. Hors Assaut,
## la liste telle quelle.
static func filter_seen(c: Combatant, pool: Array) -> Array:
	if not active():
		return pool
	var t := current.team_of(c)
	if t < 0:
		return pool
	return pool.filter(func(x): return current.perceived(t, c, x))


## [param c] peut-il viser [param target] ? (ClassRival._can_target) Toujours vrai hors Assaut.
static func perceives(c: Combatant, target: Combatant) -> bool:
	if not active() or target == null or not is_instance_valid(target):
		return true
	var t := current.team_of(c)
	return t < 0 or current.perceived(t, c, target)


func perceived(t: int, c: Combatant, x: Combatant) -> bool:
	if x == null or not is_instance_valid(x):
		return false
	if c.has_status("blind"):
		return false  # (lot TAC-5) ébloui par un Éclat aveuglant : il perd sa cible
	return sees(t, x) or c.global_position.distance_to(x.global_position) <= TOUCH


## Un bruit [param kind] en [param pos], fait par l'équipe [param src] : entendu par chaque autre équipe dont un héros debout
## est à portée ([param radius] ; INF : toute la carte). Le joueur le voit en arc (« Voir les sons ») si son équipe l'entend et
## ne voit pas déjà son auteur [param who] (un adversaire en vue n'a pas besoin d'arc ; la Charge, toujours).
func noise(pos: Vector3, kind: String, src: int, radius := -1.0, who: Combatant = null) -> void:
	if radius < 0.0:
		radius = {"steps": STEPS, "dodge": DODGE, "fight": FIGHT}.get(kind, INF)
	for t in 2:
		if t == src:
			continue
		var ok := is_inf(radius)
		if not ok:
			for h in TeamMatch.alive(t):
				if (h as Combatant).global_position.distance_to(pos) <= radius:
					ok = true
					break
		if not ok:
			continue
		var n := {"pos": pos, "kind": kind, "t": time, "src": src, "radius": radius}
		(noises[t] as Array).append(n)
		heard.emit(t, n)
		if t == view_team and CUE.has(kind) and (who == null or not sees(t, who) or kind in ["plant", "defuse"]):
			RoyaleCues.heard(pos, String(CUE[kind]))


# --- boucle -------------------------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	time += delta
	_t -= delta
	if _t > 0.0:
		return
	_t = TICK
	var t0 := Time.get_ticks_usec()
	_team_vision()
	_listen()
	_apply()
	if veil_on and _vp != null:
		_update_veil()
	var ms := float(Time.get_ticks_usec() - t0) / 1000.0
	stats.ms = ms
	stats.ms_max = maxf(float(stats.ms_max), ms)
	stats.ticks = int(stats.ticks) + 1


func _team_vision() -> void:
	var hs := _heroes()
	for t in 2:
		var now := {}
		var mine: Array = hs.filter(func(h): return team_of(h) == t and not (h as Combatant).is_dead)
		for e in hs:
			var ec := e as Combatant
			var te := team_of(ec)
			if te < 0 or te == t or ec.is_dead:
				continue
			for v in mine:
				if can_see(v, ec):
					now[ec.get_instance_id()] = v
					break
			var rv = (reveals[t] as Dictionary).get(ec.get_instance_id())
			if rv != null and float(rv[0]) > time and not now.has(ec.get_instance_id()) and not mine.is_empty():
				now[ec.get_instance_id()] = rv[1] if is_instance_valid(rv[1]) else mine[0]  # (lot TAC-4) révélé
		for id in (reveals[t] as Dictionary).keys():
			if float(reveals[t][id][0]) <= time:
				reveals[t].erase(id)
		for id in now:
			if not (seen[t] as Dictionary).has(id):
				spotted.emit(t, instance_from_id(id), now[id])
			last[t][id] = {"pos": (instance_from_id(id) as Node3D).global_position, "t": time, "who": now[id]}
		for id in seen[t]:
			if not now.has(id) and is_instance_valid(instance_from_id(id)):
				lost.emit(t, instance_from_id(id), last[t].get(id, {}).get("pos", Vector3.ZERO))
		seen[t] = now
		for id in (last[t] as Dictionary).keys():
			if time - float(last[t][id].t) > 30.0 or not is_instance_valid(instance_from_id(id)):
				last[t].erase(id)
		noises[t] = (noises[t] as Array).filter(func(n): return time - float(n.t) <= NOISE_KEEP)


## Bruits des héros : course, esquive, coups et sorts (télégraphes des scriptés, actions du joueur).
func _listen() -> void:
	for h in _heroes():
		var c := h as Combatant
		if c.is_dead:
			continue
		var t := team_of(c)
		var id := c.get_instance_id()
		var kind := ""
		if c is Player:
			var p := c as Player
			if p._state == "dodge":
				kind = "dodge"
			elif p._state in ["attack", "skill"] and not is_same(_act_seen.get(id), p._action):
				_act_seen[id] = p._action
				kind = "fight"
		elif c is ClassRival:
			var r := c as ClassRival
			if r._time < r._dash_until:
				kind = "dodge"
		var quiet := float(c.get_meta("assault_quiet", RUN_SPEED))  # (lot TAC-5) Bottes feutrées : pas silencieux plus vite
		if kind == "" and not c.has_status("silent") and Vector2(c.velocity.x, c.velocity.z).length() > quiet:
			kind = "steps"
		if kind != "" and time >= float(_noise_at.get(id, 0.0)):
			_noise_at[id] = time + (0.5 if kind == "steps" else 0.3)
			noise(c.global_position, kind, t, -1.0, c)
	for tg in get_tree().get_nodes_in_group("telegraphs"):
		var iid := (tg as Node).get_instance_id()
		if _tg_seen.has(iid):
			continue
		_tg_seen[iid] = true
		var src = tg.get("source")
		if is_instance_valid(src) and team_of(src) >= 0:
			noise((src as Node3D).global_position, "fight", team_of(src), -1.0, src)
	if _tg_seen.size() > 512:
		_tg_seen.clear()


## Ce que l'équipe du héros regardé ne voit pas est caché (modèle, plaque, mini-carte : Monster.visible) ; les morts et les
## équipiers restent visibles.
func _apply() -> void:
	viewer = director.call("view_hero") if director.has_method("view_hero") else null
	view_team = team_of(viewer) if viewer != null else 0
	if view_team < 0:
		view_team = 0
	for h in _heroes():
		var c := h as Combatant
		if c is Player and (c as Player).process_mode == Node.PROCESS_MODE_DISABLED:
			continue
		var show := team_of(c) == view_team or c.is_dead or sees(view_team, c)
		if c.visible != show:
			c.visible = show
	_update_ghosts()


## Dernière position connue (TACTIQUE § 5.5) : un « ? » fraise là où ton équipe a vu un adversaire pour la dernière fois,
## qui s'efface en LAST_SEEN s.
var _ghosts: Dictionary = {}


func _update_ghosts() -> void:
	var want := {}
	for id in last[view_team]:
		var c = instance_from_id(id)
		if not is_instance_valid(c) or (c as Combatant).is_dead or (seen[view_team] as Dictionary).has(id):
			continue
		var age := time - float(last[view_team][id].t)
		if age <= LAST_SEEN:
			want[id] = age
	for id in _ghosts.keys():
		if not want.has(id):
			(_ghosts[id] as Node).queue_free()
			_ghosts.erase(id)
	for id in want:
		if not _ghosts.has(id):
			var l := Label3D.new()
			l.text = "?"
			l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			l.no_depth_test = true
			l.fixed_size = true
			l.pixel_size = 0.0012
			l.font_size = 64
			l.outline_size = 14
			l.modulate = UiTheme.color("bonbon.fraise.base", Color("ff4d6d"))
			l.outline_modulate = UiTheme.color("encre.900", Color("221a3a"))
			add_child(l)
			_ghosts[id] = l
		var g: Label3D = _ghosts[id]
		g.global_position = (last[view_team][id].pos as Vector3) + Vector3.UP * 1.6
		var a := 1.0 - float(want[id]) / LAST_SEEN
		g.modulate.a = a
		g.outline_modulate.a = a


## Fantômes affichés (tests) : id d'instance -> Label3D.
func ghosts() -> Dictionary:
	return _ghosts


# --- voile -------------------------------------------------------------------------------------------

const VEIL_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_test_disabled, depth_draw_never, blend_mix, fog_disabled, shadows_disabled;
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;
uniform sampler2D veil_tex : filter_linear;
uniform vec4 map_rect = vec4(0.0, 0.0, 128.0, 128.0);
uniform vec4 ink : source_color = vec4(0.42, 0.37, 0.55, 0.35);
uniform float dots = 0.12;
void vertex() {
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}
void fragment() {
	float depth = textureLod(depth_tex, SCREEN_UV, 0.0).r;
	vec4 view = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, depth, 1.0);
	view.xyz /= view.w;
	vec3 world = (INV_VIEW_MATRIX * vec4(view.xyz, 1.0)).xyz;
	vec2 uv = (world.xz - map_rect.xy) / map_rect.zw;
	float hidden = 0.0;
	if (uv.x > 0.0 && uv.y > 0.0 && uv.x < 1.0 && uv.y < 1.0 && depth > 0.00001) {
		hidden = 1.0 - texture(veil_tex, uv).r;
	}
	vec2 cell = mod(FRAGCOORD.xy, 6.0) - 3.0;
	float dot_mask = step(length(cell), 1.3) * dots;
	ALBEDO = ink.rgb * (1.0 - dot_mask);
	ALPHA = hidden * (ink.a + dot_mask);
}
"""


func _build_veil() -> void:
	_vp = SubViewport.new()
	_vp.size = Vector2i(VEIL_RES, VEIL_RES)
	_vp.disable_3d = true
	_vp.transparent_bg = false
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_vp)
	var bg := ColorRect.new()
	bg.color = Color.BLACK
	bg.size = Vector2(VEIL_RES, VEIL_RES)
	_vp.add_child(bg)
	_poly = Polygon2D.new()
	_poly.color = Color.WHITE
	_vp.add_child(_poly)
	_veil_mat = ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = VEIL_SHADER
	_veil_mat.shader = sh
	_veil_mat.set_shader_parameter("veil_tex", _vp.get_texture())
	_veil_mat.set_shader_parameter("map_rect", Vector4(0, 0, map.size, map.size))
	var ink := UiTheme.color("encre.500", Color("6b5e86"))
	_veil_mat.set_shader_parameter("ink", Color(ink, 0.35))
	_quad = MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(2, 2)
	_quad.mesh = qm
	_quad.material_override = _veil_mat
	_quad.extra_cull_margin = 16384.0
	_quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_quad.sorting_offset = 100.0
	add_child(_quad)


## Polygone de visibilité de [param from] (monde) : un éventail de FAN rayons + deux rayons de part et d'autre de chaque angle
## de mur proche (bords nets), arrêtés par les murs pleins (couche SIGHT) et les brumes, prolongés de 0,5 m (la face du mur
## qu'on voit n'est pas voilée).
func visibility_polygon(from: Vector3) -> PackedVector2Array:
	var eye := from + Vector3.UP * EYE
	var o := Vector2(from.x, from.z)
	var angles: Array = []
	for i in FAN:
		angles.append(TAU * i / FAN)
	for c in _corners:
		var d := (c as Vector2) - o
		if d.length() < RANGE + 2.0 and d.length() > 0.2:
			var a := d.angle()
			angles.append(a - 0.004)
			angles.append(a + 0.004)
	angles.sort()
	var pts := PackedVector2Array()
	for a in angles:
		var dir := Vector2.from_angle(a)
		var end := o + dir * RANGE
		_q.from = eye
		_q.to = Vector3(end.x, eye.y, end.y)
		_q.collision_mask = AssaultMap.SIGHT
		stats.rays = int(stats.rays) + 1
		var hit := get_world_3d().direct_space_state.intersect_ray(_q)
		var dist := RANGE
		if not hit.is_empty():
			dist = minf(Vector2((hit.position as Vector3).x, (hit.position as Vector3).z).distance_to(o) + 0.5, RANGE)
		for s in smokes:
			if float(s.until) <= time:
				continue
			var hit2: Variant = Geometry2D.segment_intersects_circle(o, o + dir * dist, s.pos, float(s.r))
			if hit2 is float and float(hit2) >= 0.0:
				dist = minf(dist, float(hit2) * dist)
		pts.append(o + dir * dist)
	return pts


func _update_veil() -> void:
	var v := viewer
	if v == null or not is_instance_valid(v):
		_poly.polygon = PackedVector2Array()
		return
	polygon = visibility_polygon(v.global_position)
	var k: float = float(VEIL_RES) / map.size
	# éventail de triangles autour du héros (un polygone « étoilé » à sommets presque confondus ne se triangule pas toujours :
	# Polygon2D n'aurait rien dessiné)
	var px := PackedVector2Array([Vector2(v.global_position.x, v.global_position.z) * k])
	var tris: Array = []
	var n := polygon.size()
	for i in n:
		px.append(polygon[i] * k)
		tris.append(PackedInt32Array([0, 1 + i, 1 + (i + 1) % n]))
	_poly.polygon = px
	_poly.polygons = tris
	if _dump_at >= 0.0 and time >= _dump_at:
		_dump_at = -1.0  # (--assault-veil-dump=N : la texture du voile à N s, pour vérifier le voile sans regarder l'écran)
		DirAccess.make_dir_recursive_absolute("user://shots")
		_vp.get_texture().get_image().save_png("user://shots/assault_veil.png")
		print("[assault] voile : %d sommets autour de (%.0f, %.0f) -> user://shots/assault_veil.png" % [polygon.size(), v.global_position.x, v.global_position.z])


var _dump_at := _dump_arg()


static func _dump_arg() -> float:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--assault-veil-dump="):
			return float(a.trim_prefix("--assault-veil-dump="))
	return -1.0
