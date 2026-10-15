extends Node
## Passe M6 : chiffres de la Ruée et du Siège (niveaux, PE requise, PE conseillée, PE d'équipements types), sans jouer.
##   godot --headless --path game res://tools/m6_probe.tscn


func _ready() -> void:
	Settings.reset_all(false)
	print("[m6] Ruée : niveaux par boss")
	for d in 3:
		var lv: Array = []
		for f in range(1, Dungeons.rush_floors() + 1):
			lv.append(Dungeons.rush_level(f, d))
		print("[m6]   %s : %s · requise %d · conseillée %d" % [Dungeons.DIFF_NAMES[d], lv, Dungeons.power_required(Dungeons.RUSH, d), Rush.advised(d)])
	print("[m6] Siège : niveau / requise / conseillée par zone")
	for zid in Dungeons.zone_ids():
		var row: Array = []
		for d in 3:
			row.append("%d/%d/%d" % [Siege.level(zid, d), Siege.power_required(zid, d), Siege.advised(zid, d)])
		print("[m6]   %s : %s" % [zid, " · ".join(row)])
	print("[m6] PE d'équipements types (guerrier, mage, clerc, chasseur) et PE attendue")
	for spec in ["1.1.0", "1.3.5.1", "2.1.5.2", "2.3.10.3", "3.1.5.2", "3.3.10.4", "4.1.5.2", "4.3.10.4"]:
		var pes: Array = []
		for cid in ["warrior", "magician", "cleric", "hunter"]:
			pes.append(GearPower.hero_power(StarterGear.scenario(spec, cid)))
		print("[m6]   %s : %s" % [spec, pes])
	for lv in [14, 25, 39, 47, 60, 75, 90]:
		print("[m6]   attendue niveau %d : %d" % [lv, GearPower.expected(lv)])
	print("[m6] Ruée, tirages :")
	for s in [1234, 4821, 7777]:
		var names: Array = Rush.lineup_for(s).map(func(id): return "%s(%s)" % [id, ",".join(BossLibrary.families_of(id))])
		print("[m6]   %d : %s" % [s, names])
	get_tree().quit()
