class_name AssaultCombat
extends RefCounted
## Règles de combat de L'Assaut (lot TAC-4, étude conception/benchmark/TACTIQUE.md § 7.5 et 7.6, rapport R_TAC_4.md) : une vie
## par manche demande des combats courts et lisibles — un 1 contre 1 de 7 à 10 s, personne à terre en moins de ~3,5 s depuis
## la pleine vie — et des règles GÉNÉRALES plutôt que 60 retouches de classes :
## - kit tactique de 4 sorts par classe, généré par tools/assault_kits.py (data/assault_kits.json : signature gratuite,
##   cases 2 et 3 achetées au lot TAC-5, ultime chargé par points) ; rôle tactique (5 rôles d'après data/autochess_units.json) ;
## - contrôles × cc_mult puis plafonnés par type (cc_caps), insensibilité COMMUNE à tous les contrôles durs pendant
##   cc_immunity s après chacun (au lieu d'une insensibilité par type), ralenti borné (chill_slow) ;
## - invisibilité bornée (invis_max), brisée par un coup reçu, impossible en portant, posant ou désamorçant la Charge ;
## - boucliers et réductions : dégâts subis jamais sous min_taken (barrière ×0,8, mur du titan ×0,7 dans ce mode) ;
## - soins plafonnés à heal_cap des PV max par manche (ceux d'un Soutien comptent moitié) ;
## - chute de portée : un coup venu de plus de falloff_at m compte × falloff (Tireur : tireur_falloff_at) ;
## - passifs de rôle (role_hp, role_tenacity, esquive de plus de l'Ouvreur, prise à revers, cible révélée par le Tireur).
## Tout est lu dans le profil « assault » (Assault.rule : mode dev et modificateurs compris) et ne joue que pendant une partie
## de L'Assaut (on()) : les points d'appel du combat commun (Combatant, Player, ClassRival, Telegraph, Monster) sont gardés.

const HARD := ["stun", "freeze", "sleep", "fear", "root"]
const KITS_PATH := "res://data/assault_kits.json"
## Rôles tactiques (§ 7.6) : nom, couleur (bonbon de la bible), passif en mots (sans pourcentage : l'infobulle chiffre).
const ROLES := {
	"rempart": {"name": "Rempart", "color": "soleil", "passive": "Plus de vie ; les contrôles subis durent moins"},
	"ouvreur": {"name": "Ouvreur", "color": "mandarine", "passive": "Une esquive de plus ; frappe plus fort qui ne l'a pas vu venir"},
	"tireur": {"name": "Tireur", "color": "pomme", "passive": "Porte plus loin ; sa cible reste un instant révélée à son équipe"},
	"controleur": {"name": "Contrôleur", "color": "amethyste", "passive": "Utilitaires moins chers ; ses zones durent plus longtemps"},
	"soutien": {"name": "Soutien", "color": "lagon", "passive": "Voit la vie de son équipe ; ses soins pèsent moins dans la limite"},
}
const ROLE_ORDER := ["rempart", "ouvreur", "tireur", "controleur", "soutien"]

static var _kits: Dictionary = {}
## Héros qui soigne en ce moment (ClassRival._support_tick, Player._heal_action) : ses soins comptent moitié s'il est Soutien.
static var healer: Combatant = null


## Une partie de L'Assaut est-elle en cours ? (garde de tous les points d'appel du combat commun)
static func on() -> bool:
	return TeamMatch.active and TeamMatch.mode == "assault"


# --- kits et rôles -------------------------------------------------------------------------------

static func kits() -> Dictionary:
	if _kits.is_empty() and FileAccess.file_exists(KITS_PATH):
		var j = JSON.parse_string(FileAccess.get_file_as_string(KITS_PATH))
		if j is Dictionary:
			_kits = j
	return _kits


static func kit(cid: String) -> Dictionary:
	return kits().get(cid, {})


## Les 4 cases du kit de [param cid] : [{id, name, nature, kind, free | price | ult, points, radius_mult}].
static func slots(cid: String) -> Array:
	return kit(cid).get("slots", [])


## Ids des 4 sorts du kit (case 1 à 4) ; [] si la classe n'a pas de kit.
static func kit_ids(cid: String) -> Array:
	return slots(cid).map(func(s): return int(s.id))


static func role_of_class(cid: String) -> String:
	return String(kit(cid).get("role", "ouvreur"))


static func role(c: Combatant) -> String:
	return String(c.get_meta("assault_role", "")) if c != null and is_instance_valid(c) else ""


static func role_name(r: String) -> String:
	return String(ROLES.get(r, {}).get("name", r))


## Sort de l'ultime de [param cid] (case 4) : son id (-1 sans kit).
static func ult_id(cid: String) -> int:
	var s := slots(cid)
	return int(s[3].id) if s.size() >= 4 else -1


## Héros scripté armé de son kit : les sorts offensifs des cases [param owned] (indices 0-3 ; l'ultime ne s'y met qu'avec
## ses points, lot TAC-5) vont à ses sorts, soins et renforts à son soutien ; puis son rôle et ses passifs.
static func arm_rival(r: ClassRival, cid: String, owned: Array = [0, 1, 2]) -> void:
	var by_id := {}
	for s in GameData.class_data(cid).get("skills", []):
		by_id[int(s.id)] = s
	var off: Array = []
	var sup: Array = []
	var sl := slots(cid)
	for i in sl.size():
		if not i in owned:
			continue
		var sd = by_id.get(int(sl[i].id))
		if sd == null:
			continue
		if String(sd.kind) in ["buff", "heal"]:
			sup.append(sd)
		else:
			off.append(sd)
	if not off.is_empty() or not sup.is_empty():
		r._skills = off
		r._support = sup
	set_role(r, role_of_class(cid))


## Pose le rôle [param rl] sur [param c] et ses passifs : PV (Rempart), ténacité (Rempart), esquive de plus (Ouvreur).
static func set_role(c: Combatant, rl: String) -> void:
	c.set_meta("assault_role", rl)
	var hp_k := float((Assault.rule("role_hp") as Dictionary).get(rl, 1.0))
	c.set_meta("assault_hp_mult", hp_k)
	c.set_meta("assault_tenacity", float((Assault.rule("role_tenacity") as Dictionary).get(rl, 0.0)))
	if c is ClassRival:
		var r := c as ClassRival
		if not r.has_meta("assault_base_hp"):
			r.set_meta("assault_base_hp", r.max_hp)
		r.max_hp = float(r.get_meta("assault_base_hp")) * hp_k * float(r.get_meta("assault_item_hp", 1.0))
		r.hp = r.max_hp
		if rl == "ouvreur" and not r.has_meta("assault_extra_dodge"):
			r.set_meta("assault_extra_dodge", true)
			r.cfg = (r.cfg as Dictionary).duplicate()
			r.cfg["charges"] = int(r.cfg.charges) + int(Assault.num("ouvreur_dodges"))
			r._charges = float(r.cfg.charges)
	elif c is Player:
		(c as Player).recalc_stats()


## Fiche du joueur en Assaut (Player.recalc_stats, avant le calcul des PV) : passifs de rôle et achats (lot TAC-5).
static func sheet(p: Player) -> void:
	p.max_hp *= float(p.get_meta("assault_hp_mult", 1.0)) * float(p.get_meta("assault_item_hp", 1.0))
	p.dmg_mult *= float(p.get_meta("assault_dmg_mult", 1.0))


## Zone d'un sort : l'ultime du kit a sa zone × radius_mult (case 4).
static func radius_mult(c: Combatant, s: Dictionary) -> float:
	var cid := String(c.get("class_id") if c is Player else c.get("cid"))
	return Assault.num("ult_radius") if int(s.get("id", -2)) == ult_id(cid) else 1.0


# --- contrôles ---------------------------------------------------------------------------------------

## Ténacité de [param c] (0-0,8) : rôle (Rempart) et Talisman (lot TAC-5) se multiplient.
static func tenacity(c: Combatant) -> float:
	var a := float(c.get_meta("assault_tenacity", 0.0))
	var b := float(c.get_meta("assault_tenacity_item", 0.0))
	return clampf(1.0 - (1.0 - a) * (1.0 - b), 0.0, 0.8)


## Durée d'un contrôle [param status] de [param d] s sur [param c] : × cc_mult × (1 − ténacité), plafond du type.
static func cc_duration(c: Combatant, status: String, d: float) -> float:
	var caps: Dictionary = Assault.rule("cc_caps")
	if not caps.has(status):
		return d
	return minf(d * Assault.num("cc_mult") * (1.0 - tenacity(c)), float(caps[status]))


## Durée d'un effet posé sur [param c] (Combatant.add_status) : contrôles réglés, invisibilité bornée et refusée à qui porte,
## pose ou désamorce la Charge (méta assault_busy, posée par le directeur) ; 0 = refusé.
static func status_duration(c: Combatant, status: String, d: float) -> float:
	if status == "invisible":
		if bool(c.get_meta("assault_busy", false)):
			return 0.0
		return minf(d, Assault.num("invis_max"))
	return cc_duration(c, status, d)


## Insensibilité commune (Combatant._cc_gate) : après un contrôle dur, plus aucun contrôle dur pendant sa durée +
## cc_immunity s ; pas deux contrôles durs à la fois. Le désarmement garde son insensibilité propre. Vrai = il passe.
static func cc_gate(c: Combatant, status: String, d: float) -> bool:
	if status in HARD:
		var refused := c.has_status("imm_cc")
		for h in HARD:
			refused = refused or c.has_status(h)
		if refused:
			if c.has_status("imm_cc") and c.clock - c._cc_msg_at > 2.0:
				c._cc_msg_at = c.clock
				DamageNumber.spawn_text(c, "INSENSIBLE", Color(0.75, 0.85, 1.0))
			return false
		c.statuses["imm_cc"] = c.clock + d + Assault.num("cc_immunity")
		return true
	if status == "disarm":
		if c.has_status("disarm") or c.has_status("imm_disarm"):
			return false
		c.statuses["imm_disarm"] = c.clock + d + Assault.num("cc_immunity")
	return true


## Vitesse sous ralenti (Monster) : 1 − chill_slow.
static func chill_speed() -> float:
	return 1.0 - Assault.num("chill_slow")


# --- dégâts et soins -----------------------------------------------------------------------------------

## Coup de [param src] sur [param dst] (Combatant.take_damage, entre héros) : chute de portée, prise à revers de l'Ouvreur.
static func hit_mult(src: Combatant, dst: Combatant) -> float:
	if src == null or dst == null or not is_instance_valid(src):
		return 1.0
	var m := 1.0
	var d := Vector2(src.global_position.x - dst.global_position.x, src.global_position.z - dst.global_position.z).length()
	var at := Assault.num("tireur_falloff_at") if role(src) == "tireur" else Assault.num("falloff_at")
	if d > at:
		m *= Assault.num("falloff")
	if role(src) == "ouvreur" and AssaultVision.active():
		var t := TeamMatch.team_of(dst)
		var e = AssaultVision.current.last_seen(t).get(src.get_instance_id()) if t >= 0 else null
		if e == null or AssaultVision.current.time - float(e.t) > Assault.num("backstab_after"):
			m *= 1.0 + Assault.num("backstab")
	return m


## Après un coup encaissé : l'invisibilité se brise ; le Tireur révèle sa cible à son équipe.
static func on_hit(src: Combatant, dst: Combatant, dot: bool) -> void:
	if not dot and dst.statuses.has("invisible"):
		dst.statuses.erase("invisible")
		dst.statuses_changed.emit()
	if src != null and is_instance_valid(src) and role(src) == "tireur" and AssaultVision.active():
		var t := TeamMatch.team_of(src)
		if t >= 0:
			AssaultVision.current.reveal(t, dst, Assault.num("reveal_time"), src)


## Multiplicateur des dégâts subis (Combatant.damage_taken_mult) : barrière et mur du titan affaiblis, plancher min_taken.
static func taken_mult(c: Combatant, m: float) -> float:
	if c.has_status("barrier"):
		m *= Assault.num("barrier_taken") / 0.6
	if c.has_status("titan"):
		m *= Assault.num("titan_taken") / 0.5
	if c.has_status("assault_guard"):
		m *= 1.0 - Assault.num("guard_cut")  # (Fiole de garde, lot TAC-5)
	return maxf(m, Assault.num("min_taken")) if m < 1.0 else m


## Soin reçu par [param c] (Combatant.heal, après les règles du JcJ) : Enduit amer (lot TAC-5), plafond heal_cap des PV max par
## manche (méta assault_healed, remise à zéro par le directeur) ; les soins d'un Soutien comptent moitié ; le surplus ne compte pas.
static func heal_amount(c: Combatant, amount: float) -> float:
	if c.has_status("bitter"):
		amount *= 1.0 - Assault.num("bitter_cut")
	var eff := minf(amount, maxf(0.0, c.max_hp - c.hp))
	var k := 0.5 if healer != null and is_instance_valid(healer) and role(healer) == "soutien" else 1.0
	var used := float(c.get_meta("assault_healed", 0.0))
	var room := maxf(0.0, Assault.num("heal_cap") * c.max_hp - used)
	if eff * k > room:
		eff = room / k
	c.set_meta("assault_healed", used + eff * k)
	return eff


## Part du plafond de soins de la manche encore disponible (0-1 : la jauge du HUD, lot TAC-7).
static func heal_left(c: Combatant) -> float:
	var cap := Assault.num("heal_cap") * c.max_hp
	return clampf(1.0 - float(c.get_meta("assault_healed", 0.0)) / maxf(cap, 1.0), 0.0, 1.0)
