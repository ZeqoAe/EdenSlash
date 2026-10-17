class_name TodayPanel
extends PanelContainer
## Bloc « Aujourd'hui » du menu principal (lot HUB-1, P0-4) : la série, les trois quêtes du jour (coche, compteur) et le
## bouton du Journal. Lecture seule de Quests ; un clic sur une quête ou sur « Journal » ouvre le Journal
## ([signal open_journal]). Caché tant que les quêtes ne sont pas ouvertes (fil d'éveil « daily »). Rien d'obligatoire.
## Habillage provisoire (puits sombre, or) : à rhabiller avec UiTheme v2 (papier tramé, jetons bonbon) au lot UIK.

signal open_journal(tab: int)

const W := 352.0

var journal_button: Button
var quest_buttons: Array[Button] = []
var _box: VBoxContainer
var _series: Label
var _bar: ProgressBar
var _renew: Label
var _dot: NewsDot


func _init() -> void:
	custom_minimum_size = Vector2(W, 0)
	UiTheme.paper(self, 5, Vector2(12, 8), 16)  # carte papier autocollant (UIK1) : textes à l'encre, compteurs foncés
	mouse_filter = Control.MOUSE_FILTER_PASS
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 6)
	add_child(_box)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	_box.add_child(head)
	var t := Hud._label(head, "Aujourd'hui", 18, UiTheme.GOLD)
	t.add_theme_font_override("font", UiTheme.bold_font())
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_series = Hud._label(head, "", 15, UiTheme.TEXT)
	_series.mouse_filter = Control.MOUSE_FILTER_STOP
	_bar = QuestsPage._bar(0.0, 1.0)
	_bar.custom_minimum_size = Vector2(0, 6)
	_box.add_child(_bar)
	visible = false


## Redessine le bloc (au retour au menu, après une partie, quand une quête change).
func refresh() -> void:
	visible = Quests.enabled()
	if not visible:
		return
	var n := Quests.series_n()
	var nxt := Quests.next_gift(n)
	var prev := Quests.floor_step(n)
	_series.text = "Série : %d jour%s" % [n, "s" if n > 1 else ""]
	_series.tooltip_text = QuestsPage.series_tip()
	_bar.visible = not nxt.is_empty()
	if not nxt.is_empty():
		_bar.max_value = float(maxi(1, int(nxt.n) - prev))
		_bar.value = float(n - prev)
		_bar.tooltip_text = "Prochain palier : %s, à %d jours." % [Quests.gift_text(nxt), int(nxt.n)]
	for b in quest_buttons:
		_box.remove_child(b)
		b.queue_free()
	quest_buttons.clear()
	for c in _box.get_children():
		if c != _box.get_child(0) and c != _bar:
			_box.remove_child(c)
			c.queue_free()
	var daily: Array = Quests.daily()
	for i in daily.size():
		var q: Dictionary = daily[i]
		quest_buttons.append(_quest_button(q))
	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 8)
	_box.add_child(foot)
	_renew = Hud._label(foot, "Rien d'obligatoire", 13, UiTheme.MUTED)
	_renew.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_renew.mouse_filter = Control.MOUSE_FILTER_STOP
	_renew.tooltip_text = "Nouvelles quêtes dans %s. Une quête ratée revient demain ; une relance par jour." % Quests.renew_text()
	journal_button = MenuWidgets.paper_button("Journal (%s)" % Settings.action_label("journal", 1), 15, Vector2(140, 34))
	journal_button.tooltip_text = "Toutes les quêtes : du jour, de la semaine, de classe, la série"
	journal_button.pressed.connect(func(): open_journal.emit(0))
	foot.add_child(journal_button)
	_dot = NewsDot.attach(journal_button, NewsDots.MENU.journal)


func _quest_button(q: Dictionary) -> Button:
	var done := bool(q.done)
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.flat = true
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.custom_minimum_size = Vector2(0, 30)
	b.tooltip_text = "%s\n%s" % [Quests.title(q), Quests.tooltip(q)] if Quests.tooltip(q) != "" else Quests.title(q)
	b.add_theme_stylebox_override("hover", UiTheme.flat_box(Color(1, 1, 1, 0.06), Color(UiTheme.GOLD_DIM, 0.6), 1, 8, false))
	b.pressed.connect(func(): open_journal.emit(0))
	_box.add_child(b)
	var h := HBoxContainer.new()
	h.set_anchors_preset(Control.PRESET_FULL_RECT)
	h.add_theme_constant_override("separation", 8)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(h)
	Ico.mark(h, "quest_done" if done else "quest_todo", 16)
	var title := Hud._label(h, Quests.title(q), 15, UiTheme.MUTED if done else UiTheme.TEXT)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.clip_text = true
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.size_flags_vertical = Control.SIZE_FILL
	var cnt := Hud._label(h, "fait" if done else ("%d / %d" % [mini(int(q.p), int(q.t)), int(q.t)] if int(q.t) > 1 else ""), 14, UiTheme.BUFF if done else UiTheme.GOLD)
	cnt.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cnt.size_flags_vertical = Control.SIZE_FILL
	if Quests.is_pinned("daily", q):
		title.text = "★ " + title.text
	return b
