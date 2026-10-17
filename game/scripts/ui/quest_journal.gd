class_name QuestJournal
extends PageScreen
## Journal des quêtes (lot HUB-1, P0-5 de l'étude BM-HUB) : les quêtes sont une couche au-dessus de toutes les activités,
## plus une carte du menu Jouer. Ouvrable partout : touche du Journal (L par défaut), bloc « Aujourd'hui » du menu
## principal, menu pause, bilan de fin de partie.
## Onglets : Aujourd'hui (3 quêtes, dont le Défi du jour), Cette semaine (2), Classes (défis de la classe choisie), Série
## (paliers et règle du jour de grâce), Terminées. Chaque quête : « Y aller » (au menu principal seulement : la page de son
## activité) et l'épingle « Suivre » (la quête que montre le HUD en partie, Quests.toggle_pin). Rien n'est obligatoire :
## une quête ratée revient le lendemain, la série pardonne un jour d'absence.
## [codeblock]
## QuestJournal.open_on(hôte, onglet, func(go): …, func(classe): …, pause_le_jeu)
## [/codeblock]

const LAYER := 32  # au-dessus des écrans du menu (5), de la pause (15), des Paramètres et du bilan (30)
const TABS := [["day", "Aujourd'hui"], ["week", "Cette semaine"], ["class", "Classes"], ["series", "Série"], ["done", "Terminées"]]
const COL_W := 980.0

var on_go := Callable()  # Callable(go: Dictionary) : « Y aller » (vide en partie : le bouton n'est pas proposé)
var on_launch := Callable()  # Callable(classe) : Défi du jour (vide en partie)
var _dots: Array[NewsDot] = []


func _init() -> void:
	super("Journal", LAYER)


func _ready() -> void:
	super._ready()
	for t in TABS:
		var p := JournalPage.new()
		p.kind = String(t[0])
		p.journal = self
		add_page(String(t[1]), p)
	set_title("Journal", "Rien d'obligatoire : chaque quête rapporte, aucune ne bloque.")
	# pastilles des onglets (lot HUB-1, P0-1) : quête accomplie ou nouvelles quêtes pas encore vues
	for i in 2:
		_dots.append(set_tab_badge(i, ["journal.day" if i == 0 else "journal.week"]))
	page_changed.connect(_on_page)


## Ouvre le Journal sur [param host] (le même Journal s'il y est déjà) ; [param tab] : indice d'onglet (0 : Aujourd'hui).
## [param pause] : met le jeu en pause tant qu'il est ouvert (en partie, ouvert par sa touche ; jamais par-dessus la pause).
static func open_on(host: Node, tab := 0, go := Callable(), launch := Callable(), pause := false) -> QuestJournal:
	var j: QuestJournal = null
	for c in host.get_children():
		if c is QuestJournal:
			j = c
	if j == null:
		j = QuestJournal.new()
		host.add_child(j)
	j.on_go = go
	j.on_launch = launch
	j.pause_game = pause
	j.open(tab)
	return j


## Le Journal ouvert sous [param host], ou null.
static func find_open(host: Node) -> QuestJournal:
	if host == null:
		return null
	for c in host.get_children():
		if c is QuestJournal and (c as QuestJournal).is_open():
			return c
	return null


func _on_page(i: int) -> void:
	match String(TABS[i][0]):
		"day":
			NewsDots.see_group("journal.day")
		"week":
			NewsDots.see_group("journal.week")
		"done":
			NewsDots.see_group("journal.day")
			NewsDots.see_group("journal.week")
	for d in _dots:
		d.refresh()


## « Y aller » : le Journal se ferme, puis la page de l'activité s'ouvre.
func _go(where: Dictionary) -> void:
	close_ui()
	if on_go.is_valid():
		on_go.call(where)


func _launch(cid: String) -> void:
	close_ui()
	if on_launch.is_valid():
		on_launch.call(cid)


## Une page du Journal : une colonne centrée qui défile, reconstruite à chaque affichage (refresh).
class JournalPage extends Control:
	var kind := "day"
	var journal: QuestJournal
	var _scroll: ScrollContainer
	var _col: VBoxContainer

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		_scroll = ScrollContainer.new()
		_scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
		_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		add_child(_scroll)
		var center := HBoxContainer.new()
		center.alignment = BoxContainer.ALIGNMENT_CENTER
		center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_scroll.add_child(center)
		_col = VBoxContainer.new()
		_col.add_theme_constant_override("separation", 10)
		center.add_child(_col)

	func subtitle() -> String:
		match kind:
			"day":
				return "Nouvelles quêtes dans %s" % Quests.renew_text() if Quests.enabled() else ""
			"week":
				return "Jusqu'à dimanche soir"
			"class":
				return "En jouant cette classe"
			"series":
				return "Un jour d'absence pardonné"
			"done":
				return "Ce que tu as accompli"
		return ""

	func refresh() -> void:
		if _col == null:
			return
		var keep := _scroll.scroll_vertical
		for c in _col.get_children():
			_col.remove_child(c)
			c.queue_free()
		_col.custom_minimum_size.x = minf(COL_W, get_viewport().get_visible_rect().size.x - 120.0)
		if not Quests.enabled():
			var l := Hud._label(_col, Unlocks.lock_text("daily"), 17, UiTheme.MUTED)
			l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			return
		var opts := {"pin": true, "go": journal._go if journal.on_go.is_valid() else Callable()}
		var launch := journal._launch if journal.on_launch.is_valid() else Callable()
		var changed := refresh
		var st := Quests.state()
		match kind:
			"day":
				QuestsPage._section(_col, "Aujourd'hui · %s" % QuestsPage.date_fr(Quests.today()),
					"Trois quêtes par jour, le Défi du jour compris. Une quête accomplie prolonge la série.")
				var daily: Array = st.daily
				for i in daily.size():
					_col.add_child(QuestsPage._row(daily[i], i, "daily", launch, changed, opts))
				_note("Rien d'obligatoire · une relance par jour (↻) · une quête ratée revient demain.")
				_col.add_child(QuestsPage._series())
			"week":
				QuestsPage._section(_col, "Cette semaine", "Deux grandes quêtes, jusqu'à dimanche soir.")
				for i in (st.weekly as Array).size():
					_col.add_child(QuestsPage._row(st.weekly[i], i, "weekly", launch, changed, opts))
				_note("Une quête de la semaine non finie disparaît lundi, sans rien retirer.")
			"class":
				var cls := Profile.selected_class
				QuestsPage._section(_col, "Défis de classe · %s" % ClassGear.class_label(cls),
					"Ils se remplissent à chaque Survie avec cette classe, puis sont remplacés.")
				for c in Quests.class_challenges(cls):
					_col.add_child(QuestsPage._class_row(c))
				_note("Change de classe dans Héros pour voir ses défis.")
			"series":
				_col.add_child(QuestsPage._series())
				var claimed: Array = (st.series.get("claimed", []) as Array).map(func(x): return int(x))
				QuestsPage._section(_col, "Paliers de la série")
				for g in Quests.SERIES_GIFTS:
					var got := int(g.n) in claimed
					var row := HBoxContainer.new()
					row.add_theme_constant_override("separation", 10)
					_col.add_child(row)
					Hud._label(row, "◆" if got else "◇", 17, UiTheme.BUFF if got else UiTheme.GOLD_DIM).custom_minimum_size = Vector2(20, 0)
					var t := Hud._label(row, "%d jours : %s" % [int(g.n), Quests.gift_text(g)], 16, UiTheme.MUTED if got else UiTheme.TEXT)
					t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				_note("Un jour d'absence est pardonné ; au-delà, la série retombe à son dernier palier gagné, jamais à zéro.")
				var best := maxi(int(st.series.get("best", 0)), Quests.series_n())
				_note("Meilleure série : %d jour%s." % [best, "s" if best > 1 else ""])
			"done":
				var n := 0
				for period in ["daily", "weekly"]:
					for i in (st.get(period, []) as Array).size():
						var q: Dictionary = st[period][i]
						if bool(q.done):
							if n == 0:
								QuestsPage._section(_col, "Accomplies aujourd'hui et cette semaine")
							_col.add_child(QuestsPage._row(q, i, period, Callable(), changed, {}))
							n += 1
				if n == 0:
					_note("Aucune quête accomplie pour l'instant : elles se remplissent en jouant.")
				_note("Quêtes accomplies depuis le début : %d." % int(st.get("done", 0)))
		_restore_scroll.call_deferred(keep)

	func _restore_scroll(v: int) -> void:
		if is_instance_valid(_scroll):
			_scroll.scroll_vertical = v

	func _note(text: String) -> void:
		var l := Hud._label(_col, text, 14, UiTheme.MUTED)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
