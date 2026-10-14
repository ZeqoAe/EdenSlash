class_name Modes
extends RefCounted
## Mode de jeu en cours (conception, lot 4) : une seule source, lue par les règles (ModeRules), le
## journal de run et, peu à peu, par les tests dispersés `Tower.active` / `Duel.active` /
## `Training.active`. Ces drapeaux restent les vrais interrupteurs (le mode est déduit d'eux) : rien
## ne peut donc se désynchroniser. Modes : menu, survival (Survie), run (ancienne run de farm),
## tower, duel, training. Plus tard : dungeon, challenge, arena.

## Mode imposé (essais d'équilibrage, tests) : prioritaire sur les drapeaux.
static var forced := ""


static func current() -> String:
	if forced != "":
		return forced
	if Duel.active:
		return "duel"
	if Tower.active:
		return "dungeon" if Tower.is_dungeon() else "tower"
	if Training.active:
		return "training"
	if Run.active:
		return "survival" if Run.survival else "run"
	return "menu"


## Combat entre héros (règles JcJ de PvpCaps).
static func is_pvp() -> bool:
	return current() == "duel"


## Mode où les records, les cartes à débloquer et les succès comptent (règle commune : partout sauf
## l'entraînement).
static func counts_records() -> bool:
	return current() != "training"
