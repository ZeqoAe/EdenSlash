extends Node
## Lot GX-6 : build conseillé de talents (TalentBuild : un ordre de 80 points par classe, chaque préfixe bâtissable,
## cohérent avec le profil de la classe) ; page Talents : « Conseillé » (aperçu avant / après, « Annuler ») et 3
## chargements nommés par classe (sauvegardés) ; modes scellés intacts ; profils « opti » à 80 points au plus (gen_profiles).
## godot --headless --path game res://tests/test_gx6.tscn

var fails := 0


func check(label: String, ok: bool) -> void:
	print(("OK    " if ok else "ÉCHEC ") + label)
	if not ok:
		fails += 1


func _ready() -> void:
	check("profil de test", Profile.save_path == Profile.TEST_SAVE_PATH)
	Training.active = true
	Settings.reset_all()
	Profile.reset_all()
	Profile.in_run = false
	_test_build_all()
	_test_coherence()
	_test_profile_rules()
	_test_loads()
	_test_sealed()
	await _test_page()
	_test_opti_profiles()
	Modes.forced = ""
	Training.active = true
	Profile.reset_all()
	print("TOUT EST OK (0 échec(s))" if fails == 0 else "ÉCHECS : %d" % fails)
	get_tree().quit(fails)


func _sum(r: Dictionary) -> int:
	var n := 0
	for k in r:
		n += int(r[k])
	return n


# --- l'ordre conseillé, pour les 60 classes ---------------------------------------------------------
func _test_build_all() -> void:
	var bad_size: Array = []
	var bad_prefix: Array = []
	for cls in GameData.talents:
		Profile.expertise[cls] = 10000000  # maîtrise maximale : 80 points
		var o := TalentBuild.order(String(cls))
		if o.size() != TalentBuild.MAX_POINTS:
			bad_size.append(cls)
		for n in [1, 2, 7, 15, 16, 20, 25, 30, 35, 36, 50, 64, 79, 80]:
			var r := TalentBuild.ranks(String(cls), n)
			if _sum(r) != n or not Profile.talent_set_valid(String(cls), r):
				bad_prefix.append("%s@%d" % [cls, n])
				break
	check("%d classes : 80 points conseillés chacune %s" % [GameData.talents.size(), bad_size], GameData.talents.size() == 60 and bad_size.is_empty())
	check("chaque préfixe se bâtit point par point (prérequis, colonnes) %s" % [bad_prefix], bad_prefix.is_empty())
	var full := 0
	for row in GameData.talents.warrior.rows:
		for c in row:
			if c != null:
				full += int(c.max)
	check("l'arbre entier (%d points) dépasse les 80 points d'un héros : il faut choisir" % full, full > TalentBuild.MAX_POINTS)
	check("ordre stable (même résultat deux fois)", TalentBuild.order("warrior") == TalentBuild.order("warrior") and TalentBuild.ranks("magician", 40) == TalentBuild.ranks("magician", 40))
	check("0 point : rien de conseillé", TalentBuild.ranks("warrior", 0).is_empty())


## Stats de talent d'un arbre (totaux).
func _stats(cls: String, r: Dictionary) -> Dictionary:
	return TalentBuild.totals(cls, r).stats


func _test_coherence() -> void:
	# rempart (Guerrier) : survie d'abord ; arcane (Magicien) : pas de stat physique ; esprit (Clerc) : soins
	var w := _stats("warrior", TalentBuild.ranks("warrior", 80))
	check("Guerrier (rempart) : PV max et défense au maximum (%s)" % w, is_equal_approx(float(w.get("hp_pct", 0.0)), 0.2) and float(w.get("def_pct", 0.0)) >= 0.19)
	var w10 := _stats("warrior", TalentBuild.ranks("warrior", 10))
	check("Guerrier, 10 premiers points : PV max ou défense (%s)" % w10, float(w10.get("hp_pct", 0.0)) + float(w10.get("def_pct", 0.0)) >= 0.09)
	var m := _stats("magician", TalentBuild.ranks("magician", 80))
	check("Magicien (arcane) : attaque et incantation, aucune force (%s)" % m, float(m.get("atk_pct", 0.0)) >= 0.19 and float(m.get("cast_speed", 0.0)) > 0.0 and not m.has("str_pct"))
	var cl := _stats("cleric", TalentBuild.ranks("cleric", 80))
	check("Clerc (esprit) : soins et sagesse (%s)" % cl, float(cl.get("heal_pct", 0.0)) > 0.0 and float(cl.get("wis_pct", 0.0)) > 0.0)
	# les stats ★ du profil reçoivent des points quand l'arbre en propose
	var miss: Array = []
	for cls in GameData.talents:
		var r := TalentBuild.ranks(String(cls), 80)
		var st := _stats(String(cls), r)
		var tree_stats := {}
		for k in GameData.talents[cls].talents:
			var eff: Dictionary = GameData.talents[cls].talents[k].get("effect", {})
			if String(eff.get("type", "")) == "stat":
				tree_stats[String(eff.stat)] = true
		var star := false
		var offered := false
		for ts in ClassGear.top_stats(String(cls)):
			for s in tree_stats:
				if TalentBuild._key(String(cls), String(s)) == String(ts[0]) or (String(s) == "def_pct" and String(ts[0]) == "def"):
					offered = true
					if st.has(s):
						star = true
		if offered and not star:
			miss.append(cls)
	check("stats ★ du profil servies quand l'arbre en a %s" % [miss], miss.is_empty())
	check("phrase « Pensé pour Rempart : … » (%s)" % TalentBuild.focus_line("warrior"), TalentBuild.focus_line("warrior").begins_with("Pensé pour Rempart : ") and TalentBuild.focus_line("warrior").contains("PV max"))
	var lines := TalentBuild.compare_lines("warrior", {"52582": 5}, TalentBuild.ranks("warrior", 80))
	check("aperçu avant → après (%s)" % " / ".join(lines), lines.size() >= 3 and lines[0].contains("→") and " ".join(lines).contains("Défense : +5 % → +20 %"))
	check("aperçu sans changement : « Rien ne change. »", TalentBuild.compare_lines("warrior", {"52582": 5}, {"52582": 5}) == PackedStringArray(["Rien ne change."]))


# --- Profile : conseillé, appliquer, annuler -----------------------------------------------------------
func _test_profile_rules() -> void:
	Profile.reset_all()
	var c := "warrior"
	Profile.expertise[c] = 0
	check("maîtrise 1 : 2 points, conseil de 2 points", Profile.talent_points(c) == 2 and _sum(Profile.advised_talents(c)) == 2)
	for _i in 30:
		Profile.add_expertise(c, Profile.expertise_need(Profile.expertise_level(c)), false)
		if Profile.expertise_level(c) >= 12:
			break
	var pts := Profile.talent_points(c)
	check("maîtrise %d : %d points" % [Profile.expertise_level(c), pts], pts == 24)
	Profile.add_talent(c, 52584)
	Profile.add_talent(c, 52584)
	var before: Dictionary = Profile.talents[c].duplicate()
	var adv := Profile.advised_talents(c)
	check("conseil = les %d premiers points de l'ordre" % pts, adv == TalentBuild.ranks(c, pts) and _sum(adv) == pts)
	check("appliquer le conseil : tous les points placés", Profile.apply_talents(c, adv) and Profile.talent_spent(c) == pts and Profile.talent_norm(Profile.talents[c]) == adv)
	check("« Annuler » proposé tant que l'arbre est celui posé", Profile.can_undo_talents(c))
	check("« Annuler » : l'arbre d'avant revient", Profile.undo_talent_reset(c) and Profile.talent_norm(Profile.talents[c]) == Profile.talent_norm(before) and not Profile.can_undo_talents(c))
	Profile.apply_talents(c, adv)
	Profile.remove_talent(c, int(TalentBuild.order(c)[pts - 1]))
	check("arbre retouché depuis : « Annuler » n'est plus proposé ni permis", not Profile.can_undo_talents(c) and not Profile.undo_talent_reset(c) and Profile.talent_spent(c) == pts - 1)
	check("arbre impossible : refusé, rien ne change", not Profile.apply_talents(c, {"54705": 1}) and Profile.talent_spent(c) == pts - 1)
	check("arbre au-delà des points : refusé", not Profile.apply_talents(c, TalentBuild.ranks(c, 80)))
	# « Tout reprendre » garde son comportement (lot GX-5)
	var held: Dictionary = Profile.talent_norm(Profile.talents[c])
	Profile.reset_talents(c)
	check("« Tout reprendre » puis « Annuler » (GX-5) inchangés", Profile.can_undo_talents(c) and Profile.undo_talent_reset(c) and Profile.talent_norm(Profile.talents[c]) == held)


# --- chargements nommés ---------------------------------------------------------------------------------
func _test_loads() -> void:
	Profile.reset_all()
	var c := "warrior"
	Profile.expertise[c] = 10000000
	check("3 emplacements vides au départ", Profile.talent_loads_of(c).size() == 3 and Profile.talent_loads_of(c).all(func(e): return (e as Dictionary).is_empty()))
	check("arbre vide : rien à enregistrer", not Profile.save_talent_load(c, 0, "Rien"))
	Profile.apply_talents(c, TalentBuild.ranks(c, 80))
	var a: Dictionary = Profile.talent_norm(Profile.talents[c])
	check("enregistrer « Donjons » dans l'emplacement 1", Profile.save_talent_load(c, 0, "  Donjons  ") and Profile.talent_loads_of(c)[0].name == "Donjons" and Profile.talent_loads_of(c)[0].ranks == a)
	check("nom vide : « Chargement 3 »", Profile.save_talent_load(c, 2, "") and Profile.talent_loads_of(c)[2].name == "Chargement 3")
	check("nom trop long : coupé à %d signes" % Profile.TALENT_LOAD_NAME_MAX, Profile.rename_talent_load(c, 2, "Un nom beaucoup trop long pour un bouton") and String(Profile.talent_loads_of(c)[2].name).length() == Profile.TALENT_LOAD_NAME_MAX)
	check("emplacement hors bornes : refusé", not Profile.save_talent_load(c, 3, "x") and not Profile.save_talent_load(c, -1, "x"))
	Profile.reset_talents(c)
	for _i in 10:
		Profile.add_talent(c, 52584)
	var b: Dictionary = Profile.talent_norm(Profile.talents[c])
	check("deuxième arbre dans l'emplacement 2", Profile.save_talent_load(c, 1, "Duel"))
	check("charger « Donjons » : l'arbre revient, annulable", Profile.load_talent_load(c, 0) and Profile.talent_norm(Profile.talents[c]) == a and Profile.can_undo_talents(c))
	check("« Annuler » après un chargement : l'arbre d'avant", Profile.undo_talent_reset(c) and Profile.talent_norm(Profile.talents[c]) == b)
	check("charger un emplacement vide : refusé", Profile.clear_talent_load(c, 2) and not Profile.load_talent_load(c, 2) and Profile.talent_load_block(c, 2) == "emplacement vide")
	check("renommer un emplacement vide : refusé", not Profile.rename_talent_load(c, 2, "x"))
	# un chargement de 80 points sur un compte qui en a moins (autre profil) : refusé avec la raison
	Profile.expertise[c] = 0
	check("trop de points : refusé, avec la raison (%s)" % Profile.talent_load_block(c, 0), not Profile.load_talent_load(c, 0) and Profile.talent_load_block(c, 0).begins_with("demande 80 points"))
	Profile.expertise[c] = 10000000
	check("chargements par classe (le Magicien n'a rien)", Profile.talent_loads_of("magician").all(func(e): return (e as Dictionary).is_empty()))
	# sauvegarde sûre : relue telle quelle (nouvelle clé « talent_loads », « talents » inchangée)
	Training.active = false
	Profile.save_profile()
	var talents_before: Dictionary = Profile.talent_norm(Profile.talents[c])
	Profile.talent_loads = {}
	Profile.load_profile()
	Training.active = true
	var back := Profile.talent_loads_of(c)
	check("sauvegarde relue : les chargements et leurs noms", back[0].name == "Donjons" and back[0].ranks == a and back[1].name == "Duel" and back[1].ranks == b and back[2].is_empty())
	check("sauvegarde relue : l'arbre de la classe intact", Profile.talent_norm(Profile.talents[c]) == talents_before)
	# vieille sauvegarde sans la clé, et clé abîmée : rien ne casse
	Profile.talent_loads = {c: "abîmé"}
	check("clé abîmée : 3 emplacements vides", Profile.talent_loads_of(c).size() == 3 and (Profile.talent_loads_of(c)[0] as Dictionary).is_empty())
	Profile.talent_loads = {}


# --- modes scellés : les talents n'y comptent toujours pas ------------------------------------------
func _test_sealed() -> void:
	Profile.reset_all()
	var c := "warrior"
	Profile.expertise[c] = 10000000
	Profile.apply_talents(c, TalentBuild.ranks(c, 80))
	Run.class_id = c
	Run.passives = {}
	Modes.forced = ""
	var open := Run.passive_stats()
	Modes.forced = "survivor"
	var sealed := Run.passive_stats()
	var sk := Run.skill_talent(50041)
	Modes.forced = ""
	check("Aventure : les talents conseillés comptent (PV max %s)" % open.get("hp_pct", 0.0), is_equal_approx(float(open.get("hp_pct", 0.0)), 0.2))
	check("mode scellé : ni talents de stat ni talents de sort", not sealed.has("hp_pct") and not sealed.has("def_pct") and float(sk.power) == 0.0)


# --- page Talents ------------------------------------------------------------------------------------
func _ask() -> InfoCard.Ask:
	for c in get_tree().root.find_children("*", "", true, false):
		if c is InfoCard.Ask and not c.is_queued_for_deletion():
			return c
	return null


func _texts(root: Node) -> String:
	var out: PackedStringArray = []
	for n in [root] + root.find_children("*", "", true, false):
		if n is Label or n is Button or n is LineEdit:
			out.append(String(n.text))
		if n is Control and (n as Control).tooltip_text != "":
			out.append((n as Control).tooltip_text)
	return "\n".join(out)


func _test_page() -> void:
	Profile.reset_all()
	Profile.expertise["warrior"] = 10000000
	Profile.selected_class = "warrior"
	var page := TalentsPage.new()
	add_child(page)
	page.size = Vector2(1400, 800)
	page.cls = "warrior"
	await get_tree().process_frame
	page.refresh()
	page.show_sub("talents")
	check("bouton « Conseillé » et phrase du profil", page._advise != null and page._advise.visible and not page._advise.disabled and page._focus.text.begins_with("Pensé pour Rempart"))
	check("3 chargements « 1 · vide »…", page._load_btns.size() == 3 and (page._load_btns[0] as Button).text == "1 · vide")
	Profile.add_talent("warrior", 52584)
	page.refresh()
	page._advise.pressed.emit()
	await get_tree().process_frame
	var ask := _ask()
	check("« Conseillé » : aperçu avant / après d'abord (rien n'est placé)", ask != null and ask.title_label.text == "Arbre conseillé · 80 points" and Profile.talent_spent("warrior") == 1)
	var body := _texts(ask) if ask else ""
	check("aperçu : « Avant → après », PV max, « Annuler »", body.contains("Avant → après") and body.contains("PV max : 0 → +20 %") and body.contains("« Annuler »"))
	if ask:
		ask.ok_button.pressed.emit()
	await get_tree().create_timer(0.3).timeout
	check("confirmé : l'arbre conseillé est posé", Profile.talent_norm(Profile.talents.warrior) == Profile.advised_talents("warrior"))
	check("« Conseillé ✓ » grisé, « Annuler » visible", page._advise.disabled and page._advise.text == "Conseillé ✓" and page._undo.visible)
	page._undo.pressed.emit()
	await get_tree().process_frame
	check("« Annuler » : l'arbre d'avant (1 point)", Profile.talent_spent("warrior") == 1 and not page._undo.visible and not page._advise.disabled)
	# annuler l'aperçu : rien ne change
	page._advise.pressed.emit()
	await get_tree().process_frame
	ask = _ask()
	if ask:
		ask.cancel_button.pressed.emit()
	await get_tree().create_timer(0.3).timeout
	check("aperçu refusé : rien ne change", Profile.talent_spent("warrior") == 1)
	# chargement : enregistrer, renommer, charger
	Profile.apply_talents("warrior", Profile.advised_talents("warrior"))
	page.refresh()
	page.open_load(0)
	await get_tree().process_frame
	var dlg: TalentsPage.LoadDialog = page._load_dialog
	check("fiche du chargement 1 : nom à saisir, « Enregistrer ici »", dlg != null and dlg.name_edit != null and _texts(dlg).contains("Enregistrer ici") and _texts(dlg).contains("Emplacement libre"))
	dlg.name_edit.text = "Donjons"
	dlg._save()
	await get_tree().process_frame
	check("enregistré : « 1 · Donjons »", (page._load_btns[0] as Button).text == "1 · Donjons" and Profile.talent_loads_of("warrior")[0].name == "Donjons")
	Profile.reset_talents("warrior")
	page.refresh()
	page.open_load(0)
	await get_tree().process_frame
	dlg = page._load_dialog
	check("fiche remplie : 80 points, Charger, Renommer, Effacer", _texts(dlg).contains("80 points · surtout") and _texts(dlg).contains("Charger") and _texts(dlg).contains("Renommer") and _texts(dlg).contains("Effacer"))
	dlg._load()
	await get_tree().process_frame
	ask = _ask()
	check("charger : aperçu avant / après d'abord", ask != null and ask.title_label.text == "Charger « Donjons »" and Profile.talent_spent("warrior") == 0)
	if ask:
		ask.ok_button.pressed.emit()
	await get_tree().create_timer(0.3).timeout
	check("chargé : l'arbre « Donjons » est posé", Profile.talent_spent("warrior") == 80 and page._undo.visible)
	page.open_load(0)
	await get_tree().process_frame
	dlg = page._load_dialog
	dlg.name_edit.text = "Tour"
	dlg._rename()
	await get_tree().process_frame
	check("renommé : « 1 · Tour »", (page._load_btns[0] as Button).text == "1 · Tour")
	page.open_load(0)
	await get_tree().process_frame
	page._load_dialog._clear()
	await get_tree().process_frame
	check("effacé : « 1 · vide »", (page._load_btns[0] as Button).text == "1 · vide")
	page.open_load(1)
	await get_tree().process_frame
	var ev := InputEventAction.new()
	ev.action = "ui_cancel"
	ev.pressed = true
	page._load_dialog._input(ev)
	await get_tree().process_frame
	check("Échap / B ferme la fiche", not is_instance_valid(page._load_dialog) or page._load_dialog.is_queued_for_deletion())
	page.queue_free()
	await get_tree().process_frame


# --- profils « opti » du duel ---------------------------------------------------------------------------
func _test_opti_profiles() -> void:
	var all = JSON.parse_string(FileAccess.get_file_as_string("res://data/build_profiles.json"))
	var over := 0
	var auto := 0
	if all is Array:
		for b in all:
			if b is Dictionary and String(b.get("auto", "")) != "":
				auto += 1
				if _sum(b.get("talents", {})) > TalentBuild.MAX_POINTS:
					over += 1
	# talents réécrits par gen_profiles -- --talents-only après mesure du duel équipé (R_GX6)
	check("profils « opti » : %d, aucun au-delà des 80 points d'un héros (%d)" % [auto, over], auto > 0 and over == 0)
	check("gen_profiles : le build conseillé de 80 points (au lieu de l'arbre entier)", _sum(TalentBuild.ranks("knight", TalentBuild.MAX_POINTS)) == 80
		and FileAccess.get_file_as_string("res://tools/gen_profiles.gd").contains("TalentBuild.ranks(cid, TalentBuild.MAX_POINTS)"))
