extends Node
## Mode en cours, profils de règles, modificateurs, valeurs de départ inchangées.
## godot --headless --path game res://tests/test_modes.tscn

var fails := 0


func check(label: String, ok: bool) -> void:
	print(("OK    " if ok else "ÉCHEC ") + label)
	if not ok:
		fails += 1


func _ready() -> void:
	Settings.reset_all()
	check("au menu : aucun mode", Modes.current() == "menu" and not Modes.is_pvp())
	Duel.active = true
	check("Duel.active = mode duel, règles JcJ actives", Modes.current() == "duel" and PvpCaps.active() and ModeRules.profile_name() == "duel_b")
	check("valeurs de départ = les constantes d'avant", is_equal_approx(PvpCaps.damage_scale(), PvpCaps.DAMAGE_SCALE) \
		and is_equal_approx(PvpCaps.basic_mult(), PvpCaps.BASIC_MULT) and is_equal_approx(PvpCaps.heal_mult(), PvpCaps.HEAL_MULT) \
		and is_equal_approx(PvpCaps.pressure_start(), PvpCaps.PRESSURE_START))
	PvpCaps.elapsed = 0.0
	check("acharnement 1 avant le seuil, 2 vingt secondes après", is_equal_approx(PvpCaps.pressure(), 1.0))
	PvpCaps.elapsed = PvpCaps.PRESSURE_START + PvpCaps.PRESSURE_STEP
	check("acharnement ×2 un pas après le seuil", is_equal_approx(PvpCaps.pressure(), 2.0))
	PvpCaps.elapsed = 0.0
	# surcharge du mode dev
	DevEdits.data["modes"] = {"duel_b": {"dmg_scale": 0.03}}
	check("mode dev : l'échelle des dégâts est surchargée", is_equal_approx(PvpCaps.damage_scale(), 0.03))
	DevEdits.data["modes"] = {}
	check("surcharge retirée : valeur d'origine", is_equal_approx(PvpCaps.damage_scale(), PvpCaps.DAMAGE_SCALE))
	# modificateurs
	ModeRules.modifiers = ["heal_half"]
	check("modificateur « soins ÷ 2 »", is_equal_approx(PvpCaps.heal_mult(), PvpCaps.HEAL_MULT * 0.5))
	check("coût de difficulté d'une liste", Modifiers.cost(["heal_half", "one_life"]) == 4)
	ModeRules.modifiers = []
	# profil imposé (arène --rules)
	Duel.active = false
	ModeRules.forced = "duel_a"
	check("--rules : profil imposé hors mode", ModeRules.profile_name() == "duel_a" and is_equal_approx(ModeRules.num("dmg_scale"), 0.030))
	ModeRules.forced = ""
	Modes.forced = "tower"
	check("mode imposé", Modes.current() == "tower")
	Modes.forced = ""
	# plafonds de statistiques
	var caps: Dictionary = ModeRules.rule("caps")
	check("plafonds du duel : 13, dégâts +100 %", caps.size() == 13 and is_equal_approx(float(caps.crit), 0.5) and is_equal_approx(float(caps.dmg_mult), 2.0))
	print("TOUT EST OK (0 échec(s))" if fails == 0 else "ÉCHECS : %d" % fails)
	get_tree().quit(fails)
