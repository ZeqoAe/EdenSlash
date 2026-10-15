class_name Wheel
extends RefCounted
## Roulette quotidienne (idée du joueur) : 3 lancers par jour, 12 cases de largeurs inégales (la largeur d'une
## case = sa chance), dont des cases « Perdu ». Les gains sont des apparences (jamais de puissance), comme
## l'autel de la fortune. Pitié : 6 « Perdu » d'affilée, le lancer suivant donne au moins du commun ;
## 25 lancers sans rare ou mieux, le suivant donne au moins du rare. Des lancers en plus s'achètent en
## insignes (2 par jour au plus).

const FREE_PER_DAY := 3
const EXTRA_MAX := 2
const EXTRA_COST := 50  # insignes, × (nombre de lancers en plus déjà pris + 1)
const PITY_LOST := 6
const PITY_RARE := 25

## Les cases dans l'ordre de la roue (en partant du haut, dans le sens des aiguilles d'une montre) :
## [type, poids]. Le total des poids vaut 100 : un poids est un pourcentage.
const SLICES := [
	["lost", 10], ["common", 10], ["rare", 8], ["lost", 10], ["common", 9], ["epic", 10],
	["lost", 10], ["common", 9], ["rare", 7], ["jackpot", 4], ["legend", 6], ["rare", 7],
]
const KINDS := {
	"lost": {"name": "Perdu", "color": Color(0.3, 0.3, 0.37), "rank": 0},
	"common": {"name": "Apparence commune", "color": Color(0.72, 0.78, 0.9), "rank": 1},
	"rare": {"name": "Apparence rare", "color": Color(0.3, 0.55, 1.0), "rank": 2},
	"epic": {"name": "Apparence mythique", "color": Color(1.0, 0.55, 0.15), "rank": 3},
	"legend": {"name": "Apparence légendaire", "color": Color(1.0, 0.86, 0.3), "rank": 4},
	"jackpot": {"name": "Jackpot : apparence dorée", "color": Color(1.0, 0.4, 0.8), "rank": 5},
}
## Insignes quand toute la collection du rang est déjà obtenue.
const CONSOLATION := {"common": 20, "rare": 50, "epic": 100, "legend": 200, "jackpot": 300}


static var day_override := ""  # tests : jour imposé


static func today() -> String:
	return day_override if day_override != "" else Time.get_date_string_from_system()


## État du jour : remet à zéro les lancers quand le jour a changé (la série de pitié reste).
static func state() -> Dictionary:
	var w: Dictionary = Profile.wheel
	if String(w.get("day", "")) != today():
		w["day"] = today()
		w["used"] = 0
		w["extra"] = 0
	for k in ["misses", "since_rare", "total"]:
		if not w.has(k):
			w[k] = 0
	return w


static func free_left() -> int:
	return maxi(0, FREE_PER_DAY - int(state().used))


## Prix du prochain lancer en plus (en insignes) ; -1 si la limite du jour est atteinte.
static func extra_cost() -> int:
	var n := int(state().extra)
	return EXTRA_COST * (n + 1) if n < EXTRA_MAX else -1


static func can_spin() -> bool:
	return free_left() > 0 or (extra_cost() > 0 and Profile.insignia >= extra_cost())


## Angle de départ et de fin (en radians, depuis le haut, sens horaire) de la case [param i].
static func span(i: int) -> Vector2:
	var total := 0.0
	var a0 := 0.0
	for j in SLICES.size():
		if j == i:
			a0 = total
		total += float(SLICES[j][1])
	return Vector2(TAU * a0 / total, TAU * (a0 + float(SLICES[i][1])) / total)


## Case désignée par un tirage [param r] entre 0 et 1 (largeur des cases = chances).
static func slice_at(r: float) -> int:
	var total := 0.0
	for s in SLICES:
		total += float(s[1])
	var acc := 0.0
	for i in SLICES.size():
		acc += float(SLICES[i][1]) / total
		if r < acc:
			return i
	return SLICES.size() - 1


## Apparence promise par chaque case de la roue (idée du joueur : voir le gain à l'avance), tirée une fois
## par lancer et gardée dans la sauvegarde : [code]{"key": "jour#lancers", "ids": [id ou 0 par case]}[/code].
## La case « Perdu » n'a rien (0) ; un id à 0 sur une autre case = collection du rang déjà complète (insignes).
## Le lancer donne l'apparence promise par la case désignée : ce qu'on voit sur la roue est ce qu'on gagne.
static func board() -> Array:
	var w := state()
	var key := "%s#%d" % [today(), int(w.total)]
	var b: Dictionary = w.get("board", {})
	var fresh := String(b.get("key", "")) != key
	if fresh:
		b = {"key": key, "ids": []}
		w["board"] = b
	var ids: Array = b.ids
	var out: Array = []
	var used := {}
	for i in SLICES.size():
		var look: Dictionary = {}
		var id := int(ids[i]) if i < ids.size() else -1
		if id > 0 and GameData.collection_by_id.has(id) and not Profile.collected(GameData.collection_by_id[id]) and not used.has(id):
			look = GameData.collection_by_id[id]  # promesse gardée
		elif String(SLICES[i][0]) != "lost" and (id != 0 or i >= ids.size()):
			look = _roll_look(String(SLICES[i][0]), used)
		used[int(look.get("id", 0))] = true
		out.append(look)
	var new_ids: Array = out.map(func(l): return int(l.get("id", 0)))
	if fresh or new_ids != (b.ids as Array).map(func(i): return int(i)):
		b["ids"] = new_ids
		Profile.save_profile()  # la promesse survit à un redémarrage
	return out


## Apparence du gain [param kind] pas encore obtenue ni déjà promise à une autre case ({} si tout est obtenu).
static func _roll_look(kind: String, used: Dictionary) -> Dictionary:
	var look: Dictionary = {}
	for _try in 12:
		look = _draw_look(kind)
		if look.is_empty() or not used.has(int(look.id)):
			break
	return look if not look.is_empty() and not used.has(int(look.id)) else {}


static func _draw_look(kind: String) -> Dictionary:
	if kind == "jackpot":
		var look := Fortune.summit_look()
		return look if not look.is_empty() else Rewards.roll_look("look_legend")
	return Rewards.roll_look("look_" + kind)


## Une case de ce type (la plus large d'abord si plusieurs).
static func slice_of(kind: String) -> int:
	var best := -1
	for i in SLICES.size():
		if SLICES[i][0] == kind and (best < 0 or SLICES[i][1] > SLICES[best][1]):
			best = i
	return best


## Lance la roue ([param roll] : tirage imposé entre 0 et 1 pour les tests ; -1 : au hasard).
## Renvoie {ok, slice, kind, text, look, insignia} ; {ok: false, text} si plus de lancer.
static func spin(roll := -1.0) -> Dictionary:
	var w := state()
	var paid := 0
	if free_left() > 0:
		w["used"] = int(w.used) + 1
	elif extra_cost() > 0 and Profile.insignia >= extra_cost():
		paid = extra_cost()
		Profile.insignia -= paid
		w["extra"] = int(w.extra) + 1
	else:
		return {"ok": false, "text": "Plus de lancer aujourd'hui. Reviens demain !"}
	var idx := slice_at(randf() if roll < 0.0 else roll)
	var kind := String(SLICES[idx][0])
	var pity := ""
	if int(KINDS[kind].rank) < 2 and int(w.since_rare) >= PITY_RARE - 1:
		kind = "rare"
		pity = "Pitié : une apparence rare est garantie après %d lancers sans." % PITY_RARE
	elif kind == "lost" and int(w.misses) >= PITY_LOST:
		kind = "common"
		pity = "Pitié : après %d « Perdu » d'affilée, tu gagnes au moins du commun." % PITY_LOST
	if pity != "":
		idx = slice_of(kind)
	var promised: Dictionary = board()[idx]  # avant de compter le lancer : la planche est celle qu'on a vue
	w["total"] = int(w.total) + 1
	w["misses"] = int(w.misses) + 1 if kind == "lost" else 0
	w["since_rare"] = 0 if int(KINDS[kind].rank) >= 2 else int(w.since_rare) + 1
	Profile.records["wheel_spins"] = int(Profile.records.get("wheel_spins", 0)) + 1
	var out := {"ok": true, "slice": idx, "kind": kind, "paid": paid, "pity": pity, "look": {}, "insignia": 0, "text": ""}
	_grant(kind, out, promised)
	Profile.changed.emit()
	Profile.save_profile()
	return out


static func _grant(kind: String, out: Dictionary, promised: Dictionary) -> void:
	if kind == "lost":
		out.text = "Perdu… retente ta chance !"
		return
	var look := promised  # l'apparence montrée sur la case ; vide : toute la collection du rang est obtenue
	if look.is_empty():
		var n := int(CONSOLATION[kind])
		Profile.insignia += n
		out.insignia = n
		out.text = "Tu as déjà toute la collection de ce rang : %d insignes." % n
		return
	Profile.collect(look)
	out.look = look
	out.text = "Tu gagnes « %s » !" % String(look.get("name", "une apparence"))
