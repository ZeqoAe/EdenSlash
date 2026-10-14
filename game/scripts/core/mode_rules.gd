class_name ModeRules
extends RefCounted
## Règles chiffrées de chaque mode, à un seul endroit (conception, lot 4). Un profil par mode ;
## `rule("clé")` lit le profil du mode en cours (Modes.current()), avec dans l'ordre : la valeur du
## mode dev (data/dev_edits.json -> "modes"), puis les modificateurs actifs, puis la valeur du
## profil. Les valeurs de départ sont les chiffres actuels du jeu : rien ne change en jeu.
##
## Famille « héros contre héros » (PvpCaps) : dmg_scale, basic_mult, heal_mult, max_mitigation,
## pressure_start, pressure_step, caps. D'autres familles (monstres, héros, gains) rejoindront les
## profils quand leur consommateur sera branché (Survie, Donjon, Panthéon…).

const PVP := {
	"dmg_scale": PvpCaps.DAMAGE_SCALE, "basic_mult": PvpCaps.BASIC_MULT, "heal_mult": PvpCaps.HEAL_MULT,
	"max_mitigation": PvpCaps.MAX_MITIGATION, "pressure_start": PvpCaps.PRESSURE_START,
	"pressure_step": PvpCaps.PRESSURE_STEP, "caps": PvpCaps.CAPS,
}

## Profils par nom. « duel_a » (à l'arme) et « duel_b » (équipé) copient « duel » pour l'instant : le
## lot 5 les sépare. La Tour et l'entraînement n'ont pas de règles de duel propres (celles de « duel »
## s'appliquent quand Duel.active).
const PROFILES := {
	"duel": PVP,
	"duel_a": PVP,
	"duel_b": PVP,
}

## Profil imposé (arène d'IA : --rules=duel_a), prioritaire sur le mode en cours.
static var forced := ""
## Modificateurs actifs (ids de Modifiers.LIST).
static var modifiers: Array = []


static func profile_name() -> String:
	if forced != "":
		return forced
	var m := Modes.current()
	return m if PROFILES.has(m) else ""


## Valeur de la règle [param key] pour le profil [param profile] (défaut : celui du mode en cours) ;
## [param fallback] si le mode n'a pas de profil ou pas cette clé.
static func rule(key: String, fallback: Variant = null, profile := "") -> Variant:
	var p := profile if profile != "" else profile_name()
	if p == "":
		p = "duel"  # hors mode : les chiffres du duel (fiches, comparaisons)
	var base: Variant = PROFILES.get(p, {}).get(key, fallback)
	var edits: Dictionary = DevEdits.data.get("modes", {}).get(p, {})
	if edits.has(key):
		base = edits[key]
	return Modifiers.apply(key, base, modifiers)


static func num(key: String, fallback := 0.0, profile := "") -> float:
	return float(rule(key, fallback, profile))
