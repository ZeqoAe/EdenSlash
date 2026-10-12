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
	["move_order", "Déplacer / attaquer (mode RTS)"], ["jump", "Sauter"], ["dodge", "Esquive"],
	["skill_1", "Compétence 1"], ["skill_2", "Compétence 2"], ["skill_3", "Compétence 3"],
	["skill_4", "Compétence 4"], ["interact", "Interagir"], ["map", "Carte"],
	["objectives", "Afficher les objectifs"], ["pause", "Menu / pause"],
	["camera_rotate", "Tourner la caméra (maintenu)"], ["unstuck", "Se débloquer"], ["help", "Aide"],
	["feedback", "Signaler un problème"], ["extract", "S'extraire (10 s)"],
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
	"pause": [{"k": KEY_ESCAPE}],
	"camera_rotate": [{"m": MOUSE_BUTTON_RIGHT}],
	"unstuck": [{"k": KEY_F4}],
	"help": [{"k": KEY_F1}],
	"feedback": [{"k": KEY_F9}],
	"extract": [{"k": KEY_X}],
}
## Touches de test, non modifiables.
const DEBUG_BINDS := {
	"debug_level": KEY_F5, "debug_gateway": KEY_F6, "debug_dungeon": KEY_F7,
	"debug_overlay": KEY_F2, "debug_rage": KEY_F8,
}

const DEFAULTS := {
	"display": {"window_mode": "windowed", "resolution": "1600x900", "vsync": true, "max_fps": 0,
		"msaa": 2, "ui_scale": 1.0, "quality": "high"},
	"audio": {"master": 0.8, "sfx": 1.0},
	# move_mode : keyboard (ZQSD), click (clic gauche), rts (clic droit)
	# aim_mode : smart (cible, sinon curseur, sinon monstre proche), cursor (le héros suit
	#            le curseur), nearest (toujours le monstre le plus proche)
	# attack_mode : manual (clic), auto (frappe seul les monstres à portée)
	# auto_skills : compétences lancées seules dès qu'elles sont prêtes et qu'un monstre est à portée
	# auto_target : any (n'importe quel monstre à portée), locked (seulement la cible verrouillée)
	"game": {"move_mode": "keyboard", "aim_mode": "smart", "attack_mode": "manual",
		"auto_skills": [false, false, false, false], "auto_target": "any"},
	"camera": {"rotate_speed": 1.0, "invert_y": false, "distance": 15.0, "shake": 1.0},
	# dev_mode : écran de test (F10), réservé aux tests
	"interface": {"damage_numbers": "all", "hit_stop": true, "show_fps": true, "move_marker": true, "dev_mode": false},
}

## Modes de jeu prêts à l'emploi (réglages du menu Contrôles).
const PRESETS := {
	"classic": {"name": "Classique", "desc": "ZQSD pour se déplacer, clic gauche pour attaquer (sur un monstre : auto-attaque), compétences au clavier.",
		"game": {"move_mode": "keyboard", "aim_mode": "smart", "attack_mode": "manual"}},
	"twin_stick": {"name": "Visée au curseur", "desc": "ZQSD pour se déplacer, le héros regarde toujours le curseur : attaques et compétences partent vers la souris.",
		"game": {"move_mode": "keyboard", "aim_mode": "cursor", "attack_mode": "manual"}},
	"arpg": {"name": "Souris (ARPG)", "desc": "Clic gauche (maintenu) pour se déplacer vers le curseur, clic sur un monstre pour l'attaquer, compétences au clavier vers la souris.",
		"game": {"move_mode": "click", "aim_mode": "cursor", "attack_mode": "auto"}},
	"rts": {"name": "RTS / MOBA", "desc": "Clic droit pour se déplacer ou attaquer un monstre, compétences au clavier vers la souris, caméra au clic molette.",
		"game": {"move_mode": "rts", "aim_mode": "cursor", "attack_mode": "auto"}},
	"relax": {"name": "Détente", "desc": "ZQSD pour se déplacer : attaque de base et compétences se lancent seules sur les monstres à portée.",
		"game": {"move_mode": "keyboard", "aim_mode": "nearest", "attack_mode": "auto", "auto_skills": [true, true, true, true]}},
}

const RESOLUTIONS := ["1280x720", "1366x768", "1600x900", "1920x1080", "2560x1440", "3840x2160"]

var data: Dictionary = {}
var binds: Dictionary = {}  # action -> [{"k": ...} | {"m": ...}]
var save_path := SAVE_PATH


func _ready() -> void:
	if not OS.get_cmdline_user_args().is_empty() or " ".join(OS.get_cmdline_args()).contains("res://tests/"):
		save_path = TEST_SAVE_PATH
	UiTheme.apply_global()
	reset_all(false)
	load_settings()
	apply_bindings()
	apply_all()


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


func apply_preset(id: String) -> void:
	var p: Dictionary = PRESETS.get(id, {})
	var g: Dictionary = p.get("game", {})
	for k in g:
		data.game[k] = g[k].duplicate() if g[k] is Array else g[k]
	if not g.has("auto_skills"):
		data.game.auto_skills = [false, false, false, false]
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
		if ok:
			return id
	return ""


func move_mode() -> String:
	return String(get_v("game", "move_mode"))


func aim_mode() -> String:
	return String(get_v("game", "aim_mode"))


func auto_attack() -> bool:
	return get_v("game", "attack_mode") == "auto"


func auto_skill(slot: int) -> bool:
	var a: Array = get_v("game", "auto_skills")
	return slot < a.size() and bool(a[slot])


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
	if save:
		apply_bindings()
		apply_all()
		save_settings()
		changed.emit()


# --- sauvegarde ----------------------------------------------------------------------
func load_settings() -> void:
	var cf := ConfigFile.new()
	if cf.load(save_path) != OK:
		return
	for section in DEFAULTS:
		for key in DEFAULTS[section]:
			var def: Variant = DEFAULTS[section][key]
			var v: Variant = cf.get_value(section, key, def)
			if typeof(v) == typeof(def) or (def is float and v is int):
				data[section][key] = v
	if cf.has_section("keys"):
		for action in DEFAULT_BINDS:
			var v: Variant = cf.get_value("keys", action, null)
			if v is Array:
				binds[action] = v.filter(func(e): return e is Dictionary and (e.has("k") or e.has("m")))


func save_settings() -> void:
	var cf := ConfigFile.new()
	for section in data:
		for key in data[section]:
			cf.set_value(section, key, data[section][key])
	for action in binds:
		cf.set_value("keys", action, binds[action])
	cf.save(save_path)


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
		var label := OS.get_keycode_string(shown if shown != KEY_NONE else k)
		return label.to_upper() if label.length() == 1 else label
	return "—"


## Libellé court des touches d'une action (« A / 1 »), pour le HUD et l'aide.
func action_label(action: String, max_events := 2) -> String:
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
		"audio":
			var bus := AudioServer.get_bus_index("Master")
			AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(float(get_v("audio", "master")), 0.0001)))
			Sfx.volume_db = linear_to_db(maxf(float(get_v("audio", "sfx")), 0.0001))


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
