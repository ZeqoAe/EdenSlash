class_name Royale
extends RefCounted
## Battle royale (idée 9 de conception/IDEES_EN_VRAC.md) : 8 héros (toi et 7 héros scriptés) tombent nus,
## niveau 1, sur une grande carte remplie de coffres. Le niveau monte par coffres et éliminations, un anneau
## se referme en quatre phases (3 min 30 en tout), le dernier debout gagne. Chacun pour soi : voir
## Combatant.ffa_id. Le déroulement est dans RoyaleDirector ; ici l'état de la partie, le calendrier de
## l'anneau, les héros adverses et les récompenses.
##
## Comme le Duel, la sauvegarde n'est pas écrite pendant la partie (elle est rechargée à la sortie) :
## l'équipement, l'or et les fournitures de la partie ne sont jamais gardés.

const PLAYERS := 8
const LEVEL_CAP := 40
const COUNTDOWN := 6.0
const START_RADIUS := 260.0  # anneau de départ : toute la carte (512 m)
## Phases de l'anneau : attente (le cercle ne bouge pas), resserrement, rayon final, dégâts par seconde
## hors de l'anneau (part des PV max). La dernière est la mort subite, sans resserrement.
const PHASES := [
	{"hold": 35.0, "shrink": 15.0, "radius": 170.0, "dps": 0.02},
	{"hold": 30.0, "shrink": 15.0, "radius": 110.0, "dps": 0.04},
	{"hold": 30.0, "shrink": 15.0, "radius": 60.0, "dps": 0.07},
	{"hold": 25.0, "shrink": 20.0, "radius": 14.0, "dps": 0.12},
	{"hold": 25.0, "shrink": 0.0, "radius": 14.0, "dps": 0.2},
]
## Qualités de coffre : raretés de l'équipement proposé (min, max), chance, expérience (en niveaux),
## potions lâchées (chance du premier, nombre sûr), cartes proposées (chance).
const CHEST_TIERS := [
	{"min_r": 0, "max_r": 2, "luck": 0.25, "xp": 0.55, "potion": 0.4, "potions": 0, "card": 0.0},
	{"min_r": 1, "max_r": 3, "luck": 0.45, "xp": 0.85, "potion": 1.0, "potions": 1, "card": 0.35},
	{"min_r": 3, "max_r": 5, "luck": 0.75, "xp": 1.3, "potion": 1.0, "potions": 2, "card": 0.8},
]
## Expérience d'une élimination (en niveaux).
const KILL_XP := 1.0
## Difficulté des adversaires : -1 = mélange (de facile à hardcore), sinon 0 à 3 pour les sept.
const MIX := [0, 1, 1, 2, 2, 2, 3]
const DURATION := 210.0

static var active := false
static var difficulty := -1
static var rank := 0  # place finale du joueur (1 = vainqueur), 0 tant que la partie dure
static var kills := 0
static var last_report: Dictionary = {}
static var zone_id := "limestone"


## Rayon, centre et phase de l'anneau à l'instant [param t] (secondes de combat). [param centers] : le
## centre de chaque phase (centers[0] = la carte, puis un par phase), choisi au tirage (voir [method roll_centers]).
static func ring_at(t: float, centers: Array) -> Dictionary:
	var from_r := START_RADIUS
	var from_c: Vector2 = centers[0]
	var t0 := 0.0
	for i in PHASES.size():
		var ph: Dictionary = PHASES[i]
		var to_r := float(ph.radius)
		var to_c: Vector2 = centers[i + 1]
		var hold := float(ph.hold)
		var shrink := float(ph.shrink)
		var lt := t - t0
		if lt < hold:
			return {"phase": i, "state": "hold" if i < PHASES.size() - 1 else "final", "radius": from_r, "center": from_c, "next_radius": to_r, "next_center": to_c,
				"dps": float(ph.dps), "left": hold - lt}
		if lt < hold + shrink:
			var f := (lt - hold) / shrink
			return {"phase": i, "state": "shrink", "radius": lerpf(from_r, to_r, f), "center": from_c.lerp(to_c, f),
				"next_radius": to_r, "next_center": to_c, "dps": float(ph.dps), "left": hold + shrink - lt}
		t0 += hold + shrink
		from_r = to_r
		from_c = to_c
	return {"phase": PHASES.size() - 1, "state": "final", "radius": from_r, "center": from_c, "next_radius": from_r,
		"next_center": from_c, "dps": float(PHASES[PHASES.size() - 1].dps), "left": 0.0}


## Durée totale du calendrier de l'anneau (s).
static func total_time() -> float:
	var s := 0.0
	for ph in PHASES:
		s += float(ph.hold) + float(ph.shrink)
	return s


## Centres des phases : le premier est la carte ; chacun est tiré pour que le nouvel anneau reste dans le précédent.
static func roll_centers(map_center: Vector2, rng: RandomNumberGenerator) -> Array:
	var out: Array = [map_center]
	var r_prev := START_RADIUS
	for ph in PHASES:
		var r := float(ph.radius)
		var room := maxf(0.0, r_prev - r) * 0.85
		var a := rng.randf() * TAU
		out.append((out[out.size() - 1] as Vector2) + Vector2(cos(a), sin(a)) * room * sqrt(rng.randf()))
		r_prev = r
	return out


static func difficulty_for(i: int) -> int:
	return clampi(difficulty, 0, 3) if difficulty >= 0 else int(MIX[i % MIX.size()])


static func start(cid: String) -> void:
	active = true
	rank = 0
	kills = 0
	last_report = {}
	Run.start(cid)  # Profile.begin_run : copie du profil, rien n'est écrit tant que active
	Run.survival = true  # départ sans équipement, les pièces des coffres sont portées tout de suite
	Run.epoch = 1
	zone_id = String(Epochs.zone(randi_range(1, mini(4, Epochs.count())), 1))
	Run.zone_id = zone_id
	Profile.equipped = {}
	Profile.inventory = []
	Profile.gold = 0
	Profile.keys = 0
	Profile.bag = {}
	Potions.start_run()
	PvpCaps.reset_stats()
	Run.changed.emit()


## Niveau des objets des coffres pour un héros de niveau [param lv].
static func loot_level(lv: int) -> int:
	return clampi(lv + 1, 1, LEVEL_CAP)


## Choix d'équipement d'un coffre de qualité [param tier] pour un héros de niveau [param lv] : 3 pièces.
static func chest_items(tier: int, lv: int, cid: String, n := 3) -> Array:
	var def: Dictionary = CHEST_TIERS[clampi(tier, 0, CHEST_TIERS.size() - 1)]
	var out: Array = []
	for i in n:
		out.append(Items.generate(loot_level(lv), float(def.luck), "", cid, int(def.min_r), "", int(def.max_r)))
	return out


## Fiche d'un héros scripté de la classe [param cid], niveau [param lv], portant [param gear] (emplacement -> pièce) :
## un héros complet (Player foe, jamais ajouté à la scène), à libérer après usage.
static func sheet(cid: String, lv: int, gear: Dictionary) -> Player:
	var h := Player.new()
	h.foe = true
	h.class_id = cid
	h.cls = GameData.class_data(cid)
	h.level = lv
	h.built = true
	h.foe_gear = gear
	h.foe_extra = {}
	var was := Run.hero_level
	var was_active := Run.active
	Run.hero_level = lv
	Run.active = true
	h.recalc_stats()
	PvpCaps.apply(h)
	Run.hero_level = was
	Run.active = was_active
	return h


## Héros scripté de la classe [param cid], niveau 1, nu, de difficulté [param diff] (état dans meta "royale").
static func make_ai(cid: String, diff: int, index: int) -> ClassRival:
	var r := ClassRival.new()
	r.setup(cid, 1, diff)
	r.set_meta("royale", {"cid": cid, "diff": diff, "gear": {}, "lv": 1, "prog": 0.0, "chests": 0, "potions": 2, "potion_cd": 0.0, "index": index})
	refresh_ai(r, false)
	return r


## Recalcule les PV, l'attaque et la défense de [param r] d'après son niveau et son équipement. Ses PV gardent leur part.
static func refresh_ai(r: ClassRival, keep_ratio := true) -> void:
	var st: Dictionary = r.get_meta("royale")
	var ratio := r.hp / r.max_hp if keep_ratio and r.max_hp > 0.0 else 1.0
	var lv: int = st.lv
	r.level = lv
	var h := sheet(String(st.cid), lv, st.gear)
	r.use_sheet(h)
	h.free()
	r.hp = r.max_hp * ratio
	r.display_name = "%s · niv. %d" % [GameData.class_data(String(st.cid)).get("name_fr", st.cid), lv]


## Niveaux gagnés par [param r] : [param amount] niveaux (fractions comprises).
static func ai_award(r: ClassRival, amount: float) -> void:
	var st: Dictionary = r.get_meta("royale")
	st.prog = float(st.prog) + amount
	var up := false
	while float(st.prog) >= 1.0 and int(st.lv) < LEVEL_CAP:
		st.prog = float(st.prog) - 1.0
		st.lv = int(st.lv) + 1
		up = true
	if int(st.lv) >= LEVEL_CAP:
		st.prog = 0.0
	if up:
		refresh_ai(r)


## Un coffre de qualité [param tier] ouvert par le héros scripté [param r] : il garde la meilleure des trois pièces
## proposées (si elle bat celle de son emplacement), gagne de l'expérience et parfois une potion.
static func ai_open_chest(r: ClassRival, tier: int) -> void:
	var st: Dictionary = r.get_meta("royale")
	st.chests = int(st.chests) + 1
	var def: Dictionary = CHEST_TIERS[clampi(tier, 0, CHEST_TIERS.size() - 1)]
	var best: Dictionary = {}
	for it in chest_items(tier, int(st.lv), String(st.cid)):
		if best.is_empty() or int(it.get("rarity", 0)) > int(best.get("rarity", 0)):
			best = it
	var gear: Dictionary = st.gear
	var slot := String(best.get("slot", ""))
	if slot != "" and slot != "trophy" and (not gear.has(slot) or int(best.get("rarity", 0)) > int(gear[slot].get("rarity", 0))):
		gear[slot] = best
	if randf() < float(def.potion) * (1.0 if int(def.potions) > 0 else 0.6):
		st.potions = int(st.potions) + 1
	ai_award(r, float(def.xp))
	refresh_ai(r)


## Place finale du joueur éliminé alors qu'il restait [param alive] héros en vie (lui compris).
static func rank_for(alive: int) -> int:
	return clampi(alive, 1, PLAYERS)


## Maîtrise d'une partie (formule commune du JcJ, League.mastery_for) : « manches » = 2 pour la victoire, 1 pour
## le podium ; palier = éliminations (4 au plus) ; × la part du mode et la difficulté (mélange = Difficile).
static func mastery_for(place: int, n_kills: int) -> int:
	var rounds := 2 if place == 1 else (1 if place <= 3 else 0)
	var d := clampi(difficulty if difficulty >= 0 else 2, 0, League.DIFF_FACTOR.size() - 1)
	return League.mastery_for(rounds, mini(n_kills, 4), float(League.MODE_FACTOR.royale) * float(League.DIFF_FACTOR[d]))


## Récompenses d'une partie finie en [param place] avec [param n_kills] éliminations. Les insignes (plafonnés au
## jour : League.royale_insignia), la maîtrise de la classe [param cid], le coffre d'apparence et le titre sont
## crédités ; renvoie {insignia, mastery, chest, title, text: [lignes], first_win}.
static func settle(place: int, n_kills: int, cid: String) -> Dictionary:
	var out := {"insignia": 0, "mastery": 0, "chest": "", "title": "", "text": [], "first_win": false, "place": place, "kills": n_kills}
	var ins := League.royale_insignia(place, n_kills)
	out.insignia = ins
	Profile.insignia += ins
	out.text.append("+%d insignes (place %d, %d élimination%s)" % [ins, place, n_kills, "s" if n_kills > 1 else ""])
	out.mastery = mastery_for(place, n_kills)
	if int(out.mastery) > 0:
		Profile.add_expertise(cid, int(out.mastery))
		out.text.append("Maîtrise : +%d" % int(out.mastery))
	Profile.record_add("royale_games", 1)
	Profile.record_add("royale_kills", n_kills)
	if place == 1:
		Profile.record_add("royale_wins", 1)
		if int(Profile.records.get("royale_wins", 0)) == 1:
			out.first_win = true
			out.title = "Dernier debout"
			Profile.add_title(out.title)
			out.text.append("Titre : « %s »" % out.title)
	var best := int(Profile.records.get("royale_best", 99))
	if place < best:
		Profile.records["royale_best"] = place
	if place <= 3:
		var tier := 4 - place  # 1re : légendaire (3), 2e : épique (2), 3e : rare (1)
		out.chest = Rewards.look_type(tier)
		Profile.chest_add(out.chest, 20)
		out.text.append("Coffre d'apparence %s" % ["rare", "épique", "légendaire"][clampi(tier - 1, 0, 2)])
	return out


## Fin de partie : sauvegarde rechargée, récompenses. Renvoie le bilan (voir [method settle]).
static func finish(place: int) -> Dictionary:
	if not active:
		return {}
	var cid := Run.class_id
	var n_kills := kills
	RunJournal.end_map("victoire" if place == 1 else "defaite", {"mode": "royale", "place": place, "kills": n_kills})
	active = false
	Run.active = false
	Profile.in_run = false
	Profile.reload_keep_records()
	Profile.gold = 0
	Profile.keys = 0
	Profile.bag = {}
	rank = place
	last_report = settle(place, n_kills, cid)
	Profile._lobby_view()
	Profile.save_profile()
	return last_report


static func leave(tree: SceneTree) -> void:
	if active:
		finish(PLAYERS)
	tree.paused = false
	tree.change_scene_to_file.call_deferred("res://scenes/lobby.tscn")
