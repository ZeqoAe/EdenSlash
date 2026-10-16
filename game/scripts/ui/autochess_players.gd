class_name AutochessPlayers
extends PanelContainer
## L'Échiquier (lot AC-G) : colonne des 8 stratèges, à droite (SPEC §7.1). Une ligne par stratège, classée par PV : rang,
## portrait (classe), nom, barre de PV et PV, frise des dernières manches (or = victoire, rouge = défaite, gris = égalité),
## série en cours ; ta ligne cerclée d'or, l'adversaire de la manche cerclé de rouge, les éliminés grisés avec leur place.
## Une ligne cliquable (souris, A) : signal scout_requested (l'écran montre son plateau sur la moitié adverse).

signal scout_requested(pi: int)

const W := 236.0
const ROW_H := 44.0
const HISTORY := 6  # dots de la frise

var rows := {}  # pi -> ligne (tests, navigation)
var identities: Array = []  # [{name, class_id}] par stratège
var history := {}  # pi -> ["victoire" | "defaite" | "egalite"…]
var _list: VBoxContainer
var _sig := ""


func _init() -> void:
	name = "AcPlayers"
	custom_minimum_size = Vector2(W, 0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_stylebox_override("panel", AutochessHud.box(AutochessHud.BG_SOFT, Color(UiTheme.GOLD_DIM, 0.6), 1, 10, 8, 8))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(v)
	v.add_child(AutochessHud.lbl("Stratèges", 18, UiTheme.GOLD, "title"))
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 3)
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
	var sig := "%s|%d|%d|%d" % [str(order.map(func(i): return [g.players[i].hp, g.players[i].alive, g.players[i].streak])), foe,
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
	row.custom_minimum_size = Vector2(0, ROW_H)
	row.mouse_filter = Control.MOUSE_FILTER_STOP
	row.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var border := Color(0, 0, 0, 0)
	if pi == me:
		border = UiTheme.GOLD
	elif pi == foe:
		border = UiTheme.DEBUFF
	elif pi == scouted:
		border = Color(0.45, 0.7, 1.0)
	var bg := Color(0.16, 0.17, 0.34, 0.85) if pi == me else Color(0.08, 0.09, 0.2, 0.7)
	row.add_theme_stylebox_override("panel", AutochessHud.box(bg, border, 2 if border.a > 0.0 else 0, 8, 6, 3))
	row.modulate = Color(1, 1, 1, 1) if alive else Color(1, 1, 1, 0.5)
	var who := name_of(pi)
	row.tooltip_text = "%s\nNiveau %d · série %s" % [who, int(p.level), _streak_text(int(p.streak))] if alive else \
		"%s\n%s place" % [who, place_text(int(p.place))]
	row.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and (ev as InputEventMouseButton).pressed \
				and (ev as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			scout_requested.emit(pi)
			row.accept_event())
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(h)
	var rk := AutochessHud.lbl(str(rank) if alive else place_text(int(p.place)), 14, UiTheme.MUTED, "bold")
	rk.custom_minimum_size.x = 22
	rk.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	h.add_child(rk)
	var ic := TextureRect.new()
	ic.custom_minimum_size = Vector2(32, 32)
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var cid := String(identities[pi].get("class_id", "warrior")) if pi < identities.size() else "warrior"
	ic.texture = UiTheme.texture(String(GameData.class_data(cid).get("icon", "")))
	h.add_child(ic)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 1)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(v)
	var nm := AutochessHud.lbl(who, 14, UiTheme.GOLD if pi == me else UiTheme.TEXT, "bold")
	nm.clip_text = true
	nm.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	nm.custom_minimum_size.x = 60
	v.add_child(nm)
	var pb := ProgressBar.new()
	pb.show_percentage = false
	pb.max_value = AutochessData.PLAYER_HP
	pb.value = clampi(int(p.hp), 0, AutochessData.PLAYER_HP)
	pb.custom_minimum_size = Vector2(0, 6)
	pb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pb.add_theme_stylebox_override("background", AutochessHud.box(Color(UiTheme.INK, 0.85), Color(0, 0, 0, 0), 0, 3, 0, 0))
	var hpc := UiTheme.BUFF if int(p.hp) > 50 else (UiTheme.GOLD if int(p.hp) > 25 else UiTheme.HP)
	pb.add_theme_stylebox_override("fill", AutochessHud.box(hpc, hpc, 0, 3, 0, 0))
	v.add_child(pb)
	var fr := Frieze.new()
	fr.results = history.get(pi, [])
	v.add_child(fr)
	var hp := AutochessHud.lbl(str(maxi(int(p.hp), 0)), 17, UiTheme.TEXT if alive else UiTheme.MUTED, "bold")
	hp.custom_minimum_size.x = 30
	hp.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
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


## Frise des dernières manches : un point par manche (or : victoire, rouge : défaite, gris : égalité).
class Frieze extends Control:
	var results: Array = []

	func _init() -> void:
		custom_minimum_size = Vector2(0, 8)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var x := 4.0
		for r in results:
			var col := UiTheme.GOLD if String(r) == "victoire" else (UiTheme.HP if String(r) == "defaite" else UiTheme.MUTED)
			draw_circle(Vector2(x, size.y * 0.5), 3.0, col)
			x += 10.0
