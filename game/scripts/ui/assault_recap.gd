class_name AssaultRecap
extends Control
## L'Assaut, lot TAC-8 (TACTIQUE § 7.8, croquis tactique_maquettes/v2_mort_ordres.svg) : quand le joueur tombe.
##   - Carte « Éliminé ! » en haut au centre (6 s, ou [Interagir] / A) : qui (classe, rôle), avec quoi, dans le dos ou non,
##     les PV qui lui restent ; tes dégâts donnés et tes éliminations / aides de la partie.
##   - Spectateur : la caméra suit un allié debout ; [◀] / [▶] (LB / RB à la manette) changent d'allié ; le voile, les sons et
##     la mini-carte suivent le héros regardé (AssaultDirector.view_hero).
##   - Ordres [Tab] (D-pad gauche) : « Va en A », « Va en B », « Va au repère », « Tiens ta place », « Regroupez-vous »,
##     « Recule », à l'allié regardé ou à toute l'équipe (AssaultDirector.give_order) ; les alliés répondent dans la colonne de
##     droite (« Pas pour l'instant : je me bats ! »).
## Le jeu continue derrière ; rien ne met en pause. Fermé par AssaultHud à la manche suivante.

const CARD_W := 640.0
const CARD_SECS := 6.0

var h: AssaultHud
var d: AssaultDirector
var data: Dictionary = {}
var card: PanelContainer
var orders: PanelContainer
var order_buttons: Array = []  # (tests) [Button, kind]
var _bar: CenterContainer
var _bar_line: RoyaleKeyLine
var _all := true  # ordres à toute l'équipe (faux : à l'allié regardé)
var _t := 0.0
var _target_chips: Array = []


static func open(hud: AssaultHud, director: AssaultDirector) -> AssaultRecap:
	var r := AssaultRecap.new()
	r.h = hud
	r.d = director
	r.data = director.death_recap()
	r.name = "AssaultRecap"
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(r)
	return r


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_card()
	_build_bar()
	_build_orders()
	UiFeel.cue("ui_defeat", -10.0)
	if TeamMatch.watched == null or not is_instance_valid(TeamMatch.watched) or TeamMatch.watched.is_dead:
		watch_next(1)


func close() -> void:
	queue_free()


# --- carte de chute ----------------------------------------------------------------------------------------------------

## Ligne du tueur : « par Kage · Ouvreur » ; l'explosion : « Emporté par l'explosion de la Charge ».
static func headline(r: Dictionary) -> String:
	if bool(r.get("blast", false)):
		return "Emporté par l'explosion de la Charge"
	if String(r.get("name", "")) == "":
		return "Tombé"
	var role := AssaultCombat.role_name(String(r.get("role", ""))) if String(r.get("role", "")) != "" else ""
	return "par %s%s" % [String(r.name), " · " + role if role != "" else ""]


## Ligne du coup : « Lame d'ombre, dans le dos · il lui reste 410 PV ».
static func how_line(r: Dictionary) -> String:
	var parts: Array = []
	var mv := String(r.get("move", ""))
	if mv != "" or bool(r.get("back", false)):
		parts.append((mv if mv != "" else "Attaque") + (", dans le dos" if bool(r.get("back", false)) else ""))
	var hp := int(r.get("killer_hp", -1))
	if hp > 0:
		parts.append("il lui reste %s PV" % RoyaleStyle.number(hp))
	return " · ".join(parts)


func _build_card() -> void:
	card = PanelContainer.new()
	card.name = "RecapCard"
	card.add_theme_stylebox_override("panel", RoyaleStyle.paper(Vector2(24, 14)))
	card.custom_minimum_size = Vector2(CARD_W, 0)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(card)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(v)
	var t := RoyaleStyle.label(null, "Éliminé !", 36, RoyaleHudStyle.danger()[1], "title", 7)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	RoyaleStyle.tilt(v, t, -3.0)
	var who := HBoxContainer.new()
	who.add_theme_constant_override("separation", 12)
	who.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(who)
	var cid := String(data.get("cid", ""))
	if cid != "":
		var tile := PanelContainer.new()
		tile.add_theme_stylebox_override("panel", RoyaleStyle.box(RoyaleHudStyle.family_tones(cid)[1], 12, 3, Vector2(3, 3)))
		tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
		who.add_child(tile)
		var ic := TextureRect.new()
		ic.custom_minimum_size = Vector2(54, 54)
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ic.texture = h.class_icon(cid)
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tile.add_child(ic)
	var lines := VBoxContainer.new()
	lines.add_theme_constant_override("separation", 2)
	lines.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	who.add_child(lines)
	var hl := RoyaleStyle.label(lines, headline(data), 22, RoyaleStyle.INK, "bold", 0)
	hl.name = "RecapWho"
	var how := how_line(data)
	if how != "":
		var hw := RoyaleStyle.label(lines, how, 17, RoyaleStyle.INK_300, "bold", 0)
		hw.name = "RecapHow"
	var tiles := HBoxContainer.new()
	tiles.add_theme_constant_override("separation", 10)
	tiles.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(tiles)
	RoyaleStyle.tile(tiles, RoyaleStyle.number(float(data.get("dealt", 0.0))), "dégâts donnés")
	RoyaleStyle.tile(tiles, "%d / %d" % [int(data.get("kills", 0)), int(data.get("assists", 0))], "éliminations / aides")
	card.modulate.a = 0.0
	card.create_tween().tween_property(card, "modulate:a", 1.0, 0.18)


func is_card_open() -> bool:
	return card != null and is_instance_valid(card) and card.visible


func _build_bar() -> void:
	_bar = CenterContainer.new()
	_bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_bar.offset_top = -100
	_bar.offset_bottom = -40
	_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bar)
	_bar_line = RoyaleKeyLine.new()
	_bar_line.name = "SpectatorLine"
	_bar.add_child(_bar_line)


## Bandeau du spectateur : héros regardé et touches.
func bar_text() -> String:
	var w := TeamMatch.watched
	var who := "personne"
	if w != null and is_instance_valid(w) and not w.is_dead:
		var key := d.key_of(w)
		var cid := String(d.classes.get(key, ""))
		who = "%s · %s" % [String(GameData.class_data(cid).get("name_fr", cid)), AssaultCombat.role_name(d.role_of(key))]
	var prev := Settings.pad_name(JOY_BUTTON_LEFT_SHOULDER) if Gamepad.active else Settings.action_label("move_left", 1)
	var next := Settings.pad_name(JOY_BUTTON_RIGHT_SHOULDER) if Gamepad.active else Settings.action_label("move_right", 1)
	return "[%s] ◀  Tu regardes : %s  ▶ [%s]    [%s] Ordres" % [prev, who, next, Settings.action_label("objectives", 1)]


# --- ordres ------------------------------------------------------------------------------------------------------------

func _build_orders() -> void:
	orders = PanelContainer.new()
	orders.name = "OrdersCard"
	orders.add_theme_stylebox_override("panel", RoyaleStyle.paper(Vector2(18, 12)))
	orders.custom_minimum_size = Vector2(330, 0)
	orders.mouse_filter = Control.MOUSE_FILTER_STOP
	orders.visible = false
	add_child(orders)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	orders.add_child(v)
	RoyaleStyle.label(v, "Ordres à l'équipe", 22, RoyaleStyle.INK, "title", 0)
	var chips := HBoxContainer.new()
	chips.add_theme_constant_override("separation", 6)
	v.add_child(chips)
	for all in [true, false]:
		var b := Button.new()
		b.toggle_mode = true
		b.focus_mode = Control.FOCUS_ALL
		b.name = "OrdersAll" if all else "OrdersOne"
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		UiTheme.style_button(b, "papier", 15, {"selected_tone": "lagon", "pad": Vector2(8, 4)})
		var flag: bool = all
		b.pressed.connect(func():
			_all = flag
			_refresh_orders())
		chips.add_child(b)
		_target_chips.append(b)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	v.add_child(grid)
	for kind in AssaultDirector.ORDERS:
		var b := Button.new()
		b.text = String(AssaultDirector.ORDERS[kind])
		b.name = "Order_" + String(kind)
		b.focus_mode = Control.FOCUS_ALL
		b.custom_minimum_size = Vector2(146, 42)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		UiTheme.style_button(b, "lagon" if String(kind) in ["go_a", "go_b"] else "papier", 16)
		b.pressed.connect(give.bind(String(kind)))
		grid.add_child(b)
		order_buttons.append([b, String(kind)])
	var note := RoyaleStyle.label(v, "Un allié qui se bat répond « pas pour l'instant ».", 15, RoyaleStyle.INK_300, "bold", 0)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.custom_minimum_size = Vector2(290, 0)


func _refresh_orders() -> void:
	var w := TeamMatch.watched
	var watched_ally := w != null and is_instance_valid(w) and not w.is_dead and Assault.team_of(d.key_of(w)) == TeamMatch.player_team
	if not watched_ally:
		_all = true
	_target_chips[0].text = "Toute l'équipe"
	_target_chips[0].button_pressed = _all
	_target_chips[1].text = d.hero_name(d.key_of(w)) if watched_ally else "Allié regardé"
	_target_chips[1].button_pressed = not _all
	_target_chips[1].disabled = not watched_ally
	for e in order_buttons:
		if String(e[1]) == "go_ping":
			(e[0] as Button).disabled = d.ping == Vector3.INF
			(e[0] as Button).tooltip_text = "Pose d'abord un repère (clic molette)" if d.ping == Vector3.INF else ""


func toggle_orders(on := -1) -> void:
	orders.visible = (not orders.visible) if on < 0 else on == 1
	if orders.visible:
		_refresh_orders()
		if card.visible:
			card.visible = false
		UiFeel.cue("ui_open", -10.0)
		if Gamepad.active:
			(order_buttons[0][0] as Button).grab_focus()


## Donne l'ordre [param kind] (à l'allié regardé, ou à toute l'équipe) ; les réponses vont dans la colonne de droite.
func give(kind: String) -> Array:
	var keys: Array = []
	if not _all and TeamMatch.watched != null and is_instance_valid(TeamMatch.watched):
		keys = [d.key_of(TeamMatch.watched)]
	var replies := d.give_order(kind, keys)
	for r in replies:
		h.column.add_line("%s : « %s »" % [d.hero_name(String(r.key)), String(r.text)], "lagon" if bool(r.ok) else "papier")
	if replies.is_empty():
		h.column.add_line("Aucun allié ne peut le faire", "papier")
	UiFeel.cue("ui_press" if not replies.is_empty() else "ui_deny", -8.0)
	orders.visible = false
	return replies


# --- spectateur --------------------------------------------------------------------------------------------------------

## Allié suivant à regarder ([param step] +1 / -1) : la caméra le suit.
func watch_next(step: int) -> Combatant:
	var c := TeamMatch.next_watch(step)
	if c != null and d.d != null and d.d.world.rig != null:
		d.d.world.rig.target = c
	if orders.visible:
		_refresh_orders()
	return c


func _process(delta: float) -> void:
	_t += delta
	var a := get_viewport_rect().size
	var kk := h.k()
	if is_card_open():
		card.reset_size()
		card.position = Vector2(roundf((a.x - card.size.x) * 0.5), h.charge_line.position.y + (AssaultHud.LINE_H + 12.0) * kk)
		if _t > CARD_SECS:
			card.visible = false
	if orders.visible:
		orders.reset_size()
		orders.position = Vector2(24.0, roundf((a.y - orders.size.y) * 0.5))
	var w := TeamMatch.watched
	if w == null or not is_instance_valid(w) or w.is_dead:
		if not Assault.alive_keys(TeamMatch.player_team).is_empty() or Assault.phase == "planted":
			watch_next(1)
	_bar_line.set_text(bar_text())


func _input(event: InputEvent) -> void:
	if get_tree().paused:
		return
	if event.is_action_pressed("objectives"):
		get_viewport().set_input_as_handled()
		toggle_orders()
		return
	var pad := event is InputEventJoypadButton and (event as InputEventJoypadButton).pressed
	if orders.visible:
		if (pad and (event as InputEventJoypadButton).button_index == JOY_BUTTON_B) or (not pad and event.is_action_pressed("ui_cancel")):
			get_viewport().set_input_as_handled()
			toggle_orders(0)
		return
	if pad and (event as InputEventJoypadButton).button_index in [JOY_BUTTON_LEFT_SHOULDER, JOY_BUTTON_RIGHT_SHOULDER]:
		get_viewport().set_input_as_handled()
		watch_next(-1 if (event as InputEventJoypadButton).button_index == JOY_BUTTON_LEFT_SHOULDER else 1)
	elif not pad and (event.is_action_pressed("move_left") or event.is_action_pressed("move_right")):
		get_viewport().set_input_as_handled()
		watch_next(-1 if event.is_action_pressed("move_left") else 1)
	elif is_card_open() and ((pad and (event as InputEventJoypadButton).button_index == JOY_BUTTON_A) or (not pad and event.is_action_pressed("interact"))):
		get_viewport().set_input_as_handled()
		card.visible = false
