extends Node
## Simulateur de fréquence du 5/5 du Survivant (lot S2, DECISIONS_JOUEUR §3 : « avoir 5 pièces d'un même set doit être
## rare mais exceptionnel », cible 1 run sur 20 à 30 pour un joueur qui cherche un set). Il rejoue le mélange réel des
## propositions (SurvivorPool.draw / draw_many : poids du type d'armure, set déjà porté à 3 pièces moins proposé, jamais deux pièces du même set
## dans une offre) sur un modèle de run tiré du SPEC §2.2 et §6 :
## - 37 montées de niveau en 20 min ; à chacune, la carte « équipement » est une Nouvelle pièce avec la probabilité
##   F / (F + 0,8 W + 2,5) et la carte libre avec F / (F + 0,8 W + 2,5 + 8) (F emplacements libres, W pièces portées,
##   8 = poids des sorts) ; chaque Nouvelle pièce vise un emplacement libre au hasard (au plus 2 par choix) ;
## - 8 coffres d'emplacement ouverts (sur 16) à des moments au hasard : 3 pièces de l'emplacement s'il est libre ;
## - 3 gardiens (5, 10, 15 min) : 3 pièces, chacune pour un emplacement libre différent.
## Joueurs : « chercheur » (vise un set de son type d'armure choisi au départ, ne prend que ses pièces sur les emplacements
## de set), « suiveur » (vise le set de la 1re pièce de set qu'il prend), « preneur » (prend la 1re pièce venue).
## godot --headless --path game res://tools/sv_set_sim.tscn [-- runs=4000 seed=1 set_damp=0.3 set_damp_from=3 armor_pref=2]

const LEVEL_UPS := 37
const SLOT_CHESTS := 8
const GUARDIANS := [5.0, 10.0, 15.0]
const SPELL_WEIGHT := 8.0


func _ready() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := String(a).split("=")
		if kv.size() == 2:
			args[kv[0]] = kv[1]
	var over := {}
	for k in ["set_damp", "armor_pref", "set_damp_from"]:
		if args.has(k):
			over[k] = float(args[k])
	var runs := int(args.get("runs", "4000"))
	var seed_v := int(args.get("seed", "1"))
	print("Pool : %s" % SurvivorPool.summary())
	for armor in ["plates", "cuir", "tissu"]:
		for who in ["chercheur", "suiveur", "preneur"]:
			var r := simulate(runs, seed_v, armor, who, over)
			print("%-7s %-10s 5/5 : %5.2f %% (1 run sur %s) · 4/5 et plus : %5.2f %% · pièces du set visé : %.2f" % [armor, who,
				100.0 * r.full, ("%.0f" % (1.0 / r.full)) if r.full > 0.0 else "∞", 100.0 * r.four, r.avg])
	get_tree().quit(0)


## Fréquence du 5/5 sur [param runs] runs : {full, four, avg} (part des runs à 5/5, à 4/5 ou plus, pièces moyennes du set visé).
## [param over] : réglages du profil « survivor » à essayer (set_damp, armor_pref…), remis ensuite.
static func simulate(runs: int, seed_v: int, armor: String, who: String, over := {}) -> Dictionary:
	var modes: Dictionary = DevEdits.data.get("modes", {})
	var saved: Dictionary = (modes.get("survivor", {}) as Dictionary).duplicate()
	if not over.is_empty():
		var m := saved.duplicate()
		m.merge(over, true)
		modes["survivor"] = m
		DevEdits.data["modes"] = modes
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var set_slots := SurvivorPool.set_slots()
	var slots := SurvivorPool.slots()
	var mine: Array = SurvivorPool.sets().filter(func(s): return SurvivorPool.armor_of(String(s)) == armor)
	var full := 0
	var four := 0
	var total := 0
	for i in runs:
		var n := _run(rng, armor, who, mine, set_slots, slots)
		total += n
		if n >= 5:
			full += 1
		if n >= 4:
			four += 1
	if not over.is_empty():
		if saved.is_empty():
			modes.erase("survivor")
		else:
			modes["survivor"] = saved
	return {"full": float(full) / runs, "four": float(four) / runs, "avg": float(total) / runs}


## Une run : nombre de pièces du set visé portées à la fin.
static func _run(rng: RandomNumberGenerator, armor: String, who: String, mine: Array, set_slots: Array, slots: Array) -> int:
	var worn := {}  # emplacement -> set ("" hors set)
	var target := String(mine[rng.randi() % mine.size()]) if who == "chercheur" and not mine.is_empty() else ""
	var events: Array = []
	for i in LEVEL_UPS:
		events.append([20.0 * pow(float(i + 1) / LEVEL_UPS, 1.25), "level"])
	for i in SLOT_CHESTS:
		events.append([rng.randf_range(1.0, 19.0), "chest"])
	for t in GUARDIANS:
		events.append([t, "guardian"])
	events.sort_custom(func(a, b): return float(a[0]) < float(b[0]))
	for ev in events:
		var free: Array = slots.filter(func(s): return not worn.has(s))
		if free.is_empty():
			break
		var offers: Array = []  # [emplacement, [modèles]]
		match String(ev[1]):
			"level":
				var w := float(worn.size())
				var f := float(free.size())
				var picked: Array = []
				for p in [f / (f + 0.8 * w + 2.5), f / (f + 0.8 * w + 2.5 + SPELL_WEIGHT)]:
					var left: Array = free.filter(func(s): return not s in picked)
					if not left.is_empty() and rng.randf() < float(p):
						var s := String(left[rng.randi() % left.size()])
						picked.append(s)
						offers.append([s, [SurvivorPool.draw(s, rng, _ctx(armor, worn))]])
			"chest":
				var s := String(slots[rng.randi() % slots.size()])
				if not worn.has(s):
					offers.append([s, SurvivorPool.draw_many(s, 3, rng, _ctx(armor, worn))])
			"guardian":
				var left := free.duplicate()
				for k in 3:
					if left.is_empty():
						break
					var s := String(left.pop_at(rng.randi() % left.size()))
					offers.append([s, [SurvivorPool.draw(s, rng, _ctx(armor, worn))]])
		for o in offers:
			var s := String(o[0])
			if worn.has(s):
				continue
			var choice := _choose(o[1], s, who, target, set_slots, float(ev[0]), armor)
			if choice.is_empty():
				continue
			worn[s] = String(choice.get("set", ""))
			if who == "suiveur" and target == "" and String(choice.get("set", "")) != "":
				target = String(choice.set)
	var counts := {}
	for s in worn:
		if String(worn[s]) != "":
			counts[worn[s]] = int(counts.get(worn[s], 0)) + 1
	if who == "preneur":
		return int(counts.values().max()) if not counts.is_empty() else 0  # le set le plus porté, sans le chercher
	return int(counts.get(target, 0)) if target != "" else 0


static func _ctx(armor: String, worn: Dictionary) -> Dictionary:
	var counts := {}
	for s in worn:
		if String(worn[s]) != "":
			counts[worn[s]] = int(counts.get(worn[s], 0)) + 1
	return {"armor": armor, "worn": counts, "banned": [], "exclude": []}


## Pièce prise parmi [param list] ({} : le joueur attend). Le chercheur et le suiveur ne prennent sur un emplacement de
## set que le set visé (le suiveur, tant qu'il n'a pas de cible, prend une pièce de set de son type d'armure) ; après
## 16:00 ils remplissent les emplacements restants. Les accessoires se prennent toujours.
static func _choose(list: Array, slot: String, who: String, target: String, set_slots: Array, t: float, armor: String) -> Dictionary:
	if list.is_empty():
		return {}
	if who == "preneur" or not slot in set_slots or t >= 16.0:
		return list[0]
	for e in list:
		if target != "" and String(e.get("set", "")) == target:
			return e
		if target == "" and who == "suiveur" and String(e.get("armor", "")) == armor:
			return e
	return {}
