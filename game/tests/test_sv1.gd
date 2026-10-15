extends Node
## Lot S1 du Survivant (conception/survivor) : le mode existe, se lance depuis le lobby (mode dev), part sans rien du
## hub, ne touche JAMAIS au hub (victoire, défaite, abandon, fermeture en pleine run), revient au lobby, et les autres
## modes restent intacts. Le pilote vit dans la racine (il survit aux changements de scène) :
## godot --headless --path game res://tests/test_sv1.tscn

const LOBBY := "res://scenes/lobby.tscn"

var fails := 0
var _t0 := 0.0


func check(label: String, ok: bool) -> void:
	print(("OK    " if ok else "ÉCHEC ") + label)
	if not ok:
		fails += 1


func _ready() -> void:
	if name == "Sv1Driver":
		_t0 = Time.get_ticks_msec() / 1000.0
		_run.call_deferred()
		return
	var d: Node = (load("res://tests/test_sv1.gd") as GDScript).new()
	d.name = "Sv1Driver"
	get_tree().root.add_child.call_deferred(d)


# --- outils ------------------------------------------------------------------------------------------------------
func _wait(secs: float) -> void:
	await get_tree().create_timer(secs, true, false, true).timeout


func _until(cond: Callable, limit: float, label := "") -> bool:
	var t := 0.0
	while t < limit:
		if cond.call():
			return true
		await _wait(0.1)
		t += 0.1
	if label != "":
		print("   (délai dépassé : %s)" % label)
	return cond.call()


func _scene() -> Node:
	return get_tree().current_scene


func _is_lobby() -> bool:
	var s := _scene()
	return s != null and s.has_method("_start_survivor")


func _is_world() -> bool:
	var s := _scene()
	return s != null and s.has_method("end_run") and "director" in s and s.director != null and "player" in s and is_instance_valid(s.player) and s.get("hud") != null


func _results() -> ResultsPanel:
	var s := _scene()
	if s == null:
		return null
	for c in s.get_children():
		if c is ResultsPanel:
			return c
	return null


## Empreinte du hub : équipement (coffre, préréglages, loadout) et toute la progression du compte.
## Valeurs comparées comme sur le disque : nombres en flottants, clés triées (une sauvegarde relue reste identique).
func _hub() -> String:
	var vault: Array = Profile.vault.map(func(it): return _norm(it))
	vault.sort()
	var parts := ["vault=" + str(vault), "loadout=" + _norm(Profile.loadout), "presets=" + _norm(Profile.presets)]
	for k in Survivor.HUB_KEYS:
		var v: Variant = Profile.get(k)
		match k:  # (lot S6 : les seules choses que le Survivant donne : coffres d'apparence, titres, plafonds)
			"reward_chests":
				v = (v as Array).filter(func(c): return not String(c.type).begins_with("look_"))
			"records":
				v = (v as Dictionary).duplicate(true)
				v.erase(SurvivorRewards.KEY)
				v.erase("quests")
			"extra_titles":
				v = (v as Array).filter(func(t): return not String(t) in SurvivorRewards.TITLES)
		parts.append("%s=%s" % [k, _norm(v)])
	return "\n".join(parts)


func _norm(v: Variant) -> String:
	return JSON.stringify(JSON.parse_string(JSON.stringify(v)), "", true)


## Parties de l'empreinte qui diffèrent de [param ref] (diagnostic d'un échec).
func _hub_diff(ref: String) -> String:
	var a := ref.split("\n")
	var b := _hub().split("\n")
	var out: Array = []
	for i in mini(a.size(), b.size()):
		if a[i] != b[i]:
			out.append("%s -> %s" % [a[i].left(120), b[i].left(120)])
	return "; ".join(out)


## Ce que la run pourrait écrire par erreur dans le hub (simule toutes les fuites à la fois).
func _leak() -> void:
	Profile.insignia += 500
	Profile.records["kills"] = int(Profile.records.get("kills", 0)) + 99
	Profile.reward_chests.append(Rewards.make("forge", 10, false))
	Profile.seen_gear.append(999999)
	Profile.materials["crystal"] = int(Profile.materials.get("crystal", 0)) + 10
	Profile.bag["drill"] = 5
	Profile.runs_done += 3
	Profile.expertise["warrior"] = int(Profile.expertise.get("warrior", 0)) + 1000
	Profile.equipped["head"] = Items.generate(5, 0.5, "head")


func _disk() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(Profile.save_path))


# --- le déroulé ----------------------------------------------------------------------------------------------------
func _run() -> void:
	Settings.reset_all()
	Profile.selected_class = "warrior"
	Profile.reset_all()
	Profile.in_run = false
	# un compte qui a déjà un peu de tout au hub
	Profile.insignia = 123
	Profile.stash = {"drill": 3}
	Profile.materials["crystal"] = 50
	Profile.records["kills"] = 5
	Profile.reward_chests.append(Rewards.make("jewel", 5, false))
	Profile.save_profile()
	_unit()
	await _flow()
	print("\n%s (%d échec(s))" % ["TOUT EST OK" if fails == 0 else "ÉCHECS", fails])
	Profile.reset_all()
	get_tree().quit(1 if fails > 0 else 0)


func _unit() -> void:
	# --- activité : sans verrou, cachée hors mode dev tant que le mode n'est pas fini ---------------------------
	var a := Activities.get_def("survivor")
	check("activité « Survivant » dans la rangée Aventure, juste après la Survie", a.get("row", "") == "adventure"
		and Activities.LIST.find(a) == Activities.LIST.find(Activities.get_def("survival")) + 1)
	check("aucun verrou (pas de lien avec la progression)", not a.has("unlock") and not Activities.locked(a) and not Unlocks.LIST.has("survivor"))
	check("gains : apparences et titres seulement", a.get("gives", []) == ["look", "title"])
	Settings.set_v("interface", "dev_mode", false)
	check("hors mode dev : cachée (Survivor.READY = %s)" % Survivor.READY, Activities.hidden(a) == not Survivor.READY)
	Settings.set_v("interface", "dev_mode", true)
	check("mode dev : visible", not Activities.hidden(a))
	Settings.set_v("interface", "dev_mode", false)
	check("8 zones jouables, sans condition", Survivor.zones().size() == 8 and "limestone" in Survivor.zones())

	# --- lancement : héros nu, mode et règles ---------------------------------------------------------------------
	var hub := _hub()
	var hub_eq := Profile.equipped.duplicate(true)
	Survivor.start("warrior", "beluga")
	check("Modes.current() == survivor (%s)" % Modes.current(), Modes.current() == "survivor")
	check("drapeaux : Survivor.active, Run.survivor, Run.survival (socle)", Survivor.active and Run.survivor and Run.survival)
	check("départ sans arme ni pièce, inventaire vide, sac : les potions de départ seulement (%s)" % Profile.bag, Profile.equipped.is_empty() and Profile.inventory.is_empty()
		and Profile.bag.keys().all(func(k): return String(k).begins_with("potion:")))
	check("la réserve de fournitures reste au hub (%s)" % Profile.stash, Profile.stash == {"drill": 3})
	check("zone choisie, époque I carte 1", Run.zone_id == "beluga" and Survivor.zone_id == "beluga" and Run.epoch == 1 and Run.stage == 1)
	check("profil de règles « survivor »", ModeRules.profile_name() == "survivor" and is_equal_approx(Survivor.rule("boss_hp"), Survivor.BOSS_HP))
	check("expérience ×2 au niveau 1, ×1,15 au niveau 10, puis en baisse (lot S7)", is_equal_approx(Survivor.xp_mult(1), 2.0) and is_equal_approx(Survivor.xp_mult(10), 1.15) and is_equal_approx(Survivor.xp_mult(40), Survivor.XP_LATE))
	check("arme : celle de la classe tant qu'aucune n'est portée", Run.weapon_type() == Items.default_weapon_type("warrior"))
	Profile.equipped["weapon"] = {"slot": "weapon", "wtype": "bow", "eden": 0, "sv": true}
	check("arme portée d'un autre type : son type (%s)" % Run.weapon_type(), Run.weapon_type() == "bow")
	Profile.equipped.erase("weapon")
	Run.hero_level = 37
	check("pièce du Survivant : puissance = niveau du héros", Items.power_level({"sv": true, "level": 90}) == 37)
	Run.hero_level = 150
	check("pièce du Survivant : plafonnée à 90", Items.power_level({"sv": true, "level": 12}) == 90)
	Run.hero_level = 1
	check("lieux : ni scribe ni fortune, les autres inchangés", Survivor.station_count("scribe", 2) == 0 and Survivor.station_count("fortune", 1) == 0 and Survivor.station_count("anvil", 3) == 3)
	check("sanctuaire « trophée » -> carte", Survivor.shrine_reward("trophy") == "card" and Survivor.shrine_reward("keys") == "keys")
	check("cartes du Survivant (S3) : rien pris, le choix de départ (armes et compétences)", SurvivorCards.handles()
		and Run.roll_cards(3).all(func(c): return String(c.type) in ["sv_weapon", "skill"] and c.get("sv_first", false)))
	check("carte « sv_… » appartient au Survivant", Survivor.owns({"type": "sv_piece"}) and not Survivor.owns({"type": "skill"}))

	# --- fermeture en pleine run : la sauvegarde ne contient rien de la run -------------------------------------
	_leak()
	Profile.save_profile()
	var disk := _disk()
	check("sauvegarde en pleine run : insignes, records, coffres, réserve, cristaux du hub %s" % [[disk.insignia, disk.records.get("kills"), (disk.reward_chests as Array).size(), disk.stash, disk.crystals, disk.runs_done]], int(disk.insignia) == 123
		and int(disk.records.get("kills", 0)) == 5 and (disk.reward_chests as Array).size() == 1 and disk.stash.size() == 1 and int(disk.stash.get("drill", 0)) == 3
		and int(disk.crystals) == 50 and int(disk.runs_done) == 0 and not 999999 in (disk.seen_gear as Array))
	Profile.in_run = false
	Profile.load_profile()
	Survivor.reset()
	Run.active = false
	check("reprise après fermeture : hub identique " + _hub_diff(hub), _hub() == hub)

	# --- fin de run : victoire, défaite, abandon ------------------------------------------------------------------
	for res in ["victoire", "defaite", "abandon"]:
		Survivor.start("warrior", "limestone")
		_leak()
		RunJournal._time = 30.0
		Run.finish(res)
		check("%s : mode retombé, Run.survivor gardé pour le bilan" % res, Modes.current() == "menu" and not Survivor.active and Run.survivor)
		check("%s : journal de run en mode survivor (%s)" % [res, RunJournal.last_line.get("mode", "?")], RunJournal.last_line.get("mode", "") == "survivor"
			and RunJournal.last_line.get("sv_zone", "") == "limestone")
		check("%s : ni maîtrise ni insignes" % res, Run.expertise_gain == 0 and Run.insignia_gain == 0)
		Profile.end_run_survival()
		check("%s : hub identique (équipement, progression, réserve) %s" % [res, _hub_diff(hub)], _hub() == hub)
		check("%s : équipement du hub porté de nouveau au lobby" % res, _sorted(Profile.equipped.keys()) == _sorted(hub_eq.keys()))

	# --- les autres modes restent intacts --------------------------------------------------------------------------
	Run.start_survival("warrior", 1)
	check("Survie après un Survivant : mode survival, équipement du hub", Modes.current() == "survival" and not Survivor.active and not Run.survivor
		and not Profile.equipped.is_empty() and ModeRules.profile_name() == "")
	Run.finish("abandon")
	Profile.end_run_survival()
	hub = _hub()  # (la Survie, elle, compte : maîtrise, runs, réserve perdue à l'abandon)
	Royale.start("warrior")
	check("Battle royale après un Survivant : mode royale", Modes.current() == "royale" and not Survivor.active)
	Royale.active = false
	Run.active = false
	Run.survival = false
	Profile.in_run = false
	Profile.load_profile()
	check("hub toujours identique " + _hub_diff(hub), _hub() == hub)


## Le vrai chemin : lobby -> page du Survivant -> monde -> défaite -> Rejouer -> victoire (boss) -> lobby.
func _flow() -> void:
	var hub := _hub()
	Settings.set_v("interface", "dev_mode", false)
	get_tree().change_scene_to_file.call_deferred(LOBBY)
	check("lobby chargé", await _until(_is_lobby, 40.0, "lobby"))
	await _wait(0.8)
	var lobby := _scene()
	lobby._show_menu("play")
	check("menu Jouer hors mode dev : Survivant %s" % ("affiché (READY)" if Survivor.READY else "caché"), _has_text(lobby._sub, "Survivant") == Survivor.READY)
	Settings.set_v("interface", "dev_mode", true)
	lobby._show_menu("play")
	check("menu Jouer en mode dev : la carte Survivant", _has_text(lobby._sub, "Survivant"))
	lobby._show_menu("survivor")
	check("page du Survivant : zones (boss en sous-titre) et bouton Lancer", _has_text(lobby._sub, "Boss :") and _has_text(lobby._foot, "Lancer"))
	lobby._sv_zone = "rainbowfall"
	hub = _hub()  # (le lobby a pu ouvrir des entrées au chargement)
	Settings.set_v("interface", "dev_mode", false)
	lobby._start_survivor()
	check("monde du Survivant chargé", await _until(_is_world, 90.0, "monde"))
	var world := _scene()
	check("Modes.current() == survivor en jeu, zone %s" % Run.zone_id, Modes.current() == "survivor" and Run.zone_id == "rainbowfall" and world.director.sv != null)
	check("héros niveau 1, sans pièce du hub", world.player.level == 1 and Profile.equipped.is_empty())
	check("pas d'autel du scribe ni de la fortune sur la carte", world.director.map.interactables.all(func(it): return not is_instance_valid(it) or not it.kind in ["scribe", "fortune"]))
	check("choix de départ ouvert (arme ou compétence, jeu en pause)", await _until(func(): return world.cards.is_open(), 10.0, "choix de départ"))
	world.cards._opened_at -= CardPicker.CONFIRM_DELAY_MS
	world.cards._choose(0)
	world.player.autoplay = true
	await _wait(6.0)
	check("le héros joue (vivant, une arme ou une compétence prise)", not world.player.is_dead and (not Run.skills.is_empty() or Profile.equipped.has("weapon")))
	# défaite
	world.revives_left = 0
	world.player.hp = 1.0
	world.player.take_damage(1e9, null, false)
	check("défaite : bilan", await _until(func(): return _results() != null, 20.0, "bilan"))
	var panel := _results()
	await _wait(ResultsPanel.LOCK_SECS + 1.5)
	check("bilan du Survivant : Rejouer, Changer de classe, Retour au lobby", panel.buttons.size() == 3 and panel.buttons[0].text == "Rejouer")
	var wid := world.get_instance_id()
	panel.buttons[0].pressed.emit()
	check("Rejouer : nouvelle partie", await _until(func(): return _is_world() and _scene().get_instance_id() != wid, 90.0, "monde relancé"))
	world = _scene()
	check("Rejouer : même zone, mode survivor", Modes.current() == "survivor" and Run.zone_id == "rainbowfall")
	world.player.autoplay = true
	await _wait(3.0)
	# victoire : le boss de l'unique carte tombe
	world.director.debug_enter_dungeon()
	await _wait(1.0)
	world.director._on_boss_killed()
	check("boss vaincu : une seule carte, pas de portail", world.director.state == "cleared" and world.director.next_zone_id() == "")
	for i in 20:
		if _results() != null:
			break
		if world.cards.is_open():
			world.cards._opened_at -= CardPicker.CONFIRM_DELAY_MS
			world.cards._choose(0)
		await _wait(0.5)
	check("victoire : bilan", await _until(func(): return _results() != null, 20.0, "bilan de victoire"))
	panel = _results()
	check("victoire : titre", panel != null and Run.result == "victoire")
	await _wait(ResultsPanel.LOCK_SECS + 1.5)
	panel.buttons[panel.buttons.size() - 1].pressed.emit()
	check("retour au lobby", await _until(_is_lobby, 40.0, "lobby"))
	await _wait(0.8)
	check("état propre au lobby", not Run.active and not Survivor.active and not get_tree().paused and not Profile.in_run)
	check("hub identique après tout le parcours " + _hub_diff(hub), _hub() == hub)
	# une Survie normale se lance encore depuis le lobby
	_scene()._launching = false
	_scene()._start_run()
	check("Survie après le Survivant : monde chargé, mode survival", await _until(_is_world, 90.0, "Survie") and Modes.current() == "survival" and _scene().director.sv == null)
	_scene().pause_menu.abandon_requested.emit()
	await _until(func(): return _results() != null, 20.0, "bilan Survie")
	await _wait(ResultsPanel.LOCK_SECS + 1.5)
	var p2 := _results()
	if p2:
		p2.buttons[p2.buttons.size() - 1].pressed.emit()
	await _until(_is_lobby, 40.0, "lobby")


func _sorted(a: Array) -> Array:
	var b := a.duplicate()
	b.sort()
	return b


func _has_text(root: Node, txt: String) -> bool:
	for c in root.find_children("*", "Label", true, false):
		if String(c.text).contains(txt):
			return true
	for c in root.find_children("*", "Button", true, false):
		if String(c.text).contains(txt):
			return true
	return false
