extends Node
## Lot CO-F : économie du Colisée (core/colisee_anvil.gd, rapport conception/benchmark/R_CO_F.md). Or de manche (base,
## victoire, K.O., Tirelire, Mise), enclumes (Stat, Pièce : emplacement vide d'abord, jamais d'arme ; Panoplie ; Éclat
## offerte), choix d'une option parmi trois, revente au prix payé pendant la préparation puis à moitié, annulation d'un bonus
## de stat, sorts des manches 3 et 6, préparation des IA et choix automatique du joueur (jamais au hasard), pièces portées par
## un héros scripté, et une économie de partie complète sur 10 manches (machine seule) dont on garde les chiffres.
## godot --headless --path game res://tests/test_co_f.tscn

var fails := 0


func check(label: String, ok: bool) -> void:
	print(("OK    " if ok else "ÉCHEC ") + label)
	if not ok:
		fails += 1


func _ready() -> void:
	Settings.reset_all()
	Profile.selected_class = "warrior"
	Run.class_id = "warrior"
	_income()
	_anvils()
	_spells()
	_prep()
	await _gear_on_hero()
	_economy()
	print("TOUT EST OK (0 échec(s))" if fails == 0 else "ÉCHECS : %d" % fails)
	get_tree().quit(fails)


func _game(seed_value := 9) -> Colisee:
	var g := Colisee.new("classique", seed_value)
	g.classes = Colisee.compose_teams(g.n, "", g.rng)
	g.team_diffs = Colisee.team_difficulties(3, g.n, g.rng)
	g.set_meta("co_player", false)
	ColiseeBuild.setup(g)
	return g


func _income() -> void:
	var b := ColiseeBuild.new()
	b.cid = "warrior"
	check("manche 1 : 10 or", int(ColiseeAnvil.income(b, 1, false, false).total) == 10)
	b.round_kos = 2
	check("victoire avec 2 K.O. : 10 + 3 + 4 = 17", int(ColiseeAnvil.income(b, 2, true, true).total) == 17)
	b.round_kos = 5
	check("K.O. : 3 comptés au plus (10 + 6)", int(ColiseeAnvil.income(b, 2, false, true).total) == 16)
	b.round_kos = 0
	check("exempt : la base seule", int(ColiseeAnvil.income(b, 3, false, false).total) == 10)
	b.augments = ["tirelire"]
	check("Tirelire : +4 par manche", int(ColiseeAnvil.income(b, 2, false, true).total) == 14)
	b.augments = ["mise"]
	check("Mise : victoire +15 de plus (28), défaite : aucun or de manche (0)", int(ColiseeAnvil.income(b, 2, true, true).total) == 28
		and int(ColiseeAnvil.income(b, 2, false, true).total) == 0)


func _anvils() -> void:
	var g := _game()
	g.round_n = 2
	var b := ColiseeBuild.of(g, 1, 0)
	b.diff = 3
	b.gold = 5
	check("enclume de stat : refusée sans 6 or", not ColiseeAnvil.open_anvil(b, "stat", g))
	b.gold = 100
	check("enclume d'éclat : jamais en boutique (offerte seulement)", not ColiseeAnvil.open_anvil(b, "eclat", g))
	check("enclume de stat : 6 or, trois bonus différents", ColiseeAnvil.open_anvil(b, "stat", g) and b.gold == 94 and b.anvil.options.size() == 3
		and _distinct(b.anvil.options.map(func(o): return String(o.key))))
	check("une seule enclume ouverte à la fois", not ColiseeAnvil.open_anvil(b, "piece", g))
	var k := String(b.anvil.options[0].key)
	ColiseeAnvil.choose(b, 0, g)
	check("bonus de stat gardé (%s %.2f)" % [k, float(b.stats.get(k, 0.0))], is_equal_approx(float(b.stats.get(k, 0.0)), float(ColiseeAnvil.STATS[k].value)) and b.anvil.is_empty())
	ColiseeAnvil.undo_stat(b, 0)
	check("bonus de stat annulé pendant la préparation : remboursé", b.gold == 100 and not b.stats.has(k))
	b.stats["cdr"] = float(ColiseeAnvil.STATS.cdr.cap)
	var capped := true
	for i in 30:
		for o in ColiseeAnvil.options(b, "stat", 2, g.rng):
			capped = capped and String(o.key) != "cdr"
	check("bonus de stat plafonnés (la recharge au plafond n'est plus proposée)", capped)
	b.stats = {}
	# pièces : emplacements vides d'abord, jamais d'arme
	var slots_seen := {}
	var weapon := false
	for i in 4:
		check("enclume de pièce : 12 or, trois pièces" if i == 0 else "pièce %d" % (i + 1), ColiseeAnvil.open_anvil(b, "piece", g) and b.anvil.options.size() == 3)
		for o in b.anvil.options:
			weapon = weapon or String(o.slot) in ["weapon", "offhand"]
		var opts_empty := (b.anvil.options as Array).all(func(o): return not b.gear.has(String(o.slot)))
		check("  emplacements vides d'abord (%s)" % str(b.anvil.options.map(func(o): return String(o.slot))), opts_empty)
		var s := String(b.anvil.options[0].slot)
		ColiseeAnvil.choose(b, 0, g)
		slots_seen[s] = true
	check("jamais d'arme : celle de la classe reste", not weapon)
	check("pièces portées : prix payé et manche notés", b.gear.values().all(func(it): return int(it.co_price) == 12 and int(it.co_round) == 2))
	var s0 := String(b.gear.keys()[0])
	var g_before := b.gold
	check("revente pendant la préparation de l'achat : au prix payé (12)", ColiseeAnvil.sell(b, s0, g) == 12 and b.gold == g_before + 12)
	g.round_n = 3
	var s1 := String(b.gear.keys()[0])
	check("revente plus tard : à moitié (6)", ColiseeAnvil.sell(b, s1, g) == 6 and not b.gear.has(s1))
	# équipement plein : améliorations ou remplacements des pièces portées
	for s in ColiseeAnvil.SLOTS:
		if not b.gear.has(s):
			b.gear[s] = RoyaleLoot._piece(Royale.CHEST_TIERS[0], Colisee.LEVEL, b.cid, s)
			b.gear[s]["co_price"] = 12
			b.gear[s]["co_round"] = 1
	b.gold = 100
	ColiseeAnvil.open_anvil(b, "piece", g)
	var ups: Array = b.anvil.options
	check("équipement plein : améliorations ou remplacements (%s)" % str(ups.map(func(o): return String(o.get("up", "remplace")))),
		not ups.is_empty() and ups.all(func(o): return String(o.slot) in ColiseeAnvil.SLOTS and float(o.gain) > 0.0))
	var up_i := -1
	for i in ups.size():
		if String(ups[i].get("up", "")) != "":
			up_i = i
	if up_i >= 0:
		var us := String(ups[up_i].slot)
		ColiseeAnvil.choose(b, up_i, g)
		check("amélioration : la pièce garde ce qu'elle a coûté (+12)", int(b.gear[us].co_price) == 24)
	else:
		ColiseeAnvil.choose(b, 0, g)
	# panoplie : une panoplie déjà portée
	var b2 := ColiseeBuild.of(g, 2, 0)
	b2.gold = 100
	check("enclume de panoplie sans pièce de panoplie : trois panoplies différentes", ColiseeAnvil.open_anvil(b2, "panoplie", g)
		and _distinct(b2.anvil.options.map(func(o): return String(o.get("set", "")))) and b2.anvil.options.all(func(o): return String(o.get("set", "")) != ""))
	var sid := String(b2.anvil.options[0].set)
	ColiseeAnvil.choose(b2, 0, g)
	ColiseeAnvil.open_anvil(b2, "panoplie", g)
	check("enclume de panoplie : pièces de la panoplie portée (%s)" % sid, b2.anvil.options.all(func(o): return String(o.get("set", "")) == sid)
		and b2.anvil.options.all(func(o): return not b2.gear.has(String(o.slot)) or String(b2.gear[String(o.slot)].get("set", "")) != sid))
	ColiseeAnvil.choose(b2, 0, g)
	check("deux pièces d'une panoplie : son bonus compte", int(Items.set_counts(b2.gear).get(sid, 0)) == 2)
	# éclat offerte
	var b3 := ColiseeBuild.of(g, 3, 0)
	b3.gifts = ["eclat"]
	var gold3 := b3.gold
	check("enclume d'éclat offerte : gratuite, pièces légendaires", ColiseeAnvil.open_anvil(b3, "eclat", g, true) and b3.gold == gold3
		and b3.anvil.options.all(func(o): return int(o.item.rarity) == Items.LEGENDARY) and b3.gifts.is_empty())
	ColiseeAnvil.choose(b3, 0, g)
	var icons_ok := ColiseeAnvil.ANVILS.values().all(func(a): return Ico.has(String(a.ico))) and ColiseeAnvil.STATS.values().all(func(x): return Ico.has(String(x.ico)))
	check("enclumes et bonus de stat : pictogrammes Ico présents", icons_ok)
	check("texte d'une option : français, sans identifiant", not ColiseeAnvil.option_text({"kind": "stat", "key": "hp_pct"}).contains("_"))


func _distinct(a: Array) -> bool:
	var d := {}
	for x in a:
		d[x] = true
	return d.size() == a.size()


func _spells() -> void:
	var g := _game(13)
	var b := ColiseeBuild.of(g, 1, 1)
	var pool := ColiseeAnvil.spell_pool(b)
	var kinds_ok := pool.all(func(id): return _kind(b.cid, int(id)) != "buff" and _kind(b.cid, int(id)) != "heal")
	check("sorts d'un héros scripté : ses sorts d'attaque pas encore pris (%d)" % pool.size(), kinds_ok and not pool.is_empty())
	g.round_n = 2
	ColiseeAnvil.round_start(g)
	check("manche 2 : pas de sort de plus", b.spell_slots == 0)
	g.round_n = 3
	ColiseeAnvil.round_start(g)
	check("manche 3 : une place de sort de plus, prise par l'IA (%s)" % str(b.spells), b.spell_slots == 1 and b.spells.size() == 1 and b.spell_offer.is_empty()
		and not int(b.spells[0]) in [])
	g.round_n = 6
	ColiseeAnvil.round_start(g)
	check("manche 6 : un deuxième sort de plus", b.spell_slots == 2 and b.spells.size() == 2 and b.spells[0] != b.spells[1])
	# joueur : enchaînement d'une touche
	Run.start("warrior")
	Run.skills = []
	Run.chains = {}
	for sk in Run.class_data().get("skills", []).slice(0, 4):
		Run.skills.append({"id": int(sk.id), "rank": 1})
	var pb := ColiseeBuild.new()
	pb.cid = "warrior"
	pb.is_player = true
	pb.spell_slots = 1
	ColiseeAnvil.open_spells(pb)
	var pick := int(pb.spell_offer[0])
	ColiseeAnvil.take_spell(pb, 0)
	check("joueur : le sort de plus devient l'enchaînement d'une de ses quatre touches", Run.skills.size() == 4
		and not Run.skill_entry(pick).is_empty() and Run.all_skills().size() == 5)
	Run.active = false


func _kind(cid: String, id: int) -> String:
	for s in GameData.class_data(cid).get("skills", []):
		if int(s.id) == id:
			return String(s.kind)
	return ""


func _prep() -> void:
	var g := _game(21)
	g.next_round()
	ColiseeAnvil.round_start(g)
	var ok := true
	var spent := true
	for row in ColiseeBuild.all_of(g):
		for b in row:
			var bb := b as ColiseeBuild
			ok = ok and bb.augments.size() == 1 and bb.offer.is_empty() and bb.ready
			spent = spent and bb.gold < (6 if bb.diff >= 1 else 13)
	check("préparation des IA : atout pris, prêtes", ok)
	check("préparation des IA : l'or dépensé (enclumes)", spent)
	# joueur sans réponse : la meilleure option, jamais au hasard
	var g2 := Colisee.new("classique", 22)
	g2.classes = Colisee.compose_teams(g2.n, "warrior", g2.rng)
	g2.team_diffs = Colisee.team_difficulties(0, g2.n, g2.rng)
	ColiseeBuild.setup(g2)
	var pb := ColiseeBuild.player_build(g2)
	check("partie avec le joueur : sa construction (Guerrier, place 0)", pb != null and pb.is_player)
	g2.next_round()
	ColiseeAnvil.round_start(g2)
	check("le joueur choisit lui-même (rien n'est pris pour lui pendant la préparation)", pb.augments.is_empty() and pb.offer.size() == 3)
	var ctx := ColiseeAugments.context_for(g2, pb)
	var best := 0
	for i in 3:
		if ColiseeAugments.score(pb.offer[i], pb, ctx) > ColiseeAugments.score(pb.offer[best], pb, ctx):
			best = i
	var want := String(pb.offer[best])
	pb.diff = 0
	ColiseeAnvil.auto_finish(g2)
	check("temps écoulé : l'atout le mieux noté (%s), même pour un joueur noté Facile" % want, pb.augments == [want] and pb.ready)
	check("temps écoulé : l'or du joueur n'est pas dépensé pour lui", pb.gold == 10)


func _gear_on_hero() -> void:
	Colisee.register_rules()
	TeamMatch.begin(Colisee.MODE, 2)
	var g := _game(31)
	var b := ColiseeBuild.of(g, 1, 0)
	b.gold = 200
	for i in 6:
		ColiseeAnvil.open_anvil(b, "piece", g)
		ColiseeAnvil.choose(b, 0, g)
	var bare := TeamMatch.make_hero(b.cid, Colisee.LEVEL, 3, 1, 0)
	var geared := TeamMatch.make_hero(b.cid, Colisee.LEVEL, 3, 1, 0, b.gear)
	add_child(bare)
	add_child(geared)
	check("héros scripté équipé de ses pièces : plus de PV (%.0f -> %.0f)" % [bare.max_hp, geared.max_hp], geared.max_hp > bare.max_hp
		and geared.gear.size() == b.gear.size())
	bare.queue_free()
	geared.queue_free()
	TeamMatch.end()
	ModeRules._extra.erase("colisee")
	await get_tree().process_frame


## Économie d'une partie Classique sur 10 manches (machine seule, combats tirés au hasard) : or reçu, pièces, bonus,
## atouts et sorts par héros à la fin ; rien de négatif.
func _economy() -> void:
	var rows: Array = []
	for seed_value in [101, 102, 103]:
		var g := _game(seed_value)
		while not g.is_over() and g.round_n < 10:
			g.next_round()
			ColiseeAnvil.round_start(g)
			var res: Array = []
			for p in g.current.pairs:
				var a := int(p[0])
				var bb := int(p[1])
				var w := a if g.rng.randf() < 0.5 else bb
				res.append({"a": a, "b": bb, "winner": w, "left_a": 0.5, "left_b": 0.5, "ko_a": 3 if w == a else 1, "ko_b": 3 if w == bb else 1})
				for t in [a, bb]:
					for x in ColiseeBuild.team_of(g, t):
						(x as ColiseeBuild).round_kos = g.rng.randi_range(0, 2) if t == w else g.rng.randi_range(0, 1)
			g.report(res)
		for row in ColiseeBuild.all_of(g):
			for b in row:
				var bb := b as ColiseeBuild
				rows.append({"gold": bb.gold_total, "left": bb.gold, "pieces": bb.gear.size(), "stats": bb.stats.size(), "aug": bb.augments.size(),
					"spells": bb.spells.size(), "pool": ColiseeAnvil.spell_pool(bb).size(), "out": bool(g.out[bb.team])})
	var alive := rows.filter(func(r): return not r.out)
	var neg := rows.filter(func(r): return int(r.left) < 0)
	var tot := 0.0
	var pcs := 0.0
	for r in alive:
		tot += float(r.gold)
		pcs += float(r.pieces)
	var n := maxf(1.0, alive.size())
	print("[co_f] économie (10 manches, %d héros en lice) : or reçu moyen %.0f, pièces %.1f, atouts %s, sorts %s" % [alive.size(), tot / n, pcs / n,
		str(alive.map(func(r): return int(r.aug)).slice(0, 6)), str(alive.map(func(r): return int(r.spells)).slice(0, 6))])
	check("économie : jamais d'or négatif", neg.is_empty())
	check("économie : 10 manches -> ~120-200 or reçus, 5 à 8 pièces (%.0f, %.1f)" % [tot / n, pcs / n], tot / n >= 110.0 and tot / n <= 210.0 and pcs / n >= 4.5 and pcs / n <= 8.0)
	check("économie : 4 atouts (moins après une fusion) et 2 sorts de plus à la manche 10 (s'il en reste à la classe)", alive.all(func(r): return int(r.aug) >= 2 and int(r.spells) >= mini(2, int(r.spells) + int(r.pool))))
