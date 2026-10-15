extends Node
## Captures des infobulles d'objets : une carte par rareté et par emplacement (courte, complète, comparaison),
## au hub puis en Survie. Écrit dans le dossier donné par la variable d'environnement SHOT_DIR (sinon user://shots) :
## godot --path game res://tests/shot_tips.tscn   (profil de test : rien n'est sauvegardé)

var _dir := ""


func _shot(name: String, cards: Array) -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	var bg := ColorRect.new()
	bg.color = Color(0.1, 0.1, 0.14)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)
	var row := HBoxContainer.new()
	row.position = Vector2(16, 16)
	row.add_theme_constant_override("separation", 12)
	root.add_child(row)
	for c in cards:
		var box := VBoxContainer.new()
		row.add_child(box)
		box.add_child(c)
	await get_tree().create_timer(0.5).timeout
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [_dir, name])
	root.queue_free()
	await get_tree().process_frame


func _gear(rarity: int, slot: String, level := 30, wtype := "") -> Dictionary:
	return Items.generate(level, 0.0, slot, "warrior", rarity, wtype, 5)


func _ready() -> void:
	_dir = OS.get_environment("SHOT_DIR")
	if _dir == "":
		_dir = ProjectSettings.globalize_path("user://shots")
	DirAccess.make_dir_recursive_absolute(_dir)
	Settings.reset_all()
	Profile.selected_class = "warrior"
	Profile.reset_all()
	seed(7)
	# --- hub : une pièce par rareté ----------------------------------------------------------------------
	var cm := _gear(0, "weapon")
	var sp := _gear(1, "head")
	var ra := _gear(2, "boots")
	var ep := _gear(3, "ring")
	var my := _gear(4, "chest")
	var lg := _gear(5, "back", 50)
	var lw := _gear(5, "weapon", 70, "staff")
	var ln := _gear(5, "necklace", 60)
	lg["sockets"] = [{"type": "onyx", "tier": 3}, null]
	lg["enchant"] = {"type": "rehab", "lv": 4}
	lg["upgrade"] = 7
	await _shot("hub_1_commun_a_epique", [ItemWidgets.item_card(cm, "", 0), ItemWidgets.item_card(sp, "", 0), ItemWidgets.item_card(ra, "", 0), ItemWidgets.item_card(ep, "", 0)])
	await _shot("hub_2_mythique_legendaire", [ItemWidgets.item_card(my, "", 0), ItemWidgets.item_card(lg, "", 0), ItemWidgets.item_card(lw, "", 0)])
	await _shot("hub_3_complete", [ItemWidgets.item_card(lg, "", 1), ItemWidgets.item_card(lw, "", 1)])
	# arche-type de donjon et pièce de set
	var sets := _gear(5, "legs", 60)
	sets["archetype"] = "frost"
	var set_piece: Dictionary = {}
	for i in 200:
		var t := _gear(5, "head", 60)
		if t.has("set"):
			set_piece = t
			break
	if not set_piece.is_empty():
		set_piece["archetype"] = "storm"
	await _shot("hub_4_panoplies", [ItemWidgets.item_card(sets, "", 0), ItemWidgets.item_card(set_piece if not set_piece.is_empty() else ln, "", 0), ItemWidgets.item_card(set_piece if not set_piece.is_empty() else ln, "", 1)])
	# --- comparaison avec la pièce portée -------------------------------------------------------------------
	Profile.equipped["chest"] = _gear(2, "chest", 20)
	Profile.equipped["back"] = _gear(3, "back", 30)
	await _shot("hub_5_comparaison", [ItemWidgets.item_card(my, "", 0), ItemWidgets.item_card(lg, "", 0), ItemWidgets.item_card(lg, "", 1)])
	# --- Survie : pièce portée avec l'enclume, nouvelle pièce proposée ---------------------------------------
	Run.start_survival("warrior", 1)
	Run.hero_level = 12
	Run.slot_bonus["chest"] = 4
	var worn: Dictionary = Profile.equipped["chest"]
	var offer := _gear(4, "chest", 30)
	await _shot("run_1", [ItemWidgets.item_card(worn, "", 0), ItemWidgets.item_card(offer, "", 0), ItemWidgets.item_card(offer, "", 1)])
	print("captures dans ", _dir)
	get_tree().quit()
