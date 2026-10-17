class_name TowerDirector
extends Node
## Déroulement d'un étage de la Tour (voir Tower) : une salle fermée (arène des donjons, décor
## de la zone de l'étage) ; selon le type de l'étage (Tower.floor_type) : monstres d'espèces et de rôles mélangés avec au
## moins une élite à mécanique, élites, héros joué par l'IA (duelliste, ombre, ombre éveillée), boss de la bibliothèque,
## halte ; étage vidé : une carte, puis un coffre au centre (son objet s'équipe s'il est meilleur), puis l'escalier.
##
## Interface gardée stable pour les directeurs qui le prolongent (SiegeDirector ; les Donjons et la Ruée passent par les
## mêmes fonctions, Tower.is_dungeon()) :
##   champs : d, phase ("fight", "cards", "chest", "stairs", "done" ; le Siège ajoute les siens), left, _spawn_t, _adds_t,
##            _obj_t, _boss, _rival, _center, _goal, _allies ;
##   à surcharger : setup(director), begin(f), update(delta), _update_fight(delta), _cleared(), _room_word(), interact(it),
##            target(), objective_text(), clock_text() (texte de l'horloge du HUD) ;
##   outils : _spawn(id, pos, lvl, boss), _spawn_boss(zone, lvl), _spawn_lieutenant(f, lvl), _spawn_rival(f, lvl),
##            _spawn_allies(), _make_ally(cid), _place_allies(), _ring(min, max), alive(), _spawn_chest(), open_chest(it),
##            _spawn_stairs().
## Les ajouts de la passe M3 (élites à mécanique, mélange d'espèces, malédictions, ombres, halte, boss de la bibliothèque)
## ne s'appliquent qu'à la Tour elle-même (pas à la Ruée ni au Siège) ; les Donjons (lot A2) reprennent les élites à mécanique
## dans leur 1re salle (_begin_dungeon_room).

const SPAWN_EVERY := 0.7  # secondes entre deux groupes
const BOSS_ADDS_EVERY := 14.0
const ESCORT := 2  # monstres qui entourent chaque élite à son apparition (comptés dans l'étage)

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
var _adds_on := true  # renforts génériques toutes les BOSS_ADDS_EVERY s (pas pour un boss de la bibliothèque)
var _hero: Player  # ombre éveillée : héros ennemi piloté par un cerveau d'IA (sinon null)
var _pilot: MlDuelPilot
var _mix: Array = []  # espèces de l'étage (Tour), jouées à tour de rôle : jamais un pack d'une seule espèce
var _mix_i := 0
var _curse := ""  # malédiction de l'étage (Tower.CURSES), "" sinon
var _elites_alive: Array = []  # élites de l'étage (objectif)
var _lieutenant: Monster  # lieutenant de la salle d'un donjon (objectif)
var _elites_next := 0  # élites de la salle d'un donjon encore à venir (une à la fois, lot A2)
var _block_from := -1  # Tour : 1er étage de la tranche de 10 en cours, montée dans cette partie (temps record, lot DNG-1)
var _block_t0 := 0.0


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
		_allies.append(_make_ally(String(cid)))
	_place_allies()


## Un allié IA de la classe [param cid] (build « opti » au niveau de la salle), ajouté à la scène.
func _make_ally(cid: String) -> ClassRival:
	var a := ClassRival.new()
	a.ally = true
	a.setup(cid, Tower.level_for(1), 2)
	var b := Duel.opti_build(cid, Tower.level_for(1))
	if not b.is_empty():
		a.apply_build(b, Tower.level_for(1))
	d.add_child(a)
	a.died.connect(func(_w, _k): d.message.emit("Un allié est tombé : %s" % a.display_name, 2.5))
	return a


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
	_adds_on = true
	_boss = null
	d._boss = null
	_rival = null
	_free_hero()
	_mix = []
	_mix_i = 0
	_curse = ""
	_elites_alive = []
	_lieutenant = null
	_elites_next = 0
	var tower := not Tower.is_dungeon()  # la Tour elle-même (pas un donjon, la Ruée ni le Siège)
	if tower and (f - 1) % 10 == 0:
		_block_from = f
		_block_t0 = BestTimes.clock
	if Tower.is_duel_floor(f):
		left = 0
		_spawn_rival(f, lvl)
		d.message.emit(_hero_intro(f), 3.5)
	elif Tower.is_boss_floor(f):
		left = 0
		_spawn_boss(z, lvl)
		if Tower.dungeon_boss != "":
			d.message.emit("BOSS : %s\n%s" % [BossLibrary.full_name(Tower.dungeon_boss), BossLibrary.intro(Tower.dungeon_boss)], 4.5)
		elif tower and _boss != null and _boss.has_meta("boss_id"):
			var bid := String(_boss.get_meta("boss_id"))
			d.message.emit("Étage %d · BOSS\n%s\n%s" % [f, BossLibrary.full_name(bid), BossLibrary.intro(bid)], 4.5)
		else:
			d.message.emit("%s %d / %d\nBOSS : %s" % [_room_word(), f, Tower.top(), _boss.display_name], 3.5)
	elif tower and Tower.floor_type(f) == "rest":
		left = 0
		_begin_halt(f)
	elif tower:
		left = Tower.monster_count(f)
		_curse = Tower.curse_of(f)
		_prepare_mix(f, lvl)
		for i in Tower.elite_count(f):
			_spawn_elite(f, i, lvl)
		d.message.emit(_floor_intro(f), 3.0)
	else:
		_begin_dungeon_room(f, lvl)


func _spawn(id: int, pos: Vector3, lvl: int, boss := false) -> Monster:
	var m := d._spawn_monster(id, pos, lvl, boss)
	m.max_hp *= Tower.monster_hp_mult(Tower.floor_n, -1, boss)
	m.hp = m.max_hp
	m.atk *= Tower.monster_atk_mult(Tower.floor_n, -1, boss)
	m.xp_reward = 0
	match _curse:  # étage maudit de la Tour
		"menace":
			m.max_hp *= Tower.CURSE_HP
			m.hp = m.max_hp
		"frenzy":
			m.enrage()
	return m


## Salle d'un donjon (lot A2 : plus de salle de monstres seuls) : salle 1, des élites à mécanique, une à la fois avec son
## escorte (la suivante arrive quand elle tombe : une mécanique à lire à la fois) ; salle 2, le lieutenant seul ; le boss
## (salle 3) passe par _spawn_boss. Sans lieutenant possible : des élites.
func _begin_dungeon_room(f: int, lvl: int) -> void:
	left = 0
	var lt := _spawn_lieutenant(f, lvl) if Tower.floor_type(f) == "lieutenant" else ""
	if lt == "":
		_elites_next = Dungeons.room_elites(Tower.dungeon_diff) - 1
		_spawn_elite(f, 0, lvl)
		d.message.emit("%s %d / %d · Élites\n%d élites à abattre, une à une" % [_room_word(), f, Tower.top(), _elites_next + 1], 3.0)
		return
	d.message.emit("%s %d / %d · Lieutenant\n%s garde la salle" % [_room_word(), f, Tower.top(), lt], 3.0)


## Élite [param i] de l'étage [param f] (Tour, salle des élites d'un donjon) : une élite de la zone, plus coriace, avec une
## mécanique propre (une brique de BossBricks, annoncée au sol comme celles des boss, coups plafonnés), son nom suivi de sa
## mécanique, et une escorte.
func _spawn_elite(f: int, i: int, lvl: int) -> Monster:
	var id: int = d._elites[(absi(hash([Tower.PLAN_SEED, f, i])) % d._elites.size())] if not d._elites.is_empty() else d._pick_monster(lvl)
	var pos := _ring(8.0, 14.0)
	var m := _spawn(id, pos, lvl + 1)
	m.max_hp *= Dungeons.ELITE_ROOM_HP if Tower.is_dungeon() else Tower.rule("elite_hp")
	m.hp = m.max_hp
	var brick := Dungeons.elite_brick(Tower.dungeon_boss, i) if Tower.is_dungeon() else Tower.elite_brick(f, i)
	var br := BossBrain.new()
	br.boss = m
	m.brain = br
	m.add_child(br)
	br.setup_bricks([BossBricks.normalize({"type": brick})], d, "lava", ["none"], 1.0, Tower.ELITE_HIT_CAP)
	if not br._brick_t.is_empty() and not Tower.is_dungeon():
		br._brick_t[0] = float(br._brick_t[0]) + 3.5 * i  # les élites d'un étage ne lancent pas leur mécanique ensemble
	m.display_name = "%s · %s" % [m.display_name, BossBricks.name_of(brick)]
	_elites_alive.append(m)
	for k in ESCORT:
		if left <= 0 and not Tower.is_dungeon():  # donjon : l'escorte vient en plus (aucun monstre seul dans la salle)
			break
		if _mix.is_empty():
			_spawn(d._pick_monster(lvl), _near(pos, 3.5), lvl)
		else:
			_spawn_mixed(_next_species(), _near(pos, 3.5), lvl)
		left = maxi(left - 1, 0)
	return m


## Monstre du mélange de l'étage (Tour), avec son rôle (SpawnDirector.apply_role, passe P15 : PV, dégâts, vitesse, attaque
## du tireur ou du chargeur ; « PV par point de budget ≈ 1 » : un groupe mélangé pèse autant qu'avant).
func _spawn_mixed(id: int, pos: Vector3, lvl: int) -> Monster:
	var m := _spawn(id, pos, lvl)
	SpawnDirector.apply_role(m, SpawnDirector.role_of(id))
	return m


## Espèces de l'étage [param f] (Tour) : Tower.floor_species (tirées par étage ; la fiche de l'étage montre les mêmes).
func _prepare_mix(f: int, _lvl: int) -> void:
	_mix = Tower.floor_species(f)


## Espèce suivante du mélange de l'étage (à tour de rôle, le départ tiré : les groupes de 3 en ont 3 différentes).
func _next_species() -> int:
	if _mix_i == 0:
		_mix_i = randi() % _mix.size()
	_mix_i += 1
	return int(_mix[_mix_i % _mix.size()])


## Point au sol près de [param p] (groupe d'un même côté).
func _near(p: Vector3, spread: float) -> Vector3:
	var a := randf() * TAU
	var q := p + Vector3(cos(a), 0, sin(a)) * randf_range(0.8, spread)
	var g: Vector3 = d.map.ground_at(q.x, q.z)
	return g if g != Vector3.INF else p


## Halte (Tour) : pas de combat ; une part des PV rendue, une carte au choix, puis le coffre et l'escalier.
func _begin_halt(f: int) -> void:
	var p := d.player
	p.heal(p.max_hp * Tower.rule("rest_heal"))
	Tower.reached = f
	phase = "cards"
	d.message.emit("Étage %d · Halte\nReprends ton souffle" % f, 3.0)
	d.world._offer("Halte : choisis une carte", Run.roll_cards(3), func(): return Run.roll_cards(3))


## Texte d'entrée d'un étage de monstres, d'élites ou maudit.
func _floor_intro(f: int) -> String:
	var n := Tower.elite_count(f)
	match Tower.floor_type(f):
		"elite":
			return "Étage %d · Élites\n%d élites à abattre" % [f, n]
		"cursed":
			var c: Dictionary = Tower.CURSES.get(_curse, {})
			return "Étage %d · Maudit : %s\n%s" % [f, String(c.get("name", "")), String(c.get("desc", ""))]
	return "Étage %d / %d\n%s" % [f, Tower.top(), "Une élite en vue" if n <= 1 else "%d élites en vue" % n]


func _spawn_boss(z: Dictionary, lvl: int) -> void:
	if Tower.dungeon_boss != "":
		# donjon à la carte (passe M2) : le boss vient de la bibliothèque (PV fixes du palier × le boss, alliés en plus)
		var hp := BossLibrary.hp(Tower.dungeon_boss, lvl + 1, Tower.dungeon_diff) * (1.0 + Dungeons.ALLY_HP_STEP * Tower.allies.size())
		_boss = BossLibrary.spawn(Tower.dungeon_boss, Tower.dungeon_diff, {"director": d, "pos": _center, "level": lvl + 1, "hp": hp,
			"atk_mult": Tower.monster_atk_mult(Tower.floor_n, -1, true)})
		if _boss != null:
			_boss.xp_reward = 0
			return
	if not Tower.is_dungeon() and Tower.boss_id(Tower.floor_n) != "":
		# la Tour (passe M3) : un boss de la bibliothèque, PV fixes de l'étage, palier selon l'étage et la difficulté
		var f := Tower.floor_n
		_boss = BossLibrary.spawn(Tower.boss_id(f), Tower.boss_tier(f), {"director": d, "pos": _center, "level": lvl + 1,
			"hp": Tower.boss_hp_fixed(f), "atk_mult": Tower.monster_atk_mult(f, -1, true), "hit_cap": Tower.BOSS_HIT_CAP})
		if _boss != null:
			_boss.xp_reward = 0
			_adds_on = false  # ses invocations sont ses mécaniques
			return
	var dungeon: Dictionary = z.get("dungeon", {})
	_boss = _spawn(int(dungeon.get("boss", d._pick_monster(lvl))), _center, lvl + 1, true)
	_boss.display_name = "<Boss> " + _boss.display_name
	if Tower.is_dungeon():
		# donjon, Ruée, Siège : PV fixes par niveau et difficulté (passe P11), alliés ou trio en plus
		var hp := Dungeons.boss_hp(lvl + 1, Tower.dungeon_diff, Tower.rush)
		_boss.max_hp = hp * (Siege.BOSS_SCALE if Tower.siege else 1.0 + Dungeons.ALLY_HP_STEP * Tower.allies.size())
		_boss.hp = _boss.max_hp
	d._boss = _boss  # renforts et invocations du boss (RunDirector.summon_for_boss)
	if _boss.brain:
		_boss.brain.announce.connect(func(t): d.message.emit(t, 2.5))
		_boss.brain.setup(dungeon, d)
		_boss.brain.enraged_phase.connect(func(): d.message.emit("%s entre en fureur !" % _boss.display_name, 2.5))
		_boss.reflect_started.connect(func(): d.message.emit("Miroir ! Ne frappe pas pendant 3 s", 2.0))


## Salle du lieutenant d'un donjon à la carte (Dungeons.LIEUTENANT_ROOM) : un autre boss de la zone, une seule
## mécanique, une part des PV du boss (× Dungeons.LIEUTENANT_HP, lot A2 : il fait la salle à lui seul) ; il compte parmi les
## monstres de la salle. Renvoie son nom ("" : pas de lieutenant).
func _spawn_lieutenant(f: int, lvl: int) -> String:
	if Tower.dungeon_boss == "" or f != Dungeons.LIEUTENANT_ROOM:
		return ""
	var lid := Dungeons.lieutenant_of(Tower.dungeon_boss)
	if lid == "":
		return ""
	var hp := BossLibrary.hp(Tower.dungeon_boss, lvl + 1, Tower.dungeon_diff) * (1.0 + Dungeons.ALLY_HP_STEP * Tower.allies.size()) * Dungeons.LIEUTENANT_HP
	var m := BossLibrary.spawn(lid, Tower.dungeon_diff, {"director": d, "pos": _ring(9.0, 14.0), "level": lvl, "hp": hp, "lieutenant": true,
		"atk_mult": Tower.monster_atk_mult(f, -1, true)})
	if m == null:
		return ""
	m.xp_reward = 0
	_lieutenant = m
	return BossLibrary.short_name(lid)


## Duel ou ombre : un héros joué par l'IA, au centre, face au joueur (ombre éveillée : un cerveau d'IA, sinon le héros
## scripté ClassRival).
func _spawn_rival(f: int, lvl: int) -> void:
	var s := Tower.spec(f)
	if String(s.get("kind", "")) == "brain" and _spawn_brain_hero(s):
		return
	if String(s.get("kind", "")) == "brain":
		s["kind"] = "class"  # cerveau absent ou d'une autre version : l'ombre scriptée
	var r := Tower.make_rival(s)
	d.add_child(r)
	r.global_position = _center + Vector3.UP * 0.4
	r.look_at(Vector3(d.player.global_position.x, r.global_position.y, d.player.global_position.z), Vector3.UP)
	r.rotate_y(PI)
	r.died.connect(d._on_monster_died)
	_rival = r


## Ombre éveillée (passe M3) : un héros ennemi (Player) piloté par un cerveau d'IA figé (celui du Panthéon, dans git), avec
## l'équipement de l'ombre scriptée de l'étage, PV et dégâts ramenés à ceux de cette ombre × Tower.BRAIN_HP / BRAIN_DMG.
## false si le cerveau manque ou ne correspond pas à cette version de l'arène.
func _spawn_brain_hero(s: Dictionary) -> bool:
	var cid := String(s["class"])
	var lv := int(s.level)
	var h := Player.new()
	h.foe = true
	h.class_id = cid
	h.level = lv
	var kit := Duel.kit_from_grid(cid, [])
	h.kit_skills = kit.skills
	h.kit_chains = kit.chains
	# l'équipement de l'ombre scriptée du même étage (avec le build « opti », sa défense le rendait intouchable hors des règles
	# du duel : 46 dégâts sur un coup de 36 000, mesuré)
	h.built = true
	h.foe_gear = {}
	for it in s.get("gear", []):
		h.foe_gear[String(it.slot)] = it
	d.add_child(h)
	# PV et dégâts : ceux de l'ombre scriptée qu'il remplace (× BRAIN_HP / BRAIN_DMG)
	var ref_s := s.duplicate()
	ref_s["kind"] = "class"
	var ref := Tower.make_rival(ref_s)
	var magic := String(h.cls.get("dmg_type", "phys")) in ["mag", "magic"]
	var own_atk := maxf(h.matk if magic else h.atk, 1.0)
	var want_hp := ref.max_hp * Tower.BRAIN_HP
	h.foe_extra = {"hp_pct": maxf(0.0, want_hp / maxf(h.max_hp, 1.0) - 1.0), "dmg_pct": maxf(0.0, ref.atk * Tower.BRAIN_DMG / own_atk - 1.0),
		"heal_pct": -0.5}  # (le cerveau se soigne au bon moment : un Psalmiste remontait à 100 % face à un guerrier)
	ref.free()
	h.recalc_stats()
	h.max_hp = maxf(h.max_hp, want_hp)  # (les % de PV s'ajoutent à ceux de l'équipement : la valeur voulue, au moins)
	var pilot := MlDuelPilot.new()
	d.add_child(pilot)
	var was := Duel.mode
	Duel.mode = "pantheon"  # MlDuelPilot.brain_path : la copie figée (pantheon_<palier>.json), la même pour tous
	var ok := pilot.setup(h, d.player, Tower.shadow_brain(int(s.diff)), _center)
	Duel.mode = was
	if not ok:
		h.queue_free()
		pilot.queue_free()
		return false
	h.global_position = _center + Vector3.UP * 0.4
	h.face_direction(d.player.global_position - h.global_position, 1.0, 100.0)
	h.hp = h.max_hp
	h.display_name = "<Duel> " + Tower.hero_title(s)
	h.died.connect(func(_w, _k):
		Run.kills += 1
		Profile.record_add("kills", 1))
	_hero = h
	_pilot = pilot
	return true


## Retire l'ombre éveillée et son cerveau (étage suivant, fin).
func _free_hero() -> void:
	for n in [_hero, _pilot]:
		if is_instance_valid(n):
			n.queue_free()
	_hero = null
	_pilot = null


## Texte d'entrée d'un étage de héros : « Étage 4 · Duelliste 2/3\nPrêtre » ou « Étage 23 · Ombre\nOmbre · Mage ».
func _hero_intro(f: int) -> String:
	var s := Tower.spec(f)
	if is_instance_valid(_hero):
		s["kind"] = "brain"
	elif String(s.get("kind", "")) == "brain":
		s["kind"] = "class"
	if Tower.floor_type(f) == "duel":
		return "Étage %d · Duelliste %d/%d\n%s" % [f, Tower.duel_index(f), Tower.count_type("duel", 1, Tower.FLOORS), Tower.hero_title(s)]
	return "Étage %d · %s\n%s" % [f, Tower.TYPE_NAMES.shadow, Tower.hero_title(s)]


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
	BestTimes.tick(delta)  # temps de la partie (lot DNG-1 : records)
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
	_rescue_boss()
	_obj_t -= delta
	if _obj_t <= 0.0:
		_obj_t = 0.25
		d.objective_changed.emit(objective_text())


## Filet (passe M8) : un boss sorti de la salle (sous le sol ou au-delà du bord) tombait sans fin et ne pouvait plus être
## touché (vu au pilote : l'Homme de paille de l'étage 40, à 18 % de ses PV, des kilomètres plus bas trois minutes après) ;
## il revient au centre de la salle.
func _rescue_boss() -> void:
	if not is_instance_valid(_boss) or _boss.is_dead or d.map == null:
		return
	var off := _boss.global_position - _center
	if off.y < -6.0 or Vector2(off.x, off.z).length() > d.map.size * 0.5 + 4.0:
		_boss.global_position = _center + Vector3.UP * 0.5
		_boss.velocity = Vector3.ZERO


func _update_fight(delta: float) -> void:
	var f := Tower.floor_n
	var lvl := Tower.level_for(f)
	_spawn_t -= delta
	if left > 0 and _spawn_t <= 0.0 and alive() < Tower.max_alive(f):
		_spawn_t = SPAWN_EVERY
		var at := _ring(9.0, 22.0)
		for i in mini(3, left):
			if _mix.is_empty():
				_spawn(d._pick_monster(lvl), _ring(9.0, 22.0), lvl)
			else:
				_spawn_mixed(_next_species(), _near(at, 3.0), lvl)  # groupe mélangé, du même côté
			left -= 1
	if is_instance_valid(_hero) and not _hero.is_dead:
		return  # ombre éveillée encore debout
	if is_instance_valid(_boss) and not _boss.is_dead:
		_adds_t -= delta
		if _adds_on and _adds_t <= 0.0 and alive() < Tower.max_alive(f):
			_adds_t = BOSS_ADDS_EVERY
			for i in 3 + f / 40:
				_spawn(d._pick_monster(lvl), _ring(6.0, 12.0), maxi(1, lvl - 1))
		return
	if _elites_next > 0 and not _elites_alive.any(func(m): return is_instance_valid(m) and not m.is_dead):
		# donjon : l'élite suivante entre quand la précédente tombe (son escorte peut rester)
		_spawn_elite(f, _elites_alive.size(), lvl)
		_elites_next -= 1
		d.message.emit("Élite %d / %d" % [_elites_alive.size(), _elites_alive.size() + _elites_next], 2.0)
		return
	if left <= 0 and alive() == 0:
		_cleared()


func _cleared() -> void:
	var f := Tower.floor_n
	Tower.reached = f
	if not Tower.is_dungeon() and f % 10 == 0 and _block_from == f - 9:
		BestTimes.note(BestTimes.tower_key(Tower.difficulty, f / 10 - 1), "Étages %d-%d" % [f - 9, f], BestTimes.clock - _block_t0)
	d.player.heal(d.player.max_hp * 0.1)
	if _curse != "":
		Tower.cursed_cleared += 1  # cristaux en plus à la fin de l'ascension
	_free_hero()
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
				return "Étage %d · Vaincs %s" % [f, _boss.display_name.trim_prefix("<Boss> ")]
			if is_instance_valid(_hero) and not _hero.is_dead:
				return "Étage %d · Bats %s" % [f, _hero.display_name.trim_prefix("<Duel> ")]
			if is_instance_valid(_rival) and not _rival.is_dead:
				return "Étage %d · Bats %s" % [f, _rival.display_name.trim_prefix("<Duel> ")]
			if is_instance_valid(_lieutenant) and not _lieutenant.is_dead:
				return "%s %d · Vaincs %s" % [_room_word(), f, _lieutenant.display_name.trim_prefix("<Boss> ")]
			var elites := _elites_alive.filter(func(m): return is_instance_valid(m) and not m.is_dead).size()
			if Tower.is_dungeon() and elites > 0:  # une élite à la fois
				return "%s %d · Élite %d / %d" % [_room_word(), f, _elites_alive.size() - elites + 1, _elites_alive.size() + _elites_next]
			if elites > 0:
				return "%s %d · Élites : %d · Monstres restants : %d" % [_room_word(), f, elites, left + alive()]
			return "%s %d · Monstres restants : %d" % [_room_word(), f, left + alive()]
		"cards":
			if not Tower.is_dungeon() and Tower.floor_type(f) == "rest":
				return "Étage %d · Halte · Choisis une carte" % f
			return "%s %d %s · Choisis une carte" % [_room_word(), f, "vidée" if Tower.is_dungeon() else "vidé"]
		"chest":
			return "Ouvre le coffre au centre [%s]" % Settings.action_label("interact", 1)
		"stairs":
			if not Tower.is_dungeon() and f < Tower.top():
				return "Monte à l'étage %d · %s [%s]" % [f + 1, Tower.TYPE_NAMES.get(Tower.floor_type(f + 1), ""), Settings.action_label("interact", 1)]
			return "%s [%s]" % ["Passe à la salle suivante" if Tower.is_dungeon() else "Monte à l'étage %d" % (f + 1), Settings.action_label("interact", 1)]
	return "Sommet atteint"


## Horloge du HUD : « Étage 12/200 · Ombre » (Tour), « Salle 2/4 » (Donjons, Ruée) ; le Siège a la sienne.
func clock_text() -> String:
	if Tower.is_dungeon():
		return "%s %d/%d" % [_room_word(), Tower.floor_n, Tower.top()]
	return "Étage %d/%d · %s" % [Tower.floor_n, Tower.top(), Tower.TYPE_NAMES.get(Tower.floor_type(Tower.floor_n), "")]
