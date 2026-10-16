class_name HeroLook
extends RefCounted
## Création de personnage (lot C1) : nom du héros et visage (coiffure, couleur des cheveux, couleur des yeux).
## Le choix vaut pour toutes les classes ; une valeur vide garde ce que la classe porte d'origine (sa coiffure,
## sa couleur). Les apparences débloquées (tenue, tête, dos, auras) restent réglées par classe dans Héros > Apparence :
## la création règle le corps et le visage, les apparences règlent les tenues.
## État : `Profile.hero_name`, `Profile.hero_look` ({hair, hair_color, eyes}), `Profile.hero_made`.
## Rendu : `EdenModel.instantiate_hero(..., look)` et `Player._dress_model` (pièce de cheveux remplacée,
## teinte `use_tint` du shader eden_character sur la variante grise, iris `use_eye` + masque des yeux).

const HAIR_DIR := "res://assets/player/hairs/"
## Variante grise de chaque coiffure : la seule qui se teinte proprement (teinte sur la luminosité).
const GRAY := "a1c527"
const EYE_MASK := "res://assets/player/textures/lfaces01b_eyemask.png"
const FACE_MESH := "#LFACE"
const NAME_MIN := 3
const NAME_MAX := 16

## Coiffures : identifiant (préfixe des .glb de assets/player/hairs), nom.
const HAIRS := [
	["l103", "En bataille"],
	["l102", "Mi-longue"],
	["l107", "Longue"],
	["l105", "Queue de côté"],
	["l104", "Boucles"],
	["l108", "Tresse"],
]
## Couleur d'origine d'une coiffure de classe (suffixe de son .glb) -> couleur de la palette la plus proche : sert quand
## la coiffure choisie n'existe pas dans la couleur de la classe (variante grise teinte). "" = gris naturel.
const CLASS_COLORS := {"49c3eb": "black", "4e8340": "violet", "70726b": "red", "a1c527": "", "f83f5a": "blond",
	"5c1e37": "blue", "f29972": "chestnut", "aede18": "auburn", "615975": "platinum", "661c3f": "violet", "ae2fae": "green"}
## Couleurs des cheveux : identifiant, nom, couleur [r, g, b] (teinte appliquée à la coiffure grise).
const HAIR_COLORS := [
	["black", "Noir", [52, 52, 60]],
	["brown", "Brun", [104, 68, 46]],
	["chestnut", "Châtain", [150, 98, 58]],
	["auburn", "Roux", [196, 88, 40]],
	["blond", "Blond", [232, 196, 120]],
	["platinum", "Platine", [236, 232, 218]],
	["silver", "Argent", [178, 186, 206]],
	["red", "Rouge", [200, 40, 52]],
	["pink", "Rose", [236, 128, 176]],
	["violet", "Violet", [138, 82, 206]],
	["blue", "Bleu", [64, 110, 220]],
	["green", "Vert", [72, 164, 104]],
]
## Couleurs des yeux : identifiant, nom, couleur [r, g, b] ("" = les yeux bleus d'origine).
const EYE_COLORS := [
	["green", "Vert", [70, 190, 110]],
	["hazel", "Noisette", [170, 130, 60]],
	["brown", "Marron", [96, 56, 32]],
	["gray", "Gris", [150, 160, 176]],
	["violet", "Violet", [150, 90, 220]],
	["red", "Rouge", [220, 50, 50]],
	["amber", "Ambre", [236, 160, 40]],
	["ice", "Glacier", [150, 220, 240]],
]
## Filtre de noms (comparé au nom sans accents, en minuscules) : mots entiers seulement pour les plus courts.
const BANNED_WORDS := ["con", "cons", "pd", "fdp", "ntm", "tg", "nazi", "pute", "putes", "bite", "cul", "zob", "nique", "niquer",
	"chier", "shit", "cunt", "dick", "pedo"]
const BANNED_PARTS := ["connard", "connasse", "salope", "putain", "merde", "encule", "batard", "couille", "hitler", "fuck",
	"bitch", "nigg", "negre", "pedophile", "enfoire", "pouffiasse", "trouduc", "tamere", "tonpere"]
## Syllabes du nom proposé au hasard.
const NAME_START := ["Ae", "Ka", "Ly", "Tho", "Mae", "Ys", "Da", "El", "So", "Nae", "Or", "Ta", "Va", "Is", "Ca", "Ery",
	"Fae", "Ga", "Li", "Ze", "Mor", "Sel", "Ri", "Au", "Bra", "Ky"]
const NAME_END := ["ris", "len", "wyn", "ra", "dor", "lis", "ric", "nor", "thas", "via", "rin", "mir", "dan", "sa", "ren",
	"lia", "vel", "nis", "mon", "rel", "dric", "na", "ven"]


# --- nom ---------------------------------------------------------------------------------------
## Nom tel qu'il sera gardé : espaces en trop retirés.
static func tidy(raw: String) -> String:
	var s := raw.strip_edges()
	while s.contains("  "):
		s = s.replace("  ", " ")
	return s


## Message d'erreur du nom (texte court pour le joueur), "" s'il est valable.
static func name_error(raw: String) -> String:
	var s := tidy(raw)
	if s == "":
		return "Choisis un nom."
	if s.length() < NAME_MIN:
		return "Au moins %d lettres." % NAME_MIN
	if s.length() > NAME_MAX:
		return "%d lettres au plus." % NAME_MAX
	var letters := 0
	for ch in s:
		if ch == " " or ch == "-" or (ch >= "0" and ch <= "9"):
			continue
		if not _is_letter(ch):
			return "Lettres, chiffres, espace et tiret seulement."
		letters += 1
	if letters == 0:
		return "Il faut au moins une lettre."
	if not _polite(s):
		return "Ce nom n'est pas accepté."
	return ""


static func valid_name(raw: String) -> bool:
	return name_error(raw) == ""


## Lettre (accents compris) : une lettre change entre minuscule et majuscule.
static func _is_letter(ch: String) -> bool:
	return ch.to_lower() != ch.to_upper() or ch in ["ß", "ÿ"]


## Le nom passe-t-il le filtre de mots grossiers ?
static func _polite(s: String) -> bool:
	var flat := _plain(s)
	var joined := flat.replace(" ", "").replace("-", "")
	for p in BANNED_PARTS:
		if joined.contains(p):
			return false
	for w in flat.replace("-", " ").split(" ", false):
		if w in BANNED_WORDS:
			return false
	return true


## Minuscules sans accents (chiffres « l33t » ramenés aux lettres) : la forme comparée au filtre.
static func _plain(s: String) -> String:
	const FROM := "àâäáãåçéèêëíìîïñóòôöõúùûüýÿœæ013457@$"
	const TO := ["a", "a", "a", "a", "a", "a", "c", "e", "e", "e", "e", "i", "i", "i", "i", "n", "o", "o", "o", "o", "o",
		"u", "u", "u", "u", "y", "y", "oe", "ae", "o", "i", "e", "a", "s", "t", "a", "s"]
	var out := ""
	for ch in s.to_lower():
		var i := FROM.find(ch)
		out += TO[i] if i >= 0 else ch
	return out


## Nom proposé au hasard (toujours valable).
static func random_name(rng: RandomNumberGenerator = null) -> String:
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()
	for _i in 20:
		var n := String(NAME_START[rng.randi() % NAME_START.size()]) + String(NAME_END[rng.randi() % NAME_END.size()])
		if valid_name(n):
			return n
	return "Aelis"


## Nom du héros du joueur ("" tant qu'il n'en a pas).
static func hero_name() -> String:
	return Profile.hero_name


## Nom à afficher pour le joueur : son nom, sinon [param fallback] (« Toi », nom de la classe…).
static func name_or(fallback: String) -> String:
	return Profile.hero_name if Profile.hero_name != "" else fallback


## « Nom · Classe » (bilans), ou la classe seule tant que le héros n'a pas de nom.
static func who(cid: String) -> String:
	var cname := String(GameData.class_data(cid).get("name_fr", cid))
	return "%s · %s" % [Profile.hero_name, cname] if Profile.hero_name != "" else cname


## « Nom · titre porté » (en-tête du lobby) ; "" sans nom.
static func full_name() -> String:
	if Profile.hero_name == "":
		return ""
	return Profile.hero_name + (" · " + Profile.title if Profile.title != "" else "")


# --- visage -------------------------------------------------------------------------------------
## Apparence choisie (copie) : {hair, hair_color, eyes}, valeurs vides = celles de la classe.
static func current() -> Dictionary:
	return sanitize(Profile.hero_look)


## Apparence lue d'une sauvegarde : clés connues seulement, valeurs inconnues ramenées à "" (classe).
static func sanitize(d) -> Dictionary:
	var out := {"hair": "", "hair_color": "", "eyes": ""}
	if not d is Dictionary:
		return out
	var h := String(d.get("hair", ""))
	out.hair = h if _ids(HAIRS).has(h) else ""
	var c := String(d.get("hair_color", ""))
	out.hair_color = c if _ids(HAIR_COLORS).has(c) else ""
	var e := String(d.get("eyes", ""))
	out.eyes = e if _ids(EYE_COLORS).has(e) else ""
	return out


static func _ids(list: Array) -> Array:
	return list.map(func(x): return String(x[0]))


## Apparence d'origine (rien de changé : coiffure et couleurs de la classe).
static func is_default(look: Dictionary) -> bool:
	var s := sanitize(look)
	return s.hair == "" and s.hair_color == "" and s.eyes == ""


## Apparence tirée au hasard (coiffure, cheveux, yeux).
static func random_look(rng: RandomNumberGenerator = null) -> Dictionary:
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()
	return {"hair": String(HAIRS[rng.randi() % HAIRS.size()][0]),
		"hair_color": String(HAIR_COLORS[rng.randi() % HAIR_COLORS.size()][0]),
		"eyes": String(EYE_COLORS[rng.randi() % EYE_COLORS.size()][0]) if rng.randf() < 0.8 else ""}


static func _entry(list: Array, id: String) -> Array:
	for x in list:
		if String(x[0]) == id:
			return x
	return []


## Nom d'une coiffure, d'une couleur de cheveux ou d'yeux ("" = « D'origine »).
static func hair_name(id: String) -> String:
	var e := _entry(HAIRS, id)
	return String(e[1]) if not e.is_empty() else "Celle de la classe"


static func hair_color_name(id: String) -> String:
	var e := _entry(HAIR_COLORS, id)
	return String(e[1]) if not e.is_empty() else "D'origine"


static func eye_name(id: String) -> String:
	var e := _entry(EYE_COLORS, id)
	return String(e[1]) if not e.is_empty() else "D'origine"


static func hair_rgb(id: String) -> Color:
	var e := _entry(HAIR_COLORS, id)
	return Color8(int(e[2][0]), int(e[2][1]), int(e[2][2])) if not e.is_empty() else Color(0, 0, 0, 0)


static func eye_rgb(id: String) -> Color:
	var e := _entry(EYE_COLORS, id)
	return Color8(int(e[2][0]), int(e[2][1]), int(e[2][2])) if not e.is_empty() else Color(0.27, 0.45, 0.85)


## Coiffure de la classe : identifiant ("l107") et couleur d'origine ("49c3eb") lus dans le nom de son .glb.
static func class_hair(cls: Dictionary) -> Array:
	var parts: Array = cls.get("parts", [])
	if parts.size() < 2:
		return ["", ""]
	var f := String(parts[1]).get_file().get_basename()
	return [f.get_slice("_", 0), f.get_slice("_", 1)] if f.contains("_") else [f, ""]


## Cheveux à porter pour la classe [param cls] avec l'apparence [param look] : {path: .glb, tint: couleur de la palette
## à appliquer ("" : aucune teinte)}.
static func hair_choice(cls: Dictionary, look: Dictionary) -> Dictionary:
	var parts: Array = cls.get("parts", [])
	var orig := String(parts[1]) if parts.size() >= 2 else ""
	var s := sanitize(look)
	var out := {"path": orig, "tint": ""}
	if s.hair == "" and s.hair_color == "":
		return out
	var ch := class_hair(cls)
	var style: String = String(s.hair) if s.hair != "" else String(ch[0])
	if style == "":
		return out
	var gray := HAIR_DIR + "%s_%s.glb" % [style, GRAY]
	if s.hair_color != "":
		if ResourceLoader.exists(gray):
			out = {"path": gray, "tint": String(s.hair_color)}
		return out
	# coiffure choisie, couleur d'origine : la coiffure dans la couleur de la classe si elle existe, sinon la variante
	# grise teinte de la couleur la plus proche de celle de la classe
	var same := HAIR_DIR + "%s_%s.glb" % [style, ch[1]]
	if String(ch[1]) != "" and ResourceLoader.exists(same):
		return {"path": same, "tint": ""}
	if ResourceLoader.exists(gray):
		return {"path": gray, "tint": String(CLASS_COLORS.get(String(ch[1]), ""))}
	return out


static func hair_part(cls: Dictionary, look: Dictionary) -> String:
	return String(hair_choice(cls, look).path)


## Liste des pièces de la classe (tenue, cheveux) avec les cheveux de l'apparence.
static func with_hair(cls: Dictionary, parts: Array, look: Dictionary) -> Array:
	var out := parts.duplicate()
	if out.size() >= 2:
		out[1] = hair_part(cls, look)
	return out


## Teint les cheveux et les yeux d'un héros de la classe [param cls] déjà habillé (avec `with_hair`).
static func apply(model: Node3D, cls: Dictionary, look: Dictionary) -> void:
	var s := sanitize(look)
	var h := hair_choice(cls, s)
	if String(h.tint) != "" and String(h.path) != "":
		_tint_part(model, String(h.path), hair_rgb(String(h.tint)))
	if s.eyes != "":
		_tint_eyes(model, eye_rgb(s.eyes))


static func _tint_part(model: Node3D, path: String, col: Color) -> void:
	var tint := Vector3(col.r, col.g, col.b)
	for mi: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		if String(mi.get_meta("part", "")) != path:
			continue
		for i in mi.mesh.get_surface_count():
			var ov := mi.get_surface_override_material(i)
			if ov is ShaderMaterial:
				var m := (ov as ShaderMaterial).duplicate() as ShaderMaterial  # matériau partagé : copie propre à ce héros
				m.set_shader_parameter("use_tint", 1.0)
				m.set_shader_parameter("tint", tint)
				mi.set_surface_override_material(i, m)
			elif ov is BaseMaterial3D:
				var b := (ov as BaseMaterial3D).duplicate() as BaseMaterial3D
				b.albedo_color = Color(col.r, col.g, col.b, b.albedo_color.a)
				mi.set_surface_override_material(i, b)


static func _tint_eyes(model: Node3D, col: Color) -> void:
	if not ResourceLoader.exists(EYE_MASK):
		return
	var mask: Texture2D = load(EYE_MASK)
	for mi: MeshInstance3D in model.find_children(FACE_MESH, "MeshInstance3D", true, false):
		for i in mi.mesh.get_surface_count():
			var ov := mi.get_surface_override_material(i)
			if ov is ShaderMaterial:
				var m := (ov as ShaderMaterial).duplicate() as ShaderMaterial
				m.set_shader_parameter("use_eye", 1.0)
				m.set_shader_parameter("eye_mask", mask)
				m.set_shader_parameter("eye_color", Vector3(col.r, col.g, col.b))
				mi.set_surface_override_material(i, m)


## Le visage du héros a-t-il les yeux recolorés ? (tests)
static func eyes_tinted(model: Node3D) -> bool:
	for mi: MeshInstance3D in model.find_children(FACE_MESH, "MeshInstance3D", true, false):
		for i in mi.mesh.get_surface_count():
			var ov := mi.get_surface_override_material(i)
			if ov is ShaderMaterial and _on(ov, "use_eye"):
				return true
	return false


## Paramètre de shader allumé (> 0,5) ; un paramètre jamais posé vaut null.
static func _on(mat: ShaderMaterial, param: String) -> bool:
	var v = mat.get_shader_parameter(param)
	return v != null and float(v) > 0.5


## La pièce [param path] du modèle est-elle teinte ? (tests)
static func part_tinted(model: Node3D, path: String) -> bool:
	for mi: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		if String(mi.get_meta("part", "")) == path:
			for i in mi.mesh.get_surface_count():
				var ov := mi.get_surface_override_material(i)
				if ov is ShaderMaterial and _on(ov, "use_tint"):
					return true
	return false


# --- premier passage ---------------------------------------------------------------------------
## L'écran de création doit-il s'ouvrir tout seul ? (compte neuf après l'accueil, ou ancien compte une fois)
static func needs_creation() -> bool:
	return not Profile.hero_made


## Enregistre le nom et l'apparence (le nom n'est changé que s'il est valable).
static func save(name: String, look: Dictionary) -> void:
	if valid_name(name):
		Profile.hero_name = tidy(name)
	Profile.hero_look = sanitize(look)
	Profile.hero_made = true
	Profile.save_profile()


## « Garder tel quel » : la création ne se rouvrira plus d'elle-même (rien d'autre ne change).
static func skip() -> void:
	Profile.hero_made = true
	Profile.save_profile()
