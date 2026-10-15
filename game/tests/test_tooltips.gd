extends Node
## Infobulles d'objets (0.1.172, lot U6) : la carte courte et la carte complète se construisent sans erreur pour un
## échantillon de pièces de toutes les raretés et de tous les emplacements, sans mention du jeu d'origine, sans doublon
## de statistique, avec la statistique principale en gros, la comparaison avec la pièce portée et Maj pour les détails :
## godot --headless --path game res://tests/test_tooltips.tscn

var fails := 0


func check(label: String, ok: bool) -> void:
	print(("OK    " if ok else "ÉCHEC ") + label)
	if not ok:
		fails += 1


## Texte brut d'un BBCode (balises retirées).
func _plain(bb: String) -> String:
	var rx := RegEx.new()
	rx.compile("\\[[^\\]]*\\]")
	return rx.sub(bb, "", true)


func _count_lines_starting(plain: String, prefix: String) -> int:
	var n := 0
	for l in plain.split("\n"):
		if l.strip_edges().begins_with(prefix):
			n += 1
	return n


func _sample() -> Array:
	var out: Array = []
	for r in Items.RARITIES.size():
		for slot in Items.SLOTS:
			var it := Items.generate(30, 0.0, slot, "warrior", r, "", 5)
			out.append(it)
	return out


func _ready() -> void:
	Settings.reset_all()
	Profile.selected_class = "warrior"
	Profile.reset_all()
	var sample := _sample()
	check("échantillon : %d pièces, toutes les raretés" % sample.size(), sample.size() == Items.RARITIES.size() * Items.SLOTS.size() and sample.map(func(i): return int(i.rarity)).has(5) and sample.map(func(i): return int(i.rarity)).has(0))
	var bad_eden := 0
	var bad_dup := 0
	var bad_main := 0
	var longer := 0
	for it in sample:
		for detailed in [false, true]:
			var txt := Items.describe(it, detailed)
			var pl := _plain(txt)
			if pl.contains("Eden") or pl.contains("Dans "):
				bad_eden += 1
			if _count_lines_starting(pl, "Défense") > 1 or _count_lines_starting(pl, "Attaque magique") > 1 or _count_lines_starting(pl, "Force") > 1:
				bad_dup += 1
			if not txt.contains("[font_size=30]") and Items.main_stat_key(it, Items.stats(it, false)) != "":
				bad_main += 1
		if Items.describe(it, true).length() >= Items.describe(it, false).length():
			longer += 1
		check("%s %s : la carte courte tient en 18 lignes au plus" % [Items.RARITIES[int(it.rarity)].name, it.slot], Items.describe(it, false).split("\n").size() <= 18)
	check("aucune mention d'Eden sur les cartes", bad_eden == 0)
	check("aucune statistique en double (Défense, Attaque magique, Force)", bad_dup == 0)
	check("la statistique principale est en gros", bad_main == 0)
	check("la carte complète est au moins aussi longue que la courte", longer == sample.size())
	# --- contenu : PE, rareté, passif, gemmes, enchantement, panoplie x / N, archétype -------------------------
	var leg := Items.generate(40, 0.0, "chest", "warrior", 5, "", 5)
	leg["sockets"] = [{"type": "garnet", "tier": 3}, null]
	leg["enchant"] = {"type": "rehab", "lv": 3}
	leg["archetype"] = "storm"
	leg["upgrade"] = 4
	leg["passive"] = {"name": "Test", "desc": "+3 % de dégâts", "stat": {"dmg_pct": 0.03}, "procs": []}
	var txt := _plain(Items.describe(leg, false))
	check("rareté en toutes lettres", txt.contains("Légendaire"))
	check("niveau de puissance de la pièce (PE)", txt.contains("PE "))
	check("+N dans le nom", txt.contains("+4 "))
	check("passif", txt.contains("Passif — Test : +3 % de dégâts"))
	check("gemme sertie et emplacement vide", txt.contains("Grenat") and txt.contains("Emplacement de gemme vide"))
	check("enchantement", txt.contains("Rééducation niv. 3"))
	check("panoplie de donjon avec sa progression x / 6", txt.contains("Panoplie de donjon · Tempête") and txt.contains("0 / 6"))
	check("carte courte : seulement le prochain palier", txt.contains("2 pièces") and not txt.contains("6 pièces"))
	check("carte complète : tous les paliers", _plain(Items.describe(leg, true)).contains("6 pièces"))
	check("carte courte : pas de « Prochaine amélioration »", not txt.contains("Prochaine amélioration"))
	check("carte complète : prochaine amélioration (hors run)", _plain(Items.describe(leg, true)).contains("Prochaine amélioration"))
	if leg.has("set"):
		check("pièce de set : panoplie nommée avec x / N", txt.contains("Panoplie ") and txt.contains(" / "))
	# la pièce de set d'Eden : x / N d'après les paliers du set
	var seen := false
	for it in sample:
		if it.has("set"):
			var t := _plain(Items.describe(it, false))
			check("pièce de set %s : ligne « Panoplie … x / N »" % it.name, t.contains("Panoplie ") and t.contains(" / "))
			seen = true
			break
	check("l'échantillon contient une pièce de set", seen)
	# --- doublon « Défense » : plat + pourcentage fusionnés ---------------------------------------------
	var dd := Items.generate(30, 0.0, "chest", "warrior", 3, "", 5)
	dd["base"] = {"def": 40.0, "def_pct": 0.04, "hp": 100.0, "str": 5.0}
	dd["quality"] = 1.0  # la qualité tirée change le pourcentage affiché (+3 % ou +4 % selon le tirage)
	dd["upgrade"] = 0
	var rows := Items.stat_rows(dd)
	check("Défense plate et en % : une seule ligne", rows.filter(func(r): return r.name == "Défense").size() == 1)
	check("la ligne fusionnée porte le pourcentage", String(rows.filter(func(r): return r.name == "Défense")[0].pct) == "+4 %")
	check("armure : la défense est la statistique principale", Items.main_stat_key(dd, Items.stats(dd, false)) == "def")
	var wp := Items.generate(30, 0.0, "weapon", "magician", 3, "", 5)
	check("arme : l'attaque est la statistique principale", Items.main_stat_key(wp, Items.stats(wp, false)) in ["patk", "matk"])
	# --- comparaison avec la pièce portée ----------------------------------------------------------------
	var worn := Items.generate(10, 0.0, "chest", "warrior", 1, "", 5)
	Profile.equipped["chest"] = worn
	var better := Items.generate(60, 0.0, "chest", "warrior", 5, "", 5)
	var cmp := _plain(ItemWidgets.compare_text(better, worn, true))
	check("comparaison : nom de la pièce portée, verdict, PE", cmp.contains("Porté :") and cmp.contains("PE ") and (cmp.contains("Meilleur") or cmp.contains("Équivalent") or cmp.contains("Moins bien")))
	check("comparaison : flèches ▲ / ▼", cmp.contains("▲") or cmp.contains("▼"))
	var cmp_raw := ItemWidgets.compare_text(better, worn, true)
	check("comparaison : gains en vert, pertes en rouge", (not cmp_raw.contains("▲")) or cmp_raw.contains("#7fe08a]▲"))
	check("comparaison : courte = 5 lignes de différences au plus", ItemWidgets.compare_text(better, worn, false).split("\n").size() <= ItemWidgets.compare_text(better, worn, true).split("\n").size())
	check("pas de comparaison avec soi-même", ItemWidgets.compare_text(worn, worn, true) == "")
	# --- le widget : courte par défaut, complète avec mode 1, bascule ------------------------------------
	var card: Control = ItemWidgets.item_card(better, "", 0)
	add_child(card)
	var label: RichTextLabel = card.find_children("*", "RichTextLabel", true, false)[0]
	check("carte courte : indice « Maj : détails »", label.text.contains("Maj : détails"))
	check("carte courte : comparaison présente", label.text.contains("Porté :"))
	var full: Control = ItemWidgets.item_card(better, "", 1)
	add_child(full)
	var flabel: RichTextLabel = full.find_children("*", "RichTextLabel", true, false)[0]
	check("carte complète : plus d'indice, plus longue", not flabel.text.contains("Maj : détails") and flabel.text.length() > label.text.length())
	await get_tree().process_frame
	await get_tree().process_frame
	check("carte complète forcée : reste complète après quelques images (le moteur ne la repasse pas en courte)", flabel.text.contains("Prochaine amélioration") and not flabel.text.contains("Maj : détails"))
	check("carte courte forcée : le traitement par image est coupé", not card.is_processing() and not full.is_processing())
	var auto: ItemWidgets.ItemCard = ItemWidgets.item_card(better)
	add_child(auto)
	var before_len: int = auto._label.text.length()
	auto.detailed = true
	auto._refresh()
	check("bascule Maj : le texte change", auto._label.text.length() != before_len)
	check("carte qui suit Maj : traitement par image actif", auto.is_processing())
	check("le filet est un [hr] et le titre d'une pièce de set n'a pas le nom de la panoplie entre parenthèses",
		Items.describe(better, false).contains("[hr") and Items.card_name({"name": "Ceinture (Chevaliers du Temple)", "set": "x", "upgrade": 2}) == "+2 Ceinture")
	# carte de chaque pièce de l'échantillon dans le widget (sans erreur)
	var n_ok := 0
	for it in sample:
		var c: Control = ItemWidgets.item_card(it)
		add_child(c)
		n_ok += 1
		c.queue_free()
	check("%d cartes construites dans le widget" % n_ok, n_ok == sample.size())
	# --- Survie : l'enclume de l'emplacement compte pour la pièce portée ---------------------------------
	Run.start_survival("warrior", 1)
	Run.hero_level = 5
	var piece: Dictionary = Profile.equipped["chest"]
	Run.slot_bonus["chest"] = 3
	var eff := Items.anvil_applied(piece, "chest")
	check("enclume : +N de la pièce + bonus d'emplacement", int(eff.upgrade) == mini(int(piece.get("upgrade", 0)) + 3, maxi(Run.UPGRADE_CAP, int(piece.get("upgrade", 0)))))
	check("enclume : la pièce d'origine ne change pas", int(piece.get("upgrade", 0)) < int(eff.upgrade))
	var rc := _plain(ItemWidgets.card_text(piece, "", true))
	check("enclume : la carte de la pièce portée montre le +N total et la ligne d'enclume", rc.contains("+%d " % int(eff.upgrade)) and rc.contains("Enclume de la run : +3"))
	check("en run : pas de « Prochaine amélioration »", not rc.contains("Prochaine amélioration"))
	Run.slot_bonus.clear()
	print("\n%s (%d échec(s))" % ["TOUT EST OK" if fails == 0 else "ÉCHECS", fails])
	get_tree().quit(1 if fails > 0 else 0)
