class_name Procs
extends RefCounted
## Effets déclenchés des sets d'équipement et des cartes de build.
## Un proc = un déclencheur, une chance, une recharge interne (s) et un effet :
##   {"id", "trigger", "chance", "cd", "effect", ...paramètres de l'effet}
## Déclencheurs : hit (chaque monstre touché), skill_hit (impact d'une compétence),
## crit, kill, finisher (3e coup du combo), dodge, perfect (annulation parfaite),
## hurt (dégâts subis), low_hp (sous 30 % de PV).
## Effets : lightning (foudre en chaîne), freeze, chill, burn, shock, stun (sur les monstres
## autour de la cible), explosion, nova (gel autour du héros), buff (état temporaire
## du héros), stat_buff (bonus de stats temporaire, trophées), heal, cdr (recharges
## réduites), echo (la compétence frappe une 2e fois), double_hit (le coup frappe 2 fois).

const TRIGGER_TEXT := {
	"hit": "à l'impact", "skill_hit": "à l'impact d'une compétence", "crit": "sur un coup critique",
	"kill": "en tuant un monstre", "finisher": "au coup final du combo", "dodge": "en esquivant",
	"perfect": "sur une annulation parfaite", "hurt": "quand tu es touché", "low_hp": "sous 30 % de PV",
}
## Profondeur max des réactions en chaîne (une explosion qui tue déclenche une explosion…).
const MAX_DEPTH := 2

static var _depth := 0


## Déclenche les procs de [param player] liés à [param trigger].
static func fire(player: Player, trigger: String, target: Combatant = null, pos := Vector3.INF) -> void:
	if _depth >= MAX_DEPTH or player == null or player.is_dead:
		return
	if pos == Vector3.INF:
		pos = target.global_position if target and is_instance_valid(target) else player.global_position
	for p: Dictionary in player.procs:
		if p.trigger != trigger:
			continue
		if p.has("if_status") and (target == null or not is_instance_valid(target) or not target.has_status(String(p.if_status))):
			continue
		var id := String(p.id)
		if player.clock < float(player.proc_ready_at.get(id, -1.0)):
			continue
		if randf() > float(p.get("chance", 1.0)):
			continue
		player.proc_ready_at[id] = player.clock + float(p.get("cd", 0.0))
		_depth += 1
		run(player, p, target, pos)
		_depth -= 1


static func run(player: Player, p: Dictionary, target: Combatant, pos: Vector3) -> void:
	var r := float(p.get("radius", 3.0)) * player.area_mult
	var dur := float(p.get("duration", 2.0))
	match String(p.effect):
		"lightning":
			_lightning(player, target, pos, float(p.get("mult", 1.0)), int(p.get("chain", 2)), r)
		"freeze", "chill", "burn", "shock", "stun":
			var color := Combatant.STATUS_INFO[p.effect].color as Color
			Vfx.ring(player, pos, r, Color(color, 0.85))
			for m in monsters_near(player, pos, r):
				if p.effect == "stun" and (m as Monster) and (m as Monster).is_boss:
					continue
				m.add_status(String(p.effect), dur, player)
				if p.has("mult"):
					player.proc_hit(m, float(p.mult))
		"explosion":
			var col: Color = p.get("color", Color(1.0, 0.55, 0.2, 0.9))
			Vfx.ring(player, pos, r, col)
			EdenFx.play(player, "s00541", pos, 0.0, GameData.HERO_SCALE * clampf(r / 3.0, 0.8, 2.0))
			for m in monsters_near(player, pos, r):
				player.proc_hit(m, float(p.get("mult", 1.0)))
				for st in p.get("applies", {}):
					m.add_status(st, float(p.applies[st]), player)
		"nova":
			Vfx.ring(player, player.global_position, r, Color(0.55, 0.85, 1.0, 0.9))
			for m in monsters_near(player, player.global_position, r):
				m.add_status("freeze", dur, player)
		"buff":
			var st := String(p.status)
			player.add_status(st, dur, player)
			var info: Dictionary = Combatant.STATUS_INFO.get(st, {"name": st, "color": Color.WHITE})
			DamageNumber.spawn_text(player, info.name, info.color)
		"stat_buff":
			var sid := String(p.status)
			player.timed_stats[sid] = p.get("stats", {})
			player.add_status(sid, dur, player)
			var sinfo: Dictionary = Combatant.STATUS_INFO.get(sid, {"name": sid, "color": Color.WHITE})
			DamageNumber.spawn_text(player, sinfo.name, sinfo.color)
		"double_hit":
			if target and is_instance_valid(target) and not target.is_dead:
				DamageNumber.spawn_text(target, "DOUBLE !", Color(1.0, 0.85, 0.4))
				player.proc_hit(target, float(p.get("mult", 0.8)), true)
		"heal":
			player.heal(player.max_hp * float(p.get("amount", 0.2)))
			DamageNumber.spawn_text(player, "+%d %% PV" % roundi(float(p.get("amount", 0.2)) * 100), Color(0.5, 1.0, 0.55))
		"cdr":
			player.reduce_cooldowns(float(p.get("amount", 0.5)))
		"echo":
			player.echo_last_skill(float(p.get("mult", 0.6)))
	for extra in p.get("then", []):
		run(player, extra, target, pos)


## Foudre : frappe la cible puis saute vers [param chain] monstres proches.
static func _lightning(player: Player, target: Combatant, pos: Vector3, mult: float, chain: int, r: float) -> void:
	var hit: Array = []
	var cur: Combatant = target if target and is_instance_valid(target) and not target.is_dead else _closest(player, pos, r, hit)
	if cur == null:
		return
	Vfx.bolt(player, cur.global_position + Vector3.UP * 9.0, cur.global_position + Vector3.UP * 0.8)
	Sfx.play_at(player, cur.global_position, "atks071.wav", -6.0)
	for i in chain + 1:
		hit.append(cur)
		cur.add_status("shock", 3.0, player)
		player.proc_hit(cur, mult, true)
		Vfx.spark(player, cur.global_position + Vector3.UP, Color(0.7, 0.8, 1.0), true)
		var next := _closest(player, cur.global_position, r, hit)
		if next == null:
			break
		Vfx.bolt(player, cur.global_position + Vector3.UP * 1.0, next.global_position + Vector3.UP * 1.0)
		cur = next


static func _closest(player: Player, pos: Vector3, r: float, exclude: Array) -> Combatant:
	var best: Combatant = null
	var best_d := r
	for m in monsters_near(player, pos, r):
		if m in exclude:
			continue
		var d: float = m.global_position.distance_to(pos)
		if d <= best_d:
			best_d = d
			best = m
	return best


## Monstres vivants à moins de [param r] m (bord du monstre) de [param pos].
static func monsters_near(player: Node, pos: Vector3, r: float) -> Array:
	var out: Array = []
	for node in player.get_tree().get_nodes_in_group("monsters"):
		var m := node as Combatant
		if m == null or m.is_dead:
			continue
		var to := m.global_position - pos
		to.y = 0.0
		if to.length() - m.radius <= r:
			out.append(m)
	return out


## Texte lisible d'un proc (infobulles, cartes, fiche du personnage).
static func describe(p: Dictionary) -> String:
	if String(p.get("effect", "")) in ["stat_buff", "double_hit", "stun"]:
		return Trophies.describe(p)  # buffs des trophées
	var chance := float(p.get("chance", 1.0))
	var trig := String(p.get("trigger", ""))
	var head := ("%d %% de chances " % roundi(chance * 100) if chance < 1.0 else "") + String(TRIGGER_TEXT.get(trig, trig))
	var what := ""
	var r := float(p.get("radius", 3.0))
	match String(p.effect):
		"lightning":
			what = "foudre (%d %% de l'attaque) qui rebondit sur %d monstres à %d m" % [roundi(float(p.get("mult", 1.0)) * 100), int(p.get("chain", 2)), roundi(r)]
		"freeze":
			what = "gèle les monstres à %d m (%.1f s)" % [roundi(r), float(p.get("duration", 2.0))]
		"chill":
			what = "ralentit les monstres à %d m (%.1f s)" % [roundi(r), float(p.get("duration", 2.0))]
		"burn":
			what = "enflamme les monstres à %d m (%d s)" % [roundi(r), roundi(float(p.get("duration", 2.0)))]
		"shock":
			what = "électrocute les monstres à %d m (+15 %% de dégâts subis, %d s)" % [roundi(r), roundi(float(p.get("duration", 2.0)))]
		"explosion":
			what = "explosion de %d m (%d %% de l'attaque)" % [roundi(r), roundi(float(p.get("mult", 1.0)) * 100)]
		"nova":
			what = "nova de givre autour de toi (%d m, gel %.1f s)" % [roundi(r), float(p.get("duration", 2.0))]
		"buff":
			what = "%s pendant %d s" % [_buff_text(String(p.status)), roundi(float(p.get("duration", 2.0)))]
		"heal":
			what = "rend %d %% des PV" % roundi(float(p.get("amount", 0.2)) * 100)
		"cdr":
			what = "recharges -%.1f s" % float(p.get("amount", 0.5))
		"echo":
			what = "la compétence frappe une 2e fois (%d %%)" % roundi(float(p.get("mult", 0.6)) * 100)
	for extra in p.get("then", []):
		what += " + " + describe(extra).get_slice(" : ", 1)
	var cd := float(p.get("cd", 0.0))
	return "%s : %s%s" % [head.substr(0, 1).to_upper() + head.substr(1), what, (" (recharge %s s)" % str(snappedf(cd, 0.1))) if cd >= 1.0 else ""]


static func _buff_text(st: String) -> String:
	return {
		"frenzy": "Frénésie (+30 % de vitesse d'attaque)", "keen": "Œil acéré (+25 % de critique)",
		"haste": "Hâte (+30 % de vitesse)", "barrier": "Barrière (-40 % de dégâts subis)",
		"fury": "Fureur (+25 % de dégâts)",
	}.get(st, st)
