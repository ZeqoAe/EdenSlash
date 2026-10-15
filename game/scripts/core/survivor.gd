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

## Visible et jouable hors mode dev : passé à true à la fin du lot S6 (avant : visible en mode dev seulement).
const READY := false
const RUN_TIME := 1200.0  # 20 minutes de carte, puis le boss
const BOSS_OPEN_AT := 900.0  # le portail du boss s'ouvre à 15:00 (entrée en avance possible)
const GUARDIAN_TIMES := [300.0, 600.0, 900.0]  # géants gardiens à 5, 10 et 15 minutes
const SPELL_MAX := 6  # sorts pris au plus (4 cases + enchaînements)
const MAX_ITEM_LEVEL := 90  # puissance des pièces : celle du héros, plafonnée à 90
const UP_STEP := 2  # +N d'une carte d'amélioration de pièce (commune)
const WAKE_AT := [6, 8, 10]  # paliers où une pièce gagne un passif
const BASE_REROLLS := 2  # relances offertes de base
const BANS := 3

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
static var _hub := {}  # instantané de la progression du compte (HUB_KEYS)
static var lobby_request := ""  # bilan -> lobby : "class" ouvre la page du mode et le choix de classe (lu une fois par le lobby)


## Remise à zéro (en tête de Run.start : tout autre mode lancé ensuite repart sans Survivant).
static func reset() -> void:
	active = false
	bans_used = 0
	picks = {}
	since = {}
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
	Profile.save_profile()  # la réserve remise est écrite tout de suite
	Run.changed.emit()


## Fin de la run (Run.finish) : la progression du compte est remise telle qu'au départ, le sac vidé (rien ne rejoint
## la réserve), puis les récompenses propres au Survivant (S6). Renvoie les propriétés qui avaient bougé (tests).
static func finish(res: String, counted_kills: int) -> Array:
	var moved := restore_hub()
	Profile.bag = {}
	active = false
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


## Multiplicateur d'expérience (à la place de Epochs.xp_boost) : xp_start au niveau 1, xp_end à partir de xp_until.
static func xp_mult(level: int) -> float:
	var until := maxf(rule("xp_until"), 2.0)
	return lerpf(rule("xp_start"), rule("xp_end"), clampf((level - 1) / (until - 1.0), 0.0, 1.0))


## Niveau maximal du héros : aucun plafond par carte (SPEC §8.1), seulement celui des monstres et des pièces (90,
## SurvivorDirector.MAX_LEVEL) ; [param default] (plafond de la Survie) hors Survivant.
static func level_cap(default: int) -> int:
	return SurvivorDirector.MAX_LEVEL if active else default


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
