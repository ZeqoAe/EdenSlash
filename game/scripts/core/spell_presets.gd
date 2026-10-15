class_name SpellPresets
extends RefCounted
## Presets de sorts (Grimoire) : pour une classe, l'ordre voulu des 4 cases et de leurs
## enchaînements (tableau 4 × 3 : sort principal de la case, puis ses 2 sorts enchaînés).
## Le preset actif range les sorts de la run (Run.arrange) : chaque sort obtenu va à sa place,
## les autres suivent l'ordre d'obtention ; en entraînement, charger un preset pose tous ses sorts.
## Fichier à part (user://spell_presets.json) : gardé même s'il est créé pendant l'entraînement
## ou la Tour (la sauvegarde du profil n'y est pas écrite).
## Format : {classe: {"active": indice ou -1, "list": [{name, cols: [[id, id, id] × 4]}]}}
## (0 : case vide).

const PATH := "user://spell_presets.json"
const TEST_PATH := "user://spell_presets_test.json"
const COLS := 4
const ROWS := 3  # sort principal + 2 enchaînements (Run.MAX_CHAIN)

static var _data := {}
static var _loaded := false


static func _path() -> String:
	return TEST_PATH if DevEdits.is_test() else PATH


static func _load() -> void:
	if _loaded:
		return
	_loaded = true
	var txt := SafeFile.read(_path())
	if txt != "":
		var d = JSON.parse_string(txt)
		if typeof(d) == TYPE_DICTIONARY:
			_data = d


static func save() -> void:
	SafeFile.write(_path(), JSON.stringify(_data, "\t"))


static func _cls(cid: String) -> Dictionary:
	_load()
	if not _data.has(cid):
		_data[cid] = {"active": -1, "list": []}
	return _data[cid]


static func list(cid: String) -> Array:
	return _cls(cid).list


static func active_index(cid: String) -> int:
	var c := _cls(cid)
	return int(c.active) if int(c.active) < (c.list as Array).size() else -1


## Preset actif de la classe ({} : aucun, ordre d'obtention).
static func active(cid: String) -> Dictionary:
	var i := active_index(cid)
	return list(cid)[i] if i >= 0 else {}


static func set_active(cid: String, i: int) -> void:
	_cls(cid).active = i
	save()


## Enregistre le preset [param cols] sous [param name] (remplace celui du même nom) et
## l'active. Renvoie son indice.
static func store(cid: String, name: String, cols: Array) -> int:
	var l := list(cid)
	var p := {"name": name, "cols": cols}
	for i in l.size():
		if String(l[i].name) == name:
			l[i] = p
			set_active(cid, i)
			return i
	l.append(p)
	set_active(cid, l.size() - 1)
	return l.size() - 1


static func remove(cid: String, i: int) -> void:
	var l := list(cid)
	if i < 0 or i >= l.size():
		return
	l.remove_at(i)
	var c := _cls(cid)
	if int(c.active) == i:
		c.active = -1
	elif int(c.active) > i:
		c.active = int(c.active) - 1
	save()


## Tableau vide 4 × 3.
static func empty_cols() -> Array:
	var out: Array = []
	for c in COLS:
		var col: Array = []
		col.resize(ROWS)
		col.fill(0)
		out.append(col)
	return out


## Case et rang du sort [param id] dans le preset [param p] : Vector2i(case, rang) ou (-1, -1).
static func place_of(p: Dictionary, id: int) -> Vector2i:
	var cols: Array = p.get("cols", [])
	for c in cols.size():
		for r in (cols[c] as Array).size():
			if int(cols[c][r]) == id:
				return Vector2i(c, r)
	return Vector2i(-1, -1)
