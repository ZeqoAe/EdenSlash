class_name AutochessPlanner
extends RefCounted
## L'Échiquier, lot ACX-3 (étude BM-AUTO §6 n° 18) : le planificateur « Mes héros visés ». Jusqu'à MAX héros marqués (touche
## T, clic du stick droit, ou la ligne « Viser » de la fiche) : leurs cartes de boutique portent une cible fraise. La liste
## est gardée entre les parties (Settings, section « autochess », clé « planned ») : c'est une aide du joueur, pas une règle
## du jeu (les IA n'en savent rien).

const MAX := 10


## Héros visés (ids d'unités), dans l'ordre où ils ont été marqués.
static func planned() -> Array:
	var v: Variant = Settings.get_v("autochess", "planned")
	return (v as Array).duplicate() if v is Array else []


static func is_planned(id: String) -> bool:
	return id in planned()


## Marque ou retire [param id] ; renvoie l'état atteint (vrai : visé). Refusé au-delà de MAX (reste faux).
static func toggle(id: String) -> bool:
	if AutochessData.unit(id).is_empty():
		return false
	var l := planned()
	if id in l:
		l.erase(id)
		Settings.set_v("autochess", "planned", l)
		return false
	if l.size() >= MAX:
		return false
	l.append(id)
	Settings.set_v("autochess", "planned", l)
	return true


static func clear() -> void:
	Settings.set_v("autochess", "planned", [])
