"""Noyau des pictogrammes (ICO-1) : jetons, géométrie, dessin SVG, registre. Le CLI est ico_gen.py."""
import argparse
import json
import math
import os
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
OUT_SVG = os.path.join(ROOT, "conception", "art", "ico", "svg")
OUT_PNG = os.path.join(ROOT, "game", "assets", "ui", "icons")
GODOT = os.environ.get("GODOT", r"C:\Users\Nico\Godot\Godot_v4.7.2-stable_win64.exe")

INK = "#221A3A"
INK_SOFT = "#2E2450"
WHITE = "#FFFFFF"
PAPER = "#FFF8EC"
PAPER3 = "#E9DFCB"

# --- jetons -------------------------------------------------------------------------------------------------
_TOK = json.load(open(os.path.join(ROOT, "conception", "art", "tokens.json"), encoding="utf-8"))["couleur"]["bonbon"]
TONES = {k: (v["clair"]["$value"], v["base"]["$value"], v["fonce"]["$value"]) for k, v in _TOK.items() if isinstance(v, dict) and "clair" in v}
TONES["gris"] = ("#E4DFF0", "#B5AFCB", "#7F7898")  # commun : lilas-gris des raretés
TONES["encre"] = ("#5A4C86", "#3A2E63", "#221A3A")  # tuile sombre (verrou, désactivé)
TONES["bronze"] = ("#F0B27E", "#D98A4A", "#9C5A24")  # rangs de la Ligue
TONES["argent"] = ("#F4F3FA", "#C9C7DA", "#8F8CA8")
TONES["platine"] = ("#C9F6FF", "#7FDDF5", "#3A9DC4")


def n(x):
    return ("%.2f" % x).rstrip("0").rstrip(".")


# --- géométrie ----------------------------------------------------------------------------------------------
def xf(pts, cx=0.0, cy=0.0, ang=0.0, sc=1.0):
    """Points locaux -> points placés (rotation en degrés dans le sens horaire de l'écran, échelle, translation)."""
    a = math.radians(ang)
    ca, sa = math.cos(a), math.sin(a)
    return [(cx + sc * (x * ca - y * sa), cy + sc * (x * sa + y * ca)) for x, y in pts]


def poly(pts, close=True):
    s = "M" + " L".join("%s %s" % (n(x), n(y)) for x, y in pts)
    return s + ("Z" if close else "")


def circ(cx, cy, r):
    return "M%s %s a%s %s 0 1 0 %s 0 a%s %s 0 1 0 %s 0Z" % (n(cx - r), n(cy), n(r), n(r), n(2 * r), n(r), n(r), n(-2 * r))


def ell(cx, cy, rx, ry):
    return "M%s %s a%s %s 0 1 0 %s 0 a%s %s 0 1 0 %s 0Z" % (n(cx - rx), n(cy), n(rx), n(ry), n(2 * rx), n(rx), n(ry), n(-2 * rx))


def rrect(x, y, w, h, r):
    r = min(r, w / 2, h / 2)
    return ("M%s %s H%s Q%s %s %s %s V%s Q%s %s %s %s H%s Q%s %s %s %s V%s Q%s %s %s %sZ" % (
        n(x + r), n(y), n(x + w - r), n(x + w), n(y), n(x + w), n(y + r), n(y + h - r), n(x + w), n(y + h), n(x + w - r), n(y + h),
        n(x + r), n(x), n(y + h), n(x), n(y + h - r), n(y + r), n(x), n(y), n(x + r), n(y)))


def star(cx, cy, k, R, r, rot=-90.0):
    pts = []
    for i in range(k * 2):
        a = math.radians(rot + i * 180.0 / k)
        rr = R if i % 2 == 0 else r
        pts.append((cx + rr * math.cos(a), cy + rr * math.sin(a)))
    return pts


def ngon(cx, cy, k, R, rot=-90.0):
    return [(cx + R * math.cos(math.radians(rot + i * 360.0 / k)), cy + R * math.sin(math.radians(rot + i * 360.0 / k))) for i in range(k)]


def arc(cx, cy, r, a0, a1, move=True):
    """Arc ouvert (angles en degrés, 0 = droite, croissant vers le bas)."""
    x0, y0 = cx + r * math.cos(math.radians(a0)), cy + r * math.sin(math.radians(a0))
    x1, y1 = cx + r * math.cos(math.radians(a1)), cy + r * math.sin(math.radians(a1))
    large = 1 if abs(a1 - a0) > 180 else 0
    sweep = 1 if a1 > a0 else 0
    return ("M%s %s " % (n(x0), n(y0)) if move else "") + "A%s %s 0 %d %d %s %s" % (n(r), n(r), large, sweep, n(x1), n(y1))


def smooth(pts, close=True, k=0.18):
    """Courbe lisse (Catmull-Rom en Bézier) passant par les points."""
    m = len(pts)
    if m < 3:
        return poly(pts, close)
    d = "M%s %s" % (n(pts[0][0]), n(pts[0][1]))
    rng = range(m) if close else range(m - 1)
    for i in rng:
        p0 = pts[(i - 1) % m] if (close or i > 0) else pts[i]
        p1 = pts[i]
        p2 = pts[(i + 1) % m]
        p3 = pts[(i + 2) % m] if (close or i + 2 < m) else pts[(i + 1) % m]
        c1 = (p1[0] + (p2[0] - p0[0]) * k * 1.6667 / 1.6667 * 1.0, p1[1] + (p2[1] - p0[1]) * k * 1.0)
        c2 = (p2[0] - (p3[0] - p1[0]) * k, p2[1] - (p3[1] - p1[1]) * k)
        d += " C%s %s %s %s %s %s" % (n(c1[0]), n(c1[1]), n(c2[0]), n(c2[1]), n(p2[0]), n(p2[1]))
    return d + ("Z" if close else "")


# --- le dessin ----------------------------------------------------------------------------------------------
class Svg:
    def __init__(self, kind):
        self.kind = kind
        self.defs = []
        self.body = []
        self.shadow = []  # silhouettes d'encre décalées (icônes sans tuile)
        self.gid = 0

    # dégradé à bord net : deux tons (haut / bas), `split` = part du haut
    def two_tone(self, top, bottom, split=0.56, vertical=True):
        self.gid += 1
        i = "g%d" % self.gid
        x2, y2 = ("0", "1") if vertical else ("1", "0")
        self.defs.append('<linearGradient id="%s" x1="0" y1="0" x2="%s" y2="%s"><stop offset="0" stop-color="%s"/><stop offset="%s" stop-color="%s"/>'
                         '<stop offset="%s" stop-color="%s"/><stop offset="1" stop-color="%s"/></linearGradient>' % (
                             i, x2, y2, top, n(split), top, n(split), bottom, bottom))
        return "url(#%s)" % i

    def raw(self, s):
        self.body.append(s)

    def path(self, d, fill="none", stroke=None, sw=0, op=None, extra=""):
        a = 'd="%s" fill="%s"' % (d, fill)
        if stroke:
            a += ' stroke="%s" stroke-width="%s" stroke-linejoin="round" stroke-linecap="round"' % (stroke, n(sw))
        if op is not None:
            a += ' opacity="%s"' % n(op)
        self.body.append("<path %s %s/>" % (a, extra))

    # forme contourée d'encre : contour extérieur `ow`, remplissage `fill`
    def inked(self, d, fill, ow=4.5, shadow=True):
        if shadow:
            self.shadow.append('<path d="%s" fill="%s" stroke="%s" stroke-width="%s" stroke-linejoin="round"/>' % (d, INK, INK, n(ow * 2)))
        self.body.append('<path d="%s" fill="%s" stroke="%s" stroke-width="%s" stroke-linejoin="round" stroke-linecap="round"/>' % (d, INK, INK, n(ow * 2)))
        self.body.append('<path d="%s" fill="%s"/>' % (d, fill))

    def inked_line(self, d, w, color=WHITE, ow=4.0, shadow=True):
        if shadow:
            self.shadow.append('<path d="%s" fill="none" stroke="%s" stroke-width="%s" stroke-linecap="round" stroke-linejoin="round"/>' % (d, INK, n(w + ow * 2)))
        self.body.append('<path d="%s" fill="none" stroke="%s" stroke-width="%s" stroke-linecap="round" stroke-linejoin="round"/>' % (d, INK, n(w + ow * 2)))
        self.body.append('<path d="%s" fill="none" stroke="%s" stroke-width="%s" stroke-linecap="round" stroke-linejoin="round"/>' % (d, color, n(w)))

    def line(self, d, w, color, cap="round"):
        self.body.append('<path d="%s" fill="none" stroke="%s" stroke-width="%s" stroke-linecap="%s" stroke-linejoin="round"/>' % (d, color, n(w), cap))

    def fill(self, d, color, op=None):
        self.path(d, color, op=op)

    def gloss(self, d, op=0.6):
        self.body.append('<path d="%s" fill="#FFFFFF" opacity="%s"/>' % (d, n(op)))

    # tuile bonbon (icônes d'état du jeu) : ombre dure, deux tons, bande claire, contour d'encre, reflet
    def tile(self, tone, r=26, bright=True):
        c, b, f = TONES[tone]
        x, y, w = 8.0, 7.0, 108.0
        self.body.append('<path d="%s" fill="%s"/>' % (rrect(x + 4, y + 5, w, w, r), INK))
        fill = self.two_tone(b, f, 0.6)
        self.body.append('<path d="%s" fill="%s"/>' % (rrect(x, y, w, w, r), fill))
        # bande claire en haut (cel) et trait de reflet incliné
        self.body.append('<path d="%s" fill="%s" opacity="0.55"/>' % (rrect(x + 6, y + 6, w - 12, 14, 7), c))
        self.body.append('<path d="%s" fill="none" stroke="%s" stroke-width="7" stroke-linejoin="round"/>' % (rrect(x, y, w, w, r), INK))
        if bright:
            self.body.append('<path d="M%s %s Q%s %s %s %s" fill="none" stroke="#FFFFFF" stroke-width="5" stroke-linecap="round" opacity="0.85"/>' % (
                n(x + 13), n(y + 24), n(x + 13), n(y + 13), n(x + 25), n(y + 12)))

    def build(self):
        head = '<svg xmlns="http://www.w3.org/2000/svg" width="128" height="128" viewBox="0 0 128 128">'
        defs = "<defs>%s</defs>" % "".join(self.defs) if self.defs else ""
        out = head + defs
        if self.kind == "sym" and self.shadow:
            out += '<g transform="translate(3,4)">%s</g>' % "".join(self.shadow)
        return out + "".join(self.body) + "</svg>"


# --- registre -----------------------------------------------------------------------------------------------
REG = {}  # id -> dict(kind, fn, tone, group, desc)
GROUPS = []


def icon(id, kind, tone=None, group="", desc="", scale=None):
    """Décorateur : @icon("check", "glyph", "pomme") def _(s): ... ; la fonction dessine dans `s` (0..100 pour tile et sym, 0..128 pour glyph)."""
    def deco(fn):
        REG[id] = {"kind": kind, "fn": fn, "tone": tone, "group": group, "desc": desc, "scale": scale}
        if group and group not in GROUPS:
            GROUPS.append(group)
        return fn
    return deco


def render_svg(id):
    spec = REG[id]
    s = Svg(spec["kind"])
    if spec["kind"] == "tile":
        s.tile(spec["tone"])
        s.raw('<g transform="translate(14,14)">')
        spec["fn"](s)
        s.raw("</g>")
    elif spec["kind"] == "sym":
        k = spec["scale"] or 1.18
        t = 64 - 50 * k
        s.raw('<g transform="translate(%s,%s) scale(%s)">' % (n(t), n(t - 1), n(k)))
        spec["fn"](s)
        s.raw("</g>")
        # l'ombre dure suit la même transformation
        s.shadow = ['<g transform="translate(%s,%s) scale(%s)">%s</g>' % (n(t), n(t - 1), n(k), "".join(s.shadow))]
    else:
        spec["fn"](s)
    return s.build()


