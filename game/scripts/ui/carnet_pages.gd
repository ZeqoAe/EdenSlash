class_name CarnetPages
extends RefCounted
## Pages du Carnet (lot 11) : vue d'ensemble de la complétion, succès et titres, grimoire des
## cartes, codex des trophées. La Collection (archive des trésors) reste la page d'avant.


## Contenu défilant reconstruit à chaque ouverture.
class ScrollPage extends VBoxContainer:
	var _box: VBoxContainer

	func _init() -> void:
		var panel := ItemWidgets.panel(self, 0, true)
		var sc := ScrollContainer.new()
		sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
		sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		panel.add_child(sc)
		_box = VBoxContainer.new()
		_box.add_theme_constant_override("separation", 8)
		_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sc.add_child(_box)

	func clear() -> void:
		for c in _box.get_children():
			c.queue_free()

	func bar(label: String, got: int, total: int, detail := "") -> void:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		_box.add_child(row)
		var n := Hud._label(row, label, 17, UiTheme.TEXT)
		n.custom_minimum_size = Vector2(190, 0)
		var pb := ProgressBar.new()
		pb.max_value = maxf(total, 1)
		pb.value = got
		pb.show_percentage = false
		pb.custom_minimum_size = Vector2(380, 22)
		pb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(pb)
		var c := Hud._label(row, "%d / %d" % [got, total], 16, UiTheme.GOLD)
		c.custom_minimum_size = Vector2(110, 0)
		if detail != "":
			var d := Hud._label(row, detail, 13, UiTheme.MUTED)
			d.size_flags_horizontal = Control.SIZE_EXPAND_FILL


## Vue d'ensemble : les dix catégories et le pourcentage global.
class OverviewPage extends ScrollPage:
	func refresh() -> void:
		Achievements.refresh()
		clear()
		var t := Hud._label(_box, "Complétion : %d %%" % Completion.percent(), 28, UiTheme.GOLD)
		t.add_theme_font_override("font", UiTheme.title_font())
		Hud._label(_box, "Rien de ce qui est compté ici ne donne de la puissance : c'est la vue d'ensemble de ta sauvegarde.", 14, UiTheme.MUTED)
		for c in Completion.categories():
			bar(String(c[0]), int(c[1]), int(c[2]), String(c[3]))
		Hud._label(_box, "Déblocages", 20, UiTheme.GOLD).add_theme_font_override("font", UiTheme.bold_font())
		for id in Unlocks.LIST:
			var open := Unlocks.is_open(id)
			var l := Hud._label(_box, "%s %s%s" % ["✔" if open else "🔒", Unlocks.name_of(id), "" if open else "  —  " + Unlocks.condition(id)], 15,
				Color(0.55, 1.0, 0.6) if open else UiTheme.MUTED)
			l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


## Succès : obtenus en doré avec leur date, les autres avec leur progression ; titres à porter.
class AchievementsPage extends ScrollPage:
	func refresh() -> void:
		Achievements.refresh()
		clear()
		var cnt := Achievements.count()
		Hud._label(_box, "Succès : %d / %d" % [int(cnt.x), int(cnt.y)], 26, UiTheme.GOLD).add_theme_font_override("font", UiTheme.title_font())
		Hud._label(_box, "Accordés pour le passé, sans aucune statistique. Titre porté : %s" % (Profile.title if Profile.title != "" else "aucun"), 14, UiTheme.MUTED)
		var tb := HFlowContainer.new()
		tb.add_theme_constant_override("h_separation", 8)
		_box.add_child(tb)
		var none := MenuWidgets.glass_button("Aucun titre", 14, Vector2(0, 34))
		none.pressed.connect(func():
			Profile.title = ""
			Profile.save_profile()
			refresh())
		tb.add_child(none)
		for t in Achievements.titles():
			var b := MenuWidgets.glass_button(String(t) + ("  ✔" if t == Profile.title else ""), 14, Vector2(0, 34))
			var tt: String = t
			b.pressed.connect(func():
				Profile.title = tt
				Profile.save_profile()
				refresh())
			tb.add_child(b)
		for a in Achievements.LIST:
			var own := Achievements.owned(a.id)
			var p := Achievements.progress(a)
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 10)
			_box.add_child(row)
			Hud._label(row, "★" if own else "☆", 20, UiTheme.GOLD if own else UiTheme.MUTED)
			var v := VBoxContainer.new()
			v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			v.add_theme_constant_override("separation", 0)
			row.add_child(v)
			Hud._label(v, String(a.name) + (("  ·  titre « %s »" % a.title) if String(a.title) != "" else ""), 16, UiTheme.GOLD if own else UiTheme.TEXT)
			Hud._label(v, "%s%s" % [a.desc, ("  (obtenu le %s)" % Profile.achievements[a.id]) if own else "  (%d / %d)" % [int(p.x), int(p.y)]], 13, UiTheme.MUTED)


## Grimoire des cartes : chaque carte débloquée ou sa condition.
class CardsPage extends ScrollPage:
	func refresh() -> void:
		clear()
		Hud._label(_box, "Grimoire des cartes : %d / %d" % [Completion.cards_done(), Completion.cards_total()], 26, UiTheme.GOLD).add_theme_font_override("font", UiTheme.title_font())
		var shown: Array = Boons.all().duplicate()
		shown.sort_custom(func(a, b): return int(Cards.card_unlocked(String(a.id))) > int(Cards.card_unlocked(String(b.id))))
		for b in shown:
			var id := String(b.id)
			var open := Cards.card_unlocked(id)
			var rar: Dictionary = Boons.RARITY.get(String(b.get("rarity", "common")), {"name": "", "color": Color.WHITE})
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 10)
			_box.add_child(row)
			Hud._label(row, "✔" if open else "🔒", 16, Color(0.55, 1.0, 0.6) if open else UiTheme.MUTED)
			var v := VBoxContainer.new()
			v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			v.add_theme_constant_override("separation", 0)
			row.add_child(v)
			Hud._label(v, "%s  (%s)" % [b.name, rar.get("name", "")], 16, rar.get("color", Color.WHITE) if open else UiTheme.MUTED)
			var d := Hud._label(v, String(b.get("desc", "")) if open else "Pour l'ouvrir : " + Cards.unlock_text(id), 13, UiTheme.MUTED)
			d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


## Codex des trophées : les effets découverts en run.
class TrophiesPage extends ScrollPage:
	func refresh() -> void:
		clear()
		Hud._label(_box, "Codex des trophées : %d / %d" % [Profile.seen_trophies.size(), Trophies.KINDS.size()], 26, UiTheme.GOLD).add_theme_font_override("font", UiTheme.title_font())
		Hud._label(_box, "Un effet se découvre en le ramassant en run (coffres de trophée, sanctuaires). 12 trophées au plus par run, tous différents.", 14, UiTheme.MUTED)
		for k in Trophies.KINDS:
			var seen: bool = k in Profile.seen_trophies
			var info: Dictionary = Trophies.KINDS[k]
			var l := Hud._label(_box, ("✔ %s  —  %s" % [info.get("name", k), Trophies.describe(info)]) if seen else "🔒 ???  —  à découvrir", 14,
				UiTheme.TEXT if seen else UiTheme.MUTED)
			l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
