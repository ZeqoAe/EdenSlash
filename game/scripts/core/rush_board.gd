class_name RushBoard
extends RefCounted
## Ruée chronométrée (lot DNG-3, backlog BM-DNG P1-10 et P2 « classement local par graine ») : chaque Ruée finie (les huit boss)
## entre dans le classement local de son tirage et de sa difficulté (les 5 meilleurs temps, avec le jour et les modificateurs).
## Le tirage d'une Ruée dépend de sa graine et des boss de la Ruée d'avant (Rush.lineup_for : rush_prev) : le classement garde les
## deux, et « Rejouer ce tirage » les remet (les mêmes huit boss, dans le même ordre). Pas de serveur : tout reste local.
## Pendant la partie, le fil des temps par boss est tenu par BestTimes (boss:rush:<boss>:<diff>) et affiché par DngHud.
## Stockage : Profile.records[KEY] = {"<graine>:<diff>" -> [{t, day, mods, prev}]} (clé neuve : rien à migrer).

const KEY := "rush_board"
const KEEP := 5


static func _table() -> Dictionary:
	var t = Profile.records.get(KEY, {})
	return t if t is Dictionary else {}


static func _key(seed: int, diff: int) -> String:
	return "%d:%d" % [seed, diff]


## Classement du tirage [param seed] en [param diff] : [{t, day, mods, prev}], le plus rapide d'abord.
static func top(seed: int, diff: int) -> Array:
	var l = _table().get(_key(seed, diff), [])
	return (l as Array).duplicate(true) if l is Array else []


## Ruée finie en [param secs] : entre dans le classement. Renvoie {rank (1 = meilleur, 0 : hors classement), size, best (ancien
## meilleur, 0 : aucun)}. Appelé après le rechargement du profil (Tower._finish_dungeon).
static func add(seed: int, diff: int, secs: float, mods: Array, prev: int) -> Dictionary:
	if seed <= 0 or secs <= 0.5:
		return {}
	var list := top(seed, diff)
	var old_best := float(list[0].t) if not list.is_empty() else 0.0
	var e := {"t": snappedf(secs, 0.1), "day": Quests.today(), "mods": mods.duplicate(), "prev": prev}
	list.append(e)
	list.sort_custom(func(a, b): return float(a.t) < float(b.t))
	var rank := list.find(e) + 1
	list = list.slice(0, KEEP)
	if rank > KEEP:
		rank = 0
	var t := _table().duplicate(true)
	t[_key(seed, diff)] = list
	Profile.records[KEY] = t
	return {"rank": rank, "size": list.size(), "best": old_best, "seed": seed, "diff": diff, "prev": prev}


## Les tirages les plus rapides de la difficulté [param diff] : [{seed, t, prev, runs}], [param n] au plus.
static func best_draws(diff: int, n := 3) -> Array:
	var out: Array = []
	var t := _table()
	for k in t:
		var parts := String(k).split(":")
		if parts.size() != 2 or int(parts[1]) != diff or not (t[k] is Array) or (t[k] as Array).is_empty():
			continue
		var first: Dictionary = (t[k] as Array)[0]
		out.append({"seed": int(parts[0]), "t": float(first.t), "prev": int(first.get("prev", 0)), "runs": (t[k] as Array).size()})
	out.sort_custom(func(a, b): return float(a.t) < float(b.t))
	return out.slice(0, n)


## « Rejouer ce tirage » : la graine et les boss de la Ruée d'avant de ce tirage-là (mêmes huit boss, même ordre).
static func replay(seed: int, prev: int) -> void:
	Profile.records["rush_seed"] = seed
	Profile.records["rush_prev"] = prev
	Rush._cache.clear()


## Lignes du bilan : « Classement du tirage n° 4821 : 1er sur 3 » puis les temps.
static func lines(rr: Dictionary) -> Array:
	if rr.is_empty():
		return []
	var out: Array = []
	var rank := int(rr.get("rank", 0))
	var size := int(rr.get("size", 0))
	if rank == 1 and float(rr.get("best", 0.0)) > 0.0:
		out.append("Meilleur temps sur le tirage n° %d (ancien %s)" % [int(rr.seed), BestTimes.fmt(float(rr.best))])
	elif rank > 0:
		out.append("Tirage n° %d : %s temps sur %d" % [int(rr.seed), "1er" if rank == 1 else "%de" % rank, size])
	return out


## Bloc de la page Ruée (lobby._menu_rush) : le classement du tirage proposé, puis tes tirages les plus rapides de cette
## difficulté avec « Rejouer ce tirage ». Rien tant qu'aucune Ruée n'est finie.
static func page_block(lobby) -> void:
	var diff := int(lobby._dg_diff)
	var seed_n := Rush.current_seed()
	var mine := rows_text(seed_n, diff, 3)
	var draws := best_draws(diff, 3).filter(func(e): return int(e.seed) != seed_n)
	if mine.is_empty() and draws.is_empty():
		return
	lobby._section("Tes temps", "Classement local : chaque Ruée finie y entre, les cinq meilleurs temps par tirage et difficulté.")
	var sub: VBoxContainer = lobby._sub
	if not mine.is_empty():
		var l := Hud._label(sub, "Ce tirage (n° %d) : %s" % [seed_n, "   ".join(mine)], 14, UiTheme.TEXT)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	for e in draws:
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 8)
		sub.add_child(h)
		var t := Hud._label(h, "Tirage n° %d : %s (%d Ruée%s finie%s)" % [int(e.seed), BestTimes.fmt(float(e.t)), int(e.runs), "s" if int(e.runs) > 1 else "",
			"s" if int(e.runs) > 1 else ""], 14, UiTheme.MUTED)
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var b := MenuWidgets.glass_button("Rejouer ce tirage", 13, Vector2(0, 30))
		b.tooltip_text = "Les mêmes huit boss, dans le même ordre : bats ton temps."
		var s := int(e.seed)
		var p := int(e.prev)
		b.pressed.connect(func(): _pick(lobby, s, p))
		h.add_child(b)


static func _pick(lobby, seed: int, prev: int) -> void:
	replay(seed, prev)
	Profile.save_profile()
	lobby._show_menu("rush")


## Classement en texte (« 1. 12:04 · aujourd'hui », …), [param n] lignes au plus.
static func rows_text(seed: int, diff: int, n := 3) -> Array:
	var out: Array = []
	var today := Quests.today()
	var l := top(seed, diff)
	for i in mini(n, l.size()):
		var e: Dictionary = l[i]
		var mods: Array = (e.get("mods", []) as Array).map(func(k): return String(Rush.MODS.get(k, {}).get("name", k)))
		out.append("%d. %s · %s%s" % [i + 1, BestTimes.fmt(float(e.t)), "aujourd'hui" if String(e.get("day", "")) == today else String(e.get("day", "")),
			(" · " + ", ".join(mods)) if not mods.is_empty() else ""])
	return out
