extends Node
## Profils types « opti » (data/build_profiles.json) pour le duel :
##   godot --headless --path game res://tools/gen_profiles.tscn
## Pour chaque classe de base (STYLES) et chaque niveau de LEVELS : équipement d'Eden du type
## d'armure du style, tout en légendaire +10, choisi avec ses bonus de set ; paliers, 2 gemmes
## royales et enchantement au plus haut niveau permis par la pièce, choisis un par un ;
## 7 certificats (et leur place sur le plateau) ; maîtrise entière.
## Les classes éveillées reprennent exactement le build de leur classe de base (mêmes pièces,
## certificats…) : seuls leurs sorts (ceux de la classe) et leur arbre de maîtrise changent, et
## l'arme si elles n'utilisent pas le même type d'arme (Protecteur, Paladin).
## Les profils du joueur sont gardés ; ceux générés avant (« auto » : "opti") sont remplacés.
##
## Chaque choix maximise la note du style (_value) : somme de logarithmes, donc un poids 1
## veut dire « chaque % gagné compte pleinement ». p : dégâts physiques, m : dégâts magiques,
## t : survie (PV × défense, esquive, parade, vol de vie), h : soins (puissance de soin,
## recharge), theme : attributs mis en avant en plus de ce qu'ils apportent, trophies : familles
## de trophée préférées (dans l'ordre). Règles du duel comprises (PvpCaps : plafonds, défense
## entre héros, esquive 20 %…).

const LEVELS := [90, 85, 75, 65, 55, 45, 35, 25]  # du plus haut : certificats choisis au niveau 90
const SLOTS := ["weapon", "head", "chest", "legs", "gloves", "boots", "back", "necklace", "ring", "trophy"]
const ARMOR_SLOTS := ["head", "chest", "legs", "gloves", "boots"]
const RARITY := 5  # légendaire
const GEM_TIER := 4  # royale
const TAG := "opti"
const KEEP := 40  # pièces gardées par emplacement (meilleures seules), en plus des pièces de set

const STYLES := {
	# armures lourdes
	"warrior": {"armor": "plates", "p": 1.0, "t": 0.25, "theme": {"str": 0.1},
		"trophies": ["might", "berserk", "str", "double", "crit", "quake"]},
	"knight": {"armor": "plates", "p": 0.7, "t": 0.45, "v": 0.05, "theme": {"agi": 0.6},
		"trophies": ["dodge_crit", "wind_dance", "evade", "dodge_wave", "shadow_blades", "agi"]},
	"dragon_knight": {"armor": "plates", "p": 0.8, "m": 0.1, "t": 0.65, "theme": {"str": 0.05},
		"trophies": ["quake", "might", "berserk", "guard", "thorns", "str"]},
	"templar": {"armor": "plates", "p": 0.3, "t": 1.0, "h": 0.4, "theme": {"wis": 0.15, "lck": 0.1},
		"trophies": ["guard", "last_stand", "thorns", "resolve", "crit_heal", "quake"]},
	"samurai": {"armor": "plates", "p": 1.0, "t": 0.25, "theme": {"str": 0.05, "lck": 0.05},
		"trophies": ["crit", "crit_chain", "double", "might", "str"]},
	"sage": {"armor": "plates", "p": 0.4, "m": 0.15, "t": 0.8, "h": 0.8, "theme": {"wis": 0.15},
		"trophies": ["guard", "last_stand", "int_wis", "mana_surge", "crit_heal"]},
	# armures légères (cuir)
	"thief": {"armor": "cuir", "p": 1.0, "t": 0.2, "v": 0.05, "theme": {"agi": 0.15},
		"trophies": ["crit", "dodge_crit", "double", "speed", "agi"]},
	"blade_dancer": {"armor": "cuir", "p": 1.0, "t": 0.25, "v": 0.05, "theme": {"agi": 0.1},
		"trophies": ["speed", "wind_dance", "double", "agi", "crit"]},
	"martial_artist": {"armor": "cuir", "p": 1.0, "t": 0.3, "theme": {"str": 0.1},
		"trophies": ["double", "might", "speed", "str", "crit"]},
	"hunter": {"armor": "cuir", "p": 1.0, "t": 0.15, "v": 0.05, "theme": {"agi": 0.1, "lck": 0.1},
		"trophies": ["crit", "crit_chain", "speed", "agi", "double"]},
	"ranger": {"armor": "cuir", "p": 1.0, "t": 0.15, "v": 0.05, "theme": {"agi": 0.1, "lck": 0.1},
		"trophies": ["crit", "crit_chain", "double", "speed", "agi"]},
	"engineer": {"armor": "cuir", "p": 1.0, "m": 0.2, "t": 0.15, "theme": {"lck": 0.15, "agi": 0.05},
		"trophies": ["crit_chain", "crit", "storm", "speed", "double"]},
	"inquisitor": {"armor": "cuir", "p": 1.0, "t": 0.2, "theme": {"lck": 0.15, "agi": 0.05},
		"trophies": ["crit", "crit_chain", "double", "speed", "agi"]},
	"bard": {"armor": "cuir", "p": 0.25, "m": 0.35, "t": 0.4, "h": 0.8, "theme": {"wis": 0.15, "agi": 0.05},
		"trophies": ["mana_surge", "int_wis", "arcane_echo", "speed", "last_stand"]},
	"luminary": {"armor": "cuir", "m": 1.0, "t": 0.3, "theme": {"int": 0.1, "agi": 0.05},
		"trophies": ["arcane_echo", "crit", "mana_surge", "agi_int", "storm"]},
	# tissu
	"cleric": {"armor": "tissu", "m": 0.4, "t": 0.5, "h": 1.0, "theme": {"wis": 0.2},
		"trophies": ["mana_surge", "arcane_echo", "int_wis", "last_stand", "resolve"]},
	"shaman": {"armor": "tissu", "m": 0.5, "t": 0.4, "h": 0.9, "theme": {"wis": 0.15, "int": 0.05},
		"trophies": ["mana_surge", "int_wis", "arcane_echo", "last_stand", "crit_heal"]},
	"magician": {"armor": "tissu", "m": 1.0, "t": 0.15, "theme": {"int": 0.1},
		"trophies": ["arcane_echo", "mana_surge", "int_wis", "storm", "crit"]},
	"illusionist": {"armor": "tissu", "m": 0.7, "p": 0.35, "t": 0.2, "theme": {"int": 0.1, "lck": 0.05},
		"trophies": ["arcane_echo", "mana_surge", "agi_int", "crit", "int_wis"]},
	"warlock": {"armor": "tissu", "m": 1.0, "t": 0.2, "theme": {"int": 0.1},
		"trophies": ["arcane_echo", "mana_surge", "int_wis", "storm", "crit"]},
}

var _lv := 90
var _style: Dictionary = {}
var _base: Dictionary = {}  # bonus de base de la classe (hp, atk, matk, def…)
var _ab: Dictionary = {}  # attributs de départ
var _ag: Dictionary = {}  # croissance des attributs par niveau
var _set_tiers := {}  # set -> [[pièces, stats, nb de procs]]
var _cand_cache := {}  # "emplacement|armure|arme|niveau" -> pièces possibles
var _cert_cache := {}


func _ready() -> void:
	var t0 := Time.get_ticks_msec()
	var only := OS.get_cmdline_user_args()  # essai : -- <classe de base> (rien n'est enregistré)
	var by_base := {}  # classe de base -> {niveau: profil}
	for cid in STYLES:
		if not only.is_empty() and not cid in only:
			continue
		by_base[cid] = _class_builds(String(cid))
		print("%s : %d profils (%d s)" % [cid, by_base[cid].size(), (Time.get_ticks_msec() - t0) / 1000])
	var made: Array = []
	for cid in by_base:
		for lv in _ascending():
			made.append(by_base[cid][lv])
		for aid in GameData.classes:
			var c: Dictionary = GameData.classes[aid]
			if String(aid) == String(cid) or String(c.get("parent", "")) != String(cid):
				continue
			for lv in _ascending():
				made.append(_awakened(String(aid), by_base[cid][lv]))
	if only.is_empty():
		_save(made)
	else:
		for b in made:
			_report(b)
	print("%d profils générés en %d s" % [made.size(), (Time.get_ticks_msec() - t0) / 1000])
	get_tree().quit()


func _ascending() -> Array:
	var l := LEVELS.duplicate()
	l.sort()
	return l


func _save(made: Array) -> void:
	var path := RivalBuilds.PATH
	var keep: Array = []
	if FileAccess.file_exists(path):
		var d = JSON.parse_string(FileAccess.get_file_as_string(path))
		if d is Array:
			keep = d.filter(func(b): return b is Dictionary and String(b.get("auto", "")) != TAG)
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(keep + made, "\t"))
	f.close()
	print("%s : %d profils du joueur gardés, %d générés" % [path, keep.size(), made.size()])


# --- une classe de base -----------------------------------------------------------------------
func _class_builds(cid: String) -> Dictionary:
	var out := {}
	var certs: Array = []
	for lv in LEVELS:
		var b := _build(cid, int(lv), certs)
		certs = b.certs
		out[int(lv)] = b
	return out


func _setup(cid: String, lv: int) -> void:
	var cls := GameData.class_data(cid)
	var parent := cid if STYLES.has(cid) else String(cls.get("parent", cid))
	_style = STYLES.get(parent, STYLES.warrior)
	_base = cls.get("base", {})
	_ab = cls.get("attributes", {}).get("base", {})
	_ag = cls.get("attributes", {}).get("growth", {})
	_lv = lv
	Run.active = true
	Run.hero_level = lv  # puissance des objets au niveau du profil (comme RivalBuilds.stats)


func _build(cid: String, lv: int, certs: Array) -> Dictionary:
	_setup(cid, lv)
	var talents := _max_talents(cid)
	var t0 := _talent_stats(cid, talents)
	var fixed := _add(t0, _certs_total(certs))
	var lo := _choose_gear(cid, fixed)
	var gear_t := _gear_total(lo)
	if certs.is_empty():
		certs = _choose_certs(_add(t0, gear_t[0]))
		fixed = _add(t0, _certs_total(certs))
	var gear := _extras(lo, _add(fixed, gear_t[0]))
	var name := "%s niv. %d · %s" % [GameData.class_data(cid).get("name_fr", cid), lv, TAG]
	return {"name": name, "class": cid, "level": lv, "gear": gear, "look": {}, "certs": certs, "talents": talents,
		"spells": Duel.grid12([]), "hp_mult": 1.0, "atk_mult": 1.0, "auto": TAG}


## Classe éveillée : le build de sa classe de base, ses sorts et sa maîtrise (et son arme si
## son type d'arme n'est pas le même).
func _awakened(aid: String, base: Dictionary) -> Dictionary:
	var b := base.duplicate(true)
	var lv := int(b.level)
	b["class"] = aid
	b["name"] = "%s niv. %d · %s" % [GameData.class_data(aid).get("name_fr", aid), lv, TAG]
	b["talents"] = _max_talents(aid)
	b["spells"] = Duel.grid12([])
	var old: Dictionary = b.gear.get("weapon", {})
	var wt := Items.default_weapon_type(aid)
	if not old.is_empty() and String(GameData.eden_by_id.get(int(old.id), {}).get("wtype", "")) != wt:
		_setup(aid, lv)
		var best := -INF
		var pick: Dictionary = {}
		for c in _candidates(aid, "weapon"):
			var g := old.duplicate(true)
			g["id"] = int(c.e.id)
			var en := String(old.get("enchant", "")).split(":")
			var slv := _enchant_level(c.e)
			g["enchant"] = Craft.scroll_key(en[1], slv) if en.size() >= 3 and slv > 0 else ""
			b.gear["weapon"] = g
			var v := _value(RivalBuilds.stats(b, lv)) + float(c.bonus)
			if v > best:
				best = v
				pick = g
		b.gear["weapon"] = pick
	return b


# --- maîtrise et certificats ------------------------------------------------------------------
func _max_talents(cid: String) -> Dictionary:
	var out := {}
	for row in GameData.talents.get(cid, {}).get("rows", []):
		for c in row:
			if c != null:
				out[str(int(c.id))] = int(c.max)
	return out


func _talent_stats(cid: String, talents: Dictionary) -> Dictionary:
	var out := {}
	var tree: Dictionary = GameData.talents.get(cid, {}).get("talents", {})
	for id in talents:
		var eff: Dictionary = tree.get(str(id), {}).get("effect", {})
		if eff.get("type", "") == "stat":
			out[eff.stat] = float(out.get(eff.stat, 0.0)) + float(eff.per_level) * int(talents[id])
	return out


func _cert_stats(key: String) -> Dictionary:
	if _cert_cache.has(key):
		return _cert_cache[key]
	var out := {}
	var st: Dictionary = Run.certificate_card(key).get("stat", {})
	for k in st:
		if typeof(st[k]) in [TYPE_FLOAT, TYPE_INT]:
			out[k] = float(st[k])
	_cert_cache[key] = out
	return out


## Stats des certificats et de leurs bonus de placement (même plateau que RivalBuilds).
func _certs_total(certs: Array) -> Dictionary:
	var out := {}
	for k in certs:
		out = _add(out, _cert_stats(String(k)))
	return _add(out, CertBoard.stats(RivalBuilds.cert_board({"certs": certs})))


## 7 certificats (un même passif d'Eden une seule fois), puis leur ordre sur le plateau.
func _choose_certs(t: Dictionary) -> Array:
	var pool: Array = []
	var seen := {}
	for c in RivalBuilds.all_certificates():
		var key := String(c.key)
		var card := Run.certificate_card(key)
		var uid := str(card.get("eden", key.get_slice("/", 1).trim_prefix("c")))
		if not seen.has(uid) and not _cert_stats(key).is_empty():
			seen[uid] = true
			pool.append(key)
	var picked: Array = []
	var cur := t.duplicate()
	while picked.size() < RivalBuilds.MAX_CERTS and not pool.is_empty():
		var best := ""
		var bv := -INF
		for key in pool:
			var v := _value(_add(cur, _cert_stats(key)))
			if v > bv:
				bv = v
				best = key
		picked.append(best)
		pool.erase(best)
		cur = _add(cur, _cert_stats(best))
	# ordre : meilleurs bonus de placement (toutes les permutations)
	var best_order := picked.duplicate()
	var bv := _value(_add(t, _certs_total(picked)))
	for perm in _permutations(picked):
		var v := _value(_add(t, _certs_total(perm)))
		if v > bv + 1e-9:
			bv = v
			best_order = perm
	return best_order


func _permutations(a: Array) -> Array:
	if a.size() <= 1:
		return [a.duplicate()]
	var out: Array = []
	for i in a.size():
		var rest := a.duplicate()
		var x = rest.pop_at(i)
		for p in _permutations(rest):
			out.append([x] + p)
	return out


# --- équipement -------------------------------------------------------------------------------
## Pièces possibles d'un emplacement : {e, st (stats de la pièce légendaire +10 sans gemmes ni
## enchantement), set, bonus (procs, famille de trophée préférée)}.
func _candidates(cid: String, slot: String) -> Array:
	var wt := Items.default_weapon_type(cid)
	var key := "%s|%s|%s|%d" % [slot, _style.armor if slot in ARMOR_SLOTS else "", wt if slot == "weapon" else "", _lv]
	if not _cand_cache.has(key):
		var out: Array = []
		var lowest: Dictionary = {}
		for e: Dictionary in GameData.eden_items:
			if String(e.get("slot", "")) != slot or not Trophies.in_pool(e):
				continue
			if slot == "weapon" and String(e.get("wtype", "")) != wt:
				continue
			if slot in ARMOR_SLOTS and String(e.get("armor", "")) != String(_style.armor):
				continue
			var lv := int(e.get("level", 0))
			if lv > _lv:
				if lowest.is_empty() or lv < int(lowest.level):
					lowest = e
				continue
			if lv <= 0 and slot != "trophy":
				continue
			out.append(_cand(slot, e))
		if out.is_empty() and not lowest.is_empty():
			out.append(_cand(slot, lowest))  # pas d'arme de ce type à ce niveau : la plus basse
		_cand_cache[key] = out
	var list: Array = _cand_cache[key]
	for c in list:
		if slot == "trophy":
			var i: int = (_style.trophies as Array).find(String(c.kind))
			c["bonus"] = (0.06 - 0.01 * i if i >= 0 else 0.0) + 0.0001 * int(c.e.get("level", 0))
		else:
			c["bonus"] = 0.015 * int(c.procs)
	return list


func _cand(slot: String, e: Dictionary) -> Dictionary:
	var it := RivalBuilds.make_item(slot, {"id": int(e.id), "rarity": RARITY, "upgrade": Items.MAX_UPGRADE}, _lv)
	var pv: Dictionary = it.get("passive", {})
	return {"e": e, "slot": slot, "st": Items.stats(it, false), "set": String(it.get("set", "")),
		"kind": String(pv.get("trophy", e.get("trophy", ""))), "procs": (pv.get("procs", []) as Array).size(), "bonus": 0.0}


func _tiers(sid: String) -> Array:
	if not _set_tiers.has(sid):
		var l: Array = []
		for n in Items.set_tiers(sid):
			var b := Items.set_bonus(sid, n)
			l.append([int(n), b.get("stat", {}), (b.get("procs", []) as Array).size()])
		_set_tiers[sid] = l
	return _set_tiers[sid]


## Stats de l'équipement [param lo] (emplacement -> pièce) avec ses bonus de set, et ses bonus.
func _gear_total(lo: Dictionary) -> Array:
	var tot := {}
	var counts := {}
	var bonus := 0.0
	for slot in lo:
		var c: Dictionary = lo[slot]
		for k in c.st:
			tot[k] = float(tot.get(k, 0.0)) + float(c.st[k])
		bonus += float(c.bonus)
		if c.set != "":
			counts[c.set] = int(counts.get(c.set, 0)) + 1
	for sid in counts:
		for tier in _tiers(sid):
			if int(counts[sid]) >= int(tier[0]):
				for k in tier[1]:
					tot[k] = float(tot.get(k, 0.0)) + float(tier[1][k])
				bonus += 0.02 * int(tier[2])
	return [tot, bonus]


func _score(lo: Dictionary, fixed: Dictionary) -> float:
	var g := _gear_total(lo)
	return _value(_add(fixed, g[0])) + float(g[1])


## Meilleur équipement : pièce par pièce, puis sets entiers, jusqu'à ne plus rien gagner.
func _choose_gear(cid: String, fixed: Dictionary) -> Dictionary:
	var cands := {}
	for slot in SLOTS:
		var all := _candidates(cid, slot)
		for c in all:
			c["solo"] = _score({slot: c}, fixed)
		all.sort_custom(func(a, b): return float(a.solo) > float(b.solo))
		var kept: Array = all.slice(0, KEEP)
		for c in all.slice(KEEP):
			if c.set != "":
				kept.append(c)
		cands[slot] = kept
	var lo := {}
	for slot in SLOTS:
		if not cands[slot].is_empty():
			lo[slot] = cands[slot][0]
	var cur := _score(lo, fixed)
	var sets := {}
	for slot in SLOTS:
		for c in cands[slot]:
			if c.set != "":
				sets[c.set] = true
	for _round in 10:
		var improved := false
		for slot in lo:
			var keep: Dictionary = lo[slot]
			for c in cands[slot]:
				lo[slot] = c
				var s := _score(lo, fixed)
				if s > cur + 1e-9:
					cur = s
					keep = c
					improved = true
			lo[slot] = keep
		for sid in sets:
			var trial := lo.duplicate()
			for slot in lo:
				var best: Dictionary = {}
				for c in cands[slot]:
					if c.set == sid and (best.is_empty() or float(c.solo) > float(best.solo)):
						best = c
				if not best.is_empty():
					trial[slot] = best
			var s := _score(trial, fixed)
			if s > cur + 1e-9:
				cur = s
				lo = trial
				improved = true
		if not improved:
			break
	return lo


func _enchant_level(e: Dictionary) -> int:
	var it := RivalBuilds.make_item(String(e.slot), {"id": int(e.id), "rarity": RARITY}, _lv)
	return Craft.scroll_level_for(maxi(int(e.get("level", 0)), mini(Items.power_cap(it), 999)))


## Paliers, gemmes et enchantement de chaque pièce, choisis un par un (plafonds compris).
func _extras(lo: Dictionary, tot: Dictionary) -> Dictionary:
	var out := {}
	tot = tot.duplicate()
	for slot in SLOTS:
		if not lo.has(slot):
			continue
		var e: Dictionary = lo[slot].e
		var it := RivalBuilds.make_item(slot, {"id": int(e.id), "rarity": RARITY, "upgrade": Items.MAX_UPGRADE}, _lv)
		var lk := pow(1.08, Items.power_level(it) - 1)
		var rolls := {}
		for m in Items.MILESTONES:
			var opts := {}
			for s in RivalBuilds.roll_pool(slot):
				var rr: Array = Craft.UPGRADE_ROLL.get(s, [1.0, 3.0])
				opts[s] = {s: float(rr[1]) * 2.0 * (1.0 if s in Items.PERCENT_STATS else lk)}
			var pick := _best(tot, opts)
			rolls[str(m)] = pick
			tot = _add(tot, opts[pick])
		var gems: Array = []
		for i in Craft.MAX_SOCKETS:
			var opts := {}
			for gt in Craft.GEMS:
				opts[Craft.gem_key(gt, GEM_TIER)] = Craft.gem_stats({"type": gt, "tier": GEM_TIER})
			var pick := _best(tot, opts)
			gems.append(pick)
			tot = _add(tot, opts[pick])
		var enchant := ""
		var slv := _enchant_level(e)
		if slv > 0:
			var opts := {}
			for t in Craft.ENCHANTS:
				opts[Craft.scroll_key(t, slv)] = Craft.enchant_stats({"type": t, "lv": slv})
			enchant = _best(tot, opts)
			tot = _add(tot, opts[enchant])
		out[slot] = {"id": int(e.id), "rarity": RARITY, "upgrade": Items.MAX_UPGRADE, "rolls": rolls, "gems": gems, "enchant": enchant}
	return out


func _best(tot: Dictionary, opts: Dictionary) -> String:
	var best := ""
	var bv := -INF
	for k in opts:
		var v := _value(_add(tot, opts[k]))
		if v > bv:
			bv = v
			best = String(k)
	return best


# --- note d'un build --------------------------------------------------------------------------
static func _add(a: Dictionary, b: Dictionary) -> Dictionary:
	var out := a.duplicate()
	for k in b:
		out[k] = float(out.get(k, 0.0)) + float(b[k])
	return out


## Note du style pour les stats ajoutées [param t] (équipement, sets, certificats, maîtrise),
## d'après les formules du héros (Player.recalc_stats) et les plafonds du duel.
func _value(t: Dictionary) -> float:
	var lv := _lv
	var a := {}
	for k in Items.ATTRIBUTES:
		a[k] = maxf(1.0, (float(_ab.get(k, 6.0)) + float(_ag.get(k, 1.0)) * (lv - 1) + float(t.get(k, 0.0))) * (1.0 + float(t.get(k + "_pct", 0.0))))
	var atk_pct := float(t.get("atk_pct", 0.0))
	var atk: float = (GameData.player_atk(lv) * float(_base.get("atk", 1.0)) + float(t.get("patk", 0.0)) + a.str * 0.6) * (1.0 + atk_pct)
	var matk: float = (GameData.player_atk(lv) * float(_base.get("matk", 0.5)) + float(t.get("matk", 0.0)) + a.int * 0.6) * (1.0 + atk_pct + float(t.get("matk_pct", 0.0)))
	var hp: float = (GameData.player_max_hp(lv) * float(_base.get("hp", 1.0)) + a.str * 2.0 + a.wis * 1.5) * (1.0 + float(t.get("hp_pct", 0.0))) + float(t.get("hp", 0.0))
	var def: float = (4.0 + lv * 2.0 + float(t.get("def", 0.0)) + float(_base.get("def", 0.0)) + a.str * 0.25) * (1.0 + float(t.get("def_pct", 0.0)))
	var crit: float = minf(0.05 + float(_base.get("crit", 0.0)) + float(t.get("crit", 0.0)) + a.lck * 0.0012 + a.agi * 0.0004, PvpCaps.CAPS.crit)
	var mcrit: float = minf(0.05 + float(t.get("mcrit", 0.0)) + a.lck * 0.0012 + a.wis * 0.0004, PvpCaps.CAPS.mcrit)
	var crit_dmg: float = minf(0.5 + float(t.get("crit_dmg", 0.0)) + a.lck * 0.0015, PvpCaps.CAPS.crit_dmg)
	var aspd: float = minf(1.0 + float(_base.get("atk_speed", 0.0)) + a.agi * 0.0015 + float(t.get("atk_speed", 0.0)), PvpCaps.CAPS.atk_speed)
	var cast: float = minf(1.0 + a.agi * 0.001 + a.wis * 0.0005 + float(t.get("cast_speed", 0.0)), PvpCaps.CAPS.cast_speed)
	var eva: float = clampf(a.agi * 0.0006 + float(t.get("eva", 0.0)), 0.0, 0.2)
	var parry: float = clampf(a.str * 0.0004 + float(t.get("parry", 0.0)), 0.0, 0.2)
	var heal: float = minf(1.0 + a.wis * 0.004 + float(t.get("heal_pct", 0.0)), PvpCaps.CAPS.heal_power)
	var cdr: float = clampf(float(t.get("cdr", 0.0)), 0.0, PvpCaps.CAPS.cdr)
	var dmg: float = minf(maxf(0.1, 1.0 + float(t.get("dmg_pct", 0.0))), PvpCaps.CAPS.dmg_mult)
	var ls: float = minf(float(t.get("lifesteal", 0.0)), PvpCaps.CAPS.lifesteal)
	var move: float = minf(1.0 + float(_base.get("move_speed", 0.0)) + float(t.get("move_speed", 0.0)), PvpCaps.CAPS.move_mult)
	var v := 0.0
	v += float(_style.get("p", 0.0)) * log(maxf(atk, 1.0) * (1.0 + crit * crit_dmg) * aspd * dmg / (1.0 - 0.5 * cdr))
	v += float(_style.get("m", 0.0)) * log(maxf(matk, 1.0) * (1.0 + mcrit * crit_dmg) * cast * dmg / (1.0 - 0.7 * cdr))
	# défense en duel (PvpCaps.taken) face à un adversaire de défense moyenne pour le niveau
	var taken := PvpCaps.taken(def, 100.0 * pow(1.095, maxi(lv - 10, 0)))
	v += float(_style.get("t", 0.0)) * log(maxf(hp, 1.0) / taken / (1.0 - eva) / (1.0 - 0.5 * parry) * (1.0 + 2.0 * ls))
	v += float(_style.get("h", 0.0)) * log(heal / (1.0 - cdr))
	v += float(_style.get("v", 0.0)) * log(move)
	var theme: Dictionary = _style.get("theme", {})
	for k in theme:
		v += float(theme[k]) * log(float(a[k]))
	return v


## Essai (-- <classe>) : pièces, extras, certificats et stats principales du profil.
func _report(b: Dictionary) -> void:
	var lv := int(b.level)
	_setup(String(b["class"]), lv)
	print("
== %s" % b.name)
	for slot in SLOTS:
		var g: Dictionary = b.gear.get(slot, {})
		if g.is_empty():
			print("  %-9s —" % slot)
			continue
		var e: Dictionary = GameData.eden_by_id.get(int(g.id), {})
		print("  %-9s %s (niv. %d%s%s) %s %s %s" % [slot, e.name, int(e.level), " " + String(e.get("armor", e.get("wtype", ""))),
			" set " + String(e.get("set", "")) if e.has("set") else "", (g.rolls as Dictionary).values(), g.gems, g.enchant])
	print("  certificats : ", b.certs)
	var st := RivalBuilds.stats(b, lv)
	var keys: PackedStringArray = []
	for k in ["patk", "matk", "str", "agi", "int", "wis", "lck", "hp", "def", "crit", "mcrit", "crit_dmg", "eva", "parry", "atk_speed", "cdr", "dmg_pct", "atk_pct", "hp_pct", "def_pct", "heal_pct", "lifesteal"]:
		if st.has(k):
			keys.append("%s %s" % [k, str(snappedf(float(st[k]), 0.001))])
	print("  stats : ", ", ".join(keys))
	print("  note : %.3f" % _value(st))
