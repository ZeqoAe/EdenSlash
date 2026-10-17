extends Node
## Lot TAC-5 : économie, objets et écran d'achat de L'Assaut (AssaultItems, AssaultGadgets, AssaultShop, directeur).
## Pur : catalogue (26 objets + les sorts 2 et 3 du kit), prix, limites du paquetage (2 utilitaires, 4 charges, 2 du même,
## 1 fiole, 1 outil), outils réservés à un côté, remise du Contrôleur, réparation au prorata, revente pendant la phase, arme
## remplacée remboursée, achat conseillé dans le budget, rachat, plan d'équipe, perte à la chute, prime de défaite progressive.
## Partie réelle : écran d'achat ouvert (5 onglets, cartes, colonne d'équipe), achat et revente par l'écran, sorts verrouillés
## pendant l'achat, IA qui achètent, effets à la manche (bouclier qui encaisse d'abord, cases achetées), ultime à 7 points,
## brume, bombe d'éclats, chouette, fiole de soin, paquetage perdu à la chute ; l'écran tient dans 1280 × 720 et 1600 × 900.
## godot --headless --path game res://tests/test_tac5.tscn

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
	var items := AssaultItems.LIST.keys().filter(func(k): return not String(k).begins_with("spell"))
	check("catalogue : 26 objets (armes, armures, 10 utilitaires, 4 fioles, 4 outils, l'ultime) + les sorts 2 et 3", items.size() == 26
		and AssaultItems.LIST.keys().filter(func(k): return bool(AssaultItems.LIST[k].get("util", false))).size() == 10)
	var no_pct := AssaultItems.LIST.values().all(func(e): return not String(e.desc).contains("%"))
	check("aucun pourcentage dans les textes (seulement l'infobulle)", no_pct)
	Assault.begin([["a0", "a1", "a2", "a3"], ["b0", "b1", "b2", "b3"]], {"first_attack": 0, "seed": 3})
	AssaultItems.reset_all(Assault.members[0] + Assault.members[1])
	var ctx := {"cid": "warrior", "role": "rempart", "side": "attack"}
	var p2 := AssaultItems.price("a0", "spell2", ctx)
	check("sort 2 du Guerrier : son prix vient du kit (%d)" % p2, p2 == int(AssaultCombat.slots("warrior")[1].price))
	check("départ : 800", Assault.gold("a0") == 800)
	check("achat du sort 2", AssaultItems.buy("a0", "spell2", ctx) and Assault.gold("a0") == 800 - p2 and 1 in AssaultItems.inv("a0").spells)
	check("trop cher : la raison dit ce qui manque", AssaultItems.can_buy("a0", "maitre", ctx).begins_with("Il manque"))
	check("gilet", AssaultItems.buy("a0", "gilet", ctx) and is_equal_approx(float(AssaultItems.inv("a0").shield), 0.25))
	check("revente au prix payé pendant la phase", AssaultItems.sell("a0", "gilet") and Assault.gold("a0") == 800 - p2
		and String(AssaultItems.inv("a0").armor) == "")
	check("tout revendre : l'or de départ revient", AssaultItems.sell_all("a0") == 1 and Assault.gold("a0") == 800
		and (AssaultItems.inv("a0").spells as Array).is_empty())
	Assault.give("a0", 6000)
	check("utilitaires : 2 du même au plus", AssaultItems.buy("a0", "brume", ctx) and AssaultItems.buy("a0", "brume", ctx)
		and AssaultItems.can_buy("a0", "brume", ctx) == "Deux du même au plus")
	check("utilitaires : 2 cases au plus", AssaultItems.buy("a0", "eclat", ctx) and AssaultItems.can_buy("a0", "feu", ctx) == "Deux utilitaires au plus")
	check("utilitaires : 4 charges au plus", AssaultItems.buy("a0", "eclat", ctx) and AssaultItems.util_count("a0") == 4
		and AssaultItems.can_buy("a0", "eclat", ctx) != "")
	check("une fiole au plus", AssaultItems.buy("a0", "soin", ctx) and AssaultItems.can_buy("a0", "hate", ctx) == "Une fiole au plus")
	check("outil réservé : les Pinces pour la Défense", AssaultItems.can_buy("a0", "pinces", ctx) == "Pour la Défense")
	check("un outil au plus", AssaultItems.buy("a0", "gants", ctx) and AssaultItems.can_buy("a0", "talisman", ctx) == "Un outil au plus")
	var g0 := Assault.gold("a0")
	AssaultItems.buy("a0", "affutee", ctx)
	AssaultItems.buy("a0", "maitre", ctx)
	check("arme de maître après l'affûtée de la même phase : l'affûtée est remboursée", String(AssaultItems.inv("a0").weapon) == "maitre"
		and Assault.gold("a0") == g0 - 1500)
	AssaultItems.buy("a0", "cuirasse", ctx)
	AssaultItems.inv("a0").shield = 0.25
	check("réparer au prorata (la moitié de la cuirasse : 500)", AssaultItems.price("a0", "reparer", ctx) == 500)
	check("Contrôleur : utilitaires moins chers (brume 160)", AssaultItems.price("a1", "brume", {"role": "controleur"}) == 160)
	AssaultItems.new_phase("a0")
	check("phase suivante : rien n'est plus revendable, la liste « Racheter » est prête", (AssaultItems.inv("a0").now as Array).is_empty()
		and (AssaultItems.inv("a0").last as Array).size() >= 6 and not AssaultItems.sell("a0", "cuirasse"))
	AssaultItems.lose("a0")
	check("chute : tout le paquetage est perdu, la liste « Racheter » reste", String(AssaultItems.inv("a0").armor) == ""
		and (AssaultItems.inv("a0").spells as Array).is_empty() and not (AssaultItems.inv("a0").last as Array).is_empty())
	var rb := AssaultItems.rebuy("a0", ctx)
	check("racheter : la manche passée, autant que l'or permet (%s)" % str(rb), not rb.is_empty() and "maitre" in rb)
	var adv := AssaultItems.advised("a2", {"cid": "cleric", "role": "soutien", "side": "attack"})
	var cost := 0
	for i in adv:
		cost += AssaultItems.price("a2", String(i), {"cid": "cleric", "role": "soutien"})
	check("achat conseillé à 800 : dans le budget, sorts d'abord (%s)" % str(adv), cost <= 800 and not adv.is_empty()
		and String(adv[0]).begins_with("spell"))
	check("plan d'équipe : on économise à 800 de moyenne", AssaultItems.team_plan(1) == "eco")
	for k in Assault.members[1]:
		Assault.give(String(k), 3000)
	check("plan d'équipe : achat complet à 3 800", AssaultItems.team_plan(1) == "full")
	var bought := AssaultItems.ai_buy("b0", "full", {"cid": "magician", "role": "controleur", "side": "defense"})
	check("une IA achète selon le plan (%s)" % str(bought), not bought.is_empty() and Assault.gold("b0") < 3800)
	# prime de défaite progressive (machine TAC-0) : 1 500 -> 1 900 -> 2 300, une victoire redescend d'un cran
	check("prime de défaite : 1 500 d'abord", Assault.next_loss_gold(1) == 1500)
	Assault.phase = "live"
	Assault.end_round(0, "elim")
	check("après une défaite : 1 900", Assault.next_loss_gold(1) == 1900)
	Assault.reset()


var _world_n: Node


func _world() -> void:
	Profile.selected_class = "warrior"
	Assault.launch("warrior", {"map": "bourg", "seed": 12, "speed": 1.0, "win": 1, "first_attack": 0, "buy_time": 600.0,
		"buy_time_first": 600.0})
	var world: Node = load("res://scenes/world.tscn").instantiate()
	_world_n = world
	get_tree().root.add_child.call_deferred(world)
	await _until(func(): return world.is_inside_tree() and world.get("director") != null and is_instance_valid(world.director.team), 600)
	await _until(func(): return world.director.map != null and world.director.map._region.navigation_mesh != null, 3600)
	var dd: AssaultDirector = world.director.team
	var p: Player = world.player
	await _until(func(): return is_instance_valid(dd.shop), 120)
	var shop: AssaultShop = dd.shop
	check("écran d'achat ouvert à la phase d'achat", shop != null and shop.is_open() and Assault.phase == "buy")
	check("5 onglets, sorts : 4 cartes (signature, sort 2, sort 3, ultime)", shop._tabs.size() == 5 and shop.cards.size() == 4)
	check("onglets à la manette : l'écran est dans « tab_screens »", shop.is_in_group("tab_screens"))
	check("colonne de l'équipe : plan annoncé et 4 lignes", AssaultItems.plans[0] != "" and dd.team_rows(0).size() == 4)
	var g0 := Assault.gold("t0_0")
	shop._buy("spell2")
	check("achat par l'écran : le sort 2 (or %d -> %d)" % [g0, Assault.gold("t0_0")], 1 in AssaultItems.inv("t0_0").spells
		and Assault.gold("t0_0") < g0)
	check("pendant l'achat, aucun sort ne part", not dd.can_cast(p, 0) and not dd.can_cast(p, 1))
	shop.step_page(1)
	check("onglet suivant : Arme", shop.tab == 1 and shop.tab_ids().has("maitre"))
	var buttons := 0
	for b in shop.find_children("*", "BaseButton", true, false):
		if (b as Control).is_visible_in_tree():
			buttons += 1
	check("des boutons navigables (UiNav : A = clic) : %d" % buttons, buttons >= 10)
	shop._sell_all()
	check("tout revendre", Assault.gold("t0_0") == g0 and (AssaultItems.inv("t0_0").spells as Array).is_empty())
	Assault.give("t0_0", 3000)
	shop._advise()
	var inv: Dictionary = AssaultItems.inv("t0_0")
	check("achat conseillé : sorts, armure, arme (%s)" % str(inv.now.map(func(e): return e[0])), (inv.spells as Array).size() == 2
		and String(inv.armor) != "" and String(inv.weapon) != "")
	Assault.give("t0_0", 400)
	check("arme d'appoint : achetée, une seconde arme d'un autre type à prendre en main", shop.dir.call("shop_buy", "appoint")
		and not p.offhand_item().is_empty() and Items.weapon_type_of(p.offhand_item()) != String(GameData.class_data("warrior").weapon_type))
	var ai_bought := 0
	for k in Assault.members[0] + Assault.members[1]:
		if String(k) != "t0_0" and not (AssaultItems.inv(String(k)).now as Array).is_empty():
			ai_bought += 1
	check("les IA ont acheté (%d sur 7)" % ai_bought, ai_bought >= 5)
	# fits : 1280 × 720 et 1600 × 900
	for res in [Vector2i(1280, 720), Vector2i(1600, 900)]:
		get_tree().root.size = res
		dd._close_shop()
		await get_tree().process_frame
		dd._open_shop()
		var vr := Rect2(Vector2.ZERO, Vector2(res))
		var over: Array = []
		for ti in AssaultItems.TABS.size():
			dd.shop.set_tab(ti)
			await get_tree().process_frame
			await get_tree().process_frame
			var clip: Rect2 = dd.shop._scroll.get_global_rect()
			for c in dd.shop.find_children("*", "Control", true, false):
				var cc := c as Control
				if not cc.is_visible_in_tree() or cc.size.x <= 1.0 or dd.shop._scroll.is_ancestor_of(cc):
					continue  # (les cartes défilent dans leur cadre)
				if not vr.grow(1.0).encloses(cc.get_global_rect()):
					over.append("%s/%s" % [AssaultItems.TABS[ti][0], cc.name])
			check("onglet %s en %d × %d : le cadre des cartes est dans l'écran" % [AssaultItems.TABS[ti][0], res.x, res.y],
				vr.grow(1.0).encloses(clip))
		check("écran d'achat dans %d × %d, tous les onglets (débords : %s)" % [res.x, res.y, str(over.slice(0, 6))], over.is_empty())
	# la manche commence : écran fermé, effets du paquetage
	Assault.t = 0.05
	await _until(func(): return Assault.phase == "live", 120)
	await get_tree().process_frame
	check("manche : l'écran d'achat se ferme", not is_instance_valid(dd.shop))
	check("cases achetées : sorts 2 et 3, pas l'ultime", dd.can_cast(p, 1) and dd.can_cast(p, 2) and not dd.can_cast(p, 3))
	var sh := float(p.get_meta("assault_shield", 0.0))
	check("bouclier posé (%.0f)" % sh, sh > p.max_hp * 0.2)
	var hp0 := p.hp
	p.take_damage(sh * 0.5, null, false, true)
	check("le bouclier encaisse d'abord", is_equal_approx(p.hp, hp0) and float(p.get_meta("assault_shield")) < sh)
	for i in 7:
		dd._add_ult("t0_0")
	check("ultime : 7 points, la case 4 se lance", dd.ult_points("t0_0") == 7 and dd.can_cast(p, 3))
	dd.on_cast(p, 3)
	check("l'ultime consomme ses points", dd.ult_points("t0_0") == 0)
	# utilitaires et fiole
	for k in dd.heroes:
		var hk := dd.hero(String(k)) as ClassRival
		if hk != null:
			hk.passive = true  # (les scriptés restent en place : la bombe et la chouette visent un point)
			hk.velocity = Vector3.ZERO
	var foe := dd.hero(String(Assault.members[1][0]))
	AssaultItems.inv("t0_0").utils = {"brume": 1, "bombe": 1}
	AssaultItems.inv("t0_0").utils["chouette"] = 0
	var n0: int = dd.vision.smokes.size()
	check("brume lancée : la vue est coupée là", dd.use_util("t0_0", 0, p.global_position + p.forward() * 6.0) and dd.vision.smokes.size() == n0 + 1)
	foe.global_position = p.global_position + Vector3(3, 0.3, 0)
	foe.set_meta("assault_shield", 0.0)  # (son armure achetée encaisserait la bombe)
	var fhp := foe.hp
	check("bombe d'éclats lancée", dd.use_util("t0_0", 0, foe.global_position))
	await _secs(1.2)
	check("la bombe touche après son annonce (%.0f -> %.0f)" % [fhp, foe.hp], foe.hp < fhp - foe.max_hp * 0.15)
	AssaultItems.inv("t0_0").utils = {"chouette": 1}
	var far := dd.hero(String(Assault.members[1][1]))
	far.global_position = p.global_position + Vector3(0, 0.3, 9)
	check("œil de chouette", dd.use_util("t0_0", 0, far.global_position))
	await _secs(0.3)
	check("la chouette révèle autour du point", dd.vision.sees(0, far))
	p.hp = p.max_hp * 0.4
	p.set_meta("assault_healed", 0.0)
	AssaultItems.inv("t0_0").fiole = "soin"
	var h1 := p.hp
	check("fiole de soin bue", dd.use_fiole("t0_0") and String(AssaultItems.inv("t0_0").fiole) == "")
	await _secs(2.3)
	check("elle rend de la vie en 2 s (%.0f -> %.0f)" % [h1, p.hp], p.hp > h1 + p.max_hp * 0.2)
	# fin de manche : qui tombe perd tout
	var dead := String(Assault.members[1][2])
	dd.hero(dead).take_damage(dd.hero(dead).max_hp * 50.0, null, false, true)
	await get_tree().process_frame
	Assault.end_round(0, "elim")
	dd._round_inventory()
	check("tombé : paquetage perdu ; survivant : gardé", String(AssaultItems.inv(dead).armor) == "" and (AssaultItems.inv(dead).spells as Array).is_empty()
		and String(AssaultItems.inv("t0_0").armor) != "")
	TeamMatch.abandon()
	await _until(func(): return dd._ended, 300)
	get_tree().paused = false
	world.queue_free()
	await get_tree().process_frame
	Run.active = false
	Profile.in_run = false


func _secs(s: float) -> void:
	for _i in int(s * 60.0):
		await get_tree().physics_frame


func _until(cond: Callable, max_frames := 300) -> void:
	for _i in max_frames:
		if cond.call():
			return
		await get_tree().physics_frame
