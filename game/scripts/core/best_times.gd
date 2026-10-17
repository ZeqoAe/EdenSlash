class_name BestTimes
extends RefCounted
## Temps et records (lot DNG-1, backlog BM-DNG P0-6) : meilleur temps par boss (activité et difficulté), par donjon complet,
## par tranche de 10 étages de la Tour et par tirage de la Ruée. Stockés dans Profile.records[KEY] (clé neuve : une vieille
## sauvegarde n'en a pas, rien à migrer ; aucune clé existante n'est renommée) : {clé -> secondes}.
##
## Horloge : [member clock], le temps de jeu de la partie en cours (TowerDirector.update la fait avancer : rien ne compte
## pendant une pause ou un choix de carte qui met le jeu en pause). En partie, [method note] met un temps de côté (et dit
## tout de suite s'il bat le record) ; [method commit] l'écrit dans le profil à la fin (Tower.finish, après
## Profile.reload_keep_records qui ne garde pas les dictionnaires modifiés en partie), avant la sauvegarde.
## Le bilan lit [member session] (temps de la partie, ancien record, « Record ! »).

const KEY := "best_times"

static var clock := 0.0
## Temps de la partie : {key, label, t, best (ancien record, 0 : aucun), new}.
static var session: Array = []


static func reset() -> void:
	clock = 0.0
	session.clear()


static func tick(delta: float) -> void:
	clock += delta


# --- clés ---------------------------------------------------------------------------------------
## Combat contre le boss [param bid] dans l'activité [param mode] (dungeon, rush, tower) à la difficulté [param diff].
static func boss_key(mode: String, bid: String, diff: int) -> String:
	return "boss:%s:%s:%d" % [mode, bid, diff]


## Donjon du boss [param bid] fini d'un bout à l'autre (3 salles).
static func dungeon_key(bid: String, diff: int) -> String:
	return "dungeon:%s:%d" % [bid, diff]


## Tranche [param block] de la Tour (étages 10 b + 1 à 10 b + 10) à la difficulté [param diff], montée d'une traite.
static func tower_key(diff: int, block: int) -> String:
	return "tower:%d:%d" % [diff, block]


## Tirage [param seed] de la Ruée (huit boss) à la difficulté [param diff].
static func rush_key(seed: int, diff: int) -> String:
	return "rush:%d:%d" % [seed, diff]


# --- lecture ------------------------------------------------------------------------------------
static func table() -> Dictionary:
	var t = Profile.records.get(KEY, {})
	return t if t is Dictionary else {}


## Meilleur temps enregistré pour [param key] (0 : aucun).
static func best(key: String) -> float:
	return float(table().get(key, 0.0))


## « 1:58 », « 12:04 », « 1:02:10 ».
static func fmt(secs: float) -> String:
	var s := maxi(0, roundi(secs))
	if s >= 3600:
		return "%d:%02d:%02d" % [s / 3600, (s / 60) % 60, s % 60]
	return "%d:%02d" % [s / 60, s % 60]


# --- écriture -----------------------------------------------------------------------------------
## Temps [param secs] fait en partie pour [param key] ([param label] : ce que le bilan affiche, « Latif »). Renvoie l'entrée
## de la session (new : record battu, ou premier temps).
static func note(key: String, label: String, secs: float) -> Dictionary:
	if secs <= 0.5:
		return {}
	var old := best(key)
	for e in session:
		if String(e.key) == key:  # (même clé deux fois dans la partie : le meilleur des deux)
			if secs < float(e.t):
				e.t = secs
				e.new = old <= 0.0 or secs < old
			return e
	var e := {"key": key, "label": label, "t": secs, "best": old, "new": old <= 0.0 or secs < old}
	session.append(e)
	return e


## Écrit les temps de la partie dans le profil (meilleur seulement). Sans effet si rien n'a été fait.
static func commit() -> void:
	if session.is_empty():
		return
	var t := table().duplicate()
	for e in session:
		var cur := float(t.get(String(e.key), 0.0))
		if cur <= 0.0 or float(e.t) < cur:
			t[String(e.key)] = snappedf(float(e.t), 0.1)
	Profile.records[KEY] = t


## Entrée de la session pour [param key] ({} : aucune).
static func entry(key: String) -> Dictionary:
	for e in session:
		if String(e.key) == key:
			return e
	return {}


## Les records battus de la partie (les premiers temps ne sont pas des « records »).
static func beaten() -> Array:
	return session.filter(func(e): return bool(e.new) and float(e.best) > 0.0)


## Tuile du bilan pour l'entrée [param e] (sinon la durée [param fallback] de la partie) : [valeur, légende, infobulle, mis en avant].
static func tile(e: Dictionary, fallback: float, caption := "temps") -> Array:
	if e.is_empty():
		return [fmt(fallback), caption]
	var old := float(e.best)
	if bool(e.new) and old > 0.0:
		return [fmt(float(e.t)), "%s · Record !" % caption, "Ancien record : %s" % fmt(old), true]
	if old > 0.0:
		return [fmt(float(e.t)), "%s (record %s)" % [caption, fmt(old)], ""]
	return [fmt(float(e.t)), "%s · 1er temps" % caption, ""]


## Lignes d'annonce du bilan : « Record ! Latif en 1:58 (ancien 2:20) », au plus [param n] (les autres comptées).
static func record_notes(n := 2) -> Array:
	var list := beaten()
	var out: Array = []
	for e in list.slice(0, n):
		out.append("Record ! %s en %s (ancien %s)" % [String(e.label), fmt(float(e.t)), fmt(float(e.best))])
	if list.size() > n:
		out.append("… et %d autre%s record%s battu%s" % [list.size() - n, "s" if list.size() - n > 1 else "", "s" if list.size() - n > 1 else "", "s" if list.size() - n > 1 else ""])
	return out
