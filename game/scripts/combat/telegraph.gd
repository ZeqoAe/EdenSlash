class_name Telegraph
extends Node3D
## Zone au sol qui annonce une attaque : le contour apparaît, l'intérieur
## se remplit pendant [member delay], puis les dégâts tombent sur le héros s'il
## est encore dedans (l'esquive rend invulnérable).
##   shape : "circle" (rayon), "ring" (rayon intérieur / extérieur),
##           "line" (longueur, largeur), "cone" (rayon, angle)
## Télégraphes v2 (lot DNG-2, bible § 10 ; maquette donjons_maquettes/v2_barre_boss.svg) pour les attaques ennemies :
##   - danger : bord net (bande d'encre et liseré clair), intérieur hachuré fraise (lisible sans la couleur) et cœur qui
##     monte jusqu'au bord pendant l'armement, 35 % d'opacité au plus ; compte à rebours sur les grosses zones ;
##   - sûr (zone sans dégâts, verte) : pomme, bord en pointillés et mot « SÛR » ;
##   - zone immense (anneau autour d'un cercle sûr, plus de la moitié de l'écran) : seul le bord du sûr est peint, le voile
##     s'efface en s'en éloignant ; jamais un écran rouge plein ;
##   - un son court à l'armement des zones de boss (Sfx « tele_arm »).
## Les annonces discrètes (small : monstres ordinaires, arrivées, zones du héros) et les traits de projectiles gardent le
## dessin simple. Seul l'aspect change : formes, délais, dégâts et règles de touche sont ceux d'avant.
## Lot DNG-3 (accessibilité, BM-DNG P1-11) : la couleur du danger se règle (Paramètres > Caméra & interface : fraise, mandarine,
## améthyste ; « auto » suit « Couleurs pour daltoniens »), l'intensité aussi (voile et hachures) ; les formes, elles, ne changent
## jamais (hachures = danger, pointillés = sûr).

signal resolved(hit: bool)

const COLOR := Color("ff4d6d")  # fraise (bible § 3 : danger)
## Couleurs du danger au choix (réglage interface/tele_palette) : [clé, nom, couleur].
const PALETTES := [["fraise", "Fraise (rouge)", Color("ff4d6d")], ["mandarine", "Mandarine (orange)", Color("ff8a1f")],
	["amethyste", "Améthyste (violet)", Color("b43beb")]]
const INTENSITY_MIN := 0.6
const INTENSITY_MAX := 1.5
const ALPHA_CAP := 0.5  # même à l'intensité la plus haute, l'intérieur reste transparent (on voit le héros dedans)
const PLAYER_COLOR := Color(0.25, 0.6, 1.0)  # zone des attaques du héros (option)
const SAFE_COLOR := Color("8fd62e")  # pomme
const INK := Color("221a3a")
const PAPER := Color("fff8ec")
const WIDE_RING := 30.0  # un anneau plus grand couvre l'écran : on peint son bord intérieur (le sûr), pas sa surface
const WIDE_CIRCLE := 16.0
const FILL_ALPHA := 0.22  # cœur qui monte (avec les hachures, 35 % au plus)
const COUNT_MIN_R := 5.5  # compte à rebours sur les zones d'au moins ce rayon

var shape := "circle"
var radius := 4.0
var inner := 0.0  # ring
var length := 12.0  # line
var width := 3.0  # line
var angle := 90.0  # cone (degrés)
var delay := 1.2
var damage := 100.0
var source: Combatant
var stun_time := 0.0  # étourdit le héros touché
var applies: Dictionary = {}  # (L'Assaut, lot TAC-4) effets du sort d'un héros scripté posés sur qui est touché
var crit := false  # coup critique (adversaire de duel)
var jumpable := false  # onde au sol : évitée si le héros est en l'air
var small := false  # attaque de monstre ordinaire : annonce plus discrète
var color := COLOR

var _t := 0.0
var _fill: MeshInstance3D
var safe := false  # (déduit) zone sûre : pointillés pomme et « SÛR »
var wide := false  # (déduit) danger immense : seul le bord du sûr est peint
var v2 := false  # (déduit) dessin v2 (attaque ennemie qui n'est ni discrète ni un trait de projectile)
var _count: Label3D
var _hatch: ShaderMaterial
static var _hatch_shader: Shader


static func spawn(parent: Node, pos: Vector3, yaw: float, props: Dictionary) -> Telegraph:
	if NetEvents.on:
		NetEvents.emit(NetEvents.TELE, parent, [pos, yaw, props])  # (lot NET-A) Mode amis : l'hôte rejoue l'effet chez ses amis
	var t := Telegraph.new()
	for k in props:
		t.set(k, props[k])
	parent.get_tree().current_scene.add_child(t)
	t.global_position = pos + Vector3.UP * 0.12
	t.rotation.y = yaw
	if Vfx.muted(parent):
		t.visible = false  # combat caché du Colisée (lot CO-C) : la zone frappe, rien n'est dessiné
	return t


## Clé de la palette du danger en vigueur : le réglage, ou « auto » (mandarine avec « Couleurs pour daltoniens », sinon fraise).
static func palette_key() -> String:
	var k := String(Settings.get_v("interface", "tele_palette")) if Settings != null else "auto"
	for p in PALETTES:
		if String(p[0]) == k:
			return k
	return "mandarine" if Settings != null and bool(Settings.get_v("interface", "colorblind")) else "fraise"


## Couleur du danger des télégraphes v2 (et du mur d'arène, des zones du Siège).
static func danger_color() -> Color:
	var k := palette_key()
	for p in PALETTES:
		if String(p[0]) == k:
			return p[2]
	return COLOR


## Intensité des zones (réglage interface/tele_intensity, 1 = celle de la bible) : × l'opacité du voile, des hachures et du cœur.
static func intensity() -> float:
	var v = Settings.get_v("interface", "tele_intensity") if Settings != null else 1.0
	return clampf(float(v) if v != null else 1.0, INTENSITY_MIN, INTENSITY_MAX)


func _ready() -> void:
	add_to_group("telegraphs")  # les héros scriptés en équipe les lisent pour esquiver (ClassRival._read_zones, passe M7)
	safe = damage <= 0.0 and color.g > 0.75 and color.r < 0.6
	var trail := damage <= 0.0 and not safe and shape == "line" and width < 1.2  # trait de la trajectoire d'un projectile
	v2 = not small and not trail and not color.is_equal_approx(PLAYER_COLOR)
	if not v2:
		_ready_simple()
		return
	if not safe and color.is_equal_approx(COLOR):
		color = danger_color()  # palette réglable (lot DNG-3) ; une couleur imposée par la mécanique reste la sienne
	wide = not safe and ((shape == "ring" and radius >= WIDE_RING) or (shape == "circle" and radius >= WIDE_CIRCLE))
	var body := MeshInstance3D.new()
	body.mesh = _shape_mesh(1.0)
	body.material_override = _mat_color(SAFE_COLOR, 0.2) if safe else _hatch_mat()
	body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(body)
	# bord net : bande d'encre, liseré clair au milieu (pointillés pour le sûr : la forme dit « sûr » sans la couleur)
	var ink := MeshInstance3D.new()
	ink.mesh = _border_mesh(0.28, 0.0, safe)
	ink.material_override = _mat_color(INK, 0.9)
	ink.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ink.position.y = 0.012
	add_child(ink)
	var light := MeshInstance3D.new()
	light.mesh = _border_mesh(0.08, 0.1, safe)
	light.material_override = _mat_color(Color.WHITE if safe else PAPER, 0.95)
	light.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	light.position.y = 0.02
	add_child(light)
	if jumpable:
		_jump_edge()
	if not wide:
		_fill = MeshInstance3D.new()
		_fill.mesh = body.mesh
		_fill.material_override = _mat_color(SAFE_COLOR if safe else color, minf((0.16 if safe else FILL_ALPHA) * intensity(), ALPHA_CAP))
		_fill.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_fill.position.y = 0.006
		_fill.scale = Vector3(0.01, 1, 0.01) if shape != "line" else Vector3(1, 1, 0.01)
		add_child(_fill)
	if safe:
		_word("SÛR", 34)
	elif not wide and shape in ["circle", "ring"] and radius >= COUNT_MIN_R and delay >= 1.2:
		_count = _word("", 28)
	if not safe and damage > 0.0 and _boss_source():
		Sfx.ui("tele_arm", -18.0)


## Dessin d'avant (annonce discrète, zone du héros, trait de projectile) : fond léger, liseré, intérieur qui se remplit.
func _ready_simple() -> void:
	var outline := MeshInstance3D.new()
	outline.mesh = _shape_mesh(1.0)
	outline.material_override = _mat(0.08 if small else 0.12)  # fond léger : le héros reste visible
	# liseré net sur tout le contour (lisible même quand plusieurs zones se chevauchent)
	var border := MeshInstance3D.new()
	border.mesh = _border_mesh(0.14 if small else 0.18)
	border.material_override = _mat(0.85)
	border.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	border.position.y = 0.01
	add_child(border)
	if jumpable:
		_jump_edge()
	outline.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(outline)
	_fill = MeshInstance3D.new()
	_fill.mesh = outline.mesh
	_fill.material_override = _mat(0.32)
	_fill.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_fill.scale = Vector3(0.01, 1, 0.01) if shape != "line" else Vector3(1, 1, 0.01)
	add_child(_fill)


## Bord jaune : on peut l'éviter en sautant.
func _jump_edge() -> void:
	var edge := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = radius - 0.25
	torus.outer_radius = radius
	edge.mesh = torus
	edge.scale = Vector3(1, 0.05, 1)
	var em := _mat(0.9)
	em.albedo_color = Color(1.0, 0.85, 0.2, 0.9)
	edge.material_override = em
	add_child(edge)


## L'attaque vient-elle d'un boss (ou d'une élite à mécaniques) ? Seules ces zones sonnent à l'armement.
func _boss_source() -> bool:
	return is_instance_valid(source) and (bool(source.get("is_boss")) or source.get("brain") != null)


## Mot posé au centre de la zone, face caméra, contouré d'encre (« SÛR », compte à rebours).
func _word(text: String, fs: int) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.fixed_size = true
	l.pixel_size = 0.0011
	l.font = UiTheme.title_font()
	l.font_size = fs
	l.outline_size = 10
	l.modulate = Color.WHITE
	l.outline_modulate = INK
	l.position = Vector3(0, 0.5, 0)
	l.render_priority = 2
	l.outline_render_priority = 1
	add_child(l)
	return l


## Intérieur hachuré (shaders/telegraph.gdshader) ; zone immense : le voile s'efface à 5 m du bord intérieur.
func _hatch_mat() -> ShaderMaterial:
	if _hatch_shader == null:
		_hatch_shader = load("res://shaders/telegraph.gdshader") as Shader
	var m := ShaderMaterial.new()
	m.shader = _hatch_shader
	m.render_priority = 1
	m.set_shader_parameter("tint", Color(color, 1.0))
	_hatch = m
	var k := intensity()  # (lot DNG-3) intensité réglable ; 1 = les valeurs de la bible
	m.set_shader_parameter("base_alpha", minf(0.06 * k, ALPHA_CAP))
	m.set_shader_parameter("hatch_alpha", minf(0.24 * k, ALPHA_CAP))
	if wide:
		m.set_shader_parameter("base_alpha", minf(0.1 * k, ALPHA_CAP))
		m.set_shader_parameter("hatch_alpha", minf(0.24 * k, ALPHA_CAP))
		m.set_shader_parameter("inner_r", inner if shape == "ring" else 0.0)
		m.set_shader_parameter("fade_len", 5.0)
	return m


func _mat_color(c: Color, alpha: float) -> StandardMaterial3D:
	var m := _mat(alpha)
	m.albedo_color = Color(c, alpha)
	return m


func _mat(alpha: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.no_depth_test = false
	m.albedo_color = Color(color, alpha)
	m.render_priority = 1
	return m


## Maillage plat de la forme (repère local : avant = +Z).
func _shape_mesh(k: float) -> Mesh:
	var im := ImmediateMesh.new()
	im.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	match shape:
		"line":
			var w := width * 0.5
			var pts := [Vector3(-w, 0, 0), Vector3(w, 0, 0), Vector3(w, 0, length * k), Vector3(-w, 0, length * k)]
			for i in [0, 1, 2, 0, 2, 3]:
				im.surface_add_vertex(pts[i])
		"cone":
			var half := deg_to_rad(angle) * 0.5
			var segs := 24
			for i in segs:
				var a0 := -half + 2.0 * half * i / segs
				var a1 := -half + 2.0 * half * (i + 1) / segs
				im.surface_add_vertex(Vector3.ZERO)
				im.surface_add_vertex(Vector3(sin(a0), 0, cos(a0)) * radius * k)
				im.surface_add_vertex(Vector3(sin(a1), 0, cos(a1)) * radius * k)
		_:
			var segs := 40
			var r0 := inner * k if shape == "ring" else 0.0
			for i in segs:
				var a0 := TAU * i / segs
				var a1 := TAU * (i + 1) / segs
				var d0 := Vector3(sin(a0), 0, cos(a0))
				var d1 := Vector3(sin(a1), 0, cos(a1))
				im.surface_add_vertex(d0 * r0)
				im.surface_add_vertex(d0 * radius * k)
				im.surface_add_vertex(d1 * radius * k)
				im.surface_add_vertex(d0 * r0)
				im.surface_add_vertex(d1 * radius * k)
				im.surface_add_vertex(d1 * r0)
	im.surface_end()
	return im


## Bande de largeur [param w] le long du contour de la forme, décalée de [param off] vers l'intérieur ; [param dashed] :
## en pointillés (un segment sur deux, cercles et anneaux).
func _border_mesh(w: float, off := 0.0, dashed := false) -> Mesh:
	var im := ImmediateMesh.new()
	im.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	var band := func(a: Vector3, b: Vector3, n: Vector3) -> void:
		# segment a→b, épaisseur vers l'intérieur (n)
		for v in [a + n * off, b + n * off, b + n * (off + w), a + n * off, b + n * (off + w), a + n * (off + w)]:
			im.surface_add_vertex(v)
	match shape:
		"line":
			var h := width * 0.5
			var p := [Vector3(-h, 0, 0), Vector3(h, 0, 0), Vector3(h, 0, length), Vector3(-h, 0, length)]
			band.call(p[0], p[1], Vector3(0, 0, 1))
			band.call(p[1], p[2], Vector3(-1, 0, 0))
			band.call(p[2], p[3], Vector3(0, 0, -1))
			band.call(p[3], p[0], Vector3(1, 0, 0))
		"cone":
			var half := deg_to_rad(angle) * 0.5
			var segs := 24
			for i in segs:
				var a0 := -half + 2.0 * half * i / segs
				var a1 := -half + 2.0 * half * (i + 1) / segs
				var d0 := Vector3(sin(a0), 0, cos(a0))
				var d1 := Vector3(sin(a1), 0, cos(a1))
				band.call(d0 * radius, d1 * radius, -(d0 + d1).normalized())
			for side: float in [-1.0, 1.0]:
				var d := Vector3(sin(half * side), 0, cos(half * side))
				band.call(Vector3.ZERO, d * radius, Vector3(cos(half * side), 0, -sin(half * side)) * -side)
		_:
			var segs := 48
			for ring in ([radius, inner] if shape == "ring" and inner > 0.0 else [radius]):
				var inward := 1.0 if is_equal_approx(float(ring), radius) else -1.0
				for i in segs:
					if dashed and i % 2 == 1:
						continue
					var a0 := TAU * i / segs
					var a1 := TAU * (i + 1) / segs
					var d0 := Vector3(sin(a0), 0, cos(a0))
					var d1 := Vector3(sin(a1), 0, cos(a1))
					band.call(d0 * float(ring), d1 * float(ring), -(d0 + d1).normalized() * inward)
	im.surface_end()
	return im


func _process(delta: float) -> void:
	_t += delta
	var p := clampf(_t / delay, 0.0, 1.0)
	if _fill != null:
		if shape == "line":
			_fill.scale = Vector3(1, 1, maxf(p, 0.01))
		else:
			_fill.scale = Vector3(maxf(p, 0.01), 1, maxf(p, 0.01))
	if _count != null:
		_count.text = ("%.1f s" % maxf(delay - _t, 0.0)).replace(".", ",")
	if wide and _hatch != null:
		_hatch.set_shader_parameter("center", global_position)  # (posée après _ready par spawn)
	if _t >= delay:
		_resolve()


func _resolve() -> void:
	set_process(false)
	var hit := false
	var src: Combatant = source if is_instance_valid(source) else null  # la source a pu mourir entre-temps
	for target in Combatant.hostile_targets(get_tree(), src):
		if damage <= 0.0 or not contains(target.global_position, target.radius):
			continue
		if AssaultVision.current != null and AssaultVision.blocks_zone(self, src, target):
			continue  # (lot TAC-2, L'Assaut) murs et murets arrêtent le coup
		var player := target as Player
		if player == null:
			# allié IA (ClassRival) : même règle, sans les compteurs du joueur
			if target.has_method("is_invulnerable") and target.is_invulnerable():
				continue
			target.take_damage(damage, src, crit)
			_apply_effects(target, src)
			hit = true
			continue
		var dodged_by_jump := jumpable and player.is_airborne() and player.global_position.y > global_position.y + 0.4
		if dodged_by_jump:
			player.ml_counts.dodged += 1
			DamageNumber.spawn_text(player, "SAUT !", Color(0.6, 0.9, 1.0))
		elif player.is_invulnerable():
			player.ml_counts.dodged += 1
			DamageNumber.spawn_text(player, "ESQUIVE !", Color(0.7, 1.0, 0.7))
		else:
			player.take_damage(damage, src, crit)
			Quests.event("zone_hit")  # quête « sans dégât de zone » (passe M5)
			if stun_time > 0.0:
				player.stun(stun_time)
			_apply_effects(player, src)
			hit = true
	resolved.emit(hit)
	# éclat final puis disparition
	if _count != null:
		_count.visible = false
	var flash := MeshInstance3D.new()
	flash.mesh = _shape_mesh(1.0)
	flash.material_override = _mat(0.85 if not wide else 0.3)
	add_child(flash)
	var tw := create_tween()
	tw.tween_property(flash.material_override, "albedo_color:a", 0.0, 0.25)
	tw.tween_callback(queue_free)


## Effets du sort (applies) sur [param target] touché : le héros joueur est renversé par stun / freeze / sleep (Player.stun),
## le reste passe par add_status (règles de contrôle du mode : AssaultCombat). Vide hors de L'Assaut.
func _apply_effects(target: Combatant, src: Combatant) -> void:
	if applies.is_empty() or target.is_dead:
		return
	for s in applies:
		var d := float(applies[s])
		if target is Player and String(s) in ["stun", "freeze", "sleep"]:
			(target as Player).stun(d)
		else:
			target.add_status(String(s), d, src)


## Le point (monde) est-il dans la zone ?
func contains(p: Vector3, margin := 0.0) -> bool:
	var local := global_transform.affine_inverse() * p
	var flat := Vector2(local.x, local.z)
	match shape:
		"line":
			return absf(local.x) <= width * 0.5 + margin and local.z >= -margin and local.z <= length + margin
		"cone":
			if flat.length() > radius + margin:
				return false
			return rad_to_deg(absf(atan2(local.x, local.z))) <= angle * 0.5 or flat.length() < 1.0
		"ring":
			return flat.length() <= radius + margin and flat.length() >= inner - margin
		_:
			return flat.length() <= radius + margin
