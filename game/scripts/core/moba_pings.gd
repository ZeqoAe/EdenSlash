class_name MobaPings
extends RefCounted
## Les Deux Voies, lot MB-H (MOBA.md § 7.8-7.9) : repères posés par le joueur (molette ou L3 : appui = repère selon ce qu'il
## vise, maintien = roue « Attaquez ! / J'y vais / Repli ! / À moi ! »). Données seules, sans scène : le HUD (MobaHud) les pose
## et les dessine (au sol et sur la mini-carte) ; le coach d'équipe (lot MB-G) les lit pour en faire des ordres aux alliés IA
## ([method recent] : les repères des dernières secondes, ou le signal [member bus].pinged). Rien ici ne change le jeu.
##
##   MobaPings.add("attack", position, cible)   # sorte : attack | objective | go | retreat | help | here
##   MobaPings.recent(8.0)                        # [{kind, pos, target, t, text}]

const KINDS := {
	"attack": {"text": "Attaquez !", "tone": "fraise"},
	"objective": {"text": "Objectif", "tone": "soleil"},
	"go": {"text": "J'y vais", "tone": "lagon"},
	"retreat": {"text": "Repli !", "tone": "mandarine"},
	"help": {"text": "À moi !", "tone": "pomme"},
	"here": {"text": "Ici", "tone": "lagon"},
}
## Roue (maintien) : sortes dans l'ordre haut, droite, bas, gauche (MOBA.md, croquis v2_hud.svg).
const WHEEL := ["attack", "go", "retreat", "help"]
const LIFE := 6.0  # s : un repère reste visible
const MAX := 6

static var list: Array = []  # [{kind, pos, target, t, text}]
static var bus := Bus.new()


class Bus extends RefCounted:
	signal pinged(entry: Dictionary)


static func reset() -> void:
	list = []


## Pose un repère de sorte [param kind] en [param pos] (monde), sur [param target] (héros, structure, objectif ; peut être
## null) ; renvoie l'entrée. Un deuxième repère de la même sorte au même endroit (4 m) remplace le premier.
static func add(kind: String, pos: Vector3, target: Node = null) -> Dictionary:
	if not KINDS.has(kind):
		kind = "here"
	var e := {"kind": kind, "pos": pos, "target": target, "t": Moba.t, "text": String(KINDS[kind].text)}
	list = list.filter(func(x): return not (String(x.kind) == kind and (x.pos as Vector3).distance_to(pos) < 4.0))
	list.append(e)
	while list.size() > MAX:
		list.pop_front()
	bus.pinged.emit(e)
	return e


## Repères des [param secs] dernières secondes (les plus récents en dernier).
static func recent(secs := LIFE) -> Array:
	return list.filter(func(x): return Moba.t - float(x.t) <= secs and Moba.t >= float(x.t))


static func tone(kind: String) -> String:
	return String(KINDS.get(kind, KINDS.here).tone)
