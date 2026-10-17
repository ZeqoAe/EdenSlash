class_name Quests
extends RefCounted
## Quêtes (passe M5, remplace la page « Défi de maîtrise ») : trois quêtes par jour et deux par semaine, tirées du grand
## pool de QuestPool, plus les défis de classe (core/contracts.gd, présentés dans la même liste). Le Défi du jour
## (core/challenge.gd : la Survie du jour, deux contraintes) est l'une des trois quêtes du jour.
##
## Un seul bus d'événements, [method event] :
##   - `Quests.end_run(activité, gagné, extra)` à la fin d'une partie (Survie, Survivant, Donjon, Ruée, Siège, Tour, Duel,
##     Arènes, Gantelet, Battle royale) : les compteurs de la partie (Run.kills, Run.elites…) y sont lus, rien n'est compté
##     au fil de l'eau ;
##   - `Quests.event("zone_hit")` quand un coup de zone touche le héros (quête « sans dégât de zone ») ;
##   - `Quests.event("chest_open")` à l'ouverture d'un coffre de récompense au menu.
## Pendant une partie, la progression affichée (HUD, [method live_progress]) ajoute les compteurs en cours à ce qui est
## enregistré : rien n'est écrit tant que la partie dure (la sauvegarde est rechargée en fin de Tour, de Duel…).
##
## État : `Profile.records["quests"]` (aucune clé de sauvegarde nouvelle, rien à migrer ; les anciens contrats
## `Profile.contracts` et `records.challenge_day` sont lus tels quels) :
## {day, daily: [q], rerolled, week, weekly: [q], series: {n, last, claimed, best}, done}.
## Une quête q = {id, t (cible), p (progression), done, param, r (récompense), s (valeurs vues, quêtes de variété)}.
##
## Récompenses (lot A5, « jamais obligatoires ») : maîtrise de la classe la plus en retard et coffres d'apparence, rien
## d'autre — ni insignes, ni cristaux, ni fournitures, ni équipement. Une quête tirée avant A5 garde sa récompense figée
## (`q.r`, payée telle quelle par [method grant]). Pas de punition : une quête ratée se rejoue le lendemain (ou se relance une
## fois par jour), la série n'oublie que ce qui dépasse le dernier palier gagné.

const DAILY := 3
const WEEKLY := 2
## Jours d'absence pardonnés avant que la série retombe à son dernier palier.
const GRACE := 1
## Une quête du jour tirée en plus du Défi du jour ne dépasse pas ces minutes estimées (le tout tient en 20 à 40 minutes).
const DAILY_MAX_MIN := 11
## Paliers de la série (jours) et leur cadeau, cosmétique seulement.
const SERIES_GIFTS := [
	{"n": 3, "chest": "look_rare"},
	{"n": 7, "chest": "look_epic"},
	{"n": 14, "chest": "aura_rare"},
	{"n": 30, "chest": "look_legend", "title": "Régulier"},
	{"n": 60, "chest": "aura_legend"},
	{"n": 100, "chest": "look_legend", "title": "Inlassable"},
]
## Récompenses du jour selon la taille de la quête (1 à 3) : maîtrise de la classe en retard (MASTERY_SHARE des tirages),
## sinon un coffre d'apparence (LOOK_CHESTS).
const R_MASTERY := [150, 250, 350]
const MASTERY_SHARE := 0.7
const LOOK_CHESTS := ["look_common", "look_common", "look_rare"]
## Récompenses de la semaine : la première quête, maîtrise et coffre d'apparence rare ; la seconde, coffre d'apparence épique.
const W_MASTERY := 600
## Partie plus courte que cela : ne compte pour aucune quête.
const MIN_SECS := 30.0

static var _day_override := ""
static var _run: Dictionary = {}  # compteurs de la partie en cours qui ne sont pas dans Run (coups de zone)
static var _stamp := -1  # Run.started_at de la partie à laquelle _run se rapporte
static var _announced: Dictionary = {}  # quêtes déjà annoncées « accomplies » pendant la partie
static var _last: Dictionary = {}  # bilan de la dernière partie : {act, done: [{title, reward}], near: {title, p, t}, gifts: []}
static var _checked_day := ""


# --- dates -------------------------------------------------------------------------------------------------
static func today() -> String:
	return _day_override if _day_override != "" else Time.get_date_string_from_system()


## Impose la date (tests) ; "" : l'horloge.
static func set_day(iso: String) -> void:
	_day_override = iso
	_checked_day = ""


static func _unix(iso: String) -> int:
	var p := iso.split("-")
	if p.size() != 3:
		return 0
	return int(Time.get_unix_time_from_datetime_dict({"year": int(p[0]), "month": int(p[1]), "day": int(p[2]), "hour": 0, "minute": 0, "second": 0}))


## Jours entre deux dates ISO (b - a).
static func day_diff(a: String, b: String) -> int:
	return roundi(float(_unix(b) - _unix(a)) / 86400.0)


## Le lundi de la semaine de [param iso].
static func week_of(iso: String) -> String:
	var ts := _unix(iso)
	var wd := int(Time.get_datetime_dict_from_unix_time(ts).weekday)  # 0 = dimanche
	return Time.get_date_string_from_unix_time(ts - ((wd + 6) % 7) * 86400)


# --- état --------------------------------------------------------------------------------------------------
## Les quêtes sont ouvertes (fil d'éveil : « Termine 3 Survies »).
static func enabled() -> bool:
	return Unlocks.is_open("daily")


static func state() -> Dictionary:
	var st = Profile.records.get("quests")
	if not st is Dictionary:
		st = {}
		Profile.records["quests"] = st
	if String(st.get("day", "")) != today() or String(st.get("week", "")) != week_of(today()) or not st.has("series") 			or ((st.get("daily", []) as Array).is_empty() and enabled()):
		_roll(st)
	return st


static func _roll(st: Dictionary) -> void:
	if not st.has("series") or not st.series is Dictionary:
		st["series"] = {"n": 0, "last": "", "claimed": [], "best": 0}
	if not st.has("done"):
		st["done"] = 0
	var day := today()
	if String(st.get("day", "")) != day or not st.get("daily") is Array or ((st.daily as Array).is_empty() and enabled()):
		st["day"] = day
		st["daily"] = draw("daily", day) if enabled() else []
		st["rerolled"] = false
	var week := week_of(day)
	if String(st.get("week", "")) != week or not st.get("weekly") is Array or ((st.weekly as Array).is_empty() and enabled()):
		st["week"] = week
		st["weekly"] = draw("weekly", week) if enabled() else []
	_sync_challenge(st)


## Le Défi du jour déjà réussi (avant la mise à jour, ou par une autre voie) : la quête est faite.
static func _sync_challenge(st: Dictionary) -> void:
	if not Challenge.done_today():
		return
	for q in st.get("daily", []):
		if String(q.id) == "daily_challenge" and not bool(q.done):
			q["p"] = int(q.t)
			q["done"] = true
			_after_done(st, q, "daily", true)


static func daily() -> Array:
	return state().daily


static func weekly() -> Array:
	return state().weekly


static func def_of(q: Dictionary) -> Dictionary:
	return QuestPool.get_def(String(q.id))


static func done_count(period := "daily") -> int:
	var n := 0
	for q in state().get(period, []):
		if bool(q.done):
			n += 1
	return n


# --- tirage ------------------------------------------------------------------------------------------------
## Les quêtes d'une période, tirées de la date [param key] seule (même jour, même compte : mêmes quêtes). Le jour : le Défi du
## jour, puis deux quêtes d'autres activités ; la semaine : deux quêtes d'activités différentes.
static func draw(period: String, key: String) -> Array:
	var r := RandomNumberGenerator.new()
	r.seed = hash("%s|%s" % [period, key])
	var out: Array = []
	var acts := {}
	if period == "daily":
		out.append(make(QuestPool.get_def("daily_challenge"), period, 0, r))
		acts["survival"] = true
	var n := DAILY if period == "daily" else WEEKLY
	var pool := _candidates(period, [])
	_shuffle(pool, r)
	for pass_i in 2:
		for d in pool:
			if out.size() >= n:
				break
			if _taken(out, d):
				continue
			if pass_i == 0 and (acts.has(String(d.act)) or (period == "daily" and int(d.get("min", 10)) > DAILY_MAX_MIN)):
				continue
			acts[String(d.act)] = true
			out.append(make(d, period, out.size(), r))
	return out


static func _taken(list: Array, d: Dictionary) -> bool:
	for q in list:
		if String(q.id) == String(d.id):
			return true
	return false


static func _candidates(period: String, exclude: Array) -> Array:
	var out: Array = []
	for d in QuestPool.LIST:
		if QuestPool.available(d, period) and not String(d.id) in exclude:
			out.append(d)
	return out


## Mélange déterministe (le même [param r] donne le même ordre).
static func _shuffle(a: Array, r: RandomNumberGenerator) -> void:
	for i in range(a.size() - 1, 0, -1):
		var j := r.randi() % (i + 1)
		var t = a[i]
		a[i] = a[j]
		a[j] = t


## Une quête prête à jouer : cible, paramètre (classe, époque) et récompense.
static func make(d: Dictionary, period: String, index: int, r: RandomNumberGenerator) -> Dictionary:
	var q := {"id": String(d.id), "t": target_for(d, period), "p": 0, "done": false, "param": "", "r": {}, "s": []}
	match String(d.get("param", "")):
		"class":
			q["param"] = _pick_class(r)
		"epoch":
			q["param"] = str(Epochs.unlocked())
	q["r"] = _roll_reward(d, period, index, r)
	return q


static func target_for(d: Dictionary, period: String) -> int:
	if d.has("dyn"):
		return dyn_target(String(d.dyn), period)
	return int(d.get("d" if period == "daily" else "w", 1))


## Cibles qui dépendent du compte (calculées au tirage, puis figées dans la quête).
static func dyn_target(kind: String, period: String) -> int:
	match kind:
		"tower_floor":
			var best := Tower.best(1)
			if period == "daily":
				return clampi(roundi(best * 0.4 / 5.0) * 5, 5, 40)
			return clampi(roundi(best * 0.6 / 5.0) * 5, 10, 60)
	return 1


## Une classe pour une quête « avec telle classe » : plutôt une classe en retard de maîtrise.
static func _pick_class(r: RandomNumberGenerator) -> String:
	var open := QuestPool.open_classes()
	if open.is_empty():
		return "warrior"
	var late := open.filter(func(c): return Economy.lagging(String(c)))
	var pool: Array = late if not late.is_empty() and r.randf() < 0.7 else open
	return String(pool[r.randi() % pool.size()])


## Récompense d'une quête : {mastery | chest} (lot A5). Les anciennes clés (insignia, crystal, chest de forge avec lv
## et focus) ne sont plus tirées mais restent payées par [method grant] pour les quêtes tirées avant.
static func _roll_reward(d: Dictionary, period: String, index: int, r: RandomNumberGenerator) -> Dictionary:
	if String(d.get("special", "")) == "challenge":
		return {}  # la maîtrise ×2 et les 600 points du premier succès sont déjà ceux du défi
	var tier := clampi(int(d.get("tier", 1)), 1, 3) - 1
	if String(d.act) in ["survivor", "autochess"]:
		# le Survivant et l'Échiquier n'ont aucun lien avec la progression du compte : seulement de l'apparence
		return {"chest": "look_rare" if period == "weekly" else "look_common"}
	if period == "weekly":
		if index % 2 == 0:
			return {"mastery": W_MASTERY, "chest": "look_rare"} if laggard() != "" else {"chest": "look_rare"}
		return {"chest": "look_epic"}
	if r.randf() < MASTERY_SHARE and laggard() != "":
		return {"mastery": int(R_MASTERY[tier])}
	return {"chest": String(LOOK_CHESTS[tier])}


## La classe ouverte la moins maîtrisée (sous le niveau de rattrapage), "" s'il n'y en a plus.
static func laggard() -> String:
	var best := ""
	var best_lv := 1000
	for cid in QuestPool.open_classes():
		var lv := Profile.expertise_level(String(cid))
		if lv < Economy.CATCHUP_MAX and lv < best_lv:
			best_lv = lv
			best = String(cid)
	return best


# --- relance -------------------------------------------------------------------------------------------------
static func can_reroll() -> bool:
	return enabled() and not bool(state().get("rerolled", false))


## Remplace la quête du jour [param index] (pas encore faite) par une autre, une fois par jour. Renvoie vrai si c'est fait.
static func reroll(index: int) -> bool:
	var st := state()
	var list: Array = st.daily
	if not can_reroll() or index < 0 or index >= list.size() or bool(list[index].done):
		return false
	var ids: Array = []
	var acts := {}
	for i in list.size():
		ids.append(String(list[i].id))
		if i != index:
			acts[String(def_of(list[i]).get("act", ""))] = true
	var r := RandomNumberGenerator.new()
	r.seed = hash("reroll|%s|%d|%s" % [today(), index, ids])
	var pool := _candidates("daily", ids)
	if pool.is_empty():
		return false
	_shuffle(pool, r)
	var pick: Dictionary = pool[0]
	for d in pool:
		if not acts.has(String(d.act)) and int(d.get("min", 10)) <= DAILY_MAX_MIN:
			pick = d
			break
	list[index] = make(pick, "daily", index, r)
	st["rerolled"] = true
	_save()
	return true


# --- événements --------------------------------------------------------------------------------------------
## Le bus : "zone_hit" (un coup de zone touche le héros), "chest_open" (coffre de récompense ouvert au menu).
static func event(kind: String, n := 1) -> void:
	match kind:
		"zone_hit":
			_sync_run()
			_run["zone_hits"] = int(_run.get("zone_hits", 0)) + n
		"chest_open":
			if Run.active or not enabled():
				return
			var done := _apply({"act": "lobby", "chest_open": n, "secs": 999.0})
			if not done.is_empty():
				_save()


## Fin d'une partie : [param act] (survival, survivor, dungeon, rush, siege, tower, duel, arenas, gauntlet, royale), [param won],
## [param extra] (ce que Run ne sait pas : étage atteint, place, difficulté…). À appeler APRÈS le rechargement de la sauvegarde
## (Tour, Duel…) et AVANT son enregistrement.
static func end_run(act: String, won: bool, extra := {}) -> Array:
	HeroLevel.settle(act, won)  # XP de héros de la partie (lot H1) : versée ici, montrée au bilan
	var ctx := run_ctx(act, won, extra)
	_run = {}
	_announced = {}
	_last = {"act": act, "done": [], "near": {}, "gifts": []}
	if not enabled() or float(ctx.secs) < MIN_SECS:
		return []
	var before := _snapshot_progress()
	var done := _apply(ctx)
	_last["done"] = done
	if done.is_empty():
		_last["near"] = _nearest_change(before)
	return done


## Ce que la partie compte pour les quêtes (Run + extra).
static func run_ctx(act: String, won: bool, extra := {}) -> Dictionary:
	var c := {"act": act, "won": won, "class": Run.class_id, "kills": Run.kills, "elites": Run.elites, "chests": Run.chests_total,
		"perfects": Run.perfects, "level": Run.max_level, "stage": Run.stage, "revives": Run.resurrections, "epoch": Run.epoch,
		"heroic": Run.heroic_rank, "zone_hits": int(_run.get("zone_hits", 0)), "diff": 0, "allies": 0,
		"secs": float(Time.get_ticks_msec() - Run.started_at) / 1000.0, "challenge": Challenge.active and act == "survival"}
	c.merge(extra, true)
	return c


## La partie en cours, comme si elle finissait maintenant sans victoire ; {} hors partie.
static func live_ctx() -> Dictionary:
	var act := current_act()
	if act == "":
		return {}
	_sync_run()
	var extra := {}
	match act:
		"tower":
			extra = {"reached": Tower.reached, "climbed": maxi(0, Tower.reached - Tower.start_floor + 1)}
		"dungeon", "rush", "siege":
			extra = {"rooms": Tower.reached, "reached": Tower.reached, "diff": Tower.dungeon_diff, "allies": Tower.allies.size()}
		"royale":
			extra = {"pkills": Royale.kills}
		"duel", "arenas", "gauntlet":
			extra = {"mode": Duel.mode}
	return run_ctx(act, false, extra)


## L'activité de la partie en cours ("" : menu, entraînement).
static func current_act() -> String:
	if Royale.active:
		return "royale"
	if Duel.active:
		match Duel.mode:
			"arena2", "arena3":
				return "arenas"
			"gauntlet":
				return "gauntlet"
		return "duel"
	if Tower.active:
		if Tower.siege:
			return "siege"
		if Tower.rush:
			return "rush"
		return "dungeon" if Tower.is_dungeon() else "tower"
	if Training.active:
		return ""
	if Run.active:
		if Survivor.active:
			return "survivor"
		return "survival" if Run.survival else ""
	return ""


static func _sync_run() -> void:
	if Run.started_at != _stamp:
		_stamp = Run.started_at
		_run = {}
		_announced = {}


## Applique une partie (ou un événement de menu) à toutes les quêtes en cours. Renvoie les quêtes accomplies
## [{title, reward, period}] ; les récompenses sont déjà données.
static func _apply(ctx: Dictionary) -> Array:
	var st := state()
	var done: Array = []
	for period in ["daily", "weekly"]:
		for q in st.get(period, []):
			if bool(q.done):
				continue
			var d := def_of(q)
			if d.is_empty():
				continue
			var np := next_progress(d, q, ctx)
			if np == int(q.p):
				continue
			q["p"] = np
			if String(d.get("mode", "")) == "distinct":
				var key := _distinct_key(d, ctx)
				if key != "" and not key in q.s:
					q.s.append(key)
			if np >= int(q.t):
				q["p"] = int(q.t)
				q["done"] = true
				done.append(_after_done(st, q, period, false))
	return done


static func _distinct_key(d: Dictionary, ctx: Dictionary) -> String:
	return String(ctx.get("act", "")) if String(d.get("of", "")) == "act" else String(ctx.get("class", ""))


## La progression de [param q] après la partie [param ctx] (sans rien écrire).
static func next_progress(d: Dictionary, q: Dictionary, ctx: Dictionary) -> int:
	var act := String(d.act)
	var ctx_act := String(ctx.get("act", ""))
	if act == "any":
		if ctx_act == "" or ctx_act == "lobby":
			return int(q.p)
	elif act != ctx_act:
		return int(q.p)
	if String(d.get("mode", "")) == "distinct":
		var key := _distinct_key(d, ctx)
		return (q.s as Array).size() + (0 if key == "" or key in q.s else 1)
	if not when_ok(d.get("when", {}), ctx, q):
		return int(q.p)
	var v := stat_of(String(d.get("stat", "")), ctx)
	if String(d.mode) == "best":
		return maxi(int(q.p), v)
	return int(q.p) + v


static func stat_of(stat: String, ctx: Dictionary) -> int:
	match stat:
		"":
			return 0
		"win":
			return 1 if bool(ctx.get("won", false)) else 0
		"run":
			return 1
		"minutes":
			return int(float(ctx.get("secs", 0.0)) / 60.0)
		"challenge_win":
			return 1 if bool(ctx.get("challenge", false)) and bool(ctx.get("won", false)) else 0
		"boss_down", "siege_won":
			return 1 if bool(ctx.get(stat, false)) else 0
	return int(ctx.get(stat, 0))


## Les conditions d'une quête (clé « when » du pool) sont-elles remplies par la partie ?
static func when_ok(w: Dictionary, ctx: Dictionary, q: Dictionary) -> bool:
	for k in w:
		var v = w[k]
		match String(k):
			"won":
				if bool(ctx.get("won", false)) != bool(v):
					return false
			"min_diff":
				if int(ctx.get("diff", 0)) < int(v):
					return false
			"max_zone_hits":
				if int(ctx.get("zone_hits", 0)) > int(v):
					return false
			"max_revives":
				if int(ctx.get("revives", 0)) > int(v):
					return false
			"min_allies":
				if int(ctx.get("allies", 0)) < int(v):
					return false
			"min_epoch":
				var need := int(String(q.param)) if str(v) == "$param" else int(v)
				if int(ctx.get("epoch", 1)) < need:
					return false
			"min_heroic":
				if int(ctx.get("heroic", 0)) < int(v):
					return false
			"min_climbed":
				if int(ctx.get("climbed", 0)) < int(v):
					return false
			"max_place":
				var place := int(ctx.get("place", 0))
				if place <= 0 or place > int(v):
					return false
			"modes":
				if not String(ctx.get("mode", "")) in v:
					return false
			"class":
				var want := String(q.param) if str(v) == "$param" else String(v)
				if String(ctx.get("class", "")) != want:
					return false
	return true


## Une quête vient d'être accomplie : récompense, série, compteurs. Renvoie {title, reward, period}.
static func _after_done(st: Dictionary, q: Dictionary, period: String, silent: bool) -> Dictionary:
	var reward := "" if silent else grant(q.r)
	st["done"] = int(st.get("done", 0)) + 1
	Profile.record_add("quests_done", 1)
	var gifts: Array = []
	if period == "daily":
		gifts = _series_bump(st)
		if _last.has("gifts"):
			(_last["gifts"] as Array).append_array(gifts)
	var out := {"title": title(q), "reward": reward, "period": period, "gifts": gifts}
	return out


# --- série -------------------------------------------------------------------------------------------------
## Jours de série, la pause d'une journée pardonnée : au-delà, retour au dernier palier gagné.
static func series_n() -> int:
	var s: Dictionary = state().series
	var n := int(s.get("n", 0))
	var last := String(s.get("last", ""))
	if n <= 0 or last == "":
		return 0
	if day_diff(last, today()) > 1 + GRACE:
		return floor_step(n)
	return n


static func floor_step(n: int) -> int:
	var f := 0
	for g in SERIES_GIFTS:
		if int(g.n) <= n:
			f = int(g.n)
	return f


## Prochain palier au-dessus de [param n] ({n, chest, title} ; {} si tous gagnés).
static func next_gift(n: int) -> Dictionary:
	for g in SERIES_GIFTS:
		if int(g.n) > n:
			return g
	return {}


static func _series_bump(st: Dictionary) -> Array:
	var s: Dictionary = st.series
	if String(s.get("last", "")) == today():
		return []
	var n := series_n() + 1
	s["n"] = n
	s["last"] = today()
	s["best"] = maxi(int(s.get("best", 0)), n)
	Profile.records["quest_series_best"] = maxi(int(Profile.records.get("quest_series_best", 0)), n)
	var out: Array = []
	var claimed: Array = (s.get("claimed", []) as Array).map(func(x): return int(x))
	for g in SERIES_GIFTS:
		if n >= int(g.n) and not int(g.n) in claimed:
			claimed.append(int(g.n))
			Profile.chest_add(String(g.chest), 20)
			if g.has("title"):
				Profile.add_title(String(g.title))
			out.append("Série de %d jours : %s" % [int(g.n), gift_text(g)])
	s["claimed"] = claimed
	return out


static func gift_text(g: Dictionary) -> String:
	var t := Rewards.kind_name(String(g.chest)).to_lower()
	return "%s%s" % [t, " et titre « %s »" % String(g.title) if g.has("title") else ""]


# --- récompenses ---------------------------------------------------------------------------------------------
## Donne la récompense [param r] ; renvoie son texte (« +70 insignes »).
static func grant(r: Dictionary) -> String:
	var parts: PackedStringArray = []
	if int(r.get("insignia", 0)) > 0:
		Profile.insignia += int(r.insignia)
		parts.append("+%d insignes" % int(r.insignia))
	if int(r.get("crystal", 0)) > 0:
		Profile.materials["crystal"] = int(Profile.materials.get("crystal", 0)) + int(r.crystal)
		parts.append("+%d cristaux" % int(r.crystal))
	if int(r.get("mastery", 0)) > 0:
		var cid := laggard()
		if cid != "":
			Profile.add_expertise(cid, int(r.mastery), false)
			parts.append("+%d maîtrise (%s)" % [int(r.mastery), ClassGear.class_label(cid)])
		elif String(r.get("chest", "")) == "":
			# plus de classe en retard (toutes au niveau de rattrapage) : un coffre d'apparence à la place (lot A5)
			var lc := Rewards.make("look_common", 20, true)
			Profile.reward_chests.append(lc)
			parts.append(Rewards.name_of(lc).to_lower())
	if String(r.get("chest", "")) != "":
		var c := Rewards.make(String(r.chest), int(r.get("lv", 20)), true, String(r.get("focus", "")))
		Profile.reward_chests.append(c)
		parts.append(Rewards.name_of(c).to_lower())
	return ", ".join(parts)


## Les pastilles d'une quête : sa récompense (le Défi du jour : maîtrise et insignes multipliés).
static func chips_of(q: Dictionary) -> Array:
	if String(def_of(q).get("special", "")) == "challenge":
		return [{"kind": "mastery", "text": "×2", "tip": "Maîtrise doublée, et 600 points à la première victoire du jour."},
			{"kind": "insignia", "text": "×1,5", "tip": "Insignes multipliés par un et demi."}]
	return reward_chips(q.r)


## Les pastilles d'une récompense : [{kind (ResourceHelp), text, tip}].
static func reward_chips(r: Dictionary) -> Array:
	var out: Array = []
	if int(r.get("insignia", 0)) > 0:
		out.append({"kind": "insignia", "text": str(int(r.insignia))})
	if int(r.get("crystal", 0)) > 0:
		out.append({"kind": "crystal", "text": str(int(r.crystal))})
	if int(r.get("mastery", 0)) > 0:
		out.append({"kind": "mastery", "text": str(int(r.mastery)), "tip": "Maîtrise de ta classe la moins avancée."})
	if String(r.get("chest", "")) != "":
		var is_look: bool = String(r.chest).begins_with("look") or String(r.chest).begins_with("aura")
		out.append({"kind": "look" if is_look else "fortify", "text": "", "tip": Rewards.kind_name(String(r.chest))})
	return out


# --- textes ------------------------------------------------------------------------------------------------
static func title(q: Dictionary) -> String:
	var d := def_of(q)
	if d.is_empty():
		return String(q.id)
	var text := String(d.text)
	if d.has("plural") and int(q.t) > 1:
		text = String(d.plural)
	match String(d.get("param", "")):
		"class":
			return text % ClassGear.class_label(String(q.param))
		"epoch":
			return text % ["I", "II", "III", "IV"][clampi(int(String(q.param)) - 1, 0, 3)]
	if text.contains("%d"):
		return text % int(q.t)
	return text


## Le détail d'une quête sous son titre (le Défi du jour : ses deux contraintes, sans chiffre ; le détail est en infobulle).
const MOD_SHORT := {"heal_half": "Soins réduits", "elites_double": "Élites en nombre", "chests_plus": "Plus d'or, monstres plus résistants", "one_life": "Une seule vie"}


static func subtitle(q: Dictionary) -> String:
	if String(def_of(q).get("special", "")) == "challenge":
		var out: PackedStringArray = []
		for m in Challenge.modifiers_today():
			out.append(String(MOD_SHORT.get(m, Modifiers.LIST[m].text)))
		return " · ".join(out)
	return ""


## Infobulle d'une quête : les contraintes du Défi du jour en toutes lettres, sinon l'activité.
static func tooltip(q: Dictionary) -> String:
	if String(def_of(q).get("special", "")) == "challenge":
		var out: PackedStringArray = []
		for m in Challenge.modifiers_today():
			out.append(String(Modifiers.LIST[m].text))
		return "Survie de l'époque I avec :
" + "
".join(out)
	var act := act_name(q)
	return act if act != "Toutes" else ""


static func act_name(q: Dictionary) -> String:
	return String(QuestPool.ACTS.get(String(def_of(q).get("act", "")), {}).get("name", ""))


## Où mène la quête (boussole, « Y aller » du Journal) : la page de l'activité.
static func go_of(q: Dictionary) -> Dictionary:
	return QuestPool.ACTS.get(String(def_of(q).get("act", "")), {}).get("go", {"journal": true})


# --- progression en direct (HUD) -----------------------------------------------------------------------------
## Progression enregistrée plus la partie en cours (sans victoire : une quête de victoire reste à zéro jusqu'au bilan).
static func live_progress(q: Dictionary) -> int:
	if bool(q.done):
		return int(q.t)
	var ctx := live_ctx()
	if ctx.is_empty():
		return int(q.p)
	return mini(next_progress(def_of(q), q, ctx), int(q.t))


## Les quêtes non faites qui comptent pour l'activité en cours, la plus avancée d'abord.
static func current_quests() -> Array:
	var act := current_act()
	if act == "" or not enabled():
		return []
	var st := state()
	var out: Array = []
	for period in ["daily", "weekly"]:
		for q in st.get(period, []):
			var a := String(def_of(q).get("act", ""))
			if not bool(q.done) and a == act:
				out.append(q)
	out.sort_custom(func(a, b): return float(live_progress(a)) / maxf(1.0, float(a.t)) > float(live_progress(b)) / maxf(1.0, float(b.t)))
	return out


## Les quêtes qui viennent d'être accomplies pendant la partie (une seule annonce chacune) : [{title, reward}].
static func tick() -> Array:
	var out: Array = []
	for q in current_quests():
		var key := "%s|%s" % [q.id, q.t]
		if _announced.has(key):
			continue
		if live_progress(q) >= int(q.t):
			_announced[key] = true
			out.append({"title": title(q), "reward": reward_text(q.r)})
	return out


static func reward_text(r: Dictionary) -> String:
	var parts: PackedStringArray = []
	for c in reward_chips(r):
		parts.append("%s %s" % [c.text, ResourceHelp.name_of(String(c.kind)).to_lower()] if String(c.text) != "" else String(c.get("tip", "")).to_lower())
	return ", ".join(parts)


# --- bilan, boussole, menu ------------------------------------------------------------------------------------
static func _snapshot_progress() -> Dictionary:
	var out := {}
	var st := state()
	for period in ["daily", "weekly"]:
		for q in st.get(period, []):
			out["%s|%s" % [period, q.id]] = int(q.p)
	return out


## La quête qui a le plus avancé pendant la partie : {title, p, t} ou {}.
static func _nearest_change(before: Dictionary) -> Dictionary:
	var best := {}
	var best_ratio := 0.0
	var st := state()
	for period in ["daily", "weekly"]:
		for q in st.get(period, []):
			var k := "%s|%s" % [period, q.id]
			if bool(q.done) or int(q.p) <= int(before.get(k, 0)):
				continue
			var ratio := float(q.p) / maxf(1.0, float(q.t))
			if ratio > best_ratio:
				best_ratio = ratio
				best = {"title": title(q), "p": int(q.p), "t": int(q.t)}
	return best


## La ligne « Ta quête » du bilan : les quêtes accomplies, sinon la plus avancée. "" si la partie n'a rien changé.
static func report_line() -> String:
	var done: Array = _last.get("done", [])
	if not done.is_empty():
		var head := "Quête accomplie : %s" % String(done[0].title) if done.size() == 1 else "%d quêtes accomplies" % done.size()
		var rewards: PackedStringArray = []
		for d in done:
			if String(d.reward) != "":
				rewards.append(String(d.reward))
		var line := head + (" (%s)" % ", ".join(rewards) if not rewards.is_empty() else "")
		var gifts: Array = _last.get("gifts", [])
		return line + ((" · " + String(gifts[0])) if not gifts.is_empty() else "")
	var near: Dictionary = _last.get("near", {})
	if not near.is_empty():
		return "%s : %d / %d" % [near.title, int(near.p), int(near.t)]
	return ""


## Texte court du jour (bloc « Aujourd'hui » du menu, Journal).
static func card_sub() -> String:
	if not enabled():
		return ""
	var n := done_count("daily")
	var total: int = state().daily.size()
	if total > 0 and n >= total:
		return "Tout est fait aujourd'hui"
	return "%d sur %d aujourd'hui" % [n, maxi(total, DAILY)]


## Un conseil pour la boussole du lobby : {text, tip, go, nearly} ou {} (rien à proposer). [param nearly] : une quête est
## à plus de la moitié.
static func hint() -> Dictionary:
	if not enabled():
		return {}
	var st := state()
	var best := {}
	var best_ratio := -1.0
	for period in ["daily", "weekly"]:
		for q in st.get(period, []):
			if bool(q.done):
				continue
			var ratio := float(q.p) / maxf(1.0, float(q.t))
			if ratio > best_ratio:
				best_ratio = ratio
				best = q
	if best.is_empty():
		return {}
	var act := act_name(best)
	return {"text": "Quête : %s → %s" % [title(best), act] if act != "" and act != "Toutes" else "Quête : %s" % title(best),
		"tip": "Tes quêtes du jour et de la semaine sont dans le Journal (%s)." % Settings.action_label("journal", 1), "go": go_of(best), "nearly": best_ratio >= 0.5}


# --- quête suivie (lot HUB-1, P0-5 / P0-6) ----------------------------------------------------------------------
## La quête épinglée dans le Journal est celle que montre le HUD (sinon la plus avancée de l'activité jouée). Clé
## « daily|<id> » ou « weekly|<id> » dans `state().pin` ; une quête accomplie ou renouvelée n'est plus suivie (rien à migrer).
static func pin_key(period: String, q: Dictionary) -> String:
	return "%s|%s" % [period, String(q.get("id", ""))]


static func is_pinned(period: String, q: Dictionary) -> bool:
	return enabled() and String(state().get("pin", "")) == pin_key(period, q)


## Épingle (ou désépingle) la quête ; renvoie vrai si elle est maintenant suivie.
static func toggle_pin(period: String, q: Dictionary) -> bool:
	var st := state()
	var k := pin_key(period, q)
	st["pin"] = "" if String(st.get("pin", "")) == k else k
	_save()
	return String(st.pin) == k


## La quête suivie, pas encore faite : {q, period} ou {}.
static func pinned() -> Dictionary:
	if not enabled():
		return {}
	var st := state()
	var k := String(st.get("pin", ""))
	if k == "":
		return {}
	for period in ["daily", "weekly"]:
		for q in st.get(period, []):
			if pin_key(period, q) == k:
				return {} if bool(q.done) else {"q": q, "period": period}
	return {}


## Temps avant les nouvelles quêtes du jour (minuit), en clair : « 6 h 12 », « 25 min ».
static func renew_text() -> String:
	var t := Time.get_time_dict_from_system()
	var left := maxi(1, 24 * 60 - (int(t.hour) * 60 + int(t.minute)))
	return "%d h %02d" % [left / 60, left % 60] if left >= 60 else "%d min" % left


# --- défis de classe (contrats) --------------------------------------------------------------------------------
## Les contrats de [param cls] présentés comme des quêtes : [{title, p, t, reward: {mastery}, class: true}].
static func class_challenges(cls: String) -> Array:
	var out: Array = []
	var st := Contracts.state(cls)
	for id in st.active:
		var t := Contracts.template(String(id))
		if t.is_empty():
			continue
		out.append({"title": String(t.text) % int(t.target), "p": mini(Contracts.progress(cls, String(id)), int(t.target)), "t": int(t.target),
			"reward": {"mastery": int(t.reward)}, "class": true})
	return out


# --- enregistrement ------------------------------------------------------------------------------------------
static func _save() -> void:
	if not Profile.in_run:
		Profile.save_profile()
