extends Node
## Passe P13 (conception/nuit_15_10/R_P13.md), trois notes du joueur du 15/10 :
## (A) choix de carte ouvert pendant l'entrée dans l'arène du boss : le jeu reste en pause (PV, temps, fureur figés)
##     et la manette choisit (cadre sur la 1re carte, croix, A) ;
## (B) teinture d'un accessoire rigide (Pièce de l'Œil de rose écarlate) : les couleurs choisies s'appliquent ;
## (C) aide au combat « Bot » et pilote automatique : l'équipement est choisi seul, aucun écran ne reste ouvert.
## godot --headless --path game res://tests/test_p13.tscn

const ROSE := "res://assets/player/outfits/head_l1288.glb"
const RED := [[220, 30, 40], [150, 10, 20], [255, 90, 90]]
const AUTOPLAY_SECS := 180.0  # temps de jeu du pilote automatique
const AUTOPLAY_SCALE := 3.0

var fails := 0
var world: Node


func check(label: String, ok: bool) -> void:
	print(("OK    " if ok else "ÉCHEC ") + label)
	if not ok:
		fails += 1


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # le test continue pendant la pause qu'il vérifie
	get_tree().root.size = Vector2i(1600, 900)  # sans fenêtre, l'écran fait 64 px : le clic de A tomberait dehors
	_test_dye()
	var quick := OS.get_environment("P13_QUICK") != ""  # mise au point : sans l'inventaire des teintures ni la run de 3 min
	if not quick:
		_test_dye_audit()
	var assist_was := Settings.assist_level()
	Settings.set_assist("assisted")
	Profile.selected_zone = String(GameData.zones[0].id)
	# en jeu aussi : le héros porte l'Œil de rose teint en rouge (même construction que l'aperçu du lobby)
	var cls := Profile.selected_class
	var worn_was := String(Profile.worn.get(cls, {}).get("head", ""))
	var dye_was := Profile.dye_of(cls, "head")
	Profile.set_worn(cls, "head", ROSE)
	Profile.set_dye(cls, "head", RED)
	world = load("res://scenes/world.tscn").instantiate()
	get_tree().root.add_child.call_deferred(world)
	await get_tree().create_timer(6.0).timeout
	check("en jeu : l'Œil de rose du héros est teint (%d surface)" % _dyed(world.player, ROSE), _dyed(world.player, ROSE) > 0)
	Profile.set_worn(cls, "head", worn_was)
	Profile.set_dye(cls, "head", dye_was)
	_close_cards()
	_test_auto_pick()
	_test_bot_offers()
	if not quick:
		await _test_autoplay_run()
	await _test_boss_choice()
	if assist_was in Settings.ASSIST:
		Settings.set_assist(assist_was)
	print("TOUS LES TESTS PASSENT" if fails == 0 else "%d ÉCHEC(S)" % fails)
	get_tree().quit(1 if fails > 0 else 0)


# --- (B) teinture ---------------------------------------------------------------------------------
## Surfaces recolorées de la pièce [param path] portée par [param model].
func _dyed(model: Node3D, path: String) -> int:
	var n := 0
	for mi: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		if String(mi.get_meta("part", "")) != path:
			continue
		for s in mi.mesh.get_surface_count():
			var ov := mi.get_surface_override_material(s)
			var src := mi.mesh.surface_get_material(s) as BaseMaterial3D
			if ov is ShaderMaterial:
				for k in ["use_dye", "use_tint"]:
					var u: Variant = ov.get_shader_parameter(k)
					if u != null and float(u) > 0.5:
						n += 1
						break
			elif ov is BaseMaterial3D and src != null and (ov as BaseMaterial3D).albedo_texture != src.albedo_texture:
				n += 1  # lueur ou voile transparent : texture en gris teintée
	return n


func _test_dye() -> void:
	var cls := GameData.class_data("hunter")
	check("Œil de rose : pièce teintable (%s.dye.json)" % ROSE.get_file(), EdenModel.can_dye(ROSE))
	var model := EdenModel.instantiate_hero(cls, "", [ROSE], {ROSE: RED})
	var n := _dyed(model, ROSE)
	var col := Vector3.ZERO
	for mi: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		if String(mi.get_meta("part", "")) == ROSE and mi.get_surface_override_material(0) is ShaderMaterial:
			col = mi.get_surface_override_material(0).get_shader_parameter("dye0")
	check("Œil de rose en rouge : %d surface(s) recolorée(s), couleur %s" % [n, col], n > 0 and col.is_equal_approx(Vector3(220, 30, 40) / 255.0))
	var plain := EdenModel.instantiate_hero(cls, "", [ROSE])
	check("sans couleurs choisies : couleurs d'origine (%d surface recolorée)" % _dyed(plain, ROSE), _dyed(plain, ROSE) == 0)
	model.free()
	plain.free()


## Toutes les pièces teintables (tête, dos, tenue) : chacune a au moins une surface recolorée.
func _test_dye_audit() -> void:
	var cls := GameData.class_data("hunter")
	var t0 := Time.get_ticks_msec()
	var total := 0
	var multi := 0
	var inert: Array = []
	for c in GameData.cosmetics:
		var path := String(c.get("outfit", ""))
		if path == "" or not EdenModel.can_dye(path) or not ResourceLoader.exists(path):
			continue
		total += 1
		if EdenModel.dye_info(path).size() >= 2:
			multi += 1
		var body := path if String(c.get("cat", "")) == "body" else ""
		var model := EdenModel.instantiate_hero(cls, body, [] if body != "" else [path], {path: RED})
		if _dyed(model, path) == 0:
			inert.append(path.get_file())
		model.free()
	print("[teinture] %d pièces teintables (%d à plusieurs matériaux), %d ms" % [total, multi, Time.get_ticks_msec() - t0])
	check("toutes les pièces teintables changent de couleur (%d sans effet : %s)" % [inert.size(), inert.slice(0, 8)], inert.is_empty() and total > 100)


# --- (C) choix automatique -------------------------------------------------------------------------
func _gear(rarity: int, slot: String, level := 20) -> Dictionary:
	var it := Items.generate(level, 0.0, slot, Run.class_id, rarity, "", rarity)
	return RunDirector.item_card(it, "gear")


func _test_auto_pick() -> void:
	var low := _gear(1, "boots")
	var high := _gear(4, "boots")
	check("auto : meilleure rareté (%s)" % CardPicker.auto_pick([low, high, low]).subtitle, CardPicker.auto_pick([low, high, low]) == high)
	var a := _gear(3, "boots", 10)
	var b := _gear(3, "boots", 40)
	var prof := ClassGear.profile(Run.class_id)
	var best := a if Items.rating(a.item, prof) >= Items.rating(b.item, prof) else b
	check("auto : même rareté, meilleure note pondérée (%.2f / %.2f)" % [Items.rating(a.item, prof), Items.rating(b.item, prof)], CardPicker.auto_pick([a, b]) == best)
	var anvil := [{"type": "anvil_slot", "id": "weapon", "slot": "weapon", "title": "Arme"}, {"type": "anvil_slot", "id": "head", "slot": "head", "title": "Tête"}]
	check("auto : enclume = l'emplacement le plus utile (le 1er)", CardPicker.auto_pick(anvil) == anvil[0])
	var cards := Run.roll_cards(3)
	check("auto : une carte est toujours choisie", not CardPicker.auto_pick(cards).is_empty() and not CardPicker.auto_pick(cards, true).is_empty())
	check("auto : rien à choisir = rien", CardPicker.auto_pick([]).is_empty())


## Aide « Bot » : coffre d'équipement, arme secondaire, enclume, trophées, niveau : rien ne reste ouvert.
func _test_bot_offers() -> void:
	Settings.set_assist("bot")
	var d: RunDirector = world.director
	var inv0 := Profile.inventory.size()
	var loot0: int = Run.loot.size()
	world._offer("Coffre : choisis une pièce d'équipement", d.gear_cards(3, 2), func(): return d.gear_cards(3, 2))
	check("Bot : coffre d'équipement choisi seul (sac %d -> %d), pas d'écran" % [inv0, Profile.inventory.size()], not world.cards.is_open() and (Profile.inventory.size() > inv0 or Run.loot.size() > loot0))
	world._offer("Arme secondaire trouvée : choisis-en une", SlotChests.offhand_offer(1, 1).map(func(it): return RunDirector.weapon_card(it, "offhand")))
	check("Bot : arme secondaire choisie seule (%s)" % String(Profile.equipped.get("offhand", {}).get("name", "")), not world.cards.is_open() and not Profile.equipped.get("offhand", {}).is_empty())
	world._offer("Enclume : choisis un emplacement", d.anvil_slot_cards().slice(0, 3))
	check("Bot : enclume choisie seule", not world.cards.is_open() and not Run.slot_bonus.is_empty())
	world._offer("Trophées", d.trophy_cards(3))
	check("Bot : trophée choisi seul (%d)" % Run.trophies.size(), not world.cards.is_open())
	world._offer("Niveau ! Choisis une carte", Run.roll_cards(3), func(): return Run.roll_cards(3))
	check("Bot : carte de niveau choisie seule", not world.cards.is_open())
	Settings.set_assist("assisted")
	world._offer("Coffre : choisis une pièce d'équipement", d.gear_cards(3, 2))
	check("Assisté : le choix reste au joueur (écran ouvert)", world.cards.is_open())
	_close_cards()


## Pilote automatique : 3 minutes de jeu, jamais d'écran de choix ouvert, des cartes et de l'équipement pris.
func _test_autoplay_run() -> void:
	var d: RunDirector = world.director
	var p: Player = world.player
	p.autoplay = true
	p.dev_invincible = true  # la mesure porte sur les choix, pas sur la survie
	var t0 := d.time
	var lvl0 := p.level
	var cards0 := Run.skills.size() + Run.passives.size()
	var open_seen := 0
	Engine.time_scale = AUTOPLAY_SCALE
	var limit := Time.get_ticks_msec() + int(AUTOPLAY_SECS * 1000.0 * 1.5)  # garde-fou : la machine de test tient rarement ×3
	while d.time - t0 < AUTOPLAY_SECS and Time.get_ticks_msec() < limit:
		await get_tree().create_timer(0.25, true, false, true).timeout
		if world.cards.is_open() or get_tree().paused:
			open_seen += 1
	Engine.time_scale = 1.0
	p.autoplay = false
	p.dev_invincible = false
	print("[autoplay] %.0f s de jeu, niveau %d -> %d, cartes %d -> %d, coffres %d" % [d.time - t0, lvl0, p.level, cards0, Run.skills.size() + Run.passives.size(), d.chests_opened])
	check("pilote automatique : %.0f s de jeu joués" % (d.time - t0), d.time - t0 >= AUTOPLAY_SECS * 0.95)
	check("pilote automatique : aucun écran de choix ni pause pendant la run (%d relevés)" % open_seen, open_seen == 0)
	check("pilote automatique : des niveaux et des cartes pris", p.level > lvl0 and Run.skills.size() + Run.passives.size() > cards0)


# --- (A) choix pendant l'entrée dans l'arène du boss, à la manette -----------------------------------
func _pad(button: JoyButton, pressed: bool) -> void:
	var e := InputEventJoypadButton.new()
	e.device = 0
	e.button_index = button
	e.pressed = pressed
	Input.parse_input_event(e)


func _tap(button: JoyButton) -> void:
	_pad(button, true)
	await get_tree().process_frame
	await get_tree().process_frame
	_pad(button, false)
	await get_tree().process_frame


func _test_boss_choice() -> void:
	var d: RunDirector = world.director
	var p: Player = world.player
	_clear()
	# des orbes restées dehors, assez pour deux niveaux : l'entrée dans l'arène les donne (comme en jeu)
	var need := GameData.xp_to_next(p.level) + GameData.xp_to_next(p.level + 1)
	d.orbs.spawn(p.global_position + Vector3(60, 0, 60), float(need) / maxf(p.xp_mult, 0.01) + 5.0)
	var lvl0 := p.level
	Gamepad._set_active(true)
	await ScreenFade.run(get_tree(), d._enter_arena)  # le portail du donjon (run_director._interact)
	await get_tree().process_frame
	check("arène : passage de niveau pendant le fondu (%d -> %d), choix ouvert" % [lvl0, p.level], p.level >= lvl0 + 1 and world.cards.is_open())
	check("arène : le jeu reste en pause après le fondu (bug du 15/10)", get_tree().paused)
	var boss: Monster = d._boss
	if boss == null or not world.cards.is_open():
		check("boss présent et choix ouvert", false)
		return
	# héros au contact du boss : sans pause, il prendrait des coups et la fureur avancerait
	p.global_position = boss.global_position + Vector3(1.5, 0, 0)
	var snap := [p.hp, boss.hp, d.time, d._boss_time, boss.global_position]
	await get_tree().create_timer(2.5, true, false, true).timeout
	check("pause : PV du héros figés (%.0f -> %.0f)" % [snap[0], p.hp], is_equal_approx(p.hp, snap[0]))
	check("pause : PV du boss figés (%.0f -> %.0f)" % [snap[1], boss.hp], is_equal_approx(boss.hp, snap[1]))
	check("pause : temps de la carte et fureur figés (%.2f / %.2f s)" % [d.time - snap[2], d._boss_time - snap[3]], d.time == snap[2] and d._boss_time == snap[3])
	check("pause : le boss ne bouge pas", boss.global_position.is_equal_approx(snap[4]))
	# manette : le cadre est sur la 1re carte, la croix passe à la 2e, A la choisit
	check("manette : cadre doré sur la 1re carte dès l'ouverture", UiNav.shown and UiNav.cursor == world.cards._buttons[0])
	await _tap(JOY_BUTTON_DPAD_RIGHT)
	check("manette : croix droite -> 2e carte", UiNav.cursor == world.cards._buttons[1])
	var chosen: Dictionary = world.cards._cards[1]
	var applied := [0]
	var count := func(): applied[0] += 1
	Run.changed.connect(count)
	var n := 0
	while world.cards.is_open() and n < 6:
		await get_tree().create_timer(CardPicker.CONFIRM_DELAY_MS / 1000.0 + 0.1, true, false, true).timeout
		await _tap(JOY_BUTTON_A)
		await get_tree().process_frame
		n += 1
	Run.changed.disconnect(count)
	check("manette : A choisit (%d choix, %d appliqués, « %s » en premier)" % [n, applied[0], String(chosen.get("title", ""))], not world.cards.is_open() and applied[0] >= n and n >= 1)
	await get_tree().process_frame
	check("choix fini : le jeu reprend", not get_tree().paused)
	Gamepad._set_active(false)


func _clear() -> void:
	for m in get_tree().get_nodes_in_group("monsters"):
		m.remove_from_group("monsters")
		m.queue_free()


func _close_cards() -> void:
	world.cards._queue.clear()
	world.cards._show_next()
