"""Programme d'entraînement du guerrier : étapes successives, chacune avec ses scénarios
et son objectif. L'étape suivante s'ouvre quand l'objectif est atteint sur les derniers
combats. Une part des combats rejoue les étapes passées pour ne pas les oublier.

Réglages d'un scénario (envoyés au jeu, voir game/scripts/ml/ml_arena.gd) :
  scenario      dummy | flee | monster | rival
  skills        4 (une case par sort) ou 12 (2 enchaînements par case)
  difficulty    adversaire de classe : 0 facile, 1 normal, 2 difficile, 3 hardcore
  max_time      durée max d'un combat (s)
  hero_hp       PV du héros bloqués à cette valeur (1 = un coup et c'est fini)
  enemy_hp      multiplicateur des PV de l'adversaire ; count : nombre de monstres
  bonus         récompenses en plus : perfect (annulation parfaite), chain (enchaînement
                réussi), dodged (coup esquivé)
  win_bonus, loss_penalty, timeout_reward, time_penalty (par décision), w_taken
"""

from __future__ import annotations

import random
from collections import deque

DUMMY4 = dict(scenario="dummy", skills=4, max_time=30, bonus={"perfect": 0.05})
DUMMY12 = dict(scenario="dummy", skills=12, max_time=30, bonus={"perfect": 0.08, "chain": 0.15})
# fuyard difficile (6,2 m/s, 2 esquives) et hardcore (7 m/s, plus rapide que le héros,
# 3 esquives) : les renversements du guerrier ne suffisent plus, il faut le rattraper
FLEE = dict(scenario="flee", skills=12, difficulty=2, max_time=40, enemy_hp=1.0,
            bonus={"perfect": 0.15, "chain": 0.1}, timeout_reward=-2.0)
FLEE3 = dict(FLEE, difficulty=3, max_time=45)
# monstres insensibles aux contrôles (sinon le guerrier les renverse en boucle et n'esquive
# jamais) et assez solides pour qu'il faille survivre, pas juste les tuer vite
SURVIVE = dict(scenario="monster", skills=12, hero_hp=1, max_time=40, enemy_hp=20.0, cc_immune=True,
               timeout_reward=4.0, loss_penalty=8.0, bonus={"dodged": 0.4, "perfect": 0.05})
SURVIVE2 = dict(SURVIVE, count=2)


def rival(d: int, **kw) -> dict:
    sc = dict(scenario="rival", skills=12, difficulty=d, max_time=90, bonus={"dodged": 0.15, "perfect": 0.05},
              win_bonus=8.0, loss_penalty=8.0, timeout_reward=-3.0)
    sc.update(kw)
    return sc


def survives(info: dict) -> bool:
    return info["result"] in ("win", "timeout")


def wins(info: dict) -> bool:
    return info["result"] == "win"


# nom, scénarios (poids, réglages), scénario jugé, réussite, seuil, minimum de décisions
STAGES = [
    dict(nom="1. Mannequin, 4 sorts", mix=[(1.0, DUMMY4)],
         juge="dummy", reussite=wins, seuil=0.95, min_steps=300_000),
    dict(nom="2. Mannequin, 12 sorts (timings des enchaînements)", mix=[(0.9, DUMMY12), (0.1, DUMMY4)],
         juge="dummy", reussite=lambda i: wins(i) and i["chain"] >= 3, seuil=0.9, min_steps=600_000),
    dict(nom="3. Adversaire fuyard (agressivité, esquives d'annulation)",
         mix=[(0.5, FLEE), (0.35, FLEE3), (0.15, DUMMY12)],
         juge="flee", reussite=wins, seuil=0.8, min_steps=1_000_000),
    dict(nom="4. Monstres, héros à 1 PV (esquive)",
         mix=[(0.55, SURVIVE), (0.3, SURVIVE2), (0.1, FLEE), (0.05, DUMMY12)],
         juge="monster", reussite=survives, seuil=0.8, min_steps=1_500_000),
    dict(nom="5. Adversaire de classe facile",
         mix=[(0.75, rival(0)), (0.15, SURVIVE), (0.1, FLEE)],
         juge="rival", reussite=wins, seuil=0.9, min_steps=500_000),
    dict(nom="6. Adversaire de classe normal",
         mix=[(0.7, rival(1)), (0.1, rival(0)), (0.1, SURVIVE), (0.1, FLEE)],
         juge="rival", reussite=wins, seuil=0.85, min_steps=1_000_000),
    dict(nom="7. Adversaire de classe difficile",
         mix=[(0.7, rival(2)), (0.1, rival(1)), (0.1, SURVIVE), (0.1, FLEE)],
         juge="rival", reussite=wins, seuil=0.8, min_steps=2_000_000),
    dict(nom="8. Adversaire de classe HARDCORE",
         mix=[(0.75, rival(3)), (0.1, rival(2)), (0.1, SURVIVE2), (0.05, FLEE)],
         juge="rival", reussite=wins, seuil=0.7, min_steps=3_000_000),
    dict(nom="9. Perfectionnement (hardcore, sans fin)",
         mix=[(0.8, rival(3)), (0.1, SURVIVE2), (0.1, rival(2))],
         juge="rival", reussite=wins, seuil=2.0, min_steps=0),
]
WINDOW = 200  # combats jugés pour passer à l'étape suivante


class Curriculum:
    def __init__(self, state: dict | None = None):
        state = state or {}
        self.stage = int(state.get("stage", 0))
        self.steps_in_stage = int(state.get("steps_in_stage", 0))
        self.history = state.get("history", [])  # étapes franchies : [nom, décisions totales]
        self.recent: deque = deque(maxlen=WINDOW)  # réussites du scénario jugé
        self.episodes = 0
        self.by_scenario: dict[str, deque] = {}

    @property
    def spec(self) -> dict:
        return STAGES[self.stage]

    def next_scenario(self, _env_index: int) -> dict:
        weights = [w for w, _ in self.spec["mix"]]
        _, sc = random.choices(self.spec["mix"], weights=weights)[0]
        out = dict(sc)
        out["stage"] = self.stage
        return out

    def record(self, scenario: dict, info: dict) -> None:
        self.episodes += 1
        key = scenario["scenario"] + (f"{scenario.get('difficulty', '')}" if scenario["scenario"] == "rival" else "")
        self.by_scenario.setdefault(key, deque(maxlen=100)).append(info)
        if scenario.get("stage") != self.stage or scenario["scenario"] != self.spec["juge"]:
            return
        if self.spec["juge"] == "rival" and scenario.get("difficulty") != self.spec["mix"][0][1].get("difficulty"):
            return
        self.recent.append(1.0 if self.spec["reussite"](info) else 0.0)

    def success_rate(self) -> float:
        return sum(self.recent) / len(self.recent) if self.recent else 0.0

    def maybe_promote(self, total_steps: int) -> bool:
        if self.stage >= len(STAGES) - 1:
            return False
        if self.steps_in_stage < self.spec["min_steps"] or len(self.recent) < WINDOW:
            return False
        if self.success_rate() < self.spec["seuil"]:
            return False
        self.history.append([self.spec["nom"], total_steps])
        self.stage += 1
        self.steps_in_stage = 0
        self.recent.clear()
        return True

    def state(self) -> dict:
        return {"stage": self.stage, "steps_in_stage": self.steps_in_stage, "history": self.history}

    def summary(self) -> dict:
        out = {}
        for key, infos in sorted(self.by_scenario.items()):
            n = len(infos)
            out[key] = {
                "combats": n,
                "victoires": round(sum(i["result"] == "win" for i in infos) / n, 2),
                "survie": round(sum(i["result"] != "loss" for i in infos) / n, 2),
                "duree": round(sum(i["t"] for i in infos) / n, 1),
                "degats": round(sum(i["dealt"] for i in infos) / n, 2),
                "subis": round(sum(i["taken"] for i in infos) / n, 2),
                "enchainements": round(sum(i["chain"] for i in infos) / n, 1),
                "parfaits": round(sum(i["perfect"] for i in infos) / n, 1),
                "esquives": round(sum(i["dodged"] for i in infos) / n, 1),
            }
        return out
