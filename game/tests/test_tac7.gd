extends Node
## Lot TAC-7 : HUD de L'Assaut (AssaultHud, AssaultAnnounce ; croquis tactique_maquettes/v2_hud_manche.svg).
## Pur : sens des annonces, lignes de la Charge sans partie. Partie réelle sur le Bourg : le HUD du mode est posé (et pas
## ailleurs), le panneau d'objectifs de la Survie et la barre de niveau sont cachés ; bandeau du score, ligne de la Charge, or,
## objets, cases tenus dans 1280 × 720 et 1600 × 900 sans se chevaucher ni chevaucher la mini-carte ; cases 2 et 3 à acheter
## puis achetées ; ultime à points ; or et prime de la prochaine défaite ; fiole, utilitaires et outil ; bouclier ; ligne de la
## Charge (portée, posée, désamorçage et sa sauvegarde) ; annonces (« 4 contre 3 ! », fin de manche avalée) ; repère au sol et
## sur la colonne ; ce que voit l'équipe (mini-carte) ; coût du HUD.
## godot --headless --path game res://tests/test_tac7.tscn

var fails := 0


func check(label: String, ok: bool) -> void:
	print(("OK    " if ok else "ÉCHEC ") + label)
	if not ok:
		fails += 1


func _ready() -> void:
	Settings.reset_all()
	_pure()
	await _world()
	print("TOUT EST OK (0 échec(s))" if fails == 0 else "ÉCHECS : %d" % fails)
	get_tree().quit(fails)


func _pure() -> void:
	check("annonce : « Charge posée en A ! » = pose (soleil en Attaque, fraise en Défense)", AssaultAnnounce.classify_a("Charge posée en A !")[0] == "plant")
	check("annonce : « 2 contre 4 ! » = effectifs", AssaultAnnounce.classify_a("2 contre 4 !")[0] == "count")
	check("annonce : fin de partie au rang le plus haut", int(AssaultAnnounce.classify_a("VICTOIRE ! 7 - 4")[1]) == 4)
	check("annonce : « Ouf ! Charge désamorcée ! » = désamorçage", AssaultAnnounce.classify_a("Ouf ! Charge désamorcée !")[0] == "defuse")
	check("ligne de la Charge sans partie : rien", String(AssaultHud.ChargeLine.state(null)[0]) == "")
	check("case sans partie : aucun état", AssaultHud.SlotMark.state_of(null, 1) == "")


func _world() -> void:
	Profile.selected_class = "warrior"
	Assault.launch("warrior", {"map": "bourg", "seed": 12, "speed": 1.0, "first_attack": 0, "buy_time": 600.0, "buy_time_first": 600.0,
		"round_time": 600.0})
	var world: Node = load("res://scenes/world.tscn").instantiate()
	get_tree().root.add_child.call_deferred(world)
	await _until(func(): return world.is_inside_tree() and world.get("director") != null and is_instance_valid(world.director.team), 600)
	await _until(func(): return world.director.map != null and world.director.map._region.navigation_mesh != null, 3600)
	var dd: AssaultDirector = world.director.team
	var p: Player = world.player
	var hud: Hud = world.hud
	await _until(func(): return is_instance_valid(dd.shop), 120)
	dd._close_shop()
	var ah: AssaultHud = hud.get("_assault")
	check("HUD de L'Assaut posé (AssaultHud.current)", ah != null and AssaultHud.current == ah)
	check("panneau d'objectifs de la Survie, barre de niveau et niveau d'aide cachés", not (hud.get("_obj_panel") as Control).visible
		and not (hud.get("_xp_orb") as Control).visible and not (hud.get("_assist_label") as Control).visible)
	check("4 cases marquées, objets, bouclier", ah.slot_marks.size() == 4 and ah.items != null and ah.shield != null)
	# cases : à acheter, achetées, ultime à points
	check("pendant l'achat : signature gratuite, cases 2 et 3 à acheter, ultime à 0 / 7",
		AssaultHud.SlotMark.state_of(dd, 0) == "free" and AssaultHud.SlotMark.state_of(dd, 1) == "locked"
		and AssaultHud.SlotMark.state_of(dd, 2) == "locked" and AssaultHud.SlotMark.state_of(dd, 3) == "ult")
	check("sort 2 acheté : sa case n'a plus de cadenas", dd.shop_buy("spell2") and AssaultHud.SlotMark.state_of(dd, 1) == "owned")
	dd.ult_pts["t0_0"] = 7
	check("ultime à 7 points : prêt", AssaultHud.SlotMark.state_of(dd, 3) == "ult_ready")
	dd.ult_pts["t0_0"] = 2
	# or, plan, prime
	check("or : pendant l'achat, le plan de l'équipe (%s)" % AssaultHud.GoldBox.second_line(), AssaultHud.GoldBox.second_line().begins_with("Plan : "))
	# objets
	Assault.give("t0_0", 2000)
	for id in ["brume", "eclat", "soin", "gants"]:
		dd.shop_buy(id)
	var cells := AssaultHud.ItemRow.entries("t0_0")
	check("fiole, deux utilitaires et l'outil, dans l'ordre (%s)" % str(cells.map(func(e): return e.id)),
		cells.size() == 4 and String(cells[0].id) == "soin" and String(cells[1].id) == "brume" and String(cells[2].id) == "eclat"
		and String(cells[3].id) == "gants" and String(cells[0].key) != "" and String(cells[3].key) == "")
	p.set_meta("assault_shield", p.max_hp * 0.25)
	check("bouclier : un quart des PV max", is_equal_approx(AssaultHud.ShieldMark.ratio_of(p), 0.25))
	# Charge pendant l'achat : tu la portes
	check("ligne de la Charge : tu la portes", String(AssaultHud.ChargeLine.state(dd)[0]).contains("tu la portes"))
	# mise en page aux deux tailles
	for res in [Vector2i(1280, 720), Vector2i(1600, 900)]:
		get_tree().root.size = res
		await get_tree().process_frame
		await get_tree().process_frame
		var vr := Rect2(Vector2.ZERO, Vector2(res))
		var band := ah.band.get_global_rect()
		var line := ah.charge_line.get_global_rect()
		var gold := ah.gold_box.get_global_rect()
		var items := ah.items.get_global_rect()
		var mapr := (hud.get("_map_holder") as Control).get_global_rect()
		var left := (hud.get("_left") as Control).get_global_rect()
		check("%d × %d : bandeau, ligne de la Charge, or et objets dans l'écran" % [res.x, res.y], vr.encloses(band) and vr.encloses(line)
			and vr.encloses(gold) and vr.encloses(items))
		check("%d × %d : le bandeau ne touche ni la mini-carte ni la pile de gauche" % [res.x, res.y], not band.intersects(mapr)
			and (left.size.y < 2.0 or not band.intersects(left)))
		var bar := (hud.get("_action_root") as Control).get_global_rect()
		check("%d × %d : l'or ne passe pas sous la barre d'action (%s / %s)" % [res.x, res.y, str(gold), str(bar)], gold.end.x < bar.position.x + 96.0
			or gold.end.y <= bar.position.y + 4.0)
	# la manche
	Assault.t = 0.05
	await _until(func(): return Assault.phase == "live", 120)
	await get_tree().process_frame
	check("manche : la barrière d'encre est tombée", dd._barriers.is_empty())
	check("or : prime de la prochaine défaite (%s)" % AssaultHud.GoldBox.second_line(), AssaultHud.GoldBox.second_line() == "prochaine manche : +1 500 au moins")
	# annonces
	check("annonce acceptée et montrée", ah.announce_message("2 contre 4 !", 2.0) and ah.announce.shown_title() != "")
	ah.announce.clear()
	check("« Manche gagnée » : avalée (la carte de fin de manche la dit)", ah.announce_message("Manche gagnée ! · Charge\n1 - 0", 2.0)
		and ah.announce.shown_title() == "")
	# K.O. d'un adversaire : « 4 contre 3 ! »
	for k in Assault.members[1]:
		var h := dd.hero(String(k))
		if h != null:
			(h as ClassRival).passive = true
	var foe := dd.hero("t1_2")
	foe.hp = 1.0  # (les plafonds du JcJ bornent un coup : la chute se prépare)
	foe.take_damage(500.0, p, false, true)
	await _until(func(): return ah.announce.shown_title().contains("contre"), 60)
	check("une chute : « 4 contre 3 ! » (%s)" % ah.announce.shown_title(), ah.announce.shown_title() == "4 contre 3 !")
	check("fil des éliminations : la chute est notée", not dd.ko_log.is_empty() and String(dd.ko_log[-1].victim) == "t1_2")
	# repère
	var at := dd._ground(p.global_position + Vector3(4, 0, -6))
	check("repère posé au sol", ah.place_ping(at) and dd.ping != Vector3.INF)
	check("repère dans la colonne de droite", ah.column.lines.any(func(l): return String(l.text).begins_with("Repère")))
	check("repère reposé au même endroit : retiré", not ah.place_ping(at) and dd.ping == Vector3.INF)
	# ce que voit l'équipe (mini-carte)
	ah._update_views(dd)
	check("mini-carte : ce que voient le joueur et ses alliés (%d polygones)" % ah._views.size(), ah._views.size() >= 1)
	# Charge posée, désamorçage et sa sauvegarde
	dd.charge_pos = dd._ground(dd.site_pos("A"))
	dd.carrier = ""
	dd._handle(Assault.plant("A", "t0_0"))
	check("Charge posée : la ligne le dit", String(AssaultHud.ChargeLine.state(dd)[0]).begins_with("Charge posée en A"))
	dd.defuse_by = "t1_1"
	dd.defuse_t = 2.0
	var st := AssaultHud.ChargeLine.state(dd)
	check("désamorçage adverse : avancée et repère de sauvegarde à la moitié", String(st[0]).begins_with("Désamorçage") and float(st[2]) > 0.2
		and absf(float(st[3]) - 0.5) < 0.01)
	dd.defuse_by = ""
	# coût du HUD
	var t0 := Time.get_ticks_usec()
	for _i in 200:
		ah._process(0.016)
	var ms := float(Time.get_ticks_usec() - t0) / 1000.0 / 200.0
	check("coût de la mise à jour du HUD du mode : %.3f ms par image" % ms, ms < 1.5)
	TeamMatch.abandon()
	await _until(func(): return dd._ended, 300)
	get_tree().paused = false
	world.queue_free()
	await get_tree().process_frame
	check("hors partie : plus de HUD de L'Assaut", AssaultHud.current == null or not is_instance_valid(AssaultHud.current))
	Run.active = false
	Profile.in_run = false


func _until(cond: Callable, max_frames := 300) -> void:
	for _i in max_frames:
		if cond.call():
			return
		await get_tree().physics_frame
