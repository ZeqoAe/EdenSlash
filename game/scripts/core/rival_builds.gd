class_name RivalBuilds
extends RefCounted
## Profils types (éditeur de profils, ProfileEditor) : un build complet d'une classe à un
## niveau, qui sert d'adversaire de duel ou s'applique au héros (mode dev). Un profil :
##   {name, class, level,
##    gear: {emplacement: {id (Eden), rarity, upgrade, rolls: {palier: stat}, gems: [clé, clé],
##           enchant: clé}},
##    look: {body, head, back : chemins .glb, dye: {body|head|back: 3 couleurs [r, g, b]},
##          aura: id de collection, aura_tint: [r, g, b] (vide : couleurs d'origine)},
##    talents: {id: rang} (points de maîtrise), certs: [clé « classe/passif »],
##    spells: [12 ids : case × 3 + rang, 0 = sort de la classe], hp_mult, atk_mult}
## Rangés dans les données du jeu (data/build_profiles.json, envoyé sur GitHub avec le reste ;
## user:// si le dossier n'est pas modifiable) ; les anciens adversaires (user://rival_builds.json)
## y sont repris.

const PATH := "res://data/build_profiles.json"
const USER_PATH := "user://build_profiles.json"
const LEGACY_PATH := "user://rival_builds.json"
const TEST_PATH := "user://build_profiles_test.json"
const MAX_CERTS := 7

static var _list: Array = []
static var _loaded := false


static func list() -> Array:
	if not _loaded:
		_loaded = true
		var paths := [TEST_PATH, "user://rival_builds_test.json"] if DevEdits.is_test() else [PATH, USER_PATH, LEGACY_PATH]
		for p in paths:
			if not FileAccess.file_exists(p):
				continue
			var d = JSON.parse_string(FileAccess.get_file_as_string(p))
			if d is Array:
				for b in d:
					if b is Dictionary and find(String(b.get("name", ""))) < 0:
						_list.append(b)
	return _list


static func save() -> String:
	var txt := JSON.stringify(_list, "\t")
	if DevEdits.is_test():
		var tf := FileAccess.open(TEST_PATH, FileAccess.WRITE)
		tf.store_string(txt)
		return "Enregistré (fichier de test)."
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f == null:
		f = FileAccess.open(USER_PATH, FileAccess.WRITE)
		if f == null:
			return "Impossible d'enregistrer."
	f.store_string(txt)
	return "Enregistré."


static func find(name: String) -> int:
	for i in _list.size():
		if String(_list[i].get("name", "")) == name:
			return i
	return -1


## Enregistre [param b] (remplace celui du même nom).
static func store(b: Dictionary) -> String:
	list()
	var i := find(String(b.name))
	if i >= 0:
		_list[i] = b.duplicate(true)
	else:
		_list.append(b.duplicate(true))
	return save()


static func remove(name: String) -> void:
	list()
	var i := find(name)
	if i >= 0:
		_list.remove_at(i)
		save()


static func blank(cid: String, lv := 20) -> Dictionary:
	return {"name": "%s niv. %d" % [GameData.class_data(cid).get("name_fr", cid), lv], "class": cid, "level": lv, "gear": {}, "look": {},
		"certs": [], "talents": {}, "spells": Duel.grid12([]), "hp_mult": 1.0, "atk_mult": 1.0}


# --- apparence et maîtrise --------------------------------------------------------------------
## Pièces recolorées du profil : chemin .glb -> 3 couleurs (EdenModel.apply_dye).
static func look_dyes(look: Dictionary, cls: Dictionary) -> Dictionary:
	var out := {}
	var dye: Dictionary = look.get("dye", {})
	for cat in ["body", "head", "back"]:
		var path := String(look.get(cat, ""))
		if cat == "body" and path == "":
			var parts: Array = cls.get("parts", [])
			path = String(parts[0]) if not parts.is_empty() else ""
		var c: Array = dye.get(cat, [])
		if path != "" and c.size() >= 3:
			out[path] = c
	return out


static func aura_ids(look: Dictionary) -> Array:
	return [int(look.aura)] if int(look.get("aura", 0)) > 0 else []


static func aura_tint(look: Dictionary) -> Color:
	var c: Array = look.get("aura_tint", [])
	return Color8(int(c[0]), int(c[1]), int(c[2]), 255) if c.size() >= 3 else Color(1, 1, 1, 0)


## Points de maîtrise du profil et niveau de maîtrise qu'il faudrait (2 points par niveau).
static func talent_points(b: Dictionary) -> int:
	var n := 0
	for k in b.get("talents", {}):
		n += int(b.talents[k])
	return n


# --- objets ------------------------------------------------------------------------------------
## Stats proposées aux paliers d'amélioration de l'emplacement [param slot] (comme la forge).
static func roll_pool(slot: String) -> Array:
	return Craft.UPGRADE_POOL_WEAPON if slot in ["weapon", "gloves"] else Craft.UPGRADE_POOL_ARMOR


## Objet complet d'après sa fiche [param g] au niveau [param level] (qualité au mieux, paliers,
## gemmes et enchantement choisis).
static func make_item(slot: String, g: Dictionary, level: int) -> Dictionary:
	var e: Dictionary = GameData.eden_by_id.get(int(g.get("id", 0)), {})
	if e.is_empty():
		return {}
	var r := clampi(int(g.get("rarity", e.rarity)), 0, Items.RARITIES.size() - 1)
	var it := Items.from_template(e, level, r)
	it["uid"] = "p_%s_%d_%d" % [slot, int(g.id), level]
	it["quality"] = float(Items.QUALITY[r][1])
	var up := clampi(int(g.get("upgrade", 0)), 0, Items.MAX_UPGRADE)
	it["upgrade"] = up
	var rolls: Array = []
	var chosen: Dictionary = g.get("rolls", {})
	for m in Items.MILESTONES:
		if int(m) > up:
			break
		var stat := String(chosen.get(str(m), roll_pool(slot)[0]))
		var rr: Array = Craft.UPGRADE_ROLL.get(stat, [1.0, 3.0])
		rolls.append([stat, snappedf(float(rr[1]) * 2.0, 0.001 if stat in Items.PERCENT_STATS else 0.1), int(m)])
	it["up_rolls"] = rolls
	var gems: Array = g.get("gems", [])
	if not gems.is_empty():
		var sockets: Array = []
		for k in gems.slice(0, Craft.MAX_SOCKETS):
			var p := String(k).split(":")
			sockets.append({"type": p[1], "tier": int(p[2])} if p.size() >= 3 else null)
		it["sockets"] = sockets
	var en := String(g.get("enchant", ""))
	if en != "":
		var p := en.split(":")
		if p.size() >= 3:
			it["enchant"] = {"type": p[1], "lv": int(p[2])}
	return it


## Objets du profil au niveau [param level] : emplacement -> objet.
static func items(b: Dictionary, level: int) -> Dictionary:
	var out := {}
	var g: Dictionary = b.get("gear", {})
	for slot in g:
		var it := make_item(String(slot), g[slot], level)
		if not it.is_empty():
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
	# talents de stats (arbre de maîtrise) et bonus de l'aura
	var tree: Dictionary = GameData.talents.get(String(b.get("class", "")), {}).get("talents", {})
	for id in b.get("talents", {}):
		var eff: Dictionary = tree.get(str(id), {}).get("effect", {})
		if eff.get("type", "") == "stat":
			total[eff.stat] = float(total.get(eff.stat, 0.0)) + float(eff.per_level) * int(b.talents[id])
	for id in aura_ids(b.get("look", {})):
		var ax: Dictionary = GameData.collection_by_id.get(int(id), {})
		for k in ax.get("aura", {}).get("stat", {}):
			total[k] = float(total.get(k, 0.0)) + float(ax.aura.stat[k])
	var cb := CertBoard.stats(cert_board(b))
	for k in cb:
		total[k] = float(total.get(k, 0.0)) + float(cb[k])
	for key in b.get("certs", []):
		var st: Dictionary = Run.certificate_card(String(key)).get("stat", {})
		for k in st:
			if typeof(st[k]) in [TYPE_FLOAT, TYPE_INT]:
				total[k] = float(total.get(k, 0.0)) + float(st[k])
	return total


# --- remplissage et application -------------------------------------------------------------
## Remplit le profil : pour chaque emplacement la meilleure pièce d'Eden de son niveau (l'arme
## du type de la classe), mythique ; les certificats de sa classe.
static func auto_fill(b: Dictionary) -> void:
	var cid := String(b.get("class", "warrior"))
	var lv := int(b.get("level", 20))
	var wtype := Items.default_weapon_type(cid)
	var gear := {}
	for slot in ["weapon", "head", "chest", "legs", "gloves", "boots", "back", "necklace", "ring", "trophy"]:
		var best: Dictionary = {}
		for x in GameData.eden_items:
			if String(x.get("slot", "")) != slot or int(x.level) > lv:
				continue
			if slot == "weapon" and String(x.get("wtype", "")) != wtype:
				continue
			if best.is_empty() or int(x.level) > int(best.level) or (int(x.level) == int(best.level) and int(x.rarity) > int(best.rarity)):
				best = x
		if not best.is_empty():
			gear[slot] = {"id": int(best.id), "rarity": maxi(int(best.rarity), Items.MYTHIC), "upgrade": 0}
	b["gear"] = gear
	b["certs"] = (GameData.talents.get(cid, {}).get("certificates", []) as Array).map(func(p): return "%s/%s" % [cid, p])


## Applique le profil au héros (mode dev) : classe choisie, objets ajoutés au coffre commun et
## équipés dans le préréglage, preset de sorts, plateau des certificats, tenue et accessoires.
static func apply_to_hero(b: Dictionary) -> String:
	var cid := String(b.get("class", "warrior"))
	if Profile.in_run:
		return "Hors run seulement."
	Profile.selected_class = cid
	Profile._lobby_view()
	var made := items(b, int(b.get("level", 20)))
	for slot in made:
		var it: Dictionary = made[slot]
		it["uid"] = "%d_%d" % [Time.get_ticks_usec(), randi() % 100000]  # un vrai objet, à part du profil
		Profile.inventory.append(it)
		Profile.equip(it)
	var grid := Duel.grid12(b.get("spells", []))
	var kit := Duel.kit_from_grid(cid, grid)
	var cols := SpellPresets.empty_cols()
	for c in mini(kit.skills.size(), SpellPresets.COLS):
		cols[c][0] = int(kit.skills[c].id)
		var ch: Array = kit.chains.get(c, [])
		for r in mini(ch.size(), 2):
			cols[c][r + 1] = int(ch[r].id)
	SpellPresets.store(cid, String(b.name), cols)
	Profile.cert_board = cert_board(b)
	if Profile.has_method("_sync_certificates"):
		Profile.call("_sync_certificates")
	var look: Dictionary = b.get("look", {})
	if String(look.get("body", "")) != "":
		Profile.outfits[cid] = String(look.body)
	for k in ["head", "back"]:
		Profile.set_worn(cid, k, String(look.get(k, "")))
	for k in ["body", "head", "back"]:
		Profile.set_dye(cid, k, look.get("dye", {}).get(k, []))
	var ax: Dictionary = GameData.collection_by_id.get(int(look.get("aura", 0)), {})
	if ax.has("aura"):
		if not Profile.collected(ax):
			Profile.collect(ax)  # mode dev : l'aura du profil est obtenue
		Profile.set_aura(cid, String(ax.aura.kind), int(ax.id))
	Profile.set_aura_tint(cid, look.get("aura_tint", []))
	if not b.get("talents", {}).is_empty():
		Profile.talents[cid] = (b.talents as Dictionary).duplicate()
	Profile.save_profile()
	Profile.changed.emit()
	return "« %s » appliqué : %d objet(s) équipés (et rangés dans le coffre), preset de sorts, certificats, maîtrise, apparence." % [b.name, made.size()]
