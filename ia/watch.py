"""Regarder l'IA jouer dans une fenêtre, en temps réel.

  python watch.py                  scénario de l'étape en cours
  python watch.py hardcore         mannequin | mannequin4 | fuyard | survie | facile | normal | difficile | hardcore
  python watch.py hardcore --modele modeles/etapes/etape_5_4.zip

Fermer la fenêtre du jeu pour arrêter.
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

import numpy as np
from stable_baselines3 import PPO

from curriculum import DUMMY4, DUMMY12, FLEE, FLEE3, STAGES, SURVIVE, SURVIVE2, Curriculum, rival
from eden_env import GodotVecEnv

HERE = Path(__file__).resolve().parent
CHOICES = {
    "mannequin4": [DUMMY4], "mannequin": [DUMMY12], "fuyard": [FLEE, FLEE3], "survie": [SURVIVE, SURVIVE2],
    "facile": [rival(0)], "normal": [rival(1)], "difficile": [rival(2)], "hardcore": [rival(3)],
}


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("scenario", nargs="?", default="")
    ap.add_argument("--modele", default=str(HERE / "modeles" / "guerrier.zip"))
    ap.add_argument("--capture", default="", help="capture d'écran (png) à 4 s du premier combat")
    args = ap.parse_args()
    state_path = HERE / "modeles" / "guerrier_etat.json"
    cur = Curriculum(json.loads(state_path.read_text(encoding="utf-8")) if state_path.exists() else {})
    if args.scenario:
        if args.scenario not in CHOICES:
            sys.exit(f"Scénario inconnu : {args.scenario}. Choix : {', '.join(CHOICES)}")
        pool = CHOICES[args.scenario]
        pick = lambda _i: dict(pool[np.random.randint(len(pool))])
        print(f"Scénario : {args.scenario}")
    else:
        pick = lambda _i: dict(STAGES[cur.stage]["mix"][0][1])
        print(f"Scénario de l'étape {cur.stage + 1} : {STAGES[cur.stage]['nom']}")
    results = []

    def on_episode(_i, sc, info):
        results.append(info["result"])
        wins = sum(r == "win" for r in results)
        print(f"Combat {len(results)} : {info['result']:7s} en {info['t']:5.1f} s · dégâts {round(info['dealt'] * 100)} % · "
              f"subis {round(info['taken'] * 100)} % · enchaînements {info['chain']} · parfaits {info['perfect']} · "
              f"esquives {info['dodged']}   (victoires {wins}/{len(results)})")

    env = GodotVecEnv(1, pick, on_episode, watch=True,
                      extra_args=[f"--capture={Path(args.capture).resolve().as_posix()}"] if args.capture else None)
    model = PPO.load(args.modele, device="cpu")
    obs = env.reset()
    try:
        while True:
            action, _ = model.predict(obs, deterministic=True)
            obs, _, _, _ = env.step(action)
    except (ConnectionError, KeyboardInterrupt, OSError):
        pass
    finally:
        env.close()


if __name__ == "__main__":
    main()
