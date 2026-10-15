class_name CardPicker
extends CanvasLayer
## Choix de cartes (nouvelle compétence, amélioration, passif) au passage de
## niveau et au départ de la run. Met le jeu en pause pendant le choix.
## Un seul geste : cliquer une carte (ou 1, 2, 3, ou A à la manette) la choisit. Pendant les
## 0,3 premières secondes les cartes sont voilées et ignorent tout : on ne choisit pas par
## erreur en spammant l'auto-attaque au moment du passage de niveau.
## Manette : le cadre doré se pose sur la 1re carte dès l'ouverture (A la choisit, la croix change de carte).
## Le jeu reste en pause tant qu'un choix est ouvert, même si un fondu (entrée dans l'arène du boss) se
## termine pendant le choix : les écrans qui tiennent la pause sont dans le groupe [constant PAUSE_GROUP].

signal picked(card: Dictionary)

const ACCENT := Color(0.98, 0.78, 0.35)
## Couleur des cartes sans rareté (nouveau sort, enchaînement) : un vert menthe que ni le bleu rare, ni le violet épique,
## ni l'orange légendaire ne confondent. Les autres cartes portent la couleur de leur rareté.
const TYPE_COLORS := {"skill": Color(0.35, 0.95, 0.72), "chain": Color(0.55, 0.98, 0.85), "upgrade": Color(0.85, 0.85, 0.88), "weapon_up": Color(0.85, 0.85, 0.88), "passive": Color(0.85, 0.85, 0.88)}
const CONFIRM_DELAY_MS := 300  # cartes inertes juste après l'ouverture (clics en rafale)
const VEIL_ALPHA := 0.45  # opacité des cartes pendant ce délai
const MAX_STATS := 4  # lignes de statistiques d'une pièce (hors comparaison, set et passif)
## Groupe des écrans qui tiennent la pause tant qu'ils sont ouverts (is_open()) : choix de carte, fondu.
const PAUSE_GROUP := "pause_modal"

var _queue: Array = []  # [titre, cartes, relance (Callable)]
var _reroll_fn: Callable
var _reroll: Button
var _cards: Array = []
var _root: Control
var _title: Label
var _row: HBoxContainer
var _buttons: Array = []
var _opened_at := 0
var _shared: RichTextLabel  # lignes communes à toutes les cartes d'équipement, dites une fois
var _pad_focus := false  # nouveau choix : le cadre de la manette ira sur la 1re carte une fois la rangée posée


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group(PAUSE_GROUP)
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.01, 0.05, 0.72)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)
	var center := CenterContainer.new()  # le bloc est centré quelle que soit la hauteur de l'écran (720 p compris)
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(center)
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 18)
	v.custom_minimum_size = Vector2(1120, 0)
	center.add_child(v)
	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiTheme.title(_title, 40, ACCENT)
	v.add_child(_title)
	_row = HBoxContainer.new()
	_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_row.add_theme_constant_override("separation", 28)
	v.add_child(_row)
	var cd := StyleBoxFlat.new()
	cd.bg_color = Color(0.2, 0.18, 0.28, 0.9)
	cd.set_corner_radius_all(10)
	_reroll = Button.new()
	_reroll.custom_minimum_size = Vector2(200, 56)
	_reroll.focus_mode = Control.FOCUS_NONE
	_reroll.add_theme_font_size_override("font_size", 18)
	var rs := StyleBoxFlat.new()
	rs.bg_color = Color(0.16, 0.13, 0.26, 0.95)
	rs.border_color = Color(0.6, 0.55, 0.85)
	rs.set_border_width_all(2)
	rs.set_corner_radius_all(10)
	_reroll.add_theme_stylebox_override("normal", rs)
	var rh := rs.duplicate() as StyleBoxFlat
	rh.bg_color = Color(0.26, 0.2, 0.4)
	_reroll.add_theme_stylebox_override("hover", rh)
	_reroll.add_theme_stylebox_override("pressed", rh)
	_reroll.add_theme_stylebox_override("disabled", cd)
	_reroll.pressed.connect(_do_reroll)
	_shared = RichTextLabel.new()
	_shared.bbcode_enabled = true
	_shared.fit_content = true
	_shared.scroll_active = false
	_shared.add_theme_font_size_override("normal_font_size", 17)
	_shared.add_theme_font_override("normal_font", UiTheme.bold_font())
	_shared.add_theme_color_override("default_color", Color(0.85, 0.85, 0.92))
	_shared.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(_shared)
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_child(_reroll)
	v.add_child(buttons)
	_root.visible = false
	add_child(_root)


## Ajoute un choix à la file (plusieurs niveaux d'un coup = plusieurs choix).
## [param reroll] : tire de nouvelles cartes (bouton « Relancer », limité par run).
## [param own_rerolls] : relances propres à ce choix (coffre d'emplacement : 1) ; -1 : celles
## de la run (Run.rerolls_left).
func offer(title: String, cards: Array, reroll := Callable(), own_rerolls := -1) -> void:
	if cards.is_empty():
		return
	_queue.append([title, cards, reroll, own_rerolls])
	if not _root.visible:
		_show_next()


func is_open() -> bool:
	return _root.visible


## Un autre écran du groupe [constant PAUSE_GROUP] (que [param except]) est ouvert : la pause doit rester.
static func pause_held(tree: SceneTree, except: Node = null) -> bool:
	for n in tree.get_nodes_in_group(PAUSE_GROUP):
		if n != except and n.has_method("is_open") and n.is_open():
			return true
	return false


func _show_next() -> void:
	if _queue.is_empty():
		_root.visible = false
		get_tree().paused = pause_held(get_tree(), self)
		return
	var item: Array = _queue.pop_front()
	_title.text = item[0]
	_reroll_fn = item[2] if item.size() > 2 else Callable()
	_own_rerolls = int(item[3]) if item.size() > 3 else -1
	_pad_focus = true
	_show_cards(item[1])
	var host := get_parent()
	if host and "hud" in host and host.hud:
		host.hud.hide_banner()  # pas d'annonce sous le titre du choix
	_root.visible = true
	get_tree().paused = true


func _show_cards(cards: Array) -> void:
	_cards = cards
	for c in _row.get_children():
		c.queue_free()
	_buttons.clear()
	var descs := _descriptions(_cards)
	_shared.text = "[center]%s[/center]" % descs.shared if descs.shared != "" else ""
	_shared.visible = descs.shared != ""
	for i in _cards.size():
		var b := _make_card(_cards[i], i, String(descs.each[i]))
		_buttons.append(b)
		_row.add_child(b)
	_opened_at = Time.get_ticks_msec()
	_row.modulate.a = VEIL_ALPHA
	_refresh_reroll()
	_fit_heights()


## Cartes de même hauteur, assez hautes pour tout leur texte (jamais de ligne coupée).
func _fit_heights() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var tallest := 380.0
	for b in _buttons:
		if is_instance_valid(b):
			tallest = maxf(tallest, (b.get_meta("content") as Control).get_combined_minimum_size().y + 36.0)
	for b in _buttons:
		if is_instance_valid(b):
			b.custom_minimum_size.y = minf(tallest, 470.0)
	if _pad_focus and _root.visible and not _buttons.is_empty() and is_instance_valid(_buttons[0]):
		_pad_focus = false
		UiNav.focus(_buttons[0])  # manette : la 1re carte est désignée tout de suite (sans effet à la souris)


## Textes des cartes : pour l'équipement, les lignes identiques sur toutes les cartes (« Emplacement
## libre », les mêmes +3 Force des deux variantes d'une arme) sont dites une seule fois sous la rangée,
## et une pièce n'affiche que ses [constant MAX_STATS] premières statistiques.
## Renvoie {each: texte de chaque carte, shared: ligne commune (BBCode) ou ""}.
func _descriptions(cards: Array) -> Dictionary:
	var each: Array = []
	var lines: Array = []
	var gear := cards.size() >= 2
	for c in cards:
		each.append(String(c.desc))
		gear = gear and c.has("item")
		lines.append(String(c.desc).split("\n"))
	if not gear:
		return {"each": each, "shared": ""}
	var common: Array = []
	for l in lines[0]:
		if String(l) != "" and lines.all(func(ls): return (ls as PackedStringArray).has(l)):
			common.append(String(l))
	for i in cards.size():
		var kept: PackedStringArray = []
		var stats := 0
		var is_weapon := String(cards[i].item.get("slot", "")) == "weapon"
		for j in (lines[i] as PackedStringArray).size():
			var l: String = lines[i][j]
			if common.has(l):
				continue
			if j > 0 and not is_weapon and not l.begins_with("[color=#66f28c]") and not l.begins_with("[color=#ffd36b]"):
				stats += 1
				if stats > MAX_STATS:
					continue
			kept.append(l)
		each[i] = "\n".join(kept)
	return {"each": each, "shared": "  ·  ".join(PackedStringArray(common))}


var _own_rerolls := -1


func _rerolls_left() -> int:
	return _own_rerolls if _own_rerolls >= 0 else Run.rerolls_left()


func _refresh_reroll() -> void:
	_reroll.visible = _reroll_fn.is_valid()
	var left := _rerolls_left()
	_reroll.text = "Relancer (%d)" % left
	_reroll.disabled = left <= 0


## Nouvelles cartes à la place des cartes proposées (une relance consommée).
func _do_reroll() -> void:
	if not _reroll_fn.is_valid() or _rerolls_left() <= 0:
		return
	var cards: Array = _reroll_fn.call()
	if cards.is_empty():
		return
	if _own_rerolls >= 0:
		_own_rerolls -= 1
	else:
		Run.rerolls_used += 1
	_show_cards(cards)
	_opened_at -= CONFIRM_DELAY_MS  # pas de délai anti-rafale après une relance volontaire
	_row.modulate.a = 1.0


func _make_card(card: Dictionary, i: int, desc: String) -> Button:
	# couleur : rareté tirée de la carte (Cards), sinon type de carte
	var col: Color = TYPE_COLORS.get(card.type, ACCENT)
	if card.has("tier") and Cards.TIERS.has(String(card.tier)):
		col = Cards.tier(String(card.tier)).color  # la couleur est celle de la rareté, commune comprise (gris clair)
	elif card.has("rarity") and Boons.RARITY.has(String(card.rarity)):
		col = Boons.RARITY[card.rarity].color
	if card.has("color"):
		col = card.color  # objet (coffres de la carte, enclume) : couleur de sa rareté
	var b := Button.new()
	b.custom_minimum_size = Vector2(320, 380)
	b.focus_mode = Control.FOCUS_NONE
	b.pivot_offset = b.custom_minimum_size * 0.5
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.09, 0.08, 0.15, 0.97)
	sb.border_color = col
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(14)
	if String(card.get("tier", "common")) in ["rare", "epic", "legendary"]:
		sb.shadow_color = Color(col, 0.38)  # les cartes rares et mieux brillent
		sb.shadow_size = 12
	var hover := sb.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.16, 0.13, 0.25, 1.0)
	hover.set_border_width_all(5)
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", hover)
	hover.border_color = col.lightened(0.3)
	hover.shadow_color = Color(col, 0.55)
	hover.shadow_size = 16
	b.pressed.connect(_choose.bind(i))
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 18
	v.offset_right = -18
	v.offset_top = 18
	v.offset_bottom = -18
	v.add_theme_constant_override("separation", 10)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.set_meta("content", v)
	b.add_child(v)
	# fond teinté de la rareté, du haut vers le bas : la couleur se voit de loin, sans lire le texte
	var tint := GradientTexture2D.new()
	tint.fill = GradientTexture2D.FILL_LINEAR
	tint.fill_from = Vector2(0.5, 0.0)
	tint.fill_to = Vector2(0.5, 1.0)
	tint.gradient = Gradient.new()
	tint.gradient.colors = PackedColorArray([Color(col, 0.34), Color(col, 0.0)])
	var wash := TextureRect.new()
	wash.texture = tint
	wash.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	wash.stretch_mode = TextureRect.STRETCH_SCALE
	wash.set_anchors_preset(Control.PRESET_TOP_WIDE)
	wash.offset_left = 6
	wash.offset_right = -6
	wash.offset_top = 6
	wash.offset_bottom = 170
	wash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(wash)
	b.move_child(wash, 0)
	# ligne du haut : la touche qui choisit la carte (pastille), puis rareté, type et niveau
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(top)
	var badge := Label.new()
	badge.text = str(i + 1)
	badge.custom_minimum_size = Vector2(30, 30)
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge.add_theme_font_size_override("font_size", 18)
	badge.add_theme_font_override("font", UiTheme.bold_font())
	badge.add_theme_color_override("font_color", Color(0.06, 0.04, 0.1))
	badge.add_theme_stylebox_override("normal", UiTheme.flat_box(col, col.lightened(0.3), 1, 15, false))
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(badge)
	var key := Label.new()
	key.text = String(card.subtitle)
	key.add_theme_color_override("font_color", col.lightened(0.15))
	key.add_theme_font_size_override("font_size", 17)
	key.add_theme_font_override("font", UiTheme.bold_font())
	key.add_theme_constant_override("outline_size", 4)
	key.add_theme_color_override("font_outline_color", Color(0.04, 0.02, 0.08, 0.9))
	key.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	key.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	key.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	key.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(key)
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(96, 96)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture = UiTheme.texture(String(card.get("icon", "")))
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(icon)
	var t := Label.new()
	t.text = card.title
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	t.add_theme_font_size_override("font_size", 22)
	t.add_theme_font_override("font", UiTheme.bold_font())
	v.add_child(t)
	# description et totaux avant → après (texte enrichi)
	var d := RichTextLabel.new()
	d.bbcode_enabled = true
	d.text = desc
	d.scroll_active = false
	d.fit_content = true
	d.mouse_filter = Control.MOUSE_FILTER_IGNORE
	d.add_theme_font_size_override("normal_font_size", 15)
	d.add_theme_font_size_override("bold_font_size", 16)
	d.add_theme_font_override("bold_font", UiTheme.bold_font())
	d.modulate = Color(0.95, 0.95, 0.98)
	d.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(d)
	# bannir (la carte quitte la run, une autre la remplace) / garder (revient au prochain choix)
	if String(card.get("type", "")) in ["skill", "chain", "upgrade", "weapon_up", "passive"] and _reroll_fn.is_valid():
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		v.add_child(row)
		var ban := Button.new()
		ban.text = "Bannir (%d)" % (Cards.BANS_PER_RUN - Run.bans_used)
		ban.tooltip_text = "Cette carte ne sera plus proposée pendant la run ; une autre la remplace."
		ban.focus_mode = Control.FOCUS_NONE
		ban.add_theme_font_size_override("font_size", UiTheme.MIN_TEXT)
		ban.disabled = Run.bans_used >= Cards.BANS_PER_RUN or String(card.type) in ["upgrade", "weapon_up"]
		ban.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		ban.pressed.connect(func(): _ban(i))
		row.add_child(ban)
		var keep := Button.new()
		var is_kept: bool = Run.kept.any(func(k): return String(k.type) == String(card.type) and str(k.id) == str(card.id))
		keep.text = "Gardée ✔" if is_kept else "Garder (%d)" % (Cards.LOCKS_PER_RUN - Run.locks_used)
		keep.tooltip_text = "La carte revient au prochain choix, avec la même rareté, si tu en prends une autre maintenant."
		keep.focus_mode = Control.FOCUS_NONE
		keep.add_theme_font_size_override("font_size", UiTheme.MIN_TEXT)
		keep.disabled = is_kept or Run.locks_used >= Cards.LOCKS_PER_RUN
		keep.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		keep.pressed.connect(func():
			if Run.keep_card(card):
				_show_cards(_cards))
		row.add_child(keep)
	return b


func _ban(i: int) -> void:
	var rep := Run.ban_card(_cards[i], _cards)
	if rep.is_empty():
		_cards.remove_at(i)
	else:
		_cards[i] = rep
	_show_cards(_cards)
	_opened_at -= CONFIRM_DELAY_MS  # pas de délai anti-rafale après un bannissement volontaire
	_row.modulate.a = 1.0


## Les cartes sortent du voile à la fin du délai anti-rafale (temps réel : le jeu est en pause).
func _process(_delta: float) -> void:
	if _root.visible and _row.modulate.a < 1.0:
		var t := clampf(float(Time.get_ticks_msec() - _opened_at) / CONFIRM_DELAY_MS, 0.0, 1.0)
		_row.modulate.a = lerpf(VEIL_ALPHA, 1.0, t)


## 1, 2, 3 choisissent la carte (ce sont aussi les touches de compétences : le délai anti-rafale protège).
## À la manette, A sur la carte désignée par le cadre de navigation est un vrai clic (UiNav).
func _unhandled_input(event: InputEvent) -> void:
	if not _root.visible or not event is InputEventKey or not event.pressed or event.echo:
		return
	var n: int = event.physical_keycode - KEY_1
	if n >= 0 and n < _cards.size():
		_choose(n)
		get_viewport().set_input_as_handled()


## Choisit la carte [param i] et passe au choix suivant ; sans effet pendant le délai anti-rafale.
func _choose(i: int) -> void:
	if i < 0 or i >= _cards.size() or Time.get_ticks_msec() - _opened_at < CONFIRM_DELAY_MS:
		return
	var card: Dictionary = _cards[i]
	# carte gardée puis prise maintenant : elle ne revient pas
	Run.kept = Run.kept.filter(func(k): return not (String(k.type) == String(card.type) and str(k.id) == str(card.id)))
	Run.apply_card(card)
	Sfx.ui("confirm", -3.0)
	picked.emit(card)
	_show_next()


## Choix automatique (aide au combat « Bot », pilote automatique --autoplay) : jamais d'écran laissé ouvert.
## Un nouveau sort tant qu'une case est libre ; équipement (coffre, arme secondaire, trophée) : la meilleure
## rareté, puis le plus grand gain de note pondérée par le profil de la classe (Items.rating, ClassGear) sur la
## pièce portée ; enclume, parchemins : la 1re carte (rangées de la plus utile à la moins utile) ; autres
## cartes : la plus haute rareté ([param random_cards] : au hasard, pour que les mesures voient des builds variés).
static func auto_pick(options: Array, random_cards := false) -> Dictionary:
	if options.is_empty():
		return {}
	if Survivor.active and SurvivorCards.handles():
		return SurvivorCards.auto_pick(options, random_cards)  # Survivant : ses priorités (S3)
	var skills := options.filter(func(o): return String(o.get("type", "")) == "skill")
	if not skills.is_empty() and Run.skills.size() < Run.MAX_SKILLS:
		return skills[0]
	if options.all(func(o): return o.has("item")):
		var prof := ClassGear.profile(Run.class_id)
		var best: Dictionary = options[0]
		var best_key := -INF
		for o in options:
			var it: Dictionary = o.item
			var worn: Dictionary = Profile.equipped.get("offhand" if String(o.get("type", "")) == "offhand" else String(it.get("slot", "")), {})
			var key := int(it.get("rarity", 0)) * 1000.0 + Items.rating(it, prof) - (Items.rating(worn, prof) if String(o.get("type", "")) != "trophy" else 0.0)
			if key > best_key:
				best_key = key
				best = o
		return best
	if options.any(func(o): return String(o.get("type", "")) in ["anvil_slot", "anvil", "scroll"]):
		return options[0]
	if random_cards:
		return options.pick_random()
	var pick: Dictionary = options[0]
	var best_r := -1
	for o in options:
		var r := Cards.TIER_ORDER.find(String(o.get("tier", "common")))
		if r > best_r:
			best_r = r
			pick = o
	return pick
