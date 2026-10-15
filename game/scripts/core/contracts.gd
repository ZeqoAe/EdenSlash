class_name Contracts
extends RefCounted
## Contrats de classe (lot 10) : trois contrats par classe, présentés comme des défis de classe sur la page Quêtes (Quests.class_challenges) ;
## ils se remplissent à chaque fin de run avec cette classe et rapportent 400 à 800 points de
## maîtrise. Un contrat terminé est remplacé par un autre. État : `Profile.contracts[classe]` =
## {active: [ids], progress: {id: n}, done: n}.

const TEMPLATES := [
	{"id": "kills", "text": "Vaincre %d monstres", "target": 400, "reward": 400, "counter": "kills", "max": false},
	{"id": "elites", "text": "Vaincre %d élites", "target": 15, "reward": 500, "counter": "elites", "max": false},
	{"id": "chests", "text": "Ouvrir %d coffres de la carte", "target": 20, "reward": 500, "counter": "chests", "max": false},
	{"id": "perfects", "text": "Réussir %d annulations parfaites", "target": 25, "reward": 600, "counter": "perfects", "max": false},
	{"id": "levels", "text": "Atteindre le niveau %d en une run", "target": 25, "reward": 600, "counter": "max_level", "max": true},
	{"id": "wins", "text": "Gagner %d Survie", "target": 1, "reward": 800, "counter": "wins", "max": false},
]


static func template(id: String) -> Dictionary:
	for t in TEMPLATES:
		if t.id == id:
			return t
	return {}


## État du joueur pour [param cls] (créé au besoin : trois contrats tirés de la classe et du nombre déjà faits).
static func state(cls: String) -> Dictionary:
	if not Profile.contracts.has(cls):
		Profile.contracts[cls] = {"active": [], "progress": {}, "done": 0}
	var st: Dictionary = Profile.contracts[cls]
	var r := RandomNumberGenerator.new()
	r.seed = hash([cls, int(st.done)])
	while (st.active as Array).size() < 3:
		var pool := TEMPLATES.filter(func(t): return not t.id in st.active)
		st.active.append(String(pool[r.randi() % pool.size()].id))
	return st


static func progress(cls: String, id: String) -> int:
	return int(state(cls).progress.get(id, 0))


## Fin d'une run avec [param cls] : [param totals] = {kills, elites, chests, perfects, max_level, wins}.
## Renvoie les contrats terminés [{text, reward}] (la maîtrise est ajoutée par l'appelant).
static func report(cls: String, totals: Dictionary) -> Array:
	var st := state(cls)
	var finished: Array = []
	for id in (st.active as Array).duplicate():
		var t := template(String(id))
		var cur := int(st.progress.get(id, 0))
		var add := int(totals.get(t.counter, 0))
		cur = maxi(cur, add) if t.max else cur + add
		st.progress[id] = cur
		if cur >= int(t.target):
			finished.append({"text": String(t.text) % int(t.target), "reward": int(t.reward)})
			(st.active as Array).erase(id)
			st.progress.erase(id)
			st["done"] = int(st.done) + 1
	state(cls)  # complète à trois
	return finished
