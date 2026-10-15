class_name Economy
extends RefCounted
## Barème unique des insignes et pont vers la maîtrise des 60 classes (lot E5 de la nuit du 15/10, détail et chiffres
## dans `conception/nuit_15_10/R_E5.md`, règles dans DESIGN.md « Insignes et maîtrise des 60 classes »).
## - Insignes = acquérir. La Survie en est la source de référence ; les autres activités donnent au plus autant à
##   l'heure (JcJ plafonné au jour : League.win_insignia ; Donjons, Ruée, Siège, Tour : cristaux et matières).
## - Armurerie à paliers : la 1re pièce d'un palier (même emplacement, type d'arme, niveau, rareté) coûte son prix
##   plein, les autres pièces du même palier (autres panoplies, autres attributs : utiles à d'autres classes) 15 %
##   (armory_price, appelé par l'Armurerie : `GearShopPage.price`).
## - Puits sobres, jamais de puissance gratuite : coffres d'apparence et d'auras (limite par semaine), leçons de
##   maîtrise (classes en retard seulement, limite par jour).
## - Maîtrise des 60 classes : rattrapage (classe en retard sur la meilleure), 1re victoire de la classe à chaque
##   époque, part de l'arbre de classe (parent et classes qui en descendent, plus basses).

# --- barème des insignes ---------------------------------------------------------------------------------------
## Durée estimée d'une Survie victorieuse (3 cartes + boss + portail), en minutes.
const SURVIVAL_MINUTES := 35.0
## Survie victorieuse type : monstres et élites vaincus sur les 3 cartes.
const SURVIVAL_KILLS := 600
const SURVIVAL_ELITES := 10
## Cible d'insignes par heure de chaque activité (100 % de victoires ; JcJ : 1re heure du jour). Contrôlée par test_e5.
const INSIGNIA_PER_HOUR := {
	"survie_1": 360, "survie_4": 670,  # référence (survival_insignia)
	"jcj": 450,  # Arènes, Gantelet, Battle royale : 1re victoire du jour pleine, puis 10 (League.win_insignia)
	"jcj_suite": 60,  # heures suivantes du même jour
	"donjons": 0, "tour": 0, "siege": 0,  # rôle : cristaux et matières (ActivityLoot), pas d'insignes
}


## Insignes d'une Survie (Run.finish) : participation dès 10 monstres, 25 par carte atteinte, monstres / 20,
## élites × 2, victoire 60 × époque (avant Défi ×1,5 et rang héroïque).
## Passe E6 : une run arrêtée sur la 1re carte ne touche la participation et les 25 de la 1re carte qu'au prorata
## du temps joué sur cette carte ([param map1_minutes] / ENTRY_MINUTES, les 10 minutes avant la rage ; négatif : pas de
## prorata). Sans ça, abandonner au bout d'une minute rapportait 50 insignes, soit ≈ 2 000 à l'heure, 4 à 6 fois une
## Survie gagnée ; mourir exprès en 3 minutes ≈ 1 000 à l'heure.
const ENTRY_MINUTES := 10.0
static func survival_insignia(stage: int, kills: int, elites: int, epoch: int, victory: bool, map1_minutes := -1.0) -> int:
	var p := survival_insignia_parts(stage, kills, elites, epoch, victory, map1_minutes)
	return int(p.participation) + int(p.maps) + int(p.fights) + int(p.victory)


## Détail du barème (bilan de la Survie, Run.insignia_parts) : participation (avec les 25 de la 1re carte, au prorata
## sur la 1re carte), cartes suivantes atteintes, monstres et élites, victoire.
static func survival_insignia_parts(stage: int, kills: int, elites: int, epoch: int, victory: bool, map1_minutes := -1.0) -> Dictionary:
	var entry := float((Run.INSIGNIA_BASE if kills >= 10 else 0) + 25)
	if stage <= 1 and map1_minutes >= 0.0:
		entry *= clampf(map1_minutes / ENTRY_MINUTES, 0.0, 1.0)
	return {"participation": roundi(entry), "maps": 25 * (stage - 1), "fights": kills / 20 + elites * 2, "victory": 60 * epoch if victory else 0}


## Insignes à l'heure d'une Survie victorieuse type de l'époque [param ep].
static func survival_insignia_per_hour(ep: int) -> int:
	return roundi(survival_insignia(3, SURVIVAL_KILLS, SURVIVAL_ELITES, ep, true) * 60.0 / SURVIVAL_MINUTES)


# --- Armurerie à paliers ---------------------------------------------------------------------------------------
## Prix d'une pièce de plus d'un palier déjà entamé (part du prix plein).
const TIER_REPEAT := 0.15


## Prix plein d'une pièce de l'Armurerie : selon la rareté et le niveau.
static func base_price(e: Dictionary) -> int:
	if GameData.is_awakened(e):
		return 250
	var lv := int(e.get("level", 1))
	return 80 + 2 * lv if int(e.get("rarity", 0)) >= Items.LEGENDARY else 30 + lv


## Palier d'une pièce d'Eden : emplacement, type d'arme, niveau, rareté, éveil. Une pièce des Esprits (Panthéon)
## est son propre palier : jamais de remise.
static func tier_key(e: Dictionary) -> String:
	if Pantheon.is_shop_id(int(e.get("id", -1))):
		return "pantheon|%d" % int(e.id)
	return "%s|%s|%d|%d|%s" % [String(e.get("slot", "")), String(e.get("wtype", "")) if String(e.get("slot", "")) == "weapon" else "",
		int(e.get("level", 0)), int(e.get("rarity", 0)), "a" if GameData.is_awakened(e) else ""]


## Paliers déjà entamés : une pièce d'Eden de ce palier est dans le coffre commun ou portée. {clé -> true}
static func owned_tiers() -> Dictionary:
	var out := {}
	for it in Profile.all_items():
		var e: Dictionary = GameData.eden_by_id.get(int(it.get("eden", -1)), {})
		if not e.is_empty():
			out[tier_key(e)] = true
	return out


## Prix en insignes de la pièce [param e] à l'Armurerie ([param tiers] : owned_tiers(), calculé au besoin).
static func armory_price(e: Dictionary, tiers = null) -> int:
	var p := base_price(e)
	var t: Dictionary = tiers if tiers is Dictionary else owned_tiers()
	return maxi(1, roundi(p * TIER_REPEAT)) if t.has(tier_key(e)) else p


# --- puits : coffres d'apparence et d'auras --------------------------------------------------------------------
## Coffres achetables avec des insignes : prix et nombre par semaine. Une apparence n'est jamais un doublon
## (Rewards.roll_look) ; quand toute la collection est obtenue, l'achat est fermé.
const SHOP_CHESTS := {
	"look_rare": {"price": 150, "week": 3},
	"look_epic": {"price": 300, "week": 2},
	"look_legend": {"price": 600, "week": 1},
	"aura_rare": {"price": 400, "week": 1},
	"aura_legend": {"price": 900, "week": 1},
}
static var day_override := ""  # tests : jour imposé (AAAA-MM-JJ)


static func today() -> String:
	return day_override if day_override != "" else Time.get_date_string_from_system()


## Semaine en cours (lundi de la semaine, AAAA-MM-JJ) : les limites par semaine repartent le lundi.
static func week() -> String:
	var unix := Time.get_unix_time_from_datetime_string(today())
	var wd := int(Time.get_datetime_dict_from_unix_time(unix).weekday)  # 0 = dimanche
	return Time.get_date_string_from_unix_time(unix - ((wd + 6) % 7) * 86400)


## Compteurs des puits (remis à zéro chaque semaine / chaque jour) : Profile.records.insignia_shop.
static func _shop_state() -> Dictionary:
	var d = Profile.records.get("insignia_shop", {})
	if not d is Dictionary:
		d = {}
	if String(d.get("week", "")) != week():
		d["week"] = week()
		d["chests"] = {}
	if String(d.get("day", "")) != today():
		d["day"] = today()
		d["lessons"] = 0
	Profile.records["insignia_shop"] = d
	return d


## Coffres de [param type] encore achetables cette semaine.
static func chest_left(type: String) -> int:
	if not SHOP_CHESTS.has(type):
		return 0
	return maxi(0, int(SHOP_CHESTS[type].week) - int((_shop_state().chests as Dictionary).get(type, 0)))


## Reste-t-il, dans la collection, une apparence (ou aura) pas encore obtenue de la rareté du coffre [param type] ?
## (Un coffre gagné en jeu se rabat sur une autre rareté ; un coffre acheté, non : il se ferme.)
static func chest_has_content(type: String) -> bool:
	if type.begins_with("aura"):
		return not Rewards.roll_aura(type).is_empty()
	var want: Array = Rewards.LOOKS.get(type, [])
	return GameData.collection.any(func(x): return want.has(int(x.get("rarity", 0))) and not Profile.collected(x) \
		and (x.has("aura") or x.has("skin") or (int(x.get("cat", 9)) <= 3 and GameData.cosmetic_by_code.has(String(x.get("code", ""))))) \
		and not String(x.get("name", "")).contains("(Alpha)"))


static func can_buy_chest(type: String) -> bool:
	return chest_left(type) > 0 and Profile.insignia >= int(SHOP_CHESTS[type].price) and chest_has_content(type)


## Achète un coffre de [param type] (rangé dans le menu Coffres) ; renvoie vrai si c'est fait.
static func buy_chest(type: String) -> bool:
	if not can_buy_chest(type):
		return false
	Profile.insignia -= int(SHOP_CHESTS[type].price)
	var c: Dictionary = _shop_state().chests
	c[type] = int(c.get(type, 0)) + 1
	Profile.chest_add(type, maxi(Profile.best_level, 10))
	Profile.changed.emit()
	Profile.save_profile()
	return true


# --- maîtrise des 60 classes -----------------------------------------------------------------------------------
## Rattrapage : une classe en retard d'au moins CATCHUP_GAP niveaux sur la meilleure classe du compte gagne
## ×CATCHUP_MULT de maîtrise en Survie, jusqu'au niveau CATCHUP_MAX.
const CATCHUP_GAP := 3
const CATCHUP_MULT := 1.5
const CATCHUP_MAX := 20
## 1re victoire de la classe à l'époque I, II, III, IV (Survie, une fois par classe et par époque).
const FIRST_WIN := [600, 900, 1200, 1500]
## Part de l'arbre de classe : la maîtrise gagnée par une classe profite à ses voisines de l'arbre (classe
## d'origine et classes qui en descendent), débloquées et de niveau plus bas, à hauteur de cette part.
const TREE_SHARE := 0.1
## Leçon de maîtrise (puits d'insignes) : LESSON_COST insignes -> LESSON_MASTERY points pour une classe en retard.
const LESSON_COST := 200
const LESSON_MASTERY := 300
const LESSONS_PER_DAY := 3


## Niveau de maîtrise de la meilleure classe du compte.
static func best_mastery_level() -> int:
	var best := 1
	for cls in Profile.expertise:
		best = maxi(best, Profile.expertise_level(String(cls)))
	return best


## La classe [param cls] est-elle en retard (rattrapage, leçons) ?
static func lagging(cls: String) -> bool:
	var lv := Profile.expertise_level(cls)
	return lv < CATCHUP_MAX and lv <= best_mastery_level() - CATCHUP_GAP


## Maîtrise de Survie après rattrapage.
static func catchup(cls: String, gain: int) -> int:
	return roundi(gain * CATCHUP_MULT) if gain > 0 and lagging(cls) else gain


## 1re victoire de [param cls] à l'époque [param ep] : renvoie le bonus (0 si déjà gagnée) et la marque comme gagnée
## (Profile.records.class_first_wins : classe -> masque des époques).
static func first_win(cls: String, ep: int) -> int:
	var i := clampi(ep, 1, FIRST_WIN.size()) - 1
	var d = Profile.records.get("class_first_wins", {})
	if not d is Dictionary:
		d = {}
	var mask := int(d.get(cls, 0))
	if mask & (1 << i):
		return 0
	d[cls] = mask | (1 << i)
	Profile.records["class_first_wins"] = d
	return int(FIRST_WIN[i])


## Voisines de [param cls] dans l'arbre des classes : classes de sa condition de déblocage et classes dont la
## condition la cite.
static func tree_neighbours(cls: String) -> Array:
	var out: Array = []
	var own := Progression.requirement(cls)
	for c in (own[1] if not own.is_empty() else []):
		if not String(c[0]) in out:
			out.append(String(c[0]))
	for other in GameData.classes:
		var r := Progression.requirement(String(other))
		if r.is_empty() or String(other) in out:
			continue
		for c in r[1]:
			if String(c[0]) == cls:
				out.append(String(other))
				break
	return out


## Part de l'arbre : [param amount] gagnés par [param cls] ; renvoie {classe: points} donnés aux voisines.
static func share_tree(cls: String, amount: int) -> Dictionary:
	var out := {}
	var part := floori(amount * TREE_SHARE)
	if part <= 0:
		return out
	var lv := Profile.expertise_level(cls)
	for n in tree_neighbours(cls):
		if Progression.class_unlocked(n) and Profile.expertise_level(n) < lv:
			out[n] = part
	return out


## Leçons de maîtrise encore achetables aujourd'hui.
static func lessons_left() -> int:
	return maxi(0, LESSONS_PER_DAY - int(_shop_state().lessons))


static func can_buy_lesson(cls: String) -> bool:
	return lessons_left() > 0 and Profile.insignia >= LESSON_COST and Progression.class_unlocked(cls) and lagging(cls)


## Achète une leçon de maîtrise pour [param cls] ; renvoie les niveaux gagnés (-1 : impossible).
static func buy_lesson(cls: String) -> int:
	if not can_buy_lesson(cls):
		return -1
	Profile.insignia -= LESSON_COST
	var s := _shop_state()
	s["lessons"] = int(s.lessons) + 1
	var lv := Profile.add_expertise(cls, LESSON_MASTERY, false)
	Profile.changed.emit()
	Profile.save_profile()
	return lv
