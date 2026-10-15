extends Node
## Simulateur des cartes du Survivant (lot S3) : des runs de CHOIX seulement (sans combat), avec le vrai tirage
## (SurvivorCards.roll, chest_cards) et le vrai choix automatique (SurvivorCards.auto_pick). Modèle de run (SPEC §6.3) :
## choix de départ, 37 montées de niveau sur 20 minutes, 14 coffres ouverts (tirés dans SurvivorDirector.LAYOUT),
## 3 gardiens (5, 10, 15 min), 3 enclumes, 2 géants et 5 sanctuaires (cartes de niveau). Le joueur relance quand la
## meilleure carte est faible (relances de la run) et ne passe jamais.
## Sortie : distribution des builds (types d'arme, sets portés, 3/5 et 5/5, pièces à +10, sorts et leurs niveaux,
## passifs, évolutions), cartes de repli vues (cartes « mortes »), diversité (build le plus fréquent), et la table des
## effets d'amélioration de sort par niveau (moyennes mesurées).
## godot --headless --path game res://tools/sv_cards_sim.tscn -- runs=200 [seed=1 who=pilote|bot|chercheur]
##   pilote : choix du pilote (--autoplay : un peu de hasard) ; bot : choix strict du Bot ; chercheur : vise un set.

const CLASSES := ["warrior", "thief", "hunter", "cleric", "magician"]
const LEVEL_UPS := 37
const CHESTS := 14
const GUARDIANS := [5.0, 10.0, 15.0]
const ANVILS := 3
const FREE_CHOICES := 7  # 2 géants + 5 sanctuaires


func _ready() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := String(a).split("=")
		if kv.size() == 2:
			args[kv[0]] = kv[1]
	if not Profile._test:
		print("Lancer avec au moins un argument (-- runs=200) : le profil de test est utilisé, jamais la vraie partie.")
		get_tree().quit(1)
		return
	Settings.reset_all()
	Profile.reset_all()
	Profile.in_run = false
	var runs := int(args.get("runs", "200"))
	var seed_v := int(args.get("seed", "1"))
	var who: Array = ["pilote", "bot", "chercheur"] if not args.has("who") else [String(args.who)]
	# réglages du profil « survivor » à essayer (ex. set_damp=0.15 w_piece_new=0.8), le temps de la simulation
	var over := {}
	for k in args:
		if not k in ["runs", "seed", "who"]:
			over[k] = float(args[k])
	if not over.is_empty():
		var modes: Dictionary = DevEdits.data.get("modes", {})
		var m: Dictionary = (modes.get("survivor", {}) as Dictionary).duplicate()
		m.merge(over, true)
		modes["survivor"] = m
		DevEdits.data["modes"] = modes
		print("réglages essayés : %s" % over)
	for w in who:
		var r := simulate(runs, seed_v, w)
		report(r, w)
	Profile.reset_all()
	get_tree().quit(0)


## [param runs] runs de choix ; renvoie les mesures agrégées. [param who] : « pilote » (choix du pilote, un peu de
## hasard), « bot » (choix strict du Bot), « chercheur » (vise un set de son type d'armure, choisi au départ : sur les
## emplacements de set il ne prend que ses pièces, et passe plutôt que de prendre une autre pièce).
static func simulate(runs: int, seed_v: int, who: String) -> Dictionary:
	var random := who == "pilote"
	SurvivorCards.seed_with(seed_v)
	seed(seed_v)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var agg := {"runs": runs, "weapon": {}, "family_best": {}, "set_best": [], "full5": 0, "three": 0, "pieces": [], "plus10": [],
		"sum_up": [], "spells": [], "spell_lvl": [], "spell10": [], "passives": [], "passive_runs": {}, "evos": 0, "offers": 0,
		"fallback_cards": 0, "dead_offers": 0, "picks": {}, "builds": {}, "rerolls": 0, "first": {},
		"spell_by_rank": {}, "spell_tier_by_rank": {}, "max_up": [], "target5": 0, "target3": 0, "skips": 0}
	for i in runs:
		var cid := String(CLASSES[i % CLASSES.size()])
		Survivor.start(cid, "limestone")
		Run.hero_level = 1
		target = ""
		if who == "chercheur":
			var armor := String(ClassGear.profile(cid).get("armor", ""))
			var mine: Array = SurvivorPool.sets().filter(func(x): return SurvivorPool.armor_of(String(x)) == armor)
			target = String(mine[rng.randi() % mine.size()]) if not mine.is_empty() else ""
		SurvivorCards.minutes_override = 0.0
		var events := _events(rng)
		# choix de départ
		var first := SurvivorCards.first_offer()
		var fp := _choose(first, random, agg)
		agg.first[String(fp.type)] = int(agg.first.get(String(fp.type), 0)) + 1
		for ev in events:
			SurvivorCards.minutes_override = float(ev.t)
			match String(ev.kind):
				"level":
					Run.hero_level += 1
					_choose(Run.roll_cards(3), random, agg, func(): return Run.roll_cards(3))
				"chest", "guardian", "anvil":
					var cards := SurvivorCards.chest_cards(String(ev.box))
					if not cards.is_empty():
						_choose(cards, random, agg)
				"free":
					_choose(Run.roll_cards(3), random, agg, func(): return Run.roll_cards(3))
		_measure(agg)
		if target != "":
			var got := int(Items.set_counts(Profile.equipped).get(target, 0))
			agg.target5 += 1 if got >= 5 else 0
			agg.target3 += 1 if got >= 3 else 0
		Run.finish("abandon")
		Profile.end_run_survival()
	SurvivorCards.minutes_override = -1.0
	target = ""
	return agg


## Chronologie d'une run : montées de niveau régulières, coffres et lieux au hasard, gardiens à heure fixe.
static func _events(rng: RandomNumberGenerator) -> Array:
	var out: Array = []
	for k in LEVEL_UPS:
		out.append({"t": 20.0 * (k + 1) / (LEVEL_UPS + 1), "kind": "level"})
	var layout: Array = SurvivorDirector.LAYOUT.duplicate()
	for k in CHESTS:
		var box := String(layout.pop_at(rng.randi() % layout.size()))
		out.append({"t": rng.randf_range(0.5, 19.5), "kind": "chest", "box": box})
	for t in GUARDIANS:
		out.append({"t": float(t) + 0.01, "kind": "guardian", "box": SurvivorDirector.GUARDIAN_BOX})
	for k in ANVILS:
		out.append({"t": rng.randf_range(2.0, 19.0), "kind": "anvil", "box": SurvivorDirector.ANVIL_BOX})
	for k in FREE_CHOICES:
		out.append({"t": rng.randf_range(1.0, 19.5), "kind": "free"})
	out.sort_custom(func(a, b): return float(a.t) < float(b.t))
	return out


## Set visé par le joueur « chercheur » ("" : il ne cherche pas de set).
static var target := ""


## Note d'une carte pour le chercheur : sur un emplacement de set, seulement les pièces du set visé ; le reste comme le Bot.
static func _seek_score(o: Dictionary) -> float:
	if String(o.get("type", "")) == "sv_piece" and String(o.slot) in SurvivorPool.SET_SLOT_ORDER:
		return 95.0 if String(o.item.get("set", "")) == target else 0.0
	if String(o.get("type", "")) == "sv_piece_up" and String(Profile.equipped.get(String(o.slot), {}).get("set", "")) == target:
		return SurvivorCards.score(o) + 10.0
	return SurvivorCards.score(o)


static func _best(cards: Array, random: bool) -> Dictionary:
	if target == "":
		return SurvivorCards.auto_pick(cards, random)
	var best: Dictionary = {}
	var bs := 0.0
	for c in cards:
		if _seek_score(c) > bs:
			bs = _seek_score(c)
			best = c
	return best


## Choisit dans [param cards] (relance si la meilleure carte est faible et qu'il reste des relances) et l'applique ;
## le chercheur passe quand aucune carte ne lui convient.
static func _choose(cards: Array, random: bool, agg: Dictionary, reroll := Callable()) -> Dictionary:
	agg.offers += 1
	var pick := _best(cards, random)
	if reroll.is_valid() and (pick.is_empty() or (_seek_score(pick) if target != "" else SurvivorCards.score(pick)) < 30.0) and Run.rerolls_left() > 0:
		Run.rerolls_used += 1
		agg.rerolls += 1
		cards = reroll.call()
		pick = _best(cards, random)
	if pick.is_empty():
		SurvivorCards.skip()
		agg["skips"] = int(agg.get("skips", 0)) + 1
		return {}
	var fb := cards.filter(func(c): return SurvivorCards.FAMILY.get(String(c.type), "") == "fallback").size()
	agg.fallback_cards += fb
	if fb == cards.size():
		agg.dead_offers += 1
	var t := String(pick.get("type", ""))
	agg.picks[t] = int(agg.picks.get(t, 0)) + 1
	if t == "upgrade":
		var key := int(pick.rank_to)
		var tiers: Dictionary = agg.spell_tier_by_rank.get(key, {})
		tiers[String(pick.tier)] = int(tiers.get(String(pick.tier), 0)) + 1
		agg.spell_tier_by_rank[key] = tiers
	Run.apply_card(pick)
	if t == "upgrade":
		var e := Run.skill_entry(int(pick.id))
		var cell: Dictionary = agg.spell_by_rank.get(int(e.rank), {"n": 0, "pow": 0.0, "cd": 0.0, "riders": 0})
		cell.n += 1
		cell.pow += float(e.get("dmg", e.get("heal", e.get("dur", 0.0))))
		cell.cd += minf(float(e.get("cd", 0.0)), 0.6)
		cell.riders += (e.get("riders", []) as Array).size()
		agg.spell_by_rank[int(e.rank)] = cell
	return pick


static func _measure(agg: Dictionary) -> void:
	var w: Dictionary = Profile.equipped.get("weapon", {})
	var wt := Items.weapon_type_of(w) if not w.is_empty() else "aucune"
	agg.weapon[wt] = int(agg.weapon.get(wt, 0)) + 1
	var counts := Items.set_counts(Profile.equipped)
	var best := 0
	var best_sid := ""
	for sid in counts:
		if int(counts[sid]) > best:
			best = int(counts[sid])
			best_sid = String(sid)
	agg.set_best.append(best)
	if best >= 5:
		agg.full5 += 1
	if best >= 3:
		agg.three += 1
	var fam := SurvivorPool.family(best_sid) if best >= 2 else "aucune"
	agg.family_best[fam] = int(agg.family_best.get(fam, 0)) + 1
	var pieces: Array = Profile.equipped.values()
	agg.pieces.append(pieces.size())
	agg.plus10.append(pieces.filter(func(it): return int(it.get("upgrade", 0)) >= 10).size())
	var s := 0
	var mx := 0
	for it in pieces:
		s += int(it.get("upgrade", 0))
		mx = maxi(mx, int(it.get("upgrade", 0)))
	agg.sum_up.append(s)
	agg.max_up.append(mx)
	var sp := Run.all_skills()
	agg.spells.append(sp.size())
	var lv := 0
	for e in sp:
		lv += int(e.rank)
	agg.spell_lvl.append(float(lv) / maxf(sp.size(), 1.0))
	agg.spell10.append(sp.filter(func(e): return int(e.rank) >= 10).size())
	agg.passives.append(Run.passives.size())
	for id in Run.passives:
		agg.passive_runs[id] = int(agg.passive_runs.get(id, 0)) + 1
	agg.evos += Run.passives.keys().filter(func(id): return not (Boons.get_def(String(id)).get("requires", []) as Array).is_empty()).size()
	# signature d'un build : type d'arme, famille du set principal, 3 passifs les plus puissants
	var top: Array = Run.passive_power.keys()
	top.sort_custom(func(a, b): return float(Run.passive_power[a]) > float(Run.passive_power[b]))
	var sig := "%s|%s|%s" % [wt, fam, ",".join(PackedStringArray(top.slice(0, 3)))]
	agg.builds[sig] = int(agg.builds.get(sig, 0)) + 1


static func _mean(a: Array) -> float:
	var t := 0.0
	for x in a:
		t += float(x)
	return t / maxf(a.size(), 1.0)


static func _hist(a: Array) -> String:
	var h := {}
	for x in a:
		h[int(x)] = int(h.get(int(x), 0)) + 1
	var keys := h.keys()
	keys.sort()
	return " ".join(PackedStringArray(keys.map(func(k): return "%d:%d" % [k, h[k]])))


static func report(r: Dictionary, who: String) -> void:
	var n := float(r.runs)
	print("\n=== %d runs · joueur « %s » ===" % [int(r.runs), who])
	if who == "chercheur":
		print("set visé : 5/5 dans %.1f %% des runs (1 run sur %s) · 3/5 et plus : %.0f %% · choix passés : %.1f par run" % [100.0 * r.target5 / n,
			("%.0f" % (n / r.target5)) if int(r.target5) > 0 else "∞", 100.0 * r.target3 / n, float(r.skips) / n])
	print("premier choix pris : %s" % r.first)
	print("arme portée en fin de run : %s" % r.weapon)
	print("set le plus porté (pièces : runs) : %s · 3/5 et plus : %.0f %% · 5/5 : %.1f %% · famille : %s" % [_hist(r.set_best),
		100.0 * r.three / n, 100.0 * r.full5 / n, r.family_best])
	print("pièces portées (sur 9) : %s · somme des +N : %.1f · pièces à +10 : %.2f (%s) · meilleur +N : %s" % [_hist(r.pieces),
		_mean(r.sum_up), _mean(r.plus10), _hist(r.plus10), _hist(r.max_up)])
	print("sorts (sur 6) : %s · niveau moyen : %.1f · sorts au niveau 10 : %.2f (%s)" % [_hist(r.spells), _mean(r.spell_lvl),
		_mean(r.spell10), _hist(r.spell10)])
	print("passifs de la run : %.1f en moyenne · évolutions : %.2f par run" % [_mean(r.passives), float(r.evos) / n])
	var pr: Array = r.passive_runs.keys()
	pr.sort_custom(func(a, b): return int(r.passive_runs[a]) > int(r.passive_runs[b]))
	print("passifs les plus fréquents (part des runs) : %s" % ", ".join(PackedStringArray(pr.slice(0, 6).map(func(k): return "%s %.0f %%" % [k, 100.0 * r.passive_runs[k] / n]))))
	print("passifs les plus rares : %s · passifs jamais vus : %d / %d" % [", ".join(PackedStringArray(pr.slice(maxi(pr.size() - 4, 0)).map(func(k): return "%s %.0f %%" % [k, 100.0 * r.passive_runs[k] / n]))),
		Cards.passive_effects().filter(func(id): return not r.passive_runs.has(id)).size(), Cards.passive_effects().size()])
	print("cartes prises par type : %s" % r.picks)
	print("choix : %d · cartes de repli vues : %d (%.2f %% des cartes) · choix tout en repli : %d · relances : %.1f par run" % [int(r.offers),
		int(r.fallback_cards), 100.0 * r.fallback_cards / maxf(3.0 * r.offers, 1.0), int(r.dead_offers), float(r.rerolls) / n])
	var bk: Array = r.builds.keys()
	bk.sort_custom(func(a, b): return int(r.builds[a]) > int(r.builds[b]))
	print("builds distincts (arme | famille du set | 3 passifs les plus forts) : %d sur %d runs ; le plus fréquent : %s (%d)" % [bk.size(), int(r.runs),
		bk[0] if not bk.is_empty() else "-", int(r.builds.get(bk[0], 0)) if not bk.is_empty() else 0])
	print("amélioration de sort, moyenne mesurée par niveau (effet cumulé de l'entrée du sort) :")
	print("  niv. | cartes | dégâts / soins / durée | recharge | bonus d'attribut | raretés de la carte")
	var ranks: Array = r.spell_by_rank.keys()
	ranks.sort()
	for k in ranks:
		var c: Dictionary = r.spell_by_rank[k]
		print("  %4d | %6d | %+21.0f %% | %7.0f %% | %16.2f | %s" % [int(k), int(c.n), 100.0 * c.pow / c.n, -100.0 * c.cd / c.n, float(c.riders) / c.n,
			r.spell_tier_by_rank.get(k, {})])
