extends Node
## Recharges des sorts enchaînés, plafonds des statistiques et échelle des dégâts en duel
## (PvpCaps) :
## godot --headless --path game res://tests/test_pvp.tscn

var fails := 0


func check(label: String, ok: bool) -> void:
	print(("OK    " if ok else "ÉCHEC ") + label)
	if not ok:
		fails += 1


func _ready() -> void:
	Training.active = true  # rien n'est sauvegardé
	Run.start("warrior")
	var all: Array = Run.class_data().skills
	Run.skills = [{"id": int(all[0].id), "rank": 1}]
	Run.chains = {0: [{"id": int(all[4].id), "rank": 1}, {"id": int(all[5].id), "rank": 1}]}
	var p := Player.new()
	p.level = 10
	add_child(p)
	await get_tree().physics_frame
	p.set_physics_process(false)  # le temps du héros est avancé à la main
	var s1 := int(all[4].id)
	var s2 := int(all[5].id)

	# --- enchaînements : chaque sort a sa recharge
	p.use_skill(0)
	p._time += Player.CHAIN_DELAY + 0.2
	check("barre ouverte, sort enchaîné prêt", p.chain_ready(0))
	check("sort enchaîné lancé", p._chain_press(0) == 2)
	check("le sort enchaîné prend sa recharge", float(p.skill_ready_at.get(s1, 0.0)) > p._time)
	# sort suivant en recharge courte : la case attend, l'appui ne casse pas la chaîne
	p.skill_ready_at[s2] = p._time + Player.CHAIN_DELAY + 1.0
	p._time += Player.CHAIN_DELAY + 0.2
	var st := p.chain_state(0)
	check("recharge du sort suivant : case bloquée", not st.is_empty() and st.phase == "lock" and st.get("recharge", false))
	check("appui pendant la recharge : « En recharge », chaîne gardée", p._chain_press(0) == 1 and not p.chain_state(0).is_empty())
	p._time += 1.0
	check("recharge finie : barre ouverte", p.chain_ready(0))
	# sort suivant pas prêt avant la fin de la barre : chaîne non proposée
	p._chain_open(0, 0)
	p.skill_ready_at[s1] = p._time + 30.0
	check("sort suivant trop long à recharger : pas d'enchaînement", p.chain_state(0).is_empty())

	# --- plafonds JcJ (seulement en duel)
	p.atk_speed = 136.65
	p.crit = 149.5
	p.crit_dmg = 141.0
	p.move_mult = 1.2
	var capped := PvpCaps.apply(p)
	check("vitesse d'attaque plafonnée (%d %%)" % roundi(PvpCaps.CAPS.atk_speed * 100), is_equal_approx(p.atk_speed, PvpCaps.CAPS.atk_speed))
	check("critique plafonné (%d %%)" % roundi(PvpCaps.CAPS.crit * 100), is_equal_approx(p.crit, PvpCaps.CAPS.crit))
	var cd_cap := float(ModeRules.rule("caps").crit_dmg)
	check("dégâts critiques plafonnés (×%.2f)" % (1.0 + cd_cap), is_equal_approx(p.crit_dmg, cd_cap))
	check("statistique sous le plafond inchangée", is_equal_approx(p.move_mult, 1.2) and not "move_mult" in capped)
	check("hors duel : pas de plafond", not PvpCaps.active())
	Duel.active = true
	p.recalc_stats()
	check("en duel : plafonds appliqués au calcul des statistiques", p.atk_speed <= PvpCaps.CAPS.atk_speed and p.crit <= PvpCaps.CAPS.crit and p.crit_dmg <= cd_cap)
	Duel.active = false
	await _test_scale()
	print("\n%s (%d échec(s))" % ["TOUT EST OK" if fails == 0 else "ÉCHECS", fails])
	get_tree().quit()


## Duel entre deux guerriers « opti » (profils générés) : un coup retire la même part des PV au
## niveau 25 et au 90, jamais plus de 20 % ; soins réduits ; acharnement.
func _test_scale() -> void:
	var all = JSON.parse_string(FileAccess.get_file_as_string(RivalBuilds.PATH))
	var frac := {}
	Duel.active = true
	PvpCaps.elapsed = 0.0
	for lv in [25, 90]:
		var b: Dictionary = {}
		for x in all:
			if String(x.get("auto", "")) != "" and String(x["class"]) == "warrior" and int(x.level) == lv:
				b = x
		if b.is_empty():
			check("profil opti du guerrier niveau %d" % lv, false)
			continue
		var hs: Array = []
		for i in 2:
			var h := Player.new()
			h.foe = true
			h.class_id = "warrior"
			h.level = lv
			h.use_build(b, lv)
			add_child(h)
			hs.append(h)
		await get_tree().physics_frame
		for h in hs:
			h.set_physics_process(false)
			h.evasion_chance = 0.0
			h.parry_chance = 0.0
		var a: Player = hs[0]
		var t: Player = hs[1]
		t.take_damage(a.atk, a)
		frac[lv] = (t.max_hp - t.hp) / t.max_hp
		t.hp = t.max_hp
		t.take_damage(a.atk * 1000.0, a)
		check("niveau %d : un coup énorme retire 20 %% des PV au plus (%.1f %%)" % [lv, (t.max_hp - t.hp) / t.max_hp * 100.0],
			t.hp >= t.max_hp * (1.0 - Combatant.PVP_HIT_CAP) - 1.0 and not t.is_dead)
		if lv == 90:
			_test_basic(a, t)
		t.hp = t.max_hp * 0.5
		var before := t.hp
		t.heal(t.max_hp * 0.2)
		check("niveau %d : soins réduits en duel" % lv, absf((t.hp - before) - t.max_hp * 0.2 * PvpCaps.HEAL_MULT) < 1.0)
		for h in hs:
			h.queue_free()
	if frac.size() == 2:
		check("même part des PV par coup au niveau 25 et 90 (%.2f %% / %.2f %%)" % [frac[25] * 100.0, frac[90] * 100.0],
			frac[90] > 0.002 and absf(frac[25] - frac[90]) < 0.35 * frac[90])
	PvpCaps.elapsed = PvpCaps.PRESSURE_START + PvpCaps.PRESSURE_STEP
	check("acharnement : dégâts ×2 et soins ÷2 un palier plus tard", is_equal_approx(PvpCaps.pressure(), 2.0)
		and is_equal_approx(PvpCaps.heal_mult(), PvpCaps.HEAL_MULT / 2.0))
	PvpCaps.elapsed = 0.0
	Duel.active = false


## Auto-attaque entre héros en duel : sans contrôle, × PvpCaps.BASIC_MULT ; adversaire scripté
## sur la fiche du build opti de sa classe (mêmes PV et critiques qu'un héros).
func _test_basic(a: Player, t: Player) -> void:
	var hit := {"mult": 1.0, "applies": {"stun": 1.0}, "dmg_type": "phys"}
	a.crit = 0.0
	t.hp = t.max_hp
	a._hit_monster(t, Vector3.FORWARD, hit.duplicate(), false)
	var basic := t.max_hp - t.hp
	check("duel : l'auto-attaque ne renverse pas", not t.has_status("stun"))
	t.hp = t.max_hp
	a._hit_monster(t, Vector3.FORWARD, hit.duplicate(), true)
	var spell := t.max_hp - t.hp
	check("duel : un sort renverse toujours", t.has_status("stun"))
	check("duel : auto-attaque × %.1f (%.0f contre %.0f)" % [PvpCaps.BASIC_MULT, basic, spell],
		absf(basic / maxf(spell, 1.0) - PvpCaps.BASIC_MULT) < 0.15)
	t.statuses.clear()
	t.hp = t.max_hp
	Duel.rival_class = "warrior"
	Duel.rival_build = {}
	Duel.gear_mode = Duel.GEAR_OPTI
	Duel.difficulty = 2
	Duel.hp_mult = 1.0
	Duel.atk_mult = 1.0
	var r := Duel.make_rival(90)
	Run.hero_level = 90  # puissance des objets au niveau du duel, comme dans DuelDirector
	t.recalc_stats()
	check("adversaire scripté : PV d'un héros opti (%d contre %d)" % [r.max_hp, t.max_hp], absf(r.max_hp / t.max_hp - 1.0) < 0.05)
	check("adversaire scripté : critiques d'un héros (%d %%)" % roundi(r.crit_chance * 100.0), r.crit_chance > 0.2 and r.crit_chance <= PvpCaps.CAPS.crit)
	r.free()
