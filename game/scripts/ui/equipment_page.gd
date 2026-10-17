class_name EquipmentPage
extends RefCounted
## Éléments partagés de l'écran Équipement (la page elle-même est InventoryPage) :
## - PresetBar : les 3 préréglages d'équipement de la classe, copie et renommage ;
## - HeroPreview : aperçu 3D du héros (équipement, apparence, éditeur d'adversaire).


## Puissance d'une pièce (tri des cases d'un emplacement).
static func _power_of(it: Dictionary) -> int:
	return GearPower.item_power(it)


# --- préréglages d'équipement ---------------------------------------------------------------
## Les 3 préréglages de la classe affichée (hors run) : un clic change de préréglage (l'équipement
## porté reste enregistré dans l'ancien), « Gérer » copie l'équipement porté vers un autre
## préréglage ou renomme l'actif. [member extra_actions] : entrées ajoutées au menu « Gérer »
## (« Équiper le meilleur », « Appliquer à la famille »...), chacune
## {"label": String, "call": Callable, "tip": String (facultatif)} ; l'action reçoit l'identifiant
## de la classe affichée et rend un message à montrer (ou "").
class PresetBar extends HBoxContainer:
	signal changed(message: String)

	var extra_actions: Array = []
	var _cid := ""
	var _more: Button
	var _pop: PopupPanel

	func _init() -> void:
		add_theme_constant_override("separation", 6)

	func refresh(cid: String) -> void:
		_cid = cid
		visible = not Profile.in_run
		for c in get_children():
			remove_child(c)
			c.queue_free()
		if Profile.in_run:
			return
		var names := Profile.preset_names(cid)
		var active := Profile.active_preset(cid)
		for i in names.size():
			add_child(_chip(i, String(names[i]), i == active))
		_more = Button.new()
		_more.text = "Gérer ▾"
		_more.focus_mode = Control.FOCUS_NONE
		_more.custom_minimum_size = Vector2(0, 38)
		_more.add_theme_font_size_override("font_size", 14)
		_more.add_theme_stylebox_override("normal", _box(false))
		_more.add_theme_stylebox_override("hover", _box(true))
		_more.add_theme_stylebox_override("pressed", _box(true))
		_more.tooltip_text = "Équiper le meilleur, copier vers un autre préréglage ou vers la famille, renommer"
		_more.pressed.connect(_open_menu)
		add_child(_more)

	static func _box(on: bool, border := UiTheme.GOLD_DIM) -> StyleBoxFlat:
		var sb := UiTheme.flat_box(Color(0.5, 0.36, 0.1, 1.0) if on else Color(0.08, 0.07, 0.16, 0.92), UiTheme.GOLD if on else border, 1, 7, false)
		sb.content_margin_left = 12
		sb.content_margin_right = 12
		return sb

	static func pieces_text(n: int) -> String:
		return "%d pièce%s" % [n, "s" if n > 1 else ""]

	## Nombre de pièces rangées dans le préréglage [param i] de la classe.
	static func piece_count(cid: String, i: int) -> int:
		if i == Profile.active_preset(cid):
			return Profile.equipped.size()
		var sets: Array = Profile.presets.get(cid, {}).get("sets", [])
		return (sets[i].slots as Dictionary).size() if i < sets.size() else 0

	func _chip(i: int, text: String, on: bool) -> Button:
		var b := Button.new()
		b.toggle_mode = true
		b.set_pressed_no_signal(on)
		b.focus_mode = Control.FOCUS_NONE
		b.text = text
		b.clip_text = true
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, 38)
		b.add_theme_font_size_override("font_size", 14)
		b.add_theme_font_override("font", UiTheme.bold_font())
		b.add_theme_stylebox_override("normal", _box(on))
		b.add_theme_stylebox_override("pressed", _box(on))
		b.add_theme_stylebox_override("hover", _box(true))
		b.add_theme_stylebox_override("hover_pressed", _box(true))
		b.add_theme_color_override("font_color", Color(0.12, 0.08, 0.02) if on else Color(0.92, 0.88, 0.8))
		b.add_theme_color_override("font_pressed_color", Color(0.12, 0.08, 0.02))
		b.add_theme_color_override("font_hover_pressed_color", Color(0.12, 0.08, 0.02))
		b.tooltip_text = pieces_text(piece_count(_cid, i))
		b.pressed.connect(func():
			if not on:
				Profile.set_active_preset(_cid, i)
				changed.emit(""))
		return b

	func _open_menu() -> void:
		if is_instance_valid(_pop):
			_pop.queue_free()
		var names := Profile.preset_names(_cid)
		var active := Profile.active_preset(_cid)
		_pop = PopupPanel.new()
		_pop.add_theme_stylebox_override("panel", UiTheme.flat_box(Color(0.05, 0.04, 0.1, 0.98), UiTheme.GOLD, 2, 12))
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 6)
		_pop.add_child(v)
		var t := Hud._label(v, String(names[active]), 16, UiTheme.GOLD)
		t.add_theme_font_override("font", UiTheme.bold_font())
		for j in names.size():
			if j == active:
				continue
			var jj := j
			v.add_child(_entry("Copier vers « %s » · %s" % [names[j], pieces_text(piece_count(_cid, j))], func():
				Profile.copy_active_preset(_cid, jj)
				changed.emit("Équipement copié vers « %s »." % names[jj])))
		for a in extra_actions + ClassGear.menu_actions(_cid):  # meilleur équipement, famille, annulation (lot E3)
			var act: Dictionary = a
			var b := _entry(String(act.label), func():
				changed.emit(String(act.call.call(_cid))))
			b.tooltip_text = String(act.get("tip", ""))
			v.add_child(b)
		Hud._label(v, "Renommer", 12, UiTheme.MUTED)
		var ed := LineEdit.new()
		ed.text = String(names[active])
		ed.max_length = 24
		ed.placeholder_text = "Nom du préréglage"
		ed.custom_minimum_size = Vector2(300, 36)
		ed.text_submitted.connect(func(s):
			Profile.rename_preset(_cid, active, s)
			_pop.hide()
			changed.emit(""))
		v.add_child(ed)
		add_child(_pop)
		_pop.popup_hide.connect(_pop.queue_free)
		_pop.reset_size()
		var r := _more.get_global_rect()
		var vp := get_viewport_rect().size
		_pop.position = Vector2i(int(clampf(r.end.x - _pop.size.x, 8.0, vp.x - _pop.size.x - 8.0)), int(r.end.y + 6.0))
		_pop.popup()

	## Ce que « Équiper le meilleur » changerait pour [param cid] : [{slot, old, new}] (emplacements de la poupée, dans l'ordre).
	static func best_plan(cid: String) -> Array:
		if Profile.in_run or Modes.sealed() or ClassGear.profile(cid).is_empty():
			return []
		var cur := ClassGear.gear_of(cid)
		var best := ClassGear.best_gear(cid)
		if not best.has("weapon") and cur.has("weapon"):
			best["weapon"] = cur.weapon
		var out: Array = []
		for slot in Items.SLOTS + ["offhand"]:
			var a: Dictionary = cur.get(slot, {})
			var b: Dictionary = best.get(slot, {})
			if String(a.get("uid", "")) != String(b.get("uid", "")) and not b.is_empty():
				out.append({"slot": slot, "old": a, "new": b})
		return out

	## Aperçu de « Le meilleur » (comme l'équipement recommandé des MMORPG) : actuel → recommandé, puis Appliquer.
	func _open_best() -> void:
		var plan := best_plan(_cid)
		if plan.is_empty():
			return
		var a := InfoCard.ask(self, "Le meilleur pour %s" % ClassGear.class_label(_cid),
			"%s, d'après le profil %s." % [GearPower.plural(plan.size(), "pièce change", "pièces changent"), ClassGear.profile_name(ClassGear.profile_id(_cid))],
			"Appliquer", func(): changed.emit(ClassGear.equip_best(_cid)), false)
		a.ok_button.text = "Appliquer"
		var list := VBoxContainer.new()
		list.add_theme_constant_override("separation", 4)
		for row in plan.slice(0, 10):
			list.add_child(_best_row(row))
		var v := a.title_label.get_parent()
		v.add_child(list)
		v.move_child(list, v.get_child_count() - 2)
		var pe := Profile.equipped.duplicate()
		for row in plan:
			pe[row.slot] = row.new
		var d := GearPower.hero_power(pe) - GearPower.hero_power()
		var pl := Hud._label(v, "Puissance d'équipement %s%s" % ["+" if d >= 0 else "−", GearPower.fmt(absi(d))], 16, ForgeWidgets.GAIN if d >= 0 else ForgeWidgets.PERTE)
		pl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.move_child(pl, v.get_child_count() - 2)

	## Ligne de l'aperçu : emplacement, pièce actuelle → pièce recommandée (cases avec leur carte au survol).
	static func _best_row(row: Dictionary) -> Control:
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 8)
		var n := Hud._label(h, String(InventoryPage.SLOT_CAPTIONS.get(row.slot, Items.SLOT_NAMES.get(row.slot, row.slot))), UiTheme.MIN_TEXT, UiTheme.MUTED)
		n.custom_minimum_size = Vector2(120, 0)
		n.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		for k in ["old", "new"]:
			var s := ItemWidgets.ItemSlot.new(40.0)
			s.set_item(row[k])
			s.placeholder = "vide" if (row[k] as Dictionary).is_empty() else ""
			s.disabled = (row[k] as Dictionary).is_empty()
			h.add_child(s)
			if k == "old":
				Hud._label(h, "→", 18, UiTheme.TEXT).size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var nm := Hud._label(h, Items.display_name(row.new), UiTheme.MIN_TEXT, Items.color_of(row.new))
		nm.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		nm.custom_minimum_size = Vector2(200, 0)
		nm.clip_text = true
		nm.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		return h

	func _entry(text: String, cb: Callable) -> Button:
		var b := Button.new()
		b.text = text
		b.focus_mode = Control.FOCUS_NONE
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size = Vector2(300, 36)
		b.add_theme_font_size_override("font_size", 14)
		b.add_theme_stylebox_override("normal", UiTheme.flat_box(Color(0.1, 0.08, 0.18, 0.95), Color(0, 0, 0, 0), 1, 6, false))
		b.pressed.connect(func():
			if is_instance_valid(_pop):
				_pop.hide()
			cb.call())
		return b


# --- aperçu 3D du héros ---------------------------------------------------------------------
class HeroPreview extends SubViewportContainer:
	var _vp: SubViewport
	var _pivot: Node3D
	var _shown := ""
	var _drag := false
	var spin := true  # rotation automatique lente
	var idle_pose := false  # posture de repos (debout) plutôt que de combat
	var cam: Camera3D

	func _init() -> void:
		stretch = true
		mouse_filter = Control.MOUSE_FILTER_STOP
		_vp = SubViewport.new()
		_vp.own_world_3d = true
		# fond opaque : les lueurs additives des auras restent visibles (sur fond transparent, elles
		# ne se voyaient que par-dessus le personnage)
		_vp.transparent_bg = false
		_vp.msaa_3d = Viewport.MSAA_2X
		add_child(_vp)
		var env := WorldEnvironment.new()
		env.environment = Environment.new()
		env.environment.background_mode = Environment.BG_COLOR
		env.environment.background_color = Color(0.2, 0.16, 0.34)  # encre 500 (bible : jamais de fond noir ; les auras restent visibles)
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
		cam = Camera3D.new()
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

	## Visage montré à la place de celui du profil (aperçu de la création de personnage) ; null = celui du profil.
	var look_override = null

	## Pivote le héros de [param angle] radians (stick droit de la manette).
	func turn(angle: float) -> void:
		_pivot.rotation.y += angle

	func show_hero(class_id: String, weapon_code: String) -> void:
		var look: Dictionary = HeroLook.sanitize(look_override) if look_override is Dictionary else HeroLook.current()
		var key := class_id + "|" + weapon_code + "|" + Profile.outfit_of(class_id) + "|" + "|".join(Profile.worn_parts(class_id)) \
			+ "|" + "|".join(Profile.worn_auras(class_id).map(func(x): return str(int(x.id)))) + "|" + str(Profile.dye_map(class_id)) + "|" + str(Profile.aura_tint(class_id)) \
			+ "|" + str(look)
		if key == _shown:
			return
		_shown = key
		for c in _pivot.get_children():
			c.queue_free()
		var cls := GameData.class_data(class_id)
		if cls.is_empty() or not ResourceLoader.exists(String(cls.get("model", ""))):
			return
		var model := EdenModel.instantiate_hero(cls, Profile.outfit_of(class_id), Profile.worn_parts(class_id), Profile.dye_map(class_id), look)
		model.scale = Vector3.ONE * GameData.HERO_SCALE
		_pivot.add_child(model)
		EdenModel.attach_weapon(model, EdenModel.weapon_entry(cls, weapon_code))
		EdenFx.attach_auras(_pivot, class_id, GameData.HERO_SCALE, true)
		var ap := EdenModel.find_anim_player(model)
		var battle: String = cls.get("anims", {}).get("idle" if idle_pose else "battle", "stand01")
		if ap and ap.has_animation(battle):
			ap.get_animation(battle).loop_mode = Animation.LOOP_LINEAR
			ap.play(battle)

	## Apparence choisie (éditeur d'adversaire) : tenue [param body], pièces [param extra].
	func show_look(class_id: String, weapon_code: String, body: String, extra: Array, dyes: Dictionary = {}, aura_ids: Array = [], aura_tint := Color(1, 1, 1, 0)) -> void:
		var key := "look|%s|%s|%s|%s|%s|%s|%s" % [class_id, weapon_code, body, "|".join(extra), str(dyes), str(aura_ids), str(aura_tint)]
		if key == _shown:
			return
		_shown = key
		for c in _pivot.get_children():
			c.queue_free()
		var cls := GameData.class_data(class_id)
		if cls.is_empty():
			return
		var model := EdenModel.instantiate_hero(cls, body, extra.filter(func(p): return String(p) != "" and ResourceLoader.exists(String(p))), dyes)
		model.scale = Vector3.ONE * GameData.HERO_SCALE
		_pivot.add_child(model)
		EdenModel.attach_weapon(model, EdenModel.weapon_entry(cls, weapon_code))
		EdenFx.attach_aura_ids(_pivot, aura_ids, GameData.HERO_SCALE, true, aura_tint)
		var ap := EdenModel.find_anim_player(model)
		var battle: String = cls.get("anims", {}).get("battle", "stand01")
		if ap and ap.has_animation(battle):
			ap.get_animation(battle).loop_mode = Animation.LOOP_LINEAR
			ap.play(battle)

	func _process(delta: float) -> void:
		if is_visible_in_tree() and not _drag and spin:
			_pivot.rotation.y += delta * 0.35

	## Souris : glisser (clic gauche) pour tourner, molette pour zoomer, glisser au clic droit
	## pour monter / descendre (ailes, chapeaux, armes vus de près) ; double-clic : cadrage d'origine.
	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton:
			match event.button_index:
				MOUSE_BUTTON_LEFT:
					_drag = event.pressed
					if event.pressed and event.double_click:
						_zoom = 1.0
						_lift = 0.0
						_apply_frame()
				MOUSE_BUTTON_RIGHT:
					_pan = event.pressed
				MOUSE_BUTTON_WHEEL_UP:
					if event.pressed:
						_zoom = clampf(_zoom * 0.9, 0.35, 2.2)
						_apply_frame()
						accept_event()
				MOUSE_BUTTON_WHEEL_DOWN:
					if event.pressed:
						_zoom = clampf(_zoom / 0.9, 0.35, 2.2)
						_apply_frame()
						accept_event()
		elif event is InputEventMouseMotion:
			if _drag:
				_pivot.rotation.y += event.relative.x * 0.01
			elif _pan:
				_lift = clampf(_lift + event.relative.y * 0.006 * _zoom, -0.8, 1.6)
				_apply_frame()

	var _zoom := 1.0
	var _lift := 0.0
	var _pan := false
	var _frame := Vector2(4.6, 1.05)  # distance, hauteur visée (cadrage d'origine)

	## Cadrage : distance de la caméra et hauteur visée (héros en pied).
	func frame(distance: float, look_y: float, yaw := 0.0) -> void:
		_frame = Vector2(distance, look_y)
		_zoom = 1.0
		_lift = 0.0
		_apply_frame()
		_pivot.rotation.y = yaw

	func _apply_frame() -> void:
		var d := _frame.x * _zoom
		# en zoomant, la visée remonte vers le buste (sinon on ne voit plus que les jambes)
		var y := _frame.y + _lift + (1.0 - minf(_zoom, 1.0)) * 0.25
		cam.transform = Transform3D(Basis(), Vector3(0, y + 0.25 * _zoom, d)).looking_at(Vector3(0, y, 0))
