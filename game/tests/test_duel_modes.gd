extends Node
## Duel à l'arme / équipé : profils, héros sans méta, plafond par coup et rafale.
## godot --headless --path game res://tests/test_duel_modes.tscn

var fails := 0


func check(label: String, ok: bool) -> void:
	print(("OK    " if ok else "ÉCHEC ") + label)
	if not ok:
		fails += 1


func _ready() -> void:
	Settings.reset_all()
	Profile.talents["warrior"] = {"test": 3}
	# --- règles des deux modes
	Duel.active = true
	Duel.bare = true
	check("à l'arme : profil duel_a, échelle 0,030", ModeRules.profile_name() == "duel_a" and is_equal_approx(PvpCaps.damage_scale(), 0.030))
	Duel.bare = false
	check("équipé : profil duel_b, échelle 0,021, dégâts +100 % au plus, critiques ×2",
		ModeRules.profile_name() == "duel_b" and is_equal_approx(PvpCaps.damage_scale(), 0.021)
		and is_equal_approx(float(ModeRules.rule("caps").dmg_mult), 2.0) and is_equal_approx(float(ModeRules.rule("caps").crit_dmg), 1.0))
	Duel.active = false

	# --- héros à l'arme : ni pièces ni méta
	Duel.bare = true
	Duel.bare_level = 1
	Duel.bare_variant = 1
	check("à l'arme : une seule condition d'inscription (le preset)", Duel.requirements("warrior").size() == 1)
	Duel.start("warrior", "mage", 1)
	check("niveau choisi : 1", Duel.level == 1 and Duel.active)
	check("rien d'équipé, talents effacés", Profile.equipped.is_empty() and Profile.talents["warrior"].is_empty())
	var p := Player.new()
	p.level = 1
	add_child(p)
	await get_tree().physics_frame
	p.set_physics_process(false)
	p.recalc_stats()
	check("arme de la classe sans stat, variante choisie", p.weapon_item().has("auto_variant") and int(p.weapon_item().auto_variant) == 1 and p.offhand_item().is_empty())
	check("aucun bonus : dégâts, vitesse, critique de base", is_equal_approx(p.dmg_mult, 1.0) and is_equal_approx(p.atk_speed, 1.0 + float(p.cls.get("base", {}).get("atk_speed", 0.0)) + p.attrs.agi * 0.0015))
	# --- plafond par coup et rafale (les deux héros sont des Player)
	var foe := Player.new()
	foe.foe = true
	foe.level = 1
	foe.built = true
	add_child(foe)
	await get_tree().physics_frame
	foe.set_physics_process(false)
	foe.recalc_stats()
	PvpCaps.elapsed = 10.0
	p.hp = p.max_hp
	var cap := ceilf(p.max_hp * 0.15)
	p.take_damage(p.max_hp * 100.0, foe)
	var lost1 := p.max_hp - p.hp
	check("un coup énorme : au plus 15 %% des PV (%d / %d)" % [lost1, p.max_hp], lost1 <= cap + 0.5 and lost1 > 0.0)
	p.take_damage(p.max_hp * 100.0, foe)
	p.take_damage(p.max_hp * 100.0, foe)
	var lost3 := p.max_hp - p.hp
	check("3 coups en 2 s : rafale limitée, héros debout (%d %% perdus)" % roundi(lost3 / p.max_hp * 100.0), lost3 < p.max_hp * 0.6 and p.hp > 0.0)
	PvpCaps.elapsed = 14.0  # la fenêtre de 2 s est passée
	var before := p.hp
	p.take_damage(p.max_hp * 100.0, foe)
	check("fenêtre écoulée : un coup plein à nouveau (15 %)", before - p.hp >= cap - 0.5)
	check("plus gros coup noté pour le bilan", PvpCaps.best_taken > 0.0 and PvpCaps.best_taken <= 0.151)
	# --- fin : adversaire de l'éditeur rendu, sauvegarde rechargée
	var stash_probe := {"class": "mage", "name": "essai"}
	Duel.active = false
	Duel.bare = false
	Duel.rival_build = stash_probe
	Duel.bare = true
	Duel.start("warrior", "mage", 1)
	check("à l'arme : l'adversaire de l'éditeur est mis de côté", Duel.rival_build.is_empty())
	Duel.finish(false)
	check("après le duel : adversaire de l'éditeur rendu", Duel.rival_build == stash_probe)
	Duel.bare = false
	Duel.rival_build = {}
	print("TOUT EST OK (0 échec(s))" if fails == 0 else "ÉCHECS : %d" % fails)
	get_tree().quit(fails)
