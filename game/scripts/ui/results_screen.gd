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
	if Run.survivor:
		return survivor_spec()
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
		"quest": Compass.after("survival", {"unlocked": Run.unlocked_epoch, "seen": Run.seen_items.size()}),
		"buttons": [
			{"text": "Rejouer (%s)" % epoch_name, "primary": true, "disabled": not Run.survival or Run.epoch > Epochs.unlocked(), "call": _replay},
			{"text": "Retour au lobby", "call": _finish},
		],
	}


## Bilan d'un Survivant (lot S1 : le minimum ; S6 y met les coffres d'apparence, le Codex et le bloc « Ton build »).
## Aucune ligne de progression : le mode n'en donne pas.
func survivor_spec() -> Dictionary:
	var zone := String(GameData.zone(Survivor.zone_id).get("name", Survivor.zone_id))
	return {
		"title": TITLES.get(Run.result, "FIN"),
		"tone": "win" if Run.result == "victoire" else "lose",
		"subtitle": "%s · Survivant · %s" % [Run.class_data().get("name_fr", ""), zone],
		"tiles": [[str(Run.max_level), "niveau atteint"], [Run.duration_text(), "durée"], [str(Run.kills), "monstres"],
			[str(Run.elites), "élites"]],
		"gained": [],
		"kept": chest_rows(Run.new_reward_chests()),
		"lost": lost_rows(false),
		"buttons": [
			{"text": "Rejouer", "primary": true, "call": _replay},
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
		out.append(row("Défi du jour réussi", "+%d" % Challenge.BONUS_FIRST, "Première réussite du jour", "expertise"))
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
	out.append(row("Insignes", "+%d" % Run.insignia_gain, insignia_tip() + "\n\n" + ResourceHelp.hint("insignia"), "upgrade"))
	if not Run.seen_items.is_empty():
		out.append(row("Pièces découvertes", str(Run.seen_items.size()), "À acheter à l'Armurerie avec des insignes", "equipment"))
	out.append_array(chest_rows(Run.new_reward_chests()))
	if supplies_kept and supplies() > 0:
		out.append(row("Fournitures", str(supplies()), "Elles rejoignent ta réserve : parchemins, pierres, gemmes et formules se dépensent à la Forge.", "gem"))
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


## D'où viennent les insignes de la run : le détail calculé par Run.finish (Run.insignia_parts, barème
## Economy.survival_insignia_parts), puis le bonus du défi / du rang héroïque et l'autel. Les lignes font le total.
static func insignia_tip() -> String:
	return "\n".join(PackedStringArray(insignia_lines().map(func(l): return "%s : +%d" % [l[0], l[1]]) + insignia_notes()))


## Lignes [libellé, insignes] de l'infobulle ; leur somme = Run.insignia_gain.
static func insignia_lines() -> Array:
	var p := Run.insignia_parts
	if p.is_empty():  # (bilan sans Run.finish de Survie : barème sans prorata)
		p = Economy.survival_insignia_parts(Run.stage, Run.kills, Run.elites, Run.epoch, Run.result == "victoire")
	var out: Array = [["Participation", int(p.get("participation", 0))]]
	var maps := int(p.get("maps", 0))
	if maps > 0:
		out.append(["Carte 2 atteinte" if Run.stage <= 2 else ("Cartes 2 et 3 atteintes" if Run.stage == 3 else "Cartes 2 à %d atteintes" % Run.stage), maps])
	if int(p.get("fights", 0)) > 0:
		out.append(["Monstres et élites", int(p.fights)])
	if int(p.get("victory", 0)) > 0:
		out.append(["Victoire", int(p.victory)])
	var base := 0
	for l in out:
		base += int(l[1])
	var bonus := Run.insignia_gain - Run.fortune_insignia - Menace.insignia_extra - base
	if bonus > 0:
		var who := "Défi du jour" if Run.heroic_rank <= 0 else ("Rang héroïque %d" % Run.heroic_rank if not Challenge.active else "Défi et rang héroïque")
		out.append([who, bonus])
	if Menace.insignia_extra > 0:  # géants vaincus et pactes de la run (passe P12)
		var label := "Pacte de cupidité"
		if Menace.level > 0:
			label = "Menace %s" % Menace.mult_text() + (" et pacte" if Menace.pact_maps > 0 else "")
		out.append([label, Menace.insignia_extra])
	if Run.fortune_insignia > 0:
		out.append(["Autel de la fortune", Run.fortune_insignia])
	return out


## Notes de l'infobulle : ce qui a réduit la participation ou les monstres comptés.
static func insignia_notes() -> Array:
	var notes: Array = []
	if Run.kills < 10:
		notes.append("Vaincs 10 monstres : +%d de participation." % Run.INSIGNIA_BASE)
	if Run.stage <= 1 and not Run.insignia_parts.is_empty() and int(Run.insignia_parts.get("participation", 0)) < Run.INSIGNIA_BASE * (2 if Run.kills >= 10 else 1):
		notes.append("Run courte : participation selon le temps passé sur la 1re carte.")
	if Run.kills > Run.KILL_CAP_PER_MAP * maxi(Run.stage, 1):
		notes.append("Monstres comptés : %d par carte au plus." % Run.KILL_CAP_PER_MAP)
	return notes


## Rejouer : même classe, même époque, sans repasser par le lobby.
func _replay() -> void:
	var epoch := Run.epoch
	var survivor := Run.survivor
	Profile.end_run_survival()
	get_tree().paused = false
	if survivor:
		Survivor.start(Profile.selected_class, Survivor.zone_id, Survivor.palier)  # même zone, même palier
	else:
		Run.start_survival(Profile.selected_class, epoch)
	get_tree().change_scene_to_file("res://scenes/world.tscn")


func _finish() -> void:
	Profile.end_run_survival()
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/lobby.tscn")
