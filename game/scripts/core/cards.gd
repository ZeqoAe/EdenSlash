class_name Cards
extends RefCounted
## Règles des cartes de build (modifiables dans l'éditeur de cartes du mode dev, enregistrées
## dans data/dev_edits.json -> "cards" et "card_rules") :
## - chaque carte proposée a une **rareté tirée** (commune, rare, épique, légendaire) qui
##   multiplie ce qu'elle apporte ; un passif se prend jusqu'à 10 fois ;
## - la carte affiche le total avant → après (« PV max : +15 % → +30 % ») ;
## - les cartes d'amélioration de sort donnent dégâts, soins ou durée selon le sort, moins de
##   recharge, et parfois un bonus d'attribut temporaire au lancement (Intelligence…).

const MAX_LEVEL := 10
## Raretés tirées : nom, couleur, multiplicateur des bonus, poids du tirage.
const TIERS := {
	"common": {"name": "Commune", "color": Color(0.85, 0.85, 0.88), "mult": 1.0, "weight": 60.0},
	"rare": {"name": "Rare", "color": Color(0.4, 0.7, 1.0), "mult": 1.5, "weight": 27.0},
	"epic": {"name": "Épique", "color": Color(0.78, 0.45, 1.0), "mult": 2.2, "weight": 10.0},
	"legendary": {"name": "Légendaire", "color": Color(1.0, 0.6, 0.15), "mult": 3.0, "weight": 3.0},
}
const TIER_ORDER := ["common", "rare", "epic", "legendary"]
## Améliorations de sort (par carte commune, × rareté) : dégâts, recharge, soins, durée des
## effets, chances d'un bonus d'attribut au lancement (rare et mieux), sa valeur et sa durée.
const SKILL_RULES := {"dmg": 0.12, "cd": 0.05, "heal": 0.15, "duration": 0.12, "max_rank": 10,
	"rider_chance": 0.5, "rider_pct": 0.08, "rider_duration": 6.0}
## Bonus d'attribut des sorts : statut affiché (Combatant.STATUS_INFO) par attribut.
const RIDER_STATUS := {"str": "spell_str", "agi": "spell_agi", "int": "spell_int", "wis": "spell_wis"}
const ATTR_FR := {"str": "Force", "agi": "Agilité", "int": "Intelligence", "wis": "Sagesse", "lck": "Chance"}

## Statistiques propres aux cartes : [nom, unité] ("%" : en pourcentage, "s" : secondes, "" : nombre).
const STAT_FR := {
	"area": ["Rayon des zones", "%"], "reach": ["Portée", "%"], "finisher_dmg": ["Dégâts du 3e coup", "%"],
	"finisher_area": ["Zone du 3e coup", "%"], "finisher_hits": ["Frappes du 3e coup", ""],
	"combo_window": ["Délai du combo", "s"], "execute": ["Seuil d'exécution", "%"], "rerolls": ["Relances", ""],
	"dot_dur": ["Durée des effets sur la durée", "%"], "pickup": ["Zone de collecte", "%"], "xp_pct": ["Expérience", "%"],
}
## Paramètres des effets déclenchés montrés sur la carte : [nom, unité].
const PROC_FR := {"chance": ["Chances", "%"], "mult": ["Dégâts", "x%"], "chain": ["Rebonds", ""],
	"duration": ["Durée", "s"], "radius": ["Rayon", "m"], "amount": ["Effet", "amount"], "cd": ["Recharge", "s"]}


static func rules() -> Dictionary:
	var r := SKILL_RULES.duplicate()
	r.merge(DevEdits.data.get("card_rules", {}).get("skill", {}), true)
	return r


static func tier(id: String) -> Dictionary:
	var t: Dictionary = TIERS.get(id, TIERS.common).duplicate()
	t.merge(DevEdits.data.get("card_rules", {}).get("tiers", {}).get(id, {}), true)
	return t


static func tier_mult(id: String) -> float:
	return float(tier(id).get("mult", 1.0))


## Rareté tirée pour une carte proposée ([param luck] : bonus de chance, cartes des boss…).
static func roll_tier(luck := 0.0) -> String:
	var total := 0.0
	var w := {}
	for id in TIER_ORDER:
		var x := float(tier(id).weight) * (1.0 + luck * TIER_ORDER.find(id))
		w[id] = x
		total += x
	var r := randf() * total
	for id in TIER_ORDER:
		r -= float(w[id])
		if r <= 0.0:
			return id
	return "common"


# --- textes cumulés ------------------------------------------------------------------------
static func stat_name(k: String) -> String:
	if STAT_FR.has(k):
		return String(STAT_FR[k][0])
	return String(Items.STAT_NAMES.get(k, Items.EXTRA_STAT_NAMES.get(k, k)))


static func stat_value(k: String, v: float) -> String:
	var unit := String(STAT_FR[k][1]) if STAT_FR.has(k) else ("%" if k in Items.PERCENT_STATS else "")
	match unit:
		"%":
			return "%s%s %%" % ["+" if v >= 0.0 else "", _num(v * 100.0)]
		"s":
			return "+%s s" % _num(v)
	return "%s%s" % ["+" if v >= 0.0 else "", _num(v)]


static func _num(v: float) -> String:
	return str(roundi(v)) if absf(v - roundf(v)) < 0.05 else String.num(v, 1)


## Lignes « stat : avant → après » d'un passif dont la puissance passe de [param before] à
## [param after] (somme des multiplicateurs de rareté des cartes prises).
static func stat_lines(def: Dictionary, before: float, after: float) -> PackedStringArray:
	var out: PackedStringArray = []
	var st: Dictionary = def.get("stat", {})
	for k in st:
		var v := float(st[k])
		if before <= 0.0:
			out.append("%s : [b]%s[/b]" % [stat_name(k), stat_value(k, v * after)])
		else:
			out.append("%s : %s → [b]%s[/b]" % [stat_name(k), stat_value(k, v * before), stat_value(k, v * after)])
	return out


## Totaux actuels d'un passif (texte simple) : « PV max +30 % · Portée +15 % ».
static func total_text(def: Dictionary, pw: float) -> String:
	var parts: PackedStringArray = []
	var st: Dictionary = def.get("stat", {})
	for k in st:
		parts.append("%s %s" % [stat_name(k), stat_value(k, float(st[k]) * pw)])
	return " · ".join(parts)


## Lignes des effets déclenchés (paramètres qui changent) entre deux puissances.
static func proc_lines(def: Dictionary, before: float, after: float) -> PackedStringArray:
	var out: PackedStringArray = []
	var a := Boons.procs_of(def, maxf(before, 1.0)) if before > 0.0 else []
	var b := Boons.procs_of(def, after)
	for i in b.size():
		var p: Dictionary = b[i]
		var q: Dictionary = a[i] if i < a.size() else {}
		for k in PROC_FR:
			if not p.has(k):
				continue
			var nv := float(p[k])
			var ov := float(q.get(k, nv))
			if not q.is_empty() and absf(nv - ov) < 0.001:
				continue
			if q.is_empty() and k == "cd" and nv <= 0.0:
				continue
			if q.is_empty():
				out.append("%s : [b]%s[/b]" % [String(PROC_FR[k][0]), _proc_value(k, nv)])
			else:
				out.append("%s : %s → [b]%s[/b]" % [String(PROC_FR[k][0]), _proc_value(k, ov), _proc_value(k, nv)])
	return out


static func _proc_value(k: String, v: float) -> String:
	match String(PROC_FR[k][1]):
		"%":
			return "%s %%" % _num(v * 100.0)
		"x%":
			return "%s %%" % _num(v * 100.0)
		"s":
			return "%s s" % _num(v)
		"m":
			return "%s m" % _num(v)
		"amount":
			return ("%s %%" % _num(v * 100.0)) if v < 1.0 else ("%s s" % _num(v))
	return _num(v)


# --- améliorations de sort ------------------------------------------------------------------
## Bonus d'une carte d'amélioration du sort [param s] (définition de la classe) à la rareté
## [param tier_id] : {dmg, cd, heal, dur, rider}.
static func skill_upgrade(s: Dictionary, tier_id: String, attr_hint := "") -> Dictionary:
	var r := rules()
	var m := tier_mult(tier_id)
	var kind := String(s.get("kind", ""))
	var out := {"cd": float(r.cd) * m}
	if kind == "heal" or float(s.get("heal", 0.0)) > 0.0:
		out["heal"] = float(r.heal) * m
	elif kind == "buff":
		out["dur"] = float(r.duration) * m
	else:
		out["dmg"] = float(r.dmg) * m
	# bonus d'attribut au lancement : seulement à partir de rare, plus probable si rare+
	if tier_id != "common" and randf() < float(r.rider_chance):
		var attr: String = attr_hint if attr_hint != "" else ["str", "agi", "int", "wis"].pick_random()
		out["rider"] = {"stat": attr, "value": float(r.rider_pct) * m, "duration": float(r.rider_duration)}
	return out


## Texte d'une amélioration de sort : totaux avant → après.
static func skill_upgrade_lines(cur: Dictionary, up: Dictionary) -> PackedStringArray:
	var out: PackedStringArray = []
	for k in [["dmg", "Dégâts"], ["heal", "Soins"], ["dur", "Durée des effets"]]:
		if up.has(k[0]):
			var a := float(cur.get(k[0], 0.0))
			out.append("%s : +%s %% → [b]+%s %%[/b]" % [k[1], _num(a * 100.0), _num((a + float(up[k[0]])) * 100.0)])
	var c := float(cur.get("cd", 0.0))
	out.append("Recharge : -%s %% → [b]-%s %%[/b]" % [_num(minf(c, 0.6) * 100.0), _num(minf(c + float(up.cd), 0.6) * 100.0)])
	if up.has("rider"):
		var rd: Dictionary = up.rider
		out.append("Au lancement : [b]+%s %% %s[/b] pendant %s s" % [_num(float(rd.value) * 100.0), ATTR_FR.get(String(rd.stat), rd.stat), _num(float(rd.duration))])
	return out
