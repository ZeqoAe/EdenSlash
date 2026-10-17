extends Node
## Lot SND-2 : les sons de la bibliothèque SND-1 branchés aux bons endroits. Chaque cas est vérifié par le compteur de
## lectures de Sfx (Sfx.played : nom -> nombre de lectures acceptées) : sons de bilan (victoire, défaite douce, record, étoile,
## butin par rareté, niveau de héros), coffre ouvert par rareté, forge réussie / ratée / refusée, compte à rebours et
## « C'est parti » du duel, coup reçu léger du HUD (seuils et anti-spam), or d'une vente, câblage de l'Échiquier.
## godot --headless --path game res://tests/test_snd2.tscn  (profil de test uniquement)

var fails := 0


func check(label: String, ok: bool) -> void:
	print(("OK    " if ok else "ÉCHEC ") + label)
	if not ok:
		fails += 1


func n(name: String) -> int:
	return int(Sfx.played.get(name, 0))


## Pièce de rareté [param r] (tirée puis forcée : le test ne dépend pas du hasard).
func _item(r: int) -> Dictionary:
	var it := Items.generate(30, 1.0, "chest", "warrior", 0, "", 3)
	it["rarity"] = r
	return it


## Attend [param s] secondes réelles, même en pause (par les images : un minuteur créé juste après une image lente, comme
## l'ouverture d'un bilan, peut se déclencher trop tôt).
func _wait(s: float) -> void:
	var t0 := Time.get_ticks_msec()
	await get_tree().process_frame
	while float(Time.get_ticks_msec() - t0) < s * 1000.0:
		await get_tree().process_frame


func _reward_total() -> int:
	var t := 0
	for i in range(1, 6):
		t += n("ui_reward_%d" % i)
	return t


func _ready() -> void:
	get_tree().create_timer(120.0, true, false, true).timeout.connect(func(): get_tree().quit(1))
	Settings.reset_all(false)
	Settings.apply_all()
	UiFeel.read_settings()
	Vfx.silent = false
	Profile.reset_all()
	_moments_plan()
	await _results()
	await _chest()
	await _forge()
	await _duel_countdown()
	await _gold()
	_autochess_wiring()
	await _hud()
	print("\nRÉSULTAT : %s (%d échec(s))" % ["VERT" if fails == 0 else "ROUGE", fails])
	get_tree().quit(1 if fails > 0 else 0)


# --- plan des sons d'un bilan (pur) -------------------------------------------------------------------
func _names(spec: Dictionary) -> Array:
	return ResultsPanel.moments(spec).map(func(m): return m[1])


func _moments_plan() -> void:
	check("victoire : ui_victory seul", _names({"tone": "win"}) == ["ui_victory"])
	check("défaite : ui_defeat seul (douce)", _names({"tone": "lose"}) == ["ui_defeat"])
	check("bilan neutre : silence", _names({"tone": "info"}).is_empty())
	var rec := {"tone": "win", "tiles": [["1:58", "temps · Record !", "", true]]}
	check("record dans une tuile : ui_victory puis ui_record", _names(rec) == ["ui_victory", "ui_record"])
	check("record dans une note", _names({"tone": "win", "notes": ["Record ! Latif en 1:58 (ancien 2:20)"]}) == ["ui_victory", "ui_record"])
	check("étoile « nouvelle »", _names({"tone": "win", "stars": [{"label": "x", "done": true, "new": true}]}) == ["ui_victory", "ui_star"])
	check("étoile non nouvelle : rien", _names({"tone": "win", "stars": [{"label": "x", "done": true}]}) == ["ui_victory"])
	check("ligne « Étoile d'époque »", _names({"tone": "win", "gained": [ResultsPanel.row("Étoile d'époque", "+1")]}) == ["ui_victory", "ui_star"])
	for r in range(6):
		var want := "ui_reward_%d" % [1, 1, 2, 3, 4, 5][r]
		check("butin de rareté %d -> %s" % [r, want], _names({"tone": "info", "loot": [{"rarity": 0}, {"rarity": r}]}) == [want])
	check("niveau de héros gagné", _names({"tone": "win", "notes": ["Ton héros passe au niveau 35."]}) == ["ui_victory", "ui_level_up"])
	var all := {"tone": "win", "tiles": [["1", "temps · Record !"]], "stars": [{"new": true}], "loot": [{"rarity": 3}], "notes": ["Ton héros passe au niveau 9."]}
	var plan := ResultsPanel.moments(all)
	check("au plus %d accents, record puis étoile puis butin" % ResultsPanel.MOMENT_MAX,
		plan.size() == 1 + ResultsPanel.MOMENT_MAX and plan[1][1] == "ui_record" and plan[2][1] == "ui_star" and plan[3][1] == "ui_reward_3")
	var t_ok := true
	for i in range(1, plan.size()):
		t_ok = t_ok and absf(float(plan[i][0]) - (ResultsPanel.MOMENT_FROM + ResultsPanel.MOMENT_GAP * (i - 1))) < 0.001
	check("accents espacés d'une seconde, après la victoire", t_ok and float(plan[0][0]) == 0.0)


# --- bilan réel : les sons sortent, dans l'ordre, et pas après sa fermeture ---------------------------------
func _results() -> void:
	var v0 := n("ui_victory")
	var d0 := n("ui_defeat")
	var rp := ResultsPanel.new()
	add_child(rp)
	rp.show_spec({"title": "VICTOIRE", "tone": "win", "tiles": [["1:58", "temps · Record !", "", true]], "loot": [ResultsPanel.loot_entry(_item(4))],
		"buttons": [{"text": "Rejouer", "primary": true, "call": func(): pass}]})
	check("bilan de victoire : ui_victory joué tout de suite", n("ui_victory") == v0 + 1)
	var rec0 := n("ui_record")
	var rew0 := _reward_total()
	await _wait(ResultsPanel.MOMENT_FROM + 0.25)
	check("record : ui_record joué après la victoire", n("ui_record") == rec0 + 1)
	await _wait(ResultsPanel.MOMENT_GAP + 0.2)
	check("butin : un son de récompense joué ensuite (mythique)", _reward_total() == rew0 + 1 and n("ui_reward_4") >= 1)
	rp.queue_free()
	get_tree().paused = false
	await get_tree().process_frame
	# défaite douce, et fermeture avant l'accent : il ne sort pas
	var rp2 := ResultsPanel.new()
	add_child(rp2)
	rp2.show_spec({"title": "DÉFAITE", "tone": "lose", "notes": ["Ton héros passe au niveau 3."], "buttons": [{"text": "Rejouer", "primary": true, "call": func(): pass}]})
	check("bilan de défaite : ui_defeat (et pas ui_victory)", n("ui_defeat") == d0 + 1 and n("ui_victory") == v0 + 1)
	var l0 := n("ui_level_up")
	rp2.queue_free()
	get_tree().paused = false
	await _wait(ResultsPanel.MOMENT_FROM + 0.3)
	check("bilan fermé avant l'accent : rien n'est joué après coup", n("ui_level_up") == l0)
	# intensité des effets à 0 : tout se tait
	var saved := UiFeel.intensity
	UiFeel.intensity = 0.0
	var v1 := n("ui_victory")
	var rp3 := ResultsPanel.new()
	add_child(rp3)
	rp3.show_spec({"title": "VICTOIRE", "tone": "win", "buttons": [{"text": "Rejouer", "primary": true, "call": func(): pass}]})
	check("intensité des effets à 0 : bilan silencieux", n("ui_victory") == v1)
	UiFeel.intensity = saved
	rp3.queue_free()
	get_tree().paused = false
	await get_tree().process_frame


# --- coffre ouvert : son de la plus haute rareté --------------------------------------------------------------
func _chest() -> void:
	var page := ChestsPage.new()
	add_child(page)
	page.size = Vector2(1400, 800)
	var low := _item(0)
	var high := _item(5)
	var r5 := n("ui_reward_5")
	var r1 := n("ui_reward_1")
	page._show_loot({"items": [low], "supplies": {}})
	await _wait(0.5)
	check("coffre : une pièce commune -> ui_reward_1", n("ui_reward_1") == r1 + 1 and n("ui_reward_5") == r5)
	page._show_loot({"items": [low, high], "supplies": {}})
	await _wait(0.5)
	check("coffre : la plus haute rareté (légendaire) -> ui_reward_5, un seul son", n("ui_reward_5") == r5 + 1 and n("ui_reward_1") == r1 + 1)
	var all0 := _reward_total()
	page._show_loot({"items": [], "supplies": {"fortify:guard:30": 1}})
	await _wait(0.5)
	check("coffre : fournitures seules, pas de son de rareté", _reward_total() == all0)
	page.queue_free()


# --- forge ---------------------------------------------------------------------------------------------------------
func _forge() -> void:
	Profile.in_run = false
	ForgeBench.fast = true
	var fb := ForgeBench.new()
	add_child(fb)
	await get_tree().process_frame
	var ok0 := n("ui_forge_ok")
	var ko0 := n("ui_forge_fail")
	var dn0 := n("ui_deny")
	fb.done("Fortifié : +3")
	check("forge réussie -> ui_forge_ok", n("ui_forge_ok") == ok0 + 1 and n("ui_forge_fail") == ko0)
	await _wait(0.06)
	fb.done("Raté : la pièce reste à +2.")
	check("forge ratée -> ui_forge_fail", n("ui_forge_fail") == ko0 + 1 and n("ui_forge_ok") == ok0 + 1)
	await _wait(0.06)
	fb.done("Pas assez de cristaux.")
	check("demande refusée -> ui_deny (ni réussite ni échec de forge)", n("ui_deny") == dn0 + 1 and n("ui_forge_fail") == ko0 + 1)
	ForgeBench.fast = false
	fb.queue_free()


# --- compte à rebours du duel ---------------------------------------------------------------------------------
func _duel_countdown() -> void:
	var dd := DuelDirector.new()
	dd.d = RunDirector.new()
	add_child(dd)
	dd.phase = "countdown"
	var t0 := n("ui_tick")
	var g0 := n("ui_go")
	var step := 0
	for k in [[3.05, 0.1], [2.05, 0.1], [1.05, 0.1]]:
		dd._t = float(k[0])
		dd.update(float(k[1]))
		step += 1
		check("duel : chiffre %d -> ui_tick" % (4 - step), n("ui_tick") == t0 + step)
		await _wait(0.06)
	check("duel : pas de « C'est parti » avant la fin", n("ui_go") == g0)
	dd._t = 0.05
	dd.update(0.1)
	check("duel : COMBAT ! -> ui_go", n("ui_go") == g0 + 1 and dd.phase == "fight")
	dd.queue_free()


# --- or d'une vente --------------------------------------------------------------------------------------------------
func _gold() -> void:
	var c0 := n("ui_coin")
	UiFeel.cue("ui_coin", -10.0)
	check("or : ui_coin existe et se joue", n("ui_coin") == c0 + 1)
	var src := FileAccess.get_file_as_string("res://scripts/ui/merchant_pages.gd")
	check("vente : ui_coin appelé quand la vente rapporte de l'or", src.contains("Profile.sell_many(items)") and src.contains("UiFeel.cue(\"ui_coin\""))
	await get_tree().process_frame


# --- Échiquier : noms de sons des moments ------------------------------------------------------------------------
func _autochess_wiring() -> void:
	var src := FileAccess.get_file_as_string("res://scripts/ui/autochess_screen.gd")
	check("Échiquier : gardien -> ui_banner", src.contains("\"ui_banner\" if guard else \"confirm\""))
	check("Échiquier : trois étoiles et ★★ -> ui_star", src.contains("unit_name(String(u.id)), \"ui_star\"") and src.contains("\"★★ !\", \"soleil\", \"ui_star\""))
	check("Échiquier : niveau du joueur -> ui_level_up", src.contains("\"ui_level_up\", -10.0"))
	var rs := FileAccess.get_file_as_string("res://scripts/ui/royale_results.gd")
	check("Battle royale : plus de « confirm » en double avec ui_victory", not rs.contains("Sfx.ui(\"confirm\", -8.0)"))


# --- HUD : coup reçu léger ----------------------------------------------------------------------------------------------
func _hud() -> void:
	var world: Node = load("res://scenes/world.tscn").instantiate()
	get_tree().root.add_child.call_deferred(world)
	await _wait(6.0)
	var player: Player = world.player
	for m in get_tree().get_nodes_in_group("monsters"):
		m.queue_free()
	world.director.set_process(false)
	var hud: Hud = world.hud
	var mx := player.max_hp
	var h0 := n("ui_hit")
	player.damaged.emit(mx * 0.005, player)
	check("coup minuscule (0,5 % des PV) : silence", n("ui_hit") == h0)
	player.damaged.emit(mx * 0.5, player)
	check("coup très lourd (50 %) : pas le son léger", n("ui_hit") == h0)
	player.damaged.emit(mx * 0.05, null)
	check("dégâts sans source : silence", n("ui_hit") == h0)
	player.damaged.emit(mx * 0.05, player)
	check("coup léger (5 %) -> ui_hit", n("ui_hit") == h0 + 1)
	await _wait(0.1)
	player.damaged.emit(mx * 0.05, player)
	check("anti-spam : un second coup 0,1 s plus tard est muet", n("ui_hit") == h0 + 1)
	await _wait(Hud.HIT_GAP_MS / 1000.0 + 0.1)
	player.damaged.emit(mx * 0.05, player)
	check("après 0,45 s : rejoué", n("ui_hit") == h0 + 2)
	var r0 := _reward_total()
	hud.show_better(_item(3))
	check("meilleure pièce trouvée -> son de rareté", _reward_total() == r0 + 1)
	await _wait(0.1)
	hud.show_better(_item(3))
	check("deux pièces à la suite : un seul son", _reward_total() == r0 + 1)
	world.queue_free()
