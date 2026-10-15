extends Node
## Passe P12 (conception/nuit_15_10/R_P12.md) : autel de cupidité (pacte), autel du géant, Menace (PV des monstres
## vivants, suivants et des boss +20 % par géant vaincu, plafond, insignes), remise à zéro à chaque run.
## godot --headless --path game res://tests/test_p12.tscn

var fails := 0
var world: Node


func check(label: String, ok: bool) -> void:
	print(("OK    " if ok else "ÉCHEC ") + label)
	if not ok:
		fails += 1


func _ready() -> void:
	_test_rules()
	_test_results_line()
	Menace.level = 3  # une run précédente : la nouvelle run doit repartir de zéro
	Menace.pact_maps = 2
	Profile.selected_zone = String(GameData.zones[0].id)
	world = load("res://scenes/world.tscn").instantiate()
	get_tree().root.add_child.call_deferred(world)
	await get_tree().create_timer(6.0).timeout
	check("nouvelle run : Menace et pactes remis à zéro (%d, %d)" % [Menace.level, Menace.pact_maps], Menace.level == 0 and Menace.pact_maps == 0)
	_close_cards()
	var d: RunDirector = world.director
	d.set_process(false)
	_clear()
	d.state = "explore"
	d.time = RunDirector.EARLY_RAMP + 1.0  # montée en puissance du début de carte passée : PV comparables
	var kinds: Array = d.map.stations.map(func(s): return String(s.kind))
	check("2 autels du géant sur la carte (%d)" % kinds.count("giant"), kinds.count("giant") == 2)
	await _test_pact(d)
	await _test_giant(d)
	await _test_boss_and_cap(d)
	_test_rage_refuses(d)
	print("TOUS LES TESTS PASSENT" if fails == 0 else "%d ÉCHEC(S)" % fails)
	get_tree().quit(1 if fails > 0 else 0)


## Règles pures : multiplicateur, plafond, insignes.
func _test_rules() -> void:
	Menace.reset()
	check("Menace 0 : PV ×1", is_equal_approx(Menace.hp_mult(), 1.0) and Menace.mult_text() == "×1")
	check("Menace 1 : « ×1,2 »", Menace.mult_text(1) == "×1,2" and is_equal_approx(Menace.hp_mult(1), 1.2))
	check("plafond : Menace %d = ×%s" % [Menace.MAX, RunDirector.fmt_mult(Menace.hp_mult(Menace.MAX))], is_equal_approx(Menace.hp_mult(Menace.MAX + 3), Menace.hp_mult(Menace.MAX)) and Menace.mult_text(Menace.MAX) == "×2")
	Menace.level = 2
	Menace.pact_maps = 1
	check("insignes : Menace 2 et un pacte sur 2 cartes = ×1,45", is_equal_approx(Menace.insignia_mult(2), 1.45))
	check("insignes ajoutés retenus pour le bilan (100 -> %d)" % Menace.add_insignia(100, 2), Menace.add_insignia(100, 2) == 145 and Menace.insignia_extra == 45)
	Menace.reset()
	check("remise à zéro", Menace.level == 0 and Menace.pact_maps == 0 and Menace.insignia_extra == 0 and Menace.giants_killed == 0)


## Bilan : la part « Menace et pacte » a sa ligne, les lignes font le total.
func _test_results_line() -> void:
	var was := [Run.insignia_parts, Run.insignia_gain, Run.fortune_insignia, Run.heroic_rank]
	Menace.reset()
	Menace.level = 2
	Menace.pact_maps = 1
	Run.insignia_parts = {"participation": 25, "maps": 0, "fights": 0, "victory": 0}
	Run.fortune_insignia = 0
	Run.heroic_rank = 0
	Run.insignia_gain = Menace.add_insignia(25, 1)
	var lines := ResultsScreen.insignia_lines()
	var total := 0
	for l in lines:
		total += int(l[1])
	var labels: Array = lines.map(func(l): return String(l[0]))
	check("bilan : %s = %d" % [lines, Run.insignia_gain], total == Run.insignia_gain and "Menace ×1,4 et pacte" in labels and not "Défi de maîtrise" in labels)
	Run.insignia_parts = was[0]
	Run.insignia_gain = was[1]
	Run.fortune_insignia = was[2]
	Run.heroic_rank = was[3]
	Menace.reset()


## Pacte : monstres déjà là et suivants plus forts, état au HUD.
func _test_pact(d: RunDirector) -> void:
	var id := d._pick_monster(5)
	var before := d._spawn_monster(id, d._near_player(9.0), 5)
	var hp0 := before.max_hp
	var atk0 := before.atk
	_use("greed")
	check("pacte pris : actif, une carte sous pacte", d.greed and Menace.pact_maps == 1)
	check("pacte : un monstre déjà là prend +25 %% (%.0f -> %.0f PV)" % [hp0, before.max_hp], is_equal_approx(before.max_hp, hp0 * RunDirector.GREED_MONSTERS) and is_equal_approx(before.atk, atk0 * RunDirector.GREED_MONSTERS))
	var after := d._spawn_monster(id, d._near_player(9.0), 5)
	check("pacte : un nouveau monstre aussi, une seule fois (%.0f PV)" % after.max_hp, is_equal_approx(after.max_hp, hp0 * RunDirector.GREED_MONSTERS))
	var badge := _badge()
	badge.refresh()
	check("HUD : pastille « Pacte » visible", badge != null and badge.visible and badge._pact.visible and not badge._menace.visible)
	check("HUD : infobulle du pacte, sans pourcentage dans le texte visible", badge.tooltip_text.contains("Pacte") and not badge._pact.text.contains("%"))
	check("journal : pacte et Menace dans la ligne de carte", d._journal_context().get("pact") == true and d._journal_context().has("menace"))
	_clear()
	d.greed = false  # la suite mesure la Menace seule
	await get_tree().process_frame


## Géant : bien plus fort qu'une élite, grand, coups plafonnés ; vaincu, carte, or et Menace +1 sur tout.
func _test_giant(d: RunDirector) -> void:
	var lvl := d._monster_level(2)
	var id := d._pick_monster(5)
	var ref := d._spawn_monster(id, d._near_player(14.0), 5)  # témoin d'avant la Menace
	var ref_hp := ref.max_hp
	var elite: Monster = d._spawn_monster(int(d._elites[0]), d._near_player(16.0), lvl) if not d._elites.is_empty() else null
	_use("giant")
	var giants := get_tree().get_nodes_in_group("monsters").filter(func(m): return m is GiantMonster)
	check("autel du géant : un géant surgit (%d)" % giants.size(), giants.size() == 1)
	if giants.is_empty():
		return
	var g: GiantMonster = giants[0]
	await get_tree().process_frame
	check("géant : « %s », élite, %.1f m de rayon" % [g.display_name, g.radius], g.display_name.begins_with("Géant · ") and g.is_elite and g.radius >= 1.2)
	if elite:
		check("géant : PV %.0f ≥ 6 élites (%.0f)" % [g.max_hp, elite.max_hp], g.max_hp >= elite.max_hp * 6.0)
		check("géant : coup %.0f > élite %.0f" % [g.atk, elite.atk], g.atk > elite.atk)
	check("géant : expérience bornée (%d ≤ 4 élites)" % g.xp_reward, elite == null or g.xp_reward <= elite.xp_reward * 4)
	var player: Player = world.player
	g._player = player
	var dmgs: Array = []
	for i in 4:
		g._start_attack()
		if is_instance_valid(g._telegraph):
			dmgs.append(g._telegraph.damage)
			g._telegraph.queue_free()
		g._set_state("chase")
	var cap := player.max_hp * GiantMonster.HIT_CAP
	check("géant : 4 attaques annoncées, aucune au-delà de %.0f (%s)" % [cap, dmgs.map(func(x): return roundi(x))], dmgs.size() == 4 and dmgs.all(func(x): return x <= cap + 0.01))
	var gold0 := Run.gold
	var alive := d._spawn_monster(id, d._near_player(12.0), 5)
	var alive_hp := alive.max_hp
	g.take_damage(g.max_hp * 10.0 + 1e6, player)
	await get_tree().process_frame
	check("géant vaincu : Menace 1 (%s)" % Menace.mult_text(), Menace.level == 1 and Menace.giants_killed == 1)
	check("géant vaincu : un choix de cartes", world.cards.is_open() or not world.cards._queue.is_empty())
	check("géant vaincu : de l'or (+%d)" % (Run.gold - gold0), Run.gold - gold0 >= GiantAltar.GOLD_BASE)
	check("Menace : un monstre vivant prend ×1,2 (%.0f -> %.0f)" % [alive_hp, alive.max_hp], is_equal_approx(alive.max_hp, alive_hp * 1.2))
	var next := d._spawn_monster(id, d._near_player(12.0), 5)
	check("Menace : un monstre suivant naît ×1,2 (%.0f vs %.0f)" % [next.max_hp, ref_hp], is_equal_approx(next.max_hp, ref_hp * 1.2))
	var badge := _badge()
	badge.refresh()
	check("HUD : « %s »" % badge._menace.text, badge.visible and badge._menace.visible and badge._menace.text.ends_with("Menace ×1,2"))
	check("journal : %s" % [d._journal_context()], int(d._journal_context().get("menace", -1)) == 1 and int(d._journal_context().get("giants_killed", 0)) == 1)
	_close_cards()
	_clear()


## Boss : ses PV × la Menace (après son réglage), pas deux fois ; plafond de la Menace.
func _test_boss_and_cap(d: RunDirector) -> void:
	var id := d._pick_monster(5)
	var keep := Menace.level
	Menace.level = 0
	var b0 := d._spawn_monster(id, d._near_player(10.0), 5, true)
	await get_tree().process_frame
	var hp0 := b0.max_hp
	Menace.level = keep
	var b1 := d._spawn_monster(id, d._near_player(10.0), 5, true)
	b1.max_hp = hp0  # PV fixes posés juste après la création (passe P11) : la Menace s'applique après
	b1.hp = hp0
	await get_tree().process_frame
	await get_tree().process_frame
	check("boss : PV × Menace après son réglage (%.0f -> %.0f)" % [hp0, b1.max_hp], is_equal_approx(b1.max_hp, hp0 * 1.2))
	while Menace.level < Menace.MAX:
		Menace.raise(get_tree())
	var up := Menace.raise(get_tree())
	check("plafond : Menace %d, un géant de plus ne la monte plus" % Menace.level, not up and Menace.level == Menace.MAX)
	check("plafond : boss ×%s au plus" % RunDirector.fmt_mult(Menace.hp_mult()), is_equal_approx(b1.max_hp, hp0 * Menace.hp_mult()))
	_clear()


## En rage, l'autel du géant se tait (et reste utilisable plus tard : il n'est pas consommé).
func _test_rage_refuses(d: RunDirector) -> void:
	d.state = "rage"
	var n0 := get_tree().get_nodes_in_group("monsters").size()
	var altar: Interactable = null
	for it in d.map.interactables:
		if is_instance_valid(it) and it.kind == "giant" and not it.used:
			altar = it
	if altar == null:
		check("un 2e autel du géant libre", false)
		return
	d._interact(altar)
	check("rage : pas de géant, autel intact", not altar.used and get_tree().get_nodes_in_group("monsters").filter(func(m): return m is GiantMonster).is_empty() and get_tree().get_nodes_in_group("monsters").size() == n0)
	d.state = "explore"


func _badge() -> MenaceBadge:
	for n in world.hud.find_children("*", "MenaceBadge", true, false):
		return n
	return null


func _use(kind: String) -> void:
	for it in world.director.map.interactables:
		if is_instance_valid(it) and it.kind == kind and not it.used:
			world.director._interact(it)
			return
	check("lieu %s présent" % kind, false)


func _clear() -> void:
	for m in get_tree().get_nodes_in_group("monsters"):
		m.remove_from_group("monsters")
		m.queue_free()


func _close_cards() -> void:
	world.cards._queue.clear()
	world.cards._show_next()
