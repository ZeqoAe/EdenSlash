extends "res://tests/test_p4_activities.gd"
## Régression complète (passe P18) : le parcours de test_p4_activities (lancement depuis le lobby, courte partie, fin, bilan,
## retour au lobby) étendu à ce que la nuit a ajouté depuis :
## - Survivant aux paliers II à V (ouverts par une victoire au palier précédent), règles du palier en place, et la progression
##   du compte intacte après la run (Survivor.HUB_KEYS + coffre, préréglages, loadout ; SurvivorRewards.hub_view) ;
## - la Tour lancée sur un étage de chaque type (Tower.TYPES : monstres, élites, duelliste, boss, ombre, halte, maudit) ;
## - un Donjon Normal à la carte avec un boss de la bibliothèque (salle du boss atteinte, boss de la bibliothèque en jeu).
## godot --headless --path game res://tests/test_p18_modes.tscn [-- survivor2,tower_boss,dungeon_lib,...]

var _hub_ref := ""
var _floor := {}  # type d'étage -> étage joué


func _default_list() -> Array:
	var out: Array = ["survivor2", "survivor3", "survivor4", "survivor5"]
	for t in Tower.TYPES:
		out.append("tower_" + String(t))
	out.append("dungeon_lib")
	return out


## Premier étage (1 à 200) du type [param t].
func _floor_of(t: String) -> int:
	for f in range(1, 201):
		if Tower.floor_type(f) == t:
			return f
	return -1


func _launch_extra(act: String, lobby: Node) -> void:
	if act.begins_with("survivor"):
		var p := int(act.trim_prefix("survivor"))
		var wins := {}
		for i in range(1, p):
			wins[str(i)] = 1
		Profile.records[SurvivorRewards.KEY] = {"wins": wins, "first": [], "day": Quests.today(), "today": []}
		for q in Quests.daily() + Quests.weekly():
			q["done"] = true  # (une quête accomplie par la run donnerait des insignes, à bon droit : hors de ce contrôle)
		Unlocks.refresh()  # (ce que le lobby ferait au retour, pour que l'empreinte ne compte que la run)
		Achievements.refresh()
		Wheel.state()  # (la roulette du jour s'initialise au 1er affichage du lobby)
		Profile.save_profile()
		check("%s : palier %d ouvert par la victoire au palier précédent (sans mode dev)" % [act, p], Survivor.palier_open(p, false))
		_hub_ref = _hub()
		lobby._show_menu("survivor")
		lobby._sv_palier = p
		lobby._start_survivor()
	elif act.begins_with("tower_"):
		var t := act.trim_prefix("tower_")
		var f := _floor_of(t)
		_floor[t] = f
		check("%s : un étage de ce type existe (étage %d)" % [act, f], f > 0)
		lobby._start_tower(1, maxi(f, 1))
	elif act == "dungeon_lib":
		var zid := String(Dungeons.zone_ids()[0])
		var lib := ""
		for bid in BossLibrary.for_zone(zid):
			if String(bid) != BossLibrary.zone_boss(zid):
				lib = String(bid)
				break
		check("dungeon_lib : la zone %s a un boss de bibliothèque autre que le sien (%s)" % [zid, lib], lib != "")
		lobby._dg_zone = zid
		lobby._dg_diff = 0
		lobby._dg_allies = ["", ""]
		DungeonPage.sel = lib
		lobby._start_dungeon()


func _check_world(act: String, world: Node, _player: Player) -> void:
	await get_tree().process_frame
	if act.begins_with("survivor"):
		var p := int(act.trim_prefix("survivor"))
		check("%s : Survivant actif au palier %d (palier %d)" % [act, p, Survivor.palier], Survivor.active and Survivor.palier == p)
		check("%s : soins ÷ 2 du palier en place (%s)" % [act, ModeRules.modifiers],
			("heal_half" in ModeRules.modifiers) == bool(Survivor.tier_rule("heal_half")))
	elif act.begins_with("tower_"):
		var t := act.trim_prefix("tower_")
		var td: TowerDirector = world.director.tower
		check("%s : étage %d joué, de type %s" % [act, Tower.floor_n, Tower.floor_type(Tower.floor_n)],
			td != null and Tower.floor_n == int(_floor.get(t, -1)) and Tower.floor_type(Tower.floor_n) == t)
		var ok := true
		match t:
			"boss":
				ok = is_instance_valid(td._boss) and not td._boss.is_dead
			"duel", "shadow":
				ok = is_instance_valid(td._rival) or is_instance_valid(td._hero)
			"rest":
				ok = td.phase == "cards"
			"elite":
				ok = not td._elites_alive.is_empty()
			"cursed":
				ok = td._curse != "" and not td._elites_alive.is_empty()
			"monsters":
				ok = td.alive() + td.left > 0
		check("%s : le contenu de l'étage est en place (phase %s)" % [act, td.phase], ok)
	elif act == "dungeon_lib":
		var td: TowerDirector = world.director.tower
		td.begin(Tower.top())  # salle du boss
		await _wait(2.0)
		check("dungeon_lib : salle du boss %d / %d, boss de la bibliothèque %s en jeu" % [Tower.floor_n, Tower.top(), Tower.dungeon_boss],
			Tower.dungeon_boss == DungeonPage.sel and Tower.floor_n == Tower.top() and is_instance_valid(td._boss) and not td._boss.is_dead)


func _check_after(act: String, out: Dictionary) -> void:
	if act.begins_with("survivor"):
		var diff := _hub_diff(_hub_ref)
		check("%s : progression du compte intacte après la run%s" % [act, "" if diff == "" else " (" + diff + ")"], diff == "")
		check("%s : règles du palier retirées (%s)" % [act, ModeRules.modifiers], ModeRules.modifiers.is_empty() and not Survivor.active)
	elif act == "dungeon_lib":
		DungeonPage.sel = ""
	if not bool(out.get("ok", false)):
		print("   (%s : %s)" % [act, out.get("note", "")])


func _norm(v: Variant) -> String:
	return JSON.stringify(JSON.parse_string(JSON.stringify(v)), "", true)


## Empreinte de la progression du compte (comme test_sv8), sans ce que le Survivant a le droit de donner.
func _hub() -> String:
	var vault: Array = Profile.vault.map(func(it): return _norm(it))
	vault.sort()
	var parts := ["vault=" + str(vault), "loadout=" + _norm(Profile.loadout), "presets=" + _norm(Profile.presets)]
	for k in Survivor.HUB_KEYS:
		parts.append("%s=%s" % [k, _norm(SurvivorRewards.hub_view(k, Profile.get(k)))])
	return "\n".join(parts)


func _hub_diff(ref: String) -> String:
	var a := ref.split("\n")
	var b := _hub().split("\n")
	var out: Array = []
	for i in mini(a.size(), b.size()):
		if a[i] != b[i]:
			out.append("%s : %s -> %s" % [a[i].get_slice("=", 0), a[i].substr(0, 120), b[i].substr(0, 120)])
	return "; ".join(out)
