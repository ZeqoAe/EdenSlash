class_name FabricationPage
extends VBoxContainer
## Atelier > Plans de donjon (lot A1 ; onglet « Fabrication » avant A3). Chaque boss de la bibliothèque (48) donne son
## plan à la 1re victoire contre lui (Dungeons.reward, « plan_<boss> » dans Profile.plans) ; le plan fabrique, contre des insignes, une
## pièce d'un des deux emplacements du boss (BossLibrary.loot) à sa panoplie. Le plan n'est pas consommé. Niveau et
## rareté suivent la meilleure difficulté finie contre ce boss (Dungeons.plan_diff) : mythique, légendaire une fois
## battu en Mythique. Prix : Economy.base_price d'une pièce du niveau du donjon à cette rareté (le prix plein de
## l'Armurerie). Les anciens plans par zone sont convertis par Dungeons.migrate_plans (appelée par known / craft).


## Boss d'un plan : [param key] est un id de boss, ou une zone (son boss d'origine, comme les anciens plans « plan_<zone> »).
static func resolve(key: String) -> String:
	if BossLibrary.has(key):
		return key
	return BossLibrary.zone_boss(key) if key in Dungeons.zone_ids() else key


## Difficulté la plus haute finie contre le boss [param key] (-1 : jamais battu).
static func best_diff(key: String) -> int:
	return Dungeons.plan_diff(resolve(key))


## Boss dont tu as le plan.
static func known() -> Array:
	return Dungeons.plans_known()


## Emplacements que fabrique le plan de [param key] (ceux du butin de son boss).
static func slots_of(key: String) -> Array:
	return (BossLibrary.loot(resolve(key)).slots as Array).duplicate()


static func rarity_of(key: String) -> int:
	return Items.LEGENDARY if best_diff(key) >= 2 else Items.MYTHIC


## Niveau des pièces fabriquées : celui du donjon du boss à sa meilleure difficulté finie.
static func level_of(key: String) -> int:
	var bid := resolve(key)
	return Dungeons.level(Dungeons.boss_zone(bid), maxi(Dungeons.plan_diff(bid), 0))


## Prix en insignes d'une pièce fabriquée avec le plan de [param key].
static func cost(key: String) -> int:
	return Economy.base_price({"level": level_of(key), "rarity": rarity_of(key)})


## Fabrique une pièce de la panoplie du boss [param key] à l'emplacement [param slot] ; {"error": raison} si le plan
## manque, si l'emplacement n'est pas celui du boss, si les insignes ne suffisent pas ou si l'inventaire est plein.
static func craft(key: String, slot: String) -> Dictionary:
	var bid := resolve(key)
	if not BossLibrary.has(bid) or not Dungeons.has_plan(bid):
		return {"error": "Tu n'as pas le plan de ce donjon."}
	if not slot in slots_of(bid):
		return {"error": "Ce plan ne fabrique pas cet emplacement."}
	var c := cost(bid)
	if Profile.insignia < c:
		return {"error": "Il te faut %s." % insignia_text(c)}
	if Profile.inventory.size() >= Profile.INVENTORY_MAX:
		return {"error": "Coffre commun plein."}
	var rar := rarity_of(bid)
	# modèle d'Eden du niveau du donjon (et non de la zone choisie au lobby) ; arme du type de la classe choisie
	var lv := level_of(bid)
	var tpl := Items.eden_template(slot, Items.default_weapon_type(Profile.selected_class), lv, rar)
	var it := Items.from_template(tpl, lv, rar) if not tpl.is_empty() else Items.generate(lv, 1.0, slot, Profile.selected_class, rar, "", rar)
	it["archetype"] = String(BossLibrary.loot(bid).archetype)
	Profile.insignia -= c
	Profile.add_item(it)
	Profile.save_profile()
	return it


## Le mot « insignes » avec son nombre (accord compris).
static func insignia_text(n: int) -> String:
	return GearPower.plural(n, "insigne", "insignes")


var _grid: GridContainer  # les plans trouvés
var _todo_title: Label
var _todo_grid: GridContainer  # les plans des donjons ouverts, pas encore trouvés
var _closed: Label  # les plans des donjons encore fermés, en une ligne
var _banner: VBoxContainer
var _count: Label
var _msg: Label
var _pick := {}  # boss -> indice de l'emplacement choisi


func subtitle() -> String:
	return "Panoplie du boss, en insignes"


func _ready() -> void:
	add_theme_constant_override("separation", 10)
	var panel := ItemWidgets.panel(self, 0, true)
	var hh := HBoxContainer.new()
	panel.add_child(hh)
	var head := Hud._label(hh, "Plans de donjon", 20, UiTheme.GOLD)
	head.add_theme_font_override("font", UiTheme.title_font())
	head.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_count = Hud._label(hh, "", 18, UiTheme.TEXT)
	_count.tooltip_text = ResourceHelp.tip("plan")
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
	_grid = _cards_grid(col, 2)
	_todo_title = Hud._label(col, "Plans à trouver", 18, UiTheme.MUTED)
	_todo_grid = _cards_grid(col, 3)
	_closed = Hud._label(col, "", 15, UiTheme.MUTED)
	_closed.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_msg = Hud._label(panel, "", 16, UiTheme.BUFF)
	_msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


func _cards_grid(parent: Control, cols: int) -> GridContainer:
	var g := GridContainer.new()
	g.columns = cols
	g.add_theme_constant_override("h_separation", 12)
	g.add_theme_constant_override("v_separation", 12)
	g.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(g)
	return g


func refresh() -> void:
	if not is_inside_tree():
		return
	var have := known()
	_count.text = "%d / %d plans" % [have.size(), Dungeons.plan_total()]
	for box in [_banner, _grid, _todo_grid]:
		for ch in box.get_children():
			box.remove_child(ch)
			ch.queue_free()
	_banner.custom_minimum_size = Vector2.ZERO
	_banner.visible = have.is_empty()
	if have.is_empty():
		_empty_state()
	for bid in have:
		_card(String(bid))
	var closed := 0
	for bid in BossLibrary.ids():
		if String(bid) in have:
			continue
		if Dungeons.is_open(Dungeons.boss_zone(String(bid))):
			_todo_card(String(bid))
		else:
			closed += 1
	_todo_title.visible = not have.is_empty() and _todo_grid.get_child_count() > 0
	_closed.visible = closed > 0 and Unlocks.is_open("dungeons")
	_closed.text = "%s dans les donjons encore fermés." % GearPower.plural(closed, "autre plan", "autres plans")


## Aucun plan : ce qui manque et où le trouver, en une phrase.
func _empty_state() -> void:
	var ic := TextureRect.new()
	ic.texture = ResourceHelp.icon("plan")
	ic.custom_minimum_size = Vector2(72, 72)
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	ic.modulate = Color(1, 1, 1, 0.55)
	_banner.add_child(ic)
	var t := Hud._label(_banner, "Aucun plan pour l'instant", 22, UiTheme.GOLD)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var sub := "Bats un boss de donjon : son plan tombe à la première victoire." if Unlocks.is_open("dungeons") else Unlocks.condition("dungeons")
	var s := Hud._label(_banner, sub, 16, UiTheme.MUTED)
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	s.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_banner.custom_minimum_size = Vector2(0, 150)


func _box(grid: GridContainer, got: bool, arch_id: String) -> VBoxContainer:
	var pc := PanelContainer.new()
	pc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pc.add_theme_stylebox_override("panel", UiTheme.flat_box(Color(0.08, 0.07, 0.15, 0.95) if got else Color(0.05, 0.045, 0.09, 0.9),
		UiTheme.GOLD_DIM if got else Color(0.3, 0.28, 0.4, 0.7), 2 if got else 1, 10, false))
	pc.tooltip_text = _set_tip(arch_id)
	grid.add_child(pc)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	pc.add_child(v)
	return v


## Un plan trouvé : le donjon, sa panoplie, l'emplacement à choisir et le bouton « Fabriquer · N insignes ».
func _card(bid: String) -> void:
	var arch := String(BossLibrary.loot(bid).archetype)
	var v := _box(_grid, true, arch)
	var top := HBoxContainer.new()
	v.add_child(top)
	var title_l := Hud._label(top, Dungeons.dungeon_name(bid), 18, UiTheme.TEXT)
	title_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_l.clip_text = true
	title_l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	Hud._label(top, "Panoplie %s" % String(Items.SETS.get(arch, {}).get("name", "")), 15, Items.SET_COLOR)
	var slots := slots_of(bid)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	v.add_child(row)
	var ob := OptionButton.new()
	ob.focus_mode = Control.FOCUS_NONE
	ob.custom_minimum_size = Vector2(130, 40)
	for s in slots:
		ob.add_item(String(Items.SLOT_NAMES.get(s, s)))
	ob.selected = clampi(int(_pick.get(bid, 0)), 0, slots.size() - 1)
	ob.item_selected.connect(func(i): _pick[bid] = i)
	row.add_child(ob)
	var c := cost(bid)
	var have := Profile.insignia
	var b := MenuWidgets.gold_button("Fabriquer · %s" % insignia_text(c), 16, Vector2(0, 40))
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.disabled = have < c
	b.pressed.connect(func():
		var r := craft(bid, String(slots[ob.selected]))
		if r.has("error"):
			_msg.add_theme_color_override("font_color", UiTheme.DEBUFF)
			_msg.text = String(r.error)
		else:
			Sfx.ui("confirm")
			_msg.add_theme_color_override("font_color", UiTheme.BUFF)
			_msg.text = "Fabriqué : %s (dans ton coffre commun)" % Items.display_name(r)
		refresh())
	row.add_child(b)
	var info := "Pièce %s, niveau %d" % ["légendaire" if rarity_of(bid) == Items.LEGENDARY else "mythique", level_of(bid)]
	if have < c:
		info += " · il te manque %s" % insignia_text(c - have)
	var il := Hud._label(v, info, 15, UiTheme.DEBUFF if have < c else UiTheme.MUTED)
	il.tooltip_text = "Niveau du donjon à ta meilleure difficulté contre ce boss ; légendaire après une victoire en Mythique."
	il.mouse_filter = Control.MOUSE_FILTER_PASS


## Un plan pas encore trouvé (donjon ouvert) : le donjon, ses emplacements, et qui le donne.
func _todo_card(bid: String) -> void:
	var v := _box(_todo_grid, false, String(BossLibrary.loot(bid).archetype))
	var title_l := Hud._label(v, Dungeons.dungeon_name(bid), 16, UiTheme.MUTED)
	title_l.clip_text = true
	title_l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	Hud._label(v, Dungeons.slot_text(bid), 14, UiTheme.MUTED)
	var l := Hud._label(v, Dungeons.plan_source(bid), 14, UiTheme.MUTED)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


## Infobulle d'une panoplie : ses bonus à 2, 4 et 6 pièces.
static func _set_tip(arch_id: String) -> String:
	var lines: PackedStringArray = []
	for n in Items.set_tiers(arch_id):
		lines.append("%d pièces : %s" % [n, " ; ".join(Items.bonus_lines(Items.set_bonus(arch_id, n)))])
	return "\n".join(lines)
