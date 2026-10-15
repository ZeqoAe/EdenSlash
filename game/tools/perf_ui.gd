extends Node
## Mesures de performance headless (passe P2) : démarrage, lobby, pages, sauvegarde, fuites, _process.
## Réutilisable avant / après une optimisation ; écrit aussi user://perf_ui.json (--out=chemin pour un autre fichier).
## PERF_ARGS="--only=boot,data,save,lobby,pages,leaks,process,detail,run --fat --loops=20 --prefetch --out=user://x.json" ##   godot --headless --path game res://tools/perf_ui.tscn
## EDEN_PROFILE=<chemin> isole le profil lu / écrit (obligatoire pour ne pas toucher les sauvegardes du joueur).
## En headless, le rendu GPU n'est pas mesuré : ce sont les coûts de scripts, de nœuds et de mise en page.

var rows: Array = []  # [section, nom, ms, détail]
var only: Array = []
var fat := false
var loops := 20
var out_path := "user://perf_ui.json"
var lobby: Node


func _ready() -> void:
	# options par la variable d'environnement PERF_ARGS (le lobby prend tout argument « -- » pour un lancement de run)
	for arg in OS.get_environment("PERF_ARGS").split(" ", false):
		if arg.begins_with("--only="):
			only = Array(arg.trim_prefix("--only=").split(","))
		elif arg == "--fat":
			fat = true
		elif arg.begins_with("--loops="):
			loops = int(arg.trim_prefix("--loops="))
		elif arg.begins_with("--out="):
			out_path = arg.trim_prefix("--out=")
	Settings.reset_all()
	Profile.reset_all()
	Gamepad.active = false
	get_tree().root.size = Vector2i(1600, 900)
	if _want("boot"):
		_boot()
	if _want("data"):
		_data()
	if fat:
		_make_fat_profile()
	if _want("save"):
		_save()
	if _want("screens"):
		await _screens()
	if _want("compile"):
		_compile()
	if _want("slots"):
		await _slots()
	if _want("lobby") or _want("pages") or _want("leaks") or _want("process") or _want("detail"):
		await _lobby_phase()
	if _want("run"):
		await _run_phase()
	_report()
	get_tree().quit()


func _want(k: String) -> bool:
	return only.is_empty() or k in only


func _ms(a: int) -> float:
	return float(Time.get_ticks_usec() - a) / 1000.0


func add(section: String, name: String, ms: float, detail := "") -> void:
	rows.append([section, name, ms, detail])


## Chronomètre un appel synchrone.
func timed(section: String, name: String, c: Callable, detail := "") -> Variant:
	var t := Time.get_ticks_usec()
	var r: Variant = c.call()
	add(section, name, _ms(t), detail)
	return r


## Chronomètre une action puis les deux images qui suivent (mise en page, appels différés).
func timed_frames(section: String, name: String, c: Callable) -> void:
	var t := Time.get_ticks_usec()
	c.call()
	var sync := _ms(t)
	var t2 := Time.get_ticks_usec()
	await get_tree().process_frame
	await get_tree().process_frame
	add(section, name, sync + _ms(t2), "appel %.1f ms + 2 images %.1f ms" % [sync, _ms(t2)])


# --- démarrage ---------------------------------------------------------------------------------
func _boot() -> void:
	add("boot", "moteur -> début de cette scène (autoloads compris)", float(Time.get_ticks_usec()) / 1000.0)
	for k in GameData.boot_us:
		add("boot", "GameData : " + String(k), float(GameData.boot_us[k]) / 1000.0)
	for k in Profile.boot_us:
		add("boot", "Profile : " + String(k), float(Profile.boot_us[k]) / 1000.0)


# --- données ------------------------------------------------------------------------------------
func _data() -> void:
	timed("data", "lecture + analyse de data/eden_catalog.json", func(): return JSON.parse_string(FileAccess.get_file_as_string("res://data/eden_catalog.json")))
	timed("data", "lecture + analyse de data/names_fr.json", func(): return JSON.parse_string(FileAccess.get_file_as_string("res://data/names_fr.json")))
	timed("data", "lecture + analyse de data/classes.json", func(): return JSON.parse_string(FileAccess.get_file_as_string("res://data/classes.json")))
	timed("data", "lecture + analyse de data/talents.json", func(): return JSON.parse_string(FileAccess.get_file_as_string("res://data/talents.json")))
	timed("data", "lecture + analyse de data/build_profiles.json", func(): return JSON.parse_string(FileAccess.get_file_as_string("res://data/build_profiles.json")))
	add("data", "catalogue : %d pièces" % GameData.eden_items.size(), 0.0)
	timed("data", "Completion.armory_ids() (1er appel, froid)", func(): return Completion.armory_ids().size())
	timed("data", "Completion.armory_ids() (2e appel)", func(): return Completion.armory_ids().size())
	timed("data", "ClassGear.equipped_count() (60 classes)", func(): return ClassGear.equipped_count())
	timed("data", "Boons.all()", func(): return Boons.all().size())
	timed("data", "SlotChests.pool x 100", func():
		for i in 100:
			SlotChests.pool("head", 1 + i % 4, 1 + i % 3))
	var cids: Array = GameData.classes.keys()
	timed("data", "Items.default_weapon_type x 60", func():
		for c in cids:
			Items.default_weapon_type(String(c)))


## 200 cases d'objet affichées (une grille d'inventaire) : coût d'une image au repos.
func _slots() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var grid := GridContainer.new()
	grid.columns = 20
	layer.add_child(grid)
	for i in 200:
		var sl := ItemWidgets.ItemSlot.new(40.0)
		if i % 2 == 0:
			sl.set_item(Items.generate(1 + i % 60, 0.5))  # une case sur deux porte une pièce, les autres sont vides (grille d'inventaire)
		grid.add_child(sl)
	await get_tree().create_timer(1.0).timeout
	var procs := 0
	for c in grid.get_children():
		if c.is_processing():
			procs += 1
	var avg := await _avg_process(60)
	add("slots", "200 cases d'objet affichées (100 vides) : TIME_PROCESS par image", avg, "%d cases avec _process actif" % procs)
	layer.queue_free()
	await get_tree().process_frame


## Coût de (re)compilation de chaque script du projet (hors autoloads) : où passe le démarrage à froid.
func _compile() -> void:
	var skip := ["settings", "gamepad", "ui_nav", "game_data", "profile", "run", "dev", "feedback", "music"]
	var rows2: Array = []
	var paths: Array = []
	var stack: Array = ["res://scripts"]
	while not stack.is_empty():
		var d: String = stack.pop_back()
		for sub in DirAccess.get_directories_at(d):
			stack.append(d + "/" + sub)
		for f in DirAccess.get_files_at(d):
			if f.ends_with(".gd"):
				paths.append(d + "/" + f)
	var total := 0.0
	for p in paths:
		if String(p).get_file().get_basename() in skip:
			continue
		var sc := load(p) as GDScript
		if sc == null:
			continue
		var t := Time.get_ticks_usec()
		sc.reload(true)
		var ms := _ms(t)
		total += ms
		rows2.append([ms, p])
	rows2.sort_custom(func(a, b): return a[0] > b[0])
	add("compile", "recompilation de %d scripts (hors autoloads)" % rows2.size(), total, "")
	for i in mini(12, rows2.size()):
		add("compile", "  " + String(rows2[i][1]).trim_prefix("res://scripts/"), rows2[i][0], "")


## Coût de construction de chaque écran du lobby (créé et ajouté à l'arbre, hors lobby).
func _screens() -> void:
	var host := Node.new()
	add_child(host)
	var n0 := int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	var specs := {
		"Héros": func(): return HeroScreen.new(6),
		"Carnet": func(): return PageScreen.new("Carnet", 5),
		"Atelier": func(): return PageScreen.new("Atelier", 5),
		"Coffres": func(): return PageScreen.new("Coffres", 5),
		"Paramètres": func(): return SettingsMenu.new(),
	}
	for k in specs:
		var before := int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
		var t := Time.get_ticks_usec()
		var sc: Node = specs[k].call()
		host.add_child(sc)
		if k == "Carnet":
			for pg in CarnetPages.tabs():
				sc.add_page(pg[0], pg[1])
		elif k == "Atelier":
			for pg in [["Armurerie", GearShopPage.new()], ["Fabrication", FabricationPage.new()], ["Forge", ForgeBench.new()]]:
				sc.add_page(pg[0], pg[1])
			sc.add_header_control(WorkshopPurse.new())
		elif k == "Coffres":
			for pg in [["Coffres", ChestsPage.new()], ["Roulette", WheelPage.new()]]:
				sc.add_page(pg[0], pg[1])
		var ms := _ms(t)
		await get_tree().process_frame
		await get_tree().process_frame
		add("screens", "écran " + k, ms, "%d nœuds" % (int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)) - before))
	host.queue_free()
	await get_tree().process_frame


func _make_fat_profile() -> void:
	# un compte de fin de jeu : toutes les classes, 400 pièces au coffre, tout l'Armurerie vue, beaucoup de succès
	Profile.unlocked_classes = GameData.classes.keys()
	var ids := Completion.armory_ids()
	Profile.seen_gear = ids.keys()
	for i in 400:
		var it := Items.generate(1 + (i * 7) % 100, 0.5)
		Profile.vault.append(it)
	for cid in GameData.classes:
		Profile.expertise[cid] = 4000 + hash(cid) % 3000
	Profile.insignia = 123456
	Profile.materials = {"crystal": 9999}
	Profile.unlocked_cards = Boons.all().map(func(b): return String(b.id))
	for i in 60:
		Profile.reward_chests.append(Rewards.make("gear", 40))
	Profile._lobby_view()
	var f := FileAccess.get_file_as_string(Profile.save_path)
	add("fat", "profil gonflé prêt", 0.0, "coffre %d pièces, %d vues, %d coffres" % [Profile.vault.size(), Profile.seen_gear.size(), Profile.reward_chests.size()])


# --- sauvegarde --------------------------------------------------------------------------------
func _save() -> void:
	var n := 30
	var t := Time.get_ticks_usec()
	for i in n:
		Profile.save_profile()
	var per := _ms(t) / float(n)
	var size := FileAccess.get_file_as_bytes(Profile.save_path).size()
	add("save", "Profile.save_profile() (moyenne de %d)" % n, per, "%d octets" % size)
	var t2 := Time.get_ticks_usec()
	for i in n:
		Profile.save_profile()
	add("save", "idem, 2e série", _ms(t2) / float(n), "")
	var t3 := Time.get_ticks_usec()
	Profile.load_profile()
	add("save", "Profile.load_profile()", _ms(t3), "")


# --- lobby, pages, fuites --------------------------------------------------------------------------
func _counts() -> Dictionary:
	return {
		"nodes": int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
		"orphans": int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)),
		"objects": int(Performance.get_monitor(Performance.OBJECT_COUNT)),
		"resources": int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)),
	}


func _lobby_phase() -> void:
	if "--prefetch" in OS.get_environment("PERF_ARGS").split(" ", false):
		var tp := Time.get_ticks_usec()
		ResourceLoader.load_threaded_request("res://scenes/lobby.tscn")
		while ResourceLoader.load_threaded_get_status("res://scenes/lobby.tscn") == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			await get_tree().process_frame
		add("lobby", "préchargement en tâche de fond du lobby (hors thread principal)", _ms(tp))
	var c0 := _counts()
	var t := Time.get_ticks_usec()
	lobby = load("res://scenes/lobby.tscn").instantiate()
	var t_inst := _ms(t)
	var t1 := Time.get_ticks_usec()
	add_child(lobby)
	var t_ready := _ms(t1)
	var t2 := Time.get_ticks_usec()
	await get_tree().process_frame
	await get_tree().process_frame
	var t_frames := _ms(t2)
	await get_tree().create_timer(1.0).timeout
	add("lobby", "ouverture du lobby (instanciation + _ready + 2 images)", t_inst + t_ready + t_frames, "instancier %.1f + _ready %.1f + images %.1f" % [t_inst, t_ready, t_frames])
	var c1 := _counts()
	add("lobby", "nœuds du lobby", float(c1.nodes - c0.nodes), "orphelins %d" % c1.orphans)
	if _want("pages"):
		await _pages()
	if _want("leaks"):
		await _leaks()
	if _want("process"):
		await _process_scan()
	if _want("detail"):
		await _detail()
	lobby.queue_free()
	await get_tree().process_frame
	if _want("lobby"):
		# 2e ouverture dans le même processus : les scripts sont déjà compilés (écart = coût de compilation / chargement)
		var tw := Time.get_ticks_usec()
		var l2: Node = load("res://scenes/lobby.tscn").instantiate()
		add_child(l2)
		await get_tree().process_frame
		await get_tree().process_frame
		add("lobby", "2e ouverture du lobby (scripts déjà chargés)", _ms(tw), "")
		l2.queue_free()
		await get_tree().process_frame


func _open_close(open_c: Callable, close_c: Callable) -> void:
	open_c.call()
	await get_tree().process_frame
	await get_tree().process_frame
	close_c.call()
	await get_tree().process_frame


func _pages() -> void:
	# menus du lobby
	for id in ["play", "survival", "training", "mastery", "duel", "arenas", "royale", "rush", "siege", "dungeon", "tower", "tower_floors"]:
		await timed_frames("menu", "lobby > " + id, func(): lobby._show_menu(id))
	lobby._show_menu("")
	await get_tree().process_frame
	# Héros
	for s in ["equipment", "class", "appearance", "cards"]:
		await timed_frames("hero", "Héros > %s (1re ouverture)" % s, func(): lobby._hero.open(s))
		await timed_frames("hero", "Héros > %s (2e)" % s, func(): lobby._hero.show_section(s))
	lobby._hero.close_ui()
	await get_tree().process_frame
	# Carnet, Atelier, Coffres, Paramètres
	for sc in [["Carnet", lobby._archive], ["Atelier", lobby._workshop], ["Coffres", lobby._chests]]:
		var s: PageScreen = sc[1]
		for i in s.page_count():
			var nm := "%s > %s" % [sc[0], s._tab_buttons[i].text]
			await timed_frames("page", nm + " (1re)", func(): s.open(i))
			await timed_frames("page", nm + " (2e)", func(): s.show_page(i))
		s.close_ui()
		await get_tree().process_frame
	lobby._settings.open()
	for i in lobby._settings._pages.size():
		var nm2 := "Paramètres > " + String(lobby._settings._tab_buttons[i].text)
		await timed_frames("page", nm2 + " (1re)", func(): lobby._settings.show_page(i))
	lobby._settings.close()
	await get_tree().process_frame


func _detail() -> void:
	# fermeture d'un écran : le lobby refait le modèle du héros et rafraîchit ses panneaux
	var o0 := int(Performance.get_monitor(Performance.OBJECT_COUNT))
	var tsh := Time.get_ticks_usec()
	for batch in 3:
		for i in (20 if loops > 0 else 0):
			lobby._show_hero()
			await get_tree().process_frame
		await get_tree().process_frame
		add("detail", "lobby._show_hero() : lot %d de 20 (objets en plus depuis le début)" % (batch + 1), 0.0, "objets %+d, noeuds %d" % [int(Performance.get_monitor(Performance.OBJECT_COUNT)) - o0, int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))])
	add("detail", "lobby._show_hero() (modèle du héros, moyenne de 60, images comprises)", _ms(tsh) / 60.0, "")
	o0 = int(Performance.get_monitor(Performance.OBJECT_COUNT))
	tsh = Time.get_ticks_usec()
	for i in 20:
		lobby._refresh_ui()
	await get_tree().process_frame
	add("detail", "lobby._refresh_ui() (moyenne de 20)", _ms(tsh) / 20.0, "objets %+d" % (int(Performance.get_monitor(Performance.OBJECT_COUNT)) - o0))
	lobby._hero.open("equipment")
	await get_tree().process_frame
	var pg: Control = lobby._hero.page
	var cid: String = Profile.selected_class
	timed("detail", "Héros > Équipement : GearPower.hero_power()", func(): return GearPower.hero_power())
	timed("detail", "Héros > Équipement : GearPower.summary()", func(): return GearPower.summary(maxi(Profile.best_level, 1)))
	timed("detail", "Héros > Équipement : _stats_player()", func(): return pg._stats_player())
	timed("detail", "Héros > Équipement : _refresh_grid()", func(): pg._refresh_grid())
	timed("detail", "Héros > Équipement : _refresh_detail()", func(): pg._refresh_detail())
	timed("detail", "Héros > Équipement : preset_bar.refresh()", func(): pg.preset_bar.refresh(cid))
	timed("detail", "Héros > Équipement : _preview.show_hero()", func(): pg._preview.show_hero(cid, Profile.weapon_code()))
	timed("detail", "Héros > Équipement : refresh() entier", func(): pg.refresh())
	lobby._hero.close_ui()
	await get_tree().process_frame
	lobby._archive.open(5)
	await get_tree().process_frame
	var reg: Control = lobby._archive.page(5)
	timed("detail", "Registre : refresh() entier", func(): reg.refresh())
	lobby._archive.close_ui()
	lobby._archive.open(4)
	await get_tree().process_frame
	var col: Control = lobby._archive.page(4)
	timed("detail", "Collection : refresh() entier", func(): col.refresh())
	timed("detail", "Collection : _build_tree()", func(): col._build_tree())
	timed("detail", "Collection : _refresh_grid()", func(): col._refresh_grid(0))
	timed("detail", "Collection : _refresh_list()", func(): col._refresh_list())
	timed("detail", "Collection : _vault_grid.set_items()", func(): col._vault_grid.set_items(Profile.all_items().filter(func(it): return int(it.rarity) >= Items.ARCHIVE_MIN_RARITY)))
	timed("detail", "Archive.rate x toutes catégories", func():
		for c in Archive.categories():
			Archive.rate(String(c.id)))
	timed("detail", "Archive.count_all()", func(): return Archive.count_all())
	timed("detail", "Archive.total()", func(): return Archive.total())
	timed("detail", "Archive.bonus()", func(): return Archive.bonus())
	timed("detail", "Archive.entries sur la plus grande catégorie", func():
		var best := 0
		for c in Archive.categories():
			best = maxi(best, Archive.entries(String(c.id)).size())
		return best)
	add("detail", "entrées d'archive (total)", float(Archive.total()), "collection du profil : %d" % Profile.collection.size())
	lobby._archive.close_ui()
	await get_tree().process_frame


func _leaks() -> void:
	var targets: Array = []
	for sc in [["Carnet", lobby._archive], ["Atelier", lobby._workshop], ["Coffres", lobby._chests]]:
		var s: PageScreen = sc[1]
		for i in s.page_count():
			targets.append(["%s > %s" % [sc[0], s._tab_buttons[i].text], func(): s.open(i), func(): s.close_ui()])
	for sec in ["equipment", "class", "appearance", "cards"]:
		targets.append(["Héros > " + sec, func(): lobby._hero.open(sec), func(): lobby._hero.close_ui()])
	for id in ["play", "survival", "duel", "dungeon", "tower"]:
		targets.append(["lobby > " + id, func(): lobby._show_menu(id), func(): lobby._show_menu("")])
	for tg in targets:
		await _open_close(tg[1], tg[2])  # échauffement : une ouverture avant la mesure
		await get_tree().process_frame
		var c0 := _counts()
		var t := Time.get_ticks_usec()
		for i in loops:
			await _open_close(tg[1], tg[2])
		var total := _ms(t)
		await get_tree().process_frame
		await get_tree().process_frame
		var c1 := _counts()
		add("leak", tg[0], total / float(loops), "après %d : nœuds %+d, orphelins %+d, objets %+d, ressources %+d" % [loops, c1.nodes - c0.nodes, c1.orphans - c0.orphans, c1.objects - c0.objects, c1.resources - c0.resources])


func _process_scan() -> void:
	var procs := {}
	var nodes := 0
	var stack: Array = [lobby]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		nodes += 1
		if n.is_processing() or n.is_physics_processing():
			var sc: Script = n.get_script()
			var k := "%s (%s)" % [n.get_class(), (sc.resource_path.get_file() if sc.resource_path != "" else "classe interne : " + String(n.get_path()).get_slice("/", 4)) if sc else "-"]
			procs[k] = int(procs.get(k, 0)) + 1
		for c in n.get_children():
			stack.append(c)
	add("process", "nœuds du lobby avec _process / _physics_process actif", float(procs.values().reduce(func(a, b): return a + b, 0)), "sur %d nœuds : %s" % [nodes, JSON.stringify(procs)])
	# coût d'une image au repos
	await get_tree().create_timer(0.5).timeout
	var t := Time.get_ticks_usec()
	var frames := 60
	for i in frames:
		await get_tree().process_frame
	add("process", "durée moyenne d'une image du lobby au repos (headless)", _ms(t) / float(frames), "plafonnée par la boucle principale")
	add("process", "temps de traitement par image (Performance.TIME_PROCESS)", float(Performance.get_monitor(Performance.TIME_PROCESS)) * 1000.0, "")
	# qui coûte à l'arrêt : on coupe tour à tour les nœuds qui traitent (autoloads compris), TIME_PROCESS moyen sur 30 images
	await get_tree().create_timer(2.5).timeout  # laisse finir les constructions en arrière-plan (Paramètres) et les libérations
	var base := await _avg_process(30)
	add("process", "TIME_PROCESS moyen au repos", base, "30 images")
	var owners: Array = []
	for n in get_tree().root.get_children():
		if n != self and (n.is_processing() or n.is_physics_processing()):
			owners.append(n)
	var stack2: Array = [lobby]
	while not stack2.is_empty():
		var n2: Node = stack2.pop_back()
		if n2.is_processing():
			owners.append(n2)
		for c in n2.get_children():
			stack2.append(c)
	var by_class := {}
	for n in owners:
		var k := "%s %s" % [n.get_class(), n.name if n.get_parent() == get_tree().root else "(lobby)"]
		by_class[k] = (by_class.get(k, []) as Array) + [n]
	for k in by_class:
		for n in by_class[k]:
			n.set_process(false)
		var t_off := await _avg_process(20)
		for n in by_class[k]:
			n.set_process(true)
		add("process", "  sans le traitement de : " + k + " x%d" % by_class[k].size(), t_off, "gain %.2f ms" % (base - t_off))


## Coûts en run : ce que fait un ramassage d'or (Profile.changed -> Player), recalcul des stats, rechargement de l'arme.
func _run_phase() -> void:
	await get_tree().process_frame
	Run.start_survival("warrior", 1)
	var tl := Time.get_ticks_usec()
	var packed: PackedScene = load("res://scenes/world.tscn")
	var t_load := _ms(tl)
	tl = Time.get_ticks_usec()
	var world: Node = packed.instantiate()
	var t_inst := _ms(tl)
	tl = Time.get_ticks_usec()
	get_tree().root.add_child(world)
	var t_ready := _ms(tl)
	await get_tree().process_frame
	await get_tree().process_frame
	add("run", "ouverture d'une run (world.tscn)", t_load + t_inst + t_ready + _ms(tl) - t_ready, "charger %.0f + instancier %.0f + _ready %.0f ms" % [t_load, t_inst, t_ready])
	await get_tree().create_timer(6.0).timeout
	var player: Player = world.player
	for m in get_tree().get_nodes_in_group("monsters"):
		m.queue_free()
	world.director.set_process(false)
	world.director.set_physics_process(false)
	world.cards._queue.clear()
	world.cards._show_next()
	await get_tree().create_timer(0.5).timeout
	var n := 100
	var t := Time.get_ticks_usec()
	for i in n:
		player.recalc_stats()
	add("run", "Player.recalc_stats()", _ms(t) / float(n), "moyenne de %d" % n)
	t = Time.get_ticks_usec()
	for i in n:
		player._attach_weapon(Profile.weapon_code())
	add("run", "Player._attach_weapon()", _ms(t) / float(n), "moyenne de %d" % n)
	t = Time.get_ticks_usec()
	for i in n:
		Profile.changed.emit()
	add("run", "Profile.changed.emit() (un ramassage d'or)", _ms(t) / float(n), "moyenne de %d" % n)
	t = Time.get_ticks_usec()
	for i in n:
		Run.add_gold(5, "autre")
	add("run", "Run.add_gold() (un monstre tué)", _ms(t) / float(n), "moyenne de %d" % n)
	var nodes0 := int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	for i in 50:
		Profile.changed.emit()
	await get_tree().process_frame
	await get_tree().process_frame
	add("run", "nœuds gagnés après 50 Profile.changed", float(int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)) - nodes0), "")
	var soak := 0
	for a in OS.get_environment("PERF_ARGS").split(" ", false):
		if a.begins_with("--soak="):
			soak = int(a.trim_prefix("--soak="))
	if soak > 0:
		await _soak(world, player, soak)
	world.queue_free()
	await get_tree().process_frame


## Run en pilote automatique (temps ×4) : mémoire, objets et cache de matériaux toutes les 10 s de jeu réelles.
func _soak(world: Node, player: Player, seconds: int) -> void:
	world.director.set_process(true)
	world.director.set_physics_process(true)
	world.cards._queue.clear()
	player.autoplay = true
	player.dev_invincible = true
	Engine.time_scale = 4.0
	var t0 := Time.get_ticks_usec()
	var step := 0
	while _ms(t0) < seconds * 1000.0:
		await get_tree().create_timer(10.0 / 4.0).timeout
		step += 1
		var tc := int(EdenModel._toon_cache.size())
		add("soak", "après %d s : matériaux en cache %d" % [step * 10, tc], float(Performance.get_monitor(Performance.MEMORY_STATIC)) / 1048576.0,
			"mémoire statique (Mo) ; objets %d, ressources %d, noeuds %d, monstres %d, orphelins %d" % [int(Performance.get_monitor(Performance.OBJECT_COUNT)),
			int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)), int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
			get_tree().get_nodes_in_group("monsters").size(), int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))])
	Engine.time_scale = 1.0


func _avg_process(frames: int) -> float:
	await get_tree().process_frame
	var sum := 0.0
	for i in frames:
		await get_tree().process_frame
		sum += float(Performance.get_monitor(Performance.TIME_PROCESS)) * 1000.0
	return sum / float(frames)


func _report() -> void:
	var json: Array = []
	for r in rows:
		print("%-8s %-62s %9.2f ms  %s" % [r[0], r[1], r[2], r[3]])
		json.append({"section": r[0], "name": r[1], "ms": snappedf(r[2], 0.01), "detail": r[3]})
	var f := FileAccess.open(out_path, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(json, "\t"))
		f.close()
