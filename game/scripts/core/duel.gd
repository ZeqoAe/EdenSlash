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

static var active := false
static var rival_class := "warrior"
static var difficulty := 2
static var level := 1
static var wins := 0
static var losses := 0
static var round_n := 1
## Préparation de l'adversaire (lobby, « Préparer l'adversaire ») : équipement généré à ton
## niveau ou copie du tien, ses 4 sorts (0 : choisi par l'IA), multiplicateurs de PV et de dégâts.
const GEAR_MODES := ["Généré à ton niveau", "Copie de ton équipement", "Build opti de sa classe"]
const GEAR_COPY := 1
const GEAR_OPTI := 2
static var gear_mode := GEAR_COPY  # à armes égales par défaut
static var rival_spells: Array = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]  # 12 : voir grid12
static var hp_mult := 1.0
## IA de l'adversaire : "" = script de l'entraînement (ClassRival, difficulté ci-dessus), sinon
## un cerveau entraîné (MlDuelPilot.BRAINS : debutant … hardcore, actuel) qui pilote un héros.
static var pilot := ""

## Adversaire créé dans l'éditeur (RivalBuilds) : {} pour la préparation rapide ci-dessus.
static var rival_build: Dictionary = {}
static var atk_mult := 1.0


## Sorts de l'adversaire : 12 emplacements, 3 par case (sort principal puis ses 2
## enchaînements) : indice case × 3 + rang ; 0 = choix par défaut (ceux de la classe dans
## l'ordre). Les anciens réglages à 4 sorts deviennent les sorts principaux des 4 cases.
const SPELL_SLOTS := 12


static func grid12(a: Array) -> Array:
	var out: Array = []
	out.resize(SPELL_SLOTS)
	out.fill(0)
	if a.size() == 4:
		for c in 4:
			out[c * 3] = int(a[c])
	else:
		for i in mini(a.size(), SPELL_SLOTS):
			out[i] = int(a[i])
	return out


## Jeu de sorts d'un héros ennemi (cerveau d'IA) d'après la grille : chaque case prend son sort
## principal et ses enchaînements choisis, sinon ceux de la classe dans l'ordre.
static func kit_from_grid(cid: String, grid: Array) -> Dictionary:
	var g := grid12(grid)
	var base := MlDuelPilot.kit_for(cid)
	var skills: Array = []
	var chains := {}
	for c in 4:
		var main := int(g[c * 3])
		if main == 0 and c < base.skills.size():
			main = int(base.skills[c].id)
		if main == 0:
			continue
		skills.append({"id": main, "rank": 1})
		var ch: Array = []
		for r in [1, 2]:
			if int(g[c * 3 + r]) != 0:
				ch.append({"id": int(g[c * 3 + r]), "rank": 1})
		if ch.is_empty():
			ch = base.chains.get(c, [])
		if not ch.is_empty():
			chains[skills.size() - 1] = ch
	return {"skills": skills, "chains": chains}


## Sorts choisis pour l'adversaire scripté (ses attaques ; les renforcements et soins ne
## servent qu'au héros piloté par un cerveau d'IA).
static func scripted_spells(cid: String, grid: Array) -> Array:
	var picked: Array = []
	for id in grid12(grid):
		for s in spell_choices(cid):
			if int(s.id) == int(id) and not picked.has(s):
				picked.append(s)
	return picked


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
	rival_class = String(rival_build.get("class", opponent)) if not rival_build.is_empty() else opponent
	difficulty = clampi(diff, 0, ClassRival.NAMES.size() - 1)
	wins = 0
	losses = 0
	round_n = 1
	level = gear_level()
	Run.start(cid)
	Run.zone_id = ZONE
	Run.fill_from_preset()


static var _opti: Array = []


## Profil « opti » généré (tools/gen_profiles) de la classe [param cid], au niveau le plus
## proche de [param lv] ({} s'il n'y en a pas).
static func opti_build(cid: String, lv: int) -> Dictionary:
	if _opti.is_empty():
		# les profils du jeu, même quand RivalBuilds lit le fichier de test
		var all = JSON.parse_string(FileAccess.get_file_as_string(RivalBuilds.PATH))
		_opti = (all as Array).filter(func(b): return b is Dictionary and String(b.get("auto", "")) != "") if all is Array else [{}]
	var best: Dictionary = {}
	for b in _opti:
		if String(b.get("auto", "")) == "" or String(b.get("class", "")) != cid:
			continue
		if best.is_empty() or absi(int(b.get("level", 0)) - lv) < absi(int(best.get("level", 0)) - lv):
			best = b
	return best


## Équipe le héros ennemi [param h] (Player, foe) comme l'adversaire préparé : profil de
## l'éditeur, build opti de sa classe, copie de ton équipement ou équipement généré.
static func equip_foe(h: Player, lv: int) -> void:
	var b := rival_build
	if b.is_empty() and gear_mode == GEAR_OPTI:
		b = opti_build(rival_class, lv)
	if not b.is_empty():
		h.use_build(b, lv)
		return
	h.built = true
	h.foe_gear = {}
	if gear_mode == GEAR_COPY:
		h.foe_gear = Profile.equipped.duplicate(true)  # copie exacte de ton équipement (améliorations comprises)
		h.foe_extra = Run.passive_stats()  # et de tes bonus (maîtrise, certificats et leur placement)
	else:
		seed(hash([rival_class, lv, difficulty]))
		for slot in Tower.DUEL_SLOTS:
			h.foe_gear[slot] = Items.generate(lv, 0.3 + 0.2 * difficulty, slot, rival_class, 0, "", 3)
		randomize()


## Fiche du héros que l'adversaire scripté imite (stats calculées comme celles d'un héros,
## plafonds du duel compris). À libérer après usage.
static func rival_sheet(lv: int) -> Player:
	var h := Player.new()
	h.foe = true
	h.class_id = rival_class
	h.cls = GameData.class_data(rival_class)
	h.level = lv
	equip_foe(h, lv)
	var was := Run.hero_level
	var was_active := Run.active
	Run.hero_level = lv
	Run.active = true  # puissance des objets au niveau du duel, même pour l'aperçu du lobby
	h.recalc_stats()
	PvpCaps.apply(h)
	Run.hero_level = was
	Run.active = was_active
	return h


## Adversaire de la manche : sa classe, au niveau du duel, avec la fiche d'un héros équipé
## (voir [method equip_foe]).
static func make_rival(lv := -1) -> ClassRival:
	var at := level if lv < 0 else lv
	var r := ClassRival.new()
	var cid := String(rival_build.get("class", rival_class)) if not rival_build.is_empty() else rival_class
	r.setup(cid, at, difficulty)
	if not rival_build.is_empty():
		# adversaire de l'éditeur : son apparence et ses sorts (ses stats : la fiche ci-dessous)
		r.apply_build(rival_build, at)
	var h := rival_sheet(at)
	r.use_sheet(h)
	h.free()
	if not rival_build.is_empty():
		r.max_hp *= float(rival_build.get("hp_mult", 1.0))
		r.atk *= float(rival_build.get("atk_mult", 1.0))
		r.hp = r.max_hp
		return r
	r.max_hp *= hp_mult
	r.hp = r.max_hp
	r.atk *= atk_mult
	# sorts choisis (sinon les 4 premiers de sa classe)
	var picked := scripted_spells(rival_class, rival_spells)
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
	Profile.reload_keep_records()
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
