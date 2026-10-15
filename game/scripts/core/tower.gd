class_name Tower
extends RefCounted
## Mode de jeu « la Tour » : 200 étages. Chaque étage vidé donne une carte (sorts, passifs,
## comme en run) et un coffre au centre de la salle, à ouvrir tout de suite : son objet
## s'équipe pour l'ascension s'il est meilleur. Le héros part avec le préréglage d'équipement
## de sa classe ; tout ce que les coffres donnent rejoint le coffre commun à la fin, que
## l'ascension soit gagnée ou perdue.
## Étages : un duel sur trois (un héros d'une classe en 1 contre 1, ClassRival, l'IA de
## l'entraînement ; les 60 classes, celles de base d'abord), les autres des vagues de
## monstres, une élite tous les 5, un boss tous les 10 ; le décor change tous les 25 étages.
## Difficulté choisie au lancement (IA des duellistes, force des monstres), puis l'étage de
## départ : ceux déjà battus ou le suivant. Un record par difficulté. Une seule vie.
## Tout est réglable dans le mode dev (page Tour) : règles générales et réglages étage par
## étage (data/dev_edits.json -> "tower" : {rules, floors}). Chaque étage est décrit par
## spec(), lue par l'étage en jeu, la page des étages et sa fiche d'infos.
## La sauvegarde n'est pas écrite pendant l'ascension ; elle est rechargée à la sortie, puis
## les objets trouvés, le record et l'expertise y sont ajoutés.

const FLOORS := 200
const FLOORS_PER_ZONE := 25
const RECORD := "tower_best"
## Étages qui donnent un coffre d'apparence, et sa qualité (Rewards.LOOK_TYPES).
const LOOK_FLOORS := [50, 100, 150, 200]
const LOOK_TIERS := [1, 2, 3, 3]
const DIFF_NAMES := ["Facile", "Normal", "Difficile", "Hardcore"]
const DIFF_DESC := [
	"Duellistes lents à réagir, monstres affaiblis.",
	"Duellistes qui esquivent et punissent parfois.",
	"Duellistes qui lisent tes coups, annulent et se replacent.",
	"Duellistes au réflexe parfait : esquive au dernier moment, combos sans pause, chaque temps mort puni.",
]
const TYPES := ["monsters", "elite", "duel", "boss"]
const TYPE_NAMES := {"monsters": "Monstres", "elite": "Monstres et élite", "duel": "Duel", "boss": "Boss"}
const DUEL_SLOTS := ["weapon", "head", "chest", "legs", "gloves", "boots"]
## Règles par défaut (modifiables dans le mode dev, page Tour) : [valeur, nom, pas].
const RULES := {
	"level_per_floor": [0.5, "Niveaux par étage", 0.05],
	"monsters_base": [8.0, "Monstres à l'étage 1", 1.0],
	"monsters_per_floor": [0.25, "Monstres en plus par étage", 0.05],
	"monsters_max": [40.0, "Monstres au plus", 1.0],
	"alive_base": [6.0, "Monstres en même temps (étage 1)", 1.0],
	"alive_per_floor": [0.05, "En même temps : en plus par étage", 0.01],
	"alive_max": [16.0, "En même temps au plus", 1.0],
	"monster_ramp": [0.02, "Monstres : force en plus par étage d'une zone", 0.005],
	"monster_zone_step": [0.1, "Monstres : force en plus par zone", 0.01],
	"monster_easy": [0.7, "Monstres : force en Facile", 0.05],
	"monster_normal": [1.0, "Monstres : force en Normal", 0.05],
	"monster_hard": [1.3, "Monstres : force en Difficile", 0.05],
	"monster_hardcore": [1.6, "Monstres : force en Hardcore", 0.05],
	"elite_count_per_50": [1.0, "Élites en plus tous les 50 étages", 1.0],
	"duel_hp": [0.45, "Duellistes : PV (× ceux de l'entraînement)", 0.05],
	"duel_atk": [1.0, "Duellistes : dégâts", 0.05],
	"duel_gear": [1.0, "Duellistes : force de leur équipement", 0.1],
	"duel_skills_every": [3.0, "Duellistes : un sort de plus tous les N duels", 1.0],
	"boss_hp": [0.3, "Boss : PV (× ceux des donjons)", 0.05],
	"boss_atk": [1.0, "Boss : dégâts", 0.05],
	"heal_between": [0.35, "PV rendus en montant (part)", 0.05],
}
const DIFF_RULE := ["monster_easy", "monster_normal", "monster_hard", "monster_hardcore"]

static var active := false
## Donjon (lot 13) : zone du donjon en cours ("" : pas de donjon), difficulté et alliés IA choisis.
static var dungeon := ""
static var rush := false  # la Ruée des boss : « donjon » dont les salles sont les boss des 8 zones
static var siege := false  # Le Siège : « donjon » à 5 vagues puis le boss, puis le chacun pour soi (Siege)
static var dungeon_diff := 0
static var allies: Array = []
static var difficulty := 1
static var start_floor := 1
static var floor_n := 1  # étage en cours
static var reached := 0  # dernier étage vidé
static var found: Array = []  # objets des coffres de l'ascension (rejoignent le coffre commun)
static var _order: Array = []  # classes des duels, dans l'ordre (toujours le même)
static var _gear_cache := {}  # "étage_difficulté" -> équipement du duelliste


## Lance l'ascension avec la classe [param cid], en [param diff], à l'étage [param from].
## Lance le donjon de la zone [param zid] en difficulté [param diff] avec les alliés IA [param ally_ids].
static func start_dungeon(cid: String, zid: String, diff: int, ally_ids: Array) -> void:
	start(cid, 1, 1)
	dungeon = zid
	rush = zid == Dungeons.RUSH
	siege = false
	dungeon_diff = clampi(diff, 0, Dungeons.DIFF_NAMES.size() - 1)
	allies = ally_ids.slice(0, Dungeons.MAX_ALLIES)
	difficulty = 1
	Run.fill_from_preset()
	if Run.skills.is_empty():
		for s in (Run.class_data().get("skills", []) as Array).slice(0, 4):
			Run.skills.append({"id": int(s.id), "rank": 1})


## Lance Le Siège de la zone [param zid] : deux alliés IA (complétés au hasard), cinq vagues, le boss, le chacun pour soi.
static func start_siege(cid: String, zid: String, diff: int, ally_ids: Array) -> void:
	start_dungeon(cid, zid, diff, [])
	siege = true
	rush = false
	allies = Siege.fill_allies(ally_ids)
	Siege.reset()


static func start(cid: String, diff := 1, from := 1) -> void:
	dungeon = ""
	rush = false
	siege = false
	Siege.reset()
	allies = []
	active = true
	difficulty = clampi(diff, 0, DIFF_NAMES.size() - 1)
	start_floor = clampi(from, 1, FLOORS)
	floor_n = start_floor
	reached = start_floor - 1
	found = []
	Run.start(cid)
	# le préréglage d'équipement de la classe sert de base (Profile.begin_run) ; une arme
	# commune s'il n'y en a pas
	if not Profile.equipped.has("weapon"):
		Profile.equipped["weapon"] = Items.generate(1, 0.0, "weapon", cid, 0, "", 0)
	Profile.inventory = []
	Profile.bag = {}
	Profile.gold = 0
	Profile.keys = 0
	if start_floor > 1:
		_resume_kit()
	Profile.changed.emit()


# --- règles ---------------------------------------------------------------------------------
static func edits() -> Dictionary:
	if not DevEdits.data.has("tower"):
		DevEdits.data["tower"] = {"rules": {}, "floors": {}}
	var t: Dictionary = DevEdits.data.tower
	if not t.has("rules"):
		t["rules"] = {}
	if not t.has("floors"):
		t["floors"] = {}
	return t


static func rule(key: String) -> float:
	return float(edits().rules.get(key, RULES[key][0]))


## Réglages du mode dev pour l'étage [param f] (type, class, level, hp, atk, count, skills).
static func floor_edit(f: int) -> Dictionary:
	return edits().floors.get(str(f), {})


## Après une modification du mode dev : l'équipement des duellistes est retiré au sort à nouveau.
static func edited() -> void:
	_gear_cache.clear()


static func is_dungeon() -> bool:
	return dungeon != ""


## Dernière salle ou dernier étage.
static func top() -> int:
	if siege:
		return Siege.WAVES + 1  # cinq vagues, puis le boss
	if rush:
		return Dungeons.rush_floors()
	return Dungeons.ROOMS.size() if is_dungeon() else FLOORS


static func zone_for(f: int) -> Dictionary:
	if rush:
		return Dungeons.rush_zone(f)
	if is_dungeon():
		return Dungeons.zone(dungeon)
	return GameData.zones[clampi((f - 1) / FLOORS_PER_ZONE, 0, GameData.zones.size() - 1)]


## Type par défaut : duel un étage sur trois (1, 4, 7…), boss tous les 10, élite tous les 5.
static func default_type(f: int) -> String:
	if f % 10 == 0:
		return "boss"
	if f % 3 == 1:
		return "duel"
	if f % 5 == 0:
		return "elite"
	return "monsters"


static func floor_type(f: int) -> String:
	if siege:
		return Siege.floor_type(f)
	if rush:
		return "boss"
	if is_dungeon():
		return String(Dungeons.ROOMS[clampi(f - 1, 0, Dungeons.ROOMS.size() - 1)])
	var t := String(floor_edit(f).get("type", ""))
	return t if t in TYPES else default_type(f)


static func level_for(f: int) -> int:
	if rush:
		return Dungeons.rush_level(f, dungeon_diff)
	if siege:
		return Siege.level(dungeon, dungeon_diff) + (1 if f > Siege.WAVES else 0)
	if is_dungeon():
		return Dungeons.level(dungeon, dungeon_diff) + (1 if f >= Dungeons.ROOMS.size() else 0)
	if floor_edit(f).has("level"):
		return maxi(1, int(floor_edit(f).level))
	return 1 + int((f - 1) * rule("level_per_floor"))


static func is_boss_floor(f: int) -> bool:
	return floor_type(f) == "boss"


static func is_elite_floor(f: int) -> bool:
	return floor_type(f) == "elite"


static func is_duel_floor(f: int) -> bool:
	return floor_type(f) == "duel"


static func duel_index(f: int) -> int:
	var n := 0
	for k in range(1, f + 1):
		if is_duel_floor(k):
			n += 1
	return n


static func duel_count() -> int:
	return duel_index(FLOORS)


## Ordre des classes des duels : les 20 de base puis les 40 avancées, mélangées une fois pour
## toutes (la page des étages montre à l'avance qui attend à chaque étage).
static func duel_order() -> Array:
	if _order.is_empty():
		var rng := RandomNumberGenerator.new()
		rng.seed = 2026
		var green: Array = GameData.classes.keys().filter(func(k): return String(GameData.classes[k].get("tier", "")) == "green")
		var other: Array = GameData.classes.keys().filter(func(k): return not k in green)
		green.sort()
		other.sort()
		for arr in [green, other]:
			for i in range(arr.size() - 1, 0, -1):
				var j := rng.randi_range(0, i)
				var tmp = arr[i]
				arr[i] = arr[j]
				arr[j] = tmp
		_order = green + other
	return _order


static func duel_class(f: int) -> String:
	var c := String(floor_edit(f).get("class", ""))
	if c != "" and GameData.classes.has(c):
		return c
	var o := duel_order()
	return String(o[(maxi(duel_index(f), 1) - 1) % o.size()])


static func duel_skills(f: int) -> int:
	if floor_edit(f).has("skills"):
		return clampi(int(floor_edit(f).skills), 0, 4)
	return clampi(1 + int(duel_index(f) / maxf(rule("duel_skills_every"), 1.0)), 1, 4)


static func monster_count(f: int) -> int:
	if siege:
		return Siege.wave_count(f, dungeon_diff)
	if is_dungeon():
		return 14 + 4 * dungeon_diff + (4 if f == 3 else 0)
	if floor_edit(f).has("count"):
		return maxi(0, int(floor_edit(f).count))
	return mini(int(rule("monsters_base") + f * rule("monsters_per_floor")), int(rule("monsters_max")))


static func max_alive(f: int) -> int:
	if siege:
		return Siege.max_alive(dungeon_diff)
	if is_dungeon():
		return 12 + 2 * dungeon_diff
	return mini(int(rule("alive_base") + f * rule("alive_per_floor")), int(rule("alive_max")))


static func elite_count(f: int) -> int:
	if siege:
		return Siege.elite_count(f, dungeon_diff)
	if is_dungeon():
		return 3 + dungeon_diff
	return 1 + int(f / 50 * rule("elite_count_per_50"))


## Force des monstres de l'étage : zone, étage dans la zone, difficulté.
static func monster_mult(f: int, diff := -1) -> float:
	var d := difficulty if diff < 0 else diff
	return (1.0 + rule("monster_ramp") * float((f - 1) % FLOORS_PER_ZONE) + rule("monster_zone_step") * float((f - 1) / FLOORS_PER_ZONE)) * rule(DIFF_RULE[d])


## PV et dégâts des monstres de l'étage (× réglages de l'étage dans le mode dev) ; boss à part.
static func monster_hp_mult(f: int, diff := -1, boss := false) -> float:
	if siege:
		return Siege.hp_mult(boss, floor_type(f) == "elite")
	if is_dungeon():
		return Dungeons.hp_mult(boss, floor_type(f) == "elite", allies.size())
	return monster_mult(f, diff) * float(floor_edit(f).get("hp", 1.0)) * (rule("boss_hp") if boss else 1.0)


static func monster_atk_mult(f: int, diff := -1, boss := false) -> float:
	if is_dungeon():
		return 1.0 + 0.3 * dungeon_diff
	return monster_mult(f, diff) * float(floor_edit(f).get("atk", 1.0)) * (rule("boss_atk") if boss else 1.0)


## Équipement du duelliste de l'étage (tiré une fois pour l'étage et la difficulté).
static func duel_gear(f: int, diff := -1) -> Array:
	var d := difficulty if diff < 0 else diff
	var key := "%d_%d" % [f, d]
	if _gear_cache.has(key):
		return _gear_cache[key]
	var cid := duel_class(f)
	var lv := level_for(f)
	seed(hash([f, d, cid]))
	var out: Array = []
	for slot in DUEL_SLOTS:
		out.append(Items.generate(lv, 0.2 * d + f / 150.0, slot, cid, 0, "", 3))
	randomize()
	_gear_cache[key] = out
	return out


## Fiche complète de l'étage [param f] en difficulté [param diff] : type, zone, niveau, et
## selon le type le duelliste, les monstres ou le boss avec leurs stats.
static func spec(f: int, diff := -1) -> Dictionary:
	var d := difficulty if diff < 0 else diff
	var z := zone_for(f)
	var s := {"floor": f, "type": floor_type(f), "zone": z, "level": level_for(f), "diff": d}
	match String(s.type):
		"duel":
			s["class"] = duel_class(f)
			s["skills"] = duel_skills(f)
			s["gear"] = duel_gear(f, d)
			s["index"] = duel_index(f)
		"boss":
			s["boss"] = int(z.get("dungeon", {}).get("boss", 0))
		_:
			s["count"] = monster_count(f)
			s["alive"] = max_alive(f)
			if s.type == "elite":
				s["elites"] = elite_count(f)
	return s


## Duelliste prêt à placer (aussi pour la fiche : créé, lu puis libéré).
static func make_rival(s: Dictionary) -> ClassRival:
	var f := int(s.floor)
	var r := ClassRival.new()
	r.setup(String(s["class"]), int(s.level), int(s.diff), rule("duel_hp") * float(floor_edit(f).get("hp", 1.0)), int(s.skills))
	# puissance des objets : celle du niveau de l'étage (Items.power_level), même hors partie
	var was_active := Run.active
	var was_level := Run.hero_level
	Run.active = true
	Run.hero_level = int(s.level)
	r.apply_gear(s.gear, rule("duel_gear"))
	Run.active = was_active
	Run.hero_level = was_level
	r.atk *= rule("duel_atk") * float(floor_edit(f).get("atk", 1.0))
	r.display_name = "<Duel> %s" % GameData.class_data(r.cid).get("name_fr", r.cid)
	return r


## Stats d'un monstre de l'étage (fiche) : {name, hp, atk, def, level}.
static func monster_stats(id: int, s: Dictionary, boss := false) -> Dictionary:
	var m := Monster.new()
	var lv := int(s.level) + (1 if boss else 0)
	m.configure(GameData.monster(id), boss, lv)
	var hp := m.max_hp * monster_hp_mult(int(s.floor), int(s.diff), boss)
	var atk := m.atk * monster_atk_mult(int(s.floor), int(s.diff), boss)
	var out := {"name": m.display_name, "hp": hp, "atk": atk, "def": m.defense, "level": m.level, "elite": m.is_elite}
	m.free()
	return out


static func chest_item(f: int, class_id: String) -> Dictionary:
	var lv := level_for(f)
	if is_boss_floor(f):
		var rar := Items.LEGENDARY if randf() < 0.25 + f / 400.0 else Items.MYTHIC
		return Items.generate(lv, 1.0, "", class_id, rar, "", rar)
	var luck := clampf(f / 120.0, 0.0, 1.5) + (0.4 if is_elite_floor(f) else 0.0) + (0.3 if is_duel_floor(f) else 0.0)
	return Items.generate(lv, luck, "", class_id, 1 if f >= 20 else 0, "", 3)  # commun à épique


# --- progression ------------------------------------------------------------------------------
static func record_key(diff: int) -> String:
	return RECORD if diff == 1 else "%s_%d" % [RECORD, diff]


## Palier de reprise de la difficulté [param diff] : le début du bloc de 10 étages en cours
## (étage 1 tant que moins de 10 étages sont battus).
static func checkpoint(diff := -1) -> int:
	var b := best(diff)
	return clampi((b / 10) * 10 + 1, 1, FLOORS)


## Reprise sans piège : partir d'un étage élevé donne le kit complet (12 sorts du préréglage) et
## des cartes en rapport avec l'étage (une tous les 6 étages), pour ne pas arriver nu.
static func _resume_kit() -> void:
	Run.fill_from_preset()
	if Run.skills.is_empty():
		for s in (Run.class_data().get("skills", []) as Array).slice(0, 4):
			Run.skills.append({"id": int(s.id), "rank": 1})  # pas de préréglage : les sorts de base de la classe
	for i in start_floor / 6:
		var pick: Array = Run.roll_cards(1, false, "passive")
		if not pick.is_empty():
			Run.apply_card(pick[0])


## Duellistes battus au mieux, toutes difficultés confondues (fil d'éveil).
static func duelists_beaten() -> int:
	var top := 0
	for d in DIFF_NAMES.size():
		top = maxi(top, best(d))
	return duel_index(top)


## Dernier étage battu dans la difficulté [param diff].
static func best(diff := -1) -> int:
	return int(Profile.records.get(record_key(difficulty if diff < 0 else diff), 0))


## Mode dev : tous les étages ouverts (case de la page Tour du mode dev, cochée par défaut).
static func dev_unlock_all() -> bool:
	return bool(Settings.get_v("interface", "dev_mode")) and bool(Settings.get_v("interface", "tower_unlock_all"))


## Étage jouable : déjà battu, ou le suivant (tous en mode dev, si la case est cochée).
static func unlocked(f: int, diff: int) -> bool:
	return f <= best(diff) + 1 or dev_unlock_all()


## Fin de l'ascension (gagnée ou perdue) : la sauvegarde est rechargée, puis les objets des
## coffres rejoignent le coffre commun, et le record et l'expertise sont enregistrés.
## Renvoie {best, new_record, xp, levels, items}.
static func finish() -> Dictionary:
	if not active:
		return {}
	if is_dungeon():
		return _finish_dungeon()
	RunJournal.end_map("fin", {"floor": floor_n})
	active = false
	Run.active = false
	var cid := Run.class_id
	Profile.in_run = false
	Profile.reload_keep_records()
	Profile.gold = 0
	Profile.keys = 0
	Profile.bag = {}
	for it in found:
		Profile.vault.append(it)  # le coffre commun (l'inventaire du lobby en est tiré)
	var old := best()
	Profile.record_max(record_key(difficulty), reached)
	# paliers 50, 100, 150, 200 : un coffre d'apparence (une fois par difficulté et par palier)
	var looks := 0
	for i in LOOK_FLOORS.size():
		var f: int = LOOK_FLOORS[i]
		var key := "tower_look_%d_%d" % [difficulty, f]
		if reached >= f and not Profile.records.has(key):
			Profile.records[key] = 1
			Profile.reward_chests.append(Rewards.make(Rewards.look_type(LOOK_TIERS[i]), 30, true))
			looks += 1
	var climbed := maxi(0, reached - start_floor + 1)
	var xp := roundi((climbed * 12 + Run.kills / 3) * [0.75, 1.0, 1.3, 1.6][difficulty])
	var lv := Profile.add_expertise(cid, xp)
	Profile._lobby_view()
	Profile.save_profile()
	return {"best": best(), "new_record": reached > old, "xp": xp, "levels": lv, "items": found.size(), "looks": looks}


## Fin d'un donjon : butin si le boss est tombé, sauvegarde rechargée (comme la Tour).
static func _finish_dungeon() -> Dictionary:
	var victory := reached >= top()
	var was_siege := siege
	var sg_outcome := Siege.outcome
	RunJournal.end_map("victoire" if victory else "defaite", {"dungeon": dungeon, "dungeon_diff": dungeon_diff, "rooms": reached, "allies": allies.size()})
	active = false
	Run.active = false
	var cid := Run.class_id
	var zid := dungeon
	var diff := dungeon_diff
	Profile.in_run = false
	Profile.reload_keep_records()
	Profile.gold = 0
	Profile.keys = 0
	Profile.bag = {}
	var rew := {}
	var was_rush := rush
	if was_siege:
		rew = Siege.settle(zid, diff, reached, sg_outcome)  # des cristaux dès les premières vagues
	elif was_rush:
		rew = Dungeons.rush_reward(reached, diff)  # des cristaux même si la Ruée s'arrête avant la fin
	elif victory:
		rew = Dungeons.reward(zid, diff)
	var xp := (reached * 40 + (150 if victory else 0)) * (1 + diff)
	var lv := Profile.add_expertise(cid, xp)
	Achievements.refresh()
	Profile._lobby_view()
	Profile.save_profile()
	dungeon = ""
	rush = false
	siege = false
	allies = []
	var rank := Siege.rank
	Siege.reset()
	return {"dungeon": true, "rush": was_rush, "siege": was_siege, "outcome": sg_outcome, "rank": rank, "victory": victory, "rooms": reached,
		"xp": xp, "levels": lv, "reward": rew, "zone": zid, "diff": diff}


static func leave(tree: SceneTree) -> void:
	if active:
		finish()
	tree.paused = false
	tree.change_scene_to_file.call_deferred("res://scenes/lobby.tscn")
