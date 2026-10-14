class_name GearPower
extends RefCounted
## Puissance d'équipement (PE, idée du joueur) : un seul nombre pour le niveau de l'équipement porté.
## PE d'une pièce = sa note (Items.rating : chaque stat comparée à la valeur habituelle de son emplacement,
## ~2,4 en commun, ~5,7 en rare, ~8,7 en mythique, ~9,6 en légendaire, ~17 en mythique +10) × une échelle
## linéaire de son niveau de puissance. PE du héros = les 9 emplacements + 30 % de l'arme secondaire,
## + 6 % par palier de set actif. On la compare à la PE attendue d'un équipement correct du niveau visé
## (10 de note par emplacement : un mythique amélioré) : le rapport ouvre ou ferme certaines activités et
## certains butins (jamais les duels : eux sont normalisés).

const BASE := 20.0  # PE par point de note, quel que soit le niveau
const PER_LEVEL := 2.0  # PE par point de note et par niveau de puissance
const TARGET_RATING := 10.0  # note moyenne d'un emplacement « attendu »
const OFFHAND_SHARE := 0.3
const SET_STEP := 0.06
## Rapport PE / PE attendue : seuil de chaque difficulté de donjon (Normal, Héroïque, Mythique).
const DIFF_RATIO := [0.0, 0.55, 0.8]
## Rapport minimal pour qu'un coffre puisse donner une pièce légendaire (sinon : mythique).
const LEGEND_RATIO := 0.5
const TIERS := [[0.35, "Faible", Color(0.7, 0.7, 0.78)], [0.7, "Correcte", Color(0.5, 0.85, 0.5)],
	[1.0, "Solide", Color(0.4, 0.7, 1.0)], [999.0, "Redoutable", Color(1.0, 0.7, 0.2)]]


static func item_power(item: Dictionary) -> int:
	if item.is_empty():
		return 0
	return roundi(Items.rating(item) * (BASE + PER_LEVEL * Items.power_level(item)))


## PE de l'équipement [param gear] (par défaut celui du héros : Profile.equipped).
static func hero_power(gear: Dictionary = {}) -> int:
	var g: Dictionary = gear if not gear.is_empty() else Profile.equipped
	var total := 0.0
	for slot in g:
		if slot == "trophy":
			continue
		var p := float(item_power(g[slot]))
		total += p * (OFFHAND_SHARE if slot == "offhand" else 1.0)
	var sg := g.duplicate()
	sg.erase("offhand")
	var steps := Items.active_set_bonuses(sg).size()
	return roundi(total * (1.0 + SET_STEP * steps))


## PE d'un équipement correct de niveau de puissance [param level].
static func expected(level: int) -> int:
	return roundi(Items.SLOTS.size() * TARGET_RATING * (BASE + PER_LEVEL * maxi(level, 1)))


## PE qu'il faut pour le niveau [param level] à la part [param share] (0 à 1) de la PE attendue.
static func required(level: int, share: float) -> int:
	return roundi(expected(level) * share)


static func ratio(level: int, power := -1) -> float:
	return float(hero_power() if power < 0 else power) / maxf(float(expected(level)), 1.0)


static func tier(r: float) -> Array:
	for t in TIERS:
		if r < float(t[0]):
			return t
	return TIERS[-1]


## Mode dev : tout est ouvert. Sinon la PE du héros atteint-elle [param need] ?
static func meets(need: int) -> bool:
	return need <= 0 or bool(Settings.get_v("interface", "dev_mode")) or hero_power() >= need


## Variation de PE si [param item] remplace la pièce portée au même emplacement.
static func delta_if_equipped(item: Dictionary) -> int:
	var slot := String(item.get("slot", ""))
	if not slot in Items.SLOTS:
		return 0
	var g := Profile.equipped.duplicate()
	g[slot] = item
	return hero_power(g) - hero_power()


## Texte court « PE 3 450 / 6 000 attendue (niveau 30) · Correcte » pour un niveau visé.
static func summary(level: int) -> String:
	var p := hero_power()
	var t := tier(ratio(level, p))
	return "PE %s / %s attendue (niveau %d) · %s" % [fmt(p), fmt(expected(level)), level, t[1]]


static func fmt(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	while s.length() > 3:
		out = " " + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if n < 0 else "") + s + out
