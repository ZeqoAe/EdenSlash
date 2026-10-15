extends Node
## État d'une run : classe, 4 emplacements de compétences, passifs obtenus par
## cartes au passage de niveau, butin et bilan.

signal changed
signal instant_card(id: String)  # carte à effet immédiat (Rappel)

const MAX_SKILLS := 4
const MAX_RANK := 5
const INSIGNIA_BASE := 25  # insignes de participation d'une run de Survie (dès 10 monstres vaincus)
## Passe E6 : monstres comptés pour la maîtrise et les insignes, au plus KILL_CAP_PER_MAP par carte atteinte (une carte
## jouée normalement en compte 700 à 1 000 ; rester en rage sur la 1re carte n'est pas une ferme sans fin).
const KILL_CAP_PER_MAP := 1500

var active := false
var class_id := "samurai"
var skills: Array = []  # [{id, rank}] : sort principal de chaque case (4 au plus)
## Enchaînements : case -> [{id, rank}] (2 au plus) ; en timing parfait, juste après l'impact
## du sort de la case, la même touche lance le sort suivant de la chaîne (12 sorts au total).
var chains: Dictionary = {}
const MAX_CHAIN := 2
var passives: Dictionary = {}  # id -> nombre de cartes prises (niveau du passif)
## Compteur de dégâts cumulés : tous les dégâts infligés s'additionnent sans arrêt ; 3 s sans
## infliger de dégâts et il repart de zéro (record de la run et record absolu).
const COMBO_RESET_MS := 3000
var combo_damage := 0.0
var combo_best := 0.0
var _combo_last := 0
var hero_level := 0  # niveau du héros de la run (puissance des objets : Items.power_level)
var banned: Array = []  # cartes bannies pour la run (ids)
var kept: Array = []  # cartes gardées pour le prochain choix : [{type, id, tier}]
var bans_used := 0
var locks_used := 0
var cards_at_start: Array = []  # cartes débloquées au départ (bilan : nouvelles cartes)
var passive_power: Dictionary = {}  # id -> puissance : somme des multiplicateurs de rareté des cartes prises
var kills := 0
var elites := 0
var loot: Array = []
var gold := 0
var started_at := 0
var resurrections := 0  # résurrections utilisées (étoile « sans résurrection »)
var rage_stages: Array = []  # cartes où la rage a démarré
var offhand_used := false
var anvil_stages: Array = []  # cartes où l'enclume a servi
var heroic_rank := 0  # rang héroïque de la run (0 : normale)
var stars_gained := 0  # étoiles nouvellement gagnées à la fin de la run (bilan)
var heroic_rewards: Array = []  # récompenses du rang héroïque (bilan)
var perfects := 0  # annulations parfaites de la run (contrats de classe)
var chests_total := 0  # coffres de la carte ouverts pendant la run
var contracts_done: Array = []  # contrats terminés à la fin de la run (bilan)
var challenge_first := false  # 1re réussite du Défi de maîtrise du jour (bilan)
var fortune_insignia := 0  # insignes gagnés à l'autel de la fortune (déjà crédités)
var result := ""  # victoire, defaite, abandon
var max_level := 1
var seed := 0  # graine de la map (0 = aléatoire)
var zone_id := "limestone"
var unlocked_name := ""  # zone débloquée par la victoire (ancienne run)
var unlocked_epoch := ""  # Survie : époque débloquée par la victoire (bilan)
var expertise_gain := 0
var expertise_levels := 0
var expertise_catchup := 0  # part de expertise_gain due au rattrapage (Economy.catchup, bilan)
var first_win_bonus := 0  # part de expertise_gain : 1re victoire de la classe à cette époque (bilan)
var shared_gain := {}  # part de l'arbre de classe donnée aux voisines : classe -> points (bilan)
var new_classes: Array = []  # classes débloquées pendant la run (bilan)
var new_costumes: Array = []  # costumes (skins de tenue) débloqués pendant la run
var rerolls_used := 0  # relances de cartes utilisées (1 par run + cartes « Bonne étoile »)
var chests_found: Array = []  # (ancien) coffres ramassés : désormais rangés tout de suite dans Profile.reward_chests
var reward_mark := 0  # nombre de coffres de récompense à l'ouverture de la run (bilan : new_reward_chests)
var stage := 1  # étape de la run (façon Megabonk : boss vaincu → portail vers la zone suivante)
var start_zone := ""  # zone choisie au lobby (première étape)
## Survie (DESIGN.md, « Boucle de jeu et Survie ») : époque de 3 maps, départ avec l'équipement du hub,
## coffres d'emplacement ; false pour la Tour, le Duel, l'entraînement.
var survival := false
## Survivant (Survivor) : vrai de son lancement jusqu'au lancement suivant (le bilan et « Rejouer » le lisent après la
## fin de la run, quand Survivor.active est déjà retombé). Un Survivant garde aussi `survival` (socle de la Survie).
var survivor := false
var epoch := 1
## Pièces choisies dans les coffres de la run (Eden id) : achetables au hub ensuite.
var seen_items: Array = []
## Armes des autres types découvertes avec une arme choisie (SlotChests.weapon_family) : Armurerie aussi.
var seen_family: Array = []
## Enclume de la Survie : emplacement -> bonus tiré (+0 à +7), AJOUTÉ au +N de la pièce portée dans
## cet emplacement (celui du hub), quelle qu'elle soit, jusqu'à la fin de la run ; le total est
## plafonné à UPGRADE_CAP (voir slot_upgrade).
var slot_bonus: Dictionary = {}
## Améliorations d'arme de la run (cartes « weapon_up », WeaponAttacks.roll_upgrade) par
## emplacement ("weapon", "offhand") : {rank, dmg, crit, speed, area, …, sig}. Elles restent sur
## l'emplacement quand l'arme change.
var weapon_ups: Dictionary = {}
## Trophées de la run (0.1.130) : objets d'Eden (Items.from_template, passif « trophy »), tous
## d'effets différents, jusqu'à MAX_TROPHIES ; leurs effets agissent tous (trophy_procs).
const MAX_TROPHIES := 12
var trophies: Array = []
var anvil_stage := 0  # map où l'enclume a servi (une fois par map)
var insignia_gain := 0  # insignes gagnés à la fin de la run (bilan)
## Détail des insignes de la Survie (Economy.survival_insignia_parts : participation, maps, fights, victory), avant Défi,
## rang héroïque et autel de la fortune ; le bilan peut l'afficher tel quel (participation au prorata, monstres plafonnés).
var insignia_parts: Dictionary = {}
## Mesures d'équilibrage seulement (--human=<part de coups évités>) : facteur sur les dégâts subis par le héros.
static var test_taken := 1.0
## Mesures : distance (m) en deçà de laquelle le bot de test combat au lieu de marcher vers son objectif.
static var test_fight_range := 4.0
## Mesures (--rush=<m>, passe P11) : en route vers le boss, le bot suit le chemin du donjon et ne combat qu'en deçà
## de cette distance, comme un joueur qui file au boss (la horde le suit depuis P9) ; < 0 : comme le reste du temps.
static var test_rush_range := -1.0
## Tirage de l'enclume : valeur -> poids (le plus souvent +2 à +4, moyenne ≈ +3,2, rarement +6/+7).
## Elle rattrape surtout les pièces peu améliorées : sur une pièce +10 du hub, le plafond coupe vite.
const ANVIL_ROLLS := {0: 4, 1: 8, 2: 12, 3: 15, 4: 14, 5: 10, 6: 6, 7: 3}
## +N maximal d'une pièce en Survie (+10 du hub + enclume) : ×2,2 sur ses stats de base au plus.
const UPGRADE_CAP := 12
const ANVIL_SLOTS := ["weapon", "head", "chest", "legs", "gloves", "boots", "back", "necklace", "ring"]


func start(cid: String) -> void:
	Survivor.reset()  # tout lancement repart sans Survivant (Survivor.start le remet ensuite)
	survivor = false
	active = true
	class_id = cid
	skills.clear()
	chains.clear()
	passives.clear()
	passive_power.clear()
	hero_level = 1
	combo_damage = 0.0
	combo_best = 0.0
	banned.clear()
	kept.clear()
	bans_used = 0
	locks_used = 0
	cards_at_start = Cards.unlocked_ids()
	loot.clear()
	kills = 0
	elites = 0
	gold = 0
	max_level = 1
	rerolls_used = 0
	new_classes = []
	new_costumes = []
	chests_found = []
	reward_mark = Profile.reward_chests.size()
	result = ""
	started_at = Time.get_ticks_msec()
	zone_id = Profile.selected_zone
	start_zone = zone_id
	stage = 1
	unlocked_name = ""
	unlocked_epoch = ""
	fortune_insignia = 0
	insignia_parts = {}
	perfects = 0
	resurrections = 0
	rage_stages = []
	offhand_used = false
	anvil_stages = []
	heroic_rank = 0
	stars_gained = 0
	heroic_rewards = []
	chests_total = 0
	contracts_done = []
	challenge_first = false
	Challenge.reset()
	survival = false
	epoch = 1
	seen_items = []
	seen_family = []
	slot_bonus = {}
	weapon_ups = {}
	trophies = []
	anvil_stage = 0
	Profile.begin_run()
	Potions.start_run()
	RunJournal.begin_run()
	changed.emit()


## Run de Survie de l'époque [param ep] : la zone de sa 1re map, avec l'équipement du hub (0.1.164 :
## pièces, +N, gemmes, enchantements, panoplies, arme secondaire ; copies, voir Profile.begin_run).
## Les trouvailles des coffres d'emplacement remplacent un emplacement le temps de la run seulement :
## l'équipement du hub est restauré à la fin (Profile.end_run_survival).
func start_survival(cid: String, ep: int, rank := 0) -> void:
	Profile.selected_zone = Epochs.zone(ep, 1)
	start(cid)
	heroic_rank = clampi(rank, 0, Epochs.HEROIC_MAX) if Epochs.heroic_open() else 0
	Challenge.heroic_mods = Epochs.heroic_mods(heroic_rank)
	survival = true
	epoch = clampi(ep, 1, Epochs.count())
	zone_id = Epochs.zone(epoch, 1)
	start_zone = zone_id
	offhand_used = Profile.equipped.has("offhand")  # défi « sans arme secondaire » : celle du hub compte
	changed.emit()


func finish(res: String) -> void:
	if not active:
		return
	active = false
	result = res
	var map_min := RunJournal.map_minutes()  # temps de la carte en cours (avant que le journal la close)
	RunJournal.end_map(res)
	if survivor:
		# Survivant : aucun lien avec la progression du compte (ni maîtrise, ni insignes, ni records) ; le hub est
		# remis tel qu'au départ, puis ses seules récompenses (SurvivorRewards, lot S6)
		Survivor.finish(res, mini(kills, KILL_CAP_PER_MAP))
		Quests.end_run("survivor", res == "victoire")  # après la remise du hub (quêtes, passe M5)
		Profile.save_profile()
		return
	Profile.record_max("best_combo", combo_best)
	Profile.runs_done += 1
	var counted := mini(kills, KILL_CAP_PER_MAP * maxi(stage, 1))
	expertise_gain = max_level * 15 + counted / 2 + elites * 10 + (200 if res == "victoire" else (60 if res == "extraction" else 0)) + 120 * (stage - 1)
	var settled := Challenge.settle(expertise_gain, res)
	expertise_gain = int(settled.gain)
	challenge_first = bool(settled.first)
	if survival and res != "abandon":
		contracts_done = Contracts.report(class_id, {"kills": kills, "elites": elites, "chests": chests_total, "perfects": perfects,
			"max_level": max_level, "wins": 1 if res == "victoire" else 0})
		for c in contracts_done:
			expertise_gain += int(c.reward)
	expertise_catchup = 0
	first_win_bonus = 0
	if survival:
		# lot E5 : rattrapage des classes en retard, puis 1re victoire de la classe à cette époque
		expertise_catchup = Economy.catchup(class_id, expertise_gain) - expertise_gain
		expertise_gain += expertise_catchup
		if res == "victoire" and stage >= RunDirector.STAGES:
			first_win_bonus = Economy.first_win(class_id, epoch)
			expertise_gain += first_win_bonus
	expertise_levels = Profile.add_expertise(class_id, expertise_gain)
	shared_gain = Profile.last_shared.duplicate()
	if survival:
		# pièces choisies dans les coffres : achetables au hub ; insignes selon la distance parcourue
		for id in seen_items + seen_family:
			if not int(id) in Profile.seen_gear:
				Profile.seen_gear.append(int(id))
		# 25 de participation (dès 10 monstres vaincus), 25 par carte atteinte : même une défaite en carte 1
		# paie de quoi acheter une pièce de l'Armurerie en 1 ou 2 runs (prix 50 à 73 pour l'époque I)
		insignia_parts = Economy.survival_insignia_parts(stage, counted, elites, epoch, res == "victoire", map_min)  # barème unique (lots E5, E6)
		insignia_gain = Economy.survival_insignia(stage, counted, elites, epoch, res == "victoire", map_min)
		if Challenge.active:
			insignia_gain = roundi(insignia_gain * 1.5)  # Défi de maîtrise : insignes ×1,5
		if heroic_rank > 0:
			insignia_gain = roundi(insignia_gain * (1.0 + Epochs.HEROIC_INSIGNIA * heroic_rank))
		Profile.insignia += insignia_gain
		insignia_gain += fortune_insignia  # (déjà crédités à l'autel)
	if res == "victoire":
		insignia_gain = Menace.add_insignia(insignia_gain, stage)  # Menace atteinte, cartes sous pacte (passe P12)
		Profile.runs_won += 1
		unlocked_name = Profile.unlock_after(zone_id)
		if survival and stage >= RunDirector.STAGES:
			_award_stars()
			_award_heroic()
	Profile.best_level = maxi(Profile.best_level, max_level)
	if survival:
		Quests.end_run("survival", res == "victoire")  # quêtes du jour et de la semaine (passe M5)
	Achievements.refresh()
	Profile.save_profile()


## Étoiles d'époque gagnées par la run (victoire à la 3e carte).
func _award_stars() -> void:
	var key := "epoch_stars_%d" % epoch
	var before := Epochs.stars(epoch)
	Profile.records[key] = Epochs.star_mask(epoch) | Epochs.earned_mask(epoch)
	stars_gained = Epochs.stars(epoch) - before


## Rang héroïque terminé : le suivant s'ouvre, récompenses (coffre d'apparence aux rangs 3, 6 et 9, titre au rang 10).
func _award_heroic() -> void:
	if heroic_rank <= 0:
		return
	if heroic_rank > Epochs.heroic_best(epoch):
		Profile.records["heroic_best_%d" % epoch] = heroic_rank
		if heroic_rank % 3 == 0 and heroic_rank < Epochs.HEROIC_MAX:
			Profile.chest_add(Rewards.look_type(mini(epoch, 3)), max_level)
			heroic_rewards.append("coffre d'apparence (rang %d)" % heroic_rank)
		if heroic_rank >= Epochs.HEROIC_MAX:
			var t := "Héros de %s" % Epochs.get_def(epoch).name
			Profile.add_title(t)
			heroic_rewards.append("titre « %s »" % t)


## Or gagné : crédité tout de suite (coffres, marchands, forge), compté pour le bilan.
func add_gold(amount: int, source := "autre") -> void:
	amount = roundi(float(Modifiers.apply("chest_gold", float(amount), ModeRules.modifiers)))  # modificateur « or +30 % »
	RunJournal.gold_in(amount, source)
	gold += amount
	Profile.add_gold(amount)


## Objet ramassé : directement dans l'inventaire (équipable via le menu pause).
func pick_up(item: Dictionary) -> bool:
	if item.has("offhand_drop"):
		return true  # arme secondaire : le choix s'ouvre au ramassage (RunDirector._drop_offhand)
	if item.has("consumable"):
		Profile.add_bag(String(item.consumable))
		return true
	if item.has("chest"):
		Tutorial.event("reward_chest")
		# coffre de récompense : rangé tout de suite dans le menu Coffres, jamais perdu
		Profile.reward_chests.append(item.chest)
		Profile.save_profile()
		changed.emit()
		return true
	if not Profile.add_item(item):
		return false
	loot.append(item)
	Profile.save_profile()
	return true


## Type de l'arme principale : toujours celui de la classe (0.1.128) ; l'arme secondaire,
## trouvée en jeu, peut être de n'importe quel type.
func weapon_type() -> String:
	if Survivor.active:
		return Survivor.weapon_type()  # Survivant : l'arme portée, de n'importe quel type
	return Items.default_weapon_type(class_id)


## Auto-attaque de l'emplacement d'arme [param slot] ({} : pas d'arme secondaire).
func weapon_spec(slot: String) -> Dictionary:
	var it: Dictionary = Profile.equipped.get(slot, {})
	if slot == "weapon":
		return WeaponAttacks.spec_for(it, weapon_type())
	return WeaponAttacks.spec_for(it) if not it.is_empty() else {}


## Coffres de récompense gagnés pendant la run (rangés tout de suite dans le menu Coffres).
func new_reward_chests() -> Array:
	return Profile.reward_chests.slice(mini(reward_mark, Profile.reward_chests.size()))


func duration_text() -> String:
	var s := (Time.get_ticks_msec() - started_at) / 1000
	return "%d min %02d s" % [s / 60, s % 60]


func class_data() -> Dictionary:
	return GameData.class_data(class_id)


func skill_def(id: int) -> Dictionary:
	for s in class_data().get("skills", []):
		if int(s.id) == id:
			return s
	return {}


## Passif de classe ou carte de build commune (Boons).
func passive_def(id: String) -> Dictionary:
	for p in class_data().get("passives", []):
		if p.id == id:
			return p
	var cc := Cards.class_card(class_id, id)
	if not cc.is_empty():
		return cc
	if id.begins_with("cert:"):
		return certificate_card(id.trim_prefix("cert:"))
	return Boons.get_def(id)


## Certificat « classe/id » présenté comme une carte (un seul exemplaire, rare).
func certificate_card(key: String) -> Dictionary:
	var parts := key.split("/")
	if parts.size() < 2:
		return {}
	for p in GameData.class_data(parts[0]).get("passives", []):
		if String(p.id) == parts[1]:
			var d: Dictionary = p.duplicate(true)
			d["id"] = "cert:" + key
			d["max"] = 1
			d["rarity"] = "rare"
			d["cert"] = key
			d["cert_class"] = String(GameData.class_data(parts[0]).get("name_fr", parts[0]))
			if not d.has("desc"):
				d["desc"] = Cards.total_text(d, 1.0)
			return d
	return {}


## Certificats qui peuvent tomber en run : ceux de la classe jouée et tous ceux débloqués,
## sauf ceux posés sur le plateau (déjà acquis pour la run).
func certificate_pool() -> Array:
	var keys: Array = Profile.unlocked_certificates().map(func(x): return String(x.key))
	for c in GameData.talents.get(class_id, {}).get("certificates", []):
		var k := "%s/%s" % [class_id, c]
		if not k in keys:
			keys.append(k)
	var out: Array = []
	for k in keys:
		if not k in Profile.certificates and not Profile.cert_passive_posed(String(k)):
			var d := certificate_card(String(k))
			if not d.is_empty():
				out.append(d)
	return out


## Somme des effets des cartes de classe prises sur le sort [param skill_id] (dmg, cd…).
func skill_card_mod(skill_id: int, key: String) -> float:
	var total := 0.0
	for pid in passives:
		if String(pid).begins_with("sk%d_" % skill_id):
			var d := Cards.class_card(class_id, String(pid))
			total += float(d.get("skill_mod", {}).get(key, 0.0)) * power(String(pid))
	return total


func rerolls_left() -> int:
	if Survivor.active and SurvivorCards.handles():
		return SurvivorCards.rerolls_left()
	return maxi(0, 1 + int(passive_stats().get("rerolls", 0)) - rerolls_used)


## Puissance d'un passif : somme des multiplicateurs de rareté (Cards) des cartes prises
## (une carte commune = 1) ; à défaut (tests, mode dev), le nombre de cartes.
func power(pid: String) -> float:
	return float(passive_power.get(pid, passives.get(pid, 0)))


## Effets déclenchés apportés par les cartes de la run.
## Familles d'effet des trophées de la run.
func trophy_kinds() -> Array:
	return trophies.map(func(t): return String(t.get("passive", {}).get("trophy", "")))


## Ajoute le trophée [param it] à la collection (refusé si elle est pleine ou si son effet y est
## déjà).
func add_trophy(it: Dictionary) -> bool:
	var kind := String(it.get("passive", {}).get("trophy", ""))
	if trophies.size() >= MAX_TROPHIES or kind == "" or kind in trophy_kinds():
		return false
	trophies.append(it)
	Profile.note_trophy(kind)
	if it.has("eden") and not int(it.eden) in seen_items:
		seen_items.append(int(it.eden))
	changed.emit()
	return true


## Survie : une arme choisie (coffre d'arme, arme secondaire) fait découvrir les armes de tous les types
## au palier et à la rareté de la map (Armurerie, fin de run) : avoir l'arme de chaque type ne demande pas
## de jouer une classe de chaque type (lot E4).
func discover_weapons() -> void:
	if not survival:
		return
	for id in SlotChests.weapon_family(epoch, stage):
		if not int(id) in seen_family:
			seen_family.append(int(id))


## Effets des trophées de la run (un par trophée).
func trophy_procs() -> Array:
	var out: Array = []
	for t in trophies:
		for p: Dictionary in t.get("passive", {}).get("procs", []):
			out.append(p.duplicate(true))
	return out


func passive_procs() -> Array:
	var out: Array = []
	for pid in passives:
		out.append_array(Boons.procs_of(passive_def(pid), power(pid)))
	return out


## Compétence prise : {id, rank, dmg, cd, heal, dur, riders}.
func skill_entry(id: int) -> Dictionary:
	for s in all_skills():
		if int(s.id) == id:
			return s
	return {}


func skill_rank(id: int) -> int:
	var s := skill_entry(id)
	return int(s.rank) if not s.is_empty() else 0


## Tous les sorts pris : principaux et enchaînements.
func all_skills() -> Array:
	var out: Array = skills.duplicate()
	for k in chains:
		out.append_array(chains[k])
	return out


## Enchaînement de la case [param slot] : [{id, rank}].
func chain_of(slot: int) -> Array:
	return chains.get(slot, [])


## Sort à la position [param pos] de la grille de la run : x = case (0 à 3), y = 0 sort principal, 1 et 2 enchaînements.
## {} si la position est libre.
func spell_at(pos: Vector2i) -> Dictionary:
	if pos.y == 0:
		return skills[pos.x] if pos.x >= 0 and pos.x < skills.size() else {}
	var ch := chain_of(pos.x)
	return ch[pos.y - 1] if pos.y - 1 < ch.size() else {}


## Échange les sorts des positions [param a] et [param b] (glisser-déposer du menu pause). Un enchaînement peut aussi
## aller sur une position d'enchaînement libre ; un sort principal ne peut pas quitter sa case (elle resterait vide).
## Renvoie true si quelque chose a changé.
func swap_spells(a: Vector2i, b: Vector2i) -> bool:
	if a == b:
		return false
	var ea := spell_at(a)
	var eb := spell_at(b)
	if ea.is_empty():
		return false
	if eb.is_empty():
		if a.y == 0 or b.y == 0 or b.x >= skills.size():
			return false
		var src: Array = chain_of(a.x).duplicate()
		src.remove_at(a.y - 1)
		chains[a.x] = src
		var dst: Array = chain_of(b.x).duplicate()
		dst.append(ea)
		chains[b.x] = dst
	else:
		_set_spell(a, eb)
		_set_spell(b, ea)
	changed.emit()
	return true


func _set_spell(pos: Vector2i, entry: Dictionary) -> void:
	if pos.y == 0:
		skills[pos.x] = entry
		return
	var ch: Array = chain_of(pos.x).duplicate()
	ch[pos.y - 1] = entry
	chains[pos.x] = ch


## Case où ira l'enchaînement [param id] : celle de sa colonne dans le preset actif, sinon
## une case au hasard parmi [param room].
func _chain_slot_for(id: int, room: Array) -> int:
	var p := SpellPresets.active(class_id)
	var at := SpellPresets.place_of(p, id) if not p.is_empty() else Vector2i(-1, -1)
	if at.x >= 0:
		var main := int(p.cols[at.x][0])
		for i in skills.size():
			if int(skills[i].id) == main and i in room:
				return i
	return int(room.pick_random())


## Retire le sort [param id] (principal : ses enchaînements partent avec lui et les cases
## suivantes se décalent).
func remove_skill(id: int) -> void:
	for k in chains.keys():
		chains[k] = (chains[k] as Array).filter(func(e): return int(e.id) != id)
	for i in skills.size():
		if int(skills[i].id) == id:
			skills.remove_at(i)
			var nc := {}
			for k in chains:
				if int(k) < i:
					nc[int(k)] = chains[k]
				elif int(k) > i:
					nc[int(k) - 1] = chains[k]
			chains = nc
			break
	changed.emit()


## Bonus de dégâts et de recharge apportés par les cartes d'amélioration de la compétence
## (à défaut : +20 % / -8 % par rang, anciennes runs et tests).
func skill_damage_mult(id: int) -> float:
	var t := skill_talent(id)
	var s := skill_entry(id)
	return (1.0 + float(s.get("dmg", 0.2 * (skill_rank(id) - 1)))) * (1.0 + float(t.dmg) + float(t.power))


func skill_cooldown_mult(id: int) -> float:
	var s := skill_entry(id)
	return (1.0 - minf(float(s.get("cd", 0.08 * (skill_rank(id) - 1))), 0.6)) * (1.0 - minf(float(skill_talent(id).cd), 0.6))


## Soins de la compétence (cartes d'amélioration des sorts de soin).
func skill_heal_mult(id: int) -> float:
	return (1.0 + float(skill_entry(id).get("heal", 0.0))) * (1.0 + skill_card_mod(id, "heal"))


## Durée des effets de la compétence (buffs, états infligés).
func skill_duration_mult(id: int) -> float:
	return (1.0 + float(skill_entry(id).get("dur", 0.0))) * (1.0 + skill_card_mod(id, "duration"))


## Bonus d'attribut au lancement : [{stat, value, duration}].
func skill_riders(id: int) -> Array:
	return skill_entry(id).get("riders", [])


## Statistiques cumulées des passifs de la run.
func passive_stats() -> Dictionary:
	var total := {}
	for pid in passives:
		var p := passive_def(pid)
		for s in p.get("stat", {}):
			total[s] = total.get(s, 0.0) + float(p.stat[s]) * power(pid)
	if Survivor.active:
		return total  # Survivant : ni talents, ni certificats, ni plateau (aucun lien avec la progression du compte)
	# talents de la classe jouée (arbre d'Eden)
	var tree: Dictionary = GameData.talents.get(class_id, {}).get("talents", {})
	for id in Profile.talents.get(class_id, {}):
		var eff: Dictionary = tree.get(id, {}).get("effect", {})
		if eff.get("type", "") == "stat":
			total[eff.stat] = total.get(eff.stat, 0.0) + float(eff.per_level) * int(Profile.talents[class_id][id])
	# certificats équipés (passifs des classes maîtrisées, utilisables par toutes)
	for key in Profile.certificates:
		var parts: PackedStringArray = String(key).split("/")
		for p in GameData.class_data(parts[0]).get("passives", []):
			if p.id == parts[1]:
				for s in p.get("stat", {}):
					total[s] = total.get(s, 0.0) + float(p.stat[s])
	# placement des certificats sur le plateau (liens, prisme, losange)
	var board := CertBoard.stats(Profile.cert_board)
	for s in board:
		total[s] = total.get(s, 0.0) + float(board[s])
	return total


## Bonus des talents sur une compétence : {dmg, cd, duration, power}.
func skill_talent(skill_id: int) -> Dictionary:
	# cartes de classe prises sur ce sort (puissance, cadence)
	var out := {"dmg": skill_card_mod(skill_id, "dmg"), "cd": skill_card_mod(skill_id, "cd"), "duration": 0.0, "power": 0.0}
	if Survivor.active:
		return out  # Survivant : pas de talents de classe
	var tree: Dictionary = GameData.talents.get(class_id, {}).get("talents", {})
	for id in Profile.talents.get(class_id, {}):
		var eff: Dictionary = tree.get(id, {}).get("effect", {})
		if int(eff.get("skill", 0)) != skill_id:
			continue
		var n := int(Profile.talents[class_id][id])
		match String(eff.type):
			"skill_dmg":
				out.dmg += float(eff.per_level) * n
			"skill_cd":
				out.cd += float(eff.per_level) * n
			"skill_duration":
				out.duration += float(eff.per_level) * n
			"skill_power":
				out.power += float(eff.per_level) * n
	return out


# --- cartes -----------------------------------------------------------------------
## Tire [param n] cartes différentes. [param skills_only] : choix de départ.
## [param kind] : "" toutes ; "spell" sorts (nouveau, enchaînement, rang) ; "passive" passifs
## hors certificats ; "cert" certificats (coffres de cartes de la Survie).
## Plafonds des statistiques de cartes : une carte dont la stat est au plafond n'est plus proposée.
const STAT_CAPS := {"execute": 0.3, "cdr": 0.5, "eva": 0.2}


func _at_cap(p: Dictionary) -> bool:
	var st: Dictionary = p.get("stat", {})
	for k in STAT_CAPS:
		if st.has(k) and float(passive_stats().get(k, 0.0)) >= float(STAT_CAPS[k]) - 0.0001:
			return true
	return false


func roll_cards(n := 3, skills_only := false, kind := "") -> Array:
	if Survivor.active and SurvivorCards.handles():
		return SurvivorCards.roll(n, "skill" if skills_only else kind)
	var pool: Array = []
	var owned := all_skills().map(func(s): return int(s.id))
	if skills.size() < MAX_SKILLS:
		for s in class_data().get("skills", []):
			if not int(s.id) in owned and Progression.skill_unlocked(class_id, int(s.id)):
				pool.append({"type": "skill", "id": int(s.id), "weight": 3.0 if skills.size() < 2 else 2.0})
	elif not skills_only:
		# cases pleines : les autres sorts de la classe deviennent des enchaînements
		var room: Array = range(skills.size()).filter(func(i): return chain_of(i).size() < MAX_CHAIN)
		if not room.is_empty():
			for s in class_data().get("skills", []):
				if not int(s.id) in owned and Progression.skill_unlocked(class_id, int(s.id)):
					pool.append({"type": "chain", "id": int(s.id), "slot": _chain_slot_for(int(s.id), room), "weight": 2.0})
	if not skills_only:
		for s in all_skills():
			if int(s.rank) < int(Cards.rules().max_rank):
				pool.append({"type": "upgrade", "id": int(s.id), "weight": 1.5})
		# améliorations d'arme : l'arme principale souvent, la secondaire si elle est portée
		for slot in ["weapon", "offhand"]:
			if not weapon_spec(slot).is_empty() and int(weapon_ups.get(slot, {}).get("rank", 0)) < WeaponAttacks.MAX_RANK:
				pool.append({"type": "weapon_up", "id": slot, "weight": 5.0 if slot == "weapon" else 1.8})
		var boons := {}
		for b in Boons.all():
			boons[String(b.id)] = true
		# cartes communes et certificats non posés sur le plateau (ceux posés sont déjà acquis) ;
		# les certificats pèsent ensemble comme quelques cartes, quel que soit leur nombre
		var certs := certificate_pool()
		var cert_k := minf(1.0, 4.0 / maxf(1.0, float(certs.size())))
		for p in Boons.all() + certs:
			if int(passives.get(p.id, 0)) >= mini(int(p.get("max", 1)), 99 if p.get("instant", false) else Cards.MAX_LEVEL):
				continue
			if String(p.id) in banned or (boons.has(String(p.id)) and not Cards.card_unlocked(String(p.id))):
				continue  # bannie pour la run, ou carte pas encore débloquée (méta-progression)
			if not p.get("requires", []).all(func(r): return passives.has(r)):
				continue
			if _at_cap(p):
				continue  # statistique au plafond : la carte n'apporterait rien
			var rar: Dictionary = Boons.RARITY[String(p.get("rarity", "common"))]
			pool.append({"type": "passive", "id": p.id, "cert": p.has("cert"), "weight": 1.2 * float(rar.weight) * (0.5 if p.get("instant", false) else 1.0) * (cert_k if p.has("cert") else 1.0)})
		# les cartes de classe (puissance, cadence, persistance) ne sont plus proposées : elles sont
		# devenues les facettes de l'amélioration de sort (Cards.skill_upgrade)
	pool = pool.filter(func(c): return not (c.type in ["skill", "chain"] and str(c.id) in banned) \
		and not kept.any(func(k): return String(k.type) == String(c.type) and str(k.id) == str(c.id)))
	match kind:
		"spell":
			pool = pool.filter(func(c): return c.type in ["skill", "chain", "upgrade"])
		"weapon":
			pool = pool.filter(func(c): return c.type == "weapon_up")
		"passive":
			pool = pool.filter(func(c): return c.type == "passive" and not c.get("cert", false))
		"cert":
			pool = pool.filter(func(c): return c.get("cert", false))
	var picks: Array = []
	# cartes gardées au choix précédent : proposées d'abord, avec leur rareté
	if not skills_only and kind == "":
		for k in kept:
			if picks.size() < n:
				picks.append(_describe_card(k))
		kept.clear()
	# tant que les 4 emplacements ne sont pas remplis, au moins une nouvelle compétence
	var skill_cards := pool.filter(func(c): return c.type == "skill")
	if not skill_cards.is_empty() and not skills_only and picks.size() < n \
			and not picks.any(func(c): return String(c.type) == "skill"):
		var forced: Dictionary = skill_cards.pick_random()
		picks.append(_describe_card(forced))
		pool.erase(forced)
	while picks.size() < n and not pool.is_empty():
		var total := 0.0
		for c in pool:
			total += float(c.weight)
		var r := randf() * total
		for c in pool:
			r -= float(c.weight)
			if r <= 0.0:
				picks.append(_describe_card(c))
				pool.erase(c)
				break
	return picks


func _describe_card(c: Dictionary) -> Dictionary:
	match c.type:
		"skill":
			var s := skill_def(int(c.id))
			return {"type": "skill", "id": c.id, "title": s.name, "subtitle": "Nouvelle compétence",
				"desc": "%s\nRecharge : %d s" % [s.desc, int(s.cooldown)], "icon": s.icon}
		"chain":
			var s := skill_def(int(c.id))
			var slot := int(c.slot)
			var first := skill_def(int(skills[slot].id)) if slot < skills.size() else {}
			var step := chain_of(slot).size() + 2
			return {"type": "chain", "id": c.id, "slot": slot, "title": "Enchaînement : %s" % s.name,
				"subtitle": "Case %d · %de sort de la chaîne" % [slot + 1, step],
				"desc": "%s\n[color=#9fd0ff]Après « %s »%s (touche de la case %d), l'icône de ce sort reste 0,45 s en recharge, puis une barre se remplit au-dessus de la case : rappuie avant qu'elle soit pleine et ce sort part aussitôt, +20 %% de dégâts. Tu peux rappuyer tout de suite : l'appui est gardé (mémoire des touches) et le coup part dès qu'il le peut. Laisser la barre se vider casse la chaîne.[/color]" % [
					s.desc, first.get("name", "?"), "" if step == 2 else " et le sort suivant", slot + 1], "icon": s.icon}
		"upgrade":
			var s := skill_def(int(c.id))
			var rank := skill_rank(int(c.id)) + 1
			var tier := String(c.get("tier", "")) if String(c.get("tier", "")) != "" else Cards.roll_tier()
			var magic := String(class_data().get("dmg_type", "phys")) in ["mag", "magic"]
			var up := Cards.skill_upgrade(s, tier, (["int", "wis"] if magic else ["str", "agi"]).pick_random())
			return {"type": "upgrade", "id": c.id, "tier": tier, "up": up, "title": "%s — rang %d" % [s.name, rank],
				"subtitle": "Amélioration %s" % String(Cards.tier(tier).name).to_lower(),
				"desc": "\n".join(Cards.skill_upgrade_lines(skill_entry(int(c.id)), up)), "icon": s.icon}
		"weapon_up":
			var slot := String(c.id)
			var spec := weapon_spec(slot)
			var cur: Dictionary = weapon_ups.get(slot, {})
			var tier := String(c.get("tier", "")) if String(c.get("tier", "")) != "" else Cards.roll_tier()
			var up := WeaponAttacks.roll_upgrade(spec, tier, cur)
			var it: Dictionary = Profile.equipped.get(slot, {})
			var icon := String(it.get("icon", GameData.weapon_type(String(spec.wtype)).get("icon", "")))
			return {"type": "weapon_up", "id": slot, "tier": tier, "up": up,
				"title": "%s — niveau %d" % [spec.name, int(cur.get("rank", 0)) + 1],
				"subtitle": "Amélioration d'arme %s · %s" % [String(Cards.tier(tier).name).to_lower(), "arme principale" if slot == "weapon" else "arme secondaire"],
				"desc": "\n".join(WeaponAttacks.upgrade_lines(spec, cur, up)), "icon": icon}
		_:
			var p := passive_def(String(c.id))
			var stacks := int(passives.get(p.id, 0))
			var rarity := String(p.get("rarity", "common"))
			var icon := String(p.get("icon", Boons.ICONS.get(p.id, "")))
			if p.get("instant", false):
				return {"type": "passive", "id": p.id, "title": p.name, "tier": "rare", "mult": 1.0,
					"subtitle": "Effet immédiat", "desc": p.desc, "icon": icon}
			# rareté tirée (les évolutions sont toujours légendaires, sans multiplicateur)
			var evo: bool = rarity == "legendary" and not (p.get("requires", []) as Array).is_empty()
			var tier := "legendary" if evo else (String(c.get("tier", "")) if String(c.get("tier", "")) != "" else Cards.roll_tier())
			var m := 1.0 if evo else Cards.tier_mult(tier)
			var before := power(p.id)
			var lines := Cards.stat_lines(p, before, before + m)
			if before > 0.0:  # 1re carte : la description donne déjà les valeurs de l'effet
				lines.append_array(Cards.proc_lines(p, before, before + m))
			var kind := "Évolution" if evo else ("Passif" if p.get("procs", []).is_empty() else "Effet")
			if p.has("cert"):
				kind = "Certificat %s ·" % String(p.get("cert_class", ""))
			elif p.has("skill_mod"):
				kind = "Carte de sort ·"
			var mx := mini(int(p.get("max", 1)), Cards.MAX_LEVEL)
			return {"type": "passive", "id": p.id, "title": p.name, "tier": tier, "mult": m,
				"subtitle": "%s %s" % [kind, String(Cards.tier(tier).name).to_lower()] + (" · niv. %d → %d" % [stacks, stacks + 1] if mx > 1 else ""),
				"desc": p.desc + ("\n[color=#9fd0ff]%s[/color]" % "\n".join(lines) if not lines.is_empty() else ""), "icon": icon}


func apply_card(card: Dictionary) -> void:
	if Survivor.owns(card):
		Survivor.apply_card(card)  # cartes « sv_… » du Survivant
		changed.emit()
		return
	Tutorial.on_card(card)
	match card.type:
		"skill":
			if skills.size() < MAX_SKILLS:
				skills.append({"id": int(card.id), "rank": 1})
		"chain":
			var slot := int(card.get("slot", 0))
			var ch: Array = chain_of(slot).duplicate()
			if slot < skills.size() and ch.size() < MAX_CHAIN and skill_entry(int(card.id)).is_empty():
				ch.append({"id": int(card.id), "rank": 1})
				chains[slot] = ch
		"upgrade":
			for s in all_skills():
				if int(s.id) == int(card.id):
					s.rank = mini(int(s.rank) + 1, int(Cards.rules().max_rank))
					var up: Dictionary = card.get("up", {"dmg": 0.2, "cd": 0.08})
					for k in ["dmg", "cd", "heal", "dur"]:
						if up.has(k):
							s[k] = float(s.get(k, 0.2 * (int(s.rank) - 2) if k == "dmg" else (0.08 * (int(s.rank) - 2) if k == "cd" else 0.0))) + float(up[k])
					if up.has("rider"):
						var riders: Array = s.get("riders", [])
						var merged := false
						for r in riders:
							if String(r.stat) == String(up.rider.stat):
								r.value = float(r.value) + float(up.rider.value)
								r.duration = maxf(float(r.duration), float(up.rider.duration))
								merged = true
						if not merged:
							riders.append(up.rider.duplicate())
						s["riders"] = riders
		"passive":
			if passive_def(String(card.id)).get("instant", false):
				instant_card.emit(String(card.id))
				changed.emit()
				return
			var before := power(String(card.id))
			passives[card.id] = int(passives.get(card.id, 0)) + 1
			passive_power[card.id] = before + float(card.get("mult", 1.0))
		"trophy":
			add_trophy(card.item)  # collection de la run : l'effet agit tout de suite
		"gear":
			if survival:
				# coffre d'emplacement : la pièce est portée tout de suite (l'ancienne reste dans le sac)
				Profile.inventory.append(card.item)
				Profile.equip(card.item)
				if card.item.has("eden") and not int(card.item.eden) in seen_items:
					seen_items.append(int(card.item.eden))
				if String(card.item.get("slot", "")) == "weapon":
					discover_weapons()
				Profile.changed.emit()
			else:
				pick_up(card.item)  # choix de trophée ou d'équipement (coffres de la carte) : dans le sac
		"weapon_up":
			var cur: Dictionary = weapon_ups.get(String(card.id), {})
			WeaponAttacks.merge_upgrade(cur, card.get("up", {"dmg": 0.15}))
			weapon_ups[String(card.id)] = cur
			if cur.get("sig", false):
				var ws := weapon_spec(String(card.id))
				Profile.note_weapon_legend("%s:%d" % [ws.get("wtype", "?"), int(ws.get("variant", 0))])
		"offhand":
			offhand_used = true
			# arme secondaire trouvée en jeu : portée tout de suite (l'ancienne reste dans le sac)
			Profile.inventory.append(card.item)
			Profile.equip_offhand(card.item)
			if card.item.has("eden") and not int(card.item.eden) in seen_items:
				seen_items.append(int(card.item.eden))
			discover_weapons()
			Profile.changed.emit()
		"anvil_slot":
			if not stage in anvil_stages:
				anvil_stages.append(stage)
			anvil_result = anvil_roll(String(card.slot))
		"anvil":
			if not stage in anvil_stages:
				anvil_stages.append(stage)
			# enclume de la carte : +1 garanti sur la pièce portée choisie
			var it: Dictionary = Profile.equipped.get(String(card.slot), {})
			if not it.is_empty():
				var res := Craft.upgrade_free(it)
				anvil_result = String(res.get("text", ""))
				Profile.changed.emit()
		"scroll":
			Profile.add_bag(String(card.key))  # autel du scribe : le parchemin choisi
	if card.type in ["skill", "chain"]:
		arrange()
	changed.emit()


## Résultat de la dernière enclume (affiché par le directeur de run).
var anvil_result := ""


## +N effectif d'une pièce portée dans [param slot] : son +N (hub) plus le bonus d'enclume de
## l'emplacement, plafonné à UPGRADE_CAP.
func slot_upgrade(piece_up: int, slot: String) -> int:
	return clampi(piece_up + int(slot_bonus.get(slot, 0)), 0, maxi(UPGRADE_CAP, piece_up))


## Enclume de la Survie : tire l'amélioration de l'emplacement [param slot] (remplace la
## précédente) ; renvoie le texte du résultat.
func anvil_roll(slot: String) -> String:
	var total := 0
	for v in ANVIL_ROLLS:
		total += int(ANVIL_ROLLS[v])
	var r := randi() % total
	var got := 0
	for v in ANVIL_ROLLS:
		r -= int(ANVIL_ROLLS[v])
		if r < 0:
			got = int(v)
			break
	slot_bonus[slot] = got
	anvil_stage = stage
	Profile.changed.emit()
	var name := String(Items.SLOT_NAMES.get(slot, slot))
	var up := slot_upgrade(int(Profile.equipped.get(slot, {}).get("upgrade", 0)), slot)
	if got >= 6:
		return "Coup de maître ! %s +%d (total +%d)" % [name, got, up]
	return "%s +%d (total +%d)" % [name, got, up]


## Range les sorts pris selon le preset actif de la classe (Grimoire, SpellPresets) : sorts
## principaux dans l'ordre de leurs cases, enchaînements sous leur case ; les sorts hors
## preset gardent l'ordre d'obtention et prennent les places libres.
func arrange() -> void:
	var p := SpellPresets.active(class_id)
	if p.is_empty():
		return
	var cols: Array = p.get("cols", [])
	var entries := {}  # id -> entrée {id, rank, ...}
	for e in all_skills():
		entries[int(e.id)] = e
	var old_mains: Array = skills.map(func(e): return int(e.id))
	var used := {}
	var new_skills: Array = []
	var col_of := {}  # case de la run -> colonne du preset
	for c in cols.size():
		var id := int(cols[c][0])
		if entries.has(id) and new_skills.size() < MAX_SKILLS:
			col_of[new_skills.size()] = c
			new_skills.append(entries[id])
			used[id] = true
	# sorts principaux hors preset (ou dont la colonne n'a pas son sort principal)
	for id in old_mains:
		if not used.has(id) and new_skills.size() < MAX_SKILLS and SpellPresets.place_of(p, id).y <= 0:
			new_skills.append(entries[id])
			used[id] = true
	var new_chains := {}
	for slot in new_skills.size():
		if col_of.has(slot):
			var ch: Array = []
			for r in range(1, (cols[col_of[slot]] as Array).size()):
				var id := int(cols[col_of[slot]][r])
				if entries.has(id) and not used.has(id) and ch.size() < MAX_CHAIN:
					ch.append(entries[id])
					used[id] = true
			if not ch.is_empty():
				new_chains[slot] = ch
	# le reste : une case principale libre, sinon un enchaînement libre
	for id in entries:
		if used.has(id):
			continue
		if new_skills.size() < MAX_SKILLS:
			new_skills.append(entries[id])
		else:
			for slot in new_skills.size():
				var ch: Array = new_chains.get(slot, [])
				if ch.size() < MAX_CHAIN:
					ch.append(entries[id])
					new_chains[slot] = ch
					break
		used[id] = true
	skills = new_skills
	chains = new_chains


## Entraînement : tous les sorts du preset actif, à leur place (rang gardé s'il était pris).
func fill_from_preset() -> void:
	var p := SpellPresets.active(class_id)
	if p.is_empty():
		return
	var ranks := {}
	for e in all_skills():
		ranks[int(e.id)] = int(e.rank)
	skills = []
	chains = {}
	for col in p.get("cols", []):
		var id := int(col[0])
		if id == 0 or skill_def(id).is_empty() or skills.size() >= MAX_SKILLS:
			continue
		var slot := skills.size()
		skills.append({"id": id, "rank": int(ranks.get(id, 1))})
		var ch: Array = []
		for r in range(1, (col as Array).size()):
			var cid := int(col[r])
			if cid != 0 and not skill_def(cid).is_empty() and ch.size() < MAX_CHAIN:
				ch.append({"id": cid, "rank": int(ranks.get(cid, 1))})
		if not ch.is_empty():
			chains[slot] = ch
	changed.emit()



## Bannit la carte pour la run ; renvoie une carte de remplacement (ou {}).
func ban_card(card: Dictionary, shown: Array) -> Dictionary:
	if Survivor.active and SurvivorCards.handles():
		return SurvivorCards.ban(card, shown)
	if bans_used >= Cards.BANS_PER_RUN or String(card.get("type", "")) in ["trophy", "gear", "anvil", "scroll"]:
		return {}
	bans_used += 1
	banned.append(str(card.id))
	var others := shown.map(func(c): return "%s|%s" % [c.type, c.id])
	for i in 20:
		var cand: Array = roll_cards(1)
		if not cand.is_empty() and not ("%s|%s" % [cand[0].type, cand[0].id]) in others:
			return cand[0]
	return {}


## Garde la carte pour le prochain choix (même rareté).
func keep_card(card: Dictionary) -> bool:
	if locks_used >= Cards.LOCKS_PER_RUN or String(card.get("type", "")) in ["trophy", "gear", "anvil", "scroll"]:
		return false
	if kept.any(func(k): return String(k.type) == String(card.type) and str(k.id) == str(card.id)):
		return false
	locks_used += 1
	kept.append({"type": card.type, "id": card.id, "tier": String(card.get("tier", "")), "slot": int(card.get("slot", 0))})
	return true


## Cartes débloquées pendant cette run (bilan).
func new_cards() -> Array:
	return Cards.unlocked_ids().filter(func(id): return not id in cards_at_start)



## Dégâts infligés par le héros (Combatant.take_damage).
func add_combo_damage(dmg: float) -> void:
	var now := Time.get_ticks_msec()
	if now - _combo_last > COMBO_RESET_MS:
		combo_damage = 0.0
	combo_damage += dmg
	_combo_last = now
	combo_best = maxf(combo_best, combo_damage)


## Compteur en cours (0 si plus de 3 s sans dégâts).
func combo_now() -> float:
	return combo_damage if Time.get_ticks_msec() - _combo_last <= COMBO_RESET_MS else 0.0


## Temps restant avant la remise à zéro (0..1).
func combo_left() -> float:
	return clampf(1.0 - float(Time.get_ticks_msec() - _combo_last) / COMBO_RESET_MS, 0.0, 1.0)
