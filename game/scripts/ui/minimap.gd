class_name Minimap
extends Control
## Mini-carte de la map générée : rendu du terrain, brouillard de guerre,
## lieux découverts, monstres, chemin vers le donjon. Grande carte avec [M].

const ICONS := {  # bonbons de la bible (lot UIK2) ; teintes gardées proches des repères du monde
	"merchant": Color("fff8ec"),
	"dungeon": Color("dc92ff"),  # améthyste clair
	"chest": Color("ece8f4"),  # commun : lilas-gris clair, comme l'aura des coffres communs
	"shrine": Color("c3f07a"),  # pomme clair
	"anvil": Color("ffb566"),  # mandarine clair
	"scribe": Color("86ddff"),  # lagon clair
	"well": Color("8fd62e"),  # pomme
	"magnet": Color("22b8f0"),  # lagon
	"greed": Color("ffc928"),  # soleil
	"fortune": Color("ff9db0"),  # fraise clair
	"giant": Color("ff8a1f"),  # mandarine
	"challenge": Color("ff4d6d"),  # fraise
	"chest1": Color("ff4d6d"),  # coffre ouvragé (rouge dans le monde) : fraise
	"chest2": Color("ffc928"),  # coffre doré : soleil
	"fort": Color("ff4d6d"),
	"drop": Color("ffe27a"),  # Battle royale : largage
	"bounty": Color("ff4d6d"),  # Battle royale : héros mis à prix
}
## Légende de la grande carte : [type, nom].
const LEGEND := [["dungeon", "Donjon"], ["merchant", "Marchand"], ["shrine", "Sanctuaire"], ["fort", "Fort d'élite (sceau)"],
	["chest", "Coffre"], ["chest1", "Coffre ouvragé"], ["chest2", "Coffre doré"], ["anvil", "Enclume"], ["scribe", "Autel du scribe"],
	["well", "Fontaine de vie"], ["magnet", "Pierre d'aimant"], ["greed", "Autel de cupidité"], ["challenge", "Stèle du défi"], ["fortune", "Autel de la fortune"], ["giant", "Autel du géant"],
	["drop", "Largage"], ["bounty", "Héros mis à prix"]]


## Couleur du repère [param kind] ; Battle royale : coffres au code de rareté de la Bible (ProcMap.ROYALE_ICONS, lot BR-I2).
static func icon_color(kind: String) -> Color:
	if Royale.active and ProcMap.ROYALE_ICONS.has(kind):
		return ProcMap.ROYALE_ICONS[kind]
	return ICONS.get(kind, Color.WHITE)

var player: Player
var director: RunDirector
var big := false
var round := false  # mini-carte ronde (découpée par son parent, voir Hud)
var zoom := 2.0  # pixels écran par mètre (mini-carte)
const ARENA_METERS := 200.0  # une carte plus petite est une arène (duel, Tour, donjon, boss) : elle tient entière dans la mini-carte


## Brouillard « au papier » (lot HUD-2) : le brouillard de guerre est une image noire à transparence ; ce petit shader peint
## en papier ce qui est dessiné avec la teinte repère FOG_KEY (le brouillard), le reste est dessiné comme d'habitude.
const FOG_KEY := Color(1, 0, 1, 1)
static var _fog_material: ShaderMaterial


static func fog_material() -> ShaderMaterial:
	if _fog_material == null:
		var sh := Shader.new()
		sh.code = """shader_type canvas_item;
uniform vec4 fog_tint : source_color;
varying float fog;
varying float alpha;
void vertex() {
	fog = (COLOR.r > 0.99 && COLOR.g < 0.01 && COLOR.b > 0.99) ? 1.0 : 0.0;
	alpha = COLOR.a;
}
void fragment() {
	if (fog > 0.5) {
		COLOR = vec4(fog_tint.rgb, texture(TEXTURE, UV).a * fog_tint.a * alpha);
	}
}"""
		_fog_material = ShaderMaterial.new()
		_fog_material.shader = sh
		_fog_material.set_shader_parameter("fog_tint", UiTheme.color("papier.300"))
	return _fog_material


func setup(p: Player, d: RunDirector) -> void:
	player = p
	director = d
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	material = Minimap.fog_material()


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
	var focus := player.global_position
	if Royale.active and director.royale != null and director.royale.spectating and is_instance_valid(director.royale.watched):
		focus = director.royale.watched.global_position  # spectateur (passe M1) : la carte suit le héros regardé
	var center_img := Vector2(focus.x, focus.z) * ppm
	var jump: RoyaleDrop = director.royale.jump if Royale.active and director.royale != null else null
	if jump != null and jump.airborne(player):
		scale_ *= 0.4  # largage (lot BR4) : vue large pour choisir où atterrir
	if big:
		scale_ = minf(size.x, size.y) / tex.get_width()
		center_img = Vector2(tex.get_width(), tex.get_height()) * 0.5
	elif tex.get_width() / ppm < ARENA_METERS:
		scale_ = (minf(size.x, size.y) - 8.0) / tex.get_width()  # arène : vue d'ensemble fixe, le héros s'y déplace
		center_img = Vector2(tex.get_width(), tex.get_height()) * 0.5
	# repère : image -> écran (rotation selon la caméra sur la mini-carte)
	var xf := Transform2D(yaw, c) * Transform2D(0.0, Vector2.ONE * scale_, 0.0, Vector2.ZERO) * Transform2D(0.0, -center_img)
	# carte « au papier » (lot HUD-2) : hors de la carte et sous le brouillard, du papier crème tramé d'encre, pas du noir
	var paper := UiTheme.color("papier.300")
	draw_rect(Rect2(Vector2.ZERO, size), paper)
	draw_set_transform_matrix(xf)
	draw_texture(tex, Vector2.ZERO)
	var fog: Texture2D = director.fog_texture()
	if fog:
		draw_texture_rect(fog, Rect2(Vector2.ZERO, Vector2(tex.get_width(), tex.get_height())), false, FOG_KEY)  # (peint en papier, fog_material)
	draw_set_transform_matrix(Transform2D.IDENTITY)

	var w2s := func(p: Vector3) -> Vector2: return xf * (Vector2(p.x, p.z) * ppm)
	# chemin vers le donjon
	for p in director.route:
		var sp: Vector2 = w2s.call(p)
		if _inside(sp):
			draw_circle(sp, 1.8, Color(UiTheme.color("bonbon.soleil.clair"), 0.9))
	# lieux connus (grande carte : icônes agrandies, elles sont petites sur 680 px)
	var k := 1.5 if big else 1.0
	for m in director.markers():
		var sp: Vector2 = w2s.call(m[0])
		var col: Color = icon_color(String(m[1]))
		if not _inside(sp):
			if String(m[1]).begins_with("chest"):
				continue
			sp = _clamp_edge(sp, c)  # marchands, sanctuaires, donjon : au bord dans la bonne direction
		if String(m[1]).begins_with("chest"):
			var r := (3.0 + (1.5 if m[1] != "chest" else 0.0)) * k
			draw_rect(Rect2(sp - Vector2(r, r), Vector2(r, r) * 2.0), col)
		elif m[1] == "shrine":
			draw_arc(sp, 6.0 * k, 0.0, TAU, 20, Color(0, 0, 0, 0.6), 3.5)
			draw_arc(sp, 6.0 * k, 0.0, TAU, 20, col, 2.0)
		elif m[1] == "fort":
			_diamond(sp, 7.5 * k, Color(0, 0, 0, 0.6))
			_diamond(sp, 6.0 * k, col)
		elif m[1] == "drop" or m[1] == "bounty":
			_star(sp, 9.0 * k, Color(0, 0, 0, 0.7))
			_star(sp, 7.0 * k, col)
		else:
			draw_circle(sp, 7.0 * k, Color(0, 0, 0, 0.6))
			draw_circle(sp, 5.5 * k, col)
	# Battle royale : l'anneau actuel (violet) et le prochain (blanc)
	if Royale.active and director.royale != null and not director.royale.ring.is_empty():
		_draw_ring(w2s, director.royale.ring.center, float(director.royale.ring.radius), Color(0.7, 0.45, 1.0, 0.95))
		if float(director.royale.ring.next_radius) < float(director.royale.ring.radius) - 1.0:
			_draw_ring(w2s, director.royale.ring.next_center, float(director.royale.ring.next_radius), Color(1, 1, 1, 0.8))
	# largage (lot BR4) : la ligne du vol (pointillés) et l'aigle
	if jump != null and jump.flying():
		draw_dashed_line(w2s.call(jump.a), w2s.call(jump.b), Color(0.6, 0.9, 1.0, 0.85), 2.0, 8.0)
		var ep: Vector2 = w2s.call(jump.eagle_pos())
		if _inside(ep):
			draw_circle(ep, 6.5 * k, Color(0, 0, 0, 0.6))
			draw_circle(ep, 5.0 * k, Color(0.6, 0.9, 1.0))
	# monstres (Battle royale : les autres héros ne se voient que de près, et pas à bord de l'aigle)
	for node in get_tree().get_nodes_in_group("monsters"):
		var mo := node as Monster
		if Royale.active and (mo.global_position.distance_to(player.global_position) > 45.0 or not mo.visible):
			continue
		if TeamMatch.active and not mo.visible:
			continue  # (lot TAC-2, L'Assaut) un adversaire que ton équipe ne voit pas n'est pas sur la carte
		var sp: Vector2 = w2s.call(mo.global_position)
		if not _inside(sp):
			continue
		if mo.is_boss:
			draw_circle(sp, 5.5, UiTheme.color("bonbon.amethyste.base"))
		elif mo.is_elite:
			draw_circle(sp, 4.0, UiTheme.color("bonbon.mandarine.base"))
		else:
			draw_circle(sp, 2.3, UiTheme.color("bonbon.fraise.base"))
	if Royale.active:
		RoyaleMap.minimap_overlay(self, w2s)  # ligne vers la zone sûre, repère personnel (lot BR-I1)
	# héros
	var hp: Vector2 = w2s.call(player.global_position)
	var f := player.forward()
	var dir := xf.basis_xform(Vector2(f.x, f.z)).normalized()
	var side := Vector2(-dir.y, dir.x)
	var arrow := PackedVector2Array([hp + dir * 8.0, hp - dir * 5.0 + side * 5.0, hp - dir * 2.0, hp - dir * 5.0 - side * 5.0])
	var rim := arrow.duplicate()
	rim.append(arrow[0])
	draw_polyline(rim, UiTheme.color("encre.700"), 3.0, true)  # contour d'encre : lisible sur le papier comme sur l'herbe
	draw_colored_polygon(arrow, Color.WHITE)
	if not round:
		draw_rect(Rect2(Vector2.ONE * 1.5, size - Vector2.ONE * 3.0), UiTheme.color("encre.700"), false, 3.0)  # contour d'encre (bible § 5)
	if big:
		_draw_legend()
	if not big:
		# nord : pastille papier contourée d'encre, lettre à l'encre (lot HUD-2)
		var north := c + xf.basis_xform(Vector2(0, -1)).normalized() * (minf(size.x, size.y) * 0.5 - 17.0)
		draw_circle(north, 10.5, UiTheme.color("encre.700"))
		draw_circle(north, 8.5, UiTheme.color("papier.100"))
		HudV2.ink_text(self, UiTheme.number_font(), "N", north.x, north.y + 5.0, 13, UiTheme.color("encre.700"))


## Cercle de rayon [param r] m autour de [param c] (x, z) sur la carte ; seuls les points visibles sont tracés.
func _draw_ring(w2s: Callable, c: Vector2, r: float, col: Color) -> void:
	var prev := Vector2.INF
	var steps := 96
	for k in steps + 1:
		var a := TAU * k / steps
		var sp: Vector2 = w2s.call(Vector3(c.x + cos(a) * r, 0.0, c.y + sin(a) * r))
		if prev != Vector2.INF and (_inside(sp) or _inside(prev)):
			draw_line(prev, sp, col, 2.5, true)
		prev = sp


func _diamond(c: Vector2, r: float, col: Color) -> void:
	draw_colored_polygon(PackedVector2Array([c + Vector2(0, -r), c + Vector2(r, 0), c + Vector2(0, r), c + Vector2(-r, 0)]), col)


## Légende (grande carte) : la forme et la couleur des seuls lieux découverts, en colonne translucide
## (elle ne cache plus la carte avant d'avoir quoi que ce soit à dire).
func _draw_legend() -> void:
	var seen := {}
	for m in director.markers():
		seen[String(m[1])] = true
	var kinds: Array = LEGEND.filter(func(e): return seen.has(String(e[0])))
	if Royale.active:  # mêmes noms que les coffres de la partie (ProcMap.ROYALE_LOOKS)
		var names := {"chest": "Coffre commun", "chest1": "Coffre rare"}
		kinds = kinds.map(func(e): return [e[0], names.get(String(e[0]), e[1])])
	if kinds.is_empty():
		return
	var font := get_theme_default_font()
	var row := 24.0
	var box := Rect2(Vector2(10, size.y - 16 - row * kinds.size()), Vector2(206, row * kinds.size() + 8))
	HudV2.round_rect(self, box, Color(UiTheme.color("encre.500"), 0.88), 12, 3, UiTheme.color("encre.700"))  # puits d'encre (lot HUD-2)
	for i in kinds.size():
		var k: String = kinds[i][0]
		var p := box.position + Vector2(18, 16 + row * i)
		var col: Color = icon_color(k)
		if k.begins_with("chest"):
			var r := 4.0 if k == "chest" else 5.5
			draw_rect(Rect2(p - Vector2(r, r), Vector2(r, r) * 2.0), col)
		elif k == "shrine":
			draw_arc(p, 6.0, 0.0, TAU, 16, col, 2.5)
		elif k == "fort":
			_diamond(p, 7.0, col)
		elif k == "drop" or k == "bounty":
			_star(p, 7.0, col)
		else:
			draw_circle(p, 6.0, col)
		draw_string(font, p + Vector2(16, 5), String(kinds[i][1]), HORIZONTAL_ALIGNMENT_LEFT, -1, UiTheme.MIN_TEXT, Color(0.93, 0.9, 0.98))


## Étoile à cinq branches (largage, héros mis à prix : visibles de partout, au bord quand ils sont loin).
func _star(c: Vector2, r: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 10:
		var a := -PI / 2.0 + i * PI / 5.0
		pts.append(c + Vector2(cos(a), sin(a)) * (r if i % 2 == 0 else r * 0.45))
	draw_colored_polygon(pts, col)


func _inside(p: Vector2) -> bool:
	if round:
		return p.distance_to(size * 0.5) < minf(size.x, size.y) * 0.5 - 4.0
	return Rect2(Vector2.ONE * 3.0, size - Vector2.ONE * 6.0).has_point(p)


func _clamp_edge(p: Vector2, c: Vector2) -> Vector2:
	var d := p - c
	if round:
		return c + d.normalized() * (minf(size.x, size.y) * 0.5 - 12.0)
	return c + d * minf((size.x * 0.5 - 10.0) / maxf(absf(d.x), 0.01), (size.y * 0.5 - 10.0) / maxf(absf(d.y), 0.01))
