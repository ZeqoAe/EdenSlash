class_name SurvivorEvo
extends RefCounted
## Évolutions du Survivant (lot SVX-3, BM-SURV SV-P1 côté règles) : les « recettes » qui transforment une arme, un sort ou
## une paire de passifs en un effet légendaire. Une évolution est une carte « sv_evolution » proposée quand sa recette est
## remplie (SurvivorCards.candidates, coffre du gardien) ; prise, elle s'ajoute aux passifs de la partie (Run.passives) et
## se lit comme eux (Run.passive_stats / passive_procs passent par Boons.get_def, qui retombe sur [method def]).
##
## Trois genres de recettes :
## - « passifs » : deux passifs portés à pleine puissance (les 4 évolutions de Boons, lot S3, et 4 nouvelles) ;
## - « arme » : l'arme portée d'un des types de la recette, à +WEAPON_AT au moins, et un passif porté ;
## - « sort » : un sort au niveau 10 (sans évolution) et un passif porté ; le sort lui-même devient plus fort (dégâts,
##   recharge, durée inscrits dans son entrée de Run : Run.skill_damage_mult, skill_cooldown_mult, skill_duration_mult).
## Chaque évolution se prend une fois par partie. Recettes affichées après la première rencontre (BM-SURV § 8, Q2) : la
## carte qui apporte un ingrédient écrit « ◆ Évolution : + X → Y » ([method hint]), la pause écrit « il manque… »
## ([method paths]), le Codex garde les évolutions vues (SurvivorCodex). Mode scellé : rien du compte.

const WEAPON_AT := 6  # +N de l'arme pour une évolution d'arme (son premier passif éveillé)
const SPELL_AT := 10  # niveau du sort pour une évolution de sort

## Recettes neuves (les 4 de Boons s'y ajoutent, voir [method all]). Champs d'une carte de Boons (name, desc, rarity, max,
## stat, procs) + kind (« passives », « weapon », « spell »), requires (passifs), wtypes (arme), spell (bonus du sort :
## dmg, cd, dur, ajoutés à son entrée), icon.
const NEW := [
	# --- armes : chaque type d'arme a sa recette ---------------------------------------------------------------------
	{"id": "sve_quake", "name": "Séisme", "kind": "weapon", "wtypes": ["axe", "hammer", "greatsword"], "requires": ["shockwave"],
		"stat": {"area": 0.15},
		"procs": [{"trigger": "basic_hit", "chance": 0.25, "cd": 1.0, "effect": "explosion", "mult": 1.5, "radius": 5.5,
			"color": Color(1.0, 0.78, 0.35, 0.9)}],
		"desc": "Hache, marteau ou espadon : 25 % des auto-attaques fendent le sol (explosion de 5,5 m, 150 %). Zone +15 %.",
		"icon": "res://assets/ui/status/stun.png"},
	{"id": "sve_cuts", "name": "Mille entailles", "kind": "weapon", "wtypes": ["katana", "sword", "rapier", "dagger"],
		"requires": ["keen_edge"], "stat": {"crit": 0.05, "crit_dmg": 0.25},
		"procs": [{"trigger": "crit", "chance": 0.25, "cd": 0.5, "effect": "double_hit", "mult": 0.7}],
		"desc": "Lame : critique +5 %, dégâts critiques +25 % ; 25 % des coups critiques frappent une 2e fois (70 %).",
		"icon": "res://assets/ui/status/keen.png"},
	{"id": "sve_volley", "name": "Volée perçante", "kind": "weapon", "wtypes": ["bow", "cannon", "gunscythe"],
		"requires": ["piercing"], "stat": {"pierce": 2.0, "proj": 1.0, "reach": 0.2},
		"desc": "Arc, canon ou faux-fusil : +1 projectile, chaque tir traverse 2 ennemis de plus, portée +20 %.",
		"icon": "res://assets/ui/skills/e0461.png"},
	{"id": "sve_arcane", "name": "Tempête arcanique", "kind": "weapon", "wtypes": ["scepter", "staff", "rod", "grimoire"],
		"requires": ["incantation"], "stat": {"cast_speed": 0.2, "area": 0.2},
		"procs": [{"trigger": "basic_hit", "chance": 0.25, "cd": 0.8, "effect": "lightning", "mult": 1.0, "chain": 3, "radius": 7.0}],
		"desc": "Arme à incantation : incantation +20 %, zone +20 % ; 25 % des auto-attaques appellent la foudre (3 rebonds, 100 %).",
		"icon": "res://assets/ui/status/shock.png"},
	{"id": "sve_dragon", "name": "Lance du dragon", "kind": "weapon", "wtypes": ["spear"], "requires": ["long_reach"],
		"stat": {"reach": 0.35, "basic_dmg": 0.2},
		"procs": [{"trigger": "basic_hit", "chance": 0.4, "cd": 1.0, "effect": "burn", "duration": 4.0, "radius": 3.0}],
		"desc": "Lance : portée +35 %, auto-attaque +20 % ; 40 % des coups enflamment la cible et ses voisins (3 m, 4 s).",
		"icon": "res://assets/ui/status/burn.png"},
	{"id": "sve_fists", "name": "Poings d'orage", "kind": "weapon", "wtypes": ["cestus"], "requires": ["combo_flow"],
		"stat": {"atk_speed": 0.25},
		"procs": [{"trigger": "basic_hit", "chance": 0.4, "cd": 1.0, "effect": "shock", "duration": 3.0, "radius": 3.0, "mult": 0.6}],
		"desc": "Gantelets : vitesse d'attaque +25 % ; 40 % des coups électrocutent autour de la cible (3 m, 60 %, +15 % de dégâts subis).",
		"icon": "res://assets/ui/status/frenzy.png"},
	{"id": "sve_chord", "name": "Accord résonnant", "kind": "weapon", "wtypes": ["guitar"], "requires": ["ricochet"],
		"stat": {"bounce": 2.0},
		"procs": [{"trigger": "basic_hit", "chance": 0.35, "cd": 1.5, "effect": "chill", "duration": 2.5, "radius": 4.0, "mult": 0.6}],
		"desc": "Guitare : chaque note rebondit 2 fois de plus ; 35 % des notes ralentissent autour de la cible (4 m, 60 %).",
		"icon": "res://assets/ui/status/chill.png"},
	# --- sorts : un sort au niveau 10 et un passif ------------------------------------------------------------------------
	{"id": "sve_s_echo", "name": "Résonance", "kind": "spell", "requires": ["echo"], "spell": {"dmg": 0.5, "cd": 0.1},
		"procs": [{"trigger": "skill_hit", "chance": 0.2, "cd": 1.5, "effect": "echo", "mult": 0.7}],
		"desc": "Ton sort niveau 10 : dégâts +50 %, recharge -10 % ; 20 % des sorts frappent une 2e fois (70 %).",
		"icon": "res://assets/ui/skills/e0463.png"},
	{"id": "sve_s_flux", "name": "Flux éternel", "kind": "spell", "requires": ["focus"], "spell": {"cd": 0.3, "dmg": 0.2},
		"stat": {"cdr": 0.05},
		"desc": "Ton sort niveau 10 : recharge -30 %, dégâts +20 % ; recharges de tous les sorts -5 %.",
		"icon": "res://assets/ui/status/flow.png"},
	{"id": "sve_s_plague", "name": "Fléau", "kind": "spell", "requires": ["deep_wounds"], "spell": {"dur": 0.6, "dmg": 0.3},
		"stat": {"dot_pct": 0.4},
		"desc": "Ton sort niveau 10 : effets +60 % plus longs, dégâts +30 % ; brûlures et saignements +40 %.",
		"icon": "res://assets/ui/status/poison.png"},
	{"id": "sve_s_overload", "name": "Surcharge", "kind": "spell", "requires": ["arcana"], "spell": {"dmg": 0.9},
		"desc": "Ton sort niveau 10 : dégâts +90 %.",
		"icon": "res://assets/ui/skills/e0462.png"},
	{"id": "sve_s_frost", "name": "Givre éternel", "kind": "spell", "requires": ["frost_edge"], "spell": {"dmg": 0.4},
		"procs": [{"trigger": "skill_hit", "chance": 0.25, "cd": 3.0, "effect": "freeze", "duration": 1.5, "radius": 3.0}],
		"desc": "Ton sort niveau 10 : dégâts +40 % ; 25 % des sorts gèlent la cible et ses voisins (3 m, 1,5 s).",
		"icon": "res://assets/ui/status/freeze.png"},
	# --- paires de passifs -----------------------------------------------------------------------------------------------
	{"id": "sve_headsman", "name": "Bourreau", "kind": "passives", "requires": ["giant_slayer", "executioner"],
		"stat": {"elite_dmg": 0.35, "execute": 0.05},
		"desc": "Tueur de géants + Exécuteur : +35 % de dégâts contre les élites, gardiens et boss ; seuil d'exécution +5 %.",
		"icon": "res://assets/ui/skills/e0465.png"},
	{"id": "sve_undying", "name": "Immortel", "kind": "passives", "requires": ["second_wind", "bloodthirst"],
		"stat": {"lifesteal": 0.03, "hp_pct": 0.15},
		"procs": [{"trigger": "low_hp", "chance": 1.0, "cd": 45.0, "effect": "heal", "amount": 0.4,
			"then": [{"effect": "buff", "status": "barrier", "duration": 5.0}]}],
		"desc": "Second souffle + Soif de sang : PV +15 %, vol de vie +3 % ; sous 30 % de PV, rend 40 % des PV et Barrière 5 s (toutes les 45 s).",
		"icon": "res://assets/ui/status/regen.png"},
	{"id": "sve_hawk", "name": "Œil de faucon", "kind": "passives", "requires": ["hunter_eye", "precision"],
		"stat": {"crit": 0.08, "crit_dmg": 0.25},
		"desc": "Œil du chasseur + Précision : critique +8 %, dégâts critiques +25 %.",
		"icon": "res://assets/ui/status/keen.png"},
	{"id": "sve_gale", "name": "Danse des rafales", "kind": "passives", "requires": ["wind_step", "light_step"],
		"stat": {"move_speed": 0.12},
		"procs": [{"trigger": "dodge", "chance": 1.0, "cd": 3.0, "effect": "buff", "status": "haste", "duration": 4.0,
			"then": [{"effect": "buff", "status": "fury", "duration": 4.0}, {"effect": "nova", "radius": 4.0, "duration": 1.2}]}],
		"desc": "Pas du vent + Pas léger : vitesse +12 % ; esquiver donne Hâte et Fureur 4 s et gèle autour de toi (recharge 3 s).",
		"icon": "res://assets/ui/status/haste.png"},
]

static var _defs := {}


## Toutes les recettes : les 4 évolutions de Boons (genre « passives ») puis les neuves. {id, name, kind, requires, …}.
static func all() -> Array:
	if _defs.is_empty():
		for b in Boons.LIST:
			if not (b.get("requires", []) as Array).is_empty():
				var d: Dictionary = b.duplicate(true)
				d["kind"] = "passives"
				_defs[String(b.id)] = d
		for e in NEW:
			var d2: Dictionary = e.duplicate(true)
			d2["rarity"] = "legendary"
			d2["max"] = 1
			d2["sv_only"] = true
			_defs[String(e.id)] = d2
	return _defs.values()


## Définition d'une évolution neuve ({} sinon) : Boons.get_def y retombe (les 4 de Boons sont déjà dans Boons.LIST).
static func def(id: String) -> Dictionary:
	if not id.begins_with("sve_"):
		return {}
	all()
	return _defs.get(id, {})


static func get_recipe(id: String) -> Dictionary:
	all()
	return _defs.get(id, {})


## Évolution (id de passif de la partie) ?
static func is_evo(id: String) -> bool:
	all()
	return _defs.has(id)


## Évolutions prises dans la partie, dans l'ordre des recettes.
static func taken() -> Array:
	return all().filter(func(d): return Run.passives.has(String(d.id))).map(func(d): return String(d.id))


# --- recette remplie ? --------------------------------------------------------------------------------------------------
static func _power(p: String) -> float:
	return float(Run.passive_power.get(p, 0.0))


static func _weapon() -> Dictionary:
	return Profile.equipped.get("weapon", {})


## Sorts au niveau 10 sans évolution, du plus fort au plus faible (le premier reçoit l'évolution de sort).
static func spell_targets() -> Array:
	var out: Array = Run.all_skills().filter(func(s): return int(s.get("rank", 0)) >= SPELL_AT and String(s.get("evo", "")) == "")
	return out.map(func(s): return int(s.id))


## Ce qui manque à la recette [param d] : [{what, name}] (what : passive, weapon, weapon_up, spell) ; vide : prête.
## [param extra] : ingrédients qu'apporterait une carte ({passives: {id: puissance}, weapon_up: +N, wtype, spell_rank: {id: niv}}).
static func missing(d: Dictionary, extra := {}) -> Array:
	var out: Array = []
	var add_p: Dictionary = extra.get("passives", {})
	for r in d.get("requires", []):
		if _power(String(r)) + float(add_p.get(String(r), 0.0)) < 1.0 - 0.001:
			out.append({"what": "passive", "name": String(Boons.get_def(String(r)).get("name", r))})
	match String(d.get("kind", "")):
		"weapon":
			var w := _weapon()
			var wt := String(extra.get("wtype", Items.weapon_type_of(w) if not w.is_empty() else ""))
			var types: Array = d.get("wtypes", [])
			if wt == "" or not wt in types:
				out.append({"what": "weapon", "name": " / ".join(PackedStringArray(types.map(func(t): return String(GameData.weapon_type(String(t)).get("name", t)))))})
			elif maxi(int(w.get("upgrade", 0)), int(extra.get("weapon_up", 0))) < WEAPON_AT:
				out.append({"what": "weapon_up", "name": "arme à +%d" % WEAPON_AT})
		"spell":
			var ranks: Dictionary = extra.get("spell_rank", {})
			var ok := not spell_targets().is_empty()
			for id in ranks:
				if int(ranks[id]) >= SPELL_AT and String(Run.skill_entry(int(id)).get("evo", "")) == "":
					ok = true
			if not ok:
				out.append({"what": "spell", "name": "un sort niveau %d" % SPELL_AT})
	return out


## Évolutions prêtes (recette remplie, pas encore prise, pas bannie) : ids.
static func open() -> Array:
	var out: Array = []
	for d in all():
		var id := String(d.id)
		if Run.passives.has(id) or ("evo:" + id) in Run.banned:
			continue
		if missing(d).is_empty():
			out.append(id)
	return out


## La recette [param d] est-elle encore possible ? Une arme est gardée à vie : une recette d'arme d'un autre type ne l'est
## plus (ni pour une carte « Arme » d'un autre type, [param extra].wtype).
static func possible(d: Dictionary, extra := {}) -> bool:
	if String(d.get("kind", "")) != "weapon":
		return true
	var w := _weapon()
	var wt := String(extra.get("wtype", Items.weapon_type_of(w) if not w.is_empty() else ""))
	return wt == "" or wt in (d.get("wtypes", []) as Array)


## Évolutions en route (un ingrédient au moins acquis) : [{id, name, missing: [noms]}] ; prêtes : missing vide.
static func paths() -> Array:
	var out: Array = []
	for d in all():
		var id := String(d.id)
		if Run.passives.has(id) or ("evo:" + id) in Run.banned or not possible(d):
			continue
		var miss := missing(d)
		var total := (d.get("requires", []) as Array).size() + (1 if String(d.get("kind", "")) in ["weapon", "spell"] else 0)
		if miss.size() >= total:
			continue  # aucun ingrédient encore : la recette reste cachée
		out.append({"id": id, "name": String(d.name), "missing": miss.map(func(m): return String(m.name))})
	out.sort_custom(func(a, b): return (a.missing as Array).size() < (b.missing as Array).size())
	return out


## Ce qu'une carte apporte aux recettes : {passives, weapon_up, wtype, spell_rank}.
static func _gives(card: Dictionary) -> Dictionary:
	var out := {"passives": {}}
	var t := String(card.get("type", ""))
	var ps: Array = []
	if t in ["sv_piece", "sv_weapon"] and card.has("item"):
		ps = card.item.get("sv_passives", [])
		if t == "sv_weapon":
			out["wtype"] = Items.weapon_type_of(card.item)
	elif t in ["sv_piece_up", "sv_weapon_up"]:
		ps = card.get("offer", {}).get("passives", [])
		if t == "sv_weapon_up":
			out["weapon_up"] = int(card.get("offer", {}).get("to", 0))
	elif t == "upgrade":
		out["spell_rank"] = {int(card.id): int(card.get("rank_to", 0))}
	for p in ps:
		out.passives[String(p.id)] = float(out.passives.get(String(p.id), 0.0)) + float(p.get("power", 1.0))
	return out


## Indice d'évolution d'une carte (pastille verte du choix) : « ◆ Évolution prête : Séisme » si la carte remplit la recette,
## « ◆ Évolution : + Onde de choc → Séisme » si elle en apporte un ingrédient ; "" sinon.
static func hint(card: Dictionary) -> String:
	if String(card.get("type", "")) == "sv_evolution":
		return ""
	var g := _gives(card)
	var best := ""
	var best_n := 99
	var ready: Array = []
	for d in all():
		var id := String(d.id)
		if Run.passives.has(id) or ("evo:" + id) in Run.banned or not possible(d, g):
			continue
		var before := missing(d)
		if before.is_empty():
			continue  # déjà prête : la carte n'y change rien
		var after := missing(d, g)
		if after.size() >= before.size():
			continue  # la carte n'apporte rien à cette recette
		var total := (d.get("requires", []) as Array).size() + (1 if String(d.get("kind", "")) in ["weapon", "spell"] else 0)
		if not after.is_empty() and after.size() >= total:
			continue
		if after.is_empty():
			ready.append(String(d.name))
		elif after.size() < best_n:
			best_n = after.size()
			best = "◆ Évolution : + %s → %s" % [" + ".join(PackedStringArray(after.map(func(m): return String(m.name)))), String(d.name)]
	if not ready.is_empty():
		return ("◆ Évolution prête : %s" if ready.size() == 1 else "◆ Évolutions prêtes : %s") % ", ".join(PackedStringArray(ready.slice(0, 2)))
	return best


## Texte « Grâce à : … » de la carte d'évolution (ingrédients).
static func ingredients(id: String) -> String:
	var d := get_recipe(id)
	var parts: PackedStringArray = []
	for r in d.get("requires", []):
		parts.append(String(Boons.get_def(String(r)).get("name", r)))
	match String(d.get("kind", "")):
		"weapon":
			var w := _weapon()
			parts.insert(0, "%s à +%d" % [String(GameData.weapon_type(Items.weapon_type_of(w)).get("name", "Arme")) if not w.is_empty() else "Arme", WEAPON_AT])
		"spell":
			var ids := spell_targets()
			parts.insert(0, ("%s niv. %d" % [String(Run.skill_def(int(ids[0])).get("name", "Sort")), SPELL_AT]) if not ids.is_empty() else "Sort niv. %d" % SPELL_AT)
	return ", ".join(parts)


## Recette lisible d'une évolution (Codex, infobulle) : « Hache / Marteau / Espadon à +6 + Onde de choc ».
static func recipe_text(id: String) -> String:
	var d := get_recipe(id)
	var parts: PackedStringArray = []
	match String(d.get("kind", "")):
		"weapon":
			parts.append("%s à +%d" % [" / ".join(PackedStringArray((d.get("wtypes", []) as Array).map(func(t): return String(GameData.weapon_type(String(t)).get("name", t))))), WEAPON_AT])
		"spell":
			parts.append("un sort niveau %d" % SPELL_AT)
	for r in d.get("requires", []):
		parts.append(String(Boons.get_def(String(r)).get("name", r)))
	return " + ".join(parts)


# --- prendre ------------------------------------------------------------------------------------------------------------
## Carte de l'évolution [param id] ({} si elle n'existe pas) ; une évolution de sort nomme le sort qu'elle transforme.
static func card(id: String) -> Dictionary:
	var d := get_recipe(id)
	if d.is_empty():
		return {}
	var c := {"type": "sv_evolution", "id": id, "sv_key": "evo:" + id, "tier": "legendary", "title": String(d.name),
		"subtitle": "Évolution légendaire", "desc": "%s\n[color=#9a98a8]Grâce à : %s[/color]" % [String(d.get("desc", "")), ingredients(id)],
		"icon": String(d.get("icon", Boons.ICONS.get(id, "")))}
	if String(d.get("kind", "")) == "spell":
		var ids := spell_targets()
		if ids.is_empty():
			return {}
		c["skill_id"] = int(ids[0])
		c["subtitle"] = "Évolution de %s" % String(Run.skill_def(int(ids[0])).get("name", "ton sort"))
	return c


## Applique l'évolution de la carte [param c] : passif de la partie ; évolution de sort : bonus inscrits dans le sort.
static func apply(c: Dictionary) -> void:
	var id := String(c.get("id", ""))
	Run.passives[id] = 1
	Run.passive_power[id] = 1.0
	var d := get_recipe(id)
	if String(d.get("kind", "")) == "spell":
		var sid := int(c.get("skill_id", -1))
		if sid < 0 or Run.skill_entry(sid).is_empty():
			var ids := spell_targets()
			sid = int(ids[0]) if not ids.is_empty() else -1
		var s := Run.skill_entry(sid)
		if not s.is_empty():
			var sp: Dictionary = d.get("spell", {})
			# (valeurs par défaut des rangs : celles de Run.skill_damage_mult / skill_cooldown_mult)
			s["dmg"] = float(s.get("dmg", 0.2 * (int(s.rank) - 1))) + float(sp.get("dmg", 0.0))
			s["cd"] = float(s.get("cd", 0.08 * (int(s.rank) - 1))) + float(sp.get("cd", 0.0))
			s["dur"] = float(s.get("dur", 0.0)) + float(sp.get("dur", 0.0))
			s["evo"] = id
	SurvivorCodex.note_evolution(id)
	Run.changed.emit()


## La carte gardée [param c] est-elle encore valable ?
static func still_valid(c: Dictionary) -> bool:
	var id := String(c.get("id", ""))
	if Run.passives.has(id) or not missing(get_recipe(id)).is_empty():
		return false
	if c.has("skill_id"):
		return int(c.skill_id) in spell_targets()
	return true
