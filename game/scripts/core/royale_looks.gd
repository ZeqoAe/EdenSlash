class_name RoyaleLooks
extends RefCounted
## Apparences du Battle royale (lot BR-R1, backlog BM-BR P2 n° 22) : la voile du planeur et la traînée de la chute, gagnées en
## jouant le mode (parties, podiums, victoires, Ligue royale) ; la couronne du vainqueur, portée la partie suivante. Rien ne
## change le combat (mode scellé). Choix gardés dans Profile.records.royale_look = {glider, trail} ; couronne :
## Profile.records.royale_crown (vrai après une victoire, remis à faux à la fin de la partie suivante).

## Voiles : {id, name, col, need (condition, voir [method met]), text (la condition en clair)} ; la première est celle de tous.
const GLIDERS := [
	{"id": "soleil", "name": "Voile soleil", "col": Color("ffc928"), "need": ""},
	{"id": "lagon", "name": "Voile lagon", "col": Color("22b8f0"), "need": "games:3", "text": "Jouer 3 parties"},
	{"id": "pomme", "name": "Voile pomme", "col": Color("8fd62e"), "need": "podium:1", "text": "Finir une fois sur le podium"},
	{"id": "fraise", "name": "Voile fraise", "col": Color("ff4d6d"), "need": "kills:15", "text": "Éliminer 15 héros"},
	{"id": "amethyste", "name": "Voile améthyste", "col": Color("b54dff"), "need": "wins:1", "text": "Gagner une partie"},
	{"id": "argent", "name": "Voile d'argent", "col": Color("dfe6f2"), "need": "league:1", "text": "Rang Argent de la Ligue royale"},
	{"id": "or", "name": "Voile d'or", "col": Color("ffb000"), "need": "league:2", "text": "Rang Or de la Ligue royale"},
	{"id": "platine", "name": "Voile de platine", "col": Color("9ff3ff"), "need": "league:3", "text": "Rang Platine de la Ligue royale"},
]
## Traînées de chute (particules derrière le héros en chute libre) : « aucune » d'office.
const TRAILS := [
	{"id": "", "name": "Aucune", "col": Color(0, 0, 0, 0), "need": ""},
	{"id": "etoiles", "name": "Étoiles", "col": Color("fff8ec"), "need": "games:1", "text": "Jouer une partie"},
	{"id": "bonbons", "name": "Bonbons", "col": Color("ff9a3d"), "need": "wins:3", "text": "Gagner 3 parties"},
	{"id": "aurore", "name": "Aurore", "col": Color("7ef0c8"), "need": "league:2", "text": "Rang Or de la Ligue royale"},
]
## Couleurs des cinq bonbons (traînée « Cinq bonbons »).
const CANDY := [Color("ffd02d"), Color("f68622"), Color("bbf235"), Color("2fc3ff"), Color("cc27ff")]


static func _find(list: Array, id: String) -> Dictionary:
	for e in list:
		if String(e.id) == id:
			return e
	return list[0]


## La condition [param need] (« games:3 », « wins:1 », « league:2 »…) est-elle remplie ?
static func met(need: String) -> bool:
	if need == "":
		return true
	var kind := need.get_slice(":", 0)
	var n := int(need.get_slice(":", 1))
	match kind:
		"games":
			return int(Profile.records.get("royale_games", 0)) >= n
		"wins":
			return int(Profile.records.get("royale_wins", 0)) >= n
		"kills":
			return int(Profile.records.get("royale_kills", 0)) >= n
		"podium":
			return int(Profile.records.get("royale_podiums", 0)) >= n or (int(Profile.records.get("royale_best", 99)) <= 3 and n <= 1)
		"league":
			return RoyaleLeague.best_ever() >= n
	return false


static func choice() -> Dictionary:
	var c = Profile.records.get("royale_look", {})
	return c if c is Dictionary else {}


## Voile choisie (repli sur la première si elle n'est plus ouverte).
static func glider() -> Dictionary:
	var g := _find(GLIDERS, String(choice().get("glider", "soleil")))
	return g if met(String(g.need)) else GLIDERS[0]


static func trail() -> Dictionary:
	var t := _find(TRAILS, String(choice().get("trail", "")))
	return t if met(String(t.need)) else TRAILS[0]


## Choisit la voile ou la traînée [param id] ([param kind] : « glider » ou « trail ») si elle est ouverte ; vrai si c'est fait.
static func pick(kind: String, id: String) -> bool:
	var e := _find(GLIDERS if kind == "glider" else TRAILS, id)
	if String(e.id) != id or not met(String(e.need)):
		return false
	var c := choice().duplicate()
	c[kind] = id
	Profile.records["royale_look"] = c
	return true


## Couronne du vainqueur : portée pendant la partie qui suit une victoire.
static func crowned() -> bool:
	return bool(Profile.records.get("royale_crown", false))


## Petite couronne d'or au-dessus de la tête (cinq pointes autour d'un anneau), à poser sur un héros.
static func make_crown() -> Node3D:
	var root := Node3D.new()
	root.name = "RoyaleCrown"
	root.position = Vector3(0, 2.55, 0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("ffc928")
	mat.emission_enabled = true
	mat.emission = Color("ffb000") * 0.45
	mat.metallic = 0.6
	mat.roughness = 0.35
	var band := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.24
	cyl.bottom_radius = 0.26
	cyl.height = 0.12
	cyl.radial_segments = 20
	cyl.rings = 1
	band.mesh = cyl
	band.material_override = mat
	band.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(band)
	for i in 5:
		var a := TAU * i / 5.0
		var spike := MeshInstance3D.new()
		var pr := PrismMesh.new()
		pr.size = Vector3(0.13, 0.2, 0.05)
		spike.mesh = pr
		spike.material_override = mat
		spike.position = Vector3(cos(a) * 0.24, 0.15, sin(a) * 0.24)
		spike.rotation.y = -a + PI / 2.0
		spike.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(spike)
	var tw := root.create_tween().set_loops()
	tw.tween_property(root, "rotation:y", TAU, 6.0).from(0.0)
	return root


## Traînée de chute : un émetteur de particules (couleur de la traînée ; « Cinq bonbons » : les cinq couleurs) ; null sans traînée.
static func make_trail(t: Dictionary) -> Node3D:
	if String(t.get("id", "")) == "":
		return null
	var p := CPUParticles3D.new()
	p.name = "RoyaleTrail"
	p.amount = 40
	p.lifetime = 0.9
	p.local_coords = false
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.4
	p.direction = Vector3.UP
	p.spread = 25.0
	p.initial_velocity_min = 1.0
	p.initial_velocity_max = 2.5
	p.gravity = Vector3.ZERO
	p.scale_amount_min = 0.12
	p.scale_amount_max = 0.24
	var mesh := SphereMesh.new()
	mesh.radius = 0.5
	mesh.height = 1.0
	mesh.radial_segments = 6
	mesh.rings = 3
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh.material = mat
	p.mesh = mesh
	var g := Gradient.new()
	if String(t.id) == "bonbons":
		g.offsets = PackedFloat32Array([0.0, 0.25, 0.5, 0.75, 1.0])
		g.colors = PackedColorArray(CANDY)
		p.color_initial_ramp = g
	else:
		var c: Color = t.col
		g.offsets = PackedFloat32Array([0.0, 1.0])
		g.colors = PackedColorArray([c, Color(c, 0.0)])
		p.color_ramp = g
	p.position = Vector3(0, 1.0, 0)
	return p
