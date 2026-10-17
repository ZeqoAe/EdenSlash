class_name QuestsPage
extends RefCounted
## Lignes des quêtes (passe M5) : la série, les trois quêtes du jour (dont le Défi du jour, qui se lance d'ici), les deux
## de la semaine et les défis de la classe choisie. Une ligne = une consigne, sa jauge et sa récompense en pastilles ; tout
## détail est en infobulle. Depuis le lot HUB-1, les quêtes vivent dans le Journal (QuestJournal, touche L) qui reprend ces
## lignes avec, en plus ([param opts]), « Y aller » et l'épingle « Suivre » ; [method fill] remplit encore une boîte d'un coup.
## [param on_launch] reçoit la classe du Défi du jour, [param on_changed] redessine la page.

const ROW_BG := Color(0.07, 0.06, 0.14, 0.82)


static func fill(box: VBoxContainer, on_launch: Callable, on_changed: Callable, opts := {}) -> void:
	if not Quests.enabled():
		return
	var st := Quests.state()
	box.add_child(_series())
	_section(box, "Aujourd'hui · %s" % date_fr(Quests.today()), "Trois quêtes par jour, le Défi du jour compris. Une quête accomplie prolonge la série.")
	var daily: Array = st.daily
	for i in daily.size():
		box.add_child(_row(daily[i], i, "daily", on_launch, on_changed, opts))
	_section(box, "Cette semaine", "Deux grandes quêtes, jusqu'à dimanche soir.")
	for i in (st.weekly as Array).size():
		box.add_child(_row(st.weekly[i], i, "weekly", on_launch, on_changed, opts))
	var cls := Profile.selected_class
	_section(box, "Défis de classe · %s" % ClassGear.class_label(cls), "Ils se remplissent à chaque Survie avec cette classe, puis sont remplacés.")
	for c in Quests.class_challenges(cls):
		box.add_child(_class_row(c))


## « 2026-10-15 » -> « 15 octobre ».
static func date_fr(iso: String) -> String:
	var p := iso.split("-")
	var months := ["janvier", "février", "mars", "avril", "mai", "juin", "juillet", "août", "septembre", "octobre", "novembre", "décembre"]
	if p.size() != 3 or int(p[1]) < 1 or int(p[1]) > 12:
		return iso
	return "%d %s" % [int(p[2]), months[int(p[1]) - 1]]


static func _section(box: Control, text: String, tip := "") -> Label:
	var l := Hud._label(box, text, 15, UiTheme.GOLD)
	l.add_theme_font_override("font", UiTheme.bold_font())
	if tip != "":
		l.mouse_filter = Control.MOUSE_FILTER_STOP
		l.tooltip_text = tip
	return l


# --- la série --------------------------------------------------------------------------------------------------
static func _series() -> Control:
	var n := Quests.series_n()
	var nxt := Quests.next_gift(n)
	var prev := Quests.floor_step(n)
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", _box(Color(0.1, 0.08, 0.2, 0.9), Color(UiTheme.GOLD_DIM, 0.8)))
	p.tooltip_text = series_tip()
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	p.add_child(h)
	var head := Hud._label(h, "Série", 16, UiTheme.GOLD)
	head.add_theme_font_override("font", UiTheme.bold_font())
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var days := Hud._label(h, "%d jour%s" % [n, "s" if n > 1 else ""], 16, UiTheme.TEXT)
	days.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if nxt.is_empty():
		return p
	var bar := _bar(float(n - prev), float(maxi(1, int(nxt.n) - prev)))
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(bar)
	var goal := GainChips.chip("look", 20)
	h.add_child(goal)
	var g := Hud._label(goal, "%d" % int(nxt.n), 15, UiTheme.MUTED)
	g.mouse_filter = Control.MOUSE_FILTER_IGNORE
	goal.tooltip_text = "Prochain palier : %s, à %d jours." % [Quests.gift_text(nxt), int(nxt.n)]
	return p


## Règles de la série et tous ses paliers (infobulle).
static func series_tip() -> String:
	var lines: PackedStringArray = ["Une quête du jour accomplie par jour prolonge la série.",
		"Un jour d'absence est pardonné ; au-delà, elle retombe à son dernier palier gagné."]
	for g in Quests.SERIES_GIFTS:
		lines.append("%d jours : %s" % [int(g.n), Quests.gift_text(g)])
	return "\n".join(lines)


# --- les lignes -------------------------------------------------------------------------------------------------
## Ligne de quête : puits d'encre contouré (UIK1) ; une ligne mise en avant garde son liseré de couleur (or : quête faite).
static func _box(bg: Color, border: Color) -> StyleBoxFlat:
	var ink := UiTheme.color("encre.900")
	var accent := border.s > 0.3 and border.a > 0.7 and border.v > 0.9  # liseré vif voulu (or plein…), sinon encre
	var sb := UiTheme.flat_box(UiTheme.color("encre.500") if bg.get_luminance() < 0.15 else bg, border if accent else ink, 3 if not accent else 2, 14, false)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	return sb


static func _bar(value: float, max_value: float) -> ProgressBar:
	var b := ProgressBar.new()
	b.show_percentage = false
	b.min_value = 0.0
	b.max_value = max_value
	b.value = clampf(value, 0.0, max_value)
	b.custom_minimum_size = Vector2(60, 8)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_theme_stylebox_override("background", UiTheme.flat_box(Color(0.02, 0.02, 0.06, 0.9), Color(0, 0, 0, 0), 0, 4, false))
	b.add_theme_stylebox_override("fill", UiTheme.flat_box(UiTheme.GOLD, Color(0, 0, 0, 0), 0, 4, false))
	return b


## Les pastilles de récompense : icône et montant (infobulle : à quoi ça sert).
static func _chips(parent: Control, chips: Array) -> void:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	h.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	parent.add_child(h)
	for c in chips:
		var chip := GainChips.chip(String(c.kind), 20)
		if String(c.get("tip", "")) != "":
			chip.tooltip_text = "%s\n%s" % [String(c.tip), ResourceHelp.tip(String(c.kind))]
		if String(c.text) != "":
			var l := Hud._label(chip, String(c.text), 15, UiTheme.GOLD)
			l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_child(chip)


## Une quête ; [param opts] (Journal, lot HUB-1) : « go » (Callable(go: Dictionary) : « Y aller »), « pin » (vrai : l'épingle
## « Suivre » qui choisit la quête du HUD).
static func _row(q: Dictionary, index: int, period: String, on_launch: Callable, on_changed: Callable, opts := {}) -> Control:
	var done: bool = bool(q.done)
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", _box(ROW_BG, Color(UiTheme.BUFF, 0.5) if done else Color(Color(0.38, 0.38, 0.58), 0.85)))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	p.add_child(v)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	v.add_child(top)
	Ico.mark(top, "quest_done" if done else "quest_todo", 18)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 0)
	top.add_child(col)
	var title := Hud._label(col, Quests.title(q), 16, UiTheme.MUTED if done else UiTheme.TEXT)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var sub := Quests.subtitle(q)
	if sub != "":
		var s := Hud._label(col, sub, 13, UiTheme.MUTED)
		s.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	p.tooltip_text = Quests.tooltip(q)
	_chips(top, Quests.chips_of(q))
	if period == "daily" and not done and Quests.can_reroll():
		var rr := MenuWidgets.glass_button("↻", 18, Vector2(36, 34))
		rr.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		rr.tooltip_text = "Changer cette quête (une fois par jour)"
		rr.pressed.connect(func():
			if Quests.reroll(index):
				on_changed.call())
		top.add_child(rr)
	if bool(opts.get("pin", false)) and not done:
		var pinned := Quests.is_pinned(period, q)
		var pb := MenuWidgets.glass_button("★ Suivie" if pinned else "☆ Suivre", 14, Vector2(100, 34))
		pb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		pb.tooltip_text = "Ne plus la suivre dans le HUD" if pinned else "La suivre dans le HUD pendant les parties"
		if pinned:
			pb.add_theme_color_override("font_color", UiTheme.GOLD)
		pb.pressed.connect(func():
			Quests.toggle_pin(period, q)
			on_changed.call())
		top.add_child(pb)
	var go_cb: Callable = opts.get("go", Callable())
	var where := Quests.go_of(q)
	if go_cb.is_valid() and not done and not where.has("journal"):
		var gb := MenuWidgets.gold_button("Y aller", 15, Vector2(100, 34))
		gb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var an := Quests.act_name(q)
		gb.tooltip_text = ("Ouvre la page de l'activité : %s" % an) if not an in ["", "Toutes"] else "Ouvre le menu Jouer"
		gb.pressed.connect(func(): go_cb.call(where))
		top.add_child(gb)
	if int(q.t) > 1:
		_progress(v, Quests.live_progress(q) if not done else int(q.t), int(q.t))
	if String(Quests.def_of(q).get("special", "")) == "challenge" and not done and on_launch.is_valid():
		v.add_child(_launchers(on_launch))  # (en partie, le Journal n'a pas de lanceur : on_launch vide)
	return p


static func _progress(parent: Control, value: int, target: int) -> void:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	parent.add_child(h)
	var bar := _bar(float(value), float(target))
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(bar)
	var l := Hud._label(h, "%d / %d" % [mini(value, target), target], 13, UiTheme.MUTED)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE


## Les trois classes proposées pour le Défi du jour (au moins une en retard de maîtrise).
static func _launchers(on_launch: Callable) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	for cid in Challenge.classes_today():
		var cd := GameData.class_data(cid)
		var b := MenuWidgets.glass_button("%s\nmaîtrise %d" % [cd.get("name_fr", cid), Profile.expertise_level(cid)], 15, Vector2(0, 58))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.tooltip_text = "Lancer le Défi du jour avec cette classe"
		var c := String(cid)
		b.pressed.connect(func(): on_launch.call(c))
		row.add_child(b)
	return row


static func _class_row(c: Dictionary) -> Control:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", _box(ROW_BG, Color(Color(0.38, 0.38, 0.58), 0.85)))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	p.add_child(v)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	v.add_child(top)
	Ico.mark(top, "quest_todo", 18)
	var t := Hud._label(top, String(c.title), 16, UiTheme.TEXT)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_chips(top, [{"kind": "mastery", "text": str(int(c.reward.mastery)), "tip": "Maîtrise de cette classe."}])
	_progress(v, int(c.p), int(c.t))
	return p
