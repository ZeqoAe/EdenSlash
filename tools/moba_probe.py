#!/usr/bin/env python3
"""MB-0 : série de mesures du banc des « Deux Voies » (game/tools/moba_probe.tscn, rapport conception/benchmark/R_MB0.md).

    python tools/moba_probe.py                    # tous les réglages, 3 essais chacun
    python tools/moba_probe.py -r 3 base opt      # seulement les réglages dont le nom contient « base » ou « opt »
    python tools/moba_probe.py --reuse            # garde la copie du projet déjà prête (sinon : copie de HEAD + banc, --import)
    python tools/moba_probe.py --list             # liste des réglages
    python tools/moba_probe.py --tableau          # refait le tableau à partir de tout le journal

Chaque essai tourne sur une copie propre du projet (HEAD + les fichiers du banc, comme tools/run_tests.py : le dossier de
travail partagé peut contenir le travail en cours d'autres sessions) avec un dossier utilisateur à part (APPDATA détourné).
Le banc est lancé par l'exécutable Godot sans console pour lire le temps CPU du processus lui-même (GetProcessTimes), à côté
du temps mur ; la charge de la machine est notée : processus Godot ouverts au début et à la fin, occupation du processeur
pendant l'essai (GetSystemTimes). Résultats : une ligne JSON par essai dans conception/benchmark/mb0/mesures.jsonl et un
tableau (médiane des essais) dans conception/benchmark/mb0/tableau.md.
"""
import argparse
import ctypes
import json
import os
import shutil
import statistics
import subprocess
import sys
import tempfile
import threading
import time
from ctypes import wintypes
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "tools"))
import run_tests  # noqa: E402  (preparer_copie, importer, env_pour)

GODOT_GUI = Path.home() / "Godot" / "Godot_v4.7.2-stable_win64.exe"
SNAP = Path(tempfile.gettempdir()) / "mb0_snap"
OUT = ROOT / "conception" / "benchmark" / "mb0"
BANC = ["tools/moba_probe.tscn", "tools/moba_probe.gd", "tools/moba_probe_minion.gd", "tools/moba_probe_hero.gd",
        "tools/moba_probe_tower.gd", "tools/moba_probe_bolt.gd"]
FEN = ["--fixed-fps", "60", "--disable-vsync", "--resolution", "1600x900", "--position", "40,40"]

# nom -> (sans rendu ?, options du banc)
REGLAGES = {
    # logique seule (sans rendu)
    "h_base": (True, ["--preset=base"]),
    "h_opt": (True, ["--preset=opt"]),
    "h_base_nav_flow": (True, ["--preset=base", "--nav=flow"]),
    "h_base_nav_agent": (True, ["--preset=base", "--nav=agent"]),
    "h_base_grid": (True, ["--preset=base", "--target=grid"]),
    "h_base_lite": (True, ["--preset=base", "--lite=1", "--lod=1"]),
    "h_base_pool": (True, ["--preset=base", "--pool=1"]),
    "h_base_light": (True, ["--preset=base", "--light=1", "--bolts=pool"]),
    "h_base_nofx": (True, ["--preset=base", "--fx=0", "--numbers=0"]),
    "h_opt_m24": (True, ["--preset=opt", "--minions=24"]),
    "h_opt_m96": (True, ["--preset=opt", "--minions=96"]),
    "h_base_m96": (True, ["--preset=base", "--minions=96"]),
    "h_opt_m120": (True, ["--preset=opt", "--minions=120", "--wave_max=15"]),
    "h_base_m120": (True, ["--preset=base", "--minions=120", "--wave_max=15"]),
    "h_opt_nohero": (True, ["--preset=opt", "--heroes=0"]),
    "h_opt_heroonly": (True, ["--preset=opt", "--minions=0", "--towers=0", "--camps=0"]),
    # témoins de la charge : priorité normale (comme les autres agents) au lieu d'un cran au-dessus
    "h_base_prio_normal": (True, ["--preset=base"], "normal"),
    "h_opt_prio_normal": (True, ["--preset=opt"], "normal"),
    # rendu réel 1600 × 900
    "w_base_high": (False, ["--preset=base", "--quality=high"]),
    "w_opt_high": (False, ["--preset=opt", "--quality=high"]),
    "w_opt_low": (False, ["--preset=opt", "--quality=low", "--shadows=0", "--msaa=0", "--scale3d=0.75"]),
    "w_opt_m96_high": (False, ["--preset=opt", "--quality=high", "--minions=96"]),
    "w_opt_wide_high": (False, ["--preset=opt", "--quality=high", "--cam=wide"]),
    # témoin : la même fenêtre sans aucune unité (plancher de l'image fenêtrée sur cette machine)
    "w_empty_high": (False, ["--preset=opt", "--quality=high", "--heroes=0", "--minions=0", "--towers=0", "--camps=0"]),
    "w_decor_empty_high": (False, ["--preset=opt", "--quality=high", "--heroes=0", "--minions=0", "--towers=0", "--camps=0",
                                   "--decor=limestone"]),
    # rendu avec le décor d'une vraie carte (ProcMap) sous le terrain du banc
    "w_decor_opt_high": (False, ["--preset=opt", "--quality=high", "--decor=limestone"]),
    "w_decor_opt_medium": (False, ["--preset=opt", "--quality=medium", "--decor=limestone"]),
    "w_decor_opt_low": (False, ["--preset=opt", "--quality=low", "--shadows=0", "--msaa=0", "--scale3d=0.75", "--decor=limestone"]),
    "w_decor_base_high": (False, ["--preset=base", "--quality=high", "--decor=limestone"]),
}


class FILETIME(ctypes.Structure):
    _fields_ = [("lo", wintypes.DWORD), ("hi", wintypes.DWORD)]


def _ft(f: FILETIME) -> float:
    return ((f.hi << 32) | f.lo) / 1e7


def cpu_process(handle) -> float:
    """Temps CPU (utilisateur + noyau, s) du processus."""
    c, e, k, u = FILETIME(), FILETIME(), FILETIME(), FILETIME()
    ctypes.windll.kernel32.GetProcessTimes(wintypes.HANDLE(int(handle)), ctypes.byref(c), ctypes.byref(e), ctypes.byref(k), ctypes.byref(u))
    return _ft(k) + _ft(u)


def cpu_system() -> tuple:
    i, k, u = FILETIME(), FILETIME(), FILETIME()
    ctypes.windll.kernel32.GetSystemTimes(ctypes.byref(i), ctypes.byref(k), ctypes.byref(u))
    return _ft(i), _ft(k) + _ft(u)  # (le temps noyau comprend l'inactivité)


class PROCESSENTRY32W(ctypes.Structure):
    _fields_ = [("dwSize", wintypes.DWORD), ("cntUsage", wintypes.DWORD), ("th32ProcessID", wintypes.DWORD),
                ("th32DefaultHeapID", ctypes.c_size_t), ("th32ModuleID", wintypes.DWORD), ("cntThreads", wintypes.DWORD),
                ("th32ParentProcessID", wintypes.DWORD), ("pcPriClassBase", ctypes.c_long), ("dwFlags", wintypes.DWORD),
                ("szExeFile", ctypes.c_wchar * 260)]


def godot_count() -> int:
    """Processus Godot ouverts (instantané Toolhelp : tasklist met des minutes sur une machine saturée)."""
    k32 = ctypes.windll.kernel32
    k32.CreateToolhelp32Snapshot.restype = wintypes.HANDLE
    snap = k32.CreateToolhelp32Snapshot(0x2, 0)
    e = PROCESSENTRY32W()
    e.dwSize = ctypes.sizeof(PROCESSENTRY32W)
    n = 0
    ok = k32.Process32FirstW(snap, ctypes.byref(e))
    while ok:
        if e.szExeFile.lower().startswith("godot") and "console" not in e.szExeFile.lower():
            n += 1
        ok = k32.Process32NextW(snap, ctypes.byref(e))
    k32.CloseHandle(snap)
    return n


def preparer(reuse: bool) -> Path:
    projet = SNAP / "game"
    if not (reuse and (projet / "project.godot").exists()):
        projet = run_tests.preparer_copie(SNAP)
    for f in BANC:
        shutil.copy2(ROOT / "game" / f, projet / f)
    if not (reuse and (projet / ".godot" / "global_script_class_cache.cfg").exists()):
        run_tests.importer(run_tests.trouver_godot(None), projet, SNAP / "user")
    return projet


PRIO = {"normal": 0x20, "above": 0x8000, "high": 0x80}


def essai(projet: Path, nom: str, headless: bool, opts: list, i: int, extra: list, prio: str = "above") -> dict:
    res_file = SNAP / f"mb0_{nom}_{i}.json"
    if res_file.exists():
        res_file.unlink()
    args = [str(GODOT_GUI)]
    args += ["--headless", "--fixed-fps", "60"] if headless else FEN
    shot = OUT / f"{nom}.jpg"
    args += ["--path", str(projet), "res://tools/moba_probe.tscn", "--", *opts, *extra, f"--out={res_file}", f"--seed={i + 1}"]
    if not headless and i == 0:
        args.append(f"--shot={shot}")
    env = run_tests.env_pour(SNAP / "user" / f"{nom}_{i}")
    g0 = godot_count()
    s0 = cpu_system()
    t0 = time.time()
    proc = subprocess.Popen(args, env=env, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    # priorité un cran au-dessus des autres agents (machine saturée) : moins de préemptions dans les temps mesurés
    ctypes.windll.kernel32.SetPriorityClass(wintypes.HANDLE(int(proc._handle)), PRIO.get(prio, 0x20))
    minuteur = threading.Timer(900, lambda: subprocess.run(["taskkill", "/F", "/T", "/PID", str(proc.pid)], capture_output=True))
    minuteur.start()  # (son propre processus seulement)
    marques = {}
    texte = []
    for brut in proc.stdout:
        ligne = brut.decode("utf-8", "replace").rstrip()
        texte.append(ligne)
        if ligne.startswith("[mb0] mesure"):
            marques["debut"] = (cpu_process(proc._handle), time.time())
        elif ligne.startswith("[mb0] image"):
            marques["fin"] = (cpu_process(proc._handle), time.time())
    proc.wait()
    minuteur.cancel()
    sortie = "\n".join(texte).encode("utf-8")
    mur = time.time() - t0
    cpu = cpu_process(proc._handle)
    s1 = cpu_system()
    g1 = godot_count()
    idle = s1[0] - s0[0]
    tot = s1[1] - s0[1]
    occ = 100.0 * (1.0 - idle / tot) if tot > 0 else -1.0
    r = {"nom": nom, "essai": i, "prio": prio, "mur_s": round(mur, 1), "cpu_s": round(cpu, 2), "godot_debut": g0, "godot_fin": g1,
         "cpu_machine_pct": round(occ, 1), "code": proc.returncode}
    if res_file.exists():
        d = json.loads(res_file.read_text(encoding="utf-8"))
        r["res"] = d
        frames = max(1, int(d.get("frames", 1)))
        if "debut" in marques and "fin" in marques:
            # temps CPU du processus (tous ses fils) pendant la mesure seule, par image ; et part d'un cœur occupée
            dcpu = marques["fin"][0] - marques["debut"][0]
            dmur = marques["fin"][1] - marques["debut"][1]
            r["cpu_ms_image"] = round(1000.0 * dcpu / frames, 2)
            r["mur_ms_image"] = round(1000.0 * dmur / frames, 2)
            r["coeurs"] = round(dcpu / max(dmur, 0.001), 2)
        else:
            r["cpu_ms_image"] = round(1000.0 * cpu / max(1.0, d.get("sim_s", 1.0) * 60.0), 2)  # (repli : tout l'essai)
    else:
        r["erreur"] = sortie.decode("utf-8", "replace")[-1500:]
    lignes = [ligne for ligne in sortie.decode("utf-8", "replace").splitlines() if ligne.startswith("[mb0]") or "SCRIPT ERROR" in ligne]
    r["lignes"] = lignes[-12:]
    return r


def resume(r: dict) -> str:
    if "res" not in r:
        return f"{r['nom']} #{r['essai']} : ÉCHEC ({r.get('erreur', '')[-200:]})"
    d = r["res"]
    f = d["frame_ms"]
    g = d.get("gpu_ms", {})
    return (f"{r['nom']} #{r['essai']} : image p50 {f['p50']:.2f} moy {f['mean']:.2f} p95 {f['p95']:.2f} max {f['max']:.2f} ms"
            + (f" · GPU p95 {g.get('p95', 0):.2f}" if g else "")
            + f" · CPU {r['cpu_ms_image']:.2f} ms/image ({r.get('coeurs', 0):.2f} cœur) · Godot {r['godot_debut']}→{r['godot_fin']} · machine {r['cpu_machine_pct']:.0f} %")


def tableau(lignes: list) -> str:
    par = {}
    for r in lignes:
        if "res" in r:
            par.setdefault(r["nom"], []).append(r)
    med = statistics.median
    out = ["| Réglage | essais | image p50 | moy | p95 | p99 | max | passe physique p50 / p95 | GPU moy / p95 | CPU ms/image | cœurs | sbires | nœuds | Godot ouverts | machine |",
           "|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|"]
    for nom in REGLAGES:
        rs = par.get(nom)
        if not rs:
            continue
        def m(f):
            return med([f(r) for r in rs])
        gpu = "—"
        if "gpu_ms" in rs[0]["res"]:
            gpu = f"{m(lambda r: r['res']['gpu_ms']['mean']):.2f} / {m(lambda r: r['res']['gpu_ms']['p95']):.2f}"
        out.append(f"| {nom} | {len(rs)} | {m(lambda r: r['res']['frame_ms']['p50']):.2f} | {m(lambda r: r['res']['frame_ms']['mean']):.2f} | "
                   f"{m(lambda r: r['res']['frame_ms']['p95']):.2f} | "
                   f"{m(lambda r: r['res']['frame_ms']['p99']):.2f} | {m(lambda r: r['res']['frame_ms']['max']):.1f} | "
                   f"{m(lambda r: r['res']['nodes_phys_ms']['p50']):.2f} / {m(lambda r: r['res']['nodes_phys_ms']['p95']):.2f} | {gpu} | "
                   f"{m(lambda r: r['cpu_ms_image']):.2f} | {m(lambda r: r.get('coeurs', 0)):.2f} | "
                   f"{m(lambda r: r['res']['samples']['minions']['mean']):.0f} | {m(lambda r: r['res']['samples']['nodes']['max']):.0f} | "
                   f"{min(r['godot_debut'] for r in rs)}-{max(r['godot_fin'] for r in rs)} | {m(lambda r: r['cpu_machine_pct']):.0f} % |")
    return "\n".join(out)


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("mots", nargs="*")
    ap.add_argument("-r", type=int, default=3, help="essais par réglage")
    ap.add_argument("--reuse", action="store_true")
    ap.add_argument("--list", action="store_true")
    ap.add_argument("--tableau", action="store_true", help="refait le tableau à partir de tout mesures.jsonl")
    ap.add_argument("--prio", default="above", choices=list(PRIO), help="priorité du processus Godot mesuré")
    ap.add_argument("--extra", default="", help="options ajoutées à chaque essai (séparées par des espaces)")
    a = ap.parse_args()
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    if a.list:
        for k, v in REGLAGES.items():
            print(k, "sans rendu" if v[0] else "rendu", " ".join(v[1]))
        return
    if a.tableau:
        tous = [json.loads(ligne) for ligne in (OUT / "mesures.jsonl").read_text(encoding="utf-8").splitlines() if ligne.strip()]
        tab = tableau(tous)
        print(tab)
        (OUT / "tableau.md").write_text(tab + "\n", encoding="utf-8")
        return
    OUT.mkdir(parents=True, exist_ok=True)
    projet = preparer(a.reuse)
    # un nom exact ne prend que ce réglage ; sinon, tous ceux qui contiennent le mot
    noms = [n for n in REGLAGES if not a.mots or n in a.mots or any(w not in REGLAGES and w in n for w in a.mots)]
    lignes = []
    journal = OUT / "mesures.jsonl"
    for i in range(a.r):  # (essais entrelacés : une dérive de la charge touche tous les réglages)
        for nom in noms:
            headless, opts = REGLAGES[nom][0], REGLAGES[nom][1]
            prio = REGLAGES[nom][2] if len(REGLAGES[nom]) > 2 else a.prio
            r = essai(projet, nom, headless, opts, i, a.extra.split(), prio)
            print(resume(r), flush=True)
            lignes.append(r)
            with journal.open("a", encoding="utf-8") as fj:
                fj.write(json.dumps({k: v for k, v in r.items() if k != "lignes"}, ensure_ascii=False) + "\n")
    tab = tableau(lignes)
    print(tab)
    (OUT / "tableau.md").write_text(tab + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
