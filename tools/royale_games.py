#!/usr/bin/env python3
"""Parties de Battle royale au pilote automatique, en parallèle, et leur bilan (lot BR-R1, `conception/royale/R_BRR1.md`).

    python tools/royale_games.py --projet C:/AI/brr1_snap/game -n 6 -j 2 --diff 2 [--mod meteors] [--extra "--royale-seed=7"]
    python tools/royale_games.py --lire C:/AI/brr1_work/lot_a      # relit les journaux déjà écrits

Chaque partie : `world.tscn -- --royale --autoplay --auto-quit --royale-diff=<d> [--royale-mod=<id>]` sur une COPIE du jeu (jamais le
dossier de travail partagé : `tools/run_tests.py` sait en préparer une), un dossier utilisateur par partie (APPDATA détourné),
`--fixed-fps 60` (plus vite que le temps réel). Le directeur écrit les lignes lues ici (RoyaleDirector._finish, RoyaleEvent._log) :
  [royale] fin : place … · partie N s …        place du pilote, durée
  [royale] densité {json}                      premier combat, combats par minute, temps mort, lieux, atterrissages, autel, météores
  [royale] élimination T s : a niv. x -> b niv. y · combat N s
Bilan : médianes et totaux par lot, une ligne JSON à la fin (« BILAN {…} ») pour les rapports.
"""
from __future__ import annotations

import argparse
import json
import os
import re
import statistics as stats
import subprocess
import sys
import time
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

GODOT_DEFAULT = Path.home() / "Godot" / "Godot_v4.7.2-stable_win64_console.exe"
RE_FIN = re.compile(r"\[royale\] fin : place (\d+) · (\d+) éliminations · niveau (\d+) · (\d+) coffres · joueur (\d+) s · partie (\d+) s")
RE_KILL = re.compile(r"\[royale\] élimination +(\d+) s : (\S+) niv\. (\d+) -> (\S+) niv\. (\d+) · combat (\d+) s")


def run_one(godot: Path, projet: Path, out: Path, k: int, args: list[str], timeout: int) -> Path:
    log = out / f"partie_{k:02d}.log"
    ud = out / f"ud_{k:02d}"
    ud.mkdir(parents=True, exist_ok=True)
    env = dict(os.environ)
    env["APPDATA"] = str(ud)
    env["XDG_DATA_HOME"] = str(ud)
    env.pop("EDEN_PROFILE", None)
    cmd = [str(godot), "--headless", "--fixed-fps", "60", "--path", str(projet), "res://scenes/world.tscn", "--",
           "--royale", "--autoplay", "--auto-quit", *args]
    t0 = time.time()
    with open(log, "wb") as f:
        try:
            subprocess.run(cmd, stdout=f, stderr=subprocess.STDOUT, env=env, timeout=timeout)
        except subprocess.TimeoutExpired:
            f.write(b"\n[royale_games] TEMPS DEPASSE\n")
    print(f"  partie {k:02d} finie en {time.time() - t0:.0f} s", flush=True)
    return log


def parse(log: Path) -> dict:
    g: dict = {"log": log.name}
    for line in log.read_text(encoding="utf-8", errors="replace").splitlines():
        m = RE_FIN.search(line)
        if m:
            g.update(place=int(m[1]), kills=int(m[2]), level=int(m[3]), chests=int(m[4]), player_s=int(m[5]), game_s=int(m[6]))
        elif "[royale] densité " in line:
            try:
                g["d"] = json.loads(line.split("[royale] densité ", 1)[1])
            except json.JSONDecodeError:
                pass
        else:
            m = RE_KILL.search(line)
            if m:
                g.setdefault("kill_list", []).append({"t": int(m[1]), "killer": m[2], "klv": int(m[3]), "victim": m[4], "vlv": int(m[5]),
                                                     "fight": int(m[6])})
        if "SCRIPT ERROR" in line:
            g["errors"] = g.get("errors", 0) + 1
    return g


def med(xs):
    xs = [x for x in xs if x is not None]
    return round(stats.median(xs), 2) if xs else None


def summary(games: list[dict]) -> dict:
    ok = [g for g in games if "d" in g and "place" in g]
    d = [g["d"] for g in ok]
    land = [0, 0, 0, 0]
    places = [0, 0, 0, 0]
    for x in d:
        for i in range(4):
            land[i] += int(x["land"][i])
            places[i] += int(x["places"][i])
    altar = [x.get("altar", {}) for x in d]
    won = [a for a in altar if a.get("state") == "won"]
    s = {
        "parties": len(ok), "erreurs": sum(g.get("errors", 0) for g in games),
        "pilote_victoires": sum(1 for g in ok if g["place"] == 1), "pilote_place_med": med([g["place"] for g in ok]),
        "duree_med_s": med([g["game_s"] for g in ok]),
        "premier_combat_med_s": med([x["first"] for x in d if x["first"] >= 0]),
        "combats_par_min_med": med([x["per_min"] for x in d]),
        "temps_mort_med": med([x["dead"] for x in d]), "plus_long_temps_mort_med_s": med([x["gap"] for x in d]),
        "combats_lieux": {"hors": places[0], "1": places[1], "2": places[2], "3": places[3]},
        "atterrissages": {"hors": land[0], "1": land[1], "2": land[2], "3": land[3]},
        "combats_par_minute_moy": [round(stats.mean([x["minutes"][i] if i < len(x["minutes"]) else 0 for x in d]), 1)
                                   for i in range(max([len(x["minutes"]) for x in d] or [0]))],
        "autel": {"vaincu": len(won), "par_pilote": sum(1 for a in won if a.get("winner") == "Toi"),
                  "par_scripte": sum(1 for a in won if a.get("winner") not in ("", "Toi")),
                  "parti": sum(1 for a in altar if a.get("state") == "gone"),
                  "premier_coup_apres_s": med([a["first_hit"] - a["awake"] for a in altar if a.get("first_hit", -1) >= 0]),
                  "duree_apres_eveil_s": med([a["end"] - a["awake"] for a in won if a.get("end", -1) >= 0]),
                  "heros_venus_med": med([a.get("hitters", 0) for a in altar]),
                  "morts_pres_autel": sum(a.get("deaths", 0) for a in altar)},
        "meteores": {"tombes": sum(x["meteors"]["fell"] for x in d), "touches": sum(x["meteors"]["hits"] for x in d),
                     "morts": sum(x["meteors"]["kills"] for x in d)},
        "fontaines_bues": sum(int(x.get("wells", 0)) for x in d),
        "combat_med_s": med([k["fight"] for g in ok for k in g.get("kill_list", []) if abs(k["klv"] - k["vlv"]) <= 2]),
    }
    return s


def main() -> int:
    for flux in (sys.stdout, sys.stderr):
        try:
            flux.reconfigure(encoding="utf-8", errors="replace")
        except Exception:
            pass
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--projet", help="copie du jeu (dossier game/ déjà importé)")
    ap.add_argument("-n", type=int, default=4, help="nombre de parties")
    ap.add_argument("-j", type=int, default=2, help="parties en parallèle (machine chargée : 1 ou 2)")
    ap.add_argument("--diff", type=int, default=2, help="difficulté des scriptés (-1 mélange, 0 à 3)")
    ap.add_argument("--mod", default="", help="modificateur (RoyaleMods : meteors, gold, fast, wells, hunt)")
    ap.add_argument("--extra", default="", help="arguments en plus pour world.tscn")
    ap.add_argument("--out", help="dossier des journaux (défaut : <temp>/royale_games/<horodatage>)")
    ap.add_argument("--lire", help="relire les journaux d'un dossier sans lancer de partie")
    ap.add_argument("--godot", help="chemin de Godot (console)")
    ap.add_argument("--timeout", type=int, default=1500, help="délai maximal d'une partie (s)")
    a = ap.parse_args()
    if a.lire:
        out = Path(a.lire)
        logs = sorted(out.glob("partie_*.log"))
    else:
        if not a.projet:
            sys.exit("--projet <copie du jeu> : jamais le dossier de travail partagé")
        godot = Path(a.godot) if a.godot else Path(os.environ.get("GODOT", GODOT_DEFAULT))
        out = Path(a.out) if a.out else Path(os.environ.get("TEMP", "/tmp")) / "royale_games" / time.strftime("%Y%m%d_%H%M%S")
        out.mkdir(parents=True, exist_ok=True)
        args = [f"--royale-diff={a.diff}"] + ([f"--royale-mod={a.mod}"] if a.mod else []) + a.extra.split()
        print(f"{a.n} partie(s), {a.j} en parallèle, {' '.join(args)} -> {out}", flush=True)
        with ThreadPoolExecutor(max_workers=max(1, a.j)) as ex:
            logs = list(ex.map(lambda k: run_one(godot, Path(a.projet), out, k, args, a.timeout), range(1, a.n + 1)))
    games = [parse(p) for p in logs]
    s = summary(games)
    for k, v in s.items():
        print(f"  {k} : {v}")
    print("BILAN " + json.dumps(s, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    sys.exit(main())
