"""Regarder l'IA jouer dans une fenêtre, en temps réel.

  python watch.py                  scénario de l'étape en cours
  python watch.py hardcore --classe magicien   (classe au hasard si absente)
  python watch.py hardcore         mannequin | mannequin4 | fuyard | survie | facile | normal | difficile | hardcore | toutes | duo
  python watch.py hardcore --modele modeles/etapes/etape_5_4.zip

Fermer la fenêtre du jeu pour arrêter.
"""

from __future__ import annotations

import argparse
import json
import sys
import unicodedata
import time
from pathlib import Path

import numpy as np
from stable_baselines3 import PPO

from curriculum import CLASSES, ALL, DUMMY4, DUMMY12, DUO, FLEE, FLEE3, STAGES, SURVIVE, SURVIVE2, Curriculum, rival
from eden_env import GodotVecEnv

HERE = Path(__file__).resolve().parent
CHOICES = {
    "mannequin4": [DUMMY4], "mannequin": [DUMMY12], "fuyard": [FLEE, FLEE3], "survie": [SURVIVE, SURVIVE2],
    "facile": [rival(0)], "normal": [rival(1)], "difficile": [rival(2)], "hardcore": [rival(3)],
    "toutes": [ALL], "duo": [DUO],
}


def _plain(t: str) -> str:
    return unicodedata.normalize("NFKD", t).encode("ascii", "ignore").decode().lower().replace("-", " ").replace("_", " ").strip()


_data = json.loads((HERE.parent / "game" / "data" / "classes.json").read_text(encoding="utf-8"))
NAMES = {cid: c.get("name_fr", cid) for cid, c in _data.get("classes", _data).items()}


def find_class(name: str) -> str:
    """Identifiant de classe d'après son nom français ou son identifiant ("" : au hasard)."""
    if not name:
        return ""
    name = {"mage": "magician", "pretre": "cleric", "prêtre": "cleric"}.get(name.lower(), name)
    for cid, fr in NAMES.items():
        if _plain(name) in (_plain(cid), _plain(fr)):
            return cid
    sys.exit(f"Classe inconnue : {name}. Exemples : guerrier, mage -> Magicien, clerc, chasseur, samourai…")


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("scenario", nargs="?", default="")
    ap.add_argument("--modele", default=str(HERE / "modeles" / "universel.zip"))
    ap.add_argument("--classe", default="", help="classe jouée (nom français ou identifiant ; vide : au hasard)")
    ap.add_argument("--capture", default="", help="capture d'écran (png) à 4 s du premier combat")
    args = ap.parse_args()
    state_path = Path(args.modele).with_name(Path(args.modele).stem + "_etat.json")
    hero = find_class(args.classe)
    cur = Curriculum(json.loads(state_path.read_text(encoding="utf-8")) if state_path.exists() else {})
    if args.scenario:
        if args.scenario not in CHOICES:
            sys.exit(f"Scénario inconnu : {args.scenario}. Choix : {', '.join(CHOICES)}")
        pool = CHOICES[args.scenario]
        base = lambda: dict(pool[np.random.randint(len(pool))])
        print(f"Scénario : {args.scenario}")
    else:
        base = lambda: dict(STAGES[cur.stage]["mix"][0][1])
        print(f"Scénario de l'étape {cur.stage + 1} : {STAGES[cur.stage]['nom']}")
    print(f"Classe jouée : {NAMES.get(hero, hero) if hero else 'au hasard à chaque combat'}")
    pick = lambda _i: {**base(), "hero_class": hero or np.random.choice(CLASSES)}
    results = []

    def on_episode(_i, sc, info):
        results.append(info["result"])
        wins = sum(r == "win" for r in results)
        print(f"Combat {len(results)} ({NAMES.get(info.get('hero', ''), '?')}) : {info['result']:7s} en {info['t']:5.1f} s · dégâts {round(info['dealt'] * 100)} % · "
              f"subis {round(info['taken'] * 100)} % · enchaînements {info['chain']} · parfaits {info['perfect']} · "
              f"esquives {info['dodged']}   (victoires {wins}/{len(results)})")

    model_path = Path(args.modele)
    if not model_path.exists():
        sys.exit(f"Pas encore de modèle ({model_path.name}) : l'entraînement sauvegarde à chaque étape réussie "
                 "et toutes les 10 minutes. Réessaie dans quelques minutes.")
    model = None
    for attempt in range(5):  # l'entraînement peut être en train d'écrire le fichier
        try:
            model = PPO.load(model_path, device="cpu")
            break
        except Exception:
            time.sleep(2)
    if model is None:
        sys.exit(f"Impossible de lire {model_path.name} (fichier en cours d'écriture ?). Réessaie.")
    env = GodotVecEnv(1, pick, on_episode, watch=True,
                      extra_args=[f"--capture={Path(args.capture).resolve().as_posix()}"] if args.capture else None)
    if env.observation_space.shape != model.observation_space.shape:
        env.close()
        sys.exit("Ce modèle a été entraîné avec une ancienne version de l'arène (ce que voit l'IA a changé) : "
                 "il faut un modèle entraîné depuis (IA_Entrainer.bat).")
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
