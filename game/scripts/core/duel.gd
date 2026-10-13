class_name Duel
extends RefCounted
## Mode Duel : 1 contre 1 contre un héros d'une classe (ClassRival, l'IA de l'entraînement)
## dans une arène, en 2 manches gagnantes. On s'y inscrit avec un build complet (requirements) :
## preset de sorts actif (4 cases), points de maîtrise et certificats posés, arme et armure,
## tenue portée. Le héros se bat exactement avec ce build (sorts du preset, talents,
## certificats, équipement, apparence), au niveau de son équipement ; l'adversaire porte un
## équipement du même niveau. Rien n'est gagné ni perdu, sauf les victoires comptées
## (records « duel_wins », « duel_win_<classe>_<difficulté> ») : la sauvegarde n'est pas
## écrite pendant le duel, elle est rechargée à la sortie.

const ROUNDS_TO_WIN := 2
const ARMOR := ["head", "chest", "legs", "gloves", "boots"]
const ZONE := "arid"  # arène à piliers, éclairée
const RIVAL_HP := 0.6  # PV de l'adversaire (× ceux de l'entraînement : il a lui aussi de l'équipement)

static var active := false
static var rival_class := "warrior"
static var difficulty := 2
static var level := 1
static var wins := 0
static var losses := 0
static var round_n := 1
## Préparation de l'adversaire (lobby, « Préparer l'adversaire ») : équipement généré à ton
## niveau ou copie du tien, ses 4 sorts (0 : choisi par l'IA), multiplicateurs de PV et de dégâts.
const GEAR_MODES := ["Généré à ton niveau", "Copie de ton équipement"]
static var gear_mode := 1
static var rival_spells: Array = [0, 0, 0, 0]
static var hp_mult := 1.0
static var atk_mult := 1.0


## Sorts que l'adversaire peut utiliser (ceux de sa classe, hors renforcements et soins).
static func spell_choices(cid: String) -> Array:
	return (GameData.class_data(cid).get("skills", []) as Array).filter(func(s): return String(s.kind) != "buff" and String(s.kind) != "heal")


## Conditions d'inscription pour la classe [param cid] : [{ok, label, hint, section}]
## (section : page de l'écran Héros à ouvrir pour régler ce point).
static func requirements(cid: String) -> Array:
	var out: Array = []
	var p := SpellPresets.active(cid)
	var mains := 0
	for col in p.get("cols", []):
		if int(col[0]) != 0:
			mains += 1
	out.append({"ok": mains >= 4, "label": "Preset de sorts actif, 4 cases remplies",
		"hint": ("Preset « %s » : %d case(s) sur 4" % [p.name, mains]) if not p.is_empty() else "Aucun preset actif (Grimoire > Créer un preset)", "section": "grimoire"})
	var pts := Profile.talent_points(cid)
	var spent := Profile.talent_spent(cid)
	out.append({"ok": spent >= pts, "label": "Points de maîtrise attribués", "hint": "%d / %d point(s) attribués" % [spent, pts], "section": "class"})
	var open := 0
	var filled := 0
	for pos in CertBoard.POS.size():
		if Profile.is_cert_open(pos):
			open += 1
			if String(Profile.cert_board[pos]) != "":
				filled += 1
	var need := mini(open, Profile.unlocked_certificates().size())
	out.append({"ok": filled >= need, "label": "Certificats posés", "hint": "%d / %d emplacement(s) occupé(s)" % [filled, need], "section": "class"})
	var missing: PackedStringArray = []
	if not Profile.equipped.has("weapon"):
		missing.append("arme")
	for s in ARMOR:
		if not Profile.equipped.has(s):
			missing.append({"head": "tête", "chest": "torse", "legs": "jambes", "gloves": "gants", "boots": "bottes"}[s])
	out.append({"ok": missing.is_empty(), "label": "Arme et armure équipées", "hint": "Tout est équipé" if missing.is_empty() else "Manque : " + ", ".join(missing), "section": "equipment"})
	var has_outfits := not Profile.owned_outfits.is_empty()
	var outfit := Profile.outfit_of(cid)
	out.append({"ok": outfit != "" or not has_outfits, "label": "Apparence équipée", "hint": ("Tenue portée" if outfit != "" else "Aucune tenue portée") if has_outfits else "Aucune tenue débloquée : tenue de base", "section": "appearance"})
	return out


static func is_ready(cid: String) -> bool:
	return requirements(cid).all(func(r): return r.ok)


## Niveau du duel : celui de l'équipement porté (sa pièce la plus haute), 10 au moins.
static func gear_level() -> int:
	var lv := 10
	for slot in Profile.equipped:
		lv = maxi(lv, mini(Items.power_cap(Profile.equipped[slot]), 101))
	return lv


## Inscription : la run du duel avec la classe [param cid] (build du preset) contre
## [param opponent] en difficulté [param diff].
static func start(cid: String, opponent: String, diff: int) -> void:
	active = true
	rival_class = opponent
	difficulty = clampi(diff, 0, ClassRival.NAMES.size() - 1)
	wins = 0
	losses = 0
	round_n = 1
	level = gear_level()
	Run.start(cid)
	Run.zone_id = ZONE
	Run.fill_from_preset()


## Adversaire de la manche : sa classe, au niveau du duel, avec son équipement.
static func make_rival(lv := -1) -> ClassRival:
	var at := level if lv < 0 else lv
	var r := ClassRival.new()
	r.setup(rival_class, at, difficulty, RIVAL_HP)
	var gear: Array = []
	if gear_mode == 1:
		gear = Profile.equipped.values()  # copie exacte de ton équipement (améliorations comprises)
	else:
		seed(hash([rival_class, at, difficulty]))
		for slot in Tower.DUEL_SLOTS:
			gear.append(Items.generate(at, 0.3 + 0.2 * difficulty, slot, rival_class, 0, "", 3))
		randomize()
	var was := Run.hero_level
	var was_active := Run.active
	Run.hero_level = at
	Run.active = true  # puissance des objets au niveau du duel, même pour l'aperçu du lobby
	r.apply_gear(gear)
	Run.hero_level = was
	Run.active = was_active
	r.max_hp *= hp_mult
	r.hp = r.max_hp
	r.atk *= atk_mult
	# sorts choisis (sinon les 4 premiers de sa classe)
	var picked: Array = []
	for id in rival_spells:
		for s in spell_choices(rival_class):
			if int(s.id) == int(id) and not picked.has(s):
				picked.append(s)
	if not picked.is_empty():
		r._skills = picked
	r.display_name = "<Duel> %s · %s" % [GameData.class_data(rival_class).get("name_fr", rival_class), String(ClassRival.NAMES[difficulty]).to_lower()]
	return r


static func win_key(opponent: String, diff: int) -> String:
	return "duel_win_%s_%d" % [opponent, diff]


static func wins_against(opponent: String, diff: int) -> int:
	return int(Profile.records.get(win_key(opponent, diff), 0))


## Fin du duel : sauvegarde rechargée, victoire comptée. Renvoie {won, total}.
static func finish(won: bool) -> Dictionary:
	if not active:
		return {}
	active = false
	Run.active = false
	Profile.in_run = false
	Profile.load_profile()
	Profile.gold = 0
	Profile.keys = 0
	Profile.bag = {}
	if won:
		Profile.record_add("duel_wins", 1)
		Profile.record_add(win_key(rival_class, difficulty), 1)
	Profile._lobby_view()
	Profile.save_profile()
	return {"won": won, "total": wins_against(rival_class, difficulty)}


static func leave(tree: SceneTree) -> void:
	if active:
		finish(false)
	tree.paused = false
	tree.change_scene_to_file.call_deferred("res://scenes/lobby.tscn")
