class_name TowerDirector
extends Node
## Déroulement d'un étage de la Tour (voir Tower) : une salle fermée (arène des donjons, décor
## de la zone de l'étage), des vagues de monstres jusqu'au compte de l'étage, une élite tous
## les 5 étages, un boss tous les 10 ; étage vidé : une carte, puis un coffre au centre (son
## objet s'équipe s'il est meilleur), puis l'escalier vers l'étage suivant.

const SPAWN_EVERY := 0.7  # secondes entre deux groupes
const BOSS_ADDS_EVERY := 14.0

var d: RunDirector
var phase := "fight"  # fight, cards, chest, stairs, done
var left := 0  # monstres encore à faire apparaître
var _spawn_t := 0.0
var _adds_t := BOSS_ADDS_EVERY
var _obj_t := 0.0
var _boss: Monster
var _rival: ClassRival  # duelliste de l'étage
var _center := Vector3.ZERO
var _goal: Interactable  # coffre ou escalier à atteindre (flèche de l'objectif)


func setup(director: RunDirector) -> void:
	d = director
	begin(Tower.start_floor)
	_spawn_allies()


func _room_word() -> String:
	return "Salle" if Tower.is_dungeon() else "Étage"


## Alliés IA du donjon : des héros scriptés du camp du joueur (comme les duellistes, mais alliés).
var _allies: Array = []


func _spawn_allies() -> void:
	if not Tower.is_dungeon():
		return
	for cid in Tower.allies:
		var a := ClassRival.new()
		a.ally = true
		a.setup(String(cid), Tower.level_for(1), 2)
		var b := Duel.opti_build(String(cid), Tower.level_for(1))
		if not b.is_empty():
			a.apply_build(b, Tower.level_for(1))
		d.add_child(a)
		a.died.connect(func(_w, _k): d.message.emit("Un allié est tombé : %s" % a.display_name, 2.5))
		_allies.append(a)
	_place_allies()


func _place_allies() -> void:
	var i := 0
	for a in _allies:
		if is_instance_valid(a):
			if a.is_dead:
				continue
			a.global_position = d.player.global_position + Vector3(2.5 * (1 if i % 2 == 0 else -1), 0.4, 1.5)
			a.hp = minf(a.max_hp, a.hp + a.max_hp * 0.35)
			i += 1


## Prépare l'étage [param f] : salle, niveau du héros, monstres.
func begin(f: int) -> void:
	Tower.floor_n = f
	var z := Tower.zone_for(f)
	Run.zone_id = String(z.id)
	d.zone = z
	d._roster = z.monsters.map(func(x): return int(x))
	d._elites = z.get("elites", []).map(func(x): return int(x))
	d._clear_monsters()
	d.map = d.world.new_arena_map(d._seed + f * 7919)
	d.world._apply_biome_env()
	d.world.set_dungeon_mood(true)
	_center = Vector3(d.map.size * 0.5, 0, d.map.size * 0.5)
	_center.y = d.map.height_at(_center.x, _center.z)
	var p := d.player
	var lvl := Tower.level_for(f)
	p.level = lvl
	Run.hero_level = lvl
	Run.max_level = lvl
	p.recalc_stats()
	if f == Tower.start_floor or (Tower.is_boss_floor(f - 1) and not Tower.rush):
		p.heal(p.max_hp)
	else:
		p.heal(p.max_hp * Tower.rule("heal_between"))
	p.set_torch(true)
	d._place_player(d.map.start)
	_place_allies()
	d.zone_changed.emit({"name": "La Tour · %s" % z.name, "levels": [lvl, lvl]})
	if p.autoplay:
		print("[tour] étage %d · niveau %d · PV %d · équipement %d pièce(s)" % [f, lvl, int(p.hp), Profile.equipped.size()])
	phase = "fight"
	_spawn_t = 1.5
	_adds_t = BOSS_ADDS_EVERY
	_boss = null
	d._boss = null
	_rival = null
	if Tower.is_duel_floor(f):
		left = 0
		_spawn_rival(f, lvl)
		d.message.emit("Étage %d / %d\nDuel %d/%d : %s" % [f, Tower.top(), Tower.duel_index(f), Tower.duel_count(),
			GameData.class_data(_rival.cid).get("name_fr", _rival.cid)], 3.5)
	elif Tower.is_boss_floor(f):
		left = 0
		_spawn_boss(z, lvl)
		d.message.emit("%s %d / %d\nBOSS : %s" % [_room_word(), f, Tower.top(), _boss.display_name], 3.5)
	else:
		left = Tower.monster_count(f)
		if Tower.is_elite_floor(f):
			for i in Tower.elite_count(f):
				_spawn(d._elites.pick_random() if not d._elites.is_empty() else d._pick_monster(lvl), _ring(8.0, 14.0), lvl + 1)
		d.message.emit("%s %d / %d%s" % [_room_word(), f, Tower.top(), "\nÉlite en vue !" if Tower.is_elite_floor(f) else ""], 2.5)


func _spawn(id: int, pos: Vector3, lvl: int, boss := false) -> Monster:
	var m := d._spawn_monster(id, pos, lvl, boss)
	m.max_hp *= Tower.monster_hp_mult(Tower.floor_n, -1, boss)
	m.hp = m.max_hp
	m.atk *= Tower.monster_atk_mult(Tower.floor_n, -1, boss)
	m.xp_reward = 0
	return m


func _spawn_boss(z: Dictionary, lvl: int) -> void:
	var dungeon: Dictionary = z.get("dungeon", {})
	_boss = _spawn(int(dungeon.get("boss", d._pick_monster(lvl))), _center, lvl + 1, true)
	_boss.display_name = "<Boss> " + _boss.display_name
	d._boss = _boss  # renforts et invocations du boss (RunDirector.summon_for_boss)
	if _boss.brain:
		_boss.brain.announce.connect(func(t): d.message.emit(t, 2.5))
		_boss.brain.setup(dungeon, d)
		_boss.brain.enraged_phase.connect(func(): d.message.emit("%s entre en fureur !" % _boss.display_name, 2.5))
		_boss.reflect_started.connect(func(): d.message.emit("Miroir ! Ne frappe pas pendant 3 s", 2.0))


## Duel : un héros de la classe suivante de la liste, au centre, face au joueur.
func _spawn_rival(f: int, lvl: int) -> void:
	var r := Tower.make_rival(Tower.spec(f))
	d.add_child(r)
	r.global_position = _center + Vector3.UP * 0.4
	r.look_at(Vector3(d.player.global_position.x, r.global_position.y, d.player.global_position.z), Vector3.UP)
	r.rotate_y(PI)
	r.died.connect(d._on_monster_died)
	_rival = r


## Point au sol autour du centre de la salle, à distance du héros.
func _ring(min_d: float, max_d: float) -> Vector3:
	for attempt in 12:
		var a := randf() * TAU
		var p := _center + Vector3(cos(a), 0, sin(a)) * randf_range(min_d, max_d)
		var g: Vector3 = d.map.ground_at(p.x, p.z)
		if g != Vector3.INF and g.distance_to(d.player.global_position) > 6.0:
			return g
	return _center


func alive() -> int:
	return get_tree().get_nodes_in_group("monsters").size()


func update(delta: float) -> void:
	match phase:
		"fight":
			_update_fight(delta)
		"cards":
			# carte choisie (la fenêtre est fermée) : le coffre apparaît au centre
			if not d.world.cards.is_open():
				if Tower.is_dungeon():
					_spawn_stairs()  # donjon : une carte par salle, pas de coffre
				else:
					_spawn_chest()
	if d.player.autoplay:
		d.player.autoplay_target = target()
	_obj_t -= delta
	if _obj_t <= 0.0:
		_obj_t = 0.25
		d.objective_changed.emit(objective_text())


func _update_fight(delta: float) -> void:
	var f := Tower.floor_n
	var lvl := Tower.level_for(f)
	_spawn_t -= delta
	if left > 0 and _spawn_t <= 0.0 and alive() < Tower.max_alive(f):
		_spawn_t = SPAWN_EVERY
		for i in mini(3, left):
			_spawn(d._pick_monster(lvl), _ring(9.0, 22.0), lvl)
			left -= 1
	if is_instance_valid(_boss) and not _boss.is_dead:
		_adds_t -= delta
		if _adds_t <= 0.0 and alive() < Tower.max_alive(f):
			_adds_t = BOSS_ADDS_EVERY
			for i in 3 + f / 40:
				_spawn(d._pick_monster(lvl), _ring(6.0, 12.0), maxi(1, lvl - 1))
		return
	if left <= 0 and alive() == 0:
		_cleared()


func _cleared() -> void:
	var f := Tower.floor_n
	Tower.reached = f
	d.player.heal(d.player.max_hp * 0.1)
	if f >= Tower.top():
		phase = "done"
		d.message.emit("DONJON TERMINÉ !" if Tower.is_dungeon() else "SOMMET DE LA TOUR ATTEINT !", 5.0)
		d.world.tower_end("victoire")
		return
	phase = "cards"
	d.message.emit("Étage %d vidé !" % f, 2.0)
	d.world._offer("Étage %d vidé ! Choisis une carte" % f, Run.roll_cards(3), func(): return Run.roll_cards(3))


func _spawn_chest() -> void:
	phase = "chest"
	var npcs: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/npcs.json"))
	var data: Dictionary = npcs.get("chest", {})
	var chest := Interactable.new()
	chest.setup("tower_chest", "Coffre de l'étage %d" % Tower.floor_n, "res://assets/monsters/%s/%s.glb" % [data.model, data.model],
		"res://assets/monsters/textures/%s.png" % data.texture, 1.2, 3.5)
	d.map.add_child(chest)
	chest.global_position = _center
	d.map.interactables.append(chest)
	_goal = chest
	d.message.emit("Un coffre est apparu au centre de la salle", 2.0)


## Coffre ouvert : l'objet est équipé pour l'ascension s'il est meilleur (ou si la place
## est libre), puis l'escalier apparaît.
func open_chest(it: Interactable) -> void:
	it.open_chest()
	var item := Tower.chest_item(Tower.floor_n, Run.class_id)
	Tower.found.append(item)  # rejoint le coffre commun à la fin de l'ascension
	var slot := String(item.get("slot", ""))
	var cur: Dictionary = Profile.equipped.get(slot, {})
	var better := cur.is_empty() or Items.rating(item) > Items.rating(cur)
	if better:
		Profile.equipped[slot] = item
		Profile.changed.emit()
		d.message.emit("Coffre : %s\nÉquipé ! (gardé à la fin de l'ascension)" % Items.display_name(item), 3.0)
	else:
		d.message.emit("Coffre : %s\nMoins bon que %s : rangé, il rejoindra ton coffre" % [Items.display_name(item), Items.display_name(cur)], 3.0)
	Sfx.play_at(it, it.global_position, "atks001.wav", -6.0, 0.3)
	_spawn_stairs()


func _spawn_stairs() -> void:
	phase = "stairs"
	var st := Interactable.new()
	st.setup("tower_stairs", "Étage %d" % (Tower.floor_n + 1), "", "", 1.0, 3.5)
	d.map.add_child(st)
	var pos := _center + Vector3(0, 0, -7.0)
	var g: Vector3 = d.map.ground_at(pos.x, pos.z)
	st.global_position = g if g != Vector3.INF else _center
	# colonne de lumière : l'escalier se voit de toute la salle
	var beam := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 1.2
	cyl.bottom_radius = 1.6
	cyl.height = 9.0
	beam.mesh = cyl
	beam.position.y = 4.5
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.disable_fog = true
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.albedo_color = Color(0.45, 0.75, 1.0, 0.35)
	beam.material_override = m
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	st.add_child(beam)
	d.map.interactables.append(st)
	_goal = st


func interact(it: Interactable) -> void:
	match it.kind:
		"tower_chest":
			if phase == "chest":
				open_chest(it)
		"tower_stairs":
			if phase == "stairs":
				it.used = true
				begin(Tower.floor_n + 1)


## Coffre ou escalier en attente (flèche de l'objectif, pilote automatique).
func target() -> Vector3:
	if phase in ["chest", "stairs"] and is_instance_valid(_goal) and not _goal.used:
		return _goal.global_position
	return Vector3.INF


func objective_text() -> String:
	var f := Tower.floor_n
	match phase:
		"fight":
			if is_instance_valid(_boss) and not _boss.is_dead:
				return "Étage %d · Vaincs %s" % [f, _boss.display_name]
			if is_instance_valid(_rival) and not _rival.is_dead:
				return "Étage %d · Duel %d/%d : bats %s" % [f, Tower.duel_index(f), Tower.duel_count(), GameData.class_data(_rival.cid).get("name_fr", "")]
			return "%s %d · Monstres restants : %d" % [_room_word(), f, left + alive()]
		"cards":
			return "%s %d vidée · Choisis une carte" % [_room_word(), f]
		"chest":
			return "Ouvre le coffre au centre [%s]" % Settings.action_label("interact", 1)
		"stairs":
			return "%s [%s]" % ["Passe à la salle suivante" if Tower.is_dungeon() else "Monte à l'étage %d" % (f + 1), Settings.action_label("interact", 1)]
	return "Sommet atteint"
