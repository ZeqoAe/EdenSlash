class_name TowerPages
extends RefCounted
## La Tour dans le lobby : ligne d'un étage (type, ennemi, verrou) et fiche d'infos en
## fenêtre (stats de l'ennemi, sorts, résistances, équipement), lues dans Tower.spec().

const FLOORS_PER_PAGE := 5


## Titre et sous-titre de la ligne de l'étage [param f].
static func floor_line(f: int, diff: int) -> Array:
	var s := Tower.spec(f, diff)
	var what := ""
	match String(s.type):
		"duel":
			what = "Duel %d/%d : %s" % [int(s.index), Tower.duel_count(), GameData.class_data(String(s["class"])).get("name_fr", "")]
		"boss":
			what = "Boss : %s" % GameData.monster(int(s.boss)).get("name", "?")
		"elite":
			what = "%d monstres et %d élite(s)" % [int(s.count), int(s.elites)]
		_:
			what = "%d monstres" % int(s.count)
	var state := "battu" if f <= Tower.best(diff) else ("à battre" if f == Tower.best(diff) + 1 else "verrouillé")
	return ["Étage %d · %s" % [f, what], "%s · niveau %d · %s" % [s.zone.name, int(s.level), state]]


static func _pct(x: float) -> String:
	return "%+d %%" % roundi(x * 100.0)


## Réduction des dégâts subis par la défense (Combatant.take_damage : 100 déf = -50 %).
static func _def_text(def: float) -> String:
	return "Défense %d : %d %% des dégâts subis en moins" % [roundi(def), roundi(100.0 - 100.0 * 100.0 / (100.0 + maxf(def, 0.0)))]


## Fiche de l'étage en BBCode.
static func info_text(s: Dictionary) -> String:
	var f := int(s.floor)
	var lines: PackedStringArray = []
	var gold := "#%s" % UiTheme.GOLD.to_html(false)
	lines.append("[font_size=24][color=%s]Étage %d · %s[/color][/font_size]" % [gold, f, Tower.TYPE_NAMES.get(String(s.type), "")])
	lines.append("%s · niveau %d · difficulté %s" % [s.zone.name, int(s.level), Tower.DIFF_NAMES[int(s.diff)]])
	lines.append("")
	match String(s.type):
		"duel":
			lines.append_array(_duel_lines(s))
		"boss":
			lines.append_array(_boss_lines(s))
		_:
			lines.append_array(_monster_lines(s))
	lines.append("")
	lines.append("[color=#9fd0ff]Récompense : une carte, puis un coffre (son objet rejoint ton coffre commun à la fin de l'ascension).[/color]")
	return "\n".join(lines)


static func _duel_lines(s: Dictionary) -> PackedStringArray:
	var out: PackedStringArray = []
	var r := Tower.make_rival(s)
	var cd := GameData.class_data(r.cid)
	var cfg: Dictionary = r.cfg
	out.append("[font_size=20]Duel %d/%d : [b]%s[/b][/font_size]" % [int(s.index), Tower.duel_count(), cd.get("name_fr", r.cid)])
	out.append("PV [b]%s[/b] · Attaque [b]%d[/b] · Vitesse %.1f" % [Hud._big_number(r.max_hp), roundi(r.atk), r.move_speed])
	out.append("IA %s : réagit en %.2f s, lit %d %% de tes coups, %d esquive(s) d'avance (une de plus toutes les %.1f s), annonce de ses coups %.2f s" % [
		Tower.DIFF_NAMES[int(s.diff)], float(cfg.react), roundi(float(cfg.read) * 100.0), int(cfg.charges), float(cfg.recharge), float(cfg.tele)])
	out.append("")
	out.append("[color=%s][b]Résistances[/b][/color]" % ("#%s" % UiTheme.GOLD.to_html(false)))
	out.append(_def_text(r.defense))
	out.append("Contrôles : il y résiste %.0f s après chacun (comme toi), invulnérable pendant ses esquives" % Combatant.CC_IMMUNITY)
	out.append("")
	out.append("[color=#%s][b]Sorts (%d)[/b][/color]" % [UiTheme.GOLD.to_html(false), r._skills.size()])
	if r._skills.is_empty():
		out.append("Aucun : seulement le combo de son arme")
	for sk in r._skills:
		out.append("• [b]%s[/b] — %d %% de son attaque, recharge %.1f s\n   [color=#b8b8c8]%s[/color]" % [sk.get("name", "?"), roundi(float(sk.get("mult", 1.5)) * 100.0),
			float(sk.get("cooldown", 5.0)) * float(cfg.skill_cd), sk.get("desc", "")])
	var combo: Array = r.wtype.get("combo", [])
	if not combo.is_empty():
		out.append("• Combo de l'arme (%s) : %s" % [r.wtype.get("name", ""), " → ".join(combo.map(func(c): return String(c.get("name", "?"))))])
	out.append("")
	out.append("[color=#%s][b]Équipement[/b][/color]" % UiTheme.GOLD.to_html(false))
	for i in r.gear.size():
		var it: Dictionary = r.gear[i]
		var st: Dictionary = r.gear_stats[i]
		var bits: PackedStringArray = []
		for k in ["hp", "patk", "matk", "def", "crit"]:
			if float(st.get(k, 0.0)) > 0.0:
				bits.append(Items.stat_text(k, st[k]))
		out.append("• [color=#%s]%s[/color]  [color=#b8b8c8]%s[/color]" % [Items.color_of(it).to_html(false), Items.display_name(it), " · ".join(bits)])
	r.free()
	return out


static func _boss_lines(s: Dictionary) -> PackedStringArray:
	var out: PackedStringArray = []
	var st := Tower.monster_stats(int(s.boss), s, true)
	var dungeon: Dictionary = s.zone.get("dungeon", {})
	out.append("[font_size=20]Boss : [b]%s[/b][/font_size]" % st.name)
	out.append("PV [b]%s[/b] · Attaque [b]%d[/b] · niveau %d" % [Hud._big_number(st.hp), roundi(st.atk), int(st.level)])
	out.append("")
	out.append("[color=#%s][b]Résistances[/b][/color]" % UiTheme.GOLD.to_html(false))
	out.append(_def_text(float(st.def)))
	out.append("Recul : divisé par 5 · Contrôles : il y résiste %.0f s après chacun" % Combatant.CC_IMMUNITY)
	out.append("")
	out.append("[color=#%s][b]Combat[/b][/color]" % UiTheme.GOLD.to_html(false))
	if String(dungeon.get("intro", "")) != "":
		out.append(String(dungeon.intro))
	out.append("Ses attaques sont annoncées en rouge au sol. Des renforts arrivent toutes les 14 s.")
	return out


static func _monster_lines(s: Dictionary) -> PackedStringArray:
	var out: PackedStringArray = []
	out.append("[font_size=20]%d monstres à vaincre[/font_size] · %d en même temps au plus · force %s" % [int(s.count), int(s.alive),
		_pct(Tower.monster_hp_mult(int(s.floor), int(s.diff)) - 1.0)])
	if String(s.type) == "elite":
		out.append("Et %d élite(s) dès le début de l'étage" % int(s.elites))
	out.append("")
	out.append("[color=#%s][b]Monstres de la zone[/b][/color]" % UiTheme.GOLD.to_html(false))
	var ids: Array = s.zone.get("monsters", [])
	if String(s.type) == "elite":
		ids = s.zone.get("elites", []) + ids
	for id in ids.slice(0, 10):
		var st := Tower.monster_stats(int(id), s)
		out.append("• %s%s — PV %s · attaque %d · %s" % ["[color=#ffb070]★ élite[/color] " if st.elite else "", st.name, Hud._big_number(st.hp), roundi(st.atk), _def_text(float(st.def)).to_lower()])
	return out


## Fiche de l'étage en panneau par-dessus l'écran (fond assombri ; clic à côté ou Fermer).
static func info_popup(anchor: Node, s: Dictionary) -> CanvasLayer:
	var layer := CanvasLayer.new()
	layer.layer = 60
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.01, 0.05, 0.7)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed:
			layer.queue_free())
	layer.add_child(dim)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiTheme.flat_box(Color(0.05, 0.04, 0.1, 0.98), UiTheme.GOLD, 2, 12))
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(760, 680)
	panel.position = Vector2(-380, -340)
	layer.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	panel.add_child(v)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	var rt := RichTextLabel.new()
	rt.bbcode_enabled = true
	rt.fit_content = true
	rt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rt.add_theme_font_size_override("normal_font_size", 15)
	rt.add_theme_font_size_override("bold_font_size", 15)
	rt.text = info_text(s)
	scroll.add_child(rt)
	var close := Button.new()
	close.text = "Fermer"
	close.focus_mode = Control.FOCUS_NONE
	close.custom_minimum_size = Vector2(0, 40)
	close.pressed.connect(layer.queue_free)
	v.add_child(close)
	anchor.get_tree().current_scene.add_child(layer)
	return layer
