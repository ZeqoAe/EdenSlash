"""Programme d'entraînement du cerveau universel (les 60 classes) : étapes successives,
chacune avec ses scénarios et son objectif. À chaque combat, le héros joue une classe tirée
au hasard (contre les adversaires de classe, les classes qui gagnent le moins sont tirées plus
souvent). L'étape suivante s'ouvre quand l'objectif est atteint sur les derniers combats, et
pour les étapes contre les adversaires de classe, par CHAQUE classe. Une part des combats
rejoue les étapes passées pour ne pas les oublier.

Réglages d'un scénario (envoyés au jeu, voir game/scripts/ml/ml_arena.gd) :
  scenario      dummy | flee | monster | rival
  hero_class    classe jouée (choisie ici) ; loadout : default (12 premiers sorts) | random
  skills        4 (une case par sort) ou 12 (2 enchaînements par case)
  difficulty    adversaire de classe : 0 facile, 1 normal, 2 difficile, 3 hardcore
  enemy_class   classe de l'adversaire (random : au hasard, tirée pour chacun)
  max_time      durée max d'un combat (s)
  hero_hp       PV du héros bloqués à cette valeur (1 = un coup et c'est fini)
  enemy_hp      multiplicateur des PV de l'adversaire ; count : nombre d'adversaires
  cc_immune     adversaires insensibles aux contrôles
  bonus         récompenses en plus : perfect (annulation parfaite), chain (enchaînement
                réussi), dodged (coup esquivé)
  win_bonus, loss_penalty, timeout_reward, time_penalty (par décision), w_taken
"""

from __future__ import annotations

import random
from collections import deque

# même ordre que ML_CLASSES dans game/scripts/ml/ml_arena.gd
CLASSES = ["samurai", "warrior", "thief", "hunter", "cleric", "magician", "bard", "knight", "engineer",
           "martial_artist", "illusionist", "blade_dancer", "shaman", "templar", "ranger", "warlock", "sage",
           "dragon_knight", "luminary", "inquisitor", "berserker", "shielder", "arch_elementalist", "stormcaster",
           "trainer", "devil_hunter", "adjudicator", "equilibrian", "assassin", "kage", "battlefield_poet",
           "life_worshipper", "executioner", "glacier_knight", "mecha_ares", "annihilator", "asura", "rakshasa",
           "demon_tamer", "chronologist", "blade_acrobat", "elegant_dancer", "druid", "archimage", "dawnbreaker",
           "paladin", "absolute_arrow", "holy_arrow", "dark_envoy", "conjurer", "blade_master", "master_fencer",
           "psalmist", "orator", "dragon_soul", "dragon_rider", "black_blade", "light_blade", "reaver", "rifleteer"]

DUMMY4 = dict(scenario="dummy", skills=4, max_time=30, bonus={"perfect": 0.05})
DUMMY12 = dict(scenario="dummy", skills=12, max_time=30, bonus={"perfect": 0.08, "chain": 0.15})
# fuyard difficile (6,2 m/s, 2 esquives) et hardcore (7 m/s, plus rapide que le héros,
# 3 esquives) : les contrôles ne suffisent pas, il faut le rattraper. PV réduits : avec ses
# 6 à 8 fois les PV du héros, la plupart des classes (lentes, à distance) ne le tuaient pas
FLEE = dict(scenario="flee", skills=12, difficulty=2, max_time=40, enemy_hp=0.5,
            bonus={"perfect": 0.15, "chain": 0.1}, timeout_reward=-2.0)
FLEE3 = dict(FLEE, difficulty=3, max_time=45, enemy_hp=0.4)
# monstres insensibles aux contrôles (sinon on les renverse en boucle et on n'esquive jamais)
# et assez solides pour qu'il faille survivre, pas juste les tuer vite
SURVIVE = dict(scenario="monster", skills=12, hero_hp=1, max_time=40, enemy_hp=20.0, cc_immune=True,
               timeout_reward=4.0, loss_penalty=8.0, bonus={"dodged": 0.4, "perfect": 0.05})
SURVIVE2 = dict(SURVIVE, count=2)


def rival(d: int, **kw) -> dict:
    """Adversaire de classe de difficulté [d], d'une classe au hasard (les classes se rencontrent)."""
    sc = dict(scenario="rival", skills=12, difficulty=d, max_time=90, enemy_class="random",
              bonus={"dodged": 0.15, "perfect": 0.05}, win_bonus=8.0, loss_penalty=8.0, timeout_reward=-3.0)
    sc.update(kw)
    return sc


def survives(info: dict) -> bool:
    return info["result"] in ("win", "timeout")


def wins(info: dict) -> bool:
    return info["result"] == "win"


def clean_win(max_taken: float):
    """Victoire en perdant moins de [max_taken] des PV du héros."""
    return lambda i: i["result"] == "win" and i["taken"] < max_taken


# hardcore : 8 fois les PV du héros, 90 s ne suffisaient pas aux classes qui frappent moins fort
ALL = rival(3, max_time=180)
DUO = rival(3, count=2, enemy_hp=0.6, max_time=180)  # 1 contre 2, comme dans la Tour

# nom, scénarios (poids, réglages), scénario jugé, réussite, seuil (tous combats confondus),
# par_classe : seuil que CHAQUE classe doit atteindre (sur ses CLASS_WINDOW derniers combats),
# min_steps : minimum de décisions, cerveau : nom du cerveau exporté quand l'étape est réussie
STAGES = [
    dict(nom="1. Mannequin, 4 sorts", mix=[(1.0, DUMMY4)],
         juge="dummy", reussite=wins, seuil=0.9, min_steps=1_000_000),
    dict(nom="2. Mannequin, 12 sorts (timings des enchaînements)", mix=[(0.9, DUMMY12), (0.1, DUMMY4)],
         juge="dummy", reussite=lambda i: wins(i) and i["chain"] >= 3, seuil=0.85, min_steps=2_000_000),
    dict(nom="3. Adversaire fuyard (agressivité, esquives d'annulation)",
         mix=[(0.5, FLEE), (0.35, FLEE3), (0.15, DUMMY12)],
         juge="flee", reussite=lambda i: i["dealt"] >= 0.7, seuil=0.6, min_steps=3_000_000),
    dict(nom="4. Monstres, héros à 1 PV (esquive)",
         mix=[(0.55, SURVIVE), (0.3, SURVIVE2), (0.1, FLEE), (0.05, DUMMY12)],
         juge="monster", reussite=survives, seuil=0.75, min_steps=4_000_000, cerveau="cerveau_debutant"),
    dict(nom="5. Adversaires de classe faciles",
         mix=[(0.75, rival(0)), (0.15, SURVIVE), (0.1, FLEE)],
         juge="rival", reussite=wins, seuil=0.9, par_classe=0.6, min_steps=1_000_000, cerveau="cerveau_facile"),
    dict(nom="6. Adversaires de classe normaux",
         mix=[(0.7, rival(1)), (0.1, rival(0)), (0.1, SURVIVE), (0.1, FLEE)],
         juge="rival", reussite=wins, seuil=0.85, par_classe=0.6, min_steps=1_500_000, cerveau="cerveau_normal"),
    dict(nom="7. Adversaires de classe difficiles",
         mix=[(0.7, rival(2)), (0.1, rival(1)), (0.1, SURVIVE), (0.1, FLEE)],
         juge="rival", reussite=wins, seuil=0.8, par_classe=0.6, min_steps=2_000_000, cerveau="cerveau_difficile"),
    dict(nom="8. Adversaires HARDCORE (chaque classe doit gagner 70 % de ses combats)",
         mix=[(0.75, ALL), (0.1, rival(2)), (0.1, SURVIVE2), (0.05, FLEE)],
         juge="rival", reussite=wins, seuil=0.8, par_classe=0.7, min_steps=3_000_000, cerveau="cerveau_hardcore"),
    dict(nom="9. Expert : hardcore et 1 contre 2, en perdant moins de 30 % de ses PV",
         mix=[(0.5, ALL), (0.3, DUO), (0.1, SURVIVE2), (0.1, FLEE3)],
         juge="rival", reussite=clean_win(0.3), seuil=0.8, par_classe=0.5, min_steps=5_000_000,
         cerveau="cerveau_expert"),
    dict(nom="10. Maître (sans fin) : gagner sans presque être touché",
         mix=[(0.5, ALL), (0.35, DUO), (0.1, SURVIVE2), (0.05, FLEE3)],
         juge="rival", reussite=clean_win(0.1), seuil=2.0, min_steps=0, cerveau="cerveau_maitre"),
]
WINDOW = 400  # combats jugés pour passer à l'étape suivante
CLASS_WINDOW = 20  # derniers combats jugés de chaque classe


class Curriculum:
    def __init__(self, state: dict | None = None):
        state = state or {}
        self.stage = int(state.get("stage", 0))
        self.steps_in_stage = int(state.get("steps_in_stage", 0))
        self.history = state.get("history", [])  # étapes franchies : [nom, décisions totales]
        self.recent: deque = deque(maxlen=WINDOW)  # réussites du scénario jugé
        self.per_class: dict[str, deque] = {}  # classe -> réussites au scénario jugé
        self.episodes = 0
        self.by_scenario: dict[str, deque] = {}

    @property
    def spec(self) -> dict:
        return STAGES[self.stage]

    def class_rate(self, cid: str) -> float | None:
        d = self.per_class.get(cid)
        return sum(d) / len(d) if d else None

    def pick_class(self, sc: dict) -> str:
        """Classe du héros : au hasard ; contre les adversaires de classe, les classes qui
        gagnent le moins sont tirées plus souvent."""
        if sc["scenario"] != "rival" or self.spec["juge"] != "rival":
            return random.choice(CLASSES)
        weights = []
        for c in CLASSES:
            r = self.class_rate(c)
            weights.append(1.0 if r is None else 1.1 - r)
        return random.choices(CLASSES, weights=weights)[0]

    def next_scenario(self, _env_index: int) -> dict:
        weights = [w for w, _ in self.spec["mix"]]
        _, sc = random.choices(self.spec["mix"], weights=weights)[0]
        out = dict(sc)
        out["stage"] = self.stage
        out["hero_class"] = self.pick_class(sc)
        if out.get("skills", 4) > 4 and random.random() < 0.5:
            out["loadout"] = "random"  # n'importe quel jeu de 12 sorts de la classe
        return out

    def _judged(self, scenario: dict) -> bool:
        if scenario.get("stage") != self.stage or scenario["scenario"] != self.spec["juge"]:
            return False
        if self.spec["juge"] == "rival" and scenario.get("difficulty") != self.spec["mix"][0][1].get("difficulty"):
            return False
        return True

    def record(self, scenario: dict, info: dict) -> None:
        self.episodes += 1
        key = scenario["scenario"]
        if key == "rival":
            key += str(scenario.get("difficulty", ""))
            key += "x2" if int(scenario.get("count", 1)) > 1 else ""
        elif int(scenario.get("count", 1)) > 1:
            key += "x2"
        self.by_scenario.setdefault(key, deque(maxlen=300)).append(info)
        if not self._judged(scenario):
            return
        ok = 1.0 if self.spec["reussite"](info) else 0.0
        self.recent.append(ok)
        self.per_class.setdefault(scenario["hero_class"], deque(maxlen=CLASS_WINDOW)).append(ok)

    def success_rate(self) -> float:
        return sum(self.recent) / len(self.recent) if self.recent else 0.0

    def classes_ok(self) -> tuple[int, list[tuple[str, float]]]:
        """Classes qui atteignent le seuil par classe, et les plus faibles (classe, taux)."""
        need = self.spec.get("par_classe")
        rates = []
        for c in CLASSES:
            d = self.per_class.get(c)
            rates.append((c, sum(d) / len(d) if d and len(d) >= CLASS_WINDOW // 2 else -1.0))
        ok = sum(1 for _, r in rates if need is not None and r >= need)
        weakest = sorted(rates, key=lambda x: x[1])[:6]
        return ok, weakest

    def maybe_promote(self, total_steps: int) -> bool:
        if self.stage >= len(STAGES) - 1:
            return False
        if self.steps_in_stage < self.spec["min_steps"] or len(self.recent) < WINDOW:
            return False
        if self.success_rate() < self.spec["seuil"]:
            return False
        if self.spec.get("par_classe") is not None and self.classes_ok()[0] < len(CLASSES):
            return False
        self.history.append([self.spec["nom"], total_steps])
        self.stage += 1
        self.steps_in_stage = 0
        self.recent.clear()
        self.per_class.clear()
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

    def class_table(self) -> dict:
        """Réussite de chaque classe à l'étape en cours (scénario jugé)."""
        return {c: round(self.class_rate(c), 2) for c in CLASSES if self.class_rate(c) is not None}
