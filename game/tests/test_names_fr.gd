extends Node
## Noms français (0.1.165, lot U10) : data/names_fr.json appliqué au chargement de GameData.
## Aucun nom proposé en coffre / à l'Armurerie / en équipement de départ ne contient de mot anglais courant,
## les identifiants et les noms d'origine sont intacts, les anciennes sauvegardes sont traduites :
## godot --headless --path game res://tests/test_names_fr.tscn

var fails := 0

## Liste de contrôle : mots anglais courants des noms d'Eden qui ne sont pas des mots français.
const ENGLISH := ["the", "of", "and", "sword", "axe", "bow", "boots", "gloves", "gauntlets", "bracers", "helmet", "crown", "cloak",
	"belt", "necklace", "armor", "shield", "staff", "wand", "blade", "hammer", "mace", "dagger", "pistol", "gun",
	"dark", "holy", "fire", "flame", "ice", "storm", "spirit", "soul", "blood", "heart", "eagle", "wolf", "king",
	"queen", "knight", "knights", "light", "shadow", "death", "star", "moon", "sun", "ancient", "eternal", "sacred",
	"cursed", "accursed", "awaken", "ascended", "corrupted", "guardian", "battle", "steel", "iron", "gold",
	"golden", "silver", "leather", "feather", "wing", "wings", "thunder", "lightning", "wind", "sky", "demon", "devil",
	"angel", "magic", "mystic", "great", "ring", "hat", "tunic", "vestment", "greaves", "shoes", "mask", "serial",
	"number","mushroid", "turtle", "crab", "forest", "mtn", "bay", "peak", "volcano", "wilds", 
	"warrior", "hunter", "wizard", "witch", "priest", "soldier", "guard", "giant", "lily", "owl",
	"wanderer", "exile", "spider", "snake", "rock", "stone", "crystal", "power", "wrath", "fury", "anger"]


func check(label: String, ok: bool) -> void:
	print(("OK    " if ok else "ÉCHEC ") + label)
	if not ok:
		fails += 1


func _english_in(s: String) -> String:
	var clean := s.to_lower()
	for ch in ["'", "’", "(", ")", ":", ",", "-", "."]:
		clean = clean.replace(ch, " ")
	for w in clean.split(" ", false):
		if w in ENGLISH:
			return w
	return ""


func _ready() -> void:
	var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/eden_catalog.json"))
	var raw_items: Array = raw.items
	# --- la table existe et couvre toutes les sections --------------------------------------------
	var t := NamesFr.table()
	check("table : sections items, monsters, zones, sets, cosmetics, collection remplies",
		["items", "monsters", "zones", "sets", "cosmetics", "collection"].all(func(k): return (t.get(k, {}) as Dictionary).size() > 10))
	# --- identifiants et noms d'origine intacts ---------------------------------------------------
	var same_ids := GameData.eden_items.size() == raw_items.size()
	if same_ids:
		for i in raw_items.size():
			var e: Dictionary = GameData.eden_items[i]
			if int(e.id) != int(raw_items[i].id) or String(e.get("name_en", "")) != String(raw_items[i].name) or String(e.code) != String(raw_items[i].code):
				same_ids = false
				break
	check("%d équipements : mêmes identifiants et codes, nom d'origine gardé dans name_en" % raw_items.size(), same_ids)
	check("eden_by_id : toujours indexé par les mêmes identifiants", GameData.eden_by_id.has(int(raw_items[0].id)) and GameData.eden_by_id.size() > 5000)
	var mons: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/monsters.json"))
	check("monstres : mêmes identifiants", GameData.monsters.size() == mons.size() and mons.keys().all(func(k): return GameData.monsters.has(int(k))))
	var raw_zones: Array = JSON.parse_string(FileAccess.get_file_as_string("res://data/zones.json"))
	check("zones : mêmes identifiants", GameData.zones.size() == raw_zones.size() and raw_zones.all(func(z): return GameData.zone(z.id).id == z.id))
	# --- zones, donjons, monstres -----------------------------------------------------------------
	var bad_zone := ""
	for z: Dictionary in GameData.zones:
		for n in [String(z.name), String(z.get("dungeon", {}).get("name", ""))]:
			if _english_in(n) != "":
				bad_zone = n
	check("8 zones et leurs donjons : aucun mot anglais (%s)" % bad_zone, bad_zone == "" and GameData.zones.size() == 8)
	check("zone : « Monts Calcaires »", String(GameData.zones[0].name) == "Monts Calcaires" and String(GameData.zones[0].name_en) == "Limestone Mtn.")
	var bad_m := ""
	for id in GameData.monsters:
		var n := String(GameData.monsters[id].name)
		if _english_in(n) != "" or n.contains("<"):
			bad_m = n
	check("monstres et boss : aucun mot anglais ni « <Titre> » (%s)" % bad_m, bad_m == "")
	# --- équipement proposé : mythiques, légendaires, éveillées, trophées, pièces de panoplie ----------
	var checked := 0
	var bad := ""
	for e in GameData.eden_items:
		if int(e.rarity) >= Items.MYTHIC or GameData.is_awakened(e):
			checked += 1
			var w := _english_in(String(e.name))
			if w != "" and bad == "":
				bad = "%s (%s : %s)" % [e.name, e.name_en, w]
	check("%d pièces mythiques / légendaires / éveillées : aucun mot anglais courant %s" % [checked, bad], bad == "" and checked > 3000)
	var bad_set := ""
	for sid in GameData.eden_sets:
		var n := String(GameData.eden_sets[sid].name)
		var w := _english_in(n)
		if w != "" and bad_set == "":
			bad_set = "%s (%s)" % [n, w]
	check("%d panoplies d'Eden : aucun mot anglais courant %s" % [GameData.eden_sets.size(), bad_set], bad_set == "")
	# pièces réellement proposées par les coffres d'emplacement de toutes les époques
	var offered := 0
	var bad_off := ""
	for epoch in range(1, 5):
		for stage in range(1, 4):
			for box in ["weapon", "head", "chest", "legs", "gloves", "boots", "jewel", "trophy"]:
				for e in SlotChests.pool(box, epoch, stage):
					offered += 1
					var w := _english_in(String(e.name))
					if w != "" and bad_off == "":
						bad_off = "%s (%s)" % [e.name, w]
	check("coffres d'emplacement (époques 1-4, cartes 1-3) : %d propositions sans mot anglais %s" % [offered, bad_off], bad_off == "" and offered > 50)
	# pièces de départ des 60 classes
	var bad_start := ""
	for cid in GameData.classes:
		var s := StarterGear.items(String(cid))
		for slot in s:
			var w := _english_in(String(s[slot].name))
			if w != "" and bad_start == "":
				bad_start = "%s (%s)" % [s[slot].name, w]
	check("pièces de départ des %d classes : aucun mot anglais %s" % [GameData.classes.size(), bad_start], bad_start == "")
	# --- éveillées : détection par le nom d'origine -----------------------------------------------
	var awake_raw := raw_items.filter(func(e): return String(e.name).begins_with("Awaken ")).size()
	var awake_gd := GameData.eden_items.filter(func(e): return GameData.is_awakened(e)).size()
	check("pièces éveillées : %d détectées comme avant (%d)" % [awake_gd, awake_raw], awake_gd == awake_raw and awake_raw >= 60)
	check("éveillée : nom français lisible", GameData.eden_items.filter(func(e): return GameData.is_awakened(e)).all(func(e): return String(e.name).contains("éveillé")))
	# --- nettoyage : plus de tirets parasites ni de mentions de version --------------------------------
	var dirty := ""
	for e in GameData.eden_items:
		var n := String(e.name)
		if n.contains("- ") or n.contains("Serial Number") or n.contains("Version") or n.contains("  "):
			dirty = n
			break
	check("noms d'équipement propres (pas de « - », « Serial Number », « Version », double espace) %s" % dirty, dirty == "")
	var dirty_c := ""
	for c in GameData.collection:
		var n := String(c.name)
		if n.contains("Serial Number") or n.contains(" Ver.") or n.contains("  "):
			dirty_c = n
			break
	check("noms de la collection propres %s" % dirty_c, dirty_c == "")
	check("clean : « Temple Knights- Gloves Serial Number »", NamesFr.clean("Temple Knights- Gloves Serial Number") == "Temple Knights Gloves")
	# --- anciennes sauvegardes : l'objet garde son nom anglais -> traduit au chargement ---------------
	var sample: Dictionary = raw_items.filter(func(e): return int(e.rarity) == 5 and String(e.slot) == "gloves")[0]
	var old := {"name": String(sample.name), "eden": int(sample.id), "slot": "gloves"}
	NamesFr.fix_item(old)
	check("ancienne sauvegarde : « %s » -> « %s »" % [sample.name, old.name], old.name == String(GameData.eden_by_id[int(sample.id)].name) and old.name != sample.name)
	var mine := {"name": "Potion de rage", "slot": "weapon"}
	NamesFr.fix_item(mine)
	check("un nom déjà français ne bouge pas", mine.name == "Potion de rage")
	# --- affichage : Items.display_name sur un objet neuf ------------------------------------------
	var it := Items.from_template(GameData.eden_by_id[int(sample.id)], 50, 5)
	check("objet neuf : display_name = nom français", Items.display_name(it) == String(GameData.eden_by_id[int(sample.id)].name) and _english_in(Items.display_name(it)) == "")
	# --- table modifiable à la main : « overrides » gagne sur le reste --------------------------------
	var t2 := NamesFr.table()
	var saved: Variant = t2.get("overrides", {})
	t2["overrides"] = {"Rage Battle Axe": "Hache de rage (test)"}
	check("overrides : prioritaires", NamesFr.lookup("items", "Rage Battle Axe") == "Hache de rage (test)")
	t2["overrides"] = saved
	check("nom absent de la table : repli sur le nom nettoyé", NamesFr.lookup("items", "Foo- Bar Version") == "Foo Bar")
	# --- aperçu pour la relecture : 100 noms parmi les pièces proposées en coffre (toutes époques) ----
	var seen := {}
	var pairs: Array = []
	for epoch in range(1, 5):
		for stage in range(1, 4):
			for box in ["weapon", "head", "chest", "legs", "gloves", "boots", "jewel", "trophy"]:
				for e in SlotChests.pool(box, epoch, stage):
					if not seen.has(int(e.id)):
						seen[int(e.id)] = true
						pairs.append("%s => %s" % [e.name_en, e.name])
	var lines: Array = []
	var step := maxi(pairs.size() / 100, 1)
	for i in range(0, pairs.size(), step):
		lines.append(pairs[i])
	print("--- aperçu (%d pièces uniques proposées, 1 sur %d) ---
" % [pairs.size(), step], "
".join(lines))
	print("")
	print("TOUT OK" if fails == 0 else "%d ÉCHEC(S)" % fails)
	get_tree().quit(1 if fails > 0 else 0)
