class_name Menace
extends RefCounted
## Menace et pacte (passe P12, idée du joueur inspirée de Megabonk) : prendre un risque sur la carte pour
## mieux finir la run.
## - **Menace** : chaque géant vaincu (autel du géant, `GiantAltar`) monte la Menace d'un cran : PV des monstres
##   vivants de la carte, de tous les monstres suivants et des boss suivants × (1 + STEP × niveau), jusqu'à la
##   fin de la run (plafond MAX). Les dégâts ne changent pas. Une Menace élevée rapporte des insignes en plus.
## - **Pacte** : l'autel de cupidité (`RunDirector.greed`, une fois par carte) : or et butin ×1,5, monstres
##   plus forts jusqu'à la fin de la carte ; les insignes de la carte sont aussi ×1,5 (au prorata des cartes).
## Tout est remis à zéro au début de chaque run (`RunDirector.start`) : le JcJ, la Tour et le Battle royale
## n'ont ni géant ni pacte, la Menace y reste à 0.

const STEP := 0.2  # PV des monstres et des boss par cran de Menace (+20 %, idée du joueur)
const MAX := 5  # plafond : ×2 sur les PV (5 géants sur les 6 autels d'une run de 3 cartes)
const INSIGNIA_PER_LEVEL := 0.1  # insignes de fin de run +10 % par cran de Menace
const PACT_INSIGNIA := 0.5  # pacte : insignes +50 %, au prorata des cartes jouées sous pacte

static var level := 0
static var giants_summoned := 0
static var giants_killed := 0
static var pact_maps := 0  # cartes où le pacte a été pris (une fois par carte au plus)
static var insignia_extra := 0  # insignes ajoutés par Run.finish (bilan : ligne « Menace et pacte »)


static func reset() -> void:
	level = 0
	giants_summoned = 0
	giants_killed = 0
	pact_maps = 0
	insignia_extra = 0


## Multiplicateur de PV des monstres et des boss au niveau de Menace [param n] (en cours par défaut).
static func hp_mult(n := -1) -> float:
	return 1.0 + STEP * float(clampi(level if n < 0 else n, 0, MAX))


## Texte court : « ×1,2 ».
static func mult_text(n := -1) -> String:
	return "×" + RunDirector.fmt_mult(snappedf(hp_mult(n), 0.01))


## Met le monstre [param m] au multiplicateur de Menace en cours (PV gardés en proportion), une seule fois par
## cran. Boss : appliqué à la fin de l'image, après le réglage de ses PV fixes (passe P11) qui suit sa création.
static func apply(m: Monster) -> void:
	if m == null or level <= 0:
		return
	if m.is_boss:
		(func(): apply_now(m)).call_deferred()
	else:
		apply_now(m)


static func apply_now(m: Monster) -> void:
	if not is_instance_valid(m) or m.is_dead or m.team != Combatant.Team.MONSTER:
		return
	var k := hp_mult() / float(m.get_meta("menace_mult", 1.0))
	if is_equal_approx(k, 1.0):
		return
	m.max_hp *= k
	m.hp *= k
	m.set_meta("menace_mult", hp_mult())


## Un géant vaincu : la Menace monte d'un cran (si sous le plafond) et tous les monstres vivants la prennent.
## Renvoie vrai si elle a monté.
static func raise(tree: SceneTree) -> bool:
	giants_killed += 1
	if level >= MAX:
		return false
	level += 1
	for node in tree.get_nodes_in_group("monsters"):
		apply_now(node as Monster)
	return true


## Pacte pris sur la carte en cours : les monstres déjà là deviennent aussi plus forts.
static func pact_taken(tree: SceneTree, monsters_mult: float) -> void:
	pact_maps += 1
	for node in tree.get_nodes_in_group("monsters"):
		var m := node as Monster
		if m == null or m.is_dead or m.is_boss or m.team != Combatant.Team.MONSTER or m.has_meta("pact"):
			continue
		m.set_meta("pact", true)
		m.max_hp *= monsters_mult
		m.hp *= monsters_mult
		m.atk *= monsters_mult


## Multiplicateur des insignes de fin de run : Menace atteinte et cartes jouées sous pacte.
static func insignia_mult(stages: int) -> float:
	return 1.0 + INSIGNIA_PER_LEVEL * float(level) + PACT_INSIGNIA * float(pact_maps) / float(maxi(stages, 1))


## Run.finish : ajoute la part « Menace et pacte » aux insignes [param gain] de la run (retenue pour le bilan).
static func add_insignia(gain: int, stages: int) -> int:
	insignia_extra = roundi(float(gain) * (insignia_mult(stages) - 1.0))
	return gain + insignia_extra


## Infobulle du HUD : le détail chiffré (le texte permanent n'en porte pas).
static func tooltip(pact_now: bool) -> String:
	var lines: PackedStringArray = []
	if level > 0:
		lines.append("Menace %d / %d : PV des monstres et des boss %s jusqu'à la fin de la run." % [level, MAX, mult_text()])
		lines.append("Insignes de fin de run +%d %%." % roundi(INSIGNIA_PER_LEVEL * 100.0 * level))
		if level >= MAX:
			lines.append("Menace au maximum : les géants ne la font plus monter.")
	if pact_now:
		lines.append("Pacte de cupidité : jusqu'à la fin de la carte, monstres plus forts (+%d %%), or, butin et insignes ×1,5." % roundi((RunDirector.GREED_MONSTERS - 1.0) * 100.0))
	return "\n".join(lines)


## Champs du journal de run (une ligne par carte).
static func journal(pact_now: bool) -> Dictionary:
	return {"menace": level, "giants_summoned": giants_summoned, "giants_killed": giants_killed, "pact": pact_now, "pact_maps": pact_maps}
