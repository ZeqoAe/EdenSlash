extends Node
## Lot SVX-1 du Survivant (conception/survivor/R_SVX1.md) : la horde (SV-H1) et la lisibilité du chaos (SV-H2). Vérifie :
## - la horde : plan de la minute (vivants, horde finale), monstres ordinaires plus petits, sans collision physique, places
##   d'attaque bornées, croix au sol avant chaque arrivée, densité réelle autour du héros dans une vraie carte, niveaux de
##   détail et ombres selon la distance (coût borné), rien de tout ça hors du Survivant ;
## - la lisibilité : un seul nombre de dégâts par cible (qui additionne), 30 nombres au plus, « EXÉCUTÉ » en croix, sorts du
##   héros à 40 % d'opacité au plus (moins quand ils s'empilent, moins avec « Réduire les effets »), héros contouré, décor
##   tramé autour du héros, barre de cible réservée aux élites, géants et boss.
## godot --headless --path game res://tests/test_svx1.tscn

const WORLD := "res://scenes/world.tscn"

var fails := 0


func check(label: String, ok: bool) -> void:
	print(("OK    " if ok else "ÉCHEC ") + label)
	if not ok:
		fails += 1


func _ready() -> void:
	if name == "Svx1Driver":
		_run.call_deferred()
		return
	var d: Node = (load("res://tests/test_svx1.gd") as GDScript).new()
	d.name = "Svx1Driver"
	get_tree().root.add_child.call_deferred(d)


func _wait(secs: float) -> void:
	await get_tree().create_timer(secs, true, false, true).timeout


func _until(cond: Callable, limit: float, label := "") -> bool:
	var t := 0.0
	while t < limit:
		if cond.call():
			return true
		await _wait(0.1)
		t += 0.1
	if label != "":
		print("   (délai dépassé : %s)" % label)
	return cond.call()


func _run() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Settings.reset_all()
	Profile.selected_class = "warrior"
	Profile.reset_all()
	Profile.in_run = false
	seed(11)
	_plan()
	_defaults()
	await _numbers()
	_opacity()
	_target_bar()
	await _world_run()
	print("\n%s (%d échec(s))" % ["TOUT EST OK" if fails == 0 else "ÉCHECS", fails])
	Engine.time_scale = 1.0
	get_tree().paused = false
	Profile.reset_all()
	get_tree().quit(1 if fails > 0 else 0)


# --- règles ----------------------------------------------------------------------------------------------------------------
func _plan() -> void:
	var a0 := int(SurvivorDirector.spawn_plan(0.0).alive_max)
	var a10 := int(SurvivorDirector.spawn_plan(600.0).alive_max)
	var fin := int(SurvivorDirector.spawn_plan(SurvivorDirector.FINAL_HORDE_AT + 1.0).alive_max)
	check("vivants au plus : %d à 0:00, %d à 10:00, %d pendant la horde finale (avant : 18 → 110)" % [a0, a10, fin], a0 >= 25 and a10 >= 120 and fin >= 250)
	check("meutes dès l'ouverture : une toutes les %.1f s (avant : 6 s)" % float(SurvivorDirector.spawn_plan(0.0).pack_every),
		float(SurvivorDirector.spawn_plan(0.0).pack_every) <= 3.0)
	var ring: Array = Survivor.HORDE_RING
	check("arrivées à l'écran (%s m, avant 24-31 m hors de la vue), annoncées %.1f s avant" % [ring, Survivor.HORDE_MARK],
		float(ring[1]) <= 20.0 and Survivor.HORDE_MARK >= 0.5)
	check("monstres ordinaires plus petits (× %.2f), élites × %.2f" % [Survivor.HORDE_SCALE, Survivor.HORDE_SCALE_ELITE],
		Survivor.HORDE_SCALE <= 0.75 and Survivor.HORDE_SCALE_ELITE > Survivor.HORDE_SCALE)
	var s: Array = Survivor.HORDE_SHARE
	check("compensation monstre par monstre (PV ×%.2f, dégâts ×%.2f, expérience ×%.2f, or ×%.2f) et %s places d'attaque" % [s[0], s[1], s[2], s[3], str(Survivor.ATTACK_SLOTS)],
		s.all(func(x): return float(x) > 0.0 and float(x) < 1.0) and int(Survivor.ATTACK_SLOTS[0]) > 0 and int(Survivor.ATTACK_SLOTS[1]) >= int(Survivor.ATTACK_SLOTS[0]))
	for k in ["alive_final", "horde_scale", "horde_ring", "horde_mark", "horde_share", "attack_slots", "lod_near", "lod_far", "shadow_near"]:
		if not ModeRules.SURVIVOR.has(k):
			check("règle « %s » dans le profil survivor de ModeRules (mode dev)" % k, false)


## Hors du Survivant, rien ne change : monstre normal, pas de places d'attaque, décor non tramé.
func _defaults() -> void:
	Survivor.reset()
	var m := Monster.new()
	check("monstre par défaut : collisions physiques, réflexion à chaque image", not m.lite and m.lod == 0)
	m.free()
	check("hors Survivant : places d'attaque sans limite", Monster.attack_slots == 0)
	check("hors Survivant : barre de cible pour tout monstre", SurvivorDirector.shows_target_bar(Monster.new()))


# --- nombres de dégâts ------------------------------------------------------------------------------------------------------
func _labels(merged: bool) -> Array:
	return get_tree().current_scene.get_children().filter(func(n): return n is DamageNumber and not n.is_queued_for_deletion() and (n as DamageNumber).merged == merged)


func _numbers() -> void:
	var scene := get_tree().current_scene
	var target := Node3D.new()
	scene.add_child(target)
	Survivor.active = true
	DamageNumber.alive = 0
	for v in [10.0, 25.0, 40.0, 7.0, 18.0]:
		DamageNumber.spawn(target, v, v == 40.0, false)
	for i in 3:  # (quelques images : le nombre se met à jour à la suivante, AGG_STEP s après le premier coup)
		await _wait(0.2)
	var labs := _labels(true)
	check("Survivant : 5 coups sur une cible = UN nombre (%d)" % labs.size(), labs.size() == 1)
	if labs.size() == 1:
		var n: DamageNumber = labs[0]
		check("il additionne : %s (100, critique)" % n.text, int(n.total) == 100 and n.text == "100!")
	var many: Array = []
	for i in 40:
		var t := Node3D.new()
		scene.add_child(t)
		t.position = Vector3(i, 0, 0)
		many.append(t)
		DamageNumber.spawn(t, 5.0, false, false)
	check("40 cibles touchées : %d nombres à l'écran (au plus %d)" % [_labels(true).size(), Survivor.NUMBERS_MAX], _labels(true).size() <= Survivor.NUMBERS_MAX and DamageNumber.alive <= Survivor.NUMBERS_MAX)
	await _wait(DamageNumber.AGG_LIFE + DamageNumber.AGG_FADE + 0.3)
	check("les nombres s'effacent après le dernier coup (%d restent)" % _labels(true).size(), _labels(true).is_empty())
	var t2 := Node3D.new()
	scene.add_child(t2)
	DamageNumber.spawn_text(t2, "EXÉCUTÉ", Color.RED)
	var texts := scene.get_children().filter(func(n): return n is DamageNumber and not n.merged and n.text == DamageNumber.EXECUTE_ICON)
	check("« EXÉCUTÉ » devient une croix (%d)" % texts.size(), texts.size() == 1)
	Survivor.active = false
	DamageNumber.spawn(target, 10.0, false, false)
	DamageNumber.spawn(target, 12.0, false, false)
	check("hors Survivant : un chiffre par coup, comme avant", _labels(false).filter(func(n): return n.text in ["10", "12"]).size() == 2)
	for t in many + [target, t2]:
		t.queue_free()
	await _wait(1.2)


# --- effets du héros -------------------------------------------------------------------------------------------------------
func _opacity() -> void:
	EdenFx._mine_live = 0
	var one := EdenFx.survivor_opacity()
	EdenFx._mine_live = 6
	var six := EdenFx.survivor_opacity()
	EdenFx._mine_live = 0
	check("sorts du héros : %.0f %% d'opacité au plus, %.0f %% quand 6 autres sont à l'écran" % [one * 100, six * 100],
		one <= 0.4 + 0.001 and six < one and six >= EdenFx.OPACITY_MIN)
	Settings.data["interface"]["fx_particles"] = "reduced"
	var red := EdenFx.survivor_opacity()
	Settings.data["interface"]["fx_particles"] = "all"
	check("« Réduire les effets » : %.0f %%" % (red * 100), red < one)


func _target_bar() -> void:
	Survivor.active = true
	var plain := Monster.new()
	var elite := Monster.new()
	elite.is_elite = true
	var boss := Monster.new()
	boss.is_boss = true
	var giant := GiantMonster.new()
	check("barre de cible : jamais pour un monstre ordinaire, toujours pour élite, boss et géant",
		not SurvivorDirector.shows_target_bar(plain) and SurvivorDirector.shows_target_bar(elite) and SurvivorDirector.shows_target_bar(boss)
		and SurvivorDirector.shows_target_bar(giant))
	for m in [plain, elite, boss, giant]:
		m.free()
	Survivor.active = false


# --- vraie carte ----------------------------------------------------------------------------------------------------------
func _world() -> Node:
	var s := get_tree().current_scene
	if s != null and s.has_method("end_run") and s.get("director") != null and s.director.player != null and s.get("hud") != null:
		return s
	return null


func _world_run() -> void:
	get_tree().paused = false
	Profile.in_run = false
	var dist := float(Settings.get_v("camera", "distance"))
	Survivor.start("warrior", "limestone")
	get_tree().change_scene_to_file.call_deferred(WORLD)
	await _wait(0.5)
	if not await _until(func(): return _world() != null, 90.0, "monde"):
		check("monde du Survivant chargé", false)
		return
	var w := _world()
	if await _until(func(): return w.cards.is_open(), 90.0, "choix de départ"):
		w.cards._opened_at -= CardPicker.CONFIRM_DELAY_MS
		w.cards._choose(0)
	w.player.autoplay = true
	w.player.dev_invincible = true
	var d: RunDirector = w.director
	await _wait(1.0)
	check("caméra plus haute en Survivant : %.1f (réglage %.1f × %.1f)" % [w.rig.distance, dist, Survivor.CAM_ZOOM], is_equal_approx(w.rig.distance, minf(28.0, dist * Survivor.CAM_ZOOM)))
	check("plafond du directeur = plan de la minute (%d ≥ %d)" % [d._hard_cap(), int(SurvivorDirector.spawn_plan(d.time).alive_max)],
		d._hard_cap() >= int(SurvivorDirector.spawn_plan(d.time).alive_max))
	check("escouades : arrivées à l'écran annoncées par une croix, plafonds par rôle × %.1f" % d.spawner.role_cap_mult,
		d.spawner.mark_time > 0.0 and float(d.spawner.ring[1]) <= 20.0 and d.spawner.role_cap_mult > 1.0)
	# 10:00 de carte, puis la horde monte (le héros, invincible, se bat au pilote)
	d.time = 600.0
	d.sv._next = d.sv._events.size()  # (sans gardien : pendant son combat, la horde se calme ; mesuré à part)
	var marks0 := SpawnMark.made
	Engine.time_scale = 2.0
	var max_attack := 0
	var max_slots := 0
	var max_numbers := 0
	var bad_bar := 0
	var peak := {"alive": 0, "near": 0}
	for i in 120:  # ≈ 24 s de carte
		await _wait(0.1)
		max_attack = maxi(max_attack, Monster.attacking)
		max_slots = maxi(max_slots, Monster.attack_slots)
		max_numbers = maxi(max_numbers, DamageNumber.alive)
		var c := d.sv.density_now()
		if int(c.near) > int(peak.near):
			peak = c
		var ref: Object = w.hud._target_ref.get_ref() if w.hud._target_ref else null
		if w.hud._target_box.visible and ref != null and not SurvivorDirector.shows_target_bar(ref):
			bad_bar += 1
	Engine.time_scale = 1.0
	print("   10:00 + %.0f s : %d vivants, %d à moins de 15 m (pic), %d croix, %d nombres au plus, %d attaquants au plus" % [
		d.time - 600.0, int(peak.alive), int(peak.near), SpawnMark.made - marks0, max_numbers, max_attack])
	check("horde : %d monstres à moins de 15 m du héros au pic (avant : 11 en moyenne, 40 au plus à 10:00)" % int(peak.near), int(peak.near) >= 60)
	check("croix au sol avant les arrivées (%d)" % (SpawnMark.made - marks0), SpawnMark.made - marks0 >= 20)
	check("places d'attaque : %d monstres frappent en même temps au plus (≤ %d à cette minute, entre %d et %d)" % [max_attack, max_slots,
		int(Survivor.ATTACK_SLOTS[0]), int(Survivor.ATTACK_SLOTS[1])], max_attack <= max_slots and max_slots > int(Survivor.ATTACK_SLOTS[0]) and max_slots < int(Survivor.ATTACK_SLOTS[1]))
	check("nombres de dégâts : %d à l'écran au plus (≤ %d, dégâts subis compris)" % [max_numbers, Survivor.NUMBERS_MAX + 2], max_numbers <= Survivor.NUMBERS_MAX + 2)
	check("barre de cible jamais sur un monstre ordinaire (%d images)" % bad_bar, bad_bar == 0)
	var mons: Array = get_tree().get_nodes_in_group("monsters").filter(func(m): return not (m as Monster).is_dead)
	var horde: Array = mons.filter(func(m): return m.has_meta("sv_horde"))
	var big: Array = mons.filter(func(m): return m.is_elite or m.is_boss or m is GiantMonster)
	check("monstres ordinaires de la horde : sans collision physique (%d / %d)" % [horde.filter(func(m): return m.lite).size(), horde.size()],
		not horde.is_empty() and horde.all(func(m): return m.lite))
	check("élites, géants et boss gardent leurs collisions (%d)" % big.size(), big.all(func(m): return not m.lite))
	check("monstres ordinaires plus petits que leur modèle d'origine", horde.all(func(m): return float(m.data.get("scale", 1.0)) < float(GameData.monster(int(m.data.id)).get("scale", 1.0))))
	var tallest := 0.0
	for m in horde:
		# hauteur au repos (mesurée à l'apparition, Monster._model_h) × échelle : l'animation déplace les os
		tallest = maxf(tallest, float(Monster._model_h.get(String(m.data.model), 0.0)) * m.model.scale.y)
	check("aucun monstre de la horde plus haut que %.2f m (%.0f %% du héros) : le plus grand %.2f m" % [Monster.lite_height, 100.0 * Survivor.HORDE_HEIGHT, tallest],
		Monster.lite_height > 0.3 and tallest <= Monster.lite_height * 1.1)  # (1,08 : gonflement d'un coup reçu)
	# niveaux de détail : près du héros chaque image ; loin, une sur 2 ou 4, sans ombre
	d.sv._lod_t = 0.0
	d.sv._update_lod(0.0)
	var hero: Vector3 = w.player.global_position
	var lod_ok := horde.filter(func(m): return m.lod == 0).size() <= Survivor.LOD_FULL
	var far_n := 0
	var shadow_ok := true
	var nearest: Monster = null
	var nearest_d := INF
	for m in horde:
		var dd := Vector2(m.global_position.x - hero.x, m.global_position.z - hero.z).length()
		if dd < nearest_d:
			nearest_d = dd
			nearest = m
		if dd > Survivor.LOD_NEAR + 0.5 and m.lod == 0:
			lod_ok = false
		if dd > Survivor.LOD_FAR + 0.5:
			far_n += 1
			if m.lod != 2:
				lod_ok = false
		if dd > Survivor.SHADOW_NEAR + 0.5 and m.model != null:
			for gi in m.model.find_children("*", "GeometryInstance3D", true, false):
				if (gi as GeometryInstance3D).cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
					shadow_ok = false
	if nearest != null and nearest_d < Survivor.LOD_NEAR - 0.5:
		lod_ok = lod_ok and nearest.lod == 0
	check("niveaux de détail selon la distance : %d monstres réfléchissent à chaque image (≤ %d), %d loin" % [
		horde.filter(func(m): return m.lod == 0).size(), Survivor.LOD_FULL, far_n], lod_ok)
	check("pas d'ombre portée au loin", shadow_ok)
	# lisibilité en vraie carte
	var meshes: Array = w.player.model.find_children("*", "MeshInstance3D", true, false)
	check("héros contouré (%d / %d maillages)" % [meshes.filter(func(mi): return mi.material_overlay == HeroOutline.material()).size(), meshes.size()],
		not meshes.is_empty() and meshes.filter(func(mi): return mi.material_overlay == HeroOutline.material()).size() >= meshes.size() - 1)
	var fx: Array = get_tree().current_scene.get_children().filter(func(n): return n is EdenFx and n.mine)
	check("effets des sorts du héros à %d %% d'opacité au plus (%d effets vus)" % [roundi(100.0 * Survivor.FX_OPACITY), fx.size()],
		fx.all(func(f): return f.opacity <= Survivor.FX_OPACITY + 0.001))
	var fade = RenderingServer.global_shader_parameter_get("hero_fade")
	check("décor tramé autour du héros (rayon %s m)" % str(fade), fade == null or is_equal_approx(float(fade), Survivor.FOLIAGE_FADE))
	# fin : rien ne suit le héros dans un autre mode
	w.end_run("abandon")
	await _wait(1.0)
	Survivor.reset()
	var fade2 = RenderingServer.global_shader_parameter_get("hero_fade")
	check("après le Survivant : décor normal, places d'attaque sans limite", (fade2 == null or is_equal_approx(float(fade2), 0.0)) and Monster.attack_slots == 0)
	get_tree().paused = false
	Profile.end_run_survival()
