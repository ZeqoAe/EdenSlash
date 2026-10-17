class_name ResourceHelp
extends RefCounted
## Chaque ressource dit où l'obtenir ET où la dépenser (passe P6, la quête commune se voit) : une seule table,
## lue par les infobulles (pied du lobby, bourse de l'Atelier, fournitures, bilans) et par les pastilles de gains des activités
## (GainChips). Texte court, une idée par ligne, aucun pourcentage.

## id -> {name, icon (nom d'icône du menu, ou "item:<chemin>" / "craft:<clé>"), get (où l'obtenir), spend (où la dépenser)}
const KINDS := {
	"insignia": {"name": "Insignes", "icon": "ico:res_insignia",
		"get": "Survie (cartes et boss), première victoire du jour en JcJ.",
		"spend": "Atelier (pièces et plans de donjon), boutique des Coffres (apparences), leçons de maîtrise."},
	"crystal": {"name": "Cristaux", "icon": "item:crystal",
		"get": "Donjons, Ruée, Siège, Tour, démontage de pièces.",
		"spend": "Forge : monter, polir, réajuster."},
	"fortify": {"name": "Parchemins", "icon": "craft:fortify:power:60",
		"get": "Coffres de forge : Survie gagnée, Donjons, Ruée, Tour.",
		"spend": "Forge > Améliorer : un parchemin par tentative, de +1 à +10."},
	"stone": {"name": "Pierres", "icon": "craft:stone:safety",
		"get": "Coffres de forge, surtout la Ruée des boss.",
		"spend": "Forge > Améliorer : elles évitent de perdre un niveau en cas d'échec."},
	"gem": {"name": "Gemmes", "icon": "craft:gem:ruby:2",
		"get": "Coffres du joaillier : Survie, Donjons, Ruée, Tour.",
		"spend": "Forge > Gemmes : deux emplacements par pièce, fusion de trois identiques."},
	"formula": {"name": "Formules", "icon": "craft:scroll:optimize:5",
		"get": "Siège (formules hautes), coffres du joaillier, scribe de la Survie.",
		"spend": "Forge > Enchanter : un enchantement par pièce."},
	"plan": {"name": "Plans", "icon": "ico:res_plan",
		"get": "Donjons : chaque boss donne son plan la première fois qu'il tombe.",
		"spend": "Atelier > Plans de donjon : une pièce à la panoplie du boss, en insignes."},
	"piece": {"name": "Pièces", "icon": "ico:res_piece",
		"get": "Survie : les coffres d'emplacement révèlent des plans.",
		"spend": "Atelier > Fabriquer : une pièce dont tu as le plan, en insignes."},
	"panoply": {"name": "Panoplies", "icon": "ico:res_panoply",
		"get": "Donjons : un coffre de set, trois pièces à choisir.",
		"spend": "Héros > Équipement : 2, 4 et 6 pièces portées donnent des bonus."},
	"spirit": {"name": "Esprits", "icon": "ico:res_spirit",
		"get": "Panthéon : chaque cerveau battu donne une pièce des Esprits.",
		"spend": "Atelier > Fabriquer (insignes) puis Héros > Équipement, pour toutes les classes."},
	"mastery": {"name": "Maîtrise", "icon": "ico:res_mastery",
		"get": "Toutes les activités. La Survie en donne le plus.",
		"spend": "Rien à dépenser : chaque niveau ouvre sorts, certificats et talents."},
	"look": {"name": "Apparences", "icon": "ico:res_look",
		"get": "Coffres d'apparence : Tour, Siège, Ruée, Battle royale, Échiquier, Roulette.",
		"spend": "Héros > Apparence."},
	"title": {"name": "Titres", "icon": "ico:res_title",
		"get": "Ruée, Ligue, Panthéon, Battle royale, Échiquier, succès.",
		"spend": "Carnet > Succès et titres : choisis celui que tu portes."},
	"rank": {"name": "Rangs", "icon": "ico:res_rank",
		"get": "Ligue : trois victoires d'affilée par rang.",
		"spend": "Ils ouvrent Battle royale, Arènes, Gantelet et Panthéon."},
	"stars": {"name": "Étoiles", "icon": "ico:res_star",
		"get": "Survie : victoire, sans résurrection, défi de l'époque.",
		"spend": "Elles font avancer les époques jusqu'aux rangs héroïques."},
	"cards": {"name": "Cartes", "icon": "ico:res_card",
		"get": "Survie : chaque niveau gagné propose des cartes.",
		"spend": "Elles renforcent le build de la partie en cours."},
}


static func has(kind: String) -> bool:
	return KINDS.has(kind)


static func name_of(kind: String) -> String:
	return String(KINDS.get(kind, {}).get("name", kind))


## Texte d'infobulle : le nom, puis où l'obtenir et où le dépenser.
static func tip(kind: String) -> String:
	var k: Dictionary = KINDS.get(kind, {})
	if k.is_empty():
		return ""
	return "%s\nOù en trouver : %s\nÀ quoi ça sert : %s" % [k.name, k.get, k.spend]


## Les deux lignes seules (sans le nom), à ajouter sous une description existante.
static func hint(kind: String) -> String:
	var k: Dictionary = KINDS.get(kind, {})
	if k.is_empty():
		return ""
	return "Où en trouver : %s\nÀ quoi ça sert : %s" % [k.get, k.spend]


## Ressource d'une clé de réserve (Craft : « gem:ruby:2 », « fortify:power:60 »…), "" pour les autres.
static func kind_of_key(key: String) -> String:
	match key.get_slice(":", 0):
		"gem":
			return "gem"
		"scroll":
			return "formula"
		"fortify", "blessed":
			return "fortify"
		"stone":
			return "stone"
	return ""


## Icône d'une ressource (texture) ; null si l'icône manque.
static func icon(kind: String) -> Texture2D:
	var name := String(KINDS.get(kind, {}).get("icon", ""))
	if name.begins_with("item:"):
		return UiTheme.texture(Items.material_icon(name.trim_prefix("item:")))
	if name.begins_with("craft:"):
		return UiTheme.texture(Craft.icon(name.trim_prefix("craft:")))
	if name.begins_with("ico:"):  # pictogramme maison en couleurs (lot ICO-1)
		return Ico.tex(name.trim_prefix("ico:"), 24)
	return MenuWidgets.icon(name)


## Les ressources qui gardent leurs couleurs d'origine (les autres sont teintées comme les icônes du menu).
static func is_item_icon(kind: String) -> bool:
	var name := String(KINDS.get(kind, {}).get("icon", ""))
	return name.begins_with("item:") or name.begins_with("craft:") or name.begins_with("ico:")
