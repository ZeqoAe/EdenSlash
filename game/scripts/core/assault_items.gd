class_name AssaultItems
extends RefCounted
## Objets et achats de L'Assaut (lot TAC-5, étude conception/benchmark/TACTIQUE.md § 7.3 et 7.4, rapport R_TAC_5.md) : les
## 31 objets génériques (aucun par classe : sorts 2 et 3 du kit, armes, armures, 10 utilitaires, 4 fioles, 4 outils, l'ultime
## chargé en jouant), leurs prix, les limites du paquetage, l'inventaire de manche de chaque héros (gardé s'il survit, perdu
## à sa chute), l'achat, l'annulation (revente au prix payé pendant la phase d'achat), le rachat, l'achat conseillé et le plan
## d'équipe des IA (achat complet, on économise, on force). Couche pure (sans scène) : le directeur applique les effets
## (AssaultDirector._apply_kit), l'écran d'achat (AssaultShop) appelle buy / sell.
##
##   AssaultItems.reset_all(clés) ; AssaultItems.inv(clé) ; AssaultItems.can_buy(clé, id, ctx) -> "" ou la raison
##   AssaultItems.buy(clé, id, ctx) ; AssaultItems.sell(clé, id) ; AssaultItems.sell_all(clé) ; AssaultItems.advised(clé, ctx)
##   ctx = {cid, role, side ("attack" / "defense")} (AssaultDirector.shop_ctx)
## Textes sans pourcentage (« desc ») ; le détail chiffré est dans l'infobulle (« tip »).

## Onglets de l'écran d'achat (LB / RB).
const TABS := [["spells", "Sorts"], ["weapon", "Arme"], ["armor", "Armure"], ["utility", "Utilitaires"], ["fiole", "Fioles et outils"]]
## Limites du paquetage (§ 7.4) : 2 cases d'utilitaires, 4 charges au total, 2 au plus du même ; 1 fiole ; 1 outil.
const UTIL_SLOTS := 2
const UTIL_CHARGES := 4
const UTIL_SAME := 2
## Catalogue : id -> {tab, group, name, price, desc, tip, icon (Ico) ; effets : dmg, shield, uses, side, util, fiole, tool}.
## Les sorts 2 et 3 prennent leur nom, leur prix et leur icône dans le kit de la classe (data/assault_kits.json).
const LIST := {
	"spell2": {"tab": "spells", "group": "spell2", "name": "Sort 2", "price": 0, "slot": 1, "desc": "Deuxième sort de ta classe",
		"tip": "Gardé tant que tu survis"},
	"spell3": {"tab": "spells", "group": "spell3", "name": "Sort 3", "price": 0, "slot": 2, "desc": "Troisième sort de ta classe",
		"tip": "Gardé tant que tu survis"},
	"affutee": {"tab": "weapon", "group": "weapon", "name": "Arme affûtée", "price": 600, "dmg": 1.15, "icon": "slot_weapon",
		"desc": "Tes coups et tes sorts frappent plus fort", "tip": "Dégâts de l'arme et des sorts × 1,15"},
	"maitre": {"tab": "weapon", "group": "weapon", "name": "Arme de maître", "price": 1500, "dmg": 1.30, "icon": "swords",
		"desc": "Bien plus forte que l'arme affûtée", "tip": "Dégâts de l'arme et des sorts × 1,30"},
	"appoint": {"tab": "weapon", "group": "weapon2", "name": "Arme d'appoint", "price": 400, "icon": "swap",
		"desc": "Une seconde arme d'un autre type", "tip": "Change d'arme : [Changer d'arme]"},
	"enduit": {"tab": "weapon", "group": "coat", "name": "Enduit amer", "price": 300, "uses": 3, "icon": "st_bleed",
		"desc": "Tes 3 prochains coups gâchent ses soins", "tip": "Soins reçus −40 % pendant 4 s, 3 coups"},
	"gilet": {"tab": "armor", "group": "armor", "name": "Gilet", "price": 400, "shield": 0.25, "icon": "slot_chest",
		"desc": "Un bouclier léger qui encaisse avant ta vie", "tip": "Bouclier : 25 % des PV max, ne se soigne pas"},
	"cuirasse": {"tab": "armor", "group": "armor", "name": "Cuirasse", "price": 1000, "shield": 0.5, "icon": "st_titan",
		"desc": "Un bouclier lourd qui encaisse avant ta vie", "tip": "Bouclier : 50 % des PV max, ne se soigne pas"},
	"reparer": {"tab": "armor", "group": "repair", "name": "Réparer", "price": 0, "icon": "refresh",
		"desc": "Remet ton bouclier à plein", "tip": "Prix : la part du bouclier perdue"},
	"brume": {"tab": "utility", "util": true, "name": "Fiole de brume", "price": 200, "icon": "st_sleep",
		"desc": "Un nuage qui coupe la vue (pas les coups)", "tip": "Nuage de 5 m pendant 10 s"},
	"eclat": {"tab": "utility", "util": true, "name": "Éclat aveuglant", "price": 150, "icon": "spark",
		"desc": "Éblouit qui le regarde en face", "tip": "Éclate après 0,6 s ; 12 m ; éblouit 1,2 s"},
	"feu": {"tab": "utility", "util": true, "name": "Pot de feu", "price": 300, "icon": "boss_puddles",
		"desc": "Une flaque de feu qui interdit un passage", "tip": "Zone de 4 m, 6 s, 6 % des PV max par seconde"},
	"bombe": {"tab": "utility", "util": true, "name": "Bombe d'éclats", "price": 300, "icon": "skull",
		"desc": "Une explosion annoncée au sol", "tip": "0,8 s d'annonce, 5 m, 25 % des PV max (le bouclier d'abord)"},
	"chouette": {"tab": "utility", "util": true, "name": "Œil de chouette", "price": 250, "icon": "goal",
		"desc": "Révèle les ennemis proches, même cachés", "tip": "12 m pendant 3 s"},
	"clochette": {"tab": "utility", "util": true, "name": "Clochette d'alarme", "price": 150, "icon": "alert",
		"desc": "Sonne au passage d'un ennemi", "tip": "60 s ; 5 m ; révèle 2 s"},
	"piege": {"tab": "utility", "util": true, "name": "Piège à ressort", "price": 250, "icon": "st_root",
		"desc": "Posé : bloque et révèle qui marche dessus", "tip": "Invisible au-delà de 4 m ; immobilise 0,8 s ; révèle 2 s"},
	"barricade": {"tab": "utility", "util": true, "name": "Barricade de glace", "price": 300, "icon": "boss_barrier",
		"desc": "Un mur de glace : ni passage, ni vue", "tip": "4 × 2 m pendant 12 s"},
	"leurre": {"tab": "utility", "util": true, "name": "Leurre", "price": 200, "icon": "follow",
		"desc": "Un double qui court en faisant du bruit", "tip": "4 s"},
	"silence": {"tab": "utility", "util": true, "name": "Poudre de silence", "price": 200, "icon": "hourglass",
		"desc": "Tes pas ne font plus aucun bruit", "tip": "6 s"},
	"soin": {"tab": "fiole", "fiole": true, "name": "Fiole de soin", "price": 200, "icon": "heart",
		"desc": "Rend de la vie ; un coup l'interrompt", "tip": "30 % des PV en 2 s ; annulée par un coup de plus de 5 %"},
	"hate": {"tab": "fiole", "fiole": true, "name": "Fiole de hâte", "price": 150, "icon": "st_swift",
		"desc": "Tu cours plus vite un moment", "tip": "+30 % de vitesse pendant 6 s (Hâte)"},
	"garde": {"tab": "fiole", "fiole": true, "name": "Fiole de garde", "price": 250, "icon": "slot_offhand",
		"desc": "Tu encaisses moins un moment", "tip": "Dégâts subis −25 % pendant 4 s"},
	"clarte": {"tab": "fiole", "fiole": true, "name": "Fiole de clarté", "price": 200, "icon": "check",
		"desc": "Te libère d'un contrôle", "tip": "Retire le contrôle en cours, insensible 2 s"},
	"pinces": {"tab": "fiole", "tool": true, "side": "defense", "name": "Pinces d'acier", "price": 300, "icon": "unlock",
		"desc": "Désamorce bien plus vite", "tip": "Désamorçage 4 s au lieu de 7 (Défense)"},
	"gants": {"tab": "fiole", "tool": true, "side": "attack", "name": "Gants de sapeur", "price": 300, "icon": "slot_gloves",
		"desc": "Pose la Charge plus vite", "tip": "Pose 3 s au lieu de 4 (Attaque)"},
	"talisman": {"tab": "fiole", "tool": true, "name": "Talisman de ténacité", "price": 350, "icon": "st_resolve",
		"desc": "Les contrôles subis durent moins", "tip": "Durée des contrôles subis −30 %"},
	"bottes": {"tab": "fiole", "tool": true, "name": "Bottes feutrées", "price": 300, "icon": "slot_boots",
		"desc": "Tu marches sans bruit à bonne allure", "tip": "Pas silencieux jusqu'à 75 % de ta vitesse (au lieu de la seule marche)"},
	"ultime": {"tab": "spells", "group": "ult", "name": "Ultime", "price": -1, "desc": "Ne s'achète pas : se charge en jouant",
		"tip": "7 points : élimination, chute, pose, désamorçage"},
}
## Prix des outils de la Charge et effets chiffrés (lus par le directeur).
const TOOL_PLANT := 0.75  # Gants : 3 s au lieu de 4
const TOOL_DEFUSE := 4.0 / 7.0  # Pinces : 4 s au lieu de 7
const TALISMAN := 0.3
const QUIET_SPEED := 0.75
## Réduction de prix des utilitaires pour le Contrôleur (passif de rôle, § 7.6).
const CONTROLEUR_DISCOUNT := 0.8
## Seuil d'or moyen d'équipe pour un achat complet (§ 7.10).
const FULL_BUY := 3400

## Inventaire de manche de chaque héros : clé -> {spells: [cases 1, 2], weapon, weapon2, coat, armor, shield (part des PV max
## restante), utils: {id: n}, fiole, tool, now: [[id, prix payé], …] (achats de la phase en cours, revendables), last: [ids]
## (achats de la manche passée : « Racheter »)}.
static var _inv: Dictionary = {}
## Plan d'achat annoncé par équipe : « full », « eco », « force ».
static var plans := ["", ""]


static func empty() -> Dictionary:
	return {"spells": [], "weapon": "", "weapon2": false, "coat": 0, "armor": "", "shield": 0.0, "utils": {}, "fiole": "",
		"tool": "", "now": [], "last": []}


static func reset_all(keys: Array) -> void:
	_inv = {}
	for k in keys:
		_inv[String(k)] = empty()
	plans = ["", ""]


static func inv(key: String) -> Dictionary:
	if not _inv.has(key):
		_inv[key] = empty()
	return _inv[key]


## Le héros tombe : il perd tout ce qu'il portait (§ 7.3 : on garde seulement si l'on survit).
static func lose(key: String) -> void:
	var last: Array = inv(key).last
	_inv[key] = empty()
	_inv[key].last = last


## Début d'une phase d'achat : les achats de la phase passée deviennent la liste « Racheter », plus rien n'est revendable.
static func new_phase(key: String) -> void:
	var v := inv(key)
	if not (v.now as Array).is_empty():
		v.last = (v.now as Array).map(func(e): return String(e[0]))
	v.now = []


static func info(id: String, ctx := {}) -> Dictionary:
	var e: Dictionary = (LIST.get(id, {}) as Dictionary).duplicate()
	if e.is_empty():
		return e
	if id in ["spell2", "spell3"]:
		var sl: Array = AssaultCombat.slots(String(ctx.get("cid", "")))
		var i := int(e.slot)
		if sl.size() > i:
			e["name"] = String(sl[i].name)
			e["price"] = int(sl[i].get("price", 250))
			e["nature"] = String(sl[i].nature)
			e["skill_id"] = int(sl[i].id)
			e["desc"] = String({"mobility": "Mobilité", "damage": "Dégâts", "control": "Contrôle", "heal": "Soin",
				"shield": "Bouclier", "buff": "Renfort", "invis": "Invisibilité"}.get(String(sl[i].nature), "Sort")) + " · gardé si tu survis"
	return e


## Prix de [param id] pour [param key] : sorts selon le kit, utilitaires −20 % pour le Contrôleur, réparation au prorata.
static func price(key: String, id: String, ctx := {}) -> int:
	var e := info(id, ctx)
	if e.is_empty():
		return 0
	if id == "reparer":
		var v := inv(key)
		if String(v.armor) == "":
			return 0
		var full := float(LIST[String(v.armor)].shield)
		var miss := clampf((full - float(v.shield)) / maxf(full, 0.01), 0.0, 1.0)
		return int(ceil(float(LIST[String(v.armor)].price) * miss / 10.0) * 10.0)
	var p := int(e.price)
	if bool(e.get("util", false)) and String(ctx.get("role", "")) == "controleur":
		p = int(round(p * CONTROLEUR_DISCOUNT / 10.0) * 10.0)
	return p


## Le héros [param key] possède-t-il [param id] (ou mieux, pour les armes et armures) ?
static func owns(key: String, id: String) -> bool:
	var v := inv(key)
	match id:
		"spell2":
			return 1 in v.spells
		"spell3":
			return 2 in v.spells
		"affutee":
			return String(v.weapon) in ["affutee", "maitre"]
		"maitre":
			return String(v.weapon) == "maitre"
		"appoint":
			return bool(v.weapon2)
		"enduit":
			return int(v.coat) > 0
		"gilet":
			return String(v.armor) in ["gilet", "cuirasse"]
		"cuirasse":
			return String(v.armor) == "cuirasse"
	if bool(LIST.get(id, {}).get("util", false)):
		return int(v.utils.get(id, 0)) > 0
	if bool(LIST.get(id, {}).get("fiole", false)):
		return String(v.fiole) == id
	if bool(LIST.get(id, {}).get("tool", false)):
		return String(v.tool) == id
	return false


static func util_count(key: String) -> int:
	var n := 0
	for k in inv(key).utils:
		n += int(inv(key).utils[k])
	return n


## Raison pour laquelle [param key] ne peut pas acheter [param id] ("" : il peut), en mots courts pour l'écran.
static func can_buy(key: String, id: String, ctx := {}) -> String:
	var e := info(id, ctx)
	if e.is_empty() or int(e.price) < 0:
		return "Ne s'achète pas"
	var v := inv(key)
	if id == "reparer":
		if String(v.armor) == "":
			return "Pas d'armure"
		if price(key, id, ctx) <= 0:
			return "Déjà à plein"
	elif owns(key, id) and not bool(e.get("util", false)):
		return "Déjà à toi"
	if e.has("side") and String(e.side) != String(ctx.get("side", "")):
		return "Pour l'Attaque" if String(e.side) == "attack" else "Pour la Défense"
	if bool(e.get("util", false)):
		var kinds := (v.utils as Dictionary).keys().filter(func(k): return int(v.utils[k]) > 0)
		if not id in kinds and kinds.size() >= UTIL_SLOTS:
			return "Deux utilitaires au plus"
		if util_count(key) >= UTIL_CHARGES:
			return "Quatre charges au plus"
		if int(v.utils.get(id, 0)) >= UTIL_SAME:
			return "Deux du même au plus"
	if bool(e.get("fiole", false)) and String(v.fiole) != "":
		return "Une fiole au plus"
	if bool(e.get("tool", false)) and String(v.tool) != "":
		return "Un outil au plus"
	if Assault.gold(key) < price(key, id, ctx):
		return "Il manque %d" % (price(key, id, ctx) - Assault.gold(key))
	return ""


## Achète [param id] pour [param key] (or retiré, paquetage mis à jour, revendable pendant cette phase) ; faux si refusé.
static func buy(key: String, id: String, ctx := {}) -> bool:
	if can_buy(key, id, ctx) != "":
		return false
	var p := price(key, id, ctx)
	if not Assault.spend(key, p):
		return false
	var v := inv(key)
	var e: Dictionary = LIST[id]
	match String(e.get("group", "")):
		"spell2", "spell3":
			(v.spells as Array).append(int(e.slot))
		"weapon":
			_refund_now(key, "weapon")
			v.weapon = id
		"weapon2":
			v.weapon2 = true
		"coat":
			v.coat = int(e.uses)
		"armor":
			_refund_now(key, "armor")
			v.armor = id
			v.shield = float(e.shield)
		"repair":
			v.shield = float(LIST[String(v.armor)].shield)
	if bool(e.get("util", false)):
		v.utils[id] = int(v.utils.get(id, 0)) + 1
	elif bool(e.get("fiole", false)):
		v.fiole = id
	elif bool(e.get("tool", false)):
		v.tool = id
	(v.now as Array).append([id, p])
	return true


## Une arme ou une armure achetée pendant cette phase et remplacée par mieux est remboursée.
static func _refund_now(key: String, group: String) -> void:
	var v := inv(key)
	for i in range((v.now as Array).size() - 1, -1, -1):
		var e: Array = v.now[i]
		if String(LIST.get(String(e[0]), {}).get("group", "")) == group:
			Assault.give(key, int(e[1]))
			if Assault.stats.has(key):
				Assault.stats[key].gold = int(Assault.stats[key].gold) - int(e[1])
			(v.now as Array).remove_at(i)


## Revend [param id] acheté pendant cette phase (au prix payé) ; faux sinon.
static func sell(key: String, id: String) -> bool:
	var v := inv(key)
	for i in range((v.now as Array).size() - 1, -1, -1):
		var e: Array = v.now[i]
		if String(e[0]) != id:
			continue
		Assault.give(key, int(e[1]))
		if Assault.stats.has(key):
			Assault.stats[key].gold = int(Assault.stats[key].gold) - int(e[1])  # (le remboursement n'est pas un gain)
		(v.now as Array).remove_at(i)
		var g := String(LIST[id].get("group", ""))
		match g:
			"spell2", "spell3":
				(v.spells as Array).erase(int(LIST[id].slot))
			"weapon":
				v.weapon = ""
			"weapon2":
				v.weapon2 = false
			"coat":
				v.coat = 0
			"armor":
				v.armor = ""
				v.shield = 0.0
			"repair":
				pass
		if bool(LIST[id].get("util", false)):
			v.utils[id] = int(v.utils.get(id, 0)) - 1
			if int(v.utils[id]) <= 0:
				(v.utils as Dictionary).erase(id)
		elif bool(LIST[id].get("fiole", false)):
			v.fiole = ""
		elif bool(LIST[id].get("tool", false)):
			v.tool = ""
		return true
	return false


## Revend tout ce qui a été acheté pendant cette phase ; rend le nombre d'objets revendus.
static func sell_all(key: String) -> int:
	var n := 0
	while not (inv(key).now as Array).is_empty():
		if not sell(key, String(inv(key).now[-1][0])):
			break
		n += 1
	return n


## Rachète la liste de la manche passée (« Racheter ») : ce qui manque et que l'or permet ; rend les ids achetés.
static func rebuy(key: String, ctx := {}) -> Array:
	var out: Array = []
	for id in inv(key).last:
		if buy(key, String(id), ctx):
			out.append(id)
	return out


## Achat conseillé (§ 5.1, « ce que ferait un bon joueur de ta classe ») pour l'or du moment, dans l'ordre : sorts 2 et 3 du
## kit (le moins cher d'abord), armure, arme, outil de la Charge, utilitaires du rôle, fiole. [param budget] < 0 : tout l'or.
static func advised(key: String, ctx := {}, budget := -1) -> Array:
	var role := String(ctx.get("role", "ouvreur"))
	var side := String(ctx.get("side", "attack"))
	var order: Array = ["spell2", "spell3"]
	var sp := order.map(func(i): return price(key, String(i), ctx))
	if sp[1] < sp[0]:
		order = ["spell3", "spell2"]
	var gold := Assault.gold(key) if budget < 0 else budget
	if gold >= 3400:
		order += ["cuirasse", "maitre"]
	elif gold >= 2000:
		order += ["cuirasse", "affutee"]
	else:
		order += ["gilet", "affutee"]
	order.append("gants" if side == "attack" else "pinces")
	order += {"rempart": ["brume", "garde"], "ouvreur": ["eclat", "brume"], "tireur": ["chouette", "eclat"],
		"controleur": ["feu", "brume"], "soutien": ["brume", "clarte"]}.get(role, ["brume"])
	order.append("soin")
	var out: Array = []
	var spent := 0
	for id in order:
		if LIST.has(id) and can_buy(key, String(id), ctx) == "" and spent + price(key, String(id), ctx) <= gold:
			out.append(id)
			spent += price(key, String(id), ctx)
	return out


## Plan d'achat de l'équipe [param team] (§ 7.10) : achat complet si l'or moyen ≥ 3 400 ; on force à la dernière manche d'une
## moitié, à la balle de match ou si l'autre équipe économise ; sinon on économise.
static func team_plan(team: int) -> String:
	var keys: Array = Assault.members[team]
	var avg := 0.0
	for k in keys:
		avg += Assault.gold(String(k))
	avg /= maxf(1.0, keys.size())
	if avg >= FULL_BUY:
		return "full"
	var half := int(Assault.num("half"))
	var last_of_half := Assault.round_n == half or Assault.round_n == int(Assault.num("max_rounds"))
	var match_point := int(Assault.score[0]) == int(Assault.num("win")) - 1 or int(Assault.score[1]) == int(Assault.num("win")) - 1
	if last_of_half or match_point or plans[1 - team] == "eco" or Assault.in_overtime():
		return "force"
	return "eco"


const PLAN_NAMES := {"full": "Achat complet", "eco": "On économise", "force": "On force l'achat"}


## Achats d'un héros scripté selon le plan de son équipe : achat complet (conseillé), forcé (conseillé avec tout l'or), éco
## (sort le moins cher + un utilitaire, au plus 40 % de l'or).
static func ai_buy(key: String, plan: String, ctx := {}) -> Array:
	var budget := Assault.gold(key)
	if plan == "eco":
		budget = mini(budget, maxi(400, int(budget * 0.4)))
	var want := advised(key, ctx, budget)
	if plan == "eco":
		want = want.filter(func(i): return String(i) in ["spell2", "spell3"] or bool(LIST[String(i)].get("util", false))).slice(0, 2)
	var out: Array = []
	for id in want:
		if buy(key, String(id), ctx):
			out.append(id)
	return out


## Ce qu'il manque à [param key] pour un achat complet (écran d'achat : « il lui manque 850 »).
static func missing_for_full(key: String) -> int:
	return maxi(0, FULL_BUY - Assault.gold(key))
