class_name SpellInfo
extends RefCounted
## Infobulles détaillées « à la Eden » générées depuis les vraies valeurs du jeu :
## compétences (dégâts, type, critique, effets et durées, rangs 1 à 5), coups du combo
## d'auto-attaque, passifs et statistiques de base des classes.

const C_DMG := "#ffcf6b"
const C_PHYS := "#ff9a6b"
const C_MAG := "#8fb6ff"
const C_BUFF := "#7fe08a"
const C_DEBUFF := "#ff7a7a"
const C_MUTED := "#b8b4c8"
const C_CRIT := "#ffe066"

const KINDS := {
	"dash": "Charge", "spin": "Zone autour de soi", "cone": "Cône", "fan": "Éventail", "flurry": "Rafale",
	"line": "Ligne", "buff": "Renforcement", "bolt": "Projectile", "ground": "Zone ciblée", "heal": "Soin",
	"blink": "Téléportation",
}
const PASSIVE_STATS := {
	"atk_pct": "d'attaque", "hp_pct": "de PV max", "reach": "de portée", "area": "de zone d'effet",
	"crit": "de chances de critique", "crit_dmg": "de dégâts critiques", "atk_speed": "de vitesse d'attaque",
	"move_speed": "de vitesse de déplacement", "cdr": "de réduction des recharges", "lifesteal": "de vol de vie",
}


static func _c(color: String, text: String) -> String:
	return "[color=%s]%s[/color]" % [color, text]


static func pct(v: float) -> String:
	return "%d %%" % roundi(v * 100.0)


static func _secs(v: float) -> String:
	return ("%d s" % roundi(v)) if absf(v - roundf(v)) < 0.05 else ("%.1f s" % v).replace(".", ",")


static func dmg_type_label(t: String) -> String:
	return _c(C_MAG, "Magique") if t == "mag" else _c(C_PHYS, "Physique")


## Ligne d'un effet d'état : nom coloré, durée, description.
static func status_line(st: String, dur: float, on_self := false) -> String:
	var col := C_BUFF if (on_self or StatusDb.is_buff(st)) else C_DEBUFF
	return "%s %s (%s) : %s" % ["Sur toi :" if on_self else "Applique", _c(col, StatusDb.display_name(st)), _secs(dur), StatusDb.DESC.get(st, "")]


# --- compétences -----------------------------------------------------------------------
static func skill_rank_mult(rank: int) -> float:
	return 1.0 + 0.2 * (rank - 1)


static func skill_cd_mult(rank: int) -> float:
	return 1.0 - 0.08 * (rank - 1)


## Infobulle complète d'une compétence au rang [param rank] ; [param atk] > 0 : valeur chiffrée.
static func skill_bbcode(s: Dictionary, rank := 1, atk := -1.0) -> String:
	var kind := String(s.get("kind", ""))
	var lines: PackedStringArray = []
	lines.append("[font_size=22][b]%s[/b][/font_size]   %s" % [s.get("name", "?"), _c(C_MUTED, "Rang %d / %d" % [rank, Run.MAX_RANK])])
	var head: PackedStringArray = [KINDS.get(kind, kind)]
	if float(s.get("mult", 0.0)) > 0.0:
		head.append(dmg_type_label(String(s.get("dmg_type", "phys"))))
	head.append("Recharge %s" % _secs(float(s.cooldown) * skill_cd_mult(rank)))
	if float(s.get("range", 0.0)) > 0.0:
		head.append("Portée %s m" % _num(float(s.range)))
	if float(s.get("radius", 0.0)) > 0.0 and kind != "bolt":
		head.append(("Zone %s m" % _num(float(s.radius))) + ("" if float(s.get("arc", 360)) >= 360 or kind in ["ground", "blink", "spin"] else " · %d°" % int(s.arc)))
	lines.append(_c(C_MUTED, " · ".join(head)))
	lines.append("")
	lines.append("[i]%s[/i]" % String(s.get("desc", "")))
	lines.append("")
	lines.append("[b]Effets[/b]")
	lines.append_array(_effect_lines(s, skill_rank_mult(rank), atk))
	lines.append("")
	lines.append("[b]Amélioration (cartes de niveau)[/b]  " + _c(C_MUTED, "+20 % de dégâts et -8 % de recharge par rang"))
	var table: PackedStringArray = []
	for r in range(1, Run.MAX_RANK + 1):
		var parts: PackedStringArray = []
		if float(s.get("mult", 0.0)) > 0.0:
			parts.append(pct(float(s.mult) * skill_rank_mult(r)))
		parts.append(_secs(float(s.cooldown) * skill_cd_mult(r)))
		var txt := "R%d : %s" % [r, " · ".join(parts)]
		table.append(("[b]%s[/b]" % _c(C_DMG, txt)) if r == rank else _c(C_MUTED, txt))
	lines.append("   ".join(table))
	if s.has("eden_name"):
		lines.append("")
		lines.append(_c(C_MUTED, "Eden Eternal : « %s »" % s.eden_name))
	return "\n".join(lines)


## Lignes d'effets communes aux compétences et aux coups du combo.
static func _effect_lines(s: Dictionary, mult_k: float, atk: float) -> PackedStringArray:
	var out: PackedStringArray = []
	var mult := float(s.get("mult", 0.0)) * mult_k
	var t := String(s.get("dmg_type", "phys"))
	if mult > 0.0:
		var n := maxi(int(s.get("hits", 1)), 1)
		var v := maxi(int(s.get("volley", 1)), 1)
		var txt := "• Dégâts : %s de l'attaque en dégâts %s" % [_c(C_DMG, "[b]%s[/b]" % pct(mult)), "magiques" if t == "mag" else "physiques"]
		if atk > 0.0:
			txt += _c(C_MUTED, " (≈ %d)" % roundi(atk * mult))
		if n > 1:
			txt += ", %s" % _c(C_DMG, "%d coups" % n)
		if v > 1:
			txt += ", %s" % _c(C_DMG, "%d projectiles" % v)
		out.append(txt)
	if int(s.get("max_targets", 0)) > 0:
		out.append("• Cibles : les %d ennemis les plus proches" % int(s.max_targets))
	elif String(s.get("kind", "")) != "bolt" and float(s.get("radius", 0.0)) > 0.0:
		out.append("• Cibles : tous les ennemis de la zone")
	if int(s.get("pierce", 0)) > 0:
		out.append("• Perforation : traverse %s" % ("toute la ligne" if int(s.pierce) >= 99 else "%d cible%s" % [int(s.pierce), "s" if int(s.pierce) > 1 else ""]))
	if float(s.get("crit_bonus", 0.0)) > 0.0:
		out.append("• %s : +%s de chances de coup critique" % [_c(C_CRIT, "Critique"), pct(float(s.crit_bonus))])
	if float(s.get("dash", 0.0)) > 0.0:
		out.append("• Élan : fonce de %s m avant l'impact" % _num(float(s.dash)))
	if float(s.get("move", 0.0)) > 0.0:
		out.append("• Déplacement : %s m %s" % [_num(float(s.move)), "(repli)" if s.get("move_dir", "") == "evade" else "vers l'avant"])
	if String(s.get("kind", "")) == "blink":
		out.append("• Téléportation : jusqu'à %s m (sans traverser les murs)" % _num(float(s.get("range", 0.0))))
	if float(s.get("pull", 0.0)) > 0.0:
		out.append("• Attraction : ramène les ennemis de %s m %s" % [_num(float(s.pull)), "vers le centre" if String(s.get("kind", "")) == "ground" else "vers toi"])
	if s.get("land_hit", false):
		out.append("• Salto : l'impact se produit à la retombée")
	if float(s.get("heal", 0.0)) > 0.0:
		out.append("• %s : rend %s des PV max" % [_c(C_BUFF, "Soin"), pct(float(s.heal))])
	for st in s.get("applies", {}):
		out.append("• " + status_line(st, float(s.applies[st])))
	for st in s.get("buff", {}):
		out.append("• " + status_line(st, float(s.buff[st]), true))
	for st in s.get("self_status", {}):
		out.append("• " + status_line(st, float(s.self_status[st]), true))
	var combo: Dictionary = s.get("combo", {})
	if not combo.is_empty():
		var req := StatusDb.display_name(String(combo.get("requires", "")))
		var bits: PackedStringArray = []
		if combo.get("double", false):
			bits.append(_c(C_DMG, "dégâts doublés"))
		for st in combo.get("applies", {}):
			bits.append("%s (%s)" % [_c(C_DEBUFF, StatusDb.display_name(st)), _secs(float(combo.applies[st]))])
		for st in combo.get("buff", {}):
			bits.append("%s sur toi (%s)" % [_c(C_BUFF, StatusDb.display_name(st)), _secs(float(combo.buff[st]))])
		out.append("• [b]Combo[/b] — sur une cible en %s : %s" % [_c(C_DEBUFF, req), ", ".join(bits)])
	return out


# --- combo d'auto-attaque ------------------------------------------------------------------
static func combo_step_bbcode(step: Dictionary, index: int, cls: Dictionary, atk := -1.0) -> String:
	var s := step.duplicate()
	s["dmg_type"] = cls.get("dmg_type", "phys")
	if step.get("bolt", false):
		s["kind"] = "bolt"
		s["range"] = cls.get("attack_range", 13.0)
	elif not step.has("kind") and not step.has("radius"):
		s["radius"] = 2.6
	var lines: PackedStringArray = []
	lines.append("[font_size=18][b]%d · %s[/b][/font_size]%s" % [index + 1, step.get("name", "Coup %d" % (index + 1)),
		_c(C_CRIT, "   COUP FINAL") if step.get("finisher", false) else ""])
	var head: PackedStringArray = []
	var kind := String(s.get("kind", ""))
	if kind == "bolt":
		head.append("Tir · %s m" % _num(float(s.range)))
	elif kind == "ground":
		head.append("Zone ciblée · %s m, rayon %s m" % [_num(float(step.get("range", 0.0))), _num(float(step.radius))])
	elif kind == "heal":
		head.append("Soin")
	elif float(s.get("radius", 0.0)) > 0.0:
		head.append(("Autour de soi" if float(s.get("arc", 150)) >= 360 else "Devant · %d°" % int(s.get("arc", 150))) + ", %s m" % _num(float(s.radius)))
	lines.append(_c(C_MUTED, " · ".join(head)))
	if step.has("desc"):
		lines.append("[i]%s[/i]" % step.desc)
	lines.append_array(_effect_lines(s, 1.0, atk))
	if step.get("finisher", false):
		lines.append(_c(C_MUTED, "Le coup final profite des cartes « coup final » (dégâts, zone, coups supplémentaires)."))
	return "\n".join(lines)


# --- passifs et classe ----------------------------------------------------------------------
static func passive_bbcode(p: Dictionary) -> String:
	var lines: PackedStringArray = ["[b]%s[/b]%s" % [p.name, _c(C_MUTED, "   cumulable ×%d" % int(p.max)) if int(p.get("max", 1)) > 1 else ""]]
	var st: Dictionary = p.get("stat", {})
	for k in st:
		lines.append(_c(C_BUFF, "+%s %s" % [pct(float(st[k])), PASSIVE_STATS.get(k, k)]) + (_c(C_MUTED, " par carte") if int(p.get("max", 1)) > 1 else ""))
	if st.is_empty():
		lines.append(String(p.get("desc", "")))
	return "\n".join(lines)


## Statistiques de base de la classe (multiplicateurs appliqués au héros).
static func class_stats_bbcode(cls: Dictionary) -> String:
	var b: Dictionary = cls.get("base", {})
	var rows: PackedStringArray = []
	rows.append("Type de dégâts : %s" % dmg_type_label(String(cls.get("dmg_type", "phys"))))
	rows.append("Attaque de base : %s" % ("à distance, %s m" % _num(float(cls.attack_range)) if cls.has("attack_range") else "corps à corps"))
	rows.append("PV : %s" % _mod(float(b.get("hp", 1.0))))
	rows.append("Attaque physique : %s" % _mod(float(b.get("atk", 1.0))))
	rows.append("Attaque magique : %s" % _mod(float(b.get("matk", 0.5)) * 2.0))
	if float(b.get("def", 0.0)) > 0.0:
		rows.append("Défense : " + _c(C_BUFF, "+%d" % int(b.def)))
	if float(b.get("crit", 0.0)) > 0.0:
		rows.append("Critique : " + _c(C_BUFF, "+%s" % pct(float(b.crit))))
	if float(b.get("atk_speed", 0.0)) > 0.0:
		rows.append("Vitesse d'attaque : " + _c(C_BUFF, "+%s" % pct(float(b.atk_speed))))
	if float(b.get("move_speed", 0.0)) > 0.0:
		rows.append("Vitesse : " + _c(C_BUFF, "+%s" % pct(float(b.move_speed))))
	var at: Dictionary = cls.get("attributes", {})
	if not at.is_empty():
		rows.append("")
		rows.append("[b]Attributs[/b] " + _c(C_MUTED, "(niveau 1, + par niveau)"))
		var names := {"str": "Force", "agi": "Agilité", "int": "Intelligence", "wis": "Sagesse", "lck": "Chance"}
		for a in ["str", "agi", "int", "wis", "lck"]:
			rows.append("%s : [b]%d[/b] %s" % [names[a], int(at.base.get(a, 0)), _c(C_BUFF, "+%s" % _num(float(at.growth.get(a, 0))))])
		rows.append(_c(C_MUTED, "Force : attaque physique, PV, parade · Agilité : vitesses, esquive · Intelligence : attaque magique · Sagesse : PV, soins, critique magique · Chance : critiques"))
	return "\n".join(rows)


static func _mod(k: float) -> String:
	if absf(k - 1.0) < 0.001:
		return "normal"
	return _c(C_BUFF if k > 1.0 else C_DEBUFF, "%s%s" % ["+" if k > 1.0 else "", pct(k - 1.0)])


static func _num(v: float) -> String:
	return str(int(v)) if absf(v - roundf(v)) < 0.01 else ("%.1f" % v).replace(".", ",")
