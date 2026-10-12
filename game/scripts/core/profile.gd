extends Node
## Profil sauvegardé entre les runs.
## Roguelite : chaque run repart de zéro (or, matériaux, butin). Ce qui reste :
## l'« héritage » (vault), un objet gardé au choix à la fin de chaque run, avec
## son amélioration, et l'équipement de départ choisi parmi l'héritage (loadout).
## Hors run, equipped / inventory montrent l'héritage ; pendant une run, ce sont
## les objets de la run (copies de l'équipement de départ + butin).
## L'héritage est un coffre commun à toutes les classes ; chaque classe a son propre
## équipement, en 3 préréglages nommés (presets) : changer de classe change d'équipement.
## 3 emplacements de sauvegarde (écran titre : continuer, charger, nouvelle partie) ;
## l'emplacement 1 est l'ancien fichier profile.json.

const SAVE_PATH := "user://profile.json"
const SLOT_COUNT := 3
const LAST_SLOT_PATH := "user://last_slot.txt"
## Les lancements de test (arguments après --, scènes res://tests) ont leur propre
## sauvegarde : ils ne touchent jamais au profil du joueur.
const TEST_SAVE_PATH := "user://profile_test.json"
const INVENTORY_MAX := 100000  # inventaire sans limite de place
const VAULT_MAX := 100000
const PRESETS_PER_CLASS := 3

signal changed
signal class_unlocked(cls: String)  # mission remplie : nouvelle classe jouable

var selected_class := "warrior"
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
var unlocked_classes: Array = []  # classes débloquées par mission (le Guerrier l'est d'emblée)
var records := {}  # records cumulés de toutes les runs (missions) : kills, healed, best_hit...
var cert_board: Array = ["", "", "", "", "", "", ""]  # plateau des certificats (CertBoard)
var archive := {}  # entrée de l'archive ("katana:4", "set:storm"...) -> copie de l'objet archivé
var skins := {}  # type d'arme -> code du modèle choisi (apparence débloquée par l'archive)
var outfits := {}  # classe -> tenue portée (skin cosmétique, .glb de assets/player/outfits)
var owned_outfits: Array = []
## Trésors de collection obtenus (ids des entrées de l'archive d'Eden hors équipement).
var collection: Array = []
var worn := {}  # classe -> {"head": .glb, "back": .glb} : accessoires cosmétiques portés  # cosmétiques d'Eden débloqués (identifiants de data/eden_items.json -> cosmetics)
## Mode dev (écran F10) : or et matériaux donnés au départ de chaque run tant que le mode dev
## est activé dans les Paramètres (« enabled » : ancien interrupteur, repris par les Paramètres).
var dev := {"enabled": false, "gold": 0, "fragment": 0, "essence": 0, "crystal": 0}
var unlocked_zones := 1  # zones jouables (dans l'ordre de data/zones.json)
var selected_zone := "limestone"
var starter_trophy := ""  # uid du trophée de départ (donné une fois par sauvegarde)
var runs_done := 0
var runs_won := 0
var best_level := 1


var save_path := SAVE_PATH
var slot := 1  # emplacement de sauvegarde chargé
var _test := false


func _ready() -> void:
	if not OS.get_cmdline_user_args().is_empty() or " ".join(OS.get_cmdline_args()).contains("res://tests/"):
		_test = true
	slot = last_slot()
	save_path = slot_path(slot)
	load_profile()
	_ensure_starter()


## Équipement de départ : un katana commun si l'héritage n'a pas d'arme, et le trophée de
## départ (une seule fois par sauvegarde), porté par toutes les classes.
func _ensure_starter() -> void:
	if in_run:
		return
	var changed := false
	if not vault.any(func(it): return it.slot == "weapon"):
		var w := Items.generate(1, -1.0, "weapon")
		vault.append(w)
		loadout["weapon"] = w.uid
		changed = true
	if starter_trophy == "" and GameData.eden_by_id.has(Trophies.STARTER_ID):
		var t := Items.from_template(GameData.eden_by_id[Trophies.STARTER_ID], 1, Trophies.STARTER_RARITY)
		vault.append(t)
		starter_trophy = String(t.uid)
		for cls in presets:
			for st in presets[cls].sets:
				if not st.slots.has("trophy"):
					st.slots["trophy"] = starter_trophy
		if not loadout.has("trophy"):
			loadout["trophy"] = starter_trophy
		changed = true
	if changed:
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
	records = d.get("records", {})
	if d.has("unlocked_classes"):
		unlocked_classes = d.unlocked_classes
	else:
		# ancienne sauvegarde : les classes déjà jouées restent débloquées
		unlocked_classes = []
		for cid in [String(d.get("selected_class", ""))] + (d.get("expertise", {}) as Dictionary).keys() + (d.get("presets", {}) as Dictionary).keys():
			if cid != "" and cid != Progression.START_CLASS and not cid in unlocked_classes:
				unlocked_classes.append(cid)
	cert_board = d.get("cert_board", [])
	if cert_board.size() != CertBoard.POS.size():
		cert_board = ["", "", "", "", "", "", ""]
		for i in mini(certificates.size(), CertBoard.POS.size()):
			cert_board[CertBoard.OPEN_ORDER[i]] = String(certificates[i])
	_sync_certificates()
	archive = d.get("archive", {})
	# ancienne archive (type × rareté) -> une entrée par objet d'Eden mythique ou légendaire
	for k in archive.keys():
		if String(k).begins_with("e"):
			if archive[k] is Dictionary:
				_migrate(archive[k])
			continue
		var old: Dictionary = archive[k]
		archive.erase(k)
		if old is Dictionary:
			_migrate(old)
			for nk in Archive.keys_for(old):
				if not archive.has(nk):
					archive[nk] = old
	skins = d.get("skins", {})
	outfits = d.get("outfits", {})
	owned_outfits = d.get("owned_outfits", [])
	collection = (d.get("collection", []) as Array).map(func(x): return str(int(x)) if typeof(x) == TYPE_FLOAT else String(x))
	worn = d.get("worn", {})
	dev = {"enabled": false, "gold": 0, "fragment": 0, "essence": 0, "crystal": 0}
	dev.merge(d.get("dev", {}), true)
	if dev.enabled:  # ancien interrupteur de l'encyclopédie : repris par les Paramètres
		Settings.set_v("interface", "dev_mode", true)
		dev.enabled = false
	selected_zone = String(d.get("selected_zone", "limestone"))
	starter_trophy = String(d.get("starter_trophy", ""))
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
	if not item.has("rv") and item.has("rarity"):
		# anciennes raretés (commun, magique, rare or, épique, légendaire orange) -> raretés d'Eden
		item["rarity"] = [0, 2, 3, 3, 4][clampi(int(item.rarity), 0, 4)]
		item["rv"] = 2
	if int(item.get("rv", 0)) == 2 and item.has("eden"):
		# niveau affiché = niveau de l'objet dans Eden ; l'ancien niveau devient sa puissance
		var e: Dictionary = GameData.eden_by_id.get(int(item.eden), {})
		item["plevel"] = int(item.get("level", 1))
		if not e.is_empty():
			item["level"] = int(e.level)
		item["rv"] = 3
	if item.get("slot", "") == "trophy" and item.has("eden") and not item.get("passive", {}).has("trophy"):
		# trophée d'avant la refonte : plus de stats fixes, un buff sous condition
		var te: Dictionary = GameData.eden_by_id.get(int(item.eden), {})
		if te.has("trophy"):
			item["base"] = {}
			item["affixes"] = {}
			item["passive"] = Trophies.passive_for(te, int(item.get("rarity", 0)))
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
		"unlocked_zones": unlocked_zones, "selected_zone": selected_zone, "starter_trophy": starter_trophy,
		"expertise": expertise, "talents": talents, "certificates": certificates, "stash": stash,
		"unlocked_classes": unlocked_classes, "records": records, "cert_board": cert_board,
		"archive": archive, "skins": skins, "outfits": outfits, "owned_outfits": owned_outfits, "collection": collection, "worn": worn, "dev": dev, "saved_at": Time.get_datetime_string_from_system(false, true),
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
			if i == 0 and not first.has("trophy") and vault.any(func(it): return String(it.uid) == starter_trophy):
				first["trophy"] = starter_trophy  # nouvelle classe : le trophée de départ
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
	if Settings.get_v("interface", "dev_mode"):
		gold = int(dev.get("gold", 0))
		for m in materials:
			materials[m] = int(dev.get(m, 0))
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
# --- emplacements de sauvegarde ---------------------------------------------------------
## Fichier de l'emplacement [param i] (les tests ont leurs propres fichiers).
func slot_path(i: int) -> String:
	if _test:
		return TEST_SAVE_PATH if i == 1 else "user://profile_test_%d.json" % i
	return SAVE_PATH if i == 1 else "user://profile_%d.json" % i


func last_slot() -> int:
	var p := LAST_SLOT_PATH if not _test else "user://last_slot_test.txt"
	if FileAccess.file_exists(p):
		return clampi(int(FileAccess.get_file_as_string(p).strip_edges()), 1, SLOT_COUNT)
	return 1


func _remember_slot() -> void:
	var f := FileAccess.open(LAST_SLOT_PATH if not _test else "user://last_slot_test.txt", FileAccess.WRITE)
	if f:
		f.store_string(str(slot))


func slot_exists(i: int) -> bool:
	return FileAccess.file_exists(slot_path(i))


## Résumé d'un emplacement pour l'écran titre ({} s'il est vide).
func slot_summary(i: int) -> Dictionary:
	if not slot_exists(i):
		return {}
	var d = JSON.parse_string(FileAccess.get_file_as_string(slot_path(i)))
	if typeof(d) != TYPE_DICTIONARY:
		return {}
	var lv := 0
	for cls in d.get("expertise", {}):
		lv = maxi(lv, expertise_level_of(int(d.expertise[cls])))
	return {"class": String(d.get("selected_class", "samurai")), "runs": int(d.get("runs_done", 0)),
		"wins": int(d.get("runs_won", 0)), "best": int(d.get("best_level", 1)),
		"zones": int(d.get("unlocked_zones", 1)), "items": (d.get("vault", []) as Array).size(),
		"archive": (d.get("archive", {}) as Dictionary).size(), "expertise": maxi(lv, 1),
		"saved_at": String(d.get("saved_at", ""))}


## Charge l'emplacement [param i].
func load_slot(i: int) -> void:
	slot = clampi(i, 1, SLOT_COUNT)
	save_path = slot_path(slot)
	_clear()
	load_profile()
	_lobby_view()
	_ensure_starter()
	_remember_slot()


## Nouvelle partie dans l'emplacement [param i] (l'ancienne sauvegarde est remplacée).
func new_game(i: int) -> void:
	slot = clampi(i, 1, SLOT_COUNT)
	save_path = slot_path(slot)
	selected_class = Progression.START_CLASS
	reset_all()
	_remember_slot()


func delete_slot(i: int) -> void:
	if slot_exists(i):
		DirAccess.remove_absolute(slot_path(i))


## Remet le profil en mémoire à zéro, sans rien écrire.
func _clear() -> void:
	in_run = false
	starter_trophy = ""
	selected_class = Progression.START_CLASS
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
	cert_board = ["", "", "", "", "", "", ""]
	unlocked_classes = []
	records = {}
	archive = {}
	skins = {}
	outfits = {}
	owned_outfits = []
	collection = []
	worn = {}
	stash = {}
	bag = {}


func reset_all() -> void:
	in_run = false
	starter_trophy = ""
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
	cert_board = ["", "", "", "", "", "", ""]
	unlocked_classes = []
	records = {}
	archive = {}
	skins = {}
	outfits = {}
	owned_outfits = []
	collection = []
	worn = {}
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
	return expertise_level_of(int(expertise.get(cls, 0)))


static func expertise_level_of(points: int) -> int:
	var xp := points
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
	if expertise_level(cls) > before:
		_check_missions()  # la maîtrise débloque les classes vertes et orange qui en dépendent
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


## Équipe le certificat sur le premier emplacement libre du plateau, ou le retire.
func toggle_certificate(key: String) -> void:
	var at := cert_board.find(key)
	if at >= 0:
		cert_board[at] = ""
	else:
		for pos in CertBoard.OPEN_ORDER:
			if is_cert_open(pos) and String(cert_board[pos]) == "":
				cert_board[pos] = key
				break
	_sync_certificates()
	save_profile()


func is_cert_open(pos: int) -> bool:
	return CertBoard.is_open(pos, certificate_slots())


## Pose [param key] sur l'emplacement [param pos] (échange si un autre y est, ou si
## le certificat était déjà posé ailleurs).
func place_certificate(key: String, pos: int) -> void:
	if not is_cert_open(pos):
		return
	var from := cert_board.find(key)
	var there := String(cert_board[pos])
	if from >= 0:
		cert_board[from] = there
	cert_board[pos] = key
	_sync_certificates()
	save_profile()


func remove_certificate_at(pos: int) -> void:
	cert_board[pos] = ""
	_sync_certificates()
	save_profile()


## La liste des certificats équipés suit le plateau.
func _sync_certificates() -> void:
	certificates = cert_board.filter(func(k): return String(k) != "")


# --- records et missions --------------------------------------------------------------------
func record_add(key: String, amount: float) -> void:
	records[key] = float(records.get(key, 0.0)) + amount
	_check_missions()


func record_max(key: String, value: float) -> void:
	if value > float(records.get(key, 0.0)):
		records[key] = value
		_check_missions()


func _check_missions() -> void:
	for cls in Progression.check_missions():
		unlocked_classes.append(cls)
		if Run.active:
			Run.new_classes.append(cls)
		class_unlocked.emit(cls)


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
	# passifs des armes mythiques et légendaires d'Eden
	for slot in equipped:
		var i := 0
		for p: Dictionary in equipped[slot].get("passive", {}).get("procs", []):
			var q := p.duplicate(true)
			q["id"] = "passive_%s_%d" % [slot, i]
			out.append(q)
			i += 1
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


## Tenue (skin) portée par la classe ("" : tenue de la classe).
func outfit_of(cls: String) -> String:
	return String(outfits.get(cls, ""))


## Mode dev : niveau de maîtrise [param lvl] pour la classe (points d'expertise ajustés).
func set_expertise_level(cls: String, lvl: int) -> void:
	var pts := 0
	for l in range(1, clampi(lvl, 1, EXPERTISE_MAX)):
		pts += expertise_need(l)
	expertise[cls] = pts
	_check_missions()


func outfit_unlocked(id: String) -> bool:
	return id in owned_outfits


func unlock_outfit(id: String) -> void:
	if not id in owned_outfits:
		owned_outfits.append(id)


## Accessoires cosmétiques portés par la classe (chapeau, dos/ailes) : chemins .glb.
func worn_parts(cls: String) -> Array:
	var w: Dictionary = worn.get(cls, {})
	return [w.get("head", ""), w.get("back", "")].filter(func(p): return String(p) != "" and ResourceLoader.exists(String(p)))


func set_worn(cls: String, cat: String, path: String) -> void:
	if not worn.has(cls):
		worn[cls] = {}
	if path == "":
		worn[cls].erase(cat)
	else:
		worn[cls][cat] = path


## Trésor de collection [param x] obtenu ? (une apparence l'est aussi si sa tenue est débloquée)
func collected(x: Dictionary) -> bool:
	if str(int(x.id)) in collection:
		return true
	var cos: Dictionary = GameData.cosmetic_by_code.get(String(x.get("code", "")), {})
	return int(x.get("cat", 0)) <= 3 and not cos.is_empty() and outfit_unlocked(String(cos.id))


## Obtient le trésor [param x] (et la tenue correspondante pour une apparence).
func collect(x: Dictionary) -> void:
	var k := str(int(x.id))
	if not k in collection:
		collection.append(k)
	var cos: Dictionary = GameData.cosmetic_by_code.get(String(x.get("code", "")), {})
	if int(x.get("cat", 0)) <= 3 and not cos.is_empty():
		unlock_outfit(String(cos.id))


## Auras portées par la classe : une par type (pierre étoilée, pierre de lune, autre).
func worn_auras(cls: String) -> Array:
	var out: Array = []
	var w: Dictionary = worn.get(cls, {})
	for kind in ["star", "luna", "other"]:
		var x: Dictionary = GameData.collection_by_id.get(int(w.get("aura_" + kind, 0)), {})
		if x.has("aura") and collected(x):
			out.append(x)
	return out


func set_aura(cls: String, kind: String, id: int) -> void:
	if not worn.has(cls):
		worn[cls] = {}
	if id <= 0:
		worn[cls].erase("aura_" + kind)
	else:
		worn[cls]["aura_" + kind] = id


## Bonus des auras portées (en run).
func aura_stats(cls: String) -> Dictionary:
	var out := {}
	for x in worn_auras(cls):
		for s in x.aura.stat:
			out[s] = float(out.get(s, 0.0)) + float(x.aura.stat[s])
	return out
