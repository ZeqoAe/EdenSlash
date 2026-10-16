class_name XpOrbs
extends Node3D
## Orbes d'expérience lâchées par les monstres : le héros les ramasse en passant dans sa
## zone de collecte (agrandie par la carte Aimant) ; la carte Rappel les ramène toutes.
## Toutes les orbes sont dessinées en un seul appel (MultiMesh) : la rage en lâche des
## centaines. Au-delà de MAX_ORBS, la nouvelle orbe reprend la valeur de l'orbe la plus loin du héros (jamais perdue).

const MAX_ORBS := 300
const MAGNET := 3.5  # rayon de collecte de base (m) : les orbes y sont attirées
const COLLECT := 0.9
const AUTOPLAY_MAGNET := 40.0  # pilote automatique (tests) : il ne va pas chercher les orbes

var _pos := PackedVector3Array()
var _val := PackedFloat32Array()
var _pull := PackedByteArray()  # 1 : attirée vers le héros (ne revient plus en arrière)
var _mm: MultiMesh
var _player: Player
var _recall_until := -1.0
var _t := 0.0
## Mesures (lignes « [sv-xp] », test_sv9) : orbes posées, orbes oubliées reprises par une nouvelle (plein), expérience
## lâchée / ramassée / reprise (brute, avant le multiplicateur du héros).
var stats := {"spawned": 0, "recycled": 0, "xp_in": 0.0, "xp_got": 0.0, "xp_recycled": 0.0}
## Pilote automatique avec la vraie zone de collecte (--human-magnet) : mesure ce qu'un joueur ramasse.
var _human_magnet := "--human-magnet" in OS.get_cmdline_user_args()


func _ready() -> void:
	_player = get_tree().get_first_node_in_group("player") as Player
	var mesh := SphereMesh.new()
	mesh.radius = 0.2
	mesh.height = 0.4
	mesh.radial_segments = 10
	mesh.rings = 5
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = true
	mesh.material = mat
	_mm = MultiMesh.new()
	_mm.transform_format = MultiMesh.TRANSFORM_3D
	_mm.use_colors = true
	_mm.mesh = mesh
	_mm.instance_count = MAX_ORBS
	_mm.visible_instance_count = 0
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = _mm
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


func count() -> int:
	return _pos.size()


## Orbe de [param value] points d'expérience à [param at] (sous le monstre).
func spawn(at: Vector3, value: float) -> void:
	if value <= 0.0:
		return
	var p := at + Vector3(randf_range(-0.5, 0.5), 0.35, randf_range(-0.5, 0.5))
	stats.xp_in += value
	if _pos.size() >= MAX_ORBS:
		# plein : l'orbe oubliée la plus loin du héros rejoint la nouvelle (lot S9). Avant, la nouvelle s'ajoutait à l'orbe la
		# plus proche d'elle, souvent laissée loin derrière : passé 300 orbes au sol, plus aucune n'apparaissait sous les
		# monstres et l'expérience partait là où le héros ne retournait pas (mesuré : 78 % des lâchers à plus de 12 m).
		var far := _farthest_free(p)
		value += _val[far]
		stats.recycled += 1
		stats.xp_recycled += _val[far]
		_remove(far)
	stats.spawned += 1
	_pos.append(p)
	_val.append(value)
	_pull.append(0)


## Indice de l'orbe la plus loin du héros (de [param from] sans héros) parmi celles qui ne volent pas déjà vers lui.
func _farthest_free(from: Vector3) -> int:
	var ref := _player.global_position if _player != null and is_instance_valid(_player) else from
	var best := 0
	var best_d := -1.0
	for i in _pos.size():
		var d := _pos[i].distance_squared_to(ref) if _pull[i] == 0 else -0.5
		if d > best_d:
			best_d = d
			best = i
	return best


## Retrait rapide : la dernière orbe prend la place de [param i].
func _remove(i: int) -> void:
	var last := _pos.size() - 1
	_pos[i] = _pos[last]
	_val[i] = _val[last]
	_pull[i] = _pull[last]
	_pos.resize(last)
	_val.resize(last)
	_pull.resize(last)


## Carte Rappel : toutes les orbes reviennent vers le héros.
func recall() -> void:
	_recall_until = _t + 4.0
	for i in _pull.size():
		_pull[i] = 1


## Tout ce qui reste est gagné tout de suite (entrée dans le donjon).
func collect_all_now() -> void:
	var total := 0.0
	for v in _val:
		total += v
	_pos.clear()
	_val.clear()
	_pull.clear()
	_mm.visible_instance_count = 0
	_give(total)


func _give(total: float) -> void:
	stats.xp_got += total
	if total > 0.0 and _player and not _player.is_dead:
		_player.gain_xp(roundi(total * _player.xp_mult))


func _process(delta: float) -> void:
	_t += delta
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Player
		if _player == null:
			return
	var pp := _player.global_position + Vector3.UP * 0.6
	var radius := (AUTOPLAY_MAGNET if _player.autoplay and not _player.autoplay_idle and not _human_magnet else MAGNET) * _player.pickup_mult
	var recalling := _t < _recall_until
	var gained := 0.0
	var i := _pos.size() - 1
	while i >= 0:
		var to := pp - _pos[i]
		var d := to.length()
		if _pull[i] == 0 and (d < radius or recalling):
			_pull[i] = 1
		if _pull[i] == 1:
			if d < COLLECT or _player.is_dead:
				gained += _val[i]
				_remove(i)
			else:
				_pos[i] += to / d * minf(d, maxf(9.0, d * 5.0) * delta)
		i -= 1
	_give(gained)
	# rendu : petite oscillation ; couleur et taille selon la valeur (vert, bleu, or)
	var big := maxf(1.0, GameData.xp_to_next(_player.level) * 0.04)
	var n := _pos.size()
	_mm.visible_instance_count = n
	for k in n:
		var v := _val[k]
		var col := Color(0.1, 0.85, 0.2) if v < big * 0.3 else (Color(0.1, 0.45, 1.0) if v < big else Color(1.0, 0.6, 0.0))
		var sc := 0.8 + minf(v / big, 2.0) * 0.4
		var bob := 0.0 if _pull[k] == 1 else sin(_t * 4.0 + k) * 0.08
		_mm.set_instance_transform(k, Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * sc), _pos[k] + Vector3.UP * bob))
		_mm.set_instance_color(k, col)
