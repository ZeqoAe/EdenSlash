class_name SurvivorBuildPage
extends HBoxContainer
## Page « Build » du menu pause en Survivant (lot S5, SPEC §10.2) : tout le build de la run sur un écran, rien à régler.
##   1. Équipement : l'arme en grand (+N, jauge des paliers +6 / +8 / +10, auto-attaque), les 8 emplacements (icône,
##      couleur de rareté, +N, cadenas, losanges des paliers atteints ; « Libre » sinon), les statistiques du héros.
##      Une pièce ne se retire ni ne se change : un clic le rappelle sobrement. Survol : la carte de la pièce.
##   2. Sorts : 6 au plus, niveau x / 10 (jauge, losanges aux niveaux 5 et 10) et effet cumulé.
##   3. Passifs actifs (valeur cumulée de toutes les pièces, « max » au plafond) et bonus de set (2 / 3 / 5 pièces).

signal resume_requested

const SLOT_ORDER := ["head", "chest", "legs", "gloves", "boots", "back", "necklace", "ring"]
const TILE := Vector2(96, 112)

var player: Player
var _equip_title: Label
var _weapon_box: VBoxContainer
var _grid: GridContainer
var _stats: GridContainer
var _note: Label
var _note_until := 0.0
var _spells_title: Label
var _spells: VBoxContainer
var _passives: VBoxContainer
var _sets: VBoxContainer


func _ready() -> void:
	add_theme_constant_override("separation", 16)
	# 1. équipement
	var a0 := ItemWidgets.panel(self, 470)
	_equip_title = ItemWidgets.section(a0, "Équipement")
	var sa := ScrollContainer.new()  # à 1280 × 720 les statistiques passent sous les cases : la colonne défile
	sa.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sa.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	a0.add_child(sa)
	var a := VBoxContainer.new()
	a.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	a.add_theme_constant_override("separation", 8)
	sa.add_child(a)
	_weapon_box = VBoxContainer.new()
	_weapon_box.add_theme_constant_override("separation", 6)
	a.add_child(_weapon_box)
	_grid = GridContainer.new()
	_grid.columns = 4
	_grid.add_theme_constant_override("h_separation", 10)
	_grid.add_theme_constant_override("v_separation", 10)
	a.add_child(_grid)
	_note = Hud._label(a, "", UiTheme.MIN_TEXT, UiTheme.MUTED)
	_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_note.custom_minimum_size = Vector2(0, 20)
	ItemWidgets.section(a, "Héros", 15)
	_stats = GridContainer.new()
	_stats.columns = 3
	_stats.add_theme_constant_override("h_separation", 8)
	_stats.add_theme_constant_override("v_separation", 8)
	a.add_child(_stats)
	# 2. sorts
	var b := ItemWidgets.panel(self, 0, true)
	_spells_title = ItemWidgets.section(b, "Sorts")
	var sb := ScrollContainer.new()
	sb.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sb.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	b.add_child(sb)
	_spells = VBoxContainer.new()
	_spells.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_spells.add_theme_constant_override("separation", 10)
	sb.add_child(_spells)
	# 3. passifs et sets
	var c := ItemWidgets.panel(self, 0, true)
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	c.add_child(sc)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 8)
	sc.add_child(col)
	ItemWidgets.section(col, "Passifs actifs")
	_passives = VBoxContainer.new()
	_passives.add_theme_constant_override("separation", 6)
	col.add_child(_passives)
	ItemWidgets.section(col, "Sets", 18)
	_sets = VBoxContainer.new()
	_sets.add_theme_constant_override("separation", 6)
	col.add_child(_sets)
	ItemWidgets.action_button(c, "▶  Reprendre", func(): resume_requested.emit(), 0, true)


func subtitle() -> String:
	return "Ton build : tout se gagne aux cartes, rien ne se retire"


func _process(_delta: float) -> void:
	if _note.text != "" and Time.get_ticks_msec() / 1000.0 > _note_until:
		_note.text = ""


func refresh() -> void:
	if not is_inside_tree():
		return
	_refresh_equipment()
	_refresh_stats()
	_refresh_spells()
	_refresh_passives()
	_refresh_sets()


# --- équipement --------------------------------------------------------------------------------------------------------
func _refresh_equipment() -> void:
	var worn := SurvivorGear.worn().size()
	_equip_title.text = "Équipement  %d / %d" % [worn, Items.SLOTS.size()]
	for ch in _weapon_box.get_children():
		ch.queue_free()
	for ch in _grid.get_children():
		ch.queue_free()
	var w: Dictionary = Profile.equipped.get("weapon", {})
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 14)
	_weapon_box.add_child(h)
	var t := SlotTile.new("weapon", w, self)
	t.custom_minimum_size = Vector2(112, 112)
	h.add_child(t)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 3)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_child(v)
	if w.is_empty():
		Hud._label(v, "Arme : libre", 18, UiTheme.MUTED)
		Hud._label(v, "Une carte d'arme la remplit", UiTheme.MIN_TEXT, UiTheme.MUTED)
	else:
		var n := Hud._label(v, Items.card_name(w).trim_prefix("+%d " % int(w.get("upgrade", 0))), 18, Items.color_of(w))
		n.add_theme_font_override("font", UiTheme.bold_font())
		n.clip_text = true
		n.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		Hud._label(v, WeaponAttacks.variant_label(w), UiTheme.MIN_TEXT + 1, UiTheme.GOLD)
		var g := SurvivorCardView.Segments.new(Items.MAX_UPGRADE, int(w.get("upgrade", 0)), 0, Survivor.WAKE_AT, Items.color_of(w))
		g.labels = true
		v.add_child(g)
		var mt := WeaponAttacks.mods_text(WeaponAttacks.spec_for(w), Run.weapon_ups.get("weapon", {}))
		mt = RegEx.create_from_string("^Niveau \\d+/\\d+ : ").sub(mt, "")  # (le +N de l'arme est déjà sur la jauge)
		if mt != "":
			var m := Hud._label(v, SurvivorCardView.fr(mt), UiTheme.MIN_TEXT, UiTheme.MUTED)
			m.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	for slot in SLOT_ORDER:
		var tile := SlotTile.new(slot, Profile.equipped.get(slot, {}), self)
		tile.custom_minimum_size = TILE
		_grid.add_child(tile)


## Un clic sur une case : rappel sobre (rien ne se retire), ou ce qui remplit une case libre.
func tile_pressed(slot: String) -> void:
	var it: Dictionary = Profile.equipped.get(slot, {})
	_note.text = ("🔒 %s : elle ne se retire pas." % SurvivorGear.LOCK_TEXT) if not it.is_empty() \
		else "%s : une carte de pièce remplit cette case." % Items.SLOT_NAMES.get(slot, slot)
	_note_until = Time.get_ticks_msec() / 1000.0 + 3.0


func _refresh_stats() -> void:
	for ch in _stats.get_children():
		ch.queue_free()
	var p := player if player != null else get_tree().get_first_node_in_group("player") as Player
	if p == null:
		return
	var mag := String(Run.class_data().get("dmg_type", "phys")) in ["mag", "magic"]
	for e in [[Items.fmt_num(roundi(p.max_hp)), "PV"], [Items.fmt_num(roundi(p.matk if mag else p.atk)), "attaque"],
			[Items.fmt_num(roundi(p.defense)), "défense"], ["%d %%" % roundi((p.mcrit if mag else p.crit) * 100.0), "critique"],
			["%d %%" % roundi(p.atk_speed * 100.0), "vitesse d'attaque"], ["%d %%" % roundi(p.cdr * 100.0), "recharge en moins"]]:
		ResultsPanel.tile(_stats, String(e[0]), String(e[1]), "", false, 128.0)


# --- sorts --------------------------------------------------------------------------------------------------------------
func _refresh_spells() -> void:
	for ch in _spells.get_children():
		ch.queue_free()
	var all := Run.all_skills()
	_spells_title.text = "Sorts  %d / %d" % [all.size(), Survivor.SPELL_MAX]
	var mx := int(Cards.rules().max_rank)
	for s in all:
		var d := Run.skill_def(int(s.id))
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 12)
		h.tooltip_text = "%s\n%s" % [String(d.get("name", "")), String(d.get("desc", ""))]
		h.mouse_filter = Control.MOUSE_FILTER_PASS
		_spells.add_child(h)
		var ic := TextureRect.new()
		ic.texture = UiTheme.texture(String(d.get("icon", "")))
		ic.custom_minimum_size = Vector2(52, 52)
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ic.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_child(ic)
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 2)
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_child(v)
		var top := HBoxContainer.new()
		top.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(top)
		var n := Hud._label(top, String(d.get("name", "?")), 16, UiTheme.TEXT)
		n.add_theme_font_override("font", UiTheme.bold_font())
		n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		n.clip_text = true
		n.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		var rank := int(s.rank)
		Hud._label(top, "Niv. %d / %d" % [rank, mx], 15, UiTheme.GOLD if rank >= mx else UiTheme.TEXT)
		v.add_child(SurvivorCardView.Segments.new(mx, rank, 0, [5, 10], UiTheme.GOLD))
		var tot := Hud._label(v, SurvivorCardView.spell_total(s).replace("[b]", "").replace("[/b]", ""), UiTheme.MIN_TEXT, UiTheme.MUTED)
		tot.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	for i in Survivor.SPELL_MAX - all.size():
		var free := Hud._label(_spells, "+  Libre", 15, Color(UiTheme.MUTED, 0.6))
		free.custom_minimum_size = Vector2(0, 30)


# --- passifs et sets ------------------------------------------------------------------------------------------------------
## Passifs de la run, du plus fort au plus faible : valeur cumulée de toutes les pièces, nombre de sources, plafond.
func _refresh_passives() -> void:
	for ch in _passives.get_children():
		ch.queue_free()
	var sources := {}
	for it in SurvivorGear.worn():
		for p in it.get("sv_passives", []):
			sources[String(p.id)] = int(sources.get(String(p.id), 0)) + 1
	var ids: Array = Run.passive_power.keys().filter(func(id): return float(Run.passive_power[id]) > 0.0)
	ids.sort_custom(func(a, b): return float(Run.passive_power[a]) > float(Run.passive_power[b]))
	if ids.is_empty():
		Hud._label(_passives, "Aucun : chaque pièce en apporte un", UiTheme.MIN_TEXT, UiTheme.MUTED)
	for id in ids:
		var d := Boons.get_def(String(id))
		if d.is_empty():
			continue
		var pw := float(Run.passive_power[id])
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 10)
		h.mouse_filter = Control.MOUSE_FILTER_PASS
		h.tooltip_text = String(d.get("desc", ""))
		_passives.add_child(h)
		var ic := TextureRect.new()
		ic.texture = UiTheme.texture(String(d.get("icon", Boons.ICONS.get(id, ""))))
		ic.custom_minimum_size = Vector2(34, 34)
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ic.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_child(ic)
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 0)
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_child(v)
		var capped := pw >= SurvivorGear.boon_cap(String(id)) - 0.001
		var n := int(sources.get(String(id), 0))
		var head := "%s%s%s" % [String(d.get("name", id)), "  ×%d" % n if n > 1 else "", "  · max" if capped else ""]
		var t := Hud._label(v, head, 15, SurvivorCardView.PASSIVE)
		t.add_theme_font_override("font", UiTheme.bold_font())
		var e := Hud._label(v, SurvivorCardView.fr(SurvivorCardView.effect_text(String(id), pw)), UiTheme.MIN_TEXT, UiTheme.TEXT)
		e.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var evo := SurvivorCards.evolutions_open()
	for id in evo:
		var l := Hud._label(_passives, "★ Évolution possible : %s" % String(Boons.get_def(String(id)).get("name", id)), UiTheme.MIN_TEXT, Color(1.0, 0.7, 0.3))
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


## Sets portés : nom, pièces sur 5, les paliers 2 / 3 / 5 (actifs en vert).
func _refresh_sets() -> void:
	for ch in _sets.get_children():
		ch.queue_free()
	var counts := Items.set_counts(Profile.equipped)
	var any := false
	for sid in counts:
		if not String(sid) in SurvivorPool.sets():
			continue
		any = true
		var n := int(counts[sid])
		var tiers := Items.set_tiers(String(sid))
		var top := int(tiers.max()) if not tiers.is_empty() else 5
		var h := HBoxContainer.new()
		_sets.add_child(h)
		var name := Hud._label(h, "◆ " + SurvivorPool.panoply_name(String(sid)), 15, Items.SET_COLOR)
		name.add_theme_font_override("font", UiTheme.bold_font())
		name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name.clip_text = true
		name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		Hud._label(h, "%s  %d / %d" % ["●".repeat(n) + "○".repeat(maxi(0, top - n)), n, top], 15, Items.SET_COLOR)
		for t in tiers:
			var on := n >= int(t)
			var l := Hud._label(_sets, "%s %d : %s" % ["✔" if on else "◇", int(t), " ; ".join(Items.bonus_lines(Items.set_bonus(String(sid), int(t))))],
				UiTheme.MIN_TEXT, Items.SET_COLOR if on else UiTheme.MUTED)
			l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if not any:
		Hud._label(_sets, "Aucun : 2 pièces d'un même set donnent un bonus", UiTheme.MIN_TEXT, UiTheme.MUTED)


## Case d'un emplacement : icône, couleur de rareté, +N, cadenas, losanges des paliers (+6, +8, +10) ; vide : « Libre ».
## Survol : la carte de la pièce ; clic : rappel (la pièce ne se retire pas).
class SlotTile extends Button:
	var slot := ""
	var item: Dictionary = {}
	var page: SurvivorBuildPage

	func _init(s: String, it: Dictionary, p: SurvivorBuildPage) -> void:
		slot = s
		item = it
		page = p
		focus_mode = Control.FOCUS_NONE
		flat = true
		var empty := StyleBoxEmpty.new()
		for st in ["normal", "hover", "pressed", "disabled", "focus"]:
			add_theme_stylebox_override(st, empty)
		tooltip_text = "" if not it.is_empty() else "%s : libre" % Items.SLOT_NAMES.get(s, s)
		pressed.connect(func(): page.tile_pressed(slot))

	func _make_custom_tooltip(_for_text: String) -> Object:
		if item.is_empty():
			return null
		return ItemWidgets.item_card(item)

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		var col := Items.color_of(item) if not item.is_empty() else Color(0.45, 0.42, 0.55)
		var hovered := is_hovered()
		draw_style_box(UiTheme.flat_box(Color(0.06, 0.05, 0.11, 0.95), Color(col, 0.9 if not item.is_empty() else 0.45),
			3 if hovered else 2, 10, false), r)
		var font := UiTheme.bold_font()
		var icon_r := Rect2(r.position + Vector2(10, 8), Vector2(r.size.x - 20, r.size.y - 40))
		var side := minf(icon_r.size.x, icon_r.size.y)
		icon_r = Rect2(icon_r.get_center() - Vector2.ONE * side * 0.5, Vector2.ONE * side)
		if item.is_empty():
			var n := String(Items.SLOT_NAMES.get(slot, slot))
			HudWidgets.text_center(self, n, Vector2(r.get_center().x, r.size.y * 0.42), font, 14, Color(0.7, 0.68, 0.8, 0.8), 0)
			HudWidgets.text_center(self, "Libre", Vector2(r.get_center().x, r.size.y * 0.42 + 20.0), font, 14, Color(0.55, 0.52, 0.65, 0.7), 0)
			return
		var tex := UiTheme.texture(String(item.get("icon", "")))
		if tex:
			draw_texture_rect(tex, icon_r, false)
		var up := int(item.get("upgrade", 0))
		if up > 0:
			var s := "+%d" % up
			var w := font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
			draw_rect(Rect2(4, 4, w + 10, 20), Color(0.05, 0.03, 0.08, 0.92))
			draw_string(font, Vector2(9, 19), s, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, UiTheme.GOLD)
		draw_string(font, Vector2(r.size.x - 22, 20), "🔒", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1, 1, 1, 0.85))
		if SurvivorGear.is_perfect(item):
			draw_string(font, Vector2(r.size.x - 22, icon_r.end.y), "★", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, UiTheme.GOLD)
		# paliers : un losange par palier (+6, +8, +10), plein quand il est atteint
		var y := r.size.y - 16.0
		var k := 0
		for at in Survivor.WAKE_AT:
			var c := Vector2(r.get_center().x + (k - 1) * 22.0, y)
			HudWidgets.diamond(self, c, 7.0, Color(0.04, 0.03, 0.08))
			HudWidgets.diamond(self, c, 5.5, UiTheme.GOLD if up >= int(at) else Color(0.35, 0.32, 0.45))
			k += 1
