class_name RoyalePage
extends RefCounted
## Page du Battle royale dans le menu Jouer (lot BR-R1, backlog BM-BR P1 n° 11, maquette 6 de
## `conception/benchmark/battle_royale_maquettes`) : une idée par bloc, de haut en bas :
##   1. la partie : Classique, Du jour (le modificateur qui tourne chaque jour, RoyaleMods) ou Personnalisée (modificateur et graine
##      au choix, sans ligue ni récompense, P2 n° 26) ; une carte dit le modificateur choisi en une phrase ;
##   2. les adversaires (difficulté des sept héros scriptés, en pastilles) ;
##   3. les règles en quatre lignes courtes (le détail en infobulle) ;
##   4. la Ligue royale de la saison (rang, points, ce que donne le rang suivant, jours restants ; RoyaleLeague) ;
##   5. la carrière (P2 n° 24 : parties, victoires, podiums, éliminations, record, dégâts, autels, classe la plus gagnante) ;
##   6. les apparences du mode (voile du planeur, traînée de chute, couronne : P2 n° 22, RoyaleLooks).
## « Lancer » reste épinglé sous la page (Lobby._pin_go). Les choix restent d'une visite à l'autre (variables statiques).
## Construite par Lobby._menu_royale dans le panneau des pages (Lobby._sub) avec ses aides (_section, _activity_head).

static var pick := "classic"  # classic, daily, custom
static var custom_mod := ""
static var seed_text := ""

const DIFFS := [[-1, "Mélange"], [0, "Facile"], [1, "Normal"], [2, "Difficile"], [3, "Hardcore"]]
const RULES := [
	["8 héros sautent d'un aigle, nus, au niveau 1", "Personne ne frappe en l'air. Tombé dans les deux premières minutes : tu reviens une fois."],
	["Pille coffres et largages : niveau et pièces montent", "Ton arme reste la tienne ; une fois l'équipement complet, les coffres l'améliorent."],
	["Au 2e anneau, un autel gardé cache un trésor", "Le gardien ne quitte pas l'autel : l'ignorer ne coûte rien, le vaincre rapporte gros."],
	["L'anneau se referme : le dernier debout gagne", "Le niveau maximal monte à chaque anneau ; le meilleur chasseur est mis à prix."],
]
const RANK_TONES := ["mandarine", "papier2", "soleil", "lagon"]


## Modificateur de la partie choisie ("" : classique).
static func chosen_mod() -> String:
	match pick:
		"daily":
			return RoyaleMods.today_id()
		"custom":
			return custom_mod
	return ""


## Graine de la partie personnalisée (0 : au hasard).
static func chosen_seed() -> int:
	if pick != "custom" or seed_text.strip_edges() == "":
		return 0
	var t := seed_text.strip_edges()
	return maxi(1, int(t)) if t.is_valid_int() else absi(hash(t)) % 1000000 + 1


## Pose la partie choisie dans Royale (au lancement, à « Continuer »).
static func apply() -> void:
	Royale.mod = chosen_mod()
	Royale.custom = pick == "custom"
	Royale.custom_seed = chosen_seed()


## Réglages à garder pour « Continuer » (LastActivity).
static func memo(diff: int) -> Dictionary:
	return {"diff": diff, "pick": pick, "mod": custom_mod, "seed": seed_text}


static func restore(o: Dictionary) -> void:
	pick = String(o.get("pick", pick))
	if not pick in ["classic", "daily", "custom"]:
		pick = "classic"
	custom_mod = String(o.get("mod", custom_mod))
	seed_text = String(o.get("seed", seed_text))


static func build(lb) -> void:
	lb._activity_head("royale")
	_party(lb)
	_rivals(lb)
	_rules(lb)
	_league(lb)
	_career(lb)
	_looks(lb)
	var go := MenuWidgets.gold_button("Lancer le Battle royale" if pick != "custom" else "Lancer la partie personnalisée", 22, Vector2(0, 58))
	go.disabled = not Unlocks.is_open("royale")
	go.pressed.connect(lb._start_royale)
	lb._pin_go(go, "" if Unlocks.is_open("royale") else Unlocks.lock_text("royale"))


## Pastille de choix (sélectionnée : lagon, Bible § 6).
static func _chip(text: String, selected: bool, size := 15) -> Button:
	var b := MenuWidgets.glass_button(text, size, Vector2(0, 40))
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if selected:
		UiTheme.style_button(b, "lagon", size)
	b.toggle_mode = false
	return b


static func _row(lb) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	lb._sub.add_child(row)
	return row


static func _well(lb, pad := Vector2(14, 10)) -> VBoxContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UiTheme.well_style(pad))
	p.mouse_filter = Control.MOUSE_FILTER_PASS
	lb._sub.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	p.add_child(v)
	return v


static func _text(parent: Control, text: String, size := 15, col := UiTheme.TEXT, bold := false) -> Label:
	var l := Hud._label(parent, text, size, col)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if bold:
		l.add_theme_font_override("font", UiTheme.bold_font())
	return l


# --- 1. la partie -------------------------------------------------------------------------------------------
static func _party(lb) -> void:
	lb._section("Partie", "Classique : les règles de toujours. Du jour : un modificateur qui change chaque jour. Personnalisée : modificateur et graine au choix, pour t'entraîner.")
	var row := _row(lb)
	for e in [["classic", "Classique"], ["daily", "Du jour"], ["custom", "Personnalisée"]]:
		var b := _chip(String(e[1]), pick == String(e[0]))
		b.pressed.connect(_set_pick.bind(lb, String(e[0])))
		row.add_child(b)
	var mod := chosen_mod()
	var def := RoyaleMods.get_def(mod)
	var v := _well(lb)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	v.add_child(head)
	var tag := PanelContainer.new()
	tag.add_theme_stylebox_override("panel", UiTheme.sticker(String(def.tone), {"pad": Vector2(10, 2), "shadow": 3, "radius": 10}))
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(tag)
	var tl := Hud._label(tag, String(def.name), 16, UiTheme.color("encre.700") if String(def.tone) == "papier" else Color.WHITE)
	tl.add_theme_font_override("font", UiTheme.title_font())
	if String(def.tone) != "papier":
		tl.add_theme_color_override("font_outline_color", UiTheme.color("encre.700"))
		tl.add_theme_constant_override("outline_size", 5)
	if pick == "daily":
		var dl := Hud._label(head, "Aujourd'hui", 14, UiTheme.MUTED)
		dl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_text(v, String(def.line), 15, UiTheme.TEXT)
	if pick == "custom":
		_custom(lb, v)


static func _set_pick(lb, k: String) -> void:
	pick = k
	lb._show_menu("royale")


static func _set_mod(i: int, lb, ids: Array) -> void:
	custom_mod = String(ids[i])
	lb._show_menu("royale")


static func _set_diff(lb, k: int) -> void:
	lb._royale_diff = k
	lb._show_menu("royale")


## Partie personnalisée : le modificateur (liste) et la graine (même graine : même carte, mêmes adversaires).
static func _custom(lb, v: VBoxContainer) -> void:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	v.add_child(h)
	var ob := OptionButton.new()
	ob.focus_mode = Control.FOCUS_NONE
	ob.add_item("Classique")
	var ids: Array = [""]
	for m in RoyaleMods.LIST:
		ob.add_item(String(m.name))
		ids.append(String(m.id))
	ob.select(maxi(ids.find(custom_mod), 0))
	ob.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ob.tooltip_text = "Le modificateur de la partie personnalisée."
	ob.item_selected.connect(_set_mod.bind(lb, ids))
	h.add_child(ob)
	var le := LineEdit.new()
	le.placeholder_text = "Graine (vide : au hasard)"
	le.text = seed_text
	le.custom_minimum_size = Vector2(200, 0)
	le.tooltip_text = "Même graine : même carte, mêmes adversaires, même anneau."
	le.text_changed.connect(func(t): seed_text = t)
	h.add_child(le)
	_text(v, "Sans ligue ni récompense : pour t'entraîner.", 14, UiTheme.MUTED)


# --- 2. les adversaires -----------------------------------------------------------------------------------
static func _rivals(lb) -> void:
	lb._section("Adversaires", "La force des sept héros scriptés. Mélange : de Facile à Hardcore. La Ligue royale compte plus de points en Difficile et en Hardcore.")
	var row := _row(lb)
	for opt in DIFFS:
		var b := _chip(String(opt[1]), lb._royale_diff == int(opt[0]), 14)
		b.pressed.connect(_set_diff.bind(lb, int(opt[0])))
		row.add_child(b)


# --- 3. les règles ----------------------------------------------------------------------------------------
static func _rules(lb) -> void:
	lb._section("Règles")
	for r in RULES:
		var l := _text(lb._sub, "•  " + String(r[0]), 15, UiTheme.TEXT)
		l.mouse_filter = Control.MOUSE_FILTER_STOP
		l.tooltip_text = String(r[1])


# --- 4. la Ligue royale -----------------------------------------------------------------------------------
static func _league(lb) -> void:
	lb._section("Ligue royale · %s" % RoyaleLeague.season_name(),
		"Points à chaque partie : la place, plus 2 par élimination, selon la difficulté. Jamais perdus. Une saison par mois.")
	var r := RoyaleLeague.rank()
	var pts := RoyaleLeague.points()
	var v := _well(lb)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	v.add_child(head)
	var badge := PanelContainer.new()
	badge.add_theme_stylebox_override("panel", UiTheme.sticker(String(RANK_TONES[r]), {"pad": Vector2(12, 2), "shadow": 3, "radius": 10}))
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(badge)
	var played := int(RoyaleLeague.state().get("games", 0)) > 0
	var bl := Hud._label(badge, RoyaleLeague.rank_name(r) if played else "Non classé", 17, UiTheme.color("encre.700"))
	bl.add_theme_font_override("font", UiTheme.title_font())
	var pl := Hud._label(head, "%d point%s" % [pts, "s" if pts > 1 else ""], 17, UiTheme.TEXT)
	pl.add_theme_font_override("font", UiTheme.number_font())
	pl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var dl := Hud._label(head, "fin dans %d j" % RoyaleLeague.days_left(), 14, UiTheme.MUTED)
	dl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if r < RoyaleLeague.RANKS.size() - 1:
		var bar := ProgressBar.new()
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(0, 14)
		bar.min_value = float(RoyaleLeague.STEPS[r])
		bar.max_value = float(RoyaleLeague.STEPS[r + 1])
		bar.value = float(pts)
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(bar)
		var nxt := r + 1
		var gift: String = ["", "un coffre d'apparence rare", "un coffre d'apparence épique", "un coffre d'apparence légendaire"][nxt]
		if not String(RoyaleLeague.RANK_TITLE[nxt]) in Profile.extra_titles:
			gift += " et le titre « %s »" % String(RoyaleLeague.RANK_TITLE[nxt])
		_text(v, "%s dans %d points : %s." % [RoyaleLeague.rank_name(nxt), RoyaleLeague.to_next(), gift], 14, UiTheme.MUTED)
	else:
		_text(v, "Rang le plus haut de la saison : bravo !", 14, UiTheme.MUTED)
	if pick == "custom":
		_text(v, "La partie personnalisée ne compte pas.", 14, Color(1.0, 0.7, 0.55))


# --- 5. la carrière ---------------------------------------------------------------------------------------
static func career_values() -> Array:
	var rec := Profile.records
	var best := int(rec.get("royale_best", 0))
	return [
		[str(int(rec.get("royale_games", 0))), "parties"],
		[str(int(rec.get("royale_wins", 0))), "victoires"],
		[str(int(rec.get("royale_podiums", 0))), "podiums"],
		[str(best) if best > 0 and best < 99 else "—", "meilleure place"],
		[str(int(rec.get("royale_kills", 0))), "éliminations"],
		[str(int(rec.get("royale_best_kills", 0))), "record d'élim."],
		[Hud._big_number(float(rec.get("royale_dealt", 0.0))), "dégâts"],
		[str(int(rec.get("royale_altars", 0))), "gardiens"],
	]


## Classe la plus gagnante : « Magicien (3) » ("" : aucune victoire).
static func best_class() -> String:
	var by = Profile.records.get("royale_class_wins", {})
	if not by is Dictionary or (by as Dictionary).is_empty():
		return ""
	var best := ""
	var n := 0
	for cid in by:
		if int(by[cid]) > n:
			n = int(by[cid])
			best = String(cid)
	return "%s (%d)" % [String(GameData.class_data(best).get("name_fr", best)), n]


static func _career(lb) -> void:
	lb._section("Carrière")
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	lb._sub.add_child(grid)
	for e in career_values():
		var p := PanelContainer.new()
		p.add_theme_stylebox_override("panel", UiTheme.well_style(Vector2(8, 4), 12))
		p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
		grid.add_child(p)
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 0)
		p.add_child(v)
		var val := Hud._label(v, String(e[0]), 19, UiTheme.GOLD)
		val.add_theme_font_override("font", UiTheme.number_font())
		val.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var cap := Hud._label(v, String(e[1]), 14, UiTheme.MUTED)
		cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var bc := best_class()
	if bc != "":
		_text(lb._sub, "Le plus de victoires : %s" % bc, 14, UiTheme.MUTED)


# --- 6. les apparences du mode -------------------------------------------------------------------------
static func _looks(lb) -> void:
	lb._section("Apparence", "Gagnées en jouant le mode ; elles ne changent pas le combat. La couronne se porte la partie qui suit une victoire.")
	var g := RoyaleLooks.glider()
	var row := _row(lb)
	Hud._label(row, "Voile", 15, UiTheme.TEXT).custom_minimum_size = Vector2(70, 0)
	for e in RoyaleLooks.GLIDERS:
		row.add_child(_swatch(lb, "glider", e, String(e.id) == String(g.id)))
	var t := RoyaleLooks.trail()
	var row2 := _row(lb)
	Hud._label(row2, "Traînée", 15, UiTheme.TEXT).custom_minimum_size = Vector2(70, 0)
	for e in RoyaleLooks.TRAILS:
		var open := RoyaleLooks.met(String(e.need))
		var b := _chip(("🔒 " if not open else "") + String(e.name), String(e.id) == String(t.id), 14)
		b.disabled = not open
		b.tooltip_text = String(e.name) if open else "%s : %s" % [String(e.name), String(e.get("text", ""))]
		b.pressed.connect(_pick_look.bind(lb, "trail", String(e.id)))
		row2.add_child(b)
	_text(lb._sub, "Tu portes la couronne du vainqueur à la prochaine partie." if RoyaleLooks.crowned()
		else "Gagne une partie : tu porteras la couronne à la suivante.", 14, UiTheme.MUTED)


## Pastille de couleur d'une voile (cadenas et condition si elle est fermée).
static func _swatch(lb, kind: String, e: Dictionary, selected: bool) -> Button:
	var open := RoyaleLooks.met(String(e.need))
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(44, 40)
	b.text = "" if open else "🔒"
	var col: Color = e.col
	for st in ["normal", "hover", "pressed", "disabled", "focus"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = col if open else col.darkened(0.55)
		sb.border_color = UiTheme.color("bonbon.lagon.fonce", Color("0b7db5")) if selected else UiTheme.color("encre.700")
		sb.set_border_width_all(5 if selected else 3)
		sb.set_corner_radius_all(12)
		sb.anti_aliasing = true
		if st == "hover":
			sb.bg_color = sb.bg_color.lightened(0.12)
		b.add_theme_stylebox_override(st, sb)
	b.disabled = not open
	b.tooltip_text = String(e.name) + ("" if open else " : " + String(e.get("text", "")))
	b.pressed.connect(_pick_look.bind(lb, kind, String(e.id)))
	return b


static func _pick_look(lb, kind: String, id: String) -> void:
	if RoyaleLooks.pick(kind, id):
		Profile.save_profile()
		Sfx.ui("ui_equip", -8.0)
	lb._show_menu("royale")
