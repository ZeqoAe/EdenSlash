class_name EncounterJournal
extends HBoxContainer
## Carnet > « Rencontres » (lot DNG-2, backlog BM-DNG P0-9 ; maquette conception/benchmark/donjons_maquettes/v2_journal_rencontres.svg) :
## le journal des 48 boss de la bibliothèque, sur les données du lot DNG-1 (Encounters.card / all / counts, BestTimes).
##   - à gauche, un puits d'encre : les boss par zone (6 par ligne), vaincu (coche pomme), rencontré (couleurs), à découvrir
##     (« ? » tramé : nom caché tant que sa zone n'est pas ouverte) ;
##   - à droite, la fiche : médaillon, nom et titre, où il a été vu, panoplie et emplacements (ceux qui manquent), mécaniques
##     (vues : leur compteur ; pas encore vues : grisées, mais le conseil reste lisible — on ne cache jamais l'aide), records par
##     difficulté des Donjons (victoires, meilleur temps du boss et du donjon complet), meilleure part de PV laissée, et
##     « Aller à son donjon ».
## Ajouté à la fin de CarnetPages.tabs() (la Collection garde l'indice 4).

const TILE := 58.0
static var sel := ""  # boss choisi (gardé entre deux ouvertures)

var tiles: Array = []  # (tests) tuiles des boss, dans l'ordre
var go_button: Button  # (tests) « Aller à son donjon »
var _grid_box: VBoxContainer
var _card_box: VBoxContainer
var _head: Label
var _sig := ""


func _init() -> void:
	add_theme_constant_override("separation", 14)
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	var left := PanelContainer.new()
	left.add_theme_stylebox_override("panel", UiTheme.well_style(Vector2(12, 10), 16))
	left.custom_minimum_size = Vector2(6 * TILE + 5 * 8 + 24 + 14, 0)
	left.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(left)
	var lv := VBoxContainer.new()
	lv.add_theme_constant_override("separation", 8)
	left.add_child(lv)
	_head = Label.new()
	_head.add_theme_font_override("font", UiTheme.bold_font())
	_head.add_theme_font_size_override("font_size", 15)
	_head.add_theme_color_override("font_color", UiTheme.color("papier.100"))
	_head.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lv.add_child(_head)
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	lv.add_child(sc)
	_grid_box = VBoxContainer.new()
	_grid_box.add_theme_constant_override("separation", 6)
	_grid_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(_grid_box)
	var right := PanelContainer.new()
	right.add_theme_stylebox_override("panel", UiTheme.panel_style(5, Vector2(14, 12), 16))
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_vertical = Control.SIZE_EXPAND_FILL
	UiTheme.scope(right, false)
	add_child(right)
	var rsc := ScrollContainer.new()
	rsc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	rsc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(rsc)
	_card_box = VBoxContainer.new()
	_card_box.add_theme_constant_override("separation", 10)
	_card_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rsc.add_child(_card_box)


## La page a pris sa taille minimale pendant sa construction : on la recale sur tout l'écran (ancres et décalages).
func _ready() -> void:
	_fill_rect()


## Une page construite pendant que l'écran est caché (taille nulle) s'agrandit à sa taille minimale en décalant son bord
## droit, et le garde ensuite (elle dépassait de l'écran) : on la recale sur l'écran après chaque construction.
func _fill_rect() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func subtitle() -> String:
	return "Les boss croisés et tes records"


func refresh() -> void:
	var all := Encounters.all()
	var sig := var_to_str([all.map(func(c): return [c.state, c.wins, c.met]), sel, get_viewport_rect().size if is_inside_tree() else Vector2.ZERO])
	if sig == _sig and not tiles.is_empty():
		return
	_sig = sig
	if sel == "" or not BossLibrary.has(sel):
		sel = _first_interesting(all)
	var cnt := Encounters.counts()
	var seen_types := {}
	for c in all:
		for b in c.bricks:
			if int(b.seen) > 0:
				seen_types[b.type] = true
	_head.text = "%d / %d vaincus · %d rencontrés\nMécaniques vues : %d / %d" % [int(cnt.won), int(cnt.total), int(cnt.met), seen_types.size(),
		BossBricks.DEFS.size()]
	for c in _grid_box.get_children():
		_grid_box.remove_child(c)
		c.queue_free()
	tiles = []
	for z in Dungeons.zone_ids():
		var cards := all.filter(func(c): return String(c.zone) == String(z))
		if cards.is_empty():
			continue
		var head := HBoxContainer.new()
		_grid_box.add_child(head)
		var zl := Hud._label(head, Dungeons.name_of(String(z)), 15, UiTheme.color("papier.100"))
		zl.add_theme_font_override("font", UiTheme.bold_font())
		zl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		Hud._label(head, "%d / %d" % [cards.filter(func(c): return c.state == "won").size(), cards.size()], UiTheme.MIN_TEXT, UiTheme.MUTED)
		var g := GridContainer.new()
		g.columns = 6
		g.add_theme_constant_override("h_separation", 8)
		g.add_theme_constant_override("v_separation", 8)
		_grid_box.add_child(g)
		for c in cards:
			var t := _tile(c)
			g.add_child(t)
			tiles.append(t)
	var legend := HBoxContainer.new()
	legend.add_theme_constant_override("separation", 14)
	_grid_box.add_child(legend)
	for e in [["vaincu", "pomme"], ["rencontré", "mandarine"], ["à découvrir", "gris"]]:
		var dot := ColorRect.new()
		dot.color = UiTheme.tones(String(e[1]))[1]
		dot.custom_minimum_size = Vector2(14, 14)
		dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		legend.add_child(dot)
		Hud._label(legend, String(e[0]), UiTheme.MIN_TEXT, UiTheme.MUTED)
	_show_card(sel)
	_fill_rect()
	_fill_rect.call_deferred()


## Le premier boss à montrer : le dernier rencontré pas encore vaincu, sinon le premier rencontré, sinon le premier.
static func _first_interesting(all: Array) -> String:
	for c in all:
		if c.state == "met":
			return String(c.id)
	for c in all:
		if c.state == "won":
			return String(c.id)
	return String(all[0].id) if not all.is_empty() else ""


## Tuile d'un boss : médaillon (rendu, ou « ? » tramé), coche pomme s'il est vaincu, liseré lagon s'il est choisi.
func _tile(c: Dictionary) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(TILE, TILE)
	b.flat = true
	b.tooltip_text = String(c.name) if String(c.name) != "???" else "À découvrir"
	b.set_meta("boss", String(c.id))
	var on := String(c.id) == sel
	var st := StyleBoxFlat.new()
	st.draw_center = false
	st.set_corner_radius_all(14)
	st.set_border_width_all(4 if on else 0)
	st.border_color = UiTheme.color("bonbon.lagon.fonce")
	st.expand_margin_left = 4
	st.expand_margin_right = 4
	st.expand_margin_top = 4
	st.expand_margin_bottom = 4
	for k in ["normal", "hover", "pressed", "focus"]:
		b.add_theme_stylebox_override(k, st if on or k != "hover" else _hover_box())
	var por := BossPortrait.for_boss(String(c.id), TILE, false)
	por.dim = String(c.state) == "unknown" and String(c.name) == "???"
	if String(c.state) == "unknown" and not por.dim:
		por.modulate = Color(0.62, 0.6, 0.7, 0.7)  # jamais rencontré (zone ouverte) : éteint, nom lisible
	por.set_anchors_preset(Control.PRESET_FULL_RECT)
	b.add_child(por)
	if String(c.state) == "won":
		var ck := Control.new()
		ck.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ck.size = Vector2(22, 22)
		ck.position = Vector2(TILE - 18, -6)
		ck.draw.connect(DungeonPage._draw_check.bind(ck))
		b.add_child(ck)
	var id := String(c.id)
	b.pressed.connect(_pick.bind(id))
	return b


static func _hover_box() -> StyleBoxFlat:
	var h := StyleBoxFlat.new()
	h.draw_center = false
	h.set_corner_radius_all(14)
	h.set_border_width_all(3)
	h.border_color = Color.WHITE
	h.expand_margin_left = 3
	h.expand_margin_right = 3
	h.expand_margin_top = 3
	h.expand_margin_bottom = 3
	return h


func _pick(id: String) -> void:
	Sfx.ui("click", -8.0)
	sel = id
	_sig = ""
	refresh()


## La fiche du boss [param bid].
func _show_card(bid: String) -> void:
	for c in _card_box.get_children():
		_card_box.remove_child(c)
		c.queue_free()
	go_button = null
	var c := Encounters.card(bid)
	if c.is_empty():
		return
	var hidden := String(c.name) == "???"
	var fam := BossLibrary.families_of(bid)
	var tone := "gris" if hidden else (BossBar.family_tone(String(fam[0])) if not fam.is_empty() else "amethyste")
	var hp := PanelContainer.new()
	hp.add_theme_stylebox_override("panel", UiTheme.sticker(tone, {"radius": 16, "shadow": 5, "pad": Vector2(12, 10), "cel_top": 0.1, "cel_bottom": 0.3,
		"trame": hidden}))
	_card_box.add_child(hp)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 14)
	hp.add_child(h)
	var por := BossPortrait.for_boss(bid, 104, false)
	por.dim = hidden
	por.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(por)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(v)
	DungeonPage._white(v, String(c.name) if not hidden else "Boss à découvrir", 28, true)
	var sub := ("%s · %s" % [String(c.title), String(c.zone_name)]) if String(c.title) != "" else String(c.zone_name)
	var sl := DungeonPage._white(v, sub if not hidden else "%s : ouvre cette zone pour le connaître" % String(c.zone_name), 16)
	sl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var where: Array = c.get("where", [])
	var met_line := "Rencontré dans : %s" % ", ".join(where) if not where.is_empty() else ("Jamais rencontré" if int(c.met) == 0 else "Rencontré %d fois" % int(c.met))
	var ml0 := DungeonPage._white(v, met_line, 14)
	ml0.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var slots: Array = (c.slots as Array).map(func(s): return String(Items.SLOT_NAMES.get(s, s)))
	var pl := DungeonPage._white(v, "Panoplie %s · %s" % [DungeonPage._arch_name(String(c.archetype)), ", ".join(slots)], 14)
	pl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# --- butin : les emplacements (cochés si déjà à toi) ---
	var lh := HBoxContainer.new()
	lh.add_theme_constant_override("separation", 10)
	_card_box.add_child(lh)
	var missing: Array = c.get("missing", [])
	for s in c.slots:
		lh.add_child(DungeonPage.slot_cell(String(s), String(c.archetype), not String(s) in missing, 56))
	var ml := DungeonPage._ink_label(lh, DungeonPage.missing_line(bid, missing, c.slots), UiTheme.MIN_TEXT, false, true)
	ml.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ml.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ml.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	# --- mécaniques : vues (compteur) ou pas encore vues (grisées, conseil lisible) ---
	_title_line("Mécaniques")
	var g := GridContainer.new()
	g.columns = 2
	g.add_theme_constant_override("h_separation", 8)
	g.add_theme_constant_override("v_separation", 8)
	_card_box.add_child(g)
	for br in c.bricks:
		var card := DungeonPage.mech_card(String(br.type), "", int(br.seen))
		g.add_child(card)
	# --- records par difficulté des Donjons ---
	_title_line("Tes records")
	var well := PanelContainer.new()
	well.add_theme_stylebox_override("panel", UiTheme.well_style(Vector2(14, 8), 14))
	_card_box.add_child(well)
	var tg := GridContainer.new()
	tg.columns = 4
	tg.add_theme_constant_override("h_separation", 26)
	tg.add_theme_constant_override("v_separation", 4)
	well.add_child(tg)
	for t in ["Difficulté", "Victoires", "Boss", "Donjon complet"]:
		Hud._label(tg, t, UiTheme.MIN_TEXT, UiTheme.MUTED)
	for d in c.dungeon:
		var won := int(d.wins) > 0
		var col := UiTheme.color("papier.100") if won or float(d.best) > 0.0 else Color("8f86aa")
		var dn := Hud._label(tg, String(d.name), 15, col)
		dn.add_theme_font_override("font", UiTheme.bold_font())
		Hud._label(tg, str(int(d.wins)) if won else "—", 15, col)
		Hud._label(tg, BestTimes.fmt(float(d.best)) if float(d.best) > 0.0 else "—", 15, col)
		Hud._label(tg, BestTimes.fmt(float(d.full)) if float(d.full) > 0.0 else "—", 15, col)
	var low := float(c.get("low", 1.0))
	if String(c.state) != "won" and low < 1.0:
		DungeonPage._ink_label(_card_box, "Ton meilleur sans le battre : il lui restait %d %%" % ceili(low * 100.0), 15, true)
	# --- actions ---
	var zid := String(c.zone)
	var go := MenuWidgets.gold_button("Aller à son donjon", 20, Vector2(300, 56))
	go.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var why := ""
	if not Unlocks.is_open("dungeons"):
		why = Unlocks.condition("dungeons")
	elif not Dungeons.is_open(zid):
		why = Dungeons.condition(zid)
	go.disabled = why != ""
	go.tooltip_text = why
	go.pressed.connect(_goto_dungeon.bind(bid))
	_card_box.add_child(go)
	go_button = go
	if why != "":
		var wl := DungeonPage._ink_label(_card_box, why, UiTheme.MIN_TEXT, false, true)
		wl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


func _title_line(text: String) -> void:
	var l := DungeonPage._ink_label(_card_box, text, 19, true)
	l.add_theme_font_override("font", UiTheme.title_font())


## Ferme le Carnet et ouvre la page Donjons sur ce boss.
func _goto_dungeon(bid: String) -> void:
	DungeonPage.sel = bid
	var sc := CarnetPages.screen_of(self)
	if sc == null:
		return
	var lobby := sc.get_parent()
	sc.close_ui()
	if lobby != null and lobby.has_method("_show_menu"):
		lobby.call("_show_menu", "dungeon")
