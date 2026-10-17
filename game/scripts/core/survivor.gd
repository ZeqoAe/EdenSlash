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
## Sorts pris au plus : la grille entière de la run, comme en Survie (Run.MAX_SKILLS cases × (1 + Run.MAX_CHAIN) : le sort
## et ses deux enchaînements), soit 12 (lot S9 : 6 au départ, le joueur attendait sa grille complète). Contre la dilution,
## le poids d'amélioration de chaque sort baisse au-delà de spell_up_norm sorts (SurvivorCards.candidates).
const SPELL_MAX := 12
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
const ALIVE := [30, 230]
const PACK_EVERY := [2.5, 0.8]
const PACK_SIZE := [6, 16]
const PACK_SPLIT := 7.0
const WAVE_EVERY := [40.0, 22.0]
const SPAWN_PACE := [1.0, 2.0]
## Horde (lot SVX-1, conception/survivor/R_SVX1.md ; avant : ALIVE 18 → 110, meutes de 3 → 12 toutes les 6 → 1,8 s, arrivées à
## 24-31 m hors de la vue, monstres de la taille du héros : 0 à 4 monstres à l'écran à 2:30 et 5:00 au pilote). Horde finale
## (19:00) : ALIVE_FINAL vivants. Monstres ordinaires × HORDE_SCALE en taille (élites × HORDE_SCALE_ELITE), arrivées à
## HORDE_RING m (à l'écran) annoncées par une croix au sol HORDE_MARK s avant (SpawnMark), plafonds par rôle de SpawnDirector
## × HORDE_ROLE_CAP. Une horde plus dense est compensée monstre par monstre (la courbe par minute, la puissance selon
## l'équipement et les paliers ne changent pas) : PV × HORDE_SHARE[0], dégâts × [1], expérience × [2], or et potions × [3].
const ALIVE_FINAL := 290
const HORDE_SCALE := 0.6
const HORDE_SCALE_ELITE := 0.85
const HORDE_HEIGHT := 0.8  # (et jamais plus haut que 0,8 × le héros : yacks, golems)
const HORDE_RING := [13.0, 19.0]
const HORDE_MARK := 0.8
const HORDE_ROLE_CAP := 3.5
const HORDE_SHARE := [0.45, 0.6, 0.33, 0.25]
## Places d'attaque : au plus ATTACK_SLOTS[0] (à 0:00) → [1] (à 20:00) monstres de la horde frappent en même temps
## (Monster.attack_slots, suivi par SurvivorDirector.spawn_plan) ; les autres attendent au contact. Une horde dense entoure
## le héros sans multiplier les coups reçus (mesuré avec 8 places dès 0:00 : morts avant 6:00 au pilote débutant et moyen).
const ATTACK_SLOTS := [2, 12]
## Coût de la horde (même mesure) : monstres ordinaires sans collision physique (Monster.lite) ; les LOD_FULL plus proches
## à moins de LOD_NEAR m réfléchissent à chaque image, les autres une image sur 2 jusqu'à LOD_FAR m, une sur 4 au-delà ;
## ombre portée à moins de SHADOW_NEAR m.
const LOD_FULL := 40  # (au plus : les plus proches)
const LOD_NEAR := 6.0
const LOD_FAR := 18.0
const SHADOW_NEAR := 16.0
## Caméra : distance de départ × CAM_ZOOM en Survivant (la horde se voit à 15 m autour du héros ; la molette reste libre).
const CAM_ZOOM := 1.2
## Lisibilité du chaos (lot SVX-1, SV-H2) : décor tramé à moitié dans FOLIAGE_FADE m autour du héros (shader du décor,
## paramètre global hero_fade) ; effets des sorts du héros à FX_OPACITY au plus, puis adoucis quand ils s'empilent (EdenFx) ;
## nombres de dégâts fusionnés par cible, NUMBERS_MAX à l'écran au plus (DamageNumber) ; héros contouré (HeroOutline).
const FOLIAGE_FADE := 4.0
const FX_OPACITY := 0.4
const NUMBERS_MAX := 30
const ELITES_FROM := 480.0
const ELITE_EVERY := [40.0, 20.0]
## Ouverture (le héros part nu, niveau 1, parfois sans arme) : dégâts des monstres × OPENING[0] et PV × OPENING[1] à 0:00,
## × 1 à OPENING[2] s ; 1re vague à FIRST_WAVE s ; vagues « dures » (encerclement ou escorte, avec une élite) seulement dès
## HARD_WAVES_FROM s, élites des camps dès CAMPS_FROM s. Mesuré avant : 4 runs sur 15 perdues avant 2:30 (élites de camp et
## escorte dans la 1re minute), puis 5 sur 10 sans elles (50 monstres la 1re minute, le héros nu en tue 20 à 30).
const OPENING := [0.3, 0.6, 180.0]
const FIRST_WAVE := 60.0
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
## SVX-1 : gardiens 2 et 3 × 2 (220 000 / 700 000 avant) : la horde nourrit le héros (niveau 12 à 5:00 au lieu de 10) et le pilote
## qui va combattre le gardien le battait en 10-30 s (cible 30-90) ; le gardien 1 reste à 50 000 (× 2, il tuait le joueur moyen vers 6:00).
const GUARDIAN_HP := [50000.0, 440000.0, 1400000.0]
const BOSS_HP := 6000000.0
const BOSS_RAGE_AT := 240.0
const BOSS_ATK := 1.4
## Coup du boss final plafonné (lot SVX-4, SurvivorDirector._cap_boss) : part des PV max du héros au plus.
const BOSS_HIT_CAP := 0.35
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
## Pièces maudites (lot SVX-4, SV-R2, SurvivorGear.CURSES) : une pièce tirée sur CURSE_EVERY.
const CURSE_EVERY := 15.0

## --- Paliers de difficulté I à V (lot S8, SPEC §8.5, conception/survivor/R_S8.md) -----------------------------------
## Chaque palier garde les règles du précédent et en ajoute UNE, lisible (`rule`, une phrase courte affichée au lobby ; le
## détail chiffré est dans l'infobulle `tip`). Les PV et dégâts des monstres, gardiens et boss sont × `palier_mult` du profil
## « survivor » (ModeRules, modifiable en mode dev). Clés : speed (vitesse des monstres ×), heal_half (soins reçus ÷ 2),
## menace (Menace de départ, P12 : PV des monstres, gardiens et boss), bricks (mécaniques de boss ajoutées au boss final,
## BossBricks), twin (un second gardien à 15:00), rage_at (rage du boss, s d'arène), revives (résurrections).
## Un palier s'ouvre en gagnant le précédent dans ce mode (SurvivorRewards.wins) ; le mode dev les ouvre tous.
## Mesures (pilote, profil « bon » 0,7, cibles : II ≈ 30 %, III ≈ 20 %, IV ≈ 10 %, V ≈ 3-5 % de victoires) : R_S8.
const PALIERS := [
	{"name": "Normal", "rule": "La partie de base", "tip": "Vingt minutes, trois gardiens, le boss à 20:00.",
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
## Vitesse du jeu de la partie (lot SVX-4, SV-A1 : réglage interface/sv_speed, ×0,8 / ×1 / ×1,2) : hors records, hors partie
## du jour (SurvivorRecords, SurvivorDaily) ; posée par SurvivorDirector.update (Engine.time_scale), remise par finish.
const SPEEDS := [0.8, 1.0, 1.2]
static var speed := 1.0
static var boss_down := false  # (lot SVX-4) boss final vaincu : la partie est gagnée (prolongations comprises)


## Remise à zéro (en tête de Run.start : tout autre mode lancé ensuite repart sans Survivant).
static func reset() -> void:
	active = false
	RenderingServer.global_shader_parameter_set("hero_fade", 0.0)  # (décor tramé autour du héros : Survivant seulement)
	Monster.attack_slots = 0  # (places d'attaque de la horde : Survivant seulement)
	Monster.lite_height = 0.0
	Monster.attacking = 0
	bans_used = 0
	picks = {}
	since = {}
	dry = 0
	pity_given = 0
	_hub = {}
	SurvivorRewards.reset()
	SurvivorShop.reset()  # (lot SVX-4) boutique du gardien
	SurvivorFavors.current = ""
	SurvivorDaily.active = false
	speed = 1.0
	boss_down = false


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
static func start(cid: String, zone: String, p := 1, favor := "-") -> void:
	var z := zone if zone in zones() else String(zones()[0])
	var stash: Dictionary = Profile.stash.duplicate(true)
	# (lot SVX-4) faveur de départ : celle donnée, sinon celle choisie à la page du mode (--favor=<id> pour les mesures)
	var fav := SurvivorFavors.chosen() if favor == "-" else favor
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--favor="):
			fav = arg.trim_prefix("--favor=")
	Run.start(cid)  # Survivor.reset(), puis Profile.begin_run : copies de l'équipement du hub, réserve dans le sac
	SurvivorFavors.current = fav if not SurvivorFavors.get_def(fav).is_empty() else ""
	Run.seed = 0  # (lot SVX-4) carte au hasard ; la partie du jour (SurvivorDaily.start) pose la sienne ensuite
	speed = clampf(float(Settings.get_v("interface", "sv_speed")), SPEEDS[0], SPEEDS[SPEEDS.size() - 1])
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
	RenderingServer.global_shader_parameter_set("hero_fade", 0.0)
	Monster.attack_slots = 0
	Monster.lite_height = 0.0
	if not is_equal_approx(speed, 1.0):
		Engine.time_scale = 1.0  # (lot SVX-4) vitesse du jeu remise
	ModeRules.modifiers = []  # (règles du palier : rien ne suit le héros dans un autre mode)
	if res != SurvivorSave.RESULT:  # (lot SVX-4) partie sauvée pour plus tard : rien n'est réglé (elle reprendra)
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
	var fav := SurvivorFavors.mult("xp")  # (lot SVX-4) faveur « Érudit »
	if level <= until:
		return lerpf(rule("xp_start"), rule("xp_end"), clampf((level - 1) / (until - 1.0), 0.0, 1.0)) * fav
	var late := maxf(rule("xp_late_at"), until + 1.0)
	return lerpf(rule("xp_end"), rule("xp_late"), clampf((level - until) / (late - until), 0.0, 1.0)) * fav


## Niveau maximal du héros : aucun plafond par carte (SPEC §8.1), seulement celui des monstres et des pièces (90,
## SurvivorDirector.MAX_LEVEL) ; [param default] (plafond de la Survie) hors Survivant.
static func level_cap(default: int) -> int:
	return SurvivorDirector.MAX_LEVEL if active else default


## Garde-fous des statistiques du héros (crochet de Player.recalc_stats, Survivant seulement) : critique physique et
## magique plafonnées à crit_cap, le surplus le plus grand devient des dégâts critiques (× crit_overflow) ; dégâts
## critiques, vitesses d'attaque et d'incantation plafonnés (voir CRIT_CAP en tête de fichier).
static func cap_hero(p: Object) -> void:
	if active:
		SurvivorGear.apply_curses(p)  # (lot SVX-4) pièces maudites : bonus et contrepartie, avant les plafonds
		SurvivorFavors.apply_hero(p)  # (lot SVX-4) faveur de départ (Canon de verre, Course folle…)
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
