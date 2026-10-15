class_name SurvivorDirector
extends RefCounted
## Déroulement d'un Survivant (lot S4, SPEC §1, §6, §8.2-8.3) : 20 minutes sur une seule carte, courbes de monstres,
## gardiens à 5 / 10 / 15 min, portail du boss à 15:00, boss forcé à 20:00, coffres du Survivant, lieux propres.
## Créé par RunDirector.start quand Survivor.active (variable `sv` du directeur).
##
## Lot S1 : squelette. Chaque méthode qui REMPLACE un comportement de la Survie renvoie vrai si elle l'a pris en charge
## (faux : le directeur fait comme en Survie) ; les autres ne font rien. Seules différences déjà actives : pas de rage de
## carte (crochet du directeur), une seule carte (le boss vaincu termine la run) et le message d'ouverture.

var d: RunDirector


func _init(director: RunDirector) -> void:
	d = director


## Message d'ouverture de la carte ("" : celui de la Survie).
func start_message() -> String:
	return "%s · Survivant\nMonte de niveau : arme, pièces et sorts se gagnent aux cartes" % String(d.zone.get("name", ""))


## Chaque image, en exploration comme dans l'arène (gardiens, portail, horde finale : S4).
func update(_delta: float) -> void:
	pass


## Apparition des monstres de la carte ; faux : celle de la Survie.
func update_spawns(_delta: float) -> bool:
	return false


## Ligne d'objectif en exploration ("" : celle de la Survie).
func objective_text() -> String:
	return ""


## Niveau des monstres (0 : celui de la Survie).
func monster_level(_tier: int) -> int:
	return 0


## Niveau maximal des monstres et du butin (0 : celui de la Survie).
func max_level() -> int:
	return 0


## PV et dégâts d'un monstre qui apparaît ; faux : multiplicateurs de la Survie (zone, époque, montée du début).
func scale_monster(_m: Monster, _boss: bool) -> bool:
	return false


## Monstre vaincu (après l'or) ; vrai : le butin de la Survie (coffres de récompense, fournitures, armes
## secondaires, sceaux) n'est pas donné.
func on_monster_died(_m: Monster) -> bool:
	return false


## Entrée du donjon ; vrai : prise en charge (portail du boss sans sceau, S4).
func try_enter_boss() -> bool:
	return false


## Coffre de la carte ouvert (type [param box]) ; vrai : prise en charge (coffres du Survivant, S4).
func open_chest(_box: String) -> bool:
	return false


## Lieu utilisé (enclume, stèle…) ; vrai : prise en charge.
func use_station(_it: Interactable) -> bool:
	return false


## Sanctuaire capturé ; vrai : prise en charge.
func capture(_sh: Shrine) -> bool:
	return false


## Boss créé à l'entrée de l'arène (PV fixes, palier, Menace : S4).
func setup_boss(_boss: Monster) -> void:
	pass


## Début de la rage du boss en secondes (< 0 : celui de la Survie).
func boss_rage_at() -> float:
	return -1.0


## Boss vaincu : une seule carte, la run est gagnée (bilan après 6 s, en pause pendant un choix de carte).
func on_boss_killed() -> bool:
	d.state = "cleared"
	d.message.emit("Boss vaincu !\nTu as survécu", 4.0)
	_finish_later()
	return true


func _finish_later() -> void:
	await d.get_tree().create_timer(6.0, false).timeout
	if is_instance_valid(d):
		d.boss_defeated.emit()


## Disposition des coffres de la carte (ProcMap) : types [param boxes] et apparences [param tiers] modifiés sur place
## (coffres du Survivant, SPEC §6.2, lot S4) ; S1 garde ceux de la Survie.
static func layout_map(_boxes: Array, _tiers: Array, _rng: RandomNumberGenerator) -> void:
	pass
