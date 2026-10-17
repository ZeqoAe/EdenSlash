class_name MobaRival
extends ClassRival
## Héros scripté des Deux Voies (lot MB-C, rapport R_MB_C.md) : le ClassRival du jeu (micro : lecture des zones, esquives,
## cible la plus faible, repli, soutien de son équipe), à la fiche d'un héros de sa classe au niveau de partie, avec le kit
## de partie de sa classe (MobaData.kit). Sa cible et son but sont posés par le directeur (MobaDirector._think, IA simple de
## voie en attendant le lot MB-E : ne passe pas sous une tour adverse sans sbires, rentre à la fontaine sous 30 % de PV).
## Mort : caché jusqu'à sa réapparition à la fontaine, sans recréer le modèle (budget R_MB0 § 6).

var director: Node  # MobaDirector
var side := 0
var game_level := 1
var ult_on := false


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


## Fiche d'un héros de sa classe au niveau de partie [param lv] ; la part de PV restante est gardée.
func resheet(lv: int) -> void:
	var ratio := hp / max_hp if max_hp > 0.0 and not is_dead else 1.0
	var h := TeamMatch.hero_sheet(cid, MobaData.sheet_level(lv))
	use_sheet(h)
	h.free()
	game_level = lv
	level = MobaData.sheet_level(lv)
	hp = max_hp * ratio


## Sorts : les cases 1 à 3 du kit de partie, et l'ultime (case 4) une fois débloqué.
func set_kit(with_ult: bool) -> void:
	ult_on = with_ult
	var k := MobaData.kit(cid)
	var by_id := {}
	for s in cls.get("skills", []):
		by_id[int(s.id)] = s
	var off: Array = []
	var sup: Array = []
	var slots: Array = k.get("slots", [])
	for i in slots.size():
		if i == 3 and not with_ult:
			break
		var s: Dictionary = by_id.get(int(slots[i].main), {})
		if s.is_empty():
			continue
		if String(s.kind) in ["buff", "heal"]:
			sup.append(s)
		else:
			off.append(s)
	if not off.is_empty():
		_skills = off
	_support = sup


func _ready() -> void:
	super._ready()
	_retarget_t = 1.0e9  # (cible choisie par le directeur)
	_player = null  # (ClassRival._ready vise le héros du joueur, peut-être un équipier)
	travel_speed = Player.BASE_SPEED * (1.0 + float(cls.get("base", {}).get("move_speed", 0.0)))


func _physics_process(delta: float) -> void:
	if is_dead:
		return  # (ni soutien ni lecture des zones pendant la mort)
	super._physics_process(delta)


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
	velocity = Vector3.ZERO
	global_position = at + Vector3.UP * 0.4
	health_changed.emit(hp, max_hp)
