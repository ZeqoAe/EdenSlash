class_name ForgeBench
extends MerchantPages.ForgePage
## Atelier > Forge : un seul panneau pour tout ce qui se fait sur une pièce, rangé en six établis : Améliorer
## (fortification +1 à +10), Enchanter, Gemmes (percer, sertir, fusionner), Polir (qualité), Réajuster (relancer
## une stat bonus) et Démonter (cristaux). La pièce choisie à gauche ; à droite, ses lignes « avant → après », le
## coût en cristaux (en rouge s'il en manque) et l'action en bas. Chaque action passe par la barre de forge : elle
## se remplit pendant 0,8 à 1,6 s, puis le verdict s'affiche, vert « Réussi » ou rouge « Raté ». Le hasard est
## tiré au moment du clic (aucune règle changée) : l'animation est un habillage, la logique reste celle de
## Profile / Craft / Forge.

const BENCHES := [
	["upgrade", "Améliorer", "upgrade", 1.5],
	["enchant", "Enchanter", "power", 1.2],
	["gems", "Gemmes", "gem", 1.0],
	["polish", "Polir", "new", 1.2],
	["reforge", "Réajuster", "all", 1.0],
	["dismantle", "Démonter", "dismantle", 0.8],
]
## Mots d'un résultat qui le rendent « raté » (bandeau rouge).
const FAIL_WORDS := ["Échec", "échec", "pas mieux", "Pas assez", "Il faut", "Aucun", "Aucune", "Déjà", "introuvable", "Pas d'emplacement", "maximale", "ne change pas", "brisent"]

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
	if _pinned:
		for c in _pinned.get_children():
			_pinned.remove_child(c)
			c.queue_free()
	super._on_selection()


func show_detail(sel: Array) -> void:
	_sync_tabs()
	if sel.is_empty():
		detail.text = "[center]\n[img=72x72]%s[/img]\n\n[font_size=20][b]Choisis une pièce[/b][/font_size]\n[color=#c8c8d4]dans la grille, à gauche.[/color][/center]" % Items.material_icon("crystal")
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
		"dismantle":
			_dismantle(it)


## Nom, type et qualité de la pièce : les trois premières lignes de sa fiche.
func _head_text(it: Dictionary) -> String:
	return "\n".join(Array(Items.describe(it).split("\n")).slice(0, 3))


## Rangée des six établis (construite une fois).
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
	keys.sort_custom(func(a, b):
		var pa: bool = a in Items.PERCENT_STATS
		var pb: bool = b in Items.PERCENT_STATS
		return (not pa and pb) if pa != pb else float(sb[a]) > float(sb[b]))
	for s in keys.slice(0, MAIN_STATS):
		rows.append([Items.STAT_NAMES.get(s, Items.EXTRA_STAT_NAMES.get(s, s)), stat_num(s, float(sb[s])), stat_num(s, float(sa[s])), 1])
	if (up + 1) in Items.MILESTONES:
		rows.append(["Stat bonus", "—", "+1 au hasard", 1])
	detail.text = _head_text(it) + "\n\n" + ba_table(rows) + "\n\n" + (cost_line(cost) if not cost.is_empty() else "[color=#c8c8d4]Coût[/color]   [b]gratuit[/b]")


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
		rows.append(["Gemme %d" % (i + 1), Craft.label(Craft.gem_key(String(g.type), int(g.tier))) if g is Dictionary else "vide", "", 0])
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
	for stat in stats:
		var s: String = stat
		var cur := float(it.base[s]) if it.has("base") and it.base.has(s) else float(it.get("affixes", {}).get(s, 0.0))
		var k := 1.0 if s in Items.PERCENT_STATS or not it.has("base") else Items._level_k(Items.power_level(it))
		rows.append([Items.STAT_NAMES.get(s, Items.EXTRA_STAT_NAMES.get(s, s)), Items.stat_text(s, cur * k), "nouveau jet", 0])
		button("Réajuster %s · %s" % [Items.STAT_NAMES.get(s, Items.EXTRA_STAT_NAMES.get(s, s)), MerchantPages.price_words(rc)],
			func(): done(Forge.reforge(it, s)), Profile.can_afford(rc))
	detail.text = _head_text(it)
	if stats.is_empty():
		detail.text += "\n\n[color=#c8c8d4]Pas de stat bonus à réajuster : elles viennent des paliers +4, +6, +8 et +10.[/color]"
		return
	detail.text += "\n\n" + ba_table(rows) + "\n\n" + cost_line(rc)
	_note("Le nouveau jet remplace l'ancien, en mieux ou en moins bien.")


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
	_bar.verdict(not _is_fail(msg), msg)
	super.done(msg, duration)


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

	func _process(delta: float) -> void:
		if _working:
			_dots += delta * 4.0
			_title.text = "Forge en cours" + ".".repeat(int(_dots) % 4)

	func verdict(ok: bool, text: String) -> void:
		_working = false
		visible = true
		_bar.value = 1.0
		var col := Color(0.35, 0.95, 0.45) if ok else Color(1.0, 0.4, 0.38)
		_style(Color(0.05, 0.2, 0.08, 0.97) if ok else Color(0.24, 0.05, 0.06, 0.97), col)
		_title.text = "RÉUSSI" if ok else "RATÉ"
		_title.add_theme_color_override("font_color", col)
		_bar.add_theme_stylebox_override("fill", UiTheme.flat_box(col.darkened(0.25), col, 1, 5, false))
		_msg.text = text.replace("\n", " · ")
		# petit rebond du bandeau
		pivot_offset = size * 0.5
		scale = Vector2(1.04, 1.04)
		var t := create_tween()
		t.tween_property(self, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
