class_name Minimap
extends Control
## Mini-carte de la map générée : rendu du terrain, brouillard de guerre,
## lieux découverts, monstres, chemin vers le donjon. Grande carte avec [M].

const ICONS := {
	"merchant": Color(1.0, 1.0, 1.0),
	"dungeon": Color(0.85, 0.35, 1.0),
	"chest": Color(1.0, 0.85, 0.3),
	"shrine": Color(0.55, 1.0, 0.6),
	"anvil": Color(1.0, 0.6, 0.3),
	"scribe": Color(0.6, 0.75, 1.0),
	"well": Color(0.5, 1.0, 0.7),
	"magnet": Color(0.3, 1.0, 0.95),
	"greed": Color(1.0, 0.82, 0.3),
	"challenge": Color(1.0, 0.35, 0.3),
	"chest1": Color(1.0, 0.45, 0.35),
	"chest2": Color(1.0, 0.95, 0.4),
	"fort": Color(1.0, 0.35, 0.25),
}
## Légende de la grande carte : [type, nom].
const LEGEND := [["dungeon", "Donjon"], ["merchant", "Marchand"], ["shrine", "Sanctuaire"], ["fort", "Fort d'élite (sceau)"],
	["chest", "Coffre"], ["chest1", "Coffre ouvragé"], ["chest2", "Coffre doré"], ["anvil", "Enclume"], ["scribe", "Autel du scribe"],
	["well", "Fontaine de vie"], ["magnet", "Pierre d'aimant"], ["greed", "Autel de cupidité"], ["challenge", "Stèle du défi"]]

var player: Player
var director: RunDirector
var big := false
var round := false  # mini-carte ronde (découpée par son parent, voir Hud)
var zoom := 2.0  # pixels écran par mètre (mini-carte)


func setup(p: Player, d: RunDirector) -> void:
	player = p
	director = d
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true


func _process(_delta: float) -> void:
	if is_visible_in_tree():
		queue_redraw()


func _draw() -> void:
	if player == null or director == null or director.map == null or not director.map.has_method("minimap_info"):
		return
	var info: Dictionary = director.map.minimap_info()
	var tex: Texture2D = info.texture
	var ppm: float = info.ppm  # pixels de l'image par mètre
	var c := size * 0.5
	var cam := get_viewport().get_camera_3d()
	var yaw := cam.global_rotation.y if cam and not big else 0.0
	var scale_ := zoom / ppm
	var center_img := Vector2(player.global_position.x, player.global_position.z) * ppm
	if big:
		scale_ = minf(size.x, size.y) / tex.get_width()
		center_img = Vector2(tex.get_width(), tex.get_height()) * 0.5
	# repère : image -> écran (rotation selon la caméra sur la mini-carte)
	var xf := Transform2D(yaw, c) * Transform2D(0.0, Vector2.ONE * scale_, 0.0, Vector2.ZERO) * Transform2D(0.0, -center_img)
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.05, 0.05, 0.08, 0.92))
	draw_set_transform_matrix(xf)
	draw_texture(tex, Vector2.ZERO)
	var fog: Texture2D = director.fog_texture()
	if fog:
		draw_texture_rect(fog, Rect2(Vector2.ZERO, Vector2(tex.get_width(), tex.get_height())), false, Color(0.05, 0.05, 0.08, 1.0))
	draw_set_transform_matrix(Transform2D.IDENTITY)

	var w2s := func(p: Vector3) -> Vector2: return xf * (Vector2(p.x, p.z) * ppm)
	# chemin vers le donjon
	for p in director.route:
		var sp: Vector2 = w2s.call(p)
		if _inside(sp):
			draw_circle(sp, 1.8, Color(1.0, 0.85, 0.35, 0.9))
	# lieux connus
	for m in director.markers():
		var sp: Vector2 = w2s.call(m[0])
		var col: Color = ICONS.get(m[1], Color.WHITE)
		if not _inside(sp):
			if String(m[1]).begins_with("chest"):
				continue
			sp = _clamp_edge(sp, c)  # marchands, sanctuaires, donjon : au bord dans la bonne direction
		if String(m[1]).begins_with("chest"):
			var r := 3.0 + (1.5 if m[1] != "chest" else 0.0)
			draw_rect(Rect2(sp - Vector2(r, r), Vector2(r, r) * 2.0), col)
		elif m[1] == "shrine":
			draw_arc(sp, 6.0, 0.0, TAU, 20, Color(0, 0, 0, 0.6), 3.5)
			draw_arc(sp, 6.0, 0.0, TAU, 20, col, 2.0)
		elif m[1] == "fort":
			_diamond(sp, 7.5, Color(0, 0, 0, 0.6))
			_diamond(sp, 6.0, col)
		else:
			draw_circle(sp, 7.0, Color(0, 0, 0, 0.6))
			draw_circle(sp, 5.5, col)
	# monstres
	for node in get_tree().get_nodes_in_group("monsters"):
		var mo := node as Monster
		var sp: Vector2 = w2s.call(mo.global_position)
		if not _inside(sp):
			continue
		if mo.is_boss:
			draw_circle(sp, 5.5, Color(0.8, 0.3, 1.0))
		elif mo.is_elite:
			draw_circle(sp, 4.0, Color(1.0, 0.6, 0.15))
		else:
			draw_circle(sp, 2.3, Color(0.95, 0.25, 0.25))
	# héros
	var hp: Vector2 = w2s.call(player.global_position)
	var f := player.forward()
	var dir := xf.basis_xform(Vector2(f.x, f.z)).normalized()
	var side := Vector2(-dir.y, dir.x)
	draw_colored_polygon(PackedVector2Array([hp + dir * 8.0, hp - dir * 5.0 + side * 5.0, hp - dir * 2.0, hp - dir * 5.0 - side * 5.0]), Color.WHITE)
	if not round:
		draw_rect(Rect2(Vector2.ONE, size - Vector2.ONE * 2.0), Color(0.98, 0.78, 0.35, 0.8), false, 2.0)
	if big:
		_draw_legend()
	if not big:
		var north := c + xf.basis_xform(Vector2(0, -1)).normalized() * (minf(size.x, size.y) * 0.5 - 12.0)
		draw_circle(north, 9.0, Color(0.1, 0.08, 0.14, 0.9))
		draw_string(get_theme_default_font(), north + Vector2(-5, 5), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1, 0.9, 0.6))


func _diamond(c: Vector2, r: float, col: Color) -> void:
	draw_colored_polygon(PackedVector2Array([c + Vector2(0, -r), c + Vector2(r, 0), c + Vector2(0, r), c + Vector2(-r, 0)]), col)


## Légende (grande carte) : la forme et la couleur de chaque lieu.
func _draw_legend() -> void:
	var font := get_theme_default_font()
	var row := 19.0
	var box := Rect2(Vector2(10, size.y - 16 - row * LEGEND.size()), Vector2(178, row * LEGEND.size() + 8))
	draw_rect(box, Color(0.04, 0.03, 0.08, 0.82))
	draw_rect(box, Color(0.98, 0.78, 0.35, 0.5), false, 1.0)
	for i in LEGEND.size():
		var k: String = LEGEND[i][0]
		var p := box.position + Vector2(16, 14 + row * i)
		var col: Color = ICONS.get(k, Color.WHITE)
		if k.begins_with("chest"):
			var r := 3.0 if k == "chest" else 4.5
			draw_rect(Rect2(p - Vector2(r, r), Vector2(r, r) * 2.0), col)
		elif k == "shrine":
			draw_arc(p, 5.0, 0.0, TAU, 16, col, 2.0)
		elif k == "fort":
			_diamond(p, 5.5, col)
		else:
			draw_circle(p, 5.0, col)
		draw_string(font, p + Vector2(14, 5), String(LEGEND[i][1]), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.93, 0.9, 0.98))


func _inside(p: Vector2) -> bool:
	if round:
		return p.distance_to(size * 0.5) < minf(size.x, size.y) * 0.5 - 4.0
	return Rect2(Vector2.ONE * 3.0, size - Vector2.ONE * 6.0).has_point(p)


func _clamp_edge(p: Vector2, c: Vector2) -> Vector2:
	var d := p - c
	if round:
		return c + d.normalized() * (minf(size.x, size.y) * 0.5 - 12.0)
	return c + d * minf((size.x * 0.5 - 10.0) / maxf(absf(d.x), 0.01), (size.y * 0.5 - 10.0) / maxf(absf(d.y), 0.01))
