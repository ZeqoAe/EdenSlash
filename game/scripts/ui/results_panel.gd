class_name ResultsPanel
extends CanvasLayer
## Bilan de fin de partie, le même pour la Survie, le Duel, la Tour, les donjons (Donjon, Siège, Ruée)
## et le Battle royale : titre, une ligne, des tuiles de chiffres, trois blocs (Gagné, Gardé, Perdu) et
## les boutons d'après-partie. Un écran = un composant : on lui passe une description (Dictionary).
##
## [codeblock]
## ResultsPanel.new().show_spec({
##     "title": "VICTOIRE !", "tone": "win",              # win | lose | info
##     "subtitle": "Guerrier · Époque I",
##     "notes": ["Époque II débloquée !"],                # annonces dorées
##     "tiles": [["12", "niveau atteint"], ["3 / 8", "place", "infobulle", true]],   # [valeur, légende, infobulle, mis en avant]
##     "gained": [ResultsPanel.row("Maîtrise Guerrier", "+15", "", "expertise")],   # progression
##     "kept": [...], "lost": [...],                      # butin gardé ; ce qui reste dans la partie
##     "build": [...],                                    # (Survivant) le build final : mêmes lignes, bloc bleu
##     "footnote": "",
##     "stars": [{"label": "Le boss tombe", "done": true, "new": true, "tip": ""}],   # objectifs ★ / ☆ (lot DNG-1)
##     "loot": [ResultsPanel.loot_entry(objet)],          # butin montré en cases (pièce, niveau, rareté) ; "missing" : la ligne dessous
##     "defeat": HitLog.report(),                         # « Ce qui t'a battu » (coups des 8 dernières secondes, conseil) ; "defeat_note"
##     "buttons": [{"text": "Rejouer", "primary": true, "call": func(): ...}, {"text": "Retour au lobby", "call": ...}],
## })
## [/codeblock]
## Une ligne de bloc : [method row] (texte, valeur à droite, infobulle, icône). Un bloc vide n'est pas affiché.
## Les gains se révèlent en ~1,6 s : les nombres montent jusqu'à leur valeur et le plus gros gain (la valeur « +N »
## la plus haute) est entouré d'or, avec un éclat à l'arrivée. Une touche, un clic ou un bouton de manette montre
## tout de suite le résultat final ([method finish_now]).

const WIN := UiTheme.GOLD
const LOSE := Color(0.95, 0.42, 0.38)
const INFO := Color(0.55, 0.85, 1.0)
const GAINED := UiTheme.GOLD
const KEPT := Color(0.5, 0.95, 0.58)
const LOST := Color(1.0, 0.5, 0.45)
const WIDTH := 1040.0
const LOCK_SECS := 0.45  # les boutons n'agissent pas tout de suite : un appui de fin de combat ne doit rien valider
const BUILD := INFO
const COLUMNS := [["gained", "Gagné", GAINED], ["kept", "Gardé", KEPT], ["lost", "Perdu", LOST], ["build", "Ton build", BUILD]]
const ICON_MATERIALS := ["gold", "keys", "crystal"]
const COUNT_MIN := 10  # en dessous, un nombre apparaît tel quel (compter de 0 à 3 ne dit rien)
const COUNT_SECS := 0.8
const _COUNT_RE := "^([+\\-×x]?)(\\d{1,3}(?: \\d{3})+|\\d+)(.*)$"

var buttons: Array[Button] = []  # (tests) boutons de la rangée du bas, dans l'ordre de la description
var _scroll: ScrollContainer
var _body: VBoxContainer
var _counters: Array = []  # {label, prefix, n, suffix, grouped, delay, final} : les nombres qui montent
var _fades: Array = []  # blocs qui apparaissent (finish_now les montre d'un coup)
var _tweens: Array = []
var _best: Dictionary = {}  # la ligne mise en avant (la même instance que dans la description)
var _best_box: PanelContainer
var _quest_box: PanelContainer  # la ligne « Pour ta quête » (spec.quest)
var _panel: PanelContainer
var defeat_box: PanelContainer  # (tests) le bloc « Ce qui t'a battu »
var loot_box: Control  # (tests) le butin en cases
var _title: Label
var _orn: Control
var _footnote: Label
var _loot_row: Control
var _defeat_note: Label
## Hauteur minimale de la liste des blocs (elle défile en dessous) ; sous cette place, le bilan se resserre (_compact).
const MIN_LIST := 110.0
var _animating := false
var _col_index := 0  # colonne en cours de construction (décale la montée des nombres)


## Ligne d'un bloc : [param text] à gauche, [param value] en gras à droite, [param tip] au survol,
## [param icon] : nom d'icône du menu (MenuWidgets) ou matière (gold, keys, crystal).
static func row(text: String, value := "", tip := "", icon := "") -> Dictionary:
	return {"text": text, "value": value, "tip": tip, "icon": icon}


## Lignes « Coffre de forge · parchemins ×2 » d'une liste de coffres de récompense (ActivityLoot, Rewards) : un type et une
## spécialité par ligne, dans l'ordre du menu Coffres.
static func chest_rows(chests: Array) -> Array:
	var counts := {}
	for c in chests:
		var k := Rewards.kind_of(c)
		counts[k] = int(counts.get(k, 0)) + 1
	var kinds: Array = counts.keys()
	kinds.sort_custom(func(x, y): return Rewards.kind_rank(String(x)) < Rewards.kind_rank(String(y)))
	var out: Array = []
	for k in kinds:
		out.append(row(Rewards.kind_name(String(k)), "×%d" % int(counts[k]), Rewards.kind_blurb(String(k)), "chest"))
	return out


## Ligne d'une récompense dite en texte (« +90 insignes (place 3) ») : les insignes deviennent « Insignes +90 », le reste reste tel quel.
static func reward_row(text: String) -> Dictionary:
	var re := RegEx.new()
	re.compile("^\\+(\\d+) insignes?\\s*(?:\\((.*)\\))?$")
	var m := re.search(text)
	if m:
		var why := m.get_string(2)
		return row("Insignes", "+" + m.get_string(1), why.substr(0, 1).to_upper() + why.substr(1), "upgrade")
	return row(text, "", "", "chest")


## Nombre en groupes de trois chiffres (« 12 480 »).
static func number(v: float) -> String:
	return Hud._big_number(v)


## Tuile de chiffre : grande valeur dorée, légende dessous.
static func tile(parent: Control, value: String, caption: String, tip := "", highlight := false, min_w := 118.0) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UiTheme.flat_box(Color(0.07, 0.055, 0.13, 0.95), UiTheme.GOLD if highlight else UiTheme.GOLD_DIM, 2 if highlight else 1, 8))
	p.custom_minimum_size = Vector2(min_w, 0)
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if tip != "":
		p.tooltip_text = tip
	else:
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(v)
	var big := Hud._label(v, value, 26, Color(1.0, 0.9, 0.55) if highlight else UiTheme.GOLD)
	big.add_theme_font_override("font", UiTheme.bold_font())
	big.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var record := caption.contains("Record !")
	var cap := Hud._label(v, caption.replace(" · Record !", "").replace("Record !", "").strip_edges(), UiTheme.MIN_TEXT, UiTheme.MUTED)
	cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cap.clip_text = true
	if record:  # bilan v2 (lot DNG-2) : « Record ! » en pastille mandarine sur la tuile
		var pill := BossBar.pill("Record !", "mandarine", 13, 8.0)
		DungeonPage.overlay(p).add_child(pill)
		pill.anchor_left = 1.0
		pill.anchor_right = 1.0
		pill.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		pill.offset_left = 6.0
		pill.offset_right = 6.0
		pill.offset_top = -13.0
		p.set_meta("record", true)
	return p


func show_spec(spec: Dictionary) -> void:
	spec = HeroLevel.decorate(spec)  # niveau de héros gagné par la partie (lot H1), une fois
	layer = 30
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("results_panel")  # le HUD se retire derrière le bilan (Hud._menu_open)
	get_tree().paused = true
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	var art := backdrop_art(spec)  # lot ILL-2 : fond illustré selon le résultat, sous le voile
	if art != null:
		root.add_child(art)
	var dim := ColorRect.new()
	dim.color = Color(UiTheme.color("encre.700"), 0.62)  # voile de bilan : la partie se devine derrière (bible)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)
	if art != null:  # le voile garde sa couleur ; son opacité devient celle du fond illustré
		dim.modulate.a = minf(1.0, BACKDROP_VEIL / maxf(dim.color.a, 0.01))
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)
	var panel := PanelContainer.new()
	UiTheme.paper(panel, 7, Vector2(34, 22))  # feuille papier ; tuiles et colonnes restent des puits d'encre (UIK1)
	panel.custom_minimum_size = Vector2(WIDTH, 0)
	center.add_child(panel)
	_panel = panel
	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", 12)
	panel.add_child(_body)
	_best = best_row(spec)
	var tone: Color = {"win": WIN, "lose": LOSE, "info": INFO}.get(String(spec.get("tone", "info")), INFO)
	var t := Label.new()
	UiTheme.title(t, 50, tone)
	t.set_meta("ink_keep", true)  # « Victoire ! » contouré d'encre, même sur le papier
	t.text = String(spec.get("title", ""))
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_body.add_child(t)
	_title = t
	var orn := MenuWidgets.Ornament.new()
	orn.custom_minimum_size = Vector2(0, 18)
	_body.add_child(orn)
	_orn = orn
	if String(spec.get("subtitle", "")) != "":
		var s := Hud._label(_body, String(spec.subtitle), 22, UiTheme.TEXT)
		s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	for n in spec.get("notes", []):
		var nl := Hud._label(_body, String(n), 20, UiTheme.GOLD)
		nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		nl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var tiles: Array = spec.get("tiles", [])
	if not tiles.is_empty():
		var tr := HBoxContainer.new()
		tr.add_theme_constant_override("separation", 10)
		tr.alignment = BoxContainer.ALIGNMENT_CENTER
		_body.add_child(tr)
		for i in tiles.size():
			var d: Array = tiles[i]
			var tl := tile(tr, String(d[0]), String(d[1]), String(d[2]) if d.size() > 2 else "", d.size() > 3 and bool(d[3]), 118.0 if tiles.size() > 4 else 150.0)
			_appear(tl, 0.04 * i)
			_register_count((tl.get_child(0) as Control).get_child(0) as Label, String(d[0]), 0.15 + 0.07 * i)
	if not (spec.get("stars", []) as Array).is_empty():
		_add_stars(spec.stars)
	if not (spec.get("defeat", {}) as Dictionary).is_empty():
		_add_defeat(spec.defeat, String(spec.get("defeat_note", "")))
	if not (spec.get("loot", []) as Array).is_empty() or String(spec.get("missing", "")) != "":
		_add_loot(spec.get("loot", []), String(spec.get("missing", "")))
	_build_columns(spec)
	if String(spec.get("quest", "")) != "":
		_add_quest(String(spec.quest))
	if String(spec.get("footnote", "")) != "":
		var f := Hud._label(_body, String(spec.footnote), UiTheme.MIN_TEXT, UiTheme.MUTED)
		f.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		f.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		f.custom_minimum_size = Vector2(WIDTH - 90.0, 0)
		_footnote = f
	_build_buttons(spec.get("buttons", []))
	_fit.call_deferred()
	_start_animation()
	if String(spec.get("tone", "")) == "win":
		_celebrate.call_deferred()
	for m in moments(spec):
		if float(m[0]) <= 0.0:
			_moment(String(m[1]), float(m[2]))
		else:  # (minuteur lié au bilan : s'il est fermé avant, l'accent ne se joue pas)
			get_tree().create_timer(float(m[0]), true).timeout.connect(_moment.bind(String(m[1]), float(m[2])))


const MOMENT_FROM := 1.5  # (lot SND-2) premier accent, s après l'ouverture du bilan
const MOMENT_GAP := 1.0  # entre deux accents
const MOMENT_MAX := 3  # accents au plus


func _moment(sfx: String, db: float) -> void:
	UiFeel.cue(sfx, db)


## Sons du bilan (lot SND-2), [délai s, nom Sfx, dB] dans l'ordre : le résultat d'abord (victoire, ou défaite douce ; un
## bilan neutre se tait), puis au plus [constant MOMENT_MAX] accents, un à la fois, dans l'ordre record battu, étoile
## gagnée, butin (son de la plus haute rareté) et niveau de héros gagné. Les sons propres à un mode (coffres du Battle
## royale, de l'Échiquier) restent les leurs. Joués par UiFeel.cue : respectent l'intensité et le volume réglés.
static func moments(spec: Dictionary) -> Array:
	var out: Array = []
	var tone := String(spec.get("tone", "info"))
	if tone == "win":
		out.append([0.0, "ui_victory", -6.0])
	elif tone == "lose":
		out.append([0.0, "ui_defeat", -8.0])
	var accents: Array = []
	if has_record(spec):
		accents.append(["ui_record", -8.0])
	if has_new_star(spec):
		accents.append(["ui_star", -8.0])
	var loot: Array = spec.get("loot", [])
	if not loot.is_empty():
		var best := 0
		for e in loot:
			best = maxi(best, int((e as Dictionary).get("rarity", 0)))
		accents.append([Sfx.reward(best), -9.0])
	for n in spec.get("notes", []):
		if String(n).begins_with("Ton héros passe au niveau"):
			accents.append(["ui_level_up", -9.0])
			break
	for i in mini(accents.size(), MOMENT_MAX):
		out.append([MOMENT_FROM + MOMENT_GAP * i, accents[i][0], accents[i][1]])
	return out


## Un record battu : tuile « … · Record ! », note « Record ! … » ou ligne « Nouveau record ».
static func has_record(spec: Dictionary) -> bool:
	for t in spec.get("tiles", []):
		if t is Array and (t as Array).size() > 1 and String(t[1]).contains("Record !"):
			return true
	for n in spec.get("notes", []):
		if String(n).begins_with("Record"):
			return true
	for r in spec.get("gained", []):
		if r is Dictionary and String((r as Dictionary).get("text", "")).to_lower().contains("record"):
			return true
	return false


## Une étoile gagnée : objectif ★ marqué « nouvelle » ou ligne « Étoile … ».
static func has_new_star(spec: Dictionary) -> bool:
	for s in spec.get("stars", []):
		if s is Dictionary and bool((s as Dictionary).get("new", false)):
			return true
	for r in spec.get("gained", []):
		if r is Dictionary and String((r as Dictionary).get("text", "")).begins_with("Étoile"):
			return true
	return false


## Victoire : confettis des bonbons depuis le titre (UiFeel : 24 au plus, coupés avec « Réduire les animations ») ; un
## bilan qui a ses propres confettis (Battle royale : variable « confetti ») garde les siens.
func _celebrate() -> void:
	if get("confetti") is Array:
		return
	await get_tree().process_frame
	if is_instance_valid(_title) and _title.is_inside_tree():
		UiFeel.confetti(_title.get_global_transform_with_canvas() * (_title.size * 0.5))


## Les trois blocs côte à côte (un bloc sans ligne n'existe pas).
func _build_columns(spec: Dictionary) -> void:
	var cols: Array = []
	for c in COLUMNS:
		var rows: Array = spec.get(String(c[0]), [])
		if not rows.is_empty():
			cols.append([c, rows])
	if cols.is_empty():
		return
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_child(_scroll)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 14)
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(h)
	for i in cols.size():
		_col_index = i
		var c: Array = cols[i][0]
		var card := PanelContainer.new()
		var accent: Color = c[2]
		card.add_theme_stylebox_override("panel", UiTheme.flat_box(Color(0.05, 0.045, 0.1, 0.92), Color(accent, 0.55), 1, 10, false))
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.custom_minimum_size = Vector2(250 if cols.size() > 1 else 460, 0)
		if cols.size() == 1:
			card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		h.add_child(card)
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 6)
		card.add_child(v)
		var head := Hud._label(v, String(c[1]).to_upper(), 17, accent)
		head.add_theme_font_override("font", UiTheme.bold_font())
		var bar := ColorRect.new()
		bar.color = Color(accent, 0.8)
		bar.custom_minimum_size = Vector2(0, 2)
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(bar)
		for r in cols[i][1]:
			_add_row(v, r, accent)
		_appear(card, 0.2 + 0.12 * i)


func _add_row(parent: Control, r, accent: Color) -> void:
	var d: Dictionary = r if r is Dictionary else row(String(r))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	if String(d.get("tip", "")) != "":
		h.tooltip_text = String(d.tip)
		h.mouse_filter = Control.MOUSE_FILTER_PASS
	else:
		h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var is_best := not _best.is_empty() and is_same(d, _best)
	if is_best:  # le plus gros gain : sur un fond doré, valeur plus grande
		_best_box = PanelContainer.new()
		var sb := UiTheme.flat_box(Color(accent, 0.16), Color(accent, 0.9), 1, 6, false)
		sb.content_margin_top = 3
		sb.content_margin_bottom = 3
		_best_box.add_theme_stylebox_override("panel", sb)
		_best_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		parent.add_child(_best_box)
		_best_box.add_child(h)
	else:
		parent.add_child(h)
	var ic_name := String(d.get("icon", ""))
	if ic_name != "":
		var ic := TextureRect.new()
		ic.texture = UiTheme.texture(Items.material_icon(ic_name)) if ic_name in ICON_MATERIALS else MenuWidgets.icon(ic_name)
		ic.modulate = Color.WHITE if ic_name in ICON_MATERIALS else MenuWidgets.ICON_TINT
		ic.custom_minimum_size = Vector2(22, 22)
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ic.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_child(ic)
	var l := Hud._label(h, String(d.get("text", "")), 16, UiTheme.TEXT)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(110, 0)
	if String(d.get("value", "")) != "":
		var vl := Hud._label(h, String(d.value), 20 if is_best else 17, accent.lightened(0.35 if is_best else 0.15))
		vl.add_theme_font_override("font", UiTheme.bold_font())
		vl.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		_register_count(vl, String(d.value), 0.5 + 0.12 * _col_index, true)


func _build_buttons(list: Array) -> void:
	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 16)
	_body.add_child(btn_row)
	var locked: Array[Button] = []
	for d in list:
		var primary := bool(d.get("primary", false))
		var b := MenuWidgets.gold_button(String(d.text), 24, Vector2(330, 62)) if primary else MenuWidgets.paper_button(String(d.text), 22, Vector2(300, 62))
		b.add_theme_stylebox_override("disabled", UiTheme.flat_box(Color(0.1, 0.09, 0.16, 0.8), Color(0.3, 0.28, 0.4), 1, 14 if primary else 12, false))
		b.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.35))
		var cb: Callable = d.get("call", Callable())
		b.pressed.connect(func():
			if cb.is_valid():
				cb.call())
		btn_row.add_child(b)
		buttons.append(b)
		if bool(d.get("disabled", false)):
			b.disabled = true
		else:
			b.disabled = true
			locked.append(b)
	# anti-appui : un bouton enfoncé en pleine fin de combat ne doit rien valider
	get_tree().create_timer(LOCK_SECS, true, false, true).timeout.connect(func():
		for b in locked:
			if is_instance_valid(b):
				b.disabled = false)


## Les blocs défilent si l'écran est trop petit (liste de gains très longue) ; sinon ils prennent leur hauteur.
## Ligne « Pour ta quête » : ce que ce gain change pour l'équipement des classes, et la suite (Compass.after).
func _add_quest(text: String) -> void:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UiTheme.flat_box(Color(0.1, 0.08, 0.04, 0.9), Color(UiTheme.GOLD, 0.7), 1, 10, false))
	p.custom_minimum_size = Vector2(WIDTH - 90.0, 0)
	p.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	p.add_child(h)
	var ic := TextureRect.new()
	ic.texture = MenuWidgets.icon("pin")
	ic.modulate = UiTheme.GOLD
	ic.custom_minimum_size = Vector2(22, 22)
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(ic)
	var tag := Hud._label(h, "Ta quête", 15, UiTheme.GOLD)
	tag.add_theme_font_override("font", UiTheme.bold_font())
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := Hud._label(h, text, 16, UiTheme.TEXT)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if Quests.enabled():  # lot HUB-1, P0-5 : le Journal s'ouvre aussi depuis le bilan (bouton ou sa touche)
		var jb := MenuWidgets.glass_button("Journal (%s)" % Settings.action_label("journal", 1), 15, Vector2(0, 34))
		jb.tooltip_text = "Tes quêtes : ce qui a avancé, la série, ce qui reste aujourd'hui"
		jb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		jb.pressed.connect(open_journal)
		h.add_child(jb)
	_body.add_child(p)
	_quest_box = p
	_appear(p, 0.8)


func _fit() -> void:
	# la liste prend la place qui reste (mesurée : titre, tuiles, blocs du lot DNG-1, quête, boutons) : une fenêtre de 720 px
	# la raccourcit (elle défile) ; s'il ne reste pas MIN_LIST, le bilan se resserre d'abord (_compact)
	var vh := get_viewport().get_visible_rect().size.y
	if _scroll != null:
		_scroll.custom_minimum_size.y = 0.0
	for step in 5:
		if vh - _other_height() - 36.0 >= (MIN_LIST if _scroll != null else 0.0):
			break
		_compact(step)
	if _scroll == null:
		return
	var inner := _scroll.get_child(0) as Control
	var room := clampf(vh - _other_height() - 36.0, MIN_LIST, 400.0)
	_scroll.custom_minimum_size.y = minf(inner.get_combined_minimum_size().y, room)


func _other_height() -> float:
	return _panel.get_combined_minimum_size().y if _panel != null else 450.0


## Le bilan se resserre, étape [param step] (fenêtre basse, bilan riche) : titre plus petit et sans ornement, sans note de
## bas de page, sans les cases du butin (il est aussi dans « Gardé »), sans la note de meilleur pourcentage, notes réduites à une.
func _compact(step: int) -> void:
	match step:
		0:
			_body.add_theme_constant_override("separation", 6)
			if _orn != null:
				_orn.visible = false
			if _title != null:
				_title.add_theme_font_size_override("font_size", 36)
		1:
			if _footnote != null:
				_footnote.visible = false
		2:
			if _loot_row != null:
				_loot_row.visible = false
		3:
			if _defeat_note != null:
				_defeat_note.visible = false
		4:
			var seen := 0
			for c in _body.get_children():
				if c is Label and c != _title and c != _footnote and (c as Label).get_theme_color("font_color") == UiTheme.GOLD:
					seen += 1
					if seen > 1:
						c.visible = false


# --- blocs du lot DNG-1 : objectifs, butin en cases, « Ce qui t'a battu » ---------------------
## Case de butin d'un vrai objet (pièce, niveau, rareté ; l'infobulle le décrit).
static func loot_entry(item: Dictionary) -> Dictionary:
	var slot := String(item.get("slot", ""))
	return {"name": Items.display_name(item), "sub": "%s · Nv %d" % [String(Items.SLOT_NAMES.get(slot, slot)), int(item.get("level", 1))],
		"rarity": int(item.get("rarity", 0)), "tip": Items.describe(item, false) if item.has("base") else "", "item": item}


func _add_stars(list: Array) -> void:
	# bilan v2 (lot DNG-2) : un autocollant par objectif, soleil s'il est tenu, gris tramé sinon ; « nouvelle » en mandarine
	var h := HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_theme_constant_override("separation", 14)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_body.add_child(h)
	for s in list:
		var done := bool(s.get("done", false))
		var p := PanelContainer.new()
		p.add_theme_stylebox_override("panel", UiTheme.sticker("soleil" if done else "gris_nuit", {"radius": 14, "shadow": 4, "pad": Vector2(14, 4),
			"gloss": done, "trame": not done}))
		p.mouse_filter = Control.MOUSE_FILTER_PASS if String(s.get("tip", "")) != "" else Control.MOUSE_FILTER_IGNORE
		p.tooltip_text = String(s.get("tip", ""))
		h.add_child(p)
		var l := Label.new()
		l.text = "%s %s" % ["★" if done else "☆", String(s.get("label", ""))]
		l.add_theme_font_override("font", UiTheme.bold_font())
		l.add_theme_font_size_override("font_size", 17)
		l.add_theme_color_override("font_color", Color.WHITE if done else UiTheme.MUTED)
		l.add_theme_constant_override("outline_size", 4 if done else 0)
		l.add_theme_color_override("font_outline_color", UiTheme.color("encre.700"))
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		p.add_child(l)
		if bool(s.get("new", false)):
			var tag := BossBar.pill("nouvelle", "mandarine", 12, 8.0)
			tag.position = Vector2(-8, -16)
			DungeonPage.overlay(p).add_child(tag)
	_appear(h, 0.1)


## Ton de bonbon d'une rareté (bible § 3 : lilas-gris, pomme, lagon, améthyste, mandarine, soleil).
static func rarity_tone(r: int) -> String:
	return ["gris", "pomme", "lagon", "amethyste", "mandarine", "soleil"][clampi(r, 0, 5)]


func _add_loot(list: Array, missing: String) -> void:
	# bilan v2 (lot DNG-2) : le butin en cases autocollantes de la couleur de la rareté (icône du jeu si l'objet en a une),
	# nom et détail dessous ; la pièce qui manque encore en pomme
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_body.add_child(v)
	loot_box = v
	if not list.is_empty():
		var h := HBoxContainer.new()
		h.alignment = BoxContainer.ALIGNMENT_CENTER
		h.add_theme_constant_override("separation", 12)
		h.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(h)
		_loot_row = h
		var shown := list.slice(0, 5)
		for e in shown:
			var r := int(e.get("rarity", 0))
			var card := HBoxContainer.new()
			card.add_theme_constant_override("separation", 8)
			card.mouse_filter = Control.MOUSE_FILTER_PASS if String(e.get("tip", "")) != "" else Control.MOUSE_FILTER_IGNORE
			card.tooltip_text = String(e.get("tip", ""))
			h.add_child(card)
			var it: Dictionary = e.get("item", {})
			var tex: Texture2D = UiTheme.texture(String(it.get("icon", ""))) if not it.is_empty() else null
			if tex == null:
				tex = ResourceHelp.icon("plan") if String(e.get("name", "")).begins_with("Plan") else MenuWidgets.icon("chest")
			var cell := DungeonPage.cell(tex, "", rarity_tone(r), false, 56)
			cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
			cell.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			card.add_child(cell)
			var c := VBoxContainer.new()
			c.add_theme_constant_override("separation", 0)
			c.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			c.mouse_filter = Control.MOUSE_FILTER_IGNORE
			card.add_child(c)
			var col: Color = Items.RARITIES[clampi(r, 0, Items.RARITIES.size() - 1)].color
			var n := Hud._label(c, String(e.get("name", "")), 15, col.lightened(0.15))
			n.add_theme_font_override("font", UiTheme.bold_font())
			n.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			n.custom_minimum_size = Vector2(118, 0)
			var sub := Hud._label(c, String(e.get("sub", "")), UiTheme.MIN_TEXT, UiTheme.MUTED)
			sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			sub.custom_minimum_size = Vector2(118, 0)
		if list.size() > shown.size():
			Hud._label(h, "+%d" % (list.size() - shown.size()), 20, UiTheme.MUTED).size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if missing != "":
		var mp := PanelContainer.new()
		mp.add_theme_stylebox_override("panel", UiTheme.sticker("pomme", {"radius": 12, "shadow": 3, "pad": Vector2(14, 3), "gloss": false}))
		mp.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		mp.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(mp)
		var m := Label.new()
		m.text = missing
		m.add_theme_font_override("font", UiTheme.bold_font())
		m.add_theme_font_size_override("font_size", 15)
		m.add_theme_color_override("font_color", Color.WHITE)
		m.add_theme_constant_override("outline_size", 4)
		m.add_theme_color_override("font_outline_color", UiTheme.color("encre.700"))
		m.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		if missing.length() > 80:
			m.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			m.custom_minimum_size = Vector2(minf(WIDTH - 120.0, 760.0), 0)
		m.mouse_filter = Control.MOUSE_FILTER_IGNORE
		mp.add_child(m)
	_appear(v, 0.15)


## « Ce qui t'a battu » : les coups des dernières secondes (HitLog.report), la mécanique fautive et son conseil.
## Bilan v2 (lot DNG-2) : puits d'encre au bord fraise, titre fraise, une pastille de mécanique par ligne, conseil en soleil.
func _add_defeat(rep: Dictionary, note: String) -> void:
	var p := PanelContainer.new()
	var sb := UiTheme.well_style(Vector2(16, 10), 14)
	sb.border_color = UiTheme.color("bonbon.fraise.base")
	sb.set_border_width_all(3)
	p.add_theme_stylebox_override("panel", sb)
	p.custom_minimum_size = Vector2(WIDTH - 90.0, 0)
	p.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_body.add_child(p)
	defeat_box = p
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(v)
	var head := HBoxContainer.new()
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(head)
	var t := Label.new()
	UiTheme.title(t, 20, UiTheme.color("bonbon.fraise.base"))
	t.text = "Ce qui t'a battu"
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(t)
	var hits := int(rep.get("hits", 0))
	Hud._label(head, "les %d dernières secondes · %d coup%s" % [roundi(float(rep.get("window", HitLog.WINDOW))), hits, "s" if hits > 1 else ""],
		UiTheme.MIN_TEXT, UiTheme.MUTED).size_flags_vertical = Control.SIZE_SHRINK_CENTER
	for l in defeat_lines(rep):
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 8)
		h.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(h)
		var ch := BossBar.chip(String(l.get("brick", "")) if String(l.get("brick", "")) != "" else "melee", 26)
		ch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(ch)
		var a := Hud._label(h, String(l.text), 16, UiTheme.TEXT)
		a.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		a.clip_text = true
		var b := Hud._label(h, String(l.value), 17, UiTheme.color("bonbon.fraise.clair"))
		b.add_theme_font_override("font", UiTheme.bold_font())
	if String(rep.get("tip", "")) != "":
		var tip := Hud._label(v, String(rep.tip), 16, UiTheme.GOLD)
		tip.add_theme_font_override("font", UiTheme.bold_font())
		tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		tip.custom_minimum_size = Vector2(WIDTH - 130.0, 0)
	if note != "":
		_defeat_note = Hud._label(v, note, UiTheme.MIN_TEXT, UiTheme.MUTED)
	_appear(p, 0.1)


## Lignes du bloc « Ce qui t'a battu » : {text (« Pluie de météores · Latif »), value (« −48 % PV · coup final »), brick}.
static func defeat_lines(rep: Dictionary) -> Array:
	var out: Array = []
	for l in rep.get("lines", []):
		var mech := String(l.get("mech", ""))
		var text := ("%s · %s" % [mech, String(l.name)]) if mech != "" else String(l.name)
		if int(l.get("count", 1)) > 1:
			text += " (×%d)" % int(l.count)
		out.append({"text": text, "value": "−%s PV%s" % [HitLog.pct(float(l.share)), " · coup final" if bool(l.get("final", false)) else ""],
			"brick": String(l.get("brick", ""))})
	return out


func _appear(c: Control, delay: float) -> void:
	c.modulate.a = 0.0
	_fades.append(c)
	var tw := c.create_tween()
	tw.tween_interval(delay)
	tw.tween_property(c, "modulate:a", 1.0, 0.25)
	_tweens.append(tw)


# --- animation des gains ---------------------------------------------------------------------
## Le plus gros gain : la ligne « +N » la plus haute du bloc Gardé (le butin qu'on emporte : insignes, cristaux), à défaut
## du bloc Gagné (la progression). Il faut au moins deux gains chiffrés pour qu'une mise en avant ait un sens.
static func best_row(spec: Dictionary) -> Dictionary:
	var best := {}
	var counted := 0
	for k in ["kept", "gained"]:  # le butin emporté passe avant la progression : on ne compare pas des maîtrises à des insignes
		var best_n := -1
		var best_in := {}
		for r in spec.get(k, []):
			if not r is Dictionary:
				continue
			var p := _parse_count(String((r as Dictionary).get("value", "")))
			if p.is_empty() or p.prefix != "+":
				continue
			counted += 1
			if int(p.n) > best_n:
				best_n = int(p.n)
				best_in = r
		if best.is_empty():
			best = best_in
	return best if counted >= 2 else {}


## « +1 250 » -> {prefix "+", n 1250, suffix "", grouped true} ; « 05:23 », « 1,5 » ou un texte -> {} (pas de compteur).
static func _parse_count(text: String, min_n := 0) -> Dictionary:
	var m := RegEx.create_from_string(_COUNT_RE).search(text)
	if m == null:
		return {}
	var suffix := m.get_string(3)
	if suffix != "" and not suffix[0] in [" ", "%", "×"]:
		return {}
	var digits := m.get_string(2)
	var n := int(digits.replace(" ", ""))
	if n < min_n:
		return {}
	return {"prefix": m.get_string(1), "n": n, "suffix": suffix, "grouped": digits.contains(" ")}


static func _count_text(c: Dictionary, t: float) -> String:
	var v := roundi(float(c.n) * t)
	return "%s%s%s" % [c.prefix, number(v) if c.grouped else str(v), c.suffix]


## Fait monter le nombre affiché par [param label] jusqu'à [param text] (s'il s'y prête) : la largeur est celle du
## résultat final, pour que rien ne bouge pendant la montée.
func _register_count(label: Label, text: String, delay: float, right := false) -> void:
	var c := _parse_count(text, COUNT_MIN)
	if c.is_empty():
		return
	var font := label.get_theme_font("font")
	var fs := label.get_theme_font_size("font_size")
	label.custom_minimum_size.x = maxf(label.custom_minimum_size.x, font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 2.0)
	if right:
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	c["label"] = label
	c["delay"] = delay
	c["final"] = text
	_counters.append(c)
	label.text = _count_text(c, 0.0)


func _start_animation() -> void:
	if _counters.is_empty():
		return
	_animating = true
	var total := 0.0
	for c in _counters:
		total = maxf(total, float(c.delay) + COUNT_SECS)
		var tw := create_tween()
		tw.tween_interval(float(c.delay))
		var step := func(t: float):
			if is_instance_valid(c.label):
				c.label.text = _count_text(c, t)
		tw.tween_method(step, 0.0, 1.0, COUNT_SECS).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		_tweens.append(tw)
	var end := create_tween()
	end.tween_interval(total + 0.05)
	end.tween_callback(func():
		_animating = false
		_flash_best(true))
	_tweens.append(end)


## Montre le résultat final tout de suite (touche, clic ou bouton de manette pendant la montée).
func finish_now() -> void:
	if not _animating:
		return
	_animating = false
	for tw in _tweens:
		if tw is Tween and (tw as Tween).is_valid():
			(tw as Tween).kill()
	_tweens.clear()
	for c in _counters:
		if is_instance_valid(c.label):
			c.label.text = String(c.final)
	for f in _fades:
		if is_instance_valid(f):
			(f as Control).modulate.a = 1.0
	_flash_best(false)


## Éclat doré sur le plus gros gain, une fois que tout est arrivé (silencieux si on a passé l'animation).
func _flash_best(with_sound: bool) -> void:
	if _best_box == null or not is_instance_valid(_best_box):
		return
	if with_sound:
		Sfx.ui("confirm", -9.0)
	_best_box.self_modulate = Color(2.2, 1.9, 1.2)
	var tw := _best_box.create_tween()
	tw.tween_property(_best_box, "self_modulate", Color.WHITE, 0.6)


## Le Journal des quêtes par-dessus le bilan (lot HUB-1) : sans « Y aller » (le bilan garde la main).
func open_journal() -> QuestJournal:
	return QuestJournal.open_on(self, 0)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("journal") and Quests.enabled() and QuestJournal.find_open(self) == null:
		get_viewport().set_input_as_handled()
		open_journal()
		return
	if _animating and event.is_pressed() and not event.is_echo() \
			and (event is InputEventKey or event is InputEventMouseButton or event is InputEventJoypadButton):
		finish_now()  # sans consommer l'événement : un bouton dégelé garde son clic

## Fonds illustrés du bilan (lot ILL-2) : un par résultat, 1600 × 900, sous un voile ([constant BACKDROP_VEIL]) ; le panneau
## reste opaque, le fond se voit autour. Nom : [code]spec.bg[/code] s'il est donné, sinon [method backdrop_key].
const BACKDROP := "res://assets/ui/backdrops/fin_%s.jpg"
const BACKDROP_KEYS := ["victoire", "defaite", "record", "boss", "egalite", "etoiles"]
const BACKDROP_VEIL := 0.45


## Fond du bilan : défaite (ton « lose »), égalité (ton neutre : extraction), sinon pour une victoire une étoile d'époque gagnée,
## un record battu (ligne « Nouveau record » ou note « Record ! »), un boss tombé avec son butin en cases, ou la victoire simple.
static func backdrop_key(spec: Dictionary) -> String:
	var bg := String(spec.get("bg", ""))
	if bg in BACKDROP_KEYS:
		return bg
	var tone := String(spec.get("tone", "info"))
	if tone == "lose":
		return "defaite"
	if tone != "win":
		return "egalite"
	for s in spec.get("stars", []):
		if s is Dictionary and bool((s as Dictionary).get("new", false)):
			return "etoiles"
	for r in spec.get("gained", []):
		if r is Dictionary and String((r as Dictionary).get("text", "")).begins_with("Étoile"):
			return "etoiles"
	for n in spec.get("notes", []):
		if String(n).begins_with("Record"):
			return "record"
	for r in spec.get("gained", []):
		if r is Dictionary and String((r as Dictionary).get("text", "")).to_lower().contains("record"):
			return "record"
	if not (spec.get("loot", []) as Array).is_empty():
		return "boss"
	return "victoire"


## Le fond du bilan, plein cadre (recadré), qui apparaît en fondu ; null si l'image manque.
static func backdrop_art(spec: Dictionary) -> TextureRect:
	var path := BACKDROP % backdrop_key(spec)
	if not ResourceLoader.exists(path):
		return null
	var img := TextureRect.new()
	img.name = "Backdrop"
	img.texture = load(path)
	img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	img.set_anchors_preset(Control.PRESET_FULL_RECT)
	img.mouse_filter = Control.MOUSE_FILTER_IGNORE
	img.modulate.a = 0.0
	img.ready.connect(func():
		img.create_tween().tween_property(img, "modulate:a", 1.0, 0.6))
	return img
