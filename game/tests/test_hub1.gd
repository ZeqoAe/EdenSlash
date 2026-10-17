extends Node
## Lot HUB-1 (backlog P0 de l'étude BM-HUB) : pastilles de nouveauté (NewsDots), « Continuer » (LastActivity), boussole v2
## (Compass.advices, bulle « Ta quête », « Conseillé »), « Aujourd'hui », Journal des quêtes (QuestJournal : onglets, « Y aller »,
## épingle), quête suivie du HUD (QuestBadge.pick), file unique des notifications (HudNotices), réglages du HUD.
## godot --headless --path game res://tests/test_hub1.tscn  (profil de test uniquement)

var fails := 0


func check(label: String, ok: bool) -> void:
	print(("OK    " if ok else "ÉCHEC ") + label)
	if not ok:
		fails += 1


func _frames(n := 2) -> void:
	for i in n:
		await get_tree().process_frame


func _reset() -> void:
	Settings.reset_all()
	Profile.reset_all()
	Profile.selected_class = "warrior"
	Run.active = false
	Run.survival = false
	Training.active = false
	Challenge.reset()
	Quests.set_day("2026-10-15")


func _ready() -> void:
	check("profil de test", Profile.save_path.begins_with("user://profile_test"))
	_test_news()
	_test_compass()
	_test_last()
	_test_pin()
	await _test_notices()
	_test_settings()
	await _test_journal()
	await _test_lobby()
	print("\n%s (%d échec(s))" % ["TOUT EST OK" if fails == 0 else "ÉCHECS", fails])
	get_tree().quit(1 if fails > 0 else 0)


# --- P0-1 : pastilles de nouveauté ------------------------------------------------------------------------------
func _test_news() -> void:
	_reset()
	check("compte neuf : rien de nouveau au premier appel (tout ce qui existe est « vu »)", NewsDots.count("play") == 0 and NewsDots.menu_badge("play") == "")
	check("état rangé dans Profile.records.news (groupes connus)", Profile.records.has("news") and (Profile.records.news.seen as Dictionary).has("hero.look"))
	Profile.unlocked_features.append("dungeons")
	check("une activité qui s'ouvre est nouvelle (Jouer : « 1 »)", NewsDots.activity_new("dungeon") and NewsDots.count("play") == 1 and NewsDots.menu_badge("play") == "1")
	NewsDots.see("act:dungeon")
	check("sa page ouverte : la pastille s'éteint", not NewsDots.activity_new("dungeon") and NewsDots.count("play") == 0)
	Settings.set_v("interface", "dev_mode", true)
	check("le mode dev ouvre tout sans allumer de pastille", NewsDots.count("play") == 0)
	Settings.set_v("interface", "dev_mode", false)
	Profile.owned_outfits.append("hub1_test_look")
	check("apparence débloquée : Héros « 1 »", NewsDots.count("hero.look") == 1 and NewsDots.menu_badge("hero") == "1")
	NewsDots.see_group("hero.look")
	check("Héros > Apparence vue : plus rien", NewsDots.menu_badge("hero") == "")
	# sauvegarde : le vu survit au rechargement
	Profile.achievements["hub1_ach"] = "2026-10-15"
	check("succès gagné : Carnet « 1 »", NewsDots.count("carnet.succes") == 1)
	Profile.save_profile()
	Profile.load_profile()
	check("rechargé : la nouveauté non vue l'est toujours, la vue reste vue", NewsDots.count("carnet.succes") == 1 and NewsDots.count("hero.look") == 0)
	NewsDots.see_group("carnet.succes")
	check("Carnet > Succès vu", NewsDots.count("carnet.succes") == 0)
	# migration : un vieux compte (aucune clé « news ») avec déjà des succès et des apparences : rien ne s'allume
	Profile.records.erase("news")
	Profile.achievements["hub1_old"] = "2026-01-01"
	Profile.owned_outfits.append("hub1_old_look")
	check("migration : vieux compte, aucune pastille d'un coup", NewsDots.count_of(NewsDots.GROUPS) == 0)
	# groupe ajouté plus tard : il naît « tout vu »
	(Profile.records.news.seen as Dictionary).erase("workshop.plan")
	Profile.plans.append("plan_hub1")
	check("groupe absent de l'état : il naît sans nouveauté", NewsDots.count("workshop.plan") == 0)
	# Journal : nouvelles quêtes du jour
	Profile.unlocked_features.append("daily")
	(Profile.records.news.seen as Dictionary).erase("journal.day")
	check("Journal : le premier jour est vu", NewsDots.count("journal.day") == 0)
	Quests.set_day("2026-10-16")
	check("Journal : un nouveau jour allume la pastille", NewsDots.count("journal.day") == 1 and NewsDots.menu_badge("journal") != "")
	NewsDots.see_group("journal.day")
	check("Journal ouvert : éteinte", NewsDots.count("journal.day") == 0)
	Quests.set_day("2026-10-15")


# --- P0-3 : boussole v2 -----------------------------------------------------------------------------------------
func _advanced() -> void:
	_reset()
	Profile.runs_done = 14
	Profile.runs_won = 4
	Profile.unlocked_features = Unlocks.LIST.keys()
	Profile.insignia = 50
	for t in ["gear", "look_rare"]:
		Profile.reward_chests.append(Rewards.make(t, 40))
	Profile.records["epochs_cleared"] = 2


func _test_compass() -> void:
	_reset()
	var a := Compass.advices(3)
	check("compte neuf : un seul conseil, la première Survie", a.size() == 1 and String(a[0].id) == "first_run")
	_advanced()
	a = Compass.advices(3)
	var fams := {}
	for x in a:
		fams[String(x.family)] = true
	check("compte avancé : trois conseils (%s)" % ", ".join(a.map(func(x): return String(x.id))), a.size() == 3)
	check("familles différentes", fams.size() == a.size())
	check("le premier est le conseil de toujours (Compass.advice)", String(a[0].id) == String(Compass.advice().get("id", "")))
	check("chaque conseil a son pourquoi et sa page", a.all(func(x): return String(x.tip) != "" and not (x.go as Dictionary).is_empty()))
	check("Conseillé : l'activité d'un conseil de page (Survie)", Compass.activity_of({"go": {"menu": "zones"}}) == "survival" and Compass.activity_of({"go": {"chests": true}}) == "")
	Profile.in_run = true
	check("en partie : aucun conseil", Compass.advices(3).is_empty())
	Profile.in_run = false


# --- P0-2 : Continuer -------------------------------------------------------------------------------------------
func _test_last() -> void:
	_reset()
	check("rien lancé : pas de « Continuer »", LastActivity.last().is_empty())
	LastActivity.record("survival", {"epoch": 2, "heroic": 0})
	check("Survie retenue avec son époque (%s)" % LastActivity.last().get("label", ""), String(LastActivity.last().label) == "Survie · Époque II")
	LastActivity.record("tower", {"diff": 1, "from": 21})
	check("la Tour : son étage de départ", String(LastActivity.last().label) == "La Tour · étage 21" and int(LastActivity.last().opts.from) == 21)
	Profile.save_profile()
	Profile.load_profile()
	check("gardée dans la sauvegarde", String(LastActivity.last().get("id", "")) == "tower")
	Profile.records["last_activity"] = {"id": "inconnue"}
	check("une activité qui n'existe plus : rien", LastActivity.last().is_empty())


# --- P0-5 / P0-6 : épingle, quête du HUD ------------------------------------------------------------------------
func _quests_on() -> void:
	_reset()
	Profile.unlocked_features.append("daily")
	Profile.runs_done = 5


func _test_pin() -> void:
	_quests_on()
	var daily: Array = Quests.daily()
	check("quêtes ouvertes : trois du jour", daily.size() == 3)
	var q: Dictionary = daily[1]
	check("rien d'épinglé au départ", Quests.pinned().is_empty())
	check("épingler une quête", Quests.toggle_pin("daily", q) and Quests.is_pinned("daily", q) and String(Quests.pinned().q.id) == String(q.id))
	check("une seule épinglée", not Quests.is_pinned("daily", daily[2]))
	Quests.toggle_pin("daily", daily[2])
	check("en épingler une autre remplace la première", Quests.is_pinned("daily", daily[2]) and not Quests.is_pinned("daily", q))
	# HUD : la quête suivie en partie (pick) ; une quête d'une autre activité se lit sans progression en direct
	Run.active = true
	Run.survival = true
	Run.started_at = Time.get_ticks_msec()
	var p := QuestBadge.pick()
	check("HUD : la quête épinglée est celle qu'on suit", not p.is_empty() and bool(p.pinned) and String(p.q.id) == String(daily[2].id))
	daily[2]["done"] = true
	p = QuestBadge.pick()
	check("épinglée accomplie : le HUD revient à la plus avancée de l'activité", p.is_empty() or not bool(p.pinned))
	Run.active = false
	Run.survival = false
	check("Y aller : la page de l'activité ; une quête de variété mène à Jouer", Quests.go_of({"id": "tx_acts"}).get("menu", "") == "play")
	check("heure de renouvellement en clair", Quests.renew_text().contains("h") or Quests.renew_text().contains("min"))


# --- P0-7 : une seule file de notifications --------------------------------------------------------------------
func _test_notices() -> void:
	var host := Control.new()
	host.size = Vector2(1280, 720)
	add_child(host)
	var stack := InfoCard.in_control(host)
	var held := [true]
	var n := HudNotices.new(stack, func(): return held[0])
	n.push("news", {"id": "n1", "title": "Nouveauté", "body": "x"})
	n.push("quest", {"id": "q1", "title": "Quête accomplie", "body": "y"})
	check("bandeau affiché (danger) : aucune carte ne sort", stack.count() == 0 and n.pending() == 2)
	held[0] = false
	n.tick()
	check("bandeau parti : la quête passe avant la nouveauté", stack.ids() == ["q1"] and n.shown == ["quest"])
	n.tick()
	check("une seule carte à la fois", stack.count() == 1 and n.pending() == 1)
	stack.dismiss("q1")
	await get_tree().create_timer(0.5).timeout
	n.tick()
	check("la suivante sort quand la première part", stack.ids().has("n1") and n.pending() == 0)
	host.queue_free()


# --- P0-9 : réglages du HUD -------------------------------------------------------------------------------------
func _test_settings() -> void:
	Settings.reset_all()
	check("HUD : taille et opacité par défaut à 1", float(Settings.get_v("interface", "hud_scale")) == 1.0 and float(Settings.get_v("interface", "hud_opacity")) == 1.0)
	check("touche du Journal : L, sans conflit avec l'attaque (J)", InputMap.has_action("journal") and Settings.action_label("journal", 1) == "L")
	check("plus de « RTS / MOBA » ni de « Bot » dans les modes", not String(Settings.PRESETS.rts.name).contains("RTS") and not String(Settings.PRESETS.bot.name).contains("Bot")
		and String(Settings.ASSIST.bot.tag) != "BOT")


# --- P0-5 : le Journal ------------------------------------------------------------------------------------------
func _test_journal() -> void:
	_quests_on()
	get_tree().root.size = Vector2i(1280, 720)
	var went := [{}]
	var j := QuestJournal.open_on(self, 0, func(g): went[0] = g, func(_c): pass)
	await _frames(3)
	check("Journal : ouvert, 5 onglets", j.is_open() and j.page_count() == 5)
	var page: Control = j.page(0)
	var buttons := _buttons(page)
	var pins := buttons.filter(func(b): return String(b.text).contains("Suivre"))
	var gos := buttons.filter(func(b): return String(b.text) == "Y aller")
	check("Aujourd'hui : une épingle par quête non faite (%d)" % pins.size(), pins.size() == 3)
	check("Aujourd'hui : « Y aller » (%d)" % gos.size(), gos.size() >= 2)
	pins[0].pressed.emit()
	await _frames(2)
	check("épingle : la quête est suivie et la page se redessine (« ★ Suivie »)", not Quests.pinned().is_empty()
		and _buttons(j.page(0)).any(func(b): return String(b.text).contains("Suivie")))
	var go_b: Button = _buttons(j.page(0)).filter(func(b): return String(b.text) == "Y aller")[0]
	go_b.pressed.emit()
	check("Y aller : le Journal se ferme et donne la page de l'activité", not j.is_open() and not (went[0] as Dictionary).is_empty())
	j.open(3)
	await _frames(2)
	check("onglet Série : les paliers", _texts(j.page(3)).contains("Paliers de la série"))
	j.open(4)
	await _frames(2)
	check("onglet Terminées : un mot quand rien n'est fait", _texts(j.page(4)).contains("Aucune quête accomplie"))
	# en partie : ni « Y aller » ni lanceur
	j.close_ui()
	var j2 := QuestJournal.open_on(self, 0)
	await _frames(2)
	check("sans page où aller (en partie) : pas de « Y aller »", _buttons(j2.page(0)).filter(func(b): return String(b.text) == "Y aller").is_empty())
	var vp := get_viewport().get_visible_rect().size
	var cut := _buttons(j2.page(0)).filter(func(b): return b.is_visible_in_tree() and (b.get_global_rect().end.x > vp.x + 1.0))
	check("Journal : tient dans 1280 x 720 en largeur", cut.is_empty())
	j2.close_ui()
	j2.queue_free()


# --- menu principal ---------------------------------------------------------------------------------------------
func _test_lobby() -> void:
	_advanced()
	Profile.unlocked_features.append("daily")
	Quests.set_day("2026-10-15")
	LastActivity.record("survival", {"epoch": 1})
	get_tree().root.size = Vector2i(1280, 720)
	var lobby: Node = load("res://scenes/lobby.tscn").instantiate()
	add_child(lobby)
	await get_tree().create_timer(1.2).timeout
	check("Continuer : visible sous Jouer, avec la dernière activité", lobby._continue.visible and String(lobby._continue.get("_label").text).contains("Survie"))
	check("Aujourd'hui : visible, trois quêtes et le bouton Journal", lobby._today.visible and lobby._today.quest_buttons.size() == 3 and lobby._today.journal_button != null)
	check("bulle « Ta quête » : un conseil, « Y aller », deux autres choix au plus", lobby._bubble.visible and lobby._compass.is_visible_in_tree()
		and lobby._bubble.alt_buttons.size() >= 1 and lobby._bubble.alt_buttons.size() <= 2)
	var vp := get_viewport().get_visible_rect().size
	var col: Rect2 = lobby._right_col.get_global_rect()
	check("colonne de droite dans l'écran (fin %d sur %d)" % [col.end.y, vp.y], col.end.y <= vp.y - 80.0 and col.end.x <= vp.x)
	var left_end: float = lobby._menu["quit"].get_global_rect().end.y
	check("menu de gauche au-dessus du panneau de zone (%d < %d)" % [left_end, lobby._zone_card.get_global_rect().position.y], left_end < lobby._zone_card.get_global_rect().position.y)
	lobby._show_menu("play")
	await _frames(2)
	var tags := _find(lobby._sub, "AdvisedTag")
	var adv_act := Compass.activity_of(lobby._advices[0]) if not lobby._advices.is_empty() else ""
	check("Jouer : « Conseillé » sur l'activité de la bulle (%s)" % adv_act, adv_act == "" or tags.size() == 1)
	check("Jouer : plus de carte Quêtes (elles sont le Journal)", not _texts(lobby._sub).contains("Quêtes\n"))
	check("Jouer : la colonne de droite laisse la place à la page à 1280", not lobby._right_col.visible)
	lobby._show_menu("quests")
	await _frames(2)
	check("« quests » ouvre le Journal", lobby._journal != null and lobby._journal.is_open() and lobby._current == "")
	lobby._journal.close_ui()
	var ev := InputEventAction.new()
	ev.action = "journal"
	ev.pressed = true
	lobby._unhandled_input(ev)
	check("touche du Journal au menu principal", lobby._journal.is_open())
	lobby._journal.close_ui()
	# Continuer : le Duel passe par sa page, avec son onglet (la Survie se lancerait : la scène changerait sous le test)
	LastActivity.record("duel", {"tab": "league"})
	lobby._refresh_ui()
	check("Continuer : le libellé suit la dernière activité", String(lobby._continue.get("_label").text).contains("Duel"))
	lobby._continue_last()
	await _frames(2)
	check("Continuer (Duel) : sa page s'ouvre sur l'onglet retenu", lobby._current == "duel" and lobby._duel_tab == "league" and not lobby._launching)
	lobby.queue_free()
	await _frames(2)


func _buttons(n: Node) -> Array:
	var out: Array = []
	if n is Button:
		out.append(n)
	for c in n.get_children():
		out.append_array(_buttons(c))
	return out


func _texts(n: Node) -> String:
	var out := PackedStringArray()
	_collect(n, out)
	return "\n".join(out) + "\n"


func _collect(n: Node, out: PackedStringArray) -> void:
	if n is Label:
		out.append((n as Label).text)
	elif n is Button:
		out.append((n as Button).text)
	for c in n.get_children():
		_collect(c, out)


func _find(n: Node, name: String) -> Array:
	var out: Array = []
	if String(n.name) == name:
		out.append(n)
	for c in n.get_children():
		out.append_array(_find(c, name))
	return out
