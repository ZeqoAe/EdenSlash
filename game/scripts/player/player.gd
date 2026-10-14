class_name Player
extends Combatant
## Héros contrôlé par le joueur, piloté par les données de sa classe
## (data/classes.json) : modèle, arme, attaques de base, 4 compétences de run.

signal xp_changed(xp: int, xp_next: int, level: int)
signal leveled_up(level: int)
signal skills_changed
signal stats_changed

## Saut nerveux par défaut (~0,5 s en l'air) : montée rapide, chute plus rapide encore.
## La carte « Apesanteur » rend le saut flottant (builds aériens, mages).
const JUMP_VELOCITY := 14.0
const GRAVITY_UP := 52.0
const GRAVITY_DOWN := 72.0
const COYOTE_TIME := 0.12  # on peut encore sauter juste après avoir quitté un rebord
const JUMP_BUFFER := 0.15  # un saut demandé juste avant d'atterrir part à l'atterrissage
## Annulation parfaite : esquiver dans cette fenêtre après l'impact d'une compétence
## donne une esquive plus longue et gratuite, rend 25 % de la recharge et monte la
## « Fluidité » (+10 % de dégâts par palier, 4 max, 3 s sans annulation parfaite = 0).
const PERFECT_WINDOW := 0.28
## Récupération après un sort : pas de nouveau sort avant la fin de l'animation + ce délai
## (l'impact se voit, moins de matraquage sur place) ; une esquive l'annule (sort, esquive,
## sort reste fluide).
const SKILL_RECOVERY := 0.45
## Enchaînement de sorts : blocage après l'appui (le même délai que la récupération d'un
## sort : appuyer pendant ce temps ne lance rien et casse la chaîne), durée de la barre,
## zone du bon timing (part de la barre) et bonus de dégâts du sort enchaîné.
const CHAIN_DELAY := SKILL_RECOVERY
const CHAIN_BAR := 3.0
const CHAIN_ZONE := Vector2(0.0, 1.0)
const CHAIN_BONUS := 0.2
const AIR_SKILL_BONUS := 0.1
const EVASION_CHANCE := 0.4  # statut « Évasion » (fumigène du voleur)

# --- statistiques d'Eden (voir recalc_stats) --------------------------------------------
var attrs := {}  # str, agi, int, wis, lck
var matk := 0.0
var mcrit := 0.05
var cast_speed := 1.0
var evasion_chance := 0.0  # esquive passive (agilité)
var parry_chance := 0.0  # parade : dégâts divisés par deux (force)
var heal_power := 1.0  # puissance de soin (sagesse)  # compétences lancées en l'air : +10 % de dégâts
const STEP_HEIGHT := 0.6
const HERO_RADIUS := 0.33
const BASE_SPEED := 6.5
const DODGE_DISTANCE := 6.0
const DODGE_TIME := 0.32
const DODGE_COOLDOWN := 0.45
const ATTACK_RANGE := 2.6
## Combo d'auto-attaque : le coup suivant doit partir moins de COMBO_WINDOW s
## après la fin du précédent ; le 3e coup (coup final) est un saut frappé en zone.
const COMBO_WINDOW := 0.6

var class_id := "samurai"
var cls: Dictionary
var xp := 0

# statistiques dérivées (niveau + équipement + passifs + buffs)
var crit := 0.05
var crit_dmg := 0.5
var atk_speed := 1.0
var move_mult := 1.0
var cdr := 0.0
var lifesteal := 0.0
# cartes de build et sets (voir Boons, Items.SETS, Procs)
var area_mult := 1.0  # rayon des zones
var reach_mult := 1.0  # portée (attaque de base, compétences en ligne / éventail / élan)
var dmg_mult := 1.0
var elite_mult := 1.0
var finisher_mult := 1.0
var finisher_area := 1.0
var finisher_hits := 1
var combo_window := COMBO_WINDOW
var dot_bonus := 1.0
var dot_duration := 1.0  # durée des effets sur la durée infligés (cartes)
var pickup_mult := 1.0  # zone de collecte des orbes d'expérience et des objets (carte Aimant)
var xp_mult := 1.0  # expérience gagnée par orbe (carte Érudit)
var execute := 0.0
var procs: Array = []  # effets déclenchés actifs
var timed_stats := {}  # statut -> stats ajoutées tant qu'il est actif (buffs des trophées)
var proc_ready_at := {}  # id du proc -> instant (clock) de fin de recharge

var skill_ready_at := {}  # id compétence -> instant
var dev_invincible := false  # mode dev : aucun dégât
var autoplay := false
var autoplay_idle := false  # test (--idle) : le pilote automatique ne bouge ni ne frappe
var autoplay_target := Vector3.INF
var bot: BotInput = null  # IA en apprentissage (arène ML) : remplace le clavier et la souris
var ml_counts := {"perfect": 0, "chain": 0, "dodged": 0}  # récompenses de l'arène ML
## Héros ennemi (arène ML, Tour) : dans l'équipe des monstres, il vise le joueur et joue sa
## classe [member class_id] avec son propre jeu de sorts, sans l'équipement, les cartes ni les
## talents du joueur. Sans [member bot], il ne fait rien (jamais le clavier ni la souris).
var foe := false
var kit_skills: Array = []  # [{id, rank}] : sort principal de chaque case (héros ennemi)
var kit_chains: Dictionary = {}  # case -> [{id, rank}] : enchaînements (héros ennemi)
var pvp_capped: Array = []  # statistiques ramenées à leur plafond JcJ (PvpCaps, duel)
var foe_gear: Dictionary = {}  # emplacement -> objet : équipement du héros ennemi (duel)
var foe_look: Dictionary = {}  # {body, head, back} : apparence du héros ennemi (duel)
var foe_extra: Dictionary = {}  # stats du profil hors équipement : maîtrise, certificats, aura
var built := false  # joué sur un profil type (use_build) : ni l'équipement ni les cartes du joueur

var _state := "idle"  # idle, attack, skill, dodge, jump, dead
var _state_time := 0.0
var _state_len := 0.0
var _hits: Array = []  # instants d'impact restants de l'action en cours
var _action: Dictionary = {}  # compétence / attaque en cours
var _combo_step := 0  # coups du combo déjà portés
var _combo_expire := 0.0
var _last_skill := {}  # dernière compétence portée (pour l'Écho)
var _target: Combatant  # cible verrouillée par clic (auto-attaque)
var _move_goal := Vector3.INF  # point visé par un clic de déplacement (modes souris)
var _click_moving := false  # clic de déplacement maintenu : on suit le curseur
var _dodge_dir := Vector3.ZERO
var _dodge_ready_at := 0.0
var _skill_lock_until := 0.0  # pas de nouveau sort avant (récupération ; l'esquive l'annule)
var _last_combat := -100.0
var _time := 0.0
var _weapon: Node3D
var _blade_tip: Node3D
var _blade_base: Node3D
var _trail: MeshInstance3D
var _trail_points: Array = []
var _trail_on := false

var _stuck_time := 0.0
var _safe_positions: Array[Vector3] = []
var _safe_timer := 0.0
var _torch: OmniLight3D
var _bot_last_pos := Vector3.ZERO
var _bot_check_at := 0.0
var _bot_detour := Vector3.ZERO
var _bot_detour_until := 0.0


func _ready() -> void:
	team = Team.MONSTER if foe else Team.PLAYER
	collision_layer = GameData.PHYS_MONSTER if foe else GameData.PHYS_PLAYER
	collision_mask = _body_mask()
	add_to_group("foe_heroes" if foe else "player")
	if not foe:
		class_id = Run.class_id if Run.active else Profile.selected_class
	cls = GameData.class_data(class_id)
	display_name = cls.get("name_fr", "Héros")
	kfm = "m"
	setup_model(cls.get("body_model", cls.get("model", "res://assets/player/body/body_m.glb")), "", GameData.HERO_SCALE)
	_dress_model()
	_slim_collision()
	floor_max_angle = deg_to_rad(55.0)
	floor_snap_length = 0.7
	_attach_weapon(_foe_weapon_code() if foe else Profile.weapon_code())
	_model_base = model.transform
	_build_trail()
	statuses_changed.connect(recalc_stats)
	statuses_changed.connect(_update_stealth_visual)
	if not foe:
		Run.changed.connect(recalc_stats)
		Profile.changed.connect(_on_profile_changed)
	recalc_stats()
	hp = max_hp
	health_changed.emit(hp, max_hp)
	play(_anim("idle"))


func _anim(key: String) -> String:
	if key == "battle":
		return String(_weapon_type().get("battle", cls.get("anims", {}).get("battle", "battle13")))
	return String(cls.get("anims", {}).get(key, key))


func _weapon_type() -> Dictionary:
	return GameData.weapon_type(Items.default_weapon_type(class_id) if foe else Run.weapon_type())


## Collisions du corps : le décor et l'autre camp.
func _body_mask() -> int:
	return GameData.PHYS_WORLD | (GameData.PHYS_PLAYER if foe else GameData.PHYS_MONSTER)


## Cibles de ce héros : monstres et héros ennemis, ou le joueur pour un héros ennemi.
func foes() -> Array:
	if foe:
		return get_tree().get_nodes_in_group("player")
	return get_tree().get_nodes_in_group("monsters") + get_tree().get_nodes_in_group("foe_heroes")


## Cartes de passifs de la run (aucune pour un héros ennemi).
func _passives() -> Dictionary:
	return {} if foe else Run.passives


## Jeu de sorts : celui de la run, ou le sien pour un héros ennemi.
func kit() -> Array:
	return kit_skills if foe else Run.skills


func kit_chain(slot: int) -> Array:
	return kit_chains.get(slot, []) if foe else Run.chain_of(slot)


func kit_skill_def(id: int) -> Dictionary:
	if not foe:
		return Run.skill_def(id)
	for s in cls.get("skills", []):
		if int(s.id) == id:
			return s
	return {}


# --- statistiques -------------------------------------------------------------------
func recalc_stats() -> void:
	if Run.active and not foe:
		Run.hero_level = level  # puissance des objets portés (suit le niveau, plafonnée)
	var own := foe or built  # héros ennemi ou profil type : ses propres stats
	var eq := _foe_equipment_stats() if own else Profile.equipment_stats()
	var arc := {} if own else Archive.bonus()  # bonus permanents de l'archive
	for k in arc:
		eq[k] = float(eq.get(k, 0.0)) + float(arc[k])
	var aura := {} if own else Profile.aura_stats(class_id)  # auras portées (pierres étoilées, pierres de lune)
	for k in aura:
		eq[k] = float(eq.get(k, 0.0)) + float(aura[k])
	var ps := foe_extra.duplicate() if own else Run.passive_stats()
	for st in timed_stats:  # buffs temporaires des trophées
		if has_status(st):
			for k in timed_stats[st]:
				ps[k] = float(ps.get(k, 0.0)) + float(timed_stats[st][k])
	# bonus en % de l'équipement (objets et sets d'Eden) : mêmes effets que les passifs
	for k in ["def_pct", "atk_pct", "matk_pct", "parry", "cast_speed", "heal_pct", "str_pct", "agi_pct", "int_pct", "wis_pct", "lck_pct"]:
		if eq.has(k):
			ps[k] = float(ps.get(k, 0.0)) + float(eq[k])
	var ratio := hp / max_hp if max_hp > 0.0 else 1.0
	var base: Dictionary = cls.get("base", {})
	# attributs d'Eden : base de la classe + croissance par niveau + équipement, × talents
	attrs = {}
	var ab: Dictionary = cls.get("attributes", {}).get("base", {})
	var ag: Dictionary = cls.get("attributes", {}).get("growth", {})
	var buff_pct := {"str": 0.3 if has_status("might") else 0.0, "agi": 0.3 if has_status("swift") else 0.0,
		"int": 0.3 if has_status("grace") else 0.0, "wis": 0.3 if has_status("grace") else 0.0, "lck": 0.0}
	for a in Items.ATTRIBUTES:
		attrs[a] = (float(ab.get(a, 6.0)) + float(ag.get(a, 1.0)) * (level - 1) + eq.get(a, 0.0)) * (1.0 + ps.get(a + "_pct", 0.0) + float(buff_pct[a]))
	var s_str: float = attrs.str
	var s_agi: float = attrs.agi
	var s_int: float = attrs.int
	var s_wis: float = attrs.wis
	var s_lck: float = attrs.lck
	var hp_buff := (0.2 if has_status("survival") else 0.0) + (0.15 if has_status("vitality") else 0.0)
	max_hp = maxf(1.0, (GameData.player_max_hp(level) * float(base.get("hp", 1.0)) + s_str * 2.0 + s_wis * 1.5) * (1.0 + ps.get("hp_pct", 0.0) + eq.get("hp_pct", 0.0) + hp_buff) + eq.get("hp", 0.0))
	atk = (GameData.player_atk(level) * float(base.get("atk", 1.0)) + eq.get("patk", 0.0) + s_str * 0.6) * (1.0 + ps.get("atk_pct", 0.0))
	matk = (GameData.player_atk(level) * float(base.get("matk", 0.5)) + eq.get("matk", 0.0) + s_int * 0.6) * (1.0 + ps.get("atk_pct", 0.0) + ps.get("matk_pct", 0.0))
	if has_status("marduk"):
		atk *= 1.3
		matk *= 1.3
	defense = (4.0 + level * 2.0 + eq.get("def", 0.0) + float(base.get("def", 0.0)) + s_str * 0.25) * (1.0 + ps.get("def_pct", 0.0))
	crit = 0.05 + float(base.get("crit", 0.0)) + eq.get("crit", 0.0) + ps.get("crit", 0.0) + s_lck * 0.0012 + s_agi * 0.0004 + (0.25 if has_status("keen") else 0.0)
	mcrit = 0.05 + eq.get("mcrit", 0.0) + ps.get("crit", 0.0) + ps.get("mcrit", 0.0) + s_lck * 0.0012 + s_wis * 0.0004 + (0.25 if has_status("keen") else 0.0)
	crit_dmg = 0.5 + eq.get("crit_dmg", 0.0) + ps.get("crit_dmg", 0.0) + s_lck * 0.0015
	cast_speed = 1.0 + s_agi * 0.001 + s_wis * 0.0005 + ps.get("cast_speed", 0.0)
	evasion_chance = clampf(s_agi * 0.0006 + eq.get("eva", 0.0) + ps.get("eva", 0.0), 0.0, 0.2)
	parry_chance = clampf(s_str * 0.0004 + ps.get("parry", 0.0), 0.0, 0.2)
	heal_power = 1.0 + s_wis * 0.004 + ps.get("heal_pct", 0.0) + (0.15 if has_status("survival") else 0.0)
	atk_speed = 1.0 + float(base.get("atk_speed", 0.0)) + s_agi * 0.0015 + eq.get("atk_speed", 0.0) + ps.get("atk_speed", 0.0) + (0.3 if has_status("marduk") else 0.0) + (0.3 if has_status("frenzy") else 0.0)
	move_mult = 1.0 + float(base.get("move_speed", 0.0)) + eq.get("move_speed", 0.0) + ps.get("move_speed", 0.0) + (0.3 if has_status("shrine") else 0.0) + (0.3 if has_status("haste") else 0.0)
	if has_status("titan"):
		move_mult *= 0.4
	cdr = clampf(eq.get("cdr", 0.0) + ps.get("cdr", 0.0), 0.0, 0.5)
	lifesteal = eq.get("lifesteal", 0.0) + ps.get("lifesteal", 0.0)
	area_mult = 1.0 + ps.get("area", 0.0) + eq.get("area", 0.0)
	reach_mult = 1.0 + ps.get("reach", 0.0) + eq.get("reach", 0.0)
	dmg_mult = maxf(0.1, 1.0 + ps.get("dmg_pct", 0.0) + eq.get("dmg_pct", 0.0))
	elite_mult = 1.0 + ps.get("elite_dmg", 0.0) + eq.get("elite_dmg", 0.0)
	finisher_mult = 1.0 + ps.get("finisher_dmg", 0.0)
	finisher_area = 1.0 + ps.get("finisher_area", 0.0)
	finisher_hits = 1 + int(ps.get("finisher_hits", 0))
	combo_window = COMBO_WINDOW + ps.get("combo_window", 0.0)
	dot_bonus = 1.0 + ps.get("dot_pct", 0.0) + eq.get("dot_pct", 0.0)
	dot_duration = 1.0 + ps.get("dot_dur", 0.0)
	pickup_mult = 1.0 + ps.get("pickup", 0.0)
	xp_mult = 1.0 + ps.get("xp_pct", 0.0)
	execute = minf(ps.get("execute", 0.0), 0.3)
	pvp_capped = PvpCaps.apply(self) if PvpCaps.active() else []  # duel : plafonds JcJ
	procs = Items.gear_procs(foe_gear) if own else Run.passive_procs() + Profile.equipment_procs()
	hp = clampf(max_hp * ratio, 1.0, max_hp)
	health_changed.emit(hp, max_hp)
	xp_changed.emit(xp, GameData.xp_to_next(level), level)
	stats_changed.emit()
	skills_changed.emit()


## Tableau des statistiques affiché dans le menu Personnage.
func stat_sheet() -> Array:
	var pc := func(v: float) -> String: return "%d %%" % roundi(v * 100)
	var rows := [
		["Niveau", str(level)], ["PV", "%d / %d" % [hp, max_hp]],
		["— Attributs —", ""],
		["Force", str(roundi(attrs.get("str", 0.0)))], ["Agilité", str(roundi(attrs.get("agi", 0.0)))],
		["Intelligence", str(roundi(attrs.get("int", 0.0)))], ["Sagesse", str(roundi(attrs.get("wis", 0.0)))],
		["Chance", str(roundi(attrs.get("lck", 0.0)))],
		["— Offensive physique —", ""],
		["Attaque physique", str(int(atk))], ["Vitesse d'attaque", pc.call(atk_speed)],
		["Critique physique", pc.call(crit)], ["Dégâts critiques", "+" + pc.call(crit_dmg)],
		["— Offensive magique —", ""],
		["Attaque magique", str(int(matk))], ["Vitesse d'incantation", pc.call(cast_speed)],
		["Critique magique", pc.call(mcrit)], ["Puissance de soin", pc.call(heal_power)],
		["— Défense —", ""],
		["Défense", str(int(defense))], ["Esquive", pc.call(evasion_chance)], ["Parade", pc.call(parry_chance)],
		["— Autres —", ""],
		["Vitesse", "%d %%" % roundi(move_mult * 100)], ["Recharge", "-%d %%" % roundi(cdr * 100)],
		["Vol de vie", "%d %%" % roundi(lifesteal * 100)],
		["Dégâts", "+%d %%" % roundi((dmg_mult - 1.0) * 100)], ["Zone d'effet", "+%d %%" % roundi((area_mult - 1.0) * 100)],
		["Portée", "+%d %%" % roundi((reach_mult - 1.0) * 100)],
	]
	# duel : les statistiques ramenées à leur plafond JcJ sont signalées
	var cap_rows := {"atk_speed": "Vitesse d'attaque", "cast_speed": "Vitesse d'incantation", "crit": "Critique physique",
		"mcrit": "Critique magique", "crit_dmg": "Dégâts critiques", "move_mult": "Vitesse", "lifesteal": "Vol de vie",
		"heal_power": "Puissance de soin", "dmg_mult": "Dégâts", "area_mult": "Zone d'effet", "reach_mult": "Portée"}
	for k in pvp_capped:
		for r in rows:
			if r[0] == cap_rows.get(k, ""):
				r[1] = String(r[1]) + " (plafond JcJ)"
	return rows


func dot_power() -> float:
	return maxf(atk, matk)


func dot_mult() -> float:
	return dot_bonus


func dot_duration_mult() -> float:
	return dot_duration


func _on_profile_changed() -> void:
	_attach_weapon(Profile.weapon_code())
	recalc_stats()


func gain_xp(amount: int) -> void:
	if is_dead:
		return
	xp += amount
	while xp >= GameData.xp_to_next(level):
		xp -= GameData.xp_to_next(level)
		level += 1
		Run.max_level = maxi(Run.max_level, level)
		Run.hero_level = level
		recalc_stats()
		hp = max_hp
		health_changed.emit(hp, max_hp)
		leveled_up.emit(level)
	xp_changed.emit(xp, GameData.xp_to_next(level), level)


## Arme tenue par le héros ennemi : l'apparence choisie dans son profil, sinon son arme.
func _foe_weapon_code() -> String:
	if String(foe_look.get("weapon_skin", "")) != "":
		return String(foe_look.weapon_skin)
	return String(foe_gear.get("weapon", {}).get("weapon", ""))


func power() -> float:
	return maxf(atk, matk)


## Joue le profil type [param b] au niveau [param lv] : son équipement (passifs et sets
## compris), sa maîtrise, ses certificats, son aura et son apparence (héros ennemi du duel, ou
## héros de l'arène d'IA). À poser avant add_child.
func use_build(b: Dictionary, lv: int) -> void:
	foe_gear = RivalBuilds.items(b, lv)
	foe_extra = RivalBuilds.extra_stats(b)
	foe_look = b.get("look", {})
	built = true


## Stats de l'équipement du héros ennemi (comme Profile.equipment_stats, sets compris).
func _foe_equipment_stats() -> Dictionary:
	var total := {}
	for slot in foe_gear:
		var st := Items.stats(foe_gear[slot])
		for s in st:
			total[s] = float(total.get(s, 0.0)) + float(st[s])
	for b in Items.active_set_bonuses(foe_gear):
		for s in b.stat:
			total[s] = float(total.get(s, 0.0)) + float(b.stat[s])
	return total


# --- arme et traînée --------------------------------------------------------------
## Tenue et cheveux de la classe (ou skin choisi) sur le corps commun.
func _dress_model() -> void:
	EdenModel.strip_body(model)
	var parts: Array = cls.get("parts", [])
	var outfit := String(foe_look.get("body", "")) if foe else Profile.outfit_of(class_id)
	var dyes := RivalBuilds.look_dyes(foe_look, cls) if foe else Profile.dye_map(class_id)
	for i in parts.size():
		var part := outfit if i == 0 and outfit != "" and ResourceLoader.exists(outfit) else String(parts[i])
		EdenModel.dress(model, part)
		if dyes.has(part):
			EdenModel.apply_dye(model, part, dyes[part])
	for p in ([foe_look.get("head", ""), foe_look.get("back", "")].filter(func(x): return String(x) != "" and ResourceLoader.exists(String(x))) if foe else Profile.worn_parts(class_id)):
		EdenModel.dress(model, String(p))
		if dyes.has(String(p)):
			EdenModel.apply_dye(model, String(p), dyes[String(p)])
	if foe:
		EdenFx.attach_aura_ids(self, RivalBuilds.aura_ids(foe_look), GameData.HERO_SCALE, false, RivalBuilds.aura_tint(foe_look))
	else:
		EdenFx.attach_auras(self, class_id, GameData.HERO_SCALE)


func _attach_weapon(code: String) -> void:
	if _weapon:
		_weapon.queue_free()
		_weapon = null
	_weapon = EdenModel.attach_weapon(model, EdenModel.weapon_entry(cls, code))
	if _weapon:
		_blade_base = _weapon.find_child("W1", true, false) as Node3D
		_blade_tip = _weapon.find_child("W2", true, false) as Node3D


func _build_trail() -> void:
	_trail = MeshInstance3D.new()
	_trail.mesh = ImmediateMesh.new()
	_trail.top_level = true
	_trail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.disable_fog = true  # la brume ne s'ajoute pas aux effets lumineux (carrés pâles)
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.vertex_color_use_as_albedo = true
	_trail.material_override = m
	add_child(_trail)


func _update_trail() -> void:
	var mesh := _trail.mesh as ImmediateMesh
	mesh.clear_surfaces()
	if _blade_base == null or _blade_tip == null:
		return
	if _trail_on:
		_trail_points.append([_blade_base.global_position, _blade_tip.global_position])
	if _trail_points.size() > 10 or (not _trail_on and not _trail_points.is_empty()):
		_trail_points.pop_front()
	if _trail_points.size() < 2:
		return
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for i in _trail_points.size():
		var a := float(i) / (_trail_points.size() - 1)
		var c := Color(1.0, 0.9, 0.75, a * 0.75)
		mesh.surface_set_color(Color(c.r, c.g, c.b, 0.0))
		mesh.surface_add_vertex(_trail_points[i][0])
		mesh.surface_set_color(c)
		mesh.surface_add_vertex(_trail_points[i][1])
	mesh.surface_end()


# --- boucle -------------------------------------------------------------------------
func _physics_process(delta: float) -> void:
	_time += delta
	_state_time += delta
	tick_statuses(delta)
	_apply_hero_gravity(delta)
	if is_dead:
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		return
	_pointer_input()
	var input_dir := _read_move_input()
	if input_dir.length() > 0.1:
		_target = null  # se déplacer annule l'auto-attaque
	match _state:
		"idle":
			_update_idle(input_dir, delta)
		"attack", "skill":
			_update_action(input_dir, delta)
		"dodge":
			_update_dodge()
		"jump":
			_update_jump(input_dir, delta)
		"dive":
			_update_dive()
		"stun":
			velocity.x = move_toward(velocity.x, 0.0, 30.0 * delta)
			velocity.z = move_toward(velocity.z, 0.0, 30.0 * delta)
			if _state_time >= _stun_len:
				_state = "idle"
				_stun_fx.visible = false
	var was_air := not is_on_floor()
	var before := global_position
	move_and_slide()
	if is_on_floor():
		_jumps_used = 0
		_air_dashes = 0
		_last_floor_time = _time
		if was_air and _state == "dive":
			_dive_impact()
	_handle_obstacles(input_dir, before, delta)
	_update_pose()
	_update_trail()
	if has_status("regen") and hp < max_hp:
		heal(max_hp * 0.03 * delta)
	# régénération lente, seulement après 6 s sans combat
	if _time - _last_combat > 6.0 and hp < max_hp:
		heal(max_hp * 0.015 * delta)


func _speed() -> float:
	return BASE_SPEED * move_mult


func _read_move_input() -> Vector3:
	if bot:
		return bot.move
	if foe:
		return Vector3.ZERO
	var v := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	if autoplay:
		v = Vector2.ZERO if autoplay_idle else _autoplay_input()
	elif v == Vector2.ZERO and _auto_move() and _move_goal == Vector3.INF:
		v = _autoplay_input()  # déplacement automatique (Paramètres) : le clavier reprend la main
	if v != Vector2.ZERO:
		_move_goal = Vector3.INF  # le clavier reprend la main
	elif _move_goal != Vector3.INF:
		var to := _move_goal - global_position
		to.y = 0.0
		if to.length() < 0.35:
			_move_goal = Vector3.INF
		else:
			return to.normalized()
	var cam := get_viewport().get_camera_3d()
	if cam == null or v == Vector2.ZERO:
		return Vector3(v.x, 0, v.y)
	return Vector3(v.x, 0, v.y).rotated(Vector3.UP, cam.global_rotation.y)


func _update_idle(input_dir: Vector3, delta: float) -> void:
	var move := input_dir
	# auto-attaque : on rejoint la cible verrouillée puis on frappe
	if _target and (not is_instance_valid(_target) or _target.is_dead):
		_target = null
	if _target and move.length() < 0.1:
		var to := _target.global_position - global_position
		to.y = 0.0
		if to.length() > attack_reach() + _target.radius:
			move = to.normalized()
		else:
			face_direction(to, delta, 30.0)
			if not _try_skill_input():
				_start_attack(_target.global_position)
			return
	velocity.x = move.x * _speed()
	velocity.z = move.z * _speed()
	var look := _cursor_dir() if _aims_at_cursor() and _target == null else move
	if move.length() > 0.1:
		face_direction(look if look != Vector3.ZERO else move, delta)
		play(_anim("run"), 0.12, move_mult)
	else:
		face_direction(look, delta, 20.0)
		play(_anim("battle") if _time - _last_combat < 4.0 else _anim("idle"), 0.25)

	if (_wants("jump") or _time < _jump_buffer_until) and can_jump():
		_start_jump()
	elif _wants("dodge") and _time >= _dodge_ready_at:
		_start_dodge(input_dir)
	else:
		if _try_skill_input():
			return
		if _wants("attack") and Settings.attack_button_attacks():
			_on_attack_pressed()
		else:
			_try_auto_attack(move.length() > 0.1)


## Compétence demandée au clavier (prête), sinon compétence automatique.
func _try_skill_input() -> bool:
	if _chain_input() != 0:
		return true  # touche d'une case en enchaînement (réussi ou raté)
	if _time < _skill_lock_until:
		return false
	for i in 4:
		if _wants("skill_%d" % (i + 1)) and cooldown_left(i) <= 0.0:
			use_skill(i)
			return true
	return _try_auto_skill()


func _wants(action: String) -> bool:
	if bot:
		return bot.wants(action)
	if foe:
		return false
	if autoplay:
		return false if autoplay_idle else _autoplay_wants(action)
	if action == "attack":
		return Input.is_action_pressed(action) and (_pad() or not _ui_has_mouse())
	return Input.is_action_just_pressed(action)


func _ui_has_mouse() -> bool:
	return get_viewport().gui_get_hovered_control() != null


## Clic gauche : verrouille le monstre sous le curseur (auto-attaque),
## sinon frappe en direction du curseur. Visée au curseur : frappe toujours vers la souris.
func _on_attack_pressed() -> void:
	if bot:
		_start_attack(bot.aim if bot.aim != Vector3.INF else global_position + forward())
		return
	if Input.is_action_just_pressed("attack") and (autoplay or not Settings.cursor_aim()):
		var m := monster_under_mouse()
		if m:
			_target = m
			return
	var aim := mouse_ground_point() if not autoplay else Vector3.INF
	if not autoplay and Settings.aim_mode() == "nearest":
		var near := nearest_monster(6.0)
		if near:
			aim = near.global_position
	if aim == Vector3.INF:
		var n := nearest_monster(6.0)
		aim = n.global_position if n else global_position + forward()
	_start_attack(aim)


## Modes souris (Paramètres > Contrôles) : clic sur le sol = se déplacer (maintenu :
## suivre le curseur), clic sur un monstre = le verrouiller et l'attaquer.
func _pointer_input() -> void:
	var act := Settings.move_click_action()
	if autoplay or bot or act == "" or is_dead or _pad():
		_click_moving = false
		return
	if Input.is_action_just_pressed(act) and not _ui_has_mouse():
		var m := monster_under_mouse()
		if m:
			_target = m
			_move_goal = Vector3.INF
			_click_moving = false
			return
		_click_moving = true
		_set_move_goal(true)
	elif _click_moving and Input.is_action_pressed(act):
		_set_move_goal(false)
	else:
		_click_moving = false


func _set_move_goal(marker: bool) -> void:
	var p := mouse_world_point()
	if p == Vector3.INF:
		return
	_move_goal = p
	_target = null
	if marker and Settings.get_v("interface", "move_marker"):
		Vfx.ring(self, p + Vector3.UP * 0.05, 0.7, Color(0.5, 1.0, 0.6, 0.85))


## Le héros regarde le curseur en permanence (visée au curseur).
func _aims_at_cursor() -> bool:
	return not autoplay and bot == null and not foe and Settings.cursor_aim() and not _pad()


## Combos parfaits automatiques (Paramètres > Combat), pour le héros du joueur seulement.
func _auto_combo() -> bool:
	return not autoplay and bot == null and not foe and Settings.auto_combo()


## Déplacement automatique (Paramètres > Combat).
func _auto_move() -> bool:
	return not autoplay and bot == null and not foe and Settings.auto_move()


var _auto_side := 1.0


## Pas de l'annulation parfaite automatique : la direction tenue, sinon de côté autour de la
## cible la plus proche (en alternant), pour rester à portée.
func _auto_step_dir(input_dir: Vector3) -> Vector3:
	if input_dir.length() > 0.1:
		return input_dir
	var m := nearest_monster(14.0)
	if m == null:
		return -forward()
	var to := m.global_position - global_position
	to.y = 0.0
	_auto_side = -_auto_side
	var side := to.normalized().cross(Vector3.UP) * _auto_side
	# trop près pour un tireur : on recule en même temps
	var back := -to.normalized() * (0.6 if attack_reach() > 6.0 and to.length() < attack_reach() * 0.5 else 0.0)
	return (side + back).normalized()


## Objectif du déplacement automatique (flèche de l'objectif : donjon, coffre, escalier…).
func _farm_goal() -> Vector3:
	var w := get_tree().get_first_node_in_group("world")
	if w and w.get("director") and w.director.has_method("farm_target"):
		return w.director.farm_target()
	return Vector3.INF


func _auto_objective() -> Vector3:
	var w := get_tree().get_first_node_in_group("world")
	if w and w.get("director") and w.director.has_method("objective_target"):
		return w.director.objective_target()
	return Vector3.INF


## On joue à la manette (Gamepad) : visée automatique au lieu du curseur.
func _pad() -> bool:
	return Gamepad.active and not autoplay and bot == null


## Point visé à la manette : le monstre le plus proche devant le héros (dans la direction du
## stick gauche, sinon de son regard), sinon un monstre tout proche, sinon droit devant.
func _pad_aim_point() -> Vector3:
	var v := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var dir := forward()
	var cam := get_viewport().get_camera_3d()
	if v.length() > 0.3 and cam:
		dir = Vector3(v.x, 0, v.y).rotated(Vector3.UP, cam.global_rotation.y)
	dir.y = 0.0
	dir = dir.normalized()
	var best: Combatant = null
	var best_d := INF
	for node in foes():
		var m := node as Combatant
		if m == null or m.is_dead:
			continue
		var to := m.global_position - global_position
		to.y = 0.0
		var d := to.length()
		if d > 14.0:
			continue
		var ahead := d < 3.0 or rad_to_deg(dir.angle_to(to.normalized())) < 55.0
		var score := d if ahead else d + 20.0
		if score < best_d and (ahead or d < 5.0):
			best = m
			best_d = score
	if best:
		return best.global_position
	return global_position + dir * 6.0


func _cursor_dir() -> Vector3:
	var p := mouse_ground_point()
	if p == Vector3.INF:
		# mode action, curseur au-dessus de l'horizon : droit devant la caméra
		var cam := get_viewport().get_camera_3d()
		if cam and Settings.aim_mode() == "action":
			var f := -cam.global_transform.basis.z
			f.y = 0.0
			return f.normalized()
		return Vector3.ZERO
	var d := p - global_position
	d.y = 0.0
	return d if d.length() > 0.3 else Vector3.ZERO


## Attaque automatique (Paramètres > Combat) : frappe seule un monstre à portée
## quand on ne se déplace pas.
func _try_auto_attack(moving: bool) -> bool:
	if autoplay or foe or moving or not Settings.auto_attack():
		return false
	var m := _monster_in_reach(attack_reach(), false)
	if m == null:
		return false
	_start_attack(m.global_position)
	return true


## Compétences automatiques : lancées dès qu'elles sont prêtes et qu'un monstre
## (ou la cible verrouillée, selon le réglage) est à leur portée.
func _try_auto_skill() -> bool:
	if autoplay or foe:
		return false
	for i in 4:
		if not Settings.auto_skill(i) or cooldown_left(i) > 0.0:
			continue
		var s := skill_in_slot(i)
		if s.is_empty():
			continue
		var m := _monster_in_reach(skill_reach(s), Settings.get_v("game", "auto_target") == "locked")
		if m:
			use_skill(i, m.global_position)
			return true
	return false


## Portée de l'attaque de base : corps à corps, ou tir pour l'archer et le mage.
func attack_reach() -> float:
	var wt := _weapon_type()
	return float(wt.get("attack_range", ATTACK_RANGE)) * (reach_mult if wt.has("attack_range") else 1.0)


## Portée d'une compétence pour le lancement automatique (zone + élan).
func skill_reach(s: Dictionary) -> float:
	if s.get("kind", "") in ["buff", "heal"]:
		return 6.0
	if s.get("kind", "") in ["bolt", "ground", "blink"]:
		return float(s.get("range", 10.0)) * reach_mult
	return maxf(skill_radius(s), ATTACK_RANGE) + float(s.get("dash", 0.0)) * reach_mult * 0.8


## Rayon d'une compétence : la portée allonge les lignes, éventails et élans,
## la zone d'effet élargit les cercles et les cônes.
func skill_radius(s: Dictionary) -> float:
	var r := float(s.get("radius", 0.0))
	return r * (reach_mult if String(s.get("kind", "")) in ["fan", "line", "dash"] else area_mult)


func _monster_in_reach(reach: float, locked_only: bool) -> Combatant:
	if locked_only:
		var t := current_target()
		return t if t and _edge_dist(t) <= reach else null
	var best: Combatant = null
	var best_d := reach
	for node in foes():
		var m := node as Combatant
		if m and not m.is_dead:
			var d := _edge_dist(m)
			if d <= best_d:
				best_d = d
				best = m
	return best


func _edge_dist(m: Combatant) -> float:
	var to := m.global_position - global_position
	to.y = 0.0
	return to.length() - m.radius


func monster_under_mouse() -> Combatant:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return null
	var mp := get_viewport().get_mouse_position()
	var from := cam.project_ray_origin(mp)
	var to := from + cam.project_ray_normal(mp) * 120.0
	var q := PhysicsRayQueryParameters3D.create(from, to, GameData.PHYS_MONSTER | GameData.PHYS_WORLD)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return null
	var m := hit.collider as Monster
	return m if m and not m.is_dead else null


# --- attaques de base ---------------------------------------------------------------
## Coups du combo de la classe (classes.json « combo »), sinon les attaques de base.
func combo_chain() -> Array:
	var chain: Array = _weapon_type().get("combo", cls.get("combo", []))
	if not chain.is_empty():
		return chain
	var out: Array = []
	for a in cls.get("anims", {}).get("attacks", ["attack01"]):
		out.append({"anim": a})
	return out


## Coup du combo en cours et taille du combo (HUD) ; Vector2i(0, n) hors combo.
func combo_state() -> Vector2i:
	var n := combo_chain().size()
	return Vector2i(_combo_step if _time <= _combo_expire or _state == "attack" else 0, n)


func _start_attack(aim: Vector3) -> void:
	var chain := combo_chain()
	if _time > _combo_expire or _combo_step >= chain.size():
		_combo_step = 0
	var step: Dictionary = chain[_combo_step]
	_combo_step += 1
	var finisher: bool = step.get("finisher", false)
	face_direction(aim - global_position, 1.0, 100.0)
	var radius := float(step.get("radius", ATTACK_RANGE)) * (area_mult * finisher_area if finisher else reach_mult)
	var action := {
		"mult": float(step.get("mult", 1.0)) * (finisher_mult if finisher else 1.0), "radius": radius,
		"arc": float(step.get("arc", 150.0)), "hit_fx": String(step.get("hit_fx", "s00141")),
		"applies": step.get("applies", {}), "dash": float(step.get("dash", 0.0)), "finisher": finisher,
		"dmg_type": String(_weapon_type().get("dmg_type", "phys")),
	}
	for k in ["max_targets", "pull", "heal", "crit_bonus", "land_hit", "leap_forward", "self_status", "move", "drop", "spread", "volley",
			"hits", "flip", "spin_turns"]:
		if step.has(k):
			action[k] = step[k]
	_break_stealth()
	match String(step.get("kind", "")):
		"ground":
			# zone au sol à l'endroit visé (pluie de flèches, marteau, zones du mage)
			var to_aim := aim - global_position
			to_aim.y = 0.0
			action["kind"] = "ground"
			action["target"] = global_position + to_aim.limit_length(float(step.get("range", attack_reach())) * reach_mult)
		"heal":
			action["kind"] = "heal"
	if step.has("move"):
		action["move_dir"] = _evade_dir() if step.get("move_dir", "forward") == "evade" else forward()
	if step.get("bolt", false):
		action["kind"] = "bolt"
		action["range"] = attack_reach()
		action["projectile"] = String(step.get("projectile", "arrow"))
		action["pierce"] = int(step.get("pierce", 0)) + (1 if finisher else 0)
		action["volley"] = int(step.get("volley", 1))
	if finisher and finisher_hits > 1:
		action["hits"] = maxi(finisher_hits, int(action.get("hits", 1)))
		action["arc"] = 360.0
	_begin_action("attack", String(step.anim), atk_speed * 1.25 * float(step.get("speed", 1.0)), action)
	if is_on_floor() and float(step.get("leap", 0.0)) > 0.0:
		velocity.y = float(step.get("leap", 0.0))  # saut automatique (salto du samouraï)
	_combo_expire = _time + _state_len + combo_window


func _begin_action(state: String, anim_name: String, speed: float, action: Dictionary) -> void:
	_state = state
	_state_time = 0.0
	_action = action
	var keys := keys_of(anim_name)
	var length := anim_length(anim_name)
	_state_len = length / speed
	_hits = []
	var key_hits: Array = keys.get("hit", [])
	var n_hits := int(action.get("hits", maxi(key_hits.size(), 1)))
	if action.get("land_hit", false):
		key_hits = []
	if key_hits.size() >= n_hits:
		for t in key_hits.slice(key_hits.size() - n_hits):
			_hits.append(float(t) / speed)
	else:
		# coups répartis sur la partie active de l'animation
		var t0 := float(key_hits[0]) if not key_hits.is_empty() else length * 0.4
		for i in n_hits:
			_hits.append(lerpf(t0, length * 0.8, float(i) / maxf(n_hits - 1, 1)) / speed)
	for snd in keys.get("sounds", []):
		get_tree().create_timer(float(snd[0]) / speed, false).timeout.connect(
			func(): Sfx.play_at(self, global_position, String(snd[1]), -4.0))
	var trail: Array = keys.get("trail", [])
	_action["trail"] = [float(trail[0]) / speed, float(trail[-1]) / speed] if trail.size() >= 2 else [_hits[0] - 0.12, _hits[-1] + 0.08]
	_last_combat = _time
	play(anim_name, 0.06, speed, true)
	if Settings.get_v("interface", "attack_zone"):
		_show_attack_zone()


## Zone touchée par l'action en cours, en bleu au sol jusqu'à l'impact (option des
## Paramètres) : cône, cercle, ligne ou zone visée, comme les annonces rouges des monstres.
func _show_attack_zone() -> void:
	var kind := String(_action.get("kind", "cone"))
	var r := float(_action.get("radius", 0.0))
	var t0: float = _hits[0] if not _hits.is_empty() else 0.25
	var props := {"damage": 0.0, "delay": clampf(t0, 0.15, 1.2), "color": Telegraph.PLAYER_COLOR, "small": true}
	var pos := global_position
	if kind == "ground" and _action.has("target"):
		pos = _action.target
		props.merge({"shape": "circle", "radius": r})
	elif kind in ["bolt", "line"] or float(_action.get("range", 0.0)) > r + 1.0:
		props.merge({"shape": "line", "length": maxf(float(_action.get("range", 0.0)), r), "width": maxf(1.2, minf(r, 3.0)) if kind == "line" else 1.2})
	elif r <= 0.0:
		return
	elif float(_action.get("arc", 360.0)) >= 359.0 or kind in ["spin", "buff", "heal"]:
		props.merge({"shape": "circle", "radius": r})
	else:
		props.merge({"shape": "cone", "radius": r, "angle": float(_action.get("arc", 90.0))})
	Telegraph.spawn(self, pos, rotation.y, props)


func _update_action(input_dir: Vector3, delta: float) -> void:
	var dash: float = _action.get("dash", 0.0)
	var push := Vector3.ZERO
	var land_hit: bool = _action.get("land_hit", false)
	if land_hit and not _action.get("hit_done", false):
		# salto : élan vers l'avant, impact (et étourdissement) à la retombée
		_hits.clear()
		push = forward() * float(_action.get("leap_forward", 0.0))
		if _state_time > 0.15 and is_on_floor():
			_resolve_hit()
	elif dash > 0.0 and not _hits.is_empty():
		push = forward() * (dash / maxf(_hits[0], 0.1))
	elif _state == "attack" and _state_time < _state_len * 0.35:
		push = forward() * 1.2
	velocity.x = push.x + input_dir.x * 0.8
	velocity.z = push.z + input_dir.z * 0.8
	var tr: Array = _action.get("trail", [0.0, 0.0])
	_trail_on = _state_time >= tr[0] and _state_time <= tr[1]
	while not _hits.is_empty() and _state_time >= _hits[0]:
		_hits.pop_front()
		_resolve_hit()
	# enchaînement : la touche de la case pendant l'action (barre du bon timing)
	if _chain_input() == 2:
		return
	# l'esquive annule toute action (une compétence pas encore sortie est perdue) ;
	# juste après l'impact d'une compétence : annulation parfaite
	var auto_perfect: bool = _auto_combo() and _state == "skill" and _action.get("hit_done", false) and _time - _last_hit_at >= 0.06 \
		and _time - _last_hit_at <= PERFECT_WINDOW and _hits.is_empty() and float(_action.get("heal", 0.0)) <= 0.0
	if auto_perfect:
		# combos parfaits : petit pas de côté autour de la cible (on reste à portée), Fluidité
		_trail_on = false
		_perfect_cancel()
		_start_dodge(_auto_step_dir(input_dir), true)
		_dodge_mult = 0.45
		return
	if _wants("dodge"):
		var perfect: bool = _state == "skill" and _action.get("hit_done", false) and _time - _last_hit_at <= PERFECT_WINDOW
		var air_ok := is_on_floor() or _air_dashes < max_air_dashes()
		if perfect or (_time >= _dodge_ready_at and air_ok):
			if not is_on_floor() and not perfect:
				_air_dashes += 1
			_trail_on = false
			if perfect:
				_perfect_cancel()
			_start_dodge(input_dir, perfect)
			return
	# une compétence annule l'attaque de base : l'appui n'est plus perdu pendant l'auto-attaque
	if _state == "attack" and _try_skill_input():
		_trail_on = false
		return
	# le saut annule l'attaque de base à tout moment, une compétence après son impact
	var cancel_ok: bool = _state == "attack" or _action.get("hit_done", false)
	if cancel_ok and _wants("jump") and can_jump():
		_trail_on = false
		_start_jump()
		return
	var end := _state_len * (0.75 if _state == "attack" else 0.92)
	if _state_time >= end and _hits.is_empty() and (not land_hit or _action.get("hit_done", false) or _state_time > 2.0):
		_trail_on = false
		if is_on_floor():
			_state = "idle"
		else:
			_state = "jump"  # fin d'une compétence aérienne : on retombe
			_state_time = 0.3


## Applique les dégâts de l'action en cours à tous les monstres de la zone.
func _resolve_hit() -> void:
	var first_hit: bool = not _action.get("hit_done", false)
	_action["hit_done"] = true
	_last_hit_at = _time
	var is_skill := _state == "skill"
	if _action.get("finisher", false) and first_hit:
		if _action.get("land_hit", false):
			# retombée du salto : onde de choc
			Vfx.shockwave(self, global_position, float(_action.radius) * 1.4)
			EdenFx.play(self, "s00541", global_position, rotation.y, GameData.HERO_SCALE * 1.8)
			_shake(1.2)
		else:
			Vfx.ring(self, global_position, float(_action.radius), Color(1.0, 0.85, 0.4, 0.9))
			EdenFx.play(self, "s00541", global_position, rotation.y, GameData.HERO_SCALE * 1.3)
			_shake(0.5)
	var hit: Combatant = null
	if float(_action.get("move", 0.0)) > 0.0:
		_quick_move(_action.get("move_dir", forward()), float(_action.move) * reach_mult)
	if _action.has("self_status"):
		for st in _action.self_status:
			add_status(st, float(_action.self_status[st]), self)
	if _action.has("drop"):
		_sky_drop(_action.get("target", global_position), float(_action.radius), String(_action.drop))
	match String(_action.get("kind", "")):
		"bolt":
			_fire_bolts(_action, is_skill)
			return
		"heal":
			_heal_action(_action)
			hit = _resolve_area(_action, global_position, forward(), is_skill) if float(_action.get("radius", 0.0)) > 0.0 else null
		"move":
			hit = _resolve_area(_action, global_position, forward(), is_skill) if float(_action.get("radius", 0.0)) > 0.0 else null
		"ground":
			var a := _action.duplicate()
			a["arc"] = 360.0
			var at: Vector3 = _action.get("target", global_position)
			Vfx.ring(self, at, float(_action.radius), Color(1.0, 0.6, 0.3, 0.9))
			EdenFx.play(self, String(_action.get("hit_fx", "")), at, rotation.y, GameData.HERO_SCALE * 1.2)
			hit = _resolve_area(a, at, forward(), is_skill)
		_:
			hit = _resolve_area(_action, global_position, forward(), is_skill)
	if is_skill and not _action.get("echo", false) and _action.get("kind", "") != "buff":
		_last_skill = {"action": _action.duplicate(true), "pos": global_position, "fwd": forward()}
		if hit:
			Procs.fire(self, "skill_hit", hit, hit.global_position)
	if _action.get("finisher", false) and first_hit:
		Procs.fire(self, "finisher", hit, global_position)


## Applique [param action] à tous les monstres de sa zone (rayon, arc) depuis
## [param origin]. Renvoie le premier monstre touché.
func _resolve_area(action: Dictionary, origin: Vector3, fwd: Vector3, is_skill: bool) -> Combatant:
	var radius: float = action.get("radius", ATTACK_RANGE)
	var arc: float = action.get("arc", 150.0)
	var hits := 0
	var first: Combatant = null
	if action.get("kind", "") != "buff":
		var col := Color(1.0, 0.8, 0.5, 0.85) if not is_skill else Color(1.0, 0.45, 0.25, 0.9)
		if action.get("echo", false):
			col = Color(0.75, 0.5, 1.0, 0.9)
		Vfx.slash(self, origin, fwd, radius, arc, col)
	if not foe and action.get("kind", "") != "buff":
		get_tree().call_group("breakables", "hit_area", origin, fwd, radius, arc)  # jarres, caisses, cristaux
	var targets: Array = []
	for node in foes():
		var m := node as Combatant
		if m == null or m.is_dead:
			continue
		var to := m.global_position - origin
		to.y = 0.0
		var dist := to.length() - m.radius
		if dist > radius:
			continue
		if arc < 360.0 and dist > 0.6 and rad_to_deg(fwd.angle_to(to.normalized())) > arc * 0.5:
			continue
		targets.append([dist, m, to.normalized()])
	var max_t := int(action.get("max_targets", 0))
	if max_t > 0 and targets.size() > max_t:
		targets.sort_custom(func(a, b): return a[0] < b[0])
		targets = targets.slice(0, max_t)
	for t in targets:
		if first == null:
			first = t[1]
		_hit_monster(t[1], t[2], action, is_skill)
		hits += 1
	if hits > 0:
		_last_combat = _time
		_hit_pause(0.04 if hits < 4 else 0.06)
	return first


# --- tirs, soins, téléportation (archer, mage, clerc, voleur) ----------------------
## Tire la volée de l'action en cours (attaque de base ou compétence).
func _fire_bolts(action: Dictionary, is_skill: bool) -> void:
	var n := maxi(1, int(action.get("volley", 1)))
	var spread := deg_to_rad(float(action.get("spread", 0.0)) if n > 1 else 0.0)
	var fwd := forward()
	var a := action.duplicate()
	a["is_skill"] = is_skill
	for i in n:
		var off := (float(i) / float(n - 1) - 0.5) * spread if n > 1 else 0.0
		HeroBolt.fire(self, global_position + Vector3.UP * 1.1 + fwd * 0.6, fwd.rotated(Vector3.UP, off), a)
	_last_combat = _time


var _model_base := Transform3D.IDENTITY


## Pose du modèle pendant certains coups : salto avant (rotation autour du buste) et
## toupie (tours sur soi). Toute autre action remet le modèle droit.
func _update_pose() -> void:
	if model == null:
		return
	var t := _model_base
	if _state == "attack" and _action.get("flip", false) and not _action.get("hit_done", false):
		var k := clampf(_state_time / 0.72, 0.0, 1.0)
		var angle := TAU * (k * k * (3.0 - 2.0 * k))  # tour complet, lissé
		var c := Vector3(0.0, 0.9 * GameData.HERO_SCALE, 0.0)
		t = Transform3D(Basis(Vector3.RIGHT, angle), c - Basis(Vector3.RIGHT, angle) * c) * _model_base
	elif _state == "attack" and int(_action.get("spin_turns", 0)) > 0:
		var k := clampf(_state_time / maxf(_state_len * 0.85, 0.1), 0.0, 1.0)
		t = Transform3D(Basis(Vector3.UP, -TAU * float(_action.spin_turns) * k), Vector3.ZERO) * _model_base
	model.transform = t


## Déplacement instantané d'un coup (fond en avant, repli du mage, sortie de fumigène).
func _quick_move(dir: Vector3, dist: float) -> void:
	_afterimage()
	var mask := collision_mask
	collision_mask = GameData.PHYS_WORLD
	move_and_collide(Vector3(dir.x, 0.0, dir.z).normalized() * dist)
	collision_mask = mask


## Direction de repli : la direction de déplacement, sinon à l'opposé du monstre le plus proche.
func _evade_dir() -> Vector3:
	var input := _read_move_input()
	if input.length() > 0.1:
		return input.normalized()
	var n := nearest_monster(15.0)
	if n:
		var away := global_position - n.global_position
		away.y = 0.0
		if away.length() > 0.1:
			return away.normalized()
	return -forward()


## Projectiles tombant du ciel sur une zone (pluie de flèches, marteau sacré).
func _sky_drop(at: Vector3, radius: float, kind: String) -> void:
	var n := 9 if kind == "rain" else 1
	for i in n:
		var mi := MeshInstance3D.new()
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.emission_enabled = true
		if kind == "rain":
			var bx := BoxMesh.new()
			bx.size = Vector3(0.07, 1.2, 0.07)
			mi.mesh = bx
			mat.albedo_color = Color(1.0, 0.92, 0.7)
			mat.emission = Color(1.0, 0.85, 0.5)
		else:
			var hm := CylinderMesh.new()
			hm.top_radius = radius * 0.35
			hm.bottom_radius = radius * 0.35
			hm.height = radius * 0.5
			mi.mesh = hm
			mat.albedo_color = Color(1.0, 0.95, 0.65)
			mat.emission = Color(1.0, 0.9, 0.5)
			mat.emission_energy_multiplier = 2.0
		mi.material_override = mat
		get_tree().current_scene.add_child(mi)
		var off := Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).limit_length(1.0) * radius * (0.85 if n > 1 else 0.0)
		var ground := at + off
		mi.global_position = ground + Vector3.UP * 9.0
		var tw := mi.create_tween()
		tw.tween_interval(0.03 * i)
		tw.tween_property(mi, "global_position", ground, 0.16).set_ease(Tween.EASE_IN)
		tw.tween_callback(mi.queue_free)
	if kind == "hammer":
		_shake(0.6)


## Invisibilité : les monstres perdent le héros de vue ; frapper la rompt.
func _break_stealth() -> void:
	if statuses.has("invisible"):
		statuses.erase("invisible")
		statuses_changed.emit()


func _update_stealth_visual() -> void:
	if model == null:
		return
	var t := 0.5 if has_status("invisible") else 0.0
	for n in model.find_children("*", "GeometryInstance3D", true, false):
		(n as GeometryInstance3D).transparency = t


## Impact d'un projectile du héros.
func bolt_hit(m: Combatant, dir: Vector3, action: Dictionary) -> void:
	var is_skill: bool = action.get("is_skill", false)
	_hit_monster(m, dir, action, is_skill)
	_last_combat = _time
	if is_skill and not action.get("proc_done", false):
		action["proc_done"] = true
		Procs.fire(self, "skill_hit", m, m.global_position)


func _heal_action(action: Dictionary) -> void:
	if action.get("cleanse", false):
		# purification : retire les malus du héros
		for st in statuses.keys():
			if not StatusDb.is_buff(st):
				statuses.erase(st)
		statuses_changed.emit()
	var amount := max_hp * float(action.get("heal", 0.0)) * heal_power
	if amount <= 0.0:
		return
	heal(amount)
	DamageNumber.spawn_text(self, "+%d" % roundi(amount), Color(0.5, 1.0, 0.55))
	Vfx.ring(self, global_position, 2.4, Color(0.5, 1.0, 0.6, 0.9))


## Téléportation vers [param aim] (au plus [param dist] m), sans traverser les murs.
func _blink(aim: Vector3, dist: float) -> void:
	var to := aim - global_position
	to.y = 0.0
	if to.length() < 0.5:
		to = forward() * dist
	var motion := to.limit_length(dist)
	_afterimage()
	var mask := collision_mask
	collision_mask = GameData.PHYS_WORLD
	move_and_collide(motion)
	collision_mask = mask
	Vfx.ring(self, global_position, 2.0, Color(0.7, 0.6, 1.0, 0.9))


## Écho : la dernière compétence frappe une seconde fois, au même endroit.
func echo_last_skill(mult: float) -> void:
	if _last_skill.is_empty():
		return
	var a: Dictionary = _last_skill.action.duplicate(true)
	a.mult = float(a.mult) * mult
	a["echo"] = true
	a.erase("fx_count")
	var origin: Vector3 = _last_skill.pos
	var fwd: Vector3 = _last_skill.fwd
	await get_tree().create_timer(0.22, false).timeout
	if is_dead or not is_inside_tree():
		return
	DamageNumber.spawn_text(self, "ÉCHO", Color(0.8, 0.6, 1.0))
	_resolve_area(a, origin, fwd, true)


## Dégâts d'un effet déclenché (foudre, explosion...) : ne relance pas les procs
## d'impact, mais une mort peut déclencher les procs « kill ».
func proc_hit(m: Combatant, mult: float, can_crit := false) -> void:
	if m == null or not is_instance_valid(m) or m.is_dead:
		return
	var is_crit := can_crit and randf() < crit
	var dmg := maxf(atk, matk) * mult * damage_dealt_mult() * dmg_mult * (1.0 + crit_dmg if is_crit else 1.0)
	var mon := m as Monster
	if mon and (mon.is_elite or mon.is_boss):
		dmg *= elite_mult
	m.take_damage(dmg, self, is_crit)
	_last_combat = _time
	if m.is_dead:
		Procs.fire(self, "kill", m, m.global_position)


## Recharges des compétences réduites de [param seconds] s.
func reduce_cooldowns(seconds: float) -> void:
	for id in skill_ready_at:
		skill_ready_at[id] = maxf(_time, float(skill_ready_at[id]) - seconds)


## Coup porté à [param m] : un monstre, ou un héros (héros ennemi, ou le joueur pour lui).
func _hit_monster(m: Combatant, dir: Vector3, action: Dictionary, is_skill: bool) -> void:
	var mon := m as Monster
	var mult: float = action.get("mult", 1.0)
	var combo: Dictionary = action.get("combo", {})
	var combo_ok: bool = not combo.is_empty() and m.has_status(String(combo.get("requires", "")))
	if combo_ok and combo.get("double", false):
		mult *= 2.0
	var magic: bool = action.get("dmg_type", "phys") == "mag"
	var is_crit := randf() < (mcrit if magic else crit) + float(action.get("crit_bonus", 0.0))
	var dmg := (matk if magic else atk) * mult * randf_range(0.92, 1.08) * damage_dealt_mult() * (1.0 + crit_dmg if is_crit else 1.0) * flow_mult() * dmg_mult
	if mon and (mon.is_elite or mon.is_boss):
		dmg *= elite_mult
	elif execute > 0.0 and m.hp - dmg <= m.max_hp * execute:
		# exécution : coup fatal qui ignore la défense
		DamageNumber.spawn_text(m, "EXÉCUTÉ", Color(1.0, 0.3, 0.3))
		dmg = m.hp + 1.0
		m.take_damage(dmg, self, is_crit, true)
	if not m.is_dead:
		# mission du Magicien : plus gros coup (après la défense de la cible)
		if not foe:
			Profile.record_max("best_hit", round(dmg * m.damage_taken_mult() * 100.0 / (100.0 + maxf(m.defense, 0.0))))
		m.take_damage(dmg, self, is_crit)
	# effet d'impact d'Eden (limité à quelques cibles par coup pour la lisibilité)
	var fx_hits := int(action.get("fx_count", 0))
	if fx_hits < 3:
		action["fx_count"] = fx_hits + 1
		var hit_fx: String = action.get("hit_fx", "")
		EdenFx.play(self, hit_fx, m.global_position + Vector3.UP * 0.2, rotation.y, GameData.HERO_SCALE)
	if lifesteal > 0.0:
		heal(dmg * lifesteal)
	Vfx.spark(self, m.global_position + Vector3.UP * 1.0, Color(1.0, 0.85, 0.5), is_crit)
	if is_skill or is_crit or action.get("finisher", false):
		Vfx.flash(self, m.global_position + Vector3.UP * 1.0, 1.6 if is_crit else 1.2, Color(1.0, 0.85, 0.55))
	var pull := float(action.get("pull", 0.0))
	if pull > 0.0:
		# attraction vers le héros (grappin) ou le centre de la zone (vortex)
		m.knockback(-dir * sqrt(28.0 * pull))
	else:
		m.knockback(dir * (2.5 if is_skill else (3.0 if action.get("finisher", false) else 1.0)))
	for s in action.get("applies", {}):
		m.add_status(s, float(action.applies[s]), self)
	if combo_ok:
		for s in combo.get("applies", {}):
			m.add_status(s, float(combo.applies[s]), self)
		for b in combo.get("buff", {}):
			add_status(b, float(combo.buff[b]), self)
			recalc_stats()
	if not is_skill and has_status("hunter_stance") and randf() < 0.2:
		m.add_status("shock", 5.0, self)
	Procs.fire(self, "hit", m, m.global_position)
	if is_crit:
		Procs.fire(self, "crit", m, m.global_position)
	if m.is_dead:
		Procs.fire(self, "kill", m, m.global_position)


## Micro-arrêt sur impact : donne du poids aux coups.
func _hit_pause(duration: float) -> void:
	if not Settings.get_v("interface", "hit_stop"):
		return
	Engine.time_scale = 0.15
	await get_tree().create_timer(duration, true, false, true).timeout
	Engine.time_scale = 1.0


# --- compétences --------------------------------------------------------------------
func skill_in_slot(slot: int) -> Dictionary:
	if slot >= kit().size():
		return {}
	return kit_skill_def(int(kit()[slot].id))


func skill_cooldown(s: Dictionary) -> float:
	if Training.active and Training.no_cd:
		return 0.1  # entraînement : recharges à zéro
	return float(s.cooldown) * (1.0 if foe else Run.skill_cooldown_mult(int(s.id))) * (1.0 - cdr)


func cooldown_left(slot: int) -> float:
	var s := skill_in_slot(slot)
	if s.is_empty():
		return 0.0
	return maxf(0.0, float(skill_ready_at.get(int(s.id), 0.0)) - _time)


## Lance la compétence de l'emplacement [param slot], vers [param forced_aim] si donné,
## sinon selon la visée choisie (Paramètres > Contrôles).
func use_skill(slot: int, forced_aim := Vector3.INF) -> void:
	var s := skill_in_slot(slot)
	if s.is_empty() or cooldown_left(slot) > 0.0:
		return
	skill_ready_at[int(s.id)] = _time + skill_cooldown(s)
	_cast_skill(s, slot, 0, forced_aim)
	_chain_open(slot, 0)


## Enchaînements en cours, un par case (indépendants : on peut ouvrir la chaîne de la case 1,
## puis celle de la case 3, et les réussir dans l'ordre voulu) : case -> {next, t0 (appui)}.
## Après l'appui : 0,45 s de blocage (l'icône du sort suivant est en recharge), puis une
## barre de 3 s se remplit au-dessus de la case ; rappuyer dans la zone de la barre
## lance le sort suivant. Trop tôt (blocage compris), trop tard ou barre écoulée : la chaîne
## est cassée et la case reprend la recharge du premier sort.
## Chaque sort enchaîné a sa propre recharge : tant qu'elle court, la case reste bloquée (appuyer
## affiche « En recharge » sans casser la chaîne) ; s'il ne peut pas être prêt avant la fin de
## la barre, la chaîne n'est pas proposée.
var _chain := {}


func _chain_open(slot: int, next: int) -> void:
	if next < kit_chain(slot).size():
		_chain[slot] = {"next": next, "t0": _time}
	else:
		_chain.erase(slot)


## État de l'enchaînement de la case : {next, phase ("lock" ou "bar"), left, total, recharge, p}
## ou {} ; recharge : le blocage vient de la recharge du sort suivant (total : sa recharge).
func chain_state(slot: int) -> Dictionary:
	if not _chain.has(slot):
		return {}
	var c: Dictionary = _chain[slot]
	var ch := kit_chain(slot)
	if int(c.next) >= ch.size():
		_chain.erase(slot)
		return {}
	var e := _time - float(c.t0)
	if e >= CHAIN_DELAY + CHAIN_BAR:
		_chain.erase(slot)  # barre écoulée : chaîne perdue
		return {}
	var d := kit_skill_def(int(ch[int(c.next)].id))
	var cd := maxf(0.0, float(skill_ready_at.get(int(d.get("id", 0)), 0.0)) - _time)
	if cd >= CHAIN_DELAY + CHAIN_BAR - e:
		_chain.erase(slot)  # le sort suivant ne sera pas rechargé avant la fin de la barre
		return {}
	if e < CHAIN_DELAY or cd > 0.0:
		var by_cd := cd > CHAIN_DELAY - e
		return {"next": d, "phase": "lock", "left": maxf(CHAIN_DELAY - e, cd), "recharge": by_cd,
			"total": skill_cooldown(d) if by_cd else CHAIN_DELAY, "p": 0.0}
	return {"next": d, "phase": "bar", "left": 0.0, "p": (e - CHAIN_DELAY) / CHAIN_BAR}


func chain_next(slot: int) -> Dictionary:
	return chain_state(slot).get("next", {})


## La barre est-elle dans la zone du bon timing ?
func chain_ready(slot: int) -> bool:
	var st := chain_state(slot)
	return not st.is_empty() and st.phase == "bar" and float(st.p) >= CHAIN_ZONE.x and float(st.p) <= CHAIN_ZONE.y


## Appui sur la touche d'une case en enchaînement : 0 pas d'enchaînement, 1 raté (chaîne
## cassée), 2 sort suivant lancé.
func _chain_press(slot: int) -> int:
	var st := chain_state(slot)
	if st.is_empty() or _time <= float(_chain[slot].t0):
		return 0  # l'appui qui vient d'ouvrir la chaîne ne compte pas une 2e fois
	if st.get("recharge", false):
		DamageNumber.spawn_text(self, "En recharge", Color(0.7, 0.8, 1.0))
		return 1  # appui pris, la chaîne attend la fin de la recharge
	if not chain_ready(slot):
		var early: bool = st.phase == "lock" or float(st.p) < CHAIN_ZONE.x
		_chain.erase(slot)
		DamageNumber.spawn_text(self, "Trop tôt" if early else "Trop tard", Color(1.0, 0.6, 0.45))
		return 1
	var step := int(_chain[slot].next) + 1
	var nxt: Dictionary = st.next
	ml_counts.chain += 1
	DamageNumber.spawn_text(self, "ENCHAÎNEMENT ×%d" % (step + 1), Color(0.6, 0.9, 1.0))
	if autoplay:
		print("[enchainement] case %d, sort %d : %s" % [slot + 1, step + 1, nxt.get("name", "?")])
	_shake(0.35)
	skill_ready_at[int(nxt.id)] = _time + skill_cooldown(nxt)
	_cast_skill(nxt, slot, step)
	_chain_open(slot, step)
	return 2


## Touche d'une case en enchaînement (pilote automatique : au milieu de la zone).
func _chain_input() -> int:
	for cs in _chain.keys():
		var st := chain_state(int(cs))
		if st.is_empty():
			continue
		var auto: bool = autoplay and not autoplay_idle and st.phase == "bar" and float(st.p) >= 0.35
		if _auto_combo() and st.phase == "bar" and _monster_in_reach(skill_reach(st.next) + 1.0, false) != null:
			auto = true  # combos parfaits : le sort suivant part dès l'ouverture de la barre
		if (not autoplay and _wants("skill_%d" % (int(cs) + 1))) or auto:
			return _chain_press(int(cs))
	return 0


func _cast_skill(s: Dictionary, slot: int, step: int, forced_aim := Vector3.INF) -> void:
	_break_stealth()
	var aim := forced_aim if forced_aim != Vector3.INF else _skill_aim()
	if aim == Vector3.INF:
		aim = global_position + forward()
	face_direction(aim - global_position, 1.0, 100.0)
	var action := {
		"kind": s.kind, "mult": float(s.mult) * (1.0 if foe else Run.skill_damage_mult(int(s.id))),
		"radius": skill_radius(s), "arc": float(s.arc), "hits": int(s.get("hits", 1)),
		"dash": float(s.get("dash", 0.0)) * reach_mult, "applies": s.get("applies", {}), "combo": s.get("combo", {}),
		"skill_id": int(s.id), "aerial": not is_on_floor(),
		"range": float(s.get("range", 0.0)) * reach_mult, "pierce": int(s.get("pierce", 0)),
		"projectile": String(s.get("projectile", "magic")), "volley": int(s.get("volley", 1)),
		"spread": float(s.get("spread", 0.0)), "heal": float(s.get("heal", 0.0)) * (1.0 if foe else Run.skill_heal_mult(int(s.id))),
		"crit_bonus": float(s.get("crit_bonus", 0.0)), "cleanse": s.get("cleanse", false),
		"dmg_type": String(s.get("dmg_type", cls.get("dmg_type", "phys"))),
		"slot": slot, "chain_step": step,
	}
	if step > 0:
		action.mult *= 1.0 + CHAIN_BONUS
	if s.kind == "ground":
		# zone au sol à l'endroit visé, dans la limite de la portée
		var to_aim := aim - global_position
		to_aim.y = 0.0
		action["target"] = global_position + to_aim.limit_length(float(action.range))
		Vfx.ring(self, action.target, float(action.radius), Color(0.6, 0.85, 1.0, 0.6))
	elif s.kind == "blink":
		_blink(aim, float(action.range))
	if action.aerial:
		action.mult *= 1.0 + AIR_SKILL_BONUS
		_carry = Vector3.ZERO
	if _state == "dodge":
		_end_dodge()
	var tal := {"dmg": 0.0, "cd": 0.0, "duration": 0.0, "power": 0.0} if foe else Run.skill_talent(int(s.id))
	var dur_k := (1.0 + float(tal.power)) * (1.0 if foe else Run.skill_duration_mult(int(s.id)))
	for b in s.get("buff", {}):
		add_status(b, float(s.buff[b]) * dur_k + float(tal.duration), self)
	# bonus d'attribut au lancement (cartes d'amélioration rares et mieux)
	for r in ([] if foe else Run.skill_riders(int(s.id))):
		var st := String(Cards.RIDER_STATUS.get(String(r.stat), "spell_str"))
		timed_stats[st] = {String(r.stat) + "_pct": float(r.value)}
		add_status(st, float(r.duration), self)
	if float(tal.duration) > 0.0 or dur_k != 1.0:
		var ap: Dictionary = (s.get("applies", {}) as Dictionary).duplicate()
		for st in ap:
			ap[st] = float(ap[st]) * dur_k + float(tal.duration)
		action["applies"] = ap
	if s.kind == "buff" or s.kind == "spin":
		Vfx.ring(self, global_position, maxf(skill_radius(s), 2.5), Color(1.0, 0.8, 0.35, 0.8))
	recalc_stats()
	var fx: Dictionary = s.get("fx", {})
	action["hit_fx"] = String(fx.get("hit", "")) if String(fx.get("hit", "")) != "" else "s00341"
	EdenFx.play(self, String(fx.get("cast", "")), global_position, rotation.y, GameData.HERO_SCALE, self)
	_begin_action("skill", String(s.anim), 1.15 * (cast_speed if action.dmg_type == "mag" else atk_speed), action)
	_skill_lock_until = _time + _state_len * 0.92 + SKILL_RECOVERY


func _skill_aim() -> Vector3:
	if bot:
		return bot.aim
	var cursor := mouse_ground_point() if not autoplay else Vector3.INF
	var mode := "smart" if autoplay else Settings.aim_mode()
	if mode in ["cursor", "action"]:
		if cursor == Vector3.INF and mode == "action":
			return global_position + _cursor_dir() * 8.0
		return cursor
	if mode == "nearest":
		var near := nearest_monster(14.0)
		return near.global_position if near else cursor
	# intelligente : cible verrouillée, sinon curseur proche, sinon monstre le plus proche
	if _target and is_instance_valid(_target):
		return _target.global_position
	if cursor == Vector3.INF or cursor.distance_to(global_position) > 14.0:
		var n := nearest_monster(10.0)
		return n.global_position if n else Vector3.INF
	return cursor


# --- déplacements spéciaux ----------------------------------------------------------
# --- saut (mécanique de build : sauts en l'air, hauteur, piqué) ------------------------
var _jumps_used := 0
var _stun_len := 0.0
var _stun_fx: Label3D


## Sauts disponibles : 1 au sol + les sauts aériens des cartes « Saut aérien ».
func max_jumps() -> int:
	return 1 + int(_passives().get("air_jump", 0))


var _air_dashes := 0
var _last_floor_time := 0.0
var _jump_buffer_until := 0.0
var _carry := Vector3.ZERO  # élan conservé (saut depuis une esquive)


func can_jump() -> bool:
	var grounded := is_on_floor() or _time - _last_floor_time < COYOTE_TIME
	return _jumps_used < max_jumps() and (grounded or _jumps_used > 0 or max_jumps() > 1)


## Esquives aériennes disponibles avant de retoucher le sol.
func max_air_dashes() -> int:
	return 1 + int(_passives().get("air_dash", 0))


## Gravité du héros : plus forte en chute qu'en montée (saut sec) ; relâcher
## le saut tôt coupe la montée (petit saut) ; « Apesanteur » allège le tout.
func _apply_hero_gravity(delta: float) -> void:
	if is_on_floor():
		velocity.y = -0.5
		return
	if _state == "dodge":
		velocity.y = 0.0  # l'esquive aérienne file à l'horizontale
		return
	if _state in ["skill", "attack"] and _action.get("aerial", false):
		# suspension pendant une compétence aérienne, légère descente
		velocity.y = move_toward(velocity.y, -1.2, 60.0 * delta)
		return
	var g := GRAVITY_UP if velocity.y > 0.0 else GRAVITY_DOWN
	g *= 1.0 - 0.25 * int(_passives().get("featherfall", 0))
	if velocity.y > 0.0 and _state == "jump" and not autoplay and bot == null and not Input.is_action_pressed("jump"):
		g *= 2.2
	velocity.y -= g * delta


func is_airborne() -> bool:
	return not is_on_floor()


func _start_jump() -> void:
	var first := is_on_floor() or (_jumps_used == 0 and _time - _last_floor_time < COYOTE_TIME)
	if _state == "dodge":
		# saut depuis une esquive : on garde l'élan (saut-esquive très long)
		_carry = Vector3(velocity.x, 0, velocity.z) * 0.75
		_end_dodge()
	_jump_buffer_until = 0.0
	_jumps_used = 1 if first else _jumps_used + 1
	_state = "jump"
	_state_time = 0.0
	var height_bonus := 1.0 + 0.2 * int(_passives().get("high_jump", 0))
	velocity.y = JUMP_VELOCITY * height_bonus * (1.0 if first else 0.9)
	play(_anim("jump") if first else _anim("dodge"), 0.05, 1.8, true)
	if not first:
		Vfx.ring(self, global_position, 1.6, Color(0.7, 0.9, 1.0, 0.7))


func _update_jump(input_dir: Vector3, delta: float) -> void:
	_carry = _carry.move_toward(Vector3.ZERO, 18.0 * delta)
	velocity.x = input_dir.x * _speed() + _carry.x
	velocity.z = input_dir.z * _speed() + _carry.z
	if input_dir.length() > 0.1:
		face_direction(input_dir, delta)
	if _wants_pressed("jump"):
		if _jumps_used < max_jumps():
			_start_jump()
			return
		_jump_buffer_until = _time + JUMP_BUFFER
	# esquive aérienne : une par saut, sans délai
	if _wants_pressed("dodge") and _air_dashes < max_air_dashes():
		_air_dashes += 1
		_start_dodge(input_dir)
		return
	# compétences en l'air
	for i in 4:
		if _wants("skill_%d" % (i + 1)) and cooldown_left(i) <= 0.0:
			use_skill(i)
			return
	# piqué : attaque en l'air si la carte « Frappe plongeante » est prise
	if _wants_pressed("attack") and Settings.attack_button_attacks() and int(_passives().get("dive_strike", 0)) > 0 and _state_time > 0.1:
		_state = "dive"
		_state_time = 0.0
		velocity.y = -26.0
		play(_anim("dodge"), 0.05, 1.6, true)
		return
	if _state_time > 0.1 and is_on_floor():
		_carry = Vector3.ZERO
		_state = "idle"


func _update_dive() -> void:
	velocity.x = move_toward(velocity.x, 0.0, 2.0)
	velocity.z = move_toward(velocity.z, 0.0, 2.0)
	velocity.y = minf(velocity.y, -20.0)
	if _state_time > 1.2:
		_state = "idle"


## Atterrissage du piqué : onde de choc qui étourdit brièvement.
func _dive_impact() -> void:
	_state = "idle"
	var r := 3.8 + 0.6 * int(_passives().get("dive_strike", 0))
	Vfx.ring(self, global_position, r, Color(1.0, 0.85, 0.4, 0.9))
	EdenFx.play(self, "s00541", global_position, rotation.y, GameData.HERO_SCALE * 1.4)
	_shake(0.9)
	_action = {"mult": 1.5 + 0.3 * int(_passives().get("dive_strike", 0)), "radius": r, "arc": 360.0,
		"applies": {"stun": 0.6}, "hit_fx": "s00341"}
	_resolve_hit()


## Étourdissement (zones rouges du boss) : plus aucune action pendant [param t] s ; ensuite
## le héros y est insensible un moment, comme les monstres (Combatant.CC_TYPES).
func stun(t: float) -> void:
	if is_dead or _state == "stun" or not _cc_gate("stun", t):
		return
	statuses_changed.emit()
	_state = "stun"
	_state_time = 0.0
	_stun_len = t
	_target = null
	_trail_on = false
	play(_anim("hurt"), 0.05, 0.6, true)
	if _stun_fx == null:
		_stun_fx = Label3D.new()
		_stun_fx.text = "★ ÉTOURDI ★"
		_stun_fx.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_stun_fx.no_depth_test = true
		_stun_fx.fixed_size = true
		_stun_fx.pixel_size = 0.0011
		_stun_fx.font_size = 34
		_stun_fx.outline_size = 10
		_stun_fx.modulate = Color(1.0, 0.9, 0.3)
		_stun_fx.position.y = 3.2
		add_child(_stun_fx)
	_stun_fx.visible = true


func _shake(amount: float) -> void:
	if foe:
		return
	var rig := get_viewport().get_camera_3d().get_parent() as CameraRig if get_viewport().get_camera_3d() else null
	if rig:
		rig.shake(amount)


func _wants_pressed(action: String) -> bool:
	if bot:
		return bot.wants(action)
	if foe:
		return false
	if autoplay:
		return false
	return Input.is_action_just_pressed(action)


func _start_dodge(input_dir: Vector3, perfect := false) -> void:
	Procs.fire(self, "dodge")
	_skill_lock_until = 0.0  # l'esquive efface la récupération du sort
	_dodge_dir = input_dir.normalized() if input_dir.length() > 0.1 else forward()
	face_direction(_dodge_dir, 1.0, 100.0)
	_state = "dodge"
	_state_time = 0.0
	_dodge_mult = 1.35 if perfect else 1.0
	if is_on_floor() and not perfect:
		_dodge_ready_at = _time + DODGE_COOLDOWN
	collision_mask = GameData.PHYS_WORLD
	play(_anim("dodge"), 0.05, 1.8, true)


func _update_dodge() -> void:
	var v := _dodge_dir * (DODGE_DISTANCE * _dodge_mult / DODGE_TIME)
	velocity.x = v.x
	velocity.z = v.z
	# saut sans délai pendant l'esquive (garde l'élan)
	if _wants_pressed("jump") and can_jump():
		_start_jump()
		return
	# enchaînement pendant l'esquive (sort, esquive, sort suivant)
	if _chain_input() == 2:
		return
	# combos parfaits : le sort suivant part pendant le pas de l'annulation
	if _auto_combo() and _state_time >= DODGE_TIME * 0.3 and _try_auto_skill():
		return
	# compétence dès la seconde moitié de l'esquive (esquive -> sort)
	if _state_time >= DODGE_TIME * 0.45:
		for i in 4:
			if _wants("skill_%d" % (i + 1)) and cooldown_left(i) <= 0.0:
				use_skill(i)
				return
	if _state_time >= DODGE_TIME:
		_end_dodge()
		if is_on_floor():
			_state = "idle"
		else:
			# fin d'esquive aérienne : on retombe en gardant un peu d'élan
			_carry = Vector3(v.x, 0, v.z) * 0.35
			_state = "jump"
			_state_time = 0.3


func _end_dodge() -> void:
	collision_mask = _body_mask()


# --- annulation parfaite et fluidité ---------------------------------------------------
var _last_hit_at := -10.0
var _dodge_mult := 1.0
var flow_stacks := 0
var _flow_until := 0.0


func flow_mult() -> float:
	if _time > _flow_until:
		flow_stacks = 0
	return 1.0 + 0.1 * flow_stacks


func _perfect_cancel() -> void:
	flow_mult()
	ml_counts.perfect += 1
	flow_stacks = mini(flow_stacks + 1, 4)
	_flow_until = _time + 3.0
	var sid := int(_action.get("skill_id", 0))
	if skill_ready_at.has(sid):
		skill_ready_at[sid] = _time + maxf(0.0, float(skill_ready_at[sid]) - _time) * 0.75
	DamageNumber.spawn_text(self, "PARFAIT !  Fluidité ×%d" % flow_stacks, Color(0.55, 0.95, 1.0))
	Vfx.ring(self, global_position, 2.2, Color(0.5, 0.9, 1.0, 0.9))
	EdenFx.play(self, "s00141", global_position + Vector3.UP * 0.8, rotation.y, GameData.HERO_SCALE)
	_shake(0.35)
	for i in 4:
		get_tree().create_timer(0.05 * i, false).timeout.connect(_afterimage)
	_hit_pause(0.05)
	Procs.fire(self, "perfect")


## Image rémanente : copie figée et translucide de la pose actuelle du héros.
func _afterimage() -> void:
	if model == null or not is_inside_tree():
		return
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.disable_fog = true  # la brume ne s'ajoute pas aux effets lumineux (carrés pâles)
	mat.albedo_color = Color(0.35, 0.75, 1.0, 0.55)
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var ghost := Node3D.new()
	get_tree().current_scene.add_child(ghost)
	for n in model.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if not mi.is_visible_in_tree() or mi.mesh == null:
			continue
		var copy := MeshInstance3D.new()
		var sref := mi.get_skin_reference() if mi.skin else null
		copy.mesh = mi.bake_mesh_from_current_skeleton_pose() if sref and sref.get_skeleton().is_valid() and mi.get_node_or_null(mi.skeleton) is Skeleton3D else mi.mesh
		copy.material_override = mat
		copy.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		ghost.add_child(copy)
		copy.global_transform = mi.global_transform
	var tw := ghost.create_tween()
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.35)
	tw.tween_callback(ghost.queue_free)


func is_invulnerable() -> bool:
	return _state == "dodge" or dev_invincible


func take_damage(amount: float, source: Combatant = null, is_crit := false, dot := false) -> void:
	if is_invulnerable():
		if not dot:
			ml_counts.dodged += 1
		if not dot and Run.active and not dev_invincible and not foe:
			Profile.record_add("dodges", 1)  # mission du Voleur
		return
	if not dot and ((has_status("evasion") and randf() < EVASION_CHANCE) or randf() < evasion_chance):
		DamageNumber.spawn_text(self, "ESQUIVE !", Color(0.7, 1.0, 0.7))
		if Run.active and not foe:
			Profile.record_add("dodges", 1)
		return
	if not dot and randf() < parry_chance:
		DamageNumber.spawn_text(self, "PARADE", Color(0.85, 0.85, 1.0))
		amount *= 0.5
	# ange gardien (Résurrection du clerc) : un coup fatal est annulé
	if has_status("angel") and hp - amount * damage_taken_mult() <= 0.0:
		statuses.erase("angel")
		statuses_changed.emit()
		hp = max_hp * 0.3
		health_changed.emit(hp, max_hp)
		DamageNumber.spawn_text(self, "RÉSURRECTION !", Color(1.0, 0.95, 0.6))
		Vfx.shockwave(self, global_position, 4.0, Color(1.0, 0.95, 0.7))
		return
	_last_combat = _time
	super.take_damage(amount, source, is_crit, dot)
	# Épines (sorts d'Eden « renvoie les dégâts ») : 30 % du coup reçu renvoyé à l'attaquant
	if not dot and has_status("thorns") and source and is_instance_valid(source) and not source.is_dead:
		source.take_damage(amount * 0.3 * dmg_mult, self, false, true)
	if not dot:
		_shake(clampf(amount / max_hp * 8.0, 0.3, 1.4))
	if not is_dead:
		Procs.fire(self, "hurt", source)
		if hp < max_hp * 0.3:
			Procs.fire(self, "low_hp", source)


## Résolution : insensible aux contrôles des monstres.
func add_status(status: String, duration: float, source: Combatant = null) -> void:
	if status in ["stun", "freeze", "chill", "root", "sleep", "fear", "disarm"] and has_status("resolve"):
		return
	super.add_status(status, duration, source)


func _on_death(_killer: Combatant) -> void:
	_state = "dead"
	_target = null
	_trail_on = false
	play(_anim("death"), 0.1)


func respawn(at: Vector3) -> void:
	is_dead = false
	_move_goal = Vector3.INF
	_state = "idle"
	statuses.clear()
	global_position = at
	velocity = Vector3.ZERO
	hp = max_hp
	health_changed.emit(hp, max_hp)
	play(_anim("idle"), 0.2)


## Lumière qui suit le héros dans les grottes.
func set_torch(on: bool) -> void:
	if on and _torch == null:
		_torch = OmniLight3D.new()
		_torch.light_color = Color(1.0, 0.85, 0.65)
		_torch.light_energy = 2.2
		_torch.omni_range = 16.0
		_torch.position = Vector3(0, 3.0, 0)
		add_child(_torch)
	if _torch:
		_torch.visible = on


# --- collisions et blocages ---------------------------------------------------------
## Capsule plus fine que la silhouette : on se faufile entre les obstacles.
func _slim_collision() -> void:
	for c in get_children():
		if c is CollisionShape3D and c.shape is CapsuleShape3D:
			var cap := c.shape as CapsuleShape3D
			cap.radius = HERO_RADIUS
			cap.height = 1.6
			c.position.y = 0.8
	radius = HERO_RADIUS


## Marches, bords et coincements : ce qui rend un hack and slash frustrant.
func _handle_obstacles(input_dir: Vector3, before: Vector3, delta: float) -> void:
	if is_on_floor():
		_safe_timer -= delta
		if _safe_timer <= 0.0:
			_safe_timer = 0.5
			_safe_positions.append(global_position)
			if _safe_positions.size() > 12:
				_safe_positions.pop_front()
	var wants_move := input_dir.length() > 0.1 and _state in ["idle", "jump"]
	if not wants_move:
		_stuck_time = 0.0
		return
	var motion := Vector3(input_dir.x, 0, input_dir.z) * _speed() * delta
	if is_on_wall() and is_on_floor():
		var up := global_transform.translated(Vector3.UP * STEP_HEIGHT)
		if not test_move(global_transform, Vector3.UP * STEP_HEIGHT) and not test_move(up, motion * 2.0):
			global_position += Vector3.UP * STEP_HEIGHT + motion
	var moved := Vector2(global_position.x - before.x, global_position.z - before.z).length()
	if moved < motion.length() * 0.15:
		_stuck_time += delta
	else:
		_stuck_time = maxf(0.0, _stuck_time - delta * 2.0)
	if _stuck_time > 1.2 and _move_goal != Vector3.INF:
		_move_goal = Vector3.INF  # clic de déplacement vers un obstacle : on abandonne
		_click_moving = false
	if _stuck_time > 0.8 and is_on_floor() and _state == "idle":
		_start_jump()
	if _stuck_time > 2.0:
		unstuck()


## Ramène le héros à une position libre récente (touche F4 ou automatique).
func unstuck() -> void:
	_stuck_time = 0.0
	var target := global_position + Vector3.UP * 1.5
	for i in range(_safe_positions.size() - 1, -1, -1):
		if _safe_positions[i].distance_to(global_position) > 1.5:
			target = _safe_positions[i] + Vector3.UP * 0.3
			break
	global_position = target
	velocity = Vector3.ZERO


# --- visée ---------------------------------------------------------------------------
func mouse_ground_point() -> Vector3:
	if _pad():
		return _pad_aim_point()
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return Vector3.INF
	var mp := get_viewport().get_mouse_position()
	var from := cam.project_ray_origin(mp)
	var dir := cam.project_ray_normal(mp)
	if absf(dir.y) < 0.0001:
		return Vector3.INF
	var t := (global_position.y - from.y) / dir.y
	return from + dir * t if t > 0.0 else Vector3.INF


## Point du décor sous le curseur (sol en relief), sinon plan à hauteur du héros.
func mouse_world_point() -> Vector3:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return Vector3.INF
	var mp := get_viewport().get_mouse_position()
	var from := cam.project_ray_origin(mp)
	var q := PhysicsRayQueryParameters3D.create(from, from + cam.project_ray_normal(mp) * 200.0, GameData.PHYS_WORLD)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	return hit.position if not hit.is_empty() else mouse_ground_point()


## Point visé par un clic de déplacement (INF si aucun).
func move_goal() -> Vector3:
	return _move_goal


func nearest_monster(max_dist: float) -> Combatant:
	var best: Combatant = null
	var best_d := max_dist
	for node in foes():
		var m := node as Combatant
		if m and not m.is_dead:
			var d := global_position.distance_to(m.global_position)
			if d < best_d:
				best_d = d
				best = m
	return best


## Recharge restante de l'esquive au sol et sa durée totale (HUD).
func dodge_cooldown() -> Vector2:
	return Vector2(maxf(0.0, _dodge_ready_at - _time), DODGE_COOLDOWN)


## Étourdissement restant (s), 0 si le héros n'est pas étourdi (HUD).
func stun_left() -> float:
	return maxf(0.0, _stun_len - _state_time) if _state == "stun" else 0.0


## Paliers de Fluidité actifs et temps restant (HUD).
func flow_state() -> Vector2:
	return Vector2(flow_stacks, _flow_until - _time) if flow_stacks > 0 and _time <= _flow_until else Vector2.ZERO


func current_target() -> Combatant:
	return _target if _target and is_instance_valid(_target) and not _target.is_dead else null


# --- bot de test (captures d'écran automatiques) ------------------------------------
func _autoplay_input() -> Vector2:
	var m := nearest_monster(40.0)
	var to := Vector3.ZERO
	var goal := autoplay_target if autoplay else _auto_objective()
	if goal == Vector3.INF:
		goal = _farm_goal()  # rien d'autre à faire : coffres, lieux, objets à casser
	if goal != Vector3.INF and (m == null or global_position.distance_to(m.global_position) > 4.0):
		to = goal - global_position
		if _time > _bot_check_at:
			if global_position.distance_to(_bot_last_pos) < 1.0:
				_bot_detour = to.normalized().rotated(Vector3.UP, PI / 2 * (1 if randf() < 0.5 else -1))
				_bot_detour_until = _time + 1.5
			_bot_last_pos = global_position
			_bot_check_at = _time + 1.0
		if _time < _bot_detour_until:
			to = _bot_detour
	elif m == null:
		return Vector2.ZERO
	else:
		to = m.global_position - global_position
		# au contact (corps à corps), ou à distance de tir (archer, mage) en déplacement automatique
		var stop := 2.2 + m.radius if autoplay or attack_reach() <= 6.0 else attack_reach() * 0.7
		if to.length() < stop:
			return Vector2.ZERO
		var map := get_tree().get_first_node_in_group("map") as Node3D
		if map and to.length() > 5.0:
			for pt: Vector3 in map.call("path_between", global_position, m.global_position):
				var d := pt - global_position
				d.y = 0.0
				if d.length() > 1.2:
					to = d
					break
	to.y = 0.0
	var cam := get_viewport().get_camera_3d()
	var local := to.rotated(Vector3.UP, -cam.global_rotation.y) if cam else to
	return Vector2(local.x, local.z).normalized()


func _autoplay_wants(action: String) -> bool:
	var m := nearest_monster(40.0)
	if m == null:
		return false
	var close := global_position.distance_to(m.global_position) < 2.6 + m.radius
	if action == "attack":
		return close
	if action.begins_with("skill_"):
		var slot := int(action.trim_prefix("skill_")) - 1
		return close and cooldown_left(slot) <= 0.0 and randf() < 0.1
	return false
