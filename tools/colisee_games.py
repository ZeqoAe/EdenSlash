#!/usr/bin/env python3
"""Banc IA contre IA du Colisée (lot CO-D, conception/benchmark/R_CO_D.md) : parties complètes entre trios scriptés
(ClassRival + chef d'équipe ColiseeCoach), le joueur au repos. Lance
`world.tscn -- --colisee --co-watch --autoplay --auto-quit --co-nofallback ...` (une partie par graine, en parallèle),
lit la ligne `[colisee] partie {…}` de chaque partie (une ligne JSON par partie dans --jsonl) et fait le rapport :
manches gagnées par réglage (difficulté × chef), durée des combats, passivité (premier coup, dégâts par seconde du camp
le plus faible), anneau de feu, fleurs, équilibre des familles et des classes, durée des parties.

    python tools/colisee_games.py --setup lr --games 6 -j 2          # Légende contre Recrue (fiches du jeu)
    python tools/colisee_games.py --setup lr_even --games 6 -j 2     # idem, fiche égale (seul le jeu compte)
    python tools/colisee_games.py --setup chef2 --games 6 -j 2       # Champion avec chef contre Champion sans chef
    python tools/colisee_games.py --setup jeu --games 8 -j 2         # partie du jeu (toutes Champion) : durées, familles
    python tools/colisee_games.py --report runs.jsonl [autre.jsonl]  # rapport seul, sur des parties déjà jouées
    python tools/colisee_games.py --game-dir <copie>/game ...        # sur une copie propre (tools/run_tests.py --snap)

Réglages (--setup) : difficultés par équipe (0 Recrue, 1 Vétéran, 2 Champion, 3 Légende), niveau du chef par équipe (-1 : aucun
chef, le héros scripté seul), fiche égale (--co-even : sans le facteur de PV et de dégâts par difficulté). Machine chargée :
noter le nombre de Godot actifs (colonne « godot ») et relancer avant de conclure.
"""
import argparse
import concurrent.futures as cf
import json
import os
import re
import statistics
import subprocess
import sys
import tempfile
from collections import defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
GODOT = Path.home() / "Godot" / "Godot_v4.7.2-stable_win64_console.exe"
NAMES = ["Recrue", "Vétéran", "Champion", "Légende"]
FAMILIES = {1: "Guerriers", 2: "Combattants", 3: "Tireurs", 4: "Soutiens", 5: "Mages"}
SETUPS = {
    # nom : (format, difficultés, chefs (None : = difficulté), fiche égale)
    "lr": ("classique", [3, 0, 3, 0, 3, 0], None, False),
    "lr_even": ("classique", [3, 0, 3, 0, 3, 0], None, True),
    "echelle": ("classique", [0, 1, 2, 3, 1, 2], None, False),
    "echelle_even": ("classique", [0, 1, 2, 3, 1, 2], None, True),
    "chef1": ("classique", [1] * 6, [1, -1, 1, -1, 1, -1], True),
    "chef2": ("classique", [2] * 6, [2, -1, 2, -1, 2, -1], True),
    "chef3": ("classique", [3] * 6, [3, -1, 3, -1, 3, -1], True),
    "chef3_2": ("classique", [3] * 6, [3, 2, 3, 2, 3, 2], True),
    "jeu": ("classique", [2] * 6, None, False),
    "jeu1": ("classique", [1] * 6, None, False),
    "jeu3": ("classique", [3] * 6, None, False),
    "grand": ("grand", [2] * 8, None, False),
}
PARTIE = re.compile(r"^\[colisee\] partie (\{.*\})\s*$", re.M)


def godot_count() -> int:
    try:
        out = subprocess.run(["tasklist"] if os.name == "nt" else ["ps", "-A"], capture_output=True, text=True,
                             errors="replace", timeout=90).stdout
        return sum(1 for l in out.splitlines() if "godot" in l.lower())
    except (OSError, subprocess.TimeoutExpired):
        return -1


def setup_of(a):
    """Réglage choisi (--setup), corrigé par --format / --diffs / --coach / --even."""
    fmt, diffs, coach, even = SETUPS[a.setup]
    if a.format:
        fmt = a.format
    if a.diffs:
        diffs = [int(x) for x in a.diffs.split(",")]
    if a.coach:
        coach = [int(x) for x in a.coach.split(",")]
    if a.even:
        even = True
    return fmt, diffs, coach, even


def one(seed: int, a) -> dict:
    fmt, diffs, coach, even = setup_of(a)
    user = tempfile.mkdtemp(prefix="co2_games_")
    env = dict(os.environ, APPDATA=user)
    cmd = [str(a.godot), "--headless", "--path", str(a.game_dir), "res://scenes/world.tscn", "--fixed-fps", "60", "--",
           "--colisee", "--co-watch", "--autoplay", "--auto-quit", "--co-nofallback", "--co-seed=%d" % seed,
           "--co-format=%s" % fmt, "--co-diffs=%s" % ",".join(map(str, diffs))]
    if coach is not None:
        cmd.append("--co-coach=%s" % ",".join(map(str, coach)))
    if even:
        cmd.append("--co-even")
    cmd += a.extra
    load = a.load
    code = None
    try:
        p = subprocess.run(cmd, env=env, capture_output=True, text=True, encoding="utf-8", errors="replace", timeout=a.timeout)
        out, code = p.stdout, p.returncode
    except subprocess.TimeoutExpired as e:
        out = e.stdout.decode("utf-8", "replace") if isinstance(e.stdout, bytes) else (e.stdout or "")
        code = "délai dépassé"
    m = PARTIE.search(out or "")
    errs = [l for l in (out or "").splitlines() if "SCRIPT ERROR" in l]
    if not m:
        tail = [l for l in (out or "").splitlines() if l.startswith("[colisee]")][-3:]
        return {"seed": seed, "setup": a.setup, "done": False, "errors": errs[:5] + ["code %s" % code] + tail, "godot": load}
    d = json.loads(m.group(1))
    d.update({"setup": a.setup, "done": True, "errors": errs[:5], "godot": load})
    return d


def label(diff: int, coach: int, even: bool) -> str:
    return "%s%s%s" % (NAMES[diff], "" if coach == diff else (" sans chef" if coach < 0 else " chef %s" % NAMES[coach]),
                       " (fiche égale)" if even else "")


def winner(f: dict) -> int:
    """0 : camp A, 1 : camp B, -1 : égalité exacte (au temps : la plus grande part de PV restants)."""
    w = int(f["winner"])
    if w == int(f["a"]):
        return 0
    if w == int(f["b"]):
        return 1
    la, lb = float(f.get("left_a", 0)), float(f.get("left_b", 0))
    if abs(la - lb) < 0.001:
        return -1
    return 0 if la > lb else 1


def q(xs, p):
    if not xs:
        return float("nan")
    s = sorted(xs)
    return s[min(len(s) - 1, int(len(s) * p))]


def report(games: list) -> None:
    games = [g for g in games if g.get("done")]
    if not games:
        print("aucune partie finie")
        return
    fights = []
    for g in games:
        for f in g["fights"]:
            f = dict(f)
            f["even"] = bool(g.get("even"))
            f["setup"] = g.get("setup", "")
            fights.append(f)
    real = [f for f in fights if f.get("mode") == "real"]
    print("\n== %d parties, %d combats (%d réels), Godot actifs au lancement : %s" % (
        len(games), len(fights), len(real), sorted(set(g.get("godot", -1) for g in games))))
    errs = sum(len(g.get("errors", [])) for g in games)
    if errs:
        print("   ERREURS DE SCRIPT : %d" % errs)
    # manches gagnées par réglage
    pair = defaultdict(lambda: [0, 0, 0])  # (réglage x, réglage y) x < y : [x gagne, y gagne, égalités]
    for f in real:
        la = label(int(f["diff_a"]), int(f["coach_a"]), f["even"])
        lb = label(int(f["diff_b"]), int(f["coach_b"]), f["even"])
        w = winner(f)
        if la == lb:
            continue
        if la > lb:
            la, lb = lb, la
            w = {0: 1, 1: 0, -1: -1}[w]
        e = pair[(la, lb)]
        e[2 if w < 0 else w] += 1
    print("\n-- Manches gagnées entre réglages différents")
    for (la, lb), (wa, wb, t) in sorted(pair.items()):
        n = wa + wb + t
        print("   %-34s contre %-34s : %3d combats, %5.1f %% / %5.1f %% (égalités %d)" % (la, lb, n, 100.0 * wa / n, 100.0 * wb / n, t))
    # durées
    times = [float(f["time"]) for f in real]
    to = sum(1 for f in real if float(f["time"]) >= 84.9)
    print("\n-- Combats : durée médiane %.1f s (p10 %.1f, p90 %.1f), au temps (85 s) %d sur %d (%.0f %%)" % (
        statistics.median(times), q(times, 0.1), q(times, 0.9), to, len(real), 100.0 * to / max(1, len(real))))
    same = [f for f in real if int(f["diff_a"]) == int(f["diff_b"]) and int(f["coach_a"]) == int(f["coach_b"])]
    by = defaultdict(list)
    for f in same:
        by[label(int(f["diff_a"]), int(f["coach_a"]), f["even"])].append(float(f["time"]))
    for k, v in sorted(by.items()):
        print("   miroir %-34s : %3d combats, médiane %.1f s (p10 %.1f, p90 %.1f), au temps %d" % (
            k, len(v), statistics.median(v), q(v, 0.1), q(v, 0.9), sum(1 for x in v if x >= 84.9)))
    # passivité
    fh = [float(f["first_hit"]) for f in real if float(f.get("first_hit", -1)) >= 0]
    low = []
    for f in real:
        t = max(1.0, float(f["time"]))
        low.append(min(float(f["dealt_a"]), float(f["dealt_b"])) / t)
    nohit = sum(1 for f in real if float(f.get("first_hit", -1)) < 0)
    print("\n-- Passivité : premier coup médian %.1f s (p90 %.1f, max %.1f), combats sans coup %d ; dégâts par seconde du camp"
          " le plus faible : médiane %.0f, p10 %.0f, min %.0f" % (statistics.median(fh) if fh else -1, q(fh, 0.9),
                                                                   max(fh) if fh else -1, nohit, statistics.median(low),
                                                                   q(low, 0.1), min(low)))
    out = [float(f["out_a"]) + float(f["out_b"]) for f in real]
    fl = [int(f["flowers_a"]) + int(f["flowers_b"]) for f in real]
    print("   anneau : secondes-héros dans le feu par combat, médiane %.1f (p90 %.1f) ; fleurs prises par combat %.2f" % (
        statistics.median(out), q(out, 0.9), statistics.mean(fl)))
    chefs = defaultdict(lambda: defaultdict(float))
    nch = defaultdict(int)
    for f in real:
        for s in ("a", "b"):
            c = f.get("chef_" + s) or {}
            if not c:
                continue
            lv = int(f["coach_" + s])
            nch[lv] += 1
            for k, v in c.items():
                chefs[lv][k] += float(v)
    for lv in sorted(chefs):
        print("   chef %s (%d combats) : %s" % (NAMES[lv], nch[lv], ", ".join(
            "%s %.1f" % (k, v / nch[lv]) for k, v in sorted(chefs[lv].items()))))
    # familles et classes (combats entre réglages identiques seulement)
    fam = defaultdict(lambda: [0, 0])
    cls = defaultdict(lambda: [0, 0])
    for f in same:
        w = winner(f)
        if w < 0:
            continue
        for s, side in (("a", 0), ("b", 1)):
            for c in f["cls_" + s]:
                cls[c][0] += 1 if w == side else 0
                cls[c][1] += 1
    for g in games:
        for f in g["fights"]:
            if f.get("mode") != "real" or int(f["diff_a"]) != int(f["diff_b"]) or int(f["coach_a"]) != int(f["coach_b"]):
                continue
            w = winner(f)
            if w < 0:
                continue
            fa = g["families"][int(f["a"])]
            fb = g["families"][int(f["b"])]
            for fs, side in ((fa, 0), (fb, 1)):
                for x in set(fs):
                    fam[x][0] += 1 if w == side else 0
                    fam[x][1] += 1
    if fam:
        print("\n-- Familles (combats miroirs) : part des combats gagnés quand la famille est dans le trio")
        for x in sorted(fam):
            wv, n = fam[x]
            print("   %-12s %3d combats : %5.1f %%" % (FAMILIES.get(int(x), x), n, 100.0 * wv / n))
    if cls:
        rows = sorted(((100.0 * w / n, n, c) for c, (w, n) in cls.items() if n >= 3), reverse=True)
        print("   classes (au moins 3 combats) : meilleures %s ; plus faibles %s" % (
            ", ".join("%s %.0f %% (%d)" % (c, p, n) for p, n, c in rows[:5]),
            ", ".join("%s %.0f %% (%d)" % (c, p, n) for p, n, c in rows[-5:])))
    gm = [float(g["game_min"]) for g in games]
    rounds = [int(g["rounds"]) for g in games]
    prep = [float(g["game_min"]) + int(g["rounds"]) * 29.0 / 60.0 for g in games]
    print("\n-- Parties : %.1f manches (médiane %d), %.1f min de jeu (préparation de 1 s), ≈ %.1f min avec 30 s de préparation,"
          " %.1f min réelles" % (statistics.mean(rounds), statistics.median(rounds), statistics.median(gm),
                                 statistics.median(prep), statistics.median([float(g["real_min"]) for g in games])))
    places = defaultdict(list)
    for g in games:
        for t, p in enumerate(g["places"]):
            places[label(int(g["diffs"][t]), int(g["coach"][t]), bool(g.get("even")))].append(int(p))
    for k, v in sorted(places.items()):
        print("   place moyenne %-34s : %.2f (1re %d fois sur %d)" % (k, statistics.mean(v), v.count(1), len(v)))


def main() -> int:
    try:
        sys.stdout.reconfigure(encoding="utf-8")  # (console Windows : accents et signes)
    except (AttributeError, ValueError):
        pass
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--setup", default="jeu", choices=sorted(SETUPS))
    ap.add_argument("--games", type=int, default=4)
    ap.add_argument("--format", help="classique, eclair ou grand (remplace celui du réglage)")
    ap.add_argument("--diffs", help="difficultés par équipe, ex. 3,0,3,0 (remplace celles du réglage)")
    ap.add_argument("--coach", help="niveaux de chef par équipe, -1 : aucun (remplace ceux du réglage)")
    ap.add_argument("--even", action="store_true", help="fiche égale à toutes les difficultés")
    ap.add_argument("-j", "--jobs", type=int, default=2)
    ap.add_argument("--seed", type=int, default=1000)
    ap.add_argument("--game-dir", default=str(ROOT / "game"))
    ap.add_argument("--godot", default=str(GODOT))
    ap.add_argument("--timeout", type=int, default=1500, help="s au plus par partie (une erreur de script fige le jeu)")
    ap.add_argument("--jsonl", help="ajoute une ligne JSON par partie à ce fichier")
    ap.add_argument("--report", nargs="*", help="rapport seul sur ces fichiers JSONL")
    ap.add_argument("extra", nargs="*", help="arguments de plus pour le jeu (après --)")
    a = ap.parse_args()
    if a.report:
        games = []
        for p in a.report:
            for line in Path(p).read_text("utf-8").splitlines():
                if line.strip():
                    games.append(json.loads(line))
        report(games)
        return 0
    seeds = [a.seed + i for i in range(a.games)]
    a.load = godot_count()  # (une fois : tasklist peut prendre des minutes sur une machine saturée)
    res = []
    with cf.ThreadPoolExecutor(max_workers=a.jobs) as ex:
        for r in ex.map(lambda s: one(s, a), seeds):
            res.append(r)
            print("graine %d : %s%s" % (r["seed"], ("%d manches, %.1f min réelles" % (r["rounds"], r["real_min"]))
                                       if r.get("done") else "PAS FINIE", (" · erreurs %s" % r["errors"]) if r.get("errors") else ""),
                  flush=True)
            if a.jsonl:
                with open(a.jsonl, "a", encoding="utf-8") as fh:
                    fh.write(json.dumps(r, ensure_ascii=False) + "\n")
    report(res)
    return 0 if all(r.get("done") for r in res) else 1


if __name__ == "__main__":
    sys.exit(main())
