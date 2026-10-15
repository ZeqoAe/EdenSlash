class_name RunDirector
extends Node3D
## Déroulement d'une run sur une map générée (voir DESIGN.md) :
## 10 minutes d'exploration et de farm, puis la rage ; le donjon est accessible
## dès que son entrée est découverte et mène à l'arène du boss.

signal message(text: String, duration: float)
signal zone_changed(zone: Dictionary)
signal objective_changed(text: String)
signal prompt_changed(text: String)
signal npc_opened(kind: String, npc: Interactable)
signal boss_defeated
signal extracted
signal better_item(item: Dictionary)  # objet ramassé meilleur que la pièce portée

const EXTRACT_TIME := 10.0
var extracting := false
var extract_left := 0.0
var _extract_tick := 0.0

const RUN_TIME := 600.0
const DISCOVER_DUNGEON := 32.0
const DISCOVER_CHEST := 18.0
const CAMP_ACTIVATE := 55.0
const CAMP_RESPAWN := 40.0
const BOSS_ADDS_EVERY := 14.0
const FOG_RES := 128
## Niveau maximal du butin par zone : la map 1 ne donne pas d'équipement au-delà du
## niveau 15 (les maps suivantes prendront le relais). Les monstres plafonnent au
## même niveau, +3 pendant la rage (plus durs, mais le butin reste plafonné).
const ZONE_MAX_LEVEL := {"limestone": 15}
const RAGE_LEVEL_BONUS := 3
## Escalade de la rage (retour du joueur, 15/10) : la rage est un chronomètre qui force la fin de la carte.
## Une minute par palier, PV et dégâts des monstres de la carte (pas du boss) × RAGE_TIERS[palier - 1],
## en plus de la rage elle-même (+3 niveaux, dégâts ×1,3, vitesse ×1,25) ; le dernier palier dure.
const RAGE_STEP := 60.0
const RAGE_TIERS := [1.1, 2.0, 11.0, 101.0]
var _rage_tier := 0

var world: Node  # world.gd
var map  # ProcMap
var player: Player
var state := "explore"  # explore, rage, boss, cleared
var zone: Dictionary
var kills := 0
var time := 0.0
var dungeon_found := false
var chests_opened := 0
var shrines_captured := 0
var _found := {}  # marchands et sanctuaires découverts (instance -> true)
var _shrine_timer := 0.0
## Coffres de la carte : prix en or qui monte à chaque coffre ouvert (ou une clé), selon leur
## qualité ; ils proposent de l'équipement au choix (façon Megabonk).
const CHEST_BASE := 20  # prix du 1er coffre (+3 par niveau du héros), +18 % à chaque coffre ouvert
const CHEST_GROWTH := 1.18
## Qualités de coffre : prix ×, raretés de l'équipement proposé (min, max), chance, nombre de
## fournitures données en plus.
const CHEST_TIERS := [
	{"price": 1.0, "min_r": 1, "max_r": 3, "luck": 0.3, "supplies": 1},  # épique 18 % par proposition
	{"price": 2.5, "min_r": 2, "max_r": 4, "luck": 0.45, "supplies": 2},  # mythique 7 %, épique 26 %
	{"price": 6.0, "min_r": 3, "max_r": 5, "luck": 0.75, "supplies": 3},  # légendaire 15 %, mythique 22 %
]
## Objets cassables : or (× niveau), chances de soin, de fourniture, de clé.
const BREAK_GOLD := {"pot": [1, 3], "crate": [2, 4], "gold": [10, 16], "gem": [0, 0]}
## Or par monstre tué : 1 + niveau × KILL_GOLD (× KILL_GOLD_ELITE pour une élite). Retour du
## joueur (0.1.118) : l'or ne manquait jamais, il ne force plus de choix.
const KILL_GOLD := 0.5
const KILL_GOLD_ELITE := 2.5
const BREAK_HEAL := 0.06
const BREAK_SUPPLY := {"pot": 0.025, "crate": 0.05}
const BREAK_KEY := 0.006
## Autel de cupidité : or et butin ×1,5, monstres +25 % (PV et dégâts) jusqu'à la fin de la carte.
const GREED_GOLD := 1.5
const GREED_MONSTERS := 1.25
var greed := false
## Étapes d'une run (façon Megabonk) : le boss d'une étape vaincu, un portail mène à la zone
## suivante ; niveau, cartes, équipement, or et clés sont gardés. Victoire après la dernière.
const STAGES := 3
var _touch_timer := 0.0
var _gold_pop := 0  # or des objets cassés pas encore affiché
var _gold_pop_timer := 0.0
var _challenges: Array = []  # défis en cours : {station, monsters}
const DISCOVER_POI := 45.0
const SHRINE_PRESSURE := 3.5  # secondes entre deux groupes de monstres pendant une capture
const MERCHANT_ROAM := 14.0  # rayon de promenade des marchands ambulants
var route := PackedVector3Array()

var _camp_ready_at := {}  # index de camp -> instant
var _roam_timer := 2.0
var _wave_timer := 60.0
const EARLY_RAMP := 300.0  # durée de la montée en puissance du début de run (s)
const EARLY_EASE := 0.45  # PV et dégâts des monstres au tout début (×)
var _wave_hard := false
var seals := 0
var _despawn_timer := 2.0
const SEALS_NEEDED := 3
## Plafond de monstres vivants (vagues, hordes et escortes comprises) : au-delà, le jeu
## ralentit sans rendre le combat plus intéressant. Les monstres restés loin derrière
## sont retirés quand la foule approche du plafond (ils reviennent dans les vagues).
const MAX_ALIVE := {"explore": 80, "rage": 110}
const FAR_DESPAWN := 55.0
var _elite_timer := 25.0
var _adds_timer := BOSS_ADDS_EVERY
var _route_timer := 0.0
var _objective_timer := 0.0
var _boss: Monster
var _near: Interactable
var _last_safe := Vector3.ZERO
var _trail: MultiMeshInstance3D
var _fog: Image
var _fog_tex: ImageTexture
var _fog_timer := 0.0
var _roster: Array = []  # monstres normaux de la zone, par niveau
var _elites: Array = []
var _seed := 0
var orbs: XpOrbs  # orbes d'expérience au sol
var tower: TowerDirector  # mode Tour : étages successifs (Tower)
var duel: DuelDirector  # mode Duel : manches contre un héros (Duel)
var royale: RoyaleDirector  # mode Battle royale : huit héros, un anneau (Royale)
var sv: SurvivorDirector  # mode Survivant : 20 minutes, une carte, tout aux cartes (Survivor) ; null sinon


func start(p: Player) -> void:
	Menace.reset()  # Menace et pacte : propres à chaque run (passe P12)
	RunJournal.context = _journal_context
	player = p
	zone = GameData.zone(Run.zone_id)
	_roster = zone.monsters.map(func(x): return int(x))
	_elites = zone.get("elites", []).map(func(x): return int(x))
	_seed = Run.seed if Run.seed != 0 else randi()
	if Royale.active:
		# Battle royale : la grande carte, huit héros, un anneau (le directeur monte la carte)
		royale = RoyaleDirector.new()
		add_child(royale)
		royale.setup(self)
		return
	if Duel.active:
		# duel : une arène, pas de grande carte
		Music.play(Music.DUEL)
		state = "duel"
		_fog = Image.create(FOG_RES, FOG_RES, false, Image.FORMAT_LA8)
		_fog.fill(Color(0, 0, 0, 0))
		_fog_tex = ImageTexture.create_from_image(_fog)
		duel = DuelDirector.new()
		add_child(duel)
		duel.setup(self)
		return
	if Tower.active:
		# la Tour : pas de grande carte, une salle par étage
		Music.play(Music.TOWER)
		state = "tower"
		_fog = Image.create(FOG_RES, FOG_RES, false, Image.FORMAT_LA8)
		_fog.fill(Color(0, 0, 0, 0))
		_fog_tex = ImageTexture.create_from_image(_fog)
		tower = SiegeDirector.new() if Tower.siege else TowerDirector.new()
		add_child(tower)
		tower.setup(self)
		return
	if Survivor.active:
		sv = SurvivorDirector.new(self)
	map = world.new_run_map(_seed)
	_place_player(map.start)
	if map.breakables:
		map.breakables.broken.connect(_on_broken)
	Music.play_zone(String(zone.get("id", "")))
	orbs = XpOrbs.new()
	add_child(orbs)
	if not Run.instant_card.is_connected(_on_instant_card):
		Run.instant_card.connect(_on_instant_card)
	_fog = Image.create(FOG_RES, FOG_RES, false, Image.FORMAT_LA8)
	_fog.fill(Color(0, 0, 0, 1))
	_fog_tex = ImageTexture.create_from_image(_fog)
	_emit_zone()
	if Training.active:
		state = "training"
		_fog.fill(Color(0, 0, 0, 0))  # la mini-carte montre toute la zone (rien à explorer)
		_fog_tex.update(_fog)
		message.emit("Zone d'entraînement\nF3 : panneau (niveau, sorts, cartes, ennemis, DPS)", 4.0)
		return
	_refresh_chest_labels()
	GiantAltar.attach(self)  # mesures : --giants=N
	if sv and sv.start_message() != "":
		message.emit(sv.start_message(), 4.5)
	elif Run.survival:
		message.emit("%s · %s\nTu pars avec ton équipement du hub : les coffres de la carte le remplacent le temps de la run, puis trouve le donjon" % [zone.name, Epochs.get_def(Run.epoch).name], 4.5)
	else:
		message.emit("%s\nCasse tout, ouvre les coffres, forge ton équipement, puis trouve le donjon" % zone.name, 3.5)


## Carte à effet immédiat. Rappel : orbes et objets de toute la carte reviennent au héros.
func _on_instant_card(id: String) -> void:
	if id != "recall":
		return
	if orbs:
		orbs.recall()
	var n := 0
	for d in get_tree().get_nodes_in_group("loot"):
		(d as Node3D).global_position = player.global_position + Vector3(randf_range(-0.4, 0.4), 0.2, randf_range(-0.4, 0.4))
		n += 1
	message.emit("Rappel : %d orbes et %d objets reviennent !" % [orbs.count() if orbs else 0, n], 2.5)


func _place_player(pos: Vector3) -> void:
	player.global_position = pos + Vector3.UP * 0.6
	player.velocity = Vector3.ZERO
	_last_safe = player.global_position


## Contexte de la carte pour le journal de run : coffres posés et ouverts, sites, rage.
func _journal_context() -> Dictionary:
	if map == null:
		return {}
	return {"chests_opened": chests_opened, "chests_total": map.chests.size(), "shrines": shrines_captured,
		"shrines_total": map.shrines.size(), "state": state}.merged(Menace.journal(greed))


func time_left() -> float:
	if sv:
		return maxf(0.0, Survivor.RUN_TIME - time)  # Survivant : le boss à 20:00, pas de rage
	return maxf(0.0, RUN_TIME - time)


func in_dungeon() -> bool:
	return state in ["boss", "cleared"]


# --- boucle -----------------------------------------------------------------------------
func _process(delta: float) -> void:
	if player == null or map == null:
		return
	RunJournal.tick(delta, player.global_position)
	if state == "royale":
		royale.update(delta)
		_update_interactions()
		_update_breakables(delta)
		_keep_on_map()
		return
	if state == "duel":
		duel.update(delta)
		_keep_on_map()
		return
	if state == "tower":
		tower.update(delta)
		_update_interactions()
		_keep_on_map()
		return
	if state == "training":
		# entraînement : pas de minuterie, ni vagues, ni rage
		_update_interactions()
		_keep_on_map()
		_objective_timer -= delta
		if _objective_timer <= 0.0:
			_objective_timer = 0.5
			objective_changed.emit("Entraînement · F3 : panneau")
		return
	time += delta
	_update_extraction(delta)
	if sv:
		sv.update(delta)
	elif state == "explore" and time >= RUN_TIME:
		_start_rage()  # (pas de rage de carte en Survivant : le boss arrive à 20:00)
	if state == "rage" and rage_tier() != _rage_tier:
		_raise_rage(rage_tier())
	match state:
		"explore", "rage":
			_update_discovery()
			if sv == null or not sv.update_spawns(delta):
				_update_spawns(delta)
			_update_shrines(delta)
			_update_merchants(delta)
			_update_breakables(delta)
			_update_challenges()
		"boss":
			_update_boss(delta)
	_update_interactions()
	_update_fog(delta)
	_update_route(delta)
	_objective_timer -= delta
	if _objective_timer <= 0.0:
		_objective_timer = 0.25
		objective_changed.emit(_objective_text())
	_keep_on_map()


func _objective_text() -> String:
	if state == "boss":
		var who := "Vaincs %s !" % (_boss.display_name.trim_prefix("<Boss> ") if is_instance_valid(_boss) else "le boss")
		return who + ("\n" + boss_rage_text() if Run.survival else "")
	if state == "cleared":
		return "Boss vaincu ! Portail vers l'étape %d/%d" % [Run.stage + 1, STAGES] if next_zone_id() != "" else "Boss vaincu !"
	if sv and sv.objective_text() != "":
		return sv.objective_text()
	var t := time_left()
	var clock := rage_text() if state == "rage" else "%02d:%02d" % [int(t) / 60, int(t) % 60] + ("" if sv else " avant la rage")
	return "%s\nDonjon %s   ·   Sceaux %d/%d   ·   Coffres %d/%d   ·   Sanctuaires %d/%d" % [clock,
		"✔" if dungeon_found else "?", seals, SEALS_NEEDED, chests_opened, map.chests.size(), shrines_captured, map.shrines.size()]


func _start_rage() -> void:
	Tutorial.event("rage")
	Run.rage_stages.append(Run.stage)
	state = "rage"
	message.emit("LES MONSTRES ENTRENT EN RAGE !\nDanger accru, butin et XP accrus", 4.0)
	world.set_rage_mood(true)
	for node in get_tree().get_nodes_in_group("monsters"):
		(node as Monster).enrage()
	_rage_tier = 0


## Palier de rage (1 à RAGE_TIERS.size(), 0 hors rage) : un de plus chaque minute de rage.
func rage_tier() -> int:
	if state != "rage":
		return 0
	return clampi(int((time - RUN_TIME) / RAGE_STEP) + 1, 1, RAGE_TIERS.size())


## Multiplicateur de PV et de dégâts des monstres au palier [param tier] (1 hors rage).
static func rage_mult(tier: int) -> float:
	return float(RAGE_TIERS[tier - 1]) if tier >= 1 and tier <= RAGE_TIERS.size() else 1.0


## Secondes avant le palier suivant (-1 au dernier palier ou hors rage).
func rage_next_in() -> float:
	var tier := rage_tier()
	if tier < 1 or tier >= RAGE_TIERS.size():
		return -1.0
	return maxf(0.0, RUN_TIME + RAGE_STEP * tier - time)


## Texte court de la rage : « RAGE ×2 · 0:42 » (multiplicateur, temps avant le palier suivant).
func rage_text() -> String:
	var tier := maxi(rage_tier(), 1)
	var txt := "RAGE ×%s" % fmt_mult(rage_mult(tier))
	var left := rage_next_in()
	if left >= 0.0:
		txt += " · %d:%02d" % [int(left) / 60, int(left) % 60]
	return txt


## Multiplicateur en texte : « 2 », « 101 », « 1,1 ».
static func fmt_mult(m: float) -> String:
	return str(int(m)) if is_equal_approx(m, roundf(m)) else ("%.1f" % m).replace(".", ",")


## Passe au palier de rage [param tier] : les monstres de la carte prennent le nouveau multiplicateur.
func _raise_rage(tier: int) -> void:
	_rage_tier = tier
	for node in get_tree().get_nodes_in_group("monsters"):
		_apply_rage_mult(node as Monster)
	match tier:
		2:
			message.emit("LA RAGE MONTE !\nMonstres deux fois plus forts", 3.5)
		3:
			message.emit("LA RAGE DÉBORDE !\nMonstres onze fois plus forts : file au boss", 4.0)
		4:
			message.emit("FUREUR TOTALE !\nRejoins le boss ou quitte la carte", 4.0)


## Met [param m] au multiplicateur du palier en cours (PV gardés en proportion) ; ni boss ni allié.
func _apply_rage_mult(m: Monster) -> void:
	if m == null or m.is_dead or m.is_boss or m.team != Combatant.Team.MONSTER:
		return
	var k := rage_mult(_rage_tier) / float(m.get_meta("rage_mult", 1.0))
	if is_equal_approx(k, 1.0):
		return
	m.max_hp *= k
	m.hp *= k
	m.atk *= k
	m.set_meta("rage_mult", rage_mult(_rage_tier))


# --- découvertes et interactions ---------------------------------------------------------
func _update_discovery() -> void:
	var p := player.global_position
	for it in map.interactables:
		if is_instance_valid(it) and it.kind == "merchant" and not _found.has(it) and _flat(p, it.global_position) < DISCOVER_POI:
			_found[it] = true
			message.emit("Marchand ambulant !\nCartes, clés et équipement contre de l'or", 2.5)
	for sh in map.shrines:
		if not _found.has(sh) and _flat(p, sh.global_position) < DISCOVER_POI:
			_found[sh] = true
	for it in map.interactables:
		if is_instance_valid(it) and Interactable.STATION_VERBS.has(it.kind) and not _found.has(it) and _flat(p, it.global_position) < DISCOVER_POI:
			_found[it] = true
	for k in map.camps.size():
		if map.camps[k].elite and not _found.has("fort%d" % k) and _flat(p, map.camps[k].pos) < DISCOVER_POI:
			_found["fort%d" % k] = map.camps[k].pos  # fort d'élite : repère sur la carte
	if not dungeon_found and _flat(p, map.dungeon) < DISCOVER_DUNGEON:
		dungeon_found = true
		message.emit("Entrée du donjon découverte !\n[F] pour affronter le boss quand tu es prêt" if sv == null
			else "Portail du boss découvert !\nIl s'ouvre à 15:00", 3.5)


func _update_interactions() -> void:
	var best: Interactable = null
	var best_d := INF
	for it in map.interactables:
		if not is_instance_valid(it) or it.used:
			continue
		var d := _flat(player.global_position, it.global_position)
		if d < it.radius and d < best_d:
			best = it
			best_d = d
	if best != _near:
		_near = best
		prompt_changed.emit(best.prompt() if best else "")
	if best == null:
		return
	var auto := player.autoplay or Settings.auto_move()
	if Input.is_action_just_pressed("interact") or (auto and (best.kind in ["chest", "dungeon", "tower_chest", "tower_stairs", "stage_portal"]
			or (best.kind in AUTO_STATIONS and (best.kind != "well" or player.hp < player.max_hp * 0.7)))):
		_interact(best)


func _interact(it: Interactable) -> void:
	match it.kind:
		"tower_chest", "tower_stairs", "siege_core":
			tower.interact(it)
		"chest" when state == "royale":
			royale.open_chest(it)  # Battle royale : coffres gratuits, qualité = ce qu'ils donnent
		"chest":
			# une clé si on en a, sinon le prix en or (qui monte à chaque coffre ouvert)
			var tier := int(it.get_meta("tier", 0))
			var box := String(it.get_meta("box", ""))
			var price := chest_price(tier, box)
			var how := ""
			if Profile.keys > 0:
				Profile.keys -= 1
				how = "une clé"
			elif Profile.gold >= price:
				Profile.gold -= price
				RunJournal.gold_out(price, "coffres")
				how = "%d or" % price
			else:
				message.emit("%s : %d or (ou une clé)\nTu as %d or" % [it.title.get_slice(" ·", 0), price, Profile.gold], 2.5)
				_near = null
				return
			Profile.changed.emit()
			it.open_chest()
			Sfx.event_at(self, it.global_position, "chest", -2.0)
			chests_opened += 1
			Tutorial.event("chest")
			Run.chests_total += 1
			Profile.record_add("chests", 1)
			message.emit("%s ouvert (%s)" % [it.title.get_slice(" ·", 0), how], 1.5)
			if box != "":
				_open_slot_chest(box)
				_refresh_chest_labels()
				_near = null
				prompt_changed.emit("")
				return
			var def: Dictionary = CHEST_TIERS[tier]
			for i in int(def.supplies) + (1 if state == "rage" else 0):
				_drop_consumable(it.global_position, _monster_level(1), tier, "chest%d" % tier)
			if tier >= 1 or randf() < 0.4:
				_drop_potion(it.global_position, "heal" if tier == 0 else Potions.roll_kind())
			world._offer("%s : choisis une pièce d'équipement" % it.title.get_slice(" ·", 0), gear_cards(3, tier), func(): return gear_cards(3, tier))
			_refresh_chest_labels()
		_ when Interactable.STATION_VERBS.has(it.kind):
			_use_station(it)
		"stage_portal":
			it.used = true  # un seul passage (le fondu dure un instant)
			ScreenFade.run(get_tree(), _next_stage.bind(String(it.get_meta("zone", ""))))
		"dungeon":
			# le bot de test (--boss-after) ignore les sceaux
			if sv and sv.try_enter_boss():
				pass  # Survivant : portail du boss (S4)
			elif seals < SEALS_NEEDED and not (player.autoplay and time > _autoplay_dungeon_time()):
				message.emit("L'entrée est scellée : %d/%d sceaux\nLes gardiens d'élite les portent" % [seals, SEALS_NEEDED], 3.0)
				_near = null
				return
			else:
				ScreenFade.run(get_tree(), _enter_arena)
		_:
			if it.kind == "merchant":
				Tutorial.event("merchant")
			npc_opened.emit(it.kind, it)
	_near = null
	prompt_changed.emit("")


# --- monstres --------------------------------------------------------------------------
## Niveau des monstres : monte avec le temps, +3 en rage, +palier du camp.
func _monster_level(tier: int) -> int:
	if sv and sv.monster_level(tier) > 0:
		return sv.monster_level(tier)  # Survivant : courbe par minute (S4)
	# les zones suivantes : monstres de plus haut niveau (+1 par palier de zone en plus)
	var bonus := float(zone.get("level_bonus", 0))
	var tier_extra := float(GameData.zone_index(String(zone.get("id", "")))) * 0.5
	if Run.survival:
		bonus = float(Epochs.level_bonus(Run.stage))  # puissance normalisée : la map, pas la zone
		tier_extra = 0.0
	var base := 1.0 + bonus + time / 60.0 * 0.9 + (float(RAGE_LEVEL_BONUS) if state == "rage" else 0.0)
	var cap := max_level() + (RAGE_LEVEL_BONUS if state in ["rage", "boss"] else 0)
	return clampi(roundi(maxf(base, player.level - 1.0 + tier_extra) + tier), 1, cap)


## Niveau maximal du butin et des monstres (hors rage) de la zone en cours.
func max_level() -> int:
	if sv and sv.max_level() > 0:
		return sv.max_level()  # Survivant : 90 au plus (S4)
	if Run.survival:
		return Epochs.cap(Run.stage)
	return int(zone.get("max_level", ZONE_MAX_LEVEL.get(String(zone.get("id", "")), 30)))


## Niveau d'un objet donné dans cette zone (plafonné).
func loot_level(level: int) -> int:
	return clampi(level, 1, max_level())


## Niveau des fournitures (parchemins de fortification, formules d'enchantement, coffres de forge) : en
## Survie, celui des pièces de la carte d'époque (le plus haut de l'armure et de l'arme), pour monter au hub
## les pièces de cette époque (sinon le butin plafonné à 15 / 25 / 35 ne servait qu'aux pièces de niveau 40
## au plus). Les fournitures ne servent qu'au hub : la forge est fermée pendant la Survie (lot E4).
func supply_level(level: int) -> int:
	if Run.survival:
		var m := Epochs.map_def(Run.epoch, Run.stage)
		return maxi(int(m.armor), int(m.weapon))
	return loot_level(level)


## Survie : niveaux de butin ajoutés par époque au rang des gemmes (un rang de plus par époque : Craft tire
## les gemmes au niveau / 8 ; les gemmes royales restent la marque des époques avancées et des Donjons Mythiques).
const GEM_EPOCH_LEVELS := 8


## Niveau qui fixe le rang des gemmes et des coffres du joaillier : le niveau du moment, plus un rang par époque.
func gem_level(level: int) -> int:
	return loot_level(level) + (GEM_EPOCH_LEVELS * (Run.epoch - 1) if Run.survival else 0)


## Invocation pendant le combat de boss (renforts, illusions, totems, compagnon).
## [param id] = 0 : un monstre de la salle.
func summon_for_boss(id: int, pos: Vector3, elite := false) -> Monster:
	if not is_instance_valid(_boss):
		return null
	var pool: Array = zone.get("dungeon", {}).get("monsters", [])
	var mid := id if id > 0 and not GameData.monster(id).is_empty() else (int(pool.pick_random()) if not pool.is_empty() else _pick_monster(_boss.level))
	var lvl := maxi(1, _boss.level - (0 if elite else 2))
	var m := _spawn_monster(mid, ground_point(pos, _boss.global_position), lvl)
	if elite:
		m.max_hp *= 3.0
		m.hp = m.max_hp
		m.atk *= 1.3
	return m


## Point au sol le plus proche de [param p] (sinon [param fallback]).
func ground_point(p: Vector3, fallback: Vector3) -> Vector3:
	var g: Vector3 = map.ground_at(p.x, p.z)
	return g if g != Vector3.INF else fallback


func _pick_monster(level: int) -> int:
	# le roster (trié par niveau d'origine) se dévoile avec la progression dans la zone
	var start := 1 + int(zone.get("level_bonus", 0))
	var n := clampi(2 + int((level - start) * _roster.size() / 10.0), 2, _roster.size())
	var options := _roster.slice(0, n)
	# on privilégie les monstres les plus forts disponibles
	return options[mini(options.size() - 1, options.size() - 1 - randi() % mini(3, options.size()))]


## Pression constante : un flux de packs qui fonce sur le héros, des vagues qui
## alternent faciles (nombreux et faibles) et dures (encerclement + élite), et
## les gardiens d'élite des camps qui portent les sceaux du donjon.
func _update_spawns(delta: float) -> void:
	var rage := state == "rage"
	var minutes := time / 60.0
	var alive := get_tree().get_nodes_in_group("monsters").size()
	_despawn_timer -= delta
	if _despawn_timer <= 0.0:
		_despawn_timer = 2.0
		if alive > int(_hard_cap() * 0.8):
			alive -= _despawn_far()
	var cap := 120 if rage else mini(18 + int(minutes * 4.0), 50)
	# gardiens d'élite des camps (une fois chacun, puis toutes les 2 min)
	for k in map.camps.size():
		var camp: Dictionary = map.camps[k]
		if not camp.elite or _elites.is_empty():
			continue
		if _flat(player.global_position, camp.pos) > CAMP_ACTIVATE or time < float(_camp_ready_at.get(k, 0.0)):
			continue
		_camp_ready_at[k] = time + 120.0
		var lvl := _monster_level(int(camp.tier) + 1)
		var e := _spawn_monster(_elites.pick_random(), camp.pos, lvl)
		e.carries_seal = true
		for i in mini(4, _room()):
			_spawn_monster(_pick_monster(lvl), _around(camp.pos, 6.0), lvl)
		message.emit("Un gardien d'élite garde un sceau !", 2.0)
	# flux continu
	_roam_timer -= delta
	if _roam_timer <= 0.0 and alive < cap:
		_roam_timer = randf_range(1.8, 2.6) if rage else maxf(3.5, 6.0 - minutes * 0.3)
		var size := randi_range(8, 12) if rage else mini(4 + int(minutes), 9) + randi_range(0, 2)
		_spawn_pack(size, _monster_level(0), 20.0, 28.0)
	# vagues
	_wave_timer -= delta
	if _wave_timer <= 0.0:
		_wave_timer = 30.0 if rage else 45.0
		_wave_hard = not _wave_hard
		var lvl := _monster_level(1)
		if _wave_hard:
			message.emit("Vague : encerclement !", 2.0)
			# anneau complet autour du héros, plus une élite
			var n := mini(10 + int(minutes * 2.0) + (8 if rage else 0), _room())
			for i in n:
				var a := TAU * i / n
				var p := player.global_position + Vector3(cos(a), 0, sin(a)) * 18.0
				var g: Vector3 = map.ground_at(p.x, p.z)
				if g != Vector3.INF:
					_spawn_monster(_pick_monster(lvl), g, lvl)
			var ep := _ring_point(18.0, 22.0)
			if not _elites.is_empty() and ep != Vector3.INF:
				_spawn_monster(_elites.pick_random(), ep, lvl)
		else:
			message.emit("Vague : horde !", 1.6)
			for k in 3:
				_spawn_pack(6 + int(minutes), maxi(1, lvl - 2), 22.0, 30.0)
	# élites en masse pendant la rage
	if rage and not _elites.is_empty():
		_elite_timer -= delta
		if _elite_timer <= 0.0:
			_elite_timer = 22.0 * (0.5 if Challenge.has("elites_double") else 1.0)
			var c := _ring_point(24.0, 34.0)
			if c != Vector3.INF:
				for i in clampi(_room(), 1, 3):
					_spawn_monster(_elites.pick_random(), _around(c, 5.0), _monster_level(1))
				message.emit("Des élites enragées arrivent !", 2.0)


func _spawn_pack(count: int, level: int, min_d: float, max_d: float) -> void:
	var center := _ring_point(min_d, max_d)
	if center == Vector3.INF:
		return
	var id := _pick_monster(level)
	for i in mini(count, _room()):
		_spawn_monster(id if randf() < 0.7 else _pick_monster(level), _around(center, 4.0), level)


## Plafond de monstres vivants de l'état en cours.
func _hard_cap() -> int:
	return int(MAX_ALIVE.get(state, MAX_ALIVE.explore))


## Places libres sous le plafond.
func _room() -> int:
	return maxi(0, _hard_cap() - get_tree().get_nodes_in_group("monsters").size())


## Retire les monstres ordinaires restés très loin du héros (ni élite, ni boss, ni sceau).
func _despawn_far() -> int:
	var n := 0
	for node in get_tree().get_nodes_in_group("monsters"):
		var m := node as Monster
		if m.is_boss or m.is_elite or m.carries_seal or m.is_dead:
			continue
		if _flat(m.global_position, player.global_position) > FAR_DESPAWN:
			m.queue_free()
			n += 1
	return n


## Dégâts des monstres selon la zone : la première carte sert de tutoriel.
const ZONE_DAMAGE := [0.55, 0.8]


func _spawn_monster(id: int, pos: Vector3, level: int, boss := false, into: Monster = null) -> Monster:
	var m := into if into != null else Monster.new()  # [param into] : un monstre déjà créé (géant de l'autel)
	m.configure(GameData.monster(id), boss, level)
	var own := sv != null and sv.scale_monster(m, boss)  # Survivant : sa courbe remplace les trois blocs suivants (S4)
	var zi := GameData.zone_index(String(zone.get("id", ""))) if not Run.survival else Run.stage - 1
	if zi >= 0 and zi < ZONE_DAMAGE.size() and not own:
		m.atk *= float(ZONE_DAMAGE[zi])
	if Run.survival and not own:
		var em := Epochs.monster_mult(Run.epoch)  # époques suivantes : monstres plus coriaces
		m.max_hp *= em * float(Modifiers.apply("mob_hp", 1.0, ModeRules.modifiers)) * (1.0 + Epochs.HEROIC_HP * Run.heroic_rank)
		m.hp = m.max_hp
		m.atk *= em * (1.0 + Epochs.HEROIC_ATK * Run.heroic_rank)
	if state == "explore" and not own:
		# montée en puissance sur les premières minutes de chaque carte : le joueur doit
		# pouvoir se mettre en place avant que ça devienne punitif
		var k := lerpf(EARLY_EASE, 1.0, clampf(time / EARLY_RAMP, 0.0, 1.0))
		m.max_hp *= k
		m.hp = m.max_hp
		m.atk *= k
	if greed and not boss:
		m.max_hp *= GREED_MONSTERS
		m.hp = m.max_hp
		m.atk *= GREED_MONSTERS
	add_child(m)
	m.global_position = pos + Vector3.UP * 0.4
	m.rotation.y = randf() * TAU
	if state == "rage":
		m.enrage()
		_apply_rage_mult(m)
	m.died.connect(_on_monster_died)
	Menace.apply(m)  # PV × Menace (boss compris, après ses PV fixes)
	return m


func _around(c: Vector3, r: float) -> Vector3:
	for attempt in 6:
		var p := c + Vector3(randf_range(-r, r), 0, randf_range(-r, r))
		var g: Vector3 = map.ground_at(p.x, p.z)
		if g != Vector3.INF:
			return g
	return c


func _ring_point(min_d: float, max_d: float) -> Vector3:
	for attempt in 20:
		var a := randf() * TAU
		var p := player.global_position + Vector3(cos(a), 0, sin(a)) * randf_range(min_d, max_d)
		var g: Vector3 = map.ground_at(p.x, p.z)
		if g != Vector3.INF:
			return g
	return Vector3.INF


func _on_monster_died(who: Combatant, _killer: Combatant) -> void:
	kills += 1
	RunJournal.monster_died(who)
	var m := who as Monster
	if Duel.active:
		return  # duel : rien à gagner sur l'adversaire
	if Tower.active:
		# la Tour : ni expérience (le niveau suit l'étage), ni butin (le coffre de l'étage)
		Run.kills += 1
		Profile.record_add("kills", 1)
		if m.is_elite:
			Run.elites += 1
		return
	if Training.active:
		# entraînement : l'expérience seulement (pas de butin, de clés ni de records)
		if orbs:
			orbs.spawn(m.global_position, m.xp_reward)
		return
	# l'expérience tombe en orbe sous le monstre (à ramasser) ; le boss la donne d'un coup
	if m.is_boss or orbs == null:
		player.gain_xp(m.xp_reward)
	else:
		orbs.spawn(m.global_position, m.xp_reward)
	Run.kills += 1
	Tutorial.event("kill")
	Profile.record_add("kills", 1)
	if m.is_elite or m.is_boss:
		Profile.record_add("elite_kills", 1)
	if m.is_boss:
		Profile.record_add("boss_kills", 1)
	if m.is_elite:
		Run.elites += 1
		# élite : une clé, et un choix de cartes pour les gardiens des camps
		Profile.keys += 1
		Profile.changed.emit()
		message.emit("Clé obtenue (%d)" % Profile.keys, 1.8)
		if m.carries_seal:
			world._offer("Gardien vaincu ! Choisis une carte", Run.roll_cards(3), func(): return Run.roll_cards(3))
	Run.add_gold(roundi((1 + m.level * KILL_GOLD * (KILL_GOLD_ELITE if m.is_elite else 1.0)) * (GREED_GOLD if greed else 1.0)),
		"boss" if m.is_boss else ("elites" if m.is_elite else "monstres"))
	if sv and sv.on_monster_died(m):
		if m == _boss:
			_on_boss_killed()
		return  # Survivant : son butin (potions, clés, cartes ; S4)
	# coffres de récompense (ouverts hors run, menu Coffres) : boss du donjon 100 %, élites 20 %,
	# monstres 0,5 % ; en Survie, forge ou joaillier (l'équipement s'achète au hub)
	var n_chests := 1 if m.is_boss else (1 if (m.is_elite and randf() < 0.2) or randf() < 0.005 else 0)
	if n_chests > 0 and _farm_capped(m, "chests"):
		n_chests = 0
	for i in n_chests:
		_drop_reward_chest(m.global_position, m.level, m.is_boss)
	if seals < SEALS_NEEDED and (m.carries_seal or (m.is_elite and randf() < 0.3)):
		seals += 1
		Tutorial.event("seal")
		message.emit("Sceau du donjon obtenu (%d/%d)" % [seals, SEALS_NEEDED], 2.5)
	var luck := 0.0
	var count := 0
	if m.is_boss:
		count = 3
		luck = 0.5
		# trésor de collection de l'archive d'Eden (apparence, aura, monture, familier...) :
		# 1 chance sur 4, 1 sur 2 si le boss est enragé ; de préférence un trésor portable
		# (Survie : un coffre d'apparence à la place, voir give_look_chest)
		if not Run.survival and randf() < (0.5 if m.enraged else 0.25):
			var locked := GameData.collection.filter(func(x): return not Profile.collected(x))
			var wearable := locked.filter(func(x): return x.has("aura") or x.has("skin") or GameData.cosmetic_by_code.has(String(x.get("code", ""))))
			var pool := wearable if not wearable.is_empty() and randf() < 0.75 else locked
			if not pool.is_empty():
				var x: Dictionary = pool.pick_random()
				Profile.collect(x)
				Run.new_costumes.append(String(x.name))
				message.emit("Trésor de collection : %s !" % x.name, 3.5)
	elif m.is_elite:
		count = 1
		luck = 0.3
	elif randf() < (0.08 if m.enraged else 0.05) * (GREED_GOLD if greed else 1.0):
		count = 1
	if m.enraged:
		luck += 0.2
	if Run.survival:
		count = 0  # Survie : l'équipement vient des coffres d'emplacement seulement
		# arme secondaire : le boss en lâche toujours une, une élite parfois (plus souvent sans)
		var no_off: bool = Profile.equipped.get("offhand", {}).is_empty()
		if m.is_boss or (m.is_elite and randf() < (OFFHAND_DROP_FIRST if no_off else OFFHAND_DROP)):
			_drop_offhand(m.global_position)
	for i in count:  # commun à épique (mythiques et légendaires : coffres de récompense)
		_drop_item(m.global_position, m.level, luck)
	# consommables : gemmes, parchemins, ciseaux, pierres (adaptés au niveau)
	var n_cons := 3 if m.is_boss else (1 if m.is_elite and randf() < 0.35 else (1 if randf() < (0.07 if m.enraged else 0.04) else 0))
	if n_cons > 0 and _farm_capped(m, "supplies"):
		n_cons = 0
	for i in n_cons:
		_drop_consumable(m.global_position, m.level, 1 if (m.is_boss or m.is_elite) else 0)
	if m.is_boss:
		_drop_potion(m.global_position, "heal")
		_drop_potion(m.global_position, "heal")
	elif randf() < (POTION_ELITE if m.is_elite else POTION_MONSTER):
		_drop_potion(m.global_position, Potions.roll_kind())
	if m == _boss:
		_on_boss_killed()


## Passe E6 : en Survie, les monstres ordinaires d'une carte lâchent au plus FARM_CAP coffres de récompense et
## fournitures (une carte jouée normalement : 3 à 5 coffres, 30 à 45 fournitures). Au-delà (rester en rage sur une
## carte pour ses lâchers), seuls les élites, les boss, les défis et les objets cassés donnent encore. Sans ce
## plafond, une carte d'époque IV tenue 15 min en rage donnait plus de parchemins et de formules qu'une heure de
## Ruée ou de Siège, et les coffres sont gardés même sur défaite.
const FARM_CAP := {"chests": 6, "supplies": 60}
var _farm := {}


## Vrai si le lâcher [param kind] (« chests », « supplies ») du monstre [param m] dépasse le plafond de la carte.
func _farm_capped(m: Monster, kind: String) -> bool:
	if not Run.survival or m.is_boss or m.is_elite:
		return false
	var n := int(_farm.get(kind, 0))
	_farm[kind] = n + 1
	return n >= int(FARM_CAP[kind])


## Survie : chances qu'une élite lâche une arme secondaire (sans arme secondaire / avec).
const OFFHAND_DROP_FIRST := 0.4
const OFFHAND_DROP := 0.12


func _drop_item(pos: Vector3, level: int, luck: float, min_r := 0, max_r := 3) -> void:
	var drop := LootDrop.new()
	drop.item = Items.generate(loot_level(level), luck, "", Run.class_id, min_r, "", max_r)
	drop.on_picked = func(item):
		if Items.compare_to_equipped(item) >= 0.05:
			better_item.emit(item)
		else:
			message.emit("Butin : %s" % item.name, 1.5)
	add_child(drop)
	var p := pos + Vector3(randf_range(-1.5, 1.5), 0, randf_range(-1.5, 1.5))
	var g: Vector3 = map.ground_at(p.x, p.z)
	drop.global_position = (g if g != Vector3.INF else pos) + Vector3.UP * 0.2


func _drop_reward_chest(pos: Vector3, level: int, boss: bool) -> void:
	var drop := LootDrop.new()
	var t := Rewards.roll_type(boss)
	if Run.survival and not t in ["forge", "jewel"]:
		t = "forge" if randf() < 0.6 else "jewel"  # Survie : de quoi optimiser au hub (l'équipement s'y achète)
	drop.item = Rewards.loot_item(Rewards.make(t, supply_level(level) if t == "forge" else gem_level(level), boss))
	drop.on_picked = func(item): message.emit("%s ! Rangé dans le menu Coffres (jamais perdu)" % item.name, 2.5)
	add_child(drop)
	var p := pos + Vector3(randf_range(-1.5, 1.5), 0, randf_range(-1.5, 1.5))
	var g: Vector3 = map.ground_at(p.x, p.z)
	drop.global_position = (g if g != Vector3.INF else pos) + Vector3.UP * 0.2


## Chances qu'un monstre ou une élite lâche une potion (voir Potions).
const POTION_MONSTER := 0.03
const POTION_ELITE := 0.3
const BREAK_POTION := 0.03


func _drop_potion(pos: Vector3, kind: String) -> void:
	var drop := LootDrop.new()
	drop.item = Craft.loot_item(Potions.key(kind))
	drop.on_picked = func(item): message.emit("%s ! (%s pour boire)" % [item.name, Settings.action_label("potion_1" if kind == "heal" else "potion_2", 1)], 2.0)
	add_child(drop)
	var p := pos + Vector3(randf_range(-1.5, 1.5), 0, randf_range(-1.5, 1.5))
	var g: Vector3 = map.ground_at(p.x, p.z)
	drop.global_position = (g if g != Vector3.INF else pos) + Vector3.UP * 0.2


func _drop_consumable(pos: Vector3, level: int, bonus: int, source := "") -> void:
	var drop := LootDrop.new()
	drop.item = Craft.loot_item(Craft.loot_for(source, supply_level(level), bonus, gem_level(level)))
	drop.on_picked = func(item): message.emit("Butin : %s" % item.name, 1.5)
	add_child(drop)
	var p := pos + Vector3(randf_range(-1.5, 1.5), 0, randf_range(-1.5, 1.5))
	var g: Vector3 = map.ground_at(p.x, p.z)
	drop.global_position = (g if g != Vector3.INF else pos) + Vector3.UP * 0.2


func _clear_monsters() -> void:
	for node in get_tree().get_nodes_in_group("monsters"):
		node.remove_from_group("monsters")
		node.queue_free()


# --- boss -----------------------------------------------------------------------------
func _enter_arena() -> void:
	print("[run] entrée dans l'arène à %.0f s, niveau %d" % [time, player.level])
	state = "boss"
	if orbs:
		orbs.collect_all_now()  # orbes restées dehors : gagnées en entrant
	_clear_monsters()
	map = world.new_arena_map(_seed)
	_place_player(map.start)
	player.heal(player.max_hp)
	world.set_dungeon_mood(true)
	player.set_torch(true)
	route = PackedVector3Array()
	var boss_id := int(zone.dungeon.boss)
	var c := Vector3(map.size * 0.5, 0, map.size * 0.5)
	c.y = map.height_at(c.x, c.z)
	_boss = _spawn_monster(boss_id, c, mini(maxi(player.level + 1, _monster_level(2)), max_level() + RAGE_LEVEL_BONUS), true)
	_boss.display_name = "<Boss> " + _boss.display_name
	_boss_time = 0.0
	_boss_rage = 0
	if Run.survival:
		# PV fixes par carte et par époque (passe P11) ; la Menace s'y applique ensuite (Menace.apply, en différé)
		_boss.max_hp = Epochs.boss_hp(Run.epoch, Run.stage) * float(Modifiers.apply("mob_hp", 1.0, ModeRules.modifiers)) \
			* (1.0 + Epochs.HEROIC_HP * Run.heroic_rank)
		_boss.hp = _boss.max_hp
	if sv:
		sv.setup_boss(_boss)  # Survivant : PV fixes du boss final, palier (S4)
	var dungeon: Dictionary = zone.get("dungeon", {})
	if _boss.brain:
		_boss.brain.announce.connect(func(t): message.emit(t, 2.5))
		_boss.brain.setup(dungeon, self)
	# dangers permanents de la salle (lave, poison, givre...)
	for hz in map.arena_hazards:
		Hazard.spawn(self, hz.pos, {"style": hz.style, "radius": hz.radius, "lifetime": 0.0, "dps": _boss.atk * 0.3, "source": _boss})
	if String(dungeon.get("intro", "")) != "":
		message.emit(String(dungeon.intro), 4.0)
	if _boss.brain:
		_boss.brain.enraged_phase.connect(func(): message.emit("%s entre en fureur !" % _boss.display_name, 2.5))
		_boss.reflect_started.connect(func(): message.emit("Miroir ! Ne frappe pas pendant 3 s", 2.0))
	message.emit("BOSS : %s" % _boss.display_name.trim_prefix("<Boss> "), 3.5)  # le conseil d'esquive est dans le panneau d'objectifs


func _update_boss(delta: float) -> void:
	if not is_instance_valid(_boss) or _boss.is_dead:
		return
	_boss_time += delta
	if Run.survival and boss_rage_tier() != _boss_rage:
		_raise_boss_rage(boss_rage_tier())
	_adds_timer -= delta
	if _adds_timer <= 0.0:
		_adds_timer = BOSS_ADDS_EVERY
		var lvl := maxi(1, _boss.level - 2)
		for i in 4:
			var a := TAU * i / 4.0 + randf()
			var p := _boss.global_position + Vector3(cos(a), 0, sin(a)) * 8.0
			var m := _spawn_monster(_pick_monster(lvl), _around(p, 2.0), lvl)


## Rage du boss de la Survie (passe P11) : temps passé dans l'arène et palier atteint (0 avant Epochs.BOSS_RAGE_AT).
var _boss_time := 0.0
var _boss_rage := 0


## Palier de la rage du boss (0 avant son début, puis 1 à RAGE_TIERS.size(), un de plus par minute) ; Survie seulement.
func boss_rage_tier() -> int:
	if state != "boss" or not Run.survival:
		return 0
	var at := _boss_rage_start()
	if _boss_time < at:
		return 0
	return clampi(int((_boss_time - at) / RAGE_STEP) + 1, 1, RAGE_TIERS.size())


## Secondes avant le palier suivant de la rage du boss (avant son début : avant le palier 1 ; -1 au dernier).
func boss_rage_next_in() -> float:
	var tier := boss_rage_tier()
	if tier >= RAGE_TIERS.size():
		return -1.0
	return maxf(0.0, _boss_rage_start() + RAGE_STEP * tier - _boss_time)


## Début de la rage du boss (s dans l'arène) : celui de la carte (Survie), ou celui du Survivant.
func _boss_rage_start() -> float:
	if sv and sv.boss_rage_at() >= 0.0:
		return sv.boss_rage_at()
	return Epochs.boss_rage_at(Run.stage)


## Dégâts du boss au palier [param tier] de sa rage (ses PV ne changent pas : on ne peut plus le finir à temps).
func _raise_boss_rage(tier: int) -> void:
	var k := rage_mult(tier) / rage_mult(_boss_rage)
	_boss_rage = tier
	_boss.atk *= k
	match tier:
		1:
			message.emit("LE BOSS ENTRE EN RAGE !\nAchève-le vite : ses coups montent chaque minute", 3.5)
		2:
			message.emit("LA RAGE DU BOSS MONTE !\nSes coups sont deux fois plus forts", 3.0)
		3:
			message.emit("LE BOSS SE DÉCHAÎNE !\nSes coups sont onze fois plus forts", 3.0)


## Ligne d'horloge du combat de boss : « Rage du boss dans 1:42 », puis « RAGE ×2 · 0:42 ».
func boss_rage_text() -> String:
	var tier := boss_rage_tier()
	var left := boss_rage_next_in()
	if tier == 0:
		return "Rage du boss dans %d:%02d" % [int(left) / 60, int(left) % 60]
	var txt := "RAGE ×%s" % fmt_mult(rage_mult(tier))
	if left >= 0.0:
		txt += " · %d:%02d" % [int(left) / 60, int(left) % 60]
	return txt


## Extraction : 10 s à survivre (une vague fonce sur le héros), puis on garde tout.
func start_extraction() -> void:
	if Tower.active or Duel.active or Royale.active or sv:
		return  # la Tour : on monte ou on tombe (Survivant : pas d'extraction, le boss arrive à 20:00)
	if extracting or state == "cleared" or player == null or player.is_dead:
		return
	extracting = true
	extract_left = EXTRACT_TIME
	_extract_tick = 0.0
	print("[run] extraction lancée à %d s" % int(time))
	message.emit("EXTRACTION dans %d s — survis !" % int(EXTRACT_TIME), 2.0)
	# les monstres sentent la fuite : encerclement immédiat
	var lvl := _monster_level(1)
	if state != "boss" and not _roster.is_empty():
		for i in 12:
			var a := TAU * i / 12.0
			var p := player.global_position + Vector3(cos(a), 0, sin(a)) * 16.0
			var g: Vector3 = map.ground_at(p.x, p.z)
			if g != Vector3.INF:
				_spawn_monster(_pick_monster(lvl), g, lvl)


func _update_extraction(delta: float) -> void:
	if not extracting:
		return
	if player.is_dead:
		extracting = false
		print("[run] extraction interrompue (mort)")
		message.emit("Extraction interrompue", 1.5)
		return
	extract_left -= delta
	_extract_tick -= delta
	if _extract_tick <= 0.0:
		_extract_tick = 0.5
		Vfx.ring(player, player.global_position, 2.5 + (EXTRACT_TIME - extract_left) * 0.25, Color(0.45, 0.85, 1.0, 0.9))
		if absf(extract_left - roundf(extract_left)) < 0.26 and extract_left > 0.3:
			message.emit("EXTRACTION : %d" % roundi(extract_left), 0.9)
	if extract_left <= 0.0:
		print("[run] extraction réussie à %d s" % int(time))
		extracting = false
		Vfx.shockwave(player, player.global_position, 5.0, Color(0.5, 0.9, 1.0))
		extracted.emit()


func _on_boss_killed() -> void:
	if sv and sv.on_boss_killed():
		return  # Survivant : une seule carte, rien n'ouvre de zone ni d'époque
	Tutorial.event("boss")
	if Run.survival:
		Profile.records["boss_" + String(zone.get("id", ""))] = 1  # ouvre le donjon de cette zone
	print("[run] boss vaincu à %.0f s, niveau %d, étape %d/%d" % [time, player.level, Run.stage, STAGES])
	state = "cleared"
	if Run.survival:
		give_look_chest()
		# une amélioration d'arme garantie à chaque boss de carte
		world._offer("Boss vaincu ! Améliore ton arme", Run.roll_cards(3, false, "weapon"))
	var next := next_zone_id()
	if next != "":
		# les zones jusqu'à celle de l'étape suivante s'ouvrent aussi pour les prochaines runs
		var target := GameData.zone_index(next)
		while Profile.unlocked_zones <= target:
			var opened := Profile.unlock_after(String(GameData.zones[Profile.unlocked_zones - 1].id))
			if opened == "":
				break
			Run.unlocked_name = opened
		message.emit("Boss vaincu ! Ramasse le butin,\npuis prends le portail vers %s (étape %d/%d)" % [GameData.zone(next).get("name", next), Run.stage + 1, STAGES], 4.5)
		_spawn_stage_portal(next)
		return
	if Run.survival:
		var opened := Epochs.clear(Run.epoch)
		Run.unlocked_epoch = opened
		message.emit("%s terminée !%s" % [Epochs.get_def(Run.epoch).name, ("\n%s débloquée" % opened) if opened != "" else ""], 4.5)
	else:
		message.emit("Boss vaincu !\nRamasse le butin", 3.0)
	await get_tree().create_timer(6.0, false).timeout  # en pause pendant un choix de carte (sinon le bilan le recouvrait)
	boss_defeated.emit()


## Survie, boss vaincu : un coffre d'apparence (menu Coffres, jamais perdu), d'autant plus rare
## que l'époque est avancée (+1 au boss de la 3e map, 1 chance sur 5 d'une qualité de plus).
func give_look_chest() -> void:
	var tier := Run.epoch - 1 + (1 if Run.stage >= STAGES else 0) + (1 if randf() < 0.2 else 0)
	var c := Rewards.make(Rewards.look_type(tier), max_level(), true)
	Profile.reward_chests.append(c)
	Profile.save_profile()
	message.emit("%s ! (menu Coffres)" % Rewards.TYPES[c.type].name, 3.0)


## Zone de l'étape suivante ("" : dernière étape, ou plus de zone après celle-ci) : au moins la
## zone suivante, et plus loin si le héros a déjà dépassé son début (sinon monstres et butin,
## plafonnés au niveau de la zone, seraient sous le sien).
func next_zone_id() -> String:
	if Run.stage >= STAGES or sv:
		return ""  # (le Survivant se joue sur une seule carte)
	if Run.survival:
		return Epochs.zone(Run.epoch, Run.stage + 1)
	var cur := GameData.zone_index(String(zone.get("id", "")))
	if cur < 0 or cur + 1 >= GameData.zones.size():
		return ""
	var best := cur + 1
	for i in range(cur + 1, GameData.zones.size()):
		if GameData.zone_run_levels(i).x <= (player.level if player else 1) - 3:
			best = i
	return String(GameData.zones[best].id)


func _emit_zone() -> void:
	var title := String(zone.get("name", ""))
	if not Training.active and not Tower.active and not Duel.active and sv == null:
		title = "%s · étape %d/%d" % [title, Run.stage, STAGES]
	zone_changed.emit({"name": title, "levels": [1 + int(zone.get("level_bonus", 0)), max_level()]})


## Portail vers l'étape suivante, dans la salle du boss.
func _spawn_stage_portal(next: String) -> void:
	Tutorial.event("portal")
	var portal := Interactable.new()
	portal.setup("stage_portal", "Portail : %s" % GameData.zone(next).get("name", next), "res://assets/maps/objects/ub105.glb", "", 0.4, 5.0)
	portal.set_meta("zone", next)
	map.add_child(portal)
	var c := Vector3(map.size * 0.5, 0, map.size * 0.5) + Vector3(0, 0, -6.0)
	portal.global_position = ground_point(c, map.start)
	portal.add_beam(Color(0.55, 0.85, 1.0), 20.0)
	map.interactables.append(portal)


## Étape suivante : nouvelle carte de la zone suivante, minuterie et sceaux remis à zéro ; le
## héros garde tout (niveau, cartes, équipement, or, clés). Le butin resté au sol est ramassé.
func _next_stage(next: String) -> void:
	if orbs:
		orbs.collect_all_now()
	for d in get_tree().get_nodes_in_group("loot"):
		if Run.pick_up((d as LootDrop).item):
			d.queue_free()
	_clear_monsters()
	RunJournal.end_map("etape")
	Run.stage += 1
	Run.zone_id = next
	zone = GameData.zone(next)
	_roster = zone.monsters.map(func(x): return int(x))
	_elites = zone.get("elites", []).map(func(x): return int(x))
	state = "explore"
	time = 0.0
	seals = 0
	dungeon_found = false
	chests_opened = 0
	shrines_captured = 0
	greed = false
	extracting = false
	_farm.clear()
	_found.clear()
	_challenges.clear()
	_camp_ready_at.clear()
	_wave_timer = 60.0
	_elite_timer = 25.0
	_boss = null
	_near = null
	route = PackedVector3Array()
	world.set_dungeon_mood(false)
	world._apply_biome_env()
	player.set_torch(false)
	_seed = randi()
	map = world.new_run_map(_seed)
	_place_player(map.start)
	if map.breakables:
		map.breakables.broken.connect(_on_broken)
	_fog.fill(Color(0, 0, 0, 1))
	_fog_tex.update(_fog)
	player.heal(player.max_hp)
	_emit_zone()
	_refresh_chest_labels()
	print("[run] étape %d : %s" % [Run.stage, zone.name])
	message.emit("Étape %d/%d : %s\nLes monstres sont plus forts, le butin aussi" % [Run.stage, STAGES, zone.name], 4.0)


# --- divers ----------------------------------------------------------------------------
func revive_point() -> Vector3:
	if state in ["boss", "cleared"]:
		return map.start + Vector3.UP * 0.6
	return map.start + Vector3.UP * 0.6


## Lieux que le déplacement automatique utilise tout seul (la cupidité et le défi restent un
## choix du joueur).
const AUTO_STATIONS := ["anvil", "scribe", "magnet", "well"]
var _farm_at := 0.0
var _farm_cache := Vector3.INF


## Cible de farm du déplacement automatique et du bot de test : coffre qu'on peut ouvrir, lieu
## utile pas encore utilisé, sinon l'objet à casser le plus proche. Vector3.INF : rien.
func farm_target() -> Vector3:
	if state == "royale" and royale != null:
		return royale.farm_target()
	if not state in ["explore", "rage"] or map == null or player == null:
		return Vector3.INF
	if time < _farm_at:
		return _farm_cache
	_farm_at = time + 0.5
	var p := player.global_position
	var best := Vector3.INF
	var bd := 75.0
	for it in map.interactables:
		if not is_instance_valid(it) or it.used:
			continue
		var ok := false
		if it.kind == "chest":
			ok = Profile.keys > 0 or Profile.gold >= chest_price(int(it.get_meta("tier", 0)))
		elif it.kind in AUTO_STATIONS:
			ok = it.kind != "well" or player.hp < player.max_hp * 0.7
		if ok:
			var d := _flat(p, it.global_position)
			if d < bd:
				bd = d
				best = it.global_position
	if best == Vector3.INF and map.breakables:
		best = map.breakables.nearest(p, 45.0)
	_farm_cache = best
	return best


func objective_target() -> Vector3:
	if state == "tower":
		return tower.target()
	if state in ["explore", "rage"] and dungeon_found:
		for p in route:
			if _flat(p, player.global_position) > 4.0:
				return p
		return map.dungeon
	return Vector3.INF


func _update_route(delta: float) -> void:
	_route_timer -= delta
	if _route_timer > 0.0:
		return
	_route_timer = 0.5
	var show: bool = state in ["explore", "rage"] and dungeon_found
	if not show:
		route = PackedVector3Array()
		if _trail and is_instance_valid(_trail):
			_trail.visible = false
		player.autoplay_target = map.dungeon if player.autoplay and state != "boss" and time > _autoplay_dungeon_time() else Vector3.INF
		return
	route = map.path_between(player.global_position, map.dungeon)
	player.autoplay_target = objective_target() if player.autoplay and time > _autoplay_dungeon_time() else Vector3.INF
	_draw_trail()


## Bot de test : va au donjon après un temps de farm (option --boss-after=N).
func _autoplay_dungeon_time() -> float:
	return world.autoplay_boss_after


func _draw_trail() -> void:
	if _trail == null or not is_instance_valid(_trail):
		_trail = MultiMeshInstance3D.new()
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		var orb := SphereMesh.new()
		orb.radius = 0.2
		orb.height = 0.4
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = Color(1.0, 0.85, 0.4)
		orb.material = mat
		mm.mesh = orb
		_trail.multimesh = mm
		_trail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		map.add_child(_trail)
	var points: Array[Vector3] = []
	var acc := 0.0
	for i in range(1, route.size()):
		var a := route[i - 1]
		var b := route[i]
		var seg := a.distance_to(b)
		var t := 3.0 - acc
		while t < seg and points.size() < 12:
			points.append(a.lerp(b, t / seg) + Vector3.UP * 0.4)
			t += 3.0
		acc = seg - (t - 3.0)
		if points.size() >= 12:
			break
	_trail.multimesh.instance_count = points.size()
	for i in points.size():
		_trail.multimesh.set_instance_transform(i, Transform3D(Basis(), points[i]))
	_trail.visible = true


## Brouillard de la mini-carte : révélé autour du héros.
func _update_fog(delta: float) -> void:
	_fog_timer -= delta
	if _fog_timer > 0.0 or state in ["boss", "cleared"]:
		return
	_fog_timer = 0.25
	var k: float = FOG_RES / map.size
	var c := Vector2(player.global_position.x, player.global_position.z) * k
	var r := 48.0 * k
	var changed := false
	for y in range(maxi(0, int(c.y - r)), mini(FOG_RES, int(c.y + r) + 1)):
		for x in range(maxi(0, int(c.x - r)), mini(FOG_RES, int(c.x + r) + 1)):
			var d := Vector2(x, y).distance_to(c) / r
			if d < 1.0:
				var a := _fog.get_pixel(x, y).a
				var na := minf(a, smoothstep(0.7, 1.0, d))
				if na < a:
					_fog.set_pixel(x, y, Color(0, 0, 0, na))
					changed = true
	if changed:
		_fog_tex.update(_fog)


func fog_texture() -> Texture2D:
	return null if state in ["boss", "cleared"] else _fog_tex


# --- objets cassables, coffres d'équipement, lieux utilisables ------------------------------
func _update_breakables(delta: float) -> void:
	if Run.anvil_result != "":
		message.emit("Enclume : %s" % Run.anvil_result, 2.5)
		Run.anvil_result = ""
	_gold_pop_timer -= delta
	if _gold_pop > 0 and _gold_pop_timer <= 0.0:
		DamageNumber.spawn_text(player, "+%d or" % _gold_pop, Color(1.0, 0.85, 0.3))
		Sfx.ui("gold", -10.0)
		_gold_pop = 0
		_gold_pop_timer = 0.5
	_touch_timer -= delta
	if _touch_timer > 0.0 or map.breakables == null or player.is_dead:
		return
	_touch_timer = 0.08
	map.breakables.touch(player.global_position)


## Objet cassé : or, un peu d'expérience, parfois des soins, une fourniture ou une clé ;
## cristal : des gemmes.
func _on_broken(kind: String, pos: Vector3) -> void:
	var lv := player.level
	Profile.record_add("breakables", 1)
	if kind == "gem" and sv == null:  # (Survivant : le cristal ne donne ni gemme ni fourniture)
		for i in randi_range(1, 2):
			var tier := clampi(gem_level(lv) / 8 + randi_range(0, 1), 0, Craft.GEM_TIERS.size() - 1)
			_drop_loot(pos, Craft.loot_item(Craft.gem_key(Craft.GEMS.keys().pick_random(), tier)))
		message.emit("Cristal brisé : des gemmes !", 1.5)
		return
	var g: Array = BREAK_GOLD.get(kind, [1, 2])
	var gold := roundi(randi_range(int(g[0]), int(g[1])) * (1.0 + lv * 0.2) * (GREED_GOLD if greed else 1.0))
	if gold > 0:
		Run.add_gold(gold, "objets")
		_gold_pop += gold  # affiché en un seul « +N or » (voir _update_breakables)
	if kind == "gold":
		return
	if orbs:
		orbs.spawn(pos, 1.0 + lv * 0.5)
	if randf() < BREAK_POTION * (GREED_GOLD if greed else 1.0):
		_drop_potion(pos, Potions.roll_kind())
	if randf() < BREAK_HEAL and player.hp < player.max_hp:
		player.heal(player.max_hp * 0.1)
		DamageNumber.spawn_text(player, "+PV", Color(0.5, 1.0, 0.55))
	if sv == null and randf() < float(BREAK_SUPPLY.get(kind, 0.0)) * (GREED_GOLD if greed else 1.0):
		_drop_consumable(pos, _monster_level(0), 0, kind)
	if randf() < BREAK_KEY:
		Profile.keys += 1
		Profile.changed.emit()
		message.emit("Une clé dans les débris ! (%d)" % Profile.keys, 1.8)


func _drop_loot(pos: Vector3, item: Dictionary) -> void:
	var drop := LootDrop.new()
	drop.item = item
	drop.on_picked = func(it): message.emit("Butin : %s" % it.name, 1.5)
	add_child(drop)
	var p := pos + Vector3(randf_range(-1.2, 1.2), 0, randf_range(-1.2, 1.2))
	var gr: Vector3 = map.ground_at(p.x, p.z)
	drop.global_position = (gr if gr != Vector3.INF else pos) + Vector3.UP * 0.2


## Choix d'équipement d'un coffre de la carte de qualité [param tier].
func gear_cards(n: int, tier: int) -> Array:
	var def: Dictionary = CHEST_TIERS[clampi(tier, 0, CHEST_TIERS.size() - 1)]
	var out: Array = []
	for i in n:
		var it := Items.generate(loot_level(player.level + 1), float(def.luck), "", Run.class_id, int(def.min_r), "", int(def.max_r))
		out.append(item_card(it, "gear"))
	return out


## Survie : arme de départ, du type de la classe (l'arme principale est fixée par la classe),
## au palier de la 1re map : ses deux variantes au choix.
func start_weapon_cards() -> Array:
	var items := SlotChests.offer("weapon", Run.epoch, Run.stage, 2)
	if items.is_empty():
		items = [Items.generate(loot_level(1), 0.0, "weapon", Run.class_id, 0, Run.weapon_type(), 0)]
	while items.size() < 2:
		var copy: Dictionary = items[0].duplicate(true)
		copy["uid"] = "%s_v" % String(copy.uid)
		items.append(copy)
	var out: Array = []
	for i in 2:
		items[i]["auto_variant"] = i
		out.append(weapon_card(items[i], "gear"))
	return out


## Carte d'une arme : sa variante d'auto-attaque d'abord, puis ses statistiques.
static func weapon_card(it: Dictionary, type: String) -> Dictionary:
	var c := item_card(it, type)
	var s := WeaponAttacks.spec_for(it)
	c["subtitle"] = "%s · %s" % [WeaponAttacks.variant_label(it), Items.RARITIES[clampi(int(it.get("rarity", 0)), 0, Items.RARITIES.size() - 1)].name]
	var head := "[color=#ffcf6b][b]%s[/b][/color] : %s" % [s.name, s.desc]
	if s.has("sig"):
		head += "\n[color=#ffb347]★ %s[/color]" % WeaponAttacks.sig_text(s)
	var lines := String(c.desc).split("\n")
	if type == "offhand":
		var cur: Dictionary = Profile.equipped.get("offhand", {})
		lines[0] = "[color=#7dff8a]Emplacement libre[/color]" if cur.is_empty() else "Remplace : %s" % WeaponAttacks.variant_label(cur)
		head += "\n[color=#9a98a8]Arme secondaire : frappe seule, %d %% des dégâts et %d %% de ses stats.[/color]" % [
			roundi(WeaponAttacks.OFFHAND_DMG * 100.0), roundi(WeaponAttacks.OFFHAND_STATS * 100.0)]
	c["desc"] = head + "\n" + "\n".join(lines.slice(0, 4))
	return c


## Survie : arme secondaire lâchée par une élite ou un boss ; ramassée, elle propose 3 armes
## d'autres types que la classe (une relance).
func _drop_offhand(pos: Vector3) -> void:
	var drop := LootDrop.new()
	var m := Epochs.map_def(Run.epoch, Run.stage)
	var wt := GameData.weapon_type(["bow", "staff", "axe", "spear", "cannon"].pick_random())
	var ws: Array = wt.get("weapons", [])
	drop.item = {"offhand_drop": true, "name": "Arme secondaire", "rarity": int(m.rarity),
		"icon": String(ws[0].icon) if not ws.is_empty() else ""}
	drop.on_picked = func(_item):
		var roll := func(): return SlotChests.offhand_offer(Run.epoch, Run.stage).map(func(it): return weapon_card(it, "offhand"))
		world._offer("Arme secondaire trouvée : choisis-en une", roll.call(), roll, 1)
	add_child(drop)
	var g: Vector3 = map.ground_at(pos.x, pos.z)
	drop.global_position = (g if g != Vector3.INF else pos) + Vector3.UP * 0.2


## Survie : coffre d'emplacement ouvert, 3 pièces (ou cartes) au choix, une relance par coffre.
func _open_slot_chest(box: String) -> void:
	if sv and sv.open_chest(box):
		return  # Survivant : coffres du Survivant (S4)
	var title := SlotChests.title(box)
	if SlotChests.is_cards(box):
		var kind := String(SlotChests.BOXES[box].cards)
		var cards := Run.roll_cards(3, false, kind)
		if cards.is_empty():
			cards = Run.roll_cards(3)  # plus rien de ce type : des cartes au choix
		world._offer("%s : choisis une carte" % title, cards, func(): return Run.roll_cards(3, false, kind), 1)
		return
	if box == "trophy":
		if Run.trophies.size() >= Run.MAX_TROPHIES:
			world._offer("Collection de trophées complète (%d) : choisis une carte" % Run.MAX_TROPHIES, Run.roll_cards(3), func(): return Run.roll_cards(3), 1)
		else:
			world._offer("%s (%d / %d trophées) : choisis-en un" % [title, Run.trophies.size(), Run.MAX_TROPHIES], trophy_cards(3), func(): return trophy_cards(3), 1)
		return
	var gear := SlotChests.offer(box, Run.epoch, Run.stage).map(func(it): return weapon_card(it, "gear") if it.slot == "weapon" else item_card(it, "gear"))
	world._offer("%s (%s) : choisis une pièce" % [title, Epochs.map_text(Run.epoch, Run.stage)], gear,
		func(): return SlotChests.offer(box, Run.epoch, Run.stage).map(func(it): return weapon_card(it, "gear") if it.slot == "weapon" else item_card(it, "gear")), 1)


## Enclume : emplacements montrés à la fois (le choix en montre 3, comme un coffre ; la relance passe aux suivants).
const ANVIL_PAGE := 3


## Survie : enclume, un emplacement au choix (sa pièce actuelle, son bonus actuel), les 9 emplacements
## rangés du plus utile au moins utile : pièce portée d'abord, puis le +N total le plus bas, l'arme en tête.
func anvil_slot_cards() -> Array:
	var slots: Array = Run.ANVIL_SLOTS.duplicate()
	var key := func(s: String) -> int:
		var it: Dictionary = Profile.equipped.get(s, {})
		return (0 if not it.is_empty() else 1000) + 10 * Run.slot_upgrade(int(it.get("upgrade", 0)), s) + (0 if s == "weapon" else 1)
	slots.sort_custom(func(a, b): return key.call(a) < key.call(b) or (key.call(a) == key.call(b) and Run.ANVIL_SLOTS.find(a) < Run.ANVIL_SLOTS.find(b)))
	var out: Array = []
	for slot in slots:
		var it: Dictionary = Profile.equipped.get(slot, {})
		var cur := int(Run.slot_bonus.get(slot, 0))
		var up := int(it.get("upgrade", 0))
		out.append({"type": "anvil_slot", "id": slot, "slot": slot, "title": String(Items.SLOT_NAMES.get(slot, slot)),
			"subtitle": ("Bonus actuel +%d (remplacé) · total +%d" % [cur, Run.slot_upgrade(up, slot)]) if Run.slot_bonus.has(slot) else "Pièce à +%d, sans bonus de run" % up,
			"desc": (Items.display_name(it) if not it.is_empty() else "Vide : le bonus s'appliquera à la pièce que tu y mettras") \
				+ "\nTirage de +0 à +7 (le plus souvent +2 à +4), ajouté au +N de la pièce (total +%d au plus)" % Run.UPGRADE_CAP,
			"icon": String(it.get("icon", "")) if not it.is_empty() else "",
			"color": Items.color_of(it) if not it.is_empty() else Color(0.75, 0.7, 0.6)})
	return out


## Carte de choix pour l'objet [param it] : stats, set, passif, comparaison avec la pièce portée.
static func item_card(it: Dictionary, type: String) -> Dictionary:
	var lines: PackedStringArray = []
	var st := Items.stats(it)
	for k in st:
		if lines.size() >= 6:
			break
		if absf(float(st[k])) > 0.0001:
			lines.append(Items.stat_text(String(k), st[k]))
	if it.has("set"):
		lines.append("[color=#66f28c]Set : %s[/color]" % String(Items.set_def(String(it.set)).get("name", it.set)))
	var pv: Dictionary = it.get("passive", {})
	if String(pv.get("desc", "")) != "":
		lines.append("[color=#ffd36b]%s[/color]" % pv.desc)
	var cmp := Items.compare_to_equipped(it)
	if it.slot == "trophy":
		# trophée : collection de la run (12 au plus, effets différents), effet actif tout de suite
		var head := "[color=#7dff8a]S'ajoute à ta collection (%d → %d / %d) : effet actif tout de suite[/color]" % [
			Run.trophies.size(), Run.trophies.size() + 1, Run.MAX_TROPHIES]
		return {"type": "trophy", "id": String(it.get("uid", "")), "item": it, "title": Items.display_name(it),
			"subtitle": "Trophée · %s · niv. %d" % [String(it.get("passive", {}).get("name", "")), int(it.get("level", 0))],
			"desc": head + "\n[color=#ffd36b]%s[/color]" % String(it.get("passive", {}).get("desc", "")), "icon": String(it.get("icon", "")), "color": Items.color_of(it)}
	var cmp_txt := "[color=#7dff8a]Emplacement libre[/color]" if cmp >= 1.0 else ("[color=#7dff8a]▲ +%d %%[/color] sur ta pièce" % roundi(cmp * 100.0)
		if cmp > 0.005 else ("[color=#ff8a7d]▼ %d %%[/color] sur ta pièce" % roundi(cmp * 100.0) if cmp < -0.005 else "Comme ta pièce"))
	var r := clampi(int(it.get("rarity", 0)), 0, Items.RARITIES.size() - 1)
	return {"type": type, "id": String(it.get("uid", "")), "item": it, "title": Items.display_name(it),
		"subtitle": "%s · %s · niv. %d" % [String(GameData.weapon_type(Items.weapon_type_of(it)).get("name", "Arme")) if it.slot == "weapon" else Items.SLOT_NAMES.get(it.slot, it.slot),
			Items.RARITIES[r].name, int(it.get("level", 0))],
		"desc": cmp_txt + "\n" + "\n".join(lines), "icon": String(it.get("icon", "")), "color": Items.color_of(it)}


## Enclume : l'arme et les 3 pièces portées les moins améliorées (pas au maximum).
func anvil_cards() -> Array:
	var pieces: Array = []
	for slot in Profile.equipped:
		var it: Dictionary = Profile.equipped[slot]
		if slot != "offhand" and not Items.is_unique(it) and int(it.get("upgrade", 0)) < Items.MAX_UPGRADE:
			pieces.append(it)
	pieces.sort_custom(func(a, b): return (a.slot == "weapon" and b.slot != "weapon") or (a.slot == b.slot) or \
		((a.slot == "weapon") == (b.slot == "weapon") and int(a.get("upgrade", 0)) < int(b.get("upgrade", 0))))
	var out: Array = []
	for it: Dictionary in pieces.slice(0, 4):
		var up := int(it.get("upgrade", 0))
		var c := item_card(it, "anvil")
		c["slot"] = String(it.slot)
		c["subtitle"] = "%s · +%d → +%d" % [Items.SLOT_NAMES.get(it.slot, it.slot), up, up + 1]
		c["desc"] = ("[color=#7dff8a]Palier +%d : stat bonus en plus[/color]\n" % (up + 1) if (up + 1) in Items.MILESTONES else "Stats de l'objet +10 %\n") + \
			"\n".join(String(c.desc).split("\n").slice(1))
		out.append(c)
	return out


## Autel du scribe : parchemins d'enchantement du niveau de la carte (Survie : de ses pièces, plafonnés par époque :
## Craft.SURVIVAL_SCROLL_MAX), au choix.
func scroll_cards(n: int) -> Array:
	var slv := maxi(1, Craft.loot_scroll_level(supply_level(player.level + 2)))
	var types: Array = Craft.ENCHANTS.keys()
	types.shuffle()
	var out: Array = []
	for t in types.slice(0, n):
		var key := Craft.scroll_key(String(t), slv)
		out.append({"type": "scroll", "id": key, "key": key, "title": Craft.label(key), "subtitle": "Parchemin d'enchantement",
			"desc": Craft.describe_key(key), "icon": Craft.icon(key), "color": Color(0.6, 0.75, 1.0)})
	return out


func _use_station(it: Interactable) -> void:
	Sfx.event_at(self, it.global_position, "station", -4.0)
	if sv and sv.use_station(it):
		return  # Survivant : enclume +2, stèle (S4)
	match it.kind:
		"anvil" when Run.survival:
			if Run.anvil_stage == Run.stage:
				message.emit("L'enclume a déjà servi sur cette carte (une fois par carte)", 2.5)
				return
			for a in map.interactables:
				if is_instance_valid(a) and a.kind == "anvil":
					a.use_up()  # une seule enclume par carte
			# 3 emplacements à la fois (les plus utiles d'abord) ; la relance montre les suivants, en boucle
			var all := anvil_slot_cards()
			var pages := ceili(all.size() / float(ANVIL_PAGE))
			var page := [0]
			var next := func() -> Array:
				page[0] = (page[0] + 1) % pages
				return all.slice(page[0] * ANVIL_PAGE, (page[0] + 1) * ANVIL_PAGE)
			world._offer("Enclume : choisis un emplacement", all.slice(0, ANVIL_PAGE), next, 2 * (pages - 1))
		"anvil":
			var cards := anvil_cards()
			if cards.is_empty():
				message.emit("Rien à forger : équipe une pièce (au plus +%d)" % Items.MAX_UPGRADE, 2.5)
				return
			it.use_up()
			world._offer("Enclume : +1 garanti sur une pièce portée", cards)
		"scribe":
			it.use_up()
			world._offer("Autel du scribe : choisis un parchemin d'enchantement", scroll_cards(3))
		"well":
			it.use_up()
			player.heal(player.max_hp)
			Vfx.ring(player, player.global_position, 3.0, Color(0.5, 1.0, 0.7, 0.9))
			message.emit("Fontaine de vie : PV au maximum", 2.0)
		"magnet":
			it.use_up()
			_on_instant_card("recall")
		"greed":
			it.use_up()
			greed = true
			Menace.pact_taken(get_tree(), GREED_MONSTERS)  # les monstres déjà là aussi ; insignes de la carte ×1,5
			world.set_rage_mood(state == "rage")
			message.emit("PACTE DE CUPIDITÉ\nOr, butin et insignes accrus : les monstres se renforcent", 3.5)
		"giant":
			GiantAltar.invoke(self, it)
		"challenge":
			it.use_up()
			_start_challenge(it.global_position)
		"fortune":
			it.use_up()
			var plv := loot_level(_monster_level(2))
			if player.autoplay:
				message.emit("Autel de la fortune : %s" % Fortune.give(1, player.level, plv), 2.5)  # pilote auto : encaisse l'étage 1
			else:
				FortunePopup.open(self, player.level, plv, Callable())


## Défi : une escouade d'élites (et leurs gardes) surgit ; les vaincre donne un coffre de
## récompense (mythiques et légendaires, menu Coffres) et des fournitures.
func _start_challenge(c: Vector3) -> void:
	var lvl := _monster_level(2)
	var elites: Array = []
	for i in 3:
		var a := TAU * i / 3.0
		var p := _around(c + Vector3(cos(a), 0, sin(a)) * 7.0, 2.0)
		var m: Monster = _spawn_monster(_elites.pick_random() if not _elites.is_empty() else _pick_monster(lvl), p, lvl)
		if _elites.is_empty():
			m.max_hp *= 4.0
			m.hp = m.max_hp
		elites.append(m)
	for i in mini(6, _room()):
		_spawn_monster(_pick_monster(lvl), _around(c, 9.0), lvl)
	_challenges.append({"pos": c, "elites": elites})
	message.emit("DÉFI : abats les 3 élites !", 2.5)


func _update_challenges() -> void:
	for ch in _challenges.duplicate():
		if not (ch.elites as Array).all(func(m): return not is_instance_valid(m) or m.is_dead):
			continue
		_challenges.erase(ch)
		_drop_reward_chest(ch.pos, _monster_level(2), false)
		for i in 2:
			_drop_consumable(ch.pos, _monster_level(1), 2, "challenge")
		Run.add_gold(roundi((40 + 12 * player.level) * (GREED_GOLD if greed else 1.0)), "defis")
		message.emit("Défi réussi ! Coffre de récompense et fournitures", 3.0)


## Lieux connus à afficher sur la mini-carte : [position, type].
func markers() -> Array:
	var out: Array = []
	if state == "royale":
		return royale.markers()
	if state in ["boss", "cleared"]:
		return out
	for k in _found:
		if k is String:
			if String(k).begins_with("fort"):
				out.append([_found[k], "fort"])
			continue
		if is_instance_valid(k) and k is Interactable and not k.used:
			out.append([k.global_position, "merchant" if k.kind == "merchant" else k.kind])
		elif is_instance_valid(k) and k is Shrine and not k.captured:
			out.append([k.global_position, "shrine"])
	if dungeon_found:
		out.append([map.dungeon, "dungeon"])
	for it in map.interactables:
		if is_instance_valid(it) and it.kind == "chest" and not it.used and _flat(player.global_position, it.global_position) < DISCOVER_CHEST * 3.0:
			var tier := int(it.get_meta("tier", 0))
			out.append([it.global_position, "chest" if tier == 0 else "chest%d" % tier])
	return out


func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _keep_on_map() -> void:
	var p := player.global_position
	if player.is_on_floor():
		_last_safe = p
	elif p.y < _last_safe.y - 25.0:
		player.global_position = _last_safe + Vector3.UP * 0.5
		player.velocity = Vector3.ZERO
		return
	var b: Rect2 = map.bounds.grow(-3.0)
	var x := clampf(p.x, b.position.x, b.end.x)
	var z := clampf(p.z, b.position.y, b.end.y)
	if x != p.x or z != p.z:
		player.global_position = Vector3(x, p.y, z)


# --- outils de test --------------------------------------------------------------------
func debug_enter_dungeon() -> void:
	if state in ["explore", "rage"]:
		dungeon_found = true
		seals = SEALS_NEEDED
		_enter_arena()


func teleport_to_gateway() -> bool:
	if state in ["boss", "cleared"]:
		return false
	_place_player(map.dungeon + Vector3(3, 0, 3))
	return true


func debug_start_rage() -> void:
	if state == "explore":
		time = RUN_TIME


# --- coffres payants, sanctuaires, marchands ambulants --------------------------------------
## Prix du prochain coffre de la carte de qualité [param tier] (monte à chaque coffre ouvert).
func chest_price(tier := 0, box := "") -> int:
	var mult := float(CHEST_TIERS[clampi(tier, 0, 2)].price) if box == "" else (SurvivorDirector.box_price(box) if SurvivorDirector.BOXES.has(box)
		else float(SlotChests.BOXES.get(box, {}).get("price", 1.0)))
	var base := float(CHEST_BASE + 3 * (player.level if player else 1)) * mult
	return roundi(base * pow(CHEST_GROWTH, mini(chests_opened, 60)))


func _refresh_chest_labels() -> void:
	for it in map.interactables:
		if is_instance_valid(it) and it.kind == "chest" and not it.used:
			var tier := int(it.get_meta("tier", 0))
			var box := String(it.get_meta("box", ""))
			var name := SlotChests.title(box) if box != "" else String(ProcMap.CHEST_LOOKS[tier].title)
			if SurvivorDirector.BOXES.has(box):
				name = SurvivorDirector.box_title(box)  # coffres du Survivant
			it.set_title("%s · %d or ou 1 clé" % [name, chest_price(tier, box)])


## Zones à capturer : rester dans le cercle sous la pression des monstres.
func _update_shrines(delta: float) -> void:
	for sh: Shrine in map.shrines:
		if sh.captured:
			continue
		var before := sh.progress
		if not player.is_dead and sh.contains(player.global_position):
			if before == 0.0:
				message.emit("Capture du sanctuaire : reste dans le cercle !", 2.0)
			sh.progress = minf(1.0, sh.progress + delta / Shrine.CAPTURE_TIME)
			_shrine_timer -= delta
			if _shrine_timer <= 0.0:
				_shrine_timer = SHRINE_PRESSURE
				var lvl := _monster_level(1)
				var c := sh.global_position + Vector3.FORWARD.rotated(Vector3.UP, randf() * TAU) * randf_range(12.0, 16.0)
				for i in 3 + int(time / 120.0):
					_spawn_monster(_pick_monster(lvl), _around(c, 4.0), lvl)
			if sh.progress >= 1.0:
				_capture(sh)
		elif before > 0.0:
			sh.progress = maxf(0.0, sh.progress - delta / (Shrine.CAPTURE_TIME * 3.0))
		if sh.progress != before:
			sh.update_visual()


func _capture(sh: Shrine) -> void:
	sh.captured = true
	shrines_captured += 1
	Tutorial.event("shrine")
	Profile.record_add("shrines", 1)
	sh.update_visual()
	if sv and sv.capture(sh):
		return  # Survivant : récompense du sanctuaire (S4)
	match sh.reward:
		"trophy":
			if Run.trophies.size() < Run.MAX_TROPHIES:
				world._offer("Sanctuaire capturé ! Choisis un trophée (%d / %d)" % [Run.trophies.size(), Run.MAX_TROPHIES], trophy_cards(3))
			else:
				world._offer("Sanctuaire capturé ! Choisis une carte", Run.roll_cards(3), func(): return Run.roll_cards(3))
		"keys":
			Profile.keys += 2
			Run.add_gold(40 + 10 * player.level, "sites")
			Profile.changed.emit()
			message.emit("Sanctuaire capturé : 2 clés et de l'or !", 2.5)
		_:
			world._offer("Sanctuaire capturé ! Choisis une carte", Run.roll_cards(3), func(): return Run.roll_cards(3))


## Cartes de choix de trophée : [param n] effets que la collection n'a pas encore, au niveau
## de la map (le choisi rejoint Run.trophies).
func trophy_cards(n: int) -> Array:
	return SlotChests.trophy_offer(Run.epoch, Run.stage, n).map(func(it): return item_card(it, "trophy"))


## Marchands ambulants : ils se promènent autour de leur place, et s'arrêtent face au héros.
func _update_merchants(delta: float) -> void:
	for node in map.interactables:
		if not is_instance_valid(node) or node.kind != "merchant":
			continue  # (les coffres ouverts disparaissent : pas de type imposé dans la boucle)
		var it: Interactable = node
		var to_player: Vector3 = player.global_position - it.global_position
		to_player.y = 0.0
		if to_player.length() < 7.0:
			it.rotation.y = lerp_angle(it.rotation.y, atan2(to_player.x, to_player.z), minf(1.0, delta * 5.0))
			continue
		var target: Vector3 = it.get_meta("target", it.global_position)
		var to: Vector3 = target - it.global_position
		to.y = 0.0
		if to.length() < 0.5:
			var wait := float(it.get_meta("wait", 0.0)) - delta
			it.set_meta("wait", wait)
			if wait <= 0.0:
				var home: Vector3 = it.get_meta("home", it.global_position)
				var p := home + Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized() * randf_range(3.0, MERCHANT_ROAM)
				it.set_meta("target", ground_point(p, home))
				it.set_meta("wait", randf_range(4.0, 9.0))
			continue
		var step: Vector3 = to.normalized() * minf(1.6 * delta, to.length())
		var np: Vector3 = it.global_position + step
		it.global_position = ground_point(np, np)
		it.rotation.y = lerp_angle(it.rotation.y, atan2(to.x, to.z), minf(1.0, delta * 6.0))


# --- mode dev (écran F10) ----------------------------------------------------------------
func _near_player(d := 7.0) -> Vector3:
	var p := player.global_position + player.forward() * d
	return ground_point(p, player.global_position)


func dev_spawn_elite() -> void:
	if _elites.is_empty():
		return
	var e := _spawn_monster(_elites.pick_random(), _near_player(), _monster_level(1))
	if state in ["explore", "rage"] and seals < SEALS_NEEDED:
		e.carries_seal = true


## Boss de la zone sur le terrain (avec ses mécaniques), sans entrer dans le donjon.
func dev_spawn_boss() -> void:
	var dungeon: Dictionary = zone.get("dungeon", {})
	if not dungeon.has("boss"):
		return
	var b := _spawn_monster(int(dungeon.boss), _near_player(10.0), mini(maxi(player.level + 1, _monster_level(2)), max_level() + RAGE_LEVEL_BONUS), true)
	b.display_name = "<Boss> " + b.display_name
	if b.brain:
		b.brain.announce.connect(func(t): message.emit(t, 2.5))
		b.brain.setup(dungeon, self)


func dev_spawn_chest() -> void:
	var npcs: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/npcs.json"))
	var data: Dictionary = npcs.get("chest", {})
	var chest := Interactable.new()
	chest.setup("chest", "Coffre", "res://assets/monsters/%s/%s.glb" % [data.model, data.model],
		"res://assets/monsters/textures/%s.png" % data.texture, 1.0, 3.0)
	map.add_child(chest)
	chest.global_position = _near_player(4.0)
	map.interactables.append(chest)
	_refresh_chest_labels()


func dev_spawn_merchant() -> void:
	var npcs: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/npcs.json"))
	var data: Dictionary = npcs.get("merchant", {})
	var npc := Interactable.new()
	npc.setup("merchant", "Marchand ambulant", "res://assets/monsters/%s/%s.glb" % [data.model, data.model],
		"res://assets/monsters/textures/%s.png" % data.texture, float(data.get("scale", 1.0)), 4.0)
	map.add_child(npc)
	npc.global_position = _near_player(5.0)
	npc.set_meta("home", npc.global_position)
	map.interactables.append(npc)
	_found[npc] = true


func dev_capture_nearest() -> void:
	var best: Shrine = null
	for sh: Shrine in map.shrines:
		if not sh.captured and (best == null or _flat(player.global_position, sh.global_position) < _flat(player.global_position, best.global_position)):
			best = sh
	if best:
		_capture(best)


func dev_kill_all() -> int:
	var n := 0
	for m in get_tree().get_nodes_in_group("monsters"):
		var mo := m as Monster
		if mo and not mo.is_dead and mo != _boss:
			mo.take_damage(mo.max_hp * 100.0 + 1e6, player)
			n += 1
	return n
