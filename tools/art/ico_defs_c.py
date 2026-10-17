"""Icônes « sym » (symbole blanc contouré, sans tuile : mécaniques de boss, emplacements) et « glyph » (touches, raretés, modes)."""
import re

from ico_kit import *  # noqa: F401,F403

# =============================================================================================================
# Mécaniques de boss : un pictogramme par brique (BossBricks.DEFS) + les attaques de base et la fureur.
# Blanc contouré d'encre : la pastille de la barre de boss (BossBar.chip) donne la couleur de la famille.
# =============================================================================================================
B = "Mécaniques de boss"
GREY = "#CFC8E6"


def _spiral(cx, cy, r0, r1, turns, n_pts=40):
    pts = []
    for i in range(n_pts):
        t = i / (n_pts - 1)
        a = math.radians(-90 + 360 * turns * t)
        r = r0 + (r1 - r0) * t
        pts.append((cx + r * math.cos(a), cy + r * math.sin(a)))
    return pts


@icon("boss_puddles", "sym", None, B, "Flaques")
def _(s):
    wfill(s, smooth([(14, 70), (24, 58), (44, 56), (60, 54), (80, 60), (88, 72), (76, 84), (50, 88), (24, 84)]))
    wfill(s, drop_path(50, 32, 11))


@icon("boss_meteors", "sym", None, B, "Pluie de météores")
def _(s):
    wline(s, "M46 54 L12 88", 13)
    wline(s, "M34 38 L18 54", 7)
    wfill(s, circ(64, 36, 22))
    s.fill(circ(58, 30, 6), GREY)


@icon("boss_lasers", "sym", None, B, "Rayons")
def _(s):
    wline(s, "M12 80 L80 12", 11)
    wline(s, "M30 94 L94 30", 11)
    wfill(s, sparkle(78, 78, 13, 4), WHITE, 3.5)


@icon("boss_grid", "sym", None, B, "Damier")
def _(s):
    wfill(s, rrect(12, 12, 36, 36, 6))
    wfill(s, rrect(52, 52, 36, 36, 6))
    wfill(s, rrect(52, 12, 36, 36, 6), GREY, 4)
    wfill(s, rrect(12, 52, 36, 36, 6), GREY, 4)


@icon("boss_sweep", "sym", None, B, "Balayage")
def _(s):
    wline(s, "M12 28 H66 M12 50 H72 M12 72 H66", 9)
    wfill(s, poly([(92, 50), (72, 30), (72, 70)]))


@icon("boss_adds", "sym", None, B, "Renforts")
def _(s):
    for x, y, c in ((24, 52, GREY), (76, 52, GREY), (50, 40, WHITE)):
        wfill(s, circ(x, y - 12, 10), c, 4)
        wfill(s, "M%s %s Q%s %s %s %s Q%s %s %s %sZ" % (n(x - 15), n(y + 32), n(x - 15), n(y + 6), n(x), n(y + 6), n(x + 15), n(y + 6), n(x + 15), n(y + 32)), c, 4)


@icon("boss_pet", "sym", None, B, "Compagnon : patte")
def _(s):
    wfill(s, "M50 46 C70 46 82 62 78 74 C74 86 60 82 50 82 C40 82 26 86 22 74 C18 62 30 46 50 46Z")
    for x, y in ((20, 40), (38, 24), (62, 24), (80, 40)):
        wfill(s, ell(x, y, 8, 10), WHITE, 3.5)


@icon("boss_clones", "sym", None, B, "Illusions")
def _(s):
    wfill(s, circ(66, 32, 14), GREY, 4)
    wfill(s, "M44 70 Q44 48 66 48 Q88 48 88 70Z", GREY, 4)
    wfill(s, circ(40, 42, 16))
    wfill(s, "M14 88 Q14 58 40 58 Q66 58 66 88Z")


@icon("boss_swarm", "sym", None, B, "Nuée")
def _(s):
    for x, y, r in ((30, 30, 11), (66, 24, 9), (52, 52, 13), (22, 66, 9), (78, 62, 11), (46, 82, 9)):
        wfill(s, circ(x, y, r), WHITE, 3.5)
        s.fill(circ(x + 3, y - 1, r * 0.25), INK)


@icon("boss_turrets", "sym", None, B, "Tourelles")
def _(s):
    wfill(s, rrect(18, 64, 64, 22, 6))
    wfill(s, poly(xf([(-8, -9), (42, -9), (42, 9), (-8, 9)], 46, 52, -38)))
    wfill(s, "M30 66 A20 20 0 0 1 70 66Z")


@icon("boss_enrage", "sym", None, B, "Rage")
def _(s):
    wfill(s, flame_path(50, 50, 0.92))
    s.fill(poly([(32, 58), (46, 64), (34, 68)]), INK)
    s.fill(poly([(68, 58), (54, 64), (66, 68)]), INK)


@icon("boss_frenzy", "sym", None, B, "Impatience : sablier")
def _(s):
    wfill(s, rrect(22, 10, 56, 10, 5))
    wfill(s, rrect(22, 80, 56, 10, 5))
    wfill(s, "M28 20 H72 Q72 44 56 50 Q72 56 72 80 H28 Q28 56 44 50 Q28 44 28 20Z")
    s.fill("M38 66 Q50 54 62 66 V76 H38Z", GREY)


@icon("boss_totems", "sym", None, B, "Totems")
def _(s):
    for y in (10, 38, 66):
        wfill(s, rrect(30, y, 40, 24, 5))
        s.fill(circ(42, y + 11, 3.6), INK)
        s.fill(circ(58, y + 11, 3.6), INK)


@icon("boss_barrier", "sym", None, B, "Barrière")
def _(s):
    wfill(s, "M12 82 A38 38 0 0 1 88 82Z")
    s.line("M26 70 Q30 52 44 44", 6, GREY)
    wfill(s, rrect(8, 78, 84, 10, 5))


@icon("boss_crystals", "sym", None, B, "Cristaux de soin")
def _(s):
    wfill(s, poly([(16, 52), (28, 40), (34, 80), (22, 86)]), GREY, 4)
    wfill(s, poly([(84, 52), (72, 40), (66, 80), (78, 86)]), GREY, 4)
    wfill(s, poly([(50, 8), (66, 30), (62, 78), (50, 92), (38, 78), (34, 30)]))
    s.line("M50 14 V86 M38 30 L62 30", 3, GREY)


@icon("boss_rampage", "sym", None, B, "Ruée : chevrons")
def _(s):
    wline(s, "M12 24 L34 50 L12 76 M38 24 L60 50 L38 76 M64 24 L86 50 L64 76", 10)


@icon("boss_leap", "sym", None, B, "Bond")
def _(s):
    wline(s, "M14 72 Q46 -6 86 56", 7)
    wfill(s, poly([(86, 84), (72, 58), (100, 58)]), WHITE, 3.8)
    s.inked_line(ell(50, 86, 36, 6), 5, WHITE, 3)


@icon("boss_spiral", "sym", None, B, "Spirale")
def _(s):
    wline(s, smooth(_spiral(50, 50, 4, 40, 2.1), False), 8)


@icon("boss_ring_burst", "sym", None, B, "Couronne d'orbes")
def _(s):
    for i in range(8):
        a = math.radians(i * 45 - 90)
        wfill(s, circ(50 + 34 * math.cos(a), 50 + 34 * math.sin(a), 8.5), WHITE, 3.5)
    wfill(s, circ(50, 50, 6), GREY, 3)


@icon("boss_fan", "sym", None, B, "Éventail")
def _(s):
    wfill(s, "M50 90 L10 40 A60 60 0 0 1 90 40Z")
    s.line("M50 90 L50 26 M50 90 L26 34 M50 90 L74 34", 4, GREY)


@icon("boss_shrink", "sym", None, B, "L'arène se resserre")
def _(s):
    wfill(s, poly([(50, 36), (36, 14), (64, 14)]))
    wfill(s, poly([(50, 64), (36, 86), (64, 86)]))
    wfill(s, poly([(36, 50), (14, 36), (14, 64)]))
    wfill(s, poly([(64, 50), (86, 36), (86, 64)]))


@icon("boss_safe_zone", "sym", None, B, "Cercle sûr")
def _(s):
    wline(s, circ(50, 50, 34), 8)
    wfill(s, circ(50, 50, 12), WHITE, 4)
    wline(s, "M43 50 L49 56 L58 44", 4, INK, 0.001)


@icon("boss_vortex", "sym", None, B, "Tourbillon")
def _(s):
    wline(s, "M12 22 H88 M22 40 H78 M32 58 H68 M42 76 H58", 9)


@icon("boss_gale", "sym", None, B, "Bourrasque")
def _(s):
    wline(s, "M10 34 H58 Q76 34 76 22 Q76 12 66 12", 8)
    wline(s, "M10 54 H82 Q94 54 94 66 Q94 76 84 76", 8)
    wline(s, "M10 74 H42", 8)


@icon("boss_gaze", "sym", None, B, "Regard")
def _(s):
    wfill(s, "M6 50 Q50 8 94 50 Q50 92 6 50Z")
    s.fill(circ(50, 50, 19), INK)
    s.fill(circ(44, 44, 6), WHITE)


@icon("boss_marks", "sym", None, B, "Marque")
def _(s):
    wline(s, circ(50, 50, 28), 8)
    wline(s, "M50 8 V30 M50 70 V92 M8 50 H30 M70 50 H92", 8)
    wfill(s, circ(50, 50, 7), WHITE, 3.5)


@icon("boss_blink", "sym", None, B, "Saut d'ombre")
def _(s):
    for a0 in (-80, 10, 100, 190):
        wline(s, arc(50, 50, 34, a0, a0 + 60), 8)
    wfill(s, sparkle(50, 50, 20, 6, 4), WHITE, 4)


@icon("boss_reflect", "sym", None, B, "Miroir")
def _(s):
    wfill(s, ell(50, 40, 28, 34))
    s.fill(ell(50, 40, 20, 26), GREY)
    s.line("M36 30 Q40 22 48 20", 5, WHITE)
    wfill(s, rrect(43, 72, 14, 20, 5))


@icon("boss_stomp", "sym", None, B, "Ondes de choc")
def _(s):
    wline(s, ell(50, 74, 38, 12), 7)
    wline(s, ell(50, 74, 18, 5), 7)
    wline(s, "M50 10 V46", 9)
    wfill(s, poly([(50, 60), (34, 40), (66, 40)]))


@icon("boss_slams", "sym", None, B, "Frappes au sol : marteau")
def _(s):
    wline(s, "M24 80 L62 42", 9)
    wfill(s, poly(xf([(-22, -13), (22, -13), (22, 13), (-22, 13)], 66, 36, 45)))
    wline(s, "M14 90 L30 90 M12 74 L24 78", 6)


@icon("boss_charge", "sym", None, B, "Charge")
def _(s):
    wline(s, "M10 34 H34 M6 52 H30 M10 70 H34", 7)
    wfill(s, "M38 28 H66 V16 L92 50 L66 84 V72 H38Z")


@icon("boss_cleave", "sym", None, B, "Griffes")
def _(s):
    wline(s, "M20 12 Q40 50 26 90 M44 10 Q64 50 50 92 M68 12 Q88 50 74 88", 9)


@icon("boss_barrage", "sym", None, B, "Salve de tirs")
def _(s):
    for y, x in ((22, 40), (50, 26), (78, 40)):
        wfill(s, rrect(x, y - 7, 44, 14, 7))
        wfill(s, circ(x + 44, y, 9), WHITE, 3.5)


@icon("boss_nova", "sym", None, B, "Nova")
def _(s):
    wfill(s, poly(star(50, 50, 8, 44, 22, -90)))
    s.fill(circ(50, 50, 10), GREY)


@icon("boss_phase2", "sym", None, B, "Fureur")
def _(s):
    wfill(s, poly(star(50, 50, 7, 46, 25, -90)))
    s.fill(rrect(45, 26, 10, 28, 5), tone("fraise", 2))
    s.fill(circ(50, 68, 6), tone("fraise", 2))


@icon("boss_hit", "sym", None, B, "Coup (attaque sans nom)")
def _(s):
    wfill(s, poly(star(50, 50, 6, 42, 20, -90)))


# =============================================================================================================
# Emplacements d'équipement : silhouettes (cases vides, filtres)
# =============================================================================================================
Q = "Emplacements"


@icon("slot_weapon", "sym", None, Q, "Arme")
def _(s):
    white_sword(s, 50, 52, 40, 0.95)


@icon("slot_head", "sym", None, Q, "Tête")
def _(s):
    wfill(s, "M16 60 A34 34 0 0 1 84 60 V84 H66 V70 H34 V84 H16Z")
    s.fill(rrect(30, 54, 40, 9, 4.5), INK)


@icon("slot_chest", "sym", None, Q, "Torse")
def _(s):
    wfill(s, "M28 14 L40 10 Q50 22 60 10 L72 14 L92 28 L82 48 L74 44 V88 H26 V44 L18 48 L8 28Z")


@icon("slot_legs", "sym", None, Q, "Jambes")
def _(s):
    wfill(s, "M24 12 H76 L80 88 H56 L50 40 L44 88 H20Z")


@icon("slot_gloves", "sym", None, Q, "Gants")
def _(s):
    wfill(s, rrect(30, 70, 40, 20, 5))
    wfill(s, rrect(22, 36, 50, 40, 10))
    for x in (27, 39, 51, 63):
        wfill(s, rrect(x - 6, 12, 12, 30, 6))
    wfill(s, rrect(10, 46, 16, 22, 8))


@icon("slot_boots", "sym", None, Q, "Bottes")
def _(s):
    wfill(s, "M34 10 H62 V56 Q62 62 70 64 L90 72 Q94 88 82 88 H26 Q20 88 20 80 V60 Q34 58 34 46Z")


@icon("slot_back", "sym", None, Q, "Cape")
def _(s):
    wfill(s, "M30 12 H70 L92 86 Q70 74 50 90 Q30 74 8 86Z")
    wfill(s, rrect(34, 8, 32, 12, 6), GREY, 4)


@icon("slot_necklace", "sym", None, Q, "Collier")
def _(s):
    wline(s, "M18 12 Q50 82 82 12", 6)
    wfill(s, poly(gem_pts(50, 70, 0.4)))


@icon("slot_ring", "sym", None, Q, "Bague")
def _(s):
    wline(s, circ(50, 62, 24), 10)
    wfill(s, poly(gem_pts(50, 30, 0.3)))


@icon("slot_trophy", "sym", None, Q, "Trophée")
def _(s):
    wline(s, "M30 28 Q10 28 14 46 Q18 58 34 56 M70 28 Q90 28 86 46 Q82 58 66 56", 6)
    wfill(s, "M26 12 H74 V42 Q74 64 50 68 Q26 64 26 42Z")
    wfill(s, rrect(43, 66, 14, 12, 3))
    wfill(s, rrect(28, 78, 44, 12, 5))


@icon("slot_offhand", "sym", None, Q, "Arme secondaire : écu")
def _(s):
    wfill(s, shield_path(50, 50, 66, 80))
    s.fill(shield_path(50, 52, 34, 46), GREY)


# =============================================================================================================
# Touches de manette, de clavier et de souris (glyphs ; les lettres sont des traits)
# =============================================================================================================
T = "Touches"

LETTERS = {
    "A": "M-0.7 1 L0 -1 L0.7 1 M-0.4 0.35 H0.4",
    "B": "M-0.6 -1 V1 H0.1 Q0.8 1 0.8 0.5 Q0.8 0 0.1 0 H-0.6 M0.1 0 Q0.7 0 0.7 -0.5 Q0.7 -1 0 -1 H-0.6",
    "X": "M-0.7 -1 L0.7 1 M0.7 -1 L-0.7 1",
    "Y": "M-0.7 -1 L0 0 L0.7 -1 M0 0 V1",
    "L": "M-0.5 -1 V1 H0.6",
    "R": "M-0.6 1 V-1 H0.1 Q0.8 -1 0.8 -0.5 Q0.8 0 0.1 0 H-0.6 M0.1 0 L0.7 1",
    "T": "M-0.8 -1 H0.8 M0 -1 V1",
    "1": "M-0.4 -0.6 L0.1 -1 V1",
    "2": "M-0.6 -0.5 Q-0.5 -1 0 -1 Q0.7 -1 0.7 -0.4 Q0.7 0 -0.6 1 H0.7",
}


def scale_path(d, cx, cy, kx, ky):
    out, toks, cmd, idx = [], re.findall(r"[A-Za-z]|-?\d*\.?\d+", d), "", 0
    for t in toks:
        if t.isalpha():
            cmd, idx = t, 0
            out.append(t)
            continue
        v = float(t)
        if cmd == "H":
            out.append(n(cx + v * kx))
        elif cmd == "V":
            out.append(n(cy + v * ky))
        else:
            out.append(n(cx + v * kx) if idx % 2 == 0 else n(cy + v * ky))
            idx += 1
    return " ".join(out)


def letters(s, text, cx, cy, k, color=WHITE, ow=3.4, w=7.0, gap=1.9):
    """Texte court (1 à 2 signes) en traits, centré en (cx, cy), hauteur 2k."""
    total = len(text) * gap
    for i, ch in enumerate(text):
        x = cx + (i - (len(text) - 1) / 2.0) * gap * k
        s.inked_line(scale_path(LETTERS[ch], x, cy, k * (0.95 if len(text) == 1 else 0.72), k), w, color, ow, shadow=False)


def disc(s, tone_name, text):
    sticker(s, circ(64, 64, 50), tone_name, 6, 0.55)
    letters(s, text, 64, 64, 22)


@icon("pad_a", "glyph", None, T, "Manette : A (validation)")
def _(s):
    disc(s, "pomme", "A")


@icon("pad_b", "glyph", None, T, "Manette : B (retour)")
def _(s):
    disc(s, "fraise", "B")


@icon("pad_x", "glyph", None, T, "Manette : X")
def _(s):
    disc(s, "lagon", "X")


@icon("pad_y", "glyph", None, T, "Manette : Y")
def _(s):
    disc(s, "soleil", "Y")


def ps_disc(s):
    sticker_flat(s, circ(64, 64, 50), "#4A3D78", "#2E2450", 6, 0.55)


@icon("pad_cross", "glyph", None, T, "Manette PlayStation : croix")
def _(s):
    ps_disc(s)
    s.line("M42 42 L86 86 M86 42 L42 86", 11, tone("lagon", 0))


@icon("pad_circle", "glyph", None, T, "Manette PlayStation : rond")
def _(s):
    ps_disc(s)
    s.line(circ(64, 64, 24), 11, tone("fraise", 0))


@icon("pad_square", "glyph", None, T, "Manette PlayStation : carré")
def _(s):
    ps_disc(s)
    s.line(rrect(42, 42, 44, 44, 3), 11, tone("amethyste", 0))


@icon("pad_triangle", "glyph", None, T, "Manette PlayStation : triangle")
def _(s):
    ps_disc(s)
    s.line(poly([(64, 38), (90, 86), (38, 86)]), 11, tone("pomme", 0))


def pill(s, text):
    sticker_flat(s, rrect(8, 28, 112, 72, 30), "#FFFFFF", "#CFC8E6", 6, 0.55)
    letters(s, text, 64, 64, 15, INK, 0.001, 8.0, 2.1)


for _id, _t in (("pad_lb", "LB"), ("pad_rb", "RB"), ("pad_lt", "LT"), ("pad_rt", "RT"), ("pad_l1", "L1"), ("pad_r1", "R1"), ("pad_l2", "L2"), ("pad_r2", "R2")):
    def _mk(t):
        def _f(s):
            pill(s, t)
        return _f
    icon(_id, "glyph", None, T, "Manette : " + _t)(_mk(_t))


@icon("pad_stick", "glyph", None, T, "Manette : stick")
def _(s):
    sticker_flat(s, circ(64, 64, 50), "#4A3D78", "#2E2450", 6, 0.55)
    s.fill(circ(64, 64, 22), tone("lagon", 0))
    s.fill(circ(64, 64, 12), tone("lagon", 1))
    for ang in (0, 90, 180, 270):
        s.fill(poly(xf([(0, -42), (7, -33), (-7, -33)], 64, 64, ang)), "#FFFFFF")


@icon("pad_dpad", "glyph", None, T, "Manette : croix directionnelle")
def _(s):
    sticker_flat(s, "M44 12 H84 V44 H116 V84 H84 V116 H44 V84 H12 V44 H44Z", "#4A3D78", "#2E2450", 6, 0.55)
    for ang in (0, 90, 180, 270):
        s.fill(poly(xf([(0, -36), (9, -24), (-9, -24)], 64, 64, ang)), "#FFFFFF")


@icon("pad_menu", "glyph", None, T, "Manette : Menu")
def _(s):
    sticker_flat(s, circ(64, 64, 50), "#4A3D78", "#2E2450", 6, 0.55)
    s.line("M40 46 H88 M40 64 H88 M40 82 H88", 8, "#FFFFFF")


def keycap(s, w, text=None):
    x = (128 - w) / 2.0
    sticker_flat(s, rrect(x, 16, w, 88, 20), "#FFFFFF", "#CFC8E6", 6, 0.62)
    s.inked(rrect(x + 16, 30, w - 32, 50, 12), "#FFF8EC", 3.2, shadow=False)


@icon("key_cap", "glyph", None, T, "Touche de clavier (vide : le jeu pose la lettre)")
def _(s):
    keycap(s, 96)


@icon("key_wide", "glyph", None, T, "Grande touche de clavier (Espace, Maj, Entrée)")
def _(s):
    keycap(s, 122)


def mouse(s, side):
    sticker_flat(s, "M64 8 C94 8 108 26 108 54 V78 C108 104 92 120 64 120 C36 120 20 104 20 78 V54 C20 26 34 8 64 8Z", "#FFFFFF", "#CFC8E6", 6, 0.6)
    s.line("M20 56 H108 M64 8 V56", 4.5, INK)
    if side == "l":
        s.fill("M64 12 C38 12 24 28 24 54 H64Z", tone("lagon", 1))
    elif side == "r":
        s.fill("M64 12 C90 12 104 28 104 54 H64Z", tone("lagon", 1))
    else:
        s.fill(rrect(56, 20, 16, 30, 8), tone("lagon", 1))
    s.line("M20 56 H108 M64 8 V56", 4.5, INK)
    s.line("M24 54 C24 28 38 12 64 12 C90 12 104 28 104 54", 4.5, INK)


@icon("key_mouse_l", "glyph", None, T, "Souris : clic gauche")
def _(s):
    mouse(s, "l")


@icon("key_mouse_r", "glyph", None, T, "Souris : clic droit")
def _(s):
    mouse(s, "r")


@icon("key_mouse_wheel", "glyph", None, T, "Souris : molette")
def _(s):
    mouse(s, "w")


# =============================================================================================================
# Raretés (gemmes) et modes
# =============================================================================================================
M = "Raretés et modes"
for _i, (_n, _tone) in enumerate((("Commun", "gris"), ("Spécial", "pomme"), ("Rare", "lagon"), ("Épique", "amethyste"),
                                  ("Mythique", "mandarine"), ("Légendaire", "soleil"))):
    def _mkr(tn, i):
        def _f(s):
            d = poly(gem_pts(64, 62, 1.15))
            sticker(s, d, tn, 6, 0.5, shadow=(3, 4))
            s.line("M32 40 H96 M64 40 L28 66 M64 40 L100 66 M64 40 L64 108", 3, INK)
            s.gloss("M44 30 L58 30 L44 46Z", 0.7)
            if i == 5:
                s.fill(sparkle(104, 22, 14, 4, 4), "#FFFFFF")
        return _f
    icon("rar_%d" % _i, "glyph", None, M, "Rareté : " + _n)(_mkr(_tone, _i))


@icon("mode_sealed", "tile", "amethyste", M, "Mode scellé : sceau de cire")
def _(s):
    wfill(s, poly(star(50, 50, 12, 40, 33, -90)), tone("fraise", 1), 4)
    s.fill(circ(50, 50, 22), tone("fraise", 2))
    s.line(circ(50, 50, 22), 3, tone("fraise", 0))
    s.fill(poly(star(50, 50, 5, 13, 5.5, -90)), tone("fraise", 0))
