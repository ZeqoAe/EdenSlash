class_name RunPage
extends HBoxContainer
## Page « Run » du menu pause : les 12 sorts de la run (4 cases et leurs 2 enchaînements), les
## armes et leurs améliorations, le trophée porté (actif) et ceux du sac, les cartes de build et
## passifs, fournitures du sac, bilan, et les actions (reprendre, s'extraire, lobby, quitter).

signal resume_requested
signal extract_requested
signal lobby_requested
signal grimoire_requested
signal settings_requested

var player: Player
var _skills: VBoxContainer
var _skills_title: Label
var _cards: VBoxContainer
var _bag: RichTextLabel
var _summary: RichTextLabel


func _ready() -> void:
	add_theme_constant_override("separation", 16)
	# compétences
	var a := ItemWidgets.panel(self, 0, true)
	_skills_title = ItemWidgets.section(a, "Compétences de la run")
	var sa := ScrollContainer.new()
	sa.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sa.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	a.add_child(sa)
	_skills = VBoxContainer.new()
	_skills.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_skills.add_theme_constant_override("separation", 10)
	sa.add_child(_skills)
	# cartes et passifs
	var b := ItemWidgets.panel(self, 0, true)
	ItemWidgets.section(b, "Trophée et cartes")
	var sb := ScrollContainer.new()
	sb.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sb.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	b.add_child(sb)
	_cards = VBoxContainer.new()
	_cards.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_cards.add_theme_constant_override("separation", 8)
	sb.add_child(_cards)
	# bilan, sac et actions
	var c := ItemWidgets.panel(self, 380)
	ItemWidgets.section(c, "Bilan")
	_summary = ItemWidgets.rich(c, 15)
	_summary.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_summary.fit_content = true
	ItemWidgets.section(c, "Sac (fournitures)")
	_bag = ItemWidgets.rich(c, 14)
	var acts := VBoxContainer.new()
	acts.add_theme_constant_override("separation", 8)
	c.add_child(acts)
	ItemWidgets.action_button(acts, "▶  Reprendre", func(): resume_requested.emit(), 0, true)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	acts.add_child(row)
	ItemWidgets.action_button(row, "Grimoire", func(): grimoire_requested.emit()).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ItemWidgets.action_button(row, "Paramètres", func(): settings_requested.emit()).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ItemWidgets.action_button(acts, "S'extraire (10 s · %s)" % Settings.action_label("extract", 1) if InputMap.has_action("extract") else "S'extraire (10 s)", func(): extract_requested.emit())
	ItemWidgets.action_button(acts, "Abandonner : retour au lobby", func(): lobby_requested.emit())
	ItemWidgets.action_button(acts, "Quitter le jeu", func(): get_tree().quit())


func refresh() -> void:
	if not is_inside_tree():
		return
	for ch in _skills.get_children():
		ch.queue_free()
	# 4 cases, chacune avec ses 2 enchaînements : 12 sorts en tout
	var total := Run.all_skills().size()
	if _skills_title:
		_skills_title.text = "Compétences de la run (%d / %d)" % [total, Run.MAX_SKILLS * (1 + Run.MAX_CHAIN)]
	for i in Run.MAX_SKILLS:
		var ch: Array = []
		if i >= Run.skills.size():
			_row(_skills, "", "Case %d : libre" % (i + 1), "Les compétences s'obtiennent avec les cartes de niveau.", UiTheme.MUTED)
		else:
			var s: Dictionary = Run.skills[i]
			var d := Run.skill_def(int(s.id))
			_row(_skills, String(d.get("icon", "")), "Case %d · %s — rang %d" % [i + 1, d.get("name", "?"), int(s.rank)], String(d.get("desc", "")), UiTheme.GOLD)
			ch = Run.chain_of(i)
		for j in Run.MAX_CHAIN:
			if j < ch.size():
				var cd := Run.skill_def(int(ch[j].id))
				_row(_skills, String(cd.get("icon", "")), "↳ Enchaînement %d : %s — rang %d" % [j + 2, cd.get("name", "?"), int(ch[j].rank)],
					String(cd.get("desc", "")), Color(0.55, 0.9, 1.0), 34, 38)
			else:
				_row(_skills, "", "↳ Enchaînement %d : libre" % (j + 2), "Quand les 4 cases sont pleines, les cartes de sort deviennent des enchaînements.",
					UiTheme.MUTED, 34, 38)
	# armes : auto-attaque et améliorations de la run
	ItemWidgets.section(_skills, "Armes", 15)
	for slot in ["weapon", "offhand"]:
		var ws := Run.weapon_spec(slot)
		var it: Dictionary = Profile.equipped.get(slot, {})
		if ws.is_empty():
			_row(_skills, "", "Arme secondaire : aucune", "Les boss en lâchent toujours une, les élites parfois.", UiTheme.MUTED)
			continue
		var mt := WeaponAttacks.mods_text(ws, Run.weapon_ups.get(slot, {}))
		_row(_skills, String(it.get("icon", GameData.weapon_type(String(ws.wtype)).get("icon", ""))),
			"%s : %s" % ["Arme principale" if slot == "weapon" else "Arme secondaire", WeaponAttacks.variant_label(it) if not it.is_empty() else ws.name],
			String(ws.desc) + ("\n" + mt if mt != "" else "\nPas encore améliorée (cartes d'amélioration d'arme)."), UiTheme.GOLD)
	for ch in _cards.get_children():
		ch.queue_free()
	# trophée : celui porté agit, ceux du sac non
	ItemWidgets.section(_cards, "Trophée", 15)
	var worn: Dictionary = Profile.equipped.get("trophy", {})
	if worn.is_empty():
		_row(_cards, "", "Aucun trophée porté", "Les coffres de trophée en proposent : un effet unique, chaque trophée ne tombe qu'une fois par run.", UiTheme.MUTED)
	else:
		_row(_cards, String(worn.get("icon", "")), "✔ Actif : %s" % Items.display_name(worn),
			String(worn.get("passive", {}).get("desc", "")), Color(0.5, 1.0, 0.55))
	for it in Profile.inventory:
		if String(it.get("slot", "")) == "trophy":
			_row(_cards, String(it.get("icon", "")), "Dans le sac (inactif) : %s" % Items.display_name(it),
				String(it.get("passive", {}).get("desc", "")), UiTheme.MUTED, 0, 40)
	ItemWidgets.section(_cards, "Cartes de build et passifs", 15)
	if Run.passives.is_empty():
		Hud._label(_cards, "Aucune carte pour l'instant : monte de niveau pour en choisir.", 14, UiTheme.MUTED)
	for pid in Run.passives:
		var p := Run.passive_def(pid)
		var rar := String(p.get("rarity", "common"))
		var col: Color = Boons.RARITY.get(rar, Boons.RARITY.common).color
		_row(_cards, String(p.get("icon", Boons.ICONS.get(pid, ""))), "%s · niv. %d" % [p.get("name", pid), int(Run.passives[pid])],
			String(p.get("desc", "")) + ("
Total : " + Cards.total_text(p, Run.power(pid)) if not (p.get("stat", {}) as Dictionary).is_empty() else ""), col)
	var lines: PackedStringArray = [
		"Classe : [b]%s[/b]   ·   niveau [b]%d[/b]" % [Run.class_data().get("name_fr", ""), player.level if player else Run.max_level],
		"Durée : [b]%s[/b]" % Run.duration_text(),
		"Monstres vaincus : [b]%d[/b]   ·   élites : [b]%d[/b]" % [Run.kills, Run.elites],
		"Butin ramassé : [b]%d[/b] objet(s)   ·   or gagné : [b]%d[/b]" % [Run.loot.size(), Run.gold],
	]
	_summary.text = "\n".join(lines)
	if Profile.bag.is_empty():
		_bag.text = "[color=#b8b4c8]Vide : gemmes, parchemins, ciseaux et pierres tombent des monstres et des coffres, et se vendent chez le marchand.[/color]"
	else:
		var parts: PackedStringArray = []
		for k in Profile.bag.keys():
			parts.append("[img=20x20]%s[/img] %s ×%d" % [Craft.icon(k), Craft.label(k), Profile.bag_count(k)])
		_bag.text = "\n".join(parts)


func _row(parent: Control, icon: String, title: String, desc: String, color: Color, indent := 0, icon_px := 52) -> void:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	parent.add_child(h)
	if indent > 0:
		var pad := Control.new()
		pad.custom_minimum_size = Vector2(indent - 12, 0)
		h.add_child(pad)
	var ic := TextureRect.new()
	ic.custom_minimum_size = Vector2(icon_px, icon_px)
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ic.texture = UiTheme.texture(icon)
	h.add_child(ic)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(v)
	var t := Hud._label(v, title, 16, color)
	t.add_theme_font_override("font", UiTheme.bold_font())
	var l := Hud._label(v, desc, 13, Color(0.85, 0.84, 0.9))
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
