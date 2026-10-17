extends Node
## Lot SVX-3 du Survivant (BM-SURV : SV-P1 règles, SV-M1, SV-M2, SV-M3, SV-E1, SV-F1, SV-Q5) : recettes d'évolution (arme,
## sort, paires de passifs) et leur lecture (indice de carte, « il manque… », coffre du gardien), évolution de sort qui
## renforce le sort, Codex et statistiques, records (« Nouveau record ! »), défis et titres du mode, coffres du bilan qui
## s'ouvrent au bouton, élites à modificateur et événements de partie, fondu d'arrivée sous le choix de carte ; rien du compte.
## godot --headless --path game res://tests/test_svx3.tscn

var fails := 0


func check(label: String, ok: bool) -> void:
	print(("OK    " if ok else "ÉCHEC ") + label)
	if not ok:
		fails += 1


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Settings.reset_all()
	Profile.selected_class = "warrior"
	Profile.reset_all()
	Profile.in_run = false
	SurvivorCards.seed_with(5)
	_recipes()
	_weapon_evo()
	_spell_evo()
	_passive_evo()
	_settle()
	await _bilan()
	_affixes()
	var cp := CardPicker.new()
	add_child(cp)
	check("fondu d'arrivée sous le choix de carte, au-dessus du HUD et de la pause (calque %d < %d)" % [ScreenFade.REVEAL_LAYER, cp.layer], ScreenFade.REVEAL_LAYER < cp.layer and ScreenFade.REVEAL_LAYER > 16)
	cp.queue_free()
	print("\n%s (%d échec(s))" % ["TOUT EST OK" if fails == 0 else "ÉCHECS", fails])
	Profile.reset_all()
	get_tree().quit(1 if fails > 0 else 0)


func _recipes() -> void:
	var all := SurvivorEvo.all()
	check("20 recettes (4 de Boons + 16 neuves)", all.size() == 20 and SurvivorEvo.NEW.size() == 16)
	var kinds := {}
	for d in all:
		kinds[String(d.kind)] = int(kinds.get(String(d.kind), 0)) + 1
	check("7 d'arme, 5 de sort, 8 de passifs (%s)" % [kinds], kinds.get("weapon", 0) == 7 and kinds.get("spell", 0) == 5 and kinds.get("passives", 0) == 8)
	var types := {}
	for d in all.filter(func(x): return String(x.kind) == "weapon"):
		for t in d.wtypes:
			types[t] = true
	check("chaque type d'arme a sa recette (%d / %d)" % [types.size(), SurvivorPool.weapon_types().size()], SurvivorPool.weapon_types().all(func(t): return types.has(t)))
	var ok := true
	for d in all:
		var b := Boons.get_def(String(d.id))
		ok = ok and not b.is_empty() and String(b.get("desc", "")) != "" and (d.requires as Array).all(func(r): return String(r) in Cards.passive_effects())
	check("chaque évolution se lit par Boons.get_def, ingrédients = passifs des pièces", ok)
	check("les évolutions neuves ne sont jamais des cartes de la Survie", not Boons.all().any(func(b): return String(b.id).begins_with("sve_")))


func _start() -> void:
	Survivor.start("warrior", "limestone")
	Run.hero_level = 20


func _weapon_evo() -> void:
	_start()
	var w := SurvivorGear.make_weapon("axe")
	SurvivorGear.equip(w)
	Profile.equipped.weapon["upgrade"] = 4
	SurvivorGear._grant("shockwave", 1.0)
	check("Séisme : pas prête avec une hache +4", not "sve_quake" in SurvivorEvo.open())
	var up := SurvivorCards.up_card("weapon", "common")
	check("carte d'arme +4 → +6 : « ◆ Évolution prête : Séisme » (%s)" % SurvivorEvo.hint(up), SurvivorEvo.hint(up) == "◆ Évolution prête : Séisme")
	var paths := SurvivorEvo.paths().filter(func(p): return String(p.id) == "sve_quake")
	check("pause : « Séisme : il manque arme à +6 »", paths.size() == 1 and String(paths[0].missing[0]).contains("+6"))
	Profile.equipped.weapon["upgrade"] = 6
	check("hache +6 et Onde de choc : Séisme prête", "sve_quake" in SurvivorEvo.open() and "sve_quake" in SurvivorCards.evolutions_open())
	var cards := SurvivorCards.chest_cards("sv_guardian")
	check("coffre du gardien : l'évolution prête en tête", not cards.is_empty() and String(cards[0].type) == "sv_evolution")
	var c := SurvivorCards.evolution_card("sve_quake")
	check("carte : « Grâce à : Hache à +6, Onde de choc »", String(c.desc).contains("Hache à +6") and String(c.desc).contains("Onde de choc"))
	Run.apply_card(c)
	check("prise : passif de la partie, procs actifs, plus proposée", Run.passives.has("sve_quake") and Run.passive_procs().any(func(p): return String(p.id).begins_with("sve_quake"))
		and not "sve_quake" in SurvivorEvo.open() and "sve_quake" in SurvivorEvo.taken())
	check("Codex de la partie : Séisme vue", "sve_quake" in SurvivorCodex.run.evo)
	Run.finish("abandon")
	Profile.end_run_survival()


func _spell_evo() -> void:
	_start()
	var sid := int(Run.class_data().skills[0].id)
	Run.apply_card(SurvivorCards.spell_card(sid))
	SurvivorGear._grant("arcana", 1.0)
	Run.skill_entry(sid)["rank"] = 9
	var up := SurvivorCards.spell_up_card(sid, "legendary")
	check("amélioration niveau 9 → 10 : « ◆ Évolution prête : Surcharge » (%s)" % SurvivorEvo.hint(up), SurvivorEvo.hint(up) == "◆ Évolution prête : Surcharge")
	Run.skill_entry(sid)["rank"] = 10
	check("sort niveau 10 et Arcanes : Surcharge prête", "sve_s_overload" in SurvivorEvo.open())
	var before := Run.skill_damage_mult(sid)
	var c := SurvivorCards.evolution_card("sve_s_overload")
	check("carte : nomme le sort", int(c.get("skill_id", -1)) == sid and String(c.subtitle).contains(String(Run.skill_def(sid).name)))
	Run.apply_card(c)
	var after := Run.skill_damage_mult(sid)
	check("Surcharge : dégâts du sort ×%.2f → ×%.2f (+0,9)" % [before, after], absf(after - before - 0.9) < 0.01 and String(Run.skill_entry(sid).evo) == "sve_s_overload")
	SurvivorGear._grant("echo", 1.0)
	check("un sort déjà évolué n'en reçoit pas d'autre", not "sve_s_echo" in SurvivorEvo.open())
	Run.finish("abandon")
	Profile.end_run_survival()


func _passive_evo() -> void:
	_start()
	SurvivorGear._grant("hunter_eye", 1.0)
	var piece := SurvivorCards.new_piece_card("ring")
	piece.item["sv_passives"] = [{"id": "precision", "at": 0, "power": 1.0}]
	check("pièce qui apporte Précision : « ◆ Évolution prête : Œil de faucon »", SurvivorEvo.hint(piece) == "◆ Évolution prête : Œil de faucon")
	Run.banned.append("evo:sve_hawk")
	SurvivorGear._grant("precision", 1.0)
	check("évolution bannie : jamais proposée", not "sve_hawk" in SurvivorEvo.open())
	Run.finish("abandon")
	Profile.end_run_survival()


func _end(res: String, time: float, kills: int, level: int) -> Dictionary:
	_start()
	Run.kills = kills
	Run.max_level = level
	SurvivorLog.begin()
	SurvivorLog.tag = "weapon"
	SurvivorLog.note(1000.0 * level)
	SurvivorLog.tag = ""
	SurvivorCodex.note_weapon(SurvivorGear.make_weapon("bow"))
	SurvivorRewards.stats = {"time": time, "guardians": 3 if time >= 900.0 else 1, "arena": res == "victoire", "early": 0.0,
		"arena_at": 1200.0 if res == "victoire" else -1.0, "ttk": [40.0, 45.0, 50.0]}
	RunJournal._time = 30.0
	Run.finish(res)
	var out := SurvivorRewards.last.duplicate(true)
	Profile.end_run_survival()
	return out


func _settle() -> void:
	Profile.reset_all()
	var titles := Profile.extra_titles.duplicate()
	var a := _end("defaite", 700.0, 900, 20)
	check("1re partie : aucun « Nouveau record » (scores posés)", (a.records.records as Array).is_empty() and SurvivorRecords.best("warrior", 1).has("time"))
	check("Codex : l'arc porté entre au Codex", SurvivorCodex.state().weapons.any(func(k): return String(k).begins_with("bow:")))
	var b := _end("defaite", 800.0, 1200, 25)
	var keys: Array = (b.records.records as Array).map(func(e): return String(e.key))
	check("2e partie meilleure : records de survie, niveau, dégâts, monstres (%s)" % [keys], "time" in keys and "level" in keys and "dmg" in keys and "kills" in keys)
	var c := _end("victoire", 1300.0, 3100, 44)
	check("victoire : première victoire de la classe, classes gagnées 1", bool(c.records.first_win) and SurvivorRecords.classes_won() == ["warrior"])
	var done := SurvivorRecords.defis_done()
	check("défis : Gagne, 10 minutes, gardiens, 3 000 monstres, gardiens en moins d'une minute (%s)" % [done],
		["first_win", "ten_min", "guardians", "kills_3000", "quick_guard"].all(func(id): return id in done))
	check("titres des défis : donnés et comptés comme titres du mode", "Faucheur de hordes" in Profile.extra_titles and "Briseur de gardiens" in Profile.extra_titles
		and (SurvivorRewards.hub_view("extra_titles", Profile.extra_titles) as Array) == titles)
	var d := _end("victoire", 1250.0, 2000, 40)
	check("victoire plus rapide : « Victoire la plus rapide » (%s)" % [d.records.records.map(func(e): return e.key)], (d.records.records as Array).any(func(e): return String(e.key) == "win"))
	var s := SurvivorCodex.stats()
	check("statistiques : 4 parties, 2 victoires, monstres cumulés", int(s.games) == 4 and int(s.wins) == 2 and int(s.kills) == 900 + 1200 + 3100 + 2000)
	check("tout reste dans « sv_rewards » (hors progression du compte)", Profile.records.has(SurvivorRewards.KEY) and Profile.records[SurvivorRewards.KEY].has("codex")
		and Profile.records[SurvivorRewards.KEY].has("best") and not Profile.records.has("codex"))
	check("coffres de la partie : référence gardée pour le bilan", (d.chests as Array).all(func(g): return g.has("ref")))


func _bilan() -> void:
	Profile.reset_all()
	_start()
	Run.kills = 1500
	Run.max_level = 30
	SurvivorRewards.stats = {"time": 1300.0, "guardians": 3, "arena": true, "early": 0.0, "arena_at": 1200.0, "ttk": [40.0, 45.0, 50.0]}
	RunJournal._time = 30.0
	Run.finish("victoire")
	var n := Profile.reward_chests.size()
	var rs := ResultsScreen.new()
	add_child(rs)
	rs.show_results()
	await get_tree().create_timer(2.0, true, false, true).timeout
	var btn := rs.find_child("OpenChests", true, false) as Button
	check("bilan : « Tes coffres » et « Ouvrir mes coffres »", btn != null and _texts(rs).contains("TES COFFRES"))
	check("bilan : rien n'est ouvert sans le bouton (%d coffres)" % n, Profile.reward_chests.size() == n and n >= 3)
	if btn != null:
		btn.pressed.emit()
		await get_tree().create_timer(3.0, true, false, true).timeout
	check("« Ouvrir mes coffres » : ouverts un à un (%d restent)" % Profile.reward_chests.size(), Profile.reward_chests.size() == n - 3)
	check("bilan : « Première victoire ! » ou « Nouveau record ! »", _texts(rs).contains("PREMIÈRE VICTOIRE") or _texts(rs).contains("NOUVEAU RECORD"))
	rs.queue_free()
	get_tree().paused = false
	Profile.end_run_survival()


func _texts(n: Node) -> String:
	var out: PackedStringArray = []
	for c in n.find_children("*", "Label", true, false):
		if (c as Label).is_visible_in_tree():
			out.append((c as Label).text)
	return "\n".join(out)


func _affixes() -> void:
	var ev := SurvivorEvents.new(null)
	var m := Monster.new()
	m.configure(GameData.monster(int(GameData.zone("limestone").elites[0])), false, 10)
	add_child(m)
	var hp := m.max_hp
	ev.apply_affix(m, "blinde")
	check("élite blindée : PV ×1,5, nom préfixé, étiquette au-dessus", absf(m.max_hp - hp * SurvivorEvents.ARMOR_HP) < 1.0 and m.display_name.begins_with("Blindé · ")
		and m.get_node_or_null("SvAffix") is Label3D)
	var g := Monster.new()
	g.configure(GameData.monster(int(GameData.zone("limestone").elites[0])), false, 10)
	add_child(g)
	g.set_meta("sv_guardian", 0)
	var ghp := g.max_hp
	ev.apply_affix(g, "blinde")
	check("gardien : jamais de PV en plus (PV fixes mesurés)", absf(g.max_hp - ghp) < 0.01)
	check("événements : Nuée à 7:30, Chasseur à 12:30", SurvivorEvents.timeline().map(func(e): return [e.id, int(e.t)]) == [["nuee", 450], ["chasseur", 750]])
	check("gardiens : trois modificateurs sans doublon, jamais « blindé »", ev._guard_pool.size() == 3 and not "blinde" in ev._guard_pool)
	m.queue_free()
	g.queue_free()
