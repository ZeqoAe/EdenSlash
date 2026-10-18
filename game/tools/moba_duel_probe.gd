extends Node
## Les Deux Voies, lot MB-E (R_MB_E.md § 3) : sonde du 1 contre 1 entre héros scriptés (profil de combat « moba »).
## Montée par MobaDirector quand la ligne de commande contient --moba-duel=<niveau> (avec --moba-heroes=watch) : l'IA de
## poste est coupée, les 4 paires (Brumes, jungle, tir, soutien : bleu contre rouge) se battent loin des voies, chacune
## au niveau demandé ; ligne « [moba] duel <bleu>-<rouge> niv N : X s (vainqueur) » à la première chute de chaque paire,
## « [moba] duel fin » quand toutes ont fini (ou à 120 s). Options : --moba-duel-items=N (N objets du parcours chacun).
## godot --headless --fixed-fps 60 --path game res://scenes/world.tscn -- --moba --moba-heroes=watch --moba-diff=2
##   --moba-duel=6 --moba-speed=4 --auto-quit

var d: MobaDirector
var level := 1
var pairs: Array = []  # [bleu, rouge, début, fini]
var t0 := -1.0


func start(dir: MobaDirector, lv: int, n_items: int) -> void:
	d = dir
	level = lv
	for h in d.heroes:
		var hs: MobaHero = d.info[h]
		hs.ai = null
		if hs.level < lv:
			hs.add_xp(float(MobaData.xp_total(lv)) - hs.xp)
			while not hs.pending.is_empty():
				hs.choose(hs.auto_choice())
		hs.gold = 99999.0
		hs.in_shop = true
		var r := MobaItems.route(hs, [])
		for i in mini(n_items, r.size()):
			hs.items.append(String(r[i]))
		d.apply_level(hs)
	for role in 4:
		var b: Combatant = null
		var rr: Combatant = null
		for h in d.heroes:
			var hs: MobaHero = d.info[h]
			if hs.role == role:
				if hs.side == 0:
					b = h
				else:
					rr = h
		if b != null and rr != null:
			pairs.append([b, rr, -1.0, false])


func _physics_process(_delta: float) -> void:
	if d == null or pairs.is_empty():
		return
	if t0 < 0.0:
		if Moba.t < 1.0:
			return
		t0 = Moba.t
		var c: Vector3 = d.map.moba.center
		for i in pairs.size():
			var z := -21.0 + 14.0 * i
			var pb := c + Vector3(-3.5, 0.6, z)
			var pr := c + Vector3(3.5, 0.6, z)
			pairs[i][0].global_position = pb
			pairs[i][1].global_position = pr
			pairs[i][2] = Moba.t
	var done := true
	for p in pairs:
		if bool(p[3]):
			continue
		var a: Combatant = p[0]
		var b: Combatant = p[1]
		if a.is_dead or b.is_dead:
			p[3] = true
			var w := "bleu" if b.is_dead else "rouge"
			print("[moba] duel %s-%s niv %d : %.1f s (%s)" % [d.info[a].cid, d.info[b].cid, level, Moba.t - float(p[2]), w])
			continue
		done = false
		for pair in [[a, b], [b, a]]:
			var x: Combatant = pair[0]
			if x is MobaRival:
				(x as MobaRival).goal = Vector3.INF
				(x as MobaRival)._player = pair[1]
				(x as MobaRival).avoid.clear()
	if done or Moba.t - t0 > 120.0:
		for p in pairs:
			if not bool(p[3]):
				print("[moba] duel %s-%s niv %d : > 120 s (aucun)" % [d.info[p[0]].cid, d.info[p[1]].cid, level])
		pairs.clear()
		print("[moba] duel fin")
		if "--auto-quit" in OS.get_cmdline_user_args():
			get_tree().quit()
