#!/usr/bin/env python3
"""Parties de L'Assaut entre IA (8 héros scriptés, lots TAC-3 à TAC-5) : équilibre Attaque / Défense, façons de gagner, durée
des manches. Lance `world.tscn -- --assault --assault-watch --autoplay --auto-quit` (une partie par graine, en parallèle) et
lit les lignes `[assault] manche … gagnée par …` et `[assault] fin` (une ligne JSON par manche dans --jsonl).

    python tools/assault_games.py --games 8 -j 2                      # Bourg, Difficile contre Difficile, règles du jeu
    python tools/assault_games.py --games 6 --win 4 --rule buy_time:2  # parties courtes (premier à 4), achat de 2 s
    python tools/assault_games.py --game-dir <copie>/game --speed 3    # sur une copie propre (tools/run_tests.py --snap)

Les mesures servent les rapports R_TAC_3.md à R_TAC_5.md (cible de l'étude : Attaque 45 à 55 % par carte, manche jouée de
55 à 80 s de médiane). Machine chargée : relancer avant de conclure (bruit de ±10 points sur 60 manches).
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
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
GODOT = Path.home() / "Godot" / "Godot_v4.7.2-stable_win64_console.exe"
ROUND = re.compile(r"\[assault\] manche (\d+) gagnée par l'équipe (\d) \((attaque|défense), ([^)]+)\) en ([\d.]+) s")
FIN = re.compile(r"\[assault\] fin : (\S+)")


def one(seed: int, a) -> dict:
    user = tempfile.mkdtemp(prefix="assault_games_")
    env = dict(os.environ, APPDATA=user)
    cmd = [str(a.godot), "--headless", "--path", str(a.game_dir), "res://scenes/world.tscn", "--fixed-fps", "60", "--",
           "--assault", "--assault-watch", "--autoplay", "--auto-quit", "--assault-seed=%d" % seed,
           "--assault-speed=%s" % a.speed, "--assault-map=%s" % a.map, "--assault-diff=%d" % a.diff]
    if a.win:
        cmd.append("--assault-win=%d" % a.win)
        cmd.append("--assault-half=%d" % max(1, a.win - 1))
    for r in a.rule:
        cmd.append("--assault-rule=%s" % r)
    cmd += a.extra
    try:
        out = subprocess.run(cmd, env=env, capture_output=True, text=True, encoding="utf-8", errors="replace",
                             timeout=a.timeout).stdout
    except subprocess.TimeoutExpired as e:
        out = (e.stdout or b"").decode("utf-8", "replace") if isinstance(e.stdout, bytes) else (e.stdout or "")
    rounds = []
    for m in ROUND.finditer(out):
        rounds.append({"seed": seed, "n": int(m.group(1)), "winner": int(m.group(2)), "side": m.group(3),
                       "how": m.group(4), "time": float(m.group(5))})
    fin = FIN.search(out)
    extra = [l for l in out.splitlines() if l.startswith("[assault] mesure")]
    return {"seed": seed, "rounds": rounds, "done": fin is not None, "extra": extra}


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--games", type=int, default=6)
    ap.add_argument("-j", "--jobs", type=int, default=2)
    ap.add_argument("--seed", type=int, default=1000)
    ap.add_argument("--speed", default="3")
    ap.add_argument("--map", default="bourg")
    ap.add_argument("--diff", type=int, default=2)
    ap.add_argument("--win", type=int, default=0, help="manches pour gagner (0 : règle du jeu, premier à 7)")
    ap.add_argument("--rule", action="append", default=[], help="règle d'essai clé:valeur (Assault.RULES)")
    ap.add_argument("--game-dir", default=str(ROOT / "game"))
    ap.add_argument("--godot", default=str(GODOT))
    ap.add_argument("--timeout", type=int, default=2400)
    ap.add_argument("--jsonl", help="écrit une ligne JSON par manche")
    ap.add_argument("extra", nargs="*", help="arguments de plus pour le jeu (après --)")
    a = ap.parse_args()
    seeds = [a.seed + i for i in range(a.games)]
    res = []
    with cf.ThreadPoolExecutor(max_workers=a.jobs) as ex:
        for r in ex.map(lambda s: one(s, a), seeds):
            res.append(r)
            print("graine %d : %d manches%s" % (r["seed"], len(r["rounds"]), "" if r["done"] else " (pas finie)"), flush=True)
            for l in r["extra"]:
                print("   " + l)
    rounds = [x for r in res for x in r["rounds"]]
    if a.jsonl:
        with open(a.jsonl, "w", encoding="utf-8") as f:
            for x in rounds:
                f.write(json.dumps(x, ensure_ascii=False) + "\n")
    if not rounds:
        print("aucune manche lue")
        return 1
    att = sum(1 for x in rounds if x["side"] == "attaque")
    hows = {}
    for x in rounds:
        hows[x["how"]] = hows.get(x["how"], 0) + 1
    times = sorted(x["time"] for x in rounds)
    print("manches : %d (parties finies %d / %d)" % (len(rounds), sum(1 for r in res if r["done"]), len(res)))
    print("Attaque gagne : %d (%.0f %%)" % (att, 100.0 * att / len(rounds)))
    print("façons : " + ", ".join("%s %d (%.0f %%)" % (k, v, 100.0 * v / len(rounds)) for k, v in sorted(hows.items())))
    print("durée des manches : médiane %.1f s, 10e %.1f s, 90e %.1f s" % (statistics.median(times), times[len(times) // 10],
                                                                         times[min(len(times) - 1, len(times) * 9 // 10)]))
    return 0


if __name__ == "__main__":
    sys.exit(main())
