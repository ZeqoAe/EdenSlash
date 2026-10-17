extends Node
## Lot TAC-4 : kits tactiques et rééquilibrage de L'Assaut (data/assault_kits.json, AssaultCombat, profil « assault »).
## Kits des 60 classes (4 cases, prix, ultime, rôles) ; règles qui ne jouent QUE pendant une partie de L'Assaut : contrôles
## réduits et plafonnés, insensibilité commune, ténacité du Rempart, invisibilité bornée / refusée au porteur / brisée par un
## coup, boucliers bornés, soins plafonnés par manche (Soutien : moitié), chute de portée, effets des sorts des scriptés
## (Telegraph.applies), héros scripté armé de son kit ; partie réelle : passif de rôle du joueur, cible révélée par le Tireur.
## godot --headless --path game res://tests/test_tac4.tscn

var fails := 0


func check(label: String, ok: bool) -> void:
	print(("OK    " if ok else "ÉCHEC ") + label)
	if not ok:
		fails += 1


func _ready() -> void:
	Settings.reset_all()
	_kits()
	await _rules()
	await _world()
	print("TOUT EST OK (0 échec(s))" if fails == 0 else "ÉCHECS : %d" % fails)
	get_tree().quit(fails)


func _kits() -> void:
	var k := AssaultCombat.kits()
	var cids: Array = GameData.classes.keys()
	check("un kit par classe (%d / %d)" % [k.size() - 1, cids.size()], cids.all(func(c): return k.has(c)))
	var roles := {}
	var bad: Array = []
	for cid in cids:
		var kit: Dictionary = k[cid]
		var sl: Array = kit.slots
		roles[kit.role] = int(roles.get(kit.role, 0)) + 1
		var own: Array = GameData.class_data(cid).skills.map(func(s): return int(s.id))
		var ids: Array = sl.map(func(s): return int(s.id))
		var uniq := {}
		for i in ids:
			uniq[i] = true
		var ok: bool = sl.size() == 4 and uniq.size() == 4 and ids.all(func(i): return i in own) and bool(sl[0].get("free", false)) \
			and int(sl[1].get("price", 0)) in [200, 250, 300, 350] and int(sl[2].get("price", 0)) in [200, 250, 300, 350] \
			and bool(sl[3].get("ult", false)) and int(sl[3].get("points", 0)) == 7 and is_equal_approx(float(sl[3].get("radius_mult", 0.0)), 1.3) \
			and not String(sl[0].kind) in ["buff", "heal"]
		if not ok:
			bad.append(cid)
	check("4 cases distinctes, sorts de la classe, signature offensive gratuite, 2 cases à prix, ultime à 7 points (%s)" % str(bad), bad.is_empty())
	check("5 rôles tactiques : 9 Remparts, 18 Ouvreurs, 12 Tireurs, 9 Contrôleurs, 12 Soutiens (%s)" % str(roles),
		roles == {"rempart": 9, "ouvreur": 18, "tireur": 12, "controleur": 9, "soutien": 12})
	check("Assault.kit_for lit le kit", Assault.kit_for("cleric") == AssaultCombat.kit_ids("cleric") and Assault.kit_for("cleric").size() == 4)
	check("rôle du Guerrier : Rempart ; du Clerc : Soutien", AssaultCombat.role_of_class("warrior") == "rempart"
		and AssaultCombat.role_of_class("cleric") == "soutien")


func _dummy() -> Combatant:
	var c := Combatant.new()
	c.max_hp = 1000.0
	c.hp = 1000.0
	add_child(c)
	return c


func _rules() -> void:
	# hors Assaut : rien ne change
	var c := _dummy()
	check("hors Assaut : AssaultCombat éteint", not AssaultCombat.on())
	c.add_status("stun", 3.0)
	check("hors Assaut : renversement de 3 s tel quel", is_equal_approx(float(c.statuses.stun) - c.clock, 3.0))
	c.add_status("invisible", 8.0)
	check("hors Assaut : invisibilité de 8 s telle quelle", is_equal_approx(float(c.statuses.invisible) - c.clock, 8.0))
	c.queue_free()
	# en Assaut
	Assault.ensure_rules()
	TeamMatch.begin("assault", 2, {})
	PvpCaps.elapsed = 0.0
	check("en Assaut : AssaultCombat actif, profil assault", AssaultCombat.on() and ModeRules.profile_name() == "assault")
	c = _dummy()
	c.add_status("stun", 3.0)
	check("contrôle : 3 s × 0,5, plafond 1 s", is_equal_approx(float(c.statuses.stun) - c.clock, 1.0))
	c.add_status("freeze", 2.0)
	check("insensibilité commune : pas de gel pendant le renversement", not c.statuses.has("freeze"))
	check("insensibilité de tous les contrôles durs (1 + 2,5 s)", c.has_status("imm_cc") and is_equal_approx(float(c.statuses.imm_cc) - c.clock, 3.5))
	c.clock += 2.0
	c.add_status("fear", 3.0)
	check("terreur refusée tant que dure l'insensibilité", not c.has_status("fear"))
	c.clock += 2.0
	c.add_status("fear", 3.0)
	check("après l'insensibilité : terreur 3 s -> 1,2 s (plafond)", c.has_status("fear") and is_equal_approx(float(c.statuses.fear) - c.clock, 1.2))
	c.add_status("chill", 6.0)
	check("ralenti : 6 s × 0,5 -> 2 s au plus, pas d'insensibilité", c.has_status("chill") and is_equal_approx(float(c.statuses.chill) - c.clock, 2.0))
	check("ralenti borné à 30 %", is_equal_approx(AssaultCombat.chill_speed(), 0.7))
	c.queue_free()
	var t := _dummy()
	AssaultCombat.set_role(t, "rempart")
	t.add_status("stun", 1.5)
	check("ténacité du Rempart : 1,5 s × 0,5 × 0,8 = 0,6 s", is_equal_approx(float(t.statuses.stun) - t.clock, 0.6))
	t.set_meta("assault_tenacity_item", 0.3)
	check("ténacité : rôle et Talisman se multiplient (1 − 0,8 × 0,7)", is_equal_approx(AssaultCombat.tenacity(t), 0.44))
	t.queue_free()
	# invisibilité
	var v := _dummy()
	v.add_status("invisible", 8.0)
	check("invisibilité bornée à 2,5 s", is_equal_approx(float(v.statuses.invisible) - v.clock, 2.5))
	AssaultCombat.on_hit(null, v, false)
	check("un coup reçu brise l'invisibilité", not v.statuses.has("invisible"))
	v.set_meta("assault_busy", true)
	v.add_status("invisible", 8.0)
	check("porteur / pose / désamorçage : pas d'invisibilité", not v.statuses.has("invisible"))
	v.set_meta("assault_busy", false)
	# boucliers
	v.statuses["barrier"] = v.clock + 5.0
	check("barrière : dégâts subis × 0,8 (au lieu de 0,6)", is_equal_approx(v.damage_taken_mult(), 0.8))
	v.statuses["titan"] = v.clock + 5.0
	check("barrière + mur du titan : jamais sous × 0,6", is_equal_approx(v.damage_taken_mult(), 0.6))
	v.statuses.erase("barrier")
	v.statuses.erase("titan")
	# soins plafonnés par manche (soins du JcJ × 0,3 d'abord)
	v.hp = 100.0
	v.heal(4000.0)
	check("soins : plafond de 60 % des PV max par manche (%.0f)" % v.hp, is_equal_approx(v.hp, 700.0))
	v.heal(1000.0)
	check("plafond atteint : plus de soin", is_equal_approx(v.hp, 700.0) and is_equal_approx(AssaultCombat.heal_left(v), 0.0))
	var w := _dummy()
	w.hp = 100.0
	var healer := _dummy()
	AssaultCombat.set_role(healer, "soutien")
	AssaultCombat.healer = healer
	w.heal(1000.0)
	w.heal(1000.0)
	AssaultCombat.healer = null
	check("soins d'un Soutien : comptent moitié (600 rendus, la moitié du plafond)", is_equal_approx(w.hp, 700.0)
		and is_equal_approx(AssaultCombat.heal_left(w), 0.5))
	v.queue_free()
	w.queue_free()
	healer.queue_free()
	# chute de portée
	var a := _dummy()
	var b := _dummy()
	a.global_position = Vector3.ZERO
	b.global_position = Vector3(18, 0, 0)
	check("coup à 18 m : × 0,75 (au-delà de 16 m)", is_equal_approx(AssaultCombat.hit_mult(a, b), 0.75))
	AssaultCombat.set_role(a, "tireur")
	check("Tireur à 18 m : plein (20 m)", is_equal_approx(AssaultCombat.hit_mult(a, b), 1.0))
	b.global_position = Vector3(22, 0, 0)
	check("Tireur à 22 m : × 0,75", is_equal_approx(AssaultCombat.hit_mult(a, b), 0.75))
	a.queue_free()
	b.queue_free()
	# héros scripté armé de son kit, effets de ses sorts
	var r := TeamMatch.make_hero("warrior", 50, 2, 1)
	var hp0 := r.max_hp
	AssaultCombat.arm_rival(r, "warrior")
	add_child(r)
	var kit := AssaultCombat.kit_ids("warrior")
	var off: Array = r._skills.map(func(s): return int(s.id))
	check("scripté : ses sorts = les cases offensives 1-3 du kit, sans l'ultime (%s)" % str(off),
		off.all(func(i): return i in kit.slice(0, 3)) and not kit[3] in off and not off.is_empty())
	check("scripté Rempart : PV × 1,2", is_equal_approx(r.max_hp, hp0 * 1.2) and AssaultCombat.role(r) == "rempart")
	var o := TeamMatch.make_hero("assassin", 50, 2, 0)
	var ch0 := int(o.cfg.charges)
	AssaultCombat.arm_rival(o, "assassin")
	check("scripté Ouvreur : une esquive de plus", int(o.cfg.charges) == ch0 + 1 and int(ClassRival.DIFF[2].charges) == ch0)
	o.free()
	var tg := Telegraph.new()
	tg.applies = {"stun": 2.0, "bleed": 4.0}
	tg._apply_effects(r, null)
	check("effets d'un sort de scripté posés sur la cible, règles du mode (Rempart : 2 s × 0,5 × 0,8 = 0,8 s)", r.has_status("stun")
		and is_equal_approx(float(r.statuses.stun) - r.clock, 0.8) and r.has_status("bleed"))
	tg.free()
	r.queue_free()
	await get_tree().process_frame
	TeamMatch.end()
	check("partie close : AssaultCombat éteint", not AssaultCombat.on())


func _world() -> void:
	Profile.selected_class = "warrior"
	Assault.launch("warrior", {"map": "bourg", "seed": 9, "speed": 1.0, "win": 1, "buy_time": 600.0, "buy_time_first": 600.0})
	var world: Node = load("res://scenes/world.tscn").instantiate()
	get_tree().root.add_child.call_deferred(world)
	await _until(func(): return world.is_inside_tree() and world.get("director") != null and is_instance_valid(world.director.team), 600)
	await _until(func(): return world.director.map != null and world.director.map._region.navigation_mesh != null, 3600)
	var dd: AssaultDirector = world.director.team
	var p: Player = world.player
	var sheet := TeamMatch.hero_sheet("warrior", 50)
	var base := sheet.max_hp
	sheet.free()
	check("joueur Rempart (Guerrier) : passif posé, PV × 1,2 (%.0f contre %.0f)" % [p.max_hp, base], AssaultCombat.role(p) == "rempart"
		and absf(p.max_hp - base * 1.2) < base * 0.02)
	check("kit du joueur : les 4 sorts du kit", Run.skills.map(func(s): return int(s.id)) == AssaultCombat.kit_ids("warrior"))
	var ult: Dictionary = GameData.class_data("warrior").skills.filter(func(s): return int(s.id) == AssaultCombat.ult_id("warrior"))[0]
	var km := p.reach_mult if String(ult.kind) in ["fan", "line", "dash"] else p.area_mult
	check("ultime : zone × 1,3", is_equal_approx(p.skill_radius(ult), float(ult.radius) * km * 1.3))
	check("chaque scripté a son rôle", dd.heroes.keys().all(func(k): return dd.hero(String(k)) == null or AssaultCombat.role(dd.hero(String(k))) != ""))
	# cible révélée (Tireur) : un adversaire hors de vue, révélé 1,5 s à l'équipe 0
	var foe: Combatant = null
	for k in Assault.members[1]:
		foe = dd.hero(String(k))
		break
	var far: Vector3 = dd.layout.spawns.attack.pos if Assault.attack == 1 else dd.layout.spawns.defense.pos  # (départ de l'équipe 1)
	for k in Assault.members[0]:
		var h := dd.hero(String(k))
		if h != null and h != p:
			h.global_position = (dd.layout.spawns.attack.pos if Assault.attack == 0 else dd.layout.spawns.defense.pos) + Vector3.UP * 0.5
	p.global_position = (dd.layout.spawns.attack.pos if Assault.attack == 0 else dd.layout.spawns.defense.pos) + Vector3(0, 0.5, 2)
	foe.global_position = far + Vector3.UP * 0.5
	await _secs(0.4)
	check("adversaire au loin : pas vu", not dd.vision.sees(0, foe))
	dd.vision.reveal(0, foe, 1.5, p)
	await _secs(0.3)
	check("révélé (cible du Tireur) : vu par l'équipe", dd.vision.sees(0, foe))
	await _secs(1.6)
	check("après 1,5 s : plus vu", not dd.vision.sees(0, foe))
	TeamMatch.abandon()
	await _until(func(): return dd._ended, 300)
	get_tree().paused = false
	world.queue_free()
	await get_tree().process_frame
	Run.active = false
	Profile.in_run = false


## [param s] s de jeu (images de physique à 60 par seconde).
func _secs(s: float) -> void:
	for _i in int(s * 60.0):
		await get_tree().physics_frame


func _until(cond: Callable, max_frames := 300) -> void:
	for _i in max_frames:
		if cond.call():
			return
		await get_tree().physics_frame
