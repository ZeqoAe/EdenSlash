extends Node
## Lot A2 de la refonte Aventure : Donjons dès l'époque I gagnée (zone par zone, jamais de reverrouillage ; la Ruée et le Siège
## gardent l'époque II), plus de salle de monstres seuls (élites à mécanique une à une, lieutenant, boss), durée bornée par
## les PV des salles (mesures au pilote : conception/progression/R_A2.md), PE conseillée affichée sur la page.
## godot --headless --path game res://tests/test_a2.tscn

var fails := 0


func check(label: String, ok: bool) -> void:
	print(("OK    " if ok else "ÉCHEC ") + label)
	if not ok:
		fails += 1


func _ready() -> void:
	Training.active = true
	Settings.reset_all()
	Profile.reset_all()
	_test_opening()
	_test_no_relock()
	_test_rooms()
	await _test_in_game()
	await _test_page()
	print("TOUT EST OK (0 échec(s))" if fails == 0 else "ÉCHECS : %d" % fails)
	get_tree().quit(fails)


func _test_opening() -> void:
	Profile.reset_all()
	check("compte neuf : Donjons, Ruée et Siège fermés", not Unlocks.is_open("dungeons") and not Unlocks.is_open("rush") and not Unlocks.is_open("siege"))
	check("condition : gagner l'époque I", Unlocks.condition("dungeons").contains("époque I ") or Unlocks.condition("dungeons").contains("époque I ("))
	Profile.records["epochs_cleared"] = 1
	check("époque I gagnée : les Donjons s'ouvrent", Unlocks.is_open("dungeons"))
	check("époque I gagnée : la Ruée et le Siège restent fermés (époque II)", not Unlocks.is_open("rush") and not Unlocks.is_open("siege"))
	var ep1: Array = Epochs.get_def(1).zones
	check("les donjons des zones de l'époque I sont ouverts (%s)" % ", ".join(ep1), ep1.all(func(z): return Dungeons.is_open(String(z))))
	var later := Dungeons.zone_ids().filter(func(z): return not z in ep1)
	check("les autres zones restent fermées tant que leur boss n'est pas battu", later.all(func(z): return not Dungeons.is_open(String(z))))
	Profile.records["boss_" + String(later[0])] = 1
	check("zone par zone : battre le boss de %s ouvre son donjon" % later[0], Dungeons.is_open(String(later[0])) and not Dungeons.is_open(String(later[1])))
	check("donjon de Monts Calcaires jouable : boss de la bibliothèque, au moins un en Normal", not Dungeons.catalog({"zone": String(ep1[0]), "open": true}).is_empty() \
		and Dungeons.power_ok(String(ep1[0]), 0))
	Profile.records["epochs_cleared"] = 2
	check("époque II gagnée : la Ruée et le Siège s'ouvrent", Unlocks.is_open("rush") and Unlocks.is_open("siege"))
	# boussole : l'échelon « époque I » annonce les Donjons, celui de l'époque II le Siège et la Ruée
	check("boussole : les Donjons s'annoncent à l'époque I", String(Compass.ladder_step("dungeons").get("text", "")).contains("Donjons") \
		and String(Compass.ladder_step("dungeons").get("text", "")).contains("époque I "))
	check("boussole : la Ruée s'annonce avec le Siège (époque II)", String(Compass.ladder_step("rush").get("text", "")).contains("Ruée"))
	check("activité Ruée : son propre verrou", Activities.LIST.filter(func(a): return a.id == "rush")[0].unlock == "rush")


func _test_no_relock() -> void:
	# un compte d'avant A2 (Donjons ouverts à l'époque II) : rien ne se referme, la Ruée reste ouverte
	Profile.reset_all()
	Profile.records["epochs_cleared"] = 2
	Profile.unlocked_features = ["forge", "tower", "dungeons", "siege"]
	check("ancien compte (époque II) : Donjons, Siège et Ruée ouverts", Unlocks.is_open("dungeons") and Unlocks.is_open("siege") and Unlocks.is_open("rush"))
	# liste gardée : jamais de reverrouillage, même si la condition n'est plus remplie
	Profile.reset_all()
	Profile.unlocked_features = ["dungeons"]
	check("Donjons déjà ouverts (liste gardée) : ouverts sans époque gagnée", Unlocks.is_open("dungeons"))
	# une Ruée déjà jouée (mode dev, vieux profil) reste ouverte
	Profile.reset_all()
	Profile.records["epochs_cleared"] = 1
	Profile.records["rush_best_1"] = 3
	check("une Ruée déjà jouée reste ouverte", Unlocks.is_open("rush"))
	# migration d'une sauvegarde d'avant le fil d'éveil : les Donjons ne sont pas « legacy » (à gagner), la Ruée non plus
	check("Ruée et Donjons : à gagner (pas d'ouverture d'office)", not bool(Unlocks.LIST.dungeons.legacy) and not bool(Unlocks.LIST.rush.legacy))
	Profile.reset_all()


func _test_rooms() -> void:
	check("trois salles : élites, lieutenant, boss", Dungeons.ROOMS == ["elite", "lieutenant", "boss"] and Dungeons.LIEUTENANT_ROOM == 2)
	var bad: Array = []
	for zid in Dungeons.zone_ids():
		for diff in Dungeons.DIFF_NAMES.size():
			for f in range(1, Dungeons.ROOMS.size() + 1):
				if Dungeons.room_monsters(f, diff) != 0:
					bad.append("%s/%d/%d" % [zid, diff, f])
	check("aucune salle de monstres seuls (toutes zones et difficultés) %s" % str(bad.slice(0, 4)), bad.is_empty() and not "monsters" in Dungeons.ROOMS)
	check("élites : 3 en Normal, une de plus par difficulté", Dungeons.room_elites(0) == 3 and Dungeons.room_elites(2) == 5)
	var bricks := range(Dungeons.room_elites(2)).map(func(i): return Dungeons.elite_brick("mori", i))
	var uniq := {}
	for b in bricks:
		uniq[b] = true
	check("chaque élite a sa mécanique, jamais deux fois la même (%s)" % ", ".join(bricks), uniq.size() == bricks.size() and bricks.all(func(b): return b in Tower.ELITE_BRICKS))
	Tower.start_dungeon("warrior", "limestone", 0, [], "mori")
	check("moteur : 3 salles, aucun monstre seul à faire apparaître", Tower.top() == 3 and range(1, 4).all(func(f): return Tower.monster_count(f) == 0) \
		and Tower.floor_type(1) == "elite" and Tower.floor_type(2) == "lieutenant" and Tower.is_boss_floor(3))
	Tower.active = false
	Tower.dungeon = ""
	Tower.dungeon_boss = ""
	Run.active = false


## Salles jouées en scène (héros invincible) : salle 1, une élite à mécanique et son escorte, la suivante quand elle tombe ;
## salle 2, le lieutenant seul ; salle 3, le boss ; PV des salles 1-2 bornés par rapport au boss (la durée en dépend).
func _test_in_game() -> void:
	Profile.records["epochs_cleared"] = 1
	Tower.start_dungeon("warrior", "limestone", 0, [], "mori")
	var world: Node = load("res://scenes/world.tscn").instantiate()
	get_tree().root.add_child.call_deferred(world)
	await get_tree().create_timer(6.0).timeout
	var d: RunDirector = world.director
	var p: Player = world.player
	p.dev_invincible = true
	world.revives_left = 9
	world.cards._queue.clear()
	world.cards._show_next()
	await get_tree().create_timer(0.5).timeout
	var td: TowerDirector = d.tower
	var mons := get_tree().get_nodes_in_group("monsters")
	var elites := mons.filter(func(m): return m.is_elite and m.brain != null)
	check("salle 1 : une élite à mécanique et son escorte (%d monstres)" % mons.size(), elites.size() == 1 and mons.size() == 1 + TowerDirector.ESCORT \
		and String(elites[0].display_name).contains(" · "))
	check("objectif : « Élite 1 / 3 »", td.objective_text().contains("Élite 1 / 3"))
	var elite_hp := 0.0
	for k in Dungeons.room_elites(0):
		var e: Array = td._elites_alive.filter(func(m): return is_instance_valid(m) and not m.is_dead)
		if e.is_empty():
			break
		elite_hp += e[0].max_hp
		e[0].take_damage(e[0].max_hp * 50.0, p)
		await get_tree().create_timer(0.4).timeout
	check("salle 1 : les élites arrivent une à une (%d vues)" % td._elites_alive.size(), td._elites_alive.size() == Dungeons.room_elites(0))
	for m in get_tree().get_nodes_in_group("monsters"):
		m.queue_free()
	await get_tree().create_timer(1.0).timeout
	check("salle 1 vidée : choix de carte puis passage", td.phase in ["cards", "stairs"])
	td.begin(2)
	await get_tree().create_timer(0.5).timeout
	mons = get_tree().get_nodes_in_group("monsters")
	check("salle 2 : le lieutenant seul (%d monstre)" % mons.size(), mons.size() == 1 and is_instance_valid(td._lieutenant) and td._lieutenant.brain.bricks.size() <= 1)
	check("objectif : « Vaincs … lieutenant »", td.objective_text().contains("Vaincs") and td.objective_text().contains("lieutenant"))
	var lt_hp: float = td._lieutenant.max_hp
	td.begin(3)
	await get_tree().create_timer(0.5).timeout
	check("salle 3 : le boss choisi", is_instance_valid(td._boss) and String(td._boss.get_meta("boss_id", "")) == "mori")
	var boss_hp: float = td._boss.max_hp if is_instance_valid(td._boss) else 1.0
	# durée bornée : le temps de chaque salle suit ses PV (les dégâts du héros sont les mêmes) ; mesuré au pilote (R_A2) avec
	# élites ≈ 1,4 et lieutenant ≈ 0,7 boss : salles 1-2 ≈ 3:40, boss ≈ 2 min, donjon Normal médian ≈ 5:50 (3:15 à 8:30).
	var r_el := elite_hp / boss_hp
	var r_lt := lt_hp / boss_hp
	check("PV des élites (salle 1) / boss : %.2f (attendu 1 à 1,9)" % r_el, r_el >= 1.0 and r_el <= 1.9)
	check("PV du lieutenant (salle 2) / boss : %.2f (attendu 0,5 à 0,9)" % r_lt, r_lt >= 0.5 and r_lt <= 0.9)
	var total := 1.0 + r_el + r_lt
	check("PV du donjon entier : %.1f boss (attendu 2,6 à 3,6 : 5 à 7 min)" % total, total >= 2.6 and total <= 3.6)
	td.phase = "done"
	for m in get_tree().get_nodes_in_group("monsters"):
		m.queue_free()
	world.queue_free()
	await get_tree().create_timer(0.3).timeout
	Tower.active = false
	Tower.dungeon = ""
	Tower.dungeon_boss = ""
	Run.active = false


## Page Donjons : PE conseillée visible en Normal (aucune requise), requise en Héroïque.
func _test_page() -> void:
	Profile.reset_all()
	Profile.records["epochs_cleared"] = 1
	check("PE conseillée : jamais sous la requise, croissante avec la difficulté",
		Dungeons.advised("limestone", 0) > 0 and Dungeons.advised("limestone", 1) >= Dungeons.power_required("limestone", 1) \
		and Dungeons.advised("limestone", 2) >= Dungeons.power_required("limestone", 2) and Dungeons.advised("beluga", 0) > Dungeons.advised("limestone", 0))
	var lobby: Node = load("res://scenes/lobby.tscn").instantiate()
	add_child(lobby)
	await get_tree().create_timer(1.0).timeout
	DungeonPage.sel = "mori"
	lobby._dg_diff = 0
	lobby._show_menu("dungeon")
	await get_tree().process_frame
	await get_tree().process_frame
	var txt := _texts(lobby._sub)
	check("page : « PE conseillée » affichée en Normal", txt.contains("PE conseillée"))
	check("page : récompenses du donjon (cristaux, plan à la 1re victoire)", txt.contains("cristaux") and txt.contains("plan de donjon"))
	check("page : bouton « Entrer » actif (époque I gagnée)", _go_enabled(lobby))
	lobby._dg_diff = 1
	lobby._show_menu("dungeon")
	await get_tree().process_frame
	await get_tree().process_frame
	check("page Héroïque : « PE requise » affichée", _texts(lobby._sub).contains("PE requise"))
	lobby.queue_free()
	await get_tree().process_frame


func _texts(n: Node) -> String:
	var out := ""
	if n is Label:
		out += (n as Label).text + "\n"
	elif n is Button:
		out += (n as Button).text + "\n"
	for c in n.get_children():
		out += _texts(c)
	return out


func _go_enabled(lobby: Node) -> bool:
	for b in lobby.find_children("*", "Button", true, false):
		if String((b as Button).text).begins_with("Entrer"):
			return not (b as Button).disabled
	return false
