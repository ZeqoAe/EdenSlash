class_name SurvivorCards
extends RefCounted
## Cartes du Survivant (lot S3, SPEC §2 et §5, corrigé par DECISIONS_JOUEUR §2, §4 et §5 qui priment).
##
## Familles (une carte = une cible : emplacement, sort, arme ou évolution ; jamais deux cartes sur la même cible) :
## - équipement : Arme (« sv_weapon », tant qu'aucune n'est portée), Nouvelle pièce (« sv_piece », emplacement libre,
##   pièce de SurvivorPool, verrouillée à vie), Amélioration de pièce ou d'arme (« sv_piece_up » / « sv_weapon_up » : +2,
##   +4 en légendaire, jusqu'à +10 ; le passif du palier +6 / +8 / +10 est tiré QUAND la carte est proposée
##   (SurvivorGear.upgrade_offer) et écrit sur la carte ; une relance ou un bannissement en tirent un autre) ;
## - sort : Nouveau sort (« skill » puis « chain », types de Run : tout le kit de la classe, sans la maîtrise du compte,
##   6 sorts au plus) et Amélioration de sort (« upgrade » de Run, niveau 1 à 10, Cards.skill_upgrade) ;
## - Évolution (« sv_evolution » : évolution légendaire de Boons quand ses passifs sont portés) ;
## - repli (« sv_gold », « sv_heal », « sv_reroll ») : seulement s'il reste moins de 3 cartes valables.
## Plus aucune carte commune (Boons) : leurs effets sont les passifs des pièces (SurvivorGear).
##
## Tirage d'un choix (roll) : les cartes gardées d'abord, puis une carte d'équipement (une arme tant qu'aucune n'est
## portée), une carte de sort (un nouveau sort tant que le héros en a moins de 2, et moins de 3 au niveau 6), puis des
## cartes libres au poids (profil « survivor » de ModeRules : w_piece_new, w_piece_up, w_weapon_up, w_spell_new,
## w_spell_up, w_evolution ; pitié ×2 après pity_after choix sans apparaître), au plus 2 nouvelles pièces, les cartes
## mélangées. Premier choix de la run (first_offer) : seulement des armes (types différents) et des compétences, ni
## « Passer » ni carte de repli. Relances : base_rerolls (2) + statistique « rerolls » des passifs + cartes de repli ;
## bannir (3 par run) : un sort, un type d'arme, une panoplie (ou un modèle hors set), le passif d'une amélioration, une
## évolution ; garder : la carte revient telle quelle au choix suivant ; Passer : de l'or (skip_gold), jamais au 1er choix.

const FAMILY := {"sv_weapon": "equip", "sv_piece": "equip", "sv_piece_up": "equip", "sv_weapon_up": "equip",
	"skill": "spell", "chain": "spell", "upgrade": "spell", "sv_evolution": "evo", "sv_gold": "fallback",
	"sv_heal": "fallback", "sv_reroll": "fallback"}
const FALLBACK := ["sv_gold", "sv_heal", "sv_reroll"]
const NEW_PIECES_MAX := 2  # « Nouvelle pièce » au plus par choix : il reste toujours une autre option
const SPELL_NET := [[1, 2], [6, 3]]  # [niveau du héros, sorts] : en dessous, la carte de sort est un nouveau sort
## Rareté minimale de la carte qui mène un sort à ce niveau (deux moments forts par sort, SPEC §5).
const SPELL_TIER_AT := {5: "epic", 10: "legendary"}
## Jet de la pièce relevé par une amélioration rare ou mieux (chemin vers le jet parfait, 120 %).
const QUALITY_UP := {"common": 0.0, "rare": 0.03, "epic": 0.05, "legendary": 0.05}
const LEGEND_STEP := 4  # +N d'une amélioration légendaire (deux paliers d'un coup)
const EVO_GAP := 4  # une évolution possible et absente des 4 derniers choix prend la place de la carte libre
const HEAL_PART := 0.35  # carte de repli « Soin »
const HEAL_BELOW := 0.7  # proposée seulement sous 70 % des PV
const GOLD_CARD := [30, 6]  # carte de repli « Bourse » : base + par niveau

static var rng := RandomNumberGenerator.new()  # graine fixée par le simulateur et les tests
static var minutes_override := -1.0  # tests et simulateur : minutes de carte (sinon le chronomètre du directeur)
static var _seeded := false


## Les cartes du Survivant remplacent celles de la Survie (Run.roll_cards, ban_card, rerolls_left, CardPicker).
static func handles() -> bool:
	return true


## Un Survivant est en cours et ses cartes s'appliquent.
static func on() -> bool:
	return Survivor.active and handles()


static func _rng() -> RandomNumberGenerator:
	if not _seeded:
		rng.randomize()
		_seeded = true
	return rng


## Graine du tirage (simulateur, tests) ; 0 : au hasard.
static func seed_with(s: int) -> void:
	_seeded = true
	if s == 0:
		rng.randomize()
	else:
		rng.seed = s


## Minutes de carte écoulées (chance des raretés de carte).
static func minutes() -> float:
	if minutes_override >= 0.0:
		return minutes_override
	var tree := Engine.get_main_loop() as SceneTree
	var w: Node = tree.current_scene if tree else null
	if w != null and "director" in w and w.director != null:
		return float(w.director.time) / 60.0
	return 0.0


# --- état de la run (rangé dans Run : remis à zéro par Run.start) -----------------------------------------------------
static func bans_left() -> int:
	return maxi(0, int(Survivor.rule("bans")) - Run.bans_used)


static func rerolls_left() -> int:
	return maxi(0, int(Survivor.rule("base_rerolls")) + int(Run.passive_stats().get("rerolls", 0)) - Run.rerolls_used)


## Or donné par « Passer » (réglage skip_gold : 15 + 3 × niveau).
static func skip_gold() -> int:
	return roundi(Survivor.rule("skip_gold_base") + Survivor.rule("skip_gold_per_level") * Run.hero_level)


static func _banned(key: String) -> bool:
	return key in Run.banned


static func _banned_list(prefix: String) -> Array:
	return Run.banned.filter(func(b): return String(b).begins_with(prefix)).map(func(b): return String(b).trim_prefix(prefix))


# --- candidats ------------------------------------------------------------------------------------------------------------
## Sorts de la classe proposables : tout son kit (DECISIONS §5 : la maîtrise du compte n'ouvre rien ici), sans les
## sorts pris ni les sorts bannis.
static func spells_open() -> Array:
	var owned: Array = Run.all_skills().map(func(s): return int(s.id))
	return Run.class_data().get("skills", []).filter(func(s): return not int(s.id) in owned and not str(int(s.id)) in Run.banned)


## Évolutions possibles : légendaires de Boons dont tous les prérequis sont des passifs portés (puissance ≥ 1).
static func evolutions_open() -> Array:
	var out: Array = []
	for d in Boons.all():
		var req: Array = d.get("requires", [])
		if req.is_empty() or Run.passives.has(String(d.id)) or _banned("evo:" + String(d.id)):
			continue
		if req.all(func(r): return float(Run.passive_power.get(String(r), 0.0)) >= 1.0 - 0.001):
			out.append(String(d.id))
	return out


## Pièce dont la prochaine amélioration (+2) éveille un passif ?
static func wakes_next(item: Dictionary, step := Survivor.UP_STEP) -> bool:
	var from := int(item.get("upgrade", 0))
	return Survivor.WAKE_AT.any(func(at): return from < int(at) and int(at) <= from + step)


## Candidats d'un choix : {fam, kind, key, w, slot?, id?}. fam : equip, spell, evo.
static func candidates() -> Array:
	var out: Array = []
	var pity := int(Survivor.rule("pity_after"))
	var add := func(c: Dictionary) -> void:
		if int(Survivor.since.get(String(c.key), 0)) >= pity:
			c.w = float(c.w) * 2.0  # pitié : jamais proposé depuis pity_after choix
		if float(c.w) > 0.0:
			out.append(c)
	var weapon: Dictionary = Profile.equipped.get("weapon", {})
	if weapon.is_empty():
		add.call({"fam": "equip", "kind": "weapon", "key": "weapon", "w": Survivor.rule("w_weapon_up") * 2.0})
	elif int(weapon.get("upgrade", 0)) < Items.MAX_UPGRADE:
		add.call({"fam": "equip", "kind": "weapon_up", "key": "up:weapon", "slot": "weapon",
			"w": Survivor.rule("w_weapon_up") * (1.6 if wakes_next(weapon) else 1.0)})
	var affinity: bool = Items.set_counts(Profile.equipped).values().any(func(n): return int(n) >= 2)
	var set_slots := SurvivorPool.set_slots()
	for slot in SurvivorPool.slots():
		var it: Dictionary = Profile.equipped.get(slot, {})
		if it.is_empty():
			add.call({"fam": "equip", "kind": "piece", "key": "slot:" + slot, "slot": slot,
				"w": Survivor.rule("w_piece_new") * (1.5 if affinity and slot in set_slots else 1.0)})
		elif int(it.get("upgrade", 0)) < Items.MAX_UPGRADE:
			add.call({"fam": "equip", "kind": "piece_up", "key": "up:" + slot, "slot": slot,
				"w": Survivor.rule("w_piece_up") * (1.6 if wakes_next(it) else 1.0)})
	var owned := Run.all_skills()
	if owned.size() < Survivor.SPELL_MAX:
		var open := spells_open()
		var fam_w := Survivor.rule("w_spell_new") * (1.0 if owned.size() < 2 else (2.0 / 3.0 if owned.size() < Run.MAX_SKILLS else 1.0 / 3.0))
		for s in open:
			add.call({"fam": "spell", "kind": "spell_new", "key": "spell:%d" % int(s.id), "id": int(s.id), "w": fam_w / open.size()})
	for s in owned:
		if int(s.rank) < int(Cards.rules().max_rank):
			add.call({"fam": "spell", "kind": "spell_up", "key": "spup:%d" % int(s.id), "id": int(s.id), "w": Survivor.rule("w_spell_up")})
	for id in evolutions_open():
		add.call({"fam": "evo", "kind": "evo", "key": "evo:" + id, "id": id, "w": Survivor.rule("w_evolution")})
	return out


# --- tirage ---------------------------------------------------------------------------------------------------------------
## [param n] cartes d'un choix. [param kind] : "" (montée de niveau, coffre doré…), "spell" / "skill" (sorts seulement),
## "weapon" (arme seulement), "equip" (équipement seulement). [param luck] : chance de rareté en plus (coffres).
static func roll(n := 3, kind := "", luck := 0.0) -> Array:
	if kind == "skill":
		kind = "spell"
	if not kind in ["", "spell", "weapon", "equip"]:
		kind = ""
	if kind == "" and _no_start():
		return first_offer(n)  # rien pris encore (le choix de départ n'a pas eu lieu) : arme ou compétence
	return _build(n, kind, luck)


static func _no_start() -> bool:
	return Profile.equipped.get("weapon", {}).is_empty() and Run.all_skills().is_empty()


static func _build(n: int, kind: String, luck: float, exclude_keys: Array = [], track := true) -> Array:
	var cands := candidates()
	match kind:
		"spell":
			cands = cands.filter(func(c): return c.fam == "spell")
		"weapon":
			cands = cands.filter(func(c): return c.kind in ["weapon", "weapon_up"])
		"equip":
			cands = cands.filter(func(c): return c.fam == "equip")
	cands = cands.filter(func(c): return not String(c.key) in exclude_keys)
	var all_keys: Array = cands.map(func(c): return String(c.key))
	var out: Array = []
	var used := {}
	luck += Survivor.rule("luck_per_min") * minutes()
	# 1. cartes gardées au choix précédent (telles quelles : même pièce, même passif de palier)
	if kind == "" and track:
		for k in Run.kept:
			if out.size() < n and still_valid(k) and not used.has(String(k.get("sv_key", ""))):
				out.append(k)
				used[String(k.get("sv_key", ""))] = true
		Run.kept.clear()
	# 2. une carte d'équipement (une arme tant qu'aucune n'est portée)
	if not out.any(func(c): return FAMILY.get(String(c.type), "") == "equip"):
		var eq := cands.filter(func(c): return c.fam == "equip")
		if Profile.equipped.get("weapon", {}).is_empty() and eq.any(func(c): return c.kind == "weapon"):
			eq = eq.filter(func(c): return c.kind == "weapon")
		_take(eq, out, used, luck, n)
	# 3. une carte de sort (filet : un nouveau sort tant que le héros en a trop peu)
	if not out.any(func(c): return FAMILY.get(String(c.type), "") == "spell"):
		var sp := cands.filter(func(c): return c.fam == "spell")
		var news := sp.filter(func(c): return c.kind == "spell_new")
		for net in SPELL_NET:
			if Run.hero_level >= int(net[0]) and Run.all_skills().size() < int(net[1]) and not news.is_empty():
				sp = news
		_take(sp, out, used, luck, n)
	# 4. cartes libres : une évolution en attente d'abord, puis au poids
	while out.size() < n:
		var pool := cands.filter(func(c): return not used.has(String(c.key)) and not (c.kind == "piece" and _new_pieces(out) >= NEW_PIECES_MAX))
		if pool.is_empty():
			break
		var due := pool.filter(func(c): return c.kind == "evo" and int(Survivor.since.get(String(c.key), 0)) >= EVO_GAP)
		if not _take(due if not due.is_empty() else pool, out, used, luck, n):
			break
	# 5. jamais de choix vide ou incomplet : cartes de repli
	if out.size() < n and kind in ["", "equip", "weapon", "spell"]:
		for t in FALLBACK:
			if out.size() >= n:
				break
			if t == "sv_heal" and _hp_part() >= HEAL_BELOW:
				continue
			out.append(fallback_card(t))
	_shuffle(out)
	if track:
		_track(all_keys, out)
	return out


## Prend un candidat au poids dans [param pool] et l'ajoute à [param out] (sa carte) ; vrai si une carte a été ajoutée.
static func _take(pool: Array, out: Array, used: Dictionary, luck: float, n: int) -> bool:
	var p := pool.filter(func(c): return not used.has(String(c.key)) and not (c.kind == "piece" and _new_pieces(out) >= NEW_PIECES_MAX))
	while not p.is_empty() and out.size() < n:
		var c := _pick(p)
		p.erase(c)
		used[String(c.key)] = true
		var card := card_for(c, luck, out)
		if not card.is_empty():
			out.append(card)
			return true
	return false


static func _pick(pool: Array) -> Dictionary:
	var total := 0.0
	for c in pool:
		total += float(c.w)
	var r := _rng().randf() * total
	for c in pool:
		r -= float(c.w)
		if r <= 0.0:
			return c
	return pool[pool.size() - 1]


static func _new_pieces(cards: Array) -> int:
	return cards.filter(func(c): return String(c.get("type", "")) == "sv_piece").size()


static func _shuffle(a: Array) -> void:
	for i in range(a.size() - 1, 0, -1):
		var j := _rng().randi() % (i + 1)
		var t: Variant = a[i]
		a[i] = a[j]
		a[j] = t


## Pitié et évolutions : compteur de choix sans apparaître, par cible (Survivor.since).
static func _track(keys: Array, shown: Array) -> void:
	var seen: Array = shown.map(func(c): return String(c.get("sv_key", "")))
	for k in keys:
		Survivor.since[k] = 0 if k in seen else int(Survivor.since.get(k, 0)) + 1


static func _hp_part() -> float:
	var tree := Engine.get_main_loop() as SceneTree
	var p: Node = tree.get_first_node_in_group("player") if tree else null
	return float(p.hp) / maxf(float(p.max_hp), 1.0) if p != null and "hp" in p else 1.0


# --- rareté des cartes d'amélioration -------------------------------------------------------------------------------------
## Rareté tirée (commune, rare, épique, légendaire : poids de Cards.TIERS), [param luck] la décale vers le haut.
static func roll_tier(luck := 0.0) -> String:
	var total := 0.0
	var w := {}
	for id in Cards.TIER_ORDER:
		w[id] = float(Cards.tier(id).weight) * (1.0 + maxf(luck, 0.0) * Cards.TIER_ORDER.find(id))
		total += float(w[id])
	var r := _rng().randf() * total
	for id in Cards.TIER_ORDER:
		r -= float(w[id])
		if r <= 0.0:
			return id
	return "common"


static func at_least(tier: String, low: String) -> String:
	return tier if Cards.TIER_ORDER.find(tier) >= Cards.TIER_ORDER.find(low) else low


# --- cartes ---------------------------------------------------------------------------------------------------------------
## Carte du candidat [param c] ({} : rien à proposer). [param shown] : cartes déjà dans le choix (armes de types différents).
static func card_for(c: Dictionary, luck := 0.0, shown: Array = []) -> Dictionary:
	match String(c.kind):
		"weapon":
			return weapon_card(shown.filter(func(x): return x.has("wtype")).map(func(x): return String(x.wtype)))
		"piece":
			var ex: Array = shown.filter(func(x): return x.has("item")).map(func(x): return int(x.item.get("eden", 0)))
			return new_piece_card(String(c.slot), ex)
		"piece_up", "weapon_up":
			return up_card(String(c.slot), roll_tier(luck))
		"spell_new":
			return spell_card(int(c.id))
		"spell_up":
			return spell_up_card(int(c.id), roll_tier(luck))
		"evo":
			return evolution_card(String(c.id))
	return {}


## Arme d'un type tiré (type de la classe ×2, même nature de dégâts ×1,5, comme SurvivorGear.weapon_offers), hors
## [param exclude] et types bannis.
static func weapon_card(exclude: Array = []) -> Dictionary:
	var own := Items.default_weapon_type(Run.class_id)
	var dmg := String(GameData.weapon_type(own).get("dmg_type", "phys"))
	var banned := _banned_list("wtype:")
	var types: Array = SurvivorPool.weapon_types().filter(func(w): return not SurvivorPool.weapons(String(w)).is_empty() \
		and not String(w) in exclude and not String(w) in banned)
	if types.is_empty():
		return {}
	var pool: Array = types.map(func(w): return {"wt": String(w), "w": 2.0 if w == own else (1.5 if String(GameData.weapon_type(String(w)).get("dmg_type", "phys")) == dmg else 1.0)})
	var wt := String(_pick(pool).wt)
	var item := SurvivorGear.make_weapon(wt, {"rng": _rng()})
	if item.is_empty():
		return {}
	var c := RunDirector.item_card(item, "sv_weapon")
	var s := WeaponAttacks.spec_for(item)
	var lines: PackedStringArray = ["[color=#ffcf6b][b]%s[/b][/color] : %s" % [s.name, s.desc]]
	if s.has("sig"):
		lines.append("[color=#ffb347]★ %s (à +4)[/color]" % WeaponAttacks.sig_text(s))
	lines.append(_stats_line(item, 3))
	lines.append_array(_piece_tail(item))
	c.merge({"id": "weapon:" + wt, "sv_key": "weapon:" + wt, "slot": "weapon", "wtype": wt, "desc": "\n".join(lines),
		"subtitle": "%s · %s" % [String(GameData.weapon_type(wt).get("name", wt)), _rarity_name(item)]}, true)
	return c


## Statistiques principales d'une pièce sur une seule ligne (« +17 Force · +10 Agilité · +405 PV »).
static func _stats_line(item: Dictionary, n := 4) -> String:
	var parts: PackedStringArray = []
	var st := Items.stats(item)
	for k in st:
		if parts.size() >= n:
			break
		if absf(float(st[k])) > 0.0001:
			parts.append(Items.stat_text(String(k), st[k]))
	return " · ".join(parts)


## Nouvelle pièce pour l'emplacement libre [param slot] (hors modèles [param exclude], panoplies et modèles bannis).
static func new_piece_card(slot: String, exclude: Array = []) -> Dictionary:
	if not Profile.equipped.get(slot, {}).is_empty():
		return {}
	var item := SurvivorGear.make_piece(slot, _piece_ctx(exclude))
	return piece_card(item) if not item.is_empty() else {}


static func _piece_ctx(exclude: Array = []) -> Dictionary:
	var ex: Array = exclude.duplicate()
	for m in _banned_list("model:"):
		ex.append(int(m))
	return {"rng": _rng(), "banned": _banned_list("set:"), "exclude": ex}


## Carte d'une pièce : statistiques (4 au plus), panoplie (portées → avec elle / 5), passif fixe, jet, verrou.
static func piece_card(item: Dictionary) -> Dictionary:
	var slot := String(item.get("slot", ""))
	var lines: PackedStringArray = [_stats_line(item)]
	lines.append_array(_piece_tail(item))
	return {"type": "sv_piece", "id": String(item.get("uid", "")), "sv_key": "slot:" + slot, "slot": slot, "item": item,
		"title": Items.display_name(item), "subtitle": "%s · %s" % [Items.SLOT_NAMES.get(slot, slot), _rarity_name(item)],
		"desc": "\n".join(lines), "icon": String(item.get("icon", "")), "color": Items.color_of(item)}


## Lignes communes d'une pièce ou d'une arme : panoplie, passif fixe, jet, verrou.
static func _piece_tail(item: Dictionary) -> PackedStringArray:
	var out: PackedStringArray = []
	var sid := String(item.get("set", ""))
	if sid != "" and sid in SurvivorPool.sets():
		var n := int(Items.set_counts(Profile.equipped).get(sid, 0))
		out.append("[color=#66f28c]Set %s · %d / 5[/color]" % [SurvivorPool.panoply_name(sid), n + 1])
	for p in item.get("sv_passives", []):
		out.append("[color=#ffd36b]Passif : %s[/color]" % Cards.effect_line(String(p.id), float(p.get("power", 1.0))))
	var jet := ("[color=#ffd36b]★ Jet parfait[/color]" if SurvivorGear.is_perfect(item) else "Jet %d / %d" % [
		roundi(float(item.get("quality", 1.0)) * 100.0), roundi(Survivor.rule("perfect_quality") * 100.0)])
	out.append("[color=#9a98a8]%s · 🔒 %s[/color]" % [jet, SurvivorGear.LOCK_TEXT.to_lower()])
	return out


static func _rarity_name(item: Dictionary) -> String:
	return String(Items.RARITIES[clampi(int(item.get("rarity", 0)), 0, Items.RARITIES.size() - 1)].name)


## Amélioration de la pièce (ou de l'arme) de [param slot] à la rareté [param tier] : +2 (+4 en légendaire) ; le passif
## de chaque palier franchi est tiré maintenant (hors passifs bannis) et affiché. {} si la pièce est au maximum.
static func up_card(slot: String, tier: String) -> Dictionary:
	var item: Dictionary = Profile.equipped.get(slot, {})
	if item.is_empty() or int(item.get("upgrade", 0)) >= Items.MAX_UPGRADE:
		return {}
	var offer := SurvivorGear.upgrade_offer(slot, tier, _rng(), LEGEND_STEP if tier == "legendary" else Survivor.UP_STEP, _banned_list("passive:"))
	if offer.is_empty():
		return {}
	var lines: PackedStringArray = []
	lines.append("[color=#%s]%s[/color]" % [Items.color_of(item).to_html(false), Items.display_name(item)])
	for p in offer.passives:
		lines.append("[color=#ffd36b]Nouveau passif (+%d) : %s[/color]" % [int(p.at), Cards.effect_line(String(p.id), float(p.power))])
	if (offer.passives as Array).is_empty():
		var next: Array = Survivor.WAKE_AT.filter(func(at): return int(at) > int(offer.to))
		lines.append("[color=#9a98a8]%s[/color]" % ("Prochain passif à +%d" % int(next[0]) if not next.is_empty() else "Passifs au complet"))
	var after := item.duplicate(true)
	after["upgrade"] = int(offer.to)
	after["quality"] = minf(float(item.get("quality", 1.0)) + float(QUALITY_UP.get(tier, 0.0)), Survivor.rule("perfect_quality"))
	var a := Items.stats(item)
	var b := Items.stats(after)
	var shown := 0
	for k in a:
		if shown >= 2 or absf(float(a[k])) < 0.0001 or String(k) in Items.PERCENT_STATS:
			continue
		lines.append("%s : %d → [b]%d[/b]" % [Items.STAT_NAMES.get(k, k), roundi(float(a[k])), roundi(float(b.get(k, a[k])))])
		shown += 1
	if float(after.quality) > float(item.get("quality", 1.0)) + 0.0001:
		lines.append("Jet : %d → [b]%d[/b] / %d" % [roundi(float(item.get("quality", 1.0)) * 100.0), roundi(float(after.quality) * 100.0), roundi(Survivor.rule("perfect_quality") * 100.0)])
	if slot == "weapon" and offer.has("auto"):
		var cur: Dictionary = Run.weapon_ups.get("weapon", {})
		lines.append_array(WeaponAttacks.upgrade_lines(WeaponAttacks.spec_for(item), cur, offer.auto))
	return {"type": String(offer.type), "id": "up:" + slot, "sv_key": "up:" + slot, "slot": slot, "tier": tier, "offer": offer,
		"title": "%s +%d → +%d" % [Items.SLOT_NAMES.get(slot, slot), int(offer.from), int(offer.to)],
		"subtitle": "Amélioration %s" % String(Cards.tier(tier).name).to_lower(),
		"desc": "\n".join(lines), "icon": String(item.get("icon", ""))}


## Nouveau sort [param id] : case libre (« skill »), sinon enchaînement (« chain ») ; {} si plus de place.
static func spell_card(id: int) -> Dictionary:
	if Run.all_skills().size() >= Survivor.SPELL_MAX or Run.skill_def(id).is_empty():
		return {}
	var c: Dictionary
	if Run.skills.size() < Run.MAX_SKILLS:
		c = Run._describe_card({"type": "skill", "id": id})
	else:
		var room: Array = range(Run.skills.size()).filter(func(i): return Run.chain_of(i).size() < Run.MAX_CHAIN)
		if room.is_empty():
			return {}
		c = Run._describe_card({"type": "chain", "id": id, "slot": Run._chain_slot_for(id, room)})
	c["sv_key"] = "spell:%d" % id
	return c


## Amélioration du sort [param id] (niveau + 1) : l'effet de la carte (Cards.skill_upgrade : dégâts, soins ou durée,
## recharge, facettes selon la rareté, bonus d'attribut dès rare) s'ajoute à l'entrée du sort. Le niveau 5 est au
## moins épique, le niveau 10 légendaire.
static func spell_up_card(id: int, tier: String) -> Dictionary:
	var rank := Run.skill_rank(id)
	if rank <= 0 or rank >= int(Cards.rules().max_rank):
		return {}
	tier = at_least(tier, String(SPELL_TIER_AT.get(rank + 1, "common")))
	var c := Run._describe_card({"type": "upgrade", "id": id, "tier": tier})
	c["title"] = String(Run.skill_def(id).get("name", c.title))
	c["subtitle"] = "Niv. %d → %d · Amélioration %s" % [rank, rank + 1, String(Cards.tier(tier).name).to_lower()]
	c["sv_key"] = "spup:%d" % id
	c["rank_to"] = rank + 1
	return c


static func evolution_card(id: String) -> Dictionary:
	var d := Boons.get_def(id)
	if d.is_empty():
		return {}
	var req: Array = (d.get("requires", []) as Array).map(func(r): return String(Boons.get_def(String(r)).get("name", r)))
	return {"type": "sv_evolution", "id": id, "sv_key": "evo:" + id, "tier": "legendary", "title": String(d.name),
		"subtitle": "Évolution légendaire", "desc": "%s\n[color=#9a98a8]Grâce à : %s[/color]" % [String(d.get("desc", "")), ", ".join(PackedStringArray(req))],
		"icon": String(d.get("icon", Boons.ICONS.get(id, "")))}


static func fallback_card(t: String) -> Dictionary:
	match t:
		"sv_gold":
			return {"type": t, "id": t, "sv_key": "fb:" + t, "title": "Bourse", "subtitle": "Repli",
				"desc": "+%d or" % (GOLD_CARD[0] + GOLD_CARD[1] * Run.hero_level), "icon": "res://assets/ui/skills/j616.png"}
		"sv_heal":
			return {"type": t, "id": t, "sv_key": "fb:" + t, "title": "Soin", "subtitle": "Repli",
				"desc": "Rend un tiers de tes PV.", "icon": "res://assets/ui/status/regen.png"}
	return {"type": "sv_reroll", "id": "sv_reroll", "sv_key": "fb:sv_reroll", "title": "Bonne fortune", "subtitle": "Repli",
		"desc": "+1 relance pour la run.", "icon": "res://assets/ui/status/flow.png"}


# --- premier choix -----------------------------------------------------------------------------------------------------------
## Premier choix de la run (DECISIONS §4) : seulement des armes (types tous différents) et des compétences de la classe,
## au moins une de chaque ; ni « Passer » ni carte de repli (marque « sv_first »).
static func first_offer(n := 3) -> Array:
	var spells := spells_open()
	var weapons_n := n  # 1 à n - 1 armes, le reste en compétences (une seule carte : l'une ou l'autre)
	if not spells.is_empty():
		weapons_n = (1 + _rng().randi() % (n - 1)) if n >= 2 else _rng().randi() % 2
	var out: Array = []
	var types: Array = []
	for i in weapons_n:
		var w := weapon_card(types)
		if w.is_empty():
			break
		types.append(String(w.wtype))
		out.append(w)
	_shuffle(spells)
	for s in spells:
		if out.size() >= n:
			break
		var c := spell_card(int(s.id))
		if not c.is_empty():
			out.append(c)
	while out.size() < n:  # (classe sans assez de sorts : des armes de plus)
		var w := weapon_card(types)
		if w.is_empty():
			break
		types.append(String(w.wtype))
		out.append(w)
	for c in out:
		c["sv_first"] = true
	_shuffle(out)
	return out


## Choix de départ (le jeu attend en pause) : une arme ou une compétence, obligatoire ; deux relances.
static func start_offers(world: Node) -> void:
	world._offer("Choisis ton arme ou ta première compétence", first_offer(), func(): return first_offer())


# --- coffres -------------------------------------------------------------------------------------------------------------------
## Cartes d'un coffre du Survivant (SurvivorDirector.BOXES, gardien, enclume).
static func chest_cards(box: String) -> Array:
	if not Survivor.active:
		return []
	var out: Array = []
	var weapon: Dictionary = Profile.equipped.get("weapon", {})
	match box:
		"sv_weapon":
			if weapon.is_empty():
				var types: Array = []
				for i in 3:
					var w := weapon_card(types)
					if not w.is_empty():
						types.append(String(w.wtype))
						out.append(w)
			elif int(weapon.get("upgrade", 0)) < Items.MAX_UPGRADE:
				var tiers: Array = []  # 3 raretés différentes
				for i in 12:
					var t := roll_tier(0.3)
					if not t in tiers:
						tiers.append(t)
					if tiers.size() >= 3:
						break
				tiers.sort_custom(func(a, b): return Cards.TIER_ORDER.find(a) < Cards.TIER_ORDER.find(b))
				for t in tiers:
					var c := up_card("weapon", String(t))
					if not c.is_empty():
						c["sv_key"] = "up:weapon:" + String(t)
						out.append(c)
		"sv_spell":
			out = _build(3, "spell", 0.3)
			out = out.filter(func(c): return FAMILY.get(String(c.type), "") != "fallback")
		"sv_gold":
			out = _build(3, "", 0.6)
		"sv_guardian":
			var free := SurvivorGear.free_slots().filter(func(s): return s != "weapon" and s in SurvivorPool.slots())
			_shuffle(free)
			for s in free.slice(0, 3):
				var c := new_piece_card(String(s))
				if not c.is_empty():
					out.append(c)
			if out.is_empty():
				for s in _worn_upgradable():
					if out.size() >= 3:
						break
					var c := up_card(String(s), "legendary")
					if not c.is_empty():
						out.append(c)
		"sv_anvil":
			var worn := _worn_upgradable()
			worn.sort_custom(func(a, b): return _to_wake(a) < _to_wake(b))
			for s in worn.slice(0, 3):
				var c := up_card(String(s), "common")
				if not c.is_empty():
					out.append(c)
			for c in out:
				c["sv_chest"] = box
			return out  # (vide : l'enclume n'a rien à renforcer)
		_:
			var slot := box.trim_prefix("sv_")
			if not slot in Items.SLOTS:
				return []
			if Profile.equipped.get(slot, {}).is_empty():
				for e in SurvivorPool.draw_many(slot, 3, _rng(), SurvivorPool.context(_piece_ctx())):
					out.append(piece_card(SurvivorGear.from_eden(e, _rng())))
			else:
				var first := up_card(slot, at_least(roll_tier(0.3), "common"))
				if not first.is_empty():
					out.append(first)
				for s in _worn_upgradable():
					if out.size() >= 3:
						break
					if String(s) != slot:
						var c := up_card(String(s), roll_tier(0.3))
						if not c.is_empty():
							out.append(c)
	if out.size() < 3:
		var keys: Array = out.map(func(c): return String(c.get("sv_key", "")))
		out.append_array(_build(3 - out.size(), "", 0.0, keys, false))
	for c in out:
		c["sv_chest"] = box
	return out


static func _worn_upgradable() -> Array:
	return Items.SLOTS.filter(func(s): return not Profile.equipped.get(s, {}).is_empty() and int(Profile.equipped[s].get("upgrade", 0)) < Items.MAX_UPGRADE)


## Améliorations (+2) qu'il manque à la pièce de [param slot] pour son prochain passif.
static func _to_wake(slot: String) -> int:
	var up := int(Profile.equipped.get(slot, {}).get("upgrade", 0))
	for at in Survivor.WAKE_AT:
		if up < int(at):
			return int(at) - up
	return 99


# --- appliquer, garder, bannir, passer -------------------------------------------------------------------------------------
## Applique une carte « sv_… » (Survivor.owns ; les sorts passent par Run.apply_card).
static func apply(card: Dictionary) -> void:
	var t := String(card.get("type", ""))
	Survivor.picks[t] = int(Survivor.picks.get(t, 0)) + 1
	match t:
		"sv_weapon", "sv_piece":
			SurvivorGear.equip(card.item)
		"sv_piece_up", "sv_weapon_up":
			var res := SurvivorGear.apply_upgrade(card.offer)
			var item: Dictionary = Profile.equipped.get(String(card.slot), {})
			if String(res.text) != "" and not item.is_empty():
				item["quality"] = minf(float(item.get("quality", 1.0)) + float(QUALITY_UP.get(String(card.get("tier", "common")), 0.0)), Survivor.rule("perfect_quality"))
				Profile.changed.emit()
		"sv_evolution":
			Run.passives[String(card.id)] = 1
			Run.passive_power[String(card.id)] = 1.0
		"sv_gold":
			Run.add_gold(GOLD_CARD[0] + GOLD_CARD[1] * Run.hero_level, "cartes")
		"sv_heal":
			var tree := Engine.get_main_loop() as SceneTree
			var p: Node = tree.get_first_node_in_group("player") if tree else null
			if p != null and p.has_method("heal"):
				p.heal(float(p.max_hp) * HEAL_PART)
		"sv_reroll":
			Run.rerolls_used -= 1


## La carte gardée [param c] peut-elle encore être proposée telle quelle ?
static func still_valid(c: Dictionary) -> bool:
	match String(c.get("type", "")):
		"sv_weapon":
			return Profile.equipped.get("weapon", {}).is_empty()
		"sv_piece":
			return Profile.equipped.get(String(c.slot), {}).is_empty()
		"sv_piece_up", "sv_weapon_up":
			return SurvivorGear.offer_valid(c.offer)
		"skill", "chain":
			return Run.skill_entry(int(c.id)).is_empty() and Run.all_skills().size() < Survivor.SPELL_MAX \
				and (String(c.type) == "chain" or Run.skills.size() < Run.MAX_SKILLS)
		"upgrade":
			return Run.skill_rank(int(c.id)) + 1 == int(c.get("rank_to", -1))
		"sv_evolution":
			return not Run.passives.has(String(c.id))
	return false


## Garde la carte pour le prochain choix (telle quelle : même pièce, même passif de palier).
static func keep(card: Dictionary) -> bool:
	var t := String(card.get("type", ""))
	if Run.locks_used >= Cards.LOCKS_PER_RUN or t in FALLBACK or not FAMILY.has(t):
		return false
	if Run.kept.any(func(k): return String(k.type) == t and str(k.id) == str(card.id)):
		return false
	Run.locks_used += 1
	var k := card.duplicate(true)
	k.erase("sv_first")
	k.erase("sv_chest")
	Run.kept.append(k)
	return true


## Bannissable ? Un sort, une arme (son type), une pièce (sa panoplie, ou son modèle hors set), le passif de palier
## d'une amélioration, une évolution. Ni l'amélioration de sort ni les cartes de repli.
static func can_ban(card: Dictionary) -> bool:
	if bans_left() <= 0:
		return false
	match String(card.get("type", "")):
		"skill", "chain", "sv_weapon", "sv_piece", "sv_evolution":
			return true
		"sv_piece_up", "sv_weapon_up":
			return not (card.get("offer", {}).get("passives", []) as Array).is_empty()
	return false


## Libellé du bouton « Bannir » de la carte.
static func ban_label(card: Dictionary) -> String:
	match String(card.get("type", "")):
		"sv_piece":
			return "Bannir le set" if String(card.item.get("set", "")) != "" else "Bannir"
		"sv_piece_up", "sv_weapon_up":
			return "Bannir ce passif"
	return "Bannir"


## Infobulle du bouton « Bannir ».
static func ban_tip(card: Dictionary) -> String:
	match String(card.get("type", "")):
		"sv_piece":
			return "Les pièces de ce set ne seront plus proposées pendant la run." if String(card.item.get("set", "")) != "" \
				else "Cette pièce ne sera plus proposée pendant la run."
		"sv_weapon":
			return "Ce type d'arme ne sera plus proposé pendant la run."
		"sv_piece_up", "sv_weapon_up":
			return "Ce passif ne sera plus proposé pendant la run ; l'amélioration en tire un autre."
	return "Cette carte ne sera plus proposée pendant la run ; une autre la remplace."


## Bannit [param card] ; renvoie la carte de remplacement ({} : aucune).
static func ban(card: Dictionary, shown: Array) -> Dictionary:
	if not can_ban(card):
		return {}
	Run.bans_used += 1
	Survivor.bans_used = Run.bans_used
	var t := String(card.type)
	match t:
		"skill", "chain":
			Run.banned.append(str(card.id))
		"sv_weapon":
			Run.banned.append("wtype:" + String(card.wtype))
		"sv_piece":
			var sid := String(card.item.get("set", ""))
			Run.banned.append(("set:" + sid) if sid != "" else ("model:%d" % int(card.item.get("eden", 0))))
		"sv_piece_up", "sv_weapon_up":
			for p in card.offer.passives:
				Run.banned.append("passive:" + String(p.id))
		"sv_evolution":
			Run.banned.append("evo:" + String(card.id))
	var others: Array = shown.filter(func(c): return not is_same(c, card))
	var keys: Array = others.map(func(c): return String(c.get("sv_key", "")))
	# remplaçant : même cible quand elle reste possible (amélioration : un autre passif ; coffre d'emplacement : une
	# autre pièce), sinon une carte d'une autre cible (premier choix : une arme ou une compétence)
	if t in ["sv_piece_up", "sv_weapon_up"]:
		var rep := up_card(String(card.slot), String(card.get("tier", "common")))
		if not rep.is_empty():
			rep["sv_key"] = String(card.get("sv_key", rep.sv_key))
			return _carry(card, rep)
	if t == "sv_piece" and card.has("sv_chest"):
		var ex: Array = others.filter(func(c): return c.has("item")).map(func(c): return int(c.item.get("eden", 0)))
		var rep2 := new_piece_card(String(card.slot), ex)
		if not rep2.is_empty():
			return _carry(card, rep2)
	if card.get("sv_first", false):
		for i in 20:
			var cand := first_offer(1)
			if not cand.is_empty() and not String(cand[0].sv_key) in keys:
				return cand[0]
		return {}
	var cand2 := _build(1, "", 0.0, keys, false)
	if not cand2.is_empty() and FAMILY.get(String(cand2[0].type), "") != "fallback":
		return _carry(card, cand2[0])
	return {}


static func _carry(from: Dictionary, to: Dictionary) -> Dictionary:
	for k in ["sv_chest", "sv_first"]:
		if from.has(k):
			to[k] = from[k]
	return to


## « Passer » proposé ? Toujours, sauf au premier choix de la run (obligatoire).
static func can_skip(cards: Array) -> bool:
	return on() and not cards.is_empty() and not cards.any(func(c): return bool(c.get("sv_first", false)))


## « Passer » : aucune carte prise, de l'or à la place.
static func skip() -> int:
	var g := skip_gold()
	Run.add_gold(g, "passer")
	Survivor.picks["skip"] = int(Survivor.picks.get("skip", 0)) + 1
	return g


# --- choix automatique ----------------------------------------------------------------------------------------------------------
## Choix du pilote et de l'aide « Bot » (règle simple, SPEC §8.6) : l'arme ; un nouveau sort tant que le héros en a
## moins de 4 ; une évolution ; une amélioration qui éveille un passif ; l'amélioration d'arme ; une nouvelle pièce (de
## la panoplie déjà portée d'abord) ; une amélioration de sort ; le reste ; le repli en dernier.
## [param random] : un peu de hasard (pilote --autoplay, simulateur : des builds variés).
static func auto_pick(options: Array, random := false) -> Dictionary:
	if options.is_empty():
		return {}
	var best: Dictionary = options[0]
	var best_s := -INF
	for o in options:
		var s := score(o) + (_rng().randf() * 25.0 if random else 0.0)
		if s > best_s:
			best_s = s
			best = o
	return best


static func score(o: Dictionary) -> float:
	var tier := float(Cards.TIER_ORDER.find(String(o.get("tier", "common"))))
	match String(o.get("type", "")):
		"sv_weapon":
			return 100.0 + (5.0 if String(o.get("wtype", "")) == Items.default_weapon_type(Run.class_id) else 0.0)
		"skill", "chain":
			return 90.0 if Run.all_skills().size() < Run.MAX_SKILLS else 45.0
		"sv_evolution":
			return 85.0
		"sv_piece_up", "sv_weapon_up":
			var woke := not (o.get("offer", {}).get("passives", []) as Array).is_empty()
			return (70.0 if woke else (58.0 if String(o.type) == "sv_weapon_up" else 42.0)) + tier * 2.0
		"sv_piece":
			var sid := String(o.item.get("set", ""))
			var own := int(Items.set_counts(Profile.equipped).get(sid, 0)) if sid != "" else 0
			return 52.0 + own * 6.0 + float(o.item.get("quality", 1.0)) * 5.0
		"upgrade":
			return 48.0 + tier * 3.0
		"sv_heal":
			return 30.0 if _hp_part() < 0.5 else 8.0
		"sv_reroll":
			return 12.0
		"sv_gold":
			return 10.0
	return 20.0
