extends Node
## Lot BR1 : durée d'un combat entre deux héros scriptés du Battle royale de même niveau (règles du mode : profil
## « royale » de ModeRules), selon le niveau et la qualité des pièces. Les duels tournent par lots, loin les uns des autres.
##   godot --headless --fixed-fps 60 --path game res://tools/royale_duel_probe.tscn [-- --levels=1,9,20,40 --diff=3 --gear=nu,commun,dore,amel,max]
##   ... --scale=0.055 --caps=duel_b --basic=0.8 : essai d'un réglage du profil « royale » (DevEdits, rien n'est écrit)
##   ... -- --tournament=20 --gear=dore [--rounds=6] : chaque classe contre 6 autres (taux de victoire par classe)
##   ... -- --guardian --levels=10,15,20 --gear=commun,dore : chaque héros seul contre le gardien de l'autel (lot BR-R1)
## Ligne par duel : [br1] niveau · pièces · paire : durée, vainqueur, PV, dégâts infligés (part des PV max de l'autre).

const PAIRS := [["warrior", "magician"], ["black_blade", "light_blade"], ["cleric", "hunter"], ["assassin", "paladin"],
	["berserker", "ranger"], ["knight", "warlock"], ["warrior", "assassin"], ["magician", "ranger"]]
## Équipement : les 9 emplacements (Items.SLOTS) au niveau du butin du héros, [rareté min, rareté max, amélioration +N] ;
## « nu » : aucune pièce. « max » : le plus haut plausible au Battle royale (légendaire +10 partout, lot BR3).
const GEAR := {"nu": [], "commun": [0, 2, 0], "bleu": [1, 3, 0], "dore": [3, 5, 0], "amel": [3, 5, 6], "max": [5, 5, 10]}
const LIMIT := 240.0
const BATCH := 64

var results: Array = []


func _ready() -> void:
	Settings.reset_all(false)
	Profile.reset_all()
	var args := {}
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--") and "=" in a:
			args[a.substr(2).get_slice("=", 0)] = a.get_slice("=", 1)
	var levels: Array = Array(String(args.get("levels", "1,9,20,40")).split(",")).map(func(x): return int(x))
	var gears: Array = Array(String(args.get("gear", "nu,commun,dore,amel,max")).split(","))
	var diff := int(args.get("diff", "3"))
	# essais de réglage sans toucher au code : --scale=0.055 (dmg_scale), --caps=duel_b (plafonds d'un autre profil), --basic=0.8
	var over := {}
	if args.has("scale"):
		over["dmg_scale"] = float(args.scale)
	if args.has("basic"):
		over["basic_mult"] = float(args.basic)
	if args.has("caps"):
		over["caps"] = ModeRules.PROFILES[String(args.caps)].caps
	if not over.is_empty():
		DevEdits.data["modes"] = {"royale": over}
	Royale.active = true
	guardian = args.has("guardian") or "--guardian" in OS.get_cmdline_user_args()
	if args.has("gearscale"):
		_gear_scale_table()
		return
	var floor_body := StaticBody3D.new()
	floor_body.collision_layer = GameData.PHYS_WORLD
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(20000, 2, 20000)
	shape.shape = box
	shape.position.y = -1.0
	floor_body.add_child(shape)
	add_child(floor_body)
	var cases: Array = []
	var tour := args.has("tournament")
	if tour:
		var classes: Array = GameData.classes.keys()
		classes.sort()
		var rounds := int(args.get("rounds", "6"))
		for i in classes.size():
			for k in range(1, rounds + 1):
				var j := (i + k * 7) % classes.size()
				for g in gears:
					cases.append([int(args.tournament), g, [classes[i], classes[j]]])
	else:
		for lv in levels:
			for g in gears:
				for pair in PAIRS:
					cases.append([lv, g, pair])
	print("[br1] %d duels, difficulté %d, profil %s (échelle %.3f)" % [cases.size(), diff, ModeRules.profile_name(), PvpCaps.damage_scale()])
	for start in range(0, cases.size(), BATCH):
		await _run_batch(cases.slice(start, start + BATCH), diff)
	if tour:
		var wins := {}
		var games := {}
		for r in results:
			for c in r.pair.split("/"):
				games[c] = int(games.get(c, 0)) + 1
			if r.winner != "-":
				wins[r.winner] = int(wins.get(r.winner, 0)) + 1
		var rows: Array = games.keys().map(func(c): return [c, float(wins.get(c, 0)) / float(games[c])])
		rows.sort_custom(func(x, y): return x[1] > y[1])
		print("[br1] --- taux de victoire par classe ---")
		for row in rows:
			print("[br1] %-22s %3.0f%% (%d duels)" % [row[0], row[1] * 100.0, games[row[0]]])
	var by := {}
	for r in results:
		var k := "%d|%s" % [r.lv, r.gear]
		if not by.has(k):
			by[k] = []
		by[k].append(float(r.t))
	print("[br1] --- synthèse (médiane [min-max], s ; inachevés à %d s) ---" % int(LIMIT))
	for k in by:
		var ts: Array = by[k]
		ts.sort()
		print("[br1] niveau %2d · %-6s : %5.1f s [%4.1f - %5.1f] (%d duels)" % [int(k.get_slice("|", 0)), k.get_slice("|", 1), ts[ts.size() / 2], ts[0], ts[ts.size() - 1], ts.size()])
	Royale.active = false
	get_tree().quit()


## Force d'un héros scripté (√(PV max × frappe), sans le facteur de difficulté) selon la part de ses pièces qui compte
## (Royale.AI_GEAR_SCALE), rapportée à la valeur actuelle : niveaux 5 à 20, autant de coffres que de niveaux.
func _gear_scale_table() -> void:
	var xs := [0.62, 0.8, 1.0, 1.2, 1.4]
	for lv in [5, 10, 15, 20]:
		var sums := {}
		for cid in ["warrior", "magician", "cleric", "hunter", "assassin", "paladin", "berserker", "knight"]:
			for rep in 4:
				var r := Royale.make_ai(cid, 2, 1)
				var st: Dictionary = r.get_meta("royale")
				st.lv = lv
				for k in lv:
					Royale.ai_open_chest(r, 1 if k % 3 else 2)
				st.lv = lv
				for x in xs:
					var g := {}
					for slot in st.gear:
						var it: Dictionary = (st.gear[slot] as Dictionary).duplicate()
						it["quality"] = float(it.get("quality", 1.0)) * x
						var aff: Dictionary = (it.get("affixes", {}) as Dictionary).duplicate()
						for a in aff:
							aff[a] = float(aff[a]) * x
						it["affixes"] = aff
						g[slot] = it
					var h := Royale.sheet(cid, lv, g)
					sums[x] = float(sums.get(x, 0.0)) + log(sqrt(h.max_hp * h.power() * h.dmg_mult))
					h.free()
				r.free()
		var base := float(sums[0.62])
		print("[br1] force niveau %d : %s" % [lv, " ".join(xs.map(func(x): return "%.2f→%.2f" % [x, exp((float(sums[x]) - base) / 32.0)]))])
	Royale.active = false
	get_tree().quit()


## Lot BR-R1 : --guardian = chaque héros contre le gardien de l'autel (RoyaleEvent.make_guardian) au lieu d'un autre héros.
var guardian := false


func _run_batch(cases: Array, diff: int) -> void:
	var duels: Array = []
	var idx := 0
	for c in cases:
		var lv: int = c[0]
		var g: String = c[1]
		var pair: Array = c[2]
		var root := Node3D.new()
		add_child(root)
		var pos := Vector3((idx % 8) * 400.0, 0.5, (idx / 8) * 400.0)
		var hs: Array = []
		for i in 2:
			if i == 1 and guardian:
				# lot BR-R1 (--guardian) : le gardien de l'autel, au niveau du héros + RoyaleEvent.LEVEL_ADD
				var gd := RoyaleEvent.make_guardian(String(RoyaleEvent.GUARD_CLASSES[idx % RoyaleEvent.GUARD_CLASSES.size()]), mini(lv + RoyaleEvent.LEVEL_ADD, Royale.LEVEL_CAP))
				root.add_child(gd)
				gd.global_position = pos + Vector3(5.0, 0, 0)
				gd.set_ffa(idx * 2 + i + 1)
				hs.append(gd)
				continue
			var r := Royale.make_ai(String(pair[i]), diff, idx * 2 + i + 1)
			var st: Dictionary = r.get_meta("royale")
			st.lv = lv
			var spec: Array = GEAR[g]
			if not spec.is_empty():
				for slot in Items.SLOTS:
					var it := Items.generate(Royale.loot_level(lv), 0.6, slot, String(pair[i]), int(spec[0]), "", int(spec[1]))
					for u in int(spec[2]):
						Items.upgrade(it)
					st.gear[slot] = it
			st.lv = lv
			st.prog = 0.0
			Royale.refresh_ai(r, false)
			root.add_child(r)
			r.global_position = pos + Vector3(-5.0 + 10.0 * i, 0, 0)
			r.set_ffa(idx * 2 + i + 1)
			hs.append(r)
		duels.append({"root": root, "a": hs[0], "b": hs[1], "t": 0.0, "lv": lv, "gear": g, "pair": "%s/%s" % pair,
			"hp": [hs[0].max_hp, hs[1].max_hp], "done": false})
		idx += 1
	var t := 0.0
	PvpCaps.board = {}
	while t < LIMIT and duels.any(func(dd): return not dd.done):
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
		PvpCaps.elapsed = t
		for dd in duels:
			if dd.done:
				continue
			var a: ClassRival = dd.a
			var b: ClassRival = dd.b
			if a.is_dead or b.is_dead or t >= LIMIT - 0.1:
				dd.done = true
				dd.t = t
				var ea: Dictionary = PvpCaps.board.get(a.get_instance_id(), {})
				var eb: Dictionary = PvpCaps.board.get(b.get_instance_id(), {})
				dd.winner = "-" if not (a.is_dead or b.is_dead) else (dd.pair.get_slice("/", 1) if a.is_dead else dd.pair.get_slice("/", 0))
				dd.dealt = [float(ea.get("dealt", 0.0)) / float(dd.hp[1]), float(eb.get("dealt", 0.0)) / float(dd.hp[0])]
				results.append(dd)
				print("[br1] niv %2d · %-6s · %-28s : %5.1f s · gagnant %s · PV %d/%d · atk %d/%d · déf %d/%d · infligés %.0f%%/%.0f%%" % [dd.lv, dd.gear, dd.pair, t,
					dd.winner, int(dd.hp[0]), int(dd.hp[1]), int(a.atk), int(b.atk), int(a.defense), int(b.defense), dd.dealt[0] * 100.0, dd.dealt[1] * 100.0])
				dd.root.queue_free()
	for dd in duels:
		if is_instance_valid(dd.root):
			dd.root.queue_free()
	await get_tree().process_frame
