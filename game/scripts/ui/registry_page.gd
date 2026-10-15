class_name RegistryPage
extends CarnetPages.ScrollPage
## Registre de l'équipement (Carnet, lot E3) : pour chaque classe, sa puissance d'équipement face à la
## puissance attendue, l'arme du bon type, les pièces (celles de départ ne comptent pas), la panoplie de donjon
## et celle des Esprits, les pièces à +10, les gemmes, les enchantements, et une ligne « Il manque : … → activité ».
## Les moins équipées d'abord ; un clic sur une classe débloquée ouvre son équipement.

const FILTERS := ["Débloquées", "Toutes", "À équiper"]
const STATUS_COLORS := [Color(0.62, 0.6, 0.7), Color(1.0, 0.62, 0.45), Color(1.0, 0.82, 0.4), Color(0.55, 1.0, 0.6), Color(1.0, 0.84, 0.25)]
const ICON := 40.0

var _filter := 0
var _profile := ""  # "" : tous les profils


func subtitle() -> String:
	return "Ce qui manque à chaque classe"


func refresh() -> void:
	var all := ClassGear.entries()
	# P2 : rouvrir le Registre sans rien de changé ne reconstruit pas les 60 fiches (et garde le défilement)
	var opened: Array = []
	for e in all:
		opened.append(Progression.class_unlocked(String(e.cid)))
	var locks: Array = ["armory", "pantheon", "dungeons", "forge", "tower", "siege"].map(func(u): return Unlocks.is_open(u))
	if unchanged([all, opened, locks, _filter, _profile, GearPower.target_level(), view_size()]):
		return
	clear()
	var n_ok := all.filter(func(e): return int(e.status) >= ClassGear.STATUS_EQUIPPED).size()
	heading("Registre de l'équipement", "%d / %d équipées" % [n_ok, all.size()])
	var unlocked := all.filter(func(e): return Progression.class_unlocked(String(e.cid)))
	var todo := all.filter(func(e): return int(e.status) < ClassGear.STATUS_EQUIPPED)
	var counts := [unlocked.size(), all.size(), todo.size()]
	var labels: Array = []
	for i in FILTERS.size():
		labels.append("%s · %d" % [FILTERS[i], counts[i]])
	CarnetPages.chips(_box, labels, _filter, func(i):
		_filter = i
		refresh())
	var pids := ClassGear.profile_ids()
	var plabels: Array = ["Tous les profils"]
	for pid in pids:
		plabels.append(ClassGear.profile_name(String(pid)))
	var prow := CarnetPages.chips(_box, plabels, pids.find(_profile) + 1, func(i):
		_profile = "" if i == 0 else String(pids[i - 1])
		refresh())
	for i in range(1, prow.get_child_count()):
		var desc := String(ClassGear.data().profiles[pids[i - 1]].get("desc", ""))
		prow.get_child(i).tooltip_text = "%s · %s" % [desc, _plural(ClassGear.classes_of(String(pids[i - 1])).size(), "classe")]
	var shown: Array = [unlocked, all, todo][_filter]
	if _profile != "":
		shown = shown.filter(func(e): return String(e.profile) == _profile)
	shown.sort_custom(_less_equipped)
	if shown.is_empty():
		empty("Aucune classe ici." if _filter != 2 else "✔ Toutes ces classes sont équipées.")
		built()
		return
	for e in shown:
		_row(e)
	built()


## Les moins équipées d'abord : état, puis part de la puissance attendue, puis classes débloquées, puis le nom.
static func _less_equipped(a: Dictionary, b: Dictionary) -> bool:
	if int(a.status) != int(b.status):
		return int(a.status) < int(b.status)
	if not is_equal_approx(float(a.ratio), float(b.ratio)):
		return float(a.ratio) < float(b.ratio)
	var ua := Progression.class_unlocked(String(a.cid))
	var ub := Progression.class_unlocked(String(b.cid))
	if ua != ub:
		return ua
	return ClassGear.class_label(String(a.cid)).naturalnocasecmp_to(ClassGear.class_label(String(b.cid))) < 0


static func _plural(n: int, word: String) -> String:
	return "%d %s%s" % [n, word, "s" if n > 1 else ""]


func _row(e: Dictionary) -> void:
	var cid := String(e.cid)
	var narrow := get_viewport().get_visible_rect().size.x < 1500.0  # 1280 : colonnes plus serrées, la ligne tient dans l'écran
	var open := Progression.class_unlocked(cid)
	var v := card(_box)
	var pc: PanelContainer = v.get_parent()
	v.add_theme_constant_override("separation", 4)
	if not open:
		pc.modulate = Color(1, 1, 1, 0.62)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 10 if narrow else 14)
	v.add_child(top)
	var icon := TextureRect.new()
	icon.texture = UiTheme.texture(String(GameData.class_data(cid).get("icon", "")))
	icon.custom_minimum_size = Vector2(ICON, ICON)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(icon)
	var names := VBoxContainer.new()
	names.add_theme_constant_override("separation", -2)
	names.custom_minimum_size = Vector2(170 if narrow else 220, 0)
	names.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(names)
	Hud._label(names, ClassGear.class_label(cid), 18, UiTheme.TEXT)
	Hud._label(names, ClassGear.profile_name(String(e.profile)) + ("" if open else " · verrouillée"), 13, UiTheme.MUTED)
	# puissance d'équipement face à la puissance attendue
	var pw := VBoxContainer.new()
	pw.add_theme_constant_override("separation", 2)
	pw.custom_minimum_size = Vector2(190 if narrow else 250, 0)
	pw.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(pw)
	var pl := Hud._label(pw, "PE %s / %s" % [GearPower.fmt(int(e.pe)), GearPower.fmt(int(e.expected))], 14, UiTheme.TEXT)
	pl.mouse_filter = Control.MOUSE_FILTER_PASS
	pl.tooltip_text = "Puissance d'équipement du préréglage actif · attendue au niveau %d · %s" % [GearPower.target_level(), e.tier]
	var pb := _progress(minf(float(e.ratio), 1.0), 1.0, Vector2(170 if narrow else 230, 8))
	pb.step = 0.0
	pb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pw.add_child(pb)
	# compteurs
	var slots := Items.SLOTS.size()
	var nums := HBoxContainer.new()
	nums.add_theme_constant_override("separation", 10 if narrow else 18)
	nums.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nums.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(nums)
	var wname := String(GameData.weapon_type(Items.default_weapon_type(cid)).get("name", ""))
	var ws := String(e.weapon_state)
	var wb := _count(nums, "Arme", "✗" if ws == "none" else wname, ws == "ok",
		"Arme principale (%s)%s" % [wname.to_lower(), {"ok": "", "base": " : celle de départ", "none": " : aucune"}[ws]])
	wb.custom_minimum_size = Vector2(96 if narrow else 118, 0)
	_count(nums, "Pièces", "%d / %d" % [int(e.filled) - int(e.base), slots], int(e.filled) - int(e.base) >= slots,
		"%s de départ, %s" % [_plural(int(e.base), "pièce"), _plural(slots - int(e.filled), "emplacement vide")] if int(e.base) + slots - int(e.filled) > 0 else "Les %d emplacements portent une vraie pièce" % slots)
	_count(nums, "Panoplie", "%d / %d" % [int(e.arch), ClassGear.PANOPLY], int(e.arch) >= ClassGear.PANOPLY,
		("Panoplie de donjon : %s" % e.arch_name) if String(e.arch_name) != "" else "Panoplie de donjon (Donjons, fabrication)")
	_count(nums, "Esprits", "%d / %d" % [int(e.spirits), ClassGear.PANOPLY], int(e.spirits) >= ClassGear.PANOPLY, "Panoplie des Esprits (Panthéon, Armurerie)")
	_count(nums, "+10", "%d / %d" % [int(e.plus10), slots], int(e.plus10) >= slots, "Pièces montées à +10 (Forge)")
	_count(nums, "Gemmes", "%d / %d" % [int(e.gems), int(e.gem_max)], int(e.gems) >= int(e.gem_max), "Gemmes serties (Forge)")
	_count(nums, "Enchant.", "%d / %d" % [int(e.enchants), slots], int(e.enchants) >= slots, "Pièces enchantées (Forge)")
	var st := Hud._label(top, String(ClassGear.STATUS[int(e.status)]), 15, STATUS_COLORS[int(e.status)])
	st.custom_minimum_size = Vector2(96 if narrow else 110, 0)
	st.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	st.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	# ce qui manque d'abord, et où le trouver
	var need := RichTextLabel.new()
	need.bbcode_enabled = true
	need.fit_content = true
	need.scroll_active = false
	need.autowrap_mode = TextServer.AUTOWRAP_OFF
	need.add_theme_font_size_override("normal_font_size", 14)
	need.mouse_filter = Control.MOUSE_FILTER_PASS
	need.custom_minimum_size = Vector2(0, 20)
	if String(e.need) == "":
		need.text = "[color=#8cff99]Équipement optimal.[/color]"
	else:
		var act := String(e.activity)
		var locked := String(e.unlock) != "" and not Unlocks.is_open(String(e.unlock))
		need.text = "[color=#c7c2db]Il manque : %s  →  [/color][color=#%s]%s[/color]%s" % [e.need, UiTheme.GOLD.to_html(false), act, "[color=#8a86a0]  (verrouillé)[/color]" if locked else ""]
		if locked:
			need.tooltip_text = Unlocks.condition(String(e.unlock))
	var pad := MarginContainer.new()
	pad.add_theme_constant_override("margin_left", int(ICON) + 14)
	pad.add_child(need)
	v.add_child(pad)
	if open:
		pc.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		pc.tooltip_text = "Voir l'équipement de la classe"
		pc.gui_input.connect(func(ev: InputEvent):
			if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
				_open_class(cid))


## Petit compteur : intitulé discret au-dessus, valeur (verte quand c'est complet).
func _count(parent: Control, title: String, value: String, done: bool, tip: String) -> VBoxContainer:
	var b := VBoxContainer.new()
	b.add_theme_constant_override("separation", -3)
	b.custom_minimum_size = Vector2(52 if get_viewport().get_visible_rect().size.x < 1500.0 else 62, 0)
	b.mouse_filter = Control.MOUSE_FILTER_PASS
	b.tooltip_text = tip
	parent.add_child(b)
	Hud._label(b, title, 12, UiTheme.MUTED)
	var l := Hud._label(b, value, 16, CarnetPages.GREEN if done else UiTheme.TEXT)
	l.add_theme_font_override("font", UiTheme.bold_font())
	return b


## Ouvre Héros > Équipement sur la classe [param cid].
func _open_class(cid: String) -> void:
	if Profile.in_run or not Progression.class_unlocked(cid):
		return
	if cid != Profile.selected_class:
		Profile.selected_class = cid
		Profile.save_profile()
	CarnetPages.open_hero(self, "equipment")
