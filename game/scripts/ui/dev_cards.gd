class_name DevCards
## Éditeur de cartes du mode dev : cartes de build (nom, texte, fréquence, niveaux, stats par
## carte commune, effets déclenchés et leur progression par niveau) et règles (raretés tirées :
## multiplicateur et poids ; améliorations de sort : dégâts, soins, durée, recharge, bonus
## d'attribut au lancement). Enregistré dans data/dev_edits.json -> "cards", "card_rules".

const EFFECTS := ["lightning", "freeze", "chill", "burn", "shock", "explosion", "nova", "buff", "heal", "cdr", "echo"]
const BUFFS := ["frenzy", "keen", "haste", "barrier", "fury", "might", "swift", "grace", "vitality", "resolve"]
## Paramètres numériques d'un effet : [clé, nom, unité ("%" : saisi en %), min, max, pas].
const PARAMS := [["chance", "Chances", "%", 0.0, 100.0, 1.0], ["cd", "Recharge (s)", "", 0.0, 120.0, 0.1],
	["mult", "Dégâts", "%", 0.0, 2000.0, 5.0], ["radius", "Rayon (m)", "", 0.0, 30.0, 0.1],
	["duration", "Durée (s)", "", 0.0, 60.0, 0.1], ["chain", "Rebonds", "", 0.0, 20.0, 1.0],
	["amount", "Effet (soin en %, recharge en s)", "", 0.0, 100.0, 0.01]]
## Stats propres aux cartes ajoutées à la liste des stats : [clé, nom].
static func card_stats() -> Array:
	var out: Array = []
	for k in Cards.STAT_FR:
		if not k in Items.PERCENT_STATS and not Items.STAT_NAMES.has(k):
			out.append([String(k), String(Cards.STAT_FR[k][0]) + (" %" if String(Cards.STAT_FR[k][1]) == "%" else "")])
	return out


class CardsPage extends HBoxContainer:
	var _list: ItemList
	var _ids: Array = []  # "" = règles
	var _search: LineEdit
	var _id := ""
	var _form: VBoxContainer
	var _preview: RichTextLabel
	var _msg: Label
	# champs de la carte ouverte
	var _name: LineEdit
	var _desc: TextEdit
	var _freq: OptionButton
	var _max: SpinBox
	var _icon: LineEdit
	var _stats: DevEditor.StatEditor
	var _procs_box: VBoxContainer
	var _procs: Array = []  # [{trigger: OptionButton, effect: OptionButton, status: OptionButton, params: {k: SpinBox}}]
	var _per: Dictionary = {}  # k -> SpinBox (progression par carte commune en plus)
	var _extra := {}  # champs gardés tels quels (then, applies, requires, instant…)
	# règles
	var _rule_spins := {}

	func _ready() -> void:
		add_theme_constant_override("separation", 14)
		var left := ItemWidgets.panel(self, 330)
		ItemWidgets.section(left, "Cartes de build")
		_search = LineEdit.new()
		_search.placeholder_text = "Rechercher…"
		_search.text_changed.connect(func(_t): refresh())
		left.add_child(_search)
		DevPages.button(left, "+ Nouvelle carte", _new_card)
		_list = ItemList.new()
		_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_list.fixed_icon_size = Vector2i(26, 26)
		_list.item_selected.connect(func(i): _open(String(_ids[i])))
		left.add_child(_list)
		var mid := ItemWidgets.panel(self, 0, true)
		var sc := ScrollContainer.new()
		sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
		sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		mid.add_child(sc)
		_form = VBoxContainer.new()
		_form.add_theme_constant_override("separation", 8)
		_form.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sc.add_child(_form)
		_msg = Hud._label(mid, "", 14, UiTheme.BUFF)
		var right := ItemWidgets.panel(self, 400)
		ItemWidgets.section(right, "Aperçu de la carte")
		_preview = ItemWidgets.rich(right, 14)

	func refresh() -> void:
		if not is_inside_tree():
			return
		_list.clear()
		_ids = [""]
		_list.add_item("⚙ Raretés et améliorations de sort")
		var q := _search.text.strip_edges().to_lower()
		for d in Boons.all():
			if q != "" and not String(d.name).to_lower().contains(q):
				continue
			_ids.append(String(d.id))
			var edited: bool = DevEdits.data.cards.has(String(d.id))
			_list.add_item("%s%s · %s" % ["★ " if edited else "", d.name, String(Boons.RARITY.get(String(d.get("rarity", "common")), Boons.RARITY.common).name).to_lower()],
				UiTheme.texture(String(d.get("icon", Boons.ICONS.get(String(d.id), "")))))
		if _form.get_child_count() == 0:
			_open("")

	# --- carte -------------------------------------------------------------------------------
	func _new_card() -> void:
		var n := 1
		while not Boons.get_def("u%d" % n).is_empty():
			n += 1
		var id := "u%d" % n
		DevEdits.data.cards[id] = {"custom": true, "name": "Nouvelle carte", "desc": "", "rarity": "common", "max": 10, "stat": {"dmg_pct": 0.05}}
		_msg.text = DevEdits.save()
		Boons.reset_cache()
		refresh()
		_open(id)

	func _open(id: String) -> void:
		_id = id
		for c in _form.get_children():
			c.free()
		if id == "":
			_open_rules()
			return
		var d := Boons.get_def(id)
		ItemWidgets.section(_form, "Carte « %s »%s" % [d.get("name", id), " (créée en jeu)" if d.get("custom", false) else ""], 18)
		_name = LineEdit.new()
		_name.text = String(d.get("name", ""))
		_name.text_changed.connect(func(_t): _update_preview())
		DevEditor.row(_form, "Nom", _name)
		_desc = TextEdit.new()
		_desc.text = String(d.get("desc", ""))
		_desc.custom_minimum_size = Vector2(0, 70)
		_desc.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
		_desc.text_changed.connect(_update_preview)
		DevEditor.row(_form, "Description", _desc)
		_freq = OptionButton.new()
		_freq.focus_mode = Control.FOCUS_NONE
		for k in Boons.RARITY:
			_freq.add_item("%s (poids %s)" % [Boons.RARITY[k].name, Boons.RARITY[k].weight])
			_freq.set_item_metadata(_freq.item_count - 1, String(k))
			if String(k) == String(d.get("rarity", "common")):
				_freq.select(_freq.item_count - 1)
		DevEditor.row(_form, "Fréquence de la carte", _freq)
		_max = DevEditor.spin(1, 99 if d.get("instant", false) else Cards.MAX_LEVEL, 1, int(d.get("max", 10)))
		_max.value_changed.connect(func(_v): _update_preview())
		DevEditor.row(_form, "Niveaux max", _max)
		_icon = LineEdit.new()
		_icon.text = String(d.get("icon", Boons.ICONS.get(id, "")))
		_icon.placeholder_text = "res://assets/ui/status/…png"
		DevEditor.row(_form, "Icône", _icon)
		ItemWidgets.section(_form, "Stats par carte commune (× la rareté tirée, cumulées à chaque niveau)", 16)
		_stats = DevEditor.StatEditor.new(false, DevCards.card_stats())
		_stats.set_values(d.get("stat", {}))
		_stats.changed.connect(_update_preview)
		_form.add_child(_stats)
		ItemWidgets.section(_form, "Effets déclenchés", 16)
		_procs_box = VBoxContainer.new()
		_procs_box.add_theme_constant_override("separation", 10)
		_form.add_child(_procs_box)
		_procs = []
		for p in d.get("procs", []):
			_add_proc(p)
		DevPages.button(_form, "+ Ajouter un effet déclenché", func():
			_add_proc({"trigger": "hit", "chance": 0.1, "cd": 3.0, "effect": "explosion", "mult": 1.0, "radius": 3.0})
			_update_preview())
		ItemWidgets.section(_form, "Progression des effets par carte commune en plus (0 : inchangé)", 16)
		var per: Dictionary = d.get("per_stack", {})
		_per = {}
		var grid := GridContainer.new()
		grid.columns = 2
		_form.add_child(grid)
		for prm in DevCards.PARAMS:
			var pct: bool = prm[2] == "%"
			var sp := DevEditor.spin(-1000.0, 1000.0, float(prm[5]) * (1.0 if pct else 0.1), float(per.get(prm[0], 0.0)) * (100.0 if pct else 1.0), 120.0)
			sp.suffix = "%" if pct else ""
			sp.value_changed.connect(func(_v): _update_preview())
			DevEditor.row(grid, String(prm[1]), sp, 150)
			_per[prm[0]] = sp
		_extra = {}
		for k in ["requires", "instant", "custom"]:
			if d.has(k):
				_extra[k] = d[k]
		var bar := HBoxContainer.new()
		bar.add_theme_constant_override("separation", 10)
		_form.add_child(bar)
		DevPages.button(bar, "Enregistrer", _save, 160)
		if not d.get("custom", false):
			DevPages.button(bar, "Rétablir l'original", _reset, 200)
		DevPages.button(bar, "Supprimer la carte", _delete, 200)
		_update_preview()

	func _add_proc(p: Dictionary) -> void:
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 4)
		_procs_box.add_child(box)
		var head := HBoxContainer.new()
		head.add_theme_constant_override("separation", 8)
		box.add_child(head)
		var trig := OptionButton.new()
		trig.focus_mode = Control.FOCUS_NONE
		for k in Procs.TRIGGER_TEXT:
			trig.add_item(String(Procs.TRIGGER_TEXT[k]))
			trig.set_item_metadata(trig.item_count - 1, String(k))
			if String(k) == String(p.get("trigger", "hit")):
				trig.select(trig.item_count - 1)
		head.add_child(trig)
		var eff := OptionButton.new()
		eff.focus_mode = Control.FOCUS_NONE
		for k in DevCards.EFFECTS:
			eff.add_item(String(k))
			if k == String(p.get("effect", "explosion")):
				eff.select(eff.item_count - 1)
		head.add_child(eff)
		var st := OptionButton.new()
		st.focus_mode = Control.FOCUS_NONE
		for k in DevCards.BUFFS:
			st.add_item(String(Combatant.STATUS_INFO.get(k, {"name": k}).name))
			st.set_item_metadata(st.item_count - 1, String(k))
			if k == String(p.get("status", "")):
				st.select(st.item_count - 1)
		st.tooltip_text = "Buff donné (effet « buff »)"
		head.add_child(st)
		var entry := {"box": box, "trigger": trig, "effect": eff, "status": st, "params": {}, "keep": {}}
		var x := Button.new()
		x.text = "✕"
		x.focus_mode = Control.FOCUS_NONE
		x.pressed.connect(func():
			_procs.erase(entry)
			box.queue_free()
			_update_preview.call_deferred())
		head.add_child(x)
		var grid := GridContainer.new()
		grid.columns = 4
		box.add_child(grid)
		for prm in DevCards.PARAMS:
			var pct: bool = prm[2] == "%"
			var l := Hud._label(grid, String(prm[1]), 13, UiTheme.TEXT)
			l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			var sp := DevEditor.spin(float(prm[3]), float(prm[4]), float(prm[5]), float(p.get(prm[0], 0.0)) * (100.0 if pct else 1.0), 100.0)
			sp.suffix = "%" if pct else ""
			sp.value_changed.connect(func(_v): _update_preview())
			grid.add_child(sp)
			entry.params[prm[0]] = sp
		for k in ["then", "applies", "if_status"]:
			if p.has(k):
				entry.keep[k] = p[k]
		for o in [trig, eff, st]:
			o.item_selected.connect(func(_i): _update_preview())
		_procs.append(entry)

	## Définition de la carte d'après le formulaire.
	func _def() -> Dictionary:
		var d := {"name": _name.text.strip_edges(), "desc": _desc.text.strip_edges(), "rarity": String(_freq.get_item_metadata(_freq.selected)),
			"max": int(_max.value), "stat": _stats.get_values()}
		if _icon.text.strip_edges() != "":
			d["icon"] = _icon.text.strip_edges()
		var procs: Array = []
		for e in _procs:
			if not is_instance_valid(e.box):
				continue
			var p := {"trigger": String(e.trigger.get_item_metadata(e.trigger.selected)), "effect": String(DevCards.EFFECTS[e.effect.selected])}
			if p.effect == "buff":
				p["status"] = String(e.status.get_item_metadata(e.status.selected))
			for prm in DevCards.PARAMS:
				var v := float(e.params[prm[0]].value) / (100.0 if prm[2] == "%" else 1.0)
				if absf(v) > 0.00001 or prm[0] == "cd":
					p[prm[0]] = v
			if not p.has("chance"):
				p["chance"] = 1.0
			for k in e.keep:
				p[k] = e.keep[k]
			procs.append(p)
		d["procs"] = procs
		var per := {}
		for k in _per:
			var v := float(_per[k].value) / (100.0 if k in ["chance", "mult"] else 1.0)
			if absf(v) > 0.00001:
				per[k] = v
		d["per_stack"] = per
		for k in _extra:
			d[k] = _extra[k]
		return d

	func _save() -> void:
		var d := _def()
		if d.name == "":
			_msg.text = "Donne un nom à la carte."
			return
		DevEdits.data.cards[_id] = d
		_msg.text = DevEdits.save()
		Boons.reset_cache()
		refresh()

	func _reset() -> void:
		DevEdits.data.cards.erase(_id)
		_msg.text = DevEdits.save()
		Boons.reset_cache()
		refresh()
		_open(_id)

	func _delete() -> void:
		if Boons.get_base(_id).is_empty():
			DevEdits.data.cards.erase(_id)
		else:
			DevEdits.data.cards[_id] = {"deleted": true}
		_msg.text = DevEdits.save() + " Carte supprimée (Rétablir : recréer la carte d'origine depuis le fichier)."
		Boons.reset_cache()
		_id = ""
		refresh()
		_open("")

	func _update_preview() -> void:
		if _id == "" or _name == null:
			return
		var d := _def()
		d["id"] = _id
		var lines: PackedStringArray = ["[b]%s[/b]" % d.name, "[color=#c8c8d4]%s[/color]" % d.desc, ""]
		for t in ["common", "rare", "epic", "legendary"]:
			var m := Cards.tier_mult(t)
			var tl := Cards.stat_lines(d, 0.0, m)
			tl.append_array(Cards.proc_lines(d, 0.0, m))
			lines.append("[color=#%s]Niveau 1 · %s (×%s) :[/color] %s" % [Cards.tier(t).color.to_html(false), Cards.tier(t).name, m, " ; ".join(tl)])
		lines.append("")
		for n in [2, 5, int(d.max)]:
			var tl := Cards.stat_lines(d, float(n - 1), float(n))
			tl.append_array(Cards.proc_lines(d, float(n - 1), float(n)))
			lines.append("[color=#9fd0ff]Niveau %d → %d (cartes communes) :[/color] %s" % [n - 1, n, " ; ".join(tl)])
		for p in Boons.procs_of(d, 1.0):
			lines.append("[color=#ffd76a]%s[/color]" % Procs.describe(p))
		_preview.text = "\n".join(lines)

	# --- règles ------------------------------------------------------------------------------
	func _open_rules() -> void:
		ItemWidgets.section(_form, "Raretés tirées à chaque carte proposée", 18)
		Hud._label(_form, "Multiplicateur : ce qu'apporte la carte (stats et progression des effets) par rapport à une carte commune. Poids : fréquence du tirage.", 13, UiTheme.MUTED).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_rule_spins = {}
		for t in Cards.TIER_ORDER:
			var tr := Cards.tier(t)
			var h := HBoxContainer.new()
			h.add_theme_constant_override("separation", 10)
			_form.add_child(h)
			var l := Hud._label(h, String(tr.name), 16, tr.color)
			l.custom_minimum_size = Vector2(130, 0)
			Hud._label(h, "multiplicateur", 13, UiTheme.TEXT)
			var m := DevEditor.spin(0.1, 20.0, 0.1, float(tr.mult), 100.0)
			h.add_child(m)
			Hud._label(h, "poids", 13, UiTheme.TEXT)
			var w := DevEditor.spin(0.0, 1000.0, 1.0, float(tr.weight), 100.0)
			h.add_child(w)
			_rule_spins["tier_" + t] = [m, w]
		ItemWidgets.section(_form, "Améliorations de sort (par carte commune, × la rareté)", 18)
		var r := Cards.rules()
		for k in [["dmg", "Dégâts (sorts d'attaque)", true], ["heal", "Soins (sorts de soin)", true], ["duration", "Durée des effets (sorts de buff)", true],
				["cd", "Réduction de recharge", true], ["max_rank", "Rang max d'un sort", false], ["rider_chance", "Chances d'un bonus d'attribut (rare et mieux)", true],
				["rider_pct", "Bonus d'attribut au lancement", true], ["rider_duration", "Durée du bonus d'attribut (s)", false]]:
			var pct: bool = k[2]
			var sp := DevEditor.spin(0.0, 1000.0, 0.5 if pct else 1.0, float(r[k[0]]) * (100.0 if pct else 1.0), 120.0)
			sp.suffix = "%" if pct else ""
			DevEditor.row(_form, String(k[1]), sp, 330)
			_rule_spins[k[0]] = [sp, pct]
		var bar := HBoxContainer.new()
		bar.add_theme_constant_override("separation", 10)
		_form.add_child(bar)
		DevPages.button(bar, "Enregistrer les règles", _save_rules, 220)
		DevPages.button(bar, "Valeurs d'origine", func():
			DevEdits.data.card_rules = {}
			_msg.text = DevEdits.save()
			_open(""), 200)
		_preview.text = "[b]Exemple[/b]\nLame large (+15 % de rayon par carte commune) :\n" + "\n".join(PackedStringArray(Cards.TIER_ORDER.map(func(t):
			return "%s : +%s %%" % [Cards.tier(t).name, Cards._num(15.0 * Cards.tier_mult(t))])))

	func _save_rules() -> void:
		var tiers := {}
		for t in Cards.TIER_ORDER:
			var pair: Array = _rule_spins["tier_" + t]
			tiers[t] = {"mult": float(pair[0].value), "weight": float(pair[1].value)}
		var skill := {}
		for k in _rule_spins:
			if String(k).begins_with("tier_"):
				continue
			var pair: Array = _rule_spins[k]
			skill[k] = float(pair[0].value) / (100.0 if pair[1] else 1.0)
		DevEdits.data.card_rules = {"tiers": tiers, "skill": skill}
		_msg.text = DevEdits.save()
		_open("")
