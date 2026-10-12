extends Node
## Cycle roguelite : nouvelle partie, run, amélioration, objet gardé, rechargement.
## godot --headless --path game res://tests/test_progress.tscn  (profil de test uniquement)

var fails := 0


func check(label: String, ok: bool) -> void:
	print(("OK    " if ok else "ÉCHEC ") + label)
	if not ok:
		fails += 1


func _ready() -> void:
	check("profil de test", Profile.save_path == Profile.TEST_SAVE_PATH)
	Profile.reset_all()
	check("nouvelle partie : 1 katana d'héritage", Profile.vault.size() == 1 and Profile.equipped.has("weapon"))
	var w_uid: String = Profile.equipped.weapon.uid
	Run.start("samurai")
	check("run : or et butin à zéro", Profile.gold == 0 and Profile.inventory.is_empty() and Profile.in_run)
	check("run : katana copié", Profile.equipped.weapon.uid == w_uid and not is_same(Profile.equipped.weapon, Profile.vault[0]))
	for i in 5:
		Profile.add_item(Items.generate(3, 0.5))
	Profile.gain({"gold": 5000, "fragment": 200, "essence": 50, "crystal": 5})
	var w: Dictionary = Profile.equipped.weapon
	for i in 8:
		Profile.upgrade_item(w)
	check("katana amélioré en +8", int(w.upgrade) == 8)
	var spent := {}
	for u in 8:
		var c := Items.upgrade_cost({"level": int(w.level), "upgrade": u})
		for k in c:
			spent[k] = int(spent.get(k, 0)) + int(c[k])
	var refund := Items.upgrade_refund(w)
	print("  pierres dépensées ", spent, "  rendues ", refund)
	check("remboursement 70 % des pierres", int(refund.fragment) == roundi(spent.fragment * 0.7) and not refund.has("gold"))
	var sv := Items.sell_value(w)
	check("vente : or + pierres", sv.has("gold") and int(sv.fragment) == int(refund.fragment))
	var item: Dictionary = Profile.inventory[0]
	var before := int(Profile.materials.fragment)
	var got := Profile.disassemble(item)
	check("désassemblage crédité", int(Profile.materials.fragment) == before + int(got.fragment) and Profile.inventory.size() == 4)
	Run.finish("defaite")
	Profile.end_run(w)
	check("fin de run : héritage mis à jour (+8), rien d'autre", Profile.vault.size() == 1 and int(Profile.vault[0].upgrade) == 8)
	check("lobby : or et matériaux remis à zéro", Profile.gold == 0 and int(Profile.materials.fragment) == 0)
	Run.start("samurai")
	var loot := Items.generate(4, 1.0, "head")
	Profile.add_item(loot)
	Run.finish("victoire")
	Profile.end_run(loot)
	check("nouvel objet gardé et porté (emplacement libre)", Profile.vault.size() == 2 and Profile.equipped.has("head"))
	Profile.load_profile()
	check("rechargé du disque", Profile.vault.size() == 2 and int(Profile.equipped.weapon.upgrade) == 8 and Profile.runs_done == 2)
	# zones : la victoire débloque la suivante, la nouvelle partie remet à zéro
	check("une seule zone au départ", Profile.unlocked_zones >= 1 and Profile.zone_unlocked("limestone"))
	Profile.unlocked_zones = 1
	var next := Profile.unlock_after("limestone")
	check("victoire Limestone -> %s" % next, next != "" and Profile.zone_unlocked(GameData.zones[1].id) and not Profile.zone_unlocked(GameData.zones[2].id))
	check("rejouer une zone déjà battue ne débloque rien", Profile.unlock_after("limestone") == "")
	Profile.reset_all()
	check("nouvelle partie : zones verrouillées", Profile.unlocked_zones == 1 and Profile.selected_zone == "limestone")
	print("échecs : ", fails)
	get_tree().quit(fails)
