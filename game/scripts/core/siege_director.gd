class_name SiegeDirector
extends TowerDirector
## Déroulement du Siège (voir Siege) dans UNE arène de donjon : cinq vagues (carte + soin partiel + potions
## entre deux), le boss (fureur à 6 min), puis la bascule : la zone se ferme (anneau qui rétrécit en 20 s), le
## cœur du boss tombe au centre, trêve de quelques secondes, puis chacun pour soi à trois (un `ffa_id` par héros,
## règles du JcJ). Fin : dernier debout (coffre d'apparence légendaire), cœur emporté hors de l'anneau (coffre
## d'apparence épique) ou éliminé. Prolonge TowerDirector pour en garder l'apparition des monstres, du boss et des alliés.

var _wave_t := 0.0  # secondes de combat de la vague ou du boss en cours
var _enraged := false
var _enrage_next := 0.0
var _rest_t := 0.0
var _ffa_t := 0.0  # secondes depuis la mort du boss
var _wall: MeshInstance3D
var _ring_r := Siege.RING_FROM
var _core: Interactable
var _orb: Node3D  # lueur au-dessus de celui qui porte le cœur
var _out_t := 0.0  # tic des dégâts hors de l'anneau
var _msg_t := 0.0
var _hazards_done := false


func setup(director: RunDirector) -> void:
	d = director
	var z := Tower.zone_for(1)
	Run.zone_id = String(z.id)
	d.zone = z
	d._roster = z.monsters.map(func(x): return int(x))
	d._elites = z.get("elites", []).map(func(x): return int(x))
	d._clear_monsters()
	d.map = d.world.new_arena_map(d._seed)
	d.world._apply_biome_env()
	d.world.set_dungeon_mood(true)
	_center = Vector3(d.map.size * 0.5, 0, d.map.size * 0.5)
	_center.y = d.map.height_at(_center.x, _center.z)
	var p := d.player
	var lvl := Tower.level_for(1)
	p.level = lvl
	Run.hero_level = lvl
	Run.max_level = lvl
	p.recalc_stats()
	p.heal(p.max_hp)
	p.set_torch(true)
	d._place_player(d.map.start)
	Potions.start_run()  # 2 potions de soin au départ (Tower.start vide la réserve)
	_spawn_allies()
	d.zone_changed.emit({"name": "Le Siège · %s" % Dungeons.name_of(Tower.dungeon), "levels": [lvl, lvl]})
	begin(1)


func _room_word() -> String:
	return "Vague"


## Vague [param f] (1 à 5) ou le boss (6).
func begin(f: int) -> void:
	Tower.floor_n = f
	phase = "fight"
	_spawn_t = 1.5
	_adds_t = BOSS_ADDS_EVERY
	_wave_t = 0.0
	_boss = null
	d._boss = null
	var lvl := Tower.level_for(f)
	if Tower.is_boss_floor(f):
		left = 0
		_spawn_boss(Tower.zone_for(f), lvl)
		_enrage_next = Siege.ENRAGE_AT
		_enraged = false
		_spawn_hazards()
		var intro := String(Tower.zone_for(f).get("dungeon", {}).get("intro", ""))
		d.message.emit("BOSS : %s\nFureur dans %d min · évite les zones rouges" % [_boss.display_name, int(Siege.ENRAGE_AT / 60.0)], 4.0)
		if intro != "":
			d.get_tree().create_timer(4.2).timeout.connect(func(): d.message.emit(intro, 3.5))
		return
	left = Tower.monster_count(f)
	if Tower.is_elite_floor(f):
		for i in Tower.elite_count(f):
			_spawn(d._elites.pick_random() if not d._elites.is_empty() else d._pick_monster(lvl), _ring(8.0, 14.0), lvl + 1)
	d.message.emit("Vague %d / %d%s" % [f, Siege.WAVES, "\nDes élites !" if Tower.is_elite_floor(f) else ""], 2.5)


## Dangers permanents de l'arène du boss (lave, poison, givre…), comme dans la salle du boss de la Survie.
func _spawn_hazards() -> void:
	if _hazards_done:
		return
	_hazards_done = true
	for hz in d.map.arena_hazards:
		Hazard.spawn(d, hz.pos, {"style": hz.style, "radius": hz.radius, "lifetime": 0.0, "dps": _boss.atk * 0.3, "source": _boss})


# --- boucle -----------------------------------------------------------------------------------
func update(delta: float) -> void:
	match phase:
		"fight":
			_update_fight(delta)
		"cards":
			if not d.world.cards.is_open():
				_start_rest()
		"rest":
			_rest_t -= delta
			if _rest_t <= 0.0:
				begin(Tower.floor_n + 1)
		"ring", "ffa":
			_update_ring(delta)
	if d.player.autoplay:
		d.player.autoplay_target = target()
	_obj_t -= delta
	if _obj_t <= 0.0:
		_obj_t = 0.25
		d.objective_changed.emit(objective_text())


func _update_fight(delta: float) -> void:
	var f := Tower.floor_n
	var lvl := Tower.level_for(f)
	_wave_t += delta
	_spawn_t -= delta
	if left > 0 and _spawn_t <= 0.0 and alive() < Tower.max_alive(f):
		_spawn_t = SPAWN_EVERY
		for i in mini(3, left):
			_spawn(d._pick_monster(lvl), _ring(9.0, 22.0), lvl)
			left -= 1
	if is_instance_valid(_boss):
		if _boss.is_dead:
			_boss_down()
			return
		_update_boss(delta, lvl)
		return
	if left <= 0 and alive() == 0:
		_cleared()


## Renforts du boss et fureur au bout de 6 minutes : ses dégâts montent encore toutes les 15 s ensuite.
func _update_boss(delta: float, lvl: int) -> void:
	_adds_t -= delta
	if _adds_t <= 0.0 and alive() < Tower.max_alive(Tower.floor_n):
		_adds_t = BOSS_ADDS_EVERY
		for i in 3:
			_spawn(d._pick_monster(lvl), _ring(6.0, 12.0), maxi(1, lvl - 1))
	if not _enraged and _wave_t >= Siege.ENRAGE_AT - 60.0 and _msg_t <= 0.0:
		_msg_t = 1.0
		d.message.emit("Le boss entre en fureur dans 1 minute !", 2.5)
	if not _enraged and _wave_t >= Siege.ENRAGE_AT:
		_enraged = true
		_boss.enrage()
		_boss.atk *= 1.4
		_enrage_next = _wave_t + Siege.ENRAGE_STEP
		d.message.emit("%s est en FUREUR ! Ses coups ne feront que grandir." % _boss.display_name, 3.5)
	elif _enraged and _wave_t >= _enrage_next:
		_enrage_next += Siege.ENRAGE_STEP
		_boss.atk *= 1.15


func _cleared() -> void:
	var f := Tower.floor_n
	Tower.reached = f
	d.player.heal(d.player.max_hp * 0.1)
	phase = "cards"
	d.message.emit("Vague %d vaincue !" % f, 2.0)
	d.world._offer("Vague %d vaincue ! Choisis une carte" % f, Run.roll_cards(3), func(): return Run.roll_cards(3))


## Entre deux vagues : soin partiel pour tous, un peu de souffle, des potions.
func _start_rest() -> void:
	phase = "rest"
	_rest_t = Siege.REST_TIME
	var f := Tower.floor_n
	var p := d.player
	p.heal(p.max_hp * Tower.rule("heal_between"))
	_place_allies()  # les alliés vivants se regroupent et récupèrent aussi
	Potions.grant("heal", 1)
	var extra := ""
	if f % 2 == 0:
		var kind := String(Potions.BOOSTS.pick_random())
		Potions.grant(kind, 1)
		extra = " + " + Potions.label(kind).to_lower()
	d.message.emit("Répit : PV rendus, 1 potion de soin%s\nVague %d dans %d s" % [extra, f + 1, int(Siege.REST_TIME)], 3.0)


# --- le boss tombe : l'anneau, le cœur, le chacun pour soi ------------------------------------
func _boss_down() -> void:
	Tower.reached = Tower.top()  # la partie PvE est gagnée, quoi qu'il arrive ensuite
	d._clear_monsters()
	phase = "ring"
	_ffa_t = 0.0
	_ring_r = Siege.RING_FROM
	PvpCaps.elapsed = 0.0
	_regroup_heroes()
	_make_ring()
	_make_core()
	d.message.emit("LE BOSS EST TOMBÉ !\nLa zone se ferme… son cœur est tombé au centre", 4.0)


## Les trois héros reviennent à pleine vie sur un cercle (les alliés tombés sont remplacés), cooldowns remis à zéro.
func _regroup_heroes() -> void:
	var p := d.player
	for i in Tower.allies.size():
		var a: ClassRival = _allies[i] if i < _allies.size() else null
		if a == null or not is_instance_valid(a) or a.is_dead:
			if a != null and is_instance_valid(a):
				a.queue_free()
			a = _make_ally(String(Tower.allies[i]))
			if i < _allies.size():
				_allies[i] = a
			else:
				_allies.append(a)
	p.heal(p.max_hp)
	p.statuses.clear()
	p.skill_ready_at.clear()
	var hs: Array = [p] + _allies
	for i in hs.size():
		var h: Combatant = hs[i]
		var ang := PI * 0.5 + TAU * float(i) / float(hs.size())
		var pos := _center + Vector3(cos(ang), 0, sin(ang)) * 15.0
		var g: Vector3 = d.map.ground_at(pos.x, pos.z)
		h.global_position = (g if g != Vector3.INF else _center) + Vector3.UP * 0.6
		h.velocity = Vector3.ZERO
		if h != p:
			var a := h as ClassRival
			a.hp = a.max_hp
			a.statuses.clear()
			a.passive = true  # immobile pendant la trêve
	d._last_safe = p.global_position


func _make_ring() -> void:
	_wall = MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 1.0
	cyl.bottom_radius = 1.0
	cyl.height = 26.0
	cyl.radial_segments = 72
	cyl.cap_top = false
	cyl.cap_bottom = false
	_wall.mesh = cyl
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.disable_fog = true
	m.albedo_color = Color(1.0, 0.3, 0.2, 0.3)
	_wall.material_override = m
	_wall.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	d.map.add_child(_wall)
	_wall.global_position = _center + Vector3.UP * 12.0
	_wall.scale = Vector3(_ring_r, 1.0, _ring_r)


func _make_core() -> void:
	_core = Interactable.new()
	_core.setup("siege_core", "Cœur du boss", "", "", 1.0, 3.2)
	d.map.add_child(_core)
	_core.global_position = _center
	_core.add_beam(Color(1.0, 0.45, 0.95), 20.0)
	var orb := MeshInstance3D.new()
	var sph := SphereMesh.new()
	sph.radius = 0.45
	sph.height = 0.9
	orb.mesh = sph
	orb.material_override = _glow(Color(1.0, 0.5, 0.95))
	orb.position.y = 1.3
	_core.add_child(orb)
	d.map.interactables.append(_core)


static func _glow(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = c
	return m


func interact(it: Interactable) -> void:
	if it.kind == "siege_core" and phase in ["ring", "ffa"] and Siege.carrier == null and not it.used and not d.player.is_dead:
		it.used = true
		it.visible = false
		Siege.carrier = d.player
		_orb = Node3D.new()
		var mi := MeshInstance3D.new()
		var sph := SphereMesh.new()
		sph.radius = 0.28
		sph.height = 0.56
		mi.mesh = sph
		mi.material_override = _glow(Color(1.0, 0.55, 0.95))
		_orb.add_child(mi)
		var light := OmniLight3D.new()
		light.light_color = Color(1.0, 0.5, 0.95)
		light.omni_range = 7.0
		_orb.add_child(light)
		d.player.add_child(_orb)
		_orb.position = Vector3(0, 3.0, 0)
		d.message.emit("Tu portes le cœur !\nFranchis l'anneau pour quitter le duel (récompense moindre) — les deux autres te chassent", 4.0)
		Sfx.ui("pickup", -2.0)


func _alive_allies() -> Array:
	return _allies.filter(func(a): return is_instance_valid(a) and not a.is_dead)


func _update_ring(delta: float) -> void:
	_ffa_t += delta
	_msg_t -= delta
	var k := clampf(_ffa_t / Siege.RING_TIME, 0.0, 1.0)
	_ring_r = lerpf(Siege.RING_FROM, Siege.RING_TO, k)
	if is_instance_valid(_wall):
		_wall.scale = Vector3(_ring_r, 1.0, _ring_r)
	if phase == "ring" and _ffa_t >= Siege.TRUCE:
		_begin_ffa()
	if phase == "ffa":
		PvpCaps.elapsed += delta
	var p := d.player
	if phase == "done" or p.is_dead:
		return
	# hors de l'anneau : le joueur brûle (de plus en plus), les IA sont repoussées vers le centre
	_out_t -= delta
	var tick := _out_t <= 0.0
	if tick:
		_out_t = 0.5
	var heroes: Array = [p] + _alive_allies()
	for h in heroes:
		var c: Combatant = h
		var off := c.global_position - _center
		off.y = 0.0
		var dist := off.length()
		if dist <= _ring_r:
			continue
		if c == p:
			if tick and Siege.carrier != p:
				p.take_damage(p.max_hp * Siege.RING_DPS * 0.5 * (1.0 + _ffa_t / 40.0), null, false, true)
		else:
			c.global_position -= off.normalized() * minf(dist - _ring_r + 0.5, 7.0 * delta)
	# le cœur franchit l'anneau : le joueur quitte le duel
	if Siege.carrier == p:
		var off := p.global_position - _center
		off.y = 0.0
		if off.length() >= _ring_r - 0.6:
			_finish("escaped", "Tu t'enfuis avec le cœur !")
			return
	if phase == "ffa" and _alive_allies().is_empty():
		_finish("won", "VICTOIRE ! Dernier debout")


func _begin_ffa() -> void:
	phase = "ffa"
	Siege.ffa = true
	d.player.set_ffa(0)
	for i in _allies.size():
		var a: ClassRival = _allies[i]
		a.set_ffa(i + 1)
		a.passive = false
		a.died.connect(func(_w, _k): if phase == "ffa": d.message.emit("%s est éliminé" % a.display_name, 2.0))
	d.player.recalc_stats()  # plafonds du JcJ
	d.message.emit("CHACUN POUR SOI !\nLe dernier debout gagne un coffre d'apparence légendaire", 4.0)


func _stop_fight() -> void:
	phase = "done"
	Siege.ffa = false
	Siege.carrier = null
	for a in _allies:
		if is_instance_valid(a):
			a.passive = true
			a.clear_ffa()
	d.player.clear_ffa()
	d.player.immortal = true  # rien ne l'atteint pendant le bilan
	if is_instance_valid(_orb):
		_orb.queue_free()


func _finish(result: String, text: String) -> void:
	Siege.outcome = result
	Siege.rank = 1 if result == "won" else 0
	_stop_fight()
	d.message.emit(text, 3.0)
	d.get_tree().create_timer(2.5).timeout.connect(func(): d.world.tower_end("victoire"))


## Le héros est tombé (world.gd) : la partie s'arrête (une seule vie), classé selon les IA encore debout.
func player_down() -> void:
	if phase == "done":
		return
	var in_ffa := phase in ["ring", "ffa"]
	if in_ffa:
		Siege.outcome = "eliminated"
		Siege.rank = 1 + _alive_allies().size()
		d.message.emit("Éliminé ! Tu termines %de." % Siege.rank, 3.0)
	else:
		d.message.emit("Tu es tombé %s…" % ("face au boss" if Tower.is_boss_floor(Tower.floor_n) else "à la vague %d" % Tower.floor_n), 2.5)
	_stop_fight()
	d.player.immortal = false
	d.get_tree().create_timer(2.5).timeout.connect(func(): d.world.tower_end("defaite"))


func target() -> Vector3:
	if phase in ["ring", "ffa"] and is_instance_valid(_core) and not _core.used:
		return _core.global_position
	return Vector3.INF


## Texte de l'horloge du HUD.
func clock_text() -> String:
	match phase:
		"ring":
			return "Trêve %d" % maxi(0, ceili(Siege.TRUCE - _ffa_t))
		"ffa":
			return "Chacun pour soi"
		"done":
			return "Fin du siège"
	if Tower.is_boss_floor(Tower.floor_n):
		return "BOSS" if _enraged else "Boss %d:%02d" % [int(maxf(0.0, Siege.ENRAGE_AT - _wave_t)) / 60, int(maxf(0.0, Siege.ENRAGE_AT - _wave_t)) % 60]
	return "Vague %d/%d" % [Tower.floor_n, Siege.WAVES]


func objective_text() -> String:
	var f := Tower.floor_n
	match phase:
		"fight":
			if is_instance_valid(_boss) and not _boss.is_dead:
				if _enraged:
					return "%s est en fureur : achève-le !" % _boss.display_name
				var rest := maxf(0.0, Siege.ENRAGE_AT - _wave_t)
				return "Vaincs %s · fureur dans %d:%02d" % [_boss.display_name, int(rest) / 60, int(rest) % 60]
			return "Vague %d/%d · Monstres restants : %d" % [f, Siege.WAVES, left + alive()]
		"cards":
			return "Vague %d vaincue · Choisis une carte" % f
		"rest":
			return "Répit · vague %d dans %d s" % [f + 1, maxi(0, ceili(_rest_t))]
		"ring", "ffa":
			if Siege.carrier == d.player:
				return "Tu portes le cœur : franchis l'anneau pour quitter le duel"
			var n := _alive_allies().size()
			var lines := "Le cœur est au centre [%s] : prends-le et fuis, ou" % Settings.action_label("interact", 1)
			if phase == "ring":
				return "%s sois le dernier debout · reste dans l'anneau" % lines
			return "%s bats-les : %d adversaire%s · reste dans l'anneau" % [lines, n, "s" if n > 1 else ""]
	return "Fin du siège"
