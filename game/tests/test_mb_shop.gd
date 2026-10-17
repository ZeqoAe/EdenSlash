extends Node
## Lot MB-D (Les Deux Voies, conception/benchmark/R_MB_D.md) : la boutique et les 40 objets.
## 1. Logique (MobaItems sur un MobaHero) : achat, recette (on ne paie que la différence, composants pris), refus (or, place,
##    une paire de bottes, objet fini en double, boutique fermée), annuler (or et composants rendus) tant qu'on est à la base,
##    vendre (70 %), potions (5 au plus), parcours conseillé adapté à l'équipe adverse, prochaine étape en un appui, totaux.
## 2. Partie réelle (world.tscn) : objets appliqués au joueur (attaque, PV) ET aux IA (PV, attaque, vitesse d'attaque,
##    recharges) ; effets déclenchés sur un Combatant quelconque : Lame de braise, Arc-tempête, Bouclier du gardien, Croc du
##    chasseur, Sablier du sage, Heaume du colosse, Armure vivante, Cape d'épines, Brise-garde, Lame de l'exécuteur, Étendard
##    des voies, Encensoir sacré, Orbe des marées, Faux de la Lune, Sceptre du givre.
## godot --headless --path game res://tests/test_mb_shop.tscn

var fails := 0


func check(label: String, ok: bool) -> void:
	print(("OK    " if ok else "ÉCHEC ") + label)
	if not ok:
		fails += 1


func _ready() -> void:
	Settings.reset_all()
	_logic()
	await _world()
	print("TOUT EST OK (0 échec(s))" if fails == 0 else "ÉCHECS : %d" % fails)
	get_tree().quit(fails)


func _sorted(a: Array) -> Array:
	var b := a.duplicate()
	b.sort()
	return b


func _logic() -> void:
	var h := MobaHero.new(null, 0, 2, "hunter")
	h.in_shop = true
	check("achat d'un composant : prix payé, objet porté", MobaItems.buy(h, "lame_courte") and is_equal_approx(h.gold, 150.0) and h.items == ["lame_courte"])
	check("refus : pas assez d'or", MobaItems.why_not(h, "lame_braise") == "Pas assez d'or.")
	h.gold = 3000.0
	MobaItems.buy(h, "oeil_faucon")
	var q := MobaItems.quote(h, "lame_braise")
	check("recette : on ne paie que la différence (2 400 − 350 − 500 = %d)" % int(q.cost), int(q.cost) == 1550)
	check("recette : composants pris, objet fini porté", MobaItems.buy(h, "lame_braise") and h.items == ["lame_braise"] and is_equal_approx(h.gold, 950.0))
	check("annuler : or et composants rendus", MobaItems.undo(h) and _sorted(h.items) == ["lame_courte", "oeil_faucon"] and is_equal_approx(h.gold, 2500.0))
	MobaItems.buy(h, "lame_braise")
	MobaItems.leave_shop(h)
	check("hors de la base : plus d'annulation", not MobaItems.undo(h) and h.items == ["lame_braise"])
	h.in_shop = false
	check("boutique fermée loin de la fontaine", MobaItems.why_not(h, "lame_courte") == "La boutique ouvre à la fontaine.")
	h.in_shop = true
	var g := h.gold
	check("vendre : 70 % du prix", MobaItems.sell(h, 0) and h.items.is_empty() and is_equal_approx(h.gold - g, 1680.0))
	check("annuler une vente : l'objet revient, l'or repart", MobaItems.undo(h) and h.items == ["lame_braise"] and is_equal_approx(h.gold, g))
	h.gold = 20000.0
	check("bottes : on monte les bottes de marche", MobaItems.buy(h, "bottes_marche") and MobaItems.buy(h, "bottes_rempart")
		and not "bottes_marche" in h.items and "bottes_rempart" in h.items)
	check("une seule paire de bottes", MobaItems.why_not(h, "bottes_marche") == "Une seule paire de bottes."
		and MobaItems.why_not(h, "bottes_elan") == "Une seule paire de bottes.")
	check("un objet fini n'est porté qu'une fois", MobaItems.why_not(h, "lame_braise") == "Tu le portes déjà.")
	for id in ["lame_courte", "lame_courte", "gemme_vie", "gemme_vie"]:
		MobaItems.buy(h, id)
	check("6 places : la 7e est refusée", h.items.size() == 6 and MobaItems.why_not(h, "cotte_mailles") == "Plus de place.")
	check("… mais une recette qui prend 2 composants portés passe", MobaItems.buy(h, "coeur_pierre") and h.items.size() == 5)
	h.items = ["lame_courte", "lame_courte"]
	h.stats = MobaItems.totals(h)
	check("totaux : deux Lames courtes = + 20 % d'attaque", is_equal_approx(float(h.stats.atk), 0.2))
	var n0 := int(h.potions.heal)
	check("potions : achetées à part, sans place", MobaItems.buy(h, "potion_soin") and int(h.potions.heal) == n0 + 1 and h.items.size() == 2)
	for _i in 6:
		MobaItems.buy(h, "potion_soin")
	check("potions : 5 au plus", int(h.potions.heal) == MobaItems.POTION_MAX)
	# parcours conseillé
	var t := MobaHero.new(null, 0, 2, "hunter")
	var base := MobaItems.route(t, [])
	check("parcours conseillé : les objets finis de la famille (%s)" % ", ".join(base), base.size() >= 4 and base == MobaItems.route(t, [1, 3, 4, 5], true))
	check("adapté : 2 Ombre ou plus → Bouclier du gardien tôt", "bouclier_gardien" in MobaItems.route(t, [2, 2, 1, 4]).slice(0, 3))
	check("adapté : 2 Arcane ou plus → Heaume du colosse", "heaume_colosse" in MobaItems.route(t, [5, 5, 1, 4]))
	check("adapté : 2 Ferveur ou plus → Lame de braise", "lame_braise" in MobaItems.route(t, [4, 4, 1, 3]).slice(0, 2))
	check("6 places au plus dans un parcours", MobaItems.route(t, [2, 2, 5, 5, 4, 4]).size() <= MobaData.SLOTS)
	t.in_shop = true
	t.gold = 400.0
	var first := String(base[0])
	var step := MobaItems.next_step(t, base)
	check("un appui : l'objet fini s'il est payable, sinon son composant le plus cher payable (%s)" % step,
		step in (MobaData.item(first).recipe as Array) or step == first)
	t.gold = 30000.0
	MobaItems.auto_shop(t, base)
	check("achat automatique : tout le parcours (%s)" % ", ".join(t.items), _sorted(t.items) == _sorted(base))
	var adv := MobaItems.advice(MobaHero.new(null, 0, 2, "hunter"), base)
	check("conseil affiché : objet suivant, prix réel, or", String(adv.id) == first and int(adv.cost) == int(MobaData.item(first).price) and int(adv.gold) == 500)


func _world() -> void:
	seed(91)
	Profile.selected_class = "warrior"
	Moba.launch("warrior", {"heroes": "all", "diff": 1, "seed": 91})
	var world: Node = load("res://scenes/world.tscn").instantiate()
	get_tree().root.add_child.call_deferred(world)
	await _until(func(): return world.is_inside_tree() and world.get("director") != null and is_instance_valid(world.director.team), 900)
	var dd: MobaDirector = world.director.team as MobaDirector
	if dd == null:
		check("directeur monté", false)
		Moba.finish()
		return
	await _until(func(): return dd.map != null and dd.map.nav_ready(), 900)
	for _i in 5:
		await get_tree().physics_frame
	var p: Player = dd.player
	var ps: MobaHero = dd.info[p]
	check("à la fontaine : boutique ouverte", ps.in_shop and MobaItems.shop_open(ps))
	var a0 := p.atk
	var h0 := p.max_hp
	ps.gold = 2000.0
	MobaItems.buy(ps, "lame_courte")
	MobaItems.buy(ps, "gemme_vie")
	check("joueur : Lame courte = + 10 %% d'attaque (%.0f → %.0f), Gemme de vie = + 10 %% de PV" % [a0, p.atk],
		absf(p.atk / a0 - 1.1) < 0.01 and absf(p.max_hp / h0 - 1.1) < 0.01)
	MobaItems.undo(ps)
	MobaItems.undo(ps)
	check("annuler : la fiche revient", absf(p.atk - a0) < 0.5 and absf(p.max_hp - h0) < 0.5 and int(ps.gold) == 2000)
	var r: MobaRival = null
	var ally: MobaRival = null
	for x in dd.heroes:
		if x is MobaRival and (x as MobaRival).side == 1 and r == null:
			r = x
		elif x is MobaRival and (x as MobaRival).side == 0 and ally == null:
			ally = x
	var rs: MobaHero = dd.info[r]
	rs.items.clear()
	MobaItems.refresh(rs)
	var rh := r.max_hp
	var ra := r.atk
	rs.gold = 5000.0
	rs.in_shop = true
	var magic := String(GameData.class_data(r.cid).get("dmg_type", "phys")) in ["mag", "magic"]
	MobaItems.buy(rs, "gemme_vie")
	MobaItems.buy(rs, "grimoire_use" if r.atk > 0.0 and magic else "lame_courte")
	MobaItems.buy(rs, "gant_vitesse")
	MobaItems.buy(rs, "sablier_fele")
	check("IA : PV + 10 %%, attaque + 10 %% (%.0f → %.0f), vitesse d'attaque × 1,12, recharges − 8 %%" % [ra, r.atk],
		absf(r.max_hp / rh - 1.1) < 0.02 and r.atk > ra * 1.05 and is_equal_approx(r.moba_aspd, 1.12) and is_equal_approx(r.moba_cdr, 0.08))
	rs.items.clear()
	MobaItems.refresh(rs)
	# effets déclenchés : le joueur (source) sur une IA
	r.global_position = p.global_position + Vector3(3, 0, 0)
	ps.items = ["lame_braise"]
	MobaItems.refresh(ps)
	r.statuses.erase("burn")
	MobaItems.post_hit(r, p, 50.0, true, false)
	check("Lame de braise : un critique enflamme la cible ; ses soins reçus baissent", r.has_status("burn")
		and MobaItems.heal_in(r, 100.0) < 100.0 * MobaItems.BURN_HEAL + 0.5)
	r.statuses.erase("burn")
	await _until(func(): return dd.minions.any(func(m): return not m.is_dead and m.side == 1), 60 * 60)
	var m: MobaMinion = null
	for x in dd.minions:
		if not x.is_dead and x.side == 1:
			m = x
			break
	if m != null:
		ps.items = ["arc_tempete"]
		MobaItems.refresh(ps)
		ps.basic_hits = 2
		ps.proc_at.clear()
		var mh := m.hp
		MobaItems.post_hit(m, p, 1.0, false, false)
		check("Arc-tempête : le 3e coup fait jaillir la foudre (sbire touché)", m.hp < mh or m.is_dead)
	ps.items = ["croc_chasseur", "sablier_sage"]
	MobaItems.refresh(ps)
	ps.proc_at.clear()
	p.hp = p.max_hp * 0.5
	p.skill_ready_at[999] = p._time + 10.0
	MobaItems.on_kill(ps, [])
	check("Croc du chasseur : une élimination soigne ; Sablier du sage : recharges en cours − 30 %",
		p.hp > p.max_hp * 0.5 + 1.0 and float(p.skill_ready_at[999]) - p._time <= 7.05)
	p.skill_ready_at.erase(999)
	ps.items = ["brise_garde", "lame_executeur"]
	MobaItems.refresh(ps)
	r.hp = r.max_hp
	var pen := MobaItems.pre_hit(r, p, 100.0, false)
	r.hp = r.max_hp * 0.1
	var ex := MobaItems.pre_hit(r, p, 100.0, false)
	check("Brise-garde : une part de la défense traversée (%.1f) ; Lame de l'exécuteur : plus fort sous la moitié (%.1f)" % [pen, ex],
		pen > 100.5 and ex > pen + 5.0)
	r.hp = r.max_hp
	ps.items = ["faux_lune"]
	MobaItems.refresh(ps)
	ps.proc_at.clear()
	MobaItems.on_cast(ps)
	var emp := MobaItems.pre_hit(r, p, 100.0, false)
	check("Faux de la Lune : après un sort, le coup suivant × 1,5 (une fois)", is_equal_approx(emp, 150.0) and is_equal_approx(MobaItems.pre_hit(r, p, 100.0, false), 100.0))
	ps.items.clear()
	MobaItems.refresh(ps)
	# l'IA porte : Bouclier du gardien, Heaume, Armure vivante, Cape d'épines, Étendard, Orbe, Sceptre
	rs.items = ["bouclier_gardien", "heaume_colosse"]
	MobaItems.refresh(rs)
	rs.proc_at.clear()
	rs.low_armed = true
	r.hp = r.max_hp * 0.2
	MobaItems.post_hit(r, p, 1.0, false, false)
	var soak := MobaItems.absorb(r, 10.0)
	check("Bouclier du gardien : sous 30 % de PV, un bouclier absorbe les coups", rs.shield > 0.0 and is_equal_approx(soak, 0.0))
	check("Heaume du colosse : contrôles 30 % plus courts", is_equal_approx(MobaItems.status_time(r, "stun", 1.0), 0.7)
		and is_equal_approx(MobaItems.status_time(r, "burn", 1.0), 1.0))
	rs.shield = 0.0
	rs.items = ["armure_vivante", "cape_epines"]
	MobaItems.refresh(rs)
	check("Armure vivante : + 20 % de soins reçus", is_equal_approx(MobaItems.heal_in(r, 100.0), 120.0))
	p.evasion_chance = 0.0  # (pas d'esquive au hasard dans le contrôle)
	p.parry_chance = 0.0
	var php := p.hp
	MobaItems.pre_hit(r, p, 100.0, false)
	check("Cape d'épines : qui frappe se blesse", p.hp < php)
	rs.items = ["etendard_voies"]
	MobaItems.refresh(rs)
	var mine: MobaMinion = null
	for x in dd.minions:
		if not x.is_dead and x.side == 1:
			mine = x
			break
	if mine != null:
		r.global_position = mine.global_position + Vector3(1, 0, 0)
		await get_tree().physics_frame
		await get_tree().physics_frame
		check("Étendard des voies : les sbires alliés proches frappent plus fort (× %.2f)" % dd.minion_aura(mine), dd.minion_aura(mine) > 1.15)
	rs.items = ["orbe_marees", "sceptre_givre"]
	MobaItems.refresh(rs)
	rs.proc_at.clear()
	r.moba_skill = true
	p.statuses.erase("chill")
	MobaItems.post_hit(p, r, 20.0, false, false)
	check("Orbe des marées : un sort qui touche un héros protège ; Sceptre du givre : il ralentit", rs.shield > 0.0 and p.has_status("chill"))
	r.moba_skill = false
	rs.shield = 0.0
	# soin d'un allié par un soutien IA : Encensoir sacré
	var as_: MobaHero = dd.info[ally]
	var buddy: Combatant = p
	as_.items = ["encensoir"]
	MobaItems.refresh(as_)
	as_.proc_at.clear()
	p.statuses.erase("frenzy")
	p.hp = p.max_hp * 0.5
	AssaultCombat.healer = ally
	buddy.heal(100.0)
	AssaultCombat.healer = null
	check("Encensoir sacré : l'allié soigné frappe plus vite", p.has_status("frenzy"))
	TeamMatch.end()
	Moba.reset()
	world.queue_free()
	await get_tree().process_frame
	Run.active = false
	Profile.in_run = false
	check("hors des Deux Voies : aucun effet d'objet", not MobaItems.active and is_equal_approx(MobaItems.status_time(null, "stun", 1.0), 1.0))


func _until(cond: Callable, max_frames := 300) -> void:
	for _i in max_frames:
		if cond.call():
			return
		await get_tree().physics_frame
