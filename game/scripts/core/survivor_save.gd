class_name SurvivorSave
extends RefCounted
## Reprise d'un Survivant (lot SVX-4, BM-SURV SV-Q4) : « Sauver et quitter » (pause, page Équipement) écrit la partie dans
## user://survivor_save.json (SafeFile : écriture sûre) et rentre au menu sans bilan ; « Reprendre la partie » (page du mode)
## la relance là où elle était. Une seule sauvegarde, effacée à la reprise (pas de retour en arrière).
## Gardé : classe, zone, palier, faveur, graine de la carte (même carte, coffres ouverts et sanctuaires pris retirés), temps,
## niveau et expérience, PV, or et clés, équipement de la partie, sorts et passifs, bannis / gardés / relances, pitié, gardiens
## et événements passés, Menace, résurrection, boutique (offres gardées). La horde repart neuve à la minute de la sauvegarde ;
## le journal des dégâts par source repart de zéro. Seulement en exploration, sans gardien debout ni choix ouvert, hors
## partie du jour. Mode scellé : rien du compte n'y est écrit (le hub est remis comme à toute fin de partie).

const PATH := "user://survivor_save.json"
const VERSION := 1
const RESULT := "sauvegarde"  # résultat de la partie quittée ainsi (Run.finish : ni récompense, ni record, ni quête)

static var pending := {}  # sauvegarde en cours de reprise : appliquée par le directeur à sa première image


## Peut-on sauver maintenant ? "" si oui, sinon la raison (infobulle du bouton).
static func blocked(d: RunDirector) -> String:
	if not Survivor.active or d == null or d.sv == null:
		return "Seulement dans le Survivant."
	if SurvivorDaily.active:
		return "La partie du jour se joue d'une traite."
	if d.state != "explore":
		return "Pas dans l'arène du boss."
	if d.player == null or d.player.is_dead:
		return "Pas pendant une chute."
	if d.sv.guardians.any(func(e): return float(e.ttk) < 0.0):
		return "Pas pendant le combat d'un gardien."
	if d.time > Survivor.RUN_TIME - 30.0:
		return "Le boss arrive : plus de pause possible."
	return ""


## Texte de sauvegarde lisible (var_to_str garde les types : clés entières, entiers).
static func _valid(text: String) -> bool:
	return text.strip_edges() != "" and str_to_var(text) is Dictionary


static func exists() -> bool:
	return FileAccess.file_exists(PATH)


## Ce que dit la page du mode : {class, zone, palier, time, level} ({} : aucune sauvegarde lisible).
static func peek() -> Dictionary:
	if not exists():
		return {}
	var v: Variant = str_to_var(SafeFile.read(PATH, func(t): return SurvivorSave._valid(t)))
	return v if v is Dictionary and int((v as Dictionary).get("v", 0)) == VERSION else {}


## Écrit la partie en cours ; vrai si c'est fait.
static func save(d: RunDirector) -> bool:
	if blocked(d) != "":
		return false
	var p := d.player
	var used: Array = []
	for i in d.map.interactables.size():
		var it = d.map.interactables[i]
		if is_instance_valid(it) and it.used:
			used.append(i)
	var shrines: Array = []
	for i in d.map.shrines.size():
		var sh = d.map.shrines[i]
		if is_instance_valid(sh) and sh.captured:
			shrines.append(i)
	var ev := d.sv.events
	var data := {
		"v": VERSION, "version": Version.NUMBER, "class": Run.class_id, "zone": Survivor.zone_id, "palier": Survivor.palier,
		"favor": SurvivorFavors.current, "seed": d._seed, "time": d.time,
		"level": p.level, "xp": p.xp, "hp": p.hp / maxf(p.max_hp, 1.0), "max_level": Run.max_level, "kills": Run.kills, "elites": Run.elites,
		"gold": Profile.gold, "keys": Profile.keys, "equipped": Profile.equipped.duplicate(true),
		"run": {"skills": Run.skills.duplicate(true), "chains": Run.chains.duplicate(true), "passives": Run.passives.duplicate(true),
			"passive_power": Run.passive_power.duplicate(true), "banned": Run.banned.duplicate(true), "kept": Run.kept.duplicate(true),
			"bans_used": Run.bans_used, "locks_used": Run.locks_used, "rerolls_used": Run.rerolls_used, "weapon_ups": Run.weapon_ups.duplicate(true),
			"chests_total": Run.chests_total},
		"sv": {"picks": Survivor.picks.duplicate(true), "since": Survivor.since.duplicate(true), "dry": Survivor.dry, "pity_given": Survivor.pity_given},
		"shop": {"kept": SurvivorShop.kept.duplicate(true), "visits": SurvivorShop.visits, "spent": SurvivorShop.spent},
		"dir": {"guardians": d.sv.guardians.duplicate(true), "next": d.sv._next, "chests_opened": d.chests_opened, "shrines_captured": d.shrines_captured,
			"used": used, "shrines": shrines, "menace": Menace.level, "revives": int(d.world.get("revives_left")) if d.world != null and d.world.get("revives_left") != null else 1,
			"events_next": ev._next if ev != null else 0, "events_warned": ev._warned.duplicate() if ev != null else {}, "dungeon_found": d.dungeon_found},
	}
	return SafeFile.write(PATH, var_to_str(data), func(t): return SurvivorSave._valid(t))


## Efface la sauvegarde (et sa copie de secours).
static func clear() -> void:
	for f in [PATH, PATH + ".bak", PATH + ".tmp"]:
		if FileAccess.file_exists(f):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(f))


## Relance la partie sauvée (le lobby change ensuite de scène) ; la sauvegarde est effacée. Faux si elle est illisible.
static func resume() -> bool:
	var data := peek()
	clear()
	if data.is_empty():
		return false
	Survivor.start(String(data["class"]), String(data.zone), int(data.palier), String(data.get("favor", "")))
	Run.seed = int(data.seed)
	var r: Dictionary = data.run
	Run.skills = (r.skills as Array).duplicate(true)
	Run.chains = (r.chains as Dictionary).duplicate(true)
	Run.passives = (r.passives as Dictionary).duplicate(true)
	Run.passive_power = (r.passive_power as Dictionary).duplicate(true)
	Run.banned = (r.banned as Array).duplicate(true)
	Run.kept = (r.kept as Array).duplicate(true)
	Run.bans_used = int(r.bans_used)
	Run.locks_used = int(r.locks_used)
	Run.rerolls_used = int(r.rerolls_used)
	Run.weapon_ups = (r.weapon_ups as Dictionary).duplicate(true)
	Run.chests_total = int(r.get("chests_total", 0))
	Run.kills = int(data.kills)
	Run.elites = int(data.elites)
	Run.max_level = int(data.max_level)
	Run.hero_level = int(data.level)
	Profile.equipped = (data.equipped as Dictionary).duplicate(true)
	Profile.gold = int(data.gold)
	Profile.keys = int(data.keys)
	var s: Dictionary = data.sv
	Survivor.picks = (s.picks as Dictionary).duplicate(true)
	Survivor.since = (s.since as Dictionary).duplicate(true)
	Survivor.dry = int(s.dry)
	Survivor.pity_given = int(s.pity_given)
	Survivor.bans_used = Run.bans_used
	var sh: Dictionary = data.shop
	SurvivorShop.kept = (sh.kept as Array).duplicate(true)
	SurvivorShop.visits = int(sh.visits)
	SurvivorShop.spent = int(sh.spent)
	pending = data
	Run.changed.emit()
	Profile.changed.emit()
	return true


## Première image du directeur d'une partie reprise : temps, héros, gardiens, événements, carte (coffres et sanctuaires).
static func apply(sv: SurvivorDirector) -> void:
	if pending.is_empty():
		return
	var data := pending
	pending = {}
	var d := sv.d
	var dd: Dictionary = data.dir
	d.time = float(data.time)
	sv._minute = int(d.time / 60.0)
	sv.guardians = (dd.guardians as Array).duplicate(true)
	sv._next = int(dd.next)
	d.chests_opened = int(dd.chests_opened)
	d.shrines_captured = int(dd.shrines_captured)
	d.dungeon_found = bool(dd.get("dungeon_found", false))
	Menace.level = maxi(Menace.level, int(dd.menace))
	if d.world != null and d.world.get("revives_left") != null:
		d.world.revives_left = int(dd.revives)
	for i in dd.used:
		if int(i) < d.map.interactables.size() and is_instance_valid(d.map.interactables[int(i)]):
			d.map.interactables[int(i)].use_up()
	for i in dd.shrines:
		if int(i) < d.map.shrines.size() and is_instance_valid(d.map.shrines[int(i)]):
			d.map.shrines[int(i)].captured = true
	if sv.events == null:
		sv.events = SurvivorEvents.new(sv)
	sv.events._next = int(dd.events_next)
	sv.events._warned = (dd.events_warned as Dictionary).duplicate()
	sv.events._last_t = d.time
	var p := d.player
	p.level = int(data.level)
	p.xp = int(data.xp)
	p.recalc_stats()
	p.hp = clampf(float(data.hp), 0.05, 1.0) * p.max_hp
	p.health_changed.emit(p.hp, p.max_hp)
	p.skills_changed.emit()
	d.message.emit("Partie reprise à %s\nLe boss arrive à 20:00" % SurvivorDirector.clock(d.time), 3.0)
	print("[sv] partie reprise à %s, niveau %d" % [SurvivorDirector.clock(d.time), p.level])
