class_name SurvivorRecords
extends RefCounted
## Records et défis du Survivant (lot SVX-3, BM-SURV SV-M2 et SV-M3) : propres au mode, sans lien avec le compte.
##
## Records, par classe et par palier (Profile.records["sv_rewards"]["best"]["<classe>:<palier>"]) : victoire la plus rapide
## (durée de la partie), survie la plus longue (parties perdues), plus haut niveau, plus de dégâts, plus de monstres vaincus.
## « Nouveau record ! » au bilan quand une valeur déjà tenue est battue (la première partie pose les scores sans fanfare) ;
## « Première victoire avec <classe> » et le compte des classes gagnées (x / 60) à la page du mode.
##
## Défis (« defis », ids accomplis) : objectifs internes au mode, vérifiés à la fin de chaque partie ; certains donnent un
## titre (cosmétique, listé dans SurvivorRewards.TITLES). Jamais de puissance, jamais de monnaie du compte.

const KEYS := ["win", "time", "level", "dmg", "kills"]
const NAMES := {"win": "Victoire la plus rapide", "time": "Survie la plus longue", "level": "Plus haut niveau",
	"dmg": "Plus de dégâts", "kills": "Plus de monstres vaincus"}

## Défis : id, text (ce qu'il faut faire), title (titre gagné, "" : aucun). Vérifiés par [method _done].
const DEFIS := [
	{"id": "first_win", "text": "Gagne une partie", "title": ""},
	{"id": "ten_min", "text": "Tiens 10 minutes", "title": ""},
	{"id": "guardians", "text": "Vaincs les trois gardiens d'une partie", "title": ""},
	{"id": "evo_1", "text": "Prends une évolution", "title": ""},
	{"id": "evo_3", "text": "Prends trois évolutions dans une partie", "title": "Alchimiste"},
	{"id": "set_5", "text": "Complète une panoplie (5 / 5)", "title": "Paré de pied en cap"},
	{"id": "spells_12", "text": "Remplis ta grille de 12 sorts", "title": ""},
	{"id": "plus10_4", "text": "Porte quatre pièces à +10", "title": "Forgeron de fortune"},
	{"id": "perfect_3", "text": "Trois jets parfaits dans une partie", "title": ""},
	{"id": "level_50", "text": "Atteins le niveau 50", "title": ""},
	{"id": "kills_3000", "text": "Vaincs 3 000 monstres dans une partie", "title": "Faucheur de hordes"},
	{"id": "quick_guard", "text": "Vaincs chaque gardien en moins d'une minute", "title": "Briseur de gardiens"},
	{"id": "daring", "text": "Entre dans l'arène avant 17:00 et gagne", "title": "Téméraire"},
	{"id": "fast_boss", "text": "Vaincs le boss en moins de 90 secondes", "title": ""},
	{"id": "off_class", "text": "Gagne avec une arme qui n'est pas celle de ta classe", "title": ""},
	{"id": "tier_3", "text": "Gagne au palier III", "title": ""},
	{"id": "tier_5", "text": "Gagne au palier V", "title": "Légende des hordes"},
	{"id": "classes_5", "text": "Gagne avec cinq classes différentes", "title": "Touche-à-tout"},
	{"id": "codex_weapons", "text": "Porte dix types d'arme (Codex)", "title": ""},
	{"id": "codex_evo", "text": "Découvre dix évolutions (Codex)", "title": "Grand alchimiste"},
	{"id": "codex_sets", "text": "Complète cinq panoplies différentes (Codex)", "title": ""},
	{"id": "codex_monsters", "text": "Vois 100 monstres différents (Codex)", "title": ""},
]

## Dernière partie (bilan) : {records: [{key, text, old, new}], first_win: bool, defis: [{text, title}]}.
static var last := {}


static func _key(cid: String, tier: int) -> String:
	return "%s:%d" % [cid, tier]


## Records de la classe [param cid] au palier [param tier] (copie) : {win, time, level, dmg, kills} (absents : jamais joués).
static func best(cid: String, tier: int) -> Dictionary:
	var s: Variant = Profile.records.get(SurvivorRewards.KEY, {})
	var b: Variant = (s as Dictionary).get("best", {}) if s is Dictionary else {}
	var e: Variant = (b as Dictionary).get(_key(cid, tier), {}) if b is Dictionary else {}
	return (e as Dictionary).duplicate() if e is Dictionary else {}


## Classes qui ont gagné une partie du Survivant (tout palier).
static func classes_won() -> Array:
	var s: Variant = Profile.records.get(SurvivorRewards.KEY, {})
	var b: Variant = (s as Dictionary).get("best", {}) if s is Dictionary else {}
	var out: Array = []
	if b is Dictionary:
		for k in b:
			if (b[k] as Dictionary).has("win") and not String(k).get_slice(":", 0) in out:
				out.append(String(k).get_slice(":", 0))
	return out


## Défis accomplis (ids).
static func defis_done() -> Array:
	var s: Variant = Profile.records.get(SurvivorRewards.KEY, {})
	var d: Variant = (s as Dictionary).get("defis", []) if s is Dictionary else []
	return (d as Array).duplicate() if d is Array else []


## Valeur affichée d'un record (« 21:34 », « 1,2 M », « 48 »).
static func fmt(key: String, v: float) -> String:
	match key:
		"win", "time":
			return SurvivorDirector.clock(v)
		"dmg":
			return SurvivorBilan.short_number(v)
	return Items.fmt_num(roundi(v))


## Valeurs de la partie qui s'achève : {win?, time?, level, dmg, kills}.
static func run_values(res: String) -> Dictionary:
	var t := float(SurvivorRewards.stats.get("time", 0.0))
	var out := {"level": float(Run.max_level), "dmg": SurvivorLog.total(), "kills": float(Run.kills)}
	if res == "victoire":
		out["win"] = t
	else:
		out["time"] = t
	return out


## Verse la partie dans les records et les défis de [param st] (« sv_rewards », écrit par SurvivorRewards.settle) ; renvoie
## [member last].
static func settle(st: Dictionary, res: String, tier: int) -> Dictionary:
	var b: Dictionary = st.get("best", {}) if st.get("best") is Dictionary else {}
	var key := _key(Run.class_id, tier)
	var cur: Dictionary = b.get(key, {}) if b.get(key) is Dictionary else {}
	var won_before := classes_won_in(b)
	var vals := run_values(res)
	var recs: Array = []
	for k in KEYS:
		if not vals.has(k):
			continue
		var v := float(vals[k])
		if v <= 0.0:
			continue
		var better: bool = not cur.has(k) or (v < float(cur[k]) - 0.05 if k == "win" else v > float(cur[k]) + 0.0001)
		if better:
			if cur.has(k):
				recs.append({"key": k, "text": String(NAMES[k]), "old": float(cur[k]), "new": v})
			cur[k] = v
	b[key] = cur
	st["best"] = b
	var first_win: bool = res == "victoire" and not Run.class_id in won_before
	# défis
	var done: Array = st.get("defis", []) if st.get("defis") is Array else []
	var fresh: Array = []
	var ctx := _context(st, res, tier)
	for d in DEFIS:
		if String(d.id) in done or not _done(String(d.id), ctx):
			continue
		done.append(String(d.id))
		fresh.append({"text": String(d.text), "title": String(d.title)})
		if String(d.title) != "":
			Profile.add_title(String(d.title))
	st["defis"] = done
	last = {"records": recs, "first_win": first_win, "won": classes_won_in(b).size(), "defis": fresh}
	return last


static func classes_won_in(b: Dictionary) -> Array:
	var out: Array = []
	for k in b:
		if b[k] is Dictionary and (b[k] as Dictionary).has("win") and not String(k).get_slice(":", 0) in out:
			out.append(String(k).get_slice(":", 0))
	return out


## Ce que les défis lisent de la partie.
static func _context(st: Dictionary, res: String, tier: int) -> Dictionary:
	var bd := SurvivorRewards.build()
	var ttk: Array = SurvivorRewards.stats.get("ttk", [])
	var w: Dictionary = Profile.equipped.get("weapon", {})
	var c: Dictionary = st.get("codex", {}) if st.get("codex") is Dictionary else {}
	var arena := float(SurvivorRewards.stats.get("arena_at", -1.0))
	return {"win": res == "victoire", "tier": tier, "time": float(SurvivorRewards.stats.get("time", 0.0)),
		"guardians": int(SurvivorRewards.stats.get("guardians", 0)), "ttk": ttk, "evos": SurvivorEvo.taken().size(),
		"set_n": int(bd.get("set_n", 0)), "spells": Run.all_skills().size(), "plus10": int(bd.get("plus10", 0)),
		"perfect": int(bd.get("perfect", 0)), "level": Run.max_level, "kills": Run.kills,
		"off_class": not w.is_empty() and Items.weapon_type_of(w) != Items.default_weapon_type(Run.class_id),
		"arena_at": arena, "boss_secs": float(SurvivorRewards.stats.get("time", 0.0)) - arena if arena >= 0.0 else INF,
		"classes": classes_won_in(st.get("best", {})).size(), "c_weapons": (c.get("weapons", []) as Array).map(func(k): return String(k).get_slice(":", 0)),
		"c_evo": (c.get("evo", []) as Array).size(), "c_sets": (c.get("sets", []) as Array).size(), "c_monsters": (c.get("monsters", []) as Array).size()}


static func _done(id: String, x: Dictionary) -> bool:
	match id:
		"first_win":
			return x.win
		"ten_min":
			return float(x.time) >= SurvivorRewards.TIME_MIN
		"guardians":
			return int(x.guardians) >= SurvivorRewards.GUARDIANS
		"evo_1":
			return int(x.evos) >= 1
		"evo_3":
			return int(x.evos) >= 3
		"set_5":
			return int(x.set_n) >= 5
		"spells_12":
			return int(x.spells) >= Survivor.SPELL_MAX
		"plus10_4":
			return int(x.plus10) >= 4
		"perfect_3":
			return int(x.perfect) >= 3
		"level_50":
			return int(x.level) >= 50
		"kills_3000":
			return int(x.kills) >= 3000
		"quick_guard":
			return (x.ttk as Array).size() >= SurvivorRewards.GUARDIANS and (x.ttk as Array).all(func(t): return float(t) >= 0.0 and float(t) < 60.0)
		"daring":
			return x.win and float(x.arena_at) >= 0.0 and float(x.arena_at) < 1020.0
		"fast_boss":
			return x.win and float(x.boss_secs) < 90.0
		"off_class":
			return x.win and x.off_class
		"tier_3":
			return x.win and int(x.tier) >= 3
		"tier_5":
			return x.win and int(x.tier) >= 5
		"classes_5":
			return int(x.classes) >= 5
		"codex_weapons":
			var types := {}
			for t in x.c_weapons:
				types[t] = true
			return types.size() >= 10
		"codex_evo":
			return int(x.c_evo) >= 10
		"codex_sets":
			return int(x.c_sets) >= 5
		"codex_monsters":
			return int(x.c_monsters) >= 100
	return false


## Titres que les défis peuvent donner (SurvivorRewards.TITLES les compte comme titres du mode).
static func titles() -> Array:
	return DEFIS.filter(func(d): return String(d.title) != "").map(func(d): return String(d.title))
