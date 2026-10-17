class_name AssaultShop
extends Control
## Écran d'achat de L'Assaut (lot TAC-5, croquis conception/benchmark/tactique_maquettes/v2_achat.svg, étude TACTIQUE § 7.8,
## rapport R_TAC_5.md) : 20 s au début de chaque manche, le monde reste visible autour. DA v2 « autocollant manga » (papier,
## encre, bonbons, UiTheme / UiFeel) : en-tête (manche, minuteur, or, prime de la prochaine défaite), 5 onglets (LB / RB à la
## manette, Q / E au clavier), cartes d'objets (clic ou A : acheter ; clic droit ou X : revendre ce qui vient d'être acheté),
## paquetage, colonne de l'équipe (plan annoncé, or de chacun, ce qui lui manque), « Achat conseillé » (bouton primaire,
## [T]), « Racheter » ([R]), « Tout revendre », « Fermer » ([B] ou B). Aucun pourcentage dans le texte : l'infobulle chiffre.
## Le directeur (AssaultDirector) fournit tout par shop_* ; l'écran ne touche jamais l'or lui-même.

signal closed

const CARD := Vector2(244, 138)
const CARD_NARROW := Vector2(206, 142)
const TEAM_W := 300.0
const TEAM_W_NARROW := 248.0

var dir: Node  # AssaultDirector
var key := ""
var tab := 0
var cards: Array = []  # [Button, id]
var _panel: PanelContainer
var _title: Label
var _clock: Label
var _gold: Label
var _next: Label
var _tabs: Array = []
var _grid: GridContainer
var _scroll: ScrollContainer
var _pack: HFlowContainer
var _team: VBoxContainer
var _plan: Label
var _note: Label
var _btn_advise: Button
var _btn_rebuy: Button
var _btn_sell: Button
var _btn_close: Button
var _t := 0.0
var _narrow := false
var _sig := ""


func setup(d: Node, k: String) -> void:
	dir = d
	key = k
	name = "AssaultShop"
	add_to_group("tab_screens")
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()
	refresh()
	UiFeel.page_sound(true)


func is_open() -> bool:
	return visible and is_inside_tree()


## LB / RB (UiNav) et Q / E : onglet voisin.
func step_page(delta: int) -> void:
	set_tab(wrapi(tab + delta, 0, AssaultItems.TABS.size()))
	UiFeel.cue("ui_tab", -10.0)


func set_tab(i: int) -> void:
	tab = i
	_sig = ""
	refresh()


func _lbl(text: String, size: int, col: Color, font: Font = null) -> Label:
	var l := Label.new()
	l.text = text
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_override("font", font if font != null else UiTheme.bold_font())
	l.add_theme_font_size_override("font_size", UiTheme.text_size(size))
	l.add_theme_color_override("font_color", col)
	return l


func _build() -> void:
	var vs := get_viewport_rect().size if is_inside_tree() else Vector2(1600, 900)
	_narrow = vs.x < 1500.0
	_panel = PanelContainer.new()
	_panel.name = "ShopPanel"
	_panel.add_theme_stylebox_override("panel", UiTheme.panel_style(7, Vector2(18, 12)))
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_panel)
	var w := minf(vs.x - 48.0, 1240.0 if not _narrow else 1220.0)
	var h := minf(vs.y - 150.0, 640.0)
	_panel.custom_minimum_size = Vector2(w, h)
	_panel.position = Vector2((vs.x - w) * 0.5, 60.0)
	_panel.size = Vector2(w, h)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	_panel.add_child(v)
	# en-tête : manche, minuteur, or, prime de la prochaine défaite
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 14)
	v.add_child(head)
	_title = _lbl("Achat", 26, UiTheme.color("encre.700"), UiTheme.title_font())
	head.add_child(_title)
	_clock = _lbl("0:20", 24, Color.WHITE, UiTheme.number_font())
	_clock.add_theme_constant_override("outline_size", UiTheme.outline_for(24))
	_clock.add_theme_color_override("font_outline_color", UiTheme.color("encre.700"))
	var clock_box := PanelContainer.new()
	clock_box.add_theme_stylebox_override("panel", UiTheme.sticker("fraise", {"radius": 12, "pad": Vector2(12, 2)}))
	clock_box.add_child(_clock)
	head.add_child(clock_box)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(sp)
	var coin := Ico.rect("coin", 28)
	if coin != null:
		head.add_child(coin)
	_gold = _lbl("0", 26, UiTheme.color("encre.700"), UiTheme.number_font())
	head.add_child(_gold)
	_next = _lbl("", 15, UiTheme.color("encre.500"))
	_next.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(_next)
	# onglets
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 6)
	v.add_child(tabs)
	if Gamepad.active:
		var lb := Ico.rect("pad_lb", 26)
		if lb != null:
			tabs.add_child(lb)
	for i in AssaultItems.TABS.size():
		var b := Button.new()
		b.name = "ShopTab_%s" % AssaultItems.TABS[i][0]
		b.text = String(AssaultItems.TABS[i][1])
		b.toggle_mode = true
		b.focus_mode = Control.FOCUS_NONE
		UiTheme.style_button(b, "papier", 17, {"selected_tone": "mandarine"})
		b.pressed.connect(set_tab.bind(i))
		tabs.add_child(b)
		_tabs.append(b)
	if Gamepad.active:
		var rb := Ico.rect("pad_rb", 26)
		if rb != null:
			tabs.add_child(rb)
	# corps : cartes à gauche, équipe à droite
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 14)
	v.add_child(body)
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 8)
	body.add_child(left)
	_scroll = ScrollContainer.new()  # (l'onglet Utilitaires a 10 cartes : en 1280 × 720 la troisième rangée défile)
	_scroll.name = "ShopCards"
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.follow_focus = true
	left.add_child(_scroll)
	_grid = GridContainer.new()
	_grid.columns = 3 if not _narrow else 4
	_grid.add_theme_constant_override("h_separation", 10)
	_grid.add_theme_constant_override("v_separation", 10)
	_scroll.add_child(_grid)
	left.add_child(_lbl("Ton paquetage", 17, UiTheme.color("encre.700"), UiTheme.title_font()))
	_pack = HFlowContainer.new()
	_pack.add_theme_constant_override("h_separation", 6)
	_pack.add_theme_constant_override("v_separation", 6)
	left.add_child(_pack)
	var col := PanelContainer.new()
	col.add_theme_stylebox_override("panel", UiTheme.sticker("papier2", {"radius": 14, "shadow": 3, "gloss": false, "pad": Vector2(12, 8)}))
	col.custom_minimum_size.x = TEAM_W if not _narrow else TEAM_W_NARROW
	body.add_child(col)
	_team = VBoxContainer.new()
	_team.add_theme_constant_override("separation", 6)
	col.add_child(_team)
	# pied : boutons et aide
	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 10)
	v.add_child(foot)
	_btn_advise = _button("Achat conseillé · [%s]" % _key_txt(KEY_T), "soleil", _advise)
	_btn_advise.name = "ShopAdvised"
	foot.add_child(_btn_advise)
	_btn_rebuy = _button("Racheter · [%s]" % _key_txt(KEY_R), "lagon", _rebuy)
	_btn_rebuy.name = "ShopRebuy"
	foot.add_child(_btn_rebuy)
	_btn_sell = _button("Tout revendre", "papier", _sell_all)
	_btn_sell.name = "ShopSellAll"
	foot.add_child(_btn_sell)
	var sp2 := Control.new()
	sp2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	foot.add_child(sp2)
	_btn_close = _button("Fermer · [%s]" % _key_txt(KEY_B), "papier", close)
	_btn_close.name = "ShopClose"
	foot.add_child(_btn_close)
	_note = _lbl("", 14, UiTheme.color("encre.500"), UiTheme.body_font())
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_note)


func _key_txt(k: Key) -> String:
	return OS.get_keycode_string(DisplayServer.keyboard_get_keycode_from_physical(k)) if DisplayServer.get_name() != "headless" else OS.get_keycode_string(k)


func _button(text: String, tone: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	UiTheme.style_button(b, tone, 18 if tone == "soleil" else 17)
	b.custom_minimum_size.y = 46
	b.pressed.connect(cb)
	return b


func _process(delta: float) -> void:
	_t -= delta
	if _t <= 0.0:
		_t = 0.25
		refresh()


func _unhandled_input(ev: InputEvent) -> void:
	if not is_open():
		return
	if ev is InputEventKey and ev.pressed and not ev.echo:
		match (ev as InputEventKey).physical_keycode:
			KEY_Q:
				step_page(-1)
			KEY_E:
				step_page(1)
			KEY_T:
				_advise()
			KEY_R:
				_rebuy()
			KEY_B, KEY_ESCAPE:
				close()
			_:
				return
		get_viewport().set_input_as_handled()
	elif ev.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


func close() -> void:
	if not visible:
		return
	visible = false
	UiFeel.page_sound(false)
	closed.emit()


func open() -> void:
	visible = true
	_sig = ""
	refresh()
	UiFeel.page_sound(true)


## Ids des cartes de l'onglet courant.
func tab_ids() -> Array:
	var name := String(AssaultItems.TABS[tab][0])
	if name == "spells":
		return ["spell1", "spell2", "spell3", "ultime"]
	var out: Array = []
	for id in AssaultItems.LIST:
		if String(AssaultItems.LIST[id].tab) == name:
			out.append(id)
	return out


func refresh() -> void:
	if dir == null or not is_inside_tree():
		return
	var ctx: Dictionary = dir.call("shop_ctx", key)
	var secs := maxf(Assault.t, 0.0) if Assault.phase == "buy" else 0.0
	_title.text = "Achat · Manche %d · %s" % [Assault.round_n, Assault.side_name(Assault.team_of(key))]
	_clock.text = "%d:%02d" % [int(secs) / 60, int(secs) % 60]
	_gold.text = _num(Assault.gold(key))
	_next.text = "prochaine manche : +%s au moins" % _num(Assault.next_loss_gold(Assault.team_of(key)))
	for i in _tabs.size():
		(_tabs[i] as Button).set_pressed_no_signal(i == tab)
	var sig := "%d|%d|%s|%s" % [tab, Assault.gold(key), str(AssaultItems.inv(key)), str(dir.call("ult_points", key))]
	if sig != _sig:
		_sig = sig
		_fill_cards(ctx)
		_fill_pack(ctx)
	_fill_team()
	_btn_rebuy.disabled = (AssaultItems.inv(key).last as Array).is_empty()
	_btn_sell.disabled = (AssaultItems.inv(key).now as Array).is_empty()
	_note.text = "[Clic] acheter · [Clic droit] revendre ce que tu viens d'acheter · [%s] / [%s] onglets · le détail chiffré est dans l'infobulle" % [
		_key_txt(KEY_Q), _key_txt(KEY_E)]


static func _num(v: int) -> String:
	var s := str(absi(v))
	var out := ""
	while s.length() > 3:
		out = " " + s.right(3) + out
		s = s.left(s.length() - 3)
	return ("-" if v < 0 else "") + s + out


func _fill_cards(ctx: Dictionary) -> void:
	for c in _grid.get_children():
		c.queue_free()
	cards = []
	_scroll.scroll_vertical = 0
	for id in tab_ids():
		var b := _card(String(id), ctx)
		_grid.add_child(b)
		cards.append([b, id])


func _card(id: String, ctx: Dictionary) -> Button:
	var b := Button.new()
	b.name = "ShopCard_" + id
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = CARD if not _narrow else CARD_NARROW
	b.set_meta("ui_feel", "card")
	b.set_meta("assault_item", id)
	var e: Dictionary = {}
	var state := ""  # buy / own / free / locked / ult
	var reason := ""
	var icon: Texture2D = null
	var cid := String(ctx.get("cid", ""))
	var sl: Array = AssaultCombat.slots(cid)
	if id == "spell1" or id == "ultime":
		var i := 0 if id == "spell1" else 3
		var s: Dictionary = sl[i] if sl.size() > i else {}
		e = {"name": String(s.get("name", "")), "desc": "Signature" if i == 0 else "Ultime · se charge en jouant",
			"tip": "Toujours à toi" if i == 0 else String(AssaultItems.LIST.ultime.tip)}
		icon = _skill_icon(cid, int(s.get("id", -1)))
		state = "free" if i == 0 else "ult"
	else:
		e = AssaultItems.info(id, ctx)
		if e.has("skill_id"):
			icon = _skill_icon(cid, int(e.skill_id))
		else:
			icon = Ico.tex(String(e.get("icon", "misc")))
		reason = AssaultItems.can_buy(key, id, ctx)
		state = "own" if AssaultItems.owns(key, id) and id != "reparer" else ("buy" if reason == "" else "locked")
		if bool(e.get("util", false)) and int(AssaultItems.inv(key).utils.get(id, 0)) > 0 and reason == "":
			state = "buy"  # (une deuxième charge reste achetable)
	var tone := "papier"
	if state == "own" or state == "free":
		tone = "pomme"
	elif state == "locked":
		tone = "gris"
	UiTheme.style_button(b, tone, 0, {"radius": 16, "pad": Vector2(10, 8)})
	b.tooltip_text = String(e.get("tip", ""))
	var m := MarginContainer.new()
	m.set_anchors_preset(Control.PRESET_FULL_RECT)
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for s in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + s, 10)
	b.add_child(m)
	var h := HBoxContainer.new()
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_theme_constant_override("separation", 8)
	m.add_child(h)
	if icon != null:
		var tr := TextureRect.new()
		tr.texture = icon
		tr.custom_minimum_size = Vector2(46, 46)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_child(tr)
	var tx := VBoxContainer.new()
	tx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tx.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tx.add_theme_constant_override("separation", 2)
	h.add_child(tx)
	var ink := UiTheme.color("encre.700") if tone in ["papier", "gris"] else Color.WHITE
	var nm := _lbl(String(e.get("name", id)), 16, ink)
	nm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	nm.max_lines_visible = 2
	if tone == "pomme":
		nm.add_theme_constant_override("outline_size", 4)
		nm.add_theme_color_override("font_outline_color", UiTheme.color("encre.700"))
	tx.add_child(nm)
	var ds := _lbl(String(e.get("desc", "")), 13, ink if tone != "papier" else UiTheme.color("encre.500"), UiTheme.body_font())
	ds.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ds.max_lines_visible = 3
	ds.size_flags_vertical = Control.SIZE_EXPAND_FILL
	if tone == "pomme":
		ds.add_theme_constant_override("outline_size", 3)
		ds.add_theme_color_override("font_outline_color", UiTheme.color("encre.700"))
	tx.add_child(ds)
	var badge := ""
	match state:
		"free":
			badge = "✔ Gratuit"
		"own":
			badge = "✔ Acheté" if _bought_now(id) else ("✔ Tu as mieux" if _better_owned(id) else "✔ À toi")
		"ult":
			badge = "%d / %d points" % [int(dir.call("ult_points", key)), int(Assault.num("ult_points"))]
		"buy":
			badge = "%s or" % _num(AssaultItems.price(key, id, ctx))
		"locked":
			badge = reason
	var bl := _lbl(badge, 14, UiTheme.color("bonbon.fraise.fonce", Color("b0174a")) if state == "locked" else ink, UiTheme.number_font())
	if state == "buy":
		bl.add_theme_color_override("font_color", UiTheme.color("encre.700"))
	bl.clip_text = true  # (une étiquette longue ne doit pas élargir la carte)
	bl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	tx.add_child(bl)
	b.gui_input.connect(_on_card_input.bind(id))
	if state == "buy":
		b.pressed.connect(_buy.bind(id))
	elif state == "locked":
		b.pressed.connect(func(): UiFeel.cue("ui_deny", -8.0))
	return b


## L'arme affûtée ou le gilet alors que l'on porte mieux (arme de maître, cuirasse).
func _better_owned(id: String) -> bool:
	var v := AssaultItems.inv(key)
	return (id == "affutee" and String(v.weapon) == "maitre") or (id == "gilet" and String(v.armor) == "cuirasse")


func _bought_now(id: String) -> bool:
	return (AssaultItems.inv(key).now as Array).any(func(e): return String(e[0]) == id)


func _skill_icon(cid: String, sid: int) -> Texture2D:
	for s in GameData.class_data(cid).get("skills", []):
		if int(s.id) == sid:
			var p := String(s.get("icon", ""))
			return UiTheme.texture(p) if p != "" else null
	return null


func _on_card_input(ev: InputEvent, id: String) -> void:
	if ev is InputEventMouseButton and ev.pressed and (ev as InputEventMouseButton).button_index == MOUSE_BUTTON_RIGHT:
		if bool(dir.call("shop_sell", id)):
			UiFeel.cue("ui_coin", -10.0, 0.85)
			_sig = ""
			refresh()
		get_viewport().set_input_as_handled()


func _buy(id: String) -> void:
	if bool(dir.call("shop_buy", id)):
		UiFeel.cue("ui_coin", -8.0)
	else:
		UiFeel.cue("ui_deny", -8.0)
	_sig = ""
	refresh()


func _advise() -> void:
	var got: Array = dir.call("shop_advised")
	UiFeel.cue("ui_confirm" if not got.is_empty() else "ui_deny", -8.0)
	_sig = ""
	refresh()


func _rebuy() -> void:
	var got: Array = dir.call("shop_rebuy")
	UiFeel.cue("ui_confirm" if not got.is_empty() else "ui_deny", -8.0)
	_sig = ""
	refresh()


func _sell_all() -> void:
	if int(dir.call("shop_sell_all")) > 0:
		UiFeel.cue("ui_coin", -10.0, 0.85)
	_sig = ""
	refresh()


## Paquetage : une pastille par objet porté (vert : déjà à toi, soleil : acheté maintenant, revendable au clic droit).
func _fill_pack(ctx: Dictionary) -> void:
	for c in _pack.get_children():
		c.queue_free()
	var v := AssaultItems.inv(key)
	var items: Array = []
	for slot in v.spells:
		items.append(["spell%d" % (int(slot) + 1), ""])
	if String(v.weapon) != "":
		items.append([String(v.weapon), ""])
	if bool(v.weapon2):
		items.append(["appoint", ""])
	if int(v.coat) > 0:
		items.append(["enduit", "× %d" % int(v.coat)])
	if String(v.armor) != "":
		items.append([String(v.armor), "bouclier à plein" if is_equal_approx(float(v.shield), float(AssaultItems.LIST[String(v.armor)].shield)) else "bouclier entamé"])
	for u in v.utils:
		items.append([String(u), "× %d" % int(v.utils[u])])
	if String(v.fiole) != "":
		items.append([String(v.fiole), ""])
	if String(v.tool) != "":
		items.append([String(v.tool), ""])
	if items.is_empty():
		_pack.add_child(_lbl("Rien encore : le sort 1 est à toi, le reste s'achète.", 14, UiTheme.color("encre.500"), UiTheme.body_font()))
		return
	for it in items:
		var e := AssaultItems.info(String(it[0]), ctx)
		var now := _bought_now(String(it[0]))
		var chip := PanelContainer.new()
		chip.name = "PackChip_" + String(it[0])
		chip.mouse_filter = Control.MOUSE_FILTER_STOP
		chip.tooltip_text = String(e.get("tip", ""))
		chip.add_theme_stylebox_override("panel", UiTheme.sticker("soleil" if now else "pomme", {"radius": 11, "shadow": 3, "pad": Vector2(10, 3)}))
		var t := String(e.get("name", it[0])) + ("" if String(it[1]) == "" else " · " + String(it[1]))
		var l := _lbl(t, 14, Color.WHITE)
		l.add_theme_constant_override("outline_size", 4)
		l.add_theme_color_override("font_outline_color", UiTheme.color("encre.700"))
		chip.add_child(l)
		chip.gui_input.connect(_on_card_input.bind(String(it[0])))
		_pack.add_child(chip)


## Colonne de l'équipe : plan annoncé, or de l'équipe, une ligne par héros (rôle, or, prêt ou ce qui lui manque).
func _fill_team() -> void:
	var rows: Array = dir.call("team_rows", Assault.team_of(key))
	var sig: String = str(rows) + String(AssaultItems.plans[Assault.team_of(key)])
	if _team.get_meta("sig", "") == sig:
		return
	_team.set_meta("sig", sig)
	for c in _team.get_children():
		c.queue_free()
	_team.add_child(_lbl("L'équipe", 19, UiTheme.color("encre.700"), UiTheme.title_font()))
	var plan := String(AssaultItems.PLAN_NAMES.get(AssaultItems.plans[Assault.team_of(key)], "Plan à venir"))
	var total := 0
	for r in rows:
		total += int(r.gold)
	var pl := _lbl("Plan : " + plan, 16, UiTheme.color("bonbon.lagon.fonce", Color("0b7db5")))
	_team.add_child(pl)
	_team.add_child(_lbl("or de l'équipe " + _num(total), 14, UiTheme.color("encre.500"), UiTheme.body_font()))
	for r in rows:
		var box := PanelContainer.new()
		box.add_theme_stylebox_override("panel", UiTheme.sticker("papier", {"radius": 12, "shadow": 2, "gloss": false, "pad": Vector2(10, 4)}))
		var vb := VBoxContainer.new()
		vb.add_theme_constant_override("separation", 0)
		box.add_child(vb)
		vb.add_child(_lbl(String(r.name), 15, UiTheme.color("encre.700")))
		var line := "%s · %s or" % [AssaultCombat.role_name(String(r.role)), _num(int(r.gold))]
		vb.add_child(_lbl(line, 13, UiTheme.color("encre.500"), UiTheme.body_font()))
		var st := _lbl(String(r.status), 13, UiTheme.color("bonbon.pomme.fonce", Color("5f8f12")) if String(r.status).begins_with("✔")
			else UiTheme.color("bonbon.fraise.fonce", Color("b0174a")), UiTheme.body_font())
		vb.add_child(st)
		_team.add_child(box)
