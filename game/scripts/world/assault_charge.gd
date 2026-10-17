class_name AssaultCharge
extends Node3D
## La Charge de L'Assaut (lot TAC-3, étude conception/benchmark/TACTIQUE.md § 7.2, rapport R_TAC_3.md) : l'objet que porte un
## attaquant, qu'il lâche à sa mort (ou de lui-même), qu'un autre attaquant ramasse en passant, qu'on pose sur un site et
## qu'on désamorce. Ce nœud ne décide rien : le directeur (AssaultDirector) lui dit où elle est et ce qui lui arrive ; il
## tient son dessin (lanterne « autocollant » soleil contourée d'encre, mèche fraise), ses bips qui accélèrent après la
## pose, son anneau au sol, son explosion et son désamorçage.
##
##   charge.carry(héros) ; charge.drop_at(point) ; charge.plant_at(point, "A", 40.0) ; charge.update(delta, reste)
##   charge.explode() ; charge.defuse() ; AssaultCharge.beep_interval(reste, mèche)
##
## États : « carried » (sur le dos du porteur : visible avec lui, donc caché quand l'équipe adverse ne le voit pas),
## « ground » (au sol : toujours visible pour l'Attaque, pour la Défense seulement si elle voit l'endroit), « planted »
## (position connue de tous), « defused », « exploded ».

const STATES := ["carried", "ground", "planted", "defused", "exploded"]
## Bips : intervalle (s) au début et à la fin de la mèche ; les 10 dernières secondes, deux fois plus vite.
const BEEP_SLOW := 1.0
const BEEP_FAST := 0.14
const BEEP_LATE := 10.0
## Taille de la lanterne (m) au sol et sur le dos.
const SIZE := 0.42

var state := "carried"
var holder: Combatant = null
var site := ""
var fuse := 40.0
var left := 0.0
## Bips joués (tests, mesures).
var beeps := 0
var _body: Node3D  # lanterne (au sol, posée)
var _pack: Node3D  # lanterne sur le dos du porteur
var _ring: MeshInstance3D  # anneau qui pulse autour de la Charge posée
var _ring_mat: StandardMaterial3D
var _spark: MeshInstance3D
var _light: OmniLight3D
var _beep: AudioStreamPlayer3D
var _beep_t := 0.0
var _t := 0.0


func _ready() -> void:
	name = "Charge"
	_body = _lantern(1.0)
	add_child(_body)
	_ring = MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 1.05
	tm.outer_radius = 1.25
	tm.rings = 32
	_ring.mesh = tm
	_ring_mat = StandardMaterial3D.new()
	_ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ring_mat.albedo_color = Color(UiTheme.color("bonbon.fraise.base"), 0.0)
	_ring.material_override = _ring_mat
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ring.scale = Vector3(1, 0.15, 1)
	_ring.position.y = 0.05
	add_child(_ring)
	_light = OmniLight3D.new()
	_light.light_color = UiTheme.color("bonbon.soleil.base")
	_light.omni_range = 4.0
	_light.light_energy = 0.0
	_light.position.y = 0.8
	add_child(_light)
	_beep = AudioStreamPlayer3D.new()
	_beep.stream = Sfx._stream("ui/tick.wav")
	_beep.unit_size = 14.0
	_beep.max_distance = 90.0
	_beep.volume_db = -4.0
	add_child(_beep)
	_show_state()


## Lanterne-charge « autocollant » : boule soleil, coque d'encre (contour), chapeau d'encre, mèche fraise qui brille.
func _lantern(k: float) -> Node3D:
	var root := Node3D.new()
	var r := SIZE * k
	var ink := UiTheme.color("encre.900", Color("221a3a"))
	var ball := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = r * 1.8
	ball.mesh = sm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = UiTheme.color("bonbon.soleil.base")
	mat.emission_enabled = true
	mat.emission = UiTheme.color("bonbon.soleil.clair", Color("ffe27a"))
	mat.emission_energy_multiplier = 0.35
	ball.material_override = mat
	root.add_child(ball)
	var hull := MeshInstance3D.new()  # contour d'encre (coque retournée)
	var hm := SphereMesh.new()
	hm.radius = r * 1.12
	hm.height = r * 1.8 * 1.12
	hull.mesh = hm
	var hmat := StandardMaterial3D.new()
	hmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	hmat.albedo_color = ink
	hmat.cull_mode = BaseMaterial3D.CULL_FRONT
	hull.material_override = hmat
	root.add_child(hull)
	var cap := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r * 0.35
	cm.bottom_radius = r * 0.5
	cm.height = r * 0.45
	cap.mesh = cm
	cap.material_override = hmat
	cap.position.y = r * 0.95
	root.add_child(cap)
	var spark := MeshInstance3D.new()
	var spm := SphereMesh.new()
	spm.radius = r * 0.22
	spm.height = r * 0.44
	spark.mesh = spm
	var smat := StandardMaterial3D.new()
	smat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	smat.albedo_color = UiTheme.color("bonbon.fraise.base")
	spark.material_override = smat
	spark.position.y = r * 1.35
	root.add_child(spark)
	if k >= 1.0:
		_spark = spark
	for c in root.get_children():
		(c as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.position.y = r * 0.9
	return root


## Sur le dos de [param c] (porteur) : la lanterne le suit et se cache avec lui.
func carry(c: Combatant) -> void:
	state = "carried"
	holder = c
	site = ""
	_unpack()
	holder = c
	_pack = _lantern(0.6)
	_pack.name = "AssaultChargePack"
	c.add_child(_pack)
	_pack.position = Vector3(0, 2.05, 0)  # au-dessus de l'épaule : lisible de dessus
	_show_state()


func _unpack() -> void:
	if is_instance_valid(_pack):
		if _pack.get_parent() != null:
			_pack.get_parent().remove_child(_pack)  # (plus sur le dos dès maintenant)
		_pack.queue_free()
	_pack = null
	holder = null


## Au sol en [param p] (porteur à terre, ou lâchée).
func drop_at(p: Vector3) -> void:
	_unpack()
	state = "ground"
	global_position = p
	_show_state()


## Posée sur [param s] en [param p] : mèche de [param f] s.
func plant_at(p: Vector3, s: String, f: float) -> void:
	_unpack()
	state = "planted"
	site = s
	fuse = maxf(f, 0.1)
	left = fuse
	_beep_t = 0.0
	global_position = p
	_show_state()


## Intervalle entre deux bips quand il reste [param rest] s sur une mèche de [param f] s : de BEEP_SLOW à BEEP_FAST, deux
## fois plus vite les BEEP_LATE dernières secondes.
static func beep_interval(rest: float, f: float) -> float:
	var k := clampf(1.0 - rest / maxf(f, 0.1), 0.0, 1.0)
	var iv := lerpf(BEEP_SLOW, BEEP_FAST * 2.0, k * k)
	if rest <= BEEP_LATE:
		iv *= 0.5
	return maxf(iv, BEEP_FAST)


## Chaque image : la mèche (posée) et les bips ; [param rest] = temps restant (s).
func update(delta: float, rest: float) -> void:
	_t += delta
	if state == "carried" and not is_instance_valid(holder):
		holder = null
	if state != "planted":
		if is_instance_valid(_spark):
			_spark.visible = fmod(_t, 0.8) < 0.5
		return
	left = rest
	_beep_t -= delta
	var iv := beep_interval(rest, fuse)
	if _beep_t <= 0.0:
		_beep_t = iv
		beeps += 1
		if _beep.stream != null and is_inside_tree() and not Vfx.silent:
			_beep.pitch_scale = lerpf(1.0, 1.6, clampf(1.0 - rest / fuse, 0.0, 1.0))
			_beep.play()
		_light.light_energy = 3.0
		if is_instance_valid(_spark):
			_spark.visible = true
	_light.light_energy = maxf(0.0, _light.light_energy - delta * 3.0 / maxf(iv, 0.1))
	if is_instance_valid(_spark):
		_spark.visible = _light.light_energy > 0.6
	# anneau qui pulse au rythme des bips
	var ph := 1.0 - clampf(_beep_t / maxf(iv, 0.05), 0.0, 1.0)
	_ring.scale = Vector3(1.0 + ph * 0.5, 0.15, 1.0 + ph * 0.5)
	_ring_mat.albedo_color.a = 0.75 * (1.0 - ph)


## La mèche est au bout : onde de choc, éclair, son.
func explode() -> void:
	state = "exploded"
	_show_state()
	if is_inside_tree():
		Vfx.shockwave(self, global_position, 9.0, UiTheme.color("bonbon.mandarine.base"))
		Vfx.flash(self, global_position + Vector3.UP * 1.2, 7.0, UiTheme.color("bonbon.soleil.base"))
		Vfx.ring(self, global_position, 12.0, Color(UiTheme.color("bonbon.fraise.base"), 0.9))
		Sfx.play_at(self, global_position, "HitRock01.wav", 4.0)
		Sfx.play_at(self, global_position, "ui/banner.wav", 2.0)


## Désamorcée : la lumière s'éteint, un anneau lagon.
func defuse() -> void:
	state = "defused"
	_show_state()
	if is_inside_tree():
		Vfx.ring(self, global_position, 2.5, Color(UiTheme.color("bonbon.lagon.base"), 0.9))


func _show_state() -> void:
	if _body == null:
		return
	_body.visible = state in ["ground", "planted", "defused"]
	_ring.visible = state == "planted"
	if state != "planted":
		_light.light_energy = 0.0


## La lanterne au sol se montre-t-elle à l'écran ? (le directeur décide selon l'équipe regardée)
func set_shown(on: bool) -> void:
	visible = on
