class_name TowerBalance
extends RefCounted
## Équilibre de la Tour entre classes (passe M8). La Tour se joue seul, sans allié : une classe de soutien ou un tank, dont
## le kit sert aussi à soigner, protéger ou renforcer, y mettait deux à trois fois plus de temps à tuer un boss qu'un mage.
## Leurs dégâts y sont multipliés par un facteur mesuré par classe (data/tower_solo.json : temps pour tuer des boss de
## référence des étages 30, 50 et 100, sans mécaniques, aide « Bot », équipement attendu de l'étage). Jamais de baisse pour
## les classes rapides, au plus MAX_MULT ; le temps pour tuer de la classe, à son pire boss de référence, ramené à 1,1 fois
## la médiane des 60 classes. Seulement dans la Tour elle-même (pas les Donjons, la Ruée ni le Siège, où l'on joue avec des
## alliés), pour le héros du joueur. Régénérer : tools/m8_matrix.py solo (voir conception/nuit_15_10/R_M8.md).

const PATH := "res://data/tower_solo.json"
const MAX_MULT := 1.8

static var _mult := {}
static var _loaded := false


## Multiplicateur de dégâts de la classe [param cid] dans la Tour (1 si la classe n'est pas mesurée).
static func solo_mult(cid: String) -> float:
	if not _loaded:
		_loaded = true
		var raw = JSON.parse_string(FileAccess.get_file_as_string(PATH)) if FileAccess.file_exists(PATH) else null
		if raw is Dictionary:
			_mult = (raw as Dictionary).get("mult", {})
	return clampf(float(_mult.get(cid, 1.0)), 1.0, MAX_MULT)
