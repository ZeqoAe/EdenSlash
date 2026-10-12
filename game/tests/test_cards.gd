extends Node
## Choix de cartes : cliquer une carte la sélectionne, seul « Valider » (ou Entrée) confirme.
## godot --headless --path game res://tests/test_cards.tscn

var fails := 0


func check(label: String, ok: bool) -> void:
	print(("OK    " if ok else "ÉCHEC ") + label)
	if not ok:
		fails += 1


func _key(code: Key) -> InputEventKey:
	var e := InputEventKey.new()
	e.physical_keycode = code
	e.pressed = true
	return e


func _ready() -> void:
	Run.start("samurai")
	var picker := CardPicker.new()
	add_child(picker)
	var got: Array = []
	picker.picked.connect(func(c): got.append(c))

	picker.offer("Test", Run.roll_cards(3, true))
	picker.offer("Test 2", Run.roll_cards(3, true))
	check("ouvert et jeu en pause", picker.is_open() and get_tree().paused)
	check("Valider inactif sans sélection", picker._confirm.disabled)

	picker._buttons[0].pressed.emit()
	check("clic sur une carte : sélection seulement", got.is_empty() and picker.is_open() and picker._selected == 0)
	picker._confirm_choice()
	check("Valider ignoré pendant le délai anti-rafale", got.is_empty())

	await get_tree().create_timer(0.5, true, false, true).timeout
	check("Valider actif après le délai", not picker._confirm.disabled)
	var first_cards: Array = picker._cards
	picker._buttons[2].pressed.emit()
	picker._confirm.pressed.emit()
	check("Valider confirme la carte sélectionnée", got.size() == 1 and got[0] == first_cards[2])
	check("choix suivant affiché, rien de sélectionné", picker.is_open() and picker._selected == -1 and picker._confirm.disabled)

	await get_tree().create_timer(0.5, true, false, true).timeout
	picker._unhandled_input(_key(KEY_2))
	check("touche 2 : sélection seulement", got.size() == 1 and picker._selected == 1)
	var expected: Dictionary = picker._cards[1]
	picker._unhandled_input(_key(KEY_ENTER))
	check("Entrée confirme", got.size() == 2 and got[1] == expected)
	check("fermé et jeu repris", not picker.is_open() and not get_tree().paused)

	print("\n%s (%d échec(s))" % ["TOUT EST OK" if fails == 0 else "ÉCHECS", fails])
	get_tree().quit(1 if fails > 0 else 0)
