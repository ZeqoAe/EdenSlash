class_name RivalBuilds
extends RefCounted
## Adversaires du duel créés dans l'éditeur (RivalEditor) : classe, équipement tiré du
## catalogue d'Eden (rareté, amélioration), apparence (tenue, tête, dos), certificats, sorts,
## multiplicateurs de PV et de dégâts. Fichier à part : user://rival_builds.json (gardé même
## pendant l'entraînement ou la Tour).
## Un adversaire : {name, class, gear: {emplacement: {id (Eden), rarity, upgrade}},
##   look: {body, head, back : chemins .glb}, certs: [clé « classe/passif »], spells: [4 ids, 0 :
##   choix de l'IA], hp_mult, atk_mult}

const PATH := "user://rival_builds.json"
const TEST_PATH := "user://rival_builds_test.json"
const MAX_CERTS := 7

static var _list: Array = []
static var _loaded := false


static func _path() -> String:
	return TEST_PATH if DevEdits.is_test() else PATH


static func list() -> Array:
	if not _loaded:
		_loaded = true
		if FileAccess.file_exists(_path()):
			var d = JSON.parse_string(FileAccess.get_file_as_string(_path()))
			if d is Array:
				_list = d
	return _list


static func save() -> void:
	var f := FileAccess.open(_path(), FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(_list, "\t"))


static func find(name: String) -> int:
	var l := list()
	for i in l.size():
		if String(l[i].get("name", "")) == name:
			return i
	return -1


## Enregistre [param b] (remplace celui du même nom).
static func store(b: Dictionary) -> void:
	var i := find(String(b.name))
	if i >= 0:
		list()[i] = b.duplicate(true)
	else:
		list().append(b.duplicate(true))
	save()


static func remove(name: String) -> void:
	var i := find(name)
	if i >= 0:
		list().remove_at(i)
		save()


static func blank(cid: String) -> Dictionary:
	return {"name": "Adversaire %d" % (list().size() + 1), "class": cid, "gear": {}, "look": {}, "certs": [],
		"spells": [0, 0, 0, 0], "hp_mult": 1.0, "atk_mult": 1.0}


## Objets de l'adversaire au niveau [param level] : emplacement -> objet (comme ceux d'un héros).
static func items(b: Dictionary, level: int) -> Dictionary:
	var out := {}
	var g: Dictionary = b.get("gear", {})
	for slot in g:
		var e: Dictionary = GameData.eden_by_id.get(int(g[slot].get("id", 0)), {})
		if e.is_empty():
			continue
		seed(hash([slot, int(g[slot].id), level]))  # qualité toujours la même pour cet objet
		var it := Items.from_template(e, level, clampi(int(g[slot].get("rarity", e.rarity)), 0, Items.RARITIES.size() - 1))
		randomize()
		it["upgrade"] = clampi(int(g[slot].get("upgrade", 0)), 0, Items.MAX_UPGRADE)
		out[slot] = it
	return out


## Tous les certificats qui existent : [{key, name, cls}].
static func all_certificates() -> Array:
	var out: Array = []
	for cls in GameData.talents:
		for pid in GameData.talents[cls].get("certificates", []):
			var key := "%s/%s" % [cls, pid]
			var card := Run.certificate_card(key)
			if not card.is_empty():
				out.append({"key": key, "name": String(card.get("name", pid)), "cls": String(GameData.class_data(cls).get("name_fr", cls))})
	return out


## Plateau des certificats (positions comme celles du héros) pour les bonus de placement.
static func cert_board(b: Dictionary) -> Array:
	var board := ["", "", "", "", "", "", ""]
	var certs: Array = b.get("certs", [])
	for i in mini(certs.size(), CertBoard.OPEN_ORDER.size()):
		board[CertBoard.OPEN_ORDER[i]] = String(certs[i])
	return board


## Stats ajoutées par l'équipement, ses sets et les certificats (sommes, % compris).
static func stats(b: Dictionary, level: int) -> Dictionary:
	var gear := items(b, level)
	var total := {}
	var was_active := Run.active
	var was_level := Run.hero_level
	Run.active = true
	Run.hero_level = level  # puissance des objets au niveau du duel, comme pour un héros
	for slot in gear:
		var st := Items.stats(gear[slot])
		for k in st:
			total[k] = float(total.get(k, 0.0)) + float(st[k])
	Run.active = was_active
	Run.hero_level = was_level
	for sb in Items.active_set_bonuses(gear):
		for k in sb.stat:
			total[k] = float(total.get(k, 0.0)) + float(sb.stat[k])
	var cb := CertBoard.stats(cert_board(b))
	for k in cb:
		total[k] = float(total.get(k, 0.0)) + float(cb[k])
	for key in b.get("certs", []):
		var st: Dictionary = Run.certificate_card(String(key)).get("stat", {})
		for k in st:
			if typeof(st[k]) in [TYPE_FLOAT, TYPE_INT]:
				total[k] = float(total.get(k, 0.0)) + float(st[k])
	return total
