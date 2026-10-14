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
		["Équipement", Profile.seen_gear.size(), maxi(Profile.seen_gear.size(), 154), "pièces découvertes en Survie"],
		["Époques et Tour", ep + mini(tower / 50, 4), Epochs.count() + 4, "époques gagnées et paliers de la Tour"],
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
