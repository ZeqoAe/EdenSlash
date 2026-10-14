class_name Combatant
extends CharacterBody3D
## Base commune du joueur et des monstres : PV, dégâts, mort, modèle animé.

signal died(who: Combatant, killer: Combatant)
signal health_changed(hp: float, max_hp: float)

enum Team { PLAYER, MONSTER }

const GRAVITY := 24.0

var immortal := false  # ne perd jamais de PV (mannequin d'entraînement)
var team: Team = Team.MONSTER
var display_name := ""
var level := 1
var max_hp := 100.0
var hp := 100.0
var atk := 10.0
var defense := 0.0
var is_dead := false
var radius := 0.5

var model: Node3D
var anim: AnimationPlayer
var kfm := ""  # nom du modèle Eden, pour les clés de motion.ini
var _current_anim := ""

# --- effets d'état ---------------------------------------------------------------
## Effets connus : bleed (saignement), burn (brûlure), purgatory, cranes, shock
## (dégâts subis +), scar (dégâts infligés -), stun, freeze (immobilisé), chill
## (ralenti) ; solar, shrine, marduk et les buffs temporaires des procs (héros).
const STATUS_INFO := {
	"bleed": {"name": "Saignement", "color": Color(0.95, 0.25, 0.25)},
	"purgatory": {"name": "Purgatoire", "color": Color(1.0, 0.55, 0.15)},
	"cranes": {"name": "Mille grues", "color": Color(0.6, 0.85, 1.0)},
	"scar": {"name": "Cicatrice", "color": Color(0.85, 0.5, 0.9)},
	"stun": {"name": "Renversé", "color": Color(1.0, 1.0, 0.4)},
	"solar": {"name": "Bénédiction solaire", "color": Color(1.0, 0.85, 0.3)},
	"shrine": {"name": "Volonté du sanctuaire", "color": Color(0.7, 1.0, 0.7)},
	"marduk": {"name": "Langue de Marduk", "color": Color(1.0, 0.4, 0.3)},
	"burn": {"name": "Brûlure", "color": Color(1.0, 0.45, 0.1)},
	"freeze": {"name": "Gelé", "color": Color(0.55, 0.85, 1.0)},
	"chill": {"name": "Ralenti", "color": Color(0.6, 0.8, 1.0)},
	"shock": {"name": "Électrocuté", "color": Color(0.75, 0.7, 1.0)},
	# buffs temporaires du héros (sets, cartes)
	"frenzy": {"name": "Frénésie", "color": Color(1.0, 0.6, 0.3)},
	"keen": {"name": "Œil acéré", "color": Color(1.0, 0.95, 0.5)},
	"haste": {"name": "Hâte", "color": Color(0.6, 1.0, 0.8)},
	"barrier": {"name": "Barrière", "color": Color(0.7, 0.85, 1.0)},
	"fury": {"name": "Fureur", "color": Color(1.0, 0.35, 0.35)},
	"poison": {"name": "Poison", "color": Color(0.55, 0.9, 0.3)},
	"regen": {"name": "Régénération", "color": Color(0.5, 1.0, 0.6)},
	"invisible": {"name": "Invisible", "color": Color(0.75, 0.75, 0.95)},
	"titan": {"name": "Mur du titan", "color": Color(0.8, 0.7, 0.5)},
	"survival": {"name": "Instinct de survie", "color": Color(0.6, 1.0, 0.6)},
	"might": {"name": "Puissance", "color": Color(1.0, 0.6, 0.4)},
	"swift": {"name": "Célérité", "color": Color(0.6, 1.0, 0.9)},
	"grace": {"name": "Grâce de sagesse", "color": Color(0.7, 0.8, 1.0)},
	"vitality": {"name": "Vitalité", "color": Color(0.6, 1.0, 0.7)},
	"hunter_stance": {"name": "Posture du chasseur", "color": Color(0.9, 0.9, 0.5)},
	"disarm": {"name": "Désarmé", "color": Color(0.8, 0.8, 0.8)},
	"angel": {"name": "Ange gardien", "color": Color(1.0, 0.95, 0.7)},
	"evasion": {"name": "Évasion", "color": Color(0.7, 1.0, 0.7)},
	# effets des classes importées d'Eden
	"root": {"name": "Immobilisé", "color": Color(0.55, 0.8, 0.45)},
	"sleep": {"name": "Endormi", "color": Color(0.75, 0.7, 1.0)},
	"fear": {"name": "Terreur", "color": Color(0.7, 0.4, 0.8)},
	"thorns": {"name": "Épines", "color": Color(0.6, 0.9, 0.4)},
	"resolve": {"name": "Résolution", "color": Color(1.0, 0.9, 0.6)},
	# insensibilités aux contrôles (voir CC_TYPES)
	"imm_stun": {"name": "Insensible au renversement", "color": Color(0.8, 0.85, 1.0)},
	"imm_freeze": {"name": "Insensible au gel", "color": Color(0.8, 0.85, 1.0)},
	"imm_sleep": {"name": "Insensible au sommeil", "color": Color(0.8, 0.85, 1.0)},
	"imm_fear": {"name": "Insensible à la terreur", "color": Color(0.8, 0.85, 1.0)},
	"imm_root": {"name": "Insensible à l'immobilisation", "color": Color(0.8, 0.85, 1.0)},
	"imm_disarm": {"name": "Insensible au désarmement", "color": Color(0.8, 0.85, 1.0)},
	# bonus d'attribut au lancement des sorts (cartes d'amélioration)
	"spell_str": {"name": "Force du sort", "color": Color(1.0, 0.65, 0.45)},
	"spell_agi": {"name": "Agilité du sort", "color": Color(0.6, 1.0, 0.8)},
	"spell_int": {"name": "Intelligence du sort", "color": Color(0.6, 0.75, 1.0)},
	"spell_wis": {"name": "Sagesse du sort", "color": Color(0.85, 0.7, 1.0)},
	# buffs des trophées (Trophies.STATUSES)
	"t_agi": {"name": "Vivacité", "color": Color(0.6, 1.0, 0.9)},
	"t_mind": {"name": "Esprit vif", "color": Color(0.7, 0.9, 1.0)},
	"t_str": {"name": "Rage du guerrier", "color": Color(1.0, 0.6, 0.4)},
	"t_arcane": {"name": "Arcanes", "color": Color(0.7, 0.8, 1.0)},
	"t_all": {"name": "Éveil", "color": Color(1.0, 0.95, 0.6)},
	"t_luck": {"name": "Bonne étoile", "color": Color(1.0, 0.9, 0.4)},
	"t_crit": {"name": "Instinct du prédateur", "color": Color(1.0, 0.95, 0.5)},
	"t_speed": {"name": "Frénésie", "color": Color(1.0, 0.6, 0.3)},
	"t_power": {"name": "Puissance", "color": Color(1.0, 0.35, 0.35)},
	"t_guard": {"name": "Carapace", "color": Color(0.7, 0.85, 1.0)},
	"t_evade": {"name": "Pas de l'ombre", "color": Color(0.7, 1.0, 0.7)},
	"t_riposte": {"name": "Riposte", "color": Color(1.0, 0.85, 0.5)},
	"t_wind": {"name": "Danse du vent", "color": Color(0.6, 1.0, 0.85)},
	"t_berserk": {"name": "Fureur du désespoir", "color": Color(1.0, 0.3, 0.25)},
	"t_vamp": {"name": "Soif de sang", "color": Color(0.9, 0.2, 0.3)},
	"t_harvest": {"name": "Moisson", "color": Color(0.9, 0.8, 0.4)},
	"t_bastion": {"name": "Bastion", "color": Color(0.7, 0.85, 1.0)},
	"t_mastery": {"name": "Maîtrise", "color": Color(0.75, 0.7, 1.0)},
	"t_rhythm": {"name": "Rythme", "color": Color(1.0, 0.7, 0.35)},
	"t_fortune": {"name": "Fortune", "color": Color(1.0, 0.9, 0.4)},
	"t_predator": {"name": "Prédateur", "color": Color(1.0, 0.5, 0.4)},
	"t_parry": {"name": "Contre parfait", "color": Color(1.0, 0.85, 0.5)},
	"t_survive": {"name": "Instinct de survie", "color": Color(0.6, 1.0, 0.7)},
}
## Dégâts par seconde des effets sur la durée, en part de l'attaque de la source.
const DOT_FACTOR := {"bleed": 0.15, "burn": 0.25, "poison": 0.2}
## Contrôles : chaque type a sa propre insensibilité. Un contrôle ne peut pas être remis tant
## qu'il dure, puis la cible y reste insensible CC_IMMUNITY s (buff « imm_<type> ») : on ne
## bloque pas un ennemi en boucle avec le même sort, mais enchaîner des contrôles de types
## différents (renversé, puis terreur, puis gel...) le tient longtemps.
const CC_TYPES := ["stun", "freeze", "sleep", "fear", "root", "disarm"]
const CC_IMMUNITY := 3.0
signal statuses_changed

var statuses := {}  # nom -> instant de fin
var clock := 0.0
var _dots := {}  # effet -> {dps, source, tick}
var _cc_msg_at := -10.0


## Le contrôle [param status] serait refusé (déjà en cours ou cible insensible).
func cc_refused(status: String) -> bool:
	return status in CC_TYPES and (has_status(status) or has_status("imm_" + status))


## Contrôle accepté : la cible y devient insensible jusqu'à sa fin + CC_IMMUNITY s.
## Refusé : « INSENSIBLE » au-dessus de la cible (pas plus d'une fois toutes les 2 s).
func _cc_gate(status: String, duration: float) -> bool:
	if not status in CC_TYPES:
		return true
	if cc_refused(status):
		if has_status("imm_" + status) and not has_status(status) and clock - _cc_msg_at > 2.0:
			_cc_msg_at = clock
			DamageNumber.spawn_text(self, "INSENSIBLE", Color(0.75, 0.85, 1.0))
		return false
	statuses["imm_" + status] = clock + duration + CC_IMMUNITY
	return true


func add_status(status: String, duration: float, source: Combatant = null) -> void:
	if duration <= 0.0:
		return
	if not _cc_gate(status, duration):
		return
	if DOT_FACTOR.has(status) and source:
		duration *= source.dot_duration_mult()
	statuses[status] = maxf(float(statuses.get(status, 0.0)), clock + duration)
	if DOT_FACTOR.has(status) and source:
		var dps := source.dot_power() * float(DOT_FACTOR[status]) * source.dot_mult()
		var cur: Dictionary = _dots.get(status, {})
		_dots[status] = {"dps": maxf(dps, float(cur.get("dps", 0.0))), "source": source, "tick": float(cur.get("tick", 0.0))}
	statuses_changed.emit()


## Attaque utilisée par les effets sur la durée de ce combattant.
func dot_power() -> float:
	return atk


## Multiplicateur des dégâts sur la durée infligés (cartes du héros).
func dot_mult() -> float:
	return 1.0


## Multiplicateur de la durée des effets sur la durée infligés (cartes du héros).
func dot_duration_mult() -> float:
	return 1.0


func has_status(status: String) -> bool:
	return float(statuses.get(status, -1.0)) > clock


func tick_statuses(delta: float) -> void:
	clock += delta
	for st in _dots.keys():
		if not has_status(st) or is_dead:
			_dots.erase(st)
			continue
		var d: Dictionary = _dots[st]
		d.tick = float(d.tick) + delta
		if float(d.tick) >= 1.0:
			d.tick = float(d.tick) - 1.0
			var src: Combatant = d.source if is_instance_valid(d.source) else null
			take_damage(float(d.dps), src, false, true)
			if is_dead:
				return
	var expired := false
	for s in statuses.keys():
		if float(statuses[s]) <= clock:
			statuses.erase(s)
			expired = true
	if expired:
		statuses_changed.emit()


## Multiplicateur des dégâts subis (débuffs ennemis, buffs du héros).
func damage_taken_mult() -> float:
	var m := 1.0
	if has_status("purgatory"):
		m *= 1.2
	if has_status("cranes"):
		m *= 1.15
	if has_status("solar"):
		m *= 0.75
	if has_status("shrine"):
		m *= 0.7
	if has_status("shock"):
		m *= 1.15
	if has_status("barrier"):
		m *= 0.6
	if has_status("titan"):
		m *= 0.5
	if has_status("resolve"):
		m *= 0.85
	return m


func damage_dealt_mult() -> float:
	return (0.7 if has_status("scar") else 1.0) * (1.25 if has_status("fury") else 1.0)


## Immobilisé (renversé, gelé ou endormi) : ni déplacement ni attaque.
func is_disabled() -> bool:
	return has_status("stun") or has_status("freeze") or has_status("sleep")


## Clés d'animation d'Eden (impacts, sons, traînée) de l'animation [param anim_name].
func keys_of(anim_name: String) -> Dictionary:
	return GameData.anim_keys(kfm, anim_name)


func setup_model(glb_path: String, texture_path := "", model_scale := 1.0) -> void:
	if kfm == "":
		kfm = glb_path.get_file().get_basename()
	model = EdenModel.instantiate(glb_path, texture_path)
	model.scale = Vector3.ONE * model_scale
	add_child(model)
	anim = EdenModel.find_anim_player(model)
	var box := EdenModel.bounds(model)
	radius = clampf(maxf(box.size.x, box.size.z) * 0.38 * model_scale, 0.35, 1.8)
	var shape := CapsuleShape3D.new()
	shape.radius = radius
	shape.height = maxf(radius * 2.0, box.size.y * model_scale * 0.8)
	var col := CollisionShape3D.new()
	col.shape = shape
	col.position.y = shape.height * 0.5
	add_child(col)


func play(anim_name: String, blend := 0.15, speed := 1.0, restart := false) -> void:
	if anim == null or not anim.has_animation(anim_name):
		return
	if anim_name == _current_anim and not restart and anim.is_playing():
		return
	_current_anim = anim_name
	anim.play(anim_name, blend, speed)
	if restart:
		anim.seek(0.0, true)


func anim_length(anim_name: String) -> float:
	if anim and anim.has_animation(anim_name):
		return anim.get_animation(anim_name).length
	return 1.0


func has_anim(anim_name: String) -> bool:
	return anim != null and anim.has_animation(anim_name)


## Les modèles d'Eden regardent vers +Z : on oriente le corps vers [param dir].
func face_direction(dir: Vector3, delta: float, turn_speed := 14.0) -> void:
	dir.y = 0.0
	if dir.length_squared() < 0.0001:
		return
	var target := atan2(dir.x, dir.z)
	rotation.y = lerp_angle(rotation.y, target, clampf(turn_speed * delta, 0.0, 1.0))


func forward() -> Vector3:
	return global_transform.basis.z.normalized()


## Héros contre héros (duel, duels de la Tour, entraînement, arène ML) : l'attaque d'un héros
## monte de 10 % par niveau mais ses PV bien moins vite ; sans correction, à haut niveau tout
## le monde tue en un coup (217 000 d'attaque pour 22 000 PV au niveau 90). Les dégâts entre
## héros sont ramenés à l'échelle des PV : rien ne change au niveau 10.
static func hero_vs_hero_factor(lv: int) -> float:
	var l := clampi(lv, 1, 200)
	var hp_k := GameData.player_max_hp(l) / GameData.player_max_hp(10)
	var atk_k := GameData.player_atk(l) / GameData.player_atk(10)
	return clampf(hp_k / atk_k, 0.0, 1.2)


## Part des PV max qu'un seul coup peut retirer en duel (pas de mort en un coup).
const PVP_HIT_CAP := 0.15  # valeur de départ ; le profil du mode (hit_cap) la remplace


## Puissance d'attaque (échelle des dégâts entre héros en duel).
func power() -> float:
	return atk


static func is_hero(c: Combatant) -> bool:
	return c is Player or c is ClassRival


func take_damage(amount: float, source: Combatant = null, crit := false, dot := false) -> void:
	if is_dead:
		return
	var hvh := source != null and source != self and is_hero(self) and is_hero(source)
	var pvp := hvh and PvpCaps.active()
	if pvp:
		amount *= PvpCaps.damage_mult(self, source)  # duel : échelle propre (PvpCaps)
	elif hvh:
		amount *= hero_vs_hero_factor(maxi(level, source.level))
	# la défense réduit en pourcentage (100 déf = -50 %) : les petits coups restent dangereux ;
	# en duel, la référence est la défense des deux héros (PvpCaps.taken)
	var taken := PvpCaps.taken(defense, source.defense) if pvp else 100.0 / (100.0 + maxf(defense, 0.0))
	var dmg := maxf(1.0, round(amount * damage_taken_mult() * (1.0 if dot else taken)))
	if pvp:
		dmg = minf(dmg, ceilf(max_hp * ModeRules.num("hit_cap", PVP_HIT_CAP)))
		dmg = _burst_limit(dmg)
		PvpCaps.note_hit(source, self, dmg)
	hp = maxf(0.0, hp - dmg)
	# entraînement : héros invincible, ennemis invincibles ou mannequin (les dégâts s'affichent)
	if immortal or (Training.active and (Training.hero_god if team == Team.PLAYER else Training.enemies_immortal)):
		hp = max_hp
	if Training.active and source and source.team == Team.PLAYER and team != Team.PLAYER:
		Training.record(dmg)
	health_changed.emit(hp, max_hp)
	if not dot and has_status("sleep"):
		statuses.erase("sleep")  # un coup réveille
		statuses_changed.emit()
	DamageNumber.spawn(self, dmg, crit, team == Team.PLAYER, dot)
	if source and source.team == Team.PLAYER and team != Team.PLAYER and Run.active:
		Run.add_combo_damage(dmg)
	_on_damaged(dmg, source)
	if hp <= 0.0:
		is_dead = true
		_on_death(source)
		died.emit(self, source)


## Pas de mort en un coup : les dégâts reçus sur la fenêtre (2 s) ne dépassent pas burst_cap des PV
## max ; au-delà, le reste du coup ne compte que pour burst_excess (on sent le coup, on ne vide pas
## la barre). Le temps est celui de la manche (PvpCaps.elapsed).
var _burst: Array = []  # [[instant, dégâts]]


func _burst_limit(dmg: float) -> float:
	var now := PvpCaps.elapsed
	var win := ModeRules.num("burst_window", 2.0)
	_burst = _burst.filter(func(e): return float(e[0]) <= now and now - float(e[0]) <= win)
	var sum := 0.0
	for e in _burst:
		sum += float(e[1])
	var room := maxf(0.0, max_hp * ModeRules.num("burst_cap", 0.35) - sum)
	if dmg > room:
		dmg = maxf(1.0, round(room + (dmg - room) * ModeRules.num("burst_excess", 0.25)))
	_burst.append([now, dmg])
	return dmg


func heal(amount: float) -> void:
	if is_dead:
		return
	if PvpCaps.active():
		amount *= PvpCaps.heal_mult()
	var before := hp
	hp = minf(max_hp, hp + amount)
	if team == Team.PLAYER and Run.active:
		Profile.record_add("healed", hp - before)  # mission du Clerc
	health_changed.emit(hp, max_hp)


func _on_damaged(_amount: float, _source: Combatant) -> void:
	pass


## Recul sous les coups (les monstres reculent ; les héros encaissent sans bouger).
func knockback(_impulse: Vector3) -> void:
	pass


func _on_death(_killer: Combatant) -> void:
	pass


func apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		velocity.y = -0.5
