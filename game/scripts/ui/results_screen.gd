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


## Bilan d'un Survivant (lot S6) : l'avancée (niveau, durée, gardiens, boss), le titre gagné, les coffres d'apparence (les
## seules récompenses du mode : jamais d'insignes, de maîtrise ni de découverte) et le build final. Rien n'est perdu.
func survivor_spec() -> Dictionary:
	var last := SurvivorRewards.last
	var zone := String(GameData.zone(Survivor.zone_id).get("name", Survivor.zone_id))
	var tier := int(last.get("tier", Survivor.palier))
	var sub := "%s · Survivant · %s" % [Run.class_data().get("name_fr", ""), zone]
	if tier > 1:
		sub += " · palier %s" % Survivor.numeral(tier)
	var won := Run.result == "victoire"
	var boss := "vaincu" if won else ("atteint" if bool(last.get("boss", false)) else "—")
	var kept := survivor_chest_rows(last)
	var note := ""
	if kept.is_empty():
		note = "Tiens 10 minutes pour gagner un coffre d'apparence." if SurvivorRewards.reached(Run.result).is_empty() else "Récompenses du jour déjà prises."
	return {
		"title": TITLES.get(Run.result, "FIN"),
		"tone": "win" if won else "lose",
		"subtitle": sub,
		"notes": survivor_notes(last),
		"tiles": [[str(Run.max_level), "niveau atteint"], [SurvivorDirector.clock(float(last.get("time", 0.0))), "durée"],
			[str(Run.kills), "monstres"], [str(Run.elites), "élites"],
			["%d / %d" % [mini(int(last.get("guardians", 0)), int(last.get("guardians_total", SurvivorRewards.GUARDIANS))),
				int(last.get("guardians_total", SurvivorRewards.GUARDIANS))], "gardiens"],
			[boss, "boss", "Le boss t'attend à %s." % SurvivorDirector.clock(Survivor.RUN_TIME)]],
		"kept": kept,
		"build": survivor_build_rows(last.get("build", {})),
		"quest": Quests.report_line(),
		"footnote": note,
		"buttons": [
			{"text": "Rejouer", "primary": true, "call": _replay},
			{"text": "Changer de classe", "call": _change_class},
			{"text": "Retour au lobby", "call": _finish},
		],
	}


## Annonces dorées du bilan d'un Survivant : titre nouveau, palier de difficulté ouvert par la victoire (lot S8).
static func survivor_notes(last: Dictionary) -> Array:
	var out: Array = []
	if bool(last.get("new_title", false)):
		out.append("Titre gagné : « %s »" % String(last.title))
	if int(last.get("opened", 0)) > 0:
		out.append("Palier %s ouvert !" % Survivor.numeral(int(last.opened)))
	return out


## Coffres d'apparence de la run : un par palier d'avancée atteint (avec la raison au survol), puis ceux des quêtes.
static func survivor_chest_rows(last: Dictionary) -> Array:
	var out: Array = []
	var mine: Array = last.get("chests", [])
	for g in mine:
		var why := "%s · %s" % [g.text, "première fois" if String(g.kind) == "first" else "une fois par jour"]
		out.append(row(Rewards.kind_name(String(g.type)), "×1", why, "chest"))
	out.append_array(chest_rows(Run.new_reward_chests().slice(mine.size())))
	return out


## Le build final : arme, pièces, panoplie, passifs et sorts (détail au survol).
static func survivor_build_rows(b: Dictionary) -> Array:
	var out: Array = []
	if b.is_empty():
		return out
	var w: Dictionary = b.weapon
	if w.is_empty():
		out.append(row("Sans arme", "", "", "weapon"))
	else:
		out.append(row(String(w.name), "+%d" % int(w.upgrade) if int(w.upgrade) > 0 else "", "", "weapon"))
	var tip: PackedStringArray = []
	for p in b.pieces:
		tip.append("%s : %s%s" % [Items.SLOT_NAMES.get(p.slot, p.slot), "+%d " % int(p.upgrade) if int(p.upgrade) > 0 else "", p.name])
	out.append(row("Pièces", "%d / %d" % [(b.pieces as Array).size(), int(b.slots) - 1], "\n".join(tip), "armor"))
	if int(b.set_n) >= 2:
		out.append(row("Panoplie " + String(b.set), "%d / 5" % int(b.set_n), "Bonus à 2, 3 et 5 pièces", "equipment"))
	if int(b.plus10) > 0:
		out.append(row("Pièces à +10", str(b.plus10), "", "upgrade"))
	if int(b.perfect) > 0:
		out.append(row("Jets parfaits", str(b.perfect), "Pièces à 120 % de qualité", "new"))
	var spells: Array = b.spells
	var names: PackedStringArray = []
	for s in spells:
		names.append("%s (niv. %d)" % [s.name, int(s.rank)])
	var shown := spells.size() if spells.size() <= 4 else 3  # quatre sorts au plus en ligne, sinon trois et « N autres »
	for k in shown:
		out.append(row(String(spells[k].name), "niv. %d" % int(spells[k].rank), "\n".join(names), "grimoire"))
	if spells.size() > shown:
		var more := spells.size() - shown
		out.append(row("%d autre%s sort%s" % [more, "s" if more > 1 else "", "s" if more > 1 else ""], "", "\n".join(names), "grimoire"))
	return out


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
		Survivor.start(Run.class_id, Survivor.zone_id, Survivor.palier)  # même classe, même zone, même palier
	else:
		Run.start_survival(Profile.selected_class, epoch)
	get_tree().change_scene_to_file("res://scenes/world.tscn")


## Survivant : retour au lobby sur la page du mode, avec le choix de classe ouvert.
func _change_class() -> void:
	Survivor.lobby_request = "class"
	_finish()


func _finish() -> void:
	Profile.end_run_survival()
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/lobby.tscn")
