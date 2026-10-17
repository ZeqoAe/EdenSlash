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
		var chart := Chart.new()
		chart.rows = director.sv._minutes
		chart.guardians = director.sv.guardians
		chart.custom_minimum_size = Vector2(0, 86)
		c.add_child(chart)
	if not SurvivorLog.moments.is_empty():
		_moments(box, 6 if tall else 4)
	r._appear(box, 0.25)
	if Run.result == "victoire" and r.is_inside_tree():
		var tw := r.create_tween()
		tw.tween_interval(0.35)
		tw.tween_callback(func(): UiFeel.confetti(Vector2(r.get_viewport().get_visible_rect().size.x * 0.5, vh * 0.16), 24))
	return box


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
	var evos: Array = Run.passives.keys().filter(func(id): return not (Boons.get_def(String(id)).get("requires", []) as Array).is_empty()) \
		.map(func(id): return String(Boons.get_def(String(id)).get("name", id)))
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
