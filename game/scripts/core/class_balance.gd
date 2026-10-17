class_name ClassBalance
extends RefCounted
## Équilibre des classes face aux boss de l'Aventure (lot CLS-1, conception/progression/R_CLS1.md). Quelques classes de
## base avaient des stats de départ sous celles de leur propre famille sans rien en échange (le Chasseur : PV ×0,85, attaque
## ×0,95, aucune défense de base, quand les 11 autres tireurs ont PV ≥ 1, attaque 1 et défense 3) : elles mouraient deux fois
## plus souvent au boss de la 1re carte. Leurs stats de base de l'Aventure sont relevées au plancher de leur famille
## (data/class_balance.json, clé « adventure » : mêmes clés que la « base » de data/classes.json, qui l'emportent sur elle).
## Les PV et l'attaque de base ne comptent presque plus aux époques III-IV (l'équipement domine) : une classe dont le kit est en
## retard face aux boss à tout niveau reçoit plutôt un multiplicateur de PV ou de dégâts (`hp_mult`, `dmg_mult`, comme
## TowerBalance dans la Tour), mesuré par tools/boss_ttk.py, jamais une baisse, au plus MAX_MULT.
## Seulement en Aventure (`Epochs.adventure()`), pour le héros du joueur : ni le duel ni les arènes (JcJ, réglés à part),
## ni les modes scellés (Survivant, Battle royale, Échiquier), ni la Tour (TowerBalance), ni les fiches d'IA (ClassRival,
## arène d'apprentissage : les cerveaux sont entraînés sur data/classes.json) ne changent.

const PATH := "res://data/class_balance.json"
## Clés de la base d'une classe qu'un réglage peut changer (PV, défense, attaques, critique, vitesses).
const KEYS := ["hp", "def", "atk", "matk", "crit", "atk_speed", "move_speed"]
## Multiplicateurs de l'Aventure (PV max, dégâts) : entre 1 et MAX_MULT.
const MULT_KEYS := ["hp_mult", "dmg_mult"]
const MAX_MULT := 1.5

static var _adv := {}
static var _loaded := false


static func _table() -> Dictionary:
	if not _loaded:
		_loaded = true
		var raw = JSON.parse_string(FileAccess.get_file_as_string(PATH)) if FileAccess.file_exists(PATH) else null
		if raw is Dictionary:
			_adv = (raw as Dictionary).get("adventure", {})
	return _adv


## Réglage de l'Aventure de la classe [param cid] ({} : aucun) : clé de KEYS -> valeur de base.
static func adventure(cid: String) -> Dictionary:
	var out := {}
	var row: Dictionary = _table().get(cid, {})
	for k in KEYS:
		if row.has(k):
			out[k] = float(row[k])
	return out


## Multiplicateur [param key] (MULT_KEYS) de la classe [param cid] en Aventure (1 : aucun).
static func mult(cid: String, key: String) -> float:
	return clampf(float(_table().get(cid, {}).get(key, 1.0)), 1.0, MAX_MULT)


## Base de la classe [param cid] en Aventure : [param base] (data/classes.json) avec le réglage par-dessus.
static func adventure_base(cid: String, base: Dictionary) -> Dictionary:
	var adj := adventure(cid)
	if adj.is_empty():
		return base
	var out := base.duplicate()
	out.merge(adj, true)
	return out
