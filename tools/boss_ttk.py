#!/usr/bin/env python
"""Passe P11 : temps pour tuer (TTK) les boss de la Survie selon la puissance du héros (res://tools/boss_ttk.tscn).

    python tools/boss_ttk.py                       # 4 scénarios × 4 époques × 3 cartes × 5 classes (héros invincible)
    python tools/boss_ttk.py --epochs 1 --scenarios rush,bonne --human 0.5   # le héros encaisse et peut mourir

Scénarios (niveau, cartes, trophées, part des emplacements trouvés en run, emplacements passés à l'enclume, par carte) :
  rush    : boss atteint tôt, presque rien ramassé ;
  moyenne : run ordinaire ;
  bonne   : carte exploitée (niveau plafond, cartes, trophées, coffres, enclume) ;
  doree   : bonne run + équipement du hub optimisé de l'époque.
Équipement du hub d'un joueur qui joue cette époque (scénarios rush / moyenne / bonne) : HUB ; run dorée : HUB_GOLD.
"""
import argparse
import os
import re
import statistics
import subprocess
from concurrent.futures import ThreadPoolExecutor

GODOT = r"C:\Users\Nico\Godot\Godot_v4.7.2-stable_win64.exe"
GAME = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "game")
CLASSES = ["warrior", "thief", "hunter", "cleric", "magician"]
# carte 1 / 2 / 3 : (niveau, cartes, trophées, trouvailles, enclume)
SCENARIOS = {
    "rush": [(8, 7, 0, 0.0, 0), (17, 16, 1, 0.3, 0), (26, 24, 2, 0.3, 1)],
    "moyenne": [(13, 12, 2, 0.4, 1), (22, 21, 4, 0.4, 2), (31, 28, 6, 0.4, 2)],
    "bonne": [(15, 16, 4, 0.7, 1), (25, 27, 7, 0.7, 2), (35, 36, 10, 0.7, 3)],
    "doree": [(15, 18, 6, 1.0, 3), (25, 29, 10, 1.0, 6), (35, 38, 12, 1.0, 9)],
}
HUB = {1: "new", 2: "1.3.5.1", 3: "2.3.10.3", 4: "3.3.10.4"}
HUB_GOLD = {1: "1.3.10.3", 2: "2.3.10.4", 3: "3.3.10.4", 4: "4.3.10.4"}
# Donjons / Ruée (--dungeons) : équipement du hub d'un joueur qui y arrive (Normal dès l'époque II, Héroïque vers
# l'époque III, Mythique après l'époque IV) et d'un joueur sur-équipé ; 3 cartes (une par salle) avant le boss.
DUNGEON_HUB = {0: ("2.1.5.2", "4.3.10.4"), 1: ("3.3.10.4", "4.3.10.4"), 2: ("4.3.10.4", "4.3.10.4")}
DUNGEON_ZONES = ["limestone", "wetlands", "blackflame", "rush"]


def run_one(job):
    sc, ep, st, cls, a, idx = job
    env = dict(os.environ)
    env["EDEN_PROFILE"] = "user://sim_ttk_%d_%d.json" % (os.getpid(), idx)
    cmd = [GODOT, "--headless", "--fixed-fps", "60", "--path", GAME, "res://tools/boss_ttk.tscn", "--"]
    if sc.startswith("donjon"):
        # ep = indice de zone (DUNGEON_ZONES), st = difficulté + 1 ; « donjon » : équipement attendu, « donjon+ » : sur-équipé
        hub = DUNGEON_HUB[st - 1][1 if sc.endswith("+") else 0]
        cmd += ["--mode=dungeon", "--zone=" + DUNGEON_ZONES[ep - 1], "--diff=%d" % (st - 1), "--class=" + cls, "--hub=" + hub,
                "--cards=3", "--seed=%d" % (a.seed + idx), "--max=%d" % a.max]
        if DUNGEON_ZONES[ep - 1] == "rush":
            cmd.append("--floor=4")
    else:
        lv, cards, tro, finds, anvil = SCENARIOS[sc][st - 1]
        hub = HUB_GOLD[ep] if sc == "doree" else HUB[ep]
        cmd += ["--epoch=%d" % ep, "--stage=%d" % st, "--class=" + cls, "--hub=" + hub, "--level=%d" % lv, "--cards=%d" % cards,
                "--trophies=%d" % tro, "--finds=%s" % finds, "--anvil=%d" % anvil, "--seed=%d" % (a.seed + idx), "--max=%d" % a.max]
    if a.human:
        cmd.append("--human=%s" % a.human)
    if a.pure:
        cmd.append("--pure")
    try:
        out = subprocess.run(cmd, env=env, capture_output=True, text=True, timeout=a.timeout, encoding="utf-8", errors="replace").stdout
    except subprocess.TimeoutExpired:
        return {"sc": sc, "ep": ep, "st": st, "cls": cls, "res": "délai"}
    m = re.search(r"résultat=(\S+) ttk=([\d.]+) pv_boss=(\d+) boss_niv=(\d+) dps=(\d+) atk=(\d+) pv=(\d+)", out)
    if not m:
        return {"sc": sc, "ep": ep, "st": st, "cls": cls, "res": "erreur"}
    return {"sc": sc, "ep": ep, "st": st, "cls": cls, "res": m.group(1), "ttk": float(m.group(2)), "hp": int(m.group(3)),
            "dps": int(m.group(5)), "atk": int(m.group(6)), "pv": int(m.group(7))}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--scenarios", default="rush,moyenne,bonne,doree")
    ap.add_argument("--epochs", default="1,2,3,4")
    ap.add_argument("--stages", default="1,2,3")
    ap.add_argument("--classes", default=",".join(CLASSES))
    ap.add_argument("--jobs", type=int, default=8)
    ap.add_argument("--max", type=int, default=480, help="durée maximale du combat (s de jeu)")
    ap.add_argument("--timeout", type=int, default=1500)
    ap.add_argument("--seed", type=int, default=1)
    ap.add_argument("--human", default="", help="part des coups évités (le héros peut mourir) ; vide : invincible")
    ap.add_argument("--pure", action="store_true", help="boss sans mécaniques de salle : DPS du héros seul")
    ap.add_argument("--dungeons", action="store_true", help="donjons et Ruée : scénarios donjon (attendu) et donjon+ (sur-équipé), "
                    "époques = zones (1 Limestone, 2 Wetlands, 3 Blackflame, 4 Ruée), cartes = difficulté + 1")
    a = ap.parse_args()
    if a.dungeons and a.scenarios == ap.get_default("scenarios"):
        a.scenarios = "donjon,donjon+"
    jobs = []
    for sc in a.scenarios.split(","):
        for ep in map(int, a.epochs.split(",")):
            for st in map(int, a.stages.split(",")):
                for cls in a.classes.split(","):
                    jobs.append((sc, ep, st, cls, a, len(jobs)))
    with ThreadPoolExecutor(max_workers=a.jobs) as ex:
        res = list(ex.map(run_one, jobs))
    for r in res:
        print(" ", r)
    print("\nTTK médian (s) [tués / runs] · PV du boss · DPS médian%s" % ("" if not a.human else " · coups évités %s" % a.human))
    for sc in a.scenarios.split(","):
        for ep in map(int, a.epochs.split(",")):
            cells = []
            for st in map(int, a.stages.split(",")):
                rs = [r for r in res if r["sc"] == sc and r["ep"] == ep and r["st"] == st and "ttk" in r]
                if not rs:
                    cells.append("   -   ")
                    continue
                won = sum(1 for r in rs if r["res"] == "tué")
                # un combat non fini compte pour sa durée maximale (médiane minorée)
                cells.append("%5.0f [%d/%d] %7d %6d" % (statistics.median(r["ttk"] for r in rs), won, len(rs),
                                                         statistics.median(r["hp"] for r in rs), statistics.median(r["dps"] for r in rs)))
            print("%-8s E%d | %s" % (sc, ep, " | ".join(cells)))


if __name__ == "__main__":
    main()
