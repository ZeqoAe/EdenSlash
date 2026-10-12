class_name Progression
extends RefCounted
## Progression entre les runs :
## - classes : on commence Guerrier ; les autres se débloquent par des missions
##   (records cumulés sur toutes les runs, Profile.records) ;
## - maîtrise (expertise) de classe : chaque niveau donne 2 points de talent, et
##   débloque les sorts de la classe (4 au départ) et ses certificats ; le parcours de
##   maîtrise (rewards) liste tout ce que rapporte chaque niveau.

const START_CLASS := "warrior"
## Missions de déblocage des classes : record suivi, objectif, texte.
const MISSIONS := {
	"samurai": {"stat": "kills", "goal": 250, "text": "Vaincre %d monstres"},
	"cleric": {"stat": "healed", "goal": 4000, "text": "Soigner %d PV"},
	"magician": {"stat": "best_hit", "goal": 800, "text": "Un coup de %d dégâts"},
	"thief": {"stat": "dodges", "goal": 40, "text": "Esquiver %d attaques"},
	"hunter": {"stat": "elite_kills", "goal": 15, "text": "Vaincre %d élites"},
}
## Sorts : les 4 premiers de la classe sont connus d'emblée, les suivants arrivent
## à ces niveaux de maîtrise (dans l'ordre de la liste de la classe).
const BASE_SKILLS := 4
const SKILL_LEVELS := [2, 3, 4, 5, 6, 7, 8, 10, 12, 14, 16]


# --- classes ---------------------------------------------------------------------------------
## Classes importées d'Eden (data/classes.json -> unlock) : débloquées par la maîtrise de
## leur classe d'origine (classe de base de la famille pour les vertes, classe parente
## pour les orange). Les 5 classes de départ gardent leurs missions.
static func class_unlocked(cls: String) -> bool:
	return cls == START_CLASS or cls in Profile.unlocked_classes


static func unlock_rule(cls: String) -> Dictionary:
	return GameData.class_data(cls).get("unlock", {})


static func mission_text(cls: String) -> String:
	var u := unlock_rule(cls)
	if not u.is_empty() and not MISSIONS.has(cls):
		return "Maîtrise %s niveau %d" % [GameData.class_data(String(u.cls)).get("name_fr", u.cls), int(u.level)]
	var m: Dictionary = MISSIONS.get(cls, {})
	return String(m.get("text", "")) % int(m.get("goal", 0)) if not m.is_empty() else ""


## Avancement de la mission : Vector2(fait, objectif).
static func mission_progress(cls: String) -> Vector2:
	var u := unlock_rule(cls)
	if not u.is_empty() and not MISSIONS.has(cls):
		return Vector2(mini(Profile.expertise_level(String(u.cls)), int(u.level)), int(u.level))
	var m: Dictionary = MISSIONS.get(cls, {})
	if m.is_empty():
		return Vector2(1, 1)
	return Vector2(minf(float(Profile.records.get(String(m.stat), 0.0)), float(m.goal)), float(m.goal))


static func mission_line(cls: String) -> String:
	var p := mission_progress(cls)
	return "%s — %d / %d" % [mission_text(cls), int(p.x), int(p.y)]


## Classes dont la mission vient d'être remplie.
static func check_missions() -> Array:
	var out: Array = []
	for cls in GameData.classes:
		if not MISSIONS.has(cls) and unlock_rule(cls).is_empty():
			continue
		if class_unlocked(cls):
			continue
		var p := mission_progress(cls)
		if p.x >= p.y:
			out.append(cls)
	return out


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
