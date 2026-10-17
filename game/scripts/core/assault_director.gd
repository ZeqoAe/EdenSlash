class_name AssaultDirector
extends Node
## Directeur de scène de L'Assaut (lot TAC-0, rapport conception/benchmark/R_TAC_0.md) : monté par TeamMatch.mount depuis
## RunDirector.start (état « team ») ; tient la carte, les 8 héros (toi + 3 alliés IA contre 4 IA, ou 8 IA en mode
## spectateur), la machine de manche pure Assault (achat -> manche -> pose / désamorçage -> fin -> mi-temps /
## prolongation) et sa fin de partie. world.gd lui rend la mort du joueur (player_down) et l'abandon (abandon).
##
## Options de la partie (TeamMatch.spec, posées par Assault.launch) : map (« arena » : arène simple du lot TAC-0 ;
## « bourg » : lot TAC-1), format, diff_allies / diff_foes (0-3), watch (vrai : le joueur regarde 8 IA), first_attack,
## seed, speed (Engine.time_scale, mesures), allies / foes (classes imposées), et toute règle de Assault.RULES.
##
## IA (lot TAC-0, provisoire) : un agent minimal par héros scripté (_agent) — les attaquants vont ensemble au site de la
## manche, le porteur pose quand rien ne le menace, les défenseurs tiennent 2-2 puis reprennent le site de la Charge ;
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
## Charge (lot TAC-0 provisoire ; lot TAC-3 : objet porté, lâché, ramassé, bips) : porteur, pose et désamorçage en cours.
var carrier := ""
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
var _charge_mark: Node3D
var _ended := false
## Événements de la machine vus par le directeur (tests, mesures).
var events: Array = []
var round_lines: Array = []
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
	_build_map(String(spec.get("map", "arena")))
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


## Repères des sites (disque soleil et lettre) ; la Charge posée (lot TAC-3 : son vrai modèle, ses bips).
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
	PvpCaps.board = {}
	PvpCaps.elapsed = 0.0
	plant_by = ""
	plant_t = 0.0
	defuse_by = ""
	defuse_t = 0.0
	charge_pos = Vector3.INF
	if is_instance_valid(_charge_mark):
		_charge_mark.queue_free()
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
				continue
			var r := TeamMatch.make_hero(String(classes[key]), int(Assault.num("level")), int(diffs[t]), t)
			d.add_child(r)
			r.global_position = at + Vector3.UP * 0.4
			r.passive = true  # derrière la barrière pendant l'achat
			heroes[key] = r
			_watch_hero(r, key)
	carrier = Assault.default_carrier()
	TeamMatch.start_round()
	TeamMatch.set_phase("countdown")
	if d.world.rig != null:
		d.world.rig.target = d.player if not watch else _first_alive(0)
	var side := Assault.side_name(0)
	d.message.emit("Manche %d · %s · %d - %d" % [Assault.round_n, side, int(Assault.score[0]), int(Assault.score[1])], 2.5)
	if _verbose():
		print("[assault] manche %d : équipe 0 en %s, site visé %s, or moyen %d / %d" % [Assault.round_n, side.to_lower(),
			target_site, _avg_gold(0), _avg_gold(1)])


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
	if v != null:
		TeamMatch.note_ko(v, killer)
	if vk == carrier:
		carrier = ""  # (lot TAC-3 : la Charge tombe au sol et se ramasse)
	if vk == plant_by:
		plant_by = ""
		plant_t = 0.0
	if vk == defuse_by:
		_stop_defuse()
	if _verbose():
		print("[assault] %s (%s) tombe, par %s" % [vk, classes.get(vk, "?"), kk if kk != "" else "le décor"])
	_handle(Assault.ko(vk, kk, assists))


# --- boucle ----------------------------------------------------------------------------------------

func update(delta: float) -> void:
	if _ended:
		return
	TeamMatch.elapsed += delta
	if Assault.phase in ["live", "planted"]:
		PvpCaps.elapsed += delta
	if Assault.phase == "buy":
		_hold_in_spawn()
	_handle(Assault.tick(delta))
	if _ended:
		return
	if Assault.phase in ["live", "planted"]:
		if carrier == "" or not Assault.alive.get(carrier, false):
			carrier = Assault.default_carrier()
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
	print("[assault] t=%.1f %s plant=%s %.1f | %s" % [Assault.round_time, Assault.phase, plant_by, plant_t, " ".join(parts)])


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
				d.message.emit("C'est parti !", 1.2)
				UiFeel.cue("ui_go", -8.0)
			"planted":
				_drop_charge_mark(charge_pos)
				d.message.emit("Charge posée en %s !" % String(e.site), 2.5)
			"explode":
				d.message.emit("La Charge explose !", 2.0)
			"defused":
				d.message.emit("Charge désamorcée !", 2.0)
			"round_end":
				_end_round(e)
			"next":
				_start_round()
			"done":
				_finish()


func _end_round(e: Dictionary) -> void:
	var w := int(e.winner)
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


## [param h] perçoit-il [param c] ? Lot TAC-0 : oui (la distance décide) ; remplacé par la vue d'équipe (TAC-2).
func can_perceive(h: Combatant, c: Combatant) -> bool:
	return h != null and c != null


func _agent(key: String) -> void:
	var r := hero(key) as ClassRival
	if r == null or r.is_dead:
		return
	var t := Assault.team_of(key)
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
		if c != null and not c.is_dead and site_at(c.global_position) != "" and engaged_foe(c, THREAT) == null and not c.is_disabled():
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
			if dh == null or dh.is_dead or dh.is_disabled() or _dist2(dh.global_position, charge_pos) > Assault.num("defuse_range") + 0.4:
				_stop_defuse()
			else:
				_progress_defuse(dh, delta)
			return
		if defuse_by == "":
			for k in Assault.alive_keys(Assault.defense()):
				var r := hero(String(k)) as ClassRival
				if r != null and _dist2(r.global_position, charge_pos) <= Assault.num("defuse_range") and engaged_foe(r, THREAT) == null:
					defuse_by = String(k)
					defuse_t = Assault.defuse_resume(defuse_t, _defuse_full())
					r.goal = r.global_position
					break


func _dist2(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _progress_plant(c: Combatant, delta: float) -> void:
	plant_t += delta
	if plant_t >= Assault.num("plant_time"):
		charge_pos = _ground(c.global_position)
		var s := site_at(c.global_position)
		plant_by = ""
		plant_t = 0.0
		_handle(Assault.plant(s, key_of(c)))


func _defuse_full() -> float:
	return Assault.num("defuse_time")


func _progress_defuse(c: Combatant, delta: float) -> void:
	defuse_t += delta
	if defuse_t >= _defuse_full():
		var k := key_of(c)
		_stop_defuse()
		_handle(Assault.defuse(k))


func _stop_defuse() -> void:
	if defuse_by != "":
		defuse_t = Assault.defuse_resume(defuse_t, _defuse_full())  # point de sauvegarde à la moitié
	defuse_by = ""


## Le joueur pose (porteur, dans un site) ou désamorce (Défense, près de la Charge) en maintenant [Interagir] immobile ;
## un pas, un coup, un sort, une esquive ou un contrôle subi annulent (les dégâts seuls, non). Au pilote (--autoplay), il
## maintient dès qu'il est en place.
func _player_actions(delta: float) -> void:
	var prompt := ""
	var p := d.player
	if player_key == "" or p.is_dead:
		_set_prompt("")
		return
	var held := Input.is_action_pressed("interact") or p.autoplay
	var still := Vector2(p.velocity.x, p.velocity.z).length() < 0.6 and not p._state in ["attack", "skill", "dodge", "stun"]
	if Assault.phase == "live" and carrier == player_key and site_at(p.global_position) != "":
		prompt = "[F] Poser la Charge · %.0f s" % Assault.num("plant_time")
		if held and still:
			plant_by = player_key
			prompt = "Pose… %.1f s" % maxf(Assault.num("plant_time") - plant_t, 0.0)
			_progress_plant(p, delta)
		elif plant_by == player_key:
			plant_by = ""
			plant_t = 0.0
	elif Assault.phase == "planted" and Assault.team_of(player_key) == Assault.defense() and _dist2(p.global_position, charge_pos) <= Assault.num("defuse_range"):
		prompt = "[F] Désamorcer · %.0f s" % Assault.num("defuse_time")
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


func _drop_charge_mark(at: Vector3) -> void:
	_charge_mark = Node3D.new()
	_charge_mark.name = "Charge"
	_markers.add_child(_charge_mark)
	var mi := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 0.45
	s.height = 0.9
	mi.mesh = s
	var mat := StandardMaterial3D.new()
	mat.albedo_color = UiTheme.color("bonbon.soleil.base")
	mat.emission_enabled = true
	mat.emission = UiTheme.color("bonbon.soleil.base")
	mat.emission_energy_multiplier = 2.0
	mi.material_override = mat
	_charge_mark.add_child(mi)
	_charge_mark.global_position = at + Vector3.UP * 0.5


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
	d.world._ended = true
	d.world.pause_menu.close()
	var w := Assault.winner
	var won := w == TeamMatch.player_team
	TeamMatch.finish([w, 1 - w] if w >= 0 else [])
	var res := TeamMatch.result()
	var line := "[assault] fin : %s %s, %s, %.0f s" % ["victoire" if won else "défaite", "(abandon)" if forfeit else "",
		Assault.summary(), TeamMatch.elapsed]
	print(line)
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
