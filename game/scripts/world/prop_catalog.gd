class_name PropCatalog
extends RefCounted
## Décors d'Eden Eternal utilisés par le générateur de maps.
## scale : [min, max]   col : rayon de collision en mètres à l'échelle 1 (0 = aucune)

const TREES := [
	{"model": "ue001", "scale": [0.22, 0.34], "col": 2.2, "weight": 4.0},
	{"model": "ue002", "scale": [0.35, 0.55], "col": 1.6, "weight": 3.0},
	{"model": "ue077", "scale": [0.28, 0.38], "col": 2.0, "weight": 1.5},
	{"model": "ue078", "scale": [0.28, 0.38], "col": 2.0, "weight": 1.5},
	{"model": "ue080", "scale": [0.28, 0.38], "col": 2.0, "weight": 1.5},
	{"model": "ue009", "scale": [0.3, 0.4], "col": 2.4, "weight": 1.0},
	{"model": "ue054", "scale": [0.35, 0.5], "col": 1.6, "weight": 1.0},
	{"model": "ue302", "scale": [0.9, 1.4], "col": 0.5, "weight": 2.0},
	{"model": "ue305", "scale": [1.4, 1.9], "col": 0.3, "weight": 1.0},
	{"model": "ue308_1", "scale": [1.3, 1.8], "col": 0.3, "weight": 1.0},
]

const ROCKS := [
	{"model": "ud001", "scale": [0.25, 0.45], "col": 5.0, "weight": 1.5},
	{"model": "ud002", "scale": [0.3, 0.55], "col": 4.0, "weight": 2.0},
	{"model": "ud003", "scale": [0.3, 0.6], "col": 3.2, "weight": 2.0},
	{"model": "ud004", "scale": [0.25, 0.4], "col": 5.0, "weight": 1.0},
	{"model": "ud005", "scale": [0.3, 0.5], "col": 4.0, "weight": 1.5},
	{"model": "ud006", "scale": [0.3, 0.5], "col": 3.2, "weight": 1.0},
	{"model": "ud313", "scale": [0.9, 1.2], "col": 0.8, "weight": 0.8},
	{"model": "ud314", "scale": [0.9, 1.2], "col": 0.8, "weight": 0.8},
	{"model": "ud311", "scale": [0.8, 1.1], "col": 0.0, "weight": 0.8},
	{"model": "ud038", "scale": [0.8, 1.2], "col": 0.7, "weight": 0.4},
]

## Petites plantes : jamais de collision.
const PLANTS := [
	{"model": "ue701", "scale": [0.4, 0.9], "weight": 3.0},
	{"model": "ue702", "scale": [0.3, 0.6], "weight": 1.0},
	{"model": "ue703", "scale": [0.7, 1.3], "weight": 3.0},
	{"model": "ue703_1", "scale": [0.7, 1.3], "weight": 2.0},
	{"model": "ue705", "scale": [0.8, 1.3], "weight": 1.5},
	{"model": "ue706", "scale": [0.8, 1.3], "weight": 1.5},
	{"model": "ue707", "scale": [1.0, 1.6], "weight": 1.0},
	{"model": "ue708", "scale": [0.8, 1.2], "weight": 1.0},
	{"model": "ue710", "scale": [0.8, 1.3], "weight": 1.5},
	{"model": "ue712", "scale": [0.8, 1.3], "weight": 1.0},
	{"model": "ue715", "scale": [0.9, 1.6], "weight": 1.0},
	{"model": "ue716", "scale": [0.9, 1.6], "weight": 1.0},
	{"model": "ue726", "scale": [0.8, 1.2], "weight": 1.0},
	{"model": "ue728", "scale": [0.8, 1.2], "weight": 0.8},
	{"model": "ue741", "scale": [0.6, 1.0], "weight": 0.6},
	{"model": "ue748", "scale": [0.8, 1.2], "weight": 0.8},
	{"model": "ue749", "scale": [0.8, 1.3], "weight": 1.0},
]

const VILLAGE_HOUSES := ["ua001", "ua002", "ua009", "ua020", "ua031_2", "ua052"]
const VILLAGE_CLUTTER := ["uc003", "uc004", "uc005", "uc006", "uc010", "uc012", "uc013", "uc016", "uc017", "uc314"]


static func pick(list: Array, rng: RandomNumberGenerator) -> Dictionary:
	var total := 0.0
	for p in list:
		total += float(p.get("weight", 1.0))
	var r := rng.randf() * total
	for p in list:
		r -= float(p.get("weight", 1.0))
		if r <= 0.0:
			return p
	return list[-1]
