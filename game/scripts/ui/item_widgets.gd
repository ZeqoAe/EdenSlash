class_name ItemWidgets
extends RefCounted
## Éléments d'interface des objets : case d'objet (rareté, +N, set, gemmes,
## glisser-déposer), grille filtrable à sélection multiple, bourse, textes de
## comparaison et de coût.

const SORTS := ["Rareté", "Niveau", "Emplacement", "Valeur"]
## Différences de la comparaison affichées sur la carte courte (les autres derrière Maj).
const DIFF_ROWS := 5


# --- textes --------------------------------------------------------------------------------
## Comparaison avec la pièce portée au même emplacement ("" si identique ou rien de porté). Lot GX-3 : sur la carte
## courte, le verdict et les écarts ▲ / ▼ sont déjà sur les lignes de la carte (Items.describe) : il ne reste que le nom de
## la pièce portée ; la carte complète (Maj) ajoute le verdict avec l'écart au profil et une ligne par différence.
static func compare_text(item: Dictionary, worn, detailed := true) -> String:
	if worn == null or not (worn is Dictionary) or worn.is_empty() or is_same(worn, item) or String(worn.get("uid", "")) == String(item.get("uid", "-")):
		return ""
	var slot := String(item.get("slot", ""))
	var head := "[color=#8a86a0]Porté : %s[/color]" % Items.display_name(worn)
	if not detailed:
		return "\n\n%s" % head
	if slot in Items.SLOTS:
		head += "\n" + Items.verdict_line(item, worn, true)
	return "\n\n%s\n%s\n%s" % [Items.SEPARATOR, head, diff_text(
		Items.stats(worn), Items.stats(item), slot, detailed,
		Items._level_k(Items.power_level(item)))]


## Différences de statistiques, une ligne chacune, les plus lourdes d'abord (5 au plus si [param detailed] est faux).
static func diff_text(before: Dictionary, after: Dictionary, slot := "", detailed := true, lk := 1.0) -> String:
	var keys := before.keys()
	for k in after:
		if not k in keys:
			keys.append(k)
	var parts: Array = []
	for k in keys:
		var d := float(after.get(k, 0.0)) - float(before.get(k, 0.0))
		var pct: bool = k in Items.PERCENT_STATS
		var shown := roundi(d * 100.0) if pct else roundi(d)
		if shown == 0:
			continue
		parts.append({"w": Items.stat_weight(slot if slot != "" else "weapon", String(k), d, lk),
			"t": "[color=%s]%s %s%d%s %s[/color]" % ["#7fe08a" if d > 0 else "#ff7a7a", "▲" if d > 0 else "▼", "+" if d > 0 else "",
				shown, " %" if pct else "", Items.STAT_NAMES.get(k, Items.EXTRA_STAT_NAMES.get(k, k))]})
	if parts.is_empty():
		return "[color=#c8c8d4]identique[/color]"
	parts.sort_custom(func(a, b): return float(a.w) > float(b.w))
	var lines: PackedStringArray = []
	for i in parts.size():
		if detailed or i < DIFF_ROWS:
			lines.append(String(parts[i].t))
	var more := parts.size() - lines.size()
	if more > 0:
		lines.append("[color=#8a86a0]+ %d autre%s différence%s[/color]" % [more, "s" if more > 1 else "", "s" if more > 1 else ""])
	return "\n".join(lines)


static func icon_bb(k: String) -> String:
	var path := Items.material_icon(k)
	return "[img=20x20]%s[/img] " % path if path != "" else ""


## Matériaux en texte : court pour les boutons, avec icônes d'Eden pour le détail.
static func materials_text(m: Dictionary, short := false) -> String:
	const SHORT := {"crystal": "crist.", "gold": "or"}
	var parts: PackedStringArray = []
	for k in m:
		if short:
			parts.append("%d %s" % [int(m[k]), "clé" if k == "keys" and int(m[k]) < 2 else ("clés" if k == "keys" else SHORT.get(k, k))])
		else:
			parts.append("%s%d %s" % [icon_bb(k), int(m[k]), res_name(k)])
	return (" " if short else ", ").join(parts)


static func res_name(k: String) -> String:
	return {"gold": "or", "keys": "clés"}.get(k, String(Items.MATERIALS.get(k, k)).to_lower())


## Coût avec ce qui manque en rouge.
static func cost_text(cost: Dictionary) -> String:
	var parts: PackedStringArray = []
	for k in cost:
		var ok := Profile.amount(k) >= int(cost[k])
		parts.append("%s[color=%s]%d %s[/color]" % [icon_bb(k), "#ffffff" if ok else "#ff7a7a", int(cost[k]), res_name(k)])
	return ", ".join(parts)


## Titre de section doré avec un filet.
static func section(parent: Control, text: String, size := 18) -> Label:
	var l := Label.new()
	l.text = text
	UiTheme.title(l, size)
	parent.add_child(l)
	return l


static func rich(parent: Control, size := 15) -> RichTextLabel:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.scroll_active = true
	r.add_theme_font_size_override("normal_font_size", size)
	r.add_theme_font_size_override("bold_font_size", size + 1)
	r.size_flags_vertical = Control.SIZE_EXPAND_FILL
	r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(r)
	return r


## Panneau orné qui remplit son parent, avec une VBox dedans.
static func panel(parent: Control, min_width := 0.0, expand := false) -> VBoxContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UiTheme.panel_box(18, 14))
	p.custom_minimum_size = Vector2(min_width, 0)
	p.size_flags_vertical = Control.SIZE_EXPAND_FILL
	if expand:
		p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	p.add_child(v)
	return v


static func action_button(parent: Control, text: String, cb: Callable, min_w := 0.0, accent := false) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(min_w, 44)
	b.add_theme_font_size_override("font_size", 17)
	if accent:
		UiTheme.style_button(b, "lagon", 17)  # action mise en avant : autocollant lagon (bible § 6 : action douce ; le soleil reste au primaire de l'écran)
	b.pressed.connect(cb)
	parent.add_child(b)
	return b


## Carte d'objet (infobulle) : la carte courte (statistique principale en gros, cinq lignes, passif, gemmes,
## panoplie) et la comparaison avec la pièce portée ; Maj la déplie en carte complète, [param extra] en bas.
## [param mode] : -1 = suit la touche Maj, 0 = toujours courte, 1 = toujours complète.
static func item_card(item: Dictionary, extra := "", mode := -1) -> Control:
	return ItemCard.new(item, extra, mode)


## Texte complet de la carte d'[param item] (BBCode) : carte, comparaison avec la pièce portée au même emplacement
## (une arme d'un autre type que la classe : avec l'arme secondaire), [param extra].
static func card_text(item: Dictionary, extra := "", detailed := false) -> String:
	var worn = worn_for(item)
	var hint := "" if detailed else "\n\n[color=#6c6882]Maj : détails[/color]"
	# lot GX-3 : la carte compare dès qu'elle parle d'une pièce d'équipement ({} : emplacement libre)
	var ctx = (worn if worn is Dictionary else {}) if String(item.get("slot", "")) in Items.SLOTS else null
	return Items.describe(item, detailed, ctx) + compare_text(item, worn, detailed) + extra + hint


## Pièce portée là où irait [param item] (une arme d'un autre type que la classe : l'arme secondaire), null sinon.
static func worn_for(item: Dictionary):
	var slot := String(item.get("slot", ""))
	var worn = Profile.equipped.get(slot, null)
	if slot == "weapon" and not Profile.can_be_main(item) and not (Survivor.active or Royale.active):
		worn = Profile.equipped.get("offhand", null)
	return worn


## Carte d'objet v2 (lot GX-3, DA v2) : autocollant d'encre (contour, ombre dure) avec un bandeau de la couleur de la
## rareté ; la pièce portée au même emplacement, réduite, est posée à côté (mêmes lignes, alignées en haut).
class ItemCard extends HBoxContainer:
	var item: Dictionary
	var extra := ""
	var auto := true
	var detailed := false
	var _label: RichTextLabel
	var _worn_card: Control

	func _init(it: Dictionary, ex := "", mode := -1) -> void:
		item = it
		extra = ex
		auto = mode < 0
		alignment = BoxContainer.ALIGNMENT_BEGIN
		add_theme_constant_override("separation", 8)
		_label = ItemWidgets._card_panel(self, it, 400.0, "")
		var worn = ItemWidgets.worn_for(it)
		if worn is Dictionary and not worn.is_empty() and not is_same(worn, it) and String(worn.get("uid", "")) != String(it.get("uid", "-")) \
				and String(it.get("slot", "")) in Items.SLOTS:
			var wl := ItemWidgets._card_panel(self, worn, 300.0, "Portée")
			wl.text = UiTheme.paper_bbcode(Items.describe(worn, false))  # carte papier (UIK1)
			_worn_card = wl.get_parent().get_parent()
		detailed = mode == 1 or (auto and Input.is_key_pressed(KEY_SHIFT))
		_refresh()

	func _ready() -> void:
		set_process(auto)  # le moteur active _process à l'entrée dans l'arbre : seulement si Maj commande la carte

	func _refresh() -> void:
		_label.text = UiTheme.paper_bbcode(ItemWidgets.card_text(item, extra, detailed))  # couleurs foncées sur le papier (UIK1)
		reset_size()

	func _process(_delta: float) -> void:
		var d := Input.is_key_pressed(KEY_SHIFT)
		if d != detailed:
			detailed = d
			_refresh()


## Panneau d'une carte d'objet (DA v2) : autocollant d'encre, bandeau de rareté en haut ([param caption] dessus : « Portée »),
## puis le texte ; renvoie le RichTextLabel (texte à remplir).
static func _card_panel(parent: Control, it: Dictionary, width: float, caption: String) -> RichTextLabel:
	var p := PanelContainer.new()
	var sb := UiTheme.sticker("papier", {"shadow": 4, "radius": 14, "gloss": false, "cel_top": 0.0, "cel_bottom": 0.0, "pad": Vector2(14, 10)})  # papier (UIK1)
	p.add_theme_stylebox_override("panel", sb)
	p.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	parent.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	p.add_child(v)
	var band := PanelContainer.new()
	var bs := UiTheme.flat_box(Items.color_of(it), UiTheme.color("encre.900", UiTheme.INK), 2, 6, false)
	bs.content_margin_left = 8
	bs.content_margin_right = 8
	bs.content_margin_top = 0
	bs.content_margin_bottom = 0
	band.add_theme_stylebox_override("panel", bs)
	band.custom_minimum_size = Vector2(0, 8 if caption == "" else 22)
	v.add_child(band)
	if caption != "":
		var cl := Label.new()
		cl.text = caption
		cl.add_theme_font_override("font", UiTheme.bold_font())
		cl.add_theme_font_size_override("font_size", UiTheme.MIN_TEXT)
		cl.add_theme_color_override("font_color", Color.WHITE)
		cl.add_theme_color_override("font_outline_color", UiTheme.color("encre.900", UiTheme.INK))
		cl.add_theme_constant_override("outline_size", 4)
		band.add_child(cl)
	var l := RichTextLabel.new()
	l.bbcode_enabled = true
	l.fit_content = true
	l.scroll_active = false
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(width, 0)
	l.size = Vector2(width, 0)
	l.add_theme_font_size_override("normal_font_size", 15)
	l.add_theme_font_size_override("bold_font_size", 16)
	l.add_theme_color_override("default_color", UiTheme.color("encre.700"))  # texte à l'encre sur le papier (UIK1)
	v.add_child(l)
	return l


# --- bourse --------------------------------------------------------------------------------
class Wallet extends HBoxContainer:
	var _labels := {}

	func _init() -> void:
		add_theme_constant_override("separation", 6)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		for k in ["gold", "keys", "crystal"]:
			var ic := TextureRect.new()
			ic.texture = UiTheme.texture(Items.material_icon(k))
			ic.custom_minimum_size = Vector2(26, 26)
			ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			ic.tooltip_text = {"gold": "Or (perdu en fin de partie)", "keys": "Clés (perdues en fin de partie)", "crystal": "Cristaux (gardés)"}[k]
			ic.mouse_filter = Control.MOUSE_FILTER_PASS
			add_child(ic)
			var l := Hud._label(self, "0", 16, Color(1.0, 0.85, 0.35) if k == "gold" else Color.WHITE)
			l.custom_minimum_size = Vector2(78, 0)
			l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			_labels[k] = l

	func refresh() -> void:
		for k in _labels:  # un montant qui change défile jusqu'à sa nouvelle valeur (UiFeel.number, UIK2)
			UiFeel.number(_labels[k], float(Profile.amount(k)), _fmt.bind(String(k)))

	static func _fmt(x: float, k: String) -> String:
		var n := roundi(x)
		return "%d %s" % [n, {"gold": "or", "keys": "clé" if n < 2 else "clés", "crystal": "cristal" if n < 2 else "cristaux"}[k]]


## Carte d'infobulle riche (texte BBCode, cadre de couleur).
static func tip_card(bbcode: String, border := UiTheme.GOLD_DIM, width := 360.0) -> Control:
	var p := PanelContainer.new()
	var sb := UiTheme.flat_box(Color(0.05, 0.04, 0.09, 0.97), border, 2, 10)
	sb.set_content_margin_all(12)
	p.add_theme_stylebox_override("panel", sb)
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.scroll_active = false
	r.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	r.custom_minimum_size = Vector2(width, 0)
	r.size = Vector2(width, 0)
	r.add_theme_font_size_override("normal_font_size", 15)
	r.add_theme_font_size_override("bold_font_size", 16)
	r.text = bbcode
	p.add_child(r)
	return p


## Bouton avec une carte riche au survol ([member tip], BBCode).
class TipButton extends Button:
	var tip := ""
	var tip_border := UiTheme.GOLD_DIM

	func _make_custom_tooltip(_for_text: String) -> Object:
		return ItemWidgets.tip_card(tip, tip_border) if tip != "" else null


## Bouton d'objet (listes) avec la carte d'objet au survol.
class CardButton extends Button:
	var item: Dictionary = {}

	func _make_custom_tooltip(_for_text: String) -> Object:
		return ItemWidgets.item_card(item) if not item.is_empty() else null


# --- marques des cases (lot GX-3) ---------------------------------------------------------------------
## Cadenas d'une pièce gardée : anse et corps soleil contourés d'encre, centré en [param c].
static func draw_lock(ci: CanvasItem, c: Vector2, k := 1.0) -> void:
	var ink := ForgeWidgets.ENCRE
	ci.draw_arc(c + Vector2(0, -2.0 * k), 4.2 * k, PI, TAU, 12, ink, 4.0 * k, true)
	ci.draw_arc(c + Vector2(0, -2.0 * k), 4.2 * k, PI, TAU, 12, ForgeWidgets.SOLEIL_CLAIR, 1.8 * k, true)
	var body := Rect2(c + Vector2(-6.0, -1.0) * k, Vector2(12.0, 9.0) * k)
	ci.draw_rect(body.grow(1.5 * k), ink)
	ci.draw_rect(body, ForgeWidgets.SOLEIL)
	ci.draw_rect(Rect2(body.position + Vector2(5.0, 3.0) * k, Vector2(2.0, 3.0) * k), ink)


## Pastille « neuf » (mandarine, inclinée, BIBLE § 5) centrée en [param c].
static func draw_new(ci: CanvasItem, c: Vector2) -> void:
	var font := UiTheme.bold_font()
	var txt := "neuf"
	var w := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x + 10.0
	ci.draw_set_transform(c, deg_to_rad(-8.0), Vector2.ONE)
	var r := Rect2(Vector2(-w * 0.5, -7.0), Vector2(w, 14.0))
	var sb := StyleBoxFlat.new()
	sb.bg_color = ForgeWidgets.MANDARINE
	sb.border_color = ForgeWidgets.ENCRE
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(7)
	ci.draw_style_box(sb, r)
	ci.draw_string_outline(font, Vector2(-w * 0.5 + 5.0, 4.0), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, 3, ForgeWidgets.ENCRE)
	ci.draw_string(font, Vector2(-w * 0.5 + 5.0, 4.0), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color.WHITE)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# --- case d'objet ---------------------------------------------------------------------------
## Pièce au-dessus du niveau de héros (lot H3) : fond rouge sombre, icône éteinte, niveau requis en rouge.
const LOCK_BG := Color(0.3, 0.05, 0.07, 0.95)
const LOCK_TEXT := Color(1.0, 0.42, 0.4)


class ItemSlot extends Button:
	signal activated  # double-clic ou clic droit

	var item: Dictionary = {}
	var placeholder := ""  # emplacement vide : nom de la pièce
	var ghost := ""  # emplacement vide : icône fantôme (entrée d'archive non remplie)
	var slot_id := ""  # emplacement d'équipement (cases de la poupée)
	var selected := false
	var dim := false  # objet non disponible (filtre, prix trop élevé...)
	var badge := ""  # petit texte en bas (prix, classe qui l'utilise...)
	var source := ""  # "equipped", "inventory"... (glisser-déposer)
	var can_drop: Callable  # func(data) -> bool
	var on_drop: Callable  # func(data)
	var card_extra: Callable  # func(item) -> String : lignes ajoutées à la carte au survol
	var card_text := ""  # carte au survol entièrement fournie (trésors de collection)
	var show_compare := false  # ▲ / ▼ : mieux ou moins bien que la pièce portée (au profil de la classe, lot GX-3)
	var wear_check := false  # lot H3 : pièce au-dessus du niveau de héros en rouge (coffre, équipement, fabrication, coffres)
	var marks := true  # lot GX-3 : cadenas (gardée), pastille « neuf », ★ (pièce d'un objectif)
	var better := false  # lot GX-3 : case de la poupée dont le sac a mieux (▲ pomme)
	var goal := false  # lot GX-3 : ★ forcée (plan visé, aperçu d'un objectif)

	func _init(size_px := 64.0) -> void:
		custom_minimum_size = Vector2(size_px, size_px)
		focus_mode = Control.FOCUS_NONE
		flat = true
		mouse_filter = Control.MOUSE_FILTER_STOP

	func _ready() -> void:
		# le moteur active _process à l'entrée dans l'arbre : seulement pour une pièce éveillée (aura animée) ;
		# sinon 200 cases d'une grille se redessineraient à chaque image (P2)
		set_process(item.get("awakened", false))

	func set_item(it: Dictionary) -> void:
		item = it
		if not it.is_empty():
			tooltip_text = Items.display_name(it)  # déclenche la carte d'objet au survol
		set_process(it.get("awakened", false))  # pièce éveillée : aura animée
		queue_redraw()

	func _process(_delta: float) -> void:
		queue_redraw()

	func _make_custom_tooltip(for_text: String) -> Object:
		if item.is_empty():
			return null
		var extra := String(card_extra.call(item)) if card_extra.is_valid() else ""
		if card_text != "":
			return ItemWidgets.tip_card(card_text + extra, Items.color_of(item))
		if for_text != Items.display_name(item):
			extra += "\n\n[color=#c8c8d4]%s[/color]" % for_text  # consigne propre à la case
		if wear_check and not String(item.get("slot", "")) in Items.SLOTS:
			extra = HeroLevel.lock_line(item) + extra  # (pièce d'équipement : le niveau requis est dans la carte, lot GX-3)
		if marks and Profile.is_locked(item):
			extra += "\n[color=#ffd76a]Gardée : jamais démontée[/color]"
		if marks and Profile.mark_seen(item):
			queue_redraw.call_deferred()  # regardée : plus « neuf »
		return ItemWidgets.item_card(item, extra)

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed:
			if event.button_index == MOUSE_BUTTON_RIGHT or (event.button_index == MOUSE_BUTTON_LEFT and event.double_click):
				activated.emit()
				accept_event()

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		var col: Color = Items.color_of(item) if not item.is_empty() else Color(0.35, 0.3, 0.25)
		var req := HeroLevel.wear_block(item) if wear_check else 0  # niveau de héros requis (0 : portable)
		# case autocollante (bible § 5, UIK2) : contour d'encre, bord de la rareté, fond d'encre (plus de fond noir) ;
		# choisie : bord lagon et lueur lagon (sélection) ; vide : bord d'encre clair
		var ink := StyleBoxFlat.new()
		ink.bg_color = UiTheme.color("encre.900")
		ink.set_corner_radius_all(12)
		ink.anti_aliasing = true
		var bg := StyleBoxFlat.new()
		bg.anti_aliasing = true
		bg.bg_color = UiTheme.color("encre.500") if not is_hovered() else Color("41356c")
		if req > 0:
			bg.bg_color = ItemWidgets.LOCK_BG if not is_hovered() else ItemWidgets.LOCK_BG.lightened(0.12)
		bg.border_color = UiTheme.color("bonbon.lagon.base") if selected else (col if not item.is_empty() else UiTheme.color("encre.300"))
		bg.set_border_width_all(3 if selected or not item.is_empty() else 2)
		bg.set_corner_radius_all(10)
		if selected:
			ink.shadow_color = Color(UiTheme.color("bonbon.lagon.base"), 0.55)
			ink.shadow_size = 8
		draw_style_box(ink, r)
		draw_style_box(bg, r.grow(-2.0))
		if item.is_empty():
			var gt := UiTheme.texture(ghost) if ghost != "" else null
			if gt:
				draw_texture_rect(gt, r.grow(-8.0), false, Color(0.45, 0.42, 0.55, 0.35))
			if placeholder != "":
				HudWidgets.text_center(self, placeholder, r.get_center(), UiTheme.bold_font(), 12, Color(1, 1, 1, 0.35), 0)
			return
		# lueur de rareté sous l'icône
		var glow := Color(col, 0.18)
		draw_rect(r.grow(-4.0), glow)
		var tex := UiTheme.texture(String(item.get("icon", "")))
		if tex:
			draw_texture_rect(tex, r.grow(-6.0), false, Color(1, 1, 1, 0.45 if dim or req > 0 else 1.0))
		if item.get("awakened", false):
			# éveillé : aura dorée qui pulse autour de la pièce
			var t := Time.get_ticks_msec() / 1000.0
			for k in 3:
				var a := (0.35 - 0.1 * k) * (0.6 + 0.4 * sin(t * 3.0 + k))
				draw_rect(r.grow(-2.0 - 2.0 * k), Color(1.0, 0.85, 0.35, a), false, 2.0)
			draw_rect(r.grow(-6.0), Color(1.0, 0.9, 0.5, 0.08 + 0.06 * sin(t * 2.0)))
		var font := UiTheme.bold_font()
		var up := int(item.get("upgrade", 0))
		if up > 0:
			HudWidgets.text_center(self, "+%d" % up, Vector2(size.x - 13.0, 11.0), font, 13, Color(1, 0.88, 0.45), 4)
		var locked := marks and Profile.is_locked(item)
		if item.has("set") and (req == 0 or badge == ""):
			HudWidgets.diamond(self, Vector2(21 if locked else 9, 9), 5.0, Items.SET_COLOR)
		if locked:
			ItemWidgets.draw_lock(self, Vector2(10, 10), 1.0)
		var sockets: Array = item.get("sockets", [])
		for i in sockets.size():
			var p := Vector2(9.0 + i * 11.0, size.y - 9.0)
			draw_circle(p, 4.5, Color(0, 0, 0, 0.8))
			draw_circle(p, 3.2, Color(0.75, 0.55, 1.0) if sockets[i] != null else Color(0.35, 0.33, 0.4))
		if show_compare and item.has("slot") and req == 0:
			var c := Items.profile_gain(item)
			if absf(c) >= 0.02:
				HudWidgets.text_center(self, "▲" if c > 0 else "▼", Vector2(size.x - 10.0, 12.0), font, 14,
					Color(0.45, 1.0, 0.5) if c > 0 else Color(1.0, 0.45, 0.4), 4)
		if better:  # case de la poupée : le sac a mieux (lot GX-3)
			HudWidgets.text_center(self, "▲", Vector2(size.x - 10.0, 12.0 if up <= 0 else 26.0), font, 15, ForgeWidgets.POMME, 4)
		if marks and (goal or Goals.is_goal_item(item)):
			var sp := Vector2(11.0, size.y - (21.0 if not (item.get("sockets", []) as Array).is_empty() else 11.0))
			ForgeWidgets.star(self, sp, 9.0, ForgeWidgets.ENCRE)
			ForgeWidgets.star(self, sp, 7.0, ForgeWidgets.SOLEIL)
		if marks and Profile.is_new(item) and size.x >= 44.0:
			ItemWidgets.draw_new(self, Vector2(size.x * 0.5, 9.0))
		if req > 0:  # le niveau requis, en rouge (en haut à gauche si un badge occupe le bas)
			var at := Vector2(size.x - 11.0, size.y - 9.0) if badge == "" else Vector2(13.0, 11.0)
			HudWidgets.text_center(self, str(req), at, font, 12, ItemWidgets.LOCK_TEXT, 4)
		if badge != "":
			HudWidgets.text_center(self, badge, Vector2(size.x * 0.5, size.y - 8.0), font, 11, Color(1, 1, 1, 0.9), 4)
		elif req == 0 and int(item.get("level", 1)) > 0:
			HudWidgets.text_center(self, str(int(item.get("level", 1))), Vector2(size.x - 11.0, size.y - 9.0), font, 11, Color(1, 1, 1, 0.75), 3)

	func _get_drag_data(_at: Vector2) -> Variant:
		if item.is_empty() or source == "":
			return null
		var preview := TextureRect.new()
		preview.texture = UiTheme.texture(String(item.get("icon", "")))
		preview.custom_minimum_size = Vector2(56, 56)
		preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		preview.modulate.a = 0.85
		set_drag_preview(preview)
		return {"item": item, "source": source, "slot": slot_id}

	func _can_drop_data(_at: Vector2, data: Variant) -> bool:
		return data is Dictionary and data.has("item") and can_drop.is_valid() and bool(can_drop.call(data))

	func _drop_data(_at: Vector2, data: Variant) -> void:
		if on_drop.is_valid():
			on_drop.call(data)


# --- grille d'objets ------------------------------------------------------------------------
## Grille filtrable (rareté, emplacement), triable, à sélection simple ou multiple
## (clic, Ctrl+clic, Maj+clic, Ctrl+A).
class ItemGrid extends VBoxContainer:
	signal selection_changed
	signal item_activated(item: Dictionary)

	var multi := false
	var source := "inventory"
	var cell := 64.0
	var badge_fn: Callable  # func(item) -> String
	var dim_fn: Callable  # func(item) -> bool
	var can_drop: Callable
	var on_drop: Callable
	var card_extra: Callable  # func(item) -> String : ajout à la carte au survol
	var compare := true  # ▲ / ▼ de comparaison sur les cases (la Forge les coupe : le +N reste lisible)
	var first_fn: Callable  # func(item) -> bool : ces pièces d'abord, quel que soit le tri (la Forge : les pièces portées)
	var _search: LineEdit  # recherche par nom (enable_search, lot GX-4)
	var _items: Array = []
	var _shown: Array = []
	var _selection: Array = []
	var _anchor := -1
	var _grid: GridContainer
	var _rarity: OptionButton
	var _slot: OptionButton
	var _sort: OptionButton
	var _count: Label
	var _empty_text := "Aucun objet."
	var _empty: Label

	func _init(multi_select := false, columns := 8, cell_px := 64.0) -> void:
		multi = multi_select
		cell = cell_px
		add_theme_constant_override("separation", 8)
		size_flags_vertical = Control.SIZE_EXPAND_FILL
		var bar := HBoxContainer.new()
		bar.add_theme_constant_override("separation", 6)
		add_child(bar)
		_rarity = _option(bar, ["Toutes raretés"] + Items.RARITIES.map(func(r): return r.name) + ["Pièces de set"])
		_slot = _option(bar, ["Tous types"] + Items.SLOTS.map(func(s): return Items.SLOT_NAMES[s]))
		_sort = _option(bar, ItemWidgets.SORTS.map(func(s): return "Tri : " + s))
		_count = Hud._label(bar, "", 14, UiTheme.MUTED)
		_count.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		var scroll := ScrollContainer.new()
		scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		add_child(scroll)
		_grid = GridContainer.new()
		_grid.columns = columns
		_grid.add_theme_constant_override("h_separation", 6)
		_grid.add_theme_constant_override("v_separation", 6)
		scroll.add_child(_grid)
		var none := UiTheme.empty_state(self, "", "collection")  # état vide illustré (UIK2) : icône, phrase
		none.custom_minimum_size = Vector2.ZERO
		none.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		none.visible = false
		_empty = none.get_child(none.get_child_count() - 1) as Label

	func _option(parent: Control, labels: Array) -> OptionButton:
		var o := OptionButton.new()
		o.focus_mode = Control.FOCUS_NONE
		o.fit_to_longest_item = false  # largeur du choix affiché : la rangée de filtres tient dans un panneau étroit (1280 px)
		o.clip_text = true
		o.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		o.add_theme_font_size_override("font_size", 14)
		for l in labels:
			o.add_item(String(l))
		o.item_selected.connect(func(_i): refresh())
		parent.add_child(o)
		return o

	func set_empty_text(t: String) -> void:
		_empty_text = t

	## Ajoute une recherche par nom au-dessus des filtres (lot GX-4) : le texte filtre les cases au fil de la frappe.
	func enable_search(placeholder := "Chercher") -> LineEdit:
		if _search:
			return _search
		_search = LineEdit.new()
		_search.placeholder_text = placeholder
		_search.clear_button_enabled = true
		_search.custom_minimum_size = Vector2(0, 34)
		_search.add_theme_font_size_override("font_size", 14)
		_search.text_changed.connect(func(_t): refresh())
		add_child(_search)
		move_child(_search, 0)
		return _search

	## Le nom de [param it] contient [param q] (sans tenir compte des accents ni de la casse).
	static func name_matches(it: Dictionary, q: String) -> bool:
		if q.strip_edges() == "":
			return true
		var hay := (Items.display_name(it) + " " + String(Items.SLOT_NAMES.get(String(it.get("slot", "")), ""))).to_lower()
		return _plain(hay).contains(_plain(q.strip_edges().to_lower()))

	## Minuscules sans accents (é → e…) pour la recherche.
	static func _plain(s: String) -> String:
		var out := s
		for pair in [["é", "e"], ["è", "e"], ["ê", "e"], ["ë", "e"], ["à", "a"], ["â", "a"], ["î", "i"], ["ï", "i"], ["ô", "o"], ["û", "u"], ["ù", "u"], ["ç", "c"], ["œ", "oe"]]:
			out = out.replace(pair[0], pair[1])
		return out

	func set_items(items: Array) -> void:
		_items = items
		_selection = _selection.filter(func(x): return _items.any(func(y): return is_same(x, y)))
		refresh()

	func selection() -> Array:
		return _selection

	func shown() -> Array:
		return _shown

	func first_selected() -> Dictionary:
		return _selection[0] if not _selection.is_empty() else {}

	func clear_selection() -> void:
		_selection.clear()
		_anchor = -1
		refresh()
		selection_changed.emit()

	func select_item(it: Dictionary) -> void:
		_selection = [it] if not it.is_empty() else []
		refresh()
		selection_changed.emit()

	## Sélectionne tout ce qui est visible jusqu'à la rareté [param r] incluse.
	func select_up_to_rarity(r: int) -> void:
		_selection = _shown.filter(func(it): return int(it.rarity) <= r and not it.has("set"))
		refresh()
		selection_changed.emit()

	func select_all_shown() -> void:
		_selection = _shown.duplicate()
		refresh()
		selection_changed.emit()

	func refresh() -> void:
		var rf := _rarity.selected - 1
		var sf := _slot.selected - 1
		_shown = _items.filter(func(it):
			if rf >= 0 and rf < Items.RARITIES.size() and int(it.rarity) != rf:
				return false
			if rf == Items.RARITIES.size() and not it.has("set"):
				return false
			if sf >= 0 and it.slot != Items.SLOTS[sf]:
				return false
			if _search and not name_matches(it, _search.text):
				return false
			return true)
		var key := _sort.selected
		var first := first_fn
		_shown.sort_custom(func(a, b): return _sort_key(a, key) + (1e7 if first.is_valid() and first.call(a) else 0.0) > _sort_key(b, key) + (1e7 if first.is_valid() and first.call(b) else 0.0))
		for c in _grid.get_children():
			c.queue_free()
		for i in _shown.size():
			var it: Dictionary = _shown[i]
			var s := ItemWidgets.ItemSlot.new(cell)
			s.set_item(it)
			s.show_compare = compare
			s.source = source
			s.selected = _selection.any(func(x): return is_same(x, it))
			s.badge = String(badge_fn.call(it)) if badge_fn.is_valid() else ""
			s.dim = bool(dim_fn.call(it)) if dim_fn.is_valid() else false
			s.can_drop = can_drop
			s.on_drop = on_drop
			s.card_extra = card_extra
			s.pressed.connect(_on_pressed.bind(it, i))
			s.activated.connect(func(): item_activated.emit(it))
			_grid.add_child(s)
		# cases vides : on peut y déposer un objet porté
		if can_drop.is_valid():
			for i in maxi(0, _grid.columns * 2 - _shown.size() % _grid.columns):
				var e := ItemWidgets.ItemSlot.new(cell)
				e.disabled = true
				e.can_drop = can_drop
				e.on_drop = on_drop
				_grid.add_child(e)
		_count.text = "%s%s" % [GearPower.plural(_shown.size(), "objet"), (" · %s" % GearPower.plural(_selection.size(), "sélectionné", "sélectionnés")) if multi and not _selection.is_empty() else ""]
		_empty.text = _empty_text if _items.is_empty() else ""
		(_empty.get_parent() as Control).visible = _items.is_empty()

	func _sort_key(it: Dictionary, key: int) -> float:
		match key:
			1:
				return float(it.level) * 100.0 + float(it.rarity)
			2:
				return float(Items.SLOTS.size() - Items.SLOTS.find(it.slot)) * 100.0 + float(it.rarity)
			3:
				return float(Items.sell_price(it)) + 4.0 * float(int(it.get("upgrade", 0)))
		return float(it.rarity) * 1000.0 + float(Items.power_level(it)) * 10.0 + float(it.get("upgrade", 0)) + (500.0 if it.has("set") else 0.0)

	func _on_pressed(it: Dictionary, index: int) -> void:
		if multi and Input.is_key_pressed(KEY_SHIFT) and _anchor >= 0 and _anchor < _shown.size():
			var a := mini(_anchor, index)
			var b := maxi(_anchor, index)
			for k in range(a, b + 1):
				if not _selection.any(func(x): return is_same(x, _shown[k])):
					_selection.append(_shown[k])
		elif multi and (Input.is_key_pressed(KEY_CTRL) or Input.is_key_pressed(KEY_META)):
			var found := _selection.find_custom(func(x): return is_same(x, it))
			if found >= 0:
				_selection.remove_at(found)
			else:
				_selection.append(it)
			_anchor = index
		else:
			_selection = [it]
			_anchor = index
		refresh()
		selection_changed.emit()

	func _unhandled_key_input(event: InputEvent) -> void:
		if multi and is_visible_in_tree() and event is InputEventKey and event.pressed and event.keycode == KEY_A and event.ctrl_pressed:
			select_all_shown()
			get_viewport().set_input_as_handled()
