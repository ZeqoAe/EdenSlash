class_name RunJournal
extends RefCounted
## Journal de run (conception, lot 3) : une ligne JSON par carte jouée dans `user://journal.jsonl`
## (`journal_test.jsonl` pour les tests), hors git. Il ne change rien au jeu : il sert à régler les
## époques et l'économie d'après des écarts chiffrés entre styles de jeu, pas au ressenti.
##
## Mesures par carte : style (coffres ouverts, temps en combat), or par source et par usage, puissance
## au boss (niveau, cartes, trophées, DPS sur les 10 premières secondes), pression (dégâts subis par
## minute, plus gros coup), résistance des monstres (temps pour tuer), contexte (mode, époque, classe,
## aide au combat, version, issue).
##
## Style : indice = part des coffres ouverts − part du temps en combat ; « coffres » au-dessus de
## +0,2, « farm » en dessous de −0,2, sinon « mixte ».

const COMBAT_WINDOW := 3.0  # un monstre touché depuis moins de 3 s : on est en combat
const BOSS_WINDOW := 10.0
const MIN_MAP_TIME := 5.0  # en dessous, la carte n'est pas journalisée (retour immédiat au menu)

static var counters := {}
static var context: Callable  # donné par le directeur : coffres posés / ouverts, sites…
static var _map_ms := 0
static var _since_hit := 99.0
static var _time := 0.0
static var _combat := 0.0
static var _dist := 0.0
static var _last_pos := Vector3.INF
static var _boss_t0 := -1.0
static var _last_source := ""
static var last_line: Dictionary = {}  # dernière ligne écrite (tests)


static func path() -> String:
	return "user://journal_test.jsonl" if Settings.save_path == Settings.TEST_SAVE_PATH else "user://journal.jsonl"


static func mode_name() -> String:
	if Duel.active:
		return "duel"
	if Tower.active:
		return "tower"
	if Training.active:
		return "training"
	return "survival" if Run.survival else "run"


## Nouvelle run : compteurs de la carte à zéro.
static func begin_run() -> void:
	begin_map()


static func begin_map() -> void:
	counters = {}
	_map_ms = Time.get_ticks_msec()
	_since_hit = 99.0
	_time = 0.0
	_combat = 0.0
	_dist = 0.0
	_last_pos = Vector3.INF
	_boss_t0 = -1.0
	_last_source = ""


static func add(key: String, amount := 1.0) -> void:
	counters[key] = float(counters.get(key, 0.0)) + amount


static func gold_in(amount: int, source: String) -> void:
	add("gold_in_" + source, amount)


static func gold_out(amount: int, usage: String) -> void:
	add("gold_out_" + usage, amount)


## Une image de jeu : temps de la carte, temps en combat, distance parcourue.
static func tick(delta: float, pos: Vector3) -> void:
	if not Run.active or Training.active:
		return
	_time += delta
	_since_hit += delta
	if _since_hit < COMBAT_WINDOW:
		_combat += delta
	if _last_pos != Vector3.INF:
		_dist += Vector2(pos.x - _last_pos.x, pos.z - _last_pos.z).length()
	_last_pos = pos


## Coup porté par le héros du joueur au monstre [param m].
static func player_hit(m: Combatant, dmg: float) -> void:
	if not Run.active or Training.active or Duel.active:
		return
	_since_hit = 0.0
	if not m.has_meta("jr_t0"):
		m.set_meta("jr_t0", _time)
	m.set_meta("jr_hits", int(m.get_meta("jr_hits", 0)) + 1)
	if m.get("is_boss"):
		if _boss_t0 < 0.0:
			_boss_t0 = _time
		if _time - _boss_t0 <= BOSS_WINDOW:
			add("boss_dmg_10s", dmg)


static func monster_died(m: Combatant) -> void:
	if not Run.active or Training.active or Duel.active or not m.has_meta("jr_t0"):
		return
	var kind := "boss" if m.get("is_boss") else ("elite" if m.get("is_elite") else "normal")
	add("ttk_%s_sum" % kind, _time - float(m.get_meta("jr_t0")))
	add("ttk_%s_n" % kind)
	if kind == "normal":
		add("hits_normal_sum", int(m.get_meta("jr_hits", 0)))
	if kind == "boss":
		counters["boss_ttk"] = _time - float(m.get_meta("jr_t0"))


## Dégâts reçus par le héros du joueur.
static func damage_taken(amount: float, source: Combatant, max_hp: float) -> void:
	if not Run.active or Training.active or Duel.active:
		return
	var kind := "autre"
	if source != null:
		kind = "boss" if source.get("is_boss") else ("elite" if source.get("is_elite") else "normal")
		_last_source = String(source.get("display_name")) if source.get("display_name") != null else kind
	add("dmg_taken_" + kind, amount)
	counters["max_hit_frac"] = maxf(float(counters.get("max_hit_frac", 0.0)), amount / maxf(max_hp, 1.0))


static func _avg(sum_key: String, n_key: String) -> float:
	var n := float(counters.get(n_key, 0.0))
	return snappedf(float(counters.get(sum_key, 0.0)) / n, 0.01) if n > 0.0 else -1.0


## Ferme la carte en cours et écrit sa ligne. [param result] : etape, victoire, defaite, abandon,
## extraction. [param extra] : champs propres au mode (étage de la Tour, manches du Duel…).
static func end_map(result: String, extra := {}) -> void:
	if Training.active or _time < MIN_MAP_TIME:
		begin_map()
		return
	var ctx: Dictionary = context.call() if context.is_valid() else {}
	var minutes := maxf(_time / 60.0, 0.01)
	var opened := float(ctx.get("chests_opened", 0))
	var total := float(ctx.get("chests_total", 0))
	var chest_share := opened / total if total > 0.0 else 0.0
	var combat_share := _combat / maxf(_time, 0.01)
	var idx := chest_share - combat_share
	var style := "coffres" if idx > 0.2 else ("farm" if idx < -0.2 else "mixte")
	var taken := 0.0
	for k in ["normal", "elite", "boss", "autre"]:
		taken += float(counters.get("dmg_taken_" + k, 0.0))
	var line := {
		"v": Version.NUMBER, "mode": mode_name(), "result": result, "class": Run.class_id,
		"epoch": Run.epoch if Run.survival else 0, "stage": Run.stage, "zone": Run.zone_id,
		"assist": Settings.assist_level(), "auto": Settings.assist_level() in ["relax", "bot"],
		"time": snappedf(_time, 0.1), "combat_share": snappedf(combat_share, 0.01),
		"chest_share": snappedf(chest_share, 0.01), "style_index": snappedf(idx, 0.01), "style": style,
		"dist": roundi(_dist), "level": Run.max_level, "cards": Run.passives.size() + Run.skills.size(),
		"trophies": Run.trophies.size(), "anvil": Run.anvil_stage, "kills": Run.kills,
		"dmg_taken_min": snappedf(taken / minutes, 0.1), "max_hit_frac": snappedf(float(counters.get("max_hit_frac", 0.0)), 0.001),
		"dps_boss_10s": snappedf(float(counters.get("boss_dmg_10s", 0.0)) / BOSS_WINDOW, 0.1),
		"ttk_normal": _avg("ttk_normal_sum", "ttk_normal_n"), "ttk_elite": _avg("ttk_elite_sum", "ttk_elite_n"),
		"ttk_boss": snappedf(float(counters.get("boss_ttk", -1.0)), 0.1), "hits_normal": _avg("hits_normal_sum", "ttk_normal_n"),
		"gold_left": Profile.gold, "keys_left": Profile.keys, "death": _last_source if result == "defaite" else "",
		"counters": counters.duplicate(),
	}
	line.merge(ctx, true)
	line.merge(extra, true)
	last_line = line
	var f := FileAccess.open(path(), FileAccess.READ_WRITE if FileAccess.file_exists(path()) else FileAccess.WRITE)
	if f:
		f.seek_end()
		f.store_line(JSON.stringify(line))
		f.close()
	begin_map()
