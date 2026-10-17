class_name AutochessGuide
extends PanelContainer
## L'Échiquier, lot ACX-3 (étude BM-AUTO §6 n° 21) : la première partie guidée. Quatre étapes courtes (acheter, placer,
## une étoile, un trait), dans une bulle papier sous la frise de l'étape : rien ne s'arrête, rien n'est bloqué, chaque
## étape se coche quand le joueur l'a faite (dans n'importe quel ordre), « Passer le guide » le ferme pour de bon.
## Fin ou passage : Settings « autochess » / « guide_done » (une fois par joueur) ; les trois fiches de découverte qu'il
## remplace (ac_shop, ac_stars, ac_traits) sont alors marquées vues. Jouable à la manette (le bouton est un Button : UiNav).

signal finished(skipped: bool)

const STEPS := [
	{"id": "buy", "title": "Achète un héros", "body": "Clique une carte de la boutique (touches 1 à 5, A à la manette)."},
	{"id": "place", "title": "Place-le sur le plateau", "body": "Glisse un héros du banc sur une case de ton camp (W, ou A puis A)."},
	{"id": "star", "title": "Trois copies, une étoile", "body": "Achète trois fois le même héros : ils fusionnent en un héros plus fort."},
	{"id": "trait", "title": "Réunis un trait", "body": "Des héros d'un même trait, sur le plateau, allument la colonne de gauche."},
]
const TIPS_REPLACED := ["ac_shop", "ac_stars", "ac_traits"]
const W := 440.0

var done := {}  # id d'étape -> vrai
var skip_button: Button
var _title: Label
var _body: Label
var _count: Label
var _pips: Pips
var _closing := false


## Le guide est-il à montrer (première partie, jamais fini ni passé) ?
static func wanted() -> bool:
	return not bool(Settings.get_v("autochess", "guide_done"))


func _init() -> void:
	name = "AcGuide"
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_theme_stylebox_override("panel", AutochessHud.paper_panel(6.0, 14.0, 9.0, 16.0))
	anchor_left = 0.5
	anchor_right = 0.5
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	offset_top = AutochessHud.s(AutochessHud.TOP_Y)
	custom_minimum_size.x = AutochessHud.s(W)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", roundi(AutochessHud.s(3.0)))
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(v)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", roundi(AutochessHud.s(8.0)))
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(head)
	_count = AutochessHud.ink_lbl("", 13, Color.WHITE, 900)
	_count.add_theme_stylebox_override("normal", AutochessHud.sticker(AutochessHud.candy("lagon"), 9.0, 0.0, 2.0, 8.0, 1.0))
	_count.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(_count)
	_title = AutochessHud.pop_lbl("", 19, AutochessHud.INK)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_title)
	_pips = Pips.new()
	_pips.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(_pips)
	_body = AutochessHud.ink_lbl("", 15, AutochessHud.INK, 700)
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.custom_minimum_size.x = AutochessHud.s(W) - AutochessHud.s(30.0)
	v.add_child(_body)
	var foot := HBoxContainer.new()
	foot.alignment = BoxContainer.ALIGNMENT_END
	foot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(foot)
	skip_button = AutochessHud.button("Passer le guide", "plain", 30.0)
	skip_button.name = "AcGuideSkip"
	skip_button.tooltip_text = "Le guide ne reviendra plus. Les règles restent dans le Guide (F1)."
	skip_button.pressed.connect(func(): close(true))
	foot.add_child(skip_button)
	_show()


## Étape courante (la première pas encore faite), "" si tout est fait.
func current() -> String:
	for s in STEPS:
		if not done.has(String(s.id)):
			return String(s.id)
	return ""


## Marque l'étape [param id] faite (sans effet si déjà faite ou guide fermé).
func step_done(id: String) -> void:
	if _closing or done.has(id) or not STEPS.any(func(s): return String(s.id) == id):
		return
	done[id] = true
	UiFeel.cue("confirm", -10.0, 1.1 + 0.06 * done.size(), [0.1, 0.0, 0.04])
	if not UiFeel.reduce_motion:
		UiFeel.sparkle(_count.get_global_rect().get_center(), 4, ["pomme", "soleil", "lagon", "fraise"])
	if current() == "":
		_title.text = "Bravo !"
		_body.text = "Tu connais l'essentiel. Gagne tes combats, garde ton or : il rapporte des intérêts."
		_count.text = "4 / 4"
		_pips.n = done.size()
		_pips.queue_redraw()
		skip_button.visible = false
		var tw := create_tween()
		tw.tween_interval(3.0)
		tw.tween_callback(close.bind(false))
		return
	_show()


## Lit l'état de la partie : les étapes déjà vraies se cochent (une reprise, un héros donné par un atout…).
func observe(g: Autochess, pi: int) -> void:
	if g == null or _closing:
		return
	var p: Dictionary = g.players[pi]
	if int(p.stats.gold_spent) > 0 or int(p.get("buys", 0)) > 0:
		step_done("buy")
	# (placer : compté par l'écran au dépôt sur une case ; le plateau se remplit aussi seul en fin de préparation)
	for u in g.units_of(pi):
		if int(u.stars) >= 2:
			step_done("star")
			break
	if not g.active_traits(pi).is_empty() and g.phase == "prep":
		step_done("trait")


## Ferme le guide pour de bon ([param skipped] : passé par le joueur) : réglage gardé, fiches remplacées marquées vues.
func close(skipped: bool) -> void:
	if _closing:
		return
	_closing = true
	Settings.set_v("autochess", "guide_done", true)
	for id in TIPS_REPLACED:
		Tutorial.mark_seen(id)
	finished.emit(skipped)
	if UiFeel.reduce_motion or not is_inside_tree():
		queue_free()
		return
	UiFeel.pop_out(self, queue_free)


func _show() -> void:
	var cur := current()
	var k := 0
	for i in STEPS.size():
		if String(STEPS[i].id) == cur:
			k = i
	_count.text = "Premiers pas · %d / %d" % [mini(done.size() + 1, STEPS.size()), STEPS.size()]
	_title.text = String(STEPS[k].title)
	_body.text = String(STEPS[k].body)
	_pips.n = done.size()
	_pips.queue_redraw()


## Quatre pastilles (pomme = étape faite).
class Pips extends Control:
	var n := 0

	func _init() -> void:
		custom_minimum_size = Vector2(AutochessHud.s(62.0), AutochessHud.s(14.0))
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var r := AutochessHud.s(5.5)
		for i in AutochessGuide.STEPS.size():
			var c := Vector2(r + 1.0 + i * r * 2.6, size.y * 0.5)
			draw_circle(c, r, AutochessHud.candy("pomme") if i < n else AutochessHud.PAPER)
			draw_arc(c, r, 0.0, TAU, 16, AutochessHud.INK, 1.5, true)
