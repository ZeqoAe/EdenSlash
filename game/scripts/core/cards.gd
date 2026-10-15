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
	"area": ["Rayon des zones", "%"], "reach": ["Portée", "%"], "basic_dmg": ["Dégâts de l'auto-attaque", "%"],
	"proj": ["Projectiles / frappes", "n"], "pierce": ["Perforation", "n"], "bounce": ["Rebonds", "n"],
	"cast_speed": ["Vitesse d'incantation", "%"], "execute": ["Seuil d'exécution", "%"], "rerolls": ["Relances", ""],
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
		"n":
			return "+%d" % floori(v + 0.001)  # nombre entier (projectiles…) : les raretés s'additionnent
	return "%s%s" % ["+" if v >= 0.0 else "", _num(v)]


static func _num(v: float) -> String:
	return str(roundi(v)) if absf(v - roundf(v)) < 0.05 else String.num(v, 1).replace(".", ",")  # virgule décimale française


## Lignes « stat : avant → après » d'un passif dont la puissance passe de [param before] à
## [param after] (somme des multiplicateurs de rareté des cartes prises).
static func stat_lines(def: Dictionary, before: float, after: float) -> PackedStringArray:
	var out: PackedStringArray = skill_mod_lines(def, before, after)
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
	# facettes (les anciennes cartes de classe fondues dans l'amélioration) : rare 1, épique 2,
	# légendaire 3 parmi Puissance (ou Ferveur), Cadence, Persistance
	var cands: Array = ["heal" if (kind == "heal" or float(s.get("heal", 0.0)) > 0.0) else ("dur" if kind == "buff" else "pow"), "cd"]
	if kind == "buff" or not (s.get("applies", {}) as Dictionary).is_empty():
		cands.append("dur")
	cands.shuffle()
	var facets: Array = []
	for f in cands.slice(0, FACETS.get(tier_id, 0)):
		facets.append(f)
		var fv: Dictionary = FACET_VALUES[f]
		out[fv.key] = float(out.get(fv.key, 0.0)) + float(fv.value) * m
	if not facets.is_empty():
		out["facets"] = facets
	# bonus d'attribut au lancement : seulement à partir de rare, garanti en légendaire
	if tier_id != "common" and (tier_id == "legendary" or randf() < float(r.rider_chance)):
		var attr: String = attr_hint if attr_hint != "" else ["str", "agi", "int", "wis"].pick_random()
		out["rider"] = {"stat": attr, "value": float(r.rider_pct) * m, "duration": float(r.rider_duration)}
	return out


## Facettes d'une amélioration de sort par rareté, et leur effet (clé de l'entrée du sort, valeur).
const FACETS := {"common": 0, "rare": 1, "epic": 2, "legendary": 3}
const FACET_VALUES := {
	"pow": {"key": "dmg", "value": 0.08, "name": "Puissance"},
	"heal": {"key": "heal", "value": 0.08, "name": "Ferveur"},
	"cd": {"key": "cd", "value": 0.04, "name": "Cadence"},
	"dur": {"key": "dur", "value": 0.12, "name": "Persistance"},
}


## Texte d'une amélioration de sort : totaux avant → après.
static func skill_upgrade_lines(cur: Dictionary, up: Dictionary) -> PackedStringArray:
	var out: PackedStringArray = []
	for k in [["dmg", "Dégâts"], ["heal", "Soins"], ["dur", "Durée des effets"]]:
		if up.has(k[0]):
			var a := float(cur.get(k[0], 0.0))
			out.append("%s : +%s %% → [b]+%s %%[/b]" % [k[1], _num(a * 100.0), _num((a + float(up[k[0]])) * 100.0)])
	var c := float(cur.get("cd", 0.0))
	out.append("Recharge : -%s %% → [b]-%s %%[/b]" % [_num(minf(c, 0.6) * 100.0), _num(minf(c + float(up.cd), 0.6) * 100.0)])
	if up.has("facets"):
		out.append("Facettes : [b]%s[/b]" % ", ".join((up.facets as Array).map(func(f): return String(FACET_VALUES[f].name))))
	if up.has("rider"):
		var rd: Dictionary = up.rider
		out.append("Au lancement : [b]+%s %% %s[/b] pendant %s s" % [_num(float(rd.value) * 100.0), ATTR_FR.get(String(rd.stat), rd.stat), _num(float(rd.duration))])
	return out


# --- méta-progression : cartes à débloquer ----------------------------------------------------
## Cartes communes à débloquer (les autres sont disponibles d'emblée ; les passifs de classe
## aussi) : [record cumulé sur toutes les runs (Profile.records, « best_level » : niveau max
## atteint en run), objectif, texte]. Modifiable par l'éditeur de cartes (champ « unlock »).
const UNLOCK := {
	"lingering": ["kills", 500, "Vaincre %d monstres"],
	"scholar": ["best_level", 12, "Atteindre le niveau %d en run"],
	"recall": ["chests", 5, "Ouvrir %d coffres de la carte"],
	"volatile": ["kills", 1000, "Vaincre %d monstres"],
	"shockwave": ["elite_kills", 10, "Vaincre %d élites"],
	"wind_step": ["dodges", 50, "Esquiver %d attaques"],
	"battle_trance": ["best_hit", 1500, "Infliger un coup de %d dégâts"],
	"hunter_eye": ["elite_kills", 25, "Vaincre %d élites"],
	"second_wind": ["healed", 5000, "Soigner %d PV"],
	"momentum": ["kills", 2500, "Vaincre %d monstres"],
	"executioner": ["boss_kills", 1, "Vaincre %d boss"],
	"echo": ["shrines", 5, "Capturer %d sanctuaires"],
	"frost_nova": ["dodges", 150, "Esquiver %d attaques"],
	"glass_cannon": ["best_hit", 4000, "Infliger un coup de %d dégâts"],
	"storm_lord": ["boss_kills", 2, "Vaincre %d boss"],
	"glacial_shatter": ["boss_kills", 3, "Vaincre %d boss"],
	"phoenix_blade": ["boss_kills", 4, "Vaincre %d boss"],
	"steel_tempest": ["boss_kills", 5, "Vaincre %d boss"],
}
## Effets des cartes communes réutilisables ailleurs que dans les cartes (passifs des pièces du Survivant, SurvivorGear) :
## tous les passifs qui ont une statistique ou un effet déclenché, sauf les effets immédiats (Rappel), les malus (Canon de
## verre), les évolutions (prérequis) et les sauts (sans statistique). Ordre FIXE : les tables déterministes s'y réfèrent
## (ajouter à la fin).
const PASSIVE_EFFECTS := ["wide_arc", "long_reach", "sharpened", "giant_slayer", "combo_flow", "incantation", "heavy_finisher",
	"multishot", "piercing", "ricochet", "deep_wounds", "lingering", "magnet", "scholar", "fortune", "precision", "toughness",
	"brute", "arcana", "static_blade", "frost_edge", "ember", "volatile", "shockwave", "wind_step", "battle_trance",
	"hunter_eye", "second_wind", "momentum", "executioner", "echo", "frost_nova", "vigor", "swift_blade", "bloodthirst",
	"light_step", "keen_edge", "focus"]


## Effets réutilisables existants (une carte supprimée dans l'éditeur du mode dev en sort).
static func passive_effects() -> Array:
	return PASSIVE_EFFECTS.filter(func(id): return not Boons.get_def(String(id)).is_empty())


## Ligne d'un effet à la puissance [param pw] (1 = une carte commune) : « Lame large : Rayon des zones +14 % » ; pour un
## effet déclenché, sa description.
static func effect_line(id: String, pw := 1.0) -> String:
	var d := Boons.get_def(id)
	if d.is_empty():
		return id
	var t := total_text(d, pw) if not (d.get("stat", {}) as Dictionary).is_empty() else String(d.get("desc", ""))
	return "%s : %s" % [String(d.get("name", id)), t]


## Bannir (retirée de la run) et garder (revient au prochain choix) : nombre par run.
const BANS_PER_RUN := 3
const LOCKS_PER_RUN := 3


static func unlock_rule(id: String) -> Array:
	var d := Boons.get_def(id)
	if d.has("unlock"):
		return d.unlock if d.unlock is Array else []
	return UNLOCK.get(id, [])


static func record_of(key: String) -> float:
	if key == "best_level":
		return float(Profile.best_level)
	return float(Profile.records.get(key, 0.0))


## Carte commune disponible ? (sans condition, condition remplie, ou débloquée en mode dev)
static func card_unlocked(id: String) -> bool:
	var r := unlock_rule(id)
	return r.is_empty() or id in Profile.unlocked_cards or record_of(String(r[0])) >= float(r[1])


static func unlock_text(id: String) -> String:
	var r := unlock_rule(id)
	return String(r[2]) % int(r[1]) if not r.is_empty() else ""


static func unlock_progress(id: String) -> Vector2:
	var r := unlock_rule(id)
	return Vector2(minf(record_of(String(r[0])), float(r[1])), float(r[1])) if not r.is_empty() else Vector2(1, 1)


static func unlocked_ids() -> Array:
	return Boons.all().filter(func(d): return card_unlocked(String(d.id))).map(func(d): return String(d.id))



# --- cartes de classe : elles renforcent directement un sort de la classe -------------------
## Effets possibles d'une carte de sort : [suffixe d'id, nom, rareté, niveaux max, effet
## (skill_mod : dmg, cd, duration, heal ; par niveau), texte].
const SKILL_CARDS := {
	"pow": ["Puissance", "rare", 5, {"dmg": 0.2}, "+20 %% de dégâts de « %s »."],
	"cd": ["Cadence", "common", 3, {"cd": 0.1}, "-10 %% de temps de recharge de « %s »."],
	"dur": ["Persistance", "common", 3, {"duration": 0.25}, "+25 %% de durée des effets de « %s » (bonus, états infligés)."],
	"heal": ["Ferveur", "rare", 5, {"heal": 0.2}, "+20 %% de soins de « %s »."],
}
const SKILL_MOD_FR := {"dmg": "Dégâts", "cd": "Recharge", "duration": "Durée des effets", "heal": "Soins"}

static var _class_cards := {}


## Cartes de classe de [param cid] : pour chaque sort, puissance (ou ferveur pour les soins),
## cadence, et persistance s'il pose un bonus ou un état. Elles ne sortent en run que si le
## sort a été pris.
static func class_cards(cid: String) -> Array:
	if _class_cards.has(cid):
		return _class_cards[cid]
	var out: Array = []
	for s in GameData.class_data(cid).get("skills", []):
		var kinds: Array = []
		if String(s.kind) == "heal" or float(s.get("heal", 0.0)) > 0.0:
			kinds.append("heal")
		elif String(s.kind) != "buff":
			kinds.append("pow")
		kinds.append("cd")
		if String(s.kind) == "buff" or not (s.get("applies", {}) as Dictionary).is_empty():
			kinds.append("dur")
		for k in kinds:
			var t: Array = SKILL_CARDS[k]
			out.append({"id": "sk%d_%s" % [int(s.id), k], "name": "%s : %s" % [s.name, t[0]], "rarity": t[1], "max": t[2],
				"skill": int(s.id), "skill_name": String(s.name), "skill_mod": (t[3] as Dictionary).duplicate(),
				"icon": String(s.get("icon", "")), "desc": String(t[4]) % s.name, "class": cid})
	_class_cards[cid] = out
	return out


static func class_card(cid: String, id: String) -> Dictionary:
	if not id.begins_with("sk"):
		return {}
	for d in class_cards(cid):
		if d.id == id:
			return d
	return {}


## Lignes des effets d'une carte de sort entre deux puissances.
static func skill_mod_lines(def: Dictionary, before: float, after: float) -> PackedStringArray:
	var out: PackedStringArray = []
	var m: Dictionary = def.get("skill_mod", {})
	for k in m:
		var sign := "-" if k == "cd" else "+"
		var a := "%s%d %%" % [sign, roundi(float(m[k]) * before * 100.0)]
		var b := "%s%d %%" % [sign, roundi(float(m[k]) * after * 100.0)]
		out.append(("%s de « %s » : [b]%s[/b]" % [SKILL_MOD_FR.get(k, k), def.get("skill_name", ""), b]) if before <= 0.0 else
			("%s de « %s » : %s → [b]%s[/b]" % [SKILL_MOD_FR.get(k, k), def.get("skill_name", ""), a, b]))
	return out
