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
##     "build": [...],                                    # (Survivant) le build final : mêmes lignes, bloc bleu
##     "footnote": "",
##     "stars": [{"label": "Le boss tombe", "done": true, "new": true, "tip": ""}],   # objectifs ★ / ☆ (lot DNG-1)
##     "loot": [ResultsPanel.loot_entry(objet)],          # butin montré en cases (pièce, niveau, rareté) ; "missing" : la ligne dessous
##     "defeat": HitLog.report(),                         # « Ce qui t'a battu » (coups des 8 dernières secondes, conseil) ; "defeat_note"
##     "buttons": [{"text": "Rejouer", "primary": true, "call": func(): ...}, {"text": "Retour au lobby", "call": ...}],
## })
## [/codeblock]
## Une ligne de bloc : [method row] (texte, valeur à droite, infobulle, icône). Un bloc vide n'est pas affiché.
## Les gains se révèlent en ~1,6 s : les nombres montent jusqu'à leur valeur et le plus gros gain (la valeur « +N »
## la plus haute) est entouré d'or, avec un éclat à l'arrivée. Une touche, un clic ou un bouton de manette montre
## tout de suite le résultat final ([method finish_now]).

const WIN := UiTheme.GOLD
const LOSE := Color(0.95, 0.42, 0.38)
const INFO := Color(0.55, 0.85, 1.0)
const GAINED := UiTheme.GOLD
const KEPT := Color(0.5, 0.95, 0.58)
const LOST := Color(1.0, 0.5, 0.45)
const WIDTH := 1040.0
const LOCK_SECS := 0.45  # les boutons n'agissent pas tout de suite : un appui de fin de combat ne doit rien valider
const BUILD := INFO
const COLUMNS := [["gained", "Gagné", GAINED], ["kept", "Gardé", KEPT], ["lost", "Perdu", LOST], ["build", "Ton build", BUILD]]
const ICON_MATERIALS := ["gold", "keys", "crystal"]
const COUNT_MIN := 10  # en dessous, un nombre apparaît tel quel (compter de 0 à 3 ne dit rien)
const COUNT_SECS := 0.8
const _COUNT_RE := "^([+\\-×x]?)(\\d{1,3}(?: \\d{3})+|\\d+)(.*)$"

var buttons: Array[Button] = []  # (tests) boutons de la rangée du bas, dans l'ordre de la description
var _scroll: ScrollContainer
var _body: VBoxContainer
var _counters: Array = []  # {label, prefix, n, suffix, grouped, delay, final} : les nombres qui montent
var _fades: Array = []  # blocs qui apparaissent (finish_now les montre d'un coup)
var _tweens: Array = []
var _best: Dictionary = {}  # la ligne mise en avant (la même instance que dans la description)
var _best_box: PanelContainer
var _quest_box: PanelContainer  # la ligne « Pour ta quête » (spec.quest)
var _panel: PanelContainer
var defeat_box: PanelContainer  # (tests) le bloc « Ce qui t'a battu »
var loot_box: Control  # (tests) le butin en cases
var _title: Label
var _orn: Control
var _footnote: Label
var _loot_row: Control
var _defeat_note: Label
## Hauteur minimale de la liste des blocs (elle défile en dessous) ; sous cette place, le bilan se resserre (_compact).
const MIN_LIST := 110.0
var _animating := false
var _col_index := 0  # colonne en cours de construction (décale la montée des nombres)


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
	spec = HeroLevel.decorate(spec)  # niveau de héros gagné par la partie (lot H1), une fois
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
	_panel = panel
	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", 12)
	panel.add_child(_body)
	_best = best_row(spec)
	var tone: Color = {"win": WIN, "lose": LOSE, "info": INFO}.get(String(spec.get("tone", "info")), INFO)
	var t := Label.new()
	UiTheme.title(t, 50, tone)
	t.text = String(spec.get("title", ""))
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_body.add_child(t)
	_title = t
	var orn := MenuWidgets.Ornament.new()
	orn.custom_minimum_size = Vector2(0, 18)
	_body.add_child(orn)
	_orn = orn
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
			_register_count((tl.get_child(0) as Control).get_child(0) as Label, String(d[0]), 0.15 + 0.07 * i)
	if not (spec.get("stars", []) as Array).is_empty():
		_add_stars(spec.stars)
	if not (spec.get("defeat", {}) as Dictionary).is_empty():
		_add_defeat(spec.defeat, String(spec.get("defeat_note", "")))
	if not (spec.get("loot", []) as Array).is_empty() or String(spec.get("missing", "")) != "":
		_add_loot(spec.get("loot", []), String(spec.get("missing", "")))
	_build_columns(spec)
	if String(spec.get("quest", "")) != "":
		_add_quest(String(spec.quest))
	if String(spec.get("footnote", "")) != "":
		var f := Hud._label(_body, String(spec.footnote), UiTheme.MIN_TEXT, UiTheme.MUTED)
		f.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		f.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		f.custom_minimum_size = Vector2(WIDTH - 90.0, 0)
		_footnote = f
	_build_buttons(spec.get("buttons", []))
	_fit.call_deferred()
	_start_animation()


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
		_col_index = i
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
	var is_best := not _best.is_empty() and is_same(d, _best)
	if is_best:  # le plus gros gain : sur un fond doré, valeur plus grande
		_best_box = PanelContainer.new()
		var sb := UiTheme.flat_box(Color(accent, 0.16), Color(accent, 0.9), 1, 6, false)
		sb.content_margin_top = 3
		sb.content_margin_bottom = 3
		_best_box.add_theme_stylebox_override("panel", sb)
		_best_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		parent.add_child(_best_box)
		_best_box.add_child(h)
	else:
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
		var vl := Hud._label(h, String(d.value), 20 if is_best else 17, accent.lightened(0.35 if is_best else 0.15))
		vl.add_theme_font_override("font", UiTheme.bold_font())
		vl.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		_register_count(vl, String(d.value), 0.5 + 0.12 * _col_index, true)


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
## Ligne « Pour ta quête » : ce que ce gain change pour l'équipement des classes, et la suite (Compass.after).
func _add_quest(text: String) -> void:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UiTheme.flat_box(Color(0.1, 0.08, 0.04, 0.9), Color(UiTheme.GOLD, 0.7), 1, 10, false))
	p.custom_minimum_size = Vector2(WIDTH - 90.0, 0)
	p.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	p.add_child(h)
	var ic := TextureRect.new()
	ic.texture = MenuWidgets.icon("pin")
	ic.modulate = UiTheme.GOLD
	ic.custom_minimum_size = Vector2(22, 22)
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(ic)
	var tag := Hud._label(h, "Ta quête", 15, UiTheme.GOLD)
	tag.add_theme_font_override("font", UiTheme.bold_font())
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := Hud._label(h, text, 16, UiTheme.TEXT)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_body.add_child(p)
	_quest_box = p
	_appear(p, 0.8)


func _fit() -> void:
	# la liste prend la place qui reste (mesurée : titre, tuiles, blocs du lot DNG-1, quête, boutons) : une fenêtre de 720 px
	# la raccourcit (elle défile) ; s'il ne reste pas MIN_LIST, le bilan se resserre d'abord (_compact)
	var vh := get_viewport().get_visible_rect().size.y
	if _scroll != null:
		_scroll.custom_minimum_size.y = 0.0
	for step in 5:
		if vh - _other_height() - 36.0 >= (MIN_LIST if _scroll != null else 0.0):
			break
		_compact(step)
	if _scroll == null:
		return
	var inner := _scroll.get_child(0) as Control
	var room := clampf(vh - _other_height() - 36.0, MIN_LIST, 400.0)
	_scroll.custom_minimum_size.y = minf(inner.get_combined_minimum_size().y, room)


func _other_height() -> float:
	return _panel.get_combined_minimum_size().y if _panel != null else 450.0


## Le bilan se resserre, étape [param step] (fenêtre basse, bilan riche) : titre plus petit et sans ornement, sans note de
## bas de page, sans les cases du butin (il est aussi dans « Gardé »), sans la note de meilleur pourcentage, notes réduites à une.
func _compact(step: int) -> void:
	match step:
		0:
			_body.add_theme_constant_override("separation", 6)
			if _orn != null:
				_orn.visible = false
			if _title != null:
				_title.add_theme_font_size_override("font_size", 36)
		1:
			if _footnote != null:
				_footnote.visible = false
		2:
			if _loot_row != null:
				_loot_row.visible = false
		3:
			if _defeat_note != null:
				_defeat_note.visible = false
		4:
			var seen := 0
			for c in _body.get_children():
				if c is Label and c != _title and c != _footnote and (c as Label).get_theme_color("font_color") == UiTheme.GOLD:
					seen += 1
					if seen > 1:
						c.visible = false


# --- blocs du lot DNG-1 : objectifs, butin en cases, « Ce qui t'a battu » ---------------------
## Case de butin d'un vrai objet (pièce, niveau, rareté ; l'infobulle le décrit).
static func loot_entry(item: Dictionary) -> Dictionary:
	var slot := String(item.get("slot", ""))
	return {"name": Items.display_name(item), "sub": "%s · Nv %d" % [String(Items.SLOT_NAMES.get(slot, slot)), int(item.get("level", 1))],
		"rarity": int(item.get("rarity", 0)), "tip": Items.describe(item, false) if item.has("base") else "", "item": item}


func _add_stars(list: Array) -> void:
	var h := HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_theme_constant_override("separation", 22)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_body.add_child(h)
	for s in list:
		var done := bool(s.get("done", false))
		var l := Hud._label(h, "%s %s%s" % ["★" if done else "☆", String(s.get("label", "")), " · nouvelle" if bool(s.get("new", false)) else ""], 18,
			UiTheme.GOLD if done else UiTheme.MUTED)
		if String(s.get("tip", "")) != "":
			l.tooltip_text = String(s.tip)
			l.mouse_filter = Control.MOUSE_FILTER_PASS
	_appear(h, 0.1)


func _add_loot(list: Array, missing: String) -> void:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_body.add_child(v)
	loot_box = v
	if not list.is_empty():
		var h := HBoxContainer.new()
		h.alignment = BoxContainer.ALIGNMENT_CENTER
		h.add_theme_constant_override("separation", 10)
		h.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(h)
		_loot_row = h
		var shown := list.slice(0, 5)
		for e in shown:
			var col: Color = Items.RARITIES[clampi(int(e.get("rarity", 0)), 0, Items.RARITIES.size() - 1)].color
			var p := PanelContainer.new()
			p.add_theme_stylebox_override("panel", UiTheme.flat_box(Color(0.06, 0.05, 0.11, 0.95), col, 2, 8, false))
			p.custom_minimum_size = Vector2(170, 0)
			if String(e.get("tip", "")) != "":
				p.tooltip_text = String(e.tip)
			else:
				p.mouse_filter = Control.MOUSE_FILTER_IGNORE
			h.add_child(p)
			var c := VBoxContainer.new()
			c.add_theme_constant_override("separation", 0)
			c.mouse_filter = Control.MOUSE_FILTER_IGNORE
			p.add_child(c)
			var n := Hud._label(c, String(e.get("name", "")), 15, col.lightened(0.2))
			n.add_theme_font_override("font", UiTheme.bold_font())
			n.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			n.custom_minimum_size = Vector2(150, 0)
			n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			var sub := Hud._label(c, String(e.get("sub", "")), UiTheme.MIN_TEXT, UiTheme.MUTED)
			sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		if list.size() > shown.size():
			Hud._label(h, "+%d" % (list.size() - shown.size()), 20, UiTheme.MUTED).size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if missing != "":
		var m := Hud._label(v, missing, 16, KEPT)
		m.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		m.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		m.custom_minimum_size = Vector2(WIDTH - 90.0, 0)
	_appear(v, 0.15)


## « Ce qui t'a battu » : les coups des dernières secondes (HitLog.report), la mécanique fautive et son conseil.
func _add_defeat(rep: Dictionary, note: String) -> void:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UiTheme.flat_box(Color(0.12, 0.04, 0.05, 0.92), Color(LOSE, 0.75), 1, 10, false))
	p.custom_minimum_size = Vector2(WIDTH - 90.0, 0)
	p.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_body.add_child(p)
	defeat_box = p
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(v)
	var head := HBoxContainer.new()
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(head)
	var t := Hud._label(head, "CE QUI T'A BATTU", 17, LOSE)
	t.add_theme_font_override("font", UiTheme.bold_font())
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var hits := int(rep.get("hits", 0))
	Hud._label(head, "les %d dernières secondes · %d coup%s" % [roundi(float(rep.get("window", HitLog.WINDOW))), hits, "s" if hits > 1 else ""],
		UiTheme.MIN_TEXT, UiTheme.MUTED)
	for l in defeat_lines(rep):
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 8)
		h.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(h)
		var a := Hud._label(h, String(l.text), 16, UiTheme.TEXT)
		a.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		a.clip_text = true
		var b := Hud._label(h, String(l.value), 17, LOST)
		b.add_theme_font_override("font", UiTheme.bold_font())
	if String(rep.get("tip", "")) != "":
		var tip := Hud._label(v, String(rep.tip), 16, UiTheme.GOLD)
		tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		tip.custom_minimum_size = Vector2(WIDTH - 130.0, 0)
	if note != "":
		_defeat_note = Hud._label(v, note, UiTheme.MIN_TEXT, UiTheme.MUTED)
	_appear(p, 0.1)


## Lignes du bloc « Ce qui t'a battu » : {text (« Pluie de météores · Latif »), value (« −48 % PV · coup final »)}.
static func defeat_lines(rep: Dictionary) -> Array:
	var out: Array = []
	for l in rep.get("lines", []):
		var mech := String(l.get("mech", ""))
		var text := ("%s · %s" % [mech, String(l.name)]) if mech != "" else String(l.name)
		if int(l.get("count", 1)) > 1:
			text += " (×%d)" % int(l.count)
		out.append({"text": text, "value": "−%s PV%s" % [HitLog.pct(float(l.share)), " · coup final" if bool(l.get("final", false)) else ""]})
	return out


func _appear(c: Control, delay: float) -> void:
	c.modulate.a = 0.0
	_fades.append(c)
	var tw := c.create_tween()
	tw.tween_interval(delay)
	tw.tween_property(c, "modulate:a", 1.0, 0.25)
	_tweens.append(tw)


# --- animation des gains ---------------------------------------------------------------------
## Le plus gros gain : la ligne « +N » la plus haute du bloc Gardé (le butin qu'on emporte : insignes, cristaux), à défaut
## du bloc Gagné (la progression). Il faut au moins deux gains chiffrés pour qu'une mise en avant ait un sens.
static func best_row(spec: Dictionary) -> Dictionary:
	var best := {}
	var counted := 0
	for k in ["kept", "gained"]:  # le butin emporté passe avant la progression : on ne compare pas des maîtrises à des insignes
		var best_n := -1
		var best_in := {}
		for r in spec.get(k, []):
			if not r is Dictionary:
				continue
			var p := _parse_count(String((r as Dictionary).get("value", "")))
			if p.is_empty() or p.prefix != "+":
				continue
			counted += 1
			if int(p.n) > best_n:
				best_n = int(p.n)
				best_in = r
		if best.is_empty():
			best = best_in
	return best if counted >= 2 else {}


## « +1 250 » -> {prefix "+", n 1250, suffix "", grouped true} ; « 05:23 », « 1,5 » ou un texte -> {} (pas de compteur).
static func _parse_count(text: String, min_n := 0) -> Dictionary:
	var m := RegEx.create_from_string(_COUNT_RE).search(text)
	if m == null:
		return {}
	var suffix := m.get_string(3)
	if suffix != "" and not suffix[0] in [" ", "%", "×"]:
		return {}
	var digits := m.get_string(2)
	var n := int(digits.replace(" ", ""))
	if n < min_n:
		return {}
	return {"prefix": m.get_string(1), "n": n, "suffix": suffix, "grouped": digits.contains(" ")}


static func _count_text(c: Dictionary, t: float) -> String:
	var v := roundi(float(c.n) * t)
	return "%s%s%s" % [c.prefix, number(v) if c.grouped else str(v), c.suffix]


## Fait monter le nombre affiché par [param label] jusqu'à [param text] (s'il s'y prête) : la largeur est celle du
## résultat final, pour que rien ne bouge pendant la montée.
func _register_count(label: Label, text: String, delay: float, right := false) -> void:
	var c := _parse_count(text, COUNT_MIN)
	if c.is_empty():
		return
	var font := label.get_theme_font("font")
	var fs := label.get_theme_font_size("font_size")
	label.custom_minimum_size.x = maxf(label.custom_minimum_size.x, font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 2.0)
	if right:
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	c["label"] = label
	c["delay"] = delay
	c["final"] = text
	_counters.append(c)
	label.text = _count_text(c, 0.0)


func _start_animation() -> void:
	if _counters.is_empty():
		return
	_animating = true
	var total := 0.0
	for c in _counters:
		total = maxf(total, float(c.delay) + COUNT_SECS)
		var tw := create_tween()
		tw.tween_interval(float(c.delay))
		var step := func(t: float):
			if is_instance_valid(c.label):
				c.label.text = _count_text(c, t)
		tw.tween_method(step, 0.0, 1.0, COUNT_SECS).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		_tweens.append(tw)
	var end := create_tween()
	end.tween_interval(total + 0.05)
	end.tween_callback(func():
		_animating = false
		_flash_best(true))
	_tweens.append(end)


## Montre le résultat final tout de suite (touche, clic ou bouton de manette pendant la montée).
func finish_now() -> void:
	if not _animating:
		return
	_animating = false
	for tw in _tweens:
		if tw is Tween and (tw as Tween).is_valid():
			(tw as Tween).kill()
	_tweens.clear()
	for c in _counters:
		if is_instance_valid(c.label):
			c.label.text = String(c.final)
	for f in _fades:
		if is_instance_valid(f):
			(f as Control).modulate.a = 1.0
	_flash_best(false)


## Éclat doré sur le plus gros gain, une fois que tout est arrivé (silencieux si on a passé l'animation).
func _flash_best(with_sound: bool) -> void:
	if _best_box == null or not is_instance_valid(_best_box):
		return
	if with_sound:
		Sfx.ui("confirm", -9.0)
	_best_box.self_modulate = Color(2.2, 1.9, 1.2)
	var tw := _best_box.create_tween()
	tw.tween_property(_best_box, "self_modulate", Color.WHITE, 0.6)


func _input(event: InputEvent) -> void:
	if _animating and event.is_pressed() and not event.is_echo() \
			and (event is InputEventKey or event is InputEventMouseButton or event is InputEventJoypadButton):
		finish_now()  # sans consommer l'événement : un bouton dégelé garde son clic
