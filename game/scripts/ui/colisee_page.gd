class_name ColiseePage
extends RefCounted
## Page du Colisée dans le menu Jouer (lot CO-C : page minimale ; la page complète de l'étude ARENA § 6.11 — trio, alliés
## proposés, préréglage — vient au lot CO-G). De haut en bas : le mode en trois lignes, le format (Classique, Éclair, Grand
## tournoi : ouvert par la sonde de performances, R_CO_C.md), la difficulté des trios IA (Facile à Hardcore, Mélange),
## puis « Entrer au Colisée » épinglé. L'activité reste cachée du menu Jouer tant que Colisee.READY est faux (mode dev : visible).
## Construite par Lobby._show_menu("colisee") dans le panneau des pages (Lobby._sub) avec ses aides.

static var format := "classique"
static var diff := 1

const LINES := ["Six trios, une seule couronne : ton héros et deux alliés IA.", "Chaque manche, tous les trios se battent en même temps ; le perdant perd des PV d'équipe.",
	"L'anneau de feu se resserre : le dernier trio debout gagne."]
const FORMAT_TIPS := {"classique": "6 trios, une vingtaine de minutes.", "eclair": "4 trios, une douzaine de minutes.",
	"grand": "8 trios, une vingtaine de minutes."}
const DIFF_TIPS := ["Ils visent le plus proche et esquivent peu.", "Ils visent le plus faible.", "Ils lisent tes coups et se replient.",
	"Ils esquivent presque tout et ne laissent rien passer.", "Une difficulté par trio adverse."]


static func build(lb) -> void:
	lb._activity_head("colisee")
	for line in LINES:
		var l := Hud._label(lb._sub, "•  " + line, 15, UiTheme.TEXT)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lb._section("Format", "Le nombre de trios ; la partie s'arrête au plus tard à la 12e manche.")
	var row := _row(lb)
	for f in Colisee.FORMAT_ORDER:
		var locked := bool(Colisee.FORMATS[f].get("locked", false))
		var b := _chip(String(Colisee.FORMATS[f].name), f == format)
		b.disabled = locked
		Ico.lock(b, locked)
		b.tooltip_text = String(FORMAT_TIPS.get(f, ""))
		var ff := String(f)
		b.pressed.connect(func():
			format = ff
			lb._show_menu("colisee"))
		row.add_child(b)
	lb._section("Adversaires", "La force des trios IA ; tes deux alliés ont la même.")
	row = _row(lb)
	for k in Colisee.DIFFS.size():
		var b := _chip(String(Colisee.DIFFS[k]), k == diff, 14)
		b.tooltip_text = String(DIFF_TIPS[k])
		var kk := k
		b.pressed.connect(func():
			diff = kk
			lb._show_menu("colisee"))
		row.add_child(b)
	var dl := Hud._label(lb._sub, String(DIFF_TIPS[diff]), 15, UiTheme.MUTED)
	dl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var go := MenuWidgets.gold_button("Entrer au Colisée", 22, Vector2(0, 58))
	go.pressed.connect(func(): launch(lb))
	lb._pin_go(go, "")


## Lancement : partie scellée (Colisee.begin), puis la scène du monde (le directeur du combat monte la carte et les trios).
static func launch(lb) -> void:
	if lb._launching:
		return
	lb._launching = true
	if lb.backdrop:
		lb.backdrop.release()
	Colisee.begin(Profile.selected_class, format, diff)
	lb.get_tree().change_scene_to_file.call_deferred("res://scenes/world.tscn")


static func _chip(text: String, selected: bool, size := 15) -> Button:
	var b := MenuWidgets.glass_button(text, size, Vector2(0, 40))
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if selected:
		UiTheme.style_button(b, "lagon", size)
	return b


static func _row(lb) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	lb._sub.add_child(row)
	return row
