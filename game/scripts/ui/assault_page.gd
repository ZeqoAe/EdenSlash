class_name AssaultPage
extends RefCounted
## Page de L'Assaut dans le menu Jouer (lot TAC-8, TACTIQUE § 7.11) : le mode en trois lignes, le format (Classique : premier à
## 7 ; Éclair : premier à 4), la difficulté de l'équipe adverse et celle de tes alliés (Facile, Normal, Difficile, Expert), la
## carte (le Bourg aux lanternes ; le Pont et le Temple viendront), ta classe, ce qu'une victoire donne (coffres d'apparence,
## titres : AssaultRewards), puis « Lancer l'Assaut » épinglé. L'activité reste cachée du menu Jouer tant qu'Assault.READY est
## faux (mode dev : visible). Construite par Lobby._show_menu("assault") dans le panneau des pages (Lobby._sub).

static var format := "assault"
static var diff_foes := 1
static var diff_allies := 1
static var map_id := "bourg"

const LINES := ["Quatre contre quatre : toi et trois alliés IA contre quatre IA.", "L'Attaque pose la Charge sur un site ; la Défense l'en empêche ou la désamorce.",
	"Une seule vie par manche ; de l'or entre les manches pour acheter sorts, armes et utilitaires."]
const FORMATS := [["assault", "Classique", "Premier à 7 manches, une vingtaine de minutes."], ["eclair", "Éclair", "Premier à 4 manches, une dizaine de minutes."]]
const MAPS := [["bourg", "Le Bourg aux lanternes", true], ["pont", "Le Pont des brumes", false], ["temple", "Le Temple de cristal", false]]
const DIFF_TIPS := ["Ils réagissent lentement et foncent souvent.", "Ils jouent leur rôle et achètent bien.",
	"Ils se coordonnent, tournent sur information et reprennent les sites.", "Ils jouent le temps, feintent et punissent la moindre erreur."]


static func build(lb) -> void:
	lb._activity_head("assault")
	for line in LINES:
		var l := Hud._label(lb._sub, "•  " + line, 15, UiTheme.TEXT)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lb._section("Format", "La longueur de la partie ; mi-temps et changement de côté à la moitié.")
	var row := _row(lb)
	for f in FORMATS:
		var b := _chip(String(f[1]), String(f[0]) == format)
		b.name = "AssaultFormat_" + String(f[0])
		b.tooltip_text = String(f[2])
		var ff := String(f[0])
		b.pressed.connect(func():
			format = ff
			lb._show_menu("assault"))
		row.add_child(b)
	lb._section("Adversaires", "La force de l'équipe adverse ; le coffre de la victoire en dépend.")
	row = _row(lb)
	for k in AssaultRewards.DIFFS.size():
		var b := _chip(String(AssaultRewards.DIFFS[k]), k == diff_foes, 14)
		b.name = "AssaultFoes_%d" % k
		b.tooltip_text = String(DIFF_TIPS[k])
		var kk := k
		b.pressed.connect(func():
			diff_foes = kk
			lb._show_menu("assault"))
		row.add_child(b)
	var dl := Hud._label(lb._sub, String(DIFF_TIPS[diff_foes]), 15, UiTheme.MUTED)
	dl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lb._section("Tes alliés", "La force de tes trois alliés IA.")
	row = _row(lb)
	for k in AssaultRewards.DIFFS.size():
		var b := _chip(String(AssaultRewards.DIFFS[k]), k == diff_allies, 14)
		b.name = "AssaultAllies_%d" % k
		var kk := k
		b.pressed.connect(func():
			diff_allies = kk
			lb._show_menu("assault"))
		row.add_child(b)
	lb._section("Carte")
	row = _row(lb)
	for m in MAPS:
		var b := _chip(String(m[1]), String(m[0]) == map_id, 14)
		b.name = "AssaultMap_" + String(m[0])
		b.disabled = not bool(m[2])
		Ico.lock(b, not bool(m[2]))
		b.tooltip_text = "Bientôt" if not bool(m[2]) else "Deux sites, une place, des maisons : la carte d'apprentissage."
		var mm := String(m[0])
		b.pressed.connect(func():
			map_id = mm
			lb._show_menu("assault"))
		row.add_child(b)
	var cid := String(Profile.selected_class)
	var cl := Hud._label(lb._sub, "Ta classe : %s · %s" % [String(GameData.class_data(cid).get("name_fr", cid)),
		AssaultCombat.role_name(AssaultCombat.role_of_class(cid))], 15, UiTheme.TEXT)
	cl.tooltip_text = "Change de classe dans Héros. Dans ce mode, rien de ton compte ne compte : même niveau et même arme pour tous."
	cl.mouse_filter = Control.MOUSE_FILTER_STOP
	lb._section("Récompenses", "Apparences et titres seulement : rien de ton compte ne change dans ce mode.")
	var p := AssaultRewards.plan(diff_foes, format == "eclair")
	var chest_txt := "Victoire : %s" % String(Rewards.TYPES.get(String(p.type), {}).get("name", "plus de coffre aujourd'hui"))
	if String(p.kind) == "first":
		chest_txt += " (première victoire en %s)" % AssaultRewards.diff_name(diff_foes)
	elif String(p.kind) == "daily":
		chest_txt += " · encore %d aujourd'hui" % int(p.left)
	var rl := Hud._label(lb._sub, chest_txt, 15, UiTheme.TEXT)
	rl.name = "AssaultReward"
	rl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var titles: Array = []
	for e in AssaultRewards.board():
		titles.append(("✔ " if bool(e.done) else "") + "« %s » : %s" % [String(e.title), String(e.text).left(1).to_lower() + String(e.text).substr(1)])
	var tl := Hud._label(lb._sub, "Titres : " + " · ".join(titles), 15, UiTheme.MUTED)
	tl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var go := MenuWidgets.gold_button("Lancer l'Assaut", 22, Vector2(0, 58))
	go.name = "AssaultGo"
	go.pressed.connect(func(): launch(lb))
	lb._pin_go(go, "")


## Options de la partie choisies sur la page.
static func options() -> Dictionary:
	return {"map": map_id, "format": format, "diff_allies": diff_allies, "diff_foes": diff_foes}


## Lancement : partie scellée (Assault.launch), puis la scène du monde (AssaultDirector monte la carte et les 8 héros).
static func launch(lb) -> void:
	if lb._launching:
		return
	lb._launching = true
	if lb.backdrop:
		lb.backdrop.release()
	Assault.launch(Profile.selected_class, options())
	LoadScreen.go(lb.get_tree(), "res://scenes/world.tscn")  # (lot PERF-1 : écran de chargement)


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
