class_name Pantheon
extends RefCounted
## Panthéon des cerveaux (lot 14) : six cerveaux d'IA à battre dans l'ordre, à l'arme, niveau 10, au
## meilleur de trois manches. La 1re victoire donne une pièce de la panoplie des Esprits, un coffre
## d'apparence, un titre et (selon le cerveau) un coffre d'auras. Une nouvelle classe qui bat un cerveau
## déjà battu donne un coffre d'apparence de moins haute qualité ; la même classe, rien de plus (pas de
## farm). Une pièce « s'éveille » quand son cerveau est battu avec une classe de chacune des 5 familles.
## État : `Profile.pantheon[cerveau] = {classes: [...], families: [...], awake: bool}`.

const LEVEL := 10
const FAMILIES := 5

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
	return FileAccess.file_exists(MlDuelPilot.brain_path(id))


static func awake_count() -> int:
	var n := 0
	for b in BRAINS:
		if bool(Profile.pantheon.get(b.id, {}).get("awake", false)):
			n += 1
	return n


## Pièce de la panoplie pour le cerveau [param b] (légendaire, du niveau le plus haut du héros).
static func make_piece(b: Dictionary, class_id: String, awake := false) -> Dictionary:
	var lv := maxi(Profile.best_level, 10)
	var it := Items.generate(lv, 1.0, String(b.slot), class_id, Items.LEGENDARY, "", Items.LEGENDARY)
	Items.make_set_piece(it, "pantheon")
	it["pantheon"] = String(b.id)
	it["name"] = "%s (%s)" % [String(it.name), String(b.name)]
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
		Profile.vault.append(piece)
		out.piece = piece
		out.text.append("Pièce de la panoplie des Esprits : %s" % String(piece.name))
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
			if String(it.get("pantheon", "")) == id:
				it["awakened"] = true
		Profile.chest_add("aura_legend", LEVEL)
		out.chests.append("aura_legend")
		if awake_count() >= BRAINS.size():
			Profile.add_title(MASTER_TITLE)
			out.text.append("Titre doré : « %s »" % MASTER_TITLE)
	if id == "actuel" and (st.families as Array).size() >= FAMILIES:
		Profile.add_title(FIVE_TITLE)
	return out
