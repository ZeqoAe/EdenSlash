class_name RushDirector
extends TowerDirector
## Déroulement de la Ruée des boss (passe M6, voir Rush) : huit salles de boss de la bibliothèque à la suite, une carte et un
## soin partiel entre deux (aucun avec « Sans répit »), la progression « Boss 3/8 » à l'horloge du HUD, le boss suivant dans
## l'objectif (« ??? » à l'aveugle). Prolonge TowerDirector (salle, carte, escalier, alliés) ; seul le boss change.


## Salle [param f] : celle de TowerDirector, puis le boss du tirage (PV fixes du palier, modificateurs) à la place du
## boss de zone, sans renforts génériques (ses invocations sont ses mécaniques).
func begin(f: int) -> void:
	var p := d.player
	var ratio := p.hp / maxf(p.max_hp, 1.0)
	super.begin(f)
	if Rush.has("no_heal") and f > Tower.start_floor:
		p.hp = maxf(1.0, p.max_hp * ratio)  # Sans répit : les PV d'avant la salle (le niveau a pu changer)
		p.health_changed.emit(p.hp, p.max_hp)
	if p.autoplay:
		print("[ruée] boss %d/%d · %s · niveau %d · PV %d%%" % [f, Tower.top(), Rush.boss_at(f), Tower.level_for(f), roundi(100.0 * p.hp / maxf(p.max_hp, 1.0))])


func _spawn_boss(z: Dictionary, lvl: int) -> void:
	var f := Tower.floor_n
	var bid := Rush.boss_at(f)
	if bid == "":
		super._spawn_boss(z, lvl)
		return
	_boss = BossLibrary.spawn(bid, Tower.dungeon_diff, {"director": d, "pos": _center, "level": lvl + 1,
		"hp": Rush.boss_hp(f, lvl + 1, Tower.dungeon_diff, Tower.allies.size()),
		"atk_mult": Tower.monster_atk_mult(f, -1, true) * Rush.atk_mult()})
	if _boss == null:
		super._spawn_boss(z, lvl)
		return
	_boss.xp_reward = 0
	_adds_on = false
	boss_t0 = BestTimes.clock  # fil des temps (lot DNG-3)
	if _boss.brain and Rush.pace_mult() < 1.0:
		_boss.brain.pace *= Rush.pace_mult()  # Boss enragés : mécaniques plus fréquentes
	d.message.emit("Boss %d / %d · %s\n%s" % [f, Tower.top(), BossLibrary.full_name(bid), BossLibrary.intro(bid)], 4.5)


func _cleared() -> void:
	var f := Tower.floor_n
	if f >= Tower.top():
		Tower.reached = f
		_free_hero()
		phase = "done"
		d.message.emit("RUÉE TERMINÉE !\nLes %d boss sont tombés" % Tower.top(), 5.0)
		d.world.tower_end("victoire")
		return
	super._cleared()


func objective_text() -> String:
	var f := Tower.floor_n
	var next := Rush.shown_name(f + 1, f)
	match phase:
		"fight":
			if is_instance_valid(_boss) and not _boss.is_dead:
				return "Vaincs %s%s" % [BossLibrary.short_name(Rush.boss_at(f)), (" · ensuite : %s" % next) if next != "" else " · dernier boss"]
		"cards":
			return "Boss %d vaincu · Choisis une carte" % f
		"stairs":
			return "Boss suivant : %s [%s]" % [next, Settings.action_label("interact", 1)]
	return super.objective_text()


## Sous-ligne du HUD : le boss suivant (« ??? » à l'aveugle) et la difficulté.
func sub_text() -> String:
	var f := Tower.floor_n
	var next := Rush.shown_name(f + 1, f)
	return "%s · %s" % [("Ensuite : " + next) if next != "" else "Dernier boss", Dungeons.DIFF_NAMES[Tower.dungeon_diff]]


## Horloge du HUD : « Boss 3/8 ».
func clock_text() -> String:
	return "Boss %d/%d" % [Tower.floor_n, Tower.top()]


# --- Ruée chronométrée (lot DNG-3, BM-DNG P1-10) ----------------------------------------------------
var boss_t0 := 0.0  # BestTimes.clock à l'apparition du boss en cours


## Fil des temps : une ligne par boss du tirage, {n, name, state ("done", "now", "next"), t (s), best (record d'avant, 0 :
## aucun), new (record battu ou premier temps)}. Les boss vaincus d'après BestTimes (boss:rush:<boss>:<diff>), celui en cours à
## l'horloge de la partie, les suivants par leur nom (« ??? » à l'aveugle).
func trail() -> Array:
	var out: Array = []
	var f := Tower.floor_n
	var diff := Tower.dungeon_diff
	for i in range(1, Tower.top() + 1):
		var bid := Rush.boss_at(i)
		var row := {"n": i, "name": Rush.shown_name(i, f), "state": "next", "t": 0.0, "best": BestTimes.best(BestTimes.boss_key("rush", bid, diff)), "new": false}
		if i < f or (i == f and (not is_instance_valid(_boss) or _boss.is_dead) and phase != "fight"):
			var e := BestTimes.entry(BestTimes.boss_key("rush", bid, diff))
			row.state = "done"
			row.t = float(e.get("t", 0.0))
			row.best = float(e.get("best", row.best))
			row.new = bool(e.get("new", false))
		elif i == f:
			row.state = "now"
			row.t = maxf(0.0, BestTimes.clock - boss_t0) if is_instance_valid(_boss) else 0.0
		out.append(row)
	return out


## Temps total de la Ruée en cours et record du tirage (0 : aucun).
func total_and_best() -> Array:
	return [BestTimes.clock, BestTimes.best(BestTimes.rush_key(Rush.seed, Tower.dungeon_diff))]
