class_name RivalEditor
extends CanvasLayer
## Éditeur d'adversaire du duel (ouvert depuis le menu Duel du lobby) : sa classe et son
## aperçu 3D, ses 10 pièces d'équipement tirées du catalogue d'Eden (rareté, amélioration ;
## trophée compris), son apparence (tenue, tête, dos), ses certificats (7 au plus), ses 4
## sorts, ses multiplicateurs de PV et de dégâts, et ses stats calculées comme pour un héros.
## Plusieurs adversaires s'enregistrent par nom (RivalBuilds) ; « Utiliser pour le duel » le
## choisit pour le prochain duel.

const SLOTS := ["weapon", "head", "chest", "legs", "gloves", "boots", "back", "necklace", "ring", "trophy"]
const LOOK := [["body", "Tenue"], ["head", "Tête"], ["back", "Dos"]]

var build: Dictionary
var level := 10
var on_use: Callable

var _name: LineEdit
var _saved: OptionButton
var _class_btn: Button
var _preview: EquipmentPage.HeroPreview
var _stats: RichTextLabel
var _gear_box: VBoxContainer
var _right: VBoxContainer
var _msg: Label
var _picker: Control


## Ouvre l'éditeur sur [param b] (une copie) au niveau [param lv] ; [param use] reçoit le build
## quand on clique « Utiliser pour le duel ».
static func open(anchor: Node, b: Dictionary, lv: int, use: Callable) -> RivalEditor:
	var e := RivalEditor.new()
	e.build = b.duplicate(true)
	e.level = lv
	e.on_use = use
	anchor.get_tree().current_scene.add_child(e)
	return e


func _ready() -> void:
	layer = 55
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.01, 0.05, 0.85)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiTheme.flat_box(Color(0.05, 0.04, 0.1, 0.98), UiTheme.GOLD, 2, 12))
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.offset_left = 24
	panel.offset_top = 20
	panel.offset_right = -24
	panel.offset_bottom = -20
	root.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	panel.add_child(v)
	# barre du haut : charger, nom, enregistrer, supprimer, utiliser, fermer
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	v.add_child(top)
	var t := Hud._label(top, "Éditeur d'adversaire", 26, UiTheme.GOLD)
	t.add_theme_font_override("font", UiTheme.title_font())
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(sp)
	_saved = OptionButton.new()
	_saved.focus_mode = Control.FOCUS_NONE
	_saved.custom_minimum_size = Vector2(220, 40)
	_saved.item_selected.connect(_on_load)
	top.add_child(_saved)
	_name = LineEdit.new()
	_name.custom_minimum_size = Vector2(220, 40)
	_name.placeholder_text = "Nom de l'adversaire"
	_name.text_changed.connect(func(x): build["name"] = x)
	top.add_child(_name)
	_btn(top, "Enregistrer", func():
		if String(build.name).strip_edges() == "":
			build["name"] = "Adversaire"
		RivalBuilds.store(build)
		_msg.text = "« %s » enregistré" % build.name
		_refresh_saved(), 130)
	_btn(top, "Supprimer", func():
		RivalBuilds.remove(String(build.name))
		_msg.text = "« %s » supprimé" % build.name
		_refresh_saved(), 120)
	var use := MenuWidgets.gold_button("Utiliser pour le duel", 18, Vector2(240, 40))
	use.pressed.connect(func():
		if String(build.name).strip_edges() != "":
			RivalBuilds.store(build)
		if on_use.is_valid():
			on_use.call(build.duplicate(true))
		queue_free())
	top.add_child(use)
	_btn(top, "Fermer", queue_free, 110)
	_msg = Hud._label(v, "", 14, UiTheme.BUFF)
	# corps : classe et aperçu | équipement | sorts, apparence, certificats
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 14)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(body)
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(320, 0)
	left.add_theme_constant_override("separation", 8)
	body.add_child(left)
	_class_btn = MenuWidgets.glass_button("", 16, Vector2(0, 42))
	_class_btn.pressed.connect(func(): HeroPages.class_menu(_class_btn, String(build["class"]), func(c):
		build["class"] = c
		build["spells"] = [0, 0, 0, 0]
		_refresh_all()))
	left.add_child(_class_btn)
	_preview = EquipmentPage.HeroPreview.new()
	_preview.custom_minimum_size = Vector2(320, 360)
	left.add_child(_preview)
	_stats = RichTextLabel.new()
	_stats.bbcode_enabled = true
	_stats.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_stats.add_theme_font_size_override("normal_font_size", 14)
	_stats.add_theme_font_size_override("bold_font_size", 14)
	left.add_child(_stats)
	var mid_scroll := ScrollContainer.new()
	mid_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(mid_scroll)
	_gear_box = VBoxContainer.new()
	_gear_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_gear_box.add_theme_constant_override("separation", 6)
	mid_scroll.add_child(_gear_box)
	var right_scroll := ScrollContainer.new()
	right_scroll.custom_minimum_size = Vector2(430, 0)
	right_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(right_scroll)
	_right = VBoxContainer.new()
	_right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_right.add_theme_constant_override("separation", 6)
	right_scroll.add_child(_right)
	_refresh_saved()
	_refresh_all()


func _btn(parent: Control, text: String, cb: Callable, width: float) -> Button:
	var b := MenuWidgets.glass_button(text, 15, Vector2(width, 40))
	b.pressed.connect(cb)
	parent.add_child(b)
	return b


func _section(parent: Control, text: String) -> void:
	var l := Label.new()
	l.text = text
	UiTheme.title(l, 17)
	parent.add_child(l)


func _refresh_saved() -> void:
	_saved.clear()
	_saved.add_item("Charger un adversaire ▾")
	_saved.add_item("+ Nouvel adversaire")
	for b in RivalBuilds.list():
		_saved.add_item(String(b.get("name", "?")))
	_saved.select(0)


func _on_load(i: int) -> void:
	if i == 1:
		build = RivalBuilds.blank(String(build.get("class", "warrior")))
	elif i >= 2:
		build = (RivalBuilds.list()[i - 2] as Dictionary).duplicate(true)
	_saved.select(0)
	_msg.text = ""
	_refresh_all()


func _refresh_all() -> void:
	var cid := String(build.get("class", "warrior"))
	_name.text = String(build.get("name", ""))
	_class_btn.text = "Classe : %s ▾" % GameData.class_data(cid).get("name_fr", cid)
	_refresh_gear()
	_refresh_right()
	_refresh_stats()


# --- équipement -------------------------------------------------------------------------------
func _refresh_gear() -> void:
	for c in _gear_box.get_children():
		c.queue_free()
	_section(_gear_box, "Équipement (catalogue d'Eden, niveau du duel %d)" % level)
	var gear: Dictionary = build.get("gear", {})
	for slot in SLOTS:
		var s: String = slot
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		_gear_box.add_child(row)
		var l := Hud._label(row, String(Items.SLOT_NAMES.get(s, s)), 14, UiTheme.TEXT)
		l.custom_minimum_size = Vector2(70, 0)
		var g: Dictionary = gear.get(s, {})
		var e: Dictionary = GameData.eden_by_id.get(int(g.get("id", 0)), {})
		var pick := Button.new()
		pick.focus_mode = Control.FOCUS_NONE
		pick.alignment = HORIZONTAL_ALIGNMENT_LEFT
		pick.clip_text = true
		pick.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		pick.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		pick.custom_minimum_size = Vector2(250, 44)
		pick.expand_icon = false
		pick.add_theme_constant_override("icon_max_width", 34)
		if e.is_empty():
			pick.text = "  — choisir dans le catalogue"
			pick.modulate = Color(1, 1, 1, 0.6)
		else:
			var r := int(g.get("rarity", e.rarity))
			pick.text = "  %s  · niv. %d" % [e.name, int(e.level)]
			pick.icon = UiTheme.texture(String(e.get("icon", "")))
			pick.add_theme_color_override("font_color", Items.RARITIES[clampi(r, 0, Items.RARITIES.size() - 1)].color)
		pick.pressed.connect(func(): _open_picker(s))
		row.add_child(pick)
		if not e.is_empty():
			var rar := OptionButton.new()
			rar.focus_mode = Control.FOCUS_NONE
			for rr in Items.RARITIES:
				rar.add_item(String(rr.name))
			rar.select(clampi(int(g.get("rarity", e.rarity)), 0, Items.RARITIES.size() - 1))
			rar.custom_minimum_size = Vector2(120, 0)
			rar.fit_to_longest_item = false
			rar.item_selected.connect(func(k):
				build.gear[s]["rarity"] = k
				_refresh_gear()
				_refresh_stats())
			row.add_child(rar)
			var up := SpinBox.new()
			up.min_value = 0
			up.max_value = Items.MAX_UPGRADE
			up.prefix = "+"
			up.value = int(g.get("upgrade", 0))
			up.custom_minimum_size = Vector2(70, 0)
			up.value_changed.connect(func(x):
				build.gear[s]["upgrade"] = int(x)
				_refresh_stats())
			row.add_child(up)
			var clr := Button.new()
			clr.text = "✕"
			clr.focus_mode = Control.FOCUS_NONE
			clr.custom_minimum_size = Vector2(40, 40)
			clr.tooltip_text = "Retirer la pièce"
			clr.pressed.connect(func():
				build.gear.erase(s)
				_refresh_gear()
				_refresh_stats())
			row.add_child(clr)


## Catalogue d'Eden pour l'emplacement [param slot] : recherche par nom, plus haut niveau d'abord.
func _open_picker(slot: String) -> void:
	if _picker:
		_picker.queue_free()
	var box := PanelContainer.new()
	box.add_theme_stylebox_override("panel", UiTheme.flat_box(Color(0.06, 0.05, 0.12, 0.99), UiTheme.GOLD, 2, 10))
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.custom_minimum_size = Vector2(720, 640)
	box.position = Vector2(-360, -320)
	get_child(0).add_child(box)
	_picker = box
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	box.add_child(v)
	Hud._label(v, "%s : catalogue d'Eden" % Items.SLOT_NAMES.get(slot, slot), 20, UiTheme.GOLD)
	var search := LineEdit.new()
	search.placeholder_text = "Chercher un objet (nom)…"
	v.add_child(search)
	var lst := ItemList.new()
	lst.size_flags_vertical = Control.SIZE_EXPAND_FILL
	lst.fixed_icon_size = Vector2i(32, 32)
	v.add_child(lst)
	var pool: Array = GameData.eden_items.filter(func(x): return String(x.get("slot", "")) == slot)
	pool.sort_custom(func(a, b): return int(a.level) > int(b.level))
	var ids: Array = []
	var fill := func(q: String):
		lst.clear()
		ids.clear()
		for x in pool:
			if q != "" and not String(x.name).to_lower().contains(q.to_lower()):
				continue
			var i := lst.add_item("%s  · niv. %d · %s%s" % [x.name, int(x.level), Items.RARITIES[clampi(int(x.rarity), 0, Items.RARITIES.size() - 1)].name,
				("  · " + String(GameData.weapon_type(String(x.get("wtype", ""))).get("name", ""))) if slot == "weapon" else ""],
				UiTheme.texture(String(x.get("icon", ""))))
			lst.set_item_custom_fg_color(i, Items.RARITIES[clampi(int(x.rarity), 0, Items.RARITIES.size() - 1)].color)
			ids.append(int(x.id))
			if ids.size() >= 600:
				break
	fill.call("")
	search.text_changed.connect(func(q): fill.call(q))
	var choose := func(i: int):
		var e: Dictionary = GameData.eden_by_id.get(int(ids[i]), {})
		if not build.has("gear"):
			build["gear"] = {}
		build.gear[slot] = {"id": int(ids[i]), "rarity": int(e.get("rarity", 0)), "upgrade": 0}
		box.queue_free()
		_picker = null
		_refresh_gear()
		_refresh_stats()
	lst.item_activated.connect(func(i): choose.call(i))
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 8)
	v.add_child(bar)
	_btn(bar, "Choisir", func():
		var sel := lst.get_selected_items()
		if not sel.is_empty():
			choose.call(sel[0]), 140)
	_btn(bar, "Annuler", func():
		box.queue_free()
		_picker = null, 120)
	search.grab_focus()


# --- sorts, apparence, certificats ---------------------------------------------------------------
func _refresh_right() -> void:
	for c in _right.get_children():
		c.queue_free()
	var cid := String(build.get("class", "warrior"))
	_section(_right, "Sorts")
	var choices := Duel.spell_choices(cid)
	if not build.has("spells"):
		build["spells"] = [0, 0, 0, 0]
	for i in 4:
		var ob := OptionButton.new()
		ob.focus_mode = Control.FOCUS_NONE
		ob.add_item("Sort %d : choix de l'IA" % (i + 1))
		var sel := 0
		for j in choices.size():
			ob.add_item(String(choices[j].name))
			ob.set_item_icon(j + 1, UiTheme.texture(String(choices[j].get("icon", ""))))
			if int(choices[j].id) == int(build.spells[i]):
				sel = j + 1
		ob.add_theme_constant_override("icon_max_width", 22)
		ob.select(sel)
		var slot := i
		ob.item_selected.connect(func(k):
			build.spells[slot] = int(choices[k - 1].id) if k > 0 else 0
			_refresh_stats())
		_right.add_child(ob)
	_section(_right, "Apparence")
	if not build.has("look"):
		build["look"] = {}
	for spec in LOOK:
		var cat: String = spec[0]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		_right.add_child(row)
		var l := Hud._label(row, String(spec[1]), 14, UiTheme.TEXT)
		l.custom_minimum_size = Vector2(60, 0)
		var ob := OptionButton.new()
		ob.focus_mode = Control.FOCUS_NONE
		ob.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		ob.add_item("Celle de la classe" if cat == "body" else "Aucun")
		var paths: Array = [""]
		var cos: Array = GameData.cosmetics.filter(func(x): return String(x.get("cat", "")) == cat and ResourceLoader.exists(String(x.get("outfit", ""))))
		cos.sort_custom(func(a, b): return String(a.name) < String(b.name))
		for x in cos:
			ob.add_item(String(x.name))
			paths.append(String(x.outfit))
		ob.select(maxi(0, paths.find(String(build.look.get(cat, "")))))
		ob.item_selected.connect(func(k):
			if k == 0:
				build.look.erase(cat)
			else:
				build.look[cat] = paths[k]
			_refresh_stats())
		row.add_child(ob)
	var certs: Array = build.get("certs", [])
	build["certs"] = certs
	_section(_right, "Certificats (%d / %d)" % [certs.size(), RivalBuilds.MAX_CERTS])
	var grid := GridContainer.new()
	grid.columns = 2
	_right.add_child(grid)
	for c in RivalBuilds.all_certificates():
		var key := String(c.key)
		var cb := CheckBox.new()
		cb.text = "%s (%s)" % [c.name, c.cls]
		cb.focus_mode = Control.FOCUS_NONE
		cb.clip_text = true
		cb.custom_minimum_size = Vector2(220, 0)
		cb.button_pressed = key in certs
		cb.tooltip_text = Run.certificate_card(key).get("desc", "")
		cb.toggled.connect(func(on):
			if on and not key in certs:
				if certs.size() >= RivalBuilds.MAX_CERTS:
					_msg.text = "%d certificats au plus." % RivalBuilds.MAX_CERTS
					cb.set_pressed_no_signal(false)
					return
				certs.append(key)
			elif not on:
				certs.erase(key)
			_refresh_stats())
		grid.add_child(cb)
	_section(_right, "Réglages")
	for spec in [["hp_mult", "PV ×"], ["atk_mult", "Dégâts ×"]]:
		var k: String = spec[0]
		var row := HBoxContainer.new()
		_right.add_child(row)
		var l := Hud._label(row, String(spec[1]), 14, UiTheme.TEXT)
		l.custom_minimum_size = Vector2(90, 0)
		var s := SpinBox.new()
		s.min_value = 0.1
		s.max_value = 50.0
		s.step = 0.1
		s.value = float(build.get(k, 1.0))
		s.value_changed.connect(func(x):
			build[k] = x
			_refresh_stats())
		row.add_child(s)


# --- stats et aperçu --------------------------------------------------------------------------
func _refresh_stats() -> void:
	var cid := String(build.get("class", "warrior"))
	var r := ClassRival.new()
	r.setup(cid, level, Duel.difficulty)
	r.apply_build(build, level)
	var spells: PackedStringArray = []
	for s in r._skills:
		spells.append(String(s.name))
	var sets: PackedStringArray = []
	for sb in Items.active_set_bonuses(RivalBuilds.items(build, level)):
		sets.append("%s (%d)" % [Items.set_def(sb.set).get("name", ""), int(sb.pieces)])
	var cb := CertBoard.synergies(RivalBuilds.cert_board(build)).map(func(x): return String(x.name))
	_stats.text = "[b]Niveau %d · IA %s[/b]\nPV [b]%s[/b] · attaque [b]%d[/b] · défense [b]%d[/b] (%d %% de dégâts subis en moins)\nSorts : %s%s%s" % [
		level, ClassRival.NAMES[Duel.difficulty], Hud._big_number(r.max_hp), roundi(r.atk), roundi(r.defense),
		roundi(100.0 - 10000.0 / (100.0 + maxf(r.defense, 0.0))), ", ".join(spells) if not spells.is_empty() else "combo de l'arme",
		("\nSets : " + ", ".join(sets)) if not sets.is_empty() else "", ("\nPlateau des certificats : " + ", ".join(cb)) if not cb.is_empty() else ""]
	var extra: Array = [String(build.get("look", {}).get("head", "")), String(build.get("look", {}).get("back", ""))]
	_preview.show_look(cid, r.weapon_code, String(build.get("look", {}).get("body", "")), extra)
	r.free()
