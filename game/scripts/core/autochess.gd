class_name Autochess
extends RefCounted
## L'Échiquier (lot AC-B) : une partie, sans scène ni nœud. Spécification : conception/autochess/SPEC.md (§2, §3.2, §5, §6) ;
## tables : AutochessData ; réserve partagée : AutochessPool ; rapport (API pour les lots D, E, F, G, I) : R_AC_B.md.
##
## Machine d'étapes : « prep » (préparation : boutique, banc, plateau, choix) -> end_prep() -> « combat » (fights à jouer)
## -> run_fights() ou finish_combat(résultats) -> « recap » (bilan de manche) -> next_round() -> « prep »… -> « over ».
## step() avance d'une phase ; play_to_end() joue toute la partie (tests, simulateur). Le temps (minuteur, bouton Prêt) est
## celui du directeur : la machine ne compte rien.
##
## Combat INJECTÉ : `fight` = Callable(plateau_a: Array, plateau_b: Array, ctx: Dictionary) -> Dictionary
##   résultat : {"winner": 0 (a) | 1 (b) | -1 (égalité), "stars": [[étoiles debout de a], [étoiles debout de b]],
##   "duration": s, "gold": [or gagné en combat par a, par b] (facultatif : objet Fortune)}.
##   Monstres : plateau_b = [{"monster": "elite" | "sbire"}…] ; gardien : [{"guardian": true, "stage", "mult"}]
##   (debout = un élément dans stars[1]). Sans Callable : power_fight (provisoire, lot AC-C / AC-E à brancher).
##   Le directeur du vrai combat peut aussi lire `fights` et rendre ses résultats par finish_combat().
##
## Stratèges : strategists[i] = objet avec decide(partie, i) (préparation : appelle buy / sell / reroll / buy_xp / place /
## to_bench / equip) et choose(partie, i, choix) -> indice (-1 = relancer un choix d'atout). null = joueur humain (l'interface
## appelle les mêmes fonctions puis choose()). Seul hasard permis : `rng` de la partie (même graine = même partie, reprise
## identique). RandomStrategist ci-dessous sert les tests.
##
## Sauvegarde au début de chaque préparation (après les décisions des IA) dans `save_path` par SafeFile ; jamais le profil.
## Plateau : cases [colonne 0-6, rangée 0-3], rangée 0 = la plus proche de l'ennemi (AC-F affiche le miroir).
## Objets (chaînes) : composant (« lame »…), objet complet (« executeur »…), « marteau_reforge » (banc d'objets seulement),
## emblème « embleme:<composant>:<trait> » (trait vide tant que le choix n'est pas fait) : voir parse_item().

signal changed(pi: int)  # l'état d'un stratège a changé (or, boutique, banc, plateau, choix)
signal phase_changed(phase: String)

const SAVE_PATH := "user://autochess_save.json"
const SAVE_VERSION := 1
const MAX_ROUNDS := 150  # garde-fou de play_to_end (une partie finit vers 35 manches)
const FIGHT_KINDS := ["jcj", "monstres", "gardien"]
const ROW_ORDER := {"avant": [0, 1, 2, 3], "milieu": [1, 2, 0, 3], "arriere": [3, 2, 1, 0]}
## Combat provisoire (power_fight) : puissance des monstres et du gardien, chance d'égalité.
const PF_SBIRE := 0.8
const PF_ELITE := 1.6
const PF_GUARDIAN_PER_STAGE := 1.8
const PF_ITEM := 0.15
const PF_DRAW := 0.02

var seed_value := 0
var rng := RandomNumberGenerator.new()
var pool := AutochessPool.new()
var players: Array = []  # un dictionnaire par stratège (voir _new_player)
var strategists: Array = []  # non sauvegardés : le lanceur les redonne à la reprise
var fight := Callable()
var save_path := SAVE_PATH  # "" : aucune sauvegarde (tests, simulateur)
var stage := 1
var round_i := 1
var rounds_played := 0
var phase := ""
var fights: Array = []  # combats de la manche : {kind, a, b, ghost_of, board_a, board_b, ctx}
var results: Array = []  # résultats normalisés, même ordre que fights
var carousel: Dictionary = {}  # choix partagé en cours : {options: [{id, component, taken_by}], order, next}
var augment_rarity := ""
var last_rarity := ""
var next_uid := 1
var history: Array = []  # une ligne par combat (tests de déterminisme, journal)
var _limbo: Dictionary = {}  # unité reçue banc plein, absorbée par la fusion
## Lot ACX-2 : pile d'annulation des stratèges humains (le jeu est solo : aucun abus possible), voir undo().
var _undo: Dictionary = {}  # pi -> [{label, player, pool, rng}]
## Lot ACX-3 : format (AutochessData.FORMATS : « classique », « eclair ») et règle du jour (DAY_RULES, "" : aucune), fixés
## par configure() avant start() et sauvegardés avec la partie ; `rules` = les deux en un dictionnaire (rules_for).
var format := "classique"
var day_rule := ""
var rules: Dictionary = AutochessData.rules_for()


## Format et règle du jour de la partie (avant start(), ou relus par from_dict()).
func configure(fmt := "classique", rule := "") -> void:
	rules = AutochessData.rules_for(fmt, rule)
	format = String(rules.format)
	day_rule = String(rules.rule)


## Règle [param key] de la partie (format, puis règle du jour), [param default] si aucune.
func rule(key: String, default: Variant = null) -> Variant:
	return rules.get(key, default)


## PV de départ d'un stratège (100, 40 en Éclair).
func max_hp() -> int:
	return int(rules.get("player_hp", AutochessData.PLAYER_HP))


func reroll_cost() -> int:
	return int(rules.get("reroll_cost", AutochessData.REROLL_COST))


func xp_cost() -> int:
	return int(rules.get("xp_cost", AutochessData.XP_BUY_COST))


## Type de la manche [param st]-[param rd] selon le format (ouverture, monstres, jcj, choix, gardien).
func kind_at(st: int, rd: int) -> String:
	return AutochessData.round_kind(st, rd, rules)


func rounds_in(st: int) -> int:
	return AutochessData.rounds_in(st, rules)


func is_augment_round(st := -1, rd := -1) -> bool:
	return AutochessData.is_augment_round(stage if st < 0 else st, round_i if rd < 0 else rd, rules)


# --- Lancement ----------------------------------------------------------------------------------------------------
## Nouvelle partie de graine [param game_seed] ; [param strats] : 8 stratèges (null = humain) ; [param fight_fn] : combat.
func start(game_seed: int, strats: Array = [], fight_fn := Callable()) -> void:
	seed_value = game_seed
	rng.seed = game_seed
	pool.reset()
	players.clear()
	for i in AutochessData.PLAYERS:
		players.append(_new_player(i))
	set_strategists(strats)
	fight = fight_fn
	stage = 1
	round_i = 1
	rounds_played = 0
	next_uid = 1
	history.clear()
	carousel = {}
	augment_rarity = ""
	last_rarity = ""
	_begin_prep()


func set_strategists(strats: Array) -> void:
	strategists.clear()
	for i in AutochessData.PLAYERS:
		strategists.append(strats[i] if i < strats.size() else null)
		if i < players.size():
			players[i].human = strategists[i] == null


func _new_player(i: int) -> Dictionary:
	var bench: Array = []
	bench.resize(AutochessData.BENCH_SIZE)
	var shop: Array = []
	for _k in AutochessData.SHOP_SIZE:
		shop.append("")
	return {
		"id": i, "human": false, "hp": max_hp(), "hp_before": max_hp(), "alive": true,
		"place": 0, "abandoned": false, "gold": 0, "level": AutochessData.LEVEL_AT_START, "xp": 0,
		"max_level": AutochessData.MAX_LEVEL, "board": [], "bench": bench, "items": [], "shop": shop, "locked": false,
		"free_rerolls": 0, "streak": 0, "recent": [], "ghost_last": false, "augments": [], "crowns": int(rule("crowns", 0)), "trait_bonus": {},
		"buys": 0, "pending": [], "ready": false, "income": {}, "last": {}, "final_board": [],
		"stats": {"won": 0, "lost": 0, "gold_spent": 0, "rerolls": 0, "xp_bought": 0},
		"meta": {},  # libre pour le stratège (AC-D) : sauvegardé avec la partie
	}


# --- Lecture ------------------------------------------------------------------------------------------------------
func round_key() -> String:
	return "%d-%d" % [stage, round_i]


func round_kind() -> String:
	return AutochessData.round_kind(stage, round_i, rules)


func prep_time() -> float:
	return AutochessData.prep_time(stage, round_i, rules)


func is_over() -> bool:
	return phase == "over"


func alive_ids() -> Array:
	var out: Array = []
	for p in players:
		if p.alive:
			out.append(int(p.id))
	return out


func player(pi: int) -> Dictionary:
	return players[pi] if pi >= 0 and pi < players.size() else {}


## Places plateau du stratège : niveau + Couronnes.
func board_cap(pi: int) -> int:
	var p: Dictionary = players[pi]
	return int(p.level) + int(p.crowns)


func bench_units(pi: int) -> Array:
	return (players[pi].bench as Array).filter(func(u): return u != null)


## Toutes les unités possédées (plateau puis banc).
func units_of(pi: int) -> Array:
	return (players[pi].board as Array) + bench_units(pi)


func find_unit(pi: int, uid: int) -> Dictionary:
	for u in units_of(pi):
		if int(u.uid) == uid:
			return u
	return {}


func unit_at(pi: int, cell: Vector2i) -> Dictionary:
	for u in players[pi].board:
		if int(u.cell[0]) == cell.x and int(u.cell[1]) == cell.y:
			return u
	return {}


## Valeur d'équipe (somme des coûts × étoiles du plateau) : départage des éliminés.
func team_value(pi: int) -> int:
	var v := 0
	for u in players[pi].board:
		v += AutochessPool.cost_of(String(u.id)) * int(u.stars)
	return v


## Traits d'une unité : ses 2 traits + ceux de ses emblèmes.
static func unit_traits(u: Dictionary) -> Array:
	var out: Array = (AutochessData.unit(String(u.id)).get("traits", []) as Array).duplicate()
	for it in u.get("items", []):
		var t := String(parse_item(String(it))["trait"])
		if t != "" and not t in out:
			out.append(t)
	return out


## Compte de chaque trait sur le plateau (une unité compte une fois par trait ; + Cœur de famille, + Double trait).
func trait_counts(pi: int) -> Dictionary:
	var p: Dictionary = players[pi]
	var sets := {}
	for u in p.board:
		for t in unit_traits(u):
			if not sets.has(t):
				sets[t] = {}
			sets[t][String(u.id)] = true
	var out := {}
	for t in sets:
		out[t] = (sets[t] as Dictionary).size()
	for t in p.trait_bonus:
		out[t] = int(out.get(t, 0)) + int(p.trait_bonus[t])
	for aid in p.augments:
		var a := AutochessData.augment(String(aid))
		if String(a.get("effect", "")) == "trait_compte" and String(a.params.get("kind", "")) in ["arme", "tous"]:
			var need := int(AutochessData.WEAPON_THRESHOLDS[0]) if int(a.params.get("active_only", 1)) == 1 else 1
			var every := String(a.params.get("kind", "")) == "tous"  # Double trait (lot ACX-3) : familles comprises
			for t in out.keys():
				var active := int(out[t]) >= need
				if (every or String(AutochessData.TRAITS.get(t, {}).get("kind", "")) == "arme") and active:
					out[t] = int(out[t]) + int(a.params.get("count", 1))
	return out


## Traits actifs : trait -> palier (1 à 3).
func active_traits(pi: int) -> Dictionary:
	var out := {}
	var counts := trait_counts(pi)
	for t in counts:
		var tier := AutochessData.trait_tier(t, int(counts[t]))
		if tier > 0:
			out[t] = tier
	return out


## Choix en attente du stratège ({} si aucun) : {kind, options, …}. Kinds : ouverture (ids de coût 1), atout (ids d'atout,
## rerolls), choix_partage ({id, component}), objet (objets complets), composant, famille (traits de famille), heros (ids,
## stars), embleme (traits, uid).
func pending(pi: int) -> Dictionary:
	var q: Array = players[pi].pending
	return q[0] if not q.is_empty() else {}


## Décompose un objet : {id (« embleme » pour un emblème), component, trait}.
static func parse_item(s: String) -> Dictionary:
	if s.begins_with("embleme:"):
		var parts := s.split(":")
		return {"id": "embleme", "component": parts[1] if parts.size() > 1 else "",
			"trait": parts[2] if parts.size() > 2 else ""}
	return {"id": s, "component": "", "trait": ""}


# --- Revenu et expérience ------------------------------------------------------------------------------------------
## Revenu du stratège au début de la manche [param st]-[param rd] (détail : base, interest, streak, bonus, total, xp).
## Les intérêts se comptent sur l'or actuel, avant le revenu. Aucun revenu de base au choix partagé (SPEC §5.1).
func income_for(pi: int, st := -1, rd := -1) -> Dictionary:
	if st < 0:
		st = stage
		rd = round_i
	var p: Dictionary = players[pi]
	var out := {"base": 0, "interest": 0, "streak": 0, "bonus": 0, "total": 0, "xp": 0}
	if st == 1 and rd == 1:
		return out
	var kind := AutochessData.round_kind(st, rd, rules)
	var base := 0
	if st == 1:
		base = int(rule("start_gold", AutochessData.START_GOLD)) + int(rule("start_gold_bonus", 0)) if rd == 2 \
			else AutochessData.base_income(st, rd, rules)
	elif kind != "choix":
		base = AutochessData.base_income(st, rd, rules)
	if base > 0:
		out.base = base
		if not _has_effect(p, "or_sans_interets") and bool(rule("interest", true)):
			out.interest = AutochessData.interest(int(p.gold), _interest_cap(p))
		if bool(rule("streak", true)):
			out.streak = AutochessData.streak_gold(int(p.streak))
	for aid in p.augments:
		var a := AutochessData.augment(String(aid))
		if String(a.effect) == "or" and String(a.trigger) == "debut_manche":
			out.bonus += int(a.params.get("gold", 0))
	out.total = int(out.base) + int(out.interest) + int(out.streak) + int(out.bonus)
	# niveau 2 donné à 1-2 (sans XP cette manche-là), puis +2 XP par manche
	if not (st == 1 and rd <= 2):
		out.xp = int(rule("xp_per_round", AutochessData.XP_PER_ROUND)) + int(_effect_param(p, "xp", "xp_round", 0))
	return out


func _round_income(p: Dictionary) -> void:
	var inc := income_for(int(p.id))
	p.gold = int(p.gold) + int(inc.total)
	if stage == 1 and round_i == 2:
		p.level = maxi(int(p.level), int(rule("level_at_first", AutochessData.LEVEL_AT_FIRST_ROUND)))
	_add_xp(p, int(inc.xp))
	p.free_rerolls = int(_effect_param(p, "relance_gratuite", "rerolls", 0))
	p.income = inc


func _add_xp(p: Dictionary, n: int) -> void:
	if int(p.level) >= int(p.max_level):
		p.xp = 0
		return
	p.xp = int(p.xp) + n
	while int(p.level) < int(p.max_level):
		var need := AutochessData.xp_to_next(int(p.level))
		if need <= 0 or int(p.xp) < need:
			break
		p.xp = int(p.xp) - need
		p.level = int(p.level) + 1
	if int(p.level) >= int(p.max_level):
		p.xp = 0


func _interest_cap(p: Dictionary) -> int:
	var base := int(rule("interest_cap", AutochessData.INTEREST_CAP))
	return maxi(base, int(_effect_param(p, "plafond_interets", "cap", base)))


## Plafond des intérêts du stratège [param pi] (règle du jour, Intérêts composés) ; 0 sans intérêts (Éclair, Trésor).
func interest_cap(pi: int) -> int:
	var p: Dictionary = players[pi]
	if not bool(rule("interest", true)) or _has_effect(p, "or_sans_interets"):
		return 0
	return _interest_cap(p)


func _has_effect(p: Dictionary, effect: String) -> bool:
	for aid in p.augments:
		if String(AutochessData.augment(String(aid)).get("effect", "")) == effect:
			return true
	return false


func _effect_param(p: Dictionary, effect: String, key: String, default: Variant) -> Variant:
	for aid in p.augments:
		var a := AutochessData.augment(String(aid))
		if String(a.get("effect", "")) == effect:
			return a.params.get(key, default)
	return default


# --- Déroulé ------------------------------------------------------------------------------------------------------
func _begin_prep() -> void:
	phase = "prep"
	_undo.clear()
	fights.clear()
	results.clear()
	var kind := round_kind()
	for p in players:
		if not p.alive:
			continue
		p.hp_before = int(p.hp)
		p.ready = strategists[int(p.id)] != null
		p.income = {}
		_round_income(p)
		if not p.locked:
			_refresh_shop(p)
	if kind == "ouverture":
		for pi in alive_ids():
			_offer(pi, {"kind": "ouverture", "options": _opening_options()})
	if is_augment_round():
		_roll_augment_rarity()
		for pi in alive_ids():
			_offer(pi, {"kind": "atout", "rarity": augment_rarity, "rerolls": int(rule("augment_rerolls", AutochessData.AUGMENT_REROLLS)),
				"options": _augment_options(players[pi])})
	if kind == "choix":
		_start_carousel()
	for pi in alive_ids():
		var s: Variant = strategists[pi]
		if s != null and s.has_method("decide"):
			s.decide(self, pi)
	save()
	phase_changed.emit(phase)


## Fin de la préparation : choix restants faits d'office (1re option), plateau complété depuis le banc (ou vidé au-delà
## des places), puis combats de la manche (ou bilan direct pour l'ouverture et le choix partagé).
func end_prep() -> bool:
	if phase != "prep":
		return false
	_undo.clear()
	_auto_resolve_all()
	_finish_carousel()
	for pi in alive_ids():
		_fit_board(pi)
	if round_kind() in FIGHT_KINDS:
		_prepare_fights()
		phase = "combat"
	else:
		phase = "recap"
	phase_changed.emit(phase)
	return true


## Joue les combats de la manche avec le combat injecté (ou power_fight).
func run_fights() -> bool:
	if phase != "combat":
		return false
	var res: Array = []
	for f in fights:
		var r: Variant = fight.call(f.board_a, f.board_b, f.ctx) if fight.is_valid() \
			else power_fight(f.board_a, f.board_b, f.ctx)
		res.append(r)
	return finish_combat(res)


## Résultats des combats (même ordre que `fights`) : dégâts, or, séries, butin, éliminations.
func finish_combat(res: Array) -> bool:
	if phase != "combat" or res.size() != fights.size():
		return false
	results.clear()
	for r in res:
		results.append(_norm_result(r))
	_apply_results()
	phase = "over" if _check_over() else "recap"
	if phase == "over":
		clear_save(save_path)
	phase_changed.emit(phase)
	return true


func next_round() -> bool:
	if phase != "recap":
		return false
	rounds_played += 1
	round_i += 1
	if round_i > rounds_in(stage):
		stage += 1
		round_i = 1
	_begin_prep()
	return true


## Avance d'une phase ; renvoie la phase atteinte.
func step() -> String:
	match phase:
		"prep":
			end_prep()
		"combat":
			run_fights()
		"recap":
			next_round()
	return phase


func play_to_end(max_rounds := MAX_ROUNDS) -> void:
	while phase != "over" and rounds_played < max_rounds:
		step()


## Le joueur humain est prêt (le directeur lance le combat quand all_ready()).
func set_ready(pi: int, on := true) -> void:
	if pi >= 0 and pi < players.size():
		players[pi].ready = on


func all_ready() -> bool:
	for p in players:
		if p.alive and not p.ready:
			return false
	return true


## Abandon du stratège [param pi] (le joueur) : place = son rang parmi les vivants (PV, puis valeur d'équipe) ; la partie
## s'arrête pour lui (phase « over », sauvegarde effacée). Récompenses : à décider par AC-I (top 4 seulement).
func abandon(pi: int) -> int:
	var p: Dictionary = players[pi]
	if not p.alive:
		return int(p.place)
	var alive := alive_ids()
	alive.sort_custom(func(a, b):
		if int(players[a].hp) != int(players[b].hp):
			return int(players[a].hp) > int(players[b].hp)
		if team_value(a) != team_value(b):
			return team_value(a) > team_value(b)
		return a == pi)
	var place := alive.find(pi) + 1
	_release(p)
	p.alive = false
	p.abandoned = true
	p.place = place
	phase = "over"
	clear_save(save_path)
	phase_changed.emit(phase)
	return place


# --- Actions de préparation ---------------------------------------------------------------------------------------
func _can_act(pi: int) -> bool:
	return phase == "prep" and pi >= 0 and pi < players.size() and players[pi].alive


## Peut recevoir une unité ★1 [param id] : case de banc libre, ou la fusion l'absorbe (même banc plein).
func can_receive(pi: int, id: String) -> bool:
	var p: Dictionary = players[pi]
	return _free_bench(p) >= 0 or _count_star(p, id, 1) + 1 >= _need(p, id, 1)


func buy(pi: int, slot: int) -> bool:
	if not _can_act(pi) or slot < 0 or slot >= AutochessData.SHOP_SIZE:
		return false
	var p: Dictionary = players[pi]
	var id := String(p.shop[slot])
	if id == "":
		return false
	var cost := AutochessPool.cost_of(id)
	if int(p.gold) < cost or not can_receive(pi, id):
		return false
	var snap := _snapshot(pi)
	p.shop[slot] = ""
	if not _add_unit(pi, _make_unit(id, 1, 1)):
		p.shop[slot] = id
		return false
	p.gold = int(p.gold) - cost
	p.stats.gold_spent = int(p.stats.gold_spent) + cost
	p.buys = int(p.buys) + 1
	var every := int(_effect_param(p, "achat_double", "every", 0))
	if every > 0 and int(p.buys) % every == 0 and pool.take(id) == 1:
		if not _add_unit(pi, _make_unit(id, 1, 1)):
			pool.give(id)
	_push_undo(pi, "buy", snap)
	changed.emit(pi)
	return true


func sell(pi: int, uid: int) -> bool:
	if not _can_act(pi):
		return false
	var u := find_unit(pi, uid)
	if u.is_empty():
		return false
	var snap := _snapshot(pi)
	_sell_unit(players[pi], u)
	_push_undo(pi, "sell", snap)
	changed.emit(pi)
	return true


func reroll(pi: int) -> bool:
	if not _can_act(pi):
		return false
	var p: Dictionary = players[pi]
	if int(p.free_rerolls) > 0:
		p.free_rerolls = int(p.free_rerolls) - 1
	elif int(p.gold) >= reroll_cost():
		p.gold = int(p.gold) - reroll_cost()
		p.stats.gold_spent = int(p.stats.gold_spent) + reroll_cost()
	else:
		return false
	_undo.erase(pi)  # jamais d'annulation au-delà d'une actualisation (la boutique ne se repêche pas)
	p.stats.rerolls = int(p.stats.rerolls) + 1
	_refresh_shop(p)
	changed.emit(pi)
	return true


func buy_xp(pi: int) -> bool:
	if not _can_act(pi):
		return false
	var p: Dictionary = players[pi]
	if int(p.level) >= int(p.max_level) or int(p.gold) < xp_cost():
		return false
	_undo.erase(pi)
	p.gold = int(p.gold) - xp_cost()
	p.stats.gold_spent = int(p.stats.gold_spent) + xp_cost()
	p.stats.xp_bought = int(p.stats.xp_bought) + 1
	_add_xp(p, AutochessData.XP_BUY_AMOUNT)
	changed.emit(pi)
	return true


## Verrou de la boutique (gratuit) : elle reste à la manche suivante tant qu'il est mis. Renvoie l'état.
func toggle_lock(pi: int) -> bool:
	if _can_act(pi):
		players[pi].locked = not players[pi].locked
		changed.emit(pi)
	return bool(players[pi].locked)


## Pose l'unité [param uid] sur la case [param cell] ; case prise : échange (l'autre va à la place de celle-ci).
func place(pi: int, uid: int, cell: Vector2i) -> bool:
	if not _can_act(pi) or not cell_ok(cell):
		return false
	var p: Dictionary = players[pi]
	var u := find_unit(pi, uid)
	if u.is_empty():
		return false
	var snap := _snapshot(pi)
	var other := unit_at(pi, cell)
	if _board_index(p, uid) >= 0:  # déjà sur le plateau
		if not other.is_empty():
			other["cell"] = (u.cell as Array).duplicate()
		u["cell"] = [cell.x, cell.y]
	else:
		var slot := _bench_index(p, uid)
		if other.is_empty():
			if (p.board as Array).size() >= board_cap(pi):
				return false
			p.bench[slot] = null
		else:
			_board_remove(p, int(other.uid))
			other.erase("cell")
			p.bench[slot] = other
		u["cell"] = [cell.x, cell.y]
		(p.board as Array).append(u)
	_push_undo(pi, "move", snap)
	changed.emit(pi)
	return true


## Range l'unité [param uid] au banc (case [param slot], -1 : la première libre) ; case prise : échange.
func to_bench(pi: int, uid: int, slot := -1) -> bool:
	if not _can_act(pi):
		return false
	var p: Dictionary = players[pi]
	var u := find_unit(pi, uid)
	if u.is_empty():
		return false
	if slot < 0:
		slot = _free_bench(p)
	if slot < 0 or slot >= AutochessData.BENCH_SIZE:
		return false
	var snap := _snapshot(pi)
	var other: Variant = p.bench[slot]
	var k := _board_index(p, uid)
	if k >= 0:
		var cell: Array = u.cell
		if other == null:
			(p.board as Array).remove_at(k)
		else:
			other["cell"] = cell.duplicate()
			p.board[k] = other
		u.erase("cell")
		p.bench[slot] = u
	else:
		var from := _bench_index(p, uid)
		p.bench[from] = other
		p.bench[slot] = u
	_push_undo(pi, "move", snap)
	changed.emit(pi)
	return true


## Pose l'objet [param item_idx] du banc d'objets sur l'unité [param uid] (deux composants se combinent tout de suite ;
## Marteau de réforge : rend au banc les composants de l'unité).
func equip(pi: int, item_idx: int, uid: int) -> bool:
	if not _can_act(pi):
		return false
	var p: Dictionary = players[pi]
	if item_idx < 0 or item_idx >= (p.items as Array).size():
		return false
	var u := find_unit(pi, uid)
	if u.is_empty():
		return false
	var snap := _snapshot(pi)
	var it := String(p.items[item_idx])
	(p.items as Array).remove_at(item_idx)
	if it in AutochessData.UTILITY_ITEMS:
		if not _use_utility(pi, u, it):
			(p.items as Array).insert(item_idx, it)
			return false
	elif not _equip_raw(pi, u, it):
		(p.items as Array).insert(item_idx, it)
		return false
	_push_undo(pi, "item", snap)
	changed.emit(pi)
	return true


## Fait le choix en attente du stratège (indice dans options).
func choose(pi: int, idx: int) -> bool:
	if phase == "over" or phase == "combat" or pi < 0 or pi >= players.size():
		return false
	var c := pending(pi)
	if c.is_empty() or idx < 0 or idx >= (c.options as Array).size():
		return false
	_undo.erase(pi)  # un choix est définitif (et le choix partagé fait jouer les autres)
	_resolve(pi, idx)
	_carousel_continue()
	changed.emit(pi)
	return true


## Relance les 3 cartes du choix d'atout en attente (une fois par choix).
func reroll_choice(pi: int) -> bool:
	var c := pending(pi)
	if c.is_empty() or String(c.kind) != "atout" or int(c.rerolls) <= 0:
		return false
	_undo.erase(pi)
	c.options = _augment_options(players[pi], c.options)
	c.rerolls = int(c.rerolls) - 1
	changed.emit(pi)
	return true


# --- Annuler (lot ACX-2) ------------------------------------------------------------------------------------------
## Le jeu est solo : la dernière action de préparation d'un stratège humain s'annule (achat, vente, déplacement, objet
## donné), jusqu'à UNDO_MAX fois. Jamais une actualisation, un achat d'XP ni un choix (la pile est vidée), ni d'une
## préparation à l'autre. L'état revient exactement (or, boutique, banc, plateau, objets, réserve partagée, hasard de la
## partie : un Emblème refait propose les mêmes traits) ; le verrou de la boutique et la meta du stratège restent.
const UNDO_MAX := 12


## Actions annulables du stratège [param pi], la dernière en tête : « buy », « sell », « move », « item ».
func undo_list(pi: int) -> Array:
	var out: Array = []
	for e in _undo.get(pi, []):
		out.push_front(String(e.label))
	return out


func can_undo(pi: int) -> bool:
	return phase == "prep" and not (_undo.get(pi, []) as Array).is_empty()


## Annule la dernière action de [param pi] ; renvoie son genre (« buy »…), "" s'il n'y a rien à annuler.
func undo(pi: int) -> String:
	if not can_undo(pi):
		return ""
	var e: Dictionary = (_undo[pi] as Array).pop_back()
	var p: Dictionary = players[pi]
	var keep := {"locked": p.locked, "meta": p.meta, "human": p.human}
	p.clear()
	p.merge((e.player as Dictionary).duplicate(true))
	for k in keep:
		p[k] = keep[k]
	pool.from_dict(e.pool)
	rng.state = int(e.rng)
	changed.emit(pi)
	return String(e.label)


func _snapshot(pi: int) -> Dictionary:
	if not bool(players[pi].get("human", false)):
		return {}
	return {"player": (players[pi] as Dictionary).duplicate(true), "pool": pool.to_dict(), "rng": rng.state}


func _push_undo(pi: int, label: String, snap: Dictionary) -> void:
	if snap.is_empty() or phase != "prep":
		return
	snap["label"] = label
	var st: Array = _undo.get(pi, [])
	st.append(snap)
	while st.size() > UNDO_MAX:
		st.pop_front()
	_undo[pi] = st


# --- Unités, fusion, objets ---------------------------------------------------------------------------------------
static func cell_ok(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < AutochessData.COLS and cell.y >= 0 and cell.y < AutochessData.ROWS


func _make_unit(id: String, stars: int, copies: int, items: Array = []) -> Dictionary:
	next_uid += 1
	return {"uid": next_uid - 1, "id": id, "stars": stars, "copies": copies, "items": items.duplicate()}


func _free_bench(p: Dictionary) -> int:
	return (p.bench as Array).find(null)


func _bench_index(p: Dictionary, uid: int) -> int:
	for k in (p.bench as Array).size():
		if p.bench[k] != null and int(p.bench[k].uid) == uid:
			return k
	return -1


func _board_index(p: Dictionary, uid: int) -> int:
	for k in (p.board as Array).size():
		if int(p.board[k].uid) == uid:
			return k
	return -1


func _board_remove(p: Dictionary, uid: int) -> void:
	var k := _board_index(p, uid)
	if k >= 0:
		(p.board as Array).remove_at(k)


func _remove_unit(p: Dictionary, uid: int) -> void:
	if not _limbo.is_empty() and int(_limbo.uid) == uid:
		_limbo = {}
		return
	var k := _bench_index(p, uid)
	if k >= 0:
		p.bench[k] = null
	else:
		_board_remove(p, uid)


func _count_star(p: Dictionary, id: String, stars: int) -> int:
	var n := 0
	for u in (p.board as Array) + (p.bench as Array):
		if u != null and String(u.id) == id and int(u.stars) == stars:
			n += 1
	return n


## Copies à réunir pour passer de [param stars] à l'étoile suivante (Étoile filante : 2 pour les ★1 bon marché).
func _need(p: Dictionary, id: String, stars: int) -> int:
	if stars == 1 and _has_effect(p, "fusion_rapide") \
			and AutochessPool.cost_of(id) <= int(_effect_param(p, "fusion_rapide", "max_cost", 0)):
		return int(_effect_param(p, "fusion_rapide", "copies", AutochessData.COPIES_PER_STAR))
	return AutochessData.COPIES_PER_STAR


## Ajoute une unité (copies déjà retirées de la réserve) : banc, sinon fusion qui l'absorbe, sinon plateau s'il reste une
## place. Faux si elle n'a pas de place (l'appelant rend ses copies).
func _add_unit(pi: int, u: Dictionary) -> bool:
	var p: Dictionary = players[pi]
	var slot := _free_bench(p)
	if slot >= 0:
		p.bench[slot] = u
		_merge(pi, String(u.id))
		return true
	if int(u.stars) < AutochessData.MAX_STARS and _count_star(p, String(u.id), int(u.stars)) + 1 >= _need(p, String(u.id), int(u.stars)):
		_limbo = u
		_merge(pi, String(u.id))
		var left := _limbo
		_limbo = {}
		if left.is_empty():
			return true
		slot = _free_bench(p)  # la fusion a libéré une case sans absorber la nouvelle (Étoile filante prise après coup)
		if slot >= 0:
			p.bench[slot] = left
			_merge(pi, String(u.id))
			return true
	if (p.board as Array).size() < board_cap(pi):
		var cell := free_cell(pi, String(AutochessData.unit(String(u.id)).get("place", "milieu")))
		if cell.x >= 0:
			u["cell"] = [cell.x, cell.y]
			(p.board as Array).append(u)
			_merge(pi, String(u.id))
			return true
	return false


## Fusion automatique : 3 copies (★1 -> ★2, puis ★2 -> ★3) ; la nouvelle unité prend la place de l'exemplaire du plateau
## (sinon du banc) et garde les objets (3 au plus, le reste au banc d'objets).
func _merge(pi: int, id: String) -> void:
	var p: Dictionary = players[pi]
	for s in range(1, AutochessData.MAX_STARS):
		while true:
			var need := _need(p, id, s)
			var group: Array = []
			for u in p.board:
				if String(u.id) == id and int(u.stars) == s:
					group.append(u)
			for u in p.bench:
				if u != null and String(u.id) == id and int(u.stars) == s:
					group.append(u)
			if not _limbo.is_empty() and String(_limbo.id) == id and int(_limbo.stars) == s:
				group.append(_limbo)
			if group.size() < need:
				break
			var target: Dictionary = group[0]
			var items: Array = []
			var copies := 0
			for k in need:
				var u: Dictionary = group[k]
				copies += int(u.copies)
				items.append_array(u.items)
				if k > 0:
					_remove_unit(p, int(u.uid))
			target.stars = s + 1
			target.copies = copies
			target.items = []
			_reequip(pi, target, items)


func _reequip(pi: int, u: Dictionary, items: Array) -> void:
	var p: Dictionary = players[pi]
	var full := items.filter(func(it): return not AutochessData.COMPONENTS.has(String(it)))
	var comps := items.filter(func(it): return AutochessData.COMPONENTS.has(String(it)))
	for it in full + comps:
		if not _equip_raw(pi, u, String(it)):
			_item_bench_add(p, String(it))


## Pose un objet sans le prendre au banc. Composant sur un composant seul : objet complet (Insigne : Emblème ou Couronne).
func _equip_raw(pi: int, u: Dictionary, it: String) -> bool:
	var p: Dictionary = players[pi]
	var items: Array = u.items
	if it in AutochessData.UTILITY_ITEMS or it == "couronne" or it == "":
		return false
	if AutochessData.COMPONENTS.has(it):
		var k := -1
		for j in items.size():
			if AutochessData.COMPONENTS.has(String(items[j])):
				k = j
		if k >= 0:
			var other := String(items[k])
			var made := AutochessData.combine(other, it)
			if made == "couronne":
				items.remove_at(k)
				p.crowns = int(p.crowns) + int(AutochessData.SPECIAL_ITEMS.couronne.params.slots)
				return true
			if made == "embleme":
				items[k] = "embleme:%s:" % (other if other != "insigne" else it)
				_offer_emblem(pi, u)
				return true
			if made == "":
				return false
			items[k] = made
			return true
	if items.size() >= AutochessData.MAX_ITEMS_PER_UNIT:
		return false
	items.append(it)
	return true


func _offer_emblem(pi: int, u: Dictionary) -> void:
	var have := unit_traits(u)
	var opts: Array = AutochessData.TRAITS.keys().filter(func(t): return not t in have)
	_offer(pi, {"kind": "embleme", "uid": int(u.uid), "options": _pick(opts, int(AutochessData.SPECIAL_ITEMS.embleme.params.choices))})


func _item_bench_add(p: Dictionary, it: String) -> bool:
	if it == "" or (p.items as Array).size() >= AutochessData.ITEM_BENCH_SIZE:
		return false
	(p.items as Array).append(it)
	return true


## Peut-on poser l'objet utilitaire [param it] sur l'unité [param u] du stratège [param pi] (sans rien changer) ?
## [param in_bench] : l'objet est encore au banc d'objets (sa case se libérera).
func utility_ok(pi: int, u: Dictionary, it: String, in_bench := true) -> bool:
	var p: Dictionary = players[pi]
	var items: Array = u.get("items", [])
	var free := AutochessData.ITEM_BENCH_SIZE - (p.items as Array).size() + (1 if in_bench else 0)
	match it:
		"marteau_reforge":
			return not items.is_empty()
		"pince":
			return not items.is_empty() and free >= items.size()
		"creuset":
			return items.any(func(x): return AutochessData.ITEMS.has(String(x)))
		"miroir":
			var id := String(u.get("id", ""))
			return id != "" and AutochessPool.cost_of(id) <= int(AutochessData.SPECIAL_ITEMS.miroir.params.max_cost) \
				and pool.remaining(id) > 0 and can_receive(pi, id)
	return false


## Objet utilitaire (lot ACX-3) posé sur une unité : Marteau (composants au banc), Pince (objets intacts au banc), Creuset
## (objets complets changés au hasard de la partie), Miroir (copie ★1 prise à la réserve). Faux si sans effet.
func _use_utility(pi: int, u: Dictionary, it: String) -> bool:
	var p: Dictionary = players[pi]
	if not utility_ok(pi, u, it, false):
		return false
	match it:
		"marteau_reforge":
			_reforge(p, u)
		"pince":
			for x in u.items:
				_item_bench_add(p, String(x))
			u.items = []
		"creuset":
			for k in (u.items as Array).size():
				var cur := String(u.items[k])
				if AutochessData.ITEMS.has(cur):
					u.items[k] = String(_pick(AutochessData.ITEMS.keys().filter(func(x): return x != cur), 1)[0])
		"miroir":
			var id := String(u.id)
			if pool.take(id) != 1:
				return false
			if not _add_unit(pi, _make_unit(id, 1, 1)):
				pool.give(id)
				return false
	return true


## Marteau de réforge : les objets de l'unité redeviennent des composants, au banc d'objets.
func _reforge(p: Dictionary, u: Dictionary) -> void:
	for it in u.items:
		var info := parse_item(String(it))
		if String(info.id) == "embleme":
			_item_bench_add(p, "insigne")
			_item_bench_add(p, String(info.component))
		elif AutochessData.ITEMS.has(String(it)):
			for part in AutochessData.ITEMS[String(it)].parts:
				_item_bench_add(p, String(part))
		else:
			_item_bench_add(p, String(it))
	u.items = []


func _sell_unit(p: Dictionary, u: Dictionary) -> void:
	var id := String(u.id)
	p.gold = int(p.gold) + AutochessData.sell_value(AutochessPool.cost_of(id), int(u.stars))
	pool.give(id, int(u.copies))
	for it in u.items:
		_item_bench_add(p, String(it))
	_remove_unit(p, int(u.uid))


## Case libre du plateau pour une unité de place « avant » / « milieu » / « arriere » (Vector2i(-1, -1) si aucune).
func free_cell(pi: int, place_kind := "milieu") -> Vector2i:
	var cols: Array = []
	var mid := AutochessData.COLS / 2
	for d in AutochessData.COLS:
		var c: int = mid + (d + 1) / 2 * (1 if d % 2 == 1 else -1)
		if c >= 0 and c < AutochessData.COLS:
			cols.append(c)
	for r in ROW_ORDER.get(place_kind, ROW_ORDER.milieu):
		for c in cols:
			if unit_at(pi, Vector2i(c, r)).is_empty():
				return Vector2i(c, r)
	return Vector2i(-1, -1)


## Plateau ajusté avant le combat : au-delà des places, les dernières posées vont au banc (vendues s'il est plein) ; places
## libres complétées depuis le banc.
func _fit_board(pi: int) -> void:
	var p: Dictionary = players[pi]
	var cap := board_cap(pi)
	while (p.board as Array).size() > cap:
		var u: Dictionary = (p.board as Array).pop_back()
		u.erase("cell")
		var slot := _free_bench(p)
		if slot >= 0:
			p.bench[slot] = u
		else:
			_limbo = u
			_sell_unit(p, u)
			_limbo = {}
	for k in AutochessData.BENCH_SIZE:
		if (p.board as Array).size() >= cap:
			break
		var u: Variant = p.bench[k]
		if u == null:
			continue
		var cell := free_cell(pi, String(AutochessData.unit(String(u.id)).get("place", "milieu")))
		if cell.x < 0:
			break
		p.bench[k] = null
		u["cell"] = [cell.x, cell.y]
		(p.board as Array).append(u)


func _refresh_shop(p: Dictionary) -> void:
	for id in p.shop:
		pool.give(String(id))
	p.shop = pool.roll_shop(int(p.level), rng)


# --- Choix (ouverture, atouts, choix partagé, objets) -------------------------------------------------------------
## [param n] éléments distincts de [param list] tirés au hasard de la partie.
func _pick(list: Array, n: int) -> Array:
	var a := list.duplicate()
	_shuffle(a)
	return a.slice(0, mini(n, a.size()))


func _shuffle(a: Array) -> void:
	for i in range(a.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t: Variant = a[i]
		a[i] = a[j]
		a[j] = t


func _offer(pi: int, c: Dictionary) -> void:
	if (c.get("options", []) as Array).is_empty():
		return
	(players[pi].pending as Array).append(c)
	_drain_ai(pi)


## Un stratège IA répond tout de suite à ses choix (le joueur humain les garde jusqu'à choose() ou end_prep()).
func _drain_ai(pi: int) -> void:
	var s: Variant = strategists[pi] if pi < strategists.size() else null
	if s == null:
		return
	var q: Array = players[pi].pending
	var guard := 0
	while not q.is_empty() and guard < 64:
		guard += 1
		var c: Dictionary = q[0]
		var idx := int(s.choose(self, pi, c)) if s.has_method("choose") else 0
		if idx < 0 and String(c.kind) == "atout" and int(c.rerolls) > 0:
			c.options = _augment_options(players[pi], c.options)
			c.rerolls = int(c.rerolls) - 1
			continue
		_resolve(pi, clampi(idx, 0, (c.options as Array).size() - 1))


func _auto_resolve_all() -> void:
	var guard := 0
	var again := true
	while again and guard < 256:
		again = false
		guard += 1
		for pi in players.size():
			while not (players[pi].pending as Array).is_empty():
				_resolve(pi, 0)
				again = true
			_carousel_continue()


func _resolve(pi: int, idx: int) -> void:
	var p: Dictionary = players[pi]
	var c: Dictionary = (p.pending as Array).pop_front()
	var opt: Variant = c.options[idx]
	match String(c.kind):
		"ouverture":
			if pool.take(String(opt)) == 1 and not _add_unit(pi, _make_unit(String(opt), 1, 1)):
				pool.give(String(opt))
		"atout":
			_take_augment(pi, String(opt))
		"choix_partage":
			_carousel_take(pi, int(c.slots[idx]))
		"objet", "composant":
			_item_bench_add(p, String(opt))
		"famille":
			p.trait_bonus[String(opt)] = int(p.trait_bonus.get(String(opt), 0)) + int(c.get("count", 1))
		"heros":
			var stars := int(c.get("stars", 1))
			var got := pool.take(String(opt), int(pow(AutochessData.COPIES_PER_STAR, stars - 1)))
			if got > 0 and not _add_unit(pi, _make_unit(String(opt), stars, got)):
				pool.give(String(opt), got)
		"embleme":
			var u := find_unit(pi, int(c.uid))
			for k in (u.get("items", []) as Array).size():
				var info := parse_item(String(u.items[k]))
				if String(info.id) == "embleme" and String(info["trait"]) == "":
					u.items[k] = "embleme:%s:%s" % [info.component, opt]
					break


func _opening_options() -> Array:
	var ids := pool.ids_of_cost(1).filter(func(id): return pool.remaining(id) > 0)
	return _pick(ids, AutochessData.OPENING_CHOICES)


func _roll_augment_rarity() -> void:
	if String(rule("first_rarity", "")) != "" and last_rarity == "":  # règle du jour « Pluie d'éclats »
		augment_rarity = String(rule("first_rarity", ""))
		last_rarity = augment_rarity
		return
	var w: Dictionary = AutochessData.AUGMENT_RARITY_WEIGHTS.duplicate()
	if last_rarity == "eclat":
		w.eclat = 0
	var sum := 0
	for k in w:
		sum += int(w[k])
	var r := rng.randi_range(1, maxi(sum, 1))
	for k in w:
		r -= int(w[k])
		if r <= 0:
			augment_rarity = String(k)
			break
	last_rarity = augment_rarity


## 3 atouts de la rareté de la manche que le stratège n'a pas (autres que [param avoid] s'il en reste assez).
func _augment_options(p: Dictionary, avoid: Array = []) -> Array:
	var ids := AutochessData.augments_of(augment_rarity).filter(func(a): return not a in p.augments)
	var fresh := ids.filter(func(a): return not a in avoid)
	var n := AutochessData.AUGMENT_CHOICES
	if fresh.size() >= n:
		return _pick(fresh, n)
	var out := _pick(fresh, n)
	for a in _pick(ids.filter(func(x): return not x in out), n - out.size()):
		out.append(a)
	return out


## Effets d'atout qui touchent la partie (or, XP, unités, objets, places, choix) ; les effets de combat sont lus par AC-H
## dans ctx.augments.
func _take_augment(pi: int, id: String) -> void:
	var p: Dictionary = players[pi]
	var a := AutochessData.augment(id)
	if a.is_empty() or id in p.augments:
		return
	(p.augments as Array).append(id)
	var prm: Dictionary = a.params
	match String(a.effect):
		"fusion_rapide":  # les copies déjà réunies fusionnent tout de suite
			var ids := {}
			for u in units_of(pi):
				ids[String(u.id)] = true
			for uid in ids:
				_merge(pi, uid)
		"xp":
			_add_xp(p, int(prm.get("xp_now", 0)))
		"composant_au_choix":
			_offer(pi, {"kind": "composant", "options": _pick(AutochessData.BASE_COMPONENTS, int(prm.choices))})
		"unites_famille":
			_give_family_units(pi, int(prm.count), int(prm.cost))
		"pv_contre_or":
			p.hp = maxi(1, int(p.hp) + int(prm.player_hp))
			p.gold = int(p.gold) + int(prm.gold)
		"objet":
			if prm.has("items"):
				for it in prm.items:
					_item_bench_add(p, String(it))
			else:
				for _k in int(prm.get("count", 1)):
					_item_bench_add(p, String(prm.item))
		"trait_plus":  # lot ACX-3 : un trait précis compte une unité de plus (le bonus de combat est dans AutochessAugments)
			var t := String(prm.trait)
			p.trait_bonus[t] = int(p.trait_bonus.get(t, 0)) + int(prm.get("count", 1))
		"trait_au_choix":  # Maître d'armes : un trait d'arme au choix
			var ts: Array = AutochessData.weapon_traits() if String(prm.get("kind", "arme")) == "arme" else AutochessData.family_traits()
			_offer(pi, {"kind": "famille", "count": int(prm.get("count", 1)), "options": _pick(ts, int(prm.get("choices", 3)))})
		"copie_unite":  # Jumeaux : une copie ★1 de l'unité la plus chère du plateau (coût max_cost au plus)
			var best: Dictionary = {}
			for u in p.board:
				var c := AutochessPool.cost_of(String(u.id))
				if c > int(prm.get("max_cost", 4)) or pool.remaining(String(u.id)) <= 0:
					continue
				if best.is_empty() or c > AutochessPool.cost_of(String(best.id)) \
						or (c == AutochessPool.cost_of(String(best.id)) and int(u.stars) > int(best.stars)):
					best = u
			if not best.is_empty() and can_receive(pi, String(best.id)) and pool.take(String(best.id)) == 1:
				if not _add_unit(pi, _make_unit(String(best.id), 1, 1)):
					pool.give(String(best.id))
		"place_plateau":
			p.crowns = int(p.crowns) + int(prm.slots)
		"unite_au_choix":
			var ids := pool.ids_of_cost(int(prm.cost)).filter(func(u): return pool.remaining(u) > 0)
			_offer(pi, {"kind": "heros", "stars": int(prm.stars), "options": _pick(ids, int(prm.choices))})
		"or_sans_interets":
			p.gold = int(p.gold) + int(prm.gold)
		"niveau_max":
			p.max_level = maxi(int(p.max_level), int(prm.max_level))
			_add_xp(p, int(prm.get("xp_now", 0)))
		"objets_au_choix":
			for _k in int(prm.get("count", 1)):
				_offer(pi, {"kind": "objet", "options": _pick(AutochessData.ITEMS.keys(), int(prm.choices))})
		"trait_compte":
			if String(prm.kind) == "famille":
				_offer(pi, {"kind": "famille", "count": int(prm.get("count", 1)),
					"options": _pick(AutochessData.family_traits(), int(prm.choices))})


## Renfort : unités de coût [param cost] de la famille la plus nombreuse du stratège (au hasard s'il n'a rien).
func _give_family_units(pi: int, count: int, cost: int) -> void:
	var fams := {}
	for u in units_of(pi):
		var f := String((AutochessData.unit(String(u.id)).traits as Array)[0])
		fams[f] = int(fams.get(f, 0)) + 1
	var fam := ""
	for f in AutochessData.family_traits():
		if fams.has(f) and (fam == "" or int(fams[f]) > int(fams[fam])):
			fam = f
	if fam == "":
		fam = String(_pick(AutochessData.family_traits(), 1)[0])
	var among := pool.ids_of_cost(cost).filter(func(id): return String(AutochessData.unit(id).traits[0]) == fam)
	for _k in count:
		var id := pool.draw(cost, rng, among)
		if id == "":
			break
		if not _add_unit(pi, _make_unit(id, 1, 1)):
			pool.give(id)


## Choix partagé : 9 unités (copies tenues) portant chacune un composant ; ordre : PV les plus bas d'abord.
func _start_carousel() -> void:
	var costs := AutochessData.carousel_costs(stage)
	var opts: Array = []
	for _k in AutochessData.CAROUSEL_SIZE:
		var id := ""
		var c0 := rng.randi_range(int(costs[0]), int(costs[1]))
		for dc in range(int(costs[1]) - int(costs[0]) + 1):
			var c := int(costs[0]) + (c0 - int(costs[0]) + dc) % (int(costs[1]) - int(costs[0]) + 1)
			id = pool.draw(c, rng)
			if id != "":
				break
		if id == "":
			break
		opts.append({"id": id, "component": AutochessData.BASE_COMPONENTS[rng.randi_range(0, AutochessData.BASE_COMPONENTS.size() - 1)],
			"taken_by": -1})
	var order := alive_ids()
	var tie := {}
	for pi in order:
		tie[pi] = rng.randf()
	order.sort_custom(func(a, b):
		if int(players[a].hp) != int(players[b].hp):
			return int(players[a].hp) < int(players[b].hp)
		return float(tie[a]) < float(tie[b]))
	carousel = {"options": opts, "order": order, "next": 0}
	_carousel_continue()


func _carousel_avail() -> Array:
	var out: Array = []
	for k in (carousel.options as Array).size():
		if int(carousel.options[k].taken_by) < 0:
			out.append(k)
	return out


func _carousel_continue() -> void:
	while not carousel.is_empty() and int(carousel.next) < (carousel.order as Array).size():
		var pi := int(carousel.order[int(carousel.next)])
		var avail := _carousel_avail()
		if not players[pi].alive or avail.is_empty():
			carousel.next = int(carousel.next) + 1
			continue
		for c in players[pi].pending:
			if String(c.kind) == "choix_partage":
				return  # attend le choix du joueur
		var shown: Array = avail.map(func(k): return {"id": carousel.options[k].id, "component": carousel.options[k].component})
		_offer(pi, {"kind": "choix_partage", "options": shown, "slots": avail})
		for c in players[pi].pending:
			if String(c.kind) == "choix_partage":
				return


func _carousel_take(pi: int, slot: int) -> void:
	var o: Dictionary = carousel.options[slot]
	o.taken_by = pi
	carousel.next = int(carousel.next) + 1
	var u := _make_unit(String(o.id), 1, 1, [String(o.component)])
	if not _add_unit(pi, u):  # banc plein : l'unité est vendue d'office, le composant reste
		var p: Dictionary = players[pi]
		p.gold = int(p.gold) + AutochessData.sell_value(AutochessPool.cost_of(String(o.id)), 1)
		pool.give(String(o.id))
		_item_bench_add(p, String(o.component))


func _finish_carousel() -> void:
	if carousel.is_empty():
		return
	for o in carousel.options:
		if int(o.taken_by) < 0:
			pool.give(String(o.id))
	carousel = {}


# --- Combats ------------------------------------------------------------------------------------------------------
## Plateau d'un stratège pour le combat (copie) : uid, id, stars, copies, items, cell, + cost et traits.
func board_snapshot(pi: int) -> Array:
	var out: Array = []
	for u in players[pi].board:
		var c: Dictionary = (u as Dictionary).duplicate(true)
		c["cost"] = AutochessPool.cost_of(String(u.id))
		c["traits"] = unit_traits(u)
		out.append(c)
	return out


func guardian_mult(pi: int) -> float:
	return float(_effect_param(players[pi], "gardiens_renforces", "guardian_mult", 1.0))


func _pve_board(pi: int) -> Array:
	if round_kind() == "gardien":
		return [{"guardian": true, "stage": stage, "mult": guardian_mult(pi)}]
	var wave: Dictionary = AutochessData.MONSTER_WAVES.get(round_key(), {"sbires": 2})
	var out: Array = []
	for _k in int(wave.get("elites", 0)):
		out.append({"monster": "elite"})
	for _k in int(wave.get("sbires", 0)):
		out.append({"monster": "sbire"})
	return out


func _prepare_fights() -> void:
	fights.clear()
	var kind := round_kind()
	if kind == "jcj":
		for pr in _pairings(alive_ids()):
			var src: int = pr[1] if int(pr[2]) < 0 else pr[2]
			fights.append(_fight_entry(kind, pr[0], pr[1], pr[2], board_snapshot(pr[0]), board_snapshot(src), src))
	else:
		for pi in alive_ids():
			fights.append(_fight_entry(kind, pi, -1, -1, board_snapshot(pi), _pve_board(pi), -1))


func _fight_entry(kind: String, a: int, b: int, ghost_of: int, board_a: Array, board_b: Array, src: int) -> Dictionary:
	var ctx := {
		"stage": stage, "round": round_i, "kind": kind, "seed": rng.randi(), "a": a, "b": b, "ghost_of": ghost_of,
		"augments": [(players[a].augments as Array).duplicate(), (players[src].augments as Array).duplicate() if src >= 0 else []],
		"traits": [trait_counts(a), trait_counts(src) if src >= 0 else {}],
		"guardian_mult": guardian_mult(a),
	}
	return {"kind": kind, "a": a, "b": b, "ghost_of": ghost_of, "board_a": board_a, "board_b": board_b, "ctx": ctx}


## Lot ACX-3 (n° 12) : adversaires possibles du stratège [param pi] à la prochaine manche JcJ, d'après la seule règle
## publique d'appariement (les AutochessData.avoid_recent derniers adversaires sont évités) : rien de caché n'est lu, le
## hasard de la partie n'est pas touché. {cands: [stratèges], ghost: un fantôme est possible (nombre impair de vivants)}.
func likely_opponents(pi: int) -> Dictionary:
	var alive := alive_ids()
	var out := {"cands": [], "ghost": alive.size() % 2 == 1}
	if not pi in alive or alive.size() < 2:
		return out
	var k := AutochessData.avoid_recent(alive.size())
	var others := alive.filter(func(o): return o != pi)
	var free := others.filter(func(o): return not _recent(pi, o, k) and not _recent(o, pi, k))
	out.cands = free if not free.is_empty() else others
	return out


func _recent(a: int, b: int, k: int) -> bool:
	if k <= 0:
		return false
	var r: Array = players[a].recent
	return b in r.slice(maxi(0, r.size() - k))


## Appariement JcJ : [a, b, -1] ou, nombre impair, [a, -1, propriétaire du fantôme]. Évite les derniers adversaires
## (AutochessData.avoid_recent), en relâchant la contrainte s'il n'existe aucun appariement.
func _pairings(alive: Array) -> Array:
	var ids := alive.duplicate()
	_shuffle(ids)
	var out: Array = []
	var k0 := AutochessData.avoid_recent(ids.size())
	if ids.size() % 2 == 1:
		var fighter: int = ids[0]
		for pi in ids:  # pas deux fois de suite contre un fantôme
			if not players[pi].ghost_last:
				fighter = pi
				break
		ids.erase(fighter)
		var owners := ids.filter(func(o): return not _recent(fighter, o, k0))
		if owners.is_empty():
			owners = ids
		out.append([fighter, -1, owners[rng.randi_range(0, owners.size() - 1)]])
	for k in range(k0, -1, -1):
		var acc: Array = []
		if _match(ids, k, acc):
			out.append_array(acc)
			return out
	return out


func _match(rest: Array, k: int, acc: Array) -> bool:
	if rest.is_empty():
		return true
	var a: int = rest[0]
	for j in range(1, rest.size()):
		var b: int = rest[j]
		if _recent(a, b, k) or _recent(b, a, k):
			continue
		var others := rest.slice(1)
		others.erase(b)
		acc.append([a, b, -1])
		if _match(others, k, acc):
			return true
		acc.pop_back()
	return false


func _norm_result(r: Variant) -> Dictionary:
	var d: Dictionary = r if r is Dictionary else {}
	var stars: Array = d.get("stars", [[], []])
	if stars.size() < 2:
		stars = [[], []]
	var gold: Array = d.get("gold", [0, 0])
	return {"winner": clampi(int(d.get("winner", -1)), -1, 1), "stars": [(stars[0] as Array).duplicate(),
		(stars[1] as Array).duplicate()], "duration": float(d.get("duration", 0.0)),
		"gold": [int(gold[0]) if gold.size() > 0 else 0, int(gold[1]) if gold.size() > 1 else 0]}


func _apply_results() -> void:
	var kind := round_kind()
	for i in fights.size():
		var f: Dictionary = fights[i]
		var r: Dictionary = results[i]
		var w := int(r.winner)
		var a := int(f.a)
		var b := int(f.b)
		var line := "%s %s %d" % [round_key(), kind, a]
		if kind == "jcj":
			var opp := b if b >= 0 else int(f.ghost_of)
			_pvp_outcome(a, w == 0, w == -1, r.stars[1], opp, b < 0)
			(players[a].recent as Array).append(opp)
			players[a].ghost_last = b < 0
			if b >= 0:
				_pvp_outcome(b, w == 1, w == -1, r.stars[0], a, false)
				(players[b].recent as Array).append(a)
				players[b].ghost_last = false
			line += " %d %d w%d -%d" % [b, int(f.ghost_of), w, int(players[a].last.damage)]
			if b >= 0:
				line += "/-%d" % int(players[b].last.damage)
		else:
			_pve_outcome(a, w == 0, r.stars[1], kind == "gardien")
			line += " w%d -%d" % [w, int(players[a].last.damage)]
		players[a].gold = int(players[a].gold) + maxi(int(r.gold[0]), 0)  # or gagné en combat (objet Fortune)
		if b >= 0:
			players[b].gold = int(players[b].gold) + maxi(int(r.gold[1]), 0)
		history.append(line)
	for p in players:
		while (p.recent as Array).size() > 3:
			(p.recent as Array).pop_front()
	_eliminate_dead()


func _pvp_outcome(pi: int, won: bool, draw: bool, enemy_stars: Array, opp: int, ghost: bool) -> void:
	var p: Dictionary = players[pi]
	if won:
		p.gold = int(p.gold) + AutochessData.PVP_WIN_GOLD
		p.streak = maxi(int(p.streak), 0) + 1
		p.stats.won = int(p.stats.won) + 1
		p.last = {"result": "victoire", "damage": 0, "gold": AutochessData.PVP_WIN_GOLD, "opponent": opp, "ghost": ghost}
	else:
		var dmg := roundi(AutochessData.pvp_damage(stage, enemy_stars) * float(rule("damage_mult", 1.0)))
		p.hp = int(p.hp) - dmg
		p.streak = mini(int(p.streak), 0) - 1
		p.stats.lost = int(p.stats.lost) + 1
		p.last = {"result": "egalite" if draw else "defaite", "damage": dmg, "gold": 0, "opponent": opp, "ghost": ghost}


func _pve_outcome(pi: int, won: bool, enemy_standing: Array, guardian: bool) -> void:
	var p: Dictionary = players[pi]
	var gold0 := int(p.gold)
	var mult := int(_effect_param(p, "gardiens_renforces", "loot_mult", 1)) if guardian else 1
	_apply_loot(pi, AutochessData.loot(stage, round_i, won, rules), mult)
	if int(rule("pve_components", 0)) > 0:  # règle du jour « Jour de forge »
		_apply_loot(pi, {"composants": int(rule("pve_components", 0))}, 1)
	if guardian and won:
		for _k in int(_effect_param(p, "butin_gardien", "items", 0)):
			_offer(pi, {"kind": "objet", "options": _pick(AutochessData.ITEMS.keys(), AutochessData.ITEM_CHOICES)})
		p.gold = int(p.gold) + int(_effect_param(p, "gardiens_renforces", "gold", 0))
	var dmg := 0
	if won:
		p.stats.won = int(p.stats.won) + 1
	else:
		dmg = roundi(AutochessData.pve_damage(stage, enemy_standing.size(), guardian) * float(rule("damage_mult", 1.0)))
		p.hp = int(p.hp) - dmg
		p.stats.lost = int(p.stats.lost) + 1
	p.last = {"result": "victoire" if won else "defaite", "damage": dmg, "gold": int(p.gold) - gold0, "opponent": -1,
		"ghost": false}


## Butin d'une manche contre monstres ou gardien (AutochessData.loot) ; [param mult] : atout Menace.
func _apply_loot(pi: int, loot: Dictionary, mult: int) -> void:
	var p: Dictionary = players[pi]
	for key in loot:
		var v: Variant = loot[key]
		match String(key):
			"composants":
				for _k in int(v) * mult:
					_item_bench_add(p, AutochessData.BASE_COMPONENTS[rng.randi_range(0, AutochessData.BASE_COMPONENTS.size() - 1)])
			"insigne":
				for _k in mult:
					if rng.randf() < float(v):
						_item_bench_add(p, "insigne")
			"objets_au_choix":
				for _k in int(v) * mult:
					_offer(pi, {"kind": "objet", "options": _pick(AutochessData.ITEMS.keys(), AutochessData.ITEM_CHOICES)})
			"marteau":
				for _k in int(v) * mult:
					_item_bench_add(p, "marteau_reforge")
			"pince", "creuset", "miroir":
				for _k in int(v) * mult:
					_item_bench_add(p, String(key))
			"or":
				p.gold = int(p.gold) + int(v) * mult
			"heros_cout":
				var id := pool.draw(int(v), rng)
				if id != "" and not _add_unit(pi, _make_unit(id, 1, 1)):
					pool.give(id)
					p.gold = int(p.gold) + AutochessPool.cost_of(id)


## Élimine les stratèges à 0 PV ou moins. Même manche : le mieux placé avait le plus de PV avant la manche, puis l'équipe
## qui valait le plus, puis le tirage. Si tous les vivants tombent, le mieux placé prend la 1re place.
func _eliminate_dead() -> void:
	var alive := alive_ids()
	var dead: Array = alive.filter(func(pi): return int(players[pi].hp) <= 0)
	if dead.is_empty():
		return
	var key := {}
	for pi in dead:
		key[pi] = [int(players[pi].hp_before), team_value(pi), rng.randf()]
	dead.sort_custom(func(a, b):
		var ka: Array = key[a]
		var kb: Array = key[b]
		if ka[0] != kb[0]:
			return ka[0] > kb[0]
		if ka[1] != kb[1]:
			return ka[1] > kb[1]
		return ka[2] > kb[2])
	var after := alive.size() - dead.size()
	for k in dead.size():
		var p: Dictionary = players[dead[k]]
		p.place = after + 1 + k
		p.alive = false
		_release(p)


## Le stratège sort : ses unités et sa boutique reviennent à la réserve ; son équipe finale est gardée pour le bilan.
func _release(p: Dictionary) -> void:
	p.final_board = board_snapshot(int(p.id))
	for u in units_of(int(p.id)):
		pool.give(String(u.id), int(u.copies))
	for id in p.shop:
		pool.give(String(id))
	p.board = []
	var bench: Array = []
	bench.resize(AutochessData.BENCH_SIZE)
	p.bench = bench
	p.shop = []
	for _k in AutochessData.SHOP_SIZE:
		(p.shop as Array).append("")
	p.pending = []
	p.locked = false


func _check_over() -> bool:
	var alive := alive_ids()
	if alive.size() > 1:
		return false
	if alive.size() == 1:
		players[alive[0]].place = 1
	return true


## Combat provisoire de données (en attendant AC-C / AC-E) : puissance = somme des multiplicateurs de PV des unités ;
## victoire tirée à la graine du ctx, survivants selon l'écart de puissance.
static func power_fight(a: Array, b: Array, ctx: Dictionary) -> Dictionary:
	var r := RandomNumberGenerator.new()
	r.seed = int(ctx.get("seed", 0))
	var pw := [team_power(a), team_power(b)]
	var out := {"winner": -1, "stars": [[], []], "duration": 20.0 + r.randf() * 20.0}
	if pw[0] <= 0.0 and pw[1] <= 0.0:
		return out
	var teams := [a, b]
	if r.randf() < PF_DRAW and pw[0] > 0.0 and pw[1] > 0.0:
		for s in 2:
			out.stars[s] = _standing(teams[s], ceili(teams[s].size() * 0.5), r)
		out.duration = AutochessData.DRAW_AT
		return out
	var p0: float = pw[0] * pw[0] / (pw[0] * pw[0] + pw[1] * pw[1])
	var w := 0 if r.randf() < p0 else 1
	var ratio := minf(float(pw[1 - w]) / maxf(float(pw[w]), 0.001), 1.0)
	var n: int = teams[w].size()
	out.winner = w
	out.stars[w] = _standing(teams[w], clampi(ceili(n * (1.0 - 0.7 * ratio)), 1, n), r)
	return out


static func _standing(team: Array, n: int, r: RandomNumberGenerator) -> Array:
	var idx: Array = range(team.size())
	for i in range(idx.size() - 1, 0, -1):
		var j := r.randi_range(0, i)
		var t: Variant = idx[i]
		idx[i] = idx[j]
		idx[j] = t
	var out: Array = []
	for k in mini(n, idx.size()):
		out.append(int(team[idx[k]].get("stars", 1)))
	return out


static func team_power(units: Array) -> float:
	var s := 0.0
	for u in units:
		if u.has("monster"):
			s += PF_ELITE if String(u.monster) == "elite" else PF_SBIRE
		elif u.has("guardian"):
			s += PF_GUARDIAN_PER_STAGE * float(u.get("stage", 2)) * float(u.get("mult", 1.0))
		else:
			s += AutochessData.stat_mult(int(u.get("cost", 1)), int(u.get("stars", 1))) \
				* (1.0 + PF_ITEM * (u.get("items", []) as Array).size())
	return s


# --- Contrôles ----------------------------------------------------------------------------------------------------
## Invariant de la réserve : copies en réserve + copies tenues (plateaux, bancs, boutiques, choix partagé) = total.
func pool_ok() -> bool:
	return pool_errors().is_empty()


func pool_errors() -> Array:
	var held := {}
	for p in players:
		for u in (p.board as Array) + (p.bench as Array):
			if u != null:
				held[u.id] = int(held.get(u.id, 0)) + int(u.copies)
		for id in p.shop:
			if String(id) != "":
				held[id] = int(held.get(id, 0)) + 1
	for o in carousel.get("options", []):
		if int(o.taken_by) < 0:
			held[o.id] = int(held.get(o.id, 0)) + 1
	var bad: Array = []
	for id in pool.counts:
		if pool.remaining(id) + int(held.get(id, 0)) != AutochessPool.total(id):
			bad.append("%s : %d en réserve + %d tenues != %d" % [id, pool.remaining(id), int(held.get(id, 0)),
				AutochessPool.total(id)])
	return bad


# --- Sauvegarde ---------------------------------------------------------------------------------------------------
func to_dict() -> Dictionary:
	return {
		"version": SAVE_VERSION, "seed": str(seed_value), "rng": str(rng.state), "stage": stage, "round": round_i,
		"rounds_played": rounds_played, "phase": phase, "pool": pool.to_dict(), "players": players.duplicate(true),
		"carousel": carousel.duplicate(true), "augment_rarity": augment_rarity, "last_rarity": last_rarity,
		"next_uid": next_uid, "history": history.duplicate(), "format": format, "rule": day_rule,
	}


func from_dict(d: Dictionary) -> bool:
	if int(d.get("version", 0)) != SAVE_VERSION or (d.get("players", []) as Array).size() != AutochessData.PLAYERS:
		return false
	d = _ints(d.duplicate(true)) as Dictionary
	configure(String(d.get("format", "classique")), String(d.get("rule", "")))
	seed_value = String(d.seed).to_int()
	rng.seed = seed_value
	rng.state = String(d.rng).to_int()
	stage = int(d.stage)
	round_i = int(d.round)
	rounds_played = int(d.rounds_played)
	phase = String(d.phase)
	pool.from_dict(d.pool)
	players = d.players
	carousel = d.carousel
	augment_rarity = String(d.augment_rarity)
	last_rarity = String(d.last_rarity)
	next_uid = int(d.next_uid)
	history = d.history
	fights.clear()
	results.clear()
	if strategists.size() != AutochessData.PLAYERS:
		set_strategists([])
	return true


## Nombres entiers relus du JSON (le JSON ne rend que des réels).
static func _ints(v: Variant) -> Variant:
	if v is float and v == floorf(v) and absf(v) < 9.0e15:
		return int(v)
	if v is Array:
		for i in (v as Array).size():
			v[i] = _ints(v[i])
	elif v is Dictionary:
		for k in (v as Dictionary).keys():
			v[k] = _ints(v[k])
	return v


## Sauvegarde (SafeFile) : appelée au début de chaque préparation. Faux si save_path est vide ou si l'écriture échoue.
func save() -> bool:
	if save_path == "" or phase == "over":
		return false
	return SafeFile.write(save_path, JSON.stringify(to_dict()))


## Reprend la partie sauvegardée (null si aucune ou illisible), à la préparation de la manche où elle a été écrite.
static func load_game(path := SAVE_PATH, strats: Array = [], fight_fn := Callable()) -> Autochess:
	var txt := SafeFile.read(path)
	if txt == "":
		return null
	var d: Variant = JSON.parse_string(txt)
	if not d is Dictionary:
		return null
	var g := Autochess.new()
	g.save_path = path
	g.set_strategists(strats)
	if not g.from_dict(d):
		return null
	g.set_strategists(strats)
	g.fight = fight_fn
	return g


static func has_save(path := SAVE_PATH) -> bool:
	return path != "" and SafeFile.read(path) != ""


static func clear_save(path := SAVE_PATH) -> void:
	if path == "":
		return
	for ext in ["", ".tmp", ".bak"]:
		if FileAccess.file_exists(path + ext):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path + ext))


# --- Stratège de test ---------------------------------------------------------------------------------------------
## Stratège au hasard (tests, banc de la machine) : achète, relance, monte, vend, place et équipe sans réfléchir.
class RandomStrategist:
	extends RefCounted

	func decide(g: Autochess, pi: int) -> void:
		var r := g.rng
		var p: Dictionary = g.players[pi]
		for _k in 14:
			var a := r.randi_range(0, 11)
			if a <= 4:
				g.buy(pi, r.randi_range(0, AutochessData.SHOP_SIZE - 1))
			elif a == 5:
				if int(p.gold) >= 6:
					g.reroll(pi)
			elif a == 6:
				if int(p.gold) >= 10:
					g.buy_xp(pi)
			elif a == 7:
				var bench := g.bench_units(pi)
				if not bench.is_empty() and r.randf() < 0.3:
					g.sell(pi, int(bench[r.randi_range(0, bench.size() - 1)].uid))
			elif a <= 9:
				var all := g.units_of(pi)
				if not all.is_empty():
					var cell := Vector2i(r.randi_range(0, AutochessData.COLS - 1), r.randi_range(0, AutochessData.ROWS - 1))
					g.place(pi, int(all[r.randi_range(0, all.size() - 1)].uid), cell)
			elif a == 10:
				var board: Array = p.board
				if not board.is_empty():
					g.to_bench(pi, int(board[r.randi_range(0, board.size() - 1)].uid), r.randi_range(-1, AutochessData.BENCH_SIZE - 1))
			else:
				var all := g.units_of(pi)
				if not (p.items as Array).is_empty() and not all.is_empty():
					g.equip(pi, r.randi_range(0, (p.items as Array).size() - 1), int(all[r.randi_range(0, all.size() - 1)].uid))
		if r.randf() < 0.1:
			g.toggle_lock(pi)

	func choose(g: Autochess, _pi: int, c: Dictionary) -> int:
		if String(c.kind) == "atout" and int(c.get("rerolls", 0)) > 0 and g.rng.randf() < 0.2:
			return -1
		return g.rng.randi_range(0, (c.options as Array).size() - 1)
