class_name SurvivorCodex
extends RefCounted
## Codex du Survivant (lot SVX-3, BM-SURV SV-M1 et SV-Q5) : la collection propre au mode, sans aucun lien avec le compte.
##   - Évolutions (20 recettes, SurvivorEvo) : prise au moins une fois, ou seulement rencontrée (recette visible), sinon « ? » ;
##   - Armes : les 17 types × leurs variantes d'auto-attaque (WeaponAttacks.variants), portées au moins une fois ;
##   - Panoplies : les 13 du mode, complétées (5 / 5) ou portées (2 pièces et plus) ;
##   - Monstres : ceux des 8 zones du mode, vus pendant une partie (à l'écran ou tués) ;
##   - Statistiques : parties, victoires, temps de jeu, monstres vaincus, armes les plus portées, évolution préférée.
## Tout vit dans Profile.records["sv_rewards"] (clé du mode, déjà hors de la progression du compte : SurvivorRewards.hub_view) :
## « codex » et « stats ». Pendant la partie, ce qui est vu est gardé à part ([member run]) et versé à la fin par
## [method settle] (appelé par SurvivorRewards.settle, après la remise du hub : une fermeture du jeu en pleine partie ne garde
## rien, comme le reste du mode).

const LISTS := ["evo", "evo_seen", "weapons", "sets", "sets_seen", "monsters", "bosses"]
const SEEN_EVERY := 1.0  # s entre deux relevés des monstres à l'écran

## Partie en cours : {evo, weapons, monsters (id -> vrai), bosses}.
static var run := {}
## Nouveautés de la dernière partie (bilan) : [{kind, text}].
static var last_new: Array = []
static var _seen_t := 0.0


static func reset_run() -> void:
	run = {"evo": [], "weapons": [], "monsters": {}, "bosses": []}
	last_new = []
	_seen_t = 0.0


# --- état gardé -----------------------------------------------------------------------------------------------------------
## Codex gardé (copie) : {evo: [], evo_seen: [], weapons: ["katana:0"], sets: [], sets_seen: [], monsters: [ids], bosses: []}.
static func state() -> Dictionary:
	var s: Variant = Profile.records.get(SurvivorRewards.KEY, {})
	var c: Variant = (s as Dictionary).get("codex", {}) if s is Dictionary else {}
	var out: Dictionary = (c as Dictionary).duplicate(true) if c is Dictionary else {}
	for k in LISTS:
		if not out.has(k) or not out[k] is Array:
			out[k] = []
	return out


## Statistiques du mode (copie) : {games, wins, time, kills, weapons: {type: n}, evos: {id: n}, classes: {id: n}}.
static func stats() -> Dictionary:
	var s: Variant = Profile.records.get(SurvivorRewards.KEY, {})
	var t: Variant = (s as Dictionary).get("stats", {}) if s is Dictionary else {}
	var out: Dictionary = (t as Dictionary).duplicate(true) if t is Dictionary else {}
	for k in ["games", "wins", "time", "kills"]:
		out[k] = out.get(k, 0)
	for k in ["weapons", "evos", "classes"]:
		if not out.get(k) is Dictionary:
			out[k] = {}
	return out


# --- ce que la partie voit ------------------------------------------------------------------------------------------------
static func _ensure() -> void:
	if run.is_empty():
		reset_run()


static func note_evolution(id: String) -> void:
	_ensure()
	if not id in run.evo:
		(run.evo as Array).append(id)


## Arme prise (carte « Arme », coffre d'arme) : « type:variante ».
static func note_weapon(item: Dictionary) -> void:
	_ensure()
	if item.is_empty():
		return
	var wt := Items.weapon_type_of(item)
	var key := "%s:%d" % [wt, WeaponAttacks.variant_index(item, WeaponAttacks.variants(wt).size())]
	if not key in run.weapons:
		(run.weapons as Array).append(key)


## Monstres à l'écran (relevé une fois par seconde par le HUD du Survivant) : ceux des rosters du mode.
static func observe(tree: SceneTree, delta: float) -> void:
	_ensure()
	_seen_t -= delta
	if _seen_t > 0.0 or tree == null:
		return
	_seen_t = SEEN_EVERY
	var cam := tree.root.get_viewport().get_camera_3d()
	var rect := tree.root.get_viewport().get_visible_rect()
	for n in tree.get_nodes_in_group("monsters"):
		var m := n as Monster
		if m == null or m.data.is_empty():
			continue
		var id := int(m.data.get("id", 0))
		if id == 0 or run.monsters.has(id):
			continue
		if cam != null and not cam.is_position_behind(m.global_position) and rect.has_point(cam.unproject_position(m.global_position)):
			run.monsters[id] = true
		if m.is_boss:
			if not id in run.bosses:
				(run.bosses as Array).append(id)


## Monstres de tous les rosters du mode (zones du Survivant : monstres et élites, boss compris).
static func roster() -> Array:
	var out: Array = []
	for z in Survivor.zones():
		var zd := GameData.zone(String(z))
		for id in zd.get("monsters", []) + zd.get("elites", []):
			if not int(id) in out and not GameData.monster(int(id)).is_empty():
				out.append(int(id))
		var b := int(zd.get("dungeon", {}).get("boss", 0))
		if b != 0 and not b in out and not GameData.monster(b).is_empty():
			out.append(b)
	return out


## Toutes les armes du Codex : [{key « type:i », wtype, i, name (variante), type_name}].
static func weapon_entries() -> Array:
	var out: Array = []
	for wt in SurvivorPool.weapon_types():
		var vs := WeaponAttacks.variants(String(wt))
		for i in vs.size():
			out.append({"key": "%s:%d" % [wt, i], "wtype": String(wt), "i": i, "name": String(vs[i].get("name", "")),
				"type_name": String(GameData.weapon_type(String(wt)).get("name", wt))})
	return out


# --- fin de partie ----------------------------------------------------------------------------------------------------------
## Verse la partie dans le codex et les statistiques de [param st] (l'état « sv_rewards » que SurvivorRewards.settle écrit) ;
## renvoie les nouveautés : [{kind, text}].
static func settle(st: Dictionary, res: String, tier: int) -> Array:
	_ensure()
	var c: Dictionary = st.get("codex", {}) if st.get("codex") is Dictionary else {}
	for k in LISTS:
		if not c.get(k) is Array:
			c[k] = []
	var news: Array = []
	# évolutions prises et rencontrées (recette à moitié remplie)
	for id in run.evo:
		if not id in c.evo:
			(c.evo as Array).append(id)
			news.append({"kind": "evo", "text": "Évolution : %s" % String(Boons.get_def(String(id)).get("name", id))})
	for p in SurvivorEvo.paths():
		if not String(p.id) in c.evo_seen and not String(p.id) in c.evo:
			(c.evo_seen as Array).append(String(p.id))
			news.append({"kind": "evo_seen", "text": "Recette : %s" % String(p.name)})
	# arme de fin de partie (et celles prises en cours de route)
	note_weapon(Profile.equipped.get("weapon", {}))
	for k in run.weapons:
		if not k in c.weapons:
			(c.weapons as Array).append(k)
			var wt := String(k).get_slice(":", 0)
			var vs := WeaponAttacks.variants(wt)
			var i := int(String(k).get_slice(":", 1))
			news.append({"kind": "weapon", "text": "Arme : %s (%s)" % [String(vs[clampi(i, 0, vs.size() - 1)].get("name", wt)), String(GameData.weapon_type(wt).get("name", wt))]})
	# panoplies
	var counts := Items.set_counts(Profile.equipped)
	for sid in counts:
		if not String(sid) in SurvivorPool.sets():
			continue
		if int(counts[sid]) >= 2 and not String(sid) in c.sets_seen:
			(c.sets_seen as Array).append(String(sid))
		if int(counts[sid]) >= 5 and not String(sid) in c.sets:
			(c.sets as Array).append(String(sid))
			news.append({"kind": "set", "text": "Panoplie complète : %s" % SurvivorPool.panoply_name(String(sid))})
	# monstres vus
	var fresh := 0
	for id in run.monsters:
		if not int(id) in c.monsters:
			(c.monsters as Array).append(int(id))
			fresh += 1
	if fresh > 0:
		news.append({"kind": "monster", "text": "%d monstre%s au bestiaire" % [fresh, "s" if fresh > 1 else ""]})
	if res == "victoire":
		var boss := int(GameData.zone(Survivor.zone_id).get("dungeon", {}).get("boss", 0))
		if boss != 0 and not boss in c.bosses:
			(c.bosses as Array).append(boss)
			news.append({"kind": "boss", "text": "Boss vaincu : %s" % String(GameData.monster(boss).get("name", "?"))})
		if boss != 0 and not boss in c.monsters:
			(c.monsters as Array).append(boss)
	st["codex"] = c
	# statistiques
	var t: Dictionary = st.get("stats", {}) if st.get("stats") is Dictionary else {}
	t["games"] = int(t.get("games", 0)) + 1
	t["wins"] = int(t.get("wins", 0)) + (1 if res == "victoire" else 0)
	t["time"] = float(t.get("time", 0.0)) + float(SurvivorRewards.stats.get("time", 0.0))
	t["kills"] = int(t.get("kills", 0)) + Run.kills
	for k in ["weapons", "evos", "classes"]:
		if not t.get(k) is Dictionary:
			t[k] = {}
	var w: Dictionary = Profile.equipped.get("weapon", {})
	if not w.is_empty():
		var wt2 := Items.weapon_type_of(w)
		t.weapons[wt2] = int(t.weapons.get(wt2, 0)) + 1
	for id in SurvivorEvo.taken():
		t.evos[id] = int(t.evos.get(id, 0)) + 1
	t.classes[Run.class_id] = int(t.classes.get(Run.class_id, 0)) + 1
	st["stats"] = t
	last_new = news
	return news


# --- lecture (page du Codex) -----------------------------------------------------------------------------------------------
## Avancement du Codex : {evo: [n, total], weapons: [n, total], sets: [n, total], monsters: [n, total]}.
static func progress() -> Dictionary:
	var c := state()
	var mons := roster()
	return {"evo": [(c.evo as Array).size(), SurvivorEvo.all().size()],
		"weapons": [(c.weapons as Array).size(), weapon_entries().size()],
		"sets": [(c.sets as Array).size(), SurvivorPool.sets().size()],
		"monsters": [(c.monsters as Array).filter(func(id): return int(id) in mons).size(), mons.size()]}


## Clé du dictionnaire [param d] la plus haute (statistiques : arme la plus portée…) ; "" si vide.
static func top_of(d: Dictionary) -> String:
	var best := ""
	var n := 0
	for k in d:
		if int(d[k]) > n:
			n = int(d[k])
			best = String(k)
	return best
