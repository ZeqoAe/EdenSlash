extends Node
## Mesure (lot BR3) : note d'équipement d'un héros scripté selon le nombre de coffres, ancienne règle
## (meilleure des 3 pièces au hasard) contre la nouvelle (RoyaleLoot.offer, pièces comptées à Royale.AI_GEAR_SCALE).
## godot --headless --path game res://tools/br3_ai_probe.tscn

const MARKS := [3, 6, 9, 12, 15, 20, 25, 30]
const CLASSES := ["warrior", "magician", "ranger", "cleric", "kage", "bard", "templar", "reaver"]


func _old_open(r: ClassRival, tier: int) -> void:
	var st: Dictionary = r.get_meta("royale")
	st.chests = int(st.chests) + 1
	var def: Dictionary = Royale.CHEST_TIERS[tier]
	var prof := ClassGear.profile(String(st.cid))
	var gear: Dictionary = st.gear
	var best: Dictionary = {}
	var best_gain := 0.0
	for it in Royale.chest_items(tier, int(st.lv), String(st.cid)):
		var slot := String(it.get("slot", ""))
		var gain := Items.rating(it, prof) - (Items.rating(gear[slot], prof) if gear.has(slot) else 0.0)
		if gain > best_gain:
			best_gain = gain
			best = it
	if not best.is_empty():
		gear[String(best.slot)] = best
	Royale.ai_award(r, float(def.xp))


func _ready() -> void:
	Royale.active = true
	var sums := {"old": {}, "new": {}}
	var n := 0
	for cid in CLASSES:
		for trial in 6:
			n += 1
			for mode in ["old", "new"]:
				var r := Royale.make_ai(cid, 2, 1)
				var st: Dictionary = r.get_meta("royale")
				seed(trial * 977 + CLASSES.find(cid))
				for i in 30:
					var roll := randf()
					var tier := 0 if roll < 0.59 else (1 if roll < 0.87 else 2)
					Run.hero_level = int(st.lv)  # (le butin suit le niveau : celui du joueur, pris égal à celui du héros)
					if mode == "old":
						_old_open(r, tier)
					else:
						Royale.ai_open_chest(r, tier)
					if (i + 1) in MARKS:
						var k := str(i + 1)
						var g: Dictionary = st.gear if mode == "old" else Royale.ai_gear(st.gear)  # (nouvelle règle : AI_GEAR_SCALE)
						sums[mode][k] = float(sums[mode].get(k, 0.0)) + Royale.gear_score(g, cid, int(st.lv))
				r.free()
	for m in MARKS:
		var k := str(m)
		print("[br3] coffres %2d : ancienne %.1f · nouvelle %.1f (%+.0f %%)" % [m, sums.old[k] / n, sums.new[k] / n, (sums.new[k] / sums.old[k] - 1.0) * 100.0])
	get_tree().quit()
