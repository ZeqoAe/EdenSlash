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
	# Survivant (conception/survivor) : sans verrou ni lien avec la progression, ouvert à tous (Survivor.READY, lot S8) ;
	# illustration provisoire : l'écran de la Survie retourné, au crépuscule (une image dédiée est à faire, session locale)
	{"id": "survivor", "row": "adventure", "img": "survivor", "group": "pve", "name": "Survivant", "sub": "Tout se gagne aux cartes", "gain": "Apparences, titres", "gives": ["look", "title"],
		"desc": "Vingt minutes, une carte : arme, pièces et sorts se gagnent aux cartes."},
	{"id": "dungeon", "row": "adventure", "unlock": "dungeons", "group": "pve", "name": "Donjons", "sub": "Choisis ton boss et ton butin", "gain": "Panoplies, plans, cristaux", "gives": ["panoply", "plan", "crystal", "fortify"],
		"desc": "Quatre salles, un boss."},
	{"id": "tower", "row": "adventure", "unlock": "tower", "group": "pve", "name": "La Tour", "sub": "200 étages, une seule vie", "gain": "Cristaux, gemmes, apparences", "gives": ["crystal", "gem", "look"],
		"desc": "Une carte et un coffre par étage, des duels de toutes les classes."},
	{"id": "quests", "row": "challenge", "unlock": "daily", "img": "training", "group": "pve", "tag": "Chaque jour", "name": "Quêtes", "sub": "Du jour, de la semaine et de classe", "gain": "Maîtrise, apparences", "gives": ["mastery", "look"],
		"desc": ""},
	{"id": "trials", "row": "challenge", "img": "training", "group": "pve", "name": "Épreuves de maîtrise", "sub": "Leçons chronométrées", "soon": true, "gain": "Médailles, maîtrise", "gives": ["mastery"],
		"desc": "Une leçon par famille de classes, au chrono : bronze, argent, or."},
	{"id": "rush", "row": "challenge", "unlock": "rush", "img": "dungeon", "group": "pve", "name": "Ruée des boss", "sub": "Les 8 boss à la suite", "gain": "Titres, cristaux, coffres", "gives": ["fortify", "stone", "crystal", "title"],
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


## Activité absente du menu Jouer : le Survivant s'il redevenait un chantier (Survivor.READY faux, hors mode dev).
static func hidden(a: Dictionary) -> bool:
	return String(a.get("id", "")) == "survivor" and not Survivor.visible()


## Sous-titre d'une étiquette : fixe, sauf les Quêtes (combien sont faites aujourd'hui).
static func sub_text(a: Dictionary) -> String:
	if String(a.get("id", "")) == "quests":
		var s := Quests.card_sub()
		return s if s != "" else String(a.sub)
	return String(a.sub)


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
	var lock: LockOverlay = null
	if soon:
		var gray := ColorRect.new()
		# verrouillée : l'image presque noire, un cadenas enchaîné au centre (retour du joueur, 15/10)
		gray.color = Color(0.03, 0.03, 0.06, 0.74) if locked(a) else Color(0.05, 0.04, 0.1, 0.45)
		gray.set_anchors_preset(Control.PRESET_FULL_RECT)
		gray.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(gray)
		if locked(a):
			lock = LockOverlay.new()
			b.add_child(lock)
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
	if lock != null:
		lock.title = t  # le cadenas se place au-dessus du nom
	var st := Hud._label(tv, _short_condition(String(a.unlock)) if is_locked else sub_text(a), 13, Color(0.92, 0.9, 0.98, 0.95))
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


## Activité verrouillée : un cadenas doré au centre sur deux bouts de chaîne en croix (dessinés, pas
## d'image), au-dessus du nom ; la condition d'ouverture reste écrite sous le nom.
class LockOverlay extends Control:
	const STEEL := Color(0.62, 0.62, 0.7, 0.9)
	const STEEL_DARK := Color(0.08, 0.08, 0.12, 0.9)
	var title: Control:  # nom de l'activité : le cadenas reste au-dessus, même si la condition tient sur deux lignes
		set(v):
			title = v
			v.item_rect_changed.connect(queue_redraw)

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_preset(Control.PRESET_FULL_RECT)

	func _notification(what: int) -> void:
		if what == NOTIFICATION_RESIZED:
			queue_redraw()

	func _draw() -> void:
		var k := clampf(size.y / 118.0, 0.7, 1.3) * 0.8  # taille du cadenas suivant la hauteur de l'étiquette
		var top := size.y * 0.5
		if is_instance_valid(title):
			top = title.get_global_rect().position.y - get_global_rect().position.y + 4.0
		var c := Vector2(size.x * 0.5, clampf(top - 17.0 * k, 16.0 * k, size.y * 0.32))
		var arm := Vector2(52, 17) * k / 0.8
		_chain(c - arm, c + arm)
		_chain(c + Vector2(arm.x, -arm.y), c + Vector2(-arm.x, arm.y))
		# anse du cadenas
		draw_arc(c + Vector2(0, -6) * k, 9.0 * k, PI, TAU, 18, STEEL_DARK, 7.0 * k, true)
		draw_arc(c + Vector2(0, -6) * k, 9.0 * k, PI, TAU, 18, Color(0.9, 0.78, 0.45), 4.0 * k, true)
		# corps et trou de serrure
		var body := Rect2(c + Vector2(-14, -7) * k, Vector2(28, 22) * k)
		draw_rect(body.grow(2.0 * k), STEEL_DARK)
		draw_rect(body, Color(0.93, 0.74, 0.3))
		draw_rect(Rect2(body.position, Vector2(body.size.x, 5.0 * k)), Color(1.0, 0.88, 0.55))
		draw_circle(c + Vector2(0, 2) * k, 3.2 * k, Color(0.16, 0.1, 0.04))
		draw_rect(Rect2(c + Vector2(-1.3, 2) * k, Vector2(2.6, 7) * k), Color(0.16, 0.1, 0.04))

	## Chaîne de [param a] à [param b] : maillons ovales qui se chevauchent, de face puis de profil.
	func _chain(a: Vector2, b: Vector2) -> void:
		var d := b - a
		var n := maxi(int(d.length() / 9.0), 2)
		var ang := d.angle()
		for i in n:
			var p := a + d * ((i + 0.5) / n)
			_link(p, ang, Vector2(7.0, 3.6) if i % 2 == 0 else Vector2(7.0, 1.2))

	func _link(p: Vector2, ang: float, r: Vector2) -> void:
		var pts := PackedVector2Array()
		for j in 17:
			var t := TAU * j / 16.0
			pts.append(p + Vector2(cos(t) * r.x, sin(t) * r.y).rotated(ang))
		draw_polyline(pts, STEEL_DARK, 4.0, true)
		draw_polyline(pts, STEEL, 2.0, true)
