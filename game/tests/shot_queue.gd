extends Node
## Captures des phases de la file d'attente du Duel (user://shots/queue_*.png).
## godot --path game res://tests/shot_queue.tscn


func _shot(name: String) -> void:
	await get_tree().create_timer(0.5).timeout
	DirAccess.make_dir_recursive_absolute("user://shots")
	get_viewport().get_texture().get_image().save_png("user://shots/queue_%s.png" % name)


func _ready() -> void:
	Settings.reset_all()
	Profile.reset_all()
	Duel.bare = true
	Duel.bare_level = 30
	var cid := Profile.selected_class
	var ids: Array = (GameData.class_data(cid).get("skills", []) as Array).slice(0, 4).map(func(x): return int(x.id))
	SpellPresets.store(cid, "shot", [[ids[0], 0, 0], [ids[1], 0, 0], [ids[2], 0, 0], [ids[3], 0, 0]])
	var bg := ColorRect.new()
	bg.color = Color(0.2, 0.3, 0.2)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var q := DuelQueue.open(self, "Duel libre", "Duel libre · à l'arme", "warrior", 30, 1, func(): pass)
	await get_tree().create_timer(1.2).timeout
	q._search_total = 99.0
	await _shot("1_search")
	q._enter(DuelQueue.Phase.FOUND)
	q._opp_accept_at = 0.1
	await _shot("2_found")
	q.accept()
	await get_tree().create_timer(0.3).timeout
	q._opp_lock_at = 999.0
	await _shot("3_draft")
	q.lock_in()
	q._enter(DuelQueue.Phase.RECAP)
	await _shot("4_recap")
	get_tree().quit()
