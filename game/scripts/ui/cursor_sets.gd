class_name CursorSets
extends RefCounted
## Curseurs de souris au choix (Paramètres > Caméra & interface > Curseur). Un jeu de curseurs = quatre
## formes dessinées au script (tools/make_cursors.py, aucune image d'ailleurs) : flèche, main (boutons),
## texte et poing (glisser), en 32 et en 48 pixels (48 quand l'interface est agrandie). « Classique »
## laisse les curseurs du système. Appliqué par Settings (section « interface » et « display »).
## Ajouter un jeu : le dessiner dans tools/make_cursors.py (SETS), le relancer, puis l'ajouter à LIST.

const DIR := "res://assets/ui/cursors/"
const DEFAULT := "classic"
const HOTSPOTS := preload("res://scripts/ui/cursor_hotspots.gd").TABLE  # grille de 48 unités

## [identifiant, nom, détail (infobulle)].
const LIST := [
	["classic", "Classique", "La flèche de ton système."],
	["gauntlet", "Gantelet", "Flèche et main d'or, comme les cadres du jeu."],
	["blade", "Lame", "Une petite épée dont la pointe désigne la cible."],
	["crystal", "Cristal", "Un éclat de cristal bleu pâle."],
	["orb", "Orbe", "Une comète violette : la tête de l'orbe vise."],
	["feather", "Plume", "Une plume claire, fine et discrète."],
	["flame", "Flamme", "Une flamme orange, bien visible en pleine mêlée."],
	["rune", "Rune", "Une pierre verte gravée d'une rune."],
	["star", "Étoile", "Une baguette terminée par une étoile."],
	["shadow", "Ombre", "Une flèche violette sombre, cernée de clair."],
]
## Formes de curseur du moteur remplacées pour chaque forme dessinée.
const SHAPES := {
	"arrow": [Input.CURSOR_ARROW],
	"hand": [Input.CURSOR_POINTING_HAND],
	"text": [Input.CURSOR_IBEAM],
	"drag": [Input.CURSOR_DRAG, Input.CURSOR_CAN_DROP],
}

static var applied := ""  # jeu en place (aussi sans fenêtre : les tests le lisent)
static var applied_size := 0
static var _images := {}


static func is_known(id: String) -> bool:
	return LIST.any(func(e): return e[0] == id)


## Jeu choisi dans les réglages ; une valeur inconnue ou abîmée redonne « classic ».
static func current() -> String:
	var id := str(Settings.get_v("interface", "cursor_set"))
	return id if is_known(id) else DEFAULT


static func name_of(id: String) -> String:
	for e in LIST:
		if e[0] == id:
			return e[1]
	return String(LIST[0][1])


## 48 quand l'interface est agrandie ou l'écran très défini, sinon 32 (un curseur n'est pas mis à l'échelle par le moteur).
static func pixel_size() -> int:
	var big := float(Settings.get_v("display", "ui_scale")) >= 1.25
	if DisplayServer.get_name() != "headless" and DisplayServer.screen_get_scale() >= 1.5:
		big = true
	return 48 if big else 32


static func path(id: String, kind: String, size: int) -> String:
	return "%s%s_%s_%d.png" % [DIR, id, kind, size]


## Image d'une forme ([param kind] : arrow, hand, text, drag), null pour « classic » ou si le fichier manque.
static func image(id: String, kind: String, size: int) -> Image:
	if id == DEFAULT or not is_known(id):
		return null
	var p := path(id, kind, size)
	if _images.has(p):
		return _images[p]
	var img: Image = null
	if ResourceLoader.exists(p):
		var tex := load(p) as Texture2D
		if tex != null:
			img = tex.get_image()
			if img != null and img.is_compressed():
				img.decompress()
	if img == null and FileAccess.file_exists(p):
		var raw := Image.new()
		if raw.load(ProjectSettings.globalize_path(p)) == OK:
			img = raw
	_images[p] = img
	return img


## Point chaud en pixels de l'image de [param size].
static func hotspot(id: String, kind: String, size: int) -> Vector2:
	var h: Vector2i = HOTSPOTS.get(id, {}).get(kind, Vector2i.ZERO)
	return Vector2(clampi(roundi(h.x * size / 48.0), 0, size - 1), clampi(roundi(h.y * size / 48.0), 0, size - 1))


## Pose le jeu choisi sur les formes de curseur du moteur (rien à faire si déjà en place).
static func apply() -> void:
	var id := current()
	var size := pixel_size()
	if id == applied and size == applied_size:
		return
	applied = id
	applied_size = size
	if DisplayServer.get_name() == "headless":
		return
	for kind in SHAPES:
		var img := image(id, kind, size)
		var hot := hotspot(id, kind, size)
		for shape in SHAPES[kind]:
			Input.set_custom_mouse_cursor(img, shape, hot)  # null : curseur du système
