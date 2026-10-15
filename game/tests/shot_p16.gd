extends Node
## Captures de la passe P16 (conception/nuit_15_10/captures/p16_*.png) : Héros > Apparence du samouraï avec l'aura
## « Roche de Luna de la Lumière des étoiles ardente » (s82815) à deux moments de son cycle, puis l'emplacement « Arme »
## avec une apparence choisie (son icône, plus celle du katana porté).
## APPDATA détourné conseillé : godot --path game res://tests/shot_p16.tscn

const LUNA := "s82815"


func _shot(name: String, wait := 0.8) -> void:
	await get_tree().create_timer(wait).timeout
	var dir := ProjectSettings.globalize_path("res://").path_join("../conception/nuit_15_10/captures").simplify_path()
	DirAccess.make_dir_recursive_absolute(dir)
	get_viewport().get_texture().get_image().save_png(dir.path_join("p16_%s.png" % name))


func _ready() -> void:
	Training.active = true  # rien n'est sauvegardé
	Settings.reset_all()
	Profile.reset_all()
	Profile.selected_class = "samurai"
	Profile._lobby_view()  # préréglage du samouraï (la sauvegarde, qui le ferait, est coupée)
	for x in GameData.auras:
		if String(x.aura.fx) == LUNA:
			Profile.collect(x)
			Profile.set_aura("samurai", String(x.aura.kind), int(x.id))
	var w := Items.generate(30, 0.6, "weapon", "samurai")
	for _k in 50:  # une arme de la classe (un autre type irait en arme secondaire)
		if Profile.can_be_main(w):
			break
		w = Items.generate(30, 0.6, "weapon", "samurai")
	Profile.inventory.append(w)
	Profile.equip(w)
	var lobby: Node = load("res://scenes/lobby.tscn").instantiate()
	add_child(lobby)
	await get_tree().create_timer(2.0).timeout
	var hero: HeroScreen = lobby._hero
	lobby._open_hero("equipment")
	hero.appearance._cat = "aura"
	hero.appearance._slot = "aura"
	hero.show_section("appearance")
	await _shot("1_aura_luna", 2.0)
	await _shot("2_aura_luna_plus_tard", 4.0)
	# apparence d'arme : un modèle de la collection pour les katanas
	var wt := Items.weapon_type_of(w)
	for x in GameData.collection:
		if x.has("skin") and String(x.skin.wtype) in ["", wt]:
			Profile.collect(x)
			Profile.set_skin(wt, String(x.code))
			break
	hero.appearance._cat = "weapon"
	hero.appearance._slot = "weapon"
	hero.appearance.refresh()
	await _shot("3_arme_apparence")
	get_tree().quit()
