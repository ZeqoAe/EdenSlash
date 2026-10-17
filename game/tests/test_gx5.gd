extends Node
## Lot GX-5 (P1 restants de l'étude BM-GEAR) : talents v2 (arbre lisible, retirer un point gratuit, « Tout reprendre » et
## « Annuler », effet avant / après, recherche, points toujours visibles, modes scellés) ; titres (catalogue, porter, page
## Héros > Titres, titre sous le nom) ; Registre v2 (profil de stats, tout ce qui manque, classes voisines) ; « Ouvrir
## tout » (confirmation, coffres à choix gardés, récapitulatif par rareté) ; jalons du niveau de héros (titres et coffres
## d'apparence, une fois, jauge, Journal) ; préréglage choisi sur la page d'une activité ; Forge > Reporter (le +N d'une
## ancienne pièce sur la neuve, moins 2 crans, au prix des crans sans échec).
## godot --headless --path game res://tests/test_gx5.tscn

var fails := 0


func check(label: String, ok: bool) -> void:
	print(("OK    " if ok else "ÉCHEC ") + label)
	if not ok:
		fails += 1


func _buttons(root: Node) -> Array:
	return root.find_children("*", "Button", true, false)


func _button_with(root: Node, prefix: String) -> Button:
	for b in _buttons(root):
		if (b as Button).text.begins_with(prefix) and (b as Button).is_visible_in_tree():
			return b
	return null


func _texts(root: Node) -> String:
	var out: PackedStringArray = []
	for n in [root] + root.find_children("*", "", true, false):
		if n is Label or n is Button:
			out.append(String(n.text))
		elif n is RichTextLabel:
			out.append((n as RichTextLabel).get_parsed_text())
		if n is Control and (n as Control).tooltip_text != "":
			out.append((n as Control).tooltip_text)
	return "\n".join(out)


func _ready() -> void:
	check("profil de test", Profile.save_path == Profile.TEST_SAVE_PATH)
	Training.active = true
	Settings.reset_all()
	Profile.reset_all()
	Profile.in_run = false
	_test_talent_rules()
	await _test_talents_page()
	_test_titles()
	await _test_titles_page()
	await _test_registry()
	await _test_chests()
	await _test_milestones()
	_test_preset_pick()
	_test_report_rules()
	await _test_report_ui()
	await _test_lobby()
	Modes.forced = ""
	Training.active = true
	Profile.reset_all()
	print("TOUT EST OK (0 échec(s))" if fails == 0 else "ÉCHECS : %d" % fails)
	get_tree().quit(fails)


# --- talents ----------------------------------------------------------------------------------
func _add(cls: String, id: int, n: int) -> void:
	for _i in n:
		Profile.add_talent(cls, id)


func _test_talent_rules() -> void:
	Profile.reset_all()
	Profile.expertise["warrior"] = 10000000  # maîtrise maximale : 80 points
	var c := "warrior"
	check("maîtrise maximale : 80 points de talent", Profile.talent_points(c) == 2 * Profile.EXPERTISE_MAX)
	_add(c, 52582, 10)
	check("prérequis : « niveau 10 » ouvre le talent suivant", Profile.add_talent(c, 54699))
	check("retirer un point d'un prérequis tenu par un autre talent : refusé, avec la raison",
		not Profile.remove_talent(c, 52582) and Profile.talent_remove_block(c, 52582) != "" and Profile.talent_rank(c, 52582) == 10)
	check("retirer le talent du bout : gratuit", Profile.remove_talent(c, 54699) and Profile.talent_rank(c, 54699) == 0 and Profile.talent_spent(c) == 10)
	check("puis le prérequis redevient libre", Profile.remove_talent(c, 52582) and Profile.talent_rank(c, 52582) == 9)
	check("retirer un talent sans point : refusé", not Profile.remove_talent(c, 54705) and Profile.talent_remove_block(c, 54705) == "aucun point placé")
	# colonne ouverte à 15 points : on ne peut pas redescendre sous le palier tant qu'elle a des points
	_add(c, 52582, 6)
	check("15 points placés : la colonne « 15 » s'ouvre", Profile.talent_spent(c) == 15 and Profile.add_talent(c, 54705))
	check("redescendre sous le palier de la colonne : refusé", not Profile.remove_talent(c, 52582))
	_add(c, 52585, 1)
	check("un point ailleurs : on peut alors en retirer un", Profile.remove_talent(c, 52582) and Profile.talent_spent(c) == 16)
	check("arbre tenu : valide", Profile.talent_set_valid(c, Profile.talents[c]))
	check("arbre impossible (colonne sans le palier) : refusé", not Profile.talent_set_valid(c, {"54705": 1}))
	check("arbre au-delà des points : refusé", not Profile.talent_set_valid(c, {"52582": 20, "52583": 20, "52584": 20, "52585": 20, "52586": 20}))
	# tout reprendre, puis annuler
	var before: Dictionary = (Profile.talents[c] as Dictionary).duplicate()
	Profile.reset_talents(c)
	check("« Tout reprendre » : gratuit, tous les points rendus, annulable", Profile.talent_spent(c) == 0 and Profile.can_undo_talents(c))
	check("« Annuler » : l'arbre d'avant revient", Profile.undo_talent_reset(c) and Profile.talents[c] == before and not Profile.can_undo_talents(c))
	Profile.reset_talents(c)
	Profile.add_talent(c, 52582)
	check("arbre refait depuis : « Annuler » ne l'écrase pas", not Profile.undo_talent_reset(c) and Profile.talent_spent(c) == 1)
	# effet avant / après
	var t: Dictionary = GameData.talents[c].talents["52582"]
	check("effet au rang 4 : « +4 %% de défense » (%s)" % TalentsPage.effect_at(t, 4), TalentsPage.effect_at(t, 4) == "+4 % de défense")
	check("effet au rang 0 : aucun", TalentsPage.effect_at(t, 0) == "aucun effet")
	var dur := {}
	var cd := {}
	for cl in GameData.talents:
		for k in GameData.talents[cl].talents:
			var x: Dictionary = GameData.talents[cl].talents[k]
			if String(x.get("effect", {}).get("type", "")) == "skill_duration" and dur.is_empty():
				dur = x
			if String(x.get("effect", {}).get("type", "")) == "skill_cd" and cd.is_empty():
				cd = x
	check("effet de durée : « +3 s » au rang 3 (%s)" % TalentsPage.effect_at(dur, 3), TalentsPage.effect_at(dur, 3).begins_with("+%d s" % roundi(float(dur.effect.per_level) * 3)))
	check("effet de recharge : signe gardé (%s)" % TalentsPage.effect_at(cd, 2), TalentsPage.effect_at(cd, 2).begins_with("-%d %%" % roundi(float(cd.effect.per_level) * 200))
		and not TalentsPage.effect_at(cd, 2).contains("par niveau"))
	check("points : « 3 points libres · 14 placés »", TalentsPage.points_text(3, 14) == "3 points libres · 14 placés" and TalentsPage.points_text(0, 0) == "Aucun point de talent")


func _test_talents_page() -> void:
	Profile.reset_all()
	Profile.expertise["warrior"] = 10000000
	Profile.selected_class = "warrior"
	var page := TalentsPage.new()
	add_child(page)
	page.size = Vector2(1400, 800)
	page.cls = "warrior"
	await get_tree().process_frame
	page.refresh()
	page.show_sub("spells")
	check("points libres visibles depuis l'onglet Sorts", page._points.visible and page._points.text.begins_with("80 points libres"))
	check("onglet Sorts : ni recherche ni « Tout reprendre »", not page._search.visible and not page._reset.visible)
	page.show_sub("talents")
	var tree: Dictionary = GameData.talents.warrior
	var cells := 0
	for row in tree.rows:
		cells += (row as Array).size()
	check("arbre : une rangée d'en-têtes de colonne puis les cases (%d)" % page._grid.get_child_count(), page._grid.get_child_count() == page._grid.columns + cells)
	check("en-têtes : les paliers de points (15, 20, 25, 30, 35)", _texts(page._grid).contains("15 pts") and _texts(page._grid).contains("35 pts"))
	check("cases connues : 18 talents dans l'arbre", page._cells.size() == tree.talents.size())
	var dep: Control = page._cells.get(54699)
	check("lien de prérequis : la case garde son talent demandé (10 points)", dep != null and int(dep.get_meta("req")) == 52582 and int(dep.get_meta("req_pts")) == 10)
	# infobulle : effet avant / après, prérequis
	var b0: ItemWidgets.TipButton = page._cells[52582].get_child(0)
	check("infobulle : « Avec un point de plus : +1 % de défense »", b0.tip.contains("Avec un point de plus : [b]+1 % de défense"))
	var b1: ItemWidgets.TipButton = dep.get_child(0)
	check("infobulle : le prérequis et son état", b1.tip.contains("Demande :") and b1.tip.contains("niveau 10 ✗"))
	# clic : +1 ; clic droit : −1
	b0.pressed.emit()
	await get_tree().process_frame
	check("clic : +1 point", Profile.talent_rank("warrior", 52582) == 1 and page._points.text.begins_with("79 points libres"))
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_RIGHT
	ev.pressed = true
	(page._cells[52582].get_child(0) as Control).gui_input.emit(ev)
	await get_tree().process_frame
	check("clic droit : −1 point, gratuit", Profile.talent_rank("warrior", 52582) == 0 and page._points.text.begins_with("80 points libres"))
	check("manette : X dit « −1 point »", String((page._cells[52582].get_child(0) as Control).get_meta("pad_x", "")) == "−1 point")
	# recherche
	page._search.text = "défense"
	page._apply_search()
	var lit := 0
	var dim := 0
	for id in page._cells:
		if (page._cells[id] as Control).modulate.a > 0.9:
			lit += 1
		else:
			dim += 1
	check("recherche « défense » : %d cases vives, %d pâlies" % [lit, dim], lit >= 1 and dim >= 1 and (page._cells[52582] as Control).modulate.a > 0.9)
	page._search.text = ""
	page._apply_search()
	# tout reprendre / annuler
	_add("warrior", 52582, 5)
	page.refresh()
	page._reset.pressed.emit()
	await get_tree().process_frame
	check("« Tout reprendre » puis « Annuler » visible", Profile.talent_spent("warrior") == 0 and page._undo.visible)
	page._undo.pressed.emit()
	await get_tree().process_frame
	check("« Annuler » : les 5 points reviennent", Profile.talent_rank("warrior", 52582) == 5 and not page._undo.visible)
	# mode scellé : les talents n'y comptent pas, la page le dit
	Profile.in_run = true
	Modes.forced = "survivor"
	page.refresh()
	check("mode scellé : la page dit que les talents n'y comptent pas", page._sealed.visible)
	Modes.forced = ""
	Profile.in_run = false
	page.refresh()
	check("hors mode scellé : pas de note", not page._sealed.visible)
	page.queue_free()
	await get_tree().process_frame


# --- titres -------------------------------------------------------------------------------------
func _test_titles() -> void:
	Profile.reset_all()
	var cat := Titles.catalog()
	var names: Array = cat.map(func(e): return String(e.title))
	check("catalogue : %d titres, sans doublon" % cat.size(), cat.size() >= 40 and names.size() == _unique(names).size())
	for t in ["Aventurier", "Vétéran", Siege.TITLE, "Héros de Époque I", Pantheon.MASTER_TITLE, "Dernier debout", "Gantelet complet"]:
		check("catalogue : « %s » avec sa source" % t, t in names and String(cat[names.find(t)].how) != "")
	check("chaque titre dit comment l'obtenir", cat.all(func(e): return String(e.how).length() > 5 and String(e.group) in Titles.GROUPS))
	check("aucun titre gagné : rien de porté", Titles.owned().is_empty() and Titles.worn_text() == "Aucun titre porté")
	check("porter un titre pas gagné : refusé", Titles.wear("Vétéran") == "")
	Profile.add_title(Siege.TITLE)
	Profile.add_title("Titre d'une vieille version")
	check("porter un titre gagné", Titles.wear(Siege.TITLE) == Siege.TITLE and Profile.title == Siege.TITLE and Titles.worn_text() == "« %s »" % Siege.TITLE)
	check("un second « porter » le retire", Titles.wear(Siege.TITLE) == "")
	check("titre gagné hors catalogue : rangé dans « Autres »", Titles.catalog().any(func(e): return String(e.title) == "Titre d'une vieille version" and String(e.group) == "Autres"))
	check("groupes dans l'ordre des sources", String(Titles.groups(Titles.catalog())[0][0]) == "Niveau de héros")


func _unique(a: Array) -> Array:
	var out: Array = []
	for x in a:
		if not x in out:
			out.append(x)
	return out


func _test_titles_page() -> void:
	Profile.reset_all()
	Profile.hero_name = "Nico"
	Profile.add_title("Vétéran")
	Profile.achievements["run_50"] = "2026-10-17"
	var page := TitlesPage.new()
	add_child(page)
	page.size = Vector2(1400, 800)
	await get_tree().process_frame
	page.refresh()
	check("page Titres : le nom du héros, aucun titre porté", page._name.text == "Nico" and page._worn.text == "Aucun titre porté" and page._none.disabled)
	check("page Titres : filtres avec leurs comptes", _texts(page._chips).contains("Obtenus · 1"))
	var porter := _button_with(page._list, "Porter")
	check("page Titres : « Porter » sur le titre gagné, « À obtenir » ailleurs", porter != null and _texts(page._list).contains("À obtenir"))
	var fired := [false]
	page.changed.connect(func(): fired[0] = true)
	porter.pressed.emit()
	await get_tree().process_frame
	check("« Porter » : le titre est porté et l'en-tête prévenu", Profile.title == "Vétéran" and fired[0] and page._worn.text == "« Vétéran »")
	check("le titre porté est marqué « Porté ✓ »", _button_with(page._list, "Porté ✓") != null)
	page._filter = 2
	page.refresh()
	check("filtre « À obtenir » : aucun « Porter »", _button_with(page._list, "Porter") == null)
	page._filter = 0
	page._search.text = "siège"
	page._query = "siège"
	page._fill()
	check("recherche « siège » : le titre du Siège seul ou presque", _texts(page._list).contains(Siege.TITLE) and not _texts(page._list).contains("Vétéran"))
	page._none.pressed.emit()
	await get_tree().process_frame
	check("« N'en porter aucun »", Profile.title == "")
	page.queue_free()
	await get_tree().process_frame


# --- Registre v2 --------------------------------------------------------------------------------
func _test_registry() -> void:
	Profile.reset_all()
	Profile.selected_class = "warrior"
	var top := ClassGear.top_stats("warrior", 5)
	var labels: Array = top.map(func(x): return ClassGear.stat_label(String(x[0])))
	check("profil du Guerrier : %s" % ", ".join(labels), top.size() == 5 and "Défense" in labels and float(top[0][1]) >= float(top[4][1]) and labels.size() == _unique(labels).size())
	check("profil en une ligne : nom, armure, dégâts", ClassGear.profile_line("warrior").begins_with(ClassGear.profile_name(ClassGear.profile_id("warrior"))) and ClassGear.profile_line("warrior").contains("armure de"))
	var miss := ClassGear.missing("warrior")
	check("ce qui manque : tout, chacun avec son activité (%d)" % miss.size(), miss.size() >= 3 and miss.all(func(m): return String(m.text) != "" and String(m.activity) != ""))
	var nb := ClassGear.neighbours("warrior", 2)
	check("classes voisines : %s" % ", ".join(nb), nb.size() >= 1 and not "warrior" in nb)
	var a := ClassGear.entry("warrior")
	var b := a.duplicate()
	b["cid"] = String(nb[0])
	b["pe"] = int(a.pe) + 500
	Profile.unlocked_classes.append(String(nb[0]))
	check("comparaison : « … a 500 PE de plus »", ClassGear.compare_line("warrior", String(nb[0]), a, b).contains("500 PE de plus"))
	var page := RegistryPage.new()
	add_child(page)
	page.size = Vector2(1400, 800)
	await get_tree().process_frame
	page.refresh()
	var rows := page._box.get_child_count()
	page.toggle("warrior")
	var txt := _texts(page._box)
	check("fiche dépliée : profil, ce qui manque, voisines, « Voir l'équipement »", txt.contains("Ce qui manque") and txt.contains("Classes voisines")
		and _button_with(page._box, "Voir l'équipement") != null and page._box.get_child_count() == rows)
	page.toggle("warrior")
	check("second clic : la fiche se replie", _button_with(page._box, "Voir l'équipement") == null)
	page.queue_free()
	await get_tree().process_frame


# --- coffres ------------------------------------------------------------------------------------
func _test_chests() -> void:
	Profile.reset_all()
	for f in ["", "", "scroll"]:
		Profile.reward_chests.append(Rewards.make("forge", 40, false, f))
	Profile.reward_chests.append(Rewards.make("set", 40))
	var txt := ChestsPage.open_all_text(Profile.reward_chests)
	check("confirmation : un genre par ligne avec son nombre", txt.contains("×2") and txt.contains("×1"))
	check("confirmation : le coffre à choix reste, rien n'est vendu", txt.contains("1 coffre à choix reste") and txt.contains("rien n'est vendu"))
	var page := ChestsPage.new()
	add_child(page)
	page.size = Vector2(1400, 800)
	await get_tree().process_frame
	page.refresh()
	var ask := page.ask_open_all()
	check("« Ouvrir tout » demande d'abord", ask != null and Profile.reward_chests.size() == 4 and ask.title_label.text == "Ouvrir 3 coffres ?")
	ask.ok_button.pressed.emit()
	await get_tree().process_frame
	check("confirmé : les 3 coffres sans choix s'ouvrent, le coffre à choix reste", Profile.reward_chests.size() == 1 and Rewards.is_choice(Profile.reward_chests[0])
		and page._title.text == "3 coffres ouverts")
	var low := Items.generate(30, 0.0, "head", "warrior", 0, "", 0)
	var high := Items.generate(30, 0.0, "chest", "warrior", 5, "", 5)
	var recap := ChestsPage.recap_text({"items": [low, high], "looks": [], "supplies": {}, "crystal": 12})
	check("récapitulatif : les raretés, la plus haute d'abord", recap.find("légendaire") >= 0 and recap.find("légendaire") < recap.find("commun"))
	check("récapitulatif : sans pourcentage, avec les fournitures", not recap.contains("%") and recap.contains("12 cristaux"))
	page._show_loot({"items": [low, high], "looks": [], "supplies": {}}, false, true)
	await get_tree().process_frame
	var first: Control = page._loot.get_child(0)
	check("révélation par rareté : la plus rare est rangée en tête", _texts(first).contains(Items.display_name(high)))
	Profile.reward_chests.clear()
	Profile.reward_chests.append(Rewards.make("forge", 40))
	check("un seul coffre : ouvert sans carte", page.ask_open_all() == null and Profile.reward_chests.is_empty())
	page.queue_free()
	await get_tree().process_frame


# --- jalons du niveau de héros ----------------------------------------------------------------
func _test_milestones() -> void:
	Profile.reset_all()
	HeroLevel.ensure()
	HeroLevel.last_miles.clear()
	check("jalons : 10, 25, 50, 75, 90", HeroLevel.MILESTONES.map(func(m): return int(m.level)) == [10, 25, 50, 75, 90])
	check("jalons : titres et coffres d'apparence seulement", HeroLevel.MILESTONES.all(_cosmetic_only))
	check("niveau 1 : prochain jalon au niveau 10", int(HeroLevel.next_milestone().level) == 10 and HeroLevel.next_milestone_line().begins_with("Niv. 10 : titre « Aventurier »"))
	check("infobulle de la jauge : le prochain jalon", HeroLevel.tooltip().contains("Prochain jalon · Niv. 10") and not HeroLevel.tooltip().contains("%"))
	var chests := Profile.reward_chests.size()
	HeroLevel.add_xp(HeroLevel.total_for(10) - HeroLevel.total() + 1.0)
	check("niveau 10 franchi : titre « Aventurier » et un coffre d'apparence rare", HeroLevel.level() == 10 and "Aventurier" in Profile.extra_titles
		and Profile.reward_chests.size() == chests + 1 and String(Profile.reward_chests.back().type) == "look_rare")
	check("jalon noté (bilan)", HeroLevel.last_miles.size() == 1 and HeroLevel.milestone_claimed(10))
	check("donné une seule fois", HeroLevel.claim_milestones().is_empty() and Profile.reward_chests.size() == chests + 1)
	HeroLevel.add_xp(HeroLevel.total_for(52) - HeroLevel.total())
	check("deux jalons d'un coup (25 et 50)", "Baroudeur" in Profile.extra_titles and "Héros aguerri" in Profile.extra_titles and Profile.reward_chests.size() == chests + 3)
	# bilan : les jalons franchis pendant la partie sont dits
	var spec := {"gained": [], "notes": []}
	HeroLevel.last = {"run": Run.started_at, "act": "survival", "won": true, "xp": 500.0, "from": 9, "to": 52}
	var out := HeroLevel.decorate(spec)
	var notes: Array = out.get("notes", [])
	check("bilan : « Jalon du niveau 25 : titre « Baroudeur » … »", notes.any(func(n): return String(n).begins_with("Jalon du niveau 25 : titre « Baroudeur »")) and HeroLevel.last_miles.is_empty())
	# compte déjà haut (avant ce lot) : ses jalons arrivent au menu principal
	Profile.reset_all()
	HeroLevel.ensure()
	Profile.records[HeroLevel.KEY] = HeroLevel.total_for(80)
	var note := HeroLevel.take_note()
	check("compte au niveau 80 : 4 jalons au menu principal (%s)" % note, note.begins_with("Jalons du niveau de héros") and Profile.extra_titles.size() == 4 and HeroLevel.take_note() == "")
	# jauge et Journal
	var g := HeroLevelGauge.new(16, 140.0)
	g.show_milestone = true
	add_child(g)
	await get_tree().process_frame
	check("jauge : « ★ 90 » (prochain jalon)", g._mile.visible and g._mile.text == "★ 90" and g._mile.tooltip_text.contains("Héros sans égal"))
	g.queue_free()
	var j := QuestJournal.open_on(self, QuestJournal.TABS.size() - 1)
	await get_tree().process_frame
	await get_tree().process_frame
	var jt := _texts(j)
	check("Journal > Niveau de héros : les 5 jalons, obtenus et à venir", jt.contains("Niveau 10 : titre « Aventurier »") and jt.contains("Niveau 90 : titre « Héros sans égal »")
		and jt.contains("obtenu") and jt.contains("encore 10 niveaux"))
	j.close_ui()
	j.queue_free()
	await get_tree().process_frame


func _cosmetic_only(m: Dictionary) -> bool:
	return String(m.title) != "" and (m.chests as Array).all(func(c): return String(c).begins_with("look_") or String(c).begins_with("aura_"))


# --- préréglage sur la page d'une activité ----------------------------------------------------
func _test_preset_pick() -> void:
	Profile.reset_all()
	Profile.in_run = false
	Profile.selected_class = "warrior"
	Profile._lobby_view()
	var box := VBoxContainer.new()
	add_child(box)
	check("un seul préréglage rempli : pas de rangée", PresetPick.add(box, "dungeon", Callable()) == null)
	var it := Items.generate(5, 0.0, "head", "warrior", 1, "", 1)
	Profile.vault.append(it)
	Profile._class_presets("warrior")
	Profile.presets.warrior.sets[2].slots["head"] = String(it.uid)
	Profile.rename_preset("warrior", 2, "Donjons")
	var called := [0]
	var row := PresetPick.add(box, "dungeon", func(): called[0] += 1)
	check("deux préréglages remplis : la rangée « Équipement »", row != null and _texts(row).contains("Équipement"))
	check("le préréglage au nom de l'activité est conseillé (★)", PresetPick.advised_index("warrior", "dungeon") == 2 and _button_with(row, "Donjons  ★") != null)
	check("infobulle : pièces et PE", _button_with(row, "Donjons").tooltip_text.contains("PE "))
	_button_with(row, "Donjons").pressed.emit()
	check("un clic : le préréglage devient actif, la page se refait", Profile.active_preset("warrior") == 2 and called[0] == 1)
	Profile.in_run = true
	check("en partie : pas de rangée", PresetPick.add(box, "dungeon", Callable()) == null)
	Profile.in_run = false
	Profile.set_active_preset("warrior", 0)
	box.queue_free()


# --- Reporter le +N ---------------------------------------------------------------------------
func _pair() -> Array:
	Profile.reset_all()
	Profile.in_run = false
	Profile.selected_class = "warrior"
	var old := Items.generate(40, 0.0, "head", "warrior", 4, "", 4)
	old["upgrade"] = 7
	old["up_rolls"] = [["hp", 10.0, 4], ["def", 5.0, 6]]
	old["pity"] = 0.4
	var neu := Items.generate(60, 0.0, "head", "warrior", 5, "", 5)
	Profile.install_gear({"head": old})
	Profile.inventory.append(neu)
	Profile._sync_vault()
	Profile.materials["crystal"] = 5000
	return [old, neu]


func _test_report_rules() -> void:
	var p := _pair()
	var old: Dictionary = p[0]
	var neu: Dictionary = p[1]
	check("Reporter : +7 donne +5 (2 crans perdus)", Forge.report_target(old) == 5 and Forge.REPORT_LOSS == 2)
	check("Reporter : la pièce portée est une source pour la neuve", Forge.report_block(old, neu) == "" and Forge.report_sources(neu).has(old))
	var cr := Profile.amount("crystal")
	var stash := Profile.stash.duplicate()
	var price := int(Forge.report_cost(old, neu).crystal)
	check("Reporter : prix = les crans reçus sans échec (%d cristaux)" % price, price == Forge.upgrade_crystals(Craft._item_level(neu), 0, 5) and price > 0)
	var msg := Forge.report(old, neu)
	check("Reporter : la neuve passe à +5 avec la stat bonus de +4 seulement (%s)" % msg, int(neu.upgrade) == 5 and (neu.up_rolls as Array).size() == 1
		and int(neu.up_rolls[0][2]) == 4 and msg.begins_with("Reporté :") and not ForgeBench._is_fail(msg))
	check("Reporter : l'ancienne revient à +0, sans stat bonus ni persévérance", int(old.upgrade) == 0 and not old.has("up_rolls") and not old.has("pity"))
	check("Reporter : payé en cristaux, sans parchemin", Profile.amount("crystal") == cr - price and Profile.stash == stash)
	check("Reporter : une pièce sous +3 n'a rien à donner", Forge.report_block(old, neu).contains("+3") and ForgeBench._is_fail(Forge.report(old, neu)))
	p = _pair()
	p[0]["locked"] = true
	check("Reporter : une pièce gardée (verrou) ne donne rien", Forge.report_block(p[0], p[1]).contains("gardée") and int(p[1].get("upgrade", 0)) == 0)
	p = _pair()
	p[1]["upgrade"] = 6
	check("Reporter : rien à gagner (+7 − 2 ≤ +6)", Forge.report_block(p[0], p[1]).begins_with("Rien à gagner") and Forge.report_sources(p[1]).is_empty())
	p = _pair()
	var boots := Items.generate(60, 0.0, "boots", "warrior", 5, "", 5)
	check("Reporter : un autre emplacement ne compte pas", Forge.report_block(p[0], boots) != "")
	check("Reporter : vers une pièce plus basse, refusé", Forge.report_block(p[1].merged({"upgrade": 7, "uid": "x"}), p[0].merged({"upgrade": 0})).begins_with("Il faut une pièce neuve"))
	Profile.materials["crystal"] = 0
	check("Reporter : sans cristaux, refusé et rien ne bouge", Forge.report(p[0], p[1]) == "Pas assez de cristaux." and int(p[1].get("upgrade", 0)) == 0 and int(p[0].upgrade) == 7)
	Profile.materials["crystal"] = 5000
	Profile.in_run = true
	check("Reporter : au menu principal seulement", Forge.report_block(p[0], p[1]).begins_with("Au menu principal") and Forge.report_sources(p[1]).is_empty())
	Profile.in_run = false


func _test_report_ui() -> void:
	var p := _pair()
	ForgeBench.fast = true
	var fb := ForgeBench.new()
	add_child(fb)
	await get_tree().process_frame
	fb.refresh()
	fb.bench = "report"
	fb.grid.select_item(p[1])
	fb._on_selection()
	await get_tree().process_frame
	check("Forge : établi « Reporter » (prix en cristaux)", _button_with(fb, "Reporter") != null and fb.detail.get_parsed_text().contains("cristaux"))
	var b := _button_with(fb, "Prendre le +7")
	check("Forge > Reporter : « Prendre le +7 de … (portée) → +5 · prix »", b != null and b.text.contains("(portée) → +5 · ") and b.text.contains("crist"))
	if b:
		b.pressed.emit()
		await get_tree().process_frame
		var ask: InfoCard.Ask = null
		for c in fb.get_children():
			if c is InfoCard.Ask:
				ask = c
		check("Reporter : confirmation (l'ancienne revient à +0)", ask != null and ask.title_label.text == "Reporter le +7 ?")
		if ask:
			ask.ok_button.pressed.emit()
			await get_tree().create_timer(0.3).timeout
			check("Reporter : fait après la barre de forge", int(p[1].upgrade) == 5 and int(p[0].upgrade) == 0 and fb._got_verdict)
	fb.grid.select_item(p[0])
	fb._on_selection()
	await get_tree().process_frame
	check("Reporter : rien à prendre pour l'ancienne : une phrase, pas de bouton", _button_with(fb, "Prendre le") == null and fb.detail.get_parsed_text().contains("Aucune pièce"))
	ForgeBench.fast = false
	fb.queue_free()
	await get_tree().process_frame


func _test_lobby() -> void:
	Training.active = true
	Profile.reset_all()
	Profile.selected_class = "warrior"
	HeroLevel.ensure()
	Profile.records[HeroLevel.KEY] = HeroLevel.total_for(30)
	Profile._lobby_view()
	var it := Items.generate(5, 0.0, "head", "warrior", 1, "", 1)
	Profile.vault.append(it)
	Profile._class_presets("warrior")
	Profile.presets.warrior.sets[1].slots["head"] = String(it.uid)
	Profile.add_title(Siege.TITLE)
	Profile.title = Siege.TITLE
	var lobby: Node = load("res://scenes/lobby.tscn").instantiate()
	add_child(lobby)
	await get_tree().create_timer(1.0).timeout
	lobby._show_menu("survival")
	await get_tree().process_frame
	check("page Survie : la rangée du préréglage épinglée au-dessus de « Lancer »", lobby._foot.find_child("PresetPick", true, false) != null)
	lobby._open_hero("titles")
	await get_tree().process_frame
	var hero: HeroScreen = lobby._hero
	check("Héros > Titres : la section s'ouvre", hero.titles.visible and hero.current == "titles")
	check("Héros : le titre porté sous le nom", hero._worn_title.visible and hero._worn_title.text == "« %s »" % Siege.TITLE)
	hero.step_page(1)
	check("LB / RB : Titres puis Cartes", hero.current == "cards")
	hero.show_section("class")
	await get_tree().process_frame
	check("Héros > Classe : points de talent toujours visibles", hero.talents._points.visible)
	hero.close_ui()
	lobby.queue_free()
	await get_tree().process_frame
