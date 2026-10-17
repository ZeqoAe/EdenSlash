class_name AutochessUnit
extends ClassRival
## L'Échiquier : une unité du combat réel. Squelette (lot AC-E, R_AC_E.md) et IA de combat (lot AC-U, SPEC §4.1, rapport
## conception/autochess/R_AC_U.md). Socle : ClassRival (déplacement, esquive, animations), sans repli ni bond réflexe ni
## annulation après l'impact. Vérité du combat = la couche d'effets AutochessEffects (PV, mana, boucliers, contrôles,
## traits, objets, atouts) : chaque coup, sort, soin et chute passe par elle (attack / cast / spell_hit / spell_heal), le
## nœud n'en est que le miroir (sync). Le directeur (AutochessDirector) crée l'unité, lui donne son plateau (arena) et ses
## listes d'ennemis et d'alliés, avance la couche et traite les effets rendus (on_effects).
##
## Camps : ffa_id = 2 × plateau + camp (chacun pour soi entre camps : Combatant.ffa_foes, aucun coup allié). Ennemis et
## alliés viennent du directeur (jamais des groupes « ffa » / « monsters » : 4 plateaux tournent en même temps).
## Sorts : à mana pleine (AutochessEffects.can_cast), sort signature de l'unité (data/autochess_units.json « skill_id ») ;
## ★3 : le 2e sort (« second_skill_id ») part juste après, sans mana. Auto-attaque : au rythme de stat("as"), touche à
## l'impact sans annonce au sol (SPEC §3.3 : annonce rouge pour les sorts seulement) ; portée = stat("reach").
##
## IA (AC-U), cinq comportements coupables un à un (banc d'essai tools/autochess_ai_bench.tscn, SPEC §4.2) :
##  roles   : place par rôle (autochess_units.json « role ») : mêlée au contact ; tireurs, mages, soigneurs et soutiens à
##            distance gardent leur portée, reculent d'un bond devant une mêlée (vers leurs alliés, jamais dans un coin),
##            soigneurs et soutiens restent derrière la ligne ; assassins qui plongent sur l'arrière-ligne par le flanc
##            le moins garni (après l'engagement des mêlées ennemies) ; bords du plateau évités (glisse le long du bord) ;
##  target  : score de cible (faiblesse, menace, achèvement, distance : AutochessData.AI_WEIGHTS), focus du camp (+30 %),
##            3 mêlées au plus sur une cible, marge de 25 % avant de changer de cible, cible hors d'atteinte 1,5 s ;
##            tank qui prend l'ennemi qui frappe un allié fragile ; assassin : arrière-ligne non protégée d'abord ;
##  spells  : sort selon son type (AutochessData.SPELL_TYPES) : zone posée où elle touche le plus d'ennemis (2 au moins,
##            1,5 s d'attente au plus), cible unique sur l'alignement le plus garni, soin sur l'allié le plus bas à portée
##            quand il manque assez de PV (pas de soin perdu), renfort au début, déplacement pour rejoindre ;
##  dodge   : esquive des zones rouges ENNEMIES seulement (de côté pour les lignes et cônes, vers son camp sinon) ;
##  retreat : repli sous 30 % de PV des rôles fragiles visés par une mêlée, 1,5 s au plus (COUPÉ par défaut : perdant).
## IA naïve (tous coupés) : ennemi le plus proche, sort dès la mana pleine sur la cible, soigneur qui avance comme un
## combattant, aucun recul ni esquive. Réglage : AutochessUnit.ai_full() ; un combat peut donner [opts camp 0, opts camp 1]
## dans fight.ai (banc d'essai).
##
## Contrat avec le directeur (ne pas changer) : setup_unit, sync, ac_die, ac_stun, ac_stop, set_shown, ac_stats.

const RETARGET_EVERY := 1.0 / AutochessData.AI_DECISIONS_PER_S  # s : décision de cible et de sort (SPEC §4.1 : 4 fois par seconde)
const ZONE_WAIT := AutochessData.AI_ZONE_WAIT  # s : une zone attend au plus ça une meilleure occasion (2 cibles)
const FAR_WAIT := 3.0  # s : un sort qui n'a aucune cible à sa portée part quand même sur la cible après ce délai
const HEAL_WAIT := AutochessData.AI_HEAL_WAIT  # s : le soigneur attend qu'un allié soit assez blessé, puis soigne le plus bas
const HEAL_URGENT := 0.45  # part de PV sous laquelle un allié est soigné tout de suite
const HEAL_RANGE_MIN := 8.5  # m : portée des soins au moins (soigneurs de mêlée compris)
const CHAIN_FACTOR := 0.6  # ★3 : dégâts du 2e sort (sans mana) en part du sort signature
const BAR_SIZE := Vector2(1.7, 0.3)  # m : barres de PV (haut) et de mana (bas) au-dessus de l'unité
const BAR_Y := 2.75
const SIDE_COLORS := [Color(0.35, 0.9, 0.45), Color(0.95, 0.3, 0.28)]  # PV : son camp vert, l'adversaire rouge
const MANA_COLOR := Color(0.35, 0.62, 1.0)
const MONSTER_NAMES := {"sbire": "Sbire", "elite": "Élite"}
const GUARDIAN_NAME := "Gardien"

const BEHAVIORS := ["roles", "target", "spells", "dodge", "retreat"]
## Repli sous 30 % : mesuré perdant (seul 52,5 % contre la naïve ; l'IA complète sans repli bat celle avec repli 58 %) :
## coupé, gardé pour le banc (« full,retreat »). R_AC_U.md.
const OFF_BY_DEFAULT := ["retreat"]
const FRAGILE := ["tireur", "mage", "soigneur", "soutien", "assassin"]
const BACK_ROLES := ["tireur", "mage", "soigneur", "soutien"]
const RANGED_MIN := 5.0  # m : allonge à partir de laquelle une unité se tient à distance (lance : 4,5 m = mêlée)
const EDGE_SOFT := 1.4  # m : près d'un bord, la composante qui sort du plateau s'efface (glisse le long du bord)
const KEEP_IN := 0.4  # m : marge minimale gardée avant la borne dure
const HOP_GAP := 1.1  # s entre deux bonds de recul
const THREAT_M := AutochessData.AI_RETREAT_CELLS * AutochessData.CELL + 0.4  # m : une mêlée « arrive » sur un tireur
const LINE_BEHIND := 1.6  # m : soigneurs et soutiens derrière l'allié de mêlée le plus avancé
const DIVE_WAIT := 0.9  # s : l'assassin attend l'engagement des mêlées ennemies (au plus)
const PROTECT_M := 3.0  # m : une cible d'arrière-ligne est protégée si 2 mêlées ennemies sont à cette distance
const TANK_GUARD_BONUS := 3.0  # score : le tank prend l'ennemi qui frappe un allié fragile (presque toujours)
const RETREAT_TIME := 1.5
const RETREAT_GAP := 8.0
const MELEE_SLOT := 0.9  # part de l'allonge visée par une mêlée (au contact)
const LEAD_TIME := 0.45  # s : zone posée où les ennemis seront (détail « lead », coupé : 45 % contre la version sans)
const SAMPLE_EVERY := 0.25  # s : relevés du banc d'essai (inactivité, portée)
const IDLE_AFTER := 3.0  # s sans action (coup, sort, soin) : inactive

## Comportements de l'IA (BEHAVIORS -> vrai / faux) ; naive = tous coupés.
var ai: Dictionary = ai_full()
var naive := false:
	set(v):
		naive = v
		if v:
			ai = ai_naive()
var ac_role := "combattant"
var ac_dir: AutochessDirector
var ac_arena: Dictionary = {}
var ac_fid := -1
var ac_side := 0
var ac_unit: Dictionary = {}  # entrée du plateau (id, stars, cost, items, cell) ; monstre {monster} ; gardien {guardian}
var ac_sig: Dictionary = {}  # sort signature (classes.json)
var ac_chain: Dictionary = {}  # ★3 : 2e sort enchaîné
var ac_shown := true
## Compteurs (gardés après la chute dans arène.stats[fid]) : sorts, auto-attaques, soins, bornes corrigées, coups étrangers ;
## et pour le banc d'essai : zones lancées / ennemis touchés par les sorts, soins demandés / perdus, relevés d'inactivité et
## de portée (tireurs et mages).
var ac_stats := {"casts": 0, "chains": 0, "recasts": 0, "autos": 0, "heals": 0, "out": 0, "foreign": 0, "zone_casts": 0,
	"zone_hits": 0, "line_casts": 0, "line_hits": 0, "heal_req": 0.0, "heal_lost": 0.0, "samples": 0, "idle": 0,
	"range_samples": 0, "in_range": 0, "contact": 0, "hops": 0, "dodges": 0, "dives": 0, "retreats": 0}
var _ac: Dictionary = {}  # action en cours : {mode: auto / spell / chain, skill, target, heal_to, started, type}
var _ac_mana_full_at := -1.0
var _ac_recast := false
var _ac_chain_next: Dictionary = {}
var _ac_last_auto := -10.0
var _ac_last_act := 0.0  # dernière action utile (coup, sort, soin) : inactivité
var _ac_base_speed := 6.2
var _ac_monster: Dictionary = {}  # monstre d'Eden (modèle) des manches de monstres et du gardien
var _ac_bar: MeshInstance3D
var _ac_name: Label3D
var _plan: Dictionary = {}  # sort décidé à la dernière décision : {ok, aim, heal_to, count}
var _plan_at := -10.0
var _sample_at := 0.0
var _hist: Array = []  # dégâts infligés (couche) relevés chaque seconde : menace
var _hist_at := 0.0
var _far_since := -1.0  # cible hors d'atteinte depuis
var _dive := 0  # assassin : 0 attend, 1 plonge, 2 engagé
var _flank := 0.0  # côté du contournement (x local)
var _retreat_at := -INF  # fin du repli en cours
var _retreat_next := 0.0
var _heal_incoming := 0.0  # part des PV max déjà en route (soin d'un allié en préparation)
static var _bar_mat: ShaderMaterial


## Réglage complet : tous les comportements, sauf ceux de OFF_BY_DEFAULT (mesurés perdants au banc d'essai).
static func ai_full() -> Dictionary:
	var d := {}
	for k in BEHAVIORS:
		d[k] = not (k in OFF_BY_DEFAULT)
	return d


## IA naïve du banc d'essai (SPEC §4.2) : aucun comportement.
static func ai_naive() -> Dictionary:
	var d := {}
	for k in BEHAVIORS:
		d[k] = false
	return d


## Comportement [param k] actif ?
func on(k: String) -> bool:
	return bool(ai.get(k, false))


## Détail [param k] d'un comportement [param main] (banc d'essai : « full,-hop ») : actif avec lui, sauf s'il est coupé.
## roles : hop (bond de recul), dive (plongée), line (soigneurs derrière la ligne) ; target : focus, guard (tank) ;
## spells : lead (zone posée où les ennemis seront : mesuré perdant, coupé par défaut, « full,lead » pour l'essayer).
func sub(main: String, k: String) -> bool:
	return on(main) and bool(ai.get(k, true))


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
	# corrections d'AC2 : pas de repli de ClassRival sous 30 % de PV (le bond réflexe est coupé dans take_damage)
	_retreat_ready = INF
	if u.get("guardian", false):
		ac_role = "tank"
	elif id != "":
		ac_role = String(AutochessData.unit(id).get("role", "combattant"))
	# comportements de l'IA : tous, ou ceux du combat (banc d'essai : fight.ai = [camp 0, camp 1])
	var opts: Variant = (arena.get("fight", {}) as Dictionary).get("ai")
	if opts is Array and side < (opts as Array).size():
		var o: Variant = opts[side]
		ai = ai_naive() if (o is String and String(o) == "naive") else ai_full()
		if o is Dictionary:
			for k in o:
				ai[String(k)] = bool(o[k])
	naive = not BEHAVIORS.any(func(k): return on(String(k)))
	# décisions (cible et sort) décalées d'une unité à l'autre
	_retarget_t = fmod(float(fid) * 0.071, RETARGET_EVERY)
	_plan_at = _retarget_t
	set_ffa(2 * int(arena.get("index", 0)) + side)
	if arena.get("stats") is Dictionary:
		arena.stats[fid] = ac_stats  # compteurs gardés après la chute (le nœud est libéré)
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
	_player = null  # jamais le héros du joueur (stratège au bord du plateau) : cible choisie à la première décision
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
	_ac_name.pixel_size = 0.0007
	_ac_name.font_size = 24
	_ac_name.outline_size = 8
	_ac_name.position.y = BAR_Y + 0.38
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
	_watch()
	super._physics_process(delta)
	_clamp_to_board()


## Bornes : le plateau moins BOARD_MARGIN ; personne ne sort, jamais (sauts, élans et esquives compris). Filet de sécurité :
## les déplacements de l'IA glissent déjà le long des bords (_edge_safe).
func _clamp_to_board() -> void:
	var o: Vector3 = ac_arena.get("origin", Vector3.ZERO)
	var lim := limits()
	var p := global_position
	var lx := clampf(p.x - o.x, -lim.x, lim.x)
	var lz := clampf(p.z - o.z, -lim.y, lim.y)
	var out := not is_equal_approx(lx, p.x - o.x) or not is_equal_approx(lz, p.z - o.z)
	if p.y < o.y - 1.0:
		p.y = o.y + AutochessDirector.FLOOR_Y
		velocity.y = 0.0
		out = true
	if out:
		ac_stats["out"] = int(ac_stats.out) + 1
		global_position = Vector3(o.x + lx, p.y, o.z + lz)
		_dash_until = minf(_dash_until, _time)


## Relevés du banc d'essai (inactivité, portée des tireurs et mages) et mémoire courte (menace, cible hors d'atteinte).
func _watch() -> void:
	if _time >= _hist_at:
		_hist_at = _time + 1.0
		_hist.append(_dealt())
		if _hist.size() > 4:
			_hist.pop_front()
	if _can_target():
		if _flat_dist(_player) > _attack_range() + 0.5:
			if _far_since < 0.0:
				_far_since = _time
		else:
			_far_since = -1.0
	if _time < _sample_at:
		return
	_sample_at = _time + SAMPLE_EVERY
	var foes := _hostile_pool()
	if foes.is_empty() or is_disabled():
		return
	ac_stats["samples"] += 1
	if _time - _ac_last_act > IDLE_AFTER:
		ac_stats["idle"] += 1
	if ac_role in ["tireur", "mage"] and _ac_monster.is_empty() and _can_target():
		ac_stats["range_samples"] += 1
		if _flat_dist(_player) <= _attack_range() + 0.5:
			ac_stats["in_range"] += 1
		if _melee_threat(AutochessData.MELEE_REACH + 0.3) != null:
			ac_stats["contact"] += 1


func _dealt() -> float:
	return float(AutochessEffects.unit(_ctx(), ac_fid).get("stats", {}).get("dealt", 0.0))


## Dégâts infligés ces 3 dernières secondes (menace).
func recent_dealt() -> float:
	return maxf(0.0, _dealt() - float(_hist[0])) if not _hist.is_empty() else 0.0


## Valeur d'une unité (coût × étoiles, objets portés) : menace.
func worth() -> float:
	return float(maxi(int(ac_unit.get("cost", 1)), 1) * stars()) + 0.5 * (ac_unit.get("items", []) as Array).size()


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


# --- Plateau : repères et bords -----------------------------------------------------------------------------------------
## Demi-dimensions utiles du plateau (bornes dures).
static func limits() -> Vector2:
	return Vector2(AutochessDirector.HALF_X - AutochessData.BOARD_MARGIN, AutochessDirector.HALF_Z - AutochessData.BOARD_MARGIN)


func _origin() -> Vector3:
	return ac_arena.get("origin", Vector3.ZERO)


## Vers l'adversaire (le camp 0 est en z positif).
func _fwd() -> Vector3:
	return Vector3(0.0, 0.0, -1.0 if ac_side == 0 else 1.0)


## Avancée d'un point vers l'adversaire (m, repère du plateau).
func _depth(p: Vector3) -> float:
	return (p - _origin()).dot(_fwd())


func _flat_dist(c: Node3D) -> float:
	var d := c.global_position - global_position
	return Vector2(d.x, d.z).length()


## Vitesse ou direction [param v] sans sa part qui sortirait du plateau près d'un bord (glisse le long du bord).
func _edge_safe(v: Vector3, soft := EDGE_SOFT) -> Vector3:
	var p := global_position - _origin()
	var lim := limits()
	if v.x > 0.0:
		v.x *= _room(lim.x - p.x, soft)
	elif v.x < 0.0:
		v.x *= _room(lim.x + p.x, soft)
	if v.z > 0.0:
		v.z *= _room(lim.y - p.z, soft)
	elif v.z < 0.0:
		v.z *= _room(lim.y + p.z, soft)
	return v


static func _room(gap: float, soft: float) -> float:
	return clampf((gap - KEEP_IN) / maxf(soft - KEEP_IN, 0.01), 0.0, 1.0)


## Point [param p] ramené à [param m] m des bords.
func _inside(p: Vector3, m := EDGE_SOFT) -> Vector3:
	var o := _origin()
	var lim := limits()
	return Vector3(o.x + clampf(p.x - o.x, -lim.x + m, lim.x - m), p.y, o.z + clampf(p.z - o.z, -lim.y + m, lim.y - m))


## Écartement entre unités : jamais vers l'extérieur du plateau.
func _separation() -> Vector3:
	return _edge_safe(super._separation())


## Se tient à distance (allonge d'au moins RANGED_MIN : sceptre, guitare, bâton, arc, canon, grimoire).
func _ranged_pos() -> bool:
	return _attack_range() >= RANGED_MIN


## Mêlée ennemie la plus proche à moins de [param m] m, ou null ; [param mine] : seulement celles qui le visent.
func _melee_threat(m: float, mine := false) -> AutochessUnit:
	var best: AutochessUnit = null
	var bd := m
	for n in _hostile_pool():
		var e := n as AutochessUnit
		if e == null or e.is_dead or e._ranged_pos() or (mine and e._player != self):
			continue
		var d := _flat_dist(e)
		if d <= bd:
			bd = d
			best = e
	return best


## Centre de ses alliés (sans lui) ; Vector3.INF s'il est seul.
func _mates_center(melee_only := false) -> Vector3:
	var sum := Vector3.ZERO
	var n := 0
	for m in _teammates():
		var u := m as AutochessUnit
		if u == null or u == self or u.is_dead or (melee_only and u._ranged_pos()):
			continue
		sum += u.global_position
		n += 1
	return sum / n if n > 0 else Vector3.INF


## Avancée de l'allié de mêlée le plus avancé (-INF s'il n'y en a pas) : la ligne de front.
func _front_line() -> float:
	var best := -INF
	for m in _teammates():
		var u := m as AutochessUnit
		if u == null or u == self or u.is_dead or u._ranged_pos():
			continue
		best = maxf(best, _depth(u.global_position))
	return best


# --- Déplacement par rôle -------------------------------------------------------------------------------------------
## Sort à mana pleine (ou 2e sort d'une ★3), sinon place selon le rôle et auto-attaque à portée. Remplace le placement de
## ClassRival (pensé contre le joueur : tourner à 4,5 m, bonds, repli).
func _update_chase(delta: float) -> Vector3:
	if is_passive() or not _can_target():
		_set_state("idle")
		return Vector3.ZERO
	var free := _time >= _dodge_until and not has_status("disarm") and not has_status("fear")
	if free and (not _ac_chain_next.is_empty() or wants_cast()):
		_start_attack()
		if _state == "attack":
			return Vector3.ZERO
	var v := _ai_move()
	if _time < _dash_until:
		return v
	var to := _player.global_position - global_position
	to.y = 0.0
	var retreating := _time < _retreat_at
	if not retreating and free and _time >= _attack_ready_at and to.length() <= _attack_range() + 0.3:
		_start_attack()
		if _state == "attack":
			return Vector3.ZERO
	if retreating and v.length() > 0.1:
		face_direction(v, delta, 12.0)
	else:
		face_direction(to, delta, 16.0)
	if is_on_floor():
		play(_anim("run", "move02") if v.length() > 0.1 else _battle_anim(), 0.15)
	return v


## Vitesse voulue selon le rôle (comportement « roles ») ; IA naïve : droit sur sa cible jusqu'à portée.
func _ai_move() -> Vector3:
	if on("retreat") and ac_role in FRAGILE and _ac_monster.is_empty():
		var r := _retreat_step()
		if r != Vector3.INF:
			return r
	if not on("roles"):
		return _move_contact(_player, _attack_range() * 0.9)
	if ac_role == "assassin" and not _ranged_pos() and sub("roles", "dive"):
		var d := _dive_step()
		if d != Vector3.INF:
			return d
	if _ranged_pos():
		return _move_ranged()
	return _move_contact(_player, _attack_range() * MELEE_SLOT)


## Mêlée : au contact de [param t] (à [param want] m), sans tourner autour.
func _move_contact(t: Combatant, want: float) -> Vector3:
	var to := t.global_position - global_position
	to.y = 0.0
	if to.length() <= want:
		return Vector3.ZERO
	return _edge_safe(to.normalized() * move_speed)


## Tireur, mage, soigneur ou soutien à distance : garde sa portée ; recule d'un bond quand une mêlée arrive (vers ses alliés,
## jamais dans un coin) ; soigneur et soutien restent derrière la ligne de leurs mêlées.
func _move_ranged() -> Vector3:
	var threat := _melee_threat(THREAT_M, true)
	if threat != null and sub("roles", "hop"):
		var hop := _hop_from(threat)
		if hop != Vector3.INF:
			return hop
	var to := _player.global_position - global_position
	to.y = 0.0
	var d := to.length()
	var reach := _attack_range()
	var v := Vector3.ZERO
	if d > reach - 0.4:
		v = to.normalized() * move_speed
	if ac_role in ["soigneur", "soutien"] and sub("roles", "line"):
		var line := _front_line()
		if line > -INF:
			var ahead := _depth(global_position) - (line - LINE_BEHIND)
			if ahead > 0.3 and threat == null:
				v = -_fwd() * move_speed * clampf(ahead, 0.4, 1.0)  # devant sa ligne : recule derrière elle
			elif ahead > -0.2 and v.dot(_fwd()) > 0.0:
				v -= _fwd() * v.dot(_fwd())  # n'avance pas plus loin que la ligne : de côté seulement
	return _edge_safe(v)


## Bond de recul devant [param threat] (esquive prête) : loin de la menace, vers ses alliés et le centre, le long du bord
## s'il est coincé. Vector3.INF : pas de bond.
func _hop_from(threat: Combatant) -> Vector3:
	if _time < _hop_ready or not _can_dodge() or _charges < (1.5 if on("dodge") else 1.0):
		return Vector3.INF
	var away := global_position - threat.global_position
	away.y = 0.0
	if away.length() < 0.05:
		away = -_fwd()
	var dir := away.normalized()
	var mates := _mates_center()
	if mates != Vector3.INF:
		var tm := mates - global_position
		tm.y = 0.0
		if tm.length() > 1.0:
			dir += tm.normalized() * 0.5
	var c := _origin() - global_position
	c.y = 0.0
	dir += c.normalized() * 0.4 * clampf(c.length() / 6.0, 0.0, 1.0)
	dir = _edge_safe(dir.normalized(), 3.6)
	if dir.length() < 0.35:
		var side := away.normalized().cross(Vector3.UP)
		var a := _edge_safe(side, 3.6)
		var b := _edge_safe(-side, 3.6)
		dir = a if a.length() >= b.length() else b
		if dir.length() < 0.35:
			return Vector3.INF  # coincé : il tire sur place
	_hop_ready = _time + HOP_GAP
	ac_stats["hops"] += 1
	_dodge(dir.normalized(), false)
	return _dash_vel


## Repli (rôles fragiles, sous 30 % de PV, une mêlée au contact) : derrière ses mêlées, RETREAT_TIME s au plus.
func _retreat_step() -> Vector3:
	if _time >= _retreat_at:
		if hp >= max_hp * AutochessData.AI_ASSASSIN_FLEE_BELOW or _time < _retreat_next:
			return Vector3.INF
		if _melee_threat(THREAT_M + 1.0, true) == null:
			return Vector3.INF  # personne ne le vise de près : il continue de frapper
		_retreat_at = _time + RETREAT_TIME
		_retreat_next = _time + RETREAT_GAP
		ac_stats["retreats"] += 1
	var safe := _safe_point()
	var to := safe - global_position
	to.y = 0.0
	if to.length() < 0.8:
		_retreat_at = _time
		return Vector3.INF
	var threat := _melee_threat(THREAT_M, true)
	if threat != null and _time >= _hop_ready and _can_dodge() and _charges >= 1.0:
		_hop_ready = _time + HOP_GAP
		_dodge(to.normalized(), false)
		return _dash_vel
	return _edge_safe(to.normalized() * move_speed)


## Abri : derrière ses mêlées (ou derrière lui s'il n'en a plus).
func _safe_point() -> Vector3:
	var base := _mates_center(true)
	if base == Vector3.INF:
		base = global_position
	return _inside(base - _fwd() * 2.5)


# --- Assassin : plongée sur l'arrière-ligne ---------------------------------------------------------------------------
var _dive_t: Variant = null


## Plongée : attend l'engagement des mêlées ennemies (DIVE_WAIT s au plus) en glissant vers le flanc le moins garni, puis
## file sur l'arrière-ligne non protégée (contourne par ce flanc si une mêlée barre la route, un bond s'il est loin).
## Vector3.INF : plus de plongée (engagé, ou aucune cible d'arrière-ligne).
func _dive_step() -> Vector3:
	if _dive >= 2:
		return Vector3.INF
	var o := _origin()
	var lim := limits()
	if _dive == 0:
		if _flank == 0.0:
			_flank = _quiet_flank()
		if float(ac_arena.get("t", 0.0)) < DIVE_WAIT and not _foes_engaged():
			var g := _inside(Vector3(o.x + _flank * (lim.x - 1.6), global_position.y, global_position.z))
			var tg := g - global_position
			tg.y = 0.0
			return _edge_safe(tg.normalized() * move_speed * 0.6) if tg.length() > 0.5 else Vector3.ZERO
		_dive_t = _pick_dive_target()
		if _dive_t == null:
			_dive = 2
			return Vector3.INF
		_dive = 1
		ac_stats["dives"] += 1
		_player = _dive_t
	if not _alive_unit(_dive_t):
		_dive = 2
		return Vector3.INF
	var t: AutochessUnit = _dive_t
	var d := _flat_dist(t)
	if d <= _attack_range() + 0.3:
		_dive = 2
		return Vector3.INF
	var goal := t.global_position
	if _blocked(t):
		var w := _inside(Vector3(o.x + _flank * (lim.x - 1.2), goal.y, goal.z))
		if Vector2(w.x - global_position.x, w.z - global_position.z).length() > 1.2:
			goal = w
	var to := goal - global_position
	to.y = 0.0
	if d > 6.0 and _time >= _hop_ready and _can_dodge() and _charges >= 1.5:
		_hop_ready = _time + 1.5
		_dodge(to.normalized(), false)
		return _dash_vel
	return _edge_safe(to.normalized() * move_speed)


static func _alive_unit(n: Variant) -> bool:
	return n != null and is_instance_valid(n) and n is AutochessUnit and not (n as AutochessUnit).is_dead


## Flanc (x local -1 / +1) où il y a le moins de mêlées ennemies.
func _quiet_flank() -> float:
	var o := _origin()
	var w := 0.0
	for n in _hostile_pool():
		var e := n as AutochessUnit
		if e != null and not e._ranged_pos():
			w += signf(e.global_position.x - o.x)
	if absf(w) < 0.5:
		return 1.0 if global_position.x >= o.x else -1.0
	return -signf(w)


## Une mêlée ennemie est-elle déjà au contact d'un de ses alliés ?
func _foes_engaged() -> bool:
	for n in _hostile_pool():
		var e := n as AutochessUnit
		if e == null or e._ranged_pos():
			continue
		for m in _teammates():
			if m != self and _flat_dist_between(e, m as Node3D) <= 3.5:
				return true
	return false


static func _flat_dist_between(a: Node3D, b: Node3D) -> float:
	var d := a.global_position - b.global_position
	return Vector2(d.x, d.z).length()


## Une mêlée ennemie (autre que [param t]) barre-t-elle la route vers [param t] ?
func _blocked(t: Node3D) -> bool:
	var a := Vector2(global_position.x, global_position.z)
	var b := Vector2(t.global_position.x, t.global_position.z)
	for n in _hostile_pool():
		var e := n as AutochessUnit
		if e == null or e == t or e._ranged_pos():
			continue
		var p := Vector2(e.global_position.x, e.global_position.z)
		if Geometry2D.get_closest_point_to_segment(p, a, b).distance_to(p) < 1.8 and p.distance_to(b) > 1.0:
			return true
	return false


## Cible de plongée : l'ennemi d'arrière-ligne le plus fragile et le moins protégé (soigneurs et mages d'abord).
func _pick_dive_target() -> AutochessUnit:
	var best: AutochessUnit = null
	var best_s := -INF
	for n in _hostile_pool():
		var e := n as AutochessUnit
		if e == null or e.is_dead or not (e.ac_role in BACK_ROLES) or e.has_status("invisible"):
			continue
		var s := 1.0 - e.hp / maxf(e.max_hp, 1.0) * 0.5 + (0.4 if e.ac_role in ["soigneur", "mage"] else 0.0) \
			- 0.8 * float(_guards(e) >= 2) - 0.05 * _flat_dist(e)
		if s > best_s:
			best_s = s
			best = e
	return best


## Mêlées du camp de [param e] à moins de PROTECT_M de lui (ses gardes).
func _guards(e: AutochessUnit) -> int:
	var n := 0
	for m in _hostile_pool():
		var g := m as AutochessUnit
		if g != null and g != e and not g._ranged_pos() and _flat_dist_between(g, e) <= PROTECT_M:
			n += 1
	return n


# --- Ciblage ---------------------------------------------------------------------------------------------------------
func pick_target(pool: Array, current = null) -> Combatant:
	var t := choose_target(pool, current)
	if t != current:
		_far_since = -1.0
	return t


## Cible (comportement « target ») : meilleur score (faiblesse, menace, achèvement, distance : AI_WEIGHTS du rôle ; bonus
## du rôle ; focus du camp +30 % à portée + 1 case), 3 mêlées au plus sur une même cible, marge de 25 % avant de quitter
## une cible vivante, sauf si elle est hors d'atteinte depuis RETARGET_AFTER s alors qu'une autre est à portée. IA naïve :
## la plus proche.
func choose_target(pool: Array, current = null) -> Combatant:
	if _dive == 1 and sub("roles", "dive") and _alive_unit(_dive_t) and _dive_t in pool:
		return _dive_t
	if not on("target"):
		return _nearest(pool)
	var cur: AutochessUnit = current as AutochessUnit if _alive_unit(current) and current in pool else null
	var ref := _score_ref(pool)
	var reach := _attack_range()
	var focus: AutochessUnit = _team_focus(pool) if sub("target", "focus") else null
	var best: AutochessUnit = null
	var best_s := -INF
	var cur_s := -INF
	for n in pool:
		var e := n as AutochessUnit
		if e == null or e.is_dead or e.has_status("invisible"):
			continue
		var s := _score(e, ref, reach, focus)
		if not _ranged_pos() and _melee_on(e) >= AutochessData.AI_MAX_MELEE_PER_TARGET:
			s *= 0.3  # 3 mêlées déjà dessus : la suivante (pas de bouchon)
		if e == cur:
			cur_s = s
		if s > best_s:
			best_s = s
			best = e
	if cur != null and best != cur:
		var stuck := _far_since >= 0.0 and _time - _far_since > AutochessData.RETARGET_AFTER and _flat_dist(best) <= reach + 0.5
		if not stuck and best_s <= cur_s * (1.0 + AutochessData.AI_RETARGET_MARGIN):
			return cur
	return best


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


## PV effectifs contre ses auto-attaques (PV × défense physique).
func _eff_hp(e: AutochessUnit) -> float:
	return e.hp * (1.0 + AutochessEffects.stat(_ctx(), e.ac_fid, "def") / AutochessEffects.DEF_SCALE)


## Références du score (maximums parmi les ennemis) : PV effectifs, dégâts récents, valeur.
func _score_ref(pool: Array) -> Dictionary:
	var r := {"hp": 1.0, "dealt": 1.0, "worth": 1.0}
	for n in pool:
		var e := n as AutochessUnit
		if e == null or e.is_dead:
			continue
		r.hp = maxf(r.hp, _eff_hp(e))
		r.dealt = maxf(r.dealt, e.recent_dealt())
		r.worth = maxf(r.worth, e.worth())
	return r


## Score de cible (plus haut = meilleur), toujours positif.
func _score(e: AutochessUnit, ref: Dictionary, reach: float, focus: AutochessUnit) -> float:
	var w: Dictionary = AutochessData.AI_WEIGHTS.get(ac_role, AutochessData.AI_WEIGHTS.combattant)
	var d := _flat_dist(e)
	var weak := 1.0 - _eff_hp(e) / maxf(float(ref.hp), 1.0)
	var threat := 0.6 * e.recent_dealt() / maxf(float(ref.dealt), 1.0) + 0.4 * e.worth() / maxf(float(ref.worth), 1.0)
	var execute := 1.0 if e.hp < e.max_hp * AutochessData.AI_EXECUTE_BELOW and d <= reach + AutochessData.CELL else 0.0
	var travel := maxf(0.0, d - reach) / maxf(move_speed, 1.0)
	var s := 1.0 + float(w.faiblesse) * weak + float(w.menace) * threat + float(w.achevement) * execute \
		- float(w.distance) * travel / 1.5 + _role_bonus(e)
	s = maxf(s, 0.05)
	if e == focus and d <= reach + AutochessData.CELL:
		s *= 1.0 + AutochessData.AI_FOCUS_BONUS
	return s


## Bonus du rôle : le tank prend l'ennemi qui frappe un allié fragile ; l'assassin, l'arrière-ligne non protégée.
func _role_bonus(e: AutochessUnit) -> float:
	match ac_role:
		"tank":
			if not sub("target", "guard"):
				return 0.0
			var v: AutochessUnit = e._player as AutochessUnit if is_instance_valid(e._player) else null
			if v != null and v != self and not v.is_dead and v.ac_side == ac_side and v.ac_role in FRAGILE \
					and _flat_dist_between(e, v) <= 4.0:
				return TANK_GUARD_BONUS
		"assassin":
			if e.ac_role in BACK_ROLES:
				return (0.9 if e.ac_role in ["soigneur", "mage"] else 0.6) - (0.8 if _guards(e) >= 2 else 0.0)
	return 0.0


## Mêlées de son camp (sans lui) qui ont déjà [param e] pour cible.
func _melee_on(e: AutochessUnit) -> int:
	var n := 0
	for m in _teammates():
		var u := m as AutochessUnit
		if u != null and u != self and not u.is_dead and u._player == e and not u._ranged_pos():
			n += 1
	return n


## Cible désignée du camp (SPEC §4.1) : recalculée toutes les AI_FOCUS_REFRESH s, la plus intéressante parmi celles que
## 2 alliés ou plus atteignent (portée + 1 case).
func _team_focus(pool: Array) -> AutochessUnit:
	var key := "ai_focus_%d" % ac_side
	var t := float(ac_arena.get("t", 0.0))
	var f: Dictionary = ac_arena.get(key, {})
	if not f.is_empty() and t < float(f.until) and (f.unit == null or _alive_unit(f.unit)):
		return f.unit
	var mates := _teammates()
	var best: AutochessUnit = null
	var best_s := -INF
	var ref := _score_ref(pool)
	for n in pool:
		var e := n as AutochessUnit
		if e == null or e.is_dead:
			continue
		var k := 0
		for m in mates:
			var u := m as AutochessUnit
			if u != null and _flat_dist_between(u, e) <= u._attack_range() + AutochessData.CELL:
				k += 1
		if k < 2:
			continue
		var s := (1.0 - e.hp / maxf(e.max_hp, 1.0)) + 0.5 * e.worth() / maxf(float(ref.worth), 1.0) + 0.15 * k
		if s > best_s:
			best_s = s
			best = e
	ac_arena[key] = {"until": t + AutochessData.AI_FOCUS_REFRESH, "unit": best}
	return best


## Portée d'attaque : celle de la couche (cases × 2 m + 0,5 ; mêlée 3,2 m), objets et traits compris.
func _attack_range() -> float:
	var ctx := _ctx()
	if ctx.is_empty():
		return super._attack_range()
	return AutochessEffects.stat(ctx, ac_fid, "reach") * 0.95


## Zones rouges de l'autre camp seulement (comportement « dodge ») ; les auto-attaques n'ont pas de zone : seuls les sorts
## s'esquivent. Lignes et cônes : de côté (vers son camp à égalité) ; cercles : hors du centre.
func _read_zones() -> void:
	if not on("dodge") or _time < _zone_check_at or is_invulnerable() or not _can_dodge():
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
		var su := src as AutochessUnit
		if su != null and (su.ac_arena != ac_arena or su.ac_side == ac_side):
			continue  # zone d'un autre plateau, ou de son camp (source tombée entre-temps)
		var iid := tg.get_instance_id()
		if _seen_zones.has(iid) or not tg.contains(global_position, radius):
			continue
		_seen_zones[iid] = true
		var left := tg.delay - tg._t
		if randf() > float(cfg.read) or left < float(cfg.react):
			continue
		var out := global_position - tg.global_position
		out.y = 0.0
		if tg.shape in ["line", "cone"]:
			var fwd := Vector3(sin(tg.rotation.y), 0.0, cos(tg.rotation.y))
			var side := fwd.cross(Vector3.UP)
			var s := out.dot(side)
			out = side * (signf(s) if absf(s) > 0.2 else (1.0 if side.dot(-_fwd()) >= 0.0 else -1.0))
		elif out.length() < 0.3:
			out = -_fwd()
		_react_dir = out.normalized()
		_react_at = _time + clampf(left - DASH_IFRAMES * 0.6, float(cfg.react), maxf(left - 0.04, 0.0))
		ac_stats["dodges"] += 1
		return


# --- Coups et sorts --------------------------------------------------------------------------------------------------
## Type du sort (AutochessData.SPELL_TYPES : zone, cible, soin, renfort, deplacement).
static func spell_type(s: Dictionary) -> String:
	return String(AutochessData.SPELL_TYPES.get(String(s.get("kind", "")), "zone"))


static func is_heal(s: Dictionary) -> bool:
	return String(s.get("kind", "")) == "heal"


## Le sort part-il maintenant ? Mana pleine (ou relance), puis selon le type (comportement « spells ») : décision gardée
## RETARGET_EVERY s (la place visée est dans _plan). IA naïve : tout de suite, sur la cible.
func wants_cast() -> bool:
	if ac_sig.is_empty():
		return false
	if not _ac_recast and not AutochessEffects.can_cast(_ctx(), ac_fid):
		_ac_mana_full_at = -1.0
		return false
	if _ac_mana_full_at < 0.0:
		_ac_mana_full_at = _time
	if _time < _plan_at:
		return bool(_plan.get("ok", false))
	_plan = _plan_for(ac_sig, _time - _ac_mana_full_at)
	_plan_at = _time + (0.0 if bool(_plan.ok) else RETARGET_EVERY)
	return bool(_plan.ok)


## Décision de sort : {ok, aim (point visé ou INF), heal_to, count (ennemis dans la zone)}.
func _plan_for(sk: Dictionary, waited: float) -> Dictionary:
	var type := spell_type(sk)
	if type == "soin":
		var h: AutochessUnit = _heal_pick(waited) if on("spells") else heal_target(true)
		return {"ok": h != null, "heal_to": h, "aim": Vector3.INF}
	if not on("spells") or not _can_target():
		return {"ok": true, "aim": Vector3.INF, "count": 0}
	var t := float(ac_arena.get("t", 0.0))
	match type:
		"renfort":
			return {"ok": t < 2.0 or _engaged_mates() >= AutochessData.AI_SUPPORT_ALLIES or waited >= HEAL_WAIT, "aim": Vector3.INF}
		"deplacement":
			var away := _flat_dist(_player) > _attack_range() + 1.0 or (ac_role in FRAGILE and hp < max_hp * AutochessData.AI_ASSASSIN_FLEE_BELOW)
			return {"ok": away or waited >= ZONE_WAIT, "aim": Vector3.INF}
	var p := best_aim(sk, _hostile_pool())
	var need := AutochessData.AI_ZONE_MIN_TARGETS if type == "zone" else 1
	if int(p.count) >= need or (int(p.count) >= 1 and waited >= ZONE_WAIT):
		return p
	if waited >= FAR_WAIT:
		return {"ok": true, "aim": Vector3.INF, "count": 0}  # rien à sa portée : sur la cible, où qu'elle soit
	return {"ok": false}


## Alliés engagés (une mêlée ennemie à moins de 3,5 m).
func _engaged_mates() -> int:
	var n := 0
	for m in _teammates():
		var u := m as AutochessUnit
		if u != null and not u.is_dead and u._melee_threat(3.5) != null:
			n += 1
	return n


## Meilleure place d'un sort parmi les ennemis [param foes] : chaque ennemi et, pour une zone visée, le milieu de chaque
## paire ; seulement les places à la portée du sort ({ok, aim, count}).
func best_aim(sk: Dictionary, foes: Array) -> Dictionary:
	var lt := LEAD_TIME if on("spells") and bool(ai.get("lead", false)) else 0.0  # coupé par défaut : perdant au banc
	var at: Array = []  # places des ennemis à l'impact (vitesse du moment)
	for f in foes:
		var c := f as Combatant
		at.append(c.global_position + Vector3(c.velocity.x, 0.0, c.velocity.z) * lt)
	var aims: Array = at.duplicate()
	if String(sk.get("kind", "")) == "ground":
		var r := maxf(float(sk.get("radius", 3.0)), 2.0)
		for i in at.size():
			for j in range(i + 1, at.size()):
				var a: Vector3 = at[i]
				var b: Vector3 = at[j]
				if a.distance_to(b) < 2.0 * r:
					aims.append((a + b) * 0.5)
	var best := {"ok": false, "count": 0, "aim": Vector3.INF}
	var best_s := -INF
	for aim: Vector3 in aims:
		var sh := spell_shape(sk, aim - global_position)
		if bool(sh.far) and not (_ranged_pos() and String(sh.shape) == "circle"):
			continue  # hors de portée (un tireur pose son tourbillon ou son cône comme une zone, voir spell_shape)
		var n := 0
		var has_t := false
		for i in foes.size():
			var c := foes[i] as Combatant
			if c != null and not c.is_dead and shape_has(sh, at[i], c.radius * 0.5):
				n += 1
				has_t = has_t or c == _player
		if n == 0:
			continue
		var s := n * 10.0 + (3.0 if has_t else 0.0) - (aim - global_position).length() * 0.05
		if s > best_s:
			best_s = s
			best = {"ok": true, "count": n, "aim": aim}
	return best


## Forme d'un sort lancé vers [param to] (depuis l'unité) : {far, at, yaw, shape, radius / length / width / angle}.
## Zone visée : posée au point (à la portée du sort) ; trait / projectile : ligne ; tourbillon : cercle autour de soi ; cône.
## Un sort hors de portée (far) est posé sur la cible (après l'attente).
func spell_shape(sk: Dictionary, to: Vector3) -> Dictionary:
	to.y = 0.0
	var kind := String(sk.get("kind", "cone"))
	var r := float(sk.get("radius", 3.0))
	var rng := float(sk.get("range", 0.0))
	var dist := to.length()
	var far := dist > skill_reach(sk) + 0.5
	var yaw := atan2(to.x, to.z) if dist > 0.01 else rotation.y
	if kind == "ground" or (far and not kind in ["bolt", "line", "fan", "dash", "blink"]):
		return {"far": far, "at": global_position + to.limit_length(maxf(rng, dist if far else 4.0)), "yaw": yaw,
			"shape": "circle", "radius": maxf(r, 2.0)}
	if kind in ["bolt", "line", "fan", "blink"] or rng > r + 1.0:
		return {"far": far, "at": global_position, "yaw": yaw, "shape": "line", "length": maxf(maxf(rng, r), dist + 1.0),
			"width": 1.4 if kind != "line" else maxf(1.4, minf(r, 3.0))}
	if float(sk.get("arc", 120.0)) >= 359.0 or kind == "spin":
		return {"far": far, "at": global_position, "yaw": yaw, "shape": "circle", "radius": r}
	return {"far": far, "at": global_position, "yaw": yaw, "shape": "cone", "radius": r, "angle": float(sk.get("arc", 120.0))}


## Le point [param p] est-il dans la forme [param sh] (même règle que Telegraph.contains) ?
static func shape_has(sh: Dictionary, p: Vector3, margin := 0.0) -> bool:
	var d: Vector3 = p - (sh.at as Vector3)
	var yaw := float(sh.yaw)
	var lx := d.x * cos(yaw) - d.z * sin(yaw)
	var lz := d.x * sin(yaw) + d.z * cos(yaw)
	var flat := Vector2(lx, lz).length()
	match String(sh.shape):
		"line":
			return absf(lx) <= float(sh.width) * 0.5 + margin and lz >= -margin and lz <= float(sh.length) + margin
		"cone":
			if flat > float(sh.radius) + margin:
				return false
			return rad_to_deg(absf(atan2(lx, lz))) <= float(sh.angle) * 0.5 or flat < 1.0
	return flat <= float(sh.radius) + margin


## Allié à soigner, IA naïve : le plus bas en part de PV, blessé ([param any] : même sans blessure, le plus bas).
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


## Allié à soigner (comportement « spells ») : le plus bas à portée (soins déjà en route comptés), tout de suite s'il est
## sous HEAL_URGENT ou s'il lui manque assez de PV pour tout le soin ; après HEAL_WAIT s, s'il est sous AI_HEAL_BELOW.
func _heal_pick(waited: float) -> AutochessUnit:
	var want := minf(heal_frac(ac_sig, stars()) * 0.8, 0.5)
	var rng := maxf(_attack_range(), HEAL_RANGE_MIN) + 1.0
	var low: AutochessUnit = null
	var lf := INF
	for n in _teammates():
		var u := n as AutochessUnit
		if u == null or u.is_dead or _flat_dist(u) > rng:
			continue
		var f := u.hp / maxf(u.max_hp, 1.0) + u.incoming_heal()
		if f < lf:
			lf = f
			low = u
	if low == null:
		return null
	if lf < HEAL_URGENT or 1.0 - lf >= want:
		return low
	if waited >= HEAL_WAIT and lf < AutochessData.AI_HEAL_BELOW:
		return low
	return null


## Part des PV max rendue par le soin [param s] à [param st] étoiles.
static func heal_frac(s: Dictionary, st: int) -> float:
	return clampf(float(s.get("heal", 0.25)), 0.1, 0.4) * AutochessData.spell_mult(st)


var _heal_in := 0.0
var _heal_in_until := 0.0


## Soin déjà en route vers l'unité (part des PV max).
func incoming_heal() -> float:
	return _heal_in if _time < _heal_in_until else 0.0


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


## Sort à mana pleine (place décidée par wants_cast), 2e sort d'une ★3, sinon auto-attaque de l'arme.
func _start_attack() -> void:
	if not _can_target():
		return
	var ctx := _ctx()
	var sk: Dictionary = {}
	var mode := "auto"
	var heal_to: AutochessUnit = null
	var aim := Vector3.INF
	if not _ac_chain_next.is_empty():
		sk = _ac_chain_next
		_ac_chain_next = {}
		mode = "chain"
		ac_stats["chains"] = int(ac_stats.chains) + 1
		if is_heal(sk):
			heal_to = _heal_pick(INF) if on("spells") else null
		elif on("spells"):
			aim = best_aim(sk, _hostile_pool()).aim
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
		if _alive_unit(_plan.get("heal_to")):
			heal_to = _plan.heal_to
		aim = _plan.get("aim", Vector3.INF)
		_plan = {}
		_plan_at = -10.0
	if not sk.is_empty() and is_heal(sk) and heal_to == null:
		heal_to = heal_target(true)
	_begin_action(sk, mode, heal_to, aim)


func _begin_action(sk: Dictionary, mode: String, heal_to: AutochessUnit, aim := Vector3.INF) -> void:
	var act: Dictionary = sk if not sk.is_empty() else auto_step
	if sk.is_empty():
		_combo_i += 1
		_ac_last_auto = _time
	_ac_last_act = _time
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
	var at_p := aim
	if at_p == Vector3.INF:
		var tv := target.velocity
		tv.y = 0.0
		at_p = target.global_position + tv * delay * float(cfg.lead) * (0.0 if heal_to != null else 1.0)
	var to := at_p - global_position
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
		if heal_to != null:
			heal_to._heal_in = heal_frac(sk, stars()) * (CHAIN_FACTOR if mode == "chain" else 1.0)
			heal_to._heal_in_until = heal_to._time + delay + 0.3
		return
	var sh := spell_shape(sk, to)
	var props := {"delay": delay, "damage": spell_damage(mode == "chain"), "source": self, "crit": false, "shape": sh.shape}
	for k in ["radius", "length", "width", "angle"]:
		if sh.has(k):
			props[k] = sh[k]
	if String(sk.get("kind", "")) == "dash":
		_pending_dash = _edge_safe(to.normalized() * minf(to.length(), maxf(float(sk.get("range", 0.0)), 6.0)), 6.0)
	var type := spell_type(sk)
	_tg_type = "zone" if type == "zone" else ("line" if type == "cible" else "")
	if _tg_type != "":
		ac_stats[_tg_type + "_casts"] += 1
	_cur = {"hit_fx": hit_fx, "at": sh.at, "yaw": float(sh.yaw), "radius": float(sk.get("radius", 3.0))} if ac_shown else {}
	_telegraph = Telegraph.spawn(self, sh.at, float(sh.yaw), props)
	_telegraph.visible = ac_shown


var _tg_type := ""  # type de la dernière zone posée (zone / line) : ennemis touchés par sort (banc d'essai)


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
			var amount := AutochessEffects.hp_max(ctx, h.ac_fid) * heal_frac(sk, stars()) * (CHAIN_FACTOR if mode == "chain" else 1.0)
			var before := AutochessEffects.hp(ctx, h.ac_fid)
			var asked := amount * float(AutochessEffects.unit(ctx, ac_fid).get("sheet", {}).get("spell_power", 1.0)) \
				* AutochessEffects.heal_mult(ctx, h.ac_fid)
			ac_stats["heals"] = int(ac_stats.heals) + 1
			ac_dir.on_effects(ac_arena, AutochessEffects.spell_heal(ctx, ac_fid, h.ac_fid, amount))
			var got := AutochessEffects.hp(ctx, h.ac_fid) - before
			ac_stats["heal_req"] = float(ac_stats.heal_req) + asked
			ac_stats["heal_lost"] = float(ac_stats.heal_lost) + maxf(0.0, asked - got)
			h._heal_in = 0.0
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


## Fin du coup écourtée (ClassRival : esquive ou saut après l'impact) : ici la fin de l'animation seulement, sans bond.
func _cancel_after_hit() -> void:
	_set_state("chase")
	_end_of_hit()


## Esquive : jamais pendant la préparation d'un sort (la mana est dépensée), jamais hors du plateau (le long du bord).
func _dodge(dir: Vector3, iframes := true) -> void:
	if _state == "attack" and not _hit_done and String(_ac.get("mode", "auto")) != "auto":
		return
	dir.y = 0.0
	if dir.length() < 0.01:
		dir = -_fwd()
	var safe := _edge_safe(dir.normalized(), 3.6)
	if safe.length() < 0.3:
		var side := dir.normalized().cross(Vector3.UP)
		var a := _edge_safe(side, 3.6)
		var b := _edge_safe(-side, 3.6)
		safe = a if a.length() >= b.length() else b
	if safe.length() > 0.05:
		dir = safe
	super._dodge(dir, iframes)


## Saut : le long du bord près d'un bord.
func _jump(dir: Vector3) -> void:
	super._jump(_edge_safe(dir, 3.6))


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
	if src._tg_type != "":
		src.ac_stats[src._tg_type + "_hits"] += 1
	var kind := "magic" if String(src.ac_sig.get("dmg_type", "phys")) in ["mag", "magic"] else "phys"
	ac_dir.on_effects(ac_arena, AutochessEffects.spell_hit(_ctx(), src.ac_fid, ac_fid, amount, {"kind": kind}))


## Soins : seulement par la couche (spell_heal), jamais directement.
func heal(_amount: float) -> void:
	pass
