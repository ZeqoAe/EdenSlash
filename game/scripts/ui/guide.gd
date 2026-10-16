class_name Guide
extends PageScreen
## Guide (F1, fiches de découverte, lobby) : la seule aide du jeu. Six onglets dans le cadre des autres
## écrans à pages : Commandes (tes touches réelles, Premiers pas, aide au combat), Cartes (sorts, cartes,
## trophées), Survie, Équipement, Modes (le rôle de chaque activité), puis Détails (les formules,
## `InfoPage`). Les fiches de découverte (`Tutorial.CARDS`) y sont rangées par chapitre ; ouvrir le Guide
## sur une fiche descend jusqu'à elle.
## En jeu il met la partie en pause (et la remet comme il l'a trouvée).

## [identifiant, onglet, sous-titre]
const CHAPTERS := [
	["controls", "Commandes", "Touches et premiers pas"],
	["cards", "Cartes", "Sorts, cartes et trophées"],
	["run", "Survie", "Une run et ce que tu en gardes"],
	["gear", "Équipement", "Acquérir et améliorer"],
	["modes", "Modes", "À quoi sert chaque activité"],
	["details", "Détails", "Les formules, pour les curieux"],
]
## Anciens identifiants de chapitre (appels existants) -> nouvel identifiant ou « chapitre:bloc ».
const ALIASES := {"commands": "controls", "steps": "controls:steps", "tips": "controls:tips", "news": "news"}
## Ordre des fiches du chapitre « Survie » (le déroulé d'abord).
const RUN_ORDER := ["portal", "rage", "anvil", "merchant", "shrine", "fortune", "giant", "reward_chest", "results"]
## Rôle de chaque activité : ce qu'elle est seule à apporter.
const ROLES := {
	"survival": "Le cœur du jeu : tu y découvres de nouvelles pièces et ta classe y gagne de la maîtrise.",
	"survivor": "[ul]Vingt minutes sur une carte : tu pars sans arme ni pièce, tout se gagne aux cartes.\nChaque pièce prise reste à vie ; elle gagne un passif à +6, +8 et +10.\nTrois gardiens à 5, 10 et 15 minutes, puis le boss à 20:00. Cinq paliers, chacun ouvert par une victoire au précédent.\nUn mode à part : il donne des apparences et des titres, rien d'autre.[/ul]",
	"dungeon": "Quatre salles et un boss, seul ou avec des alliés IA. Chaque donjon a sa panoplie et ses plans.",
	"tower": "Monte étage après étage, avec une seule vie, contre des duellistes de toutes les classes. Elle donne des cristaux et des gemmes.",
	"quests": "Trois quêtes par jour, deux par semaine, des défis de classe. Le Défi du jour est une Survie avec deux contraintes.",
	"rush": "Les huit boss à la suite. Elle donne des fournitures de haut niveau et des titres.",
	"siege": "Cinq vagues avec deux alliés IA, un boss, puis chacun pour soi. Elle donne les formules d'enchantement les plus hautes.",
	"duel": "Un contre un contre l'IA, à l'arme ou équipé. Monte la Ligue, puis affronte le Panthéon et son équipement.",
	"arenas": "Deux contre deux ou trois contre trois, avec des alliés IA. Titres et maîtrise.",
	"royale": "Huit héros, un seul survivant. Apparences de prestige et titre.",
	"training": "Teste tes sorts, tes armes et tes cartes sans rien risquer.",
}

var _paused_before := false
var _was_open := false


static func open_on(parent: Node, chapter := "") -> Guide:
	for n in parent.get_children():
		if n is Guide and not n.is_queued_for_deletion():
			(n as Guide).select(chapter)
			return n
	var g := Guide.new()
	parent.add_child(g)
	g.build()
	g.select(chapter)
	return g


## Ferme le Guide s'il est ouvert (touche F1 qui rappuie) ; renvoie vrai s'il l'était.
static func close_in(parent: Node) -> bool:
	for n in parent.get_children():
		if n is Guide:
			(n as Guide).close()
			return true
	return false


func _init() -> void:
	super("Guide", 40)


func build() -> void:
	_paused_before = get_tree().paused
	get_tree().paused = true
	set_title("Guide", "Les formules, pour les curieux")
	for c in CHAPTERS:
		if c[0] == "details":
			var info := InfoPage.new()
			info.player = get_tree().get_first_node_in_group("player") as Player
			add_page(String(c[1]), info)
		else:
			add_page(String(c[1]), GuidePage.new(String(c[0]), String(c[2])))
	var narrow := get_viewport().get_visible_rect().size.x < 1150.0
	for b in _tab_buttons:  # six onglets : un peu plus serrés que dans les autres écrans
		b.custom_minimum_size = Vector2(0, 42)
		b.add_theme_font_size_override("font_size", 15 if narrow else 16)
	closed.connect(func():
		_was_open = false
		get_tree().paused = _paused_before
		queue_free())
	_was_open = true


## Ouvre (ou montre) le chapitre [param chapter] : un onglet, une fiche de découverte (on descend
## jusqu'à elle), ou un ancien identifiant. Rien ou inconnu : Commandes.
func select(chapter := "") -> void:
	var id := chapter
	var block := ""
	if ALIASES.has(id):
		id = String(ALIASES[id])
	if id == "news":
		id = "gear"
		var best := ""
		for cid in Tutorial.CARDS:
			if Tutorial._vkey(String(Tutorial.CARDS[cid].version)) <= Tutorial._vkey(Version.NUMBER) \
					and (best == "" or Tutorial._vkey(String(Tutorial.CARDS[cid].version)) > Tutorial._vkey(String(Tutorial.CARDS[best].version))):
				best = String(cid)
		if best != "":
			block = best
			id = Tutorial.chapter_of(best)
	elif ":" in id:
		var p := id.split(":")
		id = p[0]
		block = p[1]
	elif Tutorial.CARDS.has(id):
		block = id
		id = Tutorial.chapter_of(id)
	var i := chapter_index(id)
	var pg := page(i)
	if pg is GuidePage:
		(pg as GuidePage).focus = block
	if is_open():
		show_page(i)
	else:
		open(i)


static func chapter_index(id: String) -> int:
	for i in CHAPTERS.size():
		if CHAPTERS[i][0] == id:
			return i
	return 0


func close() -> void:
	close_ui()


func _unhandled_input(event: InputEvent) -> void:
	if _was_open and (event.is_action_pressed("help") or event.is_action_pressed("pause")):
		close()
		get_viewport().set_input_as_handled()


# --- contenu -------------------------------------------------------------------------------
## Une touche (ou une série) dans le texte : en or, gras.
static func key(t: String) -> String:
	return "[b][color=#f5c75a]%s[/color][/b]" % t


## Tableau à deux colonnes : [libellé, valeur] ; la valeur est mise en avant.
static func table(rows: Array) -> String:
	var s := "[table=2]"
	for r in rows:
		s += "[cell]%s[/cell][cell]%s[/cell]" % [r[0], key(String(r[1]))]
	return s + "[/table]"


static func bullets(lines: Array) -> String:
	return "[ul]%s[/ul]" % "\n".join(lines)


static func _cam_label() -> String:
	if Gamepad.active:
		return Settings.action_label("camera_rotate", 1)
	var mask := Settings.camera_rotate_mask()
	return "%s (maintenu)" % ("Clic molette" if mask == MOUSE_BUTTON_MASK_MIDDLE else Settings.action_label("camera_rotate", 1))


## Blocs du chapitre [param id] : [{id, title, text, extra?}].
static func blocks_for(id: String) -> Array:
	var out: Array = []
	var l := func(a: String) -> String: return Settings.action_label(a, 1)
	match id:
		"controls":
			if Tutorial.mode() == "guided" and not Tutorial.done_all():
				var t := ""
				for s in Tutorial.STEPS:
					t += "%s %s\n" % ["[color=#8fe39a]✔[/color]" if s.id in Tutorial.steps_done() else "[color=#888888]·[/color]", Tutorial.step_text(s)]
				out.append({"id": "steps", "title": Tutorial.progress_text(), "text": t.strip_edges() + "\n[color=#b8b4c8]Ils se valident en jouant, dans ta première Survie.[/color]", "skip": true})
			var move: String = "Stick gauche" if Gamepad.active else " ".join(["move_forward", "move_left", "move_back", "move_right"].map(func(a): return l.call(a)))
			var rows: Array = [["Se déplacer", move], ["Sauter", l.call("jump")], ["Esquiver (invulnérable)", l.call("dodge")], ["Tourner la caméra", _cam_label()]]
			if not Gamepad.active:
				rows.append(["Zoom", "Molette"])
			out.append({"id": "move", "title": "Mouvement", "text": table(rows)})
			var hit: Array = {
				"click": ["Se déplacer et attaquer", "%s (maintenu)" % l.call("attack")],
				"rts": ["Se déplacer et attaquer", l.call("move_order")],
			}.get(Settings.move_mode(), ["Attaquer", l.call("attack")])
			var skills := " ".join([1, 2, 3, 4].map(func(i): return l.call("skill_%d" % i)))
			out.append({"id": "fight", "title": "Combat", "text": table([hit, ["Sorts 1 à 4", skills],
				["Potion de soin", l.call("potion_1")], ["Potion d'effet", l.call("potion_2")], ["S'extraire (10 s)", l.call("extract")]])})
			out.append({"id": "world", "title": "Monde", "text": table([["Interagir (coffre, PNJ, donjon)", l.call("interact")],
				["Carte", l.call("map")], ["Objectifs", l.call("objectives")], ["Équiper la trouvaille", l.call("quick_equip")],
				["Se débloquer", l.call("unstuck")]])})
			out.append({"id": "menus", "title": "Menus", "text": table([["Menu / pause", l.call("pause")], ["Ce Guide", l.call("help")]])
				+ "\nTout se règle dans Paramètres > Touches."})
			if TestTools.dev_keys():
				out.append({"id": "dev", "title": "Mode dev", "text": table([["Infos de débogage", l.call("debug_overlay")], ["+1 niveau", "F5"],
					["Entrée du donjon", "F6"], ["Arène du boss", "F7"], ["Déclencher la rage", "F8"], ["Signaler un problème", l.call("feedback")]])
					+ "\nAlt + clic droit sur n'importe quoi : note sur cet élément."})
			var level := String(Settings.assist_level())
			var lines: Array = Tutorial.CARDS.assist.lines
			out.append({"id": "assist", "title": "Aide au combat : %s" % String(Settings.ASSIST.get(level, {}).get("name", "")), "text": bullets(lines)})
			out.append({"id": "tips", "title": "Fiches de découverte",
				"text": "Une courte fiche s'affiche la première fois que tu rencontres une nouveauté. Toutes restent ici, rangées par chapitre.", "switch": true})
		"cards":
			for cid in Tutorial.CARDS:
				if Tutorial.CARDS[cid].chapter == id:
					out.append(_card_block(String(cid)))
			out.append({"id": "spells", "title": "Tes sorts", "text": bullets([
				"Quatre sorts sont prêts en combat, sur %s." % " ".join([1, 2, 3, 4].map(func(i): return key(Settings.action_label("skill_%d" % i, 1)))),
				"Héros > Classe > Grimoire : tous les sorts de ta classe. Glisse-les dans tes cases pour composer ton kit."])})
			out.append({"id": "unlock_cards", "title": "Cartes à débloquer", "text": bullets([
				"Certaines cartes demandent de la maîtrise ou un exploit.",
				"Héros > Cartes les montre toutes, avec ce qui te manque."])})
		"run":
			out.append({"id": "survival", "title": "Une run de Survie", "text": bullets([
				"Tu pars au niveau 1 avec ton équipement du hub.",
				"Une époque = 3 cartes. Sur chacune : casse tout, ouvre les coffres, réunis 3 sceaux sur les gardiens d'élite, puis bats le boss du donjon.",
				"Battre le boss de la 3e carte ouvre l'époque suivante."])})
			for cid in RUN_ORDER:
				out.append(_card_block(String(cid)))
			out.append({"id": "progress", "title": "Ce qui progresse", "text": bullets([
				"[b]Maîtrise[/b] : chaque run en donne à ta classe. Elle ouvre des sorts, des certificats et, avec le temps, les autres classes.",
				"[b]Insignes[/b] : donnés à la fin de chaque run, même perdue. Ils s'échangent contre des pièces à l'Armurerie.",
				"[b]Étoiles[/b] : trois par époque. Après l'époque IV, les rangs héroïques durcissent la Survie et la rendent plus généreuse."])})
		"gear":
			out.append(_card_block("hub_gear"))
			out.append({"id": "armory", "title": "Armurerie : les insignes", "text": bullets([
				"Atelier > Armurerie. Chaque pièce vue dans un coffre de Survie peut s'y acheter avec des insignes.",
				"Une pièce achetée se porte tout de suite au hub, donc dès ta prochaine Survie."]) + _lock("armory")})
			out.append({"id": "forge", "title": "Forge : les cristaux", "text": bullets([
				"Atelier > Forge. Monte une pièce jusqu'à +10, sertis des gemmes, ajoute un enchantement.",
				"Il faut des cristaux et des fournitures (parchemins, gemmes, formules).",
				"Les cristaux viennent des Donjons, de la Ruée, du Siège et de la Tour, qui donnent aussi des coffres de forge et de joaillier.",
				"En Survie, les fournitures ne sont gardées qu'après une victoire ou une extraction."]) + _lock("forge")})
			out.append({"id": "craft", "title": "Fabrication", "text": bullets([
				"Atelier > Fabrication. Un plan de donjon permet de fabriquer une pièce de sa panoplie, contre des cristaux.",
				"Les plans tombent dans les donjons."])})
			out.append({"id": "sets", "title": "Panoplies", "text": bullets([
				"Porter 2, 4 ou 6 pièces d'une même panoplie active ses bonus.",
				"Chaque donjon a la sienne. Le Panthéon, en Duel, donne celle des Esprits."])})
			out.append({"id": "power", "title": "Puissance d'équipement", "text": bullets([
				"Un nombre qui résume ce que tu portes.",
				"Les difficultés élevées des Donjons et du Siège demandent une puissance minimale."])})
			out.append({"id": "presets", "title": "Préréglages", "text": bullets([
				"Héros > Équipement : choisis les pièces portées par chaque classe.",
				"La Survie part avec le préréglage actif."])})
		"modes":
			for a in Activities.LIST:
				if a.get("soon", false) or not ROLES.has(String(a.id)):
					continue
				var txt := String(ROLES[String(a.id)])
				if Activities.locked(a):
					txt += _lock_line(String(a.unlock))
				out.append({"id": "mode_" + String(a.id), "title": String(a.name), "text": txt})
			out.append({"id": "chests", "title": "Coffres et roulette", "text": bullets([
				"Les coffres de récompense (boss, défis, autel) s'ouvrent dans le menu Coffres.",
				"La roulette du jour ne donne que des apparences."])})
	return out


static func _lock(unlock_id: String) -> String:
	return "" if Unlocks.is_open(unlock_id) else _lock_line(unlock_id)


## Condition d'ouverture d'une entrée encore verrouillée, en gris.
static func _lock_line(unlock_id: String) -> String:
	return "\n[color=#9a98a8]🔒 %s[/color]" % Unlocks.condition(unlock_id)


static func _card_block(cid: String) -> Dictionary:
	var c: Dictionary = Tutorial.CARDS[cid]
	return {"id": cid, "title": String(c.title), "text": bullets(c.lines)}


## Page d'un chapitre : blocs en deux colonnes (une seule sur une fenêtre étroite), reconstruits à chaque
## affichage (les touches et les Premiers pas changent). [member focus] : bloc à montrer et à mettre en valeur.
class GuidePage extends VBoxContainer:
	var chapter: String
	var sub: String
	var focus := ""
	var _scroll: ScrollContainer
	var _box: VBoxContainer
	var _blocks := {}

	func _init(chapter_id: String, subtitle_text: String) -> void:
		chapter = chapter_id
		sub = subtitle_text
		var panel := ItemWidgets.panel(self, 0, true)
		_scroll = ScrollContainer.new()
		_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		panel.add_child(_scroll)
		_box = VBoxContainer.new()
		_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_box.add_theme_constant_override("separation", 10)
		_scroll.add_child(_box)

	## Pas de sous-titre sur une fenêtre étroite : la ligne d'onglets passe avant.
	func subtitle() -> String:
		return "" if get_viewport_rect().size.x < 1150.0 else sub

	func refresh() -> void:
		for c in _box.get_children():
			_box.remove_child(c)
			c.queue_free()
		_blocks.clear()
		var grid := GridContainer.new()
		grid.columns = 2 if get_viewport_rect().size.x >= 1000.0 else 1
		grid.add_theme_constant_override("h_separation", 12)
		grid.add_theme_constant_override("v_separation", 10)
		grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_box.add_child(grid)
		for b in Guide.blocks_for(chapter):
			_blocks[String(b.id)] = _block(grid, b)
		if focus != "":
			var f := focus
			focus = ""
			_show_block.call_deferred(f)
		else:
			_scroll.scroll_vertical = 0

	func _show_block(id: String) -> void:
		if not _blocks.has(id) or not is_inside_tree():
			return
		var pc: PanelContainer = _blocks[id]
		pc.add_theme_stylebox_override("panel", _box_style(true))
		await get_tree().process_frame
		await get_tree().process_frame
		if is_instance_valid(pc) and is_inside_tree():
			_scroll.scroll_vertical = maxi(0, int(pc.global_position.y - _box.global_position.y) - 6)

	static func _box_style(hot: bool) -> StyleBoxFlat:
		var sb := UiTheme.flat_box(Color(0.1, 0.08, 0.17, 0.95) if hot else Color(0.06, 0.05, 0.12, 0.9), UiTheme.GOLD if hot else Color(UiTheme.GOLD_DIM, 0.55), 2 if hot else 1, 8, false)
		sb.set_content_margin_all(14)
		return sb

	func _block(parent: Control, b: Dictionary) -> PanelContainer:
		var pc := PanelContainer.new()
		pc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		pc.add_theme_stylebox_override("panel", _box_style(false))
		# navigable à la manette (le curseur saute de bloc en bloc et fait défiler la page)
		pc.mouse_filter = Control.MOUSE_FILTER_STOP
		pc.gui_input.connect(func(_e): pass)
		parent.add_child(pc)
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 6)
		pc.add_child(v)
		var t := Hud._label(v, String(b.title), 20, UiTheme.GOLD)
		t.add_theme_font_override("font", UiTheme.bold_font())
		t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		t.custom_minimum_size.x = 160.0
		var rt := RichTextLabel.new()
		rt.bbcode_enabled = true
		rt.fit_content = true
		rt.scroll_active = false
		rt.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rt.custom_minimum_size.x = 160.0
		rt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		rt.add_theme_font_size_override("normal_font_size", 16)
		rt.add_theme_font_size_override("bold_font_size", 16)
		rt.add_theme_color_override("default_color", UiTheme.TEXT)
		rt.add_theme_constant_override("table_h_separation", 12)
		rt.add_theme_constant_override("table_v_separation", 4)
		rt.text = String(b.text)
		v.add_child(rt)
		if b.get("skip", false):
			var sk := MenuWidgets.glass_button("Passer les Premiers pas", 16, Vector2(0, 40))
			sk.pressed.connect(func():
				Tutorial.skip_steps()
				refresh())
			v.add_child(sk)
		if b.get("switch", false):
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 12)
			v.add_child(row)
			var lab := Hud._label(row, "Afficher les fiches en jeu", 16, UiTheme.TEXT)
			lab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var sw := UiTheme.Switch.new()
			sw.set_on(not bool(Profile.tutorial.get("cards_off", false)))
			sw.toggled.connect(func(on: bool):
				Profile.tutorial["cards_off"] = not on
				Profile.save_profile())
			row.add_child(sw)
		return pc
