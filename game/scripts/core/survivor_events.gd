class_name SurvivorEvents
extends RefCounted
## Élites lisibles, gardiens variés et événements de partie du Survivant (lot SVX-3, BM-SURV SV-E1). Créé par le directeur
## du Survivant (SurvivorDirector.update appelle [method tick] à chaque image).
##
## - Élites : chaque élite (et chaque géant de la carte) reçoit UN modificateur lisible : étiquette autocollante au-dessus de
##   la tête (pictogramme + mot, couleur du modificateur), nom préfixé dans la barre de cible du HUD (« Rapide · … »).
##     rapide (×1,45 vitesse) · blindé (PV ×1,5) · explosif (à sa mort : zone de 3,5 m annoncée 1,1 s, 20 % des PV du héros)
##     · invocateur (3 monstres de la horde autour de lui toutes les 7 s, 4 fois au plus).
## - Gardiens : chacun le sien, tiré sans doublon pour la partie (rapide, explosif, invocateur ; jamais « blindé » : leurs PV
##   sont fixés et mesurés, Survivor.GUARDIAN_HP) ; l'annonce le nomme (« Gardien rapide ! »).
## - Événements nommés, annoncés 5 s avant et marqués sur la frise du HUD :
##     7:30 « Nuée » : 25 s de meutes rapides et fragiles qui convergent ; en vaincre NUEE_GOAL × leur nombre ouvre un coffre doré ;
##     12:30 « Chasseur » : une élite nommée (rapide et blindée) traque le héros ; vaincue en CHASSEUR_TIME s, un coffre doré ;
##     sinon elle s'enfuit.
## Réglages mesurés : conception/survivor/R_SVX3.md (tools/sim_survivor.py).

const AFFIXES := {
	"rapide": {"name": "Rapide", "icon": "»", "tone": "lagon"},
	"blinde": {"name": "Blindé", "icon": "▣", "tone": "amethyste"},
	"explosif": {"name": "Explosif", "icon": "✸", "tone": "mandarine"},
	"invocateur": {"name": "Invocateur", "icon": "✚", "tone": "pomme"},
}
const GUARDIAN_AFFIXES := ["rapide", "explosif", "invocateur"]
## (lot SVX-4, mesures : R_SVX4) le 1er gardien (5:00) sans modificateur.
const GUARDIAN_FIRST_PLAIN := false
const SPEED := 1.45
const ARMOR_HP := 1.5
const BLAST_RADIUS := 3.5
const BLAST_DELAY := 1.1
const BLAST_PART := 0.2  # part des PV max du héros
const SUMMON_EVERY := 7.0
const SUMMON_N := 3
const SUMMON_MAX := 4
const SCAN_EVERY := 0.4
## Événements : temps de carte (s), id, nom, annonce.
const EVENTS := [
	{"t": 450.0, "id": "nuee", "name": "Nuée", "warn": "Une nuée approche !\nVaincs-en le plus possible : un coffre doré"},
	{"t": 750.0, "id": "chasseur", "name": "Chasseur", "warn": "Un chasseur te traque !\nVaincs-le en %d s : un coffre doré"},
]
const WARN := 5.0
const NUEE_TIME := 25.0
const NUEE_EVERY := 2.5
const NUEE_PACK := 10
const NUEE_HP := 0.35
const NUEE_GOAL := 0.6
const CHASSEUR_TIME := 60.0

var sv: SurvivorDirector
var _scan_t := 0.0
var _guard_pool: Array = []
var _next := 0
var _warned := {}
var _nuee := {}  # {until, spawned, killed, next, done}
var _hunter: Monster = null
var _hunter_until := -1.0
var _last_t := -1.0
var history: Array = []  # [{t, id, ok}] (journal, mesures)


func _init(director: SurvivorDirector) -> void:
	sv = director
	_guard_pool = GUARDIAN_AFFIXES.duplicate()
	_guard_pool.shuffle()


## Événements à venir pour la frise : [{t, name}].
static func timeline() -> Array:
	return EVENTS.map(func(e): return {"t": float(e.t), "name": String(e.name), "id": String(e.id)})


## Chaque image (SurvivorDirector.update) ; le pas vient du temps de carte du directeur.
func tick() -> void:
	var d := sv.d
	if d == null or d.state != "explore" or d.player == null:
		return
	var delta := 0.0 if _last_t < 0.0 else maxf(0.0, d.time - _last_t)
	_last_t = d.time
	_scan_t -= delta
	if _scan_t <= 0.0:
		_scan_t = SCAN_EVERY
		_scan(d)
	# annonces et départs des événements
	while _next < EVENTS.size():
		var e: Dictionary = EVENTS[_next]
		if d.time >= float(e.t) - WARN and not _warned.has(e.id):
			_warned[e.id] = true
			d.message.emit(String(e.warn) % int(CHASSEUR_TIME) if String(e.id) == "chasseur" else String(e.warn), 3.0)
			Sfx.ui("rock", -8.0, 0.7)
			SurvivorHud.caption("Bourdonnement : la nuée approche" if String(e.id) == "nuee" else "Cor de chasse : un chasseur te traque")
		if d.time < float(e.t):
			break
		_next += 1
		_start(String(e.id))
	_update_nuee(d)
	_update_hunter(d)


# --- élites et gardiens ----------------------------------------------------------------------------------------------------
func _scan(d: RunDirector) -> void:
	for n in d.get_tree().get_nodes_in_group("monsters"):
		var m := n as Monster
		if m == null or m.is_dead or m.is_boss or m.has_meta("sv_affix"):
			continue
		if m.has_meta("sv_guardian"):
			if GUARDIAN_FIRST_PLAIN and int(m.get_meta("sv_guardian")) == 0:
				m.set_meta("sv_affix", "")  # (lot SVX-4) le 1er gardien n'a pas de modificateur : il apprend le combat de gardien
				continue
			var a: String = _guard_pool.pop_front() if not _guard_pool.is_empty() else GUARDIAN_AFFIXES.pick_random()
			apply_affix(m, a)
			d.message.emit("Gardien %s !\n%s" % [String(AFFIXES[a].name).to_lower(), affix_tip(a)], 2.5)
		elif m.is_elite or m is GiantMonster:
			apply_affix(m, AFFIXES.keys().pick_random())
		else:
			m.set_meta("sv_affix", "")  # monstre ordinaire : rien (vu une fois)


## Une phrase par modificateur (annonce du gardien, infobulle).
static func affix_tip(a: String) -> String:
	match a:
		"rapide":
			return "Il court vite : garde tes distances"
		"blinde":
			return "Il encaisse beaucoup plus"
		"explosif":
			return "Il explose à sa mort : sors du cercle"
		"invocateur":
			return "Il appelle des renforts : abats-le vite"
	return ""


## Pose le modificateur [param a] sur [param m] : effet, étiquette au-dessus de la tête, nom préfixé.
func apply_affix(m: Monster, a: String) -> void:
	if not AFFIXES.has(a):
		return
	m.set_meta("sv_affix", a)
	var info: Dictionary = AFFIXES[a]
	m.display_name = "%s · %s" % [String(info.name), m.display_name]
	match a:
		"rapide":
			m.move_speed *= SPEED
		"blinde":
			if not m.has_meta("sv_guardian"):
				m.max_hp *= ARMOR_HP
				m.hp = m.max_hp
		"explosif":
			m.died.connect(func(_w: Combatant, _k: Combatant): _blast(m.global_position))
		"invocateur":
			var t := Timer.new()
			t.wait_time = SUMMON_EVERY
			t.autostart = true
			m.add_child(t)
			t.timeout.connect(_on_summon_tick.bind(m, t))
	var tag := Label3D.new()
	tag.text = "%s %s" % [String(info.icon), String(info.name)]
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.no_depth_test = true
	tag.fixed_size = true
	tag.pixel_size = 0.0022
	tag.font_size = 22
	tag.outline_size = 8
	tag.modulate = UiTheme.tones(String(info.tone))[0]
	tag.outline_modulate = UiTheme.color("encre.700")
	tag.font = UiTheme.bold_font()
	tag.position = Vector3(0, maxf(2.6, m.radius * 2.0 + 2.0), 0)
	tag.name = "SvAffix"
	m.add_child(tag)


func _on_summon_tick(m: Monster, t: Timer) -> void:
	if not is_instance_valid(m) or m.is_dead or int(m.get_meta("sv_summons", 0)) >= SUMMON_MAX:
		t.stop()
		return
	m.set_meta("sv_summons", int(m.get_meta("sv_summons", 0)) + 1)
	_summon(m)


func _blast(pos: Vector3) -> void:
	var d := sv.d
	if d == null or not is_instance_valid(d) or d.player == null:
		return
	SurvivorHud.caption("Sifflement : une élite va exploser")
	Telegraph.spawn(d, pos, 0.0, {"shape": "circle", "radius": BLAST_RADIUS, "delay": BLAST_DELAY,
		"damage": d.player.max_hp * BLAST_PART, "color": Color("ff9a3c")})


func _summon(m: Monster) -> void:
	var d := sv.d
	if d == null or not is_instance_valid(d) or d.state != "explore":
		return
	var lvl := sv.monster_level(0)
	for i in SUMMON_N:
		d._spawn_monster(d._pick_monster(lvl), d._around(m.global_position, 3.0), lvl)
	Vfx.ring(d.player, m.global_position, 3.0, Color(0.55, 0.9, 0.35, 0.9))
	SurvivorHud.caption("Appel : une élite invoque des renforts")


# --- événements ----------------------------------------------------------------------------------------------------------
func _start(id: String) -> void:
	var d := sv.d
	match id:
		"nuee":
			_nuee = {"until": d.time + NUEE_TIME, "spawned": [], "next": 0.0, "done": false}
			d.message.emit("LA NUÉE !\nVaincs-en le plus possible", 2.5)
			SurvivorLog.moment(d.time, "Nuée", "event")
		"chasseur":
			var lvl := sv.monster_level(2)
			var at := d._ring_point(18.0, 22.0)
			if at == Vector3.INF:
				at = d._around(d.player.global_position, 10.0)
			var id2: int = d._elites.pick_random() if not d._elites.is_empty() else d._pick_monster(lvl)
			var m := d._spawn_monster(id2, at, lvl)
			if not m.is_elite:
				m.is_elite = true
				m.max_hp *= 4.0
				m.hp = m.max_hp
			m.set_meta("sv_hunter", true)
			apply_affix(m, "rapide")
			m.max_hp *= ARMOR_HP
			m.hp = m.max_hp
			m.display_name = "Chasseur · " + m.display_name.trim_prefix("Rapide · ")
			_hunter = m
			_hunter_until = d.time + CHASSEUR_TIME
			m.died.connect(func(_w: Combatant, _k: Combatant): _on_hunter_down())
			d.message.emit("LE CHASSEUR EST LÀ !\nVaincs-le en %d s" % int(CHASSEUR_TIME), 2.5)
			SurvivorLog.moment(d.time, "Chasseur", "event")


func _update_nuee(d: RunDirector) -> void:
	if _nuee.is_empty() or bool(_nuee.done):
		return
	if d.time < float(_nuee.until):
		if d.time >= float(_nuee.next):
			_nuee.next = d.time + NUEE_EVERY
			var lvl := maxi(1, sv.monster_level(0) - 2)
			var c := d._ring_point(13.0, 17.0)
			if c != Vector3.INF:
				var id := d._pick_monster(lvl)
				for i in NUEE_PACK:
					var m := d._spawn_monster(id, d._around(c, 3.5), lvl)
					m.max_hp *= NUEE_HP
					m.hp = m.max_hp
					m.move_speed *= 1.3
					m.set_meta("sv_affix", "")
					m.set_meta("sv_swarm", true)
					(_nuee.spawned as Array).append(m)
		return
	_nuee.done = true
	var list: Array = _nuee.spawned
	var killed := list.filter(func(m): return not is_instance_valid(m) or m.is_dead).size()
	var ok := list.size() > 0 and float(killed) / float(list.size()) >= NUEE_GOAL
	history.append({"t": d.time, "id": "nuee", "ok": ok, "killed": killed, "n": list.size()})
	print("[sv] nuée : %d / %d vaincus%s" % [killed, list.size(), " : coffre doré" if ok else ""])
	if ok:
		d.message.emit("Nuée repoussée !\nUn coffre doré", 3.0)
		SurvivorLog.moment(d.time, "Nuée repoussée", "event")
		sv.offer_box("sv_gold", "Nuée repoussée ! Coffre doré : choisis une carte")
	else:
		d.message.emit("La nuée s'est dispersée", 2.0)


func _update_hunter(d: RunDirector) -> void:
	if _hunter_until < 0.0 or _hunter == null:
		return
	if not is_instance_valid(_hunter):
		_hunter = null
		return
	if _hunter.is_dead:
		return
	if d.time >= _hunter_until:
		history.append({"t": d.time, "id": "chasseur", "ok": false})
		print("[sv] chasseur : enfui")
		d.message.emit("Le chasseur s'enfuit…", 2.0)
		_hunter.queue_free()
		_hunter = null
		_hunter_until = -1.0


func _on_hunter_down() -> void:
	var d := sv.d
	if d == null or not is_instance_valid(d) or not Run.active or _hunter_until < 0.0:
		return
	_hunter_until = -1.0
	history.append({"t": d.time, "id": "chasseur", "ok": true})
	print("[sv] chasseur vaincu à %s" % SurvivorDirector.clock(d.time))
	d.message.emit("Chasseur vaincu !\nUn coffre doré", 3.0)
	SurvivorLog.moment(d.time, "Chasseur vaincu", "event")
	sv.offer_box("sv_gold", "Chasseur vaincu ! Coffre doré : choisis une carte")


## Événement en cours pour le HUD : {name, left} ou {}.
func current() -> Dictionary:
	var d := sv.d
	if not _nuee.is_empty() and not bool(_nuee.done) and d.time < float(_nuee.until):
		return {"name": "Nuée", "left": float(_nuee.until) - d.time}
	if _hunter_until >= 0.0 and _hunter != null and is_instance_valid(_hunter) and not _hunter.is_dead:
		return {"name": "Chasseur", "left": _hunter_until - d.time}
	return {}
