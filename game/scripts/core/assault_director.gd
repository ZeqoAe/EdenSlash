class_name AssaultDirector
extends Node
## Directeur de scène de L'Assaut (lot TAC-0, rapport conception/benchmark/R_TAC_0.md) : monté par TeamMatch.mount depuis
## RunDirector.start (état « team ») ; tient la carte, les 8 héros (toi + 3 alliés IA contre 4 IA, ou 8 IA en mode
## spectateur), la machine de manche pure Assault (achat -> manche -> pose / désamorçage -> fin -> mi-temps /
## prolongation) et sa fin de partie. world.gd lui rend la mort du joueur (player_down) et l'abandon (abandon).
##
## Options de la partie (TeamMatch.spec, posées par Assault.launch) : map (« bourg », par défaut, lot TAC-1 ; « arena » : arène
## simple du lot TAC-0), format, diff_allies / diff_foes (0-3), watch (vrai : le joueur regarde 8 IA), first_attack,
## seed, speed (Engine.time_scale, mesures), allies / foes (classes imposées), et toute règle de Assault.RULES.
##
## Charge (lot TAC-3, R_TAC_3.md) : objet AssaultCharge porté par un attaquant (_pick_carrier), lâché à sa mort ou par [G],
## ramassé en passant (pickup_radius), posé (pose annulée par un pas, un coup, un sort, une esquive ou un contrôle subi),
## bips qui accélèrent, explosion qui emporte les héros proches (blast_radius), désamorçage sauvegardé à la moitié ; la
## Défense ne voit la Charge au sol que si elle voit l'endroit (charge_seen) ; mini-carte : markers().
##
## IA (lot TAC-0, provisoire) : un agent minimal par héros scripté (_agent) — les attaquants vont ensemble au site de la
## manche, le porteur pose quand rien ne le menace, les défenseurs tiennent 2-2 puis reprennent le site de la Charge ;
## Charge au sol : l'attaquant le plus proche va la ramasser, un défenseur qui la voit va la garder ;
## dès qu'un adversaire est assez proche, ClassRival combat. Le stratège d'équipe et la perception honnête : lot TAC-6
## (la perception de ce que l'équipe voit et entend est fournie par AssaultVision, lot TAC-2).

const ENGAGE := 16.0  # m : un adversaire plus proche que ça est combattu (agent provisoire ; TAC-6 : ce que l'équipe voit)
const THREAT := 9.0  # m : un adversaire plus proche que ça empêche l'IA de poser ou de désamorcer
const AGENT_EVERY := 0.2
const SPAWN_GAP := 2.6  # m entre deux héros au départ

var d: RunDirector
var map: Node3D
## Carte : {id, name, sites: {A: {pos, radius}, B}, spawns: {attack: {pos, half}, defense: {pos, half}}, places: [{name, pos}]}.
var layout: Dictionary = {}
var heroes: Dictionary = {}  # clé -> Combatant (le joueur compris)
var classes: Dictionary = {}  # clé -> classe
var player_key := ""
var watch := false
## Pendant l'achat, le joueur reste dans son départ (faux : tests qui le placent).
var barrier := true
var diffs := [2, 2]
var rng := RandomNumberGenerator.new()
## Charge (lot TAC-3, AssaultCharge) : l'objet (porté, au sol, posé), son porteur ("" : au sol ou posée), pose et
## désamorçage en cours. Le porteur est choisi au début de chaque manche (_pick_carrier : toi si tu attaques, sinon un
## attaquant scripté qui n'ouvre pas) ; il la lâche à sa mort ([G] pour le joueur) et un attaquant la ramasse en passant.
var charge: AssaultCharge
var carrier := ""
## Héros pris dans l'explosion de la manche (ils ne « survivent » pas : lot TAC-5, ce qu'on garde).
var blasted: Array = []
var _ten_said := false
var _defuse_said := false
var _fuse_at_defuse := INF
var plant_by := ""
var plant_t := 0.0
var defuse_by := ""
var defuse_t := 0.0
var charge_pos := Vector3.INF
var target_site := "A"  # site visé par l'Attaque cette manche
var _agent_t := 0.0
var _obj_t := 0.0
var _prompt := ""
## Dégâts de la manche : victime -> {auteur: dégâts} (aides : >= 30 % des PV de la victime).
var _dmg: Dictionary = {}
var _markers: Node3D
## Vue d'équipe, brouillard, voile et bruits (lot TAC-2) ; « Voir les sons » de ton équipe.
var vision: AssaultVision
var cues: AssaultCues
var _plant_noise_t := 0.0
var _ended := false
## Événements de la machine vus par le directeur (tests, mesures).
var events: Array = []
var round_lines: Array = []
## Mesures du combat (lot TAC-4) : temps de survie de chaque héros tombé, du premier coup reçu à pleine vie jusqu'à la chute (s).
var survival: Array = []
var _hurt_t0: Dictionary = {}
## Coups entre équipiers relevés (doit rester à 0 : aucun tir ami).
var friendly_hits := 0


func setup(director: RunDirector) -> void:
	d = director
	var spec: Dictionary = TeamMatch.spec
	rng.seed = int(spec.get("seed", randi()))
	watch = bool(spec.get("watch", false))
	diffs = [clampi(int(spec.get("diff_allies", 2)), 0, 3), clampi(int(spec.get("diff_foes", 2)), 0, 3)]
	if spec.has("speed"):
		Engine.time_scale = float(spec.speed)
	d.zone = GameData.zone(Run.zone_id)
	_build_map(String(spec.get("map", "bourg")))  # (le Bourg par défaut ; « arena » : l'arène d'essai du lot TAC-0)
	vision = AssaultVision.new()
	d.add_child(vision)
	vision.setup(map, self)
	_build_cues()
	_compose_teams(spec)
	var keys := [[], []]
	for t in 2:
		for i in 4:
			keys[t].append("t%d_%d" % [t, i])
	var o: Dictionary = {}
	for k in Assault.RULES:
		if spec.has(k):
			o[k] = spec[k]
	for k in ["format", "first_attack", "seed"]:
		if spec.has(k):
			o[k] = spec[k]
	Assault.begin(keys, o)
	AssaultItems.reset_all(Assault.members[0] + Assault.members[1])  # (lot TAC-5) paquetages de la partie
	d.zone_changed.emit({"name": TeamMatch.title(), "levels": [int(Assault.num("level")), int(Assault.num("level"))]})
	_start_round()


# --- carte ---------------------------------------------------------------------------------------

func _build_map(id: String) -> void:
	var m := ProcMap.new()
	m.biome = String(GameData.zone(Run.zone_id).get("biome", "limestone"))
	m.name = "AssaultMap"
	d.world._swap_map(m)
	if m.has_method("generate_assault") and id != "arena":
		m.call("generate_assault", id)
		layout = m.get("assault")
	else:
		m.generate_arena(rng.randi(), "pillars")
		layout = _arena_layout(m)
	map = m
	d.map = m
	d.world._apply_biome_env()
	_build_markers()


## Arène simple du lot TAC-0 (cuvette à piliers de 96 m) : deux sites de part et d'autre du centre, départs face à face.
func _arena_layout(m: ProcMap) -> Dictionary:
	var r := Assault.num("site_radius")
	return {"id": "arena", "name": "Arène d'essai",
		"sites": {"A": {"pos": _at(m, -13.0, -6.0), "radius": r}, "B": {"pos": _at(m, 13.0, -6.0), "radius": r}},
		"spawns": {"defense": {"pos": _at(m, 0.0, -18.0), "half": Vector2(5, 2.5)},
			"attack": {"pos": _at(m, 0.0, 20.0), "half": Vector2(5, 2.5)}},
		"places": [{"name": "Site A", "pos": _at(m, -13.0, -6.0)}, {"name": "Site B", "pos": _at(m, 13.0, -6.0)},
			{"name": "Centre", "pos": _at(m, 0.0, 0.0)}]}


## Point au sol de l'arène, à ([param dx], [param dz]) m de son centre.
func _at(m: ProcMap, dx: float, dz: float) -> Vector3:
	var p := Vector3(m.size * 0.5 + dx, 0, m.size * 0.5 + dz)
	p.y = m.height_at(p.x, p.z)
	return p


## Repères des sites (disque soleil et lettre) ; la Charge a son propre nœud (AssaultCharge, lot TAC-3).
func _build_markers() -> void:
	_markers = Node3D.new()
	_markers.name = "AssaultMarkers"
	d.add_child(_markers)
	for s in Assault.SITES:
		var sd: Dictionary = layout.sites[s]
		var disk := MeshInstance3D.new()
		if sd.has("rect"):
			var pm := PlaneMesh.new()  # (carte faite à la main : le rectangle du site, lot TAC-1)
			pm.size = (sd.rect as Rect2).size
			disk.mesh = pm
		else:
			var cyl := CylinderMesh.new()
			cyl.top_radius = float(sd.radius)
			cyl.bottom_radius = float(sd.radius)
			cyl.height = 0.04
			disk.mesh = cyl
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_color = Color(UiTheme.color("bonbon.soleil.base"), 0.22)
		disk.material_override = mat
		disk.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_markers.add_child(disk)
		disk.global_position = (sd.pos as Vector3) + Vector3.UP * 0.06
		if sd.has("rect"):
			var rc: Vector2 = (sd.rect as Rect2).get_center()
			disk.global_position = Vector3(rc.x, map.height_at(rc.x, rc.y) + 0.06, rc.y)
		var l := Label3D.new()
		l.text = s
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.font_size = 160
		l.pixel_size = 0.01
		l.outline_size = 24
		l.modulate = UiTheme.color("bonbon.soleil.base")
		l.outline_modulate = UiTheme.color("encre.900", Color("221a3a"))
		_markers.add_child(l)
		l.global_position = (sd.pos as Vector3) + Vector3.UP * 4.0


func site_pos(s: String) -> Vector3:
	return layout.sites[s].pos


func site_radius(s: String) -> float:
	return float(layout.sites[s].radius)


## Site où se tient [param p] ("" : aucun).
func site_at(p: Vector3) -> String:
	for s in Assault.SITES:
		var sd: Dictionary = layout.sites[s]
		if sd.has("rect"):
			if (sd.rect as Rect2).has_point(Vector2(p.x, p.z)):
				return s  # (cartes faites à la main : le rectangle du site, lot TAC-1)
			continue
		var q := site_pos(s)
		if Vector2(p.x - q.x, p.z - q.z).length() <= site_radius(s):
			return s
	return ""


func _ground(p: Vector3) -> Vector3:
	var g: Vector3 = map.ground_at(p.x, p.z)
	if g == Vector3.INF:
		return p
	if map.has_method("floor_at"):
		g.y = float(map.call("floor_at", p.x, p.z, g.y))
	return g


# --- équipes -------------------------------------------------------------------------------------

## Équipe 0 = la tienne (ta classe + 3 alliés), équipe 1 = l'autre ; une classe au plus une fois par équipe.
func _compose_teams(spec: Dictionary) -> void:
	var mine: Array = spec.get("allies", [])
	var me := Run.class_id
	if mine.is_empty():
		mine = Assault.pick_classes(rng, 3, [me])
	var theirs: Array = spec.get("foes", [])
	if theirs.is_empty():
		theirs = Assault.pick_classes(rng, 4)
	classes = {}
	for i in 4:
		classes["t0_%d" % i] = String(me if i == 0 else mine[i - 1])
		classes["t1_%d" % i] = String(theirs[i])
	if watch:
		classes["t0_0"] = String(Assault.pick_classes(rng, 1, mine + theirs)[0]) if me in Assault.AI_EXCLUDED else me
	player_key = "" if watch else "t0_0"
	var p := d.player
	var lv := int(Assault.num("level"))
	p.level = lv
	Run.hero_level = lv
	Run.max_level = lv
	if not watch:
		AssaultCombat.set_role(p, AssaultCombat.role_of_class(Run.class_id))  # (lot TAC-4) rôle tactique et passif
	p.recalc_stats()
	p.hp = p.max_hp
	if watch:
		# IA contre IA (mesures, test_tac0) : le joueur regarde ; son héros est mis à l'écart, hors de tout camp
		p.visible = false
		p.process_mode = Node.PROCESS_MODE_DISABLED
		p.global_position = Vector3(-50, -20, -50)
	else:
		TeamMatch.add(p, 0)
		heroes[player_key] = p
		_watch_hero(p, player_key)


## Nouvelle manche : héros scriptés recréés (une vie, PV pleins), le joueur relevé, chacun dans son départ.
func _start_round() -> void:
	for k in heroes.keys():
		if k == player_key:
			continue
		var h := hero(String(k))  # (un héros tombé a pu être libéré)
		if h != null:
			TeamMatch.remove(h)
			h.queue_free()
		heroes.erase(k)
	for tm in TeamMatch.teams:
		tm.members = (tm.members as Array).filter(func(c): return is_instance_valid(c))  # (héros libérés de la manche passée)
	_dmg = {}
	_hurt_t0 = {}
	PvpCaps.board = {}
	PvpCaps.elapsed = 0.0
	plant_by = ""
	plant_t = 0.0
	defuse_by = ""
	defuse_t = 0.0
	charge_pos = Vector3.INF
	blasted = []
	_ten_said = false
	_defuse_said = false
	target_site = Assault.SITES[rng.randi() % 2]
	for t in 2:
		for i in 4:
			var key := "t%d_%d" % [t, i]
			var at := _spawn_point(t, i)
			if key == player_key:
				var p := d.player
				if p.is_dead:
					p.respawn(at)
				d._place_player(at)
				p.heal(p.max_hp)
				p.skill_ready_at.clear()
				p.statuses.clear()
				p.set_meta("assault_healed", 0.0)  # (lot TAC-4) plafond de soins remis à chaque manche
				continue
			var r := TeamMatch.make_hero(String(classes[key]), int(Assault.num("level")), int(diffs[t]), t)
			AssaultCombat.arm_rival(r, String(classes[key]), owned_slots(key))  # (lot TAC-4) kit tactique, rôle et passifs
			d.add_child(r)
			r.global_position = at + Vector3.UP * 0.4
			r.passive = true  # derrière la barrière pendant l'achat
			heroes[key] = r
			_watch_hero(r, key)
	_new_charge()
	TeamMatch.start_round()
	TeamMatch.set_phase("countdown")
	if d.world.rig != null:
		d.world.rig.target = d.player if not watch else _first_alive(0)
	var side := Assault.side_name(0)
	var goal_txt := "pose la Charge en A ou en B" if Assault.attack == 0 else "défends A et B"
	if carrier == player_key and player_key != "":
		goal_txt = "tu portes la Charge : pose-la en A ou en B"
	d.message.emit("Manche %d · %s · %d - %d\n%s" % [Assault.round_n, side, int(Assault.score[0]), int(Assault.score[1]),
		goal_txt], 2.5)
	if _verbose():
		print("[assault] manche %d : équipe 0 en %s, site visé %s, or moyen %d / %d" % [Assault.round_n, side.to_lower(),
			target_site, _avg_gold(0), _avg_gold(1)])
	_buy_phase_start()  # (lot TAC-5) plans d'équipe, achats des IA, écran d'achat


func _avg_gold(t: int) -> int:
	var s := 0
	for k in Assault.members[t]:
		s += Assault.gold(String(k))
	return int(s / 4.0)


## Départ du héros [param i] de l'équipe [param t] (côté attaque ou défense de la manche), sur une rangée.
func _spawn_point(t: int, i: int) -> Vector3:
	var sp: Dictionary = layout.spawns["attack" if t == Assault.attack else "defense"]
	var c: Vector3 = sp.pos
	return _ground(c + Vector3((i - 1.5) * SPAWN_GAP, 0, 0))


func _watch_hero(c: Combatant, key: String) -> void:
	c.set_meta("assault_key", key)
	if c.has_meta("assault_watched"):
		return  # (le joueur : relié une fois pour toute la partie)
	c.set_meta("assault_watched", true)
	c.died.connect(_on_died)
	c.damaged.connect(_on_damaged.bind(c))


func key_of(c: Combatant) -> String:
	return String(c.get_meta("assault_key", "")) if is_instance_valid(c) else ""


func hero(key: String) -> Combatant:
	var h = heroes.get(key)  # (non typé : un héros scripté tombé est libéré après son animation de mort)
	return h as Combatant if is_instance_valid(h) else null


func _first_alive(t: int) -> Combatant:
	for k in Assault.alive_keys(t):
		if hero(String(k)) != null:
			return hero(String(k))
	return null


func _on_damaged(amount: float, src: Combatant, victim: Combatant) -> void:
	var vk := key_of(victim)
	var sk := key_of(src)
	if vk != "" and (victim.hp + amount >= victim.max_hp * 0.98 or not _hurt_t0.has(vk)):
		_hurt_t0[vk] = TeamMatch.elapsed  # (lots TAC-4 / TAC-5) premier coup reçu à pleine vie, objets compris : début du temps de survie
	if vk == "" or sk == "" or vk == sk:
		return
	if Assault.team_of(vk) == Assault.team_of(sk):
		friendly_hits += 1
	if not _dmg.has(vk):
		_dmg[vk] = {}
	_dmg[vk][sk] = float(_dmg[vk].get(sk, 0.0)) + amount
	if src != null and is_instance_valid(src):
		PvpCaps.board_add(src, "dealt", amount)


func _on_died(who: Combatant, killer: Combatant) -> void:
	var vk := key_of(who)
	if vk == "" or vk == player_key:
		return  # le joueur : player_down (world.gd)
	_ko(vk, killer)


func _ko(vk: String, killer: Combatant) -> void:
	var kk := key_of(killer) if killer != null else ""
	var assists: Array = []
	var v := hero(vk)
	var cap := (v.max_hp if v != null else 1.0) * 0.3
	for a in _dmg.get(vk, {}):
		if a != kk and float(_dmg[vk][a]) >= cap:
			assists.append(a)
	_add_ult(vk)  # (lot TAC-5) points d'ultime : la chute et l'élimination
	if kk != "":
		_add_ult(kk)
	if v != null:
		TeamMatch.note_ko(v, killer)
		if _hurt_t0.has(vk) and kk != "":
			survival.append(snappedf(TeamMatch.elapsed - float(_hurt_t0[vk]), 0.01))
	if vk == carrier:
		_drop_charge(v.global_position if v != null else charge.global_position, "fall")  # la Charge tombe et se ramasse
	if vk == plant_by:
		plant_by = ""
		plant_t = 0.0
	if vk == defuse_by:
		_stop_defuse()
	if _verbose():
		print("[assault] %s (%s) tombe, par %s" % [vk, classes.get(vk, "?"), kk if kk != "" else "le décor"])
	_handle(Assault.ko(vk, kk, assists))


# --- boucle ----------------------------------------------------------------------------------------

## Mesure de l'image (--assault-perf) : durée de chaque image (s), temps des scripts et de la physique (ms), pendant la manche.
var perf: Array = []
var _perf_on := "--assault-perf" in OS.get_cmdline_user_args()


func update(delta: float) -> void:
	if _ended:
		return
	if _perf_on and Assault.phase in ["live", "planted"]:
		perf.append([delta / maxf(Engine.time_scale, 0.01), Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
			Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0, float(vision.stats.ms) if vision != null else 0.0])
	TeamMatch.elapsed += delta
	if Assault.phase in ["live", "planted"]:
		PvpCaps.elapsed += delta
	if Assault.phase == "buy":
		_hold_in_spawn()
	_handle(Assault.tick(delta))
	if _ended:
		return
	_items_tick(delta)
	_update_charge(delta)
	if Assault.phase in ["live", "planted"]:
		_agent_t -= delta
		if _agent_t <= 0.0:
			_agent_t = AGENT_EVERY
			for k in heroes:
				if k != player_key:
					_agent(String(k))
		_player_actions(delta)
		_ai_actions(delta)
	_obj_t -= delta
	if _obj_t <= 0.0:
		_obj_t = 0.25
		d.objective_changed.emit(objective_text())
	if _trace:
		_trace_t -= delta
		if _trace_t <= 0.0:
			_trace_t = 2.0
			_print_trace()


var _trace := "--trace" in OS.get_cmdline_user_args()
var _trace_t := 0.0


## Mesures (--trace) : toutes les 2 s, chaque héros : position, but, état, cible, PV.
func _print_trace() -> void:
	var parts: Array = []
	for k in heroes:
		var h := hero(String(k))
		if h == null:
			parts.append("%s:libéré" % k)
			continue
		var r := h as ClassRival
		var g := "-" if r == null or r.goal == Vector3.INF else "(%.0f,%.0f)" % [r.goal.x, r.goal.z]
		parts.append("%s%s:(%.0f,%.0f)>%s %s pv%d%s" % [k, "*" if k == carrier else "", h.global_position.x, h.global_position.z, g,
			r._state if r != null else "joueur", int(h.hp), " passif" if r != null and r.passive else ""])
	print("[assault] t=%.1f %s plant=%s %.1f vision=%.2f ms | %s" % [Assault.round_time, Assault.phase, plant_by, plant_t,
		float(vision.stats.ms) if vision != null else 0.0, " ".join(parts)])


## Ligne d'objectif du HUD : manche, côté, score, temps ou mèche.
func objective_text() -> String:
	var secs := maxf(Assault.t, 0.0)
	var clock := "%d:%02d" % [int(secs) / 60, int(secs) % 60]
	match Assault.phase:
		"buy":
			return "Manche %d · %s · achat %s" % [Assault.round_n, Assault.side_name(0), clock]
		"planted":
			return "Charge posée en %s · %s" % [Assault.site, clock]
	return "Manche %d · %s · %d - %d · %s" % [Assault.round_n, Assault.side_name(0), int(Assault.score[0]), int(Assault.score[1]), clock]


func _handle(ev: Array) -> void:
	for e in ev:
		events.append(e)
		match String(e.type):
			"live":
				for k in heroes:
					var h := hero(String(k))
					if h is ClassRival:
						(h as ClassRival).passive = false
				TeamMatch.set_phase("fight")
				_close_shop()  # (lot TAC-5) la manche commence : l'écran d'achat se ferme, le paquetage s'applique
				for k in heroes:
					_apply_kit(String(k))
				d.message.emit("C'est parti !", 1.2)
				UiFeel.cue("ui_go", -8.0)
			"planted":
				charge.plant_at(charge_pos, String(e.site), Assault.num("fuse"))
				d.message.emit("Charge posée en %s !" % String(e.site), 2.5)
				UiFeel.cue("ui_banner", -6.0, 1.0, [0.3, 0.2, 0.15])
			"explode":
				_explode()
			"defused":
				charge.defuse()
				var close := _fuse_at_defuse < 1.0
				d.message.emit("Ouf ! Charge désamorcée !" if close else "Charge désamorcée !", 2.0)
				UiFeel.cue("ui_star" if close else "ui_notify", -6.0)
			"round_end":
				_end_round(e)
			"next":
				_start_round()
			"done":
				_finish()


func _end_round(e: Dictionary) -> void:
	var w := int(e.winner)
	_round_inventory()  # (lot TAC-5) qui tombe perd son paquetage
	for k in heroes:
		var h := hero(String(k))
		if h is ClassRival:
			(h as ClassRival).passive = true
			(h as ClassRival).goal = Vector3.INF
	plant_by = ""
	_stop_defuse()
	TeamMatch.end_round(w, {"how": e.how, "attack": Assault.attack})
	var line := "manche %d gagnée par l'équipe %d (%s, %s) en %.1f s : %d - %d" % [int(e.round), w,
		"attaque" if w == Assault.attack else "défense", Assault.HOW[String(e.how)].to_lower(), Assault.round_time,
		int(Assault.score[0]), int(Assault.score[1])]
	round_lines.append(line)
	if _verbose():
		print("[assault] " + line)
	var mine := w == TeamMatch.player_team
	var how := String(Assault.HOW[String(e.how)])
	if int(e.match) >= 0:
		d.message.emit(("VICTOIRE ! " if int(e.match) == TeamMatch.player_team else "DÉFAITE… ") + "%d - %d" % [int(Assault.score[0]), int(Assault.score[1])], 3.0)
	else:
		d.message.emit("%s · %s\n%d - %d" % ["Manche gagnée !" if mine else "Manche perdue…", how, int(Assault.score[0]), int(Assault.score[1])], 3.0)


## Pendant l'achat, le joueur reste dans son départ (barrière d'encre : lot TAC-7).
func _hold_in_spawn() -> void:
	if player_key == "" or d.player.is_dead or not barrier:
		return
	var sp: Dictionary = layout.spawns["attack" if Assault.attack == 0 else "defense"]
	var c: Vector3 = sp.pos
	var half: Vector2 = sp.half
	var p := d.player.global_position
	var q := Vector3(clampf(p.x, c.x - half.x - 1.5, c.x + half.x + 1.5), p.y, clampf(p.z, c.z - half.y - 1.5, c.z + half.y + 1.5))
	if q.distance_to(p) > 0.01:
		d.player.global_position = q


# --- agent provisoire (lot TAC-6 : AssaultBrain + AssaultAgent) ------------------------------------

## Adversaire combattu par [param h] : le plus proche à moins de ENGAGE m (lot TAC-2 : seulement ce que son équipe voit).
func engaged_foe(h: Combatant, within := ENGAGE) -> Combatant:
	var best: Combatant = null
	var bd := within
	for f in Combatant.ffa_foes(get_tree(), h):
		var c := f as Combatant
		if not can_perceive(h, c):
			continue
		var dd := h.global_position.distance_to(c.global_position)
		if dd < bd:
			bd = dd
			best = c
	return best


## [param h] perçoit-il [param c] ? Ce que son équipe voit, ou ce qui le touche presque (AssaultVision, lot TAC-2).
func can_perceive(h: Combatant, c: Combatant) -> bool:
	return h != null and c != null and AssaultVision.perceives(h, c)


## Héros dont l'écran montre la vue (voile, sons, ce qui est caché) : le joueur, ou celui que suit la caméra.
func view_hero() -> Combatant:
	var p := d.player
	if player_key != "" and not p.is_dead:
		return p
	var t = d.world.rig.target if d.world.rig != null else null
	if is_instance_valid(t) and t is Combatant and not (t as Combatant).is_dead and t != p:
		return t
	return _first_alive(0)


## « Voir les sons » (activé dans ce mode) : un calque au-dessus du monde, sous le HUD.
func _build_cues() -> void:
	var layer := CanvasLayer.new()
	layer.name = "AssaultCuesLayer"
	layer.layer = 4
	d.add_child(layer)
	cues = AssaultCues.new()
	layer.add_child(cues)
	cues.setup_assault(vision)


func _agent(key: String) -> void:
	var r := hero(key) as ClassRival
	if r == null or r.is_dead:
		return
	var t := Assault.team_of(key)
	_ai_ult_check(r, key)  # (lot TAC-5) ultime parti, objets
	_ai_items(r, key)
	if engaged_foe(r) != null and key != plant_by and key != defuse_by:
		r.goal = Vector3.INF
		return
	r.goal = _goal_for(key, t)


## Point à tenir ou à rejoindre pour [param key] (équipe [param t]).
func _goal_for(key: String, t: int) -> Vector3:
	var i := int(key.right(1))
	var off := Vector3(cos(i * 1.7) * 2.2, 0, sin(i * 1.7) * 2.2)
	if Assault.phase == "planted":
		if t == Assault.defense() and key == _defuser():
			return charge_pos  # (le désamorceur s'arrête à moins de 1,2 m : dans la portée de désamorçage)
		return _ground(charge_pos + off * 1.6)
	if charge != null and charge.state == "ground":
		# (lot TAC-3) Charge au sol : l'attaquant le plus proche va la ramasser ; un défenseur qui la voit va la garder
		if t == Assault.attack and key == _fetcher():
			return charge.global_position
		if t == Assault.defense() and key == _guard():
			return _ground(charge.global_position + off * 2.5)
	if t == Assault.attack:
		if key == carrier:
			return _ground(site_pos(target_site))
		return _ground(site_pos(target_site) + off * 1.4)
	# Défense : 2-2 (A, B) ; le lot TAC-6 décide des empilements et des rotations
	return _ground(site_pos("A" if i % 2 == 0 else "B") + off)


## Défenseur qui va désamorcer : celui qui désamorce déjà, sinon le défenseur scripté debout le plus proche de la Charge.
func _defuser() -> String:
	if defuse_by != "":
		return defuse_by
	var best := ""
	var bd := INF
	for k in Assault.alive_keys(Assault.defense()):
		var h := hero(String(k))
		if h == null or String(k) == player_key:
			continue
		var dd := _dist2(h.global_position, charge_pos)
		if dd < bd:
			bd = dd
			best = String(k)
	return best


## Pose et désamorçage des héros scriptés : immobiles dans la zone, sans adversaire menaçant.
func _ai_actions(delta: float) -> void:
	if Assault.phase == "live":
		var c := hero(carrier) as ClassRival
		if c != null and not c.is_dead and site_at(c.global_position) != "" and engaged_foe(c, THREAT) == null \
				and not _interrupted(c) and c._state != "attack":
			if plant_by != carrier:
				plant_by = carrier
				plant_t = 0.0
			c.goal = c.global_position
			_progress_plant(c, delta)
		elif plant_by != "" and plant_by == carrier and plant_by != player_key:
			plant_by = ""
			plant_t = 0.0
	elif Assault.phase == "planted":
		if defuse_by != "" and defuse_by != player_key:
			var dh := hero(defuse_by) as ClassRival
			if dh == null or dh.is_dead or _interrupted(dh) or dh._state == "attack" \
					or _dist2(dh.global_position, charge_pos) > Assault.num("defuse_range") + 0.4:
				_stop_defuse()
			else:
				_progress_defuse(dh, delta)
			return
		if defuse_by == "":
			for k in Assault.alive_keys(Assault.defense()):
				var r := hero(String(k)) as ClassRival
				if r != null and _dist2(r.global_position, charge_pos) <= Assault.num("defuse_range") and engaged_foe(r, THREAT) == null \
						and not _interrupted(r):
					defuse_by = String(k)
					defuse_t = Assault.defuse_resume(defuse_t, _defuse_full())
					r.goal = r.global_position
					break


func _dist2(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _progress_plant(c: Combatant, delta: float) -> void:
	_charge_noise(c, "plant", plant_t, delta)
	plant_t += delta
	if plant_t >= _plant_full(key_of(c)):
		charge_pos = _ground(c.global_position)
		var s := site_at(c.global_position)
		plant_by = ""
		plant_t = 0.0
		carrier = ""
		_add_ult(key_of(c))  # (lot TAC-5) un point d'ultime à la pose
		_handle(Assault.plant(s, key_of(c)))


## Pose et désamorçage s'entendent sur toute la carte, avec la direction (TACTIQUE § 7.7) : au début, puis toutes les 1,5 s.
func _charge_noise(c: Combatant, kind: String, done: float, delta: float) -> void:
	_plant_noise_t -= delta
	if done <= 0.0 or _plant_noise_t <= 0.0:
		_plant_noise_t = 1.5
		if vision != null:
			vision.noise(c.global_position, kind, Assault.team_of(key_of(c)), INF)
	if kind == "defuse" and not _defuse_said and player_key != "" and Assault.team_of(player_key) == Assault.attack:
		_defuse_said = true
		d.message.emit("Ils désamorcent la Charge !", 1.8)


## Durée de la pose pour [param key] (plant_time ; lot TAC-5 : les Gants de sapeur la raccourcissent).
func _plant_full(key := "") -> float:
	return Assault.num("plant_time") * _tool_mult(key, "plant")


## Durée du désamorçage (defuse_time ; lot TAC-5 : les Pinces d'acier la raccourcissent) pour celui qui désamorce.
func _defuse_full(key := "") -> float:
	var k := key if key != "" else defuse_by
	return Assault.num("defuse_time") * _tool_mult(k, "defuse")


## Multiplicateur d'outil de [param key] pour [param what] (« plant », « defuse ») : 1 sans outil (achats : lot TAC-5).
func _tool_mult(key: String, what: String) -> float:
	if key == "" or not has_method("tool_mult"):
		return 1.0
	return float(call("tool_mult", key, what))


func _progress_defuse(c: Combatant, delta: float) -> void:
	_charge_noise(c, "defuse", defuse_t, delta)
	defuse_t += delta
	if defuse_t >= _defuse_full(key_of(c)):
		var k := key_of(c)
		_stop_defuse()
		_fuse_at_defuse = Assault.t  # (« Ouf ! » à moins d'une seconde)
		_add_ult(k)  # (lot TAC-5) un point d'ultime au désamorçage
		_handle(Assault.defuse(k))


func _stop_defuse() -> void:
	if defuse_by != "":
		defuse_t = Assault.defuse_resume(defuse_t, _defuse_full())  # point de sauvegarde à la moitié
	defuse_by = ""


## Pose et désamorçage annulés par un contrôle subi (renversé, gelé, endormi, terreur, immobilisé : TACTIQUE § 7.2, 7.6).
func _interrupted(c: Combatant) -> bool:
	if c == null or c.is_dead:
		return true
	if c.is_disabled():
		return true
	for s in ["fear", "root"]:
		if c.has_status(s):
			return true
	return c is Player and (c as Player)._state == "stun"


## Le joueur pose (porteur, dans un site) ou désamorce (Défense, près de la Charge) en maintenant [Interagir] immobile ;
## un pas, un coup, un sort, une esquive ou un contrôle subi annulent (les dégâts seuls, non). Porteur hors d'un site : [G]
## lâche la Charge (pour un allié). Au pilote (--autoplay), il maintient dès qu'il est en place.
func _player_actions(delta: float) -> void:
	var prompt := ""
	var p := d.player
	if player_key == "" or p.is_dead:
		_set_prompt("")
		return
	var held := Input.is_action_pressed("interact") or p.autoplay
	var still := Vector2(p.velocity.x, p.velocity.z).length() < 0.6 and not p._state in ["attack", "skill", "dodge", "stun"] \
		and not _interrupted(p)
	var key_f := Settings.action_label("interact", 1)
	if Assault.phase == "live" and carrier == player_key and site_at(p.global_position) == "":
		prompt = "Tu portes la Charge · [%s] la lâcher" % Settings.action_label("quick_equip", 1)
		if Input.is_action_just_pressed("quick_equip") and not p.autoplay:
			_drop_charge(p.global_position + p.forward() * 1.2, "drop")
			prompt = ""
	if Assault.phase == "live" and carrier == player_key and site_at(p.global_position) != "":
		prompt = "[%s] Poser la Charge · %.0f s" % [key_f, _plant_full(player_key)]
		if held and still:
			plant_by = player_key
			prompt = "Pose… %.1f s" % maxf(_plant_full(player_key) - plant_t, 0.0)
			_progress_plant(p, delta)
		elif plant_by == player_key:
			plant_by = ""
			plant_t = 0.0
	elif Assault.phase == "planted" and Assault.team_of(player_key) == Assault.defense() and _dist2(p.global_position, charge_pos) <= Assault.num("defuse_range"):
		prompt = "[%s] Désamorcer · %.0f s" % [key_f, _defuse_full(player_key)]
		if defuse_t > 0.0 and defuse_by == "":
			prompt += " · reprend à %.1f s" % defuse_t
		if held and still and (defuse_by == "" or defuse_by == player_key):
			if defuse_by == "":
				defuse_by = player_key
			prompt = "Désamorçage… %.1f s" % maxf(_defuse_full() - defuse_t, 0.0)
			_progress_defuse(p, delta)
		elif defuse_by == player_key:
			_stop_defuse()
	if p.autoplay:
		p.autoplay_target = _goal_for(player_key, 0) if engaged_foe(p) == null else Vector3.INF
	_set_prompt(prompt)


func _set_prompt(text: String) -> void:
	if text != _prompt:
		_prompt = text
		d.prompt_changed.emit(text)


# --- la Charge (lot TAC-3) -------------------------------------------------------------------------

## Nouvelle Charge de la manche, sur le dos du porteur choisi.
func _new_charge() -> void:
	if is_instance_valid(charge):
		charge.queue_free()
	for k in heroes:
		var h := hero(String(k))
		if h != null and h.has_node("AssaultChargePack"):
			h.get_node("AssaultChargePack").free()  # (le joueur garde son nœud d'une manche à l'autre)
	charge = AssaultCharge.new()
	_markers.add_child(charge)
	carrier = _pick_carrier()
	var c := hero(carrier)
	if c != null:
		charge.carry(c)
	else:
		charge.drop_at(_ground(layout.spawns.attack.pos))
		carrier = ""


## Porteur de la manche : toi si tu attaques (option player_carry, vrai par défaut), sinon l'attaquant scripté au meilleur
## score de porteur (jamais celui qui ouvre : _carrier_score).
func _pick_carrier() -> String:
	var keys: Array = Assault.alive_keys(Assault.attack)
	if keys.is_empty():
		return ""
	if player_key != "" and player_key in keys and bool(TeamMatch.spec.get("player_carry", true)):
		return player_key
	var best := ""
	var bs := -INF
	for k in keys:
		if String(k) == player_key:
			continue
		var s := _carrier_score(String(k))
		if s > bs:
			bs = s
			best = String(k)
	return best


## Rôle tactique du héros [param key] (lot TAC-4, data/assault_kits.json) : rempart, ouvreur, tireur, controleur, soutien.
func role_of(key: String) -> String:
	return AssaultCombat.role_of_class(String(classes.get(key, "")))


## Cases du kit que [param key] possède cette manche (0 signature, 1 et 2 achetées, 3 ultime) : la signature, les sorts
## achetés (AssaultItems) et l'ultime à 7 points (lot TAC-5).
func owned_slots(key: String) -> Array:
	var out: Array = [0]
	for s in AssaultItems.inv(key).spells:
		out.append(int(s))
	if ult_points(key) >= int(Assault.num("ult_points")):
		out.append(3)
	return out


## Score de porteur : pas le premier de l'équipe (il ouvre), puis le rôle tactique (role_of), puis l'ordre.
func _carrier_score(key: String) -> float:
	var i := int(key.right(1))
	var s := -2.0 if i == 0 else 0.0
	if has_method("role_of"):
		s += float({"soutien": 3, "controleur": 2, "tireur": 2, "rempart": 1, "ouvreur": -3}.get(String(call("role_of", key)), 0))
	return s - i * 0.1


## La Charge tombe en [param at] : porteur à terre ([param why] « fall ») ou lâchée ([param why] « drop »).
func _drop_charge(at: Vector3, why: String) -> void:
	if charge == null or charge.state != "carried":
		carrier = ""
		return
	var was := carrier
	carrier = ""
	if plant_by == was:
		plant_by = ""
		plant_t = 0.0
	charge.drop_at(_ground(at))
	if was == player_key and why == "drop":
		d.message.emit("Tu lâches la Charge", 1.5)
	elif player_key != "" and Assault.team_of(player_key) == Assault.attack:
		d.message.emit("La Charge est tombée !", 1.8)
	if _verbose():
		print("[assault] la Charge tombe (%s, %s) en (%.0f, %.0f)" % [was, why, at.x, at.z])


## Ramassage en passant : un attaquant debout à moins de pickup_radius m de la Charge au sol la prend.
func _try_pickup() -> void:
	var r := Assault.num("pickup_radius")
	for k in Assault.alive_keys(Assault.attack):
		var h := hero(String(k))
		if h == null or h.is_dead or _dist2(h.global_position, charge.global_position) > r:
			continue
		carrier = String(k)
		charge.carry(h)
		if carrier == player_key:
			d.message.emit("Tu ramasses la Charge", 1.5)
			UiFeel.cue("ui_equip", -8.0)
		elif player_key != "" and Assault.team_of(player_key) == Assault.attack:
			d.message.emit("%s ramasse la Charge" % h.display_name.get_slice(" · ", 0), 1.5)
		if _verbose():
			print("[assault] %s ramasse la Charge" % carrier)
		return


## Chaque image : ramassage, mèche et bips, la Charge au sol montrée à qui la voit, annonce des 10 dernières secondes.
func _update_charge(delta: float) -> void:
	if charge == null:
		return
	if Assault.phase == "live" and charge.state == "carried" and (hero(carrier) == null or hero(carrier).is_dead):
		var at := charge.holder.global_position if is_instance_valid(charge.holder) else charge.global_position
		_drop_charge(at, "fall")
	if Assault.phase == "live" and charge.state == "ground":
		_try_pickup()
	charge.update(delta, Assault.t if Assault.phase == "planted" else 0.0)
	_mark_busy()
	charge.set_shown(charge.state != "ground" or charge_seen(view_team()))
	if Assault.phase == "planted" and not _ten_said and Assault.t <= 10.0:
		_ten_said = true
		d.message.emit("10 secondes !", 1.5)
		UiFeel.cue("ui_tick", -6.0, 1.3)


## Qui porte, pose ou désamorce la Charge ne peut pas devenir invisible (lot TAC-4, AssaultCombat.status_duration) ; s'il
## l'était, l'invisibilité tombe.
func _mark_busy() -> void:
	for k in heroes:
		var h := hero(String(k))
		if h == null:
			continue
		var busy := String(k) == carrier or String(k) == plant_by or String(k) == defuse_by
		if busy != bool(h.get_meta("assault_busy", false)):
			h.set_meta("assault_busy", busy)
		if busy and h.statuses.has("invisible"):
			h.statuses.erase("invisible")
			h.statuses_changed.emit()


## Équipe dont l'écran montre la vue (celle du héros regardé).
func view_team() -> int:
	var v := view_hero()
	var t := TeamMatch.team_of(v) if v != null else 0
	return t if t >= 0 else 0


## L'équipe [param t] voit-elle la Charge ? L'Attaque toujours ; la Défense, posée (position connue de tous), ou au sol si
## l'un de ses héros debout voit l'endroit ; portée, avec son porteur (s'il est vu).
func charge_seen(t: int) -> bool:
	if charge == null:
		return false
	if t == Assault.attack or charge.state in ["planted", "defused", "exploded"]:
		return true
	if charge.state == "carried":
		return vision != null and is_instance_valid(charge.holder) and vision.sees(t, charge.holder)
	if vision == null:
		return true
	for h in TeamMatch.alive(t):
		var c := h as Combatant
		if _dist2(c.global_position, charge.global_position) <= AssaultVision.RANGE and vision.los(c.global_position, charge.global_position):
			return true
	return false


## Repères de la mini-carte (RunDirector.markers, état « team ») : la Charge, si l'équipe regardée la voit.
func markers() -> Array:
	if charge == null or charge.state in ["defused", "exploded"] or not charge_seen(view_team()):
		return []
	var at := charge.global_position
	if charge.state == "carried" and is_instance_valid(charge.holder):
		at = charge.holder.global_position
	return [[at, "drop"]]


## Attaquant scripté qui va ramasser la Charge au sol : le plus proche.
func _fetcher() -> String:
	return _nearest(Assault.attack, charge.global_position, true)


## Défenseur scripté qui garde la Charge au sol quand sa Défense la voit : le plus proche.
func _guard() -> String:
	if not charge_seen(Assault.defense()):
		return ""
	return _nearest(Assault.defense(), charge.global_position, true)


func _nearest(t: int, at: Vector3, ai_only: bool) -> String:
	var best := ""
	var bd := INF
	for k in Assault.alive_keys(t):
		if ai_only and String(k) == player_key:
			continue
		var h := hero(String(k))
		if h == null:
			continue
		var dd := _dist2(h.global_position, at)
		if dd < bd:
			bd = dd
			best = String(k)
	return best


## La mèche est au bout : explosion ; tout héros à moins de blast_radius m est emporté (il ne « survit » pas à la manche).
func _explode() -> void:
	d.message.emit("La Charge explose !", 2.0)
	UiFeel.cue("ui_banner", -2.0, 0.8, [0.8, 0.6, 0.5])
	if charge == null:
		return
	charge.explode()
	var r := Assault.num("blast_radius")
	for k in heroes.keys():
		var h := hero(String(k))
		if h == null or h.is_dead or _dist2(h.global_position, charge.global_position) > r:
			continue
		blasted.append(String(k))
		h.take_damage(h.max_hp * 50.0, null, false, true)


# --- achats, objets et ultime (lot TAC-5) ----------------------------------------------------------

## Chaque image : fioles de soin en cours ; pendant l'achat, [B] (ou la croix à gauche) rouvre l'écran ; en manche, les
## touches d'objets du joueur.
func _items_tick(delta: float) -> void:
	for k in heroes:
		var h := hero(String(k))
		if h != null:
			AssaultGadgets.tick_potion(h, delta)
	if player_key == "" or d.player.is_dead:
		return
	if Assault.phase == "buy":
		var b := Input.is_physical_key_pressed(KEY_B) or Input.is_action_pressed("objectives")
		if b and not _shop_key_was and (not is_instance_valid(shop) or not shop.visible):
			_open_shop()
		_shop_key_was = b
		_set_prompt("" if is_instance_valid(shop) and shop.visible else "[B] Achat · %d s" % int(maxf(Assault.t, 0.0)))
	elif Assault.phase in ["live", "planted"]:
		_player_items()



## Points d'ultime de chaque héros (toute la partie) : élimination, chute, pose, désamorçage (+1 chacun, 7 au plus).
var ult_pts: Dictionary = {}
var shop: AssaultShop
var _shop_layer: CanvasLayer
var _deny_ms := 0
var _shop_key_was := false
var _round_gold: Dictionary = {}
## Plans d'achat de chaque manche (mesures) : [manche, équipe qui attaque, plan 0, plan 1, or moyen 0, or moyen 1].
var plan_log: Array = []


func ult_points(key: String) -> int:
	return int(ult_pts.get(key, 0))


func _add_ult(key: String, n := 1) -> void:
	if key == "" or Assault.team_of(key) < 0:
		return
	var cap := int(Assault.num("ult_points"))
	var before := ult_points(key)
	ult_pts[key] = mini(before + n, cap)
	if before < cap and ult_points(key) >= cap:
		if key == player_key:
			d.message.emit("Ultime prêt !", 1.5)
			UiFeel.cue("ui_star", -8.0)
		elif Assault.phase in ["live", "planted"] and hero(key) is ClassRival:
			_arm(key)


## Contexte d'achat de [param key] (AssaultItems) : classe, rôle, côté.
func shop_ctx(key: String) -> Dictionary:
	return {"cid": String(classes.get(key, "")), "role": role_of(key),
		"side": "attack" if Assault.team_of(key) == Assault.attack else "defense"}


## Multiplicateur d'outil (Gants de sapeur pour la pose, Pinces d'acier pour le désamorçage).
func tool_mult(key: String, what: String) -> float:
	var t := String(AssaultItems.inv(key).tool)
	if what == "plant" and t == "gants":
		return AssaultItems.TOOL_PLANT
	if what == "defuse" and t == "pinces":
		return AssaultItems.TOOL_DEFUSE
	return 1.0


## Le joueur peut-il lancer le sort de la case [param slot] ? (Player.use_skill par AssaultCombat.can_cast) Pas pendant
## l'achat ; cases 2 et 3 achetées ; ultime à 7 points.
func can_cast(p: Player, slot: int) -> bool:
	if Assault.phase == "buy":
		return false
	var key := key_of(p)
	if key == "" or slot in owned_slots(key):
		return true
	if Time.get_ticks_msec() - _deny_ms > 800:
		_deny_ms = Time.get_ticks_msec()
		var txt := "ULTIME %d / %d" % [ult_points(key), int(Assault.num("ult_points"))] if slot == 3 else "À ACHETER"
		DamageNumber.spawn_text(p, txt, UiTheme.color("bonbon.fraise.base"))
		UiFeel.cue("ui_deny", -10.0)
	return false


## Sort lancé par le joueur : l'ultime consomme ses points.
func on_cast(p: Player, slot: int) -> void:
	if slot == 3:
		ult_pts[key_of(p)] = 0


## Héros scripté [param key] armé de ses cases possédées (kit, rôle) ; l'ultime prêt peut partir tout de suite.
func _arm(key: String) -> void:
	var r := hero(key) as ClassRival
	if r == null:
		return
	var cid := String(classes.get(key, ""))
	AssaultCombat.arm_rival(r, cid, owned_slots(key))
	r._skill_ready.erase(AssaultCombat.ult_id(cid))


## Effets du paquetage de [param key] sur son héros : arme (dégâts), bouclier (armure), outil (Talisman, Bottes), enduit ;
## pour un scripté, ses cases de sorts.
func _apply_kit(key: String) -> void:
	var h := hero(key)
	if h == null:
		return
	var v := AssaultItems.inv(key)
	var dmg := float(AssaultItems.LIST.get(String(v.weapon), {}).get("dmg", 1.0))
	h.set_meta("assault_tenacity_item", AssaultItems.TALISMAN if String(v.tool) == "talisman" else 0.0)
	h.set_meta("assault_quiet", Player.BASE_SPEED * AssaultItems.QUIET_SPEED if String(v.tool) == "bottes" else AssaultVision.RUN_SPEED)
	h.set_meta("assault_coat", int(v.coat))
	if h is ClassRival:
		var r := h as ClassRival
		if not r.has_meta("assault_base_atk"):
			r.set_meta("assault_base_atk", r.atk)
		r.atk = float(r.get_meta("assault_base_atk")) * dmg
		_arm(key)
	elif h is Player:
		h.set_meta("assault_dmg_mult", dmg)
		if bool(v.weapon2):
			if (Profile.equipped.get("offhand", {}) as Dictionary).is_empty():
				Profile.equipped["offhand"] = _offhand_for(String(classes.get(key, "")))  # Arme d'appoint : [Changer d'arme]
		elif Profile.equipped.has("offhand"):
			Profile.equipped.erase("offhand")
			(h as Player).hand_off = false
		(h as Player).recalc_stats()
	h.set_meta("assault_shield", float(v.shield) * h.max_hp)


## Début de la phase d'achat : paquetages remis à zéro à la mi-temps et en prolongation, plans d'équipe, achats des IA,
## écran d'achat du joueur (au pilote : l'achat conseillé).
func _buy_phase_start() -> void:
	var keys: Array = Assault.members[0] + Assault.members[1]
	var half := int(Assault.num("half"))
	if Assault.round_n == half + 1 or (Assault.in_overtime() and Assault.ot_rounds == 1):
		AssaultItems.reset_all(keys)
	for k in keys:
		AssaultItems.new_phase(String(k))
		_round_gold[String(k)] = Assault.gold(String(k))
	for t in 2:
		AssaultItems.plans[t] = AssaultItems.team_plan(t)
	plan_log.append([Assault.round_n, Assault.attack, AssaultItems.plans[0], AssaultItems.plans[1], _avg_gold(0), _avg_gold(1)])
	for k in keys:
		if String(k) != player_key:
			AssaultItems.ai_buy(String(k), AssaultItems.plans[Assault.team_of(String(k))], shop_ctx(String(k)))
		_apply_kit(String(k))
	if player_key != "":
		if d.player.autoplay:
			shop_advised()
		else:
			_open_shop()
	if _verbose():
		print("[assault] achats : plans %s / %s, or après achats %d / %d" % [AssaultItems.plans[0], AssaultItems.plans[1],
			_avg_gold(0), _avg_gold(1)])


func _open_shop() -> void:
	if player_key == "" or watch:
		return
	if _shop_layer == null:
		_shop_layer = CanvasLayer.new()
		_shop_layer.name = "AssaultShopLayer"
		_shop_layer.layer = 30
		d.add_child(_shop_layer)
	if is_instance_valid(shop):
		shop.open()
		return
	shop = AssaultShop.new()
	_shop_layer.add_child(shop)
	shop.setup(self, player_key)


func _close_shop() -> void:
	if is_instance_valid(shop):
		shop.queue_free()
	shop = null


## Fin de manche : un héros tombé (ou emporté par l'explosion) perd son paquetage ; un survivant garde le reste de son bouclier.
func _round_inventory() -> void:
	for k in heroes.keys():
		var key := String(k)
		var h := hero(key)
		if not bool(Assault.alive.get(key, false)) or key in blasted or h == null or h.is_dead:
			AssaultItems.lose(key)
			continue
		var v := AssaultItems.inv(key)
		if String(v.armor) != "":
			v.shield = clampf(float(h.get_meta("assault_shield", 0.0)) / maxf(h.max_hp, 1.0), 0.0, 1.0)
		v.coat = int(h.get_meta("assault_coat", 0))


## Arme d'appoint (lot TAC-5) : une arme commune d'un autre type que celle de la classe, au niveau de la fiche (système des
## deux armes, Player.swap_weapon) ; elle ne vit que le temps de la partie (Profile.equipped est la copie de la run).
func _offhand_for(cid: String) -> Dictionary:
	var own := String(GameData.class_data(cid).get("weapon_type", ""))
	var types: Array = SlotChests.weapon_types().filter(func(w): return String(w) != own)
	if types.is_empty():
		return {}
	var wt := String(types[rng.randi() % types.size()])
	return Items.generate(int(Assault.num("level")), 0.0, "weapon", cid, 0, wt, 0)


# API de l'écran d'achat (AssaultShop) : toujours pour le joueur.

func shop_buy(id: String) -> bool:
	var ok := AssaultItems.buy(player_key, id, shop_ctx(player_key))
	if ok:
		_apply_kit(player_key)
	return ok


func shop_sell(id: String) -> bool:
	var ok := AssaultItems.sell(player_key, id)
	if ok:
		_apply_kit(player_key)
	return ok


func shop_sell_all() -> int:
	var n := AssaultItems.sell_all(player_key)
	_apply_kit(player_key)
	return n


func shop_rebuy() -> Array:
	var got := AssaultItems.rebuy(player_key, shop_ctx(player_key))
	_apply_kit(player_key)
	return got


func shop_advised() -> Array:
	var out: Array = []
	for id in AssaultItems.advised(player_key, shop_ctx(player_key)):
		if AssaultItems.buy(player_key, String(id), shop_ctx(player_key)):
			out.append(id)
	_apply_kit(player_key)
	return out


## Lignes de la colonne « L'équipe » : nom, classe, rôle, or, état (« ✔ prêt » ou ce qui manque).
func team_rows(t: int) -> Array:
	var out: Array = []
	for k in Assault.members[t]:
		var key := String(k)
		var cid := String(classes.get(key, ""))
		var nm := "Toi" if key == player_key else String(GameData.class_data(cid).get("name_fr", cid))
		if key == player_key:
			nm += " · " + String(GameData.class_data(cid).get("name_fr", cid))
		var miss := AssaultItems.missing_for_full(key) if (AssaultItems.inv(key).now as Array).is_empty() else 0
		var status := "en cours" if key == player_key else ("✔ prêt" if miss == 0 or AssaultItems.plans[t] == "eco" else "Il lui manque %d" % miss)
		out.append({"key": key, "name": nm, "role": role_of(key), "gold": Assault.gold(key), "status": status})
	return out


# Utilitaires et fioles en manche.

## Utilitaire n° [param i] (0 ou 1, dans l'ordre d'achat) de [param key] lancé vers [param at].
func use_util(key: String, i: int, at: Vector3) -> bool:
	var v := AssaultItems.inv(key)
	var ids: Array = (v.utils as Dictionary).keys().filter(func(u): return int(v.utils[u]) > 0)
	if i >= ids.size():
		return false
	return _use_util_id(key, String(ids[i]), at)


func _use_util_id(key: String, id: String, at: Vector3) -> bool:
	var v := AssaultItems.inv(key)
	if int(v.utils.get(id, 0)) <= 0:
		return false
	if not AssaultGadgets.use(self, hero(key), id, at):
		return false
	v.utils[id] = int(v.utils[id]) - 1
	if int(v.utils[id]) <= 0:
		(v.utils as Dictionary).erase(id)
	if _verbose():
		print("[assault] %s lance %s" % [key, id])
	return true


func use_fiole(key: String) -> bool:
	var v := AssaultItems.inv(key)
	if String(v.fiole) == "" or not AssaultGadgets.drink(self, hero(key), String(v.fiole)):
		return false
	v.fiole = ""
	return true


## Touches du joueur en manche : [C] fiole, [V] utilitaire 1, [X] utilitaire 2 (vers le point visé).
func _player_items() -> void:
	var p := d.player
	if p.autoplay or p.is_dead:
		return
	var aim := p._skill_aim()
	if aim == Vector3.INF:
		aim = p.global_position + p.forward() * 8.0
	if Input.is_action_just_pressed("potion_1"):
		use_fiole(player_key)
	if Input.is_action_just_pressed("potion_2"):
		use_util(player_key, 0, aim)
	if Input.is_action_just_pressed("extract"):
		use_util(player_key, 1, aim)


## Objets d'un héros scripté (règles simples, en attendant le stratège du lot TAC-6) : fiole de soin sous 40 % des PV, de
## garde en combat sous 60 %, de clarté sous contrôle, de hâte en route ; bombe, feu ou éclat sur l'adversaire combattu
## (5-14 m) ; brume pour fuir sous 35 % ; chouette près du site visé ; clochette et piège à son poste en Défense.
func _ai_items(r: ClassRival, key: String) -> void:
	var v := AssaultItems.inv(key)
	var f := engaged_foe(r)
	if String(v.fiole) != "":
		var drink := false
		match String(v.fiole):
			"soin":
				drink = r.hp < r.max_hp * 0.4 and not r.has_meta("assault_potion")
			"garde":
				drink = f != null and r.hp < r.max_hp * 0.6
			"clarte":
				drink = _interrupted(r)
			"hate":
				drink = f == null and Assault.round_time > 3.0 and Assault.team_of(key) == Assault.attack
		if drink:
			use_fiole(key)
	if (v.utils as Dictionary).is_empty() or float(r.get_meta("assault_util_at", 0.0)) > TeamMatch.elapsed:
		return
	for u in (v.utils as Dictionary).keys():
		var at := Vector3.INF
		match String(u):
			"bombe", "feu", "eclat":
				if f != null and _dist2(r.global_position, f.global_position) >= 4.0 and _dist2(r.global_position, f.global_position) <= 14.0:
					at = f.global_position
			"brume", "barricade":
				if f != null and r.hp < r.max_hp * 0.35:
					at = r.global_position + (f.global_position - r.global_position).normalized() * 2.5
			"chouette":
				if f == null and Assault.team_of(key) == Assault.attack and _dist2(r.global_position, site_pos(target_site)) < 22.0:
					at = site_pos(target_site)
			"clochette", "piege":
				if Assault.team_of(key) == Assault.defense() and Assault.round_time > 2.0 and f == null and r.goal != Vector3.INF \
						and _dist2(r.global_position, r.goal) < 3.0:
					at = r.global_position
			"silence":
				if f == null and Assault.team_of(key) == Assault.attack and _dist2(r.global_position, site_pos(target_site)) < 25.0:
					at = r.global_position
		if at != Vector3.INF and _use_util_id(key, String(u), at):
			r.set_meta("assault_util_at", TeamMatch.elapsed + 3.0)
			return


## L'ultime d'un scripté est parti : ses points retombent à 0, il est réarmé sans lui.
func _ai_ult_check(r: ClassRival, key: String) -> void:
	if not 3 in owned_slots(key):
		return
	var uid := AssaultCombat.ult_id(String(classes.get(key, "")))
	if float(r._skill_ready.get(uid, 0.0)) > r._time:
		ult_pts[key] = 0
		_arm(key)


## Clochette ou piège déclenché par [param c] (équipe [param t] prévenue, avec le lieu).
func gadget_alarm(kind: String, c: Combatant, t: int) -> void:
	if t != TeamMatch.player_team or player_key == "":
		return
	var place := ""
	if map != null and map.has_method("place_name"):
		place = String(map.call("place_name", c.global_position))
	d.message.emit(("Alarme" if kind == "clochette" else "Piège") + (" · " + place if place != "" else "") + " !", 1.6)


## Le joueur ébloui : voile blanc qui s'efface en 1,2 s.
func gadget_blind(c: Combatant) -> void:
	if c != d.player or player_key == "":
		return
	var layer := CanvasLayer.new()
	layer.layer = 25
	d.add_child(layer)
	var r := ColorRect.new()
	r.color = Color(1, 1, 1, 0.92)
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(r)
	var tw := r.create_tween()
	tw.tween_interval(0.5)
	tw.tween_property(r, "color:a", 0.0, 0.7)
	tw.tween_callback(layer.queue_free)


# --- joueur à terre, abandon, fin ------------------------------------------------------------------

## Le joueur tombe (world.gd) : K.O. compté, la caméra suit un allié debout (spectateur : lot TAC-8).
func player_down(killer: Combatant) -> void:
	if player_key == "" or not Assault.alive.get(player_key, false):
		return
	if player_key == plant_by:
		plant_by = ""
		plant_t = 0.0
	if player_key == defuse_by:
		_stop_defuse()
	_ko(player_key, killer)
	if _ended:
		return
	var a := _first_alive(0)
	if a != null and d.world.rig != null:
		d.world.rig.target = a
		TeamMatch.spectate(a)
		d.message.emit("Tu es tombé : tes alliés continuent", 2.0)


## Abandon (menu pause) : la partie est perdue.
func abandon() -> void:
	if _ended:
		return
	Assault.winner = 1 - TeamMatch.player_team
	_finish(true)


func _finish(forfeit := false) -> void:
	if _ended:
		return
	_ended = true
	_close_shop()
	d.world._ended = true
	d.world.pause_menu.close()
	var w := Assault.winner
	var won := w == TeamMatch.player_team
	TeamMatch.finish([w, 1 - w] if w >= 0 else [])
	var res := TeamMatch.result()
	var line := "[assault] fin : %s %s, %s, %.0f s" % ["victoire" if won else "défaite", "(abandon)" if forfeit else "",
		Assault.summary(), TeamMatch.elapsed]
	print(line)
	if _verbose():
		print("[assault] mesure " + JSON.stringify(measure()))
	if _perf_on and not perf.is_empty():
		print(perf_line())
		perf.clear()
	var score := [int(Assault.score[0]), int(Assault.score[1])]
	var rounds := Assault.round_n
	var hist := Assault.history.duplicate(true)
	Assault.finish()  # TeamMatch.end() d'abord (piège 11), puis la sauvegarde rechargée
	if "--auto-quit" in OS.get_cmdline_user_args():
		get_tree().quit()
		return
	if not is_inside_tree():
		return
	var r := ResultsPanel.new()
	d.world.add_child(r)
	r.show_spec(results_spec(won, score, rounds, hist, forfeit, res))


func _exit_tree() -> void:
	if _perf_on and not perf.is_empty():
		print(perf_line())  # (arrêt par --quit-at : la mesure de la manche en cours)


## Mesures de la partie (lots TAC-4 / TAC-5, tools/assault_games.py) : éliminations, morts et aides par rôle tactique, temps de
## survie des héros tombés (s), or moyen.
func measure() -> Dictionary:
	var roles := {}
	for k in Assault.stats:
		var r := role_of(String(k))
		var e: Dictionary = roles.get(r, {"kills": 0, "deaths": 0, "assists": 0, "n": 0})
		for f in ["kills", "deaths", "assists"]:
			e[f] = int(e[f]) + int(Assault.stats[k][f])
		e["n"] = int(e["n"]) + 1
		roles[r] = e
	return {"roles": roles, "survival": survival, "plans": plan_log,
		"history": Assault.history.map(func(h): return [int(h.attack), int(h.winner), String(h.how)])}


## Médianes et 90e centiles de la mesure d'image (--assault-perf).
func perf_line() -> String:
	var cols: Array = [[], [], [], []]
	for p in perf:
		for i in 4:
			cols[i].append(float(p[i]))
	var q := func(a: Array, k: float) -> float: return float(a[clampi(int(a.size() * k), 0, a.size() - 1)])
	for c in cols:
		c.sort()
	return "[assault] perf : image %.2f ms (90e %.2f), scripts %.2f ms, physique %.2f ms, vision %.2f ms (90e %.2f), %d images" % [
		q.call(cols[0], 0.5) * 1000.0, q.call(cols[0], 0.9) * 1000.0, q.call(cols[1], 0.5), q.call(cols[2], 0.5), q.call(cols[3], 0.5),
		q.call(cols[3], 0.9), perf.size()]


## Bilan provisoire (lot TAC-8 : frise des manches, tableau des 8, récompenses scellées) : score, manches, boutons.
func results_spec(won: bool, score: Array, rounds: int, hist: Array, forfeit: bool, _res: Dictionary) -> Dictionary:
	var by_how := {}
	for e in hist:
		if int(e.winner) == TeamMatch.player_team:
			by_how[String(e.how)] = int(by_how.get(String(e.how), 0)) + 1
	var tiles := [["%d - %d" % score, "score", "", true], [str(rounds), "manches"]]
	for h in ["elim", "charge", "defuse", "time"]:
		if by_how.has(h):
			tiles.append([str(by_how[h]), String(Assault.HOW[h]).to_lower()])
	var cid := Run.class_id
	return {"title": "VICTOIRE !" if won else ("ABANDON" if forfeit else "DÉFAITE"), "tone": "win" if won else "lose",
		"subtitle": "%s · %s" % [TeamMatch.title() if TeamMatch.active else "L'Assaut", String(layout.get("name", ""))],
		"tiles": tiles,
		"buttons": [{"text": "Rejouer", "primary": true, "call": _replay.bind(cid)},
			{"text": "Menu principal", "call": _to_lobby}]}


func _replay(cid: String) -> void:
	Assault.launch(cid, {"map": String(layout.get("id", "arena"))})
	get_tree().paused = false
	get_tree().change_scene_to_file.call_deferred("res://scenes/world.tscn")


func _to_lobby() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file.call_deferred("res://scenes/lobby.tscn")


func _verbose() -> bool:
	return watch or d.player.autoplay or "--auto-quit" in OS.get_cmdline_user_args()
