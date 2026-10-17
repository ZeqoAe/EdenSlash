class_name Moba
extends RefCounted
## Les Deux Voies (lot MB-C, rapport conception/benchmark/R_MB_C.md) : état d'une partie, sans scène (comme Assault et
## Autochess) : options, temps, structures détruites, sbires tués, vainqueur, journal des événements, et les règles pures
## (vagues, protections des structures, décision à la fin au temps). Le directeur de scène (MobaDirector) lui donne les
## événements et lit ses décisions. Mode d'équipes scellé du socle TeamMatch (fiche « moba », piège n° 1 de R_MODE0 : ne pose
## jamais Duel.active ni Royale.active).
##
##   Moba.launch("warrior", {"diff": 2})          # puis world.tscn ; RunDirector monte MobaDirector (TeamMatch.mount)
##   Moba.args_options(OS.get_cmdline_user_args()) # lancement direct : world.tscn -- --moba [--moba-…]
##
## Options (TeamMatch.spec, posées par launch) : diff (0-3, les deux équipes) ou diff_allies / diff_foes ; heroes (« all » :
## 8 héros ; « none » : vagues seules, mesures et test_mb_lanes ; « watch » : 8 IA, le joueur regarde) ; power ([bleu, rouge] :
## force des sbires, essais « un camp × 1,2 ») ; seed ; speed (Engine.time_scale, mesures) ; until (s : fin de la mesure) ;
## allies / foes (classes imposées) ; role (poste du joueur, indice de MobaData.ROLES) ; perf (mesure du coût de l'image).

const DIRECTOR := "res://scripts/core/moba_director.gd"
const ZONE := "rainbowfall"

static var active := false
static var opts: Dictionary = {}
static var t := 0.0
static var winner := -1
static var how := ""  # « core » (Cœur détruit), « time » (fin au temps), « abandon »
## Structures détruites PAR chaque camp ([bleu, rouge]) et sbires tués par camp.
static var structures_down := [0, 0]
static var minion_kills := [0, 0]
static var hero_kills := [0, 0]
## Une ligne par événement marquant : {t, type, side, …} (tour tombée, Cœur, élimination).
static var events: Array = []


# --- partie ------------------------------------------------------------------------------------

## Prépare une partie et pose la fiche « moba » de TeamMatch ; world.tscn la monte ensuite (RunDirector.start).
static func launch(cid: String, o := {}) -> void:
	MobaData.ensure_rules()
	Run.start(cid)  # Profile.begin_run : copie du profil, rien n'est écrit tant que la partie dure (fiche : save = faux)
	Run.zone_id = String(o.get("zone", ZONE))
	Profile.equipped = {}  # mode scellé : rien du compte en partie (rendu par finish)
	Profile.inventory = []
	Profile.gold = 0
	Profile.keys = 0
	Profile.bag = {}
	PvpCaps.reset_stats()
	Run.skills = MobaData.start_skills(cid)
	Run.chains = {}
	var spec := {"director": DIRECTOR}
	spec.merge(o, true)
	TeamMatch.begin("moba", 2, spec)
	reset()
	active = true
	opts = spec.duplicate(true)
	Run.changed.emit()


static func reset() -> void:
	active = false
	opts = {}
	t = 0.0
	winner = -1
	how = ""
	structures_down = [0, 0]
	minion_kills = [0, 0]
	hero_kills = [0, 0]
	events = []


## Fin de partie : TeamMatch.end() d'abord (piège 11 de R_MODE0), puis le profil du joueur rendu tel qu'avant la partie.
static func finish() -> void:
	TeamMatch.end()
	active = false
	Engine.time_scale = 1.0
	Run.active = false
	Profile.in_run = false
	Profile.reload_keep_records()
	Profile.gold = 0
	Profile.keys = 0
	Profile.bag = {}
	Profile._lobby_view()
	Profile.save_profile()


## Options d'un lancement direct (world.tscn -- --moba …) : --moba-diff=0..3 (les deux équipes) ou --moba-allies=N /
## --moba-foes=N, --moba-heroes=all|none|watch, --moba-power=1.2,1.0, --moba-seed=N, --moba-speed=N, --moba-until=S,
## --moba-role=0..3, --moba-perf.
static func args_options(args: PackedStringArray) -> Dictionary:
	var o := {}
	for a in args:
		if a.begins_with("--moba-diff="):
			o["diff"] = int(a.get_slice("=", 1))
		elif a.begins_with("--moba-allies="):
			o["diff_allies"] = int(a.get_slice("=", 1))
		elif a.begins_with("--moba-foes="):
			o["diff_foes"] = int(a.get_slice("=", 1))
		elif a.begins_with("--moba-heroes="):
			o["heroes"] = a.get_slice("=", 1)
		elif a.begins_with("--moba-power="):
			o["power"] = Array(a.get_slice("=", 1).split(",")).map(func(x): return float(x))
		elif a.begins_with("--moba-seed="):
			o["seed"] = int(a.get_slice("=", 1))
		elif a.begins_with("--moba-speed="):
			o["speed"] = float(a.get_slice("=", 1))
		elif a.begins_with("--moba-until="):
			o["until"] = float(a.get_slice("=", 1))
		elif a.begins_with("--moba-role="):
			o["role"] = int(a.get_slice("=", 1))
		elif a.begins_with("--moba-stop="):
			o["stop"] = a.get_slice("=", 1)
		elif a == "--moba-perf":
			o["perf"] = true
		elif a.begins_with("--moba-tune="):
			var tn := {}
			for kv in a.get_slice("=", 1).split(","):
				tn[kv.get_slice(":", 0)] = float(kv.get_slice(":", 1))
			o["tune"] = tn
	return o


static func opt(key: String, fallback: Variant = null) -> Variant:
	return opts.get(key, fallback)


## Réglage d'essai [param key] (option « tune », mesures de calibrage : --moba-tune=t1_hp:80,struct:1.5) ; [param fallback] sinon.
static func tune(key: String, fallback: float) -> float:
	return float((opts.get("tune", {}) as Dictionary).get(key, fallback))


## Force des sbires du camp [param side] (options « power » : [bleu, rouge]).
static func power(side: int) -> float:
	var p: Array = opts.get("power", [1.0, 1.0])
	return float(p[side]) if side < p.size() else 1.0


static func note(type: String, side: int, extra := {}) -> void:
	var e := {"t": snappedf(t, 0.1), "type": type, "side": side}
	e.merge(extra, true)
	events.append(e)


# --- règles pures -----------------------------------------------------------------------------------

## Dégâts réellement pris par une structure (points) : [param units] unités × 100, × protection sans sbire ennemi proche,
## × garde des T1 avant 4:00 ; 0 si elle est invulnérable.
static func structure_damage(units: float, kind: String, tier: int, minion_near: bool, invulnerable: bool, at: float) -> float:
	if invulnerable:
		return 0.0
	var d := units * 100.0
	if not minion_near:
		d *= tune("protect", MobaData.PROTECT_MULT)
	if kind == "tower" and tier == 1 and at < MobaData.T1_GUARD_UNTIL:
		d *= MobaData.T1_GUARD_MULT
	return d


## PV (points) d'une structure.
static func structure_hp(kind: String, tier: int) -> float:
	var t2 := tune("t2_hp", float(MobaData.TOWER.hp_t2)) * 100.0
	if kind == "core":
		return t2 * float(MobaData.CORE.hp_mult)
	return (tune("t1_hp", float(MobaData.TOWER.hp_t1)) if tier == 1 else t2 / 100.0) * 100.0


## Multiplicateur d'un tir de tour sur un héros touché [param streak] fois de suite (1 au premier tir).
static func tower_streak(streak: int) -> float:
	return minf(1.0 + float(MobaData.TOWER.streak) * maxi(streak - 1, 0), float(MobaData.TOWER.streak_max))


## Décision à la fin au temps : plus de structures détruites, puis Cœur le moins entamé ([param core_hp] : part restante
## [bleu, rouge]), puis or total ([param gold]), puis sbires tués ; -1 si tout est égal.
static func decide(core_hp: Array, gold: Array = [0, 0]) -> int:
	if structures_down[0] != structures_down[1]:
		return 0 if structures_down[0] > structures_down[1] else 1
	if absf(float(core_hp[0]) - float(core_hp[1])) > 0.001:
		return 0 if float(core_hp[0]) > float(core_hp[1]) else 1
	if int(gold[0]) != int(gold[1]):
		return 0 if int(gold[0]) > int(gold[1]) else 1
	if minion_kills[0] != minion_kills[1]:
		return 0 if minion_kills[0] > minion_kills[1] else 1
	return -1


## Résumé d'une ligne (mesures, --auto-quit).
static func summary() -> String:
	return "vainqueur %s (%s) à %d:%02d ; structures %d-%d ; sbires %d-%d ; éliminations %d-%d" % [
		["bleu", "rouge"][winner] if winner >= 0 else "aucun", how, int(t) / 60, int(t) % 60, structures_down[0], structures_down[1],
		minion_kills[0], minion_kills[1], hero_kills[0], hero_kills[1]]
