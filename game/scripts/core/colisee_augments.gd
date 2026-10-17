class_name ColiseeAugments
extends RefCounted
## Le Colisée, lot CO-E (conception/benchmark/R_CO_E.md ; ARENA.md § 6.6) : les 32 ATOUTS — données, offres notées, choix
## de l'IA, effets sur le héros et sur son trio, recette de fusion (Braise + Givre + Foudre = Tempête), plafonds.
##
## Données (LIST) : id, name, rarity (argent, or, eclat : les trois raretés de l'Échiquier), theme (un thème par offre),
## tags (melee, ranged, healer, tank, sorts, equipe), ico (pictogramme Ico, sinon icon : chemin d'une icône de statut),
## text (UNE phrase sans chiffre : la carte), tip (le détail chiffré : l'infobulle), roles (note 0-1 par rôle de combat :
## tank, melee, ranged, healer), params (valeurs de départ de l'étude, mesurées au banc : R_CO_E.md), needs (mécanique
## d'un lot à venir : jamais proposé avant), recipe (pièce de recette), goes (« Va bien avec : … »).
##
## Offres (offer) : manches OFFER_ROUNDS du format ; les 3 cartes ont la MÊME rareté (on choisit un style, pas une puissance) ;
## tirées parmi les mieux notées pour la classe (score : rôle, synergie du trio et de la recette, état de la partie), sans
## doublon de thème, avec du hasard ; 3 relances pour la partie, une relance change UNE carte (reroll) ; 6 atouts au plus.
## Choix de l'IA (choose_augment) : Facile au hasard, Normal note de rôle, Difficile note + synergie (un peu de bruit),
## Hardcore note + synergie sans bruit ; c'est aussi le choix au temps écoulé du joueur. Le chef d'équipe du lot CO-D peut le
## remplacer (ColiseeAnvil.coach) et réutiliser score().
##
## Effets (couche de combat) : posés à l'apparition de chaque héros (apply_hero : le joueur par sa fiche, Player.recalc_stats
## -> sheet ; un héros scripté directement) et lus par les crochets de Combatant (pre_hit, absorb, post_hit, dealt_mult,
## status_time) tant que [member active] est vrai (une partie du Colisée en cours) ; tick() chaque image de combat
## (directeur). Plafonds contre l'explosion de puissance : bonus de dégâts continus × DEALT_CAP au plus, dégâts reçus ×
## TAKEN_FLOOR au moins, PV et vitesses bornés, et les plafonds du profil « colisee » (coup 15 %, 35 % sur 2 s) s'appliquent
## après. Aucun effet hors du Colisée : les crochets ne font rien quand [member active] est faux.

const RARITY_ORDER := ["argent", "or", "eclat"]
const RARITIES := {
	"argent": {"name": "Argent", "ico": "rar_1", "color": Color("c9d3e6")},
	"or": {"name": "Or", "ico": "rar_3", "color": Color("ffc928")},
	"eclat": {"name": "Éclat", "ico": "rar_5", "color": Color("b43beb")},
}
const ROLES := ["tank", "melee", "ranged", "healer"]
const ROLE_NAMES := {"tank": "Rempart", "melee": "Mêlée", "ranged": "Distance", "healer": "Soin"}
## Atouts tenus au plus (4 choix + recette + décret « Même atout pour tous »).
const MAX_HELD := 6
const REROLLS := 3
## Manches d'offre par format.
const OFFER_ROUNDS := {"classique": [1, 4, 7, 10], "eclair": [1, 3, 5, 7], "grand": [1, 4, 7, 10]}
## Plafonds : bonus de dégâts continus (stat, Pacte, Trio, Roi, Marque) ; dégâts reçus ; PV et vitesse en plus.
const DEALT_CAP := 1.6
const TAKEN_FLOOR := 0.75
const HP_CAP := 0.7
const MOVE_CAP := 0.25
## Recette : les trois pièces fusionnent en RECIPE_RESULT (libère deux places).
const RECIPE := ["braise", "givre", "foudre"]
const RECIPE_RESULT := "tempete"
## Sous cette note de rôle, un atout n'est jamais proposé à ce rôle (offre incohérente).
const INCOHERENT := 0.3
## Mécaniques des lots à venir (needs) : relève (lot CO-J).
const READY_NEEDS := []

const LIST := [
	# --- Argent ----------------------------------------------------------------------------------------------------------
	{"id": "lame_affutee", "name": "Lame affûtée", "rarity": "argent", "theme": "coups", "tags": ["melee", "ranged"], "ico": "swords",
		"text": "Tes auto-attaques frappent plus fort.", "tip": "+20 % de dégâts d'auto-attaque.",
		"roles": [0.6, 1.0, 0.9, 0.3], "params": {"basic_pct": 0.2}},
	{"id": "peau_de_chene", "name": "Peau de chêne", "rarity": "argent", "theme": "survie", "tags": ["tank"], "ico": "heart",
		"text": "Tu as plus de PV.", "tip": "+15 % de PV max.", "roles": [1.0, 0.7, 0.6, 0.8], "params": {"hp_pct": 0.15}},
	{"id": "pas_leger", "name": "Pas léger", "rarity": "argent", "theme": "mobilite", "tags": ["melee", "ranged"], "ico": "st_swift",
		"text": "Tu cours plus vite.", "tip": "+12 % de vitesse de course.", "roles": [0.4, 0.8, 0.8, 0.6], "params": {"move_pct": 0.12}},
	{"id": "concentration", "name": "Concentration", "rarity": "argent", "theme": "sorts", "tags": ["sorts", "healer"], "ico": "hourglass",
		"text": "Tes sorts reviennent plus vite.", "tip": "−12 % de recharge des sorts (30 % au plus avec les enclumes).",
		"roles": [0.6, 0.7, 0.9, 1.0], "params": {"cdr": 0.12}},
	{"id": "premiere_frappe", "name": "Première frappe", "rarity": "argent", "theme": "coups", "tags": ["melee"], "ico": "spark",
		"text": "Ton premier coup de la manche fait très mal.", "tip": "1er coup de chaque combat : +80 % (plafond du coup : 15 % des PV).",
		"roles": [0.4, 1.0, 0.8, 0.3], "params": {"first_mult": 1.8}},
	{"id": "sangsue", "name": "Sangsue", "rarity": "argent", "theme": "survie", "tags": ["melee"], "icon": "res://assets/ui/status/regen.png",
		"text": "Tes coups te soignent un peu.", "tip": "Vol de vie : 6 % des dégâts infligés.", "roles": [0.7, 1.0, 0.6, 0.3],
		"params": {"leech": 0.06}},
	{"id": "bouclier_entree", "name": "Bouclier d'entrée", "rarity": "argent", "theme": "survie", "tags": ["tank"], "icon": "res://assets/ui/status/barrier.png",
		"text": "Tu commences chaque combat protégé.", "tip": "Bouclier de 15 % des PV max pendant 6 s au début du combat.",
		"roles": [0.9, 0.7, 0.7, 0.8], "params": {"shield_pct": 0.15, "shield_time": 6.0}},
	{"id": "esquive_agile", "name": "Esquive agile", "rarity": "argent", "theme": "mobilite", "tags": ["ranged"], "icon": "res://assets/ui/status/evasion.png",
		"text": "Ton esquive revient plus vite.", "tip": "Recharge de l'esquive −25 %.", "roles": [0.4, 0.8, 0.9, 0.7],
		"params": {"dodge_cd": 0.25}},
	{"id": "tirelire", "name": "Tirelire", "rarity": "argent", "theme": "or", "tags": [], "ico": "coin",
		"text": "Plus d'or à chaque manche.", "tip": "+4 or par manche.", "roles": [0.7, 0.7, 0.7, 0.7], "params": {"gold": 4}},
	{"id": "main_verte", "name": "Main verte", "rarity": "argent", "theme": "arene", "tags": [], "ico": "plus",
		"text": "Les fleurs de vie te donnent plus.", "tip": "Fleurs de vie : soin et protection doublés pour toi.",
		"roles": [0.6, 0.6, 0.6, 0.7], "params": {"flower_mult": 2.0}},
	# --- Or --------------------------------------------------------------------------------------------------------------
	{"id": "echo", "name": "Écho", "rarity": "or", "theme": "sorts", "tags": ["sorts"], "ico": "refresh",
		"text": "Ton sort le plus long part deux fois.", "tip": "Sorts de 10 s de recharge ou plus : un 2e coup 0,6 s après, à 50 %.",
		"roles": [0.5, 0.7, 1.0, 0.8], "params": {"echo_mult": 0.5, "echo_delay": 0.6, "min_cd": 10.0, "window": 1.2}},
	{"id": "serment", "name": "Serment", "rarity": "or", "theme": "equipe", "tags": ["equipe"], "ico": "st_angel",
		"text": "Quand un allié tombe, tu es protégé.", "tip": "Un allié à terre : bouclier de 25 % de tes PV max pendant 5 s.",
		"roles": [0.6, 0.7, 0.9, 1.0], "params": {"shield_pct": 0.25, "shield_time": 5.0}},
	{"id": "garde_rapprochee", "name": "Garde rapprochée", "rarity": "or", "theme": "equipe", "tags": ["equipe", "tank"], "ico": "boss_barrier",
		"text": "Tes alliés proches prennent moins de coups.", "tip": "Alliés à 6 m de toi : −10 % de dégâts reçus (une seule garde).",
		"roles": [1.0, 0.7, 0.5, 0.8], "params": {"radius": 6.0, "taken": 0.9}},
	{"id": "releve_eclair", "name": "Relève éclair", "rarity": "or", "theme": "equipe", "tags": ["equipe", "healer"], "ico": "st_vitality",
		"text": "Tu relèves un allié bien plus vite.", "tip": "Relève en 1,2 s au lieu de 3 s, l'allié revient à 50 % des PV.",
		"roles": [0.7, 0.6, 0.7, 1.0], "params": {"revive_time": 1.2, "revive_hp": 0.5}, "needs": "releve"},
	{"id": "chasseur_de_tetes", "name": "Chasseur de têtes", "rarity": "or", "theme": "coups", "tags": ["melee", "ranged"], "ico": "skull",
		"text": "Mettre un héros K.O. recharge tes sorts.", "tip": "K.O. ou aide (3 s) : −50 % de la recharge restante de tes sorts.",
		"roles": [0.4, 1.0, 0.9, 0.4], "params": {"cd_cut": 0.5, "assist": 3.0}},
	{"id": "coup_de_grace", "name": "Coup de grâce", "rarity": "or", "theme": "coups", "tags": ["melee", "ranged"], "ico": "cross",
		"text": "Tes coups achèvent les héros presque à terre.", "tip": "Cible sous 10 % de ses PV après ton coup : K.O. (pas sous un bouclier).",
		"roles": [0.4, 1.0, 0.9, 0.3], "params": {"threshold": 0.1}},
	{"id": "contre_coup", "name": "Contre-coup", "rarity": "or", "theme": "mobilite", "tags": ["melee"], "ico": "swap",
		"text": "Esquiver près d'un ennemi lance une riposte.", "tip": "Esquive à 5 m d'un adversaire : frappe de 60 % d'une auto-attaque (toutes les 2 s au plus).",
		"roles": [0.6, 1.0, 0.6, 0.4], "params": {"riposte": 0.6, "range": 5.0, "cd": 2.0}},
	{"id": "ronces", "name": "Ronces", "rarity": "or", "theme": "survie", "tags": ["tank"], "ico": "st_thorns",
		"text": "Qui te frappe au corps à corps se blesse.", "tip": "Renvoie 15 % des dégâts reçus de près (3,5 m).",
		"roles": [1.0, 0.7, 0.2, 0.4], "params": {"reflect": 0.15, "melee_range": 3.5}},
	{"id": "marque_du_chasseur", "name": "Marque du chasseur", "rarity": "or", "theme": "equipe", "tags": ["equipe", "ranged"], "ico": "goal",
		"text": "Ta cible prend plus de coups de tes alliés.", "tip": "Ta dernière cible : +12 % de dégâts reçus de ton trio pendant 4 s.",
		"roles": [0.8, 0.8, 0.9, 0.9], "params": {"bonus": 0.12, "time": 4.0}},
	{"id": "ancre", "name": "Ancre", "rarity": "or", "theme": "survie", "tags": ["tank", "melee"], "ico": "st_resolve",
		"text": "Plus personne ne te pousse ni ne t'attire.", "tip": "Insensible aux repoussements et attractions ; contrôles subis deux fois plus courts.",
		"roles": [1.0, 0.8, 0.4, 0.5], "params": {"cc_mult": 0.5}},
	{"id": "braise", "name": "Braise", "rarity": "or", "theme": "recette", "tags": ["melee", "ranged"], "icon": "res://assets/ui/status/burn.png",
		"text": "Tes coups brûlent.", "tip": "Brûlure de 3 s (une fois par seconde et par cible) ; 1/3 de « Tempête ».",
		"roles": [0.6, 0.9, 0.9, 0.5], "params": {"burn_time": 3.0, "cd": 1.0}, "recipe": true, "goes": ["givre", "foudre"]},
	{"id": "givre", "name": "Givre", "rarity": "or", "theme": "recette", "tags": ["melee", "ranged"], "icon": "res://assets/ui/status/chill.png",
		"text": "Tes coups ralentissent.", "tip": "Ralenti 1,5 s (toutes les 3 s par cible) ; 1/3 de « Tempête ».",
		"roles": [0.8, 0.8, 0.9, 0.6], "params": {"chill_time": 1.5, "cd": 3.0}, "recipe": true, "goes": ["braise", "foudre"]},
	{"id": "foudre", "name": "Foudre", "rarity": "or", "theme": "recette", "tags": ["melee", "ranged"], "icon": "res://assets/ui/status/shock.png",
		"text": "Tes coups sautent sur un voisin.", "tip": "Rebond de 40 % du coup sur un adversaire à 4 m ; 1/3 de « Tempête ».",
		"roles": [0.5, 0.9, 1.0, 0.5], "params": {"bounce": 0.4, "range": 4.0}, "recipe": true, "goes": ["braise", "givre"]},
	{"id": "mise", "name": "Mise", "rarity": "or", "theme": "or", "tags": [], "ico": "scales",
		"text": "Gagne la manche : beaucoup d'or. Perds-la : rien.", "tip": "Victoire : +15 or de plus ; défaite : aucun or de manche.",
		"roles": [0.6, 0.6, 0.6, 0.6], "params": {"win_gold": 15}},
	# --- Éclat -----------------------------------------------------------------------------------------------------------
	{"id": "tempete", "name": "Tempête", "rarity": "eclat", "theme": "recette", "tags": ["melee", "ranged"], "ico": "boss_vortex",
		"text": "Braise, Givre et Foudre fusionnent.", "tip": "Remplace les trois ; leurs effets × 1,5 ; libère deux places.",
		"roles": [0.8, 1.0, 1.0, 0.7], "params": {"mult": 1.5}, "recipe_result": true},
	{"id": "deuxieme_souffle", "name": "Deuxième souffle", "rarity": "eclat", "theme": "survie", "tags": ["tank", "healer"], "ico": "st_survival",
		"text": "Une fois par manche, tu survis à un coup mortel.", "tip": "Reste à 1 PV, intouchable 1 s, une fois par combat.",
		"roles": [0.9, 0.9, 0.8, 1.0], "params": {"invuln": 1.0}},
	{"id": "colosse", "name": "Colosse", "rarity": "eclat", "theme": "survie", "tags": ["tank", "melee"], "ico": "st_titan",
		"text": "Tu deviens immense et très solide, mais plus lent.", "tip": "+40 % de PV max, taille × 1,3, −10 % de vitesse.",
		"roles": [1.0, 0.9, 0.5, 0.6], "params": {"hp_pct": 0.4, "scale": 1.3, "move_pct": -0.1}},
	{"id": "maitre_des_sorts", "name": "Maître des sorts", "rarity": "eclat", "theme": "sorts", "tags": ["sorts", "healer"], "ico": "mana",
		"text": "Une place de sort de plus.", "tip": "Un sort de plus, au choix parmi trois sorts de ta classe.",
		"roles": [0.6, 0.7, 1.0, 1.0], "params": {"spells": 1}},
	{"id": "ombre_jumelle", "name": "Ombre jumelle", "rarity": "eclat", "theme": "coups", "tags": ["melee", "ranged"], "ico": "follow",
		"text": "Un double de toi se bat au début du combat.", "tip": "Un double à 40 % de tes PV et de tes dégâts pendant 10 s.",
		"roles": [0.7, 0.9, 0.9, 0.6], "params": {"power": 0.4, "time": 10.0}},
	{"id": "trio_parfait", "name": "Trio parfait", "rarity": "eclat", "theme": "equipe", "tags": ["equipe"], "ico": "crown",
		"text": "Trois familles différentes : tout le trio s'en trouve plus fort.", "tip": "Trio de trois familles : +10 % de dégâts et de PV pour les trois (un seul compte).",
		"roles": [0.8, 0.8, 0.8, 0.8], "params": {"dmg_pct": 0.1, "hp_pct": 0.1}},
	{"id": "roi_de_l_arene", "name": "Roi de l'arène", "rarity": "eclat", "theme": "arene", "tags": ["tank", "melee"], "ico": "act_arena",
		"text": "Tenir le centre te rend plus fort peu à peu.", "tip": "À 5 m du centre : +3 % de dégâts par seconde, 30 % au plus ; ça retombe dehors.",
		"roles": [1.0, 0.9, 0.4, 0.5], "params": {"radius": 5.0, "per_s": 0.03, "max": 0.3}},
	{"id": "pacte_de_sang", "name": "Pacte de sang", "rarity": "eclat", "theme": "risque", "tags": ["melee", "ranged"], "ico": "st_bleed",
		"text": "Ton équipe perd des PV, tu frappes beaucoup plus fort.", "tip": "−15 PV d'équipe tout de suite ; +25 % de dégâts ; impossible sous 30 PV d'équipe.",
		"roles": [0.5, 1.0, 0.9, 0.4], "params": {"team_hp": 15, "dmg_pct": 0.25, "min_hp": 30}},
]

static var _by_id: Dictionary = {}


# --- données ---------------------------------------------------------------------------------------------------------------

static func def(id: String) -> Dictionary:
	if _by_id.is_empty():
		for a in LIST:
			_by_id[String(a.id)] = a
	return _by_id.get(id, {})


static func ids() -> Array:
	return LIST.map(func(a): return String(a.id))


static func p(id: String, key: String, fallback := 0.0) -> float:
	return float(def(id).get("params", {}).get(key, fallback))


## Proposable : pas la recette fusionnée, pas une mécanique d'un lot à venir.
static func offerable(id: String) -> bool:
	var d := def(id)
	if d.is_empty() or bool(d.get("recipe_result", false)):
		return false
	var need := String(d.get("needs", ""))
	return need == "" or need in READY_NEEDS


static func of_rarity(r: String) -> Array:
	return LIST.filter(func(a): return String(a.rarity) == r).map(func(a): return String(a.id))


## Données d'affichage d'une carte (lot CO-G) : {id, name, rarity, rarity_name, color, ico, icon, text, tip, theme, goes}.
static func card(id: String) -> Dictionary:
	var d := def(id)
	if d.is_empty():
		return {}
	var r: Dictionary = RARITIES.get(String(d.rarity), RARITIES.argent)
	var goes: Array = (d.get("goes", []) as Array).map(func(g): return String(def(String(g)).get("name", g)))
	return {"id": id, "name": String(d.name), "rarity": String(d.rarity), "rarity_name": String(r.name), "color": r.color,
		"ico": String(d.get("ico", "")), "icon": String(d.get("icon", "")), "text": String(d.text), "tip": String(d.tip),
		"theme": String(d.theme), "goes": goes}


## Icône de la carte : le pictogramme Ico s'il existe, sinon l'icône de statut.
static func texture(id: String, px := 64) -> Texture2D:
	var d := def(id)
	if String(d.get("ico", "")) != "":
		var t := Ico.tex(String(d.ico), px)
		if t != null:
			return t
	var path := String(d.get("icon", ""))
	return load(path) if path != "" and ResourceLoader.exists(path) else Ico.tex("star", px)


# --- offres ------------------------------------------------------------------------------------------------------------------

## Rareté de l'offre de la manche [param r] (Classique : 1 Argent ou Or 1 fois sur 3, 4 Or, 7 Or ou Éclat 2 fois sur 5,
## 10 Éclat) ; "" : pas d'offre.
static func offer_rarity(format: String, r: int, rng: RandomNumberGenerator) -> String:
	var rounds: Array = OFFER_ROUNDS.get(format, OFFER_ROUNDS.classique)
	var k := rounds.find(r)
	match k:
		0:
			return "or" if rng.randf() < 1.0 / 3.0 else "argent"
		1:
			return "or"
		2:
			return "eclat" if rng.randf() < 0.4 else "or"
		3:
			return "eclat"
	return ""


## Contexte de notation d'un héros : {round, team_hp, wins, losses, mates (constructions du trio), format}.
static func context_for(g: Object, b: ColiseeBuild) -> Dictionary:
	var ctx := {"round": 1, "team_hp": Colisee.TEAM_HP, "wins": 0, "rounds": 0, "mates": [], "format": "classique"}
	if g == null:
		return ctx
	ctx.round = int(g.get("round_n"))
	ctx.format = String(g.get("format"))
	var hp: Array = g.get("hp")
	if b.team < hp.size():
		ctx.team_hp = int(hp[b.team])
	var w: Array = g.get("round_wins")
	if b.team < w.size():
		ctx.wins = int(w[b.team])
	ctx.rounds = maxi(0, int(g.get("round_n")) - 1)
	ctx.mates = ColiseeBuild.team_of(g, b.team)
	return ctx


## L'atout [param id] peut-il être pris par [param b] (pas tenu, place libre, conditions) ?
static func eligible(id: String, b: ColiseeBuild, ctx := {}) -> bool:
	if not offerable(id) or b.has(id):
		return false
	if b.augments.size() >= MAX_HELD:
		return false
	if id in RECIPE and b.has(RECIPE_RESULT):
		return false
	if id == "pacte_de_sang" and int(ctx.get("team_hp", 100)) < int(p(id, "min_hp", 30)):
		return false
	if id == "trio_parfait":
		var fams := {}
		for m in ctx.get("mates", []):
			fams[(m as ColiseeBuild).family] = true
		if fams.size() < 3 and not (ctx.get("mates", []) as Array).is_empty():
			return false
		for m in ctx.get("mates", []):
			if (m as ColiseeBuild).has("trio_parfait"):
				return false  # (un seul compte pour le trio)
	if id == "maitre_des_sorts" and ColiseeAnvil.spell_pool(b).is_empty():
		return false
	return true


## Note de rôle seule (0-1) de l'atout [param id] pour le rôle [param role].
static func role_note(id: String, role: String) -> float:
	var roles: Array = def(id).get("roles", [0.5, 0.5, 0.5, 0.5])
	return float(roles[maxi(0, ROLES.find(role))])


## Note de l'atout [param id] pour [param b] : rôle (0-1) + synergie + état de la partie ; [param with_synergy] faux : la note
## de rôle seule (IA Normal). Interface du chef d'équipe (lot CO-D).
static func score(id: String, b: ColiseeBuild, ctx := {}, with_synergy := true) -> float:
	var d := def(id)
	if d.is_empty():
		return 0.0
	var roles: Array = d.get("roles", [0.5, 0.5, 0.5, 0.5])
	var s := float(roles[maxi(0, ROLES.find(b.role))])
	if "sorts" in (d.get("tags", []) as Array) and ColiseeBuild.spell_class(b.cid):
		s += 0.15
	if not with_synergy:
		return s
	var rnd := int(ctx.get("round", 1))
	var hp := float(ctx.get("team_hp", 100))
	# recette : chaque pièce tenue rend les autres plus précieuses
	if bool(d.get("recipe", false)):
		var held := 0
		for r in RECIPE:
			if b.has(r):
				held += 1
		s += 0.35 * held
	match id:
		"tirelire", "mise":
			s *= clampf(1.35 - 0.12 * float(rnd - 1), 0.3, 1.35)  # l'or sert tôt
			if id == "mise":
				var played := maxi(1, int(ctx.get("rounds", 0)))
				s *= 0.7 + 0.6 * float(ctx.get("wins", 0)) / played if int(ctx.get("rounds", 0)) > 0 else 0.9
		"peau_de_chene", "bouclier_entree", "deuxieme_souffle", "colosse", "serment":
			s *= 1.0 + 0.5 * (1.0 - hp / 100.0)  # trio en danger : survivre
		"pacte_de_sang":
			s *= clampf((hp - 20.0) / 60.0, 0.0, 1.2)
		"garde_rapprochee", "serment", "marque_du_chasseur":
			var near := 0
			for m in ctx.get("mates", []):
				if m != b and (m as ColiseeBuild).role in ["melee", "tank"]:
					near += 1
			s += 0.08 * near
		"main_verte":
			s *= 1.0 + 0.3 * (1.0 - hp / 100.0)
	return s


## Offre de 3 atouts de rareté [param rarity] pour [param b] : les mieux notés pour lui (TOP_K), sans doublon de thème,
## tirés au poids de la note ; [param exclude] : ids à écarter (relance).
static func make_offer(b: ColiseeBuild, rarity: String, ctx: Dictionary, rng: RandomNumberGenerator, n := 3, exclude: Array = []) -> Array:
	var cands: Array = []
	for id in of_rarity(rarity):
		if id in exclude or not eligible(id, b, ctx) or role_note(id, b.role) < INCOHERENT:
			continue  # (jamais une carte faite pour un autre rôle : des Ronces à un tireur)
		cands.append([score(id, b, ctx), id])
	cands.sort()
	cands.reverse()
	cands = cands.slice(0, maxi(n + 3, int(ceil(cands.size() * 0.75))))  # les mieux notés (TOP), puis le hasard
	var out: Array = []
	var themes := {}
	for pass_n in 2:
		var pool := cands.filter(func(e): return not (String(e[1]) in out) and (pass_n == 1 or not themes.has(String(def(String(e[1])).theme))))
		while out.size() < n and not pool.is_empty():
			var total := 0.0
			for e in pool:
				total += maxf(0.05, float(e[0])) ** 2
			var roll := rng.randf() * total
			var pick: Array = pool[pool.size() - 1]
			for e in pool:
				roll -= maxf(0.05, float(e[0])) ** 2
				if roll <= 0.0:
					pick = e
					break
			out.append(String(pick[1]))
			themes[String(def(String(pick[1])).theme)] = true
			pool = pool.filter(func(e): return not (String(e[1]) in out) and (pass_n == 1 or not themes.has(String(def(String(e[1])).theme))))
	return out


## Relance : la carte [param index] de l'offre de [param b] est remplacée (même rareté, autre thème si possible).
## Faux : plus de relance, ou rien d'autre à proposer.
static func reroll(b: ColiseeBuild, index: int, ctx: Dictionary, rng: RandomNumberGenerator) -> bool:
	if b.rerolls <= 0 or index < 0 or index >= b.offer.size():
		return false
	var keep: Array = b.offer.duplicate()
	keep.remove_at(index)
	var seen: Array = b.offer.duplicate()
	var alt := make_offer(b, b.offer_rarity, ctx, rng, 3, seen)
	alt = alt.filter(func(id): return not String(def(id).theme) in keep.map(func(k): return String(def(k).theme))) + alt
	if alt.is_empty():
		return false
	b.offer[index] = alt[0]
	b.rerolls -= 1
	return true


## Offres en dictionnaires pour le chef d'équipe (ColiseeCoach.choose_augment) : {id, score (note de ce fichier), tags
## (étiquettes + thème), rarity, name}.
static func offer_dicts(offers: Array, b: ColiseeBuild, ctx := {}) -> Array:
	var out: Array = []
	for id in offers:
		var d := def(String(id))
		out.append({"id": String(id), "score": score(String(id), b, ctx), "tags": (d.get("tags", []) as Array) + [String(d.get("theme", ""))],
			"rarity": String(d.get("rarity", "")), "name": String(d.get("name", id))})
	return out


## Choix de l'IA parmi [param offers] (ids) : indice. Facile : au hasard ; Normal : note de rôle (bruit 0,25) ; Difficile :
## note + synergie (bruit 0,1) ; Hardcore et choix automatique du joueur : note + synergie, sans bruit.
static func choose_augment(offers: Array, b: ColiseeBuild, ctx := {}, rng: RandomNumberGenerator = null) -> int:
	if offers.is_empty():
		return -1
	var r := rng if rng != null else RandomNumberGenerator.new()
	if b.diff <= 0:
		return r.randi_range(0, offers.size() - 1)
	var best := 0
	var best_s := -INF
	for i in offers.size():
		var s := score(String(offers[i]), b, ctx, b.diff >= 2)
		if b.diff == 1:
			s += r.randf_range(-0.25, 0.25)
		elif b.diff == 2:
			s += r.randf_range(-0.1, 0.1)
		if s > best_s:
			best_s = s
			best = i
	return best


## Prend l'atout [param id] : recette fusionnée si les trois pièces sont là, Pacte de sang (PV d'équipe), Maître des sorts
## (une offre de sort). Rend l'id vraiment ajouté (« tempete » si fusion), "" si refusé.
static func take(b: ColiseeBuild, id: String, g: Object = null) -> String:
	if def(id).is_empty() or b.has(id) or b.augments.size() >= MAX_HELD:
		return ""
	b.augments.append(id)
	b.augment_log.append({"round": int(g.get("round_n")) if g != null else 0, "id": id, "offer": b.offer.duplicate()})
	b.offer = []
	b.offer_rarity = ""
	var got := id
	if id in RECIPE and RECIPE.all(func(r): return b.has(r)):
		for r in RECIPE:
			b.augments.erase(r)
		b.augments.append(RECIPE_RESULT)
		got = RECIPE_RESULT
	if id == "pacte_de_sang" and g != null:
		var hp: Array = g.get("hp")
		hp[b.team] = int(hp[b.team]) - int(p(id, "team_hp", 15))
	if id == "maitre_des_sorts":
		b.spell_slots += int(p(id, "spells", 1))
		ColiseeAnvil.open_spells(b)
	return got


# --- effets : ce que tient un héros --------------------------------------------------------------------------------------------

## Effets actifs d'un héros de [param b] dans le trio [param mates] : id -> params (× 1,5 pour Braise, Givre et Foudre sous
## Tempête ; Trio parfait d'un équipier).
static func effects_for(b: ColiseeBuild, mates: Array = []) -> Dictionary:
	var fx := {}
	if b == null:
		return fx
	for id in b.augments:
		fx[id] = (def(id).get("params", {}) as Dictionary).duplicate()
	if fx.has(RECIPE_RESULT):
		var m := p(RECIPE_RESULT, "mult", 1.5)
		for r in RECIPE:
			var q: Dictionary = (def(r).get("params", {}) as Dictionary).duplicate()
			for k in ["burn_time", "chill_time", "bounce"]:
				if q.has(k):
					q[k] = float(q[k]) * m
			fx[r] = q
	for m in mates:
		if m != b and (m as ColiseeBuild).has("trio_parfait"):
			fx["trio_parfait"] = (def("trio_parfait").params as Dictionary).duplicate()
	return fx


## Somme des bonus de fiche (atouts + enclumes de stat) : hp_pct, move_pct, cdr, basic_pct, crit, atk_speed, def_pct, dmg_pct.
static func sheet_bonus(b: ColiseeBuild, fx: Dictionary) -> Dictionary:
	var o := {"hp_pct": 0.0, "move_pct": 0.0, "cdr": 0.0, "basic_pct": 0.0, "crit": 0.0, "atk_speed": 0.0, "def_pct": 0.0, "dmg_pct": 0.0}
	if b != null:
		for k in b.stats:
			if o.has(k):
				o[k] = float(o[k]) + float(b.stats[k])
	for id in fx:
		var q: Dictionary = fx[id]
		match String(id):
			"peau_de_chene", "colosse", "trio_parfait":
				o.hp_pct += float(q.get("hp_pct", 0.0))
		match String(id):
			"pas_leger", "colosse":
				o.move_pct += float(q.get("move_pct", 0.0))
			"concentration":
				o.cdr += float(q.get("cdr", 0.0))
			"lame_affutee":
				o.basic_pct += float(q.get("basic_pct", 0.0))
			"trio_parfait", "pacte_de_sang":
				o.dmg_pct += float(q.get("dmg_pct", 0.0))
	o.hp_pct = minf(o.hp_pct, HP_CAP)
	o.move_pct = clampf(o.move_pct, -0.2, MOVE_CAP)
	o.cdr = minf(o.cdr, float(ModeRules.rule("caps", PvpCaps.CAPS).get("cdr", 0.3)))
	return o


# --- couche de combat ----------------------------------------------------------------------------------------------------------

## Une partie du Colisée est en cours : les crochets de Combatant lisent les états (sinon ils ne font rien).
static var active := false
## Combat de manche en cours (tick, procs).
static var fighting := false
## Dégâts vrais en cours (Ronces, Foudre, Écho, Coup de grâce) : valeur imposée par absorb ; -1 : aucun.
static var _forced := -1.0
static var _exec := false
static var _depth := 0
## États par héros (id d'instance -> état) ; voir _state_for.
static var _st: Dictionary = {}
static var _pending: Array = []  ## échos à venir : [instant, cible, dégâts, source]
static var _centers: Dictionary = {}  ## arène -> centre
static var doubles: Array = []  ## ombres jumelles : [héros, fin]
static var director: Node = null
## Journal des effets déclenchés (tests, banc) : id -> nombre.
static var counts: Dictionary = {}


static func start() -> void:
	active = true
	fighting = false
	_st = {}
	_pending = []
	doubles = []
	counts = {}


static func stop() -> void:
	_clear_doubles()
	active = false
	fighting = false
	_st = {}
	_pending = []
	_centers = {}
	director = null
	_forced = -1.0
	_exec = false


static func _now() -> float:
	return PvpCaps.elapsed


static func _note(id: String) -> void:
	counts[id] = int(counts.get(id, 0)) + 1


static func state(c: Object) -> Dictionary:
	if c == null or not is_instance_valid(c):
		return {}
	return _st.get(c.get_instance_id(), {})


## Pose la construction [param b] (trio [param mates]) sur le héros [param c] qui vient d'apparaître : héros scripté, ses
## stats tout de suite ; joueur, par sa fiche (recalc_stats -> sheet). Appelé par le directeur à chaque manche.
static func apply_hero(c: Combatant, b: ColiseeBuild, mates: Array = []) -> void:
	if c == null or b == null:
		return
	active = true
	var fx := effects_for(b, mates)
	var st := {"c": c, "b": b, "fx": fx, "team": b.team, "first": false, "souffle": false, "saved_at": -99.0, "shields": [],
		"invuln": -1.0, "mark_team": -1, "mark_until": -1.0, "hits_by": {}, "king": 0.0, "echo_until": -1.0, "echoed": {},
		"cds": {}, "dodge_mark": 0.0, "dodge_ready": 0.0, "riposte_at": -99.0, "burn_at": {}, "chill_at": {}, "slowed": false,
		"combo": -1, "double": false}
	_st[c.get_instance_id()] = st
	var bonus := sheet_bonus(b, fx)
	st["bonus"] = bonus
	if c is Player:
		(c as Player).recalc_stats()
		(c as Player).hp = (c as Player).max_hp
	elif c is ClassRival:
		_sheet_rival(c as ClassRival, bonus, fx)
	_scale_model(c, fx)
	_snapshot_cds(st)


static func _sheet_rival(r: ClassRival, bonus: Dictionary, fx: Dictionary) -> void:
	r.max_hp *= 1.0 + float(bonus.hp_pct)
	r.hp = r.max_hp
	r.move_speed *= 1.0 + float(bonus.move_pct)
	if r.travel_speed > 0.0:
		r.travel_speed *= 1.0 + float(bonus.move_pct)
	var cfg: Dictionary = r.cfg.duplicate()
	cfg["skill_cd"] = float(cfg.skill_cd) * (1.0 - float(bonus.cdr))
	if fx.has("esquive_agile"):
		cfg["recharge"] = float(cfg.recharge) * (1.0 - float(fx.esquive_agile.get("dodge_cd", 0.25)))
	if float(bonus.atk_speed) > 0.0:
		cfg["pause"] = float(cfg.pause) / (1.0 + float(bonus.atk_speed))
		cfg["pause_end"] = float(cfg.pause_end) / (1.0 + float(bonus.atk_speed))
	r.cfg = cfg
	var caps: Dictionary = ModeRules.rule("caps", PvpCaps.CAPS)
	r.crit_chance = minf(r.crit_chance + float(bonus.crit), float(caps.get("crit", 0.5)))
	r.defense *= 1.0 + float(bonus.def_pct)
	r.health_changed.emit(r.hp, r.max_hp)


## Fiche du joueur (crochet de Player.recalc_stats, après les plafonds du mode) : mêmes bonus qu'un héros scripté.
static func sheet(pl: Player) -> void:
	var st := state(pl)
	if st.is_empty():
		return
	var bonus: Dictionary = st.bonus
	var caps: Dictionary = ModeRules.rule("caps", PvpCaps.CAPS)
	pl.max_hp *= 1.0 + float(bonus.hp_pct)
	pl.move_mult *= 1.0 + float(bonus.move_pct)
	pl.cdr = minf(pl.cdr + float(bonus.cdr), float(caps.get("cdr", 0.3)))
	pl.basic_mult *= 1.0 + float(bonus.basic_pct)
	pl.crit = minf(pl.crit + float(bonus.crit), float(caps.get("crit", 0.5)))
	pl.mcrit = minf(pl.mcrit + float(bonus.crit), float(caps.get("mcrit", caps.get("crit", 0.5))))
	pl.atk_speed = minf(pl.atk_speed * (1.0 + float(bonus.atk_speed)), float(caps.get("atk_speed", 2.0)))
	pl.defense *= 1.0 + float(bonus.def_pct)
	if bool(st.get("slowed", false)):
		pl.move_mult *= 0.55  # (Givre : le joueur est ralenti comme un héros scripté)


static func _scale_model(c: Combatant, fx: Dictionary) -> void:
	if c.model == null:
		return
	if not c.has_meta("co_scale"):
		c.set_meta("co_scale", c.model.scale)
	var base: Vector3 = c.get_meta("co_scale")
	c.model.scale = base * (float(fx.colosse.get("scale", 1.3)) if fx.has("colosse") else 1.0)


## Début des combats de la manche ([param fights] du directeur : {index, arena, heroes}) : drapeaux remis, Bouclier d'entrée,
## Ombre jumelle, Main verte (fleurs).
static func begin_fight(dir: Node, fights: Array) -> void:
	active = true
	fighting = true
	director = dir
	_pending = []
	_clear_doubles()
	_centers = {}
	for f in fights:
		var arena = f.get("arena")
		if arena != null and is_instance_valid(arena):
			_centers[int(f.index)] = (arena as Node3D).global_position
			for fl in arena.get("flowers"):
				if not (fl as ColiseeFlower).picked.is_connected(_on_flower):
					(fl as ColiseeFlower).picked.connect(_on_flower)
	var now := _now()
	for k in _st.keys():
		var st: Dictionary = _st[k]
		var c = st.c
		if not is_instance_valid(c):
			_st.erase(k)
			continue
		st.first = false
		st.souffle = false
		st.saved_at = -99.0
		st.shields = []
		st.invuln = -1.0
		st.mark_until = -1.0
		st.hits_by = {}
		st.king = 0.0
		st.echo_until = -1.0
		st.echoed = {}
		st.riposte_at = -99.0
		_snapshot_cds(st)
		var fx: Dictionary = st.fx
		if fx.has("bouclier_entree"):
			_shield(st, (c as Combatant).max_hp * float(fx.bouclier_entree.get("shield_pct", 0.15)), now + float(fx.bouclier_entree.get("shield_time", 6.0)))
			_note("bouclier_entree")
		if fx.has("ombre_jumelle") and dir != null:
			_spawn_double(dir, c as Combatant, st)


## Fin des combats de la manche : ombres retirées, échos oubliés.
static func end_fight() -> void:
	fighting = false
	_pending = []
	_clear_doubles()


## Nouvelle manche : les héros scriptés de la manche passée sont libérés ; on oublie leurs états.
static func reset_round() -> void:
	_clear_doubles()
	for k in _st.keys():
		var c = _st[k].c
		if not is_instance_valid(c) or not (c is Player):
			_st.erase(k)


static func _shield(st: Dictionary, amount: float, until: float) -> void:
	(st.shields as Array).append([amount, until])


static func shield_left(c: Combatant) -> float:
	var st := state(c)
	if st.is_empty():
		return 0.0
	var s := 0.0
	for e in st.shields:
		if float(e[1]) > _now():
			s += float(e[0])
	return s


# --- crochets de Combatant -----------------------------------------------------------------------------------------------------

## Avant le coup (Combatant.take_damage) : bonus de dégâts de la source (stat, Pacte, Trio, Roi de l'arène, Marque, Première
## frappe) et protection de la cible (Garde rapprochée). Plafonnés (DEALT_CAP, TAKEN_FLOOR).
static func pre_hit(dst: Combatant, src: Combatant, amount: float, dot: bool) -> float:
	if _forced >= 0.0:
		return amount
	var now := _now()
	var ss := state(src) if src != dst else {}
	var sd := state(dst)
	var m := 1.0
	if not ss.is_empty():
		var bonus: Dictionary = ss.bonus
		var add := float(bonus.dmg_pct) + float(ss.king)
		if not sd.is_empty() and int(sd.mark_team) == int(ss.team) and float(sd.mark_until) > now:
			add += float(_mark_bonus(int(ss.team)))
		m *= minf(1.0 + add, DEALT_CAP)
		if not dot and ss.fx.has("premiere_frappe") and not bool(ss.first):
			ss.first = true
			m *= float(ss.fx.premiere_frappe.get("first_mult", 1.8))
			_note("premiere_frappe")
	if not sd.is_empty() and fighting:
		var guard := 1.0
		for k in _st:
			var o: Dictionary = _st[k]
			var oc = o.c
			if oc == dst or int(o.team) != int(sd.team) or not o.fx.has("garde_rapprochee") or not is_instance_valid(oc) or (oc as Combatant).is_dead:
				continue
			if not Combatant.same_arena(oc, dst):
				continue
			var gp: Dictionary = o.fx.garde_rapprochee
			if (oc as Node3D).global_position.distance_to(dst.global_position) <= float(gp.get("radius", 6.0)):
				guard = minf(guard, float(gp.get("taken", 0.9)))
		if guard < 1.0:
			_note("garde_rapprochee")
		m *= maxf(guard, TAKEN_FLOOR)
	return amount * m


## Bonus de Marque du chasseur de l'équipe [param t] (le plus fort de ses porteurs).
static func _mark_bonus(t: int) -> float:
	var best := 0.0
	for k in _st:
		var o: Dictionary = _st[k]
		if int(o.team) == t and o.fx.has("marque_du_chasseur"):
			best = maxf(best, float(o.fx.marque_du_chasseur.get("bonus", 0.12)))
	return best


## Après défense et plafonds, avant les PV : dégâts vrais imposés, Coup de grâce, intouchable, boucliers, Deuxième souffle.
## 0 ou moins : le coup ne fait rien (Combatant.take_damage s'arrête).
static func absorb(dst: Combatant, _src: Combatant, dmg: float, _dot: bool) -> float:
	if _forced >= 0.0:
		dmg = _forced
		if _exec:
			return dst.hp + 1.0
	var st := state(dst)
	if st.is_empty():
		return dmg
	var now := _now()
	if float(st.invuln) > now:
		return 0.0
	var sh: Array = st.shields
	var i := 0
	while i < sh.size() and dmg > 0.0:
		if float(sh[i][1]) <= now:
			sh.remove_at(i)
			continue
		var take := minf(float(sh[i][0]), dmg)
		sh[i][0] = float(sh[i][0]) - take
		dmg -= take
		if float(sh[i][0]) <= 0.5:
			sh.remove_at(i)
		else:
			i += 1
	if dmg <= 0.0:
		return 0.0
	if dmg >= dst.hp and st.fx.has("deuxieme_souffle") and not bool(st.souffle):
		st.souffle = true
		st.saved_at = now
		st.invuln = now + float(st.fx.deuxieme_souffle.get("invuln", 1.0))
		_note("deuxieme_souffle")
		DamageNumber.spawn_text(dst, "DEUXIÈME SOUFFLE", Color(1.0, 0.95, 0.6))
		return maxf(0.0, dst.hp - 1.0)
	return dmg


## Multiplicateur des dégâts d'un héros scripté au moment où il lance son coup (Combatant.damage_dealt_mult) : Lame affûtée
## sur ses auto-attaques (son compteur de combo avance d'un coup d'arme, jamais d'un sort). Le joueur : par sa fiche.
static func dealt_mult(c: Combatant) -> float:
	if not c is ClassRival:
		return 1.0
	var st := state(c)
	if st.is_empty() or not st.fx.has("lame_affutee"):
		return 1.0
	var combo := int((c as ClassRival)._combo_i)
	var auto := combo != int(st.combo)
	st.combo = combo
	return 1.0 + float(st.fx.lame_affutee.get("basic_pct", 0.2)) if auto else 1.0


## Durée d'un statut posé sur [param c] (Combatant.add_status) : Ancre divise les contrôles par deux.
static func status_time(c: Combatant, status: String, duration: float, _src: Combatant) -> float:
	var st := state(c)
	if st.is_empty() or not st.fx.has("ancre"):
		return duration
	if status in Combatant.CC_TYPES or status == "chill":
		return duration * float(st.fx.ancre.get("cc_mult", 0.5))
	return duration


## Après le coup : vol de vie, Braise, Givre, Foudre, Marque, Écho, Coup de grâce (source) ; Ronces (cible) ; K.O. (Chasseur
## de têtes, Serment, or des K.O.).
static func post_hit(dst: Combatant, src: Combatant, dmg: float, dot: bool) -> void:
	var sd := state(dst)
	var now := _now()
	var src_ok := src != null and is_instance_valid(src) and src != dst
	if src_ok and not sd.is_empty():
		(sd.hits_by as Dictionary)[src.get_instance_id()] = now
	if dst.is_dead:
		_on_ko(dst, src if src_ok else null)
		return
	if _forced >= 0.0 or not fighting or _depth > 2:
		return
	var ss := state(src) if src_ok else {}
	if not ss.is_empty() and not dot:
		var fx: Dictionary = ss.fx
		var did := dst.get_instance_id()
		if fx.has("sangsue"):
			var k := PvpCaps.heal_mult() if PvpCaps.active() else 1.0
			src.heal(dmg * float(fx.sangsue.get("leech", 0.06)) / maxf(k, 0.05))
		if fx.has("braise") and float((ss.burn_at as Dictionary).get(did, -99.0)) <= now:
			(ss.burn_at as Dictionary)[did] = now + float(fx.braise.get("cd", 1.0))
			dst.add_status("burn", float(fx.braise.get("burn_time", 3.0)), src)
			_note("braise")
		if fx.has("givre") and float((ss.chill_at as Dictionary).get(did, -99.0)) <= now:
			(ss.chill_at as Dictionary)[did] = now + float(fx.givre.get("cd", 3.0))
			dst.add_status("chill", float(fx.givre.get("chill_time", 1.5)), src)
			_note("givre")
		if fx.has("foudre"):
			var nb := _neighbor(dst, float(fx.foudre.get("range", 4.0)))
			if nb != null:
				_note("foudre")
				deal_true(nb, dmg * float(fx.foudre.get("bounce", 0.4)), src)
		if fx.has("marque_du_chasseur"):
			sd.mark_team = int(ss.team)
			sd.mark_until = now + float(fx.marque_du_chasseur.get("time", 4.0))
		if float(ss.echo_until) > now and not (ss.echoed as Dictionary).has(did):
			(ss.echoed as Dictionary)[did] = true
			_pending.append([now + float(fx.echo.get("echo_delay", 0.6)), dst, dmg * float(fx.echo.get("echo_mult", 0.5)), src])
		if fx.has("coup_de_grace") and not dst.is_dead and dst.hp < dst.max_hp * float(fx.coup_de_grace.get("threshold", 0.1)) \
				and shield_left(dst) <= 0.0 and (sd.is_empty() or now - float(sd.saved_at) > 1.0):
			_note("coup_de_grace")
			deal_true(dst, dst.hp, src, true)
	if not sd.is_empty() and src_ok and not dot and sd.fx.has("ronces") and not dst.is_dead and not src.is_dead:
		var rp: Dictionary = sd.fx.ronces
		if src.global_position.distance_to(dst.global_position) <= float(rp.get("melee_range", 3.5)):
			_note("ronces")
			deal_true(src, dmg * float(rp.get("reflect", 0.15)), dst)


## Adversaire vivant le plus proche de [param c] (même équipe que lui, même arène), à [param r] m au plus.
static func _neighbor(c: Combatant, r: float) -> Combatant:
	if not c.is_inside_tree():
		return null
	var best: Combatant = null
	var best_d := r
	for n in c.get_tree().get_nodes_in_group("ffa"):
		var o := n as Combatant
		if o == null or o == c or o.is_dead or o.ffa_id != c.ffa_id or not Combatant.same_arena(o, c):
			continue
		var d := o.global_position.distance_to(c.global_position)
		if d <= best_d:
			best_d = d
			best = o
	return best


## Dégâts vrais (sans échelle ni défense ; boucliers compris) de [param src] sur [param dst] ; [param execute] : K.O. direct.
static func deal_true(dst: Combatant, amount: float, src: Combatant, execute := false) -> void:
	if dst == null or not is_instance_valid(dst) or dst.is_dead or amount <= 0.0 or _depth > 3:
		return
	var was := _forced
	var was_exec := _exec
	_forced = amount
	_exec = execute
	_depth += 1
	dst.take_damage(1.0, src if src != null and is_instance_valid(src) else null, false, true)
	_depth -= 1
	_forced = was
	_exec = was_exec


static func _on_ko(victim: Combatant, killer: Combatant) -> void:
	var sv := state(victim)
	if not sv.is_empty() and bool(sv.double):
		return
	var now := _now()
	var vt := int(sv.team) if not sv.is_empty() else TeamMatch.team_of(victim)
	var sk := state(killer)
	if not sk.is_empty() and int(sk.team) != vt:
		var kb: ColiseeBuild = sk.b
		if kb != null and not bool(sk.double):
			kb.round_kos += 1
			kb.kos += 1
	# Chasseur de têtes : le tueur et ceux qui l'ont aidé (coup dans les ASSIST s)
	if not sv.is_empty():
		for k in _st:
			var o: Dictionary = _st[k]
			if not o.fx.has("chasseur_de_tetes") or int(o.team) == vt or not is_instance_valid(o.c) or (o.c as Combatant).is_dead:
				continue
			var hit_at := float((sv.hits_by as Dictionary).get(k, -99.0))
			if o.c == killer or now - hit_at <= float(o.fx.chasseur_de_tetes.get("assist", 3.0)):
				_cut_cooldowns(o.c as Combatant, float(o.fx.chasseur_de_tetes.get("cd_cut", 0.5)))
				_note("chasseur_de_tetes")
	# Serment : les équipiers de la victime dans son arène
	for k in _st:
		var o: Dictionary = _st[k]
		if int(o.team) != vt or o.c == victim or not o.fx.has("serment") or not is_instance_valid(o.c) or (o.c as Combatant).is_dead:
			continue
		if not Combatant.same_arena(o.c, victim):
			continue
		var sp: Dictionary = o.fx.serment
		_shield(o, (o.c as Combatant).max_hp * float(sp.get("shield_pct", 0.25)), now + float(sp.get("shield_time", 5.0)))
		_note("serment")


static func _cut_cooldowns(c: Combatant, cut: float) -> void:
	if c is Player:
		var pl := c as Player
		for id in pl.skill_ready_at:
			pl.skill_ready_at[id] = pl._time + maxf(0.0, float(pl.skill_ready_at[id]) - pl._time) * (1.0 - cut)
	elif c is ClassRival:
		var r := c as ClassRival
		for id in r._skill_ready:
			r._skill_ready[id] = r._time + maxf(0.0, float(r._skill_ready[id]) - r._time) * (1.0 - cut)
		_snapshot_cds(state(c))


static func _on_flower(c: Combatant) -> void:
	var st := state(c)
	if st.is_empty() or not st.fx.has("main_verte") or c.is_dead:
		return
	var extra := float(st.fx.main_verte.get("flower_mult", 2.0)) - 1.0
	var k := PvpCaps.heal_mult() if PvpCaps.active() else 1.0
	c.heal(c.max_hp * ColiseeFlower.HEAL * extra / maxf(k, 0.05))
	c.add_status("barrier", ColiseeFlower.BARRIER * (1.0 + extra), c)
	_note("main_verte")


# --- image par image -------------------------------------------------------------------------------------------------------------

## Une image de combat (directeur) : Roi de l'arène, Écho (sorts longs lancés), Esquive agile et Contre-coup, Ancre, Givre
## sur le joueur, échos à venir, ombres jumelles.
static func tick(delta: float) -> void:
	if not fighting:
		return
	var now := _now()
	for k in _st.keys():
		var st: Dictionary = _st[k]
		var c = st.c
		if not is_instance_valid(c):
			_st.erase(k)
			continue
		var cc := c as Combatant
		if cc.is_dead:
			continue
		var fx: Dictionary = st.fx
		if fx.has("roi_de_l_arene") and _centers.has(cc.arena_id):
			var rp: Dictionary = fx.roi_de_l_arene
			var flat := cc.global_position - (_centers[cc.arena_id] as Vector3)
			flat.y = 0.0
			if flat.length() <= float(rp.get("radius", 5.0)):
				st.king = minf(float(st.king) + float(rp.get("per_s", 0.03)) * delta, float(rp.get("max", 0.3)))
			else:
				st.king = maxf(0.0, float(st.king) - 2.0 * float(rp.get("per_s", 0.03)) * delta)
		if fx.has("echo"):
			_watch_casts(st, cc)
		if c is Player:
			var pl := c as Player
			if fx.has("esquive_agile") and pl._dodge_ready_at > float(st.dodge_ready) + 0.01:
				pl._dodge_ready_at = pl._time + (pl._dodge_ready_at - pl._time) * (1.0 - float(fx.esquive_agile.get("dodge_cd", 0.25)))
			if fx.has("contre_coup") and pl._dodge_ready_at > float(st.dodge_ready) + 0.01:
				_riposte(st, cc)
			st.dodge_ready = pl._dodge_ready_at
			var slow := pl.has_status("chill")
			if slow != bool(st.slowed):
				st.slowed = slow
				pl.recalc_stats()
		elif c is ClassRival:
			var r := c as ClassRival
			if fx.has("contre_coup") and r._dodge_until > float(st.dodge_mark) + 0.01:
				_riposte(st, cc)
			st.dodge_mark = r._dodge_until
			if fx.has("ancre"):
				r._knock = Vector3.ZERO
	var i := 0
	while i < _pending.size():
		var e: Array = _pending[i]
		if float(e[0]) <= now:
			_pending.remove_at(i)
			_note("echo")
			deal_true(e[1] as Combatant if is_instance_valid(e[1]) else null, float(e[2]), e[3] as Combatant if is_instance_valid(e[3]) else null)
		else:
			i += 1
	i = 0
	while i < doubles.size():
		var d: Array = doubles[i]
		if not is_instance_valid(d[0]) or float(d[1]) <= now or (d[0] as Combatant).is_dead:
			_free_double(d[0])
			doubles.remove_at(i)
		else:
			i += 1


## Sorts lancés : la date de retour d'un sort de recharge longue avance -> fenêtre d'écho.
static func _watch_casts(st: Dictionary, c: Combatant) -> void:
	var cur := _cds_of(c)
	var last: Dictionary = st.cds
	var min_cd := float(st.fx.echo.get("min_cd", 10.0))
	for id in cur:
		if float(cur[id]) > float(last.get(id, -1.0)) + 1.0 and _base_cd(c, int(id)) >= min_cd:
			st.echo_until = _now() + float(st.fx.echo.get("window", 1.2))
			st.echoed = {}
	st.cds = cur


static func _cds_of(c: Combatant) -> Dictionary:
	if c is Player:
		return (c as Player).skill_ready_at.duplicate()
	if c is ClassRival:
		return (c as ClassRival)._skill_ready.duplicate()
	return {}


static func _snapshot_cds(st: Dictionary) -> void:
	if st.is_empty() or not is_instance_valid(st.c):
		return
	st.cds = _cds_of(st.c)
	if st.c is Player:
		st.dodge_ready = (st.c as Player)._dodge_ready_at
	elif st.c is ClassRival:
		st.dodge_mark = (st.c as ClassRival)._dodge_until


static func _base_cd(c: Combatant, id: int) -> float:
	var cls: Dictionary = c.get("cls") if c.get("cls") != null else {}
	for s in cls.get("skills", []):
		if int(s.id) == id:
			return float(s.get("cooldown", 0.0))
	return 0.0


static func _riposte(st: Dictionary, c: Combatant) -> void:
	var now := _now()
	var cp: Dictionary = st.fx.contre_coup
	if now - float(st.riposte_at) < float(cp.get("cd", 2.0)):
		return
	var best: Combatant = null
	var best_d := float(cp.get("range", 5.0))
	for o in Combatant.ffa_foes(c.get_tree(), c):
		var d := (o as Combatant).global_position.distance_to(c.global_position)
		if d <= best_d:
			best_d = d
			best = o
	if best == null:
		return
	st.riposte_at = now
	_note("contre_coup")
	best.take_damage(c.power() * float(cp.get("riposte", 0.6)) * PvpCaps.basic_mult(), c)


# --- Ombre jumelle -------------------------------------------------------------------------------------------------------------

static func _spawn_double(dir: Node, owner: Combatant, st: Dictionary) -> void:
	var b: ColiseeBuild = st.b
	if b == null or owner.is_dead:
		return
	var op: Dictionary = st.fx.ombre_jumelle
	var r := TeamMatch.make_hero(b.cid, Colisee.LEVEL, maxi(1, b.diff), b.team, owner.arena_id)
	r.display_name = "Ombre · " + owner.display_name
	dir.add_child(r)
	r.global_position = owner.global_position + owner.global_transform.basis.x * 1.6 + Vector3.UP * 0.4
	r.max_hp *= float(op.get("power", 0.4))
	r.hp = r.max_hp
	r.atk *= float(op.get("power", 0.4))
	r.visible = owner.visible
	if r.anim and owner.anim:
		r.anim.active = owner.anim.active
	r.passive = false
	_st[r.get_instance_id()] = {"c": r, "b": null, "fx": {}, "team": b.team, "first": true, "souffle": true, "saved_at": -99.0,
		"shields": [], "invuln": -1.0, "mark_team": -1, "mark_until": -1.0, "hits_by": {}, "king": 0.0, "echo_until": -1.0,
		"echoed": {}, "cds": {}, "dodge_mark": 0.0, "dodge_ready": 0.0, "riposte_at": -99.0, "burn_at": {}, "chill_at": {},
		"slowed": false, "combo": -1, "double": true, "bonus": sheet_bonus(null, {})}
	doubles.append([r, _now() + float(op.get("time", 10.0))])
	_note("ombre_jumelle")


static func _free_double(r) -> void:
	if not is_instance_valid(r):
		return
	_st.erase(r.get_instance_id())
	TeamMatch.remove(r)
	(r as Node).queue_free()


static func _clear_doubles() -> void:
	for d in doubles:
		_free_double(d[0])
	doubles = []
