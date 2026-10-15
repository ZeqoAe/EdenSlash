class_name NamesFr
extends RefCounted
## Noms français des objets, monstres, zones, panoplies et apparences d'Eden.
## Table : res://data/names_fr.json (anglais exact -> français), générée par tools/names_fr_build.py
## et retouchable à la main (section « overrides », conservée à chaque génération).
## Appliquée UNE fois, au chargement des données (GameData._ready -> apply) : les dictionnaires
## du jeu portent ensuite le nom français dans « name » ; l'original reste dans « name_en ».
## Les identifiants ne changent jamais.

const PATH := "res://data/names_fr.json"

static var _t: Dictionary = {}
static var _loaded := false


static func table() -> Dictionary:
	if not _loaded:
		_loaded = true
		if FileAccess.file_exists(PATH):
			var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
			if d is Dictionary:
				_t = d
	return _t


## Nom français de [param name] dans la section [param section] (items, monsters, zones, sets,
## cosmetics, collection) ; à défaut, le nom d'origine nettoyé.
static func lookup(section: String, name: String) -> String:
	var t := table()
	var ov: Dictionary = t.get("overrides", {})
	if ov.has(name):
		return String(ov[name])
	var s: Dictionary = t.get(section, {})
	if s.has(name):
		return String(s[name])
	return clean(name)


## Repli : nom d'origine sans les scories d'Eden (tirets parasites, « Serial Number », « Version »).
static func clean(name: String) -> String:
	var s := name.strip_edges()
	for junk in [" Serial Number", " Version", " Ver."]:
		s = s.replace(junk, "")
	s = s.replace("- ", " ").replace(" - ", " ")
	while s.contains("  "):
		s = s.replace("  ", " ")
	return s.strip_edges()


## Nom français d'un objet déjà créé (ancienne sauvegarde : nom anglais gardé dans l'objet).
static func fix_item(item: Dictionary) -> void:
	var n := String(item.get("name", ""))
	if n == "":
		return
	var items: Dictionary = table().get("items", {})
	if items.has(n) or table().get("overrides", {}).has(n):
		item["name"] = lookup("items", n)


static func _rename(list: Array, section: String) -> void:
	for e in list:
		var n := String(e.get("name", ""))
		if n != "" and not e.has("name_en"):
			e["name_en"] = n
			e["name"] = lookup(section, n)


## Traduit en place les noms chargés par GameData (monstres, zones, équipement, panoplies, apparences).
static func apply(gd: Node) -> void:
	for id in gd.monsters:
		var m: Dictionary = gd.monsters[id]
		if not m.has("name_en"):
			m["name_en"] = String(m.name)
			m["name"] = lookup("monsters", String(m.name))
	for z: Dictionary in gd.zones:
		if not z.has("name_en"):
			z["name_en"] = String(z.name)
			z["name"] = lookup("zones", String(z.name))
		var dg: Dictionary = z.get("dungeon", {})
		if dg.has("name") and not dg.has("name_en"):
			dg["name_en"] = String(dg.name)
			dg["name"] = lookup("zones", String(dg.name))
	_rename(gd.eden_items, "items")
	for sid in gd.eden_sets:
		var s: Dictionary = gd.eden_sets[sid]
		if not s.has("name_en"):
			s["name_en"] = String(s.get("name", ""))
			s["name"] = lookup("sets", String(s.get("name", "")))
	_rename(gd.cosmetics, "cosmetics")
	_rename(gd.collection, "collection")
