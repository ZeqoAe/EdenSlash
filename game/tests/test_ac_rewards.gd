extends Node
## L'Échiquier, lot AC-I : récompenses (coffres d'apparence par place, une fois par difficulté puis par jour, titres de
## victoire et d'exploit), ouverture des difficultés, quêtes (apparence seulement), puis une partie complète au pilote en
## durées réduites lancée comme le lobby la lance : mode scellé pendant la partie, hub et profil du compte intacts après,
## bilan commun (Rejouer, Statistiques, Menu principal), sauvegarde effacée ; reprise d'une partie gardée (même difficulté,
## mêmes stratèges IA).
## godot --headless --path game res://tests/test_ac_rewards.tscn

const SAVE := "user://aci_test_autochess.json"

var fails := 0


func check(label: String, ok: bool) -> void:
	print(("OK    " if ok else "ÉCHEC ") + label)
	if not ok:
		fails += 1


func _frames(n := 2) -> void:
	for _i in n:
		await get_tree().process_frame


func _ready() -> void:
	Settings.reset_all()
	Profile.reset_all()
	Profile.selected_class = "warrior"
	Settings.set_v("interface", "dev_mode", false)
	_test_caps()
	_test_exploits()
	_test_quests()
	await _test_game()
	await _test_resume()
	Autochess.clear_save(SAVE)
	AutochessScreen.config = {}
	print("TOUT EST OK (0 échec(s))" if fails == 0 else "ÉCHECS : %d" % fails)
	get_tree().quit(fails)


func _types(got: Dictionary) -> Array:
	return (got.get("chests", []) as Array).map(func(c): return "%s:%s:%s" % [c.id, c.type, c.kind])


func _settle(place: int, d: int, extra := {}) -> Dictionary:
	var info := {"diff": d, "place": place, "hp": 20, "rerolls": 3, "flags": {}}
	info.merge(extra, true)
	return AutochessRewards.settle(info)


# --- plafonds ----------------------------------------------------------------------------------------------------
func _test_caps() -> void:
	Profile.records.erase(AutochessRewards.KEY)
	check("compte neuf : Recrue et Vétéran ouvertes, Champion et Légende fermées",
		AutochessRewards.diff_open(0) and AutochessRewards.diff_open(1) and not AutochessRewards.diff_open(2) and not AutochessRewards.diff_open(3))
	var chests0 := Profile.reward_chests.size()
	var got := _settle(5, 0)
	check("5e place : aucun coffre, aucun titre, partie comptée", _types(got).is_empty() and (got.titles as Array).is_empty()
		and AutochessRewards.count("games", 0) == 1 and Profile.reward_chests.size() == chests0)
	got = _settle(3, 0)
	check("1er top 4 en Recrue : coffre commun (première fois) " + str(_types(got)), _types(got) == ["top4:look_common:first"])
	got = _settle(4, 0)
	check("2e top 4 : coffre commun du jour " + str(_types(got)), _types(got) == ["top4:look_common:daily"])
	got = _settle(3, 0)
	check("3e top 4 le même jour : plus rien", _types(got).is_empty())
	got = _settle(2, 0)
	check("1er top 2 : coffre rare (première fois) " + str(_types(got)), _types(got) == ["top2:look_rare:first"])
	got = _settle(1, 0)
	check("1re victoire en Recrue : rare du jour + mythique, titre « Stratège » " + str(_types(got)),
		_types(got) == ["top2:look_rare:daily", "win:look_epic:first"] and (got.titles as Array).size() == 1
		and String(got.titles[0].title) == "Stratège" and bool(got.titles[0].new) and "Stratège" in Profile.extra_titles)
	got = _settle(1, 0)
	check("2e victoire le même jour : rien de plus, titre déjà porté", _types(got).is_empty() and not bool(got.titles[0].new))
	var n_look := Profile.reward_chests.filter(func(c): return String(c.type).begins_with("look_")).size()
	check("coffres rangés dans le menu Coffres (%d) : apparence seulement" % n_look, n_look == 5 and Profile.reward_chests.size() == chests0 + 5)
	var st: Dictionary = Profile.records[AutochessRewards.KEY]
	st["day"] = "2000-01-01"
	got = _settle(1, 0)
	check("le lendemain : un commun et un rare du jour, rien d'autre " + str(_types(got)),
		_types(got) == ["top4:look_common:daily", "top2:look_rare:daily"])
	check("records : parties, top 4, victoires, meilleure place", AutochessRewards.count("games", 0) == 8
		and AutochessRewards.count("top4", 0) == 7 and AutochessRewards.count("wins", 0) == 3 and AutochessRewards.best(0) == 1)
	check("Champion encore fermé (il faut un top 4 en Vétéran)", not AutochessRewards.diff_open(2, false))
	got = _settle(4, 1)
	check("top 4 en Vétéran : Champion s'ouvre", AutochessRewards.diff_open(2, false) and int(got.opened) == 2
		and _types(got) == ["top4:look_common:first"])
	got = _settle(1, 2)
	check("victoire en Champion : coffre légendaire, titre « Grand tacticien », Légende s'ouvre " + str(_types(got)),
		"win:look_legend:first" in _types(got) and int(got.opened) == 3 and AutochessRewards.diff_open(3, false)
		and "Grand tacticien" in Profile.extra_titles)
	got = _settle(5, 3, {"abandoned": true})
	check("abandon à la 5e place : aucun coffre", _types(got).is_empty() and bool(got.abandoned))
	got = _settle(1, 3, {"abandoned": true, "stage": 2})
	check("abandon dès l'étape 2 à la 1re place : rien (pas de coffre du jour par abandon)", _types(got).is_empty()
		and (got.titles as Array).is_empty() and bool(got.early) and AutochessRewards.count("wins", 3) == 0)
	got = _settle(3, 3, {"abandoned": true, "stage": 4})
	check("abandon à l'étape 4 à la 3e place : la place compte", _types(got) == ["top4:look_common:first"] and not bool(got.early))
	Settings.set_v("interface", "dev_mode", true)
	Profile.records.erase(AutochessRewards.KEY)
	check("mode dev : toutes les difficultés ouvertes (sans rien écrire)", AutochessRewards.diff_open(3) and not AutochessRewards.diff_open(3, false))
	Settings.set_v("interface", "dev_mode", false)
	check("hub_view : coffres d'apparence et titres du mode écartés", (AutochessRewards.hub_view("reward_chests", Profile.reward_chests) as Array).is_empty()
		and (AutochessRewards.hub_view("extra_titles", Profile.extra_titles) as Array).is_empty())
	Profile.reward_chests.clear()
	Profile.extra_titles.clear()


# --- exploits ------------------------------------------------------------------------------------------------------
func _test_exploits() -> void:
	Profile.records.erase(AutochessRewards.KEY)
	var g := Autochess.new()
	g.save_path = ""
	var strats: Array = [null]
	for i in AutochessData.PLAYERS - 1:
		strats.append(Autochess.RandomStrategist.new())
	g.start(5, strats)
	var flags := {}
	AutochessRewards.track(g, 0, flags)
	check("début de partie : aucun exploit de plateau", flags.is_empty())
	var five: Array = AutochessData.units_of_cost(5)
	g.players[0].board.append({"uid": 9001, "id": String(five[0]), "stars": 3, "copies": 9, "items": [], "cell": [0, 0]})
	AutochessRewards.track(g, 0, flags)
	check("une unité de coût 5 à trois étoiles : « Trois étoiles »", bool(flags.get("three_stars", false)) and not flags.has("pure_blood"))
	var fam := String(AutochessData.FAMILY_TRAIT[1])
	var ids: Array = AutochessData.unit_ids().filter(func(id): return fam in (AutochessData.unit(String(id)).get("traits", []) as Array))
	g.players[0].board.clear()
	for k in 9:
		g.players[0].board.append({"uid": 9100 + k, "id": String(ids[k]), "stars": 1, "copies": 1, "items": [], "cell": [k % 7, k / 7]})
	AutochessRewards.track(g, 0, flags)
	check("neuf héros d'une famille : « Pur sang »", bool(flags.get("pure_blood", false)))
	var got := AutochessRewards.settle({"diff": 1, "place": 1, "hp": 74, "rerolls": 0, "flags": flags})
	var names: Array = (got.titles as Array).map(func(t): return String(t.title))
	check("victoire à 74 PV sans actualiser : Tacticien, Trois étoiles, Pur sang, Invaincu, Frugal " + str(names),
		names == ["Tacticien", "Trois étoiles", "Pur sang", "Invaincu", "Frugal"])
	got = AutochessRewards.settle({"diff": 0, "place": 1, "hp": 90, "rerolls": 0, "flags": flags})
	names = (got.titles as Array).map(func(t): return String(t.title))
	check("exploits une seule fois (toute difficulté) " + str(names), names == ["Stratège"])
	got = AutochessRewards.settle({"diff": 0, "place": 2, "hp": 90, "rerolls": 0, "flags": {}})
	check("2e place : ni Invaincu ni Frugal", (got.titles as Array).is_empty())
	check("exploits listés pour la page (4 faits)", AutochessRewards.exploits().filter(func(e): return bool(e.done)).size() == 4)
	Profile.records.erase(AutochessRewards.KEY)
	Profile.reward_chests.clear()
	Profile.extra_titles.clear()


# --- quêtes ----------------------------------------------------------------------------------------------------------
func _test_quests() -> void:
	var r := RandomNumberGenerator.new()
	var only_looks := true
	for d in QuestPool.LIST.filter(func(x): return String(x.act) == "autochess"):
		for s in 20:
			r.seed = s
			for period in ["daily", "weekly"]:
				var rw: Dictionary = Quests.make(d, period, s % 2, r).r
				if rw.has("mastery") or rw.has("insignia") or not String(rw.get("chest", "")).begins_with("look_"):
					only_looks = false
	check("quêtes de l'Échiquier : récompense d'apparence seulement (jamais maîtrise ni insignes)", only_looks)
	check("activité connue des quêtes (page de la boussole)", QuestPool.ACTS.has("autochess") and String(QuestPool.ACTS.autochess.go.menu) == "autochess")
	var top4 := QuestPool.get_def("ac_top4")
	var rounds := QuestPool.get_def("ac_rounds")
	var win := QuestPool.get_def("ac_win")
	var q := {"p": 0, "s": [], "param": ""}
	var ctx3 := Quests.run_ctx("autochess", true, AutochessRewards.quest_extra({"place": 3, "rounds_won": 9, "secs": 1500.0}))
	var ctx6 := Quests.run_ctx("autochess", false, AutochessRewards.quest_extra({"place": 6, "rounds_won": 4, "secs": 900.0}))
	var ctx1 := Quests.run_ctx("autochess", true, AutochessRewards.quest_extra({"place": 1, "rounds_won": 20, "secs": 1700.0}))
	check("quête « 4 premiers » : 3e compte, 6e non", Quests.next_progress(top4, q, ctx3) == 1 and Quests.next_progress(top4, q, ctx6) == 0)
	check("quête « manches gagnées » : additionne les manches", Quests.next_progress(rounds, q, ctx3) == 9 and Quests.next_progress(rounds, q, ctx6) == 4)
	check("quête « gagner une partie » : la 1re place seulement", Quests.next_progress(win, q, ctx1) == 1 and Quests.next_progress(win, q, ctx3) == 0)
	check("une partie de l'Échiquier ne compte ni classe ni monstres (rien de Run)", String(ctx3.get("class", "x")) == "" and int(ctx3.kills) == 0
		and float(ctx3.secs) == 1500.0)
	var sv := QuestPool.get_def("sv_kills")
	check("une quête d'une autre activité n'avance pas", Quests.next_progress(sv, q, ctx3) == 0)


# --- partie complète, mode scellé, bilan ----------------------------------------------------------------------------------
## Valeur lisible des propriétés du hub (Survivor.HUB_KEYS), sans ce que l'Échiquier a le droit de donner.
func _hub() -> Dictionary:
	var out := {}
	for k in Survivor.HUB_KEYS:
		out[k] = str(AutochessRewards.hub_view(k, Profile.get(k)))
	return out


func _test_game() -> void:
	# un compte avec de la progression : rien ne doit bouger
	Profile.insignia = 777
	Profile.materials = {"crystal": 42}
	Profile.add_expertise("warrior", 5000)
	Profile.runs_done = 4
	Profile.records["duel_wins"] = 3
	Profile.save_profile()
	Unlocks.refresh()  # le fil d'éveil s'écrit à la 1re lecture (Quests.enabled) : déjà ouvert par ce compte, il ne compte pas
	var hub_before := _hub()
	var equip_before := str(Profile.equipped)
	var class_before := Profile.selected_class
	Autochess.clear_save(SAVE)
	AutochessScreen.config = {"seed": 11, "save_path": SAVE, "fast": true, "autoplay": true, "diff": 0}
	var t0 := Time.get_ticks_msec()
	var screen: AutochessScreen = load("res://scenes/autochess.tscn").instantiate()
	add_child(screen)
	await _frames(3)
	check("partie lancée : mode scellé (Modes.current = %s)" % Modes.current(), Modes.current() == "autochess" and Modes.sealed())
	check("stratèges IA de la difficulté (AutochessAi, Recrue)", screen.game.strategists[1] is AutochessAi and screen.diff == 0
		and int(screen.game.players[0].meta.aci.diff) == 0)
	check("partie gardée dès la 1re préparation", Autochess.has_save(SAVE))
	var guard := 0
	while screen.phase != "over" and guard < 60000:
		guard += 1
		await get_tree().process_frame
	var p: Dictionary = screen.game.players[0]
	var place := int(p.place)
	check("partie complète au pilote (%s, place %d, %.0f s)" % [screen.game.round_key(), place, (Time.get_ticks_msec() - t0) / 1000.0],
		screen.phase == "over" and place >= 1)
	await _frames(3)
	check("bilan commun ouvert : Rejouer, Statistiques, Menu principal", screen.results != null and is_instance_valid(screen.results)
		and screen.results.buttons.map(func(b): return b.text) == ["Rejouer", "Statistiques", "Menu principal"])
	check("bilan : cinq tuiles (place, manches, dégâts, meilleure unité, durée)", screen.results != null and _tiles(screen.results) == 5)
	var plan_n := (AutochessRewards.last.get("chests", []) as Array).size()
	check("récompenses de la place %d : %d coffre(s), %d titre(s)" % [place, plan_n, (AutochessRewards.last.get("titles", []) as Array).size()],
		plan_n == AutochessRewards.reached(place).size() and Profile.reward_chests.size() == plan_n)
	check("records de l'Échiquier : une partie", AutochessRewards.count("games") == 1)
	var hub_after := _hub()
	var moved: Array = []
	for k in hub_before:
		if hub_before[k] != hub_after[k]:
			moved.append(k)
	check("hub intact après la partie (progression, équipement, classe) " + str(moved), moved.is_empty()
		and str(Profile.equipped) == equip_before and Profile.selected_class == class_before and Profile.insignia == 777)
	check("sauvegarde de la partie effacée à la fin", not Autochess.has_save(SAVE))
	check("bilan : le jeu est en pause derrière", get_tree().paused)
	# Statistiques : le bilan détaillé, puis le bilan revient
	await get_tree().create_timer(ResultsPanel.LOCK_SECS + 0.2).timeout
	screen.results.buttons[1].pressed.emit()
	await _frames(2)
	check("Statistiques : bilan détaillé ouvert, bilan commun caché", screen.recap.visible and screen.recap.mode == "game"
		and not screen.results.visible and not get_tree().paused)
	screen.recap.close()
	await _frames(2)
	check("Statistiques fermées : le bilan commun revient", screen.results.visible and get_tree().paused)
	# Rejouer : nouvelle partie de la même difficulté, nouvel instantané du hub
	screen.autoplay = false
	screen.results.buttons[0].pressed.emit()
	await _frames(3)
	check("Rejouer : nouvelle partie à 1-1, même difficulté, jeu repris", screen.game.round_key() == "1-1" and screen.phase == "prep"
		and screen.diff == 0 and not get_tree().paused and screen.results == null and AutochessRewards.has_snapshot())
	screen.queue_free()
	await _frames(2)
	get_tree().paused = false
	AutochessRewards.restore_hub()


func _tiles(panel: ResultsPanel) -> int:
	var n := 0
	for c in panel.find_children("*", "HBoxContainer", true, false):
		var k := 0
		for x in (c as HBoxContainer).get_children():
			if x is PanelContainer and (x as Control).custom_minimum_size.x >= 118.0:
				k += 1
		n = maxi(n, k)
	return n


# --- reprise ---------------------------------------------------------------------------------------------------------------
func _test_resume() -> void:
	Autochess.clear_save(SAVE)
	AutochessScreen.config = {"seed": 21, "save_path": SAVE, "fast": true, "autoplay": true, "diff": 2}
	var screen: AutochessScreen = load("res://scenes/autochess.tscn").instantiate()
	add_child(screen)
	var guard := 0
	while not (screen.game.stage == 2 and screen.game.round_i == 2 and screen.phase == "prep") and guard < 20000:
		guard += 1
		await get_tree().process_frame
	var key := screen.game.round_key()
	var saved: Variant = JSON.parse_string(SafeFile.read(SAVE))
	var shop := str(saved.players[0].shop) if saved is Dictionary else "?"
	var foe_diff := int((screen.game.strategists[3] as AutochessAi).difficulty) if screen.game.strategists[3] is AutochessAi else -1
	screen.queue_free()
	await _frames(2)
	AutochessRewards.restore_hub()
	check("partie quittée en 2-2 : gardée", Autochess.has_save(SAVE) and key == "2-2")
	AutochessScreen.config = {"save_path": SAVE, "fast": true, "resume": true, "diff": 0}
	screen = load("res://scenes/autochess.tscn").instantiate()
	add_child(screen)
	await _frames(3)
	var foe_diff2 := int((screen.game.strategists[3] as AutochessAi).difficulty) if screen.game.strategists[3] is AutochessAi else -2
	check("reprise : même manche, même boutique, difficulté Champion retrouvée, mêmes stratèges IA",
		screen.game.round_key() == key and str(screen.game.players[0].shop) == shop and screen.diff == 2 and foe_diff == foe_diff2
		and screen.game.strategists[0] == null)
	screen.queue_free()
	await _frames(2)
	AutochessRewards.restore_hub()
