class_name ColiseeAnvil
extends RefCounted
## Le Colisée, lot CO-F (conception/benchmark/R_CO_F.md ; ARENA.md § 6.5, § 6.7) : l'ÉCONOMIE DE PARTIE (scellée) — or de
## manche, enclumes (une option parmi trois), revente, sorts gagnés aux manches 3 et 6 — et le déroulé de la préparation
## de chaque héros (offres, choix de l'IA, choix automatique du joueur au temps écoulé).
##
## Or (INCOME) : 10 par manche, +3 si victoire, +2 par K.O. (3 au plus), atouts Tirelire et Mise ; rien à épargner (pas
## d'intérêts) : l'or sert à construire.
## Enclumes (ANVILS) : on paie pour ouvrir, on garde UNE des trois options. Stat (bonus tirés selon le profil de la
## classe, ClassGear), Pièce (code de butin du Battle royale, RoyaleLoot : un emplacement vide d'abord, sinon une
## amélioration), Panoplie (pièces d'une panoplie de niveau 90 du Survivant que tu portes déjà, SurvivorPool), Éclat
## (offerte à la manche 9 : pièces légendaires de ta classe). Arme : celle de la classe, jamais proposée (comme au Battle royale).
## Revente (sell) : au prix payé pendant la préparation où la pièce a été prise, à moitié ensuite ; un bonus de stat
## s'annule (remboursé) tant que la préparation dure.
## Sorts (SPELL_ROUNDS) : une place de plus aux manches 3 et 6 (Éclair : 2 et 4), un sort parmi trois de la classe ; le
## joueur l'a en enchaînement d'une de ses quatre touches (Run.chains), un héros scripté l'ajoute à ses sorts.
##
## Interface du chef d'équipe (lot CO-D, ai/ et core/colisee_coach* : hors de ce lot) : poser [member coach] = un objet qui a
## choose_augment(offres, construction, ctx) -> indice, choose_anvil(options, construction, ctx) -> indice et, au besoin,
## choose_spell(ids, construction, ctx) -> indice et shop(construction, partie) (ses achats) ; sinon les choix notés de ce
## fichier et de ColiseeAugments (score, choose_augment, choose_anvil, choose_spell) sont utilisés.

const ANVILS := {
	"stat": {"name": "Enclume de stat", "price": 6, "ico": "res_level", "text": "Trois bonus de stat : tu en gardes un."},
	"piece": {"name": "Enclume de pièce", "price": 12, "ico": "res_piece", "text": "Trois pièces : tu en gardes une."},
	"panoplie": {"name": "Enclume de panoplie", "price": 20, "ico": "res_panoply", "text": "Trois pièces d'une panoplie."},
	"eclat": {"name": "Enclume d'éclat", "price": 0, "ico": "rar_5", "text": "Trois pièces légendaires de ta classe.", "gift_only": true},
}
const ANVIL_ORDER := ["stat", "piece", "panoplie"]
## Bonus des enclumes de stat : valeur d'un bonus, plafond cumulé, poids du profil de classe lu (ClassGear weights).
const STATS := {
	"hp_pct": {"name": "PV", "value": 0.06, "cap": 0.36, "ico": "heart", "w": "hp_pct", "tip": "+6 % de PV max."},
	"dmg_pct": {"name": "Attaque", "value": 0.05, "cap": 0.3, "ico": "swords", "w": "dmg_pct", "tip": "+5 % de dégâts."},
	"atk_speed": {"name": "Vitesse d'attaque", "value": 0.08, "cap": 0.4, "ico": "st_swift", "w": "atk_speed", "tip": "+8 % de vitesse d'attaque."},
	"cdr": {"name": "Recharge", "value": 0.05, "cap": 0.15, "ico": "hourglass", "w": "cdr", "tip": "−5 % de recharge des sorts."},
	"crit": {"name": "Critique", "value": 0.04, "cap": 0.2, "ico": "spark", "w": "crit", "tip": "+4 % de chances de critique."},
	"def_pct": {"name": "Défense", "value": 0.1, "cap": 0.6, "ico": "slot_chest", "w": "def_pct", "tip": "+10 % de défense."},
}
const INCOME := {"base": 10, "win": 3, "ko": 2, "ko_max": 3}
## Enclumes offertes : manche -> type.
const GIFTS := {"classique": {3: "panoplie", 9: "eclat"}, "eclair": {2: "panoplie", 5: "eclat"}, "grand": {3: "panoplie", 9: "eclat"}}
const SPELL_ROUNDS := {"classique": [3, 6], "eclair": [2, 4], "grand": [3, 6]}
## Revente après la préparation de l'achat : part du prix payé.
const RESELL_LATER := 0.5
## Emplacements des enclumes (l'arme de la classe reste : jamais proposée).
const SLOTS := ["head", "chest", "legs", "gloves", "boots", "back", "necklace", "ring"]
## Qualité de coffre du Battle royale (Royale.CHEST_TIERS) d'une enclume de pièce : argent, puis or dès la manche PIECE_GOLD_FROM.
const PIECE_TIER := 1
const PIECE_GOLD_FROM := 6
const ECLAT_TIER := 3

## Chef d'équipe du lot CO-D (voir l'en-tête) ; null : les choix notés de ce lot.
static var coach: Object = null


# --- partie ------------------------------------------------------------------------------------------------------------------

## Constructions de la partie [param g] (Colisee) ; le joueur porte ses pièces dans Profile.equipped (même dictionnaire) et
## part avec 4 sorts (les enchaînements du préréglage sont retirés : places gagnées aux manches 3 et 6).
static func setup(g: Object) -> Array:
	var all := ColiseeBuild.setup(g)
	var pb := ColiseeBuild.player_build(g)
	if pb != null and pb.is_player:
		pb.gear = Profile.equipped
		Run.chains = {}
		Run.changed.emit()
	return all


static func rng_of(g: Object) -> RandomNumberGenerator:
	var r = g.get("rng") if g != null else null
	return r if r is RandomNumberGenerator else RandomNumberGenerator.new()


## Début de la préparation de la manche en cours de [param g] (après Colisee.next_round) : or, atouts, enclumes offertes,
## sorts ; les IA (et le joueur au pilote automatique : [param auto_player]) décident tout de suite.
static func round_start(g: Object, auto_player := false) -> void:
	var r := int(g.get("round_n"))
	var fmt := String(g.get("format"))
	var out: Array = g.get("out")
	var rng := rng_of(g)
	var last: Dictionary = (g.get("history") as Array)[-1] if not (g.get("history") as Array).is_empty() else {}
	for row in ColiseeBuild.all_of(g):
		for b in row:
			var bb := b as ColiseeBuild
			if bb.team < out.size() and bool(out[bb.team]):
				continue
			_pay_round(bb, r, last)
			bb.ready = false
			bb.stat_buys = []
			var rar := ColiseeAugments.offer_rarity(fmt, r, rng)
			if rar != "" and bb.augments.size() < ColiseeAugments.MAX_HELD:
				bb.offer_rarity = rar
				bb.offer = ColiseeAugments.make_offer(bb, rar, ColiseeAugments.context_for(g, bb), rng)
			var gift := String(GIFTS.get(fmt, GIFTS.classique).get(r, ""))
			if gift != "":
				bb.gifts.append(gift)
			if r in SPELL_ROUNDS.get(fmt, SPELL_ROUNDS.classique):
				bb.spell_slots += 1
				open_spells(bb)
	for row in ColiseeBuild.all_of(g):
		for b in row:
			var bb := b as ColiseeBuild
			if (bb.team < out.size() and bool(out[bb.team])) or (bb.is_player and not auto_player):
				continue
			ai_prep(bb, g)


## Or de la manche [param r] pour [param b] d'après la manche d'avant [param last] (Colisee.history) : base, victoire, K.O.,
## Tirelire, Mise ; manche 1 : la base seule.
static func _pay_round(b: ColiseeBuild, r: int, last: Dictionary) -> void:
	var won := false
	var played := false
	for res in last.get("results", []):
		if int(res.a) == b.team or int(res.b) == b.team:
			played = true
			var w := int(res.get("winner", -1))
			if w < 0:
				w = Colisee.tie_winner(float(res.get("left_a", 0.0)), float(res.get("left_b", 0.0)), int(res.a), int(res.b))
			won = w == b.team
	var line := income(b, r, won, played)
	b.gold += int(line.total)
	b.gold_total += int(line.total)
	b.gold_log.append(line)
	b.round_kos = 0


## Détail de l'or de la manche : {round, base, win, ko, extra, total}.
static func income(b: ColiseeBuild, r: int, won: bool, played: bool) -> Dictionary:
	var base := int(INCOME.base)
	var win := 0
	var ko := 0
	var extra := 0
	if r > 1 and played:
		if won:
			win = int(INCOME.win)
		ko = int(INCOME.ko) * mini(b.round_kos, int(INCOME.ko_max))
		if b.has("mise"):
			if won:
				win += int(ColiseeAugments.p("mise", "win_gold", 15))
			else:
				base = 0
	if b.has("tirelire"):
		extra += int(ColiseeAugments.p("tirelire", "gold", 4))
	return {"round": r, "base": base, "win": win, "ko": ko, "extra": extra, "total": base + win + ko + extra}


# --- enclumes ------------------------------------------------------------------------------------------------------------------

static func price(kind: String) -> int:
	return int(ANVILS.get(kind, {}).get("price", 0))


## Ouvre l'enclume [param kind] de [param b] (payée, sauf [param gift]) : trois options à choisir (b.anvil). Faux : pas
## assez d'or, une enclume déjà ouverte, ou rien à proposer.
static func open_anvil(b: ColiseeBuild, kind: String, g: Object = null, gift := false) -> bool:
	if not b.anvil.is_empty() or not ANVILS.has(kind):
		return false
	if bool(ANVILS[kind].get("gift_only", false)) and not gift:
		return false
	var cost := 0 if gift else price(kind)
	if b.gold < cost:
		return false
	var opts := options(b, kind, int(g.get("round_n")) if g != null else 1, rng_of(g))
	if opts.is_empty():
		return false
	b.gold -= cost
	b.anvil = {"kind": kind, "price": cost, "gift": gift, "options": opts}
	if gift:
		b.gifts.erase(kind)
	return true


## Les trois options d'une enclume : stat {kind: "stat", key, value} ; pièce {kind: "piece", slot, item, gain, replace}.
static func options(b: ColiseeBuild, kind: String, r: int, rng: RandomNumberGenerator, n := 3) -> Array:
	match kind:
		"stat":
			return _stat_options(b, rng, n)
		"piece":
			return _piece_options(b, PIECE_TIER + (1 if r >= PIECE_GOLD_FROM else 0), rng, n)
		"panoplie":
			return _set_options(b, rng, n)
		"eclat":
			return _eclat_options(b, rng, n)
	return []


static func _stat_options(b: ColiseeBuild, rng: RandomNumberGenerator, n: int) -> Array:
	var w: Dictionary = ClassGear.profile(b.cid).get("weights", {})
	var cands: Array = []
	for k in STATS:
		if float(b.stats.get(k, 0.0)) + float(STATS[k].value) > float(STATS[k].cap) + 0.001:
			continue
		cands.append([float(w.get(String(STATS[k].w), 1.0)) * rng.randf_range(0.6, 1.4), k])
	cands.sort()
	cands.reverse()
	var out: Array = []
	for e in cands.slice(0, n):
		var k := String(e[1])
		out.append({"kind": "stat", "key": k, "value": float(STATS[k].value), "gain": float(w.get(String(STATS[k].w), 1.0))})
	return out


static func _rate(it: Dictionary, b: ColiseeBuild) -> float:
	return RoyaleLoot.rate(it, ClassGear.profile(b.cid), Colisee.LEVEL)


## Pièces du Battle royale (RoyaleLoot) : un emplacement vide d'abord, sinon une pièce nettement meilleure ou une amélioration
## (mise à niveau, rareté, forge) des pièces portées. Jamais d'arme.
static func _piece_options(b: ColiseeBuild, tier: int, rng: RandomNumberGenerator, n: int) -> Array:
	tier = clampi(tier, 0, Royale.CHEST_TIERS.size() - 1)
	var def: Dictionary = Royale.CHEST_TIERS[tier]
	var lv := Colisee.LEVEL
	var out: Array = []
	var empty: Array = SLOTS.filter(func(s): return not b.gear.has(s) or (b.gear[s] as Dictionary).is_empty())
	_shuffle(empty, rng)
	var was := Run.hero_level
	Run.hero_level = lv
	for s in empty:
		if out.size() >= n:
			break
		var it := RoyaleLoot._piece(def, lv, b.cid, String(s))
		out.append({"kind": "piece", "slot": String(s), "item": it, "gain": _rate(it, b) + RoyaleLoot.EMPTY_FIRST, "replace": false})
	var cands: Array = []
	for s in SLOTS:
		if s in empty:
			continue
		var worn: Dictionary = b.gear[s]
		var base := _rate(worn, b)
		for up in ["level", "rarity", "forge"]:
			var amount := RoyaleLoot._amount(worn, up, lv, tier)
			if amount <= 0:
				continue
			var prev := worn.duplicate(true)
			RoyaleLoot._apply(prev, up, amount, lv, tier)
			var gn := _rate(prev, b) - base
			if gn > 0.001:
				cands.append({"kind": "piece", "slot": String(s), "item": prev, "gain": gn, "replace": false, "up": up})
		var it := RoyaleLoot._piece(def, lv, b.cid, String(s))
		var gr := _rate(it, b) - base
		if gr > 0.001:
			cands.append({"kind": "piece", "slot": String(s), "item": it, "gain": gr, "replace": true})
	Run.hero_level = was
	cands.sort_custom(func(x, y): return float(x.gain) > float(y.gain))
	var used := {}
	for o in out:
		used[String(o.slot)] = true
	for c in cands:
		if out.size() >= n:
			break
		if used.has(String(c.slot)) and rng.randf() < 0.8:
			continue
		out.append(c)
		used[String(c.slot)] = true
	return out


## Panoplie : pièces de la panoplie la plus portée (niveau 90 du Survivant, bonus 2 / 4), sinon de trois panoplies différentes.
static func _set_options(b: ColiseeBuild, rng: RandomNumberGenerator, n: int) -> Array:
	var counts := Items.set_counts(b.gear)
	var sets: Array = SurvivorPool.sets()
	var best := ""
	var best_n := 0
	for sid in counts:
		if String(sid) in sets and int(counts[sid]) > best_n:
			var missing := SurvivorPool.set_pieces(String(sid)).filter(func(e): return not _wears(b, e))
			if not missing.is_empty():
				best = String(sid)
				best_n = int(counts[sid])
	var models: Array = []
	if best != "":
		models = SurvivorPool.set_pieces(best).filter(func(e): return not _wears(b, e))
		_shuffle(models, rng)
		models = models.slice(0, n)
	else:
		var armor := String(ClassGear.profile(b.cid).get("armor", ""))
		var pool: Array = sets.duplicate()
		_shuffle(pool, rng)
		pool.sort_custom(func(x, y): return int(SurvivorPool.armor_of(String(x)) == armor) > int(SurvivorPool.armor_of(String(y)) == armor))
		for sid in pool:
			if models.size() >= n:
				break
			var ps: Array = SurvivorPool.set_pieces(String(sid))
			if ps.is_empty():
				continue
			var empty := ps.filter(func(e): return not b.gear.has(String(e.slot)))
			models.append((empty if not empty.is_empty() else ps)[rng.randi_range(0, (empty if not empty.is_empty() else ps).size() - 1)])
	var out: Array = []
	var was := Run.hero_level
	Run.hero_level = Colisee.LEVEL
	for e in models:
		var it := Items.from_template(e, Colisee.LEVEL, maxi(int(e.get("rarity", 3)), 3))
		var s := String(it.slot)
		var gn := _rate(it, b) - _rate(b.gear.get(s, {}), b) + 0.5 * (best_n + 1)
		out.append({"kind": "piece", "slot": s, "item": it, "gain": gn, "replace": b.gear.has(s), "set": String(it.get("set", ""))})
	Run.hero_level = was
	return out


static func _wears(b: ColiseeBuild, e: Dictionary) -> bool:
	var w: Dictionary = b.gear.get(String(e.slot), {})
	return not w.is_empty() and String(w.get("set", "")) == String(e.get("set", "")) and String(e.get("set", "")) != ""


## Éclat : pièces légendaires de la classe (qualité de largage du Battle royale), un emplacement vide ou le plus faible.
static func _eclat_options(b: ColiseeBuild, rng: RandomNumberGenerator, n: int) -> Array:
	var def: Dictionary = (Royale.CHEST_TIERS[ECLAT_TIER] as Dictionary).duplicate()
	def["min_r"] = Items.LEGENDARY
	def["max_r"] = Items.LEGENDARY
	var slots: Array = SLOTS.duplicate()
	slots.sort_custom(func(x, y): return _rate(b.gear.get(String(x), {}), b) < _rate(b.gear.get(String(y), {}), b))
	var head := slots.slice(0, 4)
	_shuffle(head, rng)
	var out: Array = []
	var was := Run.hero_level
	Run.hero_level = Colisee.LEVEL
	for s in head.slice(0, n):
		var it := RoyaleLoot._piece(def, Colisee.LEVEL, b.cid, String(s))
		out.append({"kind": "piece", "slot": String(s), "item": it, "gain": _rate(it, b) - _rate(b.gear.get(String(s), {}), b),
			"replace": b.gear.has(String(s))})
	Run.hero_level = was
	return out


## Garde l'option [param index] de l'enclume ouverte de [param b]. Une pièce remplacée est revendue (prix de revente).
static func choose(b: ColiseeBuild, index: int, g: Object = null) -> bool:
	if b.anvil.is_empty():
		return false
	var opts: Array = b.anvil.options
	if index < 0 or index >= opts.size():
		return false
	var o: Dictionary = opts[index]
	var r := int(g.get("round_n")) if g != null else 0
	var cost := int(b.anvil.price)
	if String(o.kind) == "stat":
		var k := String(o.key)
		b.stats[k] = float(b.stats.get(k, 0.0)) + float(o.value)
		b.stat_buys.append({"key": k, "value": float(o.value), "price": cost})
	else:
		var s := String(o.slot)
		var it: Dictionary = (o.item as Dictionary).duplicate(true)
		var old: Dictionary = b.gear.get(s, {})
		var paid := cost
		if not old.is_empty() and String(o.get("up", "")) != "":
			paid += int(old.get("co_price", 0))  # amélioration : la pièce garde ce qu'elle a coûté
		elif not old.is_empty():
			b.gold += resale(old, r)
		it["co_price"] = paid
		it["co_round"] = r if String(o.get("up", "")) == "" or old.is_empty() else int(old.get("co_round", r))
		b.gear[s] = it
	b.anvil_log.append({"round": r, "kind": String(b.anvil.kind), "price": cost, "pick": o.get("key", o.get("slot", ""))})
	b.anvil = {}
	return true


## Prix de revente d'une pièce à la manche [param r] : le prix payé pendant la préparation de son achat, la moitié ensuite.
static func resale(it: Dictionary, r: int) -> int:
	var paid := int(it.get("co_price", 0))
	return paid if int(it.get("co_round", -1)) == r else int(floor(paid * RESELL_LATER))


## Revend la pièce de l'emplacement [param slot] de [param b] ; rend l'or rendu (-1 : rien à vendre).
static func sell(b: ColiseeBuild, slot: String, g: Object = null) -> int:
	var it: Dictionary = b.gear.get(slot, {})
	if it.is_empty():
		return -1
	var v := resale(it, int(g.get("round_n")) if g != null else 0)
	b.gear.erase(slot)
	b.gold += v
	return v


## Annule le bonus de stat [param i] pris pendant cette préparation (remboursé).
static func undo_stat(b: ColiseeBuild, i: int) -> bool:
	if i < 0 or i >= b.stat_buys.size():
		return false
	var e: Dictionary = b.stat_buys[i]
	b.stats[String(e.key)] = maxf(0.0, float(b.stats.get(String(e.key), 0.0)) - float(e.value))
	if float(b.stats[String(e.key)]) <= 0.0001:
		b.stats.erase(String(e.key))
	b.gold += int(e.price)
	b.stat_buys.remove_at(i)
	return true


## Choix d'une option d'enclume (IA, choix automatique) : le gain de note (RoyaleLoot.best) ou le poids du profil ; Facile :
## au hasard.
static func choose_anvil(opts: Array, b: ColiseeBuild, _ctx := {}, rng: RandomNumberGenerator = null) -> int:
	if opts.is_empty():
		return -1
	if b.diff <= 0:
		return (rng if rng != null else RandomNumberGenerator.new()).randi_range(0, opts.size() - 1)
	var best := 0
	for i in opts.size():
		if float(opts[i].get("gain", 0.0)) > float(opts[best].get("gain", 0.0)):
			best = i
	return best


# --- sorts ---------------------------------------------------------------------------------------------------------------------

## Sorts de la classe que [param b] n'a pas encore. Héros scripté : sorts d'attaque seulement (il ne lance ni renforts ni
## soins hors de son équipe d'alliés) ; joueur : tous.
static func spell_pool(b: ColiseeBuild) -> Array:
	var cls := GameData.class_data(b.cid)
	var have := {}
	if b.is_player:
		for s in Run.all_skills():
			have[int(s.id)] = true
	else:
		var attack := (cls.get("skills", []) as Array).filter(func(s): return String(s.kind) != "buff" and String(s.kind) != "heal")
		for s in attack.slice(0, 4):
			have[int(s.id)] = true
	for id in b.spells:
		have[int(id)] = true
	var out: Array = []
	for s in cls.get("skills", []):
		if have.has(int(s.id)):
			continue
		if not b.is_player and String(s.kind) in ["buff", "heal"]:
			continue
		out.append(int(s.id))
	return out


## Ouvre une offre de sort si une place est libre (3 sorts de la classe tirés parmi les mieux notés).
static func open_spells(b: ColiseeBuild, rng: RandomNumberGenerator = null) -> void:
	if not b.spell_offer.is_empty() or b.spell_slots <= b.spells.size():
		return
	var pool := spell_pool(b)
	if pool.is_empty():
		return
	var r := rng if rng != null else RandomNumberGenerator.new()
	var keyed: Array = []
	for id in pool:
		keyed.append([spell_score(b, int(id)) * r.randf_range(0.7, 1.3), int(id)])
	keyed.sort()
	keyed.reverse()
	b.spell_offer = keyed.slice(0, 3).map(func(e): return int(e[1]))


## Note d'un sort pour [param b] : dégâts (mult) et contrôle, divisés par la recharge ; soins pour un soigneur.
static func spell_score(b: ColiseeBuild, id: int) -> float:
	var s: Dictionary = {}
	for e in GameData.class_data(b.cid).get("skills", []):
		if int(e.id) == id:
			s = e
	if s.is_empty():
		return 0.0
	var v := float(s.get("mult", 1.0)) + 0.6 * float((s.get("applies", {}) as Dictionary).size())
	if String(s.kind) in ["heal", "buff"]:
		v = 2.5 if b.role == "healer" and String(s.kind) == "heal" else 0.8
	return v / sqrt(maxf(float(s.get("cooldown", 6.0)), 2.0))


static func choose_spell(ids: Array, b: ColiseeBuild, _ctx := {}) -> int:
	var best := 0
	for i in ids.size():
		if spell_score(b, int(ids[i])) > spell_score(b, int(ids[best])):
			best = i
	return best if not ids.is_empty() else -1


## Prend le sort [param index] de l'offre de [param b] ; le joueur : enchaînement de la touche qui en a le moins (Run.chains).
static func take_spell(b: ColiseeBuild, index: int) -> bool:
	if index < 0 or index >= b.spell_offer.size():
		return false
	var id := int(b.spell_offer[index])
	b.spells.append(id)
	b.spell_offer = []
	if b.is_player:
		_chain_for_player(id)
	open_spells(b)
	return true


static func _chain_for_player(id: int) -> void:
	if Run.skills.size() < Run.MAX_SKILLS:
		Run.skills.append({"id": id, "rank": 1})
	else:
		var best := -1
		for slot in Run.skills.size():
			if Run.chain_of(slot).size() < Run.MAX_CHAIN and (best < 0 or Run.chain_of(slot).size() < Run.chain_of(best).size()):
				best = slot
		if best < 0:
			return
		var ch: Array = Run.chain_of(best).duplicate()
		ch.append({"id": id, "rank": 1})
		Run.chains[best] = ch
	Run.changed.emit()


## Sorts en plus d'un héros scripté qui apparaît (directeur) : ajoutés à ses sorts.
static func grant_spells(r: ClassRival, b: ColiseeBuild) -> void:
	for id in b.spells:
		for s in GameData.class_data(b.cid).get("skills", []):
			if int(s.id) == int(id) and not s in r._skills:
				r._skills.append(s)


# --- décisions -----------------------------------------------------------------------------------------------------------------

## Préparation d'une IA (ou choix automatique) : atout, sort, enclumes offertes, puis l'or dépensé (pièces pour les
## emplacements vides, panoplie, stats). Le chef d'équipe (coach) décide à la place s'il est posé.
static func ai_prep(b: ColiseeBuild, g: Object) -> void:
	var ctx := ColiseeAugments.context_for(g, b)
	var rng := rng_of(g)
	if not b.offer.is_empty():
		var i := _coach_pick("choose_augment", b.offer, b, ctx)
		if i < 0:
			i = ColiseeAugments.choose_augment(b.offer, b, ctx, rng)
		ColiseeAugments.take(b, String(b.offer[clampi(i, 0, b.offer.size() - 1)]), g)
	var guard := 0
	while not b.spell_offer.is_empty() and guard < 4:
		guard += 1
		var i := _coach_pick("choose_spell", b.spell_offer, b, ctx)
		take_spell(b, i if i >= 0 else choose_spell(b.spell_offer, b, ctx))
	for gift in b.gifts.duplicate():
		if open_anvil(b, String(gift), g, true):
			_pick_anvil(b, g, ctx, rng)
	if coach != null and coach.has_method("shop"):
		coach.call("shop", b, g)
	else:
		shop(b, g)
	b.ready = true


## Achats d'une IA avec son or : pièce pour un emplacement vide, panoplie déjà portée, puis stats ; Facile s'arrête au hasard.
static func shop(b: ColiseeBuild, g: Object) -> void:
	var ctx := ColiseeAugments.context_for(g, b)
	var rng := rng_of(g)
	var guard := 0
	while guard < 12:
		guard += 1
		if b.diff <= 0 and rng.randf() < 0.35:
			break
		var empty := SLOTS.filter(func(s): return not b.gear.has(s)).size()
		var kind := ""
		var sets := Items.set_counts(b.gear)
		var worn_set := false
		for sid in sets:
			worn_set = worn_set or int(sets[sid]) >= 1
		if b.gold >= price("panoplie") and worn_set and b.diff >= 2 and empty <= 3:
			kind = "panoplie"
		elif b.gold >= price("piece") and (empty > 0 or b.gold >= price("piece") + price("stat")):
			kind = "piece"
		elif b.gold >= price("stat"):
			kind = "stat"
		if kind == "" or not open_anvil(b, kind, g):
			break
		_pick_anvil(b, g, ctx, rng)


static func _pick_anvil(b: ColiseeBuild, g: Object, ctx: Dictionary, rng: RandomNumberGenerator) -> void:
	var opts: Array = b.anvil.get("options", [])
	var i := _coach_pick("choose_anvil", opts, b, ctx)
	if i < 0:
		i = choose_anvil(opts, b, ctx, rng)
	choose(b, clampi(i, 0, opts.size() - 1), g)


static func _coach_pick(method: String, opts: Array, b: ColiseeBuild, ctx: Dictionary) -> int:
	if opts.is_empty():
		return -1
	if coach != null and coach.has_method(method):
		return int(coach.call(method, opts, b, ctx))
	# chef d'équipe du lot CO-D (ColiseeCoach, s'il est là) : ses fonctions statiques choose_augment / choose_anvil
	# (offres en dictionnaires {score ou gain, tags}, classe, difficulté, classes du trio)
	var cs := _coach_script()
	if cs == null or method == "choose_spell" or not cs.get_script_method_list().any(func(m): return String(m.name) == method):
		return -1
	var dicts: Array = ColiseeAugments.offer_dicts(opts, b, ctx) if method == "choose_augment" else opts
	var trio: Array = (ctx.get("mates", []) as Array).map(func(m): return String((m as ColiseeBuild).cid))
	var i := int(cs.call(method, dicts, b.cid, b.diff, trio, rng_of(null)))
	return i if i >= 0 and i < opts.size() else -1


static var _coach_cached := false
static var _coach_res: Script = null


static func _coach_script() -> Script:
	if not _coach_cached:
		_coach_cached = true
		for e in ProjectSettings.get_global_class_list():
			if String(e.get("class", "")) == "ColiseeCoach" and ResourceLoader.exists(String(e.path)):
				_coach_res = load(String(e.path))
	return _coach_res


## Fin de la préparation : ce qui attend encore un choix (le joueur sans réponse) prend l'option la mieux notée, jamais au
## hasard ; une enclume ouverte garde sa meilleure option.
static func auto_finish(g: Object) -> void:
	for row in ColiseeBuild.all_of(g):
		for b in row:
			var bb := b as ColiseeBuild
			var ctx := ColiseeAugments.context_for(g, bb)
			var was := bb.diff
			bb.diff = 3  # (au temps écoulé : la meilleure note, jamais le hasard)
			if not bb.offer.is_empty():
				ColiseeAugments.take(bb, String(bb.offer[ColiseeAugments.choose_augment(bb.offer, bb, ctx)]), g)
			var guard := 0
			while not bb.spell_offer.is_empty() and guard < 4:
				guard += 1
				take_spell(bb, choose_spell(bb.spell_offer, bb, ctx))
			if not bb.anvil.is_empty():
				choose(bb, choose_anvil(bb.anvil.options, bb, ctx), g)
			for gift in bb.gifts.duplicate():
				if open_anvil(bb, String(gift), g, true):
					choose(bb, choose_anvil(bb.anvil.options, bb, ctx), g)
			bb.diff = was
			bb.ready = true


## Quelque chose attend-il le choix de [param b] (atout, sort, enclume ouverte ou offerte) ?
static func pending(b: ColiseeBuild) -> bool:
	return b != null and (not b.offer.is_empty() or not b.spell_offer.is_empty() or not b.anvil.is_empty() or not b.gifts.is_empty())


static func _shuffle(a: Array, rng: RandomNumberGenerator) -> void:
	for i in range(a.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = a[i]
		a[i] = a[j]
		a[j] = tmp


## Ligne lisible d'une option d'enclume (page de préparation, journal).
static func option_text(o: Dictionary) -> String:
	if String(o.get("kind", "")) == "stat":
		return "%s · %s" % [String(STATS[String(o.key)].name), String(STATS[String(o.key)].tip)]
	var it: Dictionary = o.get("item", {})
	var up := String(o.get("up", ""))
	var verb: String = {"level": "Mise à niveau", "rarity": "Rareté +1", "forge": "Forge"}.get(up, "Remplace" if bool(o.get("replace", false)) else "Nouvelle pièce")
	return "%s · %s" % [verb, String(it.get("name", o.get("slot", "")))]
