extends Node
## Musique d'Eden Eternal (game/assets/music, tirée du dossier bgm du client) : une piste par
## zone (celle de sa carte d'Eden, colonne bgm de c_node), le lobby, le boss, la rage, le duel
## et la Tour ; fondu enchaîné entre deux pistes, en boucle. Volume : Paramètres > Son.

const DIR := "res://assets/music/%s.ogg"
## Piste de chaque zone (scène d'Eden de la zone : c_node, colonne bgm).
const ZONES := {"limestone": "bgm007", "rainbowfall": "bgm008", "beluga": "bgm013", "wetlands": "bgm009",
	"avila": "bgm012", "arid": "aridwilds", "delphi": "bgm017", "blackflame": "blackflame"}
const MENU := "bgm_menu"
const BOSS := "bgm018"  # donjon d'Eden (S101)
const RAGE := "bgm005"
const DUEL := "gvgbgm"  # guerre de guildes
const TOWER := "bgm014"  # donjon d'Eden (S102)
const FADE := 1.6

var volume := 0.6  # 0 → 1 (Paramètres > Son > Musique)
var _players: Array[AudioStreamPlayer] = []
var _cur := 0
var _track := ""
var _cache := {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # la musique continue pendant la pause
	volume = float(Settings.get_v("audio", "music")) if Settings.get_v("audio", "music") != null else volume
	for i in 2:
		var p := AudioStreamPlayer.new()
		p.volume_db = -80.0
		add_child(p)
		_players.append(p)


## Joue [param track] (nom de fichier sans .ogg) en fondu ; rien si c'est déjà elle.
func play(track: String) -> void:
	if track == _track or Vfx.silent:
		return
	var stream := _stream(track)
	if stream == null:
		return
	_track = track
	var old := _players[_cur]
	_cur = 1 - _cur
	var p := _players[_cur]
	p.stream = stream
	p.volume_db = -50.0
	p.play()
	var tw := create_tween().set_parallel()
	tw.tween_property(p, "volume_db", _db(), FADE)
	if old.playing:
		tw.tween_property(old, "volume_db", -60.0, FADE)
		tw.chain().tween_callback(old.stop)


func stop() -> void:
	_track = ""
	for p in _players:
		if p.playing:
			var tw := create_tween()
			tw.tween_property(p, "volume_db", -60.0, FADE)
			tw.tween_callback(p.stop)


## Piste de la zone [param zone_id] (sinon celle de Limestone).
func play_zone(zone_id: String) -> void:
	play(String(ZONES.get(zone_id, ZONES.limestone)))


func current() -> String:
	return _track


func set_volume(v: float) -> void:
	volume = clampf(v, 0.0, 1.0)
	var p := _players[_cur] if not _players.is_empty() else null
	if p and p.playing:
		p.volume_db = _db()


func _db() -> float:
	return linear_to_db(maxf(volume, 0.0001))


func _stream(track: String) -> AudioStream:
	if not _cache.has(track):
		var path := DIR % track
		var s: AudioStream = load(path) if ResourceLoader.exists(path) else null
		if s is AudioStreamOggVorbis:
			(s as AudioStreamOggVorbis).loop = true
		_cache[track] = s
	return _cache[track]
