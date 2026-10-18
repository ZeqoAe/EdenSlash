class_name Colisee
extends RefCounted
## Le Colisée (étude BM-ARENA, conception/benchmark/ARENA.md § 6 ; lots CO-A et suivants, rapports conception/benchmark/R_CO_*.md) :
## 6 équipes de 3 héros (Classique), 4 (Éclair) ou 8 (Grand tournoi, caché tant que la sonde de performances du lot CO-C ne
## l'a pas validé) ; manches de combats 3 contre 3 simultanés, PV d'équipe, barème croissant, appariement tournant, exempt,
## élimination, places. Mode scellé, joué seul contre des IA scriptées (ClassRival).
##
## Cette classe est la MACHINE DE PARTIE, sans scène (patron de la machine Autochess) : testable « au tableau » par milliers
## de parties (Colisee.simulate). Le combat réel (core/colisee_director.gd, lot CO-C) lui rend les résultats de chaque
## manche (report) ; l'état des équipes du jeu (camps, arènes, vivants, places) est celui de TeamMatch, que le directeur
## tient à jour dans le même ordre (TeamMatch.eliminate après chaque élimination rendue par report).
##
## Utilisation :
##   var g := Colisee.new("classique", graine)        # ou Colisee.begin(...) : partie du jeu (TeamMatch, règles, Run)
##   while not g.is_over():
##       var r := g.next_round()                       # {n, pairs: [[a, b], …], bye: équipe exempte ou -1}
##       … combats …
##       g.report([{a, b, winner (-1 : égalité), left_a, left_b (part des PV des héros restants), ko_a, ko_b}, …])
##   g.standing() ; g.place ; g.history
##
## Règles chiffrées (§ 6.3, valeurs de départ à mesurer au lot CO-I) : FORMATS, TEAM_HP, FIGHT_TIME, PROFILE.

## Jouable de bout en bout (lots CO-A à CO-H) : tant que faux, l'activité est cachée du menu Jouer hors mode dev.
const READY := false
const MODE := "colisee"
const TEAM_HP := 100
const SIZE := 3
## Niveau des héros (fiche « à l'arme », profil duel_a : manches de 66-81 s à tout niveau).
const LEVEL := 60
## Barème : [[dernière manche, perte], …] ; la dernière ligne (manche 0) vaut pour toutes les suivantes.
const LOSS_CLASSIC := [[3, 20], [6, 25], [9, 35], [11, 50], [0, 100]]
const LOSS_FAST := [[2, 25], [4, 35], [6, 50], [0, 100]]
## Formats. locked : fermé au lobby. Grand tournoi : ouvert par la sonde de performances du lot CO-C (R_CO_C.md : 24 héros en
## Hardcore, image médiane 7,1-7,6 ms et p95 10-12 ms avec rendu, comme 18 héros ; la colonne compacte des 8 équipes : lot CO-L).
const FORMATS := {
	"classique": {"name": "Classique", "teams": 6, "prep": 30.0, "loss": LOSS_CLASSIC},
	"eclair": {"name": "Éclair", "teams": 4, "prep": 25.0, "loss": LOSS_FAST},
	"grand": {"name": "Grand tournoi", "teams": 8, "prep": 30.0, "loss": LOSS_CLASSIC},
}
const FORMAT_ORDER := ["classique", "eclair", "grand"]
## Combat : compte à rebours, anneau de feu dès RING_START s, fin forcée à FIGHT_TIME s (égalité : PV restants).
const COUNTDOWN := 3.0
const RING_START := 25.0
const FIGHT_TIME := 85.0
## Fin de manche (bandeau) et transitions (estimation de la durée d'une partie).
const RECAP := 2.5
const TRANSITION := 8.0
## Difficultés (ClassRival.DIFF 0-3 et niveau du chef d'équipe ColiseeCoach, lot CO-D) ; 4 = Mélange (une difficulté tirée par
## équipe adverse).
const DIFFS := ["Recrue", "Vétéran", "Champion", "Légende", "Mélange"]
## Profil de règles « colisee » (ModeRules.register au lancement ; jamais au démarrage du jeu : test_mode0 vérifie qu'un mode
## non enregistré lit les chiffres du duel). Échelle 0,045 (lot CO-D, R_CO_D.md : mesurée au banc tools/colisee_games avec les
## chefs d'équipe, combats miroirs de 48 à 57 s de médiane de Recrue à Champion ; 0,030 au départ) ; soins moitié ;
## pas d'acharnement ni de mort subite (l'anneau de feu les remplace) ; bonus en % aux trois quarts.
const PROFILE := {
	"dmg_scale": 0.045, "basic_mult": PvpCaps.BASIC_MULT, "heal_mult": PvpCaps.HEAL_MULT * 0.5,
	"max_mitigation": PvpCaps.MAX_MITIGATION, "pressure_start": 100000.0, "pressure_step": PvpCaps.PRESSURE_STEP,
	"pct_weight": 0.75, "sudden_after": 100000.0, "hit_cap": 0.15, "burst_cap": 0.35, "burst_window": 2.0, "burst_excess": 0.25,
	"caps": PvpCaps.CAPS,
}
## Modèle de la simulation « au tableau » (ARENA § 5.1) : force d'équipe ~ N(0, STRENGTH_SD), victoire logistique ;
## durée d'un combat ~ N(FIGHT_MEAN, FIGHT_SD) bornée [FIGHT_MIN, FIGHT_TIME] ; égalité exacte TIE_P.
const STRENGTH_SD := 0.8
const FIGHT_MEAN := 60.0
const FIGHT_SD := 12.0
const FIGHT_MIN := 30.0
const TIE_P := 0.01

## Partie du jeu en cours (Colisee.begin) ; null hors partie.
static var game: Colisee = null

var format := "classique"
var fmt: Dictionary = {}
var n := 6
var rng := RandomNumberGenerator.new()
var hp: Array = []  ## PV d'équipe (peuvent passer sous 0 : l'ordre des éliminations simultanées)
var out: Array = []  ## équipe éliminée
var place: Array = []  ## place finale (0 : encore en lice)
var met: Array = []  ## met[a][b] : combats déjà joués entre a et b
var byes: Array = []  ## manches exemptées par équipe
var last_opp: Array = []  ## dernier adversaire de chaque équipe (-1 : aucun ou exempt)
var round_wins: Array = []
var kos: Array = []  ## K.O. donnés par équipe
var round_n := 0
var current: Dictionary = {}  ## manche en cours : {n, pairs, bye}
var history: Array = []  ## une entrée par manche : {n, pairs, bye, results, losses, eliminated}
var out_order: Array = []  ## équipes éliminées, la première en tête
## Appariements qui ont dû revoir une équipe avant d'avoir vu toutes les autres (0 attendu ; test_co_a).
var rematch_violations := 0
## Réglages de la partie du jeu (difficulté, classe du joueur, trios) : remplis par begin.
var diff := 1
var team_diffs: Array = []
var classes: Array = []  ## classes de chaque trio : [[cid, cid, cid], …]
var player_team := 0


func _init(p_format := "classique", seed_value := 0, n_teams := -1) -> void:
	format = p_format if FORMATS.has(p_format) else "classique"
	fmt = FORMATS[format]
	n = int(fmt.teams) if n_teams < 2 else n_teams
	rng.seed = seed_value if seed_value != 0 else randi()
	for t in n:
		hp.append(TEAM_HP)
		out.append(false)
		place.append(0)
		byes.append(0)
		last_opp.append(-1)
		round_wins.append(0)
		kos.append(0)
		var row: Array = []
		row.resize(n)
		row.fill(0)
		met.append(row)


# --- barème -------------------------------------------------------------------------------------------------------------

## Perte de PV d'équipe d'une manche perdue à la manche [param r] (barème [param loss]).
static func loss_for(loss: Array, r: int) -> int:
	for row in loss:
		if int(row[0]) == 0 or r <= int(row[0]):
			return int(row[1])
	return int(loss[-1][1])


func loss_at(r := -1) -> int:
	return loss_for(fmt.loss, round_n if r < 0 else r)


## Première manche de mort subite (barème 100) du format.
func sudden_round() -> int:
	var last := 0
	for row in fmt.loss:
		if int(row[0]) == 0:
			return last + 1
		last = int(row[0])
	return last + 1


# --- état ---------------------------------------------------------------------------------------------------------------

func alive() -> Array:
	var o: Array = []
	for t in n:
		if not out[t]:
			o.append(t)
	return o


func is_over() -> bool:
	return alive().size() <= 1


## Classement : places attribuées d'abord (1re en tête), puis les équipes en lice par PV.
func standing() -> Array:
	var keyed: Array = []
	for t in n:
		keyed.append([0 if place[t] > 0 else 1, place[t] if place[t] > 0 else -hp[t], t])
	keyed.sort()
	return keyed.map(func(e): return e[2])


func winner() -> int:
	for t in n:
		if place[t] == 1:
			return t
	return -1


# --- appariement tournant -----------------------------------------------------------------------------------------------

## Combats de moins entre [param a] et l'équipe en lice qu'il a le moins vue (règle : pas deux fois la même équipe avant
## d'avoir vu toutes les autres).
func _min_met(a: int, al: Array) -> int:
	var m := 1 << 30
	for c in al:
		if c != a:
			m = mini(m, int(met[a][c]))
	return m


func _pair_ok(a: int, b: int, al: Array) -> bool:
	return int(met[a][b]) <= _min_met(a, al) and int(met[a][b]) <= _min_met(b, al)


## Tous les appariements parfaits de [param ids] (taille paire), dans un ordre tiré au sort.
func _matchings(ids: Array) -> Array:
	if ids.is_empty():
		return [[]]
	var a: int = ids[0]
	var outl: Array = []
	for j in range(1, ids.size()):
		var rest := ids.slice(1)
		rest.erase(ids[j])
		for m in _matchings(rest):
			outl.append([[a, ids[j]]] + m)
	return outl


func _shuffled(arr: Array) -> Array:
	var a := arr.duplicate()
	for i in range(a.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = a[i]
		a[i] = a[j]
		a[j] = tmp
	return a


func _violations(pairs: Array, al: Array) -> int:
	var v := 0
	for p in pairs:
		if not _pair_ok(int(p[0]), int(p[1]), al):
			v += 1
	return v


## Une manche sans revoir trop tôt une équipe existe-t-elle encore [param depth] manches de suite après [param pairs] ?
func _future_ok(pairs: Array, al: Array, depth: int) -> bool:
	if depth <= 0:
		return true
	for p in pairs:
		met[p[0]][p[1]] += 1
		met[p[1]][p[0]] += 1
	var ok := false
	for bye in (al if al.size() % 2 == 1 else [-1]):
		var rest := al.filter(func(t): return t != bye)
		for m in _matchings(rest):
			if _violations(m, al) == 0 and _future_ok(m, al, depth - 1):
				ok = true
				break
		if ok:
			break
	for p in pairs:
		met[p[0]][p[1]] -= 1
		met[p[1]][p[0]] -= 1
	return ok


## Appariement de la manche : {pairs, bye}. Exempt (nombre impair) : l'équipe la moins exemptée, jamais deux fois de suite
## si possible. Combats : sans revoir une équipe avant d'avoir vu toutes les autres en lice (avec 2 manches d'avance, pour
## ne pas s'enfermer : 6 équipes après 3 manches peuvent former deux triangles sans appariement possible) ; à égalité, pas
## la revanche de la manche d'avant ; au hasard ensuite.
func pairing(al: Array = []) -> Dictionary:
	if al.is_empty():
		al = alive()
	var bye_opts: Array = [-1]
	if al.size() % 2 == 1:
		var least := 1 << 30
		for t in al:
			least = mini(least, int(byes[t]))
		bye_opts = _shuffled(al.filter(func(t): return int(byes[t]) == least))
		var last_bye := int(history[-1].bye) if not history.is_empty() else -1
		if bye_opts.size() > 1 and last_bye in bye_opts:
			bye_opts.erase(last_bye)
			bye_opts.append(last_bye)
	var best: Array = []
	var best_key: Array = []
	var best_bye := -1
	for bye in bye_opts:
		var rest := al.filter(func(t): return t != bye)
		for m in _shuffled(_matchings(rest)):
			var viol := _violations(m, al)
			var rematch := 0
			for p in m:
				if int(last_opp[p[0]]) == int(p[1]):
					rematch += 1
			var key := [viol, 0, rematch]
			if viol == 0 and not best_key.is_empty() and int(best_key[0]) == 0 and int(best_key[1]) == 0 and rematch >= int(best_key[2]):
				continue
			if viol == 0:
				key[1] = 0 if _future_ok(m, al, 2) else 1
			if best_key.is_empty() or key < best_key:
				best_key = key
				best = m
				best_bye = bye
			if int(best_key[0]) == 0 and int(best_key[1]) == 0 and int(best_key[2]) == 0:
				break
		if not best_key.is_empty() and int(best_key[0]) == 0 and int(best_key[1]) == 0 and int(best_key[2]) == 0:
			break
	if not best_key.is_empty():
		rematch_violations += int(best_key[0])
	return {"pairs": best, "bye": best_bye}


# --- manches ------------------------------------------------------------------------------------------------------------

## Manche suivante : appariement tiré, rien n'est joué. {n, pairs, bye, loss}.
func next_round() -> Dictionary:
	round_n += 1
	var pr := pairing()
	current = {"n": round_n, "pairs": pr.pairs, "bye": pr.bye, "loss": loss_at()}
	return current


## Résultats de la manche en cours ([param results] : {a, b, winner (-1 égalité), left_a, left_b, ko_a, ko_b} par combat ;
## left = part des PV des héros encore debout, lue pour départager une égalité au temps). Rend les éliminations
## [[équipe, place], …] dans l'ordre où le directeur doit les rendre à TeamMatch (la pire d'abord).
func report(results: Array) -> Array:
	var loss := loss_at()
	var losses := {}
	for r in results:
		var a := int(r.a)
		var b := int(r.b)
		met[a][b] += 1
		met[b][a] += 1
		last_opp[a] = b
		last_opp[b] = a
		kos[a] += int(r.get("ko_a", 0))
		kos[b] += int(r.get("ko_b", 0))
		var w := int(r.get("winner", -1))
		if w < 0:
			w = tie_winner(float(r.get("left_a", 0.0)), float(r.get("left_b", 0.0)), a, b)
		if w == a or w == b:
			round_wins[w] += 1
			var l := b if w == a else a
			losses[l] = loss
		else:
			# égalité exacte : les deux perdent la moitié du barème
			losses[a] = ceili(loss * 0.5)
			losses[b] = ceili(loss * 0.5)
	var bye := int(current.get("bye", -1))
	if bye >= 0:
		byes[bye] += 1
		last_opp[bye] = -1
	for t in losses:
		hp[t] -= int(losses[t])
	var dead: Array = []
	for t in alive():
		if int(hp[t]) <= 0:
			dead.append(t)
	# éliminations simultanées : la plus basse en PV d'abord, puis la moins de manches gagnées, puis la moins de K.O.
	var keyed: Array = []
	for t in dead:
		keyed.append([int(hp[t]), int(round_wins[t]), int(kos[t]), rng.randf(), t])
	keyed.sort()
	var elim: Array = []
	for e in keyed:
		var t: int = e[4]
		var pl := alive().size()
		out[t] = true
		place[t] = pl
		out_order.append(t)
		elim.append([t, pl])
	var left := alive()
	if left.size() == 1:
		place[left[0]] = 1
	history.append({"n": round_n, "pairs": current.get("pairs", []), "bye": bye, "results": results.duplicate(true),
		"losses": losses, "eliminated": elim, "hp": hp.duplicate()})
	current = {}
	return elim


## Égalité au temps (FIGHT_TIME) : l'équipe qui garde la plus grande part de ses PV gagne ; égalité exacte : -1.
static func tie_winner(left_a: float, left_b: float, a: int, b: int) -> int:
	if absf(left_a - left_b) < 0.001:
		return -1
	return a if left_a > left_b else b


## Combat résolu « au tableau » (repli d'un combat caché, ARENA § 6.10) : PV restants × frappe de chaque camp
## (Royale.strike) ; rend 0 (camp A), 1 (camp B) ou -1 (personne debout des deux côtés).
static func resolve_board(side_a: Array, side_b: Array) -> int:
	var pa := _side_power(side_a)
	var pb := _side_power(side_b)
	if pa <= 0.0 and pb <= 0.0:
		return -1
	return 0 if pa >= pb else 1


static func _side_power(side: Array) -> float:
	var hp_sum := 0.0
	var hit := 0.0
	for c in side:
		var cc := c as Combatant
		if cc == null or not is_instance_valid(cc) or cc.is_dead:
			continue
		hp_sum += cc.hp
		hit += Royale.strike(cc)
	return hp_sum * hit


# --- simulation « au tableau » --------------------------------------------------------------------------------------------

## Partie complète sans scène (ARENA § 5.1) : force d'équipe tirée au hasard (ou [param strengths]), victoire logistique,
## durées de combat tirées ; une manche dure autant que son plus long combat. Rend {rounds, places, minutes, violations,
## winner, strengths, history}.
static func simulate(p_format := "classique", seed_value := 1, strengths: Array = []) -> Dictionary:
	var g := Colisee.new(p_format, seed_value)
	var s := strengths.duplicate()
	while s.size() < g.n:
		s.append(g.rng.randfn(0.0, STRENGTH_SD))
	var secs := 0.0
	var guard := 0
	while not g.is_over() and guard < 60:
		guard += 1
		var r := g.next_round()
		var res: Array = []
		var longest := 0.0
		for p in r.pairs:
			var a := int(p[0])
			var b := int(p[1])
			var dur := clampf(g.rng.randfn(FIGHT_MEAN, FIGHT_SD), FIGHT_MIN, FIGHT_TIME)
			longest = maxf(longest, dur)
			var w := a if g.rng.randf() < 1.0 / (1.0 + exp(-(float(s[a]) - float(s[b])))) else b
			if g.rng.randf() < TIE_P:
				w = -1
			res.append({"a": a, "b": b, "winner": w, "left_a": 0.5, "left_b": 0.5, "ko_a": 3 if w == a else 1, "ko_b": 3 if w == b else 1})
		secs += float(g.fmt.prep) + COUNTDOWN + longest + RECAP + TRANSITION
		g.report(res)
	return {"rounds": g.round_n, "places": g.place.duplicate(), "minutes": secs / 60.0, "violations": g.rematch_violations,
		"winner": g.winner(), "strengths": s, "history": g.history, "game": g}


# --- trios ----------------------------------------------------------------------------------------------------------------

## Trios de la partie : [param n_teams] équipes de SIZE classes de familles différentes, aucune classe deux fois ; l'équipe 0
## commence par [param player_cid] (le joueur). Tirage par [param r] (graine de la partie).
static func compose_teams(n_teams: int, player_cid: String, r: RandomNumberGenerator) -> Array:
	var pool: Array = GameData.classes.keys()
	pool.sort()
	for i in range(pool.size() - 1, 0, -1):
		var j := r.randi_range(0, i)
		var tmp = pool[i]
		pool[i] = pool[j]
		pool[j] = tmp
	var used := {}
	if player_cid != "":
		used[player_cid] = true
	var teams: Array = []
	for t in n_teams:
		var trio: Array = [player_cid] if t == 0 and player_cid != "" else []
		var fams: Array = trio.map(func(c): return Duel.family_of(String(c)))
		for pass_n in 2:
			for c in pool:
				if trio.size() >= SIZE:
					break
				if used.has(c) or (pass_n == 0 and Duel.family_of(String(c)) in fams):
					continue
				trio.append(c)
				fams.append(Duel.family_of(String(c)))
				used[c] = true
		teams.append(trio)
	return teams


## Difficulté de chaque équipe (difficulté choisie [param d] 0-3, ou 4 = Mélange : une par équipe adverse) ; l'équipe du
## joueur (ses alliés) prend la difficulté choisie (Mélange : Normal).
static func team_difficulties(d: int, n_teams: int, r: RandomNumberGenerator) -> Array:
	var o: Array = []
	for t in n_teams:
		if d < 4:
			o.append(clampi(d, 0, 3))
		else:
			o.append(1 if t == 0 else r.randi_range(0, 3))
	return o


# --- partie du jeu ----------------------------------------------------------------------------------------------------------

## Profil de règles « colisee » : enregistré au lancement (pas au démarrage du jeu).
static func register_rules() -> void:
	if not ModeRules.has_profile(MODE):
		ModeRules.register(MODE, PROFILE)


static func visible() -> bool:
	return READY or bool(Settings.get_v("interface", "dev_mode"))


## Ouvre une partie du jeu : Run (héros [param cid], mode scellé : rien du compte, équipement mis de côté comme au Battle
## royale), règles, TeamMatch (« colisee », [param p_format], directeur du combat), machine de partie (Colisee.game).
## [param n_teams] : nombre d'équipes imposé (sonde de performances : 2 = une seule arène) ; -1 : celui du format.
## Ensuite : change_scene_to_file("res://scenes/world.tscn") (RunDirector monte le directeur).
static func begin(cid: String, p_format := "classique", p_diff := 1, seed_value := 0, n_teams := -1) -> Colisee:
	var g := Colisee.new(p_format, seed_value, n_teams)
	g.diff = clampi(p_diff, 0, DIFFS.size() - 1)
	g.team_diffs = team_difficulties(g.diff, g.n, g.rng)
	g.classes = compose_teams(g.n, cid, g.rng)
	register_rules()
	Run.start(cid)
	Run.zone_id = Duel.ZONE
	Run.fill_from_preset()
	if Run.skills.is_empty():
		for sk in Run.class_data().get("skills", []).slice(0, 4):  # sans préréglage : les 4 premiers sorts de la classe
			Run.skills.append({"id": int(sk.id), "rank": 1})
	Profile.equipped = {}
	Profile.inventory = []
	Profile.gold = 0
	Profile.keys = 0
	Profile.bag = {}
	PvpCaps.reset_stats()
	TeamMatch.begin(MODE, g.n, {"format": p_format, "difficulty": g.diff, "director": "res://scripts/core/colisee_director.gd"})
	game = g
	return g


## Ferme la partie (avant toute récompense : TeamMatch.end, piège 11 de R_MODE0) ; le profil est rechargé par l'appelant.
static func finish() -> void:
	TeamMatch.end()
	game = null
