extends Node
## Lot U3 : coffres lisibles (type + spécialité, pastille d'icône) et roulette qui montre ses gains à l'avance.
## godot --headless --path game res://tests/test_u3.tscn

var fails := 0


func check(label: String, ok: bool) -> void:
	print(("OK    " if ok else "ÉCHEC ") + label)
	if not ok:
		fails += 1


func _ready() -> void:
	Settings.reset_all()
	Profile.reset_all()
	_test_kinds()
	_test_board()
	await _test_pages()
	print("\n%s (%d échec(s))" % ["TOUT EST OK" if fails == 0 else "ÉCHECS", fails])
	get_tree().quit(1 if fails > 0 else 0)


func _test_kinds() -> void:
	var plain := Rewards.make("forge", 60)
	var scroll := Rewards.make("forge", 60, false, "scroll")
	var enchant := Rewards.make("jewel", 60, false, "enchant")
	check("genre : un coffre de forge sans spécialité", Rewards.kind_of(plain) == "forge")
	check("genre : forge + parchemins distinct de la forge", Rewards.kind_of(scroll) == "forge:scroll" and Rewards.kind_of(scroll) != Rewards.kind_of(plain))
	check("libellés : forge, forge · parchemins, joaillier · formules",
		Rewards.name_of(plain) == "Coffre de forge" and Rewards.name_of(scroll) == "Coffre de forge · parchemins" and Rewards.name_of(enchant) == "Coffre de joaillier · formules")
	check("une spécialité sur un autre type est ignorée", Rewards.kind_of(Rewards.make("gear", 60, false, "scroll")) == "gear")
	var kinds := ["jewel:gem", "forge:stone", "gear", "forge", "set", "aura_legend", "jewel", "forge:scroll"]
	kinds.sort_custom(func(a, b): return Rewards.kind_rank(a) < Rewards.kind_rank(b))
	check("ordre : auras, set, équipement, forge puis joaillier, spécialités à la suite",
		kinds == ["aura_legend", "set", "gear", "forge", "forge:scroll", "forge:stone", "jewel", "jewel:gem"])
	var icons_ok := true
	for t in Rewards.TYPES:
		icons_ok = icons_ok and ResourceLoader.exists(MenuWidgets.ICONS % String(Rewards.TYPES[t].icon))
	check("chaque type a une icône de pastille qui existe", icons_ok)
	var blurbs := {}
	for k in ["forge", "forge:scroll", "forge:stone", "jewel", "jewel:gem", "jewel:enchant"]:
		blurbs[Rewards.kind_blurb(k)] = true
	check("une phrase différente par genre de forge / joaillier", blurbs.size() == 6)
	check("phrases sans pourcentage", Rewards.TYPES.values().all(func(t): return not String(t.desc).contains("%")))
	check("récapitulatif au pluriel correct", Rewards.summary({"supplies": {}, "crystal": 1, "items": [1], "looks": [1, 2]}) == "1 cristal, 1 objet, 2 apparences")
	check("aperçu d'un coffre d'auras : une seule phrase", not Rewards.preview(Rewards.make("aura_legend", 30)).contains("insignes"))


func _ids(looks: Array) -> Array:
	return looks.map(func(x): return int(x.get("id", 0)))


func _test_board() -> void:
	Wheel.day_override = "2026-10-20"
	Profile.wheel = {}
	var b := Wheel.board()
	check("planche : une entrée par case", b.size() == Wheel.SLICES.size())
	var ok_lost := true
	var ids := {}
	var dup := false
	for i in b.size():
		if String(Wheel.SLICES[i][0]) == "lost":
			ok_lost = ok_lost and (b[i] as Dictionary).is_empty()
		elif not (b[i] as Dictionary).is_empty():
			dup = dup or ids.has(int(b[i].id))
			ids[int(b[i].id)] = true
	check("planche : « Perdu » ne promet rien", ok_lost)
	check("planche : une apparence différente par case", not dup and ids.size() >= 6)
	check("planche : la même tant qu'on ne lance pas", _ids(Wheel.board()) == _ids(b))
	var saved := Profile.wheel.get("board", {}) as Dictionary
	check("planche : gardée dans la sauvegarde", (saved.ids as Array).size() == Wheel.SLICES.size())
	# ce qui est promis est ce qui est donné
	var rare := Wheel.slice_of("rare")
	var promised: Dictionary = b[rare]
	var r := Wheel.spin((float(Wheel.span(rare).x) + 0.01) / TAU)
	check("lancer : le gain est l'apparence montrée sur la case", r.ok and int(r.slice) == rare and int(r.look.get("id", -1)) == int(promised.get("id", -2)))
	check("lancer : l'apparence est dans la collection", Profile.collected(promised))
	check("planche : renouvelée après le lancer, sans l'apparence gagnée", not _ids(Wheel.board()).has(int(promised.id)))
	# case « Perdu » puis pitié : la case garantie montre aussi ce qu'elle donne
	Profile.wheel = {"day": "2026-10-20", "used": 0, "extra": 0, "misses": 6, "since_rare": 0, "total": 0}
	var lost := Wheel.slice_of("lost")
	var common: Dictionary = Wheel.board()[Wheel.slice_of("common")]
	var p := Wheel.spin((float(Wheel.span(lost).x) + 0.01) / TAU)
	check("pitié : la case du gain garanti tient sa promesse", String(p.kind) == "common" and int(p.look.get("id", -1)) == int(common.get("id", -2)))
	# une apparence promise obtenue entre-temps est remplacée
	Profile.wheel = {"day": "2026-10-21", "used": 0, "extra": 0, "misses": 0, "since_rare": 0, "total": 0}
	Wheel.day_override = "2026-10-21"
	var victim: Dictionary = Wheel.board()[Wheel.slice_of("epic")]
	Profile.collect(victim)
	var after: Dictionary = Wheel.board()[Wheel.slice_of("epic")]
	check("promesse déjà obtenue : remplacée", int(after.get("id", 0)) != int(victim.id))
	Profile.wheel = {}
	Wheel.day_override = ""


func _test_pages() -> void:
	Profile.reset_all()
	for f in ["", "scroll", "stone"]:
		Profile.reward_chests.append(Rewards.make("forge", 60, false, f))
	Profile.reward_chests.append(Rewards.make("forge", 60, false, "scroll"))
	Profile.reward_chests.append(Rewards.make("jewel", 60, false, "enchant"))
	var page := ChestsPage.new()
	add_child(page)
	page.size = Vector2(1400, 800)
	page.refresh()
	check("liste : une ligne par genre (forge, parchemins, pierres, formules)", page._list.get_child_count() == 4)
	check("bouton Ouvrir tout avec le compte", page._all_btn.visible and page._all_btn.text == "Ouvrir tout (5)")
	check("détail : niveau et une phrase, le contenu en infobulle", page._detail.text.contains("Niveau 60") and not page._detail.text.contains("%") and page._detail.tooltip_text.contains("parchemins"))
	page.open_many(Profile.reward_chests.duplicate())
	check("après Ouvrir tout : plus de coffre, titre et récapitulatif sans doublon",
		Profile.reward_chests.is_empty() and page._title.text == "5 coffres ouverts" and not page._detail.text.contains("coffre commun"))
	page.refresh()
	await get_tree().process_frame  # les anciennes lignes partent à la fin de l'image
	check("état vide : une phrase", page._list.get_child_count() == 1 and not page._all_btn.visible)
	page.queue_free()
	Wheel.day_override = ""
	Profile.wheel = {}
	var wp := WheelPage.new()
	add_child(wp)
	wp.size = Vector2(1400, 800)
	wp.refresh()
	check("roulette : la liste montre une apparence par case gagnante", wp._legend.get_child_count() == 9 + 1)
	check("roulette : la roue connaît ses apparences", wp._wheel.looks.size() == Wheel.SLICES.size())
	Wheel.day_override = "2026-10-22"
	Profile.wheel = {}
	wp.refresh()
	wp._on_spin(0.5)  # une case mythique
	check("roulette : la planche reste figée pendant le lancer", wp._showing and wp._busy)
	var shown := _ids(wp._wheel.looks)
	await get_tree().create_timer(5.0).timeout
	check("roulette : le gain s'affiche en grand à la fin", wp._reveal.visible and wp._reveal_name.text != "")
	check("roulette : la roue montre encore l'ancienne planche", _ids(wp._wheel.looks) == shown)
	wp._end_reveal()
	check("roulette : après l'annonce, la nouvelle planche", not wp._showing and not wp._reveal.visible)
	Wheel.day_override = ""
	Profile.wheel = {}
	wp.queue_free()
