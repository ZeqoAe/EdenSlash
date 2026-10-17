class_name MobaRival
extends ClassRival
## Héros scripté des Deux Voies (lots MB-C, MB-D, MB-E ; rapports R_MB_C.md, R_MB_D.md, R_MB_E.md) : le ClassRival du jeu
## (micro : lecture des zones, esquives, cible la plus faible, repli, soutien de son équipe), à la fiche d'un héros de sa
## classe au niveau de partie, avec le kit de partie de sa classe (MobaData.kit) qui grandit avec son niveau (MobaHero :
## enchaînements débloqués ajoutés à ses sorts, ultime au niveau 5 à sa recharge et sa puissance de partie) et ses objets
## (MobaItems.sheet_rival : PV, attaque, défense, critique ; ici : vitesse d'attaque, recharges, course).
## Sa cible et son but sont posés par l'IA de poste (MobaHeroAi, lot MB-E) ; [member avoid] = zones à ne pas franchir
## (portée des tours adverses dangereuses) : la course est déviée au bord, jamais dedans (sauf [member dive_ok]).
## Mort : caché jusqu'à sa réapparition à la fontaine, sans recréer le modèle (budget R_MB0 § 6).

var director: Node  # MobaDirector
var side := 0
var game_level := 1
var ult_on := false
var hero: MobaHero  # son état de partie (posé par le directeur)
## Le coup en cours est un sort (MobaItems.is_skill : vol de vie des sorts, déclencheurs « skill_hit »).
var moba_skill := false
var moba_aspd := 1.0  # vitesse d'attaque des objets (fin des coups raccourcie, jamais l'annonce rouge)
var moba_cdr := 0.0  # recharges des objets
var moba_move := 1.0  # vitesse de course des objets
var ult_id := 0
## Zones interdites [[centre, rayon]] (lot MB-E : tours adverses sans sbire allié pour les occuper) ; plongée permise.
var avoid: Array = []
var dive_ok := false
var hold_ult := true  # l'ultime est gardé pour les héros (jamais sur un sbire)
var cost_us := 0  # (mesures : temps de son _physics_process, cumulé)
var cost_n := 0


## Héros [param cid] de l'équipe [param t] au niveau de partie [param lv] (comme TeamMatch.make_hero : aucun état de Duel).
static func make(dir: Node, cid: String, lv: int, diff: int, t: int) -> MobaRival:
	var r := MobaRival.new()
	r.director = dir
	r.side = t
	r.ally = t == TeamMatch.player_team
	r.setup(cid, MobaData.sheet_level(lv), clampi(diff, 0, ClassRival.NAMES.size() - 1))
	r.resheet(lv)
	r.display_name = String(GameData.class_data(cid).get("name_fr", cid))
	r.set_kit(lv >= 5)
	TeamMatch.add(r, t)
	return r


## Fiche d'un héros de sa classe au niveau de partie [param lv], ses objets posés dessus ; la part de PV restante est gardée.
func resheet(lv: int) -> void:
	var ratio := hp / max_hp if max_hp > 0.0 and not is_dead else 1.0
	var h := TeamMatch.hero_sheet(cid, MobaData.sheet_level(lv))
	use_sheet(h)
	var magic := h.matk > h.atk
	h.free()
	game_level = lv
	level = MobaData.sheet_level(lv)
	if hero != null:
		MobaItems.sheet_rival(self, hero, magic)
		moba_aspd = 1.0 + MobaItems.stat(hero, "atk_speed")
		moba_cdr = clampf(MobaItems.stat(hero, "cdr"), 0.0, 0.5)
		moba_move = 1.0 + MobaItems.stat(hero, "move") + (MobaItems.stat(hero, "ooc_move") if hero.ooc else 0.0)
	hp = max_hp * ratio
	_apply_speed()


## Objets changés (MobaItems.refresh) : fiche refaite au même niveau.
func refresh_items() -> void:
	resheet(game_level)
	health_changed.emit(hp, max_hp)


func _apply_speed() -> void:
	move_speed = float(cfg.speed) * moba_move
	if cls.size() > 0:
		travel_speed = Player.BASE_SPEED * (1.0 + float(cls.get("base", {}).get("move_speed", 0.0))) * moba_move


## Sorts : ceux que son niveau a débloqués (MobaHero.kit_unlocked : cases 1-3, leurs enchaînements, l'ultime et le sien) ;
## sans état de partie, les cases 1 à 3 et l'ultime si [param with_ult].
func set_kit(with_ult: bool) -> void:
	var k := MobaData.kit(cid)
	var u: Dictionary
	if hero != null:
		u = hero.kit_unlocked()
	else:
		var mains: Array = []
		for i in (k.get("slots", []) as Array).size():
			if i < 3 or with_ult:
				mains.append(int(k.slots[i].main))
		u = {"mains": mains, "chains": {}, "ult": int(k.get("ult", {}).get("id", 0)), "ult_on": with_ult}
	ult_on = bool(u.ult_on)
	ult_id = int(u.ult) if ult_on else 0
	var by_id := {}
	for s in cls.get("skills", []):
		by_id[int(s.id)] = s
	var ids: Array = []
	for i in (u.mains as Array).size():
		if i < 3:
			ids.append(int(u.mains[i]))
	for slot in u.chains:
		if int(slot) < 3:
			ids.append_array(u.chains[slot])
	if ult_on:
		ids.append(int(u.ult))
		ids.append_array(u.chains.get(3, []))
	var off: Array = []
	var sup: Array = []
	for id in ids:
		var s: Dictionary = by_id.get(int(id), {})
		if s.is_empty():
			continue
		if int(id) == int(u.ult):
			s = _ult_def(s, k.get("ult", {}))
		if String(s.kind) in ["buff", "heal"]:
			sup.append(s)
		else:
			off.append(s)
	if not off.is_empty():
		_skills = off
	_support = sup


## L'ultime à sa recharge et sa puissance de partie (MobaData.kit : 60-90 s, × 1,6).
static func _ult_def(s: Dictionary, u: Dictionary) -> Dictionary:
	var d := s.duplicate(true)
	if u.is_empty():
		return d
	d["cooldown"] = float(u.get("cooldown", d.get("cooldown", 60.0)))
	var pw := float(u.get("power", 1.6))
	if d.has("mult"):
		d["mult"] = float(d.mult) * pw
	if d.has("heal"):
		d["heal"] = float(d.heal) * pw
	return d


func _ready() -> void:
	super._ready()
	_retarget_t = 1.0e9  # (cible choisie par le directeur)
	_player = null  # (ClassRival._ready vise le héros du joueur, peut-être un équipier)
	_apply_speed()


func _physics_process(delta: float) -> void:
	if is_dead:
		return  # (ni soutien ni lecture des zones pendant la mort)
	var t0 := Time.get_ticks_usec()
	super._physics_process(delta)
	cost_us += Time.get_ticks_usec() - t0
	cost_n += 1


## Coup ou sort : l'ultime n'est lancé que sur un héros ; un sort lancé raccourcit sa recharge (objets) et prévient les
## objets (« skill_cast ») ; une auto-attaque finit plus vite avec la vitesse d'attaque des objets.
func _start_attack() -> void:
	var c := _combo_i
	var before := _skill_ready.duplicate()
	var hold := hold_ult and ult_id > 0 and not Combatant.is_hero(_player)
	var saved = _skill_ready.get(ult_id)
	if hold:
		_skill_ready[ult_id] = 1.0e9
	super._start_attack()
	if hold:
		if saved == null:
			_skill_ready.erase(ult_id)
		else:
			_skill_ready[ult_id] = saved
	moba_skill = _combo_i == c
	if moba_skill:
		for id in _skill_ready:
			if before.get(id) != _skill_ready[id] and float(_skill_ready[id]) > _time:
				_skill_ready[id] = _time + (float(_skill_ready[id]) - _time) * (1.0 - moba_cdr)
		if hero != null:
			MobaItems.on_cast(hero)
	elif moba_aspd > 1.0:
		_state_len = _hit_time + maxf(0.0, _state_len - _hit_time) / moba_aspd


func _end_of_hit() -> void:
	super._end_of_hit()
	if moba_aspd > 1.0:
		_attack_ready_at = _time + maxf(0.0, _attack_ready_at - _time) / moba_aspd


## Course : jamais dans une zone interdite (bord longé, sortie si dedans).
func _update_chase(delta: float) -> Vector3:
	return guard(super._update_chase(delta))


func guard(v: Vector3) -> Vector3:
	if avoid.is_empty() or dive_ok:
		return v
	var p := global_position
	for z in avoid:
		var off: Vector3 = p - (z[0] as Vector3)
		off.y = 0.0
		var d := off.length()
		var r := float(z[1])
		if d < r:
			var out := off / maxf(d, 0.01)
			face_direction(out, 0.1, 10.0)
			return out * maxf(move_speed, travel_speed)
		if d < r + 2.0:
			var n := off / d
			var inward := v.dot(n)
			if inward < 0.0:
				v -= n * inward
	return v


## Dans une zone interdite (mesures et IA).
func inside_avoid() -> bool:
	for z in avoid:
		var off: Vector3 = global_position - (z[0] as Vector3)
		off.y = 0.0
		if off.length() < float(z[1]):
			return true
	return false


func _on_death(killer: Combatant) -> void:
	if is_instance_valid(_telegraph):
		_telegraph.queue_free()
	_set_state("dead")
	_react_at = -1.0
	visible = false
	collision_layer = 0
	director.on_hero_down(self, killer)


## Relevé à [param at] (fontaine), PV pleins, sans recréer le modèle.
func revive(at: Vector3) -> void:
	is_dead = false
	hp = max_hp
	statuses.clear()
	_dots.clear()
	statuses_changed.emit()
	_burst.clear()
	visible = true
	collision_layer = GameData.PHYS_PLAYER if ally else GameData.PHYS_MONSTER
	_state = "idle"
	_state_time = 0.0
	_player = null
	goal = Vector3.INF
	passive = false
	velocity = Vector3.ZERO
	global_position = at + Vector3.UP * 0.4
	health_changed.emit(hp, max_hp)
