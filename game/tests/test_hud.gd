extends Node
## Interface : icônes des effets, barres de buffs / debuffs (durée, clignotement),
## panneau d'objectifs repliable, HUD masqué sous le menu pause, polices du thème.
## godot --headless --path game res://tests/test_hud.tscn  (profil de test uniquement)

var fails := 0
var world: Node
var player: Player


func check(label: String, ok: bool) -> void:
	print(("OK    " if ok else "ÉCHEC ") + label)
	if not ok:
		fails += 1


## Le HUD se met à jour pendant son propre _process : on attend deux images.
func _frames() -> void:
	await get_tree().process_frame
	await get_tree().process_frame


func _ready() -> void:
	var missing: Array = []
	for st in Combatant.STATUS_INFO.keys() + ["flow"]:
		if StatusDb.icon(st) == null:
			missing.append(st)
	check("une icône pour chaque effet (manquantes : %s)" % [missing], missing.is_empty())
	check("polices du thème chargées", UiTheme.title_font() != ThemeDB.fallback_font or UiTheme.title_font() is FontFile)
	check("buff / debuff", StatusDb.is_buff("frenzy") and not StatusDb.is_buff("burn") and not StatusDb.is_buff("stun"))
	world = load("res://scenes/world.tscn").instantiate()
	get_tree().root.add_child.call_deferred(world)
	await get_tree().create_timer(6.0).timeout
	player = world.player
	for m in get_tree().get_nodes_in_group("monsters"):
		m.queue_free()
	world.director.set_process(false)
	world.cards._queue.clear()
	world.cards._show_next()
	var hud: Hud = world.hud
	player.add_status("keen", 10.0, player)
	player.add_status("frenzy", 2.0, player)
	player.add_status("purgatory", 6.0, player)
	await get_tree().create_timer(0.3).timeout
	check("buffs affichés à gauche", hud._buff_row._icons.has("keen") and hud._buff_row._icons.has("frenzy"))
	check("debuffs affichés à droite", hud._debuff_row._icons.has("purgatory") and not hud._buff_row._icons.has("purgatory"))
	var keen: Control = hud._buff_row._icons.keen
	check("durée totale retenue pour le balayage", absf(keen.total - 10.0) < 0.5 and keen.left < 10.0)
	var blinking := false
	for i in 30:
		await get_tree().process_frame
		blinking = blinking or hud._buff_row._icons.frenzy.modulate.a < 0.9
	check("clignote sous 3 s", blinking and keen.modulate.a == 1.0)
	check("infobulle de l'effet", String(keen.tooltip_text).contains("Œil acéré"))
	await get_tree().create_timer(2.2).timeout
	check("effet expiré retiré", not hud._buff_row._icons.has("frenzy"))
	player.flow_stacks = 2
	player._flow_until = player._time + 2.5
	await _frames()
	check("Fluidité avec ses paliers", hud._buff_row._icons.has("flow") and hud._buff_row._icons.flow.stacks == 2)
	player.stun(1.5)
	await _frames()
	check("étourdissement en debuff", hud._debuff_row._icons.has("stun"))
	# objectifs : repliés, dépliés avec la touche, auto à une découverte
	await get_tree().create_timer(Hud.OBJECTIVE_AUTO_SHOW + 0.5).timeout
	check("objectifs repliés par défaut", not hud._obj_details.visible)
	var ev := InputEventAction.new()
	ev.action = "objectives"
	ev.pressed = true
	hud._unhandled_input(ev)
	await _frames()
	check("touche Objectifs : dépliés (chevron ▴)", hud._obj_details.visible and hud._obj_chevron.text == "▴")
	hud._unhandled_input(ev)
	await _frames()
	check("touche Objectifs : repliés (chevron ▾)", not hud._obj_details.visible and hud._obj_chevron.text == "▾")
	check("pile de gauche : objectifs et premiers pas dans une seule colonne ; fil du butin à droite (lot HUD-2)", hud._obj_panel.get_parent() == hud._left and hud._steps_panel.get_parent() == hud._left and hud._feed == hud._loot)
	world.director.seals += 1
	await _frames()
	check("découverte : dépliés quelques secondes", hud._obj_details.visible)
	# combo et orbes
	check("barre de niveau : niveau affiché", hud._xp_orb.big_text == str(player.level))
	world.pause_menu.open()
	await _frames()
	check("HUD masqué sous le menu pause", not hud._root.visible)
	world.pause_menu.close()
	await _frames()
	check("HUD revenu après la pause", hud._root.visible)
	world.queue_free()
	print("\n%s (%d échec(s))" % ["TOUT EST OK" if fails == 0 else "ÉCHECS", fails])
	get_tree().quit(1 if fails > 0 else 0)
