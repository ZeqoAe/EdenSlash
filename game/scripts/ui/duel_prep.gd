class_name DuelPrep
extends RefCounted
## Fenêtre « Préparer l'adversaire » du mode Duel (lobby) : son équipement (généré à ton niveau
## ou copie du tien), ses 4 sorts, ses multiplicateurs de PV et de dégâts, et l'aperçu de ses
## stats à côté des tiennes. Les réglages restent pour les duels suivants (Duel.gear_mode…).


## Ouvre la fenêtre par-dessus [param anchor] ; [param on_close] est appelé à la fermeture.
static func open(anchor: Node, on_close: Callable) -> CanvasLayer:
	var layer := CanvasLayer.new()
	layer.layer = 60
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.01, 0.05, 0.7)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(dim)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiTheme.flat_box(Color(0.05, 0.04, 0.1, 0.98), UiTheme.GOLD, 2, 12))
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(820, 640)
	panel.position = Vector2(-410, -320)
	layer.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	panel.add_child(v)
	var cd := GameData.class_data(Duel.rival_class)
	var t := Hud._label(v, "Préparer l'adversaire : %s" % cd.get("name_fr", Duel.rival_class), 24, UiTheme.GOLD)
	t.add_theme_font_override("font", UiTheme.title_font())
	var preview := RichTextLabel.new()
	preview.bbcode_enabled = true
	preview.fit_content = true
	preview.add_theme_font_size_override("normal_font_size", 15)
	preview.add_theme_font_size_override("bold_font_size", 15)
	var refresh := func(): preview.text = _preview_text()
	# équipement
	var g := _row(v, "Équipement")
	var gm := OptionButton.new()
	gm.focus_mode = Control.FOCUS_NONE
	for n in Duel.GEAR_MODES:
		gm.add_item(n)
	gm.select(Duel.gear_mode)
	gm.item_selected.connect(func(i):
		Duel.gear_mode = i
		refresh.call())
	gm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	g.add_child(gm)
	# sorts
	var choices := Duel.spell_choices(Duel.rival_class)
	var sg := GridContainer.new()
	sg.columns = 2
	sg.add_theme_constant_override("h_separation", 10)
	sg.add_theme_constant_override("v_separation", 6)
	v.add_child(sg)
	for i in 4:
		var row := HBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sg.add_child(row)
		var l := Hud._label(row, "Sort %d" % (i + 1), 14, UiTheme.TEXT)
		l.custom_minimum_size = Vector2(70, 0)
		var ob := OptionButton.new()
		ob.focus_mode = Control.FOCUS_NONE
		ob.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		ob.custom_minimum_size = Vector2(300, 0)
		ob.add_item("Choix de l'IA")
		var sel := 0
		for j in choices.size():
			ob.add_item(String(choices[j].name))
			ob.set_item_icon(j + 1, UiTheme.texture(String(choices[j].get("icon", ""))))
			if int(choices[j].id) == int(Duel.rival_spells[i]):
				sel = j + 1
		ob.add_theme_constant_override("icon_max_width", 22)
		ob.select(sel)
		var slot := i
		ob.item_selected.connect(func(k):
			Duel.rival_spells[slot] = int(choices[k - 1].id) if k > 0 else 0
			refresh.call())
		row.add_child(ob)
	# multiplicateurs
	var m := _row(v, "PV ×")
	var hp := _spin(m, Duel.hp_mult)
	hp.value_changed.connect(func(x):
		Duel.hp_mult = x
		refresh.call())
	Hud._label(m, "   Dégâts ×", 15, UiTheme.TEXT)
	var atk := _spin(m, Duel.atk_mult)
	atk.value_changed.connect(func(x):
		Duel.atk_mult = x
		refresh.call())
	v.add_child(preview)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(spacer)
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 10)
	v.add_child(bar)
	var reset := MenuWidgets.glass_button("Par défaut", 15, Vector2(160, 42))
	reset.pressed.connect(func():
		Duel.gear_mode = 1
		Duel.rival_spells = [0, 0, 0, 0]
		Duel.hp_mult = 1.0
		Duel.atk_mult = 1.0
		layer.queue_free()
		open(anchor, on_close))
	bar.add_child(reset)
	var close := MenuWidgets.gold_button("Valider", 20, Vector2(0, 42))
	close.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	close.pressed.connect(func():
		layer.queue_free()
		on_close.call())
	bar.add_child(close)
	refresh.call()
	anchor.get_tree().current_scene.add_child(layer)
	return layer


static func _row(parent: Control, label: String) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	parent.add_child(h)
	var l := Hud._label(h, label, 15, UiTheme.TEXT)
	l.custom_minimum_size = Vector2(110, 0)
	return h


static func _spin(parent: Control, value: float) -> SpinBox:
	var sp := SpinBox.new()
	sp.min_value = 0.1
	sp.max_value = 50.0
	sp.step = 0.1
	sp.value = value
	sp.custom_minimum_size = Vector2(120, 0)
	parent.add_child(sp)
	return sp


## Stats de l'adversaire préparé et les tiennes, au niveau du duel.
static func _preview_text() -> String:
	var lv := Duel.gear_level()
	var r := Duel.make_rival(lv)
	var p := Player.new()
	var was := Run.class_id
	if not Run.active:
		Run.class_id = Profile.selected_class
	p.class_id = Profile.selected_class
	p.cls = GameData.class_data(Profile.selected_class)
	p.level = lv
	p.recalc_stats()
	var magic := String(p.cls.get("dmg_type", "phys")) in ["mag", "magic"]
	var my_atk := p.matk if magic else p.atk
	var spells: PackedStringArray = []
	for s in r._skills:
		spells.append(String(s.name))
	var txt := "[b]Niveau du duel : %d[/b]\n" % lv
	txt += "[color=#ff9a8a][b]Adversaire[/b][/color] : PV [b]%s[/b] · attaque [b]%d[/b] · défense %d\n" % [Hud._big_number(r.max_hp), roundi(r.atk), roundi(r.defense)]
	txt += "   Sorts : %s\n" % (", ".join(spells) if not spells.is_empty() else "combo de l'arme seulement")
	txt += "[color=#9fd0ff][b]Toi[/b][/color] : PV [b]%s[/b] · attaque [b]%d[/b] · défense %d · critiques %d %% (+%d %% de dégâts)\n" % [
		Hud._big_number(p.max_hp), roundi(my_atk), roundi(p.defense), roundi((p.mcrit if magic else p.crit) * 100.0), roundi(p.crit_dmg * 100.0)]
	txt += "[color=#c8c8d4]Ton attaque profite aussi de tes talents, certificats et cartes, et tes sorts frappent bien au-delà de 100 % : monte ses PV pour un combat qui dure.[/color]"
	r.free()
	p.free()
	Run.class_id = was
	return txt
