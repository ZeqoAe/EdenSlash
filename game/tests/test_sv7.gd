extends Node
## Lot S7 du Survivant (conception/survivor/R_S7.md) : équilibrage par mesures. Vérifie :
## - les réglages (en tête de core/survivor.gd, lus par le profil « survivor » de ModeRules) : expérience en trois bornes,
##   ouverture douce (dégâts et PV réduits, pas de vague dure ni de camp d'élite), courbe des monstres, gardiens, boss ;
## - la puissance des monstres selon l'équipement de la RUN (bande par minute, bornes étroites) ;
## - la pitié de l'offre (après PITY_DRY choix sans carte forte, une offre au moins épique) ;
## - les garde-fous des statistiques (critique, dégâts critiques, vitesses, passifs cumulés) sur des builds tirés ;
## - la Menace reste optionnelle (autels du géant et pacte présents, boss × Menace) ;
## - les MESURES (tests/sv7_mesures.json, écrit d'après tools/sim_survivor.py) : faites avec les réglages actuels (sinon :
##   relancer les mesures) et dans les bornes (niveau à 20:00, durée, victoire par profil, gardiens, boss, dominance).
## godot --headless --path game res://tests/test_sv7.tscn

const MEASURES := "res://tests/sv7_mesures.json"
const BUILDS := 60  # builds tirés pour les garde-fous de statistiques

var fails := 0


func check(label: String, ok: bool) -> void:
	print(("OK    " if ok else "ÉCHEC ") + label)
	if not ok:
		fails += 1


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Settings.reset_all()
	Profile.selected_class = "warrior"
	Profile.reset_all()
	Profile.in_run = false
	SurvivorCards.seed_with(77)
	seed(77)
	_rules()
	_curve()
	_power()
	_pity()
	_caps()
	_menace()
	_measures()
	print("\n%s (%d échec(s))" % ["TOUT EST OK" if fails == 0 else "ÉCHECS", fails])
	Profile.reset_all()
	get_tree().quit(1 if fails > 0 else 0)


static func near(a: float, b: float, eps := 0.001) -> bool:
	return absf(a - b) <= eps * maxf(1.0, absf(b))


# --- réglages -----------------------------------------------------------------------------------------------------------
func _rules() -> void:
	var same := true
	for k in ["xp_start", "xp_end", "xp_late", "hp0", "hp_growth", "atk0", "atk_growth", "boss_hp", "boss_rage_at", "crit_cap", "speed_cap"]:
		same = same and str(ModeRules.rule(k, null, "survivor")) == str(ModeRules.SURVIVOR[k])
	check("le profil « survivor » lit les constantes de core/survivor.gd", same and str(ModeRules.SURVIVOR.boss_hp) == str(Survivor.BOSS_HP))
	check("expérience : ×%s au niveau 1, ×%s au niveau %d, ×%s au niveau %d" % [Survivor.XP_START, Survivor.XP_END, Survivor.XP_UNTIL, Survivor.XP_LATE, Survivor.XP_LATE_AT],
		near(Survivor.xp_mult(1), Survivor.XP_START) and near(Survivor.xp_mult(Survivor.XP_UNTIL), Survivor.XP_END)
		and near(Survivor.xp_mult(Survivor.XP_LATE_AT), Survivor.XP_LATE) and near(Survivor.xp_mult(90), Survivor.XP_LATE))
	var mono := true
	for lv in range(1, 90):
		mono = mono and Survivor.xp_mult(lv + 1) <= Survivor.xp_mult(lv) + 0.0001
	check("expérience : jamais en hausse d'un niveau au suivant", mono)


func _curve() -> void:
	var p0 := SurvivorDirector.spawn_plan(0.0)
	check("ouverture : dégâts × %.2f et PV × %.2f à 0:00" % [p0.atk_mult, p0.hp_mult],
		near(p0.atk_mult, Survivor.ATK0 * Survivor.OPENING[0]) and near(p0.hp_mult, Survivor.HP0 * Survivor.OPENING[1]))
	var p3 := SurvivorDirector.spawn_plan(float(Survivor.OPENING[2]))
	check("fin de l'ouverture : la courbe seule", near(p3.atk_mult, Survivor.ATK0 * pow(Survivor.ATK_GROWTH, float(Survivor.OPENING[2]) / 60.0)))
	check("pas de vague dure (élite) avant %d s, puis oui" % int(Survivor.HARD_WAVES_FROM),
		not SurvivorDirector.spawn_plan(Survivor.HARD_WAVES_FROM - 1.0).hard and SurvivorDirector.spawn_plan(Survivor.HARD_WAVES_FROM).hard)
	check("vivants %d → %d" % [SurvivorDirector.spawn_plan(0.0).alive_max, SurvivorDirector.spawn_plan(1200.0).alive_max],
		int(p0.alive_max) == int(Survivor.ALIVE[0]) and int(SurvivorDirector.spawn_plan(1200.0).alive_max) == int(Survivor.ALIVE[1]))
	var lv20 := int(SurvivorDirector.spawn_plan(1200.0).level)
	check("monstres de niveau %d à 20:00 (le héros vise 38 ± 4)" % lv20, lv20 >= 34 and lv20 <= 42)
	check("gardiens : PV fixes croissants, boss au-dessus", SurvivorDirector.guardian_hp(0) < SurvivorDirector.guardian_hp(1)
		and SurvivorDirector.guardian_hp(1) < SurvivorDirector.guardian_hp(2) and SurvivorDirector.guardian_hp(2) < SurvivorDirector.final_boss_hp())


func _power() -> void:
	var band := SurvivorDirector.power_band(600.0)
	var mid := (float(band[0]) + float(band[1])) * 0.5
	check("puissance : indice dans la bande de la minute 10 → monstres inchangés", SurvivorDirector.power_target(mid, 600.0).is_equal_approx(Vector2.ONE))
	var low := SurvivorDirector.power_target(0.05, 600.0)
	check("puissance : run pauvre → monstres affaiblis, au plus × %.2f" % low.x, near(low.x, Survivor.POWER_HP[0]) and near(low.y, Survivor.POWER_ATK[0]))
	var high := SurvivorDirector.power_target(20.0, 600.0)
	check("puissance : run très riche → au plus PV × %.2f, dégâts × %.2f" % [high.x, high.y], near(high.x, Survivor.POWER_HP[1]) and near(high.y, Survivor.POWER_ATK[1]))
	var b0 := SurvivorDirector.power_band(0.0)
	var b20 := SurvivorDirector.power_band(1200.0)
	check("bande attendue croissante (%.2f → %.2f)" % [float(b0[1]), float(b20[1])], float(b20[0]) > float(b0[0]) and float(b20[1]) > float(b0[1]))


# --- pitié de l'offre -------------------------------------------------------------------------------------------------
func _pity() -> void:
	Survivor.start("warrior", "limestone")
	Run.hero_level = 8
	SurvivorCards.minutes_override = 4.0
	Run.apply_card(SurvivorCards.weapon_card())
	for s in SurvivorCards.spells_open().slice(0, 2):
		Run.apply_card(SurvivorCards.spell_card(int(s.id)))
	for slot in ["head", "chest", "legs"]:
		Run.apply_card(SurvivorCards.new_piece_card(slot))
	var ok := true
	var strong := true
	var reset := true
	for i in 200:
		Survivor.dry = Survivor.PITY_DRY
		var before := Survivor.pity_given
		var cards := Run.roll_cards(3)
		for c in cards:
			if String(c.type) in ["sv_piece_up", "sv_weapon_up", "upgrade"]:
				ok = ok and Cards.TIER_ORDER.find(String(c.tier)) >= Cards.TIER_ORDER.find(Survivor.PITY_TIER)
		strong = strong and cards.any(SurvivorCards.is_strong)
		reset = reset and Survivor.dry == 0 and Survivor.pity_given == before + 1
	check("pitié : après %d choix sans carte forte, améliorations au moins %s" % [Survivor.PITY_DRY, Survivor.PITY_TIER], ok)
	check("pitié : une carte forte garantie, compteur remis à zéro", strong and reset)
	Survivor.dry = 0
	Survivor.pity_given = 0
	var n := 2000
	for i in n:
		Run.roll_cards(3)
	check("pitié rare dans un tirage normal (%d sur %d choix)" % [Survivor.pity_given, n], Survivor.pity_given <= n / 20)
	SurvivorCards.minutes_override = -1.0
	Run.finish("abandon")
	Profile.end_run_survival()


# --- garde-fous des statistiques --------------------------------------------------------------------------------------
func _caps() -> void:
	var classes := ["warrior", "thief", "hunter", "cleric", "magician"]
	var worst := {"crit": 0.0, "crit_dmg": 0.0, "atk_speed": 0.0, "cast_speed": 0.0, "cdr": 0.0, "proj": 0, "over": 0.0}
	for i in BUILDS:
		var cid: String = classes[i % classes.size()]
		Survivor.start(cid, "limestone")
		var lv: int = [38, 60, 90][i % 3]
		var p := Player.new()
		add_child(p)
		for k in 90:
			Run.hero_level = clampi(1 + k * lv / 90, 1, lv)
			SurvivorCards.minutes_override = 20.0 * k / 90.0
			var cards := Run.roll_cards(3) if k % 3 != 2 else SurvivorCards.chest_cards(String(SurvivorDirector.LAYOUT[k % SurvivorDirector.LAYOUT.size()]))
			if not cards.is_empty():
				Run.apply_card(SurvivorCards.auto_pick(cards, true))
		p.level = lv
		Run.hero_level = lv
		p.recalc_stats()
		worst.crit = maxf(worst.crit, maxf(p.crit, p.mcrit))
		worst.crit_dmg = maxf(worst.crit_dmg, p.crit_dmg)
		worst.atk_speed = maxf(worst.atk_speed, p.atk_speed)
		worst.cast_speed = maxf(worst.cast_speed, p.cast_speed)
		worst.cdr = maxf(worst.cdr, p.cdr)
		worst.proj = maxi(worst.proj, p.extra_proj)
		for id in Run.passive_power:
			worst.over = maxf(worst.over, float(Run.passive_power[id]) - SurvivorGear.boon_cap(String(id)))
		p.free()
		SurvivorCards.minutes_override = -1.0
		Run.finish("abandon")
		Profile.end_run_survival()
	check("critique au plus %d %% sur %d builds (pire %d %%)" % [roundi(Survivor.CRIT_CAP * 100), BUILDS, roundi(worst.crit * 100)], worst.crit <= Survivor.CRIT_CAP + 0.0001)
	check("dégâts critiques au plus +%d %% (pire +%d %%)" % [roundi(Survivor.CRIT_DMG_CAP * 100), roundi(worst.crit_dmg * 100)], worst.crit_dmg <= Survivor.CRIT_DMG_CAP + 0.0001)
	check("vitesses d'attaque et d'incantation au plus ×%s (pire ×%.2f / ×%.2f)" % [Survivor.SPEED_CAP, worst.atk_speed, worst.cast_speed],
		worst.atk_speed <= Survivor.SPEED_CAP + 0.0001 and worst.cast_speed <= Survivor.SPEED_CAP + 0.0001)
	check("recharge au plus -50 %% (pire -%d %%)" % roundi(worst.cdr * 100), worst.cdr <= 0.5 + 0.0001)
	check("passifs cumulés jamais au-delà de leur plafond (dépassement %.2f)" % worst.over, worst.over <= 0.001)
	# hors Survivant : aucun plafond du mode
	var q := Player.new()
	add_child(q)
	q.crit = 2.0
	q.atk_speed = 5.0
	Survivor.cap_hero(q)
	check("hors Survivant : statistiques intactes", is_equal_approx(q.crit, 2.0) and is_equal_approx(q.atk_speed, 5.0))
	q.free()


# --- Menace optionnelle ------------------------------------------------------------------------------------------------
func _menace() -> void:
	Survivor.start("warrior", "limestone")
	check("Survivant : autels du géant (Menace) et pacte présents sur la carte", Survivor.station_count("giant", 2) == 2 and Survivor.station_count("greed", 1) == 1)
	Menace.level = 3
	check("Menace : boss final × %.1f (PV fixes × Menace)" % Menace.hp_mult(), Menace.hp_mult() > 1.5)
	Menace.level = 0
	Run.finish("abandon")
	Profile.end_run_survival()


# --- mesures ------------------------------------------------------------------------------------------------------------
func _measures() -> void:
	var f := FileAccess.open(MEASURES, FileAccess.READ)
	check("mesures présentes (%s)" % MEASURES, f != null)
	if f == null:
		return
	var m: Dictionary = JSON.parse_string(f.get_as_text())
	var stale: Array = []
	for k in (m.get("constants", {}) as Dictionary):
		if not _same(ModeRules.SURVIVOR.get(k), m.constants[k]):
			stale.append(k)
	check("mesures faites avec les réglages actuels (sinon relancer tools/sim_survivor.py) %s" % ("" if stale.is_empty() else str(stale)), stale.is_empty())
	var runs: Dictionary = m.get("runs", {})
	var lv := float(runs.get("level_20", 0))
	check("niveau médian à 20:00 : %.0f (cible 38 ± 4)" % lv, lv >= 34.0 and lv <= 42.0)
	var dur := float(runs.get("victory_time", 0))
	check("durée d'une victoire : %.0f s (20 min de carte + le boss, au plus 24 min)" % dur, dur >= 1200.0 and dur <= 1440.0)
	var win: Dictionary = runs.get("win", {})
	check("victoire : débutant %d %% ≤ moyen %d %% ≤ bon %d %%" % [roundi(100 * float(win.get("0.3", 0))), roundi(100 * float(win.get("0.5", 0))), roundi(100 * float(win.get("0.7", 0)))],
		float(win.get("0.3", 0)) <= float(win.get("0.5", 0)) + 0.1 and float(win.get("0.5", 0)) <= float(win.get("0.7", 0)) + 0.1)
	check("victoire du joueur moyen : %d %% (cible 35-50 %%, bruit ± 15)" % roundi(100 * float(win.get("0.5", 0))), float(win.get("0.5", 0)) >= 0.2 and float(win.get("0.5", 0)) <= 0.65)
	check("aucune mort avant 3:00 au pilote moyen (%d)" % int(runs.get("early_deaths_mid", 99)), int(runs.get("early_deaths_mid", 99)) == 0)
	var g := float(runs.get("guardian_ttk", 0))
	check("gardiens : %.0f s en médiane (cible 30-90)" % g, g >= 25.0 and g <= 100.0)
	var probe: Dictionary = m.get("probe", {})
	var ttk := float(probe.get("ttk_median", 0))
	check("boss final, build médian de la sonde : %.0f s (bonne run 1:30-3:00, rage à %d s)" % [ttk, int(Survivor.BOSS_RAGE_AT)], ttk >= 75.0 and ttk <= 210.0)
	check("les 10 %% de builds les plus faibles arrivent à la rage du boss (%.0f s, rage à %d s)" % [float(probe.get("ttk_q90", 0)), int(Survivor.BOSS_RAGE_AT)],
		float(probe.get("ttk_q90", 0)) >= 0.8 * Survivor.BOSS_RAGE_AT)
	check("dominance : meilleur type de build / type médian, victoires ×%.2f (≤ 3) sur %d builds" % [float(probe.get("win_ratio", 99)), int(probe.get("n", 0))],
		float(probe.get("win_ratio", 99)) <= 3.0 and int(probe.get("n", 0)) >= 250)


## Même valeur (nombres comparés en flottants, tableaux élément par élément) : le JSON relu ne distingue pas 35 de 35,0.
static func _same(a: Variant, b: Variant) -> bool:
	if a is Array or b is Array:
		if not (a is Array and b is Array) or (a as Array).size() != (b as Array).size():
			return false
		for i in (a as Array).size():
			if not _same(a[i], b[i]):
				return false
		return true
	return a != null and b != null and absf(float(a) - float(b)) < 0.000001
