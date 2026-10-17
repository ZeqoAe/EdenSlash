class_name LastActivity
extends RefCounted
## « Continuer » (lot HUB-1, P0-2) : la dernière activité lancée depuis le menu principal et ses réglages, pour la relancer
## en un clic (bouton sous Jouer). État : `Profile.records["last_activity"] = {id, opts, label}` (sauvegardé au lancement :
## la Tour et le Duel rechargent la sauvegarde à la fin). Rien à migrer : sans clé, le bouton est caché.
## Le menu principal (Lobby._continue_last) remet les réglages et appelle la même fonction de lancement que la page ; si
## l'activité n'est plus ouverte (verrou, PE), c'est sa page qui s'ouvre.

const KEY := "last_activity"
const NAMES := {"survival": "Survie", "survivor": "Survivant", "dungeon": "Donjon", "rush": "Ruée des boss", "siege": "Le Siège",
	"tower": "La Tour", "duel": "Duel", "arenas": "Arènes", "royale": "Battle royale", "autochess": "L'Échiquier",
	"training": "Entraînement", "challenge": "Défi du jour"}


## Retient l'activité [param id] et ses réglages [param opts] (époque, zone, difficulté…).
static func record(id: String, opts := {}) -> void:
	Profile.records[KEY] = {"id": id, "opts": opts.duplicate(true), "label": label_for(id, opts)}
	if not Profile.in_run:
		Profile.save_profile()


## {id, opts, label} ou {} (jamais rien lancé, ou une activité qui n'existe plus).
static func last() -> Dictionary:
	var d = Profile.records.get(KEY)
	if not d is Dictionary or not NAMES.has(String(d.get("id", ""))):
		return {}
	return d


## Texte du bouton : « Survie · Époque II », « Donjon · Normal », « La Tour · étage 12 ».
static func label_for(id: String, opts: Dictionary) -> String:
	var n := String(NAMES.get(id, id))
	match id:
		"survival":
			var ep := int(opts.get("epoch", 1))
			return "%s · Époque %s" % [n, ["I", "II", "III", "IV"][clampi(ep - 1, 0, 3)]] + (" · rang %d" % int(opts.heroic) if int(opts.get("heroic", 0)) > 0 else "")
		"survivor":
			return "%s · palier %s" % [n, Survivor.numeral(int(opts.get("palier", 1)))]
		"dungeon", "siege":
			var z := String(opts.get("zone", ""))
			return "%s · %s" % [n, Dungeons.name_of(z)] if z != "" else n
		"rush":
			return "%s · %s" % [n, Dungeons.DIFF_NAMES[clampi(int(opts.get("diff", 0)), 0, Dungeons.DIFF_NAMES.size() - 1)]]
		"tower":
			return "%s · étage %d" % [n, int(opts.get("from", 1))] if int(opts.get("from", 1)) > 1 else n
	return n
