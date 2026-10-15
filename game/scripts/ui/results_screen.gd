class_name ResultsScreen
extends ResultsPanel
## Bilan de fin d'une run de Survie (victoire, défaite, abandon, extraction), puis retour au
## lobby ou nouvelle run. Les autres modes ont leur bilan (Duel, Tour, Donjon, Royale) sur le même
## composant (ResultsPanel).

const TITLES := {"victoire": "VICTOIRE !", "defaite": "DÉFAITE", "abandon": "RUN ABANDONNÉE", "extraction": "EXTRACTION RÉUSSIE"}


func show_results() -> void:
	Tutorial.event("results")
	show_spec(spec())


## Description du bilan (voir ResultsPanel) d'après l'état de Run et du profil.
func spec() -> Dictionary:
	var cls := Run.class_data()
	var epoch_name: String = Epochs.get_def(Run.epoch).name
	var sub := "%s · %s" % [cls.get("name_fr", ""), epoch_name]
	if Run.heroic_rank > 0:
		sub += " · rang héroïque %d" % Run.heroic_rank
	var kept := Run.result in ["victoire", "extraction"]
	return {
		"title": TITLES.get(Run.result, "FIN"),
		"tone": "win" if Run.result == "victoire" else ("info" if Run.result == "extraction" else "lose"),
		"subtitle": sub,
		"notes": ["%s débloquée !" % Run.unlocked_epoch] if Run.unlocked_epoch != "" else [],
		"tiles": [[str(Run.max_level), "niveau atteint"], [Run.duration_text(), "durée"], [str(Run.kills), "monstres"],
			[str(Run.elites), "élites"], [str(Run.gold), "or gagné"], ["%d / %d" % [Run.stage, RunDirector.STAGES], "carte"]],
		"gained": gained_rows(),
		"kept": kept_rows(kept),
		"lost": lost_rows(kept),
		"buttons": [
			{"text": "Rejouer (%s)" % epoch_name, "primary": true, "disabled": not Run.survival or Run.epoch > Epochs.unlocked(), "call": _replay},
			{"text": "Retour au lobby", "call": _finish},
		],
	}


## Progression de la run : maîtrise, étoiles, contrats, sorts et cartes débloqués.
static func gained_rows() -> Array:
	var cls := Run.class_data()
	var out: Array = []
	out.append(row("Maîtrise %s" % cls.get("name_fr", ""), "+%d" % Run.expertise_gain, "", "expertise"))
	if Run.expertise_levels > 0:
		out.append(row("Niveau %d de maîtrise" % Profile.expertise_level(Run.class_id), "+%d pts" % (2 * Run.expertise_levels), "Points de talent", "expertise"))
	if Run.stars_gained > 0:
		out.append(row("Étoile d'époque", "+%d" % Run.stars_gained, "%s : %s" % [Epochs.get_def(Run.epoch).name, Epochs.star_text(Run.epoch)], "new"))
	for hr in Run.heroic_rewards:
		out.append(row("Rang héroïque %d : %s" % [Run.heroic_rank, hr], "", "", "new"))
	if Run.challenge_first:
		out.append(row("Défi de maîtrise réussi", "+%d" % Challenge.BONUS_FIRST, "Première réussite du jour", "expertise"))
	for c in Run.contracts_done:
		out.append(row("Contrat : %s" % c.text, "+%d" % int(c.reward), "", "expertise"))
	var lvl := Profile.expertise_level(Run.class_id)
	for l in range(lvl - Run.expertise_levels + 1, lvl + 1):
		for r in Progression.rewards_at(Run.class_id, l):
			if r.kind != "talent":
				out.append(row(String(r.name) if r.kind == "cert" else "Sort : " + String(r.name), "", "", "grimoire"))
	for c in Run.new_classes:
		out.append(row("Nouvelle classe", String(GameData.class_data(c).get("name_fr", c)), "", "class"))
	for id in Run.new_cards():
		out.append(row("Carte : " + String(Boons.get_def(id).get("name", id)), "", "", "grimoire"))
	for c in Run.new_costumes:
		out.append(row("Trésor : " + String(c), "", "", "collection"))
	if Run.combo_best > 0.0:
		var record := Run.combo_best >= float(Profile.records.get("best_combo", 0.0))
		out.append(row("Dégâts cumulés", number(Run.combo_best), "Nouveau record" if record else "", "attack"))
	return out


## Butin gardé : insignes (avec le détail au survol), pièces découvertes, coffres, fournitures de la réserve.
static func kept_rows(supplies_kept: bool) -> Array:
	var out: Array = []
	out.append(row("Insignes", "+%d" % Run.insignia_gain, insignia_tip(), "upgrade"))
	if not Run.seen_items.is_empty():
		out.append(row("Pièces découvertes", str(Run.seen_items.size()), "À acheter à l'Armurerie avec des insignes", "equipment"))
	out.append_array(chest_rows(Run.new_reward_chests()))
	if supplies_kept and supplies() > 0:
		out.append(row("Fournitures", str(supplies()), "Elles rejoignent ta réserve", "gem"))
	return out


## Ce qui reste dans la run : l'or et les clés, et les fournitures d'une run perdue.
static func lost_rows(supplies_kept: bool) -> Array:
	var out: Array = []
	if Profile.gold > 0:
		out.append(row("Or", number(Profile.gold), "", "gold"))
	if Profile.keys > 0:
		out.append(row("Clés", str(Profile.keys), "", "keys"))
	if not supplies_kept and supplies() > 0:
		out.append(row("Fournitures", str(supplies()), "", "gem"))
	return out


static func supplies() -> int:
	var n := 0
	for k in Profile.bag:
		n += int(Profile.bag[k])
	return n


## D'où viennent les insignes de la run (participation, cartes atteintes, monstres, victoire, bonus).
static func insignia_tip() -> String:
	var lines: PackedStringArray = []
	var sum := 0
	var part := Run.INSIGNIA_BASE if Run.kills >= 10 else 0
	if part > 0:
		lines.append("Participation : +%d" % part)
	else:
		lines.append("Participation : vaincs 10 monstres (+%d)" % Run.INSIGNIA_BASE)
	var cards := 25 * Run.stage
	var fights := Run.kills / 20 + Run.elites * 2
	var win := 60 * Run.epoch if Run.result == "victoire" else 0
	lines.append("Cartes atteintes : +%d" % cards)
	if fights > 0:
		lines.append("Monstres et élites : +%d" % fights)
	if win > 0:
		lines.append("Victoire : +%d" % win)
	if Run.fortune_insignia > 0:
		lines.append("Autel de la fortune : +%d" % Run.fortune_insignia)
	sum = part + cards + fights + win + Run.fortune_insignia
	if Run.insignia_gain > sum:
		lines.append("Bonus (défi, rang héroïque) : +%d" % (Run.insignia_gain - sum))
	return "\n".join(lines)


## Rejouer : même classe, même époque, sans repasser par le lobby.
func _replay() -> void:
	var epoch := Run.epoch
	Profile.end_run_survival()
	get_tree().paused = false
	Run.start_survival(Profile.selected_class, epoch)
	get_tree().change_scene_to_file("res://scenes/world.tscn")


func _finish() -> void:
	Profile.end_run_survival()
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/lobby.tscn")
