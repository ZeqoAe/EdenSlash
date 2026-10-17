class_name MobaHero
extends RefCounted
## Les Deux Voies, lot MB-D (MOBA.md § 7.3, § 7.6 ; rapport conception/benchmark/R_MB_D.md) : un héros en partie, joueur ou
## IA. État (niveau 1-12 par XP, or, objets, potions, éliminations, série, aides, réapparition, rappel, enchaînements
## débloqués, choix de niveau en attente, achats annulables) et règles pures de l'économie (partage de l'XP et de l'or des
## sbires, rattrapage, primes, aides, déblocages par niveau) ; aucune scène ici : le directeur (MobaDirector) tient un
## MobaHero par héros (MobaDirector.info), la boutique est MobaItems, l'IA par poste MobaHeroAi (lot MB-E).
##
## Le niveau fait grandir le kit (§ 7.6) : niv. 1 = sorts principaux des cases 1-3 ; niv. 2, 3, 4 = 1er enchaînement d'une
## case au choix ; niv. 5 = ultime (case 4) ; niv. 6, 7, 8 = 2e enchaînement d'une case au choix ; niv. 9 = enchaînement de
## l'ultime ; niv. 10-12 = la fiche monte seule. Choix non bloquant : il attend dans [member pending] (le jeu continue) ;
## [member auto_pick] le fait tout seul (IA, réglage, pilote automatique).

const ASSIST_WINDOW := 10.0  # s : a frappé la victime dans ce délai = aide
const COMBAT_WINDOW := 5.0  # s sans coup donné ni reçu = hors combat (Cœur de pierre, Bottes du vent)
const SHOP_RADIUS := 14.0  # m autour de la fontaine : boutique ouverte
const UNLOCKS := {2: "chain1", 3: "chain1", 4: "chain1", 5: "ult", 6: "chain2", 7: "chain2", 8: "chain2", 9: "ult_chain"}

var node: Combatant
var side := 0
var role := 0
var lane := 0
var cid := ""
var family := 1
var is_player := false
var difficulty := 2

# --- progression ---------------------------------------------------------------------------------
var level := 1
var xp := 0.0
var gold := 0.0
var gold_earned := 0.0  # or gagné dans la partie (décision au temps, bilan)
var chains := [0, 0, 0, 0]  # enchaînements débloqués par case (case 4 : celui de l'ultime)
var ult := false
var pending: Array = []  # choix en attente : « chain1 » / « chain2 »
var picks: Array = []  # cases choisies, dans l'ordre (bilan, tests)
var auto_pick := false
var prefer: Array = [0, 1, 2]  # ordre des cases quand le choix est automatique

# --- boutique -------------------------------------------------------------------------------------
var items: Array = []  # ids (MobaData.ITEMS), MobaData.SLOTS au plus, bottes comprises
var potions := {"heal": MobaData.START_POTIONS}  # (IA ; le joueur garde les siennes dans Profile.bag, touches C / V)
var potion_cd := {"heal": 0.0, "boost": 0.0}
var history: Array = []  # achats et ventes annulables depuis l'arrivée à la base : {op, id, gold, used}
var in_shop := true

# --- combat ---------------------------------------------------------------------------------------
var kills := 0
var deaths := 0
var assists := 0
var streak := 0  # éliminations sans mourir (prime de la victime)
var cs := 0  # sbires achevés
var camps := 0  # camps de la jungle vidés (lot MB-F : MobaDirector.reward_camp)
var camp_times: Array = []
var respawn_at := -1.0
var home := false
var think := 0.0
var recall_left := -1.0  # s restantes de la canalisation du rappel (-1 : aucun)
var recall_from := Vector3.ZERO
var recalls := 0
var last_combat := -100.0  # dernier coup donné ou reçu (temps de partie)
var damagers := {}  # héros adverse -> dernier instant où il a frappé ce héros (aides)
var proc_at := {}  # id d'objet -> instant où son effet est de nouveau prêt
var shield := 0.0
var shield_until := 0.0
var empower := 0.0  # coup suivant × (Faux de la Lune)
var basic_hits := 0  # (Arc-tempête : un coup sur trois)
var low_armed := true  # (Bouclier du gardien : réarmé au-dessus de 30 % de PV)
var ooc := false  # hors combat (dernier état appliqué à la fiche)
var stats: Dictionary = {}  # totaux des objets (MobaItems.totals), refaits à chaque achat
var death_log: Array = []  # morts : {t, by, tower, near_tower, heroes} (mesures du lot MB-E)
var ai: RefCounted  # MobaHeroAi (lot MB-E) ; null pour le joueur


func _init(c: Combatant = null, s := 0, r := 0, character := "") -> void:
	node = c
	side = s
	role = r
	lane = int(MobaData.ROLES[r].lane) if r >= 0 and r < MobaData.ROLES.size() else 0
	cid = character
	family = int(GameData.class_data(cid).get("family", 1)) if cid != "" else 1
	gold = float(MobaData.START_GOLD)


# --- règles pures (test_mb_hero) -------------------------------------------------------------------

## Déblocage du niveau [param lv] : « chain1 », « ult », « chain2 », « ult_chain » ou "".
static func unlock_at(lv: int) -> String:
	return String(UNLOCKS.get(lv, ""))


## XP d'un sbire du genre [param kind] pour chacun des [param n] héros qui le partagent.
static func minion_xp_each(kind: String, n: int) -> float:
	return float(MobaData.XP_GAIN.get(kind, 0)) / float(maxi(n, 1))


## Or d'un sbire pour un héros : [param how] = « last » (dernier coup), « near » (allié à 15 m du dernier coup d'un
## héros), « stray » (achevé par un sbire ou une tour : chaque héros à 15 m).
static func minion_gold(kind: String, how: String) -> float:
	var g := float(MobaData.MINIONS[kind].gold) if MobaData.MINIONS.has(kind) else 0.0
	match how:
		"last":
			return g * MobaData.LAST_HIT
		"near":
			return g * MobaData.NEAR_SHARE
		"stray":
			return g * MobaData.STRAY_SHARE
	return 0.0


## Rattrapage : × (1 + CATCHUP) sur l'XP et l'or des sbires sous la moyenne adverse de CATCHUP_GAP niveaux.
static func catchup(lv: float, enemy_avg: float) -> float:
	return 1.0 + MobaData.CATCHUP if lv <= enemy_avg - MobaData.CATCHUP_GAP else 1.0


## Or d'une aide pour chacun des [param n] héros qui ont aidé.
static func assist_gold(n: int) -> float:
	return float(MobaData.BOUNTY.assist) / float(maxi(n, 1))


# --- niveaux ----------------------------------------------------------------------------------------

## Ajoute [param amount] XP ; renvoie les niveaux gagnés (déblocages posés : [member pending], [member ult]).
func add_xp(amount: float) -> int:
	if level >= MobaData.LEVEL_MAX or amount <= 0.0:
		return 0
	xp += amount
	var up := 0
	while level < MobaData.LEVEL_MAX and xp >= MobaData.xp_total(level + 1):
		level += 1
		up += 1
		_unlock(level)
	if level >= MobaData.LEVEL_MAX:
		xp = float(MobaData.xp_total(MobaData.LEVEL_MAX))
	return up


func _unlock(lv: int) -> void:
	match unlock_at(lv):
		"chain1", "chain2":
			pending.append(unlock_at(lv))
		"ult":
			ult = true
		"ult_chain":
			chains[3] = 1
	if auto_pick:
		while not pending.is_empty():
			choose(auto_choice())


## Cases qu'on peut choisir pour le premier choix en attente (vide : rien à choisir).
func choice_options() -> Array:
	if pending.is_empty():
		return []
	var need := 0 if String(pending[0]) == "chain1" else 1
	var out: Array = []
	var k := MobaData.kit(cid)
	for s in 3:
		var total := (k.get("slots", [])[s].chains as Array).size() if not k.is_empty() else 2
		if int(chains[s]) == need and need < total:
			out.append(s)
	return out


## Choix automatique : la première case de [member prefer] encore possible.
func auto_choice() -> int:
	var opts := choice_options()
	for s in prefer:
		if int(s) in opts:
			return int(s)
	return int(opts[0]) if not opts.is_empty() else -1


## Débloque l'enchaînement suivant de la case [param slot] (0-2) pour le premier choix en attente ; false si refusé.
func choose(slot: int) -> bool:
	if pending.is_empty():
		return false
	if not slot in choice_options():
		if choice_options().is_empty():
			pending.pop_front()  # (aucune case possible : le choix se perd plutôt que de bloquer la file)
		return false
	pending.pop_front()
	chains[slot] = int(chains[slot]) + 1
	picks.append(slot)
	return true


## Sorts débloqués : {mains: [ids des cases 1-3 (+ ultime)], chains: {case: [ids]}, ult: id, ult_on}.
func kit_unlocked() -> Dictionary:
	var k := MobaData.kit(cid)
	var mains: Array = []
	var ch := {}
	var slots: Array = k.get("slots", [])
	for i in slots.size():
		if i == 3 and not ult:
			break
		mains.append(int(slots[i].main))
		var n := int(chains[i])
		if n > 0:
			ch[i] = (slots[i].chains as Array).slice(0, n).map(func(x): return int(x))
	return {"mains": mains, "chains": ch, "ult": int(k.get("ult", {}).get("id", 0)), "ult_on": ult}


# --- or ---------------------------------------------------------------------------------------------

func add_gold(amount: float) -> void:
	if amount <= 0.0:
		return
	gold += amount
	gold_earned += amount


# --- combat -----------------------------------------------------------------------------------------

## Note le coup de [param attacker] (héros adverse) sur ce héros à l'instant [param t].
func note_damager(attacker: Combatant, t: float) -> void:
	if attacker != null and is_instance_valid(attacker) and attacker != node:
		damagers[attacker] = t
	last_combat = t


## Héros adverses qui l'ont frappé dans la fenêtre d'aide (sauf [param killer]).
func assisters(t: float, killer: Combatant) -> Array:
	var out: Array = []
	for a in damagers:
		if a != killer and is_instance_valid(a) and t - float(damagers[a]) <= ASSIST_WINDOW:
			out.append(a)
	return out


## Dernier héros adverse qui l'a frappé dans la fenêtre d'aide (crédit d'une élimination par une tour ou un sbire).
func last_damager(t: float) -> Combatant:
	var best: Combatant = null
	var bt := -INF
	for a in damagers:
		if is_instance_valid(a) and t - float(damagers[a]) <= ASSIST_WINDOW and float(damagers[a]) > bt:
			bt = float(damagers[a])
			best = a
	return best


func in_combat(t: float) -> bool:
	return t - last_combat < COMBAT_WINDOW


func recalling() -> bool:
	return recall_left >= 0.0


# --- affichage (lot MB-H : le HUD lit ces données) ---------------------------------------------------

## Données d'affichage du héros : niveau, XP, or, objets, potions, K / M / A, choix en attente, kit, rappel.
func view(t: float) -> Dictionary:
	var k := MobaData.kit(cid)
	var slots: Array = []
	for i in (k.get("slots", []) as Array).size():
		var s: Dictionary = k.slots[i]
		slots.append({"main": int(s.main), "chains_on": int(chains[i]), "chains_total": (s.chains as Array).size(),
			"locked": i == 3 and not ult, "unlock_level": 5 if i == 3 else 1})
	var pend := {}
	if not pending.is_empty():
		pend = {"kind": String(pending[0]), "options": choice_options(), "count": pending.size()}
	return {"level": level, "xp": xp - MobaData.xp_total(level), "xp_next": MobaData.xp_to_next(level), "gold": int(gold),
		"gold_earned": int(gold_earned), "items": items.duplicate(), "potions": potions.duplicate(), "kda": [kills, deaths, assists],
		"cs": cs, "streak": streak, "pending": pend, "slots": slots, "shop_open": in_shop or (node != null and node.is_dead),
		"recall": (MobaData.RECALL_TIME - recall_left) / MobaData.RECALL_TIME if recall_left >= 0.0 else -1.0,
		"respawn_in": maxf(0.0, respawn_at - t) if respawn_at >= 0.0 else 0.0, "ult": ult}
