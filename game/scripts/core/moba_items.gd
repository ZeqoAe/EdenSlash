class_name MobaItems
extends RefCounted
## Les Deux Voies, lot MB-D (MOBA.md § 7.7 ; rapport conception/benchmark/R_MB_D.md) : la boutique et les 40 objets
## (MobaData.ITEMS) appliqués au joueur ET aux héros IA.
##
## Boutique (logique seule ; l'écran est le lot MB-H) : ouverte à la fontaine et pendant la mort ; 6 places, bottes
## comprises, une seule paire ; un objet fini n'est porté qu'une fois ; recette = on ne paie que la différence (les
## composants portés sont pris) ; « Acheter » en un appui = [method next_step] du parcours conseillé ([method route],
## adapté à l'équipe adverse) ; annuler ([method undo]) tant qu'on n'a pas quitté la base ; vendre ([method sell]) rend
## 70 % du prix ; potions à part (5 de chaque au plus).
##
## Stats : en part de la fiche de base de la classe au niveau de partie (« +10 % d'attaque » = 10 % de l'attaque de base),
## additionnées ([method totals]) puis posées sur la fiche : le joueur par une ligne gardée de Player.recalc_stats
## ([method sheet]), l'IA par MobaRival.resheet ([method sheet_rival]).
##
## Effets déclenchés (« Procs sur Combatant ») : la table Procs du jeu ne connaît que le Player ; ici les déclencheurs des
## objets (crit, basic_hit, skill_hit, skill_hit_hero, skill_cast, kill_hero, low_hp, heal_ally) partent pour n'importe
## quel Combatant héros, par des lignes gardées (MobaItems.active) de Combatant.take_damage / heal / add_status :
## [method pre_hit] (pénétration, exécution, Égide, coup renforcé, épines, écho), [method absorb] (boucliers),
## [method post_hit] (vol de vie de l'IA, vol de vie des sorts, déclencheurs), [method heal_in] (soins reçus, soins d'un
## allié), [method status_time] (ténacité). Hors des Deux Voies : active = faux, rien ne change.

const POTION_MAX := 5
const EXECUTE_BELOW := 0.5  # Lame de l'exécuteur : sous la moitié des PV
const CROWD_RADIUS := 8.0  # Égide du Rempart : ennemis comptés
const ECHO_MULT := 0.6  # Grimoire des échos : le second coup
const LIGHTNING_MULT := 0.5  # Arc-tempête : foudre (part de l'attaque)
const LIGHTNING_JUMP := 6.0  # m : saut de la foudre vers un second ennemi
const BURN_TIME := 3.0
const BURN_HEAL := 0.6  # soins reçus × sous la brûlure de la Lame de braise
const CHILL_TIME := 1.5
const SHIELD_TIME := 4.0
const SAVE_TIME := 5.0  # bouclier du Bouclier du gardien
const LOW_HP := 0.3
const MINION_AURA_R := 10.0

static var active := false
static var director: Node  # MobaDirector
static var _depth := 0
static var _raw := 0.0  # dégâts bruts du coup en cours (après pre_hit), lus par post_hit


static func begin(dir: Node) -> void:
	active = true
	director = dir
	_depth = 0


static func stop() -> void:
	active = false
	director = null
	_depth = 0


static func state(c) -> MobaHero:
	if director == null or c == null or not is_instance_valid(c):
		return null
	return director.info.get(c) as MobaHero


static func now() -> float:
	return Moba.t


# --- boutique -----------------------------------------------------------------------------------

static func shop_open(h: MobaHero) -> bool:
	return h != null and (h.in_shop or (h.node != null and is_instance_valid(h.node) and h.node.is_dead))


static func is_potion(id: String) -> bool:
	return String(MobaData.item(id).get("type", "")) == "potion"


## Prix réel de [param id] pour [param h] : prix moins les composants déjà portés (chacun pris une fois) ;
## {cost, used: [indices dans h.items]}.
static func quote(h: MobaHero, id: String) -> Dictionary:
	var it := MobaData.item(id)
	var cost := int(it.get("price", 0))
	var used: Array = []
	for r in it.get("recipe", []):
		for i in h.items.size():
			if i in used:
				continue
			if String(h.items[i]) == String(r):
				used.append(i)
				cost -= int(MobaData.item(String(r)).get("price", 0))
				break
	return {"cost": cost, "used": used}


static func potion_count(h: MobaHero, kind: String) -> int:
	if h.is_player:
		return Potions.count(kind)
	return int(h.potions.get(kind, 0))


## Raison du refus d'un achat ("" : possible).
static func why_not(h: MobaHero, id: String) -> String:
	var it := MobaData.item(id)
	if it.is_empty():
		return "Objet inconnu."
	if not shop_open(h):
		return "La boutique ouvre à la fontaine."
	if is_potion(id):
		if potion_count(h, String(it.potion)) >= POTION_MAX:
			return "Tu en as déjà assez."
		return "" if h.gold >= float(it.price) else "Pas assez d'or."
	var q := quote(h, id)
	if h.gold < float(q.cost):
		return "Pas assez d'or."
	if h.items.size() - (q.used as Array).size() + 1 > MobaData.SLOTS:
		return "Plus de place."
	var t := String(it.type)
	var kept: Array = []
	for i in h.items.size():
		if not i in q.used:
			kept.append(String(h.items[i]))
	if t == "bottes" and kept.any(func(x): return String(MobaData.item(x).type) == "bottes"):
		return "Une seule paire de bottes."
	if not t in ["composant", "bottes"] and id in kept:
		return "Tu le portes déjà."
	return ""


static func can_buy(h: MobaHero, id: String) -> bool:
	return why_not(h, id) == ""


## Achète [param id] (composants portés pris, différence payée) ; false si refusé.
static func buy(h: MobaHero, id: String) -> bool:
	if not can_buy(h, id):
		return false
	var it := MobaData.item(id)
	if is_potion(id):
		h.gold -= float(it.price)
		if h.is_player:
			Potions.grant(String(it.potion))
		else:
			h.potions[String(it.potion)] = int(h.potions.get(String(it.potion), 0)) + 1
		h.history.append({"op": "buy", "id": id, "gold": float(it.price), "used": []})
		return true
	var q := quote(h, id)
	var used_ids: Array = []
	var idx: Array = (q.used as Array).duplicate()
	idx.sort()
	idx.reverse()
	for i in idx:
		used_ids.append(String(h.items[i]))
		h.items.remove_at(i)
	h.items.append(id)
	h.gold -= float(q.cost)
	h.history.append({"op": "buy", "id": id, "gold": float(q.cost), "used": used_ids})
	refresh(h)
	return true


## Vend l'objet à la place [param index] : 70 % de son prix.
static func sell(h: MobaHero, index: int) -> bool:
	if not shop_open(h) or index < 0 or index >= h.items.size():
		return false
	var id := String(h.items[index])
	var value := floorf(float(MobaData.item(id).price) * MobaData.SELL_BACK)
	h.items.remove_at(index)
	h.gold += value
	h.history.append({"op": "sell", "id": id, "gold": value, "at": index})
	refresh(h)
	return true


## Annule le dernier achat ou la dernière vente faits depuis l'arrivée à la base (or rendu, composants rendus).
static func undo(h: MobaHero) -> bool:
	if h.history.is_empty() or not shop_open(h):
		return false
	var e: Dictionary = h.history.pop_back()
	var id := String(e.id)
	if String(e.op) == "buy":
		if is_potion(id):
			var kind := String(MobaData.item(id).potion)
			if h.is_player:
				if Potions.count(kind) > 0:
					Profile.take_bag(Potions.key(kind))
			else:
				h.potions[kind] = maxi(0, int(h.potions.get(kind, 0)) - 1)
		else:
			var i := h.items.rfind(id)
			if i >= 0:
				h.items.remove_at(i)
			for u in e.used:
				h.items.append(String(u))
		h.gold += float(e.gold)
	else:
		h.gold -= float(e.gold)
		h.items.insert(clampi(int(e.get("at", h.items.size())), 0, h.items.size()), id)
	refresh(h)
	return true


## Le héros quitte la base : ses achats ne s'annulent plus.
static func leave_shop(h: MobaHero) -> void:
	h.history.clear()


# --- parcours conseillé -------------------------------------------------------------------------

## Parcours conseillé de [param h] (objets finis dans l'ordre, bottes comprises), adapté à l'équipe adverse
## ([param foe_families]) si [param adapt] : 2 Ombre ou plus → Bouclier du gardien tôt ; 2 Arcane ou plus → Heaume du
## colosse ; 2 Ferveur ou plus (soins) → Lame de braise pour les tireurs et les ombres.
static func route(h: MobaHero, foe_families: Array = [], adapt := true) -> Array:
	var opts: Array = MobaData.BUILDS.get(h.family, MobaData.BUILDS[3])
	var v := absi(hash(h.cid)) % opts.size()
	var r: Array = (opts[v] as Array).duplicate()
	if adapt and not foe_families.is_empty():
		var n := {}
		for f in foe_families:
			n[int(f)] = int(n.get(int(f), 0)) + 1
		if int(n.get(2, 0)) >= 2 and h.family != 1 and not "bouclier_gardien" in r:
			r.insert(mini(2, r.size()), "bouclier_gardien")
		if int(n.get(5, 0)) >= 2 and not "heaume_colosse" in r:
			r.insert(mini(2 if h.family == 1 else r.size(), r.size()), "heaume_colosse")
		if int(n.get(4, 0)) >= 2 and h.family in [2, 3] and not "lame_braise" in r:
			r.insert(mini(1, r.size()), "lame_braise")
	return r.slice(0, MobaData.SLOTS)


## Prochaine étape achetable du parcours : l'objet fini suivant s'il est payable, sinon son composant manquant le plus
## cher qu'on peut payer ; "" si rien (on attend : jamais de saut à l'objet d'après).
static func next_step(h: MobaHero, r: Array) -> String:
	for id in r:
		if String(id) in h.items:
			continue
		if can_buy(h, String(id)):
			return String(id)
		var have := h.items.duplicate()
		var missing: Array = []
		for c in MobaData.item(String(id)).get("recipe", []):
			var i := have.find(String(c))
			if i >= 0:
				have.remove_at(i)
			else:
				missing.append(String(c))
		missing.sort_custom(func(a, b): return int(MobaData.item(a).price) > int(MobaData.item(b).price))
		for c in missing:
			if can_buy(h, c):
				return c
		return ""
	return ""


## Achète tant que le parcours le permet (pilote automatique, IA) ; renvoie les ids achetés.
static func auto_shop(h: MobaHero, r: Array, potions_min := 1) -> Array:
	var got: Array = []
	for _i in 12:
		var id := next_step(h, r)
		if id == "" or not buy(h, id):
			break
		got.append(id)
	if potion_count(h, "heal") < potions_min and can_buy(h, "potion_soin"):
		buy(h, "potion_soin")
		got.append("potion_soin")
	return got


## Conseil d'affichage : l'objet fini suivant du parcours, son prix réel et l'or du héros (« 1 240 / 2 300 »).
static func advice(h: MobaHero, r: Array) -> Dictionary:
	for id in r:
		if String(id) in h.items:
			continue
		var q := quote(h, String(id))
		return {"id": String(id), "name": String(MobaData.item(String(id)).name), "cost": int(q.cost), "gold": int(h.gold),
			"step": next_step(h, r)}
	return {}


# --- stats -------------------------------------------------------------------------------------

## Totaux des stats des objets portés (clés de MobaData.ITEMS.stats, additionnées).
static func totals(h: MobaHero) -> Dictionary:
	var s := {}
	for id in h.items:
		var st: Dictionary = MobaData.item(String(id)).get("stats", {})
		for k in st:
			s[k] = float(s.get(k, 0.0)) + float(st[k])
	return s


static func stat(h: MobaHero, key: String) -> float:
	return float(h.stats.get(key, 0.0)) if h != null else 0.0


## Totaux refaits et fiche reposée (joueur : recalc_stats ; IA : resheet).
static func refresh(h: MobaHero) -> void:
	h.stats = totals(h)
	if h.node == null or not is_instance_valid(h.node):
		return
	if h.node is Player:
		(h.node as Player).recalc_stats()
	elif h.node.has_method("refresh_items"):
		h.node.refresh_items()


## Ligne gardée de Player.recalc_stats : objets posés sur la fiche du joueur (après les plafonds du mode).
static func sheet(p: Player) -> void:
	var h := state(p)
	if h == null:
		return
	var s := h.stats
	var am := 1.0 + float(s.get("atk", 0.0))
	var mm := (1.0 + float(s.get("matk", 0.0))) * (1.0 + float(s.get("matk_total", 0.0)))
	p.max_hp *= 1.0 + float(s.get("hp", 0.0))
	p.atk *= am
	p.basic_atk *= am
	p.matk *= mm
	p.basic_matk *= mm
	p.defense *= 1.0 + float(s.get("def", 0.0))
	p.crit += float(s.get("crit", 0.0))
	p.mcrit += float(s.get("crit", 0.0))
	p.atk_speed += float(s.get("atk_speed", 0.0))
	p.cdr = clampf(p.cdr + float(s.get("cdr", 0.0)), 0.0, 0.5)
	p.lifesteal += float(s.get("lifesteal", 0.0))
	p.heal_power += float(s.get("heal_power", 0.0))
	p.move_mult *= 1.0 + float(s.get("move", 0.0)) + (float(s.get("ooc_move", 0.0)) if h.ooc else 0.0)


## Objets posés sur un héros IA (MobaRival.resheet, après ClassRival.use_sheet) : PV, attaque (ou magie), défense,
## critique ; vitesse d'attaque, recharges et vitesse de course gardées sur le héros (MobaRival les applique).
static func sheet_rival(r: Combatant, h: MobaHero, magic: bool) -> void:
	if h == null:
		return
	var s := h.stats
	r.max_hp *= 1.0 + float(s.get("hp", 0.0))
	if magic:
		r.atk *= (1.0 + float(s.get("matk", 0.0))) * (1.0 + float(s.get("matk_total", 0.0)))
	else:
		r.atk *= 1.0 + float(s.get("atk", 0.0))
	r.defense *= 1.0 + float(s.get("def", 0.0))
	r.set("crit_chance", float(r.get("crit_chance")) + float(s.get("crit", 0.0)))


# --- coups ---------------------------------------------------------------------------------------

## Puissance d'attaque d'un héros (dégâts des effets déclenchés, avant les règles du mode).
static func attack_of(c: Combatant) -> float:
	if c is Player:
		return maxf((c as Player).atk, (c as Player).matk) * (c as Player).dmg_mult
	return c.atk


static func is_skill(c: Combatant) -> bool:
	if c is Player:
		return (c as Player)._state == "skill"
	return bool(c.get("moba_skill")) if c.get("moba_skill") != null else false


## Part des dégâts qui passe la défense [param def] (même formule que Combatant.take_damage).
static func _taken(victim: Combatant, source: Combatant, def: float) -> float:
	if source != null and Combatant.is_hero(victim) and Combatant.is_hero(source) and PvpCaps.active():
		return PvpCaps.taken(def, source.defense)
	return 100.0 / (100.0 + maxf(def, 0.0))


## Ligne gardée de Combatant.take_damage, avant les règles du mode : pénétration (Brise-garde), exécution des héros
## affaiblis, coup renforcé (Faux de la Lune), Égide (plus solide à plusieurs), épines (Cape d'épines).
static func pre_hit(victim: Combatant, source: Combatant, amount: float, dot: bool) -> float:
	if _depth > 0 or dot:
		return amount
	var vs := state(victim)
	var ss := state(source)
	if ss != null and source != victim:
		var pen := stat(ss, "pen")
		if pen > 0.0 and vs != null:
			amount *= _taken(victim, source, victim.defense * (1.0 - pen)) / maxf(_taken(victim, source, victim.defense), 0.0001)
		var ex := stat(ss, "execute")
		if ex > 0.0 and vs != null and victim.hp < victim.max_hp * EXECUTE_BELOW:
			amount *= 1.0 + ex * (1.0 - victim.hp / (victim.max_hp * EXECUTE_BELOW))
		if ss.empower > 0.0 and not is_skill(source):
			amount *= ss.empower
			ss.empower = 0.0
	if vs != null and source != victim:
		var cd := stat(vs, "crowd_def")
		if cd > 0.0 and director != null:
			var n: int = director.enemies_near(vs.side, victim.global_position, CROWD_RADIUS, MobaDirector.KIND_HERO).size()
			if n > 1:
				amount *= _taken(victim, source, victim.defense * (1.0 + cd * (n - 1))) / maxf(_taken(victim, source, victim.defense), 0.0001)
		var th := stat(vs, "thorns")
		if th > 0.0 and ss != null and not is_skill(source) and is_instance_valid(source) and not source.is_dead:
			_depth += 1
			source.take_damage(amount * th, victim)
			_depth -= 1
	_raw = amount
	return amount


## Ligne gardée de Combatant.take_damage, après les plafonds : bouclier des objets d'abord.
static func absorb(victim: Combatant, dmg: float) -> float:
	var vs := state(victim)
	if vs == null or vs.shield <= 0.0:
		return dmg
	if now() > vs.shield_until:
		vs.shield = 0.0
		return dmg
	var take := minf(vs.shield, dmg)
	vs.shield -= take
	if dmg - take <= 0.0:
		DamageNumber.spawn_text(victim, "BOUCLIER", Color(0.7, 0.85, 1.0))
	return dmg - take


## Ligne gardée de Combatant.take_damage, à la fin : combat noté, déclencheurs de la source et de la victime.
static func post_hit(victim: Combatant, source: Combatant, dmg: float, crit: bool, dot: bool) -> void:
	if _depth > 0:
		return
	var t := now()
	var vs := state(victim)
	var ss := state(source)
	if vs != null:
		vs.last_combat = t
		if ss != null and source != victim:
			vs.note_damager(source, t)
		if not victim.is_dead:
			if victim.hp < victim.max_hp * LOW_HP:
				if vs.low_armed:
					vs.low_armed = false
					fire(vs, "low_hp", victim)
			elif victim.hp > victim.max_hp * (LOW_HP + 0.1):
				vs.low_armed = true
	if ss == null or source == victim or dot:
		return
	ss.last_combat = t
	var skill := is_skill(source)
	var ls := stat(ss, "lifesteal")
	if ls > 0.0 and not (source is Player):
		source.heal(dmg * ls)  # (le joueur : Player._hit_monster lit déjà son vol de vie)
	var sv := stat(ss, "spell_vamp")
	if sv > 0.0 and skill:
		source.heal(dmg * sv)
	if crit:
		fire(ss, "crit", victim)
	if skill:
		fire(ss, "skill_hit", victim)
		if vs != null:
			fire(ss, "skill_hit_hero", victim)
	else:
		ss.basic_hits += 1
		fire(ss, "basic_hit", victim)


## Ligne gardée de Combatant.heal : soins reçus (Armure vivante, brûlure de la Lame de braise) ; soin d'un allié par
## un soutien (AssaultCombat.healer : qui soigne en ce moment) : puissance de soin de l'IA, effets « heal_ally ».
static func heal_in(target: Combatant, amount: float) -> float:
	var vs := state(target)
	if vs == null:
		return amount
	amount *= 1.0 + stat(vs, "heal_taken")
	if target.has_status("burn") and float(target.get_meta("moba_burn_until", -1.0)) > now():
		amount *= BURN_HEAL
	var healer = AssaultCombat.healer
	if healer != null and is_instance_valid(healer) and healer != target and _depth == 0:
		var hs := state(healer)
		if hs != null and hs.side == vs.side:
			if not (healer is Player):
				amount *= 1.0 + stat(hs, "heal_power")
			fire(hs, "heal_ally", target)
	return amount


## Ligne gardée de Combatant.add_status : ténacité (Heaume du colosse) sur les contrôles et le ralenti.
static func status_time(target: Combatant, status: String, duration: float) -> float:
	if status in Combatant.CC_TYPES or status == "chill":
		var ten := stat(state(target), "tenacity")
		if ten > 0.0:
			return duration * (1.0 - ten)
	return duration


## Élimination d'un héros : effets « kill_hero » du tueur et des aides (Croc du chasseur, Sablier du sage).
static func on_kill(killer: MobaHero, helpers: Array) -> void:
	if killer != null:
		fire(killer, "kill_hero", null)
	for a in helpers:
		var hs := a as MobaHero
		if hs != null:
			for id in hs.items:
				var p: Dictionary = MobaData.item(String(id)).get("proc", {})
				if String(p.get("effect", "")) == "cdr" and String(p.get("trigger", "")) == "kill_hero":
					_run(hs, String(id), p, null)


## Un sort lancé (Faux de la Lune) : pour le joueur, vu par le directeur ; pour l'IA, par MobaRival.
static func on_cast(h: MobaHero) -> void:
	fire(h, "skill_cast", null)


# --- effets déclenchés ------------------------------------------------------------------------------

## Déclenche les effets des objets de [param h] liés à [param trigger] (chance, recharge interne par objet).
static func fire(h: MobaHero, trigger: String, target: Combatant) -> void:
	if h == null or h.node == null or not is_instance_valid(h.node) or h.node.is_dead or _depth > 1:
		return
	for id in h.items:
		var p: Dictionary = MobaData.item(String(id)).get("proc", {})
		if p.is_empty() or String(p.trigger) != trigger:
			continue
		if now() < float(h.proc_at.get(String(id), -1.0)):
			continue
		if trigger == "basic_hit" and int(p.get("every", 0)) > 1 and h.basic_hits % int(p.every) != 0:
			continue
		if randf() > float(p.get("chance", 1.0)):
			continue
		h.proc_at[String(id)] = now() + float(p.get("cd", 0.0))
		_run(h, String(id), p, target)


static func _run(h: MobaHero, id: String, p: Dictionary, target: Combatant) -> void:
	var me: Combatant = h.node
	var tv := target != null and is_instance_valid(target) and not target.is_dead
	_depth += 1
	match String(p.effect):
		"burn":
			if tv:
				target.add_status("burn", BURN_TIME, me)
				target.set_meta("moba_burn_until", now() + BURN_TIME)
		"chill":
			if tv:
				target.add_status("chill", float(p.get("time", CHILL_TIME)), me)
		"lightning":
			if tv:
				_lightning(me, target)
		"echo":
			if tv and _raw > 0.0:
				DamageNumber.spawn_text(target, "ÉCHO", Color(0.75, 0.8, 1.0))
				target.take_damage(_raw * ECHO_MULT, me)
		"empower":
			h.empower = float(p.get("mult", 1.5))
		"shield":
			var who: Combatant = target if String(p.trigger) == "heal_ally" and tv else me
			var ws := state(who)
			if ws != null:
				ws.shield = maxf(ws.shield, who.max_hp * float(p.get("shield", 0.1)))
				ws.shield_until = now() + (SAVE_TIME if String(p.trigger) == "low_hp" else SHIELD_TIME)
				Vfx.ring(who, who.global_position, 1.8, Color(0.7, 0.85, 1.0, 0.85))
		"heal":
			me.heal(me.max_hp * float(p.get("heal", 0.15)))
		"cdr":
			cut_cooldowns(me, float(p.get("cdr", 0.3)))
		"buff":
			if tv:
				target.add_status(String(p.get("status", "haste")), float(p.get("time", 3.0)), me)
	_depth -= 1


## Foudre : la cible puis un second ennemi à LIGHTNING_JUMP m (héros ou sbire du camp adverse).
static func _lightning(src: Combatant, target: Combatant) -> void:
	var dmg := attack_of(src) * LIGHTNING_MULT
	Vfx.bolt(src, target.global_position + Vector3.UP * 7.0, target.global_position + Vector3.UP * 0.8)
	target.take_damage(dmg, src)
	if director == null:
		return
	var s: int = director.side_of(src)
	for u in director.enemies_near(s, target.global_position, LIGHTNING_JUMP, MobaDirector.KIND_HERO | MobaDirector.KIND_MINION):
		if u != target and not u.is_dead:
			Vfx.bolt(src, target.global_position + Vector3.UP, u.global_position + Vector3.UP)
			u.take_damage(dmg, src)
			break


## Retire [param frac] du temps restant de chaque recharge en cours.
static func cut_cooldowns(c: Combatant, frac: float) -> void:
	if c is Player:
		var p := c as Player
		for id in p.skill_ready_at:
			var left := float(p.skill_ready_at[id]) - p._time
			if left > 0.0:
				p.skill_ready_at[id] = p._time + left * (1.0 - frac)
	elif c is ClassRival:
		var r := c as ClassRival
		for id in r._skill_ready:
			var left := float(r._skill_ready[id]) - r._time
			if left > 0.0:
				r._skill_ready[id] = r._time + left * (1.0 - frac)


## Bonus des sbires près d'un héros allié qui porte l'Étendard des voies (× 1 + minion_aura au plus fort).
static func minion_aura(m: Node3D, side: int) -> float:
	if director == null:
		return 1.0
	var best := 0.0
	for u in director.units_near(side, m.global_position, MINION_AURA_R, MobaDirector.KIND_HERO):
		best = maxf(best, stat(state(u), "minion_aura"))
	return 1.0 + best
