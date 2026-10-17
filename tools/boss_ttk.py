#!/usr/bin/env python
"""Passe P11 : temps pour tuer (TTK) les boss de la Survie selon la puissance du héros (res://tools/boss_ttk.tscn).

    python tools/boss_ttk.py                       # 4 scénarios × 4 époques × 3 cartes × 5 classes (héros invincible)
    python tools/boss_ttk.py --epochs 1 --scenarios rush,bonne --human 0.5   # le héros encaisse et peut mourir
    python tools/boss_ttk.py --scenarios bande,bande-10 --pure              # lot H4a : héros au haut de la bande de chaque carte
    python tools/boss_ttk.py --scenarios bande,bande-10,bande+10 --human 0.5 --repeat 4   # lot H4b : % de boss battus par carte

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
# Lot H4a (Aventure au niveau de héros) : --level = niveau de HÉROS. Scénarios « bande » : héros au haut de la bande de la carte,
# équipement « correct » de la carte (ses pièces à +5), cartes, trophées et trouvailles d'une bonne run ; « bande-10 » : même
# run, équipement en retard de 10 niveaux (les pièces de la carte d'avant +5, héros au même niveau).
BANDS = {1: [23, 33, 43], 2: [48, 53, 60], 3: [65, 70, 75], 4: [80, 85, 90]}
BAND_RUN = [(16, 4, 0.7), (27, 7, 0.7), (36, 10, 0.7)]  # cartes, trophées, trouvailles
# Lot H4b : équipement « retard 10 » (bande-10) et « avance 10 » (bande+10) de chaque carte, choisis pour ≈ 10 niveaux de pièce
# d'écart (×1,08 par niveau ; +0 → +5 ≈ 5 niveaux ; mythique → légendaire ≈ 3 niveaux) ; PE relevées dans R_H4b.md.
# bande-10 : héros au haut de la bande ; bande+10 : (niveau de héros, kit) : héros 10 niveaux au-dessus (90 au plus).
BAND_LATE = {(1, 1): "new", (1, 2): "1.1.5", (1, 3): "1.2.5", (2, 1): "1.3.0", (2, 2): "1.3.5", (2, 3): "2.2.5",
             (3, 1): "2.3.0", (3, 2): "2.3.5", (3, 3): "3.1.5", (4, 1): "3.2.5", (4, 2): "3.3.5", (4, 3): "3.3.5"}
BAND_AHEAD = {(1, 1): (33, "1.2.5"), (1, 2): (43, "1.3.5"), (1, 3): (53, "2.2.5"), (2, 1): (58, "2.2.10"), (2, 2): (63, "2.3.5"),
              (2, 3): (70, "3.2.5"), (3, 1): (75, "3.3.5"), (3, 2): (80, "4.1.5"), (3, 3): (85, "4.2.5"), (4, 1): (90, "4.3.5"),
              (4, 2): (90, "4.3.10.4"), (4, 3): (90, "4.3.10.4")}
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
    elif sc.startswith("bande"):
        lv = BANDS[ep][st - 1]
        cards, tro, finds = BAND_RUN[st - 1]
        if sc == "bande":
            hub = "%d.%d.5" % (ep, st)
        elif sc == "bande+10":
            lv, hub = BAND_AHEAD[(ep, st)]
        else:
            hub = BAND_LATE[(ep, st)]
        cmd += ["--epoch=%d" % ep, "--stage=%d" % st, "--class=" + cls, "--hub=" + hub, "--level=%d" % lv, "--cards=%d" % cards,
                "--trophies=%d" % tro, "--finds=%s" % (finds if sc == "bande" else 0.0), "--anvil=0", "--seed=%d" % (a.seed + idx), "--max=%d" % a.max]
    else:
        lv, cards, tro, finds, anvil = SCENARIOS[sc][st - 1]
        hub = HUB_GOLD[ep] if sc == "doree" else HUB[ep]
        cmd += ["--epoch=%d" % ep, "--stage=%d" % st, "--class=" + cls, "--hub=" + hub, "--level=%d" % lv, "--cards=%d" % cards,
                "--trophies=%d" % tro, "--finds=%s" % finds, "--anvil=%d" % anvil, "--seed=%d" % (a.seed + idx), "--max=%d" % a.max]
    if a.human:
        cmd.append("--human=%s" % a.human)
    if a.extra:
        cmd += a.extra.split()
    if a.pure:
        cmd.append("--pure")
    try:
        out = subprocess.run(cmd, env=env, capture_output=True, text=True, timeout=a.timeout, encoding="utf-8", errors="replace").stdout
    except subprocess.TimeoutExpired:
        return {"sc": sc, "ep": ep, "st": st, "cls": cls, "res": "délai"}
    m = re.search(r"résultat=(\S+) ttk=([\d.]+) pv_boss=(\d+) boss_niv=(\d+) dps=(\d+) atk=(\d+) pv=(\d+)", out)
    if not m:
        return {"sc": sc, "ep": ep, "st": st, "cls": cls, "res": "erreur"}
    r = {"sc": sc, "ep": ep, "st": st, "cls": cls, "res": m.group(1), "ttk": float(m.group(2)), "hp": int(m.group(3)),
         "dps": int(m.group(5)), "atk": int(m.group(6)), "pv": int(m.group(7))}
    t = re.search(r"subis_min=([\d.]+) coup_max=([\d.]+)", out)
    if t:
        r["taken"] = float(t.group(1))  # PV max du héros perdus par minute (avec --human)
        r["hit"] = float(t.group(2))  # plus gros coup, en PV max
    return r


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
    ap.add_argument("--repeat", type=int, default=1, help="lot H4b : combats par classe et par carte (graines différentes)")
    ap.add_argument("--extra", default="", help="arguments en plus pour la sonde (ex. « --boss-scale=0.8 », lot H4a)")
    ap.add_argument("--dungeons", action="store_true", help="donjons et Ruée : scénarios donjon (attendu) et donjon+ (sur-équipé), "
                    "époques = zones (1 Limestone, 2 Wetlands, 3 Blackflame, 4 Ruée), cartes = difficulté + 1")
    a = ap.parse_args()
    if a.dungeons and a.scenarios == ap.get_default("scenarios"):
        a.scenarios = "donjon,donjon+"
    jobs = []
    for sc in a.scenarios.split(","):
        for ep in map(int, a.epochs.split(",")):
            for st in map(int, a.stages.split(",")):
                for _r in range(a.repeat):
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
            if a.human:
                dead = []
                for st in map(int, a.stages.split(",")):
                    rs = [r for r in res if r["sc"] == sc and r["ep"] == ep and r["st"] == st and "taken" in r]
                    dead.append("morts %d/%d, subis %.1f PV max / min, coup max %.2f" % (sum(1 for r in rs if r["res"] == "mort"), len(rs),
                                statistics.median(r["taken"] for r in rs) if rs else -1, statistics.median(r["hit"] for r in rs) if rs else -1))
                print("%-8s    | %s" % ("", " | ".join(dead)))


if __name__ == "__main__":
    main()
