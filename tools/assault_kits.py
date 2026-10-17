# -*- coding: utf-8 -*-
"""Kits tactiques de L'Assaut (lot TAC-4, conception/benchmark/TACTIQUE.md § 7.5 et 7.6, rapport R_TAC_4.md).

Lit game/data/classes.json (les 14 à 20 sorts de chaque classe) et game/data/autochess_units.json (rôle de combat de
chaque classe) et écrit game/data/assault_kits.json : pour chaque classe, son rôle tactique et 4 cases, SANS enchaînement.
Aucun kit n'est écrit à la main : des règles générales, puis la courte table EXCEPTIONS.

Rôles tactiques (§ 7.6) : tank -> rempart ; combattant, assassin -> ouvreur ; tireur -> tireur ; mage -> controleur ;
soigneur, soutien -> soutien.

Cases (§ 7.5) :
  1. signature (gratuite) : le sort de dégâts de plus courte recharge (cône, zone, tourbillon, tir…) ;
  2. (achetée) : la mobilité si la classe en a une (dash, blink, sort qui fait avancer), sinon un second sort de dégâts ;
  3. (achetée) : l'utilité de la classe (contrôle, soin, bouclier, renfort, invisibilité) dans l'ordre de préférence du
     rôle ; à défaut un sort de dégâts ;
  4. ultime : le sort offensif de plus forte valeur parmi ceux de plus de 12 s de recharge (à défaut, de plus forte valeur),
     zone +30 %, chargé par 7 points (lot TAC-5).
Prix des cases achetées selon la nature du sort : mobilité 200, dégâts 250, renfort 250, contrôle 300, soin 300, bouclier
300, invisibilité 350.

    python tools/assault_kits.py            # écrit game/data/assault_kits.json
    python tools/assault_kits.py --check    # vérifie que le fichier est à jour (code de sortie 1 sinon)
"""
import json
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "game", "data", "classes.json")
UNITS = os.path.join(ROOT, "game", "data", "autochess_units.json")
DST = os.path.join(ROOT, "game", "data", "assault_kits.json")

ROLE_OF = {"tank": "rempart", "combattant": "ouvreur", "assassin": "ouvreur", "tireur": "tireur", "mage": "controleur",
           "soigneur": "soutien", "soutien": "soutien"}
CONTROL = {"stun", "freeze", "sleep", "fear", "root", "disarm", "chill"}
SHIELD = {"barrier", "titan", "angel", "resolve", "shrine", "solar"}
# Préférences de la case 3 par rôle (§ 7.5 : « ordre de préférence selon le rôle »).
UTILITY_PREF = {
    "rempart": ["shield", "control", "buff", "heal", "invis"],
    "ouvreur": ["control", "invis", "buff", "shield", "heal"],
    "tireur": ["control", "buff", "invis", "shield", "heal"],
    "controleur": ["control", "shield", "buff", "heal", "invis"],
    "soutien": ["heal", "shield", "buff", "control", "invis"],
}
PRICE = {"mobility": 200, "damage": 250, "buff": 250, "control": 300, "heal": 300, "shield": 300, "invis": 350}
ULT_FROM_CD = 12.0
ULT_RADIUS = 1.3
ULT_POINTS = 7
# Exceptions (classe -> {case: id de sort}) : vide tant que la sonde de TAC-4 ne montre pas de kit cassé.
EXCEPTIONS = {}


def offensive(s):
    return s.get("kind") not in ("buff", "heal")


def is_heal(s):
    return s.get("kind") == "heal" or float(s.get("heal", 0.0) or 0.0) > 0.0


def is_mobility(s):
    return s.get("kind") in ("dash", "blink") or float(s.get("dash", 0.0) or 0.0) > 0.0 or "move_dir" in s


def is_control(s):
    ap = s.get("applies", {}) or {}
    return offensive(s) and (bool(CONTROL.intersection(ap.keys())) or float(s.get("pull", 0.0) or 0.0) > 0.0)


def nature(s):
    """Nature d'un sort pour la case 3 et le prix : control, heal, shield, invis, buff, mobility, damage."""
    if is_mobility(s):
        return "mobility"
    if is_control(s):
        return "control"
    if is_heal(s) and not offensive(s):
        return "heal"
    buff = set((s.get("buff", {}) or {}).keys())
    if not offensive(s):
        if "invisible" in buff:
            return "invis"
        if buff & SHIELD:
            return "shield"
        return "buff"
    return "damage"


def value(s):
    """Valeur offensive : multiplicateur × coups (× salves) × zone (1 + rayon / 4)."""
    if not offensive(s):
        return 0.0
    hits = max(1, int(s.get("hits", 1) or 1)) * max(1, int(s.get("volley", 1) or 1))
    return float(s.get("mult", 0.0)) * hits * (1.0 + float(s.get("radius", 0.0)) / 4.0)


def build_kit(cid, c, role):
    skills = list(c.get("skills", []))
    order = {int(s["id"]): i for i, s in enumerate(skills)}
    used = set()

    def free(cands):
        return [s for s in cands if int(s["id"]) not in used]

    def pick(s):
        used.add(int(s["id"]))
        return s

    damage = [s for s in skills if offensive(s) and not is_mobility(s)]
    # 1. signature : le sort de dégâts de plus courte recharge (à valeur égale, le plus fort, puis l'ordre du jeu)
    sig = pick(min(damage or [s for s in skills if offensive(s)] or skills,
                   key=lambda s: (float(s.get("cooldown", 99.0)), -value(s), order[int(s["id"])])))
    # 4. ultime (choisi avant les cases 2 et 3 pour qu'elles ne le prennent pas)
    offs = free([s for s in skills if offensive(s)])
    big = [s for s in offs if float(s.get("cooldown", 0.0)) > ULT_FROM_CD] or offs or free(skills)
    ult = pick(max(big, key=lambda s: (value(s), float(s.get("cooldown", 0.0)), -order[int(s["id"])])))
    # 2. mobilité, sinon un second sort de dégâts (le plus court)
    mob = free([s for s in skills if is_mobility(s)])
    if mob:
        s2 = pick(min(mob, key=lambda s: (float(s.get("cooldown", 99.0)), order[int(s["id"])])))
    else:
        rest = free([s for s in damage if nature(s) == "damage"]) or free(damage) or free(skills)
        s2 = pick(min(rest, key=lambda s: (float(s.get("cooldown", 99.0)), -value(s), order[int(s["id"])])))
    # 3. utilité selon le rôle
    s3 = None
    for want in UTILITY_PREF[role]:
        cands = free([s for s in skills if nature(s) == want])
        if cands:
            # contrôle : le plus fort ; soin : la plus grande part ; renfort / bouclier : la plus courte recharge
            if want == "control":
                s3 = max(cands, key=lambda s: (value(s), -float(s.get("cooldown", 0.0))))
            elif want == "heal":
                s3 = max(cands, key=lambda s: (float(s.get("heal", 0.0) or 0.0), -float(s.get("cooldown", 0.0))))
            else:
                s3 = min(cands, key=lambda s: (float(s.get("cooldown", 99.0)), order[int(s["id"])]))
            break
    if s3 is None:
        rest = free(damage) or free(skills)
        s3 = max(rest, key=lambda s: (value(s), -order[int(s["id"])]))
    pick(s3)
    slots = [sig, s2, s3, ult]
    ex = EXCEPTIONS.get(cid, {})
    by_id = {int(s["id"]): s for s in skills}
    for k, sid in ex.items():
        slots[int(k)] = by_id[int(sid)]
    out = []
    for i, s in enumerate(slots):
        n = nature(s)
        e = {"id": int(s["id"]), "name": s.get("name", ""), "nature": n, "kind": s.get("kind", "")}
        if i == 0:
            e["free"] = True
        elif i in (1, 2):
            e["price"] = PRICE[n]
        else:
            e["ult"] = True
            e["points"] = ULT_POINTS
            e["radius_mult"] = ULT_RADIUS
        out.append(e)
    return {"role": role, "family": int(c.get("family", 0)), "slots": out}


def build():
    with open(SRC, encoding="utf-8") as f:
        classes = json.load(f)
    with open(UNITS, encoding="utf-8") as f:
        units = json.load(f)["units"]
    roles = {cid: ROLE_OF[u["role"]] for cid, u in units.items()}
    out = {"_doc": "Kits de L'Assaut : générés par tools/assault_kits.py depuis data/classes.json et data/autochess_units.json "
                   "(ne pas modifier à la main : règles et EXCEPTIONS dans le script)."}
    for cid in sorted(classes):
        out[cid] = build_kit(cid, classes[cid], roles.get(cid, "ouvreur"))
    return out


def dump(data):
    return json.dumps(data, ensure_ascii=False, indent=1) + "\n"


def main():
    data = build()
    text = dump(data)
    if "--check" in sys.argv:
        old = open(DST, encoding="utf-8").read() if os.path.exists(DST) else ""
        if old != text:
            print("assault_kits.json n'est pas à jour : relancer python tools/assault_kits.py")
            return 1
        print("assault_kits.json à jour (%d classes)" % (len(data) - 1))
        return 0
    with open(DST, "w", encoding="utf-8", newline="\n") as f:
        f.write(text)
    from collections import Counter
    roles = Counter(v["role"] for k, v in data.items() if k != "_doc")
    s2 = Counter(v["slots"][1]["nature"] for k, v in data.items() if k != "_doc")
    s3 = Counter(v["slots"][2]["nature"] for k, v in data.items() if k != "_doc")
    print("écrit %s : %d classes" % (os.path.relpath(DST, ROOT), len(data) - 1))
    print("rôles :", dict(roles))
    print("case 2 :", dict(s2))
    print("case 3 :", dict(s3))
    return 0


if __name__ == "__main__":
    sys.exit(main())
