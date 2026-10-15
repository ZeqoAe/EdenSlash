class_name QuestBadge
extends PanelContainer
## La quête en cours dans le HUD (passe M5) : une petite ligne discrète sous les objectifs, la quête de l'activité jouée qui
## est la plus avancée (« Vaincre 10 élites en Survie  7 / 10 »). Quand une quête est accomplie, une petite carte
## d'information (InfoCard) l'annonce une fois. Cachée hors partie, à l'entraînement et sans quête pour cette activité.

const ANNOUNCE_SECONDS := 9.0

var hud: Node  # le HUD : sa pile de cartes `_cards` sert à l'annonce
var _title: Label
var _count: Label
var _sig := ""
var _t := 0.0
var _n := 0


## Pastille ajoutée dans la pile en haut à gauche du HUD ([param stack]), sous les objectifs et la Menace.
static func attach(stack: Control, h: Node) -> QuestBadge:
	var b := QuestBadge.new()
	b.hud = h
	stack.add_child(b)
	return b


func _ready() -> void:
	add_theme_stylebox_override("panel", UiTheme.flat_box(Color(0.05, 0.05, 0.12, 0.62), Color(UiTheme.GOLD_DIM, 0.45), 1, 8, false))
	size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(h)
	_title = _label(h, UiTheme.MUTED, 13)
	_count = _label(h, UiTheme.GOLD, 14)
	visible = false


func _label(parent: Control, col: Color, size: int) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_font_override("font", UiTheme.bold_font())
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0.04, 0.03, 0.08))
	l.add_theme_constant_override("outline_size", 3)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l


func _process(delta: float) -> void:
	_t -= delta
	if _t > 0.0:
		return
	_t = 0.5
	refresh()


## Met la ligne à jour et annonce les quêtes accomplies (appelée deux fois par seconde).
func refresh() -> void:
	var list := Quests.current_quests()
	visible = not list.is_empty()
	if not list.is_empty():
		var q: Dictionary = list[0]
		var sig := "%s|%d" % [q.id, Quests.live_progress(q)]
		if sig != _sig:
			_sig = sig
			_title.text = Quests.title(q)
			_count.text = "%d / %d" % [Quests.live_progress(q), int(q.t)] if int(q.t) > 1 else "à faire"
	for done in Quests.tick():
		_announce(done)


func _announce(done: Dictionary) -> void:
	var cards = hud.get("_cards") if hud != null else null
	if cards == null or not cards is InfoCard:
		return
	_n += 1
	var body := String(done.title)
	if String(done.reward) != "":
		body += "\nÀ la fin de la partie : %s" % String(done.reward)
	cards.add_card({"id": "quest_done_%d" % _n, "title": "Quête accomplie", "body": body, "icon": "new", "duration": ANNOUNCE_SECONDS,
		"buttons": [{"label": "Compris", "kind": "primary"}]})
