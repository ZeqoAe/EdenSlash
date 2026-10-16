class_name SurvivorRewards
extends RefCounted
## Fin d'un Survivant (lot S6, DECISIONS_JOUEUR §5) : seulement des coffres d'apparence selon l'avancée, des titres de
## victoire et le bilan ; jamais de puissance ni de monnaie de progression (ni insignes, ni maîtrise, ni découvertes).
##
## Trois paliers d'avancée, chacun récompensé UNE fois par palier de difficulté ([param tier], 1 à 5) :
##   tenir 10 minutes -> coffre d'apparence commun ; vaincre les trois gardiens -> rare ; vaincre le boss -> mythique
##   (légendaire dès le palier II). Ensuite, plafond par jour : un coffre commun (10 minutes) et un rare (boss vaincu)
##   au plus. Le total de coffres du mode est donc borné, et le farm cosmétique impossible.
## Le titre de victoire (un par palier) est cosmétique.
##
## L'état des plafonds vit dans `Profile.records["sv_rewards"]` (pas de clé de sauvegarde nouvelle) : Survivor.finish
## appelle settle APRÈS avoir remis les records du hub, donc ce qui est écrit ici est gardé. Lot S8 : `wins` (palier ->
## victoires) y vit aussi ; une victoire ouvre le palier suivant (Survivor.palier_open).

const TIME_MIN := 600.0  # « tenir 10 minutes » (secondes de carte)
const GUARDIANS := 3
const MILESTONES := [
	{"id": "time", "text": "Tenir 10 minutes", "chest": "look_common", "daily": "look_common"},
	{"id": "guardians", "text": "Vaincre les trois gardiens", "chest": "look_rare", "daily": ""},
	{"id": "win", "text": "Vaincre le boss", "chest": "look_epic", "daily": "look_rare"},
]
const TITLES := ["Survivant", "Survivant endurci", "Survivant implacable", "Survivant légendaire", "Maître des survivants"]
const KEY := "sv_rewards"

## Suivi de la run en cours (écrit par le directeur à chaque image) : secondes de carte, gardiens vaincus, arène.
static var stats := {}
## Bilan de la dernière run (rempli par settle, lu par le bilan) :
## {res, tier, time, guardians, boss, kills, chests: [{type, text, kind}], title, new_title, build}.
static var last := {}


static func reset() -> void:
	stats = {}
	last = {}


## Suivi de la run : appelé par SurvivorDirector.update.
static func track(sv: SurvivorDirector) -> void:
	stats = {"time": sv.d.time, "guardians": sv.guardians_killed(), "total": SurvivorDirector.guardian_total(), "arena": sv.arena_at >= 0.0,
		"early": sv.early_seconds()}


# --- plafonds ----------------------------------------------------------------------------------------------------------
static func _state() -> Dictionary:
	var s: Variant = Profile.records.get(KEY, {})
	var out: Dictionary = (s as Dictionary).duplicate(true) if s is Dictionary else {}
	if String(out.get("day", "")) != Quests.today():
		out["day"] = Quests.today()
		out["today"] = []
	if not out.has("first"):
		out["first"] = []
	return out


static func _first_key(id: String, tier: int) -> String:
	return "%s:%d" % [id, tier]


## Coffre d'apparence de la première fois : le boss vaincu donne un coffre légendaire dès le palier II.
static func first_chest(m: Dictionary, tier: int) -> String:
	if String(m.id) == "win" and tier >= 2:
		return "look_legend"
	return String(m.chest)


## Les récompenses du palier [param tier] pour la page du lobby : [{text, type (coffre), done (déjà gagné), title}].
static func board(tier := 1) -> Array:
	var st := _state()
	var out: Array = []
	for m in MILESTONES:
		out.append({"text": String(m.text), "type": first_chest(m, tier), "done": _first_key(String(m.id), tier) in st.first,
			"title": title_of(tier) if String(m.id) == "win" else ""})
	return out


## Paliers d'avancée atteints par la run [param res] (ids de MILESTONES).
static func reached(res: String) -> Array:
	var out: Array = []
	if float(stats.get("time", 0.0)) >= TIME_MIN:
		out.append("time")
	if int(stats.get("guardians", 0)) >= GUARDIANS:
		out.append("guardians")
	if res == "victoire":
		out.append("win")
	return out


## Ce que la run [param res] au palier [param tier] donnerait : [{id, type, text, kind ("première fois" | "du jour")}].
## Ne change rien (le journal et le bilan peuvent l'appeler).
static func plan(res: String, tier := 1) -> Array:
	var st := _state()
	var out: Array = []
	var reach := reached(res)
	for m in MILESTONES:
		var id := String(m.id)
		if not id in reach:
			continue
		if not _first_key(id, tier) in st.first:
			out.append({"id": id, "type": first_chest(m, tier), "text": String(m.text), "kind": "first"})
		elif String(m.daily) != "" and not id in st.today:
			out.append({"id": id, "type": String(m.daily), "text": String(m.text), "kind": "daily"})
	return out


## Titre de victoire du palier [param tier].
static func title_of(tier: int) -> String:
	return String(TITLES[clampi(tier, 1, TITLES.size()) - 1])


## Victoires au palier [param tier] (lot S8 : une victoire ouvre le palier suivant). Les profils d'avant S8 n'ont que la
## première récompense « win:<palier> » : elle compte pour une victoire.
static func wins(tier: int) -> int:
	var s: Variant = Profile.records.get(KEY, {})
	if not s is Dictionary:
		return 0
	var n := int((s as Dictionary).get("wins", {}).get(str(tier), 0))
	if n == 0 and _first_key("win", tier) in (s as Dictionary).get("first", []):
		n = 1
	return n


## Récompenses de la run terminée sur [param res] (victoire, defaite, abandon) au palier [param tier] : coffres
## d'apparence et titre, rangés tout de suite dans le menu Coffres. Appelé par Survivor.finish après la remise du hub.
static func settle(res: String, counted_kills: int, tier := -1) -> void:
	tier = clampi(tier if tier > 0 else Survivor.palier, 1, 5)
	var opened := 0  # palier ouvert par cette victoire (0 : aucun)
	if res == "victoire" and tier < Survivor.PALIERS.size() and not Survivor.palier_open(tier + 1, false):
		opened = tier + 1
	var st := _state()
	if res == "victoire":
		var w: Dictionary = st.get("wins", {})
		w[str(tier)] = maxi(int(w.get(str(tier), 0)), wins(tier)) + 1
		st["wins"] = w
	var given: Array = []
	for g in plan(res, tier):
		Profile.chest_add(String(g.type), maxi(Run.max_level, 1))
		if String(g.kind) == "first":
			(st.first as Array).append(_first_key(String(g.id), tier))
		else:
			(st.today as Array).append(String(g.id))
		given.append(g)
	Profile.records[KEY] = st
	var title := ""
	var new_title := false
	if res == "victoire":
		title = title_of(tier)
		new_title = not title in Profile.extra_titles
		Profile.add_title(title)
	last = {"res": res, "tier": tier, "time": float(stats.get("time", 0.0)), "guardians": int(stats.get("guardians", 0)),
		"guardians_total": int(stats.get("total", GUARDIANS)),
		"boss": res == "victoire" or bool(stats.get("arena", false)), "kills": counted_kills, "chests": given, "title": title,
		"new_title": new_title, "opened": opened, "build": build()}


# --- bilan : le build final -------------------------------------------------------------------------------------------
## Le build à la fin de la run (lu avant que le hub ne remette l'équipement) : arme, pièces, panoplie, sorts, passifs.
static func build() -> Dictionary:
	var worn: Dictionary = Profile.equipped
	var pieces: Array = []
	var plus10 := 0
	var perfect := 0
	var awake := 0
	var weapon := {}
	for slot in Items.SLOTS:
		var it: Dictionary = worn.get(slot, {})
		if it.is_empty():
			continue
		var up := int(it.get("upgrade", 0))
		var e := {"slot": slot, "name": String(it.get("name", "")), "upgrade": up, "rarity": int(it.get("rarity", 0)),
			"passives": SurvivorGear.wake(it), "perfect": SurvivorGear.is_perfect(it)}
		if slot == "weapon":
			weapon = e
			continue
		pieces.append(e)
		plus10 += 1 if up >= 10 else 0
		perfect += 1 if bool(e.perfect) else 0
		awake += int(e.passives)
	if not weapon.is_empty() and bool(weapon.perfect):
		perfect += 1
	var set_id := ""
	var set_n := 0
	var counts := Items.set_counts(worn)
	for sid in counts:
		if SurvivorPool.sets().has(String(sid)) and int(counts[sid]) > set_n:
			set_id = String(sid)
			set_n = int(counts[sid])
	var spells: Array = []
	for s in Run.all_skills():
		spells.append({"name": String(Run.skill_def(int(s.id)).get("name", "")), "rank": int(s.get("rank", 1))})
	spells.sort_custom(func(a, b): return int(a.rank) > int(b.rank))
	return {"weapon": weapon, "pieces": pieces, "set": SurvivorPool.panoply_name(set_id) if set_id != "" else "", "set_n": set_n,
		"plus10": plus10, "perfect": perfect, "awake": awake, "spells": spells, "passives": Run.passives.size(),
		"slots": Items.SLOTS.size()}


## Valeur [param v] de la propriété du hub [param k] sans ce que le Survivant a le droit de donner (coffres d'apparence,
## titres, plafonds) ni l'état des quêtes : sert aux tests « le hub est intact ».
static func hub_view(k: String, v: Variant) -> Variant:
	match k:
		"reward_chests":
			return (v as Array).filter(func(c): return not String(c.type).begins_with("look_"))
		"records":
			var r: Dictionary = (v as Dictionary).duplicate(true)
			r.erase(KEY)
			r.erase("quests")
			return r
		"extra_titles":
			return (v as Array).filter(func(t): return not String(t) in TITLES)
	return v


# --- quêtes et journal ------------------------------------------------------------------------------------------------
## Ce que les quêtes (Quests.end_run) lisent en plus de la run : le temps de CARTE tenu (les choix de carte en pause ne
## comptent pas) et les gardiens vaincus.
static func quest_extra() -> Dictionary:
	return {"secs": float(stats.get("time", 0.0)), "guardians": int(stats.get("guardians", 0))}


## Champs propres au Survivant ajoutés à la ligne du journal de run (fermée avant settle : on y lit le plan).
static func journal() -> Dictionary:
	var out := {"sv_zone": Survivor.zone_id, "palier": Survivor.palier, "sv_time": snappedf(float(stats.get("time", 0.0)), 0.1),
		"sv_guardians_down": int(stats.get("guardians", 0))}
	var p: Array = plan(Run.result, Survivor.palier) if Run.result != "" else []
	out["sv_rewards"] = p.map(func(g): return "%s:%s" % [g.id, g.type])
	return out
