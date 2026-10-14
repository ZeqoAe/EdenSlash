class_name Breakables
extends Node3D
## Objets cassables de la carte (façon Megabonk) : jarres, caisses et tonneaux (un coup, ou en
## fonçant dedans), tas d'or (ramassés en passant), cristaux (3 coups : des gemmes). Tous
## dessinés en MultiMesh (un par modèle et par région de la carte) : un objet cassé devient
## invisible, rien n'est créé ni détruit pendant la run. Le directeur de run reçoit
## [signal broken] et fait tomber le butin.

signal broken(kind: String, pos: Vector3)

const KINDS := {
	"pot": {"models": ["uc012", "uc016", "uc011", "uc013"], "scale": [0.85, 1.1], "hits": 1},
	"crate": {"models": ["uc003", "uc010", "uc005", "uc005_1"], "scale": [0.8, 1.0], "hits": 1},
	"gold": {"models": ["uc033", "uc030"], "scale": [0.9, 1.2], "hits": 0},  # ramassé en passant
	"gem": {"models": ["ud038", "ud038_1", "ud114", "ud115"], "scale": [0.45, 0.6], "hits": 3},
}
const TOUCH := 1.4  # rayon où le héros casse (ou ramasse) ce qu'il touche
const CELL := 16.0  # grille de recherche (m)
const REGIONS := 4

var map_size := 512.0
var _items: Array = []  # {kind, pos, key, idx, hits, alive}
var _grid := {}  # Vector2i -> [indice]
var _pending := {}  # "modèle|région" -> [Transform3D]
var _mms := {}  # "modèle|région" -> [MultiMesh]


func _ready() -> void:
	add_to_group("breakables")


## Ajoute un objet de type [param kind] en [param pos] (avant [method build]).
func add(kind: String, pos: Vector3, rng: RandomNumberGenerator, model := "") -> void:
	var def: Dictionary = KINDS[kind]
	var m := model if model != "" else String((def.models as Array)[rng.randi() % def.models.size()])
	var s := rng.randf_range(def.scale[0], def.scale[1])
	var xf := Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * s), pos)
	var rs := map_size / REGIONS
	var key := "%s|%d" % [m, clampi(int(pos.z / rs), 0, REGIONS - 1) * REGIONS + clampi(int(pos.x / rs), 0, REGIONS - 1)]
	if not _pending.has(key):
		_pending[key] = []
	_items.append({"kind": kind, "pos": pos, "key": key, "idx": _pending[key].size(), "hits": int(def.hits), "alive": true})
	_pending[key].append(xf)
	var c := _cell(pos)
	if not _grid.has(c):
		_grid[c] = []
	_grid[c].append(_items.size() - 1)


## Crée les MultiMesh (une fois tout ajouté).
func build() -> void:
	for key in _pending:
		var model := String(key).get_slice("|", 0)
		var xfs: Array = _pending[key]
		var list: Array = []
		for entry in ProcMap.model_meshes(model):
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.mesh = entry[0]
			mm.instance_count = xfs.size()
			for k in xfs.size():
				mm.set_instance_transform(k, xfs[k] * entry[1])
			var mmi := MultiMeshInstance3D.new()
			mmi.multimesh = mm
			mmi.visibility_range_end = 110.0
			add_child(mmi)
			list.append(mm)
		_mms[key] = list
	_pending.clear()


func count(kind := "") -> int:
	var n := 0
	for it in _items:
		if it.alive and (kind == "" or it.kind == kind):
			n += 1
	return n


## Objets vivants : [[position, type]] (mini-carte, tests).
func alive_list() -> Array:
	var out: Array = []
	for it in _items:
		if it.alive:
			out.append([it.pos, it.kind])
	return out


func _cell(p: Vector3) -> Vector2i:
	return Vector2i(int(floor(p.x / CELL)), int(floor(p.z / CELL)))


func _near(p: Vector3, r: float) -> Array:
	var out: Array = []
	var c0 := _cell(p - Vector3(r, 0, r))
	var c1 := _cell(p + Vector3(r, 0, r))
	for cx in range(c0.x, c1.x + 1):
		for cz in range(c0.y, c1.y + 1):
			for i in _grid.get(Vector2i(cx, cz), []):
				if _items[i].alive:
					out.append(i)
	return out


## Le héros passe en [param pos] : il ramasse l'or et casse jarres et caisses qu'il touche.
func touch(pos: Vector3) -> void:
	for i in _near(pos, TOUCH + 1.0):
		var it: Dictionary = _items[i]
		if it.kind == "gem":
			continue
		var d := Vector2(it.pos.x - pos.x, it.pos.z - pos.z).length()
		if d <= TOUCH:
			_break(i)


## Coup du héros (zone d'attaque ou de sort) : casse ce qui est dans l'arc.
func hit_area(origin: Vector3, fwd: Vector3, radius: float, arc: float) -> void:
	for i in _near(origin, radius + 1.0):
		var it: Dictionary = _items[i]
		if it.kind == "gold":
			continue
		var to: Vector3 = it.pos - origin
		to.y = 0.0
		var dist := to.length() - 0.5
		if dist > radius:
			continue
		if arc < 360.0 and dist > 0.6 and rad_to_deg(fwd.angle_to(to.normalized())) > arc * 0.5:
			continue
		it.hits = int(it.hits) - 1
		if it.hits <= 0:
			_break(i)
		else:
			Vfx.spark(self, it.pos + Vector3.UP * 0.8, Color(0.75, 0.6, 1.0))


func _break(i: int) -> void:
	var it: Dictionary = _items[i]
	if not it.alive:
		return
	it.alive = false
	for mm: MultiMesh in _mms.get(it.key, []):
		var xf := mm.get_instance_transform(it.idx)
		mm.set_instance_transform(it.idx, Transform3D(Basis().scaled(Vector3.ONE * 0.0001), xf.origin))
	var col := Color(1.0, 0.85, 0.35) if it.kind == "gold" else (Color(0.75, 0.6, 1.0) if it.kind == "gem" else Color(0.9, 0.75, 0.5))
	Vfx.ring(self, it.pos + Vector3.UP * 0.1, 1.2, Color(col, 0.8))
	Vfx.spark(self, it.pos + Vector3.UP * 0.6, col)
	broken.emit(String(it.kind), it.pos)
