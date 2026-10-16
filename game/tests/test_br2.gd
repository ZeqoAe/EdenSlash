extends Node
## Battle royale, passe BR2 : coffres repérables (vrai modèle, aura par qualité) et carte vidée de ses jarres et caisses.
## godot --headless --path game res://tests/test_br2.tscn

var fails := 0


func check(label: String, ok: bool) -> void:
	print(("OK    " if ok else "ÉCHEC ") + label)
	if not ok:
		fails += 1


func _ready() -> void:
	Settings.reset_all()
	# les quatre qualités : nom, modèle de coffre (plus le tonneau d'Eden), aura (halo, faisceau) cachée à l'ouverture
	var names: Array = []
	for t in ProcMap.ROYALE_LOOKS.size():
		var it := ProcMap.make_royale_chest(t)
		add_child(it)
		names.append(it.title)
		check("qualité %d : « %s », étiquette et aura" % [t, it.title], it.kind == "chest" and int(it.get_meta("tier")) == t
			and it.get_child_count() >= 3 and it._beam != null and it._beam.get_child_count() >= 2)
		var aura_nodes := it._beam.get_child_count()
		it.open_chest()
		check("  ouvert : l'aura s'éteint", not it._beam.visible and it.used and aura_nodes >= 2)
	check("quatre noms distincts : %s" % [names], names.size() == 4 and _distinct(names))
	# aura seule (marque d'atterrissage du largage)
	var mark := Interactable.make_aura(Color.WHITE, 10.0, 3.0, 0)
	add_child(mark)
	check("aura seule : halo et faisceau, sans étincelles", mark.get_child_count() == 2)
	var drop := ProcMap.make_royale_chest(3)
	add_child(drop)
	drop.set_aura_visible(false)
	check("largage : aura cachée puis rendue", not drop._beam.visible)
	drop.set_aura_visible(true)
	check("  rendue", drop._beam.visible)
	# la carte du Battle royale : 64 coffres de vrais coffres, aucune jarre ni caisse ni tas d'or, quelques cristaux
	var m := ProcMap.new()
	m.biome = "limestone"
	add_child(m)
	m.generate_royale(4321)
	var br: Breakables = m.breakables
	check("carte : %d coffres posés" % m.chests.size(), m.chests.size() >= 40)
	var tiers := [0, 0, 0]
	for it in m.interactables:
		if it.kind == "chest":
			tiers[int(it.get_meta("tier"))] += 1
			if String(it.title) in ["Coffre", "Coffre ouvragé"]:
				check("coffre de la carte avec l'ancien nom", false)
	check("carte : coffres des trois qualités %s" % [tiers], tiers[0] > 0 and tiers[1] > 0 and tiers[2] > 0)
	check("carte : aucune jarre, caisse ni tas d'or (%d, %d, %d)" % [br.count("pot"), br.count("crate"), br.count("gold")],
		br.count("pot") == 0 and br.count("crate") == 0 and br.count("gold") == 0)
	check("carte : quelques cristaux seulement (%d)" % br.count("gem"), br.count("gem") > 0 and br.count("gem") <= 24)
	# la Survie n'est pas touchée : même carte, jarres et caisses toujours là
	var s := ProcMap.new()
	s.biome = "limestone"
	add_child(s)
	s.generate_run(4321)
	check("Survie : jarres (%d) et caisses (%d) inchangées" % [s.breakables.count("pot"), s.breakables.count("crate")],
		s.breakables.count("pot") > 100 and s.breakables.count("crate") > 100)
	# Le calcul de navigation d'une carte tourne sur un fil du moteur : quitter avant sa fin plante Godot à l'arrêt
	# (code 0xC0000005). On attend donc l'événement « maillage posé » de chaque carte, jamais une durée.
	await _nav_baked(m)
	await _nav_baked(s)
	print("TOUT EST OK (0 échec(s))" if fails == 0 else "ÉCHECS : %d" % fails)
	get_tree().quit(fails)


func _nav_baked(map: ProcMap) -> void:
	var frames := 0
	while map._region.navigation_mesh == null and frames < 3600:
		await get_tree().physics_frame
		frames += 1
	check("carte : maillage de navigation posé", map._region.navigation_mesh != null)


func _distinct(a: Array) -> bool:
	for i in a.size():
		for j in range(i + 1, a.size()):
			if a[i] == a[j]:
				return false
	return true
