extends Node
## Création de personnage (lot C1) : nom (valide / invalide, filtre, nom au hasard), sauvegarde et migration d'un vieux profil,
## visage du héros (coiffure, teinte des cheveux et des yeux) sur toutes les classes et avec une apparence débloquée,
## écran de création (aperçu, Aléatoire, Réinitialiser, Valider, Annuler, « Garder tel quel », confirmation), manette.
## godot --headless --path game res://tests/test_c1.tscn

const PATH := "user://c1_test.json"
const OUTFIT := "res://assets/player/outfits/l205_43413f.glb"
const HAT := "res://assets/player/outfits/head_l1288.glb"

var fails := 0


func check(label: String, ok: bool) -> void:
	print(("OK    " if ok else "ÉCHEC ") + label)
	if not ok:
		fails += 1


func _ready() -> void:
	Settings.reset_all()
	Profile.selected_class = "warrior"
	Profile.reset_all()
	var main_path: String = Profile.save_path
	_test_names()
	_test_save_and_migration()
	Profile.save_path = main_path
	Profile.reset_all()
	_test_model()
	await _test_player()
	await _test_creator()
	Profile.save_path = main_path
	Profile.reset_all()
	Settings.reset_all()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
	for ext in [".bak", ".tmp"]:
		if FileAccess.file_exists(PATH + ext):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH + ext))
	print("\n%s (%d échec(s))" % ["TOUT EST OK" if fails == 0 else "ÉCHECS", fails])
	get_tree().quit(1 if fails > 0 else 0)


func _test_names() -> void:
	for n in ["Kaelis", "Jean-Luc", "Élodie 2", "Ana", "Conan", "Monique", "Seize lettres ok"]:
		check("nom valable : « %s »" % n, HeroLook.valid_name(n))
	var bad := {"": "vide", "   ": "espaces seuls", "ab": "trop court", "Dix-sept lettres!": "signe interdit",
		"Abcdefghijklmnopq": "17 lettres", "123": "aucune lettre", "Kae_lis": "souligné", "Connard": "grossier",
		"le con": "mot grossier entier", "C0NNARD": "grossier en chiffres", "pu-tain": "grossier coupé d'un tiret"}
	for n in bad:
		check("nom refusé (%s) : « %s » -> %s" % [bad[n], n, HeroLook.name_error(n)], not HeroLook.valid_name(n) and HeroLook.name_error(n) != "")
	check("espaces en trop retirés", HeroLook.tidy("  Kae   lis ") == "Kae lis")
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var ok := true
	var seen := {}
	for i in 200:
		var n := HeroLook.random_name(rng)
		seen[n] = true
		ok = ok and HeroLook.valid_name(n)
	check("noms au hasard : tous valables, variés (%d différents sur 200)" % seen.size(), ok and seen.size() >= 60)


func _write(d: Dictionary) -> void:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify(d))
	f.close()


func _reload() -> void:
	Profile.save_path = PATH
	Profile._clear()
	Profile.load_profile()
	Profile._lobby_view()
	Profile._ensure_starter()


func _test_save_and_migration() -> void:
	# vieux profil (avant C1) : aucun champ du personnage -> sans nom, visage de la classe, création à proposer une fois
	_write({"selected_class": "warrior", "runs_done": 4, "expertise": {"warrior": 900}})
	_reload()
	check("vieux profil : chargé sans perte (parties, maîtrise)", Profile.runs_done == 4 and int(Profile.expertise.get("warrior", 0)) == 900)
	check("vieux profil : sans nom, visage d'origine, création à proposer", Profile.hero_name == "" and HeroLook.is_default(Profile.hero_look)
		and HeroLook.needs_creation())
	# valeurs abîmées : nom refusé, coiffure inconnue ramenée à celle de la classe, couleur valable gardée
	_write({"selected_class": "warrior", "hero_name": "Kae!!", "hero_look": {"hair": "zzz", "eyes": "green", "x": 1}, "hero_made": true})
	_reload()
	check("valeurs abîmées : nom vidé, coiffure inconnue -> classe, yeux gardés, clé inconnue retirée", Profile.hero_name == ""
		and Profile.hero_look == {"hair": "", "hair_color": "", "eyes": "green"} and not HeroLook.needs_creation())
	_write({"selected_class": "warrior", "hero_look": "abîmé"})
	_reload()
	check("visage illisible : celui de la classe", HeroLook.is_default(Profile.hero_look))
	# sauvegarde (SafeFile) puis rechargement
	Profile.save_path = PATH
	HeroLook.save("  Kaelis ", {"hair": "l108", "hair_color": "blond", "eyes": "violet"})
	check("enregistré : nom propre, création faite", Profile.hero_name == "Kaelis" and Profile.hero_made)
	Profile.save_profile()
	check("sauvegarde sûre (SafeFile) : copie de secours .bak au second enregistrement", FileAccess.file_exists(PATH + ".bak")
		and SafeFile.read(PATH).contains("\"hero_name\":\"Kaelis\""))
	_reload()
	check("rechargé : nom, visage et création faite gardés", Profile.hero_name == "Kaelis" and Profile.hero_look.hair == "l108"
		and Profile.hero_look.hair_color == "blond" and Profile.hero_look.eyes == "violet" and Profile.hero_made)
	HeroLook.save("ab", {})
	check("nom invalide : l'ancien nom est gardé", Profile.hero_name == "Kaelis")
	Profile.reset_all()
	check("nouvelle partie : rien du personnage précédent", Profile.hero_name == "" and not Profile.hero_made and HeroLook.is_default(Profile.hero_look))


func _hair_of(model: Node3D) -> Array:
	var out := {}
	for mi: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		var p := String(mi.get_meta("part", ""))
		if p.contains("/hairs/"):
			out[p] = true
	return out.keys()


func _test_model() -> void:
	var cls := GameData.class_data("warrior")
	var orig: String = cls.parts[1]
	var plain := EdenModel.instantiate_hero(cls, "", [], {}, HeroLook.current())
	check("visage d'origine : cheveux de la classe, rien de teint", _hair_of(plain) == [orig] and not HeroLook.part_tinted(plain, orig)
		and not HeroLook.eyes_tinted(plain))
	plain.free()
	var look := {"hair": "l108", "hair_color": "blond", "eyes": "violet"}
	var m := EdenModel.instantiate_hero(cls, "", [], {}, look)
	var hair := HeroLook.hair_part(cls, look)
	check("coiffure choisie : la variante grise est portée (%s)" % hair.get_file(), _hair_of(m) == [hair] and hair.ends_with("l108_%s.glb" % HeroLook.GRAY))
	check("couleur des cheveux : teinte posée", HeroLook.part_tinted(m, hair))
	check("couleur des yeux : iris recolorés (masque présent)", HeroLook.eyes_tinted(m) and ResourceLoader.exists(HeroLook.EYE_MASK))
	m.free()
	# coiffure choisie, couleur d'origine : celle de la classe si la coiffure existe dans cette couleur, sinon la plus proche teinte
	var cc := HeroLook.hair_choice(cls, {"hair": "l102"})
	check("coiffure sans la couleur de la classe : variante grise teinte d'une couleur proche (%s)" % cc.tint,
		String(cc.path).ends_with("l102_%s.glb" % HeroLook.GRAY) and String(cc.tint) != "")
	# avec une apparence débloquée (tenue, chapeau teint) : la création règle le visage, l'apparence la tenue
	var m2 := EdenModel.instantiate_hero(cls, OUTFIT, [HAT], {HAT: [[220, 30, 40], [150, 10, 20], [255, 90, 90]]}, look)
	var parts := {}
	for mi: MeshInstance3D in m2.find_children("*", "MeshInstance3D", true, false):
		parts[String(mi.get_meta("part", ""))] = true
	check("apparence débloquée + visage : tenue, chapeau et coiffure portés ensemble", parts.has(OUTFIT) and parts.has(HAT) and parts.has(hair)
		and not parts.has(String(cls.parts[0])))
	check("apparence débloquée + visage : cheveux et yeux teints", HeroLook.part_tinted(m2, hair) and HeroLook.eyes_tinted(m2))
	m2.free()
	# toutes les classes : la coiffure choisie existe, le visage se pose
	var bad: Array = []
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	for cid in GameData.classes:
		var c := GameData.class_data(cid)
		var lk := HeroLook.random_look(rng)
		var p := HeroLook.hair_part(c, lk)
		if p == "" or not ResourceLoader.exists(p) or HeroLook.hair_part(c, {}) != String(c.get("parts", ["", ""])[1]):
			bad.append(cid)
	check("60 classes : coiffures existantes, visage d'origine inchangé (%s)" % ", ".join(bad), bad.is_empty() and GameData.classes.size() >= 60)


func _test_player() -> void:
	Profile.hero_name = "Kaelis"
	Profile.hero_look = {"hair": "l105", "hair_color": "pink", "eyes": "green"}
	var p := Player.new()
	add_child(p)
	await get_tree().process_frame
	var hair := HeroLook.hair_part(p.cls, Profile.hero_look)
	check("en jeu : le héros porte son nom", p.display_name == "Kaelis")
	check("en jeu : coiffure et couleurs du personnage", _hair_of(p.model) == [hair] and HeroLook.part_tinted(p.model, hair) and HeroLook.eyes_tinted(p.model))
	p.queue_free()
	var foe := Player.new()
	foe.foe = true
	foe.class_id = "magician"
	add_child(foe)
	await get_tree().process_frame
	check("adversaire héros : nom de sa classe, visage de sa classe", foe.display_name != "Kaelis" and not HeroLook.eyes_tinted(foe.model)
		and _hair_of(foe.model) == [String(GameData.class_data("magician").parts[1])])
	foe.queue_free()
	Profile.hero_name = ""
	Profile.hero_look = {}
	await get_tree().process_frame


func _test_creator() -> void:
	Gamepad.active = true
	var host := Node.new()
	add_child(host)
	# premier passage (compte neuf) : nom proposé, aperçu construit
	var c := HeroCreator.open_on(host, true)
	await get_tree().process_frame
	await get_tree().process_frame
	check("création : ouverte, nom proposé valable", c.is_open() and HeroLook.valid_name(c.name_edit.text) and not c.ok_button.disabled)
	check("création : l'aperçu 3D s'est construit", c.preview._pivot.get_child_count() > 0)
	var yaw: float = c.preview._pivot.rotation.y
	c.preview.turn(0.5)
	check("création : l'aperçu tourne (stick droit)", absf(c.preview._pivot.rotation.y - yaw - 0.5) < 0.001)
	c.name_edit.text = "ab"
	c._check_name()
	check("création : nom trop court -> message, Valider grisé", c.error_label.text != "" and c.ok_button.disabled)
	c.name_edit.text = "Kaelis"
	c._check_name()
	c.random_button.pressed.emit()
	check("création : Aléatoire change le visage", not HeroLook.is_default(c._look))
	c.reset_button.pressed.emit()
	check("création : Réinitialiser remet le visage de la classe", HeroLook.is_default(c._look))
	# manette : les choix sont des contrôles atteignables (calque du dessus)
	var cands: Array = UiNav.candidates()
	check("manette : Valider, Aléatoire, pastilles et flèches sont navigables", cands.has(c.ok_button) and cands.has(c.random_button)
		and cands.has(c._hair_swatches["blond"]) and cands.has(c._eye_swatches["green"]))
	c._hair_swatches["blond"].pressed.emit()
	c._eye_swatches["green"].pressed.emit()
	c._step_hair(1)
	check("création : pastilles et flèches changent le choix", c._look.hair_color == "blond" and c._look.eyes == "green" and c._look.hair != "")
	var shown_key: String = c.preview._shown
	check("création : l'aperçu suit le choix", shown_key.contains("blond") and shown_key.contains("green"))
	var picked: Dictionary = c._look.duplicate()
	var got := [null]
	c.finished.connect(func(ok: bool): got[0] = ok)
	c.ok_button.pressed.emit()  # premier passage : pas de confirmation
	await get_tree().process_frame
	check("Valider : nom et visage enregistrés, création faite", got[0] == true and Profile.hero_name == "Kaelis" and Profile.hero_look == picked and Profile.hero_made)
	# plus tard (Héros > Personnage) : Annuler ne change rien
	var c2 := HeroCreator.open_on(host, false)
	await get_tree().process_frame
	check("plus tard : pré-rempli avec le nom et le visage", c2.name_edit.text == "Kaelis" and c2._look == picked)
	c2._look.hair_color = "green"
	c2.name_edit.text = "Autre nom"
	c2.close_ui()
	await get_tree().process_frame
	check("Annuler : rien ne change", Profile.hero_name == "Kaelis" and Profile.hero_look == picked)
	# plus tard : Valider demande une petite confirmation gratuite
	var c3 := HeroCreator.open_on(host, false)
	await get_tree().process_frame
	c3._look.hair_color = "green"
	c3._sync()
	c3.validate()
	await get_tree().process_frame
	check("plus tard : Valider attend la confirmation", Profile.hero_look.hair_color == "blond" and c3.is_open())
	var ask: InfoCard.Ask = null
	for n in c3.get_children():
		if n is InfoCard.Ask:
			ask = n
	check("confirmation : petite fenêtre « Garder ces changements ? »", ask != null)
	if ask != null:
		ask.ok_button.pressed.emit()
		await get_tree().create_timer(0.5).timeout
	check("confirmation acceptée : couleur changée", Profile.hero_look.hair_color == "green")
	# vieux compte : « Garder tel quel » ne change rien et ne rouvre plus l'écran
	Profile.hero_name = ""
	Profile.hero_look = {}
	Profile.hero_made = false
	var c4 := HeroCreator.open_on(host, true)
	await get_tree().process_frame
	check("vieux compte : bouton « Garder tel quel »", c4.keep_button.text == "Garder tel quel")
	c4.keep_button.pressed.emit()
	await get_tree().process_frame
	check("« Garder tel quel » : rien de changé, l'écran ne s'ouvrira plus seul", Profile.hero_name == "" and HeroLook.is_default(Profile.hero_look)
		and not HeroLook.needs_creation())
	Gamepad.active = false
	host.queue_free()
	await get_tree().process_frame
