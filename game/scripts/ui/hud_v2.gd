class_name HudV2
extends RefCounted
## HUD en partie v2 (lot HUD-2 ; étude BM-HUB P0-8, P1-3, croquis `conception/benchmark/hub_maquettes/hud.html` ; bible § 5,
## § 10) : pièces dessinées du HUD commun (`Hud` : Survie, Donjons, Tour, Ruée, Siège, Duel, Arènes, entraînement ; le Battle
## royale et le Survivant posent leurs propres modules par-dessus) :
##   - LifeGauge : la vie en jauge large autocollante (creux d'encre, fraise deux tons, trace claire des dégâts, chiffre contouré),
##     sous les cases de sorts comme celle du Survivant ; elle pulse sous 30 % ;
##   - LevelBar : la barre de niveau lagon et sa pastille « Niv. 8 » à la place du globe ; le niveau d'aide (« Assisté ») en
##     étiquette à côté ; aucun pourcentage permanent (il reste dans l'infobulle) ;
##   - MapRing : le cadre papier de la mini-carte ronde (bande papier entre deux contours d'encre, ombre dure) au lieu des
##     anneaux dorés ;
##   - les profils du HUD (Paramètres > Affichage > HUD en partie) : Standard (tout), Compact (plus petit, sans compteur de
##     dégâts, fil de butin court), Minimal (vie, sorts, cible et annonces ; objectifs repliés, ni mini-carte, ni quête, ni
##     butin au fil : la grande carte reste sur sa touche). Le Battle royale garde sa mini-carte et sa colonne quel que soit le profil.
## Rien ici ne change le jeu : affichage seulement.

const PROFILES := ["standard", "compact", "minimal"]
const PROFILE_NAMES := {"standard": "Standard", "compact": "Compact", "minimal": "Minimal"}
const PROFILE_HINTS := {
	"standard": "Tout le HUD : objectifs, quête suivie, mini-carte, compteur de dégâts, fil du butin.",
	"compact": "Le même HUD en plus petit, sans compteur de dégâts ; le fil du butin garde deux lignes.",
	"minimal": "Vie, sorts, cible et annonces. Objectifs repliés (touche des objectifs), sans mini-carte ni fil du butin.",
}
const COMPACT_SCALE := 0.88  # taille du profil Compact (multipliée par la taille du HUD réglée)

const INK := Color("221a3a")  # encre-700 (bible § 3)
const INK_900 := Color("150f27")
const WELL := Color("2e2450")  # encre-500


## Profil choisi (« standard », « compact », « minimal »).
static func profile() -> String:
	var p := String(Settings.get_v("interface", "hud_profile"))
	return p if p in PROFILES else "standard"


## Le profil [param p] (le profil choisi par défaut) montre-t-il [param part] ? « dmg » compteur de dégâts, « loot » fil du
## butin, « quest » quête suivie, « minimap » mini-carte, « auto_open » objectifs dépliés un instant à chaque découverte.
static func shows(part: String, p := "") -> bool:
	if p == "":
		p = profile()
	match part:
		"dmg", "auto_open":
			return p == "standard"
		"loot", "quest", "minimap":
			return p != "minimal"
	return true


## Lignes du fil de butin au plus.
static func loot_lines(p := "") -> int:
	if p == "":
		p = profile()
	return {"standard": 3, "compact": 2}.get(p, 0)


## Facteur de taille du profil (multiplié par la taille du HUD).
static func scale_of(p := "") -> float:
	if p == "":
		p = profile()
	return COMPACT_SCALE if p == "compact" else 1.0


# --- dessin commun ----------------------------------------------------------------------------------------------------
static var _sb_cache := {}


## Rectangle arrondi plein (+ contour) ; les boîtes sont gardées (une par réglage) : aucun objet créé par image.
static func round_rect(ci: CanvasItem, r: Rect2, fill: Color, radius: int, border := 0, ink := Color.TRANSPARENT, shadow := 0.0) -> void:
	var key := "%s|%d|%d|%s|%.1f" % [fill.to_html(), radius, border, ink.to_html(), shadow]
	var sb: StyleBoxFlat = _sb_cache.get(key)
	if sb == null:
		sb = StyleBoxFlat.new()
		sb.bg_color = fill
		sb.set_corner_radius_all(radius)
		sb.anti_aliasing = true
		if border > 0:
			sb.border_color = ink
			sb.set_border_width_all(border)
		if shadow > 0.0:
			sb.shadow_color = Color(INK_900, minf(fill.a, 1.0) * 0.9)
			sb.shadow_size = 1
			sb.shadow_offset = Vector2(0, shadow)
		if _sb_cache.size() > 400:
			_sb_cache.clear()
		_sb_cache[key] = sb
	ci.draw_style_box(sb, r)


## Jauge autocollante (bible § 5) : creux d'encre 500 contouré d'encre, ombre dure, remplissage deux tons [param tone]
## (clair en haut, base), trace claire [param trail] des dégâts récents, bord droit d'encre.
static func gauge(ci: CanvasItem, r: Rect2, k: float, tone: String, trail := -1.0, shadow := 3.0) -> void:
	var t := UiTheme.tones(tone)
	var rad := int(minf(12.0, r.size.y * 0.5))
	round_rect(ci, r, WELL, rad, 3, INK, shadow)
	var inner := r.grow(-3.0)
	var ir := int(minf(9.0, inner.size.y * 0.5))
	if trail > k + 0.002:
		round_rect(ci, Rect2(inner.position, Vector2(inner.size.x * clampf(trail, 0.0, 1.0), inner.size.y)), Color(UiTheme.color("papier.100"), 0.75), ir)
	var w := inner.size.x * clampf(k, 0.0, 1.0)
	if w <= 1.0:
		return
	var fr := Rect2(inner.position, Vector2(w, inner.size.y))
	round_rect(ci, fr, t[1], ir)
	var hi := maxf(2.0, inner.size.y * 0.32)
	round_rect(ci, Rect2(fr.position + Vector2(2, 1), Vector2(maxf(w - 4.0, 0.0), hi)), Color(t[0], 0.95), mini(ir, 4))
	if k < 0.995:
		ci.draw_rect(Rect2(fr.end.x - 1.5, fr.position.y, 3.0, fr.size.y), INK)


## Texte contouré d'encre (bible § 4) : [param align] 0 centré sur x, -1 à gauche de x, 1 à droite ; ligne de base [param y].
static func ink_text(ci: CanvasItem, font: Font, t: String, x: float, y: float, fs: int, col: Color, outline := 0, align := 0) -> float:
	var w := font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var at := Vector2(x - w * 0.5 if align == 0 else (x if align < 0 else x - w), y)
	if outline > 0:
		ci.draw_string_outline(font, at, t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, outline, Color(INK, col.a))
	ci.draw_string(font, at, t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
	return w


## Pastille de touche dessinée sous une case (bible § 6 : papier contouré d'encre, lettre à l'encre ; manette : A pomme,
## B fraise, X lagon, Y soleil, lettre blanche contourée). [param center] milieu de la pastille.
static func key_pill(ci: CanvasItem, center: Vector2, key: String, fs := UiTheme.MIN_TEXT) -> Rect2:
	var pads := {"A": "pomme", "B": "fraise", "X": "lagon", "Y": "soleil"}
	var font := UiTheme.number_font()
	var w := maxf(24.0, font.get_string_size(key, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 12.0)
	var h := float(fs) + 8.0
	var r := Rect2(center - Vector2(w, h) * 0.5, Vector2(w, h))
	var tone: String = pads.get(key, "")
	round_rect(ci, r, UiTheme.color("bonbon.%s.base" % tone) if tone != "" else UiTheme.color("papier.100"), int(h * 0.5), 2, INK, 2.0)
	if tone != "":
		ink_text(ci, font, key, center.x, center.y + fs * 0.36, fs, Color.WHITE, 4)
	else:
		ink_text(ci, font, key, center.x, center.y + fs * 0.36, fs, INK)
	return r


# --- vie ----------------------------------------------------------------------------------------------------------------
## Jauge de vie large (sous les cases de sorts) : « Vie » en Mochiy à gauche, chiffres contourés au milieu, trace claire des
## dégâts qui rattrape la vie, pulsation fraise sous 30 %. Redessinée seulement quand elle change.
class LifeGauge extends Control:
	const H := 24.0
	var ratio := 1.0
	var trail := 1.0
	var caption := "Vie"
	var _txt := ""
	var _low := false

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_PASS
		process_mode = Node.PROCESS_MODE_ALWAYS

	func set_hp(v: float, mx: float) -> void:
		var k := clampf(v / maxf(mx, 1.0), 0.0, 1.0)
		if k > ratio:
			trail = k
		ratio = k
		var t := "%s / %s" % [Hud._big_number(ceilf(maxf(v, 0.0))), Hud._big_number(ceilf(mx))]
		if t != _txt:
			_txt = t
			tooltip_text = "Vie : " + t
		queue_redraw()

	func _process(delta: float) -> void:
		var low := ratio < 0.3 and ratio > 0.0
		if trail > ratio:
			trail = move_toward(trail, ratio, delta * 0.45)
			queue_redraw()
		elif low or low != _low:
			queue_redraw()
		_low = low

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		HudV2.gauge(self, r, ratio, "fraise", trail)
		if _low:
			var a := 0.45 + 0.45 * sin(Time.get_ticks_msec() * 0.012)
			HudV2.round_rect(self, r.grow(3.0), Color(0, 0, 0, 0), int(size.y * 0.5) + 3, 3, Color(UiTheme.color("bonbon.fraise.clair"), a))
		var cap_font := UiTheme.title_font()
		var base := r.position.y + r.size.y * 0.5
		HudV2.ink_text(self, cap_font, caption, r.position.x + 12.0, base + 6.0, 16, Color.WHITE, 5, -1)
		HudV2.ink_text(self, UiTheme.number_font(), _txt, r.get_center().x, base + 6.0, 16, Color.WHITE, 5)


# --- niveau -------------------------------------------------------------------------------------------------------------
## Barre de niveau (au lieu du globe) : pastille lagon « Niv. 8 » en Mochiy, jauge lagon fine dessous ; à la montée de
## niveau, éclat soleil. Le pourcentage n'est que dans l'infobulle (bible § 12).
class LevelBar extends Control:
	const PILL_H := 28.0
	const GAUGE_H := 14.0
	var ratio := 0.0
	var trail := 0.0  # (compat. de l'ancien globe)
	var value := 0.0  # (compat.) = ratio
	var level := 1
	var big_text := ""  # le niveau (« 8 »)
	var small_text := ""  # jamais de pourcentage permanent (lu par test_bri1)
	var caption := "Niv."
	var flash := 0.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_PASS
		process_mode = Node.PROCESS_MODE_ALWAYS

	func set_level(k: float, lvl: int) -> void:
		k = clampf(k, 0.0, 1.0)
		if not is_equal_approx(k, ratio) or lvl != level or String(big_text) != str(lvl):
			ratio = k
			value = k
			trail = k
			level = lvl
			big_text = str(lvl)
			queue_redraw()

	func _process(delta: float) -> void:
		if flash > 0.0:
			flash = maxf(0.0, flash - delta * 1.6)
			queue_redraw()

	## Largeur de la pastille (texte en Mochiy 18).
	func pill_width() -> float:
		return maxf(78.0, UiTheme.title_font().get_string_size("%s %s" % [caption, big_text], HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x + 24.0)

	func _draw() -> void:
		var pw := pill_width()
		var pill := Rect2(0, 0, pw, PILL_H)
		var g := Rect2(0, PILL_H + 6.0, size.x, GAUGE_H)
		HudV2.gauge(self, g, ratio, "lagon", -1.0, 2.0)
		if flash > 0.0:
			HudV2.round_rect(self, g.grow(2.0 + 6.0 * (1.0 - flash)), Color(0, 0, 0, 0), 10, 3, Color(UiTheme.color("bonbon.soleil.clair"), flash))
		var tone := "soleil" if flash > 0.0 else "lagon"
		HudV2.round_rect(self, pill, UiTheme.color("bonbon.%s.base" % tone), 12, 3, HudV2.INK, 3.0)
		HudV2.round_rect(self, Rect2(pill.position + Vector2(3, 3), Vector2(pw - 6.0, 6.0)), Color(UiTheme.color("bonbon.%s.clair" % tone), 0.9), 4)
		HudV2.ink_text(self, UiTheme.title_font(), "%s %s" % [caption, big_text], pill.get_center().x, pill.position.y + 21.0, 18, Color.WHITE, 5)


# --- mini-carte ---------------------------------------------------------------------------------------------------------
## Cadre papier de la mini-carte ronde : ombre dure d'encre, contour d'encre, bande papier, contour intérieur (bible § 5).
## Dessin fixe (aucun _process).
class MapRing extends Control:
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var c := size * 0.5
		var r := size.x * 0.5 - 6.0
		draw_arc(c + Vector2(3, 4), r + 2.0, 0.0, TAU, 128, Color(HudV2.INK_900, 0.85), 6.0, true)  # ombre dure
		draw_arc(c, r + 2.5, 0.0, TAU, 128, HudV2.INK, 6.0, true)
		draw_arc(c, r - 1.0, 0.0, TAU, 128, UiTheme.color("papier.100"), 5.0, true)
		draw_arc(c, r - 4.5, 0.0, TAU, 128, HudV2.INK, 2.5, true)
		# reflet blanc sur l'arête haute (comme les icônes du jeu)
		draw_arc(c, r - 1.0, deg_to_rad(205.0), deg_to_rad(245.0), 24, Color(1, 1, 1, 0.95), 2.5, true)
