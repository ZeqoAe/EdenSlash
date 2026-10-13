"""Pont entre Eden Slash (Godot) et l'apprentissage (Stable-Baselines3).

Chaque environnement est un Godot sans fenêtre qui charge l'arène ML
(game/scenes/ml_arena.tscn) et se connecte à ce programme sur un port local. Les
messages sont des lignes JSON :
  Python -> jeu : {"cmd": "reset", "scenario": ..., ...} | {"cmd": "step", "a": [dépl., touche, visée]}
  jeu -> Python : {"obs": [...], "r": récompense, "done": fin, "info": {...}}
Tous les jeux tournent en parallèle : on envoie toutes les actions, puis on lit
toutes les réponses.
"""

from __future__ import annotations

import json
import os
import socket
import subprocess
import time
from pathlib import Path
from typing import Callable

import gymnasium as gym
import numpy as np
from stable_baselines3.common.vec_env.base_vec_env import VecEnv

ROOT = Path(__file__).resolve().parent.parent
GAME = ROOT / "game"
LOGS = Path(__file__).resolve().parent / "journaux"
GODOT = os.environ.get("EDEN_GODOT", r"C:\Users\Nico\Godot\Godot_v4.7.2-stable_win64_console.exe")

MOVES, BUTTONS, AIMS = 9, 8, 3  # rien + 8 directions ; rien, attaque, sort 1-4, esquive, saut ; visée
ACTION_SPACE = gym.spaces.MultiDiscrete([MOVES, BUTTONS, AIMS])


class GodotLink:
    """Un jeu Godot lancé et relié par une connexion locale."""

    def __init__(self, watch: bool = False, extra_args: list[str] | None = None):
        self.server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        self.server.bind(("127.0.0.1", 0))  # port libre choisi par le système
        self.port = port = self.server.getsockname()[1]
        self.server.listen(1)
        self.server.settimeout(180)
        args = [GODOT, "--path", str(GAME)]
        if not watch:
            args += ["--headless", "--fixed-fps", "60"]
        args += ["res://scenes/ml_arena.tscn", "--", f"--port={port}"]
        if watch:
            args.append("--watch")
        args += extra_args or []
        LOGS.mkdir(exist_ok=True)
        self.log_path = LOGS / f"godot_{port}.log"
        self.log = open(self.log_path, "wb")
        flags = subprocess.CREATE_NO_WINDOW if (os.name == "nt" and not watch) else 0
        self.proc = subprocess.Popen(args, stdout=self.log, stderr=subprocess.STDOUT, creationflags=flags)
        self.sock: socket.socket | None = None
        self.reader = None

    def accept(self) -> None:
        self.sock, _ = self.server.accept()
        self.server.close()
        self.sock.setsockopt(socket.IPPROTO_TCP, socket.TCP_NODELAY, 1)
        self.reader = self.sock.makefile("rb")

    def send(self, msg: dict) -> None:
        self.sock.sendall((json.dumps(msg) + "\n").encode())

    def recv(self) -> dict:
        line = self.reader.readline()
        if not line:
            raise ConnectionError(f"le jeu du port {self.port} s'est arrêté (voir {self.log_path})")
        return json.loads(line)

    def close(self) -> None:
        try:
            if self.sock:
                self.send({"cmd": "close"})
                self.sock.close()
        except OSError:
            pass
        try:
            self.proc.wait(timeout=5)
        except subprocess.TimeoutExpired:
            self.proc.kill()
        self.log.close()


class GodotVecEnv(VecEnv):
    """[n] arènes en parallèle. [scenario_fn(i)] donne les réglages du prochain épisode de
    l'arène i ; [on_episode(i, scénario, info)] reçoit le bilan de chaque épisode fini."""

    def __init__(self, n: int, scenario_fn: Callable[[int], dict], on_episode: Callable | None = None,
                 watch: bool = False, extra_args: list[str] | None = None):
        self.scenario_fn = scenario_fn
        self.on_episode = on_episode
        self.watch = watch
        self.extra_args = extra_args
        for f in LOGS.glob("godot_*.log"):  # journaux des lancements précédents
            try:
                f.unlink()
            except OSError:
                pass  # encore ouvert par un autre lancement
        self.links = [GodotLink(watch, extra_args) for _ in range(n)]
        for link in self.links:
            link.accept()
        self.current = [scenario_fn(i) for i in range(n)]
        self.links[0].send({"cmd": "reset", **self.current[0]})
        first = np.asarray(self.links[0].recv()["obs"], dtype=np.float32)
        self._first = first
        obs_space = gym.spaces.Box(low=-5.0, high=5.0, shape=first.shape, dtype=np.float32)
        super().__init__(n, obs_space, ACTION_SPACE)
        self.ep_reward = np.zeros(n)
        self.ep_len = np.zeros(n, dtype=np.int64)
        self.ep_start = [time.time()] * n
        self.last_obs = np.zeros((n,) + first.shape, dtype=np.float32)
        self.crashes = 0

    def reset(self):
        obs = np.zeros((self.num_envs,) + self.observation_space.shape, dtype=np.float32)
        for i in range(1, self.num_envs):
            self.links[i].send({"cmd": "reset", **self.current[i]})
        obs[0] = self._first
        for i in range(1, self.num_envs):
            obs[i] = self.links[i].recv()["obs"]
        self.ep_reward[:] = 0
        self.ep_len[:] = 0
        self.last_obs[:] = obs
        return obs

    def step_async(self, actions) -> None:
        for link, a in zip(self.links, actions):
            try:
                link.send({"cmd": "step", "a": [int(x) for x in a]})
            except OSError:
                pass  # jeu arrêté : relancé dans step_wait

    def step_wait(self):
        n = self.num_envs
        obs = np.zeros((n,) + self.observation_space.shape, dtype=np.float32)
        rews = np.zeros(n, dtype=np.float32)
        dones = np.zeros(n, dtype=bool)
        infos: list[dict] = [{} for _ in range(n)]
        msgs = [self._recv(i) for i in range(n)]
        ended = []
        for i, m in enumerate(msgs):
            if m is None:
                # le jeu s'est arrêté : relancé, l'épisode compte comme fini (sans bilan)
                obs[i] = self._restart(i)
                dones[i] = True
                infos[i] = {"terminal_observation": self.last_obs[i].copy()}
                self.ep_reward[i] = 0
                self.ep_len[i] = 0
                continue
            obs[i] = m["obs"]
            rews[i] = m["r"]
            self.ep_reward[i] += m["r"]
            self.ep_len[i] += 1
            if m["done"]:
                dones[i] = True
                info = dict(m.get("info", {}))
                info["terminal_observation"] = obs[i].copy()
                info["episode"] = {"r": float(self.ep_reward[i]), "l": int(self.ep_len[i]),
                                   "t": round(time.time() - self.ep_start[i], 3)}
                info["scenario"] = self.current[i]
                infos[i] = info
                if self.on_episode:
                    self.on_episode(i, self.current[i], info)
                self.ep_reward[i] = 0
                self.ep_len[i] = 0
                self.ep_start[i] = time.time()
                self.current[i] = self.scenario_fn(i)
                self.links[i].send({"cmd": "reset", **self.current[i]})
                ended.append(i)
        for i in ended:
            m = self._recv(i)
            obs[i] = m["obs"] if m is not None else self._restart(i)
        self.last_obs[:] = obs
        return obs, rews, dones, infos

    def _recv(self, i: int) -> dict | None:
        try:
            return self.links[i].recv()
        except (ConnectionError, OSError, ValueError):
            if self.watch:
                raise
            return None

    def _restart(self, i: int) -> np.ndarray:
        """Relance le jeu i (plantage) et renvoie la première observation du nouvel épisode."""
        self.crashes += 1
        print(f"  ! le jeu {i + 1} s'est arrêté (journal : {self.links[i].log_path}) : relance ({self.crashes} depuis le début)")
        try:
            self.links[i].proc.kill()
        except OSError:
            pass
        self.links[i].close()
        self.links[i] = GodotLink(self.watch, self.extra_args)
        self.links[i].accept()
        self.current[i] = self.scenario_fn(i)
        self.links[i].send({"cmd": "reset", **self.current[i]})
        self.ep_start[i] = time.time()
        return np.asarray(self.links[i].recv()["obs"], dtype=np.float32)

    def close(self) -> None:
        for link in self.links:
            link.close()

    # --- fonctions demandées par VecEnv (inutiles ici) ---
    def get_attr(self, attr_name, indices=None):
        return [getattr(self, attr_name, None) for _ in self._get_indices(indices)]

    def set_attr(self, attr_name, value, indices=None) -> None:
        pass

    def env_method(self, method_name, *method_args, indices=None, **method_kwargs):
        return [None for _ in self._get_indices(indices)]

    def env_is_wrapped(self, wrapper_class, indices=None):
        return [False for _ in self._get_indices(indices)]

    def seed(self, seed=None):
        return [None] * self.num_envs

    def _get_indices(self, indices):
        if indices is None:
            return range(self.num_envs)
        if isinstance(indices, int):
            return [indices]
        return indices
