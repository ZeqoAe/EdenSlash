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
const BUFFS := ["solar", "shrine", "marduk", "frenzy", "keen", "haste", "barrier", "fury", "flow", "regen", "invisible", "evasion"]
const DESC := {
	"bleed": "Perd 15 % de l'attaque de la source en PV chaque seconde.",
	"burn": "Perd 25 % de l'attaque de la source en PV chaque seconde.",
	"purgatory": "Subit 20 % de dégâts en plus.",
	"cranes": "Subit 15 % de dégâts en plus.",
	"shock": "Subit 15 % de dégâts en plus.",
	"scar": "Inflige 30 % de dégâts en moins.",
	"stun": "Ne peut plus agir.",
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
}


static func icon(status: String) -> Texture2D:
	var own := STATUS_DIR % status
	if FileAccess.file_exists(own):
		return UiTheme.texture(own)
	return UiTheme.texture(String(EDEN_ICONS.get(status, "")))


static func is_buff(status: String) -> bool:
	return status in BUFFS


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
