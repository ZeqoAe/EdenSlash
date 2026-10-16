extends Node
## Passe E6 de la nuit du 15/10 : équilibrage global par mesure (conception/nuit_15_10/R_E6.md, DESIGN.md « Équilibrage
## global (passe E6) »). Règles : insignes d'une run arrêtée sur la 1re carte au prorata du temps, monstres comptés
## plafonnés par carte, formules de la Survie plafonnées par époque, lâchers des monstres ordinaires plafonnés par
## carte, gemmes de la Survie à l'échelle des pièces, écart d'époque des monstres. Puis la simulation d'un compte
## neuf (tools/progression_sim.gd) doit rester dans les bornes de la conception.
## godot --headless --path game res://tests/test_e6.tscn [-- --full]  (--full : 12 comptes sur 70 h au lieu de 6 sur 45 h)

const Sim := preload("res://tools/progression_sim.gd")

var fails := 0


func check(label: String, ok: bool) -> void:
	print(("OK    " if ok else "ÉCHEC ") + label)
	if not ok:
		fails += 1


func _ready() -> void:
	Training.active = true
	Settings.reset_all()
	Profile.selected_class = "warrior"
	Profile.reset_all()
	_test_insignia()
	_test_kill_cap()
	_test_scrolls()
	_test_farm_cap()
	_test_gems()
	_test_epochs()
	_test_dismantle()
	_test_gates()
	_test_a7_decote()
	_test_h7_model()
	await _test_progression()
	await _test_a7_refonte()
	await _test_h7_heros()
	Run.active = false
	Run.survival = false
	Profile.reset_all()
	print("TOUT EST OK (0 échec(s))" if fails == 0 else "ÉCHECS : %d" % fails)
	get_tree().quit(fails)


## Insignes : prorata du temps sur la 1re carte, rien ne change dès la 2e carte ni pour une victoire.
func _test_insignia() -> void:
	var full := Economy.survival_insignia(1, 40, 1, 1, false)
	check("défaite en carte 1 sans durée connue : barème d'A5, monstres / 40 (%d)" % full, full == 25 + 25 + 1 + 2)
	check("défaite après %d min sur la 1re carte : participation entière" % int(Economy.ENTRY_MINUTES),
		Economy.survival_insignia(1, 40, 1, 1, false, Economy.ENTRY_MINUTES) == full)
	var quick := Economy.survival_insignia(1, 10, 0, 1, false, 1.0)
	check("abandon au bout d'une minute (10 monstres) : %d insignes (≤ 7)" % quick, quick <= 7)
	check("carte 2 atteinte : pas de prorata", Economy.survival_insignia(2, 600, 5, 1, false, 0.5) == Economy.survival_insignia(2, 600, 5, 1, false))
	check("victoire : barème inchangé", Economy.survival_insignia(3, 600, 10, 2, true, 0.0) == Economy.survival_insignia(3, 600, 10, 2, true))
	# à l'heure : la boucle « abandon à 1 min » et la défaite express rapportent moins qu'une Survie gagnée
	# Survie gagnée réelle (journal de run : ≈ 2 500 monstres sur les 3 cartes, 35 min)
	var win_h := roundi(Economy.survival_insignia(3, 2500, 20, 1, true) * 60.0 / 35.5)
	var abandon_h := Economy.survival_insignia(1, 10, 0, 1, false, 1.0) * 60.0 / 1.5
	var suicide_h := Economy.survival_insignia(1, 150, 1, 1, false, 3.0) * 60.0 / 3.5
	check("boucle « abandon à 1 min » : %d / h < Survie gagnée %d / h" % [roundi(abandon_h), win_h], abandon_h < win_h)
	check("boucle « défaite à 3 min » : %d / h < Survie gagnée %d / h" % [roundi(suicide_h), win_h], suicide_h < win_h)
	# une vraie défaite d'un débutant (5 min, 120 monstres) paie toujours une pièce de l'époque I en deux runs
	var cheapest := 9999
	for e in SlotChests.pool("head", 1, 1) + SlotChests.pool("chest", 1, 1):
		cheapest = mini(cheapest, Economy.base_price(e))
	var beginner := Economy.survival_insignia(1, 120, 1, 1, false, 5.0)
	check("défaite d'un débutant (5 min) : %d insignes, une pièce (%d) en 2 runs" % [beginner, cheapest], beginner * 2 >= cheapest)
	# dans une vraie run : Run.finish lit le temps de la carte dans le journal
	Profile.insignia = 0
	Run.start_survival("warrior", 1)
	RunJournal._time = 60.0
	Run.kills = 10
	Run.stage = 1
	Run.finish("abandon")
	check("Run.finish : abandon après 1 min de carte = %d insignes (prorata)" % Run.insignia_gain, Run.insignia_gain == Economy.survival_insignia(1, 10, 0, 1, false, 1.0))
	Profile.end_run_survival()


func _test_kill_cap() -> void:
	Profile.insignia = 0
	Run.start_survival("warrior", 1)
	RunJournal._time = 900.0
	Run.kills = 12000
	Run.elites = 0
	Run.stage = 1
	Run.finish("defaite")
	var capped := Economy.survival_insignia(1, Run.KILL_CAP_PER_MAP, 0, 1, false, 15.0)
	check("rage sur la 1re carte (12 000 monstres) : insignes comptés comme %d monstres (%d)" % [Run.KILL_CAP_PER_MAP, Run.insignia_gain], Run.insignia_gain == capped)
	check("maîtrise : monstres plafonnés aussi (%d ≤ %d)" % [Run.expertise_gain, Run.max_level * 15 + Run.KILL_CAP_PER_MAP / 2 + 2000],
		Run.expertise_gain <= Run.max_level * 15 + Run.KILL_CAP_PER_MAP / 2 + 2000)
	Profile.end_run_survival()


func _test_scrolls() -> void:
	Run.active = true
	Run.survival = true
	var ok := true
	for ep in range(1, 5):
		Run.epoch = ep
		var top := 0
		for i in 400:
			var k := Craft.loot_for("chest2", 90, 2, 40)
			if k.begins_with("scroll:"):
				top = maxi(top, int(k.split(":")[2]))
		ok = ok and top <= int(Craft.SURVIVAL_SCROLL_MAX[ep - 1]) and top >= 1
	check("Survie : formules plafonnées par époque %s" % str(Craft.SURVIVAL_SCROLL_MAX), ok)
	Run.active = false
	Run.survival = false
	var hub := 0
	for i in 400:
		var k := Craft.loot_for("chest2", 90, 2)
		if k.begins_with("scroll:"):
			hub = maxi(hub, int(k.split(":")[2]))
	check("hors Survie (Siège, coffres d'activité) : formules jusqu'au niveau 9 (%d)" % hub, hub == Craft.MAX_SCROLL_LV)
	check("formules Lv8-9 : jamais en Survie", int(Craft.SURVIVAL_SCROLL_MAX.max()) < 8)


func _test_farm_cap() -> void:
	var d := RunDirector.new()
	var m := Monster.new()
	Run.survival = true
	var given := 0
	for i in 100:
		if not d._farm_capped(m, "chests"):
			given += 1
	check("monstres ordinaires : %d coffres au plus par carte (%d)" % [int(RunDirector.FARM_CAP.chests), given], given == int(RunDirector.FARM_CAP.chests))
	m.is_elite = true
	check("élites : jamais plafonnées", not d._farm_capped(m, "chests"))
	m.is_elite = false
	Run.survival = false
	check("hors Survie : pas de plafond", not d._farm_capped(m, "supplies"))
	m.free()
	d.free()


func _test_gems() -> void:
	Run.active = true
	Run.survival = true
	var item := {"slot": "chest", "sockets": [{"type": "garnet", "tier": 4}]}
	var vals := []
	for lv in [1, 15, 35]:
		Run.hero_level = lv
		vals.append(float(Craft.extra_stats(item).hp))
	# torse mythique +0 de référence (REF hp 60) au même niveau
	var chest15 := 60.0 * 1.22 * pow(1.08, 14)
	check("gemme royale de PV : %.0f / %.0f / %.0f aux niveaux 1 / 15 / 35 (suit le niveau comme les pièces)" % vals,
		vals[0] < vals[1] and vals[1] < vals[2] and absf(vals[2] / vals[1] - pow(1.08, 20)) < 0.01)
	check("au niveau 15 : la gemme vaut moins qu'un torse +0 (%.0f < %.0f)" % [vals[1], chest15], vals[1] < chest15)
	Run.active = false
	Run.survival = false
	check("hors Survie : pleine valeur (duels inchangés)", is_equal_approx(float(Craft.extra_stats(item).hp), 320.0))


func _test_epochs() -> void:
	# lot H4a : M′ par carte (Epochs.MAP_MULT) à la place du multiplicateur par époque ; la plus faible carte de chaque époque
	# reste au-dessus de la plus forte de l'époque d'avant (l'équipement de la précédente bien monté est attendu)
	var lo := []
	var hi := []
	for ep in range(1, 5):
		var row: Array = Epochs.MAP_MULT[ep - 1]
		lo.append(row.min())
		hi.append(row.max())
	check("monstres : 1re carte ≤ ×1 (compte neuf, passes P5 et H4a), de plus en plus forts d'une époque à l'autre (%s)" % str(Epochs.MAP_MULT),
		float(Epochs.MAP_MULT[0][0]) <= 1.0 and float(lo[1]) > float(hi[0]) and float(lo[2]) > float(hi[1]) and float(lo[3]) > float(hi[2]))
	check("époque IV : bien plus forte que l'époque III (un équipement complet est attendu)", float(lo[3]) >= 5.0 * float(lo[2]))


## Pas de boucle insignes → cristaux : une pièce rachetable à l'Armurerie ne se démonte que pour ses améliorations.
func _test_dismantle() -> void:
	var e: Dictionary = SlotChests.pool("head", 1, 1)[0]
	var it := GearShopPage.make(e)
	Profile.seen_gear = []
	check("pièce jamais découverte : 3 cristaux au démontage", int(Items.disassemble_yield(it).crystal) == 3)
	Profile.seen_gear = [int(e.id)]
	var price := Economy.armory_price(e, {Economy.tier_key(e): true})
	check("pièce rachetable (%d insignes au palier entamé) : 0 cristal à +0" % price, int(Items.disassemble_yield(it).crystal) == 0)
	it["upgrade"] = 6
	check("pièce rachetable à +6 : la part des améliorations (2)", int(Items.disassemble_yield(it).crystal) == 2)
	Profile.seen_gear = []


## Simulation d'un compte neuf (modèle de joueur « moyen », voir R_E6.md) : bornes de la conception.
func _test_progression() -> void:
	var full := "--full" in OS.get_cmdline_user_args()
	var sim: Node = Sim.new()
	sim.quiet = true
	add_child(sim)
	# 1re victoire d'époque I : beaucoup de comptes (le nombre de runs varie beaucoup d'un compte à l'autre), 6 h au plus
	var first: Dictionary = sim.simulate(40 if full else 24, "moyen", 6.0, 5)
	var e1: Dictionary = sim.milestone(first, "epoch_1")
	var res: Dictionary = sim.simulate(12 if full else 6, "moyen", 70.0 if full else 45.0, 11)
	var e2: Dictionary = sim.milestone(res, "epoch_2")
	var e4: Dictionary = sim.milestone(res, "epoch_4")
	var kit: Dictionary = sim.milestone(res, "kit_1")
	print("      simulation : époque I %s h (%d runs), II %s h, IV %s h, équipement complet %s h" % [e1.h, e1.runs, e2.h, e4.h, kit.h])
	check("1re victoire d'époque I : 4 à 12 runs (cible 5-8) — %d" % int(e1.runs), int(e1.runs) >= 4 and int(e1.runs) <= 12)
	check("époque II : pas avant 4 h — %s h" % e2.h, float(e2.h) < 0.0 or float(e2.h) >= 4.0)
	check("époque IV : hors de portée avant 15 h — %s h" % e4.h, float(e4.h) < 0.0 or float(e4.h) >= 15.0)
	check("équipement complet d'une classe (+10, gemmes, enchantements) : 12 h ou plus — %s h" % kit.h, float(kit.h) < 0.0 or float(kit.h) >= 12.0)
	# passe P5 : verrous de PE recalés sur la PE réelle du compte simulé
	var e3: Dictionary = sim.milestone(res, "epoch_3")
	var h1: Dictionary = sim.milestone(res, "open_dungeon_1")
	var m2: Dictionary = sim.milestone(res, "open_dungeon_2")
	print("      verrous : Héroïque %s h (époque III %s h), Mythique %s h (époque IV %s h), Siège Mythique %s h, légendaire niv. 90 %s h" % [h1.h, e3.h, m2.h, e4.h,
		sim.milestone(res, "open_siege_2").h, sim.milestone(res, "legend_90").h])
	# passe P14 : sur 6 comptes la médiane de l'époque III saute par paliers (seed 11 : 20,0 h ; seed 12 : 17,6 h ; 10 comptes, seed 11 :
	# 20,9 h) alors que le verrou reste à 14-16 h : le rapport varie de 69 % à 92 % selon le tirage, 78 % sur 20 comptes (R_P14) ; borne à 65 %
	check("P5 : 1er donjon Héroïque après l'époque II et vers l'époque III (≥ 65 %% de son temps) — %s h / %s h" % [h1.h, e3.h],
		float(h1.h) > float(e2.h) and float(h1.h) >= 0.65 * float(e3.h))
	# passe P11 : les boss à PV fixes ralentissent les époques, pas la PE : le verrou Mythique s'ouvre un peu avant la fin de
	# l'époque IV (20 comptes : 95 % de son temps ; 6 comptes ici, bruit ± 10 %)
	check("P5 : Mythique pas avant la fin de l'époque IV (≥ 80 %% de son temps) — %s h / %s h" % [m2.h, e4.h], float(m2.h) < 0.0 or float(m2.h) >= 0.8 * float(e4.h))
	sim.queue_free()


## Lot A7 : décote de palier de l'outil (--decote, émulée sur une copie des pièces ; le vrai réglage est le lot A6).
func _test_a7_decote() -> void:
	var m41: Dictionary = Epochs.map_def(4, 1)
	var low := {"slot": "chest", "eden": 1, "level": 43}
	var at := {"slot": "chest", "eden": 1, "level": int(m41.armor)}
	var tiny := {"slot": "chest", "eden": 1, "level": 5}
	var f_low := Sim.decote_factor(low, 4, 1)
	check("décote : pièce au palier ×1, pièce 43 en carte IV-1 ×%.2f, plancher ×%.1f" % [f_low, Sim.DECOTE_FLOOR],
		Sim.decote_factor(at, 4, 1) == 1.0 and is_equal_approx(f_low, 43.0 / float(m41.armor)) and Sim.decote_factor(tiny, 4, 1) == Sim.DECOTE_FLOOR)
	check("décote : l'arme suit le palier d'arme de la carte, une pièce sans niveau d'Eden n'est pas touchée",
		is_equal_approx(Sim.decote_factor({"slot": "weapon", "eden": 1, "level": 43}, 4, 1), clampf(43.0 / float(m41.weapon), 0.5, 1.0))
		and Sim.decote_factor({"slot": "chest", "level": 5}, 4, 1) == 1.0)
	# sur une vraie pièce d'époque I : le niveau de puissance en run baisse, la pièce d'origine reste intacte
	var e: Dictionary = SlotChests.pool("chest", 1, 3)[0]
	var it := Items.from_eden(e)
	var g := Sim.decoted({"chest": it}, 4, 1, 35)
	Run.active = true
	Run.hero_level = 35
	var before := Items.power_level(it)
	var after := Items.power_level(g.chest)
	var stats_lower := float(Items.stats(g.chest).values().reduce(func(a, b): return a + b, 0.0)) < float(Items.stats(it).values().reduce(func(a, b): return a + b, 0.0))
	Run.active = false
	check("décote : pièce %d en carte IV-1 au niveau 35 : puissance %d -> %d, stats plus basses, original intact" % [int(it.level), before, after],
		after < before and after == maxi(1, roundi(mini(35, Items.power_cap(it)) * Sim.decote_factor(it, 4, 1))) and stats_lower and it.has("eden"))


## Lot A7 : la refonte de la conception (REFONTE_AVENTURE.md §3.1, colonne H : --refonte --hubvalue --decote, monstres
## 0,85 / 1,3 / 2,3 / 4,4) dans l'outil : donjons dès l'époque I, plans de donjon fabriqués, équipement 80-90 correct vers 30 h.
## Mesure complète (12 comptes, 50 h, graine 1, colonnes A / E / B / D / G / H) : voir l'en-tête de tools/progression_sim.gd.
func _test_a7_refonte() -> void:
	var sim: Node = Sim.new()
	sim.quiet = true
	sim.refonte = true
	sim.hubvalue = true
	sim.decote = true
	sim.mult = [0.85, 1.3, 2.3, 4.4]
	add_child(sim)
	var res: Dictionary = sim.simulate(6, "moyen", 45.0, 11)
	var e1: Dictionary = sim.milestone(res, "epoch_1")
	var d0: Dictionary = sim.milestone(res, "dungeon_0")
	var e4: Dictionary = sim.milestone(res, "epoch_4")
	var k80: Dictionary = sim.milestone(res, "kit80_ok")
	var plans := 0
	var crafted := 0
	for acc in res.accounts:
		plans += (acc.get("dplans", {}) as Dictionary).size()
		crafted += int(acc.get("dcrafted", 0))
	print("      refonte (H) : époque I %s h, 1er donjon %s h, époque IV %s h, équipement 80-90 correct %s h (%.0f %%), %d plans, %d pièces fabriquées sur plan"
		% [e1.h, d0.h, e4.h, k80.h, 100.0 * float(k80.share), plans, crafted])
	check("A7 : époque I à peine changée par la refonte (2 à 5 h ; 6 comptes, bruit ± 1 h) — %s h" % e1.h, float(e1.h) >= 2.0 and float(e1.h) <= 5.0)
	check("A7 : 1er donjon juste après l'époque I (≤ époque I + 1 h) — %s h" % d0.h, float(d0.h) >= 0.0 and float(d0.h) <= float(e1.h) + 1.0)
	check("A7 : plans de donjon gagnés et fabriqués (%d plans, %d pièces)" % [plans, crafted], plans >= 6 and crafted >= 1)
	check("A7 : équipement 80-90 correct atteint vers 30 h (≤ 40 h) — %s h" % k80.h, float(k80.h) > 15.0 and float(k80.h) <= 40.0)
	sim.queue_free()


## Lot H7 : modèle du niveau de héros de l'outil (--heros, conception/progression/NIVEAU_HEROS.md §1.3-§1.4) : courbe d'XP,
## écart de niveau, bandes des cartes, MAP_MULT, port des pièces ; sans le drapeau, l'outil ne change pas.
func _test_h7_model() -> void:
	var need_ok := true
	for p in [[10, 148], [30, 295], [43, 462], [60, 829], [80, 1650], [89, 2240]]:
		need_ok = need_ok and absf(Sim.xp_need(int(p[0])) / float(p[1]) - 1.0) < 0.01
	check("H7 : besoin d'XP 105 × 1,035^L (niv. 10 : %.0f, 60 : %.0f, 89 : %.0f, comme le §1.3)" % [Sim.xp_need(10), Sim.xp_need(60), Sim.xp_need(89)], need_ok)
	check("H7 : écart de niveau ×%.2f (10 au-dessus) / ×%.2f (10 en dessous), plancher ×0,1, plafond ×3" % [Sim.xp_gap(50, 40), Sim.xp_gap(30, 40)],
		absf(Sim.xp_gap(50, 40) - 2.594) < 0.01 and absf(Sim.xp_gap(30, 40) - 0.386) < 0.01 and Sim.xp_gap(1, 60) == 0.1 and Sim.xp_gap(90, 60) == 3.0)
	var bands := [[1, 23], [18, 33], [28, 43], [38, 48], [43, 53], [48, 60], [55, 65], [60, 70], [65, 75], [70, 80], [75, 85], [80, 90]]
	var doc_mult := [0.68, 0.80, 0.83, 2.9, 2.9, 4.0, 17.0, 17.5, 12.0, 195.0, 286.0, 99.0]
	var band_ok := true
	var mult_ok := true
	var got := []
	for ep in range(1, 5):
		for k in range(1, 4):
			var i := (ep - 1) * 3 + k - 1
			band_ok = band_ok and Sim.band_lo(ep, k) == int(bands[i][0]) and Sim.band_hi(ep, k) == int(bands[i][1])
			var m := float(Sim.HERO_PROBE_MULT[ep - 1][k - 1]) * float(Sim.HERO_EPOCH_FACTOR[ep - 1])
			mult_ok = mult_ok and absf(m / float(doc_mult[i]) - 1.0) < 0.02
			got.append("%d-%d" % [Sim.band_lo(ep, k), Sim.band_hi(ep, k)])
	check("H7 : bandes des cartes du §1.4 (%s)" % ", ".join(got), band_ok)
	check("H7 : MAP_MULT de l'outil = table du §1.4 (M′ de la sonde × facteur d'époque)", mult_ok)
	check("H7 : monstres au niveau du héros, bornés par la bande (I-2 : %d / %d / %d pour un héros 5 / 25 / 60)" % [Sim.band_level(1, 2, 5), Sim.band_level(1, 2, 25), Sim.band_level(1, 2, 60)],
		Sim.band_level(1, 2, 5) == 18 and Sim.band_level(1, 2, 25) == 25 and Sim.band_level(1, 2, 60) == 33)
	check("H7 : pièce portable si son niveau ≤ H, pièces de départ toujours",
		Sim.wearable_at({"level": 50}, 50) and not Sim.wearable_at({"level": 51}, 50) and Sim.wearable_at({"level": 80, "starter": true}, 1) and Sim.wearable_at({}, 1))
	var sim: Node = Sim.new()
	var acc: Dictionary = sim.new_account("moyen")
	check("H7 : sans --heros, l'outil ne change pas (aucun niveau de héros, toute pièce portable)", not sim.heros and not acc.has("hl") and sim.wearable({"level": 90}))
	sim.free()


## Lot H7 : colonne « niveau de héros » de NIVEAU_HEROS.md §5 (--heros --refonte --plans=boss --hubvalue). Par défaut 6 comptes,
## 45 h, graine 11 (bornes larges) ; -- --full : la mesure du document (12 comptes, 50 h, graine 1), médianes à ± 15 %.
func _test_h7_heros() -> void:
	var full := "--full" in OS.get_cmdline_user_args()
	var sim: Node = Sim.new()
	sim.quiet = true
	sim.heros = true
	sim.refonte = true
	sim.plans_by_boss = true
	sim.hubvalue = true
	# M′ du document (§1.4) : le jeu a depuis le lot H4a son propre Epochs.MAP_MULT, mesuré au pilote (R_H4a.md)
	var doc_mult: Array = []
	for ep in range(1, 5):
		for k in range(1, 4):
			doc_mult.append(float(Sim.HERO_PROBE_MULT[ep - 1][k - 1]) * float(Sim.HERO_EPOCH_FACTOR[ep - 1]))
	sim.map_mult_override = doc_mult
	add_child(sim)
	var res: Dictionary = sim.simulate(12, "moyen", 50.0, 1) if full else sim.simulate(6, "moyen", 45.0, 11)
	var e1: Dictionary = sim.milestone(res, "epoch_1")
	var e2: Dictionary = sim.milestone(res, "epoch_2")
	var e4: Dictionary = sim.milestone(res, "epoch_4")
	var d0: Dictionary = sim.milestone(res, "dungeon_0")
	var h90: Dictionary = sim.milestone(res, "hero90")
	var k80: Dictionary = sim.milestone(res, "kit80_ok")
	print("      niveau de héros : époque I %s h (H %d), II %s h (H %d), IV %s h (H %d), 1er donjon %s h, niveau 90 %s h, équipement 80-90 correct %s h (%.0f %%)"
		% [e1.h, e1.hl, e2.h, e2.hl, e4.h, e4.hl, d0.h, h90.h, k80.h, 100.0 * float(k80.share)])
	var over := 0
	for a in res.accounts:
		for slot in a.gear:
			if not Sim.wearable_at(a.gear[slot], int(a.hl)):
				over += 1
	check("H7 : aucune pièce portée au-dessus du niveau de héros (%d)" % over, over == 0)
	check("H7 : 1er donjon juste après l'époque I (≤ époque I + 1 h) — %s h / %s h" % [d0.h, e1.h], float(d0.h) >= 0.0 and float(d0.h) <= float(e1.h) + 1.0)
	if full:
		# NIVEAU_HEROS.md §5, colonne « moyen » : époque I 2,8 (H 35), II 10,6 (H 64), IV 31,2 (H 90), niveau 90 29,3, 80-90 correct 37,4
		for p in [["époque I", e1, 2.8], ["époque II", e2, 10.6], ["époque IV", e4, 31.2], ["niveau 90", h90, 29.3], ["équipement 80-90 correct", k80, 37.4]]:
			check("H7 (mesure du document) : %s %s h, document %.1f h (± 15 %%)" % [p[0], p[1].h, p[2]], absf(float(p[1].h) / float(p[2]) - 1.0) <= 0.15)
	else:
		check("H7 : époque I 2 à 5 h, héros déjà haut (H ≥ 25) — %s h, H %d" % [e1.h, e1.hl], float(e1.h) >= 2.0 and float(e1.h) <= 5.0 and int(e1.hl) >= 25)
		check("H7 : niveau 90 entre 22 et 38 h (document 29,3 h) — %s h" % h90.h, float(h90.h) >= 22.0 and float(h90.h) <= 38.0)
		check("H7 : le niveau suit le contenu (H ≥ 50 à l'époque II) — H %d" % int(e2.hl), int(e2.hl) >= 50)
	sim.queue_free()


## Passe P5 : seuils de PE (donjons, Siège, Ruée, légendaire) : ordre des difficultés et équipements types.
func _test_gates() -> void:
	seed(7)
	var kit_e1 := GearPower.gear_power(StarterGear.scenario("1.3.10.3", "warrior"))
	var kit_e3 := GearPower.gear_power(StarterGear.scenario("3.3.10.4", "warrior"))
	var low := String(Dungeons.zone_ids()[0])
	check("P5 : équipement d'époque I à +10 (PE %d) : ni Héroïque (%d) ni Mythique (%d)" % [kit_e1, Dungeons.power_required(low, 1), Dungeons.power_required(low, 2)],
		kit_e1 < Dungeons.power_required(low, 1) and kit_e1 < Dungeons.power_required(low, 2))
	check("P5 : équipement d'époque III à +10 (PE %d) : Héroïque de la 1re zone, pas le Mythique" % kit_e3,
		kit_e3 >= Dungeons.power_required(low, 1) and kit_e3 < Dungeons.power_required(low, 2))
	var ordered := true
	for z in Dungeons.zone_ids():
		ordered = ordered and Dungeons.power_required(String(z), 2) >= Dungeons.power_required(String(z), 1) \
			and Siege.power_required(String(z), 1) > Dungeons.power_required(String(z), 1) and Siege.power_required(String(z), 2) > Dungeons.power_required(String(z), 2)
	check("P5 : dans chaque zone Mythique ≥ Héroïque, Siège > donjon", ordered)
	var kit_e4 := GearPower.gear_power(StarterGear.scenario("4.3.10.4", "warrior"))
	check("P5 : légendaire d'un coffre de niveau 90 fermé à l'équipement d'époque I +10, ouvert à celui d'époque IV +10 (PE %d)" % kit_e4,
		kit_e1 < GearPower.required(90, GearPower.LEGEND_RATIO) and kit_e4 >= GearPower.required(90, GearPower.LEGEND_RATIO))
