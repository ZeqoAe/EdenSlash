class_name ResultsPanel
extends CanvasLayer
## Bilan de fin de partie, le même pour la Survie, le Duel, la Tour, les donjons (Donjon, Siège, Ruée)
## et le Battle royale : titre, une ligne, des tuiles de chiffres, trois blocs (Gagné, Gardé, Perdu) et
## les boutons d'après-partie. Un écran = un composant : on lui passe une description (Dictionary).
##
## [codeblock]
## ResultsPanel.new().show_spec({
##     "title": "VICTOIRE !", "tone": "win",              # win | lose | info
##     "subtitle": "Guerrier · Époque I",
##     "notes": ["Époque II débloquée !"],                # annonces dorées
##     "tiles": [["12", "niveau atteint"], ["3 / 8", "place", "infobulle", true]],   # [valeur, légende, infobulle, mis en avant]
##     "gained": [ResultsPanel.row("Maîtrise Guerrier", "+15", "", "expertise")],   # progression
##     "kept": [...], "lost": [...],                      # butin gardé ; ce qui reste dans la partie
##     "footnote": "",
##     "buttons": [{"text": "Rejouer", "primary": true, "call": func(): ...}, {"text": "Retour au lobby", "call": ...}],
## })
## [/codeblock]
## Une ligne de bloc : [method row] (texte, valeur à droite, infobulle, icône). Un bloc vide n'est pas affiché.

const WIN := UiTheme.GOLD
const LOSE := Color(0.95, 0.42, 0.38)
const INFO := Color(0.55, 0.85, 1.0)
const GAINED := UiTheme.GOLD
const KEPT := Color(0.5, 0.95, 0.58)
const LOST := Color(1.0, 0.5, 0.45)
const WIDTH := 1040.0
const LOCK_SECS := 0.45  # les boutons n'agissent pas tout de suite : un appui de fin de combat ne doit rien valider
const COLUMNS := [["gained", "Gagné", GAINED], ["kept", "Gardé", KEPT], ["lost", "Perdu", LOST]]
const ICON_MATERIALS := ["gold", "keys", "crystal"]

var buttons: Array[Button] = []  # (tests) boutons de la rangée du bas, dans l'ordre de la description
var _scroll: ScrollContainer
var _body: VBoxContainer


## Ligne d'un bloc : [param text] à gauche, [param value] en gras à droite, [param tip] au survol,
## [param icon] : nom d'icône du menu (MenuWidgets) ou matière (gold, keys, crystal).
static func row(text: String, value := "", tip := "", icon := "") -> Dictionary:
	return {"text": text, "value": value, "tip": tip, "icon": icon}


## Lignes « Coffre de forge · parchemins ×2 » d'une liste de coffres de récompense (ActivityLoot, Rewards) : un type et une
## spécialité par ligne, dans l'ordre du menu Coffres.
static func chest_rows(chests: Array) -> Array:
	var counts := {}
	for c in chests:
		var k := Rewards.kind_of(c)
		counts[k] = int(counts.get(k, 0)) + 1
	var kinds: Array = counts.keys()
	kinds.sort_custom(func(x, y): return Rewards.kind_rank(String(x)) < Rewards.kind_rank(String(y)))
	var out: Array = []
	for k in kinds:
		out.append(row(Rewards.kind_name(String(k)), "×%d" % int(counts[k]), Rewards.kind_blurb(String(k)), "chest"))
	return out


## Ligne d'une récompense dite en texte (« +90 insignes (place 3) ») : les insignes deviennent « Insignes +90 », le reste reste tel quel.
static func reward_row(text: String) -> Dictionary:
	var re := RegEx.new()
	re.compile("^\\+(\\d+) insignes?\\s*(?:\\((.*)\\))?$")
	var m := re.search(text)
	if m:
		var why := m.get_string(2)
		return row("Insignes", "+" + m.get_string(1), why.substr(0, 1).to_upper() + why.substr(1), "upgrade")
	return row(text, "", "", "chest")


## Nombre en groupes de trois chiffres (« 12 480 »).
static func number(v: float) -> String:
	return Hud._big_number(v)


## Tuile de chiffre : grande valeur dorée, légende dessous.
static func tile(parent: Control, value: String, caption: String, tip := "", highlight := false, min_w := 118.0) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UiTheme.flat_box(Color(0.07, 0.055, 0.13, 0.95), UiTheme.GOLD if highlight else UiTheme.GOLD_DIM, 2 if highlight else 1, 8))
	p.custom_minimum_size = Vector2(min_w, 0)
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if tip != "":
		p.tooltip_text = tip
	else:
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(v)
	var big := Hud._label(v, value, 26, Color(1.0, 0.9, 0.55) if highlight else UiTheme.GOLD)
	big.add_theme_font_override("font", UiTheme.bold_font())
	big.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var cap := Hud._label(v, caption, UiTheme.MIN_TEXT, UiTheme.MUTED)
	cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cap.clip_text = true
	return p


func show_spec(spec: Dictionary) -> void:
	layer = 30
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("results_panel")  # le HUD se retire derrière le bilan (Hud._menu_open)
	get_tree().paused = true
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.01, 0.05, 0.9)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiTheme.panel_box(34, 24))
	panel.custom_minimum_size = Vector2(WIDTH, 0)
	center.add_child(panel)
	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", 12)
	panel.add_child(_body)
	var tone: Color = {"win": WIN, "lose": LOSE, "info": INFO}.get(String(spec.get("tone", "info")), INFO)
	var t := Label.new()
	UiTheme.title(t, 50, tone)
	t.text = String(spec.get("title", ""))
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_body.add_child(t)
	var orn := MenuWidgets.Ornament.new()
	orn.custom_minimum_size = Vector2(0, 18)
	_body.add_child(orn)
	if String(spec.get("subtitle", "")) != "":
		var s := Hud._label(_body, String(spec.subtitle), 22, UiTheme.TEXT)
		s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	for n in spec.get("notes", []):
		var nl := Hud._label(_body, String(n), 20, UiTheme.GOLD)
		nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		nl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var tiles: Array = spec.get("tiles", [])
	if not tiles.is_empty():
		var tr := HBoxContainer.new()
		tr.add_theme_constant_override("separation", 10)
		tr.alignment = BoxContainer.ALIGNMENT_CENTER
		_body.add_child(tr)
		for i in tiles.size():
			var d: Array = tiles[i]
			var tl := tile(tr, String(d[0]), String(d[1]), String(d[2]) if d.size() > 2 else "", d.size() > 3 and bool(d[3]), 118.0 if tiles.size() > 4 else 150.0)
			_appear(tl, 0.04 * i)
	_build_columns(spec)
	if String(spec.get("footnote", "")) != "":
		var f := Hud._label(_body, String(spec.footnote), UiTheme.MIN_TEXT, UiTheme.MUTED)
		f.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		f.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		f.custom_minimum_size = Vector2(WIDTH - 90.0, 0)
	_build_buttons(spec.get("buttons", []))
	_fit.call_deferred()


## Les trois blocs côte à côte (un bloc sans ligne n'existe pas).
func _build_columns(spec: Dictionary) -> void:
	var cols: Array = []
	for c in COLUMNS:
		var rows: Array = spec.get(String(c[0]), [])
		if not rows.is_empty():
			cols.append([c, rows])
	if cols.is_empty():
		return
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_child(_scroll)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 14)
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(h)
	for i in cols.size():
		var c: Array = cols[i][0]
		var card := PanelContainer.new()
		var accent: Color = c[2]
		card.add_theme_stylebox_override("panel", UiTheme.flat_box(Color(0.05, 0.045, 0.1, 0.92), Color(accent, 0.55), 1, 10, false))
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.custom_minimum_size = Vector2(250 if cols.size() > 1 else 460, 0)
		if cols.size() == 1:
			card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		h.add_child(card)
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 6)
		card.add_child(v)
		var head := Hud._label(v, String(c[1]).to_upper(), 17, accent)
		head.add_theme_font_override("font", UiTheme.bold_font())
		var bar := ColorRect.new()
		bar.color = Color(accent, 0.8)
		bar.custom_minimum_size = Vector2(0, 2)
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(bar)
		for r in cols[i][1]:
			_add_row(v, r, accent)
		_appear(card, 0.2 + 0.12 * i)


func _add_row(parent: Control, r, accent: Color) -> void:
	var d: Dictionary = r if r is Dictionary else row(String(r))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	if String(d.get("tip", "")) != "":
		h.tooltip_text = String(d.tip)
		h.mouse_filter = Control.MOUSE_FILTER_PASS
	else:
		h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(h)
	var ic_name := String(d.get("icon", ""))
	if ic_name != "":
		var ic := TextureRect.new()
		ic.texture = UiTheme.texture(Items.material_icon(ic_name)) if ic_name in ICON_MATERIALS else MenuWidgets.icon(ic_name)
		ic.modulate = Color.WHITE if ic_name in ICON_MATERIALS else MenuWidgets.ICON_TINT
		ic.custom_minimum_size = Vector2(22, 22)
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ic.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_child(ic)
	var l := Hud._label(h, String(d.get("text", "")), 16, UiTheme.TEXT)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(110, 0)
	if String(d.get("value", "")) != "":
		var vl := Hud._label(h, String(d.value), 17, accent.lightened(0.15))
		vl.add_theme_font_override("font", UiTheme.bold_font())
		vl.size_flags_vertical = Control.SIZE_SHRINK_BEGIN


func _build_buttons(list: Array) -> void:
	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 16)
	_body.add_child(btn_row)
	var locked: Array[Button] = []
	for d in list:
		var primary := bool(d.get("primary", false))
		var b := MenuWidgets.gold_button(String(d.text), 24, Vector2(330, 62)) if primary else MenuWidgets.glass_button(String(d.text), 22, Vector2(300, 62))
		b.add_theme_stylebox_override("disabled", UiTheme.flat_box(Color(0.1, 0.09, 0.16, 0.8), Color(0.3, 0.28, 0.4), 1, 14 if primary else 12, false))
		b.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.35))
		var cb: Callable = d.get("call", Callable())
		b.pressed.connect(func():
			if cb.is_valid():
				cb.call())
		btn_row.add_child(b)
		buttons.append(b)
		if bool(d.get("disabled", false)):
			b.disabled = true
		else:
			b.disabled = true
			locked.append(b)
	# anti-appui : un bouton enfoncé en pleine fin de combat ne doit rien valider
	get_tree().create_timer(LOCK_SECS, true, false, true).timeout.connect(func():
		for b in locked:
			if is_instance_valid(b):
				b.disabled = false)


## Les blocs défilent si l'écran est trop petit (liste de gains très longue) ; sinon ils prennent leur hauteur.
func _fit() -> void:
	if _scroll == null:
		return
	var inner := _scroll.get_child(0) as Control
	var room := 400.0
	_scroll.custom_minimum_size.y = minf(inner.get_combined_minimum_size().y, room)


func _appear(c: Control, delay: float) -> void:
	c.modulate.a = 0.0
	var tw := c.create_tween()
	tw.tween_interval(delay)
	tw.tween_property(c, "modulate:a", 1.0, 0.25)
