class_name LoadScreen
extends CanvasLayer
## Écran de chargement commun (lot PERF-1) : TOUT changement de scène passe par [method go] (jamais d'écran figé sans retour).
## Dès l'appel : un voile d'encre sur l'écran courant et, au centre, un autocollant papier « Chargement » (pastilles qui
## sautent, barre de progression réelle, une astuce courte des fiches du tutoriel) ; curseur d'attente du système (il tourne
## même quand le jeu calcule). Déroulé, une étape par image pour que la barre avance :
##   1. la scène se charge en tâche de fond (ResourceLoader.load_threaded_request : la barre suit sa progression, l'animation
##      continue) ; un préchargement déjà lancé (titre -> lobby, lobby -> monde) est repris tel quel ;
##   2. étapes de préparation facultatives ([param steps] : [libellé, Callable], ex. le décor du lobby) ;
##   3. la scène est posée (change_scene_to_packed), puis le voile attend quelques images calmes avant de s'effacer.
## Le jeu est mis en pause pendant le chargement (l'ancienne scène ne joue plus) puis la pause d'avant revient au moment du
## changement : l'état vu par la nouvelle scène est celui qu'elle aurait eu sans écran de chargement. Pas d'annulation : les
## modes sont déjà lancés (Run, Duel…) quand le changement de scène est demandé. [member history] garde chaque chargement
## (chemin, durée, délai d'affichage) pour les mesures et test_perf1.

const LAYER := 120  # au-dessus de tout (version 100, choix de carte 20, fondu 90)
const CALM_MS := 60.0  # une image plus courte compte comme « calme »
const CALM_FRAMES := 3
const MAX_SETTLE := 6.0  # secondes au plus d'attente d'images calmes après le changement
const FADE := 0.18

static var current: LoadScreen = null
static var history: Array = []  # {path, ms, shown_ms, steps}

var path := ""
var steps: Array = []
var _bar: Control
var _fill := 0.0  # 0..1 affiché
var _label: Label
var _tip: Label
var _veil: ColorRect
var _card: Control
var _t0 := 0
var _shown_ms := -1.0
var _changed := false  # la scène a été changée (attente d'images calmes)


## Change de scène pour [param scene_path] derrière l'écran de chargement. [param steps] : préparations faites avant, une par
## image ([libellé, Callable]). Un deuxième appel pendant un chargement est ignoré (double clic).
static func go(tree: SceneTree, scene_path: String, p_steps: Array = []) -> void:
	if tree == null:
		return
	if current != null and is_instance_valid(current) and not current._changed:
		return  # (double clic pendant le chargement ; une demande pendant l'attente d'images calmes passe : nouvel écran)
	var ls := LoadScreen.new()
	ls.path = scene_path
	ls.steps = p_steps
	ls.name = "LoadScreen"
	current = ls
	tree.root.add_child.call_deferred(ls)
	ls.tree_entered.connect(ls._run, CONNECT_ONE_SHOT | CONNECT_DEFERRED)


## Retour au lobby (titre, bilans, abandon) : le décor de la zone et le catalogue de l'Atelier sont préparés chacun dans
## sa propre image avant la scène (sinon tout tombait dans la première image du lobby, plusieurs secondes d'un bloc).
static func to_lobby(tree: SceneTree) -> void:
	go(tree, LOBBY, [["Le décor de la zone…", MapBackdrop.prepare.bind(MapBackdrop.lobby_zone())],
		["L'Atelier…", func(): Completion.armory_ids()]])


const LOBBY := "res://scenes/lobby.tscn"


## Petit « Chargement… » pour un calcul long sur le fil principal (1re ouverture d'une page lourde : Collection, Roulette,
## Classe, page Donjons…) : la pastille est posée au centre puis l'image est dessinée TOUT DE SUITE (force_draw), avant le
## calcul ; l'écran figé montre donc le message. Rien si [param key] a déjà été vue par [param owner] (pages déjà bâties,
## rapides) ; renvoie le calque à passer à [method hint_done] (ou null). Le code appelant reste synchrone.
static func hint_first(owner: Node, key: String) -> CanvasLayer:
	if owner == null or not owner.is_inside_tree():
		return null
	var seen: Dictionary = owner.get_meta("perf1_seen", {})
	if seen.has(key):
		return null
	seen[key] = true
	owner.set_meta("perf1_seen", seen)
	return hint(owner)


static func hint(owner: Node, text := "Chargement…") -> CanvasLayer:
	var layer := CanvasLayer.new()
	layer.layer = LAYER
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	var box := UiTheme.StickerPanel.new("papier", 5.0)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.grow_vertical = Control.GROW_DIRECTION_BOTH
	var dots := UiTheme.Loading.new(text)
	(dots.get_child(1) as Label).add_theme_color_override("font_color", UiTheme.color("encre.700"))
	box.add_child(dots)
	layer.add_child(box)
	owner.get_tree().root.add_child(layer)
	DisplayServer.cursor_set_shape(DisplayServer.CURSOR_BUSY)
	if DisplayServer.get_name() != "headless":
		RenderingServer.force_draw(true, 0.0)  # (l'image avec la pastille est à l'écran avant le calcul)
	hint_count += 1
	return layer


static var hint_count := 0  # (mesures, test_perf1)


static func hint_done(layer: CanvasLayer) -> void:
	if layer != null and is_instance_valid(layer):
		layer.queue_free()
		DisplayServer.cursor_set_shape(DisplayServer.CURSOR_ARROW)


## Vrai pendant un chargement (le voile est affiché).
static func busy() -> bool:
	return current != null and is_instance_valid(current)


func _init() -> void:
	layer = LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS
	_t0 = Time.get_ticks_usec()
	_build()


func _build() -> void:
	_veil = ColorRect.new()
	_veil.color = Color(UiTheme.color("encre.900"), 0.88)
	_veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	_veil.mouse_filter = Control.MOUSE_FILTER_STOP  # aucun clic ne traverse pendant le chargement
	_veil.mouse_default_cursor_shape = Control.CURSOR_BUSY
	add_child(_veil)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_veil.add_child(center)
	var card := UiTheme.StickerPanel.new("papier", 7.0)
	card.custom_minimum_size = Vector2(500, 0)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card = card
	center.add_child(card)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(v)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 14)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(head)
	var dots := UiTheme.Loading.new("")
	dots.get_child(1).visible = false  # (la phrase est le titre à côté)
	head.add_child(dots)
	var title := Label.new()
	title.text = "Chargement"
	title.add_theme_font_override("font", UiTheme.title_font())
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", UiTheme.color("encre.700"))
	head.add_child(title)
	_bar = Control.new()
	_bar.custom_minimum_size = Vector2(0, 22)
	_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar.draw.connect(_paint_bar)
	v.add_child(_bar)
	_label = Label.new()
	_label.text = "Un instant…"
	_label.add_theme_font_override("font", UiTheme.label_font())
	_label.add_theme_font_size_override("font_size", 16)
	_label.add_theme_color_override("font_color", UiTheme.color("encre.300"))
	v.add_child(_label)
	var tip := tip_text()
	_tip = Label.new()
	_tip.text = tip
	_tip.visible = tip != ""
	_tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tip.custom_minimum_size = Vector2(460, 0)
	_tip.add_theme_font_override("font", UiTheme.body_font())
	_tip.add_theme_font_size_override("font_size", 15)
	_tip.add_theme_color_override("font_color", UiTheme.color("encre.700"))
	v.add_child(_tip)


## Une astuce courte au hasard (fiches du tutoriel, champ « short »).
static func tip_text() -> String:
	var pool: Array = []
	for k in Tutorial.CARDS:
		var s := String(Tutorial.CARDS[k].get("short", ""))
		if s != "" and s.length() <= 125:
			pool.append(s)
	return "Astuce : " + String(pool.pick_random()) if not pool.is_empty() else ""


func _paint_bar() -> void:
	var r := Rect2(Vector2.ZERO, _bar.size)
	var ink := UiTheme.color("encre.700")
	var track := StyleBoxFlat.new()
	track.bg_color = UiTheme.color("papier.300")
	track.set_corner_radius_all(11)
	track.set_border_width_all(3)
	track.border_color = ink
	track.draw(_bar.get_canvas_item(), r)
	if _fill > 0.0:
		var f := StyleBoxFlat.new()
		f.bg_color = UiTheme.color("bonbon.soleil.base")
		f.set_corner_radius_all(8)
		var inner := r.grow(-4.0)
		inner.size.x = maxf(inner.size.y, inner.size.x * clampf(_fill, 0.0, 1.0))
		f.draw(_bar.get_canvas_item(), inner)
		var gloss := Rect2(inner.position + Vector2(6, 2), Vector2(maxf(inner.size.x - 12.0, 0.0), 3))
		_bar.draw_rect(gloss, Color(1, 1, 1, 0.45))


func set_progress(p: float, text := "") -> void:
	_fill = maxf(_fill, clampf(p, 0.0, 1.0))  # la barre ne recule jamais
	if text != "":
		_label.text = text
	_bar.queue_redraw()


## Attend que l'image courante soit affichée (les images suivantes la montrent à l'écran).
func _shown() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	if _shown_ms < 0.0:
		_shown_ms = float(Time.get_ticks_usec() - _t0) / 1000.0


func _input(event: InputEvent) -> void:
	# rien ne passe à la scène pendant le chargement (touches, manette), sauf les relâchements (pas de touche coincée)
	if event.is_pressed():
		get_viewport().set_input_as_handled()


func _run() -> void:
	var tree := get_tree()
	var was_paused := tree.paused
	tree.paused = true
	Input.set_default_cursor_shape(Input.CURSOR_BUSY)
	set_progress(0.04, "Un instant…")
	await _shown()
	# 1. la scène, en tâche de fond
	var packed: PackedScene = null
	if ResourceLoader.exists(path):
		if ResourceLoader.load_threaded_get_status(path) == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			ResourceLoader.load_threaded_request(path)
		var prog := []
		while true:
			var st := ResourceLoader.load_threaded_get_status(path, prog)
			if st != ResourceLoader.THREAD_LOAD_IN_PROGRESS:
				break
			set_progress(0.05 + 0.45 * float(prog[0] if not prog.is_empty() else 0.0))
			await tree.process_frame
		packed = ResourceLoader.load_threaded_get(path) as PackedScene
	set_progress(0.5)
	# 2. préparations (une par image, la barre avance entre deux)
	var n := steps.size()
	for i in n:
		var st_label := String(steps[i][0])
		set_progress(0.5 + 0.35 * float(i) / float(maxi(n, 1)), st_label)
		await _shown()
		var c: Callable = steps[i][1]
		if c.is_valid():
			c.call()
	# 3. la scène posée
	set_progress(0.88, "Mise en place…")
	await _shown()
	var old := tree.current_scene
	tree.paused = was_paused
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	_changed = true
	if packed != null:
		tree.change_scene_to_packed(packed)
	else:
		tree.change_scene_to_file(path)  # (scène introuvable en tâche de fond : chargement direct, l'erreur du moteur reste visible)
	# attente : la nouvelle scène en place, puis quelques images calmes (premières images : shaders, physique)
	var t_wait := 0.0
	var calm := 0
	var last := Time.get_ticks_usec()
	while t_wait < MAX_SETTLE and current == self:
		await tree.process_frame
		var now := Time.get_ticks_usec()
		var ms := float(now - last) / 1000.0
		last = now
		t_wait += ms / 1000.0
		if tree.current_scene == old or tree.current_scene == null:
			continue
		calm = calm + 1 if ms < CALM_MS else 0
		set_progress(minf(0.88 + 0.04 * float(calm), 1.0))
		if calm >= CALM_FRAMES:
			break
	set_progress(1.0)
	history.append({"path": path, "ms": float(Time.get_ticks_usec() - _t0) / 1000.0, "shown_ms": _shown_ms, "steps": n})
	if history.size() > 64:
		history.pop_front()
	if current == self:
		current = null  # (une demande suivante peut déjà ouvrir son propre écran)
	var tw := create_tween()
	tw.tween_property(_veil, "modulate:a", 0.0, FADE)
	tw.tween_callback(queue_free)
	if path == LOBBY:
		ProcMap.warm_models()  # modèles de décor des cartes déjà jouées : en tâche de fond pendant que le joueur choisit

