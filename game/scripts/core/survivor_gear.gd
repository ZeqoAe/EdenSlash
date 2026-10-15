class_name SurvivorGear
extends RefCounted
## Pièces et arme du Survivant (lot S2, DECISIONS_JOUEUR §1-§2 qui priment sur SPEC §3-§4) : pièces des sets de niveau
## 90, stats d'origine adaptées au niveau de la run (Items.power_level, champ `sv`), qualité 100 à 120 %, passif fixe
## par pièce puis trois passifs tirés aux paliers +6 / +8 / +10, arme de n'importe quel type, gardée à vie.
##
## Lot S1 : squelette. Les pièces sont posées dans Profile.equipped SANS Profile.equip (ni préréglage, ni coffre du
## hub) : la fin de run remet l'équipement du hub.


## Nouvelle pièce pour l'emplacement [param slot] ({} : aucune).
static func make_piece(_slot: String, _ctx := {}) -> Dictionary:
	return {}


## Nouvelle arme du type [param wtype] ({} : aucune).
static func make_weapon(_wtype: String, _ctx := {}) -> Dictionary:
	return {}


## Porte [param item] pour toute la run (emplacement verrouillé).
static func equip(item: Dictionary) -> void:
	if item.is_empty():
		return
	item["sv"] = true
	Profile.equipped[String(item.get("slot", ""))] = item
	Profile.changed.emit()


## Emplacements encore libres (Items.SLOTS).
static func free_slots() -> Array:
	return Items.SLOTS.filter(func(s): return not Profile.equipped.has(s))


## Pièces portées.
static func worn() -> Array:
	return Profile.equipped.values()


## Amélioration de la pièce de [param slot] par une carte de rareté [param tier] : {text, woke}.
static func upgrade(_slot: String, _tier: String) -> Dictionary:
	return {"text": "", "woke": 0}


## Passifs gagnés par [param item] au +N atteint (paliers WAKE_AT) ; renvoie le nombre de nouveaux.
static func wake(_item: Dictionary) -> int:
	return 0


## Plafond de puissance du passif [param id] (en cartes communes).
static func boon_cap(_id: String) -> float:
	return 0.0


## Qualité maximale (jet parfait).
static func is_perfect(item: Dictionary) -> bool:
	return float(item.get("quality", 1.0)) >= Survivor.rule("perfect_quality") - 0.0001
