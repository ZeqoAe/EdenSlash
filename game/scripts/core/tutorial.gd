class_name Tutorial
extends RefCounted
## Tutoriel (conception, lot 9, repris au lot U2) : un accueil de 3 écrans, les « Premiers pas » dans la
## vraie Survie (jamais dans les autres modes), des fiches de découverte à la 1re rencontre, un Guide (F1)
## qui est la seule aide du jeu, et « Nouveau dans cette version ».
## État dans `Profile.tutorial` : {mode: "guided" | "skip", steps: [ids faits], seen: [fiches vues],
## version: dernière version dont les nouveautés ont été vues, cards_off: bool}. Passer ne débloque rien
## et ne bloque rien : cela coupe seulement les explications.

## Premiers pas : (id, texte, événement qui le valide, nombre d'occurrences). {touche:action} est
## remplacé par la touche réelle du joueur. Ils ne s'affichent que dans la Survie.
const STEPS := [
	{"id": "weapon", "text": "Ton équipement du hub est déjà porté. Frappe un monstre.", "event": "weapon", "n": 1},
	{"id": "fight", "text": "Déplace-toi avec {move_forward}{move_left}{move_back}{move_right} et vaincs 10 monstres.", "event": "kill", "n": 10},
	{"id": "jump", "text": "Saute avec {jump}.", "event": "jump", "n": 1},
	{"id": "dodge", "text": "Esquive avec {dodge} : la roulade te rend invulnérable.", "event": "dodge", "n": 1},
	{"id": "card", "text": "Niveau 2 : choisis une carte.", "event": "card", "n": 1},
	{"id": "skill", "text": "Lance ton sort avec {skill_1}.", "event": "skill", "n": 1},
	{"id": "chain", "text": "Enchaîne : rappuie sur {skill_1} pendant que la barre se remplit.", "event": "chain", "n": 1},
	{"id": "chest", "text": "Ouvre un coffre avec {interact} : il coûte de l'or ou une clé.", "event": "chest", "n": 1},
	{"id": "seal", "text": "Bats un gardien d'élite : il porte un sceau (3 ouvrent le donjon).", "event": "seal", "n": 1},
	{"id": "boss", "text": "Entre dans le donjon et bats le boss.", "event": "boss", "n": 1},
]

## Fiches de découverte : titre, 3 lignes au plus, chapitre du Guide (`Guide.CHAPTERS`), version qui l'a
## ajoutée. `on` : l'événement qui la déclenche à la 1re occurrence ("" : seulement dans le Guide, et
## annoncée comme nouveauté aux sauvegardes plus anciennes). Pas de pourcentage : le détail est dans le Guide.
const CARDS := {
	"cards": {"title": "Les cartes", "on": "cards_open", "version": "0.1.141", "chapter": "cards",
		"short": "À chaque niveau, choisis une carte parmi trois. Sa couleur dit sa rareté.", "icon": "grimoire",
		"lines": ["À chaque niveau, choisis une carte parmi trois : sa couleur dit sa rareté.", "Tu peux en bannir, en garder pour plus tard ou relancer le tirage.", "Tes sorts, tes enchaînements et ton arme grandissent par cartes."]},
	"weapon_up": {"title": "L'arme grandit", "on": "weapon_up", "version": "0.1.141", "chapter": "cards",
		"short": "Chaque carte d'arme monte son niveau. Au niveau 4, son effet légendaire s'éveille.", "icon": "weapon",
		"lines": ["Chaque carte d'arme monte son niveau (8 au plus).", "Au niveau 4, l'effet légendaire de ta variante s'active.", "Un boss de carte t'offre toujours une amélioration d'arme."]},
	"chain": {"title": "Enchaînements", "on": "chain_open", "version": "0.1.141", "chapter": "cards",
		"short": "Rappuie sur la touche d'un sort pendant que la barre se remplit : le sort suivant part, plus fort.", "icon": "power",
		"lines": ["Rappuie sur la touche d'un sort pendant que la barre se remplit : le sort suivant part, plus fort.", "En Assisté, un appui trop tôt est gardé.", "Tenir la touche joue toute la chaîne."]},
	"perfect": {"title": "Annulation parfaite", "on": "perfect", "version": "0.1.141", "chapter": "cards",
		"short": "Esquive juste après l'impact d'un sort pour gagner de la Fluidité et raccourcir ta recharge.", "icon": "speed",
		"lines": ["Esquive juste après l'impact d'un sort (anneau bleu) : tu gagnes de la Fluidité et ta recharge raccourcit.", "C'est le geste d'expert : l'automatique ne le fait pas.", "Esquiver avant l'impact te rend ton sort."]},
	"trophy": {"title": "Trophées", "on": "trophy", "version": "0.1.141", "chapter": "cards",
		"short": "12 trophées au plus, tous différents. Ils se perdent à la fin de la partie.", "icon": "expertise",
		"lines": ["12 trophées au plus, tous d'effets différents.", "Ils se perdent à la fin de la partie.", "Chacun déclenche un effet sous condition : coup, esquive, élimination…"]},
	"offhand": {"title": "Deux armes", "on": "offhand", "version": "0.1.229", "chapter": "cards",
		"short": "Ton arme secondaire ne frappe pas seule : « Changer d'arme » la met en main, même en plein combat.", "icon": "weapon",
		"lines": ["Arme principale : celle de ta classe. Arme secondaire : n'importe quel autre type.", "« Changer d'arme » (Paramètres > Touches) les échange en plein combat.",
			"En main, la secondaire change ton auto-attaque. Tes sorts restent ceux de ta classe."]},
	"fortune": {"title": "Autel de la fortune", "on": "fortune", "version": "0.1.141", "chapter": "run",
		"short": "Huit étages : encaisse ou monte tenter le suivant. Une case est piégée et fait tout perdre.", "icon": "gem",
		"lines": ["Huit étages : encaisse ou monte tenter l'étage suivant.", "Une case est piégée : elle fait tout perdre.", "Les gains sont des insignes et des coffres d'apparence."]},
	"giant": {"title": "Géants et Menace", "on": "giant", "version": "0.1.191", "chapter": "run",
		"short": "Vaincs le géant de l'autel : une carte, mais monstres et boss résistent plus jusqu'à la fin de la partie.", "icon": "attack",
		"lines": ["L'autel du géant en réveille un, bien plus fort qu'une élite.", "Vaincu, il donne une carte et la Menace monte : monstres et boss plus résistants jusqu'à la fin de la partie.", "Plus la Menace est haute, plus la partie rapporte d'insignes."]},
	"merchant": {"title": "Marchands", "on": "merchant", "version": "0.1.141", "chapter": "run",
		"short": "Cartes, clés et fournitures contre de l'or. L'or ne sort pas de la partie : dépense-le.", "icon": "misc",
		"lines": ["Cartes, clés et fournitures contre de l'or.", "L'or ne sort pas de la partie : dépense-le."]},
	"shrine": {"title": "Sanctuaires", "on": "shrine", "version": "0.1.141", "chapter": "run",
		"short": "Reste dans le cercle pour capturer le sanctuaire. Il offre un trophée, des clés ou une carte.", "icon": "pin",
		"lines": ["Reste dans le cercle pour capturer le sanctuaire.", "Il offre un trophée, des clés ou une carte."]},
	"reward_chest": {"title": "Coffres de récompense", "on": "reward_chest", "version": "0.1.141", "chapter": "run",
		"short": "Un coffre ramassé est toujours gardé, même si tu tombes. Ouvre-le dans le menu Coffres.", "icon": "chest",
		"lines": ["Un coffre ramassé est toujours gardé, même si tu tombes.", "Ouvre-le dans le menu Coffres."]},
	"rage": {"title": "La rage", "on": "rage", "version": "0.1.141", "chapter": "run",
		"short": "Passé le temps imparti, la horde enrage : plus dure, plus de butin. Vise le boss et le portail.", "icon": "attack",
		"lines": ["Passé le temps imparti, la horde enrage : plus dure, plus de butin.", "Le boss et le portail restent ton objectif."]},
	"portal": {"title": "Les étapes", "on": "portal", "version": "0.1.141", "chapter": "run",
		"short": "Chaque époque a 3 cartes. Le boss ouvre le portail vers la suivante, et tu gardes tout.", "icon": "play",
		"lines": ["Chaque époque a 3 cartes : le boss ouvre le portail vers la suivante.", "Tu gardes niveau, cartes et équipement d'une carte à l'autre."]},
	"boss_plans": {"title": "Coffre de plans", "on": "boss_plans", "version": "0.1.236", "chapter": "run",
		"short": "Chaque boss de carte t'offre un plan : une pièce nouvelle, à fabriquer à l'Atelier. Gardé même si tu tombes.", "icon": "chest",
		"lines": ["Chaque boss de carte t'offre un plan, au choix parmi trois pièces que tu n'as pas encore.", "La pièce se fabrique ensuite à l'Atelier avec des insignes.",
			"Le plan est à toi dès le boss vaincu, même si tu tombes ensuite."]},
	"results": {"title": "Ce que tu gardes", "on": "results", "version": "0.1.141", "chapter": "run",
		"short": "Gardés : la maîtrise, les insignes et les coffres. Perdus : l'or, les clés et les trouvailles.", "icon": "save",
		"lines": ["Toujours gardés : la maîtrise, les insignes, les coffres de récompense.", "Perdus : l'or, les clés et les trouvailles de la partie.", "Ton équipement du hub reste intact."]},
	"assist": {"title": "Aide au combat", "on": "", "version": "0.1.134", "chapter": "controls",
		"short": "Manuel, Assisté, Détente ou Pilote auto : règle ton aide au combat dans Paramètres > Combat.", "icon": "settings",
		"lines": ["Manuel, Assisté, Détente ou Pilote auto : Paramètres > Combat.", "Assisté garde les appuis de sorts et annonce l'annulation parfaite."]},
	"dungeons": {"title": "Donjons", "on": "", "version": "0.1.150", "chapter": "modes",
		"short": "Plusieurs salles, un boss et un butin propre à chaque donjon. Seul ou avec des alliés.", "icon": "defense",
		"lines": ["Plusieurs salles, un boss, un butin propre à chaque donjon.", "Joue-les seul ou avec des alliés IA."]},
	"quests": {"title": "Quêtes", "on": "", "version": "0.1.196", "chapter": "modes",
		"short": "Trois quêtes par jour et deux par semaine, dans Jouer. Elles donnent maîtrise et apparences.", "icon": "new",
		"lines": ["Trois quêtes par jour et deux par semaine, dans Jouer > Quêtes. Le Défi du jour est l'une d'elles.", "Une quête du jour accomplie par jour prolonge ta série, qui offre des apparences.", "Aucune n'est obligatoire : tu peux changer une quête du jour, une fois par jour."]},
	# Survivant, nouveauté annoncée au lobby (lot S8 : le mode est ouvert à tous) ; rangée au chapitre Modes du Guide.
	"survivor": {"title": "Survivant", "on": "", "version": "0.1.210", "chapter": "modes",
		"short": "Nouveau mode : vingt minutes, tu pars sans rien et tout se gagne aux cartes. Jouer > Aventure.", "icon": "clock",
		"lines": ["Vingt minutes sur une carte : arme, pièces et sorts se gagnent aux cartes.", "Chaque pièce prise reste à vie ; le boss arrive à 20:00.",
			"Cinq paliers de difficulté ; il donne des apparences et des titres."]},
	# Survivant (lot S5) : montrées dans le choix de cartes lui-même (CardPicker._show_tip), à la 1re rencontre ; jamais
	# annoncées comme nouveautés (le mode s'annonce par la fiche « survivor »).
	"sv_first": {"title": "Survivant : 1re carte", "on": "", "version": "0.1.194", "chapter": "cards", "news": false,
		"short": "Choisis une arme ou un sort pour commencer. Pièces, armes et sorts se gagnent ensuite aux cartes.", "icon": "grimoire",
		"lines": ["En Survivant, tu pars sans arme ni pièce : la première carte donne une arme ou un sort.", "Tout le reste se gagne aux cartes, niveau après niveau."]},
	"sv_locked": {"title": "Survivant : pièce à vie", "on": "", "version": "0.1.194", "chapter": "gear", "news": false,
		"short": "Une pièce prise reste dans son emplacement jusqu'à la fin de la partie. Passer garde la place pour mieux.", "icon": "armor",
		"lines": ["En Survivant, une pièce prise reste dans son emplacement jusqu'à la fin de la partie.", "Les pièces trouvées plus tard sont plus rares : passer garde la place libre."]},
	"sv_tier": {"title": "Survivant : paliers", "on": "", "version": "0.1.194", "chapter": "gear", "news": false,
		"short": "À +6, +8 et +10, la pièce gagne un passif. Il est écrit sur la carte : tu le vois avant de choisir.", "icon": "upgrade",
		"lines": ["En Survivant, une pièce gagne un passif à +6, +8 et +10 : quatre à +10.", "Le passif est tiré quand la carte est proposée et écrit dessus.", "Relancer ou bannir en tire un autre."]},
	# L'Échiquier (lot AC-I) : la nouveauté annoncée au lobby, puis trois fiches montrées dans l'écran du mode à la 1re
	# rencontre (AutochessScreen._tip_check), jamais annoncées comme nouveautés.
	"autochess": {"title": "L'Échiquier", "on": "", "version": "0.1.256", "chapter": "modes", "icon": "class",
		"short": "Nouveau mode : recrute des héros, place-les et regarde-les se battre. Jouer > Affrontements.",
		"lines": ["Huit stratèges, un seul gagnant : recrute des héros, place-les, ils se battent seuls.", "Quatre difficultés ; il donne des apparences et des titres, rien d'autre."]},
	"ac_shop": {"title": "Achète et place", "on": "", "version": "0.1.256", "chapter": "modes", "news": false, "icon": "class",
		"short": "Achète des héros (1 à 5) et pose-les. Chaque tranche de 10 or gardée rapporte 1 or par manche.",
		"lines": ["Achète des héros dans la boutique (touches 1 à 5) et pose-les sur le plateau : ils se battent seuls.", "Ton niveau fixe le nombre de héros posés ; l'XP s'achète.",
			"Chaque tranche de 10 or gardée rapporte 1 or par manche (5 au plus)."]},
	"ac_stars": {"title": "Trois copies, une étoile", "on": "", "version": "0.1.256", "chapter": "modes", "news": false, "icon": "new",
		"short": "Trois copies d'un même héros fusionnent en une étoile de plus : plus de vie, plus de dégâts.",
		"lines": ["Trois copies d'un même héros fusionnent : il gagne une étoile.", "Trois héros à deux étoiles font un héros à trois étoiles, bien plus fort."]},
	"ac_traits": {"title": "Traits et atouts", "on": "", "version": "0.1.256", "chapter": "modes", "news": false, "icon": "grimoire",
		"short": "Des héros d'un même trait l'activent. En 2-1, 3-2 et 4-2, choisis un atout pour toute la partie.",
		"lines": ["Chaque héros a deux traits : sa famille et son arme. Assez de héros d'un même trait l'activent.", "En 2-1, 3-2 et 4-2, un atout au choix change toute la partie."]},
	"hub_gear": {"title": "Équipement du hub", "on": "", "version": "0.1.173", "chapter": "gear",
		"short": "Tu pars avec l'équipement porté au hub. Après la partie, il est exactement comme avant.", "icon": "armor",
		"lines": ["Tu pars avec l'équipement que tu portes au hub : pièces, +N, gemmes, enchantements.", "Les trouvailles de coffre le remplacent le temps de la partie.", "Après la partie, ton équipement est exactement comme avant."]},
}


# --- état --------------------------------------------------------------------------------
static func mode() -> String:
	return String(Profile.tutorial.get("mode", ""))


## Les Premiers pas sont actifs (Survie seulement, mode guidé, pas terminés).
static func guided() -> bool:
	return mode() == "guided" and Run.active and Modes.current() == "survival" and not done_all()


static func set_mode(m: String) -> void:
	Profile.tutorial["mode"] = m
	if not Profile.tutorial.has("steps"):
		Profile.tutorial["steps"] = []
	if not Profile.tutorial.has("seen"):
		Profile.tutorial["seen"] = []
	Profile.save_profile()


static func steps_done() -> Array:
	return Profile.tutorial.get("steps", [])


static func done_all() -> bool:
	return steps_done().size() >= STEPS.size()


static func current_step() -> Dictionary:
	for s in STEPS:
		if not s.id in steps_done():
			return s
	return {}


static func progress_text() -> String:
	return "Premiers pas %d / %d" % [steps_done().size(), STEPS.size()]


## Contenu d'une petite carte d'information (`InfoCard`) pour une fiche : titre, une ou deux phrases, icône.
static func card_spec(card_id: String) -> Dictionary:
	var c: Dictionary = CARDS.get(card_id, {})
	return {"id": card_id, "title": String(c.get("title", "")), "body": String(c.get("short", " ".join(PackedStringArray(c.get("lines", []))))),
		"icon": String(c.get("icon", "info"))}


## Fiches triées de la plus récente à la plus ancienne (à version égale : l'ordre d'écriture de `CARDS`).
static func news_sorted(ids: Array) -> Array:
	var order := CARDS.keys()
	var out := ids.duplicate()
	out.sort_custom(func(a, b):
		var va := _vkey(String(CARDS[a].version))
		var vb := _vkey(String(CARDS[b].version))
		return va > vb if va != vb else order.find(a) < order.find(b))
	return out


## Chapitre du Guide où se trouve une fiche ("" si l'identifiant n'est pas une fiche).
static func chapter_of(card_id: String) -> String:
	return String(CARDS.get(card_id, {}).get("chapter", ""))


## Texte d'une étape avec les touches réelles du joueur.
static func step_text(s: Dictionary) -> String:
	var t := String(s.text)
	for a in ["move_forward", "move_left", "move_back", "move_right", "jump", "dodge", "skill_1", "interact"]:
		var key := Settings.action_label(a, 1)
		t = t.replace("{%s}" % a, key if a.begins_with("move_") else "[%s]" % key)
	return t


## Sauvegarde sans choix de tutoriel : une partie déjà jouée coupe les explications et ne voit que
## les nouveautés ; une nouvelle partie garde "" (l'accueil s'ouvre).
static func init_for_save() -> void:
	if not Profile.tutorial.is_empty():
		return
	var played := Profile.runs_done > 0 or not Profile.reward_chests.is_empty() or Profile.best_level > 1 		or Tower.duelists_beaten() > 0 or int(Profile.records.get("duel_wins", 0)) > 0
	if played:
		Profile.tutorial = {"mode": "skip", "steps": [], "seen": [], "version": "0.1.131"}
		Profile.save_profile()


# --- événements --------------------------------------------------------------------------
static var _counts := {}


## Un événement de jeu (saut, esquive, sort…) : valide l'étape en cours et ouvre la fiche liée.
## Renvoie l'étape qui vient d'être validée ({} sinon).
static func event(name: String) -> Dictionary:
	if mode() == "":
		return {}
	if name == "kill":
		event("weapon")  # l'arme du hub est déjà portée : la 1re victime valide l'étape
	var finished := {}
	if mode() == "guided" and Run.active and Modes.current() == "survival":
		for s in STEPS:
			if s.id in steps_done() or String(s.event) != name:
				continue
			_counts[s.id] = int(_counts.get(s.id, 0)) + 1
			if int(_counts[s.id]) >= int(s.n):
				Profile.tutorial["steps"] = steps_done() + [s.id]
				finished = s
	for id in CARDS:
		if String(CARDS[id].on) == name and card_pending(id):
			pending_card = id
	return finished


## Carte choisie : valide les étapes « carte » et ouvre la fiche liée au type de carte.
static func on_card(card: Dictionary) -> void:
	match String(card.get("type", "")):
		"gear":
			if String(card.get("item", {}).get("slot", "")) == "weapon":
				event("weapon")
		"weapon_up":
			event("card")
			event("weapon_up")
		"trophy":
			event("card")
			event("trophy")
		"offhand":
			event("offhand")
		"skill", "chain", "upgrade", "passive":
			event("card")


## Fiche à afficher (posée par un événement, prise par l'interface au prochain moment calme).
static var pending_card := ""


static func card_pending(id: String) -> bool:
	return mode() != "" and not bool(Profile.tutorial.get("cards_off", false)) and not id in Profile.tutorial.get("seen", [])


## L'interface prend la fiche en attente (une seule fois) ; "" s'il n'y en a pas.
static func take_card() -> String:
	var id := pending_card
	pending_card = ""
	if id != "" and card_pending(id):
		mark_seen(id)
		return id
	return ""


static func mark_seen(id: String) -> void:
	var seen: Array = Profile.tutorial.get("seen", [])
	if not id in seen:
		seen.append(id)
	Profile.tutorial["seen"] = seen
	Profile.save_profile()


static func skip_steps() -> void:
	var all: Array = []
	for s in STEPS:
		all.append(s.id)
	Profile.tutorial["steps"] = all
	Profile.save_profile()


# --- nouveautés --------------------------------------------------------------------------
## Fiches ajoutées depuis la version [param since] ("" : toutes).
static func news_since(since: String) -> Array:
	var out: Array = []
	for id in CARDS:
		if not bool(CARDS[id].get("news", true)):
			continue  # fiche qui ne s'annonce pas (Survivant : vue dans le choix de cartes)
		if since == "" or _vkey(String(CARDS[id].version)) > _vkey(since):
			out.append(id)
	return out


static func _vkey(v: String) -> int:
	var p := v.split(".")
	return int(p[0]) * 1000000 + int(p[1]) * 1000 + int(p[2]) if p.size() >= 3 else 0


## Nouveautés à annoncer au lobby : seulement pour une sauvegarde déjà jouée dont la dernière
## version vue est plus ancienne que la fiche (une seule fenêtre groupée). Marque la version vue.
static func news_to_show() -> Array:
	var last := String(Profile.tutorial.get("version", ""))
	var out: Array = []
	if mode() != "" and last != "" and last != Version.NUMBER:
		out = news_since(last).filter(func(id): return _vkey(String(CARDS[id].version)) <= _vkey(Version.NUMBER))
	Profile.tutorial["version"] = Version.NUMBER
	return out
