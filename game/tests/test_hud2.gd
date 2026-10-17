extends Node
## Lot HUD-2 : HUD en partie v2 (Survie, Donjon, Tour, Duel). Pièces (jauge de vie, barre de niveau sans pourcentage, cases
## à touche dessinée, cadre papier de la mini-carte, éclat de l'arme rangée), colonne de droite (mini-carte, compteur de
## dégâts, carte de notification, fil du butin : l'un sous l'autre, jamais sur la barre d'action), Premiers pas et fiche
## de découverte qui ne se superposent pas, profils Standard / Compact / Minimal, mise en page à 1600×900 et 1280×720 dans
## chaque mode, coût du HUD par image.
## godot --headless --path game res://tests/test_hud2.tscn

const BUDGET_MS := 0.8  # mise à jour du HUD commun par image (0,33-0,38 ms avant et après le lot sur la même machine chargée)
const SIZES := [Vector2i(1600, 900), Vector2i(1280, 720)]

var fails := 0
var world: Node


func check(label: String, ok: bool) -> void:
	print(("OK    " if ok else "ÉCHEC ") + label)
	if not ok:
		fails += 1


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


static func _in(outer: Rect2, r: Rect2) -> bool:
	return outer.grow(1.0).encloses(r)


func _ready() -> void:
	Settings.reset_all()
	Profile.reset_all()
	Profile.selected_class = "warrior"
	Profile.tutorial = {"mode": "guided", "steps": [], "seen": [], "version": Version.NUMBER}
	get_window().size = SIZES[0]
	check("profils du HUD : Standard, Compact, Minimal (défaut Standard)", HudV2.PROFILES == ["standard", "compact", "minimal"]
		and HudV2.profile() == "standard" and HudV2.PROFILE_NAMES.size() == 3)
	Run.start_survival("warrior", 1, 0)
	await _boot()
	var hud: Hud = world.hud
	await _pieces(hud)
	await _column(hud)
	await _profiles(hud)
	_perf(hud)
	await _close()
	for mode in ["dungeon", "tower", "duel"]:
		await _mode_layout(mode)
	get_window().size = SIZES[0]
	print("TOUT EST OK (0 échec(s))" if fails == 0 else "ÉCHECS : %d" % fails)
	get_tree().quit(fails)


func _boot() -> void:
	world = load("res://scenes/world.tscn").instantiate()
	get_tree().root.add_child.call_deferred(world)
	var t := 0.0
	while t < 40.0 and not (world.get("hud") != null and world.hud.player != null and world.get("director") != null):
		await get_tree().create_timer(0.25).timeout
		t += 0.25
	await get_tree().create_timer(4.0).timeout
	_clear_cards()
	world.player.dev_invincible = true


func _clear_cards() -> void:
	if is_instance_valid(world) and world.cards.is_open():
		world.cards._queue.clear()
		world.cards._show_next()


func _close() -> void:
	world.queue_free()
	Tower.active = false
	Duel.active = false
	Run.active = false
	get_tree().paused = false
	await _frames(3)


# --- pièces -----------------------------------------------------------------------------------------------------------
func _pieces(hud: Hud) -> void:
	var p: Player = world.player
	check("vie en jauge large (HudV2.LifeGauge), plus de globe", hud._hp_orb is HudV2.LifeGauge and hud._hp_orb.size.x >= 600.0)
	p.hp = p.max_hp * 0.5
	p.health_changed.emit(p.hp, p.max_hp)
	await _frames(2)
	check("vie : chiffres « x / y », trace des dégâts qui rattrape", String(hud._hp_orb._txt).contains(" / ") and hud._hp_orb.trail >= hud._hp_orb.ratio
		and absf(hud._hp_orb.ratio - 0.5) < 0.02)
	p.hp = p.max_hp
	p.health_changed.emit(p.hp, p.max_hp)
	var lv: HudV2.LevelBar = hud._xp_orb
	check("barre de niveau (au lieu du globe) : niveau affiché, aucun pourcentage permanent", lv is HudV2.LevelBar and lv.big_text == str(p.level)
		and lv.small_text == "" and String(lv.tooltip_text).contains("Expérience"))
	p.xp_changed.emit(0, 100, p.level + 1)
	check("montée de niveau : éclat de la barre", lv.flash > 0.5 and lv.big_text == str(p.level + 1))
	check("cases de sorts : touche dessinée sous chaque case", hud._slots.all(func(s): return s.key_sticker and s.key_text != ""))
	check("cases vides tramées (jamais « — »)", hud._slots.any(func(s): return s.empty))
	check("esquive et potions avec leur touche", hud._dodge.key_text != "" and hud._potion_slots.all(func(s): return s.key_text != ""))
	p.weapon_swapped.emit(true)
	check("échange d'arme : la case de l'arme rangée s'éclaire", hud._swap._flash > 0.9)
	check("mini-carte : cadre papier (plus d'anneaux dorés)", hud._map_holder.get_children().any(func(c): return c is HudV2.MapRing))
	check("bandeau d'annonce : autocollant d'encre (plus de dégradé noir)", hud._banner.get_theme_stylebox("panel") is UiTheme.StickerBox)
	var wait := 0.0
	while wait < 8.0 and hud.banner_up():  # (l'annonce de la carte, au départ, passe avant le butin)
		await get_tree().process_frame
		wait += get_process_delta_time()
	var lines := hud._feed.get_child_count()
	hud.show_message("Butin : Épée du test", 1.5)
	await _frames(2)
	check("fil du butin dans la colonne de droite", hud._loot == hud._feed and hud._feed.get_child_count() == lines + 1
		and hud._feed.get_global_rect().position.x > hud.get_viewport().get_visible_rect().size.x * 0.5)
	hud.show_message("Rage !\nLes monstres frappent plus fort", 1.0)
	hud.show_message("Butin : Bottes du test", 1.5)
	check("une seule chose à lire : le butin attend la fin du bandeau", hud._feed_wait.size() == 1 and hud.banner_up())
	var t := 0.0
	while t < 4.0 and not hud._feed_wait.is_empty():
		await get_tree().process_frame
		t += get_process_delta_time()
	check("puis il sort", hud._feed_wait.is_empty())


# --- colonne de droite et pile de gauche ------------------------------------------------------------------------------
func _column(hud: Hud) -> void:
	for res in SIZES:
		get_window().size = res
		await _frames(4)
		Run.add_combo_damage(123456.0)
		hud._show_card("cards")
		var t := 0.0
		while t < 3.0 and hud._cards.count() == 0:
			await get_tree().process_frame
			t += get_process_delta_time()
		await _frames(6)
		Run.add_combo_damage(1.0)
		for i in 3:
			hud.feed("Butin : Anneau de test %d" % i)
		await _frames(4)
		hud.show_message("Rage !\nLes monstres frappent plus fort : file au donjon", 2.0)
		await _frames(20)
		var tag := "%dx%d" % [res.x, res.y]
		check("%s : Premiers pas affichés (pile de gauche)" % tag, hud._steps_panel.visible)
		check("%s : carte de découverte affichée (colonne de droite)" % tag, hud._cards.count() > 0)
		_check_layout(hud, tag + " Survie")
		var card: Rect2 = hud._cards._box.get_global_rect()
		var holder: Rect2 = hud._map_holder.get_global_rect()
		check("%s : la carte est sous la mini-carte (%.0f ≥ %.0f)" % [tag, card.position.y, holder.end.y], card.position.y >= holder.end.y)
		if hud._dmg_box.modulate.a > 0.5:
			check("%s : la carte est sous le compteur de dégâts" % tag, card.position.y >= hud._dmg_box.get_global_rect().end.y - 1.0)
		while hud._cards.count() > 0 and hud._cards.dismiss_top("test"):
			await _frames(1)
		await get_tree().create_timer(0.5).timeout


## Rectangles visibles du HUD : aucun ne sort de l'écran, aucun ne recouvre un autre.
func _check_layout(hud: Hud, tag: String) -> void:
	var vp := Rect2(Vector2.ZERO, hud.get_viewport().get_visible_rect().size)
	var parts := {}
	if hud._left.visible:
		parts["pile de gauche"] = hud._left.get_global_rect()
	if hud._map_holder.visible:
		parts["mini-carte"] = hud._map_holder.get_global_rect()
	if hud._dmg_box.visible and hud._dmg_box.modulate.a > 0.5:
		parts["compteur de dégâts"] = hud._dmg_box.get_global_rect()
	if hud._cards.count() > 0:
		parts["carte"] = hud._cards._box.get_global_rect()
	if hud._loot != null:
		for c in hud._feed.get_children():
			if (c as Control).visible and (c as Control).modulate.a > 0.05:
				var fr: Rect2 = (c as Control).get_global_rect()
				parts["fil du butin"] = parts["fil du butin"].merge(fr) if parts.has("fil du butin") else fr
	if hud._target_box.visible:
		parts["cible"] = hud._target_box.get_global_rect()
	if hud.banner_up():
		parts["bandeau"] = hud._banner.get_global_rect()
	var bb = hud.get("_boss_bar")
	if bb != null and is_instance_valid(bb) and bb.visible and bb.get("panel") != null and (bb.panel as Control).is_visible_in_tree():
		parts["barre de boss"] = (bb.panel as Control).get_global_rect()
	var bar: Rect2 = hud._hp_orb.get_global_rect()
	for s in hud._slots + [hud._dodge, hud._xp_orb]:
		bar = bar.merge((s as Control).get_global_rect())
	bar = bar.grow_individual(0, 26, 0, 0)  # (icônes d'enchaînement au-dessus des cases)
	parts["barre d'action"] = bar
	var out: Array = []
	for k in parts:
		if not _in(vp, parts[k]):
			out.append("%s hors de l'écran %s" % [k, parts[k]])
	var keys := parts.keys()
	for i in keys.size():
		for j in range(i + 1, keys.size()):
			var a: Rect2 = parts[keys[i]]
			var b: Rect2 = parts[keys[j]]
			if a.grow(-1.0).intersects(b.grow(-1.0)):
				out.append("%s ∩ %s" % [keys[i], keys[j]])
	check("%s : rien hors de l'écran, rien ne se recouvre %s" % [tag, out], out.is_empty())


# --- profils -----------------------------------------------------------------------------------------------------------
func _profiles(hud: Hud) -> void:
	get_window().size = SIZES[0]
	Settings.set_v("interface", "hud_profile", "compact")
	await _frames(3)
	check("Compact : HUD plus petit", absf(hud._root.scale.x - HudV2.COMPACT_SCALE) < 0.01)
	check("Compact : sans compteur de dégâts, fil du butin de 2 lignes", not hud._dmg_allowed() and HudV2.loot_lines() == 2)
	Settings.set_v("interface", "hud_profile", "minimal")
	await _frames(3)
	check("Minimal : taille normale, sans mini-carte", is_equal_approx(hud._root.scale.x, 1.0) and not hud._map_holder.visible)
	var n := hud._feed.get_child_count()
	hud.feed("Butin : Casque du test")
	check("Minimal : pas de fil du butin", hud._feed.get_child_count() == n and hud._feed_wait.is_empty())
	await get_tree().create_timer(Hud.OBJECTIVE_AUTO_SHOW + 0.3).timeout
	world.director.seals += 1
	await _frames(3)
	check("Minimal : les objectifs restent repliés à une découverte", not hud._obj_details.visible)
	var qb: QuestBadge = null
	for c in hud._left.get_children():
		if c is QuestBadge:
			qb = c
	if qb != null:
		qb.refresh()
		check("Minimal : pas de quête suivie", not qb.visible)
	_check_layout(hud, "Minimal")
	Settings.set_v("interface", "hud_profile", "standard")
	await _frames(3)
	check("Standard : mini-carte revenue, taille normale", hud._map_holder.visible and is_equal_approx(hud._root.scale.x, 1.0))
	Settings.set_v("interface", "hud_scale", 1.2)
	await _frames(3)
	check("taille du HUD réglée : appliquée", absf(hud._root.scale.x - 1.2) < 0.01)
	Settings.set_v("interface", "hud_scale", 1.0)
	await _frames(2)


# --- coût --------------------------------------------------------------------------------------------------------------
func _perf(hud: Hud) -> void:
	var runs: Array = []
	for k in 7:
		var t0 := Time.get_ticks_usec()
		for i in 100:
			hud._process(1.0 / 60.0)
		runs.append(float(Time.get_ticks_usec() - t0) / 1000.0 / 100.0)
	runs.sort()
	print("[hud2] coût du HUD commun : %.3f ms par image (médiane %.3f)" % [runs[0], runs[3]])
	check("coût du HUD par image : %.3f ms (≤ %.1f)" % [runs[0], BUDGET_MS], float(runs[0]) <= BUDGET_MS)


# --- autres modes ------------------------------------------------------------------------------------------------------
func _mode_layout(mode: String) -> void:
	Profile.tutorial = {"mode": "skip", "steps": [], "seen": [], "version": Version.NUMBER}
	match mode:
		"dungeon":
			Tower.start_dungeon("warrior", "limestone", 0, [])
		"tower":
			Tower.start("warrior", 1, 1)
		"duel":
			Duel.mode = "free"
			Duel.start("warrior", "knight", 1)
	await _boot()
	var hud: Hud = world.hud
	for res in SIZES:
		get_window().size = res
		await _frames(4)
		_clear_cards()
		hud.feed("Butin : Gants du test")
		await _frames(3)
		_check_layout(hud, "%dx%d %s" % [res.x, res.y, mode])
		check("%dx%d %s : vie, niveau et sorts affichés" % [res.x, res.y, mode], hud._hp_orb.visible and hud._xp_orb.visible and hud._slots[0].visible)
	if mode == "duel":
		check("duel : pas de compteur de dégâts", hud._dmg_box.modulate.a < 0.5)
	await _close()
