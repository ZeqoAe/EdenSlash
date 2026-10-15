class_name Siege
extends RefCounted
## Le Siège (idée 8 du joueur, « Trio ») : toi et deux alliés IA tenez une arène de donjon contre 5 vagues de
## monstres deux fois plus nombreux et deux fois plus coriaces, puis contre le boss du donjon (un sac à PV à
## phases, qui se met en fureur au bout de 6 minutes : il faut jouer ses phases, pas le laisser durer).
## À sa mort, la zone se ferme (un anneau rétrécit en 20 s), son cœur tombe au centre et les trois héros
## deviennent hostiles : chacun pour soi, le dernier debout gagne un coffre d'apparence légendaire. Choix de
## risque : prendre le cœur et franchir l'anneau pour quitter le duel avec une récompense moindre (les deux
## IA se jettent alors sur toi). Trois joueurs humains plus tard : rien ici ne suppose que les alliés sont des IA.
##
## Le moteur est celui des Donjons (Tower.dungeon / Tower.siege, SiegeDirector qui prolonge TowerDirector) ;
## le « chacun pour soi » pose un `ffa_id` à chacun des trois héros (ciblage : Combatant.set_ffa) et lève
## [member ffa] (règles JcJ de PvpCaps, profil « siege » de ModeRules).

const WAVES := 5
const WAVE_TYPES := ["monsters", "monsters", "elite", "monsters", "elite"]
const COUNT_MULT := 2.0  # monstres en nombre ×2 (par rapport à une salle de donjon)
const MONSTER_HP := Dungeons.MONSTER_HP * 2.0  # PV ×2
const ELITE_HP := Dungeons.ELITE_HP * 2.0
const BOSS_HP := 24.0  # × les PV de base du boss (15 dans un donjon à deux alliés) : un sac à PV
const ENRAGE_AT := 360.0  # fureur du boss après 6 minutes de combat
const ENRAGE_STEP := 15.0  # puis ses dégâts montent encore toutes les 15 s
const REST_TIME := 7.0  # pause entre deux vagues (soin partiel, potions)
const RING_FROM := 25.0  # rayon de l'anneau à la mort du boss (l'arène fait ~26 m)
const RING_TO := 9.0
const RING_TIME := 20.0
const TRUCE := 4.0  # trêve avant le chacun pour soi
const RING_DPS := 0.05  # part des PV max perdue par seconde hors de l'anneau (monte avec le temps)
const ALLIES := 2
## Rapport PE / PE attendue pour entrer (Normal, Héroïque, Mythique) : plus exigeant qu'un donjon de même niveau.
const POWER_RATIO := [0.35, 0.65, 0.9]
const TITLE := "Maître du Siège"

## Issue du chacun pour soi du siège en cours : "", "won" (dernier debout), "escaped" (cœur emporté), "eliminated".
static var outcome := ""
## Rang final du joueur (1 = vainqueur, 3 = tombé le premier).
static var rank := 0
## Héros qui porte le cœur (jamais plus d'un) : les IA le prennent pour cible.
static var carrier: Combatant = null
## Le chacun pour soi est en cours : les règles du JcJ (plafonds, échelle des dégâts, soins réduits) s'appliquent.
static var ffa := false


static func reset() -> void:
	outcome = ""
	rank = 0
	carrier = null
	ffa = false


static func floor_type(f: int) -> String:
	if f > WAVES:
		return "boss"
	return String(WAVE_TYPES[clampi(f - 1, 0, WAVES - 1)])


static func wave_count(f: int, diff: int) -> int:
	return roundi((10 + 2 * f + 3 * diff) * COUNT_MULT)


static func max_alive(diff: int) -> int:
	return 20 + 2 * diff


static func elite_count(f: int, diff: int) -> int:
	return 3 + diff + (2 if f >= WAVES else 0)


static func hp_mult(boss: bool, elite: bool) -> float:
	return BOSS_HP if boss else (ELITE_HP if elite else MONSTER_HP)


## Niveau de la zone [param zid] à la difficulté [param diff] (celui du donjon).
static func level(zid: String, diff: int) -> int:
	return Dungeons.level(zid, diff)


# --- verrous -------------------------------------------------------------------------------------
static func power_required(zid: String, diff: int) -> int:
	return GearPower.required(level(zid, diff), float(POWER_RATIO[clampi(diff, 0, 2)]))


static func power_ok(zid: String, diff: int) -> bool:
	return GearPower.meets(power_required(zid, diff))


static func power_text(zid: String, diff: int) -> String:
	var need := power_required(zid, diff)
	if need <= 0:
		return ""
	return "PE requise : %s (la tienne : %s)" % [GearPower.fmt(need), GearPower.fmt(GearPower.hero_power())]


## Le siège de la zone [param zid] est jouable : Donjons ouverts, donjon de la zone ouvert, PE suffisante.
static func playable(zid: String, diff: int) -> bool:
	return Unlocks.is_open("siege") and Dungeons.is_open(zid) and power_ok(zid, diff)


## Classes des alliés : celles choisies, complétées au hasard parmi les classes jouables jusqu'à [constant ALLIES].
static func fill_allies(ids: Array) -> Array:
	var out: Array = ids.filter(func(c): return String(c) != "").slice(0, ALLIES)
	var pool: Array = GameData.classes.keys().filter(func(c): return Progression.class_unlocked(c))
	if pool.is_empty():
		pool = GameData.classes.keys()
	while out.size() < ALLIES and not pool.is_empty():
		out.append(pool.pick_random())
	return out


# --- records et butin ----------------------------------------------------------------------------
static func clears(zid: String, diff: int) -> int:
	return int(Profile.records.get("siege_%s_%d" % [zid, diff], 0))


static func wins() -> int:
	return int(Profile.records.get("siege_wins", 0))


## Butin du siège terminé (appelé après le rechargement de la sauvegarde) : [param reached] = dernière vague
## vaincue (6 : le boss est tombé). Cristaux selon la progression ; le boss tombé donne un coffre d'équipement
## et des coffres de formules d'enchantement hautes (ActivityLoot) ;
## le dernier debout, un coffre d'apparence légendaire (et un titre la 1re fois) ; le cœur emporté, un coffre
## d'apparence épique.
static func settle(zid: String, diff: int, reached: int, result: String) -> Dictionary:
	var lv := level(zid, diff) + 1
	var boss_down := reached > WAVES
	var out := {"chests": [], "crystals": ActivityLoot.siege_crystals(reached, diff, boss_down),
		"title": "", "outcome": result, "boss": boss_down}
	Profile.materials["crystal"] = int(Profile.materials.get("crystal", 0)) + int(out.crystals)
	var key := "siege_best_%d" % diff
	Profile.records[key] = maxi(int(Profile.records.get(key, 0)), mini(reached, WAVES + 1))
	if boss_down:
		Profile.records["siege_%s_%d" % [zid, diff]] = clears(zid, diff) + 1
		var gear := Rewards.make("gear", lv, true)
		Profile.reward_chests.append(gear)
		out.chests.append(gear)
		out.chests.append_array(ActivityLoot.siege_chests(lv, diff))  # formules d'enchantement hautes
	match result:
		"won":
			var look := Rewards.make(Rewards.look_type(3), lv, true)
			Profile.reward_chests.append(look)
			out.chests.append(look)
			Profile.records["siege_wins"] = wins() + 1
			if not TITLE in Profile.extra_titles:
				out.title = TITLE
				Profile.add_title(TITLE)
		"escaped":
			var look := Rewards.make(Rewards.look_type(2), lv, true)
			Profile.reward_chests.append(look)
			out.chests.append(look)
			Profile.records["siege_escapes"] = int(Profile.records.get("siege_escapes", 0)) + 1
	return out
