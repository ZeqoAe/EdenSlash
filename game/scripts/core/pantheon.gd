class_name Pantheon
extends RefCounted
## Panthéon des cerveaux (lot 14) : six cerveaux d'IA à battre dans l'ordre, à l'arme, niveau 10, au
## meilleur de trois manches. La 1re victoire donne une pièce de la panoplie des Esprits, un coffre
## d'apparence, un titre et (selon le cerveau) un coffre d'auras. Une nouvelle classe qui bat un cerveau
## déjà battu donne un coffre d'apparence de moins haute qualité ; la même classe, rien de plus (pas de
## farm). Une pièce « s'éveille » quand son cerveau est battu avec une classe de chacune des 5 familles.
## État : `Profile.pantheon[cerveau] = {classes: [...], families: [...], awake: bool}`.
##
## Panoplie universelle (lot E2, I8) : chaque pièce est un modèle fixe (légendaire de niveau [constant PIECE_LEVEL],
## jamais selon la zone du lobby). Gagnée, elle entre aussi dans `Profile.seen_gear` sous un id à elle
## ([method shop_id]) : l'Armurerie la revend à toutes les classes ; le Champion y ouvre l'arme des Esprits de
## chacun des 17 types. Ces modèles sont ajoutés à `GameData.eden_by_id` ([method register_templates]). Éveil :
## 6 pièces éveillées portées = bonus 6 pièces renforcé (`Items.SETS.pantheon.awake`).
## Battre un cerveau donne aussi de la maîtrise (Duel.settle, formule commune League.mastery_for).

const LEVEL := 10
const FAMILIES := 5
const PIECE_LEVEL := 70  # niveau d'Eden des pièces de la panoplie (fixe)
const SHOP_BASE := 900000  # ids des pièces dans seen_gear : SHOP_BASE + 100 × cerveau + type d'arme
## Types d'arme, dans un ordre fixe (les ids en dépendent : ajouter à la fin).
const WTYPES := ["axe", "bow", "cannon", "cestus", "dagger", "greatsword", "grimoire", "guitar", "gunscythe",
	"hammer", "katana", "rapier", "rod", "scepter", "spear", "staff", "sword"]

## id du cerveau (fichier data/cerveaux/cerveau_<id>.json), nom, emplacement de la pièce, récompenses.
const BRAINS := [
	{"id": "debutant", "name": "Débutant", "slot": "boots", "look": "look_rare", "aura": "", "title": "Éveillé"},
	{"id": "facile", "name": "Facile", "slot": "gloves", "look": "look_rare", "aura": "", "title": "Apprenti des Esprits"},
	{"id": "normal", "name": "Normal", "slot": "legs", "look": "look_epic", "aura": "aura_rare", "title": "Duelliste des Esprits"},
	{"id": "difficile", "name": "Difficile", "slot": "head", "look": "look_epic", "aura": "aura_rare", "title": "Briseur d'Esprits"},
	{"id": "hardcore", "name": "Hardcore", "slot": "chest", "look": "look_legend", "aura": "aura_legend", "title": "Fléau des Esprits"},
	{"id": "actuel", "name": "Champion", "slot": "weapon", "look": "look_legend", "aura": "aura_legend", "title": "Champion du Panthéon"},
]
const MASTER_TITLE := "Maître des Esprits"
const FIVE_TITLE := "Panthéon des cinq"


static func brain(i: int) -> Dictionary:
	return BRAINS[clampi(i, 0, BRAINS.size() - 1)]


static func index_of(id: String) -> int:
	for i in BRAINS.size():
		if BRAINS[i].id == id:
			return i
	return -1


static func entry(id: String) -> Dictionary:
	if not Profile.pantheon.has(id):
		Profile.pantheon[id] = {"classes": [], "families": [], "awake": false}
	return Profile.pantheon[id]


static func beaten(id: String) -> bool:
	return not (Profile.pantheon.get(id, {}).get("classes", []) as Array).is_empty()


## Nombre de cerveaux battus d'affilée depuis le Débutant.
static func progress() -> int:
	var n := 0
	for b in BRAINS:
		if beaten(String(b.id)):
			n += 1
		else:
			break
	return n


## Le cerveau [param i] peut être défié : le Panthéon est ouvert et le précédent battu.
static func available(i: int) -> bool:
	return Unlocks.is_open("pantheon") and i <= progress()


static func brain_file_present(id: String) -> bool:
	return FileAccess.file_exists(MlDuelPilot.frozen_path(id)) or FileAccess.file_exists("res://data/cerveaux/cerveau_%s.json" % id)


static func awake_count() -> int:
	var n := 0
	for b in BRAINS:
		if bool(Profile.pantheon.get(b.id, {}).get("awake", false)):
			n += 1
	return n


## Id (dans seen_gear et `GameData.eden_by_id`) de la pièce du cerveau [param i] ; [param wtype] pour l'arme.
static func shop_id(i: int, wtype := "") -> int:
	return SHOP_BASE + 100 * i + maxi(WTYPES.find(wtype), 0)


static func is_shop_id(id: int) -> bool:
	return id >= SHOP_BASE and id < SHOP_BASE + 100 * BRAINS.size()


## Ids de la pièce du cerveau [param i] : une, ou une par type d'arme (Champion).
static func shop_ids(i: int) -> Array:
	if String(brain(i).slot) != "weapon":
		return [shop_id(i)]
	return WTYPES.map(func(w): return shop_id(i, w))


## Modèle d'Eden choisi pour une pièce : légendaire de [param slot] (ou du type d'arme [param wtype]), le plus haut
## sans dépasser PIECE_LEVEL (le plus bas au-dessus sinon), hors pièces « Awaken » ; toujours le même.
static func _base_template(slot: String, wtype: String) -> Dictionary:
	var best: Dictionary = {}
	var above: Dictionary = {}
	for e: Dictionary in GameData.eden_by_slot.get(wtype if slot == "weapon" else slot, []):
		if int(e.get("rarity", 0)) != Items.LEGENDARY or (e.get("r", {}) as Dictionary).is_empty() or GameData.is_awakened(e):
			continue
		var lv := int(e.level)
		if lv <= PIECE_LEVEL:
			if best.is_empty() or lv > int(best.level) or (lv == int(best.level) and int(e.id) < int(best.id)):
				best = e
		elif above.is_empty() or lv < int(above.level) or (lv == int(above.level) and int(e.id) < int(above.id)):
			above = e
	return best if not best.is_empty() else above


## Ajoute à `GameData.eden_by_id` les modèles des pièces de la panoplie (une fois) : l'Armurerie, l'archive et les
## fiches les lisent comme les autres pièces (pas dans `eden_by_slot` : jamais dans un butin).
static func register_templates() -> void:
	if GameData.eden_by_id.has(shop_id(0)) or GameData.eden_by_slot.is_empty():
		return
	for i in BRAINS.size():
		var slot := String(BRAINS[i].slot)
		for id in shop_ids(i):
			var wt: String = WTYPES[int(id) % 100] if slot == "weapon" else ""
			var e := _base_template(slot, wt)
			if e.is_empty():
				continue
			var t := e.duplicate(true)
			t["id"] = int(id)
			t["set"] = "pantheon"
			t["pantheon"] = String(BRAINS[i].id)
			t["name"] = "%s %s" % [String(e.name), String(Items.SETS.pantheon.suffix)]
			t.erase("arch")  # pas d'entrée d'archive (archiver retirerait la pièce)
			GameData.eden_by_id[int(id)] = t


## Modèle d'une pièce de la panoplie ({} si absent).
static func template(id: int) -> Dictionary:
	register_templates()
	return GameData.eden_by_id.get(id, {}) if is_shop_id(id) else {}


## Pièces gagnées → Armurerie (seen_gear) ; aussi pour une sauvegarde d'avant le lot E2 (appelé au chargement).
static func sync_seen() -> void:
	register_templates()
	for i in BRAINS.size():
		if beaten(String(BRAINS[i].id)):
			_reveal(i)


static func _reveal(i: int) -> void:
	for id in shop_ids(i):
		if not int(id) in Profile.seen_gear and not template(int(id)).is_empty():
			Profile.seen_gear.append(int(id))


## Cerveau d'une pièce de la panoplie ("" : pas une pièce des Esprits).
static func brain_of(item: Dictionary) -> String:
	if item.has("pantheon"):
		return String(item.pantheon)
	var id := int(item.get("eden", -1))
	return String(BRAINS[(id - SHOP_BASE) / 100].id) if is_shop_id(id) else ""


## La pièce est éveillée (drapeau posé à l'éveil, ou son cerveau battu par les 5 familles).
static func piece_awake(item: Dictionary) -> bool:
	if bool(item.get("awakened", false)):
		return true
	var id := brain_of(item)
	return id != "" and bool(Profile.pantheon.get(id, {}).get("awake", false))


## Pièce de la panoplie pour le cerveau [param b] : modèle fixe (arme : du type de la classe [param class_id]).
static func make_piece(b: Dictionary, class_id: String, awake := false) -> Dictionary:
	var i := index_of(String(b.id))
	var e := template(shop_id(i, Items.default_weapon_type(class_id) if String(b.slot) == "weapon" else ""))
	var it: Dictionary
	if e.is_empty():  # catalogue d'Eden absent (tests minimaux) : pièce générée
		it = Items.generate(PIECE_LEVEL, 1.0, String(b.slot), class_id, Items.LEGENDARY, "", Items.LEGENDARY)
		Items.make_set_piece(it, "pantheon")
	else:
		it = Items.from_template(e, PIECE_LEVEL, Items.LEGENDARY)
	it["pantheon"] = String(b.id)
	if awake:
		it["awakened"] = true
	return it


## Première victoire de la classe [param class_id] contre le cerveau [param id] : renvoie ce qui est
## gagné {piece, chests: [types], title, awake, text: [lignes]} ; {} si rien (même classe déjà passée).
static func report_win(id: String, class_id: String) -> Dictionary:
	var i := index_of(id)
	if i < 0:
		return {}
	var b := brain(i)
	var st := entry(id)
	if class_id in st.classes:
		return {}
	var first := (st.classes as Array).is_empty()
	var fam := int(GameData.class_data(class_id).get("family", 1))
	(st.classes as Array).append(class_id)
	var out := {"piece": {}, "chests": [], "title": "", "awake": false, "text": []}
	if first:
		var piece := make_piece(b, class_id)
		Profile.mark_new(piece)  # pastille « Nouveau » dans le sac (lot GX-3)
		Profile.vault.append(piece)
		out.piece = piece
		out.text.append("Pièce de la panoplie des Esprits : %s" % String(piece.name))
		_reveal(i)  # à l'Armurerie pour toutes les classes
		out.text.append("Armes des Esprits de tous les types : Atelier > Fabriquer" if String(b.slot) == "weapon" else "Se refabrique à l'Atelier")
		Profile.chest_add(String(b.look), LEVEL)
		out.chests.append(String(b.look))
		if String(b.aura) != "":
			Profile.chest_add(String(b.aura), LEVEL)
			out.chests.append(String(b.aura))
		if id == "actuel":
			Profile.chest_add("look_legend", LEVEL)
			out.chests.append("look_legend")
			Profile.chest_add("aura_legend", LEVEL)
			out.chests.append("aura_legend")
		Profile.add_title(String(b.title))
		out.title = String(b.title)
		out.text.append("Titre : « %s »" % String(b.title))
	else:
		# nouvelle classe contre un cerveau déjà battu : un coffre d'apparence d'une qualité de moins
		var t := Rewards.look_type(maxi(Rewards.LOOK_TYPES.find(String(b.look)) - 1, 0))
		Profile.chest_add(t, LEVEL)
		out.chests.append(t)
		out.text.append("Nouvelle classe contre ce cerveau : un coffre d'apparence")
	if not fam in st.families:
		(st.families as Array).append(fam)
	if (st.families as Array).size() >= FAMILIES and not bool(st.awake):
		st["awake"] = true
		out.awake = true
		out.text.append("La pièce s'éveille : le cerveau est battu par les 5 familles !")
		for it in Profile.vault + Profile.inventory:
			if brain_of(it) == id:
				it["awakened"] = true
		Profile.chest_add("aura_legend", LEVEL)
		out.chests.append("aura_legend")
		if awake_count() >= BRAINS.size():
			Profile.add_title(MASTER_TITLE)
			out.text.append("Titre doré : « %s »" % MASTER_TITLE)
	if id == "actuel" and (st.families as Array).size() >= FAMILIES:
		Profile.add_title(FIVE_TITLE)
	return out
