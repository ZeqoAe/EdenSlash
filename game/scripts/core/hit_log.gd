class_name HitLog
extends RefCounted
## « Ce qui t'a battu » (lot DNG-1, backlog BM-DNG P0-5) : journal des coups reçus par le héros du joueur, sans interface.
## Combatant.take_damage appelle [method note] pour chaque coup encaissé (après défense et plafonds) ; le bilan d'échec lit
## [method report] : les coups des WINDOW dernières secondes avant la chute, regroupés par source et par mécanique
## (nom français, part des PV max), le coup final et le conseil de la mécanique fautive (TIPS, une phrase par brique de
## BossBricks et par attaque de base de BossBrain). L'attribution d'un coup de boss à sa mécanique : la dernière lancée dont
## la fenêtre couvre l'instant du coup (BossBrain.blame) ; une invocation porte la brique qui l'a appelée (meta « boss_brick »).
## Remis à zéro au début de chaque partie de la Tour, des Donjons, de la Ruée et du Siège (Tower.start).
##
## API : HitLog.reset() · HitLog.note(victime, dégâts, source, dot) · HitLog.report([secondes]) -> {lines, killer, brick, tip,
##   total, hits, window} · HitLog.tip_for(type) · HitLog.mech_name(type) · HitLog.window_of(type).

const WINDOW := 8.0
const KEEP := 96  # coups gardés au plus (les plus vieux tombent)
const MAX_LINES := 3
const STALE := 90.0  # une chute plus vieille que ça ne compte plus (partie suivante sans coup)

## Attaques de base des boss (BossBrain.KIT) et coup ordinaire : noms français.
const BASE_NAMES := {"slams": "Écrasements", "charge": "Charge", "cleave": "Taillade", "barrage": "Salve", "nova": "Onde de fureur",
	"melee": "Coups au contact"}
## Fenêtre (s) pendant laquelle une mécanique lancée est tenue pour responsable des coups de son boss (0 : jamais : ses
## dégâts passent par ses invocations, ou elle n'en fait pas).
const WINDOWS := {"puddles": 12.0, "meteors": 10.0, "lasers": 4.5, "grid": 5.0, "sweep": 5.5, "adds": 0.0, "pet": 0.0, "clones": 0.0,
	"swarm": 0.0, "turrets": 0.0, "enrage": 0.0, "frenzy": 0.0, "totems": 0.0, "barrier": 0.0, "crystals": 0.0, "rampage": 5.0,
	"leap": 3.0, "spiral": 6.0, "ring_burst": 5.0, "fan": 3.5, "shrink": 16.0, "safe_zone": 4.5, "vortex": 4.5, "gale": 3.5,
	"gaze": 3.0, "marks": 4.5, "blink": 3.0, "reflect": 3.5, "stomp": 4.5,
	"slams": 3.5, "charge": 2.5, "cleave": 2.0, "barrage": 3.0, "nova": 2.5}
## Mécaniques qui laissent une zone au sol : les dégâts continus (dot) d'un boss leur reviennent en priorité.
const DOT_BRICKS := ["puddles", "meteors", "shrink"]
## Conseil après une chute, une phrase courte par mécanique (le conseil d'entrée, BossBricks.DEFS.hint, dit ce qu'elle fait).
const TIPS := {
	"puddles": "Les flaques restent au sol : quitte-les tout de suite et ne te bats pas dedans.",
	"meteors": "Ne t'arrête pas sous les météores : chaque impact laisse une flaque.",
	"lasers": "Les rayons partent du boss : place-toi entre deux rayons, loin de lui.",
	"grid": "Le damier frappe en deux temps : va sur une case qui vient d'exploser.",
	"sweep": "Les lignes tombent l'une après l'autre : avance dans celle qui vient de frapper.",
	"adds": "Tue les renforts avant de revenir au boss : ils frappent dans ton dos.",
	"pet": "Son compagnon frappe aussi : abats-le d'abord ou garde-le en vue.",
	"clones": "Les illusions frappent aussi : le vrai garde sa barre de vie.",
	"swarm": "La nuée revient sans cesse : nettoie-la vite, puis reviens au boss.",
	"turrets": "Les tourelles tirent de loin : détruis-les dès qu'elles apparaissent.",
	"enrage": "À bout de forces, il frappe plus fort : garde tes défenses pour la fin.",
	"frenzy": "Il frappe plus fort avec le temps : finis-le plus vite, ou avec plus de puissance.",
	"totems": "Il est invincible sous son bouclier : détruis les totems d'abord.",
	"barrier": "Brise sa barrière avant qu'elle ne le soigne : concentre tes sorts dessus.",
	"crystals": "Les cristaux le soignent : casse-les avant de le frapper.",
	"rampage": "Il charge en ligne droite : écarte-toi sur le côté, pas en arrière.",
	"leap": "Il retombe là où tu étais : bouge dès qu'il saute.",
	"spiral": "Glisse entre les bras de la spirale, en tournant avec elle.",
	"ring_burst": "Passe entre deux orbes de la couronne plutôt que de fuir.",
	"fan": "Sors de l'éventail sur le côté avant le tir.",
	"shrink": "Reste au centre quand l'arène se resserre : le bord brûle.",
	"safe_zone": "Rejoins le cercle sûr dès qu'il apparaît : l'explosion couvre tout le reste.",
	"vortex": "Quand il t'attire, cours à l'opposé avant l'explosion.",
	"gale": "Le vent te pousse au bord : lutte contre lui pour rester près du boss.",
	"gaze": "Quand il te fixe, passe dans son dos.",
	"marks": "La marque se fige après quelques instants : sors-en dès qu'elle cesse de te suivre.",
	"blink": "Il disparaît en laissant une explosion : éloigne-toi de l'endroit où il était.",
	"reflect": "Ne frappe pas pendant le miroir : il te renvoie tes coups.",
	"stomp": "Saute par-dessus les ondes de choc au lieu de les fuir.",
	"slams": "Trois cercles suivent tes pas : ne reste pas immobile.",
	"charge": "Sa charge suit une ligne : écarte-toi sur le côté.",
	"cleave": "Ne reste pas devant lui au contact : sa taillade couvre l'avant.",
	"barrage": "Ses tirs suivent les traits au sol : place-toi entre deux traits.",
	"nova": "L'onde de fureur part de lui : saute par-dessus ou éloigne-toi.",
	"melee": "Ne reste pas encerclé : recule pour regrouper les monstres devant toi.",
}

static var _hits: Array = []  # {t, dmg, share, hp, name, brick, boss, dot, lethal}
static var _death_at := -1.0


## Le héros est tombé pendant la partie en cours (le bilan ne dit « ce qui t'a battu » qu'après une vraie chute).
static func died() -> bool:
	return _death_at >= 0.0 and clock() - _death_at <= STALE


## Horloge des coups (en secondes, temps réel).
static func clock() -> float:
	return Time.get_ticks_msec() / 1000.0


static func reset() -> void:
	_hits.clear()
	_death_at = -1.0


## Le héros [param victim] vient d'encaisser [param dmg] de [param source] (null : piège, poison, anneau…). Seul le héros du
## joueur compte (ni un héros ennemi, ni l'entraînement).
static func note(victim: Combatant, dmg: float, source: Combatant, dot := false) -> void:
	if victim == null or not victim is Player or (victim as Player).foe or Training.active or dmg <= 0.0:
		return
	var who := blame(source, dot)
	var share := dmg / maxf(victim.max_hp, 1.0)
	if victim.hp <= 0.0:
		# coup de grâce : il n'a pris que ce qui restait (les PV après le coup d'avant, s'il est récent)
		var prev := 1.0
		if not _hits.is_empty() and clock() - float(_hits.back().t) <= WINDOW:
			prev = float(_hits.back().hp)
		share = minf(share, prev)
	var e := {"t": clock(), "dmg": dmg, "share": share, "hp": victim.hp / maxf(victim.max_hp, 1.0),
		"name": String(who.name), "brick": String(who.brick), "boss": String(who.boss), "dot": dot, "lethal": victim.hp <= 0.0}
	_hits.append(e)
	if _hits.size() > KEEP:
		_hits.pop_front()
	if e.lethal:
		_death_at = float(e.t)


## Qui a frappé : {name (français, sans étiquette), brick (mécanique ou attaque de base, "" : coup ordinaire), boss (id de
## la bibliothèque, "" sinon)}.
static func blame(source: Combatant, dot := false) -> Dictionary:
	if source == null or not is_instance_valid(source):
		return {"name": "Effets et pièges", "brick": "", "boss": ""}
	var name := clean_name(source.display_name)
	var brick := ""
	var bid := String(source.get_meta("boss_id", ""))
	if source.has_meta("boss_brick"):
		brick = String(source.get_meta("boss_brick"))  # invocation : la mécanique qui l'a appelée
	elif source is Monster and (source as Monster).brain != null and is_instance_valid((source as Monster).brain):
		brick = (source as Monster).brain.blame(dot)
		if brick == "" and not dot:
			brick = "melee"
	elif source is Monster and not dot:
		brick = "melee"
	return {"name": name, "brick": brick, "boss": bid}


## « <Boss> Latif, Roi du ciel » -> « Latif » ; « Gobelin · Flaques » (élite) -> « Gobelin » ; « <Duel> Ombre · Mage » gardé.
static func clean_name(n: String) -> String:
	var boss := n.begins_with("<Boss> ")
	n = n.trim_prefix("<Boss> ").trim_prefix("<Duel> ")
	if boss:
		n = n.get_slice(",", 0)
	elif n.contains(" · ") and not n.begins_with("Ombre"):
		n = n.get_slice(" · ", 0)
	return n.strip_edges()


## Nom français d'une mécanique ou d'une attaque de base.
static func mech_name(type: String) -> String:
	if BASE_NAMES.has(type):
		return String(BASE_NAMES[type])
	return BossBricks.name_of(type) if BossBricks.DEFS.has(type) else ""


## Conseil après une chute pour la mécanique [param type] (à défaut, le conseil d'entrée de la brique).
static func tip_for(type: String) -> String:
	if TIPS.has(type):
		return String(TIPS[type])
	var h := BossBricks.hint_of(type)
	return (h.left(1).to_upper() + h.substr(1) + ".") if h != "" else ""


static func window_of(type: String) -> float:
	return float(WINDOWS.get(type, 4.0))


## Coups des [param secs] dernières secondes avant la chute (à défaut, avant le dernier coup reçu), du plus ancien au dernier.
static func entries(secs := WINDOW) -> Array:
	if _hits.is_empty():
		return []
	var end := _death_at if _death_at >= 0.0 else float(_hits.back().t)
	if clock() - end > STALE:
		return []
	return _hits.filter(func(e): return float(e.t) <= end + 0.001 and end - float(e.t) <= secs)


## Ce qui t'a battu : {hits (nombre de coups), total (part des PV perdue), window (s), lines (au plus MAX_LINES, la plus
## lourde d'abord : {name, brick, mech, share, count, final}), killer ({name, brick, mech, share} : le coup final), brick (la
## mécanique fautive : celle qui a pris le plus de PV, sinon celle du coup final), tip (son conseil)} ; {} sans coup reçu.
static func report(secs := WINDOW) -> Dictionary:
	var list := entries(secs)
	if list.is_empty():
		return {}
	var groups := {}
	var order: Array = []
	var total := 0.0
	for e in list:
		var k := "%s|%s" % [e.name, e.brick]
		if not groups.has(k):
			groups[k] = {"name": String(e.name), "brick": String(e.brick), "mech": mech_name(String(e.brick)), "share": 0.0, "count": 0, "final": false}
			order.append(k)
		groups[k].share += float(e.share)
		groups[k].count += 1
		total += float(e.share)
	var last: Dictionary = list.back()
	var last_k := "%s|%s" % [last.name, last.brick]
	groups[last_k].final = true
	var lines: Array = order.map(func(k): return groups[k])
	lines.sort_custom(func(a, b): return float(a.share) > float(b.share))
	# le coup final reste visible même s'il pèse peu
	var shown: Array = lines.slice(0, MAX_LINES)
	if not shown.any(func(l): return l.final):
		shown[shown.size() - 1] = groups[last_k]
	var fault := ""
	for l in lines:
		if String(l.brick) != "" and String(l.brick) != "melee":
			fault = String(l.brick)
			break
	if fault == "":
		fault = String(last.brick)
	return {"hits": list.size(), "total": total, "window": secs, "lines": shown,
		"killer": {"name": String(last.name), "brick": String(last.brick), "mech": mech_name(String(last.brick)), "share": float(last.share)},
		"brick": fault, "tip": tip_for(fault), "boss": String(last.boss)}


## Part des PV en texte (« 48 % »), jamais moins de 1 %.
static func pct(share: float) -> String:
	return "%d %%" % maxi(1, roundi(share * 100.0))
