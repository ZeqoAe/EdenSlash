"""Entraîne l'IA du guerrier dans l'arène d'Eden Slash (voir curriculum.py pour les étapes).

  python train.py              reprend là où l'entraînement s'était arrêté
  python train.py --nouveau    repart de zéro (l'ancien modèle est mis de côté)
  python train.py --jeux 8     nombre de jeux en parallèle (12 par défaut)

Ctrl+C arrête proprement : le modèle et l'étape atteinte sont sauvegardés.
"""

from __future__ import annotations

import argparse
import csv
import json
import shutil
import sys
import time
from pathlib import Path

import torch
from stable_baselines3 import PPO
from stable_baselines3.common.callbacks import BaseCallback

from curriculum import STAGES, Curriculum
from eden_env import GodotVecEnv

HERE = Path(__file__).resolve().parent
MODELS = HERE / "modeles"
MODEL = MODELS / "guerrier.zip"
STATE = MODELS / "guerrier_etat.json"
PROGRESS = HERE / "progression.json"
JOURNAL = HERE / "journal_entrainement.csv"


def pct(x: float) -> str:
    return f"{round(x * 100)} %"


def num(n: float) -> str:
    return f"{n:,.0f}".replace(",", " ")


class CurriculumCallback(BaseCallback):
    def __init__(self, cur: Curriculum, total_before: int):
        super().__init__()
        self.cur = cur
        self.total_before = total_before
        self.t_print = time.time()
        self.t_save = time.time()
        self.steps_at_print = 0

    def total(self) -> int:
        return self.total_before + self.num_timesteps

    def _on_step(self) -> bool:
        self.cur.steps_in_stage += self.training_env.num_envs
        now = time.time()
        if now - self.t_print > 30:
            self.report(now)
        if now - self.t_save > 600:
            save(self.model, self.cur, self.total())
            self.t_save = now
        return True

    def _on_rollout_end(self) -> None:
        old = self.cur.spec["nom"]
        if self.cur.maybe_promote(self.total()):
            MODELS.joinpath("etapes").mkdir(parents=True, exist_ok=True)
            self.model.save(MODELS / "etapes" / f"etape_{self.cur.stage}_reussie.zip")
            print(f"\n*** Étape réussie : {old} ({num(self.total())} décisions). Suivante : {self.cur.spec['nom']} ***\n")
            save(self.model, self.cur, self.total())

    def report(self, now: float) -> None:
        speed = (self.num_timesteps - self.steps_at_print) / (now - self.t_print)
        self.steps_at_print = self.num_timesteps
        self.t_print = now
        spec = self.cur.spec
        print(f"[{time.strftime('%H:%M:%S')}] Étape {self.cur.stage + 1}/{len(STAGES)} « {spec['nom']} » · "
              f"{num(self.total())} décisions ({num(speed)}/s) · réussite {pct(self.cur.success_rate())} "
              f"sur {len(self.cur.recent)} combats (objectif {pct(spec['seuil'])})")
        summary = self.cur.summary()
        for key, s in summary.items():
            print(f"    {key:9s} victoires {pct(s['victoires']):>5s} · survie {pct(s['survie']):>5s} · {s['duree']:5.1f} s · "
                  f"dégâts {pct(s['degats']):>5s} · subis {pct(s['subis']):>5s} · ench. {s['enchainements']:4.1f} · "
                  f"parfaits {s['parfaits']:4.1f} · esquives {s['esquives']:4.1f}")
        sys.stdout.flush()
        PROGRESS.write_text(json.dumps({
            "heure": time.strftime("%Y-%m-%d %H:%M:%S"), "etape": self.cur.stage + 1, "nom": spec["nom"],
            "decisions": self.total(), "reussite": round(self.cur.success_rate(), 3), "objectif": spec["seuil"],
            "etapes_franchies": self.cur.history, "scenarios": summary,
        }, ensure_ascii=False, indent=1), encoding="utf-8")
        new = not JOURNAL.exists()
        with JOURNAL.open("a", newline="", encoding="utf-8") as f:
            w = csv.writer(f, delimiter=";")
            if new:
                w.writerow(["heure", "etape", "decisions", "reussite", "scenario", "victoires", "survie", "duree",
                            "degats", "subis", "enchainements", "parfaits", "esquives"])
            for key, s in summary.items():
                w.writerow([time.strftime("%Y-%m-%d %H:%M:%S"), self.cur.stage + 1, self.total(),
                            round(self.cur.success_rate(), 3), key, s["victoires"], s["survie"], s["duree"],
                            s["degats"], s["subis"], s["enchainements"], s["parfaits"], s["esquives"]])


def save(model: PPO, cur: Curriculum, total: int) -> None:
    MODELS.mkdir(exist_ok=True)
    model.save(MODEL)
    STATE.write_text(json.dumps({**cur.state(), "total_steps": total}, ensure_ascii=False, indent=1), encoding="utf-8")


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--jeux", type=int, default=12)
    ap.add_argument("--nouveau", action="store_true")
    ap.add_argument("--decisions", type=int, default=1_000_000_000, help="arrêt après ce nombre de décisions")
    ap.add_argument("--etape", type=int, default=0, help="forcer une étape (1 à %d)" % len(STAGES))
    args = ap.parse_args()
    torch.set_num_threads(4)

    if args.nouveau and MODEL.exists():
        old = MODELS / f"ancien_{time.strftime('%Y%m%d_%H%M%S')}"
        old.mkdir(parents=True)
        for p in [MODEL, STATE]:
            if p.exists():
                shutil.move(str(p), old / p.name)
        print(f"Ancien modèle mis de côté dans {old}")
    state = json.loads(STATE.read_text(encoding="utf-8")) if STATE.exists() else {}
    cur = Curriculum(state)
    if args.etape:
        cur.stage = max(0, min(len(STAGES) - 1, args.etape - 1))
        cur.steps_in_stage = 0
    total = int(state.get("total_steps", 0))

    print(f"Lancement de {args.jeux} jeux Eden Slash sans fenêtre…")
    env = GodotVecEnv(args.jeux, cur.next_scenario, lambda i, sc, info: cur.record(sc, info))
    if MODEL.exists():
        print(f"Reprise du modèle {MODEL.name} ({num(total)} décisions déjà jouées), étape {cur.stage + 1} : {cur.spec['nom']}")
        model = PPO.load(MODEL, env=env, device="cpu")
    else:
        print(f"Nouveau modèle, étape {cur.stage + 1} : {cur.spec['nom']}")
        model = PPO("MlpPolicy", env, n_steps=512, batch_size=2048, n_epochs=5, learning_rate=3e-4,
                    gamma=0.995, gae_lambda=0.95, clip_range=0.2, ent_coef=0.01, vf_coef=0.5, max_grad_norm=0.5,
                    policy_kwargs=dict(net_arch=dict(pi=[256, 256], vf=[256, 256])), device="cpu", verbose=0)
    cb = CurriculumCallback(cur, total)
    try:
        model.learn(total_timesteps=args.decisions, callback=cb, reset_num_timesteps=True, progress_bar=False)
    except KeyboardInterrupt:
        print("\nArrêt demandé.")
    finally:
        save(model, cur, cb.total())
        print(f"Modèle sauvegardé : {MODEL} (étape {cur.stage + 1}, {num(cb.total())} décisions)")
        env.close()


if __name__ == "__main__":
    main()
