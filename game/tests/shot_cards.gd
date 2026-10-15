extends Node
## Captures du choix de carte (user://shots/cartes_*.png) : cartes de départ, pièces d'équipement, variantes d'arme.
## godot --path game res://tests/shot_cards.tscn   (APPDATA détourné : le test ne sauvegarde rien)


func _shot(name: String, wait := 0.8) -> void:
	await get_tree().create_timer(wait).timeout
	DirAccess.make_dir_recursive_absolute("user://shots")
	get_viewport().get_texture().get_image().save_png("user://shots/cartes_%s.png" % name)


func _ready() -> void:
	Training.active = true
	Settings.reset_all()
	Profile.reset_all()
	Run.start("samurai")
	var bg := ColorRect.new()
	bg.color = Color(0.25, 0.3, 0.2)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var picker := CardPicker.new()
	add_child(picker)
	picker.offer("Niveau 2 : choisis une carte", Run.roll_cards(3, true))
	await _shot("niveau_voile", 0.1)
	await _shot("niveau")
	picker._choose(0)
	var gear: Array = []
	for slot in ["back", "gloves", "chest"]:
		gear.append(RunDirector.item_card(Items.generate(50, 1.0, slot, "samurai", Items.LEGENDARY, "", Items.LEGENDARY), "gear"))
	picker.offer("Coffre doré : choisis une pièce d'équipement", gear, func(): return gear)
	await _shot("equipement")
	picker._choose(1)
	var weapons: Array = []
	for i in 2:
		var w := Items.generate(1, 0.0, "weapon", "samurai", Items.MYTHIC, "", Items.MYTHIC)
		w["auto_variant"] = i
		weapons.append(RunDirector.weapon_card(w, "gear"))
	picker.offer("Ton arme : choisis sa variante", weapons)
	await _shot("variantes")
	get_tree().quit()
