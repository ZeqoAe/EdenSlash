class_name BossBricks
extends RefCounted
## Briques de mécaniques de boss (bibliothèque de boss, passe M2). Une mécanique = une brique (une fonction de ce
## fichier) + des paramètres ; un boss = un modèle + 2 à 4 briques (data/bosses.json, BossLibrary). Le cerveau du boss
## (BossBrain) les déclenche selon leur sorte :
##   every   : toutes les N s (× 0,7 en 2e phase, × le rythme du palier et de la fureur), la 1re après « first » s ;
##   at      : une fois à chaque seuil de PV (part des PV max) ;
##   start   : à l'apparition ;
##   passive : une fois à l'apparition, la brique tourne ensuite seule (fureur au fil du temps).
## Règles communes : toute attaque est annoncée au sol (Telegraph, ou orbes visibles pour les projectiles) ; les dégâts
## passent par BossBrain._dmg (plafonnés en part des PV max du héros pour un boss de la bibliothèque : jamais de coup
## qui tue d'un coup) ; une brique « occupée » (busy) immobilise le boss le temps de l'incantation.
## Les huit mécaniques des boss de zone d'avant (adds, puddles, meteors, stomp, clones, totems, lasers, pet, vortex)
## sont ces mêmes briques avec leurs paramètres d'origine (from_legacy) : la Survie n'a pas changé.

const FAMILIES := {
	"ground": "Zones au sol", "summon": "Invocations", "enrage": "Fureur", "shield": "Boucliers",
	"charge": "Charges", "bullets": "Projectiles", "arena": "Arène qui se resserre", "position": "Placement",
	"counter": "Riposte", "waves": "Ondes à sauter",
}

## type -> {family, name, hint (conseil affiché à l'entrée), kind, every / first (s), at (seuils), busy, p (paramètres)}
const DEFS := {
	# --- zones au sol ---
	"puddles": {"family": "ground", "name": "Flaques", "hint": "quitte les flaques", "kind": "every", "every": 9.0, "first": 6.0,
		"p": {"count": 3, "radius": 3.0, "spread": 4.0, "life": 9.0, "dmg": 0.6, "dps": 0.45}},
	"meteors": {"family": "ground", "name": "Pluie de météores", "hint": "reste en mouvement sous les météores", "kind": "every", "every": 12.0, "first": 8.0,
		"p": {"count": 7, "spread": 9.0, "radius": 3.2, "dmg": 1.3, "puddle_every": 2, "dps": 0.45}},
	"lasers": {"family": "ground", "name": "Rayons", "hint": "sors des rayons", "kind": "every", "every": 14.0, "first": 12.0,
		"p": {"beams": 4, "waves": 2, "width": 2.4, "length": 26.0, "dmg": 1.4}},
	"grid": {"family": "ground", "name": "Damier", "hint": "une case sur deux explose, puis les autres", "kind": "every", "every": 15.0, "first": 10.0,
		"p": {"cell": 5.0, "cells": 5, "delay": 1.5, "gap": 1.3, "dmg": 1.3}},
	"sweep": {"family": "ground", "name": "Balayage", "hint": "laisse passer les lignes", "kind": "every", "every": 16.0, "first": 11.0,
		"p": {"lines": 6, "gap": 4.5, "width": 3.0, "length": 34.0, "delay": 1.2, "step": 0.45, "dmg": 1.2}},
	# --- invocations ---
	"adds": {"family": "summon", "name": "Renforts", "hint": "occupe-toi des renforts", "kind": "at", "at": [0.75, 0.5, 0.25],
		"p": {"count": 3, "growth": 4.0, "dist": 7.0}},
	"pet": {"family": "summon", "name": "Compagnon", "hint": "son compagnon se bat avec lui", "kind": "start",
		"p": {"monster": 0, "dist": 5.0}},
	"clones": {"family": "summon", "name": "Illusions", "hint": "trouve le vrai parmi ses illusions", "kind": "at", "at": [0.66, 0.33],
		"p": {"count": 2, "hp": 0.06, "atk": 0.45, "dist": 9.0}},
	"swarm": {"family": "summon", "name": "Nuée", "hint": "il appelle des renforts sans cesse", "kind": "every", "every": 20.0, "first": 12.0,
		"p": {"count": 4, "dist": 9.0}},
	"turrets": {"family": "summon", "name": "Tourelles", "hint": "détruis les tourelles", "kind": "every", "every": 26.0, "first": 10.0,
		"p": {"count": 2, "dist": 11.0, "hp": 0.025, "atk": 0.6, "every_shot": 2.4}},
	# --- fureur ---
	"enrage": {"family": "enrage", "name": "Rage", "hint": "il enrage à bout de forces", "kind": "at", "at": [0.3],
		"p": {"atk": 1.35, "speed": 1.3, "pace": 0.75}},
	"frenzy": {"family": "enrage", "name": "Impatience", "hint": "ne traîne pas : il frappe plus fort avec le temps", "kind": "passive",
		"p": {"after": 120.0, "step": 30.0, "atk": 0.12, "pace": 0.95, "max": 6}},
	# --- boucliers ---
	"totems": {"family": "shield", "name": "Totems", "hint": "détruis les totems pour briser son bouclier", "kind": "at", "at": [0.5],
		"p": {"count": 3, "dist": 11.0, "hp": 0.05}},
	"barrier": {"family": "shield", "name": "Barrière", "hint": "brise sa barrière avant qu'elle ne le soigne", "kind": "at", "at": [0.7, 0.35],
		"p": {"amount": 0.12, "time": 12.0, "heal": 0.08, "stagger": 3.0}},
	"crystals": {"family": "shield", "name": "Cristaux de soin", "hint": "détruis les cristaux qui le soignent", "kind": "at", "at": [0.55],
		"p": {"count": 3, "dist": 10.0, "hp": 0.03, "heal": 0.0015, "time": 20.0}},
	# --- charges ---
	"rampage": {"family": "charge", "name": "Ruée", "hint": "écarte-toi de ses charges", "kind": "every", "every": 15.0, "first": 9.0,
		"p": {"count": 3, "length": 16.0, "width": 3.5, "delay": 0.9, "dmg": 1.5}},
	"leap": {"family": "charge", "name": "Bond", "hint": "il retombe là où tu étais", "kind": "every", "every": 13.0, "first": 7.0,
		"p": {"radius": 5.0, "delay": 1.3, "dmg": 1.6}},
	# --- projectiles ---
	"spiral": {"family": "bullets", "name": "Spirale", "hint": "glisse entre les orbes", "kind": "every", "every": 14.0, "first": 8.0,
		"p": {"arms": 4, "waves": 10, "turn": 12.0, "interval": 0.2, "speed": 9.0, "dmg": 0.6}},
	"ring_burst": {"family": "bullets", "name": "Couronne d'orbes", "hint": "passe entre deux orbes", "kind": "every", "every": 12.0, "first": 6.0,
		"p": {"count": 14, "waves": 3, "interval": 0.7, "speed": 10.0, "dmg": 0.6}},
	"fan": {"family": "bullets", "name": "Éventail", "hint": "sors de l'éventail de tirs", "kind": "every", "every": 10.0, "first": 5.0,
		"p": {"count": 9, "arc": 120.0, "delay": 0.8, "speed": 15.0, "dmg": 0.7}},
	# --- arène ---
	"shrink": {"family": "arena", "name": "Arène qui se resserre", "hint": "reste au centre quand l'arène se resserre", "kind": "every", "every": 32.0, "first": 18.0,
		"p": {"from": 21.0, "to": 9.0, "time": 7.0, "hold": 6.0, "dps": 0.35}},
	# --- placement ---
	"safe_zone": {"family": "position", "name": "Cercle sûr", "hint": "rejoins le cercle sûr avant l'explosion", "kind": "every", "every": 20.0, "first": 14.0,
		"p": {"safe": 4.5, "dist": 9.0, "delay": 3.0, "dmg": 1.8}},
	"vortex": {"family": "position", "name": "Tourbillon", "hint": "éloigne-toi quand il t'attire", "kind": "every", "every": 18.0, "first": 16.0,
		"p": {"pull": 2.6, "time": 2.5, "radius": 6.5, "dmg": 2.2}},
	"gale": {"family": "position", "name": "Bourrasque", "hint": "lutte contre le vent pour revenir vers lui", "kind": "every", "every": 17.0, "first": 12.0,
		"p": {"push": 3.6, "time": 1.8, "edge": 14.0, "dmg": 1.6}},
	"gaze": {"family": "position", "name": "Regard", "hint": "passe dans son dos quand il te fixe", "kind": "every", "every": 16.0, "first": 10.0,
		"p": {"angle": 220.0, "radius": 30.0, "delay": 1.9, "dmg": 1.6}},
	"marks": {"family": "position", "name": "Marque", "hint": "la marque te suit, puis se fige : sors-en", "kind": "every", "every": 15.0, "first": 9.0,
		"p": {"radius": 3.5, "follow": 2.2, "fix": 1.1, "dmg": 1.5}},
	"blink": {"family": "position", "name": "Saut d'ombre", "hint": "il disparaît et laisse une explosion", "kind": "every", "every": 14.0, "first": 9.0,
		"p": {"radius": 4.5, "delay": 1.0, "dist": 9.0, "dmg": 1.4}},
	# --- riposte ---
	"reflect": {"family": "counter", "name": "Miroir", "hint": "ne frappe pas pendant le miroir", "kind": "every", "every": 17.0, "first": 12.0, "p": {}},
	# --- ondes ---
	"stomp": {"family": "waves", "name": "Ondes de choc", "hint": "saute par-dessus les ondes", "kind": "every", "every": 13.0, "first": 10.0,
		"p": {"waves": 3, "start": 7.0, "step": 6.0, "width": 2.5, "dmg": 1.2}},
}


## Brique complète (défauts de DEFS + ce que le boss précise) : {type, kind, every, first, at, p}.
static func normalize(brick: Dictionary) -> Dictionary:
	var t := String(brick.get("type", ""))
	var d: Dictionary = DEFS.get(t, {})
	if d.is_empty():
		push_warning("BossBricks : brique inconnue « %s »" % t)
		return {}
	var p: Dictionary = (d.get("p", {}) as Dictionary).duplicate()
	for k in brick:
		if not k in ["type", "every", "first", "at", "kind"]:
			p[k] = brick[k]
	return {"type": t, "kind": String(brick.get("kind", d.kind)), "every": float(brick.get("every", d.get("every", 0.0))),
		"first": float(brick.get("first", d.get("first", 0.0))), "at": brick.get("at", d.get("at", [])), "p": p}


## Mécaniques des boss de zone d'avant (zones.json -> dungeon.mechanics) : mêmes briques, paramètres d'origine.
static func from_legacy(mechanics: Array, dungeon: Dictionary) -> Array:
	var out: Array = []
	for m in mechanics:
		if not DEFS.has(String(m)) or String(m) == "reflect":
			continue  # le miroir des boss de zone reste le minuteur de base du cerveau
		var b := {"type": String(m)}
		if m == "pet":
			b["monster"] = int(dungeon.get("pet", 0))
		out.append(normalize(b))
	return out


static func family_of(type: String) -> String:
	return String(DEFS.get(type, {}).get("family", ""))


static func name_of(type: String) -> String:
	return String(DEFS.get(type, {}).get("name", type))


static func hint_of(type: String) -> String:
	return String(DEFS.get(type, {}).get("hint", ""))


## Lance la brique [param br] (normalisée) pour le cerveau [param b] ; true : le boss est occupé (incantation).
static func run(b: BossBrain, br: Dictionary) -> bool:
	var p: Dictionary = br.get("p", {})
	match String(br.get("type", "")):
		"puddles": return _puddles(b, p)
		"meteors": return _meteors(b, p)
		"lasers": return _lasers(b, p)
		"grid": return _grid(b, p)
		"sweep": return _sweep(b, p)
		"adds": return _adds(b, p)
		"pet": return _pet(b, p)
		"clones": return _clones(b, p)
		"swarm": return _swarm(b, p)
		"turrets": return _turrets(b, p)
		"enrage": return _enrage(b, p)
		"frenzy": return _frenzy(b, p)
		"totems": return _totems(b, p)
		"barrier": return _barrier(b, p)
		"crystals": return _crystals(b, p)
		"rampage": return _rampage(b, p)
		"leap": return _leap(b, p)
		"spiral": return _spiral(b, p)
		"ring_burst": return _ring_burst(b, p)
		"fan": return _fan(b, p)
		"shrink": return _shrink(b, p)
		"safe_zone": return _safe_zone(b, p)
		"vortex": return _vortex(b, p)
		"gale": return _gale(b, p)
		"gaze": return _gaze(b, p)
		"marks": return _marks(b, p)
		"blink": return _blink(b, p)
		"reflect":
			b._start_reflect()
			return true
		"stomp": return _stomp(b, p)
	return false


# --- outils --------------------------------------------------------------------------------------
static func _target(b: BossBrain) -> Combatant:
	var t: Combatant = b.boss._player
	return t if is_instance_valid(t) and not t.is_dead else null


static func _alive(b) -> bool:  # (non typé : le cerveau a pu être libéré pendant une attente)
	return is_instance_valid(b) and is_instance_valid(b.boss) and not b.boss.is_dead


static func _wait(b: BossBrain, t: float) -> void:
	await b.boss.get_tree().create_timer(t, false).timeout


static func _flat_yaw(from: Vector3, to: Vector3) -> float:
	var d := to - from
	return atan2(d.x, d.z)


static func _zone(b: BossBrain, at: Vector3, yaw: float, props: Dictionary) -> Telegraph:
	props["source"] = b.boss
	return Telegraph.spawn(b.boss, at, yaw, props)


## Orbe tiré par le boss à [param speed] m/s (projectile visible : l'annonce).
static func _shot(b: BossBrain, yaw: float, speed: float, dmg: float) -> void:
	var pr := Projectile.fire(b.boss, b.boss.global_position + Vector3.UP * 1.2, Vector3(sin(yaw), 0, cos(yaw)), dmg)
	pr.speed = speed
	pr.life = 30.0 / maxf(speed, 1.0)


# --- zones au sol --------------------------------------------------------------------------------
static func _puddles(b: BossBrain, p: Dictionary) -> bool:
	var t := _target(b)
	if t == null:
		return false
	var s := float(p.spread)
	for i in int(p.count):
		var off := Vector3(randf_range(-s, s), 0, randf_range(-s, s)) if i > 0 else Vector3.ZERO
		var at := t.global_position + off
		_zone(b, at, 0.0, {"shape": "circle", "radius": float(p.radius), "delay": 1.0, "damage": b._dmg(float(p.dmg))})
		b._hazard_later(at, float(p.radius), float(p.life), 1.0, float(p.dps))
	return false


static func _meteors(b: BossBrain, p: Dictionary) -> bool:
	var t := _target(b)
	if t == null:
		return false
	b.announce.emit("Pluie de météores !")
	b._begin("magic02", 2.2)
	var c := t.global_position
	var s := float(p.spread)
	for i in int(p.count):
		var at := c + Vector3(randf_range(-s, s), 0, randf_range(-s, s)) if i > 0 else c
		_zone(b, at, 0.0, {"shape": "circle", "radius": float(p.radius), "delay": 1.3 + i * 0.12, "damage": b._dmg(float(p.dmg)), "stun_time": 0.8})
		if int(p.puddle_every) > 0 and i % int(p.puddle_every) == 0:
			b._hazard_later(at, float(p.radius) * 0.75, 7.0, 1.4 + i * 0.12, float(p.dps))
	return true


static func _lasers(b: BossBrain, p: Dictionary) -> bool:
	b.announce.emit("Rayons !")
	b._begin("magic01", 2.4)
	var base := randf() * TAU
	var n := maxi(int(p.beams), 1)
	for wave in int(p.waves):
		for i in n:
			var yaw := base + i * TAU / n + wave * PI / n
			_zone(b, b.boss.global_position, yaw, {"shape": "line", "length": float(p.length), "width": float(p.width), "delay": 1.1 + wave * 0.9,
				"damage": b._dmg(float(p.dmg))})
	return true


## Damier centré sur le héros : une case sur deux, puis les autres (cases carrées = « line » aussi large que longue).
static func _grid(b: BossBrain, p: Dictionary) -> bool:
	var t := _target(b)
	if t == null:
		return false
	b.announce.emit("Damier !")
	b._begin("magic02", 1.6)
	var c := float(p.cell)
	var n := int(p.cells)
	var origin := t.global_position - Vector3(c * n * 0.5, 0, c * n * 0.5)
	for ix in n:
		for iz in n:
			var second := (ix + iz) % 2 == 1
			var at := origin + Vector3((ix + 0.5) * c, 0, iz * c)
			at = b.ground(at)
			_zone(b, at, 0.0, {"shape": "line", "length": c, "width": c, "delay": float(p.delay) + (float(p.gap) if second else 0.0),
				"damage": b._dmg(float(p.dmg))})
	return true


## Lignes parallèles qui tombent l'une après l'autre en traversant la position du héros.
static func _sweep(b: BossBrain, p: Dictionary) -> bool:
	var t := _target(b)
	if t == null:
		return false
	b.announce.emit("Balayage !")
	b._begin("attack02", 1.4)
	var yaw := randf() * TAU
	var along := Vector3(sin(yaw), 0, cos(yaw))
	var side := along.cross(Vector3.UP).normalized()
	var n := int(p.lines)
	var L := float(p.length)
	for i in n:
		var off := (i - (n - 1) * 0.5) * float(p.gap)
		var at := t.global_position + side * off - along * L * 0.5
		_zone(b, at, yaw, {"shape": "line", "length": L, "width": float(p.width), "delay": float(p.delay) + i * float(p.step),
			"damage": b._dmg(float(p.dmg))})
	return true


# --- invocations ---------------------------------------------------------------------------------
static func _adds(b: BossBrain, p: Dictionary) -> bool:
	var lost := 1.0 - b.boss.hp / maxf(b.boss.max_hp, 1.0)
	b._summon([], int(p.count) + int(lost * float(p.growth)), float(p.dist))
	b.announce.emit("%s appelle des renforts !" % b.short_name())
	return false


static func _pet(b: BossBrain, p: Dictionary) -> bool:
	if int(p.monster) <= 0:
		return false
	b._summon([int(p.monster)], 1, float(p.dist), true)
	b.announce.emit("%s appelle son compagnon !" % b.short_name())
	return false


static func _clones(b: BossBrain, p: Dictionary) -> bool:
	b.announce.emit("%s se dédouble !" % b.short_name())
	b._begin("magic01", 0.8)
	var c := b.boss.global_position
	var a := randf() * TAU
	b.boss.global_position = b.ground(c + Vector3(cos(a), 0, sin(a)) * float(p.dist))
	for m in b._summon([int(b.boss.data.id)], int(p.count), 6.0):
		m.max_hp = b.boss.max_hp * float(p.hp)
		m.hp = m.max_hp
		m.atk = b.boss.atk * float(p.atk)
		m.display_name = "Illusion de " + b.short_name()
	return true


static func _swarm(b: BossBrain, p: Dictionary) -> bool:
	b._summon([], int(p.count), float(p.dist))
	b.announce.emit("Une nuée accourt !")
	return false


## Tourelles immobiles (fragiles) : chacune tire un orbe annoncé (trait au sol) vers le héros toutes les « every_shot » s.
static func _turrets(b: BossBrain, p: Dictionary) -> bool:
	var out := b._summon([], int(p.count), float(p.dist), true)
	for m in out:
		m.passive = true
		m.move_speed = 0.0
		m.max_hp = b.boss.max_hp * float(p.hp)
		m.hp = m.max_hp
		m.display_name = "Tourelle"
		_turret_loop(b, m, b._dmg(float(p.atk)), float(p.get("every_shot", 2.4)))
	if not out.is_empty():
		b.announce.emit("Des tourelles se dressent : détruis-les !")
	return false


static func _turret_loop(b: BossBrain, m: Monster, dmg: float, every: float) -> void:
	await m.get_tree().create_timer(randf_range(0.8, 1.6), false).timeout
	while is_instance_valid(m) and not m.is_dead and _alive(b):
		var t := _target(b)
		if t != null and m.global_position.distance_to(t.global_position) < 26.0:
			var yaw := _flat_yaw(m.global_position, t.global_position)
			Telegraph.spawn(m, m.global_position, yaw, {"shape": "line", "length": 20.0, "width": 0.8, "delay": 0.7, "damage": 0.0, "source": m})
			await m.get_tree().create_timer(0.7, false).timeout
			if not is_instance_valid(m) or m.is_dead:
				return
			var pr := Projectile.fire(m, m.global_position + Vector3.UP * 1.0, Vector3(sin(yaw), 0, cos(yaw)), dmg)
			pr.speed = 13.0
		await m.get_tree().create_timer(every, false).timeout


# --- fureur --------------------------------------------------------------------------------------
static func _enrage(b: BossBrain, p: Dictionary) -> bool:
	b.boss.atk *= float(p.atk)
	b.boss.move_speed *= float(p.speed)
	b.pace *= float(p.pace)
	var aura := OmniLight3D.new()
	aura.light_color = Color(1.0, 0.15, 0.1)
	aura.light_energy = 1.0
	aura.omni_range = b.boss.radius * 2.5 + 2.0
	aura.shadow_enabled = false
	aura.position.y = 1.0
	b.boss.add_child(aura)
	b.announce.emit("%s entre en rage !" % b.short_name())
	return false


## Le combat traîne : un cran de fureur toutes les « step » s après « after » s (dégâts et rythme), « max » crans au plus.
static func _frenzy(b: BossBrain, p: Dictionary) -> bool:
	_frenzy_loop(b, p)
	return false


static func _frenzy_loop(b: BossBrain, p: Dictionary) -> void:
	await _wait(b, float(p.after))
	var n := 0
	while _alive(b) and n < int(p.max):
		n += 1
		b.boss.atk *= 1.0 + float(p.atk)
		b.pace *= float(p.pace)
		if n == 1:
			b.announce.emit("%s s'impatiente !" % b.short_name())
		await _wait(b, float(p.step))


# --- boucliers -----------------------------------------------------------------------------------
static func _totems(b: BossBrain, p: Dictionary) -> bool:
	b.announce.emit("Bouclier : détruis les totems !")
	b._begin("magic02", 1.0)
	b.boss.shielded = true
	b._totems = b._summon([], int(p.count), float(p.dist), true)
	for t in b._totems:
		t.display_name = "Totem du bouclier"
		t.move_speed = 0.0
		t.max_hp = b.boss.max_hp * float(p.hp)
		t.hp = t.max_hp
	if b._totems.is_empty():
		b.boss.shielded = false
	return true


## Barrière : absorbe « amount » × les PV max ; brisée à temps, le boss chancelle ; sinon il se soigne et lance une onde.
static func _barrier(b: BossBrain, p: Dictionary) -> bool:
	if b.barrier_left > 0.0:
		return false
	b.start_barrier(b.boss.max_hp * float(p.amount))
	b.announce.emit("Barrière : brise-la vite !")
	b._begin("magic02", 0.8)
	_barrier_timer(b, p)
	return true


static func _barrier_timer(b: BossBrain, p: Dictionary) -> void:
	var t := 0.0
	while t < float(p.time):
		await b.boss.get_tree().physics_frame
		if not _alive(b) or b.barrier_left <= 0.0:
			break
		t += b.boss.get_physics_process_delta_time()
	if not _alive(b):
		return
	if b.barrier_left <= 0.0:
		b.announce.emit("Barrière brisée : il chancelle !")
		b.stagger(float(p.stagger))
	else:
		b.end_barrier()
		b.boss.heal(b.boss.max_hp * float(p.heal))
		DamageNumber.spawn_text(b.boss, "SOIN", Color(0.5, 1.0, 0.5))
		b.announce.emit("La barrière tient : il se soigne !")
		b._cast_nova()


## Cristaux immobiles qui soignent le boss tant qu'ils tiennent.
static func _crystals(b: BossBrain, p: Dictionary) -> bool:
	var cr := b._summon([], int(p.count), float(p.dist), true)
	for m in cr:
		m.passive = true
		m.move_speed = 0.0
		m.max_hp = b.boss.max_hp * float(p.hp)
		m.hp = m.max_hp
		m.display_name = "Cristal de soin"
	if cr.is_empty():
		return false
	b.announce.emit("Cristaux de soin : détruis-les !")
	_crystals_loop(b, cr, float(p.heal), float(p.time))
	return false


## Soin du boss : « heal » × les PV max par seconde et par cristal debout, pendant « time » s au plus (puis ils s'éteignent).
static func _crystals_loop(b: BossBrain, cr: Array, heal: float, time: float) -> void:
	var t := 0.0
	while _alive(b):
		cr = cr.filter(func(m): return is_instance_valid(m) and not m.is_dead)
		if cr.is_empty():
			b.announce.emit("Cristaux brisés !")
			return
		if t >= time:
			for m in cr:
				m.take_damage(m.max_hp * 10.0 + 1.0, null)  # éteints
			return
		b.boss.heal(b.boss.max_hp * heal * cr.size() * 0.5)
		await _wait(b, 0.5)
		t += 0.5


# --- charges -------------------------------------------------------------------------------------
static func _rampage(b: BossBrain, p: Dictionary) -> bool:
	var n := int(p.count)
	b.announce.emit("%s charge !" % b.short_name())
	b._begin("move02", n * (float(p.delay) + 0.55) + 0.2)
	_rampage_loop(b, p, n)
	return true


static func _rampage_loop(b: BossBrain, p: Dictionary, n: int) -> void:
	for i in n:
		var t := _target(b)
		if not _alive(b) or t == null:
			return
		var to := t.global_position - b.boss.global_position
		to.y = 0.0
		b.boss.face_direction(to, 1.0, 100.0)
		var tg := _zone(b, b.boss.global_position, atan2(to.x, to.z), {"shape": "line", "length": float(p.length), "width": float(p.width),
			"delay": float(p.delay), "damage": b._dmg(float(p.dmg)), "stun_time": 0.8})
		await tg.resolved
		if not _alive(b):
			return
		var dest := b.ground(b.boss.global_position + to.normalized() * (float(p.length) - 2.0))
		b.boss.create_tween().tween_property(b.boss, "global_position", Vector3(dest.x, b.boss.global_position.y, dest.z), 0.25)
		await _wait(b, 0.3)


static func _leap(b: BossBrain, p: Dictionary) -> bool:
	var t := _target(b)
	if t == null:
		return false
	var at := t.global_position
	var d := float(p.delay)
	b._begin("attack02", d + 0.3)
	_zone(b, at, 0.0, {"shape": "circle", "radius": float(p.radius), "delay": d, "damage": b._dmg(float(p.dmg)), "stun_time": 1.0})
	var tw := b.boss.create_tween()
	tw.tween_interval(d * 0.35)
	tw.tween_property(b.boss, "global_position", Vector3(at.x, b.boss.global_position.y, at.z), d * 0.6).set_trans(Tween.TRANS_QUAD)
	return true


# --- projectiles ---------------------------------------------------------------------------------
static func _spiral(b: BossBrain, p: Dictionary) -> bool:
	b.announce.emit("Spirale d'orbes !")
	var dur := int(p.waves) * float(p.interval) + 0.9
	b._begin("magic01", dur)
	_zone(b, b.boss.global_position, 0.0, {"shape": "circle", "radius": 2.5, "delay": 0.8, "damage": 0.0})
	_spiral_loop(b, p)
	return true


static func _spiral_loop(b: BossBrain, p: Dictionary) -> void:
	await _wait(b, 0.8)
	var base := randf() * TAU
	var arms := maxi(int(p.arms), 1)
	for w in int(p.waves):
		if not _alive(b):
			return
		for a in arms:
			_shot(b, base + a * TAU / arms + deg_to_rad(float(p.turn)) * w, float(p.speed), b._dmg(float(p.dmg)))
		await _wait(b, float(p.interval))


static func _ring_burst(b: BossBrain, p: Dictionary) -> bool:
	b.announce.emit("Couronne d'orbes !")
	b._begin("magic02", int(p.waves) * float(p.interval) + 0.8)
	_zone(b, b.boss.global_position, 0.0, {"shape": "circle", "radius": 2.5, "delay": 0.7, "damage": 0.0})
	_ring_loop(b, p)
	return true


static func _ring_loop(b: BossBrain, p: Dictionary) -> void:
	await _wait(b, 0.7)
	var n := maxi(int(p.count), 1)
	for w in int(p.waves):
		if not _alive(b):
			return
		for i in n:
			_shot(b, (i + 0.5 * (w % 2)) * TAU / n, float(p.speed), b._dmg(float(p.dmg)))
		await _wait(b, float(p.interval))


static func _fan(b: BossBrain, p: Dictionary) -> bool:
	var t := _target(b)
	if t == null:
		return false
	var base := _flat_yaw(b.boss.global_position, t.global_position)
	var n := maxi(int(p.count), 2)
	var arc := deg_to_rad(float(p.arc))
	b.boss.face_direction(t.global_position - b.boss.global_position, 1.0, 100.0)
	b._begin("shoot01", float(p.delay) + 0.5)
	var yaws: Array[float] = []
	for i in n:
		var yaw := base - arc * 0.5 + arc * i / (n - 1)
		yaws.append(yaw)
		_zone(b, b.boss.global_position, yaw, {"shape": "line", "length": 22.0, "width": 0.9, "delay": float(p.delay), "damage": 0.0})
	_fan_fire(b, p, yaws)
	return true


static func _fan_fire(b: BossBrain, p: Dictionary, yaws: Array[float]) -> void:
	await _wait(b, float(p.delay))
	if not _alive(b):
		return
	for yaw in yaws:
		_shot(b, yaw, float(p.speed), b._dmg(float(p.dmg)))


# --- arène qui se resserre -----------------------------------------------------------------------
static func _shrink(b: BossBrain, p: Dictionary) -> bool:
	if is_instance_valid(b.wall):
		return false
	b.announce.emit("L'arène se resserre : reste près du centre !")
	var w := ArenaWall.new()
	w.brain = b
	w.r_from = float(p.from)
	w.r_to = float(p.to)
	w.t_close = float(p.time)
	w.t_hold = float(p.hold)
	w.dps = b._dps(float(p.dps))
	b.boss.get_tree().current_scene.add_child(w)
	w.global_position = b.home + Vector3.UP * 0.1
	b.wall = w
	return false


## Mur de l'arène : anneau rouge (de son rayon jusqu'au bord) qui se resserre puis s'ouvre ; dehors, des dégâts par
## demi-seconde. Toujours visible : une bande rouge et un liseré vif au rayon courant.
class ArenaWall extends Node3D:
	var brain: BossBrain
	var r_from := 21.0
	var r_to := 9.0
	var t_close := 7.0
	var t_hold := 6.0
	var dps := 20.0
	var r := 21.0
	var _t := 0.0
	var _tick := 0.0
	var _band: MeshInstance3D
	var _edge: MeshInstance3D

	func _ready() -> void:
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		m.albedo_color = Color(Telegraph.COLOR, 0.22)
		m.render_priority = 1
		_band = MeshInstance3D.new()
		_band.mesh = _ring_mesh(1.0, 3.0)
		_band.material_override = m
		_band.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_band)
		var em := m.duplicate() as StandardMaterial3D
		em.albedo_color = Color(1.0, 0.35, 0.2, 0.9)
		_edge = MeshInstance3D.new()
		_edge.mesh = _ring_mesh(1.0, 1.02)
		_edge.material_override = em
		_edge.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_edge.position.y = 0.02
		add_child(_edge)
		_apply()

	func _ring_mesh(a: float, c: float) -> Mesh:
		var im := ImmediateMesh.new()
		im.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
		var segs := 64
		for i in segs:
			var d0 := Vector3(sin(TAU * i / segs), 0, cos(TAU * i / segs))
			var d1 := Vector3(sin(TAU * (i + 1) / segs), 0, cos(TAU * (i + 1) / segs))
			for v in [d0 * a, d0 * c, d1 * c, d0 * a, d1 * c, d1 * a]:
				im.surface_add_vertex(v)
		im.surface_end()
		return im

	func _apply() -> void:
		_band.scale = Vector3(r, 1, r)
		_edge.scale = Vector3(r, 1, r)

	func _physics_process(delta: float) -> void:
		_t += delta
		if not is_instance_valid(brain) or not is_instance_valid(brain.boss) or brain.boss.is_dead:
			queue_free()
			return
		var open_t := 2.5
		if _t < t_close:
			r = lerpf(r_from, r_to, _t / t_close)
		elif _t < t_close + t_hold:
			r = r_to
		elif _t < t_close + t_hold + open_t:
			r = lerpf(r_to, r_from + 6.0, (_t - t_close - t_hold) / open_t)
		else:
			queue_free()
			return
		_apply()
		_tick -= delta
		if _tick > 0.0:
			return
		_tick = 0.5
		for c in Combatant.hostile_targets(get_tree(), brain.boss):
			var d := Vector2(c.global_position.x - global_position.x, c.global_position.z - global_position.z).length()
			if d > r:
				c.take_damage(dps * 0.5, brain.boss, false, true)
				c.add_status("burn", 1.5, brain.boss)


# --- placement -----------------------------------------------------------------------------------
static func _safe_zone(b: BossBrain, p: Dictionary) -> bool:
	var t := _target(b)
	if t == null:
		return false
	var a := randf() * TAU
	var safe := b.ground(t.global_position + Vector3(cos(a), 0, sin(a)) * float(p.dist))
	var d := float(p.delay)
	b.announce.emit("Rejoins le cercle sûr !")
	b._begin("magic02", d + 0.3)
	# cercle sûr (vert, sans dégâts) et tout le reste de l'arène (anneau rouge autour de lui)
	_zone(b, safe, 0.0, {"shape": "circle", "radius": float(p.safe), "delay": d, "damage": 0.0, "color": Color(0.3, 1.0, 0.45)})
	_zone(b, safe, 0.0, {"shape": "ring", "radius": 45.0, "inner": float(p.safe), "delay": d, "damage": b._dmg(float(p.dmg)), "stun_time": 1.0})
	return true


static func _vortex(b: BossBrain, p: Dictionary) -> bool:
	b.announce.emit("Tourbillon : éloigne-toi du boss !")
	b._begin("magic02", float(p.time) + 0.5)
	_zone(b, b.boss.global_position, 0.0, {"shape": "circle", "radius": float(p.radius), "delay": float(p.time) + 0.1, "damage": b._dmg(float(p.dmg)), "stun_time": 1.2})
	_drag(b, float(p.pull), float(p.time), 1.5)
	return true


## Attire (force > 0) ou repousse (force < 0) les héros pendant [param time] s.
static func _drag(b: BossBrain, force: float, time: float, min_d: float) -> void:
	var t := 0.0
	while t < time:
		await b.boss.get_tree().physics_frame
		if not _alive(b):
			return
		var dt := b.boss.get_physics_process_delta_time()
		t += dt
		for h in Combatant.hostile_heroes(b.boss.get_tree(), b.boss):
			if h.is_dead or (h.has_method("is_invulnerable") and h.is_invulnerable()):
				continue
			var to: Vector3 = b.boss.global_position - h.global_position
			to.y = 0.0
			if to.length() > min_d:
				h.global_position += to.normalized() * force * dt


static func _gale(b: BossBrain, p: Dictionary) -> bool:
	b.announce.emit("Bourrasque : reviens vers lui !")
	var d := float(p.time) + 1.0
	b._begin("magic01", d + 0.3)
	_zone(b, b.boss.global_position, 0.0, {"shape": "ring", "radius": 45.0, "inner": float(p.edge), "delay": d, "damage": b._dmg(float(p.dmg)), "stun_time": 1.0})
	_drag(b, -float(p.push), float(p.time), 0.0)
	return true


static func _gaze(b: BossBrain, p: Dictionary) -> bool:
	var t := _target(b)
	if t == null:
		return false
	var yaw := _flat_yaw(b.boss.global_position, t.global_position)
	b.boss.face_direction(t.global_position - b.boss.global_position, 1.0, 100.0)
	b.announce.emit("Il te fixe : passe dans son dos !")
	b._begin("magic01", float(p.delay) + 0.3)
	_zone(b, b.boss.global_position, yaw, {"shape": "cone", "radius": float(p.radius), "angle": float(p.angle), "delay": float(p.delay), "damage": b._dmg(float(p.dmg)), "stun_time": 1.2})
	return false


static func _marks(b: BossBrain, p: Dictionary) -> bool:
	var t := _target(b)
	if t == null:
		return false
	b.announce.emit("Marque : elle te suit, puis se fige !")
	var tg := _zone(b, t.global_position, 0.0, {"shape": "circle", "radius": float(p.radius), "delay": float(p.follow) + float(p.fix), "damage": b._dmg(float(p.dmg))})
	_follow(b, tg, t, float(p.follow))
	return false


static func _follow(b: BossBrain, tg: Telegraph, who: Combatant, time: float) -> void:
	var t := 0.0
	while t < time:
		await b.boss.get_tree().physics_frame
		if not is_instance_valid(tg) or not is_instance_valid(who) or not _alive(b):
			return
		t += b.boss.get_physics_process_delta_time()
		tg.global_position = who.global_position + Vector3.UP * 0.12


static func _blink(b: BossBrain, p: Dictionary) -> bool:
	var t := _target(b)
	if t == null:
		return false
	_zone(b, b.boss.global_position, 0.0, {"shape": "circle", "radius": float(p.radius), "delay": float(p.delay), "damage": b._dmg(float(p.dmg))})
	var a := randf() * TAU
	b.boss.global_position = b.ground(t.global_position + Vector3(cos(a), 0, sin(a)) * float(p.dist)) + Vector3.UP * 0.3
	b._begin("magic01", 0.6)
	return true


# --- ondes ---------------------------------------------------------------------------------------
static func _stomp(b: BossBrain, p: Dictionary) -> bool:
	b.announce.emit("Ondes de choc : saute par-dessus !")
	b._begin("attack02", 0.8 + int(p.waves) * 0.6)
	for i in int(p.waves):
		var r := float(p.start) + i * float(p.step)
		_zone(b, b.boss.global_position, 0.0, {"shape": "ring", "radius": r, "inner": r - float(p.width), "delay": 1.0 + i * 0.6,
			"damage": b._dmg(float(p.dmg)), "jumpable": true, "stun_time": 1.0})
	return true
