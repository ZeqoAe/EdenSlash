#!/usr/bin/env python3
"""Contrôle de la palette d'équipes (lot MODE-0) : écart de couleur entre deux équipes, vision normale et daltonismes.

    python tools/team_palette_check.py            # tableau des écarts, code de sortie 1 si une paire est trop proche
    python tools/team_palette_check.py --json     # mêmes mesures en JSON

Lit `couleur.equipe` de game/data/ui_tokens.json (ordre `ordre`, teinte `base` de chaque équipe). Simulation des trois
daltonismes complets (matrices de Machado, Oliveira et Fernandes 2009, sévérité 1,0, en RGB linéaire), puis écart CIEDE2000
dans l'espace Lab (D65). Seuils : vision normale ΔE ≥ 20 pour toute paire ; daltonismes ΔE ≥ 8 pour toute paire (sous ce
seuil, deux équipes ne se distinguent que par leur motif : la règle du jeu est de TOUJOURS montrer le motif avec la couleur).
Les paires entre 8 et 12 sont signalées « à motif » (lisibles, mais le motif fait le travail).
"""
import argparse
import json
import math
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
TOKENS = ROOT / "game" / "data" / "ui_tokens.json"

MACHADO = {
    "protanopie": [[0.152286, 1.052583, -0.204868], [0.114503, 0.786281, 0.099216], [-0.003882, -0.048116, 1.051998]],
    "deuteranopie": [[0.367322, 0.860646, -0.227968], [0.280085, 0.672501, 0.047413], [-0.011820, 0.042940, 0.968881]],
    "tritanopie": [[1.255528, -0.076749, -0.178779], [-0.078411, 0.930809, 0.147602], [0.004733, 0.691367, 0.303900]],
}
SEUIL_NORMAL = 20.0
SEUIL_DALTON = 8.0
SEUIL_MOTIF = 12.0


def hex_rgb(h: str) -> tuple:
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4))


def lin(c: float) -> float:
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def delin(c: float) -> float:
    c = min(max(c, 0.0), 1.0)
    return 12.92 * c if c <= 0.0031308 else 1.055 * c ** (1 / 2.4) - 0.055


def simulate(rgb: tuple, kind: str) -> tuple:
    if kind == "normal":
        return rgb
    m = MACHADO[kind]
    l = [lin(c) for c in rgb]
    out = [sum(m[i][j] * l[j] for j in range(3)) for i in range(3)]
    return tuple(delin(c) for c in out)


def lab(rgb: tuple) -> tuple:
    r, g, b = (lin(c) for c in rgb)
    x = (0.4124 * r + 0.3576 * g + 0.1805 * b) / 0.95047
    y = 0.2126 * r + 0.7152 * g + 0.0722 * b
    z = (0.0193 * r + 0.1192 * g + 0.9505 * b) / 1.08883

    def f(t):
        return t ** (1 / 3) if t > 216 / 24389 else (24389 / 27 * t + 16) / 116
    fx, fy, fz = f(x), f(y), f(z)
    return 116 * fy - 16, 500 * (fx - fy), 200 * (fy - fz)


def ciede2000(a: tuple, b: tuple) -> float:
    l1, a1, b1 = a
    l2, a2, b2 = b
    c1, c2 = math.hypot(a1, b1), math.hypot(a2, b2)
    cm = (c1 + c2) / 2
    g = 0.5 * (1 - math.sqrt(cm ** 7 / (cm ** 7 + 25 ** 7)))
    a1p, a2p = a1 * (1 + g), a2 * (1 + g)
    c1p, c2p = math.hypot(a1p, b1), math.hypot(a2p, b2)
    h1p = math.degrees(math.atan2(b1, a1p)) % 360
    h2p = math.degrees(math.atan2(b2, a2p)) % 360
    dl, dc = l2 - l1, c2p - c1p
    dh = h2p - h1p
    if c1p * c2p == 0:
        dh = 0
    elif dh > 180:
        dh -= 360
    elif dh < -180:
        dh += 360
    dH = 2 * math.sqrt(c1p * c2p) * math.sin(math.radians(dh / 2))
    lm, cmp_ = (l1 + l2) / 2, (c1p + c2p) / 2
    if c1p * c2p == 0:
        hm = h1p + h2p
    elif abs(h1p - h2p) <= 180:
        hm = (h1p + h2p) / 2
    else:
        hm = (h1p + h2p + 360) / 2 if h1p + h2p < 360 else (h1p + h2p - 360) / 2
    t = (1 - 0.17 * math.cos(math.radians(hm - 30)) + 0.24 * math.cos(math.radians(2 * hm))
         + 0.32 * math.cos(math.radians(3 * hm + 6)) - 0.20 * math.cos(math.radians(4 * hm - 63)))
    sl = 1 + 0.015 * (lm - 50) ** 2 / math.sqrt(20 + (lm - 50) ** 2)
    sc = 1 + 0.045 * cmp_
    sh = 1 + 0.015 * cmp_ * t
    rt = -2 * math.sqrt(cmp_ ** 7 / (cmp_ ** 7 + 25 ** 7)) * math.sin(math.radians(60 * math.exp(-((hm - 275) / 25) ** 2)))
    return math.sqrt((dl / sl) ** 2 + (dc / sc) ** 2 + (dH / sh) ** 2 + rt * (dc / sc) * (dH / sh))


def mesurer(palette: dict, ordre: list) -> dict:
    out = {}
    for kind in ["normal", "protanopie", "deuteranopie", "tritanopie"]:
        labs = {k: lab(simulate(hex_rgb(palette[k]), kind)) for k in ordre}
        paires = []
        for i, a in enumerate(ordre):
            for b in ordre[i + 1:]:
                paires.append((round(ciede2000(labs[a], labs[b]), 1), a, b))
        paires.sort()
        out[kind] = paires
    return out


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--json", action="store_true")
    ap.add_argument("-n", type=int, default=0, help="ne mesurer que les n premières équipes de l'ordre")
    args = ap.parse_args()
    tok = json.loads(TOKENS.read_text(encoding="utf-8"))
    eq = tok["couleur"]["equipe"]
    ordre = list(eq["ordre"]) if not args.n else list(eq["ordre"])[: args.n]
    palette = {k: eq[k]["base"]["$value"] for k in ordre}
    res = mesurer(palette, ordre)
    if args.json:
        print(json.dumps({k: [{"de": d, "a": a, "b": b} for d, a, b in v] for k, v in res.items()}, ensure_ascii=False, indent=1))
    rate = False
    for kind, paires in res.items():
        seuil = SEUIL_NORMAL if kind == "normal" else SEUIL_DALTON
        d, a, b = paires[0]
        motif = [f"{x}/{y} {dd}" for dd, x, y in paires if dd < SEUIL_MOTIF] if kind != "normal" else []
        ok = d >= seuil
        rate = rate or not ok
        if not args.json:
            print(f"{kind:13s} écart minimal {d:5.1f} ({a} / {b}) seuil {seuil:4.1f} {'OK' if ok else 'TROP PROCHE'}"
                  + (f" ; à motif : {', '.join(motif)}" if motif else ""))
    return 1 if rate else 0


if __name__ == "__main__":
    sys.exit(main())
