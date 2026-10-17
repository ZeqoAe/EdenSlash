extends Node
## Lot CO-E : atouts du Colisée (core/colisee_augments.gd, rapport conception/benchmark/R_CO_E.md). Données (32 atouts, 3
## raretés, textes sans chiffre, icônes), offres notées (même rareté, thèmes différents, jamais incohérentes, relance d'une
## carte), choix de l'IA, prise (recette Tempête, Pacte de sang, Maître des sorts), CHAQUE effet vérifié sur des mannequins
## (héros scriptés immobiles), plafonds ; puis une vraie partie (world.tscn) : constructions posées sur les héros, fiche du
## joueur, effets en combat réel, fin de manche.
## godot --headless --path game res://tests/test_co_e.tscn

var fails := 0
var heroes: Array = []


func check(label: String, ok: bool) -> void:
	print(("OK    " if ok else "ÉCHEC ") + label)
	if not ok:
		fails += 1


func _ready() -> void:
	Settings.reset_all()
	Profile.selected_class = "warrior"
	_data()
	_offers()
	_take()
	await _effects()
	if not "--sans-partie" in OS.get_cmdline_user_args():
		await _game()
	print("TOUT EST OK (0 échec(s))" if fails == 0 else "ÉCHECS : %d" % fails)
	get_tree().paused = false
	get_tree().quit(fails)


func _frames(n: int) -> void:
	for _i in n:
		await get_tree().physics_frame


func _until(cond: Callable, max_frames := 300) -> bool:
	for _i in max_frames:
		if cond.call():
			return true
		await get_tree().physics_frame
	return cond.call()


# --- données -------------------------------------------------------------------------------------------------------------

func _data() -> void:
	var ids := ColiseeAugments.ids()
	var uniq := {}
	for id in ids:
		uniq[id] = true
	check("32 atouts, ids uniques", ids.size() == 32 and uniq.size() == 32)
	var by_r := {}
	for a in ColiseeAugments.LIST:
		by_r[String(a.rarity)] = int(by_r.get(String(a.rarity), 0)) + 1
	check("trois raretés : Argent %d, Or %d, Éclat %d" % [by_r.get("argent", 0), by_r.get("or", 0), by_r.get("eclat", 0)],
		by_r.size() == 3 and int(by_r.argent) >= 8 and int(by_r["or"]) >= 8 and int(by_r.eclat) >= 6)
	var digit := RegEx.create_from_string("[0-9%]")
	var bad_text: Array = []
	var bad_icon: Array = []
	var names := {}
	for a in ColiseeAugments.LIST:
		var c := ColiseeAugments.card(String(a.id))
		if digit.search(String(c.text)) != null or String(c.tip) == "" or String(c.text).replace("K.O.", "KO").count(". ") > 1:
			bad_text.append(a.id)
		if ColiseeAugments.texture(String(a.id), 64) == null or (String(a.get("ico", "")) != "" and not Ico.has(String(a.ico))) 				or (String(a.get("icon", "")) != "" and not ResourceLoader.exists(String(a.icon))):
			bad_icon.append(a.id)
		names[String(a.name)] = true
		for w in String(c.text).to_lower().split(" ", false):
			if w in ["run", "build", "lobby", "set"]:
				bad_text.append(a.id)
		if (a.roles as Array).size() != 4:
			bad_text.append(a.id)
	check("cartes : une phrase sans chiffre ni %%, détail chiffré en infobulle %s" % str(bad_text), bad_text.is_empty())
	check("cartes : icône (pictogramme Ico ou statut), nom unique %s" % str(bad_icon), bad_icon.is_empty() and names.size() == 32)
	check("recette : Braise, Givre, Foudre (Or) -> Tempête (Éclat), Tempête jamais proposée",
		ColiseeAugments.RECIPE.all(func(r): return String(ColiseeAugments.def(r).rarity) == "or")
		and String(ColiseeAugments.def("tempete").rarity) == "eclat" and not ColiseeAugments.offerable("tempete"))
	check("Relève éclair : attend la relève (lot CO-J), jamais proposée avant", not ColiseeAugments.offerable("releve_eclair"))
	var cd := ColiseeAugments.card("braise")
	check("données d'affichage : nom, rareté, couleur, texte, détail, « Va bien avec »", String(cd.rarity_name) == "Or"
		and cd.color is Color and (cd.goes as Array).size() == 2)


func _build(cid: String, t := 1, aug: Array = []) -> ColiseeBuild:
	var b := ColiseeBuild.new()
	b.cid = cid
	b.team = t
	b.role = ColiseeBuild.role_of(cid)
	b.family = Duel.family_of(cid)
	b.diff = 3
	b.augments = aug.duplicate()
	return b


func _offers() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	var n := 0
	var bad: Array = []
	var themes_bad := 0
	var incoherent := 0
	var roles_seen := {}
	for cid in GameData.classes.keys():
		var b := _build(String(cid))
		roles_seen[b.role] = true
		for rar in ColiseeAugments.RARITY_ORDER:
			for k in 6:
				var ctx := {"round": 1 + k * 2, "team_hp": 100 - k * 12, "mates": [b]}
				var o := ColiseeAugments.make_offer(b, rar, ctx, rng)
				n += 1
				if o.size() != 3:
					bad.append([cid, rar, o])
					continue
				var th := {}
				for id in o:
					th[String(ColiseeAugments.def(id).theme)] = true
					if String(ColiseeAugments.def(id).rarity) != rar or not ColiseeAugments.eligible(String(id), b, ctx):
						bad.append([cid, rar, id])
					if ColiseeAugments.role_note(String(id), b.role) < ColiseeAugments.INCOHERENT:
						incoherent += 1
				if th.size() < 3:
					themes_bad += 1
	check("offres : %d offres de 3 cartes de la même rareté, toutes prenables %s" % [n, str(bad.slice(0, 3))], bad.is_empty())
	check("offres : jamais incohérentes (carte d'un autre rôle) : %d" % incoherent, incoherent == 0)
	check("offres : trois thèmes différents (%d offres sur %d à thème répété)" % [themes_bad, n], themes_bad <= n / 20)
	check("rôles des 60 classes : tank, mêlée, distance, soin %s" % str(roles_seen.keys()), roles_seen.size() == 4)
	# les mieux notés sortent le plus souvent : un soigneur reçoit Concentration plus souvent que Lame affûtée
	var healer := ""
	for cid in GameData.classes.keys():
		if ColiseeBuild.role_of(String(cid)) == "healer":
			healer = String(cid)
	var hb := _build(healer)
	var cnt := {"concentration": 0, "lame_affutee": 0}
	for i in 400:
		for id in ColiseeAugments.make_offer(hb, "argent", {"round": 1, "team_hp": 100, "mates": [hb]}, rng):
			if cnt.has(id):
				cnt[id] += 1
	check("offres notées : un soigneur voit Concentration (%d) plus que Lame affûtée (%d)" % [cnt.concentration, cnt.lame_affutee],
		int(cnt.concentration) > int(cnt.lame_affutee))
	# relance : une seule carte change, même rareté, 3 relances pour la partie
	var b := _build("warrior")
	b.offer_rarity = "or"
	b.offer = ColiseeAugments.make_offer(b, "or", {"round": 4, "mates": [b]}, rng)
	var before := b.offer.duplicate()
	var ok := ColiseeAugments.reroll(b, 1, {"round": 4, "mates": [b]}, rng)
	check("relance : la carte 2 change, les autres restent, même rareté (%s -> %s)" % [str(before), str(b.offer)], ok and b.offer[0] == before[0]
		and b.offer[2] == before[2] and b.offer[1] != before[1] and String(ColiseeAugments.def(b.offer[1]).rarity) == "or" and b.rerolls == 2)
	ColiseeAugments.reroll(b, 0, {"round": 4, "mates": [b]}, rng)
	ColiseeAugments.reroll(b, 2, {"round": 4, "mates": [b]}, rng)
	check("relance : 3 pour la partie, puis plus rien", b.rerolls == 0 and not ColiseeAugments.reroll(b, 0, {"mates": [b]}, rng))
	# choix de l'IA : Hardcore = la meilleure note ; Facile = au hasard
	var offer := ["peau_de_chene", "lame_affutee", "tirelire"]
	var tank := ""
	for cid in GameData.classes.keys():
		if ColiseeBuild.role_of(String(cid)) == "tank":
			tank = String(cid)
	var tb := _build(tank)
	var best := 0
	for i in 3:
		if ColiseeAugments.score(offer[i], tb, {"round": 6, "mates": [tb]}) > ColiseeAugments.score(offer[best], tb, {"round": 6, "mates": [tb]}):
			best = i
	check("choix Hardcore : la meilleure note (%s pour un tank)" % offer[best], ColiseeAugments.choose_augment(offer, tb, {"round": 6, "mates": [tb]}, rng) == best
		and offer[best] == "peau_de_chene")
	tb.diff = 0
	var seen := {}
	for i in 60:
		seen[ColiseeAugments.choose_augment(offer, tb, {}, rng)] = true
	check("choix Facile : au hasard parmi les trois", seen.size() == 3)
	var dicts := ColiseeAugments.offer_dicts(offer, tb, {"round": 6, "mates": [tb]})
	check("offres pour le chef d'équipe (CO-D) : {id, score, tags}", dicts.size() == 3 and dicts[0].has("score") and dicts[0].has("tags"))


func _take() -> void:
	var g := Colisee.new("classique", 5)
	g.classes = Colisee.compose_teams(g.n, "warrior", g.rng)
	g.team_diffs = Colisee.team_difficulties(3, g.n, g.rng)
	g.set_meta("co_player", false)
	ColiseeBuild.setup(g)
	var b := ColiseeBuild.of(g, 1, 0)
	check("constructions : 6 trios de 3, place et classe", ColiseeBuild.all_of(g).size() == 6 and b.cid == String(g.classes[1][0]))
	ColiseeAugments.take(b, "braise", g)
	ColiseeAugments.take(b, "givre", g)
	check("recette : deux pièces tenues", b.augments.size() == 2)
	var got := ColiseeAugments.take(b, "foudre", g)
	check("recette : la 3e pièce fusionne en Tempête et libère deux places (%s)" % str(b.augments), got == "tempete" and b.augments == ["tempete"])
	var fx := ColiseeAugments.effects_for(b)
	check("Tempête : Braise, Givre et Foudre × 1,5", is_equal_approx(float(fx.braise.burn_time), 4.5) and is_equal_approx(float(fx.givre.chill_time), 2.25)
		and is_equal_approx(float(fx.foudre.bounce), 0.6))
	check("Tempête : plus de pièce de recette proposée", not ColiseeAugments.eligible("braise", b, {}))
	var hp0 := int(g.hp[1])
	ColiseeAugments.take(b, "pacte_de_sang", g)
	check("Pacte de sang : −15 PV d'équipe tout de suite (%d -> %d)" % [hp0, int(g.hp[1])], int(g.hp[1]) == hp0 - 15)
	var b2 := ColiseeBuild.of(g, 2, 0)
	check("Pacte de sang : impossible sous 30 PV d'équipe", not ColiseeAugments.eligible("pacte_de_sang", b2, {"team_hp": 25}))
	ColiseeAugments.take(b2, "maitre_des_sorts", g)
	check("Maître des sorts : une place de sort et des sorts de la classe proposés (%s)" % str(b2.spell_offer), b2.spell_slots == 1
		and b2.spell_offer.size() == mini(3, ColiseeAnvil.spell_pool(b2).size()) and not b2.spell_offer.is_empty())
	for id in ["peau_de_chene", "pas_leger", "concentration", "ancre", "sangsue"]:
		ColiseeAugments.take(b2, id, g)
	check("6 atouts au plus (%d)" % b2.augments.size(), b2.augments.size() == 6 and ColiseeAugments.take(b2, "ronces", g) == "")
	var mates := ColiseeBuild.team_of(g, 3)
	(mates[0] as ColiseeBuild).augments = ["trio_parfait"]
	check("Trio parfait : effet sur les trois, un seul compte", ColiseeAugments.effects_for(mates[1], mates).has("trio_parfait")
		and not ColiseeAugments.eligible("trio_parfait", mates[1], {"mates": mates}))
	var cap_b := _build("warrior", 1, ["peau_de_chene", "colosse", "trio_parfait"])
	cap_b.stats = {"hp_pct": 0.36, "dmg_pct": 0.3}
	var sb := ColiseeAugments.sheet_bonus(cap_b, ColiseeAugments.effects_for(cap_b))
	check("plafond : PV en plus bornés à %d %% (%.2f)" % [int(ColiseeAugments.HP_CAP * 100), float(sb.hp_pct)], is_equal_approx(float(sb.hp_pct), ColiseeAugments.HP_CAP))


# --- effets sur mannequins -------------------------------------------------------------------------------------------------

func _hero(cid: String, t: int, aug: Array, pos: Vector3, mates: Array = []) -> ClassRival:
	var b := _build(cid, t, aug)
	var r := TeamMatch.make_hero(cid, Colisee.LEVEL, 3, t, 0)
	add_child(r)
	r.set_physics_process(false)
	r.passive = true
	r.global_position = pos
	mates.append(b)
	ColiseeAugments.apply_hero(r, b, mates)
	heroes.append(r)
	return r


## Coup de [param src] sur [param dst] : PV perdus ; la cible remise à neuf, la fenêtre de rafale vidée.
func _hit(dst: Combatant, src: Combatant, amount: float, reset := true) -> float:
	PvpCaps.elapsed += 3.0
	var before := dst.hp
	dst.take_damage(amount, src)
	var lost := before - dst.hp
	if reset and not dst.is_dead:
		dst.hp = dst.max_hp
	return lost


func _clear() -> void:
	for h in heroes:
		if is_instance_valid(h):
			TeamMatch.remove(h)
			h.queue_free()
	heroes = []
	ColiseeAugments.start()
	ColiseeAugments.begin_fight(null, [])


func _effects() -> void:
	Colisee.register_rules()
	TeamMatch.begin(Colisee.MODE, 4)
	ColiseeAugments.start()
	ColiseeAugments.begin_fight(null, [])
	PvpCaps.elapsed = 10.0
	var cid := "warrior"
	var base := _hero(cid, 1, [], Vector3(0, 0, 0))
	var ref_hp := base.max_hp
	var ref_speed := base.move_speed
	var ref_cfg: Dictionary = base.cfg
	# fiche
	var a := _hero(cid, 1, ["peau_de_chene"], Vector3(30, 0, 0))
	check("Peau de chêne : PV × 1,15 (%.0f / %.0f)" % [a.max_hp, ref_hp], absf(a.max_hp / ref_hp - 1.15) < 0.01)
	a = _hero(cid, 1, ["pas_leger"], Vector3(30, 0, 5))
	check("Pas léger : vitesse × 1,12", absf(a.move_speed / ref_speed - 1.12) < 0.01)
	a = _hero(cid, 1, ["concentration", "esquive_agile"], Vector3(30, 0, 10))
	check("Concentration : recharge des sorts × 0,88 ; Esquive agile : recharge d'esquive × 0,75",
		absf(float(a.cfg.skill_cd) / float(ref_cfg.skill_cd) - 0.88) < 0.01 and absf(float(a.cfg.recharge) / float(ref_cfg.recharge) - 0.75) < 0.01)
	a = _hero(cid, 1, ["colosse"], Vector3(30, 0, 15))
	check("Colosse : PV × 1,4, vitesse × 0,9, taille × 1,3", absf(a.max_hp / ref_hp - 1.4) < 0.01 and absf(a.move_speed / ref_speed - 0.9) < 0.01
		and (a.model == null or absf(a.model.scale.x / (a.get_meta("co_scale") as Vector3).x - 1.3) < 0.01))
	var tri_mates: Array = []
	_hero(cid, 1, ["trio_parfait"], Vector3(40, 0, 0), tri_mates)
	var tri := _hero(cid, 1, [], Vector3(40, 0, 3), tri_mates)
	check("Trio parfait : l'équipier aussi a +10 %% de PV", absf(tri.max_hp / ref_hp - 1.1) < 0.01)
	a = _hero(cid, 1, ["lame_affutee"], Vector3(30, 0, 20))
	a._combo_i += 1
	var m_auto := a.damage_dealt_mult()
	var m_spell := a.damage_dealt_mult()
	check("Lame affûtée : auto-attaque × 1,2, sort × 1 (%.2f / %.2f)" % [m_auto, m_spell], absf(m_auto - 1.2) < 0.001 and absf(m_spell - 1.0) < 0.001)
	# coups
	var foe := _hero(cid, 2, [], Vector3(0, 0, 2))
	var amt := base.atk * 3.0
	var ref_d := _hit(foe, base, amt)
	check("mannequins : un coup de référence (%.0f PV, sous le plafond de 15 %%)" % ref_d, ref_d > 1.0 and ref_d < foe.max_hp * 0.149)
	a = _hero(cid, 1, ["premiere_frappe"], Vector3(0, 0, -2))
	var d1 := _hit(foe, a, amt)
	var d2 := _hit(foe, a, amt)
	check("Première frappe : 1er coup × 1,8 puis normal (%.0f, %.0f)" % [d1, d2], absf(d1 / d2 - 1.8) < 0.05 and absf(d2 / ref_d - 1.0) < 0.03)
	a = _hero(cid, 1, ["pacte_de_sang"], Vector3(0, 0, -3))
	check("Pacte de sang : dégâts × 1,25", absf(_hit(foe, a, amt) / ref_d - 1.25) < 0.04)
	a = _hero(cid, 1, ["roi_de_l_arene"], Vector3(50, 0, 50))
	ColiseeAugments._centers[0] = a.global_position
	for i in 5:
		ColiseeAugments.tick(1.0)
	var king := float(ColiseeAugments.state(a).king)
	check("Roi de l'arène : +3 %% par seconde au centre (%.2f après 5 s)" % king, absf(king - 0.15) < 0.01)
	a.global_position = Vector3(50, 0, 70)
	ColiseeAugments.tick(1.0)
	check("Roi de l'arène : retombe hors du centre", float(ColiseeAugments.state(a).king) < king)
	ColiseeAugments._centers.erase(0)
	# Bouclier d'entrée
	a = _hero(cid, 2, ["bouclier_entree"], Vector3(0, 0, 4))
	ColiseeAugments.begin_fight(null, [])
	var sh := ColiseeAugments.shield_left(a)
	var taken := _hit(a, base, amt, false)
	check("Bouclier d'entrée : 15 %% des PV au début du combat (%.0f), le coup est absorbé" % sh, absf(sh / a.max_hp - 0.15) < 0.01 and taken <= 0.5)
	# Sangsue
	a = _hero(cid, 1, ["sangsue"], Vector3(0, 0, -4))
	a.hp = a.max_hp * 0.5
	var hp_a := a.hp
	var dealt := _hit(foe, a, amt)
	check("Sangsue : soigné de 6 %% des dégâts (%.1f pour %.0f)" % [a.hp - hp_a, dealt], absf((a.hp - hp_a) / dealt - 0.06) < 0.01)
	# Braise, Givre, Foudre
	a = _hero(cid, 1, ["braise", "givre", "foudre"], Vector3(0, 0, -5))
	var foe2 := _hero(cid, 2, [], Vector3(1.5, 0, 2))
	foe2.hp = foe2.max_hp
	var f2 := foe2.hp
	_hit(foe, a, amt)
	check("Braise et Givre : la cible brûle et ralentit", foe.has_status("burn") and foe.has_status("chill"))
	check("Foudre : 40 %% du coup sur un voisin à 4 m (%.0f)" % (f2 - foe2.hp), f2 - foe2.hp > 0.5)
	foe.statuses.clear()
	foe._dots.clear()
	foe2.hp = foe2.max_hp
	# Marque du chasseur
	var hunter := _hero(cid, 1, ["marque_du_chasseur"], Vector3(0, 0, -6))
	var mate := _hero(cid, 1, [], Vector3(0, 0, -7))
	var before_mark := _hit(foe2, mate, amt)
	_hit(foe2, hunter, amt)
	var after_mark := _hit(foe2, mate, amt)
	check("Marque du chasseur : +12 %% des coups du trio sur sa cible (%.0f -> %.0f)" % [before_mark, after_mark], absf(after_mark / before_mark - 1.12) < 0.04)
	# Garde rapprochée
	var ward := _hero(cid, 2, ["garde_rapprochee"], Vector3(60, 0, 0))
	var near := _hero(cid, 2, [], Vector3(62, 0, 0))
	var far := _hero(cid, 2, [], Vector3(80, 0, 0))
	var dn := _hit(near, base, amt)
	var df := _hit(far, base, amt)
	check("Garde rapprochée : un allié à 6 m prend 10 %% de moins (%.0f / %.0f)" % [dn, df], absf(dn / df - 0.9) < 0.03)
	# Ronces
	var thorn := _hero(cid, 2, ["ronces"], Vector3(0, 0, 1))
	var hp_b := base.hp
	var d_th := _hit(thorn, base, amt)
	check("Ronces : 15 %% renvoyés à l'attaquant de près (%.1f pour %.0f)" % [hp_b - base.hp, d_th], absf((hp_b - base.hp) / d_th - 0.15) < 0.03)
	base.hp = base.max_hp
	# Coup de grâce
	a = _hero(cid, 1, ["coup_de_grace"], Vector3(0, 0, -8))
	var vic := _hero(cid, 2, [], Vector3(0, 0, 3))
	vic.hp = vic.max_hp * 0.1 + ref_d * 0.6
	_hit(vic, a, amt, false)
	check("Coup de grâce : sous 10 %% après le coup, K.O.", vic.is_dead)
	# Deuxième souffle
	var sv := _hero(cid, 2, ["deuxieme_souffle"], Vector3(0, 0, 5))
	sv.hp = 3.0
	_hit(sv, base, amt, false)
	var after1 := sv.hp
	sv.take_damage(amt, base)  # (dans la seconde : intouchable)
	check("Deuxième souffle : reste à 1 PV, intouchable 1 s (PV %.0f puis %.0f)" % [after1, sv.hp], not sv.is_dead and is_equal_approx(after1, 1.0)
		and is_equal_approx(sv.hp, 1.0))
	ColiseeAugments.state(sv).invuln = -1.0
	_hit(sv, base, amt, false)
	check("Deuxième souffle : une fois par combat", sv.is_dead)
	# Chasseur de têtes et Serment
	var hh := _hero(cid, 1, ["chasseur_de_tetes"], Vector3(0, 0, -9))
	var sid := int(hh._skills[0].id)
	hh._skill_ready[sid] = hh._time + 10.0
	var oath := _hero(cid, 2, ["serment"], Vector3(0, 0, 6))
	var v2 := _hero(cid, 2, [], Vector3(0, 0, 7))
	v2.hp = 1.0
	_hit(v2, hh, amt, false)
	check("Chasseur de têtes : un K.O. coupe la recharge de moitié (%.1f s)" % (float(hh._skill_ready[sid]) - hh._time),
		v2.is_dead and absf(float(hh._skill_ready[sid]) - hh._time - 5.0) < 0.05)
	check("Serment : un allié tombe, bouclier de 25 %% des PV", absf(ColiseeAugments.shield_left(oath) / oath.max_hp - 0.25) < 0.01)
	var kb: ColiseeBuild = ColiseeAugments.state(hh).b
	check("K.O. compté pour l'or de la manche", kb.round_kos >= 1)
	# Ancre
	a = _hero(cid, 2, ["ancre"], Vector3(0, 0, 8))
	a._knock = Vector3(6, 0, 0)
	ColiseeAugments.tick(0.016)
	a.add_status("root", 2.0)
	check("Ancre : ni repoussé ni attiré, contrôles deux fois plus courts", a._knock == Vector3.ZERO
		and absf(float(a.statuses.root) - a.clock - 1.0) < 0.01)
	# Écho
	var ecid := cid
	var long := {}
	for c2 in GameData.classes.keys():
		for s in GameData.class_data(String(c2)).get("skills", []):
			if long.is_empty() and float(s.cooldown) >= 10.0 and String(s.kind) != "buff":
				long = s
				ecid = String(c2)
	a = _hero(ecid, 1, ["echo"], Vector3(0, 0, -10))
	if not long.is_empty():
		a._skill_ready[int(long.id)] = a._time + float(long.cooldown)
		ColiseeAugments.tick(0.016)
		var tgt := _hero(cid, 2, [], Vector3(0, 0, 9))
		var hp_s := tgt.hp
		tgt.take_damage(amt, a)
		var d_e := hp_s - tgt.hp
		var hp_e := tgt.hp
		PvpCaps.elapsed += 0.7
		ColiseeAugments.tick(0.016)
		check("Écho : un sort long lancé, un 2e coup 0,6 s après à 50 %% (%.0f pour %.0f)" % [hp_e - tgt.hp, d_e], absf((hp_e - tgt.hp) / d_e - 0.5) < 0.05)
	else:
		check("Écho : une classe a un sort de 10 s ou plus", false)
	# Contre-coup
	a = _hero(cid, 1, ["contre_coup"], Vector3(90, 0, 0))
	var tg := _hero(cid, 2, [], Vector3(92, 0, 0))
	var hp_t := tg.hp
	a._dodge_until = a._time + 0.3
	ColiseeAugments.tick(0.016)
	check("Contre-coup : esquive près d'un ennemi -> riposte", tg.hp < hp_t)
	# Main verte
	var fl := ColiseeFlower.new()
	add_child(fl)
	fl.picked.connect(ColiseeAugments._on_flower)
	var g1 := _hero(cid, 1, ["main_verte"], Vector3(100, 0, 0))
	var g0 := _hero(cid, 1, [], Vector3(100, 0, 5))
	g1.hp = g1.max_hp * 0.3
	g0.hp = g0.max_hp * 0.3
	fl.pick(g0)
	fl.reset()
	fl.pick(g1)
	check("Main verte : fleur de vie deux fois plus forte (soin %.2f / %.2f)" % [g1.hp / g1.max_hp - 0.3, g0.hp / g0.max_hp - 0.3],
		absf((g1.hp / g1.max_hp - 0.3) / (g0.hp / g0.max_hp - 0.3) - 2.0) < 0.05 and float(g1.statuses.barrier) - g1.clock > ColiseeFlower.BARRIER * 1.9)
	# Ombre jumelle
	a = _hero(cid, 1, ["ombre_jumelle"], Vector3(110, 0, 0))
	ColiseeAugments.begin_fight(self, [])
	var dbl: Array = ColiseeAugments.doubles
	check("Ombre jumelle : un double à 40 %% des PV au début du combat", dbl.size() == 1 and absf((dbl[0][0] as Combatant).max_hp / ref_hp - 0.4) < 0.02
		and TeamMatch.team_of(dbl[0][0]) == 1)
	PvpCaps.elapsed += 10.5
	ColiseeAugments.tick(0.016)
	check("Ombre jumelle : il disparaît après 10 s", ColiseeAugments.doubles.is_empty())
	# plafond des dégâts : stat + Pacte + Trio + Roi -> × 1,6 au plus
	var big := _build(cid, 1, ["pacte_de_sang", "roi_de_l_arene"])
	big.stats = {"dmg_pct": 0.3}
	var bigr := TeamMatch.make_hero(cid, Colisee.LEVEL, 3, 1, 0)
	add_child(bigr)
	bigr.set_physics_process(false)
	bigr.passive = true
	heroes.append(bigr)
	ColiseeAugments.apply_hero(bigr, big, [big])
	ColiseeAugments.state(bigr).king = 0.3
	ColiseeAugments.state(bigr).first = true
	var dbig := _hit(foe, bigr, amt)
	check("plafond : bonus de dégâts cumulés (enclumes, Pacte, Roi) × %.1f au plus (%.2f)" % [ColiseeAugments.DEALT_CAP, dbig / ref_d], dbig / ref_d <= ColiseeAugments.DEALT_CAP + 0.03)
	print("[co_e] effets relevés : %s" % str(ColiseeAugments.counts))
	_clear()
	ColiseeAugments.stop()
	TeamMatch.end()
	ModeRules._extra.erase("colisee")
	await _frames(2)


# --- partie réelle ---------------------------------------------------------------------------------------------------------

func _game() -> void:
	ColiseeDirector.fallback = false
	var g := Colisee.begin("warrior", "classique", 3, 41)
	var world: Node = load("res://scenes/world.tscn").instantiate()
	get_tree().root.add_child.call_deferred(world)
	await _until(func(): return world.is_inside_tree() and world.get("director") != null and is_instance_valid(world.director.team), 600)
	var dd: ColiseeDirector = world.director.team
	await _until(func(): return dd.phase == "fight", 3600)
	var all := ColiseeBuild.all_of(g)
	check("partie : une construction par héros (6 × 3)", all.size() == 6 and all.all(func(r): return (r as Array).size() == 3))
	var pb := ColiseeBuild.player_build(g)
	check("le joueur a sa construction (place 0 du trio 0), ses pièces dans Profile.equipped", pb != null and pb.is_player and is_same(pb.gear, Profile.equipped))
	var ai_bad: Array = []
	for row in all:
		for b in row:
			var bb := b as ColiseeBuild
			if bb.augments.size() != 1 or not bb.offer.is_empty() or (bb.gold >= 6 and not bb.is_player):
				ai_bad.append(bb.summary())
	check("manche 1 : chaque héros a pris un atout, les IA ont dépensé leur or (le joueur : atout au temps écoulé) %s" % str(ai_bad.slice(0, 2)), ai_bad.is_empty())
	var states := 0
	var n := 0
	for f in dd.fights:
		for side in 2:
			for c in f.heroes[side]:
				n += 1
				if not ColiseeAugments.state(c).is_empty():
					states += 1
	check("chaque héros du combat porte sa construction (%d / %d)" % [states, n], states == n and n == 18)
	var p: Player = world.player
	var keep := pb.augments.duplicate()
	pb.augments = []
	ColiseeAugments.apply_hero(p, pb, ColiseeBuild.team_of(g, 0))
	var hp0 := p.max_hp
	pb.augments = ["peau_de_chene"]
	ColiseeAugments.apply_hero(p, pb, ColiseeBuild.team_of(g, 0))
	check("fiche du joueur : Peau de chêne × 1,15 (%.0f -> %.0f)" % [hp0, p.max_hp], absf(p.max_hp / hp0 - 1.15) < 0.01)
	pb.augments = keep
	ColiseeAugments.apply_hero(p, pb, ColiseeBuild.team_of(g, 0))
	await _until(func(): return dd.phase in ["recap", "prep"] or g.round_n > 1, 60 * 100)
	check("fin des combats : couche d'effets arrêtée (ombres, échos)", not ColiseeAugments.fighting and ColiseeAugments.doubles.is_empty())
	print("[co_e] effets en combat réel : %s" % str(ColiseeAugments.counts))
	check("des effets d'atouts déclenchés en combat réel", not ColiseeAugments.counts.is_empty())
	await _until(func(): return g.round_n >= 2 and dd.phase in ["countdown", "fight"], 900)
	var gold_ok := true
	for row in all:
		for b in row:
			gold_ok = gold_ok and (b as ColiseeBuild).gold_log.size() == 2
	check("manche 2 : l'or de la manche versé à chacun", gold_ok)
	dd.abandon_stay = true
	dd.abandon()
	check("abandon : couche d'effets refermée", not ColiseeAugments.active)
	get_tree().paused = false
	world.queue_free()
	await get_tree().process_frame
	Run.active = false
	Profile.in_run = false
	ModeRules._extra.erase("colisee")
	ColiseeDirector.fallback = true
