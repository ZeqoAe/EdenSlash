class_name BotInput
extends RefCounted
## Commandes d'une IA en apprentissage (arène ML, voir MlArena) à la place du clavier et de
## la souris : le héros lit [member move], [member aim] et les touches appuyées.

var move := Vector3.ZERO  # direction de marche (repère du monde, horizontale)
var aim := Vector3.INF  # point visé par les coups et les sorts
var hold := {}  # action -> maintenue pendant toute la décision (attaque)
var pulse := {}  # action -> appuyée à la première image de la décision seulement


func wants(action: String) -> bool:
	return bool(pulse.get(action, false)) or bool(hold.get(action, false))


func clear() -> void:
	move = Vector3.ZERO
	aim = Vector3.INF
	hold.clear()
	pulse.clear()
