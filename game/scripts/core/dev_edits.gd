class_name DevEdits
extends RefCounted
## Modifications du mode dev sur le catalogue (data/dev_edits.json), appliquées au chargement
## par-dessus data/eden_catalog.json :
## - "items" : id d'Eden -> champs remplacés (name, rarity, level, r, set, passive, trophy,
##   nopool ; null = champ retiré) ;
## - "sets" : id de set -> définition {name, pieces, bonus} (null = set supprimé). Les sets
##   créés en jeu ont un id « u1 », « u2 »… ; leurs pièces comptent quelle que soit la rareté.
## Le fichier est dans le dossier du jeu : Envoyer.bat l'envoie sur GitHub avec le reste.
## Si le dossier du jeu n'est pas modifiable (jeu exporté), il va dans user://.

const PATH := "res://data/dev_edits.json"
const USER_PATH := "user://dev_edits.json"
const TEST_PATH := "user://dev_edits_test.json"  # tests et lancements avec arguments : jamais le vrai fichier

static var data := {"items": {}, "sets": {}, "cards": {}, "card_rules": {}}
static var _orig := {}  # id -> modèle d'origine (pour annuler les modifications)


## Chargement (GameData, après le catalogue) : applique les modifications enregistrées.
static func is_test() -> bool:
	return not OS.get_cmdline_user_args().is_empty() or " ".join(OS.get_cmdline_args()).contains("res://tests/")


## Fichiers lus, dans l'ordre (le dernier l'emporte).
static func paths() -> Array:
	return [TEST_PATH] if is_test() else [PATH, USER_PATH]


static func load_and_apply() -> void:
	for p in paths():
		if not FileAccess.file_exists(p):
			continue
		var d = JSON.parse_string(FileAccess.get_file_as_string(p))
		if typeof(d) != TYPE_DICTIONARY:
			continue
		for k in ["items", "sets", "cards", "card_rules"]:
			var src: Dictionary = d.get(k, {})
			for id in src:
				data[k][String(id)] = src[id]
	for id in data.items:
		_apply_item(String(id))
	for sid in data.sets:
		_apply_set(String(sid))


static func save() -> String:
	var txt := JSON.stringify(data, "\t", true)
	if is_test():
		var tf := FileAccess.open(TEST_PATH, FileAccess.WRITE)
		tf.store_string(txt)
		return "Enregistré (fichier de test)."
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f == null:
		f = FileAccess.open(USER_PATH, FileAccess.WRITE)
		if f == null:
			return "Impossible d'enregistrer les modifications."
		f.store_string(txt)
		return "Enregistré dans %s." % ProjectSettings.globalize_path(USER_PATH)
	f.store_string(txt)
	return "Enregistré (data/dev_edits.json : Envoyer.bat l'envoie sur GitHub)."


# --- objets du catalogue ----------------------------------------------------------------------
## Remplace des champs du modèle d'Eden [param id] (valeur null : champ retiré) et enregistre.
static func edit_item(id: int, fields: Dictionary) -> void:
	var cur: Dictionary = data.items.get(str(id), {})
	for k in fields:
		cur[k] = fields[k]
	data.items[str(id)] = cur
	_apply_item(str(id))


## Annule toutes les modifications du modèle [param id].
static func reset_item(id: int) -> void:
	data.items.erase(str(id))
	var e: Dictionary = GameData.eden_by_id.get(id, {})
	if _orig.has(str(id)) and not e.is_empty():
		e.clear()
		e.merge(_orig[str(id)].duplicate(true))


static func is_edited(id: int) -> bool:
	return data.items.has(str(id))


static func _apply_item(id: String) -> void:
	var e: Dictionary = GameData.eden_by_id.get(int(id), {})
	if e.is_empty():
		return
	if not _orig.has(id):
		_orig[id] = e.duplicate(true)
	var f: Dictionary = data.items[id]
	for k in f:
		if f[k] == null:
			e.erase(k)
		else:
			e[k] = f[k].duplicate(true) if f[k] is Dictionary or f[k] is Array else f[k]
	e["dev"] = true


# --- sets --------------------------------------------------------------------------------------
static func new_set_id() -> String:
	var n := 1
	while data.sets.has("u%d" % n) or GameData.eden_sets.has("u%d" % n):
		n += 1
	return "u%d" % n


## Enregistre la définition du set [param sid] ({name, pieces, bonus}) et met les pièces à jour.
static func edit_set(sid: String, def: Dictionary) -> void:
	var old: Array = GameData.eden_sets.get(sid, {}).get("pieces", [])
	for pid in old:
		if not pid in def.pieces:
			edit_item(int(pid), {"set": null})
	for pid in def.pieces:
		edit_item(int(pid), {"set": sid})
	data.sets[sid] = def.duplicate(true)
	_apply_set(sid)


static func delete_set(sid: String) -> void:
	for pid in GameData.eden_sets.get(sid, {}).get("pieces", []):
		edit_item(int(pid), {"set": null})
	data.sets[sid] = null
	GameData.eden_sets.erase(sid)


static func _apply_set(sid: String) -> void:
	var def = data.sets[sid]
	if def == null:
		GameData.eden_sets.erase(sid)
	else:
		GameData.eden_sets[sid] = (def as Dictionary).duplicate(true)


# --- objets possédés ---------------------------------------------------------------------------
## Tous les objets du joueur (coffre, sac, équipement porté).
static func owned_items() -> Array:
	var out: Array = []
	var seen := {}
	for it in Profile.equipped.values() + Profile.inventory + Profile.vault:
		var uid := String(it.get("uid", ""))
		if uid != "" and not seen.has(uid):
			seen[uid] = true
			out.append(it)
	return out


## Les objets possédés faits sur le modèle [param id] reprennent ses stats, son set, son passif
## et son nom (leur rareté, amélioration, qualité, gemmes et bonus restent). Renvoie leur nombre.
static func refresh_owned(id: int) -> int:
	var e: Dictionary = GameData.eden_by_id.get(id, {})
	if e.is_empty():
		return 0
	var n := 0
	for it in owned_items():
		if int(it.get("eden", 0)) != id:
			continue
		var fresh := Items.from_template(e, Items.power_level(it), int(it.rarity))
		for k in ["name", "level", "base", "passive", "set"]:
			if fresh.has(k):
				it[k] = fresh[k]
			else:
				it.erase(k)
		n += 1
	Profile.save_profile()
	return n


# --- passifs -----------------------------------------------------------------------------------
## Passif {name, stat, procs, trophy, desc} : bonus fixes et buff sous condition (famille des
## trophées, force selon [param rarity]).
static func make_passive(name: String, stat: Dictionary, kind: String, rarity: int, base_procs: Array = []) -> Dictionary:
	var p := {"name": name, "stat": stat.duplicate(), "procs": base_procs.duplicate(true)}
	if kind != "":
		var pr := Trophies.proc_for(kind, rarity)
		p.procs = [pr]
		p["trophy"] = kind
		if name == "":
			p.name = String(Trophies.KINDS[kind].name)
	p["desc"] = passive_desc(p)
	return p


static func passive_desc(p: Dictionary) -> String:
	var parts: PackedStringArray = []
	for s in p.get("stat", {}):
		parts.append(Items.stat_text(s, p.stat[s]))
	for pr in p.get("procs", []):
		parts.append(Procs.describe(pr))
	return ", ".join(parts)
