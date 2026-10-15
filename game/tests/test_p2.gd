extends Node
## Passe P2 (performances) : chaque optimisation garde son comportement et son gain.
## godot --headless --path game res://tests/test_p2.tscn

var fails := 0


func check(label: String, ok: bool) -> void:
	print(("OK    " if ok else "ÉCHEC ") + label)
	if not ok:
		fails += 1


func _ready() -> void:
	Training.active = true  # aucune sauvegarde écrite
	Settings.reset_all()
	Profile.reset_all()
	Profile.in_run = false
	_test_index()
	_test_safe_file()
	await _test_armory()
	await _test_item_slot()
	await _test_settings_lazy()
	await _test_registry_skip()
	await _test_collection_memo()
	await _test_backdrop_minimap()
	_test_boot_marks()
	await _test_toon_cache()
	await _test_player_weapon()
	print("TOUT EST OK (0 échec(s))" if fails == 0 else "ÉCHECS : %d" % fails)
	get_tree().quit(fails)


# --- Profile.collected / outfit_unlocked : index au lieu d'un parcours complet ---------------------------------
func _test_index() -> void:
	var x: Dictionary = GameData.collection[0]
	check("collection vide : rien d'obtenu", not Profile.collected(x))
	Profile.collect(x)
	check("collect() puis collected() : obtenu", Profile.collected(x) and Profile.collection.has(str(int(x.id))))
	Profile.collect(x)
	check("collect() deux fois : une seule entrée", Profile.collection.count(str(int(x.id))) == 1)
	Profile.collection = []  # le tableau est remplacé (chargement, réinitialisation) : l'index suit
	Profile.owned_outfits = []  # (une apparence est aussi obtenue si sa tenue est débloquée)
	check("tableau remplacé : plus obtenu", not Profile.collected(x))
	Profile.collection = [str(int(x.id))]
	check("tableau remplacé par un autre qui le contient : obtenu", Profile.collected(x))
	Profile.collection.append("999999")  # ajout direct (ancien code, tests) : détecté par la taille
	var fake := {"id": 999999}
	check("ajout direct au tableau : vu", Profile.collected(fake))
	Profile.owned_outfits = []
	check("tenue absente", not Profile.outfit_unlocked("zzz"))
	Profile.unlock_outfit("zzz")
	Profile.unlock_outfit("zzz")
	check("tenue débloquée une seule fois", Profile.outfit_unlocked("zzz") and Profile.owned_outfits.count("zzz") == 1)
	# vidage en place puis nouvel ajout : l'index ne garde pas l'ancien contenu
	var plain: Array = GameData.collection.filter(func(e): return int(e.get("cat", 0)) > 3)
	if plain.size() >= 2:
		Profile.collection = []
		Profile.collect(plain[0])
		Profile.collection.clear()
		Profile.collect(plain[1])
		check("collection vidée en place : l'ancien trésor n'est plus vu, le nouveau l'est", not Profile.collected(plain[0]) and Profile.collected(plain[1]))
		Profile.collection = []
	# vitesse : tout le catalogue contre une collection de 3 000 trésors (avant : un parcours complet par entrée)
	var big: Array = []
	for i in 3000:
		big.append(str(500000 + i))
	Profile.collection = big
	var t := Time.get_ticks_usec()
	var hits := 0
	for e in GameData.collection:
		if Profile.collected(e):
			hits += 1
	var ms := float(Time.get_ticks_usec() - t) / 1000.0
	print("      %d entrées contre 3 000 obtenues : %.1f ms" % [GameData.collection.size(), ms])
	check("collected() sur tout le catalogue : moins de 150 ms", ms < 150.0)
	Profile.collection = []
	Profile.owned_outfits = []


# --- sauvegarde atomique : .tmp relu, .bak gardé, repli sur fichier tronqué ----------------------------------------------
func _truncate(path: String) -> void:
	var t := FileAccess.get_file_as_string(path)
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(t.left(t.length() / 2))
	f.close()


func _cleanup(path: String) -> void:
	for ext in ["", ".tmp", ".bak"]:
		if FileAccess.file_exists(path + ext):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path + ext))


func _test_safe_file() -> void:
	var p := "user://p2_safe_test.json"
	_cleanup(p)
	check("SafeFile : écriture ok", SafeFile.write(p, '{"a": 1}') and FileAccess.get_file_as_string(p) == '{"a": 1}')
	check("SafeFile : pas de .tmp laissé", not FileAccess.file_exists(p + ".tmp") and not FileAccess.file_exists(p + ".bak"))
	SafeFile.write(p, '{"a": 2}')
	check("SafeFile : 2e écriture, l'ancien fichier est gardé en .bak", FileAccess.get_file_as_string(p + ".bak") == '{"a": 1}' and SafeFile.read(p) == '{"a": 2}')
	_truncate(p)
	SafeFile.notices = []
	check("SafeFile : fichier tronqué, repli sur la copie saine", SafeFile.read(p) == '{"a": 1}')
	check("SafeFile : le repli est signalé une fois", SafeFile.take_notice() != "" and SafeFile.take_notice() == "")
	SafeFile.write(p, '{"a": 3}')  # le fichier tronqué n'écrase pas la bonne copie
	check("SafeFile : écriture après un fichier tronqué, .bak toujours sain", SafeFile.json_ok(FileAccess.get_file_as_string(p + ".bak")) and SafeFile.read(p) == '{"a": 3}')
	DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
	var f := FileAccess.open(p + ".tmp", FileAccess.WRITE)
	f.store_string('{"a": 4}')
	f.close()
	SafeFile.notices = []
	check("SafeFile : coupure entre le .tmp et le renommage, le .tmp est lu sans alerte", SafeFile.read(p) == '{"a": 4}' and SafeFile.take_notice() == "")
	_truncate(p + ".tmp")
	check("SafeFile : .tmp tronqué mais .bak sain, repli sur .bak", SafeFile.json_ok(SafeFile.read(p)))
	_truncate(p + ".bak")
	check("SafeFile : tout est abîmé, texte vide (nouvelle partie)", SafeFile.read(p) == "")
	check("SafeFile : « null » n'est pas une sauvegarde", not SafeFile.json_ok("null") and not SafeFile.json_ok(""))
	_cleanup(p)
	# Profile : un profil tronqué revient à la dernière sauvegarde saine
	Training.active = false
	var old_path := Profile.save_path
	var test_path := "user://p2_profile.json"
	_cleanup(test_path)
	Profile.save_path = test_path
	Profile.insignia = 4242
	Profile.save_profile()
	Profile.insignia = 4343
	Profile.save_profile()
	_truncate(test_path)
	Profile.insignia = 0
	SafeFile.notices = []
	Profile.load_profile()
	check("Profile : fichier tronqué, la sauvegarde précédente est rechargée (4242)", Profile.insignia == 4242)
	check("Profile : un message sobre est prévu", SafeFile.take_notice().contains("sauvegarde"))
	Profile.save_profile()  # la sauvegarde suivante répare le fichier principal
	Profile.insignia = 0
	Profile.load_profile()
	check("Profile : après une nouvelle sauvegarde, le fichier principal est sain", SafeFile.json_ok(FileAccess.get_file_as_string(test_path)) and Profile.insignia == 4242)
	_cleanup(test_path)
	Profile.save_path = old_path
	# réglages
	var old_s := Settings.save_path
	var sp := "user://p2_settings.cfg"
	_cleanup(sp)
	Settings.save_path = sp
	Settings.set_v("audio", "music", 0.31)
	Settings.set_v("audio", "music", 0.42)
	_truncate(sp)
	Settings.set_v("audio", "music", 0.9)  # en mémoire seulement (le set_v ré-enregistre) : on relit donc la copie
	_cleanup(sp)
	FileAccess.open(sp + ".bak", FileAccess.WRITE).store_string("[audio]

music=0.31
")
	Settings.load_settings()
	check("Réglages : fichier absent mais .bak sain, réglages relus", is_equal_approx(float(Settings.get_v("audio", "music")), 0.31))
	_cleanup(sp)
	Settings.save_path = old_s
	Settings.reset_all()
	Training.active = true



# --- Armurerie : cache disque, tranches, même résultat que le calcul direct ---------------------------------------
func _reference_armory() -> Dictionary:
	# l'algorithme d'avant P2, mot pour mot (un type de classe par type d'arme, Profile._view_class)
	var out := {}
	var by_type := {}
	for cid in GameData.classes:
		by_type[Items.default_weapon_type(String(cid))] = String(cid)
	var saved := Profile._view_class
	for ep in range(1, Epochs.count() + 1):
		for stage in range(1, 4):
			for box in SlotChests.BOXES:
				if SlotChests.is_cards(box) or box == "trophy":
					continue
				for cid in (by_type.values() if box == "weapon" else [by_type.values()[0]]):
					Profile._view_class = String(cid)
					for e in SlotChests.pool(box, ep, stage):
						if not out.has(int(e.id)):
							out[int(e.id)] = ep
	Profile._view_class = saved
	return out


func _test_armory() -> void:
	var ref := _reference_armory()
	DirAccess.remove_absolute(Completion.ARMORY_CACHE)
	Completion._armory_ids = {}
	Completion._armory_jobs = []
	var t := Time.get_ticks_usec()
	var cold := Completion.armory_ids()
	var cold_ms := float(Time.get_ticks_usec() - t) / 1000.0
	print("      Armurerie : cache avant calcul %s, résultat %d pièces, référence %d" % [str(FileAccess.file_exists(Completion.ARMORY_CACHE)), cold.size(), ref.size()])
	check("Armurerie : même catalogue que le calcul d'avant (%d pièces)" % ref.size(), cold == ref and ref.size() > 100)
	check("Armurerie : cache écrit sur disque", FileAccess.file_exists(Completion.ARMORY_CACHE))
	Completion._armory_ids = {}
	t = Time.get_ticks_usec()
	var warm := Completion.armory_ids()
	var warm_ms := float(Time.get_ticks_usec() - t) / 1000.0
	print("      Armurerie : calcul %.0f ms, depuis le cache %.1f ms" % [cold_ms, warm_ms])
	check("Armurerie : relu depuis le cache, identique", warm == ref)
	check("Armurerie : le cache est au moins 10 fois plus rapide", warm_ms * 10.0 < cold_ms)
	# cache d'une autre version : ignoré et recalculé
	var f := FileAccess.open(Completion.ARMORY_CACHE, FileAccess.WRITE)
	f.store_string(JSON.stringify({"key": "autre version", "ids": {"1": 1}}))
	f.close()
	Completion._armory_ids = {}
	check("Armurerie : cache d'une autre version ignoré", Completion.armory_ids() == ref)
	# calcul par tranches pendant l'affichage, interrompu par un appel direct
	DirAccess.remove_absolute(Completion.ARMORY_CACHE)
	Completion._armory_ids = {}
	Completion._armory_jobs = []
	Completion.warm_armory()
	await get_tree().process_frame
	check("Armurerie : le calcul par tranches a commencé sans tout faire d'un coup", Completion._armory_next > 0)
	check("Armurerie : un appel direct termine le travail, même résultat", Completion.armory_ids() == ref)
	for i in 3:
		await get_tree().process_frame
	check("Armurerie : la tranche en cours ne refait rien après coup", Completion._armory_jobs.is_empty() and Completion.armory_ids() == ref)


# --- cases d'objet : plus de redessin à chaque image ----------------------------------------------------------------
func _test_item_slot() -> void:
	var host := Control.new()
	add_child(host)
	var a := ItemWidgets.ItemSlot.new(64.0)
	var b := ItemWidgets.ItemSlot.new(64.0)
	var c := ItemWidgets.ItemSlot.new(64.0)
	b.set_item({"uid": "x", "name": "Pièce", "slot": "head", "rarity": 1, "level": 1, "quality": 1.0, "upgrade": 0, "affixes": {}})
	c.set_item({"uid": "y", "name": "Pièce éveillée", "slot": "head", "rarity": 5, "awakened": true, "level": 1, "quality": 1.0, "upgrade": 0, "affixes": {}})
	for s in [a, b, c]:
		host.add_child(s)
	await get_tree().process_frame
	check("case vide : pas de _process", not a.is_processing())
	check("case avec une pièce : pas de _process", not b.is_processing())
	check("pièce éveillée : aura animée, _process actif", c.is_processing())
	c.set_item({})
	check("case vidée : _process arrêté", not c.is_processing())
	host.queue_free()


# --- Paramètres : pages construites en arrière-plan ------------------------------------------------------------------
func _test_settings_lazy() -> void:
	var m := SettingsMenu.new()
	add_child(m)
	check("Paramètres : rien de construit à la création", m._pages.is_empty())
	await get_tree().process_frame
	await get_tree().process_frame
	check("Paramètres : construction progressive (une étape par image)", m._build_next >= 1 and m._build_next < m._build_steps.size())
	check("Paramètres : page_count() termine la construction (6 pages)", m.page_count() == 6)
	m.open(2)
	check("Paramètres : ouverture sur l'onglet Touches", m.is_open() and m.current_page() == 2)
	m.close_ui()
	m.queue_free()
	var m2 := SettingsMenu.new()
	add_child(m2)
	for i in 10:
		await get_tree().process_frame
	check("Paramètres : sans rien demander, tout est construit en 10 images", m2._pages.size() == 6 and m2._build_next == m2._build_steps.size())
	m2.queue_free()
	var m3 := SettingsMenu.new()
	add_child(m3)
	m3.open()  # ouvert tout de suite : la construction se termine d'un coup
	check("Paramètres : ouvert avant la fin, les 6 pages existent", m3._pages.size() == 6 and m3.is_open())
	m3.close_ui()
	m3.queue_free()


# --- Registre : rouvrir un onglet inchangé ne reconstruit rien -----------------------------------------------------------
func _test_registry_skip() -> void:
	var page := RegistryPage.new()
	add_child(page)
	page.refresh()
	var first: Node = page._box.get_child(0)
	var n := page._box.get_child_count()
	page.refresh()
	check("Registre : 2e refresh() sans changement, mêmes nœuds", page._box.get_child(0) == first and page._box.get_child_count() == n)
	page._filter = 1
	page.refresh()
	check("Registre : filtre changé, page reconstruite", page._box.get_child(0) != first)
	var second: Node = page._box.get_child(0)
	page.refresh()
	check("Registre : de nouveau stable", page._box.get_child(0) == second)
	# une classe qui n'est pas celle du héros choisi (celle-ci lit l'équipement porté, pas son préréglage enregistré)
	var cid := ""
	for k in GameData.classes.keys():
		if String(k) != Profile.selected_class:
			cid = String(k)
			break
	Profile.expertise[cid] = 99999  # change la maîtrise, pas le Registre : rien à reconstruire
	page.refresh()
	check("Registre : donnée sans rapport, pas de reconstruction", page._box.get_child(0) == second)
	# un équipement qui change : la fiche de la classe doit se refaire (on tire jusqu'à une arme de puissance différente :
	# deux armes tirées au hasard ont parfois exactement la même, et la fiche est alors la même)
	var before := var_to_str(ClassGear.entry(cid, ClassGear.vault_map()))
	var p: Dictionary = Profile._class_presets(cid)
	var s: Dictionary = p.sets[clampi(int(p.active), 0, p.sets.size() - 1)]
	for _try in 40:
		var w := Items.generate(20, 0.5, "weapon")
		Profile.vault.append(w)
		s.slots["weapon"] = String(w.uid)
		if var_to_str(ClassGear.entry(cid, ClassGear.vault_map())) != before:
			break
	page.refresh()
	check("Registre : équipement changé, page reconstruite", page._box.get_child(0) != second)
	page.queue_free()
	# Succès : même principe
	var ach := CarnetPages.AchievementsPage.new()
	add_child(ach)
	ach.refresh()
	var a0: Node = ach._box.get_child(0)
	ach.refresh()
	check("Succès : 2e refresh() sans progrès, mêmes nœuds", ach._box.get_child(0) == a0)
	Profile.achievements[String(Achievements.LIST[0].id)] = "2026-10-15"
	ach.refresh()
	check("Succès : un succès obtenu, page reconstruite", ach._box.get_child(0) != a0)
	ach._filter = 2
	var a1: Node = ach._box.get_child(0)
	ach.refresh()
	check("Succès : filtre changé, page reconstruite", ach._box.get_child_count() > 0 and ach._box.get_child(0) != a1)
	ach.queue_free()


# --- Collection : l'avancement des catégories est calculé une fois par rafraîchissement --------------------------------
func _test_collection_memo() -> void:
	var page := ArchivePages.CollectionPage.new()
	add_child(page)
	page.refresh()
	var cats := Archive.categories().size()
	check("Collection : %d avancements mémorisés après refresh()" % cats, page._rate_memo.size() == cats)
	var r0: Vector2 = Archive.rate(String(Archive.categories()[0].id))
	check("Collection : avancement mémorisé = avancement réel", page._cat_rate(String(Archive.categories()[0].id)) == r0)
	Profile.collect(GameData.collection[3])
	page.refresh()
	check("Collection : refresh() recalcule (mémo vidé)", page._rate_memo.size() == cats)
	page.queue_free()


# --- décor : la map du titre est complétée, pas régénérée ----------------------------------------------------------------
func _test_backdrop_minimap() -> void:
	var host := Node3D.new()
	add_child(host)
	var bd := MapBackdrop.new()
	host.add_child(bd)
	var zone_id := String(GameData.zones[0].id)
	bd.show_zone(zone_id, false)
	var m1: ProcMap = bd.map
	check("décor : map générée sans mini-carte (comme au titre)", m1 != null and m1.minimap_info().texture == null)
	bd.release()
	var bd2 := MapBackdrop.new()
	host.add_child(bd2)
	bd2.show_zone(zone_id, true)
	check("décor : le lobby reprend la même map (pas de régénération)", bd2.map == m1)
	check("décor : la mini-carte est ajoutée", bd2.map.minimap_info().texture != null)
	bd2.release()
	bd2.queue_free()
	bd.queue_free()
	for m in MapBackdrop._cache.values():
		if is_instance_valid(m) and not m.is_inside_tree():
			m.free()
	MapBackdrop._cache.clear()
	MapBackdrop._order.clear()
	host.queue_free()


func _test_boot_marks() -> void:
	check("mesures : GameData.boot_us renseigné", GameData.boot_us.has("GameData._ready total") and int(GameData.boot_us["GameData._ready total"]) > 0)
	check("mesures : Profile.boot_us renseigné", Profile.boot_us.has("Profile._ready total"))


# --- modèles de héros : le cache de matériaux ne grossit plus à chaque reconstruction ---------------------------------
func _test_toon_cache() -> void:
	var cls: Dictionary = {}
	for cid in GameData.classes:
		if String(GameData.classes[cid].get("body_model", "")) != "":
			cls = GameData.classes[cid]
			break
	check("modèle : une classe à corps commun existe", not cls.is_empty())
	var warm := EdenModel.instantiate_hero(cls)
	warm.free()
	await get_tree().process_frame
	var n0: int = EdenModel._toon_cache.size()
	var objs0 := int(Performance.get_monitor(Performance.OBJECT_COUNT))
	for i in 6:
		var m := EdenModel.instantiate_hero(cls)
		add_child(m)
		m.queue_free()
		await get_tree().process_frame
	await get_tree().process_frame
	check("modèle : 6 héros reconstruits, aucune entrée de plus dans le cache de matériaux (%d)" % n0, EdenModel._toon_cache.size() == n0)
	var grown := int(Performance.get_monitor(Performance.OBJECT_COUNT)) - objs0
	check("modèle : 6 héros reconstruits, aucun objet gardé (%+d)" % grown, grown <= 4)


# --- run : un gain d'or ne recharge plus l'arme -------------------------------------------------------------------------
func _test_player_weapon() -> void:
	Training.active = false
	Run.start_survival("warrior", 1)
	var world: Node = load("res://scenes/world.tscn").instantiate()
	get_tree().root.add_child(world)
	await get_tree().create_timer(6.0).timeout
	var player: Player = world.player
	for m in get_tree().get_nodes_in_group("monsters"):
		m.queue_free()
	world.director.set_process(false)
	world.director.set_physics_process(false)
	var w0: Node3D = player._weapon
	check("run : l'arme est en main", w0 != null and player._weapon_code == Profile.weapon_code())
	for i in 5:
		Run.add_gold(5, "autre")  # un gain d'or émet Profile.changed
	await get_tree().process_frame
	check("run : 5 gains d'or, le modèle d'arme est le même", player._weapon == w0 and is_instance_valid(w0))
	var other := ""
	var wtype := Items.weapon_type_of(Profile.equipped.get("weapon", {}))  # le type de l'arme réellement portée (la clé des apparences)
	for e in GameData.eden_items:
		if String(e.get("slot", "")) == "weapon" and String(e.get("wtype", "")) == wtype and String(e.get("code", "")) != Profile.weapon_code():
			other = String(e.code)
			break
	check("run : une autre apparence existe pour le type d'arme porté (%s)" % wtype, other != "")
	if other != "":
		Profile.skins[wtype] = other  # une autre apparence d'arme
		Profile.changed.emit()
		await get_tree().process_frame
		check("run : apparence d'arme changée, le modèle est rechargé", player._weapon != w0 and player._weapon_code == Profile.weapon_code())
	world.queue_free()
	await get_tree().process_frame
	Training.active = true
