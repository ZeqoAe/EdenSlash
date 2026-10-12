extends Node
## État d'une run : classe, 4 emplacements de compétences, passifs obtenus par
## cartes au passage de niveau, butin et bilan.

signal changed

const MAX_SKILLS := 4
const MAX_RANK := 5

var active := false
var class_id := "samurai"
var skills: Array = []  # [{id, rank}]
var passives: Dictionary = {}  # id -> nombre de cartes prises
var kills := 0
var elites := 0
var loot: Array = []
var gold := 0
var started_at := 0
var result := ""  # victoire, defaite, abandon
var max_level := 1
var seed := 0  # graine de la map (0 = aléatoire)
var zone_id := "limestone"
var unlocked_name := ""  # zone débloquée par la victoire (bilan)
var expertise_gain := 0
var expertise_levels := 0
var rerolls_used := 0  # relances de cartes utilisées (1 par run + cartes « Bonne étoile »)


func start(cid: String) -> void:
	active = true
	class_id = cid
	skills.clear()
	passives.clear()
	loot.clear()
	kills = 0
	elites = 0
	gold = 0
	max_level = 1
	rerolls_used = 0
	result = ""
	started_at = Time.get_ticks_msec()
	zone_id = Profile.selected_zone
	unlocked_name = ""
	Profile.begin_run()
	changed.emit()


func finish(res: String) -> void:
	if not active:
		return
	active = false
	result = res
	Profile.runs_done += 1
	expertise_gain = max_level * 15 + kills / 2 + elites * 10 + (200 if res == "victoire" else (60 if res == "extraction" else 0))
	expertise_levels = Profile.add_expertise(class_id, expertise_gain)
	if res == "victoire":
		Profile.runs_won += 1
		unlocked_name = Profile.unlock_after(zone_id)
	Profile.best_level = maxi(Profile.best_level, max_level)
	Profile.save_profile()


## Or gagné : crédité tout de suite (utilisable au village), compté pour le bilan.
func add_gold(amount: int) -> void:
	gold += amount
	Profile.add_gold(amount)


## Objet ramassé : directement dans l'inventaire (équipable via le menu pause).
func pick_up(item: Dictionary) -> bool:
	if item.has("consumable"):
		Profile.add_bag(String(item.consumable))
		return true
	if not Profile.add_item(item):
		return false
	loot.append(item)
	Profile.save_profile()
	return true


## Type de l'arme en main (son combo d'auto-attaque est utilisé, quelle que soit la classe).
func weapon_type() -> String:
	var w: Dictionary = Profile.equipped.get("weapon", {})
	return Items.weapon_type_of(w) if not w.is_empty() else Items.default_weapon_type(class_id)


func duration_text() -> String:
	var s := (Time.get_ticks_msec() - started_at) / 1000
	return "%d min %02d s" % [s / 60, s % 60]


func class_data() -> Dictionary:
	return GameData.class_data(class_id)


func skill_def(id: int) -> Dictionary:
	for s in class_data().get("skills", []):
		if int(s.id) == id:
			return s
	return {}


## Passif de classe ou carte de build commune (Boons).
func passive_def(id: String) -> Dictionary:
	for p in class_data().get("passives", []):
		if p.id == id:
			return p
	return Boons.get_def(id)


func rerolls_left() -> int:
	return maxi(0, 1 + int(passive_stats().get("rerolls", 0)) - rerolls_used)


## Effets déclenchés apportés par les cartes de la run.
func passive_procs() -> Array:
	var out: Array = []
	for pid in passives:
		out.append_array(Boons.procs_of(passive_def(pid), int(passives[pid])))
	return out


func skill_rank(id: int) -> int:
	for s in skills:
		if int(s.id) == id:
			return int(s.rank)
	return 0


## Bonus de dégâts et de recharge apportés par le rang d'une compétence.
func skill_damage_mult(id: int) -> float:
	var t := skill_talent(id)
	return (1.0 + 0.2 * (skill_rank(id) - 1)) * (1.0 + float(t.dmg) + float(t.power))


func skill_cooldown_mult(id: int) -> float:
	return (1.0 - 0.08 * (skill_rank(id) - 1)) * (1.0 - minf(float(skill_talent(id).cd), 0.6))


## Statistiques cumulées des passifs de la run.
func passive_stats() -> Dictionary:
	var total := {}
	for pid in passives:
		var p := passive_def(pid)
		for s in p.get("stat", {}):
			total[s] = total.get(s, 0.0) + float(p.stat[s]) * int(passives[pid])
	# talents de la classe jouée (arbre d'Eden)
	var tree: Dictionary = GameData.talents.get(class_id, {}).get("talents", {})
	for id in Profile.talents.get(class_id, {}):
		var eff: Dictionary = tree.get(id, {}).get("effect", {})
		if eff.get("type", "") == "stat":
			total[eff.stat] = total.get(eff.stat, 0.0) + float(eff.per_level) * int(Profile.talents[class_id][id])
	# certificats équipés (passifs des classes maîtrisées, utilisables par toutes)
	for key in Profile.certificates:
		var parts: PackedStringArray = String(key).split("/")
		for p in GameData.class_data(parts[0]).get("passives", []):
			if p.id == parts[1]:
				for s in p.get("stat", {}):
					total[s] = total.get(s, 0.0) + float(p.stat[s])
	return total


## Bonus des talents sur une compétence : {dmg, cd, duration, power}.
func skill_talent(skill_id: int) -> Dictionary:
	var out := {"dmg": 0.0, "cd": 0.0, "duration": 0.0, "power": 0.0}
	var tree: Dictionary = GameData.talents.get(class_id, {}).get("talents", {})
	for id in Profile.talents.get(class_id, {}):
		var eff: Dictionary = tree.get(id, {}).get("effect", {})
		if int(eff.get("skill", 0)) != skill_id:
			continue
		var n := int(Profile.talents[class_id][id])
		match String(eff.type):
			"skill_dmg":
				out.dmg += float(eff.per_level) * n
			"skill_cd":
				out.cd += float(eff.per_level) * n
			"skill_duration":
				out.duration += float(eff.per_level) * n
			"skill_power":
				out.power += float(eff.per_level) * n
	return out


# --- cartes -----------------------------------------------------------------------
## Tire [param n] cartes différentes. [param skills_only] : choix de départ.
func roll_cards(n := 3, skills_only := false) -> Array:
	var pool: Array = []
	var owned := skills.map(func(s): return int(s.id))
	if skills.size() < MAX_SKILLS:
		for s in class_data().get("skills", []):
			if not int(s.id) in owned:
				pool.append({"type": "skill", "id": int(s.id), "weight": 3.0 if skills.size() < 2 else 2.0})
	if not skills_only:
		for s in skills:
			if int(s.rank) < MAX_RANK:
				pool.append({"type": "upgrade", "id": int(s.id), "weight": 1.5})
		for p in class_data().get("passives", []) + Boons.LIST:
			if p.has("eden"):
				continue  # certificat : se choisit avant la run (expertise)
			if int(passives.get(p.id, 0)) >= int(p.max):
				continue
			if not p.get("requires", []).all(func(r): return passives.has(r)):
				continue
			var rar: Dictionary = Boons.RARITY[String(p.get("rarity", "common"))]
			pool.append({"type": "passive", "id": p.id, "weight": 1.2 * float(rar.weight)})
	var picks: Array = []
	# tant que les 4 emplacements ne sont pas remplis, au moins une nouvelle compétence
	var skill_cards := pool.filter(func(c): return c.type == "skill")
	if not skill_cards.is_empty() and not skills_only:
		var forced: Dictionary = skill_cards.pick_random()
		picks.append(_describe_card(forced))
		pool.erase(forced)
	while picks.size() < n and not pool.is_empty():
		var total := 0.0
		for c in pool:
			total += float(c.weight)
		var r := randf() * total
		for c in pool:
			r -= float(c.weight)
			if r <= 0.0:
				picks.append(_describe_card(c))
				pool.erase(c)
				break
	return picks


func _describe_card(c: Dictionary) -> Dictionary:
	match c.type:
		"skill":
			var s := skill_def(int(c.id))
			return {"type": "skill", "id": c.id, "title": s.name, "subtitle": "Nouvelle compétence",
				"desc": "%s\nRecharge : %d s" % [s.desc, int(s.cooldown)], "icon": s.icon}
		"upgrade":
			var s := skill_def(int(c.id))
			var rank := skill_rank(int(c.id)) + 1
			return {"type": "upgrade", "id": c.id, "title": "%s — rang %d" % [s.name, rank],
				"subtitle": "Amélioration", "desc": "+20 % de dégâts, -8 % de recharge.", "icon": s.icon}
		_:
			var p := passive_def(String(c.id))
			var stacks := int(passives.get(p.id, 0))
			var rarity := String(p.get("rarity", "common"))
			var kind := "Évolution" if rarity == "legendary" else ("Passif" if p.get("procs", []).is_empty() else "Effet")
			return {"type": "passive", "id": p.id, "title": p.name, "rarity": rarity,
				"subtitle": "%s %s" % [kind, String(Boons.RARITY[rarity].name).to_lower()] + (" (%d/%d)" % [stacks + 1, int(p.max)] if int(p.max) > 1 else ""),
				"desc": p.desc, "icon": p.get("icon", Boons.ICONS.get(p.id, ""))}


func apply_card(card: Dictionary) -> void:
	match card.type:
		"skill":
			if skills.size() < MAX_SKILLS:
				skills.append({"id": int(card.id), "rank": 1})
		"upgrade":
			for s in skills:
				if int(s.id) == int(card.id):
					s.rank = mini(int(s.rank) + 1, MAX_RANK)
		"passive":
			passives[card.id] = int(passives.get(card.id, 0)) + 1
	changed.emit()
