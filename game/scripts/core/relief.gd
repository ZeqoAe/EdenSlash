class_name Relief
extends RefCounted
## Relève (lot DNG-3, backlog BM-DNG P1-3) : une seconde chance sans honte dans les modes de boss. Un coup fatal ne finit pas
## la partie : le héros se relève sur place (moitié de ses PV, 2,5 s intouchable). Une relève au départ, rendue à chaque boss
## (BossLibrary.spawn : boss d'un donjon, de la Ruée, d'un étage de la Tour ; jamais un lieutenant), jamais deux d'avance.
##   Donjons et Ruée : en Normal et Héroïque ; aucune en Mythique.
##   La Tour : Facile, Normal, Difficile ; aucune en Hardcore.
##   Le Siège (une seule vie, chacun pour soi), la Survie et les autres modes : aucune.
## Un allié IA debout « te relève » (le texte le dit) ; sans allié, tu te relèves seul : la règle est la même.
## Une relève utilisée coûte l'étoile « Personne ne tombe » (DungeonStars) ; le butin, les records et le reste ne changent pas.

const HP_BACK := 0.5
const SHIELD := 2.5
const DELAY := 1.2

static var left := 0  # relèves disponibles
static var used := 0  # relèves utilisées pendant la partie
## false : aucune relève (tests qui mesurent une chute). Le pilote automatique des outils de mesure (Player.autoplay) n'en a
## jamais non plus : les mesures d'équilibre (dungeon_run, tower_run, m6_run, boss_ttk) restent comparables à celles d'avant.
static var enabled := true


## La partie en cours a droit aux relèves (une par boss).
static func allowed() -> bool:
	if not enabled or not Tower.active or Tower.siege or BossPractice.active:
		return false
	if Tower.is_dungeon():
		return Tower.dungeon_diff < 2
	return Tower.difficulty < 3


## Début d'une partie (Tower.start) : une relève si le mode en a.
static func reset() -> void:
	used = 0
	left = 0


## Après le réglage du mode (Tower.start_dungeon, Tower.start) : la relève du départ.
static func arm() -> void:
	left = 1 if allowed() else 0


## Un boss vient d'apparaître (BossLibrary.spawn) : la relève est rendue (jamais plus d'une).
static func on_boss(lieutenant: bool) -> void:
	if not lieutenant and allowed():
		left = 1


## Le héros vient de tomber (world._on_player_died) : true si une relève le remet debout (la partie continue).
static func try_save(world: Node, player: Player) -> bool:
	if not allowed() or left <= 0 or player == null or player.autoplay:
		return false
	left -= 1
	used += 1
	var ally := _ally_name(world)
	world.hud.show_message(("Relève ! %s te remet debout" % ally) if ally != "" else "Relève ! Tu te remets debout", 2.0)
	world.get_tree().create_timer(DELAY, false).timeout.connect(func():
		if not is_instance_valid(player) or not Tower.active:
			return
		player.respawn(player.global_position)
		player.hp = player.max_hp * HP_BACK
		player.health_changed.emit(player.hp, player.max_hp)
		player.shield_until = player._time + SHIELD
		Sfx.ui("pickup", -4.0))
	return true


## Nom d'un allié IA encore debout (« Prêtre »), "" sinon.
static func _ally_name(world: Node) -> String:
	var t = world.director.tower if world.director != null else null
	if t == null or not "_allies" in t:
		return ""
	for a in t._allies:
		if is_instance_valid(a) and not a.is_dead:
			return String(a.display_name).trim_prefix("<Duel> ")
	return ""


## Pastille du HUD collée aux PV : « Relève 1 » ("" : pas de relève dans ce mode).
static func pill_text() -> String:
	if not allowed():
		return ""
	return "Relève %d" % left if left > 0 else "Relève 0"
