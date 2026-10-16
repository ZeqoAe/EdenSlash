class_name AutochessUnit
extends ClassRival
## L'Échiquier, lot AC-E : une unité du combat réel, SQUELETTE de l'IA (SPEC §4.1 ; rapport conception/autochess/R_AC_E.md).
## Socle : ClassRival (déplacement, esquive, animations) + les corrections mesurées du prototype d'AC2 (tools/ac2_unit.gd,
## R_AC2 §3 : soutien d'équipe, zones des équipiers ignorées, ni repli ni bond réflexe, mêlée au contact, sorts à portée).
## Vérité du combat = la couche d'effets AutochessEffects (PV, mana, boucliers, contrôles, traits, objets, atouts) : chaque
## coup, sort, soin et chute passe par elle (attack / cast / spell_hit / spell_heal), le nœud n'en est que le miroir (sync).
## Le directeur (AutochessDirector) crée l'unité, lui donne son plateau (arena) et ses listes d'ennemis et d'alliés, avance
## la couche et traite les effets rendus (on_effects).
##
## Camps : ffa_id = 2 × plateau + camp (chacun pour soi entre camps : Combatant.ffa_foes, aucun coup allié). Ennemis et
## alliés viennent du directeur (jamais des groupes « ffa » / « monsters » : 4 plateaux tournent en même temps).
## Sorts : à mana pleine (AutochessEffects.can_cast), sort signature de l'unité (data/autochess_units.json « skill_id ») ;
## ★3 : le 2e sort (« second_skill_id ») part juste après, sans mana. Auto-attaque : au rythme de stat("as"), touche à
## l'impact sans annonce au sol (SPEC §3.3 : annonce rouge pour les sorts seulement) ; portée = stat("reach").
##
## POINTS D'EXTENSION pour l'IA fine (lot AC-U, même fichier) : choose_target() (score de cible, focus d'équipe),
## wants_cast() / spell_target() (sorts selon leur type), heal_target(), _update_chase() (rôles : recul des tireurs,
## plongée des assassins, tank qui s'interpose), naive (IA naïve du banc d'essai), RETARGET_EVERY. Ne pas toucher au
## contrat avec le directeur : setup_unit, sync, ac_die, ac_stun, ac_stop, set_shown, ac_stats.

const RETARGET_EVERY := 0.25  # s : décision de cible (SPEC §4.1 : 4 fois par seconde)
const ZONE_WAIT := 1.5  # s : un sort qui ne trouve pas sa cible à portée part quand même sur elle après ce délai
const HEAL_WAIT := AutochessData.AI_HEAL_WAIT  # s : le soigneur attend qu'un allié soit blessé, puis soigne le plus bas
const CHAIN_FACTOR := 0.6  # ★3 : dégâts du 2e sort (sans mana) en part du sort signature
const BAR_SIZE := Vector2(1.25, 0.24)  # m : barres de PV (haut) et de mana (bas) au-dessus de l'unité
const BAR_Y := 2.75
const SIDE_COLORS := [Color(0.35, 0.9, 0.45), Color(0.95, 0.3, 0.28)]  # PV : son camp vert, l'adversaire rouge
const MANA_COLOR := Color(0.35, 0.62, 1.0)
const MONSTER_NAMES := {"sbire": "Sbire", "elite": "Élite"}
const GUARDIAN_NAME := "Gardien"

## IA naïve (banc d'essai d'AC-U, SPEC §4.2) : le squelette l'est déjà presque ; AC-U s'en servira pour couper ses ajouts.
var naive := false
var ac_dir: AutochessDirector
var ac_arena: Dictionary = {}
var ac_fid := -1
var ac_side := 0
var ac_unit: Dictionary = {}  # entrée du plateau (id, stars, cost, items, cell) ; monstre {monster} ; gardien {guardian}
var ac_sig: Dictionary = {}  # sort signature (classes.json)
var ac_chain: Dictionary = {}  # ★3 : 2e sort enchaîné
var ac_shown := true
var ac_stats := {"casts": 0, "chains": 0, "recasts": 0, "autos": 0, "heals": 0, "out": 0, "foreign": 0}
var _ac: Dictionary = {}  # action en cours : {mode: auto / spell / chain, skill, target, heal_to, started}
var _ac_mana_full_at := -1.0
var _ac_recast := false
var _ac_chain_next: Dictionary = {}
var _ac_last_auto := -10.0
var _ac_base_speed := 6.2
var _ac_monster: Dictionary = {}  # monstre d'Eden (modèle) des manches de monstres et du gardien
var _ac_bar: MeshInstance3D
var _ac_name: Label3D
static var _bar_mat: ShaderMaterial


# --- Mise en place (directeur) ----------------------------------------------------------------------------------------
## Unité [param u] du camp [param side] (fid [param fid] du contexte d'effets de [param arena]).
func setup_unit(u: Dictionary, side: int, fid: int, arena: Dictionary, director: AutochessDirector) -> void:
	ac_unit = u
	ac_side = side
	ac_fid = fid
	ac_arena = arena
	ac_dir = director
	var id := String(u.get("id", ""))
	if id == "":
		_ac_monster = AutochessDirector.monster_entry(u, int(arena.get("seed", 0)) + fid)
		setup("warrior", AutochessData.UNIT_LEVEL, AutochessData.UNIT_DIFF)
		cid = ""
		cls = {"anims": {}, "name_fr": unit_label()}
		wtype = {"battle": "battle01"}
		auto_step = {"anim": "attack01", "mult": 1.0, "radius": 2.6, "arc": 120.0, "hit_fx": ""}
		_skills = []
	else:
		setup(id, AutochessData.UNIT_LEVEL, AutochessData.UNIT_DIFF)
		var d := AutochessData.unit(id)
		ac_sig = skill_of(id, int(d.get("skill_id", 0)))
		if int(u.get("stars", 1)) >= AutochessData.MAX_STARS and AutochessData.STAR3_CHAIN:
			ac_chain = skill_of(id, int(d.get("second_skill_id", 0)))
		_skills = [] if ac_sig.is_empty() else [ac_sig]
	_support = []  # soins et renforts : seulement le sort signature, par la couche d'effets
	display_name = unit_label()
	_ac_base_speed = float(cfg.speed)
	# corrections d'AC2 : pas de repli sous 30 % de PV (le bond réflexe est coupé dans take_damage)
	_retreat_ready = INF
	set_ffa(2 * int(arena.get("index", 0)) + side)
	sync()


## Sort [param skill_id] de la classe [param id] ({} s'il n'existe pas).
static func skill_of(id: String, skill_id: int) -> Dictionary:
	for s in GameData.class_data(id).get("skills", []):
		if int(s.get("id", 0)) == skill_id:
			return s
	return {}


## Nom court affiché : la classe, ou Sbire / Élite / Gardien.
func unit_label() -> String:
	if ac_unit.get("guardian", false):
		return GUARDIAN_NAME
	if ac_unit.has("monster"):
		return String(MONSTER_NAMES.get(String(ac_unit.monster), "Sbire"))
	return AutochessData.unit_name(String(ac_unit.get("id", "")))


func stars() -> int:
	return int(ac_unit.get("stars", 1))


func _ready() -> void:
	if _ac_monster.is_empty():
		super._ready()
	else:
		_ready_monster()
	if _status_label:
		_status_label.position.y = BAR_Y + 0.65
	_make_overhead()
	set_shown(ac_shown)


## Monstre d'Eden (manches de monstres, gardien) : le corps du monstre, la logique de ClassRival.
func _ready_monster() -> void:
	team = Team.MONSTER
	collision_layer = GameData.PHYS_MONSTER
	collision_mask = GameData.PHYS_WORLD | GameData.PHYS_PLAYER
	add_to_group("monsters")
	floor_max_angle = deg_to_rad(55.0)
	floor_snap_length = 0.7
	var m := _ac_monster
	var base := "res://assets/monsters/%s/%s" % [m.model, m.model]
	var tex := "res://assets/monsters/textures/%s.png" % String(m.get("texture", ""))
	var s := float(m.get("scale", 1.0)) * GameData.MONSTER_SCALE * (1.7 if ac_unit.get("guardian", false) else 1.15)
	setup_model(base + ".glb", tex if ResourceLoader.exists(tex) else "", s)
	_base_scale = model.scale
	for a in ["attack01", "attack02", "attack03"]:
		if has_anim(a):
			auto_step["anim"] = a
			break
	_status_label = Label3D.new()
	_status_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_status_label.no_depth_test = true
	_status_label.fixed_size = true
	_status_label.pixel_size = 0.0009
	_status_label.font_size = 26
	_status_label.outline_size = 8
	add_child(_status_label)
	statuses_changed.connect(_refresh_status_label)
	_attacks = ["combo"]
	play(_battle_anim())
	_attack_ready_at = 1.0


## Barres de PV et de mana (une seule surface, face caméra) et nom court avec les étoiles.
func _make_overhead() -> void:
	_ac_bar = MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = BAR_SIZE
	_ac_bar.mesh = q
	_ac_bar.material_override = bar_material()
	_ac_bar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ac_bar.position.y = BAR_Y
	_ac_bar.set_instance_shader_parameter("hp_color", SIDE_COLORS[clampi(ac_side, 0, 1)])
	add_child(_ac_bar)
	_ac_name = Label3D.new()
	_ac_name.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_ac_name.no_depth_test = true
	_ac_name.fixed_size = true
	_ac_name.pixel_size = 0.0008
	_ac_name.font_size = 24
	_ac_name.outline_size = 8
	_ac_name.position.y = BAR_Y + 0.32
	var st := "" if not _ac_monster.is_empty() else "★".repeat(clampi(stars(), 1, 3)) + " "
	_ac_name.text = st + unit_label()
	_ac_name.modulate = AutochessBoard.STAR_COLORS[clampi(stars(), 1, 3) - 1] if _ac_monster.is_empty() else Color(0.9, 0.85, 0.8)
	add_child(_ac_name)
	_refresh_bar()


## Matériau commun des barres : une surface face caméra, PV en haut, mana en bas (paramètres par instance).
static func bar_material() -> ShaderMaterial:
	if _bar_mat != null:
		return _bar_mat
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode unshaded, depth_test_disabled, cull_disabled, shadows_disabled;
instance uniform float hp_frac = 1.0;
instance uniform float mana_frac = 0.0;
instance uniform vec4 hp_color : source_color = vec4(0.35, 0.9, 0.45, 1.0);
uniform vec4 mana_color : source_color = vec4(0.35, 0.62, 1.0, 1.0);
void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
}
void fragment() {
	vec2 uv = UV;
	float edge = 0.03;
	vec3 col = vec3(0.03, 0.03, 0.06);
	float a = 0.0;
	if (uv.y < 0.62) {
		a = 0.9;
		vec2 p = vec2(uv.x, uv.y / 0.62);
		if (p.x > edge && p.x < 1.0 - edge && p.y > 0.12 && p.y < 0.88) {
			float f = (p.x - edge) / (1.0 - 2.0 * edge);
			col = f <= hp_frac ? hp_color.rgb : vec3(0.12, 0.1, 0.12);
		}
	} else if (uv.y > 0.7) {
		a = 0.9;
		vec2 p = vec2(uv.x, (uv.y - 0.7) / 0.3);
		if (p.x > edge && p.x < 1.0 - edge && p.y > 0.2 && p.y < 0.8) {
			float f = (p.x - edge) / (1.0 - 2.0 * edge);
			col = f <= mana_frac ? mana_color.rgb : vec3(0.08, 0.09, 0.14);
		}
	}
	ALBEDO = col;
	ALPHA = a;
}
"""
	_bar_mat = ShaderMaterial.new()
	_bar_mat.shader = sh
	_bar_mat.set_shader_parameter("mana_color", MANA_COLOR)
	_bar_mat.render_priority = 2
	return _bar_mat


## Plateau regardé ou caché : un plateau caché n'a ni rendu, ni animation, ni effets, sons ou chiffres (SPEC §4.3).
func set_shown(on: bool) -> void:
	ac_shown = on
	visible = on
	if anim:
		anim.active = on


# --- Miroir de la couche d'effets ---------------------------------------------------------------------------------------
func _ctx() -> Dictionary:
	return ac_arena.get("ctx", {})


## PV, mana et contrôles lus dans la couche (la seule vérité).
func sync() -> void:
	var ctx := _ctx()
	if ctx.is_empty() or ac_fid < 0:
		return
	max_hp = maxf(1.0, AutochessEffects.hp_max(ctx, ac_fid))
	if not is_dead:
		hp = AutochessEffects.hp(ctx, ac_fid)
	_refresh_bar()


func _refresh_bar() -> void:
	if _ac_bar == null or not ac_shown:
		return
	var ctx := _ctx()
	if ctx.is_empty():
		return
	_ac_bar.set_instance_shader_parameter("hp_frac", clampf(hp / maxf(max_hp, 1.0), 0.0, 1.0))
	var need := AutochessEffects.mana_needed(ctx, ac_fid)
	_ac_bar.set_instance_shader_parameter("mana_frac", clampf(AutochessEffects.mana(ctx, ac_fid) / maxf(need, 1.0), 0.0, 1.0) if need < INF else 0.0)


## Contrôle venu de la couche (étourdi, gelé, renversé) : le socle s'arrête le temps voulu.
func ac_stun(kind: String, dur: float) -> void:
	var st := "freeze" if kind == "freeze" else "stun"
	statuses[st] = maxf(float(statuses.get(st, 0.0)), clock + dur)
	if _state == "attack" and not _hit_done:
		_cancel_attack_force()
	statuses_changed.emit()


## Chute (effet « death » de la couche) : animation de mort, plus aucune cible ni coup.
func ac_die(killer: Combatant = null) -> void:
	if is_dead:
		return
	is_dead = true
	hp = 0.0
	_ac = {}
	_refresh_bar()
	if _ac_bar:
		_ac_bar.visible = false
	if _ac_name:
		_ac_name.visible = false
	clear_ffa()
	_on_death(killer)
	died.emit(self, killer)


## Fin du combat : l'unité s'arrête sur place.
func ac_stop() -> void:
	if is_instance_valid(_telegraph):
		_telegraph.queue_free()
	_ac = {}
	velocity = Vector3.ZERO
	if not is_dead:
		_set_state("idle")
		play(_anim("idle", "stand01") if _ac_monster.is_empty() else ("stand01" if has_anim("stand01") else "battle01"), 0.2)


# --- Boucle ---------------------------------------------------------------------------------------------------------
func _physics_process(delta: float) -> void:
	if ac_arena.is_empty() or not bool(ac_arena.get("running", false)) or is_dead:
		if is_dead:
			super._physics_process(delta)  # chute, animation de mort
		return
	var ctx := _ctx()
	move_speed = _ac_base_speed * AutochessEffects.stat(ctx, ac_fid, "move")
	if not _can_target():
		_retarget_t = 0.0  # cible tombée : nouvelle cible tout de suite
	_retarget_t = minf(_retarget_t, RETARGET_EVERY)
	super._physics_process(delta)
	_clamp_to_board()


## Bornes : le plateau moins BOARD_MARGIN ; personne ne sort, jamais (sauts, élans et esquives compris).
func _clamp_to_board() -> void:
	var o: Vector3 = ac_arena.get("origin", Vector3.ZERO)
	var hx := AutochessDirector.HALF_X - AutochessData.BOARD_MARGIN
	var hz := AutochessDirector.HALF_Z - AutochessData.BOARD_MARGIN
	var p := global_position
	var lx := clampf(p.x - o.x, -hx, hx)
	var lz := clampf(p.z - o.z, -hz, hz)
	var out := not is_equal_approx(lx, p.x - o.x) or not is_equal_approx(lz, p.z - o.z)
	if p.y < o.y - 1.0:
		p.y = o.y + AutochessDirector.FLOOR_Y
		velocity.y = 0.0
		out = true
	if out:
		ac_stats["out"] = int(ac_stats.out) + 1
		global_position = Vector3(o.x + lx, p.y, o.z + lz)
		_dash_until = minf(_dash_until, _time)


## Ennemis vivants de son plateau (le directeur), jamais les groupes globaux.
func _hostile_pool() -> Array:
	return ac_dir.foes_of(self) if ac_dir else []


## Équipiers vivants (lui compris) : soins et renforts de son camp.
func _teammates() -> Array:
	return ac_dir.allies_of(self) if ac_dir else [self]


func _team_mode() -> bool:
	return true


## Aucun héros du joueur à lire en combat : seules les zones rouges des sorts ennemis comptent.
func _player_hero() -> Player:
	return null


## Pas de « temps mort du héros » à punir : le rythme des coups est celui de la vitesse d'attaque.
func _player_open() -> bool:
	return false


## Point d'extension AC-U : cible parmi [param pool] (score, focus d'équipe). Squelette : celui de ClassRival en équipe
## (le plus faible pas trop loin, inertie), ou le plus proche en IA naïve.
func pick_target(pool: Array, current = null) -> Combatant:
	return choose_target(pool, current)


func choose_target(pool: Array, current = null) -> Combatant:
	if naive:
		return _nearest(pool)
	return super.pick_target(pool, current)


func _nearest(pool: Array) -> Combatant:
	var best: Combatant = null
	var bd := INF
	for n in pool:
		var c := n as Combatant
		if c == null or c.is_dead or c == self:
			continue
		var d := global_position.distance_squared_to(c.global_position)
		if d < bd:
			bd = d
			best = c
	return best


## Portée d'attaque : celle de la couche (cases × 2 m + 0,5 ; mêlée 3,2 m), objets et traits compris.
func _attack_range() -> float:
	var ctx := _ctx()
	if ctx.is_empty():
		return super._attack_range()
	return AutochessEffects.stat(ctx, ac_fid, "reach") * 0.95


## Zones de l'autre camp seulement (prototype d'AC2) ; les auto-attaques n'ont pas de zone : seuls les sorts s'esquivent.
func _read_zones() -> void:
	if _time < _zone_check_at or is_invulnerable() or not _can_dodge():
		return
	_zone_check_at = _time + 0.08
	if _seen_zones.size() > 64:
		_seen_zones.clear()
	for n in get_tree().get_nodes_in_group("telegraphs"):
		var tg := n as Telegraph
		if tg == null or tg.is_queued_for_deletion():
			continue
		var src = tg.source
		if is_instance_valid(src) and (src == self or (src.ffa_id >= 0 and src.ffa_id == ffa_id) or (src.ffa_id < 0 and src.team == team)):
			continue
		var iid := tg.get_instance_id()
		if _seen_zones.has(iid) or not tg.contains(global_position, radius):
			continue
		_seen_zones[iid] = true
		var left := tg.delay - tg._t
		if randf() > float(cfg.read) or left < float(cfg.react):
			continue
		var out := global_position - tg.global_position
		out.y = 0.0
		_react_dir = out.normalized() if out.length() > 0.1 else -forward()
		_react_at = _time + clampf(left - DASH_IFRAMES * 0.6, float(cfg.react), maxf(left - 0.04, 0.0))
		return


## Mêlée qui attend son coup : reste au contact (prototype d'AC2 : ClassRival tournait à 4,5 m, pensé contre le joueur).
func _update_chase(delta: float) -> Vector3:
	if is_passive() or not _can_target() or flee or goal != Vector3.INF or _ranged():
		return super._update_chase(delta)
	var ready := _time >= _attack_ready_at and _time >= _dodge_until and not has_status("disarm") and not has_status("fear")
	if ready:
		return super._update_chase(delta)
	var to := _player.global_position - global_position
	to.y = 0.0
	var dist := to.length()
	face_direction(to, delta, 16.0)
	var v := Vector3.ZERO
	if dist > _attack_range():
		v = _path_step(_player.global_position) * move_speed
	if _time >= _dash_until and is_on_floor():
		play(_anim("run", "move02") if v.length() > 0.1 else _battle_anim(), 0.15)
	return v


# --- Coups et sorts --------------------------------------------------------------------------------------------------
## Le sort part-il maintenant ? (point d'extension AC-U : type du sort, groupes, attente d'une meilleure occasion)
## Squelette : mana pleine, cible à portée du sort (ou attente de ZONE_WAIT s), soin s'il y a un blessé (ou après HEAL_WAIT s).
func wants_cast() -> bool:
	if ac_sig.is_empty():
		return false
	if not _ac_recast and not AutochessEffects.can_cast(_ctx(), ac_fid):
		_ac_mana_full_at = -1.0
		return false
	if _ac_mana_full_at < 0.0:
		_ac_mana_full_at = _time
	var waited := _time - _ac_mana_full_at
	if is_heal(ac_sig):
		return heal_target(waited >= HEAL_WAIT) != null
	return naive or waited >= ZONE_WAIT or global_position.distance_to(_player.global_position) <= skill_reach(ac_sig)


static func is_heal(s: Dictionary) -> bool:
	return String(s.get("kind", "")) == "heal"


## Allié à soigner : le plus bas en part de PV, blessé ([param any] : même sans blessure, le plus bas).
func heal_target(any := false) -> AutochessUnit:
	var best: AutochessUnit = null
	var bf := INF
	for n in _teammates():
		var u := n as AutochessUnit
		if u == null or u.is_dead:
			continue
		var f := u.hp / maxf(u.max_hp, 1.0)
		if (any or f < 0.999) and f < bf:
			bf = f
			best = u
	return best


## Allonge d'un sort (prototype d'AC2) : zone / trait : portée ; cône, cercle : rayon ; élan : portée + rayon.
func skill_reach(s: Dictionary) -> float:
	var kind := String(s.get("kind", "cone"))
	var r := float(s.get("radius", 3.0))
	var rng := float(s.get("range", 0.0))
	if kind in ["bolt", "ground", "line", "fan", "blink"] or rng > r + 1.0:
		return maxf(rng, r) + 0.5
	if kind == "dash":
		return maxf(rng, 6.0) + r
	return r + radius + 0.6


## Sort à mana pleine, sinon auto-attaque de l'arme. Remplace ClassRival._start_attack (recharges -> mana).
func _start_attack() -> void:
	if not _can_target():
		return
	var ctx := _ctx()
	var sk: Dictionary = {}
	var mode := "auto"
	var heal_to: AutochessUnit = null
	if not _ac_chain_next.is_empty():
		sk = _ac_chain_next
		_ac_chain_next = {}
		mode = "chain"
		ac_stats["chains"] = int(ac_stats.chains) + 1
	elif wants_cast():
		sk = ac_sig
		mode = "spell"
		if _ac_recast:
			_ac_recast = false
			ac_stats["recasts"] = int(ac_stats.recasts) + 1
		else:
			ac_dir.on_effects(ac_arena, AutochessEffects.cast(ctx, ac_fid))
			ac_stats["casts"] = int(ac_stats.casts) + 1
		_ac_mana_full_at = -1.0
		if not ac_chain.is_empty():
			_ac_chain_next = ac_chain
	if not sk.is_empty() and is_heal(sk):
		heal_to = heal_target(true)
	_begin_action(sk, mode, heal_to)


func _begin_action(sk: Dictionary, mode: String, heal_to: AutochessUnit) -> void:
	var act: Dictionary = sk if not sk.is_empty() else auto_step
	if sk.is_empty():
		_combo_i += 1
		_ac_last_auto = _time
	var anim_name := String(act.get("anim", "attack01"))
	if not has_anim(anim_name):
		anim_name = String(auto_step.get("anim", "attack01"))
	_set_state("attack")
	var keys := keys_of(anim_name)
	var hits: Array = keys.get("hit", [])
	var length := maxf(anim_length(anim_name), 0.5)
	var hit_t := float(hits[0]) if not hits.is_empty() else length * HIT_FRACTION
	var delay := maxf(hit_t, float(cfg.tele))
	var speed := hit_t / delay
	_state_len = length / speed + 0.15
	_hit_time = delay
	_hit_done = false
	var target: Combatant = heal_to if heal_to != null else _player
	var tv := target.velocity
	tv.y = 0.0
	var aim := target.global_position + tv * delay * float(cfg.lead) * (0.0 if heal_to != null else 1.0)
	var to := aim - global_position
	to.y = 0.0
	var yaw := atan2(to.x, to.z)
	if heal_to == null or heal_to != self:
		face_direction(to, 1.0, 100.0)
	if ac_shown and not sk.is_empty():
		var cast_fx := String(sk.get("fx", {}).get("cast", ""))
		EdenFx.play(self, cast_fx, global_position, yaw, EdenFx.cast_scale(cast_fx, sk, float(sk.get("radius", 0.0))), self)
	if ac_shown:
		for snd in keys.get("sounds", []):
			get_tree().create_timer(float(snd[0]) / speed, false).timeout.connect(func():
				if _state == "attack" and is_instance_valid(self):
					Sfx.play_at(self, global_position, String(snd[1]), -9.0))
	play(anim_name, 0.06, speed, true)
	_ac = {"mode": mode, "skill": sk, "target": _player, "heal_to": heal_to, "started": _time}
	var fx: Variant = act.get("fx")
	var hit_fx := String(act.get("hit_fx", fx.get("hit", "s00141") if fx is Dictionary else ""))
	if sk.is_empty() or heal_to != null:
		# auto-attaque et soin : aucune annonce au sol ; résolus à l'impact (_impact)
		_cur = {"hit_fx": hit_fx, "at": target.global_position, "yaw": yaw, "radius": 0.0} if ac_shown else {}
		return
	var kind := String(sk.get("kind", "cone"))
	var r := float(sk.get("radius", 3.0))
	var rng := float(sk.get("range", 0.0))
	var at := global_position
	var dmg := spell_damage(mode == "chain")
	var props := {"delay": delay, "damage": dmg, "source": self, "crit": false}
	var far := to.length() > skill_reach(sk) + 0.5
	if kind == "ground" or (far and not kind in ["bolt", "line", "fan", "dash", "blink"]):
		# zone visée (ou sort autour de soi dont la cible est trop loin après l'attente : posé sur la cible)
		at = global_position + to.limit_length(maxf(rng, to.length() if far else 4.0))
		props.merge({"shape": "circle", "radius": maxf(r, 2.0)})
	elif kind in ["bolt", "line", "fan", "blink"] or rng > r + 1.0:
		props.merge({"shape": "line", "length": maxf(maxf(rng, r), to.length() + 1.0), "width": 1.4 if kind != "line" else maxf(1.4, minf(r, 3.0))})
	elif float(sk.get("arc", 120.0)) >= 359.0 or kind == "spin":
		props.merge({"shape": "circle", "radius": r})
	else:
		props.merge({"shape": "cone", "radius": r, "angle": float(sk.get("arc", 120.0))})
	if kind == "dash":
		_pending_dash = to.normalized() * minf(to.length(), maxf(rng, 6.0))
	_cur = {"hit_fx": hit_fx, "at": at, "yaw": yaw, "radius": r} if ac_shown else {}
	_telegraph = Telegraph.spawn(self, at, yaw, props)
	_telegraph.visible = ac_shown


## Dégâts de base du sort (fiche de la couche, rang compris) ; le 2e sort d'une ★3 en vaut CHAIN_FACTOR.
func spell_damage(chain := false) -> float:
	var u := AutochessEffects.unit(_ctx(), ac_fid)
	var base := float(u.get("sheet", {}).get("spell_base", 0.0))
	return maxf(1.0, base * (CHAIN_FACTOR if chain else 1.0))


func _update_attack(delta: float) -> void:
	var was := _hit_done
	var a := _ac  # (la fin du coup peut tomber dans la même image que l'impact et effacer l'action)
	super._update_attack(delta)
	if _hit_done and not was:
		_impact(a)


## Impact : auto-attaque (touche si la cible est encore à portée) ou soin, par la couche d'effets. Les sorts de dégâts
## tombent par leur zone rouge (Telegraph -> take_damage -> spell_hit).
func _impact(a: Dictionary) -> void:
	if a.is_empty() or is_dead:
		return
	var ctx := _ctx()
	var mode := String(a.mode)
	if mode == "auto":
		var t := a.target as AutochessUnit
		if t != null and is_instance_valid(t) and not t.is_dead and t.ac_arena == ac_arena \
				and global_position.distance_to(t.global_position) <= _attack_range() + t.radius + 1.2:
			ac_stats["autos"] = int(ac_stats.autos) + 1
			ac_dir.on_effects(ac_arena, AutochessEffects.attack(ctx, ac_fid, t.ac_fid))
	elif a.heal_to != null:
		var h := a.heal_to as AutochessUnit
		if is_instance_valid(h) and not h.is_dead:
			var sk: Dictionary = a.skill
			var amount := AutochessEffects.hp_max(ctx, h.ac_fid) * clampf(float(sk.get("heal", 0.25)), 0.1, 0.4) \
				* AutochessData.spell_mult(stars()) * (CHAIN_FACTOR if mode == "chain" else 1.0)
			ac_stats["heals"] = int(ac_stats.heals) + 1
			ac_dir.on_effects(ac_arena, AutochessEffects.spell_heal(ctx, ac_fid, h.ac_fid, amount))
			if ac_shown:
				Vfx.ring(h, h.global_position, 1.6, Color(0.5, 1.0, 0.55, 0.9))


## Cadence : la prochaine auto-attaque attend 1 / vitesse d'attaque (objets et traits compris) depuis la précédente.
func _end_of_hit() -> void:
	super._end_of_hit()
	var a := _ac
	_ac = {}
	if String(a.get("mode", "auto")) == "auto":
		var aspd := maxf(AutochessEffects.stat(_ctx(), ac_fid, "as"), 0.1)
		_attack_ready_at = maxf(_time + 0.05, float(a.get("started", _time)) + 1.0 / aspd)
	elif not _ac_chain_next.is_empty():
		_attack_ready_at = _time  # ★3 : le 2e sort part juste après
	else:
		_attack_ready_at = _time + 0.25


## Un sort en préparation ne s'annule pas par une esquive (la mana est dépensée) ; les auto-attaques, si.
func _dodge(dir: Vector3, iframes := true) -> void:
	if _state == "attack" and not _hit_done and String(_ac.get("mode", "auto")) != "auto":
		return
	super._dodge(dir, iframes)


func _cancel_attack() -> void:
	if _state == "attack" and not _hit_done and String(_ac.get("mode", "auto")) != "auto":
		return
	_ac = {}
	super._cancel_attack()


func _cancel_attack_force() -> void:
	_ac = {}
	super._cancel_attack()


## Coup reçu : seuls les sorts de l'autre camp du même plateau comptent, par la couche (défense, plafonds, Fureur,
## objets) ; pas de bond réflexe (prototype d'AC2). Rien d'autre ne blesse une unité.
func take_damage(amount: float, source: Combatant = null, _crit := false, dot := false) -> void:
	if is_dead or ac_arena.is_empty():
		return
	var src := source as AutochessUnit
	if src == null or src.ac_arena != ac_arena:
		ac_stats["foreign"] = int(ac_stats.foreign) + 1
		return
	if src.ac_side == ac_side:
		return
	if is_invulnerable() and not dot:
		if ac_shown:
			DamageNumber.spawn_text(self, "ESQUIVE", Color(0.7, 1.0, 0.7))
		return
	var kind := "magic" if String(src.ac_sig.get("dmg_type", "phys")) in ["mag", "magic"] else "phys"
	ac_dir.on_effects(ac_arena, AutochessEffects.spell_hit(_ctx(), src.ac_fid, ac_fid, amount, {"kind": kind}))


## Soins : seulement par la couche (spell_heal), jamais directement.
func heal(_amount: float) -> void:
	pass
