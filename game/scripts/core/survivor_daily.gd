class_name SurvivorDaily
extends RefCounted
## Partie du jour du Survivant (lot SVX-4, BM-SURV SV-Q1) : chaque jour, la même partie pour tous : même zone, même classe
## (une des cinq classes de départ, ouvertes à tout compte), même carte (Run.seed) et mêmes tirages de cartes
## (SurvivorCards.seed_with), palier I, sans faveur. Tableau local des cinq meilleures parties du jour (score : une victoire
## d'abord, la plus rapide ; sinon la plus longue survie ; puis les monstres vaincus). Rien du compte : l'état vit dans
## Profile.records["sv_rewards"]["daily"]. Les coffres d'apparence restent ceux du palier I (mêmes plafonds).

const KEEP := 5

static var active := false  # la partie en cours est celle du jour


## Graine du jour [param day] (« 2026-10-17 » ; défaut : aujourd'hui).
static func seed_of(day := "") -> int:
	var d := day if day != "" else Quests.today()
	return absi(hash("sv_daily|" + d)) % 2000000000 + 1


## Zone du jour.
static func zone_of(day := "") -> String:
	var zs := Survivor.zones()
	return String(zs[seed_of(day) % zs.size()]) if not zs.is_empty() else "limestone"


## Classe du jour (une des classes de départ : ouvertes à tous).
static func class_of(day := "") -> String:
	var cs: Array = Progression.START_CLASSES
	return String(cs[(seed_of(day) / 7) % cs.size()])


## Lance la partie du jour (le lobby change ensuite de scène).
static func start() -> void:
	var s := seed_of()
	Survivor.start(class_of(), zone_of(), 1, "")
	active = true
	Run.seed = s  # même carte pour tous
	SurvivorCards.seed_with(s)  # mêmes tirages


## Score d'une partie (plus haut = mieux).
static func score(e: Dictionary) -> float:
	var t := float(e.get("time", 0.0))
	var won := String(e.get("res", "")) == "victoire"
	return (1.0e7 + (5000.0 - t) * 100.0 if won else t * 100.0) + float(e.get("kills", 0)) * 0.01


## Les meilleures parties du jour [param day] : [{class, res, time, level, kills}], meilleure d'abord.
static func board(day := "") -> Array:
	var d := day if day != "" else Quests.today()
	var s: Variant = Profile.records.get(SurvivorRewards.KEY, {})
	var dd: Variant = (s as Dictionary).get("daily", {}) if s is Dictionary else {}
	if not dd is Dictionary or String((dd as Dictionary).get("day", "")) != d:
		return []
	return ((dd as Dictionary).get("runs", []) as Array).duplicate(true)


## Verse la partie du jour terminée dans [param st] (état « sv_rewards », écrit par SurvivorRewards.settle) ; renvoie son
## rang (1 à KEEP) ou 0 si elle n'entre pas au tableau.
static func settle(st: Dictionary, res: String) -> int:
	if not active:
		return 0
	active = false
	var day := Quests.today()
	var dd: Dictionary = st.get("daily", {}) if st.get("daily") is Dictionary else {}
	if String(dd.get("day", "")) != day:
		dd = {"day": day, "runs": []}
	var e := {"class": Run.class_id, "res": res, "time": snappedf(float(SurvivorRewards.stats.get("time", 0.0)), 0.1),
		"level": Run.max_level, "kills": Run.kills}
	var runs: Array = dd.get("runs", [])
	runs.append(e)
	runs.sort_custom(func(a, b): return score(a) > score(b))
	var rank := runs.find(e) + 1
	dd["runs"] = runs.slice(0, KEEP)
	st["daily"] = dd
	return rank if rank <= KEEP else 0


## Ligne d'une partie du tableau : « Victoire en 21:34 · niveau 41 · 9 870 monstres ».
static func line(e: Dictionary) -> String:
	var won := String(e.get("res", "")) == "victoire"
	return "%s %s · niveau %d · %s monstres" % ["Victoire en" if won else "Tenu", SurvivorDirector.clock(float(e.get("time", 0.0))),
		int(e.get("level", 1)), Items.fmt_num(int(e.get("kills", 0)))]
