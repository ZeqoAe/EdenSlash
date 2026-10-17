"""Icônes « tile » de la classe maison n° 61 « Ninja du Tourbillon » (lot CHR-1) : ses 4 sorts et la classe.
Formes génériques calculées ici (étoiles de lancer, sphère en spirale, silhouettes, tourbillon) : aucun symbole d'une œuvre.
Repère de la tuile 0..100 (utile 10..90)."""
import math

from ico_kit import *  # noqa: F401,F403

G = "Ninja du Tourbillon (classe maison)"


def _spiral(cx, cy, r0, r1, turns, a0=0.0, steps=48):
    pts = []
    for i in range(steps + 1):
        t = i / steps
        a = math.radians(a0) + t * turns * 2 * math.pi
        r = r0 + (r1 - r0) * t
        pts.append((cx + r * math.cos(a), cy + r * math.sin(a)))
    return smooth(pts, close=False, k=0.16)


def _person(cx, cy, k=1.0):
    """Silhouette ramassée (tête ronde, épaules, corps) : un double de brume."""
    head = circ(cx, cy - 20 * k, 11 * k)
    body = smooth([(cx - 17 * k, cy + 26 * k), (cx - 15 * k, cy + 2 * k), (cx - 8 * k, cy - 7 * k), (cx + 8 * k, cy - 7 * k),
                   (cx + 15 * k, cy + 2 * k), (cx + 17 * k, cy + 26 * k)], close=True, k=0.12)
    return head, body


@icon("sk_whirl_double", "tile", "amethyste", G, "Double de brume : deux silhouettes dans la fumée")
def _(s):
    # double du fond, plus pâle
    h, b = _person(64, 44, 0.9)
    s.inked(b, "#D9CCF5", 4.0)
    s.inked(h, "#D9CCF5", 4.0)
    h, b = _person(38, 50, 1.0)
    wfill(s, b)
    wfill(s, h)
    # bouffées de fumée
    for (x, y, r) in [(22, 80, 10), (38, 84, 12), (56, 82, 11), (73, 79, 10)]:
        s.inked(circ(x, y, r), "#F4F0FF", 3.5)
    s.fill(circ(35, 82, 4), "#FFFFFF")


@icon("sk_whirl_star", "tile", "mandarine", G, "Étoiles filantes : trois étoiles de lancer en éventail")
def _(s):
    wline(s, "M14 86 L30 70 M22 92 L40 76 M10 72 L22 62", 5, "#FFE6C8", 3)
    for (x, y, R, rot) in [(30, 58, 15, -70), (53, 36, 19, -95), (76, 60, 15, -80)]:
        wfill(s, poly(star(x, y, 4, R, R * 0.32, rot)), WHITE, 4)
        s.fill(circ(x, y, R * 0.18), tone("mandarine", 2))


@icon("sk_whirl_orb", "tile", "lagon", G, "Sphère tourbillon : sphère d'énergie en spirale")
def _(s):
    # anneau de vent
    wline(s, arc(50, 52, 38, 200, 320), 5, "#E4FAFF", 3)
    wline(s, arc(50, 52, 38, 20, 140), 5, "#E4FAFF", 3)
    wfill(s, circ(50, 52, 27), WHITE, 4.5)
    dark = tone("lagon", 2)
    for a0 in (0, 120, 240):
        s.line(_spiral(50, 52, 3, 23, 0.55, a0), 4.5, dark)
    s.fill(circ(50, 52, 6), tone("lagon", 1))
    s.gloss(ell(41, 40, 7, 4), 0.8)


@icon("sk_whirl_ult", "tile", "soleil", G, "Étoile du Tourbillon : grande étoile à lames de vent autour d'une sphère")
def _(s):
    blades = []
    for b in range(4):
        a = b * 90 - 45
        # lame courbe effilée : base large près du cœur, pointe rejetée vers l'arrière
        pol = [(13, -32), (13, 12), (24, 22), (34, 34), (44, 52), (31, 22), (22, 0)]
        pts = [(50 + r * math.cos(math.radians(a + d)), 50 + r * math.sin(math.radians(a + d))) for r, d in pol]
        blades.append(smooth(pts, close=True, k=0.12))
    for d in blades:
        wfill(s, d, WHITE, 4)
    s.inked(circ(50, 50, 15), "#BDEBFF", 4)
    s.line(_spiral(50, 50, 2, 12, 0.7, 30), 3.5, tone("lagon", 2))
    wfill(s, sparkle(82, 20, 8, 2.5), WHITE, 2.5)
    wfill(s, sparkle(18, 80, 6, 2), WHITE, 2.5)


@icon("cls_whirl_ninja", "tile", "mandarine", G, "Classe : Ninja du Tourbillon (tourbillon)")
def _(s):
    wline(s, _spiral(50, 50, 4, 36, 1.6, 200), 10, WHITE, 4)
    wfill(s, sparkle(80, 22, 9, 3), WHITE, 3)
