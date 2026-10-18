class_name MobaStore
extends Control
## Boutique des Deux Voies (lot MB-H ; étude conception/benchmark/MOBA.md § 7.7, croquis moba_maquettes/v2_boutique.svg ; DA v2
## « autocollant manga »). Panneau sur la moitié gauche : la partie continue derrière (la scène reste visible) ; ouverte à la
## manette (Vue à la base), la partie attend que tu la fermes (UiNav navigue alors l'écran comme un menu).
## - en-tête : « Boutique », où l'on est (à la fontaine / pendant la mort : ouverte ; ailleurs : on regarde sans acheter), l'or ;
## - 7 onglets (Conseillé, Attaque, Magie, Défense, Soutien, Bottes, Potions ; LB / RB) ;
## - cartes d'objets (clic : la fiche ; double clic, clic droit ou X : acheter) ; une carte grise = pas assez d'or ou pas
##   possible (la raison est écrite) ; l'onglet Conseillé montre le parcours de ta famille, adapté à l'équipe adverse ;
## - la fiche : effet en une phrase (jamais de pourcentage : les chiffres sont dans l'infobulle), prix réel (recette : on ne paie
##   que la différence), recette avec ce que tu portes déjà, ce à quoi l'objet mène ;
## - « Tes objets » (6 places) : maintenir 0,6 s (ou clic droit, X) pour vendre ; potions ;
## - « Acheter » (l'objet choisi), « Conseillé » ([Entrée] : la prochaine étape du parcours), « Annuler l'achat » ([Ctrl + Z],
##   tant qu'on n'a pas quitté la base), « Achats automatiques » (le parcours conseillé et les choix de niveau se font seuls).
## Toute écriture passe par MobaItems (buy, sell, undo) : l'écran ne touche jamais l'or lui-même.

signal closed

const W_WIDE := 760.0
const W_NARROW := 640.0
const CARD := Vector2(150, 84)
const CARD_NARROW := Vector2(136, 84)
const DETAIL_W := 248.0
const DETAIL_W_NARROW := 214.0
const HOLD := MobaData.SELL_HOLD
## Pictogramme de chaque objet (Ico) ; le fond de la case suit son type (TYPE_TONES).
const ICONS := {
	"lame_courte": "attack", "grimoire_use": "grimoire", "cotte_mailles": "armor", "gemme_vie": "heart", "gant_vitesse": "speed",
	"oeil_faucon": "star", "sablier_fele": "hourglass", "plume_soin": "st_grace", "croc_vampire": "st_bleed", "bottes_marche": "slot_boots",
	"lame_braise": "swords", "croc_chasseur": "st_hunter_stance", "arc_tempete": "spark", "faux_lune": "slot_weapon", "brise_garde": "st_might",
	"lame_executeur": "skull", "orbe_marees": "st_resolve", "baton_eclipse": "mana", "grimoire_echos": "grimoire", "sceptre_givre": "st_root",
	"lanterne_ames": "st_angel", "egide_rempart": "defense", "coeur_pierre": "st_vitality", "cape_epines": "st_thorns",
	"bouclier_gardien": "st_titan", "armure_vivante": "armor", "heaume_colosse": "slot_head", "encensoir": "st_grace",
	"medaillon_aurores": "slot_necklace", "harpe_vent": "st_swift", "etendard_voies": "crown", "sablier_sage": "hourglass",
	"bottes_elan": "slot_boots", "bottes_rempart": "slot_boots", "bottes_sage": "slot_boots", "bottes_vent": "slot_boots",
	"potion_soin": "potion", "potion_elan": "potion", "potion_rage": "potion", "potion_acuite": "potion",
}
const TYPE_TONES := {"composant": "gris", "bottes": "pomme", "attaque": "fraise", "magie": "amethyste", "défense": "soleil",
	"soutien": "lagon", "polyvalent": "mandarine", "potion": "fraise"}
const STAT_TONES := {"atk": "fraise", "matk": "amethyste", "def": "soleil", "hp": "pomme", "atk_speed": "mandarine", "crit": "mandarine",
	"cdr": "lagon", "heal_power": "lagon", "lifesteal": "fraise", "move": "pomme"}
const TYPE_NAMES := {"composant": "Composant", "bottes": "Bottes", "attaque": "Attaque", "magie": "Magie", "défense": "Défense",
	"soutien": "Soutien", "polyvalent": "Polyvalent", "potion": "Potion"}
## Stats des objets en mots (aucun pourcentage dans le texte permanent : les chiffres sont dans l'infobulle).
const STAT_WORDS := {"atk": "attaque", "matk": "magie", "matk_total": "toute la magie", "def": "défense", "hp": "PV", "atk_speed": "vitesse d'attaque",
	"crit": "critique", "cdr": "recharges", "heal_power": "puissance de soin", "lifesteal": "vol de vie", "move": "vitesse",
	"ooc_move": "vitesse hors combat", "pen": "défense traversée", "execute": "contre les affaiblis", "spell_vamp": "soin des sorts",
	"crowd_def": "défense en nombre", "ooc_regen": "repos hors combat", "thorns": "épines", "heal_taken": "soins reçus", "tenacity": "ténacité",
	"minion_aura": "sbires proches"}
const FAMILY_NAMES := {1: "Rempart", 2: "Ombre", 3: "Traque", 4: "Ferveur", 5: "Arcane"}

var hud: MobaHud
var tab := 0
var selected := ""
var paused_by_me := false
var cards: Array = []  # [Button, id] (tests)
var _panel: PanelContainer
var _state: Label
var _gold: Label
var _tabs: Array = []
var _grid: GridContainer
var _scroll: ScrollContainer
var _detail: VBoxContainer
var _owned: HBoxContainer
var _owned_btns: Array = []
var _btn_buy: Button
var _btn_next: Button
var _btn_undo: Button
var _btn_auto: Button
var _btn_close: Button
var _note: Label
var _narrow := false
var _sig := ""
var _t := 0.0
var _hold := -1
var _hold_t := 0.0
var _last_click := {}  # id -> ms


func setup(h: MobaHud) -> void:
	hud = h
	name = "MobaStore"
	add_to_group("tab_screens")
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	refresh(true)


func hs() -> MobaHero:
	return hud.me() if hud != null else null


func is_open() -> bool:
	return visible and is_inside_tree()


## [param pad] : ouverte à la manette, la partie attend (UiNav en a besoin : il ne navigue que les menus en pause).
func open(pad := false) -> void:
	visible = true
	_sig = ""
	if selected == "":
		var adv: Dictionary = hud.data.get("advice", {})
		selected = String(adv.get("id", ""))
	refresh(true)
	UiFeel.page_sound(true)
	if pad and not get_tree().paused:
		paused_by_me = true
		get_tree().paused = true
	if Gamepad.active:
		UiNav.reveal()


func close() -> void:
	if not visible:
		return
	visible = false
	_hold = -1
	UiFeel.page_sound(false)
	if paused_by_me:
		paused_by_me = false
		get_tree().paused = false
	closed.emit()


## LB / RB (UiNav) : onglet voisin.
func step_page(delta: int) -> void:
	set_tab(wrapi(tab + delta, 0, MobaData.TABS.size()))
	UiFeel.cue("ui_tab", -10.0)


func set_tab(i: int) -> void:
	tab = i
	_sig = ""
	refresh(true)


# --- construction ----------------------------------------------------------------------------------------------------

func _lbl(text: String, size: int, col: Color, font: Font = null) -> Label:
	var l := Label.new()
	l.text = text
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_override("font", font if font != null else UiTheme.bold_font())
	l.add_theme_font_size_override("font_size", UiTheme.text_size(size))
	l.add_theme_color_override("font_color", col)
	return l


func _button(text: String, tone: String, cb: Callable, fs := 16) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	UiTheme.style_button(b, tone, fs)
	b.custom_minimum_size.y = 42
	b.pressed.connect(cb)
	return b


func _build() -> void:
	var vs := get_viewport_rect().size if is_inside_tree() else Vector2(1600, 900)
	_narrow = vs.x < 1500.0
	var k := clampf(vs.y / 900.0, 0.8, 1.0)
	_panel = PanelContainer.new()
	_panel.name = "StorePanel"
	_panel.add_theme_stylebox_override("panel", UiTheme.panel_style(7, Vector2(16, 12)))
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_panel)
	var w := minf(W_NARROW if _narrow else W_WIDE, vs.x * 0.5 + 40.0)
	var top := roundf(8.0 + (MobaHud.BAND_H + 6.0 + MobaHud.OBJ_H + 10.0) * k)
	_panel.position = Vector2(16, top)
	_panel.custom_minimum_size = Vector2(w, vs.y - top - 14.0)
	_panel.size = _panel.custom_minimum_size
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	_panel.add_child(v)
	# en-tête
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	v.add_child(head)
	head.add_child(_lbl("Boutique", 26, UiTheme.color("encre.700"), UiTheme.title_font()))
	var sbox := PanelContainer.new()
	sbox.name = "StoreState"
	sbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sbox.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(sbox)
	_state = _lbl("", 14, Color.WHITE)
	_state.add_theme_constant_override("outline_size", 4)
	_state.add_theme_color_override("font_outline_color", UiTheme.color("encre.700"))
	sbox.add_child(_state)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(sp)
	var coin := Ico.rect("coin", 26)
	if coin != null:
		head.add_child(coin)
	_gold = _lbl("0", 24, UiTheme.color("encre.700"), UiTheme.number_font())
	head.add_child(_gold)
	_btn_close = _button("✕ [P]", "papier", close, 15)
	_btn_close.name = "StoreClose"
	head.add_child(_btn_close)
	# onglets
	var tabs := HFlowContainer.new()
	tabs.add_theme_constant_override("h_separation", 5)
	tabs.add_theme_constant_override("v_separation", 5)
	v.add_child(tabs)
	if Gamepad.active:
		var lb := Ico.rect("pad_lb", 24)
		if lb != null:
			tabs.add_child(lb)
	for i in MobaData.TABS.size():
		var b := Button.new()
		b.name = "StoreTab_%s" % MobaData.TABS[i][0]
		b.text = String(MobaData.TABS[i][1])
		b.toggle_mode = true
		b.focus_mode = Control.FOCUS_NONE
		b.set_meta("ui_feel", "tab")
		UiTheme.style_button(b, "papier", 15 if not _narrow else 14, {"selected_tone": "mandarine", "pad": Vector2(8, 3)})
		b.pressed.connect(set_tab.bind(i))
		tabs.add_child(b)
		_tabs.append(b)
	if Gamepad.active:
		var rb := Ico.rect("pad_rb", 24)
		if rb != null:
			tabs.add_child(rb)
	# corps : cartes à gauche, fiche à droite
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 10)
	v.add_child(body)
	_scroll = ScrollContainer.new()
	_scroll.name = "StoreCards"
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.follow_focus = true
	body.add_child(_scroll)
	_grid = GridContainer.new()
	_grid.columns = 3 if not _narrow else 3
	_grid.add_theme_constant_override("h_separation", 8)
	_grid.add_theme_constant_override("v_separation", 8)
	_scroll.add_child(_grid)
	var dpanel := PanelContainer.new()
	dpanel.name = "StoreDetail"
	dpanel.add_theme_stylebox_override("panel", UiTheme.sticker("papier2", {"radius": 14, "shadow": 3, "gloss": false, "pad": Vector2(12, 8)}))
	dpanel.custom_minimum_size.x = DETAIL_W_NARROW if _narrow else DETAIL_W
	body.add_child(dpanel)
	var dscroll := ScrollContainer.new()
	dscroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	dpanel.add_child(dscroll)
	_detail = VBoxContainer.new()
	_detail.add_theme_constant_override("separation", 4)
	_detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dscroll.add_child(_detail)
	# tes objets
	var own_head := HBoxContainer.new()
	own_head.add_theme_constant_override("separation", 8)
	v.add_child(own_head)
	own_head.add_child(_lbl("Tes objets", 17, UiTheme.color("encre.700"), UiTheme.title_font()))
	var hint := _lbl("maintenir pour vendre", 14, UiTheme.color("encre.500"), UiTheme.body_font())
	hint.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	own_head.add_child(hint)
	_owned = HBoxContainer.new()
	_owned.add_theme_constant_override("separation", 6)
	v.add_child(_owned)
	for i in MobaData.SLOTS:
		var b := OwnedSlot.new()
		b.store = self
		b.index = i
		b.name = "StoreOwned_%d" % i
		b.custom_minimum_size = Vector2(52, 52)
		b.focus_mode = Control.FOCUS_NONE
		b.set_meta("ui_feel", "slot")
		UiTheme.style_button(b, "papier", 0, {"radius": 12, "pad": Vector2(2, 2), "shadow": 3})
		b.button_down.connect(_hold_start.bind(i))
		b.button_up.connect(_hold_stop.bind(i))
		b.gui_input.connect(_on_owned_input.bind(i))
		_owned.add_child(b)
		_owned_btns.append(b)
	var pots := Control.new()
	pots.custom_minimum_size = Vector2(8, 0)
	_owned.add_child(pots)
	# pied : boutons
	var foot := HFlowContainer.new()
	foot.add_theme_constant_override("h_separation", 8)
	foot.add_theme_constant_override("v_separation", 6)
	v.add_child(foot)
	_btn_buy = _button("Acheter", "soleil", _buy_selected, 18)
	_btn_buy.name = "StoreBuy"
	foot.add_child(_btn_buy)
	_btn_next = _button("Conseillé · [Entrée]", "lagon", buy_next, 15)
	_btn_next.name = "StoreNext"
	foot.add_child(_btn_next)
	_btn_undo = _button("↶ Annuler · [Ctrl+Z]", "papier", undo, 15)
	_btn_undo.name = "StoreUndo"
	foot.add_child(_btn_undo)
	_btn_auto = _button("Achats automatiques", "papier", _toggle_auto, 15)
	_btn_auto.name = "StoreAuto"
	_btn_auto.toggle_mode = true
	UiTheme.style_button(_btn_auto, "papier", 15, {"selected_tone": "pomme"})
	_btn_auto.tooltip_text = "Le parcours conseillé s'achète seul à chaque passage à la base, et les choix de niveau se font seuls."
	foot.add_child(_btn_auto)
	_note = _lbl("", 14, UiTheme.color("encre.500"), UiTheme.body_font())
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_note)


# --- mise à jour -----------------------------------------------------------------------------------------------------

func _process(delta: float) -> void:
	if not visible:
		return
	_t -= delta
	if _t <= 0.0:
		_t = 0.2
		refresh()
	if _hold >= 0:
		_hold_t += delta
		(_owned_btns[_hold] as Control).queue_redraw()
		if _hold_t >= HOLD:
			var i := _hold
			_hold = -1
			sell(i)


## Ids de l'onglet [param t] (Conseillé : le parcours, puis ce qu'il faut pour sa prochaine étape).
func tab_ids(t: int = -1) -> Array:
	if t < 0:
		t = tab
	var key := String(MobaData.TABS[t][0])
	var h := hs()
	if key == "advised":
		var out: Array = []
		var r: Array = hud.data.get("route", [])
		if r.is_empty() and h != null:
			r = MobaItems.route(h)
		for id in r:
			for c in MobaData.item(String(id)).get("recipe", []):
				if not String(c) in out:
					out.append(String(c))
			if not String(id) in out:
				out.append(String(id))
		if not "potion_soin" in out:
			out.append("potion_soin")
		return out
	var ids: Array = MobaData.tab_items(key).map(func(it): return String(it.id))
	if key == "potion":
		return ids
	if key in ["attack", "magic", "defense", "support"]:
		# les composants de l'onglet d'abord (une carte qui mène aux objets de l'onglet)
		var comps: Array = []
		for id in ids:
			for c in MobaData.item(String(id)).get("recipe", []):
				if not String(c) in comps and not String(c) in ids:
					comps.append(String(c))
		comps.sort_custom(func(a, b): return int(MobaData.item(a).price) < int(MobaData.item(b).price))
		return comps + ids
	return ids


func refresh(force := false) -> void:
	var h := hs()
	if h == null or not is_inside_tree():
		return
	var open_ok := MobaItems.shop_open(h)
	_state.text = ("À la fontaine" if not h.node.is_dead else "Pendant la mort") if open_ok else "Rejoins la fontaine pour acheter"
	(_state.get_parent() as PanelContainer).add_theme_stylebox_override("panel", UiTheme.sticker("pomme" if open_ok else "gris",
		{"radius": 10, "pad": Vector2(10, 2), "shadow": 2, "gloss": false}))
	_gold.text = MobaHud.num(h.gold)
	for i in _tabs.size():
		(_tabs[i] as Button).set_pressed_no_signal(i == tab)
	var sig := "%d|%d|%s|%s|%s|%s" % [tab, int(h.gold), str(h.items), str(h.potions), str(open_ok), selected]
	if sig != _sig or force:
		_sig = sig
		_fill_cards(h)
		_fill_detail(h)
		_fill_owned(h)
	var step := MobaItems.next_step(h, MobaItems.route(h, hud.dd().foe_families(h) if hud.dd() != null else []))
	_btn_next.disabled = step == ""
	_btn_next.text = ("Conseillé : %s · [Entrée]" % String(MobaData.item(step).name)) if step != "" else "Conseillé · rien à payer"
	_btn_undo.disabled = h.history.is_empty() or not open_ok
	_btn_auto.set_pressed_no_signal(h.auto_pick)
	var why := MobaItems.why_not(h, selected) if selected != "" else "Choisis un objet."
	_btn_buy.disabled = why != ""
	_btn_buy.text = ("Acheter · %s" % MobaHud.num(float(MobaItems.quote(h, selected).cost) if not MobaItems.is_potion(selected) else float(MobaData.item(selected).price))) \
		if why == "" else ("Acheter" if selected == "" else why.trim_suffix("."))
	_note.text = "[Clic] la fiche · [Double clic] ou [Clic droit] acheter · %s · les chiffres sont dans l'infobulle" % (
		"LB / RB onglets · X acheter" if Gamepad.active else "[P] fermer")


## Fond de la case d'un objet : la couleur de son type ; un composant prend celle de ce qu'il donne (attaque fraise, magie
## améthyste, défense soleil, PV pomme…), un fond gris éteindrait son pictogramme blanc.
static func type_tone(id: String) -> String:
	var it := MobaData.item(id)
	if String(it.get("type", "")) == "composant":
		var st: Dictionary = it.get("stats", {})
		var k := String(st.keys()[0]) if not st.is_empty() else ""
		return String(STAT_TONES.get(k, "lagon"))
	return String(TYPE_TONES.get(String(it.get("type", "")), "papier"))


static var _tex: Dictionary = {}


## Pictogramme [param id] : celui d'Ico (ico_<id>.png), sinon le pictogramme générique (assets/ui/icons/<id>.png).
static func icon(id: String) -> Texture2D:
	if not _tex.has(id):
		var t: Texture2D = null
		if ResourceLoader.exists(Ico.path(id)):
			t = Ico.tex(id)
		elif ResourceLoader.exists("res://assets/ui/icons/%s.png" % id):
			t = UiTheme.texture("res://assets/ui/icons/%s.png" % id)
		_tex[id] = t
	return _tex[id]


## Case d'objet dessinée (bord d'encre, fond du type, pictogramme) : HUD, tableau des scores, boutique.
static func draw_item_cell(ci: CanvasItem, r: Rect2, id: String, big := false) -> void:
	var tones := UiTheme.tones(type_tone(id))
	RoyaleHudStyle.draw_sticker(ci, r, tones[1], maxf(6.0, r.size.x * 0.24), 3.0 if big else 2.0, 3.0 if big else 2.0)
	var tex: Texture2D = null
	var it := MobaData.item(id)
	if String(it.get("type", "")) == "potion":
		tex = UiTheme.texture(Potions.icon_path(String(it.get("potion", "heal"))))
	if tex == null:
		tex = icon(String(ICONS.get(id, "misc")))
	if tex != null:
		ci.draw_texture_rect(tex, r.grow(-maxf(3.0, r.size.x * 0.14)), false)


func _fill_cards(h: MobaHero) -> void:
	for c in _grid.get_children():
		c.queue_free()
	cards = []
	var ids := tab_ids()
	var key := String(MobaData.TABS[tab][0])
	if key == "advised":
		var fam := String(FAMILY_NAMES.get(h.family, ""))
		var adapt: Array = hud.data.get("route", [])
		var base := MobaItems.route(h, [], false)
		var line := "Ton parcours · %s" % fam
		if adapt != base and not adapt.is_empty():
			line += " · adapté à leur équipe"
		var l := _lbl(line, 15, UiTheme.color("encre.700"))
		_grid.add_child(l)
		for _i in _grid.columns - 1:
			var sp := Control.new()
			sp.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_grid.add_child(sp)
	for id in ids:
		var b := _card(String(id), h)
		_grid.add_child(b)
		cards.append([b, String(id)])


func _card(id: String, h: MobaHero) -> Button:
	var it := MobaData.item(id)
	var b := Button.new()
	b.name = "StoreCard_" + id
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = CARD_NARROW if _narrow else CARD
	b.set_meta("ui_feel", "card")
	b.set_meta("moba_item", id)
	var owned := id in h.items and not MobaItems.is_potion(id)
	var why := MobaItems.why_not(h, id)
	var tone := "papier"
	if owned:
		tone = "pomme"
	elif why != "":
		tone = "gris"
	if id == selected:
		tone = "lagon" if not owned else tone
	UiTheme.style_button(b, tone, 0, {"radius": 14, "pad": Vector2(6, 4)})
	b.tooltip_text = "%s · %s\n%s" % [String(it.get("name", id)), String(it.get("text", "")), String(it.get("tip", ""))]
	var m := MarginContainer.new()
	m.set_anchors_preset(Control.PRESET_FULL_RECT)
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for s in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + s, 7)
	b.add_child(m)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 6)
	m.add_child(row)
	var cell := ItemCell.new()
	cell.id = id
	cell.custom_minimum_size = Vector2(40, 40)
	cell.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cell.dim = why != "" and not owned
	row.add_child(cell)
	var tx := VBoxContainer.new()
	tx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tx.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tx.add_theme_constant_override("separation", 0)
	row.add_child(tx)
	var ink := Color.WHITE if tone in ["pomme", "lagon"] else UiTheme.color("encre.700")
	var nm := _lbl(String(it.get("name", id)), 14, ink)
	nm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	nm.max_lines_visible = 2
	if ink == Color.WHITE:
		nm.add_theme_constant_override("outline_size", 4)
		nm.add_theme_color_override("font_outline_color", UiTheme.color("encre.700"))
	tx.add_child(nm)
	var price := ""
	if owned:
		price = "✔ À toi"
	elif MobaItems.is_potion(id):
		price = "%s or · ×%d" % [MobaHud.num(float(it.price)), MobaItems.potion_count(h, String(it.potion))]
	else:
		var q := MobaItems.quote(h, id)
		price = "%s or" % MobaHud.num(float(q.cost))
	var pl := _lbl(price, 14, ink if ink == Color.WHITE else (UiTheme.color("bonbon.fraise.fonce", Color("b0174a")) if why == "Pas assez d'or." else UiTheme.color("encre.500")),
		UiTheme.number_font())
	if ink == Color.WHITE:
		pl.add_theme_constant_override("outline_size", 4)
		pl.add_theme_color_override("font_outline_color", UiTheme.color("encre.700"))
	pl.clip_text = true
	pl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	tx.add_child(pl)
	b.pressed.connect(_on_card.bind(id))
	b.gui_input.connect(_on_card_input.bind(id))
	return b


func _on_card(id: String) -> void:
	var now := Time.get_ticks_msec()
	if selected == id and now - int(_last_click.get(id, 0)) < 420:
		buy(id)
	else:
		selected = id
		_sig = ""
		refresh()
	_last_click[id] = now


func _on_card_input(ev: InputEvent, id: String) -> void:
	var mb := ev as InputEventMouseButton
	if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_RIGHT:
		get_viewport().set_input_as_handled()
		selected = id
		buy(id)


## Fiche de l'objet choisi : nom, type, prix réel, ce qu'il donne (en mots), son effet, la recette, ce à quoi il mène.
func _fill_detail(h: MobaHero) -> void:
	for c in _detail.get_children():
		c.queue_free()
	if selected == "" or MobaData.item(selected).is_empty():
		_detail.add_child(_lbl("Choisis un objet pour voir sa fiche.", 15, UiTheme.color("encre.500"), UiTheme.body_font()))
		return
	var it := MobaData.item(selected)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	_detail.add_child(head)
	var cell := ItemCell.new()
	cell.id = selected
	cell.custom_minimum_size = Vector2(52, 52)
	head.add_child(cell)
	var hv := VBoxContainer.new()
	hv.add_theme_constant_override("separation", 0)
	hv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(hv)
	var nm := _lbl(String(it.name), 17, UiTheme.color("encre.700"), UiTheme.title_font())
	nm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hv.add_child(nm)
	var finished := not String(it.type) in ["composant", "bottes", "potion"] or not (it.get("recipe", []) as Array).is_empty()
	hv.add_child(_lbl("%s%s" % [TYPE_NAMES.get(String(it.type), ""), " · objet fini" if finished and String(it.type) != "potion" else ""], 14,
		UiTheme.color("encre.500"), UiTheme.body_font()))
	var cost := int(it.price) if MobaItems.is_potion(selected) else int(MobaItems.quote(h, selected).cost)
	var pr := "%s or" % MobaHud.num(float(cost))
	if cost <= int(h.gold):
		pr += " (reste %s)" % MobaHud.num(h.gold - cost)
	else:
		pr += " (il manque %s)" % MobaHud.num(cost - h.gold)
	_detail.add_child(_lbl(pr, 15, UiTheme.color("encre.700"), UiTheme.number_font()))
	var st: Dictionary = it.get("stats", {})
	for key in st:
		var v := float(st[key])
		var amount := "forte" if v >= 0.2 else ("moyenne" if v >= 0.1 else "légère")
		_detail.add_child(_lbl("+ %s (%s)" % [STAT_WORDS.get(String(key), String(key)), amount], 14, UiTheme.color("bonbon.pomme.fonce", Color("4f8f10")),
			UiTheme.bold_font()))
	var tx := _lbl(String(it.get("text", "")), 15, UiTheme.color("encre.700"), UiTheme.body_font())
	tx.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail.add_child(tx)
	var tip := _lbl("Le détail chiffré : survol de la carte", 14, UiTheme.color("encre.500"), UiTheme.body_font())
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tip.tooltip_text = String(it.get("tip", ""))
	tip.mouse_filter = Control.MOUSE_FILTER_PASS
	_detail.add_child(tip)
	var rec: Array = it.get("recipe", [])
	if not rec.is_empty():
		_detail.add_child(_lbl("Recette", 16, UiTheme.color("encre.700"), UiTheme.title_font()))
		var have := h.items.duplicate()
		for c in rec:
			var i := have.find(String(c))
			var got := i >= 0
			if got:
				have.remove_at(i)
			var cl := _lbl(("✔ " if got else "• ") + String(MobaData.item(String(c)).name) + ("" if got else " · %s" % MobaHud.num(float(MobaData.item(String(c)).price))),
				14, UiTheme.color("bonbon.pomme.fonce", Color("4f8f10")) if got else UiTheme.color("encre.700"), UiTheme.bold_font())
			_detail.add_child(cl)
		if MobaItems.quote(h, selected).used.size() > 0:
			var nt := _lbl("Ce que tu portes compte : tu ne paies que la différence.", 14, UiTheme.color("encre.500"), UiTheme.body_font())
			nt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			_detail.add_child(nt)
	var leads: Array = []
	for e in MobaData.ITEMS:
		if selected in (e.get("recipe", []) as Array):
			leads.append(String(e.name))
	if not leads.is_empty():
		var ll := _lbl("Mène à : " + ", ".join(leads.slice(0, 4)) + ("…" if leads.size() > 4 else ""), 14, UiTheme.color("encre.500"), UiTheme.body_font())
		ll.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_detail.add_child(ll)


func _fill_owned(h: MobaHero) -> void:
	for i in _owned_btns.size():
		var b: OwnedSlot = _owned_btns[i]
		b.item = String(h.items[i]) if i < h.items.size() else ""
		b.disabled = b.item == ""
		b.tooltip_text = ("%s : maintenir pour vendre (%s or)" % [String(MobaData.item(b.item).name),
			MobaHud.num(floorf(float(MobaData.item(b.item).price) * MobaData.SELL_BACK))]) if b.item != "" else "Place libre"
		b.queue_redraw()


# --- actions -----------------------------------------------------------------------------------------------------------

func buy(id: String) -> bool:
	var h := hs()
	if h == null:
		return false
	var why := MobaItems.why_not(h, id)
	if why != "" or not MobaItems.buy(h, id):
		UiFeel.cue("ui_deny", -8.0)
		hud.announce.push(why if why != "" else "Achat impossible", "", 0, "lagon", 1.2)
		return false
	UiFeel.cue("ui_coin", -8.0)
	_sig = ""
	refresh()
	return true


func _buy_selected() -> void:
	if selected != "":
		buy(selected)


## Achète la prochaine étape du parcours conseillé ([Entrée] ; « Acheter » en un appui, MOBA.md § 7.7).
func buy_next() -> bool:
	var h := hs()
	var d := hud.dd()
	if h == null or d == null:
		return false
	var id := MobaItems.next_step(h, MobaItems.route(h, d.foe_families(h)))
	if id == "":
		UiFeel.cue("ui_deny", -8.0)
		return false
	selected = id
	return buy(id)


func undo() -> bool:
	var h := hs()
	if h == null or not MobaItems.undo(h):
		UiFeel.cue("ui_deny", -10.0)
		return false
	UiFeel.cue("ui_coin", -10.0, 0.85)
	_sig = ""
	refresh()
	return true


func sell(i: int) -> bool:
	var h := hs()
	if h == null or i >= h.items.size():
		return false
	var id := String(h.items[i])
	if not MobaItems.sell(h, i):
		UiFeel.cue("ui_deny", -10.0)
		return false
	UiFeel.cue("ui_coin", -10.0, 0.85)
	hud.announce.push("%s vendu" % String(MobaData.item(id).name), "", 0, "lagon", 1.2)
	_sig = ""
	refresh()
	return true


func _toggle_auto() -> void:
	var h := hs()
	if h == null:
		return
	h.auto_pick = not h.auto_pick
	if h.auto_pick:
		while not h.pending.is_empty():
			hud.choose(h.auto_choice())
	refresh(true)


func _hold_start(i: int) -> void:
	var h := hs()
	if h == null or i >= h.items.size() or not MobaItems.shop_open(h):
		return
	_hold = i
	_hold_t = 0.0


func _hold_stop(i: int) -> void:
	if _hold == i:
		_hold = -1
		var h := hs()
		if h != null and i < h.items.size():
			selected = String(h.items[i])
			_sig = ""
			refresh()
	(_owned_btns[i] as Control).queue_redraw()


func _on_owned_input(ev: InputEvent, i: int) -> void:
	var mb := ev as InputEventMouseButton
	if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_RIGHT:
		get_viewport().set_input_as_handled()
		sell(i)


## Avancée du maintien pour vendre la place [param i] (0-1 ; -1 : aucun).
func hold_ratio(i: int) -> float:
	return clampf(_hold_t / HOLD, 0.0, 1.0) if _hold == i else -1.0


func _input(ev: InputEvent) -> void:
	if not is_open():
		return
	var key := ev as InputEventKey
	if key != null and key.pressed and not key.echo:
		if key.physical_keycode == KEY_P or key.physical_keycode == KEY_ESCAPE:
			get_viewport().set_input_as_handled()
			close()
		elif key.ctrl_pressed and key.physical_keycode == KEY_Z:
			get_viewport().set_input_as_handled()
			undo()
		elif key.physical_keycode == KEY_ENTER or key.physical_keycode == KEY_KP_ENTER:
			get_viewport().set_input_as_handled()
			buy_next()
	elif ev.is_action_pressed("ui_cancel") and not ev is InputEventKey:
		get_viewport().set_input_as_handled()
		close()
	elif ev is InputEventJoypadButton and (ev as InputEventJoypadButton).pressed and (ev as InputEventJoypadButton).button_index == JOY_BUTTON_BACK:
		get_viewport().set_input_as_handled()
		close()


## Case d'objet (pictogramme sur le fond de son type) ; [member dim] : trop cher ou impossible (tramée).
class ItemCell extends Control:
	var id := ""
	var dim := false

	func _draw() -> void:
		if id == "":
			return
		var r := Rect2(Vector2.ZERO, size)
		MobaStore.draw_item_cell(self, r, id, size.x >= 48.0)
		if dim:
			draw_rect(r.grow(-2.0), Color(RoyaleHudStyle.PAPER_300, 0.55))
			RoyaleHudStyle.draw_halftone(self, r.grow(-3.0), Color(RoyaleHudStyle.INK, 0.22), 6.0, 1.1)


## Place d'objet du héros (bouton) : la case, et l'anneau qui se remplit pendant le maintien pour vendre.
class OwnedSlot extends Button:
	var store: MobaStore
	var index := 0
	var item := ""

	func _draw() -> void:
		var r := Rect2(Vector2(5, 4), size - Vector2(10, 12))
		if item == "":
			RoyaleHudStyle.draw_halftone(self, r, Color(RoyaleHudStyle.INK, 0.16), 6.0, 1.1)
			return
		MobaStore.draw_item_cell(self, r, item, false)
		var k := store.hold_ratio(index) if store != null else -1.0
		if k >= 0.0:
			draw_arc(r.get_center(), r.size.x * 0.5 + 1.0, -PI * 0.5, -PI * 0.5 + TAU * k, 32, RoyaleHudStyle.danger()[1], 5.0, true)
