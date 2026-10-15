extends Node
## 0.1.164 : la Survie part avec l'équipement du hub. Compte neuf équipé, instantané et restauration
## (fin de run et reprise après fermeture), +N additif plafonné, gemmes suivant le niveau, économie des insignes :
## godot --headless --path game res://tests/test_gear_run.tscn

var fails := 0


func check(label: String, ok: bool) -> void:
	print(("OK    " if ok else "ÉCHEC ") + label)
	if not ok:
		fails += 1


func _uids(d: Dictionary) -> Array:
	var out: Array = []
	for s in d:
		out.append("%s:%s" % [s, d[s].uid])
	out.sort()
	return out


func _ready() -> void:
	Settings.reset_all()
	Profile.selected_class = "warrior"  # reset_all garde la classe du profil de test
	Profile.reset_all()
	# --- compte neuf : un équipement de départ correct, pas vide ----------------------------------
	var eq: Dictionary = Profile.equipped
	check("compte neuf : 8 emplacements équipés (%s)" % [eq.keys()], eq.size() == 8 and StarterGear.SLOTS.all(func(s): return eq.has(s)))
	check("compte neuf : pièces communes, spéciales ou rares", eq.values().all(func(it): return int(it.rarity) <= 2 and int(it.upgrade) == 0))
	check("compte neuf : l'arme est du type de la classe", Items.weapon_type_of(eq.weapon) == Items.default_weapon_type(Profile.selected_class))
	check("compte neuf : classe notée comme équipée", Profile.selected_class in Profile.starter_done)
	var st := Profile.equipment_stats()
	check("compte neuf : l'équipement apporte des PV, de l'attaque et de la défense", float(st.get("hp", 0)) > 50.0 and float(st.get("patk", 0)) > 5.0 and float(st.get("def", 0)) > 2.0)
	# une autre classe reçoit son propre équipement, la 1re garde le sien
	var first := _uids(Profile.equipped)
	Profile.selected_class = "magician"
	Profile.save_profile()
	check("2e classe : équipement de départ de son type d'arme", Profile.equipped.size() == 8 and Items.weapon_type_of(Profile.equipped.weapon) == Items.default_weapon_type("magician"))
	Profile.selected_class = "warrior"
	Profile.save_profile()
	check("la 1re classe garde son équipement", _uids(Profile.equipped) == first)
	var n_vault := Profile.vault.size()
	Profile.selected_class = "magician"
	Profile.save_profile()
	Profile.selected_class = "warrior"
	Profile.save_profile()
	check("équipement de départ remis une seule fois par classe", Profile.vault.size() == n_vault)

	# --- départ de la run : copies de l'équipement du hub ---------------------------------------
	var hub_uids := _uids(Profile.equipped)
	var hub_vault := Profile.vault.duplicate(true)
	Run.start_survival("warrior", 1)
	check("Survie : équipement du hub porté au départ", _uids(Profile.equipped) == hub_uids)
	check("Survie : ce sont des copies (le coffre n'est pas touché)", not is_same(Profile.equipped.chest, Profile.vault[Profile.vault.map(func(i): return i.uid).find(Profile.equipped.chest.uid)]))
	check("Survie : or, clés et sac à zéro", Profile.gold == 0 and Profile.keys == 0 and Profile.inventory.is_empty())
	check("Survie : pas d'arme secondaire au hub, défi « sans arme secondaire » intact", not Run.offhand_used)
	Run.hero_level = 5
	check("Survie : l'équipement du hub compte dans les stats", float(Profile.equipment_stats().get("hp", 0)) > 50.0)

	# --- trouvailles de la run : remplacent un emplacement, jamais durablement -----------------------
	var offer := SlotChests.offer("head", 1, 1, 3)
	var found: Dictionary = offer[0]
	Run.apply_card({"type": "gear", "item": found})
	check("coffre : la pièce trouvée est portée tout de suite", String(Profile.equipped.head.uid) == String(found.uid) and int(found.eden) in Run.seen_items)
	Profile.equipped.chest["upgrade"] = 9  # forge, enchantement… de la copie de la run
	Run.slot_bonus["boots"] = 4
	Profile.vault.append(Items.generate(1, 0.0, "ring"))  # (piège) quelque chose écrit dans le coffre en pleine run
	Profile.save_profile()
	# fermeture du jeu en pleine run : la sauvegarde ne contient que l'équipement du hub
	var disk: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Profile.save_path))
	var disk_chest_up := 0
	for it in disk.vault:
		if String(it.uid) == String(hub_uids.filter(func(x): return String(x).begins_with("chest:"))[0]).trim_prefix("chest:"):
			disk_chest_up = int(it.upgrade)
	check("sauvegarde en pleine run : la pièce du hub est restée à +0 (pas le +9 de la copie)", disk_chest_up == 0)
	Run.finish("defaite")
	Profile.end_run_survival()
	check("fin de run : l'équipement du hub est restauré tel quel", _uids(Profile.equipped) == hub_uids)
	var vh := {}
	for it in Profile.vault:
		vh[String(it.uid)] = it.hash()
	var hh := {}
	for it in hub_vault:
		hh[String(it.uid)] = it.hash()
	check("fin de run : le coffre est restauré (rien d'ajouté, rien changé)", Profile.vault.size() == hub_vault.size() and vh == hh)
	check("fin de run : la pièce du coffre de la run n'est pas gardée, mais achetable (seen_gear)", int(found.eden) in Profile.seen_gear and not GearShopPage.owned(int(found.eden)))

	# reprise : le jeu a été fermé pendant une run (pas de fin propre)
	Run.start_survival("warrior", 1)
	Run.apply_card({"type": "gear", "item": SlotChests.offer("legs", 1, 1, 3)[0]})
	Profile.equipped.weapon["upgrade"] = 7
	Profile.save_profile()
	Profile.in_run = false
	Profile.load_profile()
	check("reprise après fermeture : équipement du hub, pièces à leur +N d'avant", _uids(Profile.equipped) == hub_uids and int(Profile.equipped.weapon.upgrade) == 0)
	Run.active = false
	Run.survival = false

	# --- +N : l'enclume s'ajoute, plafond ---------------------------------------------------------------
	Run.start_survival("warrior", 1)
	Run.slot_bonus = {"weapon": 7, "head": 3, "chest": 0}
	check("+N : +10 du hub et enclume +7 : plafonné à +%d" % Run.UPGRADE_CAP, Run.slot_upgrade(10, "weapon") == Run.UPGRADE_CAP)
	check("+N : +0 du hub et enclume +3 : +3", Run.slot_upgrade(0, "head") == 3)
	check("+N : sans bonus d'enclume, le +N du hub", Run.slot_upgrade(6, "legs") == 6)
	var w: Dictionary = Profile.equipped.weapon
	w["upgrade"] = 4
	Run.hero_level = 10
	Run.slot_bonus.erase("weapon")
	var base := float(Profile.equipment_stats().get("patk", 0))
	Run.slot_bonus["weapon"] = 6
	var boosted := float(Profile.equipment_stats().get("patk", 0))
	check("+N : l'enclume s'ajoute au +4 de l'arme (%.0f → %.0f)" % [base, boosted], boosted > base * 1.1)
	for i in 400:
		Run.anvil_roll("head")
		check_roll(Run.slot_bonus.head)
	check("enclume : tirage entre +0 et +7 (400 tirages)", _roll_ok)
	check("enclume : le tirage remplace le précédent (pas de cumul)", int(Run.slot_bonus.head) <= 7)

	# --- gemmes : leurs valeurs plates suivent le niveau du héros en Survie ------------------------
	var item := {"slot": "chest", "sockets": [{"type": "garnet", "tier": 3}]}
	Run.hero_level = 1
	var g1 := float(Craft.extra_stats(item).hp)
	Run.hero_level = 15
	var g15 := float(Craft.extra_stats(item).hp)
	Run.hero_level = 35
	var g35 := float(Craft.extra_stats(item).hp)
	check("gemme parfaite au niveau 1 / 15 / 35 : %.0f < %.0f < %.0f PV" % [g1, g15, g35], g1 < g15 and g15 < g35 and is_equal_approx(g15, 220.0) and g1 > 60.0 and g35 <= 441.0)
	var crit_item := {"slot": "ring", "sockets": [{"type": "amethyst", "tier": 2}]}
	Run.hero_level = 1
	check("gemme de critique (en %) : non normalisée", is_equal_approx(float(Craft.extra_stats(crit_item).crit), 0.035))
	Run.active = false
	Run.survival = false
	check("hors run : gemme à pleine valeur", is_equal_approx(float(Craft.extra_stats(item).hp), 220.0))

	# --- économie des insignes -----------------------------------------------------------------------------
	Profile.insignia = 0
	Run.start_survival("warrior", 1)
	Run.kills = 40
	Run.elites = 1
	Run.stage = 1
	Run.finish("defaite")
	var defeat_gain := Run.insignia_gain
	var cheapest := 9999
	for e in SlotChests.pool("head", 1, 1) + SlotChests.pool("chest", 1, 1):
		cheapest = mini(cheapest, GearShopPage.price(e))
	check("une défaite (1re map, 40 tués) rapporte %d insignes : de quoi acheter une pièce de la 1re map (%d)" % [defeat_gain, cheapest], defeat_gain >= cheapest)
	Profile.end_run_survival()

	Profile.reset_all()
	print("\n%d échec(s)" % fails)
	get_tree().quit(1 if fails > 0 else 0)


var _roll_ok := true


func check_roll(v: int) -> void:
	if v < 0 or v > 7:
		_roll_ok = false
