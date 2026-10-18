class_name AssaultResults
extends ResultsPanel
## L'Assaut, lot TAC-8 : le bilan de fin de partie (TACTIQUE § 7.8, croquis tactique_maquettes/v2_bilan.svg), par le
## composant commun des bilans (ResultsPanel, DA v2) : « Victoire ! », « 7 contre 4 », cinq tuiles (tes K.O., tes dégâts, tes
## poses, tes désamorçages, l'or gagné), la FRISE DES MANCHES (couleur de l'équipe gagnante, symbole de la façon : ✕
## élimination, éclat la Charge, pinces le désamorçage, sablier le temps ; trait de la mi-temps), le TABLEAU DES 8 (ton équipe
## et les adversaires : K.O., morts, aides, dégâts, poses / désamorçages ; « ★ Meilleur héros »), « Gagné » (coffres
## d'apparence, titres : AssaultRewards.last), la ligne « Ta quête », Rejouer et Menu principal. Mode scellé : rien d'autre.

const ROW_H := 26.0

var info: Dictionary = {}
var frieze: Control  # (tests)
var board: Control  # (tests)
var mvp := ""  # clé du meilleur héros de la partie (tests)


## Note d'un héros pour « Meilleur héros » : éliminations, aides, poses, désamorçages, et ses dégâts comptés en PV de héros.
static func rating(h: Dictionary, hp := 13000.0) -> float:
	return int(h.kills) * 100.0 + int(h.assists) * 40.0 + int(h.plants) * 80.0 + int(h.defuses) * 120.0 + float(h.dmg) / maxf(hp, 1.0) * 100.0 \
		- int(h.deaths) * 20.0


static func best_of(heroes: Array) -> String:
	var best := ""
	var bs := -INF
	for h in heroes:
		var r := rating(h)
		if r > bs:
			bs = r
			best = String(h.key)
	return best


## [param i] : AssaultDirector.match_info ; [param got] : AssaultRewards.last ; [param calls] : {replay, back} (Callable).
func show_results(i: Dictionary, got: Dictionary, calls: Dictionary) -> void:
	info = i
	var won := bool(i.get("won", false))
	var forfeit := bool(i.get("forfeit", false))
	var me := TeamMatch.player_team
	var sc: Array = i.get("score", [0, 0])
	var my: Dictionary = {}
	for h in i.get("heroes", []):
		if bool(h.get("me", false)):
			my = h
	mvp = best_of(i.get("heroes", []))
	var fmt := "Éclair" if String(i.get("format", "")) == "eclair" else "Classique"
	var sub := "%d contre %d · %s · %s · %s" % [int(sc[me]), int(sc[1 - me]), String(i.get("map_name", "")), fmt,
		AssaultRewards.diff_name(int(i.get("diff_foes", 1)))]
	var tiles: Array = [
		[str(int(my.get("kills", 0))), "K.O.", "Tes éliminations ; aides : %d" % int(my.get("assists", 0)), String(my.get("key", "")) == mvp],
		[number(float(my.get("dmg", 0.0))), "dégâts", "Dégâts donnés aux adversaires sur toute la partie"],
		[str(int(my.get("plants", 0))), "poses", "Charges posées"],
		[str(int(my.get("defuses", 0))), "désamorçages", "Charges désamorcées"],
		[number(float(my.get("gold", 0))), "or gagné", "Or de manche gagné sur toute la partie (victoires, primes, éliminations, poses)"],
	]
	var gained: Array = []
	var looks := 0
	for c in got.get("chests", []):
		var t: Dictionary = Rewards.TYPES.get(String(c.type), {})
		gained.append(row(String(t.get("name", "Coffre d'apparence")), "", String(c.text), "chest"))
		looks += 1
	for t in got.get("titles", []):
		gained.append(row("Titre « %s »" % String(t.title), "nouveau" if bool(t.get("new", false)) else "", String(t.text), "user"))
	var foot := ""
	if forfeit:
		foot = "Abandon : aucune récompense."
	elif gained.is_empty():
		foot = "Une victoire donne un coffre d'apparence : la première à chaque difficulté, puis %d par jour." % AssaultRewards.DAILY_CAP
	show_spec({
		"title": "VICTOIRE !" if won else ("ABANDON" if forfeit else "DÉFAITE"),
		"tone": "win" if won else "lose",
		"subtitle": sub,
		"tiles": tiles,
		"gained": gained,
		"footnote": foot,
		"quest": Compass.after("assault", {"looks": looks, "titles": (got.get("titles", []) as Array).size()}),
		"buttons": [
			{"text": "Rejouer", "primary": true, "call": calls.get("replay", Callable())},
			{"text": "Menu principal", "call": calls.get("back", Callable())},
		],
	})
	_add_blocks()


## Frise et tableau, juste sous les tuiles.
func _add_blocks() -> void:
	var at := -1
	for c in _body.get_children():
		if c is HBoxContainer:
			at = c.get_index()
			break
	frieze = Frieze.new()
	frieze.name = "AssaultFrieze"
	frieze.history = info.get("history", [])
	frieze.half = int(info.get("half", 6))
	frieze.max_rounds = int(info.get("max_rounds", 12))
	for hh in info.get("heroes", []):
		if String(hh.key) == mvp:
			frieze.mvp_name = ("Toi" if bool(hh.get("me", false)) else String(hh.name)) + ("" if int(hh.team) == TeamMatch.player_team or bool(hh.get("me", false)) else " (adversaire)")
	frieze.custom_minimum_size = Vector2(0, 56)
	_body.add_child(frieze)
	board = Board.new()
	board.name = "AssaultBoard"
	board.heroes = info.get("heroes", [])
	board.mvp = mvp
	board.custom_minimum_size = Vector2(0, 30.0 + ROW_H * 4.0 + 12.0)
	_body.add_child(board)
	if at >= 0:
		_body.move_child(frieze, at + 1)
		_body.move_child(board, at + 2)
	_appear(frieze, 0.25)
	_appear(board, 0.35)


## Frise des manches : une pastille par manche à la couleur de l'équipe gagnante, symbole de la façon de gagner, trait de la
## mi-temps (et de la prolongation) ; dessous, « Attaque » / « Défense » de ton équipe à chaque moitié.
class Frieze extends Control:
	var history: Array = []
	var half := 6
	var max_rounds := 12
	var mvp_name := ""
	const CELL := 30.0
	const GAP := 6.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_PASS
		tooltip_text = "Frise des manches : la croix, une élimination ; l'éclat, la Charge ; les pinces, un désamorçage ; le sablier, le temps"

	func _draw() -> void:
		var n := history.size()
		if n == 0:
			return
		var seps := 0
		for i in range(1, n):
			if int(history[i].half) != int(history[i - 1].half):
				seps += 1
		var w := n * CELL + (n - 1) * GAP + seps * 14.0
		var x := (size.x - w) * 0.5
		var me := TeamMatch.player_team
		var y := 2.0
		for i in n:
			var e: Dictionary = history[i]
			if i > 0 and int(e.half) != int(history[i - 1].half):
				var sx := x + 4.0 - GAP * 0.5
				draw_line(Vector2(sx, y - 2.0), Vector2(sx, y + CELL + 2.0), RoyaleHudStyle.INK, 3.0)
				x += 14.0
			var r := Rect2(x, y, CELL, CELL)
			var w_team := int(e.winner)
			RoyaleHudStyle.draw_sticker(self, r, TeamMatch.color(w_team, "base"), 9.0, 3.0, 2.5)
			_symbol(r.get_center(), String(e.how))
			if w_team == me:
				draw_circle(r.position + Vector2(CELL - 2.0, 2.0), 4.0, RoyaleHudStyle.INK)
				draw_circle(r.position + Vector2(CELL - 2.0, 2.0), 2.6, RoyaleHudStyle.SUN[0])
			x += CELL + GAP
		var f := RoyaleHudStyle.text_font()
		var legend := "Point soleil : manche de ton équipe · trait : mi-temps"
		if mvp_name != "":
			legend += " · ★ Meilleur héros : " + mvp_name
		draw_string(f, Vector2(0, y + CELL + 20.0), legend, HORIZONTAL_ALIGNMENT_CENTER, size.x, 15, RoyaleHudStyle.INK_300)

	func _symbol(c: Vector2, how: String) -> void:
		var ink := RoyaleHudStyle.INK
		var wh := RoyaleHudStyle.WHITE
		match how:
			"elim":
				for s in [1.0, -1.0]:
					draw_line(c + Vector2(-7, -7 * s), c + Vector2(7, 7 * s), ink, 6.0, true)
				for s in [1.0, -1.0]:
					draw_line(c + Vector2(-7, -7 * s), c + Vector2(7, 7 * s), wh, 3.0, true)
			"charge":
				var pts := PackedVector2Array()
				for i in 16:
					var a := TAU * i / 16.0
					pts.append(c + Vector2(cos(a), sin(a)) * (9.0 if i % 2 == 0 else 4.5))
				RoyaleHudStyle.draw_inked_polygon(self, pts, RoyaleHudStyle.SUN[0], 1.5)
			"defuse":
				# pinces : deux branches qui se croisent et une mèche coupée
				draw_line(c + Vector2(-7, 7), c + Vector2(5, -6), ink, 6.0, true)
				draw_line(c + Vector2(7, 7), c + Vector2(-5, -6), ink, 6.0, true)
				draw_line(c + Vector2(-7, 7), c + Vector2(5, -6), wh, 3.0, true)
				draw_line(c + Vector2(7, 7), c + Vector2(-5, -6), wh, 3.0, true)
				draw_circle(c + Vector2(0, -1), 2.5, ink)
			"time":
				var top := PackedVector2Array([c + Vector2(-6, -8), c + Vector2(6, -8), c + Vector2(0, 0)])
				var bot := PackedVector2Array([c + Vector2(-6, 8), c + Vector2(6, 8), c + Vector2(0, 0)])
				RoyaleHudStyle.draw_inked_polygon(self, top, wh, 1.5)
				RoyaleHudStyle.draw_inked_polygon(self, bot, wh, 1.5)


## Tableau des 8 : ton équipe à gauche, les adversaires à droite ; K.O., morts, aides, dégâts, poses / désamorçages ;
## une étoile soleil devant le meilleur héros (nommé sous la frise). Toi en soleil.
class Board extends Control:
	var heroes: Array = []
	var mvp := ""
	const COLS := [["K.O.", "kills"], ["Morts", "deaths"], ["Aides", "assists"], ["Dégâts", "dmg"], ["Charges", "pd"]]
	const COL_W := [38.0, 46.0, 42.0, 62.0, 78.0]

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var me := TeamMatch.player_team
		var gap := 14.0
		var w := (size.x - gap) * 0.5
		for side in 2:
			var t := me if side == 0 else 1 - me
			var r := Rect2(side * (w + gap), 0, w, size.y - 4.0)
			RoyaleHudStyle.draw_sticker(self, r, RoyaleHudStyle.WELL, 14.0, 3.0)
			var f := RoyaleHudStyle.text_font()
			var nf := RoyaleHudStyle.num_font()
			# en-tête : point de l'équipe, son nom, colonnes
			draw_circle(r.position + Vector2(18, 16), 7.0, RoyaleHudStyle.INK)
			draw_circle(r.position + Vector2(18, 16), 5.5, TeamMatch.color(t, "base"))
			RoyaleHudStyle.draw_text(self, r.position + Vector2(30, 22), "Ton équipe" if t == me else "Adversaires", 16, RoyaleHudStyle.PAPER, f)
			var x := r.end.x - 10.0
			var xs: Array = []
			for ci in range(COLS.size() - 1, -1, -1):
				x -= float(COL_W[ci])
				xs.push_front(x)
			for ci in COLS.size():
				draw_string(f, Vector2(float(xs[ci]), r.position.y + 21.0), String(COLS[ci][0]), HORIZONTAL_ALIGNMENT_CENTER, float(COL_W[ci]), 14,
					RoyaleHudStyle.INK_100)
			var rows: Array = heroes.filter(func(hh): return int(hh.team) == t)
			rows.sort_custom(func(a, b): return AssaultResults.rating(a) > AssaultResults.rating(b))
			var y := r.position.y + 30.0
			for hh in rows:
				var mine := bool(hh.get("me", false))
				if mine:
					RoyaleHudStyle.draw_sticker(self, Rect2(r.position.x + 6.0, y - 1.0, r.size.x - 12.0, AssaultResults.ROW_H - 2.0),
						Color(RoyaleHudStyle.SUN[2], 0.35), 8.0, 0.0, 1.5)
				var col: Color = RoyaleHudStyle.SUN[0] if mine else RoyaleHudStyle.PAPER
				var base := "Toi · " + String(GameData.class_data(String(hh.cid)).get("name_fr", "")) if mine else String(hh.name)
				var nm := "%s · %s" % [base, AssaultCombat.role_name(String(hh.role))]
				var x0 := r.position.x + 14.0
				var name_w := float(xs[0]) - x0 - 6.0
				if String(hh.key) == mvp:
					RoyaleHudStyle.draw_text(self, Vector2(x0, y + 17.0), "★", 16, RoyaleHudStyle.SUN[1], f)
					x0 += 20.0
					name_w -= 20.0
				if f.get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x > name_w:
					nm = base  # (le rôle tombe s'il ne tient pas : le nom jamais coupé)
				draw_string(f, Vector2(x0, y + 17.0), nm, HORIZONTAL_ALIGNMENT_LEFT, name_w, 15, col)
				var vals := [str(int(hh.kills)), str(int(hh.deaths)), str(int(hh.assists)), RoyaleStyle.number(float(hh.dmg)),
					"%d / %d" % [int(hh.plants), int(hh.defuses)]]
				for ci in COLS.size():
					draw_string(nf, Vector2(float(xs[ci]), y + 17.0), String(vals[ci]), HORIZONTAL_ALIGNMENT_CENTER, float(COL_W[ci]), 15, col)
				y += AssaultResults.ROW_H
