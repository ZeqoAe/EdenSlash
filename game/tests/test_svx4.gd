extends Node
## Lot SVX-4 du Survivant (BM-SURV : SV-R1 faveurs, SV-R2 pièces maudites, SV-R3 boutique du gardien, SV-A1 accessibilité,
## SV-Q1 partie du jour, SV-Q2 prolongations, SV-Q3 choix regroupés, SV-Q4 reprise, SV-Q6 fiches du Codex) : règles pures,
## écrans à 1280 × 720 et 1600 × 900, puis une vraie partie (boutique après un gardien, sauvegarde et reprise, choix regroupés,
## prolongations après le boss) ; rien du compte n'est touché (mode scellé).
## godot --headless --path game res://tests/test_svx4.tscn

const WORLD := "res://scenes/world.tscn"

var fails := 0


func check(label: String, ok: bool) -> void:
	print(("OK    " if ok else "ÉCHEC ") + label)
	if not ok:
		fails += 1


func _ready() -> void:
	if name == "Svx4Driver":
		_run.call_deferred()
		return
	var d: Node = (load("res://tests/test_svx4.gd") as GDScript).new()
	d.name = "Svx4Driver"
	get_tree().root.add_child.call_deferred(d)


func _wait(secs: float) -> void:
	await get_tree().create_timer(secs, true, false, true).timeout


func _until(cond: Callable, limit: float, label := "") -> bool:
	var t := 0.0
	while t < limit:
		if cond.call():
			return true
		await _wait(0.1)
		t += 0.1
	if label != "":
		print("   (délai dépassé : %s)" % label)
	return cond.call()


func _run() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Settings.reset_all()
	Profile.selected_class = "warrior"
	Profile.reset_all()
	Profile.in_run = false
	SurvivorSave.clear()
	SurvivorCards.seed_with(41)
	seed(41)
	_settings()
	_curses()
	_shop_rules()
	_favors()
	_daily()
	_records()
	_save_format()
	_shapes()
	await _picker_group()
	await _shop_screen()
	await _codex_fiche()
	await _world_run()
	print("\n%s (%d échec(s))" % ["TOUT EST OK" if fails == 0 else "ÉCHECS", fails])
	Engine.time_scale = 1.0
	get_tree().paused = false
	SurvivorSave.clear()
	Profile.reset_all()
	get_tree().quit(1 if fails > 0 else 0)


func _start() -> void:
	Survivor.start("warrior", "limestone", 1, "")
	Run.hero_level = 20


func _end() -> void:
	Run.finish("abandon")
	Profile.end_run_survival()


# --- réglages ----------------------------------------------------------------------------------------------------------------
func _settings() -> void:
	var keys := ["number_size", "calm_fx", "alert_captions", "horde_contrast", "sv_speed", "sv_group_choices"]
	check("réglages d'accessibilité et de confort présents, coupés par défaut (vitesse × 1, nombres × 1)",
		keys.all(func(k): return Settings.DEFAULTS.interface.has(k)) and not bool(Settings.get_v("interface", "calm_fx"))
		and is_equal_approx(float(Settings.get_v("interface", "sv_speed")), 1.0) and is_equal_approx(DamageNumber.size_mult(), 1.0))
	Settings.set_v("interface", "number_size", 1.3)
	check("taille des nombres : × %.1f" % DamageNumber.size_mult(), is_equal_approx(DamageNumber.size_mult(), 1.3))
	Settings.set_v("interface", "number_size", 1.0)
	Settings.set_v("interface", "calm_fx", true)
	check("« Réduire effets et secousses » : étincelles réduites, menus sans rebond", Settings.fx_particles() == "reduced" and UiFeel.reduce_motion)
	Settings.set_v("interface", "calm_fx", false)
	check("… et tout revient quand on le coupe", Settings.fx_particles() == "all" and not UiFeel.reduce_motion)
	SurvivorHud.caption("Grondement : un gardien approche")  # (sans HUD : rien, sans erreur)
	check("sous-titre d'alerte sans HUD : rien ne casse", true)


# --- pièces maudites ------------------------------------------------------------------------------------------------------------
func _curses() -> void:
	_start()
	var n := 0
	var cursed := 0
	var weapons_cursed := 0
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 1500:
		var it := SurvivorGear.make_piece(["head", "chest", "legs", "gloves", "boots", "back", "necklace", "ring"][i % 8], {"rng": rng})
		if it.is_empty():
			continue
		n += 1
		cursed += 1 if it.has("sv_curse") else 0
	for i in 300:
		var w := SurvivorGear.make_weapon(SurvivorPool.weapon_types()[i % SurvivorPool.weapon_types().size()], {"rng": rng})
		weapons_cursed += 1 if w.has("sv_curse") else 0
	var part := float(cursed) / maxf(float(n), 1.0)
	check("pièces maudites : %d sur %d (%.1f %%, visé 1 sur %d), jamais une arme (%d)" % [cursed, n, part * 100.0, int(Survivor.CURSE_EVERY), weapons_cursed],
		part > 0.6 / Survivor.CURSE_EVERY and part < 1.6 / Survivor.CURSE_EVERY and weapons_cursed == 0)
	var p := Player.new()
	add_child(p)
	p.recalc_stats()
	var base := {"dmg": p.dmg_mult, "hp": p.max_hp}
	var piece := SurvivorGear.make_piece("head", {"rng": rng})
	piece.erase("sv_curse")
	SurvivorGear.curse(piece, "avide")
	check("malédiction : jet parfait", SurvivorGear.is_perfect(piece))
	var card := SurvivorCards.piece_card(piece)
	check("la carte écrit le bonus et sa contrepartie (« %s »)" % String(card.desc).get_slice("Maudite", 1).left(60), String(card.desc).contains("Maudite · Lame avide") and String(card.desc).contains("PV max −25 %"))
	var view := VBoxContainer.new()
	SurvivorCardView.build_v2(view, card, SurvivorCardView.tones_of(card))
	var boxed := view.find_children("*", "Label", true, false).any(func(l): return (l as Label).text.begins_with("Maudite · Lame avide"))
	check("carte v2 : encadré « Maudite · Lame avide »", boxed)
	view.free()
	SurvivorGear.equip(piece)
	p.recalc_stats()
	var with_piece_hp := p.max_hp
	check("portée : dégâts × 1,3 (%.2f → %.2f)" % [base.dmg, p.dmg_mult], absf(p.dmg_mult - base.dmg * 1.3) < 0.02 or p.dmg_mult > base.dmg * 1.25)
	check("portée : PV max réduits malgré la pièce (%d → %d)" % [roundi(base.hp), roundi(with_piece_hp)], with_piece_hp < base.hp + float(Items.stats(piece).get("hp", 0.0)) * 0.9)
	check("curses_worn : %s" % str(SurvivorGear.curses_worn()), SurvivorGear.curses_worn() == ["avide"])
	p.free()
	_end()
	check("hors Survivant : jamais maudite", not SurvivorGear.make_piece("head", {"rng": rng}).has("sv_curse"))


# --- boutique du gardien (règles) ------------------------------------------------------------------------------------------------
func _shop_rules() -> void:
	_start()
	Run.apply_card(SurvivorCards.weapon_card())
	for s in SurvivorCards.spells_open().slice(0, 2):
		Run.apply_card(SurvivorCards.spell_card(int(s.id)))
	Run.apply_card(SurvivorCards.new_piece_card("head"))
	Profile.gold = 50000
	var offers := SurvivorShop.open()
	check("boutique : %d offres, aucune carte de repli" % offers.size(), offers.size() == SurvivorShop.OFFERS
		and offers.all(func(o): return SurvivorCards.FAMILY.get(String(o.card.get("type", "")), "") != "fallback"))
	var keys := {}
	for o in offers:
		keys[String(o.card.get("sv_key", ""))] = true
	check("jamais deux offres sur la même cible", keys.size() == offers.size())
	var p0 := int(offers[1].price)
	var g0 := Profile.gold
	check("achat : l'or baisse du prix, la carte est prise", SurvivorShop.buy(offers[0]) and Profile.gold == g0 - int(offers[0].price) and bool(offers[0].sold))
	check("chaque achat renchérit les suivants (%d → %d)" % [p0, int(offers[1].price)], int(offers[1].price) > p0 or bool(offers[1].sold))
	check("une offre achetée ne se rachète pas", not SurvivorShop.buy(offers[0]))
	var r0 := SurvivorShop.reroll_price()
	SurvivorShop.toggle_keep(offers[2])
	var kept_key := String(offers[2].card.get("sv_key", ""))
	check("relance payée, prix × %.1f (%d → %d)" % [SurvivorShop.REROLL_STEP, r0, SurvivorShop.reroll_price()], SurvivorShop.reroll() and SurvivorShop.reroll_price() > r0)
	check("la relance garde l'offre gardée", SurvivorShop.offers.any(func(o): return String(o.card.get("sv_key", "")) == kept_key))
	SurvivorShop.close(300.0)
	check("fermée : l'offre gardée attend la boutique suivante", SurvivorShop.kept.size() == 1)
	var next := SurvivorShop.open()
	check("boutique suivante : l'offre gardée en tête, relance au prix de base", not next.is_empty() and bool(next[0].kept) and SurvivorShop.rerolls == 0)
	SurvivorShop.close(600.0)
	Profile.gold = 0
	check("« Passer » : or entier tant que l'or ne déborde pas", is_equal_approx(SurvivorShop.skip_mult(0), 1.0) and is_equal_approx(SurvivorShop.skip_mult(int(SurvivorShop.SKIP_FULL)), 1.0))
	check("« Passer » : moins quand l'or déborde (× %.2f à 12 000 or), jamais sous × 0,25" % SurvivorShop.skip_mult(12000),
		SurvivorShop.skip_mult(12000) < 0.5 and SurvivorShop.skip_mult(1000000) >= 0.25)
	check("coffres plus chers avec le temps (× %.2f à 10:00)" % SurvivorShop.chest_mult(10.0), SurvivorShop.chest_mult(10.0) > 1.1 and is_equal_approx(SurvivorShop.chest_mult(0.0), 1.0))
	Profile.gold = 100000
	SurvivorShop.open()
	var bought0 := SurvivorShop.spent
	SurvivorShop.pilot()
	check("pilote : il achète (%d or)" % (SurvivorShop.spent - bought0), SurvivorShop.spent > bought0)
	SurvivorShop.close(900.0)
	_end()
	_start()
	check("nouvelle partie : boutique remise à zéro", SurvivorShop.visits == 0 and SurvivorShop.kept.is_empty() and SurvivorShop.spent == 0)
	_end()


# --- faveurs ------------------------------------------------------------------------------------------------------------------------
func _favors() -> void:
	var open := SurvivorFavors.LIST.filter(func(f): return SurvivorFavors.is_open(String(f.id)))
	check("compte neuf : %d faveurs ouvertes (sans faveur compris : une parmi trois)" % open.size(), open.size() == 3)
	check("les autres disent leur défi (« %s »)" % SurvivorFavors.unlock_text("tresor"), SurvivorFavors.unlock_text("tresor").begins_with("Défi du mode"))
	check("chaque faveur a sa règle et son détail", SurvivorFavors.LIST.all(func(f): return String(f.rule) != "" and SurvivorFavors.tip(String(f.id)) != ""))
	SurvivorFavors.choose("tresor")
	check("une faveur fermée ne se choisit pas", SurvivorFavors.chosen() == "")
	SurvivorFavors.choose("horde")
	check("choix gardé dans l'état du mode (« %s »)" % SurvivorFavors.chosen(), SurvivorFavors.chosen() == "horde")
	var a0 := int(SurvivorDirector.spawn_plan(600.0).alive_max)
	Survivor.start("warrior", "limestone")
	check("la page du mode lance la faveur choisie", SurvivorFavors.current == "horde")
	check("Horde affamée : vivants × %.2f (%d → %d), or × 2" % [SurvivorFavors.mult("horde"), a0, int(SurvivorDirector.spawn_plan(600.0).alive_max)],
		int(SurvivorDirector.spawn_plan(600.0).alive_max) > a0 and is_equal_approx(SurvivorFavors.mult("gold"), 2.0))
	_end()
	Survivor.start("warrior", "limestone", 1, "etoile")
	check("Bonne étoile : +3 relances, +2 bannissements (%d, %d)" % [SurvivorCards.rerolls_left(), SurvivorCards.bans_left()],
		SurvivorCards.rerolls_left() == int(Survivor.rule("base_rerolls")) + 3 and SurvivorCards.bans_left() == int(Survivor.rule("bans")) + 2)
	_end()
	Survivor.start("warrior", "limestone", 1, "verre")
	var p := Player.new()
	add_child(p)
	p.recalc_stats()
	var dmg := p.dmg_mult
	var hp := p.max_hp
	SurvivorFavors.current = ""
	p.recalc_stats()
	check("Canon de verre : dégâts × 1,3, PV × 0,7", absf(dmg / p.dmg_mult - 1.3) < 0.01 and absf(hp / p.max_hp - 0.7) < 0.02)
	p.free()
	_end()
	check("hors Survivant : aucune faveur", is_equal_approx(SurvivorFavors.mult("horde"), 1.0) and SurvivorFavors.extra("rerolls") == 0)
	SurvivorFavors.choose("")


# --- partie du jour ---------------------------------------------------------------------------------------------------------------
func _daily() -> void:
	check("partie du jour : même graine, même zone, même classe pour un jour donné",
		SurvivorDaily.seed_of("2026-10-17") == SurvivorDaily.seed_of("2026-10-17") and SurvivorDaily.zone_of("2026-10-17") in Survivor.zones()
		and SurvivorDaily.class_of("2026-10-17") in Progression.START_CLASSES)
	var days := {}
	for d in ["2026-10-17", "2026-10-18", "2026-10-19", "2026-10-20", "2026-10-21"]:
		days[SurvivorDaily.seed_of(d)] = true
	check("une graine différente chaque jour", days.size() == 5)
	SurvivorDaily.start()
	check("lancée : carte et tirages du jour, palier I, sans faveur", SurvivorDaily.active and Run.seed == SurvivorDaily.seed_of() and Survivor.palier == 1 and SurvivorFavors.current == "")
	var st := {}
	var ranks: Array = []
	for t in [400.0, 900.0, 1300.0, 200.0, 1100.0, 600.0]:
		SurvivorDaily.active = true
		SurvivorRewards.stats = {"time": t}
		ranks.append(SurvivorDaily.settle(st, "victoire" if t == 1300.0 else "defaite"))
	var runs: Array = st.daily.runs
	check("tableau : 5 parties au plus, la victoire en tête (%s)" % str(runs.map(func(e): return int(e.time))), runs.size() == 5 and String(runs[0].res) == "victoire")
	check("rangs rendus, la 6e partie fait sortir la moins bonne (%s)" % str(ranks), int(ranks[2]) == 1 and int(ranks[3]) == 4 and int(ranks[4]) == 2
		and is_equal_approx(float(runs.back().time), 400.0))
	_end()


# --- records : prolongations, vitesse ----------------------------------------------------------------------------------------
func _records() -> void:
	check("record « Plus longue prolongation »", "endless" in SurvivorRecords.KEYS and SurvivorRecords.fmt("endless", 95.0) == "1:35")
	_start()
	SurvivorRewards.stats = {"time": 1290.0, "endless": 80.0}
	check("la partie verse sa prolongation aux records", float(SurvivorRecords.run_values("victoire").get("endless", 0.0)) == 80.0)
	var st := {}
	Survivor.speed = 1.2
	SurvivorRecords.settle(st, "victoire", 1)
	check("vitesse × 1,2 : aucun record posé", (st.get("best", {}).get("warrior:1", {}) as Dictionary).is_empty())
	Survivor.speed = 1.0
	SurvivorRecords.settle(st, "victoire", 1)
	check("vitesse × 1 : records posés", not (st.get("best", {}).get("warrior:1", {}) as Dictionary).is_empty())
	_end()


func _save_format() -> void:
	var t := var_to_str({"v": SurvivorSave.VERSION, "chains": {0: [{"id": 5, "rank": 2}]}})
	var back: Variant = str_to_var(t)
	check("sauvegarde : texte lisible, types gardés (clés entières des enchaînements)", SurvivorSave._valid(t) and back is Dictionary
		and (back.chains as Dictionary).has(0) and typeof(back.chains[0][0].rank) == TYPE_INT)
	check("sauvegarde : un texte abîmé n'est pas pris", not SurvivorSave._valid("{ \"v\": 1, ") and not SurvivorSave._valid(""))


func _shapes() -> void:
	var it := {"rarity": 3}
	check("forme de la rareté : rond, carré, losange, étoile…", SurvivorCardView.shape_rank({"type": "sv_piece", "item": it}) == 3
		and SurvivorCardView.shape_rank({"type": "upgrade", "tier": "legendary"}) == 5 and SurvivorCardView.shape_rank({"type": "skill"}) == -1)


# --- choix regroupés ----------------------------------------------------------------------------------------------------------
func _picker_group() -> void:
	_start()
	Run.apply_card(SurvivorCards.weapon_card())
	Settings.set_v("interface", "sv_group_choices", true)
	var pk := SurvivorPicker.new()
	add_child(pk)
	await _wait(0.1)
	var roll := func(): return Run.roll_cards(3)
	pk.offer("Niveau 5 ! Choisis une carte", Run.roll_cards(3), roll)
	pk.offer("Niveau 6 ! Choisis une carte", Run.roll_cards(3), roll)
	check("choix regroupés : les montées attendent sans pause (%d en attente)" % pk.held(), not pk.is_open() and pk.held() == 2 and not get_tree().paused)
	pk.offer("Coffre doré : choisis une carte", SurvivorCards.chest_cards("sv_gold"), roll)
	check("un coffre ouvert passe devant et ouvre la file", pk.is_open() and pk._raw_title.begins_with("Coffre"))
	pk._queue.clear()
	pk._show_next()
	pk.offer("Niveau 7 ! Choisis une carte", Run.roll_cards(3), roll)
	check("on les ouvre quand on veut", pk.held() == 1 and pk.open_held() and pk.is_open())
	pk._queue.clear()
	pk._show_next()
	Settings.set_v("interface", "sv_group_choices", false)
	pk.offer("Niveau 8 ! Choisis une carte", Run.roll_cards(3), roll)
	check("réglage coupé : la montée s'ouvre tout de suite", pk.is_open())
	pk._queue.clear()
	pk._show_next()
	pk.queue_free()
	get_tree().paused = false
	_end()


# --- écran de la boutique -------------------------------------------------------------------------------------------------------
func _shop_screen() -> void:
	for res in [Vector2i(1280, 720), Vector2i(1600, 900)]:
		get_tree().root.size = res
		_start()
		Run.apply_card(SurvivorCards.weapon_card())
		for s in SurvivorCards.spells_open().slice(0, 3):
			Run.apply_card(SurvivorCards.spell_card(int(s.id)))
		for slot in ["head", "chest"]:
			Run.apply_card(SurvivorCards.new_piece_card(slot))
		Profile.gold = 4000
		var ui := SurvivorShopUI.new()
		add_child(ui)
		ui.open_shop(300.0)
		await _wait(0.4)
		var vr := Rect2(Vector2.ZERO, Vector2(res))
		var buys: Array = ui._cols.map(func(c): return c.buy)
		var all_in := ui._cols.all(func(c): return vr.grow(1.0).encloses((c.buy as Button).get_global_rect()) and vr.grow(1.0).encloses((c.keep as Button).get_global_rect()))
		check("boutique à %d × %d : %d offres, tout tient (relancer, continuer, acheter, garder)" % [res.x, res.y, buys.size()],
			buys.size() == SurvivorShop.OFFERS and all_in and vr.grow(1.0).encloses(ui._reroll.get_global_rect()) and vr.grow(1.0).encloses(ui._go.get_global_rect()))
		check("jeu en pause pendant la boutique", get_tree().paused and ui.is_open())
		var g0 := Profile.gold
		ui._do_buy(0)
		await _wait(0.1)
		check("acheter (touche 1) : or %d → %d, « Achetée ! »" % [g0, Profile.gold], Profile.gold < g0 and String((ui._cols[0].buy as Button).text).begins_with("Achetée"))
		ui._do_keep(1)
		check("garder : « Gardée pour la suivante »", String((ui._cols[1].keep as Button).text).begins_with("Gardée"))
		ui.close_shop()
		check("continuer : la partie reprend, l'offre gardée attend", not get_tree().paused and SurvivorShop.kept.size() == 1)
		ui.queue_free()
		_end()
	get_tree().root.size = Vector2i(1600, 900)


# --- fiches du Codex ----------------------------------------------------------------------------------------------------------
func _codex_fiche() -> void:
	var page := SurvivorCodexPage.open_on(self, SurvivorCodexPage.TABS.size() - 1)
	await _wait(0.3)
	check("Codex : onglet « Sorts » en dernier (les autres gardent leur place)", String(SurvivorCodexPage.TABS[SurvivorCodexPage.TABS.size() - 1][0]) == "spells"
		and String(SurvivorCodexPage.TABS[4][0]) == "records")
	var ws := SurvivorCodexPage.Fiche.weapon_sheet("axe")
	check("fiche d'arme : ses deux auto-attaques et son évolution (%d lignes)" % (ws.lines as Array).size(), (ws.lines as Array).size() >= 5
		and "\n".join(ws.lines).contains("Évolution"))
	var sk: Dictionary = GameData.class_data("warrior").get("skills", [{}])[0]
	var ss := SurvivorCodexPage.Fiche.spell_sheet(int(sk.get("id", 0)))
	check("fiche de sort : ce qu'il fait, ses paliers, les évolutions de sort", String(ss.title) == String(sk.get("name", "")) and "\n".join(ss.lines).contains("niveau 10"))
	var f := SurvivorCodexPage.Fiche.open_on(self, "weapon", "axe")
	await _wait(0.2)
	check("la fiche s'ouvre par-dessus le Codex", is_instance_valid(f) and f.layer > SurvivorCodexPage.LAYER)
	f.queue_free()
	page.close_ui()
	page.queue_free()
	await _wait(0.1)


# --- vraie partie -----------------------------------------------------------------------------------------------------------------
func _world() -> Node:
	var s := get_tree().current_scene
	if s != null and s.has_method("end_run") and s.get("director") != null and s.director.player != null and s.get("hud") != null:
		return s
	return null


func _world_run() -> void:
	get_tree().paused = false
	Profile.in_run = false
	Settings.set_v("interface", "alert_captions", true)
	Survivor.start("warrior", "limestone", 1, "")
	get_tree().change_scene_to_file.call_deferred(WORLD)
	await _wait(0.5)
	if not await _until(func(): return _world() != null, 90.0, "monde"):
		check("monde du Survivant chargé", false)
		return
	var w := _world()
	if await _until(func(): return w.cards.is_open(), 90.0, "choix de départ"):
		w.cards._opened_at -= CardPicker.CONFIRM_DELAY_MS
		w.cards._choose(0)
	w.player.dev_invincible = true
	var d: RunDirector = w.director
	await _wait(0.5)
	# gardien vaincu -> coffre -> boutique
	Profile.gold = 3000
	var g := d.sv.spawn_guardian(0)
	await _wait(0.3)
	check("sous-titre de l'alerte au HUD (« %s »)" % (SurvivorHud.current.captions.lines.back().text if SurvivorHud.current != null and not SurvivorHud.current.captions.lines.is_empty() else ""),
		SurvivorHud.current != null and SurvivorHud.current.captions.lines.any(func(l): return String(l.text).contains("gardien")))
	g.take_damage(g.max_hp * 10.0, w.player)
	if await _until(func(): return w.cards.is_open(), 10.0, "coffre du gardien"):
		w.cards._opened_at -= CardPicker.CONFIRM_DELAY_MS
		w.cards._choose(0)
	var shown := await _until(func(): return d.sv.shop_ui != null and d.sv.shop_ui.is_open(), 10.0, "boutique")
	check("gardien vaincu, coffre choisi : la boutique du gardien s'ouvre", shown)
	if shown:
		d.sv.shop_ui._do_buy(0)
		d.sv.shop_ui.close_shop()
	await _wait(0.3)
	# choix regroupés en vraie partie
	Settings.set_v("interface", "sv_group_choices", true)
	w._on_level_up(w.player.level + 1)
	await _wait(0.3)
	check("montée de niveau regroupée : pastille « %s »" % SurvivorHud.current.pending.text, not w.cards.is_open() and SurvivorHud.current.pending.visible)
	w.cards.open_held()
	await _wait(0.2)
	if w.cards.is_open():
		w.cards._opened_at -= CardPicker.CONFIRM_DELAY_MS
		w.cards._choose(0)
	Settings.set_v("interface", "sv_group_choices", false)
	await _wait(0.3)
	# sauvegarde puis reprise (7:00 : le 1er gardien est passé, l'événement suivant est l'annonce du 2e)
	d.sv._next = 2
	d.time = 420.0
	await _wait(0.2)
	var lv: int = w.player.level
	var pieces := SurvivorGear.worn().size()
	var skills := Run.all_skills().size()
	check("on peut sauver en exploration (« %s »)" % SurvivorSave.blocked(d), SurvivorSave.blocked(d) == "")
	check("sauver : fichier écrit", SurvivorSave.save(d) and SurvivorSave.exists())
	var pk := SurvivorSave.peek()
	check("la page du mode lit la sauvegarde (7:00, niveau %d)" % int(pk.get("level", 0)), int(pk.get("level", 0)) == lv and int(float(pk.get("time", 0))) == 420)
	var reward_chests := Profile.reward_chests.size()
	var wid := w.get_instance_id()
	Run.finish(SurvivorSave.RESULT)
	Profile.end_run_survival()
	check("quitter après la sauvegarde : ni coffre ni bilan réglé", Profile.reward_chests.size() == reward_chests)
	get_tree().paused = false
	check("reprendre : la sauvegarde s'efface", SurvivorSave.resume() and not SurvivorSave.exists())
	get_tree().change_scene_to_file.call_deferred(WORLD)
	await _wait(0.5)
	if not await _until(func(): return _world() != null and _world().get_instance_id() != wid, 90.0, "monde repris"):
		check("monde repris chargé", false)
		return
	w = _world()
	d = w.director
	await _wait(1.0)
	check("partie reprise à %s (sauvée à 7:00), niveau %d (%d)" % [SurvivorDirector.clock(d.time), w.player.level, lv], d.time >= 419.0 and w.player.level == lv)
	check("équipement, sorts et gardien passé repris (%d pièces, %d sorts, %d gardien)" % [SurvivorGear.worn().size(), Run.all_skills().size(), d.sv.guardians_killed()],
		SurvivorGear.worn().size() == pieces and Run.all_skills().size() == skills and d.sv.guardians_killed() == 1)
	check("pas de choix de départ à la reprise", not w.cards.is_open() or not w.cards._cards.any(func(c): return bool(c.get("sv_first", false))))
	# prolongations après le boss
	w.player.dev_invincible = true
	d.state = "cleared"
	Survivor.boss_down = true
	d.sv.start_endless()
	w.player.dev_invincible = false
	await _wait(4.0)
	check("prolongations : la horde revient (%d monstres)" % get_tree().get_nodes_in_group("monsters").size(), d.sv.endless and get_tree().get_nodes_in_group("monsters").size() > 0)
	w.player.statuses.erase("angel")
	await _until(func(): return not Run.active, 10.0, "fin des prolongations")
	check("première chute : la partie se clôt, gagnée (%s)" % Run.result, Run.result == "victoire" and float(SurvivorRewards.stats.get("endless", 0.0)) > 0.0)
	await _wait(0.5)
	get_tree().paused = false
	Profile.end_run_survival()
	Settings.set_v("interface", "alert_captions", false)
