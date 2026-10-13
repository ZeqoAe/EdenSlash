class_name Forge
extends RefCounted
## Forge (fiche d'un objet, pendant la run) en plus de l'amélioration à l'or et de la
## joaillerie (Craft) :
## - réforger une stat bonus (nouveau jet dans sa fourchette) : des cristaux ;
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


## Nouveau jet de l'affixe [param stat] dans sa fourchette. Renvoie le texte du résultat.
static func reforge(item: Dictionary, stat: String) -> String:
	if not Profile.pay(reforge_cost(item)):
		return "Pas assez de cristaux."
	for roll in item.get("up_rolls", []):
		if String(roll[0]) == stat and Craft.UPGRADE_ROLL.has(stat):
			# nouveau jet de la stat bonus d'amélioration dans sa fourchette (palier : ×2)
			var rr: Array = Craft.UPGRADE_ROLL[stat]
			var b0 := float(roll[1])
			roll[1] = snappedf(randf_range(rr[0], rr[1]) * 2.0, 0.001 if stat in Items.PERCENT_STATS else 0.1)
			if roll.size() < 3:
				roll.append(Items.MILESTONES[0])
			Profile.save_profile()
			var k := 1.0 if stat in Items.PERCENT_STATS else Items._level_k(Items.power_level(item))
			return "%s : %s → %s" % [Items.STAT_NAMES.get(stat, Items.EXTRA_STAT_NAMES.get(stat, stat)), Items.stat_text(stat, b0 * k), Items.stat_text(stat, float(roll[1]) * k)]
	var r: Array = Items.AFFIX_RANGES[stat]
	var v := randf_range(float(r[0]), float(r[1]))
	if not stat in Items.PERCENT_STATS:
		v *= Items._level_k(Items.power_level(item))
	var before := float(item.affixes[stat])
	item.affixes[stat] = v
	Profile.save_profile()
	return "%s : %s → %s" % [Items.STAT_NAMES.get(stat, stat), Items.stat_text(stat, before), Items.stat_text(stat, v)]


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


static func fuse(type: String, tier: int) -> String:
	var key := Craft.gem_key(type, tier)
	if Profile.bag_count(key) < FUSE_COUNT:
		return "Il faut %d gemmes identiques." % FUSE_COUNT
	if Profile.gold < fuse_cost(tier):
		return "Pas assez d'or."
	Profile.gold -= fuse_cost(tier)
	Profile.take_bag(key, FUSE_COUNT)
	var out := Craft.gem_key(type, tier + 1)
	Profile.add_bag(out)
	Profile.save_profile()
	return "%d × %s → %s" % [FUSE_COUNT, Craft.label(key), Craft.label(out)]
