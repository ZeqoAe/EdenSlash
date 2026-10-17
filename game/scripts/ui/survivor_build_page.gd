class_name SurvivorBuildPage
extends HBoxContainer
## Page « Équipement » du menu pause en Survivant (lot S5, SPEC §10.2 ; v2 lot SVX-2) : toute la partie sur un écran, rien à régler.
##   1. Équipement : l'arme en grand (+N, jauge des paliers +6 / +8 / +10, auto-attaque), les 8 emplacements (icône,
##      couleur de rareté, +N, cadenas, losanges des paliers atteints ; « Libre » sinon), les statistiques du héros.
##      Une pièce ne se retire ni ne se change : un clic le rappelle sobrement. Survol : la carte de la pièce.
##   2. Sorts : 12 au plus (Survivor.SPELL_MAX), niveau x / 10 (jauge, losanges aux niveaux 5 et 10) et effet cumulé.
##   3. Passifs actifs (valeur cumulée de toutes les pièces, « max » au plafond), évolutions possibles (« il manque… ») et
##      bonus de panoplie (2 / 3 / 5 pièces).
##   4. « Qui fait le travail » (lot SVX-2) : dégâts par seconde de chaque source sur les 30 dernières secondes (SurvivorLog) :
##      arme, sorts, passifs, évolutions, panoplies ; repliable (◂ / ▸), repliée d'office sous 1500 px de large.

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
var _work_col: Control  # colonne « Qui fait le travail »
var _work: VBoxContainer
var _work_toggle: Button
var work_open := true


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
	ItemWidgets.section(col, "Panoplies", 18)
	_sets = VBoxContainer.new()
	_sets.add_theme_constant_override("separation", 6)
	col.add_child(_sets)
	ItemWidgets.action_button(c, "▶  Reprendre", func(): resume_requested.emit(), 0, true)
	# 4. qui fait le travail (dégâts par source, 30 dernières secondes)
	var d := ItemWidgets.panel(self, 0)
	_work_col = d.get_parent() as Control
	var dh := HBoxContainer.new()
	d.add_child(dh)
	var dt := ItemWidgets.section(dh, "Qui fait le travail", 18)
	dt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dt.tooltip_text = "Dégâts par seconde de chaque source sur les %d dernières secondes de jeu" % SurvivorLog.WINDOW
	dt.mouse_filter = Control.MOUSE_FILTER_PASS
	_work_toggle = Button.new()
	_work_toggle.focus_mode = Control.FOCUS_NONE
	_work_toggle.tooltip_text = "Replier / déplier la colonne"
	_work_toggle.pressed.connect(func(): set_work_open(not work_open))
	dh.add_child(_work_toggle)
	var sd := ScrollContainer.new()
	sd.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sd.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	d.add_child(sd)
	_work = VBoxContainer.new()
	_work.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_work.add_theme_constant_override("separation", 8)
	sd.add_child(_work)
	set_work_open(get_viewport().get_visible_rect().size.x >= 1500.0)


func subtitle() -> String:
	return "Tout se gagne aux cartes"


## Colonne « Qui fait le travail » dépliée (250 px) ou repliée (le bouton seul).
func set_work_open(on: bool) -> void:
	work_open = on
	_work_toggle.text = "◂" if on else "▸"
	_work_toggle.tooltip_text = "Replier la colonne" if on else "Qui fait le travail : les dégâts de chaque source"
	_work.get_parent().visible = on
	for c in _work_toggle.get_parent().get_children():
		if c != _work_toggle:
			(c as Control).visible = on
	_work_col.custom_minimum_size.x = 250.0 if on else 0.0
	if on:
		_refresh_work()


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
	_refresh_work()


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
	var left := Survivor.SPELL_MAX - all.size()  # places libres en une ligne (12 lignes « Libre » noyaient la colonne)
	if left > 0:
		var free := Hud._label(_spells, "+  %d place%s libre%s" % [left, "s" if left > 1 else "", "s" if left > 1 else ""], 15, Color(UiTheme.MUTED, 0.6))
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
	# évolutions (lot SVX-2), en tête de colonne : prêtes (elles viennent aux prochains choix) ou ce qu'il manque
	var at := 0
	for ev in SurvivorCardView.evo_paths().slice(0, 4):  # (lot SVX-3 : 20 recettes ; les 4 plus proches)
		var miss: Array = ev.missing
		var txt := ("◆ Évolution prête : %s (prochains choix)" % String(ev.name)) if miss.is_empty() else ("◆ %s : il manque %s" % [String(ev.name), ", ".join(PackedStringArray(miss))])
		var l := Hud._label(_passives, txt, UiTheme.MIN_TEXT, UiTheme.color("bonbon.soleil.clair") if miss.is_empty() else UiTheme.color("bonbon.amethyste.clair"))
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_passives.move_child(l, at)
		at += 1


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
		Hud._label(_sets, "Aucune : 2 pièces d'une même panoplie donnent un bonus", UiTheme.MIN_TEXT, UiTheme.MUTED)


# --- qui fait le travail -------------------------------------------------------------------------------------------------
## Dégâts par seconde de chaque source sur les 30 dernières secondes : icône, nom, barre, nombre, genre (part au survol).
func _refresh_work() -> void:
	if _work == null or not work_open:
		return
	for ch in _work.get_children():
		ch.queue_free()
	var rows := SurvivorLog.rows(SurvivorLog.WINDOW)
	var whole := rows.is_empty()
	if whole:
		rows = SurvivorLog.rows()  # (rien depuis 30 s : la partie entière)
	if rows.is_empty():
		var e := Hud._label(_work, "Rien encore : frappe d'abord !", UiTheme.MIN_TEXT, UiTheme.MUTED)
		e.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		return
	var top := float(rows[0].dmg)
	for r in rows.slice(0, 8):
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 8)
		h.mouse_filter = Control.MOUSE_FILTER_PASS
		h.tooltip_text = "%s (%s)\n%d %% des dégâts%s" % [String(r.name), String(r.kind), roundi(float(r.share) * 100.0),
			"" if whole else " · %s par seconde" % Items.fmt_num(roundi(float(r.dps)))]
		_work.add_child(h)
		var ic := TextureRect.new()
		ic.texture = UiTheme.texture(String(r.icon)) if String(r.icon) != "" else null
		ic.custom_minimum_size = Vector2(30, 30)
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_child(ic)
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 1)
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_child(v)
		var top_row := HBoxContainer.new()
		top_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(top_row)
		var n := Hud._label(top_row, String(r.name), 15, UiTheme.TEXT)
		n.add_theme_font_override("font", UiTheme.bold_font())
		n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		n.clip_text = true
		n.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		n.custom_minimum_size = Vector2(60, 0)
		var val := Hud._label(top_row, Items.fmt_num(roundi(float(r.dmg) if whole else float(r.dps))), 15, UiTheme.GOLD)
		val.add_theme_font_override("font", UiTheme.number_font())
		var bar := SurvivorCardView.Bar.new()
		bar.ratio = float(r.dmg) / maxf(top, 1.0)
		bar.color = UiTheme.color("bonbon.amethyste.base") if String(r.kind) == "évolution" else (UiTheme.color("bonbon.mandarine.base") if String(r.kind) == "arme" else UiTheme.color("bonbon.lagon.base"))
		v.add_child(bar)
		var k := Hud._label(v, String(r.kind), UiTheme.MIN_TEXT - 1, UiTheme.MUTED)
		k.clip_text = true
	var cap := Hud._label(_work, "dégâts de la partie" if whole else "par seconde, %d dernières secondes" % SurvivorLog.WINDOW, UiTheme.MIN_TEXT - 1, UiTheme.MUTED)
	cap.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


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
