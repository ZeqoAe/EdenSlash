#!/usr/bin/env python3
"""Bilan du banc des atouts du Colisée (lot CO-E, conception/benchmark/R_CO_E.md).

    python tools/colisee_aug_report.py fichier.jsonl [autres.jsonl ...] [--sims 20000] [--json sortie.json]

Entrée : lignes JSON de game/tools/colisee_aug_bench (un combat 3 contre 3 par ligne, trio contre le même trio, l'un portant
l'atout). Calcule pour chaque atout :
  - taux de victoire du porteur (égalité = 1/2), intervalle de Wilson à 95 % ;
  - écart de force par héros (logit du taux, ÷ 3 quand les trois le portent : les forces s'ajoutent en logit) ;
  - « top 3 relatif » : écart de part de 1re-3e place (moitié haute du Classique 6 × 3) d'une équipe dont un héros porte
    l'atout, par rapport à un atout moyen de la même rareté, dans une partie simulée (modèle de Colisee.simulate : forces
    N(0 ; 0,8), victoire logistique, barème 20/25/35/50/100), l'atout pris à sa manche d'offre (Argent 1, Or 4, Éclat 7 ou 10).
Les atouts d'or (Tirelire, Mise) n'ont pas d'effet de combat : leur valeur passe par celle d'une pièce d'enclume (« gear:N »).
Critère du lot : aucun atout au-delà de +12 points ni en deçà de −8 points en top 3 relatif.
"""
import argparse
import json
import math
import random
import sys
from collections import defaultdict

RARITY = {
    "lame_affutee": "argent", "peau_de_chene": "argent", "pas_leger": "argent", "concentration": "argent",
    "premiere_frappe": "argent", "sangsue": "argent", "bouclier_entree": "argent", "esquive_agile": "argent",
    "tirelire": "argent", "main_verte": "argent",
    "echo": "or", "serment": "or", "garde_rapprochee": "or", "releve_eclair": "or", "chasseur_de_tetes": "or",
    "coup_de_grace": "or", "contre_coup": "or", "ronces": "or", "marque_du_chasseur": "or", "ancre": "or",
    "braise": "or", "givre": "or", "foudre": "or", "mise": "or",
    "tempete": "eclat", "deuxieme_souffle": "eclat", "colosse": "eclat", "maitre_des_sorts": "eclat",
    "ombre_jumelle": "eclat", "trio_parfait": "eclat", "roi_de_l_arene": "eclat", "pacte_de_sang": "eclat",
}
LOSS = [(3, 20), (6, 25), (9, 35), (11, 50), (0, 100)]
STRENGTH_SD = 0.8


def wilson(k, n, z=1.96):
    if n == 0:
        return 0.0, 1.0
    p = k / n
    d = 1 + z * z / n
    c = (p + z * z / (2 * n)) / d
    h = z * math.sqrt(p * (1 - p) / n + z * z / (4 * n * n)) / d
    return c - h, c + h


def logit(p):
    p = min(max(p, 0.02), 0.98)
    return math.log(p / (1 - p))


def loss_at(r):
    for last, v in LOSS:
        if last == 0 or r <= last:
            return v
    return 100


def tournament(rng, delta, from_round, hp_cost=0, teams=6):
    """Place finale de l'équipe 0 (1 = 1re) : force tirée + delta à partir de from_round (et -hp_cost PV ce jour-là)."""
    s = [rng.gauss(0.0, STRENGTH_SD) for _ in range(teams)]
    hp = [100] * teams
    out = [False] * teams
    place = [0] * teams
    r = 0
    while sum(1 for o in out if not o) > 1 and r < 40:
        r += 1
        if r == from_round and hp_cost:
            hp[0] -= hp_cost
        alive = [t for t in range(teams) if not out[t]]
        rng.shuffle(alive)
        if len(alive) % 2 == 1:
            alive.pop()  # exempt
        loss = loss_at(r)
        for i in range(0, len(alive), 2):
            a, b = alive[i], alive[i + 1]
            sa = s[a] + (delta if a == 0 and r >= from_round else 0.0)
            sb = s[b] + (delta if b == 0 and r >= from_round else 0.0)
            pa = 1.0 / (1.0 + math.exp(-(sa - sb)))
            loser = b if rng.random() < pa else a
            hp[loser] -= loss
        dead = sorted([t for t in range(teams) if not out[t] and hp[t] <= 0], key=lambda t: (hp[t], rng.random()))
        for t in dead:
            left = sum(1 for o in out if not o)
            out[t] = True
            place[t] = left
        left = [t for t in range(teams) if not out[t]]
        if len(left) == 1:
            place[left[0]] = 1
            break
    return place[0] if place[0] > 0 else 1


def top3(delta, from_round, sims, seed, hp_cost=0):
    rng = random.Random(seed)
    hits = 0
    for _ in range(sims):
        if tournament(rng, delta, from_round, hp_cost) <= 3:
            hits += 1
    return hits / sims


def offer_round(rarity):
    return {"argent": [1], "or": [4], "eclat": [7, 10]}[rarity]


def main():
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8")
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("files", nargs="+")
    ap.add_argument("--sims", type=int, default=20000)
    ap.add_argument("--json", default="")
    a = ap.parse_args()
    rows = []
    for f in a.files:
        with open(f, encoding="utf-8") as fh:
            for line in fh:
                line = line.strip()
                if line.startswith("[cobench] "):
                    line = line[len("[cobench] "):]
                if line.startswith("{"):
                    rows.append(json.loads(line))
    by = defaultdict(list)
    for r in rows:
        by[r["aug"]].append(r)
    # côté : contrôle sans atout
    ctl = by.get("", [])
    side_w = sum(1.0 if r["winner"] == 0 else (0.5 if r["winner"] < 0 else 0.0) for r in ctl)
    print(f"Combats : {len(rows)} ; contrôle sans atout : {len(ctl)} combats, le camp 0 gagne {100 * side_w / max(1, len(ctl)):.0f} %"
          f" (le porteur alterne de camp : le biais s'annule)")
    stats = {}
    for aug, rs in by.items():
        n = len(rs)
        k = sum(1.0 if r["holder_won"] == 1 else (0.5 if r["holder_won"] < 0 else 0.0) for r in rs)
        w = k / n
        lo, hi = wilson(k, n)
        mode = rs[0]["mode"]
        per_hero = logit(w) / (3.0 if mode == "trio" else 1.0)
        stats[aug] = {"n": n, "win": w, "lo": lo, "hi": hi, "mode": mode, "delta": per_hero,
                      "t": sum(r["t"] for r in rs) / n}
    # pièces d'enclume : valeur d'une pièce (pour l'or)
    piece = None
    for aug, st in stats.items():
        if aug.startswith("gear:"):
            k = int(aug.split(":")[1])
            piece = (piece or []) + [st["delta"] / k]
    d_piece = sum(piece) / len(piece) if piece else 0.06
    if "tirelire" not in stats:
        stats["tirelire"] = {"n": 0, "win": float("nan"), "lo": 0, "hi": 0, "mode": "or", "delta": 1.5 * d_piece, "t": 0}
    if "mise" not in stats:
        stats["mise"] = {"n": 0, "win": float("nan"), "lo": 0, "hi": 0, "mode": "or", "delta": 0.6 * d_piece, "t": 0}
    # moyenne par rareté (les atouts qui se proposent)
    mean = {}
    for rar in ("argent", "or", "eclat"):
        ds = [st["delta"] for aug, st in stats.items() if RARITY.get(aug) == rar and aug != "tempete"]
        mean[rar] = sum(ds) / len(ds) if ds else 0.0
    base = {rnd: top3(0.0, rnd, a.sims, 7) for rnd in (1, 4, 7, 10)}
    out = []
    print(f"\nValeur d'une pièce d'enclume par héros (logit) : {d_piece:+.3f} ; moyennes par rareté : "
          + ", ".join(f"{k} {v:+.3f}" for k, v in mean.items()))
    print(f"\n{'atout':20} {'rareté':7} {'n':>4} {'victoire':>9} {'IC 95 %':>13} {'Δ héros':>8} {'top 3 rel.':>10}  verdict")
    for aug in sorted(stats, key=lambda x: (RARITY.get(x, "z"), x)):
        st = stats[aug]
        rar = RARITY.get(aug, "")
        if rar == "" or aug == "tempete":
            rel = float("nan")
        else:
            d = st["delta"] - mean[rar]
            rel = 0.0
            for rnd in offer_round(rar):
                rel += (top3(d, rnd, a.sims, 7, 15 if aug == "pacte_de_sang" else 0) - base[rnd]) / len(offer_round(rar))
            rel *= 100.0
        st["top3_rel"] = rel
        ok = "" if math.isnan(rel) else ("OK" if -8.0 <= rel <= 12.0 else "HORS BORNES")
        win = "   —   " if math.isnan(st["win"]) else f"{100 * st['win']:6.1f} %"
        ci = "" if st["n"] == 0 else f"{100 * st['lo']:4.0f}-{100 * st['hi']:3.0f} %"
        print(f"{aug or '(aucun)':20} {rar:7} {st['n']:4d} {win:>9} {ci:>13} {st['delta']:+8.3f} "
              f"{'' if math.isnan(rel) else f'{rel:+9.1f}':>10}  {ok}")
        out.append({"aug": aug, **st})
    if a.json:
        with open(a.json, "w", encoding="utf-8") as fh:
            json.dump({"rows": len(rows), "piece": d_piece, "mean": mean, "augments": out}, fh, ensure_ascii=False, indent=1)


if __name__ == "__main__":
    main()
