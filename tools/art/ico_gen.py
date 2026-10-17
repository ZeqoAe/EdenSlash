#!/usr/bin/env python3
"""Pictogrammes d'interface d'Eden Slash (département Icônes, lot ICO-1) : SVG fabriqués par code, rendus par le moteur.

    python tools/art/ico_gen.py                 # SVG -> conception/art/ico/svg/, PNG 128 et 64 -> game/assets/ui/icons/, planche
    python tools/art/ico_gen.py --svg-only      # seulement les SVG
    python tools/art/ico_gen.py --only check,lock,boss_meteors

Style (BIBLE.md §1, §5, §9) : autocollant d'encre et de bonbon. Contour d'encre épais (#221A3A), aplat en deux tons nets
(clair / base / foncé des jetons `bonbon.*`), petit reflet blanc, ombre dure décalée. Trois familles :
  - « tile »  : tuile arrondie bonbon + symbole blanc contouré d'encre (comme les icônes d'état du jeu) ;
  - « glyph » : forme libre autocollante (coche, cadenas, étoile…) qui se pose en ligne dans un texte ;
  - « sym »   : symbole blanc contouré d'encre sans tuile (mécaniques de boss : la pastille donne la couleur ; silhouettes
    d'emplacements : teintées à l'usage).
Aucune image tierce : seulement des formes calculées ici. Rasterisation : tools/art/ico_render.gd (ThorVG du moteur).
Les définitions sont dans ico_defs_*.py (chacune appelle `icon(...)`)."""
import argparse
import os
import subprocess
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import ico_core as C
from ico_core import REG, GROUPS, OUT_SVG, OUT_PNG, GODOT, HERE, ROOT, render_svg


def load_defs():
    sys.path.insert(0, HERE)
    import importlib
    for m in ("ico_defs_a", "ico_defs_b", "ico_defs_c"):
        if os.path.exists(os.path.join(HERE, m + ".py")):
            importlib.import_module(m)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--svg-only", action="store_true")
    ap.add_argument("--only", default="")
    ap.add_argument("--no-sheet", action="store_true")
    a = ap.parse_args()
    load_defs()
    ids = [i for i in REG if not a.only or i in a.only.split(",")]
    os.makedirs(OUT_SVG, exist_ok=True)
    for i in ids:
        with open(os.path.join(OUT_SVG, "ico_%s.svg" % i), "w", encoding="utf-8") as f:
            f.write(render_svg(i))
    print("[ico] %d SVG dans %s" % (len(ids), OUT_SVG))
    if a.svg_only:
        return
    os.makedirs(OUT_PNG, exist_ok=True)
    r = subprocess.run([GODOT, "--headless", "--path", os.path.join(ROOT, "game"), "--script", os.path.join(HERE, "ico_render.gd"), "--",
                        OUT_SVG, OUT_PNG], capture_output=True, text=True, timeout=600)
    print(r.stdout.strip()[-600:])
    if r.returncode != 0:
        print(r.stderr[-1500:])
        sys.exit(r.returncode)
    import json
    man = {i: {"kind": REG[i]["kind"], "group": REG[i]["group"], "desc": REG[i]["desc"]} for i in sorted(REG)}
    with open(os.path.join(OUT_PNG, "ico_manifest.json"), "w", encoding="utf-8") as f:
        json.dump(man, f, ensure_ascii=False, indent=1)
    if not a.no_sheet:
        import ico_sheet
        ico_sheet.make(REG, GROUPS)


if __name__ == "__main__":
    main()
