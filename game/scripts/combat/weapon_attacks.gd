class_name WeaponAttacks
extends RefCounted
## Auto-attaque de chaque type d'arme (refonte 0.1.127-0.1.128, voir DESIGN.md « Auto-attaque
## des armes ») : plus de combo de 3 coups, ni d'étourdissement, d'attraction ou de saut. Une
## seule attaque répétée, faible au départ, qui grandit avec les cartes : chaque arme a sa forme
## et réagit à certaines statistiques (projectiles, perforation, rebonds, zone, portée, vitesse
## d'attaque ou d'incantation, critique, effets sur la durée).
##
## Formes (« shape ») :
##   slash  : coup en arc devant le héros (rayon × zone) ;
##   thrust : estoc en ligne (longueur × portée) ;
##   slam   : impact au sol devant le héros (rayon × zone) ;
##   nova   : onde tout autour du héros (rayon × zone) ;
##   bolt   : projectiles (nombre + projectiles, portée × portée, perforation, rebonds,
##            explosion à l'impact × zone) ;
##   cast   : zone au point visé après [code]delay[/code] s (cadence et délai réglés par la
##            vitesse d'incantation, ou d'attaque si « rate », rayon × zone, distance × portée,
##            + projectiles = zones en plus autour de la cible).
## Les armes de mêlée transforment « + projectiles » en frappes supplémentaires ([code]hits[/code] :
## frappes de base).
## Chaque type d'arme a deux variantes : l'arme (son modèle d'Eden, ou « auto_variant » pour les
## armes proposées au choix) décide laquelle.
##
## Améliorations d'arme (cartes « weapon_up », Run.weapon_ups) : par emplacement (arme principale,
## arme secondaire), niveau 1 à MAX_RANK. Commune : dégâts ; rare : + un bonus mineur ; épique :
## + un bonus majeur ; légendaire : + l'effet légendaire de la variante (« sig »), puis, une fois
## acquis, deux bonus mineurs et un majeur.

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
	"katana": [
		{"name": "Iaï", "shape": "slash", "anims": ["attack25", "attack26"], "mult": 0.8, "radius": 2.9, "arc": 140,
			"speed": 1.1, "crit_bonus": 0.1, "hit_fx": "s00141", "scales": ["hits", "area", "atk_speed", "crit"], "favor": ["crit"],
			"desc": "Taille rapide en arc devant toi (+10 % de critique).",
			"sig": {"name": "Iaï parfait", "type": "every", "n": 4, "mult": 1.5, "crit": 1.0}},
		{"name": "Lame du vent", "shape": "bolt", "anims": ["attack25", "attack26"], "mult": 0.7, "count": 1, "pierce": 1,
			"range": 8.0, "speed": 1.05, "projectile": "lightning", "hit_fx": "s00141",
			"scales": ["proj", "pierce", "reach", "atk_speed", "crit"], "favor": ["crit", "reach"],
			"desc": "Le sabre lance une lame de vent qui traverse un ennemi.",
			"sig": {"name": "Tempête de lames", "type": "chain", "chance": 0.2, "mult": 0.7, "chain": 3, "cd": 0.8}}],
	"axe": [
		{"name": "Taille large", "shape": "slash", "anims": ["attack08", "attack09"], "mult": 1.1, "radius": 3.3, "arc": 200,
			"speed": 0.85, "hit_fx": "s00241", "scales": ["hits", "area", "atk_speed"], "favor": ["area"],
			"desc": "Lent et large : la hache balaie tout ce qui est devant toi.",
			"sig": {"name": "Entaille profonde", "type": "status", "applies": {"bleed": 3.0}}},
		{"name": "Hache de jet", "shape": "bolt", "anims": ["attack08", "attack09"], "mult": 0.95, "count": 1, "bounce": 2,
			"range": 9.0, "speed": 0.8, "projectile": "shadow", "applies": {"bleed": 2.0}, "hit_fx": "s00241",
			"scales": ["proj", "bounce", "reach", "atk_speed", "dot"], "favor": ["dot"],
			"desc": "Une hachette qui ricoche sur 2 ennemis et les fait saigner (2 s).",
			"sig": {"name": "Hachettes", "type": "every", "n": 3, "proj": 2}}],
	"dagger": [
		{"name": "Lacération", "shape": "slash", "anims": ["attack05", "attack06"], "mult": 0.42, "radius": 2.5, "arc": 360,
			"speed": 1.35, "applies": {"bleed": 3.0}, "hit_fx": "s00141", "scales": ["hits", "area", "atk_speed", "dot"], "favor": ["dot", "speed"],
			"desc": "Les dagues tournoient autour de toi et font saigner (3 s).",
			"sig": {"name": "Lames empoisonnées", "type": "status", "applies": {"poison": 3.0}}},
		{"name": "Dagues de lancer", "shape": "bolt", "anims": ["attack06"], "mult": 0.45, "count": 2, "spread": 12.0, "range": 9.0,
			"speed": 1.3, "projectile": "shadow", "applies": {"bleed": 2.0}, "hit_fx": "s00141",
			"scales": ["proj", "pierce", "reach", "atk_speed", "dot"], "favor": ["speed"],
			"desc": "Lance 2 dagues qui font saigner (2 s).",
			"sig": {"name": "Éventail", "type": "every", "n": 5, "proj": 3}}],
	"bow": [
		{"name": "Flèche", "shape": "bolt", "anims": ["attack12"], "mult": 0.85, "count": 1, "range": 13.0, "speed": 1.0,
			"projectile": "arrow", "hit_fx": "s00141", "scales": ["proj", "pierce", "bounce", "reach", "atk_speed", "crit"], "favor": ["crit"],
			"desc": "Une flèche rapide ; chaque projectile en plus ajoute une flèche à la volée.",
			"sig": {"name": "Volée", "type": "every", "n": 4, "proj": 2, "mult": 0.5}},
		{"name": "Pluie de flèches", "shape": "cast", "anims": ["attack12"], "mult": 0.75, "radius": 2.6, "range": 12.0,
			"delay": 0.35, "speed": 0.9, "rate": "atk_speed", "hit_fx": "s00141",
			"scales": ["proj", "area", "reach", "atk_speed"], "favor": ["area"],
			"desc": "Les flèches retombent en pluie sur le point visé ; chaque projectile en plus ajoute une zone.",
			"sig": {"name": "Flèches givrées", "type": "status", "applies": {"chill": 2.0}}}],
	"scepter": [
		{"name": "Éclat sacré", "shape": "cast", "anims": ["attack10", "attack11"], "mult": 0.85, "radius": 2.3,
			"range": 9.0, "delay": 0.25, "speed": 1.0, "heal_on_hit": 0.004, "hit_fx": "s19141",
			"scales": ["proj", "area", "reach", "cast_speed", "heal"], "favor": ["heal"],
			"desc": "Une lumière éclate au point visé ; chaque ennemi touché te soigne un peu.",
			"sig": {"name": "Jugement", "type": "every", "n": 4, "mult": 1.0, "area": 0.5}},
		{"name": "Orbe de lumière", "shape": "bolt", "anims": ["attack10", "attack11"], "mult": 0.7, "count": 1, "bounce": 2,
			"range": 9.0, "speed": 1.0, "projectile": "holy", "heal_on_hit": 0.003, "rate": "cast_speed", "hit_fx": "s19141",
			"scales": ["proj", "bounce", "reach", "cast_speed", "heal"], "favor": ["heal"],
			"desc": "Un orbe sacré qui ricoche sur 2 ennemis ; chaque impact te soigne un peu.",
			"sig": {"name": "Lumière divine", "type": "chain", "chance": 0.25, "mult": 0.6, "chain": 3, "cd": 0.8}}],
	"staff": [
		{"name": "Météore arcanique", "shape": "cast", "anims": ["attack14"], "mult": 1.5, "radius": 2.8, "range": 10.0,
			"delay": 0.65, "speed": 0.8, "hit_fx": "s12141", "scales": ["proj", "area", "reach", "cast_speed"], "favor": ["delay", "area"],
			"desc": "Incantation, puis une explosion tombe au point visé. La vitesse d'incantation raccourcit tout.",
			"sig": {"name": "Feu arcanique", "type": "status", "applies": {"burn": 3.0}}},
		{"name": "Boule de feu", "shape": "bolt", "anims": ["attack14"], "mult": 1.0, "count": 1, "explode": 2.0, "range": 11.0,
			"speed": 0.85, "projectile": "fire", "hit_fx": "s00341", "rate": "cast_speed",
			"scales": ["proj", "area", "reach", "cast_speed"], "favor": ["area"],
			"desc": "Une boule de feu qui explose au premier ennemi touché (2 m).",
			"sig": {"name": "Pyroclasme", "type": "every", "n": 4, "proj": 2, "area": 0.5}}],
	"sword": [
		{"name": "Taille", "shape": "slash", "anims": ["attack01", "attack02"], "mult": 0.85, "radius": 2.9, "arc": 160,
			"speed": 1.0, "hit_fx": "s00141", "scales": ["hits", "area", "atk_speed"],
			"desc": "Coup d'épée équilibré devant toi.",
			"sig": {"name": "Lame vengeresse", "type": "every", "n": 3, "mult": 1.0, "area": 0.5}},
		{"name": "Tourbillon", "shape": "nova", "anims": ["attack03"], "mult": 0.6, "radius": 2.8, "speed": 0.95,
			"hit_fx": "s00141", "scales": ["hits", "area", "atk_speed"], "favor": ["area"],
			"desc": "L'épée tournoie et frappe tout autour de toi.",
			"sig": {"name": "Onde d'acier", "type": "explode", "chance": 0.2, "mult": 0.8, "radius": 3.0, "cd": 0.5}}],
	"rapier": [
		{"name": "Estoc", "shape": "thrust", "anims": ["attack17", "attack18"], "mult": 0.8, "radius": 4.2, "arc": 30,
			"speed": 1.25, "hit_fx": "s00141", "scales": ["hits", "reach", "atk_speed", "crit"], "favor": ["crit"],
			"desc": "Estocade rapide qui transperce la ligne d'ennemis (longueur × portée).",
			"sig": {"name": "Point vital", "type": "every", "n": 3, "crit": 1.0, "mult": 0.5}},
		{"name": "Rafale d'estocs", "shape": "thrust", "anims": ["attack18", "attack19"], "mult": 0.32, "radius": 3.6, "arc": 30,
			"hits": 3, "speed": 1.0, "hit_fx": "s00141", "scales": ["hits", "reach", "atk_speed", "crit"], "favor": ["speed", "crit"],
			"desc": "Trois estocs rapides par attaque : idéal pour les effets à l'impact.",
			"sig": {"name": "Saignée", "type": "status", "applies": {"bleed": 2.0}}}],
	"greatsword": [
		{"name": "Taille lourde", "shape": "slash", "anims": ["attack08", "attack09"], "mult": 1.35, "radius": 3.5,
			"arc": 180, "speed": 0.75, "hit_fx": "s00241", "scales": ["hits", "area", "atk_speed"], "favor": ["area"],
			"desc": "Lente mais lourde, l'espadon fauche large.",
			"sig": {"name": "Fracas", "type": "explode", "chance": 0.3, "mult": 0.8, "radius": 3.5, "cd": 0.6}},
		{"name": "Onde tranchante", "shape": "bolt", "anims": ["attack08", "attack09"], "mult": 1.0, "count": 1, "pierce": 99,
			"range": 7.0, "speed": 0.75, "projectile": "lightning", "hit_fx": "s00241",
			"scales": ["proj", "reach", "atk_speed"], "favor": ["reach"],
			"desc": "Une onde d'acier qui traverse tous les ennemis sur 7 m.",
			"sig": {"name": "Double onde", "type": "every", "n": 3, "proj": 1, "mult": 0.5}}],
	"hammer": [
		{"name": "Impact", "shape": "slam", "anims": ["attack08", "attack09"], "mult": 1.3, "radius": 2.4, "offset": 1.8,
			"speed": 0.8, "hit_fx": "s00541", "scales": ["hits", "area", "atk_speed"], "favor": ["area"],
			"desc": "Le marteau frappe le sol devant toi : zone ronde.",
			"sig": {"name": "Séisme", "type": "every", "n": 4, "mult": 1.0, "area": 1.0}},
		{"name": "Onde sismique", "shape": "nova", "anims": ["attack09"], "mult": 0.75, "radius": 3.6, "speed": 0.75,
			"hit_fx": "s00541", "scales": ["hits", "area", "atk_speed"], "favor": ["area"],
			"desc": "Le sol tremble tout autour de toi.",
			"sig": {"name": "Marteau de tonnerre", "type": "chain", "chance": 0.25, "mult": 0.7, "chain": 3, "cd": 0.8}}],
	"rod": [
		{"name": "Trait d'ombre", "shape": "bolt", "anims": ["attack10", "attack11"], "mult": 0.8, "count": 1, "bounce": 1,
			"range": 10.0, "speed": 1.0, "projectile": "dark", "hit_fx": "s00341", "scales": ["proj", "bounce", "reach", "atk_speed"],
			"desc": "Projectile des ténèbres qui rebondit sur un 2e ennemi.",
			"sig": {"name": "Ténèbres", "type": "status", "applies": {"shock": 3.0}}},
		{"name": "Malédiction", "shape": "cast", "anims": ["attack10", "attack11"], "mult": 0.45, "radius": 2.0, "range": 9.0,
			"delay": 0.3, "speed": 1.0, "applies": {"poison": 4.0}, "rate": "cast_speed", "hit_fx": "s00341",
			"scales": ["proj", "area", "reach", "cast_speed", "dot"], "favor": ["dot"],
			"desc": "Une malédiction tombe au point visé et empoisonne (4 s).",
			"sig": {"name": "Contagion", "type": "explode", "chance": 0.25, "mult": 0.4, "radius": 3.0, "cd": 0.6, "applies": {"poison": 3.0}}}],
	"cestus": [
		{"name": "Directs", "shape": "slash", "anims": ["attack21", "attack22"], "mult": 0.42, "radius": 2.5, "arc": 110,
			"speed": 1.6, "hit_fx": "s00141", "scales": ["hits", "atk_speed", "crit"], "favor": ["speed"],
			"desc": "Coups de poing très rapides : la vitesse d'attaque compte double.",
			"sig": {"name": "Rafale du dragon", "type": "every", "n": 5, "proj": 3}},
		{"name": "Poing de chi", "shape": "bolt", "anims": ["attack21", "attack22"], "mult": 0.45, "count": 1, "pierce": 1,
			"range": 6.0, "speed": 1.4, "projectile": "magic", "hit_fx": "s00141",
			"scales": ["proj", "pierce", "reach", "atk_speed", "crit"], "favor": ["speed", "reach"],
			"desc": "Chaque coup projette une boule de chi (6 m) qui traverse un ennemi.",
			"sig": {"name": "Paume de foudre", "type": "chain", "chance": 0.2, "mult": 0.6, "chain": 3, "cd": 0.6}}],
	"cannon": [
		{"name": "Obus", "shape": "bolt", "anims": ["attack13"], "mult": 1.1, "count": 1, "explode": 2.2, "range": 12.0,
			"speed": 0.75, "projectile": "fire", "hit_fx": "s00341", "scales": ["proj", "area", "reach", "atk_speed"], "favor": ["area"],
			"desc": "Obus lent qui explose à l'impact (2,2 m).",
			"sig": {"name": "Obus incendiaires", "type": "status", "applies": {"burn": 3.0}}},
		{"name": "Mitraille", "shape": "bolt", "anims": ["attack13"], "mult": 0.3, "count": 4, "spread": 30.0, "range": 7.0,
			"speed": 0.9, "projectile": "arrow", "hit_fx": "s00141", "scales": ["proj", "pierce", "reach", "atk_speed"], "favor": ["reach"],
			"desc": "4 plombs en éventail, à courte portée.",
			"sig": {"name": "Chevrotine", "type": "every", "n": 4, "proj": 4}}],
	"spear": [
		{"name": "Estoc de lance", "shape": "thrust", "anims": ["attack07"], "mult": 1.0, "radius": 4.8, "arc": 40,
			"speed": 0.95, "hit_fx": "s00141", "scales": ["hits", "reach", "atk_speed"], "favor": ["reach"],
			"desc": "Longue estocade en ligne (longueur × portée).",
			"sig": {"name": "Plongeon du dragon", "type": "every", "n": 4, "mult": 1.0, "area": 0.4}},
		{"name": "Lance de jet", "shape": "bolt", "anims": ["attack07"], "mult": 0.9, "count": 1, "pierce": 3, "range": 14.0,
			"speed": 0.85, "projectile": "arrow", "hit_fx": "s00141", "scales": ["proj", "pierce", "reach", "atk_speed"], "favor": ["reach"],
			"desc": "Javelot lancé de loin qui traverse 3 ennemis.",
			"sig": {"name": "Lance foudroyante", "type": "explode", "chance": 0.3, "mult": 0.7, "radius": 3.0, "cd": 0.5}}],
	"guitar": [
		{"name": "Onde sonore", "shape": "nova", "anims": ["attack15"], "mult": 0.7, "radius": 3.8, "speed": 0.9,
			"dmg_type": "mag", "hit_fx": "s00341", "scales": ["hits", "area", "atk_speed"], "favor": ["area"],
			"desc": "Un accord résonne tout autour de toi.",
			"sig": {"name": "Distorsion", "type": "status", "applies": {"shock": 2.5}}},
		{"name": "Notes vagabondes", "shape": "bolt", "anims": ["attack15"], "mult": 0.5, "count": 2, "spread": 20.0, "bounce": 1,
			"range": 10.0, "speed": 0.95, "projectile": "magic", "dmg_type": "mag", "hit_fx": "s00341",
			"scales": ["proj", "bounce", "reach", "atk_speed"],
			"desc": "Deux notes qui ricochent chacune sur un 2e ennemi.",
			"sig": {"name": "Crescendo", "type": "every", "n": 4, "proj": 2, "mult": 0.5}}],
	"grimoire": [
		{"name": "Pages arcaniques", "shape": "bolt", "anims": ["attack16"], "mult": 0.5, "count": 2, "spread": 16.0,
			"range": 11.0, "speed": 1.0, "projectile": "magic", "hit_fx": "s00341", "rate": "cast_speed",
			"scales": ["proj", "pierce", "reach", "cast_speed"],
			"desc": "Deux pages arcaniques en éventail ; les projectiles en plus élargissent la volée.",
			"sig": {"name": "Pages foudroyantes", "type": "chain", "chance": 0.2, "mult": 0.6, "chain": 3, "cd": 0.6}},
		{"name": "Glyphe", "shape": "cast", "anims": ["attack16"], "mult": 1.2, "radius": 3.0, "range": 11.0, "delay": 0.7,
			"speed": 0.85, "applies": {"chill": 2.0}, "hit_fx": "s00341",
			"scales": ["proj", "area", "reach", "cast_speed"], "favor": ["delay", "area"],
			"desc": "Un glyphe s'inscrit au point visé puis éclate en ralentissant (2 s).",
			"sig": {"name": "Grand glyphe", "type": "every", "n": 3, "mult": 1.0, "area": 0.6}}],
	"gunscythe": [
		{"name": "Faux", "shape": "slash", "anims": ["attack08", "attack09"], "mult": 1.0, "radius": 3.6, "arc": 220,
			"speed": 0.85, "hit_fx": "s00241", "scales": ["hits", "area", "atk_speed"], "favor": ["area"],
			"desc": "Large coup de faux, presque tout autour de toi.",
			"sig": {"name": "Moisson", "type": "status", "applies": {"bleed": 3.0}}},
		{"name": "Salve", "shape": "bolt", "anims": ["attack08", "attack09"], "mult": 0.4, "count": 3, "spread": 14.0, "range": 10.0,
			"speed": 0.9, "projectile": "dark", "hit_fx": "s00341", "scales": ["proj", "pierce", "reach", "atk_speed"],
			"desc": "Le canon de la faux tire 3 balles en éventail.",
			"sig": {"name": "Balles maudites", "type": "explode", "chance": 0.2, "mult": 0.6, "radius": 2.5, "cd": 0.4}}],
}

# --- améliorations d'arme -------------------------------------------------------------------
const MAX_RANK := 8
## Dégâts de l'auto-attaque par carte, selon la rareté.
const UP_DMG := {"common": 0.15, "rare": 0.18, "epic": 0.22, "legendary": 0.3}
## Bonus mineurs (rare et mieux) et majeurs (épique et mieux) : valeur par carte.
const MINOR := {"crit": 0.05, "speed": 0.08, "area": 0.1, "reach": 0.12, "dot": 1.0, "heal": 0.002, "delay": 0.12}
const MAJOR := {"proj": 1, "pierce": 1, "bounce": 1, "big_area": 0.25, "explode": 0.8}
const UP_TEXT := {
	"dmg": ["Dégâts de l'auto-attaque", "%"], "crit": ["Critique de l'arme", "%"], "speed": ["Cadence de l'arme", "%"],
	"area": ["Zone de l'arme", "%"], "reach": ["Portée de l'arme", "%"], "dot": ["Durée de ses effets", "s"],
	"heal": ["Soin par ennemi touché", "pv"], "delay": ["Délai d'incantation", "-%"], "proj": ["Projectiles / frappes", "n"],
	"pierce": ["Perforation", "n"], "bounce": ["Rebonds", "n"], "explode": ["Rayon d'explosion", "m"],
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


## Nom de la variante de l'arme [param item] (« Arc · Pluie de flèches »).
static func variant_label(item: Dictionary) -> String:
	var s := spec_for(item)
	return "%s · %s" % [String(GameData.weapon_type(String(s.wtype)).get("name", s.wtype)), String(s.name)]


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
## Player : mêmes champs que les compétences) ; [param mods] : améliorations de l'emplacement
## (Run.weapon_ups).
static func action_for(s: Dictionary, p: Player, mods := {}) -> Dictionary:
	var shape := String(s.get("shape", "slash"))
	var extra := p.extra_proj + int(mods.get("proj", 0))
	var area := p.area_mult * (1.0 + float(mods.get("area", 0.0)))
	var reach_m := p.reach_mult * (1.0 + float(mods.get("reach", 0.0)))
	var applies: Dictionary = (s.get("applies", {}) as Dictionary).duplicate()
	for st in applies:
		applies[st] = float(applies[st]) + float(mods.get("dot", 0.0))
	var sig: Dictionary = s.get("sig", {}) if mods.get("sig", false) else {}
	if String(sig.get("type", "")) == "status":
		for st in sig.applies:
			applies[st] = maxf(float(applies.get(st, 0.0)), float(sig.applies[st]) + float(mods.get("dot", 0.0)))
	var a := {"mult": float(s.get("mult", 1.0)) * (1.0 + float(mods.get("dmg", 0.0))), "dmg_type": String(s.get("dmg_type", "phys")),
		"hit_fx": String(s.get("hit_fx", "s00141")), "applies": applies,
		"crit_bonus": float(s.get("crit_bonus", 0.0)) + float(mods.get("crit", 0.0)), "basic": true, "shape": shape,
		"heal_on_hit": float(s.get("heal_on_hit", 0.0)) + float(mods.get("heal", 0.0))}
	if String(sig.get("type", "")) in ["explode", "chain"]:
		a["sig_proc"] = sig
	match shape:
		"bolt":
			a["kind"] = "bolt"
			a["range"] = float(s.get("range", 10.0)) * reach_m
			a["projectile"] = String(s.get("projectile", "arrow"))
			a["volley"] = int(s.get("count", 1)) + extra
			a["spread"] = float(s.get("spread", 10.0)) + 8.0 * extra
			a["pierce"] = int(s.get("pierce", 0)) + p.pierce_bonus + int(mods.get("pierce", 0))
			a["bounce"] = int(s.get("bounce", 0)) + p.bounce_bonus + int(mods.get("bounce", 0))
			if s.has("explode"):
				a["explode"] = (float(s.explode) + float(mods.get("explode", 0.0))) * area
			a["radius"] = 0.0
			a["hits"] = 1  # une volée par attaque, quel que soit le nombre d'impacts de l'animation
		"cast":
			a["kind"] = "cast"
			a["range"] = float(s.get("range", 10.0)) * reach_m
			a["radius"] = float(s.get("radius", 2.5)) * area
			a["arc"] = 360.0
			var rate := p.cast_speed if rate_stat(s) == "cast_speed" else p.atk_speed
			a["delay"] = float(s.get("delay", 0.4)) * (1.0 - minf(float(mods.get("delay", 0.0)), 0.6)) / maxf(rate, 0.2)
			a["zones"] = 1 + extra
			a["hits"] = 1
		"thrust":
			a["radius"] = float(s.get("radius", 4.0)) * reach_m
			a["arc"] = float(s.get("arc", 30.0))
			a["hits"] = int(s.get("hits", 1)) + extra
		"slam":
			a["kind"] = "slam"
			a["radius"] = float(s.get("radius", 2.4)) * area
			a["offset"] = float(s.get("offset", 1.8))
			a["arc"] = 360.0
			a["hits"] = int(s.get("hits", 1)) + extra
		"nova":
			a["radius"] = float(s.get("radius", 3.6)) * area
			a["arc"] = 360.0
			a["hits"] = int(s.get("hits", 1)) + extra
		_:
			a["radius"] = float(s.get("radius", 2.8)) * area
			a["arc"] = float(s.get("arc", 150.0))
			a["hits"] = int(s.get("hits", 1)) + extra
	return a


## Effet légendaire « tous les N coups » : renforce l'action [param a] si c'est le N-ième coup
## ([param count] : coups déjà portés par cet emplacement, celui-ci compris).
static func empower(a: Dictionary, s: Dictionary, mods: Dictionary, count: int) -> bool:
	var sig: Dictionary = s.get("sig", {})
	if not mods.get("sig", false) or String(sig.get("type", "")) != "every" or count % maxi(int(sig.get("n", 4)), 1) != 0:
		return false
	a["mult"] = float(a.mult) * (1.0 + float(sig.get("mult", 0.0)))
	a["crit_bonus"] = float(a.get("crit_bonus", 0.0)) + float(sig.get("crit", 0.0))
	var more := int(sig.get("proj", 0))
	if more > 0:
		match String(a.get("kind", "")):
			"bolt":
				a["volley"] = int(a.volley) + more
				a["spread"] = float(a.spread) + 8.0 * more
			"cast":
				a["zones"] = int(a.zones) + more
			_:
				a["hits"] = int(a.get("hits", 1)) + more
	var k := 1.0 + float(sig.get("area", 0.0))
	a["radius"] = float(a.get("radius", 0.0)) * k
	if a.has("explode"):
		a["explode"] = float(a.explode) * k
	a["empowered"] = true
	return true


## Effet légendaire à l'impact (explosion, foudre) au format Procs.run.
static func sig_proc(sig: Dictionary) -> Dictionary:
	if String(sig.get("type", "")) == "chain":
		return {"effect": "lightning", "mult": float(sig.get("mult", 0.6)), "chain": int(sig.get("chain", 3)), "radius": 7.0}
	var p := {"effect": "explosion", "mult": float(sig.get("mult", 0.6)), "radius": float(sig.get("radius", 3.0)),
		"color": Color(1.0, 0.75, 0.4, 0.9)}
	if sig.has("applies"):
		p["applies"] = sig.applies
	return p


## Texte de l'effet légendaire de la variante [param s].
static func sig_text(s: Dictionary) -> String:
	var sig: Dictionary = s.get("sig", {})
	var t := ""
	match String(sig.get("type", "")):
		"every":
			var bits: PackedStringArray = []
			if float(sig.get("mult", 0.0)) > 0.0:
				bits.append("+%d %% de dégâts" % roundi(float(sig.mult) * 100.0))
			if float(sig.get("crit", 0.0)) >= 1.0:
				bits.append("critique assuré")
			if int(sig.get("proj", 0)) > 0:
				var shape := String(s.get("shape", ""))
				bits.append("+%d %s" % [int(sig.proj), "projectiles" if shape == "bolt" else ("zones" if shape == "cast" else "frappes")])
			if float(sig.get("area", 0.0)) > 0.0:
				bits.append("+%d %% de zone" % roundi(float(sig.area) * 100.0))
			t = "tous les %d coups : %s" % [int(sig.get("n", 4)), ", ".join(bits)]
		"status":
			var bits: PackedStringArray = []
			for st in sig.get("applies", {}):
				bits.append("%s %s s" % [StatusDb.display_name(String(st)), String.num(float(sig.applies[st]), 1)])
			t = "chaque coup inflige " + ", ".join(bits)
		"explode":
			t = "%d %% de chances qu'un impact explose (%s m, %d %%)" % [roundi(float(sig.chance) * 100.0), String.num(float(sig.radius), 1), roundi(float(sig.mult) * 100.0)]
			if sig.has("applies"):
				t += " et empoisonne"
		"chain":
			t = "%d %% de chances qu'un impact lance une foudre en chaîne (%d rebonds, %d %%)" % [roundi(float(sig.chance) * 100.0), int(sig.chain), roundi(float(sig.mult) * 100.0)]
	return "%s : %s" % [String(sig.get("name", "?")), t]


## Bonus mineurs et majeurs que peut tirer la variante [param s] : {clé: poids}.
static func minor_pool(s: Dictionary) -> Dictionary:
	var sc: Array = s.get("scales", [])
	var out := {"crit": 1.0, "speed": 1.0}
	if "area" in sc:
		out["area"] = 1.0
	if "reach" in sc or String(s.get("shape", "")) in ["bolt", "cast", "thrust"]:
		out["reach"] = 1.0
	if not (s.get("applies", {}) as Dictionary).is_empty() or String(s.get("sig", {}).get("type", "")) == "status":
		out["dot"] = 1.0
	if float(s.get("heal_on_hit", 0.0)) > 0.0:
		out["heal"] = 1.0
	if String(s.get("shape", "")) == "cast":
		out["delay"] = 1.0
	for k in s.get("favor", []):
		if out.has(k):
			out[k] = 3.0  # bonus de prédilection de l'arme (critique pour l'arc…)
	return out


static func major_pool(s: Dictionary) -> Dictionary:
	var sc: Array = s.get("scales", [])
	var out := {}
	if "proj" in sc or "hits" in sc:
		out["proj"] = 2.0
	if "pierce" in sc and int(s.get("pierce", 0)) < 50:
		out["pierce"] = 1.0
	if "bounce" in sc:
		out["bounce"] = 1.0
	if "area" in sc:
		out["big_area"] = 1.0
	if s.has("explode"):
		out["explode"] = 1.0
	if out.is_empty():
		out["proj"] = 1.0
	return out


static func _pick(pool: Dictionary) -> String:
	var total := 0.0
	for k in pool:
		total += float(pool[k])
	var r := randf() * total
	for k in pool:
		r -= float(pool[k])
		if r <= 0.0:
			return String(k)
	return String(pool.keys()[0])


## Amélioration tirée pour la variante [param s] à la rareté [param tier] ([param cur] :
## améliorations déjà acquises) : {dmg, <bonus>…, sig?}.
static func roll_upgrade(s: Dictionary, tier: String, cur: Dictionary) -> Dictionary:
	var up := {"dmg": float(UP_DMG.get(tier, 0.15))}
	var minors := 0
	var majors := 0
	match tier:
		"rare":
			minors = 1
		"epic":
			minors = 1
			majors = 1
		"legendary":
			if not cur.get("sig", false) and s.has("sig"):
				up["sig"] = true
				minors = 1
			else:
				minors = 2
			majors = 1
	var mp := minor_pool(s)
	for i in minors:
		var k := _pick(mp)
		up[k] = float(up.get(k, 0.0)) + float(MINOR[k])
		mp.erase(k)  # deux bonus mineurs différents
		if mp.is_empty():
			break
	for i in majors:
		var k := _pick(major_pool(s))
		if k == "big_area":
			up["area"] = float(up.get("area", 0.0)) + float(MAJOR.big_area)
		else:
			up[k] = float(up.get(k, 0.0)) + float(MAJOR[k])
	return up


## Ajoute [param up] aux améliorations [param cur] (niveau + 1).
static func merge_upgrade(cur: Dictionary, up: Dictionary) -> void:
	cur["rank"] = int(cur.get("rank", 0)) + 1
	for k in up:
		if k == "sig":
			cur["sig"] = true
		else:
			cur[k] = float(cur.get(k, 0.0)) + float(up[k])


static func _val(k: String, v: float) -> String:
	var u := String(UP_TEXT.get(k, ["", ""])[1])
	match u:
		"%":
			return "+%d %%" % roundi(v * 100.0)
		"-%":
			return "-%d %%" % roundi(minf(v, 0.6) * 100.0)
		"s":
			return "+%s s" % String.num(v, 1)
		"m":
			return "+%s m" % String.num(v, 1)
		"pv":
			return "+%s %% des PV max" % String.num(v * 100.0, 1)
	return "+%d" % roundi(v)


## Texte d'une amélioration d'arme : totaux avant → après, puis l'effet légendaire.
static func upgrade_lines(s: Dictionary, cur: Dictionary, up: Dictionary) -> PackedStringArray:
	var out: PackedStringArray = []
	for k in UP_TEXT:
		if up.has(k):
			var a := float(cur.get(k, 0.0))
			var t := String(UP_TEXT[k][0])
			out.append(("%s : %s → [b]%s[/b]" % [t, _val(k, a), _val(k, a + float(up[k]))]) if a > 0.0 else ("%s : [b]%s[/b]" % [t, _val(k, float(up[k]))]))
	if up.get("sig", false):
		out.append("[color=#ffb347]★ Effet légendaire — %s[/color]" % sig_text(s))
	return out


## Résumé des améliorations [param cur] d'un emplacement (grimoire, panneau de la run).
static func mods_text(s: Dictionary, cur: Dictionary) -> String:
	if int(cur.get("rank", 0)) <= 0:
		return ""
	var bits: PackedStringArray = []
	for k in UP_TEXT:
		if float(cur.get(k, 0.0)) > 0.0:
			bits.append("%s %s" % [UP_TEXT[k][0], _val(k, float(cur[k]))])
	var t := "Niveau %d/%d : %s" % [int(cur.rank), MAX_RANK, ", ".join(bits)]
	if cur.get("sig", false):
		t += "\n★ " + sig_text(s)
	return t


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
	var per := " par projectile" if String(s.shape) == "bolt" else (" par frappe" if int(s.get("hits", 1)) > 1 else "")
	lines.append("Dégâts : [b]%s[/b]%s" % [dmg, per])
	var bits: PackedStringArray = []
	if s.has("count") and int(s.count) > 1:
		bits.append("%d projectiles" % int(s.count))
	if int(s.get("hits", 1)) > 1:
		bits.append("%d frappes" % int(s.hits))
	if int(s.get("pierce", 0)) >= 50:
		bits.append("traverse tout")
	elif int(s.get("pierce", 0)) > 0:
		bits.append("perce %d" % int(s.pierce))
	if int(s.get("bounce", 0)) > 0:
		bits.append("%d rebond%s" % [int(s.bounce), "s" if int(s.bounce) > 1 else ""])
	if s.has("explode"):
		bits.append("explosion %s m" % String.num(float(s.explode), 1))
	if s.has("delay"):
		bits.append("impact après %s s" % String.num(float(s.delay), 2))
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
	if s.has("sig"):
		lines.append("[color=#ffb347]★ Légendaire — %s[/color]" % sig_text(s))
	if offhand:
		lines.append("[color=#9a98a8]Arme secondaire : frappe seule (%d %% des dégâts, %d %% de ses stats d'objet).[/color]" % [roundi(OFFHAND_DMG * 100.0), roundi(OFFHAND_STATS * 100.0)])
	return "\n".join(lines)
