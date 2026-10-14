class_name Potions
extends RefCounted
## Potions (idée du joueur) : quatre fioles, rangées dans la réserve de fournitures de la run (clé « potion:<id> » :
## ramassées comme les gemmes, gardées en cas de victoire ou d'extraction, perdues si le héros tombe).
## Deux touches : C boit une potion de soin, V boit une potion d'effet (la plus nombreuse du stock). Chacune a
## sa recharge de 20 s : une potion n'est pas un bouton d'invincibilité. Jamais en duel (équilibre) ; centrales
## dans les modes à venir (Battle royale, Trio). Un départ de run remonte les potions de soin à 2.

const KINDS := {
	"heal": {"name": "Potion de soin", "desc": "Rend 35 % des PV max.", "color": Color(0.95, 0.3, 0.4), "group": "heal"},
	"haste": {"name": "Potion d'élan", "desc": "+30 % de vitesse de déplacement pendant 10 s.", "color": Color(0.35, 0.8, 0.95), "group": "boost", "status": "haste"},
	"frenzy": {"name": "Potion de rage", "desc": "+30 % de vitesse d'attaque pendant 10 s.", "color": Color(1.0, 0.6, 0.2), "group": "boost", "status": "frenzy"},
	"keen": {"name": "Potion d'acuité", "desc": "+25 % de chances de coup critique pendant 10 s.", "color": Color(0.7, 0.4, 0.95), "group": "boost", "status": "keen"},
}
const BOOSTS := ["haste", "frenzy", "keen"]
const HEAL_PCT := 0.35
const BOOST_TIME := 10.0
const COOLDOWN := 20.0
const START_HEAL := 2
const ICON := "res://assets/ui/potions/%s.png"
## Recharge restante par groupe (secondes de jeu, décomptées par [method tick]).
static var _cd := {"heal": 0.0, "boost": 0.0}


static func key(kind: String) -> String:
	return "potion:" + kind


static func is_potion(k: String) -> bool:
	return k.begins_with("potion:") and KINDS.has(k.get_slice(":", 1))


static func kind_of(k: String) -> String:
	return k.get_slice(":", 1)


static func count(kind: String) -> int:
	return Profile.bag_count(key(kind))


static func icon_path(kind: String) -> String:
	return ICON % kind


## Les potions servent-elles dans ce mode ? (en run, pas en duel).
static func allowed() -> bool:
	return Run.active and not Duel.active


## Départ de run : au moins [constant START_HEAL] potions de soin, recharges remises à zéro.
static func start_run() -> void:
	_cd = {"heal": 0.0, "boost": 0.0}
	if Profile.bag_count(key("heal")) < START_HEAL:
		Profile.bag[key("heal")] = START_HEAL


static func tick(delta: float) -> void:
	for g in _cd:
		_cd[g] = maxf(0.0, float(_cd[g]) - delta)


static func cooldown_left(group: String) -> float:
	return float(_cd.get(group, 0.0))


## Potion d'effet qu'une pression sur V boira : la plus nombreuse du stock (ordre fixe à égalité) ; "" si aucune.
static func boost_to_use() -> String:
	var best := ""
	for k in BOOSTS:
		if count(k) > 0 and (best == "" or count(k) > count(best)):
			best = k
	return best


## Potion de l'emplacement [param slot] : 1 = soin, 2 = effet (la prochaine à boire).
static func kind_for_slot(slot: int) -> String:
	return "heal" if slot == 1 else boost_to_use()


## Boit la potion de l'emplacement [param slot] ; renvoie le message affiché ("" : rien ne s'est passé).
static func use(player: Player, slot: int) -> String:
	if not allowed() or player == null or player.is_dead:
		return ""
	var kind := kind_for_slot(slot)
	if kind == "":
		return "Aucune potion d'effet."
	var def: Dictionary = KINDS[kind]
	var group := String(def.group)
	if count(kind) <= 0:
		return "Plus de %s." % String(def.name).to_lower()
	if cooldown_left(group) > 0.0:
		return "%s : encore %d s." % [def.name, ceili(cooldown_left(group))]
	if kind == "heal" and player.hp >= player.max_hp - 0.5:
		return "Tes PV sont déjà pleins."
	Profile.take_bag(key(kind))
	_cd[group] = COOLDOWN
	if kind == "heal":
		player.heal(player.max_hp * HEAL_PCT)
		DamageNumber.spawn_text(player, "+PV", Color(0.5, 1.0, 0.55))
		Vfx.ring(player, player.global_position, 2.2, Color(0.4, 1.0, 0.5, 0.8))
	else:
		player.add_status(String(def.status), BOOST_TIME, player)
		Vfx.ring(player, player.global_position, 2.2, Color(def.color, 0.8))
	Sfx.ui("pickup", -4.0)
	Profile.record_add("potions_used", 1)
	return "%s bue (%d restante%s)" % [def.name, count(kind), "s" if count(kind) > 1 else ""]


static func grant(kind: String, n := 1) -> void:
	if KINDS.has(kind):
		Profile.add_bag(key(kind), n)


## Potion tirée au sort pour une source de butin : le soin domine.
static func roll_kind() -> String:
	return "heal" if randf() < 0.6 else BOOSTS.pick_random()


static func label(kind: String) -> String:
	return String(KINDS[kind].name)
