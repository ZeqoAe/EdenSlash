class_name CharacterPanel
extends TabContainer
## Fiche du personnage (menu pause et lobby) : statistiques, équipement,
## inventaire, compétences et passifs de la run.
##   Inventaire : clic gauche = équiper, clic droit = vendre.
##   Équipement : clic = retirer.

const ACCENT := Color(0.98, 0.78, 0.35)

var player: Player  # null dans le lobby

var _stats_box: GridContainer
var _equip_box: GridContainer
var _inv_box: GridContainer
var _gold_label: Label
var _info: RichTextLabel
var _skills_box: VBoxContainer


func _ready() -> void:
	custom_minimum_size = Vector2(980, 560)
	add_theme_stylebox_override("panel", Hud.style(Color(0.07, 0.06, 0.12, 0.96)))
	_build_character_tab()
	_build_skills_tab()
	Profile.changed.connect(refresh)
	visibility_changed.connect(func(): if visible: refresh())
	refresh()


func _build_character_tab() -> void:
	var tab := HBoxContainer.new()
	tab.name = "Personnage"
	tab.add_theme_constant_override("separation", 24)
	add_child(tab)
	# statistiques
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(250, 0)
	tab.add_child(left)
	_title(left, "Statistiques")
	_stats_box = GridContainer.new()
	_stats_box.columns = 2
	_stats_box.add_theme_constant_override("h_separation", 18)
	left.add_child(_stats_box)
	_gold_label = Hud._label(left, "", 16, ACCENT)
	# équipement
	var mid := VBoxContainer.new()
	mid.custom_minimum_size = Vector2(250, 0)
	tab.add_child(mid)
	_title(mid, "Équipement")
	_equip_box = GridContainer.new()
	_equip_box.columns = 2
	_equip_box.add_theme_constant_override("h_separation", 8)
	_equip_box.add_theme_constant_override("v_separation", 8)
	mid.add_child(_equip_box)
	_info = RichTextLabel.new()
	_info.bbcode_enabled = true
	_info.fit_content = true
	_info.custom_minimum_size = Vector2(240, 120)
	_info.add_theme_font_size_override("normal_font_size", 14)
	mid.add_child(_info)
	# inventaire
	var right := VBoxContainer.new()
	tab.add_child(right)
	_title(right, "Inventaire (clic : équiper · clic droit : vendre)")
	_inv_box = GridContainer.new()
	_inv_box.columns = 8
	_inv_box.add_theme_constant_override("h_separation", 6)
	_inv_box.add_theme_constant_override("v_separation", 6)
	right.add_child(_inv_box)


func _build_skills_tab() -> void:
	var scroll := ScrollContainer.new()
	scroll.name = "Compétences"
	add_child(scroll)
	_skills_box = VBoxContainer.new()
	_skills_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_skills_box.add_theme_constant_override("separation", 10)
	scroll.add_child(_skills_box)


func _title(parent: Control, text: String) -> void:
	Hud._label(parent, text, 18, ACCENT)


func refresh() -> void:
	if not is_inside_tree():
		return
	# statistiques
	for c in _stats_box.get_children():
		c.queue_free()
	var sheet: Array = player.stat_sheet() if player else _lobby_sheet()
	for row in sheet:
		Hud._label(_stats_box, row[0], 15, Color(0.8, 0.8, 0.9))
		Hud._label(_stats_box, row[1], 15, Color.WHITE)
	if Run.active:
		_gold_label.text = "\nOr : %d\nFragments : %d · Essences : %d · Cristaux : %d" % [
			Profile.gold, Profile.materials.fragment, Profile.materials.essence, Profile.materials.crystal]
	else:
		_gold_label.text = "\nHéritage : %d objet(s) — clique pour choisir ton équipement de départ.\nÀ la fin de chaque run, tu gardes 1 objet (avec son amélioration)." % Profile.vault.size()
	# équipement
	for c in _equip_box.get_children():
		c.queue_free()
	for slot in Items.SLOTS:
		var item: Dictionary = Profile.equipped.get(slot, {})
		var b := _item_button(item, Items.SLOT_NAMES[slot])
		b.pressed.connect(func(): Profile.unequip(slot))
		_equip_box.add_child(b)
	# inventaire
	for c in _inv_box.get_children():
		c.queue_free()
	for item in Profile.inventory:
		var b := _item_button(item, "")
		b.custom_minimum_size = Vector2(56, 56)
		if Run.active:
			b.gui_input.connect(func(ev):
				if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_RIGHT:
					Profile.sell(item))
		b.pressed.connect(func(): Profile.equip(item))
		_inv_box.add_child(b)
	for i in Profile.INVENTORY_MAX - Profile.inventory.size():
		var empty := Panel.new()
		empty.custom_minimum_size = Vector2(56, 56)
		empty.add_theme_stylebox_override("panel", Hud.style(Color(0.1, 0.09, 0.16, 0.8)))
		_inv_box.add_child(empty)
	_refresh_skills()


func _lobby_sheet() -> Array:
	var eq := Profile.equipment_stats()
	var rows := [["Classe", GameData.class_data(Profile.selected_class).get("name_fr", "?")]]
	for s in eq:
		rows.append([Items.STAT_NAMES.get(s, Items.EXTRA_STAT_NAMES.get(s, s)), Items.stat_text(s, eq[s])])
	rows.append(["Runs", "%d (%d victoires)" % [Profile.runs_done, Profile.runs_won]])
	rows.append(["Meilleur niveau", str(Profile.best_level)])
	return rows


func _item_button(item: Dictionary, placeholder: String) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(118, 56)
	b.focus_mode = Control.FOCUS_NONE
	var sb := Hud.style(Color(0.12, 0.1, 0.18, 0.95))
	if not item.is_empty():
		sb.border_color = Items.color_of(item)
		sb.set_border_width_all(2)
	b.add_theme_stylebox_override("normal", sb)
	var hover := sb.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.2, 0.17, 0.3)
	b.add_theme_stylebox_override("hover", hover)
	if item.is_empty():
		b.text = placeholder
		b.modulate = Color(1, 1, 1, 0.5)
		return b
	if String(item.get("icon", "")) != "" and ResourceLoader.exists(item.icon):
		b.icon = load(item.icon)
		b.expand_icon = true
	b.text = placeholder
	b.mouse_entered.connect(func(): _info.text = Items.describe(item))
	return b


func _refresh_skills() -> void:
	for c in _skills_box.get_children():
		c.queue_free()
	var cls := GameData.class_data(Run.class_id if Run.active else Profile.selected_class)
	if Run.active:
		_title(_skills_box, "Compétences de la run (%d / %d)" % [Run.skills.size(), Run.MAX_SKILLS])
		for s in Run.skills:
			var d := Run.skill_def(int(s.id))
			_skill_row(d.icon, "%s — rang %d" % [d.name, int(s.rank)], d.desc)
		_title(_skills_box, "Passifs")
		if Run.passives.is_empty():
			Hud._label(_skills_box, "Aucun pour l'instant : ils s'obtiennent avec les cartes de niveau.", 14, Color(0.8, 0.8, 0.85))
		for pid in Run.passives:
			var p := Run.passive_def(pid)
			_skill_row(p.get("icon", Boons.ICONS.get(pid, "")), "%s ×%d" % [p.name, int(Run.passives[pid])], p.desc)
		_set_rows()
	else:
		_title(_skills_box, "Compétences du %s (à débloquer par cartes pendant la run)" % cls.get("name_fr", ""))
		for d in cls.get("skills", []):
			_skill_row(d.icon, "%s — recharge %d s" % [d.name, int(d.cooldown)], d.desc)
		_title(_skills_box, "Passifs possibles")
		for p in cls.get("passives", []):
			_skill_row(p.get("icon", ""), p.name, p.desc)
		_set_rows()


## Bonus de set actifs de l'équipement porté.
func _set_rows() -> void:
	var bonuses := Items.active_set_bonuses(Profile.equipped)
	if bonuses.is_empty():
		return
	_title(_skills_box, "Bonus de set")
	for b in bonuses:
		_skill_row("", "%s — %d pièces" % [Items.SETS[b.set].name, int(b.pieces)], "\n".join(Items.bonus_lines(b)))


func _skill_row(icon_path: String, title: String, desc: String) -> void:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	_skills_box.add_child(h)
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(44, 44)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.texture = UiTheme.texture(icon_path)
	h.add_child(icon)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(v)
	Hud._label(v, title, 16, Color.WHITE)
	var d := Hud._label(v, desc, 13, Color(0.82, 0.82, 0.88))
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
