extends Node
## Entrée du jeu à la manette (lot U2) : l'accueil (3 écrans) et chaque onglet du Guide sont atteignables.
## godot --headless --path game res://tests/test_nav_entry.tscn

var fails := 0


func check(label: String, ok: bool) -> void:
	print(("OK    " if ok else "ÉCHEC ") + label)
	if not ok:
		fails += 1


func reach() -> Array:
	var all: Array = UiNav.candidates()
	if all.is_empty():
		return [0, 0]
	UiNav.cursor = null
	UiNav._last_center = Vector2.ZERO
	UiNav.pick_default()
	var seen := {UiNav.cursor: true}
	var todo: Array = [UiNav.cursor]
	while not todo.is_empty():
		var c: Control = todo.pop_back()
		for d in [Vector2.RIGHT, Vector2.LEFT, Vector2.DOWN, Vector2.UP]:
			UiNav.cursor = c
			if UiNav.move(d) and not seen.has(UiNav.cursor):
				seen[UiNav.cursor] = true
				todo.append(UiNav.cursor)
	return [seen.size(), all.size()]


func probe(label: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var r := reach()
	check("%s : %d / %d contrôles atteignables" % [label, r[0], r[1]], r[1] > 0 and float(r[0]) / float(r[1]) >= 0.9)


func _ready() -> void:
	Settings.reset_all()
	Profile.reset_all()
	Gamepad.active = true
	get_tree().root.size = Vector2i(1600, 900)
	var w := Welcome.new()
	add_child(w)
	await probe("accueil : 3 départs")
	w._step_class()
	await probe("accueil : classes")
	w._step_controls()
	await probe("accueil : contrôles")
	w.queue_free()
	Tutorial.set_mode("guided")
	var g := Guide.open_on(self, "commands")
	for i in Guide.CHAPTERS.size():
		g.show_page(i)
		await probe("Guide : %s" % Guide.CHAPTERS[i][1])
	g.close()
	await get_tree().process_frame
	print("TOUT EST OK (0 échec(s))" if fails == 0 else "ÉCHECS : %d" % fails)
	get_tree().quit(fails)
