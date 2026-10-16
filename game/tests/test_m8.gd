extends Node
## Passe M8 (équilibre de la Tour entre classes) : multiplicateurs de la Tour (TowerBalance, data/tower_solo.json) pour les
## 60 classes, bornes du temps pour tuer entre classes (mesures rangées dans le fichier, une fois corrigées : max / min
## ≤ MAX_RATIO à chaque boss de référence), multiplicateur appliqué au héros dans la Tour seulement, coups de boss de la Tour
## plafonnés, esquive du pilote de mesure (PilotDodge) sans effet en jeu.
## godot --headless --path game res://tests/test_m8.tscn

const MAX_RATIO := 2.5

var fails := 0


func check(label: String, ok: bool) -> void:
	print(("OK    " if ok else "ÉCHEC ") + label)
	if not ok:
		fails += 1


func _ready() -> void:
	Settings.reset_all()
	Profile.reset_all()
	Profile.selected_class = "bard"
	_data()
	await _scene()
	print("TOUT EST OK (0 échec(s))" if fails == 0 else "ÉCHECS : %d" % fails)
	get_tree().quit(fails)


func _data() -> void:
	var raw = JSON.parse_string(FileAccess.get_file_as_string(TowerBalance.PATH))
	check("data/tower_solo.json lisible", raw is Dictionary and (raw as Dictionary).has("mult") and (raw as Dictionary).has("ttk"))
	if not raw is Dictionary:
		return
	for key in ["mult"]:
		var mult: Dictionary = raw.get(key, {})
		var missing := GameData.classes.keys().filter(func(c): return not mult.has(c))
		check("%s : les 60 classes ont un multiplicateur (%d manquantes)" % [key, missing.size()], missing.is_empty())
		check("%s : multiplicateurs entre 1 et %.1f (jamais de baisse)" % [key, TowerBalance.MAX_MULT],
			mult.values().all(func(v): return float(v) >= 1.0 and float(v) <= TowerBalance.MAX_MULT))
	check("une classe de soutien lente est aidée (Barde)", TowerBalance.solo_mult("bard") > 1.2)
	check("une classe rapide ne l'est pas (Magicien)", is_equal_approx(TowerBalance.solo_mult("magician"), 1.0))
	check("classe inconnue : 1", is_equal_approx(TowerBalance.solo_mult("inconnue"), 1.0))
	# bornes : temps pour tuer mesuré (sans mécaniques, aide « Bot ») divisé par le multiplicateur
	var ttk: Dictionary = raw.ttk
	for f in ["30", "50", "100"]:
		var before: Array = []
		var after: Array = []
		for c in ttk:
			if (ttk[c] as Dictionary).has(f):
				before.append(float(ttk[c][f]))
				after.append(float(ttk[c][f]) / TowerBalance.solo_mult(String(c)))
		if before.size() < 50:
			check("étage %s : mesures des 60 classes (%d)" % [f, before.size()], false)
			continue
		var rb: float = before.max() / maxf(before.min(), 0.1)
		var ra: float = after.max() / maxf(after.min(), 0.1)
		check("boss de l'étage %s : écart max / min des 60 classes %.2f -> %.2f (≤ %.1f)" % [f, rb, ra, MAX_RATIO], ra <= MAX_RATIO and ra <= rb + 0.001)
	# coups de boss de la Tour plafonnés plus bas qu'ailleurs
	check("coups de boss de la Tour plafonnés sous ceux de la bibliothèque", Tower.BOSS_HIT_CAP > 0.0 and Tower.BOSS_HIT_CAP < BossLibrary.HIT_CAP)
	# esquive du pilote : sans effet en jeu
	check("esquive du pilote coupée par défaut", not PilotDodge.enabled)


## Dégâts du héros [param p] comme dans un donjon (indicateur levé le temps du calcul), puis remis tel quel.
func _dmg_as_dungeon(p: Player) -> float:
	var saved := Tower.dungeon
	Tower.dungeon = "limestone"
	p.recalc_stats()
	var v := p.dmg_mult
	Tower.dungeon = saved
	p.recalc_stats()
	return v


## Dégâts du héros [param p] comme dans la Tour (indicateur « donjon » retiré le temps du calcul), puis remis tel quel.
func _dmg_as_tower(p: Player) -> float:
	var saved := Tower.dungeon
	Tower.dungeon = ""
	p.recalc_stats()
	var v := p.dmg_mult
	Tower.dungeon = saved
	p.recalc_stats()
	return v


func _scene() -> void:
	Tower.start("bard", 1, 10)
	var world: Node = load("res://scenes/world.tscn").instantiate()
	get_tree().root.add_child.call_deferred(world)
	await get_tree().create_timer(3.0).timeout
	var p: Player = world.player
	p.dev_invincible = true
	world.cards._queue.clear()
	world.cards._show_next()
	var td: TowerDirector = world.director.tower
	p.recalc_stats()
	# (le bonus de dégâts de départ varie d'une partie à l'autre : le facteur de la Tour se mesure dans UN SEUL monde, en
	# basculant l'indicateur « donjon », jamais en comparant deux mondes tirés séparément)
	var tower_mult := p.dmg_mult
	var as_dungeon := _dmg_as_dungeon(p)
	var boss = td._boss
	check("boss de l'étage 10 en jeu, coups plafonnés à %.0f %% des PV" % (Tower.BOSS_HIT_CAP * 100.0),
		is_instance_valid(boss) and boss.brain != null and is_equal_approx(boss.brain.hit_cap, Tower.BOSS_HIT_CAP))
	# boss tombé sous le sol (vu au pilote : intouchable pour toujours) -> ramené au centre de la salle
	if is_instance_valid(boss):
		boss.global_position = td._center + Vector3(0, -40.0, 0)
		td._rescue_boss()
		check("boss tombé hors de la salle : ramené au centre", boss.global_position.distance_to(td._center) < 2.0)
	# pilote : une zone rouge sur le héros -> il en sort ; coupé -> rien
	var tg := Telegraph.spawn(world, p.global_position + Vector3(1.0, 0, 0), 0.0, {"shape": "circle", "radius": 4.0, "delay": 2.0, "damage": 1.0, "source": boss})
	await get_tree().create_timer(0.5).timeout
	check("pilote coupé : aucune fuite", PilotDodge.threat(p).is_empty())
	PilotDodge.enabled = true
	# le pilote lit PilotDodge.READ des zones (tirage fixe par zone) : une des six zones posées au moins est lue
	var fled := false
	for k in 6:
		PilotDodge._cache.clear()
		var th := PilotDodge.threat(p)
		var away: Vector3 = p.global_position - tg.global_position
		away.y = 0.0
		fled = fled or (not th.is_empty() and (th.dir as Vector3).dot(away.normalized()) > 0.9)
		tg.queue_free()
		if fled:
			break
		tg = Telegraph.spawn(world, p.global_position + Vector3(1.0, 0, 0), 0.0, {"shape": "circle", "radius": 4.0, "delay": 2.0, "damage": 1.0, "source": boss})
		await get_tree().create_timer(0.5).timeout
	check("pilote (--dodge) : fuite hors de la zone rouge", fled)
	PilotDodge.enabled = false
	# hors de la Tour (donjon) : pas de multiplicateur
	world.queue_free()
	await get_tree().create_timer(0.5).timeout
	Tower.start_dungeon("bard", "limestone", 0, [])
	world = load("res://scenes/world.tscn").instantiate()
	get_tree().root.add_child.call_deferred(world)
	await get_tree().create_timer(3.0).timeout
	world.player.recalc_stats()
	var k := tower_mult / maxf(as_dungeon, 0.01)
	check("Tour : dégâts du Barde × son multiplicateur, pas en donjon (%.2f / %.2f = %.2f, attendu %.2f)" % [tower_mult, as_dungeon, k,
		TowerBalance.solo_mult("bard")], absf(k - TowerBalance.solo_mult("bard")) < 0.03)
	# vrai donjon : aucun facteur ; sans l'indicateur « donjon », le même héros au même équipement retrouverait le facteur
	var in_dungeon: float = world.player.dmg_mult
	var as_tower := _dmg_as_tower(world.player)
	check("donjon : pas de multiplicateur de la Tour (%.2f ; en Tour : %.2f)" % [in_dungeon, as_tower],
		Tower.is_dungeon() and absf(as_tower / maxf(in_dungeon, 0.01) - TowerBalance.solo_mult("bard")) < 0.03)
	Tower.active = false
	world.queue_free()
	await get_tree().create_timer(0.3).timeout
