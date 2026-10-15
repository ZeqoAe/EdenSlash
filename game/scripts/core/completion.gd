class_name Completion
extends RefCounted
## Complétion du Carnet (lot 11) : dix catégories, chacune « obtenu / total ». Rien de ce qui est
## compté ne donne de la puissance en soi ; c'est la vue d'ensemble de la sauvegarde.

static func cards_total() -> int:
	return Boons.all().size()


static func cards_done() -> int:
	var n := 0
	for b in Boons.all():
		if Cards.card_unlocked(String(b.id)):
			n += 1
	return n


static func certs_total() -> int:
	var n := 0
	for cid in GameData.talents:
		n += (GameData.talents[cid].get("certificates", []) as Array).size()
	return n


static func weapons_total() -> int:
	var n := 0
	for wt in WeaponAttacks.SPECS:
		n += (WeaponAttacks.SPECS[wt] as Array).size()
	return n


static var _armory_ids: Dictionary = {}


## Pièces d'Eden que les coffres d'emplacement de la Survie peuvent proposer (donc découvrir pour
## l'Armurerie), hors trophées : {id d'Eden -> true}. Calculé une fois sur les mêmes tirages que la Survie
## (`SlotChests.pool`, pour chaque époque, carte, emplacement et type d'arme) ; hors du lobby (en run),
## renvoie ce qui est déjà calculé.
static func armory_ids() -> Dictionary:
	if not _armory_ids.is_empty() or Profile.in_run:
		return _armory_ids
	# un coffre d'arme ne propose que le type de l'arme de la classe : une classe par type d'arme
	var by_type := {}
	for cid in GameData.classes:
		by_type[Items.default_weapon_type(String(cid))] = String(cid)
	var saved := Profile._view_class
	for ep in range(1, Epochs.count() + 1):
		for stage in range(1, 4):
			for box in SlotChests.BOXES:
				if SlotChests.is_cards(box) or box == "trophy":
					continue
				for cid in (by_type.values() if box == "weapon" else [by_type.values()[0]]):
					Profile._view_class = String(cid)
					for e in SlotChests.pool(box, ep, stage):
						_armory_ids[int(e.id)] = true
	Profile._view_class = saved
	return _armory_ids


## Total de l'Armurerie (calculé, 0.1.165 ; c'était 154 écrit en dur).
static func armory_total() -> int:
	return armory_ids().size()


## Pièces découvertes qui sont de l'équipement (les trophées de la Survie entrent aussi dans `seen_gear`).
static func armory_done() -> int:
	var n := 0
	for id in Profile.seen_gear:
		if String(GameData.eden_by_id.get(int(id), {}).get("slot", "")) != "trophy":
			n += 1
	return n


## [[nom, obtenu, total, détail]] pour les dix catégories.
static func categories() -> Array:
	var classes := int(Achievements.value("classes"))
	var tower := int(Achievements.value("tower_best"))
	var ep := int(Achievements.value("epochs"))
	var league := League.rank_index()
	return [
		["Classes", classes, GameData.classes.size(), "classes débloquées"],
		["Maîtrise", int(Achievements.value("mastery20")), GameData.classes.size(), "classes à la maîtrise 20"],
		["Cartes", cards_done(), cards_total(), "cartes débloquées"],
		["Certificats", Profile.unlocked_certificates().size(), certs_total(), "certificats débloqués"],
		["Trophées", Profile.seen_trophies.size(), Trophies.KINDS.size(), "effets de trophée découverts"],
		["Armes", Profile.weapon_legend.size(), weapons_total(), "variantes menées à l'effet légendaire"],
		["Équipement", armory_done(), maxi(armory_done(), armory_total()), "pièces découvertes en Survie"],
		["Époques et Tour", Epochs.total_stars() + mini(tower / 50, 4), Epochs.count() * 3 + 4, "étoiles d'époque et paliers de la Tour"],
		["Activités", league, League.RANKS.size() - 1, "rangs de la Ligue"],
		["Succès", int(Achievements.count().x), int(Achievements.count().y), "succès obtenus"],
	]


## Pourcentage global (moyenne des catégories).
static func percent() -> int:
	var sum := 0.0
	var cats := categories()
	for c in cats:
		sum += float(c[1]) / maxf(float(c[2]), 1.0)
	return roundi(100.0 * sum / float(cats.size()))
