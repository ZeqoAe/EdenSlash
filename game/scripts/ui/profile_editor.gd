class_name ProfileEditor
extends CanvasLayer
## Éditeur de profils types (lobby : Jouer > Profils types, ou Duel > Éditeur d'adversaire) :
## un build complet d'une classe à un niveau, sur une seule page à sous-pages :
## - Équipement : 10 pièces du catalogue d'Eden ; pour la pièce choisie, rareté, amélioration
##   (+0 à +10) et la stat bonus de chaque palier (+4, +6, +8, +10), 2 gemmes, enchantement, et
##   sa carte (toutes ses stats) en direct ; carte complète au survol de chaque pièce ;
## - Sorts : 12 emplacements (4 cases × principal et 2 enchaînements), fiche du sort au survol ;
## - Maîtrise : l'arbre de talents de la classe (points de maîtrise), fiche au survol ;
## - Certificats (7 au plus) ; Apparence : tenue, tête, dos avec leurs teintures (coloris d'Eden
##   ou 3 couleurs libres), aura et sa teinture ; Adversaire (PV ×, dégâts ×).
## À gauche : aperçu 3D et stats calculées comme un héros. Profils enregistrés dans les données
## du jeu (RivalBuilds) ; « Appliquer à mon héros » (mode dev) ; « Utiliser pour le duel ».

const SLOTS := ["weapon", "head", "chest", "legs", "gloves", "boots", "back", "necklace", "ring", "trophy"]
const LOOK := [["body", "Tenue"], ["head", "Tête"], ["back", "Dos"]]
const TABS := ["Équipement", "Sorts", "Maîtrise", "Certificats", "Apparence", "Adversaire"]
const DYE_NAMES := ["Couleur principale", "Couleur secondaire", "Détails"]
const AURA_PRESETS := [[255, 80, 60], [255, 190, 60], [90, 230, 110], [70, 170, 255], [170, 90, 255], [255, 120, 220], [235, 235, 245]]

var build: Dictionary
var on_use: Callable
var _tab := 0
var _slot := "weapon"

var _saved: Button
var _name: LineEdit
var _class_btn: Button
var _level: SpinBox
var _preview: EquipmentPage.HeroPreview
var _stats: RichTextLabel
var _tabs: HBoxContainer
var _page: VBoxContainer
var _msg: Label
var _picker: Control


## Ouvre l'éditeur sur une copie de [param b] ; [param use] (facultatif) reçoit le profil quand
## on clique « Utiliser pour le duel ».
static func open(anchor: Node, b: Dictionary, use := Callable()) -> ProfileEditor:
	var e := ProfileEditor.new()
	e.build = b.duplicate(true)
	e.on_use = use
	anchor.get_tree().current_scene.add_child(e)
	return e


func _ready() -> void:
	layer = 55
	if not build.has("level"):
		build["level"] = 20
	build["spells"] = Duel.grid12(build.get("spells", []))
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.01, 0.05, 0.88)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiTheme.flat_box(Color(0.05, 0.04, 0.1, 0.98), UiTheme.GOLD, 2, 12))
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.offset_left = 16
	panel.offset_top = 12
	panel.offset_right = -16
	panel.offset_bottom = -12
	root.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	panel.add_child(v)
	# ligne 1 : profil, nom, classe, niveau
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	v.add_child(top)
	var t := Hud._label(top, "Profils types", 24, UiTheme.GOLD)
	t.add_theme_font_override("font", UiTheme.title_font())
	_saved = MenuWidgets.glass_button("", 15, Vector2(260, 38))
	_saved.pressed.connect(_load_menu)
	top.add_child(_saved)
	_name = LineEdit.new()
	_name.custom_minimum_size = Vector2(240, 38)
	_name.placeholder_text = "Nom du profil"
	_name.text_changed.connect(func(x): build["name"] = x)
	top.add_child(_name)
	_class_btn = MenuWidgets.glass_button("", 15, Vector2(220, 38))
	_class_btn.pressed.connect(func(): HeroPages.class_menu(_class_btn, String(build["class"]), func(c):
		build["class"] = c
		build["spells"] = Duel.grid12([])
		_refresh_all()))
	top.add_child(_class_btn)
	Hud._label(top, "Niveau", 15, UiTheme.TEXT)
	_level = SpinBox.new()
	_level.min_value = 1
	_level.max_value = 101
	_level.value_changed.connect(func(x):
		build["level"] = int(x)
		_refresh_page()
		_refresh_stats())
	top.add_child(_level)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(sp)
	_btn(top, "Fermer", queue_free, 100)
	# ligne 2 : actions
	var acts := HBoxContainer.new()
	acts.add_theme_constant_override("separation", 8)
	v.add_child(acts)
	_btn(acts, "Nouveau", func():
		build = RivalBuilds.blank(String(build.get("class", "warrior")), int(build.get("level", 20)))
		_refresh_all(), 110)
	_btn(acts, "Remplir automatiquement", func():
		RivalBuilds.auto_fill(build)
		_msg.text = "Pièces d'Eden du niveau %d (mythiques) et certificats de la classe posés." % int(build.level)
		_refresh_all(), 230).tooltip_text = "Pour chaque emplacement, la meilleure pièce d'Eden jusqu'au niveau du profil (l'arme de la classe), en mythique ; les certificats de la classe."
	_btn(acts, "Enregistrer", func():
		if String(build.get("name", "")).strip_edges() == "":
			build["name"] = "Profil"
		_msg.text = "« %s » : %s" % [build.name, RivalBuilds.store(build)]
		_refresh_saved(), 130)
	_btn(acts, "Dupliquer", func():
		build["name"] = String(build.get("name", "Profil")) + " (copie)"
		_name.text = build.name
		_msg.text = "Copie : modifie-la puis enregistre", 120)
	_btn(acts, "Supprimer", func():
		RivalBuilds.remove(String(build.get("name", "")))
		_msg.text = "« %s » supprimé" % build.get("name", "")
		_refresh_saved(), 120)
	var apply := _btn(acts, "Appliquer à mon héros", func():
		_msg.text = RivalBuilds.apply_to_hero(build), 220)
	apply.disabled = not bool(Settings.get_v("interface", "dev_mode"))
	apply.tooltip_text = "Mode dev : la classe du profil devient la tienne, ses objets rejoignent ton coffre et s'équipent, avec son preset de sorts, ses certificats et son apparence." \
		if not apply.disabled else "Réservé au mode dev (Paramètres > Caméra & interface) : crée des objets."
	if on_use.is_valid():
		var use := MenuWidgets.gold_button("Utiliser pour le duel", 17, Vector2(240, 38))
		use.pressed.connect(func():
			if String(build.get("name", "")).strip_edges() != "":
				RivalBuilds.store(build)
			on_use.call(build.duplicate(true))
			queue_free())
		acts.add_child(use)
	_msg = Hud._label(acts, "", 14, UiTheme.BUFF)
	_msg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_msg.clip_text = true
	# corps : aperçu et stats | sous-pages
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 12)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(body)
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(290, 0)
	left.add_theme_constant_override("separation", 6)
	body.add_child(left)
	_preview = EquipmentPage.HeroPreview.new()
	_preview.custom_minimum_size = Vector2(290, 330)
	left.add_child(_preview)
	_stats = RichTextLabel.new()
	_stats.bbcode_enabled = true
	_stats.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_stats.add_theme_font_size_override("normal_font_size", 13)
	_stats.add_theme_font_size_override("bold_font_size", 13)
	left.add_child(_stats)
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 6)
	body.add_child(right)
	_tabs = HBoxContainer.new()
	_tabs.add_theme_constant_override("separation", 6)
	right.add_child(_tabs)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right.add_child(scroll)
	_page = VBoxContainer.new()
	_page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_page.add_theme_constant_override("separation", 6)
	scroll.add_child(_page)
	_refresh_saved()
	_refresh_all()


func _btn(parent: Control, text: String, cb: Callable, width: float) -> Button:
	var b := MenuWidgets.glass_button(text, 14, Vector2(width, 36))
	b.pressed.connect(cb)
	parent.add_child(b)
	return b


func _section(parent: Control, text: String) -> void:
	var l := Label.new()
	l.text = text
	UiTheme.title(l, 16)
	parent.add_child(l)


func _refresh_saved() -> void:
	_saved.text = "Charger un profil ▾ (%d)" % RivalBuilds.list().size()


## Profils enregistrés, rangés par classe (sous-menus), du plus bas niveau au plus haut ; la
## classe du profil ouvert en premier.
func _load_menu() -> void:
	var by_class := {}
	var list := RivalBuilds.list()
	for i in list.size():
		var cid := String(list[i].get("class", ""))
		if not by_class.has(cid):
			by_class[cid] = []
		by_class[cid].append(i)
	var order: Array = []
	var cur := String(build.get("class", ""))
	if by_class.has(cur):
		order.append(cur)
	for cid in GameData.classes:
		if by_class.has(cid) and not cid in order:
			order.append(cid)
	for cid in by_class:
		if not cid in order:
			order.append(cid)
	var pm := PopupMenu.new()
	for cid in order:
		var sub := PopupMenu.new()
		var idx: Array = by_class[cid]
		idx.sort_custom(func(a, b): return int(list[a].get("level", 0)) < int(list[b].get("level", 0)) 			or (int(list[a].get("level", 0)) == int(list[b].get("level", 0)) and String(list[a].get("name", "")) < String(list[b].get("name", ""))))
		for i in idx:
			sub.add_item("%s · niv. %d" % [list[i].get("name", "?"), int(list[i].get("level", 20))], i)
		sub.id_pressed.connect(_on_load)
		pm.add_submenu_node_item("%s (%d)" % [GameData.class_data(cid).get("name_fr", cid), idx.size()], sub)
	add_child(pm)
	pm.popup_hide.connect(pm.queue_free)
	var r := _saved.get_global_rect()
	pm.position = Vector2i(int(r.position.x), int(r.end.y))
	pm.popup()


func _on_load(i: int) -> void:
	if i >= 0 and i < RivalBuilds.list().size():
		build = (RivalBuilds.list()[i] as Dictionary).duplicate(true)
		if not build.has("level"):
			build["level"] = 20
		build["spells"] = Duel.grid12(build.get("spells", []))
		_msg.text = "« %s » chargé" % build.name
	_refresh_all()


func _refresh_all() -> void:
	var cid := String(build.get("class", "warrior"))
	_name.text = String(build.get("name", ""))
	_class_btn.text = "Classe : %s ▾" % GameData.class_data(cid).get("name_fr", cid)
	_level.set_value_no_signal(int(build.get("level", 20)))
	for c in _tabs.get_children():
		c.queue_free()
	for i in TABS.size():
		var b := MenuWidgets.glass_button(String(TABS[i]), 15, Vector2(150, 36))
		if i == _tab:
			b.add_theme_stylebox_override("normal", UiTheme.flat_box(Color(0.3, 0.22, 0.08, 0.95), UiTheme.GOLD, 2, 8))
		var k := i
		b.pressed.connect(func():
			_tab = k
			_refresh_all())
		_tabs.add_child(b)
	_refresh_page()
	_refresh_stats()


func _refresh_page() -> void:
	for c in _page.get_children():
		c.queue_free()
	match _tab:
		0:
			_page_gear()
		1:
			_page_spells()
		2:
			_page_talents()
		3:
			_page_certs()
		4:
			_page_look()
		5:
			_page_duel()


func _lv() -> int:
	return int(build.get("level", 20))


## Objet d'une pièce au niveau du profil (puissance au niveau du profil, comme un héros).
func _item(slot: String) -> Dictionary:
	var g: Dictionary = build.get("gear", {}).get(slot, {})
	if g.is_empty():
		return {}
	return RivalBuilds.make_item(slot, g, _lv())


func _with_power(f: Callable):
	var was_active := Run.active
	var was_level := Run.hero_level
	Run.active = true
	Run.hero_level = _lv()
	var r = f.call()
	Run.active = was_active
	Run.hero_level = was_level
	return r


# --- Équipement ---------------------------------------------------------------------------------
func _page_gear() -> void:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	_page.add_child(h)
	var lst := VBoxContainer.new()
	lst.custom_minimum_size = Vector2(330, 0)
	lst.add_theme_constant_override("separation", 3)
	h.add_child(lst)
	for slot in SLOTS:
		var s: String = slot
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		lst.add_child(row)
		var it := _item(s)
		var cell := ItemWidgets.ItemSlot.new(46.0)
		cell.placeholder = String(Items.SLOT_NAMES.get(s, s))
		cell.selected = s == _slot
		if not it.is_empty():
			_with_power(func(): cell.set_item(it))
		cell.pressed.connect(func():
			_slot = s
			_refresh_page())
		row.add_child(cell)
		var nb := Button.new()
		nb.flat = true
		nb.focus_mode = Control.FOCUS_NONE
		nb.alignment = HORIZONTAL_ALIGNMENT_LEFT
		nb.clip_text = true
		nb.custom_minimum_size = Vector2(270, 46)
		nb.text = Items.display_name(it) if not it.is_empty() else "%s — vide" % Items.SLOT_NAMES.get(s, s)
		nb.add_theme_color_override("font_color", Items.color_of(it) if not it.is_empty() else UiTheme.MUTED)
		if s == _slot:
			nb.add_theme_color_override("font_color", UiTheme.GOLD)
		nb.pressed.connect(func():
			_slot = s
			_refresh_page())
		row.add_child(nb)
	var ed := VBoxContainer.new()
	ed.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ed.add_theme_constant_override("separation", 6)
	h.add_child(ed)
	_item_editor(ed)


## Réglages de la pièce choisie et sa carte.
func _item_editor(ed: VBoxContainer) -> void:
	var s := _slot
	_section(ed, "%s" % Items.SLOT_NAMES.get(s, s))
	var gear: Dictionary = build.get("gear", {})
	build["gear"] = gear
	var g: Dictionary = gear.get(s, {})
	var e: Dictionary = GameData.eden_by_id.get(int(g.get("id", 0)), {})
	var r1 := HBoxContainer.new()
	r1.add_theme_constant_override("separation", 6)
	ed.add_child(r1)
	_btn(r1, "Choisir dans le catalogue d'Eden" if e.is_empty() else "Changer : %s" % e.name, func(): _open_picker(s), 0).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if e.is_empty():
		Hud._label(ed, "Aucune pièce : choisis-en une dans le catalogue (tous les objets d'Eden, recherche par nom).", 13, UiTheme.MUTED)
		return
	_btn(r1, "Retirer", func():
		gear.erase(s)
		_refresh_page()
		_refresh_stats(), 100)
	var r2 := HBoxContainer.new()
	r2.add_theme_constant_override("separation", 8)
	ed.add_child(r2)
	Hud._label(r2, "Rareté", 14, UiTheme.TEXT)
	var rar := OptionButton.new()
	rar.focus_mode = Control.FOCUS_NONE
	for rr in Items.RARITIES:
		rar.add_item(String(rr.name))
	rar.select(clampi(int(g.get("rarity", e.rarity)), 0, Items.RARITIES.size() - 1))
	rar.item_selected.connect(func(k):
		g["rarity"] = k
		_changed())
	r2.add_child(rar)
	Hud._label(r2, "   Amélioration", 14, UiTheme.TEXT)
	var up := SpinBox.new()
	up.min_value = 0
	up.max_value = Items.MAX_UPGRADE
	up.prefix = "+"
	up.value = int(g.get("upgrade", 0))
	up.value_changed.connect(func(x):
		g["upgrade"] = int(x)
		_changed())
	r2.add_child(up)
	for n in [4, 6, 8, 10]:
		var nn: int = n
		_btn(r2, "+%d" % n, func():
			g["upgrade"] = nn
			_changed(), 46)
	# paliers
	var rolls: Dictionary = g.get("rolls", {})
	g["rolls"] = rolls
	var pool := RivalBuilds.roll_pool(s)
	Hud._label(ed, "Stat bonus de chaque palier (atteint en gras) :", 14, UiTheme.TEXT)
	var pg := GridContainer.new()
	pg.columns = 4
	pg.add_theme_constant_override("h_separation", 6)
	ed.add_child(pg)
	for m in Items.MILESTONES:
		var mm: int = m
		Hud._label(pg, "  +%d" % mm, 14, UiTheme.GOLD if int(g.get("upgrade", 0)) >= mm else UiTheme.MUTED)
		var ob := OptionButton.new()
		ob.custom_minimum_size = Vector2(200, 0)
		ob.focus_mode = Control.FOCUS_NONE
		for st in pool:
			ob.add_item(_stat_name(st))
		ob.select(maxi(0, pool.find(String(rolls.get(str(mm), pool[0])))))
		ob.disabled = int(g.get("upgrade", 0)) < mm
		ob.item_selected.connect(func(k):
			rolls[str(mm)] = pool[k]
			_changed())
		pg.add_child(ob)
	# gemmes
	var gems: Array = g.get("gems", ["", ""])
	while gems.size() < Craft.MAX_SOCKETS:
		gems.append("")
	g["gems"] = gems
	var gkeys: Array = [""]
	for gt in Craft.GEMS:
		for tier in Craft.GEM_TIERS.size():
			gkeys.append(Craft.gem_key(gt, tier))
	var gr := HBoxContainer.new()
	gr.add_theme_constant_override("separation", 6)
	ed.add_child(gr)
	Hud._label(gr, "Gemmes", 14, UiTheme.TEXT)
	for i in Craft.MAX_SOCKETS:
		var idx := i
		var ob := OptionButton.new()
		ob.focus_mode = Control.FOCUS_NONE
		ob.custom_minimum_size = Vector2(230, 0)
		for k in gkeys:
			ob.add_item("Aucune" if k == "" else Craft.label(k))
			if k != "":
				ob.set_item_icon(ob.item_count - 1, UiTheme.texture(Craft.icon(k)))
		ob.add_theme_constant_override("icon_max_width", 20)
		ob.select(maxi(0, gkeys.find(String(gems[idx]))))
		ob.item_selected.connect(func(k):
			gems[idx] = gkeys[k]
			_changed())
		gr.add_child(ob)
	# enchantement
	var er := HBoxContainer.new()
	er.add_theme_constant_override("separation", 6)
	ed.add_child(er)
	Hud._label(er, "Enchantement", 14, UiTheme.TEXT)
	var en := String(g.get("enchant", ""))
	var ep := en.split(":")
	var types: Array = [""] + Craft.ENCHANTS.keys()
	var et := OptionButton.new()
	et.focus_mode = Control.FOCUS_NONE
	for k in types:
		et.add_item("Aucun" if k == "" else "%s (%s)" % [Craft.ENCHANTS[k].name, _stat_name(String(Craft.ENCHANTS[k].stat))])
	et.select(maxi(0, types.find(ep[1] if ep.size() >= 3 else "")))
	er.add_child(et)
	var el := SpinBox.new()
	el.min_value = 1
	el.max_value = Craft.MAX_SCROLL_LV
	el.prefix = "Lv"
	el.value = int(ep[2]) if ep.size() >= 3 else 1
	er.add_child(el)
	var set_en := func():
		g["enchant"] = Craft.scroll_key(String(types[et.selected]), int(el.value)) if et.selected > 0 else ""
		_changed()
	et.item_selected.connect(func(_k): set_en.call())
	el.value_changed.connect(func(_x): set_en.call())
	# carte de l'objet, en direct
	var it := _item(s)
	var card: Control = _with_power(func(): return ItemWidgets.item_card(it))
	ed.add_child(card)


static func _stat_name(k: String) -> String:
	return String(Items.STAT_NAMES.get(k, Items.EXTRA_STAT_NAMES.get(k, Cards.stat_name(k))))


func _changed() -> void:
	_refresh_page()
	_refresh_stats()


## Catalogue d'Eden pour l'emplacement [param slot] : filtres (type d'armure ou d'arme, rareté,
## stat recherchée, niveaux, sets), tri, et carte complète de l'objet sélectionné.
func _open_picker(slot: String) -> void:
	if _picker:
		_picker.queue_free()
	var box := PanelContainer.new()
	box.add_theme_stylebox_override("panel", UiTheme.flat_box(Color(0.06, 0.05, 0.12, 0.99), UiTheme.GOLD, 2, 10))
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.custom_minimum_size = Vector2(1180, 720)
	box.position = Vector2(-590, -360)
	get_child(0).add_child(box)
	_picker = box
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	box.add_child(v)
	Hud._label(v, "%s : catalogue d'Eden (profil niveau %d)" % [Items.SLOT_NAMES.get(slot, slot), _lv()], 20, UiTheme.GOLD)
	var pool: Array = GameData.eden_items.filter(func(x): return String(x.get("slot", "")) == slot)
	# --- filtres
	var f1 := HBoxContainer.new()
	f1.add_theme_constant_override("separation", 6)
	v.add_child(f1)
	var search := LineEdit.new()
	search.placeholder_text = "Nom…"
	search.custom_minimum_size = Vector2(220, 0)
	f1.add_child(search)
	# type d'armure (plates, cuir, tissu) ou d'arme
	var kinds: Array = [""]
	var kind := OptionButton.new()
	kind.focus_mode = Control.FOCUS_NONE
	if slot == "weapon":
		kind.add_item("Toutes les armes")
		for wt in GameData.weapon_types:
			kinds.append(String(wt))
			kind.add_item(String(GameData.weapon_types[wt].get("name", wt)))
		var own := kinds.find(Items.default_weapon_type(String(build.get("class", ""))))
		kind.select(maxi(0, own))
	else:
		kind.add_item("Tous les types")
		var seen := {}
		for x in pool:
			var a := String(x.get("armor", ""))
			if a != "" and not seen.has(a):
				seen[a] = true
		for a in ["plates", "cuir", "tissu"]:
			if seen.has(a):
				kinds.append(a)
				kind.add_item(String(Archive.ARMOR_CLASS_FR.get(a, a)))
		kind.select(0)
	kind.disabled = kinds.size() <= 1
	f1.add_child(kind)
	var rar := OptionButton.new()
	rar.focus_mode = Control.FOCUS_NONE
	rar.add_item("Toutes raretés")
	for rr in Items.RARITIES:
		rar.add_item(String(rr.name))
	f1.add_child(rar)
	# stat recherchée (celles que portent les pièces de cet emplacement)
	var stat_keys: Array = [""]
	var counts := {}
	for x in pool:
		for k in x.get("r", {}):
			counts[k] = int(counts.get(k, 0)) + 1
	var sk: Array = counts.keys()
	sk.sort_custom(func(a, b): return int(counts[a]) > int(counts[b]))
	var stat := OptionButton.new()
	stat.focus_mode = Control.FOCUS_NONE
	stat.add_item("Toutes les stats")
	for k in sk:
		stat_keys.append(String(k))
		stat.add_item("Avec : %s" % _stat_name(String(k)))
	f1.add_child(stat)
	var f2 := HBoxContainer.new()
	f2.add_theme_constant_override("separation", 6)
	v.add_child(f2)
	Hud._label(f2, "Niveau", 14, UiTheme.TEXT)
	var lmin := SpinBox.new()
	lmin.min_value = 0
	lmin.max_value = 200
	lmin.value = 0
	lmin.prefix = "de"
	f2.add_child(lmin)
	var lmax := SpinBox.new()
	lmax.min_value = 0
	lmax.max_value = 200
	lmax.value = _lv()
	lmax.prefix = "à"
	f2.add_child(lmax)
	var sets := CheckBox.new()
	sets.text = "Pièces de set seulement"
	sets.focus_mode = Control.FOCUS_NONE
	f2.add_child(sets)
	var sort := OptionButton.new()
	sort.focus_mode = Control.FOCUS_NONE
	for t in ["Tri : niveau", "Tri : rareté", "Tri : valeur de la stat choisie", "Tri : nom"]:
		sort.add_item(t)
	f2.add_child(sort)
	var count := Hud._label(f2, "", 13, UiTheme.MUTED)
	# --- liste et carte
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 10)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(body)
	var lst := ItemList.new()
	lst.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lst.fixed_icon_size = Vector2i(32, 32)
	body.add_child(lst)
	var card_box := ScrollContainer.new()
	card_box.custom_minimum_size = Vector2(400, 0)
	card_box.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(card_box)
	var ids: Array = []
	var fill := func():
		lst.clear()
		ids.clear()
		var q := search.text.to_lower()
		var want_kind := String(kinds[kind.selected])
		var want_stat := String(stat_keys[stat.selected])
		var shown: Array = []
		for x in pool:
			if q != "" and not String(x.name).to_lower().contains(q):
				continue
			if int(x.level) < int(lmin.value) or int(x.level) > int(lmax.value):
				continue
			if rar.selected > 0 and int(x.rarity) != rar.selected - 1:
				continue
			if want_kind != "" and String(x.get("wtype" if slot == "weapon" else "armor", "")) != want_kind:
				continue
			if want_stat != "" and not x.get("r", {}).has(want_stat):
				continue
			if sets.button_pressed and not x.has("set"):
				continue
			shown.append(x)
		match sort.selected:
			0:
				shown.sort_custom(func(a, b): return int(a.level) > int(b.level))
			1:
				shown.sort_custom(func(a, b): return int(a.rarity) > int(b.rarity) or (int(a.rarity) == int(b.rarity) and int(a.level) > int(b.level)))
			2:
				shown.sort_custom(func(a, b): return float(a.get("r", {}).get(want_stat, 0.0)) > float(b.get("r", {}).get(want_stat, 0.0)))
			3:
				shown.sort_custom(func(a, b): return String(a.name) < String(b.name))
		for x in shown.slice(0, 800):
			var rc: Dictionary = Items.RARITIES[clampi(int(x.rarity), 0, Items.RARITIES.size() - 1)]
			var tag := ""
			if slot == "weapon":
				tag = "  · " + String(GameData.weapon_type(String(x.get("wtype", ""))).get("name", ""))
			elif String(x.get("armor", "")) != "":
				tag = "  · " + String(x.armor)
			var stats_txt: PackedStringArray = []
			for k in x.get("r", {}):
				stats_txt.append(_stat_name(String(k)))
			var i := lst.add_item("%s  · niv. %d · %s%s%s" % [x.name, int(x.level), rc.name, tag, "  · set" if x.has("set") else ""],
				UiTheme.texture(String(x.get("icon", ""))))
			lst.set_item_custom_fg_color(i, rc.color)
			lst.set_item_tooltip(i, "Stats : " + ", ".join(stats_txt))
			ids.append(int(x.id))
		count.text = "%d objet(s)" % shown.size()
	var show_card := func(i: int):
		for c in card_box.get_children():
			c.queue_free()
		var e: Dictionary = GameData.eden_by_id.get(int(ids[i]), {})
		var it := RivalBuilds.make_item(slot, {"id": int(ids[i]), "rarity": int(e.get("rarity", 0)), "upgrade": 0}, _lv())
		var card: Control = _with_power(func(): return ItemWidgets.item_card(it))
		card_box.add_child(card)
	fill.call()
	for w in [kind, rar, stat, sort]:
		w.item_selected.connect(func(_k): fill.call())
	search.text_changed.connect(func(_q): fill.call())
	lmin.value_changed.connect(func(_x): fill.call())
	lmax.value_changed.connect(func(_x): fill.call())
	sets.toggled.connect(func(_on): fill.call())
	lst.item_selected.connect(func(i): show_card.call(i))
	var choose := func(i: int):
		var e: Dictionary = GameData.eden_by_id.get(int(ids[i]), {})
		var gear: Dictionary = build.get("gear", {})
		var old: Dictionary = gear.get(slot, {})
		gear[slot] = {"id": int(ids[i]), "rarity": int(e.get("rarity", 0)), "upgrade": int(old.get("upgrade", 0)),
			"rolls": old.get("rolls", {}), "gems": old.get("gems", ["", ""]), "enchant": old.get("enchant", "")}
		build["gear"] = gear
		box.queue_free()
		_picker = null
		_changed()
	lst.item_activated.connect(func(i): choose.call(i))
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 8)
	v.add_child(bar)
	Hud._label(bar, "Clic : voir la carte · double-clic ou Choisir : équiper", 13, UiTheme.MUTED)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(sp)
	_btn(bar, "Choisir", func():
		var sel := lst.get_selected_items()
		if not sel.is_empty():
			choose.call(sel[0]), 140)
	_btn(bar, "Annuler", func():
		box.queue_free()
		_picker = null, 120)
	search.grab_focus()


# --- Sorts ----------------------------------------------------------------------------------------
func _page_spells() -> void:
	var cid := String(build.get("class", "warrior"))
	var all: Array = GameData.class_data(cid).get("skills", [])
	_section(_page, "12 sorts : 4 cases de la barre × sort principal et ses 2 enchaînements (fiche au survol)")
	var grid: Array = build.spells
	var g := GridContainer.new()
	g.columns = 5
	g.add_theme_constant_override("h_separation", 6)
	g.add_theme_constant_override("v_separation", 6)
	_page.add_child(g)
	g.add_child(Control.new())
	for c in 4:
		var h := Hud._label(g, "Case %d" % (c + 1), 15, UiTheme.GOLD)
		h.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var kit := Duel.kit_from_grid(cid, grid)
	for r in 3:
		Hud._label(g, String(["Principal", "Enchaîn. 1", "Enchaîn. 2"][r]), 14, UiTheme.TEXT)
		for c in 4:
			var idx := c * 3 + r
			var chosen := int(grid[idx])
			# ce qui sera joué : le choix, sinon le sort de la classe à cette place
			var shown := chosen
			if shown == 0:
				if r == 0 and c < kit.skills.size():
					shown = int(kit.skills[c].id)
				elif r > 0 and kit.chains.get(c, []).size() >= r:
					shown = int(kit.chains[c][r - 1].id)
			var sk: Dictionary = {}
			for s in all:
				if int(s.id) == shown:
					sk = s
			var b := ItemWidgets.TipButton.new()
			b.focus_mode = Control.FOCUS_NONE
			b.custom_minimum_size = Vector2(0, 54)
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			b.alignment = HORIZONTAL_ALIGNMENT_LEFT
			b.clip_text = true
			b.expand_icon = false
			b.add_theme_constant_override("icon_max_width", 40)
			b.icon = UiTheme.texture(String(sk.get("icon", ""))) if not sk.is_empty() else null
			b.text = (" " + String(sk.get("name", "—"))) + ("" if chosen != 0 else "  (auto)")
			b.tooltip_text = String(sk.get("name", ""))
			b.tip = SpellInfo.skill_bbcode(sk, 1) if not sk.is_empty() else ""
			b.pressed.connect(func(): _spell_menu(b, idx, all))
			g.add_child(b)
	Hud._label(_page, "Clic : choisir le sort. « auto » : le sort de la classe à cette place. Les renforcements et soins ne servent qu'au héros (ou à un adversaire piloté par un cerveau d'IA) ; l'IA scriptée lance ses sorts d'attaque.", 13, UiTheme.MUTED).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


func _spell_menu(anchor: Control, idx: int, all: Array) -> void:
	var pm := PopupMenu.new()
	pm.add_item("Auto (sort de la classe à cette place)", 0)
	for j in all.size():
		pm.add_icon_item(UiTheme.texture(String(all[j].get("icon", ""))), "%s%s" % [all[j].name, "  (renforcement)" if String(all[j].get("kind", "")) in ["buff", "heal"] else ""], j + 1)
	pm.add_theme_constant_override("icon_max_width", 26)
	pm.id_pressed.connect(func(id):
		build.spells[idx] = int(all[id - 1].id) if id > 0 else 0
		_changed())
	add_child(pm)
	pm.popup_hide.connect(pm.queue_free)
	var r := anchor.get_global_rect()
	pm.position = Vector2i(int(r.position.x), int(r.end.y))
	pm.popup()


# --- Certificats ----------------------------------------------------------------------------------
var _cert_q := ""
var _cert_stat := ""
var _cert_cls := ""
var _cert_only := false


func _page_certs() -> void:
	var certs: Array = build.get("certs", [])
	build["certs"] = certs
	var all := RivalBuilds.all_certificates()
	_section(_page, "Certificats (%d / %d) · fiche au survol" % [certs.size(), RivalBuilds.MAX_CERTS])
	var syn := CertBoard.synergies(RivalBuilds.cert_board(build)).map(func(x): return String(x.name))
	Hud._label(_page, ("Plateau : " + ", ".join(syn)) if not syn.is_empty() else "Plateau : aucun bonus de placement (relie des certificats de même couleur).", 13, UiTheme.BUFF if not syn.is_empty() else UiTheme.MUTED)
	# filtres : nom, stat, classe, choisis seulement
	var f := HBoxContainer.new()
	f.add_theme_constant_override("separation", 6)
	_page.add_child(f)
	var q := LineEdit.new()
	q.placeholder_text = "Nom…"
	q.text = _cert_q
	q.custom_minimum_size = Vector2(200, 0)
	f.add_child(q)
	var stats: Array = [""]
	for c in all:
		for k in c.stat:
			if not k in stats:
				stats.append(String(k))
	var so := OptionButton.new()
	so.focus_mode = Control.FOCUS_NONE
	so.add_item("Toutes les stats")
	for k in stats.slice(1):
		so.add_item("Avec : %s" % _stat_name(String(k)))
	so.select(maxi(0, stats.find(_cert_stat)))
	f.add_child(so)
	var classes: Array = [""]
	var co := OptionButton.new()
	co.focus_mode = Control.FOCUS_NONE
	co.add_item("Toutes les classes")
	for c in all:
		if not String(c.cls_id) in classes:
			classes.append(String(c.cls_id))
			co.add_item(String(c.cls))
	co.select(maxi(0, classes.find(_cert_cls)))
	f.add_child(co)
	var only := CheckBox.new()
	only.text = "Choisis seulement"
	only.focus_mode = Control.FOCUS_NONE
	only.button_pressed = _cert_only
	f.add_child(only)
	_btn(f, "Tout retirer", func():
		certs.clear()
		_changed(), 120)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	_page.add_child(grid)
	var fill := func():
		for c in grid.get_children():
			c.queue_free()
		var n := 0
		for c in all:
			var key := String(c.key)
			var on := key in certs
			if _cert_q != "" and not (String(c.name) + " " + String(c.desc)).to_lower().contains(_cert_q.to_lower()):
				continue
			if _cert_stat != "" and not (c.stat as Dictionary).has(_cert_stat):
				continue
			if _cert_cls != "" and String(c.cls_id) != _cert_cls:
				continue
			if _cert_only and not on:
				continue
			n += 1
			var b := ItemWidgets.TipButton.new()
			b.toggle_mode = true
			b.button_pressed = on
			b.focus_mode = Control.FOCUS_NONE
			b.custom_minimum_size = Vector2(330, 52)
			b.alignment = HORIZONTAL_ALIGNMENT_LEFT
			b.clip_text = true
			b.expand_icon = false
			b.add_theme_constant_override("icon_max_width", 40)
			b.icon = UiTheme.texture(String(c.icon))
			var st: PackedStringArray = []
			for k in c.stat:
				st.append(Items.stat_text(String(k), c.stat[k]))
			b.text = " %s%s\n %s" % ["✔ " if on else "", c.name, (", ".join(st) if not st.is_empty() else String(c.cls))]
			if on:
				b.add_theme_stylebox_override("normal", UiTheme.flat_box(Color(0.25, 0.18, 0.06, 0.95), UiTheme.GOLD, 2, 8))
			b.tip = "[b]%s[/b] · %s\n%s" % [c.name, c.cls, c.desc]
			b.tooltip_text = String(c.name)
			b.pressed.connect(func():
				if key in certs:
					certs.erase(key)
				elif certs.size() >= RivalBuilds.MAX_CERTS:
					_msg.text = "%d certificats au plus." % RivalBuilds.MAX_CERTS
				else:
					certs.append(key)
				_changed())
			grid.add_child(b)
		if n == 0:
			Hud._label(grid, "Aucun certificat avec ces filtres.", 13, UiTheme.MUTED)
	fill.call()
	q.text_changed.connect(func(t):
		_cert_q = t
		fill.call())
	so.item_selected.connect(func(k):
		_cert_stat = String(stats[k])
		fill.call())
	co.item_selected.connect(func(k):
		_cert_cls = String(classes[k])
		fill.call())
	only.toggled.connect(func(on):
		_cert_only = on
		fill.call())


# --- Maîtrise --------------------------------------------------------------------------------------
func _page_talents() -> void:
	var cid := String(build.get("class", "warrior"))
	var tal: Dictionary = build.get("talents", {})
	build["talents"] = tal
	var data: Dictionary = GameData.talents.get(cid, {})
	var tree: Dictionary = data.get("talents", {})
	var pts := RivalBuilds.talent_points(build)
	_section(_page, "Maîtrise : %d point(s) attribué(s) · il faudrait la maîtrise niveau %d (2 points par niveau) · fiche au survol" % [pts, ceili(pts / 2.0)])
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 6)
	_page.add_child(bar)
	_btn(bar, "Tout au maximum", func():
		for row in data.get("rows", []):
			for c in row:
				if c != null:
					tal[str(int(c.id))] = int(c.max)
		_changed(), 180)
	_btn(bar, "Tout retirer", func():
		tal.clear()
		_changed(), 140)
	for ri in (data.get("rows", []) as Array).size():
		var row: Array = data.rows[ri]
		_section(_page, "Branche %d" % (ri + 1))
		var flow := HFlowContainer.new()
		flow.add_theme_constant_override("h_separation", 8)
		flow.add_theme_constant_override("v_separation", 6)
		_page.add_child(flow)
		for c in row:
			if c == null:
				continue
			var id := str(int(c.id))
			var t: Dictionary = tree.get(id, {})
			var cell := HBoxContainer.new()
			cell.add_theme_constant_override("separation", 4)
			cell.custom_minimum_size = Vector2(300, 0)
			flow.add_child(cell)
			var b := ItemWidgets.TipButton.new()
			b.focus_mode = Control.FOCUS_NONE
			b.custom_minimum_size = Vector2(200, 44)
			b.alignment = HORIZONTAL_ALIGNMENT_LEFT
			b.clip_text = true
			b.expand_icon = false
			b.add_theme_constant_override("icon_max_width", 34)
			b.icon = UiTheme.texture(String(t.get("icon", "")))
			b.text = " " + String(t.get("name", id))
			b.tooltip_text = String(t.get("name", ""))
			var req := ""
			if int(c.get("req", 0)) > 0:
				req = "\n[color=#c8c8d4]Demande %s niveau %d[/color]" % [tree.get(str(int(c.req)), {}).get("name", "?"), int(c.req_pts)]
			if int(c.get("spent", 0)) > 0:
				req += "\n[color=#c8c8d4]Demande %d points dans l'arbre[/color]" % int(c.spent)
			b.tip = "[b]%s[/b] (%d niveaux)\n%s%s" % [t.get("name", id), int(c.max), t.get("desc", ""), req]
			cell.add_child(b)
			var sp := SpinBox.new()
			sp.min_value = 0
			sp.max_value = int(c.max)
			sp.value = int(tal.get(id, 0))
			sp.custom_minimum_size = Vector2(80, 0)
			sp.value_changed.connect(func(x):
				if int(x) <= 0:
					tal.erase(id)
				else:
					tal[id] = int(x)
				_refresh_stats())
			cell.add_child(sp)
	if (data.get("rows", []) as Array).is_empty():
		Hud._label(_page, "Pas d'arbre de maîtrise pour cette classe.", 13, UiTheme.MUTED)


# --- Apparence ------------------------------------------------------------------------------------
func _page_look() -> void:
	if not build.has("look"):
		build["look"] = {}
	var look: Dictionary = build.look
	_section(_page, "Apparence (aperçu à gauche) : pièces, teintures, aura")
	for spec in LOOK:
		var cat: String = spec[0]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		_page.add_child(row)
		var l := Hud._label(row, String(spec[1]), 15, UiTheme.TEXT)
		l.custom_minimum_size = Vector2(80, 0)
		var ob := OptionButton.new()
		ob.focus_mode = Control.FOCUS_NONE
		ob.custom_minimum_size = Vector2(420, 0)
		ob.add_item("Celle de la classe" if cat == "body" else "Aucun")
		var paths: Array = [""]
		var cos: Array = GameData.cosmetics.filter(func(x): return String(x.get("cat", "")) == cat and ResourceLoader.exists(String(x.get("outfit", ""))))
		cos.sort_custom(func(a, b): return String(a.name) < String(b.name))
		for x in cos:
			ob.add_item(String(x.name))
			if String(x.get("icon", "")) != "":
				ob.set_item_icon(ob.item_count - 1, UiTheme.texture(String(x.icon)))
			paths.append(String(x.outfit))
		ob.add_theme_constant_override("icon_max_width", 24)
		ob.select(maxi(0, paths.find(String(build.look.get(cat, "")))))
		ob.item_selected.connect(func(k):
			if k == 0:
				build.look.erase(cat)
			else:
				build.look[cat] = paths[k]
			_changed())
		row.add_child(ob)
		_dye_row(cat, look)
	_weapon_skin_row(look)
	_aura_section(look)

## Apparence de l'arme : modèle porté (vide : celui de l'arme du profil).
func _weapon_skin_row(look: Dictionary) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	_page.add_child(row)
	var l := Hud._label(row, "Arme", 15, UiTheme.TEXT)
	l.custom_minimum_size = Vector2(80, 0)
	var cid := String(build.get("class", "warrior"))
	var wt := Items.default_weapon_type(cid)
	var code := String(look.get("weapon_skin", ""))
	var cur: Dictionary = {}
	for x in RivalBuilds.weapon_skins(wt):
		if String(x.code) == code:
			cur = x
	var b := MenuWidgets.glass_button(("  " + String(cur.get("name", code))) if code != "" else "  Celle de l'arme du profil", 15, Vector2(420, 40))
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.expand_icon = false
	b.add_theme_constant_override("icon_max_width", 30)
	if not cur.is_empty():
		b.icon = UiTheme.texture(String(cur.get("icon", "")))
	b.pressed.connect(func(): _open_skin_picker(wt, look))
	row.add_child(b)
	if code != "":
		_btn(row, "Origine", func():
			look.erase("weapon_skin")
			_changed(), 90)


## Choix du modèle d'arme : modèles de base, armes d'Eden du type, apparences d'armes d'Eden.
func _open_skin_picker(wt: String, look: Dictionary) -> void:
	if _picker:
		_picker.queue_free()
	var box := PanelContainer.new()
	box.add_theme_stylebox_override("panel", UiTheme.flat_box(Color(0.06, 0.05, 0.12, 0.99), UiTheme.GOLD, 2, 10))
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.custom_minimum_size = Vector2(760, 660)
	box.position = Vector2(-380, -330)
	get_child(0).add_child(box)
	_picker = box
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	box.add_child(v)
	Hud._label(v, "Apparence de l'arme (%s) : l'aperçu à gauche suit la sélection" % GameData.weapon_type(wt).get("name", wt), 20, UiTheme.GOLD)
	var f := HBoxContainer.new()
	f.add_theme_constant_override("separation", 6)
	v.add_child(f)
	var search := LineEdit.new()
	search.placeholder_text = "Nom…"
	search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	f.add_child(search)
	var froms := ["", "base", "eden", "skin"]
	var src := OptionButton.new()
	src.focus_mode = Control.FOCUS_NONE
	for t in ["Tout", "Modèles de base", "Armes d'Eden de ce type", "Apparences d'armes d'Eden (archive)"]:
		src.add_item(t)
	f.add_child(src)
	var lst := ItemList.new()
	lst.size_flags_vertical = Control.SIZE_EXPAND_FILL
	lst.fixed_icon_size = Vector2i(32, 32)
	v.add_child(lst)
	var all := RivalBuilds.weapon_skins(wt)
	var codes: Array = []
	var fill := func():
		lst.clear()
		codes.clear()
		var q := search.text.to_lower()
		for x in all:
			if src.selected > 0 and String(x.from) != froms[src.selected]:
				continue
			if q != "" and not String(x.name).to_lower().contains(q):
				continue
			lst.add_item("%s%s" % [x.name, ("  · niv. %d" % int(x.level)) if x.has("level") else ""], UiTheme.texture(String(x.icon)))
			codes.append(String(x.code))
	fill.call()
	search.text_changed.connect(func(_q): fill.call())
	src.item_selected.connect(func(_k): fill.call())
	var before := String(look.get("weapon_skin", ""))
	lst.item_selected.connect(func(i):
		look["weapon_skin"] = codes[i]
		_refresh_stats())
	var close := func(keep: bool):
		if not keep:
			if before == "":
				look.erase("weapon_skin")
			else:
				look["weapon_skin"] = before
		box.queue_free()
		_picker = null
		_changed()
	lst.item_activated.connect(func(_i): close.call(true))
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 8)
	v.add_child(bar)
	Hud._label(bar, "Clic : essayer · double-clic ou Choisir : garder", 13, UiTheme.MUTED)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(sp)
	_btn(bar, "Choisir", func(): close.call(true), 140)
	_btn(bar, "Annuler", func(): close.call(false), 120)
	search.grab_focus()


## Teinture de la pièce [param cat] : coloris d'Eden de la pièce, ou 3 couleurs libres.
func _dye_row(cat: String, look: Dictionary) -> void:
	var path := String(look.get(cat, ""))
	if cat == "body" and path == "":
		var parts: Array = GameData.class_data(String(build.get("class", ""))).get("parts", [])
		path = String(parts[0]) if not parts.is_empty() else ""
	if path == "" or not EdenModel.can_dye(path):
		return
	var dye: Dictionary = look.get("dye", {})
	look["dye"] = dye
	var cos := {}
	for c in GameData.cosmetics:
		if String(c.get("outfit", "")) == path:
			cos = c
	var variants: Array = cos.get("variants", []) if cos.get("variants", []) is Array else []
	var cur: Array = dye.get(cat, [])
	var shown: Array = cur if cur.size() >= 3 else (variants[0].colors if not variants.is_empty() else [[200, 200, 200], [150, 150, 150], [80, 80, 80]])
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	_page.add_child(row)
	var l := Hud._label(row, "   couleurs", 13, UiTheme.MUTED)
	l.custom_minimum_size = Vector2(80, 0)
	for v in variants.slice(0, 8):
		var cols: Array = v.colors
		var sw := Button.new()
		sw.custom_minimum_size = Vector2(44, 28)
		sw.focus_mode = Control.FOCUS_NONE
		sw.tooltip_text = String(v.get("name", "")) if String(v.get("name", "")) != "" else "Coloris d'Eden"
		sw.add_theme_stylebox_override("normal", UiTheme.flat_box(Color8(int(cols[0][0]), int(cols[0][1]), int(cols[0][2])),
			UiTheme.GOLD if str(cols) == str(shown) else UiTheme.GOLD_DIM, 2, 6))
		sw.pressed.connect(func():
			dye[cat] = cols.duplicate(true)
			_changed())
		row.add_child(sw)
	var pickers: Array = []
	for i in 3:
		var pb := ColorPickerButton.new()
		pb.custom_minimum_size = Vector2(56, 28)
		pb.focus_mode = Control.FOCUS_NONE
		pb.edit_alpha = false
		pb.tooltip_text = DYE_NAMES[i]
		var c: Array = shown[i]
		pb.color = Color8(int(c[0]), int(c[1]), int(c[2]))
		row.add_child(pb)
		pickers.append(pb)
	for pb in pickers:
		pb.color_changed.connect(func(_c):
			dye[cat] = pickers.map(func(p): return [p.color.r8, p.color.g8, p.color.b8])
			_refresh_stats())
	_btn(row, "Origine", func():
		dye.erase(cat)
		_changed(), 90)


## Aura (toutes celles d'Eden) et sa teinture.
func _aura_section(look: Dictionary) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	_page.add_child(row)
	var l := Hud._label(row, "Aura", 15, UiTheme.TEXT)
	l.custom_minimum_size = Vector2(80, 0)
	var ob := OptionButton.new()
	ob.focus_mode = Control.FOCUS_NONE
	ob.custom_minimum_size = Vector2(420, 0)
	ob.add_item("Aucune")
	var ids: Array = [0]
	var auras: Array = GameData.auras.duplicate()
	auras.sort_custom(func(a, b): return String(a.name) < String(b.name))
	for x in auras:
		ob.add_item("%s (%s)" % [x.name, {"star": "pierre étoilée", "luna": "pierre de lune"}.get(String(x.aura.kind), "autre")])
		ob.set_item_icon(ob.item_count - 1, UiTheme.texture(String(x.get("icon", ""))))
		ids.append(int(x.id))
	ob.add_theme_constant_override("icon_max_width", 24)
	ob.select(maxi(0, ids.find(int(look.get("aura", 0)))))
	ob.item_selected.connect(func(k):
		if k == 0:
			look.erase("aura")
		else:
			look["aura"] = ids[k]
		_changed())
	row.add_child(ob)
	if int(look.get("aura", 0)) <= 0:
		return
	var tr := HBoxContainer.new()
	tr.add_theme_constant_override("separation", 6)
	_page.add_child(tr)
	var tl := Hud._label(tr, "   teinture", 13, UiTheme.MUTED)
	tl.custom_minimum_size = Vector2(80, 0)
	var cur := RivalBuilds.aura_tint(look)
	for preset in AURA_PRESETS:
		var rgb: Array = preset
		var col := Color8(rgb[0], rgb[1], rgb[2])
		var sw := Button.new()
		sw.custom_minimum_size = Vector2(30, 28)
		sw.focus_mode = Control.FOCUS_NONE
		sw.add_theme_stylebox_override("normal", UiTheme.flat_box(col, UiTheme.GOLD if cur.a > 0.0 and cur.is_equal_approx(col) else UiTheme.GOLD_DIM, 2, 6))
		sw.pressed.connect(func():
			look["aura_tint"] = rgb.duplicate()
			_changed())
		tr.add_child(sw)
	var pb := ColorPickerButton.new()
	pb.custom_minimum_size = Vector2(70, 28)
	pb.focus_mode = Control.FOCUS_NONE
	pb.edit_alpha = false
	pb.color = cur if cur.a > 0.0 else Color(1, 1, 1)
	pb.tooltip_text = "Couleur libre de l'aura"
	pb.color_changed.connect(func(c):
		look["aura_tint"] = [c.r8, c.g8, c.b8]
		_refresh_stats())
	tr.add_child(pb)
	_btn(tr, "Origine", func():
		look.erase("aura_tint")
		_changed(), 90)


# --- Adversaire -----------------------------------------------------------------------------------
func _page_duel() -> void:
	_section(_page, "En adversaire de duel")
	Hud._label(_page, "Ces réglages ne servent que quand le profil est un adversaire (Duel > Éditeur d'adversaire). Le duel se joue au niveau de ton équipement ; l'IA (scriptée ou cerveau) se choisit dans le menu Duel.", 13, UiTheme.MUTED).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	for spec in [["hp_mult", "PV ×"], ["atk_mult", "Dégâts ×"]]:
		var k: String = spec[0]
		var row := HBoxContainer.new()
		_page.add_child(row)
		var l := Hud._label(row, String(spec[1]), 15, UiTheme.TEXT)
		l.custom_minimum_size = Vector2(100, 0)
		var s := SpinBox.new()
		s.min_value = 0.1
		s.max_value = 50.0
		s.step = 0.1
		s.value = float(build.get(k, 1.0))
		s.value_changed.connect(func(x):
			build[k] = x
			_refresh_stats())
		row.add_child(s)


# --- stats et aperçu -------------------------------------------------------------------------------
func _refresh_stats() -> void:
	var cid := String(build.get("class", "warrior"))
	var lv := _lv()
	var r := ClassRival.new()
	r.setup(cid, lv, 2)
	r.apply_build(build, lv)
	var st := RivalBuilds.stats(build, lv)
	var sets: PackedStringArray = []
	for sb in Items.active_set_bonuses(RivalBuilds.items(build, lv)):
		sets.append("%s (%d)" % [Items.set_def(sb.set).get("name", ""), int(sb.pieces)])
	var lines: PackedStringArray = ["[b]%s · niveau %d[/b] · maîtrise %d pts" % [GameData.class_data(cid).get("name_fr", cid), lv, RivalBuilds.talent_points(build)],
		"PV [b]%s[/b] · attaque [b]%d[/b]" % [Hud._big_number(r.max_hp), roundi(r.atk / (float(r.cfg.atk) / 0.65))],
		# en duel, la défense se compare à celle de l'adversaire (PvpCaps.taken) : ici à une défense
		# moyenne pour ce niveau
		"Défense [b]%d[/b] (en duel : %d %% des dégâts subis face à une défense moyenne)" % [roundi(r.defense),
			roundi(100.0 * PvpCaps.taken(r.defense, 100.0 * pow(1.095, maxi(lv - 10, 0))))]]
	for k in ["crit", "crit_dmg", "atk_speed", "cdr", "dmg_pct", "hp_pct", "move_speed"]:
		var v := float(st.get(k, 0.0))
		if v != 0.0:
			lines.append(Items.stat_text(k, v) if v > 0.0 else "-" + Items.stat_text(k, -v).trim_prefix("+"))
	if not sets.is_empty():
		lines.append("Sets : " + ", ".join(sets))
	_stats.text = "\n".join(lines)
	var look: Dictionary = build.get("look", {})
	var extra: Array = [String(look.get("head", "")), String(look.get("back", ""))]
	_preview.show_look(cid, r.weapon_code, String(look.get("body", "")), extra, RivalBuilds.look_dyes(look, GameData.class_data(cid)),
		RivalBuilds.aura_ids(look), RivalBuilds.aura_tint(look))
	r.free()
