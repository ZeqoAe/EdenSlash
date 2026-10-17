extends Node3D
## MB-0 : essai technique des « Deux Voies » (MOBA 4 contre 4, conception/benchmark/MOBA.md § 8-9 ; rapport
## conception/benchmark/R_MB0.md). Carte grossière 200 × 120 m à deux voies (sol, voies, rivière, rochers de jungle,
## navigation cuite d'un coup avant tout), 8 héros scriptés (ClassRival, deux camps natifs Team), des sbires qui suivent
## leur voie (vagues refaites toutes les 10 s jusqu'au quota), 8 tours et 2 Cœurs qui tirent, 12 monstres de camp ; mesure du
## coût d'image. Rien n'est écrit dans le profil (Training.active) ; aucun class_name (banc).
## Lancer :
##   sans rendu : Godot --headless --fixed-fps 60 --path game res://tools/moba_probe.tscn -- [options]
##   avec rendu : Godot --fixed-fps 60 --disable-vsync --resolution 1600x900 --path game res://tools/moba_probe.tscn -- [options]
##   (--fixed-fps : une image physique par image, aussi vite que possible : le temps d'une image = son coût complet)
##   série (3 essais par réglage, charge de la machine, temps CPU du processus) : python tools/moba_probe.py
## Options :
##   --preset=base|opt   base = le code du jeu tel quel (Monster complet, cibles par groupes, chemin de navigation, zones rouges,
##                       Projectile du jeu, aucun recyclage) ; opt = parades proposées (voir R_MB0 § 4) ; puis un réglage à la fois :
##   --nav=path|flow|agent   marche des sbires : chemin NavigationServer (comme Monster), courbe de voie seule, NavigationAgent3D + évitement
##   --target=group|grid     recherche des cibles : groupes de la scène (get_nodes_in_group) ou grille spatiale refaite à chaque image
##   --lite=0|1  sbires « horde » (Monster.lite : sans move_and_slide, animation à demi-cadence)   --lod=0|1 (loin de la caméra : 1 image sur 2 / 4 ;
##               camps endormis sans héros à 25 m)   --pool=0|1 (sbires et traits recyclés)   --light=0|1 (coup de sbire sans zone rouge)
##   --bolts=game|pool  tirs des sbires tireurs : Projectile du jeu (maillage, matière et lumière neufs) ou trait du banc partagé
##   --wave_max=5 (sbires ajoutés au plus par voie et par camp toutes les 10 s : plus haut pour tenir un grand nombre de sbires)
##   --busy=1 (sans cible à portée, chaque tour tire à blanc sur l'ennemi le plus proche à 45 m : les 10 structures tirent sans arrêt)
##   --minions=48 --heroes=8 --towers=1 --camps=12 --level=50 --diff=2 --seed=1 --warm=12 --dur=60 --scale=0.09 (échelle JcJ)
##   --fx=0|1 (effets de sorts) --numbers=0|1 (chiffres de dégâts) --quality=low|medium|high|ultra --shadows=0|1 --scale3d=1.0
##   --msaa=0|2|4 --decor=<biome> (décor d'une vraie carte sous le terrain du banc, rendu seulement) --cam=follow|wide --shot=<image.jpg> --out=<résultats.json>
## Lignes : [mb0] …

const MINION := preload("res://tools/moba_probe_minion.gd")
const HERO := preload("res://tools/moba_probe_hero.gd")
const TOWER := preload("res://tools/moba_probe_tower.gd")
const BOLT := preload("res://tools/moba_probe_bolt.gd")

const HALF_W := 100.0
const HALF_H := 60.0
## Voies (du Cœur bleu au Cœur rouge) : Soleil en haut (z < 0), Brumes en bas.
const LANE_PTS := [
	[Vector3(-88, 0, -6), Vector3(-82, 0, -28), Vector3(-66, 0, -42), Vector3(-40, 0, -47), Vector3(0, 0, -48),
		Vector3(40, 0, -47), Vector3(66, 0, -42), Vector3(82, 0, -28), Vector3(88, 0, -6)],
	[Vector3(-88, 0, 6), Vector3(-82, 0, 28), Vector3(-66, 0, 42), Vector3(-40, 0, 47), Vector3(0, 0, 48),
		Vector3(40, 0, 47), Vector3(66, 0, 42), Vector3(82, 0, 28), Vector3(88, 0, 6)],
]
const LANE_W := 11.0
const WP_STEP := 4.0
const TOWER_AT := [0.11, 0.30]  # T2, T1 : part de la voie depuis sa base
const GRID_CELL := 8.0
const SEP_CELL := 2.0
const MELEE_ID := 56036  # Soldat des marais (m010)
const RANGED_ID := 56003  # Angelly (m024, tireur)
const CAMP_IDS := [56080, 56160]
const CAMPS := [Vector2(-50, -18), Vector2(-50, 18), Vector2(-28, -24), Vector2(-28, 24), Vector2(-20, 0), Vector2(-62, 0)]
## Postes : Brumes (solo, Rempart), jungle (Ombre), Soleil (tir + soutien).
const TEAMS := [["knight", "assassin", "ranger", "cleric"], ["warrior", "kage", "hunter", "bard"]]
const ROLE_LANE := [1, -1, 0, 0]
const WAVE_EVERY := 10.0
const HERO_AGGRO := 22.0
const RESPAWN := 5.0
const OPT_DEFAULTS := {"minions": "48", "heroes": "8", "towers": "1", "camps": "12", "level": "50", "diff": "2", "seed": "1",
	"warm": "12", "dur": "60", "scale": "0.09", "fx": "1", "numbers": "1", "quality": "high", "shadows": "1", "scale3d": "1.0",
	"cam": "follow", "msaa": "2", "busy": "1", "wave_max": "5"}

## Dernier nœud physique de l'image (priorité 1000) : le banc mesure le temps de toute la passe physique des nœuds (unités,
## Projectile, effets, banc), du début de sa propre passe (priorité -100, la première) à la fin de celle-ci.
class LateTimer extends Node:
	var probe: Node

	func _physics_process(_delta: float) -> void:
		probe.phys_end()


var opt := {}
var headless := false
var _phys_t0 := 0
var nodes_phys_ms := PackedFloat32Array()
# réglages lus dans la boucle chaude (copiés de opt)
var nav_mode := "path"
var grid_on := false
var lite_on := false
var lod_on := false
var pool_on := false
var light_on := false
var pool_bolts := false
var towers_busy := true

var lane_wp := []  # [voie][camp] -> PackedVector3Array (dans le sens de marche du camp)
var lane_perp := []  # [voie][camp] -> PackedVector3Array (côté gauche de la marche)
var lane_cum := []  # [voie][camp] -> PackedFloat32Array (distance parcourue au point)
var lane_len: Array[float] = [0.0, 0.0]
var front := [[0.0, 0.0], [0.0, 0.0]]  # [camp][voie] : avancée de la vague la plus avancée (m depuis sa base)

var heroes: Array = []
var minions: Array = []  # sbires actifs (vivants ou en train de mourir)
var spare: Array = [[], []]  # recyclage : [mêlée, tireur]
var towers: Array = []
var cores := [null, null]
var camps: Array = []
var bolts_free: Array = []
var bolts_live := 0
var focus: Node3D
var cam: Camera3D
var _region: NavigationRegion3D

var grid := {}
var sep_grid := {}
## Coûts (µs) de l'image physique en cours : par genre d'unité (leur _physics_process entier), grilles, directeur ; « query » (recherche
## de cibles du banc) et « path » (NavigationServer3D.map_get_path) sont aussi comptés dans le genre qui les appelle.
var cost := {"hero": 0, "minion": 0, "tower": 0, "bolt": 0, "camp": 0, "grid": 0, "manager": 0, "query": 0, "path": 0}
var hist := {}
var t := 0.0
var _running := false
var measuring := false
var _wave_t := 0.0
var _slow_t := 0.0
var _sample_t := 0.0
var _last_usec := 0
var _rid: RID
var hero_ref_hp := 1000.0
var hero_ref_auto := 100.0
var hero_ref_def := 100.0

# mesures
var frame_ms := PackedFloat32Array()
var phys_ms := PackedFloat32Array()
var proc_ms := PackedFloat32Array()
var nav_ms := PackedFloat32Array()
var gpu_ms := PackedFloat32Array()
var rcpu_ms := PackedFloat32Array()
var samples := {"minions": [], "heroes_fighting": [], "bolts": [], "projectiles": [], "telegraphs": [], "fx": [], "numbers": [],
	"nodes": [], "objects": [], "mem_mb": [], "vmem_mb": [], "draw_calls": [], "primitives": []}
var spawn_minion_ms: Array = []
var spawn_hero_ms: Array = []
var events := {"minion_deaths": 0, "hero_deaths": 0, "tower_shots": 0, "bolts": 0, "hero_attacks": 0, "minion_spawns": 0, "reused": 0,
	"paths": 0, "queries": 0, "tower_practice": 0}
var info := {}


func _ready() -> void:
	process_physics_priority = -100  # grille et directeur avant les unités
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--") and "=" in a:
			opt[a.substr(2).get_slice("=", 0)] = a.get_slice("=", 1)
		elif a.begins_with("--"):
			opt[a.substr(2)] = "1"
	var preset := String(opt.get("preset", "base"))
	var defaults := {"nav": "path", "target": "group", "lite": "0", "lod": "0", "pool": "0", "light": "0", "bolts": "game"}
	if preset == "opt":
		defaults = {"nav": "flow", "target": "grid", "lite": "1", "lod": "1", "pool": "1", "light": "1", "bolts": "pool"}
	for k in defaults:
		if not opt.has(k):
			opt[k] = defaults[k]
	for k in OPT_DEFAULTS:
		if not opt.has(k):
			opt[k] = OPT_DEFAULTS[k]
	nav_mode = String(opt.nav)
	grid_on = String(opt.target) == "grid"
	lite_on = opt.lite == "1"
	lod_on = opt.lod == "1"
	pool_on = opt.pool == "1"
	light_on = opt.light == "1"
	pool_bolts = String(opt.bolts) == "pool"
	towers_busy = opt.busy == "1"
	seed(int(opt.seed))
	headless = DisplayServer.get_name() == "headless"
	_setup_state()
	add_to_group("map")
	var t0 := Time.get_ticks_usec()
	_build_map()
	info["map_build_ms"] = (Time.get_ticks_usec() - t0) / 1000.0
	_bake_nav()
	for i in 30:
		await get_tree().physics_frame
		if NavigationServer3D.map_get_iteration_id(get_world_3d().navigation_map) > 0:
			break
	if not headless:
		_build_render()
	_build_lanes()
	if opt.towers == "1":
		_place_structures()
	else:
		for side in 2:
			cores[side] = _make_tower(side, Vector3(-90.0 if side == 0 else 90.0, 0, 0), true)  # (cible de repli des héros)
	t0 = Time.get_ticks_usec()
	_spawn_heroes()
	info["heroes_spawn_ms"] = (Time.get_ticks_usec() - t0) / 1000.0
	_spawn_camps()
	_spawn_initial_minions()
	if not headless:
		_rid = get_viewport().get_viewport_rid()
		RenderingServer.viewport_set_measure_render_time(_rid, true)
		info["gpu"] = RenderingServer.get_video_adapter_name()
		info["driver"] = RenderingServer.get_current_rendering_driver_name()
		info["window"] = "%dx%d" % [get_viewport().get_visible_rect().size.x, get_viewport().get_visible_rect().size.y]
	print(("[mb0] prêt : %s · %d héros, %d sbires visés, %d structures, %d camps · nav %s · cibles %s · lite %s · lod %s · "
		+ "recyclage %s · coup léger %s · tirs %s · %s") % [
		"sans rendu" if headless else "rendu %s %s" % [info.get("window", "?"), info.get("gpu", "?")], heroes.size(), int(opt.minions),
		towers.size(), camps.size(),
		nav_mode, opt.target, opt.lite, opt.lod, opt.pool, opt.light, opt.bolts, JSON.stringify(info)])
	var late := LateTimer.new()
	late.probe = self
	late.process_physics_priority = 1000
	add_child(late)
	_last_usec = Time.get_ticks_usec()
	_running = true


func _setup_state() -> void:
	Training.active = true  # aucune sauvegarde (comme l'arène d'IA et la sonde AC2)
	Training.hero_god = false
	Training.enemies_immortal = false
	Training.enemies_passive = false
	Vfx.silent = opt.fx != "1"
	var ui: Dictionary = Settings.data.get("interface", {})
	ui["hit_stop"] = false
	ui["damage_numbers"] = "all" if opt.numbers == "1" else "off"
	Settings.data["interface"] = ui
	var disp: Dictionary = Settings.data.get("display", {})
	disp["quality"] = String(opt.quality)
	Settings.data["display"] = disp
	# règles d'équipe (Arènes) : Duel actif (règles JcJ entre héros, ClassRival en mode d'équipe), héros nus au niveau --level
	Duel.active = true
	Duel.mode = "arena3"
	Duel.bare = true
	Duel.extra_foes = ["mb0"]
	Duel.level = int(opt.level)
	Duel.difficulty = int(opt.diff)
	ModeRules.forced = "arena3"
	DevEdits.data["modes"] = {"arena3": {"dmg_scale": float(opt.scale), "sudden_after": 100000.0}}  # (en mémoire : profil « moba » de départ)
	PvpCaps.board = {}
	PvpCaps.elapsed = 0.0
	if not headless:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		Engine.max_fps = 0
		get_viewport().msaa_3d = {"0": Viewport.MSAA_DISABLED, "2": Viewport.MSAA_2X, "4": Viewport.MSAA_4X}.get(String(opt.msaa), Viewport.MSAA_2X)
		get_viewport().scaling_3d_scale = float(opt.scale3d)


# --- carte ---------------------------------------------------------------------------------

func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.9
	return m


func _static_box(at: Vector3, size: Vector3, color: Color, rot := 0.0) -> StaticBody3D:
	var b := StaticBody3D.new()
	b.collision_layer = GameData.PHYS_WORLD
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	b.add_child(cs)
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = _mat(color)
	b.add_child(mi)
	add_child(b)
	b.position = at
	b.rotation.y = rot
	return b


func _build_map() -> void:
	# sol (le dessus à y = 0) et bords
	var ground := _static_box(Vector3(0, -1, 0), Vector3(HALF_W * 2, 2, HALF_H * 2), Color(0.42, 0.66, 0.3))
	if opt.has("decor") and not headless:
		_add_decor(ground)
	for s in [-1.0, 1.0]:
		_static_box(Vector3(s * (HALF_W + 1), 2, 0), Vector3(2, 4, HALF_H * 2 + 4), Color(0.5, 0.45, 0.4))
		_static_box(Vector3(0, 2, s * (HALF_H + 1)), Vector3(HALF_W * 2 + 4, 4, 2), Color(0.5, 0.45, 0.4))
	# voies et rivière (décor seul, sans collision)
	var lane_mat := _mat(Color(0.85, 0.76, 0.52))
	for pts in LANE_PTS:
		for i in pts.size() - 1:
			var a: Vector3 = pts[i]
			var b: Vector3 = pts[i + 1]
			var mi := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3(LANE_W, 0.04, a.distance_to(b) + LANE_W * 0.6)
			mi.mesh = bm
			mi.material_override = lane_mat
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(mi)
			mi.position = (a + b) * 0.5 + Vector3.UP * 0.02
			mi.rotation.y = atan2(b.x - a.x, b.z - a.z)
	var river := MeshInstance3D.new()
	var rm := BoxMesh.new()
	rm.size = Vector3(8, 0.03, HALF_H * 2)
	river.mesh = rm
	river.material_override = _mat(Color(0.35, 0.6, 0.85))
	river.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(river)
	river.position = Vector3(0, 0.015, 0)
	# bases
	for side in 2:
		var pad := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 12.0
		cm.bottom_radius = 12.0
		cm.height = 0.05
		pad.mesh = cm
		pad.material_override = _mat(Color(0.45, 0.6, 0.95) if side == 0 else Color(0.95, 0.45, 0.45))
		pad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(pad)
		pad.position = Vector3(-88.0 if side == 0 else 88.0, 0.03, 0)
	# rochers de la jungle (couvert : bloquent le passage), symétriques par rotation, loin des voies, de la rivière et des camps
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	var placed := 0
	var tries := 0
	while placed < 24 and tries < 2000:
		tries += 1
		var p := Vector3(rng.randf_range(-74, -6), 0, rng.randf_range(-36, 36))
		if _lane_dist(p) < LANE_W * 0.5 + 4.0:
			continue
		var near_camp := false
		for c in CAMPS:
			if Vector2(p.x, p.z).distance_to(c) < 6.0:
				near_camp = true
		if near_camp:
			continue
		var r := rng.randf_range(1.4, 3.4)
		var h := rng.randf_range(2.0, 4.0)
		for k in [1.0, -1.0]:  # (symétrie par rotation : (x, z) -> (-x, -z))
			var b := StaticBody3D.new()
			b.collision_layer = GameData.PHYS_WORLD
			var cs := CollisionShape3D.new()
			var cy := CylinderShape3D.new()
			cy.radius = r
			cy.height = h
			cs.shape = cy
			b.add_child(cs)
			var mi := MeshInstance3D.new()
			var cmm := CylinderMesh.new()
			cmm.top_radius = r * 0.7
			cmm.bottom_radius = r
			cmm.height = h
			cmm.radial_segments = 10
			mi.mesh = cmm
			mi.material_override = _mat(Color(0.55, 0.53, 0.5))
			b.add_child(mi)
			add_child(b)
			b.position = Vector3(p.x * k, h * 0.5, p.z * k)
		placed += 1
	info["rocks"] = placed * 2


## Banc --decor=<biome> : le décor d'une vraie carte de Survie (ProcMap.generate_scenery : relief, herbe, arbres, rochers,
## village) sous le terrain plat du banc, pour estimer le rendu d'une carte habillée. Ses collisions sont coupées (les unités
## marchent sur le sol plat, invisible) ; le relief peut cacher une unité par endroits : seul le coût du rendu compte ici.
func _add_decor(ground: StaticBody3D) -> void:
	var t0 := Time.get_ticks_usec()
	var pm := ProcMap.new()
	pm.biome = String(opt.decor)
	add_child(pm)
	pm.generate_scenery(7)
	for c in pm.find_children("*", "CollisionObject3D", true, false):
		(c as CollisionObject3D).collision_layer = 0
		(c as CollisionObject3D).collision_mask = 0
	# relief le plus haut sous l'aire de jeu : posé juste sous le sol plat (rien ne cache les unités ; les creux restent plus bas)
	var h := -INF
	for x in range(-int(HALF_W), int(HALF_W) + 1, 4):
		for z in range(-int(HALF_H), int(HALF_H) + 1, 4):
			h = maxf(h, pm.height_at(pm.size * 0.5 + x, pm.size * 0.5 + z))
	pm.position = Vector3(-pm.size * 0.5, -h - 0.15, -pm.size * 0.5)
	info["decor_drop_m"] = snappedf(h - pm.height_at(pm.size * 0.5, pm.size * 0.5), 0.1)
	for c in ground.get_children():
		if c is MeshInstance3D:
			(c as MeshInstance3D).visible = false
	info["decor_ms"] = (Time.get_ticks_usec() - t0) / 1000.0


func _lane_dist(p: Vector3) -> float:
	var best := INF
	for pts in LANE_PTS:
		for i in pts.size() - 1:
			var a: Vector3 = pts[i]
			var b: Vector3 = pts[i + 1]
			var ab := b - a
			var u := clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
			best = minf(best, p.distance_to(a + ab * u))
	return best


## Navigation cuite d'un coup, sur le fil principal, avant toute unité (un calcul en tâche de fond non fini plante la sortie).
func _bake_nav() -> void:
	var t0 := Time.get_ticks_usec()
	_region = NavigationRegion3D.new()
	var nav := MapLoader.make_navmesh_settings()
	nav.cell_size = 0.5
	nav.cell_height = 0.25
	nav.agent_radius = 0.6
	add_child(_region)
	var nav_map := get_world_3d().navigation_map
	NavigationServer3D.map_set_cell_size(nav_map, nav.cell_size)
	NavigationServer3D.map_set_cell_height(nav_map, nav.cell_height)
	var src := NavigationMeshSourceGeometryData3D.new()
	NavigationServer3D.parse_source_geometry_data(nav, src, self)
	NavigationServer3D.bake_from_source_geometry_data(nav, src)
	_region.navigation_mesh = nav
	info["nav_bake_ms"] = (Time.get_ticks_usec() - t0) / 1000.0
	info["nav_polys"] = nav.get_polygon_count()


## Comme ProcMap.path_between (Monster et ClassRival suivent ce chemin).
func path_between(from: Vector3, to: Vector3) -> PackedVector3Array:
	var t0 := Time.get_ticks_usec()
	var nav_map := get_world_3d().navigation_map
	if NavigationServer3D.map_get_iteration_id(nav_map) == 0:
		return PackedVector3Array()
	var path := NavigationServer3D.map_get_path(nav_map, from, to, true)
	cost.path += Time.get_ticks_usec() - t0
	events.paths += 1
	return path


func height_at(_x: float, _z: float) -> float:
	return 0.0


func _build_lanes() -> void:
	lane_wp = []
	lane_perp = []
	lane_cum = []
	for li in 2:
		var pts: Array = LANE_PTS[li]
		var dense := PackedVector3Array()
		dense.append(pts[0])
		for i in pts.size() - 1:
			var a: Vector3 = pts[i]
			var b: Vector3 = pts[i + 1]
			var n := maxi(1, ceili(a.distance_to(b) / WP_STEP))
			for k in range(1, n + 1):
				dense.append(a.lerp(b, float(k) / n))
		var per_side := []
		var perp_side := []
		var cum_side := []
		for side in 2:
			var wp := dense.duplicate()
			if side == 1:
				wp.reverse()
			var perp := PackedVector3Array()
			var cum := PackedFloat32Array()
			var acc := 0.0
			for i in wp.size():
				if i > 0:
					acc += wp[i].distance_to(wp[i - 1])
				cum.append(acc)
				var d := (wp[mini(i + 1, wp.size() - 1)] - wp[maxi(i - 1, 0)])
				d.y = 0.0
				perp.append(d.normalized().cross(Vector3.UP))
			per_side.append(wp)
			perp_side.append(perp)
			cum_side.append(cum)
		lane_wp.append(per_side)
		lane_perp.append(perp_side)
		lane_cum.append(cum_side)
		lane_len[li] = (cum_side[0] as PackedFloat32Array)[-1]
	info["lane_len_m"] = [snappedf(lane_len[0], 0.1), snappedf(lane_len[1], 0.1)]


## Point de la voie [param li] à [param dist] m de la base du camp [param side] (et son indice de point de passage).
func lane_point(side: int, li: int, dist: float) -> Vector3:
	var wp: PackedVector3Array = lane_wp[li][side]
	var cum: PackedFloat32Array = lane_cum[li][side]
	dist = clampf(dist, 0.0, cum[-1])
	var i := cum.bsearch(dist)
	if i <= 0:
		return wp[0]
	var u := (dist - cum[i - 1]) / maxf(cum[i] - cum[i - 1], 0.001)
	return wp[i - 1].lerp(wp[i], u)


func lane_index(side: int, li: int, dist: float) -> int:
	return clampi((lane_cum[li][side] as PackedFloat32Array).bsearch(dist), 1, (lane_wp[li][side] as PackedVector3Array).size() - 1)


func fountain(side: int) -> Vector3:
	return Vector3(-95.0 if side == 0 else 95.0, 0.3, 0)


# --- rendu -----------------------------------------------------------------------------------

func _build_render() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	Gfx.style_sky(sm)
	sky.sky_material = sm
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	Gfx.style_environment(env)
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -35, 0)
	add_child(sun)
	Gfx.style_sun(sun)
	sun.shadow_enabled = opt.shadows == "1"
	cam = Camera3D.new()
	cam.fov = 50.0
	cam.far = 400.0
	add_child(cam)
	cam.current = true


func _update_camera(delta: float) -> void:
	if cam == null:
		return
	if String(opt.cam) == "wide":
		cam.global_position = Vector3(-10, 70, -10)
		cam.look_at(Vector3(-10, 0, -40), Vector3.UP)
		return
	var at := focus.global_position if is_instance_valid(focus) else Vector3(-20, 0, -46)  # (sans héros : le front du Soleil)
	# distance 22 m (caméra du mode, MOBA.md § 7.9), plongée 55°
	var want := at + Vector3(0, 22.0 * sin(deg_to_rad(55.0)), 22.0 * cos(deg_to_rad(55.0)))
	cam.global_position = cam.global_position.lerp(want, clampf(delta * 4.0, 0.0, 1.0)) if cam.global_position.length() > 0.1 else want
	cam.look_at(cam.global_position - Vector3(0, sin(deg_to_rad(55.0)), cos(deg_to_rad(55.0))), Vector3.UP)


# --- unités ----------------------------------------------------------------------------------

func _make_tower(side: int, at: Vector3, is_core: bool) -> Node:
	var tw = TOWER.new()
	tw.probe = self
	tw.side = side
	tw.is_core = is_core
	tw.mb_side = side
	add_child(tw)
	tw.global_position = at
	towers.append(tw)
	return tw


func _place_structures() -> void:
	for side in 2:
		cores[side] = _make_tower(side, Vector3(-88.0 if side == 0 else 88.0, 0, 0), true)
		for li in 2:
			for f in TOWER_AT:
				var d: float = f * lane_len[li]
				var p := lane_point(side, li, d)
				var i := lane_index(side, li, d)
				var perp: Vector3 = lane_perp[li][side][i]
				_make_tower(side, p + perp * (LANE_W * 0.5 + 1.5) * (1.0 if li == 0 else -1.0), false)


func _spawn_heroes() -> void:
	var n := clampi(int(opt.heroes), 0, 8)
	var level := int(opt.level)
	var hp_sum := 0.0
	var auto_sum := 0.0
	var def_sum := 0.0
	for k in n:
		var side := k % 2
		var role := k / 2
		var cid: String = TEAMS[side][role]
		var t0 := Time.get_ticks_usec()
		var r = HERO.new()
		r.probe = self
		r.side = side
		r.mb_side = side
		r.role_lane = ROLE_LANE[role]
		r.ally = side == 0
		r.setup(cid, level, int(opt.diff))
		var sheet := Royale.sheet(cid, level, {})
		r.use_sheet(sheet)
		sheet.free()
		r.travel_speed = Player.BASE_SPEED * (1.0 + float(GameData.class_data(cid).get("base", {}).get("move_speed", 0.0)))
		r.display_name = "%s %s" % ["Bleu" if side == 0 else "Rouge", cid]
		add_child(r)
		r.global_position = spawn_point(r)
		spawn_hero_ms.append((Time.get_ticks_usec() - t0) / 1000.0)
		heroes.append(r)
		hp_sum += r.max_hp
		auto_sum += r.atk * float(r.auto_step.get("mult", 1.0)) * PvpCaps.basic_mult()
		def_sum += r.defense
		if side == 0 and role == 2:
			focus = r  # caméra : le tireur bleu du Soleil
	if n > 0:
		hero_ref_hp = hp_sum / n
		hero_ref_auto = auto_sum / n
		hero_ref_def = def_sum / n
	if focus == null and not heroes.is_empty():
		focus = heroes[0]
	info["hero_hp"] = snappedf(hero_ref_hp, 1.0)
	info["hero_auto"] = snappedf(hero_ref_auto, 0.1)


func spawn_point(h) -> Vector3:
	var side: int = h.side
	if h.role_lane < 0:
		return Vector3(-30.0 if side == 0 else 30.0, 0.3, 4.0 if side == 0 else -4.0)
	return lane_point(side, h.role_lane, TOWER_AT[1] * lane_len[h.role_lane]) + Vector3.UP * 0.3


## But d'un héros sans adversaire à portée : 4 m derrière le front de sa vague (au moins sa T1), ou la rivière (jungle).
func hero_goal(h) -> Vector3:
	var side: int = h.side
	if h.role_lane < 0:
		return Vector3(0, 0, 12.0 if side == 0 else -12.0)
	var li: int = h.role_lane
	var d := maxf(float(front[side][li]) - 4.0, TOWER_AT[1] * lane_len[li] - 6.0)
	return lane_point(side, li, d)


func _spawn_camps() -> void:
	var n := clampi(int(opt.camps), 0, 24)
	for k in n:
		var c: Vector2 = CAMPS[(k / 2) % CAMPS.size()]
		var mirror := (k / 2) >= CAMPS.size() / 2
		var p := Vector3(c.x, 0.3, c.y) * (Vector3(-1, 1, -1) if mirror else Vector3.ONE)
		p += Vector3(1.6 * (k % 2) - 0.8, 0, 0)
		var m = MINION.new()
		m.probe = self
		m.camp = true
		m.configure(GameData.monster(CAMP_IDS[k % 2]), false, int(opt.level))
		add_child(m)
		m.global_position = p
		camps.append(m)


func _spawn_initial_minions() -> void:
	var quota := int(opt.minions) / 4
	for side in 2:
		for li in 2:
			for k in quota:
				var d := lerpf(0.12, 0.44, float(k) / maxf(quota - 1, 1)) * lane_len[li]
				_spawn_minion(side, li, k % 5 >= 3, d)


func count_lane(side: int, li: int) -> int:
	var n := 0
	for m in minions:
		if m.side == side and m.lane == li and not m.is_dead:
			n += 1
	return n


func _spawn_minion(side: int, li: int, ranged: bool, dist: float) -> void:
	var t0 := Time.get_ticks_usec()
	var m = null
	var bucket: Array = spare[1 if ranged else 0]
	if pool_on and not bucket.is_empty():
		m = bucket.pop_back()
		m.side = side
		m.mb_side = side
		m.lane = li
		m.reuse(lane_point(side, li, dist) + Vector3.UP * 0.3, lane_index(side, li, dist))
		events.reused += 1
	else:
		m = MINION.new()
		m.probe = self
		m.side = side
		m.mb_side = side
		m.lane = li
		m.ranged = ranged
		m.lite = lite_on
		m.configure(GameData.monster(RANGED_ID if ranged else MELEE_ID), false, int(opt.level))
		m.max_hp = hero_ref_auto * (3.0 if ranged else 4.0)
		m.hp = m.max_hp
		m.defense = 0.0
		m.atk = hero_ref_hp * 0.03 * (100.0 + hero_ref_def) / 100.0
		m.move_speed = randf_range(3.9, 4.1)
		m.wp_i = lane_index(side, li, dist)
		add_child(m)
		m.global_position = lane_point(side, li, dist) + Vector3.UP * 0.3
	minions.append(m)
	events.minion_spawns += 1
	spawn_minion_ms.append((Time.get_ticks_usec() - t0) / 1000.0)


func on_minion_death(_m) -> void:
	events.minion_deaths += 1


## Sbire recyclé (fin de son animation de mort) : retiré de la liste active, gardé pour la prochaine vague.
func release_minion(m) -> void:
	minions.erase(m)
	spare[1 if m.ranged else 0].append(m)


func forget_minion(m) -> void:
	minions.erase(m)


# --- cibles ----------------------------------------------------------------------------------
## Genres : 1 héros, 2 sbire, 4 structure.

func _cell(p: Vector3, size: float) -> Vector2i:
	return Vector2i(floori(p.x / size), floori(p.z / size))


func _rebuild_grids() -> void:
	grid.clear()
	sep_grid.clear()
	for list in [heroes, minions, towers]:
		for u in list:
			if u.is_dead:
				continue
			var p: Vector3 = u.global_position
			var k := Vector3i(floori(p.x / GRID_CELL), floori(p.z / GRID_CELL), u.mb_side)
			if grid.has(k):
				grid[k].append(u)
			else:
				grid[k] = [u]
			if u.mb_kind != 4:
				var ks := Vector3i(floori(p.x / SEP_CELL), floori(p.z / SEP_CELL), u.mb_side)
				if sep_grid.has(ks):
					sep_grid[ks].append(u)
				else:
					sep_grid[ks] = [u]


## Combattants ennemis de [param side] à moins de [param r] m de [param p] (genres [param kinds]).
func enemies_near(side: int, p: Vector3, r: float, kinds: int) -> Array:
	var t0 := Time.get_ticks_usec()
	var out := _enemies_near(side, p, r, kinds)
	cost.query += Time.get_ticks_usec() - t0
	events.queries += 1
	return out


func _enemies_near(side: int, p: Vector3, r: float, kinds: int) -> Array:
	var out: Array = []
	var foe := 1 - side
	var r2 := r * r
	if grid_on:
		var c0 := Vector2i(floori((p.x - r) / GRID_CELL), floori((p.z - r) / GRID_CELL))
		var c1 := Vector2i(floori((p.x + r) / GRID_CELL), floori((p.z + r) / GRID_CELL))
		for cx in range(c0.x, c1.x + 1):
			for cz in range(c0.y, c1.y + 1):
				var cell: Variant = grid.get(Vector3i(cx, cz, foe))
				if cell == null:
					continue
				for u in cell:
					if (u.mb_kind & kinds) != 0 and not u.is_dead and p.distance_squared_to(u.global_position) <= r2 + u.radius * u.radius * 4.0:
						out.append(u)
		return out
	# groupes de la scène (ce que font Monster._hostile_pool et Combatant.hostile_targets aujourd'hui)
	var pool: Array = get_tree().get_nodes_in_group("monsters" if foe == 1 else "heroes")
	if (kinds & 4) != 0:
		pool += get_tree().get_nodes_in_group("mb_towers")
	for n in pool:
		var u := n as Combatant
		if u == null or u.is_dead:
			continue
		var kind = u.get("mb_kind")
		if kind == null or (int(kind) & kinds) == 0 or int(u.get("mb_side")) != foe:
			continue
		if p.distance_squared_to(u.global_position) <= r2 + u.radius * u.radius * 4.0:
			out.append(u)
	return out


func _nearest_of(p: Vector3, list: Array, kind: int) -> Combatant:
	var best: Combatant = null
	var bd := INF
	for u in list:
		if u.mb_kind != kind:
			continue
		var d := p.distance_squared_to(u.global_position)
		if d < bd:
			bd = d
			best = u
	return best


## Sbire : sbire ennemi le plus proche à portée d'aggro, sinon structure, sinon héros.
func minion_target(m) -> Combatant:
	var aggro := 11.0 if m.ranged else 9.0
	var near := enemies_near(m.side, m.global_position, aggro, 7)
	if near.is_empty():
		return null
	for kind in [2, 4, 1]:
		var t := _nearest_of(m.global_position, near, kind)
		if t != null:
			return t
	return null


## Tour : le sbire le plus proche à portée d'abord, puis le héros le plus proche.
func tower_target(tw) -> Combatant:
	var near := enemies_near(tw.side, tw.global_position, tw.range_m, 3)
	if near.is_empty():
		return null
	var t := _nearest_of(tw.global_position, near, 2)
	return t if t != null else _nearest_of(tw.global_position, near, 1)


## Tour sans cible à portée (banc --busy=1) : l'ennemi le plus proche à 45 m (tir à blanc).
func tower_far_target(tw) -> Combatant:
	var near := enemies_near(tw.side, tw.global_position, 45.0, 3)
	var t := _nearest_of(tw.global_position, near, 2)
	return t if t != null else _nearest_of(tw.global_position, near, 1)


## Héros : adversaires (héros et sbires, pas les structures) à moins de HERO_AGGRO m.
func hero_pool(h) -> Array:
	return enemies_near(h.side, h.global_position, HERO_AGGRO, 3)


## Écartement d'un sbire (grille fine de son camp, 8 voisins au plus).
func separation(u) -> Vector3:
	var push := Vector3.ZERO
	var p: Vector3 = u.global_position
	var c := Vector2i(floori(p.x / SEP_CELL), floori(p.z / SEP_CELL))
	var seen := 0
	for dx in range(-1, 2):
		for dz in range(-1, 2):
			var cell: Variant = sep_grid.get(Vector3i(c.x + dx, c.y + dz, u.mb_side))
			if cell == null:
				continue
			for o in cell:
				if o == u:
					continue
				var to: Vector3 = p - o.global_position
				to.y = 0.0
				var min_d: float = u.radius + o.radius
				var d := to.length()
				if d < min_d and d > 0.001:
					push += to / d * (min_d - d)
				seen += 1
				if seen >= 8:
					return push
	return push


# --- tirs ----------------------------------------------------------------------------------

func fire_bolt(src: Combatant, target: Combatant, dmg: float) -> void:
	var b = null
	if pool_bolts and not bolts_free.is_empty():
		b = bolts_free.pop_back()
	else:
		b = BOLT.new()
		b.probe = self
		b.shared = pool_bolts
		add_child(b)
	b.launch(src, target, dmg, src.global_position + Vector3.UP * (4.5 if src.get("mb_kind") == 4 else 1.0))
	bolts_live += 1
	events.bolts += 1


func bolt_done(b) -> void:
	bolts_live -= 1
	if pool_bolts:
		bolts_free.append(b)
	else:
		b.queue_free()


# --- boucle -----------------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if not _running:
		return
	_phys_t0 = Time.get_ticks_usec()
	# coûts de l'image physique précédente (les unités les ont ajoutés pendant leur _physics_process)
	if measuring:
		for k in cost:
			if not hist.has(k):
				hist[k] = []  # (Array : un tableau « Packed » lu dans un dictionnaire serait une copie)
			hist[k].append(cost[k] / 1000.0)
	for k in cost:
		cost[k] = 0
	t += delta
	PvpCaps.elapsed = t
	var t0 := Time.get_ticks_usec()
	if grid_on:
		_rebuild_grids()
	var t1 := Time.get_ticks_usec()
	cost.grid = t1 - t0
	_wave_t -= delta
	if _wave_t <= 0.0:
		_wave_t = WAVE_EVERY
		var quota := int(opt.minions) / 4
		for side in 2:
			for li in 2:
				var missing := mini(quota - count_lane(side, li), int(opt.wave_max))
				for k in maxi(missing, 0):
					_spawn_minion(side, li, k >= 3, 4.0 + 1.5 * k)
	_slow_t -= delta
	if _slow_t <= 0.0:
		_slow_t = 0.5
		_update_fronts()
		if lod_on:
			_update_lod()
	cost.manager = Time.get_ticks_usec() - t1
	if not measuring and t >= float(opt.warm):
		measuring = true
		info["spawn_minion_ms_setup"] = _stats(spawn_minion_ms)
		spawn_minion_ms = []
		for k in events:
			events[k] = 0
		print("[mb0] mesure : %d s (après %d s de mise en route)" % [int(opt.dur), int(opt.warm)])
	if measuring and t >= float(opt.warm) + float(opt.dur):
		_running = false
		_finish()


func phys_end() -> void:
	if measuring and _running and _phys_t0 > 0:
		nodes_phys_ms.append((Time.get_ticks_usec() - _phys_t0) / 1000.0)


func _update_fronts() -> void:
	for side in 2:
		for li in 2:
			front[side][li] = 0.0
	for m in minions:
		if m.is_dead:
			continue
		var d: float = (lane_cum[m.lane][m.side] as PackedFloat32Array)[mini(m.wp_i, (lane_cum[m.lane][m.side] as PackedFloat32Array).size() - 1)] - WP_STEP
		front[m.side][m.lane] = maxf(front[m.side][m.lane], d)


## Loin de la caméra : les sbires réfléchissent une image sur 2 (au-delà de 35 m) ou sur 4 (70 m) ; un camp sans héros à 25 m dort.
func _update_lod() -> void:
	var f: Vector3 = focus.global_position if is_instance_valid(focus) else Vector3.ZERO
	if lite_on:
		for m in minions:
			if m.is_dead:
				continue
			var d := f.distance_to(m.global_position)
			m.lod = 0 if d < 35.0 else (1 if d < 70.0 else 2)
	for c in camps:
		var awake := false
		for h in heroes:
			if not h.is_dead and h.global_position.distance_squared_to(c.global_position) < 625.0:
				awake = true
				break
		c.set_physics_process(awake)
		if c.anim:
			c.anim.speed_scale = 1.0 if awake else 0.0


func _process(delta: float) -> void:
	_update_camera(delta)
	var now := Time.get_ticks_usec()
	var dt := (now - _last_usec) / 1000.0
	_last_usec = now
	if not measuring or not _running:
		return
	frame_ms.append(dt)
	phys_ms.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0)
	proc_ms.append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
	nav_ms.append(Performance.get_monitor(Performance.TIME_NAVIGATION_PROCESS) * 1000.0)
	if not headless:
		gpu_ms.append(RenderingServer.viewport_get_measured_render_time_gpu(_rid))
		rcpu_ms.append(RenderingServer.viewport_get_measured_render_time_cpu(_rid) + RenderingServer.get_frame_setup_time_cpu())
	_sample_t -= delta
	if _sample_t <= 0.0:
		_sample_t = 0.25
		_sample()


func _sample() -> void:
	var alive := 0
	for m in minions:
		if not m.is_dead:
			alive += 1
	var fighting := 0
	for h in heroes:
		if not h.is_dead and h.goal == Vector3.INF:
			fighting += 1
	var proj := 0
	var fx := 0
	var nums := 0
	for c in get_children():
		if c is Projectile:
			proj += 1
		elif c is EdenFx:
			fx += 1
		elif c is DamageNumber:
			nums += 1
	samples.minions.append(alive)
	samples.heroes_fighting.append(fighting)
	samples.bolts.append(bolts_live)
	samples.projectiles.append(proj)
	samples.fx.append(fx)
	samples.numbers.append(nums)
	samples.telegraphs.append(get_tree().get_nodes_in_group("telegraphs").size())
	samples.nodes.append(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	samples.objects.append(Performance.get_monitor(Performance.OBJECT_COUNT))
	samples.mem_mb.append(Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0)
	samples.vmem_mb.append(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0)
	samples.draw_calls.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	samples.primitives.append(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))


# --- résultats --------------------------------------------------------------------------------

static func _stats(a) -> Dictionary:
	var arr: Array = Array(a)
	if arr.is_empty():
		return {"n": 0}
	arr.sort()
	var s := 0.0
	for v in arr:
		s += float(v)
	var n := arr.size()
	return {"n": n, "mean": snappedf(s / n, 0.001), "p50": snappedf(float(arr[int(0.5 * (n - 1))]), 0.001),
		"p95": snappedf(float(arr[int(0.95 * (n - 1))]), 0.001), "p99": snappedf(float(arr[int(0.99 * (n - 1))]), 0.001),
		"max": snappedf(float(arr[n - 1]), 0.001)}


func _finish() -> void:
	var res := {"config": opt.duplicate(), "headless": headless, "info": info, "events": events,
		"frame_ms": _stats(frame_ms), "nodes_phys_ms": _stats(nodes_phys_ms), "physics_ms": _stats(phys_ms), "process_ms": _stats(proc_ms),
		"nav_ms": _stats(nav_ms),
		"spawn_minion_ms": _stats(spawn_minion_ms), "spawn_hero_ms": _stats(spawn_hero_ms), "categories": {}, "samples": {}}
	if not headless:
		res["gpu_ms"] = _stats(gpu_ms)
		res["render_cpu_ms"] = _stats(rcpu_ms)
	for k in hist:
		res.categories[k] = _stats(hist[k])
	for k in samples:
		res.samples[k] = _stats(samples[k])
	res["frames"] = frame_ms.size()
	res["sim_s"] = snappedf(t, 0.01)
	var hero_attacks := 0
	for h in heroes:
		hero_attacks += int(h.attacks)
	res.events.hero_attacks = hero_attacks
	var f: Dictionary = res.frame_ms
	print(("[mb0] image : moyenne %.2f ms · p95 %.2f · p99 %.2f · max %.2f (%d images) · passe physique des nœuds moy %.2f p50 %.2f "
		+ "p95 %.2f · navigation moy %.3f") % [
		f.get("mean", 0.0), f.get("p95", 0.0), f.get("p99", 0.0), f.get("max", 0.0), int(f.get("n", 0)), float(res.nodes_phys_ms.get("mean", 0.0)),
		float(res.nodes_phys_ms.get("p50", 0.0)), float(res.nodes_phys_ms.get("p95", 0.0)),
		float(res.nav_ms.get("mean", 0.0))])
	if not headless:
		print("[mb0] GPU : moyenne %.2f ms · p95 %.2f · rendu CPU moy %.2f" % [float(res.gpu_ms.get("mean", 0.0)), float(res.gpu_ms.get("p95", 0.0)),
			float(res.render_cpu_ms.get("mean", 0.0))])
	var cats := []
	for k in res.categories:
		cats.append("%s %.3f/%.3f" % [k, float(res.categories[k].get("mean", 0.0)), float(res.categories[k].get("p95", 0.0))])
	print("[mb0] scripts (ms moy/p95 par image physique) : ", " · ".join(cats))
	print(("[mb0] unités : sbires %.1f (max %d) · héros au combat %.1f · traits %.1f · Projectile %.1f · zones rouges %.1f · effets %.1f · "
		+ "chiffres %.1f · nœuds %d · mémoire %.0f Mo") % [
		float(res.samples.minions.get("mean", 0)), int(res.samples.minions.get("max", 0)), float(res.samples.heroes_fighting.get("mean", 0)),
		float(res.samples.bolts.get("mean", 0)), float(res.samples.projectiles.get("mean", 0)), float(res.samples.telegraphs.get("mean", 0)),
		float(res.samples.fx.get("mean", 0)), float(res.samples.numbers.get("mean", 0)), int(res.samples.nodes.get("max", 0)),
		float(res.samples.mem_mb.get("max", 0))])
	print("[mb0] événements : ", JSON.stringify(res.events), " · création sbire ", JSON.stringify(res.spawn_minion_ms))
	if opt.has("shot") and not headless:
		var img := get_viewport().get_texture().get_image()
		img.save_jpg(String(opt.shot), 0.85)
	if opt.has("out"):
		var fa := FileAccess.open(String(opt.out), FileAccess.WRITE)
		if fa:
			fa.store_string(JSON.stringify(res))
			fa.close()
	await get_tree().process_frame
	get_tree().quit()
