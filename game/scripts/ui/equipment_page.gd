class_name EquipmentPage
extends HBoxContainer
## Page Équipement : équipement porté autour d'un aperçu 3D du héros (bijoux et trophée
## en dessous), statistiques,
## bonus de set, et coffre (hors run : commun à toutes les classes, avec 3 préréglages
## d'équipement par classe ; pendant la run : le sac de la run).
## Équiper : glisser un objet sur sa case, double-clic ou clic droit ; retirer : glisser
## la pièce portée dans le coffre, double-clic ou clic droit sur la case.

signal class_changed

const DOLL_LEFT := ["head", "chest", "legs", "boots"]
const DOLL_RIGHT := ["weapon", "gloves", "back"]
const DOLL_BOTTOM := ["necklace", "ring", "trophy"]

var player: Player  # null hors run

var _class_box: GridContainer
var _preset_box: VBoxContainer
var _preset_name: LineEdit
var _stats: RichTextLabel
var _sets: RichTextLabel
var _doll_slots := {}  # emplacement -> ItemSlot
var _preview: HeroPreview
var _power: Label
var _grid: ItemWidgets.ItemGrid
var _grid_title: Label
var _detail: RichTextLabel
var _equip_btn: Button
var _selected: Dictionary = {}


func _ready() -> void:
	add_theme_constant_override("separation", 16)
	# --- gauche : classe, préréglages, statistiques ---
	var left := ItemWidgets.panel(self, 330)
	ItemWidgets.section(left, "Classe")
	_class_box = GridContainer.new()
	_class_box.columns = 3
	_class_box.add_theme_constant_override("h_separation", 6)
	_class_box.add_theme_constant_override("v_separation", 6)
	left.add_child(_class_box)
	ItemWidgets.section(left, "Préréglages d'équipement")
	_preset_box = VBoxContainer.new()
	_preset_box.add_theme_constant_override("separation", 4)
	left.add_child(_preset_box)
	_preset_name = LineEdit.new()
	_preset_name.placeholder_text = "Renommer le préréglage actif…"
	_preset_name.text_submitted.connect(func(t):
		Profile.rename_preset(Profile.selected_class, Profile.active_preset(Profile.selected_class), t)
		refresh())
	left.add_child(_preset_name)
	ItemWidgets.section(left, "Statistiques")
	_stats = ItemWidgets.rich(left, 14)
	# --- centre : poupée d'équipement autour du héros ---
	var mid := ItemWidgets.panel(self, 470)
	var doll := HBoxContainer.new()
	doll.add_theme_constant_override("separation", 10)
	doll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	mid.add_child(doll)
	var lcol := _doll_column(doll, DOLL_LEFT)
	_preview = HeroPreview.new()
	_preview.custom_minimum_size = Vector2(260, 420)
	_preview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	doll.add_child(_preview)
	_doll_column(doll, DOLL_RIGHT)
	lcol.alignment = BoxContainer.ALIGNMENT_CENTER
	var acc := HBoxContainer.new()  # accessoires : collier, bague, trophée
	acc.alignment = BoxContainer.ALIGNMENT_CENTER
	acc.add_theme_constant_override("separation", 22)
	mid.add_child(acc)
	for slot in DOLL_BOTTOM:
		_doll_cell(acc, slot, 66.0)
	_power = Label.new()
	UiTheme.title(_power, 18)
	_power.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mid.add_child(_power)
	ItemWidgets.section(mid, "Bonus de set", 16)
	_sets = ItemWidgets.rich(mid, 13)
	_sets.custom_minimum_size = Vector2(0, 110)
	_sets.size_flags_vertical = Control.SIZE_SHRINK_END
	# --- droite : coffre et détail ---
	var right := ItemWidgets.panel(self, 0, true)
	_grid_title = ItemWidgets.section(right, "")
	_grid = ItemWidgets.ItemGrid.new(false, 9, 62.0)
	_grid.source = "inventory"
	_grid.badge_fn = _badge
	_grid.card_extra = _users_text
	_grid.can_drop = func(data): return data.source == "equipped"
	_grid.on_drop = func(data): _unequip(String(data.slot))
	_grid.selection_changed.connect(func(): _select(_grid.first_selected()))
	_grid.item_activated.connect(_equip)
	right.add_child(_grid)
	var dp := PanelContainer.new()
	dp.add_theme_stylebox_override("panel", UiTheme.flat_box(Color(0.04, 0.03, 0.08, 0.9), UiTheme.GOLD_DIM, 1, 8, false))
	dp.custom_minimum_size = Vector2(0, 230)
	right.add_child(dp)
	var dv := VBoxContainer.new()
	dp.add_child(dv)
	_detail = ItemWidgets.rich(dv, 14)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	dv.add_child(actions)
	_equip_btn = ItemWidgets.action_button(actions, "Équiper", func():
		if _selected.is_empty():
			return
		if _is_equipped(_selected):
			_unequip(String(_selected.slot))
		else:
			_equip(_selected), 200, true)
	Hud._label(actions, "Glisser-déposer, double-clic ou clic droit pour équiper / retirer.", 13, UiTheme.MUTED)


func _doll_column(parent: Control, slots: Array) -> VBoxContainer:
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 12)
	parent.add_child(col)
	for slot in slots:
		_doll_cell(col, slot, 78.0)
	return col


## Case d'équipement de la poupée et sa légende.
func _doll_cell(parent: Control, slot: String, px: float) -> void:
	var cell := VBoxContainer.new()
	cell.add_theme_constant_override("separation", 0)
	parent.add_child(cell)
	var s := ItemWidgets.ItemSlot.new(px)
	s.slot_id = slot
	s.source = "equipped"
	s.placeholder = Items.SLOT_NAMES[slot]
	s.can_drop = func(data): return data.source == "inventory" and data.item.slot == slot
	s.on_drop = func(data): _equip(data.item)
	s.card_extra = _users_text
	s.pressed.connect(func():
		_select(Profile.equipped.get(slot, {})))
	s.activated.connect(func(): _unequip(slot))
	s.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	cell.add_child(s)
	var cap := Hud._label(cell, Items.SLOT_NAMES[slot], 12, UiTheme.MUTED)
	cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_doll_slots[slot] = s


func refresh() -> void:
	if not is_inside_tree():
		return
	var in_run := Profile.in_run
	var cid := Run.class_id if in_run else Profile.selected_class
	_refresh_classes(cid, in_run)
	_refresh_presets(cid, in_run)
	for slot in _doll_slots:
		var s: ItemWidgets.ItemSlot = _doll_slots[slot]
		s.set_item(Profile.equipped.get(slot, {}))
		s.selected = not _selected.is_empty() and is_same(Profile.equipped.get(slot), _selected)
		s.tooltip_text = Items.display_name(s.item) if not s.item.is_empty() else "%s : vide (glisse un objet ici)" % Items.SLOT_NAMES[slot]
		s.queue_redraw()
	_preview.show_hero(cid, Profile.weapon_code())
	_grid_title.text = ("Sac de la run  ·  %d / %d" % [Profile.inventory.size(), Profile.INVENTORY_MAX]) if in_run else \
		("Coffre commun à toutes les classes  ·  %d / %d" % [Profile.vault.size(), Profile.VAULT_MAX])
	_grid.set_empty_text("Ton sac est vide : le butin de la run arrive ici." if in_run else "Le coffre est vide : garde des objets en fin de run pour le remplir.")
	_grid.set_items(Profile.inventory)
	_refresh_stats(in_run)
	_refresh_detail()


func _refresh_classes(cid: String, in_run: bool) -> void:
	for c in _class_box.get_children():
		c.queue_free()
	for id in GameData.classes:
		var cls := GameData.class_data(id)
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.toggle_mode = true
		b.button_pressed = id == cid
		var open := Progression.class_unlocked(id)
		b.disabled = (in_run and id != cid) or not open
		b.text = String(cls.get("name_fr", id))
		b.icon = UiTheme.texture(String(cls.get("icon", "")))
		b.expand_icon = false
		b.add_theme_constant_override("icon_max_width", 24)
		b.add_theme_font_size_override("font_size", 13)
		b.custom_minimum_size = Vector2(98, 40)
		b.tooltip_text = ("Classe verrouillée — mission : " + Progression.mission_line(id)) if not open else \
			("Pendant la run, la classe est fixée." if in_run else "Chaque classe a son propre équipement (3 préréglages).")
		var cls_id: String = id
		b.pressed.connect(func():
			if in_run or cls_id == Profile.selected_class:
				b.set_pressed_no_signal(true)
				return
			Profile.selected_class = cls_id
			Profile.save_profile()
			_selected = {}
			class_changed.emit()
			refresh())
		_class_box.add_child(b)


func _refresh_presets(cid: String, in_run: bool) -> void:
	for c in _preset_box.get_children():
		c.queue_free()
	if in_run:
		Hud._label(_preset_box, "Pendant la run, tu portes les copies de ton équipement de départ et le butin trouvé.", 13, UiTheme.MUTED).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_preset_name.visible = false
		return
	_preset_name.visible = true
	var names := Profile.preset_names(cid)
	var active := Profile.active_preset(cid)
	for i in names.size():
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)
		_preset_box.add_child(row)
		var b := Button.new()
		b.toggle_mode = true
		b.button_pressed = i == active
		b.focus_mode = Control.FOCUS_NONE
		b.text = "%s%s" % ["▶ " if i == active else "", names[i]]
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, 36)
		var idx := i
		b.pressed.connect(func():
			Profile.set_active_preset(cid, idx)
			_selected = {}
			class_changed.emit()
			refresh())
		row.add_child(b)
		if i != active:
			var copy := Button.new()
			copy.text = "copier ici"
			copy.tooltip_text = "Remplace ce préréglage par l'équipement porté actuellement."
			copy.focus_mode = Control.FOCUS_NONE
			copy.add_theme_font_size_override("font_size", 12)
			copy.pressed.connect(func():
				Profile.copy_active_preset(cid, idx)
				refresh())
			row.add_child(copy)
	_preset_name.text = ""
	_preset_name.placeholder_text = "Renommer « %s »…" % names[active]


func _refresh_stats(in_run: bool) -> void:
	var lines: PackedStringArray = []
	if in_run and player:
		for row in player.stat_sheet():
			if String(row[1]) == "":
				lines.append("[color=#f5c75a]%s[/color]" % row[0])
			else:
				lines.append("%s : [b]%s[/b]" % [row[0], row[1]])
	else:
		var eq := Profile.equipment_stats()
		lines.append("[color=#c8c8d4]Bonus de l'équipement porté :[/color]")
		var keys := eq.keys()
		keys.sort()
		for k in keys:
			lines.append(Items.stat_text(k, eq[k]))
		if keys.is_empty():
			lines.append("[color=#c8c8d4]aucun[/color]")
		var arc := Archive.bonus()
		if not arc.is_empty():
			lines.append("")
			lines.append("[color=#c8c8d4]Bonus permanent de l'archive :[/color]")
			for k in arc:
				lines.append("[color=#7fe08a]%s[/color]" % Items.stat_text(k, arc[k]))
	_stats.text = "\n".join(lines)
	var power := 0
	for it in Profile.equipped.values():
		power += _power_of(it)
	_power.text = "Puissance d'équipement : %d" % power
	var sl: PackedStringArray = []
	for b in Items.active_set_bonuses(Profile.equipped):
		sl.append("[color=#%s]%s · %d pièces[/color] : %s" % [Items.SET_COLOR.to_html(false), Items.SETS[b.set].name, int(b.pieces), " ; ".join(Items.bonus_lines(b))])
	_sets.text = "\n".join(sl) if not sl.is_empty() else "[color=#c8c8d4]Aucun bonus actif : porte 2, 4 ou 6 pièces d'un même set (cadre vert).[/color]"


static func _power_of(it: Dictionary) -> int:
	return int(it.level) * 10 + int(it.rarity) * 25 + int(it.get("upgrade", 0)) * 12 + (30 if it.has("set") else 0)


func _badge(it: Dictionary) -> String:
	if Profile.in_run:
		return ""
	var users := Profile.item_users(String(it.uid))
	return "★" if not users.is_empty() else ""


## Carte au survol : classes dont un préréglage utilise l'objet.
func _users_text(it: Dictionary) -> String:
	if Profile.in_run:
		return ""
	var users := Profile.item_users(String(it.get("uid", "")))
	return "\n\n[color=#f5c75a]★ Utilisé par :[/color] " + ", ".join(users) if not users.is_empty() else ""


func _is_equipped(it: Dictionary) -> bool:
	return Profile.equipped.values().any(func(x): return is_same(x, it))


func _select(it) -> void:
	_selected = it if it is Dictionary else {}
	_refresh_detail()
	for slot in _doll_slots:
		_doll_slots[slot].selected = not _selected.is_empty() and is_same(Profile.equipped.get(slot), _selected)
		_doll_slots[slot].queue_redraw()


func _refresh_detail() -> void:
	if _selected.is_empty():
		_detail.text = "[b]Équipement[/b]\n\nClique un objet pour voir ses statistiques et la comparaison avec ta pièce portée.\n[color=#c8c8d4]★ : objet utilisé dans un préréglage d'une classe (le coffre est commun : tu peux passer un objet d'une classe à l'autre).[/color]"
		_equip_btn.disabled = true
		_equip_btn.text = "Équiper"
		return
	var equipped := _is_equipped(_selected)
	var txt := Items.describe(_selected)
	if not equipped:
		txt += ItemWidgets.compare_text(_selected, Profile.equipped.get(_selected.slot))
	_detail.text = txt + _users_text(_selected)
	_equip_btn.disabled = false
	_equip_btn.text = "Retirer" if equipped else "Équiper"


func _equip(it: Dictionary) -> void:
	if it.is_empty() or _is_equipped(it):
		return
	Profile.equip(it)
	_after_change(it)


func _unequip(slot: String) -> void:
	var it: Dictionary = Profile.equipped.get(slot, {})
	if it.is_empty():
		return
	if Profile.inventory.size() >= Profile.INVENTORY_MAX and Profile.in_run:
		return
	Profile.unequip(slot)
	_after_change(it)


func _after_change(it: Dictionary) -> void:
	if player:
		player.recalc_stats()
	_selected = it
	refresh()


# --- aperçu 3D du héros ---------------------------------------------------------------------
class HeroPreview extends SubViewportContainer:
	var _vp: SubViewport
	var _pivot: Node3D
	var _shown := ""
	var _drag := false

	func _init() -> void:
		stretch = true
		mouse_filter = Control.MOUSE_FILTER_STOP
		_vp = SubViewport.new()
		_vp.own_world_3d = true
		_vp.transparent_bg = true
		_vp.msaa_3d = Viewport.MSAA_2X
		add_child(_vp)
		var env := WorldEnvironment.new()
		env.environment = Environment.new()
		env.environment.background_mode = Environment.BG_CLEAR_COLOR
		env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.environment.ambient_light_color = Color(0.8, 0.76, 0.86)
		env.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
		_vp.add_child(env)
		var sun := DirectionalLight3D.new()
		sun.rotation_degrees = Vector3(-35, 30, 0)
		sun.light_color = Color(1.0, 0.92, 0.82)
		_vp.add_child(sun)
		var rim := OmniLight3D.new()
		rim.position = Vector3(-1.5, 2.2, -2.0)
		rim.light_color = Color(0.6, 0.5, 1.0)
		rim.light_energy = 1.5
		rim.omni_range = 6.0
		_vp.add_child(rim)
		var cam := Camera3D.new()
		cam.fov = 34.0
		cam.transform = Transform3D(Basis(), Vector3(0, 1.25, 4.6)).looking_at(Vector3(0, 1.05, 0))
		_vp.add_child(cam)
		_pivot = Node3D.new()
		_vp.add_child(_pivot)
		var disk := MeshInstance3D.new()  # socle doré
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.55
		cyl.bottom_radius = 0.6
		cyl.height = 0.06
		disk.mesh = cyl
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.25, 0.18, 0.08)
		m.metallic = 0.6
		m.roughness = 0.35
		disk.material_override = m
		disk.position.y = -0.04
		_vp.add_child(disk)

	func show_hero(class_id: String, weapon_code: String) -> void:
		var key := class_id + "|" + weapon_code
		if key == _shown:
			return
		_shown = key
		for c in _pivot.get_children():
			c.queue_free()
		var cls := GameData.class_data(class_id)
		if cls.is_empty() or not ResourceLoader.exists(String(cls.get("model", ""))):
			return
		var model := EdenModel.instantiate(cls.model)
		model.scale = Vector3.ONE * GameData.HERO_SCALE
		_pivot.add_child(model)
		EdenModel.attach_weapon(model, EdenModel.weapon_entry(cls, weapon_code))
		var ap := EdenModel.find_anim_player(model)
		var battle: String = cls.get("anims", {}).get("battle", "stand01")
		if ap and ap.has_animation(battle):
			ap.get_animation(battle).loop_mode = Animation.LOOP_LINEAR
			ap.play(battle)

	func _process(delta: float) -> void:
		if is_visible_in_tree() and not _drag:
			_pivot.rotation.y += delta * 0.35

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			_drag = event.pressed
		elif event is InputEventMouseMotion and _drag:
			_pivot.rotation.y += event.relative.x * 0.01
