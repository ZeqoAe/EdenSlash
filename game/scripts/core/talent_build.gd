class_name TalentBuild
extends RefCounted
## Build conseillé de talents (lot GX-6) : un ORDRE de 80 points par classe (2 par niveau de maîtrise, 40 niveaux), chaque
## préfixe étant un arbre que l'on peut bâtir point par point (`Profile.talent_set_valid`) : avec N points, le conseil est
## les N premiers points de l'ordre.
##
## Valeur d'un point (sans unité, comparée entre talents d'une même classe) :
## - talent de stat : poids de la stat au profil de la classe (`ClassGear.profile(...).weights`, ★ = `ClassGear.top_stats`)
##   × ce que 1 % de cette stat rapporte vraiment (`EFF` : 1 % de dégâts vaut plus que 1 % de force) × l'effet par niveau ;
##   une classe en plates (rempart, croisé) compte un peu plus la survie (`ARMOR_SURVIVAL`) ;
## - talent de sort : part du sort dans les dégâts de la classe (dégâts / recharge parmi ses `KIT` meilleurs sorts,
##   `SKILL_PART` des dégâts totaux, le reste étant l'auto-attaque), dans les soins (`HEAL_PART`), ou forfait d'un
##   sort de soutien (`BUFF_SHARE`) ; puissance, dégâts, recharge et durée selon leur effet.
## Choix glouton : le point de meilleure valeur parmi ceux que l'on peut placer ; un talent fermé par un prérequis est
## pesé avec les points qu'il demande (moyenne du paquet), ce qui va chercher les sorts renforcés du bout de l'arbre.

const MAX_POINTS := 80
## Ce que 1 % de la stat rapporte (dégâts ou survie), d'après Player.recalc_stats.
const EFF := {
	"dmg_pct": 1.0, "atk_pct": 0.9, "str_pct": 0.45, "agi_pct": 0.45, "int_pct": 0.45, "wis_pct": 0.45, "lck_pct": 0.4,
	"crit": 0.6, "crit_dmg": 0.3, "atk_speed": 0.85, "cast_speed": 0.7, "cdr": 0.9,
	"hp_pct": 0.8, "def_pct": 0.5, "parry": 0.8, "heal_pct": 0.6, "move_speed": 0.3,
}
## Stat d'un talent -> clé du profil de la classe.
const ALIAS := {"str_pct": "str", "agi_pct": "agi", "int_pct": "int", "wis_pct": "wis", "lck_pct": "lck"}
const SURVIVAL := ["hp_pct", "def_pct", "parry", "heal_pct"]
const ARMOR_SURVIVAL := 1.25
const STAR_BONUS := 1.1
const KIT := 6
const SKILL_PART := 0.6
const HEAL_PART := 0.5
const BUFF_SHARE := 0.1
const DURATION_REF := 10.0
## Valeur d'un point qui n'apporte plus rien (effet déjà permanent) : placé seulement s'il ne reste rien d'autre.
const SATURATED := 0.01

static var _orders := {}  # classe -> Array d'ids (ordre conseillé)


## Ordre conseillé des points de [param cls] : MAX_POINTS ids au plus (gardé en mémoire).
static func order(cls: String) -> Array:
	if _orders.has(cls):
		return _orders[cls]
	var cells := _cells(cls)
	var keys: Array = cells.keys()  # ordre de l'arbre (rangée par rangée) : départage stable
	var have := {}
	var spent := 0
	var out: Array = []
	while spent < MAX_POINTS:
		var pick := ""
		var best := -INF
		for k in keys:
			var c: Dictionary = cells[k]
			if int(have.get(k, 0)) >= int(c.max):
				continue
			var first: String = k
			var r := point_value(cls, k, int(have.get(k, 0)))
			var rq := str(int(c.get("req", 0)))
			var need := 0
			if int(c.get("req", 0)) > 0:
				need = maxi(0, int(c.req_pts) - int(have.get(rq, 0)))
			if need > 0:
				var rc: Dictionary = cells.get(rq, {})
				if rc.is_empty() or int(rc.max) < int(c.req_pts) or not _open(rc, have, spent):
					continue
				if spent + need < int(c.get("spent", 0)):
					continue  # le paquet n'ouvrirait pas la colonne : les autres points y mèneront
				first = rq
				r = (need * point_value(cls, rq, int(have.get(rq, 0))) + r) / float(need + 1)
			elif not _open(c, have, spent):
				continue
			if r > best + 1e-9:
				best = r
				pick = first
		if pick == "":
			break
		have[pick] = int(have.get(pick, 0)) + 1
		spent += 1
		out.append(int(pick))
	_orders[cls] = out
	return out


## Le point peut-il aller sur [param c] (colonne ouverte, prérequis tenu) ?
static func _open(c: Dictionary, have: Dictionary, spent: int) -> bool:
	if spent < int(c.get("spent", 0)):
		return false
	return int(c.get("req", 0)) <= 0 or int(have.get(str(int(c.req)), 0)) >= int(c.req_pts)


## Cases de l'arbre de [param cls] : id (String) -> case, dans l'ordre de l'arbre.
static func _cells(cls: String) -> Dictionary:
	var out := {}
	for row in GameData.talents.get(cls, {}).get("rows", []):
		for c in row:
			if c != null:
				out[str(int(c.id))] = c
	return out


## Rangs conseillés avec [param points] points : {id (String): rang}.
static func ranks(cls: String, points: int) -> Dictionary:
	var out := {}
	var o := order(cls)
	for i in mini(maxi(points, 0), o.size()):
		var k := str(int(o[i]))
		out[k] = int(out.get(k, 0)) + 1
	return out


## Valeur d'un point de plus dans le talent [param id] (déjà au rang [param rank]) pour [param cls] (voir l'en-tête).
static func point_value(cls: String, id, rank := 0) -> float:
	var t: Dictionary = GameData.talents.get(cls, {}).get("talents", {}).get(str(int(id)), {})
	var eff: Dictionary = t.get("effect", {})
	var per := float(eff.get("per_level", 0.0))
	match String(eff.get("type", "")):
		"stat":
			return stat_value(cls, String(eff.get("stat", ""))) * per * 100.0
		"skill_dmg":
			return per * 100.0 * _skill_share(cls, int(eff.get("skill", 0)), "dmg") * _w(cls, "dmg_pct")
		"skill_power":
			return per * 100.0 * _skill_share(cls, int(eff.get("skill", 0)), "any") * _w(cls, "dmg_pct")
		"skill_cd":
			return per * 100.0 * _skill_share(cls, int(eff.get("skill", 0)), "any") * _w(cls, "cdr")
		"skill_duration":
			# temps de présence de l'effet : une seconde de plus vaut 1 / recharge ; rien au-delà d'un effet permanent
			var s := _skill(cls, int(eff.get("skill", 0)))
			var cd := maxf(float(s.get("cooldown", DURATION_REF)), 1.0)
			if _duration(s) + per * rank >= cd:
				return SATURATED
			return per / cd * 100.0 * _skill_share(cls, int(eff.get("skill", 0)), "any")
	return 0.0


## Ce que vaut 1 % de [param stat] (talent) pour la classe.
static func stat_value(cls: String, stat: String) -> float:
	var v := float(EFF.get(stat, 0.5)) * _w(cls, stat)
	var p := ClassGear.profile(cls)
	if stat in SURVIVAL and String(p.get("armor", "")) == "plates":
		v *= ARMOR_SURVIVAL
	for ts in ClassGear.top_stats(cls):
		if _key(cls, stat) == String(ts[0]) or (stat == "def_pct" and String(ts[0]) == "def"):
			v *= STAR_BONUS
			break
	return v


## Clé du profil de stats pour une stat de talent.
static func _key(cls: String, stat: String) -> String:
	if stat == "atk_pct":
		return "matk" if String(ClassGear.profile(cls).get("dmg", "phys")) == "mag" else "patk"
	return String(ALIAS.get(stat, stat))


## Poids de la stat au profil de la classe (le critique compte pour le physique et le magique).
static func _w(cls: String, stat: String) -> float:
	var w: Dictionary = ClassGear.profile(cls).get("weights", {})
	if stat == "crit":
		return maxf(float(w.get("crit", 1.0)), float(w.get("mcrit", 0.0)))
	return float(w.get(_key(cls, stat), 1.0))


static func _skill(cls: String, sid: int) -> Dictionary:
	for s in GameData.class_data(cls).get("skills", []):
		if int(s.get("id", 0)) == sid:
			return s
	return {}


## Durée de référence d'un sort (son effet le plus long), pour peser « +1 s ».
static func _duration(s: Dictionary) -> float:
	var d := 0.0
	for src in [s.get("buff", {}), s.get("applies", {})]:
		if src is Dictionary:
			for k in src:
				d = maxf(d, float(src[k]))
	return d if d > 0.0 else DURATION_REF


## Part du sort [param sid] dans ce que fait la classe : dégâts (parmi ses KIT meilleurs sorts), soins, ou forfait de
## soutien. [param mode] « dmg » : seulement les dégâts du sort.
static func _skill_share(cls: String, sid: int, mode: String) -> float:
	var s := _skill(cls, sid)
	if s.is_empty():
		return 0.0
	var skills: Array = GameData.class_data(cls).get("skills", [])
	var share := 0.0
	if float(s.get("mult", 0.0)) > 0.0:
		var all: Array = []
		for x in skills:
			all.append(_dps(x))
		all.sort()
		all.reverse()
		var top := 0.0
		for i in mini(KIT, all.size()):
			top += float(all[i])
		share += SKILL_PART * _dps(s) / maxf(top, 0.001)
	if mode != "dmg" and float(s.get("heal", 0.0)) > 0.0:
		var tot := 0.0
		for x in skills:
			tot += _hps(x)
		share += HEAL_PART * _hps(s) / maxf(tot, 0.001) * _w(cls, "heal_pct")
	if mode != "dmg" and (s.get("buff", {}) is Dictionary and not (s.get("buff", {}) as Dictionary).is_empty()):
		share += BUFF_SHARE
	if mode != "dmg" and share <= 0.0:
		share = BUFF_SHARE
	return share


static func _dps(x: Dictionary) -> float:
	return float(x.get("mult", 0.0)) / maxf(float(x.get("cooldown", 1.0)), 2.0)


static func _hps(x: Dictionary) -> float:
	return float(x.get("heal", 0.0)) / maxf(float(x.get("cooldown", 1.0)), 2.0)


## Tri : la plus grande valeur de [param d] d'abord, puis par nom (stable).
static func _by_value(x, y, d: Dictionary) -> bool:
	var vx := float(d.get(x, 0.0))
	var vy := float(d.get(y, 0.0))
	return vx > vy if not is_equal_approx(vx, vy) else String(x) < String(y)


# --- lecture : totaux, phrases ----------------------------------------------------------------
## Totaux d'un arbre [param r] : {"stats": {stat: total}, "skills": nombre de points dans des talents de sort}.
static func totals(cls: String, r: Dictionary) -> Dictionary:
	var tree: Dictionary = GameData.talents.get(cls, {}).get("talents", {})
	var st := {}
	var sk := 0
	for k in r:
		var n := int(r[k])
		var eff: Dictionary = tree.get(str(int(k)), {}).get("effect", {})
		if String(eff.get("type", "")) == "stat":
			st[eff.stat] = float(st.get(eff.stat, 0.0)) + float(eff.per_level) * n
		elif n > 0:
			sk += n
	return {"stats": st, "skills": sk}


## Nom d'une stat de talent (« PV max », « Critique », « Soins reçus »).
static func stat_name(stat: String) -> String:
	match stat:
		"crit":
			return "Critique"
		"heal_pct":
			return "Soins reçus"
		"atk_pct":
			return "Attaque"
	return ClassGear.stat_label(stat)


static func _pct(v: float) -> String:
	var p := v * 100.0
	if p <= 0.0001:
		return "0"
	return "+%s %%" % (str(roundi(p)) if is_equal_approx(p, roundf(p)) else ("%.1f" % p).replace(".", ","))


## Comparaison avant → après (aperçu de « Conseillé » et des chargements), une stat par ligne, [param n] lignes au plus.
static func compare_lines(cls: String, before: Dictionary, after: Dictionary, n := 6) -> PackedStringArray:
	var a := totals(cls, before)
	var b := totals(cls, after)
	var keys: Array = []
	for k in a.stats:
		keys.append(k)
	for k in b.stats:
		if not k in keys:
			keys.append(k)
	keys.sort_custom(TalentBuild._by_value.bind(b.stats))
	var out: PackedStringArray = []
	for k in keys:
		var va := float(a.stats.get(k, 0.0))
		var vb := float(b.stats.get(k, 0.0))
		if is_equal_approx(va, vb):
			continue
		if out.size() >= n:
			break
		out.append("%s : %s → %s" % [stat_name(String(k)), _pct(va), _pct(vb)])
	if int(a.skills) != int(b.skills):
		out.append("Points dans des sorts : %d → %d" % [int(a.skills), int(b.skills)])
	if out.is_empty():
		out.append("Rien ne change.")
	return out


## « Pensé pour Rempart : PV max, Dégâts, Défense » : le profil de la classe et les stats où va l'essentiel des points.
static func focus_line(cls: String) -> String:
	var p := ClassGear.profile(cls)
	return "Pensé pour %s : %s" % [String(p.get("name", "ta classe")), main_stats(cls, ranks(cls, MAX_POINTS))]


## Les 3 stats qui ont le plus de points dans l'arbre [param r] (« PV max, Dégâts, Défense »), à valeur égale la plus utile.
static func main_stats(cls: String, r: Dictionary, n := 3) -> String:
	var pts := {}
	var tree: Dictionary = GameData.talents.get(cls, {}).get("talents", {})
	for id in r:
		var eff: Dictionary = tree.get(str(id), {}).get("effect", {})
		if String(eff.get("type", "")) == "stat":
			pts[eff.stat] = float(pts.get(eff.stat, 0.0)) + int(r[id]) + stat_value(cls, String(eff.stat)) * 0.01  # points, puis valeur
	var keys: Array = pts.keys()
	keys.sort_custom(TalentBuild._by_value.bind(pts))
	var names: PackedStringArray = []
	for k in keys.slice(0, n):
		names.append(stat_name(String(k)))
	return ", ".join(names) if not names.is_empty() else "sorts renforcés"
