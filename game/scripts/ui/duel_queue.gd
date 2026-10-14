class_name DuelQueue
extends CanvasLayer
## File d'attente du Duel (idée du joueur, façon matchmaking de LoL) : recherche (temps écoulé), match trouvé
## à accepter (10 s), draft de 60 s (classe, 12 sorts, maîtrise, certificats, équipement : les points ✘ du duel se
## règlent ici), puis récapitulatif de 10 s des deux héros pendant que la partie se précharge (carte, effets des
## deux kits), et enfin l'arène. L'adversaire est une IA (celle choisie au lobby) qui accepte et valide comme un
## joueur ; le même déroulé servira à un vrai adversaire en ligne.
## Chaque délai est multiplié par [member speed] (tests : 100).

enum Phase { SEARCH, FOUND, DRAFT, RECAP, DONE }

const SEARCH_RANGE := Vector2(3.0, 9.0)
const ACCEPT_TIME := 10.0
const DRAFT_TIME := 60.0
const RECAP_TIME := 10.0
const RUN_SCENE := "res://scenes/world.tscn"

static var speed := 1.0

signal cancelled(reason: String)
signal launched

var title := "Duel"
var subtitle := ""
var opp_class := "warrior"
var opp_name := ""
var level := 10
var diff := 1
var launch: Callable  # lance la partie (Duel.start + changement de scène)
var open_hero: Callable  # func(section: String) : ouvre l'écran Héros (draft)
var phase := Phase.SEARCH
var me_accepted := false
var opp_accepted := false
var me_locked := false
var opp_locked := false

var _t := 0.0
var _search_total := 5.0
var _opp_accept_at := 2.0
var _opp_lock_at := 30.0
var _body: VBoxContainer
var _panel: PanelContainer
var _timer_label: Label
var _status_me: Label
var _status_opp: Label
var _bar: ProgressBar
var _validate: Button
var _req_box: VBoxContainer
var _spell_box: VBoxContainer
var _hero_open := false
var _pre_total := 1
var _pre_done := 0
var _fx_queue: Array = []
var _scene_ready := false


## Ouvre la file par-dessus [param host].
static func open(host: Node, p_title: String, p_sub: String, p_opp_class: String, p_level: int, p_diff: int, p_launch: Callable, p_open_hero := Callable()) -> DuelQueue:
	var q := DuelQueue.new()
	q.title = p_title
	q.subtitle = p_sub
	q.opp_class = p_opp_class
	q.opp_name = String(GameData.class_data(p_opp_class).get("name_fr", p_opp_class))
	q.level = p_level
	q.diff = p_diff
	q.launch = p_launch
	q.open_hero = p_open_hero
	host.get_tree().root.add_child.call_deferred(q)
	return q


func _ready() -> void:
	layer = 70
	process_mode = Node.PROCESS_MODE_ALWAYS
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.01, 0.05, 0.86)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", UiTheme.flat_box(Color(0.05, 0.04, 0.1, 0.98), UiTheme.GOLD, 2, 14))
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.custom_minimum_size = Vector2(1060, 640)
	_panel.position = Vector2(-530, -320)
	add_child(_panel)
	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", 12)
	_panel.add_child(_body)
	_search_total = randf_range(SEARCH_RANGE.x, SEARCH_RANGE.y)
	_opp_accept_at = randf_range(1.0, 4.0)
	_opp_lock_at = randf_range(18.0, 48.0)
	_enter(Phase.SEARCH)


# --- phases ------------------------------------------------------------------------------------
func _enter(p: Phase) -> void:
	phase = p
	_t = 0.0
	for c in _body.get_children():
		c.queue_free()
	_timer_label = null
	_bar = null
	match p:
		Phase.SEARCH:
			_build_search()
		Phase.FOUND:
			_build_found()
		Phase.DRAFT:
			_build_draft()
		Phase.RECAP:
			_build_recap()


func _process(delta: float) -> void:
	if phase == Phase.DONE:
		return
	_t += delta * speed  # (le décompte du draft continue pendant que l'écran Héros est ouvert)
	match phase:
		Phase.SEARCH:
			_timer_label.text = _clock(_t)
			if _t >= _search_total:
				_enter(Phase.FOUND)
		Phase.FOUND:
			var left := ACCEPT_TIME - _t
			_bar.value = maxf(left, 0.0)
			_timer_label.text = "%d" % ceili(maxf(left, 0.0))
			if not opp_accepted and _t >= _opp_accept_at:
				opp_accepted = true
				_status_opp.text = "Adversaire : ✔ accepté"
				_status_opp.add_theme_color_override("font_color", UiTheme.BUFF)
			if me_accepted and opp_accepted:
				_enter(Phase.DRAFT)
			elif left <= 0.0:
				_finish("Match non accepté : tu quittes la file.")
		Phase.DRAFT:
			var left := DRAFT_TIME - _t
			_bar.value = maxf(left, 0.0)
			_timer_label.text = "%d" % ceili(maxf(left, 0.0))
			_timer_label.add_theme_color_override("font_color", Color(1.0, 0.45, 0.4) if left < 10.0 else UiTheme.GOLD)
			if not opp_locked and _t >= _opp_lock_at:
				opp_locked = true
				_update_opp_status()
			if me_locked and opp_locked:
				_enter(Phase.RECAP)
			elif left <= 0.0:
				if Duel.is_ready(Profile.selected_class):
					lock_in()
				else:
					_finish("Draft incomplet : il restait des points à régler, le match est annulé.")
		Phase.RECAP:
			_preload_step()
			var left := RECAP_TIME - _t
			_timer_label.text = "La partie commence dans %d s" % ceili(maxf(left, 0.0))
			_bar.value = float(_pre_done) / float(maxi(_pre_total, 1))
			if left <= 0.0 and _scene_ready and _fx_queue.is_empty():
				_go()


func _unhandled_input(event: InputEvent) -> void:
	if phase == Phase.SEARCH and (event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause")):
		get_viewport().set_input_as_handled()
		_finish("Recherche annulée.")


func _finish(reason: String) -> void:
	if phase == Phase.DONE:
		return
	phase = Phase.DONE
	cancelled.emit(reason)
	queue_free()


func _go() -> void:
	if phase == Phase.DONE:
		return
	phase = Phase.DONE
	launched.emit()
	if launch.is_valid():
		launch.call()
	queue_free()


static func _clock(t: float) -> String:
	return "%d:%02d" % [int(t) / 60, int(t) % 60]


# --- 1. recherche ------------------------------------------------------------------------------
func _head(text: String, sub := "") -> void:
	var t := Hud._label(_body, text, 30, UiTheme.GOLD)
	t.add_theme_font_override("font", UiTheme.title_font())
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if sub != "":
		var s := Hud._label(_body, sub, 15, UiTheme.MUTED)
		s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


func _build_search() -> void:
	_head(title, subtitle)
	var sp := Control.new()
	sp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body.add_child(sp)
	var l := Hud._label(_body, "Recherche d'un adversaire…", 24, Color.WHITE)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_timer_label = Hud._label(_body, "0:00", 64, UiTheme.GOLD)
	_timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var est := Hud._label(_body, "Temps de recherche · estimé : %s" % _clock(_search_total), 14, UiTheme.MUTED)
	est.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var sp2 := Control.new()
	sp2.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body.add_child(sp2)
	var c := CenterContainer.new()
	_body.add_child(c)
	var cancel := MenuWidgets.glass_button("Annuler la recherche", 18, Vector2(300, 48))
	cancel.pressed.connect(func(): _finish("Recherche annulée."))
	c.add_child(cancel)


# --- 2. match trouvé ---------------------------------------------------------------------------
func _build_found() -> void:
	_head("MATCH TROUVÉ", subtitle)
	var sp := Control.new()
	sp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body.add_child(sp)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 40)
	_body.add_child(row)
	_hero_card(row, Profile.selected_class, "Toi", Color(0.6, 0.8, 1.0))
	var vs := Hud._label(row, "VS", 40, UiTheme.GOLD)
	vs.add_theme_font_override("font", UiTheme.title_font())
	_hero_card(row, opp_class, opp_name, Color(1.0, 0.6, 0.55))
	_timer_label = Hud._label(_body, "10", 40, Color.WHITE)
	_timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_bar = ProgressBar.new()
	_bar.max_value = ACCEPT_TIME
	_bar.value = ACCEPT_TIME
	_bar.show_percentage = false
	_bar.custom_minimum_size = Vector2(0, 16)
	_bar.add_theme_stylebox_override("fill", UiTheme.flat_box(Color(0.9, 0.7, 0.2), Color(1, 0.85, 0.4), 1, 6, false))
	_bar.add_theme_stylebox_override("background", UiTheme.flat_box(Color(0.06, 0.05, 0.1), UiTheme.GOLD_DIM, 1, 6, false))
	_body.add_child(_bar)
	var st := HBoxContainer.new()
	st.alignment = BoxContainer.ALIGNMENT_CENTER
	st.add_theme_constant_override("separation", 60)
	_body.add_child(st)
	_status_me = Hud._label(st, "Toi : en attente", 16, UiTheme.MUTED)
	_status_opp = Hud._label(st, "Adversaire : en attente", 16, UiTheme.MUTED)
	var sp2 := Control.new()
	sp2.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body.add_child(sp2)
	var c := HBoxContainer.new()
	c.alignment = BoxContainer.ALIGNMENT_CENTER
	c.add_theme_constant_override("separation", 20)
	_body.add_child(c)
	var ok := MenuWidgets.gold_button("ACCEPTER", 26, Vector2(340, 64))
	ok.pressed.connect(accept)
	c.add_child(ok)
	var no := MenuWidgets.glass_button("Refuser", 18, Vector2(180, 64))
	no.pressed.connect(func(): _finish("Match refusé."))
	c.add_child(no)


## Accepte le match (bouton « Accepter »).
func accept() -> void:
	if phase != Phase.FOUND or me_accepted:
		return
	me_accepted = true
	_status_me.text = "Toi : ✔ accepté"
	_status_me.add_theme_color_override("font_color", UiTheme.BUFF)


func _hero_card(parent: Control, cid: String, who: String, col: Color) -> void:
	var cd := GameData.class_data(cid)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	parent.add_child(v)
	var ic := TextureRect.new()
	ic.texture = UiTheme.texture(String(cd.get("icon", "")))
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ic.custom_minimum_size = Vector2(96, 96)
	v.add_child(ic)
	var n := Hud._label(v, String(cd.get("name_fr", cid)), 20, col)
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var w := Hud._label(v, who, 14, UiTheme.MUTED)
	w.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


# --- 3. draft ----------------------------------------------------------------------------------
func _build_draft() -> void:
	_head("Draft : prépare ton héros", "%s · niveau %d" % [subtitle, level])
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 16)
	_body.add_child(top)
	_timer_label = Hud._label(top, "60", 40, UiTheme.GOLD)
	_timer_label.custom_minimum_size = Vector2(70, 0)
	_bar = ProgressBar.new()
	_bar.max_value = DRAFT_TIME
	_bar.value = DRAFT_TIME
	_bar.show_percentage = false
	_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_bar.custom_minimum_size = Vector2(0, 16)
	_bar.add_theme_stylebox_override("fill", UiTheme.flat_box(Color(0.9, 0.7, 0.2), Color(1, 0.85, 0.4), 1, 6, false))
	_bar.add_theme_stylebox_override("background", UiTheme.flat_box(Color(0.06, 0.05, 0.1), UiTheme.GOLD_DIM, 1, 6, false))
	top.add_child(_bar)
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 16)
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body.add_child(cols)
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 8)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(left)
	var cname := String(GameData.class_data(Profile.selected_class).get("name_fr", Profile.selected_class))
	var cr := HBoxContainer.new()
	cr.add_theme_constant_override("separation", 10)
	left.add_child(cr)
	Hud._label(cr, "Classe : %s" % cname, 18, Color(0.6, 0.8, 1.0))
	var change := MenuWidgets.glass_button("Changer de classe", 14, Vector2(170, 34))
	change.pressed.connect(func():
		var p := ClassPicker.open(self, Profile.selected_class, false)
		p.picked.connect(func(cid):
			if cid != Profile.selected_class:
				Profile.selected_class = cid
				Profile.save_profile()
				_enter_draft_again()))
	cr.add_child(change)
	_req_box = VBoxContainer.new()
	_req_box.add_theme_constant_override("separation", 4)
	left.add_child(_req_box)
	_spell_box = VBoxContainer.new()
	left.add_child(_spell_box)
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 8)
	right.custom_minimum_size = Vector2(300, 0)
	cols.add_child(right)
	Hud._label(right, "Adversaire", 18, Color(1.0, 0.6, 0.55))
	_hero_card(right, opp_class, "%s · niveau %d" % [opp_name, level], Color(1.0, 0.6, 0.55))
	_status_opp = Hud._label(right, "", 16, UiTheme.MUTED)
	_update_opp_status()
	var sp := Control.new()
	sp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(sp)
	_validate = MenuWidgets.gold_button("Valider mon choix", 22, Vector2(0, 58))
	_validate.pressed.connect(lock_in)
	right.add_child(_validate)
	_refresh_draft()


func _enter_draft_again() -> void:
	var t := _t
	_enter(Phase.DRAFT)
	_t = t  # changer de classe ne remet pas le décompte à 60 s


func _update_opp_status() -> void:
	if _status_opp == null:
		return
	_status_opp.text = "✔ a validé son choix" if opp_locked else "…prépare son héros"
	_status_opp.add_theme_color_override("font_color", UiTheme.BUFF if opp_locked else UiTheme.MUTED)


## Points à régler (✘) et grille des 12 sorts du preset actif.
func _refresh_draft() -> void:
	if _req_box == null:
		return
	for c in _req_box.get_children():
		c.queue_free()
	for c in _spell_box.get_children():
		c.queue_free()
	var cid := Profile.selected_class
	for r in Duel.requirements(cid):
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 8)
		_req_box.add_child(h)
		var mark := Hud._label(h, "✔" if r.ok else "✘", 18, UiTheme.BUFF if r.ok else Color(1.0, 0.45, 0.4))
		mark.custom_minimum_size = Vector2(22, 0)
		var l := Hud._label(h, "%s : %s" % [r.label, r.hint], 13, UiTheme.TEXT)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if not r.ok and open_hero.is_valid() and String(r.section) != "grimoire":
			var sec := String(r.section)
			var fix := MenuWidgets.glass_button("Régler", 13, Vector2(80, 30))
			fix.pressed.connect(func(): _open_section(sec))
			h.add_child(fix)
	# les 12 sorts : le preset actif de la classe, modifiable ici (enregistré sous « Draft de duel »)
	var preset := SpellPresets.active(cid)
	var grid: Array = Duel.grid12([])
	var cols: Array = preset.get("cols", [])
	for c in mini(cols.size(), 4):
		for r in range(mini((cols[c] as Array).size(), 3)):
			grid[c * 3 + r] = int(cols[c][r])
	DuelPrep.spell_grid(_spell_box, cid, grid, func():
		var nc: Array = []
		for c in 4:
			nc.append([int(grid[c * 3]), int(grid[c * 3 + 1]), int(grid[c * 3 + 2])])
		SpellPresets.store(cid, "Draft de duel", nc)
		_refresh_req_only())
	if _validate:
		_validate.disabled = me_locked or not Duel.is_ready(cid)
		_validate.text = "Choix validé : en attente…" if me_locked else "Valider mon choix"


func _refresh_req_only() -> void:
	# seules les conditions sont reconstruites (la grille de sorts garde la main)
	for c in _req_box.get_children():
		c.queue_free()
	var cid := Profile.selected_class
	for r in Duel.requirements(cid):
		var h := HBoxContainer.new()
		_req_box.add_child(h)
		var mark := Hud._label(h, "✔" if r.ok else "✘", 18, UiTheme.BUFF if r.ok else Color(1.0, 0.45, 0.4))
		mark.custom_minimum_size = Vector2(22, 0)
		Hud._label(h, "%s : %s" % [r.label, r.hint], 13, UiTheme.TEXT)
	if _validate:
		_validate.disabled = me_locked or not Duel.is_ready(cid)


func _open_section(section: String) -> void:
	_hero_open = true
	visible = false
	open_hero.call(section, func():
		_hero_open = false
		visible = true
		_refresh_draft())


## Valide le choix (bouton « Valider », ou automatiquement à 0 s si tout est réglé).
func lock_in() -> void:
	if phase != Phase.DRAFT or me_locked or not Duel.is_ready(Profile.selected_class):
		return
	me_locked = true
	if _validate:
		_validate.disabled = true
		_validate.text = "Choix validé : en attente…"


# --- 4. récapitulatif et préchargement ------------------------------------------------------------
func _build_recap() -> void:
	_head("Récapitulatif", "%s · niveau %d" % [subtitle, level])
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 20)
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body.add_child(cols)
	var mine := _kit_of_player()
	var theirs := _kit_of_rival()
	_recap_column(cols, "Toi", Profile.selected_class, mine, Color(0.6, 0.8, 1.0))
	_recap_column(cols, "Adversaire", opp_class, theirs, Color(1.0, 0.6, 0.55))
	_timer_label = Hud._label(_body, "", 20, Color.WHITE)
	_timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_bar = ProgressBar.new()
	_bar.max_value = 1.0
	_bar.value = 0.0
	_bar.show_percentage = false
	_bar.custom_minimum_size = Vector2(0, 14)
	_bar.add_theme_stylebox_override("fill", UiTheme.flat_box(Color(0.4, 0.8, 0.5), Color(0.6, 1.0, 0.7), 1, 6, false))
	_bar.add_theme_stylebox_override("background", UiTheme.flat_box(Color(0.06, 0.05, 0.1), UiTheme.GOLD_DIM, 1, 6, false))
	_body.add_child(_bar)
	var pl := Hud._label(_body, "Chargement de l'arène et des effets des deux héros…", 13, UiTheme.MUTED)
	pl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var c := CenterContainer.new()
	_body.add_child(c)
	var ready := MenuWidgets.gold_button("Prêt", 20, Vector2(240, 46))
	ready.tooltip_text = "Lance la partie dès que le chargement est terminé."
	ready.pressed.connect(func(): _t = maxf(_t, RECAP_TIME))
	c.add_child(ready)
	_start_preload(mine + theirs)


func _skill_of(cid: String, id: int) -> Dictionary:
	for s in GameData.class_data(cid).get("skills", []):
		if int(s.id) == id:
			return s
	return {}


## Sorts du preset actif du joueur (jusqu'à 12), dans l'ordre des cases.
func _kit_of_player() -> Array:
	var out: Array = []
	var cid := Profile.selected_class
	for col in SpellPresets.active(cid).get("cols", []):
		for id in col:
			var s := _skill_of(cid, int(id))
			if int(id) != 0 and not s.is_empty():
				out.append(s)
	return out


## Sorts de l'adversaire : ceux de son kit scripté (cerveau d'IA : les 12 de son preset).
func _kit_of_rival() -> Array:
	if Duel.pilot != "":
		return []  # cerveau d'IA : il joue les 12 sorts de son preset (voir la colonne)
	Duel.rival_class = opp_class
	Duel.difficulty = diff
	var r := Duel.make_rival(level)
	var out: Array = (r._skills as Array).duplicate()
	r.free()
	return out


func _recap_column(parent: Control, who: String, cid: String, kit: Array, col: Color) -> void:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(v)
	_hero_card(v, cid, who, col)
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 6)
	flow.add_theme_constant_override("v_separation", 6)
	v.add_child(flow)
	for s in kit:
		var t := TextureRect.new()
		t.texture = UiTheme.texture(String(s.get("icon", "")))
		t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		t.custom_minimum_size = Vector2(44, 44)
		t.tooltip_text = "%s\n%s" % [s.get("name", "?"), s.get("desc", "")]
		t.mouse_filter = Control.MOUSE_FILTER_PASS
		flow.add_child(t)
	if kit.is_empty():
		Hud._label(v, "Cerveau d'IA entraîné : il joue les 12 sorts de son preset" if who == "Adversaire" and Duel.pilot != "" else "Auto-attaque de l'arme seulement", 13, UiTheme.MUTED)
	if who == "Toi" and not Duel.bare:
		Hud._label(v, "Maîtrise et certificats posés · PE %s" % GearPower.fmt(GearPower.hero_power()), 13, UiTheme.TEXT)
	elif who == "Toi":
		Hud._label(v, "À l'arme : ni pièces ni maîtrise, seulement tes sorts", 13, UiTheme.MUTED)


## Préchargement : la scène de jeu en tâche de fond, puis les effets d'Eden des sorts des deux kits, un par image.
func _start_preload(kits: Array) -> void:
	_fx_queue = []
	for s in kits:
		var fx = s.get("fx", {})
		if fx is Dictionary:
			for k in fx:
				var n := String(fx[k])
				if n != "" and not n in _fx_queue:
					_fx_queue.append(n)
	_pre_total = 1 + _fx_queue.size()
	_pre_done = 0
	_scene_ready = false
	ResourceLoader.load_threaded_request(RUN_SCENE)


func _preload_step() -> void:
	if not _scene_ready:
		var st := ResourceLoader.load_threaded_get_status(RUN_SCENE)
		if st == ResourceLoader.THREAD_LOAD_LOADED or st == ResourceLoader.THREAD_LOAD_FAILED:
			_scene_ready = true
			_pre_done += 1
	if not _fx_queue.is_empty():
		EdenFx._load(String(_fx_queue.pop_back()))
		_pre_done += 1
