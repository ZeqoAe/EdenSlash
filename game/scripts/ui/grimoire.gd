class_name Grimoire
extends CanvasLayer
## Grimoire des classes, façon page de champion :
## - à gauche : portrait, statistiques de base, attributs par niveau, arme de la classe ;
## - au centre : sorts de la classe, puis ses certificats ;
## - à droite : le détail de ce qu'on a cliqué (sort et ses rangs, auto-attaque de l'arme,
##   certificat).
## S'ouvre depuis la page Classe du héros (sur le sort cliqué) et le menu pause (classe de la run).
## En bas : presets de sorts (SpellPresets) : charger un preset enregistré, ou en créer un en
## faisant glisser les sorts de la liste dans un tableau 4 × 3 (les 4 cases, chacune avec son
## sort principal et ses 2 enchaînements). Le preset actif range les sorts en run.

const LEFT_W := 330.0
const RIGHT_W := 430.0

var _root: Control
var _class_id := "samurai"
var _class_bar: HBoxContainer
var _header_icon: TextureRect
var _header_name: Label
var _header_lore: Label
var _stats: RichTextLabel
var _weapon_box: VBoxContainer
var _skills_grid: GridContainer
var _passives_grid: GridContainer
var _detail: RichTextLabel
var _rank_bar: HBoxContainer
var _selected := {}  # {kind: "skill" | "weapon" | "passive", data}
var _rank := 1
var _buttons: Array = []  # [Button, sélection] pour l'état enfoncé
var _preset_label: Label
var _preset_msg: Label
var _editor: VBoxContainer
var _cells: Array = []  # [case][rang] -> Button
var _edit_cols: Array = []  # ids en cours d'édition (0 : vide)
var _name_edit: LineEdit
var _cert_title: Control
var _mscroll: ScrollContainer
const ROW_NAMES := ["Sort principal", "Enchaînement 1", "Enchaînement 2"]


func _ready() -> void:
	layer = 22
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.01, 0.05, 0.85)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiTheme.panel_box(20, 16))
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.offset_left = 32
	panel.offset_top = 26
	panel.offset_right = -32
	panel.offset_bottom = -26
	panel.clip_contents = true
	_root.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	panel.add_child(v)

	# barre du haut : titre, classe, fermer
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	v.add_child(top)
	var t := Label.new()
	t.text = "Grimoire"
	UiTheme.title(t, 30)
	top.add_child(t)
	_class_bar = HBoxContainer.new()
	_class_bar.add_theme_constant_override("separation", 6)
	_class_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(_class_bar)
	var close := Button.new()
	close.text = "✕  Fermer (Échap)"
	close.focus_mode = Control.FOCUS_NONE
	close.pressed.connect(close_ui)
	top.add_child(close)

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 16)
	v.add_child(body)

	# --- gauche : portrait, statistiques, attributs par niveau, arme de la classe ---
	var lscroll := ScrollContainer.new()
	lscroll.custom_minimum_size = Vector2(LEFT_W, 0)
	lscroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(lscroll)
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 8)
	lscroll.add_child(left)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	left.add_child(head)
	_header_icon = TextureRect.new()
	_header_icon.custom_minimum_size = Vector2(72, 72)
	_header_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	head.add_child(_header_icon)
	_header_name = Label.new()
	UiTheme.title(_header_name, 26)
	_header_name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	head.add_child(_header_name)
	_header_lore = Hud._label(left, "", 14, UiTheme.MUTED)
	_header_lore.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_header_lore.custom_minimum_size = Vector2(LEFT_W - 20, 0)
	_section(left, "Statistiques de base")
	_stats = _rich(left, 15)
	_stats.fit_content = true
	_stats.scroll_active = false
	_stats.custom_minimum_size = Vector2(LEFT_W - 20, 0)
	_section(left, "Arme de la classe")
	_weapon_box = VBoxContainer.new()
	left.add_child(_weapon_box)

	# --- centre : compétences puis passifs ---
	var mscroll := ScrollContainer.new()
	_mscroll = mscroll
	mscroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mscroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(mscroll)
	var mid := VBoxContainer.new()
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.add_theme_constant_override("separation", 8)
	mscroll.add_child(mid)
	_section(mid, "Sorts")
	_skills_grid = GridContainer.new()
	_skills_grid.columns = 2
	_skills_grid.add_theme_constant_override("h_separation", 8)
	_skills_grid.add_theme_constant_override("v_separation", 8)
	mid.add_child(_skills_grid)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 6)
	mid.add_child(gap)
	_section(mid, "Certificats de la classe")
	_cert_title = mid.get_child(mid.get_child_count() - 1)
	_passives_grid = GridContainer.new()
	_passives_grid.columns = 3
	_passives_grid.add_theme_constant_override("h_separation", 8)
	_passives_grid.add_theme_constant_override("v_separation", 6)
	mid.add_child(_passives_grid)
	_build_presets(mid)

	# --- droite : détail de la sélection ---
	var right := PanelContainer.new()
	right.custom_minimum_size = Vector2(RIGHT_W, 0)
	right.add_theme_stylebox_override("panel", UiTheme.flat_box(Color(0.07, 0.06, 0.13, 0.95), UiTheme.GOLD_DIM, 2, 10))
	body.add_child(right)
	var rv := VBoxContainer.new()
	rv.add_theme_constant_override("separation", 8)
	right.add_child(rv)
	_rank_bar = HBoxContainer.new()
	_rank_bar.add_theme_constant_override("separation", 4)
	rv.add_child(_rank_bar)
	_detail = _rich(rv, 15)
	_detail.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_root.visible = false


## Ouvre le grimoire de [param class_id] ; [param skill_id] > 0 : sur ce sort.
func open(class_id := "", skill_id := 0) -> void:
	_class_id = class_id if class_id != "" else (Run.class_id if Run.active else Profile.selected_class)
	_selected = {}
	for s in GameData.class_data(_class_id).get("skills", []):
		if skill_id > 0 and int(s.id) == skill_id:
			_selected = {"kind": "skill", "data": s}
			_rank = maxi(1, _owned_rank(skill_id))
	_root.visible = true
	_refresh()
	if "--preset-editor" in OS.get_cmdline_user_args():
		# test : l'éditeur de preset ouvert avec quelques sorts posés
		_open_editor()
		var sk: Array = GameData.class_data(_class_id).get("skills", [])
		for i in mini(sk.size(), 7):
			_edit_cols[i % 4][i / 4] = int(sk[i].id)
		_refresh_cells()


func close_ui() -> void:
	_root.visible = false


func is_open() -> bool:
	return _root.visible


func _unhandled_input(event: InputEvent) -> void:
	if _root.visible and event.is_action_pressed("pause"):
		close_ui()
		get_viewport().set_input_as_handled()


# --- contenu ---------------------------------------------------------------------------------
## Grand bouton (icône + nom) qui sélectionne [param sel] pour le panneau de droite.
func _entry(parent: Control, icon: String, text: String, sel: Dictionary, height := 52.0) -> Button:
	var b := Button.new()
	b.text = "  " + text
	b.icon = UiTheme.texture(icon)
	b.expand_icon = false
	b.add_theme_constant_override("icon_max_width", int(height) - 12)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.clip_text = true
	b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	b.custom_minimum_size = Vector2(0, height)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.toggle_mode = true
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(func():
		_selected = sel
		if sel.kind == "skill":
			_rank = maxi(1, _owned_rank(int(sel.data.id)))
		_refresh_detail())
	parent.add_child(b)
	_buttons.append([b, sel])
	return b


func _refresh() -> void:
	var cls := GameData.class_data(_class_id)
	for c in _class_bar.get_children():
		c.queue_free()
	_class_bar.add_child(ClassPicker.button(func(): return _class_id, func(cid):
		_class_id = cid
		_selected = {}
		_refresh(), true))
	_header_icon.texture = UiTheme.texture(String(cls.get("icon", "")))
	_header_name.text = String(cls.get("name_fr", ""))
	_header_lore.text = String(cls.get("lore", ""))
	_stats.text = SpellInfo.class_stats_bbcode(cls)
	_buttons.clear()
	# arme de la classe : son auto-attaque s'affiche à droite
	for c in _weapon_box.get_children():
		c.queue_free()
	var wt := Items.default_weapon_type(_class_id)
	var wdata := GameData.weapon_type(wt)
	var weapon_sel := {"kind": "weapon", "data": wt}
	_entry(_weapon_box, String(wdata.get("icon", "")), "%s  ·  %s" % [String(wdata.get("name", wt)), " / ".join(WeaponAttacks.variants(wt).map(func(v): return String(v.name)))], weapon_sel, 56.0)
	# compétences
	for c in _skills_grid.get_children():
		c.queue_free()
	var skills: Array = cls.get("skills", [])
	for s in skills:
		var label := String(s.name)
		var owned := _owned_rank(int(s.id))
		if Run.active and owned > 0:
			label += "  (rang %d)" % owned
		var need := Progression.skill_level_of(_class_id, int(s.id))
		var locked := not Progression.skill_unlocked(_class_id, int(s.id))
		if locked:
			label += "   🔒 maîtrise %d" % need
		var b := _entry(_skills_grid, String(s.get("icon", "")), label, {"kind": "skill", "data": s})
		var sd: Dictionary = s
		b.set_drag_forwarding(func(_at): return _drag_spell(b, sd, Vector2i(-1, -1)), Callable(), Callable())
		if locked:
			b.modulate = Color(0.7, 0.7, 0.75)
		b.tooltip_text = String(s.name) + ("  ·  sort de base" if need <= 1 else "  ·  débloqué au niveau %d de maîtrise de la classe" % need)
	# certificats de la classe
	for c in _passives_grid.get_children():
		c.queue_free()
	for p in cls.get("passives", []):
		var label := String(p.get("name", "?"))
		if int(p.get("max", 1)) > 1:
			label += "  ×%d" % int(p.max)
		var b := _entry(_passives_grid, String(p.get("icon", Boons.ICONS.get(p.get("id", ""), ""))), label, {"kind": "passive", "data": p}, 44.0)
		b.tooltip_text = label
	_refresh_presets()
	_set_compact(false)
	if _selected.is_empty():
		_selected = {"kind": "skill", "data": skills[0]} if not skills.is_empty() else weapon_sel
		if _selected.kind == "skill":
			_rank = maxi(1, _owned_rank(int(_selected.data.id)))
	_refresh_detail()


func _same(a: Dictionary, b: Dictionary) -> bool:
	if a.is_empty() or b.is_empty() or a.kind != b.kind:
		return false
	if a.kind == "weapon":
		return a.data == b.data
	return is_same(a.data, b.data) or (a.data is Dictionary and b.data is Dictionary and a.data.get("id") == b.data.get("id") and a.data.get("name") == b.data.get("name"))


func _refresh_detail() -> void:
	for c in _rank_bar.get_children():
		c.queue_free()
	for pair in _buttons:
		if is_instance_valid(pair[0]):
			(pair[0] as Button).set_pressed_no_signal(_same(pair[1], _selected))
	if _selected.is_empty():
		_detail.text = ""
		return
	match String(_selected.kind):
		"skill":
			var sk: Dictionary = _selected.data
			Hud._label(_rank_bar, "Rang :", 14, UiTheme.MUTED)
			for r in range(1, Run.MAX_RANK + 1):
				var b := Button.new()
				b.text = str(r)
				b.toggle_mode = true
				b.button_pressed = r == _rank
				b.custom_minimum_size = Vector2(34, 30)
				b.focus_mode = Control.FOCUS_NONE
				var rr := r
				b.pressed.connect(func():
					_rank = rr
					_refresh_detail())
				_rank_bar.add_child(b)
			var icon := String(sk.get("icon", ""))
			var txt := ("[img=64x64]%s[/img]\n" % icon if icon != "" else "") + SpellInfo.skill_bbcode(sk, _rank, _atk(String(sk.get("dmg_type", "phys"))))
			var cards := Cards.class_cards(_class_id).filter(func(d): return int(d.skill) == int(sk.id))
			if not cards.is_empty():
				txt += "

[b]Cartes de classe pour ce sort[/b] (en run, une fois le sort pris)"
				for d in cards:
					txt += "
• %s : %s (jusqu'à %d fois)" % [String(d.name).get_slice(" : ", 1), " ; ".join(Cards.skill_mod_lines(d, 0.0, 1.0)), int(d.max)]
			var need := Progression.skill_level_of(_class_id, int(sk.id))
			if not Progression.skill_unlocked(_class_id, int(sk.id)):
				txt += "\n\n[color=#ffcf6b]🔒 Débloqué au niveau %d de maîtrise de la classe[/color]" % need
			_detail.text = txt
		"weapon":
			var wt := String(_selected.data)
			var wdata := GameData.weapon_type(wt)
			var vs := WeaponAttacks.variants(wt)
			var parts: PackedStringArray = []
			var icon := String(wdata.get("icon", ""))
			parts.append(("[img=56x56]%s[/img]  " % icon if icon != "" else "") + "[font_size=22][b]%s[/b][/font_size]" % String(wdata.get("name", wt)))
			parts.append("[color=#c8c8d4]Auto-attaque (clic gauche, ou automatique) : elle grandit avec les cartes.%s[/color]" %
				(" Deux variantes : le modèle de l'arme décide laquelle." if vs.size() > 1 else ""))
			for i in vs.size():
				var sp := WeaponAttacks.spec_for({"auto_variant": i, "slot": "weapon"}, wt)
				parts.append(("[color=#ffcf6b]━━━━━━━━━━[/color]\n" if i > 0 else "") + WeaponAttacks.bbcode(sp, _atk(String(sp.dmg_type))))
			parts.append("[color=#c8c8d4]Améliorations d'arme (cartes de niveau, %d niveaux par arme) : commune = dégâts ; rare = dégâts + un bonus (critique, cadence, zone, portée…) ; épique = + un bonus majeur (projectile, perforation, rebond, grande zone) ; légendaire = + l'effet légendaire de la variante (★).[/color]" % WeaponAttacks.MAX_RANK)
			parts.append("[color=#9a98a8]Arme secondaire (n'importe quel type) : elle ne frappe pas seule. [%s] la met en main : son auto-attaque remplace celle de l'arme principale ; tes sorts ne changent pas.[/color]" % Settings.action_label("swap_weapon", 1))
			if Run.active:
				for slot in ["weapon", "offhand"]:
					var ws := Run.weapon_spec(slot)
					var mt := WeaponAttacks.mods_text(ws, Run.weapon_ups.get(slot, {})) if not ws.is_empty() else ""
					if mt != "":
						parts.append("[b]%s (%s)[/b]\n%s" % ["Arme principale" if slot == "weapon" else "Arme secondaire", ws.name, mt])
			_detail.text = "\n\n".join(parts)
		"passive":
			var p: Dictionary = _selected.data
			var icon := String(p.get("icon", Boons.ICONS.get(p.get("id", ""), "")))
			_detail.text = ("[img=64x64]%s[/img]\n" % icon if icon != "" else "") + "[font_size=17]" + SpellInfo.passive_bbcode(p) + "[/font_size]" + \
				"\n\n[color=#c8c8d4]Certificat : à poser sur le plateau (Classe > Certificats) pour l'avoir dès le début de la partie.[/color]"


## Attaque actuelle du héros (physique ou magique) pour chiffrer les dégâts, sinon estimation niveau 1.
func _atk(dmg_type := "") -> float:
	var cls := GameData.class_data(_class_id)
	if dmg_type == "":
		dmg_type = String(cls.get("dmg_type", "phys"))
	var p := get_tree().get_first_node_in_group("player") as Player
	if p and p.class_id == _class_id:
		return p.matk if dmg_type == "mag" else p.atk
	var base: Dictionary = cls.get("base", {})
	return GameData.player_atk(1) * float(base.get("matk" if dmg_type == "mag" else "atk", 0.5 if dmg_type == "mag" else 1.0))


# --- presets de sorts ------------------------------------------------------------------------
func _build_presets(parent: Control) -> void:
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 6)
	parent.add_child(gap)
	_section(parent, "Préréglages de sorts")
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	parent.add_child(row)
	var load_b := _small_button(row, "Charger un préréglage ▾", 220)
	load_b.pressed.connect(func(): _load_menu(load_b))
	_small_button(row, "Créer un préréglage", 200).pressed.connect(_open_editor)
	_preset_label = Hud._label(row, "", 14, UiTheme.MUTED)
	_preset_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_preset_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_preset_msg = Hud._label(parent, "", 14, UiTheme.BUFF)
	_editor = VBoxContainer.new()
	_editor.add_theme_constant_override("separation", 6)
	_editor.visible = false
	parent.add_child(_editor)
	var grid := GridContainer.new()
	grid.tooltip_text = "Glisse les sorts de la liste dans les cases (ou d'une case à l'autre pour les échanger), clic pour vider une case. Chaque colonne est une case de la barre de sorts (touche 1 à 4) : son sort principal, puis les 2 sorts qu'elle enchaîne."
	grid.columns = 1 + SpellPresets.COLS
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	_editor.add_child(grid)
	grid.add_child(Control.new())
	for c in SpellPresets.COLS:
		var h := Hud._label(grid, "Case %d" % (c + 1), 15, UiTheme.GOLD)
		h.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		h.mouse_filter = Control.MOUSE_FILTER_PASS
	_cells = []
	for c in SpellPresets.COLS:
		_cells.append([])
	for r in SpellPresets.ROWS:
		var rl := Hud._label(grid, String(ROW_NAMES[r]), 13, UiTheme.TEXT)
		rl.custom_minimum_size = Vector2(110, 0)
		rl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		for c in SpellPresets.COLS:
			var cell := Button.new()
			cell.custom_minimum_size = Vector2(0, 50)
			cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			cell.focus_mode = Control.FOCUS_NONE
			cell.alignment = HORIZONTAL_ALIGNMENT_LEFT
			cell.clip_text = true
			cell.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			cell.expand_icon = false
			cell.add_theme_constant_override("icon_max_width", 38)
			var at := Vector2i(c, r)
			cell.pressed.connect(func():
				_edit_cols[at.x][at.y] = 0
				_refresh_cells())
			cell.set_drag_forwarding(func(_p): return _drag_spell(cell, _spell_at(at), at) if int(_edit_cols[at.x][at.y]) != 0 else null,
				func(_p, d): return d is Dictionary and d.has("spell"),
				func(_p, d): _drop_spell(at, d))
			grid.add_child(cell)
			_cells[c].append(cell)
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 8)
	_editor.add_child(bar)
	Hud._label(bar, "Nom", 14, UiTheme.TEXT)
	_name_edit = LineEdit.new()
	_name_edit.custom_minimum_size = Vector2(240, 0)
	_name_edit.placeholder_text = "Nom du préréglage"
	bar.add_child(_name_edit)
	_small_button(bar, "Enregistrer le préréglage", 200).pressed.connect(_save_editor)
	_small_button(bar, "Vider", 90).pressed.connect(func():
		_edit_cols = SpellPresets.empty_cols()
		_refresh_cells())
	_small_button(bar, "Annuler", 100).pressed.connect(func():
		_editor.visible = false
		_set_compact(false))


func _small_button(parent: Control, text: String, width: float) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(width, 40)
	parent.add_child(b)
	return b


func _refresh_presets() -> void:
	if _preset_label == null:
		return
	var p := SpellPresets.active(_class_id)
	var n := SpellPresets.list(_class_id).size()
	_preset_label.text = ("Préréglage actif : %s" % p.name if not p.is_empty() else "Aucun préréglage actif : les sorts se rangent dans l'ordre où on les obtient") + "  ·  %s" % GearPower.plural(n, "enregistré", "enregistrés")
	_editor.visible = false


func _spell_at(at: Vector2i) -> Dictionary:
	var id := int(_edit_cols[at.x][at.y])
	for s in GameData.class_data(_class_id).get("skills", []):
		if int(s.id) == id:
			return s
	return {}


## Données glissées : le sort (et sa case d'origine s'il vient du tableau), avec son icône.
func _drag_spell(from: Control, sk: Dictionary, at: Vector2i) -> Variant:
	if sk.is_empty():
		return null
	var ic := TextureRect.new()
	ic.texture = UiTheme.texture(String(sk.get("icon", "")))
	ic.custom_minimum_size = Vector2(48, 48)
	ic.size = Vector2(48, 48)
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	from.set_drag_preview(ic)
	return {"spell": int(sk.id), "from": at}


func _drop_spell(at: Vector2i, d: Dictionary) -> void:
	if _edit_cols.is_empty():
		return
	var id := int(d.spell)
	var from: Vector2i = d.get("from", Vector2i(-1, -1))
	if from.x >= 0:
		# d'une case à l'autre : échange
		_edit_cols[from.x][from.y] = int(_edit_cols[at.x][at.y])
	else:
		# depuis la liste : le sort quitte son ancienne case
		for c in _edit_cols.size():
			for r in (_edit_cols[c] as Array).size():
				if int(_edit_cols[c][r]) == id:
					_edit_cols[c][r] = 0
	_edit_cols[at.x][at.y] = id
	_refresh_cells()


func _refresh_cells() -> void:
	for c in SpellPresets.COLS:
		for r in SpellPresets.ROWS:
			var cell: Button = _cells[c][r]
			var sk := _spell_at(Vector2i(c, r))
			cell.icon = UiTheme.texture(String(sk.get("icon", ""))) if not sk.is_empty() else null
			cell.text = ("  " + String(sk.name)) if not sk.is_empty() else "  —  glisse un sort ici"
			cell.modulate = Color.WHITE if not sk.is_empty() else Color(1, 1, 1, 0.55)
			cell.tooltip_text = (String(sk.name) + "  ·  clic : vider la case") if not sk.is_empty() else "Glisse un sort de la liste ici"


func _open_editor() -> void:
	var p := SpellPresets.active(_class_id)
	_edit_cols = SpellPresets.empty_cols()
	if not p.is_empty():
		for c in mini((p.cols as Array).size(), SpellPresets.COLS):
			for r in mini((p.cols[c] as Array).size(), SpellPresets.ROWS):
				_edit_cols[c][r] = int(p.cols[c][r])
	_name_edit.text = String(p.get("name", "Préréglage %d" % (SpellPresets.list(_class_id).size() + 1)))
	_preset_msg.text = ""
	_editor.visible = true
	_set_compact(true)
	_refresh_cells()


## Éditeur ouvert : sorts en 3 colonnes plus basses, certificats masqués, pour voir la liste
## et le tableau ensemble (on glisse sans faire défiler).
func _set_compact(on: bool) -> void:
	_skills_grid.columns = 3 if on else 2
	for b in _skills_grid.get_children():
		(b as Control).custom_minimum_size.y = 40.0 if on else 52.0
		(b as Button).add_theme_constant_override("icon_max_width", 30 if on else 40)
	_cert_title.visible = not on
	_passives_grid.visible = not on
	if on and _mscroll:
		_mscroll.set_deferred("scroll_vertical", 0)


func _save_editor() -> void:
	var n := 0
	for col in _edit_cols:
		for id in col:
			if int(id) != 0:
				n += 1
	if n == 0:
		_preset_msg.text = "Place au moins un sort avant d'enregistrer."
		return
	var nm := _name_edit.text.strip_edges()
	if nm == "":
		nm = "Préréglage %d" % (SpellPresets.list(_class_id).size() + 1)
	SpellPresets.store(_class_id, nm, _edit_cols.duplicate(true))
	_apply_preset()
	_refresh_presets()
	_set_compact(false)
	_preset_msg.text = "Préréglage « %s » enregistré et chargé." % nm


func _load_menu(anchor: Control) -> void:
	var pm := PopupMenu.new()
	var l := SpellPresets.list(_class_id)
	var act := SpellPresets.active_index(_class_id)
	for i in l.size():
		pm.add_radio_check_item(String(l[i].name), i)
		pm.set_item_checked(i, i == act)
	pm.add_radio_check_item("Aucun (ordre d'obtention)", 1000)
	pm.set_item_checked(pm.item_count - 1, act < 0)
	if act >= 0:
		pm.add_separator()
		pm.add_item("Supprimer « %s »" % l[act].name, 2000)
	pm.id_pressed.connect(func(id):
		if id == 2000:
			SpellPresets.remove(_class_id, act)
			_refresh_presets()
			_preset_msg.text = "Préréglage supprimé."
			return
		SpellPresets.set_active(_class_id, -1 if id == 1000 else id)
		_apply_preset()
		_refresh_presets()
		_preset_msg.text = ("Préréglage « %s » chargé." % l[id].name) if id < 1000 else "Plus de préréglage : ordre d'obtention.")
	_root.add_child(pm)
	pm.popup_hide.connect(pm.queue_free)
	var r := anchor.get_global_rect()
	pm.position = Vector2i(int(r.position.x), int(r.end.y + 4))
	pm.popup()


## Preset chargé pendant une run de la classe : les sorts se rangent tout de suite
## (en entraînement, tous les sorts du preset sont posés).
func _apply_preset() -> void:
	if not Run.active or Run.class_id != _class_id:
		return
	if Training.active:
		Run.fill_from_preset()
	else:
		Run.arrange()
		Run.changed.emit()
	_refresh()


func _owned_rank(id: int) -> int:
	return Run.skill_rank(id) if Run.active and _class_id == Run.class_id else 0


func _section(parent: Control, text: String) -> void:
	var l := Label.new()
	l.text = text
	UiTheme.title(l, 17)
	parent.add_child(l)


func _rich(parent: Control, size: int) -> RichTextLabel:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.add_theme_font_size_override("normal_font_size", size)
	r.add_theme_font_size_override("bold_font_size", size)
	r.add_theme_font_size_override("italics_font_size", size)
	r.scroll_active = true
	r.selection_enabled = false
	parent.add_child(r)
	return r
