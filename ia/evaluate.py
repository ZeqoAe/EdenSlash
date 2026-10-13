"""Tableau des victoires de chaque classe : N combats par classe contre un niveau d'adversaire,
avec le cerveau entraîné (sans tirage au sort). Résultat dans la console et dans
ia/evaluation_<scénario>.csv.

  python evaluate.py                    hardcore, 10 combats par classe
  python evaluate.py difficile --combats 20 --modele modeles/etapes/etape_8_reussie.zip
"""

from __future__ import annotations

import argparse
import csv
import time
from collections import defaultdict
from pathlib import Path

import numpy as np
from stable_baselines3 import PPO

from curriculum import CLASSES
from eden_env import GodotVecEnv
from watch import CHOICES, NAMES

HERE = Path(__file__).resolve().parent


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("scenario", nargs="?", default="hardcore")
    ap.add_argument("--combats", type=int, default=10)
    ap.add_argument("--jeux", type=int, default=12)
    ap.add_argument("--modele", default=str(HERE / "modeles" / "universel.zip"))
    args = ap.parse_args()
    model = PPO.load(args.modele, device="cpu")
    todo = [c for c in CLASSES for _ in range(args.combats)]
    base = CHOICES[args.scenario][0]

    def pick(_i: int) -> dict:
        # quand tout est lancé, les jeux finissent avec des combats qui ne comptent pas
        return {**base, "hero_class": todo.pop(0) if todo else "warrior", "count_me": bool(todo)}

    results: dict[str, list] = defaultdict(list)
    started = {"n": 0}

    def on_episode(_i, sc, info):
        if sc.get("count_me", True) and len(results[sc["hero_class"]]) < args.combats:
            results[sc["hero_class"]].append(info)

    env = GodotVecEnv(args.jeux, pick, on_episode)
    if env.observation_space.shape != model.observation_space.shape:
        env.close()
        raise SystemExit("Modèle d'une ancienne version de l'arène : il faut un modèle entraîné depuis.")
    obs = env.reset()
    t0 = time.time()
    total = len(CLASSES) * args.combats
    last = 0
    while sum(len(v) for v in results.values()) < total:
        action, _ = model.predict(obs, deterministic=True)
        obs, _, _, _ = env.step(action)
        done = sum(len(v) for v in results.values())
        if done - last >= 60:
            last = done
            print(f"  {done}/{total} combats ({time.time() - t0:.0f} s)")
    env.close()

    rows = []
    for c in CLASSES:
        infos = results[c]
        n = len(infos)
        rows.append((c, sum(i["result"] == "win" for i in infos) / n, sum(i["taken"] for i in infos) / n,
                     sum(i["t"] for i in infos) / n))
    rows.sort(key=lambda r: (r[1], -r[2]))
    print(f"\nVictoires par classe ({args.scenario}, {args.combats} combats chacune) :")
    for c, w, tk, t in rows:
        print(f"  {NAMES.get(c, c):26s} {round(w * 100):3d} %   PV perdus {round(tk * 100):3d} %   {t:5.1f} s")
    ok = sum(1 for r in rows if r[1] >= 0.7)
    print(f"\n{ok}/{len(rows)} classes gagnent au moins 70 % de leurs combats ; moyenne {round(np.mean([r[1] for r in rows]) * 100)} %")
    out = HERE / f"evaluation_{args.scenario}.csv"
    with out.open("w", newline="", encoding="utf-8") as f:
        w = csv.writer(f, delimiter=";")
        w.writerow(["classe", "nom", "victoires", "pv_perdus", "duree"])
        for c, wr, tk, t in rows:
            w.writerow([c, NAMES.get(c, c), round(wr, 3), round(tk, 3), round(t, 1)])
    print(f"Tableau : {out}")


if __name__ == "__main__":
    main()
