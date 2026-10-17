class_name RoyaleAmbience
extends Node
## Son et ambiance du Battle royale (lot BR-I3) :
## - moments courts (cue) : portes de l'aigle, saut, planeur, atterrissage, compte à rebours avant le resserrement de
##   l'anneau, annonces de danger, K.O., coup donné ; sons de la bibliothèque maison SND-1 (Sfx « ui_… », synthétisés)
##   et vibration courte à la manette (réglage interface/combat_vibration) ;
## - ambiance continue synthétisée ici (aucun fichier tiers) : vent pendant le vol et la chute (plus fort en piqué, doux
##   sous le planeur) et grondement grave près du mur de l'anneau (plus fort dehors). AudioStreamGenerator, bruit filtré et
##   deux sinus ; rien n'est calculé quand le volume visé est nul.
## Posé par RoyaleHud ; « Voir les sons » (RoyaleCues) montre les mêmes sons à l'écran.

## Moments : [rôle Sfx, dB, hauteur, vibration [faible, fort, s] ou []].
const CUES := {
	"doors": ["ui_go", -9.0, 1.0, [0.1, 0.0, 0.05]],  # portes ouvertes : on peut sauter
	"jump": ["ui_swoosh", -6.0, 0.9, [0.2, 0.0, 0.06]],
	"glide": ["ui_open", -10.0, 0.8, []],
	"land": ["rock", -6.0, 0.7, [0.25, 0.2, 0.08]],
	"tick": ["ui_tick", -6.0, 1.0, []],  # 5, 4, 3, 2, 1 avant le resserrement
	"shrink": ["ui_banner", -5.0, 0.75, [0.0, 0.3, 0.12]],
	"danger": ["ui_deny", -8.0, 0.85, [0.0, 0.25, 0.08]],
	"drop": ["ui_notify", -6.0, 1.0, []],
	"win": ["ui_star", -6.0, 1.0, [0.3, 0.45, 0.18]],
	"ko": ["ui_banner", -4.0, 1.1, [0.3, 0.45, 0.15]],
	"hit": ["ui_focus", -15.0, 1.25, [0.12, 0.0, 0.03]],  # « tic » du coup donné
	"crit": ["ui_star", -11.0, 1.3, [0.2, 0.1, 0.05]],
}
const MIX_RATE := 11025.0  # (vent et grondement : pas besoin d'aigus ; moitié moins de calcul)
const WIND_DB := -14.0
const HUM_RANGE := 26.0  # m : on entend le mur de l'anneau à moins de cette distance

static var last_cue := ""  # (tests)
static var _cue_ms := {}

var player: Player
var director: RunDirector
var wind := 0.0  # volume visé du vent (0 à 1)
var hum := 0.0  # volume visé du grondement de l'anneau
var _wind_now := 0.0
var _hum_now := 0.0
var _gen: AudioStreamPlayer
var _pb: AudioStreamGeneratorPlayback
var _lp := 0.0
var _lp2 := 0.0
var _osc_a := Vector2(1, 0)  # sinus par rotation (cos, sin) : pas de sin() par échantillon
var _osc_b := Vector2(1, 0)
var _tremolo := 0.0
var _tick_left := -1  # dernier chiffre du compte à rebours joué
var _was_state := ""
var _was_riding := false
var _was_glide := false
var _was_air := false
var _doors := false


## Joue le moment [param name] (CUES) : son et vibration (une seule fois toutes les 60 ms par moment).
static func cue(name: String) -> void:
	if not CUES.has(name):
		return
	var now := Time.get_ticks_msec()
	if now - int(_cue_ms.get(name, -1000)) < 60:
		return
	_cue_ms[name] = now
	last_cue = name
	var c: Array = CUES[name]
	Sfx.ui(String(c[0]), float(c[1]), float(c[2]) * randf_range(0.98, 1.02))
	vibrate(c[3])


## Vibration de combat [param v] = [faible, fort, s] (réglage interface/combat_vibration, manette active).
static func vibrate(v: Array) -> void:
	if v.size() < 3 or not Gamepad.active or not bool(Settings.get_v("interface", "combat_vibration")):
		return
	var pads := Input.get_connected_joypads()
	if not pads.is_empty():
		Input.start_joy_vibration(int(pads[0]), clampf(float(v[0]), 0.0, 1.0), clampf(float(v[1]), 0.0, 1.0), float(v[2]))


func setup(p: Player, d: RunDirector) -> void:
	player = p
	director = d
	name = "RoyaleAmbience"


func _rd() -> RoyaleDirector:
	return director.royale if director != null else null


func _process(delta: float) -> void:
	var rd := _rd()
	if rd == null or player == null or not is_instance_valid(player):
		return
	_moments(rd)
	_targets(rd)
	_wind_now = move_toward(_wind_now, wind, delta * 1.5)
	_hum_now = move_toward(_hum_now, hum, delta * 0.8)
	if (_wind_now > 0.001 or _hum_now > 0.001) and not Vfx.silent:
		_feed()
	elif _gen != null and _gen.playing:
		_gen.stop()
		_pb = null


## Moments du largage et de l'anneau.
func _moments(rd: RoyaleDirector) -> void:
	var j := rd.jump
	var riding: bool = j != null and j.on_board(player)
	var air: bool = j != null and j.airborne(player)
	if riding and not _doors and j.t >= Royale.COUNTDOWN:
		_doors = true
		cue("doors")
	if _was_riding and not riding and air:
		cue("jump")
	var glide: bool = air and String(j.riders[player].state) == "glide"
	if glide and not _was_glide:
		cue("glide")
	if _was_air and not air and not player.is_dead:
		cue("land")
	_was_riding = riding
	_was_glide = glide
	_was_air = air
	if rd.phase != "fight" or rd.ring.is_empty():
		return
	var state := String(rd.ring.get("state", ""))
	if state == "hold":
		var left := ceili(float(rd.ring.get("left", 0.0)))
		if left <= 5 and left >= 1 and left != _tick_left and int(rd.ring.get("phase", 0)) < Royale.PHASES.size() - 1:
			_tick_left = left
			cue("tick")
	if state == "shrink" and _was_state == "hold":
		cue("shrink")
		_tick_left = -1
	_was_state = state


## Volumes visés : vent selon l'état en l'air, grondement selon la distance au mur de l'anneau.
func _targets(rd: RoyaleDirector) -> void:
	wind = 0.0
	var j := rd.jump
	if j != null and j.airborne(player):
		match String(j.riders[player].state):
			"ride":
				wind = 0.3
			"glide":
				wind = 0.35
			_:
				wind = 0.95 if Input.is_action_pressed("dodge") else 0.65
	hum = 0.0
	if rd.phase == "fight" and not rd.ring.is_empty() and not player.is_dead:
		var c: Vector2 = rd.ring.center
		var d := Vector2(player.global_position.x, player.global_position.z).distance_to(c) - float(rd.ring.radius)
		if d > -HUM_RANGE:
			hum = clampf(1.0 - absf(d) / HUM_RANGE, 0.0, 1.0) * (1.0 if d > 0.0 else 0.6)
			if d > 0.0:
				hum = maxf(hum, 0.55)  # dehors : il reste présent


func _ensure() -> void:
	if _gen != null:
		if not _gen.playing:
			_gen.play()
			_pb = _gen.get_stream_playback() as AudioStreamGeneratorPlayback
		return
	var st := AudioStreamGenerator.new()
	st.mix_rate = MIX_RATE
	st.buffer_length = 0.2
	_gen = AudioStreamPlayer.new()
	_gen.stream = st
	_gen.volume_db = WIND_DB + Sfx.volume_db
	add_child(_gen)
	_gen.play()
	_pb = _gen.get_stream_playback() as AudioStreamGeneratorPlayback


## Remplit le tampon : bruit filtré deux fois (vent, plus clair quand il souffle fort) + deux sinus graves (anneau).
func _feed() -> void:
	_ensure()
	if _pb == null:
		return
	var n := mini(_pb.get_frames_available(), int(MIX_RATE * 0.1))
	if n <= 0:
		return
	var buf := PackedVector2Array()
	buf.resize(n)
	var cut := 0.04 + 0.08 * _wind_now  # filtre passe-bas (part du nouvel échantillon)
	var wa := _wind_now * 0.55
	var ha := _hum_now * 0.32
	var ra := Vector2(cos(TAU * 55.0 / MIX_RATE), sin(TAU * 55.0 / MIX_RATE))
	var rb := Vector2(cos(TAU * 82.5 / MIX_RATE), sin(TAU * 82.5 / MIX_RATE))
	_tremolo = fmod(_tremolo + TAU * 0.7 * float(n) / MIX_RATE, TAU)
	ha *= 0.75 + 0.25 * sin(_tremolo)
	var wk := 3.0 * wa
	for i in n:
		_lp += (randf() * 2.0 - 1.0 - _lp) * cut
		_lp2 += (_lp - _lp2) * cut
		_osc_a = Vector2(_osc_a.x * ra.x - _osc_a.y * ra.y, _osc_a.x * ra.y + _osc_a.y * ra.x)
		_osc_b = Vector2(_osc_b.x * rb.x - _osc_b.y * rb.y, _osc_b.x * rb.y + _osc_b.y * rb.x)
		var s := _lp2 * wk + (_osc_a.y * 0.7 + _osc_b.y * 0.3) * ha
		buf[i] = Vector2(s, s)
	_osc_a = _osc_a.normalized()  # (la rotation dérive à la longue)
	_osc_b = _osc_b.normalized()
	_pb.push_buffer(buf)
