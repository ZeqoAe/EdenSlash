class_name QuestBadge
extends PanelContainer
## La quête suivie dans le HUD (passe M5, lot HUB-1 P0-6) : une ligne sous les objectifs, avec sa jauge fine. C'est la quête
## épinglée dans le Journal (« ★ », même d'une autre activité), sinon la quête de l'activité jouée la plus avancée
## (« Vaincre 10 élites en Survie  7 / 10 »). Quand une quête est accomplie, une carte l'annonce une fois, par la file
## unique des notifications du HUD (HudNotices, priorité « quête »). Cachée hors partie, à l'entraînement et sans quête.

const ANNOUNCE_SECONDS := 9.0

var hud: Node  # le HUD : sa file `notices` (sinon sa pile de cartes `_cards`) sert à l'annonce
var pinned := false  # (tests) la ligne montre la quête épinglée
var _star: Label  # pastille ★ (soleil : épinglée)
var _title: Label
var _count: Label
var _bar: ProgressBar
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
	# lot HUD-2 (croquis BM-HUB) : puits d'encre translucide contouré, pastille soleil ★ (papier si la quête n'est pas
	# épinglée), texte papier, compteur en chiffres, jauge fine soleil contourée
	var sb := UiTheme.well_style(Vector2(10, 6), 14)
	sb.bg_color = Color(UiTheme.color("encre.500"), 0.88)
	add_theme_stylebox_override("panel", sb)
	size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(Hud.PANEL_W, 0)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(v)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(h)
	_star = Label.new()
	_star.text = "★"
	_star.add_theme_font_override("font", UiTheme.bold_font())
	_star.add_theme_font_size_override("font_size", 14)
	_star.add_theme_color_override("font_color", Color.WHITE)
	_star.add_theme_color_override("font_outline_color", UiTheme.color("encre.700"))
	_star.add_theme_constant_override("outline_size", 4)
	_star.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_star.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(_star)
	_title = _label(h, UiTheme.color("papier.100"), 15)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_title.custom_minimum_size = Vector2(Hud.PANEL_W - 130.0, 0)
	_count = _label(h, UiTheme.color("bonbon.soleil.clair"), 15)
	_count.add_theme_font_override("font", UiTheme.number_font())
	_count.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_bar = QuestsPage._bar(0.0, 1.0)
	_bar.custom_minimum_size = Vector2(0, 8)
	var bg := StyleBoxFlat.new()
	bg.bg_color = UiTheme.color("encre.900")
	bg.border_color = UiTheme.color("encre.900")
	bg.set_border_width_all(2)
	bg.set_corner_radius_all(4)
	_bar.add_theme_stylebox_override("background", bg)
	v.add_child(_bar)
	_paint_star(false)
	visible = false


## Pastille de la quête : soleil si elle est épinglée au Journal, papier sinon (la plus avancée de l'activité).
func _paint_star(on: bool) -> void:
	_star.add_theme_stylebox_override("normal", UiTheme.sticker("soleil" if on else "papier2", {"radius": 9, "shadow": 2,
		"pad": Vector2(5, 0), "gloss": false, "cel_top": 0.0, "cel_bottom": 0.0}))
	_star.add_theme_color_override("font_color", Color.WHITE if on else UiTheme.color("encre.700"))
	_star.add_theme_constant_override("outline_size", 4 if on else 0)


func _label(parent: Control, col: Color, size: int) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_font_override("font", UiTheme.bold_font())
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", UiTheme.color("encre.700"))
	l.add_theme_constant_override("outline_size", 4)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l


func _process(delta: float) -> void:
	_t -= delta
	if _t > 0.0:
		return
	_t = 0.5
	refresh()


## La quête à montrer : {q, pinned, live} ou {} (rien à suivre).
static func pick() -> Dictionary:
	var act := Quests.current_act()
	if act == "" or not Quests.enabled():
		return {}
	var pin := Quests.pinned()
	if not pin.is_empty():
		var a := String(Quests.def_of(pin.q).get("act", ""))
		return {"q": pin.q, "pinned": true, "live": a == act or a == "any"}
	var list := Quests.current_quests()
	return {} if list.is_empty() else {"q": list[0], "pinned": false, "live": true}


## Met la ligne à jour et annonce les quêtes accomplies (appelée deux fois par seconde).
func refresh() -> void:
	var p := pick()
	visible = not p.is_empty() and HudV2.shows("quest")  # (profil Minimal du HUD : pas de quête suivie, lot HUD-2)
	if not p.is_empty():
		var q: Dictionary = p.q
		var prog := Quests.live_progress(q) if bool(p.live) else int(q.p)
		var sig := "%s|%d|%s" % [q.id, prog, p.pinned]
		if sig != _sig:
			_sig = sig
			pinned = bool(p.pinned)
			var an := Quests.act_name(q)
			var where := "" if bool(p.live) or an in ["", "Toutes"] or Quests.title(q).contains(an) else " · " + an
			_title.text = Quests.title(q) + where  # (l'épingle est la pastille ★ soleil, lot HUD-2)
			_paint_star(pinned)
			_count.text = "%d / %d" % [prog, int(q.t)] if int(q.t) > 1 else "à faire"
			_bar.visible = int(q.t) > 1
			_bar.max_value = float(maxi(1, int(q.t)))
			_bar.value = float(prog)
	for done in Quests.tick():
		_announce(done)


func _announce(done: Dictionary) -> void:
	_n += 1
	var body := String(done.title)
	if String(done.reward) != "":
		body += "\nÀ la fin de la partie : %s" % String(done.reward)
	var spec := {"id": "quest_done_%d" % _n, "title": "Quête accomplie", "body": body, "icon": "new", "duration": ANNOUNCE_SECONDS,
		"buttons": [{"label": "Compris", "kind": "primary"}]}
	var notices = hud.get("notices") if hud != null else null
	if notices is HudNotices:
		notices.push("quest", spec)
		return
	var cards = hud.get("_cards") if hud != null else null
	if cards is InfoCard:
		cards.add_card(spec)
