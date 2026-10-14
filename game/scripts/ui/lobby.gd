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
## Arguments de test qui ouvrent un écran au démarrage (captures, tests).
const SCREEN_ARGS := ["--grimoire", "--talents", "--info", "--inventory", "--appearance", "--chests", "--cards", "--settings", "--armory"]

var backdrop: MapBackdrop
var _hero: HeroScreen
var _archive: PageScreen
var _workshop: PageScreen
var _chests: PageScreen
var _launching := false
var _open_screen := ""  # test : écran ouvert au démarrage (--inventory, --talents, --appearance, --archive=0...)
var _settings: SettingsMenu
var _epoch := 99  # époque choisie pour la Survie (la plus avancée ouverte par défaut)
var _zone_card: Control  # zone choisie et prochaine récompense (en bas à gauche)
var _menu := {}  # identifiant -> MenuWidgets.SideButton
var _current := ""  # sous-menu affiché ("" : aucun, le panneau est caché)
var _sub: VBoxContainer
var _sub_panel: PanelContainer
var _tower_diff := 1  # la Tour : difficulté et page d'étages affichées, étage choisi
var _tower_page := 0
var _tower_sel := 1
var _duel_opp := "warrior"  # mode Duel : adversaire et difficulté choisis
var _duel_diff := 2
var _badge_icon: TextureRect
var _badge_name: Label
var _badge_sub: Label
var _zone_thumb: TextureRect
var _zone_name: Label
var _zone_sub: Label
var _reward_bar: ProgressBar
var _reward_text: Label
var _footer: Label
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
				or arg.begins_with("--wear-aura") or arg == "--class-menu" or arg.begins_with("--wear-head=") or arg.begins_with("--wear-back=") or arg.begins_with("--dye-back=") or arg.begins_with("--archive-cat=") or arg.begins_with("--shot-out=") or arg.begins_with("--orbit=") or arg.begins_with("--tower-menu=") or arg == "--preset-editor" or arg == "--duel-menu" or arg == "--lobby-forge" or arg == "--duel-prep" or arg == "--rival-editor" or arg.begins_with("--profile-tab=") or arg.begins_with("--profile-picker=") or arg == "--profile-load" or arg.begins_with("--settings-tab=") or arg.begins_with("--menu=") or arg.begins_with("--chest-open="):
			continue
		if arg.begins_with("--lobby-shot="):
			shot = float(arg.trim_prefix("--lobby-shot="))
		elif arg.begins_with("--"):
			_start_run()
			return
	_build_scene()
	_build_ui()
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
			_chests.open(0)
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
			_workshop.open(0)
		"archive":
			_archive.open(0)
			for arg in OS.get_cmdline_user_args():
				if arg.begins_with("--archive-cat="):  # test : catégorie de l'archive
					_archive.page(0)._cat = arg.trim_prefix("--archive-cat=")
					_archive.page(0).refresh()
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


## Mode Duel : conditions d'inscription (build complet), adversaire, difficulté, inscription.
func _menu_duel() -> void:
	var cid := Profile.selected_class
	_activity_head("duel")
	# deux modes : à l'arme (rien que le preset de sorts, niveau au choix) ou équipé (tout compte)
	var modes := HBoxContainer.new()
	modes.add_theme_constant_override("separation", 8)
	_sub.add_child(modes)
	for m in [[true, "À l'arme"], [false, "Équipé"]]:
		var mb := MenuWidgets.glass_button(String(m[1]) + ("  ✔" if Duel.bare == bool(m[0]) else ""), 16, Vector2(0, 42))
		mb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		mb.tooltip_text = "Aucune pièce ni bonus de méta : l'arme de ta classe et ton preset de sorts, niveau au choix. Les deux héros sont à armes égales." if bool(m[0]) 			else "Tout ce que tu as réglé compte : équipement, maîtrise, certificats. Le niveau est celui de ton équipement."
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
	Hud._label(_sub, "À l'arme : seul ton preset de sorts compte, à armes égales avec l'adversaire." if Duel.bare 		else "Ton build doit être prêt avant de t'inscrire : tu te bats avec exactement ce que tu as réglé.", 13, UiTheme.MUTED).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	for r in Duel.requirements(cid):
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 8)
		_sub.add_child(h)
		var mark := Hud._label(h, "✔" if r.ok else "✘", 20, UiTheme.BUFF if r.ok else Color(1.0, 0.45, 0.4))
		mark.custom_minimum_size = Vector2(22, 0)
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 0)
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(v)
		Hud._label(v, String(r.label), 15, UiTheme.TEXT)
		Hud._label(v, String(r.hint), 12, UiTheme.MUTED)
		if not r.ok:
			var sec := String(r.section)
			var fix := MenuWidgets.glass_button("Régler", 14, Vector2(86, 36))
			fix.pressed.connect(func(): _open_hero(sec))
			h.add_child(fix)
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
	pl.tooltip_text = "IA scriptée : celle de l'entraînement, réglée par la difficulté. Cerveau : IA entraînée (apprentissage par renforcement), qui joue un vrai héros avec ses 12 sorts." if not brains.is_empty() else "Aucun cerveau d'IA entraîné sur ce PC (dossier data/cerveaux)."
	pl.item_selected.connect(func(i):
		Duel.pilot = "" if i == 0 else String(brains[i - 1][0])
		_show_menu("duel"))
	opp.add_child(pl)
	dd.disabled = Duel.pilot != ""
	Hud._label(_sub, "Niveau du duel : %d (%s) · victoires contre cette classe : %d" % [Duel.bare_level if Duel.bare else Duel.gear_level(), "choisi" if Duel.bare else "celui de ton équipement", Duel.wins_against(_duel_opp, _duel_diff)], 13, UiTheme.MUTED).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	_sub.add_child(row)
	var ed := MenuWidgets.glass_button("Éditeur d'adversaire", 14, Vector2(0, 40))
	ed.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ed.tooltip_text = "Sa classe, son équipement du catalogue d'Eden, son trophée, son apparence, ses certificats et ses sorts ; plusieurs adversaires enregistrés"
	ed.pressed.connect(func():
		Duel.difficulty = _duel_diff
		var b := Duel.rival_build if built else RivalBuilds.blank(_duel_opp, Duel.gear_level())
		ProfileEditor.open(self, b, func(nb):
			Duel.rival_build = nb
			_duel_opp = String(nb.get("class", _duel_opp))
			_show_menu("duel")))
	row.add_child(ed)
	if not built:
		var prep := MenuWidgets.glass_button("Préparation rapide (PV ×%.1f, dégâts ×%.1f)" % [Duel.hp_mult, Duel.atk_mult], 14, Vector2(0, 40))
		prep.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		prep.pressed.connect(func():
			Duel.rival_class = _duel_opp
			Duel.difficulty = _duel_diff
			DuelPrep.open(self, func(): _show_menu("duel")))
		row.add_child(prep)
	var go := MenuWidgets.gold_button("S'inscrire au duel", 22, Vector2(0, 58))
	go.disabled = not Duel.is_ready(cid)
	go.tooltip_text = "" if not go.disabled else "Règle d'abord les points marqués ✘"
	go.pressed.connect(_start_duel)
	_sub.add_child(go)


func _start_duel() -> void:
	if _launching or not Duel.is_ready(Profile.selected_class):
		return
	_launching = true
	if backdrop:
		backdrop.release()
	Duel.start(Profile.selected_class, _duel_opp, _duel_diff)
	get_tree().change_scene_to_file.call_deferred(RUN_SCENE)


## La Tour : choix de la difficulté (IA des duellistes, force des monstres, record à part).
func _menu_tower() -> void:
	_activity_head("tower")
	Hud._label(_sub, "Difficulté", 15, UiTheme.GOLD).add_theme_font_override("font", UiTheme.bold_font())
	for i in Tower.DIFF_NAMES.size():
		var rec := Tower.best(i)
		var di := i
		_row(String(Tower.DIFF_NAMES[i]), "%s\nÉtages battus : %d / %d" % [Tower.DIFF_DESC[i], rec, Tower.FLOORS], "upgrade", func():
			_tower_diff = di
			_tower_sel = mini(Tower.best(di) + 1, Tower.FLOORS)
			_tower_page = (_tower_sel - 1) / TowerPages.FLOORS_PER_PAGE
			_show_menu("tower_floors"), 92.0)


## Étages de la difficulté choisie, 10 par page : battus et suivant jouables, les autres
## verrouillés ; un clic choisit l'étage, « i » ouvre sa fiche (ennemi, sorts, équipement).
func _menu_tower_floors() -> void:
	var diff := _tower_diff
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
	var pl := Hud._label(nav, "Étages %d à %d  ·  battus : %d%s" % [_tower_page * TowerPages.FLOORS_PER_PAGE + 1, mini((_tower_page + 1) * TowerPages.FLOORS_PER_PAGE, Tower.FLOORS), Tower.best(diff),
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
		var f := _tower_page * TowerPages.FLOORS_PER_PAGE + i + 1
		if f > Tower.FLOORS:
			break
		var open := Tower.unlocked(f, diff)
		var line := TowerPages.floor_line(f, diff)
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 6)
		_sub.add_child(h)
		var icon := "upgrade" if f > Tower.best(diff) else "new"
		var r := MenuWidgets.RowButton.new(("🔒 " if not open else "") + String(line[0]), String(line[1]), icon, 56.0)
		r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		r.disabled = not open
		r.modulate = Color.WHITE if open else Color(1, 1, 1, 0.45)
		r.mark(f == _tower_sel)
		r.pressed.connect(func():
			_tower_sel = f
			_show_menu("tower_floors"))
		h.add_child(r)
		var info := MenuWidgets.glass_button("i", 18, Vector2(44, 56))
		info.tooltip_text = "Fiche de l'étage : ennemi, sorts, résistances, équipement"
		info.pressed.connect(func(): TowerPages.info_popup(_sub, Tower.spec(f, diff)))
		h.add_child(info)
	var go := MenuWidgets.gold_button("Commencer à l'étage %d" % _tower_sel, 22, Vector2(0, 58))
	go.disabled = not Tower.unlocked(_tower_sel, diff)
	go.pressed.connect(_start_tower.bind(diff, _tower_sel))
	_sub.add_child(go)
	var back := MenuWidgets.glass_button("Changer de difficulté", 15, Vector2(0, 36))
	back.pressed.connect(_show_menu.bind("tower"))
	_sub.add_child(back)


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
	Run.start_survival(Profile.selected_class, clampi(_epoch, 1, Epochs.unlocked()))
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
	var model := EdenModel.instantiate_hero(cls, Profile.outfit_of(Profile.selected_class), Profile.worn_parts(Profile.selected_class), Profile.dye_map(Profile.selected_class))
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
	var left := VBoxContainer.new()
	left.position = Vector2(44, 196)
	left.add_theme_constant_override("separation", 12)
	root.add_child(left)
	for m in MENU:
		var b := MenuWidgets.SideButton.new(m[1], m[2], 60.0)
		b.pressed.connect(_on_menu.bind(String(m[0])))
		left.add_child(b)
		_menu[m[0]] = b
	# sous-menu central
	var sp := PanelContainer.new()
	sp.add_theme_stylebox_override("panel", MenuWidgets.glass(14))
	sp.position = Vector2(372, 196)
	sp.custom_minimum_size = Vector2(450, 0)
	sp.visible = false
	root.add_child(sp)
	_sub_panel = sp
	_sub = VBoxContainer.new()
	_sub.add_theme_constant_override("separation", 10)
	sp.add_child(_sub)
	# badge de la classe (en haut à droite)
	var badge := PanelContainer.new()
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
	_badge_name = Hud._label(bv, "", 21, Color(1, 0.97, 0.9))
	_badge_name.add_theme_font_override("font", UiTheme.bold_font())
	_badge_sub = Hud._label(bv, "", 14, UiTheme.MUTED)
	# zone et prochaine récompense (en bas à gauche)
	var zc := PanelContainer.new()
	zc.add_theme_stylebox_override("panel", MenuWidgets.glass(14, UiTheme.GOLD, 0.88))
	zc.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	zc.offset_left = 44
	zc.offset_right = 760
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
	rv.custom_minimum_size = Vector2(250, 0)
	zh.add_child(rv)
	Hud._label(rv, "Prochaine récompense", 14, UiTheme.MUTED)
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
	info.offset_left = -560
	info.offset_right = -28
	info.offset_top = -86
	info.offset_bottom = -36
	var orbit_hint := Hud._label(root, "Glisser : tourner autour du héros · molette : zoom · clic droit glissé : hauteur · double-clic : vue de départ", 12, Color(1, 1, 1, 0.7))
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
	var ih := HBoxContainer.new()
	ih.add_theme_constant_override("separation", 10)
	ih.alignment = BoxContainer.ALIGNMENT_END
	info.add_child(ih)
	var user := _tex(ih, Vector2(22, 22))
	user.texture = MenuWidgets.icon("user")
	user.modulate = MenuWidgets.ICON_TINT
	_footer = Hud._label(ih, "", 14, UiTheme.TEXT)
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
	Settings.changed.connect(func(): _dev_button.visible = Dev.enabled())

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
	_archive = _screen("Carnet", [["Collection", ArchivePages.CollectionPage.new()]])
	_archive.set_title("Carnet", "Archive des trésors : chaque entrée donne un bonus permanent à tous les héros")
	_workshop = _screen("Atelier", [["Armurerie", GearShopPage.new()]])
	_workshop.set_title("Atelier", "Armurerie : les pièces découvertes en Survie s'achètent avec tes insignes")
	_chests = _screen("Coffres", [["Coffres", ChestsPage.new()]])
	_chests.set_title("Coffres", "Coffres de récompense rapportés des runs : apparences, forge, joaillier")
	_settings = SettingsMenu.new()
	add_child(_settings)
	_refresh_ui()


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


func _show_menu(id: String) -> void:
	_current = id
	if _sub_panel:
		_sub_panel.visible = id != ""
	if _zone_card:
		_zone_card.visible = id == ""  # sous-menu ouvert : le panneau de zone laisse la place
	for k in _menu:
		_menu[k].selected = k == ("" if id == "" else ("quit" if id == "quit" else "play"))
	for c in _sub.get_children():
		c.queue_free()
	if _sub_panel:
		# activités en grille : panneau large ; pages et autres sous-menus : étroit
		_sub_panel.custom_minimum_size.x = 728 if id == "play" else 470
		_sub_panel.size = Vector2.ZERO
	match id:
		"play":
			_menu_play()
		"survival", "zones":
			_menu_survival()
		"training":
			_menu_training()
		"dungeon", "arena2", "arena3", "battlefield":
			_menu_soon(id)
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
	for gr in Activities.GROUPS:
		var head := Hud._label(_sub, String(gr[1]), 15, UiTheme.GOLD)
		head.add_theme_font_override("font", UiTheme.bold_font())
		var grid := GridContainer.new()
		grid.columns = 2
		grid.add_theme_constant_override("h_separation", 10)
		grid.add_theme_constant_override("v_separation", 10)
		_sub.add_child(grid)
		for a in Activities.LIST.filter(func(x): return x.group == gr[0] or (gr[0] == "pve" and x.group == "")):
			grid.add_child(_activity_card(a))  # l'entraînement complète la grille JcE


func _activity_card(a: Dictionary, size := Vector2(345, 112)) -> Button:
	var c := Activities.card(a, size)
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if Activities.locked(a):
		c.tooltip_text = Unlocks.lock_text(String(a.unlock))  # grisée : la condition dit comment l'ouvrir
		c.pressed.connect(func(): c.tooltip_text = Unlocks.lock_text(String(a.unlock)))
	else:
		c.pressed.connect(_show_menu.bind(String(a.id)))
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


## Survie : l'époque (3 maps, paliers et raretés des coffres), puis Lancer.
func _menu_survival() -> void:
	_activity_head("survival")
	Hud._label(_sub, "Époque", 15, UiTheme.GOLD).add_theme_font_override("font", UiTheme.bold_font())
	_epoch = clampi(_epoch, 1, Epochs.unlocked())
	for i in range(1, Epochs.count() + 1):
		var e := Epochs.get_def(i)
		var open := i <= Epochs.unlocked()
		var zones: Array = (e.zones as Array).map(func(z): return String(GameData.zone(String(z)).get("name", z)))
		var tiers: Array = range(1, 4).map(func(st): return str(int(Epochs.map_def(i, st).armor)))
		var sub := ("%s
Paliers %s · %s" % [" → ".join(zones), ", ".join(tiers), Epochs.rarity_name(Epochs.map_def(i, 3))]) if open 			else "Verrouillée : termine l'%s" % Epochs.get_def(i - 1).name
		var ei := i
		var r := _row(String(e.name), sub, "pin", func():
			_epoch = ei
			_select_zone(Epochs.zone(ei, 1))
			_show_menu("survival"), 62.0)
		r.disabled = not open
		if not open:
			r.modulate = Color(1, 1, 1, 0.5)
		r.mark(i == _epoch)
	var hint := Hud._label(_sub, "Tu pars sans équipement : arme au choix au départ, puis coffres d'emplacement sur chaque carte.", 13, UiTheme.MUTED)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.custom_minimum_size = Vector2(420, 0)
	var go := MenuWidgets.gold_button("Lancer la run", 22, Vector2(0, 56))
	go.pressed.connect(_launch)
	_sub.add_child(go)


## Zone d'entraînement : description, puis Entrer.
func _menu_training() -> void:
	_activity_head("training")
	_activity_desc("training")
	var go := MenuWidgets.gold_button("Entrer", 22, Vector2(0, 56))
	go.pressed.connect(_start_training)
	_sub.add_child(go)


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
	var cid := Profile.selected_class
	var cd := GameData.class_data(cid)
	_badge_icon.texture = UiTheme.texture(String(cd.get("icon", "")))
	_badge_name.text = String(cd.get("name_fr", cid)) + "  ▾"
	var w: Dictionary = Profile.equipped.get("weapon", {})
	_badge_sub.text = "Maîtrise niv. %d · %s" % [Profile.expertise_level(cid), GameData.weapon_type(Items.weapon_type_of(w)).get("name", "") if not w.is_empty() else "sans arme"]
	var zone := GameData.zone(Profile.selected_zone)
	_zone_name.text = String(zone.get("name", ""))
	_zone_sub.text = "Niv. %d+ · zone %d / %d · %d débloquée(s)" % [1 + int(zone.get("level_bonus", 0)), GameData.zone_index(Profile.selected_zone) + 1, GameData.zones.size(), Profile.unlocked_zones]
	_zone_thumb.texture = _snapshot
	var prog := Profile.expertise_progress(cid)
	_reward_bar.max_value = maxf(prog.y, 1.0)
	_reward_bar.value = prog.x
	var lvl := Profile.expertise_level(cid)
	var next := Progression.rewards_at(cid, lvl + 1).filter(func(r): return r.kind != "talent")
	_reward_text.text = ("Maîtrise %s niv. %d : %s" % [cd.get("name_fr", cid), lvl + 1, String(next[0].name) if not next.is_empty() else "+2 points de talent"]) if lvl < Profile.EXPERTISE_MAX else "Maîtrise maximale"
	_dev_button.visible = Dev.enabled()
	_menu.chests._label.text = "Coffres" + ("  (%d)" % Profile.reward_chests.size() if not Profile.reward_chests.is_empty() else "")
	_footer.text = "%d insignes · %d cristaux · %d coffre(s) à ouvrir
Sauvegarde %d · coffre commun %d objet(s) · %d run(s), %d victoire(s)" % [
		Profile.insignia, int(Profile.materials.get("crystal", 0)), Profile.reward_chests.size(), Profile.slot, Profile.vault.size(), Profile.runs_done, Profile.runs_won]
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
