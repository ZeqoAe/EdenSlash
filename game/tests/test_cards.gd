extends Node
## Choix de cartes en un seul geste : un clic (ou 1, 2, 3) choisit, sauf pendant le délai anti-rafale.
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


## Attend la fin du délai anti-rafale (temps réel, pas le temps de jeu).
func _wait_delay(picker: CardPicker) -> void:
	var until := picker._opened_at + CardPicker.CONFIRM_DELAY_MS + 50
	while Time.get_ticks_msec() < until:
		await get_tree().process_frame
	await get_tree().process_frame


func _gear_card(name: String, lines: String) -> Dictionary:
	return {"type": "gear", "id": name, "title": name, "subtitle": "Torse", "desc": lines, "icon": "",
		"item": {"slot": "chest", "uid": name}, "color": Color.WHITE}


func _ready() -> void:
	Run.start("samurai")
	var picker := CardPicker.new()
	add_child(picker)
	var got: Array = []
	picker.picked.connect(func(c): got.append(c))

	picker.offer("Test", Run.roll_cards(3, true))
	picker.offer("Test 2", Run.roll_cards(3, true))
	check("ouvert et jeu en pause", picker.is_open() and get_tree().paused)
	check("plus de bouton Valider", not "_confirm" in picker and not picker.has_method("_confirm_choice"))
	check("cartes voilées pendant le délai", picker._row.modulate.a < 1.0)

	picker._buttons[0].pressed.emit()
	check("clic pendant le délai anti-rafale : ignoré", got.is_empty() and picker.is_open())
	picker._unhandled_input(_key(KEY_1))
	check("touche 1 pendant le délai : ignorée", got.is_empty())

	await _wait_delay(picker)
	check("cartes nettes après le délai", is_equal_approx(picker._row.modulate.a, 1.0))
	var first_cards: Array = picker._cards
	picker._buttons[2].pressed.emit()
	check("un clic choisit la carte", got.size() == 1 and got[0] == first_cards[2])
	check("choix suivant affiché, de nouveau voilé", picker.is_open() and picker._row.modulate.a < 1.0)

	await _wait_delay(picker)
	var expected: Dictionary = picker._cards[1]
	picker._unhandled_input(_key(KEY_2))
	check("touche 2 choisit la carte", got.size() == 2 and got[1] == expected)
	check("fermé et jeu repris", not picker.is_open() and not get_tree().paused)

	# équipement : les lignes communes sont dites une fois, six statistiques réduites à quatre
	var a := _gear_card("A", "[color=#7dff8a]Emplacement libre[/color]\n+4 Force\n+4 Agilité\n+4 Chance\n+45 PV\n+3 % Esquive\n+6 % Vitesse")
	var b := _gear_card("B", "[color=#7dff8a]Emplacement libre[/color]\n+9 Défense\n+4 Intelligence")
	var d := picker._descriptions([a, b])
	check("ligne commune dite une fois", String(d.shared) == "[color=#7dff8a]Emplacement libre[/color]" and not String(d.each[0]).contains("Emplacement"))
	check("une pièce : quatre statistiques au plus", String(d.each[0]).split("\n").size() == 4 and String(d.each[1]).contains("Défense"))
	var same := picker._descriptions([_gear_card("C", "+3 Force\n+3 Agilité"), _gear_card("D", "+3 Force\n+3 Agilité")])
	check("deux cartes identiques : tout est commun", String(same.each[0]) == "" and String(same.shared).contains("+3 Force"))
	var spells := picker._descriptions([{"desc": "niv. 0 → 1"}, {"desc": "niv. 0 → 1"}])
	check("cartes de sort : textes intacts", String(spells.each[0]) == "niv. 0 → 1" and String(spells.shared) == "")

	print("\n%s (%d échec(s))" % ["TOUT EST OK" if fails == 0 else "ÉCHECS", fails])
	get_tree().quit(1 if fails > 0 else 0)
