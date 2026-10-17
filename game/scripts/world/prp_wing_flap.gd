class_name PrpWingFlap
extends Node
## Battement léger des ailes maison (lot PRP-2) : les deux moitiés AileG / AileD d'un dos `back_prp_*.glb` (coupées par
## tools/art/prp_blender.py, origine à la charnière au milieu du dos) tournent autour de l'axe X de l'os du dos (le haut
## du dos) : elles se replient vers l'arrière puis s'ouvrent, en boucle. Aucun os ni animation dans le GLB : deux
## transformations par image. Réglage « Réduire les animations » (UiFeel.reduce_motion) : ailes immobiles, ouvertes.
## Posé par EdenModel.dress quand la pièce a ces deux nœuds.

const AMPLITUDE := 0.24  # radians (≈ 14°) : repli maximal vers l'arrière
const PERIOD := 1.9  # secondes par battement

var _wings: Array = []  # [nœud, transformation de repos, signe]
var _t := 0.0


func _ready() -> void:
	var part := get_parent()
	for n in ["AileG", "AileD"]:
		var w := part.find_child(n, true, false) as Node3D
		if w:
			_wings.append([w, w.transform, -1.0 if n == "AileG" else 1.0])
	_t = randf() * PERIOD  # deux héros côte à côte ne battent pas en même temps
	set_process(_wings.size() == 2)


func _process(delta: float) -> void:
	var still := UiFeel.reduce_motion
	_t = fmod(_t + delta, PERIOD)
	var a := 0.0 if still else AMPLITUDE * (0.5 - 0.5 * cos(TAU * _t / PERIOD))
	for w in _wings:
		var rest: Transform3D = w[1]
		(w[0] as Node3D).transform = Transform3D(rest.basis * Basis(Vector3.RIGHT, a * float(w[2])), rest.origin)
