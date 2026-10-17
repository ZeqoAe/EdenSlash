class_name SurvivorBilan
extends RefCounted
## Bilan v2 du Survivant (lot SVX-2 ; maquette conception/benchmark/survivant_maquettes/v2_bilan.svg) : ce que ResultsPanel
## ne sait pas dire, posé dans son corps juste sous les tuiles (ResultsScreen.show_results en Survivant) :
##   - « Qui a fait le travail » : les sources de dégâts de la partie (SurvivorLog), barre et total ; la part au survol ;
##   - « Ton équipement final » : les 9 cases (rareté, +N, éveil), panoplie, jets parfaits, sorts, évolutions ;
##   - « Ta partie minute par minute » (écran assez haut) : niveau du héros contre force des monstres, gardiens en points ;
##   - « Moments marquants » : pastilles horodatées (gardiens, évolution, jet parfait, panoplie complète, niveaux…) ;
##   - victoire : confettis des 5 bonbons. Le reste (titre, tuiles, coffres gardés, quête, boutons) reste ResultsPanel.
## Aucune donnée du compte : tout vient de la partie (mode scellé).

const ORDER := ["weapon", "head", "chest", "legs", "gloves", "boots", "back", "necklace", "ring"]


## Pose les blocs du bilan v2 dans le bilan [param r] (déjà construit par show_spec).
static func decorate(r: ResultsPanel) -> Control:
	var body: VBoxContainer = r._body
	if body == null:
		return null
	var vh := r.get_viewport().get_visible_rect().size.y if r.is_inside_tree() else 900.0
	var tall := vh >= 860.0
	var box := VBoxContainer.new()
	box.name = "SurvivorBilan"
	box.add_theme_constant_override("separation", 10)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var at := r._scroll.get_index() if r._scroll != null else body.get_child_count() - 1
	body.add_child(box)
	body.move_child(box, at)
	_records_and_chests(box, r)  # (lot SVX-3) « Nouveau record ! », défis, coffres qui s'ouvrent un à un, Codex
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(row)
	var left := _well(row, "Qui a fait le travail")
	_damage(left, 4 if not tall else 5)
	var right := _well(row, "Ton équipement final")
	_gear(right, tall)
	var director: Variant = r.get_parent().get("director") if r.get_parent() != null else null
	if tall and director != null and director.get("sv") != null and not (director.sv._minutes as Array).is_empty():
		var c := _well(box, "Ta partie minute par minute")
		c.get_parent().name = "Courbe"
		var chart := Chart.new()
		chart.rows = director.sv._minutes
		chart.guardians = director.sv.guardians
		chart.custom_minimum_size = Vector2(0, 86)
		c.add_child(chart)
	if not SurvivorLog.moments.is_empty():
		_moments(box, 6 if tall else 4)
	r._appear(box, 0.25)
	if r.is_inside_tree():
		_fit_bilan.call_deferred(r, box)  # (lot SVX-3) tient dans la fenêtre, même à 1280 × 720 avec records et coffres
	if Run.result == "victoire" and r.is_inside_tree():
		var tw := r.create_tween()
		tw.tween_interval(0.35)
		tw.tween_callback(func(): UiFeel.confetti(Vector2(r.get_viewport().get_visible_rect().size.x * 0.5, vh * 0.16), 24))
	return box


## Lot SVX-3 : une rangée « Nouveau record ! » (records battus, première victoire de la classe, défis accomplis, découvertes du
## Codex) et « Tes coffres » (les coffres d'apparence gagnés apparaissent l'un après l'autre ; « Ouvrir mes coffres » les
## ouvre un à un, 520 ms chacun : rayons, puis l'apparence gagnée). Rien si la partie n'a rien de tout ça. Ensuite le bilan se
## resserre s'il dépasse la fenêtre (_fit_bilan).
static func _records_and_chests(box: VBoxContainer, r: ResultsPanel) -> void:
	var last := SurvivorRewards.last
	var rec: Dictionary = last.get("records", {})
	var lines: Array = []
	for e in rec.get("records", []):
		lines.append("%s : %s  (avant %s)" % [String(e.text), SurvivorRecords.fmt(String(e.key), float(e.new)), SurvivorRecords.fmt(String(e.key), float(e.old))])
	if bool(rec.get("first_win", false)):
		lines.push_front("Première victoire avec cette classe  ·  %d / %d classes" % [int(rec.get("won", 1)), GameData.classes.size()])
	var defis: Array = rec.get("defis", [])
	var chests: Array = (last.get("chests", []) as Array).filter(func(g): return g.has("ref"))
	var news: Array = SurvivorCodex.last_new
	if lines.is_empty() and defis.is_empty() and chests.is_empty() and news.is_empty():
		return
	var row := HBoxContainer.new()
	row.name = "SurvivorRecords"
	row.add_theme_constant_override("separation", 14)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(row)
	var big := not (rec.get("records", []) as Array).is_empty()
	var v := _well(row, "Nouveau record !" if big else ("Première victoire !" if bool(rec.get("first_win", false)) else "Codex du Survivant"))
	v.get_child(0).add_theme_color_override("font_color", UiTheme.color("bonbon.soleil.base") if big else UiTheme.color("bonbon.soleil.clair"))
	for l in lines.slice(0, 3):
		_line(v, String(l), UiTheme.TEXT)
	if not defis.is_empty():
		var titled: Array = defis.filter(func(d): return String(d.title) != "")
		var dl := _line(v, ("Défi accompli : %s" % String(defis[0].text)) if defis.size() == 1 else "%d défis accomplis" % defis.size(), UiTheme.color("bonbon.pomme.clair"))
		if not titled.is_empty():
			dl.text += "  ·  titre « %s »" % String(titled[0].title)
		dl.tooltip_text = "\n".join(PackedStringArray(defis.map(func(d): return String(d.text) + ("  ·  titre « %s »" % String(d.title) if String(d.title) != "" else ""))))
		dl.mouse_filter = Control.MOUSE_FILTER_PASS
	if not news.is_empty():
		var parts: PackedStringArray = []
		for n in news.slice(0, 2):
			parts.append(String(n.text))
		var nl := _line(v, "Codex : " + "  ·  ".join(parts) + ("  ·  +%d" % (news.size() - 2) if news.size() > 2 else ""), UiTheme.color("bonbon.lagon.clair"))
		nl.name = "CodexLine"
		nl.tooltip_text = "\n".join(PackedStringArray(news.map(func(n): return String(n.text))))
		nl.mouse_filter = Control.MOUSE_FILTER_PASS
	if not chests.is_empty():
		var v2 := _well(row, "Tes coffres")
		var flow := HFlowContainer.new()
		flow.add_theme_constant_override("h_separation", 8)
		flow.add_theme_constant_override("v_separation", 6)
		flow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v2.add_child(flow)
		var chips: Array = []
		for g in chests:
			var c := ChestChip.new()
			c.chest = g.ref
			c.type = String(g.type)
			c.why = "%s · %s" % [String(g.text), "première fois" if String(g.get("kind", "")) == "first" else "une fois par jour"]
			flow.add_child(c)
			chips.append(c)
		var open := MenuWidgets.glass_button("Ouvrir mes coffres", 16, Vector2(0, 38))
		open.name = "OpenChests"
		open.tooltip_text = "Ils s'ouvrent l'un après l'autre ; sinon ils t'attendent dans le menu Coffres."
		open.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		flow.add_child(open)  # (à la suite des coffres : une rangée de moins)
		open.pressed.connect(_open_all.bind(r, chips, open))
		_reveal(r, chips)
		# la liste « Gardé » du bilan ne dit plus rien de neuf quand elle ne contient que ces coffres
		if r._scroll != null and (ResultsScreen.survivor_chest_rows(last) as Array).size() == chests.size():
			r._scroll.visible = false


## Le bilan dépasse la fenêtre (1280 × 720, partie riche) : il se resserre, dans l'ordre : moments marquants, ligne du Codex,
## lignes de record au-delà de deux, une source de dégâts de moins.
static func _fit_bilan(r: ResultsPanel, box: VBoxContainer) -> void:
	if not is_instance_valid(r) or not is_instance_valid(box) or r._panel == null:
		return
	r._fit()
	var vh := r.get_viewport().get_visible_rect().size.y - 24.0  # (marge du cadre papier)
	var steps: Array = [box.get_node_or_null("Courbe"), box.get_node_or_null("Moments"), box.find_child("CodexLine", true, false)]
	for s in steps:
		if r._panel.get_combined_minimum_size().y <= vh:
			return
		if s != null:
			(s as Control).visible = false
			r._fit()
	var rec := box.get_node_or_null("SurvivorRecords")
	# (lignes de record en trop : seulement si leur puits est le plus haut de la rangée)
	if rec != null and r._panel.get_combined_minimum_size().y > vh and (rec.get_child_count() < 2 or (rec.get_child(0) as Control).get_combined_minimum_size().y > (rec.get_child(1) as Control).get_combined_minimum_size().y):
		var col: Node = rec.get_child(0).get_child(0)
		for i in range(col.get_child_count() - 1, 2, -1):
			if r._panel.get_combined_minimum_size().y <= vh:
				break
			(col.get_child(i) as Control).visible = false
		r._fit()


## Les coffres gagnés apparaissent l'un après l'autre (fermés : leur rareté) ; « Réduire les animations » : tous d'un coup.
static func _reveal(r: ResultsPanel, chips: Array) -> void:
	if not r.is_inside_tree() or UiFeel.reduce_motion:
		return
	for c in chips:
		(c as ChestChip).modulate.a = 0.0
	var tw := r.create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_interval(0.6)
	for c in chips:
		tw.tween_property(c, "modulate:a", 1.0, 0.12)
		tw.tween_callback(UiFeel.pop_in.bind(c))
		tw.tween_interval(0.35)


## « Ouvrir mes coffres » : ils s'ouvrent l'un après l'autre (rayons 520 ms, puis l'apparence gagnée) ; un bilan quitté avant
## la fin laisse les autres fermés dans le menu Coffres (rien ne se perd).
static func _open_all(r: ResultsPanel, chips: Array, btn: Button) -> void:
	btn.disabled = true
	btn.text = "Coffres ouverts"
	if UiFeel.reduce_motion or not r.is_inside_tree():
		for c in chips:
			(c as ChestChip).open_now(false)
		return
	var tw := r.create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	for c in chips:
		tw.tween_callback((c as ChestChip).open_now.bind(true))
		tw.tween_interval(0.62)


## Puits d'encre titré (BIBLE § 2 : zones denses = puits d'encre) ; renvoie sa colonne.
static func _well(parent: Control, title: String) -> VBoxContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UiTheme.well_style(Vector2(14, 10), 14))
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 5)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(v)
	var t := Hud._label(v, title.to_upper(), 16, UiTheme.color("bonbon.soleil.clair"))
	t.add_theme_font_override("font", UiTheme.bold_font())
	return v


## Sources de dégâts de la partie : nom (genre), barre à la part, total ; la part et le genre au survol.
static func _damage(v: VBoxContainer, n: int) -> void:
	var rows := SurvivorLog.rows()
	if rows.is_empty():
		Hud._label(v, "Aucun dégât compté", UiTheme.MIN_TEXT, UiTheme.MUTED)
		return
	var top := float(rows[0].dmg)
	for r in rows.slice(0, n):
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 8)
		h.tooltip_text = "%s (%s) : %d %% des dégâts de la partie" % [String(r.name), String(r.kind), roundi(float(r.share) * 100.0)]
		h.mouse_filter = Control.MOUSE_FILTER_PASS
		v.add_child(h)
		var ic := TextureRect.new()
		ic.texture = UiTheme.texture(String(r.icon)) if String(r.icon) != "" else null
		ic.custom_minimum_size = Vector2(26, 26)
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_child(ic)
		var c := VBoxContainer.new()
		c.add_theme_constant_override("separation", 1)
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_child(c)
		var nm := Hud._label(c, String(r.name) if String(r.kind) == "effets" else "%s  ·  %s" % [String(r.name), String(r.kind)], 15, UiTheme.TEXT)
		nm.clip_text = true
		nm.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		nm.custom_minimum_size = Vector2(80, 0)
		var bar := SurvivorCardView.Bar.new()
		bar.ratio = float(r.dmg) / maxf(top, 1.0)
		bar.color = UiTheme.color("bonbon.amethyste.base") if String(r.kind) == "évolution" else (UiTheme.color("bonbon.mandarine.base") if String(r.kind) == "arme" else UiTheme.color("bonbon.lagon.base"))
		c.add_child(bar)
		var val := Hud._label(h, short_number(float(r.dmg)), 17, UiTheme.GOLD)
		val.add_theme_font_override("font", UiTheme.number_font())
		val.size_flags_vertical = Control.SIZE_SHRINK_CENTER


## « 1 240 », « 48 k », « 1,2 M » (dégâts de toute une partie).
static func short_number(x: float) -> String:
	if x >= 1.0e6:
		return ("%.1f M" % (x / 1.0e6)).replace(".", ",")
	if x >= 1.0e4:
		return "%d k" % roundi(x / 1000.0)
	return Items.fmt_num(roundi(x))


## Les 9 cases de l'équipement final et ses lignes (panoplie, jets parfaits, sorts, évolutions).
static func _gear(v: VBoxContainer, tall: bool) -> void:
	var g := Cases.new()
	g.custom_minimum_size = Vector2(9 * 44.0 + 8 * 6.0, 48)
	v.add_child(g)
	var b: Dictionary = SurvivorRewards.last.get("build", {})
	if b.is_empty():
		b = SurvivorRewards.build()
	var parts: PackedStringArray = []
	if int(b.get("set_n", 0)) >= 2:
		parts.append("◆ %s %d / 5%s" % [String(b.set), int(b.set_n), " accomplie" if int(b.set_n) >= 5 else ""])
	if int(b.get("perfect", 0)) > 0:
		parts.append("★ %d jet%s parfait%s" % [int(b.perfect), "s" if int(b.perfect) > 1 else "", "s" if int(b.perfect) > 1 else ""])
	if int(b.get("plus10", 0)) > 0:
		parts.append("%d pièce%s à +10" % [int(b.plus10), "s" if int(b.plus10) > 1 else ""])
	if not parts.is_empty():
		_line(v, "  ·  ".join(parts), UiTheme.color("bonbon.pomme.clair"))
	var spells: Array = b.get("spells", [])
	if not spells.is_empty():
		var names: PackedStringArray = []
		for s in spells.slice(0, 3):
			names.append("%s %d" % [String(s.name), int(s.rank)])
		_line(v, "Sorts : " + " · ".join(names) + ("  +%d autre%s" % [spells.size() - 3, "s" if spells.size() > 4 else ""] if spells.size() > 3 else ""), UiTheme.TEXT)
	var evos: Array = SurvivorEvo.taken().map(func(id): return String(Boons.get_def(String(id)).get("name", id)))
	if not evos.is_empty() or tall:
		_line(v, ("Évolution : %s" % ", ".join(PackedStringArray(evos)) if not evos.is_empty() else "Aucune évolution") + "  ·  passifs éveillés : %d" % int(b.get("awake", 0)), UiTheme.MUTED)


static func _line(v: Control, text: String, col: Color) -> Label:
	var l := Hud._label(v, text, UiTheme.MIN_TEXT + 1, col)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(120, 0)
	return l


## Moments marquants : pastilles « 5:37 · Gardien 1 vaincu en 0:37 », dans l'ordre de la partie.
static func _moments(box: VBoxContainer, n: int) -> void:
	var v := _well(box, "Moments marquants")
	v.get_parent().name = "Moments"
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 8)
	flow.add_theme_constant_override("v_separation", 6)
	flow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(flow)
	var list: Array = SurvivorLog.moments.duplicate()
	list.sort_custom(func(a, b): return float(a.t) < float(b.t))
	if list.size() > n:
		list = list.slice(list.size() - n)  # les plus récents (la fin de partie compte le plus)
	for m in list:
		var p := PanelContainer.new()
		var sb := UiTheme.sticker(_tone(String(m.kind)), {"shadow": 3, "radius": 11, "gloss": false, "cel_top": 0.0, "cel_bottom": 0.25, "pad": Vector2(10, 3)})
		p.add_theme_stylebox_override("panel", sb)
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
		flow.add_child(p)
		var l := Hud._label(p, "%s · %s" % [SurvivorDirector.clock(float(m.t)), String(m.text)], UiTheme.MIN_TEXT, Color.WHITE)
		l.add_theme_font_override("font", UiTheme.bold_font())
		l.add_theme_constant_override("outline_size", 4)
		l.add_theme_color_override("font_outline_color", UiTheme.color("encre.700"))


static func _tone(kind: String) -> String:
	match kind:
		"guardian":
			return "pomme"
		"evolution", "boss":
			return "amethyste"
		"perfect", "win":
			return "soleil"
		"set", "upgrade":
			return "mandarine"
	return "lagon"


## Un coffre d'apparence du bilan (lot SVX-3) : fermé (couleur du coffre), puis ouvert (rayons 520 ms, l'apparence gagnée).
## Ouvrir = Rewards.open (comme le menu Coffres : l'apparence rejoint la collection).
class ChestChip extends Control:
	var chest: Dictionary = {}
	var type := ""
	var why := ""
	var got := ""
	var _t := -1.0  # temps depuis l'ouverture (-1 : fermé)

	func _init() -> void:
		custom_minimum_size = Vector2(140, 52)
		mouse_filter = Control.MOUSE_FILTER_PASS
		process_mode = Node.PROCESS_MODE_ALWAYS

	func _ready() -> void:
		tooltip_text = "%s\n%s" % [String(Rewards.TYPES.get(type, {}).get("name", "Coffre")), why]

	## Ouvre le coffre (s'il est encore dans le menu Coffres) ; [param fx] : rayons, étincelles et son.
	func open_now(fx := true) -> void:
		if _t >= 0.0:
			return
		_t = 0.0 if fx else 1.0
		if Profile.reward_chests.has(chest):
			var res := Rewards.open(chest)
			var looks: Array = res.get("looks", [])
			got = String(looks[0].get("name", "")) if not looks.is_empty() else "Cristaux"
		else:
			got = "Ouvert"
		tooltip_text = "%s : %s" % [String(Rewards.TYPES.get(type, {}).get("name", "Coffre")), got]
		if fx and is_inside_tree():
			Sfx.ui("confirm")
			UiFeel.sparkle(get_global_rect().get_center(), 10, ["soleil", "fraise", "lagon"])
		queue_redraw()

	func _process(delta: float) -> void:
		if _t >= 0.0 and _t < 1.0:
			_t = minf(1.0, _t + delta / 0.52)
			queue_redraw()

	func _draw() -> void:
		var col: Color = Rewards.TYPES.get(type, {}).get("color", Color.WHITE)
		var r := Rect2(Vector2.ZERO, size)
		var ink := UiTheme.color("encre.900")
		var k := clampf(_t, 0.0, 1.0)
		var c := Vector2(23, size.y * 0.5)
		if _t >= 0.0 and k < 1.0:
			for i in 10:  # rayons (BIBLE § 7 : ouverture de coffre 520 ms)
				var a := TAU * i / 10.0 + k * 1.2
				draw_line(c, c + Vector2(cos(a), sin(a)) * (16.0 + 40.0 * k), Color(col.lightened(0.4), 1.0 - k), 4.0, true)
		SurvivorHud.round_rect(self, r, UiTheme.color("encre.700"), 12, 2, ink)
		var box := Rect2(c - Vector2(15, 13), Vector2(30, 27))
		SurvivorHud.round_rect(self, box, col.darkened(0.2) if _t < 0.0 else col, 7, 2, ink)
		if _t < 0.0:
			SurvivorHud.round_rect(self, Rect2(box.position, Vector2(30, 10)), col.lightened(0.25), 7, 2, ink)  # couvercle fermé
		else:
			SurvivorHud.round_rect(self, Rect2(box.position + Vector2(-2, -9 * k), Vector2(34, 9)), col.lightened(0.35), 5, 2, ink)
		var font := UiTheme.bold_font()
		var name := String(Rewards.TYPES.get(type, {}).get("name", "Coffre")).trim_prefix("Coffre d'apparence ").capitalize()
		var line1 := name if _t < 0.0 else got
		var line2 := "à ouvrir" if _t < 0.0 else name
		draw_string(font, Vector2(44, 23), line1, HORIZONTAL_ALIGNMENT_LEFT, size.x - 48, 15 if _t < 0.0 else 13, col.lightened(0.3) if _t >= 0.0 else UiTheme.TEXT)
		draw_string(UiTheme.label_font(), Vector2(44, 41), line2, HORIZONTAL_ALIGNMENT_LEFT, size.x - 48, 13, UiTheme.MUTED)


## Les 9 cases de l'équipement (arme + 8) : rareté, icône, +N, éveil en points soleil, jet parfait.
class Cases extends Control:
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var ink := UiTheme.color("encre.900")
		for i in SurvivorBilan.ORDER.size():
			var slot := String(SurvivorBilan.ORDER[i])
			var r := Rect2(i * 50.0, 2, 44, 44)
			var it: Dictionary = Profile.equipped.get(slot, {})
			if it.is_empty():
				SurvivorHud.round_rect(self, r, UiTheme.color("encre.700"), 10, 2, UiTheme.color("encre.300"))
				continue
			var col := Items.color_of(it)
			SurvivorHud.round_rect(self, r, col.darkened(0.15), 10, 2, ink)
			SurvivorHud.round_rect(self, Rect2(r.position + Vector2(2, 2), Vector2(40, 17)), col.lightened(0.15), 8)
			var tex := UiTheme.texture(String(it.get("icon", "")))
			if tex:
				draw_texture_rect(tex, r.grow(-4.0), false)
			var up := int(it.get("upgrade", 0))
			if up > 0:
				var pr := Rect2(r.position + Vector2(-2, -2), Vector2(24 if up >= 10 else 18, 15))
				SurvivorHud.round_rect(self, pr, ink, 5)
				draw_string(UiTheme.number_font(), pr.position + Vector2(3, 12), "+%d" % up, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, UiTheme.color("bonbon.soleil.base"))
			var awake := Survivor.WAKE_AT.filter(func(at): return up >= int(at)).size()
			for k in awake:
				var c := Vector2(r.position.x + 6.0 + k * 7.0, r.end.y - 5.0)
				draw_circle(c, 3.4, ink)
				draw_circle(c, 2.4, UiTheme.color("bonbon.soleil.base"))
			if SurvivorGear.is_perfect(it):
				SurvivorHud.ink_text(self, UiTheme.number_font(), "★", r.end.x - 7.0, r.position.y + 13.0, 12, UiTheme.color("bonbon.soleil.clair"), 3)


## Courbe minute par minute : niveau du héros (pomme, trait plein) contre force des monstres (fraise, pointillés : PV ×
## dégâts de la minute, ramenés à l'échelle du niveau), gardiens en points soleil.
class Chart extends Control:
	var rows: Array = []
	var guardians: Array = []

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_PASS
		tooltip_text = "Trait plein : ton niveau · pointillés : force des monstres · points : gardiens"

	func _draw() -> void:
		if rows.size() < 2:
			return
		var r := Rect2(4, 4, size.x - 8, size.y - 18)
		var max_m := float(rows[rows.size() - 1].m)
		var max_l := 1.0
		var max_f := 0.001
		for e in rows:
			max_l = maxf(max_l, float(e.level))
			max_f = maxf(max_f, float(e.get("hp_mult", 1.0)) * float(e.get("atk_mult", 1.0)))
		var lv := PackedVector2Array()
		var fo := PackedVector2Array()
		for e in rows:
			var x := r.position.x + r.size.x * float(e.m) / maxf(max_m, 1.0)
			lv.append(Vector2(x, r.end.y - r.size.y * float(e.level) / max_l))
			fo.append(Vector2(x, r.end.y - r.size.y * float(e.get("hp_mult", 1.0)) * float(e.get("atk_mult", 1.0)) / max_f))
		draw_line(Vector2(r.position.x, r.end.y), r.end, Color(UiTheme.color("encre.100"), 0.4), 1.0)
		for k in range(0, fo.size() - 1):
			if k % 2 == 0:
				draw_line(fo[k], fo[k + 1], UiTheme.color("bonbon.fraise.clair"), 2.0, true)
		draw_polyline(lv, UiTheme.color("bonbon.pomme.clair"), 3.0, true)
		for g in guardians:
			if float(g.ttk) < 0.0:
				continue
			var gx := r.position.x + r.size.x * (float(g.t) + float(g.ttk)) / 60.0 / maxf(max_m, 1.0)
			draw_circle(Vector2(gx, r.end.y), 5.0, UiTheme.color("encre.900"))
			draw_circle(Vector2(gx, r.end.y), 3.6, UiTheme.color("bonbon.soleil.base"))
		var font := UiTheme.label_font()
		draw_string(font, Vector2(r.position.x, size.y - 2), "0:00", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, UiTheme.color("encre.100"))
		draw_string(font, Vector2(r.end.x - 34, size.y - 2), "%d:00" % int(max_m), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, UiTheme.color("encre.100"))
		draw_string(font, Vector2(r.position.x + 60, size.y - 2), "— niveau %d" % int(max_l), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, UiTheme.color("bonbon.pomme.clair"))
		draw_string(font, Vector2(r.position.x + 170, size.y - 2), "- - force des monstres", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, UiTheme.color("bonbon.fraise.clair"))
