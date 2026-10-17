class_name Forge
extends RefCounted
## Forge (fiche d'un objet, pendant la run) en plus de l'amélioration à l'or et de la
## joaillerie (Craft) :
## - réforger une stat bonus (nouveau jet dans sa fourchette, puis le joueur garde l'ancien ou le nouveau) : des cristaux ;
## - polir la qualité (nouveau jet, gardé seulement s'il est meilleur) : des cristaux ;
## - fusion de 3 gemmes identiques en une gemme de qualité supérieure.
## Les cristaux viennent du désassemblage et se gardent entre les runs.

const FUSE_COUNT := 3


# --- forgeron --------------------------------------------------------------------------------
static func reforge_cost(item: Dictionary) -> Dictionary:
	return {"crystal": 1 + int(item.rarity) / 2}


## Stats de l'objet qu'on peut réforger : ses stats bonus d'amélioration (+4, +6, +8, +10) ;
## les stats de l'objet sont fixes (seule la qualité se polit).
static func reforgeable(item: Dictionary) -> Array:
	var out: Array = []
	for r in item.get("up_rolls", []):
		if not String(r[0]) in out and Craft.UPGRADE_ROLL.has(String(r[0])):
			out.append(String(r[0]))
	if not item.has("base"):
		for s in item.get("affixes", {}).keys():
			if Items.AFFIX_RANGES.has(s) and not s in out:
				out.append(s)
	return out


## Nouveau jet de l'affixe [param stat] dans sa fourchette. Lot GX-2 : le jet est posé à côté de l'ancien
## (item.reroll = {stat, i, old, new} ; i : indice dans up_rolls, -1 : affixe) et le joueur choisit ensuite lequel garder
## ([method reforge_choose]) ; tant qu'il n'a pas choisi, la pièce garde l'ancien et ne se réajuste pas à nouveau.
## Renvoie le texte du tirage.
static func reforge(item: Dictionary, stat: String) -> String:
	if not reforge_pending(item).is_empty():
		return "Choisis d'abord : l'ancien jet ou le nouveau."
	var idx := -1
	var rolls: Array = item.get("up_rolls", [])
	for i in rolls.size():
		if String(rolls[i][0]) == stat and Craft.UPGRADE_ROLL.has(stat):
			idx = i
			break
	if idx < 0 and not (item.get("affixes", {}) as Dictionary).has(stat):
		return "Aucune stat à réajuster."
	if not Profile.pay(reforge_cost(item)):
		return "Pas assez de cristaux."
	var old := 0.0
	var v := 0.0
	if idx >= 0:
		# nouveau jet de la stat bonus d'amélioration dans sa fourchette (palier : ×2)
		var rr: Array = Craft.UPGRADE_ROLL[stat]
		old = float(rolls[idx][1])
		v = snappedf(randf_range(rr[0], rr[1]) * 2.0, 0.001 if stat in Items.PERCENT_STATS else 0.1)
	else:
		var r: Array = Items.AFFIX_RANGES[stat]
		v = randf_range(float(r[0]), float(r[1]))
		if not stat in Items.PERCENT_STATS:
			v *= Items._level_k(Items.power_level(item))
		old = float(item.affixes[stat])
	item["reroll"] = {"stat": stat, "i": idx, "old": old, "new": v}
	Profile.save_profile()
	return "%s : %s → %s" % [stat_name(stat), reroll_text(item, old), reroll_text(item, v)]


## Jet en attente de choix sur [param item] ({} : aucun ; un jet périmé, dont la stat a disparu, est oublié).
static func reforge_pending(item: Dictionary) -> Dictionary:
	var p = item.get("reroll", {})
	if not p is Dictionary or (p as Dictionary).is_empty():
		return {}
	var i := int(p.get("i", -1))
	var stat := String(p.get("stat", ""))
	var rolls: Array = item.get("up_rolls", [])
	var ok := (i >= 0 and i < rolls.size() and String(rolls[i][0]) == stat) or (i < 0 and (item.get("affixes", {}) as Dictionary).has(stat))
	if not ok:
		item.erase("reroll")
		return {}
	return p


## Garde le nouveau jet ([param take_new]) ou l'ancien ; renvoie le texte du choix.
static func reforge_choose(item: Dictionary, take_new: bool) -> String:
	var p := reforge_pending(item)
	if p.is_empty():
		return "Aucun jet en attente."
	var stat := String(p.stat)
	var v := float(p.new) if take_new else float(p.old)
	if int(p.i) >= 0:
		var roll: Array = item.up_rolls[int(p.i)]
		roll[1] = v
		if roll.size() < 3:
			roll.append(Items.MILESTONES[0])
	else:
		item.affixes[stat] = v
	item.erase("reroll")
	Profile.save_profile()
	return "%s : %s %s" % [stat_name(stat), reroll_text(item, v, int(p.i) >= 0, stat), "(nouveau jet)" if take_new else "(jet gardé)"]


static func stat_name(stat: String) -> String:
	return String(Items.STAT_NAMES.get(stat, Items.EXTRA_STAT_NAMES.get(stat, stat)))


## Valeur lisible d'un jet [param raw] de la stat en attente de [param item] (une stat bonus d'amélioration est gardée au
## niveau 1 et suit la puissance de la pièce).
static func reroll_text(item: Dictionary, raw: float, is_up := true, stat := "") -> String:
	var p: Dictionary = item.get("reroll", {}) if item.get("reroll", {}) is Dictionary else {}
	if stat == "":
		stat = String(p.get("stat", ""))
		is_up = int(p.get("i", -1)) >= 0
	var k := Items._level_k(Items.power_level(item)) if is_up and not stat in Items.PERCENT_STATS else 1.0
	return Items.stat_text(stat, raw * k)


static func polish_cost(item: Dictionary) -> Dictionary:
	return {"crystal": 2 + int(item.get("rarity", 0)) / 3}


## Nouveau jet de qualité (90-120 %), gardé seulement s'il est meilleur.
static func polish(item: Dictionary) -> String:
	if not Profile.pay(polish_cost(item)):
		return "Pas assez de cristaux."
	var before := float(item.get("quality", 1.0))
	# nouveau jet dans la fourchette de la rareté (mythique : toujours 100 %)
	var q: Array = Items.QUALITY[clampi(int(item.get("rarity", 0)), 0, Items.QUALITY.size() - 1)] if item.has("rv") else [0.9, 1.2]
	var roll := snappedf(randf_range(float(q[0]), float(q[1])), 0.01)
	Profile.save_profile()
	if roll > before:
		item.quality = roll
		Profile.save_profile()
		return "Qualité %d %% → %d %% !" % [roundi(before * 100), roundi(roll * 100)]
	return "Jet de %d %% : pas mieux que %d %%, la qualité ne change pas." % [roundi(roll * 100), roundi(before * 100)]


# --- joaillerie ------------------------------------------------------------------------------
static func fuse_cost(tier: int) -> int:
	return 40 * (tier + 1)


## Gemmes fusionnables : [{key, type, tier, count}] (au moins 3, pas déjà au maximum).
static func fusable() -> Array:
	var out: Array = []
	for k in Profile.bag_keys("gem"):
		var p := String(k).split(":")
		var tier := int(p[2])
		if tier < Craft.GEM_TIERS.size() - 1:
			out.append({"key": k, "type": p[1], "tier": tier, "count": Profile.bag_count(k)})
	return out


## Hors run (forge depuis l'équipement du lobby), l'or n'existe pas : ce qui coûte de l'or en
## run se paie en cristaux, 1 cristal pour 108 or (0.1.165 : 125, 25 avant ; les cristaux des Donjons, de la Ruée,
## du Siège et de la Tour ont été recalés avec, voir ActivityLoot). Lot GX-2 (Forge sans punition : persévérance, plus
## de rétrogradation) : 125 → 108 pour que le coût ATTENDU d'un +10 reste celui d'avant (niveau 85 : ≈ 1 610 cristaux,
## contre ≈ 1 615 avant avec des pierres de protection ; 872 si chaque tentative réussit, au pire ≈ 3 830) ; mesures
## progression_sim dans conception/progression/R_GX2.md.
const GOLD_PER_CRYSTAL := 108


## Prix d'une action de forge valant [param gold] or : en or pendant la run, en cristaux hors run.
static func price(gold: int) -> Dictionary:
	if Profile.in_run:
		return {"gold": gold}
	return {"crystal": maxi(1, ceili(gold / float(GOLD_PER_CRYSTAL)))}


## Prix en texte simple (boutons) : « 90 or » ou « 4 crist. ».
static func price_label(cost: Dictionary) -> String:
	return ("%d or" % int(cost.gold)) if cost.has("gold") else "%d crist." % int(cost.get("crystal", 0))


## Cristaux pour amener une pièce de niveau [param level] de +[param from] à +[param to] si chaque tentative
## réussit (sans compter les échecs ni les parchemins) : la somme des prix de `Items.upgrade_cost`.
static func upgrade_crystals(level: int, from: int, to: int) -> int:
	var total := 0
	for u in range(from, to):
		total += int(price(int(Items.upgrade_cost({"level": level, "upgrade": u}).gold)).get("crystal", 0))
	return total


# --- tout l'équipement à +N (lot GX-4) ---------------------------------------------------------------------------
## « Tout monter à +5 » : la boussole (Compass._forge_step) et la mesure H56 (`progression_sim --even` : équipement 80-90
## correct ≈ 32 h au lieu de 35-36) veulent toutes les pièces à +5 avant d'en pousser une plus haut. Un essai à la fois,
## mêmes règles que « Fortifier » (lot GX-2 : persévérance, aucune rétrogradation, un parchemin et le prix par essai) ;
## rien n'est changé au coût.
const EVEN_TARGET := 5


## Pièces portées (préréglage actif, 9 emplacements de la poupée : ni trophée, ni arme secondaire, qui ne donnent pas de
## stats) encore sous +[param target], dans l'ordre de la poupée.
static func even_pieces(target: int) -> Array:
	var out: Array = []
	for slot in Items.SLOTS:
		var it = Profile.equipped.get(slot)
		if it is Dictionary and not (it as Dictionary).is_empty() and not Items.is_unique(it) and int(it.get("upgrade", 0)) < target:
			out.append(it)
	return out


## Parchemins de fortification du sac utilisables par au moins une pièce du genre [param kind] dans [param pieces].
static func _scrolls_usable(kind: String, pieces: Array) -> int:
	var low := 9999
	for it in pieces:
		if Craft.fortify_kind(it) == kind:
			low = mini(low, Craft._item_level(it))
	var n := 0
	for k in Profile.bag_keys("fortify:" + kind):
		if int(String(k).split(":")[2]) >= low:
			n += Profile.bag_count(k)
	return n


## Ce que coûterait « Tout monter à +[param target] » (sans pierre) : {pieces: [{item, from, plan}], steps, tries, tries_max,
## cost (attendu), cost_max (au pire), scrolls: {genre: [attendus, au pire, utilisables dans le sac]}, no_scroll: [pièces
## sans parchemin qui convienne]}. Les coûts suivent Craft.plan_upgrade (cristaux hors partie).
static func plan_even(target: int) -> Dictionary:
	var pieces: Array = []
	var cost := {}
	var cost_max := {}
	var scrolls := {}
	var no_scroll: Array = []
	var steps := 0
	var tries := 0.0
	var worst := 0
	var todo := even_pieces(target)
	for it in todo:
		var p := Craft.plan_upgrade(it, target)
		pieces.append({"item": it, "from": int(it.get("upgrade", 0)), "plan": p})
		steps += int(p.steps)
		tries += float(p.tries)
		worst += int(p.tries_max)
		for k in p.cost:
			cost[k] = int(cost.get(k, 0)) + int(p.cost[k])
		for k in p.cost_max:
			cost_max[k] = int(cost_max.get(k, 0)) + int(p.cost_max[k])
		var kind := Craft.fortify_kind(it)
		var s: Array = scrolls.get(kind, [0, 0, 0])
		s[0] = int(s[0]) + int(p.scrolls)
		s[1] = int(s[1]) + int(p.scrolls_max)
		scrolls[kind] = s
		if Craft.fortify_for(it) == "":
			no_scroll.append(it)
	for kind in scrolls:
		scrolls[kind][2] = _scrolls_usable(String(kind), todo)
	return {"pieces": pieces, "steps": steps, "tries": tries, "tries_max": worst, "cost": cost, "cost_max": cost_max,
		"scrolls": scrolls, "no_scroll": no_scroll}


## La plus petite pierre de chance du sac utilisable sur [param it] ("" : aucune, ou réussite déjà assurée).
static func smallest_stone(it: Dictionary) -> String:
	if Craft.success_chance(it) >= 0.999:
		return ""
	var best := ""
	for id in Craft.STONES:
		var key := Craft.stone_key(String(id))
		if Profile.bag_count(key) > 0 and Craft.stone_usable(it, key) \
				and (best == "" or float(Craft.STONES[id].bonus) < float(Craft.STONES[best.split(":")[1]].bonus)):
			best = key
	return best


## Un essai de « Tout monter à +[param target] » : la pièce la moins montée d'abord (ordre de la poupée à égalité : une
## pièce ratée est reprise aussitôt, sa persévérance monte), en sautant celles qui n'ont pas de parchemin ou dont le prix
## manque ; [param stones] : avec la plus petite pierre de chance du sac quand la réussite n'est pas assurée. Renvoie
## {item, r, stone} après un essai, {done: true} quand tout est à +N, {stop: "crystal" | "scroll", item} quand plus rien
## ne peut monter (la première pièce bloquée).
static func even_step(target: int, stones := false) -> Dictionary:
	var cands := even_pieces(target)
	if cands.is_empty():
		return {"done": true}
	cands.sort_custom(func(a, b): return int(a.get("upgrade", 0)) * 100 + Items.SLOTS.find(a.slot) < int(b.get("upgrade", 0)) * 100 + Items.SLOTS.find(b.slot))
	var why := ""
	var blocked: Dictionary = {}
	for it in cands:
		var reason := ""
		if Craft.fortify_for(it) == "":
			reason = "scroll"
		elif not Profile.can_afford(price(int(Items.upgrade_cost(it).gold))):
			reason = "crystal"
		if reason != "":
			if why == "" or reason == "crystal":
				why = reason
				blocked = it
			continue
		var stone := smallest_stone(it) if stones else ""
		var r := Profile.upgrade_item(it, stone)
		if bool(r.get("error", false)):
			return {"stop": "error", "item": it, "text": String(r.get("text", ""))}
		return {"item": it, "r": r, "stone": stone}
	return {"stop": why, "item": blocked}


## « Tout monter » d'un coup (sans animation : tests, outils) : enchaîne [method even_step] jusqu'à la fin ou au manque ;
## renvoie {tries, fails, done, stop, item, bonus: [textes des stats bonus], spent: {clé: quantité}}.
static func even_all(target: int, stones := false) -> Dictionary:
	var before := {"crystal": Profile.amount("crystal")}
	var out := {"tries": 0, "fails": 0, "done": false, "stop": "", "item": {}, "bonus": []}
	while int(out.tries) < 600:
		var s := even_step(target, stones)
		if s.has("done"):
			out.done = true
			break
		if s.has("stop"):
			out.stop = String(s.stop)
			out.item = s.get("item", {})
			break
		out.tries = int(out.tries) + 1
		if not bool(s.r.ok):
			out.fails = int(out.fails) + 1
		elif String(s.r.get("stat", "")) != "":
			(out.bonus as Array).append("%s +%d : %s" % [Items.display_name(s.item), int(s.item.upgrade), Items.stat_text(String(s.r.stat), float(s.r.value))])
	out["spent"] = {"crystal": int(before.crystal) - Profile.amount("crystal")}
	return out


## La fusion garde l'ancien taux (1 cristal pour 25 or) : les gemmes se fusionnent beaucoup, ce n'est pas le poste
## de dépense de la forge (2 à 7 cristaux selon la taille), alors que le taux de 125 la rendait presque gratuite.
const FUSE_GOLD_PER_CRYSTAL := 25


## Prix d'une fusion de gemmes de la taille [param tier] : de l'or en run, des cristaux hors run.
static func fuse_price(tier: int) -> Dictionary:
	if Profile.in_run:
		return {"gold": fuse_cost(tier)}
	return {"crystal": maxi(1, ceili(fuse_cost(tier) / float(FUSE_GOLD_PER_CRYSTAL)))}


static func fuse(type: String, tier: int) -> String:
	var key := Craft.gem_key(type, tier)
	if Profile.bag_count(key) < FUSE_COUNT:
		return "Il faut %d gemmes identiques." % FUSE_COUNT
	if not Profile.pay(fuse_price(tier)):
		return "Pas assez d'or." if Profile.in_run else "Pas assez de cristaux."
	Profile.take_bag(key, FUSE_COUNT)
	var out := Craft.gem_key(type, tier + 1)
	Profile.add_bag(out)
	Profile.save_profile()
	return "%d × %s → %s" % [FUSE_COUNT, Craft.label(key), Craft.label(out)]


## Fusions possibles tout de suite (gemmes en paquets de 3, sans compter les cascades) et leur prix total.
static func fuse_all_plan() -> Dictionary:
	var n := 0
	var cost := {}
	for g in fusable():
		var k := int(g.count) / FUSE_COUNT
		if k <= 0:
			continue
		n += k
		var fp := fuse_price(int(g.tier))
		for key in fp:
			cost[key] = int(cost.get(key, 0)) + int(fp[key]) * k
	return {"count": n, "cost": cost}


## « Tout fusionner » (lot GX-4) : fusionne les plus petites tailles d'abord (les gemmes obtenues peuvent fusionner à leur
## tour), tant que le prix suit. Renvoie {count, text}.
static func fuse_all() -> Dictionary:
	var n := 0
	var before := {}
	for k in Profile.bag_keys("gem"):
		before[k] = Profile.bag_count(k)
	var guard := 0
	while guard < 500:
		guard += 1
		var list := fusable().filter(func(g): return int(g.count) >= FUSE_COUNT)
		if list.is_empty():
			break
		list.sort_custom(func(a, b): return int(a.tier) < int(b.tier))
		var g: Dictionary = list[0]
		if not Profile.can_afford(fuse_price(int(g.tier))):
			break
		fuse(String(g.type), int(g.tier))
		n += 1
	if n == 0:
		return {"count": 0, "text": "Rien à fusionner : il faut %d gemmes identiques." % FUSE_COUNT}
	var parts: PackedStringArray = []  # ce qu'on a de plus qu'avant (les tailles intermédiaires refondues ne comptent pas)
	for k in Profile.bag_keys("gem"):
		var d := Profile.bag_count(k) - int(before.get(k, 0))
		if d > 0:
			parts.append("%s ×%d" % [Craft.label(String(k)), d])
	return {"count": n, "text": "%s : %s" % [GearPower.plural(n, "fusion", "fusions"), ", ".join(parts)]}
