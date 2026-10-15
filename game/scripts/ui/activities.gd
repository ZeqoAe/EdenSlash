class_name Activities
extends RefCounted
## Activités du menu Jouer (lobby) : étiquettes illustrées (écrans de chargement d'Eden,
## assets/ui/activities/), rangées en JcE et JcJ. Un clic ouvre la page de l'activité (ses
## réglages, puis Lancer) dans le même panneau. Les activités pas encore faites sont
## affichées « Bientôt » : leur page dit ce qui est prévu.

const IMG := "res://assets/ui/activities/%s.jpg"
const GROUPS := [["pve", "Aventure (JcE)"], ["pvp", "Affrontements (JcJ)"]]
## Rangées de la page Jouer (3 colonnes) : Aventure, Défis, Affrontements.
const ROWS := [["adventure", "Aventure"], ["challenge", "Défis"], ["versus", "Affrontements"]]
const LIST := [
	{"id": "survival", "row": "adventure", "group": "pve", "name": "Survie", "sub": "Horde, coffres et boss", "gain": "Maîtrise, insignes, pièces", "gives": ["piece", "mastery", "insignia", "stars"],
		"desc": "Explore la carte, tiens face à la horde, bats le boss."},
	{"id": "dungeon", "row": "adventure", "unlock": "dungeons", "group": "pve", "name": "Donjons", "sub": "Salles, boss et alliés IA", "gain": "Panoplies, plans, cristaux", "gives": ["panoply", "plan", "crystal", "fortify"],
		"desc": "Quatre salles, un boss."},
	{"id": "tower", "row": "adventure", "unlock": "tower", "group": "pve", "name": "La Tour", "sub": "200 étages, une seule vie", "gain": "Cristaux, gemmes, apparences", "gives": ["crystal", "gem", "look"],
		"desc": "Une carte et un coffre par étage, des duels de toutes les classes."},
	{"id": "mastery", "row": "challenge", "unlock": "daily", "img": "survival", "group": "pve", "name": "Défi de maîtrise", "sub": "Une Survie par jour", "gain": "Maîtrise ×2, insignes ×1,5", "gives": ["mastery", "insignia"],
		"desc": ""},
	{"id": "trials", "row": "challenge", "img": "training", "group": "pve", "name": "Épreuves de maîtrise", "sub": "Leçons chronométrées", "soon": true, "gain": "Médailles, maîtrise", "gives": ["mastery"],
		"desc": "Une leçon par famille de classes, au chrono : bronze, argent, or."},
	{"id": "rush", "row": "challenge", "unlock": "dungeons", "img": "dungeon", "group": "pve", "name": "Ruée des boss", "sub": "Les 8 boss à la suite", "gain": "Titres, cristaux, coffres", "gives": ["fortify", "stone", "crystal", "title"],
		"desc": "Les huit boss à la suite, une carte entre deux."},
	{"id": "siege", "row": "challenge", "unlock": "siege", "img": "arena3", "group": "pvp", "tag": "JcE + JcJ", "name": "Le Siège", "sub": "Vagues, boss, chacun pour soi", "gain": "Apparence légendaire, cristaux", "gives": ["formula", "crystal", "look"],
		"desc": "5 vagues, un boss, puis chacun pour soi. Le dernier debout gagne."},
	{"id": "duel", "row": "versus", "unlock": "duel_free", "group": "pvp", "name": "Duel", "sub": "1 contre 1, à l'arme ou équipé", "gain": "Rangs, titres, maîtrise", "gives": ["rank", "title", "mastery", "spirit"],
		"desc": "Un héros adverse, piloté par l'IA, à armes égales ou avec ton build."},
	{"id": "arenas", "row": "versus", "unlock": "arenas", "img": "arena2", "group": "pvp", "name": "Arènes", "sub": "2 contre 2 ou 3 contre 3", "gain": "Titres, maîtrise", "gives": ["title", "mastery", "insignia"],
		"desc": "Toi et tes alliés IA contre une équipe IA."},
	{"id": "royale", "row": "versus", "unlock": "royale", "img": "battlefield", "group": "pvp", "name": "Battle royale", "sub": "8 héros, un seul survivant", "gain": "Coffre d'apparence, titre, maîtrise", "gives": ["look", "title", "mastery"],
		"desc": ""},
	{"id": "training", "row": "", "group": "", "name": "Zone d'entraînement", "sub": "Sorts, armes et cartes, sans enjeu", "gain": "Rien (banc d'essai)",
		"desc": ""},
]


## Activité pas encore ouverte (fil d'éveil) : grisée, avec sa condition.
static func locked(a: Dictionary) -> bool:
	return a.has("unlock") and not Unlocks.is_open(String(a.unlock))


static func get_def(id: String) -> Dictionary:
	for a in LIST:
		if a.id == id:
			return a
	return {}


## Étiquette cliquable : l'illustration, un voile sombre en bas, le nom, le sous-titre et
## une pastille (JcE, JcJ, Bientôt).
static func card(a: Dictionary, size := Vector2(0, 118)) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = size
	b.clip_contents = true
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var soon: bool = a.get("soon", false) or locked(a)
	var n := UiTheme.flat_box(Color(0.08, 0.07, 0.16, 1.0), UiTheme.GOLD_DIM if not soon else Color(0.35, 0.32, 0.42), 2, 12)
	var hv := UiTheme.flat_box(Color(0.12, 0.1, 0.22, 1.0), Color(1, 0.92, 0.62), 3, 12)
	hv.shadow_color = Color(UiTheme.GOLD, 0.45)
	hv.shadow_size = 10
	b.add_theme_stylebox_override("normal", n)
	b.add_theme_stylebox_override("hover", hv)
	b.add_theme_stylebox_override("pressed", hv)
	_art(b, a, 0.86)
	if soon:
		var gray := ColorRect.new()
		gray.color = Color(0.05, 0.04, 0.1, 0.45)
		gray.set_anchors_preset(Control.PRESET_FULL_RECT)
		gray.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(gray)
	var tv := VBoxContainer.new()
	tv.set_anchors_preset(Control.PRESET_FULL_RECT)
	tv.offset_left = 16
	tv.offset_right = -30
	tv.offset_bottom = -10
	tv.alignment = BoxContainer.ALIGNMENT_END
	tv.add_theme_constant_override("separation", -2)
	tv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(tv)
	var t := Hud._label(tv, String(a.name), 22, Color(1, 0.98, 0.92) if not soon else Color(0.85, 0.83, 0.9))
	t.add_theme_font_override("font", UiTheme.bold_font())
	t.add_theme_constant_override("outline_size", 6)
	t.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	var is_locked := locked(a)  # grisée : le sous-titre dit comment l'ouvrir
	var st := Hud._label(tv, ("🔒 " + _short_condition(String(a.unlock))) if is_locked else String(a.sub), 13, Color(0.92, 0.9, 0.98, 0.95))
	if is_locked:
		st.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART  # la condition tient sur deux lignes plutôt que d'être coupée
	else:
		st.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	var tag := _tag(a)
	if tag != null:
		tag.position = Vector2(10, 10)
		b.add_child(tag)
	var gc := GainChips.icons(a, 18, soon)  # ce que l'activité donne : icônes seules, le détail au survol
	if gc != null:
		gc.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		gc.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		gc.offset_right = -8
		gc.offset_top = 8
		b.add_child(gc)
	var ch := Hud._label(b, "›", 34, Color(1, 0.98, 0.92, 0.9 if not soon else 0.4))
	ch.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	ch.offset_left = -26
	ch.offset_bottom = -8
	ch.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	return b


## Condition d'ouverture abrégée pour l'étiquette (jusqu'à la première virgule ou parenthèse) ; l'infobulle donne le détail.
static func _short_condition(id: String) -> String:
	var c := Unlocks.condition(id)
	for sep in [" (", ", "]:
		c = c.get_slice(sep, 0)
	return c.trim_suffix(".")


## Bandeau en tête de la page d'une activité : l'illustration et son nom.
static func banner(a: Dictionary) -> Control:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UiTheme.flat_box(Color(0.06, 0.05, 0.12, 1.0), UiTheme.GOLD_DIM, 2, 12))
	p.custom_minimum_size = Vector2(0, 150)
	p.clip_contents = true
	var holder := Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(holder)
	_art(holder, a, 0.9, 0.0)
	var tv := VBoxContainer.new()
	tv.set_anchors_preset(Control.PRESET_FULL_RECT)
	tv.offset_left = 14
	tv.offset_bottom = -8
	tv.alignment = BoxContainer.ALIGNMENT_END
	tv.add_theme_constant_override("separation", -2)
	tv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(tv)
	var t := Label.new()
	UiTheme.title(t, 30, Color(1, 0.95, 0.8))
	t.text = String(a.name)
	tv.add_child(t)
	Hud._label(tv, String(a.sub), 14, Color(0.95, 0.93, 1.0))
	var tag := _tag(a)
	if tag != null:
		tag.position = Vector2(10, 10)
		holder.add_child(tag)
	return p


static func _art(parent: Control, a: Dictionary, shade: float, inset := 3.0) -> void:
	var path := IMG % String(a.get("img", a.id))
	if ResourceLoader.exists(path):
		var img := TextureRect.new()
		img.texture = load(path)
		img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		img.set_anchors_preset(Control.PRESET_FULL_RECT)
		img.offset_left = inset
		img.offset_top = inset
		img.offset_right = -inset
		img.offset_bottom = -inset
		img.mouse_filter = Control.MOUSE_FILTER_IGNORE
		parent.add_child(img)
	var s := TextureRect.new()
	var g := GradientTexture2D.new()
	g.fill_from = Vector2(0, 0)
	g.fill_to = Vector2(0, 1)
	g.gradient = Gradient.new()
	g.gradient.set_color(0, Color(0, 0, 0, 0.0))
	g.gradient.add_point(0.45, Color(0.02, 0.02, 0.08, 0.15))
	g.gradient.set_color(g.gradient.get_point_count() - 1, Color(0.02, 0.02, 0.08, shade))
	s.texture = g
	s.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	s.stretch_mode = TextureRect.STRETCH_SCALE
	s.set_anchors_preset(Control.PRESET_FULL_RECT)
	s.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(s)


static func _tag(a: Dictionary) -> Control:
	var text := ""
	var col := UiTheme.GOLD
	if a.has("tag") and not a.get("soon", false):
		text = String(a.tag)
		col = Color(1.0, 0.75, 0.4)
	elif a.get("soon", false):
		text = "BIENTÔT"
		col = Color(0.75, 0.72, 0.85)
	elif a.group == "pve":
		text = "JcE"
		col = Color(0.55, 0.95, 0.6)
	elif a.group == "pvp":
		text = "JcJ"
		col = Color(1.0, 0.5, 0.45)
	else:
		return null
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UiTheme.flat_box(Color(0.03, 0.02, 0.07, 0.8), col, 1, 6))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := Hud._label(p, " %s " % text, 11, col)
	l.add_theme_font_override("font", UiTheme.bold_font())
	return p
