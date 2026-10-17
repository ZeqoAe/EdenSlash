class_name AutochessPlayers
extends PanelContainer
## L'Échiquier (lot AC-G, v2 du lot ACX-1) : colonne des 8 stratèges, à droite (SPEC §7.1), autocollant papier. Une ligne
## par stratège, classée par PV : rang, portrait (icône de classe dans une case contourée), nom, barre de PV épaisse
## (pomme, soleil puis fraise selon les PV), frise des dernières manches (pomme = victoire, fraise = défaite, papier =
## égalité), PV en chiffre ; ta ligne en soleil clair, l'adversaire de la manche cerclé de fraise, le plateau regardé
## cerclé de lagon, les éliminés grisés avec leur place. Une ligne cliquable (souris, A) : signal scout_requested.

signal scout_requested(pi: int)

const W := AutochessHud.SIDE_W
const ROW_H := 44.0
const HISTORY := 6  # pastilles de la frise

var rows := {}  # pi -> ligne (tests, navigation)
var identities: Array = []  # [{name, class_id}] par stratège
var history := {}  # pi -> ["victoire" | "defaite" | "egalite"…]
var _list: VBoxContainer
var _sig := ""


func _init() -> void:
	name = "AcPlayers"
	custom_minimum_size = Vector2(AutochessHud.s(W), 0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_stylebox_override("panel", AutochessHud.paper_panel(7.0, 8.0, 10.0))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", roundi(AutochessHud.s(3.0)))
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(v)
	v.add_child(AutochessHud.panel_title("Stratèges", 22))
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", roundi(AutochessHud.s(2.0)))
	_list.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(_list)


## Note le résultat de la manche de chaque stratège (appelé au bilan de manche).
func record(g: Autochess) -> void:
	for p in g.players:
		var r := String((p.last as Dictionary).get("result", ""))
		if r == "":
			continue
		var h: Array = history.get(int(p.id), [])
		h.append(r)
		while h.size() > HISTORY:
			h.pop_front()
		history[int(p.id)] = h


## [param me] : le joueur ; [param foe] : son adversaire de la manche (-1 : aucun) ; [param scouted] : plateau regardé.
func refresh(g: Autochess, me: int, foe := -1, scouted := -1) -> void:
	var order: Array = range(g.players.size())
	order.sort_custom(func(a, b):
		var pa: Dictionary = g.players[a]
		var pb: Dictionary = g.players[b]
		if bool(pa.alive) != bool(pb.alive):
			return bool(pa.alive)
		if not bool(pa.alive):
			return int(pa.place) < int(pb.place)
		if int(pa.hp) != int(pb.hp):
			return int(pa.hp) > int(pb.hp)
		return a < b)
	var sig := "%s|%d|%d|%d" % [str(order.map(func(i): return [g.players[i].hp, g.players[i].alive, g.players[i].streak, g.players[i].level])), foe,
		scouted, str(history).hash()]
	if sig == _sig:
		return
	_sig = sig
	for c in _list.get_children():
		_list.remove_child(c)
		c.queue_free()
	rows.clear()
	var rank := 0
	for pi in order:
		rank += 1
		var row := _row(g, int(pi), rank, me, foe, scouted)
		_list.add_child(row)
		rows[int(pi)] = row


func name_of(pi: int) -> String:
	return String(identities[pi].get("name", "")) if pi < identities.size() else "Stratège %d" % (pi + 1)


func _row(g: Autochess, pi: int, rank: int, me: int, foe: int, scouted: int) -> Control:
	var p: Dictionary = g.players[pi]
	var alive := bool(p.alive)
	var row := PanelContainer.new()
	row.name = "AcPlayer_%d" % pi
	row.custom_minimum_size = Vector2(0, AutochessHud.s(ROW_H))
	row.mouse_filter = Control.MOUSE_FILTER_STOP
	row.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var fill := Color(0, 0, 0, 0)
	var border := Color(0, 0, 0, 0)
	if pi == me:
		fill = AutochessHud.candy("soleil", 0)
		border = AutochessHud.INK
	if pi == foe:
		border = AutochessHud.candy("fraise")
	elif pi == scouted:
		border = AutochessHud.candy("lagon", 2)
	var bw := 0.0 if border.a <= 0.0 else (2.0 if pi == me and pi != foe else 3.0)
	var sb := AutochessHud.sticker(fill, 10.0, 0.0, bw, 5.0, 2.0)
	sb.border_color = border
	row.add_theme_stylebox_override("panel", sb)
	row.modulate = Color(1, 1, 1, 1) if alive else Color(1, 1, 1, 0.55)
	var who := name_of(pi)
	row.tooltip_text = "%s\nNiveau %d · série %s" % [who, int(p.level), _streak_text(int(p.streak))] if alive else \
		"%s\n%s place" % [who, place_text(int(p.place))]
	UiFeel.attach(row, "row")
	row.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and (ev as InputEventMouseButton).pressed \
				and (ev as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			scout_requested.emit(pi)
			row.accept_event())
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", roundi(AutochessHud.s(5.0)))
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(h)
	var rk := AutochessHud.ink_lbl(str(rank) if alive else place_text(int(p.place)), 14, AutochessHud.INK_300, 900)
	rk.custom_minimum_size.x = AutochessHud.s(18.0) if alive else AutochessHud.s(26.0)
	rk.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rk.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(rk)
	var frame := PanelContainer.new()
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	frame.add_theme_stylebox_override("panel", AutochessHud.sticker(AutochessHud.candy("lagon", 0), 9.0, 0.0, 2.0, 1.0, 1.0))
	h.add_child(frame)
	var ic := TextureRect.new()
	var side := AutochessHud.s(30.0)
	ic.custom_minimum_size = Vector2(side, side)
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var cid := String(identities[pi].get("class_id", "warrior")) if pi < identities.size() else "warrior"
	ic.texture = UiTheme.texture(String(GameData.class_data(cid).get("icon", "")))
	frame.add_child(ic)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", roundi(AutochessHud.s(2.0)))
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(v)
	var nm := AutochessHud.ink_lbl(who, 14, AutochessHud.INK, 800)
	nm.clip_text = true
	nm.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	nm.custom_minimum_size.x = 50
	v.add_child(nm)
	var hpv := clampi(int(p.hp), 0, AutochessData.PLAYER_HP)
	var hpc := AutochessHud.candy("pomme") if hpv > 50 else (AutochessHud.candy("soleil") if hpv > 25 else AutochessHud.candy("fraise"))
	var pb := AutochessHud.gauge(ProgressBar.new(), hpc, 8.0)
	pb.max_value = AutochessData.PLAYER_HP
	pb.value = hpv
	v.add_child(pb)
	var fr := Frieze.new()
	fr.results = history.get(pi, [])
	v.add_child(fr)
	var hp := AutochessHud.pop_lbl(str(maxi(int(p.hp), 0)), 17, AutochessHud.INK)
	hp.custom_minimum_size.x = AutochessHud.s(30.0)
	hp.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hp.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(hp)
	return row


static func place_text(place: int) -> String:
	return "1re" if place == 1 else "%de" % place


static func _streak_text(s: int) -> String:
	if s >= 2:
		return "%d victoires" % s
	if s <= -2:
		return "%d défaites" % -s
	return "aucune"


## Frise des dernières manches : une pastille contourée par manche (pomme : victoire, fraise : défaite, papier : égalité).
class Frieze extends Control:
	var results: Array = []

	func _init() -> void:
		custom_minimum_size = Vector2(0, AutochessHud.s(9.0))
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var r := AutochessHud.s(3.6)
		var x := r + 1.0
		for res in results:
			var col := AutochessHud.candy("pomme") if String(res) == "victoire" else \
				(AutochessHud.candy("fraise") if String(res) == "defaite" else AutochessHud.PAPER)
			var c := Vector2(x, size.y * 0.5)
			draw_circle(c, r, col)
			draw_arc(c, r, 0.0, TAU, 12, AutochessHud.INK, 1.3, true)
			x += r * 2.0 + AutochessHud.s(3.0)
