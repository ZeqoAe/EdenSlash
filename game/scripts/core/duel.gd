class_name Duel
extends RefCounted
## Mode Duel : 1 contre 1 contre un héros d'une classe (ClassRival, l'IA de l'entraînement)
## dans une arène, en 2 manches gagnantes. On s'y inscrit avec un build complet (requirements) :
## preset de sorts actif (4 cases), points de maîtrise et certificats posés, arme et armure,
## tenue portée. Le héros se bat exactement avec ce build (sorts du preset, talents,
## certificats, équipement, apparence), au niveau de son équipement ; l'adversaire porte un
## équipement du même niveau. Rien n'est perdu ; une victoire rapporte de la maîtrise (League.pvp_mastery,
## réduite en duel libre), les modes classés aussi leurs récompenses (voir [method settle]), et les
## victoires sont comptées (records « duel_wins », « duel_win_<classe>_<difficulté> ») : la sauvegarde
## n'est pas écrite pendant le duel, elle est rechargée à la sortie.

const ROUNDS_TO_WIN := 2
const ARMOR := ["head", "chest", "legs", "gloves", "boots"]
const ZONE := "arid"  # arène à piliers, éclairée

static var active := false
static var rival_class := "warrior"
## Duel à l'arme (mode A) : aucune pièce, aucun talent ni certificat, niveau choisi (1 à 100), arme de la
## classe (variante au choix). Sinon duel équipé (mode B) : tout ce que tu as réglé compte.
static var bare := false
## Mode du duel : "free" (libre), "league" (Ligue) ou "pantheon" ; les deux derniers sont classés.
static var mode := "free"
static var last_report: Dictionary = {}
## Équipes (Arènes, Gantelet) : classes des alliés IA du joueur et des adversaires en plus du premier.
static var team_allies: Array = []
static var extra_foes: Array = []
static var bare_level := 10
static var bare_variant := 0
static var _stashed_build: Dictionary = {}
static var _stashed_mults: Array = []
static var _weakened := false  # adversaire du duel en cours affaibli (voir foe_weakened)
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
	if bare:
		# à l'arme : seul le preset de sorts compte (rien d'autre n'entre dans le combat)
		var n := 0
		for col in p.get("cols", []):
			if int(col[0]) != 0:
				n += 1
		return [{"ok": n >= 4, "label": "Preset de sorts actif, 4 cases remplies",
			"hint": ("Preset « %s » : %d case(s) sur 4" % [p.name, n]) if not p.is_empty() else "Aucun preset actif (Grimoire > Créer un preset)", "section": "grimoire"}]
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


## Prêt pour un duel à l'arme : seul le preset de sorts compte.
static func is_ready_bare(cid: String) -> bool:
	var was := bare
	bare = true
	var ok := is_ready(cid)
	bare = was
	return ok


static func is_ready(cid: String) -> bool:
	return requirements(cid).all(func(r): return r.ok)


## Niveau du duel équipé : celui de l'équipement porté (sa pièce la plus haute), 1 au moins.
static func gear_level() -> int:
	var lv := 1
	for slot in Profile.equipped:
		lv = maxi(lv, mini(Items.power_cap(Profile.equipped[slot]), 101))
	return lv


## Inscription : la run du duel avec la classe [param cid] (build du preset) contre
## [param opponent] en difficulté [param diff].
static func ranked() -> bool:
	return active and mode in ["league", "pantheon", "arena2", "arena3", "gauntlet"]


## Adversaire scripté supplémentaire de la classe [param cid] (équipes) : même fiche que le premier.
static func make_extra(cid: String) -> ClassRival:
	var keep := rival_class
	rival_class = cid
	var r := make_rival()
	rival_class = keep
	return r


## Allié IA du joueur (Arènes) : un héros scripté du camp du joueur, au niveau du duel.
static func make_ally(cid: String) -> ClassRival:
	var a := ClassRival.new()
	a.ally = true
	a.setup(cid, level, 2)
	var b := opti_build(cid, level)
	if not b.is_empty() and not bare:
		a.apply_build(b, level)
	return a


## Le duel libre a été rendu plus facile (préparation de l'adversaire : PV ou dégâts réduits, adversaire de
## l'éditeur) : il ne rapporte pas de maîtrise.
static func foe_weakened() -> bool:
	return not rival_build.is_empty() or hp_mult < 1.0 or atk_mult < 1.0


## Maîtrise d'une victoire hors Ligue (formule commune League.pvp_mastery), créditée à la classe [param cid].
static func _grant_mastery(cid: String, r: Dictionary) -> void:
	var m := League.pvp_mastery(mode, wins, difficulty, extra_foes.size())
	if m <= 0:
		return
	Profile.add_expertise(cid, m)
	r["mastery"] = m
	(r.text as Array).append("Maîtrise : +%d" % m)


## Résultat du duel qui vient de finir (Ligue : rang et maîtrise ; Panthéon : récompenses et maîtrise ; Arènes et
## Gantelet : maîtrise, insignes plafonnés au jour, titre ; duel libre : maîtrise réduite).
static func settle(won: bool, cid: String) -> Dictionary:
	match mode:
		"league":
			var r := League.report(won, cid, wins)
			r["mode"] = "league"
			return r
		"pantheon":
			var r := Pantheon.report_win(pilot, cid) if won else {}
			if not r.has("text"):
				r["text"] = []
			r["mode"] = "pantheon"
			if won:
				# palier = rang du cerveau (1 à 6), comme un rang de Ligue
				var m := League.mastery_for(wins, Pantheon.index_of(pilot) + 1, float(League.MODE_FACTOR.pantheon))
				Profile.add_expertise(cid, m)
				r["mastery"] = m
				(r.text as Array).append("Maîtrise : +%d" % m)
			return r
		"arena2", "arena3", "gauntlet":
			var key := "%s_wins" % mode if mode != "gauntlet" else "gauntlet_%d_wins" % (extra_foes.size() + 1)
			var r := {"mode": mode, "text": []}
			if won:
				Profile.record_add(key, 1)
				_grant_mastery(cid, r)
				var gain := League.win_insignia(key.trim_suffix("_wins"))
				Profile.insignia += gain
				r["insignia"] = gain
				r.text.append("+%d insignes%s" % [gain, " (1re victoire du jour)" if gain > League.REPEAT_INSIGNIA else ""])
				if int(Profile.records.get(key, 0)) == 1:
					var title: String = {"arena2": "Arène à deux", "arena3": "Arène à trois", "gauntlet": "Gantelet"}[mode]
					if mode == "gauntlet" and extra_foes.size() >= 2:
						title = "Gantelet complet"
					Profile.add_title(title)
					r.text.append("Titre : « %s »" % title)
			return r
		"free":
			var r := {"mode": mode, "text": []}
			if won and not _weakened:
				_grant_mastery(cid, r)
			return r
	return {}


static func start(cid: String, opponent: String, diff: int) -> void:
	active = true
	last_report = {}
	if mode in ["league", "pantheon", "arena2", "arena3"]:
		bare = true  # Ligue, Panthéon et Arènes : à l'arme
		bare_level = Pantheon.LEVEL
	elif mode == "gauntlet":
		bare = false  # le Gantelet se joue équipé : tout ton build compte
	if not mode in ["arena2", "arena3", "gauntlet"]:
		team_allies = []
		extra_foes = []
	# la préparation de l'adversaire (PV, dégâts) ne vaut que pour le duel libre : remise après le duel
	_stashed_mults = [hp_mult, atk_mult]
	if mode != "free":
		hp_mult = 1.0
		atk_mult = 1.0
	rival_class = String(rival_build.get("class", opponent)) if not rival_build.is_empty() else opponent
	difficulty = clampi(diff, 0, ClassRival.NAMES.size() - 1)
	wins = 0
	losses = 0
	round_n = 1
	level = clampi(bare_level, 1, 100) if bare else gear_level()
	PvpCaps.reset_stats()
	_stashed_build = {}
	if bare:
		_stashed_build = rival_build  # l'adversaire de l'éditeur revient après le duel
		rival_build = {}
	_weakened = foe_weakened()  # (à l'arme, l'adversaire de l'éditeur est déjà mis de côté)
	Run.start(cid)
	Run.zone_id = ZONE
	Run.fill_from_preset()
	if bare:
		# rien de la méta dans le combat (la sauvegarde n'est pas écrite en duel, elle est rechargée à la sortie)
		Profile.equipped = {}
		Profile.talents[cid] = {}
		Profile.certificates = []
		Profile.cert_board = ["", "", "", "", "", "", ""]


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
	if bare:
		h.built = true  # à l'arme : l'adversaire non plus n'a ni pièces ni bonus
		h.foe_gear = {}
		h.foe_extra = {}
		return
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
	RunJournal.end_map("victoire" if won else "defaite", {"rival": rival_class, "difficulty": difficulty, "rounds": [wins, losses]})
	active = false
	Run.active = false
	Profile.in_run = false
	Profile.reload_keep_records()
	if bare:
		rival_build = _stashed_build
	Profile.gold = 0
	Profile.keys = 0
	Profile.bag = {}
	last_report = settle(won, Run.class_id)
	if _stashed_mults.size() == 2:
		hp_mult = float(_stashed_mults[0])
		atk_mult = float(_stashed_mults[1])
		_stashed_mults = []
	if won:
		if bare and level <= 1:
			Profile.record_add("duel_lv1", 1)
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
