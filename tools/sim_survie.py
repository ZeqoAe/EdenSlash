#!/usr/bin/env python
"""Mesures d'équilibrage de la Survie : lance le pilote automatique (world.tscn -- --autoplay) sur
plusieurs classes / graines / équipements du hub, en parallèle, et résume : le héros arrive-t-il au
boss de la map 1, le bat-il, à quel niveau, en combien de temps.

    python tools/sim_survie.py --hub new --classes warrior,magician --seeds 3 --epoch 1
    python tools/sim_survie.py --hub 1.3.10.3 --boss-after 360
    python tools/sim_survie.py --hub 2.1.5 --epoch 2 --stage 2 --hero-level 48   # lot H4a : carte II-2, héros niveau 48

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
           "--boss-after=%d" % a.boss_after, "--quit-at=%d" % a.quit_at, "--human=%s" % a.human, "--fight=%s" % a.fight] + (["--rush=%s" % a.rush] if a.rush else []) + (a.extra.split() if a.extra else [])
    if a.hero_level:
        cmd.append("--hero-level=%d" % a.hero_level)
    if a.stage > 1:
        cmd.append("--stage=%d" % a.stage)
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
    # passe P15 : dernière ligne de mesure du spawn (avant le boss), voir SpawnDirector.stats_line
    sp = re.findall(r"\[spawn\] t=(\d+) \w+ espèces=(\d+) top=([\d.]+) espèces_fenêtre=([\d.]+) identiques=([\d.]+) par_point=([\d.]+) dispersion=([\d.]+) secteurs=([\d.]+) std=(\d+) pv×([\d.]+) dég×([\d.]+) indice=([\d.]+) monstres=(\d+) .*? dégâts_subis_min=([\d.]+) pv_max=(\d+) ttk=([-\d.]+) niv=(\d+)", out)
    if sp:
        g = sp[-1]
        r["spawn"] = {"t": int(g[0]), "species": int(g[1]), "top": float(g[2]), "win_species": float(g[3]), "same": float(g[4]),
                      "per_point": float(g[5]), "spread": float(g[6]), "sectors": float(g[7]), "std": int(g[8]), "pv": float(g[9]),
                      "deg": float(g[10]), "index": float(g[11]), "monsters": int(g[12]), "taken_min": float(g[13]),
                      "hp_max": int(g[14]), "ttk": float(g[15]), "lvl": int(g[16])}
    m = re.search(r"\[fournitures\] sac=(\{.*?\}) coffres=(\[.*?\]) armes découvertes=(\d+)", out)
    if m:
        bag = {}
        for k, v in re.findall(r'"([^"]+)": (\d+)', m.group(1)):
            bag[k] = int(v)
        r["bag"] = bag
        r["chests"] = re.findall(r'"([^"]+)"', m.group(2))
        r["family"] = int(m.group(3))
    return r


def supplies_summary(res):
    """Fournitures trouvées (lot E4) : parchemins de fortification et formules par niveau, gemmes par rang, coffres."""
    from collections import Counter
    fort, form, gems, chests = Counter(), Counter(), Counter(), Counter()
    n = 0
    for r in res:
        if "bag" not in r:
            continue
        n += 1
        for k, v in r["bag"].items():
            p = k.split(":")
            if p[0] == "fortify":
                fort["Lv%s" % p[2]] += v
            elif p[0] == "scroll":
                form["Lv%s" % p[2]] += v
            elif p[0] == "gem":
                gems["rang %d" % (int(p[2]) + 1)] += v
        for c in r["chests"]:
            chests[c] += 1
    if n:
        f = lambda c: ", ".join("%s ×%.1f" % (k, v / n) for k, v in sorted(c.items()))
        print("=> fournitures par run (%d runs, sac de la run, perdu sur défaite) :" % n)
        print("   parchemins de fortification : %s" % f(fort))
        print("   formules d'enchantement : %s" % f(form))
        print("   gemmes : %s" % f(gems))
        print("   coffres de récompense (gardés) : %s" % f(chests))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--hub", default="new")
    ap.add_argument("--classes", default="warrior")
    ap.add_argument("--seeds", type=int, default=2)
    ap.add_argument("--epoch", type=int, default=1)
    ap.add_argument("--stage", type=int, default=1, help="carte de départ (1 à 3, lot H4a)")
    ap.add_argument("--hero-level", dest="hero_level", type=int, default=0, help="niveau de héros du profil (lot H4a ; 0 : compte neuf, niveau 1)")
    ap.add_argument("--boss-after", dest="boss_after", type=int, default=420)
    ap.add_argument("--quit-at", dest="quit_at", type=int, default=900)
    ap.add_argument("--timeout", type=int, default=900)
    ap.add_argument("--jobs", type=int, default=5)
    ap.add_argument("--fight", default="8", help="le bot combat les monstres à moins de N mètres avant de marcher vers un objectif")
    ap.add_argument("--rush", default="", help="en route vers le boss : suit le chemin du donjon, ne combat qu'à moins de N mètres (P11 : joueur qui file au boss)")
    ap.add_argument("--seed-base", dest="seed_base", type=int, default=1000)
    ap.add_argument("--extra", default="", help="arguments en plus pour le jeu (ex. « --no-cape » : coffres de cape remplacés)")
    ap.add_argument("--human", default="0", help="part des coups évités par un joueur humain (0 : le bot brut, 0.3 débutant, 0.5 bon joueur)")
    a = ap.parse_args()
    jobs = []
    for cls in a.classes.split(","):
        for s in range(a.seeds):
            jobs.append((cls, a.seed_base + s * 7919, a, len(jobs)))
    with ThreadPoolExecutor(max_workers=a.jobs) as ex:
        res = list(ex.map(run_one, jobs))
    print("hub=%s époque=%d carte=%d niveau de héros=%s boss-après=%ds coups évités=%s rush=%s" % (a.hub, a.epoch, a.stage, a.hero_level or 1, a.boss_after, a.human, a.rush or "-"))
    for r in res:
        print(" ", r)
    n = len(res)
    reached = sum(1 for r in res if r.get("boss"))
    won = sum(1 for r in res if r.get("won_boss"))
    print("=> %d runs : boss atteint %d (%.0f %%), boss battu %d (%.0f %%)" % (n, reached, 100.0 * reached / n, won, 100.0 * won / n))
    alive = sum(1 for r in res if r.get("t", 0) >= 420 or r.get("boss"))
    print("=> survit au moins 7 min (ou atteint le boss) : %d (%.0f %%)" % (alive, 100.0 * alive / n))
    spawn_summary(res)
    supplies_summary(res)


def spawn_summary(res):
    """Passe P15 : moyennes de la dernière ligne « [spawn] » de chaque run (composition, directions, pression)."""
    sp = [r["spawn"] for r in res if "spawn" in r]
    if not sp:
        return
    avg = lambda k: sum(s[k] for s in sp) / len(sp)
    pct = lambda s: s["taken_min"] / max(s["hp_max"], 1) * 100.0
    print("=> spawn (%d runs, dernière mesure à %.0f s en moyenne) : espèces %.1f, espèces par fenêtre de 20 s %.1f, espèce la plus vue %.0f %%,"
          " part de l'espèce dominante d'un groupe %.0f %%, monstres par point %.1f, dispersion %.2f (0 = de tous les côtés), secteurs %.1f / 8,"
          " écart-type des angles %.0f°" % (len(sp), avg("t"), avg("species"), avg("win_species"), avg("top") * 100, avg("same") * 100,
                                           avg("per_point"), avg("spread"), avg("sectors"), avg("std")))
    ttk = [s["ttk"] for s in sp if s["ttk"] >= 0]
    print("   pression : dégâts subis %.0f / min (%.0f %% des PV max par minute), TTK des monstres %.2f s, niveau %.1f, PV ×%.2f, dégâts ×%.2f,"
          " indice d'équipement %.2f" % (avg("taken_min"), sum(pct(s) for s in sp) / len(sp), sum(ttk) / max(len(ttk), 1), avg("lvl"),
                                         avg("pv"), avg("deg"), avg("index")))


if __name__ == "__main__":
    main()
