class_name SurvivorHud
extends VBoxContainer
## HUD du Survivant (lot S5, SPEC §10.3), sous l'en-tête du panneau d'objectifs : la frise des 20 minutes (le temps
## écoulé, les gardiens à 5, 10 et 15 min : gris à venir, rouge à l'annonce et tant qu'il est debout, or une fois vaincu ;
## le portail à 15:00, le boss à 20:00), puis dans l'arène la jauge de la rage du boss (encoches à chaque palier) ; et une
## ligne « Équipement 6 / 9 · Sorts 4 / 6 ». Le chronomètre (temps avant le boss) reste dans l'en-tête du panneau.

const H := 34.0
const RED := Color(1.0, 0.36, 0.3)
const VIOLET := Color(0.72, 0.5, 1.0)

var director: RunDirector
var _bar: Control
var _build: Label
var _sig := ""


## Pose la frise dans le panneau d'objectifs [param panel] (sous son en-tête).
static func attach(panel: PanelContainer, d: RunDirector) -> SurvivorHud:
	var s := SurvivorHud.new()
	s.director = d
	var v := panel.get_child(0) as VBoxContainer
	v.add_child(s)
	v.move_child(s, 1)
	return s


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override("separation", 0)
	_bar = Control.new()
	_bar.custom_minimum_size = Vector2(0, H)
	_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar.draw.connect(_draw_bar)
	add_child(_bar)
	_build = Hud._label(self, "", UiTheme.MIN_TEXT, Color(0.85, 0.83, 0.93))


func _process(_delta: float) -> void:
	if director == null or not is_instance_valid(director):
		return
	_bar.queue_redraw()
	var t := "Équipement %d / %d  ·  Sorts %d / %d" % [SurvivorGear.worn().size(), Items.SLOTS.size(), Run.all_skills().size(), Survivor.SPELL_MAX]
	if t != _sig:
		_sig = t
		_build.text = t


## Le gardien [param n] : 0 à venir, 1 annoncé ou debout, 2 vaincu.
func guardian_state(n: int) -> int:
	if director.sv == null:
		return 0
	for e in director.sv.guardians:
		if int(e.n) == n:
			return 2 if float(e.ttk) >= 0.0 else 1
	var at := float(Survivor.GUARDIAN_TIMES[n])
	return 1 if director.time >= at - SurvivorDirector.GUARDIAN_WARN and director.time < at + 1.0 else 0


func _draw_bar() -> void:
	if director == null or not is_instance_valid(director):
		return
	if director.state in ["boss", "cleared"]:
		_draw_boss()
	else:
		_draw_run()


func _track(r: Rect2, k: float, fill: Color) -> void:
	_bar.draw_rect(r.grow(1.0), Color(0.02, 0.01, 0.05, 0.9))
	_bar.draw_rect(r, Color(0.16, 0.14, 0.25))
	_bar.draw_rect(Rect2(r.position, Vector2(r.size.x * clampf(k, 0.0, 1.0), r.size.y)), fill)


func _tick_label(x: float, s: String, col: Color) -> void:
	var font := UiTheme.bold_font()
	var w := font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, UiTheme.MIN_TEXT).x
	_bar.draw_string(font, Vector2(clampf(x - w * 0.5, 0.0, _bar.size.x - w), H - 2.0), s, HORIZONTAL_ALIGNMENT_LEFT, -1, UiTheme.MIN_TEXT, col)


## Frise des 20 minutes.
func _draw_run() -> void:
	var r := Rect2(6.0, 6.0, _bar.size.x - 12.0, 6.0)
	var total := Survivor.RUN_TIME
	var t := clampf(director.time, 0.0, total)
	_track(r, t / total, Color(0.98, 0.78, 0.35, 0.9))
	var pulse := 0.6 + 0.4 * sin(Time.get_ticks_msec() * 0.012)
	# portail (15:00) : un trait violet ; boss (20:00) : un losange rouge au bout
	var px := r.position.x + r.size.x * Survivor.BOSS_OPEN_AT / total
	_bar.draw_line(Vector2(px, r.position.y - 5.0), Vector2(px, r.end.y + 5.0), VIOLET, 2.0)
	for i in Survivor.GUARDIAN_TIMES.size():
		var at := float(Survivor.GUARDIAN_TIMES[i])
		var x := r.position.x + r.size.x * at / total
		var st := guardian_state(i)
		var c: Color = [Color(0.55, 0.52, 0.66), Color(RED, pulse), UiTheme.GOLD][st]
		HudWidgets.diamond(_bar, Vector2(x, r.get_center().y), 8.0, Color(0.03, 0.02, 0.06))
		HudWidgets.diamond(_bar, Vector2(x, r.get_center().y), 6.0 if st != 1 else 6.0 + 1.5 * pulse, c)
		_tick_label(x, "%d:00" % int(at / 60.0), c if st != 0 else Color(0.75, 0.73, 0.85))
	var bx := r.end.x - 1.0
	HudWidgets.diamond(_bar, Vector2(bx, r.get_center().y), 8.0, Color(0.03, 0.02, 0.06))
	HudWidgets.diamond(_bar, Vector2(bx, r.get_center().y), 6.0, RED if director.time < total else Color(RED, pulse))
	_tick_label(bx, "Boss", RED)
	# curseur du temps écoulé
	var cx := r.position.x + r.size.x * t / total
	_bar.draw_line(Vector2(cx, r.position.y - 4.0), Vector2(cx, r.end.y + 4.0), Color.WHITE, 2.0)


## Arène : jauge de la rage du boss (0 → dernier palier), une encoche par palier (×1,1, ×2, ×11, ×101).
func _draw_boss() -> void:
	var r := Rect2(6.0, 6.0, _bar.size.x - 12.0, 6.0)
	var start := director._boss_rage_start()
	var steps := RunDirector.RAGE_TIERS.size()
	var total := start + RunDirector.RAGE_STEP * (steps - 1)
	var t := clampf(director._boss_time, 0.0, total)
	var tier := director.boss_rage_tier()
	_track(r, t / total, RED if tier > 0 else Color(0.98, 0.78, 0.35, 0.9))
	for k in steps:
		var at := start + RunDirector.RAGE_STEP * k
		var x := r.position.x + r.size.x * at / total
		var on := tier > k
		_bar.draw_rect(Rect2(x - 1.5, r.position.y - 5.0, 3.0, r.size.y + 10.0), RED if on else Color(1.0, 0.85, 0.4))
		if k == 0 and not on:
			_tick_label(x, "Rage", Color(0.95, 0.85, 0.6))
		elif on:
			_tick_label(x, "×%s" % RunDirector.fmt_mult(RunDirector.rage_mult(k + 1)), RED)
	var cx := r.position.x + r.size.x * t / total
	_bar.draw_line(Vector2(cx, r.position.y - 4.0), Vector2(cx, r.end.y + 4.0), Color.WHITE, 2.0)
