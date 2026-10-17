class_name BossBar
extends Control
## Barre de boss v2 (lot DNG-2, backlog BM-DNG P0-1 ; maquette conception/benchmark/donjons_maquettes/v2_barre_boss.svg) : en haut
## au centre, une barre compacte en papier contouré d'encre (DA v2) qui remplace le cadre de cible quand la cible est un boss :
##   - médaillon (rendu du modèle, BossPortrait), nom, pastille de difficulté, minuteur de fureur (Impatience des boss de la
##     bibliothèque, rage du boss de la Survie) ;
##   - jauge épaisse (creux d'encre, remplissage fraise en deux tons, trace claire des dégâts, bord droit d'encre) avec les
##     **seuils réels** du cerveau (BossBrain.thresholds : la fureur à mi-vie et les briques « at »), une pastille de la couleur
##     de la famille sous chaque encoche, la part des PV au centre ;
##   - dessous, les pastilles des mécaniques du boss (l'active cerclée de blanc) et la ligne d'incantation mandarine
##     (« Pluie de météores · bouge ! ») tant qu'une mécanique est en cours.
## Elle ne cache jamais le boss : s'il passe derrière elle, elle s'efface à moitié ; s'il sort de la vue, une flèche soleil au
## bord de l'écran le montre. Elle porte aussi la frise « À venir » (BossTimeline) et les annonces à 3 niveaux (HudAlert).
## Lecture seule : rien ici ne change le combat (PV fixes, briques, rythmes intacts).
##   Hud : _boss_bar = BossBar.attach(root, self) ; _update_target : if _boss_bar.show_for(cible, director) -> le cadre de cible
##   se cache ; show_message : if _boss_bar.take_message(texte, durée) -> l'annonce est prise par HudAlert.

## Couleur (bonbon) de chaque famille de mécaniques (BossBricks.FAMILIES) : pastilles, encoches, frise, page Donjons, journal.
const FAMILY_TONE := {"ground": "fraise", "summon": "pomme", "enrage": "fraise", "shield": "soleil", "charge": "mandarine",
	"bullets": "amethyste", "arena": "mandarine", "position": "lagon", "counter": "amethyste", "waves": "lagon"}
## Familles des attaques de base et de la fureur à mi-vie (elles ne sont pas des briques).
const BASE_FAMILY := {"slams": "ground", "charge": "charge", "cleave": "charge", "barrage": "bullets", "nova": "waves", "phase2": "enrage"}
## Icône du jeu (icônes d'état) de chaque mécanique : on garde les icônes d'origine, posées dans nos pastilles.
const TYPE_ICON := {"puddles": "poison", "meteors": "burn", "lasers": "shock", "grid": "stun", "sweep": "shock", "adds": "frenzy",
	"pet": "regen", "clones": "invisible", "swarm": "frenzy", "turrets": "keen", "enrage": "fury", "frenzy": "fury", "totems": "barrier",
	"barrier": "barrier", "crystals": "regen", "rampage": "haste", "leap": "haste", "spiral": "chill", "ring_burst": "chill", "fan": "keen",
	"shrink": "burn", "safe_zone": "evasion", "vortex": "flow", "gale": "flow", "gaze": "invisible", "marks": "keen", "blink": "invisible",
	"reflect": "barrier", "stomp": "stun", "slams": "stun", "charge": "haste", "cleave": "keen", "barrage": "keen", "nova": "stun",
	"phase2": "fury"}
## Ligne d'incantation : ce qu'il faut faire, en deux ou trois mots.
const CAST_HINT := {"puddles": "sors des flaques", "meteors": "bouge !", "lasers": "entre deux rayons", "grid": "case qui a explosé",
	"sweep": "laisse passer", "adds": "les renforts d'abord", "pet": "garde-le en vue", "clones": "trouve le vrai", "swarm": "nettoie la nuée",
	"turrets": "détruis-les", "enrage": "garde tes défenses", "frenzy": "finis-le vite", "totems": "les totems d'abord",
	"barrier": "brise-la !", "crystals": "casse les cristaux", "rampage": "sur le côté !", "leap": "bouge !", "spiral": "tourne avec",
	"ring_burst": "entre deux orbes", "fan": "sur le côté !", "shrink": "reste au centre", "safe_zone": "au cercle sûr !",
	"vortex": "éloigne-toi !", "gale": "reviens vers lui", "gaze": "dans son dos !", "marks": "sors de la marque", "blink": "éloigne-toi",
	"reflect": "ne frappe pas !", "stomp": "saute !", "slams": "ne reste pas là", "charge": "sur le côté !", "cleave": "pas devant lui",
	"barrage": "entre les traits", "nova": "saute ou recule"}
## Gravité de l'annonce d'une mécanique (HudAlert) : 0 mineure (texte seul), 1 moyenne (bulle lagon), 2 critique (bulle fraise + son).
const SEVERITY := {"adds": 0, "pet": 0, "clones": 0, "swarm": 0, "turrets": 0, "crystals": 0, "result": 0,
	"safe_zone": 2, "gaze": 2, "vortex": 2, "shrink": 2, "enrage": 2, "phase2": 2}
## Annonce courte (28 signes au plus) quand celle de la brique est plus longue.
const SHORT := {"shrink": "L'arène se resserre !", "totems": "Détruis les totems !", "crystals": "Cristaux de soin !",
	"turrets": "Des tourelles !", "vortex": "Tourbillon : éloigne-toi !", "gale": "Bourrasque : reviens !", "gaze": "Il te fixe : dans son dos !",
	"marks": "Une marque te suit !", "stomp": "Ondes : saute !", "barrier": "Barrière : brise-la !", "safe_zone": "Rejoins le cercle sûr !",
	"adds": "Des renforts !", "pet": "Son compagnon arrive !", "clones": "Il se dédouble !", "rampage": "Il charge !",
	"enrage": "Il entre en rage !", "phase2": "Il entre en fureur !", "frenzy": "Il s'impatiente !", "reflect": "Miroir : ne frappe pas !"}
const MAX_ALERT := 28
const W_MIN := 480.0
const W_MAX := 720.0

var hud: Hud
var director: Node
var panel: PanelContainer  # (tests) la barre elle-même
var row: HBoxContainer  # (tests) pastilles des mécaniques et ligne d'incantation
var timeline: BossTimeline
var alert: HudAlert
var arrow: Label  # flèche au bord de l'écran quand le boss est hors de la vue
var boss_ref: WeakRef
var _portrait: BossPortrait
var _name: Label
var _diff: Label
var _fury: Label
var _gauge: Gauge
var _mechs: HBoxContainer
var _chips := {}  # type -> pastille
var _cast: PanelContainer
var _cast_label: Label
var _cast_fill: ColorRect
var _sig := ""
var _w := 0.0


static func attach(root: Control, p_hud: Hud) -> BossBar:
	var b := BossBar.new()
	b.hud = p_hud
	b.name = "BossBar"
	root.add_child(b)
	b.timeline = BossTimeline.new()
	root.add_child(b.timeline)
	b.alert = HudAlert.new()
	root.add_child(b.alert)
	return b


static func family_tone(fam: String) -> String:
	return String(FAMILY_TONE.get(fam, "amethyste"))


## Famille d'une mécanique, d'une attaque de base ou de la fureur.
static func family_of(type: String) -> String:
	return String(BASE_FAMILY.get(type, BossBricks.family_of(type)))


static func tone_of(type: String) -> String:
	return family_tone(family_of(type))


static func icon_of(type: String) -> Texture2D:
	var own := Ico.of_boss(type)  # un pictogramme par mécanique (lot ICO-1, « boss_hit » si inconnue) ; à défaut, l'icône d'état
	if own != null:
		return own
	return UiTheme.texture("res://assets/ui/status/%s.png" % String(TYPE_ICON.get(type, "fury")))


## Nom d'une mécanique, d'une attaque de base ou de la fureur.
static func mech_name(type: String) -> String:
	return "Fureur" if type == "phase2" else HitLog.mech_name(type)


## Pastille carrée d'une mécanique : icône du jeu sur la couleur de sa famille, contour d'encre.
static func chip(type: String, px: float) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UiTheme.sticker(tone_of(type), {"radius": int(px * 0.27), "shadow": 3, "pad": Vector2(3, 2), "gloss": px >= 34.0}))
	p.custom_minimum_size = Vector2(px, px)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ic := TextureRect.new()
	ic.texture = icon_of(type)
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(ic)
	return p


## Pastille de texte inclinée (difficulté, fureur, « Record ! ») : bonbon [param tone], texte blanc contouré d'encre.
static func pill(text: String, tone: String, size := 14, tilt := 8.0) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_stylebox_override("normal", UiTheme.sticker(tone, {"radius": 10, "shadow": 3, "pad": Vector2(9, 1), "gloss": false}))
	l.add_theme_font_override("font", UiTheme.bold_font())
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", Color.WHITE)
	l.add_theme_constant_override("outline_size", 4)
	l.add_theme_color_override("font_outline_color", UiTheme.color("encre.700"))
	l.rotation_degrees = tilt
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.resized.connect(func(): l.pivot_offset = l.size * 0.5)
	return l


static func diff_pill_text() -> Array:
	if not Tower.active:
		return []
	if Tower.is_dungeon():
		var d := clampi(Tower.dungeon_diff, 0, Dungeons.DIFF_NAMES.size() - 1)
		return [Dungeons.DIFF_NAMES[d], ["lagon", "amethyste", "mandarine"][d]]
	var t := clampi(Tower.difficulty, 0, Tower.DIFF_NAMES.size() - 1)
	return [Tower.DIFF_NAMES[t], ["pomme", "lagon", "amethyste", "fraise"][t]]


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_CENTER_TOP)
	process_mode = Node.PROCESS_MODE_INHERIT
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(v)
	panel = PanelContainer.new()
	var sb := UiTheme.sticker("papier", {"radius": 16, "shadow": 5, "gloss": false, "cel_top": 0.0, "cel_bottom": 0.0, "pad": Vector2(10, 7)})
	sb.content_margin_bottom = 12
	panel.add_theme_stylebox_override("panel", sb)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(panel)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(h)
	_portrait = BossPortrait.for_monster({}, 66, "?", true)
	_portrait.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(_portrait)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 5)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(col)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(head)
	_name = Label.new()
	_name.add_theme_font_override("font", UiTheme.bold_font())
	_name.add_theme_font_size_override("font_size", 20)
	_name.add_theme_color_override("font_color", UiTheme.color("encre.700"))
	_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name.clip_text = true
	_name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(_name)
	_diff = pill("", "amethyste", 13, 8.0)
	_diff.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(_diff)
	_fury = pill("", "fraise", 14, 0.0)
	_fury.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(_fury)
	_gauge = Gauge.new()
	_gauge.custom_minimum_size = Vector2(0, 30)
	col.add_child(_gauge)
	row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(row)
	_mechs = HBoxContainer.new()
	_mechs.add_theme_constant_override("separation", 6)
	_mechs.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_mechs)
	_cast = PanelContainer.new()
	_cast.add_theme_stylebox_override("panel", UiTheme.sticker("mandarine", {"radius": 12, "shadow": 3, "pad": Vector2(12, 3), "gloss": false}))
	_cast.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_cast.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_cast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cast.clip_contents = true
	row.add_child(_cast)
	_cast_fill = ColorRect.new()
	_cast_fill.color = Color(UiTheme.color("bonbon.mandarine.clair"), 0.85)
	_cast_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cast_fill.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_cast.add_child(_cast_fill)
	_cast_label = Label.new()
	_cast_label.add_theme_font_override("font", UiTheme.bold_font())
	_cast_label.add_theme_font_size_override("font_size", 16)
	_cast_label.add_theme_color_override("font_color", Color.WHITE)
	_cast_label.add_theme_constant_override("outline_size", 4)
	_cast_label.add_theme_color_override("font_outline_color", UiTheme.color("encre.700"))
	_cast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_cast_label.clip_text = true
	_cast_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_cast_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cast.add_child(_cast_label)
	_cast.modulate.a = 0.0
	arrow = Label.new()
	arrow.text = "▲"
	UiTheme.title(arrow, 34, UiTheme.color("bonbon.soleil.base"))
	arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	arrow.visible = false
	arrow.top_level = true
	add_child(arrow)
	visible = false


## Le boss suivi ([code]null[/code] : aucun).
func current() -> Monster:
	var b: Object = boss_ref.get_ref() if boss_ref != null else null
	return b as Monster if b != null and is_instance_valid(b) and not (b as Monster).is_dead else null


## La cible [param t] est-elle un boss ? Oui : la barre le suit et le cadre de cible ordinaire se cache. Non : la barre se cache.
func show_for(t: Node, p_director: Node) -> bool:
	director = p_director
	var m := t as Monster
	if m == null or not m.is_boss or m.is_dead:
		hide_all()
		return false
	if current() != m:
		boss_ref = weakref(m)
		_sig = ""
		_gauge.trail = m.hp / maxf(m.max_hp, 1.0)
	visible = true
	_refresh(m)
	return true


func hide_all() -> void:
	visible = false
	arrow.visible = false
	if timeline != null:
		timeline.visible = false
	_shift_banner(false)


## Une annonce de mécanique du boss suivi part en alerte à 3 niveaux (HudAlert) ; les autres messages gardent le bandeau (décalé
## sous la barre). Renvoie true si l'annonce est prise.
func take_message(text: String, duration: float) -> bool:
	var m := current()
	if not visible or m == null or m.brain == null:
		_shift_banner(false)
		return false
	_shift_banner(true)
	var t := text.strip_edges()
	if t.contains("\n"):
		return false
	var type := classify(m.brain, t)
	if type == "" or (not t.ends_with("!") and type != "reflect"):
		return false
	alert.show_alert(alert_text(type, t), int(SEVERITY.get(type, 1)), clampf(duration * 0.8, 1.4, 2.6))
	return true


## Texte de l'alerte (28 signes au plus) : l'annonce telle quelle si elle tient ; sinon le texte court de la mécanique
## (SHORT) ; sinon ce qui précède les deux-points (« Barrière brisée : il chancelle ! » -> « Barrière brisée ! ») ; sinon coupé.
static func alert_text(type: String, text: String) -> String:
	var t := text.strip_edges()
	if t.length() <= MAX_ALERT:
		return t
	if SHORT.has(type) and type != "result" and not (type == "barrier" and not t.begins_with("Barrière :")):
		return String(SHORT[type])
	if t.contains(" : "):
		var head := t.get_slice(" : ", 0).strip_edges()
		if head.length() + 2 <= MAX_ALERT:
			return head + " !"
	return t.left(MAX_ALERT - 1).strip_edges() + "…"


## Mécanique d'une annonce [param text] du cerveau [param brain] : la brique qui vient d'être lancée, sinon d'après les mots des
## annonces qui suivent (barrière brisée, fureur, impatience, miroir) ; "" : pas une annonce de mécanique.
static func classify(brain: BossBrain, text: String) -> String:
	if brain.age - brain.last_cast_at < 0.3 and brain.last_cast != "" and not brain.last_cast in ["slams", "charge", "cleave", "barrage"]:
		return brain.last_cast
	var low := text.to_lower()
	if low.contains("fureur"):
		return "phase2"
	if low.contains("impatiente"):
		return "frenzy"
	if low.contains("miroir"):
		return "reflect"
	if low.contains("brisé") or low.contains("tient"):
		return "result"
	return ""


## Le bandeau d'annonce ordinaire (intro du boss, salle suivante) passe sous la barre quand elle est affichée.
func _shift_banner(on: bool) -> void:
	if hud == null or hud._banner == null:
		return
	var top := 122.0
	if on and visible:
		top = maxf(122.0, position.y + (get_child(0) as Control).size.y + 14.0)
	hud._banner.offset_top = top


func _refresh(m: Monster) -> void:
	var root := get_parent() as Control
	var vw: float = root.size.x if root != null and root.size.x > 0.0 else get_viewport_rect().size.x
	var w := clampf(vw - 2.0 * (Hud.PANEL_W + 30.0), W_MIN, W_MAX)
	if not is_equal_approx(w, _w):
		_w = w
		custom_minimum_size.x = w
		(get_child(0) as Control).custom_minimum_size.x = w
		offset_left = -w * 0.5
		offset_right = w * 0.5
		offset_top = 10.0
	var brain := m.brain
	var sig := str(m.get_instance_id()) + ("|%d" % (brain.bricks.size() if brain != null else -1))
	if sig != _sig:
		_sig = sig
		_build_for(m)
	var ratio := clampf(m.hp / maxf(m.max_hp, 1.0), 0.0, 1.0)
	_gauge.ratio = ratio
	if _gauge.trail > ratio:
		_gauge.trail = move_toward(_gauge.trail, ratio, get_process_delta_time() * 0.45)
	else:
		_gauge.trail = ratio
	_gauge.shielded = m.shielded or (brain != null and brain.barrier_left > 0.0)
	_gauge.text = "%d %%" % ceili(ratio * 100.0) if ratio > 0.0 else "0 %"
	var marks: Array = []
	if brain != null:
		for th in brain.thresholds():
			marks.append({"at": float(th.at), "tone": tone_of(String(th.type)), "done": bool(th.done)})
	_gauge.marks = marks
	_gauge.queue_redraw()
	_update_fury(m)
	var cur := brain.active_cast() if brain != null else ""
	for k in _chips:
		var c: Control = _chips[k]
		var on := String(k) == cur
		c.scale = Vector2.ONE * (1.12 if on else 1.0)
		c.modulate = Color.WHITE if on or cur == "" else Color(1, 1, 1, 0.72)
		(c.get_child(c.get_child_count() - 1) as Control).visible = on
	if cur != "":
		_cast_label.text = "%s · %s" % [mech_name(cur), String(CAST_HINT.get(cur, "attention !"))]
		var k := clampf((brain.age - brain.last_cast_at) / BossBrain.ACTIVE_SECS, 0.0, 1.0)
		_cast_fill.custom_minimum_size.x = maxf(_cast.size.x - 24.0, 0.0) * (1.0 - k)
		_cast.modulate.a = 1.0
	else:
		_cast.modulate.a = move_toward(_cast.modulate.a, 0.0, get_process_delta_time() * 4.0)
	_place_arrow_and_fade(m)
	if timeline != null:
		timeline.follow(brain, self)


func _build_for(m: Monster) -> void:
	var nm := m.display_name.trim_prefix("<Boss> ").trim_prefix("<Duel> ")
	_name.text = nm
	var fam := "enrage"
	var types: Array = []
	if m.brain != null:
		for br in m.brain.bricks:
			var t := String(br.type)
			if not t in types:
				types.append(t)
	if not types.is_empty():
		fam = family_of(String(types[0]))
	var lieutenant := m.display_name.contains(", lieutenant")
	var d := diff_pill_text()
	if lieutenant:
		d = ["Lieutenant", "soleil"]
	_diff.visible = not d.is_empty()
	if not d.is_empty():
		_diff.text = String(d[0])
		_diff.add_theme_stylebox_override("normal", UiTheme.sticker(String(d[1]), {"radius": 10, "shadow": 3, "pad": Vector2(9, 1), "gloss": false}))
	_portrait.set_boss(m.data if m.data is Dictionary else {}, nm, family_tone(fam))
	for c in _mechs.get_children():
		c.queue_free()
	_chips.clear()
	var px := 34.0 if _w < 560.0 else 38.0
	for t in types.slice(0, 5):
		var c := chip(String(t), px)
		c.pivot_offset = Vector2(px, px) * 0.5
		var ring := Panel.new()  # anneau blanc de la mécanique en cours
		var rs := StyleBoxFlat.new()
		rs.draw_center = false
		rs.set_border_width_all(3)
		rs.border_color = Color.WHITE
		rs.set_corner_radius_all(int(px * 0.33))
		rs.expand_margin_left = 4
		rs.expand_margin_right = 4
		rs.expand_margin_top = 4
		rs.expand_margin_bottom = 4
		ring.add_theme_stylebox_override("panel", rs)
		ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ring.visible = false
		c.add_child(ring)
		_mechs.add_child(c)
		_chips[String(t)] = c


func _update_fury(m: Monster) -> void:
	var txt := ""
	var f: Dictionary = m.brain.fury() if m.brain != null else {}
	if not f.is_empty():
		txt = "Fureur %s" % BestTimes.fmt(float(f.left)) if float(f.left) > 0.0 else "Fureur ×%d" % int(f.steps)
	elif director != null and Run.survival and director.has_method("boss_rage_tier") and director.get("_boss") == m:
		var tier: int = director.boss_rage_tier()
		var left: float = director.boss_rage_next_in()
		txt = "Rage %s" % BestTimes.fmt(left) if tier == 0 and left >= 0.0 else ("Rage ×%d" % tier if tier > 0 else "")
	_fury.visible = txt != ""
	_fury.text = txt


## Le boss sous la barre : elle s'efface à moitié ; hors de la vue : flèche au bord de l'écran.
func _place_arrow_and_fade(m: Monster) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		arrow.visible = false
		return
	var vr := Rect2(Vector2.ZERO, get_viewport().get_visible_rect().size)
	if vr.size.x < 200.0 or vr.size.y < 200.0:
		return
	var head := m.global_position + Vector3.UP * 1.2  # le corps du boss (sa tête peut sortir par le haut sans qu'il soit caché)
	var behind := cam.is_position_behind(head)
	var sp := cam.unproject_position(head)
	var inset := vr.grow(-46.0)
	if behind or not inset.has_point(sp):
		var c := vr.get_center()
		var dir := (sp - c) if not behind else (c - sp)
		if dir.length() < 1.0:
			dir = Vector2.DOWN
		dir = dir.normalized()
		# la flèche reste sous la barre et ses pastilles (jamais posée dessus)
		var top := maxf(inset.position.y, row.get_global_rect().end.y + 28.0)
		var kx := (inset.end.x - c.x) / maxf(dir.x, 0.001) if dir.x > 0.0 else (c.x - inset.position.x) / maxf(-dir.x, 0.001)
		var ky := (inset.end.y - c.y) / maxf(dir.y, 0.001) if dir.y > 0.0 else (c.y - top) / maxf(-dir.y, 0.001)
		var k := minf(kx, ky)
		arrow.visible = true
		arrow.pivot_offset = arrow.size * 0.5
		arrow.global_position = c + dir * k - arrow.size * 0.5
		arrow.rotation = dir.angle() + PI * 0.5
		modulate.a = 1.0
		return
	arrow.visible = false
	var r := panel.get_global_rect().grow(10.0)
	r = r.merge(row.get_global_rect())
	var top_p := cam.unproject_position(m.global_position + Vector3.UP * (m.radius * 2.0 + 1.0))  # haut du boss
	modulate.a = 0.42 if r.has_point(sp) or r.has_point(top_p) else 1.0


## Jauge du boss : creux d'encre, remplissage en deux tons, trace claire, bord droit d'encre, encoches aux seuils réels.
class Gauge extends Control:
	var ratio := 1.0
	var trail := 1.0
	var marks: Array = []
	var shielded := false
	var text := ""

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		if size.x < 20.0 or size.y < 14.0:
			return
		var ink := UiTheme.color("encre.700")
		var r := Rect2(Vector2(0, 2), Vector2(size.x, size.y - 10.0))
		var sb := StyleBoxFlat.new()
		sb.bg_color = UiTheme.color("encre.500")
		sb.border_color = ink
		sb.set_border_width_all(3)
		sb.set_corner_radius_all(11)
		sb.anti_aliasing = true
		draw_style_box(sb, r)
		var inner := r.grow(-3.0)
		var fill_t := UiTheme.tones("lagon" if shielded else "fraise")
		if trail > ratio:
			var tr := StyleBoxFlat.new()
			tr.bg_color = Color("ffd6de")
			tr.set_corner_radius_all(9)
			draw_style_box(tr, Rect2(inner.position, Vector2(inner.size.x * trail, inner.size.y)))
		if ratio > 0.0:
			var fw := maxf(inner.size.x * ratio, 6.0)
			var f := StyleBoxFlat.new()
			f.bg_color = fill_t[1]
			f.set_corner_radius_all(9)
			f.anti_aliasing = true
			draw_style_box(f, Rect2(inner.position, Vector2(fw, inner.size.y)))
			var top := StyleBoxFlat.new()
			top.bg_color = fill_t[0]
			top.set_corner_radius_all(6)
			draw_style_box(top, Rect2(inner.position + Vector2(3, 2), Vector2(maxf(fw - 6.0, 0.0), inner.size.y * 0.3)))
			draw_line(Vector2(inner.position.x + fw, inner.position.y), Vector2(inner.position.x + fw, inner.end.y), ink, 3.0)
		for mk in marks:
			var x := inner.position.x + inner.size.x * float(mk.at)
			var done := bool(mk.done)
			var col := Color(ink, 0.45) if done else ink
			draw_line(Vector2(x, r.position.y - 2.0), Vector2(x, r.end.y + 1.0), col, 3.0)
			var tone := UiTheme.tones("gris" if done else String(mk.tone))
			draw_circle(Vector2(x, r.end.y + 4.0), 5.5, col)
			draw_circle(Vector2(x, r.end.y + 4.0), 3.5, tone[1])
		if text != "":
			var font := UiTheme.number_font()
			var fs := 16 if size.y < 32.0 else 18
			var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			var p := Vector2(r.get_center().x - w * 0.5, r.get_center().y + fs * 0.36)
			draw_string_outline(font, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 5, ink)
			draw_string(font, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)
