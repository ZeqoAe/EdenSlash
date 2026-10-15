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
	await _test_progression()
	Run.active = false
	Run.survival = false
	Profile.reset_all()
	print("TOUT EST OK (0 échec(s))" if fails == 0 else "ÉCHECS : %d" % fails)
	get_tree().quit(fails)


## Insignes : prorata du temps sur la 1re carte, rien ne change dès la 2e carte ni pour une victoire.
func _test_insignia() -> void:
	var full := Economy.survival_insignia(1, 40, 1, 1, false)
	check("défaite en carte 1 sans durée connue : barème d'E5 (%d)" % full, full == 25 + 25 + 2 + 2)
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
	var m: Array = Epochs.MONSTER_MULT
	check("monstres : ×0,85 à l'époque I (adoucie, passe P5), de plus en plus forts", float(m[0]) <= 1.0 and float(m[0]) >= 0.8 and float(m[1]) > 1.0 and float(m[2]) > float(m[1]) and float(m[3]) > float(m[2]))
	check("époque IV : ≥ ×5 (un équipement complet est attendu)", float(m[3]) >= 5.0)


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
