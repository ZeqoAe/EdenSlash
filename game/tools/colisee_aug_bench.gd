extends Node
## Banc des atouts du Colisée (lot CO-E, R_CO_E.md) : combats 3 contre 3 IA contre IA, en vrai (world.tscn, carte du
## Colisée, héros scriptés et leurs sorts, anneau de feu, fleurs), trio contre le MÊME trio (mêmes classes, même place),
## l'un avec l'atout mesuré, l'autre sans ; le camp qui le porte alterne. Une ligne JSON par combat (« [cobench] {…} »),
## lue par python tools/colisee_aug_report.py (taux de victoire avec / sans, écart par héros, top 3 relatif simulé).
##
## godot --headless --fixed-fps 60 --path game res://tools/colisee_aug_bench.tscn -- [--augs=lame_affutee,colosse|all]
##   [--n=40] [--mode=trio|solo] [--diff=3] [--seed=N] [--out=C:/chemin/fichier.jsonl] [--arenas=3]
##   [--hz=30 avec --fixed-fps 30 : deux fois moins d'images par seconde de jeu, pour une machine chargée]
## Pseudo-atouts : "" (aucun des deux côtés : contrôle du côté), "gear:N" (N pièces d'enclume par héros), "stat:N".
## Un atout d'équipe (Trio parfait) se mesure porté par un seul héros (--mode=solo ou automatiquement).

const MODE_ID := "co_bench"


func _ready() -> void:
	Settings.reset_all(false)
	Profile.selected_class = "warrior"
	Colisee.register_rules()
	TeamMatch.register(MODE_ID, {"name": "Banc des atouts", "kind": "teams", "teams": 7, "size": 3, "rules": "colisee",
		"arenas": true, "director": "res://tools/colisee_aug_bench_director.gd"})
	Run.start("warrior")
	Run.zone_id = Duel.ZONE
	Profile.equipped = {}
	Profile.inventory = []
	Profile.gold = 0
	Profile.bag = {}
	PvpCaps.reset_stats()
	var n_teams := 7
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--arenas="):
			n_teams = clampi(int(arg.trim_prefix("--arenas=")), 1, 3) * 2 + 1
		elif arg.begins_with("--hz="):
			Engine.physics_ticks_per_second = clampi(int(arg.trim_prefix("--hz=")), 20, 60)  # (avec --fixed-fps du même nombre)
	TeamMatch.begin(MODE_ID, n_teams)
	var world: Node = load("res://scenes/world.tscn").instantiate()
	get_tree().root.add_child.call_deferred(world)
