class_name AutochessBench
extends Node3D
## L'Échiquier (lot AC-F) : banc de 9 cases devant le plateau et banc de 10 objets à sa gauche. Données seulement
## (unités et objets) et leurs cases ; les figurines des unités sont posées par AutochessBoard (même code que le plateau).
## Repère : celui du plateau (AutochessBoard). Voir conception/autochess/R_AC_F.md.

const SLOT_STEP := 1.72  # m entre deux cases du banc
const BENCH_Z := 8.45
const SLOT_R := 0.86
const ITEM_X := [-10.15, -8.95]  # deux colonnes de 5 objets
const ITEM_Z0 := 1.0
const ITEM_STEP := 1.42
const ITEM_R := 0.6

var units: Array = []  # 9 × unité ou {}
var items: Array = []  # 10 × id d'objet ou ""
var _pads: Array = []  # [dessus, bord] par case du banc
var _item_pads: Array = []
var _item_gems: Array = []  # icône flottante de chaque objet


func _init() -> void:
	name = "AutochessBench"
	units.resize(AutochessData.BENCH_SIZE)
	for i in units.size():
		units[i] = {}
	items.resize(AutochessData.ITEM_BENCH_SIZE)
	items.fill("")


func _ready() -> void:
	for i in AutochessData.BENCH_SIZE:
		var p := slot_position(i)
		var rim := AutochessBoard.hex_node(SLOT_R, AutochessBoard.TILE_H, AutochessBoard.RIM)
		rim.position = Vector3(p.x, AutochessBoard.TILE_H * 0.5 - 0.02, p.z)
		add_child(rim)
		var top := AutochessBoard.hex_node(SLOT_R * 0.86, AutochessBoard.TILE_H, AutochessBoard.TILE_BENCH)
		top.position = Vector3(p.x, AutochessBoard.TILE_H * 0.5 + 0.015, p.z)
		add_child(top)
		_pads.append([top, rim])
	for i in AutochessData.ITEM_BENCH_SIZE:
		var p := item_position(i)
		var rim := AutochessBoard.hex_node(ITEM_R, AutochessBoard.TILE_H, AutochessBoard.RIM)
		rim.position = Vector3(p.x, AutochessBoard.TILE_H * 0.5 - 0.02, p.z)
		add_child(rim)
		var top := AutochessBoard.hex_node(ITEM_R * 0.84, AutochessBoard.TILE_H, AutochessBoard.TILE_BENCH)
		top.position = Vector3(p.x, AutochessBoard.TILE_H * 0.5 + 0.015, p.z)
		add_child(top)
		_item_pads.append([top, rim])
		_item_gems.append(null)


## Centre d'une case du banc (repère du plateau).
static func slot_position(i: int) -> Vector3:
	return Vector3((float(i) - float(AutochessData.BENCH_SIZE - 1) * 0.5) * SLOT_STEP, AutochessBoard.TOP, BENCH_Z)


## Centre d'une case du banc d'objets (deux colonnes de 5, de l'avant vers le fond du plateau).
static func item_position(i: int) -> Vector3:
	return Vector3(ITEM_X[i / 5], AutochessBoard.TOP, ITEM_Z0 + float(i % 5) * ITEM_STEP)


func first_free() -> int:
	for i in units.size():
		if (units[i] as Dictionary).is_empty():
			return i
	return -1


func is_full() -> bool:
	return first_free() < 0


## Case du banc (ou du banc d'objets) sous un point du repère du plateau ; {} si aucune.
func pick(p: Vector3) -> Dictionary:
	var flat := Vector2(p.x, p.z)
	for i in AutochessData.BENCH_SIZE:
		var c := slot_position(i)
		if flat.distance_to(Vector2(c.x, c.z)) <= SLOT_STEP * 0.5:
			return AutochessBoard.bench_slot(i)
	for i in AutochessData.ITEM_BENCH_SIZE:
		var c := item_position(i)
		if flat.distance_to(Vector2(c.x, c.z)) <= ITEM_R:
			return AutochessBoard.items_slot(i)
	return {}


## Couleurs des cases selon le curseur et ce qui est tenu.
func paint(hover: Dictionary, held: Dictionary, board: AutochessBoard) -> void:
	var holding := not held.is_empty()
	for i in _pads.size():
		var s := AutochessBoard.bench_slot(i)
		var col := AutochessBoard.TILE_BENCH
		var rim := AutochessBoard.RIM
		var glow := 0.0
		if holding and String(held.zone) != "items":
			col = AutochessBoard.TILE_TARGET
		if AutochessBoard.same_slot(s, held):
			col = AutochessBoard.TILE_BENCH.darkened(0.35)
			rim = UiTheme.GOLD
		if AutochessBoard.same_slot(s, hover):
			col = AutochessBoard.TILE_HOVER
			rim = UiTheme.GOLD
			glow = 1.0
		AutochessBoard._tint(_pads[i][0], col, 0.0)
		AutochessBoard._tint(_pads[i][1], rim, glow)
	for i in _item_pads.size():
		var s := AutochessBoard.items_slot(i)
		var col := AutochessBoard.TILE_BENCH
		var rim := AutochessBoard.RIM
		var glow := 0.0
		if AutochessBoard.same_slot(s, held):
			rim = UiTheme.GOLD
		if AutochessBoard.same_slot(s, hover):
			col = AutochessBoard.TILE_HOVER
			rim = UiTheme.GOLD
			glow = 1.0
		AutochessBoard._tint(_item_pads[i][0], col, 0.0)
		AutochessBoard._tint(_item_pads[i][1], rim, glow)
	_sync_items(held)


## Icônes des objets posés sur le banc d'objets (l'objet tenu flotte plus haut).
func _sync_items(held: Dictionary) -> void:
	for i in items.size():
		var id := String(items[i])
		var gem: Node3D = _item_gems[i]
		if gem != null and String(gem.get_meta("id", "")) != id:
			gem.queue_free()
			gem = null
		if gem == null and id != "":
			gem = _make_gem(id)
			add_child(gem)
		_item_gems[i] = gem
		if gem:
			var lift := 0.55 if AutochessBoard.same_slot(AutochessBoard.items_slot(i), held) else 0.0
			gem.position = item_position(i) + Vector3(0.0, 0.45 + lift, 0.0)


static func _make_gem(id: String) -> Node3D:
	var it := AutochessData.item(id)
	var path := String(Boons.ICONS.get(String(it.get("icon", "")), ""))
	var node: Node3D
	if path != "" and ResourceLoader.exists(path):
		var sp := Sprite3D.new()
		sp.texture = load(path)
		sp.pixel_size = 0.62 / maxf(1.0, float(sp.texture.get_width()))
		sp.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		node = sp
	else:
		# composant : un cristal (sans icône dans les données)
		var mi := MeshInstance3D.new()
		var pm := PrismMesh.new()
		pm.size = Vector3(0.36, 0.5, 0.36)
		mi.mesh = pm
		var m := AutochessBoard._mat(UiTheme.GOLD, false)
		m.emission_enabled = true
		m.emission = UiTheme.GOLD
		m.emission_energy_multiplier = 0.5
		mi.material_override = m
		node = mi
	node.set_meta("id", id)
	return node
