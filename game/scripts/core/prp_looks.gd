class_name PrpLooks
extends RefCounted
## Créations maison (lots PRP-1 / PRP-2) : apparences d'armes et accessoires de dos modelés pour Eden Slash
## (image -> objet 3D -> Blender, tools/art/prp_pipeline.py ; conception/art/R_PRP2.md). Aucune stat : de l'apparence seule.
##
## Table : data/prp_looks.json (écrite par `prp_pipeline.py game`). [method install] les range dans les tables du
## catalogue au chargement (GameData) :
## - arme : trésor de collection de catégorie 4 avec `skin` (Héros > Apparence > Arme, Archive.skins, EdenModel.weapon_entry) ;
## - dos : cosmétique « back » (Héros > Apparence > Dos, Profile.unlock_outfit) + trésor de collection de catégorie 2
##   qui le débloque (Profile.collect).
## Les deux entrent donc d'elles-mêmes dans les coffres d'apparence (Rewards.roll_look, puits d'insignes) et dans la
## Collection du Carnet. En plus : la Vitrine (menu Coffres > Vitrine), achat direct en insignes, prix par rareté.

const PATH := "res://data/prp_looks.json"
## Prix en insignes par rareté (Commun … Légendaire). Plus cher qu'un coffre d'apparence de même rareté
## (Economy.SHOP_CHESTS : 150 / 300 / 600) puisqu'on choisit la pièce.
const PRICES := [120, 160, 220, 400, 700, 1000]

static var list: Array = []  # entrées de data/prp_looks.json, dans l'ordre de la table
static var _by_id := {}  # id texte (prp_… / back_prp_…) -> entrée de collection


## Lit la table et ajoute ses entrées aux tables de [param gd] (GameData). Appelé une fois, après les noms français.
static func install(gd: Node) -> void:
	list = []
	_by_id = {}
	if not FileAccess.file_exists(PATH):
		return
	var d = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if not d is Dictionary:
		return
	var backs: Array = []
	for e: Dictionary in d.get("looks", []):
		if not ResourceLoader.exists(String(e.model)):
			continue
		list.append(e)
		var x := {"id": int(e.num), "name": String(e.name), "icon": String(e.icon), "code": String(e.id),
			"rarity": int(e.rarity), "mall": false, "ord": 0, "prp": true}
		if String(e.slot) == "weapon":
			x["cat"] = 4
			x["skin"] = {"model": String(e.model), "texture": "", "wtype": String(e.get("wtype", ""))}
			gd.skin_by_code[String(e.id)] = x.skin
		else:
			x["cat"] = 2
			var cos := {"id": String(e.id), "cat": "back", "name": String(e.name), "icon": String(e.icon),
				"rarity": int(e.rarity), "outfit": String(e.model), "variants": [], "codes": [String(e.id)], "prp": true}
			backs.append(cos)
			gd.cosmetic_by_code[String(e.id)] = cos
		gd.collection.append(x)
		gd.collection_by_id[int(e.num)] = x
		_by_id[String(e.id)] = x
	# nos dos en tête de la liste (Héros > Apparence > Dos les montre avant les 160 d'origine)
	var cos_all: Array = gd.cosmetics
	gd.cosmetics = backs + cos_all


## Trésor de collection de la création [param id] (prp_… ou back_prp_…) ; {} si inconnue.
static func entry(id: String) -> Dictionary:
	return _by_id.get(id, {})


static func is_prp(x: Dictionary) -> bool:
	return x.has("prp")


## Prix en insignes d'une création (vitrine).
static func price(x: Dictionary) -> int:
	return int(PRICES[clampi(int(x.get("rarity", 0)), 0, PRICES.size() - 1)])


static func owned(x: Dictionary) -> bool:
	return Profile.collected(x)


static func can_buy(x: Dictionary) -> bool:
	return not owned(x) and Profile.insignia >= price(x) and not Profile.in_run


## Achète la création [param x] (trésor de collection) : insignes retirés, pièce débloquée. Renvoie vrai si c'est fait.
static func buy(x: Dictionary) -> bool:
	if not can_buy(x):
		return false
	Profile.insignia -= price(x)
	Profile.collect(x)
	Profile.changed.emit()
	Profile.save_profile()
	return true


## Les trésors de collection des créations (armes puis dos), pour la vitrine.
static func shop_entries() -> Array:
	var out: Array = []
	for slot in ["weapon", "back"]:
		for e in list:
			if String(e.slot) == slot and _by_id.has(String(e.id)):
				out.append(_by_id[String(e.id)])
	return out


## Ligne courte « Épée · Rare » d'une création.
static func kind_text(x: Dictionary) -> String:
	var kind := "Dos"
	if x.has("skin"):
		kind = String(GameData.weapon_type(String(x.skin.wtype)).get("name", "Arme"))
	return "%s · %s" % [kind, String(Items.RARITIES[clampi(int(x.get("rarity", 0)), 0, 5)].name)]
