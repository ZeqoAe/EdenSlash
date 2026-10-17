class_name FabricationPage
extends VBoxContainer
## Atelier > Plans de donjon (lot A1 ; onglet « Fabrication » avant A3). Chaque boss de la bibliothèque (48) donne son
## plan à la 1re victoire contre lui (Dungeons.reward, « plan_<boss> » dans Profile.plans) ; le plan fabrique, contre des insignes, une
## pièce d'un des deux emplacements du boss (BossLibrary.loot) à sa panoplie. Le plan n'est pas consommé. Niveau et
## rareté suivent la meilleure difficulté finie contre ce boss (Dungeons.plan_diff) : mythique, légendaire une fois
## battu en Mythique. Prix : Economy.base_price d'une pièce du niveau du donjon à cette rareté (le prix plein de
## l'Armurerie). Les anciens plans par zone sont convertis par Dungeons.migrate_plans (appelée par known / craft).
## Lot GX-2 : la pièce se voit AVANT d'être fabriquée (icône, rareté, niveau requis, stats, verdict face à la pièce portée) ;
## l'aperçu ([method preview]) est la pièce même que le bouton fabrique ; « Fabriquer et porter » l'équipe aussitôt.


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


## Aperçus déjà tirés (boss|emplacement|niveau|rareté|classe -> pièce) : ce qui est montré est ce qui sera fabriqué.
static var _previews := {}


## La pièce que le plan de [param key] fabriquerait à l'emplacement [param slot] (même tirage jusqu'à la fabrication).
static func preview(key: String, slot: String) -> Dictionary:
	var bid := resolve(key)
	var k := "%s|%s|%d|%d|%s" % [bid, slot, level_of(bid), rarity_of(bid), Profile.selected_class]
	if not _previews.has(k):
		_previews[k] = _make(bid, slot)
	return _previews[k]


static func _make(bid: String, slot: String) -> Dictionary:
	var rar := rarity_of(bid)
	# modèle d'Eden du niveau du donjon (et non de la zone choisie au lobby) ; arme du type de la classe choisie
	var lv := level_of(bid)
	var tpl := Items.eden_template(slot, Items.default_weapon_type(Profile.selected_class), lv, rar)
	var it := Items.from_template(tpl, lv, rar) if not tpl.is_empty() else Items.generate(lv, 1.0, slot, Profile.selected_class, rar, "", rar)
	it["archetype"] = String(BossLibrary.loot(bid).archetype)
	return it


## Fabrique une pièce de la panoplie du boss [param key] à l'emplacement [param slot] (la pièce de [method preview]) ;
## {"error": raison} si le plan manque, si l'emplacement n'est pas celui du boss, si les insignes ne suffisent pas ou si
## l'inventaire est plein.
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
	var shown := preview(bid, slot)
	var it := shown.duplicate(true)
	it["uid"] = "%d_%d" % [Time.get_ticks_usec(), randi() % 100000]
	_previews.erase(_previews.find_key(shown))  # la prochaine fabrication tire une nouvelle pièce
	Profile.insignia -= c
	Profile.add_item(it)
	Profile.save_profile()
	return it


## Fabrique puis porte la pièce si le niveau de héros le permet ; renvoie le message (ou {"error"} comme [method craft]).
static func craft_and_wear(key: String, slot: String) -> Dictionary:
	var it := craft(key, slot)
	if it.has("error"):
		return it
	return {"item": it, "text": ForgeWidgets.wear_new(it)}


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


## Un plan trouvé (lot GX-2) : le donjon et sa panoplie, l'emplacement à choisir, puis la pièce elle-même AVANT de la
## fabriquer (case, rareté, niveau requis, stats, verdict face à la pièce portée ; Maj sur la case : la carte complète),
## et deux actions : « Fabriquer · N insignes » et « Fabriquer et porter ».
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
	var idx := clampi(int(_pick.get(bid, 0)), 0, slots.size() - 1)
	var slot := String(slots[idx])
	# les emplacements du boss : des onglets (souris et manette), l'aperçu suit
	var srow := HBoxContainer.new()
	srow.add_theme_constant_override("separation", 6)
	v.add_child(srow)
	for i in slots.size():
		var on := i == idx
		var sb := ForgeWidgets.candy_button(String(Items.SLOT_NAMES.get(slots[i], slots[i])), "mandarine" if on else "nuit", 15, 34)
		sb.custom_minimum_size.x = 110
		var at := i
		sb.pressed.connect(func():
			_pick[bid] = at
			refresh())
		srow.add_child(sb)
	var it := preview(bid, slot)
	var prow := HBoxContainer.new()
	prow.add_theme_constant_override("separation", 12)
	v.add_child(prow)
	var cell := ItemWidgets.ItemSlot.new(76.0)
	cell.set_item(it)
	cell.wear_check = true
	cell.show_compare = false  # le verdict écrit (profil de la classe) suffit : pas de ▲ générique qui le contredise
	cell.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	prow.add_child(cell)
	var txt := ItemWidgets.rich(prow, 15)
	txt.fit_content = true
	txt.scroll_active = false
	txt.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	txt.text = preview_text(it)
	var lock := HeroLevel.lock_text(it)
	if lock != "":
		Hud._label(v, lock + " · fabriquer reste permis", 14, ItemWidgets.LOCK_TEXT).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var c := cost(bid)
	var have := Profile.insignia
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	v.add_child(row)
	var b := MenuWidgets.gold_button("Fabriquer · %s" % insignia_text(c), 16, Vector2(0, 40))
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.disabled = have < c
	b.pressed.connect(func(): _do_craft(bid, slot, false))
	row.add_child(b)
	var bw := ForgeWidgets.candy_button("Fabriquer et porter", "lagon", 16, 40)
	bw.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bw.disabled = have < c or lock != ""
	bw.tooltip_text = lock if lock != "" else "La pièce rejoint aussitôt ton équipement (l'ancienne va au coffre commun)."
	bw.pressed.connect(func(): _do_craft(bid, slot, true))
	row.add_child(bw)
	var info := "Plan légendaire" if rarity_of(bid) == Items.LEGENDARY else "Plan mythique · légendaire après une victoire en Mythique"
	if have < c:
		info = "Il te manque %s ≈ %s" % [insignia_text(c - have), GearPower.plural(Economy.maps_for(c - have), "carte de Survie", "cartes de Survie")]
	var il := Hud._label(v, info, 15, UiTheme.DEBUFF if have < c else UiTheme.MUTED)
	il.tooltip_text = "La pièce est au niveau du donjon à ta meilleure difficulté contre ce boss ; légendaire après une victoire en Mythique."
	il.mouse_filter = Control.MOUSE_FILTER_PASS
	il.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


func _do_craft(bid: String, slot: String, wear: bool) -> void:
	var r := craft_and_wear(bid, slot) if wear else craft(bid, slot)
	if r.has("error"):
		_msg.add_theme_color_override("font_color", UiTheme.DEBUFF)
		_msg.text = String(r.error)
	else:
		Sfx.ui("confirm")
		_msg.add_theme_color_override("font_color", UiTheme.BUFF)
		_msg.text = String(r.text) if wear else "Fabriqué : %s (dans ton coffre commun)" % Items.display_name(r)
	refresh()


## Aperçu d'une pièce à fabriquer (BBCode court) : nom, « rareté · emplacement · niveau », verdict face à la pièce
## portée (le mot et l'écart de PE ; pas de pourcentage), puis ses trois plus fortes stats.
static func preview_text(it: Dictionary) -> String:
	var r: Dictionary = Items.RARITIES[clampi(int(it.get("rarity", 0)), 0, Items.RARITIES.size() - 1)]
	var lines: PackedStringArray = ["[b][color=#%s]%s[/color][/b]" % [Items.color_of(it).to_html(false), Items.display_name(it)],
		"[color=#c9bfea]%s · %s · niveau %d[/color]" % [String(r.name), String(Items.SLOT_NAMES.get(it.slot, it.slot)), int(it.get("level", 1))]]
	lines.append(verdict_text(it))
	var st := Items.stats(it)
	var keys: Array = st.keys()
	keys.sort_custom(func(a, b):
		var pa: bool = a in Items.PERCENT_STATS
		var pb: bool = b in Items.PERCENT_STATS
		return (not pa and pb) if pa != pb else float(st[a]) > float(st[b]))
	var parts: PackedStringArray = []
	for k in keys.slice(0, 3):
		parts.append("%s [b]%s[/b]" % [Forge.stat_name(String(k)), MerchantPages.ForgePage.stat_num(String(k), float(st[k]))])
	if not parts.is_empty():
		lines.append("   ".join(parts))
	return "\n".join(lines)


## Verdict d'une pièce face à celle que la classe porte au même emplacement : le mot d'après le profil de stats de la
## classe (Items.rating), le chiffre d'après la PE (étude BM-GEAR, Q4) : « ▲ Meilleure pour Guerrier  PE +621 ».
static func verdict_text(it: Dictionary) -> String:
	var worn: Dictionary = Profile.equipped.get(String(it.get("slot", "")), {})
	if worn.is_empty():
		return "[color=#c3f07a]Emplacement libre[/color]"
	var cid := Profile.selected_class
	var prof := ClassGear.profile(cid)
	var c := Items.compare_to_equipped(it)
	if not prof.is_empty():
		var old := Items.rating(worn, prof)
		c = (Items.rating(it, prof) - old) / maxf(absf(old), 0.0001)
	var dpe := GearPower.delta_if_equipped(it)
	var who := " pour " + String(GameData.class_data(cid).get("name_fr", cid)) if not prof.is_empty() else ""
	var word := ("▲ Meilleure" if c >= 0.02 else ("▼ Moins bonne" if c <= -0.02 else "≈ Équivalente")) + who
	return "[b][color=%s]%s[/color][/b]  [color=%s]PE %s%s[/color]" % ["#c3f07a" if c >= 0.02 else ("#ff9db0" if c <= -0.02 else "#c9bfea"), word,
		"#c3f07a" if dpe >= 0 else "#ff9db0", "+" if dpe >= 0 else "−", GearPower.fmt(absi(dpe))]


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
