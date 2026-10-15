class_name DifficultyPanel
extends RefCounted
## Lisibilité de la difficulté (passe M6), sous le choix de difficulté de la Ruée et du Siège : la PE requise pour entrer
## (ou la PE conseillée en Normal, qui n'en demande pas) et la tienne sur une jauge (celle de la passe P5), une estimation
## sobre (VERDICTS : la tienne rapportée à la PE conseillée, mesurée au pilote), les récompenses de la difficulté et, quand
## elle est trop haute pour toi, un avertissement d'une phrase. La difficulté reste permise : on sait à quoi s'attendre.

## [rapport minimal à la PE conseillée, nom, couleur, conseil (infobulle)]
const VERDICTS := [
	[1.35, "Facile", Color(0.45, 0.92, 0.55), "Ton équipement dépasse nettement ce qu'il faut : les boss tomberont vite."],
	[0.95, "Équilibré", Color(0.55, 0.8, 1.0), "Ton équipement est celui qu'il faut : un vrai combat, à ta portée."],
	[0.7, "Difficile", Color(1.0, 0.72, 0.3), "Il te manque de la puissance : combats longs, chaque erreur coûte cher."],
	[0.0, "Hors de portée", Color(1.0, 0.42, 0.4), "Ton équipement est loin du compte : les boss tiendront très longtemps et frapperont fort."],
]
const WARN := {
	"Difficile": "Il te manque de la puissance : attends-toi à des combats longs et punitifs.",
	"Hors de portée": "Ton équipement est loin du compte : vise d'abord une difficulté plus basse.",
}


## Estimation : [nom, couleur, conseil] pour la PE [param have] face à la PE conseillée [param advised].
static func verdict(have: int, advised: int) -> Array:
	var r := float(have) / maxf(float(advised), 1.0)
	for v in VERDICTS:
		if r >= float(v[0]):
			return [v[1], v[2], v[3]]
	var last: Array = VERDICTS[-1]
	return [last[1], last[2], last[3]]


## Ajoute le bloc à [param parent] : PE requise [param need] (0 : aucune), PE conseillée [param advised], récompenses
## [param rewards] (courtes, « 272 cristaux »…). Renvoie le nom de l'estimation.
static func add(parent: Control, need: int, advised: int, rewards: Array) -> String:
	var have := GearPower.hero_power()
	var v := verdict(have, advised)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 5)
	parent.add_child(box)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	box.add_child(row)
	var line := ("PE requise %s · la tienne %s" % [GearPower.fmt(need), GearPower.fmt(have)]) if need > 0 \
		else ("PE conseillée %s · la tienne %s" % [GearPower.fmt(advised), GearPower.fmt(have)])
	var l := Hud._label(row, line, 15, UiTheme.TEXT)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.mouse_filter = Control.MOUSE_FILTER_STOP
	l.tooltip_text = "Puissance d'équipement (PE).%s Conseillée : %s.\nPour la monter : des pièces de plus haut niveau à l'Armurerie, puis +N, gemmes et enchantements à la Forge." % [
		(" Requise pour entrer : %s." % GearPower.fmt(need)) if need > 0 else "", GearPower.fmt(advised)]
	row.add_child(_chip(String(v[0]), v[1], String(v[2])))
	var bar := ProgressBar.new()
	var top := maxf(float(maxi(need, advised)), 1.0)
	bar.max_value = top
	bar.value = minf(float(have), top)
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 8)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fill := StyleBoxFlat.new()
	fill.bg_color = v[1]
	fill.set_corner_radius_all(4)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(1, 1, 1, 0.1)
	bg.set_corner_radius_all(4)
	bar.add_theme_stylebox_override("fill", fill)
	bar.add_theme_stylebox_override("background", bg)
	box.add_child(bar)
	if not rewards.is_empty():
		var rw := Hud._label(box, "Récompenses : " + " · ".join(rewards), 14, UiTheme.MUTED)
		rw.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if WARN.has(String(v[0])):
		var w := Hud._label(box, "⚠ " + String(WARN[String(v[0])]), 14, v[1])
		w.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return String(v[0])


## Pastille de l'estimation (texte coloré dans un cadre fin), le conseil en infobulle.
static func _chip(text: String, color: Color, tip: String) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UiTheme.flat_box(Color(color.r, color.g, color.b, 0.14), color, 1, 6, false))
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	p.tooltip_text = tip
	var l := Hud._label(p, text, 14, color)
	l.add_theme_font_override("font", UiTheme.bold_font())
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.custom_minimum_size = Vector2(110, 0)
	return p


## Récompenses de la Ruée en difficulté [param diff] avec les modificateurs [param mods] : cristaux si les 8 tombent,
## coffres de matières, équipement, apparence (1re fois), titre.
static func rush_rewards(diff: int, mods: Array) -> Array:
	var lv := Dungeons.rush_level(Dungeons.rush_floors(), diff)
	var out: Array = ["%d cristaux" % roundi(ActivityLoot.rush_crystals(Dungeons.rush_floors(), diff) * Rush.bonus(mods)),
		"parchemins et gemmes niv. %d" % lv, "coffre d'équipement"]
	if int(Profile.records.get("rush_clear_%d" % diff, 0)) == 0:
		out.append("apparence")
	out.append("titre « %s »" % String(Dungeons.RUSH_TITLES[clampi(diff, 0, 2)]))
	return out


## Récompenses du Siège de [param zid] en difficulté [param diff] (boss tombé, objectifs compris dans l'infobulle).
static func siege_rewards(zid: String, diff: int) -> Array:
	var n := clampi(diff, 0, 2) + 1
	return ["%d cristaux" % ActivityLoot.siege_crystals(Siege.WAVES, diff, true), "formules d'enchantement ×%d" % n,
		"coffre d'équipement niv. %d" % (Siege.level(zid, diff) + 1), "apparence légendaire au dernier debout"]
