extends Node
## Recharges des sorts enchaînés et plafonds des statistiques en duel (PvpCaps) :
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
	check("vitesse d'attaque plafonnée à 300 %", is_equal_approx(p.atk_speed, 3.0))
	check("critique plafonné à 100 %", is_equal_approx(p.crit, 1.0))
	check("dégâts critiques plafonnés à ×3,00", is_equal_approx(1.0 + p.crit_dmg, 3.0))
	check("statistique sous le plafond inchangée", is_equal_approx(p.move_mult, 1.2) and not "move_mult" in capped)
	check("hors duel : pas de plafond", not PvpCaps.active())
	Duel.active = true
	p.recalc_stats()
	check("en duel : plafonds appliqués au calcul des statistiques", p.atk_speed <= 3.0 and p.crit <= 1.0 and p.crit_dmg <= 2.0)
	Duel.active = false
	print("\n%s (%d échec(s))" % ["TOUT EST OK" if fails == 0 else "ÉCHECS", fails])
	get_tree().quit()
