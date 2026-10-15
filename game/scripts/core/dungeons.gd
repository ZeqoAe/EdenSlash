class_name Dungeons
extends RefCounted
## Donjons (lot 13) : un donjon d'Eden par zone, en quatre salles (monstres, élites, monstres, boss),
## joué avec ton équipement synchronisé, les 12 sorts de ton préréglage, une carte par salle et jusqu'à
## deux alliés IA. Trois difficultés : Normal (niveau de l'époque), Héroïque (+15), Mythique (niveau 90).
## Il réutilise l'infrastructure de la Tour (salles, directeur, bilan) : `Tower.dungeon` est la zone du
## donjon en cours ("" : pas de donjon). Butin : un coffre de set (pièce mythique au choix, légendaire
## plus probable en Héroïque et Mythique), des cristaux, des coffres de matières au niveau du donjon
## (ActivityLoot : de quoi monter les pièces de ce niveau) et le plan de fabrication de la zone (sûr au 1er donjon
## terminé de chaque difficulté, sinon une fois sur dix).

const ROOMS := ["monsters", "elite", "monsters", "boss"]
const DIFF_NAMES := ["Normal", "Héroïque", "Mythique"]
const MYTHIC_LEVEL := 90
const HEROIC_BONUS := 15
## PV des monstres et des élites des salles (profil « donjon ») ; passe M2 : 1,8 / 2,5 -> 3,5 / 4 et salles plus peuplées
## (room_monsters) : le pilote vidait une salle en 15 s (donjon de 2 à 4 min) ; plus (4 / 4,5 et 50 monstres) les salles tuaient
## le pilote avant le boss. Mesuré : voir conception/nuit_15_10/R_M2.md.
const MONSTER_HP := 3.5
const ELITE_HP := 4.0
const BOSS_HP := 25.0  # × les PV de base d'un monstre de son niveau
const ALLY_HP_STEP := 0.5  # PV des monstres en plus par allié
const MAX_ALLIES := 2
const PLAN_CHANCE := 0.1  # plan de fabrication après un donjon déjà terminé dans cette difficulté
## PV des boss de donjon, de la Ruée et du Siège (passe P11) : FIXES par niveau et difficulté, plus d'après les données
## d'Eden de chaque boss (elles donnaient un boss Mythique de Limestone à 990 millions de PV, jamais tué, et un boss
## Héroïque de Blackflame tué en 15 s). PV = BOSS_REF_HP × BOSS_GROWTH^(niveau − 15) × BOSS_DIFF[difficulté], comme
## les dégâts d'un héros synchronisé (×1,09 par niveau, mesurés au pilote, tools/boss_ttk.py --dungeons) : ≈ 1 min 40,
## 2 min, 2 min 30 avec l'équipement attendu de la difficulté ; la Ruée enchaîne 8 boss plus courts (RUSH_BOSS).
const BOSS_REF_HP := 106000.0
const BOSS_GROWTH := 1.09
const BOSS_DIFF := [1.0, 3.4, 2.5]
const RUSH_BOSS := 0.6


## Panoplie (archétype d'`Items.SETS`) de chaque donjon : ses pièces comptent pour 2 / 4 / 6 en plus du set d'Eden.
const ARCHETYPES := {
	"limestone": "storm", "rainbowfall": "frost", "beluga": "blood", "wetlands": "falcon",
	"avila": "phoenix", "arid": "wind", "delphi": "salvo", "blackflame": "rampart",
}


static func archetype(zid: String) -> String:
	return String(ARCHETYPES.get(zid, "storm"))


## Ruée des boss : « zone » spéciale du moteur de donjon, un étage par zone (un boss de la zone tiré par Rush, niveau du donjon).
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
## Passe M6 : cristaux × Rush.bonus() (modificateurs choisis) ; le bilan reçoit le tirage (graine, boss vaincus, modificateurs).
static func rush_reward(reached: int, diff: int) -> Dictionary:
	var out := {"chests": [], "crystals": roundi(ActivityLoot.rush_crystals(reached, diff) * Rush.bonus()), "plan": "", "rush": true, "title": "",
		"seed": Rush.seed, "mods": Rush.mods.duplicate(), "bosses": Rush.lineup.slice(0, reached)}
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
		if Rush.seed > 0:
			Rush.cleared()  # tirage vaincu : la prochaine Ruée en propose un autre
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
	if zid == Tower.dungeon and Tower.dungeon_boss != "":
		return dungeon_name(Tower.dungeon_boss)  # donjon à la carte en cours (HUD, bilans)
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
	return "Bats le boss de la zone %s en Survie." % String(zone(zid).get("name", zid))


## Monstres de la salle [param f] en difficulté [param diff] (la salle du lieutenant en a un peu plus), en même temps au plus,
## élites de la 2e salle.
static func room_monsters(f: int, diff: int) -> int:
	return 44 + 6 * diff + (8 if f == LIEUTENANT_ROOM else 0)


static func room_alive(diff: int) -> int:
	return 16 + 2 * diff


static func room_elites(diff: int) -> int:
	return 5 + diff


## Salles du donjon [param zid] : {type, level} dans l'ordre.
static func rooms(zid: String, diff: int) -> Array:
	var lv := level(zid, diff)
	var out: Array = []
	for i in ROOMS.size():
		out.append({"type": ROOMS[i], "level": lv + (1 if ROOMS[i] == "boss" else 0)})
	return out


## PV fixes d'un boss de donjon de niveau [param lvl] en difficulté [param diff] (sans alliés ; Ruée : × RUSH_BOSS).
static func boss_hp(lvl: int, diff: int, rush := false) -> float:
	return BOSS_REF_HP * pow(BOSS_GROWTH, float(lvl - 15)) * float(BOSS_DIFF[clampi(diff, 0, BOSS_DIFF.size() - 1)]) * (RUSH_BOSS if rush else 1.0)


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
## les cristaux le profil (sauvegardés par l'appelant). [param bid] : boss de la bibliothèque (donjon à la carte) :
## le coffre propose 3 pièces de ses deux emplacements, à sa panoplie.
static func reward(zid: String, diff: int, bid := "") -> Dictionary:
	var lv := level(zid, diff)
	var out := {"chests": [], "crystals": ActivityLoot.dungeon_crystals(diff), "plan": ""}
	var boss := diff >= 1
	var c := Rewards.make("set", lv, boss)
	c["zone"] = zid
	c["archetype"] = archetype(zid)  # ses 3 pièces portent la panoplie du donjon
	if BossLibrary.has(bid):
		var th := BossLibrary.loot(bid)
		c["archetype"] = String(th.archetype)
		c["slots"] = (th.slots as Array).duplicate()
		c["boss_id"] = bid
		c["diff"] = diff
		Profile.records[boss_key(bid, diff)] = boss_cleared(bid, diff) + 1
	Profile.reward_chests.append(c)
	out.chests.append(c)
	if diff >= 2:
		var c2 := Rewards.make("gear", lv, true)
		Profile.reward_chests.append(c2)
		out.chests.append(c2)
	out.chests.append_array(ActivityLoot.dungeon_chests(lv, diff))
	Profile.materials["crystal"] = int(Profile.materials.get("crystal", 0)) + int(out.crystals)
	# plan : sûr au 1er donjon terminé de chaque difficulté (un seul plan par zone : la fabrication suit ensuite
	# la meilleure difficulté terminée), sinon une fois sur dix
	if randf() < PLAN_CHANCE or cleared(zid, diff) == 0:
		var plan := "plan_" + zid
		if not plan in Profile.plans:
			Profile.plans.append(plan)
			out.plan = plan
	Profile.records["dungeon_%s_%d" % [zid, diff]] = cleared(zid, diff) + 1
	return out


# --- donjons à la carte (passe M2) ---------------------------------------------------------------
## Chaque boss de la bibliothèque (BossLibrary, 6 par zone) a son donjon dans sa zone : mêmes salles, niveau et
## difficultés que le donjon de la zone ; son boss final et son butin (panoplie + deux emplacements) le distinguent.
## La 3e salle est gardée par un lieutenant (un autre boss de la zone, une seule mécanique). Farmable à volonté.
const LIEUTENANT_ROOM := 3
## Mythique : chance qu'une pièce d'armure soit « éveillée » (légendaire à aura) quand le modèle existe.
const AWAKEN_CHANCE := 0.25
const AWAKEN_SLOTS := ["head", "chest", "legs", "gloves", "boots"]


## Donjons (ids de boss) qui répondent à [param f] : {slot, archetype, family, zone, open} ("" ou absent : tous).
static func catalog(f := {}) -> Array:
	var out: Array = []
	for id in BossLibrary.ids():
		var d := BossLibrary.get_def(id)
		if String(f.get("slot", "")) != "" and not String(f.slot) in (d.get("slots", []) as Array):
			continue
		if String(f.get("archetype", "")) != "" and String(d.get("archetype", "")) != String(f.archetype):
			continue
		if String(f.get("family", "")) != "" and not String(f.family) in BossLibrary.families_of(id):
			continue
		if String(f.get("zone", "")) != "" and String(d.zone) != String(f.zone):
			continue
		if f.get("open", false) and not is_open(String(d.zone)):
			continue
		out.append(id)
	return out


static func boss_zone(bid: String) -> String:
	return String(BossLibrary.get_def(bid).get("zone", ""))


## Nom du donjon du boss [param bid] (« Grotte de Latif »).
static func dungeon_name(bid: String) -> String:
	return String(BossLibrary.get_def(bid).get("lair", BossLibrary.short_name(bid)))


static func boss_key(bid: String, diff: int) -> String:
	return "dgb_%s_%d" % [bid, diff]


static func boss_cleared(bid: String, diff: int) -> int:
	return int(Profile.records.get(boss_key(bid, diff), 0))


## Lieutenant du donjon de [param bid] : le boss suivant de la même zone (jamais lui-même).
static func lieutenant_of(bid: String) -> String:
	var zl := BossLibrary.for_zone(boss_zone(bid))
	if zl.size() < 2:
		return ""
	return String(zl[(zl.find(bid) + 1) % zl.size()])


## Emplacements du butin en texte (« Torse · Jambes »).
static func slot_text(bid: String) -> String:
	return " · ".join((BossLibrary.loot(bid).slots as Array).map(func(s): return String(Items.SLOT_NAMES.get(s, s))))


## Aperçu d'un coffre de donjon à la carte (même règle que slot_pieces).
static func chest_preview(chest: Dictionary) -> String:
	var slots: Array = (chest.get("slots", []) as Array).map(func(s): return String(Items.SLOT_NAMES.get(s, s)).to_lower())
	var set_name := String(Items.SETS.get(String(chest.get("archetype", "")), {}).get("name", ""))
	return "3 pièces au choix (%s), panoplie %s ; légendaire : %s%s." % [" ou ".join(slots), set_name, Rewards._legend_text(chest),
		" ; une pièce d'armure peut être éveillée" if int(chest.get("diff", 0)) >= 2 else ""]


## Propositions d'un coffre de donjon à la carte : 3 pièces d'Eden des emplacements du boss (le 1er, le 2e, puis le 1er
## encore), au niveau du donjon, mythiques ou légendaires (Rewards.top_rarity : selon la PE), éveillées parfois en
## Mythique ; jamais une pièce déjà possédée ni deux fois la même.
static func slot_pieces(chest: Dictionary) -> Array:
	var slots: Array = chest.get("slots", [])
	if slots.is_empty():
		return []
	var lv := int(chest.get("plevel", 1))
	var target := _eden_level(lv)
	var wtype := Profile.main_weapon_type()
	var skip: Dictionary = GearShopPage.owned_ids()
	var out: Array = []
	for i in 3:
		var slot := String(slots[i % slots.size()])
		var rar := Rewards.top_rarity(chest)
		var awaken := int(chest.get("diff", 0)) >= 2 and slot in AWAKEN_SLOTS and randf() < AWAKEN_CHANCE
		var e := _template(slot, wtype, target, Items.LEGENDARY if awaken else rar, awaken, skip)
		if e.is_empty() and awaken:
			awaken = false
			e = _template(slot, wtype, target, rar, false, skip)
		if e.is_empty() and rar != Items.MYTHIC:
			rar = Items.MYTHIC
			e = _template(slot, wtype, target, rar, false, skip)
		if e.is_empty():
			continue
		skip[int(e.id)] = true
		var it := Items.from_template(e, lv, Items.LEGENDARY if awaken else rar)
		if awaken:
			it["awakened"] = true
		out.append(it)
	return out


## Niveau d'Eden des pièces d'un donjon de niveau [param lv] (la zone dont la tranche de niveaux le contient).
static func _eden_level(lv: int) -> int:
	for i in GameData.zones.size():
		if lv <= int(GameData.zone_run_levels(i).y):
			return GameData.eden_level_at(i, lv)
	return GameData.eden_level_at(GameData.zones.size() - 1, lv)


## Modèle d'Eden de [param slot] (arme : du type [param wtype]) à la rareté [param rar], le plus haut sans dépasser
## [param target] (à 6 niveaux près), sinon le plus bas au-dessus ; hors [param skip].
static func _template(slot: String, wtype: String, target: int, rar: int, awaken: bool, skip: Dictionary) -> Dictionary:
	var c: Array = GameData.eden_items.filter(func(e): return String(e.get("slot", "")) == slot 		and (slot != "weapon" or String(e.get("wtype", "")) == wtype) and int(e.get("rarity", 0)) == rar 		and GameData.is_awakened(e) == awaken and Trophies.in_pool(e) and not skip.has(int(e.id)))
	if c.is_empty():
		return {}
	var below := c.filter(func(e): return int(e.level) <= target)
	if not below.is_empty():
		var top := 0
		for e in below:
			top = maxi(top, int(e.level))
		return below.filter(func(e): return int(e.level) >= top - 6).pick_random()
	var low := 1000
	for e in c:
		low = mini(low, int(e.level))
	return c.filter(func(e): return int(e.level) <= low + 4).pick_random()
