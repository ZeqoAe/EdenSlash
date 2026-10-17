class_name TeamMatch
extends RefCounted
## Socle commun des modes d'équipes (lot MODE-0, rapport conception/benchmark/R_MODE0.md) : Le Colisée (6 équipes de 3,
## combats d'arène simultanés), Les Deux Voies (4 contre 4, objectif) et L'Assaut (4 contre 4, objectif), tous scellés et
## joués seul contre des IA. Un seul état statique par partie (comme Duel et Royale) : mode, équipes, couleurs, camps,
## appartenance d'arène, vivants / éliminés, manches, spectateur, résultats, directeur du mode.
##
## Règle d'or : un mode d'équipes ne pose JAMAIS Duel.active ni Royale.active (leurs ~30 variables statiques supposent un
## seul duel). Il est lu partout par l'API unique de Modes : Modes.current() rend son id, Modes.kind() son type
## (« teams », « ffa », « objective »), Modes.sealed(), Modes.is_pvp(), Modes.team_match(), Modes.hero_match() ; ses règles
## chiffrées passent par ModeRules (profil spec.rules, enregistré par ModeRules.register).
##
## Camps : un héros de l'équipe t porte ffa_id = FFA_BASE + t (Combatant.set_ffa) : Combatant.ffa_foes rend les héros des
## AUTRES équipes, jamais ses équipiers ; ClassRival._teammates rend son équipe (Battle royale, Siège : soi seul, comme avant).
## Arène : Combatant.arena_id (-1 = partout, tous les modes d'avant) ; à arena_id >= 0, ffa_foes, hostile_heroes,
## hostile_targets (donc télégraphes, projectiles, zones) et la lecture des zones rouges de ClassRival ne voient que la même
## arène : un héros du Colisée ne vise jamais l'arène voisine à 300 m.
##
## Utilisation (lots CO-A, MB-C, TAC-0) :
##   TeamMatch.begin("colisee")                 # 6 équipes (spec), couleurs de la palette, phase « prep »
##   TeamMatch.add(hero, t, arène)              # camp + arène ; le joueur : TeamMatch.add(player, TeamMatch.player_team, a)
##   TeamMatch.start_round() ; set_phase("fight") ; note_ko(victime, tueur) ; end_round(gagnant)
##   TeamMatch.eliminate(t) -> place ; TeamMatch.result() ; TeamMatch.end()
## Directeur du mode : spec.director (chemin de script) monté par RunDirector.start (TeamMatch.mount) ; world.gd lui
## renvoie la mort du joueur (player_down(tueur)) et l'abandon (abandon()).


## Signaux de la partie (une instance pour tout le jeu ; se reconnecter à chaque partie).
class Bus extends RefCounted:
	signal phase_changed(phase: String)
	signal round_started(n: int)
	signal round_over(winner: int, n: int)
	signal member_down(who: Combatant, team: int)
	signal team_out(team: int, place: int)
	signal watched_changed(who: Combatant)


## Types de mode : équipes contre équipes (manches, élimination), chacun pour soi, objectif (structures, Charge…).
const KINDS := ["teams", "ffa", "objective"]
## Phases d'une manche (aucune n'est obligatoire : un mode à objectif peut rester en « fight » toute la partie).
const PHASES := ["prep", "countdown", "fight", "recap", "done"]
## Premier ffa_id des équipes (0 et suivants : Battle royale et Siège ; GUARD_ID du gardien du Battle royale en dessous de 100).
const FFA_BASE := 100

## Modes déclarés. Clés : name (texte joueur), kind, teams (équipes par défaut), size (héros par équipe), rules (profil de
## ModeRules), act (activité de Quests.end_run), arenas (combats séparés par arène), win_places (places qui comptent comme
## une victoire), rounds_to_win (0 : pas de manches gagnantes), director (script du directeur, monté par mount).
## Options lues par les endroits du jeu (TeamMatch.allows) : potions, level_cards (cartes de montée de niveau), journal
## (journal de run), save (sauvegarde pendant la partie) ; toutes fausses par défaut (mode scellé).
const MODES := {
	"colisee": {"name": "Le Colisée", "kind": "teams", "teams": 6, "size": 3, "rules": "colisee", "act": "colisee",
		"arenas": true, "win_places": 3},
	"moba": {"name": "Les Deux Voies", "kind": "objective", "teams": 2, "size": 4, "rules": "moba", "act": "moba"},
	"assault": {"name": "L'Assaut", "kind": "objective", "teams": 2, "size": 4, "rules": "assault", "act": "assault",
		"rounds_to_win": 7},
}
const DEFAULTS := {"kind": "teams", "teams": 2, "size": 1, "rules": "", "act": "", "arenas": false, "win_places": 1,
	"rounds_to_win": 0, "director": "", "sealed": true, "pvp": true,
	"potions": false, "level_cards": false, "journal": false, "save": false}
## Palette de secours si les jetons manquent (mêmes valeurs que data/ui_tokens.json > couleur.equipe).
const FALLBACK := [["azur", "Azur", "22B8F0", "rond"], ["braise", "Braise", "FF8A1F", "carre"], ["citron", "Citron", "F7E030", "triangle"],
	["amethyste", "Améthyste", "B43BEB", "losange"], ["menthe", "Menthe", "12A18C", "etoile"], ["griotte", "Griotte", "AE184E", "croix"],
	["marine", "Marine", "1C4EA2", "hexagone"], ["perle", "Perle", "E7E4F3", "anneau"]]

static var bus := Bus.new()
## Modes ajoutés à l'exécution (tests, essais) : même format que MODES, prioritaires.
static var _registered: Dictionary = {}

static var active := false
static var mode := ""
static var spec: Dictionary = {}
## Équipes : [{index, name, color, motif, ffa, members: [Combatant], out, place, score, kills, round_wins}].
static var teams: Array = []
static var player_team := 0
static var phase := ""
static var round_n := 0
## Une ligne par manche : {n, winner, time, info}.
static var round_log: Array = []
## Ordre d'élimination (indices d'équipe, la première éliminée en tête).
static var out_order: Array = []
static var watched: Combatant = null
static var director: Node = null
## Temps de la partie (le directeur l'avance : TeamMatch.elapsed += delta) et début de la manche en cours.
static var elapsed := 0.0
static var round_t0 := 0.0


# --- registre --------------------------------------------------------------------------------

static func register(id: String, s: Dictionary) -> void:
	_registered[id] = s


static func unregister(id: String) -> void:
	_registered.erase(id)


static func is_mode(id: String) -> bool:
	return _registered.has(id) or MODES.has(id)


static func ids() -> Array:
	var out: Array = MODES.keys()
	for k in _registered:
		if not out.has(k):
			out.append(k)
	return out


## Fiche complète du mode [param id] (valeurs par défaut comprises) ; {} si inconnu.
static func spec_of(id: String) -> Dictionary:
	if not is_mode(id):
		return {}
	var s: Dictionary = DEFAULTS.duplicate(true)
	s.merge(_registered.get(id, MODES.get(id, {})), true)
	s["id"] = id
	return s


## Mode scellé d'après le registre (Modes.sealed avec Modes.forced = id d'un mode d'équipes).
static func sealed_id(id: String) -> bool:
	return is_mode(id) and bool(spec_of(id).sealed)


# --- partie -----------------------------------------------------------------------------------

## Ouvre une partie du mode [param id] avec [param n_teams] équipes (-1 : celles de la fiche) ; [param opts] remplace des
## clés de la fiche pour cette partie (difficulté, format, options).
static func begin(id: String, n_teams := -1, opts := {}) -> void:
	assert(is_mode(id), "TeamMatch : mode inconnu " + id)
	end()
	spec = spec_of(id)
	spec.merge(opts, true)
	mode = id
	active = true
	var n := int(spec.teams) if n_teams < 0 else n_teams
	n = clampi(n, 1, palette().size())
	for t in n:
		var key := color_key_at(t)
		teams.append({"index": t, "key": key, "name": _pal_name(key), "motif": _pal_motif(key), "ffa": FFA_BASE + t,
			"members": [], "out": false, "place": 0, "score": 0.0, "kills": 0, "round_wins": 0})
	player_team = 0
	set_phase("prep")


## Ferme la partie : camps et arènes retirés des héros encore là, tout l'état remis à zéro. Sans effet hors partie.
static func end() -> void:
	for tm in teams:
		for c in tm.members:
			if is_instance_valid(c):
				var cc := c as Combatant
				if cc.ffa_id == int(tm.ffa):
					cc.clear_ffa()
				cc.arena_id = -1
	active = false
	mode = ""
	spec = {}
	teams = []
	player_team = 0
	phase = ""
	round_n = 0
	round_log = []
	out_order = []
	watched = null
	director = null
	elapsed = 0.0
	round_t0 = 0.0


static func kind() -> String:
	return String(spec.get("kind", "")) if active else ""


static func sealed() -> bool:
	return active and bool(spec.get("sealed", true))


static func pvp() -> bool:
	return active and bool(spec.get("pvp", true))


## Option [param key] de la fiche (potions, level_cards, journal, save…) : faux hors partie.
static func allows(key: String) -> bool:
	return active and bool(spec.get(key, false))


static func rules_profile() -> String:
	return String(spec.get("rules", "")) if active else ""


static func act() -> String:
	if not active:
		return ""
	var a := String(spec.get("act", ""))
	return a if a != "" else mode


static func title() -> String:
	return String(spec.get("name", mode))


# --- équipes ----------------------------------------------------------------------------------

static func team_count() -> int:
	return teams.size()


static func team(t: int) -> Dictionary:
	return teams[t] if t >= 0 and t < teams.size() else {}


## Équipe de [param c] (-1 : hors équipe).
static func team_of(c: Combatant) -> int:
	if c == null or not is_instance_valid(c) or not active:
		return -1
	var t := c.ffa_id - FFA_BASE
	return t if t >= 0 and t < teams.size() and (teams[t].members as Array).has(c) else -1


## Place [param c] dans l'équipe [param t] (camp = ffa_id de l'équipe) et dans l'arène [param arena] (-1 : partout).
static func add(c: Combatant, t: int, arena := -1) -> void:
	assert(t >= 0 and t < teams.size(), "TeamMatch.add : équipe hors limites")
	remove(c)
	c.set_ffa(int(teams[t].ffa))
	c.arena_id = arena
	(teams[t].members as Array).append(c)


static func remove(c: Combatant) -> void:
	for tm in teams:
		(tm.members as Array).erase(c)
	if is_instance_valid(c) and c.ffa_id >= FFA_BASE:
		c.clear_ffa()
		c.arena_id = -1


## Membres encore présents de l'équipe [param t] (morts compris) ; [param arena] >= 0 : ceux de cette arène.
static func members(t: int, arena := -1) -> Array:
	var out: Array = []
	for c in team(t).get("members", []):
		if is_instance_valid(c) and (arena < 0 or (c as Combatant).arena_id == arena):
			out.append(c)
	return out


static func alive(t: int, arena := -1) -> Array:
	return members(t, arena).filter(func(c): return not (c as Combatant).is_dead)


static func alive_count(t: int, arena := -1) -> int:
	return alive(t, arena).size()


## L'équipe [param t] n'a plus personne debout (dans [param arena] si >= 0).
static func wiped(t: int, arena := -1) -> bool:
	return alive_count(t, arena) == 0


static func is_out(t: int) -> bool:
	return bool(team(t).get("out", true))


## Équipes encore en lice (pas éliminées), par indice.
static func teams_in() -> Array:
	var out: Array = []
	for tm in teams:
		if not tm.out:
			out.append(int(tm.index))
	return out


## Équipiers de [param c] dans la même arène (lui compris si [param with_self]), morts compris si [param with_dead].
static func allies(c: Combatant, with_self := true, with_dead := false) -> Array:
	var t := team_of(c)
	if t < 0:
		return [c] if with_self and c != null else []
	var out: Array = []
	for m in members(t):
		var mc := m as Combatant
		if (mc == c and not with_self) or not Combatant.same_arena(mc, c) or (mc.is_dead and not with_dead and mc != c):
			continue
		out.append(mc)
	return out


## Adversaires vivants de [param c] (autres équipes, même arène) : le ciblage du jeu (Combatant.ffa_foes).
static func foes(c: Combatant) -> Array:
	if c == null or not c.is_inside_tree():
		return []
	return Combatant.ffa_foes(c.get_tree(), c)


static func same_team(a: Combatant, b: Combatant) -> bool:
	var t := team_of(a)
	return t >= 0 and t == team_of(b)


# --- manches, K.O., élimination --------------------------------------------------------------

static func set_phase(p: String) -> void:
	assert(p in PHASES, "TeamMatch.set_phase : phase inconnue " + p)
	if p == phase:
		return
	phase = p
	bus.phase_changed.emit(p)


## Nouvelle manche : compteur, chrono de manche ; la phase reste au choix du mode (souvent « countdown »).
static func start_round() -> int:
	round_n += 1
	round_t0 = elapsed
	bus.round_started.emit(round_n)
	return round_n


## Fin de manche : [param winner] (-1 : égalité) gagne la manche ; phase « recap ».
static func end_round(winner: int, info := {}) -> void:
	if winner >= 0 and winner < teams.size():
		teams[winner].round_wins = int(teams[winner].round_wins) + 1
	round_log.append({"n": round_n, "winner": winner, "time": elapsed - round_t0, "info": info})
	set_phase("recap")
	bus.round_over.emit(winner, round_n)


## Manches gagnées par l'équipe [param t].
static func round_wins(t: int) -> int:
	return int(team(t).get("round_wins", 0))


## Équipe qui a atteint rounds_to_win manches (-1 : aucune, ou pas de manches gagnantes dans ce mode).
static func round_winner() -> int:
	var need := int(spec.get("rounds_to_win", 0))
	if need <= 0:
		return -1
	for tm in teams:
		if int(tm.round_wins) >= need:
			return int(tm.index)
	return -1


## Un héros tombe : compte le K.O. pour l'équipe du tueur et prévient le mode (bus.member_down).
static func note_ko(victim: Combatant, killer: Combatant = null) -> void:
	var tk := team_of(killer)
	if tk >= 0 and tk != team_of(victim):
		teams[tk].kills = int(teams[tk].kills) + 1
	bus.member_down.emit(victim, team_of(victim))


static func add_score(t: int, v: float) -> void:
	if t >= 0 and t < teams.size():
		teams[t].score = float(teams[t].score) + v


## Élimine l'équipe [param t] : sa place = nombre d'équipes encore en lice (la dernière éliminée finit 2e). Quand il n'en
## reste qu'une, elle prend la 1re place. Rend la place ; 0 si déjà éliminée.
static func eliminate(t: int) -> int:
	if is_out(t):
		return 0
	var place := teams_in().size()
	teams[t].out = true
	teams[t].place = place
	out_order.append(t)
	bus.team_out.emit(t, place)
	var left := teams_in()
	if left.size() == 1 and teams.size() > 1:
		teams[left[0]].place = 1
	return place


## Fin de partie sans élimination (objectif, temps écoulé) : [param order] = indices d'équipe du 1er au dernier ; sans
## ordre, par manches gagnées, puis score, puis K.O.
static func finish(order: Array = []) -> void:
	if order.is_empty():
		order = _sorted(teams_in(), "_rank_key")
	var place := 1
	for t in order:
		if not is_out(int(t)) or int(teams[int(t)].place) == 0:
			teams[int(t)].place = place
			teams[int(t)].out = true
		place += 1
	set_phase("done")


static func place_of(t: int) -> int:
	return int(team(t).get("place", 0))


## Classement : indices d'équipe, 1re place en tête (les équipes encore en lice d'abord, dans l'ordre de leur indice).
static func standing() -> Array:
	return _sorted(range(teams.size()), "_place_key")


## Clés de tri (plus petite = mieux classée) : place (0 = encore en lice, avant tout le monde), puis indice.
static func _place_key(t: int) -> Array:
	var p := place_of(t)
	return [0 if p == 0 else 1, p, t]


## Fin sans élimination : plus de manches gagnées, puis de score, puis de K.O. (puis indice).
static func _rank_key(t: int) -> Array:
	return [-round_wins(t), -float(teams[t].score), -int(teams[t].kills), t]


## Tri par clé ([param key_fn] : « _place_key » ou « _rank_key ») ; sans lambda sur plusieurs lignes (piège du parseur).
static func _sorted(idx: Array, key_fn: String) -> Array:
	var keyed: Array = []
	for t in idx:
		keyed.append([_place_key(int(t)) if key_fn == "_place_key" else _rank_key(int(t)), int(t)])
	keyed.sort()
	return keyed.map(func(e): return e[1])


## Bilan de la partie (pour ResultsPanel, les récompenses et Quests.end_run) : place et victoire de l'équipe du joueur.
static func result() -> Dictionary:
	var rows: Array = []
	for t in standing():
		var tm: Dictionary = teams[t]
		rows.append({"index": t, "name": tm.name, "key": tm.key, "motif": tm.motif, "place": tm.place, "score": tm.score,
			"kills": tm.kills, "round_wins": tm.round_wins, "player": t == player_team})
	var place := place_of(player_team)
	return {"mode": mode, "name": title(), "kind": kind(), "place": place,
		"won": place > 0 and place <= int(spec.get("win_places", 1)), "rounds": round_n, "teams": rows, "time": elapsed}


# --- spectateur -------------------------------------------------------------------------------

static func spectate(c: Combatant) -> void:
	watched = c
	bus.watched_changed.emit(c)


## Héros suivant à regarder ([param step] +1 / -1) : les équipiers vivants du joueur d'abord, puis tous les vivants.
static func next_watch(step := 1) -> Combatant:
	var pool: Array = alive(player_team)
	if pool.is_empty():
		for tm in teams:
			pool += alive(int(tm.index))
	if pool.is_empty():
		spectate(null)
		return null
	var i := pool.find(watched)
	var c: Combatant = pool[posmod(i + step, pool.size()) if i >= 0 else 0]
	spectate(c)
	return c


# --- couleurs (jetons couleur.equipe, BIBLE § 3) ----------------------------------------------

## Clés de couleur des équipes dans l'ordre de la palette (2 équipes : azur / braise ; 6 : les 6 premières).
static func palette() -> Array:
	var o: Variant = UiTheme.tok("couleur.equipe.ordre")
	if o is Array and not (o as Array).is_empty():
		return o
	return FALLBACK.map(func(e): return e[0])


static func color_key_at(t: int) -> String:
	var p := palette()
	return String(p[posmod(t, p.size())])


static func _fallback(key: String) -> Array:
	for e in FALLBACK:
		if e[0] == key:
			return e
	return FALLBACK[0]


static func _pal_name(key: String) -> String:
	return String(UiTheme.tok("couleur.equipe.%s.nom" % key, _fallback(key)[1]))


static func _pal_motif(key: String) -> String:
	return String(UiTheme.tok("couleur.equipe.%s.motif" % key, _fallback(key)[3]))


## Couleur de l'équipe [param t] : « clair », « base » ou « fonce ». Hors partie : celle de la palette à cet indice.
static func color(t: int, tone := "base") -> Color:
	var key := String(team(t).get("key", color_key_at(t)))
	return UiTheme.color("equipe.%s.%s" % [key, tone], Color.html(_fallback(key)[2]))


static func team_name(t: int) -> String:
	return String(team(t).get("name", _pal_name(color_key_at(t))))


## Motif de l'équipe (rond, carre, triangle, losange, etoile, croix, hexagone, anneau) : toujours montré avec la couleur.
static func motif(t: int) -> String:
	return String(team(t).get("motif", _pal_motif(color_key_at(t))))


## Couleur de la barre de vie de [param c] vue par le joueur : pomme (équipe du joueur) ou fraise (adversaire) ; jamais la
## couleur d'équipe (piège 11 de l'étude ARENA : pomme et fraise ont un sens).
static func bar_color(c: Combatant) -> Color:
	return UiTheme.color("bonbon.pomme.base") if team_of(c) == player_team else UiTheme.color("bonbon.fraise.base")


# --- héros IA ----------------------------------------------------------------------------------

## Héros scripté (ClassRival) de la classe [param cid] à la fiche d'un vrai héros de niveau [param lv] (nu, ou équipé de
## [param gear] : {emplacement: pièce}), de difficulté [param diff] (0-3). [param t] >= 0 : placé dans l'équipe t et
## l'arène [param arena] (allié du joueur si t = player_team : camp, collisions et groupe « heroes » des alliés d'Arène).
## N'utilise AUCUN état de Duel : Duel.make_ally / make_extra / make_rival lisent Duel.level, difficulty, bare, gear_mode
## (copie de TON équipement par défaut), hp_mult, rival_build : ne pas les appeler hors d'un duel.
static func make_hero(cid: String, lv: int, diff: int, t := -1, arena := -1, gear := {}) -> ClassRival:
	var r := ClassRival.new()
	r.ally = t >= 0 and t == player_team
	r.setup(cid, lv, clampi(diff, 0, ClassRival.NAMES.size() - 1))
	var h := hero_sheet(cid, lv, gear)
	r.use_sheet(h)
	h.free()
	r.display_name = String(GameData.class_data(cid).get("name_fr", cid))
	if t >= 0:
		add(r, t, arena)
	return r


## Fiche (Player hors scène, à libérer) d'un héros de la classe [param cid] au niveau [param lv], équipé de [param gear],
## plafonds JcJ du mode en cours compris (ModeRules du mode d'équipes).
static func hero_sheet(cid: String, lv: int, gear := {}) -> Player:
	var h := Player.new()
	h.foe = true
	h.class_id = cid
	h.cls = GameData.class_data(cid)
	h.level = lv
	h.built = true
	h.foe_gear = gear.duplicate(true)
	h.foe_extra = {}
	var was := Run.hero_level
	var was_active := Run.active
	Run.hero_level = lv
	Run.active = true
	h.recalc_stats()
	PvpCaps.apply(h)
	Run.hero_level = was
	Run.active = was_active
	return h


# --- directeur du mode -------------------------------------------------------------------------

## Monte le directeur du mode (spec.director) sous [param parent] (RunDirector) : setup(parent) s'il existe. null sans directeur.
static func mount(parent: Node) -> Node:
	var path := String(spec.get("director", ""))
	if not active or path == "":
		return null
	var s: Script = load(path)
	var d: Node = s.new()
	parent.add_child(d)
	director = d
	if d.has_method("setup"):
		d.call("setup", parent)
	return d


## Mort du joueur (world.gd) : rendue au directeur du mode s'il la prend (player_down) ; faux sinon.
static func player_down(killer: Combatant = null) -> bool:
	if active and is_instance_valid(director) and director.has_method("player_down"):
		director.call("player_down", killer)
		return true
	return false


## Abandon (menu pause, world.gd) : rendu au directeur du mode s'il le prend (abandon) ; faux sinon.
static func abandon() -> bool:
	if active and is_instance_valid(director) and director.has_method("abandon"):
		director.call("abandon")
		return true
	return false
