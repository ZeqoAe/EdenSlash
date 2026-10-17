class_name SurvivorHud
extends Control
## HUD du Survivant v2 (lot SVX-2 ; maquette conception/benchmark/survivant_maquettes/v2_hud.svg ; BIBLE v2 « autocollant »).
##   - haut : barre d'expérience pleine largeur, niveau dans une pastille soleil (XpBar) ;
##   - centre haut : panneau papier, chrono « 12:34 avant le boss » et frise des 20 minutes : gardiens gris à venir, fraise
##     « ! » à l'annonce et tant qu'il est debout, pomme ✓ vaincus ; portail à 15:00, boss au bout. Dans l'arène : temps avant
##     la rage et jauge de rage à graduations. La frise tremble (±3 px) et gronde à l'annonce d'un gardien (Clock) ;
##   - gauche (pile du HUD, sous les objectifs) : la collection de la partie : arme +N, 8 cases (rareté, +N, éveil en points
##     soleil), panoplie « 3 / 5 », passifs actifs en ronds ×N, « Évolution prête » ; survol : la carte de la pièce (Collection) ;
##   - bas : la vie en jauge large, trace claire des dégâts (HpGauge) ; les cases de sorts dessinent la grille 4 × 3 et leurs
##     touches (HudWidgets.SkillSlot.chain_slots / key_sticker) ; « Sorts n / 12 » ;
##   - moments manga (SurvivorMoments) et journal des moments marquants (SurvivorLog.moment).
## Le HUD commun garde le reste : objectifs (sans horloge), Menace, quête, mini-carte, cible (élites, géants, boss), messages.
## Aucun compteur « dégâts cumulés » en Survivant (bruit face à une horde, BM-SURV § 3).

const TOP := 40.0  # hauteur réservée en haut de l'écran (barre d'expérience)
const BOTTOM_LIFT := 34.0  # la barre d'action monte : la jauge de vie se loge dessous
const BANNER_Y := 230.0  # haut du bandeau d'annonce (sous le chrono et la cible)

var director: RunDirector
var hud: Hud
var xp: XpBar
var clock: Clock
var collection: Collection
var hp: HpGauge
var moments: SurvivorMoments
var spells_label: Label
var _hooked := false
var _guardians_seen := 0
var _states := [0, 0, 0]
var _last_state := ""
var _milestone := 0
var _plus10 := {}


## Pose le HUD v2 sur le HUD commun [param h] (racine [param root]) ; appelé à la fin de Hud._build.
static func attach(h: Hud, root: Control, d: RunDirector) -> SurvivorHud:
	SurvivorLog.begin()
	var s := SurvivorHud.new()
	s.hud = h
	s.director = d
	root.add_child(s)
	s._setup()
	current = s
	return s


## HUD du Survivant en cours (sous-titres des alertes).
static var current: SurvivorHud
var captions: Captions
var pending: Label  # (lot SVX-4, SV-Q3) « 3 choix en attente · Tab »


## Sous-titre d'une alerte sonore (lot SVX-4, SV-A1 : réglage interface/alert_captions) : « ♪ Grondement : un gardien
## approche », en bas au centre, trois au plus, 3,5 s chacun.
static func caption(text: String) -> void:
	if not bool(Settings.get_v("interface", "alert_captions")) or current == null or not is_instance_valid(current) or current.captions == null:
		return
	current.captions.add(text)


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _setup() -> void:
	# le HUD commun fait de la place : ni orbes (vie, niveau), ni horloge des objectifs, ni compteur de dégâts
	hud._xp_orb.visible = false
	hud._hp_orb.visible = false
	hud._clock_label.visible = false
	hud._dmg_box.visible = false
	hud._left.position.y = TOP + 8.0
	var holder := hud.minimap.get_parent().get_parent() as Control  # (mini-carte ronde : son support)
	if holder != null:
		holder.offset_top += TOP
		holder.offset_bottom += TOP
	hud._fps_label.offset_top += TOP
	hud._fps_label.offset_bottom += TOP
	hud._target_box.offset_top = TOP + Clock.H + 18.0  # cible (élite, géant, boss) sous le chrono
	hud._target_box.offset_bottom = hud._target_box.offset_top
	hud._banner.offset_top = BANNER_Y  # bandeau d'annonce sous la cible
	hud._action_root.offset_top -= BOTTOM_LIFT
	hud._action_root.offset_bottom -= BOTTOM_LIFT
	xp = XpBar.new()
	add_child(xp)
	clock = Clock.new(self)
	add_child(clock)
	collection = Collection.new(self)
	hud._left.add_child(collection)
	hud._left.move_child(collection, 1)  # sous le panneau des objectifs
	hp = HpGauge.new()
	hp.position = Vector2(150, 200)
	hp.size = Vector2(600, HpGauge.H)
	hud._action_root.add_child(hp)
	spells_label = Hud._label(hud._action_root, "", UiTheme.MIN_TEXT, UiTheme.color("papier.100"))
	spells_label.add_theme_font_override("font", UiTheme.bold_font())
	spells_label.add_theme_color_override("font_outline_color", UiTheme.color("encre.700"))
	spells_label.position = Vector2(640, 80)
	moments = SurvivorMoments.new()
	moments.hud = hud
	add_child(moments)
	captions = Captions.new()
	add_child(captions)
	pending = Label.new()  # (lot SVX-4, SV-Q3) choix regroupés : pastille mandarine en tête de la pile de gauche
	pending.add_theme_font_override("font", UiTheme.bold_font())
	pending.add_theme_font_size_override("font_size", UiTheme.MIN_TEXT + 1)
	pending.add_theme_color_override("font_color", Color.WHITE)
	pending.add_theme_constant_override("outline_size", 4)
	pending.add_theme_color_override("font_outline_color", UiTheme.color("encre.700"))
	pending.add_theme_stylebox_override("normal", UiTheme.sticker("mandarine", {"shadow": 3, "radius": 10, "gloss": false, "pad": Vector2(12, 4)}))
	pending.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	pending.visible = false
	hud._left.add_child(pending)
	hud._left.move_child(pending, 0)
	if hud.player != null:
		moments.player = hud.player
		hud.player.leveled_up.connect(_on_level)


## Le gardien [param n] : 0 à venir, 1 annoncé ou debout, 2 vaincu.
func guardian_state(n: int) -> int:
	if director == null or director.sv == null:
		return 0
	for e in director.sv.guardians:
		if int(e.n) == n:
			return 2 if float(e.ttk) >= 0.0 else 1
	var at := float(Survivor.GUARDIAN_TIMES[n])
	return 1 if director.time >= at - SurvivorDirector.GUARDIAN_WARN and director.time < at + 1.0 else 0


func _process(delta: float) -> void:
	if director == null or not is_instance_valid(director) or hud.player == null:
		return
	SurvivorCodex.observe(get_tree(), delta)  # (lot SVX-3) monstres vus pour le Codex
	var p := hud.player
	xp.set_xp(p.xp, GameData.xp_to_next(p.level), p.level)
	hp.set_hp(p.hp, p.max_hp)
	spells_label.text = "Sorts %d / %d" % [Run.all_skills().size(), Survivor.SPELL_MAX]
	var w := hud.get_parent()
	var held: int = w.cards.held() if w != null and w.get("cards") is SurvivorPicker else 0
	pending.visible = held > 0
	if held > 0:
		pending.text = "%d choix en attente · %s" % [held, Settings.action_label("objectives", 1)]
	_hook_cards()
	_watch()
	_layout()


## Le chrono laisse la place à la barre de boss v2 du HUD commun (lot DNG-2) quand elle est là ; le bandeau d'annonce reste
## sous le chrono (le HUD commun le remet à sa place à chaque image : on le recale après lui).
func _layout() -> void:
	var bb: Variant = hud.get("_boss_bar")
	var boss_on := bb != null and is_instance_valid(bb) and bool(bb.visible)
	clock.visible = not boss_on
	if boss_on:
		if float(bb.offset_top) < TOP:
			bb.offset_top = TOP + 4.0
	else:
		hud._banner.offset_top = BANNER_Y


## Choix de cartes du monde : évolution prise, jet parfait, panoplie complète… (moments et journal).
func _hook_cards() -> void:
	if _hooked:
		return
	var w := hud.get_parent()
	if w != null and w.get("cards") != null:
		_hooked = true
		(w.cards as CardPicker).picked.connect(_on_picked)


## Annonces de la frise, gardiens vaincus, arène : moments et journal.
func _watch() -> void:
	for n in Survivor.GUARDIAN_TIMES.size():
		var st := guardian_state(n)
		if st == 1 and int(_states[n]) == 0:
			clock.shake = 0.6  # gardien annoncé : la frise tremble, son grave
			Sfx.ui("rock", -8.0, 0.55)
		_states[n] = st
	if director.sv != null:
		for e in director.sv.guardians:
			if float(e.ttk) >= 0.0 and int(e.n) >= _guardians_seen:
				_guardians_seen = int(e.n) + 1
				SurvivorLog.moment(float(e.t) + float(e.ttk), "Gardien %d vaincu en %s" % [int(e.n) + 1, SurvivorDirector.clock(float(e.ttk))], "guardian")
				moments.pop("Gardien vaincu !", UiTheme.color("bonbon.pomme.clair"))
	if director.state != _last_state:
		if director.state == "boss":
			var b = director.get("_boss")
			var bname := String(b.display_name).trim_prefix("<Boss> ") if b != null and is_instance_valid(b) else ""
			moments.boss(bname)
			SurvivorLog.moment(director.time, "Arène du boss", "boss")
		elif director.state == "cleared" and _last_state == "boss":
			SurvivorLog.moment(director.time, "Boss vaincu", "win")
		_last_state = director.state


func _on_level(lvl: int) -> void:
	if moments != null:
		moments.level_up(lvl)
	_level_wave()
	if lvl >= _milestone + 10 and lvl % 10 == 0:
		_milestone = lvl
		SurvivorLog.moment(director.time if director else 0.0, "Niveau %d" % lvl, "level")


## Montée de niveau (lot SVX-3, BM-SURV § 7.3) : onde blanche qui repousse d'environ 2 m les monstres à moins de LEVEL_WAVE m
## (élites, géants et boss à peine : Monster.knockback) ; un instant de répit avant le choix de carte.
const LEVEL_WAVE := 4.0
const LEVEL_PUSH := 7.5  # impulsion (amortie à 14 m/s² : ≈ 2 m)


func _level_wave() -> void:
	var p := hud.player
	if p == null or not is_instance_valid(p) or not p.is_inside_tree():
		return
	Vfx.ring(p, p.global_position, LEVEL_WAVE, Color(1.0, 1.0, 1.0, 0.85))
	for m in Procs.monsters_near(p, p.global_position, LEVEL_WAVE):
		var dir: Vector3 = m.global_position - p.global_position
		dir.y = 0.0
		if dir.length() > 0.01:
			m.knockback(dir.normalized() * LEVEL_PUSH)


func _on_picked(card: Dictionary) -> void:
	var t := String(card.get("type", ""))
	var now := director.time if director else 0.0
	if t == "sv_weapon" and card.has("item"):
		SurvivorCodex.note_weapon(card.item)  # (lot SVX-3) Codex : armes portées
	if t == "sv_evolution":
		var name := String(card.get("title", ""))
		moments.evolution(name)
		SurvivorLog.moment(now, "Évolution : " + name, "evolution")
	if card.has("item") and SurvivorGear.is_perfect(card.item):
		moments.pop("Jet parfait !", UiTheme.color("bonbon.soleil.clair"))
		SurvivorLog.moment(now, "Jet parfait : " + Items.card_name(card.item), "perfect")
	for slot in Items.SLOTS:
		var it: Dictionary = Profile.equipped.get(slot, {})
		if not it.is_empty() and int(it.get("upgrade", 0)) >= Items.MAX_UPGRADE and not _plus10.has(slot):
			_plus10[slot] = true
			SurvivorLog.moment(now, "%s à +%d" % [Items.SLOT_NAMES.get(slot, slot), Items.MAX_UPGRADE], "upgrade")
	var counts := Items.set_counts(Profile.equipped)
	for sid in counts:
		if int(counts[sid]) >= 5 and String(sid) in SurvivorPool.sets():
			SurvivorLog.moment(now, "Panoplie %s complète" % SurvivorPool.panoply_name(String(sid)), "set")
	if Run.all_skills().size() >= Survivor.SPELL_MAX:
		SurvivorLog.moment(now, "Grille de sorts pleine", "spells")


# --- dessin commun -----------------------------------------------------------------------------------------------------
## Texte contouré d'encre (BIBLE § 4) centré horizontalement sur [param x], ligne de base [param y].
static func ink_text(ci: CanvasItem, font: Font, t: String, x: float, y: float, fs: int, col: Color, outline := 0, align := 0) -> void:
	var w := font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var at := Vector2(x - w * 0.5 if align == 0 else (x if align < 0 else x - w), y)
	if outline > 0:
		ci.draw_string_outline(font, at, t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, outline, UiTheme.color("encre.700"))
	ci.draw_string(font, at, t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)


## Rectangle arrondi plein (+ contour) sans boîte de style à garder.
static func round_rect(ci: CanvasItem, r: Rect2, fill: Color, radius: int, border := 0, ink := Color.TRANSPARENT) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.set_corner_radius_all(radius)
	sb.anti_aliasing = true
	if border > 0:
		sb.border_color = ink
		sb.set_border_width_all(border)
	ci.draw_style_box(sb, r)


## Jauge contourée (BIBLE § 5) : creux encre-500, remplissage deux tons [param tone], trace claire, bord droit d'encre.
static func gauge(ci: CanvasItem, r: Rect2, k: float, tone: String, trail := -1.0) -> void:
	var ink := UiTheme.color("encre.700")
	var t := UiTheme.tones(tone)
	round_rect(ci, r, UiTheme.color("encre.500"), int(r.size.y * 0.5), 3, ink)
	var inner := r.grow(-3.0)
	if trail > k:
		round_rect(ci, Rect2(inner.position, Vector2(inner.size.x * clampf(trail, 0.0, 1.0), inner.size.y)), Color(t[0], 0.85), int(inner.size.y * 0.5))
	var w := inner.size.x * clampf(k, 0.0, 1.0)
	if w > 1.0:
		var fr := Rect2(inner.position, Vector2(w, inner.size.y))
		round_rect(ci, fr, t[1], int(inner.size.y * 0.5))
		round_rect(ci, Rect2(fr.position + Vector2(2, 1), Vector2(maxf(w - 4.0, 0.0), maxf(2.0, inner.size.y * 0.3))), Color(t[0], 0.9), 2)
		if k < 0.995:
			ci.draw_rect(Rect2(fr.end.x - 1.5, fr.position.y, 3.0, fr.size.y), ink)


# --- barre d'expérience ------------------------------------------------------------------------------------------------
class XpBar extends Control:
	var ratio := 0.0
	var level := 0
	var _flash := 0.0

	func _init() -> void:
		set_anchors_preset(Control.PRESET_TOP_WIDE)
		offset_top = 2
		offset_bottom = SurvivorHud.TOP
		mouse_filter = Control.MOUSE_FILTER_PASS
		process_mode = Node.PROCESS_MODE_ALWAYS

	func set_xp(x: int, nxt: int, lvl: int) -> void:
		var k := clampf(float(x) / maxf(float(nxt), 1.0), 0.0, 1.0)
		if level > 0 and lvl > level:
			_flash = 1.0
		if lvl != level or absf(k - ratio) > 0.001:
			ratio = k
			level = lvl
			tooltip_text = "Niveau %d\nExpérience : %s / %s" % [lvl, Hud._big_number(x), Hud._big_number(nxt)]
			queue_redraw()

	func _process(delta: float) -> void:
		if _flash > 0.0:
			_flash = maxf(0.0, _flash - delta * 2.0)
			queue_redraw()

	func _draw() -> void:
		var r := Rect2(70, 9, size.x - 86.0, 22)
		SurvivorHud.gauge(self, r, ratio, "pomme")
		if _flash > 0.0:
			SurvivorHud.round_rect(self, r.grow(2.0 * _flash), Color(1, 1, 1, 0.5 * _flash), 12)
		# pastille du niveau : soleil, contour d'encre, ombre dure
		var font := UiTheme.title_font()
		var t := "Niv. %d" % level
		var w := maxf(92.0, font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 19).x + 26.0)
		var pr := Rect2(12, 2, w, 34)
		draw_style_box(UiTheme.sticker("soleil", {"shadow": 3, "radius": 12, "pad": Vector2.ZERO}), Rect2(pr.position, pr.size + Vector2(0, 3)))
		SurvivorHud.ink_text(self, font, t, pr.get_center().x, pr.position.y + 24.0, 19, Color.WHITE, 6)


# --- chrono et frise ---------------------------------------------------------------------------------------------------
class Clock extends Control:
	const W := 460.0
	const H := 94.0
	var owner_hud: SurvivorHud
	var shake := 0.0

	func _init(o: SurvivorHud) -> void:
		owner_hud = o
		set_anchors_preset(Control.PRESET_CENTER_TOP)
		offset_left = -W * 0.5
		offset_right = W * 0.5
		offset_top = SurvivorHud.TOP + 4.0
		offset_bottom = offset_top + H + 8.0
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		process_mode = Node.PROCESS_MODE_ALWAYS

	func _process(delta: float) -> void:
		shake = maxf(0.0, shake - delta)
		queue_redraw()

	func _draw() -> void:
		var d := owner_hud.director
		if d == null or not is_instance_valid(d):
			return
		var off := Vector2(3.0 * sin(Time.get_ticks_msec() * 0.09) if shake > 0.0 and not UiFeel.reduce_motion else 0.0, 0.0)
		var panel := Rect2(off, Vector2(size.x, H + 7.0))
		draw_style_box(UiTheme.sticker("papier", {"shadow": 7, "radius": 18, "gloss": false, "cel_top": 0.0, "cel_bottom": 0.22, "pad": Vector2.ZERO}), panel)
		var ink := UiTheme.color("encre.700")
		var font := UiTheme.title_font()
		var body := UiTheme.bold_font()
		var cx := off.x + size.x * 0.5
		if d.state in ["boss", "cleared"]:
			_draw_boss(d, off, cx, font, body, ink)
			return
		var left := maxf(0.0, Survivor.RUN_TIME - d.time)
		var t := SurvivorDirector.clock(left)
		var tw := font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 32).x
		var warn := left < 60.0
		SurvivorHud.ink_text(self, font, t, cx - 40.0, 40.0, 32, UiTheme.color("bonbon.fraise.fonce") if warn else ink)
		SurvivorHud.ink_text(self, body, "avant le boss", cx - 40.0 + tw * 0.5 + 10.0, 37.0, UiTheme.MIN_TEXT, UiTheme.color("encre.300"), 0, -1)
		# frise : 0 → 20:00, gardiens, portail à 15:00, boss au bout
		var r := Rect2(off.x + 26.0, 58.0, size.x - 70.0, 14.0)
		var total := Survivor.RUN_TIME
		SurvivorHud.gauge(self, r, clampf(d.time / total, 0.0, 1.0), "soleil")
		var px := r.position.x + r.size.x * Survivor.BOSS_OPEN_AT / total
		draw_line(Vector2(px, r.position.y - 6.0), Vector2(px, r.end.y + 6.0), UiTheme.color("bonbon.amethyste.base"), 3.0)
		var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.012)
		for i in Survivor.GUARDIAN_TIMES.size():
			var x := r.position.x + r.size.x * float(Survivor.GUARDIAN_TIMES[i]) / total
			var st := owner_hud.guardian_state(i)
			var c := r.get_center()
			c.x = x
			var rad := 11.0 + (1.5 * pulse if st == 1 else 0.0)
			var fill: Color = [UiTheme.color("papier.300"), UiTheme.color("bonbon.fraise.base"), UiTheme.color("bonbon.pomme.base")][st]
			draw_circle(c, rad + 2.5, ink)
			draw_circle(c, rad, fill)
			var mark: String = ["%d" % int(float(Survivor.GUARDIAN_TIMES[i]) / 60.0), "!", "✓"][st]
			SurvivorHud.ink_text(self, body, mark, c.x, c.y + 5.0, UiTheme.MIN_TEXT, Color.WHITE if st == 1 else ink, 4 if st == 1 else 0)
		# (lot SVX-3) événements nommés : losange mandarine (initiale), il palpite pendant l'annonce et l'événement
		for e in SurvivorEvents.timeline():
			var ex := r.position.x + r.size.x * float(e.t) / total
			var ec := Vector2(ex, r.get_center().y)
			var live := d.time >= float(e.t) - SurvivorEvents.WARN and d.time < float(e.t) + 30.0
			var s := 8.0 + (1.5 * pulse if live else 0.0)
			var dia := PackedVector2Array([ec + Vector2(0, -s), ec + Vector2(s, 0), ec + Vector2(0, s), ec + Vector2(-s, 0)])
			var past := d.time >= float(e.t) + 30.0
			draw_colored_polygon(dia, UiTheme.color("papier.300") if past else UiTheme.color("bonbon.mandarine.base"))
			draw_polyline(dia + PackedVector2Array([dia[0]]), ink, 2.0, true)
			SurvivorHud.ink_text(self, body, String(e.name).left(1), ec.x, ec.y + 4.0, 11, ink)
		# boss : case améthyste au bout de la frise, couronne soleil
		var br := Rect2(r.end.x - 4.0, r.get_center().y - 14.0, 28.0, 28.0)
		SurvivorHud.round_rect(self, br, UiTheme.color("bonbon.amethyste.base"), 8, 3, ink)
		var crown := PackedVector2Array([br.position + Vector2(6, 19), br.position + Vector2(7, 9), br.position + Vector2(11, 14),
			br.position + Vector2(14, 7), br.position + Vector2(17, 14), br.position + Vector2(21, 9), br.position + Vector2(22, 19)])
		draw_colored_polygon(crown, UiTheme.color("bonbon.soleil.base"))
		draw_polyline(crown + PackedVector2Array([crown[0]]), ink, 1.5, true)
		# curseur du temps écoulé
		var tx := r.position.x + r.size.x * clampf(d.time / total, 0.0, 1.0)
		draw_line(Vector2(tx, r.position.y - 3.0), Vector2(tx, r.end.y + 3.0), Color.WHITE, 2.0)

	## Arène : temps avant la rage (puis son palier) et jauge de rage à graduations ; victoire.
	func _draw_boss(d: RunDirector, off: Vector2, cx: float, font: Font, body: Font, ink: Color) -> void:
		if d.state == "cleared":
			SurvivorHud.ink_text(self, font, "Victoire !", cx, 56.0, 34, UiTheme.color("bonbon.soleil.base"), 7)
			return
		var tier := d.boss_rage_tier()
		var left := d.boss_rage_next_in()
		var head := "Le boss" if tier == 0 else "Rage ×%s" % RunDirector.fmt_mult(RunDirector.rage_mult(tier))
		SurvivorHud.ink_text(self, font, head, cx - 30.0, 40.0, 30, UiTheme.color("bonbon.fraise.fonce") if tier > 0 else ink)
		if left >= 0.0:
			var hw := font.get_string_size(head, HORIZONTAL_ALIGNMENT_LEFT, -1, 30).x
			SurvivorHud.ink_text(self, body, ("rage dans %s" if tier == 0 else "plus fort dans %s") % SurvivorDirector.clock(left),
				cx - 30.0 + hw * 0.5 + 10.0, 37.0, UiTheme.MIN_TEXT, UiTheme.color("encre.300"), 0, -1)
		var start := d._boss_rage_start()
		var steps := RunDirector.RAGE_TIERS.size()
		var total := start + RunDirector.RAGE_STEP * (steps - 1)
		var r := Rect2(off.x + 26.0, 58.0, size.x - 52.0, 14.0)
		SurvivorHud.gauge(self, r, clampf(d._boss_time / total, 0.0, 1.0), "fraise" if tier > 0 else "soleil")
		for k in steps:
			var x := r.position.x + r.size.x * (start + RunDirector.RAGE_STEP * k) / total
			draw_rect(Rect2(x - 1.5, r.position.y - 4.0, 3.0, r.size.y + 8.0), ink)


# --- collection de la partie ---------------------------------------------------------------------------------------------
class Collection extends Control:
	const W := 330.0
	const CASE := 34.0
	const SLOTS := ["head", "chest", "legs", "gloves", "boots", "back", "necklace", "ring"]
	var owner_hud: SurvivorHud
	var _rects: Array = []  # [Rect2, objet (Dictionary) ou passif (String)]
	var _sig := ""
	var _t := 0.0

	func _init(o: SurvivorHud) -> void:
		owner_hud = o
		custom_minimum_size = Vector2(W, 0)
		size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		mouse_filter = Control.MOUSE_FILTER_PASS
		process_mode = Node.PROCESS_MODE_ALWAYS

	func _process(delta: float) -> void:
		_t -= delta
		if _t > 0.0:
			return
		_t = 0.25
		var sig := "%d|%d|%s|%s|%s" % [Run.kills, Profile.equipped.size(), str(Profile.equipped.values().map(func(it): return int(it.get("upgrade", 0)))),
			str(Run.passive_power), str(SurvivorCards.evolutions_open())]
		if sig != _sig:
			_sig = sig
			custom_minimum_size.y = _height()
			queue_redraw()

	func _passives() -> Array:
		var ids: Array = Run.passive_power.keys().filter(func(id): return float(Run.passive_power[id]) > 0.0)
		ids.sort_custom(func(a, b): return float(Run.passive_power[a]) > float(Run.passive_power[b]))
		return ids

	func _height() -> float:
		return 12.0 + 62.0 + 10.0 + CASE + 10.0 + (34.0 if not _passives().is_empty() else 0.0) + 14.0 + 7.0

	func _get_tooltip(at: Vector2) -> String:
		for e in _rects:
			if (e[0] as Rect2).has_point(at):
				if e[1] is Dictionary:
					return "%s" % Items.card_name(e[1]) if not (e[1] as Dictionary).is_empty() else "Emplacement libre : une carte de pièce le remplit"
				var d := Boons.get_def(String(e[1]))
				return "%s\n%s" % [String(d.get("name", e[1])), SurvivorCardView.fr(SurvivorCardView.effect_text(String(e[1]), float(Run.passive_power.get(e[1], 1.0))))]
		return ""

	func _make_custom_tooltip(for_text: String) -> Object:
		var at := get_local_mouse_position()
		for e in _rects:
			if (e[0] as Rect2).has_point(at) and e[1] is Dictionary and not (e[1] as Dictionary).is_empty():
				return ItemWidgets.item_card(e[1])
		return null if for_text == "" else null

	func _draw() -> void:
		_rects.clear()
		var ink := UiTheme.color("encre.700")
		var font := UiTheme.bold_font()
		var num := UiTheme.number_font()
		var h := _height()
		draw_style_box(UiTheme.sticker("papier", {"shadow": 6, "radius": 16, "gloss": false, "cel_top": 0.0, "cel_bottom": 0.12, "pad": Vector2.ZERO}),
			Rect2(Vector2.ZERO, Vector2(W, h)))
		# 1. arme : case rareté, nom, +N, éveil ; monstres vaincus
		var w: Dictionary = Profile.equipped.get("weapon", {})
		var wr := Rect2(12, 12, 62, 62)
		_case(wr, w, true)
		_rects.append([wr, w])
		var name := "Sans arme" if w.is_empty() else Items.card_name(w).trim_prefix("+%d " % int(w.get("upgrade", 0)))
		var nx := wr.end.x + 10.0
		var room := W - nx - 12.0
		while font.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x > room and name.length() > 4:
			name = name.left(name.length() - 2) + "…"
		draw_string(font, Vector2(nx, 30), name, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Items.color_of(w).darkened(0.35) if not w.is_empty() else UiTheme.color("encre.300"))
		var kills := "%s vaincus" % Hud._big_number(Run.kills)
		draw_string(font, Vector2(nx, 50), kills, HORIZONTAL_ALIGNMENT_LEFT, -1, UiTheme.MIN_TEXT, UiTheme.color("encre.300"))
		# panoplie la plus portée ou évolution prête
		var evo := SurvivorCards.evolutions_open()
		if not evo.is_empty():
			var et := "◆ Évolution prête"
			var ew := font.get_string_size(et, HORIZONTAL_ALIGNMENT_LEFT, -1, UiTheme.MIN_TEXT).x + 16.0
			var er := Rect2(nx, 56, ew, 22)
			SurvivorHud.round_rect(self, er, UiTheme.color("bonbon.amethyste.base"), 11, 2, ink)
			SurvivorHud.ink_text(self, font, et, er.get_center().x, er.position.y + 16.0, UiTheme.MIN_TEXT, Color.WHITE, 4)
		else:
			var best := _best_set()
			if best != "":
				var n := int(Items.set_counts(Profile.equipped).get(best, 0))
				draw_string(font, Vector2(nx, 72), "◆ %s %d / 5" % [SurvivorPool.panoply_name(best), n], HORIZONTAL_ALIGNMENT_LEFT, room, UiTheme.MIN_TEXT,
					UiTheme.color("bonbon.pomme.fonce"))
		# 2. les 8 emplacements
		var y := 12.0 + 62.0 + 10.0
		var gap := (W - 24.0 - CASE * SLOTS.size()) / float(SLOTS.size() - 1)
		for i in SLOTS.size():
			var it: Dictionary = Profile.equipped.get(SLOTS[i], {})
			var cr := Rect2(12.0 + i * (CASE + gap), y, CASE, CASE)
			_case(cr, it, false)
			_rects.append([cr, it])
		y += CASE + 10.0
		# 3. passifs actifs : ronds, ×N sources
		var ids := _passives()
		if not ids.is_empty():
			var sources := {}
			for it in SurvivorGear.worn():
				for p in it.get("sv_passives", []):
					sources[String(p.id)] = int(sources.get(String(p.id), 0)) + 1
			var max_n := int((W - 24.0) / 34.0)
			if ids.size() > max_n:
				max_n -= 1  # (la place du « +N »)
			for i in mini(ids.size(), max_n):
				var id := String(ids[i])
				var c := Vector2(12.0 + 14.0 + i * 34.0, y + 14.0)
				var evo_id := not (Boons.get_def(id).get("requires", []) as Array).is_empty()
				draw_circle(c, 15.5, ink)
				draw_circle(c, 13.0, UiTheme.color("bonbon.amethyste.base") if evo_id else UiTheme.color("encre.500"))
				var tex := UiTheme.texture(String(Boons.get_def(id).get("icon", Boons.ICONS.get(id, ""))))
				if tex:
					draw_texture_rect(tex, Rect2(c - Vector2(10, 10), Vector2(20, 20)), false)
				var n := int(sources.get(id, 0))
				if n > 1:
					SurvivorHud.ink_text(self, num, "×%d" % n, c.x + 9.0, c.y + 15.0, 12, Color.WHITE, 4)
				_rects.append([Rect2(c - Vector2(15, 15), Vector2(30, 30)), id])
			if ids.size() > max_n:
				SurvivorHud.ink_text(self, font, "+%d" % (ids.size() - max_n), W - 22.0, y + 19.0, UiTheme.MIN_TEXT, ink)

	func _best_set() -> String:
		var best := ""
		var counts := Items.set_counts(Profile.equipped)
		for sid in counts:
			if String(sid) in SurvivorPool.sets() and int(counts[sid]) >= 2 and (best == "" or int(counts[sid]) > int(counts[best])):
				best = String(sid)
		return best

	## Case d'objet (BIBLE § 5) : deux tons de la rareté, contour d'encre, icône, +N dans une pastille d'encre, éveil en
	## points soleil ; vide : papier tramé.
	func _case(r: Rect2, it: Dictionary, big: bool) -> void:
		var ink := UiTheme.color("encre.700")
		if it.is_empty():
			SurvivorHud.round_rect(self, r, UiTheme.color("papier.200"), 9, 2, UiTheme.color("encre.300"))
			for yy in range(int(r.position.y) + 6, int(r.end.y) - 3, 7):
				for xx in range(int(r.position.x) + 6, int(r.end.x) - 3, 7):
					draw_circle(Vector2(xx, yy), 1.1, Color(ink, 0.22))
			return
		var col := Items.color_of(it)
		SurvivorHud.round_rect(self, r, col.darkened(0.15), 10 if big else 9, 3 if big else 2, ink)
		SurvivorHud.round_rect(self, Rect2(r.position + Vector2(2, 2), Vector2(r.size.x - 4, r.size.y * 0.42)), col.lightened(0.18), 8)
		var tex := UiTheme.texture(String(it.get("icon", "")))
		if tex:
			draw_texture_rect(tex, r.grow(-4.0 if big else -3.0), false)
		var up := int(it.get("upgrade", 0))
		var font := UiTheme.number_font()
		if up > 0:
			var t := "+%d" % up
			var fs := 13 if big else 11
			var w := font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 6.0
			var pr := Rect2(r.position + Vector2(-2, -3), Vector2(w, fs + 4.0))
			SurvivorHud.round_rect(self, pr, ink, 5)
			draw_string(font, pr.position + Vector2(3, fs + 0.5), t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UiTheme.color("bonbon.soleil.base"))
		var awake := 0
		for at in Survivor.WAKE_AT:
			if up >= int(at):
				awake += 1
		for k in awake:
			var c := Vector2(r.position.x + 5.0 + k * 7.0, r.end.y - 4.0)
			draw_circle(c, 3.4, ink)
			draw_circle(c, 2.4, UiTheme.color("bonbon.soleil.base"))
		if SurvivorGear.is_perfect(it):
			SurvivorHud.ink_text(self, font, "★", r.end.x - 6.0, r.position.y + 12.0, 12, UiTheme.color("bonbon.soleil.clair"), 3)


# --- vie -------------------------------------------------------------------------------------------------------------------
class HpGauge extends Control:
	const H := 26.0
	var ratio := 1.0
	var trail := 1.0
	var _txt := ""

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_PASS
		process_mode = Node.PROCESS_MODE_ALWAYS

	func set_hp(v: float, mx: float) -> void:
		var k := clampf(v / maxf(mx, 1.0), 0.0, 1.0)
		if k > ratio:
			trail = k
		ratio = k
		_txt = "%s / %s" % [Hud._big_number(ceilf(v)), Hud._big_number(ceilf(mx))]
		tooltip_text = "Vie : " + _txt

	func _process(delta: float) -> void:
		if trail > ratio:
			trail = move_toward(trail, ratio, delta * 0.45)
		queue_redraw()

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		SurvivorHud.gauge(self, r, ratio, "fraise", trail)
		if ratio < 0.3:
			var a := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.012)
			SurvivorHud.round_rect(self, r.grow(2.0), Color(0, 0, 0, 0), int(H * 0.5) + 2, 2, Color(UiTheme.color("bonbon.fraise.clair"), a))
		SurvivorHud.ink_text(self, UiTheme.number_font(), _txt, r.get_center().x, r.position.y + 19.0, 15, Color.WHITE, 5)


# --- sous-titres des alertes (lot SVX-4, SV-A1) --------------------------------------------------------------------------
## Les alertes sonores écrites, en bas au centre au-dessus de la vie : « ♪ » + le son et ce qu'il annonce, pastille d'encre,
## trois au plus (la plus récente en bas), chacune 3,5 s puis un fondu.
class Captions extends Control:
	const LIFE := 3.5
	const MAX := 3
	var lines: Array = []  # [{text, t}]

	func _init() -> void:
		set_anchors_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		process_mode = Node.PROCESS_MODE_ALWAYS

	func add(text: String) -> void:
		for l in lines:
			if String(l.text) == text:
				l.t = 0.0  # (même alerte : on la rafraîchit, pas de doublon)
				return
		lines.append({"text": text, "t": 0.0})
		while lines.size() > MAX:
			lines.pop_front()
		queue_redraw()

	func _process(delta: float) -> void:
		if lines.is_empty():
			return
		for l in lines:
			l.t = float(l.t) + delta
		lines = lines.filter(func(l): return float(l.t) < LIFE)
		queue_redraw()

	func _draw() -> void:
		var font := UiTheme.bold_font()
		var fs := UiTheme.MIN_TEXT + 1
		var y := size.y - 196.0 - 34.0 * float(lines.size() - 1)
		for l in lines:
			var t := "♪  " + String(l.text)
			var w := font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 28.0
			var a := clampf((LIFE - float(l.t)) / 0.4, 0.0, 1.0)
			var r := Rect2(size.x * 0.5 - w * 0.5, y, w, 28.0)
			SurvivorHud.round_rect(self, r, Color(UiTheme.color("encre.500"), 0.92 * a), 14, 2, Color(UiTheme.color("encre.700"), a))
			SurvivorHud.ink_text(self, font, t, r.get_center().x, r.position.y + 20.0, fs, Color(UiTheme.color("papier.100"), a))
			y += 34.0
