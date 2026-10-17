class_name SurvivorShop
extends RefCounted
## Boutique du gardien du Survivant (lot SVX-4, BM-SURV SV-R3 « l'or utile », sur le modèle de Brotato) : après chaque gardien
## vaincu (une fois son coffre choisi), une boutique s'ouvre, jeu en pause : OFFERS cartes du mode (les mêmes familles que les
## choix de niveau : pièces, améliorations, sorts, évolutions ; jamais de repli), chacune avec son prix ; « Garder » (verrou,
## gratuit) met une offre de côté pour la boutique suivante ; « Relancer » tire de nouvelles offres (sauf les gardées), à un
## prix qui monte à chaque relance de la même boutique. Chaque achat de la même boutique renchérit les suivants
## (PRICE_STEP). Ailleurs dans la partie : les coffres coûtent plus cher avec le temps (CHEST_PER_MIN) et « Passer » rapporte
## de moins en moins quand l'or déborde (SKIP_FULL). Mode scellé : rien ne sort de la partie.
## Réglages lus par le profil « survivor » (ModeRules) ; mesures : conception/survivor/R_SVX4.md.

const OFFERS := 4
const PRICE := [60.0, 14.0]  # prix d'une carte : base + par niveau du héros (comme une carte de marchand)
const PRICE_STEP := 0.15  # chaque achat de la même boutique : prix des suivants + 15 %
const REROLL := [30.0, 6.0]  # relance : base + par niveau
const REROLL_STEP := 1.5  # × à chaque relance de la même boutique (remis à la boutique suivante)
const SKIP_FULL := 3000.0  # « Passer » : or entier jusqu'à SKIP_FULL or en poche, puis × SKIP_FULL / or (au moins × 0,25)
const CHEST_PER_MIN := 0.025  # coffres de la carte : prix × (1 + CHEST_PER_MIN × minutes de carte)
## Prix selon la carte : rareté de l'amélioration, rareté de la pièce, évolution.
const TIER_MULT := {"common": 1.0, "rare": 1.3, "epic": 1.7, "legendary": 2.2}
const EVO_MULT := 2.5
const LUCK := 0.5  # chance de rareté des offres (comme un coffre doré : 0,6)

static var offers: Array = []  # [{card, price, kept, sold}] de la boutique ouverte
static var kept: Array = []  # cartes gardées pour la boutique suivante
static var rerolls := 0  # relances de la boutique ouverte
static var bought := 0  # achats de la boutique ouverte
static var visits := 0  # boutiques ouvertes dans la partie
static var spent := 0  # or dépensé à la boutique dans la partie (journal, mesures)
static var history: Array = []  # [{t, bought, rerolls, spent}] (journal, mesures)


static func reset() -> void:
	offers = []
	kept = []
	rerolls = 0
	bought = 0
	visits = 0
	spent = 0
	history = []


static func r(key: String, fallback: Variant) -> Variant:
	return ModeRules.rule(key, fallback, "survivor")


# --- prix ---------------------------------------------------------------------------------------------------------------
## Prix de la carte [param card] dans la boutique ouverte (renchéri par les achats déjà faits).
static func price_of(card: Dictionary) -> int:
	var p: Array = r("shop_price", PRICE)
	var base := float(p[0]) + float(p[1]) * maxi(Run.hero_level, 1)
	var k := 1.0
	match String(card.get("type", "")):
		"sv_evolution":
			k = EVO_MULT
		"sv_piece", "sv_weapon":
			k = 1.0 + 0.2 * int(card.get("item", {}).get("rarity", 0))
		_:
			k = float(TIER_MULT.get(String(card.get("tier", "common")), 1.0))
	return roundi(base * k * (1.0 + PRICE_STEP * bought))


## Prix de la prochaine relance.
static func reroll_price() -> int:
	var p: Array = r("shop_reroll", REROLL)
	return roundi((float(p[0]) + float(p[1]) * maxi(Run.hero_level, 1)) * pow(float(r("shop_reroll_step", REROLL_STEP)), rerolls))


## « Passer » : part de l'or donnée selon l'or en poche (1 jusqu'à skip_gold_full, puis de moins en moins, au moins 0,25).
static func skip_mult(gold := -1) -> float:
	var g := float(Profile.gold if gold < 0 else gold)
	var full := float(r("skip_gold_full", SKIP_FULL))
	return 1.0 if full <= 0.0 or g <= full else clampf(full / g, 0.25, 1.0)


## Coffres de la carte : prix × ce facteur à [param minutes] de carte.
static func chest_mult(minutes: float) -> float:
	return 1.0 + float(r("chest_per_min", CHEST_PER_MIN)) * maxf(minutes, 0.0)


# --- boutique -------------------------------------------------------------------------------------------------------------
## Ouvre une boutique : les cartes gardées d'abord (encore valables), puis des offres neuves.
static func open() -> Array:
	visits += 1
	rerolls = 0
	bought = 0
	offers = []
	for c in kept:
		if SurvivorCards.still_valid(c):
			offers.append({"card": c, "kept": true, "sold": false})
	kept = []
	_fill()
	return offers


## Complète la boutique avec des offres neuves (jamais deux fois la même cible, jamais de carte de repli).
static func _fill() -> void:
	var n := int(r("shop_offers", OFFERS))
	var keys: Array = offers.map(func(o): return String(o.card.get("sv_key", "")))
	var fresh := SurvivorCards._build(maxi(0, n - offers.size()), "", LUCK, keys, false)
	for c in fresh:
		if SurvivorCards.FAMILY.get(String(c.get("type", "")), "") == "fallback":
			continue
		offers.append({"card": c, "kept": false, "sold": false})
	for o in offers:
		o["price"] = price_of(o.card)


static func _reprice() -> void:
	for o in offers:
		if not bool(o.sold):
			o["price"] = price_of(o.card)


## Achète l'offre [param o] ; vrai si c'est fait.
static func buy(o: Dictionary) -> bool:
	if bool(o.get("sold", false)) or Profile.gold < int(o.get("price", 0)) or not SurvivorCards.still_valid(o.card):
		return false
	var price := int(o.price)
	Profile.gold -= price
	RunJournal.gold_out(price, "boutique")
	spent += price
	o["sold"] = true
	o["kept"] = false
	bought += 1
	Run.apply_card(o.card)
	Profile.changed.emit()
	# (une carte achetée peut en rendre une autre caduque : même pièce, sort monté)
	for x in offers:
		if not bool(x.sold) and not SurvivorCards.still_valid(x.card):
			x["sold"] = true
			x["gone"] = true
	_reprice()
	return true


## Garde (ou libère) l'offre [param o] pour la boutique suivante (gratuit).
static func toggle_keep(o: Dictionary) -> void:
	if not bool(o.get("sold", false)):
		o["kept"] = not bool(o.get("kept", false))


## Relance : de nouvelles offres à la place de celles qui ne sont ni gardées ni vendues ; vrai si c'est fait.
static func reroll() -> bool:
	var price := reroll_price()
	if Profile.gold < price:
		return false
	Profile.gold -= price
	RunJournal.gold_out(price, "boutique")
	spent += price
	rerolls += 1
	offers = offers.filter(func(o): return bool(o.get("kept", false)) and not bool(o.get("sold", false)))
	_fill()
	Profile.changed.emit()
	return true


## Ferme la boutique : les offres gardées attendent la suivante.
static func close(t := 0.0) -> void:
	kept = offers.filter(func(o): return bool(o.get("kept", false)) and not bool(o.get("sold", false))).map(func(o): return o.card)
	history.append({"t": snappedf(t, 0.1), "bought": bought, "rerolls": rerolls, "spent": spent})
	print("[sv] boutique %d : %d achat(s), %d relance(s), %d or dépensés en tout" % [visits, bought, rerolls, spent])
	offers = []


## Pilote automatique (mesures) : achète les meilleures cartes qu'il peut payer (SurvivorCards.auto_pick), puis relance
## tant qu'il garde de quoi acheter ensuite (au plus 6 relances), et garde la meilleure offre qu'il n'a pas pu payer.
static func pilot() -> void:
	for i in 7:
		while true:
			var can := offers.filter(func(o): return not bool(o.sold) and int(o.price) <= Profile.gold)
			if can.is_empty():
				break
			var pick := SurvivorCards.auto_pick(can.map(func(o): return o.card), true)
			var o: Dictionary = can.filter(func(x): return x.card == pick).front() if not pick.is_empty() else can[0]
			if not buy(o):
				break
		if i == 6 or Profile.gold < reroll_price() * 3:
			break
		reroll()
	var left := offers.filter(func(o): return not bool(o.sold))
	if not left.is_empty():
		var best := SurvivorCards.auto_pick(left.map(func(o): return o.card))
		for o in left:
			if o.card == best:
				o["kept"] = true
