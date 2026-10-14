class_name Fortune
extends RefCounted
## Autel de la fortune (lieu de la carte, un par carte, idée du joueur) : une pyramide de
## 8 étages. Étages 1 à 7 : 8, 7, … 2 cases, dont une seule piégée. Une case gagnante :
## encaisser le gain de l'étage, ou monter tenter l'étage suivant (gain plus gros, risque
## plus grand) ; la case piégée arrête la série et fait tout perdre. L'étage 7 franchi, le
## sommet (8e étage) est gagné : une apparence dorée de la collection. Chances d'y arriver :
## 7/8 × 6/7 × … × 1/2 = 1 sur 8.

const FLOORS := 7  # étages à choix ; le 8e est le sommet
## Gain de chaque étage (index 0 : étage 1 ; 7 : sommet) ; chaque gain remplace le précédent.
## gold : × FORTUNE_GOLD ; chests : coffres de récompense (menu Coffres) ; look : apparence.
## insignia : insignes (× 1 + 0,25 par époque au-delà de la 1re) ; chests : coffres d'apparence
## (commun, rare…) ; l'équipement ne sort plus de l'autel (le hasard ne donne jamais de puissance).
const PRIZES := [
	{"gold": 1.0},
	{"gold": 1.5, "keys": 2},
	{"insignia": 15},
	{"insignia": 25},
	{"insignia": 40},
	{"insignia": 60, "chests": ["look_common"]},
	{"insignia": 90, "chests": ["look_rare"]},
	{"insignia": 120, "look": true},
]


## Insignes d'un gain à l'époque [param epoch].
static func insignia_for(n: int, epoch: int) -> int:
	return roundi(n * (1.0 + 0.25 * (maxi(epoch, 1) - 1)))


## Nombre de cases de l'étage [param f] (1 à 7).
static func cells(f: int) -> int:
	return 9 - clampi(f, 1, FLOORS)


static func gold_for(mult: float, level: int) -> int:
	return roundi((60 + 20 * level) * mult)


## Gain de l'étage [param f] (1 à 8) en texte court.
static func prize_text(f: int, level: int) -> String:
	var p: Dictionary = PRIZES[clampi(f, 1, PRIZES.size()) - 1]
	var parts: PackedStringArray = []
	if p.has("gold"):
		parts.append("%d or" % gold_for(float(p.gold), level))
	if p.has("keys"):
		parts.append("%d clés" % int(p["keys"]))
	if p.has("insignia"):
		parts.append("%d insignes" % insignia_for(int(p.insignia), Run.epoch))
	for t in p.get("chests", []):
		parts.append(String(Rewards.TYPES[t].name).to_lower())
	if p.get("look", false):
		parts.append("une apparence dorée")
	return ", ".join(parts)


## Donne le gain de l'étage [param f] ; renvoie le texte de ce qui a été obtenu.
static func give(f: int, level: int, plevel: int) -> String:
	var p: Dictionary = PRIZES[clampi(f, 1, PRIZES.size()) - 1]
	var parts: PackedStringArray = []
	if p.has("gold"):
		var g := gold_for(float(p.gold), level)
		Run.add_gold(g)
		parts.append("%d or" % g)
	if p.has("keys"):
		Profile.keys += int(p["keys"])
		parts.append("%d clés" % int(p["keys"]))
	if p.has("insignia"):
		var n := insignia_for(int(p.insignia), Run.epoch)
		Profile.insignia += n
		Run.fortune_insignia += n
		parts.append("%d insignes" % n)
	for t in p.get("chests", []):
		Profile.reward_chests.append(Rewards.make(String(t), plevel, p.get("boss", false)))
		parts.append(String(Rewards.TYPES[t].name).to_lower())
	if p.get("look", false):
		var x := summit_look()
		if not x.is_empty():
			Profile.collect(x)
			parts.append("l'apparence « %s »" % String(x.name))
		else:
			Profile.reward_chests.append(Rewards.make("gear", plevel, true))  # toute la collection : un coffre en plus
			parts.append("un coffre d'équipement de boss")
	Profile.changed.emit()
	Profile.save_profile()
	return ", ".join(parts)


## Apparence du sommet : une apparence portable pas encore obtenue, dorée si possible.
static func summit_look() -> Dictionary:
	var pool := GameData.collection.filter(func(x): return int(x.get("cat", 0)) <= 3 \
		and GameData.cosmetic_by_code.has(String(x.get("code", ""))) and not Profile.collected(x) \
		and not String(x.get("name", "")).contains("(Alpha)"))
	var gold := pool.filter(func(x): return String(x.name).to_lower().contains("gold"))
	var pick: Array = gold if not gold.is_empty() else pool
	return pick.pick_random() if not pick.is_empty() else {}
