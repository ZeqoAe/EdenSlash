class_name NewsDots
extends RefCounted
## Pastilles de nouveauté (lot HUB-1, P0-1 de l'étude BM-HUB) : ce qui est nouveau depuis la dernière visite, par
## groupe, et s'éteint quand le joueur l'a vu. Aucun écran ne compte lui-même : chaque groupe dit ses clés actuelles
## ([method keys]) et le service les compare à celles déjà vues.
##
## Groupes (un par onglet ou par page) :
##   - "play" : activités ouvertes (« act:<id> ») ; vue quand sa page s'ouvre ([method see]) ;
##   - "hero.look" : apparences débloquées (« look:<id> ») ; vu à l'ouverture de Héros > Apparence ;
##   - "workshop.plan" : plans de donjon (« plan:<id> ») ; vu à l'onglet Atelier > Plans de donjon ;
##   - "carnet.succes" : succès et titres gagnés (« ach:<id> », « title:<t> ») ; vu à l'onglet Carnet > Succès ;
##   - "journal.day" / "journal.week" : quêtes accomplies et nouvelles quêtes du jour (de la semaine) ; vu au Journal.
## [method action] : une action possible, pas une nouveauté (une pièce achetable à l'Armurerie) : coche, jamais compteur.
##
## État : `Profile.records["news"] = {v, seen: {groupe: {clé: 1}}}` (sauvegardé avec le profil, donc par SafeFile).
## Migration sans casse : un groupe absent de l'état (compte d'avant, ou groupe ajouté plus tard) prend pour « vu » tout
## ce qui existe déjà au premier appel ; rien ne s'allume d'un coup sur un vieux compte.

const KEY := "news"
const GROUPS := ["play", "hero.look", "workshop.plan", "carnet.succes", "journal.day", "journal.week"]
## Bouton du menu principal -> groupes qu'il additionne.
const MENU := {"play": ["play"], "hero": ["hero.look"], "workshop": ["workshop.plan"], "collection": ["carnet.succes"],
	"journal": ["journal.day", "journal.week"]}
## Onglets : écran -> [indice d'onglet, groupe].
const TABS := {"workshop": [[1, "workshop.plan"]], "collection": [[1, "carnet.succes"]], "hero": [["appearance", "hero.look"]]}


static func _state() -> Dictionary:
	var st = Profile.records.get(KEY)
	if not st is Dictionary or not st.get("seen") is Dictionary:
		st = {"v": 1, "seen": {}}
		Profile.records[KEY] = st
	var seen: Dictionary = st.seen
	for g in GROUPS:
		if not seen.get(g) is Dictionary:
			seen[g] = _as_set(keys(g))  # première fois : tout ce qui existe déjà est vu
	return st


static func _as_set(list: Array) -> Dictionary:
	var d := {}
	for k in list:
		d[String(k)] = 1
	return d


## Clés actuelles d'un groupe (ce qui existe maintenant), sans tenir compte du vu.
static func keys(group: String) -> Array:
	var out: Array = []
	match group:
		"play":
			# ouverte pour de vrai (le mode dev ouvre tout sans rien inscrire : il n'allume aucune pastille)
			for a in Activities.LIST:
				if String(a.get("row", "")) != "" and not a.get("soon", false) and not Activities.hidden(a) \
						and (not a.has("unlock") or String(a.unlock) in Profile.unlocked_features):
					out.append("act:" + String(a.id))
		"hero.look":
			for id in Profile.owned_outfits:
				out.append("look:" + String(id))
		"workshop.plan":
			for id in Profile.plans:
				out.append("plan:" + String(id))
		"carnet.succes":
			for id in Profile.achievements:
				out.append("ach:" + String(id))
			for t in Achievements.titles():
				out.append("title:" + String(t))
		"journal.day":
			if Quests.enabled():
				var day := Quests.today()
				out.append("qnew:" + day)
				for q in Quests.daily():
					if bool(q.done):
						out.append("qdone:d:%s:%s" % [day, q.id])
		"journal.week":
			if Quests.enabled():
				var week := Quests.week_of(Quests.today())
				out.append("qweek:" + week)
				for q in Quests.weekly():
					if bool(q.done):
						out.append("qdone:w:%s:%s" % [week, q.id])
	return out


## Clés d'un groupe pas encore vues.
static func unseen(group: String) -> Array:
	var seen: Dictionary = _state().seen.get(group, {})
	return keys(group).filter(func(k): return not seen.has(String(k)))


static func count(group: String) -> int:
	return unseen(group).size()


## Somme de plusieurs groupes (un bouton du menu).
static func count_of(groups: Array) -> int:
	var n := 0
	for g in groups:
		n += count(String(g))
	return n


## La clé [param key] (ex. « act:dungeon ») est-elle nouvelle ?
static func is_new(key: String) -> bool:
	for g in GROUPS:
		if key in keys(g):
			return not (_state().seen.get(g, {}) as Dictionary).has(key)
	return false


## Une activité de Jouer pas encore ouverte depuis qu'elle s'est débloquée.
static func activity_new(id: String) -> bool:
	return not (_state().seen.get("play", {}) as Dictionary).has("act:" + id) and ("act:" + id) in keys("play")


## Marque une clé vue (une page d'activité ouverte).
static func see(key: String) -> void:
	for g in GROUPS:
		var seen: Dictionary = _state().seen[g]
		if not seen.has(key) and key in keys(g):
			seen[key] = 1
			_save()
			return


## Marque tout le groupe vu (onglet ouvert) ; les clés qui n'existent plus sont oubliées (le Journal ne grossit pas).
static func see_group(group: String) -> void:
	if not group in GROUPS:
		return
	var st := _state()
	var now := _as_set(keys(group))
	if now.size() == (st.seen[group] as Dictionary).size() and now.keys().all(func(k): return (st.seen[group] as Dictionary).has(k)):
		return
	st.seen[group] = now
	_save()


## Une action utile attend dans ce groupe (coche, pas un compteur) : une pièce achetable à l'Armurerie.
static func action(group: String) -> bool:
	match group:
		"workshop", "workshop.plan":
			if Profile.in_run or not Unlocks.is_open("armory"):
				return false
			var cid := Profile.selected_class
			return not Compass.affordable_piece(cid, Compass.missing_slots(cid)).is_empty()
	return false


## Texte de la pastille d'un bouton du menu principal : le nombre de nouveautés, sinon « ✓ » (action possible), sinon "".
static func menu_badge(menu_id: String) -> String:
	var n := count_of(MENU.get(menu_id, []))
	if n > 0:
		return str(n) if n < 10 else "9+"
	if action(menu_id):
		return "✓"
	return ""


static func _save() -> void:
	if not Profile.in_run:
		Profile.save_profile()
