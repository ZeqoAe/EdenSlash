class_name Dungeons
extends RefCounted
## Donjons (lot 13) : un donjon d'Eden par zone, en quatre salles (monstres, élites, monstres, boss),
## joué avec ton équipement synchronisé, les 12 sorts de ton préréglage, une carte par salle et jusqu'à
## deux alliés IA. Trois difficultés : Normal (niveau de l'époque), Héroïque (+15), Mythique (niveau 90).
## Il réutilise l'infrastructure de la Tour (salles, directeur, bilan) : `Tower.dungeon` est la zone du
## donjon en cours ("" : pas de donjon). Butin : un coffre de set (pièce mythique au choix, légendaire
## plus probable en Héroïque et Mythique), des cristaux, des coffres de matières au niveau du donjon
## (ActivityLoot : de quoi monter les pièces de ce niveau) et un plan de fabrication une fois sur dix.

const ROOMS := ["monsters", "elite", "monsters", "boss"]
const DIFF_NAMES := ["Normal", "Héroïque", "Mythique"]
const MYTHIC_LEVEL := 90
const HEROIC_BONUS := 15
const MONSTER_HP := 1.8  # PV des monstres (profil « donjon »)
const ELITE_HP := 2.5
const BOSS_HP := 25.0  # × les PV de base d'un monstre de son niveau
const ALLY_HP_STEP := 0.5  # PV des monstres en plus par allié
const MAX_ALLIES := 2


## Panoplie (archétype d'`Items.SETS`) de chaque donjon : ses pièces comptent pour 2 / 4 / 6 en plus du set d'Eden.
const ARCHETYPES := {
	"limestone": "storm", "rainbowfall": "frost", "beluga": "blood", "wetlands": "falcon",
	"avila": "phoenix", "arid": "wind", "delphi": "salvo", "blackflame": "rampart",
}


static func archetype(zid: String) -> String:
	return String(ARCHETYPES.get(zid, "storm"))


## Ruée des boss : « zone » spéciale du moteur de donjon, un étage par zone (son boss, niveau du donjon).
const RUSH := "rush"
const RUSH_TITLES := ["Briseur de boss", "Fléau des boss", "Seigneur des boss"]  # Normal, Héroïque, Mythique


static func rush_floors() -> int:
	return GameData.zones.size()


static func rush_zone(f: int) -> Dictionary:
	return GameData.zones[clampi(f - 1, 0, GameData.zones.size() - 1)]


static func rush_level(f: int, diff: int) -> int:
	return level(String(rush_zone(f).id), diff)


## Butin de la Ruée : cristaux pour chaque boss battu ; des coffres de matières de haut niveau (un de forge à
## la moitié, quatre dont pierres rares et gemmes si les 8 sont tombés) ; si les 8 sont tombés, un coffre
## d'équipement (le 1er de chaque difficulté : un coffre d'apparence) et le titre de la difficulté.
static func rush_reward(reached: int, diff: int) -> Dictionary:
	var out := {"chests": [], "crystals": ActivityLoot.rush_crystals(reached, diff), "plan": "", "rush": true, "title": ""}
	Profile.materials["crystal"] = int(Profile.materials.get("crystal", 0)) + int(out.crystals)
	var key := "rush_best_%d" % diff
	Profile.records[key] = maxi(int(Profile.records.get(key, 0)), reached)
	out.chests.append_array(ActivityLoot.rush_chests(rush_level(rush_floors(), diff), reached, diff))
	if reached >= rush_floors():
		var lv := rush_level(rush_floors(), diff)
		var c := Rewards.make("gear", lv, true)
		Profile.reward_chests.append(c)
		out.chests.append(c)
		if int(Profile.records.get("rush_clear_%d" % diff, 0)) == 0:
			var look := Rewards.make(Rewards.look_type(diff + 1), lv, true)
			Profile.reward_chests.append(look)
			out.chests.append(look)
		Profile.records["rush_clear_%d" % diff] = int(Profile.records.get("rush_clear_%d" % diff, 0)) + 1
		out.title = RUSH_TITLES[clampi(diff, 0, RUSH_TITLES.size() - 1)]
		Profile.add_title(out.title)
	return out


## Alliés du dernier donjon lancé (pour « Rejouer »).
static var last_allies: Array = []


static func zone_ids() -> Array:
	return GameData.zones.map(func(z): return String(z.id))


static func zone(zid: String) -> Dictionary:
	return GameData.zone(zid)


static func name_of(zid: String) -> String:
	if zid == RUSH:
		return "Ruée des boss"
	var z := zone(zid)
	return String(z.get("dungeon", {}).get("name", z.get("name", zid)))


## Niveau du donjon [param zid] à la difficulté [param diff] (0 Normal, 1 Héroïque, 2 Mythique).
static func level(zid: String, diff: int) -> int:
	if diff >= 2:
		return MYTHIC_LEVEL
	var base := int(zone(zid).get("levels", [1, 8])[1]) + 6
	return base + (HEROIC_BONUS if diff == 1 else 0)


## Le donjon [param zid] est ouvert : donjons débloqués (époque II) et le boss de sa zone battu en Survie
## (ou son époque déjà gagnée).
static func is_open(zid: String) -> bool:
	if not Unlocks.is_open("dungeons"):
		return false
	if int(Profile.records.get("boss_" + zid, 0)) > 0:
		return true
	for ep in range(1, Epochs.count() + 1):
		if ep <= int(Profile.records.get("epochs_cleared", 0)) and zid in (Epochs.get_def(ep).zones as Array):
			return true
	return false


## PE (puissance d'équipement) qu'il faut pour le donjon [param zid] à la difficulté [param diff] ; la Ruée
## se juge au niveau de son étage du milieu.
static func power_required(zid: String, diff: int) -> int:
	var lv := level(zid, diff) if zid != RUSH else rush_level((rush_floors() + 1) / 2, diff)
	return GearPower.required(lv, float(GearPower.DIFF_RATIO[clampi(diff, 0, 2)]))


static func power_ok(zid: String, diff: int) -> bool:
	return GearPower.meets(power_required(zid, diff))


static func power_text(zid: String, diff: int) -> String:
	var need := power_required(zid, diff)
	if need <= 0:
		return ""
	return "PE requise : %s (la tienne : %s)" % [GearPower.fmt(need), GearPower.fmt(GearPower.hero_power())]


static func condition(zid: String) -> String:
	if not Unlocks.is_open("dungeons"):
		return Unlocks.condition("dungeons")
	return "Bats le boss de %s en Survie." % String(zone(zid).get("name", zid))


## Salles du donjon [param zid] : {type, level} dans l'ordre.
static func rooms(zid: String, diff: int) -> Array:
	var lv := level(zid, diff)
	var out: Array = []
	for i in ROOMS.size():
		out.append({"type": ROOMS[i], "level": lv + (1 if ROOMS[i] == "boss" else 0)})
	return out


static func hp_mult(boss: bool, elite: bool, allies: int) -> float:
	return (BOSS_HP if boss else (ELITE_HP if elite else MONSTER_HP)) * (1.0 + ALLY_HP_STEP * allies) * (0.3 if boss else 1.0)


## Records : donjons terminés (zone, difficulté).
static func cleared(zid: String, diff: int) -> int:
	return int(Profile.records.get("dungeon_%s_%d" % [zid, diff], 0))


static func total_cleared() -> int:
	var n := 0
	for zid in zone_ids():
		for d in DIFF_NAMES.size():
			if cleared(zid, d) > 0:
				n += 1
	return n


## Butin d'un donjon terminé : {chests, crystals, plan}. Les coffres rejoignent le menu Coffres, le plan et
## les cristaux le profil (sauvegardés par l'appelant).
static func reward(zid: String, diff: int) -> Dictionary:
	var lv := level(zid, diff)
	var out := {"chests": [], "crystals": ActivityLoot.dungeon_crystals(diff), "plan": ""}
	var boss := diff >= 1
	var c := Rewards.make("set", lv, boss)
	c["zone"] = zid
	c["archetype"] = archetype(zid)  # ses 3 pièces portent la panoplie du donjon
	Profile.reward_chests.append(c)
	out.chests.append(c)
	if diff >= 2:
		var c2 := Rewards.make("gear", lv, true)
		Profile.reward_chests.append(c2)
		out.chests.append(c2)
	out.chests.append_array(ActivityLoot.dungeon_chests(lv, diff))
	Profile.materials["crystal"] = int(Profile.materials.get("crystal", 0)) + int(out.crystals)
	if randf() < 0.1 or (cleared(zid, diff) == 0 and diff >= 1 and not "plan_" + zid in Profile.plans):
		var plan := "plan_" + zid
		if not plan in Profile.plans:
			Profile.plans.append(plan)
			out.plan = plan
	Profile.records["dungeon_%s_%d" % [zid, diff]] = cleared(zid, diff) + 1
	return out
