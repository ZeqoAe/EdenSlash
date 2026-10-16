# Curseurs de souris du jeu (lot K1), dessinés au script, sans aucune image du jeu d'origine.
#   python -I tools/make_cursors.py            -> game/assets/ui/cursors/<jeu>_<forme>_<32|48>.png
#                                                 et écrit les points chauds dans game/scripts/ui/cursor_hotspots.gd
#   python -I tools/make_cursors.py --sheet f.png -> planche de contrôle (tous les jeux, fond clair et sombre)
# Un jeu = 4 formes : arrow (flèche), hand (main, CURSOR_POINTING_HAND), text (I), drag (poing, CURSOR_DRAG).
# Tout est dessiné dans une grille de 48 unités, à 8 fois la taille, puis réduit en 48 et en 32 pixels.
# Pour ajouter un jeu : une entrée dans SETS (palette + fonction de flèche + marque de la paume), l'identifiant
# dans CursorSets.LIST (cursor_sets.gd) et son nom français ; relancer ce script.
import json, math, os, re, sys
from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageOps

U = 48
K = 8
N = U * K
HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "..", "game", "assets", "ui", "cursors")
GD = os.path.join(HERE, "..", "game", "scripts", "ui", "cursor_hotspots.gd")
INK = (13, 10, 26)


def hexc(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def P(pts):
    return [(x * K, y * K) for x, y in pts]


def rot(pts, deg, origin=(0, 0), to=(0, 0)):
    a = math.radians(deg)
    c, s = math.cos(a), math.sin(a)
    return [(to[0] + (x - origin[0]) * c - (y - origin[1]) * s, to[1] + (x - origin[0]) * s + (y - origin[1]) * c) for x, y in pts]


def bez(p0, p1, p2, n=10):
    return [((1 - t) ** 2 * p0[0] + 2 * (1 - t) * t * p1[0] + t * t * p2[0],
             (1 - t) ** 2 * p0[1] + 2 * (1 - t) * t * p1[1] + t * t * p2[1]) for t in [i / n for i in range(n + 1)]]


class Art:
    """Pièces superposées (masque + dégradé), contour sombre commun, lueur facultative."""

    def __init__(self, pal):
        self.pal = pal
        self.parts = []   # (masque L, haut, bas) ou (masque, couleur plate)
        self.lines = []   # traits de détail (fonction de dessin sur la couche), coupés à la silhouette
        self.glow = False  # lueur : seulement la flèche (les autres formes touchent presque le bord)

    def mask(self, fn):
        m = Image.new("L", (N, N), 0)
        fn(ImageDraw.Draw(m))
        return m

    def part(self, fn, hi=None, lo=None, flat=None):
        self.parts.append((self.mask(fn), hi, lo, flat))

    def poly(self, pts, hi=None, lo=None, flat=None):
        self.part(lambda d: d.polygon(P(pts), fill=255), hi, lo, flat)

    def rrect(self, box, r, hi=None, lo=None, flat=None):
        x0, y0, x1, y1 = box
        self.part(lambda d: d.rounded_rectangle([x0 * K, y0 * K, x1 * K, y1 * K], radius=r * K, fill=255), hi, lo, flat)

    def circle(self, c, r, hi=None, lo=None, flat=None):
        self.part(lambda d: d.ellipse([(c[0] - r) * K, (c[1] - r) * K, (c[0] + r) * K, (c[1] + r) * K], fill=255), hi, lo, flat)

    def detail(self, fn):
        self.lines.append(fn)

    def render(self):
        pal = self.pal
        sil = Image.new("L", (N, N), 0)
        for m, *_ in self.parts:
            sil = ImageChops.lighter(sil, m)
        out = Image.new("RGBA", (N, N), (0, 0, 0, 0))
        if pal.get("glow") and self.glow:
            g = sil.filter(ImageFilter.MaxFilter(2 * int(1.6 * K) + 1)).filter(ImageFilter.GaussianBlur(3.2 * K))
            g = g.point(lambda v: int(v * pal.get("glow_a", 0.75)))
            out.paste(Image.new("RGBA", (N, N), hexc(pal["glow"]) + (255,)), (0, 0), g)
        # contour sombre (ou clair pour les jeux sombres)
        rim = int(pal.get("outline_w", 1.25) * K)
        dil = sil.filter(ImageFilter.MaxFilter(2 * rim + 1))
        out.paste(Image.new("RGBA", (N, N), hexc(pal["outline"]) + (255,) if "outline" in pal else INK + (255,)), (0, 0), dil)
        for m, hi, lo, flat in self.parts:
            if flat is not None:
                layer = Image.new("RGBA", (N, N), hexc(flat) + (255,))
            else:
                grad = Image.linear_gradient("L").resize((N, N))
                col = ImageOps.colorize(grad, black=hexc(lo), white=hexc(hi)).convert("RGBA")
                layer = col
            out.paste(layer, (0, 0), m)
        if self.lines:
            ov = Image.new("RGBA", (N, N), (0, 0, 0, 0))
            d = ImageDraw.Draw(ov)
            for fn in self.lines:
                fn(d)
            a = ImageChops.multiply(ov.getchannel("A"), sil)
            ov.putalpha(a)
            out = Image.alpha_composite(out, ov)
        return out


def ln(d, pts, col, w):
    d.line(P(pts), fill=hexc(col) + (255,), width=max(1, int(w * K)), joint="curve")


# ---- flèches ------------------------------------------------------------------------------------------
def arrow_gauntlet(a, pal):
    body = [(3, 3), (3, 35), (11, 28), (17, 41), (23, 38.5), (17, 25.5), (28, 25)]
    a.poly(body, pal["hi"], pal["lo"])
    a.poly([(3, 3), (3, 35), (11, 28), (11, 14)], pal["light"], pal["mid"])  # facette claire (plaque)
    a.detail(lambda d: ln(d, [(3.5, 4), (11, 27.5)], pal["lo"], 0.7))
    return (3, 3)


def arrow_blade(a, pal):
    ang = -45
    to = (3.5, 3.5)
    blade = rot([(0, 0), (3.2, 7), (3.2, 26), (-3.2, 26), (-3.2, 7)], ang, to=to)
    a.poly(blade, pal["light"], pal["mid"])
    a.poly(rot([(0, 0), (3.2, 7), (3.2, 26), (0, 26)], ang, to=to), pal["hi"], pal["lo"])  # moitié ombrée
    a.poly(rot([(-7.5, 26), (7.5, 26), (7.5, 29.5), (-7.5, 29.5)], ang, to=to), pal["gold_hi"], pal["gold_lo"])
    a.poly(rot([(-1.7, 29.5), (1.7, 29.5), (1.7, 36), (-1.7, 36)], ang, to=to), pal["grip_hi"], pal["grip_lo"])
    px, py = rot([(0, 38.2)], ang, to=to)[0]
    a.circle((px, py), 2.6, pal["gold_hi"], pal["gold_lo"])
    a.detail(lambda d: ln(d, rot([(0, 6), (0, 25)], ang, to=to), pal["lo"], 0.6))
    return (3, 3)


def arrow_crystal(a, pal):
    ang = -45
    to = (3.5, 3.5)
    gem = [(0, 0), (5.2, 7), (5.2, 21), (0, 31), (-5.2, 21), (-5.2, 7)]
    a.poly(rot(gem, ang, to=to), pal["light"], pal["mid"])
    a.poly(rot([(0, 0), (5.2, 7), (5.2, 21), (0, 31), (0, 12)], ang, to=to), pal["hi"], pal["lo"])  # facette droite
    a.detail(lambda d: ln(d, rot([(0, 0.5), (0, 30)], ang, to=to), pal["white"], 0.5))
    a.detail(lambda d: ln(d, rot([(-5, 7), (0, 12), (5, 7)], ang, to=to), pal["white"], 0.5))
    sx, sy = rot([(7.5, 24)], ang, to=to)[0]
    a.poly(spark((sx + 6.5, sy - 1.5), 4.2), flat=pal["white"])
    return (3, 3)


def arrow_orb(a, pal):
    a.poly([(10, 10), (31, 27), (29, 31), (27.5, 33)] and tail((10, 10), (31, 33), 6.2), pal["mid"], pal["lo"])
    a.circle((10, 10), 7.4, pal["light"], pal["mid"])
    a.circle((8, 7.6), 2.4, flat=pal["white"])
    return (10, 10)


def arrow_feather(a, pal):
    ang = -42
    to = (3.5, 3.5)
    right = bez((0, 5), (13, 11), (2.5, 38), 14) + bez((2.5, 38), (0, 40), (0, 38), 3)
    left = bez((0, 5), (-12, 13), (-1.5, 36), 14)
    vane = left + right[::-1][:0] + right
    a.poly(rot(vane, ang, to=to), pal["hi"], pal["mid"])
    a.poly(rot(right, ang, to=to), pal["light"], pal["hi"])
    a.poly(rot([(0, 0), (1.9, 5.5), (-1.9, 5.5)], ang, to=to), flat=pal["nib"])
    a.detail(lambda d: ln(d, rot([(0, 3), (0.3, 40)], ang, to=to), pal["lo"], 0.7))
    for yy in (12, 18, 24, 30):
        a.detail(lambda d, yy=yy: ln(d, rot([(0.2, yy), (6.5 - yy * 0.05, yy + 5)], ang, to=to), pal["lo"], 0.35))
    return (3, 3)


def arrow_flame(a, pal):
    ang = -35
    to = (4, 4)
    outer = (bez((0, 0), (8.5, 9), (8.5, 19)) + bez((8.5, 19), (8.5, 28), (0, 32))[1:]
             + bez((0, 32), (-9.5, 28), (-8, 19))[1:] + bez((-8, 19), (-7.5, 14), (-3, 11))[1:]
             + bez((-3, 11), (-2.5, 6), (0, 0))[1:])
    a.poly(rot(outer, ang, to=to), pal["hi"], pal["lo"])
    inner = [(x * 0.55, 13 + y * 0.55) for x, y in outer]
    a.poly(rot(inner, ang, to=to), pal["light"], pal["mid"])
    return (4, 4)


def arrow_rune(a, pal):
    ang = -45
    to = (3.5, 3.5)
    kite = [(0, 0), (7.2, 12), (0, 33), (-7.2, 12)]
    a.poly(rot(kite, ang, to=to), pal["light"], pal["mid"])
    a.poly(rot([(0, 0), (7.2, 12), (0, 33), (0, 14)], ang, to=to), pal["hi"], pal["lo"])
    rune = [(0, 11), (0, 25)], [(0, 14), (4, 10.5)], [(0, 19), (4, 15.5)]
    for seg in rune:
        a.detail(lambda d, seg=seg: ln(d, rot(list(seg), ang, to=to), pal["white"], 0.9))
    return (3, 3)


def arrow_star(a, pal):
    ang = -45
    to = (8, 8)
    rod = rot([(-1.4, 6), (1.4, 6), (1.4, 33), (-1.4, 33)], ang, to=to)
    a.poly(rod, pal["hi"], pal["lo"])
    a.poly(spark((8, 8), 9.2, inner=0.4), pal["white"], pal["light"])
    a.circle((8, 8), 2.0, flat=pal["mid"])
    return (8, 8)


def arrow_shadow(a, pal):
    body = [(3, 3), (10, 34), (15, 27), (23, 37), (27, 33), (19, 23.5), (28, 21)]
    a.poly(body, pal["hi"], pal["lo"])
    a.poly([(3, 3), (10, 34), (15, 27), (14, 15)], pal["light"], pal["mid"])
    return (3, 3)


def tail(head, end, w):
    # comète : queue effilée de la tête vers [end]
    dx, dy = end[0] - head[0], end[1] - head[1]
    L = math.hypot(dx, dy)
    nx, ny = -dy / L, dx / L
    return [(head[0] + nx * w, head[1] + ny * w), end, (head[0] - nx * w, head[1] - ny * w)]


def spark(c, r, inner=0.28):
    pts = []
    for i in range(8):
        rr = r if i % 2 == 0 else r * inner
        ang = math.radians(-90 + i * 45)
        pts.append((c[0] + rr * math.cos(ang), c[1] + rr * math.sin(ang)))
    return pts


# ---- main, poing, texte ------------------------------------------------------------------------------
def hand(a, pal, mark):
    hi, lo, light = pal["hi"], pal["lo"], pal["light"]
    a.rrect((14, 3, 22.5, 28), 4.2, light, hi)               # index
    a.rrect((22, 13, 29.5, 30), 3.6, hi, lo)                # majeur replié
    a.rrect((29, 15.5, 36, 31), 3.4, hi, lo)                # annulaire
    a.rrect((35.5, 18, 42, 32), 3.1, hi, lo)                # auriculaire
    a.rrect((11, 24, 42, 41), 5, light, hi)                 # paume
    a.rrect((5, 25, 16, 36), 4.5, light, hi)                # pouce
    a.rrect((12.5, 38, 41, 45), 2.4, pal.get("cuff_hi", hi), pal.get("cuff_lo", lo))  # manchette
    for x in (22, 29.2, 35.8):
        a.detail(lambda d, x=x: ln(d, [(x, 15), (x, 27)], pal["lo"], 0.6))
    mark(a, pal, (27, 33))
    return (18, 3)


def fist(a, pal, mark):
    hi, lo, light = pal["hi"], pal["lo"], pal["light"]
    a.rrect((10, 18, 42, 40), 6, light, hi)
    for x in (15.5, 23.2, 30.8, 38):
        a.circle((x, 19), 4.4, light, hi)
    a.rrect((12, 29, 32, 38), 4.2, hi, lo)                  # pouce rabattu
    a.rrect((12.5, 38, 40, 45), 2.4, pal.get("cuff_hi", hi), pal.get("cuff_lo", lo))
    for x in (19.2, 27, 34.5):
        a.detail(lambda d, x=x: ln(d, [(x, 15.5), (x, 25)], pal["lo"], 0.6))
    mark(a, pal, (36, 33.5))
    return (26, 28)


def ibeam(a, pal):
    a.rrect((21.8, 5, 26.2, 43), 1.0, pal["light"], pal["mid"])
    a.rrect((16, 3.4, 32, 7.2), 1.2, pal["hi"], pal["lo"])
    a.rrect((16, 40.8, 32, 44.6), 1.2, pal["hi"], pal["lo"])
    return (24, 24)


def mark_gem(a, pal, c):
    a.poly([(c[0], c[1] - 3.4), (c[0] + 3, c[1]), (c[0], c[1] + 3.4), (c[0] - 3, c[1])], pal["accent_hi"], pal["accent_lo"])


def mark_dot(a, pal, c):
    a.circle(c, 2.5, pal["accent_hi"], pal["accent_lo"])


def mark_star(a, pal, c):
    a.poly(spark(c, 3.6, 0.35), pal["accent_hi"], pal["accent_lo"])


def mark_rune(a, pal, c):
    for seg in ([(c[0], c[1] - 3.3), (c[0], c[1] + 3.3)], [(c[0], c[1] - 1.6), (c[0] + 2.6, c[1] - 3.6)], [(c[0], c[1] + 0.6), (c[0] + 2.6, c[1] - 1.4)]):
        a.detail(lambda d, seg=seg: ln(d, seg, pal["accent_hi"], 0.9))


def mark_none(a, pal, c):
    a.detail(lambda d: ln(d, [(c[0] - 3, c[1] + 0.5), (c[0] + 3, c[1] + 0.5)], pal["lo"], 0.6))


def mark_flame(a, pal, c):
    a.poly([(c[0], c[1] - 3.8), (c[0] + 2.6, c[1] + 0.4), (c[0] + 1.2, c[1] + 3), (c[0] - 1.2, c[1] + 3), (c[0] - 2.6, c[1] + 0.4)], pal["accent_hi"], pal["accent_lo"])


def pal(hi, mid, lo, light, **kw):
    d = dict(hi=hi, mid=mid, lo=lo, light=light, white="#ffffff", accent_hi="#ffffff", accent_lo="#cccccc")
    d.update(kw)
    return d


SETS = {
    "gauntlet": (pal("#f8c75a", "#e3a73a", "#a8731f", "#ffe9a8", accent_hi="#7fe0ff", accent_lo="#2a78d6", cuff_hi="#b98a35", cuff_lo="#7a5114"), arrow_gauntlet, mark_gem),
    "blade": (pal("#b9c4dc", "#cdd6ea", "#6c7a9c", "#f4f7ff", gold_hi="#ffd978", gold_lo="#b07a22", grip_hi="#8a5a2a", grip_lo="#4a2d12",
                  accent_hi="#ffd978", accent_lo="#b07a22", cuff_hi="#8a98b8", cuff_lo="#4c5878"), arrow_blade, mark_none),
    "crystal": (pal("#4fb4ff", "#9fe0ff", "#2563c9", "#dcfaff", glow="#59c6ff", glow_a=0.45, accent_hi="#ffffff", accent_lo="#b9ecff"), arrow_crystal, mark_gem),
    "orb": (pal("#b277ff", "#cf9bff", "#5a2aa8", "#f1dcff", glow="#a064ff", glow_a=0.6, accent_hi="#ffffff", accent_lo="#e6ccff"), arrow_orb, mark_dot),
    "feather": (pal("#f3e6d0", "#f8eedd", "#c9a97a", "#ffffff", nib="#8a5a2a", accent_hi="#c98a4a", accent_lo="#8a5a2a", cuff_hi="#d8b88a", cuff_lo="#9a7a4a"), arrow_feather, mark_none),
    "flame": (pal("#ff9a2e", "#ffc24a", "#d4351c", "#fff2a0", glow="#ff7a2a", glow_a=0.45, accent_hi="#fff2a0", accent_lo="#ffb030"), arrow_flame, mark_flame),
    "rune": (pal("#5be3a6", "#a8f2cf", "#1f8f6e", "#d8ffe8", accent_hi="#0e4a3a", accent_lo="#0e4a3a"), arrow_rune, mark_rune),
    "star": (pal("#ffd86a", "#ffe9a0", "#ff9f43", "#fffbe0", glow="#ffd86a", glow_a=0.5, accent_hi="#ff9f43", accent_lo="#d4701e"), arrow_star, mark_star),
    "shadow": (pal("#7d58d6", "#9c7cf0", "#2a1560", "#b79cff", outline="#dcd0ff", outline_w=1.0, glow="#7a4cff", glow_a=0.55, accent_hi="#e9ddff", accent_lo="#b79cff"), arrow_shadow, mark_star),
}


def build(set_id):
    p, arrow_fn, mark_fn = SETS[set_id]
    arts = {}
    hot = {}
    a = Art(p)
    a.glow = True
    hot["arrow"] = arrow_fn(a, p)
    arts["arrow"] = a
    a = Art(p)
    hot["hand"] = hand(a, p, mark_fn)
    arts["hand"] = a
    a = Art(p)
    hot["text"] = ibeam(a, p)
    arts["text"] = a
    a = Art(p)
    hot["drag"] = fist(a, p, mark_fn)
    arts["drag"] = a
    return {k: v.render() for k, v in arts.items()}, hot


def main():
    os.makedirs(OUT, exist_ok=True)
    hotspots = {}
    sheet = []
    for sid in SETS:
        imgs, hot = build(sid)
        hotspots[sid] = {k: [int(round(v[0])), int(round(v[1]))] for k, v in hot.items()}
        for kind, im in imgs.items():
            for size in (32, 48):
                im.resize((size, size), Image.LANCZOS).save(os.path.join(OUT, "%s_%s_%d.png" % (sid, kind, size)))
        sheet.append((sid, imgs))
    # points chauds (grille de 48 unités) : fichier généré lu par cursor_sets.gd
    out = ["# Écrit par tools/make_cursors.py : ne pas modifier à la main.", "extends RefCounted", "", "const TABLE := {"]
    for sid, h in hotspots.items():
        out.append('	"%s": {%s},' % (sid, ", ".join('"%s": Vector2i(%d, %d)' % (k, v[0], v[1]) for k, v in h.items())))
    out.append("}")
    with open(GD, "w", encoding="utf-8", newline=chr(10)) as f:
        f.write(chr(10).join(out) + chr(10))
    if "--sheet" in sys.argv:
        path =sys.argv[sys.argv.index("--sheet") + 1]
        cell = 64
        W = cell * 5 * 2 + 20
        sh = Image.new("RGBA", (W, cell * len(sheet)), (0, 0, 0, 0))
        for i, (sid, imgs) in enumerate(sheet):
            for side, bg in enumerate(((235, 235, 240), (24, 22, 40))):
                ox = side * (cell * 5 + 20)
                ImageDraw.Draw(sh).rectangle([ox, i * cell, ox + cell * 5, (i + 1) * cell], fill=bg + (255,))
                for j, kind in enumerate(("arrow", "hand", "text", "drag")):
                    t = imgs[kind].resize((48, 48), Image.LANCZOS)
                    sh.alpha_composite(t, (ox + 8 + j * cell, i * cell + 8))
        sh.save(path)
    print("cursors ok:", ", ".join(SETS))


if __name__ == "__main__":
    main()
