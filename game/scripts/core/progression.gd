class_name Progression
extends RefCounted
## Progression entre les runs :
## - classes : on commence Guerrier ; les autres se débloquent par des missions
##   (records cumulés sur toutes les runs, Profile.records) ;
## - maîtrise (expertise) de classe : chaque niveau donne 2 points de talent, et
##   débloque les sorts de la classe (4 au départ) et ses certificats ; le parcours de
##   maîtrise (rewards) liste tout ce que rapporte chaque niveau.

const START_CLASS := "warrior"  # classe choisie dans une nouvelle partie
## Les 5 classes de base d'Eden (une par famille) sont jouables d'emblée.
const START_CLASSES := ["warrior", "thief", "hunter", "cleric", "magician"]
## Déblocage des classes par la maîtrise (règles du joueur, 13/10/2026) :
## [mode, [[classe, niveau de maîtrise], ...]] ; "all" : toutes les conditions, "any" : une.
## Les classes éveillées (orange) : maîtrise 8 de leur classe d'origine (data/classes.json).
const UNLOCKS := {
	"knight": ["all", [["warrior", 3]]],
	"samurai": ["all", [["warrior", 3], ["thief", 3]]],
	"inquisitor": ["all", [["hunter", 3]]],
	"bard": ["all", [["cleric", 3]]],
	"luminary": ["all", [["magician", 3], ["thief", 3]]],
	"dragon_knight": ["any", [["knight", 5], ["warrior", 5]]],
	"martial_artist": ["any", [["samurai", 5], ["thief", 5]]],
	"engineer": ["any", [["inquisitor", 5], ["hunter", 5]]],
	"sage": ["any", [["cleric", 5], ["bard", 5]]],
	"illusionist": ["any", [["luminary", 5], ["magician", 5]]],
	"templar": ["any", [["warrior", 7], ["knight", 7], ["dragon_knight", 7]]],
	"blade_dancer": ["any", [["thief", 7], ["samurai", 7], ["martial_artist", 7]]],
	"ranger": ["any", [["hunter", 7], ["inquisitor", 7], ["engineer", 7]]],
	"shaman": ["any", [["cleric", 7], ["bard", 7], ["sage", 7]]],
	"warlock": ["any", [["magician", 7], ["luminary", 7], ["illusionist", 7]]],
}
## Sorts : les 4 premiers de la classe sont connus d'emblée, les suivants arrivent
## à ces niveaux de maîtrise (dans l'ordre de la liste de la classe).
const BASE_SKILLS := 4
const SKILL_LEVELS := [2, 3, 4, 5, 6, 7, 8, 10, 12, 14, 16]


# --- classes ---------------------------------------------------------------------------------
static func class_unlocked(cls: String) -> bool:
	return cls in START_CLASSES or cls in Profile.unlocked_classes or bool(GameData.custom_classes.get(cls, {}).get("open", false))


## Condition de déblocage : [mode, [[classe, niveau], ...]] ; vide pour les classes de base.
static func requirement(cls: String) -> Array:
	if cls in START_CLASSES:
		return []
	if UNLOCKS.has(cls):
		return UNLOCKS[cls]
	var u: Dictionary = GameData.class_data(cls).get("unlock", {})
	return ["all", [[String(u.cls), int(u.level)]]] if u.has("cls") else []


## Ancienne règle (compatibilité) : première condition.
static func unlock_rule(cls: String) -> Dictionary:
	var r := requirement(cls)
	return {"cls": r[1][0][0], "level": r[1][0][1]} if not r.is_empty() else {}


static func mission_text(cls: String) -> String:
	var r := requirement(cls)
	if r.is_empty():
		return ""
	var parts: PackedStringArray = []
	for c in r[1]:
		parts.append("%s %d" % [GameData.class_data(String(c[0])).get("name_fr", c[0]), int(c[1])])
	return "Maîtrise " + (" et " if r[0] == "all" else " ou ").join(parts)


## Avancement : Vector2(fait, objectif) (somme des conditions, ou la plus avancée pour « ou »).
static func mission_progress(cls: String) -> Vector2:
	var r := requirement(cls)
	if r.is_empty():
		return Vector2(1, 1)
	if r[0] == "all":
		var done := 0
		var goal := 0
		for c in r[1]:
			done += mini(Profile.expertise_level(String(c[0])), int(c[1]))
			goal += int(c[1])
		return Vector2(done, goal)
	var best := Vector2(0, 1)
	for c in r[1]:
		var v := Vector2(mini(Profile.expertise_level(String(c[0])), int(c[1])), int(c[1]))
		if v.x / v.y > best.x / best.y or best.x == 0:
			best = v
	return best


static func mission_line(cls: String) -> String:
	var p := mission_progress(cls)
	return "%s — %d / %d" % [mission_text(cls), int(p.x), int(p.y)]


## Classes dont la condition vient d'être remplie.
static func check_missions() -> Array:
	var out: Array = []
	for cls in GameData.classes:
		if class_unlocked(cls) or requirement(cls).is_empty():
			continue
		var p := mission_progress(cls)
		if p.x >= p.y:
			out.append(cls)
	return out


## Niveau de maîtrise le plus haut demandé (tri des classes).
static func requirement_level(cls: String) -> int:
	var r := requirement(cls)
	var m := 0
	for c in (r[1] if not r.is_empty() else []):
		m = maxi(m, int(c[1]))
	return m


# --- sorts -----------------------------------------------------------------------------------
## Niveau de maîtrise qui débloque le sort n° [param index] de la classe (1 : d'emblée).
static func skill_level(index: int) -> int:
	if index < BASE_SKILLS:
		return 1
	var k := index - BASE_SKILLS
	return int(SKILL_LEVELS[k]) if k < SKILL_LEVELS.size() else int(SKILL_LEVELS[-1]) + 2 * (k - SKILL_LEVELS.size() + 1)


## Sorts propres de la classe (les sorts partagés, hérités de la famille ou de la classe
## parente, sont jouables d'emblée).
static func own_skills(cls: String) -> Array:
	return GameData.class_data(cls).get("skills", []).filter(func(s): return not s.get("shared", false))


static func skill_level_of(cls: String, skill_id: int) -> int:
	var skills := own_skills(cls)
	for i in skills.size():
		if int(skills[i].id) == skill_id:
			return skill_level(i)
	return 1


static func skill_unlocked(cls: String, skill_id: int) -> bool:
	return Profile.expertise_level(cls) >= skill_level_of(cls, skill_id)


# --- parcours de maîtrise --------------------------------------------------------------------
## Récompenses du niveau [param lvl] de la classe : [{kind, name, icon, desc}].
static func rewards_at(cls: String, lvl: int) -> Array:
	var out: Array = []
	if lvl >= 1:
		out.append({"kind": "talent", "name": "+2 points de talent", "icon": "", "desc": "À dépenser dans l'arbre de talents de la classe."})
	var skills := own_skills(cls)
	for i in skills.size():
		if skill_level(i) == lvl and lvl > 1:
			out.append({"kind": "skill", "name": String(skills[i].name), "icon": String(skills[i].get("icon", "")),
				"desc": "Nouveau sort : il peut maintenant apparaître dans les cartes de niveau.\n" + String(skills[i].get("desc", ""))})
	var certs: Array = GameData.talents.get(cls, {}).get("certificates", [])
	for i in certs.size():
		if i < Profile.CERT_LEVELS.size() and int(Profile.CERT_LEVELS[i]) == lvl:
			var p := TalentsPage.cert_passive("%s/%s" % [cls, certs[i]])
			out.append({"kind": "cert", "name": "Certificat : " + String(p.get("name", "?")), "icon": String(p.get("icon", "")),
				"desc": "Certificat de maîtrise, utilisable par toutes les classes.\n" + String(p.get("desc", ""))})
	return out


## Dernier niveau qui apporte autre chose que des points de talent.
static func last_reward_level(cls: String) -> int:
	var skills := own_skills(cls)
	var last := skill_level(maxi(skills.size() - 1, 0))
	for l in Profile.CERT_LEVELS:
		last = maxi(last, int(l))
	return last
