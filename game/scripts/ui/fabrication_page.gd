class_name FabricationPage
extends VBoxContainer
## Atelier > Fabrication : chaque plan trouvé dans un donjon (Profile.plans, « plan_<zone> ») permet de
## fabriquer, contre des cristaux, une pièce de la panoplie de ce donjon (son archétype : Dungeons.ARCHETYPES) à
## l'emplacement voulu. Le plan n'est pas consommé. Niveau et rareté suivent la meilleure difficulté terminée :
## mythique, légendaire une fois le donjon fini en Mythique.

const SLOTS := ["head", "chest", "legs", "gloves", "boots", "back"]
const COST := 60  # cristaux par niveau de difficulté terminé (Normal 60, Héroïque 120, Mythique 180)

var _list: VBoxContainer
var _msg: Label
var _wallet: Label


## Difficulté la plus haute terminée du donjon [param zid] (-1 : jamais terminé).
static func best_diff(zid: String) -> int:
	var best := -1
	for d in Dungeons.DIFF_NAMES.size():
		if Dungeons.cleared(zid, d) > 0:
			best = d
	return best


## Zones dont tu as le plan.
static func known() -> Array:
	var out: Array = []
	for zid in Dungeons.zone_ids():
		if ("plan_" + String(zid)) in Profile.plans:
			out.append(zid)
	return out


static func cost(zid: String) -> int:
	return COST * (maxi(best_diff(zid), 0) + 1)


## Fabrique une pièce de la panoplie de [param zid] à l'emplacement [param slot] ; {} si le plan manque, si les
## cristaux ne suffisent pas ou si l'inventaire est plein ("error" donne la raison).
static func craft(zid: String, slot: String) -> Dictionary:
	if not ("plan_" + zid) in Profile.plans:
		return {"error": "Tu n'as pas le plan de ce donjon."}
	if not slot in SLOTS:
		return {"error": "Emplacement inconnu."}
	var c := cost(zid)
	if Profile.amount("crystal") < c:
		return {"error": "Il te faut %d cristaux." % c}
	if Profile.inventory.size() >= Profile.INVENTORY_MAX:
		return {"error": "Inventaire plein."}
	var d := maxi(best_diff(zid), 0)
	var rar := Items.LEGENDARY if d >= 2 else Items.MYTHIC
	var it := Items.generate(Dungeons.level(zid, d), 1.0, slot, Profile.selected_class, rar, "", rar)
	it["archetype"] = Dungeons.archetype(zid)
	Profile.materials["crystal"] = Profile.amount("crystal") - c
	Profile.add_item(it)
	Profile.save_profile()
	return it


func _ready() -> void:
	add_theme_constant_override("separation", 10)
	var panel := ItemWidgets.panel(self, 0, true)
	var hh := HBoxContainer.new()
	panel.add_child(hh)
	var head := Hud._label(hh, "Fabrication", 20, UiTheme.GOLD)
	head.add_theme_font_override("font", UiTheme.title_font())
	head.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_wallet = Hud._label(hh, "", 17, Color(0.75, 0.85, 1.0))
	Hud._label(panel, "Un plan trouvé dans un donjon te laisse fabriquer, contre des cristaux, une pièce de sa panoplie à l'emplacement voulu (mythique, légendaire une fois le donjon terminé en Mythique). Le plan reste à toi.", 13, UiTheme.MUTED).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(sc)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 10)
	sc.add_child(_list)
	_msg = Hud._label(panel, "", 15, UiTheme.BUFF)


func refresh() -> void:
	if not is_inside_tree():
		return
	_wallet.text = "%d cristaux" % Profile.amount("crystal")
	for ch in _list.get_children():
		ch.queue_free()
	var zones := known()
	if zones.is_empty():
		Hud._label(_list, "Aucun plan : un donjon terminé en rapporte un une fois sur dix (le premier terminé en Héroïque ou Mythique en donne un à coup sûr).", 15, UiTheme.MUTED).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		return
	for z in zones:
		var zid := String(z)
		var arch: Dictionary = Items.SETS[Dungeons.archetype(zid)]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		_list.add_child(row)
		var t := Hud._label(row, "%s — panoplie %s" % [Dungeons.name_of(zid), arch.name], 17, Color(0.92, 0.92, 0.96))
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var ob := OptionButton.new()
		ob.focus_mode = Control.FOCUS_NONE
		for s in SLOTS:
			ob.add_item(String(Items.SLOT_NAMES.get(s, s)))
		row.add_child(ob)
		var c := cost(zid)
		var b := MenuWidgets.gold_button("Fabriquer · %d cristaux" % c, 16, Vector2(250, 40))
		b.disabled = Profile.amount("crystal") < c
		var slot_box := ob
		b.pressed.connect(func():
			var r := craft(zid, SLOTS[slot_box.selected])
			if r.has("error"):
				_msg.text = String(r.error)
			else:
				_msg.text = "Fabriqué : %s (dans ton inventaire)." % Items.display_name(r)
			refresh())
		row.add_child(b)
		Hud._label(_list, "   " + " · ".join(Items.bonus_lines(Items.set_bonus(Dungeons.archetype(zid), 2))) + " (2 pièces)  |  " + " · ".join(Items.bonus_lines(Items.set_bonus(Dungeons.archetype(zid), 4))) + " (4)", 12, UiTheme.MUTED).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
