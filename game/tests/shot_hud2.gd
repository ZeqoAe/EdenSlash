extends Node
## Lot HUD-2 : captures du HUD en partie v2 (user://shots/hud2_<cas>_<largeur>.png), en 1600×900 puis 1280×720 :
## Survie (Premiers pas, fiche de découverte, fil du butin, compteur de dégâts, combat), profils Compact et Minimal,
## Donjon (combat de boss), Tour, Duel.
## godot --path game res://tests/shot_hud2.tscn -- [survie|donjon|tour|duel|tout]   (APPDATA détourné : rien n'est gardé)

var res := Vector2i(1600, 900)
var world: Node


func _shot(name: String, wait := 0.8) -> void:
	await get_tree().create_timer(wait, true).timeout
	DirAccess.make_dir_recursive_absolute("user://shots")
	var path := "user://shots/hud2_%s_%d.png" % [name, res.x]
	get_viewport().get_texture().get_image().save_png(path)
	print("[hud2] capture %s" % ProjectSettings.globalize_path(path))


func _size(r: Vector2i) -> void:
	res = r
	DisplayServer.window_set_size(r)
	get_window().size = r
	await get_tree().create_timer(0.6).timeout


func _ready() -> void:
	Settings.reset_all()
	Profile.reset_all()
	Profile.selected_class = "warrior"
	var args := OS.get_cmdline_user_args()
	var what := "tout" if args.is_empty() else String(args[0])
	var sizes := [Vector2i(1600, 900), Vector2i(1280, 720)]
	if OS.get_environment("HUD2_RES") != "":
		var p := OS.get_environment("HUD2_RES").split("x")
		sizes = [Vector2i(int(p[0]), int(p[1]))]
	for r in sizes:
		await _size(r)
		if what in ["survie", "tout"]:
			await _survie()
		if what in ["donjon", "tout"]:
			await _donjon()
		if what in ["tour", "tout"]:
			await _mode("tour")
		if what in ["duel", "tout"]:
			await _mode("duel")
	get_tree().quit()


func _boot() -> void:
	world = load("res://scenes/world.tscn").instantiate()
	get_tree().root.add_child.call_deferred(world)
	var t := 0.0
	while t < 40.0 and not (world.get("hud") != null and world.hud.player != null):
		await get_tree().create_timer(0.25).timeout
		t += 0.25
	await get_tree().create_timer(5.0).timeout
	if world.cards.is_open():
		world.cards._queue.clear()
		world.cards._show_next()
	world.player.dev_invincible = true


func _close() -> void:
	world.queue_free()
	Tower.active = false
	Duel.active = false
	Run.active = false
	get_tree().paused = false
	Settings.set_v("interface", "hud_profile", "standard")
	await get_tree().create_timer(0.5).timeout


func _survie() -> void:
	Profile.tutorial = {"mode": "guided", "steps": [], "seen": [], "version": Version.NUMBER}
	Run.start_survival("warrior", 1, 0)
	await _boot()
	var hud: Hud = world.hud
	var p: Player = world.player
	p.add_status("keen", 20.0, p)
	p.add_status("frenzy", 12.0, p)
	p.add_status("purgatory", 8.0, p)
	p.hp = p.max_hp * 0.62
	p.health_changed.emit(p.hp, p.max_hp)
	await _shot("survie_calme", 1.0)
	Run.add_combo_damage(48210.0)
	hud._show_card("cards")
	await get_tree().create_timer(0.6).timeout
	hud.show_message("Butin : Bottes du vent", 1.5)
	hud.show_message("Cristal brisé : des gemmes !", 1.5)
	hud.show_message("Une clé dans les débris ! (2)", 1.5)
	Run.add_combo_damage(1200.0)
	await _shot("survie_carte_butin", 0.5)
	hud.show_message("Rage !\nLes monstres frappent plus fort : file au donjon", 3.0)
	Run.add_combo_damage(800.0)
	await _shot("survie_bandeau", 0.4)
	Settings.set_v("interface", "hud_profile", "compact")
	Run.add_combo_damage(800.0)
	await _shot("profil_compact", 1.0)
	Settings.set_v("interface", "hud_profile", "minimal")
	await _shot("profil_minimal", 1.0)
	Settings.set_v("interface", "hud_profile", "standard")
	await _close()


func _donjon() -> void:
	Profile.tutorial = {"mode": "skip", "steps": [], "seen": [], "version": Version.NUMBER}
	Tower.start_dungeon("warrior", "beluga", 0, [], "latif", Dungeons.ROOMS.size())
	await _boot()
	var d: RunDirector = world.director
	var p: Player = world.player
	var b: Monster = d.tower._boss if d.tower != null else null
	if b != null:
		b.move_speed = 0.0
		b.hp = b.max_hp * 0.62
		var center: Vector3 = d.tower._center
		p.global_position = center + Vector3(0, 0.5, 8.0)
		b.global_position = center + Vector3(0, 0.3, -2.0)
	p.add_status("burn", 6.0, p)
	await _shot("donjon_boss", 2.0)
	await _close()


func _mode(mode: String) -> void:
	Profile.tutorial = {"mode": "skip", "steps": [], "seen": [], "version": Version.NUMBER}
	if mode == "tour":
		Tower.start("warrior", 1, 1)
	else:
		Duel.mode = "free"
		Duel.start("warrior", "knight", 1)
	await _boot()
	if mode == "duel":
		world.player.autoplay = true
	await _shot(mode, 3.0)
	await _close()
