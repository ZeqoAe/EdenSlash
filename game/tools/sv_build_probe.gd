extends Node
## Sonde de builds du Survivant (lot S7, conception/survivor/R_S7.md) : une run de CHOIX (vrai tirage des cartes,
## SurvivorCards) jouée par une stratégie, jusqu'au niveau de 20:00, puis (avec --fight) le combat contre le boss final
## (PV fixes, mécaniques comprises) en aide au combat « Bot » du jeu, héros invincible : on ne mesure que ses dégâts.
##   godot --headless --fixed-fps 60 --path game res://tools/sv_build_probe.tscn -- --class=warrior --strategy=bot
##         --seed=1 [--level=38] [--chests=12] [--free=6] [--fight] [--max=150]
## Stratégies (« types de build » de la mesure de dominance) : pilote (choix du pilote, un peu de hasard), bot (choix strict
## du Bot), set (vise un set de son type d'armure), sorts (sorts d'abord), arme (arme d'abord), pieces (pièces d'abord),
## passifs (paliers +6 / +8 / +10 et évolutions d'abord).
## Ligne lue par tools/sim_survivor.py --probe : « [probe] … ». Profil jetable (APPDATA du processus).

const STRATEGIES := ["pilote", "bot", "set", "sorts", "arme", "pieces", "passifs"]
const GUARDIANS := [5.0, 10.0, 15.0]
const ANVILS := 3

var cid := "warrior"
var strategy := "bot"
var seed_v := 1
var level := 38
var chests := 12
var free_choices := 6
var fight := false
var max_t := 150.0
var target_set := ""
var rng := RandomNumberGenerator.new()


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=")
		match kv[0]:
			"class": cid = kv[1]
			"strategy": strategy = kv[1]
			"seed": seed_v = int(kv[1])
			"level": level = int(kv[1])
			"chests": chests = int(kv[1])
			"free": free_choices = int(kv[1])
			"fight": fight = true
			"max": max_t = float(kv[1])
	Settings.reset_all(false)
	Profile.selected_class = cid
	rng.seed = seed_v
	seed(seed_v)
	SurvivorCards.seed_with(seed_v)
	build()
	if not fight:
		print("[probe] " + line(null, {}))
		get_tree().quit()
		return
	var res := await duel_boss()
	print("[probe] " + line(res.get("player"), res))
	get_tree().quit()


## La run de choix : départ, montées de niveau jusqu'à [member level], coffres tirés dans la disposition de la carte,
## gardiens, enclumes, cartes libres (géants, sanctuaires, marchands) ; une relance quand la meilleure carte est faible.
func build() -> void:
	Survivor.start(cid, "limestone")
	Run.hero_level = 1
	if strategy == "set":
		var armor := String(ClassGear.profile(cid).get("armor", ""))
		var mine: Array = SurvivorPool.sets().filter(func(x): return SurvivorPool.armor_of(String(x)) == armor)
		target_set = String(mine[rng.randi() % mine.size()]) if not mine.is_empty() else ""
	var events: Array = []
	for k in range(1, level):
		events.append({"t": 20.0 * pow(float(k) / float(level - 1), 0.9), "kind": "level", "lv": k + 1})
	var layout: Array = SurvivorDirector.LAYOUT.duplicate()
	for k in mini(chests, layout.size()):
		events.append({"t": rng.randf_range(0.5, 19.5), "kind": "chest", "box": String(layout.pop_at(rng.randi() % layout.size()))})
	for t in GUARDIANS:
		events.append({"t": float(t) + 0.01, "kind": "chest", "box": SurvivorDirector.GUARDIAN_BOX})
	for k in ANVILS:
		events.append({"t": rng.randf_range(2.0, 19.0), "kind": "chest", "box": SurvivorDirector.ANVIL_BOX})
	for k in free_choices:
		events.append({"t": rng.randf_range(1.0, 19.5), "kind": "free"})
	events.sort_custom(func(a, b): return float(a.t) < float(b.t))
	SurvivorCards.minutes_override = 0.0
	_choose(SurvivorCards.first_offer(), func(): return SurvivorCards.first_offer())
	for ev in events:
		SurvivorCards.minutes_override = float(ev.t)
		match String(ev.kind):
			"level":
				Run.hero_level = int(ev.lv)
				_choose(Run.roll_cards(3), func(): return Run.roll_cards(3))
			"chest":
				_choose(SurvivorCards.chest_cards(String(ev.box)))
			"free":
				_choose(Run.roll_cards(3), func(): return Run.roll_cards(3))
	Run.hero_level = level
	SurvivorCards.minutes_override = -1.0


## Note d'une carte pour la stratégie en cours.
func score(o: Dictionary) -> float:
	var t := String(o.get("type", ""))
	var tier := float(Cards.TIER_ORDER.find(String(o.get("tier", "common"))))
	var base := SurvivorCards.score(o)
	var woke := not (o.get("offer", {}).get("passives", []) as Array).is_empty()
	var few_spells := Run.all_skills().size() < 2
	match strategy:
		"pilote":
			return base + rng.randf() * 25.0
		"set":
			if t == "sv_piece" and String(o.slot) in SurvivorPool.SET_SLOT_ORDER:
				return 95.0 if String(o.item.get("set", "")) == target_set else 0.0
			if t == "sv_piece_up" and String(Profile.equipped.get(String(o.slot), {}).get("set", "")) == target_set:
				return base + 10.0
		"sorts":
			if t in ["skill", "chain"]:
				return 100.0
			if t == "upgrade":
				return 80.0 + tier * 3.0
			return base * 0.8
		"arme":
			if t == "sv_weapon":
				return 100.0
			if t == "sv_weapon_up":
				return 95.0 + tier * 2.0
			if t in ["skill", "chain"] and few_spells:
				return 90.0
		"pieces":
			if t in ["skill", "chain"] and few_spells:
				return 100.0
			if t == "sv_piece":
				return 92.0 + float(o.item.get("rarity", 0))
			if t == "sv_piece_up":
				return 75.0 + tier * 3.0 + (10.0 if woke else 0.0)
			return base * 0.9
		"passifs":
			if t == "sv_evolution":
				return 99.0
			if t in ["sv_piece_up", "sv_weapon_up"] and woke:
				return 98.0
	return base


func _best(cards: Array) -> Dictionary:
	var best: Dictionary = {}
	var bs := -INF
	for c in cards:
		var s := score(c)
		if s > bs:
			bs = s
			best = c
	return best if bs > 0.0 else {}


func _choose(cards: Array, reroll := Callable()) -> void:
	if cards.is_empty():
		return
	var pick := _best(cards)
	if reroll.is_valid() and (pick.is_empty() or score(pick) < 30.0) and Run.rerolls_left() > 0:
		Run.rerolls_used += 1
		cards = reroll.call()
		pick = _best(cards)
	if pick.is_empty():
		if SurvivorCards.can_skip(cards):
			SurvivorCards.skip()
		return
	Run.apply_card(pick)


## Combat contre le boss final de la zone (arène de la run, 20:00), héros invincible en aide « Bot ».
func duel_boss() -> Dictionary:
	var world: Node = load("res://scenes/world.tscn").instantiate()
	get_tree().root.add_child.call_deferred(world)
	await get_tree().create_timer(3.0).timeout
	var p: Player = world.player
	var d: RunDirector = world.director
	world.cards._queue.clear()
	world.cards._show_next()
	for k in Settings.PRESETS.bot.game:
		Settings.data["game"][k] = Settings.PRESETS.bot.game[k]
	p.dev_invincible = true
	world.revives_left = 0
	p.level = level
	Run.hero_level = level
	p.recalc_stats()
	p.hp = p.max_hp
	d.time = Survivor.RUN_TIME
	d.debug_enter_dungeon()
	var boss: Monster = d._boss
	if boss == null:
		return {"res": "erreur", "player": p}
	await get_tree().physics_frame  # PV définitifs (Menace appliquée en différé)
	var hp0 := boss.max_hp
	var t := 0.0
	var res := "temps"
	var shield_t := 0.0
	while t < max_t:
		await get_tree().physics_frame
		var dt := get_physics_process_delta_time()
		t += dt
		# totems et cristaux de soin : un joueur les casse en quelques secondes (comme tools/boss_ttk)
		shield_t = shield_t + dt if is_instance_valid(boss) and boss.shielded else 0.0
		if shield_t > 8.0 and boss.brain:
			for tt in boss.brain._totems:
				if is_instance_valid(tt) and not tt.is_dead:
					tt.take_damage(tt.max_hp * 10.0 + 1.0, p)
			shield_t = 0.0
		if not is_instance_valid(boss) or boss.is_dead:
			res = "tué"
			break
	var left := boss.hp if is_instance_valid(boss) and not boss.is_dead else 0.0
	var dps := (hp0 - left) / maxf(t, 0.1)
	return {"res": res, "t": t, "hp0": hp0, "dps": dps, "ttk": t if res == "tué" else hp0 / maxf(dps, 1.0), "player": p}


## Ligne de mesure : stratégie, build (arme, set, pièces, sorts, passifs) et statistiques du héros ; combat s'il a eu lieu.
func line(p: Player, res: Dictionary) -> String:
	if p == null:
		p = Player.new()
		add_child(p)
		p.level = level
		p.recalc_stats()
	var w: Dictionary = Profile.equipped.get("weapon", {})
	var counts := Items.set_counts(Profile.equipped)
	var best := 0
	var fam := "-"
	for sid in counts:
		if int(counts[sid]) > best:
			best = int(counts[sid])
			fam = SurvivorPool.family(String(sid)) if String(sid) in SurvivorPool.sets() else String(sid)
	var plus10 := 0
	var sum_up := 0
	for it in Profile.equipped.values():
		sum_up += int(it.get("upgrade", 0))
		plus10 += 1 if int(it.get("upgrade", 0)) >= 10 else 0
	var ranks: Array = Run.all_skills().map(func(s): return int(s.rank))
	var capped := Run.passive_power.keys().filter(func(id): return float(Run.passive_power[id]) >= SurvivorGear.boon_cap(String(id)) - 0.001).size()
	var top: Array = Run.passive_power.keys()
	top.sort_custom(func(a, b): return float(Run.passive_power[a]) > float(Run.passive_power[b]))
	var evos := Run.passives.keys().filter(func(id): return not (Boons.get_def(String(id)).get("requires", []) as Array).is_empty()).size()
	var s := "classe=%s stratégie=%s graine=%d niveau=%d arme=%s+%d set=%s:%d pièces=%d somme=%d plus10=%d sorts=%s s10=%d passifs=%d plafond=%d évolutions=%d top=%s" % [
		cid, strategy, seed_v, level, Items.weapon_type_of(w) if not w.is_empty() else "-", int(w.get("upgrade", 0)), fam, best,
		Profile.equipped.size(), sum_up, plus10, ",".join(PackedStringArray(ranks.map(func(x): return str(x)))), ranks.filter(func(x): return x >= 10).size(),
		Run.passive_power.size(), capped, evos, ",".join(PackedStringArray(top.slice(0, 3)))]
	s += " pv=%d atk=%d matk=%d crit=%.2f mcrit=%.2f critdmg=%.2f vit=%.2f incant=%.2f recharge=%.2f dégâts=%.2f zone=%.2f proj=%d pitié=%d" % [
		roundi(p.max_hp), roundi(p.atk), roundi(p.matk), p.crit, p.mcrit, p.crit_dmg, p.atk_speed, p.cast_speed, p.cdr, p.dmg_mult, p.area_mult,
		p.extra_proj, Survivor.pity_given]
	if not res.is_empty() and res.has("dps"):
		s += " résultat=%s ttk=%.1f dps=%.0f pv_boss=%.0f" % [res.res, res.ttk, res.dps, res.hp0]
	return s
