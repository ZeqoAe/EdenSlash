class_name Unlocks
extends RefCounted
## Fil d'éveil (conception, lot 8) : ce qui s'ouvre, quand. Chaque entrée a une condition lue dans
## la sauvegarde ; une fois ouverte, une entrée le reste (« on ne reverrouille jamais » : la liste
## `Profile.unlocked_features` la garde). Le mode dev ouvre tout. Une sauvegarde d'avant le fil
## d'éveil garde ouvert tout ce qu'elle utilisait déjà (migration, voir [method migrate]).
##
## Les entrées verrouillées restent visibles, grisées, avec leur condition : rien n'est caché.

## id -> {name, cond (texte de la condition), legacy (ouvert d'emblée pour une ancienne sauvegarde)}
const LIST := {
	"survival": {"name": "Survie", "cond": "", "legacy": true},
	"training": {"name": "Zone d'entraînement", "cond": "", "legacy": true},
	"collection": {"name": "Carnet", "cond": "Termine une première Survie (quelle que soit l'issue).", "legacy": true},
	"chests": {"name": "Coffres", "cond": "Ramasse un premier coffre de récompense ou termine une Survie.", "legacy": true},
	"armory": {"name": "Atelier : Armurerie", "cond": "Découvre une première pièce dans un coffre de la Survie.", "legacy": true},
	"certificates": {"name": "Plateau des certificats", "cond": "Atteins la maîtrise 3 d'une classe.", "legacy": true},
	"daily": {"name": "Défi de maîtrise", "cond": "Termine 3 Survies.", "legacy": true},
	"forge": {"name": "Atelier : Forge et Réserve", "cond": "Gagne l'époque I (boss de la 3e carte).", "legacy": true},
	"tower": {"name": "La Tour", "cond": "Gagne l'époque I (boss de la 3e carte).", "legacy": true},
	"duel_free": {"name": "Duel libre", "cond": "Bats un premier duelliste de la Tour.", "legacy": true},
	"league": {"name": "Ligue", "cond": "Bats 3 duellistes de la Tour (ou gagne 3 duels).", "legacy": true},
	"dungeons": {"name": "Donjons", "cond": "Gagne l'époque II.", "legacy": false},
	"royale": {"name": "Battle royale", "cond": "Atteins le rang Argent de la Ligue (ou gagne 6 duels).", "legacy": false},
	"gauntlet": {"name": "Gantelet", "cond": "Atteins le rang Or de la Ligue.", "legacy": false},
	"arenas": {"name": "Arènes avec alliés IA", "cond": "Atteins le rang Or de la Ligue.", "legacy": false},
	"pantheon": {"name": "Panthéon des cerveaux", "cond": "Atteins le rang Platine de la Ligue.", "legacy": false},
	"heroic": {"name": "Rangs héroïques", "cond": "Gagne l'époque IV.", "legacy": false},
}


## La condition de [param id] est-elle remplie par la sauvegarde ?
static func test(id: String) -> bool:
	match id:
		"survival", "training":
			return true
		"collection":
			return Profile.runs_done >= 1
		"chests":
			return Profile.runs_done >= 1 or not Profile.reward_chests.is_empty()
		"armory":
			return not Profile.seen_gear.is_empty()
		"certificates":
			for cls in GameData.talents:
				if Profile.expertise_level(cls) >= 3:
					return true
			return false
		"daily":
			return Profile.runs_done >= 3
		"forge", "tower":
			return Epochs.unlocked() >= 2
		"duel_free":
			return int(Profile.records.get("duel_wins", 0)) >= 1 or Tower.duelists_beaten() >= 1
		"league":
			return int(Profile.records.get("duel_wins", 0)) >= 3 or Tower.duelists_beaten() >= 3
		"dungeons":
			return Epochs.unlocked() >= 3
		"royale":
			return League.rank_index() >= 2 or int(Profile.records.get("duel_wins", 0)) >= 6
		"gauntlet", "arenas":
			return League.rank_index() >= 3
		"pantheon":
			return League.rank_index() >= 4
		"heroic":
			return int(Profile.records.get("epochs_cleared", 0)) >= 4
	return false


## [param id] est-elle ouverte ? (mode dev : tout ; sinon la liste gardée, sinon la condition, qui
## s'enregistre alors une fois pour toutes.)
static func is_open(id: String) -> bool:
	if bool(Settings.get_v("interface", "dev_mode")):
		return true
	if id in Profile.unlocked_features:
		return true
	if test(id):
		Profile.unlocked_features.append(id)
		Profile.new_features.append(id)
		return true
	return false


static func name_of(id: String) -> String:
	return String(LIST.get(id, {}).get("name", id))


static func condition(id: String) -> String:
	return String(LIST.get(id, {}).get("cond", ""))


## Texte de verrou (infobulle d'une entrée grisée).
static func lock_text(id: String) -> String:
	return "🔒 %s — %s" % [name_of(id), condition(id)]


## Vérifie toutes les entrées (nouvelles ouvertures enregistrées) et renvoie les ids nouvellement ouverts.
static func refresh() -> Array:
	var before := Profile.new_features.size()
	for id in LIST:
		is_open(id)
	return Profile.new_features.slice(before)


## Sauvegarde d'avant le fil d'éveil (aucune liste enregistrée) : tout ce qu'elle utilisait déjà reste
## ouvert. Appelé au chargement de la sauvegarde.
static func migrate(had_list: bool) -> void:
	if had_list:
		return
	var used := Profile.runs_done > 0 or not Profile.reward_chests.is_empty() or Profile.best_level > 1 \
		or int(Profile.records.get("duel_wins", 0)) > 0 or Tower.duelists_beaten() > 0 or not Profile.seen_gear.is_empty()
	if not used:
		return  # nouvelle partie : tout est à gagner
	for id in LIST:
		if bool(LIST[id].legacy) and not id in Profile.unlocked_features:
			Profile.unlocked_features.append(id)
