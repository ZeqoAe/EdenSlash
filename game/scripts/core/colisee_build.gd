class_name ColiseeBuild
extends RefCounted
## Le Colisée, lots CO-E et CO-F (conception/benchmark/R_CO_E.md, R_CO_F.md ; ARENA.md § 6.5-6.7) : la CONSTRUCTION d'un
## héros pendant une partie (scellée, remise à zéro à chaque partie) : son or, ses atouts (ColiseeAugments), ses pièces et
## ses bonus d'enclume (ColiseeAnvil), ses sorts gagnés aux manches 3 et 6. Un objet par héros et par partie, gardé dans la
## machine de partie (Colisee) : ColiseeBuild.of(partie, équipe, place) ; place 0 de l'équipe du joueur = le joueur.
## Les héros scriptés sont recréés à chaque manche (lot CO-C) : leur construction est remise sur le nouveau héros à son
## apparition (ColiseeAugments.apply_hero, pièces passées à TeamMatch.make_hero). Le joueur porte ses pièces dans
## Profile.equipped (même dictionnaire que [member gear]).
##
## Préparation d'une manche (ColiseeAnvil.round_start) : or de la manche, offre d'atouts (manches 1, 4, 7, 10), enclume
## offerte (3 et 9), sort de plus (3 et 6) ; les IA décident tout de suite (ColiseeAnvil.ai_prep, ou le chef d'équipe du lot
## CO-D par ColiseeAnvil.coach : choose_augment / choose_anvil / choose_spell) ; le joueur choisit dans la page de
## préparation, ou la meilleure option lui est donnée au temps écoulé (ColiseeAnvil.auto_finish).

const META := "co_builds"

var team := 0
var slot := 0
var cid := ""
## Rôle de combat de la classe (tank, melee, ranged, healer) : notation des offres.
var role := "melee"
var family := 0
## Héros du joueur (ses choix : page de préparation ; sinon la meilleure option au temps écoulé).
var is_player := false
## Difficulté de l'IA qui choisit pour lui (0-3 ; le joueur : 3, sert au choix automatique).
var diff := 1

# --- or ---------------------------------------------------------------------------------------------------------------
var gold := 0
var gold_total := 0  ## or reçu depuis le début de la partie
var gold_log: Array = []  ## une ligne par manche : {round, base, win, ko, extra, total}

# --- atouts -------------------------------------------------------------------------------------------------------------
var augments: Array = []  ## ids tenus, dans l'ordre de prise (Tempête remplace Braise, Givre et Foudre)
var offer: Array = []  ## offre d'atouts en cours (3 ids de même rareté) ; [] : aucune
var offer_rarity := ""
var rerolls := 3  ## relances pour la partie (une relance change une carte)
var augment_log: Array = []  ## {round, id, offer}

# --- enclumes, pièces, bonus ---------------------------------------------------------------------------------------------
## Pièces portées : emplacement -> pièce (champs co_price : prix payé, co_round : manche d'achat). Joueur : Profile.equipped.
var gear: Dictionary = {}
## Bonus des enclumes de stat : clé -> valeur (hp_pct, dmg_pct, atk_speed, cdr, crit, def_pct).
var stats: Dictionary = {}
## Achats de stat de la préparation en cours (annulables, remboursés) : [{key, value, price}].
var stat_buys: Array = []
## Enclume ouverte, en attente du choix : {kind, price, gift, options: [...]} ; {} : aucune.
var anvil: Dictionary = {}
## Enclumes offertes à ouvrir (manche 3 : panoplie, manche 9 : éclat).
var gifts: Array = []
var anvil_log: Array = []  ## {round, kind, price, pick}

# --- sorts ----------------------------------------------------------------------------------------------------------------
var spells: Array = []  ## sorts gagnés (ids) en plus des 4 du départ
var spell_offer: Array = []  ## 3 ids de sorts de la classe proposés ; [] : aucun
var spell_slots := 0  ## places de sort gagnées (manches 3 et 6, Maître des sorts)

# --- manche -----------------------------------------------------------------------------------------------------------------
var kos := 0
var round_kos := 0  ## K.O. donnés pendant la manche en cours (or : +2 chacun, 3 au plus)
var ready := false  ## a fini sa préparation


# --- registre de la partie ---------------------------------------------------------------------------------------------------

## Crée les constructions de tous les héros de la partie [param g] (Colisee) : g.classes, g.team_diffs ; le joueur = équipe
## TeamMatch.player_team (0), place 0. Rend le tableau [équipe][place].
static func setup(g: Object) -> Array:
	var all: Array = []
	var trios: Array = g.get("classes") if g.get("classes") != null else []
	var diffs: Array = g.get("team_diffs") if g.get("team_diffs") != null else []
	for t in trios.size():
		var row: Array = []
		for j in (trios[t] as Array).size():
			var b := ColiseeBuild.new()
			b.team = t
			b.slot = j
			b.cid = String(trios[t][j])
			b.role = role_of(b.cid)
			b.family = Duel.family_of(b.cid)
			b.diff = int(diffs[t]) if t < diffs.size() else 1
			# (banc IA contre IA du lot CO-D : trio 0 tiré sans la classe du joueur -> aucune construction de joueur)
			b.is_player = t == 0 and j == 0 and bool(g.get_meta("co_player", true)) and b.cid == Run.class_id
			if b.is_player:
				b.diff = 3
			row.append(b)
		all.append(row)
	g.set_meta(META, all)
	return all


static func all_of(g: Object) -> Array:
	if g == null or not g.has_meta(META):
		return []
	return g.get_meta(META)


static func of(g: Object, t: int, j: int) -> ColiseeBuild:
	var all := all_of(g)
	if t < 0 or t >= all.size() or j < 0 or j >= (all[t] as Array).size():
		return null
	return all[t][j]


static func team_of(g: Object, t: int) -> Array:
	var all := all_of(g)
	return all[t] if t >= 0 and t < all.size() else []


static func player_build(g: Object) -> ColiseeBuild:
	return of(g, TeamMatch.player_team if TeamMatch.active else 0, 0)


## Rôle de combat d'une classe d'après sa fiche de l'Échiquier (data/autochess_units.json) : tank ; combattant, assassin ->
## melee ; tireur, mage -> ranged ; soigneur, soutien -> healer.
static func role_of(cid: String) -> String:
	match String(AutochessData.unit(cid).get("role", "")):
		"tank":
			return "tank"
		"tireur", "mage":
			return "ranged"
		"soigneur", "soutien":
			return "healer"
	return "melee"


## La classe frappe surtout par ses sorts (mages) : étiquette « sorts » de la notation.
static func spell_class(cid: String) -> bool:
	return String(AutochessData.unit(cid).get("role", "")) == "mage"


# --- lecture ----------------------------------------------------------------------------------------------------------------

func has(id: String) -> bool:
	return id in augments


func label() -> String:
	return "%s (%s)" % [String(GameData.class_data(cid).get("name_fr", cid)), TeamMatch.team_name(team)]


## Résumé lisible (journal, tests).
func summary() -> Dictionary:
	return {"team": team, "slot": slot, "cid": cid, "gold": gold, "augments": augments.duplicate(), "gear": gear.keys(),
		"stats": stats.duplicate(), "spells": spells.duplicate(), "rerolls": rerolls}
