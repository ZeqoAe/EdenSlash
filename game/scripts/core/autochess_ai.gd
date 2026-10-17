class_name AutochessAi
extends RefCounted
## L'Échiquier, lot AC-D : les stratèges IA (les 7 adversaires du joueur). Spécification : conception/autochess/SPEC.md §4.4 ;
## rapport, mesures et réglages : conception/autochess/R_AC_D.md. Aucun cerveau neuronal : une stratégie scriptée qui se lit.
##
## Interface attendue par Autochess (lot AC-B) : decide(partie, i) au début de chaque préparation, choose(partie, i, choix)
## -> indice (-1 = relancer un choix d'atout). Fabrique : AutochessAi.make(difficulté, tempérament, graine) ; les 7 IA d'une
## partie : AutochessAi.lineup(difficulté, graine) ; reprise d'une partie sauvegardée : AutochessAi.restore(partie).
##
## Règle d'or : AUCUNE TRICHE. L'IA joue avec les mêmes boutiques, la même réserve et les mêmes règles que le joueur ; elle
## n'agit que par les actions publiques (buy, sell, reroll, buy_xp, toggle_lock, place, to_bench, equip) et ne lit que ce
## que le joueur voit : son propre état et les plateaux / bancs des autres stratèges (jamais les compteurs de la réserve, ni
## le générateur de la partie). Sa force vient de ses décisions, selon la difficulté, jamais d'un bonus caché.
##
## Quatre difficultés (SPEC §4.4) :
## - Recrue : dépense tout, relance et monte au hasard, suit ses premières unités et en change souvent, place selon la portée,
##   objets et atouts au hasard ;
## - Vétéran : garde 30 or, achète l'XP aux paliers, vise 2 traits dès l'étape 2, objets sur l'unité la plus chère, atouts à
##   la note de base ;
## - Champion : intérêts pleins (50 or) jusqu'au niveau 7, lit les plateaux adverses (quitte une famille disputée), assemble
##   les objets selon le rôle, protège son porteur (coin du fond contre les Ombres), atouts selon sa composition ;
## - Légende : courbe d'un bon joueur (niveau 8 en 4-2, relance à 6 en 3-x puis en 4-1 / 5-1), dépense à l'étape 2 et
##   garde 50 or ensuite, garde 3 plans et choisit au 1er atout, change de plan quand la composition ne vient pas, lit tous
##   les adversaires pour se placer (coins contre les plongeurs, rangée espacée contre les zones).
## Trois tempéraments (AutochessData.TEMPERAMENTS) : econome (courbe standard, garde son or), relanceur (reste au niveau 6
## jusqu'à l'étape 4 et relance pour des ★2 bon marché), montee_rapide (niveau 8 en 4-1, l'or en trop va à l'XP).
## Hasard : générateur propre, regraine à chaque appel par (graine, graine de la partie, stratège, compteur dans meta) : même
## graine = même partie, et la reprise après sauvegarde est identique (le compteur et le plan vivent dans players[i].meta).

const DIFFS := ["recrue", "veteran", "champion", "legende"]
const TEMPERS := ["econome", "relanceur", "montee_rapide"]

# --- Réglages ---------------------------------------------------------------------------------------------------------
## Sens des synergies par difficulté (poids des traits dans la valeur d'un plateau).
const TRAIT_SENSE := [0.15, 0.6, 1.0, 1.1]
## Valeur d'un palier de trait (en « unités ★1 de coût 1 ») : famille (3 / 6 / 9), arme (2 / 4 / 6).
const TIER_VAL_FAMILY := [0.0, 0.8, 2.2, 4.5]
const TIER_VAL_WEAPON := [0.0, 0.6, 1.6, 3.0]
## Envie d'un trait : famille du plan, armes du plan, le reste.
const DESIRE_FAMILY := 2.5
const DESIRE_WEAPON := 1.5
const DESIRE_OTHER := 0.25
const ITEM_POWER := 0.15  # chaque objet porté : +15 % de puissance (comme le combat provisoire)
const BUY_MIN := [0.0, 0.8, 0.9, 0.9]  # valeur minimale d'un achat
const STRONG_BUY := 2.5  # achat fort (★2 complétée, place libre bien remplie) : permis sous la réserve d'or
const MAX_ROLLS := 40
const RECRUE_ROLL := 0.55  # chance de relancer à chaque passe (Recrue)
const RECRUE_XP := 0.25
const RECRUE_REPLAN := 0.3
const RECRUE_SWAP := 1.5  # la Recrue ne remplace une unité posée que par une bien plus forte
const VETERAN_FLOOR := 30
const ECON_FLOOR := 50
const AUGMENT_REROLL_BELOW := 5.5  # Champion et Légende relancent un choix d'atout dont la meilleure note est sous ce seuil
## Niveau visé : [étape, manche, niveau] (le plus haut atteint à la manche courante).
const CURVES := {
	"veteran": [[2, 1, 4], [2, 6, 5], [3, 5, 6], [4, 5, 7], [5, 5, 8]],
	"champion": [[2, 1, 4], [2, 5, 5], [3, 2, 6], [4, 1, 7], [5, 1, 8], [6, 1, 9]],
	"standard": [[2, 1, 4], [2, 5, 5], [3, 2, 6], [4, 1, 7], [4, 2, 8], [5, 5, 9]],
	"econome": [[2, 1, 4], [2, 6, 5], [3, 2, 6], [4, 1, 7], [4, 5, 8], [5, 5, 9]],
	"relanceur": [[2, 1, 4], [2, 5, 5], [3, 2, 6], [4, 2, 7], [5, 1, 8], [6, 1, 9]],
	"montee_rapide": [[2, 1, 4], [2, 5, 5], [3, 1, 6], [3, 5, 7], [4, 1, 8], [5, 1, 9]],
}
## Objets préférés par groupe de rôles (du meilleur au moins bon) ; hors liste : ITEM_OFF.
const ITEM_PREF := {
	"tank": ["robustesse", "mur_titan", "brute", "colosse", "ange_gardien", "pas_du_vent", "coup_final", "soif_de_sang",
		"lame_givre", "briseur_sorts", "nova_givre", "volatile", "second_souffle"],
	"physique": ["lame_vive", "transe", "precision", "tueur_geants", "executeur", "soif_de_sang", "oeil_chasseur",
		"tir_multiple", "ricochet", "plaies", "fortune", "echo", "lame_statique", "second_souffle"],
	"magie": ["arcanes", "incantation", "source", "braise", "sort_critique", "echo", "elan", "persistance", "onde_de_choc",
		"flux_combo", "barriere", "vigueur", "nova_givre"],
	"soutien": ["source", "incantation", "elan", "vigueur", "barriere", "ange_gardien", "persistance", "mur_titan",
		"nova_givre"],
}
const ITEM_OFF := 0.4
const ROLE_GROUP := {"tank": "tank", "combattant": "physique", "assassin": "physique", "tireur": "physique",
	"mage": "magie", "soigneur": "soutien", "soutien": "soutien"}
const FRONT_ROLES := ["tank", "combattant", "assassin"]
const CARRY_ROLES := ["tireur", "mage", "assassin", "combattant"]
## Note de base des atouts (Vétéran ; Champion et Légende y ajoutent le contexte).
const AUGMENT_BASE := {
	"tirelire": 5.0, "relance_offerte": 5.0, "apprenti": 5.0, "composant": 5.0, "renfort": 4.5, "peau_dure": 5.0,
	"premier_sang": 4.0, "esquive_aiguisee": 5.0, "ralliement": 4.0, "mana_vive": 5.0,
	"interets_composes": 5.0, "pacte_de_sang": 5.5, "insigne": 6.0, "chef_de_guerre": 6.0, "heritage": 3.5,
	"echo_recrue": 5.0, "riposte": 5.0, "garde_du_corps": 6.0, "coeur_de_famille": 6.0, "forge_de_campagne": 4.5,
	"main_sure": 6.0,
	"couronne": 9.0, "heros_legendaire": 8.0, "ordre_de_bataille": 7.0, "menace": 4.0, "tresor_du_dragon": 7.0,
	"niveau_11": 6.0, "etoile_filante": 6.0, "arsenal": 7.0, "double_trait": 7.0,
	# lot ACX-3 (R_ACX3.md) : atouts de trait et d'unité
	"maitre_armes": 5.0, "recrue_doree": 5.0, "atelier": 4.0, "ligne_de_boucliers": 5.0, "porte_etendard": 5.0,
	"serment_rempart": 5.0, "pacte_ombre": 5.0, "piste_traque": 5.0, "flamme_ferveur": 5.0, "savoir_arcane": 5.0,
	"jumeaux": 5.5, "grand_grimoire": 7.0, "trinite": 7.0, "miroir_des_ames": 6.0, "grand_coeur": 6.0,
}
## Lot ACX-3 : courbe de niveau du format Éclair (aucune XP offerte : tout s'achète).
const ECLAIR_CURVE := [[1, 2, 3], [2, 1, 4], [2, 3, 5], [2, 6, 6], [3, 2, 7], [3, 5, 8], [4, 1, 9]]
const ECON_AUGMENTS := ["tirelire", "interets_composes", "tresor_du_dragon", "relance_offerte", "apprenti", "echo_recrue"]
## Puissance moyenne par place attendue d'un bon plateau à chaque niveau (★2 bon marché, puis ★2 de coût 3, 4…).
const QUALITY_TARGET := [1.0, 1.0, 1.2, 1.4, 1.6, 1.7, 1.9, 2.2, 2.6, 2.9, 3.2, 3.4]
const STRENGTH_WEAK := 0.92  # Légende : sous la médiane adverse, on dépense pour se renforcer
const STRENGTH_STRONG := 1.12
const COLS_CENTER := [3, 2, 4, 1, 5, 0, 6]
const COLS_EDGE := [0, 6, 1, 5, 2, 4, 3]
const COLS_SPREAD := [0, 6, 2, 4, 3, 1, 5]

var difficulty := 0  # 0 Recrue, 1 Vétéran, 2 Champion, 3 Légende
var temperament := "econome"
var seed_value := 0
var rng := RandomNumberGenerator.new()
## Réglages d'essai (banc --a= / --b=) : econ, early, curve, panic, roll6, rolldown, reroll_q, reroll_floor, potential,
## adapt (1 : la Légende règle sa réserve sur sa force face à la médiane adverse ; neutre au combat provisoire, à revoir).
var tune: Dictionary = {}

# État de l'appel en cours (relu à chaque appel : l'objet ne garde rien d'une manche à l'autre hors de meta).
var _g: Autochess
var _pi := 0
var _p: Dictionary = {}
var _desire: Dictionary = {}
var _wt: Dictionary = {}  # trait -> poids dans la valeur d'un plateau (sens des synergies × envie)
var _threat_cache: Dictionary = {}
var _strength_cache := -1.0
var _quality_cache := -1.0


# --- Fabrique -------------------------------------------------------------------------------------------------------
## Un stratège IA. [param diff] : 0-3 ou « recrue » / « veteran » / « champion » / « legende » ; [param temper] : un des
## AutochessData.TEMPERAMENTS (vide : tiré à la graine) ; [param ai_seed] : graine propre (≥ 0, < 2^31 conseillé).
static func make(diff: Variant = 0, temper := "", ai_seed := 0) -> AutochessAi:
	var ai := AutochessAi.new()
	ai.difficulty = diff_index(diff)
	ai.seed_value = absi(ai_seed)
	ai.temperament = temper if temper in TEMPERS else String(TEMPERS[ai.seed_value % TEMPERS.size()])
	return ai


static func diff_index(diff: Variant) -> int:
	if diff is String or diff is StringName:
		return maxi(DIFFS.find(String(diff)), 0)
	return clampi(int(diff), 0, DIFFS.size() - 1)


## Les 8 stratèges d'une partie : null à la place du joueur ([param human_seat], -1 : aucun joueur), 7 IA selon le mélange
## de la difficulté choisie (AutochessData.DIFFICULTIES[*].mix), tempéraments tirés à la graine.
static func lineup(diff: Variant, game_seed: int, human_seat := 0) -> Array:
	var d := diff_index(diff)
	var r := RandomNumberGenerator.new()
	r.seed = hash([game_seed, "ac_lineup", d])
	var levels: Array = []
	var mix: Array = AutochessData.DIFFICULTIES[d].mix
	for k in mix.size():
		for _n in int(mix[k]):
			levels.append(k)
	var seats := AutochessData.PLAYERS - (1 if human_seat >= 0 and human_seat < AutochessData.PLAYERS else 0)
	while levels.size() < seats:
		levels.append(d)
	for i in range(levels.size() - 1, 0, -1):
		var j := r.randi_range(0, i)
		var t: Variant = levels[i]
		levels[i] = levels[j]
		levels[j] = t
	var out: Array = []
	var k2 := 0
	for i in AutochessData.PLAYERS:
		if i == human_seat:
			out.append(null)
			continue
		out.append(make(int(levels[k2]), String(TEMPERS[r.randi_range(0, TEMPERS.size() - 1)]), r.randi_range(0, 0x3fffffff)))
		k2 += 1
	return out


## Stratèges d'une partie reprise : chaque IA est refaite d'après players[i].meta.ai (null : le joueur).
static func restore(g: Autochess) -> Array:
	var out: Array = []
	for p in g.players:
		var m: Dictionary = p.get("meta", {})
		var a: Variant = m.get("ai")
		if a is Dictionary:
			out.append(make(int(a.get("d", 0)), String(a.get("t", "")), int(a.get("s", 0))))
		else:
			out.append(null)
	return out


func _k(key: String, default: Variant) -> Variant:
	return tune.get(key, default)


func label() -> String:
	return "%s/%s" % [DIFFS[difficulty], temperament]


# --- Interface de la partie ----------------------------------------------------------------------------------------
func decide(g: Autochess, pi: int) -> void:
	_bind(g, pi)
	if not bool(_p.alive):
		return
	_update_plan()
	if difficulty == 0:
		_spend_recrue()
	else:
		_tidy_bench()
		_spend()
		_tidy_bench()
	_arrange()
	if _manage_items():
		_arrange()
	_lock()


func choose(g: Autochess, pi: int, c: Dictionary) -> int:
	_bind(g, pi)
	var opts: Array = c.get("options", [])
	if opts.is_empty():
		return 0
	if difficulty == 0:
		return rng.randi_range(0, opts.size() - 1)
	var scores: Array = []
	match String(c.get("kind", "")):
		"ouverture":
			for id in opts:
				scores.append(_opening_value(String(id)))
		"atout":
			if difficulty >= 3 and String(_plan().get("family", "")) == "":
				_commit_plan()
			for id in opts:
				scores.append(_augment_rating(String(id)))
			if difficulty >= 2 and int(c.get("rerolls", 0)) > 0 and _max(scores) < AUGMENT_REROLL_BELOW:
				return -1
		"choix_partage":
			for o in opts:
				var d: Dictionary = o
				if difficulty == 1:
					scores.append(float(AutochessPool.cost_of(String(d.id))))
				else:
					scores.append(_buy_value(String(d.id), _board_ctx()) + _component_value(String(d.component)))
		"objet":
			for id in opts:
				scores.append(_best_holder(String(id))[1])
		"composant":
			for id in opts:
				scores.append(_component_value(String(id)))
		"famille":
			for t in opts:
				scores.append(_trait_pick_value(String(t)))
		"heros":
			var bc := _board_ctx()
			for id in opts:
				scores.append(_buy_value(String(id), bc) + _plan_fit(String(id)))
		"embleme":
			for t in opts:
				scores.append(_trait_pick_value(String(t)))
		_:
			return 0
	return _argmax(scores)


# --- Appel en cours -------------------------------------------------------------------------------------------------
func _bind(g: Autochess, pi: int) -> void:
	_g = g
	_pi = pi
	_p = g.players[pi]
	if not _p.has("meta") or not _p.meta is Dictionary:
		_p["meta"] = {}
	var m: Dictionary = _p.meta
	if not m.has("ai"):
		m["ai"] = {"d": difficulty, "t": temperament, "s": seed_value}
	var n := int(m.get("n", 0))
	m["n"] = n + 1
	_strength_cache = -1.0
	_quality_cache = -1.0
	_threat_cache = {}
	rng.seed = hash([seed_value, g.seed_value, pi, n])
	_compute_desire()


func _meta() -> Dictionary:
	return _p.meta


func _plan() -> Dictionary:
	var pl: Variant = _meta().get("plan", {})
	return pl if pl is Dictionary else {}


func _gold() -> int:
	return int(_p.gold)


func _level() -> int:
	return int(_p.level)


func _sense() -> float:
	return float(TRAIT_SENSE[difficulty])


# --- Plan (composition visée) ---------------------------------------------------------------------------------------
func _compute_desire() -> void:
	_desire = {}
	for t in AutochessData.TRAITS:
		_desire[t] = DESIRE_OTHER
	var pl := _plan()
	var fam := String(pl.get("family", ""))
	if fam != "":
		_desire[fam] = DESIRE_FAMILY
		for w in pl.get("weapons", []):
			_desire[String(w)] = DESIRE_WEAPON
	else:
		for f in _meta().get("cands", []):  # Légende avant le 1er atout : trois plans à moitié
			_desire[String(f)] = DESIRE_FAMILY * 0.5
	_wt = {}
	for t in _desire:
		_wt[t] = _sense() * (0.5 + 0.5 * float(_desire[t]))


func _update_plan() -> void:
	var pl := _plan()
	var fam := String(pl.get("family", ""))
	var st := _g.stage
	# Éclair (lot ACX-3) : partie trop courte pour les trois plans de la Légende : elle relit les plateaux comme le Champion
	var d := 2 if difficulty == 3 and _no_interest() else difficulty
	match d:
		0:  # suit ses premières unités, en change souvent
			if fam == "" or (st >= 2 and _g.round_i == 1 and rng.randf() < RECRUE_REPLAN) or rng.randf() < RECRUE_REPLAN * 0.3:
				var all := _g.units_of(_pi)
				if not all.is_empty():
					var u: Dictionary = all[rng.randi_range(0, all.size() - 1)]
					var tr: Array = AutochessData.unit(String(u.id)).get("traits", [])
					_set_plan(String(tr[0]), [String(tr[1])] if tr.size() > 1 else [])
		1:  # vise 2 traits dès l'étape 2 et n'en change plus
			if fam == "" and st >= 2:
				var scores := _family_scores(false)
				var best := _best_key(scores)
				_set_plan(best, _plan_weapons(best, 1))
		2:  # relit les plateaux adverses à chaque étape jusqu'à l'étape 4 : quitte une famille disputée
			if st >= 2 and (fam == "" or (_g.round_i == 1 and st <= 4)):
				var scores := _family_scores(true)
				var best := _best_key(scores)
				if fam == "" or float(scores[best]) > float(scores.get(fam, -99.0)) + 1.5:
					_set_plan(best, _plan_weapons(best, 2))
		3:
			if fam == "":
				if st >= 2:
					_commit_plan()
				else:
					var scores := _family_scores(true)
					var keys := scores.keys()
					keys.sort_custom(func(a, b): return float(scores[a]) > float(scores[b]))
					_meta()["cands"] = keys.slice(0, 3)
			elif st >= 3 and st <= 4:  # la composition ne vient pas : on change de plan
				var scores := _family_scores(true)
				var best := _best_key(scores)
				if best != fam and float(scores[best]) > float(scores.get(fam, -99.0)) + 2.5:
					_set_plan(best, _plan_weapons(best, 2))
	_compute_desire()


## Légende : choisit un des 3 plans (au 1er atout ou à l'étape 2).
func _commit_plan() -> void:
	var scores := _family_scores(true)
	var cands: Array = _meta().get("cands", [])
	var best := ""
	for f in cands:
		if best == "" or float(scores.get(String(f), -99.0)) > float(scores.get(best, -99.0)):
			best = String(f)
	if best == "":
		best = _best_key(scores)
	_set_plan(best, _plan_weapons(best, 2))
	_compute_desire()


func _set_plan(fam: String, weapons: Array) -> void:
	_meta()["plan"] = {"family": fam, "weapons": weapons}
	_meta().erase("cands")


## Note de chaque famille : unités possédées (puissance) − familles disputées par les autres (plateaux et bancs visibles).
func _family_scores(read_others: bool) -> Dictionary:
	var out := {}
	for f in AutochessData.family_traits():
		out[f] = 0.0
	for u in _g.units_of(_pi):
		var f := String(info(String(u.id)).traits[0])
		if out.has(f):
			out[f] = float(out[f]) + _power(u)
	if read_others:
		var weight := 1.2 if _g.stage <= 3 else 0.6
		for q in _g.players:
			if int(q.id) == _pi or not bool(q.alive):
				continue
			var seen := {}
			for u in (q.board as Array) + (q.bench as Array):
				if u == null:
					continue
				var f := String(info(String(u.id)).traits[0])
				if not seen.has(f):
					seen[f] = {}
				seen[f][String(u.id)] = true
			for f in seen:
				if out.has(f) and (seen[f] as Dictionary).size() >= 3:
					out[f] = float(out[f]) - weight
	for f in out:
		out[f] = float(out[f]) + rng.randf() * 0.05
	return out


## Traits d'arme les plus utiles à une famille : ceux de ses unités (pondérés par le coût) et des unités possédées.
func _plan_weapons(fam: String, n: int) -> Array:
	var w := {}
	for id in AutochessData.units_with_trait(fam):
		var tr: Array = AutochessData.unit(String(id)).get("traits", [])
		if tr.size() > 1:
			w[String(tr[1])] = float(w.get(String(tr[1]), 0.0)) + 0.4 + 0.15 * AutochessPool.cost_of(String(id))
	for u in _g.units_of(_pi):
		var tr: Array = AutochessData.unit(String(u.id)).get("traits", [])
		if tr.size() > 1 and String(tr[0]) == fam:
			w[String(tr[1])] = float(w.get(String(tr[1]), 0.0)) + 1.0
	var keys := w.keys()
	keys.sort_custom(func(a, b): return float(w[a]) > float(w[b]))
	return keys.slice(0, n)


func _plan_fit(id: String) -> float:
	var s := 0.0
	for t in info(id).traits:
		s += float(_desire.get(String(t), DESIRE_OTHER))
	return s


# --- Valeur d'un plateau --------------------------------------------------------------------------------------------
static var _uinfo: Dictionary = {}
static var _tv: Dictionary = {}


## Données d'une unité lues une fois : coût, rôle, traits (famille, arme), portée, lignée.
static func info(id: String) -> Dictionary:
	var d: Variant = _uinfo.get(id)
	if d == null:
		var u := AutochessData.unit(id)
		d = {"cost": int(u.get("cost", 1)), "role": String(u.get("role", "combattant")),
			"traits": (u.get("traits", []) as Array).duplicate(), "range": int(u.get("range", 1)),
			"parent": String(u.get("parent", "")), "front": String(u.get("role", "")) in FRONT_ROLES}
		_uinfo[id] = d
	return d


static func _power(u: Dictionary) -> float:
	return AutochessData.stat_mult(int(info(String(u.id)).cost), int(u.get("stars", 1))) \
		* (1.0 + ITEM_POWER * (u.get("items", []) as Array).size())


## Traits d'une unité (les 2 siens, plus ceux de ses emblèmes).
static func traits_of(u: Dictionary) -> Array:
	for it in u.get("items", []):
		if String(it).begins_with("embleme"):
			return Autochess.unit_traits(u)
	return info(String(u.id)).traits


## Valeur d'un trait à [param c] unités : palier atteint + demi-valeur du progrès vers le suivant (table en cache).
static func tier_value(t: String, c: int) -> float:
	var tab: Variant = _tv.get(t)
	if tab == null:
		var ths := AutochessData.trait_thresholds(t)
		var vals: Array = TIER_VAL_FAMILY if String(AutochessData.TRAITS[t].kind) == "famille" else TIER_VAL_WEAPON
		var arr := PackedFloat32Array()
		for n in 16:
			var tier := 0
			for th in ths:
				if n >= int(th):
					tier += 1
			var v := float(vals[tier])
			if tier < ths.size():
				var lo := 0 if tier == 0 else int(ths[tier - 1])
				var hi := int(ths[tier])
				v += float(n - lo) / float(hi - lo) * (float(vals[tier + 1]) - float(vals[tier])) * 0.5
			arr.append(v)
		_tv[t] = arr
		tab = arr
	return (tab as PackedFloat32Array)[clampi(c, 0, 15)]


## Valeur d'une unité ajoutée à un plateau dont les traits sont [param ids_in] (trait -> {id: vrai}).
func _member_value(u: Dictionary, ids_in: Dictionary, front: int, cap: int) -> float:
	return _entry_value(_entry(u), ids_in, front, cap)


func _entry(u: Dictionary) -> Dictionary:
	var ui := info(String(u.id))
	return {"u": u, "id": String(u.id), "power": _power(u), "traits": traits_of(u), "front": bool(ui.front)}


func _entry_value(e: Dictionary, ids_in: Dictionary, front: int, cap: int) -> float:
	var v := float(e.power)
	var id := String(e.id)
	var bonus: Dictionary = _p.trait_bonus
	for t in e.traits:
		var have: Variant = ids_in.get(t)
		var c := 0
		if have != null:
			if (have as Dictionary).has(id):
				continue
			c = (have as Dictionary).size()
		if not bonus.is_empty():
			c += int(bonus.get(t, 0))
		v += float(_wt.get(t, 0.0)) * (tier_value(t, c + 1) - tier_value(t, c))
	if difficulty >= 1 and bool(e.front) and front < ceili(cap * 0.4):
		v += 0.6 * _sense()
	return v


## Meilleur plateau (cap unités) parmi [param units] : ajout glouton de l'unité qui apporte le plus.
func _choose_board(units: Array, cap: int) -> Dictionary:
	var rest: Array = []
	for u in units:
		rest.append(_entry(u))
	var chosen: Array = []
	var ids_in := {}
	var front := 0
	var values: Array = []
	while chosen.size() < cap and not rest.is_empty():
		var bi := 0
		var bv := -INF
		for i in rest.size():
			var v := _entry_value(rest[i], ids_in, front, cap)
			if v > bv:
				bv = v
				bi = i
		var e: Dictionary = rest[bi]
		rest.remove_at(bi)
		chosen.append(e.u)
		values.append(bv)
		for t in e.traits:
			if not ids_in.has(t):
				ids_in[t] = {}
			ids_in[t][e.id] = true
		if bool(e.front):
			front += 1
	return {"chosen": chosen, "ids_in": ids_in, "front": front, "values": values}


## Contexte d'achat : plateau visé, valeur de la moins bonne unité, copies possédées.
func _board_ctx() -> Dictionary:
	var cap := _g.board_cap(_pi)
	var b := _choose_board(_g.units_of(_pi), cap)
	b["cap"] = cap
	var weakest := INF
	for v in b.values:
		weakest = minf(weakest, float(v))
	b["weakest"] = 0.0 if weakest == INF else weakest
	var n1 := {}
	var n2 := {}
	for u in _g.units_of(_pi):
		var id := String(u.id)
		if int(u.stars) == 1:
			n1[id] = int(n1.get(id, 0)) + 1
		elif int(u.stars) == 2:
			n2[id] = int(n2.get(id, 0)) + 1
	b["n1"] = n1
	b["n2"] = n2
	return b


## Copies ★1 à réunir pour une ★2 (Étoile filante : 2 pour les unités bon marché).
func _need(id: String) -> int:
	if "etoile_filante" in _p.augments:
		var prm: Dictionary = AutochessData.augment("etoile_filante").params
		if AutochessPool.cost_of(id) <= int(prm.max_cost):
			return int(prm.copies)
	return AutochessData.COPIES_PER_STAR


## Valeur d'achat d'une unité de la boutique (copies, place sur le plateau, plan).
func _buy_value(id: String, bc: Dictionary) -> float:
	var cost := AutochessPool.cost_of(id)
	var v := 0.0
	var n1 := int(bc.n1.get(id, 0))
	var n2 := int(bc.n2.get(id, 0))
	var need := _need(id)
	if n1 + 1 >= need:
		v += 3.0 + 1.0 * cost
	elif n1 >= 1:
		v += 1.0 + 0.3 * cost
	if n2 >= 1:
		var slow := temperament == "relanceur" and cost <= 3 and difficulty >= 2
		v += (1.5 if slow else 0.6) + (1.0 if n2 >= 2 else 0.0)
	var mv := _member_value({"id": id, "stars": 1, "items": []}, bc.ids_in, int(bc.front), int(bc.cap))
	if (bc.chosen as Array).size() < int(bc.cap):
		v += mv
	else:
		v += maxf(0.0, mv - float(bc.weakest))
	v += _sense() * 0.3 * _plan_fit(id)
	if _g.stage >= 4 and cost == 1 and n1 == 0 and n2 == 0:
		v -= 1.0
	if difficulty >= 2 and cost >= 3 and _level() >= cost + 3:  # unité chère que la boutique propose souvent : avenir
		v += float(_k("potential", 0.5)) * float(cost - 2)
	return v


## Achat fort (permis sous la réserve, sans perdre une tranche d'intérêts) : ★2 complétée, place libre sur le plateau,
## ou nette amélioration du plateau (une ★1 se revend à son prix : remplir et améliorer ne coûte presque rien).
func _is_strong(id: String, v: float, bc: Dictionary) -> bool:
	if v >= STRONG_BUY or (bc.chosen as Array).size() < int(bc.cap):
		return true
	if int(bc.n1.get(id, 0)) >= 1 or int(bc.n2.get(id, 0)) >= 1:  # copie d'une unité qu'on a déjà
		return true
	if _g.bench_units(_pi).size() < 5 and AutochessPool.cost_of(id) <= 2 and _g.stage <= 3:  # pari bon marché
		return true
	var mv := _member_value({"id": id, "stars": 1, "items": []}, bc.ids_in, int(bc.front), int(bc.cap))
	return mv - float(bc.weakest) >= 0.4


## Valeur de garde d'une unité du banc (vendre la moins utile).
func _keep_value(u: Dictionary, bc: Dictionary) -> float:
	var id := String(u.id)
	var v := _power(u) * 0.6 + _sense() * 0.3 * _plan_fit(id)
	var same := int(bc.n1.get(id, 0)) if int(u.stars) == 1 else int(bc.n2.get(id, 0))
	if same >= 2:
		v += 0.8 + 0.3 * AutochessPool.cost_of(id)
	if int(u.stars) >= 2:
		v += 1.0
	return v


# --- Économie -------------------------------------------------------------------------------------------------------
func _curve_name() -> String:
	match difficulty:
		1:
			return "veteran"
		2:
			return "montee_rapide" if temperament == "montee_rapide" else "champion"
		3:
			return "standard" if temperament == "econome" else temperament
	return "econome"


## Format sans intérêts (Éclair) : l'or qui dort ne rapporte rien, on le dépense.
func _no_interest() -> bool:
	return not bool(_g.rule("interest", true))


func _target_level() -> int:
	var lvl := 1
	var curve: Array = ECLAIR_CURVE if _no_interest() else CURVES[String(_k("curve", _curve_name()))]
	for row in curve:
		if _g.stage > int(row[0]) or (_g.stage == int(row[0]) and _g.round_i >= int(row[1])):
			lvl = maxi(lvl, int(row[2]))
	if _no_interest():
		if difficulty == 1:
			lvl -= 1 if _g.stage >= 2 else 0  # Vétéran : un niveau derrière
		return clampi(lvl, 1, int(_p.max_level))
	if temperament == "relanceur" and difficulty >= 2 and _g.stage <= 3:
		lvl = mini(lvl, 6)  # reste au niveau 6 pour chercher les ★2 bon marché
	return mini(lvl, int(_p.max_level))


## Réserve d'or : en dessous, on n'achète que les unités fortes (★2 complétée…) sans perdre une tranche d'intérêts.
func _floors() -> Dictionary:
	var g := _gold()
	var st := _g.stage
	var hp := int(_p.hp)
	var unit_floor := 0
	var level_floor := 0
	match difficulty:
		1:
			unit_floor = 10 if st <= 2 else VETERAN_FLOOR
			level_floor = 10
		2:
			unit_floor = (10 if st <= 2 else ECON_FLOOR) if _level() < 7 else 30
			level_floor = 30 if _level() >= 5 else 0
			if hp < 40:
				unit_floor = 20
				level_floor = 20
		3:
			unit_floor = int(_k("early", 0)) if st <= 2 else int(_k("econ", ECON_FLOOR))
			level_floor = 0 if st <= 2 else 10
			if temperament == "econome":
				level_floor = 20 if st <= 3 else 10
			if _level() >= 8 or st >= 5:
				unit_floor = 30
			if hp < 50 and st >= 3:
				unit_floor = 20
			if int(_k("adapt", 0)) == 1 and st >= 2:  # plus faible que les autres : on renforce ; plus fort : on garde
				var sv := _strength()
				if sv < STRENGTH_WEAK:
					unit_floor = mini(unit_floor, 10 if st <= 2 else 20)
				elif sv > STRENGTH_STRONG and hp >= 50:
					unit_floor = maxi(unit_floor, int(_k("econ", ECON_FLOOR)))
	if st <= 1:
		unit_floor = 0
	if _no_interest():  # Éclair : rien à garder pour les intérêts ; l'XP d'abord, puis les unités
		unit_floor = 0 if difficulty >= 2 else mini(unit_floor, 6)
		level_floor = 0
	var strong := mini(unit_floor, (g / 10) * 10)
	if hp < 40 or st <= 1:
		strong = 0
	return {"unit": unit_floor, "level": level_floor, "strong": strong}


## Or plancher d'une série de relances (-1 : pas de relance cette manche).
func _roll_floor() -> int:
	var hp := int(_p.hp)
	var st := _g.stage
	var lvl := _level()
	if st <= 1:
		return -1
	if _no_interest():  # Éclair : relancer quand le niveau visé est atteint (or gardé : un achat d'XP)
		if lvl < _target_level():
			return -1
		return _g.xp_cost() if difficulty >= 2 else (12 if _gold() > 16 else -1)
	if difficulty == 1:
		if hp < 30:
			return 10
		return 40 if lvl >= 6 and _gold() > 44 else -1
	if st >= 3 and hp < int(_k("panic", 35 if difficulty == 2 else 45)):
		return 0 if hp < 20 else 10
	match temperament:
		"relanceur":
			if difficulty >= 2 and lvl >= 6 and st >= 3 and st <= 4 and _quality() < float(_k("reroll_q", 0.9)):
				return int(_k("reroll_floor", 30))
		"montee_rapide":
			if lvl >= 8:
				return 20 if st <= 4 else 10
		"econome":
			if lvl >= 8 and st >= 5 and _quality() < 0.9:
				return 20
	if difficulty == 3 and int(_k("adapt", 0)) == 1 and st >= 3 and _strength() < STRENGTH_WEAK and hp < 80:
		return 20 if hp >= 50 else 10
	if difficulty == 3 and lvl >= 6 and st == 3 and _g.round_i >= 2 and _quality() < float(_k("roll6", 0.85)):
		return 30  # relance à 6 : des ★2 avant de monter
	if difficulty == 3 and lvl >= 7 and st >= 4 and _quality() < float(_k("rolldown", 0.9)):
		return 20 if st == 4 else 10
	if difficulty == 2 and lvl >= 8 and _quality() < 0.85:
		return 20
	var econ := int(_k("econ", ECON_FLOOR))
	if lvl >= _target_level() and _gold() > econ + 4 and temperament != "montee_rapide":
		return econ
	return -1


## Force du plateau visé rapportée à la médiane des plateaux adverses vivants (visibles de tous). Cache par appel.
func _strength() -> float:
	if _strength_cache >= 0.0:
		return _strength_cache
	var mine := 0.0
	for u in _choose_board(_g.units_of(_pi), _g.board_cap(_pi)).chosen:
		mine += _power(u)
	var others: Array = []
	for q in _g.players:
		if int(q.id) == _pi or not bool(q.alive):
			continue
		var pw := 0.0
		for u in q.board:
			pw += _power(u)
		others.append(pw)
	if others.is_empty():
		return 1.0
	others.sort()
	var med := float(others[others.size() / 2])
	_strength_cache = mine / maxf(med, 0.01)
	return _strength_cache


## Qualité du plateau visé : puissance moyenne par place rapportée à celle qu'on attend à ce niveau (1 = bon plateau).
func _quality() -> float:
	if _quality_cache >= 0.0:
		return _quality_cache
	var cap := _g.board_cap(_pi)
	var b := _choose_board(_g.units_of(_pi), cap)
	var sum := 0.0
	for u in b.chosen:
		sum += AutochessData.stat_mult(int(info(String(u.id)).cost), int(u.stars))
	_quality_cache = minf(sum / float(maxi(cap, 1)) / float(QUALITY_TARGET[clampi(_level(), 1, QUALITY_TARGET.size() - 1)]), 1.5)
	return _quality_cache


func _spend() -> void:
	var fl := _floors()
	_level_up(_target_level(), int(fl.level))
	_buy_pass(int(fl.unit), int(fl.strong))
	var roll_to := _roll_floor()
	var guard := 0
	while roll_to >= 0 and _gold() - _g.reroll_cost() >= roll_to and guard < MAX_ROLLS:
		guard += 1
		if not _g.reroll(_pi):
			break
		_buy_pass(roll_to, roll_to)
	_level_excess()


func _level_up(target: int, level_floor: int) -> void:
	var guard := 0
	while _level() < target and _gold() - _g.xp_cost() >= level_floor and guard < 30:
		guard += 1
		if not _g.buy_xp(_pi):
			break
	# paliers : un achat qui finit le niveau
	if _g.stage >= 2 and _level() < mini(target + 1, int(_p.max_level)):
		var left := AutochessData.xp_to_next(_level()) - int(_p.xp)
		var floor_v := int(_floors().unit) if difficulty <= 2 else level_floor
		if left > 0 and left <= AutochessData.XP_BUY_AMOUNT and _gold() - _g.xp_cost() >= floor_v:
			_g.buy_xp(_pi)


## Or au-dessus de la réserve : en XP pour la Montée rapide (et le Champion qui suit sa courbe).
func _level_excess() -> void:
	if temperament != "montee_rapide" or difficulty < 2:
		return
	var guard := 0
	while _gold() - _g.xp_cost() >= ECON_FLOOR and _level() < mini(_target_level() + 1, int(_p.max_level)) \
			and guard < 20:
		guard += 1
		if not _g.buy_xp(_pi):
			break


func _buy_pass(unit_floor: int, strong_floor: int) -> void:
	var guard := 0
	var again := true
	while again and guard < 20:
		again = false
		guard += 1
		var bc := _board_ctx()
		var best_slot := -1
		var best_v := -INF
		for slot in AutochessData.SHOP_SIZE:
			var id := String(_p.shop[slot])
			if id == "":
				continue
			var cost := AutochessPool.cost_of(id)
			if _gold() < cost:
				continue
			var v := _buy_value(id, bc)
			if v < float(BUY_MIN[difficulty]):
				continue
			var floor_v := unit_floor
			if int(bc.n1.get(id, 0)) + 1 >= _need(id):
				floor_v = 0  # ★2 complétée : toujours
			elif _is_strong(id, v, bc):
				floor_v = strong_floor
			if _gold() - cost < floor_v:
				continue
			if v > best_v:
				best_v = v
				best_slot = slot
		if best_slot < 0:
			return
		var bid := String(_p.shop[best_slot])
		if not _g.can_receive(_pi, bid) and not _make_room(best_v, bc):
			return
		again = _g.buy(_pi, best_slot)


## Banc plein : vend l'unité de banc la moins utile si elle vaut moins que [param v]. Vrai si une case s'est libérée.
func _make_room(v: float, bc: Dictionary) -> bool:
	var worst: Dictionary = {}
	var wv := INF
	var on_board := {}
	for u in bc.chosen:
		on_board[int(u.uid)] = true
	for u in _g.bench_units(_pi):
		if on_board.has(int(u.uid)):
			continue
		var k := _keep_value(u, bc)
		if k < wv:
			wv = k
			worst = u
	if worst.is_empty() or wv >= v - 0.3:
		return false
	return _g.sell(_pi, int(worst.uid))


## Vente propre : unités de banc devenues inutiles (coût 1 sans paire en fin de partie, unités hors plan qui portent des
## objets : les objets reviennent au banc d'objets et repartent sur le plateau).
func _tidy_bench() -> void:
	var bench := _g.bench_units(_pi)
	if bench.is_empty() or (difficulty == 1 and _g.stage < 3):
		return
	if difficulty >= 2 and _g.stage < 4 and bench.size() < 7:
		var with_items := false
		for u in bench:
			with_items = with_items or not (u.items as Array).is_empty()
		if not with_items:
			return
	var bc := _board_ctx()
	var on_board := {}
	for u in bc.chosen:
		on_board[int(u.uid)] = true
	for u in bench:
		if on_board.has(int(u.uid)):
			continue
		var k := _keep_value(u, bc)
		var junk := false
		if difficulty == 1:
			junk = _g.stage >= 3 and k < 0.9
		else:
			junk = (_g.stage >= 4 and k < 1.2) or (not (u.items as Array).is_empty() and k < 2.0) \
				or (bench.size() >= 7 and k < 1.0)
		if junk:
			_g.sell(_pi, int(u.uid))


func _spend_recrue() -> void:
	for _pass in 4:
		var guard := 0
		while guard < 6:
			guard += 1
			var slots: Array = []
			for slot in AutochessData.SHOP_SIZE:
				var id := String(_p.shop[slot])
				if id != "" and _gold() >= AutochessPool.cost_of(id):
					slots.append(slot)
			if slots.is_empty():
				break
			var slot: int = slots[0]
			var bv := -INF
			for s in slots:  # au hasard, en suivant un peu ses premières unités
				var v := _plan_fit(String(_p.shop[s])) * 0.5 + rng.randf() * 2.0
				if v > bv:
					bv = v
					slot = s
			var id2 := String(_p.shop[slot])
			if not _g.can_receive(_pi, id2):
				var bench := _g.bench_units(_pi)
				if bench.is_empty() or rng.randf() > 0.3:
					break
				_g.sell(_pi, int(bench[rng.randi_range(0, bench.size() - 1)].uid))
			if not _g.buy(_pi, slot):
				break
		if _gold() >= _g.xp_cost() and rng.randf() < RECRUE_XP:
			_g.buy_xp(_pi)
		if _gold() >= _g.reroll_cost() and _g.stage >= 2 and rng.randf() < RECRUE_ROLL:
			_g.reroll(_pi)


## Verrou : garde une boutique qui contient une ★2 qu'on ne peut pas encore payer (Champion, Légende).
func _lock() -> void:
	if difficulty < 2:
		if bool(_p.locked):
			_g.toggle_lock(_pi)
		return
	var want := false
	var bc := {}
	for slot in AutochessData.SHOP_SIZE:
		var id := String(_p.shop[slot])
		if id == "" or _gold() >= AutochessPool.cost_of(id):
			continue
		if bc.is_empty():
			bc = _board_ctx()
		if _buy_value(id, bc) >= STRONG_BUY + 1.0:
			want = true
	if want != bool(_p.locked):
		_g.toggle_lock(_pi)


# --- Placement -----------------------------------------------------------------------------------------------------
## Choisit le plateau (les meilleures unités, cap au plus) puis pose chaque unité à sa place selon son rôle.
func _arrange() -> void:
	var cap := _g.board_cap(_pi)
	var chosen: Array = _recrue_board(cap) if difficulty == 0 else _choose_board(_g.units_of(_pi), cap).chosen
	var want := {}
	for u in chosen:
		want[int(u.uid)] = true
	var outs: Array = []
	for u in _p.board:
		if not want.has(int(u.uid)):
			outs.append(int(u.uid))
	var ins: Array = []
	for u in _g.bench_units(_pi):
		if want.has(int(u.uid)):
			ins.append(int(u.uid))
	while not outs.is_empty() and not ins.is_empty():  # échange banc <-> plateau
		var o: Dictionary = _g.find_unit(_pi, int(outs.pop_back()))
		_g.place(_pi, int(ins.pop_back()), Vector2i(int(o.cell[0]), int(o.cell[1])))
	for uid in outs:
		_g.to_bench(_pi, int(uid))
	for uid in ins:
		var c := _g.free_cell(_pi, "milieu")
		if c.x >= 0:
			_g.place(_pi, int(uid), c)
	var cells := _assign_cells(chosen)
	var by_uid := {}
	for u in chosen:
		by_uid[int(u.uid)] = u
	for uid in cells:
		var u: Dictionary = by_uid.get(int(uid), {})
		if u.is_empty() or not u.has("cell"):
			continue
		var c: Vector2i = cells[uid]
		if int(u.cell[0]) != c.x or int(u.cell[1]) != c.y:
			_g.place(_pi, int(uid), c)


## Recrue : garde les unités déjà posées, complète avec le banc dans l'ordre, ne remplace une unité que par une nettement
## plus forte (une étoile de plus se voit).
func _recrue_board(cap: int) -> Array:
	var chosen: Array = (_p.board as Array).duplicate()
	for u in _g.bench_units(_pi):
		if chosen.size() < cap:
			chosen.append(u)
			continue
		var wi := -1
		for i in chosen.size():
			if wi < 0 or _power(chosen[i]) < _power(chosen[wi]):
				wi = i
		if wi >= 0 and _power(u) >= _power(chosen[wi]) * RECRUE_SWAP:
			chosen[wi] = u
	return chosen.slice(0, cap)


## Case de chaque unité du plateau : uid -> Vector2i (rangée 0 = front).
func assign_cells(units: Array) -> Dictionary:
	return _assign_cells(units)


func _assign_cells(units: Array) -> Dictionary:
	var taken := {}
	var out := {}
	var order := units.duplicate()
	var prio := {"tank": 0, "combattant": 1, "assassin": 2, "tireur": 3, "mage": 3, "soigneur": 4, "soutien": 4}
	order.sort_custom(func(a, b):
		var ra := int(prio.get(_role(a), 1))
		var rb := int(prio.get(_role(b), 1))
		if ra != rb:
			return ra < rb
		return _power(a) > _power(b))
	var carry := _carry_uid(units)
	var threats := _threats() if difficulty >= 2 else {}
	var corner := Vector2i(0, 3) if (_pi % 2 == 0) else Vector2i(6, 3)
	for u in order:
		var prefs: Array = []
		if int(u.uid) == carry and difficulty >= 2 and _role(u) in ["tireur", "mage"] and bool(threats.get("dive", false)):
			prefs.append(corner)
		elif difficulty >= 2 and _role(u) in ["soigneur", "soutien"] and carry >= 0 and out.has(carry):
			var cc: Vector2i = out[carry]
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, -1), Vector2i(1, -1), Vector2i(-1, -1)]:
				prefs.append(cc + d)
		prefs.append_array(_cell_prefs(u, threats))
		for c in prefs:
			var cell: Vector2i = c
			if Autochess.cell_ok(cell) and not taken.has(cell):
				taken[cell] = true
				out[int(u.uid)] = cell
				break
	return out


func _role(u: Dictionary) -> String:
	return String(info(String(u.id)).role)


func _cell_prefs(u: Dictionary, threats: Dictionary) -> Array:
	var rows: Array = [0, 1, 2, 3]
	var cols: Array = COLS_CENTER
	if difficulty == 0:  # Recrue : avant ou arrière selon la portée, de gauche à droite
		var rng_cells := int(info(String(u.id)).range)
		rows = [0, 1, 2, 3] if rng_cells <= 1 else ([1, 0, 2, 3] if rng_cells == 2 else [3, 2, 1, 0])
		cols = [0, 1, 2, 3, 4, 5, 6]
	else:
		match _role(u):
			"tank", "combattant":
				rows = [0, 1, 2, 3]
			"assassin":
				rows = [0, 1, 2, 3]
				if difficulty >= 2:
					cols = COLS_EDGE  # sur les flancs : contournent par le côté pour plonger
			"tireur", "mage":
				rows = [3, 2, 1, 0]
				if bool(threats.get("splash", false)):
					cols = COLS_SPREAD
			"soigneur", "soutien":
				rows = [2, 3, 1, 0]
	var out: Array = []
	for r in rows:
		for c in cols:
			out.append(Vector2i(int(c), int(r)))
	return out


## Porteur désigné : l'unité offensive la plus forte du plateau (elle reçoit les objets offensifs, le coin protégé).
func _carry_uid(units: Array) -> int:
	var best := -1
	var bv := -INF
	for u in units:
		if not _role(u) in CARRY_ROLES:
			continue
		var v := _power(u) * (1.0 + 0.15 * _plan_fit(String(u.id)))
		if _role(u) in ["tireur", "mage"]:
			v *= 1.2
		if v > bv:
			bv = v
			best = int(u.uid)
	return best


## Lecture des plateaux adverses (visibles) : plongeurs (Ombre, assassins) et dégâts de zone (Poudre, Élémentaire).
func _threats() -> Dictionary:
	if not _threat_cache.is_empty():
		return _threat_cache
	var dive := 0
	var splash := 0
	for q in _g.players:
		if int(q.id) == _pi or not bool(q.alive):
			continue
		var ombre := {}
		var poudre := {}
		var assassins := 0
		for u in q.board:
			var tr: Array = info(String(u.id)).traits
			if "ombre" in tr:
				ombre[String(u.id)] = true
			if "poudre" in tr or "elementaire" in tr:
				poudre[String(u.id)] = true
			if String(info(String(u.id)).role) == "assassin":
				assassins += 1
		if ombre.size() >= 3 or assassins >= 2:
			dive += 1
		if poudre.size() >= 2:
			splash += 1
	var alive := maxi(_g.alive_ids().size() - 1, 1)
	_threat_cache = {"dive": dive * 4 >= alive or (difficulty == 2 and dive >= 1), "splash": difficulty >= 3 and splash * 3 >= alive}
	return _threat_cache


# --- Objets ---------------------------------------------------------------------------------------------------------
static func item_score(item: String, role: String) -> float:
	var parsed := Autochess.parse_item(item)
	var id := String(parsed.id)
	if id == "embleme":
		return 1.5
	if AutochessData.COMPONENTS.has(id):
		return 0.8
	var lst: Array = ITEM_PREF.get(String(ROLE_GROUP.get(role, "physique")), [])
	var k := lst.find(id)
	if k < 0:
		return ITEM_OFF
	return 3.0 - 2.0 * float(k) / float(maxi(lst.size() - 1, 1))


## Meilleur porteur d'un objet complet sur le plateau : [uid, note] ([-1, 0] si aucune place).
func _best_holder(item: String) -> Array:
	var carry := _carry_uid(_p.board)
	var best := -1
	var bv := 0.0
	for u in _p.board:
		if (u.items as Array).size() >= AutochessData.MAX_ITEMS_PER_UNIT:
			continue
		var v := item_score(item, _role(u)) * (0.6 + 0.2 * _power(u))
		if int(u.uid) == carry and _role(u) != "tank":
			v *= 1.5
		if difficulty == 1:  # Vétéran : sur l'unité la plus chère
			v = float(AutochessPool.cost_of(String(u.id))) * 10.0 + float(u.stars) - (u.items as Array).size() * 0.1
		if v > bv:
			bv = v
			best = int(u.uid)
	return [best, bv]


## Composant libre posé seul sur une unité (il s'assemble avec le prochain composant posé sur elle).
static func loose_component(u: Dictionary) -> String:
	for it in u.get("items", []):
		if AutochessData.COMPONENTS.has(String(it)):
			return String(it)
	return ""


func _component_value(comp: String) -> float:
	var best := 0.5
	for it in _p.items:
		var made := AutochessData.combine(String(it), comp)
		if AutochessData.ITEMS.has(made):
			best = maxf(best, float(_best_holder(made)[1]) * 0.5)
	for u in _p.board:
		var lc := loose_component(u)
		if lc != "":
			var made := AutochessData.combine(lc, comp)
			if AutochessData.ITEMS.has(made):
				best = maxf(best, item_score(made, _role(u)) * 0.6)
	return best


func _item_index(name: String) -> int:
	return (_p.items as Array).find(name)


## Objets du banc d'objets ; vrai si quelque chose a été posé (le plateau peut changer : couronne, porteur).
func _manage_items() -> bool:
	if (_p.items as Array).is_empty() or (_p.board as Array).is_empty():
		return false
	var before := (_p.items as Array).size()
	if difficulty == 0:
		_items_recrue()
		return (_p.items as Array).size() != before
	_crowns()
	_utilities()
	var guard := 0
	while guard < 24:
		guard += 1
		if not _items_step():
			break
	return (_p.items as Array).size() != before


## Lot ACX-3 : objets utilitaires du banc d'objets. Miroir : copie de l'unité bon marché qui vaut le plus (une ★2 qui se
## complète d'abord) ; Pince : libère les objets d'une unité du banc (ils repartent sur le plateau) ; Creuset : change les
## objets mal assortis d'une unité ; Marteau : défait les objets d'une unité du banc ou mal assortis (étape 3 et plus).
func _utilities() -> void:
	var guard := 0
	while guard < 8:
		guard += 1
		var used := false
		var items: Array = _p.items
		var bc := _board_ctx()
		var on_board := {}
		for u in bc.chosen:
			on_board[int(u.uid)] = true
		for k in items.size():
			var it := String(items[k])
			var target := -1
			match it:
				"miroir":
					var bv := 0.9
					var late := _g.stage >= 4 or items.size() >= 7  # plus tard : la meilleure copie, même modeste
					for u in _g.units_of(_pi):
						if not _g.utility_ok(_pi, u, it):
							continue
						var v := _buy_value(String(u.id), bc)
						if v > bv or (late and target < 0):
							bv = maxf(v, bv)
							target = int(u.uid)
				"pince", "marteau_reforge":
					for u in _g.bench_units(_pi):
						if not on_board.has(int(u.uid)) and not (u.items as Array).is_empty() and _g.utility_ok(_pi, u, it):
							target = int(u.uid)
							break
					if target < 0 and it == "pince":
						target = _misplaced_items()
					if target < 0 and it == "marteau_reforge" and _g.stage >= 3:
						target = _worst_items(1.0)
				"creuset":
					target = _worst_items(1.2)
			if target >= 0 and _g.equip(_pi, k, target):
				used = true
				break
		if not used:
			return


## Pince : unité du plateau (pas le porteur) dont les objets complets iraient nettement mieux sur le porteur, qui a la
## place de les prendre ; -1 sinon.
func _misplaced_items() -> int:
	var carry := _carry_uid(_p.board)
	var cu: Dictionary = {}
	for u in _p.board:
		if int(u.uid) == carry:
			cu = u
	if cu.is_empty() or _role(cu) == "tank":
		return -1
	var room := AutochessData.MAX_ITEMS_PER_UNIT - (cu.items as Array).size()
	for u in _p.board:
		if int(u.uid) == carry:
			continue
		var full := (u.items as Array).filter(func(x): return AutochessData.ITEMS.has(String(x)))
		if full.is_empty() or full.size() > room or full.size() != (u.items as Array).size():
			continue
		var here := 0.0
		var there := 0.0
		for x in full:
			here += item_score(String(x), _role(u))
			there += item_score(String(x), _role(cu))
		if there > here + 0.8 * full.size():
			return int(u.uid)
	return -1


## Unité du plateau dont les objets complets vont le plus mal à son rôle (note moyenne sous [param below]) ; -1 sinon.
func _worst_items(below: float) -> int:
	var best := -1
	var bv := below
	for u in _p.board:
		var full := (u.items as Array).filter(func(x): return AutochessData.ITEMS.has(String(x)))
		if full.is_empty():
			continue
		var s := 0.0
		for x in full:
			s += item_score(String(x), _role(u))
		s /= float(full.size())
		if s < bv:
			bv = s
			best = int(u.uid)
	return best


func _items_recrue() -> void:
	var guard := 0
	while not (_p.items as Array).is_empty() and guard < 12:
		guard += 1
		if rng.randf() > 0.7:
			return
		var k := rng.randi_range(0, (_p.items as Array).size() - 1)
		var units: Array = _p.board
		_g.equip(_pi, k, int(units[rng.randi_range(0, units.size() - 1)].uid))


## Deux Insignes : une Couronne (une place de plus) ; posés sur une unité sans composant libre.
func _crowns() -> void:
	while (_p.items as Array).count("insigne") >= 2:
		var host := -1
		for u in _p.board:
			if loose_component(u) == "" and (u.items as Array).size() < AutochessData.MAX_ITEMS_PER_UNIT:
				host = int(u.uid)
				break
		if host < 0:
			return
		if not _g.equip(_pi, _item_index("insigne"), host) or not _g.equip(_pi, _item_index("insigne"), host):
			return


## Une décision d'objet : objet complet sur son meilleur porteur, ou deux composants assemblés en un objet. Faux si rien.
func _items_step() -> bool:
	var items: Array = _p.items
	# 1. objets complets
	for k in items.size():
		var it := String(items[k])
		if AutochessData.ITEMS.has(it) or it.begins_with("embleme"):
			var h: Array = _best_holder(it)
			if int(h[0]) >= 0 and _g.equip(_pi, k, int(h[0])):
				return true
	# 2. composants : finir un composant libre ou en assembler deux du banc
	var comps: Array = []
	for k in items.size():
		var it := String(items[k])
		if AutochessData.COMPONENTS.has(it) and it != "insigne":
			comps.append(k)
	var best := {"v": 0.0}
	var carry := _carry_uid(_p.board)
	for k in comps:
		var c := String(items[k])
		for u in _p.board:
			var lc := loose_component(u)
			if lc != "" and lc != "insigne":
				var made := AutochessData.combine(lc, c)
				if AutochessData.ITEMS.has(made):
					var v := item_score(made, _role(u)) * (0.6 + 0.2 * _power(u)) + 0.5
					if v > float(best.v):
						best = {"v": v, "steps": [[c, int(u.uid)]]}
		for k2 in comps:
			if k2 <= k:
				continue
			var made := AutochessData.combine(c, String(items[k2]))
			if not AutochessData.ITEMS.has(made):
				continue
			for u in _p.board:
				if loose_component(u) != "" or (u.items as Array).size() >= AutochessData.MAX_ITEMS_PER_UNIT:
					continue
				var v := item_score(made, _role(u)) * (0.6 + 0.2 * _power(u))
				if int(u.uid) == carry and _role(u) != "tank":
					v *= 1.5
				if difficulty == 1:
					v = float(AutochessPool.cost_of(String(u.id))) * 10.0 + float(u.stars)
				if v > float(best.v):
					best = {"v": v, "steps": [[c, int(u.uid)], [String(items[k2]), int(u.uid)]]}
	if best.has("steps"):
		for s in best.steps:
			if not _g.equip(_pi, _item_index(String(s[0])), int(s[1])):
				return false
		return true
	# 3. Insigne seul + composant : un Emblème du trait du plan (Champion, Légende), à partir de l'étape 3
	if difficulty >= 2 and items.count("insigne") == 1 and _g.stage >= 3 and not comps.is_empty():
		for u in _p.board:
			if loose_component(u) == "" and (u.items as Array).size() < AutochessData.MAX_ITEMS_PER_UNIT:
				var c0 := String(items[comps[0]])
				if _g.equip(_pi, _item_index(c0), int(u.uid)) and _g.equip(_pi, _item_index("insigne"), int(u.uid)):
					return true
				return false
	# 4. composant isolé : sur le porteur (il s'assemblera avec le suivant), tout de suite pour la Légende
	if not comps.is_empty() and (difficulty >= 3 or _g.stage >= 4 or items.size() >= 7 or int(_p.hp) < 40):
		for u in _p.board:
			if int(u.uid) == carry and loose_component(u) == "" and (u.items as Array).size() < AutochessData.MAX_ITEMS_PER_UNIT:
				return _g.equip(_pi, comps[0], carry)
	return false


# --- Choix ----------------------------------------------------------------------------------------------------------
func _opening_value(id: String) -> float:
	var role := String(AutochessData.unit(id).get("role", ""))
	var v := {"tank": 1.0, "tireur": 1.0, "mage": 0.9}.get(role, 0.7) as float
	return v + rng.randf() * 0.2


func _augment_rating(id: String) -> float:
	var r := float(AUGMENT_BASE.get(id, 5.0))
	if difficulty < 2:
		return r
	var hp := int(_p.hp)
	var st := _g.stage
	if _no_interest():  # Éclair : ni intérêts ni XP offerte
		match id:
			"interets_composes":
				return 0.0
			"tresor_du_dragon", "apprenti":
				r += 1.5
			"pacte_de_sang":
				return 0.0 if hp < 30 else 4.0
	match id:
		"pacte_de_sang":
			r = 7.0 if hp >= 70 else (4.0 if hp >= 50 else 0.0)
		"interets_composes":
			r += (2.0 if temperament == "econome" else 0.0) - (2.0 if st >= 4 else 0.0)
		"etoile_filante":
			r += 3.0 if temperament == "relanceur" else 0.0
			for u in _g.units_of(_pi):
				if AutochessPool.cost_of(String(u.id)) <= 2 and int(u.stars) == 1:
					r += 0.25
		"niveau_11":
			r += 2.0 if temperament == "montee_rapide" else 0.0
		"relance_offerte":
			r += 1.5 if temperament == "relanceur" else 0.0
		"apprenti":
			r += 1.5 if temperament == "montee_rapide" else 0.0
		"tresor_du_dragon":
			r -= 2.0 if temperament == "econome" else 0.0
		"heritage":
			r += 3.0 if _has_lineage_pair() else -1.0
		"coeur_de_famille":
			var fam := String(_plan().get("family", ""))
			var counts := _g.trait_counts(_pi)
			if fam != "" and int(counts.get(fam, 0)) % 3 == 2:
				r += 1.5
		"menace":
			r -= 1.0 if hp < 50 else 0.0
		"renfort":
			r += 1.0 if st <= 2 else 0.0
		"serment_rempart", "pacte_ombre", "piste_traque", "flamme_ferveur", "savoir_arcane":  # lot ACX-3
			var t := String(AutochessData.augment(id).params.trait)
			var c := int(_g.trait_counts(_pi).get(t, 0))
			if t == String(_plan().get("family", "")) or t in _meta().get("cands", []):
				r += 2.0 + (1.0 if AutochessData.trait_tier(t, c + 1) > AutochessData.trait_tier(t, c) else 0.0)
			elif c >= 2:
				r += 0.5
			else:
				r -= 2.0
		"maitre_armes":
			var counts := _g.trait_counts(_pi)
			for w in _plan().get("weapons", []):
				if int(counts.get(String(w), 0)) % 2 == 1:
					r += 1.0
		"grand_coeur":
			var fam := String(_plan().get("family", ""))
			if fam != "" and int(_g.trait_counts(_pi).get(fam, 0)) % 3 >= 1:
				r += 1.5
		"jumeaux":
			var bc := _board_ctx()
			var top := ""
			for u in _p.board:
				if AutochessPool.cost_of(String(u.id)) <= 4 and (top == "" or AutochessPool.cost_of(String(u.id)) > AutochessPool.cost_of(top)):
					top = String(u.id)
			if top != "" and int(bc.n1.get(top, 0)) + 1 >= _need(top):
				r += 1.5
		"porte_etendard":
			var carry := _carry_uid(_p.board)
			for u in _p.board:
				if int(u.uid) == carry and (u.items as Array).size() >= 2:
					r += 1.0
		"atelier":
			for u in _g.bench_units(_pi):
				if not (u.items as Array).is_empty():
					r += 0.5
		"grand_grimoire":
			var casters := 0
			for u in _p.board:
				casters += 1 if String(info(String(u.id)).role) in ["mage", "soigneur", "soutien"] else 0
			r += 0.4 * casters - 0.8
	if difficulty >= 3:
		if id in ECON_AUGMENTS:
			r -= 0.8 * maxf(0.0, float(st - 2))
		elif String(AutochessData.augment(id).get("trigger", "")) in ["passif", "debut_combat", "attaque", "esquive", "chute_allie"]:
			r += 0.5 * maxf(0.0, float(st - 2)) + (1.0 if hp < 50 else 0.0)
	return r


func _has_lineage_pair() -> bool:
	var parents := {}
	for u in _p.board:
		var d := AutochessData.unit(String(u.id))
		parents[String(d.get("parent", ""))] = int(parents.get(String(d.get("parent", "")), 0)) + 1
	for k in parents:
		if int(parents[k]) >= 2:
			return true
	return false


## Note d'un trait choisi (Emblème, Cœur de famille) : gain de palier sur le plateau, pondéré par le plan.
func _trait_pick_value(t: String) -> float:
	if not AutochessData.TRAITS.has(t):
		return 0.0
	var counts := _g.trait_counts(_pi)
	var c := int(counts.get(t, 0))
	return (tier_value(t, c + 1) - tier_value(t, c)) * (0.5 + 0.5 * float(_desire.get(t, DESIRE_OTHER))) + rng.randf() * 0.01


# --- Outils ---------------------------------------------------------------------------------------------------------
func _argmax(scores: Array) -> int:
	var bi := 0
	for i in scores.size():
		if float(scores[i]) > float(scores[bi]):
			bi = i
	return bi


func _max(scores: Array) -> float:
	var m := -INF
	for s in scores:
		m = maxf(m, float(s))
	return m


func _best_key(d: Dictionary) -> String:
	var best := ""
	for k in d:
		if best == "" or float(d[k]) > float(d[best]):
			best = String(k)
	return best
