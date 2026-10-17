class_name RoyaleMods
extends RefCounted
## Modificateurs de partie du Battle royale (lot BR-R1, backlog BM-BR P1 n° 12 de `conception/benchmark/BATTLE_ROYALE.md`) :
## une règle simple qui change la partie sans changer le combat (l'équilibre du lot BR1 reste intact). Un modificateur « du
## jour » tourne chaque jour (jamais le même deux jours de suite, comme le Défi du jour) ; la partie classique est toujours là.
## La page du mode montre le modificateur choisi, l'annonce de départ le rappelle, les héros scriptés savent le jouer :
##   meteors : pluie de météores (zones fraise télégraphiées près des héros ; les scriptés et le pilote en sortent) ;
##   gold    : ruée vers l'or (chaque coffre de la carte et des vagues monte d'une qualité) ;
##   fast    : anneau pressé (attente × FAST_HOLD, resserrement × FAST_SHRINK : partie d'environ 6 min) ;
##   wells   : sources de vie (WELLS fontaines au lieu de 4 ; un scripté blessé va boire) ;
##   hunt    : chasse ouverte (tous les héros sur la carte, une élimination vaut HUNT_XP niveau de plus, traque dès le 2e anneau).
## Rien n'est enregistré ici : le modificateur de la partie est Royale.mod ("" : classique).

const LIST := [
	{"id": "meteors", "name": "Pluie de météores", "line": "Des météores tombent près des héros : sors vite du cercle rouge.",
		"tone": "fraise"},
	{"id": "gold", "name": "Ruée vers l'or", "line": "Chaque coffre monte d'une qualité : tout le monde s'équipe vite.", "tone": "soleil"},
	{"id": "fast", "name": "Anneau pressé", "line": "L'anneau attend moins : une partie de six minutes, sans temps mort.", "tone": "amethyste"},
	{"id": "wells", "name": "Sources de vie", "line": "Trois fois plus de fontaines : chacune rend tous les PV.", "tone": "pomme"},
	{"id": "hunt", "name": "Chasse ouverte", "line": "Tous les héros sont sur la carte et chaque élimination rapporte plus.", "tone": "mandarine"},
]
const CLASSIC := {"id": "", "name": "Classique", "line": "Les règles de toujours : coffres, largages, autel du gardien.", "tone": "papier"}

## Pluie de météores : la première tombe METEOR_FROM s après le départ de l'anneau, puis une vague toutes les METEOR_EVERY s
## (± METEOR_JITTER) ; chaque vague vise METEOR_PER_WAVE héros au hasard (jamais deux fois le même), à METEOR_OFFSET m au plus
## de lui. Zone de METEOR_RADIUS m annoncée METEOR_DELAY s ; un héros encore dedans (sans esquive) perd METEOR_DMG de ses PV max.
const METEOR_FROM := 40.0
const METEOR_EVERY := 9.0
const METEOR_JITTER := 2.0
const METEOR_PER_WAVE := 2
const METEOR_OFFSET := 5.0
const METEOR_RADIUS := 4.5
const METEOR_DELAY := 1.8
const METEOR_DMG := 0.12
## Anneau pressé : facteurs des temps d'attente et de resserrement de Royale.PHASES.
const FAST_HOLD := 0.55
const FAST_SHRINK := 0.8
## Sources de vie : fontaines de la carte (4 en classique) ; un scripté sous WELL_HP de ses PV va boire à moins de WELL_SIGHT m.
const WELLS := 12
const WELL_HP := 0.55
const WELL_SIGHT := 55.0
## Chasse ouverte : expérience en plus d'une élimination (en niveaux) ; traque dès cet anneau (2e) et plus loin.
const HUNT_XP := 0.5
const HUNT_PHASE := 1
const HUNT_REACH := 1.5


## Fiche du modificateur [param id] (CLASSIC pour "" ou un identifiant inconnu).
static func get_def(id: String) -> Dictionary:
	for m in LIST:
		if String(m.id) == id:
			return m
	return CLASSIC


static func ids() -> Array:
	return LIST.map(func(m): return String(m.id))


static func name_of(id: String) -> String:
	return String(get_def(id).name)


## Modificateur du jour [param day] (« AAAA-MM-JJ », le jour du système par défaut) : il tourne d'un cran chaque jour.
static func today_id(day := "") -> String:
	var dd := day if day != "" else League.today()
	var unix := Time.get_unix_time_from_datetime_string(dd + "T12:00:00")
	var n := int(floor(float(unix) / 86400.0))
	return String(LIST[posmod(n, LIST.size())].id)


## Le modificateur [param id] est-il celui de la partie en cours ?
static func on(id: String) -> bool:
	return Royale.mod == id


# --- règles lues par les autres scripts ---------------------------------------------------------------------
## Qualité d'un coffre de la carte ou d'une vague (0 commun, 1 rare, 2 doré ; le largage n'est pas concerné).
static func chest_tier(tier: int) -> int:
	return mini(tier + 1, 2) if on("gold") and tier < 2 else tier


## Fontaines de la carte du Battle royale.
static func well_count() -> int:
	return WELLS if on("wells") else 4


## Facteur des temps d'attente ([param shrink] : de resserrement) de l'anneau.
static func ring_factor(shrink: bool) -> float:
	if not on("fast"):
		return 1.0
	return FAST_SHRINK if shrink else FAST_HOLD


## Expérience en plus d'une élimination.
static func kill_bonus() -> float:
	return HUNT_XP if on("hunt") else 0.0


## Ligne courte de l'annonce de départ ({} en classique) : [titre, détail].
static func announce() -> Array:
	if Royale.mod == "":
		return []
	var m := get_def(Royale.mod)
	return [String(m.name), String(m.line)]
