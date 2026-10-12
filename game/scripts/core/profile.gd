extends Node
## Profil sauvegardé entre les runs.
## Roguelite : chaque run repart de zéro (or, matériaux, butin). Ce qui reste :
## l'« héritage » (vault), un objet gardé au choix à la fin de chaque run, avec
## son amélioration, et l'équipement de départ choisi parmi l'héritage (loadout).
## Hors run, equipped / inventory montrent l'héritage ; pendant une run, ce sont
## les objets de la run (copies de l'équipement de départ + butin).
## L'héritage est un coffre commun à toutes les classes ; chaque classe a son propre
## équipement, en 3 préréglages nommés (presets) : changer de classe change d'équipement.

const SAVE_PATH := "user://profile.json"
## Les lancements de test (arguments après --, scènes res://tests) ont leur propre
## sauvegarde : ils ne touchent jamais au profil du joueur.
const TEST_SAVE_PATH := "user://profile_test.json"
const INVENTORY_MAX := 40
const VAULT_MAX := 80
const PRESETS_PER_CLASS := 3

signal changed

var selected_class := "samurai"
var gold := 0
var materials := {"fragment": 0, "essence": 0, "crystal": 0}
var inventory: Array = []  # objets (Dictionary)
var equipped: Dictionary = {}  # emplacement -> objet
var vault: Array = []  # objets gardés entre les runs
var loadout: Dictionary = {}  # préréglage actif de la classe choisie : emplacement -> uid (référence dans presets)
## Préréglages d'équipement : classe -> {"active": int, "sets": [{"name", "slots": {emplacement: uid}}]}
var presets: Dictionary = {}
var _view_class := ""  # classe dont le préréglage est projeté dans equipped / inventory (hors run)
var in_run := false
var bag := {}  # consommables de la run (Craft) : clé -> quantité
var stash := {}  # réserve de fournitures gardées (extraction, victoire), emportée à la run suivante
var expertise := {}  # classe -> points d'expertise (gagnés à chaque run)
var talents := {}  # classe -> {id talent (String): niveau}
var certificates: Array = []  # certificats équipés : "classe/id_passif"
var archive := {}  # entrée de l'archive ("katana:4", "set:storm"...) -> copie de l'objet archivé
var skins := {}  # type d'arme -> code du modèle choisi (apparence débloquée par l'archive)
var unlocked_zones := 1  # zones jouables (dans l'ordre de data/zones.json)
var selected_zone := "limestone"
var runs_done := 0
var runs_won := 0
var best_level := 1


var save_path := SAVE_PATH


func _ready() -> void:
	if not OS.get_cmdline_user_args().is_empty() or " ".join(OS.get_cmdline_args()).contains("res://tests/"):
		save_path = TEST_SAVE_PATH
	load_profile()
	_ensure_starter()


## Équipement de départ : un katana commun si l'héritage n'a pas d'arme.
func _ensure_starter() -> void:
	if in_run or vault.any(func(it): return it.slot == "weapon"):
		return
	var w := Items.generate(1, -1.0, "weapon")
	vault.append(w)
	loadout["weapon"] = w.uid
	_lobby_view()
	save_profile()


func load_profile() -> void:
	if not FileAccess.file_exists(save_path):
		return
	var d = JSON.parse_string(FileAccess.get_file_as_string(save_path))
	if typeof(d) != TYPE_DICTIONARY:
		return
	selected_class = d.get("selected_class", selected_class)
	runs_done = int(d.get("runs_done", 0))
	unlocked_zones = maxi(1, int(d.get("unlocked_zones", 1)))
	expertise = d.get("expertise", {})
	stash = d.get("stash", {})
	talents = d.get("talents", {})
	certificates = d.get("certificates", [])
	archive = d.get("archive", {})
	skins = d.get("skins", {})
	selected_zone = String(d.get("selected_zone", "limestone"))
	if d.has("vault"):
		vault = d.get("vault", []).map(_migrate)
		loadout = d.get("loadout", {})
		presets = d.get("presets", {})
	else:
		# ancienne sauvegarde : tout ce qu'on possédait devient l'héritage
		var eq: Dictionary = d.get("equipped", {})
		vault = d.get("inventory", []).map(_migrate)
		for slot in eq:
			var it := _migrate(eq[slot])
			vault.append(it)
			loadout[slot] = it.uid
	# une run interrompue (jeu fermé) est perdue : retour à l'héritage
	in_run = false
	_lobby_view()
	runs_won = int(d.get("runs_won", 0))
	best_level = int(d.get("best_level", 1))


## Anciennes sauvegardes (stats figées) -> format à jets.
func _migrate(item: Dictionary) -> Dictionary:
	if not item.has("uid"):
		item["uid"] = "%d_%d" % [Time.get_ticks_usec(), randi() % 100000]
	if item.has("quality"):
		return item
	item["quality"] = 1.0
	item["upgrade"] = 0
	var base: Dictionary = Items.BASES.get(item.get("slot", "weapon"), {}).get("stats", {})
	var aff := {}
	for s in item.get("stats", {}):
		if not base.has(s):
			aff[s] = float(item.stats[s])
	item["affixes"] = aff
	item.erase("stats")
	return item


func save_profile() -> void:
	if not in_run:
		_sync_vault()
	if not in_run and selected_class != _view_class:
		_lobby_view()  # autre classe choisie : on affiche son préréglage
	var d := {"selected_class": selected_class, "vault": vault, "loadout": loadout, "presets": presets,
		"unlocked_zones": unlocked_zones, "selected_zone": selected_zone,
		"expertise": expertise, "talents": talents, "certificates": certificates, "stash": stash,
		"archive": archive, "skins": skins,
		"runs_done": runs_done, "runs_won": runs_won, "best_level": best_level}
	var f := FileAccess.open(save_path, FileAccess.WRITE)
	f.store_string(JSON.stringify(d))
	f.close()
	changed.emit()


# --- héritage et runs ------------------------------------------------------------------
## Hors run : equipped / inventory = l'héritage, réparti selon le préréglage actif
## de la classe choisie (son arme par défaut si le préréglage n'en a pas).
func _lobby_view() -> void:
	_view_class = selected_class
	loadout = _active_slots(selected_class)
	if not in_run and not loadout.has("weapon"):
		_default_weapon(selected_class)
	equipped = {}
	inventory = []
	for it in vault:
		if String(loadout.get(it.slot, "")) == String(it.uid) and not equipped.has(it.slot):
			equipped[it.slot] = it
		else:
			inventory.append(it)
	gold = 0
	for m in materials:
		materials[m] = 0
	bag = {}


## Hors run, ce qui est équipé / rangé redevient l'héritage et le préréglage actif.
func _sync_vault() -> void:
	vault = equipped.values() + inventory
	if _view_class == "":
		_view_class = selected_class
	loadout = _active_slots(_view_class)
	loadout.clear()
	for slot in equipped:
		loadout[slot] = equipped[slot].uid


# --- préréglages d'équipement par classe ---------------------------------------------------
func _class_presets(cls: String) -> Dictionary:
	if not presets.has(cls):
		var sets: Array = []
		for i in PRESETS_PER_CLASS:
			# ancienne sauvegarde : l'équipement unique devient le préréglage 1 de la classe choisie
			var first: Dictionary = loadout.duplicate() if i == 0 and cls == selected_class and presets.is_empty() else {}
			sets.append({"name": "Préréglage %d" % (i + 1), "slots": first})
		presets[cls] = {"active": 0, "sets": sets}
	var p: Dictionary = presets[cls]
	while p.sets.size() < PRESETS_PER_CLASS:
		p.sets.append({"name": "Préréglage %d" % (p.sets.size() + 1), "slots": {}})
	return p


## Emplacements du préréglage actif de [param cls] (dictionnaire partagé, modifiable).
func _active_slots(cls: String) -> Dictionary:
	var p := _class_presets(cls)
	return p.sets[clampi(int(p.active), 0, p.sets.size() - 1)].slots


## Arme de départ d'une classe sans arme : la meilleure du coffre de son type, sinon une neuve.
func _default_weapon(cls: String) -> void:
	var wtype := Items.default_weapon_type(cls)
	var best: Dictionary = {}
	for it in vault:
		if it.slot == "weapon" and Items.weapon_type_of(it) == wtype:
			if best.is_empty() or int(it.rarity) * 20 + int(it.get("upgrade", 0)) > int(best.rarity) * 20 + int(best.get("upgrade", 0)):
				best = it
	if best.is_empty():
		best = Items.generate(1, -1.0, "weapon", cls, 0, wtype)
		vault.append(best)
	loadout["weapon"] = best.uid


func preset_names(cls: String) -> Array:
	return _class_presets(cls).sets.map(func(s): return String(s.name))


func active_preset(cls: String) -> int:
	return int(_class_presets(cls).active)


## Change de préréglage (hors run) ; l'équipement actuel reste enregistré dans l'ancien.
func set_active_preset(cls: String, index: int) -> void:
	if in_run:
		return
	_sync_vault()
	_class_presets(cls).active = clampi(index, 0, PRESETS_PER_CLASS - 1)
	_lobby_view()
	save_profile()


func rename_preset(cls: String, index: int, name: String) -> void:
	var p := _class_presets(cls)
	if index >= 0 and index < p.sets.size() and name.strip_edges() != "":
		p.sets[index].name = name.strip_edges().left(24)
		save_profile()


## Copie le préréglage actif de la classe dans le préréglage [param index].
func copy_active_preset(cls: String, index: int) -> void:
	if in_run:
		return
	_sync_vault()
	var p := _class_presets(cls)
	if index != int(p.active):
		p.sets[index].slots = _active_slots(cls).duplicate()
	save_profile()


## Classes et préréglages qui utilisent l'objet [param uid] : ["Guerrier · Préréglage 2", ...].
func item_users(uid: String) -> Array:
	var out: Array = []
	for cls in presets:
		var p: Dictionary = presets[cls]
		for i in p.sets.size():
			if String(uid) in p.sets[i].slots.values().map(func(u): return String(u)):
				out.append("%s · %s" % [GameData.class_data(cls).get("name_fr", cls), p.sets[i].name])
	return out


## Début de run : on part avec des copies de l'équipement de départ, sans or ni butin.
func begin_run() -> void:
	if in_run:
		return
	_sync_vault()
	in_run = true
	var start := {}
	for slot in equipped:
		start[slot] = equipped[slot].duplicate(true)
	equipped = start
	inventory = []
	gold = 0
	for m in materials:
		materials[m] = 0
	# la réserve de fournitures part avec le héros : perdue s'il tombe
	bag = stash.duplicate()
	stash = {}
	save_profile()


## Fin de run : [param item] (ou null) rejoint l'héritage avec son amélioration.
## Si c'est une pièce d'héritage portée pendant la run, elle est mise à jour.
func end_run(item) -> void:
	if not in_run:
		return
	in_run = false
	if Run.result == "victoire":
		keep_supplies()
	if item is Dictionary and not item.is_empty():
		var kept: Dictionary = item.duplicate(true)
		var replaced := false
		for i in vault.size():
			if String(vault[i].uid) == String(kept.uid):
				vault[i] = kept
				replaced = true
				break
		if not replaced and vault.size() < VAULT_MAX:
			vault.append(kept)
			if not loadout.has(kept.slot):
				loadout[kept.slot] = kept.uid
	_lobby_view()
	save_profile()


## Extraction réussie : tout l'inventaire de la run rejoint l'héritage (améliorations comprises),
## l'équipement porté devient l'équipement de départ.
func end_run_extract() -> int:
	if not in_run:
		return 0
	in_run = false
	keep_supplies()
	var kept := 0
	for it in equipped.values() + inventory:
		var copy: Dictionary = it.duplicate(true)
		var replaced := false
		for i in vault.size():
			if String(vault[i].uid) == String(copy.uid):
				vault[i] = copy
				replaced = true
				break
		if not replaced and vault.size() < VAULT_MAX:
			vault.append(copy)
		kept += 1
	loadout.clear()
	for slot in equipped:
		loadout[slot] = equipped[slot].uid
	_lobby_view()
	save_profile()
	return kept


## Les fournitures du sac rejoignent la réserve (extraction réussie, victoire).
func keep_supplies() -> void:
	for k in bag:
		stash[k] = int(stash.get(k, 0)) + int(bag[k])
	bag = {}


func stash_count() -> int:
	var n := 0
	for k in stash:
		n += int(stash[k])
	return n


## Arme de départ du type [param wtype] : la meilleure de l'héritage, sinon une arme commune neuve.
func select_weapon_type(wtype: String) -> void:
	if not in_run:
		_sync_vault()  # l'équipement de la classe affichée reste dans son préréglage
	var best: Dictionary = {}
	for it in vault:
		if it.slot == "weapon" and Items.weapon_type_of(it) == wtype:
			if best.is_empty() or int(it.rarity) * 20 + int(it.get("upgrade", 0)) > int(best.rarity) * 20 + int(best.get("upgrade", 0)):
				best = it
	if best.is_empty():
		best = Items.generate(1, -1.0, "weapon", selected_class, 0, wtype)
		vault.append(best)
	_active_slots(selected_class)["weapon"] = best.uid
	_lobby_view()
	save_profile()


## Nouvelle partie : efface tout (héritage, statistiques) et redonne le katana de départ.
func reset_all() -> void:
	in_run = false
	vault = []
	loadout = {}
	presets = {}
	_view_class = ""
	runs_done = 0
	runs_won = 0
	best_level = 1
	unlocked_zones = 1
	selected_zone = "limestone"
	expertise = {}
	talents = {}
	certificates = []
	archive = {}
	skins = {}
	stash = {}
	_lobby_view()
	_ensure_starter()
	save_profile()


# --- expertise de classe, talents, certificats -------------------------------------------
const EXPERTISE_MAX := 40
const CERT_LEVELS := [3, 8]  # niveaux d'expertise débloquant les 2 certificats d'une classe


## Points d'expertise nécessaires pour passer du niveau [param lvl] au suivant.
static func expertise_need(lvl: int) -> int:
	return 120 + 80 * lvl


func expertise_level(cls: String) -> int:
	var xp := int(expertise.get(cls, 0))
	var lvl := 1
	while lvl < EXPERTISE_MAX and xp >= expertise_need(lvl):
		xp -= expertise_need(lvl)
		lvl += 1
	return lvl


## Progression vers le niveau suivant : Vector2(points acquis, points nécessaires).
func expertise_progress(cls: String) -> Vector2:
	var xp := int(expertise.get(cls, 0))
	var lvl := 1
	while lvl < EXPERTISE_MAX and xp >= expertise_need(lvl):
		xp -= expertise_need(lvl)
		lvl += 1
	return Vector2(xp, expertise_need(lvl))


## Gain d'expertise en fin de run ; renvoie le nombre de niveaux gagnés.
func add_expertise(cls: String, amount: int) -> int:
	var before := expertise_level(cls)
	expertise[cls] = int(expertise.get(cls, 0)) + amount
	return expertise_level(cls) - before


## Points de talent : 2 au départ, +2 par niveau d'expertise.
func talent_points(cls: String) -> int:
	return 2 * expertise_level(cls)


func talent_rank(cls: String, id) -> int:
	return int(talents.get(cls, {}).get(str(int(id)), 0))


func talent_spent(cls: String) -> int:
	var n := 0
	for k in talents.get(cls, {}):
		n += int(talents[cls][k])
	return n


func _talent_cell(cls: String, id) -> Dictionary:
	for row in GameData.talents.get(cls, {}).get("rows", []):
		for c in row:
			if c != null and int(c.id) == int(id):
				return c
	return {}


## Pourquoi un point ne peut pas être ajouté ("" si possible).
func talent_block(cls: String, id) -> String:
	var c := _talent_cell(cls, id)
	if c.is_empty():
		return "talent inconnu"
	if talent_rank(cls, id) >= int(c.max):
		return "niveau maximal"
	if talent_spent(cls) >= talent_points(cls):
		return "plus de points (monte l'expertise de la classe)"
	if talent_spent(cls) < int(c.get("spent", 0)):
		return "%d points à dépenser dans l'arbre d'abord" % int(c.spent)
	if int(c.req) > 0 and talent_rank(cls, c.req) < int(c.req_pts):
		var t: Dictionary = GameData.talents[cls].talents.get(str(int(c.req)), {})
		return "nécessite %s niveau %d" % [t.get("name", "?"), int(c.req_pts)]
	return ""


func add_talent(cls: String, id) -> bool:
	if talent_block(cls, id) != "":
		return false
	if not talents.has(cls):
		talents[cls] = {}
	talents[cls][str(int(id))] = talent_rank(cls, id) + 1
	save_profile()
	return true


func reset_talents(cls: String) -> void:
	talents.erase(cls)
	save_profile()


## Certificats débloqués (toutes classes) : [{key, cls, passif}].
func unlocked_certificates() -> Array:
	var out: Array = []
	for cls in GameData.talents:
		var certs: Array = GameData.talents[cls].get("certificates", [])
		for i in certs.size():
			if i < CERT_LEVELS.size() and expertise_level(cls) >= int(CERT_LEVELS[i]):
				out.append({"key": "%s/%s" % [cls, certs[i]], "cls": cls, "id": certs[i]})
	return out


## Emplacements de certificats : 2, +1 tous les 8 niveaux d'expertise cumulés (7 max).
const CERT_MAX := 7


func certificate_slots() -> int:
	var total := 0
	for cls in GameData.talents:
		total += expertise_level(cls) - 1
	return clampi(2 + total / 8, 2, CERT_MAX)


func toggle_certificate(key: String) -> void:
	if key in certificates:
		certificates.erase(key)
	elif certificates.size() < certificate_slots():
		certificates.append(key)
	save_profile()


## Zone jouable ? (la suivante se débloque en battant le boss de la précédente)
func zone_unlocked(id: String) -> bool:
	return GameData.zone_index(id) < unlocked_zones


## Victoire dans [param zone_id] : débloque la zone suivante. Renvoie son nom (ou "").
func unlock_after(zone_id: String) -> String:
	var next := GameData.zone_index(zone_id) + 1
	if next >= GameData.zones.size() or next < unlocked_zones:
		return ""
	unlocked_zones = next + 1
	selected_zone = String(GameData.zones[next].id)
	save_profile()
	return String(GameData.zones[next].name)


# --- consommables (gemmes, parchemins, ciseaux, pierres) ------------------------------------
func add_bag(key: String, n := 1) -> void:
	bag[key] = int(bag.get(key, 0)) + n
	changed.emit()


func bag_count(key: String) -> int:
	return int(bag.get(key, 0))


func take_bag(key: String, n := 1) -> bool:
	if bag_count(key) < n:
		return false
	bag[key] = bag_count(key) - n
	if int(bag[key]) <= 0:
		bag.erase(key)
	changed.emit()
	return true


## Clés du sac commençant par [param prefix] (« gem », « scroll »…), triées.
func bag_keys(prefix: String) -> Array:
	var out := bag.keys().filter(func(k): return String(k).begins_with(prefix))
	out.sort()
	return out


func add_item(item: Dictionary) -> bool:
	if inventory.size() >= INVENTORY_MAX:
		return false
	inventory.append(item)
	changed.emit()
	return true


func add_gold(amount: int) -> void:
	gold += amount
	changed.emit()


func equip(item: Dictionary) -> void:
	var slot: String = item.slot
	inventory.erase(item)
	if equipped.has(slot):
		inventory.append(equipped[slot])
	equipped[slot] = item
	save_profile()


func unequip(slot: String) -> void:
	if equipped.has(slot) and inventory.size() < INVENTORY_MAX:
		inventory.append(equipped[slot])
		equipped.erase(slot)
		save_profile()


func sell(item: Dictionary) -> Dictionary:
	return sell_many([item])


func disassemble(item: Dictionary) -> Dictionary:
	return disassemble_many([item])


## Vente (or + 70 % des pierres d'amélioration) ou désassemblage groupés,
## une seule sauvegarde. Renvoie tout ce qui a été gagné.
func sell_many(items: Array) -> Dictionary:
	return _convert(items, true)


func disassemble_many(items: Array) -> Dictionary:
	return _convert(items, false)


func _convert(items: Array, selling: bool) -> Dictionary:
	var total := {}
	for it in items:
		var y := Items.sell_value(it) if selling else Items.disassemble_yield(it)
		for k in y:
			total[k] = int(total.get(k, 0)) + int(y[k])
		_remove(it)
	gain(total)
	save_profile()
	return total


func gain(res: Dictionary) -> void:
	for k in res:
		if k == "gold":
			gold += int(res[k])
		else:
			materials[k] = int(materials.get(k, 0)) + int(res[k])


## Retire exactement cet objet (et pas un autre identique) de l'inventaire.
func _remove(item: Dictionary) -> void:
	for i in inventory.size():
		if is_same(inventory[i], item):
			inventory.remove_at(i)
			return


func can_afford(cost: Dictionary) -> bool:
	for k in cost:
		var have := gold if k == "gold" else int(materials.get(k, 0))
		if have < int(cost[k]):
			return false
	return true


func pay(cost: Dictionary) -> bool:
	if not can_afford(cost):
		return false
	for k in cost:
		if k == "gold":
			gold -= int(cost[k])
		else:
			materials[k] = int(materials[k]) - int(cost[k])
	return true


## Améliore un objet (porté ou en inventaire). Renvoie la stat renforcée au palier,
## "" sinon, ou "!" si impossible.
## Tentative d'amélioration à la Eden : coût payé, pierres de chance et de protection
## consommées, résultat {ok, text, error?}.
func upgrade_item(item: Dictionary, luck := 0, protect := false) -> Dictionary:
	if int(item.get("upgrade", 0)) >= Items.MAX_UPGRADE:
		return {"ok": false, "error": true, "text": "Amélioration maximale atteinte."}
	if not pay(Items.upgrade_cost(item)):
		return {"ok": false, "error": true, "text": "Pas assez d'or ou de matériaux."}
	luck = mini(luck, bag_count("luck"))
	if luck > 0:
		take_bag("luck", luck)
	if protect and not take_bag("protect"):
		protect = false
	var r := Craft.upgrade(item, luck, protect)
	save_profile()
	return r


func buy(item: Dictionary, price: int) -> bool:
	if gold < price or inventory.size() >= INVENTORY_MAX:
		return false
	gold -= price
	inventory.append(item)
	save_profile()
	return true


## Somme des statistiques de l'équipement porté, bonus de set compris.
func equipment_stats() -> Dictionary:
	var total := {}
	for slot in equipped:
		var st := Items.stats(equipped[slot])
		for s in st:
			total[s] = total.get(s, 0.0) + float(st[s])
	for b in Items.active_set_bonuses(equipped):
		for s in b.stat:
			total[s] = total.get(s, 0.0) + float(b.stat[s])
	return total


## Effets déclenchés des bonus de set actifs.
func equipment_procs() -> Array:
	var out: Array = []
	for b in Items.active_set_bonuses(equipped):
		out.append_array(b.procs)
	return out


## Modèle de l'arme portée : son apparence choisie dans l'archive, sinon le sien.
func weapon_code() -> String:
	var w: Dictionary = equipped.get("weapon", {})
	if w.is_empty():
		return ""
	var skin := String(skins.get(Items.weapon_type_of(w), ""))
	return skin if skin != "" else String(w.get("weapon", ""))


## Apparence du type d'arme [param wtype] ("" : celle de l'arme).
func set_skin(wtype: String, code: String) -> void:
	if code == "":
		skins.erase(wtype)
	else:
		skins[wtype] = code
	save_profile()


## Archive l'objet (hors run) : il quitte le coffre et les préréglages, et remplit
## ses entrées vides de la collection. Renvoie les entrées remplies.
func archive_item(item: Dictionary) -> Array:
	if Archive.refusal(item) != "":
		return []
	_sync_vault()
	var uid := String(item.uid)
	for i in vault.size():
		if String(vault[i].uid) == uid:
			vault.remove_at(i)
			break
	for cls in presets:
		for st in presets[cls].sets:
			for slot in st.slots.keys():
				if String(st.slots[slot]) == uid:
					st.slots.erase(slot)
	var filled: Array = []
	for k in Archive.keys_for(item):
		if not archive.has(k):
			archive[k] = item.duplicate(true)
			filled.append(k)
	_lobby_view()
	_ensure_starter()
	save_profile()
	return filled


func all_items() -> Array:
	return equipped.values() + inventory
