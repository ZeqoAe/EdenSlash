#!/usr/bin/env python3
"""PERF-1 : temps de chargement et à-coups du jeu EN FENÊTRE, mesurés plusieurs fois, avec le temps CPU du processus.

    python tools/perf_loads.py                       # copie propre de HEAD, 3 passages, toutes les activités
    python tools/perf_loads.py --runs 3 --label avant --snap <dossier> --overlay game/scripts/ui/x.gd ...
    python tools/perf_loads.py --acts survival,tower --no-pages --runs 1

Lance `res://tools/load_probe.tscn` (pilote de test_p4_activities + moniteur d'images) dans une vraie fenêtre : le rendu, la
compilation des shaders (pipelines) et les chargements de textures comptent. Pendant le passage, un fil relève toutes les 25 ms
le temps CPU du processus Godot (tous fils) et celui de son fil principal (Windows : GetProcessTimes / GetThreadTimes) ; chaque
« [perf1] mark » imprimé par la sonde est daté et associé à ces compteurs. Sur une machine chargée (d'autres Godot tournent),
le temps CPU du fil principal est la mesure la plus stable : il ne compte pas l'attente du processeur.
Le 1er passage part d'un cache de shaders vide (premier lancement du jeu), les suivants le réutilisent (même dossier utilisateur) ;
`--cold` donne un dossier neuf à chaque passage.
Rapport : <snap>/perf_<label>.json et un tableau Markdown sur la sortie.
"""
import argparse
import ctypes
import json
import os
import shutil
import statistics
import subprocess
import sys
import threading
import time
from ctypes import wintypes
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import run_tests  # noqa: E402  (copie propre de HEAD, import, Godot)

ROOT = Path(__file__).resolve().parent.parent
PROBE_FILES = ["game/tools/load_probe.gd", "game/tools/load_probe.tscn"]


# --- compteurs Windows ---------------------------------------------------------------------------------------------
class FILETIME(ctypes.Structure):
    _fields_ = [("lo", wintypes.DWORD), ("hi", wintypes.DWORD)]


class THREADENTRY32(ctypes.Structure):
    _fields_ = [("dwSize", wintypes.DWORD), ("cntUsage", wintypes.DWORD), ("th32ThreadID", wintypes.DWORD),
                ("th32OwnerProcessID", wintypes.DWORD), ("tpBasePri", wintypes.LONG), ("tpDeltaPri", wintypes.LONG),
                ("dwFlags", wintypes.DWORD)]


k32 = ctypes.WinDLL("kernel32", use_last_error=True) if os.name == "nt" else None
if k32:
    for _f in ("CreateToolhelp32Snapshot", "OpenThread", "OpenProcess"):
        getattr(k32, _f).restype = wintypes.HANDLE
    for _f in ("CloseHandle", "GetThreadTimes", "GetProcessTimes", "Thread32First", "Thread32Next", "Process32FirstW", "Process32NextW"):
        getattr(k32, _f).argtypes = None
    k32.CloseHandle.argtypes = [wintypes.HANDLE]
    k32.GetThreadTimes.argtypes = [wintypes.HANDLE] + [ctypes.c_void_p] * 4
    k32.GetProcessTimes.argtypes = [wintypes.HANDLE] + [ctypes.c_void_p] * 4
    k32.Thread32First.argtypes = k32.Thread32Next.argtypes = [wintypes.HANDLE, ctypes.c_void_p]
    k32.Process32FirstW.argtypes = k32.Process32NextW.argtypes = [wintypes.HANDLE, ctypes.c_void_p]


def _ft(f: FILETIME) -> int:
    return (f.hi << 32) | f.lo  # unités de 100 ns


def proc_cpu_ms(h) -> float:
    c, e, k, u = FILETIME(), FILETIME(), FILETIME(), FILETIME()
    if not k32.GetProcessTimes(h, ctypes.byref(c), ctypes.byref(e), ctypes.byref(k), ctypes.byref(u)):
        return -1.0
    return (_ft(k) + _ft(u)) / 1e4


def thread_times(tid: int):
    h = k32.OpenThread(0x0800, False, tid)  # THREAD_QUERY_LIMITED_INFORMATION
    if not h:
        return None
    c, e, k, u = FILETIME(), FILETIME(), FILETIME(), FILETIME()
    ok = k32.GetThreadTimes(h, ctypes.byref(c), ctypes.byref(e), ctypes.byref(k), ctypes.byref(u))
    k32.CloseHandle(h)
    return (_ft(c), (_ft(k) + _ft(u)) / 1e4) if ok else None


class PROCESSENTRY32W(ctypes.Structure):
    _fields_ = [("dwSize", wintypes.DWORD), ("cntUsage", wintypes.DWORD), ("th32ProcessID", wintypes.DWORD),
                ("th32DefaultHeapID", ctypes.c_size_t), ("th32ModuleID", wintypes.DWORD), ("cntThreads", wintypes.DWORD),
                ("th32ParentProcessID", wintypes.DWORD), ("pcPriClassBase", wintypes.LONG), ("dwFlags", wintypes.DWORD),
                ("szExeFile", ctypes.c_wchar * 260)]


def child_godot(pid: int) -> int:
    """Godot_…_console.exe n'est qu'une enveloppe : le jeu tourne dans un processus enfant (Godot_….exe)."""
    snap = k32.CreateToolhelp32Snapshot(0x2, 0)  # TH32CS_SNAPPROCESS
    pe = PROCESSENTRY32W()
    pe.dwSize = ctypes.sizeof(PROCESSENTRY32W)
    found = 0
    ok = k32.Process32FirstW(snap, ctypes.byref(pe))
    while ok:
        if pe.th32ParentProcessID == pid and pe.szExeFile.lower().startswith("godot"):
            found = pe.th32ProcessID
        ok = k32.Process32NextW(snap, ctypes.byref(pe))
    k32.CloseHandle(snap)
    return found


def main_thread(pid: int) -> int:
    """Le fil principal = le plus ancien fil du processus."""
    snap = k32.CreateToolhelp32Snapshot(0x4, 0)  # TH32CS_SNAPTHREAD
    te = THREADENTRY32()
    te.dwSize = ctypes.sizeof(THREADENTRY32)
    best, best_t = 0, None
    ok = k32.Thread32First(snap, ctypes.byref(te))
    while ok:
        if te.th32OwnerProcessID == pid:
            tt = thread_times(te.th32ThreadID)
            if tt and (best_t is None or tt[0] < best_t):
                best, best_t = te.th32ThreadID, tt[0]
        ok = k32.Thread32Next(snap, ctypes.byref(te))
    k32.CloseHandle(snap)
    return best


def system_busy():
    i, k, u = FILETIME(), FILETIME(), FILETIME()
    k32.GetSystemTimes(ctypes.byref(i), ctypes.byref(k), ctypes.byref(u))
    return _ft(i), _ft(k) + _ft(u)


def count_godot() -> int:
    out = subprocess.run(["tasklist", "/FO", "CSV", "/NH"], capture_output=True).stdout.decode("cp850", "replace")
    return sum(1 for line in out.splitlines() if line.lower().startswith('"godot'))


# --- un passage ----------------------------------------------------------------------------------------------------
def one_run(godot: Path, projet: Path, userdir: Path, probe_args: str, out_json: Path, log_path: Path, timeout: float) -> dict:
    env = run_tests.env_pour(userdir)
    env["LOAD_PROBE"] = probe_args + f" --out={out_json.as_posix()}"
    n_godot = count_godot()
    s_idle0, s_busy0 = system_busy()
    t_start = time.perf_counter()
    proc = subprocess.Popen([str(godot), "--path", str(projet), "res://tools/load_probe.tscn"], env=env,
                            stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    state = {"tid": 0, "pid": 0, "h": None}
    for _ in range(100):  # le vrai processus du jeu (enfant de l'enveloppe console), sinon l'enveloppe elle-même
        time.sleep(0.05)
        state["pid"] = child_godot(proc.pid)
        if state["pid"]:
            break
    gpid = state["pid"] or proc.pid
    hproc = k32.OpenProcess(0x1000, False, gpid)  # PROCESS_QUERY_LIMITED_INFORMATION
    marks = []  # (nom, t_wall, cpu_proc, cpu_main)
    lock = threading.Lock()

    def sample():
        tid = state["tid"]
        tt = thread_times(tid) if tid else None
        return time.perf_counter() - t_start, proc_cpu_ms(hproc), (tt[1] if tt else -1.0)

    def reader():
        with open(log_path, "wb") as lf:
            for raw in proc.stdout:
                lf.write(raw)
                line = raw.decode("utf-8", "replace").strip()
                if line.startswith("[perf1] mark "):
                    if not state["tid"]:
                        state["tid"] = main_thread(gpid)
                    name = line[len("[perf1] mark "):].rsplit(" ", 1)[0]
                    with lock:
                        marks.append((name,) + sample())

    th = threading.Thread(target=reader, daemon=True)
    th.start()
    peak_busy = []
    last = system_busy()
    while proc.poll() is None:
        time.sleep(1.0)
        cur = system_busy()
        d_idle, d_tot = cur[0] - last[0], cur[1] - last[1]
        if d_tot > 0:
            peak_busy.append(100.0 * (1.0 - d_idle / d_tot))
        last = cur
        if time.perf_counter() - t_start > timeout:
            run_tests.tuer(proc)
            break
    th.join(timeout=10)
    s_idle1, s_busy1 = system_busy()
    load = 100.0 * (1.0 - (s_idle1 - s_idle0) / max(1, s_busy1 - s_busy0))
    k32.CloseHandle(hproc)
    data = json.loads(out_json.read_text(encoding="utf-8")) if out_json.exists() else {"phases": [], "hitches": []}
    data["load"] = {"godot_at_start": n_godot, "cpu_busy_avg": round(load, 1),
                    "cpu_busy_max": round(max(peak_busy), 1) if peak_busy else None, "wall_s": round(time.perf_counter() - t_start, 1)}
    # temps CPU entre la marque d'une phase et la suivante ; « :pret » donne le CPU jusqu'à l'écran prêt
    # appariement dans l'ordre : les marques non « :pret » suivent l'ordre des phases
    plain = [m for m in marks if not m[0].endswith(":pret")]
    pret = [m for m in marks if m[0].endswith(":pret")]
    for k, p in enumerate(data["phases"]):
        if k < len(plain) and k + 1 < len(plain):
            a, b = plain[k], plain[k + 1]
            p["cpu_main_ms"] = round(b[3] - a[3], 1) if a[3] >= 0 and b[3] >= 0 else None
            p["cpu_proc_ms"] = round(b[2] - a[2], 1)
            p["wall_py_ms"] = round((b[1] - a[1]) * 1000.0, 1)
            ready = next((m for m in pret if a[1] <= m[1] <= b[1]), None)
            if ready and a[3] >= 0:
                p["cpu_main_ready_ms"] = round(ready[3] - a[3], 1)
    return data


# --- agrégat -------------------------------------------------------------------------------------------------------
def med(vals):
    vals = [v for v in vals if v is not None and v >= 0]
    return round(statistics.median(vals), 1) if vals else None


def aggregate(runs: list) -> list:
    names = []
    for r in runs:
        for p in r["phases"]:
            if p["name"] not in names:
                names.append(p["name"])
    rows = []
    for n in names:
        ps = [p for r in runs for p in r["phases"] if p["name"] == n]
        rows.append({"name": n, "runs": len(ps), "ms": med([p["ms"] for p in ps]), "ready_ms": med([p.get("ready_ms") for p in ps]),
                     "max": med([p["max"] for p in ps]), "max_worst": max(p["max"] for p in ps), "frozen": med([p["frozen"] for p in ps]),
                     "n100": med([p["n100"] for p in ps]), "n300": med([p["n300"] for p in ps]), "pipes": med([p["pipes"] for p in ps]),
                     "draw_pipes": med([p["draw_pipes"] for p in ps]), "cpu_main_ms": med([p.get("cpu_main_ms") for p in ps]),
                     "cpu_main_ready_ms": med([p.get("cpu_main_ready_ms") for p in ps]), "pipes_run1": ps[0]["pipes"] if ps else None})
    return rows


def table(rows: list) -> str:
    out = ["| Phase | Durée (ms) | Prêt (ms) | Image max (méd. / pire) | Figé > 50 ms | Images > 300 ms | CPU fil principal (ms) | Pipelines (1er / méd.) |",
           "|---|---|---|---|---|---|---|---|"]
    for r in rows:
        out.append(f"| {r['name']} | {r['ms']} | {r['ready_ms'] if r['ready_ms'] and r['ready_ms'] > 0 else '-'} | {r['max']} / {r['max_worst']} | "
                   f"{r['frozen']} | {r['n300']} | {r['cpu_main_ready_ms'] or r['cpu_main_ms']} | {r['pipes_run1']} / {r['pipes']} |")
    return "\n".join(out)


def main() -> int:
    for flux in (sys.stdout, sys.stderr):
        try:
            flux.reconfigure(encoding="utf-8", errors="replace")
        except Exception:
            pass
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--runs", type=int, default=3)
    ap.add_argument("--label", default="mesure")
    ap.add_argument("--snap", help="dossier de la copie (défaut : <temp>/eden_perf1)")
    ap.add_argument("--reuse", action="store_true", help="réutiliser la copie telle quelle")
    ap.add_argument("--live", action="store_true", help="mesurer le dossier de travail (modifications des autres sessions comprises)")
    ap.add_argument("--overlay", nargs="*", default=[], help="fichiers du dossier de travail recopiés dans la copie (chemins depuis la racine)")
    ap.add_argument("--acts", default="", help="activités (liste ; défaut : toutes celles de la sonde)")
    ap.add_argument("--no-pages", action="store_true")
    ap.add_argument("--play", type=float, default=7.0)
    ap.add_argument("--cold", action="store_true", help="dossier utilisateur neuf (cache de shaders vide) à chaque passage")
    ap.add_argument("--shots", help="dossier : une capture de chaque écran de chargement")
    ap.add_argument("--ud", help="nom du dossier utilisateur dans la copie (défaut : ud_<label>)")
    ap.add_argument("--warm", action="store_true", help="garder le dossier utilisateur (cache de shaders) du passage précédent")
    ap.add_argument("--godot", help="chemin de Godot")
    ap.add_argument("--timeout", type=float, default=1800.0)
    a = ap.parse_args()
    godot = run_tests.trouver_godot(a.godot)
    import tempfile
    snap = Path(a.snap) if a.snap else Path(tempfile.gettempdir()) / "eden_perf1"
    if a.live:
        projet = ROOT / "game"
    else:
        projet = snap / "game" if a.reuse and (snap / "game").exists() else run_tests.preparer_copie(snap)
        for f in PROBE_FILES + a.overlay:
            src, dst = ROOT / f, snap / f
            if src.exists():
                dst.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(src, dst)
            elif dst.exists():
                dst.unlink()
        run_tests.importer(godot, projet, snap)
    probe_args = []
    if a.acts:
        probe_args.append("--acts=" + a.acts)
    if a.no_pages:
        probe_args.append("--no-pages")
    probe_args.append(f"--play={a.play}")
    if a.shots:
        Path(a.shots).mkdir(parents=True, exist_ok=True)
        probe_args.append("--shots=" + Path(a.shots).resolve().as_posix())
    runs = []
    for i in range(a.runs):
        ud = snap / (f"ud_{a.label}_{i}" if a.cold else (a.ud or f"ud_{a.label}"))
        if i == 0 and ud.exists() and not a.warm:
            shutil.rmtree(ud, ignore_errors=True)  # 1er passage : cache de shaders vide
        out_json = snap / f"probe_{a.label}_{i}.json"
        if out_json.exists():
            out_json.unlink()
        t0 = time.time()
        r = one_run(godot, projet, ud, " ".join(probe_args), out_json, snap / f"probe_{a.label}_{i}.log", a.timeout)
        r["run"] = i
        runs.append(r)
        print(f"passage {i + 1}/{a.runs} : {len(r['phases'])} phases, {len(r['hitches'])} à-coups, {time.time() - t0:.0f} s, charge {r['load']}",
              flush=True)
    rows = aggregate(runs)
    rapport = {"label": a.label, "runs": runs, "rows": rows}
    (snap / f"perf_{a.label}.json").write_text(json.dumps(rapport, ensure_ascii=False, indent=1), encoding="utf-8")
    print(table(rows))
    print(f"\nRapport : {snap / f'perf_{a.label}.json'}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
