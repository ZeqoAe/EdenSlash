class_name DungeonResults
extends ResultsPanel
## Bilan d'un donjon, de la Ruée des boss et du Siège : salles franchies, butin (coffres de matières, cristaux,
## plan, titre), maîtrise gagnée.

const TITLES := {true: "DONJON TERMINÉ !", false: "ÉCHEC DANS LE DONJON"}


func show_results(got: Dictionary) -> void:
	var victory := bool(got.get("victory", false))
	var siege := bool(got.get("siege", false))
	var rush := bool(got.get("rush", false))
	var zid := String(got.get("zone", ""))
	var diff := int(got.get("diff", 0))
	var rooms := int(got.get("rooms", 0))
	var title: String = TITLES[victory]
	var progress := ["%d / %d" % [rooms, Dungeons.rush_floors() if rush else Dungeons.ROOMS.size()], "salles franchies"]
	var bid := String(got.get("boss", ""))
	var place := Dungeons.dungeon_name(bid) if bid != "" else Dungeons.name_of(zid)  # donjon à la carte (passe M2)
	if rush:
		title = "RUÉE TERMINÉE !" if victory else "RUÉE INTERROMPUE"
		place = "La Ruée des boss"
		progress[1] = "boss vaincus"
	if siege:
		title = siege_title(got)
		place = "Le Siège · %s" % Dungeons.name_of(zid)
		progress = ["%d / %d" % [mini(rooms, Siege.WAVES), Siege.WAVES], "vagues vaincues"]
	var notes: Array = []
	if siege and String(got.get("outcome", "")) != "":
		notes.append(siege_outcome_text(got))
	var cls := Run.class_data()
	var gained: Array = [row("Maîtrise %s" % cls.get("name_fr", ""), "+%d" % int(got.get("xp", 0)), "", "expertise")]
	var kept: Array = []
	if victory or rush or siege:
		var r: Dictionary = got.get("reward", {})
		kept.append_array(chest_rows(r.get("chests", [])))
		if int(r.get("crystals", 0)) > 0:
			kept.append(row("Cristaux", str(int(r.crystals)), ResourceHelp.tip("crystal"), "crystal"))
		if String(r.get("plan", "")) != "":
			kept.append(row("Plan de fabrication", "", "À fabriquer à l'Atelier", "equipment"))
		if String(r.get("title", "")) != "":
			gained.append(row("Titre « %s »" % String(r.title), "", "", "user"))
	var quest := {}
	if victory or rush or siege:
		var rw: Dictionary = got.get("reward", {})
		quest = {"crystals": int(rw.get("crystals", 0)), "plan": String(rw.get("plan", "")), "title": String(rw.get("title", "")),
			"formulas": siege and (rw.get("chests", []) as Array).any(func(c): return String(c.get("focus", "")) == "enchant"),
			"looks": 1 if siege and String(got.get("outcome", "")) in ["won", "escaped"] else 0}
		for c in rw.get("chests", []):
			if String(c.get("archetype", "")) != "":
				quest["archetype"] = String(c.archetype)
	var tiles: Array = [progress, [Dungeons.DIFF_NAMES[diff], "difficulté"], [str(Run.max_level), "niveau"], [Run.duration_text(), "durée"],
		[str(Run.kills), "monstres"], [str(Run.elites), "élites"]]
	show_spec({
		"title": title,
		"tone": "win" if victory else "lose",
		"subtitle": "%s · %s" % [place, cls.get("name_fr", "")],
		"notes": notes,
		"tiles": tiles,
		"gained": gained,
		"kept": kept,
		"quest": Compass.after("siege" if siege else ("rush" if rush else "dungeon"), quest),
		"buttons": [
			{"text": "Rejouer (la Ruée)" if rush else ("Rejouer (même siège)" if siege else "Rejouer (même donjon)"), "primary": true, "call": func():
				get_tree().paused = false
				if siege:
					Tower.start_siege(Profile.selected_class, zid, diff, Dungeons.last_allies)
				else:
					Tower.start_dungeon(Profile.selected_class, zid, diff, Dungeons.last_allies, bid)
				get_tree().change_scene_to_file("res://scenes/world.tscn")},
			{"text": "Retour au lobby", "call": func():
				get_tree().paused = false
				get_tree().change_scene_to_file("res://scenes/lobby.tscn")},
		],
	})


## Titre du bilan d'un siège selon l'issue du chacun pour soi.
static func siege_title(got: Dictionary) -> String:
	match String(got.get("outcome", "")):
		"won":
			return "DERNIER DEBOUT !"
		"escaped":
			return "TU QUITTES LE DUEL"
		"eliminated":
			return "ÉLIMINÉ (%de)" % maxi(2, int(got.get("rank", 3)))
	return "SIÈGE TERMINÉ" if bool(got.get("victory", false)) else "SIÈGE PERDU"


static func siege_outcome_text(got: Dictionary) -> String:
	match String(got.get("outcome", "")):
		"won":
			return "Tu as battu tes deux compagnons : coffre d'apparence légendaire."
		"escaped":
			return "Tu as emporté le cœur hors de l'anneau : récompense moindre, mais saine et sauve."
		"eliminated":
			return "Le boss est tombé, mais tu n'as pas survécu au chacun pour soi."
	return ""
