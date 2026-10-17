"""Icônes « glyph » : signes d'interface qui se posent en ligne (coche, cadenas, étoile, nouveauté…). Repère 0..128."""
from ico_kit import *  # noqa: F401,F403

G = "Signes d'interface"


def _bar(cx, cy, length, w, ang):
    return poly(xf([(-length / 2, -w / 2), (length / 2, -w / 2), (length / 2, w / 2), (-length / 2, w / 2)], cx, cy, ang))


@icon("check", "glyph", group=G, desc="coche (✔)")
def _(s):
    d = poly([(14, 70), (32, 52), (50, 70), (94, 22), (114, 40), (50, 108)])
    sticker(s, d, "pomme", 6, 0.52)
    s.gloss(poly([(24, 66), (32, 58), (40, 66), (34, 70)]), 0.0)
    s.gloss("M30 56 L50 74 L50 82 L26 62Z", 0.0)
    s.line("M34 62 L50 78", 4.5, "#FFFFFF")
    s.line("M62 70 L92 38", 4.5, "#FFFFFF")


@icon("cross", "glyph", group=G, desc="croix (✘ : refusé, manque)")
def _(s):
    d = _bar(64, 64, 104, 28, 45) + " " + _bar(64, 64, 104, 28, -45)
    sticker(s, d, "fraise", 6, 0.52)
    s.line("M34 34 L50 50", 4.5, "#FFFFFF")


@icon("lock", "glyph", group=G, desc="cadenas (fermé)")
def _(s):
    s.inked_line("M42 62 V46 A22 22 0 0 1 86 46 V62", 12, "#E4DFF0", 5.5)
    sticker(s, rrect(24, 58, 80, 56, 14), "soleil", 6, 0.5)
    s.fill(circ(64, 82, 8), INK)
    s.fill(rrect(60, 84, 8, 16, 4), INK)
    s.gloss(rrect(32, 64, 36, 7, 3.5), 0.7)


@icon("unlock", "glyph", group=G, desc="cadenas ouvert")
def _(s):
    s.inked_line("M42 62 V40 A22 22 0 0 1 86 40 V46", 12, "#E4DFF0", 5.5)
    sticker(s, rrect(24, 58, 80, 56, 14), "pomme", 6, 0.5)
    s.fill(circ(64, 82, 8), INK)
    s.fill(rrect(60, 84, 8, 16, 4), INK)
    s.gloss(rrect(32, 64, 36, 7, 3.5), 0.7)


@icon("star", "glyph", group=G, desc="étoile pleine (★)")
def _(s):
    d = poly(star(64, 66, 5, 54, 25, -90))
    sticker(s, d, "soleil", 6, 0.55)
    s.gloss("M50 50 L60 30 L64 38 L56 56Z", 0.75)


@icon("star_empty", "glyph", group=G, desc="étoile vide (☆)")
def _(s):
    d = poly(star(64, 66, 5, 54, 25, -90))
    sticker_flat(s, d, "#E9E4F3", "#B5AFCB", 6, 0.55)
    s.line("M40 52 L54 34", 4.5, "#FFFFFF")


@icon("goal", "glyph", group=G, desc="objectif suivi (fanion)")
def _(s):
    s.inked(rrect(24, 14, 10, 104, 5), "#E4DFF0", 4.5)
    sticker(s, poly([(34, 20), (112, 20), (92, 46), (112, 72), (34, 72)]), "mandarine", 5.5, 0.52, shadow=(3, 4))
    s.inked(poly(star(68, 46, 5, 17, 7.5, -90)), "#FFFFFF", 3.2, shadow=False)
    s.gloss("M40 26 H92", 0.0)


@icon("new", "glyph", group=G, desc="nouveau (« ! » rond mandarine)")
def _(s):
    sticker(s, circ(64, 64, 50), "mandarine", 6, 0.52)
    s.inked(rrect(56, 28, 16, 44, 8), "#FFFFFF", 3.5, shadow=False)
    s.inked(circ(64, 90, 9), "#FFFFFF", 3.5, shadow=False)
    s.line("M34 44 Q36 34 46 28", 5, "#FFFFFF")


@icon("alert", "glyph", group=G, desc="attention (triangle)")
def _(s):
    sticker(s, "M64 14 Q70 14 74 21 L116 94 Q122 106 108 108 H20 Q6 106 12 94 L54 21 Q58 14 64 14Z", "soleil", 6, 0.55)
    s.fill(rrect(58, 44, 12, 34, 6), INK)
    s.fill(circ(64, 92, 7), INK)


@icon("info", "glyph", group=G, desc="information (i)")
def _(s):
    sticker(s, circ(64, 64, 50), "lagon", 6, 0.55)
    s.inked(circ(64, 38, 8.5), "#FFFFFF", 3.2, shadow=False)
    s.inked(rrect(55, 54, 18, 46, 8), "#FFFFFF", 3.2, shadow=False)
    s.line("M34 44 Q36 34 46 28", 5, "#FFFFFF")


@icon("help", "glyph", group=G, desc="aide (?)")
def _(s):
    sticker(s, circ(64, 64, 50), "lagon", 6, 0.55)
    s.inked_line("M46 50 Q46 30 64 30 Q82 30 82 48 Q82 60 64 68 V76", 11, "#FFFFFF", 3.2, shadow=False)
    s.inked(circ(64, 95, 8.5), "#FFFFFF", 3.2, shadow=False)


@icon("quest_done", "glyph", group=G, desc="étape faite (losange pomme, coche)")
def _(s):
    sticker(s, poly([(64, 8), (118, 64), (64, 120), (10, 64)]), "pomme", 6, 0.55)
    s.inked_line("M42 66 L58 82 L88 46", 12, "#FFFFFF", 0.001, shadow=False)
    s.line("M42 66 L58 82 L88 46", 12, "#FFFFFF")


@icon("quest_todo", "glyph", group=G, desc="étape à faire (losange creux)")
def _(s):
    sticker(s, poly([(64, 8), (118, 64), (64, 120), (10, 64)]), "soleil", 6, 0.55)
    s.inked(poly([(64, 38), (90, 64), (64, 90), (38, 64)]), "#FFF8EC", 4, shadow=False)


@icon("cmp_up", "glyph", group=G, desc="mieux (▲)")
def _(s):
    sticker(s, "M64 14 Q70 14 74 22 L114 88 Q120 108 100 108 H28 Q8 108 14 88 L54 22 Q58 14 64 14Z", "pomme", 6, 0.55)
    s.gloss("M52 44 L62 28 L66 36 L58 52Z", 0.7)


@icon("cmp_down", "glyph", group=G, desc="moins bien (▼)")
def _(s):
    sticker(s, "M64 114 Q70 114 74 106 L114 40 Q120 20 100 20 H28 Q8 20 14 40 L54 106 Q58 114 64 114Z", "fraise", 6, 0.5)
    s.gloss("M24 30 H52", 0.0)
    s.line("M30 34 H54", 5, "#FFFFFF")


@icon("plus", "glyph", group=G, desc="ajouter (+)")
def _(s):
    d = _bar(64, 64, 100, 30, 0) + " " + _bar(64, 64, 100, 30, 90)
    sticker(s, d, "pomme", 6, 0.55)
    s.line("M30 54 H52", 4.5, "#FFFFFF")


@icon("swap", "glyph", group=G, desc="échanger (⇄)")
def _(s):
    sticker(s, "M14 38 H80 V22 L116 48 L80 74 V58 H14Z", "lagon", 5.5, 0.5, shadow=(3, 4))
    sticker(s, "M114 90 H48 V74 L12 100 L48 126 V110 H114Z".replace("V74", "V74").replace("L12 100", "L12 100"), "mandarine", 5.5, 0.5, shadow=(3, 4))


@icon("refresh", "glyph", group=G, desc="rejouer / recommencer (↻)")
def _(s):
    cx, cy, r = 60, 66, 36
    a1 = math.radians(-35 + 285)
    s.inked_line(arc(cx, cy, r, -35, 250), 14, tone("lagon"), 5.5)
    ex, ey = cx + r * math.cos(a1), cy + r * math.sin(a1)
    tx, ty = -math.sin(a1), math.cos(a1)   # tangente (sens horaire)
    nx, ny = math.cos(a1), math.sin(a1)
    tip = (ex + tx * 24, ey + ty * 24)
    b1 = (ex + nx * 22, ey + ny * 22)
    b2 = (ex - nx * 22, ey - ny * 22)
    sticker(s, poly([tip, b1, b2]), "lagon", 5.5, 0.5, shadow=(3, 4))


@icon("follow", "glyph", group=G, desc="suivre (signet)")
def _(s):
    sticker(s, "M30 12 H98 Q104 12 104 18 V118 L64 90 L24 118 V18 Q24 12 30 12Z", "mandarine", 6, 0.5)
    s.gloss("M34 22 H64", 0.0)
    s.line("M38 26 H60", 5, "#FFFFFF")


@icon("hourglass", "glyph", group=G, desc="sablier (minuteur)")
def _(s):
    s.inked(rrect(22, 8, 84, 14, 7), tone("mandarine"), 4.5)
    s.inked(rrect(22, 106, 84, 14, 7), tone("mandarine"), 4.5)
    sticker(s, "M34 22 H94 Q94 54 72 64 Q94 74 94 106 H34 Q34 74 56 64 Q34 54 34 22Z", "lagon", 5.5, 0.5, shadow=None)
    s.fill("M44 30 H84 Q80 46 64 52 Q48 46 44 30Z", "#FFE27A")
    s.fill("M52 100 Q64 76 76 100Z", "#FFE27A")


@icon("skull", "glyph", group=G, desc="crâne (menace)")
def _(s):
    d = ("M22 62 C22 30 44 14 64 14 C84 14 106 30 106 62 C106 76 98 84 90 88 V104 Q90 114 80 114 H48 Q38 114 38 104 V88 "
         "C30 84 22 76 22 62Z")
    sticker_flat(s, d, "#FFFFFF", "#CFC8E6", 6, 0.62)
    s.fill(circ(45, 62, 11), INK)
    s.fill(circ(83, 62, 11), INK)
    s.fill(poly([(64, 74), (58, 86), (70, 86)]), INK)
    s.line("M54 98 V110 M64 98 V110 M74 98 V110", 4, INK)
    s.line("M36 34 Q42 26 52 24", 5, "#FFFFFF")


@icon("scales", "glyph", group=G, desc="balance (pacte)")
def _(s):
    s.inked_line("M64 22 V102", 10, tone("soleil"), 5, shadow=False)
    s.inked(rrect(34, 100, 60, 14, 7), tone("soleil", 2), 4.5)
    s.inked_line("M18 40 H110", 9, tone("soleil"), 5, shadow=False)
    s.inked_line("M24 42 L10 74 M24 42 L38 74 M104 42 L90 74 M104 42 L118 74", 3.2, "#FFFFFF", 3, shadow=False)
    s.inked("M8 72 H40 A16 16 0 0 1 8 72Z", tone("soleil"), 4.5)
    s.inked("M88 72 H120 A16 16 0 0 1 88 72Z", tone("soleil"), 4.5)
    s.inked(circ(64, 20, 9), tone("soleil", 0), 4.5)


@icon("crown", "glyph", group=G, desc="couronne (record, meilleur)")
def _(s):
    sticker(s, poly([(14, 100), (8, 36), (42, 62), (64, 18), (86, 62), (120, 36), (114, 100)]), "soleil", 6, 0.5)
    s.inked(rrect(14, 92, 100, 20, 8), tone("mandarine"), 4.5)
    for cx, col in ((64, "fraise"), (34, "lagon"), (94, "pomme")):
        s.inked(circ(cx, 100, 6), tone(col), 2.5, shadow=False)
    s.gloss("M40 44 L52 60 L46 64Z", 0.0)


@icon("swords", "glyph", group=G, desc="épées croisées (⚔)")
def _(s):
    draw_sword(s, 64, 56, 40, 1.12)
    draw_sword(s, 64, 56, -40, 1.12)


@icon("grave", "glyph", group=G, desc="chute (✝) : pierre tombale")
def _(s):
    sticker_flat(s, "M26 112 V52 A38 38 0 0 1 102 52 V112Z", "#E9E4F3", "#A29BB9", 6, 0.55)
    s.line("M64 38 V82 M46 54 H82", 9, INK)
    s.line("M36 52 Q38 36 50 28", 5, "#FFFFFF")


@icon("gem_empty", "glyph", group=G, desc="emplacement de gemme vide (◇)")
def _(s):
    d = poly(gem_pts(64, 62, 1.15))
    sticker_flat(s, d, "#EAE5F5", "#B5AFCB", 6, 0.5, shadow=(3, 4))
    s.inked(poly(gem_pts(64, 64, 0.5)), "#6B5E86", 0.001, shadow=False)


@icon("gem", "glyph", group=G, desc="gemme (améthyste)")
def _(s):
    d = poly(gem_pts(64, 62, 1.15))
    sticker(s, d, "amethyste", 6, 0.5, shadow=(3, 4))
    s.line("M32 40 H96 M64 40 L28 66 M64 40 L100 66 M64 40 L64 108", 3, INK)
    s.gloss("M44 30 L58 30 L44 46Z", 0.7)


@icon("spark", "glyph", group=G, desc="éclat (✶ passif, ✦ nouveau plan)")
def _(s):
    sticker(s, sparkle(64, 64, 56, 15, 4), "soleil", 5.5, 0.55)
    s.gloss("M58 40 L64 22 L66 44Z", 0.8)


@icon("arrow_right", "glyph", group=G, desc="flèche (→)")
def _(s):
    sticker(s, "M10 46 H70 V22 L118 64 L70 106 V82 H10Z", "lagon", 5.5, 0.5)


@icon("chevron_right", "glyph", group=G, desc="chevron › (aller)")
def _(s):
    s.inked_line("M44 20 L90 64 L44 108", 24, tone("lagon"), 6)


@icon("chevron_down", "glyph", group=G, desc="chevron ▾ (déplier)")
def _(s):
    s.inked_line("M20 44 L64 90 L108 44", 24, tone("lagon"), 6)


@icon("coin", "glyph", group=G, desc="pièce d'or")
def _(s):
    sticker(s, circ(64, 64, 50), "soleil", 6, 0.5)
    s.inked(circ(64, 64, 33), tone("soleil", 0), 4, shadow=False)
    s.fill(poly([(64, 44), (80, 64), (64, 84), (48, 64)]), tone("mandarine", 2))
    s.line("M30 40 Q36 28 50 22", 5, "#FFFFFF")


@icon("heart", "glyph", group=G, desc="cœur (vie)")
def _(s):
    sticker(s, heart_path(64, 64, 1.0), "fraise", 6, 0.52)
    s.gloss("M30 42 Q34 32 44 32 L44 40 Q38 40 36 48Z", 0.75)


@icon("mana", "glyph", group=G, desc="goutte (magie)")
def _(s):
    sticker(s, drop_path(64, 76, 36), "lagon", 6, 0.5)
    s.gloss("M44 76 Q44 66 52 60 L54 66 Q50 70 50 78Z", 0.75)
