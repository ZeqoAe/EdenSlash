class_name FabricationPage
extends VBoxContainer
## Atelier > Fabrication : chaque plan trouvé dans un donjon (Profile.plans, « plan_<zone> ») permet de
## fabriquer, contre des cristaux, une pièce de la panoplie de ce donjon (son archétype : Dungeons.ARCHETYPES) à
## l'emplacement voulu. Le plan n'est pas consommé. Niveau et rareté suivent la meilleure difficulté terminée :
## mythique, légendaire une fois le donjon fini en Mythique.

const SLOTS := ["weapon", "head", "chest", "legs", "gloves", "boots", "back", "necklace", "ring"]  # arme : du type de la classe choisie
const COST := 60  # cristaux par niveau de difficulté terminé (Normal 60, Héroïque 120, Mythique 180)


## Difficulté la plus haute terminée du donjon [param zid] (-1 : jamais terminé).
static func best_diff(zid: String) -> int:
	var best := -1
	for d in Dungeons.DIFF_NAMES.size():
		if Dungeons.cleared(zid, d) > 0:
			best = d
	return best


## Zones dont tu as le plan.
static func known() -> Array:
	var out: Array = []
	for zid in Dungeons.zone_ids():
		if ("plan_" + String(zid)) in Profile.plans:
			out.append(zid)
	return out


static func cost(zid: String) -> int:
	return COST * (maxi(best_diff(zid), 0) + 1)


## Fabrique une pièce de la panoplie de [param zid] à l'emplacement [param slot] ; {} si le plan manque, si les
## cristaux ne suffisent pas ou si l'inventaire est plein ("error" donne la raison).
static func craft(zid: String, slot: String) -> Dictionary:
	if not ("plan_" + zid) in Profile.plans:
		return {"error": "Tu n'as pas le plan de ce donjon."}
	if not slot in SLOTS:
		return {"error": "Emplacement inconnu."}
	var c := cost(zid)
	if Profile.amount("crystal") < c:
		return {"error": "Il te faut %d cristaux." % c}
	if Profile.inventory.size() >= Profile.INVENTORY_MAX:
		return {"error": "Inventaire plein."}
	var d := maxi(best_diff(zid), 0)
	var rar := Items.LEGENDARY if d >= 2 else Items.MYTHIC
	# modèle d'Eden du niveau du donjon (et non de la zone choisie au lobby) ; arme du type de la classe choisie
	var lv := Dungeons.level(zid, d)
	var tpl := Items.eden_template(slot, Items.default_weapon_type(Profile.selected_class), lv, rar)
	var it := Items.from_template(tpl, lv, rar) if not tpl.is_empty() else Items.generate(lv, 1.0, slot, Profile.selected_class, rar, "", rar)
	it["archetype"] = Dungeons.archetype(zid)
	Profile.materials["crystal"] = Profile.amount("crystal") - c
	Profile.add_item(it)
	Profile.save_profile()
	return it


var _grid: GridContainer  # les donjons dont tu as le plan
var _todo_title: Label
var _todo_grid: GridContainer  # les autres
var _banner: VBoxContainer
var _count: Label
var _msg: Label
var _pick := {}  # zone -> emplacement choisi dans la liste


func subtitle() -> String:
	return "Plans de donjon, contre des cristaux"


func _ready() -> void:
	add_theme_constant_override("separation", 10)
	var panel := ItemWidgets.panel(self, 0, true)
	var hh := HBoxContainer.new()
	panel.add_child(hh)
	var head := Hud._label(hh, "Fabrication", 20, UiTheme.GOLD)
	head.add_theme_font_override("font", UiTheme.title_font())
	head.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_count = Hud._label(hh, "", 18, UiTheme.TEXT)
	_count.tooltip_text = "Plans de donjon trouvés"
	_count.mouse_filter = Control.MOUSE_FILTER_PASS
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(sc)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 12)
	sc.add_child(col)
	_banner = VBoxContainer.new()
	_banner.alignment = BoxContainer.ALIGNMENT_CENTER
	_banner.add_theme_constant_override("separation", 6)
	col.add_child(_banner)
	_grid = _cards_grid(col)
	_todo_title = Hud._label(col, "Plans à trouver", 18, UiTheme.MUTED)
	_todo_grid = _cards_grid(col)
	_msg = Hud._label(panel, "", 16, UiTheme.BUFF)
	_msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


func _cards_grid(parent: Control) -> GridContainer:
	var g := GridContainer.new()
	g.columns = 2
	g.add_theme_constant_override("h_separation", 12)
	g.add_theme_constant_override("v_separation", 12)
	g.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(g)
	return g


## Le mot « cristaux » avec son nombre (accord compris).
static func crystals_text(n: int) -> String:
	return "%d %s" % [n, "cristal" if n < 2 else "cristaux"]


func refresh() -> void:
	if not is_inside_tree():
		return
	var zones := Dungeons.zone_ids()
	var have := known()
	_count.text = "%d / %d plans" % [have.size(), zones.size()]
	for box in [_banner, _grid, _todo_grid]:
		for ch in box.get_children():
			box.remove_child(ch)
			ch.queue_free()
	_banner.custom_minimum_size = Vector2.ZERO
	_banner.visible = have.is_empty()
	if have.is_empty():
		_empty_state()
	var todo := zones.filter(func(z): return not String(z) in have)
	for z in zones:
		if String(z) in have:
			_card(String(z), true)
	_todo_title.visible = not have.is_empty() and not todo.is_empty()
	for z in todo:
		_card(String(z), false)


## Aucun plan : ce qui manque et où le trouver, en une phrase.
func _empty_state() -> void:
	var ic := TextureRect.new()
	ic.texture = UiTheme.texture(Items.material_icon("crystal"))
	ic.custom_minimum_size = Vector2(72, 72)
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	ic.modulate = Color(1, 1, 1, 0.55)
	_banner.add_child(ic)
	var t := Hud._label(_banner, "Aucun plan pour l'instant", 22, UiTheme.GOLD)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var sub := "Termine un donjon pour en recevoir le plan." if Unlocks.is_open("dungeons") else Unlocks.condition("dungeons")
	var s := Hud._label(_banner, sub, 16, UiTheme.MUTED)
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	s.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_banner.custom_minimum_size = Vector2(0, 150)


## La fiche d'un donjon : sa panoplie, et soit la fabrication (plan trouvé), soit ce qui manque.
func _card(zid: String, got: bool) -> void:
	var grid := _grid if got else _todo_grid
	var arch: Dictionary = Items.SETS[Dungeons.archetype(zid)]
	var pc := PanelContainer.new()
	pc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pc.add_theme_stylebox_override("panel", UiTheme.flat_box(Color(0.08, 0.07, 0.15, 0.95) if got else Color(0.05, 0.045, 0.09, 0.9),
		UiTheme.GOLD_DIM if got else Color(0.3, 0.28, 0.4, 0.7), 2 if got else 1, 10, false))
	pc.tooltip_text = _set_tip(Dungeons.archetype(zid))
	grid.add_child(pc)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	pc.add_child(v)
	var top := HBoxContainer.new()
	v.add_child(top)
	var title_l := Hud._label(top, Dungeons.name_of(zid), 18, UiTheme.TEXT if got else UiTheme.MUTED)
	title_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	Hud._label(top, "Panoplie %s" % String(arch.name), 15, Items.SET_COLOR if got else UiTheme.MUTED)
	if not got:
		var why := "Termine ce donjon pour recevoir son plan." if Dungeons.is_open(zid) else (Dungeons.condition(zid) if Unlocks.is_open("dungeons") else "Donjon fermé.")
		var l := Hud._label(v, why, 15, UiTheme.MUTED)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		return
	var best := maxi(best_diff(zid), 0)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	v.add_child(row)
	var ob := OptionButton.new()
	ob.focus_mode = Control.FOCUS_NONE
	ob.custom_minimum_size = Vector2(130, 40)
	for s in SLOTS:
		ob.add_item(String(Items.SLOT_NAMES.get(s, s)))
	ob.selected = clampi(int(_pick.get(zid, 0)), 0, SLOTS.size() - 1)
	ob.item_selected.connect(func(i): _pick[zid] = i)
	row.add_child(ob)
	var c := cost(zid)
	var have := Profile.amount("crystal")
	var b := MenuWidgets.gold_button("Fabriquer · %s" % crystals_text(c), 16, Vector2(0, 40))
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.disabled = have < c
	b.pressed.connect(func():
		var r := craft(zid, SLOTS[ob.selected])
		if r.has("error"):
			_msg.add_theme_color_override("font_color", UiTheme.DEBUFF)
			_msg.text = String(r.error)
		else:
			_msg.add_theme_color_override("font_color", UiTheme.BUFF)
			_msg.text = "Fabriqué : %s (dans ton inventaire)" % Items.display_name(r)
		refresh())
	row.add_child(b)
	var info := "Pièce %s" % ("légendaire" if best >= 2 else "mythique")
	if have < c:
		info += " · il te manque %s" % crystals_text(c - have)
	var il := Hud._label(v, info, 15, UiTheme.DEBUFF if have < c else UiTheme.MUTED)
	il.tooltip_text = "Légendaire une fois ce donjon terminé en Mythique"
	il.mouse_filter = Control.MOUSE_FILTER_PASS


## Infobulle d'une panoplie : ses bonus à 2, 4 et 6 pièces.
static func _set_tip(arch_id: String) -> String:
	var lines: PackedStringArray = []
	for n in Items.set_tiers(arch_id):
		lines.append("%d pièces : %s" % [n, " ; ".join(Items.bonus_lines(Items.set_bonus(arch_id, n)))])
	return "\n".join(lines)
