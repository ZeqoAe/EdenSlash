extends Node
## Intégration (passe P4) : les sauvegardes des anciennes versions se chargent sans perte ni erreur.
## Formats anciens reconstruits ici : objets à stats figées sans uid, raretés anciennes, sans coffre (inventory + equipped),
## clés de sac d'avant 0.1.41, archive par type, coffres « trophée », sauvegarde d'avant le fil d'éveil, etc.
## (Un fichier de sauvegarde illisible n'est pas testé ici : le moteur écrit alors une ligne ERROR « Parse JSON failed » voulue.)
## Option : P4_REAL_SAVES=<dossier> charge aussi tous les profile*.json de ce dossier (lecture seule).
## godot --headless --path game res://tests/test_p4_migration.tscn

const PATH := "user://p4_legacy.json"

var fails := 0


func check(label: String, ok: bool) -> void:
	print(("OK    " if ok else "ÉCHEC ") + label)
	if not ok:
		fails += 1


func _ready() -> void:
	Settings.reset_all()
	Profile.selected_class = "warrior"
	Profile.reset_all()
	var main_path: String = Profile.save_path
	_test_v1()
	_test_vault_without_new_fields()
	_test_before_wakening_thread()
	_test_empty_and_broken()
	_test_night_fields()
	_test_hero_fields()
	var real := OS.get_environment("P4_REAL_SAVES")
	if real != "":
		_test_real_saves(real)
	Profile.save_path = main_path
	Profile.reset_all()
	Settings.reset_all()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
	print("\n%s (%d échec(s))" % ["TOUT EST OK" if fails == 0 else "ÉCHECS", fails])
	get_tree().quit(1 if fails > 0 else 0)


## Création de personnage (C1) : un profil d'avant n'a ni nom ni visage ; il garde tout le reste et la création lui sera proposée
## une fois ; enregistré puis relu, le nom et le visage tiennent.
func _test_hero_fields() -> void:
	_load({"selected_class": "warrior", "runs_done": 3, "outfits": {"warrior": "res://assets/player/outfits/l205_43413f.glb"}})
	check("C1 : profil d'avant sans nom ni visage, tenue gardée, création à proposer", Profile.hero_name == "" and HeroLook.is_default(Profile.hero_look)
		and HeroLook.needs_creation() and Profile.outfit_of("warrior").ends_with("l205_43413f.glb") and Profile.runs_done == 3)
	Profile.hero_name = "Kaelis"
	Profile.hero_look = {"hair": "l104", "hair_color": "red", "eyes": "amber"}
	Profile.hero_made = true
	Profile.save_profile()
	Profile._clear()
	Profile.load_profile()
	check("C1 : nom et visage relus après sauvegarde", Profile.hero_name == "Kaelis" and Profile.hero_look.hair == "l104" and Profile.hero_made)


## Charge [param d] comme le fait load_slot (profil vidé, chargé, vue du hub, équipement de départ).
func _load(d: Variant, raw := "") -> void:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	f.store_string(raw if raw != "" else JSON.stringify(d))
	f.close()
	Profile.save_path = PATH
	Profile._clear()
	Profile.load_profile()
	Profile._lobby_view()
	Profile._ensure_starter()


func _old_item(slot: String, level: int, rarity: int, stats: Dictionary) -> Dictionary:
	return {"slot": slot, "level": level, "rarity": rarity, "stats": stats, "name": "Vieil objet"}


func _item_ok(it: Dictionary) -> bool:
	return it.has("uid") and it.has("quality") and it.has("upgrade") and it.has("affixes") and not it.has("stats") and Items.stats(it) is Dictionary \
		and Items.stats(it).size() > 0


func _all_items() -> Array:
	var out: Array = Profile.vault.duplicate()
	return out


func _test_v1() -> void:
	# --- première génération : pas de coffre (inventory + equipped), stats figées, raretés 0-4, clés de sac anciennes ---
	var eq := {"weapon": _old_item("weapon", 6, 3, {"patk": 22.0, "crit": 0.03}), "chest": _old_item("chest", 5, 2, {"hp": 80.0, "def": 6.0})}
	var inv := []
	for i in 5:
		inv.append(_old_item(["head", "legs", "ring", "gloves", "boots"][i], 3 + i, i % 5, {"hp": 20.0 + i, "def": 2.0}))
	var d := {"selected_class": "warrior", "runs_done": 7, "best_level": 12, "unlocked_zones": 3,
		"expertise": {"warrior": 2500, "magician": 10}, "talents": {"warrior": {"1": 2}},
		"stash": {"luck": 2, "protect": 1, "drill": 4}, "equipped": eq, "inventory": inv, "crystals": 12,
		"archive": {"weapon_4": _old_item("weapon", 40, 4, {"patk": 60.0})},
		"reward_chests": [{"type": "trophy", "plevel": 10}, {"type": "gear", "plevel": 8}],
		"collection": [40416.0, 42084.0], "dev": {"enabled": true, "gold": 5, "keys": 1}}
	_load(d)
	check("v1 : chargée, classe, parties et record conservés", Profile.selected_class == "warrior" and Profile.runs_done == 7 and Profile.best_level == 12 and Profile.unlocked_zones == 3)
	check("v1 : maîtrise et talents conservés", Profile.expertise.get("warrior") == 2500 and Profile.expertise.get("magician") == 10 and not Profile.talents.is_empty())
	check("v1 : aucun objet perdu (7 anciens + le départ éventuel)", Profile.vault.size() >= 7)
	check("v1 : tous les objets sont au format actuel (uid, qualité, +N, affixes)", Profile.vault.all(_item_ok))
	check("v1 : l'ancien équipement est porté (arme et torse)", Profile.loadout.has("weapon") and Profile.loadout.has("chest"))
	check("v1 : l'arme est portée", Profile.equipped.has("weapon") and Profile.equipped.weapon.slot == "weapon")
	check("v1 : clés de sac renommées (chance, protection) et sommes gardées", Profile.stash.get("stone:lucky") == 2 and Profile.stash.get("stone:safety") == 1 and Profile.stash.get("drill") == 4 and not Profile.stash.has("luck"))
	check("v1 : coffre « trophée » devenu « set », l'autre intact", Profile.reward_chests.size() == 2 and Profile.reward_chests[0].type == "set" and Profile.reward_chests[1].type == "gear")
	check("v1 : cristaux repris dans les matières", Profile.amount("crystal") == 12)
	check("v1 : collection (nombres décimaux) devenue des textes", Profile.collection == ["40416", "42084"])
	check("v1 : classes déjà jouées restent débloquées", "magician" in Profile.unlocked_classes or "magician" in Progression.START_CLASSES)
	check("v1 : l'ancien interrupteur dev est repris par les Paramètres, puis éteint", bool(Settings.get_v("interface", "dev_mode")) and not bool(Profile.dev.enabled))
	Settings.set_v("interface", "dev_mode", false)
	check("v1 : compte qui a joué = activités d'avant le fil d'éveil ouvertes", Unlocks.is_open("survival") and Unlocks.is_open("tower") and Unlocks.is_open("forge") and Unlocks.is_open("collection"))
	check("v1 : activités nouvelles non ouvertes à tort", not Unlocks.is_open("royale") and not Unlocks.is_open("siege") and not Unlocks.is_open("pantheon"))
	check("v1 : une Survie démarre sur ce compte", _survival_ok())
	_roundtrip("v1")


func _survival_ok() -> bool:
	Run.start_survival(Profile.selected_class, 1)
	var ok := Run.active and Profile.equipped.size() >= 1
	Run.finish("defaite")
	Profile.end_run_survival()
	return ok and not Run.active


## Valeur comparable : nombres tous en flottants (le JSON relit 15 et 15.0 pareil), clés triées.
func _norm(v: Variant) -> String:
	return JSON.stringify(_numbers(v), "", true)


func _numbers(v: Variant) -> Variant:
	if v is int or v is float:
		return float(v)
	if v is Dictionary:
		var out := {}
		for k in v:
			out[String(k)] = _numbers(v[k])
		return out
	if v is Array:
		return v.map(_numbers)
	return v


## Compare une sauvegarde chargée et sa réécriture rechargée : rien ne change, rien ne se perd.
func _roundtrip(tag: String) -> void:
	var before := {"vault": Profile.vault.size(), "runs": Profile.runs_done, "ins": Profile.insignia, "exp": Profile.expertise.duplicate(true),
		"stash": Profile.stash.duplicate(true), "seen": Profile.seen_gear.size(), "loadout": Profile.loadout.duplicate(true),
		"chests": Profile.reward_chests.size(), "coll": Profile.collection.size(), "feat": Profile.unlocked_features.size(),
		"classes": Profile.unlocked_classes.size(), "records": Profile.records.size()}
	Profile.save_profile()
	var raw := FileAccess.get_file_as_string(PATH)
	var parsed = JSON.parse_string(raw)
	check("%s : réécrite en JSON valide" % tag, typeof(parsed) == TYPE_DICTIONARY)
	Profile._clear()
	Profile.load_profile()
	Profile._lobby_view()
	var after := {"vault": Profile.vault.size(), "runs": Profile.runs_done, "ins": Profile.insignia, "exp": Profile.expertise.duplicate(true),
		"stash": Profile.stash.duplicate(true), "seen": Profile.seen_gear.size(), "loadout": Profile.loadout.duplicate(true),
		"chests": Profile.reward_chests.size(), "coll": Profile.collection.size(), "feat": Profile.unlocked_features.size(),
		"classes": Profile.unlocked_classes.size(), "records": Profile.records.size()}
	var same := true
	for k in before:
		if _norm(before[k]) != _norm(after[k]):
			same = false
			print("   différence sur « %s » : %s -> %s" % [k, before[k], after[k]])
	check("%s : réécrite puis rechargée à l'identique" % tag, same)


func _test_vault_without_new_fields() -> void:
	# --- 2e génération : coffre commun, objets d'Eden (rv 2) sans niveau d'Eden, archive par type, sans uid sur certains objets ---
	var items := []
	for slot in ["weapon", "head", "chest", "legs", "gloves", "boots", "ring", "necklace"]:
		var it := Items.generate(8, 0.4, slot, "warrior")
		it.erase("uid")
		it.erase("quality")
		it.erase("rv")
		it["rarity"] = 2
		var st := Items.stats(it)
		it.erase("affixes")
		it.erase("upgrade")
		it["stats"] = st
		items.append(it)
	var d := {"selected_class": "magician", "vault": items, "loadout": {}, "presets": {}, "runs_done": 30, "insignia": 640, "seen_gear": [1, 2.0],
		"records": {"kills": 900.0, "duel_wins": 4.0}, "unlocked_classes": ["magician", "cleric"], "unlocked_zones": 4,
		"archive": {"weapon_3": Items.generate(30, 0.9, "weapon", "warrior", 3)}, "wheel": {"day": "2026-01-01", "used": 1}}
	_load(d)
	check("v2 : les 8 objets sont gardés et mis au format actuel", Profile.vault.size() >= 8 and Profile.vault.all(_item_ok))
	check("v2 : classe, insignes et records conservés", Profile.selected_class == "magician" and Profile.insignia == 640 and Profile.records.get("kills") == 900.0)
	check("v2 : pièces découvertes lues en entiers", Profile.seen_gear == [1, 2])
	check("v2 : la roue d'un ancien jour est remise à zéro au premier lancer", Wheel.free_left() == Wheel.FREE_PER_DAY)
	check("v2 : la classe choisie reçoit un équipement (vue du hub)", Profile.equipped.size() >= 1)
	check("v2 : une Survie démarre sur ce compte", _survival_ok())
	_roundtrip("v2")


func _test_before_wakening_thread() -> void:
	# --- sauvegarde d'avant le fil d'éveil / l'accueil / les succès : on part d'une sauvegarde actuelle et on retire les clés récentes ---
	Profile.reset_all()
	Profile.runs_done = 4
	Profile.insignia = 321
	Profile.expertise["warrior"] = 1200
	Profile.records["epochs_cleared"] = 1
	Profile.add_item(Items.generate(10, 0.8, "ring", "warrior"))
	Profile.save_profile()
	var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Profile.save_path))
	for k in ["unlocked_features", "new_features", "tutorial", "contracts", "achievements", "plans", "pantheon", "wheel", "insignia", "seen_gear",
			"weapon_legend", "extra_titles", "title", "seen_trophies", "unlocked_classes", "cert_board", "talents", "starter_done"]:
		d.erase(k)
	var n_items: int = d.vault.size()
	_load(d)
	check("avant le fil d'éveil : tous les objets du coffre sont là (%d)" % n_items, Profile.vault.size() >= n_items)
	check("avant le fil d'éveil : maîtrise, parties, records conservés", Profile.expertise.get("warrior") == 1200 and Profile.runs_done == 4 and Profile.records.get("epochs_cleared") == 1)
	check("avant le fil d'éveil : valeurs par défaut sûres (insignes 0, plateau de certificats à 7 cases)", Profile.insignia == 0 and Profile.cert_board.size() == CertBoard.POS.size())
	check("avant le fil d'éveil : le compte qui a joué garde Survie, Carnet et Coffres", Unlocks.is_open("survival") and Unlocks.is_open("collection") and Unlocks.is_open("chests"))
	check("avant le fil d'éveil : Succès et Tutoriel se lisent sans erreur", Achievements.refresh() is Array and Achievements.count().y > 0 and Completion.categories().size() > 0 and Completion.percent() >= 0)
	check("avant le fil d'éveil : une Survie démarre", _survival_ok())
	_roundtrip("avant éveil")
	# compte neuf (sans aucune partie) : rien d'ouvert à tort par la migration
	var fresh := {"selected_class": "warrior", "runs_done": 0}
	_load(fresh)
	check("sauvegarde presque vide : chargée, équipement de départ donné", Profile.equipped.size() == 8 or Profile.equipped.has("weapon"))
	check("sauvegarde presque vide : seules Survie et Entraînement sont ouvertes", Unlocks.is_open("survival") and Unlocks.is_open("training") and not Unlocks.is_open("forge") and not Unlocks.is_open("tower"))


func _test_empty_and_broken() -> void:
	# --- fichiers vides ou cassés : le jeu ne plante pas et garde un profil utilisable ---
	_load(null, "")  # (raw vide -> JSON.stringify(null) = "null")
	check("fichier « null » : profil neuf utilisable", Profile.vault.size() >= 1 and Profile.selected_class != "")
	_load({"selected_class": "classe_inconnue", "vault": [], "loadout": {"weapon": "uid_fantome"}, "expertise": {"classe_inconnue": 5}})
	check("classe inconnue et équipement fantôme : chargé sans erreur", Profile.vault.size() >= 0)
	Profile._lobby_view()
	check("classe inconnue : la vue du hub ne plante pas", true)
	Profile.selected_class = "warrior"
	Profile._lobby_view()


## Passe P18 : les champs ajoutés pendant la nuit du 15/10 (quêtes, Survivant, SafeFile) sur des sauvegardes d'avant eux.
func _test_night_fields() -> void:
	# --- sauvegarde de 0.1.185 (avant les quêtes et le Survivant) : rien de neuf dans records ---
	Profile.reset_all()
	Profile.runs_done = 12
	Profile.insignia = 777
	Profile.records["epochs_cleared"] = 2
	Profile.save_profile()
	var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Profile.save_path))
	(d.records as Dictionary).erase("quests")
	(d.records as Dictionary).erase("sv_rewards")
	_load(d)
	var st := Quests.state()
	check("avant les quêtes : parties, insignes, records gardés", Profile.runs_done == 12 and Profile.insignia == 777 and Profile.records.get("epochs_cleared") == 2)
	check("avant les quêtes : quêtes tirées pour aujourd'hui (%d du jour, %d de la semaine)" % [(st.daily as Array).size(), (st.weekly as Array).size()],
		String(st.day) == Quests.today() and (not Quests.enabled() or ((st.daily as Array).size() == Quests.DAILY and (st.weekly as Array).size() == Quests.WEEKLY)))
	check("avant le Survivant : palier I seul ouvert, aucune victoire", SurvivorRewards.wins(1) == 0 and not Survivor.palier_open(2, false))
	_roundtrip("avant quêtes")
	# --- quêtes d'un ancien jour, avec une quête retirée du jeu depuis : série et compteurs gardés, tirage neuf, rien ne plante ---
	d = JSON.parse_string(FileAccess.get_file_as_string(Profile.save_path))
	d.records["quests"] = {"day": "2026-01-01", "week": "2026-W01", "rerolled": true, "done": 12,
		"daily": [{"id": "quete_disparue", "t": 3, "p": 1, "done": false, "param": "", "r": {"insignia": 40}, "s": []}], "weekly": [],
		"series": {"n": 5, "last": "2025-12-31", "claimed": [3.0], "best": 5}}
	_load(d)
	st = Quests.state()
	var known: bool = (st.daily as Array).all(func(q): return not Quests.def_of(q).is_empty())
	check("quêtes d'un ancien jour : nouveau tirage, plus de quête inconnue, relance rendue", String(st.day) == Quests.today() and known and not bool(st.rerolled))
	check("quêtes d'un ancien jour : compteur et palier de série gardés", int(st.done) == 12 and int(st.series.best) == 5 and 3 in (st.series.claimed as Array).map(func(x): return int(x)))
	d.records.quests["day"] = Quests.today()
	d.records.quests["week"] = Quests.week_of(Quests.today())
	_load(d)
	var ins := Profile.insignia
	var done: Array = Quests.end_run("survival", true)
	check("quête inconnue du jour : fin de partie sans erreur ni récompense fantôme", done is Array and Profile.insignia == ins)
	# --- Survivant d'avant les paliers (S6) : la 1re victoire au palier I ouvre le palier II ---
	d = JSON.parse_string(FileAccess.get_file_as_string(Profile.save_path))
	d.records["sv_rewards"] = {"day": "2026-01-01", "today": ["time"], "first": ["time:1", "win:1"]}
	_load(d)
	check("Survivant d'avant les paliers : victoire comptée, palier II ouvert", SurvivorRewards.wins(1) == 1 and Survivor.palier_open(2, false) and not Survivor.palier_open(3, false))
	check("Survivant d'avant les paliers : récompense de victoire au palier I déjà prise", (SurvivorRewards.board(1)[2] as Dictionary).done)
	_roundtrip("Survivant S6")
	# --- coupure du jeu en plein Survivant : la sauvegarde écrite en pleine run garde la progression du hub, rien de la run ---
	Profile.reset_all()
	Profile.insignia = 500
	Profile.stash = {"drill": 3}
	Profile.reward_chests = []
	Profile.save_profile()
	var vault_n := Profile.vault.size()
	Survivor.start("warrior", "limestone", 1)
	Profile.insignia += 999
	Profile.records["kills"] = 123456
	Profile.reward_chests.append(Rewards.make("forge", 20, true))
	Profile.materials["crystal"] = 4000
	Profile.save_profile()  # (une sauvegarde en pleine run, puis le jeu est coupé)
	Run.active = false
	Run.survivor = false
	Run.survival = false
	Survivor.reset()
	ModeRules.modifiers = []
	Profile.in_run = false
	Profile._clear()
	Profile.load_profile()
	Profile._lobby_view()
	check("coupure en plein Survivant : insignes, cristaux, records, coffres et réserve du hub (%d ins., %d cr.)" % [Profile.insignia, Profile.amount("crystal")],
		Profile.insignia == 500 and Profile.amount("crystal") == 0 and not Profile.records.has("kills") and Profile.reward_chests.is_empty()
		and int(Profile.stash.get("drill", 0)) == 3)
	check("coupure en plein Survivant : coffre commun intact (%d -> %d)" % [vault_n, Profile.vault.size()], Profile.vault.size() == vault_n)
	# --- coupure en pleine écriture du profil : fichier principal tronqué -> dernière copie saine (.bak) ---
	Profile.insignia = 601
	Profile.save_profile()
	Profile.insignia = 602
	Profile.save_profile()  # .bak = 601, principal = 602
	var f := FileAccess.open(Profile.save_path, FileAccess.WRITE)
	f.store_string('{"insignia": 9')  # écriture coupée net
	f.close()
	SafeFile.notices = []
	Profile._clear()
	Profile.load_profile()
	check("profil tronqué : copie saine rechargée (%d insignes) et message prévu" % Profile.insignia, Profile.insignia == 601 and SafeFile.take_notice() != "")
	Profile.save_profile()
	check("profil tronqué : la sauvegarde suivante remet un fichier principal sain", SafeFile.json_ok(FileAccess.get_file_as_string(Profile.save_path)))
	Profile._remove_copies(Profile.save_path)


func _test_real_saves(dir_path: String) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		check("sauvegardes réelles : dossier lisible", false)
		return
	for f in dir.get_files():
		if not (f.begins_with("profile") and f.ends_with(".json")):
			continue
		var raw := FileAccess.get_file_as_string(dir_path.path_join(f))
		var d = JSON.parse_string(raw)
		if typeof(d) != TYPE_DICTIONARY:
			continue
		var n_raw := (d.get("vault", []) as Array).size() if d.has("vault") else (d.get("inventory", []) as Array).size() + (d.get("equipped", {}) as Dictionary).size()
		_load(d)
		check("réelle %s : coffre conservé (%d -> %d), objets au format actuel" % [f, n_raw, Profile.vault.size()], Profile.vault.size() >= n_raw and Profile.vault.all(_item_ok))
		check("réelle %s : insignes, maîtrise et parties identiques" % f, Profile.insignia == int(d.get("insignia", 0)) and Profile.runs_done == int(d.get("runs_done", 0))
			and (d.get("expertise", {}) as Dictionary).keys().all(func(k): return Profile.expertise.has(k)))
		check("réelle %s : une Survie démarre" % f, _survival_ok())
		_roundtrip("réelle " + f)
