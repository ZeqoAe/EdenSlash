class_name TrainingCards
extends CanvasLayer
## Zone d'entraînement : toutes les cartes en grand (de la classe, communes, certificats),
## avec leur effet en chiffres au niveau choisi, et le niveau réglable directement
## (−, +, Max, retirer). Le jeu est en pause pendant que la fenêtre est ouverte.

signal closed

const COLS := 5

var player: Player
var _grid: GridContainer
var _search: LineEdit
var _filter: OptionButton
var _count: Label
var _shown: Array = []  # cartes affichées (bouton Tout au max)


func _init(p: Player) -> void:
	player = p
	layer = 30
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.01, 0.05, 0.86)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiTheme.panel_box(20, 16))
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.offset_left = 30
	panel.offset_top = 24
	panel.offset_right = -30
	panel.offset_bottom = -24
	add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	panel.add_child(v)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	v.add_child(top)
	var t := Label.new()
	t.text = "Toutes les cartes"
	UiTheme.title(t, 28)
	top.add_child(t)
	_count = Hud._label(top, "", 14, UiTheme.MUTED)
	_count.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_search = LineEdit.new()
	_search.placeholder_text = "Chercher (nom, effet : zone, critique, brûlure…)"
	_search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_search.text_changed.connect(func(_t): refresh())
	top.add_child(_search)
	_filter = OptionButton.new()
	for f in ["Toutes", "De la classe", "Communes", "Certificats", "Prises"]:
		_filter.add_item(f)
	_filter.focus_mode = Control.FOCUS_NONE
	_filter.item_selected.connect(func(_i): refresh())
	top.add_child(_filter)
	_btn(top, "Tout au max", func():
		# toutes les cartes affichées (filtre et recherche) au niveau maximal
		for c in _shown:
			if not c.get("instant", false):
				Run.passives[c.id] = mini(int(c.get("max", 1)), Cards.MAX_LEVEL)
				Run.passive_power[c.id] = float(Run.passives[c.id])
		_changed())
	_btn(top, "Tout retirer", func():
		Run.passives.clear()
		Run.passive_power.clear()
		_changed())
	_btn(top, "✕  Fermer (Échap)", close_ui)
	Hud._label(v, "Le niveau d'une carte multiplie son effet (comme des cartes communes prises plusieurs fois). Les chiffres affichés sont ceux du niveau actuel ; à 0, ceux d'une carte.", 13, UiTheme.MUTED).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(sc)
	_grid = GridContainer.new()
	_grid.columns = COLS
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid.add_theme_constant_override("h_separation", 10)
	_grid.add_theme_constant_override("v_separation", 10)
	sc.add_child(_grid)
	get_tree().paused = true
	if "--training-cards" in OS.get_cmdline_user_args():
		_search.text = "zone"
	refresh()


func close_ui() -> void:
	get_tree().paused = false
	closed.emit()
	queue_free()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") or (event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE):
		close_ui()
		get_viewport().set_input_as_handled()


func _btn(parent: Control, text: String, cb: Callable, w := 0.0) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(w, 34)
	b.pressed.connect(cb)
	parent.add_child(b)
	return b


## [d, groupe] : cartes de la classe, communes, certificats.
func _entries() -> Array:
	var out: Array = []
	for d in Cards.class_cards(Run.class_id):
		out.append([d, "class"])
	for d in Boons.all():
		out.append([d, "common"])
	for d in Run.certificate_pool():
		out.append([d, "cert"])
	# les cartes prises d'abord (ordre d'origine conservé sinon)
	var taken := out.filter(func(e): return Run.passives.has(e[0].id))
	return taken + out.filter(func(e): return not Run.passives.has(e[0].id))


func _text_of(d: Dictionary) -> String:
	var pw := Run.power(String(d.id))
	var lines: PackedStringArray = Cards.stat_lines(d, 0.0, pw if pw > 0.0 else 1.0)
	for pr in Boons.procs_of(d, pw if pw > 0.0 else 1.0):
		lines.append(Procs.describe(pr))
	return "\n".join(lines)


func refresh() -> void:
	for c in _grid.get_children():
		c.queue_free()
	var q := _search.text.strip_edges().to_lower()
	var f := _filter.selected
	var shown := 0
	var taken := 0
	_shown = []
	for e in _entries():
		var d: Dictionary = e[0]
		var group := String(e[1])
		var n := int(Run.passives.get(d.id, 0))
		if n > 0:
			taken += 1
		if f == 1 and group != "class" or f == 2 and group != "common" or f == 3 and group != "cert" or f == 4 and n <= 0:
			continue
		if q != "" and not (String(d.name) + " " + String(d.get("desc", "")) + " " + _text_of(d)).to_lower().contains(q):
			continue
		_grid.add_child(_tile(d, group))
		_shown.append(d)
		shown += 1
	_count.text = "%d cartes · %d prises" % [shown, taken]


func _tile(d: Dictionary, group: String) -> Control:
	var id := String(d.id)
	var n := int(Run.passives.get(id, 0))
	var mx := 99 if d.get("instant", false) else mini(int(d.get("max", 1)), Cards.MAX_LEVEL)
	var rar: Dictionary = Boons.RARITY.get(String(d.get("rarity", "common")), Boons.RARITY.common)
	var p := PanelContainer.new()
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p.custom_minimum_size = Vector2(0, 150)
	p.add_theme_stylebox_override("panel", UiTheme.flat_box(Color(0.12, 0.09, 0.2, 0.97) if n > 0 else Color(0.07, 0.06, 0.12, 0.95), UiTheme.GOLD if n > 0 else rar.color.darkened(0.35), 2 if n > 0 else 1, 10))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	p.add_child(v)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	v.add_child(h)
	var ic := TextureRect.new()
	ic.texture = UiTheme.texture(String(d.get("icon", Boons.ICONS.get(id, ""))))
	ic.custom_minimum_size = Vector2(40, 40)
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	h.add_child(ic)
	var hv := VBoxContainer.new()
	hv.add_theme_constant_override("separation", 0)
	hv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(hv)
	var name := Hud._label(hv, String(d.name), 15, rar.color)
	name.add_theme_font_override("font", UiTheme.bold_font())
	name.clip_text = true
	var kind: String = {"class": "Carte de sort", "cert": "Certificat %s" % String(d.get("cert_class", "")), "common": String(rar.name)}.get(group, "")
	Hud._label(hv, "%s · niveau %d / %d" % [kind, n, mx] if not d.get("instant", false) else "%s · effet immédiat" % kind, 12, Color(1, 0.85, 0.45) if n > 0 else UiTheme.MUTED)
	var desc := RichTextLabel.new()
	desc.bbcode_enabled = true
	desc.fit_content = true
	desc.scroll_active = false
	desc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	desc.add_theme_font_size_override("normal_font_size", 12)
	desc.add_theme_font_size_override("bold_font_size", 12)
	var eff := _text_of(d)
	desc.text = "[color=#c8c8d4]%s[/color]%s" % [String(d.get("desc", "")), ("\n[color=#9fd0ff]%s%s[/color]" % ["" if n > 0 else "Par carte : ", eff]) if eff != "" else ""]
	v.add_child(desc)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	v.add_child(row)
	if d.get("instant", false):
		_btn(row, "Déclencher", func():
			Run.apply_card({"type": "passive", "id": id, "tier": "common", "mult": 1.0})
			_changed()).size_flags_horizontal = Control.SIZE_EXPAND_FILL
		return p
	_btn(row, "0", func(): _set_level(id, 0), 36).disabled = n <= 0
	_btn(row, "−", func(): _set_level(id, n - 1), 36).disabled = n <= 0
	var lv := Hud._label(row, str(n), 15, Color.WHITE)
	lv.custom_minimum_size = Vector2(28, 0)
	lv.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_btn(row, "+", func(): _set_level(id, n + 1), 36).disabled = n >= mx
	_btn(row, "Max", func(): _set_level(id, mx), 54).disabled = n >= mx
	return p


## Niveau [param n] de la carte (puissance = n cartes communes).
func _set_level(id: String, n: int) -> void:
	if n <= 0:
		Run.passives.erase(id)
		Run.passive_power.erase(id)
	else:
		Run.passives[id] = n
		Run.passive_power[id] = float(n)
	_changed()


func _changed() -> void:
	if player:
		player.recalc_stats()
	refresh()
