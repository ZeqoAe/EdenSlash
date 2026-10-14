class_name WeaponAttacks
extends RefCounted
## Auto-attaque de chaque type d'arme (refonte 0.1.127, voir DESIGN.md « Auto-attaque des
## armes ») : plus de combo de 3 coups, ni d'étourdissement, d'attraction ou de saut. Une seule
## attaque répétée, faible au départ, qui grandit avec les cartes : chaque arme a sa forme et
## réagit à certaines statistiques (projectiles, perforation, rebonds, zone, portée, vitesse
## d'attaque ou d'incantation, critique, effets sur la durée).
##
## Formes (« shape ») :
##   slash  : coup en arc devant le héros (rayon × zone) ;
##   thrust : estoc en ligne (longueur × portée) ;
##   slam   : impact au sol devant le héros (rayon × zone) ;
##   nova   : onde tout autour du héros (rayon × zone) ;
##   bolt   : projectiles (nombre + projectiles, portée × portée, perforation, rebonds,
##            explosion à l'impact × zone) ;
##   cast   : incantation puis zone au point visé après [code]delay[/code] s (cadence et délai
##            réglés par la vitesse d'incantation, rayon × zone, distance × portée,
##            + projectiles = zones en plus autour de la cible).
## Les armes de mêlée transforment « + projectiles » en frappes supplémentaires.
## Certaines armes ont deux variantes : le modèle d'Eden de l'arme décide laquelle (une même
## arme garde toujours la sienne).

## Arme secondaire : part de ses dégâts et de ses statistiques d'objet.
const OFFHAND_DMG := 0.6
const OFFHAND_STATS := 0.5
## Cadence de base (attaques par seconde à 100 % de vitesse, × speed de l'arme) : celle de
## l'arme secondaire, qui frappe seule sans animation.
const BASE_RATE := 1.1

## Statistiques auxquelles une arme réagit (affichées dans le grimoire et les infobulles).
const SCALE_TEXT := {
	"proj": "Projectiles", "hits": "Frappes (cartes de projectiles)", "pierce": "Perforation", "bounce": "Rebonds",
	"area": "Zone", "reach": "Portée", "atk_speed": "Vitesse d'attaque", "cast_speed": "Vitesse d'incantation",
	"crit": "Critique", "dot": "Effets sur la durée", "heal": "Puissance de soin",
}

const SPECS := {
	"katana": [{"name": "Iaï", "shape": "slash", "anims": ["attack25", "attack26"], "mult": 0.8, "radius": 2.9, "arc": 140,
		"speed": 1.1, "crit_bonus": 0.1, "hit_fx": "s00141", "scales": ["hits", "area", "atk_speed", "crit"],
		"desc": "Taille rapide en arc devant toi (+10 % de critique)."}],
	"axe": [{"name": "Taille large", "shape": "slash", "anims": ["attack08", "attack09"], "mult": 1.1, "radius": 3.3, "arc": 200,
		"speed": 0.85, "hit_fx": "s00241", "scales": ["hits", "area", "atk_speed"],
		"desc": "Lent et large : la hache balaie tout ce qui est devant toi."}],
	"dagger": [
		{"name": "Lacération", "shape": "slash", "anims": ["attack05", "attack06"], "mult": 0.42, "radius": 2.5, "arc": 360,
			"speed": 1.35, "applies": {"bleed": 3.0}, "hit_fx": "s00141", "scales": ["hits", "area", "atk_speed", "dot"],
			"desc": "Les dagues tournoient autour de toi et font saigner (3 s)."},
		{"name": "Dagues de lancer", "shape": "bolt", "anims": ["attack06"], "mult": 0.45, "count": 2, "spread": 12.0, "range": 9.0,
			"speed": 1.3, "projectile": "shadow", "applies": {"bleed": 2.0}, "hit_fx": "s00141",
			"scales": ["proj", "pierce", "reach", "atk_speed", "dot"],
			"desc": "Lance 2 dagues qui font saigner (2 s)."}],
	"bow": [
		{"name": "Flèche", "shape": "bolt", "anims": ["attack12"], "mult": 0.85, "count": 1, "range": 13.0, "speed": 1.0,
			"projectile": "arrow", "hit_fx": "s00141", "scales": ["proj", "pierce", "bounce", "reach", "atk_speed"],
			"desc": "Une flèche rapide ; chaque projectile en plus ajoute une flèche à la volée."},
		{"name": "Flèche perçante", "shape": "bolt", "anims": ["attack12"], "mult": 0.7, "count": 1, "pierce": 2, "range": 15.0,
			"speed": 0.85, "projectile": "lightning", "hit_fx": "s00141", "scales": ["proj", "pierce", "reach", "atk_speed"],
			"desc": "Tir tendu qui traverse 2 ennemis, de très loin."}],
	"scepter": [{"name": "Éclat sacré", "shape": "cast", "anims": ["attack10", "attack11"], "mult": 0.85, "radius": 2.3,
		"range": 9.0, "delay": 0.25, "speed": 1.0, "heal_on_hit": 0.004, "hit_fx": "s19141",
		"scales": ["proj", "area", "reach", "cast_speed", "heal"],
		"desc": "Une lumière éclate au point visé ; chaque ennemi touché te soigne un peu."}],
	"staff": [
		{"name": "Météore arcanique", "shape": "cast", "anims": ["attack14"], "mult": 1.5, "radius": 2.8, "range": 10.0,
			"delay": 0.65, "speed": 0.8, "hit_fx": "s12141", "scales": ["proj", "area", "reach", "cast_speed"],
			"desc": "Incantation, puis une explosion tombe au point visé. La vitesse d'incantation raccourcit tout."},
		{"name": "Boule de feu", "shape": "bolt", "anims": ["attack14"], "mult": 1.0, "count": 1, "explode": 2.0, "range": 11.0,
			"speed": 0.85, "projectile": "fire", "hit_fx": "s00341", "rate": "cast_speed",
			"scales": ["proj", "area", "reach", "cast_speed"],
			"desc": "Une boule de feu qui explose au premier ennemi touché (2 m)."}],
	"sword": [{"name": "Taille", "shape": "slash", "anims": ["attack01", "attack02"], "mult": 0.85, "radius": 2.9, "arc": 160,
		"speed": 1.0, "hit_fx": "s00141", "scales": ["hits", "area", "atk_speed"],
		"desc": "Coup d'épée équilibré devant toi."}],
	"rapier": [{"name": "Estoc", "shape": "thrust", "anims": ["attack17", "attack18"], "mult": 0.8, "radius": 4.2, "arc": 30,
		"speed": 1.25, "hit_fx": "s00141", "scales": ["hits", "reach", "atk_speed", "crit"],
		"desc": "Estocade rapide qui transperce la ligne d'ennemis (longueur × portée)."}],
	"greatsword": [{"name": "Taille lourde", "shape": "slash", "anims": ["attack08", "attack09"], "mult": 1.35, "radius": 3.5,
		"arc": 180, "speed": 0.75, "hit_fx": "s00241", "scales": ["hits", "area", "atk_speed"],
		"desc": "Lente mais lourde, l'espadon fauche large."}],
	"hammer": [{"name": "Impact", "shape": "slam", "anims": ["attack08", "attack09"], "mult": 1.3, "radius": 2.4, "offset": 1.8,
		"speed": 0.8, "hit_fx": "s00541", "scales": ["hits", "area", "atk_speed"],
		"desc": "Le marteau frappe le sol devant toi : zone ronde."}],
	"rod": [{"name": "Trait d'ombre", "shape": "bolt", "anims": ["attack10", "attack11"], "mult": 0.8, "count": 1, "bounce": 1,
		"range": 10.0, "speed": 1.0, "projectile": "dark", "hit_fx": "s00341", "scales": ["proj", "bounce", "reach", "atk_speed"],
		"desc": "Projectile des ténèbres qui rebondit sur un 2e ennemi."}],
	"cestus": [{"name": "Directs", "shape": "slash", "anims": ["attack21", "attack22"], "mult": 0.42, "radius": 2.5, "arc": 110,
		"speed": 1.6, "hit_fx": "s00141", "scales": ["hits", "atk_speed", "crit"],
		"desc": "Coups de poing très rapides : la vitesse d'attaque compte double."}],
	"cannon": [{"name": "Obus", "shape": "bolt", "anims": ["attack13"], "mult": 1.1, "count": 1, "explode": 2.2, "range": 12.0,
		"speed": 0.75, "projectile": "fire", "hit_fx": "s00341", "scales": ["proj", "area", "reach", "atk_speed"],
		"desc": "Obus lent qui explose à l'impact (2,2 m)."}],
	"spear": [{"name": "Estoc de lance", "shape": "thrust", "anims": ["attack07"], "mult": 1.0, "radius": 4.8, "arc": 40,
		"speed": 0.95, "hit_fx": "s00141", "scales": ["hits", "reach", "atk_speed"],
		"desc": "Longue estocade en ligne (longueur × portée)."}],
	"guitar": [{"name": "Onde sonore", "shape": "nova", "anims": ["attack15"], "mult": 0.7, "radius": 3.8, "speed": 0.9,
		"dmg_type": "mag", "hit_fx": "s00341", "scales": ["hits", "area", "atk_speed"],
		"desc": "Un accord résonne tout autour de toi."}],
	"grimoire": [{"name": "Pages arcaniques", "shape": "bolt", "anims": ["attack16"], "mult": 0.5, "count": 2, "spread": 16.0,
		"range": 11.0, "speed": 1.0, "projectile": "magic", "hit_fx": "s00341", "rate": "cast_speed",
		"scales": ["proj", "pierce", "reach", "cast_speed"],
		"desc": "Deux pages arcaniques en éventail ; les projectiles en plus élargissent la volée."}],
	"gunscythe": [{"name": "Faux", "shape": "slash", "anims": ["attack08", "attack09"], "mult": 1.0, "radius": 3.6, "arc": 220,
		"speed": 0.85, "hit_fx": "s00241", "scales": ["hits", "area", "atk_speed"],
		"desc": "Large coup de faux, presque tout autour de toi."}],
}


## Variantes du type [param wtype].
static func variants(wtype: String) -> Array:
	return SPECS.get(wtype, SPECS.katana)


## Auto-attaque de l'arme [param item] (sa variante suit son modèle d'Eden) ; sans arme, celle
## du type [param wtype].
static func spec_for(item: Dictionary, wtype := "") -> Dictionary:
	if wtype == "":
		wtype = Items.weapon_type_of(item) if not item.is_empty() else "katana"
	var vs := variants(wtype)
	var i := variant_index(item, vs.size())
	var s: Dictionary = vs[i].duplicate()
	s["wtype"] = wtype
	s["variant"] = i
	if not s.has("dmg_type"):
		s["dmg_type"] = String(GameData.weapon_type(wtype).get("dmg_type", "phys"))
	return s


static func variant_index(item: Dictionary, n: int) -> int:
	if n <= 1 or item.is_empty():
		return 0
	if item.has("auto_variant"):
		return clampi(int(item.auto_variant), 0, n - 1)
	var key := str(item.get("eden", item.get("weapon", "")))
	return absi(key.hash()) % n


## Statistique de cadence de l'arme : vitesse d'incantation (incantations, boule de feu,
## pages) ou vitesse d'attaque.
static func rate_stat(s: Dictionary) -> String:
	return String(s.get("rate", "cast_speed" if String(s.get("shape", "")) == "cast" else "atk_speed"))


## Portée de visée (lancement automatique, IA).
static func reach(s: Dictionary, reach_mult: float, area_mult: float) -> float:
	match String(s.get("shape", "slash")):
		"bolt", "cast":
			return float(s.get("range", 10.0)) * reach_mult
		"thrust":
			return float(s.get("radius", 4.0)) * reach_mult
		"slam":
			return float(s.get("offset", 1.8)) + float(s.get("radius", 2.4)) * area_mult
	return float(s.get("radius", 2.8)) * area_mult


## Action de combat de l'auto-attaque [param s] pour le héros [param p] (attaque de base de
## Player : mêmes champs que les compétences).
static func action_for(s: Dictionary, p: Player) -> Dictionary:
	var shape := String(s.get("shape", "slash"))
	var extra := p.extra_proj
	var a := {"mult": float(s.get("mult", 1.0)), "dmg_type": String(s.get("dmg_type", "phys")), "hit_fx": String(s.get("hit_fx", "s00141")),
		"applies": s.get("applies", {}), "crit_bonus": float(s.get("crit_bonus", 0.0)), "basic": true, "shape": shape,
		"heal_on_hit": float(s.get("heal_on_hit", 0.0))}
	match shape:
		"bolt":
			a["kind"] = "bolt"
			a["range"] = float(s.get("range", 10.0)) * p.reach_mult
			a["projectile"] = String(s.get("projectile", "arrow"))
			a["volley"] = int(s.get("count", 1)) + extra
			a["spread"] = float(s.get("spread", 10.0)) + 8.0 * extra
			a["pierce"] = int(s.get("pierce", 0)) + p.pierce_bonus
			a["bounce"] = int(s.get("bounce", 0)) + p.bounce_bonus
			if s.has("explode"):
				a["explode"] = float(s.explode) * p.area_mult
			a["radius"] = 0.0
			a["hits"] = 1  # une volée par attaque, quel que soit le nombre d'impacts de l'animation
		"cast":
			a["kind"] = "cast"
			a["range"] = float(s.get("range", 10.0)) * p.reach_mult
			a["radius"] = float(s.get("radius", 2.5)) * p.area_mult
			a["arc"] = 360.0
			a["delay"] = float(s.get("delay", 0.4)) / maxf(p.cast_speed, 0.2)
			a["zones"] = 1 + extra
			a["hits"] = 1
		"thrust":
			a["radius"] = float(s.get("radius", 4.0)) * p.reach_mult
			a["arc"] = float(s.get("arc", 30.0))
			a["hits"] = 1 + extra
		"slam":
			a["kind"] = "slam"
			a["radius"] = float(s.get("radius", 2.4)) * p.area_mult
			a["offset"] = float(s.get("offset", 1.8))
			a["arc"] = 360.0
			a["hits"] = 1 + extra
		"nova":
			a["radius"] = float(s.get("radius", 3.6)) * p.area_mult
			a["arc"] = 360.0
			a["hits"] = 1 + extra
		_:
			a["radius"] = float(s.get("radius", 2.8)) * p.area_mult
			a["arc"] = float(s.get("arc", 150.0))
			a["hits"] = 1 + extra
	return a


## Coup au format de l'ancien combo (adversaire scripté ClassRival : animation, zone, tir).
static func rival_step(wtype: String) -> Dictionary:
	var s := spec_for({}, wtype)
	var step := {"name": s.name, "anim": String(s.anims[0]), "mult": float(s.mult), "radius": float(s.get("radius", 2.8)),
		"arc": float(s.get("arc", 360.0)), "hit_fx": String(s.get("hit_fx", ""))}
	match String(s.shape):
		"bolt":
			step["bolt"] = true
			step["volley"] = int(s.get("count", 1))
			step["range"] = float(s.get("range", 10.0))
		"cast":
			step["kind"] = "ground"
			step["range"] = float(s.get("range", 10.0))
	return step


## Texte du grimoire / des infobulles (BBCode) ; [param atk] : attaque du héros (-1 : sans
## les dégâts chiffrés).
static func bbcode(s: Dictionary, atk := -1.0, offhand := false) -> String:
	var mult := float(s.get("mult", 1.0)) * (OFFHAND_DMG if offhand else 1.0)
	var magic := String(s.get("dmg_type", "phys")) == "mag"
	var lines: PackedStringArray = []
	lines.append("[b][color=#ffcf6b]%s[/color][/b]  [color=#9a98a8](auto-attaque%s)[/color]" % [s.get("name", "?"), " de l'arme secondaire" if offhand else ""])
	lines.append("[color=#e6e2f0]%s[/color]" % String(s.get("desc", "")))
	var dmg := "%d %% de l'attaque %s" % [roundi(mult * 100.0), "magique" if magic else "physique"]
	if atk > 0.0:
		dmg += " (≈ %d)" % roundi(atk * mult)
	lines.append("Dégâts : [b]%s[/b]%s" % [dmg, " par projectile" if String(s.shape) == "bolt" else ""])
	var bits: PackedStringArray = []
	if s.has("count") and int(s.count) > 1:
		bits.append("%d projectiles" % int(s.count))
	if int(s.get("pierce", 0)) > 0:
		bits.append("perce %d" % int(s.pierce))
	if int(s.get("bounce", 0)) > 0:
		bits.append("%d rebond" % int(s.bounce))
	if s.has("explode"):
		bits.append("explosion %s m" % String.num(float(s.explode), 1))
	if s.has("delay"):
		bits.append("incantation, impact après %s s" % String.num(float(s.delay), 2))
	if s.has("range"):
		bits.append("%d m" % roundi(float(s.range)))
	elif s.has("radius"):
		bits.append("%s m" % String.num(float(s.radius), 1))
	for st in s.get("applies", {}):
		bits.append("%s %s s" % [StatusDb.display_name(String(st)), String.num(float(s.applies[st]), 1)])
	if not bits.is_empty():
		lines.append("[color=#c8c8d4]%s[/color]" % " · ".join(bits))
	var sc: PackedStringArray = []
	for k in s.get("scales", []):
		sc.append(String(SCALE_TEXT.get(k, k)))
	lines.append("[color=#7fd0ff]Grandit avec : %s[/color]" % ", ".join(sc))
	if offhand:
		lines.append("[color=#9a98a8]Arme secondaire : frappe seule (%d %% des dégâts, %d %% de ses stats d'objet).[/color]" % [roundi(OFFHAND_DMG * 100.0), roundi(OFFHAND_STATS * 100.0)])
	return "\n".join(lines)
