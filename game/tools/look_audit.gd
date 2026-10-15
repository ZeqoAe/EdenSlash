extends Control
## Planche et contrôle des apparences portées (P16) : toutes les auras de la collection (un effet par
## case, autour du samouraï, sur le fond sombre de l'aperçu Héros) et toutes les apparences d'armes
## (une par case, en main). Demande un rendu (pas de --headless) :
##   godot --path game res://tools/look_audit.tscn -- auras [--page=N] [--fx=s82815,s80213]
##   godot --path game res://tools/look_audit.tscn -- weapons [--page=N]
## --wait=S : première mesure (et planche) après S secondes d'animation au lieu de 1,2.
## Sans --page : toutes les pages. Écrit user://shots/look_<genre>_<page>.png et le relevé
## user://shots/look_<genre>.txt (une ligne par case signalée, puis le total).
## Signalé :
##  - auras : maillage sans entrée dans le .fx.json (« orphelin », matériau brut du glTF), maillage visible
##    sans le shader des effets, bord droit d'un grand panneau (une rangée ou une colonne de l'image où la
##    partie couverte saute de plus d'un tiers de la case : mur, plaque, quad à bords durs), case couverte
##    à plus de 70 % ;
##  - armes : modèle tenu différent de celui de l'apparence, arme non accrochée, modèle minuscule.

const COLS := 8
const ROWS := 4
const CELL := Vector2i(220, 270)
const BG := Color(0.06, 0.05, 0.11)
const EDGE_SHARE := 0.34
const COVER_MAX := 0.70

var _kind := "auras"
var _items: Array = []  # auras : noms d'effet ; armes : [code, modèle, nom]
var _report: PackedStringArray = []
var _flagged := 0
var _wait := 1.2


func _ready() -> void:
	var page := -1
	var only: Array = []
	for a in OS.get_cmdline_user_args():
		if a in ["auras", "weapons"]:
			_kind = a
		elif a.begins_with("--page="):
			page = int(a.get_slice("=", 1))
		elif a.begins_with("--fx="):
			only = Array(a.get_slice("=", 1).split(","))
		elif a.begins_with("--wait="):
			_wait = float(a.get_slice("=", 1))  # délai avant la 1re mesure (moment de l'animation à voir)
	if _kind == "auras" and not only.is_empty():
		_items = only  # effets donnés (aussi hors collection : essais)
	elif _kind == "auras":
		var seen := {}
		for x in GameData.auras:
			var fx := String(x.aura.fx)
			if not seen.has(fx) and (only.is_empty() or fx in only):
				seen[fx] = true
				_items.append(fx)
		_items.sort()
	else:
		var seen := {}
		for x in GameData.collection:
			if x.has("skin") and not seen.has(String(x.code)):
				seen[String(x.code)] = true
				_items.append([String(x.code), String(x.skin.model), String(x.name)])
	var per := COLS * ROWS
	var pages := ceili(_items.size() / float(per))
	get_window().size = Vector2i(COLS * CELL.x, ROWS * CELL.y)
	DirAccess.make_dir_recursive_absolute("user://shots")
	for p in range(pages):
		if page >= 0 and p != page:
			continue
		await _page(p, _items.slice(p * per, (p + 1) * per))
	_report.append("%d cases, %d signalées" % [_items.size() if page < 0 else mini(per, _items.size() - page * per), _flagged])
	var f := FileAccess.open("user://shots/look_%s.txt" % _kind, FileAccess.WRITE)
	f.store_string("\n".join(_report) + "\n")
	f.close()
	print("\n".join(_report))
	print("planches : ", ProjectSettings.globalize_path("user://shots/"))
	get_tree().quit()


func _page(p: int, items: Array) -> void:
	for c in get_children():
		c.queue_free()
	var cells: Array = []
	for i in items.size():
		var box := SubViewportContainer.new()
		box.stretch = true
		box.position = Vector2((i % COLS) * CELL.x, (i / COLS) * CELL.y)
		box.size = CELL
		add_child(box)
		var vp := SubViewport.new()
		vp.own_world_3d = true
		vp.transparent_bg = false
		vp.size = CELL
		box.add_child(vp)
		var env := WorldEnvironment.new()
		env.environment = Environment.new()
		env.environment.background_mode = Environment.BG_COLOR
		env.environment.background_color = BG
		env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.environment.ambient_light_color = Color(0.8, 0.76, 0.86)
		vp.add_child(env)
		var sun := DirectionalLight3D.new()
		sun.rotation_degrees = Vector3(-35, 30, 0)
		vp.add_child(sun)
		var cam := Camera3D.new()
		cam.fov = 40.0 if _kind == "auras" else 34.0
		var eye := Vector3(1.6, 2.4, 6.2) if _kind == "auras" else Vector3(1.6, 1.6, 5.2)
		cam.transform = Transform3D(Basis(), eye).looking_at(Vector3(0, 1.1 if _kind == "auras" else 0.9, 0))
		vp.add_child(cam)
		var pivot := Node3D.new()
		vp.add_child(pivot)
		var cls := GameData.class_data("samurai")
		var model := EdenModel.instantiate_hero(cls)
		model.scale = Vector3.ONE * GameData.HERO_SCALE
		pivot.add_child(model)
		var info := {"vp": vp, "pivot": pivot, "flags": []}
		if _kind == "auras":
			var fx := EdenFx.attach(pivot, String(items[i]), GameData.HERO_SCALE, true)
			info["fx"] = fx
			info["name"] = String(items[i])
		else:
			var it: Array = items[i]
			var entry := EdenModel.weapon_entry(cls, String(it[0]))
			var att := EdenModel.attach_weapon(model, entry)
			info["name"] = "%s %s" % [it[0], it[2]]
			if String(entry.get("model", "")) != String(it[1]):
				info.flags.append("modèle tenu %s au lieu de %s" % [entry.get("model", "?"), it[1]])
			if att == null:
				info.flags.append("arme non accrochée")
			else:
				var sz := EdenModel.bounds(att.get_child(0) as Node3D).get_longest_axis_size()
				if sz < 0.05:
					info.flags.append("modèle minuscule (%.2f m)" % sz)
		var ap := EdenModel.find_anim_player(model)
		var battle: String = cls.get("anims", {}).get("battle", "stand01")
		if ap and ap.has_animation(battle):
			ap.play(battle)
		var lbl := Label.new()
		lbl.text = String(info.name).left(30)
		lbl.add_theme_font_size_override("font_size", 12)
		lbl.position = Vector2(4, CELL.y - 20)
		box.add_child(lbl)
		info["label"] = lbl
		cells.append(info)
	# deux instants de l'animation : un panneau peut n'apparaître qu'un moment
	for k in 2:
		await get_tree().create_timer(_wait if k == 0 else 1.2).timeout
		await RenderingServer.frame_post_draw
		for info in cells:
			if _kind == "auras":
				_check_aura(info)
	await RenderingServer.frame_post_draw
	for info in cells:
		var flags: Array = info.flags
		if not flags.is_empty():
			_flagged += 1
			_report.append("%s : %s" % [info.name, " ; ".join(_uniq(flags))])
			(info.label as Label).add_theme_color_override("font_color", Color(1, 0.35, 0.3))
			(info.label as Label).text = "! " + (info.label as Label).text
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("user://shots/look_%s_%d.png" % [_kind, p])


func _check_aura(info: Dictionary) -> void:
	var fx: EdenFx = info.get("fx")
	if fx == null:
		info.flags.append("effet introuvable")
		return
	var orph = fx.get("orphans")  # absent des versions d'avant P16 (planche « avant »)
	if orph != null and int(orph) > 0:
		info.flags.append("%d maillage(s) sans entrée" % int(orph))
	var raw := 0
	for mi: MeshInstance3D in fx.find_children("*", "MeshInstance3D", true, false):
		if mi.is_visible_in_tree() and not (mi.material_override is ShaderMaterial or mi.material_override is StandardMaterial3D):
			raw += 1
	if raw > 0:
		info.flags.append("%d maillage(s) au matériau brut" % raw)
	var img := (info.vp as SubViewport).get_texture().get_image()
	var w := img.get_width()
	var h := img.get_height()
	var cov := PackedInt32Array()
	cov.resize(h)
	var colc := PackedInt32Array()
	colc.resize(w)
	var total := 0
	for y in h:
		for x in w:
			var c := img.get_pixel(x, y)
			if absf(c.r - BG.r) + absf(c.g - BG.g) + absf(c.b - BG.b) > 0.12:
				cov[y] += 1
				colc[x] += 1
				total += 1
	var edges := 0
	for y in range(1, h):
		if absi(cov[y] - cov[y - 1]) > int(w * EDGE_SHARE):
			edges += 1
	for x in range(1, w):
		if absi(colc[x] - colc[x - 1]) > int(h * EDGE_SHARE):
			edges += 1
	if edges > 0:
		info.flags.append("bord droit de panneau (%d)" % edges)
	var share := total / float(w * h)
	if share > COVER_MAX:
		info.flags.append("case couverte à %d %%" % int(share * 100.0))


static func _uniq(a: Array) -> Array:
	var out: Array = []
	for x in a:
		if not out.has(x):
			out.append(x)
	return out
