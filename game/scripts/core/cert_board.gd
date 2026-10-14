class_name CertBoard
extends RefCounted
## Plateau des certificats de maîtrise : 7 emplacements en colonnes 1-2-1-2-1.
##
##        [1]     [4]
##   [0]       [3]       [6]
##        [2]     [5]
##
## Chaque certificat a une couleur (orange : puissance, jaune : vigueur, bleu :
## précision). Bonus de placement :
## - deux certificats de même couleur reliés : petit bonus (par lien) ;
## - un triangle de trois couleurs différentes : bonus « Prisme » ;
## - quatre de même couleur en losange : gros bonus.
## Les emplacements s'ouvrent avec la maîtrise cumulée, du centre vers les bords.

## Position (colonne, ligne) de chaque emplacement, pour l'affichage.
const POS := [Vector2(0, 0.5), Vector2(1, 0), Vector2(1, 1), Vector2(2, 0.5), Vector2(3, 0), Vector2(3, 1), Vector2(4, 0.5)]
## Ordre d'ouverture des emplacements.
const OPEN_ORDER := [3, 1, 2, 0, 4, 5, 6]
const LINKS := [[0, 1], [0, 2], [1, 2], [1, 3], [2, 3], [3, 4], [3, 5], [4, 5], [4, 6], [5, 6]]
const TRIANGLES := [[0, 1, 2], [1, 2, 3], [3, 4, 5], [4, 5, 6]]
const DIAMONDS := [[0, 1, 2, 3], [3, 4, 5, 6]]

const COLORS := {
	"orange": {"name": "Puissance", "color": Color(1.0, 0.56, 0.18)},
	"yellow": {"name": "Vigueur", "color": Color(1.0, 0.86, 0.3)},
	"blue": {"name": "Précision", "color": Color(0.4, 0.72, 1.0)},
}
## Couleur d'un certificat selon la statistique de son passif : attaque et dégâts = orange,
## PV, défense et soins = jaune, tout le reste (critique, vitesses, esquive, zone, portée…) = bleu.
const STAT_COLOR := {
	"atk_pct": "orange", "dmg_pct": "orange", "crit_dmg": "orange",
	"hp_pct": "yellow", "def_pct": "yellow", "heal_pct": "yellow", "lifesteal": "yellow",
}
const PAIR := {
	"orange": {"dmg_pct": 0.03},
	"yellow": {"hp_pct": 0.04},
	"blue": {"crit": 0.015},
}
const DIAMOND := {
	"orange": {"name": "Losange de puissance", "stat": {"dmg_pct": 0.08, "crit_dmg": 0.2}},
	"yellow": {"name": "Losange de vigueur", "stat": {"hp_pct": 0.1, "def_pct": 0.1, "lifesteal": 0.02}},
	"blue": {"name": "Losange de précision", "stat": {"crit": 0.05, "area": 0.1, "reach": 0.1}},
}
const PRISM := {"name": "Prisme", "stat": {"dmg_pct": 0.03, "hp_pct": 0.03, "cdr": 0.03}}


static func color_of(key: String) -> String:
	var p := key.split("/")
	if p.size() < 2:
		return "blue"
	for pp in GameData.class_data(p[0]).get("passives", []):
		if String(pp.id) == p[1]:
			for s in pp.get("stat", {}):
				return String(STAT_COLOR.get(s, "blue"))
	return "blue"


## Les certificats d'une même lignée (parent et enfants) portent le même passif : un passif ne
## se pose qu'une fois sur le plateau. Identifiant du passif de [param key] ("classe/passif").
static func passive_id(key: String) -> String:
	var p := key.split("/")
	return p[p.size() - 1]


static func color_value(key: String) -> Color:
	return COLORS[color_of(key)].color


## Emplacement [param pos] ouvert avec [param slots] emplacements disponibles ?
static func is_open(pos: int, slots: int) -> bool:
	return OPEN_ORDER.find(pos) < slots


## Bonus actifs du plateau : [{name, color, stat}].
static func synergies(board: Array) -> Array:
	var out: Array = []
	var col := func(i: int) -> String:
		return color_of(String(board[i])) if i < board.size() and String(board[i]) != "" else ""
	var pairs := {}
	for l in LINKS:
		var a: String = col.call(l[0])
		if a != "" and a == col.call(l[1]):
			pairs[a] = int(pairs.get(a, 0)) + 1
	for c in pairs:
		var st := {}
		for s in PAIR[c]:
			st[s] = float(PAIR[c][s]) * int(pairs[c])
		out.append({"name": "%s reliés ×%d" % [COLORS[c].name, int(pairs[c])], "color": c, "stat": st})
	for t in TRIANGLES:
		var cs := [col.call(t[0]), col.call(t[1]), col.call(t[2])]
		if not "" in cs and cs[0] != cs[1] and cs[1] != cs[2] and cs[0] != cs[2]:
			out.append({"name": PRISM.name, "color": "", "stat": PRISM.stat})
	for d in DIAMONDS:
		var c: String = col.call(d[0])
		if c != "" and d.all(func(i): return col.call(i) == c):
			out.append({"name": DIAMOND[c].name, "color": c, "stat": DIAMOND[c].stat})
	return out


## Somme des bonus de placement.
static func stats(board: Array) -> Dictionary:
	var total := {}
	for s in synergies(board):
		for k in s.stat:
			total[k] = float(total.get(k, 0.0)) + float(s.stat[k])
	return total


static func stat_text(st: Dictionary) -> String:
	var parts: PackedStringArray = []
	for k in st:
		parts.append(Items.stat_text(k, st[k]))
	return ", ".join(parts)


## Règles affichées sous le plateau.
static func rules_bbcode() -> String:
	var lines: PackedStringArray = []
	for c in COLORS:
		lines.append("[color=#%s]■ %s[/color] : 2 reliés %s · losange de 4 : %s" % [Color(COLORS[c].color).to_html(false), COLORS[c].name,
			stat_text(PAIR[c]), stat_text(DIAMOND[c].stat)])
	lines.append("[color=#e6d7ff]◆ Prisme[/color] (triangle de 3 couleurs différentes) : %s" % stat_text(PRISM.stat))
	return "\n".join(lines)
