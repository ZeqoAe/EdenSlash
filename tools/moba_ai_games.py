#!/usr/bin/env python3
"""Les Deux Voies (lots MB-D / MB-E, rapports conception/benchmark/R_MB_D.md et R_MB_E.md) : parties IA contre IA mesurées.

    python tools/moba_ai_games.py --projet <copie du projet> -n 20 -j 3 --diff 3 --until 1500
    python tools/moba_ai_games.py --projet <copie> -n 4 --diff 2 --until 600 --perf      # coût de l'image (temps CPU)
    python tools/moba_ai_games.py --tableau conception/benchmark/mb_e/parties.jsonl       # refait le résumé

Chaque partie : world.tscn -- --moba --moba-heroes=watch (8 IA) sans rendu, --fixed-fps 60, accélérée (--speed), graine
propre ; une ligne JSON par partie (« [moba] bilan » du directeur : héros, niveaux, K / M / A, camps vidés et leurs
instants, morts avec leur cause : sous une tour adverse, tuée par une tour / un sbire / un héros, frappée par un héros
dans les 10 s). Avec --perf : temps CPU du processus par image physique entre « [moba] mesure début » et la fin
(GetProcessTimes, insensible à la charge de la machine, comme R_MB0 § 3.4), temps des scripts de chaque image (marques du
directeur : p50 / p95, borne haute sur une machine saturée) et coût moyen d'un héros IA (µs par image).
Le projet doit être une copie importée (tools/run_tests.py, ou la copie de travail d'une session) : le dossier partagé
peut contenir des travaux en cours d'autres sessions.
"""
import argparse
import concurrent.futures as cf
import ctypes
import json
import os
import statistics
import subprocess
import sys
import tempfile
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
# exécutable sans console : le lanceur « _console » est un autre processus (son temps CPU ne serait pas celui du jeu)
GODOT = Path(os.environ.get("GODOT_GUI", str(Path.home() / "Godot" / "Godot_v4.7.2-stable_win64.exe")))


def cpu_process(handle) -> float:
    """Temps CPU (utilisateur + noyau, s) du processus (Windows) ; -1 ailleurs."""
    if os.name != "nt":
        return -1.0
    from ctypes import wintypes

    class FT(ctypes.Structure):
        _fields_ = [("lo", wintypes.DWORD), ("hi", wintypes.DWORD)]
    c, e, k, u = FT(), FT(), FT(), FT()
    ctypes.windll.kernel32.GetProcessTimes(wintypes.HANDLE(int(handle)), ctypes.byref(c), ctypes.byref(e), ctypes.byref(k), ctypes.byref(u))
    return (((k.hi << 32) | k.lo) + ((u.hi << 32) | u.lo)) / 1e7


def partie(projet: Path, i: int, a) -> dict:
    seed = a.seed + i
    args = [str(GODOT), "--headless", "--fixed-fps", "60", "--path", str(projet), "res://scenes/world.tscn", "--", "--moba",
            "--moba-heroes=watch", f"--moba-diff={a.diff}", f"--moba-seed={seed}", f"--moba-speed={a.speed}",
            f"--moba-until={a.until}", "--auto-quit"] + (["--moba-perf"] if a.perf else []) + a.extra
    env = dict(os.environ)
    user = Path(tempfile.gettempdir()) / "moba_ai_games" / f"u{i}"
    user.mkdir(parents=True, exist_ok=True)
    env["APPDATA"] = str(user)
    t0 = time.time()
    proc = subprocess.Popen(args, env=env, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    if os.name == "nt":
        from ctypes import wintypes
        ctypes.windll.kernel32.SetPriorityClass(wintypes.HANDLE(int(proc._handle)), 0x8000)  # un cran au-dessus (R_MB0 § 3.4)
    r = {"seed": seed, "diff": a.diff}
    c0 = None
    erreurs = []
    for brut in proc.stdout:
        l = brut.decode("utf-8", "replace").rstrip()
        if l.startswith("[moba] mesure début"):
            c0 = cpu_process(proc._handle)
        elif l.startswith("[moba] mesure fin images="):
            if c0 is not None:
                n = max(1, int(l.split("=")[1]))
                r["cpu_ms_image"] = round(1000.0 * (cpu_process(proc._handle) - c0) / n, 3)
                r["images"] = n
        elif l.startswith("[moba] logique : "):
            r["logique"] = json.loads(l.split(" : ", 1)[1])
        elif l.startswith("[moba] héros µs : "):
            r["heros_us"] = json.loads(l.split(" : ", 1)[1])
        elif l.startswith("[moba] bilan "):
            r["bilan"] = json.loads(l[len("[moba] bilan "):])
        elif "SCRIPT ERROR" in l:
            erreurs.append(l[:200])
    proc.wait()
    r["mur_s"] = round(time.time() - t0, 1)
    r["code"] = proc.returncode
    if erreurs:
        r["erreurs"] = erreurs[:5]
    return r


def resume(rs: list) -> str:
    out = []
    morts = tour = sans = 0
    jungle = []
    for r in rs:
        b = r.get("bilan")
        if not b:
            continue
        for h in b["heroes"]:
            for d in h["deaths"]:
                morts += 1
                tour += 1 if d.get("under_tower") else 0
                sans += 1 if not d.get("hero_hit") else 0
            if h["role"] == 1:
                jungle.append(len([t for t in h.get("camp_times", []) if t < 240.0]))
    n = len([r for r in rs if r.get("bilan")])
    out.append(f"{n} parties, {morts} morts : {tour} sous une tour adverse, {sans} sans héros adverse dans les 10 s")
    if jungle:
        out.append(f"jungle : camps avant 4:00 par jungler : min {min(jungle)}, médiane {statistics.median(jungle)}, max {max(jungle)}")
    cpu = [r["cpu_ms_image"] for r in rs if "cpu_ms_image" in r]
    if cpu:
        out.append(f"CPU par image physique : médiane {statistics.median(cpu):.2f} ms (min {min(cpu):.2f}, max {max(cpu):.2f})")
    lg = [r["logique"]["p95"] for r in rs if r.get("logique", {}).get("n")]
    if lg:
        out.append(f"scripts de l'image p95 : médiane {statistics.median(lg):.2f} ms (borne haute, machine chargée)")
    hu = [x for r in rs for x in r.get("heros_us", [])]
    if hu:
        tot = [float(x[0]) for x in hu]
        ia = [float(x[1]) for x in hu]
        out.append(f"héros IA, temps mur par image : MobaRival entier {statistics.mean(tot):.1f} µs (max {max(tot):.1f}), "
                   f"dont couche de poste {statistics.mean(ia):.1f} µs (max {max(ia):.1f})")
    return "\n".join(out)


def main() -> int:
    for f in (sys.stdout, sys.stderr):
        try:
            f.reconfigure(encoding="utf-8", errors="replace")
        except Exception:
            pass
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--projet", help="copie importée du projet (dossier game)")
    ap.add_argument("-n", type=int, default=4)
    ap.add_argument("-j", type=int, default=2)
    ap.add_argument("--diff", type=int, default=3)
    ap.add_argument("--seed", type=int, default=100)
    ap.add_argument("--speed", type=float, default=4.0)
    ap.add_argument("--until", type=float, default=1500.0)
    ap.add_argument("--perf", action="store_true")
    ap.add_argument("--out", default=str(ROOT / "conception" / "benchmark" / "mb_e" / "parties.jsonl"))
    ap.add_argument("--tableau", help="résumé d'un journal existant")
    ap.add_argument("extra", nargs="*", help="options en plus pour le jeu (après --)")
    a = ap.parse_args()
    if a.tableau:
        rs = [json.loads(l) for l in Path(a.tableau).read_text(encoding="utf-8").splitlines() if l.strip()]
        print(resume(rs))
        return 0
    projet = Path(a.projet) if a.projet else ROOT / "game"
    out = Path(a.out)
    out.parent.mkdir(parents=True, exist_ok=True)
    rs = []
    with cf.ThreadPoolExecutor(max_workers=a.j) as ex:
        for r in ex.map(lambda i: partie(projet, i, a), range(a.n)):
            rs.append(r)
            with out.open("a", encoding="utf-8") as f:
                f.write(json.dumps(r, ensure_ascii=False) + "\n")
            b = r.get("bilan", {})
            print(f"graine {r['seed']} : {b.get('what', '?')} à {b.get('t', 0)} s, vainqueur {b.get('winner')}, "
                  f"{r.get('cpu_ms_image', '-')} ms CPU/image, {r['mur_s']} s" + (f" ERREURS {r['erreurs']}" if r.get("erreurs") else ""))
    print(resume(rs))
    return 0


if __name__ == "__main__":
    sys.exit(main())
