class_name PresetPick
extends RefCounted
## Choix du préréglage d'équipement sur la page d'une activité, avant « Lancer » (lot GX-5, étude BM-GEAR Q6 : « 5
## préréglages nommés par usage, choisis sur la page de l'activité »). Une rangée « Équipement » : un bouton par préréglage
## qui a des pièces (nom, ou numéro pour un nom d'origine), le préréglage actif en premier plan ; l'infobulle donne sa
## puissance d'équipement. Un clic change le préréglage actif de la classe (Profile.set_active_preset, comme Héros) puis
## [param on_change] (la page se reconstruit : PE, estimation). Rien en partie, rien pour les modes scellés (leur propre
## équipement). Le préréglage dont le nom d'usage correspond à l'activité porte une petite pastille « conseillé ».
##
## [codeblock]
## PresetPick.add(_sub, "dungeon", func(): _show_menu("dungeon"))
## [/codeblock]

## Nom d'usage (Profile.PRESET_USES) qui convient à chaque activité.
const USE_OF := {"survival": "Survie", "dungeon": "Donjons", "rush": "Donjons", "siege": "Donjons", "tower": "Tour", "duel": "Duel"}


## Ajoute la rangée à [param parent] ; renvoie null quand il n'y a rien à choisir (en partie, un seul préréglage rempli).
static func add(parent: Control, activity: String, on_change: Callable) -> Control:
	if Profile.in_run:
		return null
	var cid := Profile.selected_class
	var names := Profile.preset_names(cid)
	var active := Profile.active_preset(cid)
	var usable: Array = []
	for i in names.size():
		if i == active or EquipmentPage.PresetBar.piece_count(cid, i) > 0:
			usable.append(i)
	if usable.size() <= 1:
		return null
	var row := HBoxContainer.new()
	row.name = "PresetPick"
	row.add_theme_constant_override("separation", 6)
	parent.add_child(row)
	var l := Hud._label(row, "Équipement", 15, UiTheme.GOLD)
	l.add_theme_font_override("font", UiTheme.bold_font())
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	l.custom_minimum_size.x = 104
	l.mouse_filter = Control.MOUSE_FILTER_STOP
	l.tooltip_text = "Préréglage porté pour cette partie (Héros > Équipement pour le modifier)."
	var advised := advised_index(cid, activity)
	for i in usable:
		var on: bool = i == active
		var nm := String(names[i])
		var txt := str(i + 1) if Profile.preset_default_name(nm) else nm
		var b := ForgeWidgets.candy_button(("✓ " if on else "") + txt + ("  ★" if i == advised and not on else ""), "mandarine" if on else "papier", 15, 38)
		b.clip_text = true
		b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		b.custom_minimum_size.x = 44.0 if txt.length() <= 2 else 0.0
		b.size_flags_horizontal = Control.SIZE_FILL if txt.length() <= 2 else Control.SIZE_EXPAND_FILL
		b.tooltip_text = tip(cid, i, i == advised)
		var k: int = i
		b.pressed.connect(func():
			if k != Profile.active_preset(cid):
				Profile.set_active_preset(cid, k)
				Sfx.ui("confirm")
				if on_change.is_valid():
					on_change.call())
		row.add_child(b)
	return row


## Préréglage dont le nom d'usage va avec l'activité [param activity] (-1 : aucun).
static func advised_index(cid: String, activity: String) -> int:
	var use := String(USE_OF.get(activity, ""))
	if use == "":
		return -1
	var names := Profile.preset_names(cid)
	for i in names.size():
		if String(names[i]) == use:
			return i
	return -1


## Infobulle : nom, pièces, PE du préréglage.
static func tip(cid: String, i: int, advised := false) -> String:
	var g := Profile.preset_gear(cid, i)
	var nm := String(Profile.preset_names(cid)[i])
	return "%s · %s · PE %s%s" % [nm, EquipmentPage.PresetBar.pieces_text(g.size()), GearPower.fmt(GearPower.gear_power(g)),
		"\nSon nom va avec cette activité." if advised else ""]
