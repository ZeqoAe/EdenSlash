class_name ForgeBench
extends MerchantPages.ForgePage
## Atelier > Forge : un seul panneau pour tout ce qui se fait sur une pièce, rangé en sept établis : Améliorer
## (fortification +1 à +10, sans rétrogradation, avec persévérance et « Viser +N », lot GX-2), Enchanter, Gemmes (percer,
## sertir, fusionner), Polir (qualité), Réajuster (relancer une stat bonus, puis garder l'ancien ou le nouveau jet), Reporter
## (lot GX-5 : le +N d'une ancienne pièce du même emplacement sur la neuve, moins 2 crans, sans échec) et Démonter (cristaux).
## La pièce choisie à gauche ; à droite, ses lignes « avant → après », le
## coût en cristaux (en rouge s'il en manque) et l'action en bas. Chaque action passe par la barre de forge : elle
## se remplit pendant 0,8 à 1,6 s, puis le verdict s'affiche : pomme « Réussi », lagon « Raté » quand l'échec remplit la
## persévérance (il avance, il ne punit pas), fraise pour un refus. Le hasard est
## tiré au moment du clic (aucune règle changée) : l'animation est un habillage, la logique reste celle de
## Profile / Craft / Forge.

const BENCHES := [
	["upgrade", "Améliorer", "upgrade", 1.5],
	["enchant", "Enchanter", "power", 1.2],
	["gems", "Gemmes", "gem", 1.0],
	["polish", "Polir", "new", 1.2],
	["reforge", "Réajuster", "all", 1.0],
	["report", "Reporter", "upgrade", 1.0],  # lot GX-5 : le +N d'une ancienne pièce sur la neuve, moins 2 crans
	["dismantle", "Démonter", "dismantle", 0.8],
]
## Mots d'un résultat qui le rendent « raté » (bandeau rouge).
const FAIL_WORDS := ["Raté :", "Échec", "échec", "pas mieux", "Pas assez", "Il faut", "Aucun", "Aucune", "Déjà", "introuvable", "Pas d'emplacement", "maximale", "ne change pas", "brisent",
	"Rien à gagner", "La pièce qui donne", "Au menu principal", "Choisis une autre"]

## Stats montrées dans le tableau « avant → après » d'une amélioration.
const MAIN_STATS := 4

## Tests : la barre se remplit presque aussitôt.
static var fast := false

var bench := "upgrade"
var _bar: ForgeBar
var _tab_buttons := {}
var _pinned: VBoxContainer  # l'action principale, en bas du panneau
var _busy := false
var _armed_at := -10.0  # démontage : second clic pour confirmer
## « Tout monter à +N » (lot GX-4) : la rangée au-dessus de la grille, la cible, la séance en cours.
var even_target := Forge.EVEN_TARGET
var even_stones := false
var _even_row: HBoxContainer
var _even_btn: Button
var _even_minus: Button
var _even_plus: Button
var _even := {}  # séance en cours : {target, stones, tries, fails, bonus, start_crystal, total, stop_asked}
## Durée d'un essai de « Tout monter » (la barre de forge se remplit à chaque essai).
const EVEN_TRY_SECS := 0.16


func _init() -> void:
	super._init()
	var narrow := (Engine.get_main_loop() as SceneTree).root.get_visible_rect().size.x < 1500.0  # 1280 : la page tient dans l'écran
	grid_cols = 5 if narrow else 9
	right_width = 600.0 if narrow else 760.0
	title = "Forge"
	heads = false


func subtitle() -> String:
	return "Améliorer, enchanter, sertir"


func _ready() -> void:
	super._ready()
	# colonne de droite : les établis en haut, la fiche et ses actions qui défilent, puis la barre et l'action principale
	var sc := detail.get_parent().get_parent()
	var right := sc.get_parent()
	var tabs := _build_tabs()
	right.add_child(tabs)
	right.move_child(tabs, 0)
	_bar = ForgeBar.new()
	right.add_child(_bar)
	_pinned = VBoxContainer.new()
	_pinned.add_theme_constant_override("separation", 8)
	right.add_child(_pinned)
	grid.selection_changed.connect(func():
		if not _busy:
			_bar.idle())
	# lot GX-4 : les pièces portées d'abord (le +N reste lisible : pas de ▲ / ▼ sur la case), une recherche, « Tout monter »
	grid.compare = false
	grid.first_fn = func(it): return _worn(it)
	grid.enable_search("Chercher une pièce")
	_build_even_row()
	visibility_changed.connect(_on_visibility)


## Hors run, la « bourse » de fournitures est la réserve tant que la page est visible.
func _on_visibility() -> void:
	if Profile.in_run:
		return
	if is_visible_in_tree():
		Profile.bag = Profile.stash
	else:
		Profile.bag = {}
		Profile.save_profile()


func _exit_tree() -> void:
	if not Profile.in_run and is_same(Profile.bag, Profile.stash):
		Profile.bag = {}


func refresh() -> void:
	if not Profile.in_run and is_visible_in_tree():
		Profile.bag = Profile.stash
	super.refresh()


func _on_selection() -> void:
	if not _even.is_empty():  # « Tout monter » en cours : « Arrêter » reste seul en bas
		return
	if _pinned:
		for c in _pinned.get_children():
			_pinned.remove_child(c)
			c.queue_free()
	super._on_selection()


func show_detail(sel: Array) -> void:
	_sync_tabs()
	if sel.is_empty():
		detail.text = "[center]\n[img=72x72]%s[/img]\n\n[font_size=20][b]Choisis une pièce[/b][/font_size]\n[color=#c8c8d4]dans la grille, à gauche%s.[/color]%s[/center]" % [Items.material_icon("crystal"),
			", ou « Tout monter » pour toutes les pièces portées" if bench == "upgrade" and not Forge.even_pieces(even_target).is_empty() else "", _crystal_hint()]
		if bench == "gems":
			_fusion()
		return
	var it: Dictionary = sel[0]
	if Items.is_unique(it) and bench != "dismantle":
		detail.text = _head_text(it) + "\n\n[color=#ffb347]%s[/color]" % Items.UNIQUE_TEXT
		return
	match bench:
		"upgrade":
			_bench_upgrade(it)
		"enchant":
			_bench_enchant(it)
		"gems":
			_bench_gems(it)
			_fusion()
		"polish":
			_polish(it)
		"reforge":
			_reforge(it)
		"report":
			_report(it)
		"dismantle":
			_dismantle(it)


## Sans cristaux, la Forge dit où en trouver (passe P6) : rien ne se dépense sans savoir d'où ça vient.
func _crystal_hint() -> String:
	if Profile.in_run or Profile.amount("crystal") > 0:
		return ""
	return "\n\n[color=#ffb347]Tu n'as pas de cristaux.[/color]\n[color=#c8c8d4]%s[/color]" % ResourceHelp.KINDS.crystal.get


## Nom, type et qualité de la pièce : les trois premières lignes de sa fiche.
func _head_text(it: Dictionary) -> String:
	return "\n".join(Array(Items.describe(it).split("\n")).slice(0, 3))


## Rangée des sept établis (construite une fois).
func _build_tabs() -> Control:
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 6)
	row.add_theme_constant_override("v_separation", 6)
	for b in BENCHES:
		var id: String = b[0]
		var btn := Button.new()
		btn.text = String(b[1])
		btn.toggle_mode = true
		btn.button_pressed = id == bench
		btn.focus_mode = Control.FOCUS_NONE
		btn.custom_minimum_size = Vector2(110, 38)
		btn.add_theme_font_size_override("font_size", 15)
		var on := UiTheme.flat_box(Color(0.3, 0.22, 0.08, 1.0), UiTheme.GOLD, 2, 8, false)
		var off := UiTheme.flat_box(Color(0.1, 0.08, 0.16, 0.95), UiTheme.GOLD_DIM, 1, 8, false)
		btn.add_theme_stylebox_override("normal", off)
		btn.add_theme_stylebox_override("pressed", on)
		btn.add_theme_stylebox_override("hover_pressed", on)
		btn.add_theme_stylebox_override("hover", UiTheme.flat_box(Color(0.18, 0.14, 0.28, 1.0), UiTheme.GOLD, 1, 8, false))
		btn.pressed.connect(func():
			if _busy:
				_sync_tabs()
				return
			bench = id
			_armed_at = -10.0
			_bar.idle()
			_on_selection())
		row.add_child(btn)
		_tab_buttons[id] = btn
	return row


func _sync_tabs() -> void:
	for id in _tab_buttons:
		(_tab_buttons[id] as Button).set_pressed_no_signal(id == bench)
	_sync_even()


# --- tout l'équipement à +N (lot GX-4) ----------------------------------------------------------------------------
## Rangée « Tout monter à +5 » au-dessus de la grille (établi Améliorer) : ‹ +N › et le bouton, qui dit combien de pièces
## portées sont encore en dessous.
func _build_even_row() -> void:
	var left := grid.get_parent()
	_even_row = HBoxContainer.new()
	_even_row.add_theme_constant_override("separation", 6)
	left.add_child(_even_row)
	left.move_child(_even_row, grid.get_index())
	_even_minus = ItemWidgets.action_button(_even_row, "‹", func():
		even_target = maxi(1, even_target - 1)
		_sync_even(), 40)
	_even_minus.tooltip_text = "Viser un cran plus bas"
	_even_btn = ForgeWidgets.candy_button("", "lagon", 15, 40)
	_even_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_even_btn.clip_text = true
	_even_btn.pressed.connect(_ask_even)
	_even_row.add_child(_even_btn)
	_even_plus = ItemWidgets.action_button(_even_row, "›", func():
		even_target = mini(Items.MAX_UPGRADE, even_target + 1)
		_sync_even(), 40)
	_even_plus.tooltip_text = "Viser un cran plus haut"
	for b in [_even_minus, _even_plus]:
		(b as Button).custom_minimum_size.y = 40
	_sync_even()


func _sync_even() -> void:
	if _even_row == null:
		return
	_even_row.visible = bench == "upgrade" and not Profile.in_run
	if not _even_row.visible:
		return
	var n := Forge.even_pieces(even_target).size()
	var worn := Items.SLOTS.filter(func(s): return Profile.equipped.get(s) is Dictionary and not Items.is_unique(Profile.equipped[s])).size()
	if worn == 0:
		_even_btn.text = "Aucune pièce portée"
	elif n == 0:
		_even_btn.text = "Tout est à +%d ✓" % even_target
	else:
		_even_btn.text = "Tout monter à +%d · %s" % [even_target, GearPower.plural(n, "pièce")]
	_even_btn.disabled = n == 0 or _busy
	_even_btn.tooltip_text = "Monte les pièces portées (préréglage actif) jusqu'à +%d, la moins montée d'abord : coût attendu et au pire avant de commencer, arrêt possible à tout moment." % even_target
	_even_minus.disabled = _busy or even_target <= 1
	_even_plus.disabled = _busy or even_target >= Items.MAX_UPGRADE


## Confirmation : ce qui monte, le coût attendu et au pire (cristaux, parchemins), ce qu'on a ; pierres de chance en option.
func _ask_even() -> void:
	if _busy:
		return
	var target := even_target
	var plan := Forge.plan_even(target)
	if (plan.pieces as Array).is_empty():
		return
	var have := Profile.amount("crystal")
	var e_cost := int((plan.cost as Dictionary).get("crystal", 0))
	var worst := int((plan.cost_max as Dictionary).get("crystal", 0))
	var lines: PackedStringArray = []
	lines.append("%s, %s." % [GearPower.plural(plan.pieces.size(), "pièce portée", "pièces portées"), GearPower.plural(int(plan.steps), "cran", "crans")])
	lines.append("Cristaux : attendu ≈ %s, au pire %s (tu en as %s)" % [_nb(GearPower.fmt(e_cost)), _nb(GearPower.fmt(worst)), _nb(GearPower.fmt(have))])
	for kind in plan.scrolls:
		var s: Array = plan.scrolls[kind]
		lines.append("%s : ≈ %d, au pire %d (tu en as %d)" % ["Parchemins de puissance" if kind == "power" else "Parchemins de garde", int(s[0]), int(s[1]), int(s[2])])
	if have < worst:
		lines.append("S'il en manque, la Forge s'arrête : rien n'est perdu.")
	lines.append("Un échec ne coûte que l'essai. Tu peux arrêter à tout moment.")
	var a := InfoCard.ask(self, "Tout monter à +%d ?" % target, "\n".join(lines), "Monter", func(): _even_start(target), false)
	var v := a.title_label.get_parent()
	# la liste des pièces (case, +N → +cible) et l'option des pierres de chance
	var list := HFlowContainer.new()
	list.add_theme_constant_override("h_separation", 8)
	list.add_theme_constant_override("v_separation", 6)
	for p in plan.pieces:
		var cell := VBoxContainer.new()
		cell.add_theme_constant_override("separation", 0)
		var s := ItemWidgets.ItemSlot.new(44.0)
		s.set_item(p.item)
		cell.add_child(s)
		var l := Hud._label(cell, "+%d → +%d" % [int(p.from), target], 13, UiTheme.TEXT)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		list.add_child(cell)
	v.add_child(list)
	v.move_child(list, 2)
	if _has_stones():
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		var sw := UiTheme.Switch.new()
		sw.button_pressed = even_stones
		sw.toggled.connect(func(on): even_stones = on)
		row.add_child(sw)
		var sl := Hud._label(row, "Utiliser mes pierres de chance (les plus petites d'abord)", 15, UiTheme.TEXT)
		sl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		v.add_child(row)
		v.move_child(row, v.get_child_count() - 2)


func _has_stones() -> bool:
	for id in Craft.STONES:
		if Profile.bag_count(Craft.stone_key(String(id))) > 0:
			return true
	return false


## Début de la séance : la barre de forge se remplit à chaque essai, « Arrêter » remplace l'action principale.
func _even_start(target: int) -> void:
	if _busy:
		return
	_busy = true
	_even = {"target": target, "stones": even_stones, "tries": 0, "fails": 0, "bonus": [], "start_crystal": Profile.amount("crystal"),
		"total": Forge.even_pieces(target).size(), "steps": _steps_left(target), "stop_asked": false, "stop": ""}
	_disable(actions)
	for c in _pinned.get_children():
		_pinned.remove_child(c)
		c.queue_free()
	var stop := ForgeWidgets.candy_button("Arrêter", "fraise", 18, 50)
	stop.pressed.connect(func():
		_even.stop_asked = true
		stop.disabled = true
		stop.text = "Arrêt après cet essai…")
	_pinned.add_child(stop)
	_sync_even()
	_even_next()


func _even_next() -> void:
	var target := int(_even.target)
	var left := Forge.even_pieces(target)
	if left.is_empty() or bool(_even.stop_asked):
		_even_finish()
		return
	left.sort_custom(func(a, b): return int(a.get("upgrade", 0)) * 100 + Items.SLOTS.find(a.slot) < int(b.get("upgrade", 0)) * 100 + Items.SLOTS.find(b.slot))
	var cur: Dictionary = left[0]
	var done_n := int(_even.steps) - _steps_left(target)
	_bar.caption = "Cran %d / %d" % [mini(done_n + 1, int(_even.steps)), int(_even.steps)]
	_bar.line = "%s · +%d → +%d" % [Items.display_name(cur), int(cur.get("upgrade", 0)), int(cur.get("upgrade", 0)) + 1]
	# la fiche montre la pièce en cours et le bilan de la séance
	detail.text = _head_text(cur) + "\n\n" + ba_table([["Amélioration", "+%d" % int(cur.get("upgrade", 0)), "+%d" % (int(cur.get("upgrade", 0)) + 1), 1],
		["Persévérance", "%d %%" % roundi(Craft.pity(cur) * 100.0), "", 0],
		["Essais", str(int(_even.tries)), "", 0], ["Ratés", str(int(_even.fails)), "", 0],
		["Cristaux dépensés", GearPower.fmt(int(_even.start_crystal) - Profile.amount("crystal")), "", 0]])
	_got_verdict = false
	_bar.work(0.01 if fast else EVEN_TRY_SECS, func():
		if not is_visible_in_tree():  # l'Atelier s'est fermé : la réserve n'est plus la bourse, on s'arrête là
			_even.stop_asked = true
			_even_finish()
			return
		var s := Forge.even_step(target, bool(_even.stones))
		if s.has("done"):
			_even_finish()
			return
		if s.has("stop"):
			_even.stop = String(s.stop)
			_even["blocked"] = s.get("item", {})
			_even_finish()
			return
		_even.tries = int(_even.tries) + 1
		if not bool(s.r.ok):
			_even.fails = int(_even.fails) + 1
		else:
			grid.refresh()  # le +N de la case suit
			if String(s.r.get("stat", "")) != "":
				(_even.bonus as Array).append("%s : %s" % [Items.SLOT_NAMES.get(String(s.item.slot), ""), Items.stat_text(String(s.r.stat), float(s.r.value))])
		_even_next())


## Crans encore à faire pour amener les pièces portées à +[param target].
func _steps_left(target: int) -> int:
	var n := 0
	for it in Forge.even_pieces(target):
		n += target - int(it.get("upgrade", 0))
	return n


## Fin de la séance : le résumé dans le bandeau (pomme si tout est monté, lagon si arrêt), la grille relue.
func _even_finish() -> void:
	var target := int(_even.target)
	var left := Forge.even_pieces(target).size()
	var reached := int(_even.total) - left
	var spent := int(_even.start_crystal) - Profile.amount("crystal")
	var head := ""
	if left == 0:
		head = "Tout l'équipement à +%d" % target
	elif bool(_even.stop_asked):
		head = "Arrêté : %d pièce%s sur %d à +%d" % [reached, "s" if reached > 1 else "", int(_even.total), target]
	else:
		var it: Dictionary = _even.get("blocked", {})
		var what := "plus assez de cristaux" if String(_even.stop) == "crystal" else ("plus de %s" % Craft.label(Craft.fortify_key(Craft.fortify_kind(it), Craft.fortify_level_for(it))).to_lower() if not it.is_empty() else "plus de parchemin")
		head = "Arrêt : %s · %d pièce%s sur %d à +%d" % [what, reached, "s" if reached > 1 else "", int(_even.total), target]
	var txt := "%s\n%s (%s) · %s" % [head, GearPower.plural(int(_even.tries), "essai", "essais"), GearPower.plural(int(_even.fails), "raté", "ratés"), GearPower.plural(spent, "cristal", "cristaux")]
	var bonus: Array = _even.bonus
	if not bonus.is_empty():
		txt += "\nStats bonus : " + ", ".join(bonus.slice(0, 4)) + (" + %d" % (bonus.size() - 4) if bonus.size() > 4 else "")
	_busy = false
	_got_verdict = true
	_even = {}
	Profile.save_profile()
	_bar.verdict(left == 0, txt, left > 0)
	UiFeel.cue("ui_forge_ok" if left == 0 else "ui_forge_fail", -9.0)
	if ui:
		ui.message(txt.get_slice("\n", 0), 2.5)
	refresh()


# --- les établis ---------------------------------------------------------------------------------
## Améliorer : +N → +N+1 (parchemin, pierre de sûreté, chances), avec ce que la pièce gagne.
func _bench_upgrade(it: Dictionary) -> void:
	var up := int(it.get("upgrade", 0))
	var cost := _upgrade(it)
	var rows: Array = []
	if up >= Items.MAX_UPGRADE:
		rows.append(["Amélioration", "+%d" % up, "maximale", 0])
		detail.text = _head_text(it) + "\n\n" + ba_table(rows)
		return
	rows.append(["Amélioration", "+%d" % up, "+%d" % (up + 1), 1])
	var after := it.duplicate(true)
	after["upgrade"] = up + 1
	var sb := Items.stats(it, false)
	var sa := Items.stats(after, false)
	# les quatre stats principales : les plus fortes, celles en pourcentage seulement s'il en manque
	var keys: Array = Items.base_stats(it).keys().filter(func(s): return sb.has(s))
	var main_n := MAIN_STATS if not (Craft.base_chance(it) < 1.0 and _narrow_h()) else 2  # 720 px : place pour la persévérance
	keys.sort_custom(func(a, b):
		var pa: bool = a in Items.PERCENT_STATS
		var pb: bool = b in Items.PERCENT_STATS
		return (not pa and pb) if pa != pb else float(sb[a]) > float(sb[b]))
	for s in keys.slice(0, main_n):
		rows.append([Items.STAT_NAMES.get(s, Items.EXTRA_STAT_NAMES.get(s, s)), stat_num(s, float(sb[s])), stat_num(s, float(sa[s])), 1])
	if (up + 1) in Items.MILESTONES:
		rows.append(["Stat bonus", "—", "+1 au hasard", 1])
	detail.text = _head_text(it) + "\n\n" + ba_table(rows) + "\n\n" + (cost_line(cost) if not cost.is_empty() else "[color=#c8c8d4]Coût[/color]   [b]gratuit[/b]")


func _narrow_h() -> bool:
	return get_viewport().get_visible_rect().size.y < 840.0


func _bench_enchant(it: Dictionary) -> void:
	var cur := "aucun"
	if it.has("enchant"):
		var e: Dictionary = it.enchant
		cur = "%s niv. %d" % [String(Craft.ENCHANTS.get(String(e.get("type", "")), {}).get("name", "?")), int(e.get("lv", 1))]
	_enchant(it)
	detail.text = _head_text(it) + "\n\n" + ba_table([["Enchantement", cur, "au choix" if not Profile.bag_keys("scroll").is_empty() else "", 0]])


func _bench_gems(it: Dictionary) -> void:
	var sockets: Array = it.get("sockets", [])
	var rows: Array = []
	if sockets.size() < Craft.MAX_SOCKETS:
		rows.append(["Emplacements", "%d / %d" % [sockets.size(), Craft.MAX_SOCKETS], "%d / %d" % [sockets.size() + 1, Craft.MAX_SOCKETS], 1])
	else:
		rows.append(["Emplacements", "%d / %d" % [sockets.size(), Craft.MAX_SOCKETS], "complet", 0])
	for i in sockets.size():
		var g = sockets[i]
		var gk := Craft.gem_key(String(g.type), int(g.tier)) if g is Dictionary else ""
		rows.append(["Gemme %d" % (i + 1), ("%s · %s" % [Craft.label(gk), Craft.gem_value_text(gk)]) if g is Dictionary else "vide", "", 0])
	_gems(it)
	detail.text = _head_text(it) + "\n\n" + ba_table(rows)


func _polish(it: Dictionary) -> void:
	var pc := Forge.polish_cost(it)
	var q := float(it.get("quality", 1.0))
	var qmax := float(Items.QUALITY[clampi(int(it.get("rarity", 0)), 0, Items.QUALITY.size() - 1)][1])
	var more := q < qmax
	var rows := [["Qualité", "%d %%" % roundi(q * 100.0), ("jusqu'à %d %%" % roundi(qmax * 100.0)) if more else "maximale", 1 if more else 0]]
	detail.text = _head_text(it) + "\n\n" + ba_table(rows) + "\n\n" + cost_line(pc)
	_note("Nouveau jet, gardé seulement s'il est meilleur.")
	button("Polir · %s" % MerchantPages.price_words(pc), func(): done(Forge.polish(it)), Profile.can_afford(pc) and more, true)


func _reforge(it: Dictionary) -> void:
	var rc := Forge.reforge_cost(it)
	var stats := Forge.reforgeable(it)
	var rows: Array = []
	var pending := Forge.reforge_pending(it)
	if not pending.is_empty():
		# le jet est tiré : l'ancien et le nouveau côte à côte, le joueur garde l'un des deux
		var d := float(pending.new) - float(pending.old)
		rows.append([Forge.stat_name(String(pending.stat)), Forge.reroll_text(it, float(pending.old)), Forge.reroll_text(it, float(pending.new)), signi(int(signf(d)))])
		detail.text = _head_text(it) + "\n\n" + ba_table(rows)
		reroll_choice(it)
		return
	for stat in stats:
		var s: String = stat
		rows.append([Forge.stat_name(s), Items.stat_text(s, _roll_value(it, s)), "nouveau jet", 0])
		button("Réajuster %s · %s" % [Forge.stat_name(s), MerchantPages.price_words(rc)],
			func(): done(Forge.reforge(it, s)), Profile.can_afford(rc))
	detail.text = _head_text(it)
	if stats.is_empty():
		detail.text += "\n\n[color=#c8c8d4]Pas de stat bonus à réajuster : elles viennent des paliers +4, +6, +8 et +10.[/color]"
		return
	detail.text += "\n\n" + ba_table(rows) + "\n\n" + cost_line(rc)
	_note("Après le tirage, tu gardes l'ancien jet ou le nouveau.")


## Valeur affichée d'une stat réajustable : stat bonus d'amélioration (suit la puissance de la pièce) ou affixe.
func _roll_value(it: Dictionary, s: String) -> float:
	for r in it.get("up_rolls", []):
		if String(r[0]) == s:
			return float(r[1]) * (1.0 if s in Items.PERCENT_STATS else Items._level_k(Items.power_level(it)))
	return float(it.get("affixes", {}).get(s, 0.0))


## Reporter (lot GX-5) : la pièce choisie reçoit le +N d'une autre pièce du même emplacement, moins 2 crans, sans échec ni
## parchemin (le prix des crans en cristaux) ; ses stats bonus des paliers gardés suivent ; l'autre revient à +0. Les sources
## possibles, la plus haute d'abord.
func _report(it: Dictionary) -> void:
	var up := int(it.get("upgrade", 0))
	if Profile.in_run:
		detail.text = _head_text(it) + "

[color=#c8c8d4]Reporter se fait au menu principal.[/color]"
		return
	var src := Forge.report_sources(it)
	if src.is_empty():
		detail.text = _head_text(it) + "

" + ba_table([["Amélioration", "+%d" % up, "—", 0]]) 			+ "

[color=#c8c8d4]Aucune pièce de cet emplacement ne peut lui donner plus que +%d.
Une pièce à +7 donne +5 à la neuve, puis revient à +0. Sans échec ni parchemin.[/color]" % up
		return
	var best: Dictionary = src[0]
	var target := Forge.report_target(best)
	var have := (it.get("up_rolls", []) as Array).size()
	var keep := (best.get("up_rolls", []) as Array).filter(func(r): return r is Array and r.size() >= 3 and int(r[2]) <= target).size()
	var rows: Array = [["Amélioration", "+%d" % up, "+%d" % target, 1], ["Stats bonus", str(have), str(keep), signi(keep - have)]]
	detail.text = _head_text(it) + "

" + ba_table(rows) + "

" + cost_line(Forge.report_cost(best, it)) 		+ "

[color=#c8c8d4]La pièce qui donne revient à +0 (%d crans perdus au report).[/color]" % Forge.REPORT_LOSS
	for s in src.slice(0, 4):
		var sv: Dictionary = s
		var nm := Items.display_name(sv).trim_prefix("+%d " % int(sv.get("upgrade", 0)))
		var pb := ItemWidgets.action_button(actions, "Prendre le +%d de %s%s → +%d · %s" % [int(sv.get("upgrade", 0)), nm, " (portée)" if _worn(sv) else "",
			Forge.report_target(sv), MerchantPages.price_words(Forge.report_cost(sv, it))], _ask_report.bind(sv, it))  # la confirmation d'abord, la barre ensuite
		pb.disabled = not Profile.can_afford(Forge.report_cost(sv, it))
		if pb.disabled:
			pb.tooltip_text = "Il te manque %s." % MerchantPages.price_words({"crystal": int(Forge.report_cost(sv, it).crystal) - Profile.amount("crystal")})
	_note("Sans échec ni parchemin : la neuve prend le +N moins %d crans et les stats bonus des paliers gardés." % Forge.REPORT_LOSS)


## Confirmation du report (la pièce qui donne revient à +0 : irréversible), puis la barre de forge.
func _ask_report(src: Dictionary, dst: Dictionary) -> InfoCard.Ask:
	var users := Profile.item_users(String(src.get("uid", "")))
	var text := "« %s » passe de +%d à +%d.
« %s » revient de +%d à +0.%s

Prix : %s (tu en as %s)." % [String(dst.get("name", "")), int(dst.get("upgrade", 0)),
		Forge.report_target(src), String(src.get("name", "")), int(src.get("upgrade", 0)),
		("
Elle sert au préréglage : %s." % ", ".join(users)) if not users.is_empty() else "",
		MerchantPages.price_words(Forge.report_cost(src, dst)), GearPower.fmt(Profile.amount("crystal"))]
	return InfoCard.ask(self, "Reporter le +%d ?" % int(src.get("upgrade", 0)), text, "Reporter", func(): _run(func(): done(Forge.report(src, dst), 2.4)), false)


func _dismantle(it: Dictionary) -> void:
	var y := Items.disassemble_yield(it)
	var worn := _worn(it)
	var have := Profile.amount("crystal")
	var gain := int(y.get("crystal", 0))
	detail.text = _head_text(it) + "\n\n" + ba_table([["Cristaux", GearPower.fmt(have), GearPower.fmt(have + gain), 1 if gain > 0 else 0]]) \
		+ "\n\n[color=#c8c8d4]La pièce disparaît.[/color]"
	if worn:
		_note("Retire d'abord la pièce portée (page Héros).")
	var users := Profile.item_users(String(it.get("uid", "")))
	if not users.is_empty():
		_note("Utilisée par le préréglage de %s." % ", ".join(users))
	var armed := now() - _armed_at < 3.0
	button(("Confirmer : démonter %s ?" % Items.display_name(it)) if armed else "Démonter · %s" % MerchantPages.price_words(y), func():
		if now() - _armed_at > 3.0:
			_armed_at = now()
			_on_selection()
			return
		_armed_at = -10.0
		_run(func():
			var got := Profile.disassemble(it)
			grid.clear_selection()
			done("Démonté : %s" % MerchantPages.price_words(got), 2.0)), not worn, true)


## L'action principale (en or) se range en bas du panneau ; toute action d'établi passe par la barre de forge,
## sauf les cases de choix (pierre, parchemin béni) et la confirmation du démontage.
func button(text: String, cb: Callable, enabled := true, accent := false) -> Button:
	var plain := text.begins_with("☑") or text.begins_with("☐") or text.begins_with("Confirmer : démonter") or text.begins_with("Démonter ·")
	var b := ItemWidgets.action_button(_pinned if accent and _pinned else actions, text, cb if plain else func(): _run(cb), 0, accent)
	b.disabled = not enabled
	return b


## « Viser +N » (lot GX-2) : dans la zone épinglée, juste au-dessus de « Fortifier », toujours visible.
func _aim_parent() -> Control:
	return _pinned if _pinned else actions


func button_in(parent: Control, text: String, cb: Callable, enabled := true) -> Button:
	var b := ItemWidgets.action_button(parent, text, func(): _run(cb))
	b.disabled = not enabled
	return b


func _bench_seconds() -> float:
	for b in BENCHES:
		if b[0] == bench:
			return float(b[3])
	return 1.0


## Lance l'animation puis l'action [param cb] ; son résultat arrive par [method done].
func _run(cb: Callable) -> void:
	if _busy:
		return
	_busy = true
	_disable(actions)
	_disable(_pinned)
	_got_verdict = false
	var secs := 0.02 if fast else _bench_seconds()
	_bar.work(secs, func():
		cb.call()
		_busy = false
		if not _got_verdict:
			_bar.idle())


var _got_verdict := false


func _disable(n: Node) -> void:
	if n is BaseButton:
		(n as BaseButton).disabled = true
	for c in n.get_children():
		_disable(c)


func done(msg: String, duration := 2.0) -> void:
	_got_verdict = true
	_bar.verdict(not _is_fail(msg), msg, msg.contains("Raté :"))
	UiFeel.cue(verdict_sound(msg), -9.0)
	super.done(msg, duration)


## Son du verdict (lot SND-2) : forge réussie, forge ratée (échec du tirage), ou « bonk » d'une demande refusée (pas assez
## de cristaux, rien à faire…).
static func verdict_sound(msg: String) -> String:
	if not _is_fail(msg):
		return "ui_forge_ok"
	for w in ["Raté :", "Échec", "échec", "pas mieux", "brisent"]:
		if msg.contains(w):
			return "ui_forge_fail"
	return "ui_deny"


static func _is_fail(msg: String) -> bool:
	for w in FAIL_WORDS:
		if msg.contains(w):
			return true
	return false


## Barre de forge : cachée au repos, elle chauffe (la barre se remplit) puis donne le verdict, vert ou rouge.
class ForgeBar extends PanelContainer:
	var _title: Label
	var _bar: ProgressBar
	var _msg: Label
	var _tw: Tween
	var _dots := 0.0
	var _working := false

	func _init() -> void:
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 4)
		add_child(v)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 14)
		v.add_child(row)
		_title = Hud._label(row, "", 20, Color.WHITE)
		_title.custom_minimum_size = Vector2(150, 0)
		_msg = Hud._label(row, "", 15, Color(0.85, 0.85, 0.92))
		_msg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_bar = ProgressBar.new()
		_bar.min_value = 0.0
		_bar.max_value = 1.0
		_bar.show_percentage = false
		_bar.custom_minimum_size = Vector2(0, 10)
		_bar.add_theme_stylebox_override("background", UiTheme.flat_box(Color(0.06, 0.05, 0.1, 1.0), UiTheme.GOLD_DIM, 1, 5, false))
		_bar.add_theme_stylebox_override("fill", UiTheme.flat_box(Color(0.95, 0.6, 0.15), Color(1.0, 0.85, 0.4), 1, 5, false))
		v.add_child(_bar)
		idle()

	func _style(fill: Color, border: Color) -> void:
		add_theme_stylebox_override("panel", UiTheme.flat_box(fill, border, 2, 10))

	## Au repos : rien à montrer.
	func idle() -> void:
		_working = false
		caption = ""
		line = ""
		visible = false
		_style(Color(0.07, 0.06, 0.12, 0.95), UiTheme.GOLD_DIM)
		_title.text = ""
		_bar.value = 0.0
		_msg.text = ""

	func work(secs: float, done_cb: Callable) -> void:
		_working = true
		_dots = 0.0
		visible = true
		_style(Color(0.16, 0.1, 0.04, 0.97), Color(1.0, 0.7, 0.25))
		_title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.5))
		_bar.add_theme_stylebox_override("fill", UiTheme.flat_box(Color(0.95, 0.6, 0.15), Color(1.0, 0.85, 0.4), 1, 5, false))
		_msg.text = ""
		_bar.value = 0.0
		if _tw:
			_tw.kill()
		_tw = create_tween()
		_tw.tween_property(_bar, "value", 1.0, secs).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_tw.tween_callback(func():
			_working = false
			done_cb.call())

	## Titre pendant le travail (« Tout monter » : « Pièce 3 / 7 ») et ligne de droite, gardés d'un essai à l'autre.
	var caption := ""
	var line := ""

	func _process(delta: float) -> void:
		if _working:
			_dots += delta * 4.0
			_title.text = (caption if caption != "" else "Forge en cours") + ".".repeat(int(_dots) % 4)
			if line != "":
				_msg.text = line

	## [param soft] : un échec de la Forge qui remplit la persévérance (lagon : il avance, il ne punit pas).
	func verdict(ok: bool, text: String, soft := false) -> void:
		_working = false
		caption = ""
		line = ""
		visible = true
		_bar.value = 1.0
		var col := ForgeWidgets.POMME if ok else (ForgeWidgets.LAGON if soft else ForgeWidgets.FRAISE)
		_style(Color(0.05, 0.2, 0.08, 0.97) if ok else (Color(0.03, 0.14, 0.24, 0.97) if soft else Color(0.24, 0.05, 0.06, 0.97)), col)
		_title.text = "RÉUSSI" if ok else "RATÉ"
		_title.add_theme_color_override("font_color", col)
		_bar.add_theme_stylebox_override("fill", UiTheme.flat_box(col.darkened(0.25), col, 1, 5, false))
		_msg.text = text.replace("\n", " · ")
		# petit rebond du bandeau
		pivot_offset = size * 0.5
		scale = Vector2(1.04, 1.04)
		var t := create_tween()
		t.tween_property(self, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
