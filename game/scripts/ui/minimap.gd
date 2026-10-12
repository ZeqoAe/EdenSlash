class_name Minimap
extends Control
## Mini-carte de la map générée : rendu du terrain, brouillard de guerre,
## lieux découverts, monstres, chemin vers le donjon. Grande carte avec [M].

const ICONS := {
	"village": Color(0.4, 0.85, 1.0),
	"dungeon": Color(0.85, 0.35, 1.0),
	"chest": Color(1.0, 0.85, 0.3),
}

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
			if m[1] == "chest":
				continue
			sp = _clamp_edge(sp, c)  # village / donjon : au bord dans la bonne direction
		if m[1] == "chest":
			draw_rect(Rect2(sp - Vector2(3, 3), Vector2(6, 6)), col)
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
	if not big:
		var north := c + xf.basis_xform(Vector2(0, -1)).normalized() * (minf(size.x, size.y) * 0.5 - 12.0)
		draw_circle(north, 9.0, Color(0.1, 0.08, 0.14, 0.9))
		draw_string(get_theme_default_font(), north + Vector2(-5, 5), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1, 0.9, 0.6))


func _inside(p: Vector2) -> bool:
	if round:
		return p.distance_to(size * 0.5) < minf(size.x, size.y) * 0.5 - 4.0
	return Rect2(Vector2.ONE * 3.0, size - Vector2.ONE * 6.0).has_point(p)


func _clamp_edge(p: Vector2, c: Vector2) -> Vector2:
	var d := p - c
	if round:
		return c + d.normalized() * (minf(size.x, size.y) * 0.5 - 12.0)
	return c + d * minf((size.x * 0.5 - 10.0) / maxf(absf(d.x), 0.01), (size.y * 0.5 - 10.0) / maxf(absf(d.y), 0.01))
