#!/usr/bin/env python3
"""Rapport du journal de run (lot 16) : applique les règles de décision de la conception
(conception/equilibrage/raffinement_3.md, §2) aux lignes de `journal.jsonl`.

Usage : python tools/journal_report.py [chemin du journal] [--min 5]

Le journal est écrit par le jeu (core/run_journal.gd) dans
%APPDATA%/Godot/app_userdata/Eden Slash/journal.jsonl. Une ligne = une carte jouée.
Aucun réglage d'époque ni d'économie ne se fait sans ≥ 5 cartes par style et par époque.
"""
import json
import os
import statistics
import sys

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8")
from collections import defaultdict

DEFAULT = os.path.join(os.environ.get("APPDATA", ""), "Godot", "app_userdata", "Eden Slash", "journal.jsonl")


def load(path):
    rows = []
    with open(path, encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if line:
                try:
                    rows.append(json.loads(line))
                except json.JSONDecodeError:
                    pass
    return rows


def mean(xs):
    xs = [x for x in xs if x is not None and x >= 0]
    return statistics.mean(xs) if xs else None


def decide(rows, minimum=5):
    """Renvoie la liste des constats (texte) pour les cartes de Survie."""
    surv = [r for r in rows if r.get("mode") == "survival"]
    out = []
    by = defaultdict(list)
    for r in surv:
        by[(int(r.get("epoch", 0)), r.get("style", "mixte"))].append(r)
    out.append("Cartes de Survie journalisées : %d" % len(surv))
    for (ep, style), rs in sorted(by.items()):
        out.append("  époque %d · %-7s : %d carte(s) · dégâts subis/min %.1f · temps pour tuer un normal %.2f s · DPS boss 10 s %.1f" % (
            ep, style, len(rs), mean([r.get("dmg_taken_min") for r in rs]) or 0.0,
            mean([r.get("ttk_normal") for r in rs]) or 0.0, mean([r.get("dps_boss_10s") for r in rs]) or 0.0))
    eps = sorted({ep for ep, _ in by})
    for a, b in zip(eps, eps[1:]):
        ok = True
        for style in ("coffres", "farm"):
            ra, rb = by.get((a, style), []), by.get((b, style), [])
            if len(ra) < minimum or len(rb) < minimum:
                ok = False
        if not ok:
            out.append("Époque %d -> %d : pas assez de cartes (≥ %d par style) pour conclure." % (a, b, minimum))
            continue
        hits = []
        slow = []
        for style in ("coffres", "farm"):
            da, db = mean([r.get("dmg_taken_min") for r in by[(a, style)]]), mean([r.get("dmg_taken_min") for r in by[(b, style)]])
            ta, tb = mean([r.get("ttk_normal") for r in by[(a, style)]]), mean([r.get("ttk_normal") for r in by[(b, style)]])
            hits.append(bool(da and db and db > 1.5 * da))
            slow.append(bool(ta and tb and tb > 1.4 * ta))
        if all(hits):
            out.append("Époque %d -> %d : « frappent trop » (dégâts subis ×1,5 dans les deux styles) : régler les dégâts." % (a, b))
        if all(slow):
            out.append("Époque %d -> %d : « tiennent trop » (temps pour tuer ×1,4 dans les deux styles) : régler les PV." % (a, b))
        if not any(hits) and not any(slow):
            out.append("Époque %d -> %d : rien à régler." % (a, b))
    # économie : les deux styles doivent arriver au boss à puissance voisine
    for ep in eps:
        c, f = by.get((ep, "coffres"), []), by.get((ep, "farm"), [])
        if len(c) >= minimum and len(f) >= minimum:
            dc, df = mean([r.get("dps_boss_10s") for r in c]), mean([r.get("dps_boss_10s") for r in f])
            if dc and df and abs(dc - df) / max(dc, df) > 0.25:
                if dc > df:
                    out.append("Époque %d : le style coffres est devant (DPS boss %.0f contre %.0f) : or des objets cassés -15 %%." % (ep, dc, df))
                else:
                    out.append("Époque %d : le style farm est devant (DPS boss %.0f contre %.0f) : prix des coffres -10 %%." % (ep, df, dc))
            else:
                out.append("Époque %d : styles à puissance voisine au boss (écart ≤ 25 %%)." % ep)
    # aide automatique : trop forte ?
    auto = [r.get("ttk_boss") for r in surv if r.get("auto") and (r.get("ttk_boss") or -1) > 0]
    manual = [r.get("ttk_boss") for r in surv if not r.get("auto") and (r.get("ttk_boss") or -1) > 0]
    if len(auto) >= minimum and len(manual) >= minimum:
        ma, mm = statistics.mean(auto), statistics.mean(manual)
        out.append("Aide auto : boss tué en %.1f s contre %.1f s à la main%s." % (ma, mm, " — bridage à étudier (> 20 % plus vite)" if ma < 0.8 * mm else ""))
    return out


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    minimum = 5
    if "--min" in sys.argv:
        minimum = int(sys.argv[sys.argv.index("--min") + 1])
        args = [a for a in args if a != str(minimum)]
    path = args[0] if args else DEFAULT
    if not os.path.exists(path):
        print("Journal introuvable :", path)
        return 1
    for line in decide(load(path), minimum):
        print(line)
    return 0


if __name__ == "__main__":
    sys.exit(main())
