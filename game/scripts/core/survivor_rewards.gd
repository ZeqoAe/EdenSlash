class_name SurvivorRewards
extends RefCounted
## Fin d'un Survivant (lot S6, DECISIONS_JOUEUR §5) : seulement des coffres d'apparence (selon l'avancée : boss atteint,
## victoire, palier), des titres et le Codex du mode ; jamais de puissance ni de monnaie de progression.
##
## Lot S1 : squelette (rien n'est donné). Appelé par Survivor.finish APRÈS la remise du hub : ce qui est donné ici
## est gardé.


## Récompenses de la run terminée sur [param res] (victoire, defaite, abandon).
static func settle(_res: String, _counted_kills: int) -> void:
	pass


## Champs propres au Survivant ajoutés à la ligne du journal de run.
static func journal() -> Dictionary:
	return {"sv_zone": Survivor.zone_id, "palier": Survivor.palier}
