extends Node
## Lot MODE-0 : socle des modes d'équipes (TeamMatch) et API unique de mode (Modes.kind / sealed / is_pvp / team_match /
## hero_match). Prouve que les modes d'avant ne changent pas (table de vérité complète des drapeaux contre les anciennes
## formules, ciblage chacun pour soi identique), puis teste équipes, couleurs, arènes, manches, élimination, spectateur,
## résultats, profil de règles, et une partie réelle dans world.tscn avec un directeur de démonstration (deux arènes au
## même endroit : aucun coup ne passe de l'une à l'autre).
## godot --headless --path game res://tests/test_mode0.tscn

var fails := 0


func check(label: String, ok: bool) -> void:
	print(("OK    " if ok else "ÉCHEC ") + label)
	if not ok:
		fails += 1


func _ready() -> void:
	Settings.reset_all()
	_legacy_truth_table()
	_registry_and_api()
	await _targeting()
	_rounds_and_results()
	_palette()
	await _sigil()
	await _world_match()
	print("TOUT EST OK (0 échec(s))" if fails == 0 else "ÉCHECS : %d" % fails)
	get_tree().quit(fails)


# --- 1. table de vérité : rien ne change hors mode d'équipes -----------------------------------

func _legacy_current() -> String:
	if AutochessDirector.active:
		return "autochess"
	if Royale.active:
		return "royale"
	if Duel.active:
		return "duel"
	if Tower.active:
		return "dungeon" if Tower.is_dungeon() else "tower"
	if Training.active:
		return "training"
	if Run.active:
		if Survivor.active:
			return "survivor"
		return "survival" if Run.survival else "run"
	return "menu"


func _legacy_profile() -> String:
	if Siege.ffa:
		return "siege"
	var m := _legacy_current()
	if m == "duel":
		if Duel.mode in ["arena2", "arena3", "gauntlet"]:
			return Duel.mode
		return "duel_a" if Duel.bare else "duel_b"
	return m if ModeRules.PROFILES.has(m) else ""


func _set_flags(bits: int) -> void:
	AutochessDirector.active = bits & 1 != 0
	Royale.active = bits & 2 != 0
	Duel.active = bits & 4 != 0
	Tower.active = bits & 8 != 0
	Training.active = bits & 16 != 0
	Run.active = bits & 32 != 0
	Survivor.active = bits & 64 != 0
	Run.survival = bits & 128 != 0
	Siege.ffa = bits & 256 != 0


func _legacy_truth_table() -> void:
	var keep := [Duel.mode, Duel.bare, Duel.team_allies.duplicate()]
	var bad := {}
	var n := 0
	for dm in ["free", "league", "arena2", "arena3", "gauntlet"]:
		Duel.mode = dm
		Duel.team_allies = ["cleric"] if dm.begins_with("arena") else []
		for bare in [false, true]:
			Duel.bare = bare
			for bits in 512:
				_set_flags(bits)
				n += 1
				var cur := _legacy_current()
				if Modes.current() != cur:
					bad["current"] = bad.get("current", 0) + 1
				if Modes.is_pvp() != (cur in ["duel", "royale"] or Siege.ffa):
					bad["is_pvp"] = bad.get("is_pvp", 0) + 1
				if PvpCaps.active() != Modes.is_pvp():
					bad["PvpCaps.active"] = bad.get("PvpCaps.active", 0) + 1
				if Modes.sealed() != (Survivor.active or Royale.active or AutochessDirector.active):
					bad["sealed"] = bad.get("sealed", 0) + 1
				if ModeRules.profile_name() != _legacy_profile():
					bad["profile_name"] = bad.get("profile_name", 0) + 1
				if Modes.hero_match() != (Duel.active or Royale.active):
					bad["hero_match"] = bad.get("hero_match", 0) + 1
				if Potions.allowed() != (Run.active and not Duel.active and not Siege.ffa):
					bad["Potions.allowed"] = bad.get("Potions.allowed", 0) + 1
				if Modes.team_match():
					bad["team_match"] = bad.get("team_match", 0) + 1
	_set_flags(0)
	Duel.mode = keep[0]
	Duel.bare = keep[1]
	Duel.team_allies = keep[2]
	check("table de vérité : %d états des drapeaux, current / is_pvp / sealed / profil / hero_match / potions identiques %s"
		% [n, str(bad) if not bad.is_empty() else ""], bad.is_empty())
	# types des modes d'avant
	check("type : menu au menu", Modes.kind() == "menu")
	Duel.active = true
	check("type : duel en duel libre", Modes.kind() == "duel")
	Duel.team_allies = ["cleric"]
	check("type : équipes en Arène", Modes.kind() == "teams")
	Duel.team_allies = []
	Duel.active = false
	Royale.active = true
	check("type : chacun pour soi au Battle royale", Modes.kind() == "ffa")
	Royale.active = false
	AutochessDirector.active = true
	check("type : plateau à L'Échiquier", Modes.kind() == "board")
	AutochessDirector.active = false
	Run.active = true
	Run.survival = true
	check("type : pve en Survie", Modes.kind() == "pve")
	_set_flags(0)
	check("hors partie : TeamMatch inactif, aucune équipe", not TeamMatch.active and TeamMatch.teams.is_empty() and TeamMatch.mode == "")


# --- 2. registre, API de mode, profil de règles ------------------------------------------------

func _registry_and_api() -> void:
	check("les 3 modes déclarés", TeamMatch.is_mode("colisee") and TeamMatch.is_mode("moba") and TeamMatch.is_mode("assault"))
	check("types : Colisée = équipes, Deux Voies et Assaut = objectif", TeamMatch.spec_of("colisee").kind == "teams"
		and TeamMatch.spec_of("moba").kind == "objective" and TeamMatch.spec_of("assault").kind == "objective")
	check("tous scellés par défaut", TeamMatch.ids().all(func(id): return TeamMatch.sealed_id(id)))
	Modes.forced = "colisee"
	check("Modes.forced = un mode d'équipes : scellé", Modes.sealed())
	Modes.forced = ""
	TeamMatch.begin("colisee")
	check("Colisée : 6 équipes, phase prep", TeamMatch.team_count() == 6 and TeamMatch.phase == "prep")
	check("Modes.current() = colisee, type équipes", Modes.current() == "colisee" and Modes.kind() == "teams")
	check("scellé, JcJ, partie d'équipes, partie entre héros", Modes.sealed() and Modes.is_pvp() and PvpCaps.active()
		and Modes.team_match() and Modes.hero_match())
	check("ne pose ni Duel.active ni Royale.active", not Duel.active and not Royale.active)
	check("profil pas encore enregistré : chiffres du duel", ModeRules.profile_name() == ""
		and is_equal_approx(PvpCaps.damage_scale(), float(ModeRules.PVP.dmg_scale)))
	check("un nom de PROFILES ne se remplace pas", not ModeRules.register("duel_a", {"dmg_scale": 1.0}))
	check("profil enregistré : lu par ModeRules et PvpCaps", ModeRules.register("colisee", {"dmg_scale": 0.02, "hit_cap": 0.15})
		and ModeRules.profile_name() == "colisee" and is_equal_approx(PvpCaps.damage_scale(), 0.02))
	DevEdits.data["modes"] = {"colisee": {"dmg_scale": 0.05}}
	check("mode dev : le profil enregistré se surcharge aussi", is_equal_approx(PvpCaps.damage_scale(), 0.05))
	DevEdits.data["modes"] = {}
	ModeRules._extra.erase("colisee")
	Run.active = true
	check("options par défaut : ni potions, ni cartes de niveau, ni journal, ni sauvegarde", not Potions.allowed()
		and not TeamMatch.allows("level_cards") and not TeamMatch.allows("journal") and not TeamMatch.allows("save"))
	check("activité des quêtes : colisee", Quests.current_act() == "colisee")
	Run.active = false
	TeamMatch.begin("moba")
	check("Deux Voies : 2 équipes, type objectif, azur contre braise", TeamMatch.team_count() == 2 and Modes.kind() == "objective"
		and TeamMatch.team(0).key == "azur" and TeamMatch.team(1).key == "braise")
	TeamMatch.begin("assault", -1, {"rounds_to_win": 4, "potions": true})
	check("options de partie : premier à 4, potions permises", int(TeamMatch.spec.rounds_to_win) == 4 and TeamMatch.allows("potions"))
	TeamMatch.end()
	check("fin : plus de mode d'équipes", Modes.current() == "menu" and not Modes.sealed() and not Modes.is_pvp())
	TeamMatch.register("mode0_x", {"kind": "ffa", "sealed": false, "pvp": false})
	TeamMatch.begin("mode0_x", 3)
	check("mode enregistré à l'exécution : non scellé, sans JcJ", Modes.current() == "mode0_x" and not Modes.sealed()
		and not Modes.is_pvp() and Modes.kind() == "ffa")
	TeamMatch.end()
	TeamMatch.unregister("mode0_x")


# --- 3. camps, arènes, ciblage -----------------------------------------------------------------

func _dummy(at: Vector3) -> Combatant:
	var c := Combatant.new()
	add_child(c)
	c.set_physics_process(false)
	c.position = at
	return c


func _legacy_ffa_foes(source: Combatant) -> Array:
	var out: Array = []
	for n in get_tree().get_nodes_in_group("ffa"):
		var c := n as Combatant
		if c != null and not c.is_dead and c != source and c.ffa_id >= 0 and c.ffa_id != source.ffa_id:
			out.append(c)
	return out


func _targeting() -> void:
	# chacun pour soi d'avant (Battle royale, Siège) : identiques à l'ancienne formule, arena_id = -1 partout
	var br: Array = []
	for i in 6:
		var c := _dummy(Vector3(i * 2.0, 0, 0))
		c.set_ffa(i if i < 5 else 90)  # (90 : gardien du Battle royale)
		br.append(c)
	br[2].is_dead = true
	await get_tree().process_frame
	var same := true
	for c in br:
		same = same and Combatant.ffa_foes(get_tree(), c) == _legacy_ffa_foes(c) and Combatant.hostile_targets(get_tree(), c) == _legacy_ffa_foes(c)
	check("chacun pour soi d'avant : ffa_foes et hostile_targets inchangés", same)
	for c in br:
		c.queue_free()
	await get_tree().process_frame
	# modes d'équipes : 4 équipes de 2, équipes 0-1 dans l'arène 0, 2-3 dans l'arène 1, AU MÊME ENDROIT
	TeamMatch.begin("colisee", 4)
	var by_team: Array = [[], [], [], []]
	for t in 4:
		for k in 2:
			var c := _dummy(Vector3(k * 2.0, 0, 0))
			TeamMatch.add(c, t, 0 if t < 2 else 1)
			by_team[t].append(c)
	await get_tree().process_frame
	var a0: Combatant = by_team[0][0]
	var foes0 := Combatant.ffa_foes(get_tree(), a0)
	check("équipe 0 : ses adversaires = les 2 de l'équipe 1 (même arène)", foes0.size() == 2 and foes0.all(func(c): return c in by_team[1]))
	check("aucune cible dans l'autre arène (hostile_targets, hostile_heroes)", Combatant.hostile_targets(get_tree(), a0).all(func(c): return c.arena_id == 0)
		and Combatant.hostile_heroes(get_tree(), a0).all(func(c): return c.arena_id == 0))
	var b0: Combatant = by_team[2][0]
	check("équipe 2 (arène 1) : ses adversaires = l'équipe 3", Combatant.ffa_foes(get_tree(), b0).all(func(c): return c in by_team[3]))
	check("équipiers : allies, same_team, team_of", TeamMatch.allies(a0).size() == 2 and TeamMatch.same_team(a0, by_team[0][1])
		and not TeamMatch.same_team(a0, by_team[1][0]) and TeamMatch.team_of(b0) == 2)
	check("same_arena : -1 partout, sinon égalité", Combatant.same_arena(a0, by_team[1][0]) and not Combatant.same_arena(a0, b0))
	# camp des héros (alliés du joueur, groupe « heroes ») : filtre d'arène aussi
	var mon := _dummy(Vector3.ZERO)
	mon.arena_id = 1
	for h in [a0, b0]:
		h.team = Combatant.Team.PLAYER
		h.add_to_group("heroes")
	check("hostile_heroes d'un monstre d'arène : seulement les héros de son arène", Combatant.hostile_heroes(get_tree(), mon) == [b0])
	mon.arena_id = -1
	check("monstre sans arène : tous les héros (comme avant)", Combatant.hostile_heroes(get_tree(), mon).size() == 2)
	by_team[1][0].is_dead = true
	check("vivants : alive_count, wiped", TeamMatch.alive_count(1) == 1 and not TeamMatch.wiped(1) and TeamMatch.alive_count(1, 1) == 0)
	TeamMatch.end()
	check("fin : camps et arènes rendus", not a0.is_in_group("ffa") and a0.ffa_id == -1 and a0.arena_id == -1 and b0.arena_id == -1)
	for t in 4:
		for c in by_team[t]:
			c.queue_free()
	mon.queue_free()
	await get_tree().process_frame


# --- 4. manches, élimination, classement, spectateur, résultats --------------------------------

func _rounds_and_results() -> void:
	TeamMatch.begin("colisee")
	var phases: Array = []
	var outs: Array = []
	var on_phase := func(p): phases.append(p)
	var on_out := func(t, pl): outs.append([t, pl])
	TeamMatch.bus.phase_changed.connect(on_phase)
	TeamMatch.bus.team_out.connect(on_out)
	check("manche 1", TeamMatch.start_round() == 1)
	TeamMatch.set_phase("fight")
	TeamMatch.end_round(2, {"note": "test"})
	check("fin de manche : phase recap, manche gagnée comptée", TeamMatch.phase == "recap" and TeamMatch.round_wins(2) == 1
		and TeamMatch.round_log.size() == 1 and phases == ["fight", "recap"])
	check("élimination : 6e, puis 5e", TeamMatch.eliminate(5) == 6 and TeamMatch.eliminate(1) == 5 and TeamMatch.eliminate(1) == 0)
	TeamMatch.eliminate(3)
	TeamMatch.player_team = 0
	check("joueur 3e : moitié haute = victoire (win_places 3)", TeamMatch.eliminate(0) == 3 and bool(TeamMatch.result().won))
	check("avant-dernière éliminée : 2e", TeamMatch.eliminate(4) == 2)
	check("dernière équipe en lice : 1re place automatique", TeamMatch.place_of(2) == 1 and TeamMatch.teams_in() == [2])
	var st := TeamMatch.standing()
	check("classement : %s" % str(st), st == [2, 4, 0, 3, 1, 5])
	var res := TeamMatch.result()
	check("bilan : place 3, 6 lignes avec nom, couleur et motif", int(res.place) == 3 and (res.teams as Array).size() == 6
		and String(res.teams[0].name) != "" and String(res.teams[0].motif) != "" and bool(res.teams[2].player))
	check("signaux d'élimination : %s" % str(outs), outs.size() == 5 and outs[0] == [5, 6] and outs[-1] == [4, 2])
	TeamMatch.bus.phase_changed.disconnect(on_phase)
	TeamMatch.bus.team_out.disconnect(on_out)
	TeamMatch.end()
	# fin sans élimination (objectif) : par manches gagnées puis score
	TeamMatch.begin("assault")
	TeamMatch.add_score(0, 5.0)
	TeamMatch.end_round(1)
	TeamMatch.end_round(1)
	TeamMatch.finish()
	check("fin au temps : l'équipe qui a le plus de manches gagne", TeamMatch.place_of(1) == 1 and TeamMatch.place_of(0) == 2
		and TeamMatch.phase == "done" and not bool(TeamMatch.result().won))
	TeamMatch.end()
	TeamMatch.begin("assault", -1, {"rounds_to_win": 2})
	TeamMatch.end_round(0)
	check("premier à 2 : pas encore", TeamMatch.round_winner() == -1)
	TeamMatch.end_round(0)
	check("premier à 2 : l'équipe 0", TeamMatch.round_winner() == 0)
	TeamMatch.end()


# --- 5. palette d'équipes (jetons) -------------------------------------------------------------

func _palette() -> void:
	var order: Array = UiTheme.tok("couleur.equipe.ordre", [])
	check("au moins 8 couleurs d'équipe dans les jetons", order.size() >= 8)
	var cols := {}
	var motifs := {}
	for i in order.size():
		var k := String(order[i])
		var tones_ok := true
		for tone in ["clair", "base", "fonce"]:
			tones_ok = tones_ok and UiTheme.color("equipe.%s.%s" % [k, tone], Color.MAGENTA) != Color.MAGENTA
		check("jetons couleur.equipe.%s : clair, base, foncé" % k, tones_ok)
		cols[UiTheme.color("equipe.%s.base" % k).to_html()] = true
		motifs[String(UiTheme.tok("couleur.equipe.%s.motif" % k, ""))] = true
		check("couleur %d de la partie = jeton %s" % [i, k], TeamMatch.color(i) == UiTheme.color("equipe.%s.base" % k))
	check("8 couleurs et 8 motifs différents", cols.size() == order.size() and motifs.size() == order.size() and not motifs.has(""))
	check("motifs connus du blason", motifs.keys().all(func(m): return m in TeamSigil.MOTIFS))
	check("couleurs de la DA gardées (bonbons inchangés)", UiTheme.color("bonbon.lagon.base").to_html(false) == "22b8f0"
		and UiTheme.color("bonbon.pomme.base").to_html(false) == "8fd62e" and UiTheme.color("bonbon.fraise.base").to_html(false) == "ff4d6d"
		and UiTheme.color("bonbon.soleil.base").to_html(false) == "ffc928")
	TeamMatch.begin("colisee", 2)
	var me := Combatant.new()
	var other := Combatant.new()
	add_child(me)
	add_child(other)
	TeamMatch.add(me, 0)
	TeamMatch.add(other, 1)
	check("barres de vie : pomme (équipe du joueur) / fraise (adversaire), jamais la couleur d'équipe",
		TeamMatch.bar_color(me) == UiTheme.color("bonbon.pomme.base") and TeamMatch.bar_color(other) == UiTheme.color("bonbon.fraise.base"))
	TeamMatch.end()
	me.queue_free()
	other.queue_free()


func _sigil() -> void:
	var box := HBoxContainer.new()
	add_child(box)
	for i in 8:
		box.add_child(TeamSigil.make(i, 32))
	await get_tree().process_frame
	await get_tree().process_frame
	check("blasons : 8 motifs dessinés", box.get_child_count() == 8 and TeamSigil.shape("etoile", Vector2.ZERO, 10.0).size() == 10)
	box.queue_free()


# --- 6. partie réelle : world.tscn + directeur de démonstration --------------------------------

func _world_match() -> void:
	Profile.selected_class = "warrior"
	Run.start("warrior")
	Run.zone_id = Duel.ZONE
	TeamMatch.register("mode0_demo", {"name": "Démonstration", "kind": "teams", "teams": 4, "rules": "mode0_demo",
		"director": "res://tests/mode0_demo_director.gd"})
	ModeRules.register("mode0_demo", ModeRules.PVP_A3)
	TeamMatch.begin("mode0_demo")
	var world: Node = load("res://scenes/world.tscn").instantiate()
	get_tree().root.add_child.call_deferred(world)
	await _until(func(): return world.is_inside_tree() and world.get("director") != null and is_instance_valid(world.director.team), 600)
	var dd: Node = world.director.team
	check("directeur du mode monté par RunDirector (état « team »)", is_instance_valid(dd) and world.director.state == "team"
		and TeamMatch.director == dd)
	await _until(func(): return world.director.map != null and world.director.map._region.navigation_mesh != null, 3600)
	check("carte : maillage de navigation posé", world.director.map != null and world.director.map._region.navigation_mesh != null)
	check("aucune carte de compétence offerte au départ", not world.cards.is_open())
	check("profil de règles du mode", ModeRules.profile_name() == "mode0_demo" and is_equal_approx(PvpCaps.damage_scale(), 0.024))
	var foreign := get_tree().get_nodes_in_group("monsters").filter(func(m): return not m in dd.heroes)
	check("aucun monstre de la Survie", foreign.is_empty())
	await _frames(720)  # 12 s de combat
	var cross := 0
	var mates := 0
	var inside := 0
	for h in dd.hits:
		var v: Combatant = h[0]
		var s: Combatant = h[1]
		if not is_instance_valid(v) or not is_instance_valid(s):
			continue
		if not Combatant.same_arena(v, s):
			cross += 1
		elif TeamMatch.same_team(v, s) and v != s:
			mates += 1
		else:
			inside += 1
	print("[mode0] coups relevés : %d dans l'arène, %d entre arènes, %d entre équipiers" % [inside, cross, mates])
	check("des coups dans chaque arène", inside > 0)
	check("aucun coup d'une arène à l'autre (héros au même endroit)", cross == 0)
	check("aucun coup entre équipiers", mates == 0)
	var wrong := 0
	for r in dd.heroes:
		if is_instance_valid(r) and is_instance_valid(r._player) and not (Combatant.same_arena(r, r._player) and not TeamMatch.same_team(r, r._player)):
			wrong += 1
	check("cibles des IA : un adversaire de leur arène", wrong == 0)
	world.player.died.emit(world.player, null)
	await get_tree().process_frame
	check("mort du joueur : rendue au directeur du mode, pas de bilan de Survie", dd.downs == 1 and not world._ended)
	world.pause_menu.abandon_requested.emit()
	check("abandon : rendu au directeur du mode", dd.abandoned)
	TeamMatch.end()
	get_tree().paused = false
	world.queue_free()
	await get_tree().process_frame
	Run.active = false
	Profile.in_run = false
	TeamMatch.unregister("mode0_demo")
	ModeRules._extra.erase("mode0_demo")
	check("après la partie : menu, rien de scellé", Modes.current() == "menu" and not Modes.sealed())


func _frames(n: int) -> void:
	for _i in n:
		await get_tree().physics_frame


func _until(cond: Callable, max_frames := 300) -> void:
	for _i in max_frames:
		if cond.call():
			return
		await get_tree().physics_frame
