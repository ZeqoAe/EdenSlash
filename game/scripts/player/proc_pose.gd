class_name ProcPose
extends SkeletonModifier3D
## Pose procédurale par-dessus les animations d'Eden (lot CHR-1, `conception/art/CHR.md` § Animation) : le corps commun n'a que
## 94 animations, sans coup de pied ni signe de mains ; ce calque oriente quelques os (bras, jambes, buste) vers des directions
## données, mélangé à l'animation en cours (poids qui monte et descend), après elle (SkeletonModifier3D : appliqué une fois
## l'AnimationPlayer passé).
## Une pose = { nom d'os Bip : direction voulue de l'os } dans le repère du bassin au repos (Z en haut, le héros regarde +X,
## sa gauche est +Y ; le repère suit le bassin animé) ; l'os garde sa torsion, seule sa direction (axe X des os Bip, le long de l'os) tourne. Les os sont traités
## parent d'abord. Sans pose active, rien n'est touché (poids nul).
## Réduire les animations (Paramètres) ne coupe pas ces poses : ce sont des gestes de combat, pas un effet décoratif.

## Poses connues (directions dans le repère du squelette).
const POSES := {
	# coup de pied de face (3e coup du taï-jutsu) : jambe droite tendue devant à hauteur de hanche, buste en arrière
	"kick": {"Bip01 Spine": Vector3(-0.32, 0.0, 1.0), "Bip01 R Thigh": Vector3(1.0, -0.12, 0.38), "Bip01 R Calf": Vector3(1.0, -0.1, 0.5),
		"Bip01 R Foot": Vector3(0.3, 0.0, 1.0), "Bip01 L Thigh": Vector3(-0.15, 0.08, -1.0), "Bip01 L Calf": Vector3(0.2, 0.05, -1.0)},
	# signe des mains (Double de brume) : les deux mains jointes devant la poitrine, doigts vers le haut
	"seal": {"Bip01 L UpperArm": Vector3(0.45, 0.25, -0.85), "Bip01 L Forearm": Vector3(0.75, -0.62, 0.25), "Bip01 L Hand": Vector3(0.25, -0.15, 1.0),
		"Bip01 R UpperArm": Vector3(0.45, -0.25, -0.85), "Bip01 R Forearm": Vector3(0.75, 0.62, 0.25), "Bip01 R Hand": Vector3(0.25, 0.15, 1.0)},
	# sphère tenue devant soi, bras droit tendu, paume en avant (Sphère tourbillon, charge)
	"hold_front": {"Bip01 R UpperArm": Vector3(0.85, -0.35, -0.1), "Bip01 R Forearm": Vector3(1.0, -0.12, 0.05), "Bip01 R Hand": Vector3(1.0, 0.0, 0.0),
		"Bip01 L UpperArm": Vector3(0.6, 0.3, -0.6), "Bip01 L Forearm": Vector3(0.9, -0.35, 0.0)},
	# bras droit levé au ciel (Étoile du Tourbillon, charge)
	"raise": {"Bip01 Spine": Vector3(-0.12, 0.0, 1.0), "Bip01 R UpperArm": Vector3(0.12, -0.3, 1.0), "Bip01 R Forearm": Vector3(0.05, -0.12, 1.0),
		"Bip01 R Hand": Vector3(0.0, 0.0, 1.0), "Bip01 L UpperArm": Vector3(0.3, 0.55, -0.6)},
}
const FADE_IN := 0.08
const FADE_OUT := 0.16

var pose_name := ""
var skip: Array = []  # poses remplacées par des animations neuves (ClassPremium, méta « proc_skip » du modèle)
var _pose: Dictionary = {}
var _weight := 0.0
var _until := 0.0  # instant (s, horloge du moteur) où la pose commence à retomber
var _last := 0.0
var _order: Array = []  # indices des os de la pose, parent d'abord


## Pose [param name] tenue [param duration] s (puis retombée en FADE_OUT s).
func hold(name: String, duration: float) -> void:
	if not POSES.has(name) or name in skip:
		return
	if name != pose_name:
		pose_name = name
		_pose = POSES[name]
		_order = []
	_until = _now() + duration


## Lâche la pose tout de suite (retombée en FADE_OUT s).
func release() -> void:
	_until = _now()


func active() -> bool:
	return _weight > 0.001 or _now() < _until


## Le calque du squelette de [param model] (créé au premier appel).
static func on(model: Node3D) -> ProcPose:
	var sk := model.find_child("Skeleton3D", true, false) as Skeleton3D
	if sk == null:
		return null
	for c in sk.get_children():
		if c is ProcPose:
			(c as ProcPose).skip = model.get_meta("proc_skip", [])
			return c
	var p := ProcPose.new()
	p.name = "ProcPose"
	p.skip = model.get_meta("proc_skip", [])
	sk.add_child(p)
	return p


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0


func _process_modification() -> void:
	var sk := get_skeleton()
	if sk == null or _pose.is_empty():
		return
	var t := _now()
	var dt := clampf(t - _last, 0.0, 0.1)
	_last = t
	var want := 1.0 if t < _until else 0.0
	_weight = move_toward(_weight, want, dt / (FADE_IN if want > _weight else FADE_OUT))
	if _weight <= 0.001:
		return
	if _order.is_empty():
		for bn in _pose:
			var i := sk.find_bone(String(bn))
			if i >= 0:
				_order.append(i)
		_order.sort()  # les os Bip sont rangés parent d'abord
	var k := _weight * _weight * (3.0 - 2.0 * _weight)  # lissé
	# directions données par rapport au bassin (l'animation peut tourner tout le corps : garde de côté, pivot)
	var frame := sk.get_bone_global_pose(0).basis.orthonormalized() * sk.get_bone_global_rest(0).basis.orthonormalized().inverse()
	for i: int in _order:
		var want_dir: Vector3 = (frame * (_pose[sk.get_bone_name(i)] as Vector3)).normalized()
		var g := sk.get_bone_global_pose(i)
		var cur := g.basis.x.normalized()
		var axis := cur.cross(want_dir)
		var ang := cur.angle_to(want_dir) * k
		if axis.length() < 0.0001 or ang < 0.0001:
			continue
		var rot := Basis(axis.normalized(), ang)
		var ng := Transform3D(rot * g.basis, g.origin)
		var parent := sk.get_bone_parent(i)
		var pg := sk.get_bone_global_pose(parent) if parent >= 0 else Transform3D.IDENTITY
		var local := pg.affine_inverse() * ng
		sk.set_bone_pose_rotation(i, local.basis.get_rotation_quaternion())
