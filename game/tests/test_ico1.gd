extends Node
## Pictogrammes d'interface (ICO-1) : chaque icône du catalogue existe en 128 et 64 px, à la bonne taille, importée, non vide ;
## chaque mécanique de boss, chaque ressource et chaque statut sans icône trouvent leur pictogramme ; l'API `Ico` et les
## branchements (ressources, statuts, marques, cadenas, touches de manette) tiennent.
## godot --headless --path game res://tests/test_ico1.tscn

var fails := 0


func check(label: String, ok: bool) -> void:
	if not ok:
		print("ÉCHEC " + label)
		fails += 1


func _ready() -> void:
	get_tree().create_timer(120.0).timeout.connect(func(): get_tree().quit(1))
	var man: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/ui/icons/ico_manifest.json"))
	check("catalogue : au moins 170 pictogrammes", man.size() >= 170)
	var kinds := {}
	for id in man:
		var k := String(man[id].kind)
		kinds[k] = int(kinds.get(k, 0)) + 1
		for suffix in ["", "_64"]:
			var path: String = "res://assets/ui/icons/ico_%s%s.png" % [id, suffix]
			var px := 128 if suffix == "" else 64
			check("fichier : " + path.get_file(), FileAccess.file_exists(path))
			check("import : " + path.get_file(), FileAccess.file_exists(path + ".import"))
			var t := load(path) as Texture2D
			check("chargée : " + path.get_file(), t != null)
			if t == null:
				continue
			check("taille %d : %s" % [px, path.get_file()], t.get_width() == px and t.get_height() == px)
			var img := t.get_image()
			if img != null:
				if img.is_compressed():
					img.decompress()
				check("coin transparent : " + path.get_file(), img.get_pixel(0, 0).a < 0.05)
				var opaque := 0
				for y in range(0, img.get_height(), 4):
					for x in range(0, img.get_width(), 4):
						if img.get_pixel(x, y).a > 0.9:
							opaque += 1
				check("pas vide : " + path.get_file(), opaque > 20)
		check("Ico.has : " + String(id), Ico.has(String(id)))
		check("Ico.tex : " + String(id), Ico.tex(String(id), 20) != null and Ico.tex(String(id), 100) != null)
	check("trois familles : tuile, glyph, symbole", kinds.has("tile") and kinds.has("glyph") and kinds.has("sym"))
	# --- les trois familles du catalogue sont toutes là
	for id in ["check", "cross", "lock", "unlock", "star", "star_empty", "goal", "new", "quest_done", "quest_todo", "cmp_up", "cmp_down",
			"pad_a", "pad_b", "pad_x", "pad_y", "pad_cross", "pad_circle", "pad_square", "pad_triangle", "key_cap", "rank_0", "rank_4",
			"diff_normal", "diff_heroic", "diff_mythic", "rar_0", "rar_5", "act_survival", "act_royale", "act_autochess", "res_insignia", "res_pe"]:
		check("indispensable : " + id, man.has(id))
	# --- une mécanique de boss = un pictogramme (29 briques + attaques de base + fureur)
	var bricks := 0
	for type in BossBricks.DEFS:
		bricks += 1
		check("boss : brique " + String(type), man.has("boss_" + String(type)))
	check("29 briques", bricks == 29)
	for type in BossBar.BASE_FAMILY:
		check("boss : attaque de base " + String(type), man.has("boss_" + String(type)))
	check("BossBar.icon_of : pictogramme maison", BossBar.icon_of("meteors") == Ico.tex("boss_meteors", 40))
	check("BossBar.icon_of : inconnu = coup", BossBar.icon_of("zzz") == Ico.tex("boss_hit", 40))
	check("deux mécaniques n'ont plus la même icône", BossBar.icon_of("lasers") != BossBar.icon_of("sweep"))
	# --- ressources : plus de pictogramme blanc générique
	for kind in ResourceHelp.KINDS:
		var ic := String(ResourceHelp.KINDS[kind].icon)
		check("ressource sans symbole générique : " + String(kind), ic.begins_with("ico:") or ic.begins_with("item:") or ic.begins_with("craft:"))
		check("ressource : icône chargée " + String(kind), ResourceHelp.icon(String(kind)) != null)
		if ic.begins_with("ico:"):
			check("ressource : pictogramme au catalogue " + ic, man.has(ic.trim_prefix("ico:")))
			check("ressource en couleurs : " + String(kind), ResourceHelp.is_item_icon(String(kind)))
	# --- statuts : plus aucun effet sans icône (pictogramme maison en dernier recours)
	var missing: Array = []
	for st in Combatant.STATUS_INFO:
		if StatusDb.icon(String(st)) == null:
			missing.append(st)
	check("statuts sans icône : %s" % str(missing), missing.is_empty())
	# --- API
	check("Ico.rank / difficulty / rarity / slot", Ico.rank(3) != null and Ico.difficulty(2) != null and Ico.rarity(5) != null and Ico.slot("head") != null)
	check("Ico.tex : id inconnu = null", Ico.tex("zzz_inconnue") == null and not Ico.has("zzz_inconnue"))
	check("petite taille = fichier 64", Ico.path("check", 20).ends_with("_64.png") and not Ico.path("check", 96).ends_with("_64.png"))
	var box := HBoxContainer.new()
	add_child(box)
	var m := Ico.mark(box, "check", 20)
	check("Ico.mark : TextureRect dans la rangée, taille minimale", m != null and m.get_parent() == box and m.custom_minimum_size.y == 20.0 and m.mouse_filter == Control.MOUSE_FILTER_IGNORE)
	var b := Button.new()
	b.text = "Mythique"
	add_child(b)
	Ico.lock(b)
	check("Ico.lock : cadenas en icône du bouton", b.icon == Ico.tex("lock", 18))
	var b2 := Button.new()
	b2.text = "Normal"
	Ico.state(b2, false, true)
	check("Ico.state : coche quand c'est fait", b2.icon == Ico.tex("check", 18))
	var b3 := Button.new()
	b3.text = "Normal"
	Ico.state(b3, false, false)
	check("Ico.state : rien quand ouvert et pas fait", b3.icon == null)
	check("cadenas BBCode au catalogue", Ico.LOCK_BB.contains("ico_lock_64.png") and FileAccess.file_exists("res://assets/ui/icons/ico_lock_64.png"))
	var rt := RichTextLabel.new()
	rt.bbcode_enabled = true
	add_child(rt)
	rt.text = "[color=#ffcf6b]" + Ico.LOCK_BB + " Débloqué au niveau 3[/color]"
	check("BBCode : le cadenas se lit sans erreur", rt.get_parsed_text().contains("Débloqué"))
	# --- touches de manette : un pictogramme par touche dessinée
	for k in UiNav.GLYPH_COLORS:
		check("manette : icône de " + String(k), UiNav.GLYPH_ICON.has(k) and man.has(String(UiNav.GLYPH_ICON[k])))
	# --- aucun emoji ne reste dans les écrans branchés
	for f in ["res://scripts/ui/today_panel.gd", "res://scripts/ui/quests_page.gd", "res://scripts/ui/quest_journal.gd", "res://scripts/ui/duel_queue.gd",
			"res://scripts/ui/dungeon_page.gd", "res://scripts/ui/class_picker.gd", "res://scripts/ui/guide.gd", "res://scripts/ui/grimoire.gd"]:
		var src := FileAccess.get_file_as_string(f)
		check("plus d'emoji cadenas : " + f.get_file(), not src.contains("🔒"))
	print("[ico1] %d pictogrammes (%s), %d échec(s)" % [man.size(), str(kinds), fails])
	print("TEST ICO1 : " + ("OK" if fails == 0 else "ÉCHEC"))
	get_tree().quit(1 if fails > 0 else 0)
