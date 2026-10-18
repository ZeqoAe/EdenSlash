class_name MobaPage
extends RefCounted
## Page des Deux Voies dans le menu Jouer (lot MB-H : page minimale ; le choix des postes et des héros de l'étude MOBA § 7.2,
## croquis v2_choix_heros.svg, la partie guidée et les récompenses viennent aux lots MB-I et MB-K). De haut en bas : le mode
## en trois lignes, ton poste (conseillé d'après la famille de ta classe), la difficulté des IA (les deux équipes), les touches
## du mode, puis « Entrer dans l'arène » épinglé. L'activité reste « Bientôt » (cachée du menu Jouer) tant que Moba.READY est
## faux ; Lobby._show_menu("moba") construit la page (tests, mode dev).

static var role := -1  # -1 : le poste conseillé de la classe
static var diff := 1

const LINES := ["Toi et trois alliés IA contre quatre héros IA, sur deux voies et une jungle.",
	"Les sbires avancent par vagues ; abats les tours, puis le Cœur adverse.",
	"Monte jusqu'au niveau 12, achète tes objets à la fontaine, prends le Gardien et le Colosse."]
const DIFFS := ["Facile", "Normal", "Difficile", "Hardcore"]
const DIFF_TIPS := ["Ils se placent mal et oublient de rentrer à la base.", "Ils suivent leur parcours et respectent les tours.",
	"Ils s'adaptent à ton équipe et préparent les objectifs.", "Ils ne laissent rien passer."]
const KEYS := "[P] boutique · [X] rappel · [Tab] scores · [Ctrl+1/2/3] enchaînement · [molette] repère"


static func build(lb) -> void:
	lb._activity_head("moba")
	for line in LINES:
		var l := Hud._label(lb._sub, "•  " + line, 15, UiTheme.TEXT)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var fam := int(GameData.class_data(Profile.selected_class).get("family", 1))
	var advised := MobaData.role_for_family(fam)
	var pick := advised if role < 0 else role
	lb._section("Ton poste", "Le poste conseillé suit la famille de ta classe ; tu peux en prendre un autre.")
	var row := _row(lb)
	for r in MobaData.ROLES.size():
		var e: Dictionary = MobaData.ROLES[r]
		var b := _chip(String(e.short) + (" ★" if r == advised else ""), r == pick, 14)
		b.tooltip_text = "%s%s" % [String(e.name), " · conseillé pour ta classe" if r == advised else ""]
		var rr := r
		b.pressed.connect(func():
			role = rr
			lb._show_menu("moba"))
		row.add_child(b)
	var pl := Hud._label(lb._sub, "%s · %s" % [String(MobaData.ROLES[pick].name), String(MobaData.ROLES[pick].short)], 15, UiTheme.MUTED)
	pl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lb._section("Adversaires", "La force des héros IA ; tes trois alliés ont la même.")
	row = _row(lb)
	for k in DIFFS.size():
		var b := _chip(String(DIFFS[k]), k == diff, 14)
		b.tooltip_text = String(DIFF_TIPS[k])
		var kk := k
		b.pressed.connect(func():
			diff = kk
			lb._show_menu("moba"))
		row.add_child(b)
	var dl := Hud._label(lb._sub, String(DIFF_TIPS[diff]), 15, UiTheme.MUTED)
	dl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var kl := Hud._label(lb._sub, KEYS, 14, UiTheme.MUTED)
	kl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var go := MenuWidgets.gold_button("Entrer dans l'arène", 22, Vector2(0, 58))
	go.pressed.connect(func(): launch(lb))
	lb._pin_go(go, "")


## Lancement : partie scellée (Moba.launch), puis la scène du monde par l'écran de chargement (règle PERF-1).
static func launch(lb) -> void:
	if lb._launching:
		return
	lb._launching = true
	if lb.backdrop:
		lb.backdrop.release()
	var o := {"diff": diff}
	if role >= 0:
		o["role"] = role
	Moba.launch(Profile.selected_class, o)
	LoadScreen.go(lb.get_tree(), "res://scenes/world.tscn")


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
