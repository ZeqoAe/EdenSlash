class_name Modes
extends RefCounted
## Mode de jeu en cours (conception, lot 4) : une seule source, lue par les règles (ModeRules), le
## journal de run et, peu à peu, par les tests dispersés `Tower.active` / `Duel.active` /
## `Training.active`. Ces drapeaux restent les vrais interrupteurs (le mode est déduit d'eux) : rien
## ne peut donc se désynchroniser. Modes : menu, survival (Survie), survivor (Survivant), run (ancienne
## run de farm), tower, dungeon, duel, royale, training.

## Mode imposé (essais d'équilibrage, tests) : prioritaire sur les drapeaux.
static var forced := ""


static func current() -> String:
	if forced != "":
		return forced
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


## Combat entre héros (règles JcJ de PvpCaps) : le Duel et le Battle royale.
static func is_pvp() -> bool:
	return current() in ["duel", "royale"] or Siege.ffa  # + le chacun pour soi du Siège


## Modes scellés (lot H2, NIVEAU_HEROS §2.3) : le Survivant et le Battle royale.
const SEALED := ["survivor", "royale"]


## Mode scellé : le héros ne joue qu'avec sa partie (niveau, cartes et pièces de la run). Rien de la
## progression du compte en combat : ni talents, ni certificats, ni plateau, ni archive, ni auras, ni
## sorts fermés par la maîtrise, ni cartes à débloquer. Classes et apparences débloquées restent permises ;
## les récompenses de fin (maîtrise du Battle royale) aussi. Lu par Run et Player à chaque usage.
static func sealed() -> bool:
	return Survivor.active or Royale.active or forced in SEALED


## Mode où les records, les cartes à débloquer et les succès comptent (règle commune : partout sauf
## l'entraînement).
static func counts_records() -> bool:
	return current() != "training"
