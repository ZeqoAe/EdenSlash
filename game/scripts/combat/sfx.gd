class_name Sfx
extends RefCounted
## Sons d'Eden Eternal (game/assets/sound) : dans l'espace 3D, d'interface (non spatialisés) et
## boucles d'ambiance (feux de camp, torches, fontaines).

static var _cache := {}
static var volume_db := 0.0
static var _last_ui := {}  # son d'interface -> instant (pas deux fois dans la même image)

## Sons d'interface et de jeu, par rôle. Les UI0xx du client n'ont pas de nom : choisis d'après
## leur durée et leur force (clic court, coup bref, fanfare longue) ; à changer ici si l'un ne
## colle pas.
const UI := {
	"click": "UI004.wav",  # clic de bouton (0,06 s)
	"confirm": "UI007.wav",  # carte choisie, validation (0,24 s)
	"level_up": "UI083.wav",  # passage de niveau (fanfare, 2,5 s)
	"chest": "ct001.wav",  # coffre ouvert
	"gold": "mm002.wav",  # or ramassé
	"pickup": "Itemtake01.wav",  # objet ramassé
	"station": "UI056.wav",  # lieu utilisé (enclume, autel…)
	"wood": ["HitWood01.wav", "HitWood02.wav"],  # jarre, caisse, tonneau cassés
	"rock": "HitRock01.wav",  # cristal brisé
}


static func play_at(parent: Node, pos: Vector3, wav: String, vol := 0.0, pitch_jitter := 0.06) -> void:
	if Vfx.silent:
		return
	if wav == "" or parent == null or not parent.is_inside_tree():
		return
	var stream := _stream(wav)
	if stream == null:
		return
	var p := AudioStreamPlayer3D.new()
	p.stream = stream
	p.volume_db = vol + volume_db
	p.unit_size = 12.0
	p.max_distance = 60.0
	p.pitch_scale = 1.0 + randf_range(-pitch_jitter, pitch_jitter)
	parent.get_tree().current_scene.add_child(p)
	p.global_position = pos
	p.finished.connect(p.queue_free)
	p.play()


## Son du rôle [param name] (UI) à la position [param pos] (dans le monde).
static func event_at(parent: Node, pos: Vector3, name: String, vol := 0.0) -> void:
	play_at(parent, pos, _pick(name), vol, 0.08)


## Son d'interface [param name] (UI), non spatialisé, même pendant la pause.
static func ui(name: String, vol := 0.0) -> void:
	if Vfx.silent:
		return
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.current_scene == null:
		return
	var now := Time.get_ticks_msec()
	if now - int(_last_ui.get(name, -1000)) < 40:
		return
	_last_ui[name] = now
	var stream := _stream(_pick(name))
	if stream == null:
		return
	var p := AudioStreamPlayer.new()
	p.stream = stream
	p.volume_db = vol + volume_db
	p.process_mode = Node.PROCESS_MODE_ALWAYS
	tree.current_scene.add_child(p)
	p.finished.connect(p.queue_free)
	p.play()


## Boucle d'ambiance [param wav] attachée à [param parent] (feu de camp, torche, fontaine) :
## audible de près seulement.
static func loop_at(parent: Node3D, offset: Vector3, wav: String, vol := -6.0, max_dist := 16.0) -> void:
	if Vfx.silent:
		return
	var stream := _stream(wav)
	if stream == null:
		return
	if stream is AudioStreamWAV:
		var w := (stream as AudioStreamWAV).duplicate() as AudioStreamWAV
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		var bytes := 2 if w.format == AudioStreamWAV.FORMAT_16_BITS else 1
		w.loop_end = w.data.size() / (bytes * (2 if w.stereo else 1))
		stream = w
	var p := AudioStreamPlayer3D.new()
	p.stream = stream
	p.volume_db = vol + volume_db
	p.unit_size = 4.0
	p.max_distance = max_dist
	p.autoplay = true
	p.position = offset
	parent.add_child(p)


static func _pick(name: String) -> String:
	var v = UI.get(name, name)
	return String(v.pick_random()) if v is Array else String(v)


static func _stream(wav: String) -> AudioStream:
	if not _cache.has(wav):
		var path := "res://assets/sound/%s" % wav
		_cache[wav] = load(path) if ResourceLoader.exists(path) else null
	return _cache[wav]
