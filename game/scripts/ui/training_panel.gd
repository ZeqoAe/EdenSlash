class_name TrainingPanel
extends CanvasLayer
## Panneau de la zone d'entraînement (Training), sur le côté droit, ouvert avec F3 ou
## l'onglet « Entraînement » : héros (niveau, invincible, recharges à zéro, classe), sorts
## de la classe (au choix, avec leur rang), cartes (communes, de classe, certificats),
## ennemis (invincibles, passifs, monstre au choix, mannequin) et compteur de DPS.

const WIDTH := 430.0

var player: Player
var director: RunDirector
var _panel: PanelContainer
var _tab: Button
var _box: VBoxContainer
var _level: Label
var _dps: Label
var _skills_box: VBoxContainer
var _cards_box: VBoxContainer
var _card_search: LineEdit
var _mon_search: LineEdit
var _mon_list: ItemList
var _mon_ids: Array = []
var _count: SpinBox
var _rival_class := "warrior"
var _rival_btn: Button
var _rival_diff: OptionButton
var _msg: Label
var _tick := 0.0


func setup(p: Player, d: RunDirector) -> void:
	player = p
	director = d
	layer = 12
	_build()
	if "--attack-zone" in OS.get_cmdline_user_args():
		# test : zone des attaques au sol (sans enregistrer les paramètres du joueur)
		if not Settings.data.has("interface"):
			Settings.data["interface"] = {}
		Settings.data["interface"]["attack_zone"] = true
	if "--training-open" in OS.get_cmdline_user_args():
		# test : panneau ouvert, mannequin, 4 sorts
		await get_tree().create_timer(1.0).timeout
		for sk in Run.class_data().get("skills", []).slice(0, 4):
			if Run.skill_rank(int(sk.id)) == 0:
				Run.skills.append({"id": int(sk.id), "rank": 1})
		player.recalc_stats()
		_spawn_dummy()
		if "--training-chains" in OS.get_cmdline_user_args():
			_fill_all()
		toggle()
		for arg in OS.get_cmdline_user_args():
			if arg.begins_with("--rival="):
				for m in get_tree().get_nodes_in_group("monsters"):
					m.queue_free()
				_rival_class = arg.trim_prefix("--rival=")
				if _rival_diff and "--rival-hardcore" in OS.get_cmdline_user_args():
					_rival_diff.select(3)
				Training.hero_god = true
				spawn_rival()
		if "--training-cards" in OS.get_cmdline_user_args():
			Run.passives["wide_arc"] = 10
			Run.passive_power["wide_arc"] = 10.0
			player.recalc_stats()
			open_all_cards()


func _build() -> void:
	_tab = Button.new()
	_tab.text = "◂ Entraînement (F3)"
	_tab.focus_mode = Control.FOCUS_NONE
	_tab.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	_tab.offset_left = -190
	_tab.offset_right = -8
	_tab.offset_top = -20
	_tab.offset_bottom = 20
	_tab.pressed.connect(toggle)
	add_child(_tab)
	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", UiTheme.flat_box(Color(0.05, 0.04, 0.1, 0.93), UiTheme.GOLD_DIM, 2, 12))
	_panel.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	_panel.offset_left = -WIDTH - 12
	_panel.offset_right = -12
	_panel.offset_top = 260  # sous la mini-carte
	_panel.offset_bottom = -150
	_panel.clip_contents = true
	_panel.visible = false
	add_child(_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	_panel.add_child(v)
	var head := HBoxContainer.new()
	v.add_child(head)
	var t := Label.new()
	t.text = "Entraînement"
	UiTheme.title(t, 22)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	_button(head, "✕", toggle, 40)
	_dps = Hud._label(v, "", 14, Color(1, 0.9, 0.6))
	_msg = Hud._label(v, "", 13, UiTheme.BUFF)
	_msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_msg.custom_minimum_size = Vector2(WIDTH - 40, 0)
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(sc)
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 6)
	_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(_box)
	_build_hero()
	_build_skills()
	_build_cards()
	_build_enemies()
	_section("Quitter")
	_button(_box, "Quitter l'entraînement", func(): Training.leave(get_tree()))


func toggle() -> void:
	_panel.visible = not _panel.visible
	_tab.visible = not _panel.visible
	if _panel.visible:
		_refresh_skills()
		_refresh_cards()


func is_open() -> bool:
	return _panel.visible


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F3:
		toggle()
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	_tick -= delta
	if _tick > 0.0:
		return
	_tick = 0.25
	_dps.text = "DPS (5 s) : %d   ·   total : %d en %.1f s" % [roundi(Training.dps()), roundi(Training.total), Training.fight_time()]
	if _level:
		_level.text = "Niveau %d" % player.level


# --- éléments ---------------------------------------------------------------------------------
func _section(text: String) -> void:
	var l := Label.new()
	l.text = text
	UiTheme.title(l, 17)
	_box.add_child(l)


func _button(parent: Control, text: String, cb: Callable, w := 0.0) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(w, 32)
	b.pressed.connect(cb)
	parent.add_child(b)
	return b


func _check(text: String, on: bool, cb: Callable) -> CheckBox:
	var c := CheckBox.new()
	c.text = text
	c.button_pressed = on
	c.focus_mode = Control.FOCUS_NONE
	c.toggled.connect(cb)
	_box.add_child(c)
	return c


func _row() -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	_box.add_child(h)
	return h


func _say(t: String) -> void:
	_msg.text = t


# --- héros ------------------------------------------------------------------------------------
func _build_hero() -> void:
	_section("Héros")
	var r := _row()
	_level = Hud._label(r, "", 15, Color.WHITE)
	_level.custom_minimum_size = Vector2(90, 0)
	_button(r, "−1", func(): set_level(player.level - 1), 46)
	_button(r, "+1", func(): set_level(player.level + 1), 46)
	_button(r, "+5", func(): set_level(player.level + 5), 46)
	_button(r, "Max", func(): set_level(director.max_level()), 56)
	_check("Héros invincible", Training.hero_god, func(on): Training.hero_god = on)
	_check("Recharges à zéro", Training.no_cd, func(on): Training.no_cd = on)
	var r2 := _row()
	_button(r2, "Soigner", func():
		player.hp = player.max_hp
		player.health_changed.emit(player.hp, player.max_hp), 100)
	_button(r2, "DPS à zéro", func(): Training.reset_meter(), 0).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var cb := _button(_box, "Classe : %s ▾" % GameData.class_data(Run.class_id).get("name_fr", ""), func(): pass)
	cb.pressed.connect(func(): HeroPages.class_menu(cb, Run.class_id, func(cid):
		if cid != Run.class_id:
			Training.restart(cid, get_tree())))


## Règle le niveau du héros (cartes de niveau désactivées en entraînement).
func set_level(n: int) -> void:
	n = clampi(n, 1, maxi(director.max_level(), 1))
	player.level = n
	player.xp = 0
	Run.hero_level = n
	Run.max_level = maxi(Run.max_level, n)
	player.recalc_stats()
	player.hp = player.max_hp
	player.health_changed.emit(player.hp, player.max_hp)
	player.xp_changed.emit(0, GameData.xp_to_next(n), n)


# --- sorts ------------------------------------------------------------------------------------
func _build_skills() -> void:
	_section("Sorts : 4 cases et leurs enchaînements")
	_skills_box = VBoxContainer.new()
	_skills_box.add_theme_constant_override("separation", 3)
	_box.add_child(_skills_box)
	_refresh_skills()


func _refresh_skills() -> void:
	for c in _skills_box.get_children():
		c.queue_free()
	Hud._label(_skills_box, "Case : sort principal (touche 1 à 4). Enchaînement : après l'appui, 0,45 s de blocage (appuyer casse la chaîne), puis une barre se remplit au-dessus de la case ; rappuie avant la fin pour le sort suivant (2 par case, 12 sorts en tout).", 12, UiTheme.MUTED).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var r := HBoxContainer.new()
	r.add_theme_constant_override("separation", 6)
	_skills_box.add_child(r)
	_button(r, "Remplir les 12 emplacements", _fill_all, 0).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_button(r, "Tout retirer", func():
		Run.skills.clear()
		Run.chains.clear()
		player.recalc_stats()
		_refresh_skills(), 110)
	for s in Run.class_data().get("skills", []):
		var sid := int(s.id)
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 6)
		_skills_box.add_child(h)
		var ic := TextureRect.new()
		ic.texture = UiTheme.texture(String(s.get("icon", "")))
		ic.custom_minimum_size = Vector2(28, 28)
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		h.add_child(ic)
		var l := Hud._label(h, String(s.name), 13, Color.WHITE if Run.skill_rank(sid) > 0 else UiTheme.MUTED)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.clip_text = true
		var where := OptionButton.new()
		where.focus_mode = Control.FOCUS_NONE
		where.add_item("—")
		for i in Run.MAX_SKILLS:
			where.add_item("Case %d" % (i + 1))
		for i in Run.MAX_SKILLS:
			where.add_item("Case %d ➜ suite" % (i + 1))
		where.select(_place_index(sid))
		where.item_selected.connect(func(i): _place(sid, i))
		h.add_child(where)
		var rank := SpinBox.new()
		rank.min_value = 1
		rank.max_value = Run.MAX_RANK
		rank.value = maxi(1, Run.skill_rank(sid))
		rank.prefix = "rg"
		rank.custom_minimum_size = Vector2(80, 0)
		rank.editable = Run.skill_rank(sid) > 0
		rank.value_changed.connect(func(v):
			var e := Run.skill_entry(sid)
			if not e.is_empty():
				e.rank = int(v)
				e.erase("dmg")
				e.erase("cd")
			player.recalc_stats())
		h.add_child(rank)


## Indice du menu « où » pour le sort : 0 aucun, 1-4 case, 5-8 enchaînement de la case.
func _place_index(sid: int) -> int:
	for i in Run.skills.size():
		if int(Run.skills[i].id) == sid:
			return i + 1
	for k in Run.chains:
		for e in Run.chains[k]:
			if int(e.id) == sid:
				return Run.MAX_SKILLS + 1 + int(k)
	return 0


func _place(sid: int, idx: int) -> void:
	var rank := maxi(1, Run.skill_rank(sid))
	Run.remove_skill(sid)
	if idx >= 1 and idx <= Run.MAX_SKILLS:
		var slot := idx - 1
		if slot < Run.skills.size():
			# la case est prise : le sort en place devient un sort libre
			var old := int(Run.skills[slot].id)
			Run.skills[slot] = {"id": sid, "rank": rank}
			_say("Case %d : %s (remplace %s)." % [slot + 1, Run.skill_def(sid).name, Run.skill_def(old).name])
		else:
			Run.skills.append({"id": sid, "rank": rank})
			if Run.skills.size() - 1 != slot:
				_say("Case %d : les cases se remplissent dans l'ordre." % Run.skills.size())
	elif idx > Run.MAX_SKILLS:
		var slot := idx - Run.MAX_SKILLS - 1
		if slot >= Run.skills.size():
			_say("Mets d'abord un sort principal dans la case %d." % (slot + 1))
		elif Run.chain_of(slot).size() >= Run.MAX_CHAIN:
			_say("La case %d a déjà 2 enchaînements." % (slot + 1))
		else:
			var ch: Array = Run.chain_of(slot).duplicate()
			ch.append({"id": sid, "rank": rank})
			Run.chains[slot] = ch
	player.recalc_stats()
	_refresh_skills()


## 4 sorts principaux puis 2 enchaînements par case, dans l'ordre de la classe.
func _fill_all() -> void:
	Run.skills.clear()
	Run.chains.clear()
	var list: Array = Run.class_data().get("skills", [])
	for i in mini(list.size(), Run.MAX_SKILLS):
		Run.skills.append({"id": int(list[i].id), "rank": 1})
	var n := Run.MAX_SKILLS
	for slot in Run.skills.size():
		var ch: Array = []
		while ch.size() < Run.MAX_CHAIN and n < list.size():
			ch.append({"id": int(list[n].id), "rank": 1})
			n += 1
		if not ch.is_empty():
			Run.chains[slot] = ch
	player.recalc_stats()
	_refresh_skills()


# --- cartes -----------------------------------------------------------------------------------
func _build_cards() -> void:
	_section("Cartes")
	_button(_box, "Voir toutes les cartes (en grand, avec leurs effets)", open_all_cards)
	_card_search = LineEdit.new()
	_card_search.placeholder_text = "Chercher une carte…"
	_card_search.text_changed.connect(func(_t): _refresh_cards())
	_box.add_child(_card_search)
	var r := _row()
	_button(r, "Retirer toutes les cartes", func():
		Run.passives.clear()
		Run.passive_power.clear()
		player.recalc_stats()
		_refresh_cards(), 0).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_cards_box = VBoxContainer.new()
	_cards_box.add_theme_constant_override("separation", 2)
	_box.add_child(_cards_box)
	_refresh_cards()


## Grande fenêtre de toutes les cartes (effets en chiffres, niveau au choix).
func open_all_cards() -> void:
	var w := TrainingCards.new(player)
	w.closed.connect(_refresh_cards)
	get_parent().add_child(w)


func _all_cards() -> Array:
	return Cards.class_cards(Run.class_id) + Boons.all() + Run.certificate_pool()


func _refresh_cards() -> void:
	for c in _cards_box.get_children():
		c.queue_free()
	var q := _card_search.text.strip_edges().to_lower()
	var shown := 0
	# les cartes prises d'abord, puis les autres
	var list := _all_cards().filter(func(d): return q == "" or String(d.name).to_lower().contains(q))
	list.sort_custom(func(a, b): return int(Run.passives.has(a.id)) > int(Run.passives.has(b.id)))
	for d in list:
		if shown >= 40:
			Hud._label(_cards_box, "… affine la recherche pour voir les autres", 12, UiTheme.MUTED)
			break
		shown += 1
		var id := String(d.id)
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 4)
		_cards_box.add_child(h)
		var ic := TextureRect.new()
		ic.texture = UiTheme.texture(String(d.get("icon", Boons.ICONS.get(id, ""))))
		ic.custom_minimum_size = Vector2(24, 24)
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		h.add_child(ic)
		var n := int(Run.passives.get(id, 0))
		var mx := mini(int(d.get("max", 1)), Cards.MAX_LEVEL)
		var l := Hud._label(h, "%s%s" % [d.name, ("  [%d/%d]" % [n, mx]) if n > 0 else ""], 13, Color(1, 0.85, 0.45) if n > 0 else Color.WHITE)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.clip_text = true
		l.tooltip_text = String(d.get("desc", ""))
		l.mouse_filter = Control.MOUSE_FILTER_PASS
		_button(h, "−", func(): _card(id, -1), 32).disabled = n <= 0
		_button(h, "+", func(): _card(id, 1), 32).disabled = n >= mx and not d.get("instant", false)


func _card(id: String, delta: int) -> void:
	if delta > 0:
		Run.apply_card({"type": "passive", "id": id, "tier": "common", "mult": 1.0})
	else:
		var n := int(Run.passives.get(id, 0)) - 1
		if n <= 0:
			Run.passives.erase(id)
			Run.passive_power.erase(id)
		else:
			Run.passives[id] = n
			Run.passive_power[id] = maxf(0.0, float(Run.passive_power.get(id, 1.0)) - 1.0)
	player.recalc_stats()
	_refresh_cards()


# --- ennemis ----------------------------------------------------------------------------------
func _build_enemies() -> void:
	_section("Ennemis")
	_check("Ennemis invincibles", Training.enemies_immortal, func(on): Training.enemies_immortal = on)
	_check("Ennemis passifs (n'attaquent pas)", Training.enemies_passive, func(on): Training.enemies_passive = on)
	var r := _row()
	_button(r, "Mannequin d'entraînement", _spawn_dummy, 0).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_button(r, "Tout retirer", func():
		for m in get_tree().get_nodes_in_group("monsters"):
			m.queue_free()
		_say("Ennemis retirés."), 120)
	# adversaire : un héros d'une classe (combo de son arme, sorts, esquives)
	var rr := _row()
	_rival_btn = _button(rr, "Adversaire : %s ▾" % GameData.class_data(_rival_class).get("name_fr", ""), func(): pass, 0)
	_rival_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rival_btn.pressed.connect(func(): HeroPages.class_menu(_rival_btn, _rival_class, func(cid):
		_rival_class = cid
		_rival_btn.text = "Adversaire : %s ▾" % GameData.class_data(cid).get("name_fr", "")))
	_rival_diff = OptionButton.new()
	for d in ClassRival.NAMES:
		_rival_diff.add_item(d)
	_rival_diff.select(1)
	_rival_diff.focus_mode = Control.FOCUS_NONE
	rr.add_child(_rival_diff)
	_button(_box, "Faire apparaître l'adversaire de classe", spawn_rival)
	_mon_search = LineEdit.new()
	_mon_search.placeholder_text = "Chercher un monstre (nom)…"
	_mon_search.text_changed.connect(func(_t): _refresh_monsters())
	_box.add_child(_mon_search)
	_mon_list = ItemList.new()
	_mon_list.custom_minimum_size = Vector2(0, 170)
	_box.add_child(_mon_list)
	var r2 := _row()
	_count = SpinBox.new()
	_count.min_value = 1
	_count.max_value = 30
	_count.value = 1
	_count.prefix = "×"
	r2.add_child(_count)
	_button(r2, "Faire apparaître", _spawn_selected, 0).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_refresh_monsters()


func _refresh_monsters() -> void:
	_mon_list.clear()
	_mon_ids.clear()
	var q := _mon_search.text.strip_edges().to_lower()
	# monstres de la zone d'abord, puis tous les autres
	var zone_ids: Array = director.zone.get("monsters", []).map(func(x): return int(x)) + director.zone.get("elites", []).map(func(x): return int(x))
	var ids: Array = zone_ids + GameData.monsters.keys().filter(func(k): return not int(k) in zone_ids)
	for id in ids:
		var m: Dictionary = GameData.monster(int(id))
		if m.is_empty() or (q != "" and not String(m.get("name", "")).to_lower().contains(q)):
			continue
		_mon_list.add_item("%s · niv. %d%s" % [m.get("name", id), int(m.get("level", 1)), "  ★ élite" if int(m.get("rank", 2)) == 3 else ""])
		_mon_ids.append(int(id))
		if _mon_ids.size() >= 300:
			break


func _spawn_point(i: int, n: int) -> Vector3:
	var fwd := -player.global_transform.basis.z
	fwd.y = 0.0
	fwd = fwd.normalized() if fwd.length() > 0.01 else Vector3.FORWARD
	var side := fwd.cross(Vector3.UP).normalized()
	var p := player.global_position + fwd * 6.0 + side * (float(i) - float(n - 1) * 0.5) * 2.2
	return director.ground_point(p, player.global_position + fwd * 6.0)


func _spawn_selected() -> void:
	var sel := _mon_list.get_selected_items()
	if sel.is_empty():
		_say("Choisis un monstre dans la liste.")
		return
	var id := int(_mon_ids[sel[0]])
	var n := int(_count.value)
	for i in n:
		director._spawn_monster(id, _spawn_point(i, n), player.level)
	_say("%d × %s (niveau %d)." % [n, GameData.monster(id).get("name", id), player.level])


## Adversaire de classe au niveau du héros, devant lui.
func spawn_rival() -> ClassRival:
	var r := ClassRival.new()
	r.setup(_rival_class, player.level, _rival_diff.selected if _rival_diff else 1)
	director.add_child(r)
	r.global_position = _spawn_point(0, 1) + Vector3.UP * 0.4
	r.look_at(player.global_position * Vector3(1, 0, 1) + Vector3.UP * r.global_position.y, Vector3.UP)
	r.rotate_y(PI)
	_say("%s adverse %s (niveau %d) : combo, sorts annoncés en rouge, esquives." % [GameData.class_data(_rival_class).get("name_fr", ""), String(ClassRival.NAMES[r.difficulty]).to_lower(), player.level])
	return r


## Mannequin : un monstre de la zone qui ne bouge pas, n'attaque pas et ne meurt jamais.
func _spawn_dummy() -> void:
	var pool: Array = director.zone.get("monsters", []) + director.zone.get("elites", [])
	if pool.is_empty():
		return
	var m := director._spawn_monster(int(pool[0]), _spawn_point(0, 1), player.level)
	m.passive = true
	m.immortal = true
	m.display_name = "Mannequin d'entraînement"
	m.max_hp = 1000000.0
	m.hp = m.max_hp
	_say("Mannequin posé devant toi : il encaisse sans broncher (DPS en haut).")
