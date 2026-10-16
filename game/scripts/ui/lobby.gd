extends Node3D
## Menu principal (lobby) : le héros posé dans la map de la zone choisie ; menu à icônes
## à gauche, une fonction = un seul endroit :
## - Jouer : lancer la run (un clic), résumé du héros (ouvre l'écran Héros), zone de farm ;
## - Héros : écran HeroScreen (équipement, talents, apparence, grimoire, classe, aide « ? ») ;
## - Coffres : les coffres de récompense rapportés des runs, à ouvrir (Rewards) ;
## - Collection : l'archive des trésors (une seule page) ;
## - Paramètres, Quitter.
## Badge de la classe en haut à droite, zone et prochaine récompense en bas.
## Les arguments de test (--autoplay, --dungeon, --shots...) lancent la run directement.

const RUN_SCENE := "res://scenes/world.tscn"
const TITLE_SCENE := "res://scenes/title.tscn"
## Menu de gauche : identifiant, texte, icône.
const MENU := [
	["play", "Jouer", "play"], ["hero", "Héros", "class"], ["chests", "Coffres", "chest"], ["workshop", "Atelier", "equipment"],
	["collection", "Carnet", "collection"], ["settings", "Paramètres", "settings"], ["quit", "Quitter", "quit"],
]
## Largeur du panneau central : fixe (la page Jouer, en grille, est plus large) ; il ne « saute » plus d'une page à l'autre.
const PANEL_W := 580.0
const PLAY_W := 760.0
const NEWS_CARDS := 3  # nouveautés montrées en cartes, puis « Tout voir dans le Guide »
const PANEL_BOTTOM := 36.0  # marge entre le bas du panneau et le bas de l'écran
## Arguments de test qui ouvrent un écran au démarrage (captures, tests).
const SCREEN_ARGS := ["--grimoire", "--talents", "--info", "--inventory", "--appearance", "--chests", "--cards", "--settings", "--armory"]

var backdrop: MapBackdrop
var _hero: HeroScreen
var _archive: PageScreen
var _workshop: PageScreen
var _chests: PageScreen
var _launching := false
var _cards: InfoCard  # pile de petites cartes d'information (nouveautés, avis)
var _open_screen := ""  # test : écran ouvert au démarrage (--inventory, --talents, --appearance, --archive=0...)
var _settings: SettingsMenu
var _heroic := 0  # rang héroïque choisi pour la Survie
var _epoch := 99  # époque choisie pour la Survie (la plus avancée ouverte par défaut)
var _zone_card: Control  # zone choisie et prochaine récompense (en bas à gauche)
var _menu := {}  # identifiant -> MenuWidgets.SideButton
var _current := ""  # sous-menu affiché ("" : aucun, le panneau est caché)
var _sub: VBoxContainer  # contenu défilant de la page ouverte
var _sub_panel: PanelContainer
var _scroll: ScrollContainer  # la page défile ; le bouton d'action reste en dessous, toujours visible
var _foot: VBoxContainer  # boutons épinglés (Lancer, Entrer, S'inscrire)
var _shown_page := ""
var _scroll_keep := 0  # position de défilement à retrouver quand la même page est reconstruite
var _fit_queued := false
var _tower_diff := 1  # la Tour : difficulté et page d'étages affichées, étage choisi
var _tower_page := 0
var _tower_sel := 1
var _duel_opp := "warrior"  # mode Duel : adversaire et difficulté choisis
var _duel_diff := 2
var _badge: PanelContainer  # badge de la classe (en haut à droite) : un clic ouvre le choix de classe
var _badge_icon: TextureRect
var _badge_name: Label
var _badge_sub: Label
var _badge_hero: Label  # nom du héros (et titre porté) au-dessus de la classe ; caché sans nom
var _zone_thumb: TextureRect
var _zone_name: Label
var _zone_sub: Label
var _reward_bar: ProgressBar
var _reward_text: Label
var _reward_nums: Label
var _footer: Label
var _info_bar: Control  # pied de page (insignes, cristaux, heure) : le panneau central lui laisse la place
var _gear_band: Label  # « 3 / 60 classes équipées » (Registre de l'équipement)
var _compass: Button  # la boussole : un conseil, une ligne cliquable en haut de l'écran (Compass)
var _compass_go := {}
var _gear_sep: VSeparator
var _clock: Label
var _snapshot: Texture2D
var _dev_button: Button


func _ready() -> void:
	Music.play(Music.MENU)
	var shot := -1.0
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--class="):
			Profile.selected_class = arg.trim_prefix("--class=")
		elif arg.begins_with("--zone="):
			Profile.selected_zone = arg.trim_prefix("--zone=")
		elif arg.begins_with("--weapon="):
			Profile.select_weapon_type(arg.trim_prefix("--weapon="))
		elif arg.begins_with("--duel-tab="):
			_duel_tab = arg.trim_prefix("--duel-tab=")  # test : onglet du Duel (free, league, pantheon, gauntlet)
		elif arg in SCREEN_ARGS or arg.begins_with("--archive=") or arg.begins_with("--appearance=") or arg.begins_with("--dev=") or arg.begins_with("--tower-menu="):
			_open_screen = arg.trim_prefix("--")
		elif arg.begins_with("--wear-back="):
			# test : porte la pièce de dos d'Eden de ce nom, --dye-back=r,g,b;r,g,b;r,g,b
			for c in GameData.cosmetics:
				if String(c.name) == arg.trim_prefix("--wear-back="):
					Profile.unlock_outfit(String(c.id))
					Profile.set_worn(Profile.selected_class, "back", String(c.outfit))
		elif arg.begins_with("--orbit="):
			# test : caméra de l'accueil (degrés, degrés, distance, hauteur)
			_test_orbit = Array(arg.trim_prefix("--orbit=").split(",")).map(func(x): return float(x))
		elif arg.begins_with("--dye-back="):
			var cols: Array = []
			for part in arg.trim_prefix("--dye-back=").split(";"):
				cols.append(Array(part.split(",")).map(func(x): return int(x)))
			Profile.set_dye(Profile.selected_class, "back", cols)
		elif arg.begins_with("--wear-head="):
			# test : porte l'accessoire de tête d'Eden de ce nom (profil de test uniquement)
			for c in GameData.cosmetics:
				if String(c.name) == arg.trim_prefix("--wear-head="):
					Profile.unlock_outfit(String(c.id))
					Profile.set_worn(Profile.selected_class, "head", String(c.outfit))
		elif arg.begins_with("--wear-aura="):
			# test : porte l'aura dont l'effet est donné (ex. --wear-aura=s81011)
			for x in GameData.auras:
				if String(x.aura.fx) == arg.trim_prefix("--wear-aura="):
					Profile.collect(x)
					Profile.set_aura(Profile.selected_class, String(x.aura.kind), int(x.id))
		elif arg == "--wear-aura":
			# test : une pierre étoilée et une pierre de lune portées (profil de test uniquement)
			for kind in ["star", "luna"]:
				var xs := GameData.auras.filter(func(x): return String(x.aura.kind) == kind)
				if not xs.is_empty():
					Profile.collect(xs[0])
					Profile.set_aura(Profile.selected_class, kind, int(xs[0].id))
		elif arg.begins_with("--expertise="):
			# test : expertise donnée à toutes les classes (profil de test uniquement)
			for cid in GameData.classes:
				Profile.expertise[cid] = int(arg.trim_prefix("--expertise="))
	if not Profile.in_run:
		Profile.save_profile()  # classe choisie en argument : son préréglage (et son arme)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--class=") or arg.begins_with("--zone=") or arg.begins_with("--weapon=") or arg in SCREEN_ARGS \
				or arg.begins_with("--archive=") or arg.begins_with("--appearance=") or arg.begins_with("--expertise=") or arg.begins_with("--dev=") \
				or arg.begins_with("--wear-aura") or arg == "--class-menu" or arg.begins_with("--wear-head=") or arg.begins_with("--wear-back=") or arg.begins_with("--dye-back=") or arg.begins_with("--archive-cat=") or arg.begins_with("--shot-out=") or arg.begins_with("--orbit=") or arg.begins_with("--tower-menu=") or arg == "--preset-editor" or arg == "--duel-menu" or arg == "--lobby-forge" or arg == "--duel-prep" or arg == "--rival-editor" or arg.begins_with("--profile-tab=") or arg.begins_with("--profile-picker=") or arg == "--profile-load" or arg.begins_with("--settings-tab=") or arg.begins_with("--menu=") or arg.begins_with("--duel-tab=") or arg.begins_with("--chest-open=") or arg.begins_with("--chests-tab=") or arg.begins_with("--workshop-tab="):
			continue
		if arg.begins_with("--lobby-shot="):
			shot = float(arg.trim_prefix("--lobby-shot="))
		elif arg.begins_with("--"):
			_start_run()
			return
	_build_scene()
	_build_ui()
	_welcome_flow.call_deferred()
	if OS.get_cmdline_user_args().is_empty():
		# P2 : la scène de run se charge en tâche de fond une fois le lobby affiché (Lancer n'attend plus)
		var prefetch := Timer.new()  # enfant du lobby : disparaît avec lui si le joueur part avant
		prefetch.one_shot = true
		prefetch.wait_time = 2.0
		add_child(prefetch)
		prefetch.timeout.connect(func():
			if not _launching:
				ResourceLoader.load_threaded_request(RUN_SCENE))
		prefetch.start()
	if "--duel-menu" in OS.get_cmdline_user_args():
		_show_menu("duel")  # test : inscription au duel
		if "--rival-editor" in OS.get_cmdline_user_args():
			# test : éditeur de profils avec un profil de démonstration (rempli, une arme +10)
			var demo := RivalBuilds.blank("magician", 45)
			RivalBuilds.auto_fill(demo)
			if demo.gear.has("weapon"):
				demo.gear.weapon["upgrade"] = 10
				demo.gear.weapon["rolls"] = {"4": "matk", "6": "crit", "8": "matk", "10": "int"}
				demo.gear.weapon["gems"] = [Craft.gem_key("sapphire", 4), Craft.gem_key("amethyst", 3)]
				demo.gear.weapon["enchant"] = Craft.scroll_key("optimize", 4)
			var bodies := GameData.cosmetics.filter(func(x): return String(x.get("cat", "")) == "body")
			if not bodies.is_empty():
				demo.look["body"] = String(bodies[3].outfit)
			if not GameData.auras.is_empty():
				demo.look["aura"] = int(GameData.auras[0].id)
				demo.look["aura_tint"] = [70, 170, 255]
			demo.look["dye"] = {"body": [[220, 40, 60], [30, 30, 40], [240, 200, 80]]}
			for row in GameData.talents.get("magician", {}).get("rows", []).slice(0, 1):
				for c in row:
					if c != null:
						demo.talents[str(int(c.id))] = int(c.max)
			var pe := ProfileEditor.open(self, demo, func(_b): pass)
			for arg in OS.get_cmdline_user_args():
				if arg.begins_with("--profile-tab="):
					pe._tab = int(arg.trim_prefix("--profile-tab="))
					pe._refresh_all.call_deferred()
				elif arg.begins_with("--profile-picker="):  # test : catalogue d'un emplacement
					pe._open_picker.call_deferred(arg.trim_prefix("--profile-picker="))
				elif arg == "--profile-load":  # test : menu « Charger un profil » (rangé par classe)
					pe._load_menu.call_deferred()
		if "--duel-prep" in OS.get_cmdline_user_args():
			Duel.rival_class = _duel_opp
			DuelPrep.open(self, func(): _show_menu("duel"))
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--menu="):  # test : sous-menu ouvert (play, zones, tower, duel)
			_show_menu(arg.trim_prefix("--menu="))
	if Survivor.lobby_request == "class":  # bilan du Survivant, « Changer de classe » : la page du mode et le choix de classe
		Survivor.lobby_request = ""
		_show_menu("survivor")
		_open_class_menu.call_deferred()
	match _open_screen.get_slice("=", 0):
		"tower-menu":
			# test : étages de la Tour (--tower-menu=difficulté,étage ; avec un étage : sa fiche ouverte)
			var parts := _open_screen.get_slice("=", 1).split(",")
			_tower_diff = int(parts[0])
			_tower_sel = int(parts[1]) if parts.size() > 1 else 1
			_tower_page = (_tower_sel - 1) / TowerPages.FLOORS_PER_PAGE
			_show_menu("tower_floors")
			if parts.size() > 1:
				TowerPages.info_popup(_sub, Tower.spec(_tower_sel, _tower_diff))
		"settings":
			var tab := 0
			for arg in OS.get_cmdline_user_args():
				if arg.begins_with("--settings-tab="):  # test : onglet des paramètres
					tab = int(arg.trim_prefix("--settings-tab="))
			_settings.open(tab)
		"grimoire":
			_open_hero("grimoire")
		"talents":
			_open_hero("class")
			for arg in OS.get_cmdline_user_args():
				if arg == "--class-menu":  # test : menu des classes ouvert
					_hero.get_node(".").call_deferred("_test_class_menu")
		"info":
			_open_hero("help")
		"inventory":
			_open_hero("equipment")
			if "--lobby-forge" in OS.get_cmdline_user_args() and not Profile.inventory.is_empty():
				# test : forge hors run sur le premier objet du coffre
				_hero.page._select({"kind": "item", "item": Profile.inventory[0]})
				_hero.page._on_upgrade()
		"cards":
			_open_hero("cards")
		"appearance":
			# test : catégorie de l'apparence (--appearance=aura, --appearance=weapon...)
			if _open_screen.contains("="):
				_hero.appearance._cat = _open_screen.get_slice("=", 1)
				_hero.appearance._slot = _hero.appearance._cat
			_open_hero("appearance")
		"dev":
			# test : écran du mode dev, page N (paramètres de test uniquement)
			Settings.set_v("interface", "dev_mode", true)
			Dev.open(int(_open_screen.get_slice("=", 1)))
			match int(_open_screen.get_slice("=", 1)):
				1:  # éditeur : le premier objet possédé
					var ed: DevEditor.EditPage = Dev.screen.page(1)
					ed._select(ed._entries[0])
				2:  # sets : un set d'Eden
					Dev.screen.page(2)._open(String(GameData.eden_sets.keys()[0]))
				3:  # cartes : Lame statique (stats et effets déclenchés)
					Dev.screen.page(3)._open("static_blade")
		"chests":
			# test (profil de test) : un coffre de chaque type, la proposition d'un coffre de set ouverte
			if Profile.reward_chests.is_empty():
				for t in Rewards.ORDER:
					Profile.reward_chests.append(Rewards.make(t, 25))
			var ctab := 0
			for arg in OS.get_cmdline_user_args():
				if arg.begins_with("--chests-tab="):
					ctab = int(arg.get_slice("=", 1))  # test : onglet de l'écran Coffres (1 : Roulette)
			_chests.open(ctab)
			var kind := "set"  # --chest-open=gear : coffre ouvert (set, trophy, gear, forge, jewel ; none : aucun)
			for arg in OS.get_cmdline_user_args():
				if arg.begins_with("--chest-open="):
					kind = arg.trim_prefix("--chest-open=")
			var pick := Profile.reward_chests.filter(func(c): return c.type == kind)
			if pick.is_empty() and Rewards.TYPES.has(kind):
				Profile.reward_chests.append(Rewards.make(kind, 25))
				pick = Profile.reward_chests.filter(func(c): return c.type == kind)
			if not pick.is_empty():
				_chests.page(0).open_chest(pick[0])
		"armory":
			# test (profil de test) : pièces découvertes en Survie (époque I et une éveillée), insignes
			if Profile.seen_gear.is_empty():
				for ep in [1, 3]:
					for box in ["weapon", "head", "chest"]:
						for it in SlotChests.offer(box, ep, 3 if ep == 3 else 1, 2):
							Profile.seen_gear.append(int(it.eden))
				Profile.insignia = 300
			var wtab := 0
			for arg in OS.get_cmdline_user_args():
				if arg.begins_with("--workshop-tab="):
					wtab = int(arg.get_slice("=", 1))  # test : onglet de l'Atelier (2 : Forge)
			_workshop.open(wtab)
		"archive":
			_archive.open(4)
			for arg in OS.get_cmdline_user_args():
				if arg.begins_with("--archive-cat="):  # test : catégorie de l'archive
					_archive.page(4)._cat = arg.trim_prefix("--archive-cat=")
					_archive.page(4).refresh()
	if shot > 0.0:
		await get_tree().create_timer(shot).timeout
		DirAccess.make_dir_recursive_absolute("user://shots")
		var out := "lobby"
		for arg in OS.get_cmdline_user_args():
			if arg.begins_with("--shot-out="):
				out = arg.trim_prefix("--shot-out=")
		get_viewport().get_texture().get_image().save_png("user://shots/%s.png" % out)
		get_tree().quit()


## Lancer la run : un clic (le héros se prépare dans l'écran Héros).
func _launch() -> void:
	if _launching:
		return
	_launching = true
	_start_run()


func _start_training() -> void:
	if _launching:
		return
	_launching = true
	if backdrop:
		backdrop.release()
	Training.start(Profile.selected_class)
	get_tree().change_scene_to_file.call_deferred(RUN_SCENE)


## Duel : quatre onglets — libre, Ligue, Panthéon et Gantelet (1 contre 2 ou 3, équipé).
var _duel_tab := "free"
var _team_size := 2  # Arènes : 2 (2v2) ou 3 (3v3)
var _team_allies: Array = ["", ""]
var _team_brain := ""  # Arènes / Gantelet : cerveau d'IA qui pilote le premier adversaire ("" = scriptés seulement)
var _gauntlet_foes := 2
var _team_diff := 2  # Arènes / Gantelet : difficulté des héros IA (passe M7 : réglable, Difficile par défaut)


## Classes au hasard, de familles différentes (Duel.team_classes), hors de celle du joueur.
func _random_classes(n: int, avoid: Array = [], avoid_families: Array = []) -> Array:
	return Duel.team_classes(n, avoid, avoid_families)


## Arènes / Gantelet (passe M7) : difficulté des héros IA, en une rangée de boutons ; [param menu] est la page à redessiner.
func _team_diff_row(menu: String) -> void:
	_section("Adversaires", "Leur jeu (lecture de tes coups, esquives, choix de cible) ; tes alliés jouent au même niveau.")
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	_sub.add_child(row)
	for i in ClassRival.NAMES.size():
		var b := MenuWidgets.glass_button(("✔ " if _team_diff == i else "") + String(ClassRival.NAMES[i]), 14, Vector2(0, 40))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var k := i
		b.pressed.connect(func():
			_team_diff = k
			_show_menu(menu))
		row.add_child(b)


## Arènes / Gantelet (passe M7) : arène classique ou piégée (zones de feu pour tout le monde, Duel.hazards).
func _hazard_row(menu: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	_sub.add_child(row)
	for opt in [[false, "Arène classique", "Le sol est sûr : seuls les héros frappent."], [true, "Arène piégée", "Des zones de feu tombent près des héros toutes les quelques secondes, pour les deux camps : une esquive les évite."]]:
		var b := MenuWidgets.glass_button(("✔ " if Duel.hazards == bool(opt[0]) else "") + String(opt[1]), 14, Vector2(0, 40))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.tooltip_text = String(opt[2])
		var on := bool(opt[0])
		b.pressed.connect(func():
			Duel.hazards = on
			_show_menu(menu))
		row.add_child(b)


## Victoires du mode et 1re victoire du jour (insignes) : une ligne, le détail en infobulle.
func _team_record(key: String) -> void:
	var wins := int(Profile.records.get(key + "_wins", 0))
	var daily := League.daily_open(key)
	var l := Hud._label(_sub, "Victoires : %d · %s" % [wins, ("1re victoire du jour : +%d insignes" % League.daily_insignia(key, _team_diff)) if daily
		else "1re victoire du jour déjà prise"], 14, Color(0.6, 0.85, 1.0))
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.tooltip_text = "Chaque victoire rapporte de la maîtrise à ta classe ; la 1re du jour rapporte aussi des insignes (plus en difficulté haute), les suivantes %d." % League.REPEAT_INSIGNIA
	l.mouse_filter = Control.MOUSE_FILTER_PASS


## Conditions d'inscription [param reqs] (Duel.requirements) : seulement les points à régler, chacun avec « Régler » ;
## tout réglé : une ligne « Héros prêt » (passe M7 : plus de liste de ✔ « 0 / 0 emplacements »).
func _req_list(reqs: Array) -> void:
	var todo := reqs.filter(func(r): return not r.ok)
	if todo.is_empty():
		var p := SpellPresets.active(Profile.selected_class)
		var ok := Hud._label(_sub, "✔ Héros prêt · préréglage « %s »" % String(p.get("name", "")), 14, UiTheme.BUFF)
		ok.tooltip_text = "\n".join(reqs.map(func(r): return "✔ %s : %s" % [r.label, r.hint]))
		ok.mouse_filter = Control.MOUSE_FILTER_PASS
		return
	for r in todo:
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 8)
		_sub.add_child(h)
		var mark := Hud._label(h, "✘", 20, Color(1.0, 0.45, 0.4))
		mark.custom_minimum_size = Vector2(22, 0)
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 0)
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(v)
		Hud._label(v, String(r.label), 15, UiTheme.TEXT)
		Hud._label(v, String(r.hint), 14, UiTheme.MUTED).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var sec := String(r.section)
		var fix := MenuWidgets.glass_button("Régler", 14, Vector2(86, 36))
		fix.pressed.connect(func(): _open_hero(sec))
		h.add_child(fix)


func _start_team(mode: String, allies: Array, foes: Array) -> void:
	if _launching or foes.is_empty():
		return
	Duel.save_free()  # (passe M7) les réglages du duel libre reviennent au retour au lobby
	Duel.mode = mode
	Duel.pilot = _team_brain if MlDuelPilot.available().any(func(b): return b[0] == _team_brain) else ""
	Duel.rival_build = {}
	Duel.team_allies = allies
	Duel.extra_foes = foes.slice(1)
	_launching = true
	if backdrop:
		backdrop.release()
	Duel.start(Profile.selected_class, String(foes[0]), _team_diff)
	get_tree().change_scene_to_file.call_deferred(RUN_SCENE)


## Choix du cerveau d'IA qui pilote le premier adversaire d'une équipe (les autres restent scriptés).
func _team_brain_picker() -> void:
	var brains := MlDuelPilot.available()
	if brains.is_empty():
		return
	_section("Premier adversaire")
	var pl := OptionButton.new()
	pl.focus_mode = Control.FOCUS_NONE
	pl.add_item("IA scriptée")
	for b in brains:
		pl.add_item("Cerveau %s" % b[1])
		if String(b[0]) == _team_brain:
			pl.select(pl.item_count - 1)
	pl.tooltip_text = "Un cerveau d'IA entraînée joue le premier adversaire ; les autres restent scriptés."
	pl.item_selected.connect(func(i): _team_brain = "" if i == 0 else String(brains[i - 1][0]))
	_sub.add_child(pl)


## Gantelet : toi (équipé) contre deux, puis trois héros scriptés.
func _menu_gauntlet() -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	_sub.add_child(row)
	for n in [2, 3]:
		var b := MenuWidgets.glass_button(("✔ " if _gauntlet_foes == n else "") + "1 contre %d" % n, 16, Vector2(0, 42))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var k: int = n
		b.pressed.connect(func():
			_gauntlet_foes = k
			_show_menu("duel"))
		row.add_child(b)
	# le Gantelet se joue équipé : conditions du duel équipé (passe M7 : la page lisait celles de l'à l'arme), en tête
	var was := Duel.bare
	Duel.bare = false
	var reqs := Duel.requirements(Profile.selected_class)
	Duel.bare = was
	_req_list(reqs)
	_team_diff_row("duel")
	_hazard_row("duel")
	_team_brain_picker()
	_team_record("gauntlet_%d" % _gauntlet_foes)
	var ready := reqs.all(func(r): return r.ok)
	var go := MenuWidgets.gold_button("Entrer dans le Gantelet", 22, Vector2(0, 58))
	go.disabled = not ready
	go.pressed.connect(func(): _start_team("gauntlet", [], _random_classes(_gauntlet_foes)))
	_pin_go(go, "" if ready else "Règle d'abord les points marqués ✘")


## Arènes : toi et tes alliés IA contre une équipe IA (2v2 ou 3v3), à l'arme.
func _menu_arenas() -> void:
	_activity_head("arenas")
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	_sub.add_child(row)
	for n in [2, 3]:
		var b := MenuWidgets.glass_button(("✔ " if _team_size == n else "") + "%d contre %d" % [n, n], 16, Vector2(0, 42))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var k: int = n
		b.pressed.connect(func():
			_team_size = k
			_show_menu("arenas"))
		row.add_child(b)
	_section("Alliés IA", "Une classe au choix pour chacun, « Au hasard » sinon. Si tu tombes, tes alliés continuent.")
	for k in _team_size - 1:
		var ob := OptionButton.new()
		ob.focus_mode = Control.FOCUS_NONE
		ob.add_item("Au hasard")
		var ids: Array = [""]
		for cid in GameData.classes:
			if Progression.class_unlocked(cid):
				ob.add_item(String(GameData.class_data(cid).get("name_fr", cid)))
				ids.append(cid)
		ob.select(maxi(ids.find(_team_allies[k]), 0))
		var kk := k
		ob.item_selected.connect(func(i): _team_allies[kk] = ids[i])
		_sub.add_child(ob)
	_team_diff_row("arenas")
	_hazard_row("arenas")
	# niveau de l'arène (à l'arme, comme le duel libre)
	var lr := HBoxContainer.new()
	lr.add_theme_constant_override("separation", 8)
	_sub.add_child(lr)
	Hud._label(lr, "Niveau des héros", 15, UiTheme.TEXT)
	var sp := SpinBox.new()
	sp.min_value = 1
	sp.max_value = 100
	sp.value = Duel.arena_level
	sp.tooltip_text = "Tous les héros de l'arène, toi compris, se battent à ce niveau, à l'arme."
	sp.value_changed.connect(func(x): Duel.arena_level = int(x))
	lr.add_child(sp)
	_team_brain_picker()
	_team_record("arena%d" % _team_size)
	var ready := Duel.is_ready_bare(Profile.selected_class)
	var go := MenuWidgets.gold_button("Lancer l'arène", 22, Vector2(0, 58))
	go.disabled = not ready
	go.pressed.connect(func():
		var allies: Array = []
		for k in _team_size - 1:
			allies.append(String(_team_allies[k]) if String(_team_allies[k]) != "" else "")
		var taken: Array = allies.filter(func(c): return c != "")
		# alliés au hasard : d'une famille absente de ton équipe (pas deux soigneurs ni trois mêlées)
		var fams: Array = [Duel.family_of(Profile.selected_class)] + taken.map(func(c): return Duel.family_of(String(c)))
		for i in allies.size():
			if allies[i] == "":
				allies[i] = _random_classes(1, taken, fams)[0]
				taken.append(allies[i])
				fams.append(Duel.family_of(String(allies[i])))
		_start_team("arena%d" % _team_size, allies, _random_classes(_team_size, taken)))
	_pin_go(go, "" if ready else "Ton préréglage de sorts doit avoir 4 cases remplies.")


## Battle royale : le niveau des sept héros IA, puis Lancer. Tout le monde part nu, niveau 1.
var _royale_diff := Royale.difficulty  # (passe M1) le choix de la partie précédente reste coché


func _menu_royale() -> void:
	_activity_head("royale")
	_section("Adversaires")
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	_sub.add_child(row)
	for opt in [[-1, "Mélange"], [0, "Facile"], [1, "Normal"], [2, "Difficile"], [3, "Hardcore"]]:
		var b := MenuWidgets.glass_button(("✔ " if _royale_diff == int(opt[0]) else "") + String(opt[1]), 14, Vector2(0, 40))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var k: int = opt[0]
		b.pressed.connect(func():
			_royale_diff = k
			_show_menu("royale"))
		row.add_child(b)
	for line in ["Coffres et largages à piller", "Une zone qui se referme", "Le meilleur chasseur est mis à prix"]:
		Hud._label(_sub, "•  " + line, 15, UiTheme.TEXT)
	var best := int(Profile.records.get("royale_best", 0))
	var rec := Hud._label(_sub, "Victoires : %d · meilleure place : %s · éliminations : %d" % [int(Profile.records.get("royale_wins", 0)),
		str(best) if best > 0 else "—", int(Profile.records.get("royale_kills", 0))], 14, Color(0.6, 0.85, 1.0))
	rec.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var go := MenuWidgets.gold_button("Lancer le Battle royale", 22, Vector2(0, 58))
	go.disabled = not Unlocks.is_open("royale")
	go.pressed.connect(_start_royale)
	_pin_go(go, "" if Unlocks.is_open("royale") else Unlocks.lock_text("royale"))


func _start_royale() -> void:
	if _launching or not Unlocks.is_open("royale"):
		return
	_launching = true
	if backdrop:
		backdrop.release()
	Royale.difficulty = _royale_diff
	Royale.start(Profile.selected_class)
	get_tree().change_scene_to_file.call_deferred(RUN_SCENE)


func _duel_tabs() -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	_sub.add_child(row)
	for t in [["free", "Libre", ""], ["league", "Ligue", "league"], ["pantheon", "Panthéon", "pantheon"], ["gauntlet", "Gantelet", "gauntlet"]]:
		var open: bool = String(t[2]) == "" or Unlocks.is_open(String(t[2]))
		var b := MenuWidgets.glass_button(("🔒 " if not open else ("▶ " if _duel_tab == t[0] else "")) + String(t[1]), 15, Vector2(0, 38))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.modulate = Color.WHITE if open else Color(1, 1, 1, 0.45)
		b.tooltip_text = "" if open else Unlocks.lock_text(String(t[2]))
		var id := String(t[0])
		b.pressed.connect(func():
			if open:
				_duel_tab = id
				_show_menu("duel"))
		row.add_child(b)


## Ligue : cinq rangs contre l'IA scriptée, à l'arme niveau 10, aide Assistée au plus.
func _menu_league() -> void:
	var nxt := League.target_rank()
	var rank_text := ("%s · rang %s" % [Profile.hero_name, League.rank_name()]) if Profile.hero_name != "" else "Rang : %s" % League.rank_name()
	Hud._label(_sub, rank_text, 24, UiTheme.GOLD).add_theme_font_override("font", UiTheme.title_font())
	if League.rank_index() >= League.RANKS.size() - 1:
		Hud._label(_sub, "Rang maximal atteint : la Ligue ne rapporte plus que de la maîtrise.", 14, UiTheme.MUTED)
	else:
		# série vers le rang suivant (passe M7) : une pastille par victoire d'affilée, la récompense de la promotion
		var sr := HBoxContainer.new()
		sr.add_theme_constant_override("separation", 10)
		_sub.add_child(sr)
		Hud._label(sr, "Vers %s · IA %s" % [League.rank_name(nxt), String(ClassRival.NAMES[League.DIFFICULTY[nxt]]).to_lower()], 17, UiTheme.TEXT)
		var pips := Hud._label(sr, " ".join(range(League.WINS_PER_RANK).map(func(i): return "●" if i < League.streak() else "○")), 22, UiTheme.GOLD)
		pips.tooltip_text = "%s d'affilée contre l'IA %s ; une défaite remet la série à zéro." % [GearPower.plural(League.WINS_PER_RANK, "victoire"),
			String(ClassRival.NAMES[League.DIFFICULTY[nxt]]).to_lower()]
		pips.mouse_filter = Control.MOUSE_FILTER_PASS
		var look := String(League.PROMO_LOOK[nxt])
		Hud._label(_sub, "Promotion : +%d insignes%s" % [League.promo_insignia(nxt), (", " + String(Rewards.TYPES[look].name).to_lower()) if look != "" else ""],
			14, Color(0.6, 0.85, 1.0)).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var ready := Duel.is_ready_bare(Profile.selected_class)
	var go := MenuWidgets.gold_button("Combat de Ligue", 22, Vector2(0, 58))
	go.disabled = not ready
	go.pressed.connect(func(): _start_ranked("league", ""))
	_pin_go(go, "" if ready else "Ton préréglage de sorts doit avoir 4 cases remplies.")


## Panthéon : les six cerveaux dans l'ordre, avec leurs récompenses.
func _menu_pantheon() -> void:
	Hud._label(_sub, "Les cerveaux d'IA — à l'arme, niveau 10, meilleur de 3.", 14, UiTheme.MUTED)
	const ICONS := ["heart", "defense", "agility", "attack", "power", "expertise"]
	for i in Pantheon.BRAINS.size():
		var b: Dictionary = Pantheon.BRAINS[i]
		var id := String(b.id)
		var done := Pantheon.beaten(id)
		var open := Pantheon.available(i) and Pantheon.brain_file_present(id)
		var st: Dictionary = Profile.pantheon.get(id, {})
		var rewards := "Pièce « %s », coffre d'apparence%s, titre « %s »" % [String(Items.SLOT_NAMES.get(String(b.slot), String(b.slot))).to_lower(), (", coffre d'aura" if String(b.aura) != "" else ""), b.title]
		var state := ""
		if done:
			state = "✔ Battu" + (" · éveillé" if st.get("awake", false) else " (%d/5 familles)" % (st.get("families", []) as Array).size())
		elif open:
			state = "À défier"
		else:
			state = "🔒 Verrouillé"
		var r := _row("Cerveau %s" % b.name, "%s\n%s" % [rewards, state], ICONS[i % ICONS.size()], func(): _start_ranked("pantheon", id), 76.0)
		r.disabled = not open
		r.modulate = Color.WHITE if open or done else Color(1, 1, 1, 0.5)
		if not open and not done:
			r.tooltip_text = "Bats le cerveau précédent." if i > 0 and not Pantheon.beaten(String(Pantheon.BRAINS[i - 1].id)) else "Ce cerveau est absent sur ce PC."
	Hud._label(_sub, "Panoplie des Esprits : %d / 6 pièces · éveillées : %d" % [Pantheon.progress(), Pantheon.awake_count()], 14, UiTheme.GOLD)


func _start_ranked(mode: String, brain: String) -> void:
	if _launching:
		return
	var pool: Array = GameData.classes.keys()
	pool.sort()
	var opp := String(pool[randi() % pool.size()])
	Duel.save_free()  # (passe M7) rendus à l'annulation de la file ou au retour au lobby, plus seulement à l'annulation
	Duel.mode = mode
	Duel.bare = true
	Duel.bare_level = Pantheon.LEVEL
	Duel.rival_build = {}
	Duel.pilot = brain
	var diff := 3 if mode == "pantheon" else int(League.DIFFICULTY[League.target_rank()])
	var launch := func():
		_launching = true
		if backdrop:
			backdrop.release()
		Duel.start(Profile.selected_class, opp, diff)
		get_tree().change_scene_to_file.call_deferred(RUN_SCENE)
	var restore := func(): Duel.restore_free()
	_queue_duel("Panthéon" if mode == "pantheon" else "Ligue", "%s · à l'arme" % ("Défi d'un cerveau d'IA" if mode == "pantheon" else "Duel classé"), opp, Pantheon.LEVEL, diff, launch, restore)


## File d'attente du Duel (DuelQueue : recherche, match trouvé, draft de 60 s, récapitulatif de 10 s) puis
## [param launch]. Annulée ou refusée : [param restore] remet les réglages du Duel d'avant.
func _queue_duel(title: String, sub: String, opp: String, level: int, diff: int, launch: Callable, restore := Callable()) -> void:
	if _launching:
		return
	var q := DuelQueue.open(self, title, sub, opp, level, diff, launch, func(section: String, on_closed: Callable):
		_open_hero(section)
		_hero.closed.connect(on_closed, CONNECT_ONE_SHOT))
	q.cancelled.connect(func(_reason):
		if restore.is_valid():
			restore.call()
		_show_menu(_current))


## Mode Duel : conditions d'inscription (build complet), adversaire, difficulté, inscription.
func _menu_duel() -> void:
	var cid := Profile.selected_class
	_activity_head("duel")
	_duel_tabs()
	if _duel_tab == "league" and Unlocks.is_open("league"):
		_menu_league()
		return
	if _duel_tab == "pantheon" and Unlocks.is_open("pantheon"):
		_menu_pantheon()
		return
	if _duel_tab == "gauntlet" and Unlocks.is_open("gauntlet"):
		_menu_gauntlet()
		return
	_duel_tab = "free"
	Duel.restore_free()  # (passe M7) une partie classée ou en équipe interrompue ne laisse pas ses réglages ici
	Duel.mode = "free"
	# deux modes : à l'arme (rien que le préréglage de sorts, niveau au choix) ou équipé (tout compte)
	var modes := HBoxContainer.new()
	modes.add_theme_constant_override("separation", 8)
	_sub.add_child(modes)
	for m in [[true, "À l'arme"], [false, "Équipé"]]:
		var mb := MenuWidgets.glass_button(String(m[1]) + ("  ✔" if Duel.bare == bool(m[0]) else ""), 16, Vector2(0, 42))
		mb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		mb.tooltip_text = "Aucune pièce ni bonus de méta : l'arme de ta classe et ton préréglage de sorts, niveau au choix. Les deux héros sont à armes égales." if bool(m[0]) 			else "Tout ce que tu as réglé compte : équipement, maîtrise, certificats. Le niveau est celui de ton équipement."
		mb.pressed.connect(func():
			Duel.bare = bool(m[0])
			_show_menu("duel"))
		modes.add_child(mb)
	if Duel.bare:
		var lr := HBoxContainer.new()
		lr.add_theme_constant_override("separation", 8)
		_sub.add_child(lr)
		Hud._label(lr, "Niveau du duel", 15, UiTheme.TEXT)
		var sp := SpinBox.new()
		sp.min_value = 1
		sp.max_value = 100
		sp.value = Duel.bare_level
		sp.value_changed.connect(func(x): Duel.bare_level = int(x))
		lr.add_child(sp)
		var variants := WeaponAttacks.variants(Items.default_weapon_type(cid))
		if variants.size() > 1:
			Hud._label(lr, "Arme", 15, UiTheme.TEXT)
			var vo := OptionButton.new()
			vo.focus_mode = Control.FOCUS_NONE
			for vv in variants:
				vo.add_item(String(vv.get("name", "?")))
			vo.select(clampi(Duel.bare_variant, 0, variants.size() - 1))
			vo.item_selected.connect(func(i): Duel.bare_variant = i)
			lr.add_child(vo)
	_req_list(Duel.requirements(cid))
	var opp := HBoxContainer.new()
	opp.add_theme_constant_override("separation", 8)
	_sub.add_child(opp)
	var built := not Duel.rival_build.is_empty()
	var ob := MenuWidgets.glass_button(("Adversaire : %s (éditeur) ▾" % Duel.rival_build.get("name", "?")) if built
		else "Adversaire : %s ▾" % GameData.class_data(_duel_opp).get("name_fr", _duel_opp), 15, Vector2(0, 40))
	ob.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ob.tooltip_text = "Choisir une classe : adversaire simple (l'adversaire de l'éditeur est laissé de côté)"
	ob.pressed.connect(func(): HeroPages.class_menu(ob, _duel_opp, func(c):
		_duel_opp = c
		Duel.rival_build = {}
		Duel.rival_spells = Duel.grid12([])
		_show_menu("duel")))
	opp.add_child(ob)
	var dd := OptionButton.new()
	dd.focus_mode = Control.FOCUS_NONE
	for n in ClassRival.NAMES:
		dd.add_item(n)
	dd.select(_duel_diff)
	dd.item_selected.connect(func(i):
		_duel_diff = i
		_show_menu("duel"))
	opp.add_child(dd)
	# IA de l'adversaire : script de l'entraînement ou cerveau entraîné (arène ML)
	var pl := OptionButton.new()
	pl.focus_mode = Control.FOCUS_NONE
	pl.add_item("IA scriptée")
	var brains := MlDuelPilot.available()
	for b in brains:
		pl.add_item("Cerveau %s" % b[1])
		if String(b[0]) == Duel.pilot:
			pl.select(pl.item_count - 1)
	pl.tooltip_text = "IA scriptée : réglée par la difficulté. Cerveau : une IA entraînée, bien plus redoutable." if not brains.is_empty() else "Aucun cerveau d'IA entraîné sur ce PC."
	pl.item_selected.connect(func(i):
		Duel.pilot = "" if i == 0 else String(brains[i - 1][0])
		_show_menu("duel"))
	opp.add_child(pl)
	dd.disabled = Duel.pilot != ""
	Hud._label(_sub, ("Victoires contre cette classe : %d" % Duel.wins_against(_duel_opp, _duel_diff)) if Duel.bare
		else ("Niveau du duel : %d · victoires contre cette classe : %d" % [Duel.gear_level(), Duel.wins_against(_duel_opp, _duel_diff)]), 14, UiTheme.MUTED)  # (passe M7 : 14 px au moins)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	_sub.add_child(row)
	var ed := MenuWidgets.glass_button("Éditeur d'adversaire", 14, Vector2(0, 40))
	ed.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ed.tooltip_text = "Sa classe, son équipement, son trophée, son apparence, ses certificats et ses sorts ; plusieurs adversaires enregistrés"
	ed.pressed.connect(func():
		Duel.difficulty = _duel_diff
		var b := Duel.rival_build if built else RivalBuilds.blank(_duel_opp, Duel.gear_level())
		ProfileEditor.open(self, b, func(nb):
			Duel.rival_build = nb
			_duel_opp = String(nb.get("class", _duel_opp))
			_show_menu("duel")))
	row.add_child(ed)
	if not built:
		var prep := MenuWidgets.glass_button("Préparation rapide", 14, Vector2(0, 40))
		prep.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		prep.tooltip_text = "PV ×%.1f, dégâts ×%.1f" % [Duel.hp_mult, Duel.atk_mult]
		prep.pressed.connect(func():
			Duel.rival_class = _duel_opp
			Duel.difficulty = _duel_diff
			DuelPrep.open(self, func(): _show_menu("duel")))
		row.add_child(prep)
	var go := MenuWidgets.gold_button("S'inscrire au duel", 22, Vector2(0, 58))
	go.disabled = not Duel.is_ready(cid)
	go.tooltip_text = "" if not go.disabled else "Règle d'abord les points marqués ✘"
	go.pressed.connect(_start_duel)
	_pin(go)


func _start_duel() -> void:
	if _launching or not Duel.is_ready(Profile.selected_class):
		return
	var opp := String(Duel.rival_build.get("class", _duel_opp)) if not Duel.rival_build.is_empty() else _duel_opp
	var diff := _duel_diff
	var lv := Duel.bare_level if Duel.bare else Duel.gear_level()
	var launch := func():
		_launching = true
		if backdrop:
			backdrop.release()
		Duel.start(Profile.selected_class, _duel_opp, diff)
		get_tree().change_scene_to_file.call_deferred(RUN_SCENE)
	_queue_duel("Duel libre", "Duel libre · %s" % ("à l'arme" if Duel.bare else "équipé"), opp, lv, diff, launch)


## La Tour : choix de la difficulté (IA des duellistes, force des monstres, record à part).
func _menu_tower() -> void:
	_activity_head("tower")
	if Tower.checkpoint(1) > 1 or Tower.checkpoint(_tower_diff) > 1:
		var d := _tower_diff
		var from := Tower.checkpoint(d)
		if from > 1:
			_row("Reprendre l'ascension", "Étage %d · %s · %s" % [from, TowerPages.floor_what(Tower.spec(from, d)), Tower.DIFF_NAMES[d]], "continue", func(): _start_tower(d, from), 64.0)
	_section("Difficulté")
	const DIFF_ICONS := ["heart", "defense", "attack", "power"]
	for i in Tower.DIFF_NAMES.size():
		var di := i
		_row("%s  ·  %d / %d" % [Tower.DIFF_NAMES[i], Tower.best(i), Tower.FLOORS], String(Tower.DIFF_DESC[i]), DIFF_ICONS[i % DIFF_ICONS.size()], func():
			_tower_diff = di
			_tower_sel = mini(Tower.best(di) + 1, Tower.FLOORS)
			_tower_page = (_tower_sel - 1) / TowerPages.FLOORS_PER_PAGE
			_show_menu("tower_floors"), 72.0)


## Étages de la difficulté choisie, 5 par page : battus et suivant jouables, les autres
## verrouillés ; un clic choisit l'étage, « i » ouvre sa fiche (ennemi, sorts, équipement).
func _menu_tower_floors() -> void:
	var diff := _tower_diff
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	_sub.add_child(head)
	var back := MenuWidgets.glass_button("‹  Difficulté", 15, Vector2(150, 36))
	back.pressed.connect(_show_menu.bind("tower"))
	head.add_child(back)
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(gap)
	var mine_floor := mini(Tower.best(diff) + 1, Tower.FLOORS)
	var mine := MenuWidgets.glass_button("Mon étage", 15, Vector2(130, 36))
	mine.disabled = _tower_sel == mine_floor
	mine.pressed.connect(func():
		_tower_sel = mine_floor
		_tower_page = (mine_floor - 1) / TowerPages.FLOORS_PER_PAGE
		_show_menu("tower_floors"))
	head.add_child(mine)
	_sub_title("La Tour · %s" % Tower.DIFF_NAMES[diff])
	var nav := HBoxContainer.new()
	nav.add_theme_constant_override("separation", 8)
	_sub.add_child(nav)
	var pages := (Tower.FLOORS + TowerPages.FLOORS_PER_PAGE - 1) / TowerPages.FLOORS_PER_PAGE
	var prev := MenuWidgets.glass_button("◀", 18, Vector2(52, 38))
	prev.disabled = _tower_page <= 0
	prev.pressed.connect(func():
		_tower_page -= 1
		_show_menu("tower_floors"))
	nav.add_child(prev)
	var pl := Hud._label(nav, "Étages %d à %d  ·  %d / %d battus%s" % [_tower_page * TowerPages.FLOORS_PER_PAGE + 1, mini((_tower_page + 1) * TowerPages.FLOORS_PER_PAGE, Tower.FLOORS), Tower.best(diff), Tower.FLOORS,
		"\n(mode dev : tous débloqués)" if Tower.dev_unlock_all() else ""], 15, UiTheme.TEXT)
	pl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var nxt := MenuWidgets.glass_button("▶", 18, Vector2(52, 38))
	nxt.disabled = _tower_page >= pages - 1
	nxt.pressed.connect(func():
		_tower_page += 1
		_show_menu("tower_floors"))
	nav.add_child(nxt)
	for i in TowerPages.FLOORS_PER_PAGE:
		var fl := _tower_page * TowerPages.FLOORS_PER_PAGE + i + 1
		if fl > Tower.FLOORS:
			break
		var open := Tower.unlocked(fl, diff)
		var line := TowerPages.floor_line(fl, diff)
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 6)
		_sub.add_child(h)
		var icon := TowerPages.floor_icon(fl)  # type de l'étage (monstres, élites, ombre, halte, boss…)
		var r := MenuWidgets.RowButton.new(("🔒 " if not open else "") + String(line[0]), String(line[1]), icon, 56.0)
		r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		r.disabled = not open
		r.modulate = Color.WHITE if open else Color(1, 1, 1, 0.45)
		r.mark(fl == _tower_sel)
		if fl == _tower_sel:
			(func():  # petite fenêtre (1280 × 720) : l'étage choisi reste visible au-dessus du bouton épinglé
				await get_tree().process_frame
				if is_instance_valid(r) and is_instance_valid(_scroll):
					_scroll.ensure_control_visible(r)).call_deferred()
		r.pressed.connect(func():
			_tower_sel = fl
			_show_menu("tower_floors"))
		h.add_child(r)
		var info := MenuWidgets.glass_button("i", 18, Vector2(44, 56))
		info.tooltip_text = "Fiche de l'étage"
		info.pressed.connect(func(): TowerPages.info_popup(_sub, Tower.spec(fl, diff)))
		h.add_child(info)
	TowerPages.legend(_sub)
	var go := MenuWidgets.gold_button("Commencer à l'étage %d" % _tower_sel, 22, Vector2(0, 58))
	go.disabled = not Tower.unlocked(_tower_sel, diff)
	go.pressed.connect(_start_tower.bind(diff, _tower_sel))
	_pin(go)


func _start_tower(diff := 1, from := 1) -> void:
	if _launching:
		return
	_launching = true
	if backdrop:
		backdrop.release()
	Tower.start(Profile.selected_class, diff, from)
	get_tree().change_scene_to_file.call_deferred(RUN_SCENE)


func _start_run() -> void:
	if backdrop:
		backdrop.release()
	Run.start_survival(Profile.selected_class, clampi(_epoch, 1, Epochs.unlocked()), _heroic)
	get_tree().change_scene_to_file.call_deferred(RUN_SCENE)


# --- décor 3D : la map de la zone, le héros au premier plan ---------------------------------
func _build_scene() -> void:
	if not Profile.zone_unlocked(Profile.selected_zone):
		Profile.selected_zone = "limestone"
	backdrop = MapBackdrop.new()
	add_child(backdrop)
	backdrop.show_zone(Profile.selected_zone, true)
	backdrop.stage_hero()
	_snapshot = backdrop.snapshot()
	_show_hero()
	if _test_orbit.size() >= 4:
		backdrop.orbit_yaw = deg_to_rad(_test_orbit[0])
		backdrop.orbit_pitch = deg_to_rad(_test_orbit[1])
		backdrop.orbit_dist = _test_orbit[2]
		backdrop.orbit_lift = _test_orbit[3]
		backdrop.place_stage_camera()


func _show_hero() -> void:
	if backdrop == null:
		return
	for c in backdrop.hero_root.get_children():
		c.queue_free()
	var cls := GameData.class_data(Profile.selected_class)
	if cls.is_empty() or not ResourceLoader.exists(cls.model):
		return
	var model := EdenModel.instantiate_hero(cls, Profile.outfit_of(Profile.selected_class), Profile.worn_parts(Profile.selected_class),
		Profile.dye_map(Profile.selected_class), HeroLook.current())
	model.scale = Vector3.ONE * GameData.HERO_SCALE
	model.rotation.y = -0.45  # trois-quarts, tourné vers le menu
	backdrop.hero_root.add_child(model)
	EdenModel.attach_weapon(model, EdenModel.weapon_entry(cls, Profile.weapon_code()))
	EdenFx.attach_auras(backdrop.hero_root, Profile.selected_class, GameData.HERO_SCALE)
	var ap := EdenModel.find_anim_player(model)
	var battle: String = cls.anims.get("battle", "stand01")
	if ap and ap.has_animation(battle):
		ap.get_animation(battle).loop_mode = Animation.LOOP_LINEAR
		ap.play(battle)


var _tick := 0.0
var _orbit_drag := 0  # bouton tenu pour bouger la caméra (0 : aucun)
var _test_orbit: Array = []


## Caméra autour du héros, dans le décor (hors des menus) : glisser pour tourner, molette pour
## zoomer, clic droit glissé pour monter ou descendre, double-clic pour revenir à la vue de départ.
func _unhandled_input(event: InputEvent) -> void:
	if backdrop == null or _screen_open():
		_orbit_drag = 0
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.double_click and mb.button_index == MOUSE_BUTTON_LEFT:
			backdrop.reset_orbit()
		elif mb.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
			_orbit_drag = mb.button_index if mb.pressed else 0
		elif mb.pressed and mb.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			backdrop.orbit_dist = clampf(backdrop.orbit_dist * (0.88 if mb.button_index == MOUSE_BUTTON_WHEEL_UP else 1.14), 1.6, 10.0)
			backdrop.place_stage_camera()
	elif event is InputEventMouseMotion and _orbit_drag != 0:
		if not Input.is_mouse_button_pressed(_orbit_drag) and not (event as InputEventMouseMotion).button_mask:
			_orbit_drag = 0  # bouton relâché au-dessus d'un menu
			return
		var mm := event as InputEventMouseMotion
		if _orbit_drag == MOUSE_BUTTON_LEFT:
			backdrop.orbit_yaw -= mm.relative.x * 0.008
			backdrop.orbit_pitch = clampf(backdrop.orbit_pitch + mm.relative.y * 0.005, -0.25, 1.1)
		else:
			backdrop.orbit_lift = clampf(backdrop.orbit_lift + mm.relative.y * 0.006, -1.0, 1.2)
		backdrop.place_stage_camera()


## Un écran plein écran (Héros, Collection, Coffres, Paramètres, mode dev) est-il ouvert ?
func _screen_open() -> bool:
	for n in [_hero, _archive, _workshop, _chests, _settings]:
		if n and n.has_method("is_open") and n.is_open():
			return true
	return Dev.is_open() if Dev.has_method("is_open") else false


func _process(delta: float) -> void:
	_tick -= delta
	if _clock and _tick <= 0.0:
		_tick = 1.0
		_clock.text = Time.get_time_string_from_system().left(5)


# --- interface ------------------------------------------------------------------------------
func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)
	# voile à gauche pour la lisibilité des menus
	var veil := TextureRect.new()
	var grad := GradientTexture2D.new()
	grad.gradient = Gradient.new()
	grad.gradient.set_color(0, Color(0.02, 0.02, 0.07, 0.62))
	grad.gradient.set_color(1, Color(0.02, 0.02, 0.07, 0.0))
	veil.texture = grad
	veil.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	veil.stretch_mode = TextureRect.STRETCH_SCALE
	veil.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	veil.offset_right = 980
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(veil)
	var logo_box := Control.new()
	logo_box.position = Vector2(48, 22)
	logo_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(logo_box)
	MenuWidgets.logo(logo_box, 64)
	# menu de gauche
	# fenêtre basse (1280 × 720) : menu plus compact, il ne passe plus sous le panneau de zone ni sous le pied de page
	var compact := get_viewport().get_visible_rect().size.y < 840.0
	var top := 150.0 if compact else 196.0
	var left := VBoxContainer.new()
	left.position = Vector2(44, top)
	left.add_theme_constant_override("separation", 8 if compact else 12)
	root.add_child(left)
	for m in MENU:
		var b := MenuWidgets.SideButton.new(m[1], m[2], 48.0 if compact else 60.0)
		b.pressed.connect(_on_menu.bind(String(m[0])))
		left.add_child(b)
		_menu[m[0]] = b
	# sous-menu central
	var sp := PanelContainer.new()
	sp.add_theme_stylebox_override("panel", MenuWidgets.glass(14))
	sp.position = Vector2(372, top)
	sp.custom_minimum_size = Vector2(PANEL_W, 0)
	sp.visible = false
	root.add_child(sp)
	_sub_panel = sp
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	sp.add_child(col)
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(_scroll)
	_sub = VBoxContainer.new()
	_sub.add_theme_constant_override("separation", 10)
	_sub.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_sub)
	_foot = VBoxContainer.new()
	_foot.add_theme_constant_override("separation", 8)
	col.add_child(_foot)
	_sub.minimum_size_changed.connect(_queue_fit)
	_foot.minimum_size_changed.connect(_queue_fit)
	# badge de la classe (en haut à droite)
	var badge := PanelContainer.new()
	_badge = badge
	badge.add_theme_stylebox_override("panel", MenuWidgets.glass(12))
	badge.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	badge.offset_left = -380
	badge.offset_right = -28
	badge.offset_top = 24
	badge.offset_bottom = 104
	badge.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	badge.tooltip_text = "Changer de classe"
	root.add_child(badge)
	# clic : menu compact des classes par famille (comme dans l'écran Héros)
	badge.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			HeroPages.class_menu(badge, Profile.selected_class, _select_class))
	var bh := HBoxContainer.new()
	bh.add_theme_constant_override("separation", 14)
	badge.add_child(bh)
	_badge_icon = _tex(bh, Vector2(56, 56))
	var bv := VBoxContainer.new()
	bv.alignment = BoxContainer.ALIGNMENT_CENTER
	bv.add_theme_constant_override("separation", 0)
	bh.add_child(bv)
	_badge_hero = Hud._label(bv, "", 15, UiTheme.GOLD)
	_badge_hero.add_theme_font_override("font", UiTheme.bold_font())
	_badge_hero.clip_text = true
	_badge_hero.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_badge_hero.custom_minimum_size.x = 240.0
	_badge_name = Hud._label(bv, "", 21, Color(1, 0.97, 0.9))
	_badge_name.add_theme_font_override("font", UiTheme.bold_font())
	_badge_sub = Hud._label(bv, "", 14, UiTheme.MUTED)
	# zone et prochaine récompense (en bas à gauche)
	var zc := PanelContainer.new()
	zc.add_theme_stylebox_override("panel", MenuWidgets.glass(14, UiTheme.GOLD, 0.88))
	zc.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	zc.offset_left = 44
	zc.offset_right = 760 if get_viewport().get_visible_rect().size.x >= 1400.0 else 726  # 1280 : ne passe pas sous le pied de page
	zc.offset_top = -136
	zc.offset_bottom = -28
	root.add_child(zc)
	_zone_card = zc
	var zh := HBoxContainer.new()
	zh.add_theme_constant_override("separation", 16)
	zc.add_child(zh)
	_zone_thumb = _tex(zh, Vector2(150, 80))
	_zone_thumb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	var zv := VBoxContainer.new()
	zv.alignment = BoxContainer.ALIGNMENT_CENTER
	zv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	zh.add_child(zv)
	var zr := HBoxContainer.new()
	zr.add_theme_constant_override("separation", 8)
	zv.add_child(zr)
	var pin := _tex(zr, Vector2(26, 26))
	pin.texture = MenuWidgets.icon("pin")
	pin.modulate = UiTheme.GOLD
	_zone_name = Hud._label(zr, "", 22, Color(1, 0.97, 0.9))
	_zone_name.add_theme_font_override("font", UiTheme.bold_font())
	_zone_sub = Hud._label(zv, "", 14, UiTheme.MUTED)
	zh.add_child(VSeparator.new())
	var rv := VBoxContainer.new()
	rv.alignment = BoxContainer.ALIGNMENT_CENTER
	rv.custom_minimum_size = Vector2(250 if get_viewport().get_visible_rect().size.x >= 1400.0 else 210, 0)
	zh.add_child(rv)
	var rh := HBoxContainer.new()
	rv.add_child(rh)
	var rt := Hud._label(rh, "Prochaine récompense", 14, UiTheme.MUTED)
	rt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_reward_nums = Hud._label(rh, "", 14, UiTheme.TEXT)
	var rr := HBoxContainer.new()
	rr.add_theme_constant_override("separation", 10)
	rv.add_child(rr)
	var chest := _tex(rr, Vector2(34, 34))
	chest.texture = MenuWidgets.icon("chest")
	_reward_bar = ProgressBar.new()
	_reward_bar.show_percentage = false
	_reward_bar.custom_minimum_size = Vector2(190, 14)
	_reward_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_reward_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_reward_bar.add_theme_stylebox_override("background", UiTheme.flat_box(Color(0.03, 0.03, 0.08, 0.9), MenuWidgets.LINE, 1, 7, false))
	_reward_bar.add_theme_stylebox_override("fill", UiTheme.flat_box(UiTheme.GOLD, UiTheme.GOLD, 0, 7, false))
	rr.add_child(_reward_bar)
	_reward_text = Hud._label(rv, "", 12, UiTheme.MUTED)
	# sauvegarde, coffre commun et heure (en bas à droite)
	var info := PanelContainer.new()
	info.add_theme_stylebox_override("panel", MenuWidgets.glass(12, MenuWidgets.LINE))
	info.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	info.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	info.offset_left = -400
	info.offset_right = -28
	info.offset_top = -86
	info.offset_bottom = -36
	var orbit_hint := Hud._label(root, "Glisser : tourner · Molette : zoom", 12, Color(1, 1, 1, 0.7))
	orbit_hint.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	orbit_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	orbit_hint.offset_left = -760
	orbit_hint.offset_right = -32
	orbit_hint.offset_top = -112
	orbit_hint.offset_bottom = -92
	orbit_hint.add_theme_constant_override("outline_size", 4)
	orbit_hint.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	orbit_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# l'aide de la caméra s'efface après quelques secondes (la scène reste dégagée)
	var fade := orbit_hint.create_tween()
	fade.tween_interval(8.0)
	fade.tween_property(orbit_hint, "modulate:a", 0.0, 1.5)
	root.add_child(info)
	_info_bar = info
	var ih := HBoxContainer.new()
	ih.add_theme_constant_override("separation", 10)
	ih.alignment = BoxContainer.ALIGNMENT_END
	info.add_child(ih)
	var user := _tex(ih, Vector2(22, 22))
	user.texture = MenuWidgets.icon("user")
	user.modulate = MenuWidgets.ICON_TINT
	_footer = Hud._label(ih, "", 14, UiTheme.TEXT)
	_footer.mouse_filter = Control.MOUSE_FILTER_STOP
	_footer.tooltip_text = ResourceHelp.tip("insignia") + "\n\n" + ResourceHelp.tip("crystal")  # où les gagner, où les dépenser
	# Registre de l'équipement (lot E3) : classes équipées ; un clic ouvre le Registre du Carnet
	_gear_sep = VSeparator.new()
	ih.add_child(_gear_sep)
	_gear_band = Hud._label(ih, "", 14, UiTheme.TEXT)
	_gear_band.mouse_filter = Control.MOUSE_FILTER_STOP
	_gear_band.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_gear_band.tooltip_text = "Registre de l'équipement"
	_gear_band.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT and Unlocks.is_open("collection"):
			_open_registry())
	ih.add_child(VSeparator.new())
	var clock := _tex(ih, Vector2(22, 22))
	clock.texture = MenuWidgets.icon("clock")
	clock.modulate = MenuWidgets.ICON_TINT
	_clock = Hud._label(ih, "", 14, UiTheme.TEXT)
	# mode dev (activé dans les Paramètres) : bouton au-dessus du pied de page
	_dev_button = MenuWidgets.glass_button("Mode dev  (F10)", 15, Vector2(200, 38))
	_dev_button.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_dev_button.offset_left = -228
	_dev_button.offset_right = -28
	_dev_button.offset_top = -136
	_dev_button.offset_bottom = -98
	_dev_button.pressed.connect(func(): Dev.open())
	root.add_child(_dev_button)
	Settings.changed.connect(func():
		_dev_button.visible = Dev.enabled()
		_refresh_compass())

	_build_compass(root)
	# écrans plein écran
	_hero = HeroScreen.new(6)
	add_child(_hero)
	_hero.closed.connect(func():
		if _launching:
			return
		_show_hero()  # classe, arme ou apparence ont pu changer
		_refresh_ui()
		if _current == "duel":
			_show_menu("duel"))  # conditions d'inscription à jour
	_archive = _screen("Carnet", CarnetPages.tabs())  # chaque onglet donne son sous-titre
	_workshop = _screen("Atelier", [["Fabriquer", GearShopPage.new()], ["Plans de donjon", FabricationPage.new()], ["Forge", ForgeBench.new()]])
	_workshop.set_title("Atelier")  # chaque onglet donne son sous-titre
	_workshop.add_header_control(WorkshopPurse.new())  # insignes et cristaux, quel que soit l'onglet
	_chests = _screen("Coffres", [["Coffres", ChestsPage.new()], ["Roulette", WheelPage.new()]])
	_chests.set_title("Coffres")  # le sous-titre vient de chaque onglet (ChestsPage / WheelPage .subtitle())
	_settings = SettingsMenu.new()
	add_child(_settings)
	_refresh_ui()


## La boussole : une pastille cliquable à gauche du badge de classe (jamais sur les pages) ; le texte se recalcule dans _refresh_ui.
func _build_compass(root: Control) -> void:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	b.expand_icon = true
	b.add_theme_font_size_override("font_size", 15)
	b.add_theme_constant_override("icon_max_width", 22)
	b.add_theme_constant_override("h_separation", 10)
	b.add_theme_color_override("font_color", UiTheme.TEXT)
	b.add_theme_color_override("font_hover_color", Color(1, 0.96, 0.8))
	b.add_theme_stylebox_override("normal", UiTheme.flat_box(Color(MenuWidgets.GLASS, 0.78), Color(UiTheme.GOLD_DIM, 0.8), 1, 20, false))
	b.add_theme_stylebox_override("hover", UiTheme.flat_box(Color(0.13, 0.12, 0.26, 0.95), UiTheme.GOLD, 2, 20, false))
	b.add_theme_stylebox_override("pressed", UiTheme.flat_box(Color(0.13, 0.12, 0.26, 0.95), UiTheme.GOLD, 2, 20, false))
	b.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	b.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	b.offset_right = -396  # à gauche du badge de classe
	b.offset_top = 44
	b.offset_bottom = 84
	b.visible = false
	b.pressed.connect(func(): _compass_open(_compass_go))
	root.add_child(b)
	_compass = b


## Met à jour la boussole : le conseil du moment (Compass.advice), ou rien hors du lobby.
func _refresh_compass() -> void:
	if _compass == null:
		return
	if not Settings.show_compass():
		_compass.visible = false
		return
	var adv := Compass.advice()
	_compass.visible = not adv.is_empty()
	if adv.is_empty():
		return
	_compass_go = adv.go
	_compass.text = String(adv.text)
	_compass.tooltip_text = "%s\n%s" % [adv.text, adv.tip] if String(adv.tip) != "" else String(adv.text)
	_compass.icon = ResourceHelp.icon(String(adv.icon)) if ResourceHelp.has(String(adv.icon)) else MenuWidgets.icon("pin")
	var font := _compass.get_theme_font("font")
	var want := font.get_string_size(_compass.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x + 70.0
	var room := get_viewport().get_visible_rect().size.x - 396.0 - 490.0  # entre le logo et le badge
	var w := clampf(want, 140.0, maxf(room, 140.0))
	_compass.custom_minimum_size.x = w
	_compass.offset_right = -396.0
	_compass.offset_left = -396.0 - w
	_compass.size = Vector2(w, 40)


## Le clic de la boussole : ouvre la page décrite par [param go] (voir Compass).
func _compass_open(go: Dictionary) -> void:
	if go.is_empty() or _launching:
		return
	if go.has("workshop"):
		_workshop.open(int(go.workshop))
	elif go.has("chests"):
		_chests.open(0)
	elif go.has("registry"):
		_open_registry()
	elif go.has("hero"):
		_open_hero(String(go.hero))
	elif go.has("menu"):
		if go.has("zone"):
			_dg_zone = String(go.zone)
		if go.has("tab"):
			_duel_tab = String(go.tab)
		_show_menu(String(go.menu))


## Carnet > Registre de l'équipement.
func _open_registry() -> void:
	for i in _archive.page_count():
		if _archive.page(i) is RegistryPage:
			_archive.open(i)
			return


func _tex(parent: Control, px: Vector2) -> TextureRect:
	var t := TextureRect.new()
	t.custom_minimum_size = px
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(t)
	return t


## Menu de gauche : sous-menu (Jouer, Quitter) ou écran plein écran.
func _on_menu(id: String) -> void:
	match id:
		"hero":
			_open_hero()
		"collection", "chests", "workshop":
			if not Unlocks.is_open(_menu_unlock(id)):
				return
			match id:
				"collection":
					_archive.open(0)
				"workshop":
					_workshop.open(0)
				_:
					_chests.open(0)
		"settings":
			_settings.open()
		_:
			# Jouer, Quitter : le panneau s'ouvre au clic et se referme au second clic
			_show_menu("" if id == _current else id)


## Accueil d'une nouvelle partie ; sinon les nouveautés (une fenêtre par version) et la fiche en attente.
func _welcome_flow() -> void:
	if not OS.get_cmdline_user_args().is_empty() or Settings.save_path == Settings.TEST_SAVE_PATH:
		return
	var notice := SafeFile.take_notice()
	if notice != "":
		# une sauvegarde abîmée a été remplacée par sa dernière copie saine
		info_cards().add_card({"id": "save_notice", "kicker": "Sauvegarde", "title": "Copie saine rechargée", "body": notice, "icon": "save"})
	Tutorial.init_for_save()
	if Tutorial.mode() == "":
		var w := Welcome.new()
		add_child(w)
		w.finished.connect(func(warmup: bool):
			_refresh_ui()
			# création de personnage (C1) : juste après le choix de la classe, avant l'échauffement ou la première Survie
			_open_creator(true, func(_ok: bool):
				if warmup:
					_start_training()))
		return
	if HeroLook.needs_creation():
		# ancien compte : la création s'ouvre une fois, pré-remplie (« Garder tel quel »), puis les nouveautés
		_open_creator(true, func(_ok: bool): _show_news_flow())
		return
	var news := Tutorial.news_to_show()
	var pending := Tutorial.take_card()
	if pending != "" and not pending in news:
		news.append(pending)
	news = Tutorial.news_sorted(news)
	Profile.save_profile()
	_show_news_flow()


## Nouveautés de la version (une carte par fiche) et fiche en attente.
func _show_news_flow() -> void:
	if news.is_empty():
		return
	_show_news(news)


## Les nouveautés en petites cartes : une par fiche, la plus récente d'abord, trois au plus, puis le Guide.
func _show_news(news: Array) -> void:
	var cards := info_cards()
	# sur une petite fenêtre, moins de cartes : la dernière place est celle de « Tout voir dans le Guide »
	var room := cards.capacity()
	var shown := news.size() if news.size() <= mini(room, NEWS_CARDS) else mini(room - 1, NEWS_CARDS)
	shown = maxi(1, shown)
	for id in news.slice(0, shown):
		var spec := Tutorial.card_spec(String(id))
		spec["kicker"] = "Nouveau"
		spec["buttons"] = [{"label": "Compris", "kind": "primary"},
				{"label": "Guide", "kind": "plain", "cb": func(): _guide_from_cards(String(id))}]
		cards.add_card(spec)
	if news.size() > shown:
		cards.add_card({"id": "news_more", "icon": "new",
				"title": "%d autres nouveautés" % (news.size() - shown), "body": "Tu les retrouves toutes dans le Guide.",
				"buttons": [{"label": "Tout voir dans le Guide", "kind": "primary", "cb": func(): _guide_from_cards("news")},
						{"label": "Plus tard", "kind": "link"}]})


## Un bouton « Guide » d'une carte : les cartes se retirent (elles ne restent pas au-dessus du Guide) et le cadre de la manette y entre.
func _guide_from_cards(chapter: String) -> void:
	info_cards().dismiss_all("guide")
	Guide.open_on(self, chapter)
	UiNav.cursor = null


## Pile de petites cartes d'information (en haut à droite, sous la carte du héros ; B ou Échap ferment la première).
func info_cards() -> InfoCard:
	if _cards == null or not is_instance_valid(_cards):
		_cards = InfoCard.in_layer(self)
	return _cards


## Entrée du fil d'éveil (Unlocks) d'un bouton du menu de gauche.
func _menu_unlock(id: String) -> String:
	return {"collection": "collection", "chests": "chests", "workshop": "armory"}.get(id, "survival")


## Grise les boutons du menu dont l'entrée n'est pas encore ouverte, avec la condition en infobulle.
func _refresh_locks() -> void:
	for id in ["collection", "chests", "workshop"]:
		if not _menu.has(id):
			continue
		var key := _menu_unlock(id)
		var open := Unlocks.is_open(key)
		_menu[id].modulate = Color.WHITE if open else Color(1, 1, 1, 0.42)
		_menu[id].tooltip_text = "" if open else Unlocks.lock_text(key)


## Bouton d'action de la page (Lancer, Entrer, S'inscrire) : épinglé sous la zone qui défile, toujours visible.
func _pin(b: Control) -> void:
	_foot.add_child(b)


## Bouton d'action grisé : la raison s'écrit juste au-dessus (et reste en infobulle).
func _pin_go(go: Button, reason: String) -> void:
	go.tooltip_text = reason
	if go.disabled and reason != "":
		var l := Hud._label(_foot, reason, 13, Color(1.0, 0.55, 0.5))
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.custom_minimum_size = Vector2(200, 0)
	_foot.add_child(go)


## Titre de section d'une page ; [param tip] : le détail au survol.
func _section(text: String, tip := "") -> Label:
	var l := Hud._label(_sub, text, 15, UiTheme.GOLD)
	l.add_theme_font_override("font", UiTheme.bold_font())
	if tip != "":
		l.mouse_filter = Control.MOUSE_FILTER_STOP
		l.tooltip_text = tip
	return l


## La zone qui défile prend la hauteur de la page, sans dépasser l'écran (le bouton épinglé reste dessous).
func _queue_fit() -> void:
	if not _fit_queued:
		_fit_queued = true
		_fit_scroll.call_deferred()


func _fit_scroll() -> void:
	_fit_queued = false
	if _scroll == null or not is_inside_tree():
		return
	var foot_h := _foot.get_combined_minimum_size().y if _foot.get_child_count() > 0 else 0.0
	var bottom := PANEL_BOTTOM
	if _info_bar != null:
		var info_left := get_viewport().get_visible_rect().size.x - 28.0 - maxf(372.0, _info_bar.get_combined_minimum_size().x)
		if info_left < _sub_panel.position.x + _sub_panel.custom_minimum_size.x:
			bottom = 100.0  # le panneau passerait sous le pied de page
	var avail := get_viewport().get_visible_rect().size.y - _sub_panel.position.y - bottom - 28.0 - (foot_h + 10.0 if foot_h > 0.0 else 0.0)
	var want := clampf(_sub.get_combined_minimum_size().y, 0.0, maxf(avail, 120.0))
	if absf(_scroll.custom_minimum_size.y - want) > 0.5:
		_scroll.custom_minimum_size.y = want
	_sub_panel.size = Vector2.ZERO  # toujours : le bouton épinglé change sans que la zone qui défile change de hauteur
	if _scroll_keep > 0:
		var keep := _scroll_keep
		_scroll_keep = 0
		await get_tree().process_frame
		_scroll.scroll_vertical = keep


func _show_menu(id: String) -> void:
	_scroll_keep = int(_scroll.scroll_vertical) if _scroll != null and id != "" and id == _shown_page else 0
	_shown_page = id
	_current = id
	if _sub_panel:
		_sub_panel.visible = id != ""
	if _zone_card:
		_zone_card.visible = id == ""  # sous-menu ouvert : le panneau de zone laisse la place
	for k in _menu:
		_menu[k].selected = k == ("" if id == "" else ("quit" if id == "quit" else "play"))
	for box in [_sub, _foot]:
		for c in box.get_children():
			box.remove_child(c)
			c.queue_free()
	if _sub_panel:
		# activités en grille : panneau large ; pages et autres sous-menus : largeur fixe
		_sub_panel.custom_minimum_size.x = PLAY_W if id == "play" else PANEL_W
		_sub_panel.size = Vector2.ZERO
	match id:
		"play":
			_menu_play()
		"survival", "zones":
			_menu_survival()
		"survivor":
			_menu_survivor()
		"training":
			_menu_training()
		"dungeon":
			_menu_dungeon()
		"arenas":
			_menu_arenas()
		"royale":
			_menu_royale()
		"rush":
			_menu_rush()
		"siege":
			_menu_siege()
		"trials":
			_menu_soon(id)
		"quests":
			_menu_quests()
		"tower":
			_menu_tower()
		"tower_floors":
			_menu_tower_floors()
		"duel":
			_menu_duel()
		"quit":
			_menu_quit()


func _sub_title(t: String) -> void:
	var l := Label.new()
	l.text = t
	UiTheme.title(l, 22)
	_sub.add_child(l)


func _row(title: String, sub: String, icon: String, cb: Callable, height := 70.0) -> MenuWidgets.RowButton:
	var r := MenuWidgets.RowButton.new(title, sub, icon, height)
	r.pressed.connect(cb)
	_sub.add_child(r)
	return r


## Menu Jouer : toutes les activités, en étiquettes illustrées (Activities), JcE puis JcJ ;
## un clic ouvre la page de l'activité (réglages, puis Lancer) dans ce même panneau.
func _menu_play() -> void:
	for row in Activities.ROWS:
		_section(String(row[1]))
		var grid := GridContainer.new()
		grid.columns = 3
		grid.add_theme_constant_override("h_separation", 10)
		grid.add_theme_constant_override("v_separation", 10)
		_sub.add_child(grid)
		var cards := Activities.LIST.filter(func(x): return x.row == row[0] and not x.get("soon", false) and not Activities.hidden(x))  # les « Bientôt » restent cachés
		for a in cards:
			grid.add_child(_activity_card(a, Vector2(230, 112)))
		for _k in (3 - cards.size() % 3) % 3:
			var gap := Control.new()  # une rangée incomplète garde la largeur des cartes
			gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			grid.add_child(gap)
	var tr := _activity_card(Activities.get_def("training"), Vector2(0, 52))
	_sub.add_child(tr)


func _activity_card(a: Dictionary, size := Vector2(345, 112)) -> Button:
	var c := Activities.card(a, size)
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if Activities.locked(a):
		c.tooltip_text = Unlocks.lock_text(String(a.unlock))  # grisée : la condition dit comment l'ouvrir
		c.pressed.connect(func(): c.tooltip_text = Unlocks.lock_text(String(a.unlock)))
	else:
		c.pressed.connect(_show_menu.bind(String(a.id)))
		if String(a.get("row", "")) != "":
			c.tooltip_text = "Donne : %s" % String(a.get("gain", "")).to_lower()
	return c


## En-tête d'une page d'activité : retour aux activités et bandeau illustré.
func _activity_head(id: String) -> void:
	var back := MenuWidgets.glass_button("‹  Activités", 15, Vector2(150, 36))
	back.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	back.pressed.connect(_show_menu.bind("play"))
	_sub.add_child(back)
	var bn := Activities.banner(Activities.get_def(id))
	bn.custom_minimum_size.y = 118
	_sub.add_child(bn)
	var gl := GainChips.line(Activities.get_def(id), Activities.locked(Activities.get_def(id)))  # ce que cette activité donne
	if gl != null:
		_sub.add_child(gl)


## Survie : l'époque (3 cartes), le rang héroïque, puis Lancer.
func _menu_survival() -> void:
	_activity_head("survival")
	_section("Époque")
	_epoch = clampi(_epoch, 1, Epochs.unlocked())
	for i in range(1, Epochs.count() + 1):
		var e := Epochs.get_def(i)
		var open := i <= Epochs.unlocked()
		var sub := ""
		if open:
			var zones: Array = (e.zones as Array).map(func(z): return String(GameData.zone(String(z)).get("name", z)))
			sub = "%s\n%s  ·  Défi : %s%s" % [" → ".join(zones), Epochs.star_text(i), Epochs.CHALLENGES[i - 1], ("  ·  Rang héroïque %d" % Epochs.heroic_best(i)) if Epochs.heroic_best(i) > 0 else ""]
		else:
			sub = "🔒 Termine l'%s" % Epochs.get_def(i - 1).name
		var ei := i
		var r := _row(String(e.name), sub, "pin", func():
			_epoch = ei
			_select_zone(Epochs.zone(ei, 1))
			_show_menu("survival"), 62.0)
		r.disabled = not open
		if not open:
			r.modulate = Color(1, 1, 1, 0.5)
		r.mark(i == _epoch)
	if Epochs.heroic_open() and Epochs.heroic_best(_epoch) >= 0:
		var top := mini(Epochs.heroic_best(_epoch) + 1, Epochs.HEROIC_MAX)
		_heroic = clampi(_heroic, 0, top)
		var hr := HBoxContainer.new()
		hr.add_theme_constant_override("separation", 8)
		_sub.add_child(hr)
		var minus := MenuWidgets.glass_button("−", 18, Vector2(48, 40))
		minus.disabled = _heroic <= 0
		minus.pressed.connect(func():
			_heroic -= 1
			_show_menu("survival"))
		hr.add_child(minus)
		var hl := Hud._label(hr, "Rang héroïque %d" % _heroic, 16, UiTheme.TEXT)
		hl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hl.mouse_filter = Control.MOUSE_FILTER_STOP
		hl.tooltip_text = ("Monstres +%d %% PV et +%d %% dégâts ; insignes +%d %%." % [roundi(Epochs.HEROIC_HP * 100 * _heroic), roundi(Epochs.HEROIC_ATK * 100 * _heroic), roundi(Epochs.HEROIC_INSIGNIA * 100 * _heroic)]) if _heroic > 0 else "Une Survie normale."
		var plus := MenuWidgets.glass_button("+", 18, Vector2(48, 40))
		plus.disabled = _heroic >= top
		plus.pressed.connect(func():
			_heroic += 1
			_show_menu("survival"))
		hr.add_child(plus)
		if _heroic >= 3:
			var cons: Array = Epochs.heroic_mods(_heroic).map(func(m): return String(Modifiers.LIST[m].text))
			Hud._label(_sub, "Contraintes : " + " · ".join(cons), 13, UiTheme.MUTED).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var go := MenuWidgets.gold_button("Lancer la run", 22, Vector2(0, 56))
	go.pressed.connect(_launch)
	_pin(go)


## Survivant : une phrase, la classe, le palier (lot S8 : I à V, chacun ouvert par une victoire au précédent), ses coffres
## d'apparence, la zone (décor, monstres et boss ; aucune n'est plus dure), puis Lancer. Aucune condition de progression.
var _sv_zone := ""
var _sv_palier := 0  # 0 : le plus haut palier ouvert (choisi à la 1re ouverture de la page)


func _menu_survivor() -> void:
	_activity_head("survivor")
	_activity_desc("survivor")
	_survivor_overview()  # (lot S5) le mode en trois idées, puis la classe
	_section("Classe")
	var cr := _row(String(GameData.class_data(Profile.selected_class).get("name_fr", Profile.selected_class)), "Changer de classe", "class", func(): pass, 56.0)
	cr.pressed.connect(func(): HeroPages.class_menu(cr, Profile.selected_class, func(id: String):
		_select_class(id)
		_show_menu("survivor")))
	_survivor_tiers()
	_survivor_rewards(_sv_palier)
	_section("Zone")
	var zones := Survivor.zones()
	if not _sv_zone in zones:
		_sv_zone = Profile.selected_zone if Profile.selected_zone in zones else String(zones[0])
	for z in zones:
		var zd := GameData.zone(String(z))
		var boss := String(GameData.monster(int(zd.get("dungeon", {}).get("boss", 0))).get("name", ""))
		var zid := String(z)
		var r := _row(String(zd.get("name", zid)), "Boss : %s" % boss if boss != "" else "", "pin", func():
			_sv_zone = zid
			_show_menu("survivor"), 56.0)
		r.mark(zid == _sv_zone)
	var go := MenuWidgets.gold_button("Lancer le Survivant", 22, Vector2(0, 56))
	go.pressed.connect(_start_survivor)
	_pin(go)


## Ce que le Survivant donne : trois coffres d'apparence selon l'avancée (✔ une fois gagnés), le titre au boss.
func _survivor_rewards(tier: int) -> void:
	_section("Coffres d'apparence", "Chaque palier d'avancée donne son coffre une fois ; ensuite, un coffre commun et un coffre rare au plus par jour.")
	for g in SurvivorRewards.board(tier):
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 8)
		_sub.add_child(h)
		var mark := Hud._label(h, "✔" if bool(g.done) else "◇", 15, UiTheme.GOLD if bool(g.done) else UiTheme.MUTED)
		mark.custom_minimum_size = Vector2(18, 0)
		var t := Hud._label(h, String(g.text) + ("  ·  titre « %s »" % String(g.title) if String(g.title) != "" else ""), 15, UiTheme.TEXT)
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var c: Dictionary = Rewards.TYPES[String(g.type)]
		var n := Hud._label(h, String(c.name).trim_prefix("Coffre d'apparence "), 15, c.color)
		n.tooltip_text = String(c.name)
		n.mouse_filter = Control.MOUSE_FILTER_STOP
		var gap := Control.new()  # la rareté ne touche pas la barre de défilement
		gap.custom_minimum_size = Vector2(10, 0)
		h.add_child(gap)


## Survivant (lot S8) : les cinq paliers en une rangée (le choisi en or, un fermé grisé avec sa condition), puis ce que le
## palier choisi ajoute, en une phrase (le détail au survol).
func _survivor_tiers() -> void:
	if _sv_palier <= 0 or _sv_palier > Survivor.top_palier():
		# par défaut : celui de la run qui vient de finir (bilan -> lobby), sinon le plus haut palier gagné (le mode dev ouvre les autres)
		var last := int(SurvivorRewards.last.get("tier", 0))
		_sv_palier = last if last > 0 and Survivor.palier_open(last) else Survivor.top_palier(false)
	_section("Palier", "Chaque palier garde les règles du précédent et en ajoute une. Gagne un palier pour ouvrir le suivant.")
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	_sub.add_child(h)
	for p in range(1, Survivor.PALIERS.size() + 1):
		var open := Survivor.palier_open(p)
		var t: Dictionary = Survivor.PALIERS[p - 1]
		var b := MenuWidgets.glass_button(Survivor.numeral(p) if open else "🔒 " + Survivor.numeral(p), 18, Vector2(0, 44))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.disabled = not open
		b.tooltip_text = ("%s · %s" % [String(t.name), String(t.rule)]) if open else "Gagne le palier %s pour l'ouvrir." % Survivor.numeral(p - 1)
		if p == _sv_palier:
			b.add_theme_stylebox_override("normal", UiTheme.flat_box(Color(0.14, 0.11, 0.24, 0.96), UiTheme.GOLD, 2, 12))
			b.add_theme_color_override("font_color", UiTheme.GOLD)
		elif not open:
			b.add_theme_color_override("font_disabled_color", UiTheme.MUTED)
		var pp := p
		b.pressed.connect(func():
			_sv_palier = pp
			_show_menu("survivor"))
		h.add_child(b)
	var cur: Dictionary = Survivor.PALIERS[_sv_palier - 1]
	var l := Hud._label(_sub, "%s · %s" % [String(cur.name), String(cur.rule)], 15, UiTheme.TEXT)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.mouse_filter = Control.MOUSE_FILTER_STOP
	l.tooltip_text = String(cur.tip)


## Survivant (lot S5) : le mode en trois idées, une icône et quelques mots chacune.
func _survivor_overview() -> void:
	var g := GridContainer.new()
	g.columns = 3
	g.add_theme_constant_override("h_separation", 8)
	_sub.add_child(g)
	for e in [["armor", "Pièces à vie"], ["upgrade", "Passifs +6 +8 +10"], ["clock", "Boss à 20:00"]]:
		var p := PanelContainer.new()
		p.add_theme_stylebox_override("panel", UiTheme.flat_box(Color(0.08, 0.06, 0.15, 0.85), UiTheme.GOLD_DIM, 1, 8, false))
		p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		g.add_child(p)
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 8)
		p.add_child(h)
		var ic := TextureRect.new()
		ic.texture = MenuWidgets.icon(String(e[0]))
		ic.custom_minimum_size = Vector2(26, 26)
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ic.modulate = Color(1.0, 0.9, 0.62)
		h.add_child(ic)
		var l := Hud._label(h, String(e[1]), 14, UiTheme.TEXT)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.custom_minimum_size = Vector2(90, 0)


func _start_survivor() -> void:
	if _launching:
		return
	_launching = true
	if backdrop:
		backdrop.release()
	Survivor.start(Profile.selected_class, _sv_zone, clampi(_sv_palier, 1, Survivor.top_palier()))
	get_tree().change_scene_to_file.call_deferred(RUN_SCENE)


## Zone d'entraînement : description, puis Entrer.
func _menu_training() -> void:
	_activity_head("training")
	var go := MenuWidgets.gold_button("Entrer", 22, Vector2(0, 56))
	go.pressed.connect(_start_training)
	_pin(go)


## Quêtes : celles du jour (dont le Défi du jour), de la semaine et de la classe (QuestsPage).
func _menu_quests() -> void:
	_activity_head("quests")
	QuestsPage.fill(_sub, _start_challenge, _show_menu.bind("quests"))


func _start_challenge(cid: String) -> void:
	if _launching:
		return
	_launching = true
	if backdrop:
		backdrop.release()
	Profile.selected_class = cid
	Challenge.start(cid)
	get_tree().change_scene_to_file.call_deferred(RUN_SCENE)


## Donjons : un par zone (ouvert quand son boss est battu en Survie), trois difficultés, jusqu'à deux alliés IA.
var _dg_zone := ""
var _dg_diff := 0
var _dg_allies: Array = ["", ""]


## Donjons à la carte (passe M2) : boss, pièces et panoplie choisis dans la liste filtrable (DungeonPage).
func _menu_dungeon() -> void:
	DungeonPage.fill(self)


## Choix de la zone (un donjon par zone, ouvert quand son boss est battu en Survie) et de la difficulté, pour les
## Donjons et pour Le Siège ([param siege] : la PE exigée est celle du Siège). [param menu] : page à rouvrir au clic.
func _dungeon_pickers(menu: String, siege: bool) -> void:
	var zids := Dungeons.zone_ids()
	if _dg_zone == "" or not _dg_zone in zids:
		_dg_zone = String(zids[0])
	_section("Donjon" if not siege else "Arène et boss")
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 6)
	_sub.add_child(grid)
	for zid in zids:
		var open := Dungeons.is_open(String(zid))
		var done := false
		for d in Dungeons.DIFF_NAMES.size():
			done = done or (Siege.clears(String(zid), d) if siege else Dungeons.cleared(String(zid), d)) > 0
		var b := MenuWidgets.glass_button(("🔒 " if not open else ("✔ " if done else "")) + Dungeons.name_of(String(zid)), 14, Vector2(0, 40))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.modulate = Color.WHITE if open else Color(1, 1, 1, 0.45)
		b.tooltip_text = "Niveau %d (Normal)" % Dungeons.level(String(zid), 0) if open else Dungeons.condition(String(zid))
		if String(zid) == _dg_zone:
			b.text = "▶ " + b.text
		var z := String(zid)
		b.pressed.connect(func():
			_dg_zone = z
			_show_menu(menu))
		grid.add_child(b)
	_section("Difficulté")
	var dr := HBoxContainer.new()
	dr.add_theme_constant_override("separation", 6)
	_sub.add_child(dr)
	for i in Dungeons.DIFF_NAMES.size():
		var ok_pe := Siege.power_ok(_dg_zone, i) if siege else Dungeons.power_ok(_dg_zone, i)
		var b := MenuWidgets.glass_button(("🔒 " if not ok_pe else ("✔ " if i == _dg_diff else "")) + "%s (niv. %d)" % [Dungeons.DIFF_NAMES[i], Dungeons.level(_dg_zone, i)], 14, Vector2(0, 40))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.modulate = Color.WHITE if ok_pe else Color(1, 1, 1, 0.5)
		b.tooltip_text = Siege.power_text(_dg_zone, i) if siege else Dungeons.power_text(_dg_zone, i)
		var di := i
		b.pressed.connect(func():
			_dg_diff = di
			_show_menu(menu))
		dr.add_child(b)
	if siege:  # passe M6 : PE requise ou conseillée, estimation, récompenses, avertissement
		DifficultyPanel.add(_sub, Siege.power_required(_dg_zone, _dg_diff), Siege.advised(_dg_zone, _dg_diff), DifficultyPanel.siege_rewards(_dg_zone, _dg_diff))
	else:
		_pe_gauge(Dungeons.power_required(_dg_zone, _dg_diff))
	_pe_next(_dg_zone, siege)


## Bouton de lancement fermé par la PE : le détail est dans la jauge de la page (_pe_gauge).
const PE_LOW := "Puissance d'équipement insuffisante"


## Jauge de la PE exigée par la difficulté choisie (passe P5) : la tienne / la requise, verte quand elle suffit.
## Rien en Normal (aucune PE requise).
func _pe_gauge(need: int, label := "") -> void:
	if need <= 0:
		return
	var have := GearPower.hero_power()
	var ok := GearPower.meets(need)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	box.mouse_filter = Control.MOUSE_FILTER_STOP
	box.tooltip_text = "Puissance d'équipement (PE). Pour la monter : des pièces de plus haut niveau à l'Armurerie, puis +N, gemmes et enchantements à la Forge."
	_sub.add_child(box)
	var line := "PE requise : %s · la tienne : %s" % [GearPower.fmt(need), GearPower.fmt(have)]
	if label != "":
		line = "%s : PE requise %s · la tienne %s" % [label, GearPower.fmt(need), GearPower.fmt(have)]
	Hud._label(box, line, 14, UiTheme.BUFF if ok else UiTheme.MUTED)
	var bar := ProgressBar.new()
	bar.max_value = float(need)
	bar.value = float(mini(have, need))
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 8)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fill := StyleBoxFlat.new()
	fill.bg_color = UiTheme.BUFF if ok else UiTheme.GOLD
	fill.set_corner_radius_all(4)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(1, 1, 1, 0.1)
	bg.set_corner_radius_all(4)
	bar.add_theme_stylebox_override("fill", fill)
	bar.add_theme_stylebox_override("background", bg)
	box.add_child(bar)


## La difficulté choisie est ouverte : la jauge de la première plus dure qui ne l'est pas encore (passe P6), pour que la prochaine
## marche à gravir se voie sans cliquer dessus. [param siege] : la PE exigée est celle du Siège.
func _pe_next(zid: String, siege: bool) -> void:
	var ok_now := Siege.power_ok(zid, _dg_diff) if siege else Dungeons.power_ok(zid, _dg_diff)
	if not ok_now:
		return  # la jauge de la difficulté choisie dit déjà ce qui manque
	for i in range(_dg_diff + 1, Dungeons.DIFF_NAMES.size()):
		if not (Siege.power_ok(zid, i) if siege else Dungeons.power_ok(zid, i)):
			_pe_gauge(Siege.power_required(zid, i) if siege else Dungeons.power_required(zid, i), String(Dungeons.DIFF_NAMES[i]))
			return


## Le Siège : trois héros (toi et deux alliés IA), cinq vagues, le boss de la zone, puis le chacun pour soi.
func _menu_siege() -> void:
	_activity_head("siege")
	_dungeon_pickers("siege", true)
	_siege_boss_and_stars()
	_section("Alliés IA", "Ils deviennent tes rivaux quand le boss tombe. « Au hasard » sinon.")
	var ar := HBoxContainer.new()
	ar.add_theme_constant_override("separation", 6)
	_sub.add_child(ar)
	for k in Siege.ALLIES:
		var ob := OptionButton.new()
		ob.focus_mode = Control.FOCUS_NONE
		ob.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		ob.add_item("Au hasard")
		var ids: Array = [""]
		for cid in GameData.classes:
			if Progression.class_unlocked(cid):
				ob.add_item(String(GameData.class_data(cid).get("name_fr", cid)))
				ids.append(cid)
		ob.select(maxi(ids.find(_dg_allies[k]), 0))
		var kk := k
		ob.item_selected.connect(func(i): _dg_allies[kk] = ids[i])
		ar.add_child(ob)
	var best := int(Profile.records.get("siege_best_%d" % _dg_diff, 0))
	var rec := Hud._label(_sub, "Victoires : %d · meilleur siège (%s) : %s" % [Siege.wins(), Dungeons.DIFF_NAMES[_dg_diff], ("boss vaincu" if best > Siege.WAVES else "vague %d / %d" % [best, Siege.WAVES])], 13, UiTheme.MUTED)
	rec.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var open_now := Siege.playable(_dg_zone, _dg_diff)
	var go := MenuWidgets.gold_button("Lancer le Siège : %s" % Dungeons.name_of(_dg_zone), 22, Vector2(0, 58))
	go.disabled = not open_now
	var why := ""
	if not Unlocks.is_open("siege"):
		why = Unlocks.condition("siege")
	elif not Dungeons.is_open(_dg_zone):
		why = Dungeons.condition(_dg_zone)
	elif not Siege.power_ok(_dg_zone, _dg_diff):
		why = PE_LOW
	go.pressed.connect(_start_siege)
	_pin_go(go, why)


## Siège (passe M6) : le boss du jour et ses lieutenants (bibliothèque), puis les trois objectifs (étoiles gagnées).
func _siege_boss_and_stars() -> void:
	var bid := Siege.boss_for(_dg_zone)
	if bid != "":
		_section("Boss du jour", "Il change chaque jour. Ses lieutenants mènent les vagues d'élites.")
		var b := Hud._label(_sub, "%s · %s" % [BossLibrary.full_name(bid), ", ".join(BossLibrary.mechanic_names(bid))], 15, UiTheme.TEXT)
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var lts: Array = Siege.lieutenants_for(_dg_zone)
		if not lts.is_empty():
			var parts: Array = []
			for i in lts.size():
				parts.append("%s (vague %d)" % [BossLibrary.short_name(String(lts[i])), int(Siege.LIEUTENANT_WAVES[i])])
			Hud._label(_sub, "Lieutenants : " + ", ".join(parts), 14, UiTheme.MUTED).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var got := Siege.stars(_dg_zone, _dg_diff)
	_section("Objectifs  %s" % "".join(Siege.STARS.map(func(st): return "★" if String(st.id) in got else "☆")),
		"Chaque objectif réussi ajoute un quart de cristaux en plus.")
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	_sub.add_child(row)
	for st in Siege.STARS:
		var done := String(st.id) in got
		var p := PanelContainer.new()
		p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		p.add_theme_stylebox_override("panel", UiTheme.flat_box(Color(0.08, 0.06, 0.15, 0.85), UiTheme.GOLD if done else UiTheme.GOLD_DIM, 1, 8, false))
		p.mouse_filter = Control.MOUSE_FILTER_STOP
		p.tooltip_text = String(st.tip)
		row.add_child(p)
		var l := Hud._label(p, ("★ " if done else "☆ ") + String(st.name), 14, UiTheme.GOLD if done else UiTheme.TEXT)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


func _start_siege() -> void:
	if _launching or not Siege.playable(_dg_zone, _dg_diff):
		return
	_launching = true
	if backdrop:
		backdrop.release()
	var allies: Array = _dg_allies.filter(func(c): return String(c) != "")
	Dungeons.last_allies = allies
	Tower.start_siege(Profile.selected_class, _dg_zone, _dg_diff, allies)
	get_tree().change_scene_to_file.call_deferred(RUN_SCENE)


## Choix des alliés IA d'un donjon ou de la Ruée.
func _dungeon_allies_picker() -> void:
	_section("Alliés IA", "Les PV des monstres augmentent de 50 % par allié ; le butin reste le même.")
	var ar := HBoxContainer.new()
	ar.add_theme_constant_override("separation", 6)
	_sub.add_child(ar)
	for k in Dungeons.MAX_ALLIES:
		var ob := OptionButton.new()
		ob.focus_mode = Control.FOCUS_NONE
		ob.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		ob.add_item("Aucun allié")
		var ids: Array = ["" ]
		for cid in GameData.classes:
			if Progression.class_unlocked(cid):
				ob.add_item(String(GameData.class_data(cid).get("name_fr", cid)))
				ids.append(cid)
		ob.select(maxi(ids.find(_dg_allies[k]), 0))
		var kk := k
		ob.item_selected.connect(func(i): _dg_allies[kk] = ids[i])
		ar.add_child(ob)


## Ruée des boss : 8 boss de la bibliothèque à la suite (un tirage, passe M6), une difficulté, des modificateurs, des alliés IA.
func _menu_rush() -> void:
	_activity_head("rush")
	_section("Difficulté")
	var dr := HBoxContainer.new()
	dr.add_theme_constant_override("separation", 6)
	_sub.add_child(dr)
	for i in Dungeons.DIFF_NAMES.size():
		var best := int(Profile.records.get("rush_best_%d" % i, 0))
		var b := MenuWidgets.glass_button(("✔ " if i == _dg_diff else "") + "%s" % Dungeons.DIFF_NAMES[i], 14, Vector2(0, 40))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.tooltip_text = "Meilleur : %d / %d boss\nBoss de niveau %d à %d · titre « %s » si les %d tombent" % [best, Dungeons.rush_floors(), Dungeons.rush_level(1, i), Dungeons.rush_level(Dungeons.rush_floors(), i), Dungeons.RUSH_TITLES[i], Dungeons.rush_floors()]
		if not Dungeons.power_ok(Dungeons.RUSH, i):
			b.text = "🔒 " + b.text
			b.modulate = Color(1, 1, 1, 0.5)
			b.tooltip_text += "\n" + Dungeons.power_text(Dungeons.RUSH, i)
		var di := i
		b.pressed.connect(func():
			_dg_diff = di
			_show_menu("rush"))
		dr.add_child(b)
	DifficultyPanel.add(_sub, Dungeons.power_required(Dungeons.RUSH, _dg_diff), Rush.advised(_dg_diff), DifficultyPanel.rush_rewards(_dg_diff, Rush.chosen()))
	_pe_next(Dungeons.RUSH, false)
	_rush_lineup()
	_rush_mods()
	_dungeon_allies_picker()
	var go := MenuWidgets.gold_button("Lancer la Ruée", 22, Vector2(0, 58))
	go.disabled = not Unlocks.is_open("dungeons") or not Dungeons.power_ok(Dungeons.RUSH, _dg_diff)
	go.pressed.connect(_start_rush)
	_pin_go(go, Unlocks.condition("dungeons") if not Unlocks.is_open("dungeons") else (PE_LOW if go.disabled else ""))


## Les huit boss du tirage proposé (« ??? » à l'aveugle), sa graine et « Nouveau tirage ».
func _rush_lineup() -> void:
	var seed_n := Rush.current_seed()
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	_sub.add_child(head)
	var t := _section("Les %d boss · tirage n° %d" % [Dungeons.rush_floors(), seed_n],
		"Un boss par zone, de plus en plus forts. Le tirage reste le même tant que la Ruée n'est pas vaincue.")
	t.reparent(head)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var rr := MenuWidgets.glass_button("Nouveau tirage", 13, Vector2(0, 30))
	rr.tooltip_text = "D'autres boss, d'autres mécaniques."
	rr.pressed.connect(func():
		Rush.reroll()
		Profile.save_profile()
		_show_menu("rush"))
	head.add_child(rr)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 3)
	_sub.add_child(grid)
	var blind := "blind" in Rush.chosen()
	var ids := Rush.lineup_for(seed_n)
	for i in ids.size():
		var id := String(ids[i])
		var hidden := blind and i > 0
		var l := Hud._label(grid, "%d  %s" % [i + 1, "???" if hidden else BossLibrary.short_name(id)], 14, UiTheme.MUTED if hidden else UiTheme.TEXT)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.mouse_filter = Control.MOUSE_FILTER_STOP
		l.tooltip_text = "Caché jusqu'à son arrivée" if hidden else "%s\n%s" % [BossLibrary.full_name(id), ", ".join(BossLibrary.mechanic_names(id))]


## Modificateurs de la Ruée (passe M6) : plus durs, plus de cristaux (le total est dans les récompenses).
func _rush_mods() -> void:
	_section("Modificateurs", "Plus durs, plus de cristaux.")
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	_sub.add_child(row)
	var on := Rush.chosen()
	for k in Rush.MOD_ORDER:
		var m: Dictionary = Rush.MODS[k]
		var b := MenuWidgets.glass_button(("✔ " if k in on else "") + String(m.name), 14, Vector2(0, 38))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.tooltip_text = "%s\nCristaux : +%d %%" % [String(m.desc), roundi(100.0 * float(m.bonus))]
		var kk := String(k)
		b.pressed.connect(func():
			Rush.toggle(kk)
			Profile.save_profile()
			_show_menu("rush"))
		row.add_child(b)


func _start_rush() -> void:
	if _launching or not Unlocks.is_open("dungeons") or not Dungeons.power_ok(Dungeons.RUSH, _dg_diff):
		return
	_launching = true
	if backdrop:
		backdrop.release()
	var allies: Array = _dg_allies.filter(func(c): return String(c) != "")
	Dungeons.last_allies = allies
	Tower.start_dungeon(Profile.selected_class, Dungeons.RUSH, _dg_diff, allies)
	get_tree().change_scene_to_file.call_deferred(RUN_SCENE)


func _start_dungeon() -> void:
	if _launching or not Dungeons.is_open(_dg_zone) or not Dungeons.power_ok(_dg_zone, _dg_diff):
		return
	_launching = true
	if backdrop:
		backdrop.release()
	var allies: Array = _dg_allies.filter(func(c): return String(c) != "")
	Dungeons.last_allies = allies
	Tower.start_dungeon(Profile.selected_class, _dg_zone, _dg_diff, allies, DungeonPage.sel)
	get_tree().change_scene_to_file.call_deferred(RUN_SCENE)


## Activité à venir : ce qui est prévu.
func _menu_soon(id: String) -> void:
	_activity_head(id)
	_activity_desc(id)
	var l := Hud._label(_sub, "Bientôt disponible.", 16, Color(0.8, 0.78, 0.9))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


func _activity_desc(id: String) -> void:
	var d := Hud._label(_sub, String(Activities.get_def(id).get("desc", "")), 14, UiTheme.TEXT)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.custom_minimum_size = Vector2(420, 0)


func _menu_quit() -> void:
	_sub_title("Quitter")
	_row("Écran titre", "Changer de sauvegarde, nouvelle partie", "save", func():
		backdrop.release()
		get_tree().change_scene_to_file.call_deferred(TITLE_SCENE))
	_row("Quitter le jeu", "Ta progression est sauvegardée", "quit", func(): get_tree().quit())


func _open_class_menu() -> void:
	if _badge != null and is_inside_tree():
		HeroPages.class_menu(_badge, Profile.selected_class, _select_class)


func _select_class(id: String) -> void:
	if id == Profile.selected_class or not Progression.class_unlocked(id):
		return
	Profile.selected_class = id
	Profile.save_profile()
	_show_hero()
	_refresh_ui()


func _select_zone(id: String) -> void:
	if id == Profile.selected_zone or not Profile.zone_unlocked(id):
		return
	Profile.selected_zone = id
	Profile.save_profile()
	backdrop.change_zone(id, func():
		_snapshot = backdrop.snapshot()
		_refresh_ui())
	_refresh_ui()


## Badge, zone, récompense, pied de page, sous-menu courant.
func _refresh_ui() -> void:
	if _sub == null:
		return
	Unlocks.refresh()
	_refresh_locks()
	_refresh_compass()
	var cid := Profile.selected_class
	var cd := GameData.class_data(cid)
	_badge_icon.texture = UiTheme.texture(String(cd.get("icon", "")))
	_badge_name.text = String(cd.get("name_fr", cid)) + "  ▾"
	var w: Dictionary = Profile.equipped.get("weapon", {})
	_badge_sub.text = "Maîtrise niv. %d · %s" % [Profile.expertise_level(cid), GameData.weapon_type(Items.weapon_type_of(w)).get("name", "") if not w.is_empty() else "sans arme"]
	var zone := GameData.zone(Profile.selected_zone)
	_zone_name.text = String(zone.get("name", ""))
	_zone_sub.visible = false
	_zone_thumb.texture = _snapshot
	_badge_hero.text = HeroLook.full_name()
	_badge_hero.visible = _badge_hero.text != ""
	var prog := Profile.expertise_progress(cid)
	_reward_bar.max_value = maxf(prog.y, 1.0)
	_reward_bar.value = prog.x
	var lvl := Profile.expertise_level(cid)
	var next := Progression.rewards_at(cid, lvl + 1).filter(func(r): return r.kind != "talent")
	_reward_text.text = ("Maîtrise niv. %d : %s" % [lvl + 1, String(next[0].name) if not next.is_empty() else "+2 points de talent"]) if lvl < Profile.EXPERTISE_MAX else "Maîtrise maximale"
	_reward_nums.text = ("%s / %s" % [GearPower.fmt(roundi(prog.x)), GearPower.fmt(roundi(prog.y))]) if lvl < Profile.EXPERTISE_MAX else ""
	_dev_button.visible = Dev.enabled()
	var n_chests := Profile.reward_chests.size()
	_menu.chests.set_badge((("%d" % n_chests if n_chests > 0 else "") + (" ★" if Wheel.free_left() > 0 else "")) if Unlocks.is_open("chests") else "")
	var crystals := int(Profile.materials.get("crystal", 0))
	_footer.text = "%s %s · %s %s" % [GearPower.fmt(Profile.insignia), "insigne" if Profile.insignia < 2 else "insignes", GearPower.fmt(crystals), "cristal" if crystals < 2 else "cristaux"]
	var reg := Unlocks.is_open("collection")
	_gear_band.visible = reg
	_gear_sep.visible = reg
	if reg:
		var ec := ClassGear.equipped_count()
		_gear_band.text = "%d / %d classes équipées" % [ec.x, ec.y]
	_show_menu(_current)


## Écran plein écran du lobby ; à sa fermeture, le lobby suit (classe, arme, apparence).
func _screen(t: String, pages: Array) -> PageScreen:
	var s := PageScreen.new(t, 5)
	add_child(s)
	for p in pages:
		s.add_page(p[0], p[1])
	s.closed.connect(func():
		if _launching:
			return
		_show_hero()  # classe, arme ou apparence ont pu changer
		_refresh_ui())
	return s


func _open_hero(section := "") -> void:
	_hero.zone_texture = _snapshot
	_hero.open(section)


## Création de personnage (HeroCreator) ; à la fermeture, le héros du lobby et le badge suivent.
func _open_creator(first := false, then: Callable = Callable()) -> HeroCreator:
	return HeroCreator.open_on(self, first, func(ok: bool):
		_show_hero()
		_refresh_ui()
		if _hero.is_open():
			_hero.refresh()
		if then.is_valid():
			then.call(ok))
