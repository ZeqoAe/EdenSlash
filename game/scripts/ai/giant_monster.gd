class_name GiantMonster
extends Monster
## Géant de l'autel du géant (passe P12, voir Menace et GiantAltar) : un monstre ordinaire de la zone agrandi
## (≈ ×2,8), avec les PV d'une escouade d'élites et des coups d'élite renforcés, mais lent et lisible :
## une attaque sur deux est une grande zone au sol annoncée longtemps (écrasement sous le héros, onde à
## sauter, balayage en éventail). Jamais de coup fatal d'un seul tenant : un coup retire au plus HIT_CAP des
## PV max du héros visé.

const SIZE := 2.8  # taille par rapport au monstre de la zone (le drapeau d'élite compte déjà ×1,25)
const HP_ELITES := 8.0  # PV : 8 élites de la zone au même niveau
const ATK_ELITES := 1.6  # un coup : 1,6 coup d'élite
const XP_ELITES := 3.0  # expérience bornée : 3 élites (pas une ferme d'XP)
const HIT_CAP := 0.3  # part des PV max du héros qu'un coup retire au plus
const SPEED := 0.72  # vitesse de marche (× celle du monstre)
## Attaques spéciales, à tour de rôle, une attaque sur deux : forme, délai d'annonce, dégâts (× le coup).
const SPECIALS := [
	{"id": "slam", "delay": 1.25, "mult": 1.4, "radius": 5.5},
	{"id": "quake", "delay": 1.4, "mult": 1.0, "radius": 12.0, "inner": 2.6},
	{"id": "sweep", "delay": 1.1, "mult": 1.2, "radius": 9.0, "angle": 160.0},
]

## Données d'une élite de la zone : référence des PV, des dégâts et de l'expérience (vide : le monstre lui-même).
var ref_elite: Dictionary = {}
var spawned_at := 0.0  # instant de l'apparition (mesures : temps pour le vaincre)
var _attack_n := 0


func configure(monster_data: Dictionary, _boss := false, at_level := 0) -> void:
	super.configure(monster_data, false, at_level)
	is_elite = true  # repoussé à peine, nom et effets affichés, jamais retiré de loin, récompenses d'élite
	var ref: Dictionary = ref_elite if not ref_elite.is_empty() else monster_data
	var rk := pow(1.1, level - int(ref.get("level", level)))
	# élite de référence : PV ×1,6 et dégâts ×1,25 (Monster.configure) ; sans élite dans la zone, un monstre
	# ordinaire vaut à peu près le quart d'une élite en PV et les deux tiers en dégâts (données d'Eden)
	var hp_k := 1.6 if not ref_elite.is_empty() else 2.4 * 2.7
	var atk_k := 1.25 if not ref_elite.is_empty() else 1.9
	max_hp = float(ref.hp) * rk * hp_k * HP_ELITES
	hp = max_hp
	atk = float(ref.atk) * rk * GameData.MONSTER_DAMAGE_FACTOR * atk_k * ATK_ELITES
	xp_reward = int(float(ref.xp) * rk * 4.0 * XP_ELITES)
	move_speed *= SPEED


func _ready() -> void:
	super._ready()
	display_name = "Géant · %s" % display_name
	if model:
		model.scale *= SIZE
		_base_scale = model.scale
	radius = clampf(radius * SIZE, 1.2, 3.2)
	for c in get_children():
		if c is CollisionShape3D and c.shape is CapsuleShape3D:
			var cap: CapsuleShape3D = c.shape
			cap.radius = radius
			cap.height = maxf(radius * 2.0, cap.height * SIZE)
			c.position.y = cap.height * 0.5
	if _status_label:
		_status_label.position.y = radius * 2.2 + 3.0
	# halo rouge sombre au sol : on le repère dans la foule
	var glow := OmniLight3D.new()
	glow.light_color = Color(1.0, 0.3, 0.15)
	glow.light_energy = 0.8
	glow.omni_range = radius * 2.5 + 2.0
	glow.shadow_enabled = false
	glow.position.y = 1.2
	add_child(glow)


## Portée : le géant frappe de plus loin (ses zones sont grandes).
func _attack_range() -> float:
	return radius + 4.5


## Coup le plus fort permis contre la cible (part de ses PV max).
func hit_cap() -> float:
	return (_player.max_hp if is_instance_valid(_player) else 1e9) * HIT_CAP


func _start_attack() -> void:
	_attack_n += 1
	if _attack_n % 2 == 1:
		super._start_attack()
		# coup ordinaire (cône, charge, tir) : plafonné
		if is_instance_valid(_telegraph):
			_telegraph.damage = minf(_telegraph.damage, hit_cap())
		if not _pending_shot.is_empty():
			_pending_shot.damage = minf(float(_pending_shot.damage), hit_cap())
		return
	_special(SPECIALS[(_attack_n / 2 - 1) % SPECIALS.size()])


## Attaque spéciale [param s] : le géant reste sur place, la zone se remplit pendant le délai, puis frappe.
func _special(s: Dictionary) -> void:
	_set_state("attack")
	var a := "magic01" if has_anim("magic01") else String(_attacks.pick_random())
	var keys := keys_of(a)
	var hits: Array = keys.get("hit", [])
	var length := maxf(anim_length(a), 0.3)
	var hit_t := float(hits[0]) if not hits.is_empty() else length * HIT_FRACTION
	var delay := float(s.delay)
	var speed := hit_t / delay
	_state_len = length / speed + 0.35  # un temps de récupération après le coup : la fenêtre pour frapper
	_hit_time = delay
	_hit_done = false
	play(a, 0.1, speed, true)
	var to := _player.global_position - global_position
	to.y = 0.0
	face_direction(to, 1.0, 100.0)
	var dmg := minf(atk * damage_dealt_mult() * float(s.mult), hit_cap())
	var props := {"delay": delay, "damage": dmg, "source": self}
	var at := global_position
	var yaw := 0.0
	match String(s.id):
		"slam":  # écrasement : un grand cercle sous le héros
			props.merge({"shape": "circle", "radius": float(s.radius)})
			at = _player.global_position
		"quake":  # onde de choc autour du géant : à sauter, ou à fuir
			props.merge({"shape": "ring", "radius": float(s.radius), "inner": float(s.inner), "jumpable": true})
		_:  # balayage en éventail devant lui
			props.merge({"shape": "cone", "radius": float(s.radius), "angle": float(s.angle)})
			yaw = atan2(to.x, to.z)
	_telegraph = Telegraph.spawn(self, at, yaw, props)
	var r := float(s.radius)
	_telegraph.resolved.connect(func(_hit: bool):
		if is_instance_valid(self) and not is_dead:
			Vfx.shockwave(self, at, r, Color(1.0, 0.45, 0.25)))
