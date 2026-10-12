class_name Sfx
extends RefCounted
## Sons d'Eden Eternal (game/assets/sound) joués dans l'espace 3D.

static var _cache := {}
static var volume_db := 0.0


static func play_at(parent: Node, pos: Vector3, wav: String, vol := 0.0, pitch_jitter := 0.06) -> void:
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


static func _stream(wav: String) -> AudioStream:
	if not _cache.has(wav):
		var path := "res://assets/sound/%s" % wav
		_cache[wav] = load(path) if ResourceLoader.exists(path) else null
	return _cache[wav]
