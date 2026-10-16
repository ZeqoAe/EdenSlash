class_name AutochessPool
extends RefCounted
## L'Échiquier (lot AC-B) : réserve partagée des 8 stratèges (SPEC §6). Un compteur de copies restantes par unité.
## Tirage d'une case de boutique : coût tiré selon le niveau (AutochessData.SHOP_ODDS, renormalisé sur les coûts qui ont encore
## des copies), puis unité tirée au poids de ses copies restantes. Les copies tirées sont « tenues » par celui qui les a
## (boutique, banc, plateau, choix partagé) et reviennent par give() : invariant testé par Autochess.pool_ok().
## Aucun hasard propre : le générateur est celui de la partie (même graine = mêmes tirages).

var counts: Dictionary = {}  # id d'unité -> copies restantes
var _by_cost: Dictionary = {}  # coût -> [ids], ordre du fichier des unités (déterministe)


func _init() -> void:
	reset()


## Réserve pleine (début de partie).
func reset() -> void:
	counts.clear()
	_by_cost.clear()
	for id in AutochessData.unit_ids():
		counts[id] = total(id)
		var c := cost_of(id)
		if not _by_cost.has(c):
			_by_cost[c] = []
		(_by_cost[c] as Array).append(id)


static func cost_of(id: String) -> int:
	return int(AutochessData.unit(id).get("cost", 1))


## Copies d'une unité dans une réserve pleine.
static func total(id: String) -> int:
	return int(AutochessData.POOL_COPIES.get(cost_of(id), 0))


func remaining(id: String) -> int:
	return int(counts.get(id, 0))


func remaining_of_cost(cost: int) -> int:
	var n := 0
	for id in _by_cost.get(cost, []):
		n += int(counts[id])
	return n


func ids_of_cost(cost: int) -> Array:
	return (_by_cost.get(cost, []) as Array).duplicate()


## Retire jusqu'à [param n] copies ; renvoie le nombre réellement retiré.
func take(id: String, n := 1) -> int:
	var got := mini(maxi(n, 0), remaining(id))
	if got > 0:
		counts[id] = remaining(id) - got
	return got


## Rend [param n] copies (jamais au-delà du total).
func give(id: String, n := 1) -> void:
	if id == "" or n <= 0 or not counts.has(id):
		return
	counts[id] = mini(remaining(id) + n, total(id))


## Coût d'une case de boutique au niveau [param level] ; 0 si la réserve est vide.
func roll_cost(level: int, rng: RandomNumberGenerator) -> int:
	var odds: Array = AutochessData.shop_odds(level)
	var w: Array = []
	var sum := 0
	for i in odds.size():
		var wi := int(odds[i]) if remaining_of_cost(i + 1) > 0 else 0
		w.append(wi)
		sum += wi
	if sum <= 0:  # plus rien aux taux de ce niveau : n'importe quel coût qui reste
		for i in odds.size():
			w[i] = 1 if remaining_of_cost(i + 1) > 0 else 0
			sum += int(w[i])
		if sum <= 0:
			return 0
	var r := rng.randi_range(1, sum)
	for i in w.size():
		r -= int(w[i])
		if r <= 0:
			return i + 1
	return 0


## Tire une unité de coût [param cost] au poids des copies restantes et la retire ("" si aucune). [param among] : liste
## d'ids permise (vide = toutes celles du coût).
func draw(cost: int, rng: RandomNumberGenerator, among: Array = []) -> String:
	var ids: Array = _by_cost.get(cost, []) if among.is_empty() else among
	var sum := 0
	for id in ids:
		sum += remaining(id)
	if sum <= 0:
		return ""
	var r := rng.randi_range(1, sum)
	for id in ids:
		r -= remaining(id)
		if r <= 0:
			take(id)
			return String(id)
	return ""


## Boutique de [param size] cases au niveau [param level] ; chaque case tient une copie ("" : réserve vide).
func roll_shop(level: int, rng: RandomNumberGenerator, size := AutochessData.SHOP_SIZE) -> Array:
	var out: Array = []
	for _i in size:
		var c := roll_cost(level, rng)
		out.append("" if c == 0 else draw(c, rng))
	return out


func to_dict() -> Dictionary:
	return counts.duplicate()


func from_dict(d: Dictionary) -> void:
	reset()
	for id in d:
		if counts.has(id):
			counts[id] = clampi(int(d[id]), 0, total(id))
