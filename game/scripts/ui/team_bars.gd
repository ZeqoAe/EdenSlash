class_name TeamBars
extends PanelContainer
## Arènes et Gantelet (passe M7) : les PV de chaque héros, sous le titre du HUD (pile de gauche) ; ton camp en bleu,
## l'autre en rouge, les héros à terre grisés. Entre deux manches, le tableau de la manche : dégâts infligés de chacun
## et ses K.O. (DuelDirector.board). Le cadre de cible du haut ne montre qu'un adversaire : ici on voit tout le monde.

const W := 360.0  # largeur de la pile de gauche (Hud.PANEL_W)
const ALLY := Color("86ddff")  # lagon clair (lot HUD-2 : couleurs de la bible)
const FOE := Color("ff9db0")  # fraise clair

var duel: DuelDirector
var _box: VBoxContainer
var _rows: Array = []  # [{node, bar, name, num}]
var _head: Label  # « Dégâts de la manche » : seulement entre deux manches
var _t := 0.0


func setup(director: DuelDirector) -> void:
	duel = director
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(W, 0)
	# puits d'encre translucide contouré, comme la quête suivie (lot HUD-2)
	var sb := UiTheme.well_style(Vector2(10, 6), 14)
	sb.bg_color = Color(UiTheme.color("encre.500"), 0.88)
	add_theme_stylebox_override("panel", sb)
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
	var name := HeroLook.name_or("Toi") if c == duel.d.player else String(GameData.class_data(cid).get("name_fr", cid))
	var n := Hud._label(h, name, 14, ALLY if mine else FOE)
	n.add_theme_font_override("font", UiTheme.bold_font())
	n.custom_minimum_size = Vector2(118, 0)
	n.clip_text = true
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 12)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# jauge autocollante : creux d'encre contouré, remplissage lagon (ton camp) ou fraise (l'autre)
	var fill := StyleBoxFlat.new()
	fill.bg_color = UiTheme.color("bonbon.lagon.base" if mine else "bonbon.fraise.base")
	fill.set_corner_radius_all(6)
	fill.border_color = Color(0, 0, 0, 0)
	fill.set_border_width_all(2)
	fill.anti_aliasing = true
	var back := StyleBoxFlat.new()
	back.bg_color = UiTheme.color("encre.900")
	back.border_color = UiTheme.color("encre.900")
	back.set_border_width_all(2)
	back.set_corner_radius_all(6)
	back.anti_aliasing = true
	bar.add_theme_stylebox_override("fill", fill)
	bar.add_theme_stylebox_override("background", back)
	h.add_child(bar)
	var num := Hud._label(h, "", 14, UiTheme.color("papier.100"))
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
