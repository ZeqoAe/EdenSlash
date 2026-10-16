class_name Survivor
extends RefCounted
## Mode « Survivant » (id `survivor`, conception/survivor/SPEC.md, corrigé par DECISIONS_JOUEUR.md qui prime) : une
## run pure façon Vampire Survivors où tout le build se gagne aux cartes de niveau. Mode à part, « pour s'amuser » :
## AUCUN lien avec la progression du compte (ni équipement du hub, ni maîtrise, ni insignes, ni découvertes) ; seules
## les classes et les apparences débloquées comptent, et la récompense de fin est un coffre d'apparence (lot S6).
##
## Lot S1 (socle) : l'état de la run, son lancement (héros niveau 1, sans arme ni pièce), la protection du hub et les
## crochets posés dans les fichiers existants. Le reste vit dans des fichiers neufs remplis par les lots suivants :
## SurvivorPool / SurvivorGear (S2), SurvivorCards (S3), SurvivorDirector (S4), SurvivorRewards (S6).
##
## Le hub n'est JAMAIS modifié : comme la Survie, l'équipement du hub est copié au départ (Profile.begin_run) et remis à
## la fin (Profile.end_run_survival) ; en plus, tout ce qui est progression du compte (HUB_KEYS : records, coffres,
## insignes, réserve…) est photographié au départ, écrit tel quel par chaque sauvegarde faite en pleine run (une
## fermeture du jeu en pleine run ne garde rien) et remis à la fin de la run, avant les récompenses du Survivant.
##
## `Run.survival` reste vrai pendant un Survivant (comme le Battle royale) : la carte générée, les coffres, les cartes et
## les lieux de la Survie servent de base, et chaque différence passe par un crochet `Survivor.active` / `sv`.

## Visible et jouable par tous dès le départ (lot S8, DECISIONS §5 : aucun verrou lié à la progression du compte).
const READY := true
const RUN_TIME := 1200.0  # 20 minutes de carte, puis le boss
const BOSS_OPEN_AT := 900.0  # le portail du boss s'ouvre à 15:00 (entrée en avance possible)
const GUARDIAN_TIMES := [300.0, 600.0, 900.0]  # géants gardiens à 5, 10 et 15 minutes
const SPELL_MAX := 6  # sorts pris au plus (4 cases + enchaînements)
const MAX_ITEM_LEVEL := 90  # puissance des pièces : celle du héros, plafonnée à 90
const UP_STEP := 2  # +N d'une carte d'amélioration de pièce (commune)
const WAKE_AT := [6, 8, 10]  # paliers où une pièce gagne un passif
const BASE_REROLLS := 2  # relances offertes de base
const BANS := 3

## --- Équilibrage (lot S7, conception/survivor/R_S7.md : mesures au pilote, tools/sim_survivor.py) -------------------
## Valeurs lues par le profil « survivor » de ModeRules (modifiables en mode dev) ; le détail des mesures est dans R_S7.
## Cibles : run de 20 min ; niveau 38 (± 4) à 20:00 ; gardiens vaincus en 30-90 s par un build correct ; boss final en
## 1 min 30 à 3 min pour une bonne run, rage du boss (4:00) pour une run sans synergie ; victoire ≈ 35-50 % au joueur moyen.
## Héros : expérience × XP_START au niveau 1 → × XP_END au niveau XP_UNTIL → × XP_LATE au niveau XP_LATE_AT et au-delà
## (à la place de Epochs.xp_boost). Sans la 3e borne le héros prenait 3 à 5 niveaux par minute après 12:00 (horde dense,
## il tue tout) : niveau 53 à 20:00 pour une cible de 38, et des monstres de 16 niveaux en dessous.
const XP_START := 2.0
const XP_END := 1.15
const XP_UNTIL := 10
const XP_LATE := 0.35
const XP_LATE_AT := 35
## Monstres (SurvivorDirector.spawn_plan) : niveau 1 + LEVEL_PER_MIN par minute ; PV × HP0 × HP_GROWTH^minutes, dégâts
## × ATK0 × ATK_GROWTH^minutes ; vivants ALIVE[0] → ALIVE[1] ; meutes toutes les PACK_EVERY s de PACK_SIZE monstres
## (budget de SpawnDirector, deux escouades de deux côtés dès PACK_SPLIT) ; vagues (événements de SpawnDirector) toutes
## les WAVE_EVERY s, budget × SPAWN_PACE ; élites ponctuelles dès ELITES_FROM s, toutes les ELITE_EVERY s.
const LEVEL_PER_MIN := 1.8
const HP0 := 0.5
const HP_GROWTH := 1.12
const ATK0 := 0.5
const ATK_GROWTH := 1.07
const ALIVE := [18, 110]
const PACK_EVERY := [6.0, 1.8]
const PACK_SIZE := [3, 12]
const PACK_SPLIT := 7.0
const WAVE_EVERY := [45.0, 25.0]
const SPAWN_PACE := [0.7, 0.7]
const ELITES_FROM := 480.0
const ELITE_EVERY := [40.0, 20.0]
## Ouverture (le héros part nu, niveau 1, parfois sans arme) : dégâts des monstres × OPENING[0] et PV × OPENING[1] à 0:00,
## × 1 à OPENING[2] s ; 1re vague à FIRST_WAVE s ; vagues « dures » (encerclement ou escorte, avec une élite) seulement dès
## HARD_WAVES_FROM s, élites des camps dès CAMPS_FROM s. Mesuré avant : 4 runs sur 15 perdues avant 2:30 (élites de camp et
## escorte dans la 1re minute), puis 5 sur 10 sans elles (50 monstres la 1re minute, le héros nu en tue 20 à 30).
const OPENING := [0.3, 0.6, 180.0]
const FIRST_WAVE := 75.0
const HARD_WAVES_FROM := 240.0
const CAMPS_FROM := 180.0
## Puissance des monstres selon l'équipement de la RUN (pas du hub : le Survivant n'en a pas) : indice d'équipement
## (MonsterScaling.gear_index, pièces portées / PE attendue au niveau du héros) comparé à la bande [bas, haut] attendue à
## chaque minute (POWER_BAND, une ligne toutes les 5 min, mesurée au pilote moyen) ; dans la bande rien ne change ; au-dessus
## les monstres ordinaires prennent jusqu'à POWER_HP[1] PV et POWER_ATK[1] dégâts, en dessous ils perdent jusqu'à
## POWER_HP[0] / POWER_ATK[0] (un tirage pauvre n'est jamais une run perdue) ; lissé (MonsterScaling.SMOOTH_TIME) ; gardiens
## et boss jamais (PV fixes).
const POWER_BAND := [[0.0, 0.25], [1.0, 1.25], [1.4, 1.6], [1.65, 2.0], [1.85, 2.3]]
const POWER_HP := [0.9, 1.3]
const POWER_ATK := [0.9, 1.15]
## Gardiens (5 / 10 / 15 min) et boss final : PV FIXES (× palier × Menace), rage du boss après BOSS_RAGE_AT s d'arène.
## Dégâts du boss × BOSS_ATK × palier (et non la courbe des monstres ordinaires, ×1,93 à 20:00 : deux fois ceux du boss d'une
## carte de Survie ; le pilote moyen tombait en 30 s dans l'arène). S8 : 1 -> 1,4 : le pilote dépense désormais son or (coffres,
## marchands : ~85 cartes à 20:00 au lieu de 70) et battait le boss en 1:35 ; le débutant gagnait autant que le joueur moyen (60 %).
const GUARDIAN_HP := [50000.0, 220000.0, 700000.0]
const BOSS_HP := 6000000.0
const BOSS_RAGE_AT := 240.0
const BOSS_ATK := 1.4
## Butin des monstres : potions seulement (part des monstres ordinaires, des élites).
const POTION_DROP := [0.03, 0.3]
## Garde-fous du build : critique (physique et magique) plafonnée à CRIT_CAP, le surplus devient des dégâts critiques
## (× CRIT_OVERFLOW) ; dégâts critiques au plus + CRIT_DMG_CAP, vitesses d'attaque et d'incantation au plus × SPEED_CAP ;
## plafond d'un passif cumulé = son max (statistiques entières) ou PASSIVE_CAP_MULT × max. Mesuré avant (sonde, niveau
## 38) : critique 300 % (perdue au-delà de 100 %), dégâts critiques +300 %, vitesse d'attaque ×3,2 en médiane et ×4 au plus :
## les attributs des pièces de niveau 90 (chance, agilité) se multiplient entre eux, et un build « tout en pièces +10 »
## faisait ×2,7 les dégâts du build médian.
const CRIT_CAP := 0.75
const CRIT_OVERFLOW := 0.25
const CRIT_DMG_CAP := 2.5
const SPEED_CAP := 2.5
const PASSIVE_CAP_MULT := 1.5
## Pitié de l'offre : après PITY_DRY choix de niveau d'affilée sans carte forte (SurvivorCards.is_strong), l'offre suivante
## a ses améliorations au moins PITY_TIER (et une carte forte garantie).
const PITY_DRY := 3
const PITY_TIER := "epic"

## --- Paliers de difficulté I à V (lot S8, SPEC §8.5, conception/survivor/R_S8.md) -----------------------------------
## Chaque palier garde les règles du précédent et en ajoute UNE, lisible (`rule`, une phrase courte affichée au lobby ; le
## détail chiffré est dans l'infobulle `tip`). Les PV et dégâts des monstres, gardiens et boss sont × `palier_mult` du profil
## « survivor » (ModeRules, modifiable en mode dev). Clés : speed (vitesse des monstres ×), heal_half (soins reçus ÷ 2),
## menace (Menace de départ, P12 : PV des monstres, gardiens et boss), bricks (mécaniques de boss ajoutées au boss final,
## BossBricks), twin (un second gardien à 15:00), rage_at (rage du boss, s d'arène), revives (résurrections).
## Un palier s'ouvre en gagnant le précédent dans ce mode (SurvivorRewards.wins) ; le mode dev les ouvre tous.
## Mesures (pilote, profil « bon » 0,7, cibles : II ≈ 30 %, III ≈ 20 %, IV ≈ 10 %, V ≈ 3-5 % de victoires) : R_S8.
const PALIERS := [
	{"name": "Normal", "rule": "La run de base", "tip": "Vingt minutes, trois gardiens, le boss à 20:00.",
		"speed": 1.0, "heal_half": false, "menace": 0, "bricks": 0, "twin": false, "rage_at": 240.0, "revives": 1},
	{"name": "Endurci", "rule": "Monstres plus rapides", "tip": "Monstres, gardiens et boss plus résistants et plus forts ; les monstres courent plus vite.",
		"speed": 1.15, "heal_half": false, "menace": 0, "bricks": 0, "twin": false, "rage_at": 240.0, "revives": 1},
	{"name": "Implacable", "rule": "Soins reçus divisés par deux", "tip": "En plus : tous les soins que tu reçois sont divisés par deux.",
		"speed": 1.15, "heal_half": true, "menace": 0, "bricks": 0, "twin": false, "rage_at": 240.0, "revives": 1},
	{"name": "Cauchemar", "rule": "Menace dès le départ, boss plus retors", "tip": "En plus : la Menace part à 2 et le boss final a une mécanique de plus.",
		"speed": 1.15, "heal_half": true, "menace": 2, "bricks": 1, "twin": false, "rage_at": 240.0, "revives": 1},
	{"name": "Légende", "rule": "Deux gardiens à 15:00, boss enragé plus tôt", "tip": "En plus : deux gardiens surgissent à 15:00, le boss a deux mécaniques de plus et enrage après 3 minutes.",
		"speed": 1.2, "heal_half": true, "menace": 2, "bricks": 2, "twin": true, "rage_at": 180.0, "revives": 1},
]
const NUMERALS := ["I", "II", "III", "IV", "V"]
## Le multiplicateur du palier s'installe sur les monstres ordinaires pendant les PALIER_RAMP premières secondes (le héros
## part nu : au palier V, sans ça, 5 pilotes sur 5 tombaient avant 2:30) ; gardiens et boss l'ont en entier.
const PALIER_RAMP := 300.0
## Mécaniques que les paliers IV et V ajoutent au boss final, dans l'ordre (la première absente de son kit) : des briques
## « every » annoncées (au sol ou orbes visibles), lisibles, d'une famille qu'il n'a pas (six familles différentes).
const EXTRA_BRICKS := ["marks", "ring_burst", "sweep", "leap", "stomp", "swarm"]

## Propriétés du profil qui forment la progression du compte : gardées intactes par un Survivant (voir l'en-tête).
## Les choix d'apparence (tenue, accessoires, titre porté) et le tutoriel n'en font pas partie.
const HUB_KEYS := ["seen_gear", "insignia", "materials", "stash", "expertise", "talents", "certificates", "unlocked_classes",
	"records", "cert_board", "archive", "collection", "owned_outfits", "unlocked_cards", "unlocked_zones", "reward_chests",
	"runs_done", "runs_won", "best_level", "starter_done", "wheel", "unlocked_features", "new_features", "contracts",
	"achievements", "plans", "pantheon", "extra_titles", "seen_trophies", "weapon_legend"]

static var active := false  # vrai du lancement à la fin de la run (Run.finish) ; Run.survivor reste vrai pour le bilan
static var zone_id := "limestone"  # zone choisie (décor, monstres, boss) ; gardée pour « Rejouer »
static var palier := 1  # difficulté I à V (lot S8)
static var bans_used := 0
static var picks := {}  # famille de carte -> nombre de cartes prises (journal, S3)
static var since := {}  # cible -> choix depuis sa dernière apparition (pitié, S3)
static var dry := 0  # choix de niveau d'affilée sans carte forte (pitié de l'offre, S7)
static var pity_given := 0  # offres garanties données dans la run (journal, mesures)
static var _hub := {}  # instantané de la progression du compte (HUB_KEYS)
static var lobby_request := ""  # bilan -> lobby : "class" ouvre la page du mode et le choix de classe (lu une fois par le lobby)


## Remise à zéro (en tête de Run.start : tout autre mode lancé ensuite repart sans Survivant).
static func reset() -> void:
	active = false
	bans_used = 0
	picks = {}
	since = {}
	dry = 0
	pity_given = 0
	_hub = {}
	SurvivorRewards.reset()


## Zones jouables : celles des époques de la Survie (8 décors) ; aucune ne demande de progression.
static func zones() -> Array:
	var out: Array = []
	for i in range(1, Epochs.count() + 1):
		for z in Epochs.get_def(i).zones:
			if not String(z) in out:
				out.append(String(z))
	return out


## Lance un Survivant de la classe [param cid] dans la zone [param zone] au palier [param p] : héros niveau 1, sans arme,
## sans pièce, sans fourniture. La carte et le monde viennent ensuite (scène du jeu).
static func start(cid: String, zone: String, p := 1) -> void:
	var z := zone if zone in zones() else String(zones()[0])
	var stash: Dictionary = Profile.stash.duplicate(true)
	Run.start(cid)  # Survivor.reset(), puis Profile.begin_run : copies de l'équipement du hub, réserve dans le sac
	Profile.stash = stash  # la réserve reste au hub (begin_run l'avait mise dans le sac du héros)
	Profile.bag = {}
	Potions.start_run()  # seulement les potions de départ de toute run
	Profile.equipped = {}
	Profile.inventory = []
	_hub = _snapshot()
	active = true
	zone_id = z
	palier = clampi(p, 1, 5)
	Run.survivor = true
	Run.survival = true  # socle de la Survie (carte, coffres, cartes, lieux) ; les écarts passent par les crochets
	Run.epoch = 1  # la difficulté vient du temps et du palier, jamais de la zone (SPEC §1.2)
	Run.stage = 1
	Run.zone_id = z
	Run.start_zone = z
	# palier : « soins reçus ÷ 2 » passe par la table commune des modificateurs (Combatant.heal) ; retirée par finish
	ModeRules.modifiers = ["heal_half"] if bool(tier_rule("heal_half")) else []
	Profile.save_profile()  # la réserve remise est écrite tout de suite
	Run.changed.emit()


## Fin de la run (Run.finish) : la progression du compte est remise telle qu'au départ, le sac vidé (rien ne rejoint
## la réserve), puis les récompenses propres au Survivant (S6). Renvoie les propriétés qui avaient bougé (tests).
static func finish(res: String, counted_kills: int) -> Array:
	var moved := restore_hub()
	Profile.bag = {}
	active = false
	ModeRules.modifiers = []  # (règles du palier : rien ne suit le héros dans un autre mode)
	SurvivorRewards.settle(res, counted_kills)
	return moved


## Remet les propriétés HUB_KEYS du profil telles qu'au lancement ; renvoie celles qui avaient changé.
static func restore_hub() -> Array:
	var moved: Array = []
	for k in _hub:
		if str(Profile.get(k)) != str(_hub[k]):
			moved.append(k)
		Profile.set(k, _copy(_hub[k]))
	_hub = {}
	return moved


## Sauvegarde faite en pleine run (Profile.save_profile) : les valeurs du hub remplacent celles de la run.
static func hub_save(d: Dictionary) -> void:
	if not active or _hub.is_empty():
		return
	for k in _hub:
		if k == "materials":
			d["crystals"] = int(_hub.materials.get("crystal", 0))
		elif d.has(k):
			d[k] = _hub[k]


static func _snapshot() -> Dictionary:
	var out := {}
	for k in HUB_KEYS:
		out[k] = _copy(Profile.get(k))
	return out


static func _copy(v: Variant) -> Variant:
	if v is Dictionary or v is Array:
		return v.duplicate(true)
	return v


## Carte propre au Survivant (types « sv_… », lots S2-S3) : appliquée par apply_card plutôt que par Run.
static func owns(card: Dictionary) -> bool:
	return active and String(card.get("type", "")).begins_with("sv_")


static func apply_card(card: Dictionary) -> void:
	SurvivorCards.apply(card)


## Type de l'arme portée (n'importe lequel des 17), sinon celui de la classe (le départ, sans arme).
static func weapon_type() -> String:
	var w: Dictionary = Profile.equipped.get("weapon", {})
	if not w.is_empty():
		return Items.weapon_type_of(w)
	return Items.default_weapon_type(Run.class_id)


## Animation d'auto-attaque de repli quand le modèle de la classe n'a pas celle de l'arme portée (§4.2) : les
## animations de la 1re variante de l'arme de la classe, dans le même ordre.
static func fallback_anim(cid: String, swing: int) -> String:
	var anims: Array = WeaponAttacks.variants(Items.default_weapon_type(cid))[0].get("anims", ["attack01"])
	return String(anims[swing % anims.size()])


## Multiplicateur d'expérience (à la place de Epochs.xp_boost) : xp_start au niveau 1, xp_end au niveau xp_until, puis
## en baisse jusqu'à xp_late au niveau xp_late_at et au-delà (lot S7).
static func xp_mult(level: int) -> float:
	var until := maxf(rule("xp_until"), 2.0)
	if level <= until:
		return lerpf(rule("xp_start"), rule("xp_end"), clampf((level - 1) / (until - 1.0), 0.0, 1.0))
	var late := maxf(rule("xp_late_at"), until + 1.0)
	return lerpf(rule("xp_end"), rule("xp_late"), clampf((level - until) / (late - until), 0.0, 1.0))


## Niveau maximal du héros : aucun plafond par carte (SPEC §8.1), seulement celui des monstres et des pièces (90,
## SurvivorDirector.MAX_LEVEL) ; [param default] (plafond de la Survie) hors Survivant.
static func level_cap(default: int) -> int:
	return SurvivorDirector.MAX_LEVEL if active else default


## Garde-fous des statistiques du héros (crochet de Player.recalc_stats, Survivant seulement) : critique physique et
## magique plafonnées à crit_cap, le surplus le plus grand devient des dégâts critiques (× crit_overflow) ; dégâts
## critiques, vitesses d'attaque et d'incantation plafonnés (voir CRIT_CAP en tête de fichier).
static func cap_hero(p: Object) -> void:
	var cap := rule("crit_cap")
	if not active or cap <= 0.0:
		return
	var over := maxf(maxf(float(p.crit) - cap, float(p.mcrit) - cap), 0.0)
	p.crit = minf(float(p.crit), cap)
	p.mcrit = minf(float(p.mcrit), cap)
	p.crit_dmg = minf(float(p.crit_dmg) + over * rule("crit_overflow"), rule("crit_dmg_cap"))
	p.atk_speed = minf(float(p.atk_speed), rule("speed_cap"))
	p.cast_speed = minf(float(p.cast_speed), rule("speed_cap"))


## Nombre de lieux [param kind] posés sur la carte : ni autel du scribe (fournitures du hub) ni autel de la fortune
## (insignes) en Survivant (SPEC §6.1).
static func station_count(kind: String, default: int) -> int:
	if active and kind in ["scribe", "fortune"]:
		return 0
	return default


## Récompense d'un sanctuaire : les sanctuaires « trophée » donnent une carte (pas de trophée en Survivant).
static func shrine_reward(default: String) -> String:
	if active and default == "trophy":
		return "card"
	return default


## Règle chiffrée du profil « survivor » (ModeRules, modifiable en mode dev).
static func rule(key: String) -> float:
	return ModeRules.num(key, 0.0, "survivor")


## Visible au menu Jouer : une fois le mode fini (READY), ou en mode dev pendant le développement.
static func visible() -> bool:
	return READY or bool(Settings.get_v("interface", "dev_mode"))


# --- paliers (lot S8) ---------------------------------------------------------------------------------------------------
## Règle [param key] du palier [param p] (défaut : celui de la run en cours), voir PALIERS.
static func tier_rule(key: String, p := -1) -> Variant:
	var t: Dictionary = PALIERS[clampi(p if p > 0 else palier, 1, PALIERS.size()) - 1]
	return t.get(key)


## « II » pour le palier 2.
static func numeral(p: int) -> String:
	return String(NUMERALS[clampi(p, 1, NUMERALS.size()) - 1])


## Palier [param p] ouvert : le I toujours ; les suivants après une victoire au précédent DANS CE MODE (aucun lien avec la
## progression du compte) ; tous en mode dev ([param dev] faux : par les victoires seulement).
static func palier_open(p: int, dev := true) -> bool:
	if p <= 1:
		return true
	if p > PALIERS.size():
		return false
	return (dev and bool(Settings.get_v("interface", "dev_mode"))) or SurvivorRewards.wins(p - 1) > 0


## Plus haut palier ouvert ([param dev] faux : ouvert par les victoires, le choix par défaut de la page du mode).
static func top_palier(dev := true) -> int:
	var top := 1
	for p in range(2, PALIERS.size() + 1):
		if palier_open(p, dev):
			top = p
	return top
