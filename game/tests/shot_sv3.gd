extends Node
## Captures des cartes du Survivant (lot S3, user://shots/sv3_*.png) : premier choix (armes et compétences), montée de
## niveau (pièce, amélioration à passif de palier, sort), coffre d'emplacement (3 pièces).
## godot --path game res://tests/shot_sv3.tscn --resolution 1280x720


func _shot(name: String, wait := 0.8) -> void:
	await get_tree().create_timer(wait).timeout
	DirAccess.make_dir_recursive_absolute("user://shots")
	get_viewport().get_texture().get_image().save_png("user://shots/sv3_%s.png" % name)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Settings.reset_all()
	Profile.reset_all()
	SurvivorCards.seed_with(4)
	Survivor.start("warrior", "limestone")
	var bg := ColorRect.new()
	bg.color = Color(0.25, 0.3, 0.2)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var picker := CardPicker.new()
	add_child(picker)
	picker.offer("Choisis ton arme ou ta première compétence", SurvivorCards.first_offer(), func(): return SurvivorCards.first_offer())
	await _shot("premier_choix")
	picker._queue.clear()
	picker._show_next()
	Run.apply_card(SurvivorCards.weapon_card())
	Run.apply_card(SurvivorCards.spell_card(int(Run.class_data().skills[0].id)))
	Run.apply_card(SurvivorCards.new_piece_card("head"))
	Profile.equipped.head.upgrade = 4
	Run.hero_level = 14
	SurvivorCards.minutes_override = 7.0
	var cards: Array = [SurvivorCards.new_piece_card("chest"), SurvivorCards.up_card("head", "epic"),
		SurvivorCards.spell_up_card(int(Run.skills[0].id), "rare")]
	picker.offer("Niveau 14 ! Choisis une carte", cards, func(): return Run.roll_cards(3))
	await _shot("niveau")
	picker._queue.clear()
	picker._show_next()
	picker.offer("Coffre de torse : choisis une carte", SurvivorCards.chest_cards("sv_chest"), func(): return SurvivorCards.chest_cards("sv_chest"), 1)
	await _shot("coffre")
	picker._queue.clear()
	picker._show_next()
	Run.finish("abandon")
	Profile.end_run_survival()
	Profile.reset_all()
	get_tree().quit()
