class_name InfoPage
extends HBoxContainer
## Page Infos : comment chaque statistique est calculée, ce que rapporte un point de
## chaque attribut, la formule des dégâts et l'effet de la défense (héros et monstres).
## En run, montre aussi les valeurs du héros et ce que vaut un point de plus.
## Les formules reprennent Player.recalc_stats, Player._hit_monster et Combatant.take_damage.

const SECTIONS := ["Monnaies et coffres", "Attributs", "Statistiques du héros", "Calcul des dégâts", "Défense", "Survie", "Équipement", "Tes valeurs"]

var player: Player  # null hors run
var _nav: VBoxContainer
var _text: RichTextLabel
var _current := 0


func _ready() -> void:
	add_theme_constant_override("separation", 16)
	var left := ItemWidgets.panel(self, 260)
	ItemWidgets.section(left, "Sommaire")
	_nav = VBoxContainer.new()
	_nav.add_theme_constant_override("separation", 6)
	left.add_child(_nav)
	for i in SECTIONS.size():
		var b := Button.new()
		b.text = SECTIONS[i]
		b.toggle_mode = true
		b.focus_mode = Control.FOCUS_NONE
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size = Vector2(0, 40)
		b.add_theme_font_size_override("font_size", 16)
		b.pressed.connect(show_section.bind(i))
		_nav.add_child(b)
	var right := ItemWidgets.panel(self, 0, true)
	_text = ItemWidgets.rich(right, 16)
	_text.add_theme_constant_override("table_h_separation", 18)
	_text.add_theme_constant_override("table_v_separation", 4)


func refresh() -> void:
	if is_inside_tree():
		show_section(_current)


func show_section(i: int) -> void:
	_current = clampi(i, 0, SECTIONS.size() - 1)
	for k in _nav.get_child_count():
		(_nav.get_child(k) as Button).set_pressed_no_signal(k == _current)
	var txt := ""
	match _current:
		0: txt = _money()
		1: txt = _attributes()
		2: txt = _hero()
		3: txt = _damage()
		4: txt = _defense()
		5: txt = _survival()
		6: txt = _gear()
		7: txt = _live()
	_text.text = txt
	_text.scroll_to_line(0)


static func _h(t: String) -> String:
	return "[font_size=24][color=#f5c75a]%s[/color][/font_size]\n" % t


static func _sub(t: String) -> String:
	return "\n[font_size=18][color=#f5c75a]%s[/color][/font_size]\n" % t


static func _note(t: String) -> String:
	return "[color=#b8b4c8]%s[/color]\n" % t


static func _table(head: Array, rows: Array) -> String:
	var s := "[table=%d]" % head.size()
	for h in head:
		s += "[cell][b][color=#f5c75a]%s[/color][/b][/cell]" % h
	for r in rows:
		for c in r:
			s += "[cell]%s[/cell]" % c
	return s + "[/table]\n"


func _money() -> String:
	var t := _h("Une run : étapes, carte, monnaies")
	t += _note("Une run = 3 étapes : la zone choisie, puis des zones à ta hauteur. Sur chaque carte : casse tout, ouvre les coffres, forge ton équipement, réunis 3 sceaux puis affronte le boss du donjon (le pilier violet). Boss vaincu : un portail mène à l'étape suivante, tu gardes ton niveau, tes cartes, ton équipement, ton or et tes clés. Après 10 minutes sur une carte : la rage.")
	t += _table(["Monnaie", "Où l'obtenir", "À quoi elle sert", "En fin de run"], [
		["[b]Or[/b]", "Jarres, caisses, tas d'or, monstres, défis, vente aux marchands", "Coffres de la carte (le prix monte de 15 % à chaque coffre), marchands, amélioration +1 → +10", "[color=#ff9a7a]perdu[/color]"],
		["[b]Clés[/b]", "Élites (1 chacune), débris, sanctuaires des clés, marchands", "Ouvrir n'importe quel coffre de la carte sans payer", "[color=#ff9a7a]perdues[/color]"],
		["[b]Cristaux[/b]", "Démonter un objet", "Réforger une stat bonus, polir la qualité, fabrication", "[color=#7fe08a]gardés[/color]"],
		["[b]Fournitures[/b]", "Caisses (parchemins de fortification), cristaux et jarres (gemmes), coffres ouvragés et dorés et défis (pierres, parchemins bénis), autels du scribe (enchantements)", "Forge : améliorer, sertir des gemmes, enchanter, améliorer sans risque", "gardées si tu t'en sors"],
		["[b]Cartes[/b]", "Niveaux, sanctuaires, gardiens d'élite, marchands", "Ton build de la run", "la run seulement"],
		["[b]Coffres de récompense[/b]", "Boss d'étape (toujours), stèles du défi (toujours), élites (20 %)", "Menu Coffres : mythiques et légendaires, sets, forge, joaillier, trophées", "gardés si tu t'en sors"],
	])
	t += _sub("Sur la carte")
	t += _note("• Plus de 1 000 jarres, caisses et tonneaux : frappe-les ou fonce dedans (or, XP, parfois soins, fournitures, clés) ; tas d'or ramassés en passant ; cristaux : 3 coups, des gemmes.\n• 30 coffres : or ou une clé, une pièce d'équipement au choix parmi 3 — coffre (jusqu'à épique), coffre ouvragé (jusqu'à mythique), coffre doré (jusqu'à légendaire, pilier doré).\n• Lieux à usage unique (piliers de lumière) : enclume (+1 garanti sur une pièce portée), autel du scribe (parchemin d'enchantement au choix), fontaine de vie, pierre d'aimant (toute l'XP et le butin), autel de cupidité (+50 % d'or et de butin, monstres +25 %), stèle du défi (3 élites : coffre de récompense).\n• 10 sanctuaires : reste dans le cercle (14 s) pendant que les monstres affluent ; cartes, trophées ou clés.\n• 3 marchands ambulants : cartes, clé, fournitures, équipement ; ils rachètent ton butin.\n• Ruines, tours de guet, mines, campements et plateaux : remplis d'objets à casser.\n• Forge (Échap > Héros, fiche d'un objet) : améliorer (or et parchemin), réforger et polir (cristaux), percer, sertir, enchanter.")
	return t


func _attributes() -> String:
	var t := _h("Les 5 attributs")
	t += _note("Total d'un attribut = (base de la classe + croissance × (niveau − 1) + équipement + archive) × (1 + bonus en % des cartes et talents + buffs). Les buffs Puissance, Célérité et Grâce ajoutent +30 %.")
	t += _sub("Ce que rapporte 1 point")
	t += _table(["Attribut", "Effets d'un point", "Pour 100 points"], [
		["[b]Force[/b]", "+0,6 attaque physique · +2 PV max · +0,25 défense · +0,04 % parade", "+60 att. phys., +200 PV, +25 déf., +4 % parade"],
		["[b]Agilité[/b]", "+0,15 % vitesse d'attaque · +0,04 % critique physique · +0,1 % vitesse d'incantation · +0,06 % esquive", "+15 % vit. d'attaque, +4 % crit., +10 % incantation, +6 % esquive"],
		["[b]Intelligence[/b]", "+0,6 attaque magique", "+60 att. magique"],
		["[b]Sagesse[/b]", "+1,5 PV max · +0,4 % puissance de soin · +0,04 % critique magique · +0,05 % vitesse d'incantation", "+150 PV, +40 % soins, +4 % crit. mag., +5 % incantation"],
		["[b]Chance[/b]", "+0,12 % critique (physique et magique) · +0,15 % dégâts critiques", "+12 % crit., +15 % dégâts critiques"],
	])
	t += _sub("Comment choisir")
	t += _note("• Armes physiques (katana, hache, dague, arc) : la Force augmente l'attaque, l'Agilité la cadence.\n• Armes et sorts magiques (sceptre, bâton) : l'Intelligence augmente l'attaque magique, la Sagesse les soins et la survie.\n• La Chance sert à tous : critique et dégâts critiques. Un point de Chance vaut à peu près 3 points d'Agilité pour le critique.\n• L'attaque compte de moins en moins quand elle est déjà haute : +60 d'attaque, c'est +60 % de dégâts à 100 d'attaque mais +20 % à 300.")
	return t


func _hero() -> String:
	var t := _h("Statistiques du héros")
	t += _note("« Niveau » : niveau du héros pendant la run. « Classe » : coefficients propres à chaque classe (data/classes.json).")
	t += _table(["Statistique", "Formule"], [
		["PV max", "(PV du niveau × coef. classe + 2 × For + 1,5 × Sag) × (1 + PV % cartes, équipement et buffs) + PV de l'équipement"],
		["Attaque physique", "(45 × 1,1^(niveau − 1) × coef. classe + att. physique de l'équipement + 0,6 × For) × (1 + attaque % des cartes)"],
		["Attaque magique", "(45 × 1,1^(niveau − 1) × coef. magique de la classe + att. magique de l'équipement + 0,6 × Int) × (1 + attaque % + attaque magique %)"],
		["Défense", "(4 + 2 × niveau + défense de l'équipement et de la classe + 0,25 × For) × (1 + défense %)"],
		["Critique physique", "5 % + classe + équipement + cartes + 0,12 % × Chance + 0,04 % × Agi"],
		["Critique magique", "5 % + équipement + cartes + 0,12 % × Chance + 0,04 % × Sag"],
		["Dégâts critiques", "+50 % + équipement + cartes + 0,15 % × Chance"],
		["Vitesse d'attaque", "100 % + classe + 0,15 % × Agi + équipement + cartes (+30 % Frénésie, +30 % Marduk)"],
		["Vitesse d'incantation", "100 % + 0,1 % × Agi + 0,05 % × Sag + cartes"],
		["Puissance de soin", "100 % + 0,4 % × Sag + cartes (+15 % Survie)"],
		["Esquive", "0,06 % × Agi + équipement + cartes — 20 % au maximum"],
		["Parade", "0,04 % × For + cartes — 20 % au maximum"],
		["Recharge", "équipement + cartes — 50 % au maximum"],
		["Vitesse de déplacement", "100 % + classe + équipement + cartes (+30 % Sanctuaire, +30 % Hâte)"],
		["Zone, portée", "100 % + cartes + équipement (taille des sorts et allonge des coups)"],
	])
	t += _note("Les talents d'expertise, certificats de maîtrise et cartes de la run ajoutent leurs bonus en % dans ces formules.")
	return t


func _damage() -> String:
	var t := _h("Calcul des dégâts")
	t += _sub("1. Le coup du héros")
	t += "[b]Dégâts = Attaque × Puissance de l'action × aléa (92 à 108 %) × Critique × Statuts × Flow × (1 + Dégâts %) × Élites[/b]\n"
	t += _table(["Facteur", "Détail"], [
		["Attaque", "physique ou magique selon l'arme (auto-attaque) ou le sort"],
		["Puissance de l'action", "auto-attaque de l'arme (% de son arme, cartes « Main lourde »), arme secondaire 60 %, sort (% indiqué dans le grimoire), ×2 sur un combo réussi (ex. cible gelée)"],
		["Critique", "× (1 + dégâts critiques) si le coup est critique (chance = critique physique ou magique)"],
		["Statuts du héros", "Fureur ×1,25 · Cicatrice ×0,7 · Marduk : attaque ×1,3"],
		["Flow", "+10 % par annulation parfaite enchaînée (jusqu'à +40 %, 3 s)"],
		["Dégâts %", "cartes, sets et objets (« Dégâts »)"],
		["Élites", "contre les élites et les boss : × (1 + dégâts contre élites et boss)"],
	])
	t += _sub("2. Ce que la cible reçoit")
	t += "[b]Dégâts reçus = max(1, arrondi(Dégâts × Modificateurs de la cible × 100 / (100 + Défense de la cible)))[/b]\n"
	t += _table(["Modificateur de la cible", "Effet"], [
		["Débuffs (Purgatoire, Grues, Choc)", "×1,2 · ×1,15 · ×1,15 dégâts subis"],
		["Buffs (Solaire, Sanctuaire, Barrière, Titan)", "×0,75 · ×0,7 · ×0,6 · ×0,5 dégâts subis"],
	])
	t += _sub("3. Cas particuliers")
	t += _note("• Effets sur la durée (brûlure, poison, saignement) : un tick par seconde, ils ignorent la défense ; leur force suit l'attaque et les « dégâts sur la durée ».\n• Exécution (cartes) : si le coup laisse la cible sous X % de ses PV (30 % max), elle est achevée — ignore la défense.\n• Effets déclenchés (foudre, gel, explosion…) des sets et cartes : ils partent de ton attaque et passent par la défense comme un coup normal.\n• Vol de vie : tu récupères ce % des dégâts infligés (avant la défense de la cible).")
	return t


func _defense() -> String:
	var t := _h("Défense")
	t += _note("La défense réduit chaque coup en pourcentage : dégâts × 100 / (100 + défense). Elle vaut pour le héros comme pour les monstres. Chaque point compte un peu moins que le précédent, mais les PV effectifs, eux, montent toujours de 1 % par point : PV effectifs = PV × (1 + défense / 100).")
	var rows: Array = []
	for d: int in [0, 25, 50, 100, 150, 200, 300, 400]:
		var k := 100.0 / (100.0 + d)
		rows.append([str(d), "%d %%" % roundi(k * 100), "−%d %%" % roundi((1.0 - k) * 100), "×%.2f" % (1.0 + d / 100.0)])
	t += _table(["Défense", "Dégâts reçus", "Réduction", "PV effectifs"], rows)
	t += _sub("Défense des monstres")
	t += _note("Chaque monstre garde la défense de sa fiche d'Eden, ×1,1 par niveau quand il est ramené au niveau de la zone. Les élites et les boss ont la même défense que leur espèce mais bien plus de PV (élite ×1,6, boss ×14 par rapport à la fiche).")
	var defs: Array = []
	for id in GameData.monsters:
		defs.append(float(GameData.monsters[id].get("def", 0)))
	if not defs.is_empty():
		defs.sort()
		var med: float = defs[defs.size() / 2]
		t += _note("Dans les fiches actuelles : défense de %d à %d (médiane %d). À %d de défense, un monstre encaisse %d %% de tes coups." % [
			roundi(defs[0]), roundi(defs[-1]), roundi(med), roundi(med), roundi(100.0 * 100.0 / (100.0 + med))])
	t += _note("Les dégâts sur la durée ignorent la défense : c'est la meilleure réponse aux monstres très protégés.")
	return t


func _survival() -> String:
	var t := _h("Survie")
	t += _table(["Mécanisme", "Effet"], [
		["Esquive", "le coup est entièrement évité (« ESQUIVE ! ») — Agilité, équipement, cartes, 20 % max"],
		["Parade", "le coup est divisé par 2 (« PARADE ») — Force et cartes, 20 % max"],
		["Roulade", "invulnérable pendant l'esquive (touche d'esquive, avec un temps de recharge)"],
		["Défense", "réduit tous les coups (voir Défense)"],
		["Soins", "× puissance de soin (Sagesse)"],
		["Vol de vie", "rend un % des dégâts infligés"],
		["Effets sur la durée", "ignorent l'esquive, la parade et la défense"],
	])
	t += _note("Ordre : esquive, puis parade, puis défense et modificateurs.")
	return t


func _gear() -> String:
	var t := _h("Équipement")
	t += _table(["Élément", "Effet"], [
		["Niveau de l'objet", "stats de base et affixes plats × 1,08^(niveau − 1) ; les stats en % ne dépendent pas du niveau"],
		["Qualité", "jet de 90 à 120 % sur les stats de base (polissage chez le forgeron)"],
		["Amélioration +1 à +10", "+10 % des stats de base par niveau ; aux paliers +4, +6, +8 et +10 un affixe est ajouté ou renforcé"],
		["Rareté", "nombre d'affixes : Commun 0 · Magique 1 · Rare (or) 2 · Épique (violet) 3 · Légendaire (orange) 4"],
		["Sets (cadre vert)", "bonus à 2, 4 et 6 pièces portées, dont des effets déclenchés"],
		["Gemmes, enchantement", "stats ajoutées par le joaillier et les parchemins"],
		["Archive", "chaque entrée remplie : +1 / +2 / +4 points d'attribut (rare / épique / légendaire), +1 % de dégâts par set ; paliers de collection"],
	])
	t += _sub("Fourchettes des affixes (niveau 1)")
	var rows: Array = []
	for s in Items.AFFIX_RANGES:
		var r: Array = Items.AFFIX_RANGES[s]
		var pct: bool = s in Items.PERCENT_STATS
		rows.append([Items.STAT_NAMES.get(s, s), ("%d à %d %%" % [roundi(r[0] * 100), roundi(r[1] * 100)]) if pct else ("%d à %d" % [roundi(r[0]), roundi(r[1])])])
	t += _table(["Affixe", "Jet"], rows)
	return t


func _live() -> String:
	var t := _h("Tes valeurs")
	if player == null or not is_instance_valid(player):
		return t + _note("Pendant une run (menu pause), cette section montre les statistiques de ton héros et ce que vaut un point de chaque attribut pour lui.")
	var p := player
	var rows: Array = []
	for r in p.stat_sheet():
		rows.append(["[color=#f5c75a]%s[/color]" % r[0] if String(r[1]) == "" else String(r[0]), "[b]%s[/b]" % r[1]])
	t += _table(["Statistique", "Valeur"], rows)
	t += _sub("Ce que vaut +10 points maintenant")
	var red := 100.0 / (100.0 + p.defense)
	t += _table(["+10 de…", "Gain"], [
		["Force", "+%.1f %% de dégâts physiques · +%d PV · défense %d → %d" % [600.0 / maxf(p.atk, 1.0), 20, roundi(p.defense), roundi(p.defense + 2.5)]],
		["Agilité", "+1,5 % vitesse d'attaque · +0,4 % critique · +0,6 % esquive"],
		["Intelligence", "+%.1f %% de dégâts magiques" % (600.0 / maxf(p.matk, 1.0))],
		["Sagesse", "+15 PV · +4 % soins · +0,4 % critique magique"],
		["Chance", "+1,2 % critique · +1,5 % dégâts critiques"],
	])
	t += _note("Tu reçois actuellement %d %% des dégâts des coups (défense %d), soit %d PV effectifs." % [roundi(red * 100), roundi(p.defense), roundi(p.max_hp / red)])
	return t
