class_name SurvivorLog
extends RefCounted
## Ce que la partie du Survivant raconte (lot SVX-2, BM-SURV SV-B1) : les dégâts du héros PAR SOURCE (arme, chaque sort,
## chaque passif ou évolution, panoplie, effets sur la durée) et les moments marquants (gardien vaincu, évolution, jet
## parfait, panoplie complète…). Lu par la page « Équipement » de la pause (« Qui fait le travail », 30 dernières
## secondes) et par le bilan (part des dégâts, moments). Mode scellé : rien n'est écrit dans le profil.
##
## Attribution : le code qui frappe pose [member tag] juste avant le coup (Player._hit_monster : « weapon » ou
## « skill:<id> » ; Procs.run : « passive:<id> » ou « set:<id> ») et le remet après ; Combatant.take_damage appelle
## [method note] pour tout coup d'un allié du joueur sur un ennemi. Sans étiquette : « dot » (brûlure, saignement…) ou
## « other ». Ne compte que pendant un Survivant (Survivor.active).

const WINDOW := 30  # secondes de la colonne « Qui fait le travail »
const MOMENTS_MAX := 12

## Étiquette de la source du coup en cours ("" : aucune).
static var tag := ""
## Dégâts totaux par source depuis le début de la partie.
static var totals := {}
## Dégâts par seconde réelle (Time.get_ticks_msec / 1000) : {seconde: {source: dégâts}} (les WINDOW + 5 dernières).
static var _secs := {}
## Moments marquants : [{t (temps de carte), text, kind}] dans l'ordre.
static var moments: Array = []


## Nouvelle partie (le HUD du Survivant l'appelle à sa pose).
static func begin() -> void:
	tag = ""
	totals = {}
	_secs = {}
	moments = []


## Coup de [param dmg] d'un allié du joueur (Combatant.take_damage) ; [param dot] : dégâts sur la durée.
static func note(dmg: float, dot := false) -> void:
	if not Survivor.active or dmg <= 0.0:
		return
	var key := tag if tag != "" else ("dot" if dot else "other")
	totals[key] = float(totals.get(key, 0.0)) + dmg
	var s := Time.get_ticks_msec() / 1000
	var b: Dictionary = _secs.get(s, {})
	b[key] = float(b.get(key, 0.0)) + dmg
	_secs[s] = b
	if _secs.size() > WINDOW + 8:
		for k in _secs.keys():
			if int(k) < s - WINDOW - 5:
				_secs.erase(k)


## Étiquette d'un effet déclenché d'id [param proc_id] (Boons.procs_of : « ember_0 » ; Items.active_set_bonuses :
## « set_<panoplie>_<n>_<i> »).
static func proc_tag(proc_id: String) -> String:
	var parts := proc_id.split("_")
	if proc_id.begins_with("set_") and parts.size() >= 4:
		return "set:" + "_".join(parts.slice(1, parts.size() - 2))
	if parts.size() >= 2 and parts[parts.size() - 1].is_valid_int():
		return "passive:" + "_".join(parts.slice(0, parts.size() - 1))
	return "passive:" + proc_id


## Moment marquant de la partie au temps de carte [param t] (« Gardien vaincu en 0:37 »).
static func moment(t: float, text: String, kind := "") -> void:
	if moments.any(func(m): return String(m.text) == text):
		return
	moments.append({"t": t, "text": text, "kind": kind})
	if moments.size() > MOMENTS_MAX:
		moments.pop_front()


## Sources du plus fort au plus faible : [{key, name, kind, icon, dmg, share}] ; [param window] > 0 : seulement les
## [param window] dernières secondes (dmg = total sur la fenêtre, dps = dmg / fenêtre).
static func rows(window := 0) -> Array:
	var sums := {}
	if window > 0:
		var now := Time.get_ticks_msec() / 1000
		for s in _secs:
			if int(s) > now - window:
				for k in _secs[s]:
					sums[k] = float(sums.get(k, 0.0)) + float(_secs[s][k])
	else:
		sums = totals
	var total := 0.0
	for k in sums:
		total += float(sums[k])
	var out: Array = []
	for k in sums:
		var d := source(String(k))
		d["dmg"] = float(sums[k])
		d["share"] = float(sums[k]) / maxf(total, 1.0)
		d["dps"] = float(sums[k]) / float(window) if window > 0 else 0.0
		out.append(d)
	out.sort_custom(func(a, b): return float(a.dmg) > float(b.dmg))
	return out


## Total des dégâts comptés (toute la partie).
static func total() -> float:
	var t := 0.0
	for k in totals:
		t += float(totals[k])
	return t


## Nom lisible, genre (arme, sort, passif, évolution, panoplie, effets, autres) et icône de la source [param key].
static func source(key: String) -> Dictionary:
	var out := {"key": key, "name": "Autres", "kind": "autres", "icon": ""}
	if key == "weapon":
		var w: Dictionary = Profile.equipped.get("weapon", {})
		out.name = Items.card_name(w).trim_prefix("+%d " % int(w.get("upgrade", 0))) if not w.is_empty() else "Auto-attaque"
		out.kind = "arme"
		out.icon = String(w.get("icon", ""))
	elif key.begins_with("skill:"):
		var d := Run.skill_def(int(key.trim_prefix("skill:")))
		out.name = String(d.get("name", "Sort"))
		out.kind = "sort"
		out.icon = String(d.get("icon", ""))
	elif key.begins_with("passive:"):
		var id := key.trim_prefix("passive:")
		var b := Boons.get_def(id)
		out.name = String(b.get("name", "Effet d'objet"))
		out.kind = "évolution" if not (b.get("requires", []) as Array).is_empty() else "passif"
		out.icon = String(b.get("icon", Boons.ICONS.get(id, "")))
	elif key.begins_with("set:"):
		out.name = "Panoplie " + SurvivorPool.panoply_name(key.trim_prefix("set:"))
		out.kind = "panoplie"
	elif key == "dot":
		out.name = "Effets sur la durée"
		out.kind = "effets"
	return out
