class_name SurvivorDirector
extends RefCounted
## Déroulement d'un Survivant (lot S4, SPEC §1, §6, §8.2-8.3, corrigé par DECISIONS_JOUEUR) : 20 minutes sur une seule
## carte, sans rage de carte ; la pression vient de la courbe des monstres par minute. Créé par RunDirector.start quand
## Survivor.active (variable `sv` du directeur).
##
## Chronologie (timeline()) : gardiens à 5:00, 10:00 et 15:00 (annoncés 10 s avant), portail du boss ouvert à 15:00
## (entrée en avance permise), « le boss arrive dans 1:00 » et horde finale à 19:00, entrée forcée dans l'arène à 20:00.
## Arène : boss de la zone à PV FIXES (boss_hp × palier × Menace, jamais d'après le héros), rage du boss après
## boss_rage_at (4:00), renforts du directeur. Boss vaincu = victoire ; seconde chute = défaite (world.gd).
##
## Monstres : spawn_plan(t) donne la composition voulue à l'instant t (vivants au plus, rythme des meutes, vagues,
## élites, niveau, PV et dégâts) ; update_spawns l'applique avec les outils du directeur (anneau, meutes). Interface
## étroite pour le composant de spawn de P15 : il n'aura qu'à lire spawn_plan(t).
##
## Convention des crochets (S1) : une méthode qui remplace un comportement de la Survie renvoie vrai si elle l'a pris
## en charge (faux : le directeur fait comme en Survie).

## Coffres du Survivant (SPEC §6.2) : nom, apparence (ProcMap.CHEST_LOOKS : 0 simple, 1 ouvragé, 2 doré), prix
## (× RunDirector.chest_price) et emplacement visé. Le contenu vient de SurvivorCards.chest_cards(id) (lot S3).
const BOXES := {
	"sv_weapon": {"name": "Coffre d'arme", "look": 0, "price": 1.0, "slot": "weapon"},
	"sv_head": {"name": "Coffre de tête", "look": 0, "price": 1.0, "slot": "head"},
	"sv_chest": {"name": "Coffre de torse", "look": 0, "price": 1.0, "slot": "chest"},
	"sv_legs": {"name": "Coffre de jambes", "look": 0, "price": 1.0, "slot": "legs"},
	"sv_gloves": {"name": "Coffre de gants", "look": 0, "price": 1.0, "slot": "gloves"},
	"sv_boots": {"name": "Coffre de bottes", "look": 0, "price": 1.0, "slot": "boots"},
	"sv_back": {"name": "Coffre de cape", "look": 0, "price": 1.0, "slot": "back"},
	"sv_necklace": {"name": "Coffre de collier", "look": 0, "price": 1.0, "slot": "necklace"},
	"sv_ring": {"name": "Coffre de bague", "look": 0, "price": 1.0, "slot": "ring"},
	"sv_spell": {"name": "Coffre de sort", "look": 1, "price": 1.2},
	"sv_gold": {"name": "Coffre doré", "look": 2, "price": 1.5},
}
## Les 30 coffres de la carte : 2 par emplacement d'armure et de bijou (16), 2 d'arme, 6 de sort, 6 dorés.
const LAYOUT := ["sv_head", "sv_head", "sv_chest", "sv_chest", "sv_legs", "sv_legs", "sv_gloves", "sv_gloves",
	"sv_boots", "sv_boots", "sv_back", "sv_back", "sv_necklace", "sv_necklace", "sv_ring", "sv_ring",
	"sv_weapon", "sv_weapon", "sv_spell", "sv_spell", "sv_spell", "sv_spell", "sv_spell", "sv_spell",
	"sv_gold", "sv_gold", "sv_gold", "sv_gold", "sv_gold", "sv_gold"]
## Coffres hors carte, même mécanisme : celui du gardien vaincu, l'enclume (+2 sur une pièce portée).
const GUARDIAN_BOX := "sv_guardian"
const ANVIL_BOX := "sv_anvil"

## Niveau maximal du héros, des monstres et du butin (la puissance des pièces suit le héros, plafonnée à 90).
const MAX_LEVEL := 90
const GUARDIAN_WARN := 10.0  # annonce d'un gardien, secondes avant
const GUARDIAN_DIST := 18.0  # un gardien surgit à cette distance du héros
const GUARDIAN_GOLD := [60, 15]  # or d'un gardien vaincu : base + par niveau (comme un géant)
const PORTAL_MSG_DELAY := 5.0  # l'annonce du portail suit celle du 3e gardien (même minute)
const FINAL_HORDE_AT := 1140.0  # 19:00 : « le boss arrive dans 1:00 », densité maximale
const FINAL_HORDE := 30  # monstres de la horde finale, en anneau autour du héros
const CHALLENGE_GOLD := [40, 12]  # stèle du défi réussie : or (base + par niveau), et un coffre doré gratuit
const MSG_THROTTLE := 3.0  # secondes entre deux messages répétés (portail fermé, enclume vide)
const POWER_SAMPLE := 2.0  # s entre deux mesures de l'équipement de la run (puissance des monstres)
const GUARDIAN_CALM := 0.5  # plafond de vivants × pendant le combat d'un gardien (lot SVX-1)

var d: RunDirector
var _next := 0  # prochain événement de la chronologie
var _events: Array = []
var _forced := false  # entrée dans l'arène lancée (en avance ou forcée)
var arena_at := -1.0  # instant de l'entrée dans l'arène (temps de carte) ; -1 avant
var arena_forced := false  # entrée forcée à 20:00 (sinon : en avance, bonus « Audace » du lot S6)
var boss_hp := 0.0  # PV du boss posés à l'entrée (avant la Menace, appliquée en différé)
var guardians: Array = []  # {n, t, level, hp, ttk} : un par gardien apparu
var _minutes: Array = []  # journal : une ligne par minute de carte
var _minute := 0
var _pack_t := 3.0
var _wave_t := Survivor.FIRST_WAVE
var _elite_t := 0.0
var _despawn_t := 2.0
var _wave_hard := false
var _challenges: Array = []  # stèles du défi en cours : {pos, elites}
var _msg_at := {}  # message -> instant du dernier affichage (anti-répétition)
var _base_context: Callable  # contexte de la carte du directeur (journal de run)
var power := Vector2.ONE  # coefficients lissés [PV, dégâts] des monstres ordinaires (équipement de la run)
var gear_idx := 0.0  # indice d'équipement de la run (dernière mesure)
var _power_t := 0.0
var events: SurvivorEvents  # (lot SVX-3) élites lisibles, gardiens variés, Nuée (7:30) et Chasseur (12:30)


func _init(director: RunDirector) -> void:
	d = director
	_events = timeline()
	# journal de run : le contexte de la carte (posé par RunDirector.start juste avant) reçoit en plus nos champs (méthode
	# liée plutôt qu'une fonction anonyme : une variable statique qui garde une fonction anonyme fait planter la sortie)
	_base_context = RunJournal.context
	RunJournal.context = _journal_context
	# palier (lot S8) : Menace de départ (après Menace.reset du directeur), résurrections
	Menace.level = maxi(Menace.level, int(Survivor.tier_rule("menace")))
	if d.world and "revives_left" in d.world:
		d.world.revives_left = int(Survivor.tier_rule("revives"))
	# horde (lot SVX-1) : places d'attaque (remises à 0 par Survivor.reset / finish)
	Monster.attacking = 0
	Monster.attack_slots = int(spawn_plan(0.0).attack_slots)


## Règle du profil « survivor » (ModeRules, modifiable en mode dev) ; [param fallback] si la clé n'y est pas.
static func r(key: String, fallback: Variant) -> Variant:
	return ModeRules.rule(key, fallback, "survivor")


## Multiplicateur du palier en cours (monstres, gardiens et boss : PV et dégâts, SPEC §8.5).
static func palier_mult() -> float:
	var m: Array = r("palier_mult", [1.0])
	return float(m[clampi(Survivor.palier - 1, 0, m.size() - 1)])


## Chronologie de la run : événements datés (secondes de carte), dans l'ordre. id : guardian_warn, guardian,
## portal, final_horde, boss ; n : rang du gardien.
static func timeline() -> Array:
	var out: Array = []
	for i in Survivor.GUARDIAN_TIMES.size():
		out.append({"t": float(Survivor.GUARDIAN_TIMES[i]) - GUARDIAN_WARN, "id": "guardian_warn", "n": i})
		out.append({"t": float(Survivor.GUARDIAN_TIMES[i]), "id": "guardian", "n": i})
	out.append({"t": Survivor.BOSS_OPEN_AT + PORTAL_MSG_DELAY, "id": "portal"})
	out.append({"t": FINAL_HORDE_AT, "id": "final_horde"})
	out.append({"t": Survivor.RUN_TIME, "id": "boss"})
	out.sort_custom(func(a, b): return float(a.t) < float(b.t))
	return out


## Composition voulue à [param t] secondes de carte (SPEC §8.2) : vivants au plus, rythme et taille des meutes, vagues,
## élites (0 : aucune), niveau de base, PV et dégâts (× palier), horde finale. Interpolée sur les 20 minutes ; au-delà
## (renforts de l'arène) elle reste celle de 20:00.
static func spawn_plan(t: float) -> Dictionary:
	var mins := clampf(t / 60.0, 0.0, Survivor.RUN_TIME / 60.0)
	var k := mins / (Survivor.RUN_TIME / 60.0)
	var final := t >= FINAL_HORDE_AT
	var pk := lerpf(1.0, palier_mult(), clampf(t / Survivor.PALIER_RAMP, 0.0, 1.0))  # (installé sur 5 min, S8)
	var pack_every: Array = r("pack_every", Survivor.PACK_EVERY)
	var pack_size: Array = r("pack_size", Survivor.PACK_SIZE)
	var wave_every: Array = r("wave_every", Survivor.WAVE_EVERY)
	var elite_every: Array = r("elite_every", Survivor.ELITE_EVERY)
	var pace: Array = r("spawn_pace", Survivor.SPAWN_PACE)
	var elites_from := float(r("elites_from", Survivor.ELITES_FROM))
	var opening: Array = r("opening", Survivor.OPENING)
	var slots: Array = r("attack_slots", Survivor.ATTACK_SLOTS)
	var ramp := clampf(t / maxf(float(opening[2]), 1.0), 0.0, 1.0)
	var ease := lerpf(float(opening[0]), 1.0, ramp)
	var ease_hp := lerpf(float(opening[1]), 1.0, ramp)
	var horde := SurvivorFavors.mult("horde")  # (lot SVX-4) faveur « Horde affamée »
	return {
		"minute": mins,
		# (la faveur ne dépasse jamais la horde finale : coût mesuré au lot SVX-1 jusqu'à 290 vivants)
		"alive_max": roundi(minf((float(r("alive_final", Survivor.ALIVE_FINAL)) if final else lerpf(float(r("alive_start", Survivor.ALIVE[0])), float(r("alive_end", Survivor.ALIVE[1])), k)) * horde,
			maxf(float(r("alive_final", Survivor.ALIVE_FINAL)), float(r("alive_end", Survivor.ALIVE[1]))))),
		"pack_every": float(pack_every[1]) if final else lerpf(float(pack_every[0]), float(pack_every[1]), k),
		"pack_size": roundi(lerpf(float(pack_size[0]), float(pack_size[1]), 1.0 if final else k) * horde),
		"wave_every": lerpf(float(wave_every[0]), float(wave_every[1]), k),
		"pace": lerpf(float(pace[0]), float(pace[1]), k),
		"elite_every": 0.0 if t < elites_from else float(elite_every[1] if t >= Survivor.BOSS_OPEN_AT else elite_every[0]),
		"level": clampi(roundi(1.0 + float(r("level_per_min", Survivor.LEVEL_PER_MIN)) * mins), 1, MAX_LEVEL),
		"hp_mult": float(r("hp0", Survivor.HP0)) * pow(float(r("hp_growth", Survivor.HP_GROWTH)), mins) * pk * ease_hp,
		"atk_mult": float(r("atk0", Survivor.ATK0)) * pow(float(r("atk_growth", Survivor.ATK_GROWTH)), mins) * pk * ease,
		"hard": t >= float(r("hard_waves_from", Survivor.HARD_WAVES_FROM)),
		"final": final,
		"attack_slots": roundi(lerpf(float(slots[0]), float(slots[1]), 1.0 if final else k)),
	}


## Bande d'indice d'équipement attendue à [param t] secondes de carte (Survivor.POWER_BAND, une ligne toutes les 5 min,
## interpolée) : [bas, haut].
static func power_band(t: float) -> Array:
	var band: Array = r("power_band", Survivor.POWER_BAND)
	var x := clampf(t / 300.0, 0.0, float(band.size() - 1))
	var i := mini(floori(x), band.size() - 2)
	var f := x - i
	return [lerpf(float(band[i][0]), float(band[i + 1][0]), f), lerpf(float(band[i][1]), float(band[i + 1][1]), f)]


## Coefficients visés [PV, dégâts] des monstres ordinaires pour un indice d'équipement de la run [param index] à
## [param t] : MonsterScaling.target face à la bande de la minute, bornés par power_hp / power_atk (plus étroits que
## ceux de la Survie : les pièces de la run SONT la progression attendue).
static func power_target(index: float, t: float) -> Vector2:
	var k := MonsterScaling.target(index, power_band(t))
	var hp: Array = r("power_hp", Survivor.POWER_HP)
	var atk: Array = r("power_atk", Survivor.POWER_ATK)
	return Vector2(clampf(k.x, float(hp[0]), float(hp[1])), clampf(k.y, float(atk[0]), float(atk[1])))


## Message d'ouverture de la carte.
func start_message() -> String:
	var tier := "" if Survivor.palier <= 1 else " · palier %s : %s" % [Survivor.numeral(Survivor.palier), String(Survivor.tier_rule("name"))]
	return "%s · Survivant%s\nTiens 20 minutes : le boss arrive à 20:00" % [String(d.zone.get("name", "")), tier]


## Chaque image, en exploration comme dans l'arène : chronologie, défis, journal minute par minute.
func update(delta: float) -> void:
	if not SurvivorSave.pending.is_empty() and d.player != null and d.map != null:
		SurvivorSave.apply(self)  # (lot SVX-4, SV-Q4) partie reprise : temps, héros, gardiens, carte
	if not _cam_done and d.world != null and d.world.get("rig") != null:
		_cam_done = true  # (lot SVX-1) caméra plus haute : la horde se voit autour du héros
		d.world.rig.distance = minf(28.0, float(d.world.rig.distance) * Survivor.CAM_ZOOM)
		RenderingServer.global_shader_parameter_set("hero_fade", Survivor.FOLIAGE_FADE)  # décor tramé autour du héros
		_ensure_height()
	_outline_t -= delta
	if _outline_t <= 0.0 and d.player != null:
		_outline_t = 1.0  # (un modèle rhabillé par une pièce perd son contour : remis chaque seconde)
		HeroOutline.apply(d.player.model)
	_sample_density(delta)
	_sample_minute()
	SurvivorRewards.track(self)  # suivi pour les récompenses de fin (S6)
	if events == null:
		events = SurvivorEvents.new(self)
	events.tick()
	_update_endless(delta)
	if d.player != null and d.player.is_dead != _was_dead:
		_was_dead = d.player.is_dead
		if _was_dead:  # (lot SVX-4, mesures) ce qui a fait tomber le héros : dégâts subis par source depuis le début
			var c := RunJournal.counters
			print("[sv] chute à %s (%s) · subis monstres %d · élites %d · boss %d · autres %d · pv_max %d" % [clock(d.time), d.state,
				roundi(float(c.get("dmg_taken_normal", 0.0))), roundi(float(c.get("dmg_taken_elite", 0.0))), roundi(float(c.get("dmg_taken_boss", 0.0))),
				roundi(float(c.get("dmg_taken_autre", 0.0))), roundi(d.player.max_hp)])
	if not is_equal_approx(Survivor.speed, 1.0) and is_equal_approx(Engine.time_scale, 1.0) and not d.player.autoplay:
		Engine.time_scale = Survivor.speed  # (lot SVX-4, SV-A1) vitesse du jeu (reposée après un arrêt sur image)
	if d.state != "explore":
		return
	_update_challenges()
	_update_guardian_shop()
	if d.player.autoplay:
		_pilot_shop()
		_pilot_push()
	while _next < _events.size() and d.time >= float(_events[_next].t):
		var ev: Dictionary = _events[_next]
		if ev.id == "boss" and not _can_force():
			return  # héros à terre : l'entrée forcée attend qu'il se relève
		_next += 1
		_fire(ev)


func _fire(ev: Dictionary) -> void:
	match String(ev.id):
		"guardian_warn":
			d.message.emit("Un gardien approche !\nIl surgit dans %d secondes" % int(GUARDIAN_WARN), 3.0)
			SurvivorHud.caption("Grondement : un gardien approche")
		"guardian":
			spawn_guardian(int(ev.n))
			if int(ev.n) == Survivor.GUARDIAN_TIMES.size() - 1 and bool(Survivor.tier_rule("twin")):
				spawn_guardian(int(ev.n))  # palier V : deux gardiens à 15:00
		"portal":
			d.dungeon_found = true  # la trace mène au portail
			d.message.emit("Le portail du boss est ouvert !\nEntre quand tu veux : le boss arrive à 20:00", 4.0)
		"final_horde":
			d.message.emit("Le boss arrive dans 1:00 !\nLa horde se déchaîne", 4.0)
			SurvivorHud.caption("Cor de guerre : le boss arrive dans 1:00")
			var sp := _squads()
			if sp != null:
				sp._event("encircle", d.time / 60.0, false)  # encerclement annoncé (cercles au sol), rôles mélangés
				sp.wave(false, d.time / 60.0)  # puis une ruée ou une tenaille
			else:
				_ring(FINAL_HORDE, monster_level(0), 16.0)
		"boss":
			enter_arena(true)


## L'entrée forcée attend un héros debout (la résurrection prend 3 s).
func _can_force() -> bool:
	return d.player != null and not d.player.is_dead


## Entrée dans l'arène du boss (en avance au portail, ou forcée à 20:00) : une seule fois.
func enter_arena(forced: bool) -> void:
	if _forced or d.state != "explore":
		return
	_forced = true
	arena_forced = forced
	if forced:
		d.message.emit("Le boss t'attend !", 2.0)
	print("[sv] entrée dans l'arène à %s (%s), niveau %d" % [clock(d.time), "forcée" if forced else "en avance", d.player.level])
	ScreenFade.run(d.get_tree(), d._enter_arena)


## Vrai quand le portail du boss est ouvert (15:00).
func portal_open() -> bool:
	return d.time >= Survivor.BOSS_OPEN_AT


## Secondes d'avance à l'entrée de l'arène (0 : forcée ou pas encore entré) ; bonus « Audace » (lot S6).
func early_seconds() -> float:
	if arena_at < 0.0 or arena_forced:
		return 0.0
	return maxf(0.0, Survivor.RUN_TIME - arena_at)


# --- monstres ------------------------------------------------------------------------------------------------------
## Apparition des monstres de la carte d'après spawn_plan (remplace celle de la Survie) : gardiens d'élite des camps,
## meutes continues, vagues alternées (encerclement + élite / horde), élites ponctuelles.
func update_spawns(delta: float) -> bool:
	var plan := spawn_plan(d.time)
	var cap := int(plan.alive_max)
	var alive := _alive()
	Monster.attack_slots = int(plan.attack_slots)
	var calm := guardians.any(func(e): return float(e.ttk) < 0.0)
	if calm:
		# (lot SVX-1) gardien en vie : la horde se calme (moitié moins de meutes, pas de vague, plafond × GUARDIAN_CALM) ; mesuré sans :
		# gardiens vaincus en 120-300 s au lieu de 30-90, le héros débutant tombait pendant le combat
		cap = roundi(cap * GUARDIAN_CALM)
	_despawn_t -= delta
	if _despawn_t <= 0.0:
		_despawn_t = 2.0
		if alive > int(cap * 0.8):
			alive -= d._despawn_far()
	_update_camps()
	_update_power(delta)
	_update_lod(delta)
	var sp = _squads()  # composant de spawn de P15 (escouades mélangées par rôle, anneau espacé) s'il est là
	if sp != null:
		sp.pace = float(plan.pace)  # budget des événements (encerclement, escorte, ruée, tenaille)
		sp.tick(delta)  # soigneurs, secteurs qui refroidissent, mesures
	_pack_t -= delta
	if _pack_t <= 0.0:
		_pack_t = float(plan.pack_every) * (2.0 if calm else 1.0)
		if alive < cap:
			var budget := float(mini(int(plan.pack_size), cap - alive))
			if sp != null and budget >= float(r("pack_split", Survivor.PACK_SPLIT)):
				# deux escouades mélangées de deux côtés (angle d'or, MIN_GAP_DEG) plutôt qu'un gros groupe
				var a: float = sp.pack(budget * 0.55, monster_level(0))
				sp.spawn_squad(sp._pick_squad(), budget * 0.45, monster_level(0), [a] if a != INF else [], sp.ring)
			elif sp != null:
				sp.pack(budget, monster_level(0))
			else:
				_pack(int(budget), monster_level(0), 20.0, 28.0)
	_wave_t -= 0.0 if calm else delta  # (pas de vague pendant le combat d'un gardien)
	if _wave_t <= 0.0:
		_wave_t = float(plan.wave_every)
		_wave_hard = not _wave_hard and bool(plan.hard)  # (ouverture : seulement des vagues légères, sans élite)
		var lvl := monster_level(1)
		var mins := float(plan.minute)
		if sp != null:
			sp.wave(_wave_hard, mins)  # encerclement annoncé, élite escortée, ruée d'essaim, tenaille
			if _wave_hard and float(plan.elite_every) > 0.0:
				_elite(1)
		elif _wave_hard:
			d.message.emit("Vague : encerclement !", 2.0)
			_ring(mini(10 + int(mins * 2.0), maxi(0, cap - _alive())), lvl, 18.0)
			if float(plan.elite_every) > 0.0:
				_elite(1)
		else:
			d.message.emit("Vague : horde !", 1.6)
			for i in 3:
				_pack(mini(6 + int(mins), maxi(0, cap - _alive())), maxi(1, lvl - 2), 22.0, 30.0)
	if float(plan.elite_every) > 0.0:
		_elite_t -= delta
		if _elite_t <= 0.0:
			_elite_t = float(plan.elite_every)
			_elite(1 if d.time < Survivor.BOSS_OPEN_AT else 2)
	return true


## Composant de spawn de la passe P15 (RunDirector.spawner, SpawnDirector : interface tick / pack / wave / pace) quand il
## est en place et pas en mode « --spawn=legacy » ; null : le spawn propre au Survivant (meutes, anneaux).
func _squads() -> SpawnDirector:
	if d.spawner == null or SpawnDirector.legacy:
		return null
	if not _sp_ready:
		# horde (lot SVX-1) : plus de monstres par rôle, arrivées à l'écran annoncées par une croix au sol
		_sp_ready = true
		d.spawner.role_cap_mult = float(r("horde_role_cap", Survivor.HORDE_ROLE_CAP))
		d.spawner.ring = r("horde_ring", Survivor.HORDE_RING)
		d.spawner.mark_time = float(r("horde_mark", Survivor.HORDE_MARK))
	return d.spawner


var _sp_ready := false
var _cam_done := false
var _outline_t := 0.0


# --- horde (lot SVX-1) ------------------------------------------------------------------------------------------------
## Monstre ordinaire de la horde (ni boss, ni élite, ni géant, ni gardien) : plus petit, sans collision physique, part de
## PV, de dégâts, d'expérience et d'or réduite (Survivor.HORDE_SHARE).
static func is_horde(m: Monster, boss: bool) -> bool:
	return not boss and not m.is_boss and not m.is_elite and not (m is GiantMonster) and not m.has_meta("sv_guardian")


## Barre de cible du HUD (lot SVX-1, SV-H2) : face à une horde, seulement pour les élites, géants, gardiens et boss.
static func shows_target_bar(t: Object) -> bool:
	if not Survivor.active or not (t is Monster):
		return true
	var m := t as Monster
	return m.is_boss or m.is_elite or m is GiantMonster


## Part [param i] (0 PV, 1 dégâts, 2 expérience, 3 or et potions) d'un monstre de la horde.
static func horde_share(i: int) -> float:
	var s: Array = r("horde_share", Survivor.HORDE_SHARE)
	return float(s[i]) if i < s.size() else 1.0


## Plafond de monstres vivants du directeur (RunDirector._hard_cap) : celui du plan de la minute, avec la marge des vagues ;
## dans l'arène, celui de la Survie ([param default]).
func hard_cap(default: int) -> int:
	if d.state != "explore":
		return default
	return int(spawn_plan(d.time).alive_max) + 40


## Or d'un monstre vaincu (× RunDirector, avant Run.add_gold) : la part de la horde pour un monstre ordinaire.
func kill_gold(m: Monster) -> float:
	return (horde_share(3) if m.has_meta("sv_horde") else 1.0) * SurvivorFavors.mult("gold")


## Niveaux de détail de la horde (toutes les LOD_EVERY s) : réflexion à chaque image près du héros, une sur 2 puis une
## sur 4 plus loin (animation au même rythme), ombre portée seulement de près (Monster.lod, Monster.lite).
const LOD_EVERY := 0.2
var _lod_t := 0.0


func _update_lod(delta: float) -> void:
	_lod_t -= delta
	if _lod_t > 0.0 or d.player == null:
		return
	_lod_t = LOD_EVERY
	var near := float(r("lod_near", Survivor.LOD_NEAR))
	var far := float(r("lod_far", Survivor.LOD_FAR))
	var shadow := float(r("shadow_near", Survivor.SHADOW_NEAR))
	var hero := d.player.global_position
	var rows: Array = []
	for node in d.get_tree().get_nodes_in_group("monsters"):
		var mo := node as Monster
		if mo == null or not mo.lite or mo.is_dead:
			continue
		rows.append([Vector2(mo.global_position.x - hero.x, mo.global_position.z - hero.z).length(), mo])
	rows.sort_custom(func(a, b): return float(a[0]) < float(b[0]))
	var full := int(r("lod_full", Survivor.LOD_FULL))
	var contrast := bool(Settings.get_v("interface", "horde_contrast"))
	for i in rows.size():
		var dist := float(rows[i][0])
		var mo: Monster = rows[i][1]
		# chaque image : les LOD_FULL plus proches à moins de LOD_NEAR m ; une sur 2 jusqu'à LOD_FAR m ; une sur 4 au-delà
		set_lod(mo, 0 if dist < near and i < full else (1 if dist < far else 2))
		if contrast != bool(mo.get_meta("sv_shade", false)) and mo.model != null:
			mo.set_meta("sv_shade", contrast)  # (lot SVX-4, SV-A1) horde contrastée : plus sombre et terne (shader eden_character)
			for gi in mo.model.find_children("*", "GeometryInstance3D", true, false):
				(gi as GeometryInstance3D).set_instance_shader_parameter("horde_shade", 0.8 if contrast else 0.0)
		var sh := dist < shadow
		if sh != bool(mo.get_meta("sv_shadow", true)) and mo.model != null:
			mo.set_meta("sv_shadow", sh)
			for gi in mo.model.find_children("*", "GeometryInstance3D", true, false):
				(gi as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if sh else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## Niveau de détail [param lod] du monstre [param mo] (sa réflexion et son animation ralentissent avec, Monster.lod).
static func set_lod(mo: Monster, lod: int) -> void:
	mo.lod = lod


## Puissance des monstres selon l'équipement de la run (MonsterScaling, voir Survivor.POWER_BAND) : mesurée toutes les
## POWER_SAMPLE s, lissée ; appliquée aux monstres ordinaires qui apparaissent (scale_monster).
func _update_power(delta: float) -> void:
	_power_t -= delta
	if _power_t > 0.0:
		return
	_power_t = POWER_SAMPLE
	gear_idx = MonsterScaling.gear_index()
	power = MonsterScaling.smooth(power, power_target(gear_idx, d.time), POWER_SAMPLE)


func _alive() -> int:
	return d.get_tree().get_nodes_in_group("monsters").size()


## Gardiens d'élite des camps (comme en Survie : une fois chacun, puis toutes les 2 min) : une clé et un choix de
## cartes ; ils ne portent plus de sceau utile (le portail du boss n'en demande pas).
func _update_camps() -> void:
	if d._elites.is_empty() or d.time < float(r("camps_from", Survivor.CAMPS_FROM)):
		return  # (ouverture : les camps d'élite dorment)
	for k in d.map.camps.size():
		var camp: Dictionary = d.map.camps[k]
		if not camp.elite or d._flat(d.player.global_position, camp.pos) > RunDirector.CAMP_ACTIVATE or d.time < float(d._camp_ready_at.get(k, 0.0)):
			continue
		d._camp_ready_at[k] = d.time + 120.0
		var lvl := monster_level(int(camp.tier) + 1)
		var e := d._spawn_monster(d._elites.pick_random(), camp.pos, lvl)
		e.carries_seal = true  # (RunDirector : un choix de cartes à sa mort)
		for i in 4:
			d._spawn_monster(d._pick_monster(lvl), d._around(camp.pos, 6.0), lvl)
		d.message.emit("Un gardien d'élite défend son camp !", 2.0)


func _pack(count: int, level: int, min_d: float, max_d: float) -> void:
	if count <= 0:
		return
	var center := d._ring_point(min_d, max_d)
	if center == Vector3.INF:
		return
	var id := d._pick_monster(level)
	for i in count:
		d._spawn_monster(id if randf() < 0.7 else d._pick_monster(level), d._around(center, 4.0), level)


## Anneau complet de [param n] monstres autour du héros (encerclement, horde finale).
func _ring(n: int, level: int, dist: float) -> void:
	for i in n:
		var a := TAU * i / float(n)
		var p := d.player.global_position + Vector3(cos(a), 0, sin(a)) * dist
		var g: Vector3 = d.map.ground_at(p.x, p.z)
		if g != Vector3.INF:
			d._spawn_monster(d._pick_monster(level), g, level)


func _elite(n: int) -> void:
	var c := d._ring_point(24.0, 34.0)
	if c == Vector3.INF:
		return
	for i in n:
		var id: int = d._elites.pick_random() if not d._elites.is_empty() else d._pick_monster(monster_level(1))
		var m := d._spawn_monster(id, d._around(c, 5.0), monster_level(1))
		if d._elites.is_empty():
			m.is_elite = true
			m.max_hp *= 4.0
			m.hp = m.max_hp


## Niveau des monstres (SPEC §8.2) : 1 + 1,8 par minute (+ palier du camp [param tier]), 90 au plus. DÉCISION S4 : pas de
## plancher « niveau du héros − 1 » (SPEC) : sans le plafond de niveau par carte de la Survie, il emballait la run (héros et
## monstres qui se tirent l'un l'autre : niveau 66 à 20:00 mesuré au pilote, cible 38).
func monster_level(tier: int) -> int:
	return clampi(int(spawn_plan(d.time).level) + tier, 1, MAX_LEVEL)


## Niveau maximal des monstres et du butin.
func max_level() -> int:
	return MAX_LEVEL


## PV et dégâts d'un monstre qui apparaît : la courbe par minute × palier (à la place de la zone, de l'époque et de la
## montée du début de la Survie). Gardien : PV fixes ; boss : dégâts × boss_atk × palier (PV fixes posés par setup_boss).
func scale_monster(m: Monster, boss: bool) -> bool:
	var plan := spawn_plan(d.time)
	m.atk *= float(r("boss_atk", Survivor.BOSS_ATK)) * palier_mult() if boss else float(plan.atk_mult)
	m.move_speed *= float(Survivor.tier_rule("speed"))  # palier II et plus : monstres plus rapides
	if m.has_meta("sv_guardian"):
		m.max_hp = guardian_hp(int(m.get_meta("sv_guardian")))
	elif not boss:
		m.max_hp *= float(plan.hp_mult)
		if is_horde(m, boss):
			# horde (lot SVX-1) : plus petit, sans collision physique, sa part de PV, de dégâts et d'expérience
			m.set_meta("sv_horde", true)
			m.lite = true
			_ensure_height()
			_soft_body(m)
			m.max_hp *= horde_share(0)
			m.atk *= horde_share(1)
			m.xp_reward = maxi(1, roundi(m.xp_reward * horde_share(2)))
			_shrink(m, float(r("horde_scale", Survivor.HORDE_SCALE)))
		elif m.is_elite:
			_shrink(m, float(r("horde_scale_elite", Survivor.HORDE_SCALE_ELITE)))
		if d.state == "explore" and not (m is GiantMonster):
			# équipement de la run au-dessus / en dessous de la bande attendue (lissé, plafonné avec Menace et pacte)
			var greed_k := RunDirector.GREED_MONSTERS if d.greed else 1.0
			var k := MonsterScaling.capped(power, Menace.hp_mult() * greed_k, greed_k)
			m.max_hp *= k.x
			m.atk *= k.y
		# (lot SVX-4) faveur de départ : monstres ordinaires et élites (jamais gardiens ni boss)
		m.max_hp *= SurvivorFavors.mult("m_hp")
		m.atk *= SurvivorFavors.mult("m_atk")
		m.move_speed *= SurvivorFavors.mult("m_speed")
	m.hp = m.max_hp
	return true


## Le héros traverse la horde (lot SVX-1) : un monstre ordinaire ne le bloque plus (il est repoussé hors de son corps,
## Monster._lite_move) ; mesuré avant : dans une foule de 60 monstres, le héros restait coincé (moins de coffres atteints,
## mort au premier gardien). Élites, géants et boss le bloquent toujours.
func _soft_body(m: Monster) -> void:
	var p := d.player
	if p == null:
		return
	p.add_collision_exception_with(m)
	m.tree_exiting.connect(func():
		if is_instance_valid(p):
			p.remove_collision_exception_with(m))


## Hauteur maximale des monstres de la horde (Monster.lite_height) : HORDE_HEIGHT × la hauteur du héros, posée dès que
## son modèle existe (avant le premier monstre).
func _ensure_height() -> void:
	if Monster.lite_height > 0.0:
		return
	var h := Monster.rig_height(d.player.model) if d.player != null and d.player.model != null else 0.0
	Monster.lite_height = (h if h > 0.5 else HERO_HEIGHT) * float(r("horde_height", Survivor.HORDE_HEIGHT))


const HERO_HEIGHT := 1.4  # m : héros mesuré (os le plus haut), si son modèle n'est pas encore là


## Taille du monstre × [param k] (avant son entrée en scène : le modèle et son rayon de collision suivent).
static func _shrink(m: Monster, k: float) -> void:
	if is_equal_approx(k, 1.0):
		return
	m.data = m.data.duplicate()
	m.data["scale"] = float(m.data.get("scale", 1.0)) * k


## PV fixes du gardien [param n] (0, 1, 2) × palier, avant la Menace (SPEC §8.2) : jamais d'après le héros.
static func guardian_hp(n: int) -> float:
	var hp: Array = r("guardian_hp", Survivor.GUARDIAN_HP)
	return float(hp[clampi(n, 0, hp.size() - 1)]) * palier_mult()


## PV fixes du boss final × palier, avant la Menace (SPEC §8.3).
static func final_boss_hp() -> float:
	return float(r("boss_hp", Survivor.BOSS_HP)) * palier_mult()


## Monstre vaincu (après l'or et la clé d'élite) : ni équipement, ni coffre de récompense, ni fourniture, ni arme
## secondaire, ni sceau ; seulement des potions (Survivor.POTION_DROP : monstre, élite).
func on_monster_died(m: Monster) -> bool:
	var drop: Array = r("potion_drop", Survivor.POTION_DROP)
	if not m.is_boss and randf() < float(drop[1] if m.is_elite else drop[0]) * (horde_share(3) if m.has_meta("sv_horde") else 1.0):
		d._drop_potion(m.global_position, Potions.roll_kind())
	return true


# --- gardiens --------------------------------------------------------------------------------------------------------
## Fait surgir le gardien [param n] (0, 1, 2) à GUARDIAN_DIST du héros : un géant (GiantMonster, passe P12) aux PV fixes,
## coups plafonnés à 30 % des PV du héros. Vaincu : coffre du gardien et or ; il ne monte PAS la Menace.
func spawn_guardian(n: int) -> GiantMonster:
	var lvl := monster_level(2)
	var at := d._ring_point(GUARDIAN_DIST - 1.0, GUARDIAN_DIST + 1.0)
	if at == Vector3.INF:
		at = d._around(d.player.global_position, 6.0)
	var g := GiantMonster.new()
	g.ref_elite = GameData.monster(int(d._elites.pick_random())) if not d._elites.is_empty() else {}
	g.set_meta("sv_guardian", n)
	d._spawn_monster(d._pick_monster(lvl), at, lvl, false, g)
	g.spawned_at = d.time
	g.display_name = "Gardien · " + g.display_name.trim_prefix("Géant · ")
	g.died.connect(func(_who: Combatant, _killer: Combatant): _on_guardian_died(n, g))
	guardians.append({"n": n, "t": snappedf(d.time, 0.1), "level": lvl, "hp": roundi(g.max_hp), "ttk": -1.0})
	RunJournal.add("sv_guardians")
	Sfx.event_at(d, at, "rock", 2.0)
	Vfx.shockwave(d.player, at, 8.0, Color(1.0, 0.4, 0.2))
	d.message.emit("UN GARDIEN SURGIT !\nVaincs-le : un coffre de gardien t'attend", 3.5)
	SurvivorHud.caption("Fracas : un gardien surgit")
	print("[sv] gardien %d à %s · niveau %d · PV %d · Menace %s" % [n + 1, clock(d.time), lvl, roundi(g.max_hp), Menace.mult_text()])
	return g


func _on_guardian_died(n: int, g: GiantMonster) -> void:
	if not is_instance_valid(d) or not Run.active:
		return
	var ttk := d.time - g.spawned_at
	for e in guardians:
		if int(e.n) == n and float(e.ttk) < 0.0:
			e.ttk = snappedf(ttk, 0.1)
			break
	RunJournal.add("sv_guardian_kills")
	Run.add_gold(GUARDIAN_GOLD[0] + GUARDIAN_GOLD[1] * g.level, "gardiens")
	print("[sv] gardien %d vaincu en %.0f s" % [n + 1, ttk])
	d.message.emit("GARDIEN VAINCU !\nOuvre son coffre", 3.0)
	offer_box(GUARDIAN_BOX, "Coffre du gardien : choisis une carte")
	shop_pending = true  # (lot SVX-4, SV-R3) la boutique du gardien s'ouvre une fois le coffre choisi


## Boutique du gardien (lot SVX-4, SV-R3) : ouverte dès que le choix du coffre du gardien est fait (aucun choix de carte
## ouvert) ; le pilote automatique y achète seul (SurvivorShop.pilot), un joueur a son écran (SurvivorShopUI).
var shop_pending := false
var shop_ui: SurvivorShopUI


func _update_guardian_shop() -> void:
	if not shop_pending or d.world == null:
		return
	var cards = d.world.get("cards")
	if cards != null and cards.is_open():
		return
	shop_pending = false
	if d.player.autoplay or Settings.auto_cards():
		SurvivorShop.open()
		SurvivorShop.pilot()  # (aide « Bot » : la boutique se fait seule, comme les cartes)
		var n := SurvivorShop.bought
		SurvivorShop.close(d.time)
		if not d.player.autoplay:
			d.message.emit("Boutique du gardien : %d carte%s achetée%s" % [n, "s" if n > 1 else "", "s" if n > 1 else ""], 2.5)
		d.player.recalc_stats()
		return
	if shop_ui == null or not is_instance_valid(shop_ui):
		shop_ui = SurvivorShopUI.new()
		d.world.add_child(shop_ui)
	shop_ui.open_shop(d.time)


## Gardiens vaincus.
func guardians_killed() -> int:
	return guardians.filter(func(e): return float(e.ttk) >= 0.0).size()


## Gardiens de la run : trois, quatre au palier V (deux à 15:00).
static func guardian_total() -> int:
	return Survivor.GUARDIAN_TIMES.size() + (1 if bool(Survivor.tier_rule("twin")) else 0)


# --- coffres, lieux, sanctuaires ------------------------------------------------------------------------------------
## Cartes du coffre [param box] : SurvivorCards.chest_cards (lot S3) ; tant que S3 n'est pas branché, des cartes de
## la Survie (sorts pour le coffre de sort).
static func box_cards(box: String) -> Array:
	if SurvivorCards.handles():
		var c := SurvivorCards.chest_cards(box)
		if not c.is_empty() or box == ANVIL_BOX:
			return c
	if box == ANVIL_BOX:
		return []
	var cards := Run.roll_cards(3, false, "spell") if box == "sv_spell" else []
	return cards if not cards.is_empty() else Run.roll_cards(3)


## Propose les cartes du coffre [param box] (une relance par coffre, comme en Survie).
func offer_box(box: String, title: String) -> void:
	var roll := func() -> Array: return box_cards(box)
	d.world._offer(title, roll.call(), roll, 1)


## Coffre de la carte ouvert (déjà payé par le directeur).
func open_chest(box: String) -> bool:
	if not BOXES.has(box):
		return false
	offer_box(box, "%s : choisis une carte" % String(BOXES[box].name))
	return true


## Nom d'un coffre du Survivant ("" : pas un coffre du Survivant).
static func box_title(box: String) -> String:
	return String(BOXES.get(box, {}).get("name", ""))


## Prix relatif d'un coffre du Survivant (× RunDirector.chest_price) ; plus cher avec le temps (lot SVX-4, SurvivorShop.chest_mult).
static func box_price(box: String) -> float:
	return float(BOXES.get(box, {}).get("price", 1.0)) * SurvivorShop.chest_mult(SurvivorCards.minutes()) * SurvivorFavors.mult("chest")


## Lieux : l'enclume donne +2 gratuit sur une pièce portée (chacune une fois) ; la stèle du défi donne un coffre doré.
## Fontaine, aimant, pacte et autel du géant : comme en Survie (P12 inchangé).
func use_station(it: Interactable) -> bool:
	match it.kind:
		"anvil":
			var cards := box_cards(ANVIL_BOX)
			if cards.is_empty():
				if d.player.autoplay:
					it.use_up()  # (pilote : il n'y revient pas en boucle)
				else:
					_say("Enclume : aucune pièce à renforcer\nReviens quand tu portes une pièce", 2.5)
				return true
			it.use_up()
			d.world._offer("Enclume : +2 sur une pièce", cards)
			return true
		"challenge":
			it.use_up()
			_start_challenge(it.global_position)
			return true
	return false


## Défi de la stèle : 3 élites et leur garde ; vaincues, un coffre doré gratuit et de l'or (pas de coffre de
## récompense ni de fourniture).
func _start_challenge(c: Vector3) -> void:
	var lvl := monster_level(2)
	var elites: Array = []
	for i in 3:
		var a := TAU * i / 3.0
		var p := d._around(c + Vector3(cos(a), 0, sin(a)) * 7.0, 2.0)
		var m: Monster = d._spawn_monster(d._elites.pick_random() if not d._elites.is_empty() else d._pick_monster(lvl), p, lvl)
		if d._elites.is_empty():
			m.max_hp *= 4.0
			m.hp = m.max_hp
		elites.append(m)
	for i in 6:
		d._spawn_monster(d._pick_monster(lvl), d._around(c, 9.0), lvl)
	_challenges.append({"pos": c, "elites": elites})
	d.message.emit("DÉFI : abats les 3 élites !", 2.5)


func _update_challenges() -> void:
	for ch in _challenges.duplicate():
		if not (ch.elites as Array).all(func(m): return not is_instance_valid(m) or m.is_dead):
			continue
		_challenges.erase(ch)
		Run.add_gold(roundi((CHALLENGE_GOLD[0] + CHALLENGE_GOLD[1] * d.player.level) * (RunDirector.GREED_GOLD if d.greed else 1.0)), "defis")
		d.message.emit("Défi réussi ! Un coffre doré", 3.0)
		offer_box("sv_gold", "Défi réussi ! Coffre doré : choisis une carte")


## Sanctuaire capturé : comme en Survie (carte du Survivant, ou 2 clés et de l'or ; « trophée » devenu « carte »).
func capture(_sh: Shrine) -> bool:
	return false


## Entrée du donjon : portail du boss, ouvert à 15:00, sans sceau ; avant, il reste fermé.
func try_enter_boss() -> bool:
	if not portal_open():
		var left := Survivor.BOSS_OPEN_AT - d.time
		_say("Le portail du boss est fermé\nIl s'ouvre dans %d:%02d" % [int(left) / 60, int(left) % 60], 2.5)
		return true
	enter_arena(false)
	return true


# --- pilote automatique (mesures, --autoplay) -------------------------------------------------------------------------
## Le pilote dépense son or comme un joueur (lot S8 ; avant, il finissait la carte avec ~50 000 or) : il va au coffre
## qu'il peut payer le plus proche (toute la carte), puis aux marchands qu'il n'a pas visités, et y achète des cartes
## (SurvivorCards.auto_pick) puis des clés. Rien de tout ça pour un joueur (ni pour l'aide « Bot »).
const PILOT_RETARGET := 1.0  # s entre deux choix de cible
var _pilot_t := 0.0
var _pilot_goal := Vector3.INF


## Cible du pilote (RunDirector._update_route) ; Vector3.INF : rien à acheter (il combat et farme comme avant).
func pilot_target() -> Vector3:
	if d.player == null or not d.player.autoplay or d.state != "explore" or d.map == null:
		return Vector3.INF
	if d.time >= _pilot_t:
		_pilot_choose()
	return _pilot_waypoint()


func _pilot_choose() -> void:
	_pilot_t = d.time + PILOT_RETARGET
	_pilot_goal = Vector3.INF
	_pilot_it = null
	var p := d.player.global_position
	for e in guardians:  # (lot SVX-1) un gardien en vie : le pilote va le combattre (sinon il frappait la horde qui l'entoure)
		if float(e.ttk) < 0.0:
			for node in d.get_tree().get_nodes_in_group("monsters"):
				if node is GiantMonster and node.has_meta("sv_guardian") and not (node as Monster).is_dead:
					_pilot_goal = (node as Node3D).global_position
					return
	var best := INF
	for it in d.map.interactables:
		if not is_instance_valid(it) or it.used or _pilot_skip.has(it):
			continue
		var ok := false
		if it.kind == "chest":
			ok = Profile.keys > 0 or Profile.gold >= d.chest_price(int(it.get_meta("tier", 0)), String(it.get_meta("box", "")))
		elif it.kind == "merchant":
			ok = not it.has_meta("pilot_done") and Profile.gold >= _pilot_card_price()
		if ok and d._flat(p, it.global_position) < best:
			best = d._flat(p, it.global_position)
			_pilot_goal = it.global_position
			_pilot_it = it


## Le pilote suit le chemin de navigation vers son but (lot SVX-4, mesures ; avant : la ligne droite, bloquée par les falaises
## et les rochers : sur certaines cartes il n'atteignait presque aucun coffre). Un but sans chemin est abandonné.
const PILOT_WP_EVERY := 0.3
var _pilot_it: Node = null
var _pilot_skip := {}  # lieux sans chemin (jamais repris)
var _wp := Vector3.INF
var _wp_t := 0.0
var _wp_goal := Vector3.INF


func _pilot_waypoint() -> Vector3:
	if _pilot_goal == Vector3.INF:
		return Vector3.INF
	if d.time < _wp_t and _pilot_goal.distance_to(_wp_goal) < 1.0:
		return _wp
	_wp_t = d.time + PILOT_WP_EVERY
	_wp_goal = _pilot_goal
	_wp = _pilot_goal
	var from := d.player.global_position
	var path: PackedVector3Array = d.map.path_between(from, _pilot_goal) if d.map.has_method("path_between") else PackedVector3Array()
	if path.size() < 2:
		return _wp
	var end := path[path.size() - 1]
	if Vector2(end.x - _pilot_goal.x, end.z - _pilot_goal.z).length() > 5.0 and _pilot_it != null:
		_pilot_skip[_pilot_it] = true  # (pas de chemin jusqu'au lieu : il en choisit un autre)
		_pilot_t = 0.0
		return _wp
	for pt in path:
		if Vector2(pt.x - from.x, pt.z - from.z).length() > 1.6:
			_wp = pt
			break
	return _wp


## Percée du pilote (lot SVX-4, mesures) : le pilote ne frappe qu'à moins de --fight m ; dans une horde dense il y a
## toujours un monstre à portée, il restait donc sur place et n'atteignait plus les coffres (mesuré au lot SVX-1 : les parties
## perdues vers 5:00 avaient 2 pièces et 0 coffre à 3:00, l'or intact). En route vers un but, il avance une part de chaque
## PILOT_CYCLE s sans s'arrêter (selon le profil) ; s'il ne se rapproche pas de son but de 2 m en PILOT_STUCK s, il passe en
## force PILOT_PUSH s, comme un joueur qui fend la horde.
const PILOT_STUCK := 2.0
const PILOT_PUSH := 4.0
const PILOT_CYCLE := 4.0
const PILOT_MOVE := 0.55
var _push_goal := Vector3.INF
var _push_best := INF
var _push_check := 0.0
var _push_until := -1.0
var _fight_base := -1.0


func _pilot_push() -> void:
	if _fight_base < 0.0:
		_fight_base = Run.test_fight_range
	var goal := d.player.autoplay_target
	# en route vers un but, le pilote avance PILOT_MOVE du temps sans s'arrêter pour frapper (cycle de PILOT_CYCLE s), le même pour
	# tous les profils (essai d'une part selon le profil : le « bon » joueur tuait moins, niveau 34-37 à 20:00 au lieu de 41)
	var moving := goal != Vector3.INF and fmod(d.time, PILOT_CYCLE) < PILOT_CYCLE * PILOT_MOVE
	if d.time < _push_until or moving:
		Run.test_fight_range = 0.0
		if not moving:
			return
	else:
		Run.test_fight_range = _fight_base
	if goal == Vector3.INF:
		_push_goal = Vector3.INF
		return
	var dist := d._flat(d.player.global_position, goal)
	if goal.distance_to(_push_goal) > 1.0:
		_push_goal = goal
		_push_best = dist
		_push_check = d.time + PILOT_STUCK
	elif dist < _push_best - 2.0:
		_push_best = dist
		_push_check = d.time + PILOT_STUCK
	elif d.time > _push_check:
		_push_until = d.time + PILOT_PUSH
		_push_best = dist
		_push_check = _push_until + PILOT_STUCK
		pushes += 1


var pushes := 0  # percées du pilote (journal)
var _was_dead := false


## Prix d'une carte de marchand au niveau du héros (MerchantUI.roll_offers : 50 à 70 + 14 par niveau).
func _pilot_card_price() -> int:
	return 70 + 14 * d.player.level


## Au contact d'un marchand pas encore visité : achète ses cartes (la meilleure d'abord, au choix du Bot) puis ses clés.
func _pilot_shop() -> void:
	var ui = d.world.get("merchant_ui") if d.world else null
	if ui == null:
		return
	for it in d.map.interactables:
		if not is_instance_valid(it) or it.kind != "merchant" or it.has_meta("pilot_done"):
			continue
		if d._flat(d.player.global_position, it.global_position) > it.radius:
			continue
		it.set_meta("pilot_done", true)
		var offers: Array = it.get_meta("offers") if it.has_meta("offers") else ui.roll_offers()
		it.set_meta("offers", offers)
		var spent := Profile.gold
		while true:
			var buyable := offers.filter(_pilot_can_buy)
			if buyable.is_empty():
				break
			var pick: Dictionary = SurvivorCards.auto_pick(buyable.map(func(o): return o.card), true)
			var o: Dictionary = buyable.filter(func(x): return x.card == pick).front() if not pick.is_empty() else buyable[0]
			ui.buy(o)
			if not o.get("sold", false):
				break
		for o in offers:
			if o.has("keys") and not o.get("sold", false) and int(o.price) <= Profile.gold:
				ui.buy(o)
		print("[sv] pilote : marchand à %s, %d or dépensés" % [clock(d.time), spent - Profile.gold])


## Offre de marchand que le pilote peut prendre : une carte (ni clé ni fourniture) pas encore vendue, dans ses moyens.
static func _pilot_can_buy(o: Dictionary) -> bool:
	return not o.get("sold", false) and not o.has("keys") and not o.has("bag") and o.has("card") and int(o.price) <= Profile.gold


func _say(text: String, duration: float) -> void:
	if d.time - float(_msg_at.get(text.get_slice("\n", 0), -INF)) < MSG_THROTTLE:
		return
	_msg_at[text.get_slice("\n", 0)] = d.time
	d.message.emit(text, duration)


# --- boss ------------------------------------------------------------------------------------------------------------
## Boss créé à l'entrée de l'arène : PV fixes × palier (la Menace s'y applique ensuite, Menace.apply en différé).
func setup_boss(boss: Monster) -> void:
	arena_at = d.time if arena_at < 0.0 else arena_at
	boss_hp = final_boss_hp()
	boss.max_hp = boss_hp
	boss.hp = boss.max_hp
	if int(Survivor.tier_rule("bricks")) > 0:
		_add_boss_bricks.call_deferred(boss, int(Survivor.tier_rule("bricks")))  # après BossBrain.setup (mécaniques de la zone)
	_cap_boss.call_deferred(boss)
	print("[sv] boss %s · PV %d (× Menace %s) · niveau %d" % [boss.display_name.trim_prefix("<Boss> "), roundi(boss_hp), Menace.mult_text(), boss.level])


## Coup du boss final plafonné (lot SVX-4) : jamais plus de boss_hit_cap des PV max du héros d'un seul coup (comme les gardiens,
## 30 %, et les boss de la bibliothèque, 40 %). Mesuré avant (« [sv] chute ») : le boss retirait 110 000 à 120 000 PV en 14-26 s à
## des héros +10 de 25 000 à 40 000 PV, même au profil « bon ».
func _cap_boss(boss: Monster) -> void:
	if is_instance_valid(boss) and boss.brain != null and "hit_cap" in boss.brain:
		boss.brain.hit_cap = float(r("boss_hit_cap", Survivor.BOSS_HIT_CAP))


## Paliers IV et V : [param n] mécaniques de plus pour le boss final (Survivor.EXTRA_BRICKS, d'une famille qu'il n'a pas),
## ajoutées à son cerveau comme les siennes (annoncées au sol, rythme et fureur communs).
func _add_boss_bricks(boss: Monster, n: int) -> void:
	if not is_instance_valid(boss) or boss.brain == null:
		return
	var b: BossBrain = boss.brain
	var added: Array = []
	for t in extra_bricks(b.bricks, n):
		var br := BossBricks.normalize({"type": t})
		b.bricks.append(br)
		b._brick_t.append(float(br.first))
		added.append(BossBricks.name_of(t))
	if not added.is_empty():
		d.message.emit("Palier %s · le boss gagne : %s" % [Survivor.numeral(Survivor.palier), ", ".join(added)], 3.0)
		print("[sv] boss : mécaniques du palier %s" % ", ".join(added))


## Types des [param n] briques ajoutées à un boss qui a déjà [param have] (briques normalisées) : dans l'ordre de
## Survivor.EXTRA_BRICKS, jamais une famille déjà présente.
static func extra_bricks(have: Array, n: int) -> Array:
	var fams: Array = have.map(func(br): return BossBricks.family_of(String(br.get("type", ""))))
	var out: Array = []
	for t in Survivor.EXTRA_BRICKS:
		if out.size() >= n:
			break
		var f := BossBricks.family_of(String(t))
		if not f in fams:
			out.append(String(t))
			fams.append(f)
	return out


## Début de la rage du boss, en secondes dans l'arène (4:00 ; plus tôt au palier V).
func boss_rage_at() -> float:
	return minf(float(r("boss_rage_at", Survivor.BOSS_RAGE_AT)), float(Survivor.tier_rule("rage_at")))


## Boss vaincu : une seule carte, la run est gagnée (bilan après 6 s, en pause pendant un choix de carte).
func on_boss_killed() -> bool:
	d.state = "cleared"
	Survivor.boss_down = true
	print("[sv] boss vaincu à %s (%.0f s dans l'arène), niveau %d" % [clock(d.time), d.time - arena_at, d.player.level])
	d.message.emit("Boss vaincu !\nTu as survécu", 4.0)
	if d.player.autoplay or Settings.auto_cards() or "--auto-quit" in OS.get_cmdline_user_args():
		_finish_later()
	else:
		_offer_endless()  # (lot SVX-4, SV-Q2) prolongations proposées
	return true


# --- prolongations (lot SVX-4, BM-SURV SV-Q2) -------------------------------------------------------------------------
## Après la victoire, « Continuer » : la horde revient sans fin dans l'arène, plus forte de minute en minute (PV × ENDLESS_HP,
## dégâts × ENDLESS_ATK par minute, meutes plus grosses) ; rien de plus à gagner : seulement le record « Plus longue
## prolongation ». La première chute (le héros se relève, la partie s'arrête) ou « Abandonner » au menu clôt la partie, gagnée.
const ENDLESS_EVERY := 2.2
const ENDLESS_PACK := 10
const ENDLESS_HP := 1.15
const ENDLESS_ATK := 1.08
const ENDLESS_ALIVE := 160
var endless := false
var endless_at := -1.0
var endless_secs := 0.0
var _endless_t := 0.0


func _offer_endless() -> void:
	await d.get_tree().create_timer(2.5, false).timeout
	if not is_instance_valid(d) or not Run.active or d.world == null:
		return
	d.get_tree().paused = true
	InfoCard.ask(d.world, "Prolongations ?", "La horde revient sans fin, de plus en plus forte. Rien de plus à gagner : seulement le record de la plus longue prolongation. Ta première chute clôt la partie, gagnée.",
		"Continuer", start_endless, false, "Terminer", _end_now)


func _end_now() -> void:
	d.get_tree().paused = CardPicker.pause_held(d.get_tree())
	if is_instance_valid(d):
		d.boss_defeated.emit()


## Lance les prolongations (tests : directement).
func start_endless() -> void:
	d.get_tree().paused = CardPicker.pause_held(d.get_tree())
	endless = true
	endless_at = d.time
	d.player.add_status("angel", 1.0e6)  # (la chute qui clôt les prolongations relève le héros)
	d.message.emit("PROLONGATIONS !\nTiens le plus longtemps possible", 3.0)
	SurvivorLog.moment(d.time, "Prolongations", "event")


func _update_endless(delta: float) -> void:
	if not endless:
		return
	endless_secs = d.time - endless_at
	if not d.player.has_status("angel") or d.player.is_dead:
		endless = false
		print("[sv] prolongations : %.0f s" % endless_secs)
		d.message.emit("Fin des prolongations : %s tenues" % clock(endless_secs), 3.0)
		d.boss_defeated.emit()
		return
	_endless_t -= delta
	if _endless_t > 0.0 or _alive() >= ENDLESS_ALIVE:
		return
	_endless_t = ENDLESS_EVERY
	var mins := endless_secs / 60.0
	var lvl := mini(MAX_LEVEL, monster_level(0) + int(mins * 2.0))
	var c := d._ring_point(12.0, 18.0)
	if c == Vector3.INF:
		return
	for i in ENDLESS_PACK + int(mins * 2.0):
		var m: Monster = d._spawn_monster(d._pick_monster(lvl), d._around(c, 4.0), lvl)
		if m != null:
			m.max_hp *= pow(ENDLESS_HP, mins)
			m.hp = m.max_hp
			m.atk *= pow(ENDLESS_ATK, mins)


func _finish_later() -> void:
	await d.get_tree().create_timer(6.0, false).timeout
	if is_instance_valid(d):
		d.boss_defeated.emit()


# --- texte et journal --------------------------------------------------------------------------------------------------
## Temps « 12:34 ».
static func clock(t: float) -> String:
	return "%d:%02d" % [int(t) / 60, int(t) % 60]


## Prochain gardien encore à venir (-1 : aucun).
func next_guardian() -> int:
	for i in Survivor.GUARDIAN_TIMES.size():
		if d.time < float(Survivor.GUARDIAN_TIMES[i]):
			return i
	return -1


## Ligne d'objectif en exploration : « Gardien à 10:00 », puis « Portail du boss ouvert », puis « Boss dans 0:42 ».
func objective_text() -> String:
	var n := next_guardian()
	if n >= 0:
		return "Gardien à %s" % clock(Survivor.GUARDIAN_TIMES[n])
	if d.time < FINAL_HORDE_AT:
		return "Portail du boss ouvert · boss à 20:00"
	return "Le boss arrive dans %s" % clock(maxf(0.0, Survivor.RUN_TIME - d.time))


## Ligne courte sous l'horloge du HUD (à la place des sceaux) : les gardiens vaincus.
func status_text() -> String:
	var n := guardian_total()
	var k := mini(guardians_killed(), n)
	return "Gardiens  " + "◆ ".repeat(k) + "◇ ".repeat(maxi(0, n - k))


## Lignes du panneau d'objectifs du HUD (exploration).
func objective_lines() -> Array[String]:
	var lines: Array[String] = []
	var n := next_guardian()
	lines.append(("◇ Gardien à %s" % clock(Survivor.GUARDIAN_TIMES[n])) if n >= 0 else "✔ Les trois gardiens sont passés")
	lines.append("✔ Portail du boss ouvert : entre quand tu veux" if portal_open() else "◇ Portail du boss à %s" % clock(Survivor.BOSS_OPEN_AT))
	lines.append("◇ Coffres %d / %d" % [d.chests_opened, d.map.chests.size() if d.map else 0])
	lines.append("◇ Sanctuaires %d / %d" % [d.shrines_captured, d.map.shrines.size() if d.map else 0])
	lines.append("Boss à 20:00" if d.time < FINAL_HORDE_AT else "Le boss arrive dans %s" % clock(maxf(0.0, Survivor.RUN_TIME - d.time)))
	return lines


## Une ligne de journal par minute de carte (et d'arène) ; ligne « [sv] » dans la console.
func _sample_minute() -> void:
	var m := int(d.time / 60.0)
	if m <= _minute or d.player == null:
		return
	_minute = m
	var plan := spawn_plan(d.time)
	var row := {"m": m, "state": d.state, "level": d.player.level, "hp": snappedf(d.player.hp / maxf(d.player.max_hp, 1.0), 0.01),
		"alive": _alive(), "kills": Run.kills, "mlvl": monster_level(0), "hp_mult": snappedf(float(plan.hp_mult), 0.01),
		"atk_mult": snappedf(float(plan.atk_mult), 0.01), "menace": Menace.level, "gold": Profile.gold,
		"skills": Run.all_skills().size(), "pieces": SurvivorGear.worn().size(), "cards": cards_taken(),
		"taken": roundi(damage_taken()), "max_hp": roundi(d.player.max_hp), "gear_index": snappedf(gear_idx, 0.01),
		"power": [snappedf(power.x, 0.01), snappedf(power.y, 0.01)], "pity": Survivor.pity_given}
	_minutes.append(row)
	print("[sv] %02d:00 · %s · niveau %d · PV %d %% · monstres %d (niv. %d, PV ×%.2f, dégâts ×%.2f) · tués %d · Menace %d · or %d · sorts %d · pièces %d · cartes %d · subis %d · pv_max %d · indice %.2f · puissance ×%.2f/×%.2f · pitié %d · percées %d · boutique %d · maudites %d%s" % [
		m, d.state, row.level, roundi(float(row.hp) * 100.0), row.alive, row.mlvl, row.hp_mult, row.atk_mult, row.kills, row.menace,
		row.gold, row.skills, row.pieces, row.cards, row.taken, row.max_hp, gear_idx, power.x, power.y, Survivor.pity_given,
		pushes, SurvivorShop.spent, SurvivorGear.curses_worn().size(),
		(" · boss PV %d %%" % roundi(100.0 * d._boss.hp / maxf(d._boss.max_hp, 1.0))) if d.state == "boss" and is_instance_valid(d._boss) else ""])
	print("[sv-build] " + build_line())
	var dn := maxf(float(_dens.n), 1.0)
	row["near"] = snappedf(float(_dens.near) / dn, 0.1)
	row["screen"] = snappedf(float(_dens.screen) / dn, 0.1)
	print("[sv-dens] %02d:00 · %s · près %.1f (max %d) · écran %.1f (max %d) · vivants %.1f (max %d)" % [m, d.state, float(_dens.near) / dn,
		int(_dens.near_max), float(_dens.screen) / dn, int(_dens.screen_max), float(_dens.alive) / dn, int(_dens.alive_max)])
	_dens = {"n": 0, "near": 0, "near_max": 0, "screen": 0, "screen_max": 0, "alive": 0, "alive_max": 0}
	if d.orbs != null:  # expérience (lot S9) : orbes au sol, posées, reprises (sol plein), lâchée / ramassée / reprise
		var o: Dictionary = d.orbs.stats
		print("[sv-xp] %02d:00 · niveau %d · au sol %d · posées %d · reprises %d · xp lâchée %d · ramassée %d · reprise %d" % [
			m, d.player.level, d.orbs.count(), int(o.spawned), int(o.recycled), roundi(float(o.xp_in)), roundi(float(o.xp_got)),
			roundi(float(o.xp_recycled))])


## Densité de la horde (lot SVX-1) : chaque seconde, monstres vivants, à moins de DENSITY_NEAR m du héros et à l'écran
## (cône de la caméra) ; moyenne et maximum par minute (ligne « [sv-dens] », journal : near, screen).
const DENSITY_NEAR := 15.0
var _dens := {"n": 0, "near": 0, "near_max": 0, "screen": 0, "screen_max": 0, "alive": 0, "alive_max": 0}
var _dens_t := 0.0


func _sample_density(delta: float) -> void:
	_dens_t -= delta
	if _dens_t > 0.0 or d.player == null:
		return
	_dens_t = 1.0
	var c := density_now()
	_dens.n = int(_dens.n) + 1
	for k in ["near", "screen", "alive"]:
		_dens[k] = int(_dens[k]) + int(c[k])
		_dens[k + "_max"] = maxi(int(_dens[k + "_max"]), int(c[k]))


## Monstres vivants maintenant : {alive, near (à moins de DENSITY_NEAR m), screen (dans le champ de la caméra)}.
func density_now() -> Dictionary:
	var hero := d.player.global_position
	var cam := d.get_viewport().get_camera_3d()
	var out := {"alive": 0, "near": 0, "screen": 0}
	for node in d.get_tree().get_nodes_in_group("monsters"):
		var mo := node as Monster
		if mo == null or mo.is_dead:
			continue
		out.alive += 1
		var p := mo.global_position
		if Vector2(p.x - hero.x, p.z - hero.z).length() < DENSITY_NEAR:
			out.near += 1
		if cam and cam.is_position_in_frustum(p + Vector3.UP * 0.5):
			out.screen += 1
	return out


## Cartes prises dans la run : cartes du Survivant (arme, pièces, améliorations, évolutions, repli) + niveaux de sorts
## (un nouveau sort = 1, chaque amélioration = 1). « Passer » n'en est pas une.
static func cards_taken() -> int:
	var n := 0
	for k in Survivor.picks:
		if String(k) != "skip":
			n += int(Survivor.picks[k])
	for s in Run.all_skills():
		n += int(s.rank)
	return n


## Dégâts subis par le héros depuis le début de la run (compteurs du journal).
static func damage_taken() -> float:
	var t := 0.0
	for k in ["normal", "elite", "boss", "autre"]:
		t += float(RunJournal.counters.get("dmg_taken_" + k, 0.0))
	return t


## Build en une ligne (mesures, ligne « [sv-build] ») : arme et +N, set le plus porté, pièces et +N, sorts et niveaux,
## passifs (nombre, au plafond), évolutions, statistiques clés du héros.
func build_line() -> String:
	var w: Dictionary = Profile.equipped.get("weapon", {})
	var counts := Items.set_counts(Profile.equipped)
	var best_set := ""
	for sid in counts:
		if best_set == "" or int(counts[sid]) > int(counts[best_set]):
			best_set = String(sid)
	var ups: PackedStringArray = []
	var plus10 := 0
	for s in Items.SLOTS:
		var it: Dictionary = Profile.equipped.get(s, {})
		if not it.is_empty():
			ups.append("%s+%d" % [s, int(it.get("upgrade", 0))])
			plus10 += 1 if int(it.get("upgrade", 0)) >= 10 else 0
	var capped := Run.passive_power.keys().filter(func(id): return float(Run.passive_power[id]) >= SurvivorGear.boon_cap(String(id)) - 0.001).size()
	var evos := Run.passives.keys().filter(func(id): return not (Boons.get_def(String(id)).get("requires", []) as Array).is_empty())
	var p := d.player
	return "arme=%s+%d set=%s:%d pièces=%d plus10=%d up=%s sorts=%s passifs=%d plafond=%d évolutions=%d crit=%.2f mcrit=%.2f critdmg=%.2f vit=%.2f recharge=%.2f dégâts=%.2f atk=%d matk=%d pv=%d" % [
		Items.weapon_type_of(w) if not w.is_empty() else "-", int(w.get("upgrade", 0)), SurvivorPool.family(best_set) if best_set != "" else "-",
		int(counts.get(best_set, 0)), SurvivorGear.worn().size(), plus10, ",".join(ups), ",".join(PackedStringArray(Run.all_skills().map(func(s): return str(int(s.rank))))),
		Run.passive_power.size(), capped, evos.size(), p.crit, p.mcrit, p.crit_dmg, p.atk_speed, p.cdr, p.dmg_mult, roundi(p.atk), roundi(p.matk), roundi(p.max_hp)]


func _journal_context() -> Dictionary:
	var base: Dictionary = _base_context.call() if _base_context.is_valid() else {}
	return base.merged(journal())


## Champs du journal de run (ajoutés au contexte de la carte) : minute par minute, gardiens, arène, boss.
func journal() -> Dictionary:
	return {"sv_minutes": _minutes.duplicate(true), "sv_guardians": guardians.duplicate(true), "sv_arena_at": snappedf(arena_at, 0.1),
		"sv_arena_forced": arena_forced, "sv_early_s": snappedf(early_seconds(), 0.1), "sv_boss_hp": roundi(boss_hp)}


## Disposition des coffres de la carte (ProcMap) : types [param boxes] et apparences [param tiers] remplacés sur place
## par ceux du Survivant (LAYOUT, mélangés avec [param rng]).
static func layout_map(boxes: Array, tiers: Array, rng: RandomNumberGenerator) -> void:
	var out := layout(boxes.size(), rng)
	for k in boxes.size():
		boxes[k] = out[k]
		if k < tiers.size():
			tiers[k] = int(BOXES[out[k]].look)


## Types des [param n] coffres d'une carte du Survivant, mélangés avec [param rng].
static func layout(n: int, rng: RandomNumberGenerator) -> Array:
	var out: Array = []
	while out.size() < n:
		out.append_array(LAYOUT)
	out = out.slice(0, n)
	for i in range(out.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t = out[i]
		out[i] = out[j]
		out[j] = t
	return out
