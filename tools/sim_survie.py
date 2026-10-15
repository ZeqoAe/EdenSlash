#!/usr/bin/env python
"""Mesures d'équilibrage de la Survie : lance le pilote automatique (world.tscn -- --autoplay) sur
plusieurs classes / graines / équipements du hub, en parallèle, et résume : le héros arrive-t-il au
boss de la map 1, le bat-il, à quel niveau, en combien de temps.

    python tools/sim_survie.py --hub new --classes warrior,magician --seeds 3 --epoch 1
    python tools/sim_survie.py --hub 1.3.10.3 --boss-after 360

--hub : « new » (équipement de départ d'un compte neuf) ou « E.C.N[.G] » (voir StarterGear.scenario).
Un profil jetable par processus (variable EDEN_PROFILE) : le vrai profil n'est jamais touché.
"""
import argparse
import os
import re
import subprocess
import sys
import tempfile
from concurrent.futures import ThreadPoolExecutor

GODOT = r"C:\Users\Nico\Godot\Godot_v4.7.2-stable_win64.exe"
GAME = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "game")


def run_one(job):
    cls, seed, a, idx = job
    env = dict(os.environ)
    env["EDEN_PROFILE"] = "user://sim_%d_%s_%d.json" % (os.getpid(), cls, idx)
    cmd = [GODOT, "--headless", "--fixed-fps", "60", "--path", GAME, "res://scenes/world.tscn", "--", "--autoplay",
           "--auto-quit", "--class=" + cls, "--hub=" + a.hub, "--epoch=%d" % a.epoch, "--seed=%d" % seed,
           "--boss-after=%d" % a.boss_after, "--quit-at=%d" % a.quit_at, "--human=%s" % a.human, "--fight=%s" % a.fight]
    try:
        out = subprocess.run(cmd, env=env, capture_output=True, text=True, timeout=a.timeout, encoding="utf-8", errors="replace").stdout
    except subprocess.TimeoutExpired:
        return {"cls": cls, "seed": seed, "res": "timeout"}
    r = {"cls": cls, "seed": seed, "res": "pas de fin (délai %ds)" % a.quit_at}
    m = re.search(r"\[fin\] résultat=(\w+) niveau=(\d+) temps=(\d+) étape=(\d+) tués=(\d+) élites=(\d+) insignes=(\d+) pv=(\d+) atk=(\d+) matk=(\d+)", out)
    if m:
        r.update(res=m.group(1), lvl=int(m.group(2)), t=int(m.group(3)), stage=int(m.group(4)), kills=int(m.group(5)),
                 elites=int(m.group(6)), ins=int(m.group(7)), hp=int(m.group(8)), atk=int(m.group(9)), matk=int(m.group(10)))
    else:
        m2 = re.search(r"\[bilan\] (\d+) s · état (\w+) · niveau (\d+) · tués (\d+)", out)
        if m2:
            r.update(t=int(m2.group(1)), state=m2.group(2), lvl=int(m2.group(3)), kills=int(m2.group(4)))
    m = re.search(r"entrée dans l'arène à (\d+) s, niveau (\d+)", out)
    r["boss"] = bool(m)
    if m:
        r["boss_t"] = int(m.group(1))
        r["boss_lvl"] = int(m.group(2))
    r["won_boss"] = "boss vaincu" in out
    return r


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--hub", default="new")
    ap.add_argument("--classes", default="warrior")
    ap.add_argument("--seeds", type=int, default=2)
    ap.add_argument("--epoch", type=int, default=1)
    ap.add_argument("--boss-after", dest="boss_after", type=int, default=420)
    ap.add_argument("--quit-at", dest="quit_at", type=int, default=900)
    ap.add_argument("--timeout", type=int, default=900)
    ap.add_argument("--jobs", type=int, default=5)
    ap.add_argument("--fight", default="8", help="le bot combat les monstres à moins de N mètres avant de marcher vers un objectif")
    ap.add_argument("--human", default="0", help="part des coups évités par un joueur humain (0 : le bot brut, 0.3 débutant, 0.5 bon joueur)")
    a = ap.parse_args()
    jobs = []
    for cls in a.classes.split(","):
        for s in range(a.seeds):
            jobs.append((cls, 1000 + s * 7919, a, len(jobs)))
    with ThreadPoolExecutor(max_workers=a.jobs) as ex:
        res = list(ex.map(run_one, jobs))
    print("hub=%s époque=%d boss-après=%ds coups évités=%s" % (a.hub, a.epoch, a.boss_after, a.human))
    for r in res:
        print(" ", r)
    n = len(res)
    reached = sum(1 for r in res if r.get("boss"))
    won = sum(1 for r in res if r.get("won_boss"))
    print("=> %d runs : boss atteint %d (%.0f %%), boss battu %d (%.0f %%)" % (n, reached, 100.0 * reached / n, won, 100.0 * won / n))


if __name__ == "__main__":
    main()
