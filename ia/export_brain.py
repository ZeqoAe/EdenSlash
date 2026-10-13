"""Exporte un modèle entraîné en cerveau lisible par le jeu (game/data/cerveaux/<nom>.json),
utilisé sans Python par MlBrain (game/scripts/ml/ml_brain.gd).

  python export_brain.py                              modeles/guerrier.zip -> guerrier_maitre.json
  python export_brain.py modeles/etapes/etape_6_reussie.zip guerrier_facile
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

import numpy as np
import torch
from stable_baselines3 import PPO

HERE = Path(__file__).resolve().parent
BRAINS = HERE.parent / "game" / "data" / "cerveaux"


def _r(a) -> list:
    return np.round(np.asarray(a, dtype=np.float64), 6).tolist()


def export(model_path: Path | str, name: str, meta: dict | None = None) -> Path:
    model = PPO.load(model_path, device="cpu")
    pol = model.policy
    layers, act = [], "tanh"
    for m in pol.mlp_extractor.policy_net:
        if isinstance(m, torch.nn.Linear):
            layers.append({"w": _r(m.weight.detach()), "b": _r(m.bias.detach())})
        elif isinstance(m, torch.nn.ReLU):
            act = "relu"
    head = pol.action_net
    heads = [int(n) for n in model.action_space.nvec]
    obs_size = int(model.observation_space.shape[0])
    # échantillons de contrôle : le jeu vérifie qu'il trouve les mêmes actions (tests/test_ml_brain)
    rng = np.random.default_rng(0)
    checks = []
    with torch.no_grad():
        for _ in range(8):
            obs = rng.uniform(-1.0, 1.0, obs_size).astype(np.float32)
            obs = np.round(obs, 4)
            z = pol.action_net(pol.mlp_extractor.policy_net(torch.as_tensor(obs)[None]))[0].numpy()
            acts, k = [], 0
            for n in heads:
                acts.append(int(np.argmax(z[k:k + n])))
                k += n
            checks.append({"obs": obs.tolist(), "act": acts, "logits": _r(z)})
    data = {"obs_size": obs_size, "act": act, "layers": layers,
            "head": {"w": _r(head.weight.detach()), "b": _r(head.bias.detach())},
            "heads": heads, "checks": checks, "meta": meta or {}}
    BRAINS.mkdir(parents=True, exist_ok=True)
    out = BRAINS / f"{name}.json"
    out.write_text(json.dumps(data, separators=(",", ":")), encoding="utf-8")
    return out


if __name__ == "__main__":
    src = sys.argv[1] if len(sys.argv) > 1 else str(HERE / "modeles" / "guerrier.zip")
    name = sys.argv[2] if len(sys.argv) > 2 else "guerrier_maitre"
    path = export(src, name, {"source": Path(src).name})
    print(f"Cerveau exporté : {path} ({path.stat().st_size // 1024} Ko)")
