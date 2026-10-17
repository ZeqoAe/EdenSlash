class_name AutochessChoicePanel
extends Control
## L'Échiquier (lot AC-G, v2 du lot ACX-2) : les choix à cartes de la préparation (SPEC §5.3, §7.1) : l'atout (3 grandes
## cartes de la même rareté, [Relancer] une fois), et les autres choix de la partie, même écran : premier héros (ouverture,
## 1 parmi 4), héros légendaire, objet complet, composant, famille (Cœur de famille), trait d'un Emblème. Le choix partagé a
## son propre écran (AutochessCarousel). Posé par l'écran sur un calque au-dessus du plateau (la manette n'y voit que ces
## cartes) ; [Voir le plateau] le replie le temps de regarder (l'écran affiche un bouton pour revenir).
## v2 (BIBLE §5-8, étude BM-AUTO §7.4, maquette autochess_maquettes/choix.html) : voile d'encre, titre Mochiy incliné ;
## cartes papier autocollantes à cadre de rareté (Argent : lagon clair ; Or : soleil ; Éclat : améthyste + rayons qui
## tournent), icône du jeu dans un médaillon, nom en Mochiy, UNE phrase, étiquette du genre (Économie, Combat, Unités,
## Objets) ; le détail chiffré n'apparaît que sur la carte visée (souris ou cadre de la manette). Manette : A choisit,
## X relance, Y voit le plateau ; clavier 1-3 (l'écran), R relance.

signal chosen(index: int)
signal reroll_requested
signal hide_requested

## Cadre de rareté : bonbon et ton.
const RARITY_CANDY := {"argent": ["lagon", 0], "or": ["soleil", 1], "eclat": ["amethyste", 1]}
const RARITY_COLORS := {"argent": Color("86ddff"), "or": Color("ffc928"), "eclat": Color("b43beb")}  # (compatibilité)
const TITLES := {
	"atout": "Choisis un atout", "ouverture": "Choisis ton premier héros", "heros": "Choisis un héros légendaire",
	"objet": "Choisis un objet", "composant": "Choisis un composant", "famille": "Choisis une famille",
	"embleme": "Choisis le trait de l'Emblème",
}
const SUBTITLES := {
	"atout": "Il reste toute la partie.", "ouverture": "Les autres stratèges reçoivent le leur.",
	"heros": "Il arrive déjà avec deux étoiles.", "objet": "Il va au banc d'objets.", "composant": "Il va au banc d'objets.",
	"famille": "Elle compte une unité de plus.", "embleme": "Son porteur gagne ce trait.",
}
## Genre d'un atout (étiquette de la carte), d'après son effet.
const KIND_OF_EFFECT := {
	"or": "Économie", "relance_gratuite": "Économie", "xp": "Économie", "plafond_interets": "Économie",
	"pv_contre_or": "Économie", "or_sans_interets": "Économie", "niveau_max": "Économie", "achat_double": "Économie",
	"unites_famille": "Unités", "unite_au_choix": "Unités", "place_plateau": "Unités", "trait_compte": "Unités",
	"fusion_rapide": "Unités", "composant_au_choix": "Objets", "objet": "Objets", "objets_au_choix": "Objets",
	"butin_gardien": "Objets", "trait_plus": "Traits", "trait_au_choix": "Traits", "copie_unite": "Unités",
}

var cards: Array = []  # Button par option
var reroll_button: Button
var hide_button: Button
var kind := ""
var _title: Label
var _sub: Label
var _row: HBoxContainer
var _details: Array = []  # Label de détail par carte (montré sur la carte visée)
var _hover := -1


func _init() -> void:
	name = "AcChoice"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(AutochessHud.INK_900, 0.62)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", roundi(AutochessHud.s(16)))
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(v)
	_title = AutochessHud.pop_lbl("", 34)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.rotation = deg_to_rad(-3.0)
	v.add_child(_title)
	var subh := CenterContainer.new()
	subh.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(subh)
	_sub = AutochessHud.ink_lbl("", 16, AutochessHud.INK, 800)
	_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sub.add_theme_stylebox_override("normal", AutochessHud.sticker(AutochessHud.PAPER, 12.0, 4.0, 3.0, 14.0, 3.0))
	subh.add_child(_sub)
	_row = HBoxContainer.new()
	_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_row.add_theme_constant_override("separation", roundi(AutochessHud.s(22)))
	_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(_row)
	var foot := HBoxContainer.new()
	foot.alignment = BoxContainer.ALIGNMENT_CENTER
	foot.add_theme_constant_override("separation", roundi(AutochessHud.s(16)))
	foot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(foot)
	reroll_button = AutochessHud.button("Relancer", "soft", 44.0, "R", "X")
	reroll_button.name = "AcChoiceReroll"
	reroll_button.custom_minimum_size.x = AutochessHud.s(200)
	reroll_button.pressed.connect(func(): reroll_requested.emit())
	foot.add_child(reroll_button)
	hide_button = AutochessHud.button("Voir le plateau", "plain", 44.0, "", "Y")
	hide_button.name = "AcChoiceHide"
	hide_button.custom_minimum_size.x = AutochessHud.s(200)
	hide_button.pressed.connect(func(): hide_requested.emit())
	foot.add_child(hide_button)
	visible = false


## Montre le choix [param c] (Autochess.pending : {kind, options, rerolls, rarity, stars}).
func open(c: Dictionary) -> void:
	kind = String(c.get("kind", ""))
	var opts: Array = c.get("options", [])
	_title.text = String(TITLES.get(kind, "Choisis"))
	var sub := String(SUBTITLES.get(kind, ""))
	if kind == "atout":
		sub = "Rareté %s · %s" % [String(AutochessData.RARITY_NAMES.get(String(c.get("rarity", "")), "")), sub.to_lower()]
	elif kind == "heros" and int(c.get("stars", 2)) < 2:  # lot ACX-3 : Recrue dorée (coût 3, une étoile)
		_title.text = "Choisis un héros"
		sub = "Il rejoint ton banc."
	elif kind == "famille":
		var weapon := not opts.is_empty() and String(AutochessData.TRAITS.get(String(opts[0]), {}).get("kind", "")) == "arme"
		if weapon:
			_title.text = "Choisis un trait d'arme"
		sub = ("Il compte" if weapon else "Elle compte") + (" deux unités de plus." if int(c.get("count", 1)) >= 2 else " une unité de plus.")
	_sub.text = sub
	for b in cards:
		_row.remove_child(b)
		b.queue_free()
	cards.clear()
	_details.clear()
	var vw := get_viewport_rect().size.x
	var n := maxi(opts.size(), 1)
	var big := kind == "atout"
	var w := clampf((vw - AutochessHud.s(120.0) - AutochessHud.s(22.0) * (n - 1)) / n, AutochessHud.s(170.0),
		AutochessHud.s(300.0 if big else 240.0))
	var h := AutochessHud.s(390.0 if big else 330.0)
	for i in opts.size():
		var b := _card(i, opts[i], c, Vector2(w, h))
		_row.add_child(b)
		cards.append(b)
	reroll_button.visible = kind == "atout"
	var left := int(c.get("rerolls", 0))
	reroll_button.disabled = left <= 0
	reroll_button.text = ("Relancer · %d" % left) if left > 0 else "Déjà relancé"
	reroll_button.tooltip_text = "Trois nouvelles cartes de la même rareté." if left > 0 else "Une relance par choix."
	visible = true
	if not cards.is_empty():
		UiNav.focus(cards[0])
		if not UiFeel.reduce_motion:
			for k in cards.size():
				_deal(cards[k] as Control, k)


## Arrivée des cartes (distribution) : de 40 px plus bas, en fondu, 70 ms d'écart.
func _deal(b: Control, k: int) -> void:
	var inner := b.get_child(0) as Control
	if inner == null:
		return
	inner.modulate.a = 0.0
	var tw := inner.create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_interval(0.07 * k)
	tw.tween_property(inner, "modulate:a", 1.0, 0.18)


func _card(i: int, opt: Variant, c: Dictionary, sz: Vector2) -> Button:
	var b := Button.new()
	b.name = "AcChoiceCard_%d" % i
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = sz
	b.set_meta("ui_feel", "card")
	b.pressed.connect(func(): chosen.emit(i))
	b.mouse_entered.connect(func(): _hover = i)
	b.mouse_exited.connect(func():
		if _hover == i:
			_hover = -1)
	var frame := "soleil"
	var tone := 1
	var head := ""
	var title := ""
	var short := ""
	var tip := ""
	var tag := ""
	var icon: Texture2D = null
	var rays := false
	match kind:
		"atout":
			var a := AutochessData.augment(String(opt))
			var rc: Array = RARITY_CANDY.get(String(a.get("rarity", "")), ["soleil", 1])
			frame = String(rc[0])
			tone = int(rc[1])
			rays = String(a.get("rarity", "")) == "eclat"
			head = String(AutochessData.RARITY_NAMES.get(String(a.get("rarity", "")), ""))
			title = String(a.get("name", opt))
			short = String(a.get("short", ""))
			tip = String(a.get("tip", ""))
			tag = String(KIND_OF_EFFECT.get(String(a.get("effect", "")), "Combat"))
			icon = augment_icon(String(opt))
		"ouverture", "heros":
			var d := AutochessData.unit(String(opt))
			var cost := int(d.get("cost", 1))
			frame = AutochessHud.COST_CANDY[clampi(cost, 1, 5) - 1]
			rays = cost >= 5
			var stars := int(c.get("stars", 1))
			head = "★".repeat(stars) + "  ·  %d or" % cost
			title = AutochessData.unit_name(String(opt))
			short = " · ".join((d.get("traits", []) as Array).map(func(t): return String(AutochessData.TRAITS.get(t, {}).get("name", t))))
			var role: Dictionary = AutochessData.ROLES.get(String(d.get("role", "")), {})
			tag = String(role.get("name", ""))
			tip = String(role.get("short", ""))
			icon = UiTheme.texture(String(GameData.class_data(String(opt)).get("icon", "")))
		"objet", "composant":
			var it := AutochessData.item(String(opt))
			frame = "mandarine" if AutochessData.COMPONENTS.has(String(opt)) else "amethyste"
			head = "Composant" if AutochessData.COMPONENTS.has(String(opt)) else "Objet complet"
			title = String(it.get("name", opt))
			short = String(it.get("short", ""))
			tip = String(it.get("tip", ""))
			icon = AutochessUnitCard.item_icon(String(opt))
		"famille", "embleme":
			var td: Dictionary = AutochessData.TRAITS.get(String(opt), {})
			var fam := String(td.get("kind", "")) == "famille"
			head = "Famille" if fam else "Arme"
			title = String(td.get("name", opt))
			short = String(td.get("short", ""))
			tip = String(td.get("tip", ""))
			var col := AutochessHud.trait_candy(String(opt))
			for nm in AutochessHud.CANDY:
				if AutochessHud.candy(nm) == col or AutochessHud.candy(nm, 0) == col:
					frame = nm
		_:
			title = str(opt)
	var fc := AutochessHud.candy(frame, tone)
	# papier, cadre épais de la rareté, contour d'encre, ombre dure ; survol : liseré lagon (la carte monte : UiFeel)
	var n := AutochessHud.sticker(AutochessHud.PAPER, 18.0, 8.0, 3.0, 0.0, 0.0)
	n.border_color = AutochessHud.INK
	var hv := n.duplicate() as StyleBoxFlat
	hv.shadow_offset = Vector2(0.0, AutochessHud.s(11.0))
	for st in ["normal", "focus", "disabled"]:
		b.add_theme_stylebox_override(st, n)
	b.add_theme_stylebox_override("hover", hv)
	b.add_theme_stylebox_override("pressed", n)
	var art := CardArt.new()
	art.frame = fc
	art.rays = rays
	art.icon = icon
	art.set_anchors_preset(Control.PRESET_FULL_RECT)
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(art)
	var m := MarginContainer.new()
	m.set_anchors_preset(Control.PRESET_FULL_RECT)
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right"]:
		m.add_theme_constant_override("margin_" + side, roundi(AutochessHud.s(20)))
	m.add_theme_constant_override("margin_top", roundi(AutochessHud.s(14)))
	m.add_theme_constant_override("margin_bottom", roundi(AutochessHud.s(18)))
	art.add_child(m)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", roundi(AutochessHud.s(6)))
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m.add_child(v)
	var hl := AutochessHud.pop_lbl(head, 17)
	hl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(hl)
	var medal := Control.new()  # place du médaillon (dessiné par CardArt)
	medal.custom_minimum_size = Vector2(0, AutochessHud.s(100.0 if kind == "atout" else 84.0))
	medal.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(medal)
	art.medal = medal
	medal.item_rect_changed.connect(art.queue_redraw)  # le médaillon se dessine où la mise en page l'a posé
	var tl := AutochessHud.pop_lbl(title, 24 if kind == "atout" else 21, AutochessHud.INK)
	tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(tl)
	var sl := AutochessHud.ink_lbl(short, 17, AutochessHud.INK, 700)
	sl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(sl)
	if tag != "":
		var tc := CenterContainer.new()
		tc.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(tc)
		var tg := AutochessHud.ink_lbl(tag, 14, AutochessHud.INK, 900)
		tg.add_theme_stylebox_override("normal", AutochessHud.sticker(AutochessHud.candy(frame, 0), 10.0, 0.0, 2.0, 10.0, 1.0))
		tg.rotation = deg_to_rad(-4.0)
		tc.add_child(tg)
	var sp := Control.new()
	sp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(sp)
	var dl := AutochessHud.ink_lbl(tip, 14, AutochessHud.INK_300, 800)
	dl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dl.modulate.a = 0.0
	v.add_child(dl)
	_details.append(dl)
	return b


## Icône du jeu d'un atout (AutochessData « icon » : nom d'icône de passif, Boons.ICONS) ; repli : étoile.
static func augment_icon(id: String) -> Texture2D:
	var name_ := String(AutochessData.augment(id).get("icon", ""))
	var path := String(Boons.ICONS.get(name_, ""))
	if path == "" or not ResourceLoader.exists(path):
		path = "res://assets/ui/status/keen.png"
	return UiTheme.texture(path)


func _process(delta: float) -> void:
	if not visible:
		return
	var aim := _hover
	if Gamepad.active and UiNav.cursor != null and is_instance_valid(UiNav.cursor):
		aim = cards.find(UiNav.cursor)
	for i in _details.size():
		var dl := _details[i] as Label
		var want := 1.0 if i == aim else 0.0
		dl.modulate.a = move_toward(dl.modulate.a, want, delta * 8.0) if not UiFeel.reduce_motion else want


func _input(ev: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	var jb := ev as InputEventJoypadButton
	if jb != null and jb.pressed:
		if jb.button_index == JOY_BUTTON_X and reroll_button.visible and not reroll_button.disabled:
			reroll_requested.emit()
			get_viewport().set_input_as_handled()
		elif jb.button_index == JOY_BUTTON_Y:
			hide_requested.emit()
			get_viewport().set_input_as_handled()
	var ke := ev as InputEventKey
	if ke != null and ke.pressed and not ke.echo and ke.keycode == KEY_R and reroll_button.visible and not reroll_button.disabled:
		reroll_requested.emit()
		get_viewport().set_input_as_handled()


## Dessin de la carte : bandeau de rareté en haut (cadre épais intérieur), médaillon rond de l'icône contouré d'encre,
## rayons de soleil qui tournent derrière (Éclat, coût 5 : 1 tour / 12 s).
class CardArt extends Control:
	var frame := Color.WHITE
	var rays := false
	var icon: Texture2D
	var medal: Control
	var _t := 0.0

	func _process(delta: float) -> void:
		if rays and not UiFeel.reduce_motion and is_visible_in_tree():
			_t += delta
			queue_redraw()

	func _draw() -> void:
		var k := AutochessHud.k
		var bw := roundf(7.0 * k)
		var r := Rect2(Vector2(3, 3), size - Vector2(6, 6))
		# cadre de rareté à l'intérieur du contour d'encre
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0, 0, 0, 0)
		sb.border_color = frame
		sb.set_border_width_all(int(bw))
		sb.border_width_top = int(bw * 4.2)
		sb.set_corner_radius_all(roundi(15.0 * k))
		sb.anti_aliasing = true
		draw_style_box(sb, r)
		if medal == null:
			return
		var at := medal.position  # dans le repère de la carte (la carte peut être tournée par UiFeel)
		var up := medal.get_parent() as Control
		while up != null and up != self:
			at += up.position
			up = up.get_parent() as Control
		var mr := Rect2(at, medal.size)
		var c := mr.get_center()
		var rad := minf(mr.size.y * 0.5, mr.size.x * 0.5)
		if rays:
			var n := 12
			for i in n:
				var a := TAU * float(i) / n + _t * TAU / 12.0
				var p1 := c + Vector2(cos(a - 0.11), sin(a - 0.11)) * rad * 1.9
				var p2 := c + Vector2(cos(a + 0.11), sin(a + 0.11)) * rad * 1.9
				draw_colored_polygon(PackedVector2Array([c, p1, p2]), Color(frame.lightened(0.35), 0.45))
		draw_circle(c + Vector2(0, roundf(4.0 * k)), rad, AutochessHud.INK)  # ombre dure
		draw_circle(c, rad, AutochessHud.INK)
		draw_circle(c, rad - roundf(3.0 * k), frame)
		draw_circle(c, rad - roundf(9.0 * k), frame.lightened(0.45))
		if icon != null:
			var s := (rad - roundf(12.0 * k)) * 2.0 * 0.92
			draw_texture_rect(icon, Rect2(c - Vector2(s, s) * 0.5, Vector2(s, s)), false)
		# reflet blanc incliné en haut à gauche (BIBLE §5)
		draw_line(c + Vector2(-rad * 0.55, -rad * 0.62), c + Vector2(-rad * 0.18, -rad * 0.8), Color(1, 1, 1, 0.85), roundf(4.0 * k), true)
