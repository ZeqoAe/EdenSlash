class_name CarnetPages
extends RefCounted
## Pages du Carnet : vue d'ensemble de la complétion, succès et titres, cartes débloquées, codex
## des trophées. La Collection (archive des trésors) est dans `ArchivePages`.
## Chaque page donne son sous-titre (`subtitle()`, lu par PageScreen) et se reconstruit dans `refresh()`.

const GREEN := Color(0.55, 1.0, 0.6)


## Onglets du Carnet, dans l'ordre : [[nom, page]]. Pour ajouter un onglet (ex. le Registre de
## l'équipement), l'ajouter ici, à la fin : la Collection garde sa place (indice 4).
static func tabs() -> Array:
	return [
		["Vue d'ensemble", OverviewPage.new()],
		["Succès", AchievementsPage.new()],
		["Cartes", CardsPage.new()],
		["Trophées", TrophiesPage.new()],
		["Collection", ArchivePages.CollectionPage.new()],
		["Registre", RegistryPage.new()],
	]


## L'écran (PageScreen) qui contient la page, ou null.
static func screen_of(page: Node) -> PageScreen:
	var n := page.get_parent()
	while n != null and not n is PageScreen:
		n = n.get_parent()
	return n


## Affiche l'onglet dont la page est de ce script (ex. `CarnetPages.TrophiesPage`).
static func goto_tab(page: Node, kind: Script) -> void:
	var sc := screen_of(page)
	if sc == null:
		return
	for i in sc.page_count():
		if sc.page(i).get_script() == kind:
			sc.show_page(i)
			return


## Ferme le Carnet et ouvre une section de l'écran Héros ("cards", "class"...).
static func open_hero(page: Node, section: String) -> void:
	var sc := screen_of(page)
	if sc == null:
		return
	var lobby := sc.get_parent()
	sc.close_ui()
	if lobby != null and lobby.has_method("_open_hero"):
		lobby.call("_open_hero", section)


## Entier lisible, milliers séparés par une espace (« 10 500 »).
static func num(x: float) -> String:
	var s := str(int(x))
	var out := ""
	for i in s.length():
		if i > 0 and (s.length() - i) % 3 == 0:
			out += " "
		out += s[i]
	return out


## « 2026-10-15 » -> « 15/10/2026 » (tout autre texte tel quel).
static func date_fr(iso: String) -> String:
	var p := iso.split("-")
	return "%s/%s/%s" % [p[2], p[1], p[0]] if p.size() == 3 else iso


## Rangée de pastilles exclusives (filtre) : renvoie le conteneur ; `on_pick(indice)` à chaque choix.
static func chips(parent: Control, labels: Array, current: int, on_pick: Callable) -> HFlowContainer:
	var fl := HFlowContainer.new()
	fl.add_theme_constant_override("h_separation", 8)
	parent.add_child(fl)
	for i in labels.size():
		var b := MenuWidgets.glass_button(String(labels[i]), 15, Vector2(0, 36))
		b.toggle_mode = true
		b.button_pressed = i == current
		b.pressed.connect(func(): on_pick.call(i))
		fl.add_child(b)
	return fl


## Contenu défilant reconstruit à chaque ouverture.
class ScrollPage extends VBoxContainer:
	var _box: VBoxContainer
	var _sig := 0
	var _sig_next := 0

	func _init() -> void:
		var panel := ItemWidgets.panel(self, 0, true)
		var sc := ScrollContainer.new()
		sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
		sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		panel.add_child(sc)
		_box = VBoxContainer.new()
		_box.add_theme_constant_override("separation", 10)
		_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sc.add_child(_box)

	func clear() -> void:
		_sig = 0
		for c in _box.get_children():
			_box.remove_child(c)
			c.queue_free()

	## La page est-elle déjà construite pour ces données ? (P2 : rouvrir un onglet inchangé ne reconstruit rien et garde le
	## défilement.) [param data] : tout ce qui change l'affichage ; à appeler avant clear(), et ne renvoie vrai que si
	## la page n'a pas été vidée depuis.
	## Taille de la fenêtre (une mise en page qui en dépend fait partie de la signature).
	func view_size() -> Vector2:
		return get_viewport().get_visible_rect().size if is_inside_tree() else Vector2.ZERO

	func unchanged(data: Variant) -> bool:
		var h := hash(var_to_str(data)) | 1
		if h == _sig and _box.get_child_count() > 0:
			return true
		_sig_next = h
		return false

	## À appeler une fois la page reconstruite : mémorise la signature prise par unchanged().
	func built() -> void:
		_sig = _sig_next

	## En-tête de page : titre à gauche, compteur doré à droite.
	func heading(text: String, counter: String) -> void:
		var row := HBoxContainer.new()
		_box.add_child(row)
		var t := Hud._label(row, text, 28, UiTheme.GOLD)
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if counter != "":
			Hud._label(row, counter, 26, UiTheme.TEXT)

	func bar(label: String, got: int, total: int, detail := "") -> void:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		_box.add_child(row)
		var n := Hud._label(row, label, 17, UiTheme.TEXT)
		n.custom_minimum_size = Vector2(190, 0)
		row.add_child(_progress(got, total, Vector2(380, 22)))
		var c := Hud._label(row, "%d / %d" % [got, total], 16, UiTheme.GOLD)
		c.custom_minimum_size = Vector2(110, 0)
		if detail != "":
			var d := Hud._label(row, detail, 13, UiTheme.MUTED)
			d.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	static func _progress(got: float, total: float, size: Vector2) -> ProgressBar:
		var pb := ProgressBar.new()
		pb.max_value = maxf(total, 1.0)
		pb.value = got
		pb.show_percentage = false
		pb.custom_minimum_size = size
		pb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		return pb

	## Message d'une page vide (état utile : dit quoi faire).
	func empty(text: String) -> void:
		var l := Hud._label(_box, text, 16, UiTheme.MUTED)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.custom_minimum_size = Vector2(0, 240)
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	## Grille de deux colonnes de fiches.
	func cards_grid() -> GridContainer:
		var g := GridContainer.new()
		g.columns = 2
		g.add_theme_constant_override("h_separation", 12)
		g.add_theme_constant_override("v_separation", 8)
		g.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_box.add_child(g)
		return g

	## Fiche (cadre sombre) à placer dans une grille ; renvoie son contenu vertical.
	func card(parent: Control) -> VBoxContainer:
		var pc := PanelContainer.new()
		pc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		pc.add_theme_stylebox_override("panel", UiTheme.flat_box(Color(0.06, 0.05, 0.12, 0.9), Color(UiTheme.GOLD_DIM, 0.55), 1, 8, false))
		parent.add_child(pc)
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 2)
		pc.add_child(v)
		return v


## Vue d'ensemble : le bandeau de complétion, puis les dix catégories (cliquables quand elles ont une page).
class OverviewPage extends ScrollPage:
	## Catégorie -> page du Carnet ou section du Héros où la retrouver.
	const LINKS := {"Succès": "tab:Achievements", "Cartes": "tab:Cards", "Trophées": "tab:Trophies", "Classes": "hero:class", "Maîtrise": "hero:class",
		"Équipement": "tab:Registry"}

	func subtitle() -> String:
		return "Ta progression d'un coup d'œil"

	func refresh() -> void:
		Achievements.refresh()
		clear()
		var cats := Completion.categories()
		var pct := Completion.percent()
		# bandeau : pourcentage, barre, catégorie la plus proche de la fin
		var band := PanelContainer.new()
		band.add_theme_stylebox_override("panel", UiTheme.flat_box(Color(0.12, 0.09, 0.2, 0.95), UiTheme.GOLD_DIM, 2, 10, false))
		_box.add_child(band)
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 22)
		band.add_child(h)
		var big := Hud._label(h, "%d %%" % pct, 52, UiTheme.GOLD)
		big.custom_minimum_size = Vector2(150, 0)
		big.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var mid := VBoxContainer.new()
		mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		mid.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		mid.add_theme_constant_override("separation", 4)
		h.add_child(mid)
		Hud._label(mid, "Complétion", 20, UiTheme.TEXT)
		var pb := _progress(pct, 100, Vector2(0, 20))
		pb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		mid.add_child(pb)
		var near := _nearest(cats)
		if near != "":
			var n := Hud._label(h, near, 15, UiTheme.MUTED)
			n.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			n.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		# catégories
		var g := cards_grid()
		for c in cats:
			_category(g, c)

	## « Bientôt : Succès » : la catégorie non terminée la plus avancée.
	func _nearest(cats: Array) -> String:
		var best := -1.0
		var name := ""
		for c in cats:
			var r := float(c[1]) / maxf(float(c[2]), 1.0)
			if r < 1.0 and r > best:
				best = r
				name = String(c[0])
		return "Le plus avancé : %s" % name if best > 0.0 else ""

	func _category(parent: Control, c: Array) -> void:
		var got := int(c[1])
		var total := int(c[2])
		var link := String(LINKS.get(String(c[0]), ""))
		var v := card(parent)
		var pc: PanelContainer = v.get_parent()
		pc.custom_minimum_size = Vector2(0, 100)
		v.alignment = BoxContainer.ALIGNMENT_CENTER
		v.add_theme_constant_override("separation", 6)
		var top := HBoxContainer.new()
		v.add_child(top)
		var name_l := Hud._label(top, String(c[0]) + ("  ›" if link != "" else ""), 21, UiTheme.TEXT)
		name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		Hud._label(top, "%s / %s" % [CarnetPages.num(got), CarnetPages.num(total)], 20, GREEN if got >= total else UiTheme.GOLD)
		var pb := _progress(got, total, Vector2(0, 16))
		pb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		pb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(pb)
		Hud._label(v, String(c[3]), 14, UiTheme.MUTED)
		if link != "":
			pc.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			pc.gui_input.connect(func(ev: InputEvent):
				if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
					_follow(link))

	func _follow(link: String) -> void:
		var kind := link.get_slice(":", 1)
		if link.begins_with("hero:"):
			CarnetPages.open_hero(self, kind)
			return
		match kind:
			"Achievements":
				CarnetPages.goto_tab(self, CarnetPages.AchievementsPage)
			"Cards":
				CarnetPages.goto_tab(self, CarnetPages.CardsPage)
			"Trophies":
				CarnetPages.goto_tab(self, CarnetPages.TrophiesPage)
			"Registry":
				CarnetPages.goto_tab(self, RegistryPage)


## Succès : obtenus d'abord, puis ceux en cours par avancement ; titres à porter.
class AchievementsPage extends ScrollPage:
	var _filter := 0  # 0 tous, 1 en cours, 2 obtenus

	func subtitle() -> String:
		return "Défis relevés, titres à porter"

	func refresh() -> void:
		Achievements.refresh()
		# P2 : rouvrir l'onglet sans nouveau progrès ne reconstruit pas les 40 fiches
		var state: Array = [_filter, Profile.title, Achievements.titles(), Profile.achievements, view_size()]
		for a in Achievements.LIST:
			state.append(Achievements.progress(a))
		if unchanged(state):
			return
		clear()
		var cnt := Achievements.count()
		heading("Succès", "%d / %d" % [int(cnt.x), int(cnt.y)])
		_titles_row()
		CarnetPages.chips(_box, ["Tous", "En cours", "Obtenus"], _filter, func(i):
			_filter = i
			refresh())
		var owned_list: Array = []
		var todo: Array = []
		for a in Achievements.LIST:
			if Achievements.owned(a.id):
				owned_list.append(a)
			else:
				todo.append(a)
		todo.sort_custom(func(a, b): return _ratio(a) > _ratio(b))
		var shown: Array = []
		if _filter != 1:
			shown.append_array(owned_list)
		if _filter != 2:
			shown.append_array(todo)
		if shown.is_empty():
			var first: Dictionary = todo[0] if not todo.is_empty() else {}
			empty("Aucun succès obtenu pour l'instant." + ((" Commence par « %s »." % first.name) if not first.is_empty() else ""))
			built()
			return
		var g := cards_grid()
		for a in shown:
			_achievement(g, a)
		built()

	static func _ratio(a: Dictionary) -> float:
		var p := Achievements.progress(a)
		return p.x / maxf(p.y, 1.0)

	## Titres obtenus (celui porté est coché) ; rien tant qu'aucun titre n'est gagné.
	func _titles_row() -> void:
		var titles := Achievements.titles()
		if titles.is_empty():
			return
		var row := HFlowContainer.new()
		row.add_theme_constant_override("h_separation", 8)
		row.add_theme_constant_override("v_separation", 6)
		_box.add_child(row)
		var l := Hud._label(row, "Titre porté :", 16, UiTheme.MUTED)
		l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		for t in titles:
			var tt: String = t
			var b := MenuWidgets.glass_button(tt, 15, Vector2(0, 36))
			b.toggle_mode = true
			b.button_pressed = tt == Profile.title
			b.pressed.connect(func():
				Profile.title = "" if Profile.title == tt else tt  # un second clic retire le titre
				Profile.save_profile()
				refresh())
			row.add_child(b)

	func _achievement(parent: Control, a: Dictionary) -> void:
		var own := Achievements.owned(a.id)
		var p := Achievements.progress(a)
		var v := card(parent)
		var top := HBoxContainer.new()
		top.add_theme_constant_override("separation", 8)
		v.add_child(top)
		Hud._label(top, "★" if own else "☆", 20, UiTheme.GOLD if own else UiTheme.MUTED)
		var name_l := Hud._label(top, String(a.name), 17, UiTheme.GOLD if own else UiTheme.TEXT)
		name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if String(a.title) != "":
			Hud._label(top, "titre « %s »" % a.title, 13, UiTheme.MUTED)
		var d := Hud._label(v, String(a.desc), 14, UiTheme.MUTED)
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		if own:
			Hud._label(v, "Obtenu le %s" % CarnetPages.date_fr(String(Profile.achievements[a.id])), 13, UiTheme.MUTED)
		else:
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 10)
			v.add_child(row)
			var pb := _progress(p.x, p.y, Vector2(0, 8))
			pb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(pb)
			Hud._label(row, "%s / %s" % [CarnetPages.num(p.x), CarnetPages.num(p.y)], 13, UiTheme.MUTED)


## Cartes : compteurs par rareté et prochaines cartes à débloquer ; la grille complète est dans Héros > Cartes.
class CardsPage extends ScrollPage:
	const NEXT_COUNT := 5

	func subtitle() -> String:
		return "Cartes de build débloquées"

	func refresh() -> void:
		clear()
		heading("Cartes", "%d / %d" % [Completion.cards_done(), Completion.cards_total()])
		var all := Boons.all()
		for r in ["common", "rare", "epic", "legendary"]:
			var of_r := all.filter(func(b): return String(b.get("rarity", "common")) == r)
			if of_r.is_empty():
				continue
			var got := of_r.filter(func(b): return Cards.card_unlocked(String(b.id))).size()
			var row: Dictionary = Boons.RARITY[r]
			bar(String(row.name), got, of_r.size())
		var locked := all.filter(func(b): return not Cards.card_unlocked(String(b.id)))
		locked.sort_custom(func(a, b): return _ratio(String(a.id)) > _ratio(String(b.id)))
		var sub := Hud._label(_box, "Prochaines à débloquer", 20, UiTheme.GOLD)
		sub.add_theme_font_override("font", UiTheme.bold_font())
		if locked.is_empty():
			Hud._label(_box, "✔ Toutes les cartes sont débloquées.", 16, GREEN)
		for b in locked.slice(0, NEXT_COUNT):
			var id := String(b.id)
			var v := card(_box)
			var top := HBoxContainer.new()
			v.add_child(top)
			var rar: Dictionary = Boons.RARITY.get(String(b.get("rarity", "common")), {"color": Color.WHITE})
			var nm := Hud._label(top, String(b.name), 17, rar.color)
			nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var p := Cards.unlock_progress(id)
			Hud._label(top, "%d / %d" % [int(p.x), int(p.y)], 14, UiTheme.MUTED)
			var d := Hud._label(v, Cards.unlock_text(id), 14, UiTheme.MUTED)
			d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var go := ItemWidgets.action_button(_box, "Voir toutes les cartes", func(): CarnetPages.open_hero(self, "cards"), 260, true)
		go.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN

	static func _ratio(id: String) -> float:
		var p := Cards.unlock_progress(id)
		return p.x / maxf(p.y, 1.0)


## Codex des trophées : les effets découverts d'abord.
class TrophiesPage extends ScrollPage:
	func subtitle() -> String:
		return "Effets de trophée découverts"

	func refresh() -> void:
		clear()
		heading("Trophées", "%d / %d" % [Profile.seen_trophies.size(), Trophies.KINDS.size()])
		var seen: Array = []
		for k in Trophies.KINDS:
			if k in Profile.seen_trophies:
				seen.append(k)
		if seen.is_empty():
			empty("Aucun trophée découvert. Ramasse-en en Survie pour remplir le codex.")
			return
		var g := cards_grid()
		for k in seen:
			var info: Dictionary = Trophies.KINDS[k]
			var v := card(g)
			Hud._label(v, String(info.get("name", k)), 17, UiTheme.GOLD)
			var d := Hud._label(v, _french_decimals(Trophies.describe(info)), 14, UiTheme.MUTED)
			d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var left := Trophies.KINDS.size() - seen.size()
		if left > 0:
			Hud._label(_box, "Encore %d effet%s à découvrir." % [left, "s" if left > 1 else ""], 15, UiTheme.MUTED)

	## « 1.5 s » -> « 1,5 s ».
	static func _french_decimals(t: String) -> String:
		var re := RegEx.new()
		re.compile("(\\d)\\.(\\d)")
		return re.sub(t, "$1,$2", true)
