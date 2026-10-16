extends Node
## Passe E6 (nuit du 15/10) : simulation de la progression d'un compte neuf, de bout en bout, avec les vraies
## formules du jeu (insignes, prix de l'Armurerie, coûts et chances de la Forge, butins des coffres et des
## activités, stats des pièces en Survie) et un modèle de joueur explicite (voir conception/nuit_15_10/R_E6.md).
##
##   godot --headless --path game res://tools/progression_sim.tscn -- [--accounts=12] [--skill=moyen|debutant|bon]
##         [--hours=90] [--seed=1] [--class=warrior] [--quiet] [--trace] [--mult=1,1.7,3.4,7] [--probe]
## --trace : une ligne par run du 1er compte ; --mult : autres Epochs.MONSTER_MULT ; --probe : puissance d'équipements types.
##
## Lot A7 (refonte « Aventure », conception/progression/REFONTE_AVENTURE.md §3.1, colonnes A / E / B / D / G / H) :
##   --refonte   Donjons dès l'époque I gagnée (zones des époques gagnées), donjon de 7 min, plans de donjon fabriqués en
##               insignes (Economy.base_price du modèle, panoplie du donjon, légendaire en Mythique) ;
##   --plans=boss  avec --refonte : un plan par boss (6 par zone, 2 emplacements chacun, lot A1) au lieu de l'approximation
##               de PR1 (un plan par zone et difficulté : sûr au 1er donjon fini, sinon 10 %, les 9 emplacements) ;
##   --hubvalue  pièces choisies sur leur PE (le niveau compte) au lieu de leur valeur en Survie (niveau du héros 35) ;
##   --decote    décote de palier en Survie : niveau de puissance × clamp(niveau de la pièce / palier de la carte, 0,5, 1)
##               (émulée ici sur une copie des pièces, sans toucher Items : le vrai réglage est le lot A6) ;
##   --heroic= / --mythic=  autres GearPower.DIFF_RATIO ;
##   --bossplans  coffre de plans du boss de chaque carte finie (lot A4) : la meilleure (sur sa valeur) de 3 pièces non
##               découvertes du palier (SlotChests.plan_candidates) ; tout découvert : Run.PLAN_INSIGNIA insignes.
## Jalons : kit80_ok (9 pièces ≥ 78, légendaires, +5), kit90_ok (≥ 86), kit90_opti (≥ 86, +10, gemmes ≥ 4, ench. ≥ 7),
## dungeon_0 (1er donjon Normal). Colonne H : -- --refonte --hubvalue --decote --mult=0.85,1.3,2.3,4.4 (12 comptes, 50 h ≈ 10 min).
##
## Lot H7 (niveau de héros, conception/progression/NIVEAU_HEROS.md §1.3, §1.4, §5 ; rapport R_H7.md) : modèle du jeu À VENIR
## (lots H1, H3, H4) ; sans ces drapeaux rien ne change.
##   --heros            niveau de héros H (1-90, compte) : XP au kill (monstre de son niveau = 1, écart × clamp(1,1^(niveau des
##                      monstres − H), 0,1, 3), +20 % sur victoire, activités ×0,6), besoin a × g^L ; pièce portable si son niveau
##                      ≤ H (pièces de départ : toujours), achat, plans et trouvailles de run aussi ; cartes = bandes de niveau
##                      [bas, haut] (haut = plus haute pièce de la carte, bas = haut de la carte d'avant − 5) ; monstres au niveau
##                      clamp(H, bas, haut) ; pièces comptées à leur niveau (sans plafond 15 / 25 / 35 ni décote) ;
##                      R = I(pièces, H) / (I de référence × 1,1^(niveau des monstres − 15/25/35)) / MAP_MULT(carte) ;
##                      pièces choisies sur leur PE (comme --hubvalue) ; jalons hero10 … hero90.
##   --hero-level=N     (implique --heros) le compte part du niveau N (compte migré, NIVEAU_HEROS §3) ;
##   --xp=a,g           autre courbe d'XP (défaut 105,1.035 ; aussi --a= / --g= de l'annexe) ;
##   --mep=e1,e2,e3,e4  facteur d'époque du M′ de la sonde (défaut 0.75,0.7,0.5,0.8 : MAP_MULT de NIVEAU_HEROS §1.4) ;
##   --mapmult=12 valeurs  MAP_MULT entier (I-1 … IV-3), prime sur --mep ; --epochcap : H plafonné au haut de l'époque en
##                      cours ; --sync : héros ramené au haut de la bande. Si le jeu a un Epochs.MAP_MULT (lot H4b), il sert
##                      de défaut. Colonne « niveau de héros » du §5 : -- --heros --refonte --plans=boss --hubvalue (12 comptes, 50 h).
## Sonde : res://tools/hl_probe.tscn (puissance par carte et M′ suggéré, retard dans la bande, talents et certificats).
##
## Rien n'est sauvegardé (Training.active pendant la simulation) ; le profil chargé n'est que la mémoire du processus.
##
## Modèle d'une Survie (une run = 3 cartes de l'époque) :
## - indice de puissance du héros I = racine(PV effectifs × dégâts par seconde) avec l'équipement porté, calculé par
##   Player.recalc_stats au niveau plafond de la carte (15 / 25 / 35), sans les cartes de la run (identiques pour tous) ;
## - rapport R = I / I(pièces mythiques +0 de la même carte de l'époque I) / Epochs.MONSTER_MULT[époque] ;
## - chance de finir la carte k : sigmoïde(C_MAP[k] + BETA × ln R + talent + apprentissage) ; BETA vient des mesures du
##   pilote automatique (tools/sim_survie.py : survie à 7 min de 60 % à 100 % quand R triple, N1 et E6), C_MAP, le
##   talent et l'apprentissage sont des hypothèses écrites ici.

const SKILLS := {"debutant": -0.7, "moyen": 0.0, "bon": 0.7}
## Joueur appris, pièces mythiques +0 de la carte (Armurerie), époque I : chance de finir chaque carte (0,50 / 0,55 / 0,60).
const C_MAP := [0.0, 0.2, 0.4]
## Sensibilité à la puissance (logit par unité de ln R), tirée des mesures du pilote automatique.
const BETA := 2.6
## Apprentissage : les premières runs sont plus dures (−LEARN au 1er essai, divisé par e toutes les LEARN_RUNS runs).
const LEARN := 1.2
const LEARN_RUNS := 3.0
## Passe P11 : boss à PV fixes et rage du boss. Une carte survécue n'est finie que si le boss tombe avant que sa rage
## ne tue le héros : chance sigmoïde(C_BOSS[carte] + BETA × ln R + talent), tirée des combats de la sonde
## tools/boss_ttk.py (--human 0.5 : runs moyennes et bonnes, la moitié de chaque pour un joueur moyen appris).
const C_BOSS := [3.0, 2.0, 2.0]
const HERO_LEVELS := [15, 25, 35]
const BASE_DRAWS := 6
## Durées (minutes) : carte finie, chargement, sessions d'activités.
const MAP_MIN := 11.0
const LOAD_MIN := 0.5
const KILLS_PER_MIN := 55.0
const ELITES_PER_MIN := 0.6
const DUNGEON_MIN := 10.0
const RUSH_MIN := 18.0
const SIEGE_MIN := 14.0
const TOWER_FLOOR_MIN := 2.0  # journal de run : 10 étages en 20 min
## Pièces découvertes (choisies dans un coffre d'emplacement) par carte jouée au moins 5 minutes.
const SEEN_PER_MAP := 6
## Fournitures par carte (sac, gardé sur victoire) et coffres de récompense (toujours gardés).
const SUPPLIES_PER_MAP := 28
const CHESTS_PER_MAP := 2.5
## Répartition du temps une fois les activités ouvertes : part du temps en Survie.
const SURVIVAL_SHARE := 0.6
## Part des emplacements où le joueur trouve une pièce de la carte pendant la run (coffres d'emplacement payés en or).
const RUN_FIND := 0.7
## Donjon tenable : niveau moyen des pièces ≥ niveau du donjon − cette marge.
const DUNGEON_LEVEL_SLACK := 12

var rng := RandomNumberGenerator.new()
var cid := "warrior"
var hero: Player
var base_index: Array = []  # indice des pièces mythiques +0 de l'époque I à chaque carte (référence R = 1)
var quiet := false
var _cache := {}
var trace := false
var mult: Array = []  # --mult=1,1.8,3,4.5 : essai d'autres Epochs.MONSTER_MULT sans toucher le jeu
var no_boss := "--no-boss" in OS.get_cmdline_user_args()  # passe P11 : sans l'enjeu du boss (comparaison avant / après)
## Lot A7 : drapeaux de la refonte (voir l'en-tête) ; des variables pour que test_e6 les règle sans ligne de commande.
var refonte := "--refonte" in OS.get_cmdline_user_args()
var plans_by_boss := "--plans=boss" in OS.get_cmdline_user_args()
var hubvalue := "--hubvalue" in OS.get_cmdline_user_args()
var decote := "--decote" in OS.get_cmdline_user_args()
var boss_plans := "--bossplans" in OS.get_cmdline_user_args()  # lot A4 (voir l'en-tête)
var plan_rng := RandomNumberGenerator.new()  # tirages du coffre de plans à part : les autres tirages restent ceux de la série sans
var diff_ratios: Array = GearPower.DIFF_RATIO.duplicate()
## Donjon sans salles de remplissage (refonte, lot A2) ; approximation de PR1 du plan par boss (plan après un donjon déjà fini).
const REFONTE_DUNGEON_MIN := 7.0
const ZONE_PLAN_CHANCE := 0.1
## Décote de palier : plancher du facteur (une pièce très sous le palier compte au moins pour la moitié de son niveau).
const DECOTE_FLOOR := 0.5
## Jalons d'équipement : [clé, niveau d'Eden minimal des 9 pièces, +N minimal, rang des 2 gemmes (-1 : sans), enchantement].
const KIT_GOALS := [["kit80_ok", 78, 5, -1, 0], ["kit90_ok", 86, 5, -1, 0], ["kit90_opti", 86, 10, 4, 7]]
const GEAR_SLOTS := ["weapon", "chest", "legs", "head", "gloves", "boots", "back", "necklace", "ring"]

## Lot H7 : niveau de héros (voir l'en-tête ; valeurs de NIVEAU_HEROS.md §1.3-§1.4).
const HERO_MAX := 90
const HERO_XP_A := 105.0  # besoin du niveau L → L+1 : HERO_XP_A × HERO_XP_G^L « monstres de son niveau »
const HERO_XP_G := 1.035
const HERO_GAP := 1.1  # XP × clamp(HERO_GAP^(niveau des monstres − H), HERO_GAP_MIN, HERO_GAP_MAX)
const HERO_GAP_MIN := 0.1
const HERO_GAP_MAX := 3.0
const HERO_WIN_XP := 1.2  # victoire : +20 % de l'XP de la partie
const HERO_ACTIVITY_XP := 0.6  # activités : XP par minute ≈ ×0,6 de l'Aventure (monstres au niveau du héros)
const HERO_BAND_OVERLAP := 5  # bas de la bande = haut de la carte d'avant − 5
const HERO_MARKS := [10, 20, 30, 43, 50, 60, 70, 75, 80, 85, 90]
## M′ de la sonde hl_probe (kit de la carte à +5 aligné sur la colonne H de REFONTE_AVENTURE §3.1), par époque et carte,
## puis facteur d'époque (balayage de PR2) : MAP_MULT = HERO_PROBE_MULT × HERO_EPOCH_FACTOR (table de NIVEAU_HEROS §1.4).
const HERO_PROBE_MULT := [[0.9, 1.06, 1.11], [4.2, 4.2, 5.75], [34.0, 35.0, 24.0], [244.0, 357.0, 124.0]]
const HERO_EPOCH_FACTOR := [0.75, 0.7, 0.5, 0.8]
var heros := "--heros" in OS.get_cmdline_user_args()
var hero_start := 1
var xp_a := HERO_XP_A
var xp_g := HERO_XP_G
var mep: Array = HERO_EPOCH_FACTOR.duplicate()
var map_mult_override: Array = []  # --mapmult= : 12 valeurs (I-1 … IV-3)
var epochcap := "--epochcap" in OS.get_cmdline_user_args()
var sync := "--sync" in OS.get_cmdline_user_args()
var _mep_given := false
var _cur: Dictionary = {}  # compte en cours (niveau de héros lu par les choix de pièces)
var _game_map_mult = null  # Epochs.MAP_MULT du jeu s'il existe (lu une fois)


func _ready() -> void:
	if get_tree().current_scene != self:
		return  # utilisé comme bibliothèque (test_e6)
	var opt := parse_args()
	if "--probe" in OS.get_cmdline_user_args():
		setup()
		probe()
		get_tree().quit()
		return
	if "--gates" in OS.get_cmdline_user_args():
		gates_table()
		get_tree().quit()
		return
	var res := simulate(int(opt.accounts), String(opt.skill), float(opt.hours), int(opt.seed))
	print_report(res, String(opt.skill))
	activity_table()
	loop_table()
	get_tree().quit()


## Options de la ligne de commande (aussi lues par la sonde hl_probe) : règle les variables et renvoie
## {accounts, skill, hours, seed}.
func parse_args() -> Dictionary:
	var opt := {"accounts": 12, "skill": "moyen", "hours": 90.0, "seed": 1}
	var floats := func(s: String) -> Array: return Array(s.split(",")).map(func(x): return float(x))
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--accounts="):
			opt.accounts = int(a.trim_prefix("--accounts="))
		elif a.begins_with("--skill="):
			opt.skill = a.trim_prefix("--skill=")
		elif a.begins_with("--hours="):
			opt.hours = float(a.trim_prefix("--hours="))
		elif a.begins_with("--seed="):
			opt.seed = int(a.trim_prefix("--seed="))
		elif a.begins_with("--class="):
			cid = a.trim_prefix("--class=")
		elif a.begins_with("--mult="):
			mult = floats.call(a.trim_prefix("--mult="))
		elif a.begins_with("--heroic="):
			diff_ratios[1] = float(a.trim_prefix("--heroic="))
		elif a.begins_with("--mythic="):
			diff_ratios[2] = float(a.trim_prefix("--mythic="))
		elif a.begins_with("--hero-level="):
			heros = true
			hero_start = clampi(int(a.trim_prefix("--hero-level=")), 1, HERO_MAX)
		elif a.begins_with("--xp="):
			var xg: Array = floats.call(a.trim_prefix("--xp="))
			xp_a = float(xg[0])
			if xg.size() > 1:
				xp_g = float(xg[1])
		elif a.begins_with("--a="):
			xp_a = float(a.trim_prefix("--a="))
		elif a.begins_with("--g="):
			xp_g = float(a.trim_prefix("--g="))
		elif a.begins_with("--mep="):
			mep = floats.call(a.trim_prefix("--mep="))
			_mep_given = true
		elif a.begins_with("--mapmult="):
			map_mult_override = floats.call(a.trim_prefix("--mapmult="))
		elif a == "--trace":
			trace = true
		elif a == "--quiet":
			quiet = true
	return opt


## Prépare le héros de mesure (une fois).
func setup() -> void:
	if hero != null:
		return
	Training.active = true  # rien n'est sauvegardé
	Profile.selected_class = cid
	Run.active = false
	hero = Player.new()
	add_child(hero)
	hero.set_physics_process(false)
	hero.set_process(false)
	# référence de chaque carte k : les pièces mythiques +0 des coffres de la carte k de l'époque I (moyenne de
	# BASE_DRAWS tirages : les pièces d'un coffre n'ont pas toutes les mêmes attributs)
	seed(12345)
	base_index = []
	for k in 3:
		var tot := 0.0
		for i in BASE_DRAWS:
			tot += power_index(StarterGear.scenario("1.%d.0" % (k + 1), cid), HERO_LEVELS[k])
		base_index.append(tot / BASE_DRAWS)


# --- puissance -----------------------------------------------------------------------------------
## Indice de puissance de l'équipement [param gear] au niveau de héros [param lv] (Survie, sans cartes).
func power_index(gear: Dictionary, lv: int) -> float:
	var keep := Profile.equipped
	Run.active = true
	Run.survival = true
	Run.passives = {}
	Run.class_id = cid
	Profile.equipped = gear
	hero.level = lv
	hero.recalc_stats()
	var mag := String(hero.cls.get("dmg_type", "phys")) == "mag"
	var main := hero.matk if mag else hero.atk
	var cr := clampf(hero.mcrit if mag else hero.crit, 0.0, 1.0)
	var dps := main * (1.0 + cr * hero.crit_dmg) * hero.atk_speed * hero.dmg_mult / (1.0 - hero.cdr * 0.5)
	var ehp := hero.max_hp * (100.0 + hero.defense) / 100.0 / (1.0 - hero.evasion_chance)
	Profile.equipped = keep
	Run.active = false
	Run.survival = false
	return sqrt(maxf(ehp, 1.0) * maxf(dps, 1.0))


## Rapport de puissance aux 3 cartes de l'époque [param ep] (pièces +0 de la carte à l'époque I = 1).
## En run, les coffres d'emplacement de la carte donnent des pièces mythiques +0 de la carte, portées à la place des
## pièces du hub qui valent moins (« le temps de la run ») : l'équipement réel de la carte k est, emplacement par
## emplacement, le meilleur des deux (RUN_FIND : part des emplacements trouvés en run).
func ratios(gear: Dictionary, ep: int, with_finds := true) -> Array:
	if heros:
		return hero_ratios(gear, ep, with_finds)
	var out: Array = []
	for k in 3:
		var g := run_gear(gear, ep, k + 1) if with_finds else gear
		if decote:
			g = decoted(g, ep, k + 1, HERO_LEVELS[k])
		out.append(power_index(g, HERO_LEVELS[k]) / float(base_index[k]) / monster_mult(ep))
	return out


## Lot A7, --decote : facteur de palier d'une pièce d'Eden à la carte [param stage] de l'époque [param ep] :
## clamp(niveau de la pièce / palier, DECOTE_FLOOR, 1) ; palier = niveau d'arme de la carte pour l'arme, d'armure sinon.
static func decote_factor(item: Dictionary, ep: int, stage: int) -> float:
	if not item.has("eden"):
		return 1.0
	var m := Epochs.map_def(ep, stage)
	var pal := maxi(1, int(m.weapon) if String(item.get("slot", "")) == "weapon" else int(m.armor))
	return clampf(float(item.get("level", pal)) / float(pal), DECOTE_FLOOR, 1.0)


## Copie de [param gear] où chaque pièce d'Eden a le niveau de puissance décoté (niveau du héros [param lv] borné par le
## plafond de la pièce, × decote_factor) : même calcul que le lot A6 dans Items.power_level, sans toucher le jeu.
static func decoted(gear: Dictionary, ep: int, stage: int, lv: int) -> Dictionary:
	var out := {}
	for slot in gear:
		var it: Dictionary = gear[slot]
		var f := decote_factor(it, ep, stage)
		if f >= 1.0:
			out[slot] = it
			continue
		var x := it.duplicate()
		x.erase("eden")  # pièce sans niveau d'Eden : Items.power_cap lit « plevel »
		x["plevel"] = maxi(1, roundi(mini(lv, Items.power_cap(it)) * f))
		out[slot] = x
	return out


# --- niveau de héros (lot H7, --heros) ------------------------------------------------------------
## Haut de la bande de la carte [param k] de l'époque [param ep] : niveau d'Eden de sa plus haute pièce.
static func band_hi(ep: int, k: int) -> int:
	var m := Epochs.map_def(ep, k)
	return maxi(int(m.armor), int(m.weapon))


## Bas de la bande : haut de la carte d'avant − HERO_BAND_OVERLAP (1 pour la 1re carte).
static func band_lo(ep: int, k: int) -> int:
	if ep <= 1 and k <= 1:
		return 1
	return band_hi(ep if k > 1 else ep - 1, k - 1 if k > 1 else 3) - HERO_BAND_OVERLAP


## XP (« monstres de son niveau ») du niveau [param l] au suivant.
static func xp_need(l: int, a := HERO_XP_A, g := HERO_XP_G) -> float:
	return a * pow(g, l)


## Facteur d'XP d'un monstre de niveau [param monster_lv] pour un héros de niveau [param h].
static func xp_gap(monster_lv: int, h: int) -> float:
	return clampf(pow(HERO_GAP, monster_lv - h), HERO_GAP_MIN, HERO_GAP_MAX)


## Niveau des monstres de la carte pour un héros de niveau [param h].
static func band_level(ep: int, k: int, h: int) -> int:
	return clampi(h, band_lo(ep, k), band_hi(ep, k))


## M′ de la carte [param k] de l'époque [param ep] (remplace Epochs.MONSTER_MULT) : --mapmult, sinon Epochs.MAP_MULT
## s'il existe (lot H4b) et sans --mep, sinon HERO_PROBE_MULT × facteur d'époque.
func map_mult(ep: int, k: int) -> float:
	var i := (clampi(ep, 1, 4) - 1) * 3 + clampi(k, 1, 3) - 1
	if map_mult_override.size() >= 12:
		return float(map_mult_override[i])
	if _game_map_mult == null:
		_game_map_mult = (load("res://scripts/core/epochs.gd") as Script).get_script_constant_map().get("MAP_MULT", [])
	var game: Array = _game_map_mult
	if game.size() >= 12 and not _mep_given:
		return float(game[i])
	return float(HERO_PROBE_MULT[clampi(ep, 1, 4) - 1][clampi(k, 1, 3) - 1]) * float(mep[clampi(ep, 1, mep.size()) - 1])


## Niveau de héros du compte en cours (35 hors simulation : sonde).
func hero_level() -> int:
	return int(_cur.get("hl", 1)) if heros and not _cur.is_empty() else 35


## Pièce portable au niveau de héros [param h] (pièces de départ : toujours).
static func wearable_at(it: Dictionary, h: int) -> bool:
	return it.is_empty() or it.get("starter", false) or int(it.get("level", 0)) <= h


func wearable(it: Dictionary) -> bool:
	return not heros or wearable_at(it, hero_level())


## Rapport de puissance aux 3 cartes avec le niveau de héros : pièces à leur niveau, monstres dans la bande, MAP_MULT.
func hero_ratios(gear: Dictionary, ep: int, with_finds := true) -> Array:
	var out: Array = []
	var h := hero_level()
	for k in 3:
		var g := run_gear(gear, ep, k + 1) if with_finds else gear
		var hh := mini(h, band_hi(ep, k + 1)) if sync else h
		var ref := float(base_index[k]) * pow(1.1, band_level(ep, k + 1, h) - int(HERO_LEVELS[k]))
		out.append(power_index(g, hh) / ref / map_mult(ep, k + 1))
	return out


## XP de héros [param units] versée au compte ; jalons heroN.
func add_hero_xp(acc: Dictionary, units: float) -> void:
	acc.hxp = float(acc.hxp) + units
	var cap := HERO_MAX
	if epochcap:
		cap = band_hi(mini(int(acc.cleared) + 1, Epochs.count()), 3)
	while int(acc.hl) < cap and float(acc.hxp) >= xp_need(int(acc.hl), xp_a, xp_g):
		acc.hxp = float(acc.hxp) - xp_need(int(acc.hl), xp_a, xp_g)
		acc.hl = int(acc.hl) + 1
		if int(acc.hl) in HERO_MARKS:
			_note(acc, "hero%d" % int(acc.hl))
	if int(acc.hl) >= cap:
		acc.hxp = minf(float(acc.hxp), xp_need(int(acc.hl), xp_a, xp_g))


## XP d'une partie d'Aventure : minutes réparties sur les cartes atteintes (MAP_MIN par carte finie), monstres au niveau
## de la bande de chaque carte ; +20 % sur victoire.
func hero_run_xp(acc: Dictionary, ep: int, minutes: float, victory: bool) -> void:
	var units := 0.0
	var h := int(acc.hl)
	var k := 1
	while minutes > 0.01 and k <= 3:
		var t := minf(minutes, MAP_MIN)
		units += t * KILLS_PER_MIN * xp_gap(band_level(ep, k, h), h)
		minutes -= t
		k += 1
	add_hero_xp(acc, units * (HERO_WIN_XP if victory else 1.0))


var _run_kits := {}


func run_gear(gear: Dictionary, ep: int, stage: int) -> Dictionary:
	var key := "%d.%d" % [ep, stage]
	if not _run_kits.has(key):
		_run_kits[key] = StarterGear.scenario("%d.%d.0" % [ep, stage], cid)
	var kit: Dictionary = _run_kits[key]
	var out := gear.duplicate()
	var lv: int = hero_level() if heros else HERO_LEVELS[stage - 1]
	var i := 0
	for slot in kit:
		i += 1
		if float(i) / float(kit.size()) > RUN_FIND:
			break
		if not wearable(kit[slot]):
			continue
		if not out.has(slot) or _value_at(kit[slot], lv) > _value_at(out[slot], lv):
			out[slot] = kit[slot]
	return out


func _value_at(it: Dictionary, lv: int) -> float:
	Run.active = true
	Run.survival = true
	Run.hero_level = lv
	var v := Items.rating(it)
	Run.active = false
	Run.survival = false
	return v


func monster_mult(ep: int) -> float:
	return float(mult[clampi(ep, 1, mult.size()) - 1]) if not mult.is_empty() else Epochs.monster_mult(ep)


static func sigmoid(x: float) -> float:
	return 1.0 / (1.0 + exp(-x))


func clear_chance(r: float, k: int, talent: float) -> float:
	return sigmoid(float(C_MAP[k]) + BETA * log(maxf(r, 0.05)) + talent) * boss_chance(r, k, talent)


## Le boss de la carte [param k] tombe avant sa rage (passe P11) ; --no-boss : comme avant (boss sans enjeu).
func boss_chance(r: float, k: int, talent: float) -> float:
	if no_boss:
		return 1.0
	return sigmoid(float(C_BOSS[k]) + BETA * log(maxf(r, 0.05)))  # (le talent compte déjà dans la survie à la carte)


# --- un compte ---------------------------------------------------------------------------------------
func new_account(skill: String) -> Dictionary:
	var acc := {"skill": float(SKILLS.get(skill, 0.0)), "min": 0.0, "runs": 0, "insignia": 0, "crystals": 0, "mastery": 0,
		"cleared": 0, "bag": {}, "gear": StarterGear.items(cid), "seen": {}, "bought": {}, "events": {}, "curve": [],
		"spent_insignia": 0, "spent_crystals": 0, "won_runs": 0, "insignia_total": 0, "crystals_total": 0}
	if heros:
		acc["hl"] = hero_start
		acc["hxp"] = 0.0
		for s in acc.gear:
			acc.gear[s]["starter"] = true  # pièces de départ : portables à tout niveau
		_cur = acc
	return acc


func _note(acc: Dictionary, key: String) -> void:
	if not acc.events.has(key):
		acc.events[key] = {"h": acc.min / 60.0, "runs": int(acc.runs), "pe": pe(acc), "lvl": avg_level(acc), "hl": int(acc.get("hl", 0))}


## Passe P5 : verrous de PE du jeu (sans la marge de niveau du modèle) franchis par le compte : donjons et Siège
## (au moins une zone / toutes les zones) par difficulté, Ruée, butin légendaire d'un coffre de niveau 60 et 90.
func _note_gates(acc: Dictionary) -> void:
	if int(acc.cleared) < 2:
		return
	var power := pe(acc)
	for d in [1, 2]:
		var any_d := false
		var all_d := true
		var any_s := false
		for z in Dungeons.zone_ids():
			var ok := power >= Dungeons.power_required(String(z), d)
			any_d = any_d or ok
			all_d = all_d and ok
			any_s = any_s or power >= Siege.power_required(String(z), d)
		if any_d:
			_note(acc, "open_dungeon_%d" % d)
		if all_d:
			_note(acc, "open_dungeon_%d_all" % d)
		if any_s:
			_note(acc, "open_siege_%d" % d)
		if power >= Dungeons.power_required(Dungeons.RUSH, d):
			_note(acc, "open_rush_%d" % d)
	for lv in [60, 90]:
		if power >= GearPower.required(lv, GearPower.LEGEND_RATIO):
			_note(acc, "legend_%d" % lv)


func _add_bag(acc: Dictionary, key: String, n := 1) -> void:
	acc.bag[key] = int(acc.bag.get(key, 0)) + n


## Une Survie à l'époque [param ep] : renvoie le résultat ; gains versés au compte.
func survival_run(acc: Dictionary, ep: int) -> String:
	_cur = acc
	acc.runs = int(acc.runs) + 1
	var talent: float = float(acc.skill) - LEARN * exp(-float(int(acc.runs) - 1) / LEARN_RUNS)
	var rs := ratios(acc.gear, ep)
	var stage := 1
	var minutes := 0.0
	var victory := false
	var bag := {}
	for k in 3:
		stage = k + 1
		if rng.randf() < clear_chance(float(rs[k]), k, talent):
			minutes += MAP_MIN
			_map_loot(acc, ep, stage, MAP_MIN, bag)
			if boss_plans:
				_boss_plan(acc, ep, stage)  # carte finie = boss vaincu
			if k == 2:
				victory = true
		else:
			var t := rng.randf_range(3.0, MAP_MIN)
			minutes += t
			_map_loot(acc, ep, stage, t, bag)
			break
	acc.min = float(acc.min) + minutes + LOAD_MIN
	var kills := int(KILLS_PER_MIN * minutes)
	var elites := int(ELITES_PER_MIN * minutes)
	var map1 := minutes if stage == 1 else MAP_MIN
	var f := Callable(Economy, "survival_insignia")
	var ins: int = f.call(stage, kills, elites, ep, victory, map1) if f.get_argument_count() >= 6 else f.call(stage, kills, elites, ep, victory)
	acc.insignia = int(acc.insignia) + ins
	acc.insignia_total = int(acc.insignia_total) + ins
	var lvl: int = HERO_LEVELS[stage - 1] if victory or minutes > 6.0 else int(HERO_LEVELS[stage - 1] * 0.7)
	var cap := int(Run.get_script().get_script_constant_map().get("KILL_CAP_PER_MAP", 1 << 30))
	var gain := lvl * 15 + mini(kills, cap * stage) / 2 + elites * 10 + (200 if victory else 0) + 120 * (stage - 1)
	acc.mastery = int(acc.mastery) + gain
	if victory:
		acc.won_runs = int(acc.won_runs) + 1
		for k in bag:
			_add_bag(acc, k, int(bag[k]))
		if ep > int(acc.cleared):
			acc.cleared = ep
			_note(acc, "epoch_%d" % ep)
	if heros:
		hero_run_xp(acc, ep, minutes, victory)
	if trace:
		print("  run %3d  %5.1f h  E%d  %s carte %d  R %.2f/%.2f/%.2f  talent %+.2f  insignes %5d (+%d)  cristaux %5d  PE %d%s" % [acc.runs, float(acc.min) / 60.0,
			ep, "VICTOIRE" if victory else "défaite ", stage, rs[0], rs[1], rs[2], talent, acc.insignia, ins, acc.crystals, pe(acc),
			("  niveau de héros %d" % int(acc.hl)) if heros else ""])
	return "victoire" if victory else "defaite"


## Butin d'une carte : découvertes (Armurerie), fournitures du sac, coffres de récompense ouverts au hub.
func _map_loot(acc: Dictionary, ep: int, stage: int, minutes: float, bag: Dictionary) -> void:
	var part := clampf(minutes / MAP_MIN, 0.0, 1.0)
	if minutes >= 5.0:
		for i in SEEN_PER_MAP:
			var box: String = ["weapon", "head", "chest", "legs", "gloves", "boots", "back", "jewel", "jewel", "chest", "legs", "head"][rng.randi() % 12]
			var p := SlotChests.pool(box, ep, stage, Items.default_weapon_type(cid))
			if not p.is_empty():
				var e: Dictionary = p[rng.randi() % p.size()]
				acc.seen[int(e.id)] = e
	var m := Epochs.map_def(ep, stage)
	var supply := maxi(int(m.armor), int(m.weapon))
	var loot_lv := maxi(1, int(Epochs.cap(stage) * 0.8))
	var gem_lv := loot_lv + RunDirector.GEM_EPOCH_LEVELS * (ep - 1)
	Run.active = true  # plafonds de la Survie (formules) : vrai chemin du jeu
	Run.survival = true
	Run.epoch = ep
	for i in roundi(SUPPLIES_PER_MAP * part):
		var key := Craft.loot_for("crate" if i % 3 == 0 else "", supply, 0, gem_lv)
		bag[key] = int(bag.get(key, 0)) + 1
	Run.active = false
	Run.survival = false
	var n_chests := roundi(CHESTS_PER_MAP * part + rng.randf() - 0.5)
	for i in maxi(n_chests, 0):
		var t := "forge" if rng.randf() < 0.6 else "jewel"
		_open_chest(acc, Rewards.make(t, supply if t == "forge" else gem_lv, false))


## Lot A4, --bossplans : coffre de plans du boss de la carte : 3 pièces non découvertes du palier tirées au hasard, le joueur
## prend celle qui vaut le plus (il vise son manque) ; tout le palier découvert : des insignes à la place.
func _boss_plan(acc: Dictionary, ep: int, stage: int) -> void:
	var known := {}
	for id in acc.seen:
		known[int(id)] = true
	var p := SlotChests.plan_candidates(ep, stage, known, Items.default_weapon_type(cid))
	if p.is_empty():
		acc.insignia = int(acc.insignia) + Run.PLAN_INSIGNIA
		acc.insignia_total = int(acc.insignia_total) + Run.PLAN_INSIGNIA
		return
	for i in range(p.size() - 1, 0, -1):
		var j := plan_rng.randi_range(0, i)
		var t = p[i]
		p[i] = p[j]
		p[j] = t
	var best: Dictionary = {}
	var best_v := -INF
	for e in p.slice(0, Run.PLAN_CHOICES):
		var it: Dictionary = _cache.get(int(e.id), {})
		if it.is_empty():
			it = Items.from_eden(e)
			it["quality"] = 1.0
			_cache[int(e.id)] = it
		var v := _value(it) - _value(acc.gear.get(String(e.slot), {}), true)
		if v > best_v:
			best_v = v
			best = e
	acc.seen[int(best.id)] = best
	acc["boss_plans"] = int(acc.get("boss_plans", 0)) + 1


## Ouvre un coffre de récompense (vrai contenu : Rewards.open) et verse son contenu au compte.
func _open_chest(acc: Dictionary, chest: Dictionary) -> void:
	var stash0 := Profile.stash.duplicate()
	var cr0 := int(Profile.materials.get("crystal", 0))
	Profile.reward_chests.append(chest)
	var got := Rewards.open(chest)
	for k in got.get("supplies", {}):
		_add_bag(acc, String(k), int(got.supplies[k]))
	acc.crystals = int(acc.crystals) + int(got.get("crystal", 0))
	acc.crystals_total = int(acc.crystals_total) + int(got.get("crystal", 0))
	for it in got.get("items", []):
		_offer_piece(acc, it)
	Profile.stash = stash0
	Profile.materials["crystal"] = cr0
	Profile.inventory.clear()


## Une pièce gagnée (coffre de set, d'équipement, Tour) : portée si elle vaut mieux en Survie.
func _offer_piece(acc: Dictionary, it: Dictionary) -> void:
	var slot := String(it.get("slot", ""))
	if not slot in Items.SLOTS or slot == "trophy":
		return
	if slot == "weapon" and Items.weapon_type_of(it) != Items.default_weapon_type(cid):
		return
	if not wearable(it):
		return  # --heros : niveau requis au-dessus du niveau de héros
	var cur: Dictionary = acc.gear.get(slot, {})
	if cur.is_empty() or _value(it, true) > _value(cur, true) * 1.08:
		acc.gear[slot] = it


## Valeur d'une pièce pour le choix (note commune au niveau 35, enclume exclue) ; [param bare] : sans +N, gemmes
## ni enchantement (ce que vaut la pièce elle-même : le joueur rachète une meilleure base puis la remonte).
## --hubvalue (lot A7) : sa PE hors run (le niveau de la pièce compte) au lieu de sa note en Survie ; --heros aussi.
func _value(it: Dictionary, bare := false) -> float:
	if it.is_empty():
		return 0.0
	var x := it
	if bare:
		x = it.duplicate()
		x["upgrade"] = 0
		x.erase("sockets")
		x.erase("enchant")
		x.erase("up_rolls")
	if hubvalue or heros:
		Run.active = false
		return float(GearPower.item_power(x))
	Run.active = true
	Run.hero_level = 35
	var v := Items.rating(x)
	Run.active = false
	return v


# --- hub ---------------------------------------------------------------------------------------------
## Achats à l'Armurerie : pour chaque emplacement, la meilleure pièce découverte, si sa base vaut mieux que celle
## de la pièce portée (le joueur la remonte ensuite à l'Atelier).
func shop(acc: Dictionary) -> void:
	var order := ["weapon", "chest", "legs", "head", "gloves", "boots", "back", "necklace", "ring"]
	for slot in order:
		var best: Dictionary = {}
		var best_v := _value(acc.gear.get(slot, {}), true) * 1.08
		for id in acc.seen:
			var e: Dictionary = acc.seen[id]
			if String(e.slot) != slot or acc.bought.has(id):
				continue
			if heros and int(e.get("level", 0)) > int(acc.hl):
				continue  # pas encore portable : le joueur attend son niveau
			var it: Dictionary = _cache.get(id, {})
			if it.is_empty():
				it = Items.from_eden(e)
				it["quality"] = 1.0
				_cache[id] = it
			var v := _value(it)
			if v > best_v:
				best_v = v
				best = it
		if best.is_empty():
			continue
		var e2: Dictionary = acc.seen[int(best.eden)]
		var price := Economy.base_price(e2)
		if int(acc.insignia) >= price:
			acc.insignia = int(acc.insignia) - price
			acc.spent_insignia = int(acc.spent_insignia) + price
			acc.bought[int(best.eden)] = true
			var piece := best.duplicate(true)
			piece["uid"] = "sim%d" % rng.randi()
			acc.gear[slot] = piece


## Lot A7, --refonte : plans de donjon fabriqués en insignes (pièce au niveau du donjon dans la difficulté du plan,
## légendaire en Mythique, mythique sinon, à la panoplie du donjon), au prix de l'Armurerie (Economy.base_price du
## modèle) ; seulement si sa base vaut mieux que la pièce portée (même marge que l'Armurerie).
func craft_dungeon(acc: Dictionary) -> void:
	if not refonte:
		return
	var plans: Dictionary = acc.get("dplans", {})
	for k in plans:
		var p: Dictionary = plans[k]
		var lv := Dungeons.level(String(p.zone), int(p.diff))
		if heros and lv > int(acc.hl):
			continue  # pièce du plan pas encore portable
		var rar := Items.LEGENDARY if int(p.diff) >= 2 else Items.MYTHIC
		for slot in p.slots:
			var ck := "%s|%d|%s" % [k, int(p.diff), slot]
			var it: Dictionary = _cache.get(ck, {})
			if it.is_empty():
				var tpl := Items.eden_template(String(slot), Items.default_weapon_type(cid), lv, rar)
				if tpl.is_empty():
					continue
				it = Items.from_template(tpl, lv, rar)
				it["quality"] = 1.0
				it["archetype"] = String(p.archetype)
				it["_price"] = Economy.base_price(tpl)
				_cache[ck] = it
			if _value(it) <= _value(acc.gear.get(slot, {}), true) * 1.08:
				continue
			var price := int(it._price)
			if int(acc.insignia) >= price:
				acc.insignia = int(acc.insignia) - price
				acc.spent_insignia = int(acc.spent_insignia) + price
				acc["dcrafted"] = int(acc.get("dcrafted", 0)) + 1
				var piece := it.duplicate(true)
				piece.erase("_price")
				piece["uid"] = "simd%d" % rng.randi()
				acc.gear[slot] = piece


## Lot A7 : plan de donjon gagné en finissant le donjon [param zone] en [param diff] (--refonte). Par défaut (PR1) un plan
## par zone et difficulté, sûr au 1er donjon fini puis 10 % ; --plans=boss : le plan du boss affronté, sûr à sa 1re
## victoire, au niveau de la meilleure difficulté finie contre lui (lot A1). Le joueur affronte d'abord les boss sans plan.
func dungeon_plan(acc: Dictionary, zone: String, diff: int) -> void:
	var plans: Dictionary = acc.get("dplans", {})
	var clears: Dictionary = acc.get("dclears", {})
	acc["dplans"] = plans
	acc["dclears"] = clears
	if not plans_by_boss:
		var dk := "%s_%d" % [zone, diff]
		if not plans.has(dk) and (not clears.has(dk) or rng.randf() < ZONE_PLAN_CHANCE):
			plans[dk] = {"zone": zone, "diff": diff, "slots": GEAR_SLOTS, "archetype": Dungeons.archetype(zone)}
		clears[dk] = true
		return
	var bosses := BossLibrary.for_zone(zone)
	if bosses.is_empty():
		return
	var bid := String(bosses[rng.randi() % bosses.size()])
	for b in bosses:
		if not plans.has(b) or int(plans[b].diff) < diff:
			bid = String(b)
			break
	if not plans.has(bid) or int(plans[bid].diff) < diff:
		var th := BossLibrary.loot(bid)
		plans[bid] = {"zone": zone, "diff": diff, "slots": (th.get("slots", []) as Array).duplicate(), "archetype": String(th.get("archetype", Dungeons.archetype(zone)))}


## Lot A7 : jalons d'équipement KIT_GOALS (9 emplacements au niveau voulu, légendaires ou mieux, +N, gemmes, enchantement).
func note_kits(acc: Dictionary) -> void:
	for spec in KIT_GOALS:
		var ok := true
		for slot in GEAR_SLOTS:
			var it: Dictionary = acc.gear.get(slot, {})
			if it.is_empty() or int(it.get("level", 0)) < int(spec[1]) or int(it.get("upgrade", 0)) < int(spec[2]) or int(it.get("rarity", 0)) < Items.LEGENDARY:
				ok = false
				break
			if int(spec[3]) >= 0:
				var s: Array = it.get("sockets", [])
				if s.size() < 2 or s.any(func(g): return not g is Dictionary or int(g.tier) < int(spec[3])) \
						or int(it.get("enchant", {}).get("lv", 0)) < int(spec[4]):
					ok = false
					break
		if ok:
			_note(acc, String(spec[0]))


## Atelier (Forge ouverte : époque I gagnée) : +N avec parchemin et cristaux, gemmes, enchantement.
func workshop(acc: Dictionary) -> void:
	if int(acc.cleared) < 1:
		return
	for slot in Items.SLOTS:
		var it: Dictionary = acc.gear.get(slot, {})
		if it.is_empty():
			continue
		_gems(acc, it)
		_enchant(acc, it)
		var guard := 40
		while int(it.get("upgrade", 0)) < Items.MAX_UPGRADE and guard > 0:
			guard -= 1
			var scroll := ""
			var kind := Craft.fortify_kind(it)
			for k in acc.bag:
				var p := String(k).split(":")
				if p[0] == "fortify" and p[1] == kind and int(p[2]) >= Craft._item_level(it) and int(acc.bag[k]) > 0 \
						and (scroll == "" or int(p[2]) < int(scroll.split(":")[2])):
					scroll = String(k)
			var blessed := int(acc.bag.get(Craft.BLESSED, 0)) > 0 and int(it.upgrade) >= 5
			if scroll == "" and not blessed:
				break
			var cost := int(Forge.price(int(Items.upgrade_cost(it).gold)).get("crystal", 0))
			if not blessed and int(acc.crystals) < cost:
				break
			var stone := ""
			if int(it.upgrade) + 1 >= Craft.DOWNGRADE_FROM:
				for s in ["stone:sublime", "stone:citrine", "stone:ultramarine", "stone:coral", "stone:viridian", "stone:lucky", "stone:safety"]:
					if int(acc.bag.get(s, 0)) > 0 and Craft.stone_usable(it, s):
						stone = s
						break
				if stone == "" and not blessed:
					break  # le joueur moyen ne risque pas de redescendre : il attend une pierre
			if blessed:
				_add_bag(acc, Craft.BLESSED, -1)
				Craft.upgrade(it, stone, Craft.BLESSED)
			else:
				_add_bag(acc, scroll, -1)
				acc.crystals = int(acc.crystals) - cost
				acc.spent_crystals = int(acc.spent_crystals) + cost
				Craft.upgrade(it, stone, scroll)
			if stone != "":
				_add_bag(acc, stone, -1)


func _gems(acc: Dictionary, it: Dictionary) -> void:
	var sockets: Array = it.get("sockets", [])
	while sockets.size() < Craft.MAX_SOCKETS and int(acc.bag.get("drill", 0)) > 0:
		_add_bag(acc, "drill", -1)
		if sockets.size() == 1 and rng.randf() > Craft.SECOND_SOCKET_CHANCE:
			continue
		sockets.append(null)
	it["sockets"] = sockets
	var want := "garnet" if String(it.slot) != "weapon" else "ruby"
	for i in sockets.size():
		var cur = sockets[i]
		var cur_t := int(cur.tier) if cur is Dictionary else -1
		var best_k := ""
		var best_t := cur_t
		for k in acc.bag:
			var p := String(k).split(":")
			if p[0] == "gem" and int(acc.bag[k]) > 0 and int(p[2]) > best_t and (p[1] == want or p[1] == "onyx" or p[1] == "amethyst"):
				best_t = int(p[2])
				best_k = String(k)
		if best_k != "":
			_add_bag(acc, best_k, -1)
			sockets[i] = {"type": best_k.split(":")[1], "tier": best_t}


func _enchant(acc: Dictionary, it: Dictionary) -> void:
	var cur := int(it.get("enchant", {}).get("lv", 0))
	var best_k := ""
	var best_l := cur
	for k in acc.bag:
		var p := String(k).split(":")
		if p[0] == "scroll" and int(acc.bag[k]) > 0 and int(p[2]) > best_l and Craft.can_enchant(it, String(k)) == "":
			best_l = int(p[2])
			best_k = String(k)
	if best_k != "":
		_add_bag(acc, best_k, -1)
		it["enchant"] = {"type": "optimize" if String(it.slot) == "weapon" else "rehab", "lv": best_l}


# --- activités ---------------------------------------------------------------------------------------
## Niveau d'Eden moyen des pièces portées.
func avg_level(acc: Dictionary) -> float:
	var tot := 0.0
	var n := 0
	for slot in acc.gear:
		tot += float(acc.gear[slot].get("level", 0))
		n += 1
	return tot / maxf(1.0, float(n))


## PE du compte (hors run).
func pe(acc: Dictionary) -> int:
	Run.active = false
	return GearPower.gear_power(acc.gear)


## Une session d'activité (environ 30 min) : la meilleure ouverte pour les cristaux et matières.
func activity_session(acc: Dictionary) -> String:
	_cur = acc
	var power := pe(acc)
	var minutes := 0.0
	var label := ""
	if int(acc.cleared) >= (1 if refonte else 2):
		# le donjon le plus payant ouvert : PE suffisante ET pièces assez hautes (le héros y est au niveau du donjon,
		# ses pièces y valent leur propre niveau : une pièce de niveau 45 ne tient pas un donjon de niveau 90)
		# --refonte : Donjons dès l'époque I gagnée, seulement les zones des époques gagnées
		var lvl_avg := avg_level(acc)
		var zone := "limestone"
		var diff := 0
		var best_lv := -1
		var open_z: Array = []
		for ep in range(1, mini(int(acc.cleared), Epochs.count()) + 1):
			open_z.append_array(Epochs.get_def(ep).zones)
		for d in [0, 1, 2]:
			for z in Dungeons.zone_ids():
				if refonte and not String(z) in open_z:
					continue
				var lv := Dungeons.level(String(z), d)
				if power < GearPower.required(lv, float(diff_ratios[d])) or lvl_avg < lv - DUNGEON_LEVEL_SLACK:
					continue
				if d > diff or (d == diff and lv > best_lv):
					diff = d
					zone = String(z)
					best_lv = lv
		label = "donjon_%d" % diff
		while minutes < 30.0:
			minutes += REFONTE_DUNGEON_MIN if refonte else DUNGEON_MIN
			if rng.randf() < 0.85:
				var lv := Dungeons.level(zone, diff)
				if refonte:
					dungeon_plan(acc, zone, diff)
				acc.crystals = int(acc.crystals) + ActivityLoot.dungeon_crystals(diff)
				acc.crystals_total = int(acc.crystals_total) + ActivityLoot.dungeon_crystals(diff)
				var mats := ActivityLoot.dungeon_chests(lv, diff)
				for c in mats:
					Profile.reward_chests.erase(c)
					_open_chest(acc, c)
				var set_chest := Rewards.make("set", lv, diff >= 1)
				for it in Rewards.offer(set_chest).slice(0, 1):
					_offer_piece(acc, it)
		_note(acc, "dungeon_%d" % diff)
	elif int(acc.cleared) >= 1:
		label = "tour"
		var floors := int(30.0 / TOWER_FLOOR_MIN)
		var from := int(acc.get("tower", 0))
		var gain := ActivityLoot.tower_crystals(floors, 1)
		acc.crystals = int(acc.crystals) + gain
		acc.crystals_total = int(acc.crystals_total) + gain
		var chests := ActivityLoot.tower_chests(from + 1, from + floors, func(f): return Tower.level_for(f))
		for c in chests:
			Profile.reward_chests.erase(c)
			_open_chest(acc, c)
		acc["tower"] = (from + floors) % 200
		minutes = 30.0
	acc.min = float(acc.min) + minutes
	if heros:
		add_hero_xp(acc, minutes * KILLS_PER_MIN * HERO_ACTIVITY_XP)
	return label


# --- simulation --------------------------------------------------------------------------------------
## Kit optimisé : les 9 emplacements à +10, 2 gemmes de rang 4 (parfaite) ou plus, enchantement de niveau 5 ou plus.
## Renvoie l'époque la plus basse des pièces (1 à 4 : niveau d'Eden ≥ celui de la 1re carte de l'époque), 0 sinon.
func kit_tier(acc: Dictionary, need_up := 10, need_gem := 3, need_ench := 5) -> int:
	var tier := 4
	for slot in Items.SLOTS:
		if slot == "trophy":
			continue
		var it: Dictionary = acc.gear.get(slot, {})
		if it.is_empty() or it.get("starter", false) or int(it.get("upgrade", 0)) < need_up:
			return 0
		var s: Array = it.get("sockets", [])
		if s.size() < 2 or s.any(func(g): return not g is Dictionary or int(g.tier) < need_gem):
			return 0
		if int(it.get("enchant", {}).get("lv", 0)) < need_ench:
			return 0
		var t := 1
		for ep in range(2, 5):
			if int(it.get("level", 0)) >= mini(int(Epochs.map_def(ep, 1).armor), int(Epochs.map_def(ep, 1).weapon)):
				t = ep
		tier = mini(tier, t)
	return tier


func simulate(accounts: int, skill: String, max_hours: float, seed_value: int) -> Dictionary:
	setup()
	rng.seed = seed_value
	plan_rng.seed = seed_value + 7919
	seed(seed_value)
	var all: Array = []
	for a in accounts:
		var acc := new_account(skill)
		var next_activity := false
		while float(acc.min) < max_hours * 60.0:
			var ep := mini(int(acc.cleared) + 1, Epochs.count())
			if next_activity and int(acc.cleared) >= 1:
				activity_session(acc)
			else:
				survival_run(acc, ep)
			next_activity = int(acc.cleared) >= 1 and rng.randf() > SURVIVAL_SHARE
			shop(acc)
			craft_dungeon(acc)
			workshop(acc)
			note_kits(acc)
			_note_gates(acc)
			if int(acc.cleared) >= Epochs.count():
				_note(acc, "epoch_all")
			var kt := kit_tier(acc)
			for t in range(1, kt + 1):
				_note(acc, "kit_%d" % t)
			if int(acc.runs) % 5 == 0 and int(acc.get("curve_at", -1)) != int(acc.runs):
				acc["curve_at"] = int(acc.runs)
				(acc.curve as Array).append({"h": snappedf(float(acc.min) / 60.0, 0.1), "runs": int(acc.runs), "pe": pe(acc),
					"cleared": int(acc.cleared), "r1": snappedf(float(ratios(acc.gear, mini(int(acc.cleared) + 1, 4))[0]), 0.01),
					"ins": int(acc.insignia_total), "cr": int(acc.crystals_total)})
		all.append(acc)
	return {"accounts": all}


static func _median(xs: Array) -> float:
	if xs.is_empty():
		return -1.0
	var s := xs.duplicate()
	s.sort()
	return float(s[s.size() / 2])


## Médiane (heures, runs) de l'événement [param key] ; -1 si moins de la moitié des comptes l'atteint.
static func milestone(res: Dictionary, key: String) -> Dictionary:
	var hs: Array = []
	var rs: Array = []
	var ps: Array = []
	var ls: Array = []
	var hls: Array = []
	var n := 0
	for acc in res.accounts:
		if acc.events.has(key):
			n += 1
			hs.append(float(acc.events[key].h))
			rs.append(int(acc.events[key].runs))
			ps.append(int(acc.events[key].get("pe", 0)))
			ls.append(float(acc.events[key].get("lvl", 0.0)))
			hls.append(int(acc.events[key].get("hl", 0)))
	if n * 2 < (res.accounts as Array).size():
		return {"h": -1.0, "runs": -1, "pe": -1, "lvl": -1.0, "hl": -1, "share": float(n) / maxf(1.0, (res.accounts as Array).size())}
	return {"h": snappedf(_median(hs), 0.1), "runs": int(_median(rs)), "pe": int(_median(ps)), "lvl": _median(ls),
		"hl": int(_median(hls)), "share": float(n) / float((res.accounts as Array).size())}


func print_report(res: Dictionary, skill: String) -> void:
	print("== progression d'un compte neuf (%s, %d comptes, classe %s) ==" % [skill, (res.accounts as Array).size(), cid])
	if heros:
		var mm := []
		for ep in range(1, 5):
			mm.append("%.2f/%.2f/%.2f" % [map_mult(ep, 1), map_mult(ep, 2), map_mult(ep, 3)])
		print("  niveau de héros (H7) : XP %.0f × %.3f^L, départ %d, MAP_MULT %s%s%s" % [xp_a, xp_g, hero_start, " | ".join(mm),
			", plafond d'époque" if epochcap else "", ", synchronisé" if sync else ""])
	var keys := ["epoch_1", "epoch_2", "epoch_3", "epoch_4", "dungeon_1", "dungeon_2", "kit_1", "kit_2", "kit_3", "kit_4",
			"open_dungeon_1", "open_dungeon_1_all", "open_dungeon_2", "open_dungeon_2_all", "open_siege_1", "open_siege_2",
			"open_rush_1", "open_rush_2", "legend_60", "legend_90", "dungeon_0", "kit80_ok", "kit90_ok", "kit90_opti"]
	if heros:
		for lv in HERO_MARKS:
			keys.append("hero%d" % lv)
	for key in keys:
		var m := milestone(res, key)
		var hl_txt: String = (", héros %d" % int(m.hl)) if heros else ""
		print("  %-18s : %s" % [key, ("médiane %.1f h, %d runs, PE %d, niveau des pièces %.0f%s (%.0f %% des comptes)" % [m.h, m.runs, m.pe, m.lvl, hl_txt, 100.0 * float(m.share)]) if float(m.h) >= 0.0 else "non atteint par la moitié des comptes (%.0f %%)" % (100.0 * float(m.share))])
	if heros:
		var hls := []
		for acc in res.accounts:
			hls.append(int(acc.hl))
		hls.sort()
		print("  niveau de héros final : min %d, médiane %d, max %d" % [hls[0], hls[hls.size() / 2], hls[-1]])
	if not quiet:
		var acc: Dictionary = res.accounts[0]
		print("  courbe du compte 1 (toutes les 5 runs) :")
		for c in acc.curve:
			print("    %5.1f h  run %3d  époque gagnée %d  PE %6d  R(carte 1) %.2f  insignes %6d  cristaux %6d" % [c.h, c.runs, c.cleared, c.pe, c.r1, c.ins, c.cr])
		var up := ""
		for slot in Items.SLOTS:
			var it: Dictionary = acc.gear.get(slot, {})
			if not it.is_empty():
				up += "%s:%d+%d " % [slot, int(it.get("level", 0)), int(it.get("upgrade", 0))]
		print("  équipement final du compte 1 : %s" % up)
		print("  insignes gagnés %d (dépensés %d), cristaux gagnés %d (dépensés %d), runs %d dont %d gagnées" % [acc.insignia_total, acc.spent_insignia, acc.crystals_total, acc.spent_crystals, acc.runs, acc.won_runs])
		if boss_plans:
			print("  plans des boss de carte (A4) : %d, pièces découvertes %d" % [int(acc.get("boss_plans", 0)), (acc.seen as Dictionary).size()])


## Gains à l'heure de chaque activité (barèmes du jeu, durées supposées) : cristaux, insignes, fournitures.
func activity_table() -> void:
	print("== gains à l'heure par activité (100 %% de réussite) ==")
	for ep in range(1, 5):
		print("  Survie époque %d (victoire type, 35 min) : insignes %d / h" % [ep, Economy.survival_insignia_per_hour(ep)])
	for d in 3:
		var per := 60.0 / DUNGEON_MIN
		print("  Donjon %s : cristaux %d / h, coffres de matières %.1f / h" % [Dungeons.DIFF_NAMES[d], roundi(ActivityLoot.dungeon_crystals(d) * per), (2 if d >= 2 else 1) * per + (per if d >= 1 else 0.0)])
	for d in 3:
		var per2 := 60.0 / RUSH_MIN
		print("  Ruée %s : cristaux %d / h" % [Dungeons.DIFF_NAMES[d], roundi(ActivityLoot.rush_crystals(Dungeons.rush_floors(), d) * per2)])
	for d in 3:
		var per3 := 60.0 / SIEGE_MIN
		print("  Siège %s : cristaux %d / h, formules %.0f / h" % [Dungeons.DIFF_NAMES[d], roundi(ActivityLoot.siege_crystals(Siege.WAVES, d, true) * per3), 3.0 * (d + 1) * per3])
	print("  Tour (Normal) : cristaux %d / h" % ActivityLoot.tower_crystals(int(60.0 / TOWER_FLOOR_MIN), 1))


## Boucles de la Survie (insignes et maîtrise à l'heure) : avant E6 (sans prorata ni plafond) et maintenant.
func loop_table() -> void:
	print("== boucles de la Survie, époque I : insignes / h | maîtrise / h (avant E6 → maintenant) ==")
	# [nom, minutes de jeu, carte atteinte, monstres, élites, victoire, niveau max]
	var cases := [["abandon à 1 min (10 monstres)", 1.0, 1, 10, 0, false, 3], ["défaite à 3 min (150 monstres)", 3.0, 1, 150, 1, false, 6],
		["défaite à 5 min (400 monstres)", 5.0, 1, 400, 3, false, 10], ["défaite en carte 2 (15 min)", 15.0, 2, 1200, 9, false, 22],
		["victoire (35 min, 2 500 monstres)", 35.0, 3, 2500, 20, true, 35], ["rage en carte 1 pendant 60 min", 60.0, 1, 10000, 40, false, 15]]
	var cap := int(Run.get_script().get_script_constant_map().get("KILL_CAP_PER_MAP", 1 << 30))
	for c in cases:
		var h := (float(c[1]) + LOAD_MIN) / 60.0
		var before := Economy.survival_insignia(int(c[2]), int(c[3]), int(c[4]), 1, bool(c[5]))
		var counted := mini(int(c[3]), cap * int(c[2]))
		var now := Economy.survival_insignia(int(c[2]), counted, int(c[4]), 1, bool(c[5]), float(c[1]) if int(c[2]) == 1 else -1.0)
		var m_before := int(c[6]) * 15 + int(c[3]) / 2 + int(c[4]) * 10 + (200 if c[5] else 0) + 120 * (int(c[2]) - 1)
		var m_now := int(c[6]) * 15 + counted / 2 + int(c[4]) * 10 + (200 if c[5] else 0) + 120 * (int(c[2]) - 1)
		print("  %-36s insignes %5d → %5d / h   maîtrise %6d → %6d / h" % [c[0], roundi(before / h), roundi(now / h), roundi(m_before / h), roundi(m_now / h)])


## Sonde : rapport de puissance de quelques équipements types à chaque époque (carte 1 et 3).
func probe() -> void:
	print("== rapport de puissance R = I / I(pièces +0 de l'époque I) / monstres (carte 1 | carte 3) ==")
	seed(7)
	var specs := ["new", "1.1.0", "1.3.0", "1.3.5", "1.3.10", "1.3.0.3", "1.3.0.4", "1.3.10.3", "2.3.10.4", "3.3.10.4", "4.3.10.4", "4.3.10", "4.3.0.4"]
	for spec in specs:
		var g := StarterGear.items(cid) if spec == "new" else StarterGear.scenario(spec, cid)
		var line := "  %-10s" % spec
		for ep in range(1, 5):
			var r := ratios(g, ep, false)
			line += "  E%d %.2f | %.2f" % [ep, float(r[0]), float(r[2])]
		print(line)


## Passe P5 : PE requise par chaque verrou (donjons, Siège, Ruée, butin légendaire) et PE d'équipements types.
func gates_table() -> void:
	print("== PE requise (donjon | siège) ==")
	for z in Dungeons.zone_ids():
		var line := "  %-14s" % z
		for d in 3:
			line += "  %s nv %d : %6d | %6d" % [Dungeons.DIFF_NAMES[d], Dungeons.level(String(z), d), Dungeons.power_required(String(z), d), Siege.power_required(String(z), d)]
		print(line)
	print("  Ruée : %d / %d / %d" % [Dungeons.power_required(Dungeons.RUSH, 0), Dungeons.power_required(Dungeons.RUSH, 1), Dungeons.power_required(Dungeons.RUSH, 2)])
	for lv in [20, 40, 60, 75, 90]:
		print("  légendaire au niveau %d : PE %d" % [lv, GearPower.required(lv, GearPower.LEGEND_RATIO)])
	print("== PE d'équipements types (époque.carte.+N.rang des gemmes) ==")
	seed(7)
	for spec in ["1.1.0", "1.3.0", "1.3.10.3", "2.3.0", "2.3.10.3", "3.3.0", "3.3.10.4", "4.1.10.4", "4.3.0", "4.3.5.4", "4.3.10.4"]:
		print("  %-10s PE %d" % [spec, GearPower.gear_power(StarterGear.scenario(spec, cid))])
	print("  compte neuf : PE %d" % GearPower.gear_power(StarterGear.items(cid)))
