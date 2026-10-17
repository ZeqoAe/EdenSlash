class_name ColiseePrepPage
extends CanvasLayer
## Le Colisée, lots CO-E / CO-F : page MINIMALE de préparation (essais à la main ; l'écran complet de l'étude ARENA § 6.11 —
## trio, frise, 6 équipes, pied, choix d'atout v2 sans pause — vient au lot CO-G). Elle ne tient pas la pause (les autres
## héros choisissent pendant ce temps). Ouverte par le directeur du combat quand le joueur a un choix à faire ; au temps
## écoulé, ce qui reste prend la meilleure option (ColiseeAnvil.auto_finish).
## De haut en bas : or ; offre d'atouts (icône, nom, une phrase, rareté ; détail chiffré en infobulle ; « Relancer ») ; sort
## de plus ; enclumes (offertes, puis Stat / Pièce / Panoplie à leur prix) et leurs trois options ; pièces portées
## (« Revendre ») ; bonus de stat de la manche (« Annuler ») ; « Prêt ».

const LAYER := 40
const WIDTH := 560.0

var g: Object
var b: ColiseeBuild
var player: Player
var box: VBoxContainer


static func open(parent: Node, game: Object, build: ColiseeBuild, pl: Player) -> ColiseePrepPage:
	var page := ColiseePrepPage.new()
	page.layer = LAYER
	page.g = game
	page.b = build
	page.player = pl
	parent.add_child(page)
	page.rebuild()
	return page


func rebuild() -> void:
	for c in get_children():
		remove_child(c)
		c.queue_free()
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiTheme.panel_style())
	panel.anchor_left = 1.0
	panel.anchor_right = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_left = -WIDTH - 16.0
	panel.offset_right = -16.0
	panel.offset_top = 70.0
	panel.offset_bottom = -90.0
	add_child(panel)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	box = VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 6)
	scroll.add_child(box)
	_label("Manche %d · préparation" % int(g.get("round_n")), 22)
	_label("Or : %d" % b.gold, 18, UiTheme.color("bonbon.soleil.fonce", UiTheme.INK))
	_augments()
	_spells()
	_anvils()
	_gear()
	var ready := _button("Prêt", 20)
	ready.pressed.connect(_on_ready)


func _label(t: String, size := 16, col := UiTheme.INK) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", maxi(size, UiTheme.MIN_TEXT))
	l.add_theme_color_override("font_color", col)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(l)
	return l


func _button(t: String, size := 16, icon: Texture2D = null, parent: Control = null) -> Button:
	var bt := Button.new()
	bt.text = t
	bt.icon = icon
	bt.expand_icon = true
	bt.alignment = HORIZONTAL_ALIGNMENT_LEFT
	bt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bt.custom_minimum_size = Vector2(0, 44)
	UiTheme.style_button(bt, "papier", maxi(size, UiTheme.MIN_TEXT))
	(parent if parent != null else box).add_child(bt)
	return bt


func _augments() -> void:
	if b.offer.is_empty():
		if not b.augments.is_empty():
			_label("Atouts : " + ", ".join(b.augments.map(func(id): return String(ColiseeAugments.def(id).get("name", id)))), 15)
		return
	_label("Choisis un atout (%s)" % String(ColiseeAugments.RARITIES[b.offer_rarity].name), 18)
	for i in b.offer.size():
		var c := ColiseeAugments.card(String(b.offer[i]))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		box.add_child(row)
		var stripe := ColorRect.new()  # (bandeau de rareté)
		stripe.color = c.color
		stripe.custom_minimum_size = Vector2(8, 0)
		row.add_child(stripe)
		var bt := _button("%s — %s" % [c.name, c.text], 16, ColiseeAugments.texture(String(b.offer[i]), 40), row)
		bt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bt.tooltip_text = String(c.tip) + ("\nVa bien avec : " + ", ".join(c.goes) if not (c.goes as Array).is_empty() else "")
		bt.pressed.connect(_take_augment.bind(i))
		if b.rerolls > 0:
			var rr := _button("", 14, Ico.tex("refresh", 24), row)
			rr.tooltip_text = "Relancer cette carte (%d)" % b.rerolls
			rr.custom_minimum_size = Vector2(52, 44)
			rr.alignment = HORIZONTAL_ALIGNMENT_CENTER
			rr.pressed.connect(_reroll.bind(i))


func _spells() -> void:
	if b.spell_offer.is_empty():
		return
	_label("Un sort de plus", 18)
	for i in b.spell_offer.size():
		var s: Dictionary = Run.skill_def(int(b.spell_offer[i]))
		var tex: Texture2D = load(String(s.icon)) if String(s.get("icon", "")) != "" and ResourceLoader.exists(String(s.icon)) else null
		var bt := _button(String(s.get("name", "?")), 16, tex)
		bt.tooltip_text = String(s.get("desc", ""))
		bt.pressed.connect(_take_spell.bind(i))


func _anvils() -> void:
	if not b.anvil.is_empty():
		_label(String(ColiseeAnvil.ANVILS[String(b.anvil.kind)].name) + " : garde une option", 18)
		for i in (b.anvil.options as Array).size():
			var bt := _button(ColiseeAnvil.option_text(b.anvil.options[i]), 15)
			var it: Dictionary = b.anvil.options[i].get("item", {})
			if not it.is_empty():
				bt.tooltip_text = Items.describe(it, true)
			bt.pressed.connect(_choose.bind(i))
		return
	for gift in b.gifts:
		var bt := _button("Ouvrir : %s (offerte)" % String(ColiseeAnvil.ANVILS[String(gift)].name), 16, Ico.tex(String(ColiseeAnvil.ANVILS[String(gift)].ico), 32))
		bt.pressed.connect(_open.bind(String(gift), true))
	for k in ColiseeAnvil.ANVIL_ORDER:
		var a: Dictionary = ColiseeAnvil.ANVILS[k]
		var bt := _button("%s · %d or" % [String(a.name), int(a.price)], 15, Ico.tex(String(a.ico), 32))
		bt.tooltip_text = String(a.text)
		bt.disabled = b.gold < int(a.price)
		bt.pressed.connect(_open.bind(String(k), false))


func _gear() -> void:
	if b.gear.is_empty() and b.stat_buys.is_empty():
		return
	_label("Ton équipement", 16)
	for s in b.gear.keys():
		var it: Dictionary = b.gear[s]
		var bt := _button("%s · Revendre (+%d)" % [String(it.get("name", s)), ColiseeAnvil.resale(it, int(g.get("round_n")))], 14)
		bt.tooltip_text = Items.describe(it, true)
		bt.pressed.connect(_sell.bind(String(s)))
	for i in b.stat_buys.size():
		var e: Dictionary = b.stat_buys[i]
		var bt := _button("%s · Annuler (+%d)" % [String(ColiseeAnvil.STATS[String(e.key)].name), int(e.price)], 14)
		bt.pressed.connect(_undo.bind(i))


# --- actions -----------------------------------------------------------------------------------------------------------------

func _refresh() -> void:
	if is_instance_valid(player) and player.arena_id >= 0 and player.arena_id != ColiseeDirector.PARK:
		ColiseeAugments.apply_hero(player, b, ColiseeBuild.team_of(g, b.team))
	rebuild()


func _take_augment(i: int) -> void:
	ColiseeAugments.take(b, String(b.offer[i]), g)
	_refresh()


func _reroll(i: int) -> void:
	ColiseeAugments.reroll(b, i, ColiseeAugments.context_for(g, b), ColiseeAnvil.rng_of(g))
	rebuild()


func _take_spell(i: int) -> void:
	ColiseeAnvil.take_spell(b, i)
	_refresh()


func _open(kind: String, gift: bool) -> void:
	ColiseeAnvil.open_anvil(b, kind, g, gift)
	rebuild()


func _choose(i: int) -> void:
	ColiseeAnvil.choose(b, i, g)
	_refresh()


func _sell(slot: String) -> void:
	ColiseeAnvil.sell(b, slot, g)
	_refresh()


func _undo(i: int) -> void:
	ColiseeAnvil.undo_stat(b, i)
	_refresh()


func _on_ready() -> void:
	ColiseeAnvil.auto_finish(g)
	b.ready = true
	_refresh()
