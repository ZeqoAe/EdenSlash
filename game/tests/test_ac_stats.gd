extends Node
## L'Échiquier, lot AC-V : statistiques de combat façon TFT (AutochessStats, compteur AutochessMeter, bilan AutochessRecap).
## Combat de données connu (fiches imposées, graine fixe) : somme des dégâts infligés = somme des dégâts subis, soins
## donnés = soins reçus, auto-attaques + sorts + autres = dégâts, éliminations = chutes ; coups posés à la main : chiffres
## exacts dans les lignes, classement, MVP ; cumul de partie ; compteur et bilan remplis, onglets, B ferme, aucun mot anglais.
## godot --headless --path game res://tests/test_ac_stats.tscn

var fails := 0
var _uid := 1


func check(label: String, ok: bool) -> void:
	print(("OK    " if ok else "ÉCHEC ") + label)
	if not ok:
		fails += 1


func mk(id: String, cell: Array, over: Dictionary = {}) -> Dictionary:
	var u := {"uid": _uid, "id": id, "stars": 1, "copies": 1, "items": [], "cell": cell.duplicate(),
		"cost": AutochessPool.cost_of(id), "traits": (AutochessData.unit(id).get("traits", []) as Array).duplicate()}
	_uid += 1
	var s := {"hp": 1500.0, "atk": 70.0, "as": 1.0, "crit": 0.0, "mana_max": 60.0, "spell_base": 140.0, "def": 20.0,
		"mdef": 20.0, "range": float(AutochessData.unit(id).get("range", 1))}
	for k in over:
		s[k] = over[k]
	u["sheet"] = s
	return u


func fctx(s: int) -> Dictionary:
	return {"stage": 2, "round": 1, "kind": "jcj", "seed": s, "a": 0, "b": 1, "ghost_of": -1, "augments": [[], []],
		"guardian_mult": 1.0}


func _ready() -> void:
	Training.active = true
	Settings.reset_all()
	Profile.reset_all()
	_test_known_fight()
	_test_hand_hits()
	_test_game_acc()
	await _test_ui()
	print("TOUT EST OK (0 échec(s))" if fails == 0 else "ÉCHECS : %d" % fails)
	get_tree().quit(1 if fails > 0 else 0)


func _sum(ctx: Dictionary, key: String) -> float:
	var s := 0.0
	for fid in ctx.units:
		s += float(ctx.units[fid].stats.get(key, 0.0))
	return s


# --- Combat de données connu ---------------------------------------------------------------------------------------
func _test_known_fight() -> void:
	var ids := AutochessData.unit_ids()
	ids.sort()
	var a: Array = []
	var b: Array = []
	for i in 5:
		a.append(mk(String(ids[i * 3]), [i, i % 4]))
		b.append(mk(String(ids[i * 3 + 1]), [6 - i, (i + 1) % 4]))
	var r1 := AutochessStats.data_fight(a, b, fctx(77))
	var r2 := AutochessStats.data_fight(a, b, fctx(77))
	var ctx: Dictionary = r1.ctx
	var dealt := _sum(ctx, "dealt")
	var taken := _sum(ctx, "taken")
	print("[ac_stats] combat connu : vainqueur %d en %.1f s, dégâts %.1f / subis %.1f, soins %.1f, boucliers %.1f" % [
		int(r1.result.winner), float(r1.result.duration), dealt, taken, _sum(ctx, "heal_done"), _sum(ctx, "blocked")])
	check("combat de données joué (%.1f s)" % float(r1.result.duration), float(r1.result.duration) > 0.0 and dealt > 0.0)
	check("même graine, mêmes chiffres", is_equal_approx(dealt, _sum(r2.ctx, "dealt")) and JSON.stringify(r1.result) == JSON.stringify(r2.result))
	check("somme des dégâts infligés = somme des dégâts subis (%.2f / %.2f)" % [dealt, taken], absf(dealt - taken) < 0.01)
	# soins sans auteur (traits, atouts : ferveur, ralliement) : reçus mais donnés par personne
	check("soins donnés ≤ soins reçus (%.1f / %.1f)" % [_sum(ctx, "heal_done"), _sum(ctx, "healed")],
		_sum(ctx, "heal_done") <= _sum(ctx, "healed") + 0.01)
	var deaths := 0
	for fid in ctx.units:
		deaths += 0 if bool(ctx.units[fid].alive) else 1
	check("éliminations = chutes (%d)" % deaths, int(_sum(ctx, "kills")) == deaths)
	var split_ok := true
	var autos := 0.0
	for fid in ctx.units:
		var st: Dictionary = ctx.units[fid].stats
		var sp: Array = AutochessStats.split(st)
		autos += float(sp[0])
		if absf(float(sp[0]) + float(sp[1]) + float(sp[2]) - float(st.dealt)) > 0.01 or float(sp[2]) < -0.001:
			split_ok = false
	check("auto-attaques + sorts + autres = dégâts de chaque unité", split_ok)
	check("dégâts des auto-attaques comptés par la couche (%.0f)" % autos, autos > 0.0)
	# lignes et totaux
	for tab in AutochessStats.TABS:
		var rows := AutochessStats.rows(ctx, tab)
		var sorted := true
		for i in range(1, rows.size()):
			if float(rows[i - 1].value) < float(rows[i].value):
				sorted = false
		var t0 := AutochessStats.totals(ctx, 0)
		var t1 := AutochessStats.totals(ctx, 1)
		var sum := 0.0
		for e in rows:
			sum += float(e.value)
		check("%s : 10 lignes classées, totaux des deux camps = somme des lignes" % tab,
			rows.size() == 10 and sorted and absf(float(t0[tab]) + float(t1[tab]) - sum) < 0.01)
	var best := AutochessStats.mvp(ctx)
	var best_s := -1.0
	var arg := -1
	for fid in ctx.units:
		var s := AutochessStats.score(ctx.units[fid].stats)
		if s > best_s:
			best_s = s
			arg = int(fid)
	check("MVP = meilleur score (fid %d)" % best, best == arg and best >= 0)


# --- Coups posés à la main : chiffres exacts -----------------------------------------------------------------------------
func _test_hand_hits() -> void:
	var a := [mk("warrior", [3, 0], {"atk": 100.0, "def": 0.0, "mdef": 0.0}), mk("cleric", [2, 1], {"def": 0.0, "mdef": 0.0})]
	var b := [mk("magician", [3, 0], {"hp": 1000.0, "def": 0.0, "mdef": 0.0, "dodge": 0.0, "parry": 0.0})]
	var ctx := AutochessEffects.context(fctx(5), [AutochessDirector._placed(a, false), AutochessDirector._placed(b, true)])
	ctx["rules"] = {"fury": false, "hit_cap": false}
	AutochessEffects.start(ctx)
	for fid in ctx.units:
		var u: Dictionary = ctx.units[fid]
		u.sheet["dodge"] = 0.0
		u.sheet["parry"] = 0.0
		u.sheet["crit"] = 0.0
	var war: int = ctx.sides[0][0]
	var cle: int = ctx.sides[0][1]
	var mag: int = ctx.sides[1][0]
	AutochessEffects.attack(ctx, war, mag)
	AutochessEffects.attack(ctx, war, mag)
	AutochessEffects.spell_hit(ctx, cle, mag, 50.0)
	AutochessEffects.attack(ctx, mag, war)
	AutochessEffects.heal(ctx, cle, war, 1.0e6, "test")
	var st_w: Dictionary = ctx.units[war].stats
	var st_m: Dictionary = ctx.units[mag].stats
	var st_c: Dictionary = ctx.units[cle].stats
	print("[ac_stats] coups à la main : guerrier %.1f (auto %.1f), clerc %.1f (sorts %.1f), mage subit %.1f, soin %.1f" % [
		float(st_w.dealt), float(st_w.dealt_attack), float(st_c.dealt), float(st_c.dealt_spell), float(st_m.taken), float(st_c.heal_done)])
	check("auto-attaques du Guerrier : dégâts = dégâts d'auto-attaque", float(st_w.dealt) > 0.0 and absf(float(st_w.dealt) - float(st_w.dealt_attack)) < 0.001)
	check("sort du Clerc : dégâts de sort, pas d'auto-attaque", float(st_c.dealt_spell) > 0.0 and float(st_c.dealt_attack) == 0.0)
	check("le Magicien subit la somme des deux", absf(float(st_m.taken) - float(st_w.dealt) - float(st_c.dealt)) < 0.001)
	check("soin borné aux PV manquants, compté au Clerc", float(st_c.heal_done) > 0.0 and absf(float(st_c.heal_done) - float(ctx.units[war].stats.healed)) < 0.001)
	var rows := AutochessStats.rows(ctx, "dealt")
	check("onglet Dégâts : le premier est le plus grand (%s)" % String(rows[0].label), float(rows[0].value) >= float(rows[1].value))
	var heal_rows := AutochessStats.rows(ctx, "heal", 0)
	check("onglet Soins, son camp seulement : le Clerc en tête", heal_rows.size() == 2 and int(heal_rows[0].fid) == cle)
	var sp: Array = AutochessStats.split(st_w)
	check("barre des dégâts : tout en auto-attaque pour le Guerrier", absf(float(sp[0]) - float(st_w.dealt)) < 0.001 and float(sp[1]) == 0.0)
	check("libellés en français (Guerrier, monstres)", AutochessStats.label({"id": "", "monster": "sbire", "guardian": false}) == "Sbire"
		and AutochessStats.label({"id": "", "monster": "", "guardian": true}) == "Gardien")


# --- Cumul de la partie ------------------------------------------------------------------------------------------------
func _test_game_acc() -> void:
	var acc := AutochessStats.new_game_stats()
	var a := [mk("warrior", [3, 0]), mk("hunter", [1, 3])]
	var b := [mk("magician", [3, 0])]
	var r1 := AutochessStats.data_fight(a, b, fctx(1))
	var r2 := AutochessStats.data_fight(a, b, fctx(2))
	AutochessStats.add_round(acc, r1.ctx, 0)
	AutochessStats.add_round(acc, r2.ctx, 0)
	var w: Dictionary = acc.units.get("warrior", {})
	var want := float(r1.ctx.units[0].stats.dealt) + float(r2.ctx.units[0].stats.dealt)
	check("cumul : 2 manches, 2 classes du joueur (l'adversaire n'y est pas)", int(acc.rounds) == 2 and acc.units.size() == 2 and not acc.units.has("magician"))
	check("cumul : dégâts du Guerrier = somme des deux manches", absf(float(w.get("dealt", -1.0)) - want) < 0.01)
	var mvps := 0
	for id in acc.units:
		mvps += int(acc.units[id].mvp)
	check("un MVP de son camp par manche (%d)" % mvps, mvps == 2)
	var gr := AutochessStats.game_rows(acc, "dealt")
	check("lignes de la partie classées, héros de la partie trouvé", gr.size() == 2 and float(gr[0].value) >= float(gr[1].value) and AutochessStats.game_mvp(acc) != "")


# --- Compteur et bilan ---------------------------------------------------------------------------------------------------
func _test_ui() -> void:
	var a := [mk("warrior", [3, 0]), mk("cleric", [2, 2]), mk("hunter", [5, 3])]
	var b := [mk("magician", [3, 0]), mk("knight", [2, 0])]
	var r := AutochessStats.data_fight(a, b, fctx(9))
	var layer := CanvasLayer.new()
	add_child(layer)
	var meter := AutochessMeter.new()
	layer.add_child(meter)
	meter.show_fight(r.ctx, 0)
	await get_tree().process_frame
	var shown := meter._rows.filter(func(x): return (x as Control).visible)
	check("compteur : une ligne par unité (%d)" % shown.size(), shown.size() == 5)
	meter.step_page(1)
	check("compteur : onglet suivant (LB / RB, Tab) = Subis", meter.tab == "taken")
	meter.set_collapsed(true)
	check("compteur replié : plus d'onglets (LB / RB libres)", not meter.is_open())
	meter.set_collapsed(false)
	var recap := AutochessRecap.new()
	layer.add_child(recap)
	recap.open_round(r.ctx, 0, "Victoire", "+1 or", UiTheme.GOLD, ["Aelis", "Bérénice"])
	await get_tree().process_frame
	var rows := recap.shown_rows()
	check("bilan : 5 lignes classées, MVP nommé (%s)" % recap._mvp_name.text, rows.size() == 5 and recap._mvp_name.text != ""
		and float(rows[0].value) >= float(rows[-1].value))
	check("bilan : totaux des deux camps", recap._tot[0].text.begins_with("Aelis") and recap._tot[1].text.begins_with("Bérénice"))
	recap.step_page(1)
	check("bilan : LB / RB changent d'onglet", recap.tab == "taken")
	var ev := InputEventJoypadButton.new()
	ev.button_index = JOY_BUTTON_B
	ev.pressed = true
	Input.parse_input_event(ev)
	await get_tree().process_frame
	await get_tree().process_frame
	check("bilan : B ferme", not recap.visible)
	var acc := AutochessStats.new_game_stats()
	AutochessStats.add_round(acc, r.ctx, 0)
	recap.open_game(acc, "2e place", "1 manche", "Aelis")
	await get_tree().process_frame
	check("bilan de partie : 3 héros, héros de la partie", recap.shown_rows().size() == 3 and recap._mvp_head.text == "Héros de la partie")
	var k := InputEventKey.new()
	k.keycode = KEY_ESCAPE
	k.pressed = true
	Input.parse_input_event(k)
	await get_tree().process_frame
	await get_tree().process_frame
	check("bilan de partie : Échap ferme", not recap.visible)
	var english: Array = []
	for n in [meter, recap]:
		for l in (n as Node).find_children("*", "Label", true, false) + (n as Node).find_children("*", "Button", true, false):
			var t := String(l.get("text"))
			for w in ["Damage", "Taken", "Heal", "Shield", "Total", "Kills"]:
				if t.contains(w):
					english.append(t)
	check("aucun mot anglais (%s)" % str(english), english.is_empty())
	layer.queue_free()
