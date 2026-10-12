extends Node
## État d'une run : classe, 4 emplacements de compétences, passifs obtenus par
## cartes au passage de niveau, butin et bilan.

signal changed
signal instant_card(id: String)  # carte à effet immédiat (Rappel)

const MAX_SKILLS := 4
const MAX_RANK := 5

var active := false
var class_id := "samurai"
var skills: Array = []  # [{id, rank}]
var passives: Dictionary = {}  # id -> nombre de cartes prises (niveau du passif)
var passive_power: Dictionary = {}  # id -> puissance : somme des multiplicateurs de rareté des cartes prises
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
var new_classes: Array = []  # classes débloquées pendant la run (bilan)
var new_costumes: Array = []  # costumes (skins de tenue) débloqués pendant la run
var rerolls_used := 0  # relances de cartes utilisées (1 par run + cartes « Bonne étoile »)
var chests_found: Array = []  # coffres de récompense ramassés (gardés si victoire ou extraction)


func start(cid: String) -> void:
	active = true
	class_id = cid
	skills.clear()
	passives.clear()
	passive_power.clear()
	loot.clear()
	kills = 0
	elites = 0
	gold = 0
	max_level = 1
	rerolls_used = 0
	new_classes = []
	new_costumes = []
	chests_found = []
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


## Or gagné : crédité tout de suite (coffres, marchands, forge), compté pour le bilan.
func add_gold(amount: int) -> void:
	gold += amount
	Profile.add_gold(amount)


## Objet ramassé : directement dans l'inventaire (équipable via le menu pause).
func pick_up(item: Dictionary) -> bool:
	if item.has("consumable"):
		Profile.add_bag(String(item.consumable))
		return true
	if item.has("chest"):
		chests_found.append(item.chest)
		changed.emit()
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


## Puissance d'un passif : somme des multiplicateurs de rareté (Cards) des cartes prises
## (une carte commune = 1) ; à défaut (tests, mode dev), le nombre de cartes.
func power(pid: String) -> float:
	return float(passive_power.get(pid, passives.get(pid, 0)))


## Effets déclenchés apportés par les cartes de la run.
func passive_procs() -> Array:
	var out: Array = []
	for pid in passives:
		out.append_array(Boons.procs_of(passive_def(pid), power(pid)))
	return out


## Compétence prise : {id, rank, dmg, cd, heal, dur, riders}.
func skill_entry(id: int) -> Dictionary:
	for s in skills:
		if int(s.id) == id:
			return s
	return {}


func skill_rank(id: int) -> int:
	for s in skills:
		if int(s.id) == id:
			return int(s.rank)
	return 0


## Bonus de dégâts et de recharge apportés par les cartes d'amélioration de la compétence
## (à défaut : +20 % / -8 % par rang, anciennes runs et tests).
func skill_damage_mult(id: int) -> float:
	var t := skill_talent(id)
	var s := skill_entry(id)
	return (1.0 + float(s.get("dmg", 0.2 * (skill_rank(id) - 1)))) * (1.0 + float(t.dmg) + float(t.power))


func skill_cooldown_mult(id: int) -> float:
	var s := skill_entry(id)
	return (1.0 - minf(float(s.get("cd", 0.08 * (skill_rank(id) - 1))), 0.6)) * (1.0 - minf(float(skill_talent(id).cd), 0.6))


## Soins de la compétence (cartes d'amélioration des sorts de soin).
func skill_heal_mult(id: int) -> float:
	return 1.0 + float(skill_entry(id).get("heal", 0.0))


## Durée des effets de la compétence (buffs, états infligés).
func skill_duration_mult(id: int) -> float:
	return 1.0 + float(skill_entry(id).get("dur", 0.0))


## Bonus d'attribut au lancement : [{stat, value, duration}].
func skill_riders(id: int) -> Array:
	return skill_entry(id).get("riders", [])


## Statistiques cumulées des passifs de la run.
func passive_stats() -> Dictionary:
	var total := {}
	for pid in passives:
		var p := passive_def(pid)
		for s in p.get("stat", {}):
			total[s] = total.get(s, 0.0) + float(p.stat[s]) * power(pid)
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
	# placement des certificats sur le plateau (liens, prisme, losange)
	var board := CertBoard.stats(Profile.cert_board)
	for s in board:
		total[s] = total.get(s, 0.0) + float(board[s])
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
			if not int(s.id) in owned and Progression.skill_unlocked(class_id, int(s.id)):
				pool.append({"type": "skill", "id": int(s.id), "weight": 3.0 if skills.size() < 2 else 2.0})
	if not skills_only:
		for s in skills:
			if int(s.rank) < int(Cards.rules().max_rank):
				pool.append({"type": "upgrade", "id": int(s.id), "weight": 1.5})
		for p in class_data().get("passives", []) + Boons.all():
			if p.has("eden") and not p.get("shared", false):
				continue  # certificat : se choisit avant la run (expertise) ; les certificats partagés sont des cartes
			if int(passives.get(p.id, 0)) >= mini(int(p.get("max", 1)), 99 if p.get("instant", false) else Cards.MAX_LEVEL):
				continue
			if not p.get("requires", []).all(func(r): return passives.has(r)):
				continue
			var rar: Dictionary = Boons.RARITY[String(p.get("rarity", "common"))]
			pool.append({"type": "passive", "id": p.id, "weight": 1.2 * float(rar.weight) * (0.5 if p.get("instant", false) else 1.0)})
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
			var tier := Cards.roll_tier()
			var magic := String(class_data().get("dmg_type", "phys")) == "magic"
			var up := Cards.skill_upgrade(s, tier, (["int", "wis"] if magic else ["str", "agi"]).pick_random())
			return {"type": "upgrade", "id": c.id, "tier": tier, "up": up, "title": "%s — rang %d" % [s.name, rank],
				"subtitle": "Amélioration %s" % String(Cards.tier(tier).name).to_lower(),
				"desc": "\n".join(Cards.skill_upgrade_lines(skill_entry(int(c.id)), up)), "icon": s.icon}
		_:
			var p := passive_def(String(c.id))
			var stacks := int(passives.get(p.id, 0))
			var rarity := String(p.get("rarity", "common"))
			var icon := String(p.get("icon", Boons.ICONS.get(p.id, "")))
			if p.get("instant", false):
				return {"type": "passive", "id": p.id, "title": p.name, "tier": "rare", "mult": 1.0,
					"subtitle": "Effet immédiat", "desc": p.desc, "icon": icon}
			# rareté tirée (les évolutions sont toujours légendaires, sans multiplicateur)
			var evo: bool = rarity == "legendary" and not (p.get("requires", []) as Array).is_empty()
			var tier := "legendary" if evo else Cards.roll_tier()
			var m := 1.0 if evo else Cards.tier_mult(tier)
			var before := power(p.id)
			var lines := Cards.stat_lines(p, before, before + m)
			if before > 0.0:  # 1re carte : la description donne déjà les valeurs de l'effet
				lines.append_array(Cards.proc_lines(p, before, before + m))
			var kind := "Évolution" if evo else ("Passif" if p.get("procs", []).is_empty() else "Effet")
			var mx := mini(int(p.get("max", 1)), Cards.MAX_LEVEL)
			return {"type": "passive", "id": p.id, "title": p.name, "tier": tier, "mult": m,
				"subtitle": "%s %s" % [kind, String(Cards.tier(tier).name).to_lower()] + (" · niv. %d → %d" % [stacks, stacks + 1] if mx > 1 else ""),
				"desc": p.desc + ("\n[color=#9fd0ff]%s[/color]" % "\n".join(lines) if not lines.is_empty() else ""), "icon": icon}


func apply_card(card: Dictionary) -> void:
	match card.type:
		"skill":
			if skills.size() < MAX_SKILLS:
				skills.append({"id": int(card.id), "rank": 1})
		"upgrade":
			for s in skills:
				if int(s.id) == int(card.id):
					s.rank = mini(int(s.rank) + 1, int(Cards.rules().max_rank))
					var up: Dictionary = card.get("up", {"dmg": 0.2, "cd": 0.08})
					for k in ["dmg", "cd", "heal", "dur"]:
						if up.has(k):
							s[k] = float(s.get(k, 0.2 * (int(s.rank) - 2) if k == "dmg" else (0.08 * (int(s.rank) - 2) if k == "cd" else 0.0))) + float(up[k])
					if up.has("rider"):
						var riders: Array = s.get("riders", [])
						var merged := false
						for r in riders:
							if String(r.stat) == String(up.rider.stat):
								r.value = float(r.value) + float(up.rider.value)
								r.duration = maxf(float(r.duration), float(up.rider.duration))
								merged = true
						if not merged:
							riders.append(up.rider.duplicate())
						s["riders"] = riders
		"passive":
			if passive_def(String(card.id)).get("instant", false):
				instant_card.emit(String(card.id))
				changed.emit()
				return
			var before := power(String(card.id))
			passives[card.id] = int(passives.get(card.id, 0)) + 1
			passive_power[card.id] = before + float(card.get("mult", 1.0))
		"trophy":
			pick_up(card.item)  # carte de choix de trophée : le trophée va dans le sac
	changed.emit()
