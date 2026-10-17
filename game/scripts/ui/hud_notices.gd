class_name HudNotices
extends RefCounted
## File unique des notifications du HUD (lot HUB-1, P0-7) : une seule carte à la fois, par priorité (danger > quête >
## nouveauté > butin), la suivante attend. Le bandeau d'annonce du haut (Hud.show_message : boss, rage, danger) passe
## avant tout : tant qu'il est affiché, aucune carte ne sort et le fil de butin attend lui aussi (Hud.feed).
## Les cartes sont celles d'InfoCard (la pile du HUD) ; une carte déjà affichée n'est jamais coupée.
## [codeblock]
## hud.notices.push("quest", {"id": …, "title": "Quête accomplie", "body": …, "duration": 9.0})
## [/codeblock]

const PRIO := {"danger": 0, "quest": 1, "news": 2, "loot": 3}

var cards: InfoCard
var hold := Callable()  # vrai tant que le bandeau d'annonce est affiché (les cartes attendent)
var _pending: Array = []  # [{prio, seq, kind, spec}]
var _seq := 0
var shown: Array = []  # (tests) genres des cartes montrées, dans l'ordre


func _init(stack: InfoCard, hold_fn := Callable()) -> void:
	cards = stack
	hold = hold_fn


## Met une carte dans la file ([param kind] : danger, quest, news, loot).
func push(kind: String, spec: Dictionary) -> void:
	_seq += 1
	_pending.append({"prio": int(PRIO.get(kind, 3)), "seq": _seq, "kind": kind, "spec": spec})
	_pending.sort_custom(func(a, b): return a.prio < b.prio or (a.prio == b.prio and a.seq < b.seq))
	tick()


## Rien d'affiché ni d'attente : une fiche de découverte peut être proposée (Hud._update_tutorial).
func idle() -> bool:
	return _pending.is_empty() and (cards == null or cards.count() == 0)


func pending() -> int:
	return _pending.size()


## Montre la carte suivante si la place est libre (appelé à chaque image par le HUD).
func tick() -> void:
	if _pending.is_empty() or cards == null or not is_instance_valid(cards):
		return
	if cards.count() > 0 or (hold.is_valid() and bool(hold.call())):
		return
	var e: Dictionary = _pending.pop_front()
	shown.append(String(e.kind))
	cards.add_card(e.spec)
