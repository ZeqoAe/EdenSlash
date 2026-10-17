class_name AssaultAnnounce
extends RoyaleAnnounce
## Annonces centrales de L'Assaut (lot TAC-7, TACTIQUE § 7.8) : une seule à la fois, sous le bandeau du score, mêmes
## autocollants et même file à priorités que le Battle royale (RoyaleAnnounce) ; sens et couleurs propres au mode : manche et
## côté sur papier, « C'est parti ! » lagon, Charge posée fraise pour la Défense et soleil pour l'Attaque, désamorçage lagon,
## « À toi de jouer ! » soleil, fin de partie soleil ou papier. Les fins de manche (« Manche gagnée ! ») et la chute du joueur
## ont leur propre carte (AssaultHud.round_card, AssaultRecap) : elles ne passent pas ici.

const TOP_A := 150.0  # haut du bandeau à 1600×900 : sous le bandeau du score et la ligne de la Charge
## [motif, sorte, rang] : rang 0 info légère, 1 information, 2 manche, 3 danger immédiat, 4 fin de partie.
const RULES_A := [
	["VICTOIRE", "win", 4], ["DÉFAITE", "end", 4], ["10 secondes", "danger", 3], ["La Charge explose", "danger", 3],
	["Ils désamorcent", "danger", 3], ["Ouf", "defuse", 3], ["Charge désamorcée", "defuse", 3], ["Charge posée", "plant", 3],
	["À toi de jouer", "solo", 3], ["contre", "count", 2], ["C'est parti", "go", 2], ["Manche ", "round", 2], ["Mi-temps", "round", 2],
	["Prolongation", "round", 2], ["Alarme", "alarm", 2], ["Piège", "alarm", 2], ["Ultime prêt", "ult", 1], ["Charge", "info", 1],
]
const TONES_A := {"win": "soleil", "end": "papier", "danger": "fraise", "defuse": "lagon", "plant": "soleil", "solo": "soleil",
	"count": "papier", "go": "lagon", "round": "papier", "alarm": "mandarine", "ult": "soleil", "info": "papier"}
## Messages du directeur qui ont leur propre carte (fin de manche, chute du joueur) : ils ne s'affichent pas en bandeau.
const SWALLOW := ["Manche gagnée", "Manche perdue", "Tu es tombé"]

## Haut du bandeau en px (posé par AssaultHud sous le cadre de cible) ; négatif : TOP_A.
var top_px := -1.0
## Côté du joueur (pour la couleur de « Charge posée » : danger pour la Défense).
var defending := false


static func classify_a(text: String) -> Array:
	for r in RULES_A:
		if text.contains(String(r[0])):
			return [String(r[1]), int(r[2])]
	return ["info", 1]


func push(text: String, duration: float) -> bool:
	for s in SWALLOW:
		if text.begins_with(s):
			return true
	for pre in Hud.FEED_PREFIXES:
		if text.begins_with(pre) and not text.contains("\n"):
			return false
	var lines := text.split("\n", false, 1)
	var title := String(lines[0]) if lines.size() > 0 else ""
	var sub := String(lines[1]) if lines.size() > 1 else ""
	var c := classify_a(text)
	var a := {"title": title, "sub": sub, "kind": c[0], "prio": c[1], "duration": maxf(duration, 1.2), "at": _clock}
	if not current.is_empty() and String(current.title) == title and String(current.sub) == sub:
		current.left = maxf(float(current.left), a.duration)
		return true
	if String(a.kind) == "count":
		queue = queue.filter(func(q): return String(q.kind) != "count")
	if current.is_empty() or int(a.prio) > int(current.prio) or (int(a.prio) == int(current.prio) and float(current.shown) >= MIN_SHOW) \
			or float(current.left) <= 0.0:
		_show(a)
	else:
		queue.append(a)
		queue.sort_custom(func(x, y): return int(x.prio) > int(y.prio) or (int(x.prio) == int(y.prio) and float(x.at) < float(y.at)))
		if queue.size() > QUEUE_MAX:
			queue.pop_back()
	return true


func _show(a: Dictionary) -> void:
	current = {"title": a.title, "sub": a.sub, "kind": a.kind, "prio": a.prio, "left": a.duration, "shown": 0.0}
	var kind := String(a.kind)
	var tone := String(TONES_A.get(kind, "papier"))
	if kind == "plant" and defending:
		tone = "fraise"
	if tone == "fraise" and RoyaleHudStyle.colorblind():
		tone = "mandarine"
	var paper := tone == "papier"
	_panel.add_theme_stylebox_override("panel", UiTheme.sticker(tone, {"pad": Vector2(30, 8), "shadow": 6, "radius": 18}))
	_style(_title, 34 if kind in ["win", "end"] else 30, paper, RoyaleHudStyle.title_font())
	_style(_sub, 17, paper, RoyaleHudStyle.text_font())
	_title.text = String(a.title)
	_sub.text = String(a.sub)
	_sub.visible = String(a.sub) != ""
	_fit()
	_holder.visible = true
	if _tw:
		_tw.kill()
	_panel.modulate.a = 0.0
	_panel.scale = Vector2(1.18, 1.18)
	_tw = create_tween().set_parallel()
	_tw.tween_property(_panel, "modulate:a", 1.0, 0.14)
	_tw.tween_property(_panel, "scale", Vector2.ONE, 0.26).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Sous le bandeau du score (pas sous le cadre de cible comme au Battle royale).
func _place() -> void:
	var ms := _panel.get_combined_minimum_size()
	_panel.size = ms
	_panel.pivot_offset = ms * 0.5
	_panel.rotation_degrees = TILT
	var vw := _area().x
	var k := clampf(_area().y / 900.0, 0.8, 1.0)
	_holder.position = Vector2(roundf((vw - ms.x) * 0.5), top_px if top_px >= 0.0 else TOP_A * k)
