class_name Hud
extends CanvasLayer
## HUD de la partie, DA v2 « autocollant » (lot HUD-2, croquis BM-HUB `hub_maquettes/hud.html`, pièces dans HudV2) :
## - bas : cases de sorts autocollantes (2 potions, 4 sorts, esquive, arme rangée), touche dessinée sous chaque case,
##   barre de niveau lagon à droite (au lieu du globe) et niveau d'aide, jauge de vie large dessous ; effets positifs
##   au-dessus à gauche, négatifs à droite ;
## - haut gauche (pile) : objectifs repliés (zone, chrono, sceaux), dépliés avec [Tab] et quelques secondes à chaque
##   découverte, Menace, quête suivie, Premiers pas ;
## - haut centre : cible (PV, niveau, effets), ou la barre de boss v2 (BossBar) ; bandeau d'annonce dessous ;
## - droite (colonne) : mini-carte ronde au cadre papier, compteur de dégâts, carte de notification (file HudNotices),
##   fil du butin : chacun sous le précédent, jamais sur la barre d'action (_layout_right) ;
## - profils Standard / Compact / Minimal, taille et opacité (Paramètres > Affichage > HUD en partie).
## Le Battle royale (RoyaleHud) et le Survivant (SurvivorHud) posent leurs modules par-dessus à la fin de _build.

const ACCENT := UiTheme.GOLD
const PANEL := Color(0.07, 0.06, 0.12, 0.82)
const PANEL_W := 360.0  # largeur des panneaux de la pile en haut à gauche
const OBJECTIVE_AUTO_SHOW := 5.0  # s de dépliage automatique après une découverte

var player: Player
var director: RunDirector
var minimap: Minimap

var _hp_orb: HudV2.LifeGauge  # jauge de vie (nom d'avant gardé : le Survivant la masque, des tests la lisent)
var _xp_orb: HudV2.LevelBar  # barre de niveau (au lieu du globe)
var _slots: Array[HudWidgets.SkillSlot] = []
var _dodge: HudWidgets.SkillSlot
var _swap: HudWidgets.SkillSlot  # arme rangée : « Changer d'arme » (passe N2), visible avec une arme secondaire
var _potion_slots: Array = []  # cases de potions (soin, effet)
var _queue_strip: HudWidgets.QueueStrip
var _assist_label: Label
var _steps_panel: PanelContainer
var _steps_head: Label
var _steps_text: Label
var _cards: InfoCard  # fiche de découverte : une petite carte à droite, sous le compteur de dégâts
var notices: HudNotices  # file unique des cartes (lot HUB-1, P0-7) : une à la fois, danger > quête > nouveauté > butin
var _feed_wait: Array = []  # lignes de butin qui attendent la fin du bandeau d'annonce (P0-7)
var _buff_row: HudWidgets.StatusRow
var _debuff_row: HudWidgets.StatusRow
var _durations := {}  # "cible:effet" -> [fin, durée totale]
var _last_level := 0

var _left: VBoxContainer  # pile en haut à gauche : objectifs, premiers pas, fil de butin (se recale seule)
var _obj_panel: PanelContainer
var _obj_chevron: Label  # ▾ / ▴ : les objectifs se déplient avec la touche des objectifs
var _zone_label: Label
var _gold_label: Label  # or et clés de la run (coffres, marchands, forge)
var _clock_label: Label
var _seal_label: Label
var _obj_details: VBoxContainer
var _obj_lines: Array[Label] = []
var _obj_pinned := false
var _obj_show_until := 0.0
var _obj_signature := ""
var _zone_text := ""
var _zone_extra := ""  # « Étape 1/3 », « Nv 29 » : en police ordinaire (le « 1 » de la police des titres se lit comme un I)
var _target_big := false  # la cible est un boss : cadre large
var _target_bars: Control
var _target_phase: Control  # repère de phase sur la barre d'un boss (deux encoches)
var _target_w := 380.0

var _target_box: PanelContainer
var _target_name: Label
var _target_tag: Label
var _target_bar: ProgressBar
var _target_trail: ProgressBar
var _target_row: HudWidgets.StatusRow
var _target_hp: Label  # PV actuels / max, sur la barre
var _target_ref: WeakRef

var _center_label: Label  # titre du bandeau d'annonce
var _center_sub: Label  # détail du bandeau (2e ligne et suivantes)
var _banner: PanelContainer
const BANNER_SIDE := 390.0  # place gardée de chaque côté du bandeau d'annonce : la pile de gauche et la mini-carte (lots DNG-1, HUD-2)
const BANNER_MAX := 1000.0
var _feed: VBoxContainer  # fil de butin (à gauche) : petites lignes qui s'effacent
## Messages qui vont dans le fil de butin plutôt que dans le bandeau (début du texte).
const FEED_PREFIXES := ["Butin", "Clé", "Une clé", "Coffre", "Coffre ouvragé", "Coffre doré", "Équipé", "Rangé", "Cristal", "Potion"]
var _prompt_box: PanelContainer
var _better_box: PanelContainer  # objet ramassé meilleur que la pièce portée : [G] Équiper
var _better_label: RichTextLabel
var better_item: Dictionary = {}
var _better_until := 0.0
var _prompt: Label
var _fps_label: Label
var _dmg_box: VBoxContainer  # compteur de dégâts cumulés (Run.combo_damage)
var _dmg_value: Label
var _dmg_best: Label
var _dmg_bar: ColorRect
var _dmg_shown := 0.0
var _arrow: Label
var _big_map: Minimap
var _msg_tween: Tween
var _clock := 0.0
var _low_hp: TextureRect
var _root: Control
var _sv_hud: SurvivorHud  # Survivant : frise des 20 minutes (null ailleurs)
var _royale: RoyaleHud  # Battle royale : HUD d'état v2, flèches, repère, grande carte (lot BR-I1 ; null ailleurs)
var _moba: MobaHud  # Les Deux Voies : tableau, mini-carte, alliés, boutique, annonces, mort (lot MB-H ; null ailleurs)
var _assault: AssaultHud  # L'Assaut : score, Charge, or, cases achetées, mini-carte, mort et ordres (lots TAC-7 / TAC-8 ; null ailleurs)
var _boss_bar: BossBar  # barre de boss v2, frise « À venir », annonces à 3 niveaux (lot DNG-2)
var _map_holder: Control  # support de la mini-carte ronde (haut droite)
var _loot: VBoxContainer  # colonne du fil du butin à droite (lot HUD-2) ; Battle royale et Survivant : null (fil dans la pile de gauche)
var _cards_top := -1.0  # haut de la carte de notification posé par _layout_right
var _dmg_room := true  # le compteur de dégâts a sa place (une carte de notification passe avant lui sur un petit écran)
const DMG_H := 96.0  # hauteur gardée pour le compteur de dégâts dans la colonne de droite
const FEED_LINE_H := 38.0  # hauteur d'une ligne du fil du butin (avec l'écart)
const FEED_TONES := {"Butin": "soleil", "Coffre": "soleil", "Clé": "mandarine", "Une clé": "mandarine", "Cristal": "lagon",
	"Potion": "fraise", "Équipé": "pomme", "Rangé": "pomme"}
static var _feed_style: StyleBox


func setup(p: Player, d: RunDirector) -> void:
	player = p
	director = d
	_build()
	player.health_changed.connect(_on_hp)
	player.damaged.connect(_on_player_hit)
	player.xp_changed.connect(_on_xp)
	player.skills_changed.connect(_refresh_skills)
	Settings.changed.connect(_refresh_skills)
	Gamepad.device_changed.connect(func(_pad): _refresh_skills())  # libellés des touches (manette ou clavier)
	director.zone_changed.connect(func(z):
		var parts := zone_parts(z)
		_zone_text = parts[0]
		_zone_extra = parts[1])
	director.message.connect(show_message)
	director.better_item.connect(show_better)
	Run.weapon_bagged.connect(show_bagged)  # (l'échange d'arme, lui, reste discret : éclair, son et case de l'arme rangée)
	player.weapon_swapped.connect(func(_off): _swap._flash = 1.0)  # (lot HUD-2) la case de l'arme rangée s'éclaire à l'échange
	_on_hp(player.hp, player.max_hp)
	_on_xp(player.xp, GameData.xp_to_next(player.level), player.level)
	_refresh_skills()


## Titre du panneau d'objectifs : « Zone · étape 1/3 ». Le niveau des monstres n'est donné que là où il compte
## (duel, Tour, donjons : « Nv 14 », jamais « Nv 14-14 ») ; en Survie il suit la carte. Battle royale : l'horloge
## de l'anneau prend toute la ligne, pas de titre.
static func zone_title(z: Dictionary) -> String:
	var parts := zone_parts(z)
	return parts[0] if parts[1] == "" else "%s · %s" % parts


## Le titre en deux morceaux [nom, précision] : le nom s'écrit en police des titres, la précision (étape, niveau)
## en police ordinaire sur la ligne du dessous.
static func zone_parts(z: Dictionary) -> Array:
	if Royale.active:
		return ["", ""]
	if Training.active:
		return ["Entraînement", ""]
	var lo := int(z.levels[0])
	var hi := int(z.levels[1])
	if Tower.active:
		var base := "La Ruée" if Tower.rush else ("Le Siège" if Tower.siege else ("Donjon" if Tower.is_dungeon() else "La Tour"))
		return [base, "Nv %d" % lo]
	if not Duel.active:
		var m := RegEx.create_from_string("^(.*) · [ée]tape (\\d+/\\d+)$").search(String(z.name))
		if m:
			return [m.get_string(1), "Étape " + m.get_string(2)]
		return [String(z.name), ""]
	return [String(z.name), "Nv %d" % lo if lo == hi else "Nv %d-%d" % [lo, hi]]


func _build() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # se masque sous les menus qui mettent le jeu en pause
	var root := Control.new()
	_root = root
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# liseré rouge sur les bords de l'écran quand la vie est basse
	_low_hp = TextureRect.new()
	var grad := GradientTexture2D.new()
	grad.fill = GradientTexture2D.FILL_RADIAL
	grad.fill_from = Vector2(0.5, 0.5)
	grad.fill_to = Vector2(1.05, 1.05)
	grad.gradient = Gradient.new()
	grad.gradient.set_color(0, Color(0.7, 0.0, 0.05, 0.0))
	grad.gradient.set_color(1, Color(0.75, 0.0, 0.05, 0.9))
	grad.gradient.add_point(0.5, Color(0.7, 0.0, 0.05, 0.0))
	_low_hp.texture = grad
	_low_hp.set_anchors_preset(Control.PRESET_FULL_RECT)
	_low_hp.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_low_hp.stretch_mode = TextureRect.STRETCH_SCALE
	_low_hp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_low_hp.modulate.a = 0.0
	root.add_child(_low_hp)
	# NB : root n'est ajouté qu'à la fin, pour que les positions ancrées
	# (centre, bas, droite) soient relatives à l'ancre.
	_left = VBoxContainer.new()
	_left.add_theme_constant_override("separation", 8)
	_left.position = Vector2(14, 12)
	_left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_left)
	_build_objectives(root)
	MenaceBadge.attach(_left, director)  # « Menace ×1,2 · Pacte » sous les objectifs (passe P12)
	QuestBadge.attach(_left, self)  # la quête en cours, discrète (passe M5)
	_build_tutorial(root)
	_build_minimap(root)
	_build_target(root)
	_boss_bar = BossBar.attach(root, self)  # boss : barre v2 à la place du cadre de cible (lot DNG-2)
	_build_action_bar(root)

	# --- messages (centre) ---
	# bandeau d'annonce : haut de l'écran, titre + détail dans un autocollant d'encre (lot HUD-2 : même famille que les
	# annonces de boss HudAlert ; contour d'encre, ombre dure, titre en Mochiy contouré)
	_banner = PanelContainer.new()
	_banner.add_theme_stylebox_override("panel", UiTheme.sticker("nuit", {"radius": 16, "shadow": 5, "pad": Vector2(26, 8),
		"gloss": false, "cel_top": 0.0, "cel_bottom": 0.0}))
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_banner.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_banner.offset_left = -230
	_banner.offset_right = 230
	_banner.offset_top = 122
	_banner.custom_minimum_size = Vector2(460, 0)
	root.add_child(_banner)
	var bv := VBoxContainer.new()
	bv.add_theme_constant_override("separation", 2)
	bv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner.add_child(bv)
	_center_label = _label(bv, "", 30, ACCENT)
	_center_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiTheme.title(_center_label, 30)
	_center_sub = _label(bv, "", 17, UiTheme.color("papier.100"))
	_center_sub.add_theme_font_override("font", UiTheme.bold_font())
	_center_sub.add_theme_color_override("font_outline_color", UiTheme.color("encre.700"))
	_center_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_center_sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_center_sub.custom_minimum_size = Vector2(460, 0)
	_banner.modulate.a = 0.0
	# fil du butin (lot HUD-2) : colonne de droite, sous la carte de notification (Diablo, WoW : une ligne par trouvaille,
	# case de couleur) ; Battle royale et Survivant : dans la pile de gauche comme avant (leur colonne de droite est prise)
	_feed = VBoxContainer.new()
	_feed.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_feed.add_theme_constant_override("separation", 6)
	_feed.custom_minimum_size = Vector2(PANEL_W, 0)
	if Royale.active or Survivor.active:
		_left.add_child(_feed)
	else:
		_loot = _feed
		_feed.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		_feed.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		_feed.offset_left = -(PANEL_W + 16.0)
		_feed.offset_right = -16.0
		_feed.offset_top = 260.0
		root.add_child(_feed)

	# --- invite d'interaction ([F] Ouvrir...) : autocollant papier, texte à l'encre ---
	_prompt_box = PanelContainer.new()
	_prompt_box.add_theme_stylebox_override("panel", UiTheme.sticker("papier", {"radius": 14, "shadow": 4, "pad": Vector2(18, 6),
		"gloss": false, "cel_top": 0.0, "cel_bottom": 0.0}))
	_prompt_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_prompt_box.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_prompt_box.position = Vector2(0, -270)
	root.add_child(_prompt_box)
	_prompt = _label(_prompt_box, "", 20, UiTheme.color("encre.700"))
	_prompt.add_theme_font_override("font", UiTheme.bold_font())
	_prompt.add_theme_constant_override("outline_size", 0)
	_prompt_box.visible = false

	_better_box = PanelContainer.new()
	_better_box.add_theme_stylebox_override("panel", UiTheme.sticker("nuit", {"radius": 14, "shadow": 4, "pad": Vector2(14, 8),
		"gloss": false, "cel_top": 0.0, "cel_bottom": 0.0, "ink": UiTheme.color("bonbon.pomme.fonce")}))
	_better_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_better_box.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_better_box.custom_minimum_size = Vector2(420, 0)
	_better_box.offset_left = -210
	_better_box.offset_right = 210
	_better_box.offset_top = -205
	_better_box.offset_bottom = -150
	root.add_child(_better_box)
	_better_label = RichTextLabel.new()
	_better_label.bbcode_enabled = true
	_better_label.fit_content = true
	_better_label.scroll_active = false
	_better_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_better_label.add_theme_font_size_override("normal_font_size", 15)
	_better_box.add_child(_better_label)
	_better_box.visible = false

	_arrow = _label(root, "▲", 36, ACCENT)
	_arrow.add_theme_constant_override("outline_size", 9)
	_arrow.add_theme_color_override("font_outline_color", UiTheme.color("encre.700"))
	_arrow.pivot_offset = Vector2(13, 25)
	_arrow.visible = false

	# --- grande carte [M] ---
	_big_map = Minimap.new()
	_big_map.big = true
	_big_map.set_anchors_preset(Control.PRESET_CENTER)
	_big_map.position = Vector2(-340, -340)
	_big_map.size = Vector2(680, 680)
	_big_map.visible = false
	root.add_child(_big_map)
	_big_map.setup(player, director)
	add_child(root)
	_apply_hud_prefs()  # taille et opacité du HUD (lot HUB-1, P0-9)
	Settings.changed.connect(_apply_hud_prefs)
	get_viewport().size_changed.connect(_apply_hud_prefs)
	if Royale.active:
		_royale = RoyaleHud.attach(self, root)
	elif Survivor.active:
		_sv_hud = SurvivorHud.attach(self, root, director)  # Survivant : HUD v2 (lot SVX-2 : XP pleine largeur, chrono et frise, collection, vie)
	elif Duel.active:
		HitArc.attach(root, player)  # arc de coup reçu en Duel et en Arènes aussi (lot BR-I1)
	elif Modes.current() == "moba":
		_moba = MobaHud.attach(self, root)  # (lot MB-H) HUD des Deux Voies
	elif Modes.current() == "assault":
		_assault = AssaultHud.attach(self, root)  # (lot TAC-7) HUD de L'Assaut


# --- objectifs (haut gauche) -------------------------------------------------------------
## Premiers pas (étape en cours, touches réelles) et fiche de découverte : jamais bloquants.
func _build_tutorial(root: Control) -> void:
	_steps_panel = PanelContainer.new()
	_steps_panel.add_theme_stylebox_override("panel", UiTheme.panel_box(18, 10))
	_steps_panel.custom_minimum_size = Vector2(PANEL_W, 0)
	_steps_panel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_steps_panel.visible = false
	_left.add_child(_steps_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	_steps_panel.add_child(v)
	var h := HBoxContainer.new()
	v.add_child(h)
	_steps_head = _label(h, "", UiTheme.MIN_TEXT, ACCENT)
	_steps_head.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var skip := Button.new()
	skip.text = "Passer"
	skip.focus_mode = Control.FOCUS_NONE
	UiTheme.style_button(skip, "papier", UiTheme.MIN_TEXT, {"shadow": 3, "pad": Vector2(10, 1), "gloss": false})
	skip.pressed.connect(func():
		Tutorial.skip_steps()
		_steps_panel.visible = false)
	h.add_child(skip)
	_steps_text = _label(v, "", 16, Color.WHITE)
	_steps_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_steps_text.custom_minimum_size = Vector2(PANEL_W - 36.0, 0)
	_cards = InfoCard.in_control(root)  # colonne de droite : posée sous la mini-carte et le compteur de dégâts par _layout_right
	notices = HudNotices.new(_cards, banner_up)


## Manette : L3 ferme la fiche de découverte, R3 ouvre le Guide à son chapitre (en jeu B reste à l'action).
func _pad_card_input(event: InputEvent) -> bool:
	if not (event is InputEventJoypadButton and event.pressed) or _cards == null or _cards.count() == 0:
		return false
	if event.button_index == JOY_BUTTON_LEFT_STICK:
		_cards.dismiss_top("pad")
		return true
	if event.button_index == JOY_BUTTON_RIGHT_STICK:
		return _cards.press_top(1)
	return false


## Survie seulement : les Premiers pas et les fiches de découverte parlent de la Survie (pas du Duel, de la
## Tour, du Battle royale, du Survivant ni de l'entraînement, qui peuvent pourtant garder le drapeau de la Survie).
func _survival_mode() -> bool:
	return Run.survival and not Duel.active and not Tower.active and not Royale.active and not Training.active and not Survivor.active


func _update_tutorial() -> void:
	var guided := Tutorial.guided() and _survival_mode()
	_steps_panel.visible = guided
	if guided:
		var s := Tutorial.current_step()
		_steps_head.text = Tutorial.progress_text()
		_steps_text.text = Tutorial.step_text(s)
	if notices.idle() and director != null and not director.state in ["boss", "duel", "tower", "royale"] and _survival_mode():
		var id := Tutorial.take_card()
		if id != "":
			_show_card(id)


## La fiche de découverte `id` en petite carte : « Compris », « Guide » (à son chapitre), « Plus de conseils ».
func _show_card(id: String) -> void:
	var spec := Tutorial.card_spec(id)
	spec["duration"] = 20.0
	spec["buttons"] = [{"label": "Compris", "kind": "primary"},
			{"label": "Guide", "kind": "plain", "cb": func(): Guide.open_on(get_parent(), id)},
			{"label": "Plus de conseils", "kind": "link", "cb": func():
				Profile.tutorial["cards_off"] = true
				Profile.save_profile()}]
	if Gamepad.active:
		spec["hint"] = "%s : compris · %s : Guide" % [Settings.pad_name(JOY_BUTTON_LEFT_STICK), Settings.pad_name(JOY_BUTTON_RIGHT_STICK)]
	notices.push("news", spec)  # (P0-7 : par la file unique, après les quêtes et jamais sous le bandeau)


func _build_objectives(root: Control) -> void:
	_obj_panel = PanelContainer.new()
	_obj_panel.add_theme_stylebox_override("panel", UiTheme.panel_box(18, 12))
	_obj_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_obj_panel.custom_minimum_size = Vector2(PANEL_W, 0)
	_obj_panel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_left.add_child(_obj_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	_obj_panel.add_child(v)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	v.add_child(head)
	_zone_label = _label(head, "", 16, ACCENT)
	UiTheme.title(_zone_label, 16)
	_zone_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_zone_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART  # un nom long passe à la ligne, il n'est jamais coupé
	_zone_label.custom_minimum_size = Vector2(100, 0)
	_clock_label = _label(head, "", 17, Color.WHITE)
	_clock_label.add_theme_font_override("font", UiTheme.bold_font())
	_clock_label.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var sub := HBoxContainer.new()
	sub.add_theme_constant_override("separation", 10)
	v.add_child(sub)
	_seal_label = _label(sub, "", UiTheme.MIN_TEXT, Color(0.85, 0.75, 1.0))
	_seal_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_seal_label.clip_text = true
	_gold_label = _label(sub, "", UiTheme.MIN_TEXT, Color(1.0, 0.85, 0.35))
	_gold_label.add_theme_font_override("font", UiTheme.bold_font())
	_obj_chevron = _label(sub, "▾", 16, Color(1, 1, 1, 0.55))
	_obj_chevron.mouse_filter = Control.MOUSE_FILTER_PASS  # infobulle : la touche des objectifs
	_obj_details = VBoxContainer.new()
	_obj_details.add_theme_constant_override("separation", 3)
	v.add_child(_obj_details)
	var sep := HSeparator.new()
	sep.add_theme_constant_override("separation", 6)
	var line := StyleBoxLine.new()
	line.color = Color(UiTheme.GOLD_DIM, 0.7)
	line.thickness = 1
	sep.add_theme_stylebox_override("separator", line)
	_obj_details.add_child(sep)
	for i in 5:
		var l := _label(_obj_details, "", UiTheme.MIN_TEXT + 1, Color.WHITE)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(PANEL_W - 36.0, 0)
		_obj_lines.append(l)
	_obj_details.visible = false


func _update_objectives() -> void:
	var rage := director.state == "rage"
	_zone_label.text = _zone_text
	_zone_label.visible = _zone_text != ""
	var t := director.time_left()
	match director.state:
		"royale":
			_clock_label.text = director.royale.clock_text() if director.royale else ""
		"duel":
			_clock_label.text = "Manche %d · %d - %d" % [Duel.round_n, Duel.wins, Duel.losses]
			if PvpCaps.pressure() > 1.05:
				_clock_label.text += " · acharnement ×%.1f" % PvpCaps.pressure()
		"tower":
			_clock_label.text = director.tower.clock_text()  # « Étage 12/200 · Ombre », « Salle 2/4 », Siège : son horloge
		"boss":
			# Survie (passe P11) : temps avant la rage du boss, puis son palier
			_clock_label.text = "BOSS"
			if Run.survival:
				var tier: int = director.boss_rage_tier()
				var left: float = director.boss_rage_next_in()
				rage = tier > 0 or left < 30.0
				_clock_label.text = director.boss_rage_text() if tier > 0 else "BOSS · %d:%02d" % [int(left) / 60, int(left) % 60]
		"cleared":
			_clock_label.text = "Victoire"
		"team":
			# modes d'équipes (lot CO-C) : l'horloge et la ligne viennent du directeur du mode (clock_text, sub_text)
			_clock_label.text = director.team.clock_text() if is_instance_valid(director.team) and director.team.has_method("clock_text") else ""
		"rage":
			_clock_label.text = director.rage_text()
		_:
			_clock_label.text = "⏳ %02d:%02d" % [int(t) / 60, int(t) % 60]
	_clock_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.35) if rage or t < 60.0 else Color.WHITE)
	var need: int = director.SEALS_NEEDED
	var extra := _zone_extra + " · " if _zone_extra != "" else ""  # étape ou niveau, en police ordinaire
	_seal_label.text = extra + "Sceaux  " + "◆ ".repeat(mini(director.seals, need)) + "◇ ".repeat(maxi(0, need - director.seals))
	_gold_label.text = "%d or · %d clé%s" % [Profile.gold, Profile.keys, "s" if Profile.keys > 1 else ""]
	_gold_label.visible = not Modes.hero_match() and not Tower.active and not Training.active  # (lot CO-A : ni en mode d'équipes)
	if Royale.active and director.royale:
		_seal_label.text = "%d / %d en vie · %d élimination%s" % [director.royale.alive_count(), Royale.PLAYERS, Royale.kills, "s" if Royale.kills > 1 else ""]
	if Duel.active:
		# la règle du duel ne se lit qu'avant le premier coup : ensuite le score parle
		_seal_label.text = extra.trim_suffix(" · ") + (" · %s · 2 manches gagnantes" % ClassRival.NAMES[Duel.difficulty].to_lower() if Duel.round_n <= 1 and Duel.wins + Duel.losses == 0 else "")
	if Tower.active:
		_seal_label.text = extra + (("%s · %s" % [Dungeons.name_of(Tower.dungeon), Dungeons.DIFF_NAMES[Tower.dungeon_diff]]) if Tower.is_dungeon() else "%s · record : étage %d" % [Tower.DIFF_NAMES[Tower.difficulty], Tower.best()])
		if director.tower and director.tower.has_method("sub_text"):
			_seal_label.text = extra + director.tower.sub_text()  # Ruée : le boss suivant ; Siège : alliés debout (passe M6)
	if director.state == "team":
		_seal_label.text = director.team.sub_text() if is_instance_valid(director.team) and director.team.has_method("sub_text") else ""
	if director.sv:
		_seal_label.text = extra.trim_suffix(" · ")  # Survivant : les gardiens sont sur la frise (SurvivorHud), pas de sceau
	if Training.active:
		_seal_label.text = ""  # ni minuterie, ni sceaux, ni or : on s'entraîne
		_clock_label.text = ""
	_seal_label.get_parent().visible = _seal_label.text != "" or _gold_label.visible
	# objectifs : le duel, la Tour et l'entraînement n'en ont pas (rien à déplier)
	var has_objectives: bool = not director.state in ["duel", "tower", "team"] and not Training.active
	_obj_chevron.visible = has_objectives
	var chests_total: int = director.map.chests.size() if director.map and "chests" in director.map else 0
	var sig := "%s|%s|%d|%d|%d" % [director.state, director.dungeon_found, director.seals, director.chests_opened, director.shrines_captured]
	if _obj_signature != "" and sig != _obj_signature and HudV2.shows("auto_open"):
		_obj_show_until = _clock + OBJECTIVE_AUTO_SHOW  # nouvelle découverte : on déplie un instant (profil Standard)
	_obj_signature = sig
	var open := has_objectives and (_obj_pinned or _clock < _obj_show_until)
	_obj_details.visible = open
	_obj_chevron.text = "▴" if open else "▾"
	_obj_chevron.tooltip_text = "Objectifs : touche [%s]" % Settings.action_label("objectives", 1)
	if not open:
		return
	var lines: Array[String] = []
	match director.state:
		"royale":
			lines = director.royale.objective_lines() if director.royale else []
		"boss":
			lines = ["⚔ Vaincs le boss du donjon", "Évite les zones rouges ([%s] : esquive)" % Settings.action_label("dodge", 1)]
			if Run.survival:
				lines.append(director.boss_rage_text())  # passe P11 : le combat a une limite de temps
		"cleared":
			lines = ["✔ Boss vaincu : ramasse le butin"]
		_ when director.sv != null:
			lines = director.sv.objective_lines()  # Survivant : gardiens, portail, boss à 20:00
		_:
			lines.append("✔ Entrée du donjon trouvée" if director.dungeon_found else "◇ Trouve le donjon (pilier violet)")
			lines.append("✔ Sceaux réunis : donjon ouvert" if director.seals >= need else "◇ Sceaux %d / %d : forts d'élite" % [director.seals, need])
			lines.append("◇ Coffres %d / %d · %d / %d / %d or" % [director.chests_opened, chests_total,
				director.chest_price(0), director.chest_price(1), director.chest_price(2)])
			var used := 0
			var total := 0
			if director.map:
				for it in director.map.interactables:
					if is_instance_valid(it) and Interactable.STATION_VERBS.has(it.kind):
						total += 1
						used += 1 if it.used else 0
			lines.append("◇ Sanctuaires %d / %d · lieux %d / %d" % [director.shrines_captured,
				director.map.shrines.size() if director.map else 0, used, total])
			lines.append("Rage dans %02d:%02d" % [int(t) / 60, int(t) % 60] if not rage else _rage_line())
	for i in _obj_lines.size():
		var shown := i < lines.size()
		_obj_lines[i].visible = shown
		_obj_lines[i].text = lines[i] if shown else ""
		_obj_lines[i].add_theme_color_override("font_color", Color(0.55, 1.0, 0.6) if shown and lines[i].begins_with("✔") else Color(0.92, 0.9, 0.98))


## Ligne d'objectif en rage : le multiplicateur des monstres et le prochain palier.
func _rage_line() -> String:
	var tier := director.rage_tier()
	var left := director.rage_next_in()
	var now := "Rage : monstres ×%s" % RunDirector.fmt_mult(RunDirector.rage_mult(tier))
	if left < 0.0:
		return now + " : file au boss"
	return now + ", ×%s dans %d:%02d" % [RunDirector.fmt_mult(RunDirector.rage_mult(tier + 1)), int(left) / 60, int(left) % 60]


# --- mini-carte ronde (haut droite) ------------------------------------------------------
func _build_minimap(root: Control) -> void:
	var holder := Control.new()
	holder.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	holder.position = Vector2(-246, 12)
	holder.size = Vector2(230, 230)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(holder)
	_map_holder = holder
	var mask := Control.new()  # découpe ronde : seuls les pixels du disque sont gardés
	mask.size = holder.size
	mask.clip_children = CanvasItem.CLIP_CHILDREN_ONLY
	mask.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mask.draw.connect(func(): mask.draw_circle(mask.size * 0.5, mask.size.x * 0.5 - 6.0, Color.WHITE))
	holder.add_child(mask)
	minimap = Minimap.new()
	minimap.round = true
	minimap.process_mode = Node.PROCESS_MODE_ALWAYS
	minimap.size = holder.size
	mask.add_child(minimap)
	minimap.setup(player, director)
	var ring := HudV2.MapRing.new()  # cadre papier (lot HUD-2) au lieu des anneaux dorés
	ring.size = holder.size
	holder.add_child(ring)
	# compteur de dégâts cumulés : à droite, sous la mini-carte (chiffre soleil en Mochiy contouré d'encre, jauge des 3 s)
	var ink := UiTheme.color("encre.700")
	_dmg_box = VBoxContainer.new()
	_dmg_box.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_dmg_box.position = Vector2(-260, 256)
	_dmg_box.grow_horizontal = Control.GROW_DIRECTION_BEGIN  # (lot DNG-1 : un grand nombre l'élargit vers la gauche, jamais hors de l'écran)
	_dmg_box.custom_minimum_size = Vector2(240, 0)
	_dmg_box.alignment = BoxContainer.ALIGNMENT_END
	_dmg_box.add_theme_constant_override("separation", 2)
	_dmg_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_dmg_box)
	var cap := _label(_dmg_box, "Dégâts cumulés", UiTheme.MIN_TEXT + 1, UiTheme.color("papier.100"))
	cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_dmg_value = _label(_dmg_box, "", 36, UiTheme.color("bonbon.soleil.clair"))
	_dmg_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	UiTheme.title(_dmg_value, 36, UiTheme.color("bonbon.soleil.clair"))
	_dmg_value.pivot_offset = Vector2(240, 26)
	_dmg_bar = ColorRect.new()
	_dmg_bar.color = UiTheme.color("bonbon.soleil.base")
	_dmg_bar.custom_minimum_size = Vector2(240, 4)
	_dmg_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dmg_box.add_child(_dmg_bar)
	_dmg_best = _label(_dmg_box, "", UiTheme.MIN_TEXT, UiTheme.color("papier.100"))
	_dmg_best.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	for l in [cap, _dmg_best]:
		l.add_theme_font_override("font", UiTheme.bold_font())
		l.add_theme_constant_override("outline_size", 6)
		l.add_theme_color_override("font_outline_color", ink)
	_dmg_box.modulate.a = 0.0

	_fps_label = _label(root, "", UiTheme.MIN_TEXT, Color(1, 1, 1, 0.6))
	_fps_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_fps_label.position = Vector2(-150, 244)


# --- cible (haut centre) -----------------------------------------------------------------
func _build_target(root: Control) -> void:
	_target_box = PanelContainer.new()
	_target_box.add_theme_stylebox_override("panel", UiTheme.panel_box(18, 10))
	_target_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_target_box.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_target_box.position = Vector2(-190, 12)
	_target_box.custom_minimum_size = Vector2(380, 0)
	root.add_child(_target_box)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	_target_box.add_child(v)
	var head := HBoxContainer.new()
	v.add_child(head)
	_target_name = _label(head, "", 16, Color.WHITE)
	_target_name.add_theme_font_override("font", UiTheme.bold_font())
	_target_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_target_tag = _label(head, "", UiTheme.MIN_TEXT, ACCENT)
	var bars := Control.new()
	_target_bars = bars
	bars.custom_minimum_size = Vector2(0, 18)
	v.add_child(bars)
	_target_trail = _bar(bars, Color(UiTheme.color("papier.100"), 0.75), 18)  # trace claire des dégâts
	_target_trail.set_anchors_preset(Control.PRESET_FULL_RECT)
	_target_bar = _bar(bars, UiTheme.color("bonbon.fraise.base"), 18)
	_target_bar.set_anchors_preset(Control.PRESET_FULL_RECT)
	_target_bar.add_theme_stylebox_override("background", StyleBoxEmpty.new())
	# boss : repère de la 2e phase (à mi-vie, il entre en fureur), deux encoches dorées en haut et en bas de la grande
	# barre (le texte des PV reste lisible entre elles)
	_target_phase = Control.new()
	_target_phase.set_anchors_preset(Control.PRESET_FULL_RECT)
	_target_phase.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_target_phase.visible = false
	bars.add_child(_target_phase)
	for bottom in [false, true]:
		var notch := ColorRect.new()
		notch.color = Color(1.0, 0.85, 0.4)
		notch.anchor_left = BossBrain.PHASE2_AT
		notch.anchor_right = BossBrain.PHASE2_AT
		notch.anchor_top = 1.0 if bottom else 0.0
		notch.anchor_bottom = notch.anchor_top
		notch.offset_left = -1.5
		notch.offset_right = 1.5
		notch.offset_top = -6.0 if bottom else 0.0
		notch.offset_bottom = 0.0 if bottom else 6.0
		notch.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_target_phase.add_child(notch)
	_target_hp = _label(bars, "", UiTheme.MIN_TEXT, Color.WHITE)
	_target_hp.set_anchors_preset(Control.PRESET_FULL_RECT)
	_target_hp.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_target_hp.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_target_hp.add_theme_constant_override("outline_size", 4)
	_target_hp.add_theme_color_override("font_outline_color", Color(0.05, 0.02, 0.05))
	_target_row = HudWidgets.StatusRow.new(false, 24.0, false)
	_target_row.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(_target_row)
	_target_box.visible = false


# --- barre d'action (bas) ----------------------------------------------------------------
## Repères de la barre d'action v2 (lot HUD-2) dans son cadre de 900 × 196 ancré en bas au centre (haut à 204 px du bas).
const SLOT := 62.0
const SLOT_Y := 96.0  # haut des cases (au-dessus : effets, puis les icônes d'enchaînement et la barre du bon timing)
const POTION_X := 96.0
const SKILL_X := 216.0
const SKILL_STEP := 72.0
const LEVEL_X := 630.0  # barre de niveau (pastille, jauge) et niveau d'aide
const LIFE_X := 96.0
const LIFE_W := 724.0
const LIFE_Y := 172.0  # jauge de vie, sous les touches dessinées


func _build_action_bar(root: Control) -> void:
	var bottom := Control.new()
	bottom.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	bottom.position = Vector2(-450, -204)
	bottom.size = Vector2(900, 196)
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bottom)
	_action_root = bottom
	# lot HUD-2 (croquis BM-HUB, P0-8) : plus de panneau ni de globes ; rangée de cases autocollantes (potions, sorts,
	# esquive, arme rangée) avec la touche dessinée dessous, barre de niveau à droite, vie en jauge large tout en bas
	# (comme le Survivant : les icônes d'enchaînement, au-dessus des cases, ne la cachent jamais). Repères dans 900 × 196.
	for i in 2:
		var ps := HudWidgets.PotionSlot.new()
		ps.position = Vector2(POTION_X + i * 56.0, SLOT_Y + 6.0)
		ps.size = Vector2(50, 50)
		bottom.add_child(ps)
		_potion_slots.append(ps)
	for i in 4:
		var s := HudWidgets.SkillSlot.new()
		s.position = Vector2(SKILL_X + i * SKILL_STEP, SLOT_Y)
		s.size = Vector2(SLOT, SLOT)
		bottom.add_child(s)
		_slots.append(s)
	var after := SKILL_X + 4 * SKILL_STEP
	_dodge = HudWidgets.SkillSlot.new()
	_dodge.round = true
	_dodge.empty = false
	_dodge.icon = UiTheme.texture("res://assets/ui/status/haste.png")
	_dodge.position = Vector2(after, SLOT_Y + 3.0)
	_dodge.size = Vector2(56, 56)
	_dodge.tooltip_text = "Esquive (invulnérable)"
	bottom.add_child(_dodge)
	_swap = HudWidgets.SkillSlot.new()  # arme rangée (lot N2) : s'éclaire à chaque échange
	_swap.round = true
	_swap.empty = false
	_swap.ready_tone = "lagon"
	_swap.position = Vector2(after + 66.0, SLOT_Y + 9.0)
	_swap.size = Vector2(44, 44)
	_swap.visible = false
	bottom.add_child(_swap)
	_queue_strip = HudWidgets.QueueStrip.new()
	_queue_strip.position = Vector2(after, SLOT_Y - 34.0)
	bottom.add_child(_queue_strip)
	_xp_orb = HudV2.LevelBar.new()
	_xp_orb.position = Vector2(LEVEL_X, SLOT_Y + 2.0)
	_xp_orb.size = Vector2(LIFE_X + LIFE_W - LEVEL_X, 50)
	bottom.add_child(_xp_orb)
	_assist_label = Hud._label(bottom, "", UiTheme.MIN_TEXT, Color.WHITE)  # niveau d'aide (« Assisté ») : étiquette à droite de la pastille
	_assist_label.add_theme_font_override("font", UiTheme.bold_font())
	_assist_label.add_theme_color_override("font_outline_color", UiTheme.color("encre.700"))
	_assist_label.add_theme_constant_override("outline_size", 5)
	_assist_label.position = Vector2(LEVEL_X + 92.0, SLOT_Y + 4.0)
	_assist_label.size = Vector2(LIFE_X + LIFE_W - LEVEL_X - 92.0, 24)
	_assist_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_assist_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hp_orb = HudV2.LifeGauge.new()
	_hp_orb.position = Vector2(LIFE_X, LIFE_Y)
	_hp_orb.size = Vector2(LIFE_W, HudV2.LifeGauge.H)
	bottom.add_child(_hp_orb)
	_buff_row = HudWidgets.StatusRow.new(true)
	_buff_row.position = Vector2(150, 0)
	_buff_row.size = Vector2(296, 54)
	bottom.add_child(_buff_row)
	_debuff_row = HudWidgets.StatusRow.new(false)
	_debuff_row.alignment = BoxContainer.ALIGNMENT_END
	_debuff_row.position = Vector2(454, 0)
	_debuff_row.size = Vector2(LIFE_X + LIFE_W - 454.0, 54)
	bottom.add_child(_debuff_row)


## Cases de potions (soin, effet) : icône, nombre, recharge, touche.
func _refresh_potions() -> void:
	for i in 2:
		var ps: HudWidgets.PotionSlot = _potion_slots[i]
		ps.visible = Potions.allowed()
		var kind := Potions.kind_for_slot(i + 1)
		ps.key_text = Settings.action_label("potion_%d" % (i + 1), 1)
		ps.empty = kind == ""
		if kind == "":
			ps.icon = null
			ps.count = 0
			ps.tooltip_text = "Potion d'effet (%s) : aucune. Élan, rage et acuité se trouvent dans les coffres, les débris et sur les élites." % ps.key_text
			ps.set_cooldown(Potions.cooldown_left("boost"), Potions.COOLDOWN)
			continue
		var def: Dictionary = Potions.KINDS[kind]
		ps.icon = UiTheme.texture(Potions.icon_path(kind))
		ps.count = Potions.count(kind)
		ps.tint = def.color
		ps.tooltip_text = "%s (%s) — %s\nRecharge : %d s, commune aux potions %s." % [def.name, ps.key_text, def.desc, int(Potions.COOLDOWN), "de soin" if kind == "heal" else "d'effet"]
		ps.set_cooldown(Potions.cooldown_left(String(def.group)), Potions.COOLDOWN)


func _refresh_skills() -> void:
	for i in 4:
		var s := player.skill_in_slot(i)
		var slot := _slots[i]
		slot.key_text = Settings.action_label("skill_%d" % (i + 1), 1)
		slot.auto = Settings.auto_skill(i) and not s.is_empty()  # « AUTO » sur une case vide ne dit rien
		slot.empty = s.is_empty()
		slot.icon = null if s.is_empty() else UiTheme.texture(String(s.icon))
		slot.rank = Run.skill_rank(int(s.id)) if not s.is_empty() else 1
		slot.level_badge = slot.rank if Survivor.active and not s.is_empty() else 0  # Survivant : niveau 1 à 10 en chiffre
		slot.chain_slots = Run.MAX_CHAIN if Survivor.active and not s.is_empty() else 0  # Survivant : grille 4 × 3 (lot SVX-2)
		slot.key_sticker = true  # touche dessinée en pastille sous chaque case (lot SVX-2, partout depuis HUD-2)
		slot.chain_icons = Run.chain_of(i).map(func(e): return UiTheme.texture(String(Run.skill_def(int(e.id)).get("icon", ""))))
		if s.is_empty():
			slot.tooltip_text = "Emplacement libre"
		else:
			slot.tooltip_text = "%s — %s %d\n%s\nRecharge : %.1f s" % [s.name, "niveau" if Survivor.active else "rang", slot.rank, s.desc, player.skill_cooldown(s)]
			for j in Run.chain_of(i).size():
				slot.tooltip_text += "\n%s Enchaînement %d : %s (rappuie sur la touche : l'appui est gardé et le coup part dès qu'il peut)" % ["➜", j + 1, Run.skill_def(int(Run.chain_of(i)[j].id)).get("name", "?")]
	_dodge.key_text = Settings.action_label("dodge", 1)


func _process(delta: float) -> void:
	if player == null:
		return
	if _better_box.visible and Time.get_ticks_msec() / 1000.0 > _better_until:
		_better_box.visible = false
	_root.visible = not _menu_open()
	if not _root.visible:
		return
	_clock += delta
	notices.tick()
	_layout_right()
	if not _feed_wait.is_empty() and not banner_up() and _feed_room() > 0:
		var waiting := _feed_wait.duplicate()
		_feed_wait.clear()
		for t in waiting:
			feed(String(t[0]), t[1])
	_refresh_potions()
	_update_damage_counter(delta)
	_update_kill_feed()
	# vie basse : bords de l'écran qui pulsent en rouge
	var hp_ratio := player.hp / maxf(player.max_hp, 1.0)
	_low_hp.modulate.a = 0.0 if hp_ratio >= 0.3 or player.is_dead else (0.5 + 0.5 * (1.0 - hp_ratio / 0.3)) * (0.65 + 0.35 * sin(_clock * 6.0))
	_fps_label.visible = Settings.get_v("interface", "show_fps")
	_fps_label.text = "%d FPS" % Engine.get_frames_per_second()
	for i in 4:
		var s := player.skill_in_slot(i)
		_slots[i].set_cooldown(player.cooldown_left(i), player.skill_cooldown(s) if not s.is_empty() else 1.0)
		# enchaînement : l'icône du sort suivant prend la place, petite recharge, puis la barre
		var st := player.chain_state(i)
		var ch: Array = Run.chain_of(i)
		if st.is_empty():
			_slots[i].chain_bar = -1.0
			_slots[i].chain_ready = false
			if not s.is_empty():
				_slots[i].icon = UiTheme.texture(String(s.icon))
			_slots[i].chain_icons = ch.map(func(e): return UiTheme.texture(String(Run.skill_def(int(e.id)).get("icon", ""))))
		else:
			_slots[i].icon = UiTheme.texture(String(st.next.get("icon", "")))
			var at := ch.map(func(e): return int(e.id)).find(int(st.next.id))
			_slots[i].chain_icons = ch.slice(at + 1).map(func(e): return UiTheme.texture(String(Run.skill_def(int(e.id)).get("icon", ""))))
			_slots[i].chain_zone = Player.CHAIN_ZONE
			if st.phase == "lock":
				_slots[i].set_cooldown(float(st.left), float(st.get("total", Player.CHAIN_DELAY)))
				_slots[i].chain_bar = 0.0
				_slots[i].chain_ready = false
			else:
				_slots[i].set_cooldown(0.0, 1.0)
				_slots[i].chain_bar = float(st.p)
				_slots[i].chain_ready = player.chain_ready(i)
	# mémoire des touches : appuis gardés sur les cases (suite d'un enchaînement) ou en pastilles
	var kept := player.queue_view()
	var waiting: Array = []
	for i in 4:
		var n := 0
		for e in kept:
			if int(e.slot) == i and e.chain:
				n += 1
		var open: bool = not player.chain_state(i).is_empty()
		_slots[i].queued_main = open and n >= 1
		_slots[i].queued_icons = maxi(n - 1, 0) if open else n
	for e in kept:
		if not e.chain:
			waiting.append({"icon": UiTheme.texture(String(player.skill_in_slot(int(e.slot)).get("icon", ""))),
				"key": Settings.action_label("skill_%d" % (int(e.slot) + 1), 1)})
	_queue_strip.set_items(waiting)
	var lv := Settings.assist_level()
	var info: Dictionary = Settings.ASSIST.get(lv, {})
	# niveau d'aide en mots du jeu (« Assisté », « Pilote auto » ; lot HUD-2) ; rien en Manuel ; Battle royale : pas de mot technique
	_assist_label.text = String(info.get("name", "")) if String(info.get("tag", "")) != "" and not Royale.active else ""
	_assist_label.add_theme_color_override("font_color", info.get("color", Color.WHITE))
	var dc := player.dodge_cooldown()
	_dodge.set_cooldown(dc.x, dc.y)
	_update_swap()
	_update_tutorial()
	_update_statuses()
	_update_target()
	_update_objectives()
	_update_arrow()
	# choix de carte ouvert : la pile de gauche et la cible se retirent (elles se mêlent au titre et aux cartes) ;
	# la barre d'action, la vie et la mini-carte restent
	var w := get_parent()
	var picking: bool = w != null and w.get("cards") != null and w.cards.is_open()
	_left.visible = not picking
	_cards.visible = not picking  # la fiche attend (son compte à rebours aussi) que le choix de carte soit fini
	if picking:
		_target_box.visible = false
		if _boss_bar != null:
			_boss_bar.hide_all()


# --- buffs / debuffs -----------------------------------------------------------------------
func _update_statuses() -> void:
	var buffs: Array = []
	var debuffs: Array = []
	for st in player.statuses:
		var left := float(player.statuses[st]) - player.clock
		if left <= 0.0 or not Combatant.STATUS_INFO.has(st):
			continue
		var e := {"id": st, "left": left, "total": _total("p", st, float(player.statuses[st]), left)}
		if StatusDb.is_buff(st):
			buffs.append(e)
		else:
			debuffs.append(e)
	var flow := player.flow_state()
	if flow.x > 0:
		buffs.append({"id": "flow", "left": flow.y, "total": 3.0, "stacks": int(flow.x)})
	var stun := player.stun_left()
	if stun > 0.0:
		debuffs.append({"id": "stun", "left": stun, "total": _total("p", "stun_state", player.clock + stun, stun)})
	_buff_row.sync(buffs)
	_debuff_row.sync(debuffs)


## Durée totale d'un effet (pour le balayage) : retenue quand il apparaît ou est prolongé.
func _total(who: String, st: String, end: float, left: float) -> float:
	var key := who + ":" + st
	var rec: Array = _durations.get(key, [-1.0, 1.0])
	if absf(end - float(rec[0])) > 0.05:
		rec = [end, maxf(left, 0.1) if end > float(rec[0]) else float(rec[1])]
		_durations[key] = rec
	return float(rec[1])


# --- cible -------------------------------------------------------------------------------
func _update_target() -> void:
	var t := player.current_target()
	# combat de boss : la barre reste sur le boss (pas sur ses renforts)
	var boss = director.get("_boss") if director else null
	if boss and is_instance_valid(boss) and not boss.is_dead:
		t = boss
	if t == null:
		t = player.nearest_monster(9.0)
	if t != null and not SurvivorDirector.shows_target_bar(t):
		t = null  # Survivant (lot SVX-1) : face à une horde, la barre ne sert qu'aux élites, géants et boss
	if t != null and TeamMatch.active and not t.visible:
		t = null  # (lot TAC-2, L'Assaut) un adversaire caché par le brouillard n'a pas de barre
	if _boss_bar != null and _boss_bar.show_for(t, director):  # boss : barre de boss v2 (lot DNG-2)
		_target_box.visible = false
		return
	if t == null:
		_target_box.visible = false
		return
	var prev: Object = _target_ref.get_ref() if _target_ref else null
	var ratio := t.hp / maxf(t.max_hp, 1.0)
	if prev != t:
		_target_ref = weakref(t)
		_target_trail.value = ratio
	_target_box.visible = true
	_target_name.text = t.display_name.trim_prefix("<Boss> ").trim_prefix("<Duel> ")
	var m := t as Monster
	_set_target_big(m != null and m.is_boss)
	_target_phase.visible = m != null and m.brain != null and ratio > BossBrain.PHASE2_AT
	var tag := "Nv %d" % t.level
	if Combatant.is_hero(t):
		tag = "Adversaire · " + tag  # duel, Tour : un héros, pas une élite
	elif m and m.is_boss:
		tag = "BOSS · " + tag
	elif m and m.is_elite:
		tag = "Élite · " + tag
	_target_tag.text = tag
	_target_tag.add_theme_color_override("font_color", Color(0.85, 0.45, 1.0) if m and m.is_boss else (Color(1.0, 0.6, 0.2) if m and m.is_elite else ACCENT))
	_target_bar.max_value = 1.0
	_target_trail.max_value = 1.0
	_target_bar.value = ratio
	_target_hp.text = "%s / %s" % [_big_number(minf(ceilf(t.hp), ceilf(t.max_hp))), _big_number(ceilf(t.max_hp))]  # (jamais « 39 045 / 39 044 »)
	if _target_trail.value > ratio:
		_target_trail.value = move_toward(_target_trail.value, ratio, get_process_delta_time() * 0.5)
	else:
		_target_trail.value = ratio
	var effects: Array = []
	var id := str(t.get_instance_id())
	for st in t.statuses:
		var left := float(t.statuses[st]) - t.clock
		if left > 0.0 and Combatant.STATUS_INFO.has(st) and not String(st).begins_with("imm_"):  # pas les insensibilités
			effects.append({"id": st, "left": left, "total": _total(id, st, float(t.statuses[st]), left)})
	_target_row.sync(effects)


## Un boss a un cadre plus large, une barre plus haute et un nom plus grand que les autres cibles.
func _set_target_big(big: bool) -> void:
	# large de 560 px, mais jamais sur la pile de gauche ni sur la mini-carte (écran de 1280 : 500 px)
	var w := clampf(get_viewport().get_visible_rect().size.x - 2.0 * (PANEL_W + 30.0), 380.0, 560.0) if big else 380.0
	if big == _target_big and is_equal_approx(w, _target_w):
		return
	_target_big = big
	_target_w = w
	_target_box.custom_minimum_size.x = w
	_target_box.offset_left = -w * 0.5  # (ancré au centre : des décalages, pas une position)
	_target_box.offset_right = w * 0.5
	_target_bars.custom_minimum_size.y = 26.0 if big else 18.0
	_target_name.add_theme_font_size_override("font_size", 21 if big else 16)
	_target_hp.add_theme_font_size_override("font_size", 16 if big else UiTheme.MIN_TEXT)
	_target_box.reset_size()


## Menu pause, marchand ou bilan ouvert : le HUD laisse la place (le choix de cartes le garde).
func _menu_open() -> bool:
	if not get_tree().paused:
		return false
	if not get_tree().get_nodes_in_group("results_panel").is_empty():
		return true  # bilan de fin de partie : rien du HUD ne doit se lire à travers
	var w := get_parent()
	for key in ["pause_menu", "merchant_ui"]:
		var menu = w.get(key) if w else null
		if menu and menu.has_method("is_open") and menu.is_open():
			return true
	return false


func _unhandled_input(event: InputEvent) -> void:
	if get_tree().paused:
		return
	if _pad_card_input(event):
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("journal") and not Training.active:
		# Journal des quêtes (lot HUB-1, P0-5) : le jeu attend qu'on le referme ; ni « Y aller » ni Défi du jour en partie
		get_viewport().set_input_as_handled()
		QuestJournal.open_on(get_parent(), 0, Callable(), Callable(), true)
		return
	if event.is_action_pressed("map") and _royale != null:
		_royale.toggle_map()  # Battle royale : grande carte v2 (lot BR-I1)
	elif event.is_action_pressed("map"):
		_big_map.visible = not _big_map.visible
		if _big_map.visible:
			hide_banner()
	elif event.is_action_pressed("objectives"):
		_obj_pinned = not _obj_pinned
		_obj_show_until = 0.0


## Flèche autour du héros pointant vers l'objectif.
func _update_arrow() -> void:
	var target := director.objective_target()
	var cam := get_viewport().get_camera_3d()
	if target == Vector3.INF or cam == null:
		_arrow.visible = false
		return
	var to := target - player.global_position
	to.y = 0.0
	if to.length() < 8.0:
		_arrow.visible = false
		return
	var local := to.rotated(Vector3.UP, -cam.global_rotation.y)
	var dir := Vector2(local.x, local.z).normalized()
	var center := cam.unproject_position(player.global_position + Vector3.UP * 1.0)
	_arrow.visible = true
	_arrow.position = center + dir * 90.0 - _arrow.pivot_offset
	_arrow.rotation = dir.angle() + PI / 2.0


## Battle royale (passe M1) : fil des éliminations sous la mini-carte, les 4 dernières lignes, 8 s chacune.
var _feed_box: VBoxContainer
var _feed_sig := ""
var _action_root: Control  # barre du bas (vie, sorts, niveau) : cachée quand le joueur éliminé regarde la fin


func _update_kill_feed() -> void:
	if not Royale.active or director == null or director.royale == null:
		if _feed_box:
			_feed_box.visible = false
		if _drop_box:
			_drop_box.visible = false
		return
	if _feed_box == null:
		_feed_box = VBoxContainer.new()
		_feed_box.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		_feed_box.position = Vector2(-372, 252)
		_feed_box.custom_minimum_size = Vector2(356, 0)
		_feed_box.add_theme_constant_override("separation", 2)
		_feed_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_root.add_child(_feed_box)
	if _action_root:
		_action_root.visible = not director.royale.spectating
	_update_drop_hint()
	if _royale != null:
		_feed_box.visible = false  # (lot BR-I1 : le fil est en pastilles sous la mini-carte, RoyaleHud)
		return
	var now: float = director.royale.clock
	var lines: Array = director.royale.kill_feed.filter(func(e): return now - float(e[1]) < 8.0)
	_feed_box.visible = not lines.is_empty()
	var sig := str(lines)
	if sig == _feed_sig:
		return
	_feed_sig = sig
	for c in _feed_box.get_children():
		c.queue_free()
	for e in lines:
		var t := String(e[0])
		var mine := t.begins_with("Tu ")
		var l := _label(_feed_box, t, UiTheme.MIN_TEXT, Color(1.0, 0.85, 0.4) if mine else Color(0.93, 0.9, 0.98))
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		l.add_theme_constant_override("outline_size", 5)
		l.add_theme_color_override("font_outline_color", Color(0.05, 0.02, 0.08, 0.95))


## Battle royale, largage et retour (lot BR4) : une ligne au centre en bas (« [Espace] Sauter », « retour dans 4 s »).
var _drop_box: PanelContainer
var _drop_label: Label


func _update_drop_hint() -> void:
	var text: String = director.royale.drop_hint()
	if _drop_box == null:
		if text == "":
			return
		_drop_box = PanelContainer.new()
		_drop_box.add_theme_stylebox_override("panel", UiTheme.flat_box(Color(0.06, 0.04, 0.1, 0.88), UiTheme.GOLD, 2, 18))
		_drop_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_drop_box.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
		_drop_box.position = Vector2(0, -340)
		_root.add_child(_drop_box)
		_drop_label = _label(_drop_box, "", 22, Color(1.0, 0.92, 0.7))
		_drop_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_drop_box.visible = text != "" and not (_royale != null and _royale.map_open())  # (la grande carte du vol dit déjà tout)
	if text == _drop_label.text:
		return
	_drop_label.text = text
	_drop_box.reset_size()
	_drop_box.offset_left = -_drop_box.size.x * 0.5
	_drop_box.offset_right = _drop_box.size.x * 0.5


## Compteur de dégâts cumulés : grossit à chaque coup, la barre montre les 3 s avant la remise
## à zéro ; le record de la run et le record absolu en dessous.
func _update_damage_counter(delta: float) -> void:
	var now := Run.combo_now()
	if not _dmg_room and _dmg_allowed():
		_dmg_box.modulate.a = 0.0  # une carte a pris sa place (petit écran) : il s'efface tout de suite, sans la chevaucher
	if not _dmg_allowed() or not _dmg_room or now <= 0.0:  # (profil, place dans la colonne de droite : lot HUD-2)
		_dmg_box.modulate.a = move_toward(_dmg_box.modulate.a, 0.0, delta * 2.0)
		_dmg_shown = 0.0
		return
	_dmg_box.modulate.a = 1.0
	if now > _dmg_shown:
		_dmg_value.scale = Vector2.ONE * minf(1.25, 1.0 + (now - _dmg_shown) / maxf(now, 1.0) * 2.0)
	_dmg_shown = lerpf(_dmg_shown, now, minf(1.0, delta * 12.0))
	_dmg_value.scale = _dmg_value.scale.move_toward(Vector2.ONE, delta * 2.0)
	_dmg_value.text = _big_number(_dmg_shown)
	_dmg_bar.custom_minimum_size.x = 240.0 * Run.combo_left()
	var best := maxf(Run.combo_best, float(Profile.records.get("best_combo", 0.0)))
	_dmg_best.text = "record %s" % _big_number(best) if best <= Run.combo_best else "record %s  ·  partie %s" % [_big_number(best), _big_number(Run.combo_best)]


## Le compteur de dégâts a-t-il un sens ici ? Pas en duel (coups plafonnés), ni en Battle royale (fil des éliminations), ni
## au Survivant (bruit face à une horde, lot SVX-2) ; seulement dans le profil Standard (lot HUD-2).
func _dmg_allowed() -> bool:
	return not (Modes.hero_match() or Survivor.active) and HudV2.shows("dmg")  # (lot CO-A : ni en mode d'équipes)


## Colonne de droite (lot HUD-2) : mini-carte, compteur de dégâts, carte de notification, fil du butin, chacun sous le
## précédent et jamais sur la barre d'action. Sur un petit écran, une carte passe avant le compteur de dégâts (il s'efface
## le temps qu'elle est là) et le fil du butin attend qu'il y ait la place (Hud.feed). Battle royale : sa propre colonne.
func _layout_right() -> void:
	if _royale != null or _map_holder == null or _cards == null:
		return
	var limit := _action_root.position.y - 6.0  # haut de la barre d'action (ses effets compris)
	var y := _map_holder.offset_top + (_map_holder.size.y + 14.0 if _map_holder.visible else 0.0)
	var card_h := _cards._box.size.y if _cards.count() > 0 else 0.0
	var dmg_h := maxf(DMG_H, _dmg_box.size.y + 8.0)
	_dmg_room = _dmg_allowed() and (card_h <= 0.0 or y + dmg_h + card_h <= limit)
	if _dmg_room:
		if not is_equal_approx(_dmg_box.offset_top, y):
			_dmg_box.offset_top = y
			_dmg_box.offset_bottom = y
		y += dmg_h
	if not is_equal_approx(y, _cards_top):
		_cards_top = y
		_cards.place(y, 14.0, false)
	if _loot != null:
		var top := y + (card_h + 10.0 if card_h > 0.0 else 0.0)
		if not is_equal_approx(_loot.offset_top, top):
			_loot.offset_top = top
			_loot.offset_bottom = top
		# une carte arrivée après le butin : les lignes qui n'ont plus la place se cachent (les plus anciennes d'abord)
		var room := _feed_room()
		var n := _feed.get_child_count()
		var changed := false
		for i in n:
			var c := _feed.get_child(i) as CanvasItem
			if c.visible != (i >= n - room):
				c.visible = i >= n - room
				changed = true
		if changed:
			_feed.reset_size()


## Lignes du fil du butin qui ont la place (profil, colonne de droite) ; 0 : la ligne attend (ou n'est pas montrée).
func _feed_room() -> int:
	if _loot == null:
		return 3 if Royale.active else HudV2.loot_lines()  # (pile de gauche : comme avant)
	var limit := _action_root.position.y - 6.0
	return mini(HudV2.loot_lines(), maxi(0, int((limit - _loot.offset_top + 6.0) / FEED_LINE_H)))


static func _big_number(v: float) -> String:
	var s := str(roundi(v))
	var out := ""
	for i in s.length():
		if i > 0 and (s.length() - i) % 3 == 0:
			out += " "
		out += s[i]
	return out


## Case de l'arme rangée (passe N2) : son icône, la touche « Changer d'arme », la recharge ; cachée sans arme secondaire.
func _update_swap() -> void:
	var it := player.stowed_item()
	_swap.visible = not it.is_empty()
	if it.is_empty():
		return
	_swap.icon = UiTheme.texture(String(it.get("icon", "")))
	_swap.key_text = Settings.action_label("swap_weapon", 1)
	_swap.tooltip_text = "Changer d'arme (%s) : prendre en main %s" % [_swap.key_text, Items.display_name(it)]
	_swap.set_cooldown(player.swap_left(), player.swap_cooldown())


## Survie : arme trouvée rangée dans le sac (passe N2) ; 8 s pour l'équiper avec [G] (principale si elle est du type
## de la classe, sinon secondaire). [param item] vide : sac plein, l'arme est perdue.
func show_bagged(item: Dictionary) -> void:
	if item.is_empty():
		show_message("Sac plein : l'arme trouvée est perdue", 2.0)
		return
	better_item = item
	_better_until = Time.get_ticks_msec() / 1000.0 + 8.0
	var where := "arme principale" if Profile.can_be_main(item) else "arme secondaire"
	_better_label.text = "[img=34x34]%s[/img]  [b][color=#%s]%s[/color][/b]\n[color=#c8c8d4]Dans ton sac — [b]%s[/b] : équiper en %s[/color]" % [
		String(item.get("icon", "")), Items.color_of(item).to_html(false), Items.display_name(item), Settings.action_label("quick_equip", 1), where]
	_better_box.visible = true


## Objet ramassé meilleur que la pièce portée : 8 s pour l'équiper avec [G].
func show_better(item: Dictionary) -> void:
	better_item = item
	if not Royale.active and Time.get_ticks_msec() - _better_ms > 1500:  # son de rareté (lot SND-2), pas deux de suite
		_better_ms = Time.get_ticks_msec()
		UiFeel.reward_cue(int(item.get("rarity", 0)), -10.0)
	_better_until = Time.get_ticks_msec() / 1000.0 + 8.0
	var c := Items.compare_to_equipped(item)
	_better_label.text = "[img=34x34]%s[/img]  [b][color=#%s]%s[/color][/b]  [color=#7fe08a]▲ %+d %%[/color]\n[color=#c8c8d4]Meilleur que ta pièce portée — [b]%s[/b] : équiper[/color]" % [
		String(item.get("icon", "")), Items.color_of(item).to_html(false), Items.display_name(item), roundi(c * 100.0), Settings.action_label("quick_equip", 1)]
	_better_box.visible = true


## [G] : équipe l'objet signalé (s'il est encore dans le sac).
func quick_equip() -> bool:
	if better_item.is_empty() or not _better_box.visible:
		return false
	if Profile.inventory.any(func(x): return is_same(x, better_item)):
		Profile.equip(better_item)
		show_message("Équipé : %s" % Items.display_name(better_item), 1.5)
	better_item = {}
	_better_box.visible = false
	return true


func show_prompt(text: String) -> void:
	_prompt.text = text
	_prompt_box.visible = text != ""
	_prompt_box.reset_size()
	# ancré en bas au centre : décalages relatifs à l'ancre
	_prompt_box.offset_left = -_prompt_box.size.x * 0.5
	_prompt_box.offset_right = _prompt_box.size.x * 0.5


func show_message(text: String, duration: float) -> void:
	text = text.replace("<Boss> ", "").replace("<Duel> ", "")  # (les noms de combattants portent une étiquette interne)
	if _boss_bar != null and _boss_bar.take_message(text, duration):
		return  # annonce d'une mécanique du boss : alerte à 3 niveaux (HudAlert, lot DNG-2)
	if _moba != null and _moba.announce_message(text, duration):
		return  # Les Deux Voies : annonces du mode une à la fois (lot MB-H)
	if _royale != null and _royale.announce_message(text, duration):
		return  # Battle royale : annonces centrales une à la fois, DA v2 (lot BR-I3, RoyaleAnnounce)
	if _assault != null and _assault.announce_message(text, duration):
		return  # L'Assaut : annonces du mode (lot TAC-7, AssaultAnnounce)
	for pre in FEED_PREFIXES:
		if text.begins_with(pre) and not text.contains("\n"):
			feed(text)
			return
	var lines := text.split("\n", false, 1)
	_center_label.text = lines[0] if not lines.is_empty() else ""
	_center_sub.text = lines[1] if lines.size() > 1 else ""
	_fit_banner()
	_center_sub.visible = lines.size() > 1
	if _msg_tween:
		_msg_tween.kill()
	_banner.modulate.a = 0.0
	_banner.reset_size()
	_center_banner()
	_banner.pivot_offset = _banner.get_combined_minimum_size() * 0.5
	_settle_banner()
	_banner.scale = Vector2(1.06, 1.06)
	_msg_tween = create_tween()
	_msg_tween.set_parallel()
	_msg_tween.tween_property(_banner, "modulate:a", 1.0, 0.18)
	_msg_tween.tween_property(_banner, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_msg_tween.chain().tween_interval(duration)
	_msg_tween.chain().tween_property(_banner, "modulate:a", 0.0, 0.5)


## Bandeau centré sur l'écran quelle que soit sa largeur (reset_size garde le bord gauche, lot DNG-1).
func _center_banner() -> void:
	var w := maxf(_banner.size.x, _banner.get_combined_minimum_size().x)
	_banner.offset_left = -w * 0.5
	_banner.offset_right = w * 0.5


## Largeur du bandeau d'annonce (lot DNG-1) : jamais plus que l'espace entre la mini-carte et le bord gauche, centré ; un
## titre trop long (une intro de boss en une ligne) passe à la ligne au lieu de sortir de l'écran.
func _fit_banner() -> void:
	var vw := get_viewport().get_visible_rect().size.x if is_inside_tree() else 1600.0
	var room := clampf(vw - 2.0 * BANNER_SIDE, 460.0, BANNER_MAX)
	var inner := room - 60.0  # marges de l'autocollant (26 de chaque côté, contour compris ; lot HUD-2)
	var font := _center_label.get_theme_font("font")
	var fs := _center_label.get_theme_font_size("font_size")
	var wide := font != null and font.get_string_size(_center_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > inner
	_center_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if wide else TextServer.AUTOWRAP_OFF
	_center_label.custom_minimum_size.x = inner if wide else 0.0
	_center_sub.custom_minimum_size.x = minf(460.0, inner)
	var sub_font := _center_sub.get_theme_font("font")
	var sub_wide := sub_font != null and sub_font.get_string_size(_center_sub.text, HORIZONTAL_ALIGNMENT_LEFT, -1, _center_sub.get_theme_font_size("font_size")).x > inner
	if sub_wide:
		_center_sub.custom_minimum_size.x = inner


## Un conteneur grandit tout seul mais ne rétrécit pas : le texte à renvoyer à la ligne se mesure à la largeur du
## bandeau, qu'on ne connaît qu'une image plus tard ; on le recale alors (sinon un grand vide sous le titre).
func _settle_banner() -> void:
	await get_tree().process_frame
	if is_instance_valid(_banner):
		_banner.reset_size()
		_center_banner()
		_banner.pivot_offset = _banner.size * 0.5


## Cache tout de suite le bandeau d'annonce (un choix de cartes ou un menu s'ouvre par-dessus).
func hide_banner() -> void:
	if _msg_tween:
		_msg_tween.kill()
	_banner.modulate.a = 0.0


## Le bandeau d'annonce (danger, boss, rage) est-il affiché ? Les cartes et le butin attendent (HudNotices, P0-7).
func banner_up() -> bool:
	if _msg_tween != null and _msg_tween.is_valid() and _msg_tween.is_running():
		return true  # (lot HUD-2 : dès l'annonce, avant même que son fondu d'entrée ne la montre)
	return _banner != null and is_instance_valid(_banner) and _banner.modulate.a > 0.05


## Taille et opacité du HUD (Paramètres > Affichage > HUD en partie, lot HUB-1 P0-9), à part de la taille de l'interface :
## la racine du HUD est posée à la taille de l'écran divisée par l'échelle, puis agrandie ; les ancres restent justes.
func _apply_hud_prefs() -> void:
	if _root == null or not is_instance_valid(_root):
		return
	var s := clampf(float(Settings.get_v("interface", "hud_scale")) * HudV2.scale_of(), 0.6, 1.5)  # (× profil Compact, lot HUD-2)
	if _map_holder != null and not Royale.active:
		_map_holder.visible = HudV2.shows("minimap")  # profil Minimal : la grande carte reste sur sa touche
	if is_equal_approx(s, 1.0):
		_root.scale = Vector2.ONE
		_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	else:
		_root.set_anchors_preset(Control.PRESET_TOP_LEFT)
		_root.position = Vector2.ZERO
		_root.size = get_viewport().get_visible_rect().size / s
		_root.scale = Vector2(s, s)
	_root.modulate.a = clampf(float(Settings.get_v("interface", "hud_opacity")), 0.35, 1.0)


## Ligne du fil de butin (3 au plus, la plus récente en bas), effacée après quelques secondes ; elle attend la fin du
## bandeau d'annonce (une seule chose à lire à la fois, P0-7).
func feed(text: String, color := Color(1.0, 0.88, 0.55)) -> void:
	var room := _feed_room()
	if HudV2.loot_lines() <= 0 and not Royale.active:
		return  # profil Minimal : pas de fil du butin (lot HUD-2)
	if banner_up() or room <= 0:
		_feed_wait.append([text, color])
		while _feed_wait.size() > 6:
			_feed_wait.pop_front()
		return
	# ligne autocollante (lot HUD-2) : puits d'encre contouré, case de couleur du genre de trouvaille, texte papier
	if _feed_style == null:
		_feed_style = UiTheme.sticker("nuit", {"radius": 12, "shadow": 3, "pad": Vector2(8, 3), "gloss": false, "cel_top": 0.0, "cel_bottom": 0.0})
	var box := PanelContainer.new()
	box.add_theme_stylebox_override("panel", _feed_style)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.size_flags_horizontal = Control.SIZE_SHRINK_END if _loot != null else Control.SIZE_SHRINK_BEGIN
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(row)
	var tone := ""
	for pre in FEED_TONES:
		if text.begins_with(pre):
			tone = FEED_TONES[pre]
	var tab := Panel.new()
	tab.custom_minimum_size = Vector2(16, 16)
	tab.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tab.add_theme_stylebox_override("panel", HudWidgets.box(UiTheme.color("bonbon.%s.base" % tone) if tone != "" else color, 5, 2, UiTheme.color("encre.900")))
	row.add_child(tab)
	var l := _label(row, text, 15, UiTheme.color("papier.100"))
	l.add_theme_font_override("font", UiTheme.bold_font())
	l.add_theme_color_override("font_outline_color", UiTheme.color("encre.700"))
	l.clip_text = true
	l.custom_minimum_size.x = minf(PANEL_W - 44.0, l.get_theme_font("font").get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x + 2.0)
	_feed.add_child(box)
	while _feed.get_child_count() > maxi(room, 1):
		var old := _feed.get_child(0)
		_feed.remove_child(old)
		old.queue_free()
	box.modulate.a = 0.0
	var tw := box.create_tween()
	tw.tween_property(box, "modulate:a", 1.0, 0.15)
	tw.tween_interval(3.5)
	tw.tween_property(box, "modulate:a", 0.0, 0.6)
	tw.tween_callback(box.queue_free)


## Coup reçu léger (lot SND-2) : un « thud » feutré, ni pour les petits tics de dégâts continus (moins de [constant HIT_MIN] des
## PV max) ni pour les gros coups (plus de [constant HIT_MAX], le jeu les fait déjà sentir), au plus un toutes les 0,45 s.
const HIT_MIN := 0.012
const HIT_MAX := 0.30
const HIT_GAP_MS := 450
var _hit_ms := -1000
var _better_ms := -10000


func _on_player_hit(amount: float, source: Combatant) -> void:
	var ratio := amount / maxf(player.max_hp, 1.0)
	if source == null or player.is_dead or ratio < HIT_MIN or ratio > HIT_MAX:
		return
	var now := Time.get_ticks_msec()
	if now - _hit_ms < HIT_GAP_MS:
		return
	_hit_ms = now
	UiFeel.cue("ui_hit", -10.0)


func _on_hp(hp: float, max_hp: float) -> void:
	_hp_orb.set_hp(hp, max_hp)


## Barre de niveau (lot HUD-2, P0-8 : au lieu du globe) ; aucun pourcentage permanent, il reste dans l'infobulle.
func _on_xp(xp: int, xp_next: int, level: int) -> void:
	var ratio := float(xp) / maxf(float(xp_next), 1.0)
	if _last_level != 0 and level > _last_level:
		_xp_orb.flash = 1.0  # montée de niveau : éclat soleil
	_last_level = level
	_xp_orb.set_level(ratio, level)
	_xp_orb.tooltip_text = "Niveau %d\nExpérience : %s / %s (%d %%)" % [level, _big_number(xp), _big_number(xp_next), floori(ratio * 100.0)]
	if Epochs.adventure():
		# lot H4a : le niveau de la partie ne donne que des cartes ; le héros se bat à son niveau de héros
		_xp_orb.tooltip_text = "Niveau de partie %d : chaque niveau donne une carte.\nTon héros se bat au niveau %d.\nExpérience : %s / %s" % [level, Run.hero_level, _big_number(xp), _big_number(xp_next)]


# --- fabrique de widgets ---
static func style(color := PANEL) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(10)
	sb.border_color = Color(ACCENT, 0.5)
	sb.set_border_width_all(2)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	sb.shadow_color = Color(0, 0, 0, 0.35)
	sb.shadow_size = 4
	return sb


func _panel(parent: Control) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", style())
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(p)
	return p


static func _label(parent: Control, text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	if size >= 26:
		l.add_theme_font_override("font", UiTheme.title_font())  # grands titres en Mochiy Pop One
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_constant_override("outline_size", 4)
	l.add_theme_color_override("font_outline_color", UiTheme.color("encre.700"))  # contour d'encre, jamais de noir (bible § 3)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l


func _bar(parent: Control, color: Color, height: int) -> ProgressBar:
	var b := ProgressBar.new()
	b.show_percentage = false
	b.step = 0.0
	b.custom_minimum_size = Vector2(0, height)
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# jauge autocollante (lot HUD-2, bible § 5) : creux d'encre 500 contouré d'encre, remplissage net
	var bg := StyleBoxFlat.new()
	bg.bg_color = UiTheme.color("encre.500")
	bg.border_color = UiTheme.color("encre.700")
	bg.set_border_width_all(3)
	bg.set_corner_radius_all(height / 2)
	bg.anti_aliasing = true
	var fg := StyleBoxFlat.new()
	fg.bg_color = color
	fg.set_corner_radius_all(height / 2)
	fg.border_color = Color(0, 0, 0, 0)
	fg.set_border_width_all(3)  # (le remplissage reste dans le contour d'encre)
	fg.anti_aliasing = true
	b.add_theme_stylebox_override("background", bg)
	b.add_theme_stylebox_override("fill", fg)
	parent.add_child(b)
	return b
