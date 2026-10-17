class_name Ico
extends RefCounted
## Pictogrammes d'interface maison (lot ICO-1) : coche, cadenas, étoile, activités, ressources, rangs, mécaniques de boss, touches…
## Fichiers `assets/ui/icons/ico_<id>.png` (128 px) et `ico_<id>_64.png` (64 px), fabriqués par `tools/art/ico_gen.py`
## (catalogue et planche : `conception/art/ico/planche.jpg`, rapport `conception/art/R_ICO1.md`).
## Les icônes du jeu (sorts, objets, classes, statuts) ne passent pas ici : on ne crée que ce qui manque.
##   Ico.tex("check")            texture (la version 64 px sous 48 px d'affichage)
##   Ico.rect("lock", 18)        TextureRect prêt à poser dans une rangée (ignore la souris)
##   Ico.of_boss(type)           mécanique de boss (BossBricks, attaques de base, fureur) ; null si absente
## `id` inconnu : null, jamais d'erreur (l'appelant garde alors son texte).

const FILE := "res://assets/ui/icons/ico_%s%s.png"
## Sous cette taille d'affichage (px), on lit la version 64 px : elle est nette sans filtre de réduction.
const SMALL_PX := 48


static func path(id: String, px := 0) -> String:
	return FILE % [id, "_64" if px > 0 and px <= SMALL_PX else ""]


static func has(id: String) -> bool:
	return FileAccess.file_exists(FILE % [id, ""]) or ResourceLoader.exists(FILE % [id, ""])


static func tex(id: String, px := 0) -> Texture2D:
	if id == "":
		return null
	return UiTheme.texture(path(id, px))


## Une image carrée de [param px] pixels, centrée dans sa rangée ; null si l'icône manque.
static func rect(id: String, px := 20, tint := Color.WHITE) -> TextureRect:
	var t := tex(id, px)
	if t == null:
		return null
	var r := TextureRect.new()
	r.texture = t
	r.custom_minimum_size = Vector2(px, px)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.modulate = tint
	return r


## Mécanique de boss : brique (« meteors »), attaque de base (« slams »), « phase2 » (fureur) ; « boss_hit » à défaut.
static func of_boss(type: String) -> Texture2D:
	var t := tex("boss_" + type, 40)
	return t if t != null else tex("boss_hit", 40)


## Rang de la Ligue : 0 non classé, 1 Bronze … 4 Platine.
static func rank(i: int) -> Texture2D:
	return tex("rank_%d" % clampi(i, 0, 4), 40)


## Difficulté d'un donjon : 0 Normal, 1 Héroïque, 2 Mythique.
static func difficulty(i: int) -> Texture2D:
	return tex(["diff_normal", "diff_heroic", "diff_mythic"][clampi(i, 0, 2)], 40)


## Rareté : 0 Commun … 5 Légendaire.
static func rarity(i: int) -> Texture2D:
	return tex("rar_%d" % clampi(i, 0, 5), 40)


## Silhouette d'un emplacement d'équipement (Items.SLOTS, « offhand », « trophy »).
static func slot(id: String) -> Texture2D:
	return tex("slot_" + id, 64)


## Ressource de ResourceHelp.KINDS ; null si elle n'a pas d'icône maison.
static func resource(kind: String, px := 20) -> Texture2D:
	return tex("res_" + kind, px)


## Marque d'une rangée (coche, croix, étape à faire…) ajoutée à [param parent] : remplace le symbole écrit en texte.
static func mark(parent: Node, id: String, px := 18) -> TextureRect:
	var r := rect(id, px)
	if r == null:
		return null
	r.custom_minimum_size = Vector2(px + 2, px)
	parent.add_child(r)
	return r


## Bouton verrouillé : cadenas à gauche du texte ; [param done] : coche à la place (victoire déjà obtenue). Sinon rien.
static func state(b: Button, locked: bool, done := false, px := 18) -> void:
	var id := "lock" if locked else ("check" if done else "")
	if id == "":
		return
	b.icon = tex(id, px)
	b.expand_icon = false
	b.add_theme_constant_override("icon_max_width", px)
	b.add_theme_constant_override("h_separation", 6)
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER if b.text.strip_edges() == "" else HORIZONTAL_ALIGNMENT_LEFT


static func lock(b: Button, locked := true, px := 18) -> void:
	state(b, locked, false, px)


## Cadenas pour un texte BBCode (RichTextLabel) : remplace « 🔒 » (emoji hors de la police du jeu).
const LOCK_BB := "[img=16]res://assets/ui/icons/ico_lock_64.png[/img]"
