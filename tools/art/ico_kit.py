"""Pièces communes des définitions d'icônes (ICO-1) : autocollant libre, symboles blancs, objets récurrents."""
import math

from ico_core import (INK, WHITE, PAPER, PAPER3, TONES, n, xf, poly, circ, ell, rrect, star, ngon, arc, smooth, icon, REG, GROUPS)  # noqa: F401


# --- forme libre autocollante (kind "glyph", repère 0..128) ----------------------------------------------------
def sticker(s, d, tone, ow=5.5, split=0.55, shadow=(4, 5)):
    """Ombre dure, contour d'encre, deux tons nets du bonbon `tone`."""
    c, b, f = TONES[tone]
    if shadow:
        s.raw('<path d="%s" transform="translate(%s,%s)" fill="%s" stroke="%s" stroke-width="%s" stroke-linejoin="round"/>' % (d, shadow[0], shadow[1], INK, INK, n(ow * 2)))
    s.inked(d, s.two_tone(b, f, split), ow, shadow=False)


def sticker_flat(s, d, top, bottom, ow=5.5, split=0.55, shadow=(4, 5)):
    if shadow:
        s.raw('<path d="%s" transform="translate(%s,%s)" fill="%s" stroke="%s" stroke-width="%s" stroke-linejoin="round"/>' % (d, shadow[0], shadow[1], INK, INK, n(ow * 2)))
    s.inked(d, s.two_tone(top, bottom, split), ow, shadow=False)


def ink_over(s, d, w=5.0, color=INK):
    s.line(d, w, color)


def dot(s, cx, cy, r, color=INK):
    s.fill(circ(cx, cy, r), color)


# --- symboles blancs (tile et sym, repère 0..100, utile 10..90) ------------------------------------------------
def wfill(s, d, color=WHITE, ow=4.5):
    s.inked(d, color, ow)


def wline(s, d, w=9.0, color=WHITE, ow=4.0):
    s.inked_line(d, w, color, ow)


def accent(s, d, color):
    """Aplat de couleur sans contour, posé sur un symbole blanc."""
    s.fill(d, color)


def tone(name, i=1):
    return TONES[name][i]


# --- objets récurrents -----------------------------------------------------------------------------------------
def heart_path(cx, cy, k=1.0):
    def p(x, y):
        return "%s %s" % (n(cx + (x - 64) * k), n(cy + (y - 64) * k))
    return "M%s C%s, %s, %s C%s, %s, %s C%s, %s, %s C%s, %s, %s Z" % (
        p(64, 112), p(18, 80), p(8, 44), p(30, 26), p(46, 14), p(62, 22), p(64, 40),
        p(66, 22), p(82, 14), p(98, 26), p(120, 44), p(110, 80), p(64, 112))


def shield_path(cx, cy, w, h):
    """Écu : haut plat, flancs droits puis pointe arrondie."""
    x0, x1, y0, y1 = cx - w / 2, cx + w / 2, cy - h / 2, cy + h / 2
    return "M%s %s Q%s %s %s %s V%s C%s %s %s %s %s %s C%s %s %s %s %s %s V%s Z" % (
        n(x0), n(y0), n(cx), n(y0 - h * 0.1), n(x1), n(y0), n(y0 + h * 0.5), n(x1), n(y0 + h * 0.8), n(cx + w * 0.2), n(y1 - h * 0.08), n(cx), n(y1),
        n(cx - w * 0.2), n(y1 - h * 0.08), n(x0), n(y0 + h * 0.8), n(x0), n(y0 + h * 0.5), n(y0))


def drop_path(cx, cy, r):
    return "M%s %s C%s %s %s %s %s %s A%s %s 0 1 1 %s %s C%s %s %s %s %s %sZ" % (
        n(cx), n(cy - r * 1.7), n(cx + r * 0.25), n(cy - r * 1.1), n(cx + r), n(cy - r * 0.35), n(cx + r), n(cy + r * 0.2),
        n(r), n(r), n(cx - r), n(cy + r * 0.2), n(cx - r), n(cy - r * 0.35), n(cx - r * 0.25), n(cy - r * 1.1), n(cx), n(cy - r * 1.7))


def bolt_pts(cx, cy, k=1.0):
    base = [(8, -50), (-26, 6), (-2, 6), (-12, 50), (28, -10), (4, -10), (22, -50)]
    return xf(base, cx, cy, 0, k)


def sparkle(cx, cy, R, r=None, k=4, rot=-90.0):
    return poly(star(cx, cy, k, R, r if r is not None else R * 0.3, rot))


def flame_path(cx, cy, k=1.0):
    def p(x, y):
        return "%s %s" % (n(cx + (x - 50) * k), n(cy + (y - 50) * k))
    pts = [(50, 8), (56, 26), (80, 36), (80, 60), (80, 78), (66, 92), (50, 92), (34, 92), (20, 78), (20, 60),
           (20, 46), (28, 38), (34, 32), (34, 42), (38, 48), (44, 50), (40, 32), (44, 18), (50, 8)]
    d = "M" + p(*pts[0])
    for i in range(1, len(pts), 3):
        d += " C" + ", ".join(p(*q) for q in pts[i:i + 3])
    return d + "Z"


def sword_parts(cx, cy, ang=0.0, sc=1.0, blade_len=62.0):
    """Épée pointant vers le haut avant rotation. Renvoie [(d, rôle)] : blade, guard, grip, pommel."""
    L = blade_len
    blade = xf([(0, -L), (7, -L + 12), (7, 0), (-7, 0), (-7, -L + 12)], cx, cy, ang, sc)
    guard = xf([(-17, -1), (17, -1), (17, 7), (-17, 7)], cx, cy, ang, sc)
    grip = xf([(-4.5, 7), (4.5, 7), (4.5, 27), (-4.5, 27)], cx, cy, ang, sc)
    pc = xf([(0, 31)], cx, cy, ang, sc)[0]
    return [(poly(blade), "blade"), (poly(guard), "guard"), (poly(grip), "grip"), (circ(pc[0], pc[1], 6.5 * sc), "pommel")]


def draw_sword(s, cx, cy, ang=0.0, sc=1.0, blade_len=62.0, ow=4.5, metal=("#FFFFFF", "#CFC8E6"), hilt="soleil", shadow=True):
    for d, role in sword_parts(cx, cy, ang, sc, blade_len):
        if role == "blade":
            sticker_flat(s, d, metal[0], metal[1], ow, 0.5, shadow=None if not shadow else (3, 4))
        elif role == "grip":
            sticker(s, d, "mandarine", ow, 0.5, shadow=None)
        else:
            sticker(s, d, hilt, ow, 0.5, shadow=None)


def white_sword(s, cx, cy, ang=0.0, sc=1.0, blade_len=62.0, ow=4.0):
    for d, role in sword_parts(cx, cy, ang, sc, blade_len):
        wfill(s, d, WHITE, ow)


def crown_pts(cx, cy, k=1.0):
    base = [(-46, 32), (-52, -22), (-24, 0), (0, -40), (24, 0), (52, -22), (46, 32)]
    return xf(base, cx, cy, 0, k)


def gem_pts(cx, cy, k=1.0):
    """Gemme taillée en brillant (vue de face) : table, couronne, pavillon."""
    base = [(-26, -30), (26, -30), (46, -6), (0, 44), (-46, -6)]
    return xf(base, cx, cy, 0, k)
