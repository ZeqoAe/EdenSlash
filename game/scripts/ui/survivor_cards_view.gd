class_name SurvivorCardView
extends RefCounted
## Rendu des cartes du Survivant dans le choix de cartes (lot S5, SPEC §10.1) : une carte = une idée, lisible d'un coup
## d'œil, sans paragraphe. CardPicker garde le cadre (couleur de rareté, pastille de la touche, Bannir / Garder) et
## délègue le contenu ici quand la carte est une carte du Survivant (handles).
##   - Pièce / arme : icône, nom à la couleur de la rareté, statistique principale en gros, 4 lignes au plus, jet de
##     qualité (barre 100 → 120, étoile au jet parfait), set (pièces portées / 5 et prochain bonus 2 / 3 / 5), passif fixe,
##     paliers à venir (+6 / +8 / +10), « Gardée à vie ».
##   - Amélioration : « +4 → +6 », jauge des paliers (le gain surligné), le passif du palier tiré (encadré doré), les
##     statistiques avant → après (▲), le jet relevé, les passifs déjà acquis ; arme : l'amélioration d'auto-attaque.
##   - Sort : nouveau (case ou enchaînement, niveau 1 / 10) ou amélioration (niveau n → n + 1 sur 10, « Ce niveau » puis
##     « Total »).
## Les textes restent courts ; le détail chiffré complet est dans l'infobulle de l'objet (page Build).

const GOOD := Color(0.5, 0.95, 0.55)
const BAD := Color(1.0, 0.45, 0.42)
const PASSIVE := Color(1.0, 0.83, 0.42)
const TEXT := Color(0.93, 0.92, 0.97)
const DIM := Color(0.7, 0.68, 0.8)
const TRACK := Color(0.16, 0.14, 0.25)


## La carte est-elle rendue ici ? (Survivant en cours, carte d'une famille du Survivant ; Battle royale : ses pièces, ses
## améliorations de pièce et ses sorts passent par les mêmes cartes, lot BR3.)
static func handles(card: Dictionary) -> bool:
	return (SurvivorCards.on() or Royale.active) and SurvivorCards.FAMILY.has(String(card.get("type", "")))


## Ligne du haut de la carte (à côté de la pastille de la touche) : ce qu'est la carte, en trois mots.
static func header(card: Dictionary) -> String:
	var t := String(card.get("type", ""))
	var tier_name := String(Cards.tier(String(card.get("tier", "common"))).name).to_lower()
	match t:
		"sv_piece":
			return "%s · %s" % [Items.SLOT_NAMES.get(String(card.slot), card.slot), _rarity_name(card.item)]
		"sv_weapon":
			return String(card.get("subtitle", "Arme"))
		"sv_piece_up", "sv_weapon_up":
			return "%s · %s" % [Items.SLOT_NAMES.get(String(card.slot), card.slot), tier_name]
		"skill":
			return "Nouveau sort"
		"chain":
			return "Nouveau sort · chaîne"
		"upgrade":
			return "Sort · %s" % tier_name
		"sv_evolution":
			return "Évolution légendaire"
	return String(card.get("subtitle", ""))


## Remplit [param v] (contenu de la carte, sous la ligne du haut) pour la carte [param card] de couleur [param col].
static func build(v: VBoxContainer, card: Dictionary, col: Color) -> void:
	match String(card.get("type", "")):
		"sv_piece", "sv_weapon":
			_piece(v, card, col)
		"sv_piece_up", "sv_weapon_up":
			_upgrade(v, card, col)
		"skill", "chain":
			_spell_new(v, card, col)
		"upgrade":
			_spell_up(v, card, col)
		_:
			_simple(v, card, col)
	var fill := Control.new()  # Bannir / Garder restent en bas de la carte, alignés d'une carte à l'autre
	fill.size_flags_vertical = Control.SIZE_EXPAND_FILL
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(fill)


# --- familles ---------------------------------------------------------------------------------------------------------
## Nouvelle pièce ou arme.
static func _piece(v: VBoxContainer, card: Dictionary, col: Color) -> void:
	var item: Dictionary = card.item
	var weapon := String(card.type) == "sv_weapon"
	var head := _icon_row(v, String(item.get("icon", "")), 56, col)
	var name := _label(head, Items.card_name(item), 18, Items.color_of(item), true)
	name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name.max_lines_visible = 2  # un nom très long finit en « … » (il est entier dans la carte de la pièce)
	name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name.custom_minimum_size = Vector2(60, 0)
	_main_stat(head, item)
	if weapon:
		var s := WeaponAttacks.spec_for(item)
		var bb := "[color=#ffcf6b][b]%s[/b][/color] · %s" % [String(s.name), String(s.desc)]
		if s.has("sig"):
			bb += "\n[color=#ffb347]★ À +4 : %s[/color]" % WeaponAttacks.sig_text(s)
		_rich(v, bb, 14)
	else:
		_stat_grid(v, item, 4)
	_jet(v, item)
	_set_block(v, item, true)
	for p in item.get("sv_passives", []):
		_passive_box(v, String(p.id), float(p.get("power", 1.0)), "Passif", false)
	_lock_line(v, item)


## Amélioration d'une pièce ou de l'arme : +N, jauge des paliers, passif tiré, avant → après.
static func _upgrade(v: VBoxContainer, card: Dictionary, col: Color) -> void:
	var slot := String(card.slot)
	var item: Dictionary = Profile.equipped.get(slot, {})
	var offer: Dictionary = card.get("offer", {})
	var from := int(offer.get("from", item.get("upgrade", 0)))
	var to := int(offer.get("to", from + Survivor.UP_STEP))
	var head := _icon_row(v, String(item.get("icon", card.get("icon", ""))), 48, col)
	var name := _label(head, Items.card_name(item).trim_prefix("+%d " % from), 15, Items.color_of(item), true)
	name.clip_text = true
	name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name.custom_minimum_size = Vector2(60, 0)
	_label(head, "+%d → +%d" % [from, to], 26, UiTheme.GOLD)
	var g := Segments.new(Items.MAX_UPGRADE, from, to - from, Survivor.WAKE_AT, col)
	g.labels = true
	v.add_child(g)
	var gained: Array = offer.get("passives", [])
	for p in gained:
		_passive_box(v, String(p.id), float(p.power), "Nouveau passif +%d" % int(p.at), true)
	# statistiques avant → après (2 lignes), le jet s'il monte, le prochain palier
	var after := item.duplicate(true)
	after["upgrade"] = to
	var q0 := float(item.get("quality", 1.0))
	var q1 := minf(q0 + float(SurvivorCards.QUALITY_UP.get(String(card.get("tier", "common")), 0.0)), Survivor.rule("perfect_quality"))
	after["quality"] = q1
	var two := gained.size() > 1  # légendaire qui éveille deux passifs : carte resserrée (1280 × 720, test_sv5)
	var lines := delta_lines(item, after, 1 if two else 2)
	if q1 > q0 + 0.0001:
		lines.append("[color=#b4b0c8]Jet[/color]  %d → [b][color=#7fe08a]%d[/color][/b] / %d  [color=#7fe08a]▲[/color]" % [roundi(q0 * 100.0), roundi(q1 * 100.0), roundi(Survivor.rule("perfect_quality") * 100.0)])
	if gained.is_empty():
		var next: Array = Survivor.WAKE_AT.filter(func(at): return int(at) > to)
		lines.append("[color=#b4b0c8]%s[/color]" % (("Prochain passif à +%d" % int(next[0])) if not next.is_empty() else "Passifs au complet"))
	_rich(v, "\n".join(lines), 15)
	if slot == "weapon" and offer.has("auto"):
		var auto := WeaponAttacks.upgrade_lines(WeaponAttacks.spec_for(item), Run.weapon_ups.get("weapon", {}), offer.auto)
		if not auto.is_empty():
			_rich(v, "[color=#ffcf6b]Auto-attaque[/color]  " + " · ".join(auto.slice(0, 1 if two else 2)), 14)
	var owned: Array = (item.get("sv_passives", []) as Array).map(func(p): return String(Boons.get_def(String(p.id)).get("name", p.id)))
	if not owned.is_empty() and not two:
		var l := _label(v, "Acquis : " + " · ".join(PackedStringArray(owned)), UiTheme.MIN_TEXT, DIM)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


## Nouveau sort : sa case (ou l'enchaînement), sa recharge, niveau 1 sur 10.
static func _spell_new(v: VBoxContainer, card: Dictionary, col: Color) -> void:
	var d := Run.skill_def(int(card.id))
	var head := _icon_row(v, String(d.get("icon", card.get("icon", ""))), 64, col)
	_label(head, String(d.get("name", card.get("title", ""))), 20, TEXT, true).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label(head, "Recharge %s s" % Cards._num(float(d.get("cooldown", 0.0))), UiTheme.MIN_TEXT, DIM)
	_rich(v, String(d.get("desc", "")), 15)
	v.add_child(Segments.new(int(Cards.rules().max_rank), 0, 1, [5, 10], col))
	if String(card.type) == "chain":
		var slot := int(card.get("slot", 0))
		var first := Run.skill_def(int(Run.skills[slot].id)) if slot < Run.skills.size() else {}
		_label(v, "Niveau 1 / %d" % int(Cards.rules().max_rank), UiTheme.MIN_TEXT, DIM)
		var l := _label(v, "Enchaînement : rappuie sur la touche de la case %d après « %s »." % [slot + 1, String(first.get("name", "?"))], UiTheme.MIN_TEXT, Color(0.62, 0.85, 1.0))
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	else:
		_label(v, "Niveau 1 / %d  ·  case %d" % [int(Cards.rules().max_rank), Run.skills.size() + 1], UiTheme.MIN_TEXT, DIM)


## Amélioration de sort : niveau n → n + 1 sur 10, l'effet de ce niveau puis le total.
static func _spell_up(v: VBoxContainer, card: Dictionary, col: Color) -> void:
	var id := int(card.id)
	var d := Run.skill_def(id)
	var cur := Run.skill_entry(id)
	var rank := int(cur.get("rank", Run.skill_rank(id)))
	var to := int(card.get("rank_to", rank + 1))
	var mx := int(Cards.rules().max_rank)
	var head := _icon_row(v, String(d.get("icon", card.get("icon", ""))), 56, col)
	_label(head, String(d.get("name", card.get("title", ""))), 19, TEXT, true).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label(head, "Niv. %d → %d" % [rank, to], 24, UiTheme.GOLD)
	v.add_child(Segments.new(mx, rank, to - rank, [5, 10], col))
	var up: Dictionary = card.get("up", {})
	_rich(v, "[color=#ffd36b][b]Ce niveau[/b][/color]\n" + "\n".join(level_lines(up)), 15)
	_rich(v, "[color=#ffd36b][b]Total au niveau %d[/b][/color]\n%s" % [to, total_text(cur, up)], 15)


static func _simple(v: VBoxContainer, card: Dictionary, col: Color) -> void:
	var head := _icon_row(v, String(card.get("icon", "")), 64, col)
	_label(head, String(card.get("title", "")), 20, TEXT, true).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_rich(v, String(card.get("desc", "")), 15)


# --- textes chiffrés ------------------------------------------------------------------------------------------------------
## Effet d'une amélioration de sort, une ligne par effet (« +18 % de dégâts »).
static func level_lines(up: Dictionary) -> PackedStringArray:
	var out: PackedStringArray = []
	for k in [["dmg", "de dégâts"], ["heal", "de soins"], ["dur", "de durée des effets"]]:
		if up.has(k[0]):
			out.append("[color=#7fe08a]+%s %%[/color] %s" % [Cards._num(float(up[k[0]]) * 100.0), k[1]])
	if up.has("cd"):
		out.append("[color=#7fe08a]-%s %%[/color] de recharge" % Cards._num(float(up.cd) * 100.0))
	if up.has("facets"):
		out.append("Facettes : [b]%s[/b]" % ", ".join((up.facets as Array).map(func(f): return String(Cards.FACET_VALUES[f].name))))
	if up.has("rider"):
		var rd: Dictionary = up.rider
		out.append("Au lancement : +%s %% %s (%s s)" % [Cards._num(float(rd.value) * 100.0), Cards.ATTR_FR.get(String(rd.stat), rd.stat), Cards._num(float(rd.duration))])
	return out


## Total du sort après l'amélioration (« Dégâts +54 % · Recharge -21 % »).
static func total_text(cur: Dictionary, up: Dictionary) -> String:
	var parts: PackedStringArray = []
	for k in [["dmg", "Dégâts"], ["heal", "Soins"], ["dur", "Durée"]]:
		var a := float(cur.get(k[0], 0.0)) + float(up.get(k[0], 0.0))
		if absf(a) > 0.0001:
			parts.append("%s [b]+%s %%[/b]" % [k[1], Cards._num(a * 100.0)])
	var c := minf(float(cur.get("cd", 0.0)) + float(up.get("cd", 0.0)), 0.6)
	if c > 0.0001:
		parts.append("Recharge [b]-%s %%[/b]" % Cards._num(c * 100.0))
	return " · ".join(parts) if not parts.is_empty() else "Effet de base"


## Total d'un sort porté (page Build) : « Dégâts +54 % · Recharge -21 % ».
static func spell_total(entry: Dictionary) -> String:
	return total_text(entry, {})


# --- briques ----------------------------------------------------------------------------------------------------------------
static func _rarity_name(item: Dictionary) -> String:
	return String(Items.RARITIES[clampi(int(item.get("rarity", 0)), 0, Items.RARITIES.size() - 1)].name)


## Icône à gauche, colonne de textes à droite ; renvoie la colonne.
static func _icon_row(v: VBoxContainer, icon: String, px: int, col: Color) -> VBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(h)
	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", UiTheme.flat_box(Color(0.05, 0.04, 0.09, 0.9), Color(col, 0.85), 2, 8, false))
	frame.custom_minimum_size = Vector2(px + 6, px + 6)
	frame.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(frame)
	var tr := TextureRect.new()
	tr.texture = UiTheme.texture(icon) if icon != "" else null
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.custom_minimum_size = Vector2(px, px)
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(tr)
	var col_v := VBoxContainer.new()
	col_v.add_theme_constant_override("separation", 2)
	col_v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col_v.alignment = BoxContainer.ALIGNMENT_CENTER
	col_v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(col_v)
	return col_v


static func _label(parent: Control, text: String, size: int, color: Color, bold := false) -> Label:
	var l := Label.new()
	l.text = text
	if size >= 24:
		l.add_theme_font_override("font", UiTheme.title_font())
	elif bold:
		l.add_theme_font_override("font", UiTheme.bold_font())
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_constant_override("outline_size", 3)
	l.add_theme_color_override("font_outline_color", Color(0.02, 0.01, 0.05, 0.8))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l


static func _rich(parent: Control, bb: String, size := 15) -> RichTextLabel:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.scroll_active = false
	r.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	r.custom_minimum_size = Vector2(80, 0)
	r.add_theme_font_size_override("normal_font_size", size)
	r.add_theme_font_size_override("bold_font_size", size)
	r.add_theme_font_override("bold_font", UiTheme.bold_font())
	r.add_theme_color_override("default_color", TEXT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.text = fr(bb)
	parent.add_child(r)
	return r


## Statistique principale en gros (« 1 240 » + « Défense »).
static func _main_stat(parent: Control, item: Dictionary) -> void:
	var st := Items.stats(item)
	var k := Items.main_stat_key(item, st)
	if k == "":
		return
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(h)
	var pct: bool = k in Items.PERCENT_STATS
	var val := ("%d %%" % roundi(float(st[k]) * 100.0)) if pct else Items.fmt_num(roundi(float(st[k])))
	_label(h, val, 24, Color.WHITE).size_flags_vertical = Control.SIZE_SHRINK_END
	var n := _label(h, String(Items.STAT_NAMES.get(k, k)), 15, DIM)
	n.size_flags_vertical = Control.SIZE_SHRINK_END


## Statistiques secondaires (les plus lourdes pour l'emplacement), deux colonnes : nom, valeur.
static func _stat_grid(v: VBoxContainer, item: Dictionary, n: int) -> void:
	var st := Items.stats(item)
	var main := Items.main_stat_key(item, st)
	var rows: Array = Items.stat_rows(item).filter(func(r): return String(r.k) != main)
	rows.sort_custom(func(a, b): return float(a.w) > float(b.w))
	if rows.is_empty():
		return
	var g := GridContainer.new()
	g.columns = 2
	g.add_theme_constant_override("h_separation", 14)
	g.add_theme_constant_override("v_separation", 0)
	g.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(g)
	for r in rows.slice(0, n):
		_rich(g, "[color=#b4b0c8]%s[/color]  [b]%s[/b]" % [String(r.name), String(r.val)], 15).size_flags_horizontal = Control.SIZE_EXPAND_FILL


## Jet de qualité : barre de 100 à 120, valeur, étoile au jet parfait.
static func _jet(v: VBoxContainer, item: Dictionary) -> void:
	var lo := Survivor.rule("quality_min")
	var hi := Survivor.rule("perfect_quality")
	var q := float(item.get("quality", 1.0))
	var perfect := SurvivorGear.is_perfect(item)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.tooltip_text = "Qualité de la pièce : de %d à %d. Le jet parfait vaut %d." % [roundi(lo * 100.0), roundi(hi * 100.0), roundi(hi * 100.0)]
	v.add_child(h)
	_label(h, "Jet", UiTheme.MIN_TEXT, DIM)
	var bar := Bar.new()
	bar.ratio = clampf((q - lo) / maxf(hi - lo, 0.001), 0.0, 1.0)
	bar.color = UiTheme.GOLD if perfect else Color(0.55, 0.78, 1.0)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(bar)
	if perfect:
		_label(h, "★ Jet parfait", UiTheme.MIN_TEXT, UiTheme.GOLD, true)
	else:
		_label(h, "%d / %d" % [roundi(q * 100.0), roundi(hi * 100.0)], UiTheme.MIN_TEXT, TEXT, true)


## Set de la pièce : nom, pièces portées (avec celle-ci si [param with_this]) sur 5, et le prochain bonus.
static func _set_block(v: VBoxContainer, item: Dictionary, with_this: bool) -> void:
	var sid := String(item.get("set", ""))
	if sid == "" or not sid in SurvivorPool.sets():
		return
	var worn := int(Items.set_counts(Profile.equipped).get(sid, 0))
	var n := worn + (1 if with_this else 0)
	var tiers := Items.set_tiers(sid)
	var top := int(tiers.max()) if not tiers.is_empty() else 5
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(h)
	var name := _label(h, "◆ " + SurvivorPool.panoply_name(sid), UiTheme.MIN_TEXT + 1, Items.SET_COLOR, true)
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name.clip_text = true
	name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_label(h, "●".repeat(mini(worn, top)) + ("◉" if with_this and n <= top else "") + "○".repeat(maxi(0, top - n)), UiTheme.MIN_TEXT, Items.SET_COLOR)
	_label(h, "%d / %d" % [n, top], UiTheme.MIN_TEXT, Items.SET_COLOR, true)
	for t in tiers:
		if int(t) > worn and int(t) >= n:
			var on := int(t) == n
			var l := _label(v, "%s %d pièces : %s" % ["✔" if on else "À", int(t), " ; ".join(Items.bonus_lines(Items.set_bonus(sid, int(t))))],
				UiTheme.MIN_TEXT, Items.SET_COLOR if on else DIM)
			l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			l.max_lines_visible = 1 if with_this else 2  # une ligne sur la carte (le bonus complet est sur la page Build)
			l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			l.custom_minimum_size = Vector2(60, 0)
			break


## Passif : petite icône, nom en or, effet ; [param fresh] : encadré doré (le passif que la carte apporte).
static func _passive_box(v: VBoxContainer, id: String, power: float, caption: String, fresh: bool) -> void:
	var d := Boons.get_def(id)
	var box := PanelContainer.new()
	var sb := UiTheme.flat_box(Color(0.22, 0.16, 0.04, 0.55) if fresh else Color(0.1, 0.08, 0.16, 0.7),
		UiTheme.GOLD if fresh else Color(0.42, 0.36, 0.22, 0.7), 2 if fresh else 1, 8, false)
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 3
	sb.content_margin_bottom = 4
	box.add_theme_stylebox_override("panel", sb)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(box)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(h)
	var icon := String(d.get("icon", Boons.ICONS.get(id, "")))
	if icon != "":
		var tr := TextureRect.new()
		tr.texture = UiTheme.texture(icon)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.custom_minimum_size = Vector2(28, 28)
		tr.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_child(tr)
	var t := VBoxContainer.new()
	t.add_theme_constant_override("separation", 0)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(t)
	var head := _label(t, "%s · %s" % [caption, String(d.get("name", id))], UiTheme.MIN_TEXT, PASSIVE, true)
	head.clip_text = true
	head.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	head.custom_minimum_size = Vector2(60, 0)
	var e := _label(t, fr(effect_text(id, power)), UiTheme.MIN_TEXT, TEXT)
	e.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	e.max_lines_visible = 3  # un effet déclenché long tient en trois lignes (le détail est dans la carte de la pièce)
	e.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	e.custom_minimum_size = Vector2(60, 0)


## Nombres à la française : « 1.5 » -> « 1,5 » (textes venus des armes et des sorts).
static func fr(s: String) -> String:
	return RegEx.create_from_string("(\\d)\\.(\\d)").sub(s, "$1,$2", true)


## Effet d'un passif à la puissance [param pw] (sans son nom) : « Rayon des zones +14 % », ou sa description.
static func effect_text(id: String, pw: float) -> String:
	var d := Boons.get_def(id)
	if d.is_empty():
		return id
	return Cards.total_text(d, pw) if not (d.get("stat", {}) as Dictionary).is_empty() else String(d.get("desc", ""))


## Bas d'une nouvelle pièce : le verrou à gauche, les paliers à venir à droite (infobulle).
static func _lock_line(v: VBoxContainer, item: Dictionary) -> void:
	var h := HBoxContainer.new()
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(h)
	var lock := _label(h, "🔒 Gardée à vie", UiTheme.MIN_TEXT, DIM)
	lock.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var up := int(item.get("upgrade", 0))
	var next: Array = Survivor.WAKE_AT.filter(func(at): return int(at) > up).map(func(at): return "+%d" % int(at))
	if not next.is_empty():
		_label(h, "Passifs à " + " ".join(PackedStringArray(next)), UiTheme.MIN_TEXT, DIM)


## Statistiques avant → après (les [param n] plus lourdes), ▲ vert / ▼ rouge, en lignes BBCode.
static func delta_lines(before: Dictionary, after: Dictionary, n: int) -> PackedStringArray:
	var out: PackedStringArray = []
	var a := Items.stats(before)
	var b := Items.stats(after)
	var rows: Array = Items.stat_rows(before)
	rows.sort_custom(func(x, y): return float(x.w) > float(y.w))
	for r in rows:
		if out.size() >= n:
			break
		var k := String(r.k)
		var x := float(a.get(k, 0.0))
		var y := float(b.get(k, x))
		if absf(y - x) < 0.0001:
			continue
		var pct: bool = k in Items.PERCENT_STATS
		var fx := ("%d %%" % roundi(x * 100.0)) if pct else Items.fmt_num(roundi(x))
		var fy := ("%d %%" % roundi(y * 100.0)) if pct else Items.fmt_num(roundi(y))
		var c := (GOOD if y > x else BAD).to_html(false)
		out.append("[color=#b4b0c8]%s[/color]  %s → [b][color=#%s]%s[/color][/b]  [color=#%s]%s[/color]" % [String(r.name), fx, c, fy, c, "▲" if y > x else "▼"])
	return out


# --- carte v2 (lot SVX-2, maquette v2_choix_carte.svg) : papier, une décision, quatre lignes au plus -------------------------
## Tons de la carte (clair, base, foncé) : rareté de la pièce, rareté de l'amélioration, « nouveau » (mandarine) pour un sort
## neuf, soleil pour une évolution (légendaire), lilas-gris pour une carte commune ou de repli.
static func tones_of(card: Dictionary) -> Array:
	var t := String(card.get("type", ""))
	var name := "commun"
	if card.has("item") and t in ["sv_piece", "sv_weapon"]:
		name = ["commun", "pomme", "lagon", "amethyste", "mandarine", "soleil"][clampi(int(card.item.get("rarity", 0)), 0, 5)]
	elif t in ["skill", "chain"]:
		name = "mandarine"
	elif t == "sv_evolution":
		name = "soleil"
	elif card.has("tier"):
		name = {"common": "commun", "rare": "lagon", "epic": "amethyste", "legendary": "soleil"}.get(String(card.tier), "commun")
	if name == "commun":
		return [UiTheme.color("rarete.commun.clair", Color("ece8f4")), UiTheme.color("rarete.commun.base", Color("c9c3d6")), UiTheme.color("rarete.commun.fonce", Color("8e86a6"))]
	return UiTheme.tones(name)


## Étiquette autocollante de famille (« PIÈCE », « ARME », « SORT », « ÉVOLUTION », « BONUS »).
static func family_label(card: Dictionary) -> String:
	match String(card.get("type", "")):
		"sv_piece", "sv_piece_up":
			return "PIÈCE"
		"sv_weapon", "sv_weapon_up":
			return "ARME"
		"skill", "chain", "upgrade":
			return "SORT"
		"sv_evolution":
			return "ÉVOLUTION"
	return "BONUS"


## Bandeau de la carte : « Tête · Épique », « Sort · Nouveau ! », « Arme · amélioration rare ».
static func band_text(card: Dictionary) -> String:
	var t := String(card.get("type", ""))
	match t:
		"skill", "chain":
			return "Sort · Nouveau !"  # (un enchaînement le dit dans la carte : « Enchaînement de … »)
		"upgrade":
			return "Sort · %s" % String(Cards.tier(String(card.get("tier", "common"))).name)
		"sv_evolution":
			return "Évolution · Légendaire"
	return header(card)


## Passifs que la carte apporte : [{id, power}] (passif fixe d'une pièce, passifs de palier d'une amélioration).
static func card_passives(card: Dictionary) -> Array:
	var t := String(card.get("type", ""))
	if t in ["sv_piece", "sv_weapon"] and card.has("item"):
		return card.item.get("sv_passives", [])
	if t in ["sv_piece_up", "sv_weapon_up"]:
		return card.get("offer", {}).get("passives", [])
	return []


## Indice d'évolution de la carte (« ◆ Évolution : + Braise → Lame du phénix », « ◆ Évolution prête : … ») ; "" sinon.
## Une évolution s'ouvre quand tous ses passifs requis sont portés à pleine puissance (SurvivorCards.evolutions_open).
static func evo_hint(card: Dictionary) -> String:
	if String(card.get("type", "")) == "sv_evolution":
		return ""
	for b in card_passives(card):
		var bid := String(b.id)
		for d in Boons.all():
			var req: Array = d.get("requires", [])
			if not bid in req or Run.passives.has(String(d.id)) or ("evo:" + String(d.id)) in Run.banned:
				continue
			var missing: Array = []
			for r in req:
				var pw := float(Run.passive_power.get(String(r), 0.0)) + (float(b.get("power", 1.0)) if String(r) == bid else 0.0)
				if pw < 1.0 - 0.001:
					missing.append(String(Boons.get_def(String(r)).get("name", r)))
			if missing.is_empty():
				return "◆ Évolution prête : %s" % String(d.name)
			return "◆ Évolution : + %s → %s" % [" + ".join(PackedStringArray(missing)), String(d.name)]
	return ""


## Évolutions en route (un passif requis au moins porté) : [{id, name, missing: [noms]}] ; prêtes : missing vide.
static func evo_paths() -> Array:
	var out: Array = []
	for d in Boons.all():
		var req: Array = d.get("requires", [])
		if req.is_empty() or Run.passives.has(String(d.id)) or ("evo:" + String(d.id)) in Run.banned:
			continue
		var have := req.filter(func(r): return float(Run.passive_power.get(String(r), 0.0)) > 0.0)
		if have.is_empty():
			continue
		var missing: Array = req.filter(func(r): return float(Run.passive_power.get(String(r), 0.0)) < 1.0 - 0.001) \
			.map(func(r): return String(Boons.get_def(String(r)).get("name", r)))
		out.append({"id": String(d.id), "name": String(d.name), "missing": missing})
	return out


## Synergie écrite sur la carte (pastille verte) : évolution, sinon panoplie poursuivie (« ◆ Tempête 3 / 5 : bonus ! »).
static func synergy(card: Dictionary) -> String:
	var evo := evo_hint(card)
	if evo != "":
		return evo
	if String(card.get("type", "")) in ["sv_piece", "sv_weapon"] and card.has("item"):
		var sid := String(card.item.get("set", ""))
		if sid != "" and sid in SurvivorPool.sets():
			var worn := int(Items.set_counts(Profile.equipped).get(sid, 0))
			if worn >= 1:
				var n := worn + 1
				return "◆ %s %d / 5%s" % [SurvivorPool.panoply_name(sid), n, " : bonus !" if n in Items.set_tiers(sid) else ""]
	return ""


## Contenu compact d'une carte v2 dans [param v] (sous le bandeau dessiné par SurvivorPicker) : icône et nom, LE chiffre de
## la décision, l'aléa encadré (passif tiré, effet ★, sort), deux lignes au plus, la synergie, le pied « Maj : tout le détail ».
static func build_v2(v: VBoxContainer, card: Dictionary, tones: Array) -> void:
	var t := String(card.get("type", ""))
	var ink := UiTheme.color("encre.700")
	var dim := UiTheme.color("encre.300")
	match t:
		"sv_piece", "sv_weapon":
			var item: Dictionary = card.item
			var head := _icon_row_v2(v, String(item.get("icon", "")), 58, tones)
			_name_v2(head, Items.card_name(item), Items.color_of(item))
			var st := Items.stats(item)
			var k := Items.main_stat_key(item, st)
			if k != "":
				var pct: bool = k in Items.PERCENT_STATS
				_big_v2(head, ("%d %%" % roundi(float(st[k]) * 100.0)) if pct else Items.fmt_num(roundi(float(st[k]))), String(Items.STAT_NAMES.get(k, k)))
			if t == "sv_weapon":
				var s := WeaponAttacks.spec_for(item)
				_box_v2(v, String(s.name), fr(String(s.desc)), "lagon")
				if s.has("sig"):
					_line_v2(v, "★ À +4 : " + fr(WeaponAttacks.sig_text(s)), UiTheme.color("bonbon.mandarine.fonce"), 2)
			else:
				for p in item.get("sv_passives", []):
					_box_v2(v, "Passif · " + String(Boons.get_def(String(p.id)).get("name", p.id)), fr(effect_text(String(p.id), float(p.get("power", 1.0)))), "soleil")
				_line_v2(v, _stats_text(item, 2), ink, 1)
			var jet := "★ Jet parfait" if SurvivorGear.is_perfect(item) else "Jet %d / %d" % [roundi(float(item.get("quality", 1.0)) * 100.0), roundi(Survivor.rule("perfect_quality") * 100.0)]
			_line_v2(v, jet, UiTheme.color("bonbon.soleil.fonce") if SurvivorGear.is_perfect(item) else dim, 1)
		"sv_piece_up", "sv_weapon_up":
			var slot := String(card.slot)
			var it: Dictionary = Profile.equipped.get(slot, {})
			var offer: Dictionary = card.get("offer", {})
			var from := int(offer.get("from", it.get("upgrade", 0)))
			var to := int(offer.get("to", from + Survivor.UP_STEP))
			var head2 := _icon_row_v2(v, String(it.get("icon", card.get("icon", ""))), 50, tones)
			_name_v2(head2, Items.card_name(it).trim_prefix("+%d " % from), Items.color_of(it))
			_big_v2(head2, "+%d → +%d" % [from, to], "")
			var g := Segments.new(Items.MAX_UPGRADE, from, to - from, Survivor.WAKE_AT, tones[1])
			g.labels = true
			g.paper = true
			v.add_child(g)
			var gained: Array = offer.get("passives", [])
			for p in gained:
				_box_v2(v, "Nouveau passif · " + String(Boons.get_def(String(p.id)).get("name", p.id)), fr(effect_text(String(p.id), float(p.power))), "soleil")
			if gained.is_empty() and slot == "weapon" and offer.has("auto"):
				var auto := WeaponAttacks.upgrade_lines(WeaponAttacks.spec_for(it), Run.weapon_ups.get("weapon", {}), offer.auto)
				if not auto.is_empty():
					_box_v2(v, "Auto-attaque", fr(_plain(String(auto[0]))), "lagon")
			var after := it.duplicate(true)
			after["upgrade"] = to
			after["quality"] = minf(float(it.get("quality", 1.0)) + float(SurvivorCards.QUALITY_UP.get(String(card.get("tier", "common")), 0.0)), Survivor.rule("perfect_quality"))
			for l in delta_lines_v2(it, after, 1 if gained.size() > 1 else 2):
				_rich_v2(v, l)
			if gained.is_empty():
				var next: Array = Survivor.WAKE_AT.filter(func(at): return int(at) > to)
				_line_v2(v, ("Prochain passif à +%d" % int(next[0])) if not next.is_empty() else "Passifs au complet", dim, 1)
		"skill", "chain":
			var d := Run.skill_def(int(card.id))
			var head3 := _icon_row_v2(v, String(d.get("icon", card.get("icon", ""))), 58, tones)
			_name_v2(head3, String(d.get("name", card.get("title", ""))), ink)
			_big_v2(head3, "Niv. 1 / %d" % int(Cards.rules().max_rank), "")
			_box_v2(v, "", fr(String(d.get("desc", ""))), "lagon", 3)
			if t == "chain":
				var slot_i := int(card.get("slot", 0))
				var first := Run.skill_def(int(Run.skills[slot_i].id)) if slot_i < Run.skills.size() else {}
				_line_v2(v, "Enchaînement de « %s » (case %d)" % [String(first.get("name", "?")), slot_i + 1], dim, 2)
			else:
				_line_v2(v, "Case %d · recharge %s s" % [Run.skills.size() + 1, Cards._num(float(d.get("cooldown", 0.0)))], dim, 1)
		"upgrade":
			var id := int(card.id)
			var d2 := Run.skill_def(id)
			var cur := Run.skill_entry(id)
			var rank := int(cur.get("rank", Run.skill_rank(id)))
			var to2 := int(card.get("rank_to", rank + 1))
			var head4 := _icon_row_v2(v, String(d2.get("icon", card.get("icon", ""))), 54, tones)
			_name_v2(head4, String(d2.get("name", card.get("title", ""))), ink)
			_big_v2(head4, "Niv. %d → %d" % [rank, to2], "")
			var up: Dictionary = card.get("up", {})
			_box_v2(v, "Ce niveau", _plain("  ·  ".join(level_lines(up))), "lagon", 2)
			_line_v2(v, "Total : " + _plain(total_text(cur, up)), ink, 2)
		"sv_evolution":
			var d3 := Boons.get_def(String(card.id))
			var head5 := _icon_row_v2(v, String(card.get("icon", "")), 58, tones)
			_name_v2(head5, String(card.get("title", "")), ink)
			_big_v2(head5, "Évolution", "")
			_box_v2(v, "", fr(String(d3.get("desc", ""))), "amethyste", 4)
			var req: Array = (d3.get("requires", []) as Array).map(func(r): return String(Boons.get_def(String(r)).get("name", r)))
			_line_v2(v, "Grâce à : " + ", ".join(PackedStringArray(req)), dim, 2)
		_:
			var head6 := _icon_row_v2(v, String(card.get("icon", "")), 54, tones)
			_name_v2(head6, String(card.get("title", "")), ink)
			_line_v2(v, fr(_plain(String(card.get("desc", "")))), ink, 3)
	var syn := synergy(card)
	if syn != "":
		_pill_v2(v, syn, "pomme")
	var fill := Control.new()
	fill.size_flags_vertical = Control.SIZE_EXPAND_FILL
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(fill)
	var foot := "Maj : tout le détail" + (" · 🔒 gardée à vie" if t in ["sv_piece", "sv_weapon"] else "")
	var fl := _line_v2(v, foot, dim, 1)
	fl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fl.add_theme_font_size_override("font_size", UiTheme.MIN_TEXT - 1)


## Texte BBCode → texte simple (« [b]+18 %[/b] » → « +18 % »).
static func _plain(bb: String) -> String:
	return RegEx.create_from_string("\\[[^\\]]*\\]").sub(bb, "", true)


## Les [param n] statistiques secondaires les plus lourdes en une ligne (« Force 17 · PV 405 »).
static func _stats_text(item: Dictionary, n: int) -> String:
	var st := Items.stats(item)
	var main := Items.main_stat_key(item, st)
	var rows: Array = Items.stat_rows(item).filter(func(r): return String(r.k) != main)
	rows.sort_custom(func(a, b): return float(a.w) > float(b.w))
	return "  ·  ".join(PackedStringArray(rows.slice(0, n).map(func(r): return "%s %s" % [String(r.name), String(r.val)])))


## Statistiques avant → après sur papier (gain pomme foncé, perte fraise foncé).
static func delta_lines_v2(before: Dictionary, after: Dictionary, n: int) -> PackedStringArray:
	var out: PackedStringArray = []
	var good := UiTheme.color("texte.gain-sur-papier").to_html(false)
	var bad := UiTheme.color("texte.perte-sur-papier").to_html(false)
	var dim := UiTheme.color("encre.300").to_html(false)
	for l in delta_lines(before, after, n):
		out.append(l.replace("#b4b0c8", "#" + dim).replace("#" + GOOD.to_html(false), "#" + good).replace("#" + BAD.to_html(false), "#" + bad))
	return out


static func _icon_row_v2(v: VBoxContainer, icon: String, px: int, tones: Array) -> VBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(h)
	var frame := PanelContainer.new()  # case d'objet : deux tons de la rareté, contour d'encre (BIBLE § 5)
	var sb := UiTheme.sticker("papier", {"shadow": 3, "radius": 12, "gloss": true, "pad": Vector2(3, 3)})
	sb.light = (tones[0] as Color)
	sb.fill = (tones[1] as Color)
	sb.dark = (tones[2] as Color)
	sb.content_margin_top = 3
	sb.content_margin_bottom = 6
	frame.add_theme_stylebox_override("panel", sb.refresh())
	frame.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(frame)
	var tr := TextureRect.new()
	tr.texture = UiTheme.texture(icon) if icon != "" else null
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.custom_minimum_size = Vector2(px, px)
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(tr)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(col)
	return col


static func _ink(parent: Control, text: String, size: int, color: Color, font: Font) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_constant_override("outline_size", 0)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l


## Nom de la carte (deux lignes au plus, « … » au-delà), à l'encre teintée de la rareté.
static func _name_v2(parent: Control, text: String, col: Color) -> Label:
	var c := col
	if c.get_luminance() > 0.55:
		c = c.darkened(0.45)  # sur papier, les couleurs de rareté claires sont foncées (contraste)
	var l := _ink(parent, text, 17, c, UiTheme.bold_font())
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.max_lines_visible = 2
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	l.custom_minimum_size = Vector2(60, 0)
	return l


## Le chiffre de la décision, en grand (Mochiy), et sa légende.
static func _big_v2(parent: Control, value: String, caption: String) -> void:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(h)
	var b := _ink(h, value, 26, UiTheme.color("encre.700"), UiTheme.title_font())
	b.size_flags_vertical = Control.SIZE_SHRINK_END
	if caption != "":
		var c := _ink(h, caption, UiTheme.MIN_TEXT, UiTheme.color("encre.300"), UiTheme.bold_font())
		c.size_flags_vertical = Control.SIZE_SHRINK_END
		c.clip_text = true
		c.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL


## Encadré de l'aléa (BIBLE § 6) : fond bonbon clair [param tone], contour d'encre ; [param head] en gras, [param body]
## sur [param lines] lignes au plus.
static func _box_v2(v: VBoxContainer, head: String, body: String, tone: String, lines := 2) -> void:
	var box := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = (UiTheme.tones(tone)[0] as Color).lerp(Color.WHITE, 0.35)
	sb.border_color = UiTheme.color("encre.700")
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(10)
	sb.anti_aliasing = true
	sb.content_margin_left = 9
	sb.content_margin_right = 9
	sb.content_margin_top = 4
	sb.content_margin_bottom = 5
	box.add_theme_stylebox_override("panel", sb)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(box)
	var c := VBoxContainer.new()
	c.add_theme_constant_override("separation", 0)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(c)
	if head != "":
		var h := _ink(c, head, UiTheme.MIN_TEXT, UiTheme.color("encre.700"), UiTheme.bold_font())
		h.clip_text = true
		h.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		h.custom_minimum_size = Vector2(40, 0)
	if body != "":
		var b := _ink(c, body, UiTheme.MIN_TEXT, UiTheme.color("encre.700"), UiTheme.body_font())
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.max_lines_visible = lines
		b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		b.custom_minimum_size = Vector2(40, 0)


## Ligne simple à l'encre (au plus [param lines] lignes).
static func _line_v2(v: Control, text: String, color: Color, lines := 1) -> Label:
	var l := _ink(v, text, UiTheme.MIN_TEXT, color, UiTheme.label_font())
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.max_lines_visible = lines
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	l.custom_minimum_size = Vector2(40, 0)
	return l


static func _rich_v2(v: Control, bb: String) -> RichTextLabel:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.scroll_active = false
	r.autowrap_mode = TextServer.AUTOWRAP_OFF
	r.add_theme_font_override("normal_font", UiTheme.label_font())
	r.add_theme_font_override("bold_font", UiTheme.number_font())
	r.add_theme_font_size_override("normal_font_size", UiTheme.MIN_TEXT)
	r.add_theme_font_size_override("bold_font_size", UiTheme.MIN_TEXT + 1)
	r.add_theme_color_override("default_color", UiTheme.color("encre.700"))
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.text = fr(bb)
	v.add_child(r)
	return r


## Pastille de synergie (bonbon [param tone], texte blanc contouré d'encre).
static func _pill_v2(v: Control, text: String, tone: String) -> void:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = UiTheme.tones(tone)[2] as Color
	sb.border_color = UiTheme.color("encre.700")
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(11)
	sb.anti_aliasing = true
	sb.content_margin_left = 9
	sb.content_margin_right = 9
	sb.content_margin_top = 2
	sb.content_margin_bottom = 3
	p.add_theme_stylebox_override("panel", sb)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(p)
	var l := _ink(p, text, UiTheme.MIN_TEXT, Color.WHITE, UiTheme.bold_font())
	l.add_theme_constant_override("outline_size", 4)
	l.add_theme_color_override("font_outline_color", UiTheme.color("encre.700"))
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.max_lines_visible = 2
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	l.custom_minimum_size = Vector2(40, 0)


## Aperçu des statistiques du héros si la carte est prise : [[libellé, avant, après]] (Attaque, Vie, Défense, Critique).
## Pièces et améliorations : l'équipement est échangé un instant (Profile.equipment_stats, bonus de panoplie compris) et la
## différence passe par les formules du héros (attributs, % des passifs) ; le reste des cartes ne change rien ici.
static func hero_preview(card: Dictionary, p: Player) -> Array:
	if p == null:
		return []
	var mag := String(Run.class_data().get("dmg_type", "phys")) in ["mag", "magic"]
	var base := {"Attaque": p.matk if mag else p.atk, "Vie": p.max_hp, "Défense": p.defense, "Critique": p.mcrit if mag else p.crit}
	var delta := {"Attaque": 0.0, "Vie": 0.0, "Défense": 0.0, "Critique": 0.0}
	var t := String(card.get("type", ""))
	var slot := ""
	var after: Dictionary = {}
	if t in ["sv_piece", "sv_weapon"] and card.has("item"):
		slot = String(card.get("slot", card.item.get("slot", "")))
		after = card.item
	elif t in ["sv_piece_up", "sv_weapon_up"]:
		slot = String(card.slot)
		var it: Dictionary = Profile.equipped.get(slot, {})
		if not it.is_empty():
			after = it.duplicate(true)
			after["upgrade"] = int(card.get("offer", {}).get("to", it.get("upgrade", 0)))
			after["quality"] = minf(float(it.get("quality", 1.0)) + float(SurvivorCards.QUALITY_UP.get(String(card.get("tier", "common")), 0.0)), Survivor.rule("perfect_quality"))
	if slot != "" and not after.is_empty():
		var eq0 := Profile.equipment_stats()
		var had := Profile.equipped.has(slot)
		var saved: Dictionary = Profile.equipped.get(slot, {})
		Profile.equipped[slot] = after
		var eq1 := Profile.equipment_stats()
		if had:
			Profile.equipped[slot] = saved
		else:
			Profile.equipped.erase(slot)
		var ps := Run.passive_stats()
		var dd := func(k: String) -> float: return float(eq1.get(k, 0.0)) - float(eq0.get(k, 0.0))
		var da := {}
		for a in Items.ATTRIBUTES:
			da[a] = dd.call(a) * (1.0 + float(ps.get(a + "_pct", 0.0)))
		delta["Vie"] = (float(da.str) * 2.0 + float(da.wis) * 1.5) * (1.0 + float(ps.get("hp_pct", 0.0)) + float(eq1.get("hp_pct", 0.0))) + dd.call("hp")
		if mag:
			delta["Attaque"] = (dd.call("matk") + float(da.int) * 0.6) * (1.0 + float(ps.get("atk_pct", 0.0)) + float(ps.get("matk_pct", 0.0)))
			delta["Critique"] = dd.call("mcrit") + float(da.lck) * 0.0012 + float(da.wis) * 0.0004
		else:
			delta["Attaque"] = (dd.call("patk") + float(da.str) * 0.6) * (1.0 + float(ps.get("atk_pct", 0.0)))
			delta["Critique"] = dd.call("crit") + float(da.lck) * 0.0012 + float(da.agi) * 0.0004
		delta["Défense"] = (dd.call("def") + float(da.str) * 0.25) * (1.0 + float(ps.get("def_pct", 0.0)))
	var out: Array = []
	for k in ["Attaque", "Vie", "Défense", "Critique"]:
		var pct: bool = k == "Critique"
		var b := float(base[k])
		var a := b + float(delta[k])
		var fb := ("%d %%" % roundi(b * 100.0)) if pct else Items.fmt_num(roundi(b))
		var fa := ("%d %%" % roundi(a * 100.0)) if pct else Items.fmt_num(roundi(a))
		out.append([k, fb, fa if fa != fb else ""])
	return out


# --- jauges -----------------------------------------------------------------------------------------------------------
## Jauge en segments : [member filled] acquis, [member gain] apportés par la carte (surlignés), losanges sur [member marks]
## (paliers +6 / +8 / +10 d'une pièce, niveaux 5 et 10 d'un sort) ; [member labels] : « +6 » sous les losanges.
class Segments extends Control:
	var total := 10
	var filled := 0
	var gain := 0
	var marks: Array = []
	var color := UiTheme.GOLD
	var labels := false
	var paper := false  # (carte v2, lot SVX-2) chiffres à l'encre sur papier

	func _init(t: int, f: int, g: int, m: Array, c: Color) -> void:
		total = maxi(t, 1)
		filled = f
		gain = g
		marks = m
		color = c
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		custom_minimum_size = Vector2(0, 30 if labels else 16)

	func _ready() -> void:
		custom_minimum_size = Vector2(0, 32 if labels else 16)
		process_mode = Node.PROCESS_MODE_ALWAYS  # (le choix de cartes met le jeu en pause)
		set_process(gain > 0)

	func _draw() -> void:
		var gap := 3.0
		var sw := (size.x - gap * (total - 1)) / total
		var font := UiTheme.bold_font()
		var t := Time.get_ticks_msec() / 1000.0
		for i in total:
			var n := i + 1
			var r := Rect2(i * (sw + gap), 4.0, sw, 9.0)
			var c := SurvivorCardView.TRACK
			if n <= filled:
				c = UiTheme.GOLD.darkened(0.1)
			elif n <= filled + gain:
				c = SurvivorCardView.GOOD.lerp(Color.WHITE, 0.15 + 0.15 * sin(t * 5.0))
			draw_rect(r, c)
			draw_rect(r, Color(0, 0, 0, 0.45), false, 1.0)
			if n in marks:
				var reached := n <= filled + gain
				HudWidgets.diamond(self, Vector2(r.get_center().x, r.position.y + r.size.y * 0.5), 6.0, Color(0.06, 0.04, 0.1))
				HudWidgets.diamond(self, Vector2(r.get_center().x, r.position.y + r.size.y * 0.5), 4.5, UiTheme.GOLD if reached else Color(0.55, 0.5, 0.68))
				if labels:
					var s := "+%d" % n
					var w := font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
					var lc := (UiTheme.color("encre.700") if reached else UiTheme.color("encre.300")) if paper else (UiTheme.GOLD if reached else Color(0.7, 0.68, 0.8))
					draw_string(font, Vector2(r.get_center().x - w * 0.5, 29.0), s, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, lc)

	func _process(_delta: float) -> void:
		queue_redraw()  # le gain pulse doucement


## Barre simple (jet de qualité).
class Bar extends Control:
	var ratio := 0.0
	var color := UiTheme.GOLD

	func _init() -> void:
		custom_minimum_size = Vector2(60, 10)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		draw_rect(r, SurvivorCardView.TRACK)
		draw_rect(Rect2(r.position, Vector2(r.size.x * ratio, r.size.y)), color)
		for k in range(1, 4):
			draw_line(Vector2(r.size.x * k / 4.0, 0.0), Vector2(r.size.x * k / 4.0, r.size.y), Color(0, 0, 0, 0.5), 1.0)
		draw_rect(r, Color(0, 0, 0, 0.6), false, 1.0)
