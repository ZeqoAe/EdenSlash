extends Node
## Profil sauvegardé entre les runs.
## Roguelite : chaque run repart de zéro (or, matériaux, butin). Ce qui reste :
## l'« héritage » (vault), un objet gardé au choix à la fin de chaque run, avec
## son amélioration, et l'équipement de départ choisi parmi l'héritage (loadout).
## Hors run, equipped / inventory montrent l'héritage ; pendant une run, ce sont
## les objets de la run (copies de l'équipement de départ + butin).

const SAVE_PATH := "user://profile.json"
## Les lancements de test (arguments après --, scènes res://tests) ont leur propre
## sauvegarde : ils ne touchent jamais au profil du joueur.
const TEST_SAVE_PATH := "user://profile_test.json"
const INVENTORY_MAX := 40
const VAULT_MAX := 40

signal changed

var selected_class := "samurai"
var gold := 0
var materials := {"fragment": 0, "essence": 0, "crystal": 0}
var inventory: Array = []  # objets (Dictionary)
var equipped: Dictionary = {}  # emplacement -> objet
var vault: Array = []  # objets gardés entre les runs
var loadout: Dictionary = {}  # emplacement -> uid de l'objet d'héritage porté au départ
var in_run := false
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
	if d.has("vault"):
		vault = d.get("vault", []).map(_migrate)
		loadout = d.get("loadout", {})
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
	var d := {"selected_class": selected_class, "vault": vault, "loadout": loadout,
		"runs_done": runs_done, "runs_won": runs_won, "best_level": best_level}
	var f := FileAccess.open(save_path, FileAccess.WRITE)
	f.store_string(JSON.stringify(d))
	f.close()
	changed.emit()


# --- héritage et runs ------------------------------------------------------------------
## Hors run : equipped / inventory = l'héritage, réparti selon le loadout.
func _lobby_view() -> void:
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


## Hors run, ce qui est équipé / rangé redevient l'héritage et le loadout.
func _sync_vault() -> void:
	vault = equipped.values() + inventory
	loadout = {}
	for slot in equipped:
		loadout[slot] = equipped[slot].uid


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
	save_profile()


## Fin de run : [param item] (ou null) rejoint l'héritage avec son amélioration.
## Si c'est une pièce d'héritage portée pendant la run, elle est mise à jour.
func end_run(item) -> void:
	if not in_run:
		return
	in_run = false
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


## Nouvelle partie : efface tout (héritage, statistiques) et redonne le katana de départ.
func reset_all() -> void:
	in_run = false
	vault = []
	loadout = {}
	runs_done = 0
	runs_won = 0
	best_level = 1
	_lobby_view()
	_ensure_starter()
	save_profile()


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
func upgrade_item(item: Dictionary) -> String:
	if int(item.get("upgrade", 0)) >= Items.MAX_UPGRADE or not pay(Items.upgrade_cost(item)):
		return "!"
	var s := Items.upgrade(item)
	save_profile()
	return s


func buy(item: Dictionary, price: int) -> bool:
	if gold < price or inventory.size() >= INVENTORY_MAX:
		return false
	gold -= price
	inventory.append(item)
	save_profile()
	return true


## Somme des statistiques de l'équipement porté.
func equipment_stats() -> Dictionary:
	var total := {}
	for slot in equipped:
		var st := Items.stats(equipped[slot])
		for s in st:
			total[s] = total.get(s, 0.0) + float(st[s])
	return total


func weapon_code() -> String:
	return String(equipped.get("weapon", {}).get("weapon", ""))


func all_items() -> Array:
	return equipped.values() + inventory
