class_name HeroLevel
extends RefCounted
## Niveau de héros (lot H1, conception `conception/progression/NIVEAU_HEROS.md`) : un niveau permanent du COMPTE,
## de 1 à 90, partagé par les 60 classes. Il ne redescend jamais.
##
## - État : `Profile.records["hero_xp"]` = XP totale (le niveau en est calculé) ; déjà sauvegardé (SafeFile), gardé par
##   `Profile.reload_keep_records` (max) et par la photo du Survivant (`Survivor.HUB_KEYS`).
## - Besoin du niveau L → L+1 : `NEED_BASE` × `NEED_GROWTH`^L (105 × 1,035^L : 148 au niveau 10, 2 243 au niveau 89).
## - Gain : au kill d'un monstre (Monster._on_death → [method on_kill]) en mode de progression seulement (Survie, Donjons,
##   Tour, Ruée, Siège ; jamais en Survivant, Battle royale, Duel, entraînement, Défi du jour) : 1 par monstre ordinaire,
##   4 par élite, 8 par boss, × clamp(1,1^(niveau du monstre − niveau du héros), 0,1, 3). L'XP de la partie attend le bilan :
##   [method settle] (appelé par `Quests.end_run`, le bus de fin de partie) la verse, +20 % si la partie est gagnée.
## - Migration (une fois, paresseuse, idempotente) : [method ensure] ; niveau de départ d'après les époques gagnées et la
##   plus haute pièce portée (aucune pièce n'est déséquipée).
## - Lecture : [method level], [method xp_in_level], [method xp_needed], [method xp_left], [method progress] ; signaux
##   [member events] (`xp_changed(total)`, `level_up(from, to)`).
##
## - Port des pièces (lot H3) : [method wear_block], [method lock_text], [method lock_line] ; une pièce de niveau N ne
##   s'équipe au hub que si le niveau de héros ≥ N (`Profile.equip`, `ClassGear.best_gear`).
## Les stats et les monstres (H4) ne lisent pas encore ce niveau.

const MAX_LEVEL := 90
const NEED_BASE := 105.0
const NEED_GROWTH := 1.035
const GAP_STEP := 1.1  # × par niveau d'écart entre le monstre et le héros
const GAP_MIN := 0.1
const GAP_MAX := 3.0
const UNIT_ELITE := 4.0
const UNIT_BOSS := 8.0
const WIN_BONUS := 0.2  # partie gagnée : +20 % de l'XP de la partie
## Activités qui font monter le niveau de héros (noms de `Quests.end_run`) et modes (`Modes.current()`) où l'on compte.
const ACTS := ["survival", "dungeon", "tower", "rush", "siege"]
const MODES := ["survival", "dungeon", "tower"]
## Migration : niveau de départ par nombre d'époques gagnées (0 : le meilleur niveau de run, plafonné à EPOCH0_CAP).
const MIGRATION := [0, 43, 60, 75, 85]
const EPOCH0_CAP := 35
const MYTHIC_DIFF := 2  # Dungeons.DIFF_NAMES : Mythique
const KEY := "hero_xp"
const KEY_START := "hero_start"  # niveau donné par la migration (rapport, tests)
const KEY_NOTE := "hero_note"  # 1 : message de migration à montrer au lobby ; 2 : montré

class Events extends RefCounted:
	signal xp_changed(total: float)
	signal level_up(from: int, to: int)

static var events := Events.new()

## XP de la partie en cours, pas encore versée (attend le bilan) ; liée à `Run.started_at`.
static var pending := 0.0
static var _pending_run := -1
## Dernier versement (bilan) : {run, act, won, xp, from, to} ; {} si la dernière partie n'en donnait pas.
static var last: Dictionary = {}

static var _totals: PackedFloat64Array = PackedFloat64Array()


# --- courbe ------------------------------------------------------------------------------------
## XP pour passer du niveau [param lv] au suivant (0 au niveau 90).
static func need(lv: int) -> float:
	if lv >= MAX_LEVEL or lv < 1:
		return 0.0
	return roundf(NEED_BASE * pow(NEED_GROWTH, lv))


## XP totale pour atteindre le niveau [param lv] (0 au niveau 1).
static func total_for(lv: int) -> float:
	if _totals.is_empty():
		_totals.resize(MAX_LEVEL + 1)
		var acc := 0.0
		_totals[0] = 0.0
		_totals[1] = 0.0
		for l in range(1, MAX_LEVEL):
			acc += need(l)
			_totals[l + 1] = acc
	return _totals[clampi(lv, 1, MAX_LEVEL)]


## Niveau atteint avec [param xp] d'XP totale.
static func level_for(xp: float) -> int:
	var lv := 1
	while lv < MAX_LEVEL and xp + 0.001 >= total_for(lv + 1):
		lv += 1
	return lv


# --- lecture -----------------------------------------------------------------------------------
static func total() -> float:
	ensure()
	return float(Profile.records.get(KEY, 0.0))


static func level() -> int:
	return level_for(total())


## XP déjà faite dans le niveau en cours.
static func xp_in_level() -> float:
	var t := total()
	return t - total_for(level_for(t))


## XP du niveau en cours (0 au niveau 90).
static func xp_needed() -> float:
	return need(level())


## XP qui manque pour le niveau suivant (0 au niveau 90).
static func xp_left() -> float:
	var lv := level()
	return 0.0 if lv >= MAX_LEVEL else total_for(lv + 1) - total()


## Avancée dans le niveau, de 0 à 1 (1 au niveau 90).
static func progress() -> float:
	var n := xp_needed()
	return 1.0 if n <= 0.0 else clampf(xp_in_level() / n, 0.0, 1.0)


## Infobulle de la jauge : niveau, XP, où il monte (sans pourcentage).
static func tooltip() -> String:
	var lv := level()
	var head := "Niveau de héros %d" % lv
	if lv < MAX_LEVEL:
		head += " · %s / %s XP" % [_n(xp_in_level()), _n(xp_needed())]
	else:
		head += " · niveau maximal"
	return head + "\nCommun à toutes tes classes. Il monte en battant des monstres en Survie, Donjons, Tour, Ruée et Siège."


static func _n(v: float) -> String:
	return ResultsPanel.number(floorf(v))


# --- gains -------------------------------------------------------------------------------------
## Le mode en cours fait-il monter le niveau de héros ?
static func counts_now() -> bool:
	return Modes.current() in MODES and not Challenge.active


## Multiplicateur d'écart : × 1,1 par niveau du monstre au-dessus du héros, borné à [0,1 ; 3].
static func gap_mult(monster_level: int, hero_level: int) -> float:
	return clampf(pow(GAP_STEP, monster_level - hero_level), GAP_MIN, GAP_MAX)


## XP d'un monstre de niveau [param monster_level] (rang : boss, élite ou ordinaire) pour un héros de niveau [param hero_level].
static func kill_xp(monster_level: int, hero_level: int, elite := false, boss := false) -> float:
	var unit := UNIT_BOSS if boss else (UNIT_ELITE if elite else 1.0)
	return unit * gap_mult(monster_level, hero_level)


## Un monstre est tombé (Monster._on_death) : son XP s'ajoute à la partie si le mode compte et si c'est le camp du héros
## (le joueur, un allié, un effet sans auteur) qui l'a abattu.
static func on_kill(m: Monster, killer: Combatant) -> void:
	if m == null or m.passive or not counts_now():
		return
	if killer != null and is_instance_valid(killer) and killer.team != Combatant.Team.PLAYER:
		return
	_sync_run()
	pending += kill_xp(m.level, level(), m.is_elite, m.is_boss)


static func _sync_run() -> void:
	if _pending_run != Run.started_at:
		_pending_run = Run.started_at
		pending = 0.0


## Fin de partie (Quests.end_run) : verse l'XP de la partie si l'activité [param act] fait monter le niveau ; renvoie [member last].
static func settle(act: String, won: bool) -> Dictionary:
	var counted := act in ACTS and not (act == "survival" and Challenge.active) and _pending_run == Run.started_at
	var xp := roundf(pending * (1.0 + (WIN_BONUS if won else 0.0))) if counted else 0.0
	pending = 0.0
	_pending_run = -1
	last = {}
	if not counted:
		return last
	var from := level()
	var gained := add_xp(xp)
	last = {"run": Run.started_at, "act": act, "won": won, "xp": gained, "from": from, "to": level()}
	return last


## Ajoute [param amount] d'XP au compte (plafonnée au niveau 90) ; renvoie l'XP vraiment ajoutée.
static func add_xp(amount: float) -> float:
	if amount <= 0.0:
		return 0.0
	var before := total()
	var after := minf(before + amount, total_for(MAX_LEVEL))
	if after <= before:
		return 0.0
	Profile.records[KEY] = after
	events.xp_changed.emit(after)
	var a := level_for(before)
	var b := level_for(after)
	if b > a:
		events.level_up.emit(a, b)
	return after - before


# --- bilan -------------------------------------------------------------------------------------
## Ajoute au bilan (ResultsPanel.show_spec) la ligne du niveau de héros de la partie qui vient de finir, une seule fois.
static func decorate(spec: Dictionary) -> Dictionary:
	if last.is_empty() or bool(last.get("shown", false)) or int(last.run) != Run.started_at or float(last.xp) <= 0.0:
		return spec
	last["shown"] = true
	var out := spec.duplicate()
	var gained: Array = (out.get("gained", []) as Array).duplicate()
	gained.push_front(result_row(last))
	out["gained"] = gained
	var up := int(last.to) - int(last.from)
	if up > 0:
		var notes: Array = (out.get("notes", []) as Array).duplicate()
		notes.append("Ton héros passe au niveau %d." % int(last.to))
		out["notes"] = notes
	return out


## Ligne « Gagné » d'un versement : « Niveau de héros 34 → 35 · +1 niveau », sinon « XP de héros · +N ».
static func result_row(r: Dictionary) -> Dictionary:
	var up := int(r.to) - int(r.from)
	var xp := _n(float(r.xp))
	if up > 0:
		return ResultsPanel.row("Niveau de héros %d → %d" % [int(r.from), int(r.to)], "+%d niveau%s" % [up, "x" if up > 1 else ""],
			"+%s XP de héros" % xp, "class")
	var tip := "Niveau %d : encore %s XP" % [int(r.to), _n(xp_left())] if int(r.to) < MAX_LEVEL else "Niveau maximal"
	return ResultsPanel.row("XP de héros", "+" + xp, tip, "class")


# --- migration ---------------------------------------------------------------------------------
## Compte sans niveau de héros (sauvegarde d'avant le lot H1, ou compte neuf) : le niveau de départ, une seule fois.
static func ensure() -> void:
	if Profile.records.has(KEY):
		return
	var lv := start_level()
	Profile.records[KEY] = total_for(lv)
	Profile.records[KEY_START] = lv
	if lv > 1:
		Profile.records[KEY_NOTE] = 1


## Niveau de départ d'un compte existant : max(barème des époques gagnées, 90 avec un donjon Mythique fini ; plus haute
## pièce portée dans le préréglage actif de chaque classe). Un compte neuf part du niveau 1.
static func start_level() -> int:
	var ep := clampi(int(Profile.records.get("epochs_cleared", 0)), 0, MIGRATION.size() - 1)
	var lv := clampi(Profile.best_level, 1, EPOCH0_CAP) if ep == 0 else int(MIGRATION[ep])
	if ep == MIGRATION.size() - 1:
		var heroic := 0
		for e in range(1, MIGRATION.size()):
			heroic = maxi(heroic, Epochs.heroic_best(e))
		lv += heroic  # +1 par rang héroïque fini
	if mythic_done():
		lv = MAX_LEVEL
	return clampi(maxi(lv, highest_worn()), 1, MAX_LEVEL)


## Un donjon (ou un boss de donjon) fini en Mythique.
static func mythic_done() -> bool:
	var suffix := "_%d" % MYTHIC_DIFF
	for k in Profile.records:
		var key := String(k)
		if (key.begins_with("dungeon_") or key.begins_with("dgb_")) and key.ends_with(suffix) and float(Profile.records[k]) > 0.0:
			return true
	return false


## Plus haut niveau parmi les pièces portées (préréglage actif de chaque classe, et l'équipement affiché) ; les pièces
## de départ et celles du Survivant ne comptent pas.
static func highest_worn() -> int:
	var by_uid := {}
	for it in Profile.vault:
		if it is Dictionary and it.has("uid"):
			by_uid[String(it.uid)] = it
	var best := 0
	for cls in Profile.presets:
		var p = Profile.presets[cls]
		if not p is Dictionary or not p.has("sets"):
			continue
		var sets: Array = p.sets
		if sets.is_empty():
			continue
		var s = sets[clampi(int(p.get("active", 0)), 0, sets.size() - 1)]
		if not s is Dictionary:
			continue
		for uid in (s.get("slots", {}) as Dictionary).values():
			best = maxi(best, item_level(by_uid.get(String(uid), {})))
	if not Profile.in_run:
		for slot in Profile.equipped:
			best = maxi(best, item_level(Profile.equipped[slot]))
	return best


## Niveau d'une pièce pour la migration (0 : ne compte pas).
static func item_level(it) -> int:
	if not it is Dictionary or it.is_empty() or it.get("starter", false) or it.get("sv", false):
		return 0
	var lv := int(it.get("level", 0)) if it.has("eden") else int(it.get("plevel", it.get("level", 0)))
	return clampi(lv, 0, MAX_LEVEL)


# --- port des pièces (lot H3) ------------------------------------------------------------------
## Niveau requis si [param item] ne peut pas être porté maintenant, 0 sinon (`Items.required_level` > niveau de héros).
## Le port se vérifie au hub (coffre commun, préréglages : l'équipement de l'Aventure, des activités et du Duel équipé).
## Jamais pendant une partie (Survie, Survivant : les pièces trouvées ne valent que la partie ; elles suivront le niveau
## de héros au lot H4a), ni dans les modes scellés (Survivant, Battle royale : leurs propres pièces).
static func wear_block(item: Dictionary) -> int:
	if item.is_empty() or Profile.in_run or Modes.sealed():
		return 0
	var req := Items.required_level(item)
	return req if req > level() else 0


static func can_wear(item: Dictionary) -> bool:
	return wear_block(item) == 0


## « Niveau 60 requis · tu es niveau 34 » ("" : la pièce se porte).
static func lock_text(item: Dictionary) -> String:
	var req := wear_block(item)
	return "" if req <= 0 else "Niveau %d requis · tu es niveau %d" % [req, level()]


## Ligne de la carte d'objet (BBCode, "" : rien à dire). Une pièce déjà portée au-dessus du niveau (compte d'avant le
## niveau de héros) reste portée : elle est seulement signalée.
static func lock_line(item: Dictionary) -> String:
	var t := lock_text(item)
	if t == "":
		return ""
	if Profile.slot_of(item) != "":
		return "\n\n[color=#ffb070]%s. Déjà portée : elle reste.[/color]" % t
	return "\n\n[color=#ff7a7a][b]%s[/b][/color]" % t


## Message de migration (une fois, au lobby) : "" s'il n'y en a pas (ou plus).
static func take_note() -> String:
	ensure()
	if int(Profile.records.get(KEY_NOTE, 0)) != 1:
		return ""
	Profile.records[KEY_NOTE] = 2
	return "Ton héros est niveau %d. Il garde ce niveau dans toutes les classes." % level()
