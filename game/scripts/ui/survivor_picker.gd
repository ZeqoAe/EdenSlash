class_name SurvivorPicker
extends CardPicker
## Choix de carte v2 du Survivant (lot SVX-2 ; maquette conception/benchmark/survivant_maquettes/v2_choix_carte.svg ;
## BIBLE v2 § 5-7). Le monde le crée à la place de CardPicker quand un Survivant est en cours (World : Survivor.active) ;
## la file, la pause, les relances, Passer, bannir et garder restent ceux de CardPicker et de SurvivorCards.
##   - le jeu reste visible derrière : flou + voile d'encre (jamais de fond noir plein) ;
##   - titre « Niveau 14 ! » en Mochiy incliné −3°, « Choisis une carte · 2 autres en attente » ;
##   - trois cartes papier : bandeau de rareté deux tons avec la touche (1, 2, 3) et l'étiquette de famille, icône du jeu dans
##     sa case, LE chiffre de la décision, l'aléa encadré, deux lignes au plus, pastille verte de synergie (évolution,
##     panoplie), pied « Maj : tout le détail » (Maj tenue, ou RB : la carte complète de SurvivorCardView.build) ;
##   - à droite, le panneau d'encre « Ton équipement » : les 9 cases (la case visée en pointillés lagon), le héros avant →
##     après la carte survolée, les panoplies, sorts et évolutions ;
##   - une seule barre : Relancer (X / R), Bannir… (Y / F), Garder… (LB / C), Passer +or (B / P). Bannir et Garder passent
##     en mode visée : les cartes éligibles se soulignent, les autres se grisent ; un clic, A ou 1-2-3 sur la carte, B / Échap
##     ou le même bouton annule.

## Touches de la barre : [bouton de manette, touche du clavier].
const BAR_KEYS := {"reroll": [JOY_BUTTON_X, "R"], "ban": [JOY_BUTTON_Y, "F"], "keep": [JOY_BUTTON_LEFT_SHOULDER, "C"], "skip": [JOY_BUTTON_B, "P"]}
## Couleur de la pastille de la touche à la manette (BIBLE § 6 : X lagon, Y soleil, B fraise ; gâchettes à l'encre).
const PAD_TONES := {"reroll": "lagon", "ban": "soleil", "keep": "nuit", "skip": "fraise"}
const BAND_H := 44.0
const PANEL_W := [270.0, 300.0]  # panneau « Ton équipement » : sous / au-dessus de 1500 px de large

var aim := ""  # mode visée : "" | "ban" | "keep"
var detail := false  # Maj tenue : cartes complètes
var hover := -1  # carte survolée (souris ou cadre de la manette)
var sub_label: Label
var ban_button: Button
var keep_button: Button
var aim_hint: Label
var panel: EquipPanel
var _card_w := 300.0
var _last_title := ""
var _raw_title := ""


func _ready() -> void:
	super._ready()
	var dim := _root.get_child(0) as ColorRect
	dim.color = Color.WHITE
	dim.material = _blur_material()
	var v := _title.get_parent() as VBoxContainer
	v.custom_minimum_size = Vector2.ZERO
	v.add_theme_constant_override("separation", 10)
	UiTheme.title(_title, 44, UiTheme.color("bonbon.soleil.base"))
	_title.rotation_degrees = -3.0
	_title.resized.connect(func(): _title.pivot_offset = _title.size * 0.5)
	sub_label = Label.new()
	sub_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub_label.add_theme_font_override("font", UiTheme.bold_font())
	sub_label.add_theme_font_size_override("font_size", 17)
	sub_label.add_theme_color_override("font_color", UiTheme.color("papier.100"))
	sub_label.add_theme_constant_override("outline_size", 4)
	sub_label.add_theme_color_override("font_outline_color", UiTheme.color("encre.700"))
	v.add_child(sub_label)
	v.move_child(sub_label, _title.get_index() + 1)
	_tip.add_theme_stylebox_override("panel", UiTheme.sticker("nuit", {"shadow": 5, "radius": 14, "gloss": false, "cel_top": 0.0, "cel_bottom": 0.0, "pad": Vector2(14, 8)}))
	# cartes + panneau « Ton équipement »
	var mid := HBoxContainer.new()
	mid.alignment = BoxContainer.ALIGNMENT_CENTER
	mid.add_theme_constant_override("separation", 22)
	v.add_child(mid)
	v.move_child(mid, _row.get_index())
	v.remove_child(_row)
	mid.add_child(_row)
	_row.add_theme_constant_override("separation", 18)
	_row.size_flags_vertical = Control.SIZE_SHRINK_CENTER  # (les cartes gardent leur hauteur, pas celle du panneau voisin)
	panel = EquipPanel.new(self)
	mid.add_child(panel)
	_shared.visible = false
	aim_hint = Label.new()
	aim_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	aim_hint.custom_minimum_size = Vector2(0, 22)
	aim_hint.add_theme_font_override("font", UiTheme.bold_font())
	aim_hint.add_theme_font_size_override("font_size", 16)
	aim_hint.add_theme_color_override("font_color", UiTheme.color("bonbon.lagon.clair"))
	aim_hint.add_theme_constant_override("outline_size", 4)
	aim_hint.add_theme_color_override("font_outline_color", UiTheme.color("encre.700"))
	v.add_child(aim_hint)
	v.move_child(aim_hint, mid.get_index() + 1)
	# une seule barre : Relancer, Bannir…, Garder…, Passer
	var bar := _reroll.get_parent() as HBoxContainer
	bar.add_theme_constant_override("separation", 14)
	ban_button = Button.new()
	keep_button = Button.new()
	bar.add_child(ban_button)
	bar.add_child(keep_button)
	bar.move_child(ban_button, _reroll.get_index() + 1)
	bar.move_child(keep_button, ban_button.get_index() + 1)
	ban_button.pressed.connect(toggle_aim.bind("ban"))
	keep_button.pressed.connect(toggle_aim.bind("keep"))
	for e in [[_reroll, "reroll"], [ban_button, "ban"], [keep_button, "keep"], [_skip, "skip"]]:
		_decorate(e[0], String(e[1]))
	Gamepad.device_changed.connect(func(_pad): _refresh_reroll())


## Flou de la scène + voile d'encre (BIBLE § 2 : le jeu reste visible derrière un choix).
static func _blur_material() -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = """shader_type canvas_item;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform vec4 veil : source_color = vec4(0.133, 0.102, 0.227, 0.5);
uniform float lod = 2.6;
void fragment() {
	vec3 c = textureLod(screen_tex, SCREEN_UV, lod).rgb;
	COLOR = vec4(mix(c, veil.rgb, veil.a), 1.0);
}
"""
	var m := ShaderMaterial.new()
	m.shader = sh
	return m


## Bouton de la barre : autocollant, pastille de la touche à gauche (dessinée).
func _decorate(b: Button, kind: String) -> void:
	UiTheme.style_button(b, "lagon" if kind == "reroll" else "papier", 18)
	for st in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		var sb := b.get_theme_stylebox(st)
		if sb != null:
			sb.content_margin_left = 54.0
			sb.content_margin_right = 18.0
	b.custom_minimum_size = Vector2(0, 54)
	b.set_meta("bar_kind", kind)
	b.draw.connect(_draw_key.bind(b, kind))


func _key_label(kind: String) -> String:
	return Settings.pad_name(int(BAR_KEYS[kind][0])) if Gamepad.active else String(BAR_KEYS[kind][1])


func _draw_key(b: Button, kind: String) -> void:
	var font := UiTheme.bold_font()
	var t := _key_label(kind)
	var w := maxf(30.0, font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x + 14.0)
	var r := Rect2(12, (b.size.y - 4.0) * 0.5 - 14.0, w, 28)
	var ink := UiTheme.color("encre.700")
	var pad := Gamepad.active
	var fill := UiTheme.color("papier.100")
	if pad:
		fill = UiTheme.tones(String(PAD_TONES[kind]))[1]
	if b.disabled:
		fill = fill.lerp(Color(0.8, 0.78, 0.86), 0.6)
	SurvivorHud.round_rect(b, r, fill, 14, 2, ink)
	SurvivorHud.ink_text(b, font, t, r.get_center().x, r.position.y + 20.0, 15, Color.WHITE if pad else ink, 4 if pad else 0)


# --- cartes ----------------------------------------------------------------------------------------------------------------
func _show_cards(cards: Array) -> void:
	_cards = cards
	aim = ""
	for c in _row.get_children():
		c.queue_free()
	_buttons.clear()
	_shared.visible = false
	_split_title()
	var vw := get_viewport().get_visible_rect().size.x
	var pw: float = PANEL_W[1] if vw >= 1500.0 else PANEL_W[0]
	panel.custom_minimum_size.x = pw
	_card_w = clampf((vw - 48.0 - pw - 22.0 - 18.0 * maxf(_cards.size() - 1, 0)) / maxf(_cards.size(), 1), 240.0, 310.0)
	for i in _cards.size():
		var b := _make_card(_cards[i], i, "")
		_buttons.append(b)
		_row.add_child(b)
	_opened_at = Time.get_ticks_msec()
	_row.modulate.a = VEIL_ALPHA
	hover = -1
	panel.refresh(-1)
	_refresh_reroll()
	_apply_aim()
	_fit_heights()


## Un choix de plus dans la file : « N autres en attente » se met à jour sous le titre du choix ouvert.
## Choix regroupés (lot SVX-4, BM-SURV SV-Q3 : réglage interface/sv_group_choices) : une montée de niveau ne met plus le jeu en
## pause ; elle attend dans la file (pastille « N choix en attente » du HUD) et s'ouvre quand le joueur le veut (touche des
## objectifs, Tab / croix gauche). Un coffre ouvert passe devant et ouvre la file avec lui.
func offer(title: String, cards: Array, reroll := Callable(), own_rerolls := -1) -> void:
	var was_open := is_open()
	var list := cards.filter(func(c): return not (c as Dictionary).is_empty())
	if list.is_empty():
		return
	if grouping() and not was_open:
		if String(title).begins_with("Niveau "):
			_queue.append([title, list, reroll, own_rerolls, true])
			return
		if not _queue.is_empty():
			_queue.push_front([title, list, reroll, own_rerolls])
			_show_next()
			return
	super.offer(title, list, reroll, own_rerolls)
	if was_open and is_open():
		_split_title()


## Choix regroupés en cours (réglage, Survivant, ni pilote ni aide « Bot »).
static func grouping() -> bool:
	return Survivor.active and bool(Settings.get_v("interface", "sv_group_choices")) and not Settings.auto_cards()


## Choix en attente (fermés) : la pastille du HUD.
func held() -> int:
	return 0 if is_open() else _queue.size()


## Ouvre les choix en attente (touche des objectifs, ou le HUD).
func open_held() -> bool:
	if is_open() or _queue.is_empty():
		return false
	_show_next()
	return true


## Le titre brut du choix qui s'ouvre (« Niveau 14 ! Choisis une carte ») est gardé : une relance redessine le même.
## Un choix qui a attendu (choix regroupés) et dont une carte n'est plus valable (emplacement pris, sort monté entre-temps) est
## tiré de nouveau (lot SVX-4).
func _show_next() -> void:
	if not _queue.is_empty():
		_raw_title = String(_queue[0][0])
		var it: Array = _queue[0]
		if it.size() > 4 and bool(it[4]) and (it[2] as Callable).is_valid() \
				and (it[1] as Array).any(func(c): return SurvivorCards.FAMILY.get(String(c.get("type", "")), "") != "fallback" and not SurvivorCards.still_valid(c)):
			it[1] = (it[2] as Callable).call()
	super._show_next()


## Titre du choix en deux temps : « Niveau 14 ! » (grand, incliné) puis « Choisis une carte · 2 autres en attente ».
func _split_title() -> void:
	var raw := _raw_title if _raw_title != "" else _title.text
	var main := raw
	var rest := ""
	var m := RegEx.create_from_string("^(Niveau \\d+ !)\\s*(.*)$").search(raw)
	if m:
		main = m.get_string(1)
		rest = m.get_string(2)
	elif raw.begins_with("Choisis ton arme ou ta première"):
		main = "Ta première carte !"  # (premier choix de la partie : une arme ou un sort)
		rest = "Une arme ou un sort pour commencer"
	elif raw.contains(" : "):
		main = raw.get_slice(" : ", 0)
		rest = raw.substr(raw.find(" : ") + 3)
		rest = rest.substr(0, 1).to_upper() + rest.substr(1)
	var waiting := _queue.size()
	if waiting > 0:
		rest += (" · " if rest != "" else "") + ("%d autre%s en attente" % [waiting, "s" if waiting > 1 else ""])
	var fresh := raw != _last_title
	_title.text = main
	_last_title = raw
	var big := m != null or raw.begins_with("Choisis ton arme ou ta première")  # (moments forts : montée de niveau, premier choix)
	_title.add_theme_font_size_override("font_size", 44 if big else 34)
	_title.add_theme_constant_override("outline_size", UiTheme.outline_for(44 if big else 34))
	sub_label.text = rest
	sub_label.visible = rest != ""
	if fresh and not UiFeel.reduce_motion:
		_title.scale = Vector2.ONE * 0.7
		var tw := _title.create_tween()
		tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		tw.tween_property(_title, "scale", Vector2.ONE, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _make_card(card: Dictionary, i: int, _desc: String) -> Button:
	var tones := SurvivorCardView.tones_of(card)
	var b := Button.new()
	b.custom_minimum_size = Vector2(_card_w, 380)
	b.focus_mode = Control.FOCUS_NONE
	b.set_meta("ui_feel", "card")
	var st := UiTheme.button_states("papier", {"shadow": 7, "radius": 18, "gloss": false, "cel_top": 0.0, "cel_bottom": 0.06, "pad": Vector2.ZERO})
	for k in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		b.add_theme_stylebox_override(k, st[k])
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.pressed.connect(_choose.bind(i))
	b.mouse_entered.connect(func(): _set_hover(i))
	b.draw.connect(_draw_card_extra.bind(b, i))
	var band := Band.new(self, card, i, tones)
	band.set_anchors_preset(Control.PRESET_TOP_WIDE)
	band.offset_bottom = BAND_H
	b.add_child(band)
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 14
	v.offset_right = -14
	v.offset_top = BAND_H + 8.0
	v.offset_bottom = -15
	v.add_theme_constant_override("separation", 6)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.set_meta("content", v)
	b.set_meta("tones", tones)
	b.add_child(v)
	_fill(v, card, tones, b)
	return b


## Contenu de la carte : compact (build_v2) ou, Maj tenue, la carte complète de SurvivorCardView.build dans un puits d'encre.
func _fill(v: VBoxContainer, card: Dictionary, tones: Array, b: Button) -> void:
	for ch in v.get_children():
		v.remove_child(ch)
		ch.queue_free()
	if not detail:
		SurvivorCardView.build_v2(v, card, tones)
		b.set_meta("measure", v)
		b.set_meta("measure_pad", 0.0)
		return
	var well := PanelContainer.new()
	well.add_theme_stylebox_override("panel", UiTheme.well_style(Vector2(10, 8), 12))
	well.size_flags_vertical = Control.SIZE_EXPAND_FILL
	well.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(well)
	var scroll := ScrollContainer.new()  # (écran très bas : la carte complète défile plutôt que de déborder)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	well.add_child(scroll)
	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 6)
	inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scroll.add_child(inner)
	SurvivorCardView.build(inner, card, tones[1])
	b.set_meta("measure", inner)
	b.set_meta("measure_pad", 16.0)


## Cartes de même hauteur, assez hautes pour leur contenu, jamais plus que l'écran ne laisse (card_cap).
func _fit_heights() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var tallest := 340.0
	for b in _buttons:
		if is_instance_valid(b):
			tallest = maxf(tallest, needed_height(_buttons.find(b)))
	var cap := card_cap()
	for b in _buttons:
		if is_instance_valid(b):
			b.custom_minimum_size.y = minf(tallest, cap)
	if _pad_focus and _root.visible and not _buttons.is_empty() and is_instance_valid(_buttons[0]):
		_pad_focus = false
		UiNav.focus(_buttons[0])


## Hauteur maximale d'une carte : ce que l'écran laisse sous le titre (et la fiche de découverte) et au-dessus de la barre.
func card_cap() -> float:
	var vh := get_viewport().get_visible_rect().size.y
	var v := _title.get_parent() as VBoxContainer
	var sep := float(v.get_theme_constant("separation")) if v != null else 10.0
	# titre, consigne de visée (22), barre (58), marges ; sous-titre et fiche de découverte s'ils sont là
	var used := _title.get_combined_minimum_size().y + 22.0 + 58.0 + sep * 3.0 + 24.0
	if sub_label != null and sub_label.visible:
		used += sub_label.get_combined_minimum_size().y + sep
	if _tip.visible:
		used += _tip.get_combined_minimum_size().y + sep
	return clampf(vh - used, 300.0, 560.0)


## Hauteur nécessaire du contenu de la carte [param i] (tests : rien ne déborde).
func needed_height(i: int) -> float:
	var b: Button = _buttons[i]
	return (b.get_meta("measure") as Control).get_combined_minimum_size().y + float(b.get_meta("measure_pad", 0.0)) + BAND_H + 8.0 + 15.0 + 8.0


## Maj tenue (ou RB) : les cartes complètes ; relâchée : les cartes courtes.
func set_detail(on: bool) -> void:
	if on == detail or not _root.visible:
		return
	detail = on
	for i in _buttons.size():
		var b: Button = _buttons[i]
		if is_instance_valid(b):
			_fill(b.get_meta("content"), _cards[i], b.get_meta("tones"), b)
	_fit_heights()
	_hint()


func _set_hover(i: int) -> void:
	if i != hover:
		hover = i
		panel.refresh(i)


func _process(delta: float) -> void:
	super._process(delta)
	if not _root.visible:
		return
	var h := hover
	for i in _buttons.size():
		var b: Button = _buttons[i]
		if is_instance_valid(b) and (b.is_hovered() or (UiNav.shown and UiNav.cursor == b)):
			h = i
	_set_hover(h)


# --- barre : relancer, bannir, garder, passer ------------------------------------------------------------------------------
func _keepable(c: Dictionary) -> bool:
	var t := String(c.get("type", ""))
	return Run.locks_used < Cards.LOCKS_PER_RUN and SurvivorCards.FAMILY.has(t) and not t in SurvivorCards.FALLBACK \
		and not Run.kept.any(func(k): return String(k.type) == t and str(k.id) == str(c.id))


func eligible(i: int) -> bool:
	if i < 0 or i >= _cards.size():
		return false
	if aim == "ban":
		return SurvivorCards.can_ban(_cards[i])
	if aim == "keep":
		return _keepable(_cards[i])
	return true


func _refresh_reroll() -> void:
	if ban_button == null:
		return
	var left := _rerolls_left()
	_reroll.visible = _reroll_fn.is_valid()
	_reroll.text = "Relancer · %d" % left
	_reroll.disabled = left <= 0
	_reroll.tooltip_text = "Trois nouvelles cartes à la place de celles-ci."
	_skip.visible = SurvivorCards.can_skip(_cards)
	_skip.text = "Passer · +%d or" % SurvivorCards.skip_gold()
	_skip.tooltip_text = "Ne prends aucune carte : de l'or à la place."
	var can := _reroll_fn.is_valid()
	ban_button.visible = can
	keep_button.visible = can
	ban_button.text = ("Annuler" if aim == "ban" else "Bannir") + " · %d" % SurvivorCards.bans_left()
	keep_button.text = ("Annuler" if aim == "keep" else "Garder") + " · %d" % maxi(0, Cards.LOCKS_PER_RUN - Run.locks_used)
	ban_button.disabled = aim != "ban" and not _cards.any(func(c): return SurvivorCards.can_ban(c))
	keep_button.disabled = aim != "keep" and not _cards.any(func(c): return _keepable(c))
	ban_button.tooltip_text = "Choisis ensuite la carte : elle ne reviendra plus de la partie (une sorte de sort, d'arme, de panoplie ou de passif)."
	keep_button.tooltip_text = "Choisis ensuite la carte : elle revient telle quelle au prochain choix."
	for b in [_reroll, ban_button, keep_button, _skip]:
		b.queue_redraw()


## Bannir… / Garder… : mode visée (même bouton, B ou Échap : annuler).
func toggle_aim(mode: String) -> void:
	if not _root.visible or not _reroll_fn.is_valid():
		return
	if aim == mode:
		aim = ""
	else:
		var btn := ban_button if mode == "ban" else keep_button
		if btn.disabled:
			UiFeel.deny(btn)
			return
		aim = mode
		Sfx.ui("ui_tab", -12.0, 1.1)
	_refresh_reroll()
	_apply_aim()


func _apply_aim() -> void:
	for i in _buttons.size():
		var b: Button = _buttons[i]
		if is_instance_valid(b):
			b.modulate = Color.WHITE if aim == "" or eligible(i) else Color(0.55, 0.53, 0.62)
			b.queue_redraw()
	_hint()


func _hint() -> void:
	match aim:
		"ban":
			aim_hint.text = "Bannir : choisis la carte · %s pour annuler" % ("B" if Gamepad.active else "Échap")
		"keep":
			aim_hint.text = "Garder : choisis la carte · %s pour annuler" % ("B" if Gamepad.active else "Échap")
		_:
			aim_hint.text = "Cartes complètes : relâche Maj" if detail and not Gamepad.active else ("Cartes complètes : RB" if detail else "")


## Contour lagon des cartes éligibles en mode visée ; « Gardée » sur une carte gardée.
func _draw_card_extra(b: Button, i: int) -> void:
	if aim != "" and eligible(i):
		var sb := StyleBoxFlat.new()
		sb.draw_center = false
		sb.border_color = UiTheme.color("bonbon.lagon.fonce")
		sb.set_border_width_all(4)
		sb.set_corner_radius_all(20)
		sb.anti_aliasing = true
		b.draw_style_box(sb, Rect2(Vector2(-3, -3), Vector2(b.size.x + 6.0, b.size.y - 7.0 + 6.0)))  # (la face, sans l'ombre dure)


func _choose(i: int) -> void:
	if aim != "":
		if i < 0 or i >= _cards.size():
			return
		if not eligible(i):
			UiFeel.deny(_buttons[i])
			return
		var mode := aim
		aim = ""
		if mode == "ban":
			_ban(i)
		elif SurvivorCards.keep(_cards[i]):
			_show_cards(_cards)
			_opened_at -= CONFIRM_DELAY_MS
			_row.modulate.a = 1.0
		Sfx.ui("confirm", -8.0, 0.85)
		return
	if i >= 0 and i < _buttons.size() and Time.get_ticks_msec() - _opened_at >= CONFIRM_DELAY_MS and is_instance_valid(_buttons[i]):
		var b: Button = _buttons[i]
		UiFeel.sparkle(b.get_global_transform_with_canvas() * (b.size * 0.5), 4, ["soleil", "papier", "lagon", "fraise"], b.size.x * 0.4)
	detail = false
	super._choose(i)


func _input(event: InputEvent) -> void:
	if not _root.visible:
		if not _queue.is_empty() and event.is_action_pressed("objectives") and not get_tree().paused:
			open_held()  # (lot SVX-4) choix regroupés : on les ouvre quand on veut
			get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and (event as InputEventKey).keycode == KEY_SHIFT and not event.is_echo():
		set_detail(event.pressed)
		return
	if not (event is InputEventJoypadButton and event.pressed):
		return
	match (event as InputEventJoypadButton).button_index:
		JOY_BUTTON_X:
			if _reroll.visible and not _reroll.disabled:
				_do_reroll()
		JOY_BUTTON_Y:
			toggle_aim("ban")
		JOY_BUTTON_LEFT_SHOULDER:
			toggle_aim("keep")
		JOY_BUTTON_B:
			if aim != "":
				toggle_aim(aim)
			elif _skip.visible:
				_do_skip()
		JOY_BUTTON_RIGHT_SHOULDER:
			set_detail(not detail)
		_:
			return
	get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if not _root.visible or not event is InputEventKey or not event.pressed or event.echo:
		return
	match (event as InputEventKey).physical_keycode:
		KEY_R:
			if _reroll.visible and not _reroll.disabled:
				_do_reroll()
		KEY_F:
			toggle_aim("ban")
		KEY_C:
			toggle_aim("keep")
		KEY_P:
			if _skip.visible:
				_do_skip()
		KEY_ESCAPE:
			if aim == "":
				return
			toggle_aim(aim)
		_:
			super._unhandled_input(event)
			return
	get_viewport().set_input_as_handled()


# --- bandeau de la carte ------------------------------------------------------------------------------------------------------
## Bandeau de rareté (deux tons nets, BIBLE § 5) : pastille de la touche, ce qu'est la carte, étiquette de famille inclinée.
class Band extends Control:
	var picker: SurvivorPicker
	var card: Dictionary
	var idx := 0
	var tones: Array

	func _init(p: SurvivorPicker, c: Dictionary, i: int, t: Array) -> void:
		picker = p
		card = c
		idx = i
		tones = t
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var ink := UiTheme.color("encre.700")
		var r := Rect2(3, 3, size.x - 6, SurvivorPicker.BAND_H - 3)
		var sb := StyleBoxFlat.new()
		sb.bg_color = tones[1]
		sb.corner_radius_top_left = 15
		sb.corner_radius_top_right = 15
		sb.anti_aliasing = true
		draw_style_box(sb, r)
		var hl := sb.duplicate() as StyleBoxFlat
		hl.bg_color = tones[0]
		draw_style_box(hl, Rect2(r.position, Vector2(r.size.x, 13)))
		draw_rect(Rect2(r.position.x, r.end.y - 3.0, r.size.x, 3.0), ink)
		# touche du choix
		var c := Vector2(24, 23)
		draw_circle(c, 15.5, ink)
		draw_circle(c, 13.0, UiTheme.color("papier.100"))
		SurvivorHud.ink_text(self, UiTheme.title_font(), str(idx + 1), c.x, c.y + 7.0, 17, ink)
		# étiquette de famille (ou « GARDÉE »), inclinée −4°
		var kept := Run.kept.any(func(k): return String(k.type) == String(card.get("type", "")) and str(k.id) == str(card.get("id", "")))
		var tag := "GARDÉE" if kept else SurvivorCardView.family_label(card)
		var font := UiTheme.bold_font()
		var tw := font.get_string_size(tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x + 16.0
		var tr := Rect2(size.x - tw - 12.0, 9.0, tw, 24.0)
		draw_set_transform(tr.get_center(), deg_to_rad(-4.0), Vector2.ONE)
		var local := Rect2(-tr.size * 0.5, tr.size)
		SurvivorHud.round_rect(self, Rect2(local.position + Vector2(0, 2), local.size), ink, 8)
		SurvivorHud.round_rect(self, local, UiTheme.color("bonbon.pomme.base") if kept else ink, 8, 2, ink)
		SurvivorHud.ink_text(self, font, tag, 0.0, 5.0, 12, Color.WHITE, 3 if kept else 0)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		# forme de la rareté (lot SVX-4, accessibilité : jamais la couleur seule), puis ce qu'est la carte (blanc contouré
		# d'encre), coupé avant l'étiquette
		var rank := SurvivorCardView.shape_rank(card)
		var x0 := 46.0
		if rank >= 0:
			SurvivorCardView.draw_shape(self, Vector2(54.0, 24.0), 6.0, rank)
			x0 = 66.0
		var text := SurvivorCardView.band_text(card)
		var room := tr.position.x - x0 - 6.0
		while font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x > room and text.length() > 4:
			text = text.left(text.length() - 2) + "…"
		SurvivorHud.ink_text(self, font, text, x0, 29.0, 15, Color.WHITE, 5, -1)


# --- panneau « Ton équipement » -------------------------------------------------------------------------------------------------
class EquipPanel extends PanelContainer:
	const CASE := 46.0
	var picker: SurvivorPicker
	var grid: MiniGrid
	var stats: VBoxContainer
	var sets: VBoxContainer
	var foot: Label
	var caption: Label

	func _init(p: SurvivorPicker) -> void:
		picker = p
		size_flags_vertical = Control.SIZE_SHRINK_CENTER
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_theme_stylebox_override("panel", UiTheme.sticker("nuit", {"shadow": 7, "radius": 18, "gloss": false, "cel_top": 0.0, "cel_bottom": 0.0, "pad": Vector2(16, 12)}))
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 6)
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(v)
		var t := Label.new()
		t.text = "Ton équipement"
		UiTheme.title(t, 20, UiTheme.color("papier.100"))
		v.add_child(t)
		grid = MiniGrid.new()
		v.add_child(grid)
		var h := _head(v, "Héros")
		caption = Label.new()
		caption.add_theme_font_size_override("font_size", UiTheme.MIN_TEXT - 1)
		caption.add_theme_color_override("font_color", UiTheme.color("encre.100"))
		caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		h.add_child(caption)
		stats = VBoxContainer.new()
		stats.add_theme_constant_override("separation", 1)
		v.add_child(stats)
		_head(v, "Panoplies")
		sets = VBoxContainer.new()
		sets.add_theme_constant_override("separation", 1)
		v.add_child(sets)
		foot = _line(v, "", UiTheme.color("encre.100"))
		foot.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	func _head(v: Control, text: String) -> HBoxContainer:
		var h := HBoxContainer.new()
		v.add_child(h)
		var l := Label.new()
		l.text = text
		l.add_theme_font_override("font", UiTheme.bold_font())
		l.add_theme_font_size_override("font_size", 15)
		l.add_theme_color_override("font_color", UiTheme.color("bonbon.soleil.clair"))
		h.add_child(l)
		return h

	func _line(v: Control, text: String, col: Color) -> Label:
		var l := Label.new()
		l.text = text
		l.add_theme_font_override("font", UiTheme.label_font())
		l.add_theme_font_size_override("font_size", UiTheme.MIN_TEXT)
		l.add_theme_color_override("font_color", col)
		l.custom_minimum_size = Vector2(60, 0)
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(l)
		return l

	## Le panneau pour la carte survolée [param i] (-1 : aucune).
	func refresh(i: int) -> void:
		var card: Dictionary = picker._cards[i] if i >= 0 and i < picker._cards.size() else {}
		var t := String(card.get("type", ""))
		grid.target = String(card.get("slot", "")) if t in ["sv_piece", "sv_weapon", "sv_piece_up", "sv_weapon_up"] else ""
		var small := picker.card_cap() < 440.0  # (petit écran : le panneau ne dépasse pas les cartes)
		grid.cs = 36.0 if small else CASE
		grid.custom_minimum_size = Vector2(custom_minimum_size.x - 32.0, 3.0 * grid.cs + 12.0)
		grid.queue_redraw()
		for ch in stats.get_children():
			ch.queue_free()
		var p := picker.get_tree().get_first_node_in_group("player") as Player if picker.is_inside_tree() else null
		var rows := SurvivorCardView.hero_preview(card, p)
		caption.text = "si tu la prends" if rows.any(func(r): return String(r[2]) != "") else ""
		var gain := UiTheme.color("texte.gain-sur-encre")
		for r in rows:
			var h := HBoxContainer.new()
			stats.add_child(h)
			var n := _line(h, String(r[0]), UiTheme.color("encre.100"))
			n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var changed := String(r[2]) != ""
			var val := _line(h, ("%s → %s ▲" % [r[1], r[2]]) if changed else String(r[1]), gain if changed else UiTheme.color("papier.100"))
			val.add_theme_font_override("font", UiTheme.number_font())
			val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		if rows.is_empty():
			_line(stats, "—", UiTheme.color("encre.100"))
		for ch in sets.get_children():
			ch.queue_free()
		var counts := Items.set_counts(Profile.equipped)
		var card_set := String(card.get("item", {}).get("set", "")) if t in ["sv_piece", "sv_weapon"] else ""
		var shown := 0
		var max_lines := 2 if small else 4
		var ids: Array = counts.keys().filter(func(s): return String(s) in SurvivorPool.sets())
		ids.sort_custom(func(a, b): return (String(a) == card_set) or (String(b) != card_set and int(counts[a]) > int(counts[b])))
		for sid in ids:
			if shown >= max_lines:
				break
			var n := int(counts[sid]) + (1 if String(sid) == card_set else 0)
			var nxt: Array = Items.set_tiers(String(sid)).filter(func(x): return int(x) > n)
			var l := _line(sets, "◆ %s %d / 5%s" % [SurvivorPool.panoply_name(String(sid)), n, (" · bonus à %d" % int(nxt[0])) if not nxt.is_empty() else " · complète"],
				UiTheme.color("bonbon.pomme.clair") if String(sid) == card_set else UiTheme.color("papier.100"))
			l.clip_text = true
			l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			shown += 1
		if card_set != "" and not counts.has(card_set) and card_set in SurvivorPool.sets() and shown < max_lines:
			_line(sets, "◇ %s 1 / 5 · bonus à 2" % SurvivorPool.panoply_name(card_set), UiTheme.color("bonbon.pomme.clair")).clip_text = true
			shown += 1
		if shown == 0:
			_line(sets, "Aucune : 2 pièces d'une panoplie donnent un bonus", UiTheme.color("encre.100")).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var n_sp := Run.all_skills().size()
		var sp := "Sorts %d / %d" % [n_sp, Survivor.SPELL_MAX] if not t in ["skill", "chain"] else "Sorts %d → %d / %d" % [n_sp, n_sp + 1, Survivor.SPELL_MAX]
		var paths := SurvivorCardView.evo_paths()
		var ready := paths.filter(func(e): return (e.missing as Array).is_empty()).size()
		foot.text = sp + ("  ·  Évolution%s prête%s : %d" % ["s" if ready > 1 else "", "s" if ready > 1 else "", ready] if ready > 0 else
			("  ·  Évolutions en route : %d" % paths.size() if not paths.is_empty() else ""))


## Les 9 cases (arme + 8) ; la case visée par la carte survolée en pointillés lagon.
class MiniGrid extends Control:
	const ORDER := ["weapon", "head", "chest", "legs", "gloves", "boots", "back", "necklace", "ring"]
	var target := ""
	var cs := 46.0  # côté d'une case

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var ink := UiTheme.color("encre.900")
		var gap := (size.x - 3.0 * cs) / 2.0
		for i in ORDER.size():
			var slot := String(ORDER[i])
			var r := Rect2((i % 3) * (cs + gap), (i / 3) * (cs + 6.0), cs, cs)
			var it: Dictionary = Profile.equipped.get(slot, {})
			if it.is_empty():
				# case vide : tramée (BIBLE § 6), jamais un nom coupé
				SurvivorHud.round_rect(self, r, UiTheme.color("encre.700"), 10, 2, UiTheme.color("encre.300"))
				for yy in range(int(r.position.y) + 8, int(r.end.y) - 4, 8):
					for xx in range(int(r.position.x) + 8, int(r.end.x) - 4, 8):
						draw_circle(Vector2(xx, yy), 1.2, Color(1, 1, 1, 0.2))
			else:
				var col := Items.color_of(it)
				SurvivorHud.round_rect(self, r, col.darkened(0.15), 10, 2, ink)
				var tex := UiTheme.texture(String(it.get("icon", "")))
				if tex:
					draw_texture_rect(tex, r.grow(-4.0), false)
				var up := int(it.get("upgrade", 0))
				if up > 0:
					var pr := Rect2(r.position + Vector2(-2, -3), Vector2(24 if up >= 10 else 18, 15))
					SurvivorHud.round_rect(self, pr, ink, 5)
					draw_string(UiTheme.number_font(), pr.position + Vector2(3, 12), "+%d" % up, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, UiTheme.color("bonbon.soleil.base"))
			if slot == target:
				_dashed(r.grow(4.0), UiTheme.color("bonbon.lagon.clair"))

	func _dashed(r: Rect2, c: Color) -> void:
		var pts := [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y), r.position]
		for k in 4:
			var a: Vector2 = pts[k]
			var b: Vector2 = pts[k + 1]
			var n := int(a.distance_to(b) / 8.0)
			for s in n:
				if s % 2 == 0:
					draw_line(a.lerp(b, float(s) / n), a.lerp(b, float(s + 1) / n), c, 3.0)
