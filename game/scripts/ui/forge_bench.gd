class_name ForgeBench
extends MerchantPages.ForgePage
## Atelier > Forge (idée du joueur) : une seule grande page pour tout ce qui se fait sur un objet, rangée en
## six établis : Améliorer (fortification +1 à +10), Enchanter, Gemmes (percer, sertir, fusionner), Polir (qualité),
## Réajuster (relancer une stat bonus) et Démonter (cristaux). Chaque action passe par la barre de forge : elle
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

## Tests : la barre se remplit presque aussitôt.
static var fast := false

var bench := "upgrade"
var _bar: ForgeBar
var _busy := false
var _armed_at := -10.0  # démontage : second clic pour confirmer


func _init() -> void:
	super._init()
	grid_cols = 7
	right_width = 760.0
	title = "Forge"
	hint = "Choisis une pièce (portée ou dans ton coffre), puis un établi. Hors run, les fournitures de ta réserve servent et l'or est remplacé par des cristaux."


func _ready() -> void:
	super._ready()
	# la barre de forge reste en haut de la colonne de droite (les actions, elles, se reconstruisent)
	var sc := detail.get_parent().get_parent()
	var right := sc.get_parent()
	_bar = ForgeBar.new()
	right.add_child(_bar)
	right.move_child(_bar, sc.get_index())
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


func show_detail(sel: Array) -> void:
	_bench_tabs()
	if sel.is_empty():
		detail.text = "[b]Forge[/b]\n\nChoisis une pièce dans la grille, puis un établi.\n\nTes cristaux : [b]%d[/b]%s" % [Profile.amount("crystal"),
			(" · ton or : [b]%d[/b]" % Profile.gold) if Profile.in_run else "\n[color=#c8c8d4]Hors run : les fournitures de ta réserve servent, et l'or est remplacé par des cristaux (1 pour %d or).[/color]" % Forge.GOLD_PER_CRYSTAL]
		if bench == "gems":
			_fusion()
		return
	var it: Dictionary = sel[0]
	detail.text = Items.describe(it)
	if Items.is_unique(it) and bench != "dismantle":
		detail.text += "\n\n[color=#ffb347]%s[/color]" % Items.UNIQUE_TEXT
		return
	match bench:
		"upgrade":
			_upgrade(it)
		"enchant":
			_enchant(it)
		"gems":
			_gems(it)
			_fusion()
		"polish":
			_polish(it)
		"reforge":
			_reforge(it)
		"dismantle":
			_dismantle(it)


## Rangée des six établis.
func _bench_tabs() -> void:
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 6)
	row.add_theme_constant_override("v_separation", 6)
	actions.add_child(row)
	for b in BENCHES:
		var id: String = b[0]
		var btn := Button.new()
		btn.text = String(b[1])
		btn.toggle_mode = true
		btn.button_pressed = id == bench
		btn.focus_mode = Control.FOCUS_NONE
		btn.custom_minimum_size = Vector2(96, 34)
		btn.add_theme_font_size_override("font_size", 14)
		var on := UiTheme.flat_box(Color(0.3, 0.22, 0.08, 1.0), UiTheme.GOLD, 2, 8, false)
		var off := UiTheme.flat_box(Color(0.1, 0.08, 0.16, 0.95), UiTheme.GOLD_DIM, 1, 8, false)
		btn.add_theme_stylebox_override("normal", off)
		btn.add_theme_stylebox_override("pressed", on)
		btn.add_theme_stylebox_override("hover_pressed", on)
		btn.add_theme_stylebox_override("hover", UiTheme.flat_box(Color(0.18, 0.14, 0.28, 1.0), UiTheme.GOLD, 1, 8, false))
		btn.pressed.connect(func():
			if _busy:
				return
			bench = id
			_armed_at = -10.0
			_on_selection())
		row.add_child(btn)


func _polish(it: Dictionary) -> void:
	var pc := Forge.polish_cost(it)
	var q := float(it.get("quality", 1.0))
	var qmax := float(Items.QUALITY[clampi(int(it.get("rarity", 0)), 0, Items.QUALITY.size() - 1)][1])
	_head("Polir la qualité (%d %%, au mieux %d %%)" % [roundi(q * 100.0), roundi(qmax * 100.0)])
	_note("Un nouveau jet de qualité ; il n'est gardé que s'il est meilleur. Coût : %s (tu as %d cristaux)." % [ItemWidgets.materials_text(pc, true), Profile.amount("crystal")])
	button("Polir · %s" % ItemWidgets.materials_text(pc, true), func(): done(Forge.polish(it)), Profile.can_afford(pc) and q < qmax, true)


func _reforge(it: Dictionary) -> void:
	var rc := Forge.reforge_cost(it)
	_head("Réajuster une stat bonus (tu as %d cristaux)" % Profile.amount("crystal"))
	_note("Une stat bonus d'amélioration ne te convient pas ? Relance-la au hasard dans sa fourchette : le nouveau jet remplace l'ancien, mieux ou moins bien.")
	for stat in Forge.reforgeable(it):
		var s: String = stat
		var cur := float(it.base[s]) if it.has("base") and it.base.has(s) else float(it.get("affixes", {}).get(s, 0.0))
		var k := 1.0 if s in Items.PERCENT_STATS or not it.has("base") else Items._level_k(Items.power_level(it))
		button("Réajuster %s (%s) · %s" % [Items.STAT_NAMES.get(s, Items.EXTRA_STAT_NAMES.get(s, s)), Items.stat_text(s, cur * k), ItemWidgets.materials_text(rc, true)],
			func(): done(Forge.reforge(it, s)), Profile.can_afford(rc))
	if Forge.reforgeable(it).is_empty():
		_note("Pas de stat bonus à réajuster : elles viennent des améliorations +4, +6, +8 et +10 (les mythiques et légendaires ont des stats fixes).")


func _dismantle(it: Dictionary) -> void:
	var y := Items.disassemble_yield(it)
	var worn := _worn(it)
	_head("Démonter")
	_note("Rend %s. L'objet disparaît." % ItemWidgets.materials_text(y))
	if worn:
		_note("Retire d'abord la pièce portée (page Héros).")
	var users := Profile.item_users(String(it.get("uid", "")))
	if not users.is_empty():
		_note("Attention : utilisé par le préréglage de %s." % ", ".join(users))
	var armed := now() - _armed_at < 3.0
	button(("Confirmer : démonter %s ?" % Items.display_name(it)) if armed else "Démonter · %s" % ItemWidgets.materials_text(y, true), func():
		if now() - _armed_at > 3.0:
			_armed_at = now()
			_on_selection()
			return
		_armed_at = -10.0
		_run(func():
			var got := Profile.disassemble(it)
			grid.clear_selection()
			done("Démonté : %s" % ItemWidgets.materials_text(got, true), 2.0)), not worn, true)


## Toute action d'établi passe par la barre de forge ; les cases de choix (pierre, parchemin béni) non.
func button(text: String, cb: Callable, enabled := true, accent := false) -> Button:
	if text.begins_with("☑") or text.begins_with("☐") or text.begins_with("Confirmer : démonter") or text.begins_with("Démonter ·"):
		return super.button(text, cb, enabled, accent)
	return super.button(text, func(): _run(cb), enabled, accent)


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
	for c in actions.get_children():
		_disable(c)
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


## Barre de forge : repos, chauffe (la barre se remplit), verdict vert ou rouge.
class ForgeBar extends PanelContainer:
	var _title: Label
	var _bar: ProgressBar
	var _msg: Label
	var _tw: Tween
	var _dots := 0.0
	var _working := false

	func _init() -> void:
		custom_minimum_size = Vector2(0, 92)
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 4)
		add_child(v)
		_title = Hud._label(v, "", 20, Color.WHITE)
		_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_bar = ProgressBar.new()
		_bar.min_value = 0.0
		_bar.max_value = 1.0
		_bar.show_percentage = false
		_bar.custom_minimum_size = Vector2(0, 18)
		_bar.add_theme_stylebox_override("background", UiTheme.flat_box(Color(0.06, 0.05, 0.1, 1.0), UiTheme.GOLD_DIM, 1, 6, false))
		_bar.add_theme_stylebox_override("fill", UiTheme.flat_box(Color(0.95, 0.6, 0.15), Color(1.0, 0.85, 0.4), 1, 6, false))
		v.add_child(_bar)
		_msg = Hud._label(v, "", 14, Color(0.85, 0.85, 0.92))
		_msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		idle()

	func _style(fill: Color, border: Color) -> void:
		add_theme_stylebox_override("panel", UiTheme.flat_box(fill, border, 2, 10))

	func idle() -> void:
		_working = false
		_style(Color(0.07, 0.06, 0.12, 0.95), UiTheme.GOLD_DIM)
		_title.text = "Forge prête"
		_title.add_theme_color_override("font_color", UiTheme.MUTED)
		_bar.value = 0.0
		_msg.text = "Choisis un établi, puis lance l'action."

	func work(secs: float, done_cb: Callable) -> void:
		_working = true
		_dots = 0.0
		_style(Color(0.16, 0.1, 0.04, 0.97), Color(1.0, 0.7, 0.25))
		_title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.5))
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
		_bar.value = 1.0
		var col := Color(0.35, 0.95, 0.45) if ok else Color(1.0, 0.4, 0.38)
		_style(Color(0.05, 0.2, 0.08, 0.97) if ok else Color(0.24, 0.05, 0.06, 0.97), col)
		_title.text = "RÉUSSI" if ok else "RATÉ"
		_title.add_theme_color_override("font_color", col)
		_bar.add_theme_stylebox_override("fill", UiTheme.flat_box(col.darkened(0.25), col, 1, 6, false))
		_msg.text = text.replace("\n", " · ")
		# petit rebond du bandeau
		pivot_offset = size * 0.5
		scale = Vector2(1.04, 1.04)
		var t := create_tween()
		t.tween_property(self, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
