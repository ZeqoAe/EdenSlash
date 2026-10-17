class_name Assault
extends RefCounted
## L'Assaut (lot TAC-0, étude conception/benchmark/TACTIQUE.md, rapport R_TAC_0.md) : 4 contre 4, une Charge à poser sur
## l'un de deux sites, une vie par manche, or de manche et achat entre les manches, premier à 7 en 12 manches. Mode
## d'équipes scellé du socle TeamMatch (fiche « assault », piège n° 1 de R_MODE0 : ne pose jamais Duel.active ni
## Royale.active). Ce fichier = les règles chiffrées (profil « assault » de ModeRules) et la MACHINE DE MANCHE pure, sans
## scène (comme Autochess) : achat -> manche -> pose / désamorçage -> fin de manche -> mi-temps / prolongation -> fin.
## Le directeur de scène (AssaultDirector) lui donne les K.O., les poses et les désamorçages et lit ses phases.
##
##   Assault.begin([["t0_0", "t0_1", …], ["t1_0", …]], {"first_attack": 1})   # clés des héros par équipe
##   var ev := Assault.tick(delta)     # [{"type": "live"}, {"type": "round_end", …}, …]
##   Assault.ko("t1_2", "t0_0", ["t0_1"]) ; Assault.plant("A", "t1_0") ; Assault.defuse("t0_3")
##   Assault.winner                     # équipe gagnante de la partie (-1 : en cours)
##
## Équipes : 0 = celle du joueur (TeamMatch.player_team), 1 = l'autre. attack = l'équipe qui attaque cette manche.
## Toutes les valeurs passent par ModeRules (profil « assault ») : mode dev (dev_edits > modes > assault) et
## modificateurs compris ; une partie peut en remplacer par ses options (Assault.begin(…, opts), tests, format Éclair).

## Règles de départ (TACTIQUE § 7.2, 7.3, 7.6 ; recommandations validées par le joueur). Combat (PvpCaps) : valeurs de
## départ de l'étude, à mesurer par la sonde du lot TAC-4.
const RULES := {
	# combat entre héros (PvpCaps, ModeRules) : un 1 contre 1 de 7 à 10 s, jamais mort en moins de ~3,5 s depuis la pleine vie.
	# Mesuré au lot TAC-4 (tools/assault_duel_probe, R_TAC_4 § 3) : valeurs de l'étude (échelle 0,13, coup 25 %, rafale 55 %
	# + 20 %) -> duel médian 37,8 s ; retenu : échelle 0,6, coup 30 % (au-delà le temps de duel ne baisse plus : les coups
	# portés sont plafonnés, la durée tient au nombre de coups qui touchent), auto-attaque ×1, rafale 45 % sur 2 s et 5 % du
	# reste (focus à 3 sur 1 : 3,7 s au plus court), acharnement léger dès 12 s (×2 toutes les 6 s : la traîne des duels
	# d'esquiveurs) -> duel médian 8,4 s en Normal, 12 s en Difficile
	"dmg_scale": 0.6, "basic_mult": 1.0, "heal_mult": 0.30, "max_mitigation": PvpCaps.MAX_MITIGATION,
	"pressure_start": 12.0, "pressure_step": 6.0, "pct_weight": 1.0,
	"hit_cap": 0.30, "burst_cap": 0.45, "burst_window": 2.0, "burst_excess": 0.05, "caps": PvpCaps.CAPS,
	# partie : premier à 7, 12 manches au plus, mi-temps après 6 ; prolongation à 6-6 par blocs de 2, 2 manches d'écart,
	# après 3 blocs une manche décisive (côté tiré au sort)
	"win": 7, "max_rounds": 12, "half": 6, "overtime": true, "ot_block": 2, "ot_blocks": 3,
	# temps (s) : achat (25 à la 1re manche de chaque moitié), manche, pose, mèche, désamorçage (sauvegarde à la moitié),
	# bandeau de fin de manche (rien n'attend de clic)
	"buy_time": 20.0, "buy_time_first": 25.0, "round_time": 100.0, "plant_time": 4.0, "fuse": 40.0,
	"defuse_time": 7.0, "defuse_save": 3.5, "banner": 5.0,
	# or de manche (§ 7.3)
	"start_gold": 800, "ot_gold": 4000, "gold_cap": 7000, "win_gold": 2400, "loss_gold": [1500, 1900, 2300, 2700],
	"kill_gold": 200, "assist_gold": 50, "plant_gold": 300, "defuse_gold": 200,
	# héros : fiche normalisée (niveau, comme le Duel à l'arme), sites (rayon de pose, m), portée de désamorçage (m)
	"level": 50, "site_radius": 5.0, "defuse_range": 1.8,
	# Charge (lot TAC-3) : ramassée en passant à moins de pickup_radius m ; l'explosion emporte les héros à moins de
	# blast_radius m (ils ne survivent pas à la manche) ; player_carry : le joueur porte la Charge quand il attaque
	"pickup_radius": 1.5, "blast_radius": 9.0,
	# rééquilibrage pour une vie (lot TAC-4, AssaultCombat ; TACTIQUE § 7.6) : contrôles × cc_mult puis plafond par type,
	# insensibilité commune cc_immunity s après tout contrôle dur, ralenti de chill_slow au plus ; invisibilité invis_max s ;
	# dégâts subis jamais sous min_taken (barrière, mur du titan) ; soins reçus plafonnés à heal_cap des PV max par manche ;
	# coups venus de plus de falloff_at m × falloff (Tireur : tireur_falloff_at) ; ultime : zone × ult_radius
	"cc_mult": 0.5, "cc_caps": {"stun": 1.0, "freeze": 1.0, "sleep": 1.0, "fear": 1.2, "root": 1.2, "disarm": 1.5, "chill": 2.0},
	"cc_immunity": 2.5, "chill_slow": 0.3, "invis_max": 2.5, "min_taken": 0.6, "barrier_taken": 0.8, "titan_taken": 0.7,
	"heal_cap": 0.6, "falloff_at": 16.0, "falloff": 0.75, "tireur_falloff_at": 20.0, "ult_radius": 1.3,
	# passifs des 5 rôles tactiques (§ 7.6) : PV et ténacité du Rempart, esquive de plus de l'Ouvreur, prise à revers (cible qui
	# ne l'a pas vu depuis backstab_after s), cible du Tireur révélée reveal_time s
	"role_hp": {"rempart": 1.2}, "role_tenacity": {"rempart": 0.2}, "ouvreur_dodges": 1, "backstab": 0.2, "backstab_after": 3.0,
	"reveal_time": 1.5,
	# effets des objets (lot TAC-5) lus par AssaultCombat : Enduit amer (soins reçus −), Fiole de garde (dégâts subis −)
	"bitter_cut": 0.4, "guard_cut": 0.25,
	# ultime (lot TAC-5) : points pour le lancer (élimination, chute, pose, désamorçage : un chacun)
	"ult_points": 7,
}
## Formats : options de partie qui remplacent les règles (Éclair : premier à 4, 7 manches, mi-temps après 3, la 7e décide).
const FORMATS := {
	"assault": {},
	"eclair": {"win": 4, "max_rounds": 7, "half": 3, "overtime": false, "start_gold": 1200},
}
## Comment une manche se gagne (frise du bilan, TAC-8).
const HOW := {"elim": "Élimination", "charge": "Charge", "defuse": "Désamorçage", "time": "Temps"}
const SITES := ["A", "B"]
const PHASES := ["buy", "live", "planted", "end", "done"]

static var active := false
static var format := "assault"
## Règles de la partie (RULES + format + options), lues par [method rule].
static var opts: Dictionary = {}
static var phase := ""
## Temps restant dans la phase (s) : achat, manche, mèche après la pose, bandeau.
static var t := 0.0
static var round_n := 0
static var score := [0, 0]
## Équipe qui attaque la manche en cours ; celle qui attaquait la 1re manche.
static var attack := 1
static var first_attack := 1
static var members: Array = [[], []]
## Or de chaque héros (clé -> or) ; série de défaites de chaque équipe.
static var money: Dictionary = {}
static var streak := [0, 0]
## Héros debout dans la manche en cours (clé -> vrai / faux).
static var alive: Dictionary = {}
## Site où la Charge est posée ("" : pas posée) ; qui l'a posée ; quand (temps de manche).
static var site := ""
static var planter := ""
## Désamorçage : avancement sauvegardé (s, point de sauvegarde à la moitié).
static var defuse_saved := 0.0
## Une ligne par manche : {n, winner, how, attack, time, planted, half}.
static var history: Array = []
## Statistiques de partie (clé -> {kills, deaths, assists, plants, defuses, gold}).
static var stats: Dictionary = {}
## Manches jouées en prolongation ; manche décisive en cours.
static var ot_rounds := 0
static var decisive := false
static var winner := -1
## Temps de la manche en cours (s, depuis le début de la phase « live »).
static var round_time := 0.0
static var _rng := RandomNumberGenerator.new()


# --- règles ------------------------------------------------------------------------------------

## Enregistre le profil « assault » de ModeRules (une fois ; lu par PvpCaps quand TeamMatch joue l'Assaut).
static func ensure_rules() -> void:
	if not ModeRules.has_profile("assault"):
		ModeRules.register("assault", RULES)


## Règle [param key] de la partie : options de la partie (format, tests), sinon le profil « assault » de ModeRules
## (mode dev et modificateurs compris).
static func rule(key: String) -> Variant:
	if opts.has(key):
		return opts[key]
	ensure_rules()
	return ModeRules.rule(key, RULES.get(key), "assault")


static func num(key: String) -> float:
	return float(rule(key))


# --- partie ------------------------------------------------------------------------------------

## Ouvre une partie : [param teams] = clés des héros de chaque équipe ([équipe 0, équipe 1]) ; [param o] : format
## (« assault », « eclair »), first_attack (équipe qui attaque d'abord, 1 par défaut : le joueur défend), seed, et toute
## règle de RULES à remplacer.
static func begin(teams: Array, o := {}) -> void:
	ensure_rules()
	reset()
	active = true
	format = String(o.get("format", "assault"))
	opts = (FORMATS.get(format, {}) as Dictionary).duplicate(true)
	opts.merge(o, true)
	_rng.seed = int(o.get("seed", randi()))
	members = [Array(teams[0]).duplicate(), Array(teams[1]).duplicate()]
	first_attack = int(o.get("first_attack", 1))
	attack = first_attack
	for tm in members:
		for k in tm:
			stats[k] = {"kills": 0, "deaths": 0, "assists": 0, "plants": 0, "defuses": 0, "gold": 0}
	_reset_money(int(num("start_gold")))
	_begin_round()


static func reset() -> void:
	active = false
	format = "assault"
	opts = {}
	phase = ""
	t = 0.0
	round_n = 0
	score = [0, 0]
	attack = 1
	first_attack = 1
	members = [[], []]
	money = {}
	streak = [0, 0]
	alive = {}
	site = ""
	planter = ""
	defuse_saved = 0.0
	history = []
	stats = {}
	ot_rounds = 0
	decisive = false
	winner = -1
	round_time = 0.0


static func defense() -> int:
	return 1 - attack


static func team_of(key: String) -> int:
	for i in 2:
		if (members[i] as Array).has(key):
			return i
	return -1


## « attaque » / « défense » pour l'équipe [param team] cette manche.
static func side_name(team: int) -> String:
	return "Attaque" if team == attack else "Défense"


static func alive_keys(team: int) -> Array:
	return (members[team] as Array).filter(func(k): return bool(alive.get(k, false)))


static func in_overtime() -> bool:
	return ot_rounds > 0 or (round_n > int(num("max_rounds")) and bool(rule("overtime")))


## Moitié de la manche [param n] (1, 2 ; 3 = prolongation).
static func half_of(n: int) -> int:
	if n > int(num("max_rounds")):
		return 3
	return 1 if n <= int(num("half")) else 2


## Nouvelle manche : côtés (mi-temps, prolongation), or (remis à la mi-temps, fixe en prolongation), tout le monde debout,
## phase d'achat.
static func _begin_round() -> void:
	round_n += 1
	var half := int(num("half"))
	var first_of_half := round_n == 1 or round_n == half + 1
	if round_n == half + 1:
		# mi-temps : on change de côté, or et séries remis à zéro
		attack = 1 - first_attack
		streak = [0, 0]
		_reset_money(int(num("start_gold")))
	if round_n > int(num("max_rounds")):
		# prolongation : or fixe à chaque manche, une manche par côté dans chaque bloc ; après les blocs, manche décisive
		var k := round_n - int(num("max_rounds")) - 1
		ot_rounds = k + 1
		decisive = k >= int(num("ot_block")) * int(num("ot_blocks"))
		attack = (_rng.randi() % 2) if decisive else (first_attack if k % 2 == 0 else 1 - first_attack)
		_reset_money(int(num("ot_gold")))
		first_of_half = k == 0
	alive = {}
	for tm in members:
		for key in tm:
			alive[key] = true
	site = ""
	planter = ""
	defuse_saved = 0.0
	round_time = 0.0
	phase = "buy"
	t = num("buy_time_first") if first_of_half else num("buy_time")


static func _reset_money(v: int) -> void:
	for tm in members:
		for k in tm:
			money[k] = v


static func gold(key: String) -> int:
	return int(money.get(key, 0))


## Ajoute [param v] d'or à [param key] (plafond gold_cap : le reste est perdu).
static func give(key: String, v: int) -> void:
	money[key] = mini(gold(key) + v, int(num("gold_cap")))
	if stats.has(key):
		stats[key].gold = int(stats[key].gold) + v


## Dépense (achat, lot TAC-5) : faux si l'or manque.
static func spend(key: String, v: int) -> bool:
	if gold(key) < v:
		return false
	money[key] = gold(key) - v
	return true


## Prime de la prochaine défaite de l'équipe [param team] (HUD : « prochaine manche : +1 500 au moins »).
static func next_loss_gold(team: int) -> int:
	var tab: Array = rule("loss_gold")
	return int(tab[clampi(int(streak[team]), 0, tab.size() - 1)])


# --- déroulé -------------------------------------------------------------------------------------

## Avance la machine de [param dt] secondes ; rend les événements de cette image : live (fin de l'achat), time (temps
## écoulé), explode (la Charge saute), round_end ({winner, how}), next (manche suivante, phase d'achat), done (fin).
static func tick(dt: float) -> Array:
	var ev: Array = []
	if not active or phase in ["", "done"]:
		return ev
	t -= dt
	match phase:
		"buy":
			if t <= 0.0:
				phase = "live"
				t = num("round_time")
				ev.append({"type": "live", "round": round_n})
		"live":
			round_time += dt
			if t <= 0.0:
				ev.append({"type": "time"})
				ev += end_round(defense(), "time")
		"planted":
			round_time += dt
			if t <= 0.0:
				ev.append({"type": "explode", "site": site})
				ev += end_round(attack, "charge")
		"end":
			if t <= 0.0:
				if winner >= 0:
					phase = "done"
					ev.append({"type": "done", "winner": winner})
				else:
					_begin_round()
					ev.append({"type": "next", "round": round_n, "attack": attack})
	return ev


## Un héros tombe : [param killer] (clé, "" : le décor) gagne la prime d'élimination, [param assists] celle d'aide.
## Rend les événements (fin de manche si une équipe est à terre).
static func ko(victim: String, killer := "", assists: Array = []) -> Array:
	if not alive.get(victim, false):
		return []
	alive[victim] = false
	if stats.has(victim):
		stats[victim].deaths = int(stats[victim].deaths) + 1
	var tv := team_of(victim)
	if killer != "" and team_of(killer) >= 0 and team_of(killer) != tv:
		give(killer, int(num("kill_gold")))
		stats[killer].kills = int(stats[killer].kills) + 1
	for a in assists:
		if a != killer and team_of(String(a)) >= 0 and team_of(String(a)) != tv:
			give(String(a), int(num("assist_gold")))
			stats[a].assists = int(stats[a].assists) + 1
	if not phase in ["live", "planted"] or tv < 0 or not alive_keys(tv).is_empty():
		return []
	if phase == "live":
		return end_round(1 - tv, "elim")
	# Charge posée : la Défense à terre ne peut plus désamorcer (l'Attaque gagne) ; l'Attaque à terre, la manche continue
	if tv == defense():
		return end_round(attack, "elim")
	return []


## La Charge est posée sur [param s] par [param by] : mèche de « fuse » s, +plant_gold à chaque attaquant.
static func plant(s: String, by: String) -> Array:
	if phase != "live" or team_of(by) != attack:
		return []
	phase = "planted"
	site = s
	planter = by
	t = num("fuse")
	defuse_saved = 0.0
	for k in members[attack]:
		give(String(k), int(num("plant_gold")))
	if stats.has(by):
		stats[by].plants = int(stats[by].plants) + 1
	return [{"type": "planted", "site": s, "by": by}]


## Désamorçage réussi par [param by] : la Défense gagne la manche.
static func defuse(by: String) -> Array:
	if phase != "planted" or team_of(by) != defense():
		return []
	give(by, int(num("defuse_gold")))
	if stats.has(by):
		stats[by].defuses = int(stats[by].defuses) + 1
	return [{"type": "defused", "by": by}] + end_round(defense(), "defuse")


## Point de sauvegarde du désamorçage : [param progress] s faits ; on repart de la moitié si on l'a dépassée.
static func defuse_resume(progress: float, full: float) -> float:
	var save := full * num("defuse_save") / maxf(num("defuse_time"), 0.01)
	return save if progress >= save else 0.0


## Fin de manche : score, or (victoire, défaite progressive, pas de prime aux attaquants vivants au temps écoulé),
## frise, fin de partie éventuelle ; bandeau de « banner » s (phase « end »).
static func end_round(w: int, how: String) -> Array:
	if not phase in ["buy", "live", "planted"]:
		return []
	var l := 1 - w
	score[w] = int(score[w]) + 1
	for k in members[w]:
		give(String(k), int(num("win_gold")))
	var loss := next_loss_gold(l)
	for k in members[l]:
		if how == "time" and l == attack and bool(alive.get(k, false)):
			continue  # (§ 7.3) attaquant vivant au temps écoulé sans pose : pas de prime de défaite
		give(String(k), loss)
	streak[l] = int(streak[l]) + 1
	streak[w] = maxi(0, int(streak[w]) - 1)  # une victoire fait redescendre la série d'un cran
	history.append({"n": round_n, "winner": w, "how": how, "attack": attack, "time": snappedf(round_time, 0.1),
		"planted": site, "half": half_of(round_n)})
	winner = _match_winner(w)
	phase = "end"
	t = num("banner")
	return [{"type": "round_end", "winner": w, "how": how, "round": round_n, "score": score.duplicate(), "match": winner}]


## Équipe qui a gagné la partie après la manche gagnée par [param last] (-1 : la partie continue).
static func _match_winner(last: int) -> int:
	var need := int(num("win"))
	var mx := int(num("max_rounds"))
	if round_n <= mx or not bool(rule("overtime")):
		if int(score[last]) >= need:
			return last
		if round_n >= mx and not bool(rule("overtime")):
			return 0 if int(score[0]) > int(score[1]) else (1 if int(score[1]) > int(score[0]) else last)
		return -1
	# prolongation : 2 manches d'écart, ou la manche décisive
	if decisive:
		return last
	if absi(int(score[0]) - int(score[1])) >= 2:
		return 0 if int(score[0]) > int(score[1]) else 1
	return -1


## Premier attaquant debout (le porteur est choisi par le directeur au lot TAC-3 : AssaultDirector._pick_carrier).
static func default_carrier() -> String:
	var a := alive_keys(attack)
	return String(a[0]) if not a.is_empty() else ""


## Kit tactique de la classe [param cid] (lot TAC-4 : data/assault_kits.json, AssaultCombat) : 4 sorts, sans enchaînement
## (signature, case 2, case 3, ultime). Sans kit (classe nouvelle) : les 4 premiers sorts de dégâts ou de contrôle.
static func kit_for(cid: String) -> Array:
	var ids := AssaultCombat.kit_ids(cid)
	if ids.size() == 4:
		return ids
	var all: Array = GameData.class_data(cid).get("skills", [])
	var main := all.filter(func(s): return not String(s.kind) in ["buff", "heal"])
	var rest := all.filter(func(s): return String(s.kind) in ["buff", "heal"])
	return (main + rest).slice(0, 4).map(func(s): return int(s.id))


## Classes interdites aux héros scriptés (comme le Battle royale : sorts sans IA).
const AI_EXCLUDED := ["black_blade", "light_blade"]


## [param n] classes différentes, de familles différentes d'abord, hors de [param avoid] (tirage par [param rng]).
static func pick_classes(rng: RandomNumberGenerator, n: int, avoid: Array = []) -> Array:
	var pool: Array = GameData.classes.keys().filter(func(c): return not c in avoid and not c in AI_EXCLUDED)
	pool.sort()
	for i in range(pool.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = pool[i]
		pool[i] = pool[j]
		pool[j] = tmp
	var out: Array = []
	var fams: Array = avoid.map(func(c): return int(GameData.class_data(String(c)).get("family", 0)))
	for pass_n in 2:  # d'abord des familles nouvelles, puis n'importe quelle classe restante
		for c in pool:
			if out.size() >= n:
				break
			var fam := int(GameData.class_data(String(c)).get("family", 0))
			if c in out or (pass_n == 0 and fam in fams):
				continue
			out.append(c)
			fams.append(fam)
	return out


# --- lancement et fin ------------------------------------------------------------------------------

const DIRECTOR := "res://scripts/core/assault_director.gd"
## Zone de la partie (biome, musique) : le village calcaire du Bourg.
const ZONE := "limestone"


## Lance une partie (page du lobby, world.tscn -- --assault) : run scellée de la classe [param cid] (aucune pièce, ni
## talent, ni certificat : fiche normalisée), kit tactique, puis TeamMatch.begin("assault") avec le directeur du mode.
## [param o] : options de la partie (format, map, diff_allies, diff_foes, watch, first_attack, seed, speed, et règles).
## Ensuite : get_tree().change_scene_to_file("res://scenes/world.tscn") (RunDirector.start monte AssaultDirector).
static func launch(cid: String, o := {}) -> void:
	ensure_rules()
	Run.start(cid)  # Profile.begin_run : copie du profil, rien n'est écrit tant que la partie dure (fiche : save = faux)
	Run.zone_id = String(o.get("zone", ZONE))
	Profile.equipped = {}
	Profile.inventory = []
	Profile.gold = 0
	Profile.keys = 0
	Profile.bag = {}
	PvpCaps.reset_stats()
	Run.skills = kit_for(cid).map(func(id): return {"id": int(id), "rank": 1})
	Run.chains = {}
	var spec := {"director": DIRECTOR}
	spec.merge(o, true)
	TeamMatch.begin("assault", 2, spec)
	reset()
	Run.changed.emit()


## Options d'un lancement direct (world.tscn -- --assault …) : --assault-map=arena|bourg, --assault-format=assault|eclair,
## --assault-diff=0..3 (les deux équipes) ou --assault-allies=N / --assault-foes=N, --assault-watch (8 IA, le joueur regarde),
## --assault-side=attack|defense (côté de ton équipe à la 1re manche), --assault-seed=N, --assault-speed=N (vitesse du jeu,
## mesures), --assault-win=N (manches pour gagner, essais), --assault-half=N.
static func args_options(args: PackedStringArray) -> Dictionary:
	var o := {}
	for a in args:
		if a.begins_with("--assault-map="):
			o["map"] = a.trim_prefix("--assault-map=")
		elif a.begins_with("--assault-format="):
			o["format"] = a.trim_prefix("--assault-format=")
		elif a.begins_with("--assault-diff="):
			o["diff_allies"] = int(a.trim_prefix("--assault-diff="))
			o["diff_foes"] = int(a.trim_prefix("--assault-diff="))
		elif a.begins_with("--assault-allies="):
			o["diff_allies"] = int(a.trim_prefix("--assault-allies="))
		elif a.begins_with("--assault-foes="):
			o["diff_foes"] = int(a.trim_prefix("--assault-foes="))
		elif a == "--assault-watch":
			o["watch"] = true
		elif a.begins_with("--assault-side="):
			o["first_attack"] = 0 if a.trim_prefix("--assault-side=") == "attack" else 1
		elif a.begins_with("--assault-seed="):
			o["seed"] = int(a.trim_prefix("--assault-seed="))
		elif a.begins_with("--assault-speed="):
			o["speed"] = float(a.trim_prefix("--assault-speed="))
		elif a.begins_with("--assault-win="):
			o["win"] = int(a.trim_prefix("--assault-win="))
		elif a.begins_with("--assault-half="):
			o["half"] = int(a.trim_prefix("--assault-half="))
		elif a.begins_with("--assault-rule="):
			# (lot TAC-3, mesures) toute règle de RULES : --assault-rule=buy_time:2 (nombre), plusieurs fois permis
			var kv := a.trim_prefix("--assault-rule=").split(":", true, 1)
			if kv.size() == 2 and RULES.has(kv[0]):
				o[kv[0]] = float(kv[1]) if kv[1].is_valid_float() else (JSON.parse_string(kv[1]) if kv[1].begins_with("{") else kv[1])
	return o


## Fin de partie : TeamMatch fermé AVANT toute écriture (piège 11 de R_MODE0), sauvegarde rechargée (rien du compte n'a
## bougé), vitesse du jeu rendue. Les récompenses scellées et les quêtes viennent au lot TAC-8. Le score et la frise
## restent lisibles (score, history, stats) jusqu'à la partie suivante.
static func finish() -> void:
	TeamMatch.end()
	active = false
	Engine.time_scale = 1.0
	Run.active = false
	Profile.in_run = false
	Profile.reload_keep_records()
	Profile.gold = 0
	Profile.keys = 0
	Profile.bag = {}
	Profile._lobby_view()
	Profile.save_profile()


## Résumé d'une ligne (mesures, --auto-quit).
static func summary() -> String:
	return "score %d-%d en %d manches (%s) %s" % [int(score[0]), int(score[1]), round_n, format,
		" ".join(history.map(func(e): return "%d:%s%s" % [int(e.n), "AD"[int(e.winner == e.attack) ^ 1], String(e.how).left(1)]))]
