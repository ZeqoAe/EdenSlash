extends Node
## Passe P11 : temps pour tuer (TTK) un boss selon la puissance du héros. Une run est reconstituée (équipement du
## hub, trouvailles de la carte, enclume, niveau, cartes tirées comme le pilote automatique, trophées), puis le
## héros, en aide au combat « Bot » du jeu, entre dans l'arène du boss et frappe jusqu'à sa mort.
##   godot --headless --fixed-fps 60 --path game res://tools/boss_ttk.tscn -- --epoch=1 --stage=1 --class=warrior
##         --hub=new|E.C.N[.G] --level=15 --cards=15 --trophies=4 --finds=0.7 --anvil=1 [--seed=1] [--max=600]
##         [--human=0.5] [--pure]
##   Donjon / Ruée : --mode=dungeon --zone=<zone|rush> --diff=0..2 [--floor=N] (kit du préréglage, une carte par salle)
##   [--boss=<id>] : donjon à la carte d'un boss de la bibliothèque (BossLibrary, passe M2)
## Sans --human : héros invincible (on ne mesure que ses dégâts) ; avec : il encaisse la part de coups non évitée et
## peut mourir (rage du boss comprise). --pure : boss sans mécaniques de salle (DPS du héros seul).
## Ligne lue par tools/boss_ttk.py : « [ttk] … ». Profil jetable : variable EDEN_PROFILE (le vrai n'est jamais touché).

var epoch := 1
var stage := 1
var cid := "warrior"
var hub := "new"
var level := 15
var n_cards := 15
var n_trophies := 0
var finds := 0.0
var anvil := 0
var max_t := 600.0
var human := -1.0
var mode := "survival"
var zid := "limestone"
var diff := 0
var floor_n := -1
var _taken := 0.0
var _max_hit := 0.0
var _hp_last := 0.0
var boss_id := ""  # donjon à la carte (passe M2) : boss de la bibliothèque (sa zone est prise)
var world: Node
const TOTEM_TIME := 8.0


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=")
		if kv.size() < 2:
			continue
		match kv[0]:
			"epoch": epoch = int(kv[1])
			"stage": stage = int(kv[1])
			"class": cid = kv[1]
			"hub": hub = kv[1]
			"level": level = int(kv[1])
			"cards": n_cards = int(kv[1])
			"trophies": n_trophies = int(kv[1])
			"finds": finds = float(kv[1])
			"anvil": anvil = int(kv[1])
			"max": max_t = float(kv[1])
			"human": human = float(kv[1])
			"mode": mode = kv[1]
			"zone": zid = kv[1]
			"diff": diff = int(kv[1])
			"floor": floor_n = int(kv[1])
			"boss": boss_id = kv[1]
			"seed": seed(int(kv[1]))
	Settings.reset_all(false)
	Profile.selected_class = cid
	Profile.save_profile()  # équipement de départ d'un compte neuf (une fois par classe)
	if hub != "new":
		Profile.install_gear(StarterGear.scenario(hub, cid))
	if mode == "dungeon":
		if BossLibrary.has(boss_id):
			zid = Dungeons.boss_zone(boss_id)
		Tower.start_dungeon(cid, zid, diff, [], boss_id)
		for i in n_cards:  # une carte par salle avant le boss
			_pick(Run.roll_cards(3))
	else:
		Run.start_survival(cid, epoch)
		Run.stage = stage
		Run.zone_id = Epochs.zone(epoch, stage)
		Run.hero_level = level
		Run.max_level = level
		_run_finds()
		for i in n_cards:
			_pick(Run.roll_cards(3, Run.skills.is_empty()))
		for i in n_trophies:
			var offer := SlotChests.trophy_offer(epoch, stage, 3)
			if not offer.is_empty():
				Run.add_trophy(offer.pick_random())
	if human >= 0.0:
		Run.test_taken = 1.0 - clampf(human, 0.0, 0.95)
	world = load("res://scenes/world.tscn").instantiate()
	get_tree().root.add_child.call_deferred(world)
	await get_tree().create_timer(3.0).timeout
	var p: Player = world.player
	var d: RunDirector = world.director
	world.cards._queue.clear()
	world.cards._show_next()
	# aide au combat « Bot » du jeu (déplacement, attaques, sorts et enchaînements automatiques) : le pilote de
	# mesure (--autoplay) ne frappe qu'au contact et lance ses sorts au hasard, deux à trois fois moins de dégâts
	# qu'un joueur en aide « Détente » (journal réel)
	if "--autoplay" in OS.get_cmdline_user_args():
		p.autoplay = true
	else:
		for k in Settings.PRESETS.bot.game:
			Settings.data["game"][k] = Settings.PRESETS.bot.game[k]
	if human < 0.0:
		p.dev_invincible = true
	world.revives_left = 0
	if mode == "dungeon":
		d.tower.begin(floor_n if floor_n > 0 else Tower.top())
		level = p.level
	else:
		p.level = level
		p.recalc_stats()
		p.hp = p.max_hp
		d.time = 300.0  # (hors rage)
		d.debug_enter_dungeon()
	var boss: Monster = d._boss
	if boss == null:
		print("[ttk] erreur : pas de boss")
		get_tree().quit()
		return
	if "--pure" in OS.get_cmdline_user_args() and boss.brain:
		boss.brain.mechanics = []
		boss.brain.bricks = []
		boss.brain._reflect_timer = 1.0e9
	await get_tree().physics_frame  # PV définitifs (Menace appliquée en différé)
	var hp0 := boss.max_hp
	# dégâts subis (en PV max du héros par minute, et le plus gros coup) : avec --human seulement (sinon invincible)
	_hp_last = p.hp
	p.health_changed.connect(func(now, _m):
		if now < _hp_last:
			_taken += _hp_last - now
			_max_hit = maxf(_max_hit, _hp_last - now)
		_hp_last = now)
	var t := 0.0
	var res := "temps"
	var shield_t := 0.0
	var crystal_t := 0.0
	var shot_at := -1.0
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot="):
			shot_at = float(a.trim_prefix("--shot="))
			if mode != "dungeon":
				d._boss_time = Epochs.boss_rage_at(stage) + 50.0 - shot_at  # rage du boss en cours au moment de la capture
	while t < max_t:
		await get_tree().physics_frame
		var dt := get_physics_process_delta_time()
		t += dt
		# totems (bouclier du boss) : l'aide « Bot » ne vise que le boss ; un joueur casse les totems en quelques
		# secondes : la sonde les détruit après TOTEM_TIME de bouclier
		if shot_at > 0.0 and t >= shot_at:
			# capture (sans --headless) : barre du boss avec son repère de phase, horloge de la rage du boss
			shot_at = -1.0
			DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://shots"))
			get_viewport().get_texture().get_image().save_png("user://shots/p11_boss.png")
			print("[ttk] capture user://shots/p11_boss.png")
		shield_t = shield_t + dt if is_instance_valid(boss) and boss.shielded else 0.0
		if shield_t > TOTEM_TIME and boss.brain:
			for tt in boss.brain._totems:
				if is_instance_valid(tt) and not tt.is_dead:
					tt.take_damage(tt.max_hp * 10.0 + 1.0, p)
			shield_t = 0.0
		# cristaux de soin (bibliothèque de boss, passe M2) : cassés comme les totems, après TOTEM_TIME
		var crys := get_tree().get_nodes_in_group("monsters").filter(func(m): return m.display_name == "Cristal de soin" and not m.is_dead)
		crystal_t = crystal_t + dt if not crys.is_empty() else 0.0
		if crystal_t > TOTEM_TIME:
			for c in crys:
				c.take_damage(c.max_hp * 10.0 + 1.0, p)
			crystal_t = 0.0
		if not is_instance_valid(boss) or boss.is_dead:
			res = "tué"
			break
		if p.is_dead:
			res = "mort"
			break
	var mag := String(p.cls.get("dmg_type", "phys")) == "mag"
	var left := boss.hp if is_instance_valid(boss) and not boss.is_dead else 0.0
	print("[ttk] mode=%s époque=%d carte=%d zone=%s diff=%d classe=%s hub=%s niveau=%d cartes=%d trophées=%d trouvailles=%.1f enclume=%d résultat=%s ttk=%.1f pv_boss=%.0f boss_niv=%d dps=%.0f atk=%.0f pv=%.0f rage=%d boss=%s subis_min=%.2f coup_max=%.2f" % [
		mode, epoch, stage, Run.zone_id, diff, cid, hub, level, n_cards, Run.trophies.size(), finds, anvil, res, t, hp0,
		boss.level if is_instance_valid(boss) else 0, (hp0 - left) / maxf(t, 0.1), p.matk if mag else p.atk, p.max_hp,
		d._boss_rage, Tower.dungeon_boss if Tower.dungeon_boss != "" else "-",
		_taken / maxf(p.max_hp, 1.0) / maxf(t / 60.0, 0.01), _max_hit / maxf(p.max_hp, 1.0)])
	get_tree().quit()


## Trouvailles de la run : la part [member finds] des emplacements reçoit la pièce mythique +0 de la carte
## (coffres d'emplacement) quand elle vaut mieux que celle du hub ; l'enclume ajoute +4 sur [member anvil] emplacements.
func _run_finds() -> void:
	var kit := StarterGear.scenario("%d.%d.0" % [epoch, stage], cid)
	var i := 0
	for slot in kit:
		i += 1
		if float(i) / float(kit.size()) > finds + 0.001:
			break
		var cur: Dictionary = Profile.equipped.get(slot, {})
		if cur.is_empty() or Items.rating(kit[slot]) > Items.rating(cur):
			Profile.equipped[slot] = kit[slot]
	var slots := Profile.equipped.keys()
	for k in mini(anvil, slots.size()):
		Run.slot_bonus[String(slots[k])] = 4


## Carte choisie comme le pilote automatique : une compétence tant qu'il en manque, sinon au hasard.
func _pick(options: Array) -> void:
	if options.is_empty():
		return
	var skills := options.filter(func(o): return String(o.get("type", "")) == "skill")
	Run.apply_card(skills[0] if not skills.is_empty() and Run.skills.size() < 4 else options.pick_random())
