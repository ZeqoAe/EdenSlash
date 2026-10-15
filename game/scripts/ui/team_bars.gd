class_name TeamBars
extends PanelContainer
## Arènes et Gantelet (passe M7) : les PV de chaque héros, sous le titre du HUD (pile de gauche) ; ton camp en bleu,
## l'autre en rouge, les héros à terre grisés. Entre deux manches, le tableau de la manche : dégâts infligés de chacun
## et ses K.O. (DuelDirector.board). Le cadre de cible du haut ne montre qu'un adversaire : ici on voit tout le monde.

const W := 300.0
const ALLY := Color(0.45, 0.75, 1.0)
const FOE := Color(1.0, 0.45, 0.4)

var duel: DuelDirector
var _box: VBoxContainer
var _rows: Array = []  # [{node, bar, name, num}]
var _head: Label  # « Dégâts de la manche » : seulement entre deux manches
var _t := 0.0


func setup(director: DuelDirector) -> void:
	duel = director
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(W, 0)
	add_theme_stylebox_override("panel", UiTheme.flat_box(Color(0.05, 0.04, 0.1, 0.78), UiTheme.GOLD_DIM, 1, 8))
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 3)
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_box)
	var parent := get_parent()
	if parent is VBoxContainer and parent.get_child_count() > 1:
		parent.move_child(self, 1)  # juste sous le titre
	rebuild()


## Lignes de la manche : le joueur et ses alliés, puis les adversaires (appelé à chaque manche).
func rebuild() -> void:
	for c in _box.get_children():
		c.queue_free()
	_rows = []
	if duel == null:
		return
	_head = Hud._label(_box, "Dégâts de la manche", 14, UiTheme.GOLD)
	_head.visible = false
	var mine: Array = [duel.d.player] + duel._allies
	var theirs: Array = duel._foes.duplicate()
	if is_instance_valid(duel._foe):
		theirs.push_front(duel._foe)
	for list in [mine, theirs]:
		for c in list:
			if is_instance_valid(c):
				_add_row(c, list == mine)


func _add_row(c: Combatant, mine: bool) -> void:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.add_child(h)
	var cid := String(c.get("class_id") if c is Player else c.get("cid"))
	var name := "Toi" if c == duel.d.player else String(GameData.class_data(cid).get("name_fr", cid))
	var n := Hud._label(h, name, 14, ALLY if mine else FOE)
	n.custom_minimum_size = Vector2(118, 0)
	n.clip_text = true
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 10)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var col := ALLY if mine else FOE
	bar.add_theme_stylebox_override("fill", UiTheme.flat_box(col.darkened(0.15), col, 1, 4, false))
	bar.add_theme_stylebox_override("background", UiTheme.flat_box(Color(0.08, 0.07, 0.12, 0.9), Color(0.25, 0.22, 0.32), 1, 4, false))
	h.add_child(bar)
	var num := Hud._label(h, "", 14, UiTheme.MUTED)
	num.custom_minimum_size = Vector2(54, 0)
	num.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_rows.append({"node": c, "bar": bar, "name": n, "num": num})


func _process(delta: float) -> void:
	_t -= delta
	if _t > 0.0 or duel == null:
		return
	_t = 0.1
	var between := duel.phase in ["between", "done"]
	if _head != null:
		_head.visible = between
	for r in _rows:
		var c = r.node
		var alive: bool = is_instance_valid(c) and not c.is_dead
		var bar: ProgressBar = r.bar
		bar.max_value = 1.0
		bar.value = (c.hp / maxf(c.max_hp, 1.0)) if alive else 0.0
		(r.name as Label).modulate.a = 1.0 if alive else 0.45
		var num: Label = r.num
		if between and is_instance_valid(c):
			# tableau de la manche : dégâts infligés (et K.O.)
			var e: Dictionary = duel.board.get(c.get_instance_id(), {})
			num.text = Hud._big_number(float(e.get("dealt", 0.0))) + (" · %d K.O." % int(e.ko) if int(e.get("ko", 0)) > 0 else "")
			num.tooltip_text = "Dégâts infligés pendant la manche"
		else:
			num.text = "" if alive else "à terre"
