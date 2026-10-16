class_name QuestPool
extends RefCounted
## Le grand pool des quêtes (passe M5) : une entrée = une consigne, l'activité qui la fait avancer, ce qu'elle compte et
## ses cibles. Lu par Quests (tirage du jour et de la semaine, compteurs). Rien n'est enregistré ici.
##
## Champs d'une entrée :
##   id      identifiant stable (enregistré dans la sauvegarde)
##   act     activité qui fait avancer la quête : survival, survivor, dungeon, tower, rush, siege, duel, arenas, gauntlet,
##           royale, lobby (menu Coffres), any (n'importe quelle activité, pour les quêtes de variété)
##   text    consigne, avec un %d (la cible), un %s (classe ou époque du paramètre) ou rien
##   stat    ce qui est compté dans le bilan d'une partie (voir Quests.stat_of) ; mode : sum (additionné), best (le meilleur
##           d'une partie), distinct (valeurs différentes vues, `of` = act ou class)
##   when    conditions sur la partie (Quests.when_ok)
##   d / w   cible du jour / de la semaine (0 : jamais tirée à cette période) ; dyn : cible calculée (Quests.dyn_target)
##   tier    1 à 3 : taille de la récompense du jour ; min : minutes estimées pour un joueur moyen
##   need    entrée du fil d'éveil (Unlocks) qui doit être ouverte ; gate : condition de compte (voir [method gate_ok])
##   param   "class" ou "epoch" : la quête porte une classe ou une époque choisie au tirage
const LIST := [
	# --- Survie ------------------------------------------------------------------------------------------------
	{"id": "sv_kills", "act": "survival", "text": "Vaincre %d monstres en Survie", "stat": "kills", "mode": "sum", "d": 400, "w": 2500, "tier": 1, "min": 10},
	{"id": "sv_elites", "act": "survival", "text": "Vaincre %d élites en Survie", "stat": "elites", "mode": "sum", "d": 8, "w": 50, "tier": 2, "min": 10},
	{"id": "sv_chests", "act": "survival", "text": "Ouvrir %d coffres de la carte", "stat": "chests", "mode": "sum", "d": 8, "w": 40, "tier": 1, "min": 8},
	{"id": "sv_perfects", "act": "survival", "text": "Réussir %d annulations parfaites", "stat": "perfects", "mode": "sum", "d": 15, "w": 100, "tier": 2, "min": 10},
	{"id": "sv_level", "act": "survival", "text": "Atteindre le niveau %d en une Survie", "stat": "level", "mode": "best", "d": 25, "w": 35, "tier": 2, "min": 14},
	{"id": "sv_stage", "act": "survival", "text": "Atteindre la carte %d d'une Survie", "stat": "stage", "mode": "best", "d": 2, "w": 3, "tier": 1, "min": 9},
	{"id": "sv_win", "act": "survival", "text": "Gagner %d Survie", "plural": "Gagner %d Survies", "stat": "win", "mode": "sum", "d": 1, "w": 3, "tier": 3, "min": 22},
	{"id": "sv_clean", "act": "survival", "text": "Gagner %d Survie sans résurrection", "plural": "Gagner %d Survies sans résurrection", "stat": "win", "mode": "sum",
		"when": {"won": true, "max_revives": 0}, "d": 1, "w": 2, "tier": 3, "min": 22},
	{"id": "sv_top", "act": "survival", "text": "Gagner une Survie à l'époque %s", "stat": "win", "mode": "sum", "when": {"won": true, "min_epoch": "$param"},
		"param": "epoch", "d": 1, "w": 2, "tier": 3, "min": 25, "gate": "epoch2"},
	{"id": "sv_heroic", "act": "survival", "text": "Gagner %d Survie en rang héroïque", "plural": "Gagner %d Survies en rang héroïque", "stat": "win", "mode": "sum",
		"when": {"won": true, "min_heroic": 1}, "d": 1, "w": 2, "tier": 3, "min": 28, "gate": "heroic"},
	{"id": "sv_class", "act": "survival", "text": "Gagner une Survie avec %s", "stat": "win", "mode": "sum", "when": {"won": true, "class": "$param"},
		"param": "class", "d": 1, "w": 0, "tier": 3, "min": 22},
	# --- Défi du jour : la Survie du jour, deux contraintes (core/challenge.gd) ------------------------------------
	{"id": "daily_challenge", "act": "survival", "text": "Défi du jour", "stat": "challenge_win", "mode": "sum", "d": 1, "w": 0, "tier": 3, "min": 22,
		"special": "challenge", "never_drawn": true},
	# --- Survivant (mode en chantier : tirée seulement quand le mode est visible) ---------------------------------
	{"id": "sr_kills", "act": "survivor", "text": "Vaincre %d monstres en Survivant", "stat": "kills", "mode": "sum", "d": 600, "w": 4000, "tier": 1, "min": 10, "gate": "survivor"},
	{"id": "sr_level", "act": "survivor", "text": "Atteindre le niveau %d en Survivant", "stat": "level", "mode": "best", "d": 20, "w": 30, "tier": 2, "min": 12, "gate": "survivor"},
	{"id": "sr_time", "act": "survivor", "text": "Tenir %d minutes en Survivant", "stat": "minutes", "mode": "best", "d": 10, "w": 18, "tier": 2, "min": 11, "gate": "survivor"},
	{"id": "sr_win", "act": "survivor", "text": "Vaincre le boss du Survivant", "stat": "win", "mode": "sum", "d": 1, "w": 2, "tier": 3, "min": 22, "gate": "survivor"},
	# --- Donjons -------------------------------------------------------------------------------------------------
	{"id": "dg_clear", "act": "dungeon", "text": "Terminer %d donjon", "plural": "Terminer %d donjons", "stat": "win", "mode": "sum", "d": 1, "w": 4, "tier": 2, "min": 12, "need": "dungeons"},
	{"id": "dg_clean", "act": "dungeon", "text": "Finir un donjon sans prendre de dégât de zone", "stat": "win", "mode": "sum",
		"when": {"won": true, "max_zone_hits": 0}, "d": 1, "w": 2, "tier": 3, "min": 15, "need": "dungeons"},
	{"id": "dg_elites", "act": "dungeon", "text": "Vaincre %d élites en donjon", "stat": "elites", "mode": "sum", "d": 8, "w": 30, "tier": 2, "min": 12, "need": "dungeons"},
	{"id": "dg_hard", "act": "dungeon", "text": "Terminer un donjon en Héroïque ou Mythique", "stat": "win", "mode": "sum", "when": {"won": true, "min_diff": 1},
		"d": 1, "w": 2, "tier": 3, "min": 15, "need": "dungeons", "gate": "dungeon_hard"},
	{"id": "dg_allies", "act": "dungeon", "text": "Terminer un donjon avec deux alliés IA", "stat": "win", "mode": "sum", "when": {"won": true, "min_allies": 2},
		"d": 1, "w": 2, "tier": 2, "min": 12, "need": "dungeons"},
	# --- La Tour -------------------------------------------------------------------------------------------------
	{"id": "tw_climb", "act": "tower", "text": "Monter de %d étages dans la Tour", "stat": "climbed", "mode": "sum", "d": 5, "w": 25, "tier": 1, "min": 10, "need": "tower"},
	{"id": "tw_floor", "act": "tower", "text": "Atteindre l'étage %d de la Tour", "stat": "reached", "mode": "best", "when": {"min_climbed": 3},
		"dyn": "tower_floor", "tier": 2, "min": 14, "need": "tower"},
	# --- Ruée des boss ---------------------------------------------------------------------------------------------
	{"id": "rs_bosses", "act": "rush", "text": "Vaincre %d boss de la Ruée", "stat": "rooms", "mode": "best", "d": 3, "w": 6, "tier": 2, "min": 12, "need": "rush"},
	{"id": "rs_clear", "act": "rush", "text": "Terminer la Ruée des boss", "stat": "win", "mode": "sum", "when": {"won": true}, "d": 0, "w": 1, "tier": 3, "min": 35, "need": "rush"},
	# --- Le Siège --------------------------------------------------------------------------------------------------
	{"id": "sg_wave", "act": "siege", "text": "Tenir jusqu'à la vague %d du Siège", "stat": "reached", "mode": "best", "d": 3, "w": 5, "tier": 2, "min": 10, "need": "siege"},
	{"id": "sg_boss", "act": "siege", "text": "Vaincre le boss du Siège", "stat": "boss_down", "mode": "sum", "d": 1, "w": 2, "tier": 3, "min": 16, "need": "siege"},
	{"id": "sg_win", "act": "siege", "text": "Être le dernier debout au Siège", "stat": "siege_won", "mode": "sum", "d": 0, "w": 1, "tier": 3, "min": 20, "need": "siege"},
	# --- Duel, Arènes, Gantelet ----------------------------------------------------------------------------------
	{"id": "du_win", "act": "duel", "text": "Gagner %d duel", "plural": "Gagner %d duels", "stat": "win", "mode": "sum", "d": 2, "w": 8, "tier": 1, "min": 8, "need": "duel_free"},
	{"id": "du_class", "act": "duel", "text": "Gagner un duel avec %s", "stat": "win", "mode": "sum", "when": {"won": true, "class": "$param"},
		"param": "class", "d": 1, "w": 0, "tier": 2, "min": 6, "need": "duel_free"},
	{"id": "du_league", "act": "duel", "text": "Gagner %d duel de Ligue", "plural": "Gagner %d duels de Ligue", "stat": "win", "mode": "sum", "when": {"won": true, "modes": ["league"]},
		"d": 1, "w": 3, "tier": 2, "min": 8, "need": "league"},
	{"id": "du_pantheon", "act": "duel", "text": "Battre un cerveau du Panthéon", "stat": "win", "mode": "sum", "when": {"won": true, "modes": ["pantheon"]},
		"d": 0, "w": 1, "tier": 3, "min": 12, "need": "pantheon"},
	{"id": "ar_win", "act": "arenas", "text": "Gagner %d Arène", "plural": "Gagner %d Arènes", "stat": "win", "mode": "sum", "d": 1, "w": 3, "tier": 2, "min": 10, "need": "arenas"},
	{"id": "ga_win", "act": "gauntlet", "text": "Gagner un Gantelet", "stat": "win", "mode": "sum", "d": 1, "w": 2, "tier": 3, "min": 10, "need": "gauntlet"},
	# --- Battle royale ---------------------------------------------------------------------------------------------
	{"id": "ry_podium", "act": "royale", "text": "Finir sur le podium d'une Battle royale", "stat": "run", "mode": "sum", "when": {"max_place": 3},
		"d": 1, "w": 3, "tier": 2, "min": 12, "need": "royale"},
	{"id": "ry_kills", "act": "royale", "text": "Éliminer %d héros en Battle royale", "stat": "pkills", "mode": "sum", "d": 4, "w": 15, "tier": 2, "min": 12, "need": "royale"},
	{"id": "ry_win", "act": "royale", "text": "Gagner une Battle royale", "stat": "win", "mode": "sum", "d": 0, "w": 1, "tier": 3, "min": 14, "need": "royale"},
	# --- Menu Coffres ----------------------------------------------------------------------------------------------
	{"id": "lb_chests", "act": "lobby", "text": "Ouvrir %d coffres de récompense", "stat": "chest_open", "mode": "sum", "d": 4, "w": 15, "tier": 1, "min": 3, "gate": "chests"},
	# --- Variété ---------------------------------------------------------------------------------------------------
	{"id": "tx_acts", "act": "any", "text": "Jouer %d activités différentes", "stat": "", "mode": "distinct", "of": "act", "d": 0, "w": 4, "tier": 2, "min": 30, "gate": "two_acts"},
	{"id": "tx_classes", "act": "any", "text": "Jouer avec %d classes différentes", "stat": "", "mode": "distinct", "of": "class", "d": 2, "w": 4, "tier": 2, "min": 20, "gate": "two_classes"},
]

## Activités : nom court et page où mène la boussole.
const ACTS := {
	"survival": {"name": "Survie", "go": {"menu": "survival"}},
	"survivor": {"name": "Survivant", "go": {"menu": "survivor"}},
	"dungeon": {"name": "Donjons", "go": {"menu": "dungeon"}},
	"tower": {"name": "La Tour", "go": {"menu": "tower"}},
	"rush": {"name": "Ruée des boss", "go": {"menu": "rush"}},
	"siege": {"name": "Le Siège", "go": {"menu": "siege"}},
	"duel": {"name": "Duel", "go": {"menu": "duel"}},
	"arenas": {"name": "Arènes", "go": {"menu": "arenas"}},
	"gauntlet": {"name": "Gantelet", "go": {"menu": "duel", "tab": "gauntlet"}},
	"royale": {"name": "Battle royale", "go": {"menu": "royale"}},
	"lobby": {"name": "Coffres", "go": {"chests": true}},
	"any": {"name": "Toutes", "go": {"menu": "quests"}},
}


static func get_def(id: String) -> Dictionary:
	for d in LIST:
		if String(d.id) == id:
			return d
	return {}


## La quête peut-elle être tirée pour [param period] ("daily" ou "weekly") avec l'état actuel du compte ?
static func available(d: Dictionary, period: String) -> bool:
	if bool(d.get("never_drawn", false)):
		return false
	var has_target: bool = int(d.get("d" if period == "daily" else "w", 0)) > 0 or d.has("dyn")
	if not has_target:
		return false
	var need := String(d.get("need", ""))
	if need != "" and not Unlocks.is_open(need):
		return false
	return gate_ok(String(d.get("gate", "")))


## Conditions de compte (clé « gate »).
static func gate_ok(gate: String) -> bool:
	match gate:
		"survivor":
			return Survivor.visible()
		"epoch2":
			return Epochs.unlocked() >= 2
		"heroic":
			return Epochs.heroic_open()
		"chests":
			return Profile.reward_chests.size() >= 4 and Unlocks.is_open("chests")
		"two_classes":
			return open_classes().size() >= 2
		"two_acts":
			return Unlocks.is_open("tower") or Unlocks.is_open("dungeons")
		"dungeon_hard":
			for zid in Dungeons.zone_ids():
				if Dungeons.is_open(String(zid)) and Dungeons.power_ok(String(zid), 1):
					return true
			return false
	return true


## Classes jouables (ouvertes), triées par identifiant.
static func open_classes() -> Array:
	var out: Array = []
	for cid in GameData.classes:
		if Progression.class_unlocked(cid):
			out.append(String(cid))
	out.sort()
	return out
