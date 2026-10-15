class_name SurvivorCards
extends RefCounted
## Cartes du Survivant (lot S3, SPEC §2 et §5, corrigé par DECISIONS_JOUEUR §2 et §4) : tirage à garanties (une carte
## d'équipement, une carte de sort), poids, pitié, évolutions, repli, relancer / bannir / garder / passer, cartes des
## coffres, choix de départ (une compétence OU une arme), choix automatique du pilote.
##
## Lot S1 : squelette. Tant que [method handles] est faux, Run (roll_cards, ban_card, rerolls_left) et CardPicker
## (auto_pick) gardent les cartes de la Survie ; S3 le passe à vrai quand le tirage est prêt.


## Les cartes du Survivant remplacent-elles celles de la Survie ?
static func handles() -> bool:
	return false


## [param n] cartes d'un choix ; [param kind] : "" (montée de niveau), "skill" (sorts seulement), "spell", "weapon"…
static func roll(_n := 3, _kind := "", _luck := 0.0) -> Array:
	return []


## Cartes d'un coffre de la carte de type [param box].
static func chest_cards(_box: String) -> Array:
	return []


## Applique une carte « sv_… » (Survivor.owns).
static func apply(_card: Dictionary) -> void:
	pass


## Bannit [param card] ; renvoie la carte de remplacement ({} : aucune).
static func ban(_card: Dictionary, _shown: Array) -> Dictionary:
	return {}


static func rerolls_left() -> int:
	return maxi(0, Survivor.BASE_REROLLS - Run.rerolls_used)


## Or donné par « Passer » (réglage skip_gold : 15 + 3 × niveau).
static func skip_gold() -> int:
	return roundi(Survivor.rule("skip_gold_base") + Survivor.rule("skip_gold_per_level") * Run.hero_level)


## Choix de départ (le jeu attend en pause). S1 : la première compétence, comme en Survie.
static func start_offers(world: Node) -> void:
	var n := int(Run.class_data().get("start_skills", 3))
	world._offer("Choisis ta première compétence", Run.roll_cards(n, true), func(): return Run.roll_cards(n, true))


## Choix automatique (pilote, aide « Bot ») ; {} : celui de CardPicker.
static func auto_pick(_options: Array, _random := false) -> Dictionary:
	return {}
