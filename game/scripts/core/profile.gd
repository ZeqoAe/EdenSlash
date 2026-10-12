extends Node
## Profil sauvegardé entre les runs : classe choisie, or, matériaux,
## inventaire, équipement, statistiques de runs.

const SAVE_PATH := "user://profile.json"
const INVENTORY_MAX := 40

signal changed

var selected_class := "samurai"
var gold := 0
var materials := {"fragment": 0, "essence": 0, "crystal": 0}
var inventory: Array = []  # objets (Dictionary)
var equipped: Dictionary = {}  # emplacement -> objet
var runs_done := 0
var runs_won := 0
var best_level := 1


func _ready() -> void:
	load_profile()
	if not equipped.has("weapon"):
		# équipement de départ : un katana commun
		equipped["weapon"] = Items.generate(1, -1.0, "weapon")
		save_profile()


func load_profile() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var d = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if typeof(d) != TYPE_DICTIONARY:
		return
	selected_class = d.get("selected_class", selected_class)
	gold = int(d.get("gold", 0))
	for m in materials:
		materials[m] = int(d.get("materials", {}).get(m, 0))
	inventory = d.get("inventory", []).map(_migrate)
	equipped = {}
	var eq: Dictionary = d.get("equipped", {})
	for slot in eq:
		equipped[slot] = _migrate(eq[slot])
	runs_done = int(d.get("runs_done", 0))
	runs_won = int(d.get("runs_won", 0))
	best_level = int(d.get("best_level", 1))


## Anciennes sauvegardes (stats figées) -> format à jets.
func _migrate(item: Dictionary) -> Dictionary:
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
	var d := {"selected_class": selected_class, "gold": gold, "materials": materials, "inventory": inventory,
		"equipped": equipped, "runs_done": runs_done, "runs_won": runs_won, "best_level": best_level}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify(d))
	f.close()
	changed.emit()


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


func sell(item: Dictionary) -> int:
	var price := Items.sell_price(item)
	inventory.erase(item)
	gold += price
	save_profile()
	return price


func disassemble(item: Dictionary) -> Dictionary:
	var y := Items.disassemble_yield(item)
	inventory.erase(item)
	for m in y:
		materials[m] = int(materials.get(m, 0)) + int(y[m])
	save_profile()
	return y


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
