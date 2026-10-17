class_name AutochessBoard
extends Node3D
## L'Échiquier (lot AC-F) : le plateau 3D d'un stratège. Grille hexagonale 7 × 8 (pointe en haut, case de 2 m),
## 4 rangées à soi (rangée 0 = ligne de front, 3 = fond) et 4 rangées adverses montrées en miroir (rotation d'un demi-tour,
## comme le plateau de l'adversaire vu de son côté), banc de 9 cases et banc de 10 objets (AutochessBench), stratège qui
## marche (le héros du joueur, son nom au-dessus), figurines des unités (modèle de la classe, taille selon les étoiles,
## anneau de la couleur du coût, étoiles ★1-3 au-dessus). Spécification : conception/autochess/SPEC.md §3.1, §7.1, §8.
## Rapport et interface pour les lots B (partie), E (combat) et G (interface) : conception/autochess/R_AC_F.md.
##
## Données (dictionnaires simples, sauvegardables en JSON) :
##   unité  = {"id": "warrior", "stars": 1, "items": ["lame"], "uid": 12}  (« uid » : entier unique et stable, sinon le
##            plateau en donne un ; une unité qui garde son uid garde sa figurine d'un set_state à l'autre)
##   case   = {"zone": "board", "col": c, "row": r} | {"zone": "bench", "index": i} | {"zone": "items", "index": i}
##   état   = {"level": 3, "crowns": 0, "board": {"c,r": unité}, "bench": [9 × unité ou {}], "items": [10 × id ou ""]}
## Le plateau applique lui-même les déplacements (placement libre, borné au niveau + Couronnes) et prévient par signal ;
## la partie (AC-B) reste maîtresse de l'économie : elle écoute unit_sold (or, réserve) et remet l'état par set_state.

signal unit_placed(unit: Dictionary, from: Dictionary, to: Dictionary)  ## une unité a changé de case (deux signaux pour un échange)
signal unit_sold(unit: Dictionary, from: Dictionary)  ## une unité a été vendue (ses objets sont revenus au banc d'objets)
signal item_given(item: String, unit: Dictionary, from: Dictionary)  ## un objet du banc a été donné à une unité
signal placement_refused(reason: String)  ## texte court pour le joueur (« Plateau plein »…)
signal state_changed  ## après tout changement (déplacement, vente, objet, set_state)

const COLS := AutochessData.COLS  # 7
const ROWS := AutochessData.ROWS  # 4 par camp
const HEX_W := AutochessData.CELL  # 2 m d'un bord plat à l'autre
const HEX_R := 1.1547005  # rayon (pointe) = HEX_W / √3
const ROW_STEP := 1.7320508  # écart entre deux rangées = 1,5 × HEX_R
const TILE_H := 0.14
const TOP := 0.16  # hauteur du dessus d'une case (pieds des figurines)
const PLINTH_R := 13.2
const FIGURE_SCALE := 0.88  # figurine = héros × HERO_SCALE × FIGURE_SCALE × taille des étoiles
const STAR_SIZE := [1.0, 1.14, 1.3]
const STRATEGIST_SCALE := 0.72
const WALK_SPEED := 6.0
const STRATEGIST_HOME := Vector3(9.6, 0.0, 6.4)
## Allée du stratège, à droite du plateau (il ne cache jamais une unité) : x fixe, z borné au socle.
const LANE_X := 9.6
const LANE_Z := Vector2(0.7, 8.6)

## Couleurs : bleu nuit et or (UiTheme), camp adverse plus sombre et pourpre.
const TILE_MINE := Color(0.12, 0.14, 0.31)
const TILE_FOE := Color(0.19, 0.09, 0.17)
const TILE_BENCH := Color(0.10, 0.12, 0.26)
const TILE_TARGET := Color(0.20, 0.25, 0.50)
const TILE_FULL := Color(0.27, 0.09, 0.14)
const TILE_HOVER := Color(0.27, 0.31, 0.62)
const RIM := Color(0.56, 0.42, 0.20)
const RIM_FOE := Color(0.38, 0.20, 0.26)
const PLINTH := Color(0.06, 0.06, 0.14)
## Étoiles : bronze, argent, or.
const STAR_COLORS := [Color(0.88, 0.62, 0.38), Color(0.86, 0.91, 1.0), Color(0.98, 0.80, 0.30)]
## Lot AC-V : plateau tracé sur le sol d'une arène (AutochessArena) : cases plates en filigrane (fond bleu nuit
## translucide, bord doré lumineux), sans socle ; elles s'allument en préparation et s'estompent au combat (light_up).
const ARENA_FILL_A := 0.62  # opacité du fond des cases, allumées
const ARENA_RIM_A := 0.95  # opacité du bord doré
const ARENA_RIM_GLOW := 0.45  # lueur du bord, allumé
const ARENA_DIM := 0.22  # éclat des cases pendant le combat
const ARENA_FADE := 0.6  # s
const ARENA_RIM_W := 0.13  # m : largeur du filet doré

## Style « arène » (à poser avant l'entrée dans l'arbre).
var arena_style := false
## Éclat des cases (1 : préparation, ARENA_DIM : combat) : opacité du fond et du filet, lueur.
var glow_level := 1.0:
	set(v):
		glow_level = clampf(v, 0.0, 1.0)
		if arena_style and is_inside_tree():
			_paint()
var _glow_tween: Tween

var level := 1:
	set(v):
		level = clampi(v, 1, AutochessData.MAX_LEVEL_BONUS)
		_refresh_count()
var crowns := 0:
	set(v):
		crowns = maxi(v, 0)
		_refresh_count()

var cells := {}  # "c,r" -> unité (sa moitié, coordonnées du joueur)
var enemy := {}  # "c,r" -> unité (moitié adverse, coordonnées de l'adversaire : montrée en miroir)
var bench: AutochessBench
var strategist: Node3D
var foe_strategist: Node3D

var _tiles := {}  # "c,r" -> [dessus, bord] (MeshInstance3D) ; « e:c,r » pour la moitié adverse
var _figures := {}  # uid -> Node3D
var _next_uid := 1
var _count_label: Label3D
var _count_cap: Label3D
var _hover: Dictionary = {}
var _held: Dictionary = {}
var _held_at := Vector3.ZERO
var _walk_target := STRATEGIST_HOME
var _flash := 0.0
var _marked := {}  # uid -> true : unités mises en avant (lot ACX-1, mark_units)
var _mark_mesh: Mesh
var _mark_mat: Material


func _init() -> void:
	name = "AutochessBoard"


func _ready() -> void:
	if arena_style:
		_build_arena_marks()
	else:
		_build_plinth()
	for r in ROWS * 2:
		for c in COLS:
			_build_tile(c, r)
	bench = AutochessBench.new()
	add_child(bench)
	if arena_style:
		_flatten_bench()
	_count_label = _label("", 64, UiTheme.GOLD)
	_count_label.position = Vector3(LANE_X, 1.25, -1.2)
	add_child(_count_label)
	var cap := _label("Héros placés", 36, UiTheme.MUTED)
	cap.position = Vector3(LANE_X, 0.6, -1.2)
	add_child(cap)
	_count_cap = cap
	_refresh_count()
	set_strategist(Profile.selected_class, Profile.hero_name)
	_paint()


# --- géométrie --------------------------------------------------------------------------------------------------
static func key(c: int, r: int) -> String:
	return "%d,%d" % [c, r]


static func key_cell(k: String) -> Vector2i:
	var p := k.split(",")
	return Vector2i(int(p[0]), int(p[1])) if p.size() == 2 else Vector2i(-1, -1)


static func board_slot(c: int, r: int) -> Dictionary:
	return {"zone": "board", "col": c, "row": r}


static func bench_slot(i: int) -> Dictionary:
	return {"zone": "bench", "index": i}


static func items_slot(i: int) -> Dictionary:
	return {"zone": "items", "index": i}


static func slot_id(s: Dictionary) -> String:
	match String(s.get("zone", "")):
		"board":
			return "b:" + key(int(s.col), int(s.row))
		"bench":
			return "n:%d" % int(s.index)
		"items":
			return "i:%d" % int(s.index)
	return ""


static func same_slot(a: Dictionary, b: Dictionary) -> bool:
	return slot_id(a) != "" and slot_id(a) == slot_id(b)


## Case valide de sa moitié (0 ≤ c < 7, 0 ≤ r < 4) ?
static func valid_cell(c: int, r: int) -> bool:
	return c >= 0 and c < COLS and r >= 0 and r < ROWS


## Rangée du monde (0 = fond du joueur, 7 = fond adverse) et colonne du monde d'une case ; l'adversaire est tourné d'un
## demi-tour (sa colonne c devient 6 - c, sa rangée r devient 4 + r).
static func world_cell(c: int, r: int, foe := false) -> Vector2i:
	return Vector2i(COLS - 1 - c, ROWS + r) if foe else Vector2i(c, ROWS - 1 - r)


## Centre d'une case (repère du plateau) ; [param foe] : case de l'adversaire, en miroir.
static func cell_position(c: int, r: int, foe := false) -> Vector3:
	var w := world_cell(c, r, foe)
	var x := (float(w.x) + 0.5 * float(w.y % 2) - (float(COLS) - 0.5) * 0.5) * HEX_W
	var z := (float(ROWS) - 0.5 - float(w.y)) * ROW_STEP
	return Vector3(x, TOP, z)


## Position (repère du plateau) d'une case quelconque.
func slot_position(s: Dictionary) -> Vector3:
	match String(s.get("zone", "")):
		"board":
			return cell_position(int(s.col), int(s.row))
		"bench":
			return bench.slot_position(int(s.index))
		"items":
			return bench.item_position(int(s.index))
	return Vector3.ZERO


## Centre d'une case dans le monde (apparition des combattants par AC-E : même case, même miroir).
func cell_world_position(c: int, r: int, foe := false) -> Vector3:
	return to_global(cell_position(c, r, foe))


## Case sous un point du repère du plateau (sa moitié, banc, banc d'objets) ; {} si aucune.
func pick(p: Vector3) -> Dictionary:
	var best: Dictionary = {}
	var best_d := INF
	for r in ROWS:
		for c in COLS:
			var d := Vector2(p.x, p.z).distance_to(Vector2(cell_position(c, r).x, cell_position(c, r).z))
			if d < best_d:
				best_d = d
				best = board_slot(c, r)
	if best_d <= HEX_W * 0.5:
		return best
	var bs := bench.pick(p)
	return bs


## Toutes les cases où le curseur peut aller (sa moitié, banc, banc d'objets).
func all_slots() -> Array:
	var out: Array = []
	for r in ROWS:
		for c in COLS:
			out.append(board_slot(c, r))
	for i in AutochessData.BENCH_SIZE:
		out.append(bench_slot(i))
	for i in AutochessData.ITEM_BENCH_SIZE:
		out.append(items_slot(i))
	return out


# --- état ---------------------------------------------------------------------------------------------------------
## Remet tout l'état (après un achat, une fusion, une reprise de partie…). Les cases hors de sa moitié sont écartées :
## leurs unités vont au banc s'il reste de la place (aucune unité hors plateau). Accepte aussi tel quel le dictionnaire
## d'un stratège de la partie (Autochess.players[i] : « board » = liste d'unités avec « cell » [c, r], banc avec null).
func set_state(s: Dictionary) -> void:
	level = int(s.get("level", level))
	crowns = int(s.get("crowns", crowns))
	cells.clear()
	var stray: Array = []
	var src := board_dict(s.get("board", {}))
	for k in src:
		var u: Dictionary = _own(src[k])
		var at := key_cell(String(k))
		if valid_cell(at.x, at.y) and not cells.has(key(at.x, at.y)):
			cells[key(at.x, at.y)] = u
		else:
			stray.append(u)
	var b: Array = s.get("bench", [])
	for i in AutochessData.BENCH_SIZE:
		bench.units[i] = _own(b[i]) if i < b.size() and b[i] is Dictionary and not (b[i] as Dictionary).is_empty() else {}
	for u in stray:
		var i := first_free_bench()
		if i >= 0:
			bench.units[i] = u
	var it: Array = s.get("items", [])
	for i in AutochessData.ITEM_BENCH_SIZE:
		bench.items[i] = String(it[i]) if i < it.size() and it[i] != null else ""
	_changed()


## Plateau en dictionnaire « c,r » -> unité, depuis un dictionnaire (tel quel) ou une liste d'unités portant « cell » [c, r]
## (forme de la partie, AC-B) ; une unité sans case valide garde une clé hors grille (elle ira au banc).
static func board_dict(src: Variant) -> Dictionary:
	if src is Dictionary:
		return src
	var out := {}
	if src is Array:
		for u in src:
			if u is Dictionary and (u as Dictionary).has("cell") and (u.cell is Array) and (u.cell as Array).size() == 2:
				out[key(int(u.cell[0]), int(u.cell[1]))] = u
			elif u is Dictionary:
				out["x%d" % out.size()] = u
	return out


## Copie de l'état, même forme que set_state.
func state() -> Dictionary:
	return {"level": level, "crowns": crowns, "board": cells.duplicate(true), "bench": bench.units.duplicate(true),
		"items": bench.items.duplicate()}


## Plateau de l'adversaire de la manche ({} : moitié vide), dans SES coordonnées (son « board » : dictionnaire « c,r » ou
## liste d'unités avec « cell ») : montré en miroir. [param info] : {"class_id", "name"} de son stratège ({} : aucun).
func set_enemy(board: Variant, info: Dictionary = {}) -> void:
	enemy.clear()
	var src := board_dict(board)
	for k in src:
		var at := key_cell(String(k))
		if valid_cell(at.x, at.y):
			enemy[key(at.x, at.y)] = _own(src[k])
	if info.is_empty():
		if foe_strategist:
			foe_strategist.queue_free()
			foe_strategist = null
	else:
		_set_foe_strategist(String(info.get("class_id", "warrior")), String(info.get("name", "")))
	_changed()


func cap() -> int:
	return mini(level, AutochessData.MAX_LEVEL_BONUS) + crowns


func board_count() -> int:
	return cells.size()


func first_free_bench() -> int:
	return bench.first_free()


## Pose une unité sur la première case libre du banc ; -1 si le banc est plein.
func add_to_bench(u: Dictionary) -> int:
	var i := first_free_bench()
	if i >= 0:
		bench.units[i] = _own(u)
		_changed()
	return i


func unit_at(s: Dictionary) -> Dictionary:
	match String(s.get("zone", "")):
		"board":
			return cells.get(key(int(s.col), int(s.row)), {})
		"bench":
			var i := int(s.index)
			return bench.units[i] if i >= 0 and i < bench.units.size() else {}
	return {}


func item_at(s: Dictionary) -> String:
	var i := int(s.get("index", -1))
	return bench.items[i] if String(s.get("zone", "")) == "items" and i >= 0 and i < bench.items.size() else ""


func _put(s: Dictionary, u: Dictionary) -> void:
	match String(s.zone):
		"board":
			if u.is_empty():
				cells.erase(key(int(s.col), int(s.row)))
			else:
				cells[key(int(s.col), int(s.row))] = u
		"bench":
			bench.units[int(s.index)] = u


func _valid(s: Dictionary) -> bool:
	match String(s.get("zone", "")):
		"board":
			return valid_cell(int(s.get("col", -1)), int(s.get("row", -1)))
		"bench":
			return int(s.get("index", -1)) >= 0 and int(s.index) < AutochessData.BENCH_SIZE
		"items":
			return int(s.get("index", -1)) >= 0 and int(s.index) < AutochessData.ITEM_BENCH_SIZE
	return false


## Raison du refus d'un déplacement ("" : permis).
func refusal(from: Dictionary, to: Dictionary) -> String:
	if not _valid(from) or not _valid(to):
		return "Hors du plateau"
	if String(from.zone) == "items":
		if String(to.zone) == "items":
			return ""
		var u := unit_at(to)
		if u.is_empty():
			return "Pose l'objet sur un héros"
		if (u.get("items", []) as Array).size() >= AutochessData.MAX_ITEMS_PER_UNIT:
			return "Ce héros porte déjà trois objets"
		return ""
	if String(to.zone) == "items":
		return "Hors du plateau"
	if unit_at(from).is_empty():
		return "Case vide"
	# du banc vers une case libre du plateau : une place de plus
	if String(from.zone) == "bench" and String(to.zone) == "board" and unit_at(to).is_empty() and board_count() >= cap():
		return "Plateau plein : %d héros au niveau %d" % [cap(), level]
	return ""


## Déplace (ou échange) une unité ; un objet du banc va à l'unité visée. Renvoie vrai si quelque chose a bougé.
func move(from: Dictionary, to: Dictionary) -> bool:
	if same_slot(from, to):
		return false
	var why := refusal(from, to)
	if why != "":
		placement_refused.emit(why)
		_flash = 0.6
		return false
	if String(from.zone) == "items":
		return _move_item(from, to)
	var a := unit_at(from)
	var b := unit_at(to)
	_put(from, b)
	_put(to, a)
	_changed()
	unit_placed.emit(a, from, to)
	if not b.is_empty():
		unit_placed.emit(b, to, from)
	return true


func _move_item(from: Dictionary, to: Dictionary) -> bool:
	var it := item_at(from)
	if it == "":
		return false
	if String(to.zone) == "items":
		var other := item_at(to)
		bench.items[int(to.index)] = it
		bench.items[int(from.index)] = other
		_changed()
		return true
	var u := unit_at(to)
	(u["items"] as Array).append(it)
	bench.items[int(from.index)] = ""
	_changed()
	item_given.emit(it, u, from)
	return true


## Vend l'unité de [param from] : elle quitte le plateau, ses objets reviennent au banc d'objets (s'il y a de la place).
func sell(from: Dictionary) -> bool:
	var u := unit_at(from)
	if u.is_empty():
		return false
	_put(from, {})
	for it in u.get("items", []):
		var i := bench.items.find("")
		if i >= 0:
			bench.items[i] = String(it)
	_changed()
	unit_sold.emit(u, from)
	return true


## Or rendu par la vente de l'unité de [param from] (0 si vide).
func sell_value(from: Dictionary) -> int:
	var u := unit_at(from)
	if u.is_empty():
		return 0
	return AutochessData.sell_value(int(AutochessData.unit(String(u.id)).get("cost", 1)), int(u.get("stars", 1)))


func _own(u: Variant) -> Dictionary:
	if not u is Dictionary or (u as Dictionary).is_empty():
		return {}
	var d: Dictionary = (u as Dictionary).duplicate(true)
	if not d.has("uid") or int(d.uid) <= 0:
		d["uid"] = _next_uid
		_next_uid += 1
	else:
		_next_uid = maxi(_next_uid, int(d.uid) + 1)
	d["stars"] = clampi(int(d.get("stars", 1)), 1, AutochessData.MAX_STARS)
	if not d.has("items") or not d.items is Array:
		d["items"] = []
	return d


func _changed() -> void:
	_sync_figures()
	_refresh_count()
	_paint()
	state_changed.emit()


# --- surbrillance ---------------------------------------------------------------------------------------------------
## Case sous le curseur ({} : aucune) et case d'origine de ce qui est tenu ({} : rien) ; [param at] : où la figurine tenue
## flotte (repère du plateau).
func set_cursor(hover: Dictionary, held: Dictionary = {}, at := Vector3.INF) -> void:
	var moved := not same_slot(hover, _hover) or not same_slot(held, _held) or hover.is_empty() != _hover.is_empty() \
		or held.is_empty() != _held.is_empty()
	_hover = hover
	_held = held
	_held_at = at if at != Vector3.INF else (slot_position(hover) if not hover.is_empty() else Vector3.INF)
	if moved:
		_paint()
	if not hover.is_empty():
		var p := slot_position(hover)
		# le stratège suit la case visée dans son allée, à droite du plateau
		_walk_target = Vector3(LANE_X, 0.0, clampf(p.z, LANE_Z.x, LANE_Z.y))


func _paint() -> void:
	var holding_unit := not _held.is_empty() and String(_held.zone) != "items"
	var full := holding_unit and String(_held.zone) == "bench" and board_count() >= cap()
	for k in _tiles:
		var parts: Array = _tiles[k]
		var foe := String(k).begins_with("e:")
		var col := TILE_FOE if foe else TILE_MINE
		var rim := RIM_FOE if foe else RIM
		var glow := 0.0
		if not foe:
			var at := key_cell(String(k))
			var here := board_slot(at.x, at.y)
			var empty := not cells.has(String(k))
			if holding_unit:
				col = TILE_FULL if (full and empty) else TILE_TARGET
			if same_slot(here, _held):
				col = TILE_MINE.darkened(0.35)
				rim = UiTheme.GOLD
			if same_slot(here, _hover):
				col = TILE_HOVER
				rim = UiTheme.GOLD
				glow = 1.0
		_tint(parts[0], col, 0.0)
		_tint(parts[1], rim, glow)
	if bench:
		bench.paint(_hover, _held, self)
	if arena_style:
		_arena_fade()


static func _tint(mi: MeshInstance3D, col: Color, glow: float) -> void:
	var m := mi.material_override as StandardMaterial3D
	m.albedo_color = Color(col, m.albedo_color.a)  # l'opacité reste celle du style (cases en filigrane : AC-V)
	m.emission_enabled = glow > 0.0
	m.emission = col
	m.emission_energy_multiplier = glow * 0.9


# --- style « arène » (lot AC-V) --------------------------------------------------------------------------------------
## Allume (préparation) ou estompe (combat) les cases tracées au sol ; [param instant] : sans transition.
func light_up(on: bool, instant := false) -> void:
	if _glow_tween != null and _glow_tween.is_valid():
		_glow_tween.kill()
	var goal := 1.0 if on else ARENA_DIM
	for l in [_count_label, _count_cap]:
		if l != null:
			l.visible = on  # « Héros placés » : en préparation seulement
	if instant or not is_inside_tree():
		glow_level = goal
		return
	_glow_tween = create_tween()
	_glow_tween.tween_property(self, "glow_level", goal, ARENA_FADE)


## Opacité et lueur des cases selon glow_level (après _tint, qui garde l'opacité) ; case visée : pleine lumière.
func _arena_fade() -> void:
	var pads: Array = _tiles.values()
	if bench:
		pads += bench._pads + bench._item_pads
	for parts in pads:
		var fill := (parts[0] as MeshInstance3D).material_override as StandardMaterial3D
		var rim := (parts[1] as MeshInstance3D).material_override as StandardMaterial3D
		fill.albedo_color.a = ARENA_FILL_A * glow_level
		rim.albedo_color.a = ARENA_RIM_A * maxf(glow_level, 0.35)
		if not rim.emission_enabled:  # visée ou tenue : _tint l'a déjà fait briller
			rim.emission_enabled = true
			rim.emission = Color(rim.albedo_color, 1.0)
			rim.emission_energy_multiplier = ARENA_RIM_GLOW * glow_level


## Matériau translucide d'une case tracée au sol.
static func _arena_mat(col: Color, alpha: float) -> StandardMaterial3D:
	var m := _mat(Color(col, alpha))
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.roughness = 1.0
	m.metallic_specular = 0.0
	m.cull_mode = BaseMaterial3D.CULL_DISABLED  # faces plates : visibles quel que soit le sens des triangles
	return m


## Hexagone plat (pointe vers ±Z), face vers le haut ; [param inner] > 0 : seulement le filet entre inner et [param r].
static func flat_hex_mesh(r: float, inner := 0.0) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_normal(Vector3.UP)
	for k in 6:
		var a0 := TAU * float(k) / 6.0
		var a1 := TAU * float(k + 1) / 6.0
		var o0 := Vector3(sin(a0), 0.0, cos(a0)) * r
		var o1 := Vector3(sin(a1), 0.0, cos(a1)) * r
		if inner <= 0.0:
			for v in [Vector3.ZERO, o0, o1]:
				st.add_vertex(v)
		else:
			var i0 := Vector3(sin(a0), 0.0, cos(a0)) * inner
			var i1 := Vector3(sin(a1), 0.0, cos(a1)) * inner
			for v in [i0, o0, o1, i0, o1, i1]:
				st.add_vertex(v)
	return st.commit()


## Case plate : [fond, filet] juste au niveau TOP (rayon [param r]) ; mêmes rôles que les prismes du socle.
func _flat_pad(p: Vector3, r: float, fill: Color, rim_col: Color) -> Array:
	var rim := MeshInstance3D.new()
	rim.mesh = flat_hex_mesh(r, r - ARENA_RIM_W)
	rim.material_override = _arena_mat(rim_col, ARENA_RIM_A)
	rim.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	rim.position = Vector3(p.x, TOP - 0.004, p.z)
	var top := MeshInstance3D.new()
	top.mesh = flat_hex_mesh(r - ARENA_RIM_W - 0.02)
	top.material_override = _arena_mat(fill, ARENA_FILL_A)
	top.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	top.position = Vector3(p.x, TOP - 0.006, p.z)
	return [top, rim]


## Cercle doré et ligne de partage tracés au sol (le socle n'existe pas dans l'arène).
func _build_arena_marks() -> void:
	var ring := MeshInstance3D.new()
	ring.mesh = flat_ring_mesh(PLINTH_R + 0.05, PLINTH_R - 0.07)
	ring.material_override = _arena_mat(UiTheme.GOLD_DIM, 0.8)
	ring.position.y = TOP - 0.008
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ring)
	var line := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(float(COLS) * HEX_W + 1.6, 0.01, 0.07)
	line.mesh = bm
	line.position = Vector3(0.0, TOP - 0.008, 0.0)
	line.material_override = _arena_mat(UiTheme.GOLD_DIM, 0.85)
	line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(line)


## Anneau plat (face vers le haut) entre [param inner] et [param r].
static func flat_ring_mesh(r: float, inner: float, seg := 96) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_normal(Vector3.UP)
	for k in seg:
		var a0 := TAU * float(k) / float(seg)
		var a1 := TAU * float(k + 1) / float(seg)
		var d0 := Vector3(sin(a0), 0.0, cos(a0))
		var d1 := Vector3(sin(a1), 0.0, cos(a1))
		for v in [d0 * inner, d0 * r, d1 * r, d0 * inner, d1 * r, d1 * inner]:
			st.add_vertex(v)
	return st.commit()


## Bancs : les prismes d'AutochessBench remplacés par des cases plates (mêmes rôles : [fond, filet]).
func _flatten_bench() -> void:
	for item in [false, true]:
		var list: Array = bench._item_pads if item else bench._pads
		for i in list.size():
			var old: Array = list[i]
			var p := (old[0] as Node3D).position
			for n in old:
				(n as Node).queue_free()
			var pad := _flat_pad(p, AutochessBench.ITEM_R if item else AutochessBench.SLOT_R, TILE_BENCH, RIM)
			bench.add_child(pad[1])
			bench.add_child(pad[0])
			list[i] = pad


func _refresh_count() -> void:
	if _count_label == null:
		return
	_count_label.text = "%d / %d" % [board_count(), cap()]
	_count_label.modulate = UiTheme.GOLD if board_count() < cap() else UiTheme.TEXT


# --- construction -------------------------------------------------------------------------------------------------
static func _mat(col: Color, unshaded := false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = 0.85
	m.metallic_specular = 0.2
	if unshaded:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return m


## Prisme hexagonal (pointe vers ±Z) de rayon [param r].
static func hex_mesh(r: float, h: float) -> CylinderMesh:
	var cm := CylinderMesh.new()
	cm.top_radius = r
	cm.bottom_radius = r
	cm.height = h
	cm.radial_segments = 6
	cm.rings = 1
	return cm


static func hex_node(r: float, h: float, col: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = hex_mesh(r, h)
	# CylinderMesh à 6 côtés : un sommet vers +Z, donc pointe en haut sans rotation
	mi.material_override = _mat(col)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


func _build_tile(c: int, wr: int) -> void:
	# (c, wr) : colonne et rangée du monde ; on retrouve la case de son propriétaire
	var foe := wr >= ROWS
	var own := Vector2i(COLS - 1 - c, wr - ROWS) if foe else Vector2i(c, ROWS - 1 - wr)
	var p := cell_position(own.x, own.y, foe)
	if arena_style:
		var pad := _flat_pad(p, HEX_R * 0.97, TILE_FOE if foe else TILE_MINE, RIM_FOE if foe else RIM)
		add_child(pad[1])
		add_child(pad[0])
		_tiles[("e:" if foe else "") + key(own.x, own.y)] = pad
		return
	var rim := hex_node(HEX_R * 0.98, TILE_H, RIM_FOE if foe else RIM)
	rim.position = Vector3(p.x, TILE_H * 0.5 - 0.02, p.z)
	add_child(rim)
	var top := hex_node(HEX_R * 0.86, TILE_H, TILE_FOE if foe else TILE_MINE)
	top.position = Vector3(p.x, TILE_H * 0.5 + 0.015, p.z)
	add_child(top)
	_tiles[("e:" if foe else "") + key(own.x, own.y)] = [top, rim]


func _build_plinth() -> void:
	var base := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = PLINTH_R
	cm.bottom_radius = PLINTH_R + 0.4
	cm.height = 0.5
	cm.radial_segments = 64
	base.mesh = cm
	base.position.y = -0.25
	base.material_override = _mat(PLINTH)
	add_child(base)
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = PLINTH_R - 0.12
	tm.outer_radius = PLINTH_R + 0.05
	tm.rings = 96
	ring.mesh = tm
	ring.material_override = _mat(UiTheme.GOLD_DIM, true)
	add_child(ring)
	# ligne de partage entre les deux moitiés
	var line := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(float(COLS) * HEX_W + 1.6, 0.03, 0.07)
	line.mesh = bm
	line.position = Vector3(0.0, 0.02, 0.0)
	line.material_override = _mat(UiTheme.GOLD_DIM, true)
	add_child(line)


func _label(text: String, size: int, col: Color) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font = UiTheme.bold_font()
	l.font_size = size
	l.pixel_size = 0.01
	l.outline_size = 14
	l.outline_modulate = Color(UiTheme.INK, 0.9)
	l.modulate = col
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.render_priority = 2
	return l


# --- figurines ------------------------------------------------------------------------------------------------------
## Couleur d'un coût (1 à 5) : celles des raretés d'objet (gris, vert, bleu, violet, or), pour la boutique aussi (AC-G).
static func cost_color(cost: int) -> Color:
	return Items.RARITIES[[0, 1, 2, 3, 5][clampi(cost, 1, 5) - 1]].color


## Figurine d'une unité : modèle de sa classe (arme de la classe), anneau du coût, étoiles et objets au-dessus.
## [param foe] : tournée vers le joueur.
static func make_figure(u: Dictionary, foe := false) -> Node3D:
	var root := Node3D.new()
	root.name = "AcUnit"
	var cls := GameData.class_data(String(u.get("id", "")))
	var stars := clampi(int(u.get("stars", 1)), 1, 3)
	var size: float = STAR_SIZE[stars - 1]
	var holder := Node3D.new()
	holder.name = "Body"
	root.add_child(holder)
	if not cls.is_empty():
		var model := EdenModel.instantiate_hero(cls)
		model.scale = Vector3.ONE * GameData.HERO_SCALE * FIGURE_SCALE * size
		model.rotation.y = 0.0 if foe else PI
		holder.add_child(model)
		EdenModel.attach_weapon(model, EdenModel.weapon_entry(cls, ""))
		var ap := EdenModel.find_anim_player(model)
		var wt := GameData.weapon_type(String(cls.get("weapon_type", "")))
		var anim := String(wt.get("battle", cls.get("anims", {}).get("battle", "stand01")))
		if ap and ap.has_animation(anim):
			ap.get_animation(anim).loop_mode = Animation.LOOP_LINEAR
			ap.play(anim)
			ap.seek(randf() * 1.5, true)  # pas toutes au même pas
	var cost := int(AutochessData.unit(String(u.get("id", ""))).get("cost", 1))
	var ring := MeshInstance3D.new()
	ring.name = "CostRing"
	var tm := TorusMesh.new()
	tm.inner_radius = 0.62 * size
	tm.outer_radius = 0.74 * size
	tm.rings = 32
	ring.mesh = tm
	var rm := _mat(cost_color(cost), true)
	ring.material_override = rm
	ring.position.y = 0.03
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(ring)
	var top := 2.05 * size + 0.15
	var st := Label3D.new()
	st.name = "Stars"
	st.text = "★".repeat(stars)
	st.font = UiTheme.bold_font()
	st.font_size = 54 + 8 * (stars - 1)
	st.pixel_size = 0.01
	st.outline_size = 12
	st.outline_modulate = Color(UiTheme.INK, 0.95)
	st.modulate = STAR_COLORS[stars - 1]
	st.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	st.no_depth_test = true
	st.render_priority = 3
	st.position.y = top
	root.add_child(st)
	var items: Array = u.get("items", [])
	for i in items.size():
		var icon := String(AutochessData.item(String(items[i])).get("icon", ""))
		var path := String(Boons.ICONS.get(icon, ""))
		var pip: Node3D
		if path != "" and ResourceLoader.exists(path):
			var sp := Sprite3D.new()
			sp.texture = load(path)
			sp.pixel_size = 0.3 / maxf(1.0, float(sp.texture.get_width()))
			sp.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			sp.no_depth_test = true
			sp.render_priority = 3
			pip = sp
		else:
			var l := Label3D.new()
			l.text = "◆"
			l.font_size = 30
			l.pixel_size = 0.01
			l.outline_size = 8
			l.modulate = UiTheme.GOLD
			l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			l.no_depth_test = true
			pip = l
		pip.position = Vector3((float(i) - float(items.size() - 1) * 0.5) * 0.36, top - 0.42, 0.0)
		root.add_child(pip)
	root.set_meta("look", "%s/%d/%s" % [String(u.get("id", "")), stars, ",".join(items)])
	return root


func _sync_figures() -> void:
	var want := {}  # uid -> [unité, position, adverse]
	for k in cells:
		var at := key_cell(String(k))
		want[int(cells[k].uid)] = [cells[k], cell_position(at.x, at.y), false]
	for i in bench.units.size():
		var u: Dictionary = bench.units[i]
		if not u.is_empty():
			want[int(u.uid)] = [u, bench.slot_position(i), false]
	for k in enemy:
		var at := key_cell(String(k))
		want[-int(enemy[k].uid)] = [enemy[k], cell_position(at.x, at.y, true), true]  # uid négatif : figurines adverses
	for id in _figures.keys():
		if not want.has(id):
			(_figures[id] as Node3D).queue_free()
			_figures.erase(id)
	for id in want:
		var u: Dictionary = want[id][0]
		var stars := clampi(int(u.get("stars", 1)), 1, 3)
		var look := "%s/%d/%s" % [String(u.get("id", "")), stars, ",".join(u.get("items", []))]
		var fig: Node3D = _figures.get(id)
		if fig != null and String(fig.get_meta("look", "")) != look:
			fig.queue_free()
			fig = null
		if fig == null:
			fig = make_figure(u, bool(want[id][2]))
			fig.position = want[id][1]
			add_child(fig)
			_figures[id] = fig
		fig.set_meta("home", want[id][1])
		fig.set_meta("uid", int(u.uid))
	_apply_marks()


## Lot ACX-1 : unités mises en avant (survol d'un trait ou d'une carte de la boutique) : anneau lagon épais et lumineux sous
## leur figurine, au plateau comme au banc. [param uids] : unités du joueur ([] : aucune).
func mark_units(uids: Array) -> void:
	var want := {}
	for u in uids:
		want[int(u)] = true
	if want == _marked:
		return
	_marked = want
	_apply_marks()


## Figurines du joueur actuellement mises en avant (tests).
func marked_count() -> int:
	var n := 0
	for id in _figures:
		var ring: Node3D = (_figures[id] as Node3D).get_node_or_null("AcMark")
		if int(id) > 0 and ring != null and ring.visible:
			n += 1
	return n


func _apply_marks() -> void:
	for id in _figures:
		var fig: Node3D = _figures[id]
		var on := int(id) > 0 and _marked.has(int(id))
		var ring: MeshInstance3D = fig.get_node_or_null("AcMark")
		if on and ring == null:
			ring = MeshInstance3D.new()
			ring.name = "AcMark"
			if _mark_mesh == null:
				var tm := TorusMesh.new()
				tm.inner_radius = 0.98
				tm.outer_radius = 1.18
				tm.rings = 40
				_mark_mesh = tm
				_mark_mat = _mat(Color("22b8f0"), true)
			ring.mesh = _mark_mesh
			ring.material_override = _mark_mat
			ring.position.y = 0.06
			ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			fig.add_child(ring)
		if ring != null:
			ring.visible = on


## Figurine d'une unité (uid), ou null.
func figure(uid: int) -> Node3D:
	return _figures.get(uid)


## Toutes les figurines (combat : AC-E les cache et pose ses combattants aux mêmes cases).
func show_figures(on: bool) -> void:
	for f in _figures.values():
		(f as Node3D).visible = on


func _process(delta: float) -> void:
	var held_uid := int(unit_at(_held).get("uid", 0)) if not _held.is_empty() else 0
	for id in _figures:
		var f: Node3D = _figures[id]
		var home: Vector3 = f.get_meta("home", f.position)
		var goal := home
		if held_uid != 0 and id == held_uid and _held_at != Vector3.INF:
			goal = Vector3(_held_at.x, TOP + 0.7, _held_at.z)  # tenue : soulevée, suit le curseur
		f.position = f.position.lerp(goal, minf(1.0, delta * 14.0))
	if _flash > 0.0:
		_flash -= delta
		_count_label.modulate = UiTheme.DEBUFF if fmod(_flash, 0.2) > 0.1 else UiTheme.TEXT
		if _flash <= 0.0:
			_refresh_count()
	_walk(strategist, _walk_target, delta)


# --- stratèges ------------------------------------------------------------------------------------------------------
## Le stratège du joueur : son héros du hub (tenue, cheveux, teintures, arme) en petit, son nom au-dessus.
func set_strategist(class_id: String, hero_name: String) -> void:
	if strategist:
		strategist.queue_free()
	var mine := class_id == Profile.selected_class
	strategist = _make_strategist(class_id, hero_name, mine)
	strategist.position = STRATEGIST_HOME
	strategist.rotation.y = PI * 1.2
	add_child(strategist)
	_walk_target = STRATEGIST_HOME


func _set_foe_strategist(class_id: String, hero_name: String) -> void:
	if foe_strategist:
		foe_strategist.queue_free()
	foe_strategist = _make_strategist(class_id, hero_name, false)
	foe_strategist.position = Vector3(-STRATEGIST_HOME.x, 0.0, -STRATEGIST_HOME.z)
	foe_strategist.rotation.y = PI * 0.2
	add_child(foe_strategist)


func _make_strategist(class_id: String, hero_name: String, mine: bool) -> Node3D:
	var root := Node3D.new()
	root.name = "Strategist"
	var id := class_id if GameData.classes.has(class_id) else "warrior"
	var cls := GameData.class_data(id)
	var model: Node3D
	if mine:
		model = EdenModel.instantiate_hero(cls, Profile.outfit_of(id), Profile.worn_parts(id), Profile.dye_map(id), HeroLook.current())
	else:
		model = EdenModel.instantiate_hero(cls)
	model.scale = Vector3.ONE * GameData.HERO_SCALE * STRATEGIST_SCALE
	root.add_child(model)
	EdenModel.attach_weapon(model, EdenModel.weapon_entry(cls, Profile.weapon_code() if mine else ""))
	var shown := hero_name.strip_edges()
	if shown == "":
		shown = AutochessData.unit_name(id)
	var tag := _label(shown, 40, UiTheme.GOLD if mine else UiTheme.MUTED)
	tag.position.y = 2.15
	root.add_child(tag)
	root.set_meta("cls", cls)
	_play(root, "idle")
	return root


func _play(who: Node3D, what: String) -> void:
	if who == null or String(who.get_meta("anim", "")) == what:
		return
	who.set_meta("anim", what)
	var cls: Dictionary = who.get_meta("cls", {})
	var ap := EdenModel.find_anim_player(who)
	var anim := String(cls.get("anims", {}).get(what, "stand01"))
	if ap and ap.has_animation(anim):
		ap.get_animation(anim).loop_mode = Animation.LOOP_LINEAR
		ap.play(anim, 0.15)


func _walk(who: Node3D, target: Vector3, delta: float) -> void:
	if who == null:
		return
	var d := target - who.position
	d.y = 0.0
	if d.length() < 0.08:
		_play(who, "idle")
		return
	var step := minf(d.length(), WALK_SPEED * delta)
	who.position += d.normalized() * step
	who.rotation.y = lerp_angle(who.rotation.y, atan2(d.x, d.z), minf(1.0, delta * 12.0))
	_play(who, "run" if d.length() > 0.3 else "idle")


# --- caméra ---------------------------------------------------------------------------------------------------------
## Vue de 3/4 depuis son côté : [param zoom] 0 = tout le plateau et les bancs, 1 = plus près de sa moitié.
func frame_camera(cam: Camera3D, zoom := 0) -> void:
	# cadrage : plateau et bancs entre la frise (haut) et la boutique (bas, ≈ 170 px en 1280 × 720) d'AC-G
	var eye := Vector3(-0.6, 23.0, 20.0) if zoom == 0 else Vector3(-0.6, 16.0, 16.5)
	var at := Vector3(-0.6, 0.0, 3.6) if zoom == 0 else Vector3(-0.6, 0.0, 5.4)
	cam.fov = 42.0
	cam.global_position = to_global(eye)
	cam.look_at(to_global(at), Vector3.UP)
