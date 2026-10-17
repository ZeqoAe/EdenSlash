class_name DungeonResults
extends ResultsPanel
## Bilan d'un donjon, de la Ruée des boss et du Siège : salles franchies, butin (coffres de matières, cristaux,
## plan, titre), maîtrise gagnée. Lot DNG-1 : temps contre record (BestTimes), butin en cases (pièces du coffre de panoplie,
## plan), emplacements du boss qui manquent encore, objectifs ★ du Siège, « Ce qui t'a battu » après une chute (HitLog) et
## « Réessayer le boss » après une chute dans la salle du boss.

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
	var rw0: Dictionary = got.get("reward", {})
	if rush and not (rw0.get("bosses", []) as Array).is_empty():
		# passe M6 : les boss vaincus du tirage, ses modificateurs
		var names: Array = (rw0.bosses as Array).map(func(id): return BossLibrary.short_name(String(id)))
		var mods: Array = (rw0.get("mods", []) as Array).map(func(k): return String(Rush.MODS.get(k, {}).get("name", k)))
		notes.append("Vaincus : %s%s" % [", ".join(names), (" · " + ", ".join(mods)) if not mods.is_empty() else ""])
	var stars: Array = []
	if siege and not (rw0.get("stars", []) as Array).is_empty():
		var st: Array = rw0.stars
		var fresh: Array = rw0.get("new_stars", [])
		stars = Siege.STARS.map(func(s): return {"label": String(s.name), "done": String(s.id) in st, "new": String(s.id) in fresh, "tip": String(s.tip)})
	notes.append_array(BestTimes.record_notes())
	var cls := Run.class_data()
	var gained: Array = [row("Maîtrise %s" % cls.get("name_fr", ""), "+%d" % int(got.get("xp", 0)), "", "expertise")]
	var kept: Array = []
	if victory or rush or siege:
		var r: Dictionary = got.get("reward", {})
		kept.append_array(chest_rows(r.get("chests", [])))
		if int(r.get("crystals", 0)) > 0:
			kept.append(row("Cristaux", str(int(r.crystals)), ResourceHelp.tip("crystal"), "crystal"))
		if String(r.get("plan", "")) != "":
			kept.append(row("Plan de donjon", BossLibrary.short_name(String(r.plan).trim_prefix(Dungeons.PLAN_PREFIX)), ResourceHelp.tip("plan"), "equipment"))
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
	var time_key := ""
	if rush and int(got.get("rush_seed", 0)) > 0:
		time_key = BestTimes.rush_key(int(got.rush_seed), diff)
	elif not rush and not siege and bid != "":
		time_key = BestTimes.dungeon_key(bid, diff)
	var tiles: Array = [progress, [Dungeons.DIFF_NAMES[diff], "difficulté"], [str(Run.max_level), "niveau"], _time_tile(time_key),
		[str(Run.kills), "monstres"], [str(Run.elites), "élites"]]
	var boss_e := BestTimes.entry(BestTimes.boss_key("dungeon", bid, diff)) if bid != "" and not rush else {}
	if not boss_e.is_empty():
		tiles[4] = BestTimes.tile(boss_e, 0.0, "boss")
	if rush and int(rw0.get("seed", 0)) > 0:
		tiles = tiles.slice(0, 4) + [["n° %d" % int(rw0.seed), "tirage"], [str((rw0.get("mods", []) as Array).size()), "modificateurs"]]
	var buttons: Array = [
		{"text": "Rejouer (la Ruée)" if rush else ("Rejouer (même siège)" if siege else "Rejouer (même donjon)"), "primary": true, "call": func():
			get_tree().paused = false
			if siege:
				Tower.start_siege(Profile.selected_class, zid, diff, Dungeons.last_allies)
			else:
				Tower.start_dungeon(Profile.selected_class, zid, diff, Dungeons.last_allies, bid)
			get_tree().change_scene_to_file("res://scenes/world.tscn")},
		{"text": "Retour au menu", "call": func():
			get_tree().paused = false
			get_tree().change_scene_to_file("res://scenes/lobby.tscn")},
	]
	if retry_boss(got):
		# chute dans la salle du boss (lot DNG-1) : on reprend devant lui, une carte tirée par salle sautée
		buttons[0].primary = false
		buttons.push_front({"text": "Réessayer le boss", "primary": true, "call": _retry.bind(zid, diff, bid)})
	var spec := {
		"title": title,
		"tone": "win" if victory else "lose",
		"subtitle": "%s · %s" % [place, cls.get("name_fr", "")],
		"notes": notes,
		"tiles": tiles,
		"stars": stars,
		"loot": loot_of(got),
		"missing": missing_text(bid) if not rush and not siege and bid != "" else "",
		"gained": gained,
		"kept": kept,
		"quest": Compass.after("siege" if siege else ("rush" if rush else "dungeon"), quest),
		"buttons": buttons,
	}
	if HitLog.died() and (not victory or String(got.get("outcome", "")) == "eliminated"):
		var rep := HitLog.report()
		spec["defeat"] = rep
		spec["defeat_note"] = low_note(bid if bid != "" else String(rep.get("boss", "")))
	show_spec(spec)


func _retry(zid: String, diff: int, bid: String) -> void:
	get_tree().paused = false
	Tower.start_dungeon(Profile.selected_class, zid, diff, Dungeons.last_allies, bid, Dungeons.ROOMS.size())
	get_tree().change_scene_to_file("res://scenes/world.tscn")


## Tuile du temps : contre le record de [param key] s'il y en a un pour cette partie, sinon la durée de la partie.
static func _time_tile(key: String) -> Array:
	var e := BestTimes.entry(key) if key != "" else {}
	if e.is_empty():
		return [BestTimes.fmt(BestTimes.clock) if BestTimes.clock > 0.5 else Run.duration_text(), "durée"]
	return BestTimes.tile(e, 0.0)


## « Réessayer le boss » : chute dans la salle du boss d'un donjon (pas la Ruée ni le Siège).
static func retry_boss(got: Dictionary) -> bool:
	return not bool(got.get("victory", false)) and not bool(got.get("rush", false)) and not bool(got.get("siege", false)) \
		and String(got.get("boss", "")) != "" and int(got.get("rooms", 0)) >= Dungeons.ROOMS.size() - 1


## Butin en cases : ce que contiennent les coffres de panoplie et d'équipement (emplacements, niveau, rareté), le plan.
static func loot_of(got: Dictionary) -> Array:
	var rw: Dictionary = got.get("reward", {})
	var out: Array = []
	for c in rw.get("chests", []):
		var kind := String(c.get("type", ""))
		if not kind in ["set", "gear"]:
			continue
		var slots: Array = (c.get("slots", []) as Array).map(func(x): return String(Items.SLOT_NAMES.get(x, x)))
		var set_name := String(Items.SETS.get(String(c.get("archetype", "")), {}).get("name", ""))
		var name := (" ou ".join(slots) if not slots.is_empty() else "Pièce de panoplie") if kind == "set" else "Pièce d'équipement"
		var legend := Rewards.legendary_open(c)
		out.append({"name": name, "sub": "%sNv %d · %s" % [(set_name + " · ") if set_name != "" and kind == "set" else "", int(c.get("plevel", 1)),
			"légendaire possible" if legend else "mythique"], "rarity": Items.LEGENDARY if legend else Items.MYTHIC,
			"tip": Rewards.TYPES.get(kind, {}).get("desc", "") + " Au menu Coffres."})
	if String(rw.get("plan", "")) != "":
		out.append({"name": "Plan de donjon", "sub": BossLibrary.short_name(String(rw.plan).trim_prefix(Dungeons.PLAN_PREFIX)), "rarity": Items.LEGENDARY,
			"tip": ResourceHelp.tip("plan")})
	return out


## « Pièces de Latif qui te manquent : Torse, Jambes » ("" : il ne manque rien, ou boss inconnu).
static func missing_text(bid: String) -> String:
	if not BossLibrary.has(bid):
		return ""
	var miss: Array = Encounters.missing_slots(bid).map(func(x): return String(Items.SLOT_NAMES.get(x, x)))
	if miss.is_empty():
		return ""
	if miss.size() == 1:
		return "Il te manque encore ici : %s (seul emplacement de %s qui te manque)" % [miss[0], BossLibrary.short_name(bid)]
	return "Pièces de %s qui te manquent : %s" % [BossLibrary.short_name(bid), ", ".join(miss)]


## « Ton meilleur sur Latif : il lui restait 41 % (aujourd'hui 22 %) » ("" : boss inconnu ou jamais entamé).
static func low_note(bid: String) -> String:
	if bid == "" or not BossLibrary.has(bid):
		return ""
	var today := float(Encounters.last_low.get(bid, -1.0))
	var best := Encounters.best_low(bid)
	if today < 0.0 or best >= 0.999:
		return ""
	if best <= 0.0:
		return "Tu l'as déjà vaincu : aujourd'hui, il lui restait %d %%" % roundi(today * 100.0)
	return "Ton meilleur sur %s : il lui restait %d %% (aujourd'hui %d %%)" % [BossLibrary.short_name(bid), roundi(best * 100.0), roundi(today * 100.0)]


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
