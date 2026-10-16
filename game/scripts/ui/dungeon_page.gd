class_name DungeonPage
extends RefCounted
## Page Donjons du lobby (passe M2, donjons à la carte). Le joueur choisit son donjon d'après la pièce qu'il cherche,
## la panoplie ou les mécaniques du boss : 48 donjons (un par boss de la bibliothèque, 6 par zone). En haut le donjon
## choisi (boss, mécaniques, pièces, victoires) et sa difficulté ; dessous les filtres et la liste ; puis les alliés.
## Le bouton épinglé lance le donjon (Tower.start_dungeon avec le boss choisi). État gardé entre deux ouvertures.

static var sel := ""  # boss (donjon) choisi
static var f_slot := ""
static var f_arch := ""
static var f_family := ""

const SLOT_ORDER := ["weapon", "head", "chest", "legs", "gloves", "boots", "back", "necklace", "ring"]
const ARCH_ORDER := ["storm", "frost", "blood", "falcon", "phoenix", "wind", "salvo", "rampart"]
const CARD_W := 270.0
const PE_LOW := "Puissance d'équipement insuffisante"  # (même phrase que le lobby)
const FAR_NORMAL := "Trop faible ici : essaie d'abord une zone plus basse."


## Remplit la page (panneau défilant [code]lobby._sub[/code], bouton épinglé).
static func fill(lobby) -> void:
	var sub: VBoxContainer = lobby._sub
	lobby._activity_head("dungeon")
	if sel == "" or not BossLibrary.has(sel):
		var open := Dungeons.catalog({"open": true})
		sel = String(open[0]) if not open.is_empty() else BossLibrary.zone_boss(String(Dungeons.zone_ids()[0]))
	var zid := Dungeons.boss_zone(sel)
	lobby._dg_zone = zid
	var diff := int(lobby._dg_diff)
	var is_open := Dungeons.is_open(zid)
	# --- le donjon choisi -----------------------------------------------------------------------
	lobby._section(Dungeons.dungeon_name(sel))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	sub.add_child(box)
	_line(box, "Boss : %s · niveau %d" % [BossLibrary.full_name(sel), Dungeons.level(zid, diff) + 1], UiTheme.TEXT)
	var mech := _line(box, "Mécaniques : %s" % ", ".join(BossLibrary.mechanic_names(sel)), UiTheme.TEXT)
	mech.tooltip_text = "\n".join(BossLibrary.brick_types(sel).map(func(t): return "%s : %s" % [BossBricks.name_of(t), BossBricks.hint_of(t)]))
	mech.mouse_filter = Control.MOUSE_FILTER_STOP
	var th := BossLibrary.loot(sel)
	var slots: Array = (th.slots as Array).map(func(s): return String(Items.SLOT_NAMES.get(s, s)).to_lower())
	var pieces := _line(box, "Pièces : %s, panoplie %s" % [" ou ".join(slots), _arch_name(String(th.archetype))], UiTheme.GOLD)
	pieces.tooltip_text = "Chaque victoire : un coffre de trois pièces au choix parmi ces emplacements, à la panoplie du donjon, plus des matières et des cristaux. Sans limite : refais-le autant que tu veux."
	pieces.mouse_filter = Control.MOUSE_FILTER_STOP
	var wins: Array = []
	for d in Dungeons.DIFF_NAMES.size():
		wins.append("%s %d" % [Dungeons.DIFF_NAMES[d], Dungeons.boss_cleared(sel, d)])
	_line(box, "Victoires : %s" % " · ".join(wins), UiTheme.MUTED)
	# --- difficulté -----------------------------------------------------------------------------
	var dr := HBoxContainer.new()
	dr.add_theme_constant_override("separation", 6)
	sub.add_child(dr)
	for i in Dungeons.DIFF_NAMES.size():
		var ok_pe := Dungeons.power_ok(zid, i)
		var b := MenuWidgets.glass_button(("🔒 " if not ok_pe else ("✔ " if i == diff else "")) + "%s (niv. %d)" % [Dungeons.DIFF_NAMES[i], Dungeons.level(zid, i)], 14, Vector2(0, 40))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.modulate = Color.WHITE if ok_pe else Color(1, 1, 1, 0.5)
		b.tooltip_text = Dungeons.power_text(zid, i)
		var di := i
		b.pressed.connect(func():
			lobby._dg_diff = di
			lobby._show_menu("dungeon"))
		dr.add_child(b)
	# lot A2 : PE requise (Héroïque, Mythique) ou conseillée (Normal), estimation et récompenses, comme la Ruée et le Siège
	DifficultyPanel.add(sub, Dungeons.power_required(zid, diff), Dungeons.advised(zid, diff), rewards(sel, diff),
		FAR_NORMAL if diff == 0 else "")
	lobby._pe_next(zid, false)
	# --- filtres et liste -----------------------------------------------------------------------
	lobby._section("Je cherche", "Filtre les donjons d'après la pièce, la panoplie ou les mécaniques du boss.")
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 6)
	sub.add_child(bar)
	_filter(lobby, bar, ["Toutes les pièces"] + SLOT_ORDER.map(func(s): return String(Items.SLOT_NAMES.get(s, s))), [""] + SLOT_ORDER, f_slot,
		func(v): f_slot = v)
	_filter(lobby, bar, ["Toutes les panoplies"] + ARCH_ORDER.map(func(a): return _arch_name(a)), [""] + ARCH_ORDER, f_arch, func(v): f_arch = v)
	var fams: Array = BossBricks.FAMILIES.keys()
	_filter(lobby, bar, ["Toutes les mécaniques"] + fams.map(func(f): return String(BossBricks.FAMILIES[f])), [""] + fams, f_family,
		func(v): f_family = v)
	var ids := Dungeons.catalog({"slot": f_slot, "archetype": f_arch, "family": f_family})
	var open_ids := ids.filter(func(id): return Dungeons.is_open(Dungeons.boss_zone(id)))
	var shut := ids.size() - open_ids.size()
	if ids.is_empty():
		_line(sub, "Aucun donjon ne répond à ces filtres.", UiTheme.MUTED)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 6)
	sub.add_child(grid)
	for id in open_ids + ids.filter(func(x): return not x in open_ids):
		grid.add_child(_card(lobby, String(id), diff))
	if shut > 0 and not open_ids.is_empty():
		_line(sub, "🔒 Les autres s'ouvrent en battant les boss de la Survie.", UiTheme.MUTED)
	lobby._dungeon_allies_picker()
	# --- lancement ------------------------------------------------------------------------------
	var go := MenuWidgets.gold_button("Entrer : %s" % Dungeons.dungeon_name(sel), 22, Vector2(0, 58))
	go.disabled = not (is_open and Dungeons.power_ok(zid, diff))
	go.pressed.connect(func(): lobby._start_dungeon())
	lobby._pin_go(go, ("" if Dungeons.power_ok(zid, diff) else PE_LOW) if is_open else Dungeons.condition(zid))


## Récompenses courtes du donjon de [param bid] en difficulté [param diff] : cristaux, coffre de pièces (et d'équipement en
## Mythique), plan à la 1re victoire (Dungeons.reward).
static func rewards(bid: String, diff: int) -> Array:
	var out: Array = ["%d cristaux" % ActivityLoot.dungeon_crystals(diff), "3 pièces au choix"]
	if diff >= 2:
		out.append("coffre d'équipement")
	if not Dungeons.has_plan(bid):
		out.append("son plan de donjon")
	return out


static func _arch_name(a: String) -> String:
	return String(Items.SETS.get(a, {}).get("name", a))


static func _line(parent: Control, text: String, color: Color) -> Label:
	var l := Hud._label(parent, text, 14, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


## Menu déroulant d'un filtre : [param labels] affichés, [param values] gardées ; [param set_v] range le choix.
static func _filter(lobby, parent: Control, labels: Array, values: Array, cur: String, set_v: Callable) -> void:
	var o := OptionButton.new()
	o.focus_mode = Control.FOCUS_NONE
	o.fit_to_longest_item = false
	o.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	o.add_theme_font_size_override("font_size", 14)
	for l in labels:
		o.add_item(String(l))
	o.select(maxi(values.find(cur), 0))
	o.item_selected.connect(func(i):
		set_v.call(String(values[i]))
		lobby._show_menu("dungeon"))
	parent.add_child(o)


## Carte d'un donjon de la liste : son nom, puis boss · pièces · panoplie · niveau ; cadre doré s'il est choisi.
static func _card(lobby, id: String, diff: int) -> Button:
	var zid := Dungeons.boss_zone(id)
	var open := Dungeons.is_open(zid)
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(CARD_W, 58)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var on := id == sel
	var base := UiTheme.flat_box(Color(0.14, 0.11, 0.24, 0.96), UiTheme.GOLD, 2, 10, false) if on else UiTheme.flat_box(Color(0.07, 0.08, 0.17, 0.9), MenuWidgets.LINE, 1, 10, false)
	b.add_theme_stylebox_override("normal", base)
	b.add_theme_stylebox_override("hover", UiTheme.flat_box(Color(0.13, 0.12, 0.26, 0.96), UiTheme.GOLD_DIM, 2, 10, false))
	b.add_theme_stylebox_override("pressed", base)
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 12
	v.offset_right = -10
	v.offset_top = 6
	v.offset_bottom = -6
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 0)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(v)
	var t := Hud._label(v, ("🔒 " if not open else ("✔ " if Dungeons.boss_cleared(id, 0) + Dungeons.boss_cleared(id, 1) + Dungeons.boss_cleared(id, 2) > 0 else "")) + Dungeons.dungeon_name(id), 15,
		UiTheme.GOLD if on else UiTheme.TEXT)
	t.add_theme_font_override("font", UiTheme.bold_font())
	t.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	t.clip_text = true
	var s := Hud._label(v, "%s · %s · %s" % [Dungeons.slot_text(id), _arch_name(String(BossLibrary.loot(id).archetype)), "niv. %d" % Dungeons.level(zid, diff)], 12, UiTheme.MUTED)
	s.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	s.clip_text = true
	b.tooltip_text = "%s\n%s" % [BossLibrary.full_name(id), ", ".join(BossLibrary.mechanic_names(id))] if open else Dungeons.condition(zid)
	if not open:
		b.modulate = Color(1, 1, 1, 0.5)
	b.pressed.connect(func():
		Sfx.ui("click", -8.0)
		sel = id
		lobby._show_menu("dungeon"))
	return b
