extends Node
## L'Échiquier, lot AC-H : effets des objets, atouts et traits (AutochessEffects, AutochessItems, AutochessTraits,
## AutochessAugments). Chaque objet (36 + composants + emblème), chaque trait (15) et chaque atout (30) montre un effet
## mesurable dans un mini-combat de données (simulateur de test ci-dessous : le vrai simulateur est le lot AC-C) ; plafonds
## (aucune statistique infinie, aucune division par zéro, aucune boucle de déclencheurs) ; ordre déterministe.
## godot --headless --path game res://tests/test_ac_effects.tscn


var fails := 0
var _uid := 1


func check(label: String, ok: bool) -> void:
	print(("OK    " if ok else "ÉCHEC ") + label)
	if not ok:
		fails += 1


# --- Fabrique d'unités -----------------------------------------------------------------------------------------------
## Unité de plateau (format board_snapshot d'AC-B) avec une fiche de base imposée ([param over] remplace des clés).
func mk(id: String, cell: Array, items: Array = [], over: Dictionary = {}) -> Dictionary:
	var u := {"uid": _uid, "id": id, "stars": 1, "copies": 1, "items": items.duplicate(), "cell": cell.duplicate(),
		"cost": AutochessPool.cost_of(id) if id != "" else 1,
		"traits": (AutochessData.unit(id).get("traits", []) as Array).duplicate() if id != "" else []}
	_uid += 1
	var s := {"hp": 2000.0, "atk": 60.0, "as": 1.0, "crit": 0.0, "mana_max": 60.0, "spell_base": 120.0, "def": 20.0,
		"mdef": 20.0, "range": float(AutochessData.unit(id).get("range", 1)) if id != "" else 1.0}
	for k in over:
		s[k] = over[k]
	u["sheet"] = s
	return u


## Sac de frappe : ne fait rien, PV énormes (pas de mort, pas de plafond de coup).
func bag(cell: Array, over: Dictionary = {}) -> Dictionary:
	var o := {"hp": 100000.0, "atk": 0.0, "as": 0.0, "passive": true, "mana_max": 140.0}
	for k in over:
		o[k] = over[k]
	return mk("", cell, [], o)


func bags(over: Dictionary = {}) -> Array:
	return [bag([3, 0], over), bag([2, 0], over), bag([4, 0], over)]


## Assaillants : frappent le porteur, ne lancent pas de sort.
func attackers(over: Dictionary = {}) -> Array:
	var out: Array = []
	for c in [[3, 0], [2, 0], [4, 0]]:
		var o := {"hp": 100000.0, "atk": 40.0, "as": 1.0, "no_spell": true, "mana_max": 140.0}
		for k in over:
			o[k] = over[k]
		out.append(mk("", c, [], o))
	return out


func fctx(traits_a: Dictionary = {}, augments_a: Array = [], seed_v := 7) -> Dictionary:
	return {"stage": 3, "round": 1, "kind": "jcj", "seed": seed_v, "augments": [augments_a, []], "traits": [traits_a, {}]}


# --- Mini-simulateur de test -----------------------------------------------------------------------------------------
## Combat de données minimal : cible = ennemi le plus proche, marche à 3 m/s, attaque au rythme de stat("as"), sort à mana
## pleine (dégâts sur la cible et les ennemis à 1 case ; soin de l'allié le plus bas si « heals »).
func sim(team_a: Array, team_b: Array, fc: Dictionary, dur := 10.0, dt := 0.1) -> Dictionary:
	var ctx := AutochessEffects.context(fc, [team_a, team_b])
	ctx["keep_log"] = true
	AutochessEffects.start(ctx)
	var timers := {}
	var ids: Array = (ctx.units as Dictionary).keys()
	ids.sort()
	var magic_t := {}
	for _i in int(round(dur / dt)):
		AutochessEffects.tick(ctx, dt)
		if AutochessEffects.living(ctx, 0).is_empty() or AutochessEffects.living(ctx, 1).is_empty():
			break
		for fid in ids:
			var u: Dictionary = ctx.units[fid]
			if not u.alive or AutochessEffects.disabled(ctx, fid):
				continue
			var foes := AutochessEffects.near(ctx, int(u.side), u.pos)
			if foes.is_empty():
				break
			var tgt: int = foes[0]
			if float(u.base.get("magic_dps", 0.0)) > 0.0:
				magic_t[fid] = float(magic_t.get(fid, 0.0)) + dt
				if float(magic_t[fid]) >= 1.0:
					magic_t[fid] = float(magic_t[fid]) - 1.0
					AutochessEffects.damage(ctx, fid, tgt, float(u.base.magic_dps), {"kind": "magic"})
			if u.base.get("passive", false):
				continue
			if not u.base.get("no_spell", false) and AutochessEffects.can_cast(ctx, fid):
				var fx := AutochessEffects.cast(ctx, fid)
				_spell(ctx, fid, tgt)
				for e in fx:
					if String(e.type) == "recast":
						_spell(ctx, fid, tgt)
				continue
			if AutochessEffects.dist(ctx, fid, tgt) > AutochessEffects.stat(ctx, fid, "reach"):
				var p: Vector2 = u.pos
				var to: Vector2 = ctx.units[tgt].pos
				AutochessEffects.set_pos(ctx, fid, p + (to - p).normalized() * minf(3.0 * AutochessEffects.stat(ctx, fid, "move") * dt, p.distance_to(to)))
				continue
			timers[fid] = float(timers.get(fid, 0.0)) + dt * AutochessEffects.stat(ctx, fid, "as")
			if float(timers[fid]) >= 1.0:
				timers[fid] = float(timers[fid]) - 1.0
				AutochessEffects.attack(ctx, fid, tgt)
	return ctx


func _spell(ctx: Dictionary, fid: int, tgt: int) -> void:
	var u: Dictionary = ctx.units[fid]
	if u.base.get("heals", false):
		var low := -1
		for f in AutochessEffects.living(ctx, int(u.side)):
			if low < 0 or AutochessEffects.hp_frac(ctx.units[f]) < AutochessEffects.hp_frac(ctx.units[low]):
				low = f
		AutochessEffects.spell_heal(ctx, fid, low, float(u.sheet.spell_base))
		return
	var tpos: Vector2 = ctx.units[tgt].pos
	for f in AutochessEffects.near(ctx, int(u.side), tpos, AutochessData.CELL):
		AutochessEffects.spell_hit(ctx, fid, f, 0.0)


## Mesure sur un combat : statistique cumulée d'un groupe (« holder » = fid 0, « side0 », « foes ») ou valeur spéciale.
func metric(ctx: Dictionary, key: String, who := "holder") -> float:
	match key:
		"gold":
			return float(ctx.gold[0])
		"hp_end":
			return float(ctx.units[0].hp)
		"hp_max":
			return float(ctx.units[0].hp_max)
	var ids: Array = []
	match who:
		"holder":
			ids = [0]
		"side0":
			ids = ctx.sides[0]
		"foes":
			ids = ctx.sides[1]
	var v := 0.0
	for f in ids:
		v += float(ctx.units[f].stats.get(key, 0.0))
	return v


## Un cas : équipe A et B construites par [param setup] avec / sans l'objet, mesure [param key] ; sens +1 ou -1.
func setup(kind: String, holder_id: String, items: Array) -> Array:
	match kind:
		"sac":
			return [[mk(holder_id, [3, 1], items)], bags()]
		"sac_crit":
			return [[mk(holder_id, [3, 1], items, {"crit": 0.5})], bags()]
		"sac_bas":
			return [[mk(holder_id, [3, 1], items)], bags({"hp_start": 20000.0})]
		"sac_tres_bas":
			return [[mk(holder_id, [3, 1], items)], bags({"hp_start": 9000.0})]
		"sac_dur":
			return [[mk(holder_id, [3, 1], items)], bags({"def": 150.0})]
		"loin":
			return [[mk(holder_id, [3, 3], items, {"range": 4.0})], bags()]
		"assaut":
			return [[mk(holder_id, [3, 1], items, {"hp": 6000.0})], attackers()]
		"assaut_esquive":
			return [[mk(holder_id, [3, 1], items, {"hp": 6000.0, "dodge": 0.3})], attackers()]
		"magie":
			return [[mk(holder_id, [3, 1], items, {"hp": 6000.0})], attackers({"atk": 0.0, "magic_dps": 80.0})]
		"bas":
			return [[mk(holder_id, [3, 1], items, {"hp": 3000.0, "hp_start": 1600.0})], attackers({"atk": 60.0})]
		"chute":
			return [[mk(holder_id, [3, 1], items, {"hp": 400.0})], attackers({"atk": 120.0})]
		"tuer":
			return [[mk(holder_id, [3, 1], items, {"atk": 200.0})], bags({"hp": 150.0})]
		"mana_ennemi":
			return [[mk(holder_id, [3, 1], items, {"hp": 6000.0})], attackers()]
	return [[], []]


func run_case(kind: String, holder_id: String, items: Array, fc: Dictionary, dur := 12.0) -> Dictionary:
	var teams := setup(kind, holder_id, items)
	return sim(teams[0], teams[1], fc, dur)


func _ready() -> void:
	test_items()
	test_components()
	test_traits()
	test_combat_augments()
	test_game_augments()
	test_caps()
	test_loops()
	test_determinism()
	test_result_format()
	print("Échecs : %d" % fails)
	get_tree().quit(1 if fails > 0 else 0)


# --- 1. les 36 objets ------------------------------------------------------------------------------------------------
## objet -> [mise en place, mesure, qui, sens]
const ITEM_CASES := {
	"executeur": ["sac_bas", "dealt", "holder", 1], "transe": ["sac", "attacks", "holder", 1],
	"lame_statique": ["sac", "dealt_proc", "holder", 1], "echo": ["sac", "dealt", "holder", 1],
	"soif_de_sang": ["assaut", "healed", "holder", 1], "briseur_sorts": ["mana_ennemi", "mana_lost", "foes", 1],
	"tueur_geants": ["sac", "dealt", "holder", 1], "precision": ["sac", "crits", "holder", 1],
	"lame_vive": ["sac", "attacks", "holder", 1], "tir_multiple": ["sac", "dealt_proc", "holder", 1],
	"elan": ["sac", "casts", "holder", 1], "pas_du_vent": ["assaut", "dodges", "holder", 1],
	"ricochet": ["sac", "dealt_proc", "holder", 1], "second_souffle": ["bas", "healed", "holder", 1],
	"oeil_chasseur": ["sac", "crits", "holder", 1], "arcanes": ["sac", "dealt_spell", "holder", 1],
	"incantation": ["sac", "casts", "holder", 1], "onde_de_choc": ["sac", "cc_done", "holder", 1],
	"nova_givre": ["sac", "cc_done", "holder", 1], "braise": ["sac", "dealt_proc", "holder", 1],
	"sort_critique": ["sac", "crits", "holder", 1], "source": ["sac", "casts", "holder", 1],
	"barriere": ["sac", "shielded", "holder", 1], "persistance": ["sac", "zone_dealt", "holder", 1],
	"vigueur": ["assaut", "healed", "holder", 1], "flux_combo": ["sac_crit", "mana_gained", "holder", 1],
	"robustesse": ["assaut", "taken", "holder", -1], "mur_titan": ["assaut", "taken", "holder", -1],
	"brute": ["assaut", "hp_end", "holder", 1], "coup_final": ["sac", "cc_done", "holder", 1],
	"lame_givre": ["assaut", "attacks", "foes", -1], "ange_gardien": ["bas", "blocked", "holder", 1],
	"volatile": ["chute", "dealt", "holder", 1], "colosse": ["assaut", "hp_end", "holder", 1],
	"plaies": ["sac", "dealt_proc", "holder", 1], "fortune": ["tuer", "gold", "holder", 1],
}


func test_items() -> void:
	var all_ok := ITEM_CASES.size() == AutochessData.ITEMS.size()
	for id in AutochessData.ITEMS:
		all_ok = all_ok and ITEM_CASES.has(id)
	check("un cas de test par objet (%d)" % AutochessData.ITEMS.size(), all_ok)
	for id in AutochessData.ITEMS:
		var c: Array = ITEM_CASES.get(id, [])
		if c.is_empty():
			continue
		# Persistance : porteur Élémentaire (sa zone dure plus longtemps et s'élargit)
		var holder := "magician" if id == "persistance" else "warrior"
		var tr := {"elementaire": 2} if id == "persistance" else {}
		var without := run_case(String(c[0]), holder, [], fctx(tr))
		var with := run_case(String(c[0]), holder, [id], fctx(tr))
		var m0 := metric(without, String(c[1]), String(c[2]))
		var m1 := metric(with, String(c[1]), String(c[2]))
		var ok := (m1 > m0 + 0.001) if int(c[3]) > 0 else (m1 < m0 - 0.001)
		check("objet %s : %s %s (%.1f -> %.1f)" % [id, c[1], "monte" if int(c[3]) > 0 else "baisse", m0, m1], ok)


# --- 2. composants et emblème ------------------------------------------------------------------------------------------
const COMPONENT_CASES := {
	"lame": ["sac", "dealt", 1], "arc": ["sac", "attacks", 1], "baton": ["sac", "dealt_spell", 1],
	"larme": ["sac", "casts", 1], "plastron": ["assaut", "taken", -1], "voile": ["magie", "taken", -1],
	"ceinture": ["assaut", "hp_end", 1], "gant": ["sac", "crits", 1],
}


func test_components() -> void:
	for id in AutochessData.BASE_COMPONENTS:
		var c: Array = COMPONENT_CASES[id]
		var m0 := metric(run_case(String(c[0]), "warrior", [], fctx()), String(c[1]))
		var m1 := metric(run_case(String(c[0]), "warrior", [id], fctx()), String(c[1]))
		check("composant %s : %s (%.1f -> %.1f)" % [id, c[1], m0, m1], (m1 > m0) if int(c[2]) > 0 else (m1 < m0))
	# Emblème : stats de son composant ; son trait compte pour AC-B (unit_traits)
	var emb := "embleme:lame:tir"
	var m0 := metric(run_case("sac", "warrior", [], fctx()), "dealt")
	var m1 := metric(run_case("sac", "warrior", [emb], fctx()), "dealt")
	var tr := Autochess.unit_traits({"id": "warrior", "items": [emb]})
	check("emblème : stats du composant (%.0f -> %.0f) et trait ajouté %s" % [m0, m1, str(tr)], m1 > m0 and "tir" in tr)
	# Insigne seule et objets qui ne s'équipent pas : aucune stat (rien d'infini, rien de cassé)
	var ctx := AutochessEffects.context(fctx(), [[mk("warrior", [3, 1], ["insigne", "couronne", "marteau_reforge"])], bags()])
	var ref := AutochessEffects.context(fctx(), [[mk("warrior", [3, 1], [])], bags()])
	check("Insigne, Couronne, Marteau portés : fiche inchangée", ctx.units[0].sheet == ref.units[0].sheet)


# --- 3. les 15 traits ------------------------------------------------------------------------------------------------
## trait -> [porteur, mise en place, mesure, qui, sens]
const TRAIT_CASES := {
	"rempart": ["warrior", "assaut", "taken", "holder", -1], "ombre": ["thief", "sac_crit", "dealt", "holder", 1],
	"traque": ["hunter", "loin", "dealt", "holder", 1], "ferveur": ["cleric", "assaut", "healed", "holder", 1],
	"arcane": ["magician", "sac", "dealt_spell", "holder", 1], "escrime": ["templar", "assaut", "parries", "holder", 1],
	"tir": ["hunter", "sac", "attacks", "holder", 1], "elementaire": ["magician", "sac", "zone_dealt", "holder", 1],
	"tranchant": ["thief", "sac_tres_bas", "executes", "holder", 1], "fracas": ["warrior", "sac", "cc_done", "holder", 1],
	"estoc": ["knight", "sac_dur", "dealt", "holder", 1], "poudre": ["engineer", "sac", "dealt_proc", "holder", 1],
	"choeur": ["cleric", "sac", "mana_gained", "holder", 1], "malediction": ["warlock", "assaut", "taken", "holder", -1],
	"impact": ["martial_artist", "sac", "dealt", "holder", 1],
}


func test_traits() -> void:
	var all_ok := TRAIT_CASES.size() == AutochessData.TRAITS.size()
	for t in AutochessData.TRAITS:
		all_ok = all_ok and TRAIT_CASES.has(t)
	check("un cas de test par trait (%d)" % AutochessData.TRAITS.size(), all_ok)
	var climb_bad: Array = []
	for t in AutochessData.TRAITS:
		var c: Array = TRAIT_CASES.get(t, [])
		if c.is_empty():
			continue
		var ths: Array = AutochessData.trait_thresholds(t)
		var sgn := int(c[4])
		var m := []
		for count in [0, int(ths[0]), int(ths[2])]:
			var tr := {} if count == 0 else {t: count}
			m.append(metric(run_case(String(c[1]), String(c[0]), [], fctx(tr)), String(c[2]), String(c[3])))
		var ok: bool = (m[1] > m[0] + 0.001) if sgn > 0 else (m[1] < m[0] - 0.001)
		check("trait %s (palier 1) : %s %s (%.1f -> %.1f)" % [t, c[2], "monte" if sgn > 0 else "baisse", m[0], m[1]], ok)
		var climb: bool = (m[2] >= m[1] - 0.001) if sgn > 0 else (m[2] <= m[1] + 0.001)
		if not climb:
			climb_bad.append("%s %.1f/%.1f" % [t, m[1], m[2]])
	check("palier 3 au moins aussi fort que le palier 1 (%s)" % str(climb_bad), climb_bad.is_empty())
	# Effets des paliers hauts qui ne se voient pas au palier 1
	var c9 := AutochessEffects.context(fctx({"rempart": 9}), [[mk("warrior", [3, 1]), mk("hunter", [2, 3])], bags()])
	var c0 := AutochessEffects.context(fctx({}), [[mk("warrior", [3, 1]), mk("hunter", [2, 3])], bags()])
	var team_hp := float(AutochessData.TRAITS.rempart.tiers[2].team_hp_pct)  # réglage (AC-J : 0,10)
	check("Rempart à 9 : PV de toute l'équipe +%.0f %%" % (100.0 * team_hp), team_hp > 0.0
		and is_equal_approx(float(c9.units[1].hp_max), float(c0.units[1].hp_max) * (1.0 + team_hp)))
	var arc := sim([mk("magician", [3, 1])], bags(), fctx({"arcane": 9}), 8.0)
	check("Arcane à 9 : le 1er sort part deux fois", _count(arc, "recast") >= 1)
	var omb := sim([mk("thief", [3, 1])], bags(), fctx({"ombre": 3}), 1.0)
	check("Ombre : saut sur l'arrière ennemi au début (« leap »)", _count(omb, "leap") == 1)
	var traq := AutochessEffects.context(fctx({"traque": 6}), [[mk("hunter", [3, 1])], bags()])
	check("Traque à 6 : portée +1", float(traq.units[0].sheet.range) == float(AutochessData.unit("hunter").range) + 1.0)
	var fv := AutochessEffects.context(fctx({"ferveur": 9}), [[mk("cleric", [3, 1])], bags()])
	check("Ferveur à 9 : soins reçus +30 %", is_equal_approx(float(fv.units[0].sheet.heal_taken), 1.3))
	var tir := sim([mk("hunter", [3, 1], [], {"range": 4.0, "no_spell": true})], [bag([3, 0]), bag([2, 1])], fctx({"tir": 6}), 6.0)
	check("Tir à 6 : les flèches traversent (ennemi derrière touché)", float(tir.units[2].stats.taken) > 0.0)
	var el := sim([mk("magician", [3, 1])], bags(), fctx({"elementaire": 6}), 10.0)
	check("Élémentaire à 6 : la zone ralentit", _has_buff(el, "zone_lente"))


func _count(ctx: Dictionary, type: String) -> int:
	return (ctx.log as Array).filter(func(e): return String(e.type) == type).size()


func _has_buff(ctx: Dictionary, tag: String) -> bool:
	for e in ctx.log:
		if String(e.type) == "buff" and String(e.get("tag", "")) == tag:
			return true
	return false


# --- 4. atouts de combat ---------------------------------------------------------------------------------------------
const AUGMENT_CASES := {
	"peau_dure": ["assaut", "hp_end", "holder", 1], "premier_sang": ["sac", "dealt", "holder", 1],
	"esquive_aiguisee": ["assaut", "dodges", "holder", 1], "mana_vive": ["sac", "casts", "holder", 1],
	"chef_de_guerre": ["sac", "dealt", "holder", 1], "riposte": ["assaut_esquive", "dealt_proc", "holder", 1],
	"garde_du_corps": ["assaut", "shielded", "holder", 1], "main_sure": ["sac", "casts", "holder", 1],
	"ordre_de_bataille": ["sac", "attacks", "holder", 1],
	# lot ACX-3
	"ligne_de_boucliers": ["assaut", "shielded", "holder", 1], "porte_etendard": ["sac", "dealt", "holder", 1],
	"trinite": ["sac", "dealt", "holder", 1], "grand_grimoire": ["sac", "casts", "holder", 1],
	"serment_rempart": ["assaut", "hp_end", "holder", 1],
}


func test_combat_augments() -> void:
	var combat := AutochessData.AUGMENTS.keys().filter(func(k): return AutochessAugments.scope(k) in ["combat", "les deux"])
	var game := AutochessData.AUGMENTS.keys().filter(func(k): return AutochessAugments.scope(k) in ["partie", "les deux"])
	var unknown := AutochessData.AUGMENTS.keys().filter(func(k): return AutochessAugments.scope(k) == "")
	check("chaque atout a sa place : %d de combat, %d de partie, aucun oublié %s" % [combat.size(), game.size(), str(unknown)],
		unknown.is_empty() and combat.size() >= 11)
	for id in AUGMENT_CASES:
		var c: Array = AUGMENT_CASES[id]
		var m0 := metric(run_case(String(c[0]), "warrior", [], fctx({}, [])), String(c[1]), String(c[2]))
		var m1 := metric(run_case(String(c[0]), "warrior", [], fctx({}, [id])), String(c[1]), String(c[2]))
		check("atout %s : %s (%.1f -> %.1f)" % [id, c[1], m0, m1], (m1 > m0) if int(c[3]) > 0 else (m1 < m0))
	# Ralliement : un allié tombe, les autres se soignent
	var team := [mk("warrior", [3, 1], [], {"hp": 6000.0, "hp_start": 3000.0, "atk": 0.0}), mk("knight", [2, 0], [], {"hp": 100.0})]
	var r0 := sim(team.duplicate(true), attackers({"atk": 200.0}), fctx({}, []), 4.0)
	var r1 := sim(team.duplicate(true), attackers({"atk": 200.0}), fctx({}, ["ralliement"]), 4.0)
	check("atout ralliement : soins à la chute d'un allié (%.0f -> %.0f)" % [metric(r0, "healed"), metric(r1, "healed")],
		metric(r1, "healed") > metric(r0, "healed") and not r1.units[1].alive)
	# Héritage : une classe verte et son ascension
	var asc := ""
	for uid in AutochessData.unit_ids():
		var d := AutochessData.unit(uid)
		if String(d.lineage) != "verte" and String(d.parent) == "warrior":
			asc = uid
			break
	var pair := [mk("warrior", [3, 1]), mk(asc, [2, 1])]
	var h0 := sim(pair.duplicate(true), bags(), fctx({}, []), 6.0)
	var h1 := sim(pair.duplicate(true), bags(), fctx({}, ["heritage"]), 6.0)
	check("atout héritage (warrior + %s) : dégâts (%.0f -> %.0f)" % [asc, metric(h0, "dealt", "side0"), metric(h1, "dealt", "side0")],
		asc != "" and metric(h1, "dealt", "side0") > metric(h0, "dealt", "side0"))
	# Chef de guerre : seulement l'unité la plus chère
	var duo := [mk("warrior", [3, 1]), mk("assassin", [2, 1])]
	var cg := AutochessEffects.context(fctx({}, ["chef_de_guerre"]), [duo, bags()])
	var cg0 := AutochessEffects.context(fctx({}, []), [duo, bags()])
	check("chef de guerre : l'unité la plus chère seule (%s)" % AutochessData.unit_name("assassin"),
		float(cg.units[1].hp_max) > float(cg0.units[1].hp_max) and float(cg.units[0].hp_max) == float(cg0.units[0].hp_max))
	# Menace (combat) : gardien deux fois plus fort (« mult » posé par AC-B)
	var g1 := sim([mk("warrior", [3, 1])], [{"guardian": true, "stage": 3, "mult": 1.0, "cell": [3, 0]}], fctx(), 6.0)
	var g2 := sim([mk("warrior", [3, 1])], [{"guardian": true, "stage": 3, "mult": 2.0, "cell": [3, 0]}], fctx(), 6.0)
	check("atout menace : gardien plus solide et plus fort (PV max ×2, dégâts subis %.0f -> %.0f)" % [metric(g1, "taken"), metric(g2, "taken")],
		is_equal_approx(float(g2.units[1].hp_max), 2.0 * float(g1.units[1].hp_max)) and metric(g2, "taken") > metric(g1, "taken"))
	# Cœur de famille / Double trait : un compte de plus (AC-B) -> un palier de plus en combat
	var g := _game()
	var p: Dictionary = g.players[0]
	p["board"] = [_bu(g, "warrior", [3, 0]), _bu(g, "knight", [2, 0])]
	var before := int(g.trait_counts(0).get("rempart", 0))
	g._take_augment(0, "coeur_de_famille")
	var guard := 0
	while not g.pending(0).is_empty() and String(g.pending(0).kind) != "famille" and guard < 5:
		g.choose(0, 0)
		guard += 1
	var idx := (g.pending(0).get("options", []) as Array).find("rempart")
	if idx >= 0:
		g.choose(0, idx)
	var after := int(g.trait_counts(0).get("rempart", 0))
	var fc0 := fctx({"rempart": before})
	var fc1 := fctx({"rempart": after})
	var t0 := metric(run_case("assaut", "warrior", [], fc0), "taken")
	var t1 := metric(run_case("assaut", "warrior", [], fc1), "taken")
	check("atout cœur de famille : Rempart %d -> %d, dégâts subis (%.0f -> %.0f)" % [before, after, t0, t1],
		after == before + 1 and t1 < t0)
	var g2b := _game()
	var p2: Dictionary = g2b.players[0]
	p2["board"] = [_bu(g2b, "warrior", [3, 0]), _bu(g2b, "berserker", [2, 0]), _bu(g2b, "sage", [4, 0])]
	var fr0 := int(g2b.trait_counts(0).get("fracas", 0))
	g2b._take_augment(0, "double_trait")
	var fr1 := int(g2b.trait_counts(0).get("fracas", 0))
	var s0 := metric(run_case("sac", "warrior", [], fctx({"fracas": fr0})), "cc_done")
	var s1 := metric(run_case("sac", "warrior", [], fctx({"fracas": fr1})), "cc_done")
	check("atout double trait : Fracas %d -> %d, étourdissements (%.0f -> %.0f)" % [fr0, fr1, s0, s1], fr1 == fr0 + 1 and s1 > s0)


func _game() -> Autochess:
	var g := Autochess.new()
	g.save_path = ""
	g.start(11, [])
	return g


func _bu(g: Autochess, id: String, cell: Array) -> Dictionary:
	var u: Dictionary = g._make_unit(id, 1, 1)
	u["cell"] = cell
	return u


# --- 5. atouts de partie (appliqués par Autochess, AC-B) : chacun change l'état de la partie ---------------------------
func test_game_augments() -> void:
	var bad: Array = []
	for id in AutochessData.AUGMENTS:
		if AutochessAugments.scope(id) == "combat":
			continue
		var g0 := _game()
		var g1 := _game()
		var ok := _game_effect(id, g0, g1)
		if not ok:
			bad.append(id)
	check("atouts de partie : effet mesurable sur la partie (%s)" % str(bad), bad.is_empty())


## Applique l'atout [param id] dans g1 (g0 = témoin) et compare.
func _game_effect(id: String, g0: Autochess, g1: Autochess) -> bool:
	var p0: Dictionary = g0.players[0]
	var p1: Dictionary = g1.players[0]
	for p in [p0, p1]:
		p["gold"] = 40
	g1._take_augment(0, id)
	match id:
		"tirelire":
			return int(g1.income_for(0, 2, 2).total) == int(g0.income_for(0, 2, 2).total) + 1
		"relance_offerte":
			g0._round_income(p0)
			g1._round_income(p1)
			return int(p1.free_rerolls) == int(p0.free_rerolls) + 1
		"apprenti":
			return int(p1.level) * 1000 + int(p1.xp) > int(p0.level) * 1000 + int(p0.xp)
		"composant":
			return "composant" in _kinds(p1) and not "composant" in _kinds(p0)
		"renfort":
			return g1.units_of(0).size() == g0.units_of(0).size() + 2
		"interets_composes":
			p0["gold"] = 100
			p1["gold"] = 100
			return int(g1.income_for(0, 2, 2).interest) == 10 and int(g0.income_for(0, 2, 2).interest) == 5
		"pacte_de_sang":
			return int(p1.hp) == int(p0.hp) - 15 and int(p1.gold) == int(p0.gold) + 25
		"insigne":
			return "insigne" in p1.items
		"echo_recrue":
			return _buy4(g1) == _buy4(g0) + 1
		"forge_de_campagne", "menace":
			for g in [g0, g1]:
				g.stage = 3
				g.round_i = 7
				g._pve_outcome(0, true, [], true)
			var extra := (p1.pending as Array).size() > (p0.pending as Array).size()
			if id == "menace":
				return extra and is_equal_approx(g1.guardian_mult(0), 2.0) and int(p1.gold) > int(p0.gold)
			return extra
		"couronne":
			return g1.board_cap(0) == g0.board_cap(0) + 1
		"heros_legendaire":
			return "heros" in _kinds(p1) and not "heros" in _kinds(p0)
		"tresor_du_dragon":
			return int(p1.gold) == int(p0.gold) + int(AutochessData.augment(id).params.gold) and int(g1.income_for(0, 2, 2).interest) == 0
		"niveau_11":
			return int(p1.max_level) == 11 and int(p0.max_level) == 10
		"etoile_filante":
			var cheap := String(AutochessData.units_of_cost(1)[0])
			return g1._need(p1, cheap, 1) == 2 and g0._need(p0, cheap, 1) == 3
		"arsenal":
			return (p1.pending as Array).filter(func(c): return String(c.kind) == "objet").size() == 2
		"coeur_de_famille":
			return "famille" in _kinds(p1) and not "famille" in _kinds(p0)
		"double_trait":
			p0["board"] = [_bu(g0, "warrior", [3, 0]), _bu(g0, "berserker", [2, 0]), _bu(g0, "sage", [4, 0])]
			p1["board"] = [_bu(g1, "warrior", [3, 0]), _bu(g1, "berserker", [2, 0]), _bu(g1, "sage", [4, 0])]
			return int(g1.trait_counts(0).get("fracas", 0)) == int(g0.trait_counts(0).get("fracas", 0)) + 1
		# lot ACX-3
		"maitre_armes", "grand_coeur":
			var guard := 0
			while not g1.pending(0).is_empty() and String(g1.pending(0).kind) != "famille" and guard < 5:
				g1.choose(0, 0)  # (l'ouverture de 1-1 passe d'abord)
				guard += 1
			var c: Dictionary = g1.pending(0)
			if String(c.get("kind", "")) != "famille":
				return false
			var t := String(c.options[0])
			var want := 2 if id == "grand_coeur" else 1
			var kind_ok := String(AutochessData.TRAITS[t].kind) == ("famille" if id == "grand_coeur" else "arme")
			var before := int(g1.trait_counts(0).get(t, 0))
			g1.choose(0, 0)
			return kind_ok and int(g1.trait_counts(0).get(t, 0)) == before + want
		"recrue_doree":
			var hs := (p1.pending as Array).filter(func(c): return String(c.kind) == "heros")
			return hs.size() == 1 and int(hs[0].stars) == 1 and AutochessPool.cost_of(String(hs[0].options[0])) == 3
		"atelier", "miroir_des_ames":
			var want: Array = AutochessData.augment(id).params.items
			return want.all(func(x): return x in p1.items) and not "pince" in p0.items
		"serment_rempart", "pacte_ombre", "piste_traque", "flamme_ferveur", "savoir_arcane":
			var t := String(AutochessData.augment(id).params.trait)
			return int(g1.trait_counts(0).get(t, 0)) == int(g0.trait_counts(0).get(t, 0)) + 1
		"jumeaux":
			for g in [g0, g1]:
				g.players[0]["board"] = [_bu(g, "warrior", [3, 0])]
			(p1.augments as Array).erase(id)
			g1._take_augment(0, id)
			return g1.units_of(0).size() == g0.units_of(0).size() + 1
	return false


func _kinds(p: Dictionary) -> Array:
	return (p.pending as Array).map(func(c): return String(c.kind))


## Achète 4 unités (boutique rafraîchie entre deux achats) ; rend le nombre de copies reçues.
func _buy4(g: Autochess) -> int:
	var p: Dictionary = g.players[0]
	p["pending"] = []
	p["gold"] = 100
	var n0 := 0
	for u in g.units_of(0):
		n0 += int(u.copies)
	var bought := 0
	var guard := 0
	while bought < 4 and guard < 40:
		guard += 1
		g._refresh_shop(p)
		if g.buy(0, 0):
			bought += 1
	var n1 := 0
	for u in g.units_of(0):
		n1 += int(u.copies)
	return n1 - n0


# --- 6. plafonds, divisions par zéro -----------------------------------------------------------------------------------
func test_caps() -> void:
	# Tout empilé sur une unité : vitesse, esquive, critique, PV, mana max, défense, pénétration… bornés
	var stack := ["lame_vive", "transe", "lame_vive", "precision", "precision", "precision"]
	var u := mk("hunter", [3, 1], stack, {"as": 4.0, "crit": 0.9, "dodge": 0.5, "crit_dmg": 2.5})
	var ctx := sim([u, mk("templar", [2, 1], ["pas_du_vent", "pas_du_vent", "mur_titan"], {"dodge": 0.55, "parry": 0.5})],
		attackers(), fctx({"tir": 6, "escrime": 6, "estoc": 6}, ["ordre_de_bataille", "esquive_aiguisee", "main_sure"]), 15.0)
	var as_v := AutochessEffects.stat(ctx, 0, "as")
	var crit := float(ctx.units[0].sheet.crit)
	var dodge := AutochessEffects.stat(ctx, 1, "dodge")
	var parry := float(ctx.units[1].sheet.parry)
	check("vitesse d'attaque bornée (%.2f ≤ %.1f)" % [as_v, float(AutochessEffects.CAPS["as"][1])], as_v <= float(AutochessEffects.CAPS["as"][1]) + 0.001)
	check("critique ≤ 100 %%, dégâts critiques ≤ ×%.0f" % (1.0 + float(AutochessEffects.CAPS.crit_dmg[1])),
		crit <= 1.0 and float(ctx.units[0].sheet.crit_dmg) <= float(AutochessEffects.CAPS.crit_dmg[1]))
	check("esquive bornée (%.2f) et parade bornée (%.2f)" % [dodge, parry], dodge <= 0.6001 and parry <= 0.6001)
	# Fiches dégénérées : zéro partout, valeurs énormes ou négatives -> aucun NaN, aucune division par zéro
	var zero := mk("", [3, 1], ["incantation", "incantation", "incantation"], {"hp": 0.0, "atk": 0.0, "as": 0.0, "mana_max": 0.0,
		"def": -500.0, "mdef": 0.0, "spell_base": 0.0, "dmg_taken": 0.0})
	var huge := mk("", [3, 0], ["colosse", "colosse", "colosse"], {"hp": 1e9, "atk": 1e9, "as": 1e6, "def": 1e9})
	var c2 := sim([zero], [huge], fctx(), 5.0)
	var nan_free := true
	for fid in c2.units:
		var w: Dictionary = c2.units[fid]
		for k in w.sheet:
			if typeof(w.sheet[k]) == TYPE_FLOAT and (is_nan(float(w.sheet[k])) or is_inf(float(w.sheet[k]))):
				nan_free = false
		nan_free = nan_free and not is_nan(float(w.hp)) and not is_nan(float(w.mana))
	check("fiches nulles / énormes : aucune valeur NaN ou infinie", nan_free)
	check("mana max jamais sous 10 (3 Incantations sur une mana nulle : %.0f)" % float(c2.units[0].sheet.mana_max),
		float(c2.units[0].sheet.mana_max) >= 10.0)
	check("plafond d'un coup : 20 % des PV max (hors gardiens)", _max_hit(c2, 0) <= 0.2 * float(c2.units[0].hp_max) + 0.01)
	# Un coup sur un gardien n'est pas plafonné
	var cg := sim([mk("warrior", [3, 1], [], {"atk": 5000.0})], [{"guardian": true, "stage": 2, "mult": 1.0, "cell": [3, 0]}],
		fctx(), 3.0)
	check("gardien : coups non plafonnés", _max_hit(cg, 1) > 0.2 * float(cg.units[1].hp_max))


func _max_hit(ctx: Dictionary, dst: int) -> float:
	var m := 0.0
	for e in ctx.log:
		if String(e.type) == "damage" and int(e.dst) == dst and not String(e.tag) in ["acheve"]:
			m = maxf(m, float(e.amount))
	return m


# --- 7. boucles de déclencheurs --------------------------------------------------------------------------------------
func test_loops() -> void:
	# Deux murs qui se renvoient les coups, parent et ripostent : aucun appel ne déborde, le combat avance
	var wall := ["robustesse", "robustesse", "pas_du_vent"]
	var a := [mk("templar", [3, 1], wall, {"dodge": 0.4}), mk("templar", [2, 1], ["volatile", "lame_statique", "ricochet"])]
	var b := [mk("templar", [3, 0], wall, {"dodge": 0.4}), mk("templar", [2, 0], ["volatile", "tir_multiple", "ricochet"])]
	var fc := {"stage": 3, "kind": "jcj", "seed": 3, "augments": [["riposte", "ralliement"], ["riposte", "ralliement"]],
		"traits": [{"escrime": 6, "poudre": 6}, {"escrime": 6, "poudre": 6}]}
	var ctx := AutochessEffects.context(fc, [a, b])
	AutochessEffects.start(ctx)
	var biggest := 0
	for _i in 300:
		var n := AutochessEffects.tick(ctx, 0.1).size()
		for s in [[0, 2], [2, 0], [1, 3], [3, 1]]:
			if AutochessEffects.alive(ctx, s[0]) and AutochessEffects.alive(ctx, s[1]):
				n = maxi(n, AutochessEffects.attack(ctx, s[0], s[1]).size())
		biggest = maxi(biggest, n)
	check("aucune cascade sans fin : au plus %d effets par appel (vu : %d), profondeur revenue à 0" % [AutochessEffects.MAX_EFFECTS_PER_CALL, biggest],
		biggest <= AutochessEffects.MAX_EFFECTS_PER_CALL and int(ctx.depth) == 0)
	# Un renvoi ne renvoie jamais un renvoi
	var reflects := 0
	var c2 := sim([mk("warrior", [3, 1], ["robustesse"], {"hp": 8000.0})], [mk("warrior", [3, 0], ["robustesse"], {"hp": 8000.0})], fctx(), 6.0)
	for e in c2.log:
		if String(e.type) == "damage" and String(e.tag) == "epines":
			reflects += 1
	var hits := 0
	for e in c2.log:
		if String(e.type) == "damage" and String(e.tag) == "attaque":
			hits += 1
	check("Robustesse contre Robustesse : un renvoi par coup, pas plus (%d renvois, %d coups)" % [reflects, hits],
		reflects > 0 and reflects <= hits)


# --- 8. ordre déterministe ---------------------------------------------------------------------------------------------
func test_determinism() -> void:
	var items := ["precision", "transe", "soif_de_sang"]
	var shuffled := ["soif_de_sang", "precision", "transe"]
	var c1 := AutochessEffects.context(fctx({"rempart": 3}, ["peau_dure", "chef_de_guerre"]), [[mk("warrior", [3, 1], items)], bags()])
	var c2 := AutochessEffects.context(fctx({"rempart": 3}, ["chef_de_guerre", "peau_dure"]), [[mk("warrior", [3, 1], shuffled)], bags()])
	check("fiche identique quel que soit l'ordre des objets et des atouts", c1.units[0].sheet == c2.units[0].sheet)
	var team_a := [mk("warrior", [3, 1], ["precision", "plaies"]), mk("hunter", [2, 3], ["tir_multiple"], {"crit": 0.3}),
		mk("cleric", [4, 3], [], {"heals": true})]
	var team_b := [mk("templar", [3, 0], ["pas_du_vent"], {"dodge": 0.2}), mk("magician", [2, 2], ["braise"])]
	var fc := fctx({"tir": 2, "ferveur": 3}, ["riposte", "ralliement"], 99)
	fc.traits[1] = {"escrime": 2, "elementaire": 2}
	var r1 := sim(team_a.duplicate(true), team_b.duplicate(true), fc, 20.0)
	var r2 := sim(team_a.duplicate(true), team_b.duplicate(true), fc, 20.0)
	check("même combat, même graine : même déroulé (%d effets)" % r1.log.size(), _log_sig(r1) == _log_sig(r2) and r1.log.size() > 50)
	var fc3 := fc.duplicate(true)
	fc3["seed"] = 100
	var r3 := sim(team_a.duplicate(true), team_b.duplicate(true), fc3, 20.0)
	check("autre graine : autre déroulé (le hasard passe bien par la graine)", _log_sig(r3) != _log_sig(r1))


func _log_sig(ctx: Dictionary) -> String:
	var parts: PackedStringArray = []
	for e in ctx.log:
		parts.append("%s:%s:%s:%.3f" % [e.type, e.get("src", ""), e.get("dst", ""), float(e.get("amount", 0.0))])
	return "|".join(parts)


# --- 9. format du résultat (combat injecté d'AC-B) ----------------------------------------------------------------------
func test_result_format() -> void:
	var ctx := sim([mk("warrior", [3, 1], ["fortune"], {"atk": 300.0})], bags({"hp": 100.0}), fctx(), 20.0)
	var r := AutochessEffects.result(ctx)
	check("résultat : vainqueur, étoiles debout, durée, or (%s)" % str(r), int(r.winner) == 0 and (r.stars[0] as Array) == [1]
		and (r.stars[1] as Array).is_empty() and float(r.duration) > 0.0 and int(r.gold[0]) == 2)
	# Le combat de données branché sur une vraie partie d'AC-B tourne sans erreur
	var g := Autochess.new()
	g.save_path = ""
	g.start(5, [Autochess.RandomStrategist.new(), Autochess.RandomStrategist.new(), Autochess.RandomStrategist.new(),
		Autochess.RandomStrategist.new(), Autochess.RandomStrategist.new(), Autochess.RandomStrategist.new(),
		Autochess.RandomStrategist.new(), Autochess.RandomStrategist.new()], _data_fight)
	g.play_to_end()
	check("une partie entière d'AC-B jouée avec cette couche d'effets (fin : %s, %d manches)" % [g.phase, g.rounds_played],
		g.is_over() and g.pool_ok())


func _data_fight(a: Array, b: Array, c: Dictionary) -> Dictionary:
	var ctx := AutochessEffects.context(c, [a, b])
	AutochessEffects.start(ctx)
	var timers := {}
	var ids: Array = (ctx.units as Dictionary).keys()
	for _i in 300:
		AutochessEffects.tick(ctx, 0.1)
		if AutochessEffects.living(ctx, 0).is_empty() or AutochessEffects.living(ctx, 1).is_empty():
			break
		for fid in ids:
			var u: Dictionary = ctx.units[fid]
			if not u.alive or AutochessEffects.disabled(ctx, fid):
				continue
			var foes := AutochessEffects.near(ctx, int(u.side), u.pos)
			if foes.is_empty():
				break
			if AutochessEffects.can_cast(ctx, fid):
				AutochessEffects.cast(ctx, fid)
				AutochessEffects.spell_hit(ctx, fid, foes[0])
				continue
			if AutochessEffects.dist(ctx, fid, foes[0]) > AutochessEffects.stat(ctx, fid, "reach"):
				var p: Vector2 = u.pos
				AutochessEffects.set_pos(ctx, fid, p.move_toward(ctx.units[foes[0]].pos, 0.3))
				continue
			timers[fid] = float(timers.get(fid, 0.0)) + 0.1 * AutochessEffects.stat(ctx, fid, "as")
			if float(timers[fid]) >= 1.0:
				timers[fid] = float(timers[fid]) - 1.0
				AutochessEffects.attack(ctx, fid, foes[0])
	return AutochessEffects.result(ctx)
