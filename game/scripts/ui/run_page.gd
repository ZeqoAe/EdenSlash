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
signal quit_requested

var player: Player
var _skills: VBoxContainer
var _skills_title: Label
var _cards: VBoxContainer
var _bag: RichTextLabel
var _bag_title: Label
var _stats: GridContainer
var _free_rows: Array = []  # positions d'enchaînement libres : visibles seulement pendant un glisser-déposer


func _ready() -> void:
	add_theme_constant_override("separation", 16)
	# compétences
	var a := ItemWidgets.panel(self, 0, true)
	_skills_title = ItemWidgets.section(a, "Compétences" if Royale.active else "Compétences de la run")
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
	b.get_parent().visible = not Survivor.active and not Duel.active  # Survivant : passifs et sets sont sur la page Build (lot S5) ; duel : ni trophée ni carte (passe M7)
	ItemWidgets.section(b, "Cartes" if Royale.active else "Trophée et cartes")  # (Battle royale : pas de trophée, passe M1)
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
	_stats = GridContainer.new()
	_stats.columns = 3
	_stats.add_theme_constant_override("h_separation", 8)
	_stats.add_theme_constant_override("v_separation", 8)
	c.add_child(_stats)
	_bag_title = ItemWidgets.section(c, "Sac")
	_bag_title.tooltip_text = "Fournitures de la run : gemmes, parchemins, ciseaux et pierres"
	_bag_title.mouse_filter = Control.MOUSE_FILTER_PASS
	_bag = ItemWidgets.rich(c, 15)
	var acts := VBoxContainer.new()
	acts.add_theme_constant_override("separation", 8)
	c.add_child(acts)
	ItemWidgets.action_button(acts, "▶  Reprendre", func(): resume_requested.emit(), 0, true)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	acts.add_child(row)
	ItemWidgets.action_button(row, "Grimoire", func(): grimoire_requested.emit()).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ItemWidgets.action_button(row, "Paramètres", func(): settings_requested.emit()).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if not (Training.active or Duel.active or Tower.active or Royale.active or Survivor.active):  # (Survivant : pas d'extraction)
		var ex := ItemWidgets.action_button(acts, "S'extraire", func(): extract_requested.emit())
		ex.tooltip_text = "Quitte la carte en gardant la run : compte 10 s sans être touché%s" % [" (touche %s)" % Settings.action_label("extract", 1) if InputMap.has_action("extract") else ""]
	ItemWidgets.action_button(acts, PauseMenu.leave_texts().button, func(): lobby_requested.emit())
	ItemWidgets.action_button(acts, "Quitter le jeu", func(): quit_requested.emit())


func _process(_delta: float) -> void:
	var dragging := get_viewport().gui_is_dragging()
	for r in _free_rows:
		if is_instance_valid(r):
			r.visible = dragging


func refresh() -> void:
	if not is_inside_tree():
		return
	for ch in _skills.get_children():
		ch.queue_free()
	_free_rows.clear()
	# 4 cases, chacune avec ses 2 enchaînements : 12 sorts en tout
	var total := Run.all_skills().size()
	if _skills_title:
		_skills_title.text = ("Compétences (%d / %d)" if Royale.active else "Compétences de la run (%d / %d)") % [total, Survivor.SPELL_MAX if Survivor.active else Run.MAX_SKILLS * (1 + Run.MAX_CHAIN)]
	if _skills_title:
		_skills_title.tooltip_text = "Glisse un sort sur un autre pour échanger leurs places (touches et enchaînements)"
		_skills_title.mouse_filter = Control.MOUSE_FILTER_PASS
	# seules les cases occupées s'affichent (+ la prochaine, libre) : jamais une liste de lignes vides
	for i in Run.skills.size():
		var s: Dictionary = Run.skills[i]
		var d := Run.skill_def(int(s.id))
		_row(_skills, String(d.get("icon", "")), "Case %d · %s — rang %d" % [i + 1, d.get("name", "?"), int(s.rank)], String(d.get("desc", "")), UiTheme.GOLD, 0, 52, Vector2i(i, 0))
		var ch: Array = Run.chain_of(i)
		for j in Run.MAX_CHAIN:
			if j < ch.size():
				var cd := Run.skill_def(int(ch[j].id))
				_row(_skills, String(cd.get("icon", "")), "↳ Enchaînement %d : %s — rang %d" % [j + 2, cd.get("name", "?"), int(ch[j].rank)],
					String(cd.get("desc", "")), Color(0.55, 0.9, 1.0), 34, 38, Vector2i(i, j + 1))
			else:
				# position d'enchaînement libre : invisible, elle n'apparaît que le temps d'un glisser (cible de dépôt)
				var free := _row(_skills, "", "↳ Enchaînement %d : libre" % (j + 2), "", UiTheme.MUTED, 34, 38, Vector2i(i, j + 1))
				free.visible = false
				_free_rows.append(free)
	if Run.skills.size() < Run.MAX_SKILLS:
		_row(_skills, "", "Case %d libre" % (Run.skills.size() + 1), "", UiTheme.MUTED, 0, 52, Vector2i(-1, -1), "Les compétences s'obtiennent avec les cartes de niveau")
	# armes : auto-attaque et améliorations de la run
	ItemWidgets.section(_skills, "Armes", 15)
	for slot in (["weapon"] if Survivor.active or Royale.active else ["weapon", "offhand"]):  # (Survivant, Battle royale : pas d'arme secondaire)
		var ws := Run.weapon_spec(slot)
		var it: Dictionary = Profile.equipped.get(slot, {})
		if ws.is_empty():
			_row(_skills, "", "Arme secondaire : aucune", "", UiTheme.MUTED, 0, 0, Vector2i(-1, -1), "Équipe une arme d'un autre type (Héros) pour pouvoir changer d'arme en combat")
			continue
		var mt := WeaponAttacks.mods_text(ws, Run.weapon_ups.get(slot, {}))
		_row(_skills, String(it.get("icon", GameData.weapon_type(String(ws.wtype)).get("icon", ""))),
			"%s : %s" % ["Arme principale" if slot == "weapon" else "Arme secondaire", WeaponAttacks.variant_label(it) if not it.is_empty() else ws.name],
			String(ws.desc) + ("\n" + mt if mt != "" else "\nPas encore améliorée (cartes d'amélioration d'arme)."), UiTheme.GOLD)
	for ch in _cards.get_children():
		ch.queue_free()
	# trophées : collection de la run, tous actifs (le Battle royale n'en donne pas : passe M1)
	if not Royale.active:
		ItemWidgets.section(_cards, "Trophées (%d / %d)" % [Run.trophies.size(), Run.MAX_TROPHIES], 15)
	if Run.trophies.is_empty() and not Royale.active:
		_row(_cards, "", "Aucun trophée", "", UiTheme.MUTED, 0, 0, Vector2i(-1, -1), "Coffres et sanctuaires : jusqu'à %d trophées par run, tous d'effets différents, tous actifs" % Run.MAX_TROPHIES)
	for t in Run.trophies:
		_row(_cards, String(t.get("icon", "")), "✔ %s · %s" % [String(t.get("passive", {}).get("name", "")), Items.display_name(t)],
			String(t.get("passive", {}).get("desc", "")), Color(0.5, 1.0, 0.55), 0, 40)
	ItemWidgets.section(_cards, "Passifs" if Royale.active else "Cartes de build et passifs", 15)
	if Run.passives.is_empty():
		Hud._label(_cards, "Aucune carte", UiTheme.MIN_TEXT, UiTheme.MUTED)
	for pid in Run.passives:
		var p := Run.passive_def(pid)
		var rar := String(p.get("rarity", "common"))
		var col: Color = Boons.RARITY.get(rar, Boons.RARITY.common).color
		_row(_cards, String(p.get("icon", Boons.ICONS.get(pid, ""))), "%s · niv. %d" % [p.get("name", pid), int(Run.passives[pid])],
			String(p.get("desc", "")) + ("
Total : " + Cards.total_text(p, Run.power(pid)) if not (p.get("stat", {}) as Dictionary).is_empty() else ""), col)
	for ch in _stats.get_children():
		ch.queue_free()
	var secs := (Time.get_ticks_msec() - Run.started_at) / 1000
	var tiles := [[str(player.level if player else Run.max_level), "niveau"], ["%d:%02d" % [secs / 60, secs % 60], "durée"],
			[str(Run.kills), "monstres"], [str(Run.elites), "élites"], [str(Run.gold), "or gagné"], [str(Run.loot.size()), "objets"]]
	if Duel.active:
		# duel, Arènes, Gantelet (passe M7) : ni monstres, ni or, ni objets ; le score et les coups
		var t := int(PvpCaps.elapsed)
		tiles = [[str(Duel.level), "niveau"], ["%d - %d" % [Duel.wins, Duel.losses], "manches"], ["%d:%02d" % [t / 60, t % 60], "manche %d" % Duel.round_n],
			["%d %%" % roundi(PvpCaps.best_dealt * 100.0), "coup porté"], ["%d %%" % roundi(PvpCaps.best_taken * 100.0), "coup reçu"],
			["À l'arme" if Duel.bare else "Équipé", Duel.mode_title().to_lower() if Duel.mode != "free" else "duel libre"]]
	var rd = _royale()
	if rd != null:
		# Battle royale (passe M1) : ni monstres, ni or, ni objets ; les chiffres de la partie
		var t := int(rd.player_time())
		tiles = [[str(player.level if player else 1), "niveau"], ["%d:%02d" % [t / 60, t % 60], "durée"],
			["%d / %d" % [rd.alive_count(), Royale.PLAYERS], "en vie"], [str(Royale.kills), "éliminations"],
			[str(rd.chests_opened), "coffres"], [str(Potions.count("heal")), "soins"]]
	for e in tiles:
		ResultsPanel.tile(_stats, String(e[0]), String(e[1]), "", false, 100.0)
	_bag_title.visible = not Profile.bag.is_empty() and not Duel.active  # (duel : rien ne se ramasse ni ne se boit)
	_bag.visible = _bag_title.visible
	var parts: PackedStringArray = []
	for k in Profile.bag.keys():
		parts.append("[img=20x20]%s[/img] %s ×%d" % [Craft.icon(k), Craft.label(k), Profile.bag_count(k)])
	_bag.text = "\n".join(parts)


## Directeur du Battle royale de la partie en cours (null hors Battle royale).
func _royale():
	if not Royale.active:
		return null
	var w: Node = player.get_parent() if player != null else get_tree().current_scene  # le monde (parent du héros)
	var d = w.get("director") if w != null else null
	return d.royale if d != null and d.get("royale") != null else null


## Ligne de la grille des sorts : on la glisse sur une autre pour échanger leurs places (Run.swap_spells).
class SpellRow extends HBoxContainer:
	var pos := Vector2i(-1, -1)
	var label := ""
	var on_swap: Callable

	func _get_drag_data(_at: Vector2) -> Variant:
		if Run.spell_at(pos).is_empty():
			return null
		var p := Label.new()
		p.text = "  %s  " % label
		p.add_theme_font_size_override("font_size", 16)
		p.add_theme_color_override("font_color", Color(1, 0.92, 0.6))
		p.add_theme_stylebox_override("normal", UiTheme.flat_box(Color(0.1, 0.08, 0.2, 0.95), UiTheme.GOLD, 2, 8))
		set_drag_preview(p)
		return {"spell_pos": pos}

	func _can_drop_data(_at: Vector2, data: Variant) -> bool:
		if not (data is Dictionary and data.has("spell_pos")):
			return false
		var from: Vector2i = data.spell_pos
		if from == pos:
			return false
		# les emplacements libres n'accueillent que des enchaînements
		return not Run.spell_at(pos).is_empty() or (pos.y > 0 and from.y > 0 and pos.x < Run.skills.size())

	func _drop_data(_at: Vector2, data: Variant) -> void:
		if on_swap.is_valid():
			on_swap.call(data.spell_pos, pos)


func _swap(a: Vector2i, b: Vector2i) -> void:
	if Run.swap_spells(a, b):
		Sfx.ui("pickup", -8.0)
		refresh()


func _row(parent: Control, icon: String, title: String, desc: String, color: Color, indent := 0, icon_px := 52, spell := Vector2i(-1, -1), tip := "") -> HBoxContainer:
	var h: HBoxContainer
	if spell.x >= 0:
		var sr := SpellRow.new()
		sr.pos = spell
		sr.label = title.get_slice(" —", 0)
		sr.on_swap = _swap
		sr.mouse_filter = Control.MOUSE_FILTER_STOP
		sr.mouse_default_cursor_shape = Control.CURSOR_DRAG if not Run.spell_at(spell).is_empty() else Control.CURSOR_ARROW
		h = sr
	else:
		h = HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	if tip != "":
		h.tooltip_text = tip
		h.mouse_filter = Control.MOUSE_FILTER_PASS
	parent.add_child(h)
	if indent > 0:
		var pad := Control.new()
		pad.custom_minimum_size = Vector2(indent - 12, 0)
		h.add_child(pad)
	if icon_px > 0 and icon == "":
		# case libre : un cadre vide avec un « + » à la place de l'icône (les titres restent alignés)
		var slot := PanelContainer.new()
		slot.add_theme_stylebox_override("panel", UiTheme.flat_box(Color(0.05, 0.045, 0.09, 0.8), UiTheme.GOLD_DIM, 1, 8, false))
		slot.custom_minimum_size = Vector2(icon_px, icon_px)
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_child(slot)
		var plus := Hud._label(slot, "+", 24, UiTheme.MUTED)
		plus.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		plus.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	elif icon_px > 0:
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
	t.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if desc != "":
		var l := Hud._label(v, desc, UiTheme.MIN_TEXT, Color(0.85, 0.84, 0.9))
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return h
