class_name Sfx
extends RefCounted
## Sons d'Eden Eternal (game/assets/sound) : dans l'espace 3D, d'interface (non spatialisés) et
## boucles d'ambiance (feux de camp, torches, fontaines). Sons d'interface et moments manga : bibliothèque
## maison SND-1 (game/assets/sfx/ui/, noms « ui/… », refaite par tools/art/snd_synth.py ; planche
## conception/art/snd/index.md) : tous à la même sonie de référence, le dB de l'appel fait la hiérarchie.

static var _cache := {}
static var volume_db := 0.0
static var _last_ui := {}  # son d'interface -> instant (pas deux fois dans la même image)
static var last_ui_ms := -1000  # dernier son d'interface joué (UiFeel n'en ajoute pas un second au même instant)

## Sons d'interface et de jeu, par rôle. Les UI0xx du client n'ont pas de nom : choisis d'après
## leur durée et leur force (clic court, coup bref, fanfare longue) ; à changer ici si l'un ne
## colle pas.
const UI := {
	"click": ["ui/release_1.wav", "ui/release_2.wav", "ui/release_3.wav"],  # clic de bouton (ancien : UI004.wav)
	"confirm": "ui/confirm.wav",  # carte choisie, validation, achat (ancien : UI007.wav)
	"level_up": "ui/level_up.wav",  # passage de niveau (ancien : UI083.wav, fanfare de 2,5 s)
	"chest": "ct001.wav",  # coffre ouvert
	"gold": "mm002.wav",  # or ramassé
	"pickup": "Itemtake01.wav",  # objet ramassé
	"station": "UI056.wav",  # lieu utilisé (enclume, autel…)
	"wood": ["HitWood01.wav", "HitWood02.wav"],  # jarre, caisse, tonneau cassés
	"rock": "HitRock01.wav",  # cristal brisé
	"error": "ui/deny.wav",  # action refusée (ancien : HitWood01.wav)
	# interface (UiFeel, bible de style § 7) : bibliothèque SND-1 ; une liste = variantes tirées au hasard
	"ui_hover": ["ui/hover_1.wav", "ui/hover_2.wav", "ui/hover_3.wav"],  # « tic » de bois du survol
	"ui_focus": ["ui/focus_1.wav", "ui/focus_2.wav", "ui/focus_3.wav"],  # note brève : le cadre de la manette avance
	"ui_press": ["ui/press_1.wav", "ui/press_2.wav", "ui/press_3.wav"],  # « pop » mat d'appui
	"ui_release": ["ui/release_1.wav", "ui/release_2.wav", "ui/release_3.wav"],  # « clic » clair de relâchement
	"ui_primary": "ui/primary.wav",  # bouton primaire relâché : pop + carillon montant
	"ui_deny": "ui/deny.wav",  # « bonk » rond : bouton désactivé
	"ui_tab": "ui/tab.wav",  # « flip » de papier : changement d'onglet
	"ui_toggle": "ui/toggle_on.wav",  # interrupteur (ancien nom)
	"ui_toggle_on": "ui/toggle_on.wav",  # clic-clac qui monte
	"ui_toggle_off": "ui/toggle_off.wav",  # clac-clic qui descend
	"ui_swoosh": "ui/swoosh.wav",  # carte d'activité
	"ui_equip": "ui/equip.wav",  # pièce équipée
	"ui_open": "ui/open.wav",  # page ou fenêtre qui s'ouvre
	"ui_close": "ui/close.wav",  # page qui se ferme
	"ui_card_flip": "ui/card_flip.wav",  # carte qui se retourne
	"ui_card_pick": "ui/card_pick.wav",  # « shing » : carte choisie
	"ui_notify": "ui/notify.wav",  # notification, nouveauté
	"ui_tick": "ui/tick.wav",  # compte à rebours (3, 2, 1)
	"ui_go": "ui/go.wav",  # « C'est parti ! »
	"ui_coin": ["ui/coin_1.wav", "ui/coin_2.wav", "ui/coin_3.wav"],  # or, pièces
	"ui_reward": "ui/reward_3.wav",  # récompense (ancien nom) ; par rareté : Sfx.reward(rareté)
	"ui_reward_1": "ui/reward_1.wav",  # objet commun ou spécial (2 notes)
	"ui_reward_2": "ui/reward_2.wav",  # rare (3 notes)
	"ui_reward_3": "ui/reward_3.wav",  # épique (4 notes + clochette)
	"ui_reward_4": "ui/reward_4.wav",  # mythique (5 notes + scintillement)
	"ui_reward_5": "ui/reward_5.wav",  # légendaire (6 notes + accord + étincelles)
	"ui_level_up": "ui/level_up.wav",  # niveau gagné
	"ui_star": "ui/star.wav",  # étoile gagnée
	"ui_record": "ui/record.wav",  # record battu
	"ui_victory": "ui/victory.wav",  # victoire (1,9 s)
	"ui_defeat": "ui/defeat.wav",  # défaite douce
	"ui_banner": "ui/banner.wav",  # bannière de moment manga (impact bref)
	"ui_forge_ok": "ui/forge_ok.wav",  # forge réussie
	"ui_forge_fail": "ui/forge_fail.wav",  # forge ratée
	"ui_hit": ["ui/hit_1.wav", "ui/hit_2.wav", "ui/hit_3.wav"],  # coup reçu léger (HUD)
	# combat de boss (lot DNG-2) : annonces à 3 niveaux et armement des zones, sons de la bibliothèque SND-1
	"alert_crit": "ui/banner.wav",  # annonce critique (bulle fraise) : impact bref
	"alert_mid": "ui/notify.wav",  # annonce moyenne (bulle lagon)
	"tele_arm": "ui/tick.wav",  # armement d'une zone de boss (télégraphe v2), court et discret
}

## Correction de volume (dB) des anciens noms passés à la bibliothèque SND-1, pour garder leur niveau d'avant.
const UI_DB := {"click": -5.0, "level_up": 2.0}
## Rareté d'objet (Items.RARITIES, 0 commun … 5 légendaire) -> son de récompense (5 tons).
const REWARD_BY_RARITY := [1, 1, 2, 3, 4, 5]


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


## Son d'interface [param name] (UI), non spatialisé, même pendant la pause ; [param pitch] : hauteur (1 = normale).
static func ui(name: String, vol := 0.0, pitch := 1.0) -> void:
	if Vfx.silent:
		return
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.current_scene == null:
		return
	var now := Time.get_ticks_msec()
	if now - int(_last_ui.get(name, -1000)) < 40:
		return
	_last_ui[name] = now
	last_ui_ms = now
	var stream := _stream(_pick(name))
	if stream == null:
		return
	var p := AudioStreamPlayer.new()
	p.stream = stream
	p.pitch_scale = pitch
	p.volume_db = vol + volume_db + float(UI_DB.get(name, 0.0))
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


## Nom du son de récompense d'une pièce de rareté [param rarity] (0 commun … 5 légendaire) : Sfx.ui(Sfx.reward(r)).
static func reward(rarity: int) -> String:
	return "ui_reward_%d" % int(REWARD_BY_RARITY[clampi(rarity, 0, REWARD_BY_RARITY.size() - 1)])


static func _pick(name: String) -> String:
	var v = UI.get(name, name)
	return String(v.pick_random()) if v is Array else String(v)


static func _stream(wav: String) -> AudioStream:
	if not _cache.has(wav):
		var path := ("res://assets/sfx/%s" if wav.begins_with("ui/") else "res://assets/sound/%s") % wav
		_cache[wav] = load(path) if ResourceLoader.exists(path) else null
	return _cache[wav]
