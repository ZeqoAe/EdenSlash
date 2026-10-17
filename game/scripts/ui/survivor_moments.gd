class_name SurvivorMoments
extends Control
## Moments manga du Survivant (lot SVX-2, BIBLE v2 § 7-8, BM-SURV § 7.3) : sur un événement seulement, jamais au repos.
##   - montée de niveau : onomatopée « Niveau ! » au-dessus du héros (600 ms, Mochiy contourée, inclinée −3°), « shing » ;
##   - évolution prise : traits de vitesse, « Évolution ! » puis son nom en Mochiy 44, confettis des 5 bonbons (1,2 s) ;
##   - boss : « Le boss ! » à traits de vitesse, son grave ; gardien vaincu, jet parfait… : onomatopée courte.
## Son (Sfx.ui) et vibration de la manette (réglage « Vibration manette » de UiFeel ; jamais pendant un télégraphe : les
## moments arrivent en pause de carte ou à l'entrée de l'arène). « Réduire les animations » : ni échelle, ni traits, ni
## confettis ; le texte, le son et la vibration restent. Un seul moment plein écran à la fois, les onomatopées s'empilent.

const POP_LIFE := 0.6
const BANNER_LIFE := 1.6
const RAYS := 30
## Vibrations (faible, fort, durée s), comme UiFeel.VIB.
const VIB := {"level": [0.25, 0.1, 0.06], "evolution": [0.3, 0.45, 0.18], "boss": [0.2, 0.5, 0.25], "small": [0.15, 0.0, 0.05]}

var player: Player
var hud: Hud
## Effets en cours : {kind ("pop" | "banner"), age, life, text, sub, pos, color}.
var items: Array = []


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS


## Montée de niveau : « Niveau ! » au-dessus du héros.
func level_up(_lvl: int) -> void:
	pop("Niveau !", UiTheme.color("bonbon.soleil.base"))
	Sfx.ui("ui_primary", -10.0, 1.3)
	_vibrate("level")


## Onomatopée courte au-dessus du héros ([param color] : couleur du texte, contour d'encre).
func pop(text: String, color := Color.WHITE) -> void:
	var stack := items.filter(func(e): return String(e.kind) == "pop").size()  # empilées, jamais superposées
	items.append({"kind": "pop", "age": 0.0, "life": POP_LIFE, "text": text, "color": color, "row": stack})
	queue_redraw()


## Évolution prise : bannière à traits de vitesse et confettis.
func evolution(name: String) -> void:
	_banner("Évolution !", name, UiTheme.color("bonbon.amethyste.base"))
	Sfx.ui("level_up", -4.0, 1.1)
	_vibrate("evolution")
	if not UiFeel.reduce_motion:
		UiFeel.confetti(get_global_transform_with_canvas() * (size * Vector2(0.5, 0.36)), 24)


## Le boss entre en scène.
func boss(name: String) -> void:
	_banner("Le boss !", name, UiTheme.color("bonbon.fraise.base"))
	Sfx.ui("rock", -2.0, 0.6)
	_vibrate("boss")


func _banner(head: String, sub: String, color: Color) -> void:
	if hud != null and is_instance_valid(hud):
		hud.hide_banner()  # un seul texte au centre à la fois
	items = items.filter(func(e): return String(e.kind) != "banner")
	items.append({"kind": "banner", "age": 0.0, "life": BANNER_LIFE, "text": head, "sub": sub, "color": color})
	queue_redraw()


func _vibrate(kind: String) -> void:
	if not UiFeel.vibration or not Gamepad.active or not VIB.has(kind):
		return
	var pads := Input.get_connected_joypads()
	if pads.is_empty():
		return
	var v: Array = VIB[kind]
	Input.start_joy_vibration(int(pads[0]), float(v[0]), float(v[1]), float(v[2]))


func _process(delta: float) -> void:
	if items.is_empty():
		return
	for e in items:
		e.age = float(e.age) + delta
	items = items.filter(func(e): return float(e.age) < float(e.life))
	queue_redraw()


## Point de l'écran au-dessus du héros (coordonnées de ce contrôle).
func hero_point() -> Vector2:
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	if player == null or not is_instance_valid(player) or cam == null:
		return size * Vector2(0.5, 0.42)
	var p3 := player.global_position + Vector3.UP * 2.4
	if -cam.global_transform.basis.z.dot(p3 - cam.global_position) <= 0.05:
		return size * Vector2(0.5, 0.42)  # (caméra pas encore placée : le héros est dans son plan)
	var p := cam.unproject_position(p3)
	return get_global_transform_with_canvas().affine_inverse() * p


func _draw() -> void:
	var calm := UiFeel.reduce_motion
	var ink := UiTheme.color("encre.700")
	for e in items:
		var k := float(e.age) / float(e.life)
		if String(e.kind) == "pop":
			# 0 → 0,15 : ressort 0,6 → 1,1 → 1 ; monte de 22 px ; fondu dans le dernier tiers
			var sc := 1.0 if calm else (lerpf(0.6, 1.1, k / 0.15) if k < 0.15 else lerpf(1.1, 1.0, clampf((k - 0.15) / 0.15, 0.0, 1.0)))
			var a := 1.0 if k < 0.66 else 1.0 - (k - 0.66) / 0.34
			var p := hero_point() + Vector2(0, -22.0 * k - 34.0 * int(e.row))
			_text(String(e.text), p, 30, Color(e.color, a), Color(ink, a), sc, -3.0)
		else:
			var a2 := clampf(k / 0.1, 0.0, 1.0) * (1.0 if k < 0.75 else 1.0 - (k - 0.75) / 0.25)
			var c := size * Vector2(0.5, 0.36)
			# bande d'encre douce derrière le texte (lisible sur le monde clair), puis traits de vitesse
			draw_rect(Rect2(0, c.y - 78.0, size.x, 128.0), Color(ink, 0.32 * a2))
			if not calm:
				_rays(c, k, a2)
			var sc2 := 1.0 if calm else (lerpf(0.7, 1.08, k / 0.12) if k < 0.12 else lerpf(1.08, 1.0, clampf((k - 0.12) / 0.2, 0.0, 1.0)))
			_text(String(e.text), c + Vector2(0, -44), 28, Color(UiTheme.color("bonbon.soleil.base"), a2), Color(ink, a2), sc2, -3.0)
			_text(String(e.sub), c + Vector2(0, 14), 44, Color(e.color.lightened(0.55), a2), Color(ink, a2), sc2, -3.0)


## Traits de vitesse : rayons blancs fins depuis [param c] (1,6 s puis disparaissent).
func _rays(c: Vector2, k: float, a: float) -> void:
	var r0 := 150.0 + 60.0 * k
	for i in RAYS:
		var ang := TAU * float(i) / float(RAYS) + 0.11 * sin(float(i) * 7.3)
		var len := 140.0 + 90.0 * absf(sin(float(i) * 3.1))
		var d := Vector2(cos(ang), sin(ang) * 0.55)
		draw_line(c + d * r0, c + d * (r0 + len), Color(1, 1, 1, 0.8 * a), 3.0 if i % 3 == 0 else 1.8, true)


## Texte Mochiy contouré d'encre, centré sur [param p], incliné de [param deg] degrés.
func _text(t: String, p: Vector2, fs: int, col: Color, ink: Color, sc: float, deg: float) -> void:
	if t == "":
		return
	var font := UiTheme.title_font()
	var w := font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_set_transform(p, deg_to_rad(deg), Vector2.ONE * sc)
	var at := Vector2(-w * 0.5, fs * 0.35)
	draw_string_outline(font, at, t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UiTheme.outline_for(fs) + 3, ink)
	draw_string(font, at, t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
