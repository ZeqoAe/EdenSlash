class_name SurvivorFavors
extends RefCounted
## Faveurs de départ du Survivant (lot SVX-4, BM-SURV SV-R1, sur le modèle des modificateurs d'étape du genre) : à la page
## du mode, une faveur au choix (ou aucune) change UNE règle de la partie, avec sa contrepartie, écrite en une phrase.
## Deux faveurs sont ouvertes d'office (un compte neuf choisit donc une faveur parmi trois, « sans faveur » compris) ; les
## autres s'ouvrent par les défis du mode (SurvivorRecords.DEFIS). Mode scellé : rien du compte n'est lu ni écrit ; le choix
## est gardé dans l'état du mode (Profile.records["sv_rewards"]["favor"]).
## Effets (clés de `fx`) : horde (vivants et meutes ×), gold (or des monstres ×), dmg / hp / move (héros ×), chest (prix des
## coffres ×), m_hp / m_atk / m_speed (monstres ordinaires et élites ×, jamais les gardiens ni le boss), xp (expérience ×),
## rerolls / bans (relances et bannissements en plus). Mesures : conception/survivor/R_SVX4.md.

const LIST := [
	{"id": "", "name": "Sans faveur", "rule": "La partie telle quelle", "unlock": "", "fx": {}},
	{"id": "horde", "name": "Horde affamée", "rule": "Plus de monstres, deux fois plus d'or", "unlock": "",
		"fx": {"horde": 1.35, "gold": 2.0}},
	{"id": "verre", "name": "Canon de verre", "rule": "Tu frappes plus fort, tu encaisses moins", "unlock": "",
		"fx": {"dmg": 1.3, "hp": 0.7}},
	{"id": "tresor", "name": "Chasse au trésor", "rule": "Coffres moins chers, monstres plus coriaces", "unlock": "ten_min",
		"fx": {"chest": 0.6, "m_hp": 1.2}},
	{"id": "course", "name": "Course folle", "rule": "Tu cours plus vite, eux aussi", "unlock": "guardians",
		"fx": {"move": 1.2, "m_speed": 1.15}},
	{"id": "etoile", "name": "Bonne étoile", "rule": "Plus de relances et de bannissements, monstres plus forts", "unlock": "first_win",
		"fx": {"rerolls": 3, "bans": 2, "m_atk": 1.12}},
	{"id": "erudit", "name": "Érudit", "rule": "Plus d'expérience, monstres plus coriaces", "unlock": "evo_3",
		"fx": {"xp": 1.25, "m_hp": 1.2}},
]

static var current := ""  # faveur de la partie en cours ("" : aucune)


## Faveur [param id] ({} si inconnue).
static func get_def(id: String) -> Dictionary:
	for f in LIST:
		if String(f.id) == id:
			return f
	return {}


## Ouverte ? (d'office, ou défi accompli, ou mode dev).
static func is_open(id: String) -> bool:
	var f := get_def(id)
	if f.is_empty():
		return false
	var u := String(f.unlock)
	return u == "" or u in SurvivorRecords.defis_done() or bool(Settings.get_v("interface", "dev_mode"))


## Condition d'ouverture en une phrase (« Défi : Tiens 10 minutes »).
static func unlock_text(id: String) -> String:
	var u := String(get_def(id).get("unlock", ""))
	for d in SurvivorRecords.DEFIS:
		if String(d.id) == u:
			return "Défi du mode : %s" % String(d.text)
	return ""


## Détail chiffré (infobulle).
static func tip(id: String) -> String:
	var f := get_def(id)
	var out: PackedStringArray = []
	var fx: Dictionary = f.get("fx", {})
	var names := {"horde": "monstres", "gold": "or des monstres", "dmg": "tes dégâts", "hp": "tes PV max", "move": "ta vitesse",
		"chest": "prix des coffres", "m_hp": "PV des monstres", "m_atk": "dégâts des monstres", "m_speed": "vitesse des monstres",
		"xp": "expérience"}
	for k in fx:
		if k in ["rerolls", "bans"]:
			out.append("+%d %s" % [int(fx[k]), "relances" if k == "rerolls" else "bannissements"])
		else:
			var nm := String(names.get(k, k))
			out.append("%s × %s" % [nm.substr(0, 1).to_upper() + nm.substr(1), String.num(float(fx[k]), 2).replace(".", ",")])
	if out.is_empty():
		return "Vingt minutes, trois gardiens, le boss à 20:00 : la partie de base."
	return " · ".join(out) + ". Gardiens et boss inchangés."


## Faveur choisie à la page du mode (gardée dans l'état du mode) ; "" si aucune ou plus ouverte.
static func chosen() -> String:
	var s: Variant = Profile.records.get(SurvivorRewards.KEY, {})
	var id := String((s as Dictionary).get("favor", "")) if s is Dictionary else ""
	return id if is_open(id) else ""


static func choose(id: String) -> void:
	var s: Variant = Profile.records.get(SurvivorRewards.KEY, {})
	var st: Dictionary = (s as Dictionary).duplicate(true) if s is Dictionary else {}
	st["favor"] = id if is_open(id) else ""
	Profile.records[SurvivorRewards.KEY] = st


## Multiplicateur [param key] de la faveur de la partie (1 sans elle) ; seulement pendant un Survivant.
static func mult(key: String) -> float:
	if not Survivor.active or current == "":
		return 1.0
	return float(get_def(current).get("fx", {}).get(key, 1.0))


## Bonus entier [param key] (relances, bannissements) de la faveur de la partie.
static func extra(key: String) -> int:
	if not Survivor.active or current == "":
		return 0
	return int(get_def(current).get("fx", {}).get(key, 0))


## Effets sur le héros (crochet de Survivor.cap_hero) : dégâts, PV max, vitesse.
static func apply_hero(p: Object) -> void:
	if current == "":
		return
	p.dmg_mult = float(p.dmg_mult) * mult("dmg")
	p.max_hp = maxf(1.0, float(p.max_hp) * mult("hp"))
	p.move_mult = float(p.move_mult) * mult("move")


## Nom affiché de la faveur de la partie ("" : aucune).
static func current_name() -> String:
	return "" if current == "" else String(get_def(current).get("name", ""))
