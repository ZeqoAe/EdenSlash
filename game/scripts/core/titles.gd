class_name Titles
extends RefCounted
## Titres (lot GX-5, étude BM-GEAR Q9 : « les titres dans l'écran Héros ») : le catalogue de tous les titres que le jeu
## peut donner, rangés par source, avec la phrase qui dit comment l'obtenir. Rien n'est sauvegardé ici : les titres
## gagnés restent dans `Profile.extra_titles` et les succès (`Achievements.titles()`), le titre porté dans `Profile.title`.
## Un titre ne donne aucune stat (cosmétique : il s'affiche sous le nom du héros).
##
## - [method catalog] : [{title, how, group}] (un titre gagné absent du catalogue, d'une vieille version, va dans « Autres ») ;
## - [method owned], [method wear], [method worn_text], [method groups].

## Sources dans l'ordre d'affichage.
const GROUPS := ["Niveau de héros", "Succès", "Survie", "Donjons", "La Tour", "Ruée des boss", "Le Siège", "Duel et Arènes", "Panthéon",
	"Quêtes", "Survivant", "Battle royale", "L'Échiquier", "Autres"]


## Tous les titres : {title, how, group}, sans doublon (le premier qui le donne garde la phrase).
static func catalog() -> Array:
	var out: Array = []
	var seen := {}
	var add := func(t: String, how: String, group: String) -> void:
		if t == "" or seen.has(t):
			return
		seen[t] = true
		out.append({"title": t, "how": how, "group": group})
	for m in HeroLevel.MILESTONES:
		add.call(String(m.title), "Atteindre le niveau de héros %d." % int(m.level), "Niveau de héros")
	for a in Achievements.LIST:
		add.call(String(a.title), String(a.desc), "Succès")
	for e in range(1, Epochs.count() + 1):
		add.call("Héros de %s" % Epochs.get_def(e).name, "Finir le rang héroïque %d de l'%s." % [Epochs.HEROIC_MAX, Epochs.get_def(e).name], "Survie")
	for m in _const("DungeonStars", "MILESTONES"):
		add.call(String(m.title), ("%d donjon%s à trois étoiles en Mythique." if bool(m.mythic) else "%d donjon%s à trois étoiles.") % [int(m.n), "s" if int(m.n) > 1 else ""], "Donjons")
	for i in Dungeons.RUSH_TITLES.size():
		add.call(String(Dungeons.RUSH_TITLES[i]), "Vaincre les 8 boss de la Ruée en %s." % String(Dungeons.DIFF_NAMES[mini(i, Dungeons.DIFF_NAMES.size() - 1)]), "Ruée des boss")
	add.call(Siege.TITLE, "Gagner le Siège.", "Le Siège")
	add.call("Arène à deux", "Gagner une Arène 2 contre 2.", "Duel et Arènes")
	add.call("Arène à trois", "Gagner une Arène 3 contre 3.", "Duel et Arènes")
	add.call("Gantelet", "Gagner un Gantelet.", "Duel et Arènes")
	add.call("Gantelet complet", "Gagner le Gantelet contre trois adversaires.", "Duel et Arènes")
	for b in Pantheon.BRAINS:
		add.call(String(b.title), "Battre l'Esprit %s du Panthéon." % String(b.name), "Panthéon")
	add.call(Pantheon.MASTER_TITLE, "Éveiller les 6 pièces des Esprits.", "Panthéon")
	add.call(Pantheon.FIVE_TITLE, "Battre le Champion avec les 5 familles.", "Panthéon")
	for g in Quests.SERIES_GIFTS:
		if g.has("title"):
			add.call(String(g.title), "Tenir une série de quêtes de %d jours." % int(g.n), "Quêtes")
	for i in SurvivorRewards.TITLES.size():
		add.call(String(SurvivorRewards.TITLES[i]), "Gagner le palier %s du Survivant." % ["I", "II", "III", "IV", "V"][mini(i, 4)], "Survivant")
	for d in _const("SurvivorRecords", "DEFIS"):
		add.call(String(d.get("title", "")), "Survivant : %s." % String(d.get("text", "")), "Survivant")
	add.call("Dernier debout", "Gagner une partie de Battle royale.", "Battle royale")
	var ranks := ["", "Argent", "Or", "Platine"]
	var rt: Array = _const("RoyaleLeague", "RANK_TITLE")
	for r in range(1, rt.size()):
		add.call(String(rt[r]), "Atteindre le rang %s de la Ligue royale." % String(ranks[mini(r, ranks.size() - 1)]), "Battle royale")
	for d in AutochessRewards.TITLES.size():
		add.call(String(AutochessRewards.TITLES[d]), "Gagner une partie de l'Échiquier en %s." % AutochessRewards.diff_name(d), "L'Échiquier")
	for e in AutochessRewards.EXPLOITS:
		add.call(String(e.title), "L'Échiquier : %s." % String(e.text), "L'Échiquier")
	for t in owned():
		add.call(String(t), "Titre gagné.", "Autres")
	return out


## Constante [param key] de la classe nommée [param cls] si elle existe (des sources viennent de lots récents : on les lit
## sans en dépendre) ; [] sinon.
static func _const(cls: String, key: String) -> Array:
	for c in ProjectSettings.get_global_class_list():
		if String(c.get("class", "")) == cls:
			var s: Script = load(String(c.path))
			if s != null:
				var v: Variant = s.get_script_constant_map().get(key, [])
				return v if v is Array else []
	return []


## Titres gagnés (succès et autres sources).
static func owned() -> Array:
	return Achievements.titles()


static func has(t: String) -> bool:
	return t in owned()


## Porte le titre [param t] ("" ou le titre déjà porté : n'en porte plus). Renvoie le titre porté.
static func wear(t: String) -> String:
	if t == "" or t == Profile.title:
		Profile.title = ""
	elif has(t):
		Profile.title = t
	Profile.save_profile()
	return Profile.title


## « Titre porté : « Vétéran » » ou « Aucun titre porté ».
static func worn_text() -> String:
	return "Aucun titre porté" if Profile.title == "" else "« %s »" % Profile.title


## Titres groupés : [[groupe, [entrées]]] dans l'ordre de [constant GROUPS] (les groupes vides sont omis).
static func groups(entries: Array) -> Array:
	var out: Array = []
	for g in GROUPS:
		var list := entries.filter(func(e): return String(e.group) == g)
		if not list.is_empty():
			out.append([g, list])
	return out
