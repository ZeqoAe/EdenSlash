class_name SurvivorCodexPage
extends PageScreen
## Codex du Survivant (lot SVX-3, BM-SURV SV-M1, SV-M2, SV-M3, SV-Q5) : la collection propre au mode, ouverte depuis sa page
## au menu Jouer (« Codex du Survivant ») ; rien n'y touche le compte. Onglets : Évolutions (prises, recettes connues, « ? »),
## Armes (types × variantes d'auto-attaque), Panoplies, Bestiaire, Records (par palier pour la classe choisie, classes
## gagnées x / 60), Défis et statistiques. Données : SurvivorCodex, SurvivorRecords.
## [codeblock]
## SurvivorCodexPage.open_on(hôte, onglet)
## [/codeblock]

const LAYER := 32
const TABS := [["evo", "Évolutions"], ["weapons", "Armes"], ["sets", "Panoplies"], ["monsters", "Bestiaire"],
	["records", "Records"], ["defis", "Défis"], ["spells", "Sorts"]]  # (lot SVX-4 : « Sorts » ajouté en fin, fiches d'arme et de sort)


func _init() -> void:
	super("Codex", LAYER)


func _ready() -> void:
	super._ready()
	for t in TABS:
		var p := CodexTab.new()
		p.kind = String(t[0])
		add_page(String(t[1]), p)
	var pr := SurvivorCodex.progress()
	set_title("Codex", "Survivant · évolutions %d / %d · armes %d / %d · panoplies %d / %d · monstres %d / %d" % [
		pr.evo[0], pr.evo[1], pr.weapons[0], pr.weapons[1], pr.sets[0], pr.sets[1], pr.monsters[0], pr.monsters[1]])


## Ouvre le Codex sur [param host] (le même s'il y est déjà) à l'onglet [param tab].
static func open_on(host: Node, tab := 0) -> SurvivorCodexPage:
	var c: SurvivorCodexPage = null
	for n in host.get_children():
		if n is SurvivorCodexPage:
			c = n
	if c == null:
		c = SurvivorCodexPage.new()
		host.add_child(c)
	c.open(tab)
	return c


## Part du Codex remplie (0 à 1), pour le bouton de la page du mode.
static func completion() -> float:
	var pr := SurvivorCodex.progress()
	var n := 0.0
	var d := 0.0
	for k in pr:
		n += float(pr[k][0])
		d += float(pr[k][1])
	return n / maxf(d, 1.0)


## Carte de la page du mode (lobby, sous les coffres) : records au palier choisi pour la classe choisie, classes gagnées,
## défis, bouton du Codex. [param host] : le nœud qui recevra le Codex (le lobby).
static func lobby_card(sub: Control, tier: int, host: Node) -> void:
	var head := Hud._label(sub, "Records et Codex", 15, UiTheme.GOLD)
	head.add_theme_font_override("font", UiTheme.bold_font())
	head.mouse_filter = Control.MOUSE_FILTER_STOP
	head.tooltip_text = "Propres au Survivant : records par classe et par palier, défis, collection du mode."
	var b := SurvivorRecords.best(Profile.selected_class, tier)
	var parts: PackedStringArray = []
	if b.has("win"):
		parts.append("victoire en %s" % SurvivorRecords.fmt("win", float(b.win)))
	elif b.has("time"):
		parts.append("tenu %s" % SurvivorRecords.fmt("time", float(b.time)))
	if b.has("level"):
		parts.append("niveau %d" % int(b.level))
	if b.has("dmg"):
		parts.append("%s dégâts" % SurvivorRecords.fmt("dmg", float(b.dmg)))
	var cls := String(GameData.class_data(Profile.selected_class).get("name_fr", Profile.selected_class))
	var l := Hud._label(sub, ("%s · palier %s : %s" % [cls, Survivor.numeral(tier), ", ".join(parts)]) if not parts.is_empty()
		else "%s · palier %s : aucune partie encore" % [cls, Survivor.numeral(tier)], 15, UiTheme.TEXT)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var won := SurvivorRecords.classes_won().size()
	var l2 := Hud._label(sub, "Classes gagnées %d / %d  ·  défis %d / %d" % [won, GameData.classes.size(), SurvivorRecords.defis_done().size(), SurvivorRecords.DEFIS.size()], 15, UiTheme.MUTED)
	l2.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var btn := MenuWidgets.glass_button("Codex du Survivant  ·  %d %%" % roundi(completion() * 100.0), 17, Vector2(0, 46))
	btn.tooltip_text = "Évolutions, armes, panoplies, bestiaire, records et défis du mode."
	btn.pressed.connect(func(): SurvivorCodexPage.open_on(host))
	sub.add_child(btn)


## Un onglet du Codex (reconstruit à chaque affichage).
class CodexTab extends ScrollContainer:
	var kind := ""
	var _v: VBoxContainer

	func _init() -> void:
		horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		set_anchors_preset(Control.PRESET_FULL_RECT)
		_v = VBoxContainer.new()
		_v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_v.add_theme_constant_override("separation", 10)
		add_child(_v)

	func subtitle() -> String:
		var pr := SurvivorCodex.progress()
		match kind:
			"evo":
				return "Une évolution s'ouvre quand sa recette est remplie ; la recette se dévoile dès que tu tiens un ingrédient."
			"weapons":
				return "Chaque type d'arme a ses auto-attaques : porte-les toutes (%d / %d)." % [pr.weapons[0], pr.weapons[1]]
			"sets":
				return "Panoplies complétées (5 / 5) pendant une partie : %d / %d." % [pr.sets[0], pr.sets[1]]
			"monsters":
				return "Monstres croisés dans le mode : %d / %d." % [pr.monsters[0], pr.monsters[1]]
			"records":
				return "Records de %s, palier par palier." % String(GameData.class_data(Profile.selected_class).get("name_fr", ""))
			"defis":
				return "Défis du mode : des titres, jamais de puissance."
			"spells":
				return "Les sorts de %s : un clic ouvre la fiche." % String(GameData.class_data(Profile.selected_class).get("name_fr", ""))
		return ""

	func refresh() -> void:
		for c in _v.get_children():
			c.queue_free()
		match kind:
			"evo":
				_evo()
			"weapons":
				_weapons()
			"sets":
				_sets()
			"monsters":
				_monsters()
			"records":
				_records()
			"defis":
				_defis()
			"spells":
				_spells()

	func _grid(cols: int) -> GridContainer:
		var g := GridContainer.new()
		g.columns = cols
		g.add_theme_constant_override("h_separation", 8)
		g.add_theme_constant_override("v_separation", 8)
		g.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_v.add_child(g)
		return g

	func _cols() -> int:
		var w := get_viewport().get_visible_rect().size.x if is_inside_tree() else 1600.0
		return 4 if w >= 1500.0 else 3

	## Case : icône, titre, ligne ; [param state] 2 obtenu (soleil), 1 connu (lilas), 0 inconnu (« ? »).
	func _cell(parent: Control, icon: String, title: String, line: String, state: int, tip := "") -> PanelContainer:
		var p := PanelContainer.new()
		var border := UiTheme.color("bonbon.soleil.base") if state == 2 else (UiTheme.color("bonbon.amethyste.clair") if state == 1 else UiTheme.color("encre.300"))
		var sb := UiTheme.flat_box(UiTheme.color("encre.700") if state > 0 else UiTheme.color("encre.900"), border, 2, 12, false)
		sb.content_margin_left = 10
		sb.content_margin_right = 10
		sb.content_margin_top = 6
		sb.content_margin_bottom = 6
		p.add_theme_stylebox_override("panel", sb)
		p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		p.custom_minimum_size = Vector2(0, 64)
		p.tooltip_text = tip
		p.mouse_filter = Control.MOUSE_FILTER_PASS
		parent.add_child(p)
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 10)
		h.mouse_filter = Control.MOUSE_FILTER_IGNORE
		p.add_child(h)
		var tr := TextureRect.new()
		tr.texture = UiTheme.texture(icon) if icon != "" and state > 0 else null
		tr.custom_minimum_size = Vector2(40, 40)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if state == 1:
			tr.modulate = Color(1, 1, 1, 0.45)
		h.add_child(tr)
		if state == 0:
			var q := Hud._label(tr, "?", 26, UiTheme.MUTED)
			q.add_theme_font_override("font", UiTheme.bold_font())
			q.set_anchors_preset(Control.PRESET_FULL_RECT)
			q.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			q.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		var t := VBoxContainer.new()
		t.add_theme_constant_override("separation", 0)
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		t.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_child(t)
		var a := Hud._label(t, title, 15, UiTheme.color("bonbon.soleil.clair") if state == 2 else (UiTheme.TEXT if state == 1 else UiTheme.MUTED))
		a.add_theme_font_override("font", UiTheme.bold_font())
		a.clip_text = true
		a.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		a.custom_minimum_size = Vector2(60, 0)
		var b := Hud._label(t, line, UiTheme.MIN_TEXT, UiTheme.MUTED)
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.max_lines_visible = 2
		b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		b.custom_minimum_size = Vector2(60, 0)
		return p

	func _head(text: String) -> void:
		var l := Hud._label(_v, text, 16, UiTheme.color("bonbon.soleil.clair"))
		l.add_theme_font_override("font", UiTheme.bold_font())

	func _evo() -> void:
		var c := SurvivorCodex.state()
		var kinds := {"weapon": "Évolution d'arme", "spell": "Évolution de sort", "passives": "Deux passifs"}
		for k in ["weapon", "spell", "passives"]:
			_head(String(kinds[k]))
			var g := _grid(_cols())
			for d in SurvivorEvo.all().filter(func(x): return String(x.get("kind", "")) == k):
				var id := String(d.id)
				var st := 2 if id in c.evo else (1 if id in c.evo_seen else 0)
				var n := int(SurvivorCodex.stats().evos.get(id, 0))
				_cell(g, String(d.get("icon", Boons.ICONS.get(id, ""))), String(d.name) if st > 0 else "?",
					SurvivorEvo.recipe_text(id) if st > 0 else String(kinds[k]), st,
					(SurvivorCardView.fr(String(d.get("desc", ""))) + ("\nPrise %d fois" % n if n > 0 else "")) if st > 0 else "Pas encore rencontrée.")

	func _weapons() -> void:
		var c := SurvivorCodex.state()
		var by: Dictionary = {}
		for e in SurvivorCodex.weapon_entries():
			if not by.has(e.wtype):
				by[e.wtype] = []
			(by[e.wtype] as Array).append(e)
		var g := _grid(_cols())
		for wt in by:
			var list: Array = by[wt]
			var have := list.filter(func(e): return String(e.key) in c.weapons)
			var names: PackedStringArray = []
			for e in list:
				names.append(("✔ " if String(e.key) in c.weapons else "· ") + String(e.name))
			var tip := "\n".join(names)
			var cell := _cell(g, String(GameData.weapon_type(String(wt)).get("icon", "")), "%s  %d / %d" % [String(list[0].type_name), have.size(), list.size()],
				", ".join(PackedStringArray(have.map(func(e): return String(e.name)))) if not have.is_empty() else "Jamais portée",
				2 if have.size() == list.size() else (1 if not have.is_empty() else 0), tip + "\nClic : la fiche de l'arme")
			cell.gui_input.connect(_on_cell_input.bind("weapon", String(wt)))  # (lot SVX-4, SV-Q6) fiche de l'arme

	func _sets() -> void:
		var c := SurvivorCodex.state()
		var g := _grid(_cols())
		for sid in SurvivorPool.sets():
			var st := 2 if String(sid) in c.sets else (1 if String(sid) in c.sets_seen else 0)
			var fam := String(SurvivorPool.family(String(sid)))
			var fam_name: String = {"str": "Assaut", "agi": "Vivacité", "int": "Sortilège", "wis": "Grâce"}.get(fam, fam)
			var tip := "\n".join(Items.bonus_lines(Items.set_bonus(String(sid), 5))) if st > 0 else ""
			_cell(g, "", SurvivorPool.panoply_name(String(sid)) if st > 0 else "?", "%s · %s" % [fam_name,
				"complète" if st == 2 else ("portée" if st == 1 else "jamais portée")], st, tip)

	func _monsters() -> void:
		var c := SurvivorCodex.state()
		var flow := HFlowContainer.new()
		flow.add_theme_constant_override("h_separation", 6)
		flow.add_theme_constant_override("v_separation", 6)
		flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_v.add_child(flow)
		var list := SurvivorCodex.roster()
		list.sort_custom(func(a, b): return int(GameData.monster(int(a)).get("level", 0)) < int(GameData.monster(int(b)).get("level", 0)))
		for id in list:
			var seen: bool = int(id) in c.monsters
			var m := GameData.monster(int(id))
			var p := PanelContainer.new()
			var boss: bool = int(id) in c.bosses
			var sb := UiTheme.flat_box(UiTheme.color("encre.700") if seen else UiTheme.color("encre.900"),
				UiTheme.color("bonbon.amethyste.base") if boss else (UiTheme.color("bonbon.lagon.base") if seen else UiTheme.color("encre.300")), 2, 10, false)
			sb.content_margin_left = 8
			sb.content_margin_right = 8
			sb.content_margin_top = 3
			sb.content_margin_bottom = 3
			p.add_theme_stylebox_override("panel", sb)
			p.tooltip_text = ("%s · niveau %d%s" % [String(m.get("name", "?")), int(m.get("level", 0)), " · boss vaincu" if boss else ""]) if seen else "Pas encore croisé."
			p.mouse_filter = Control.MOUSE_FILTER_PASS
			flow.add_child(p)
			Hud._label(p, String(m.get("name", "?")) if seen else "?", UiTheme.MIN_TEXT, UiTheme.TEXT if seen else UiTheme.MUTED)

	func _records() -> void:
		var g := _grid(SurvivorRecords.KEYS.size() + 1)
		for h in ["Palier", "Victoire la plus rapide", "Survie la plus longue", "Niveau", "Dégâts", "Monstres", "Prolongation"]:
			var l := Hud._label(g, h, UiTheme.MIN_TEXT, UiTheme.GOLD)
			l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		for p in range(1, Survivor.PALIERS.size() + 1):
			var b := SurvivorRecords.best(Profile.selected_class, p)
			Hud._label(g, "%s · %s" % [Survivor.numeral(p), String(Survivor.PALIERS[p - 1].name)], 15, UiTheme.TEXT)
			for k in SurvivorRecords.KEYS:
				Hud._label(g, SurvivorRecords.fmt(k, float(b[k])) if b.has(k) else "—", 15, UiTheme.TEXT if b.has(k) else UiTheme.MUTED)
		var won := SurvivorRecords.classes_won()
		_head("Classes gagnées : %d / %d" % [won.size(), GameData.classes.size()])
		var flow := HFlowContainer.new()
		flow.add_theme_constant_override("h_separation", 6)
		flow.add_theme_constant_override("v_separation", 6)
		flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_v.add_child(flow)
		var ids: Array = GameData.classes.keys()
		ids.sort_custom(func(a, b): return (String(a) in won) and not (String(b) in won))
		for cid in ids:
			var ok := String(cid) in won
			var p := PanelContainer.new()
			var sb := UiTheme.flat_box(UiTheme.color("encre.700"), UiTheme.color("bonbon.pomme.base") if ok else UiTheme.color("encre.300"), 2, 10, false)
			sb.content_margin_left = 8
			sb.content_margin_right = 8
			sb.content_margin_top = 2
			sb.content_margin_bottom = 2
			p.add_theme_stylebox_override("panel", sb)
			flow.add_child(p)
			Hud._label(p, ("✔ " if ok else "") + String(GameData.class_data(String(cid)).get("name_fr", cid)), UiTheme.MIN_TEXT, UiTheme.TEXT if ok else UiTheme.MUTED)

	## (lot SVX-4, SV-Q6) Les sorts de la classe choisie : une case chacun ; clic : la fiche.
	func _spells() -> void:
		var g := _grid(_cols())
		for sk in GameData.class_data(Profile.selected_class).get("skills", []):
			var d: Dictionary = sk
			var cell := _cell(g, String(d.get("icon", "")), String(d.get("name", "?")), SurvivorCardView.fr(String(d.get("desc", "")).trim_prefix(String(d.get("name", "")) + " : ")), 2,
				"Clic : la fiche du sort")
			cell.gui_input.connect(_on_cell_input.bind("spell", str(int(d.get("id", 0)))))

	func _on_cell_input(ev: InputEvent, kind: String, id: String) -> void:
		if ev is InputEventMouseButton and ev.pressed and (ev as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			Fiche.open_on(self, kind, id)
			accept_event()

	func _defis() -> void:
		var done := SurvivorRecords.defis_done()
		var g := _grid(2 if _cols() < 4 else 3)
		for d in SurvivorRecords.DEFIS:
			var ok := String(d.id) in done
			_cell(g, "", ("✔ " if ok else "") + String(d.text), ("Titre « %s »" % String(d.title)) if String(d.title) != "" else "Pour le plaisir", 2 if ok else 1)
		var s := SurvivorCodex.stats()
		_head("Statistiques du mode")
		var g2 := _grid(2)
		var fav_w := SurvivorCodex.top_of(s.weapons)
		var fav_e := SurvivorCodex.top_of(s.evos)
		var fav_c := SurvivorCodex.top_of(s.classes)
		var rows := [["Parties", str(int(s.games))], ["Victoires", str(int(s.wins))],
			["Temps de jeu", "%d h %02d" % [int(float(s.time)) / 3600, (int(float(s.time)) % 3600) / 60]],
			["Monstres vaincus", Items.fmt_num(int(s.kills))],
			["Arme la plus portée", String(GameData.weapon_type(fav_w).get("name", "—")) if fav_w != "" else "—"],
			["Évolution préférée", String(Boons.get_def(fav_e).get("name", "—")) if fav_e != "" else "—"],
			["Classe la plus jouée", String(GameData.class_data(fav_c).get("name_fr", "—")) if fav_c != "" else "—"]]
		for i in range(1, Survivor.PALIERS.size() + 1):
			rows.append(["Victoires au palier %s" % Survivor.numeral(i), str(SurvivorRewards.wins(i))])
		for r in rows:
			var a := Hud._label(g2, String(r[0]), 15, UiTheme.MUTED)
			a.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			Hud._label(g2, String(r[1]), 15, UiTheme.TEXT)



## Fiche d'arme ou de sort (lot SVX-4, BM-SURV SV-Q6, comme les fiches de l'aide F1) : fenêtre papier sur le Codex, l'icône du
## jeu, ce que fait la chose, ses variantes ou ses paliers et les évolutions qu'elle ouvre ; Fermer ou Échap.
class Fiche extends CanvasLayer:
	var _box: VBoxContainer

	static func open_on(from: Node, kind: String, id: String) -> Fiche:
		var f := Fiche.new()
		f.layer = SurvivorCodexPage.LAYER + 2
		f.process_mode = Node.PROCESS_MODE_ALWAYS
		var host: Node = from.get_tree().current_scene if from.get_tree().current_scene != null else from.get_tree().root
		host.add_child(f)
		f._build(kind, id)
		return f

	func _build(kind: String, id: String) -> void:
		var root := Control.new()
		root.set_anchors_preset(Control.PRESET_FULL_RECT)
		add_child(root)
		var dim := ColorRect.new()
		UiTheme.veil(dim, 0.55)
		dim.set_anchors_preset(Control.PRESET_FULL_RECT)
		dim.gui_input.connect(_on_dim)
		root.add_child(dim)
		var center := CenterContainer.new()
		center.set_anchors_preset(Control.PRESET_FULL_RECT)
		center.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(center)
		var panel := PanelContainer.new()
		UiTheme.paper(panel, 7, Vector2(26, 20))
		panel.custom_minimum_size = Vector2(620, 0)
		center.add_child(panel)
		_box = VBoxContainer.new()
		_box.add_theme_constant_override("separation", 10)
		panel.add_child(_box)
		var data := weapon_sheet(id) if kind == "weapon" else spell_sheet(int(id))
		var head := HBoxContainer.new()
		head.add_theme_constant_override("separation", 12)
		_box.add_child(head)
		var tr := TextureRect.new()
		tr.texture = UiTheme.texture(String(data.icon)) if String(data.icon) != "" else null
		tr.custom_minimum_size = Vector2(64, 64)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		head.add_child(tr)
		var t := Label.new()
		t.text = String(data.title)
		UiTheme.title(t, 26)
		t.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		head.add_child(t)
		var body := RichTextLabel.new()
		body.bbcode_enabled = true
		body.fit_content = true
		body.scroll_active = false
		body.custom_minimum_size = Vector2(568, 0)
		body.add_theme_font_override("normal_font", UiTheme.label_font())
		body.add_theme_font_override("bold_font", UiTheme.bold_font())
		body.add_theme_font_size_override("normal_font_size", 16)
		body.add_theme_font_size_override("bold_font_size", 16)
		body.add_theme_color_override("default_color", UiTheme.color("encre.700"))
		body.text = "\n".join(data.lines)
		_box.add_child(body)
		var close := Button.new()
		close.text = "Fermer"
		UiTheme.style_button(close, "papier", 18)
		close.custom_minimum_size = Vector2(200, 46)
		close.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		close.pressed.connect(queue_free)
		_box.add_child(close)
		UiNav.focus(close)

	func _on_dim(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed:
			queue_free()

	func _unhandled_input(event: InputEvent) -> void:
		if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
			queue_free()
			get_viewport().set_input_as_handled()

	## Fiche d'un type d'arme : ses auto-attaques (variantes, effet à +4), son évolution.
	static func weapon_sheet(wt: String) -> Dictionary:
		var c := SurvivorCodex.state()
		var lines: PackedStringArray = []
		var vs := WeaponAttacks.variants(wt)
		for i in vs.size():
			var v: Dictionary = vs[i]
			var worn: bool = ("%s:%d" % [wt, i]) in c.weapons
			lines.append("[b]%s %s[/b] : %s" % ["✔" if worn else "·", String(v.get("name", "")), SurvivorCardView.fr(String(v.get("desc", "")))])
			if v.has("sig"):
				lines.append("     ★ À +4 : %s" % SurvivorCardView.fr(WeaponAttacks.sig_text(v)))
		lines.append("")
		lines.append("Chaque amélioration d'arme : +2 et une amélioration de l'auto-attaque (jusqu'à +10).")
		for d in SurvivorEvo.all():
			if String(d.get("kind", "")) == "weapon" and wt in (d.get("wtypes", []) as Array):
				var known: bool = String(d.id) in c.evo or String(d.id) in c.evo_seen
				lines.append("[b]◆ Évolution : %s[/b] · %s" % [String(d.name) if known else "?", SurvivorEvo.recipe_text(String(d.id)) if known else "arme à +6 et un passif à découvrir"])
		return {"title": String(GameData.weapon_type(wt).get("name", wt)), "icon": String(GameData.weapon_type(wt).get("icon", "")), "lines": lines}

	## Fiche d'un sort de la classe choisie : ce qu'il fait, sa recharge, ses paliers (5 et 10), les évolutions de sort.
	static func spell_sheet(id: int) -> Dictionary:
		var d: Dictionary = {}
		for sk in GameData.class_data(Profile.selected_class).get("skills", []):
			if int(sk.get("id", -1)) == id:
				d = sk
		var c := SurvivorCodex.state()
		var lines: PackedStringArray = [SurvivorCardView.fr(String(d.get("desc", "")).trim_prefix(String(d.get("name", "")) + " : "))]
		if float(d.get("cooldown", 0.0)) > 0.0:
			lines.append("Recharge : %s s" % Cards._num(float(d.get("cooldown", 0.0))))
		lines.append("")
		lines.append("Niveau 1 à 10 : chaque amélioration renforce le sort ; le niveau 5 est au moins épique, le niveau 10 légendaire.")
		lines.append("Au niveau 10, avec le bon passif, il peut évoluer :")
		for e in SurvivorEvo.all():
			if String(e.get("kind", "")) == "spell":
				var known: bool = String(e.id) in c.evo or String(e.id) in c.evo_seen
				lines.append("[b]◆ %s[/b] · %s" % [String(e.name) if known else "?", SurvivorCardView.fr(String(e.get("desc", ""))) if known else "une recette à découvrir"])
		return {"title": String(d.get("name", "?")), "icon": String(d.get("icon", "")), "lines": lines}
