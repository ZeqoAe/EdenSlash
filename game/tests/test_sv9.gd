extends Node
## Lot S9 du Survivant (conception/survivor/R_S9.md) : retours du joueur. Vérifie :
## - les orbes d'expérience : sol plein (XpOrbs.MAX_ORBS), une orbe nouvelle apparaît TOUJOURS sous le monstre et reprend la
##   valeur de l'orbe oubliée la plus loin (avant : elle s'ajoutait à l'orbe la plus proche d'elle, souvent loin derrière le
##   héros : « les monstres ne lâchent plus d'orbes ») ; rien ne se perd, une orbe qui vole vers le héros n'est pas reprise ;
## - les sorts : la grille entière (12 = 4 cases × le sort et 2 enchaînements), et le poids des améliorations de sort borné ;
## - les MESURES de la collecte réelle (tests/sv7_mesures.json, « human » : pilote avec la vraie zone de collecte) : le niveau
##   monte jusqu'à la fin sans palier plat.
## godot --headless --path game res://tests/test_sv9.tscn

const MEASURES := "res://tests/sv7_mesures.json"

var fails := 0


func check(label: String, ok: bool) -> void:
	print(("OK    " if ok else "ÉCHEC ") + label)
	if not ok:
		fails += 1


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Settings.reset_all()
	Profile.selected_class = "hunter"
	Profile.reset_all()
	Profile.in_run = false
	SurvivorCards.seed_with(9)
	seed(9)
	_orbs()
	_spells()
	_measures()
	print("\n%s (%d échec(s))" % ["TOUT EST OK" if fails == 0 else "ÉCHECS", fails])
	Profile.reset_all()
	get_tree().quit(1 if fails > 0 else 0)


# --- orbes ----------------------------------------------------------------------------------------------------------------
func _orbs() -> void:
	var o := XpOrbs.new()
	add_child(o)  # aucun héros dans la scène de test : la distance se compte depuis le point du lâcher
	o.set_process(false)
	for i in XpOrbs.MAX_ORBS:  # orbes oubliées en ligne : la plus loin à 3 + MAX_ORBS mètres
		o.spawn(Vector3(3.0 + i, 0, 0), 10.0)
	var before := _total(o)
	check("sol plein : %d orbes" % o.count(), o.count() == XpOrbs.MAX_ORBS)
	o._pull[o.count() - 1] = 1  # la plus loin vole déjà vers le héros : elle n'est pas reprise
	o.spawn(Vector3.ZERO, 7.0)
	var newest: Vector3 = o._pos[o.count() - 1]
	check("sol plein : la nouvelle orbe apparaît sous le monstre (%.1f m)" % Vector2(newest.x, newest.z).length(),
		o.count() == XpOrbs.MAX_ORBS and Vector2(newest.x, newest.z).length() < 1.0)
	check("elle reprend l'orbe oubliée la plus loin (valeur %.0f = 7 + 10)" % o._val[o.count() - 1], is_equal_approx(o._val[o.count() - 1], 17.0))
	var farthest := 0.0
	for p in o._pos:
		farthest = maxf(farthest, p.x)
	check("l'orbe qui vole vers le héros reste (la plus loin : %.0f m)" % farthest, farthest > 1.5 + XpOrbs.MAX_ORBS)
	check("rien ne se perd : %.0f = %.0f + 7" % [_total(o), before], is_equal_approx(_total(o), before + 7.0))
	for i in 500:  # une horde de plus : chaque lâcher reste visible là où le monstre tombe, le total suit
		o.spawn(Vector3(randf_range(-4, 4), 0, randf_range(-4, 4)), 5.0)
	var near := 0
	for p in o._pos:
		if Vector2(p.x, p.z).length() < 7.0:
			near += 1
	check("500 lâchers de plus au même endroit : %d orbes près du héros, total %.0f" % [near, _total(o)],
		near >= XpOrbs.MAX_ORBS - 1 and is_equal_approx(_total(o), before + 7.0 + 2500.0))
	check("compteurs : %d reprises, xp lâchée %.0f" % [int(o.stats.recycled), float(o.stats.xp_in)],
		int(o.stats.recycled) == 501 and is_equal_approx(float(o.stats.xp_in), before + 7.0 + 2500.0))
	o.queue_free()


func _total(o: XpOrbs) -> float:
	var t := 0.0
	for v in o._val:
		t += v
	return t


# --- sorts ----------------------------------------------------------------------------------------------------------------
func _spells() -> void:
	check("sorts : la grille entière, %d = %d cases × (1 + %d enchaînements)" % [Survivor.SPELL_MAX, Run.MAX_SKILLS, Run.MAX_CHAIN],
		Survivor.SPELL_MAX == Run.MAX_SKILLS * (1 + Run.MAX_CHAIN))
	var few := 999
	for cid in GameData.classes:
		few = mini(few, (GameData.classes[cid].get("skills", []) as Array).size())
	check("chaque classe a de quoi remplir la grille (%d sorts au moins)" % few, few >= Survivor.SPELL_MAX)
	Survivor.start("hunter", Survivor.zones()[0], 3)
	var ids: Array = Run.class_data().get("skills", []).map(func(s): return int(s.id))
	var w_at := {}
	for i in Survivor.SPELL_MAX:
		Run.apply_card(SurvivorCards.spell_card(int(ids[i])))
		var tot := 0.0
		for c in SurvivorCards.candidates():
			if c.kind == "spell_up":
				tot += float(c.w)
		w_at[i + 1] = tot
	var norm := Survivor.rule("spell_up_norm")
	check("Chasseur : %d sorts pris (4 cases, 2 enchaînements par case)" % Run.all_skills().size(),
		Run.all_skills().size() == Survivor.SPELL_MAX and Run.skills.size() == Run.MAX_SKILLS)
	check("améliorations de sort : poids %.1f à 6 sorts, %.1f à 12 (les sorts ne noient pas l'équipement)" % [float(w_at[6]), float(w_at[12])],
		absf(float(w_at[12]) - float(w_at[int(norm)])) < 0.01 and float(w_at[2]) < float(w_at[6]))
	check("12 sorts : plus de nouveau sort proposé", not SurvivorCards.candidates().any(func(c): return c.kind == "spell_new"))
	Run.finish("abandon")
	Profile.end_run_survival()


# --- mesures --------------------------------------------------------------------------------------------------------------
func _measures() -> void:
	var f := FileAccess.open(MEASURES, FileAccess.READ)
	check("mesures présentes (%s)" % MEASURES, f != null)
	if f == null:
		return
	var m: Dictionary = JSON.parse_string(f.get_as_text())
	var h: Dictionary = m.get("human", {})
	var lv: Dictionary = h.get("levels", {})
	check("collecte réelle mesurée (%d runs, pilote avec la vraie zone de collecte)" % int(h.get("n", 0)), int(h.get("n", 0)) >= 4 and lv.size() >= 18)
	if lv.size() < 18:
		return
	var flat := 0
	for mi in range(10, 19):
		if float(lv.get(str(mi + 2), 0)) <= float(lv.get(str(mi), 0)):
			flat += 1
	check("le niveau monte jusqu'à la fin : %s à 10 / 15 / 18 min, aucun palier plat de 2 min après 10:00 (%d)" % [
		[lv.get("10"), lv.get("15"), lv.get("18")], flat], flat == 0)
	var l18 := float(lv.get("18", 0))
	check("niveau médian à 18:00 avec la vraie collecte : %.0f (30 à 45)" % l18, l18 >= 30.0 and l18 <= 45.0)
	check("expérience ramassée : %d %% de celle lâchée (au moins 70 %%)" % roundi(100.0 * float(h.get("collected", 0))), float(h.get("collected", 0)) >= 0.7)
