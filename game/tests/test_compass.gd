extends Node
## Passe P6 : la quête commune se voit. La boussole du lobby (Compass) sur cinq états de compte, la ligne de quête des
## bilans, les gains des activités en pastilles (GainChips) et « où l'obtenir, où le dépenser » de chaque ressource.
## godot --headless --path game res://tests/test_compass.tscn

var fails := 0


func check(label: String, ok: bool) -> void:
	print(("OK    " if ok else "ÉCHEC ") + label)
	if not ok:
		fails += 1


func _reset() -> void:
	Settings.reset_all()
	Profile.reset_all()
	Profile.records[HeroLevel.KEY] = HeroLevel.total_for(HeroLevel.MAX_LEVEL)  # lot H3 : niveau 90, toutes les pièces se portent
	Profile.selected_class = "warrior"
	Profile._lobby_view()


func _ready() -> void:
	_test_states()
	_test_after()
	_test_resources()
	_test_activities()
	print("TOUT EST OK (0 échec(s))" if fails == 0 else "ÉCHECS : %d" % fails)
	get_tree().quit(fails)


## Pièces vues de l'Armurerie pour les emplacements manquants du Guerrier (au prix de leur palier).
func _see(slots: Array, epoch := 1) -> void:
	for box in slots:
		for it in SlotChests.offer(String(box), epoch, 1, 2):
			Profile.seen_gear.append(int(it.eden))


func _test_states() -> void:
	# 1. compte neuf : la première Survie
	_reset()
	var a := Compass.advice()
	check("1. compte neuf : première Survie (%s)" % a.get("id", "?"), String(a.get("id", "")) == "first_run" and a.go.get("menu", "") == "survival")
	check("1. le texte tient en une ligne courte (%d signes)" % String(a.text).length(), String(a.text).length() <= 50 and not String(a.text).contains("\n"))
	# 2. une Survie faite, des pièces vues, assez d'insignes : une pièce est achetable
	_reset()
	Profile.runs_done = 1
	_see(["head", "back", "weapon"])
	check("2. pièces vues : l'Armurerie est ouverte", Unlocks.is_open("armory"))
	Profile.insignia = 0
	a = Compass.advice()
	check("2. sans insignes : il manque une pièce → Survie (%s)" % a.get("id", "?"), String(a.get("id", "")) == "find_piece" and a.go.get("menu", "") == "survival")
	check("2. le texte nomme la classe et la pièce (%s)" % a.get("text", ""), String(a.text).begins_with("Guerrier : il te manque"))
	Profile.insignia = 5000
	a = Compass.advice()
	check("2. avec des insignes : une pièce est achetable (%s)" % a.get("id", "?"), String(a.get("id", "")) == "buy_piece" and a.go.get("workshop", -1) == 0)
	check("2. le texte donne les insignes (%s)" % a.get("text", ""), String(a.text).contains("5 000 insignes") and String(a.text).contains("à fabriquer"))
	# 3. des coffres à ouvrir (rien d'achetable)
	Profile.insignia = 0
	Profile.reward_chests.append(Rewards.make("gear", 20))
	Profile.reward_chests.append(Rewards.make("forge", 20))
	a = Compass.advice()
	check("3. coffres en attente → Coffres (%s)" % a.get("id", "?"), String(a.get("id", "")) == "chests" and bool(a.go.get("chests", false)) and String(a.text).begins_with("2 coffres"))
	# une pièce du coffre commun qui comble un emplacement : elle passe avant
	_reset()
	Profile.runs_done = 1
	_see(["head"])
	var spare := Items.generate(30, 0.9, "back", "warrior", Items.MYTHIC)
	Profile.vault.append(spare)
	Profile._lobby_view()
	a = Compass.advice()
	check("3b. une pièce t'attend dans le coffre commun → Équipement (%s)" % a.get("id", "?"), String(a.get("id", "")) == "equip_spare" and a.go.get("hero", "") == "equipment")
	# 4. classe équipée, époque I gagnée : la Forge (cristaux) puis les cristaux manquants
	_reset()
	Profile.runs_done = 6
	Profile.records["epochs_cleared"] = 1
	_see(["head"])
	_fill_gear()
	Profile.materials["crystal"] = 0
	a = Compass.advice()
	check("4. équipée, époque II ouverte : le conseil ne parle plus de pièces manquantes (%s)" % a.get("id", "?"),
		not String(a.get("id", "")) in ["find_piece", "first_run", "equip_spare", "buy_piece"])
	check("4. panoplie de donjon fermée : l'échelon du fil d'éveil (%s)" % a.get("id", "?"), String(a.get("id", "")) in ["ladder_dungeons", "crystals", "forge", "panoply", "ladder_forge"])
	Profile.records["epochs_cleared"] = 2
	a = Compass.advice()
	check("4. donjons ouverts : la panoplie mène à un donjon (%s)" % a.get("text", ""), String(a.get("id", "")) in ["panoply", "forge", "crystals"] and a.go.has("menu") or a.go.has("workshop"))
	Profile.materials["crystal"] = 9000
	var forge_id := String(Compass.advice().get("id", ""))
	check("4. des cristaux : une pièce peut monter ou la panoplie passe d'abord (%s)" % forge_id, forge_id in ["panoply", "forge"])
	# 5. compte avancé : tout à +10 est hors d'atteinte ici ; le fil d'éveil ou la classe suivante
	_reset()
	Profile.runs_done = 40
	Profile.records["epochs_cleared"] = 4
	Profile.records["duel_wins"] = 2
	_see(["head"])
	_fill_gear()
	for slot in Profile.equipped:
		Profile.equipped[slot]["upgrade"] = 10
	a = Compass.advice()
	check("5. compte avancé : un conseil existe (%s)" % a.get("id", "?"), not a.is_empty() and String(a.text) != "")
	# l'échelon suivant du fil d'éveil dit la condition
	var step := Compass.ladder_step("royale")
	check("5. échelon Ligue Argent → Battle royale (%s)" % step.get("text", ""), String(step.get("text", "")).contains("Ligue Argent") and String(step.text).contains("Battle royale"))
	var all_short := true
	for l in Compass.LADDER:
		if String(l[1]).length() > 54:
			all_short = false
			print("  trop long : ", l[1])
	check("5. chaque échelon tient en une ligne", all_short)
	# 6. la première heure sans impasse : achat → « équipe-la » → équipée → autre conseil
	_reset()
	Profile.runs_done = 1
	_see(["weapon", "weapon", "weapon", "weapon"])
	Profile.insignia = 400
	check("6. première heure : le conseil est l'achat", String(Compass.advice().get("id", "")) == "buy_piece")
	var e: Dictionary = {}
	for id in Profile.seen_gear:
		var cand: Dictionary = GameData.eden_by_id.get(int(id), {})
		if String(cand.get("slot", "")) == "weapon" and String(cand.get("wtype", "")) == Items.default_weapon_type("warrior"):
			e = cand
			break
	check("6. une arme du type du Guerrier est découverte", not e.is_empty())
	Profile.insignia -= GearShopPage.price(e)
	Profile.add_item(GearShopPage.make(e))
	Profile.save_profile()  # comme l'achat de l'Armurerie
	a = Compass.advice()
	check("6. achetée mais pas posée : le conseil mène à l'équipement (%s)" % a.get("id", "?"), String(a.get("id", "")) == "equip_spare" and a.go.get("hero", "") == "equipment")
	ClassGear.equip_best("warrior", false)
	a = Compass.advice()
	check("6. une fois posée, le conseil change (%s)" % a.get("id", "?"), String(a.get("id", "")) != "equip_spare")
	# en partie : pas de boussole
	Profile.in_run = true
	check("en partie : pas de conseil", Compass.advice().is_empty())
	check("au bilan : un conseil (ou la ligne seule)", not Compass.advice(true).is_empty())
	Profile.in_run = false


## Équipe le Guerrier de pièces fortes (comme un compte qui a joué).
func _fill_gear() -> void:
	Items.reward_zone = "wetlands"
	var gear := {}
	for slot in Items.SLOTS:
		var it := Items.generate(45, 0.9, slot, "warrior", Items.MYTHIC, "", Items.LEGENDARY)
		Profile.vault.append(it)
		gear[slot] = it
	Items.reward_zone = ""
	Profile.install_gear(gear)
	Profile._lobby_view()


func _test_after() -> void:
	_reset()
	Profile.runs_done = 3
	_see(["head"])
	var l := Compass.after("survival", {"unlocked": "Époque II", "seen": 3})
	check("bilan Survie : époque et plans découverts (%s)" % l, l.contains("Époque II") and l.contains("3 plans découverts") and not l.contains("Armurerie"))
	check("bilan Survie : deux gains, pas de suite (ligne courte)", not l.contains("›"))
	l = Compass.after("survival", {"seen": 2})
	check("bilan Survie : un seul gain, la suite suit (%s)" % l, l.contains("›"))
	l = Compass.after("dungeon", {"archetype": "storm", "crystals": 170, "plan": "plan_limestone"})
	check("bilan Donjon : plan puis panoplie, deux gains au plus (%s)" % l, l.contains("plan") and l.contains("panoplie") and l.contains("/ 6") and not l.contains("170 cristaux"))
	l = Compass.after("dungeon", {"crystals": 170})
	check("bilan Donjon : cristaux (%s)" % l, l.contains("170 cristaux"))
	l = Compass.after("tower", {"crystals": 1})
	check("bilan Tour : cristal au singulier (%s)" % l, l.contains("1 cristal ") or l.contains("1 cristal("))
	l = Compass.after("siege", {"formulas": true, "looks": 1})
	check("bilan Siège : formules et apparence (%s)" % l, l.contains("formules") and l.contains("apparence"))
	l = Compass.after("duel", {"spirit": true})
	check("bilan Panthéon : pièce des Esprits (%s)" % l, l.contains("Esprits"))
	l = Compass.after("royale", {"looks": 1})
	check("bilan Royale : apparence de prestige (%s)" % l, l.contains("prestige"))
	for mode in ["survival", "dungeon", "rush", "siege", "tower", "duel", "royale"]:
		var t := Compass.after(mode, {})
		check("bilan %s sans gain : une ligne ou rien, jamais de pourcentage" % mode, not t.contains("%") and not t.contains("\n"))
	var sp := ResultsScreen.new().spec()
	check("la description du bilan de Survie porte la clé « quest »", sp.has("quest"))


func _test_resources() -> void:
	for k in ResourceHelp.KINDS:
		var d: Dictionary = ResourceHelp.KINDS[k]
		check("ressource %s : nom, où l'obtenir, où la dépenser, icône" % k, String(d.name) != "" and String(d.get) != "" and String(d.spend) != "" and ResourceHelp.icon(String(k)) != null)
		check("ressource %s : aucune mention d'Eden, aucun pourcentage" % k, not ResourceHelp.tip(String(k)).contains("Eden") and not ResourceHelp.tip(String(k)).contains("%"))
	for key in [Craft.gem_key("ruby", 2), Craft.scroll_key("optimize", 3), Craft.fortify_key("power", 40), Craft.stone_key("safety")]:
		var t := Craft.describe_key(key)
		check("fourniture %s : où en trouver et à quoi ça sert" % key, t.contains("Où en trouver") and t.contains("À quoi ça sert"))
	check("une potion garde sa description sans ajout", not Craft.describe_key("potion:heal").contains("Où en trouver"))


func _test_activities() -> void:
	for a in Activities.LIST:
		var gives: Array = a.get("gives", [])
		var ok := true
		for k in gives:
			ok = ok and ResourceHelp.has(String(k))
		check("activité %s : ses gains sont des ressources connues (%d)" % [a.id, gives.size()], ok)
		if a.get("row", "") != "" and not a.get("soon", false):
			check("activité %s : au moins un gain affiché" % a.id, not gives.is_empty())
	var survie := Activities.get_def("survival")
	var chips := GainChips.icons(survie, 18)
	check("pastilles de la Survie : une icône par gain", chips != null and chips.get_child(0).get_child_count() == (survie.gives as Array).size())
	chips.free()
	var line := GainChips.line(Activities.get_def("dungeon"))
	check("ligne de la page Donjons : « Donne » et ses pastilles", line != null and line.get_child_count() == 1 + (Activities.get_def("dungeon").gives as Array).size())
	line.free()
	check("l'entraînement ne donne rien : pas de pastilles", GainChips.icons(Activities.get_def("training")) == null)
	check("le Siège est ouvert dès l'époque II (condition à jour)", Unlocks.condition("siege").begins_with("Gagne l'époque II") and not Unlocks.condition("siege").contains("puis atteins"))
