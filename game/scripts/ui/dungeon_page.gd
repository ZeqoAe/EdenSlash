class_name DungeonPage
extends RefCounted
## Page Donjons du lobby, v2 (lot DNG-2, backlog BM-DNG P0-8 ; maquette conception/benchmark/donjons_maquettes/v2_selection_donjon.svg),
## dans la DA « autocollant manga » (UiTheme v2). Le joueur choisit son donjon d'après la pièce qu'il cherche, la panoplie ou les
## mécaniques du boss : 48 donjons (un par boss de la bibliothèque, 6 par zone, passe M2). De haut en bas :
##   - la fiche du boss choisi : médaillon (rendu du modèle, BossPortrait) sur la couleur de sa famille, nom, titre et niveau,
##     sa phrase, victoires, meilleurs temps (BestTimes) et plan ;
##   - ses mécaniques en pastilles (icône du jeu, nom, conseil d'entrée ; le conseil après chute en infobulle) ;
##   - la difficulté en onglets nets (actif mandarine, verrouillé tramé avec sa condition), la jauge de PE et l'estimation
##     (DifficultyPanel), les records de cette difficulté ;
##   - le butin en cases (emplacements de la panoplie, les pièces déjà possédées cochées, le plan « garanti 1re fois ») ;
##   - les filtres et la liste par zone : tuiles avec médaillon, emplacements, familles de mécaniques et médailles N / H / M ;
##   - les alliés IA, puis le bouton épinglé « Entrer : … » (Tower.start_dungeon avec le boss choisi).
## État gardé entre deux ouvertures (sel, filtres).

static var sel := ""  # boss (donjon) choisi
static var f_slot := ""
static var f_arch := ""
static var f_family := ""

const SLOT_ORDER := ["weapon", "head", "chest", "legs", "gloves", "boots", "back", "necklace", "ring"]
const ARCH_ORDER := ["storm", "frost", "blood", "falcon", "phoenix", "wind", "salvo", "rampart"]
const CARD_W := 270.0
const PE_LOW := "Puissance d'équipement insuffisante"  # (même phrase que le lobby)
const FAR_NORMAL := "Trop faible ici : essaie d'abord une zone plus basse."
## Médailles des difficultés (tuiles de la liste) : Normal, Héroïque, Mythique.
const MEDALS := [["N", "pomme"], ["H", "soleil"], ["M", "mandarine"]]
const DIFF_TONE := ["lagon", "amethyste", "mandarine"]

static var cards: Array = []  # (tests) tuiles de la liste, dans l'ordre affiché
static var diff_tabs: Array = []  # (tests) onglets de difficulté
static var loot_cells: Array = []  # (tests) cases du butin


## Remplit la page (panneau défilant [code]lobby._sub[/code], bouton épinglé).
static func fill(lobby) -> void:
	var sub: VBoxContainer = lobby._sub
	lobby._activity_head("dungeon")
	if sel == "" or not BossLibrary.has(sel):
		var open := Dungeons.catalog({"open": true})
		sel = String(open[0]) if not open.is_empty() else BossLibrary.zone_boss(String(Dungeons.zone_ids()[0]))
	var zid := Dungeons.boss_zone(sel)
	lobby._dg_zone = zid
	var diff := int(lobby._dg_diff)
	var is_open := Dungeons.is_open(zid)
	sub.add_child(_hero(sel, zid, diff))
	# --- mécaniques ---------------------------------------------------------------------------
	lobby._section("Mécaniques", "Le conseil de chaque mécanique ; au survol, ce qu'il faut retenir après une chute.")
	sub.add_child(_mechanics(sel))
	# --- difficulté ---------------------------------------------------------------------------
	lobby._section("Difficulté")
	sub.add_child(_diff_tabs(lobby, zid, diff))
	# lot A2 : PE requise (Héroïque, Mythique) ou conseillée (Normal), estimation et récompenses, comme la Ruée et le Siège
	DifficultyPanel.add(sub, Dungeons.power_required(zid, diff), Dungeons.advised(zid, diff), rewards(sel, diff),
		FAR_NORMAL if diff == 0 else "", Dungeons.level(zid, diff))
	lobby._pe_next(zid, false)
	var rec := records_line(sel, diff)
	if rec != "":
		_line(sub, rec, UiTheme.MUTED)
	# --- butin --------------------------------------------------------------------------------
	lobby._section("Butin", "Chaque victoire : un coffre de trois pièces au choix parmi ces emplacements, à la panoplie du donjon, plus des matières et des cristaux. Sans limite : refais-le autant que tu veux.")
	sub.add_child(_loot(sel))
	# --- filtres et liste -----------------------------------------------------------------------
	lobby._section("Je cherche", "Filtre les donjons d'après la pièce, la panoplie ou les mécaniques du boss.")
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 6)
	sub.add_child(bar)
	_filter(lobby, bar, ["Toutes les pièces"] + SLOT_ORDER.map(func(s): return String(Items.SLOT_NAMES.get(s, s))), [""] + SLOT_ORDER, f_slot,
		func(v): f_slot = v)
	_filter(lobby, bar, ["Toutes les panoplies"] + ARCH_ORDER.map(func(a): return _arch_name(a)), [""] + ARCH_ORDER, f_arch, func(v): f_arch = v)
	var fams: Array = BossBricks.FAMILIES.keys()
	_filter(lobby, bar, ["Toutes les mécaniques"] + fams.map(func(f): return String(BossBricks.FAMILIES[f])), [""] + fams, f_family,
		func(v): f_family = v)
	var ids := Dungeons.catalog({"slot": f_slot, "archetype": f_arch, "family": f_family})
	cards = []
	if ids.is_empty():
		_line(sub, "Aucun donjon ne répond à ces filtres.", UiTheme.MUTED)
	var shut := 0
	for z in Dungeons.zone_ids():
		var in_zone := ids.filter(func(id): return Dungeons.boss_zone(String(id)) == String(z))
		if in_zone.is_empty():
			continue
		var zopen := Dungeons.is_open(String(z))
		if not zopen:
			shut += in_zone.size()
		sub.add_child(_zone_head(String(z), in_zone))
		var grid := GridContainer.new()
		grid.columns = 2
		grid.add_theme_constant_override("h_separation", 8)
		grid.add_theme_constant_override("v_separation", 8)
		sub.add_child(grid)
		for id in in_zone:
			var c := _card(lobby, String(id), diff)
			grid.add_child(c)
			cards.append(c)
	if shut > 0 and shut < ids.size():
		_line(sub, "Les autres s'ouvrent en battant les boss de la Survie.", UiTheme.MUTED)
	var cnt := Encounters.counts()
	var plans := BossLibrary.ids().filter(func(b): return not Dungeons.has_plan(String(b))).size()
	var foot := _line(sub, "%d boss · %d / %d vaincus · %d plans à trouver" % [int(cnt.get("total", 48)), int(cnt.get("won", 0)), int(cnt.get("total", 48)), plans], UiTheme.MUTED)
	foot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lobby._dungeon_allies_picker()
	# --- lancement ------------------------------------------------------------------------------
	var go := MenuWidgets.gold_button("Entrer : %s" % Dungeons.dungeon_name(sel), 22, Vector2(0, 58))
	go.disabled = not (is_open and Dungeons.power_ok(zid, diff))
	go.pressed.connect(func(): lobby._start_dungeon())
	lobby._pin_go(go, ("" if Dungeons.power_ok(zid, diff) else PE_LOW) if is_open else Dungeons.condition(zid))


## Récompenses courtes du donjon de [param bid] en difficulté [param diff] : cristaux, coffre de pièces (et d'équipement en
## Mythique), plan à la 1re victoire (Dungeons.reward).
static func rewards(bid: String, diff: int) -> Array:
	var out: Array = ["%d cristaux" % ActivityLoot.dungeon_crystals(diff), "3 pièces au choix"]
	if diff >= 2:
		out.append("coffre d'équipement")
	if not Dungeons.has_plan(bid):
		out.append("son plan de donjon")
	return out


## « Record à cette difficulté : boss 1:58 · donjon 4:12 » ("" : aucun temps encore).
static func records_line(bid: String, diff: int) -> String:
	var b := BestTimes.best(BestTimes.boss_key("dungeon", bid, diff))
	var f := BestTimes.best(BestTimes.dungeon_key(bid, diff))
	var parts: Array = []
	if b > 0.0:
		parts.append("boss %s" % BestTimes.fmt(b))
	if f > 0.0:
		parts.append("donjon %s" % BestTimes.fmt(f))
	return ("Tes records en %s : %s" % [String(Dungeons.DIFF_NAMES[diff]), " · ".join(parts)]) if not parts.is_empty() else ""


static func _arch_name(a: String) -> String:
	return String(Items.SETS.get(a, {}).get("name", a))


static func _line(parent: Control, text: String, color: Color) -> Label:
	var l := Hud._label(parent, text, 14, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


static func _ink_label(parent: Control, text: String, size: int, bold := false, muted := false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", UiTheme.bold_font() if bold else UiTheme.body_font())
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", UiTheme.color("encre.300") if muted else UiTheme.color("encre.700"))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l


## Texte blanc contouré d'encre (sur un bonbon : jamais de blanc sans contour, bible § 3).
static func _white(parent: Control, text: String, size: int, title := false) -> Label:
	var l := Label.new()
	l.text = text
	if title:
		UiTheme.title(l, size, Color.WHITE)
	else:
		l.add_theme_font_override("font", UiTheme.bold_font())
		l.add_theme_font_size_override("font_size", size)
		l.add_theme_color_override("font_color", Color.WHITE)
		l.add_theme_constant_override("outline_size", UiTheme.outline_for(size) + 1)
		l.add_theme_color_override("font_outline_color", UiTheme.color("encre.700"))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l


## Fiche du boss choisi : médaillon sur la couleur de sa famille, nom, titre et niveau, phrase, victoires, temps et plan.
static func _hero(bid: String, zid: String, diff: int) -> Control:
	var fam := BossLibrary.families_of(bid)
	var tone := BossBar.family_tone(String(fam[0])) if not fam.is_empty() else "amethyste"
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UiTheme.sticker(tone, {"radius": 16, "shadow": 5, "pad": Vector2(12, 10), "cel_top": 0.1, "cel_bottom": 0.3}))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 14)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(h)
	var por := BossPortrait.for_boss(bid, 112, false)
	por.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(por)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(v)
	var def := BossLibrary.get_def(bid)
	var nm := _white(v, BossLibrary.short_name(bid), 30, true)
	nm.clip_text = true
	nm.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	var title := String(def.get("title", ""))
	_white(v, ("%s · niveau %d" % [title, Dungeons.level(zid, diff) + 1]) if title != "" else "Niveau %d · %s" % [Dungeons.level(zid, diff) + 1, Dungeons.name_of(zid)], 16)
	var intro := _white(v, "« %s »" % BossLibrary.intro(bid), 14)
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	intro.custom_minimum_size.x = 300
	var wins := Encounters.wins(bid)
	var best := 0.0
	for d in Dungeons.DIFF_NAMES.size():
		var t := BestTimes.best(BestTimes.boss_key("dungeon", bid, d))
		if t > 0.0 and (best <= 0.0 or t < best):
			best = t
	var facts: Array = ["vaincu %d fois" % wins if wins > 0 else "jamais vaincu",
		"meilleur temps %s" % BestTimes.fmt(best) if best > 0.0 else "aucun temps",
		"plan obtenu" if Dungeons.has_plan(bid) else "plan à obtenir"]
	var f := _white(v, " · ".join(facts).left(1).to_upper() + " · ".join(facts).substr(1), 14)
	f.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	f.custom_minimum_size.x = 300
	return p


## Les mécaniques du boss en pastilles : icône du jeu sur la couleur de la famille, nom, conseil d'entrée (le conseil après
## chute en infobulle). Deux par ligne.
static func _mechanics(bid: String) -> Control:
	var g := GridContainer.new()
	g.columns = 2
	g.add_theme_constant_override("h_separation", 8)
	g.add_theme_constant_override("v_separation", 8)
	for t in BossLibrary.brick_types(bid):
		g.add_child(mech_card(String(t)))
	if not BossLibrary.MYTHIC_EXTRA in BossLibrary.brick_types(bid):
		g.add_child(mech_card(BossLibrary.MYTHIC_EXTRA, "en Mythique"))
	return g


## Pastille d'une mécanique : icône, nom (et [param tag] : « en Mythique »), conseil d'entrée ; infobulle : le conseil après chute.
static func mech_card(type: String, tag := "", seen := -1) -> PanelContainer:
	var p := PanelContainer.new()
	var unseen := seen == 0
	p.add_theme_stylebox_override("panel", UiTheme.sticker("gris" if unseen else "papier", {"radius": 14, "shadow": 3, "pad": Vector2(8, 6),
		"gloss": false, "cel_top": 0.0, "cel_bottom": 0.0, "trame": unseen, "ink": UiTheme.color("encre.300") if unseen else UiTheme.color("encre.700")}))
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p.custom_minimum_size = Vector2(250, 0)
	p.tooltip_text = HitLog.tip_for(type)
	p.mouse_filter = Control.MOUSE_FILTER_PASS
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(h)
	var c := BossBar.chip(type, 40)
	c.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if unseen:
		c.modulate = Color(1, 1, 1, 0.55)
	h.add_child(c)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(v)
	var n := _ink_label(v, BossBar.mech_name(type) + (" · " + tag if tag != "" else ""), 15, true, unseen)
	n.clip_text = true
	n.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	var hint := BossBricks.hint_of(type)
	if seen > 0:
		hint += " · vue %d fois" % seen
	elif unseen:
		hint = "pas encore vue : " + hint
	var hl := _ink_label(v, hint, UiTheme.MIN_TEXT, false, true)
	hl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return p


## Onglets de difficulté : l'actif mandarine (plus haut), les autres papier, un verrouillé tramé avec sa condition.
static func _diff_tabs(lobby, zid: String, diff: int) -> Control:
	var dr := HBoxContainer.new()
	dr.add_theme_constant_override("separation", 6)
	diff_tabs = []
	for i in Dungeons.DIFF_NAMES.size():
		var ok_pe := Dungeons.power_ok(zid, i)
		var on := i == diff
		var won := Dungeons.boss_cleared(sel, i) > 0
		var b := Button.new()
		b.text = ("🔒 " if not ok_pe else "") + "%s · %d" % [Dungeons.DIFF_NAMES[i], Dungeons.level(zid, i)] + (" ✔" if won else "")
		b.focus_mode = Control.FOCUS_NONE
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.size_flags_vertical = Control.SIZE_SHRINK_END
		b.custom_minimum_size = Vector2(0, 48 if on else 40)
		UiTheme.style_button(b, "mandarine" if on else ("papier" if ok_pe else "gris"), 17 if on else 15,
			{"radius": 12, "shadow": 4, "pad": Vector2(6, 4), "trame": not ok_pe})
		if not ok_pe and not on:
			b.add_theme_color_override("font_color", UiTheme.color("texte.desactive"))
		b.tooltip_text = Dungeons.power_text(zid, i)
		b.set_meta("diff", i)
		var di := i
		b.pressed.connect(func():
			lobby._dg_diff = di
			lobby._show_menu("dungeon"))
		dr.add_child(b)
		diff_tabs.append(b)
	return dr


## Le butin en cases : un emplacement par pièce de la panoplie (cochée si tu l'as déjà), le plan « garanti 1re fois ».
static func _loot(bid: String) -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	v.add_child(h)
	loot_cells = []
	var th := BossLibrary.loot(bid)
	var missing := Encounters.missing_slots(bid)
	for s in th.slots:
		var owned := not String(s) in missing
		var c := slot_cell(String(s), String(th.archetype), owned, 64)
		c.tooltip_text = "%s · panoplie %s%s" % [String(Items.SLOT_NAMES.get(s, s)), _arch_name(String(th.archetype)), " · déjà à toi" if owned else ""]
		h.add_child(c)
		loot_cells.append(c)
	var plan := plan_cell(not Dungeons.has_plan(bid), 64)
	h.add_child(plan)
	loot_cells.append(plan)
	var txt := VBoxContainer.new()
	txt.add_theme_constant_override("separation", 0)
	txt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	txt.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(txt)
	var a := Hud._label(txt, "3 pièces au choix, jamais en double", 15, UiTheme.TEXT)
	a.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var b := Hud._label(txt, missing_line(bid, missing, th.slots), UiTheme.MIN_TEXT, UiTheme.MUTED)
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return v


## « Gants déjà à toi : on te proposera la Tête », « Il te manque tout ici », « Panoplie complète ici ».
static func missing_line(_bid: String, missing: Array, slots: Array) -> String:
	if missing.is_empty():
		return "Panoplie complète ici : les coffres donnent de meilleures pièces."
	if missing.size() == slots.size():
		return "Rien de cette panoplie encore : chaque pièce te sera utile."
	var have := slots.filter(func(s): return not s in missing).map(func(s): return String(Items.SLOT_NAMES.get(s, s)))
	return "%s déjà à toi : on te proposera %s" % [" et ".join(have), " ou ".join(missing.map(func(s): return String(Items.SLOT_NAMES.get(s, s)).to_lower()))]


## Icône d'un emplacement de la panoplie [param arch] (une icône du jeu, toujours la même pour cette panoplie).
static func slot_icon(slot: String, arch: String) -> Texture2D:
	var k := absi(hash(arch + slot))
	var list: Array = Items.icons().get(slot, [])
	if not list.is_empty():
		return UiTheme.texture(String(list[k % list.size()]))
	var key := Items.default_weapon_type(Profile.selected_class) if slot == "weapon" else slot
	var eden: Array = GameData.eden_by_slot.get(key, [])
	if not eden.is_empty():
		var t := UiTheme.texture(String(eden[k % eden.size()].get("icon", "")))
		if t != null:
			return t
	return MenuWidgets.icon({"weapon": "weapon", "ring": "ring", "necklace": "jewel"}.get(slot, "equipment"))


## Case d'un emplacement : icône sur le bonbon de rareté (mythique), nom dessous, coche pomme si la pièce est déjà à toi.
static func slot_cell(slot: String, arch: String, owned: bool, px: float) -> Control:
	return cell(slot_icon(slot, arch), String(Items.SLOT_NAMES.get(slot, slot)), "mandarine", owned, px)


static func plan_cell(new_plan: bool, px: float) -> Control:
	var c := cell(ResourceHelp.icon("plan"), "Plan", "soleil", not new_plan, px)
	if new_plan:
		var tag := BossBar.pill("Garanti 1re fois", "mandarine", 12, -6.0)
		tag.position = Vector2(px * 0.3, -14)
		overlay(c).add_child(tag)
	c.tooltip_text = "Plan de donjon : garanti à la première victoire, puis fabriqué en insignes à l'Atelier." if new_plan else "Plan de donjon déjà obtenu."
	return c


## Case autocollante (bible § 5 : rayon 14, contour d'encre, deux tons, ombre dure) avec une icône et un nom.
static func cell(tex: Texture2D, label: String, tone: String, check: bool, px: float) -> Control:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UiTheme.sticker(tone, {"radius": 14, "shadow": 4, "pad": Vector2(4, 3)}))
	p.custom_minimum_size = Vector2(px, px)
	p.mouse_filter = Control.MOUSE_FILTER_PASS
	var ic := TextureRect.new()
	ic.texture = tex
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(ic)
	var l := Label.new()
	l.text = label
	l.add_theme_font_override("font", UiTheme.bold_font())
	l.add_theme_font_size_override("font_size", 12)
	l.add_theme_color_override("font_color", Color.WHITE)
	l.add_theme_constant_override("outline_size", 4)
	l.add_theme_color_override("font_outline_color", UiTheme.color("encre.700"))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(l)
	if check:
		var ck := Control.new()
		ck.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ck.size = Vector2(22, 22)
		ck.position = Vector2(px - 22, -10)
		ck.draw.connect(_draw_check.bind(ck))
		overlay(p).add_child(ck)
		p.set_meta("checked", true)
	return p


## Calque libre posé sur un conteneur (pastilles et coches qui débordent du cadre) : un conteneur place ses enfants, pas les
## enfants de ce calque. Repère : le coin haut gauche de la case (marges comprises).
static func overlay(parent: Container) -> Control:
	var o := Control.new()
	o.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(o)
	var sb := parent.get_theme_stylebox("panel") if parent is PanelContainer else null
	var holder := Control.new()  # recalé sur le cadre entier (le calque commence après la marge intérieure)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.set_anchors_preset(Control.PRESET_FULL_RECT)
	if sb != null:
		holder.offset_left = -sb.content_margin_left
		holder.offset_top = -sb.content_margin_top
		holder.offset_right = sb.content_margin_right
		holder.offset_bottom = sb.content_margin_bottom
	o.add_child(holder)
	return holder


## En-tête de zone de la liste : « Monts Calcaires · niv. 14 » et « 4 / 6 vaincus ».
static func _zone_head(zid: String, ids: Array) -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	var t := Hud._label(h, "%s · niv. %d" % [Dungeons.name_of(zid), Dungeons.level(zid, 0)], 15, UiTheme.color("papier.100"))
	t.add_theme_font_override("font", UiTheme.bold_font())
	var line := ColorRect.new()
	line.color = Color(UiTheme.MUTED, 0.35)
	line.custom_minimum_size = Vector2(0, 2)
	line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(line)
	var won := ids.filter(func(id): return Encounters.wins(String(id)) > 0).size()
	Hud._label(h, "%d / %d vaincus" % [won, ids.size()], UiTheme.MIN_TEXT, UiTheme.MUTED)
	return h


## Menu déroulant d'un filtre : [param labels] affichés, [param values] gardées ; [param set_v] range le choix.
static func _filter(lobby, parent: Control, labels: Array, values: Array, cur: String, set_v: Callable) -> void:
	var o := OptionButton.new()
	o.focus_mode = Control.FOCUS_NONE
	o.fit_to_longest_item = false
	o.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	o.add_theme_font_size_override("font_size", 14)
	for l in labels:
		o.add_item(String(l))
	o.select(maxi(values.find(cur), 0))
	if cur != "":
		UiTheme.style_button(o, "lagon", 14, {"radius": 12, "shadow": 3})
	o.item_selected.connect(func(i):
		set_v.call(String(values[i]))
		lobby._show_menu("dungeon"))
	parent.add_child(o)


## Tuile d'un donjon de la liste : médaillon, nom, emplacements · panoplie, familles de mécaniques (points de couleur) et
## médailles N / H / M (pleines : boss battu à cette difficulté) ; lagon si choisie, tramée et grise si fermée.
static func _card(lobby, id: String, diff: int) -> Button:
	var zid := Dungeons.boss_zone(id)
	var open := Dungeons.is_open(zid)
	var on := id == sel
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(CARD_W, 82)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UiTheme.style_button(b, "lagon" if on else ("papier" if open else "gris"), 0, {"radius": 14, "shadow": 4, "trame": not open, "gloss": false,
		"cel_top": 0.0, "cel_bottom": 0.0})
	b.set_meta("boss", id)
	var h := HBoxContainer.new()
	h.set_anchors_preset(Control.PRESET_FULL_RECT)
	h.offset_left = 8
	h.offset_right = -8
	h.offset_top = 6
	h.offset_bottom = -10
	h.add_theme_constant_override("separation", 8)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(h)
	var por := BossPortrait.for_boss(id, 56, false)
	por.dim = not open
	por.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(por)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 1)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(v)
	var t := _ink_label(v, Dungeons.dungeon_name(id), 15, true, not open)
	t.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	t.clip_text = true
	if on:
		t.add_theme_color_override("font_color", UiTheme.color("encre.900"))
	var s := _ink_label(v, "%s · %s" % [Dungeons.slot_text(id), _arch_name(String(BossLibrary.loot(id).archetype))] if open else Dungeons.condition(zid), 12, false, true)
	s.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	s.clip_text = true
	var low := HBoxContainer.new()
	low.add_theme_constant_override("separation", 4)
	low.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(low)
	var dots := Control.new()
	var fams := BossLibrary.families_of(id)
	dots.custom_minimum_size = Vector2(16 * fams.size() + 2, 18)
	dots.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dots.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dots.draw.connect(_draw_dots.bind(dots, fams, open))
	low.add_child(dots)
	for d in MEDALS.size():
		low.add_child(_medal(String(MEDALS[d][0]), String(MEDALS[d][1]), open and Dungeons.boss_cleared(id, d) > 0))
	b.tooltip_text = "%s\n%s" % [BossLibrary.full_name(id), ", ".join(BossLibrary.mechanic_names(id))] if open else Dungeons.condition(zid)
	b.pressed.connect(func():
		sel = id
		lobby._show_menu("dungeon"))
	return b


## Médaille de difficulté : pastille ronde, pleine (bonbon) si le boss est battu à cette difficulté, sinon creuse.
static func _medal(letter: String, tone: String, won: bool) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(22, 22)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.draw.connect(_draw_medal.bind(c, letter, tone, won))
	return c


## Coche pomme autocollante (pièce déjà à toi).
static func _draw_check(ck: Control) -> void:
	ck.draw_circle(Vector2(11, 11), 11, UiTheme.color("encre.700"))
	ck.draw_circle(Vector2(11, 11), 8.5, UiTheme.color("bonbon.pomme.base"))
	ck.draw_polyline(PackedVector2Array([Vector2(6.5, 11), Vector2(10, 14.5), Vector2(15.5, 7.5)]), UiTheme.color("encre.700"), 2.6, true)


## Points de couleur des familles de mécaniques.
static func _draw_dots(dots: Control, fams: Array, open: bool) -> void:
	for i in fams.size():
		var c := Vector2(8 + 16 * i, 9)
		dots.draw_circle(c, 7, UiTheme.color("encre.700"))
		dots.draw_circle(c, 5, UiTheme.tones("gris" if not open else BossBar.family_tone(String(fams[i])))[1])


static func _draw_medal(c: Control, letter: String, tone: String, won: bool) -> void:
	var ink := UiTheme.color("encre.700") if won else UiTheme.color("encre.300")
	c.draw_circle(Vector2(11, 11), 10.5, ink)
	c.draw_circle(Vector2(11, 11), 8.0, UiTheme.tones(tone)[1] if won else UiTheme.color("papier.200"))
	var f := UiTheme.bold_font()
	var w := f.get_string_size(letter, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
	if won:
		c.draw_string_outline(f, Vector2(11 - w * 0.5, 15.5), letter, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, 3, ink)
	c.draw_string(f, Vector2(11 - w * 0.5, 15.5), letter, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.WHITE if won else ink)
