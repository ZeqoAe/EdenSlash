class_name Achievements
extends RefCounted
## Succès et titres (lot 11). Les succès sont accordés pour le passé (évalués d'après les records de
## la sauvegarde), ne donnent aucune statistique, et certains donnent un titre à porter
## (`Profile.title`). État : `Profile.achievements[id] = date d'obtention`.

## id, nom, description, compteur, seuil, titre ("" : aucun).
const LIST := [
	{"id": "run_1", "name": "Première expédition", "desc": "Terminer une Survie.", "c": "runs_done", "n": 1, "title": ""},
	{"id": "run_10", "name": "Habitué des cartes", "desc": "Terminer 10 Survies.", "c": "runs_done", "n": 10, "title": "Habitué"},
	{"id": "run_50", "name": "Vétéran", "desc": "Terminer 50 Survies.", "c": "runs_done", "n": 50, "title": "Vétéran"},
	{"id": "win_1", "name": "Première victoire", "desc": "Gagner une Survie.", "c": "runs_won", "n": 1, "title": ""},
	{"id": "win_10", "name": "Conquérant", "desc": "Gagner 10 Survies.", "c": "runs_won", "n": 10, "title": "Conquérant"},
	{"id": "kills_1k", "name": "Chasseur", "desc": "Vaincre 1 000 monstres.", "c": "kills", "n": 1000, "title": ""},
	{"id": "kills_10k", "name": "Faucheur", "desc": "Vaincre 10 000 monstres.", "c": "kills", "n": 10000, "title": "Faucheur"},
	{"id": "kills_50k", "name": "Fléau des monstres", "desc": "Vaincre 50 000 monstres.", "c": "kills", "n": 50000, "title": "Fléau des monstres"},
	{"id": "elite_10", "name": "Briseur de gardiens", "desc": "Vaincre 10 élites.", "c": "elite_kills", "n": 10, "title": ""},
	{"id": "elite_100", "name": "Chasseur d'élites", "desc": "Vaincre 100 élites.", "c": "elite_kills", "n": 100, "title": "Chasseur d'élites"},
	{"id": "boss_1", "name": "Tueur de boss", "desc": "Vaincre un boss.", "c": "boss_kills", "n": 1, "title": ""},
	{"id": "boss_20", "name": "Terreur des boss", "desc": "Vaincre 20 boss.", "c": "boss_kills", "n": 20, "title": "Terreur des boss"},
	{"id": "chest_20", "name": "Pilleur", "desc": "Ouvrir 20 coffres de la carte.", "c": "chests", "n": 20, "title": ""},
	{"id": "chest_200", "name": "Maître pilleur", "desc": "Ouvrir 200 coffres de la carte.", "c": "chests", "n": 200, "title": "Pilleur"},
	{"id": "break_500", "name": "Casse-tout", "desc": "Casser 500 objets.", "c": "breakables", "n": 500, "title": ""},
	{"id": "dodge_100", "name": "Insaisissable", "desc": "Esquiver 100 attaques.", "c": "dodges", "n": 100, "title": ""},
	{"id": "dodge_1k", "name": "Fantôme", "desc": "Esquiver 1 000 attaques.", "c": "dodges", "n": 1000, "title": "Fantôme"},
	{"id": "shrine_10", "name": "Gardien des sanctuaires", "desc": "Capturer 10 sanctuaires.", "c": "shrines", "n": 10, "title": ""},
	{"id": "heal_5k", "name": "Main guérisseuse", "desc": "Soigner 5 000 PV.", "c": "healed", "n": 5000, "title": ""},
	{"id": "hit_1500", "name": "Gros frappeur", "desc": "Infliger un coup de 1 500 dégâts.", "c": "best_hit", "n": 1500, "title": ""},
	{"id": "hit_10k", "name": "Coup de tonnerre", "desc": "Infliger un coup de 10 000 dégâts.", "c": "best_hit", "n": 10000, "title": "Coup de tonnerre"},
	{"id": "lvl_25", "name": "Aguerri", "desc": "Atteindre le niveau 25 en partie.", "c": "best_level", "n": 25, "title": ""},
	{"id": "lvl_50", "name": "Légende vivante", "desc": "Atteindre le niveau 50 en partie.", "c": "best_level", "n": 50, "title": "Légende"},
	{"id": "epoch_1", "name": "Époque I gagnée", "desc": "Vaincre le boss de la 3e carte de l'époque I.", "c": "epochs", "n": 1, "title": ""},
	{"id": "epoch_2", "name": "Époque II gagnée", "desc": "Gagner l'époque II.", "c": "epochs", "n": 2, "title": ""},
	{"id": "epoch_4", "name": "Maître des époques", "desc": "Gagner l'époque IV.", "c": "epochs", "n": 4, "title": "Maître des époques"},
	{"id": "tower_50", "name": "Mi-chemin", "desc": "Atteindre l'étage 50 de la Tour.", "c": "tower_best", "n": 50, "title": ""},
	{"id": "tower_200", "name": "Sommet de la Tour", "desc": "Atteindre l'étage 200 de la Tour.", "c": "tower_best", "n": 200, "title": "Roi de la Tour"},
	{"id": "duel_1", "name": "Premier sang", "desc": "Gagner un duel.", "c": "duel_wins", "n": 1, "title": ""},
	{"id": "duel_10", "name": "Duelliste", "desc": "Gagner 10 duels.", "c": "duel_wins", "n": 10, "title": "Duelliste"},
	{"id": "duel_lv1", "name": "À mains nues", "desc": "Gagner un duel à l'arme au niveau 1.", "c": "duel_lv1", "n": 1, "title": ""},
	{"id": "league_1", "name": "Ligue de Bronze", "desc": "Atteindre le rang Bronze de la Ligue.", "c": "league_rank", "n": 1, "title": "Bronze"},
	{"id": "league_3", "name": "Ligue d'Or", "desc": "Atteindre le rang Or de la Ligue.", "c": "league_rank", "n": 3, "title": "Or"},
	{"id": "league_4", "name": "Ligue de Platine", "desc": "Atteindre le rang Platine de la Ligue.", "c": "league_rank", "n": 4, "title": "Platine"},
	{"id": "class_5", "name": "Polyvalent", "desc": "Débloquer 10 classes.", "c": "classes", "n": 10, "title": ""},
	{"id": "class_30", "name": "Collectionneur de classes", "desc": "Débloquer 30 classes.", "c": "classes", "n": 30, "title": "Collectionneur"},
	{"id": "mastery_1", "name": "Maîtrise totale", "desc": "Amener une classe à la maîtrise 20.", "c": "mastery20", "n": 1, "title": "Maître"},
	{"id": "contract_10", "name": "Homme de parole", "desc": "Terminer 10 contrats de classe.", "c": "contracts", "n": 10, "title": ""},
	{"id": "challenge_7", "name": "Assidu", "desc": "Réussir le Défi du jour 7 fois.", "c": "challenge_wins", "n": 7, "title": "Assidu"},
	{"id": "quests_30", "name": "Aventurier appliqué", "desc": "Accomplir 30 quêtes.", "c": "quests_done", "n": 30, "title": ""},
	{"id": "series_7", "name": "Constance", "desc": "Tenir une série de quêtes de 7 jours.", "c": "quest_series_best", "n": 7, "title": "Constant"},
	{"id": "cards_40", "name": "Bibliothécaire", "desc": "Débloquer 40 cartes.", "c": "cards", "n": 40, "title": ""},
	{"id": "trophy_30", "name": "Collectionneur de trophées", "desc": "Découvrir 30 effets de trophée.", "c": "trophies", "n": 30, "title": ""},
	{"id": "weapon_legend", "name": "Arme légendaire", "desc": "Faire grandir une arme jusqu'à son effet légendaire.", "c": "weapon_legend", "n": 1, "title": ""},
]


## Valeur du compteur [param c] pour la sauvegarde actuelle.
static func value(c: String) -> float:
	match c:
		"runs_done":
			return float(Profile.runs_done)
		"runs_won":
			return float(Profile.runs_won)
		"best_level":
			return float(Profile.best_level)
		"epochs":
			return float(Profile.records.get("epochs_cleared", 0))
		"tower_best":
			var top := 0
			for d in Tower.DIFF_NAMES.size():
				top = maxi(top, Tower.best(d))
			return float(top)
		"league_rank":
			return float(League.rank_index())
		"classes":
			var n := 0
			for cid in GameData.classes:
				if Progression.class_unlocked(cid):
					n += 1
			return float(n)
		"mastery20":
			var n := 0
			for cid in GameData.classes:
				if Profile.expertise_level(cid) >= 20:
					n += 1
			return float(n)
		"contracts":
			var n := 0
			for cid in Profile.contracts:
				n += int(Profile.contracts[cid].get("done", 0))
			return float(n)
		"cards":
			return float(Completion.cards_done())
		"trophies":
			return float(Profile.seen_trophies.size())
		"weapon_legend":
			return float(Profile.weapon_legend.size())
	return float(Profile.records.get(c, 0))


static func owned(id: String) -> bool:
	return Profile.achievements.has(id)


static func progress(a: Dictionary) -> Vector2:
	return Vector2(minf(value(String(a.c)), float(a.n)), float(a.n))


## Accorde tous les succès atteints (pour le passé aussi) ; renvoie les ids nouvellement obtenus.
static func refresh() -> Array:
	var gained: Array = []
	for a in LIST:
		if not Profile.achievements.has(a.id) and value(String(a.c)) >= float(a.n):
			Profile.achievements[a.id] = Time.get_date_string_from_system()
			gained.append(a.id)
	return gained


static func titles() -> Array:
	var out: Array = Profile.extra_titles.duplicate()
	for a in LIST:
		if owned(a.id) and String(a.title) != "":
			out.append(String(a.title))
	return out


static func count() -> Vector2:
	var n := 0
	for a in LIST:
		if owned(a.id):
			n += 1
	return Vector2(n, LIST.size())
