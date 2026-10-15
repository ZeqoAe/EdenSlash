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
static var _armory_jobs: Array = []  # tirages restant à faire : [époque, carte, coffre, type d'arme]
static var _armory_next := 0
static var _armory_part: Dictionary = {}
const ARMORY_CACHE := "user://armory_cache.json"
## Fichiers dont dépend le tirage des coffres : si l'un change, le cache disque n'est plus bon.
const ARMORY_SOURCES := ["res://scripts/core/slot_chests.gd", "res://scripts/core/epochs.gd", "res://scripts/core/trophies.gd",
	"res://scripts/core/game_data.gd", "res://scripts/core/items.gd", "res://data/dev_edits.json", "res://data/eden_catalog.json"]


## Pièces d'Eden que les coffres d'emplacement de la Survie peuvent proposer (donc découvrir pour
## l'Armurerie), hors trophées : {id d'Eden -> époque dont un coffre la propose en premier}. Calculé une fois sur les
## mêmes tirages que la Survie (`SlotChests.pool`, pour chaque époque, carte, emplacement et type d'arme) ; le calcul
## dure près d'une seconde, donc il est gardé sur disque (cache par version, P2) et `warm_armory()` le fait par
## tranches pendant que le lobby s'affiche. Hors du lobby (en run), renvoie ce qui est déjà calculé.
static func armory_ids() -> Dictionary:
	if not _armory_ids.is_empty() or Profile.in_run:
		return _armory_ids
	if _armory_load_cache():
		return _armory_ids
	_armory_prepare()
	while _armory_next < _armory_jobs.size():
		_armory_step()
	_armory_finish()
	return _armory_ids


## Prépare le catalogue de l'Armurerie sans bloquer l'affichage : cache disque, sinon une tranche de quelques
## millisecondes par image (un appel à `armory_ids()` entre-temps termine le travail d'un coup).
static func warm_armory() -> void:
	if not _armory_ids.is_empty() or Profile.in_run or _armory_load_cache():
		return
	_armory_prepare()
	var loop := Engine.get_main_loop() as SceneTree
	while _armory_ids.is_empty() and _armory_next < _armory_jobs.size() and not Profile.in_run:
		var t := Time.get_ticks_usec()
		while _armory_next < _armory_jobs.size() and Time.get_ticks_usec() - t < 5000:
			_armory_step()
		if _armory_next < _armory_jobs.size():
			await loop.process_frame
	if _armory_ids.is_empty() and _armory_next >= _armory_jobs.size() and not _armory_jobs.is_empty():
		_armory_finish()


static func _armory_prepare() -> void:
	if not _armory_jobs.is_empty():
		return
	_armory_part = {}
	_armory_next = 0
	# un coffre d'arme ne propose que le type de l'arme de la classe : un tirage par type d'arme
	var types := {}
	for cid in GameData.classes:
		types[Items.default_weapon_type(String(cid))] = true
	for ep in range(1, Epochs.count() + 1):
		for stage in range(1, 4):
			for box in SlotChests.BOXES:
				if SlotChests.is_cards(box) or box == "trophy":
					continue
				for wt in (types.keys() if box == "weapon" else [""]):
					_armory_jobs.append([ep, stage, box, String(wt)])


static func _armory_step() -> void:
	var j: Array = _armory_jobs[_armory_next]
	_armory_next += 1
	for e in SlotChests.pool(String(j[2]), int(j[0]), int(j[1]), String(j[3])):
		if not _armory_part.has(int(e.id)):
			_armory_part[int(e.id)] = int(j[0])  # la première époque dont un coffre la propose


static func _armory_finish() -> void:
	_armory_ids = _armory_part
	_armory_jobs = []
	_armory_next = 0
	_armory_part = {}
	var f := FileAccess.open(ARMORY_CACHE, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"key": _armory_key(), "ids": _armory_ids}))
		f.close()


## Clé du cache : version, taille du catalogue et empreinte des fichiers dont dépend le tirage (absents d'un jeu
## exporté : seule la version compte alors, et un jeu exporté ne change pas).
static func _armory_key() -> String:
	var parts: Array = [Version.NUMBER, str(GameData.eden_items.size()), str(Epochs.count())]
	for p in ARMORY_SOURCES:
		parts.append(FileAccess.get_sha256(p) if FileAccess.file_exists(p) else "-")
	return "|".join(parts).sha256_text()


static func _armory_load_cache() -> bool:
	if not FileAccess.file_exists(ARMORY_CACHE):
		return false
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(ARMORY_CACHE))
	if not d is Dictionary or String(d.get("key", "")) != _armory_key() or not d.get("ids") is Dictionary:
		return false
	var out := {}
	for k in d.ids:
		out[int(k)] = int(d.ids[k])
	if out.is_empty():
		return false
	_armory_ids = out
	return true


## Total de l'Armurerie (calculé, 0.1.165 ; c'était 154 écrit en dur).
static func armory_total() -> int:
	return armory_ids().size()


## Pièces découvertes qui sont de l'équipement (les trophées de la Survie et les pièces des Esprits du Panthéon
## entrent aussi dans `seen_gear`, hors du compte).
static func armory_done() -> int:
	var n := 0
	for id in Profile.seen_gear:
		if not Pantheon.is_shop_id(int(id)) and String(GameData.eden_by_id.get(int(id), {}).get("slot", "")) != "trophy":
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
