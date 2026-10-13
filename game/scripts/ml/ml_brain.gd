class_name MlBrain
extends RefCounted
## Cerveau entraîné (réseau de neurones de la politique PPO, exporté par ia/export_brain.py)
## qui tourne dans le jeu, sans Python : il reçoit ce que voit l'IA (MlArena._obs) et rend
## l'action [déplacement, touche, visée].
## Fichier JSON : {"obs_size", "act": "tanh"|"relu", "layers": [{"w": [[...] par sortie], "b"}],
##   "head": {"w", "b"}, "heads": [9, 8, 3], "checks": [{"obs", "act"}]}.

var obs_size := 0
var heads: Array = []
var _act := "tanh"
var _layers: Array = []  # [{w: Array[PackedFloat32Array] (une ligne par sortie), b: PackedFloat32Array}]
var _head := {}
var checks: Array = []


static func load_file(path: String) -> MlBrain:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("cerveau introuvable : " + path)
		return null
	var d: Variant = JSON.parse_string(f.get_as_text())
	if not d is Dictionary:
		push_error("cerveau illisible : " + path)
		return null
	var b := MlBrain.new()
	b.obs_size = int(d.obs_size)
	b.heads = (d.heads as Array).map(func(x): return int(x))
	b._act = String(d.get("act", "tanh"))
	for l in d.layers:
		b._layers.append(_pack_layer(l))
	b._head = _pack_layer(d.head)
	b.checks = d.get("checks", [])
	return b


static func _pack_layer(l: Dictionary) -> Dictionary:
	var rows: Array[PackedFloat32Array] = []
	for r in l.w:
		rows.append(PackedFloat32Array(r))
	return {"w": rows, "b": PackedFloat32Array(l.b)}


## Sorties brutes (logits) des 3 choix, à la suite.
func logits(obs: Array) -> PackedFloat32Array:
	var x := PackedFloat32Array(obs)
	for l in _layers:
		x = _dense(l, x)
		for i in x.size():
			x[i] = tanh(x[i]) if _act == "tanh" else maxf(x[i], 0.0)
	return _dense(_head, x)


static func _dense(l: Dictionary, x: PackedFloat32Array) -> PackedFloat32Array:
	var rows: Array[PackedFloat32Array] = l.w
	var b: PackedFloat32Array = l.b
	var out := PackedFloat32Array()
	out.resize(rows.size())
	var n := x.size()
	for o in rows.size():
		var r := rows[o]
		var s := b[o]
		for i in n:
			s += r[i] * x[i]
		out[o] = s
	return out


## Action [déplacement, touche, visée]. [param temperature] 0 : le meilleur choix à chaque
## fois (le plus fort) ; > 0 : tirage au sort pondéré (plus humain, fait des erreurs).
func act(obs: Array, temperature := 0.0) -> Array:
	var z := logits(obs)
	var out: Array = []
	var k := 0
	for n in heads:
		var best := 0
		if temperature <= 0.0:
			for i in n:
				if z[k + i] > z[k + best]:
					best = i
		else:
			var m := z[k]
			for i in n:
				m = maxf(m, z[k + i])
			var p: Array = []
			var total := 0.0
			for i in n:
				var e := exp((z[k + i] - m) / temperature)
				p.append(e)
				total += e
			var r := randf() * total
			best = n - 1
			for i in n:
				r -= p[i]
				if r <= 0.0:
					best = i
					break
		out.append(best)
		k += n
	return out
