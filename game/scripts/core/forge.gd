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
