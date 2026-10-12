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
	result = ""
	started_at = Time.get_ticks_msec()
	changed.emit()


func finish(res: String) -> void:
	if not active:
		return
	active = false
	result = res
	Profile.runs_done += 1
	if res == "victoire":
		Profile.runs_won += 1
	Profile.best_level = maxi(Profile.best_level, max_level)
	Profile.save_profile()


## Or gagné : crédité tout de suite (utilisable au village), compté pour le bilan.
func add_gold(amount: int) -> void:
	gold += amount
	Profile.add_gold(amount)


## Objet ramassé : directement dans l'inventaire (équipable via le menu pause).
func pick_up(item: Dictionary) -> bool:
	if not Profile.add_item(item):
		return false
	loot.append(item)
	Profile.save_profile()
	return true


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


func passive_def(id: String) -> Dictionary:
	for p in class_data().get("passives", []):
		if p.id == id:
			return p
	return {}


func skill_rank(id: int) -> int:
	for s in skills:
		if int(s.id) == id:
			return int(s.rank)
	return 0


## Bonus de dégâts et de recharge apportés par le rang d'une compétence.
func skill_damage_mult(id: int) -> float:
	return 1.0 + 0.2 * (skill_rank(id) - 1)


func skill_cooldown_mult(id: int) -> float:
	return 1.0 - 0.08 * (skill_rank(id) - 1)


## Statistiques cumulées des passifs de la run.
func passive_stats() -> Dictionary:
	var total := {}
	for pid in passives:
		var p := passive_def(pid)
		for s in p.get("stat", {}):
			total[s] = total.get(s, 0.0) + float(p.stat[s]) * int(passives[pid])
	return total


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
		for p in class_data().get("passives", []):
			if int(passives.get(p.id, 0)) < int(p.max):
				pool.append({"type": "passive", "id": p.id, "weight": 1.2})
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
			return {"type": "passive", "id": p.id, "title": p.name,
				"subtitle": "Passif" + (" (%d/%d)" % [stacks + 1, int(p.max)] if int(p.max) > 1 else ""),
				"desc": p.desc, "icon": p.get("icon", "")}


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
