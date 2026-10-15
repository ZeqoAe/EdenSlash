extends Node
## Captures du marchand de run (Boutique, Vendre) et de la forge de run : user://shots/merchant_*.png.
## godot --path game res://tests/shot_merchant.tscn   (APPDATA détourné : le test ne sauvegarde rien chez le joueur)


func _shot(name: String) -> void:
	await get_tree().create_timer(0.7).timeout
	DirAccess.make_dir_recursive_absolute("user://shots")
	get_viewport().get_texture().get_image().save_png("user://shots/merchant_%s.png" % name)


func _ready() -> void:
	Training.active = true
	Settings.reset_all()
	Profile.reset_all()
	Profile.in_run = true
	Profile.gold = 800
	Profile.materials["crystal"] = 40
	for i in 8:
		Profile.add_item(Items.generate(20 + i, randf_range(-0.5, 1.0)))
	for k in ["drill", "drill", Craft.stone_key("lucky"), Craft.stone_key("safety"), Craft.BLESSED, Craft.fortify_key("power", 20), Craft.fortify_key("guard", 20),
			Craft.gem_key("ruby", 1), Craft.gem_key("garnet", 0), Craft.gem_key("garnet", 0), Craft.gem_key("garnet", 0), Craft.scroll_key("violence", 1)]:
		Profile.add_bag(k)
	var ui := MerchantUI.new()
	add_child(ui)
	ui.setup(null, null)
	ui.open()
	await _shot("boutique")
	ui._screen.show_page(1)
	await _shot("vendre_vide")
	ui._screen.page(1).grid.select_up_to_rarity(1)
	await _shot("vendre")
	ui.close_ui()
	ui.open_forge(Profile.inventory[0])
	await _shot("forge")
	ui._forge.page(0).grid.clear_selection()
	await _shot("forge_vide")
	get_tree().quit()
