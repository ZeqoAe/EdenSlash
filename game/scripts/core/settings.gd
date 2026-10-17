extends Node
## Paramètres du joueur, sauvegardés dans user://settings.cfg : affichage, son,
## touches, mode de jeu (déplacement, visée), combat automatique, caméra, interface.
## Les lancements de test ont leur propre fichier (comme le profil).

signal changed

const SAVE_PATH := "user://settings.cfg"
const TEST_SAVE_PATH := "user://settings_test.cfg"

## Actions modifiables dans le menu Touches, dans l'ordre d'affichage.
const ACTIONS := [
	["move_forward", "Avancer"], ["move_back", "Reculer"], ["move_left", "Aller à gauche"],
	["move_right", "Aller à droite"], ["attack", "Attaquer (clic principal)"],
	["move_order", "Déplacer / attaquer (clic droit)"], ["jump", "Sauter"], ["dodge", "Esquive"],
	["skill_1", "Compétence 1"], ["skill_2", "Compétence 2"], ["skill_3", "Compétence 3"],
	["skill_4", "Compétence 4"], ["interact", "Interagir"], ["map", "Carte"],
	["objectives", "Afficher les objectifs"], ["pause", "Menu / pause"],
	["journal", "Journal des quêtes"],
	["camera_rotate", "Tourner la caméra (maintenu)"], ["unstuck", "Se débloquer"], ["help", "Aide"],
	["feedback", "Signaler un problème"], ["extract", "S'extraire (10 s)"], ["quick_equip", "Équiper l'objet trouvé"],
	["potion_1", "Potion de soin"], ["potion_2", "Potion d'effet"], ["swap_weapon", "Changer d'arme"],
	["ping", "Poser un repère (Battle royale)"],
]
## Paires d'actions qui peuvent partager une touche (jamais utilisées en même temps).
const SHARED_OK := [["move_order", "camera_rotate"]]

## Touches par défaut (touches physiques : ZQSD sur AZERTY = WASD sur QWERTY).
## {"k": touche physique} ou {"m": bouton de souris}.
const DEFAULT_BINDS := {
	"move_forward": [{"k": KEY_W}, {"k": KEY_UP}],
	"move_back": [{"k": KEY_S}, {"k": KEY_DOWN}],
	"move_left": [{"k": KEY_A}, {"k": KEY_LEFT}],
	"move_right": [{"k": KEY_D}, {"k": KEY_RIGHT}],
	"attack": [{"m": MOUSE_BUTTON_LEFT}, {"k": KEY_J}],
	"move_order": [{"m": MOUSE_BUTTON_RIGHT}],
	"jump": [{"k": KEY_SPACE}],
	"dodge": [{"k": KEY_SHIFT}],
	# compétences : 1-4, ou A E R T sur AZERTY (Q E R T sur QWERTY)
	"skill_1": [{"k": KEY_1}, {"k": KEY_Q}],
	"skill_2": [{"k": KEY_2}, {"k": KEY_E}],
	"skill_3": [{"k": KEY_3}, {"k": KEY_R}],
	"skill_4": [{"k": KEY_4}, {"k": KEY_T}],
	"interact": [{"k": KEY_F}],
	"map": [{"k": KEY_M}],
	"objectives": [{"k": KEY_TAB}],
	"journal": [{"k": KEY_L}],  # Journal des quêtes (lot HUB-1) : partout, menu, partie, bilan (J est déjà une attaque)
	"pause": [{"k": KEY_ESCAPE}],
	"camera_rotate": [{"m": MOUSE_BUTTON_RIGHT}],
	"unstuck": [{"k": KEY_F4}],
	"help": [{"k": KEY_F1}],
	"feedback": [{"k": KEY_F9}],
	"extract": [{"k": KEY_X}],
	"quick_equip": [{"k": KEY_G}],
	"potion_1": [{"k": KEY_C}],
	"potion_2": [{"k": KEY_V}],
	"swap_weapon": [{"k": KEY_Z}],  # (W sur AZERTY, Z sur QWERTY : sous la main gauche, libre)
	"ping": [{"m": MOUSE_BUTTON_MIDDLE}],  # repère personnel du Battle royale (lot BR-I1)
}
## Manette (disposition fixe, non modifiable ; voir Gamepad) : {"b": bouton} ou
## {"a": axe, "v": sens}, et le libellé affiché quand on joue à la manette.
const PAD_BINDS := {
	"move_forward": [{"a": JOY_AXIS_LEFT_Y, "v": -1.0}], "move_back": [{"a": JOY_AXIS_LEFT_Y, "v": 1.0}],
	"move_left": [{"a": JOY_AXIS_LEFT_X, "v": -1.0}], "move_right": [{"a": JOY_AXIS_LEFT_X, "v": 1.0}],
	"attack": [{"b": JOY_BUTTON_X}], "dodge": [{"b": JOY_BUTTON_B}], "jump": [{"b": JOY_BUTTON_Y}],
	"interact": [{"b": JOY_BUTTON_A}],
	"skill_1": [{"b": JOY_BUTTON_RIGHT_SHOULDER}], "skill_2": [{"a": JOY_AXIS_TRIGGER_RIGHT, "v": 1.0}],
	"skill_3": [{"b": JOY_BUTTON_LEFT_SHOULDER}], "skill_4": [{"a": JOY_AXIS_TRIGGER_LEFT, "v": 1.0}],
	"pause": [{"b": JOY_BUTTON_START}], "map": [{"b": JOY_BUTTON_BACK}],
	"objectives": [{"b": JOY_BUTTON_DPAD_LEFT}], "quick_equip": [{"b": JOY_BUTTON_DPAD_RIGHT}],
	"potion_1": [{"b": JOY_BUTTON_DPAD_UP}], "potion_2": [{"b": JOY_BUTTON_DPAD_DOWN}],
	"swap_weapon": [{"b": JOY_BUTTON_RIGHT_STICK}],
	"ping": [{"b": JOY_BUTTON_LEFT_STICK}],
}
## Actions dont la manette est réassignable (le déplacement reste au stick gauche).
const PAD_ACTIONS := ["attack", "dodge", "jump", "interact", "skill_1", "skill_2", "skill_3", "skill_4",
	"pause", "map", "objectives", "quick_equip", "potion_1", "potion_2", "extract", "help", "unstuck", "feedback", "swap_weapon", "ping"]
## Noms des boutons selon la disposition (Godot : A = bouton du bas, B = droite, X = gauche, Y = haut).
const PAD_NAMES := {
	"xbox": {JOY_BUTTON_A: "A", JOY_BUTTON_B: "B", JOY_BUTTON_X: "X", JOY_BUTTON_Y: "Y", JOY_BUTTON_LEFT_SHOULDER: "LB",
		JOY_BUTTON_RIGHT_SHOULDER: "RB", JOY_BUTTON_START: "Menu", JOY_BUTTON_BACK: "Vue", JOY_BUTTON_GUIDE: "Xbox",
		JOY_BUTTON_LEFT_STICK: "L3", JOY_BUTTON_RIGHT_STICK: "R3", JOY_BUTTON_DPAD_UP: "↑ (croix)", JOY_BUTTON_DPAD_DOWN: "↓ (croix)",
		JOY_BUTTON_DPAD_LEFT: "← (croix)", JOY_BUTTON_DPAD_RIGHT: "→ (croix)"},
	"ps": {JOY_BUTTON_A: "Croix", JOY_BUTTON_B: "Rond", JOY_BUTTON_X: "Carré", JOY_BUTTON_Y: "Triangle", JOY_BUTTON_LEFT_SHOULDER: "L1",
		JOY_BUTTON_RIGHT_SHOULDER: "R1", JOY_BUTTON_START: "Options", JOY_BUTTON_BACK: "Share", JOY_BUTTON_GUIDE: "PS",
		JOY_BUTTON_LEFT_STICK: "L3", JOY_BUTTON_RIGHT_STICK: "R3", JOY_BUTTON_DPAD_UP: "↑ (croix)", JOY_BUTTON_DPAD_DOWN: "↓ (croix)",
		JOY_BUTTON_DPAD_LEFT: "← (croix)", JOY_BUTTON_DPAD_RIGHT: "→ (croix)"},
}
const PAD_TRIGGERS := {"xbox": {JOY_AXIS_TRIGGER_LEFT: "LT", JOY_AXIS_TRIGGER_RIGHT: "RT"}, "ps": {JOY_AXIS_TRIGGER_LEFT: "L2", JOY_AXIS_TRIGGER_RIGHT: "R2"}}
const PAD_LABELS := {
	"attack": "Carré", "dodge": "Rond", "jump": "Triangle", "interact": "Croix",
	"skill_1": "R1", "skill_2": "R2", "skill_3": "L1", "skill_4": "L2",
	"pause": "Options", "map": "Share", "objectives": "← (croix)", "quick_equip": "→ (croix)", "potion_1": "↑ (croix)", "potion_2": "↓ (croix)",
	"swap_weapon": "R3", "ping": "L3",
	"move_forward": "Stick gauche", "move_back": "Stick gauche", "move_left": "Stick gauche", "move_right": "Stick gauche",
}

## Touches de test, non modifiables.
const DEBUG_BINDS := {
	"debug_level": KEY_F5, "debug_gateway": KEY_F6, "debug_dungeon": KEY_F7,
	"debug_overlay": KEY_F2, "debug_rage": KEY_F8,
}

const DEFAULTS := {
	"display": {"window_mode": "windowed", "resolution": "1600x900", "vsync": true, "max_fps": 0,
		"msaa": 2, "ui_scale": 1.0, "quality": "high",
		"hero_detail": true},  # « Héros détaillé » (lot CHR-2, ClassPremium) : classes maison seulement
	"audio": {"master": 0.8, "sfx": 1.0, "music": 0.6},
	# move_mode : keyboard (ZQSD), click (clic gauche), rts (clic droit)
	# aim_mode : smart (cible, sinon curseur, sinon monstre proche), cursor (le héros suit
	#            le curseur), action (héros de dos, la caméra tourne vers le curseur),
	#            nearest (toujours le monstre le plus proche)
	# attack_mode : manual (clic), auto (frappe seul les monstres à portée)
	# auto_skills : compétences lancées seules dès qu'elles sont prêtes et qu'un monstre est à portée
	# auto_target : any (n'importe quel monstre à portée), locked (seulement la cible verrouillée)
	"game": {"move_mode": "keyboard", "aim_mode": "smart", "attack_mode": "manual",
		"auto_skills": [false, false, false, false], "auto_target": "any", "auto_combo": false, "auto_move": false, "auto_cards": false,
		"key_memory": true, "hold_chain": true},
	"camera": {"rotate_speed": 1.0, "invert_y": false, "distance": 15.0, "shake": 1.0, "action_turn": 1.0},
	# L'Échiquier (lot ACX-2) : préparation sans minuteur, noms au-dessus des héros en combat, bilan de manche à chaque fois
	"autochess": {"no_timer": false, "names": false, "recap_always": false, "planned": [], "guide_done": false},  # planned, guide_done : lot ACX-3
	# Mode amis (lot NET-A) : « Jouer ensemble » à l'écran titre, port d'hôte, dernière adresse rejointe, héros de l'arène
	"net": {"friends": false, "port": 24680, "join": "", "class": ""},
	# dev_mode : écran de test (F10), réservé aux tests
	"interface": {"damage_numbers": "all", "hit_stop": true, "show_fps": false, "move_marker": true, "attack_zone": false, "dev_mode": false,
		"tower_unlock_all": true, "perfect_hint": true, "pad_labels": "auto", "compass": true,
		"boss_timeline": true,  # frise « À venir » des combats de boss (lot DNG-2)
		"tele_palette": "auto", "tele_intensity": 1.0,  # couleur et intensité des zones de danger (lot DNG-3, Telegraph.PALETTES)
		# HUD en partie (lot HUB-1, P0-9) : taille et opacité, à part de la taille de l'interface (display.ui_scale)
		"hud_scale": 1.0, "hud_opacity": 1.0,
		"hud_profile": "standard",  # profil du HUD : standard, compact, minimal (lot HUD-2, HudV2.PROFILES)
		"fx_spells": "all", "fx_auras": "all", "fx_particles": "all", "fx_intensity": 1.0,
		# curseur de souris (CursorSets) et réticule de visée en jeu (AimReticle) ; valeur inconnue = défaut
		"cursor_set": "classic", "reticle": "dot", "reticle_size": 1.0, "reticle_color": "gold",
		# ressenti du clic (UiFeel) ; ui_skin : peau des panneaux (« sticker » ; « night » = option technique, sans ligne)
		"ui_reduce_motion": false, "ui_vibration": true, "ui_fx": 1.0, "ui_skin": "sticker",
		# accessibilité (lot BR-I3) : « Voir les sons », couleurs adaptées aux daltoniens, vibration des coups en combat
		"sound_cues": false, "colorblind": false, "combat_vibration": true,
		# accessibilité et confort du Survivant (lot SVX-4, BM-SURV SV-A1, SV-Q3) : taille des nombres de dégâts (0,8 / 1 / 1,3),
		# effets et secousses réduits, sous-titres des alertes sonores, horde contrastée, vitesse du jeu (hors records), choix
		# de cartes regroupés (on les ouvre quand on veut)
		"number_size": 1.0, "calm_fx": false, "alert_captions": false, "horde_contrast": false, "sv_speed": 1.0,
		"sv_group_choices": false},
}

## Modes de jeu prêts à l'emploi (réglages du menu Contrôles).
const PRESETS := {
	"classic": {"name": "Classique", "desc": "ZQSD pour se déplacer, clic gauche pour attaquer (sur un monstre : auto-attaque), compétences au clavier.",
		"game": {"move_mode": "keyboard", "aim_mode": "smart", "attack_mode": "manual"}},
	"twin_stick": {"name": "Visée au curseur", "desc": "ZQSD pour se déplacer, le héros regarde toujours le curseur : attaques et compétences partent vers la souris.",
		"game": {"move_mode": "keyboard", "aim_mode": "cursor", "attack_mode": "manual"}},
	"arpg": {"name": "Souris (ARPG)", "desc": "Clic gauche (maintenu) pour se déplacer vers le curseur, clic sur un monstre pour l'attaquer, compétences au clavier vers la souris.",
		"game": {"move_mode": "click", "aim_mode": "cursor", "attack_mode": "auto"}},
	"rts": {"name": "Clic droit (stratégie)", "desc": "Clic droit pour se déplacer ou attaquer un monstre, compétences au clavier vers la souris, caméra au clic molette.",
		"game": {"move_mode": "rts", "aim_mode": "cursor", "attack_mode": "auto"}},
	"action": {"name": "Action (vue de dos)", "desc": "ZQSD pour se déplacer, le héros regarde le curseur et la caméra tourne derrière lui quand le curseur s'écarte du centre. Molette : du plan rapproché à la vue large.",
		"game": {"move_mode": "keyboard", "aim_mode": "action", "attack_mode": "manual"}},
	"relax": {"name": "Détente", "desc": "ZQSD pour se déplacer : attaque de base, compétences et enchaînements se lancent seuls sur les monstres à portée (sans annulation parfaite).",
		"game": {"move_mode": "keyboard", "aim_mode": "nearest", "attack_mode": "auto", "auto_skills": [true, true, true, true], "auto_combo": true}},
	"bot": {"name": "Pilote automatique", "desc": "Le héros se déplace, frappe et enchaîne ses sorts tout seul (ton préréglage de sorts), sans annulation parfaite ; bouger toi-même reprend la main.",
		"game": {"move_mode": "keyboard", "aim_mode": "nearest", "attack_mode": "auto", "auto_skills": [true, true, true, true],
			"auto_combo": true, "auto_move": true, "auto_cards": true}},
}

const RESOLUTIONS := ["1280x720", "1366x768", "1600x900", "1920x1080", "2560x1440", "3840x2160"]

var data: Dictionary = {}
var binds: Dictionary = {}  # action -> [{"k": ...} | {"m": ...}]
var pad_binds: Dictionary = {}  # action -> [{"b": bouton} | {"a": axe, "v": ±1}] (manette)
var save_path := SAVE_PATH


func _ready() -> void:
	if not OS.get_cmdline_user_args().is_empty() or " ".join(OS.get_cmdline_args()).contains("res://tests/"):
		save_path = TEST_SAVE_PATH
	save_path = NetLaunch.user_path(save_path)  # (lot NET-A) --profil=<nom> : réglages de cette instance
	UiTheme.apply_global()
	if DisplayServer.get_name() != "headless":  # réticule de visée en jeu : un calque au-dessus de tout
		var layer := CanvasLayer.new()
		layer.layer = 100
		layer.process_mode = Node.PROCESS_MODE_ALWAYS
		layer.add_child(AimReticle.new())
		add_child(layer)
	reset_all(false)
	load_settings()
	apply_bindings()
	apply_all()
	if "--fullscreen" in OS.get_cmdline_args():
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)  # pour jouer en streaming (Steam Link)


# --- valeurs -------------------------------------------------------------------------
func get_v(section: String, key: String) -> Variant:
	return data.get(section, {}).get(key, DEFAULTS.get(section, {}).get(key))


func set_v(section: String, key: String, value: Variant) -> void:
	if not data.has(section):
		data[section] = {}
	data[section][key] = value
	_apply_section(section)
	save_settings()
	changed.emit()


## Lisibilité / performances : part d'opacité (0 à 1) des effets de sorts ([param kind] « fx_spells »)
## ou des auras de skin (« fx_auras ») selon leur propriétaire : [param mine] = 1 pour mes effets,
## 0 pour ceux des autres héros, -1 pour un aperçu (jamais masqué). Valeurs : all, dim_others,
## hide_others, hide_mine, hide_all.
func fx_factor(kind: String, mine: int) -> float:
	if mine < 0:
		return 1.0
	match String(get_v("interface", kind)):
		"dim_others":
			return 1.0 if mine == 1 else 0.35
		"hide_others":
			return 1.0 if mine == 1 else 0.0
		"hide_mine":
			return 0.0 if mine == 1 else 1.0
		"hide_all":
			return 0.0
	return 1.0


## Étincelles, poussière et éclairs d'impact : « all », « reduced » (moitié) ou « off ».
func fx_particles() -> String:
	var v := String(get_v("interface", "fx_particles"))
	if v == "all" and get_v("interface", "calm_fx") == true:
		return "reduced"  # (lot SVX-4, SV-A1) « Réduire effets et secousses » : étincelles réduites de moitié
	return v


func apply_preset(id: String) -> void:
	var p: Dictionary = PRESETS.get(id, {})
	var g: Dictionary = p.get("game", {})
	for k in g:
		data.game[k] = g[k].duplicate() if g[k] is Array else g[k]
	if not g.has("auto_skills"):
		data.game.auto_skills = [false, false, false, false]
	for k in ["auto_combo", "auto_move", "auto_cards"]:
		if not g.has(k):
			data.game[k] = false
	save_settings()
	changed.emit()


## Mode de jeu correspondant aux réglages actuels ("" si personnalisé).
func current_preset() -> String:
	for id in PRESETS:
		var g: Dictionary = PRESETS[id].game
		var ok := true
		for k in ["move_mode", "aim_mode", "attack_mode"]:
			if data.game[k] != g[k]:
				ok = false
		if ok and data.game.auto_skills != g.get("auto_skills", [false, false, false, false]):
			ok = false
		if ok and (bool(get_v("game", "auto_combo")) != bool(g.get("auto_combo", false)) or bool(get_v("game", "auto_move")) != bool(g.get("auto_move", false))):
			ok = false
		if ok:
			return id
	return ""


func move_mode() -> String:
	return String(get_v("game", "move_mode"))


func aim_mode() -> String:
	return String(get_v("game", "aim_mode"))


## Visée au curseur (le héros regarde toujours la souris) : modes « curseur » et « action ».
func cursor_aim() -> bool:
	return aim_mode() in ["cursor", "action"]


func auto_attack() -> bool:
	return get_v("game", "attack_mode") == "auto"


func auto_skill(slot: int) -> bool:
	var a: Array = get_v("game", "auto_skills")
	return (slot < a.size() and bool(a[slot])) or auto_combo()


## Sorts et enchaînements automatiques : les 4 sorts du preset et leurs enchaînements, dès l'ouverture
## de la barre (Paramètres > Combat). Plus d'annulations parfaites : c'est le geste du joueur.
func auto_combo() -> bool:
	return bool(get_v("game", "auto_combo"))


## Aide au combat : quatre niveaux qui rangent les réglages existants (le niveau est lu dans les
## réglages, "custom" si on les a mélangés à la main). Manuel : tout à la main ; Assisté : mémoire des
## touches, maintien et anneau d'annulation (par défaut) ; Détente : sorts et enchaînements
## automatiques, attaque de base automatique, sans annulation parfaite ; Bot : en plus, déplacement
## et choix des cartes. L'annulation parfaite reste un geste du joueur.
const ASSIST := {
	"manual": {"name": "Manuel", "tag": "", "color": Color(0.8, 0.8, 0.85),
		"desc": "Tout à la main : pas de mémoire des touches, sorts, enchaînements et annulations parfaites au bon timing."},
	"assisted": {"name": "Assisté", "tag": "ASSISTÉ", "color": Color(0.45, 0.9, 0.55),
		"desc": "Mémoire des touches (3 appuis gardés), tenir la touche enchaîne, anneau d'annonce de l'annulation parfaite. Les sorts, le déplacement et l'esquive restent à toi."},
	"relax": {"name": "Détente", "tag": "SORTS AUTO", "color": Color(0.45, 0.7, 1.0),
		"desc": "Attaque de base, sorts et enchaînements partent seuls sur les monstres à portée. Tu te déplaces et tu esquives ; l'annulation parfaite, plus puissante, reste à la main."},
	"bot": {"name": "Pilote auto", "tag": "PILOTE AUTO", "color": Color(0.75, 0.55, 1.0),
		"desc": "Comme Détente, et le héros se déplace et choisit seul ses cartes et son équipement. Bouger toi-même reprend la main."},
}


func assist_level() -> String:
	var any_skill := false
	for i in 4:
		any_skill = any_skill or bool((get_v("game", "auto_skills") as Array)[i])
	var mem := key_memory()
	var all_aids := mem and hold_chain() and perfect_hint()
	var no_aids := not mem and not hold_chain() and not perfect_hint()
	if auto_move() and auto_combo() and auto_attack():
		return "bot"
	if auto_combo() and not auto_move() and auto_attack():
		return "relax"
	if not auto_move() and not auto_combo() and not any_skill and not auto_cards() and not auto_attack():
		if all_aids:
			return "assisted"
		if no_aids:
			return "manual"
	return "custom"


func set_assist(level: String) -> void:
	if not ASSIST.has(level):
		return
	var g: Dictionary = data.game
	g["auto_skills"] = [false, false, false, false]
	g["auto_combo"] = level in ["relax", "bot"]
	g["auto_move"] = level == "bot"
	g["auto_cards"] = level == "bot"
	g["attack_mode"] = "auto" if level in ["relax", "bot"] else "manual"
	g["key_memory"] = level != "manual"
	g["hold_chain"] = level != "manual"
	data.interface["perfect_hint"] = level != "manual"
	if level in ["relax", "bot"]:
		g["aim_mode"] = "nearest"
	save_settings()
	changed.emit()


## Mémoire des touches : jusqu'à 3 appuis de sorts gardés et joués dans l'ordre (plus de « Trop tôt »).
func key_memory() -> bool:
	return bool(get_v("game", "key_memory"))


## Tenir la touche d'une case enchaîne toute la chaîne (avec la mémoire des touches).
func hold_chain() -> bool:
	return bool(get_v("game", "hold_chain"))


## Anneau bleu bref à chaque impact de sort : c'est le moment de l'annulation parfaite.
func perfect_hint() -> bool:
	return bool(get_v("interface", "perfect_hint"))


## La boussole d'objectif du menu principal (Compass) : le conseil du moment.
func show_compass() -> bool:
	return bool(get_v("interface", "compass"))


## Choix des cartes automatique : nouveau sort tant qu'une case est libre, sinon la plus rare.
func auto_cards() -> bool:
	return bool(get_v("game", "auto_cards"))


## Déplacement automatique : vers les monstres, puis vers l'objectif (Paramètres > Combat).
func auto_move() -> bool:
	return bool(get_v("game", "auto_move"))


func set_auto_skill(slot: int, on: bool) -> void:
	var a: Array = (get_v("game", "auto_skills") as Array).duplicate()
	a[slot] = on
	set_v("game", "auto_skills", a)


## Action souris qui sert à se déplacer selon le mode ("" : clavier).
func move_click_action() -> String:
	return {"click": "attack", "rts": "move_order"}.get(move_mode(), "")


## Le clic d'attaque frappe (sinon il sert à se déplacer, mode souris).
func attack_button_attacks() -> bool:
	return move_mode() != "click"


## Rotation de la caméra : bouton de l'action, ou clic molette s'il sert déjà à se déplacer.
func camera_rotate_mask() -> int:
	var mask := 0
	var move_buttons := _mouse_buttons(move_click_action()) if move_click_action() != "" else []
	for b in _mouse_buttons("camera_rotate"):
		if not b in move_buttons:
			mask |= 1 << (b - 1)
	return mask if mask != 0 else MOUSE_BUTTON_MASK_MIDDLE


func _mouse_buttons(action: String) -> Array:
	var out: Array = []
	for e in binds.get(action, []):
		if e.has("m"):
			out.append(int(e.m))
	return out


func reset_section(section: String) -> void:
	data[section] = DEFAULTS[section].duplicate(true)
	_apply_section(section)
	save_settings()
	changed.emit()


func reset_all(save := true) -> void:
	data = DEFAULTS.duplicate(true)
	binds = DEFAULT_BINDS.duplicate(true)
	pad_binds = PAD_BINDS.duplicate(true)
	if save:
		apply_bindings()
		apply_all()
		save_settings()
		changed.emit()


# --- sauvegarde ----------------------------------------------------------------------
func load_settings() -> void:
	var cf := ConfigFile.new()
	var txt := SafeFile.read(save_path, func(t): return ConfigFile.new().parse(t) == OK)
	if txt == "" or cf.parse(txt) != OK:
		return
	for section in DEFAULTS:
		for key in DEFAULTS[section]:
			var def: Variant = DEFAULTS[section][key]
			var v: Variant = cf.get_value(section, key, def)
			if typeof(v) == typeof(def) or (def is float and v is int):
				data[section][key] = v
	if cf.has_section("keys"):
		for action in DEFAULT_BINDS:
			if not cf.has_section_key("keys", action):
				continue  # touche ajoutée depuis la sauvegarde : le réglage par défaut reste
			var v: Variant = cf.get_value("keys", action, null)
			if v is Array:
				binds[action] = v.filter(func(e): return e is Dictionary and (e.has("k") or e.has("m")))
	if cf.has_section("pad"):
		for action in PAD_ACTIONS:
			if not cf.has_section_key("pad", action):
				continue
			var v: Variant = cf.get_value("pad", action, null)
			if v is Array:
				pad_binds[action] = v.filter(func(e): return e is Dictionary and (e.has("b") or (e.has("a") and e.has("v"))))


func save_settings() -> void:
	var cf := ConfigFile.new()
	for section in data:
		for key in data[section]:
			cf.set_value(section, key, data[section][key])
	for action in binds:
		cf.set_value("keys", action, binds[action])
	for action in PAD_ACTIONS:
		cf.set_value("pad", action, pad_binds.get(action, []))
	SafeFile.write(save_path, cf.encode_to_text(), func(t): return ConfigFile.new().parse(t) == OK)


# --- touches -------------------------------------------------------------------------
func apply_bindings() -> void:
	for action in DEFAULT_BINDS:
		if InputMap.has_action(action):
			InputMap.action_erase_events(action)
		else:
			InputMap.add_action(action)
		for e in binds.get(action, []):
			var ev := event_from(e)
			if ev:
				InputMap.action_add_event(action, ev)
		for e in pad_binds.get(action, PAD_BINDS.get(action, [])):
			InputMap.action_add_event(action, pad_event(e))
		if String(action).begins_with("move_"):
			InputMap.action_set_deadzone(action, 0.2)  # stick : déplacement progressif
	for action in DEBUG_BINDS:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
			InputMap.action_add_event(action, event_from({"k": DEBUG_BINDS[action]}))


static func event_from(e: Dictionary) -> InputEvent:
	if e.has("k"):
		var ev := InputEventKey.new()
		ev.physical_keycode = int(e.k) as Key
		return ev
	if e.has("m"):
		var ev := InputEventMouseButton.new()
		ev.button_index = int(e.m) as MouseButton
		return ev
	return null


static func pad_event(e: Dictionary) -> InputEvent:
	if e.has("b"):
		var b := InputEventJoypadButton.new()
		b.button_index = int(e.b) as JoyButton
		b.device = -1  # toutes les manettes
		return b
	var m := InputEventJoypadMotion.new()
	m.axis = int(e.a) as JoyAxis
	m.axis_value = float(e.v)
	m.device = -1
	return m


## Descripteur sauvegardable d'un évènement (touche ou bouton), {} si non utilisable.
static func describe_event(ev: InputEvent) -> Dictionary:
	if ev is InputEventKey:
		var k: int = ev.physical_keycode if ev.physical_keycode != 0 else ev.keycode
		return {"k": k} if k != 0 else {}
	if ev is InputEventMouseButton:
		if ev.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN, MOUSE_BUTTON_WHEEL_LEFT, MOUSE_BUTTON_WHEEL_RIGHT]:
			return {}
		return {"m": int(ev.button_index)}
	return {}


## Nom lisible d'une touche, selon la disposition du clavier (Z sur AZERTY pour KEY_W).
static func event_label(e: Dictionary) -> String:
	if e.has("m"):
		return {MOUSE_BUTTON_LEFT: "Clic gauche", MOUSE_BUTTON_RIGHT: "Clic droit", MOUSE_BUTTON_MIDDLE: "Clic molette",
			MOUSE_BUTTON_XBUTTON1: "Souris 4", MOUSE_BUTTON_XBUTTON2: "Souris 5"}.get(int(e.m), "Souris %d" % int(e.m))
	if e.has("k"):
		var k := int(e.k) as Key
		var names := {KEY_SHIFT: "Maj", KEY_CTRL: "Ctrl", KEY_ALT: "Alt", KEY_SPACE: "Espace", KEY_ESCAPE: "Échap",
			KEY_ENTER: "Entrée", KEY_TAB: "Tab", KEY_BACKSPACE: "Retour", KEY_UP: "↑", KEY_DOWN: "↓",
			KEY_LEFT: "←", KEY_RIGHT: "→", KEY_CAPSLOCK: "Verr. maj"}
		if names.has(k):
			return names[k]
		var shown := KEY_NONE if DisplayServer.get_name() == "headless" else DisplayServer.keyboard_get_keycode_from_physical(k)
		var key_shown: int = shown if shown != KEY_NONE else k
		var symbols := {KEY_COMMA: ",", KEY_PERIOD: ".", KEY_SEMICOLON: ";", KEY_COLON: ":", KEY_SLASH: "/", KEY_BACKSLASH: "\\",
			KEY_MINUS: "-", KEY_EQUAL: "=", KEY_QUOTELEFT: "`", KEY_APOSTROPHE: "'", KEY_BRACKETLEFT: "[", KEY_BRACKETRIGHT: "]",
			KEY_DELETE: "Suppr", KEY_INSERT: "Inser", KEY_HOME: "Début", KEY_END: "Fin", KEY_PAGEUP: "Page ↑", KEY_PAGEDOWN: "Page ↓"}
		if symbols.has(key_shown):
			return symbols[key_shown]
		var label := OS.get_keycode_string(key_shown)
		return label.to_upper() if label.length() == 1 else label
	return "—"


## Libellé court des touches d'une action (« A / 1 »), pour le HUD et l'aide.
func action_label(action: String, max_events := 2) -> String:
	if Gamepad.active and String(action).begins_with("move_"):
		return "Stick gauche"
	if Gamepad.active and pad_binds.has(action) and not (pad_binds[action] as Array).is_empty():
		return pad_action_label(action)
	if Gamepad.active and PAD_LABELS.has(action):
		return String(PAD_LABELS[action])
	var parts: PackedStringArray = []
	for e in binds.get(action, []).slice(0, max_events):
		parts.append(event_label(e))
	return " / ".join(parts) if not parts.is_empty() else "—"


## Assigne [param e] à l'emplacement [param idx] de [param action] ; l'enlève des autres
## actions. Renvoie les noms des actions qui l'ont perdue.
func bind(action: String, idx: int, e: Dictionary) -> PackedStringArray:
	var lost: PackedStringArray = []
	for other in binds:
		if other == action or _may_share(action, other):
			continue
		var before: int = binds[other].size()
		binds[other] = binds[other].filter(func(x): return not _same(x, e))
		if binds[other].size() != before:
			lost.append(action_name(other))
	var list: Array = binds.get(action, []).filter(func(x): return not _same(x, e))
	if idx < list.size():
		list[idx] = e
	else:
		list.append(e)
	binds[action] = list
	apply_bindings()
	save_settings()
	changed.emit()
	return lost


func unbind(action: String, idx: int) -> void:
	var list: Array = binds.get(action, [])
	if idx < list.size():
		list.remove_at(idx)
	apply_bindings()
	save_settings()
	changed.emit()


# --- manette réassignable ------------------------------------------------------------------
## Disposition affichée : "xbox" ou "ps" (Paramètres > Interface, sinon d'après le nom de la manette).
func pad_layout() -> String:
	var forced := String(get_v("interface", "pad_labels"))
	if forced in ["xbox", "ps"]:
		return forced
	var n := Input.get_joy_name(0).to_lower() if not Input.get_connected_joypads().is_empty() else ""
	for key in ["playstation", "dualshock", "dualsense", "ps3", "ps4", "ps5", "sony"]:
		if n.contains(key):
			return "ps"
	return "xbox"  # Xbox, Steam Link (manette virtuelle) et inconnues


## Nom d'un bouton de la manette ([param button] : JoyButton) dans la disposition affichée.
func pad_name(button: int) -> String:
	return String(PAD_NAMES[pad_layout()].get(button, "Bouton %d" % button))


func pad_label(e: Dictionary) -> String:
	if e.has("b"):
		return pad_name(int(e.b))
	if e.has("a"):
		var t: Dictionary = PAD_TRIGGERS[pad_layout()]
		return String(t.get(int(e.a), "Axe %d" % int(e.a)))
	return "—"


func pad_action_label(action: String) -> String:
	var list: Array = pad_binds.get(action, [])
	return pad_label(list[0]) if not list.is_empty() else "—"


## Descripteur d'un évènement de manette (bouton ou gâchette), {} sinon (les sticks ne s'assignent pas).
static func describe_pad(ev: InputEvent) -> Dictionary:
	if ev is InputEventJoypadButton and ev.pressed:
		return {"b": int(ev.button_index)}
	if ev is InputEventJoypadMotion and ev.axis in [JOY_AXIS_TRIGGER_LEFT, JOY_AXIS_TRIGGER_RIGHT] and absf(ev.axis_value) > 0.7:
		return {"a": int(ev.axis), "v": 1.0}
	return {}


## Assigne [param e] à [param action] (un seul bouton par action) ; l'enlève des autres. Renvoie les
## noms des actions qui l'ont perdu.
func pad_bind(action: String, e: Dictionary) -> PackedStringArray:
	var lost: PackedStringArray = []
	for other in PAD_ACTIONS:
		if other == action:
			continue
		var list: Array = pad_binds.get(other, [])
		var kept := list.filter(func(x): return not (x == e or (x.has("a") and e.has("a") and int(x.a) == int(e.a)) or (x.has("b") and e.has("b") and int(x.b) == int(e.b))))
		if kept.size() != list.size():
			pad_binds[other] = kept
			lost.append(action_name(other))
	pad_binds[action] = [e]
	apply_bindings()
	save_settings()
	changed.emit()
	return lost


func reset_pad_bindings() -> void:
	pad_binds = PAD_BINDS.duplicate(true)
	apply_bindings()
	save_settings()
	changed.emit()


func reset_bindings() -> void:
	binds = DEFAULT_BINDS.duplicate(true)
	apply_bindings()
	save_settings()
	changed.emit()


func action_name(action: String) -> String:
	for a in ACTIONS:
		if a[0] == action:
			return a[1]
	return action


func _may_share(a: String, b: String) -> bool:
	for pair in SHARED_OK:
		if (pair[0] == a and pair[1] == b) or (pair[0] == b and pair[1] == a):
			return true
	return false


static func _same(a: Dictionary, b: Dictionary) -> bool:
	return (a.has("k") and b.has("k") and int(a.k) == int(b.k)) or (a.has("m") and b.has("m") and int(a.m) == int(b.m))


# --- application ---------------------------------------------------------------------
func apply_all() -> void:
	for section in DEFAULTS:
		_apply_section(section)


func _apply_section(section: String) -> void:
	match section:
		"display":
			_apply_display()
			CursorSets.apply()  # la taille du curseur suit celle de l'interface
		"interface":
			CursorSets.apply()
		"audio":
			var bus := AudioServer.get_bus_index("Master")
			AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(float(get_v("audio", "master")), 0.0001)))
			Sfx.volume_db = linear_to_db(maxf(float(get_v("audio", "sfx")), 0.0001))
			var music := get_node_or_null("/root/Music")  # chargée après les paramètres au démarrage
			if music:
				music.set_volume(float(get_v("audio", "music")))


func _apply_display() -> void:
	Engine.max_fps = int(get_v("display", "max_fps"))
	var win := get_window()
	win.msaa_3d = {0: Viewport.MSAA_DISABLED, 2: Viewport.MSAA_2X, 4: Viewport.MSAA_4X, 8: Viewport.MSAA_8X}.get(
		int(get_v("display", "msaa")), Viewport.MSAA_2X)
	win.content_scale_factor = float(get_v("display", "ui_scale"))
	if DisplayServer.get_name() == "headless":
		return
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if get_v("display", "vsync") else DisplayServer.VSYNC_DISABLED)
	match String(get_v("display", "window_mode")):
		"fullscreen":
			win.mode = Window.MODE_FULLSCREEN
		"exclusive":
			win.mode = Window.MODE_EXCLUSIVE_FULLSCREEN
		"maximized":
			win.mode = Window.MODE_WINDOWED
			win.borderless = false
			win.mode = Window.MODE_MAXIMIZED
		_:
			win.mode = Window.MODE_WINDOWED
			win.borderless = false
			var parts := String(get_v("display", "resolution")).split("x")
			if parts.size() == 2:
				var screen := DisplayServer.window_get_current_screen()
				var usable := DisplayServer.screen_get_usable_rect(screen)
				var size := Vector2i(int(parts[0]), int(parts[1]))
				size = Vector2i(mini(size.x, usable.size.x), mini(size.y, usable.size.y))
				win.size = size
				win.position = usable.position + (usable.size - size) / 2
