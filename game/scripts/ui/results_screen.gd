class_name ResultsScreen
extends CanvasLayer
## Bilan de fin de run (victoire, défaite, abandon), choix de l'objet gardé en
## héritage (le reste est perdu), puis retour au lobby.

const TITLES := {"victoire": "VICTOIRE !", "defaite": "DÉFAITE", "abandon": "RUN ABANDONNÉE", "extraction": "EXTRACTION RÉUSSIE"}
const MUTED := Color(0.72, 0.72, 0.8)

var _choice = null  # objet gardé
var _buttons := {}  # uid -> Button
var _detail: RichTextLabel
var _confirm: Button


func show_results() -> void:
	layer = 30
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = true
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.01, 0.05, 0.82)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", Hud.style(Color(0.08, 0.07, 0.14, 0.97)))
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-560, -360)
	panel.custom_minimum_size = Vector2(1120, 720)
	root.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	panel.add_child(v)
	var t := Hud._label(v, TITLES.get(Run.result, "FIN"), 42,
		Hud.ACCENT if Run.result == "victoire" else (Color(0.5, 0.9, 1.0) if Run.result == "extraction" else Color(0.95, 0.4, 0.4)))
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var cls := Run.class_data()
	var s := Hud._label(v, "%s · niveau atteint %d · %s   ·   Monstres vaincus : %d   ·   Élites : %d   ·   Or gagné : %d" % [
		cls.get("name_fr", ""), Run.max_level, Run.duration_text(), Run.kills, Run.elites, Run.gold], 16, Color(0.9, 0.9, 0.95))
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if Run.unlocked_name != "":
		var u := Hud._label(v, "Nouvelle zone débloquée : %s !" % Run.unlocked_name, 22, Color(0.55, 1.0, 0.6))
		u.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var ex := Hud._label(v, "Expertise %s : +%d%s" % [cls.get("name_fr", ""), Run.expertise_gain,
		("   ·   NIVEAU %d ! (+%d points de talent)" % [Profile.expertise_level(Run.class_id), 2 * Run.expertise_levels]) if Run.expertise_levels > 0 else ""],
		17, Color(0.6, 0.85, 1.0))
	ex.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# récompenses de maîtrise gagnées (sorts, certificats) et classes débloquées
	var gained: PackedStringArray = []
	var lvl := Profile.expertise_level(Run.class_id)
	for l in range(lvl - Run.expertise_levels + 1, lvl + 1):
		for r in Progression.rewards_at(Run.class_id, l):
			if r.kind != "talent":
				gained.append(String(r.name) if r.kind == "cert" else "Sort : " + String(r.name))
	for c in Run.new_classes:
		gained.append("Nouvelle classe : " + String(GameData.class_data(c).get("name_fr", c)))
	for id in Run.new_cards():
		gained.append("Carte : " + String(Boons.get_def(id).get("name", id)))
	for c in Run.new_costumes:
		gained.append("Trésor : " + String(c))
	if not gained.is_empty():
		var g := Hud._label(v, "Débloqué : " + "  ·  ".join(gained), 18, Color(0.55, 1.0, 0.6))
		g.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		g.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var extract := Run.result == "extraction"
	var head := Hud._label(v, "Tout ton inventaire est conservé" if extract else "Choisis l'objet à garder en héritage", 24, Hud.ACCENT)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var sub := Hud._label(v, ("Équipement, inventaire et fournitures (gemmes, parchemins, pierres, ciseaux) sont gardés. L'or et les matériaux restent perdus." if extract
		else ("Il garde son amélioration. Tes fournitures rejoignent ta réserve ; or, matériaux et autres objets sont perdus." if Run.result == "victoire"
		else "Il garde son amélioration et pourra être porté au départ des prochaines runs. Tout le reste (or, matériaux, fournitures, butin) est perdu.")), 14, MUTED)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 16)
	v.add_child(body)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(640, 0)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	scroll.add_child(grid)
	var items := Profile.all_items()
	items.sort_custom(func(a, b): return _score(a) > _score(b))
	for item in items:
		grid.add_child(_item_button(item))
	var detail_panel := PanelContainer.new()
	detail_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_panel.add_theme_stylebox_override("panel", Hud.style(Color(0.1, 0.08, 0.16, 0.9)))
	body.add_child(detail_panel)
	_detail = RichTextLabel.new()
	_detail.bbcode_enabled = true
	_detail.add_theme_font_size_override("normal_font_size", 16)
	detail_panel.add_child(_detail)

	_confirm = Button.new()
	_confirm.custom_minimum_size = Vector2(0, 54)
	_confirm.add_theme_font_size_override("font_size", 20)
	_confirm.add_theme_stylebox_override("normal", Hud.style(Color(0.2, 0.15, 0.3)))
	_confirm.add_theme_stylebox_override("hover", Hud.style(Color(0.3, 0.22, 0.42)))
	_confirm.focus_mode = Control.FOCUS_NONE
	_confirm.pressed.connect(_finish)
	v.add_child(_confirm)
	add_child(root)
	# présélection : la meilleure pièce
	_select(items[0] if not items.is_empty() else null)
	if extract:
		_confirm.text = "Retour au lobby : %d objet(s) rejoignent ton héritage" % items.size()


## Valeur indicative d'un objet pour la présélection et le tri.
func _score(it: Dictionary) -> float:
	return float(it.rarity) * 100.0 + float(it.get("upgrade", 0)) * 25.0 + float(Items.power_level(it)) * 3.0 + float(it.get("quality", 1.0)) * 10.0


func _item_button(item: Dictionary) -> Button:
	var b := ItemWidgets.CardButton.new()
	b.item = item
	b.tooltip_text = Items.display_name(item)
	b.custom_minimum_size = Vector2(312, 62)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.focus_mode = Control.FOCUS_NONE
	b.clip_text = true
	var color: Color = Items.color_of(item)
	var worn := Profile.equipped.values().any(func(x): return is_same(x, item))
	b.text = "%s\n%s · %s · nv %d%s" % [Items.display_name(item), Items.SLOT_NAMES[item.slot],
		Items.RARITIES[int(item.rarity)].name, int(item.level), " · porté" if worn else ""]
	var icon_path := String(item.get("icon", ""))
	if icon_path != "" and ResourceLoader.exists(icon_path):
		b.icon = load(icon_path)
		b.add_theme_constant_override("icon_max_width", 44)
	b.add_theme_color_override("font_color", color)
	b.add_theme_color_override("font_hover_color", color.lightened(0.2))
	b.add_theme_font_size_override("font_size", 15)
	b.pressed.connect(_select.bind(item))
	_buttons[String(item.uid)] = [b, color]
	return b


func _select(item) -> void:
	_choice = item
	for uid in _buttons:
		var b: Button = _buttons[uid][0]
		var color: Color = _buttons[uid][1]
		var on: bool = item != null and String(item.uid) == uid
		var sb := Hud.style(Color(0.22, 0.17, 0.32) if on else Color(0.11, 0.09, 0.17, 0.95))
		sb.border_color = color if on else Color(color, 0.4)
		sb.set_border_width_all(3 if on else 2)
		sb.border_width_left = 7
		b.add_theme_stylebox_override("normal", sb)
		var hover := sb.duplicate() as StyleBoxFlat
		hover.bg_color = Color(0.24, 0.2, 0.34)
		b.add_theme_stylebox_override("hover", hover)
		b.add_theme_stylebox_override("pressed", hover)
	if item == null:
		_detail.text = "Aucun objet à garder."
		_confirm.text = "Retour au lobby"
		return
	var heir := Profile.vault.any(func(x): return String(x.uid) == String(item.uid))
	_detail.text = Items.describe(item) + ("\n\n[color=#9fd0ff]Pièce d'héritage : sa version de cette run (amélioration comprise) remplace l'ancienne.[/color]" if heir else "")
	_confirm.text = ("Retour au lobby : tout l'inventaire rejoint ton héritage" if Run.result == "extraction"
		else "Garder %s et retourner au lobby" % Items.display_name(item))


func _finish() -> void:
	if Run.result == "extraction":
		Profile.end_run_extract()
	else:
		Profile.end_run(_choice)
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/lobby.tscn")
