class_name Tower
extends RefCounted
## Mode de jeu « la Tour » : 200 étages. Chaque étage vidé donne une carte (sorts, passifs,
## comme en run) et un coffre au centre de la salle, à ouvrir tout de suite : son objet
## s'équipe pour l'ascension s'il est meilleur. Le héros part avec le préréglage d'équipement
## de sa classe ; tout ce que les coffres donnent rejoint le coffre commun à la fin, que
## l'ascension soit gagnée ou perdue.
## Étages (passe M3, retour du joueur : « les petites vagues étaient ennuyeuses ») : par blocs de 10 (le palier de
## reprise), plan fixe tiré de la graine du bloc (block_plan) : monstres (espèces et rôles mélangés, toujours au moins
## une élite à mécanique), élites (plusieurs élites à mécanique), ombres (un héros d'une classe joué par l'IA : ClassRival,
## parfois ta propre classe avec ton kit, ou un cerveau d'IA en Difficile / Hardcore aux étages hauts), étage maudit
## (Menace, rage ou horde : coffre meilleur et cristaux en plus), halte (étage 9 du bloc : soin, carte, coffre) et boss
## (étage 10 : un boss de la bibliothèque, BossLibrary, PV fixes) ; les duellistes des étages 1, 4 et 7 ouvrent le Duel
## libre et la Ligue (Unlocks). Le décor change tous les 25 étages.
## Difficulté choisie au lancement (IA des duellistes, force des monstres), puis l'étage de
## départ : ceux déjà battus ou le suivant. Un record par difficulté. Une seule vie.
## Tout est réglable dans le mode dev (page Tour) : règles générales et réglages étage par
## étage (data/dev_edits.json -> "tower" : {rules, floors}). Chaque étage est décrit par
## spec(), lue par l'étage en jeu, la page des étages et sa fiche d'infos.
## La sauvegarde n'est pas écrite pendant l'ascension ; elle est rechargée à la sortie, puis
## les objets trouvés, le record et l'expertise y sont ajoutés.

const FLOORS := 200
const FLOORS_PER_ZONE := 25
const RECORD := "tower_best"
## Étages qui donnent un coffre d'apparence, et sa qualité (Rewards.LOOK_TYPES).
const LOOK_FLOORS := [50, 100, 150, 200]
const LOOK_TIERS := [1, 2, 3, 3]
const DIFF_NAMES := ["Facile", "Normal", "Difficile", "Hardcore"]
const DIFF_DESC := [
	"Ombres lentes à réagir, monstres affaiblis.",
	"Ombres qui esquivent et punissent parfois.",
	"Ombres qui lisent tes coups, annulent et se replacent.",
	"Ombres au réflexe parfait : esquive au dernier moment, combos sans pause, chaque temps mort puni.",
]
const TYPES := ["monsters", "elite", "duel", "boss", "shadow", "rest", "cursed"]
const TYPE_NAMES := {"monsters": "Monstres", "elite": "Élites", "duel": "Duelliste", "boss": "Boss", "shadow": "Ombre",
	"rest": "Halte", "cursed": "Maudit"}
## Icône de chaque type (pages de la Tour, fiche, HUD) et ce qu'il donne, en une phrase (fiche de l'étage).
const TYPE_ICONS := {"monsters": "attack", "elite": "power", "duel": "weapon", "boss": "stats", "shadow": "class",
	"rest": "heart", "cursed": "speed"}
const TYPE_GIVES := {
	"monsters": "Une carte, puis un coffre.",
	"elite": "Une carte, puis un coffre plus généreux.",
	"duel": "Une carte, puis un coffre ; chaque duelliste battu ouvre un peu plus le Duel.",
	"shadow": "Une carte, puis un coffre plus généreux.",
	"boss": "Une carte, un coffre mythique ou légendaire, et tes PV rendus.",
	"rest": "Des PV rendus, une carte et un coffre, sans combat.",
	"cursed": "Une carte, un meilleur coffre et des cristaux en plus.",
}
## Malédictions des étages maudits : {name, desc}. Effets dans TowerDirector (PV, rage, nombre).
const CURSES := {
	"menace": {"name": "Menace", "desc": "Les monstres sont bien plus coriaces."},
	"frenzy": {"name": "Rage", "desc": "Les monstres sont enragés : plus rapides et plus forts."},
	"horde": {"name": "Horde", "desc": "Deux fois plus de monstres, plus nombreux en même temps."},
}
const CURSE_HP := 1.6  # Menace : PV des monstres
const CURSE_HORDE := 1.8  # Horde : nombre de monstres (et × 1,3 en même temps)
const CURSE_CRYSTALS := 4  # cristaux en plus par étage maudit franchi (× la difficulté, comme TOWER_PER_FLOOR)
## Mécaniques des élites (briques de BossBricks, une par élite, tirée par étage) : jamais d'invocation (réservée aux
## boss), d'arène ni de placement (lisibles seulement en duel face au boss).
const ELITE_BRICKS := ["puddles", "meteors", "leap", "rampage", "fan", "ring_burst", "stomp", "marks", "barrier", "enrage", "blink"]
const ELITE_HIT_CAP := 0.25  # un coup d'élite retire au plus cette part des PV max du héros
## [étage, facteur] : PV des boss selon l'étage (équipement attendu : époque I jusqu'au 50, II vers 70, III vers 100,
## IV au-delà de 130) ; mesuré avec tools/tower_run (--god), voir conception/nuit_15_10/R_M3.md.
const BOSS_CURVE := [[1, 1.0], [50, 1.0], [70, 5.0], [100, 5.5], [130, 9.0], [200, 7.0]]
## Boss d'un étage mesuré trop court ou trop long avec la courbe seule (le boss de chaque étage est fixe) : × ce facteur.
const BOSS_FLOOR_ADJ := {100: 0.7, 150: 2.5, 160: 3.0, 190: 0.6, 200: 0.5}  # 100 et 150 : passe M8
## Un coup de boss de la Tour retire au plus cette part des PV max du héros (passe M8 : une seule vie, seul, et le corps à
## corps passe le combat dans ses zones ; la bibliothèque en prend 40 % ailleurs : BossLibrary.HIT_CAP).
const BOSS_HIT_CAP := 0.25
## Ombre éveillée (cerveau d'IA, équipement de l'ombre scriptée de l'étage) : PV et dégâts × ceux de l'ombre scriptée qu'elle
## remplace (elle esquive, enchaîne et se soigne mieux : PV × 0,5 et soins reçus moitié moins, mesuré).
const BRAIN_HP := 0.5
const BRAIN_DMG := 1.0
const ATK_CURVE_EXP := 0.6  # dégâts des monstres et des ombres × BOSS_CURVE ^ ceci (équipement attendu des étages hauts)
const PLAN_SEED := 2026
const DUEL_SLOTS := ["weapon", "head", "chest", "legs", "gloves", "boots"]
## Règles par défaut (modifiables dans le mode dev, page Tour) : [valeur, nom, pas].
const RULES := {
	"level_per_floor": [0.5, "Niveaux par étage", 0.05],
	"monsters_base": [20.0, "Monstres à l'étage 1", 1.0],
	"monsters_per_floor": [0.3, "Monstres en plus par étage", 0.05],
	"monsters_max": [70.0, "Monstres au plus", 1.0],
	"alive_base": [10.0, "Monstres en même temps (étage 1)", 1.0],
	"alive_per_floor": [0.05, "En même temps : en plus par étage", 0.01],
	"alive_max": [24.0, "En même temps au plus", 1.0],
	"monster_ramp": [0.02, "Monstres : force en plus par étage d'une zone", 0.005],
	"monster_zone_step": [0.1, "Monstres : force en plus par zone", 0.01],
	"monster_easy": [0.7, "Monstres : force en Facile", 0.05],
	"monster_normal": [1.0, "Monstres : force en Normal", 0.05],
	"monster_hard": [1.3, "Monstres : force en Difficile", 0.05],
	"monster_hardcore": [1.6, "Monstres : force en Hardcore", 0.05],
	"elite_count_per_50": [1.0, "Élites en plus tous les 50 étages", 1.0],
	"duel_hp": [0.9, "Duellistes : PV (× ceux de l'entraînement)", 0.05],
	"duel_atk": [1.0, "Duellistes : dégâts", 0.05],
	"duel_gear": [1.0, "Duellistes : force de leur équipement", 0.1],
	"duel_skills_every": [3.0, "Duellistes : un sort de plus tous les N duels", 1.0],
	"boss_hp": [0.8, "Boss : PV (× les PV fixes d'un boss de donjon Normal)", 0.05],
	"boss_atk": [1.0, "Boss : dégâts", 0.05],
	"heal_between": [0.5, "PV rendus en montant (part)", 0.05],
	"elite_hp": [3.0, "Élites : PV (× ceux d'une élite)", 0.1],
	"shadow_hp": [3.0, "Ombres : PV (× ceux des duellistes)", 0.1],
	"shadow_atk": [1.8, "Ombres : dégâts (× ceux des duellistes)", 0.1],
	"elites_per_70": [1.0, "Élites en plus tous les 70 étages (étage de monstres)", 1.0],
	"rest_heal": [0.6, "Halte : PV rendus (part)", 0.05],
}
const DIFF_RULE := ["monster_easy", "monster_normal", "monster_hard", "monster_hardcore"]

static var active := false
## Donjon (lot 13) : zone du donjon en cours ("" : pas de donjon), difficulté et alliés IA choisis.
static var dungeon := ""
static var rush := false  # la Ruée des boss : « donjon » de 8 salles de boss (Rush : tirage de la bibliothèque, passe M6)
static var siege := false  # Le Siège : « donjon » à 5 vagues puis le boss, puis le chacun pour soi (Siege)
static var dungeon_diff := 0
## Donjon à la carte (passe M2) : boss de la bibliothèque (BossLibrary) du donjon en cours ("" : Ruée, Siège, Tour).
static var dungeon_boss := ""
static var allies: Array = []
static var difficulty := 1
static var start_floor := 1
static var floor_n := 1  # étage en cours
static var reached := 0  # dernier étage vidé
static var found: Array = []  # objets des coffres de l'ascension (rejoignent le coffre commun)
static var _order: Array = []  # classes des duels, dans l'ordre (toujours le même)
static var _gear_cache := {}  # "étage_difficulté" -> équipement du duelliste
static var _plans := {}  # bloc de 10 étages -> plan (block_plan)
static var _boss_cache := {}  # étage -> boss de la bibliothèque (boss_id)
static var cursed_cleared := 0  # étages maudits franchis pendant l'ascension (cristaux en plus)


## Lance l'ascension avec la classe [param cid], en [param diff], à l'étage [param from].
## Lance le donjon de la zone [param zid] en difficulté [param diff] avec les alliés IA [param ally_ids] ; [param boss_id] :
## le boss de la bibliothèque choisi (donjon à la carte), par défaut celui de la zone.
## [param from_room] > 1 : « Réessayer le boss » (lot DNG-1) : la partie reprend à cette salle, une carte tirée par salle sautée.
static func start_dungeon(cid: String, zid: String, diff: int, ally_ids: Array, boss_id := "", from_room := 1) -> void:
	start(cid, 1, 1)
	dungeon = zid
	rush = zid == Dungeons.RUSH
	if not rush:
		dungeon_boss = boss_id if BossLibrary.has(boss_id) and BossLibrary.get_def(boss_id).zone == zid else BossLibrary.zone_boss(zid)
	siege = false
	dungeon_diff = clampi(diff, 0, Dungeons.DIFF_NAMES.size() - 1)
	allies = ally_ids.slice(0, Dungeons.MAX_ALLIES)
	difficulty = 1
	if rush:
		Rush.start()  # passe M6 : les huit boss du tirage proposé, les modificateurs cochés
	Run.fill_from_preset()
	if Run.skills.is_empty():
		for s in (Run.class_data().get("skills", []) as Array).slice(0, 4):
			Run.skills.append({"id": int(s.id), "rank": 1})
	if from_room > 1 and not rush:
		start_floor = clampi(from_room, 1, Dungeons.ROOMS.size())
		floor_n = start_floor
		reached = start_floor - 1
		for i in start_floor - 1:
			var pick: Array = Run.roll_cards(1)
			if not pick.is_empty():
				Run.apply_card(pick[0])
	Relief.arm()  # lot DNG-3 : la relève du départ (Normal et Héroïque)


## Lance Le Siège de la zone [param zid] : deux alliés IA (complétés au hasard), cinq vagues, le boss, le chacun pour soi.
static func start_siege(cid: String, zid: String, diff: int, ally_ids: Array) -> void:
	start_dungeon(cid, zid, diff, [])
	dungeon_boss = ""  # (le Siège garde son boss de zone ; la bibliothèque y viendra plus tard)
	siege = true
	rush = false
	allies = Siege.fill_allies(ally_ids)
	Siege.reset()


static func start(cid: String, diff := 1, from := 1) -> void:
	dungeon = ""
	dungeon_boss = ""
	rush = false
	siege = false
	Siege.reset()
	allies = []
	active = true
	difficulty = clampi(diff, 0, DIFF_NAMES.size() - 1)
	start_floor = clampi(from, 1, FLOORS)
	floor_n = start_floor
	reached = start_floor - 1
	found = []
	cursed_cleared = 0
	HitLog.reset()  # lot DNG-1 : coups reçus, temps et rencontres de la partie
	BestTimes.reset()
	Encounters.reset()
	BossPractice.active = false  # lot DNG-3 : entraînement, relève, étoiles et tableau du Siège de la partie
	Relief.reset()
	DungeonStars.reset()
	SiegeScore.reset()
	Run.start(cid)
	# le préréglage d'équipement de la classe sert de base (Profile.begin_run) ; une arme
	# commune s'il n'y en a pas
	if not Profile.equipped.has("weapon"):
		Profile.equipped["weapon"] = Items.generate(1, 0.0, "weapon", cid, 0, "", 0)
	Profile.inventory = []
	Profile.bag = {}
	Profile.gold = 0
	Profile.keys = 0
	if start_floor > 1:
		_resume_kit()
	Relief.arm()  # (la Tour : Facile à Difficile ; un donjon la règle à nouveau)
	Profile.changed.emit()


# --- règles ---------------------------------------------------------------------------------
static func edits() -> Dictionary:
	if not DevEdits.data.has("tower"):
		DevEdits.data["tower"] = {"rules": {}, "floors": {}}
	var t: Dictionary = DevEdits.data.tower
	if not t.has("rules"):
		t["rules"] = {}
	if not t.has("floors"):
		t["floors"] = {}
	return t


static func rule(key: String) -> float:
	return float(edits().rules.get(key, RULES[key][0]))


## Réglages du mode dev pour l'étage [param f] (type, class, level, hp, atk, count, skills).
static func floor_edit(f: int) -> Dictionary:
	return edits().floors.get(str(f), {})


## Après une modification du mode dev : l'équipement des duellistes est retiré au sort à nouveau.
static func edited() -> void:
	_gear_cache.clear()


static func is_dungeon() -> bool:
	return dungeon != ""


## Dernière salle ou dernier étage.
static func top() -> int:
	if siege:
		return Siege.WAVES + 1  # cinq vagues, puis le boss
	if rush:
		return Dungeons.rush_floors()
	return Dungeons.ROOMS.size() if is_dungeon() else FLOORS


static func zone_for(f: int) -> Dictionary:
	if rush:
		return Dungeons.rush_zone(f)
	if is_dungeon():
		return Dungeons.zone(dungeon)
	return GameData.zones[clampi((f - 1) / FLOORS_PER_ZONE, 0, GameData.zones.size() - 1)]


## Type par défaut de l'étage [param f] : sa place dans le plan de son bloc de 10 étages.
static func default_type(f: int) -> String:
	var b := (clampi(f, 1, FLOORS) - 1) / 10
	return String(block_plan(b)[(clampi(f, 1, FLOORS) - 1) % 10])


## Plan du bloc [param b] (étages 10 b + 1 à 10 b + 10, le palier de reprise) : 10 types, toujours les mêmes pour
## un bloc donné (graine PLAN_SEED). Place 9 : halte ; place 10 : boss. Bloc 0 : duellistes aux étages 1, 4 et 7 (ils
## ouvrent le Duel libre puis la Ligue : Unlocks), élites au 5. Blocs suivants : deux ombres (une par moitié de bloc,
## jamais côte à côte), un étage d'élites, un étage maudit à partir du bloc 2, le reste en monstres.
static func block_plan(b: int) -> Array:
	if _plans.has(b):
		return _plans[b]
	var plan: Array = []
	plan.resize(10)
	plan.fill("monsters")
	plan[8] = "rest"
	plan[9] = "boss"
	if b == 0:
		plan[0] = "duel"
		plan[3] = "duel"
		plan[6] = "duel"
		plan[4] = "elite"
	else:
		var rng := RandomNumberGenerator.new()
		rng.seed = hash([PLAN_SEED, b])
		var s1 := rng.randi_range(0, 3)
		var s2 := rng.randi_range(5, 7) if s1 == 3 else rng.randi_range(4, 7)
		plan[s1] = "shadow"
		plan[s2] = "shadow"
		var free: Array = range(8).filter(func(i): return plan[i] == "monsters")
		var e: int = free[rng.randi_range(0, free.size() - 1)]
		plan[e] = "elite"
		free.erase(e)
		if b >= 2:
			plan[free[rng.randi_range(0, free.size() - 1)]] = "cursed"
	_plans[b] = plan
	return plan


static func floor_type(f: int) -> String:
	if siege:
		return Siege.floor_type(f)
	if rush:
		return "boss"
	if is_dungeon():
		return String(Dungeons.ROOMS[clampi(f - 1, 0, Dungeons.ROOMS.size() - 1)])
	var t := String(floor_edit(f).get("type", ""))
	return t if t in TYPES else default_type(f)


static func level_for(f: int) -> int:
	if rush:
		return Dungeons.rush_level(f, dungeon_diff)
	if siege:
		return Siege.level(dungeon, dungeon_diff) + (1 if f > Siege.WAVES else 0)
	if is_dungeon():
		return Dungeons.level(dungeon, dungeon_diff) + (1 if f >= Dungeons.ROOMS.size() else 0)
	if floor_edit(f).has("level"):
		return maxi(1, int(floor_edit(f).level))
	return 1 + int((f - 1) * rule("level_per_floor"))


static func is_boss_floor(f: int) -> bool:
	return floor_type(f) == "boss"


static func is_elite_floor(f: int) -> bool:
	return floor_type(f) == "elite"


## Étage contre un héros joué par l'IA : duelliste ou ombre (règles du face-à-face : aide limitée, pas d'arrêt sur impact).
static func is_duel_floor(f: int) -> bool:
	return floor_type(f) in ["duel", "shadow"]


static func is_shadow_floor(f: int) -> bool:
	return floor_type(f) == "shadow"


## Rang de l'étage [param f] parmi les ombres (1 pour la première, 0 si ce n'en est pas une).
static func shadow_index(f: int) -> int:
	if not is_shadow_floor(f):
		return 0
	var n := 0
	for k in range(1, f + 1):
		if is_shadow_floor(k):
			n += 1
	return n


## Sorte d'ombre de l'étage [param f] en difficulté [param diff] : "self" (ta classe et ton kit : une ombre sur quatre),
## "brain" (un cerveau d'IA : Hardcore dès l'étage 100, Difficile dès le 150, une ombre sur deux ; repli sur l'IA
## scriptée s'il manque), "class" (une classe de la liste) ; "" si l'étage n'est pas une ombre.
static func shadow_kind(f: int, diff := -1) -> String:
	var k := shadow_index(f)
	if k == 0:
		return ""
	var d := difficulty if diff < 0 else diff
	if k % 4 == 0:
		return "self"
	if k % 2 == 1 and ((d >= 3 and f >= 100) or (d == 2 and f >= 150)):
		return "brain"
	return "class"


## Difficulté de l'IA du héros de l'étage [param f] : celle de l'ascension pour les duellistes, puis un cran de plus aux
## étages 80 et 150 pour les ombres (au plus Hardcore).
static func duel_ai(f: int, diff := -1) -> int:
	var d := difficulty if diff < 0 else diff
	if not is_shadow_floor(f):
		return d
	return mini(d + (1 if f >= 80 else 0) + (1 if f >= 150 else 0), ClassRival.DIFF.size() - 1)


## Cerveau d'IA d'une ombre éveillée (copie figée du Panthéon, dans git) selon la difficulté.
static func shadow_brain(diff := -1) -> String:
	return "hardcore" if (difficulty if diff < 0 else diff) >= 3 else "difficile"


static func duel_index(f: int) -> int:
	var n := 0
	for k in range(1, f + 1):
		if is_duel_floor(k):
			n += 1
	return n


static func duel_count() -> int:
	return duel_index(FLOORS)


## Ordre des classes des duels : les 20 de base puis les 40 avancées, mélangées une fois pour
## toutes (la page des étages montre à l'avance qui attend à chaque étage).
static func duel_order() -> Array:
	if _order.is_empty():
		var rng := RandomNumberGenerator.new()
		rng.seed = 2026
		var green: Array = GameData.classes.keys().filter(func(k): return String(GameData.classes[k].get("tier", "")) == "green")
		var other: Array = GameData.classes.keys().filter(func(k): return not k in green)
		green.sort()
		other.sort()
		for arr in [green, other]:
			for i in range(arr.size() - 1, 0, -1):
				var j := rng.randi_range(0, i)
				var tmp = arr[i]
				arr[i] = arr[j]
				arr[j] = tmp
		_order = green + other
	return _order


static func duel_class(f: int) -> String:
	var c := String(floor_edit(f).get("class", ""))
	if c != "" and GameData.classes.has(c):
		return c
	if shadow_kind(f) == "self":
		return Run.class_id if active and Run.class_id != "" else Profile.selected_class  # ton ombre : ta classe
	var o := duel_order()
	return String(o[(maxi(duel_index(f), 1) - 1) % o.size()])


static func duel_skills(f: int) -> int:
	if floor_edit(f).has("skills"):
		return clampi(int(floor_edit(f).skills), 0, 4)
	return clampi(1 + int(duel_index(f) / maxf(rule("duel_skills_every"), 1.0)), 1, 4)


static func monster_count(f: int) -> int:
	if siege:
		return Siege.wave_count(f, dungeon_diff)
	if is_dungeon():
		return Dungeons.room_monsters(f, dungeon_diff)
	if floor_edit(f).has("count"):
		return maxi(0, int(floor_edit(f).count))
	var n := mini(int(rule("monsters_base") + f * rule("monsters_per_floor")), int(rule("monsters_max")))
	match floor_type(f):
		"elite":
			return n / 2  # les élites font l'étage : moins de monstres ordinaires
		"cursed":
			return roundi(n * CURSE_HORDE) if curse_of(f) == "horde" else n
		"duel", "shadow", "boss", "rest":
			return 0
	return n


static func max_alive(f: int) -> int:
	if siege:
		return Siege.max_alive(dungeon_diff)
	if is_dungeon():
		return Dungeons.room_alive(dungeon_diff)
	var n := mini(int(rule("alive_base") + f * rule("alive_per_floor")), int(rule("alive_max")))
	return roundi(n * 1.3) if floor_type(f) == "cursed" and curse_of(f) == "horde" else n


## Élites de l'étage : au moins une à chaque étage de monstres (une de plus tous les 70 étages), trois et plus aux étages
## d'élites (une de plus tous les 50), aucune aux duels, ombres, haltes et boss.
static func elite_count(f: int) -> int:
	if siege:
		return Siege.elite_count(f, dungeon_diff)
	if is_dungeon():
		return Dungeons.room_elites(dungeon_diff)
	match floor_type(f):
		"elite":
			return 3 + int(f / 50 * rule("elite_count_per_50"))
		"monsters", "cursed":
			return 1 + int(f / 70 * rule("elites_per_70"))
	return 0


## Mécanique (brique de BossBricks) de la [param i]-ième élite de l'étage [param f] : tirée par étage, jamais deux fois
## la même sur un étage.
static func elite_brick(f: int, i: int) -> String:
	var start := absi(hash([PLAN_SEED, "elite", f])) % ELITE_BRICKS.size()
	return String(ELITE_BRICKS[(start + i * 3) % ELITE_BRICKS.size()])


## Rôle d'un monstre pour composer un étage : celui du composant d'apparition de la passe P15 (SpawnDirector.role_of :
## essaim, mêlée, chargeur, tireur, colosse, soigneur, d'après le modèle).
static func role_of(id: int, _pool: Array = []) -> String:
	return SpawnDirector.role_of(id)


## Espèces de l'étage [param f] : 3 espèces de sa zone (4 à partir de l'étage 40), de rôles différents quand la zone le
## permet (role_of), tirées par étage parmi celles de son niveau ; le directeur les fait apparaître à tour de rôle (des
## groupes mélangés, jamais un pack d'une seule espèce). Vide hors de la Tour.
static func floor_species(f: int) -> Array:
	var out: Array = []
	if is_dungeon():
		return out
	var z := zone_for(f)
	var roster: Array = z.get("monsters", []).map(func(x): return int(x))
	if roster.is_empty():
		return out
	var lvl := level_for(f)
	var start := 1 + int(z.get("level_bonus", 0))
	var n := clampi(3 + int((lvl - start) * roster.size() / 10.0), mini(3, roster.size()), roster.size())
	var options := roster.slice(0, n)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([PLAN_SEED, "mix", f])
	var by_role := {}
	for id in options:
		var r := role_of(int(id), options)
		if not by_role.has(r):
			by_role[r] = []
		by_role[r].append(int(id))
	var roles: Array = by_role.keys()
	roles.sort()
	for k in range(roles.size() - 1, 0, -1):
		var j := rng.randi_range(0, k)
		var tmp = roles[k]
		roles[k] = roles[j]
		roles[j] = tmp
	var want := mini(3 if f < 40 else 4, options.size())
	for r in roles:
		if out.size() >= want:
			break
		var list: Array = by_role[r]
		out.append(list[rng.randi_range(0, list.size() - 1)])
	var guard := 0
	while out.size() < want and guard < 40:
		guard += 1
		var id := int(options[rng.randi_range(0, options.size() - 1)])
		if not id in out:
			out.append(id)
	return out


## Malédiction de l'étage maudit [param f] (CURSES), "" sinon.
static func curse_of(f: int) -> String:
	if floor_type(f) != "cursed":
		return ""
	var keys := CURSES.keys()
	return String(keys[absi(hash([PLAN_SEED, "curse", f])) % keys.size()])


## Force des monstres de l'étage : zone, étage dans la zone, difficulté.
static func monster_mult(f: int, diff := -1) -> float:
	var d := difficulty if diff < 0 else diff
	return (1.0 + rule("monster_ramp") * float((f - 1) % FLOORS_PER_ZONE) + rule("monster_zone_step") * float((f - 1) / FLOORS_PER_ZONE)) * rule(DIFF_RULE[d])


## PV et dégâts des monstres de l'étage (× réglages de l'étage dans le mode dev) ; boss à part.
static func monster_hp_mult(f: int, diff := -1, boss := false) -> float:
	if siege:
		return Siege.hp_mult(boss, floor_type(f) == "elite")
	if is_dungeon():
		return Dungeons.hp_mult(boss, floor_type(f) == "elite", allies.size())
	# étages hauts (passe M3) : PV × la racine de la courbe des boss, dégâts × sa puissance 0,3 (équipement attendu plus fort)
	return monster_mult(f, diff) * float(floor_edit(f).get("hp", 1.0)) * (rule("boss_hp") if boss else sqrt(boss_curve(f)))


static func monster_atk_mult(f: int, diff := -1, boss := false) -> float:
	if is_dungeon():
		return 1.0 + 0.3 * dungeon_diff
	return monster_mult(f, diff) * float(floor_edit(f).get("atk", 1.0)) * (rule("boss_atk") if boss else 1.0) * pow(boss_curve(f), ATK_CURVE_EXP)


## Boss de la bibliothèque (BossLibrary) de l'étage de boss [param f] : un des 6 boss de la zone de l'étage, jamais le même
## deux fois dans une zone (ordre tiré une fois par zone) ; le dernier boss de chaque zone est son gardien (le boss d'origine).
static func boss_id(f: int) -> String:
	if _boss_cache.has(f):
		return _boss_cache[f]
	var zi := clampi((f - 1) / FLOORS_PER_ZONE, 0, GameData.zones.size() - 1)
	var zid := String(GameData.zones[zi].id)
	var pool: Array = BossLibrary.for_zone(zid)
	var keeper := BossLibrary.zone_boss(zid)
	var floors: Array = range(zi * FLOORS_PER_ZONE + 1, mini((zi + 1) * FLOORS_PER_ZONE, FLOORS) + 1).filter(func(k): return default_type(k) == "boss")
	var id := keeper
	if not pool.is_empty() and f != int(floors.back() if not floors.is_empty() else -1):
		var others := pool.filter(func(x): return x != keeper)
		var rng := RandomNumberGenerator.new()
		rng.seed = hash([PLAN_SEED, "boss", zid])
		for i in range(others.size() - 1, 0, -1):
			var j := rng.randi_range(0, i)
			var tmp = others[i]
			others[i] = others[j]
			others[j] = tmp
		var k := maxi(floors.find(f), 0)
		id = String(others[k % others.size()]) if not others.is_empty() else keeper
	if id == "" and not pool.is_empty():
		id = String(pool[0])
	_boss_cache[f] = id
	return id


## Palier du boss de l'étage [param f] (rythme des mécaniques, Impatience en Mythique) : selon l'étage (0 jusqu'au 60,
## 1 jusqu'au 130, 2 ensuite), un cran de moins en Facile, un de plus en Hardcore.
static func boss_tier(f: int, diff := -1) -> int:
	var d := difficulty if diff < 0 else diff
	var t := (0 if f <= 60 else (1 if f <= 130 else 2)) + (-1 if d == 0 else (1 if d >= 3 else 0))
	return clampi(t, 0, BossLibrary.PACE.size() - 1)


## PV fixes du boss de l'étage [param f] (passe P11 : indépendants du héros) : ceux d'un boss de donjon Normal de son
## niveau, × le boss (BossLibrary), × la règle « boss_hp », × la courbe des étages (BOSS_CURVE), × la force de la difficulté.
static func boss_hp_fixed(f: int, diff := -1) -> float:
	var d := difficulty if diff < 0 else diff
	var id := boss_id(f)
	var k := float(BossLibrary.get_def(id).get("hp", 1.0)) if id != "" else 1.0
	return Dungeons.boss_hp(level_for(f) + 1, 0) * k * rule("boss_hp") * boss_curve(f) * float(BOSS_FLOOR_ADJ.get(f, 1.0)) * rule(DIFF_RULE[d]) * float(floor_edit(f).get("hp", 1.0))


## Équipement attendu aux étages hauts (passe M3, mesuré au pilote : un héros de l'époque III ou IV tuait un boss de donjon
## Normal de l'étage 130 en 4 s) : PV des boss × ce facteur, interpolé entre les étages de BOSS_CURVE.
static func boss_curve(f: int) -> float:
	var prev: Array = BOSS_CURVE[0]
	for pt in BOSS_CURVE:
		if f <= int(pt[0]):
			var span := maxf(float(int(pt[0]) - int(prev[0])), 1.0)
			return lerpf(float(prev[1]), float(pt[1]), clampf(float(f - int(prev[0])) / span, 0.0, 1.0))
		prev = pt
	return float(BOSS_CURVE[-1][1])


## Équipement du duelliste de l'étage (tiré une fois pour l'étage et la difficulté).
static func duel_gear(f: int, diff := -1) -> Array:
	var d := difficulty if diff < 0 else diff
	var key := "%d_%d" % [f, d]
	if _gear_cache.has(key):
		return _gear_cache[key]
	var cid := duel_class(f)
	var lv := level_for(f)
	seed(hash([f, d, cid]))
	var out: Array = []
	for slot in DUEL_SLOTS:
		out.append(Items.generate(lv, 0.2 * d + f / 150.0, slot, cid, 0, "", 3))
	randomize()
	_gear_cache[key] = out
	return out


## Fiche complète de l'étage [param f] en difficulté [param diff] : type, zone, niveau, et
## selon le type le duelliste, les monstres ou le boss avec leurs stats.
static func spec(f: int, diff := -1) -> Dictionary:
	var d := difficulty if diff < 0 else diff
	var z := zone_for(f)
	var s := {"floor": f, "type": floor_type(f), "zone": z, "level": level_for(f), "diff": d}
	match String(s.type):
		"duel", "shadow":
			s["class"] = duel_class(f)
			s["skills"] = duel_skills(f)
			s["index"] = duel_index(f)
			s["ai"] = duel_ai(f, d)
			s["kind"] = shadow_kind(f, d) if s.type == "shadow" else "duel"
			s["gear"] = self_gear() if s.kind == "self" else duel_gear(f, d)
		"boss":
			s["boss_id"] = boss_id(f)
			s["boss"] = int(BossLibrary.get_def(String(s.boss_id)).get("monster", z.get("dungeon", {}).get("boss", 0)))
			s["tier"] = boss_tier(f, d)
		"rest":
			pass
		_:
			s["count"] = monster_count(f)
			s["alive"] = max_alive(f)
			s["elites"] = elite_count(f)
			s["mechanics"] = range(int(s.elites)).map(func(i): return elite_brick(f, i))
			if s.type == "cursed":
				s["curse"] = curse_of(f)
	return s


## Équipement de « ton ombre » : une copie de celui que tu portes (pendant l'ascension : celui de l'ascension).
static func self_gear() -> Array:
	var out: Array = []
	for slot in DUEL_SLOTS:
		if Profile.equipped.has(slot):
			out.append(Profile.equipped[slot])
	return out


## Sorts de « ton ombre » : ceux de ton préréglage actif (sinon ceux de la classe), sans renforcement ni soin.
static func self_skills(cid: String, n: int) -> Array:
	var flat: Array = []
	for col in SpellPresets.active(cid).get("cols", []):
		for id in col:
			flat.append(int(id))
	var out: Array = Duel.scripted_spells(cid, flat) if not flat.is_empty() else []
	if out.is_empty():
		out = Duel.spell_choices(cid)
	return out.slice(0, maxi(n, 4))


## Duelliste prêt à placer (aussi pour la fiche : créé, lu puis libéré).
static func make_rival(s: Dictionary) -> ClassRival:
	var f := int(s.floor)
	var r := ClassRival.new()
	r.setup(String(s["class"]), int(s.level), int(s.get("ai", s.diff)), rule("duel_hp") * float(floor_edit(f).get("hp", 1.0)), int(s.skills))
	if String(s.get("kind", "")) == "self":
		r._skills = self_skills(r.cid, int(s.skills))  # ton ombre : les sorts de ton préréglage
	# puissance des objets : celle du niveau de l'étage (Items.power_level), même hors partie
	var was_active := Run.active
	var was_level := Run.hero_level
	Run.active = true
	Run.hero_level = int(s.level)
	r.apply_gear(s.gear, rule("duel_gear"))
	Run.active = was_active
	Run.hero_level = was_level
	r.atk *= rule("duel_atk") * float(floor_edit(f).get("atk", 1.0))
	if String(s.get("type", "")) == "shadow":
		# une ombre est un vrai combat d'étage (passe M3, mesuré au pilote : les duellistes tombaient en 3 à 8 s)
		r.max_hp *= rule("shadow_hp") * sqrt(boss_curve(f))
		r.hp = r.max_hp
		r.atk *= rule("shadow_atk") * pow(boss_curve(f), ATK_CURVE_EXP)
	r.display_name = "<Duel> %s" % hero_title(s)
	return r


## Nom du héros de l'étage [param s] (spec) : « Guerrier » (duelliste), « Ombre · Guerrier », « Ton ombre · Guerrier »,
## « Ombre éveillée · Guerrier » (cerveau d'IA).
static func hero_title(s: Dictionary) -> String:
	var cname := String(GameData.class_data(String(s.get("class", ""))).get("name_fr", s.get("class", "")))
	match String(s.get("kind", "duel")):
		"self":
			return "Ton ombre · %s" % cname
		"brain":
			return "Ombre éveillée · %s" % cname
		"class":
			return "Ombre · %s" % cname
	return cname


## Stats d'un monstre de l'étage (fiche) : {name, hp, atk, def, level}.
static func monster_stats(id: int, s: Dictionary, boss := false) -> Dictionary:
	var m := Monster.new()
	var lv := int(s.level) + (1 if boss else 0)
	m.configure(GameData.monster(id), boss, lv)
	var hp := m.max_hp * monster_hp_mult(int(s.floor), int(s.diff), boss)
	var atk := m.atk * monster_atk_mult(int(s.floor), int(s.diff), boss)
	var out := {"name": m.display_name, "hp": hp, "atk": atk, "def": m.defense, "level": m.level, "elite": m.is_elite}
	m.free()
	return out


static func chest_item(f: int, class_id: String) -> Dictionary:
	var lv := level_for(f)
	if is_boss_floor(f):
		var rar := Items.LEGENDARY if randf() < 0.25 + f / 400.0 else Items.MYTHIC
		return Items.generate(lv, 1.0, "", class_id, rar, "", rar)
	var bonus := {"elite": 0.4, "duel": 0.3, "shadow": 0.4, "rest": 0.2, "cursed": 0.8}
	var luck := clampf(f / 120.0, 0.0, 1.5) + float(bonus.get(floor_type(f), 0.0))
	var floor_rar := 2 if floor_type(f) == "cursed" else (1 if f >= 20 else 0)  # étage maudit : rare au moins
	return Items.generate(lv, luck, "", class_id, floor_rar, "", 3)  # commun à épique


# --- progression ------------------------------------------------------------------------------
static func record_key(diff: int) -> String:
	return RECORD if diff == 1 else "%s_%d" % [RECORD, diff]


## Palier de reprise de la difficulté [param diff] : le début du bloc de 10 étages en cours
## (étage 1 tant que moins de 10 étages sont battus).
static func checkpoint(diff := -1) -> int:
	var b := best(diff)
	return clampi((b / 10) * 10 + 1, 1, FLOORS)


## Reprise sans piège : partir d'un étage élevé donne le kit complet (12 sorts du préréglage) et
## des cartes en rapport avec l'étage (une tous les 6 étages), pour ne pas arriver nu.
static func _resume_kit() -> void:
	Run.fill_from_preset()
	if Run.skills.is_empty():
		for s in (Run.class_data().get("skills", []) as Array).slice(0, 4):
			Run.skills.append({"id": int(s.id), "rank": 1})  # pas de préréglage : les sorts de base de la classe
	for i in start_floor / 6:
		var pick: Array = Run.roll_cards(1, false, "passive")
		if not pick.is_empty():
			Run.apply_card(pick[0])


## Duellistes battus au mieux, toutes difficultés confondues (fil d'éveil).
static func duelists_beaten() -> int:
	var top := 0
	for d in DIFF_NAMES.size():
		top = maxi(top, best(d))
	return duel_index(top)


## Dernier étage battu dans la difficulté [param diff].
static func best(diff := -1) -> int:
	return int(Profile.records.get(record_key(difficulty if diff < 0 else diff), 0))


## Mode dev : tous les étages ouverts (case de la page Tour du mode dev, cochée par défaut).
static func dev_unlock_all() -> bool:
	return bool(Settings.get_v("interface", "dev_mode")) and bool(Settings.get_v("interface", "tower_unlock_all"))


## Étage jouable : déjà battu, ou le suivant (tous en mode dev, si la case est cochée).
static func unlocked(f: int, diff: int) -> bool:
	return f <= best(diff) + 1 or dev_unlock_all()


## Fin de l'ascension (gagnée ou perdue) : la sauvegarde est rechargée, puis les objets des
## coffres rejoignent le coffre commun, et le record et l'expertise sont enregistrés.
## Renvoie {best, new_record, xp, levels, items}.
static func finish() -> Dictionary:
	if not active:
		return {}
	if is_dungeon():
		return _finish_dungeon()
	RunJournal.end_map("fin", {"floor": floor_n})
	active = false
	Run.active = false
	var cid := Run.class_id
	Profile.in_run = false
	Profile.reload_keep_records()
	Profile.gold = 0
	Profile.keys = 0
	Profile.bag = {}
	BestTimes.commit()  # après le rechargement du profil (lot DNG-1)
	Encounters.commit()
	for it in found:
		Profile.mark_new(it)  # pastille « Nouveau » dans le sac (lot GX-3)
		Profile.vault.append(it)  # le coffre commun (l'inventaire du lobby en est tiré)
	var old := best()
	Profile.record_max(record_key(difficulty), reached)
	# paliers 50, 100, 150, 200 : un coffre d'apparence (une fois par difficulté et par palier)
	var looks := 0
	for i in LOOK_FLOORS.size():
		var f: int = LOOK_FLOORS[i]
		var key := "tower_look_%d_%d" % [difficulty, f]
		if reached >= f and not Profile.records.has(key):
			Profile.records[key] = 1
			Profile.reward_chests.append(Rewards.make(Rewards.look_type(LOOK_TIERS[i]), 30, true))
			looks += 1
	var climbed := maxi(0, reached - start_floor + 1)
	Quests.end_run("tower", false, {"reached": reached, "climbed": climbed})  # quêtes (passe M5)
	# cristaux et coffres de gemmes / de forge de l'ascension (ActivityLoot : le rôle de la Tour)
	var cursed_bonus := cursed_cleared * CURSE_CRYSTALS * (difficulty + 1)  # étages maudits franchis
	var crystals := ActivityLoot.tower_crystals(climbed, difficulty) + cursed_bonus
	Profile.materials["crystal"] = int(Profile.materials.get("crystal", 0)) + crystals
	var mats := ActivityLoot.tower_chests(start_floor, reached, level_for)
	var xp := roundi((climbed * 12 + Run.kills / 3) * [0.75, 1.0, 1.3, 1.6][difficulty])
	var lv := Profile.add_expertise(cid, xp)
	Profile._lobby_view()
	Profile.save_profile()
	return {"best": best(), "new_record": reached > old, "xp": xp, "levels": lv, "items": found.size(), "looks": looks,
		"crystals": crystals, "chests": mats, "cursed": cursed_cleared, "cursed_crystals": cursed_bonus,
		"heroes": duel_index(reached) - duel_index(start_floor - 1), "bosses": count_type("boss", start_floor, reached)}


## Étages du type [param t] entre [param from] et [param to] compris.
static func count_type(t: String, from: int, to: int) -> int:
	var n := 0
	for f in range(maxi(from, 1), mini(to, FLOORS) + 1):
		if floor_type(f) == t:
			n += 1
	return n


## Fin d'un donjon : butin si le boss est tombé, sauvegarde rechargée (comme la Tour).
static func _finish_dungeon() -> Dictionary:
	var victory := reached >= top()
	var was_siege := siege
	var sg_outcome := Siege.outcome
	RunJournal.end_map("victoire" if victory else "defaite", {"dungeon": dungeon, "dungeon_diff": dungeon_diff, "rooms": reached, "allies": allies.size()})
	active = false
	Run.active = false
	var cid := Run.class_id
	var zid := dungeon
	var diff := dungeon_diff
	var bid := dungeon_boss
	Profile.in_run = false
	Profile.reload_keep_records()
	Profile.gold = 0
	Profile.keys = 0
	Profile.bag = {}
	var rew := {}
	var was_rush := rush
	var rush_seed := Rush.seed
	var rush_rank := {}
	if victory and start_floor == 1 and not was_siege:  # temps complet (lot DNG-1) : pas une reprise au boss
		if was_rush:
			BestTimes.note(BestTimes.rush_key(Rush.seed, diff), "Tirage n° %d" % Rush.seed, BestTimes.clock)
			rush_rank = RushBoard.add(Rush.seed, diff, BestTimes.clock, Rush.mods, int(Profile.records.get("rush_prev", 0)))  # lot DNG-3
		elif BossLibrary.has(bid):
			BestTimes.note(BestTimes.dungeon_key(bid, diff), Dungeons.dungeon_name(bid), BestTimes.clock)
	if was_siege and SiegeScore.boss_time > 0.0:  # lot DNG-3 : le Siège a ses temps (vagues + boss, puis le boss seul)
		BestTimes.note(BestTimes.siege_key(zid, diff), "Le Siège", SiegeScore.boss_time)
	BestTimes.commit()  # après le rechargement du profil (lot DNG-1)
	Encounters.commit()
	var dstars := {}
	if was_siege:
		rew = Siege.settle(zid, diff, reached, sg_outcome)  # des cristaux dès les premières vagues
	elif was_rush:
		rew = Dungeons.rush_reward(reached, diff)  # des cristaux même si la Ruée s'arrête avant la fin
	elif victory:
		rew = Dungeons.reward(zid, diff, bid)
		# étoiles du donjon (lot DNG-3) : jamais requises pour le butin ; paliers = titres et coffres d'apparence
		dstars = DungeonStars.score(bid, diff, true, start_floor == 1, BestTimes.clock, Relief.used)
	var xp := (reached * 40 + (150 if victory else 0)) * (1 + diff)
	var lv := Profile.add_expertise(cid, xp)
	Quests.end_run("siege" if was_siege else ("rush" if was_rush else "dungeon"), victory, {"rooms": reached, "reached": reached, "diff": diff,
		"allies": allies.size(), "boss_down": was_siege and reached > Siege.WAVES, "siege_won": was_siege and sg_outcome == "won"})  # quêtes (passe M5)
	Achievements.refresh()
	Profile._lobby_view()
	Profile.save_profile()
	dungeon = ""
	dungeon_boss = ""
	rush = false
	siege = false
	allies = []
	Rush.reset()
	var rank := Siege.rank
	Siege.reset()
	return {"dungeon": true, "rush": was_rush, "siege": was_siege, "outcome": sg_outcome, "rank": rank, "victory": victory, "rooms": reached,
		"start_room": start_floor, "rush_seed": rush_seed if was_rush else 0, "rush_rank": rush_rank, "dstars": dstars,
		"reliefs": Relief.used, "siege_board": SiegeScore.rows() if was_siege else [],
		"xp": xp, "levels": lv, "reward": rew, "zone": zid, "diff": diff, "boss": bid}


static func leave(tree: SceneTree) -> void:
	if active:
		finish()
	tree.paused = false
	tree.change_scene_to_file.call_deferred("res://scenes/lobby.tscn")
