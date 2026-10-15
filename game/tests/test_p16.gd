extends Node
## Passe P16 (conception/nuit_15_10/R_P16.md), deux notes du joueur du 15/10 :
## (A) aura « Roche de Luna de la Lumière des étoiles ardente » (s82815) : plus de mur étoilé ni de plaque blanche
##     (maillages d'une variante sans entrée dans le .fx.json), halo de la lune sans planche de 3 × 3 (texture bloquée
##     au bord), lune et soleil face à la caméra (nœuds panneaux), textures qui tournent ; puis les 171 effets d'aura :
##     aucun maillage orphelin ni au matériau brut, aucune transformation non finie après 4 s d'animation ;
## (B) Héros > Apparence : l'emplacement « Arme » montre l'apparence choisie (icône et nom), plus l'arme d'origine.
## godot --headless --path game res://tests/test_p16.tscn

const LUNA := "s82815"

var fails := 0


func check(label: String, ok: bool) -> void:
	print(("OK    " if ok else "ÉCHEC ") + label)
	if not ok:
		fails += 1


func _ready() -> void:
	Training.active = true  # rien n'est sauvegardé
	await _test_luna()
	await _test_all_auras()
	await _test_weapon_slot()
	print("test_p16 : %s (%d échec(s))" % ["OK" if fails == 0 else "ÉCHEC", fails])
	get_tree().quit(1 if fails > 0 else 0)


## Scène minimale : caméra de l'aperçu Héros, pivot qui tourne comme la poupée.
func _stage() -> Array:
	var root := Node3D.new()
	add_child(root)
	var cam := Camera3D.new()
	root.add_child(cam)
	cam.transform = Transform3D(Basis(), Vector3(0, 1.25, 4.6)).looking_at(Vector3(0, 1.05, 0))
	cam.current = true
	var pivot := Node3D.new()
	root.add_child(pivot)
	return [root, cam, pivot]


func _test_luna() -> void:
	var st := _stage()
	var cam: Camera3D = st[1]
	var pivot: Node3D = st[2]
	var fx := EdenFx.attach(pivot, LUNA, GameData.HERO_SCALE, true)
	await get_tree().process_frame
	check("(A) s82815 : aucun maillage sans entrée (%d)" % fx.orphans, fx.orphans == 0)
	var raw := 0
	for mi: MeshInstance3D in fx.find_children("*", "MeshInstance3D", true, false):
		if mi.is_visible_in_tree() and not (mi.material_override is ShaderMaterial):
			raw += 1
	check("(A) s82815 : aucun maillage visible au matériau brut du glTF (%d)" % raw, raw == 0)
	var curtain := fx.find_child("Editable_Poly_416", true, false)
	check("(A) s82815 : le rideau étoilé (mur bleu) n'est plus affiché", curtain == null or not (curtain as Node3D).is_visible_in_tree())
	var plate := fx.find_child("Editable_Poly_428", true, false)
	check("(A) s82815 : la plaque blanche au sol n'est plus affichée", plate == null or not (plate as Node3D).is_visible_in_tree())
	var halo := fx.find_child("Plane10", true, false) as MeshInstance3D
	var hm := halo.material_override as ShaderMaterial if halo else null
	check("(A) s82815 : halo de la lune bloqué au bord (pas de planche de 3 × 3)", hm != null and int(hm.get_shader_parameter("wrap_mode")) == 0)
	var r0 := float(hm.get_shader_parameter("uv_rot")) if hm else 0.0
	# lune et soleil (NiBillboardNode) : face à la caméra, même quand la poupée tourne
	var moon := fx.find_child("Dummy10", true, false) as Node3D
	var sun := fx.find_child("Dummy09", true, false) as Node3D
	var faced := 0
	for yaw in [0.0, 1.2, 2.5, 4.0]:
		pivot.rotation.y = yaw
		for _k in 3:
			await get_tree().process_frame
		for n in [moon, sun]:
			if n and n.global_basis.orthonormalized().z.dot(cam.global_basis.z) > 0.99:
				faced += 1
	check("(A) s82815 : lune et soleil face à la caméra sous 4 angles (%d / 8)" % faced, faced == 8)
	await get_tree().create_timer(0.5).timeout
	var r1 := float(hm.get_shader_parameter("uv_rot")) if hm else 0.0
	check("(A) s82815 : la texture du halo tourne (%.2f -> %.2f rad)" % [r0, r1], absf(r1 - r0) > 0.05)
	st[0].queue_free()
	await get_tree().process_frame


func _test_all_auras() -> void:
	var st := _stage()
	var pivot: Node3D = st[2]
	var names := {}
	for x in GameData.auras:
		names[String(x.aura.fx)] = true
	var fxs: Array = []
	var i := 0
	for n in names:
		var holder := Node3D.new()
		holder.position = Vector3((i % 15) * 3.0, 0, (i / 15) * 3.0)
		pivot.add_child(holder)
		fxs.append(EdenFx.attach(holder, String(n), GameData.HERO_SCALE, true))
		i += 1
	await get_tree().process_frame
	var missing := fxs.filter(func(f): return f == null).size()
	check("(A) %d effets d'aura chargés (%d introuvables)" % [names.size(), missing], missing == 0)
	var orph: PackedStringArray = []
	var raw: PackedStringArray = []
	for f: EdenFx in fxs:
		if f == null:
			continue
		if f.orphans > 0:
			orph.append(f.fx_name)
		for mi: MeshInstance3D in f.find_children("*", "MeshInstance3D", true, false):
			if mi.is_visible_in_tree() and not (mi.material_override is ShaderMaterial):
				raw.append(f.fx_name)
				break
	check("(A) toutes les auras : aucun maillage sans entrée %s" % str(orph), orph.is_empty())
	check("(A) toutes les auras : aucun maillage au matériau brut %s" % str(raw), raw.is_empty())
	await get_tree().create_timer(4.0).timeout
	var bad: PackedStringArray = []
	for f: EdenFx in fxs:
		if f == null:
			continue
		for n: Node3D in f.find_children("*", "Node3D", true, false):
			var b := n.global_transform
			if not (b.basis.x.is_finite() and b.basis.y.is_finite() and b.basis.z.is_finite() and b.origin.is_finite()):
				bad.append(f.fx_name)
				break
	check("(A) toutes les auras : transformations finies après 4 s %s" % str(bad), bad.is_empty())
	st[0].queue_free()
	await get_tree().process_frame


func _test_weapon_slot() -> void:
	Profile.reset_all()  # compte neuf en mémoire (rien n'est sauvegardé : Training.active)
	Profile.selected_class = "samurai"
	Profile._lobby_view()  # préréglage du samouraï (la sauvegarde, qui le ferait, est coupée)
	var w := Items.generate(30, 0.6, "weapon", "samurai")
	for _k in 50:  # une arme de la classe (un autre type irait en arme secondaire)
		if Profile.can_be_main(w):
			break
		w = Items.generate(30, 0.6, "weapon", "samurai")
	Profile.inventory.append(w)
	Profile.equip(w)
	var wt := Items.weapon_type_of(w)
	var skin := {}
	for x in GameData.collection:
		if x.has("skin") and String(x.skin.wtype) in ["", wt]:
			skin = x
			break
	Profile.collect(skin)
	var skins_was: Dictionary = Profile.skins.duplicate()
	Profile.skins.erase(wt)
	var page := HeroPages.AppearancePage.new()
	page.size = Vector2(1400, 800)
	add_child(page)
	await get_tree().process_frame
	page._cat = "weapon"
	page._slot = "weapon"
	page.refresh()
	var slot: ItemWidgets.TipButton = page._slots["weapon"]
	var item_icon := UiTheme.texture(String(w.get("icon", "")))
	check("(B) sans apparence : l'emplacement Arme montre l'arme portée", slot.icon == item_icon)
	Profile.set_skin(wt, String(skin.code))
	page.refresh()
	check("(B) apparence « %s » : l'emplacement Arme montre son icône" % String(skin.name), slot.icon == UiTheme.texture(String(skin.icon)))
	check("(B) infobulle : nom de l'apparence et arme portée", slot.tip.contains(String(skin.name)) and slot.tip.contains(Items.display_name(w)))
	check("(B) le héros porte l'apparence (code de l'arme affichée)", Profile.weapon_code() == String(skin.code))
	# modèle de base d'un type d'arme (sans nom) : un nom lisible quand même
	var base: Dictionary = GameData.weapon_type(wt).get("weapons", [{}])[0]
	Profile.set_skin(wt, String(base.get("code", "")))
	page.refresh()
	check("(B) modèle de base : icône du modèle et nom « modèle 1 »", slot.icon == UiTheme.texture(String(base.get("icon", ""))) and slot.tip.contains("modèle 1"))
	Profile.skins = skins_was
	page.queue_free()
	await get_tree().process_frame
