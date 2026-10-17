class_name StatusDb
extends RefCounted
## Présentation des effets d'état : icône, buff ou debuff, description courte.
## Icônes d'Eden quand elles existent (compétences du Samouraï), sinon les icônes
## dessinées de assets/ui/status/ (même nom que l'effet : une vraie icône extraite du
## client déposée sous ce nom remplace automatiquement la nôtre).

const STATUS_DIR := "res://assets/ui/status/%s.png"
const EDEN_ICONS := {
	"bleed": "res://assets/ui/skills/e0459.png",
	"solar": "res://assets/ui/skills/e0460.png",
	"scar": "res://assets/ui/skills/e0461.png",
	"purgatory": "res://assets/ui/skills/e0462.png",
	"cranes": "res://assets/ui/skills/e0463.png",
	"marduk": "res://assets/ui/skills/e0464.png",
	"shrine": "res://assets/ui/skills/e0467.png",
}
const BUFFS := ["solar", "shrine", "marduk", "frenzy", "keen", "haste", "barrier", "fury", "flow", "regen", "invisible", "evasion",
	"titan", "survival", "might", "swift", "grace", "vitality", "hunter_stance", "angel", "thorns", "resolve",
	"t_agi", "t_mind", "t_str", "t_arcane", "t_all", "t_luck", "t_crit", "t_speed", "t_power", "t_guard", "t_evade",
	"spell_str", "spell_agi", "spell_int", "spell_wis", "t_riposte", "t_wind", "t_berserk", "t_vamp", "t_harvest"]
const DESC := {
	"bleed": "Perd 15 % de l'attaque de la source en PV chaque seconde.",
	"burn": "Perd 25 % de l'attaque de la source en PV chaque seconde.",
	"purgatory": "Subit 20 % de dégâts en plus.",
	"cranes": "Subit 15 % de dégâts en plus.",
	"shock": "Subit 15 % de dégâts en plus.",
	"scar": "Inflige 30 % de dégâts en moins.",
	"stun": "Ne peut plus agir.",
	"imm_stun": "Vient d'être renversé : ne peut pas l'être de nouveau tout de suite (les autres contrôles passent).",
	"imm_freeze": "Vient d'être gelé : ne peut pas l'être de nouveau tout de suite (les autres contrôles passent).",
	"imm_sleep": "Vient d'être endormi : ne peut pas l'être de nouveau tout de suite (les autres contrôles passent).",
	"imm_fear": "Vient d'être terrifié : ne peut pas l'être de nouveau tout de suite (les autres contrôles passent).",
	"imm_root": "Vient d'être immobilisé : ne peut pas l'être de nouveau tout de suite (les autres contrôles passent).",
	"imm_disarm": "Vient d'être désarmé : ne peut pas l'être de nouveau tout de suite (les autres contrôles passent).",
	"freeze": "Pris dans la glace : ne peut ni bouger ni attaquer.",
	"chill": "Vitesse de déplacement réduite de 45 %.",
	"solar": "Dégâts subis réduits de 25 %.",
	"shrine": "+30 % de vitesse, dégâts subis réduits de 30 %.",
	"marduk": "+30 % d'attaque et de vitesse d'attaque.",
	"frenzy": "+30 % de vitesse d'attaque.",
	"keen": "+25 % de chances de coup critique.",
	"haste": "+30 % de vitesse de déplacement.",
	"barrier": "Dégâts subis réduits de 40 %.",
	"fury": "+25 % de dégâts infligés.",
	"flow": "Annulations parfaites : +10 % de dégâts par palier.",
	"poison": "Perd 20 % de l'attaque de la source en PV chaque seconde.",
	"regen": "Rend 3 % des PV max chaque seconde.",
	"invisible": "Les monstres perdent ta trace ; attaquer ou lancer un sort la rompt.",
	"evasion": "40 % de chances d'éviter complètement un coup.",
	"titan": "Dégâts subis réduits de 50 %, vitesse réduite de 60 %.",
	"survival": "+20 % de PV max et +15 % de soins reçus.",
	"might": "+30 % de force.",
	"swift": "+30 % d'agilité.",
	"grace": "+30 % d'intelligence et de sagesse.",
	"vitality": "+15 % de PV max.",
	"hunter_stance": "Les attaques de base ont 20 % de chances d'électrocuter la cible.",
	"disarm": "Ne peut plus attaquer.",
	"angel": "Te relève une fois à 30 % des PV si tu tombes.",
	"root": "Immobilisé : ne peut plus se déplacer, mais attaque encore.",
	"sleep": "Endormi : ne peut plus agir ; un coup le réveille.",
	"fear": "Terreur : fuit sans attaquer.",
	"thorns": "Renvoie 30 % des dégâts reçus à l'attaquant.",
	"resolve": "Insensible aux contrôles, dégâts subis réduits de 15 %.",
	"spell_str": "Sort amélioré : Force accrue.",
	"spell_agi": "Sort amélioré : Agilité accrue.",
	"spell_int": "Sort amélioré : Intelligence accrue.",
	"spell_wis": "Sort amélioré : Sagesse accrue.",
	"t_riposte": "Trophée : critique et dégâts critiques accrus après une esquive.",
	"t_wind": "Trophée : Agilité et vitesse d'attaque accrues après une esquive.",
	"t_berserk": "Trophée : dégâts et vitesse d'attaque accrus sous 30 % de PV.",
	"t_vamp": "Trophée : vol de vie.",
	"t_harvest": "Trophée : vitesse et dégâts accrus après une élimination.",
	"t_agi": "Trophée : Agilité accrue.",
	"t_mind": "Trophée : Agilité et Intelligence accrues.",
	"t_str": "Trophée : Force accrue.",
	"t_arcane": "Trophée : Intelligence et Sagesse accrues.",
	"t_all": "Trophée : tous les attributs accrus.",
	"t_luck": "Trophée : Chance accrue.",
	"t_crit": "Trophée : chances et dégâts critiques accrus.",
	"t_speed": "Trophée : vitesse d'attaque et d'incantation accrues.",
	"t_power": "Trophée : dégâts accrus.",
	"t_guard": "Trophée : défense accrue.",
	"t_evade": "Trophée : esquive et vitesse de déplacement accrues.",
}


static var _skill_icons := {}


const SPELL_ICONS := {"spell_str": "fury", "spell_agi": "haste", "spell_int": "keen", "spell_wis": "regen"}


static func icon(status: String) -> Texture2D:
	if status.begins_with("imm_"):  # insensibilité à un contrôle : icône du contrôle
		status = status.trim_prefix("imm_")
	if Trophies.STATUSES.has(status):  # buffs des trophées : icône du buff le plus proche
		status = String(Trophies.STATUSES[status].icon)
	if SPELL_ICONS.has(status):  # bonus d'attribut des sorts améliorés
		status = String(SPELL_ICONS[status])
	var own := STATUS_DIR % status
	if FileAccess.file_exists(own):
		return UiTheme.texture(own)
	if EDEN_ICONS.has(status):
		return UiTheme.texture(String(EDEN_ICONS[status]))
	var sk := String(_skill_icon_map().get(status, ""))
	return UiTheme.texture(sk) if sk != "" else Ico.tex("st_" + status, 40)  # dernier recours : pictogramme maison (lot ICO-1)


## Icône d'Eden du sort qui donne l'effet (buff du sort ou effet appliqué aux monstres),
## toutes classes confondues : chaque nouvel effet de classe a ainsi son icône.
static func _skill_icon_map() -> Dictionary:
	if _skill_icons.is_empty():
		for cid in GameData.classes:
			for sk: Dictionary in GameData.classes[cid].get("skills", []):
				var effects: Array = sk.get("buff", {}).keys() + sk.get("applies", {}).keys()
				effects += sk.get("combo", {}).get("applies", {}).keys() if sk.get("combo") is Dictionary else []
				for st in effects:
					if not _skill_icons.has(st) and String(sk.get("icon", "")) != "":
						_skill_icons[st] = String(sk.icon)
	return _skill_icons


static func is_buff(status: String) -> bool:
	return status in BUFFS or status.begins_with("imm_")


static func display_name(status: String) -> String:
	if status == "flow":
		return "Fluidité"
	return String(Combatant.STATUS_INFO.get(status, {}).get("name", status))


static func color(status: String) -> Color:
	if status == "flow":
		return Color(0.5, 0.95, 1.0)
	return Combatant.STATUS_INFO.get(status, {}).get("color", Color.WHITE)


static func tooltip(status: String, left: float, stacks := 0) -> String:
	var head := display_name(status) + (" ×%d" % stacks if stacks > 1 else "")
	return "%s\n%s\n%s restante%s" % [head, String(DESC.get(status, "")), _time_text(left), "s" if left >= 2.0 else ""]


static func _time_text(left: float) -> String:
	if left >= 60.0:
		return "%d min %02d s" % [int(left) / 60, int(left) % 60]
	return "%d s" % ceili(left) if left >= 1.0 else "%.1f s" % left
