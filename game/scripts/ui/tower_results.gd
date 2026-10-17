class_name TowerResults
extends ResultsPanel
## Bilan de fin d'ascension de la Tour : étage atteint, record, maîtrise gagnée, butin gardé. Lot DNG-1 : temps des tranches de
## 10 étages contre leur record (BestTimes), objets des coffres en cases, « Ce qui t'a battu » après une chute (HitLog), et
## « Reprendre » au palier de reprise (Tower.checkpoint) quand il est plus haut que l'étage de départ.

const TITLES := {"victoire": "SOMMET DE LA TOUR !", "defaite": "CHUTE DANS LA TOUR", "abandon": "ASCENSION ARRÊTÉE"}


## [param got] : Tower.finish() {best, new_record, xp, levels, items, crystals, chests, looks}.
func show_results(result: String, floor_reached: int, got: Dictionary) -> void:
	var diff: String = Tower.DIFF_NAMES[Tower.difficulty]
	var cls := Run.class_data()
	var record := bool(got.get("new_record", false))
	var heroes := int(got.get("heroes", Tower.duel_index(floor_reached) - Tower.duel_index(Tower.start_floor - 1)))
	var gained: Array = [row("Maîtrise %s" % cls.get("name_fr", ""), "+%d" % int(got.get("xp", 0)), "", "expertise")]
	if int(got.get("levels", 0)) > 0:
		gained.append(row("Niveau %d de maîtrise" % Profile.expertise_level(Run.class_id), "", "", "expertise"))
	if record:
		gained.append(row("Nouveau record", "étage %d" % int(got.get("best", 0)), diff, "stats"))
	var kept: Array = []
	if int(got.get("items", 0)) > 0:
		kept.append(row("Objets des coffres", str(int(got.items)), "Ils rejoignent ton coffre commun", "equipment"))
	if int(got.get("crystals", 0)) > 0:
		var cursed := int(got.get("cursed", 0))
		kept.append(row("Cristaux", str(int(got.crystals)), ("Dont %d pour %d étage%s maudit%s" % [int(got.get("cursed_crystals", 0)), cursed,
			"s" if cursed > 1 else "", "s" if cursed > 1 else ""]) if cursed > 0 else ResourceHelp.tip("crystal"), "crystal"))
	kept.append_array(chest_rows(got.get("chests", [])))
	if int(got.get("looks", 0)) > 0:
		kept.append(row("Coffre d'apparence", "×%d" % int(got.looks) if int(got.looks) > 1 else "", "Palier franchi", "chest"))
	var build: PackedStringArray = []
	for e in Run.all_skills():
		build.append("%s r%d" % [Run.skill_def(int(e.id)).get("name", "?"), int(e.rank)])
	for id in Run.passives:
		build.append("%s ×%d" % [Run.passive_def(String(id)).get("name", id), int(Run.passives[id])])
	var buttons: Array = [
		{"text": "Rejouer (étage %d, %s)" % [Tower.start_floor, diff], "primary": true, "call": _restart.bind(Tower.start_floor)},
		{"text": "Retour au menu", "call": func(): Tower.leave(get_tree())},
	]
	var resume := resume_floor(result)
	if resume > 0:
		buttons[0].primary = false
		buttons.push_front({"text": "Reprendre (étage %d)" % resume, "primary": true, "call": _restart.bind(resume)})
	var spec := {
		"title": TITLES.get(result, "FIN DE L'ASCENSION"),
		"tone": "win" if result == "victoire" else "lose",
		"subtitle": "%s · %s" % [cls.get("name_fr", ""), diff],
		"tiles": [
			["%d / %d" % [floor_reached, Tower.FLOORS], "étage atteint", "", record],
			[str(int(got.get("best", 0))), "record %s" % diff.to_lower()],
			[str(heroes), "héros battus"],
			[str(int(got.get("bosses", 0))), "boss vaincus"],
			[BestTimes.fmt(BestTimes.clock) if BestTimes.clock > 0.5 else Run.duration_text(), "durée"],
			[str(Run.kills), "monstres"],
		],
		"notes": BestTimes.record_notes(),
		"loot": loot_of(Tower.found),
		"gained": gained,
		"kept": kept,
		"lost": [row("Build de l'ascension", "", "Sorts, cartes et équipement de la Tour", "equipment")],
		"quest": Compass.after("tower", {"crystals": int(got.get("crystals", 0)), "looks": int(got.get("looks", 0))}),
		"footnote": ("Build : " + "  ·  ".join(build)) if not build.is_empty() else "",
		"buttons": buttons,
	}
	if result == "defaite" and HitLog.died():
		spec["defeat"] = HitLog.report()
	show_spec(spec)
	print("[tour] fin : %s, étage %d, record %d, %d objet(s) gardés, coffre commun : %d objet(s)" % [result, floor_reached, int(got.get("best", 0)), int(got.get("items", 0)), Profile.inventory.size()])


func _restart(from: int) -> void:
	get_tree().paused = false
	Tower.start(Profile.selected_class, Tower.difficulty, from)
	get_tree().change_scene_to_file("res://scenes/world.tscn")


## Étage de reprise proposé après une chute ou un arrêt : le palier de reprise (début du bloc de 10 du record) s'il est plus
## haut que l'étage de départ de l'ascension (une chute à l'étage 12 partie du 1 propose l'étage 11) ; 0 sinon.
static func resume_floor(result: String) -> int:
	if result == "victoire":
		return 0
	var cp := Tower.checkpoint()
	return cp if cp > Tower.start_floor and Tower.unlocked(cp, Tower.difficulty) else 0


## Objets des coffres de l'ascension en cases, les meilleurs d'abord (rareté, puis niveau).
static func loot_of(items: Array) -> Array:
	var list := items.duplicate()
	list.sort_custom(func(a, b): return int(a.get("rarity", 0)) * 1000 + int(a.get("level", 0)) > int(b.get("rarity", 0)) * 1000 + int(b.get("level", 0)))
	return list.map(func(it): return loot_entry(it))
