class_name Modes
extends RefCounted
## Mode de jeu en cours (conception, lot 4) : une seule source, lue par les règles (ModeRules), le
## journal de run et, peu à peu, par les tests dispersés `Tower.active` / `Duel.active` /
## `Training.active`. Ces drapeaux restent les vrais interrupteurs (le mode est déduit d'eux) : rien
## ne peut donc se désynchroniser. Modes : menu, survival (Survie), survivor (Survivant), run (ancienne
## run de farm), tower, dungeon, duel, royale, training, autochess (L'Échiquier : AutochessDirector.active), et les modes
## d'équipes de TeamMatch (lot MODE-0 : colisee, moba, assault ; TeamMatch.active, id dans TeamMatch.mode).
##
## API unique (lot MODE-0, R_MODE0.md) pour « le mode actif est X, scellé, de type équipes / chacun pour soi / objectif » :
## current() (id), kind() (type), sealed(), is_pvp(), team_match(), hero_match(). Les ~110 tests dispersés de Duel.active /
## Royale.active migrent vers elle peu à peu (les endroits à risque pour les modes d'équipes l'ont déjà fait).

## Mode imposé (essais d'équilibrage, tests) : prioritaire sur les drapeaux.
static var forced := ""


static func current() -> String:
	if forced != "":
		return forced
	if TeamMatch.active:
		return TeamMatch.mode  # (lot MODE-0 : ne pose jamais Duel.active ni Royale.active)
	if AutochessDirector.active:
		return "autochess"
	if Royale.active:
		return "royale"
	if Duel.active:
		return "duel"
	if Tower.active:
		return "dungeon" if Tower.is_dungeon() else "tower"
	if Training.active:
		return "training"
	if Run.active:
		if Survivor.active:
			return "survivor"  # (garde Run.survival : le socle de la Survie sert de base)
		return "survival" if Run.survival else "run"
	return "menu"


## Combat entre héros (règles JcJ de PvpCaps) : le Duel, le Battle royale et les modes d'équipes (TeamMatch, sauf fiche
## pvp = false).
static func is_pvp() -> bool:
	if TeamMatch.active and forced == "":
		return TeamMatch.pvp()
	return current() in ["duel", "royale"] or Siege.ffa  # + le chacun pour soi du Siège


## Type du mode en cours (lot MODE-0) : « menu » ; « pve » (Survie, run, Tour, donjon, entraînement, Survivant) ;
## « duel » (1 contre 1, Ligue, Panthéon) ; « teams » (équipes : Arènes 2v2 / 3v3, Gantelet, Colisée) ; « ffa » (chacun
## pour soi : Battle royale, et la bascule du Siège) ; « objective » (Deux Voies, Assaut) ; « board » (L'Échiquier).
static func kind(m := "") -> String:
	if m == "":
		m = current()
	if TeamMatch.is_mode(m):
		return String(TeamMatch.spec_of(m).kind)
	match m:
		"menu":
			return "menu"
		"duel":
			return "teams" if Duel.team_mode() else "duel"
		"royale":
			return "ffa"
		"autochess":
			return "board"
	return "ffa" if Siege.ffa else "pve"


## Partie d'un mode d'équipes de TeamMatch (Colisée, Deux Voies, Assaut).
static func team_match() -> bool:
	return TeamMatch.active


## Partie entre héros sans économie de run (ni or ni butin, ni journal, ni extraction, ni sauvegarde en cours de partie) :
## Duel (et Arènes, Gantelet), Battle royale, modes d'équipes. Remplace les tests « Duel.active or Royale.active ».
static func hero_match() -> bool:
	return Duel.active or Royale.active or TeamMatch.active


## Modes scellés (lot H2, NIVEAU_HEROS §2.3) : le Survivant, le Battle royale et L'Échiquier (autochess, lot AC-E).
## Plus les modes d'équipes de TeamMatch dont la fiche dit sealed (tous par défaut : Colisée, Deux Voies, Assaut ; lot MODE-0).
const SEALED := ["survivor", "royale", "autochess"]


## Mode scellé : le héros ne joue qu'avec sa partie (niveau, cartes et pièces de la run). Rien de la
## progression du compte en combat : ni talents, ni certificats, ni plateau, ni archive, ni auras, ni
## sorts fermés par la maîtrise, ni cartes à débloquer. Classes et apparences débloquées restent permises ;
## les récompenses de fin (maîtrise du Battle royale) aussi. Lu par Run et Player à chaque usage.
static func sealed() -> bool:
	return Survivor.active or Royale.active or AutochessDirector.active or TeamMatch.sealed() or forced in SEALED \
		or TeamMatch.sealed_id(forced)


## Mode où les records, les cartes à débloquer et les succès comptent (règle commune : partout sauf
## l'entraînement).
static func counts_records() -> bool:
	return current() != "training"
