# -*- coding: utf-8 -*-
"""Kits de partie des Deux Voies (lot MB-A, conception/benchmark/MOBA.md § 7.6, rapport R_MB_A.md).

Lit game/data/classes.json (les sorts des 60 classes, dans l'ordre du jeu : 4 sorts principaux puis les enchaînements
de chaque case, comme MlDuelPilot.kit_for) et écrit game/data/moba_kits.json : pour chaque classe, 3 cases de base + 1
ultime, chacune avec ses enchaînements (2 pour les cases de base, 1 pour l'ultime). Aucun kit n'est écrit à la main.

Règles du tri (MOBA.md § 7.6), par classe :
  - au moins un sort de déplacement s'il existe (dash, blink, ou un sort qui fait avancer) ;
  - au moins un sort de contrôle s'il existe (renversement, gel, sommeil, terreur, immobilisation, désarmement, ralenti,
    attraction) ;
  - au moins un soin pour la Ferveur (famille 4) s'il en existe un ;
  - ultime = le sort offensif de plus forte valeur (multiplicateur × coups × zone) parmi ceux de plus de 12 s de
    recharge (à défaut : de plus forte valeur), recharge portée à 60-90 s, puissance × 1,6 ; pour la Ferveur : le soin de
    plus forte valeur (renfort d'équipe à défaut) ;
  - le reste des cases : les sorts principaux de la classe d'abord (ordre du jeu), puis les plus forts ;
  - enchaînements : parmi les sorts restants, les plus forts d'abord (offensifs pour les cases offensives).

    python tools/moba_kits.py            # écrit game/data/moba_kits.json
    python tools/moba_kits.py --check    # vérifie que le fichier est à jour (code de sortie 1 sinon)
"""
import json
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "game", "data", "classes.json")
DST = os.path.join(ROOT, "game", "data", "moba_kits.json")

FERVEUR = 4
CONTROL = {"stun", "freeze", "sleep", "fear", "root", "disarm", "chill"}
ULT_POWER = 1.6
ULT_CD_MIN = 60.0
ULT_CD_MAX = 90.0
ULT_FROM_CD = 12.0


def offensive(s):
    return s.get("kind") not in ("buff", "heal")


def is_heal(s):
    return s.get("kind") == "heal" or float(s.get("heal", 0.0) or 0.0) > 0.0


def is_mobility(s):
    return s.get("kind") in ("dash", "blink") or float(s.get("dash", 0.0) or 0.0) > 0.0 or "move_dir" in s


def is_control(s):
    ap = s.get("applies", {}) or {}
    return bool(CONTROL.intersection(ap.keys())) or float(s.get("pull", 0.0) or 0.0) > 0.0


def value(s):
    """Valeur d'un sort : multiplicateur × coups (× salves) × zone (1 + rayon / 4) ; soin : part soignée × 10."""
    if is_heal(s) and not offensive(s):
        return float(s.get("heal", 0.2) or 0.2) * 10.0
    if not offensive(s):
        return 0.0
    hits = max(1, int(s.get("hits", 1) or 1)) * max(1, int(s.get("volley", 1) or 1))
    return float(s.get("mult", 0.0)) * hits * (1.0 + float(s.get("radius", 0.0)) / 4.0)


def ult_cooldown(s):
    return round(min(ULT_CD_MAX, max(ULT_CD_MIN, float(s.get("cooldown", 15.0)) * 4.0)), 1)


def build_kit(cid, c):
    skills = list(c.get("skills", []))
    order = {int(s["id"]): i for i, s in enumerate(skills)}
    fam = int(c.get("family", 0))
    used = set()

    def best(cands):
        cands = [s for s in cands if int(s["id"]) not in used]
        if not cands:
            return None
        return max(cands, key=lambda s: (value(s), -order[int(s["id"])]))

    # ultime
    if fam == FERVEUR:
        ult = best([s for s in skills if is_heal(s) and not offensive(s)]) or best([s for s in skills if not offensive(s)])
        ult_kind = "support"
        if ult is None:
            ult = best([s for s in skills if offensive(s)])
            ult_kind = "offense"
    else:
        ult = best([s for s in skills if offensive(s) and float(s.get("cooldown", 0.0)) > ULT_FROM_CD]) \
            or best([s for s in skills if offensive(s)])
        ult_kind = "offense"
    used.add(int(ult["id"]))
    # cases de base : déplacement, contrôle, soin (Ferveur), puis les principaux
    base = []
    needs = [is_mobility, is_control]
    if fam == FERVEUR:
        needs.append(lambda s: is_heal(s) and not offensive(s))
    covered = lambda pred: any(pred(s) for s in base) or pred(ult)  # noqa: E731
    for pred in needs:
        if len(base) >= 3 or covered(pred):
            continue
        s = best([x for x in skills if pred(x)])
        if s is not None:
            base.append(s)
            used.add(int(s["id"]))
    main = [s for s in skills[:4] if offensive(s)]
    while len(base) < 3:
        s = best(main) or best([x for x in skills if offensive(x)]) or best(skills)
        if s is None:
            break
        base.append(s)
        used.add(int(s["id"]))
    base.sort(key=lambda s: order[int(s["id"])])
    # enchaînements : 2 par case de base, 1 pour l'ultime
    slots = []
    for s in base + [ult]:
        n = 1 if s is ult else 2
        pref_off = offensive(s)
        chains = []
        for _ in range(n):
            pick = best([x for x in skills if offensive(x) == pref_off]) or best(skills)
            if pick is None:
                break
            chains.append(int(pick["id"]))
            used.add(int(pick["id"]))
        slots.append({"main": int(s["id"]), "chains": chains})
    return {
        "slots": slots,
        "ult": {"id": int(ult["id"]), "kind": ult_kind, "cooldown": ult_cooldown(ult), "power": ULT_POWER},
        "family": fam,
        "has": {"mobility": any(is_mobility(s) for s in skills), "control": any(is_control(s) for s in skills),
                "heal": any(is_heal(s) and not offensive(s) for s in skills)},
    }


def build():
    with open(SRC, encoding="utf-8") as f:
        classes = json.load(f)
    out = {"_doc": "Kits des Deux Voies : généré par tools/moba_kits.py depuis data/classes.json (ne pas modifier à la main)."}
    for cid in sorted(classes):
        out[cid] = build_kit(cid, classes[cid])
    return out


def dump(data):
    return json.dumps(data, ensure_ascii=False, indent=1, sort_keys=False) + "\n"


def main():
    data = build()
    text = dump(data)
    if "--check" in sys.argv:
        old = open(DST, encoding="utf-8").read() if os.path.exists(DST) else ""
        if old != text:
            print("moba_kits.json n'est pas à jour : relancer python tools/moba_kits.py")
            return 1
        print("moba_kits.json à jour (%d classes)" % (len(data) - 1))
        return 0
    with open(DST, "w", encoding="utf-8", newline="\n") as f:
        f.write(text)
    n_ult_off = sum(1 for k, v in data.items() if k != "_doc" and v["ult"]["kind"] == "offense")
    print("écrit %s : %d classes (%d ultimes offensifs)" % (os.path.relpath(DST, ROOT), len(data) - 1, n_ult_off))
    return 0


if __name__ == "__main__":
    sys.exit(main())
