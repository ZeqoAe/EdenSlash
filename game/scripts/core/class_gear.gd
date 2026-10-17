class_name ClassGear
extends RefCounted
## Équipement des 60 classes (lot E3, nuit du 15/10) :
## - profils de stats (`data/class_profiles.json`, généré par `tools/gen_class_profiles.py`) : 7 profils, un par
##   rôle (type de dégâts, attribut principal, type d'armure) ; la note d'une pièce pour une classe est
##   `Items.rating(pièce, profil)` (sans profil, la note commune ne change pas) ;
## - « Équiper le meilleur » (préréglage actif d'une classe, pièces du coffre commun, arme du type de la classe ;
##   option « garder mes choix » : les pièces posées à la main restent) ;
## - « Appliquer à la famille » : le préréglage actif copié vers les classes du même profil (chacune garde une arme
##   de son type ; une classe sans arme de son type au coffre est sautée) ;
## - annulation de la dernière de ces deux actions ;
## - la fiche du Registre de l'équipement (Carnet) : où en est chaque classe et quelle activité donne ce qui manque.

const PATH := "res://data/class_profiles.json"
## Part de la PE attendue à partir de laquelle une classe est « équipée » (palier « Solide » de GearPower).
const EQUIPPED_RATIO := 0.7
## Pièces d'une panoplie complète (archétype de donjon, Esprits).
const PANOPLY := 6
## Passes d'échanges pièce par pièce après le premier choix (panoplies).
const SWAP_PASSES := 3
## États d'une classe dans le Registre, du moins au plus équipé.
const STATUS := ["À commencer", "À compléter", "À renforcer", "Équipée", "Optimale"]
const STATUS_EQUIPPED := 3

static var _data: Dictionary = {}
## Dernière action annulable : {"label", "save", "presets": {classe: {"index", "slots", "auto"}}}.
static var _undo: Dictionary = {}


# --- profils ----------------------------------------------------------------------------------
static func data() -> Dictionary:
	if _data.is_empty():
		var d = JSON.parse_string(FileAccess.get_file_as_string(PATH)) if FileAccess.file_exists(PATH) else null
		_data = d if d is Dictionary else {"profiles": {}, "classes": {}}
	return _data


static func profile_id(cid: String) -> String:
	return String(data().get("classes", {}).get(cid, ""))


## Profil de stats de la classe : {id, name, dmg, focus, armor, desc, weights} ; {} si la classe est inconnue.
static func profile(cid: String) -> Dictionary:
	var pid := profile_id(cid)
	var p: Dictionary = data().get("profiles", {}).get(pid, {})
	if p.is_empty():
		return {}
	var out := p.duplicate()
	out["id"] = pid
	return out


static func profile_name(pid: String) -> String:
	return String(data().get("profiles", {}).get(pid, {}).get("name", pid))


static func profile_ids() -> Array:
	return (data().get("profiles", {}) as Dictionary).keys()


## Classes du profil [param pid], dans l'ordre de data/classes.json.
static func classes_of(pid: String) -> Array:
	var out: Array = []
	for cid in GameData.classes:
		if profile_id(String(cid)) == pid:
			out.append(String(cid))
	return out


static func class_label(cid: String) -> String:
	return String(GameData.class_data(cid).get("name_fr", cid))


# --- équipement d'une classe ------------------------------------------------------------------
## uid -> objet du coffre commun.
static func vault_map() -> Dictionary:
	var out := {}
	for it in Profile.vault:
		out[String(it.get("uid", ""))] = it
	return out


## Préréglage actif de [param cid] tel qu'il est enregistré ({} si la classe n'en a pas encore).
static func _active_set(cid: String) -> Dictionary:
	var p: Dictionary = Profile.presets.get(cid, {})
	var sets: Array = p.get("sets", [])
	if sets.is_empty():
		return {}
	return sets[clampi(int(p.get("active", 0)), 0, sets.size() - 1)]


## Équipement du préréglage actif de [param cid] : emplacement -> objet ([param by_uid] : vault_map, pour
## ne la construire qu'une fois). La classe affichée au hub donne son équipement porté.
static func gear_of(cid: String, by_uid: Dictionary = {}) -> Dictionary:
	if not Profile.in_run and cid == Profile._view_class:
		return Profile.equipped.duplicate()
	var slots: Dictionary = _active_set(cid).get("slots", {})
	if slots.is_empty():
		return {}
	var m := by_uid if not by_uid.is_empty() else vault_map()
	var out := {}
	for slot in slots:
		var it: Dictionary = m.get(String(slots[slot]), {})
		if not it.is_empty():
			out[slot] = it
	return out


## [param item] peut aller dans l'emplacement [param slot] de la classe [param cid] (arme principale : du type
## de la classe ; arme secondaire : n'importe quelle arme).
static func fits(item: Dictionary, slot: String, cid: String) -> bool:
	var s := String(item.get("slot", ""))
	if slot == "offhand":
		return s == "weapon"
	if slot == "weapon":
		return s == "weapon" and Items.weapon_type_of(item) == Items.default_weapon_type(cid)
	return s == slot and slot in Items.SLOTS


## [param item] se porte au niveau de héros actuel (lot H3 ; pièces de départ toujours).
static func wearable(item: Dictionary) -> bool:
	return HeroLevel.can_wear(item)


## Pièces portées par [param cid] au-dessus du niveau de héros (comptes d'avant le niveau de héros : gardées, signalées).
static func over_level(cid: String, by_uid: Dictionary = {}) -> int:
	var n := 0
	for it in gear_of(cid, by_uid).values():
		if not wearable(it):
			n += 1
	return n


## Emplacements choisis à la main dans le préréglage actif : ni pièce de départ, ni pièce posée par le
## dernier « Équiper le meilleur ».
static func choice_slots(cid: String) -> Array:
	var auto: Dictionary = _active_set(cid).get("auto", {})
	var out: Array = []
	var g := gear_of(cid)
	for slot in g:
		var it: Dictionary = g[slot]
		if not it.get("starter", false) and String(auto.get(slot, "")) != String(it.get("uid", "")):
			out.append(String(slot))
	return out


# --- meilleur équipement ----------------------------------------------------------------------
static func _value(it: Dictionary, prof: Dictionary, cache: Dictionary) -> float:
	var uid := String(it.get("uid", ""))
	if not cache.has(uid):
		cache[uid] = float(GearPower.item_power(it, prof))
	return float(cache[uid])


## Valeur d'un équipement pour le profil (pièces × leur part, × paliers de panoplie).
static func _total(g: Dictionary, prof: Dictionary, cache: Dictionary) -> float:
	var t := 0.0
	for slot in g:
		t += _value(g[slot], prof, cache) * GearPower.slot_share(String(slot))
	return t * GearPower.set_factor(g)


static func _uid(it) -> String:
	return String(it.get("uid", "")) if it is Dictionary else ""


## Meilleur équipement du coffre commun pour [param cid] : chaque emplacement prend la pièce de plus grande
## valeur pour le profil de la classe ; puis, panoplie par panoplie, ses meilleures pièces sont essayées par
## paliers (2, 4, 6) et gardées si l'ensemble vaut plus ; enfin des échanges pièce par pièce.
## [param keep] : emplacement -> objet qui ne bouge pas (« garder mes choix »).
## Lot H3 : seulement les pièces portables au niveau de héros, et celles que la classe porte déjà (jamais retirées d'office).
static func best_gear(cid: String, keep: Dictionary = {}) -> Dictionary:
	var prof := profile(cid)
	var cache := {}
	var slots: Array = Items.SLOTS + ["offhand"]
	var cands := {}
	for slot in slots:
		cands[slot] = []
	var worn := {}
	for it in gear_of(cid).values():
		worn[_uid(it)] = true
	for it in Profile.vault:
		if not wearable(it) and not worn.has(_uid(it)):
			continue
		for slot in slots:
			if fits(it, slot, cid):
				cands[slot].append(it)
	var gear := keep.duplicate()
	var free: Array = slots.filter(func(s): return not keep.has(s))
	for slot in free:
		var best: Dictionary = {}
		for it in cands[slot]:
			if slot == "offhand" and _uid(it) == _uid(gear.get("weapon")):
				continue
			if best.is_empty() or _value(it, prof, cache) > _value(best, prof, cache):
				best = it
		if not best.is_empty():
			gear[slot] = best
	var score := _total(gear, prof, cache)
	# panoplies : les N meilleures pièces d'une panoplie d'un coup (un échange seul ne franchit pas un palier)
	var sids := {}
	for slot in free:
		if slot == "offhand":
			continue
		for it in cands[slot]:
			for k in ["set", "archetype"]:
				if String(it.get(k, "")) != "":
					sids[String(it.get(k))] = true
	for sid in sids:
		var per_slot := {}
		for slot in free:
			if slot == "offhand":
				continue
			for it in cands[slot]:
				if String(it.get("set", "")) == sid or String(it.get("archetype", "")) == sid:
					if not per_slot.has(slot) or _value(it, prof, cache) > _value(per_slot[slot], prof, cache):
						per_slot[slot] = it
		var order: Array = per_slot.keys()
		order.sort_custom(func(a, b): return _value(per_slot[a], prof, cache) > _value(per_slot[b], prof, cache))
		for n in Items.set_tiers(sid):
			if order.size() < int(n):
				break
			var g2 := gear.duplicate()
			for slot in order.slice(0, int(n)):
				g2[slot] = per_slot[slot]
			if _uid(g2.get("offhand")) != "" and _uid(g2.get("offhand")) == _uid(g2.get("weapon")):
				g2.erase("offhand")
			var t := _total(g2, prof, cache)
			if t > score + 0.5:
				gear = g2
				score = t
	# échanges pièce par pièce (pièces de panoplie seulement : les autres sont déjà au mieux)
	for _pass in SWAP_PASSES:
		var improved := false
		for slot in free:
			if slot == "offhand":
				continue
			for it in cands[slot]:
				if String(it.get("set", "")) == "" and String(it.get("archetype", "")) == "":
					continue
				if _uid(it) == _uid(gear.get(slot)) or (slot == "weapon" and _uid(it) == _uid(gear.get("offhand"))):
					continue
				var g3 := gear.duplicate()
				g3[slot] = it
				var t3 := _total(g3, prof, cache)
				if t3 > score + 0.5:
					gear = g3
					score = t3
					improved = true
		if not improved:
			break
	return gear


## Nombre d'emplacements qui changent entre deux équipements.
static func diff_count(a: Dictionary, b: Dictionary) -> int:
	var n := 0
	for slot in Items.SLOTS + ["offhand"]:
		if _uid(a.get(slot)) != _uid(b.get(slot)):
			n += 1
	return n


## Écrit [param gear] dans le préréglage actif de [param cid] (même dictionnaire : `Profile.loadout` le suit).
static func _write(cid: String, gear: Dictionary, auto: Dictionary) -> void:
	var p := Profile._class_presets(cid)
	var s: Dictionary = p.sets[clampi(int(p.active), 0, p.sets.size() - 1)]
	var slots: Dictionary = s.slots
	slots.clear()
	for slot in gear:
		slots[slot] = String(gear[slot].uid)
	s["auto"] = auto


static func _after_write(cids: Array) -> void:
	if Profile.selected_class in cids:
		Profile._lobby_view()
	Profile.save_profile()


static func _plural(n: int, word: String) -> String:
	return "%d %s%s" % [n, word, "s" if n > 1 else ""]


## « Équiper le meilleur » pour [param cid] (hors run) ; renvoie le message à afficher.
static func equip_best(cid: String, keep_choices := false) -> String:
	if Profile.in_run:
		return ""
	Profile._sync_vault()
	var current := gear_of(cid)
	var keep := {}
	if keep_choices:
		for slot in choice_slots(cid):
			keep[slot] = current[slot]
	var best := best_gear(cid, keep)
	if not best.has("weapon") and current.has("weapon"):
		best["weapon"] = current.weapon  # aucune arme du type de la classe au coffre : on garde la sienne
	var n := diff_count(current, best)
	if n == 0:
		return "Rien à changer : c'est déjà ton meilleur équipement."
	remember_undo("Équiper le meilleur", [cid])
	var auto := {}
	for slot in best:
		if not keep.has(slot):
			auto[slot] = String(best[slot].uid)
	_write(cid, best, auto)
	_after_write([cid])
	return "%d pièce%s changée%s pour le profil %s." % [n, "s" if n > 1 else "", "s" if n > 1 else "", profile_name(profile_id(cid))]


## Meilleure arme du type de [param cid] au coffre commun (pour son profil), {} s'il n'y en a pas.
static func best_weapon(cid: String) -> Dictionary:
	var prof := profile(cid)
	var cache := {}
	var best: Dictionary = {}
	for it in Profile.vault:
		if fits(it, "weapon", cid) and wearable(it) and (best.is_empty() or _value(it, prof, cache) > _value(best, prof, cache)):
			best = it
	return best


## Classes qui recevraient le préréglage actif de [param cid] : {"to": [classes], "skip": [classes sans arme de leur type]}.
static func family_plan(cid: String) -> Dictionary:
	var src := gear_of(cid)
	var to: Array = []
	var skip: Array = []
	var gears := {}
	var over := 0  # pièces au-dessus du niveau de héros : pas copiées (lot H3), la classe garde la sienne
	for t in classes_of(profile_id(cid)):
		if t == cid:
			continue
		var g := src.duplicate()
		var mine := gear_of(t)
		for slot in src:
			if not wearable(src[slot]) and _uid(mine.get(slot)) != _uid(src[slot]):
				over += 1
				if mine.has(slot):
					g[slot] = mine[slot]
				else:
					g.erase(slot)
		var w: Dictionary = g.get("weapon", {})
		if w.is_empty() or not fits(w, "weapon", t):
			w = best_weapon(t)
		if w.is_empty():
			skip.append(t)
			continue
		g["weapon"] = w
		if _uid(g.get("offhand")) == _uid(w):
			g.erase("offhand")
		to.append(t)
		gears[t] = g
	return {"to": to, "skip": skip, "gears": gears, "over": over}


## « Appliquer à la famille » : le préréglage actif de [param cid] copié dans le préréglage actif des classes du
## même profil (annulable) ; renvoie le message à afficher.
static func apply_family(cid: String) -> String:
	if Profile.in_run:
		return ""
	Profile._sync_vault()
	var plan := family_plan(cid)
	var to: Array = plan.to
	var fam := profile_name(profile_id(cid))
	if to.is_empty():
		return "Aucune autre classe %s n'a d'arme de son type au coffre." % fam
	remember_undo("Appliquer à la famille", to)
	for t in to:
		_write(t, plan.gears[t], {})
	_after_write(to)
	var skip: Array = plan.skip
	var msg := "Copié vers %s %s%s." % [_plural(to.size(), "classe"), fam, (" (%s sans arme de leur type)" % _plural(skip.size(), "autre")) if not skip.is_empty() else ""]
	if int(plan.over) > 0:
		msg += " Pièces au-dessus de ton niveau laissées de côté."
	return msg


# --- annulation -------------------------------------------------------------------------------
static func remember_undo(label: String, cids: Array) -> void:
	var snap := {}
	for c in cids:
		var p := Profile._class_presets(String(c))
		var i := clampi(int(p.active), 0, p.sets.size() - 1)
		snap[String(c)] = {"index": i, "slots": (p.sets[i].slots as Dictionary).duplicate(), "auto": (p.sets[i].get("auto", {}) as Dictionary).duplicate()}
	_undo = {"label": label, "save": Profile.save_path, "presets": snap}


static func can_undo() -> bool:
	return not _undo.is_empty() and String(_undo.get("save", "")) == Profile.save_path


static func undo_label() -> String:
	return String(_undo.get("label", ""))


## Annule la dernière action (« Équiper le meilleur » ou « Appliquer à la famille ») ; renvoie le message.
static func undo() -> String:
	if not can_undo() or Profile.in_run:
		return ""
	Profile._sync_vault()
	var snap: Dictionary = _undo.presets
	for c in snap:
		var p := Profile._class_presets(String(c))
		var s: Dictionary = p.sets[clampi(int(snap[c].index), 0, p.sets.size() - 1)]
		var slots: Dictionary = s.slots
		slots.clear()
		slots.merge(snap[c].slots)
		s["auto"] = (snap[c].auto as Dictionary).duplicate()
	var label := undo_label()
	_undo = {}
	_after_write(snap.keys())
	return "Annulé : %s." % label.to_lower()


## Entrées du menu « Gérer » de l'écran Équipement pour la classe [param cid] : {label, call, tip}.
static func menu_actions(cid: String) -> Array:
	var prof := profile(cid)
	if prof.is_empty():
		return []
	var out: Array = [{"label": "Équiper le meilleur", "call": func(c): return equip_best(c, false),
		"tip": "Pour chaque emplacement, la meilleure pièce du coffre pour le profil %s. %s." % [prof.name, prof.desc]}]
	if not choice_slots(cid).is_empty():
		out.append({"label": "Équiper le meilleur, garder mes choix", "call": func(c): return equip_best(c, true),
			"tip": "Comme « Équiper le meilleur », sans toucher aux pièces que tu as posées toi-même."})
	var plan := family_plan(cid)
	var to: Array = plan.to
	if not to.is_empty():
		out.append({"label": "Appliquer à la famille %s · %s" % [prof.name, _plural(to.size(), "classe")], "call": func(c): return apply_family(c),
			"tip": "Copie ce préréglage vers : %s. Chacune garde une arme de son type." % ", ".join(to.map(func(t): return class_label(t)))})
	if can_undo():
		out.append({"label": "Annuler : %s" % undo_label().to_lower(), "call": func(_c): return undo(), "tip": "Remet les préréglages d'avant."})
	return out


# --- Registre de l'équipement ----------------------------------------------------------------
## Fiche d'une classe : {cid, profile, pe, expected, ratio, tier, weapon_ok, filled, base, arch, arch_name,
## spirits, plus10, gems, gem_max, enchants, status, need, activity, unlock}. [param by_uid] : vault_map.
static func entry(cid: String, by_uid: Dictionary = {}) -> Dictionary:
	var g := gear_of(cid, by_uid)
	var e := {"cid": cid, "profile": profile_id(cid), "pe": GearPower.gear_power(g), "expected": GearPower.expected(GearPower.target_level()),
		"over": over_level(cid, by_uid)}
	e["ratio"] = float(e.pe) / maxf(float(e.expected), 1.0)
	e["tier"] = String(GearPower.tier(float(e.ratio))[1])
	var w: Dictionary = g.get("weapon", {})
	var has_w := not w.is_empty() and fits(w, "weapon", cid)
	e["weapon_ok"] = has_w and not w.get("starter", false)
	e["weapon_state"] = "none" if not has_w else ("ok" if e.weapon_ok else "base")
	var filled := 0
	var base := 0
	var plus10 := 0
	var gems := 0
	var enchants := 0
	var spirits := 0
	var arch := {}
	for slot in Items.SLOTS:
		var it: Dictionary = g.get(slot, {})
		if it.is_empty():
			continue
		filled += 1
		if it.get("starter", false):
			base += 1
		if int(it.get("upgrade", 0)) >= Items.MAX_UPGRADE:
			plus10 += 1
		for so in it.get("sockets", []):
			if so is Dictionary:
				gems += 1
		if it.has("enchant"):
			enchants += 1
		if String(it.get("set", "")) == "pantheon":
			spirits += 1
		var a := String(it.get("archetype", ""))
		if a != "":
			arch[a] = int(arch.get(a, 0)) + 1
	var best_arch := ""
	for a in arch:
		if best_arch == "" or int(arch[a]) > int(arch[best_arch]):
			best_arch = String(a)
	e.merge({"filled": filled, "base": base, "plus10": plus10, "gems": gems, "gem_max": Items.SLOTS.size() * Craft.MAX_SOCKETS,
		"enchants": enchants, "spirits": spirits, "arch": int(arch.get(best_arch, 0)),
		"arch_name": String(Items.SETS.get(best_arch, {}).get("name", ""))})
	var slots := Items.SLOTS.size()
	var panoply := maxi(int(e.arch), spirits)
	var status := 0
	if filled == 0:
		status = 0
	elif not e.weapon_ok or filled < slots or base > 0:
		status = 1
	elif float(e.ratio) < EQUIPPED_RATIO:
		status = 2
	elif panoply < PANOPLY or plus10 < slots or gems < int(e.gem_max) or enchants < slots:
		status = 3
	else:
		status = 4
	e["status"] = status
	# ce qui manque d'abord, et l'activité qui le donne (A1 §5.3 : rôle de chaque activité)
	var wname := String(GameData.weapon_type(Items.default_weapon_type(cid)).get("name", "")).to_lower()
	var need := ["", "", ""]  # texte, activité, déblocage
	if filled == 0 and not Progression.class_unlocked(cid):
		need = ["la classe", Progression.mission_text(cid), ""]
	elif filled == 0 and not cid in Profile.starter_done:
		need = ["l'équipement de départ", "Héros : choisir la classe", ""]  # offert au premier choix de la classe
	elif not has_w:
		need = ["une arme (%s)" % wname, "Survie, puis Atelier", "armory"]
	elif filled < slots or base > 0:
		need = [_plural(slots - filled + base, "pièce") + " à trouver", "Survie, puis Atelier", "armory"]
	elif float(e.ratio) < EQUIPPED_RATIO and hero_capped(float(e.pe)):
		# lot GX-3 : l'équipement est déjà au niveau du héros ; les pièces plus hautes ne se porteraient pas
		need = ["du niveau de héros (tu es niveau %d)" % HeroLevel.level(), "Monte ton niveau de héros en Survie", ""]
	elif float(e.ratio) < EQUIPPED_RATIO:
		need = ["des pièces de plus haut niveau", "Survie, puis Atelier", "armory"]
	elif panoply < PANOPLY:
		need = (["la panoplie des Esprits (%d / %d)" % [spirits, PANOPLY], "Panthéon", "pantheon"] if spirits > int(e.arch)
			else ["une panoplie de donjon (%d / %d)" % [int(e.arch), PANOPLY], "Donjons", "dungeons"])
	elif plus10 < slots:
		need = [_plural(slots - plus10, "pièce") + " à monter à +10", "Forge", "forge"]
	elif gems < int(e.gem_max):
		need = ["des gemmes", "La Tour", "tower"]
	elif enchants < slots:
		need = ["des enchantements", "Le Siège", "siege"]
	e["need"] = need[0]
	e["activity"] = need[1]
	e["unlock"] = need[2]
	return e


## Lot GX-3 : la PE [param pe] est « correcte » pour le niveau de héros, mais pas pour le niveau de référence du Registre (le
## meilleur niveau atteint en partie) : ce qui manque, c'est le niveau de héros (les pièces plus hautes ne se portent pas).
static func hero_capped(pe: float) -> bool:
	var hl := HeroLevel.level()
	return hl < GearPower.target_level() and pe >= EQUIPPED_RATIO * float(GearPower.expected(hl))


## Fiches des 60 classes (ordre de data/classes.json).
static func entries() -> Array:
	var m := vault_map()
	var out: Array = []
	for cid in GameData.classes:
		out.append(entry(String(cid), m))
	return out


## Classes « équipées » (ou mieux) : [équipées, total].
static func equipped_count() -> Vector2i:
	var n := 0
	var all := entries()
	for e in all:
		if int(e.status) >= STATUS_EQUIPPED:
			n += 1
	return Vector2i(n, all.size())
