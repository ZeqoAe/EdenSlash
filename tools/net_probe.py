"""NET-0 : lance l'essai réseau jetable (game/tools/net_probe.tscn) avec un hôte et N clients sur cette machine.

    python tools/net_probe.py                       # 1 hôte + 1 client, en fenêtres, clavier sur chacune
    python tools/net_probe.py --clients 3 --pilot   # 4 héros au pilote automatique
    python tools/net_probe.py --headless --pilot --secs 20 [--lag 120 --loss 5] [--snap 20] [--compress]
    python tools/net_probe.py ... --project <copie de game/>   # dossier de travail partagé en chantier : copie propre
    python tools/net_probe.py --clients 0 --headless --pilot --secs 20   # référence : l'hôte seul, sans réseau actif

Chaque processus a son propre dossier utilisateur (APPDATA détourné vers un dossier temporaire net0_*) : rien n'est
écrit dans le vrai profil ni mélangé entre les instances. Avec --secs, chaque instance écrit une ligne « [net] {json} »
de mesures (débit ENet réel, paquets, aller-retour, retard d'entrée, images par seconde, mémoire) ; le script ajoute le
temps processeur et la mémoire maximale de chaque processus (Windows) et résume.
"""
import argparse
import ctypes
import json
import os
import subprocess
import sys
import tempfile
import threading
import time

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
# exécutable principal (pas le lanceur « _console », qui n'est qu'un relais : son temps processeur ne compterait pas le jeu)
GODOT = os.path.join(os.path.expanduser("~"), "Godot", "Godot_v4.7.2-stable_win64.exe")


def launch(role_args, args, tag, tmp, secs):
    env = dict(os.environ)
    appdata = os.path.join(tmp, f"net0_{tag}")
    os.makedirs(appdata, exist_ok=True)
    env["APPDATA"] = appdata
    env.pop("EDEN_PROFILE", None)
    cmd = [GODOT]
    if args.headless:
        cmd.append("--headless")
    else:
        cmd += ["--resolution", "960x540"]
    cmd += ["--path", args.project or os.path.join(ROOT, "game"), "res://tools/net_probe.tscn", "--"] + role_args
    if args.pilot:
        cmd.append("--net-pilot")
    if secs:
        cmd.append(f"--net-secs={secs}")
    if args.snap:
        cmd.append(f"--net-snap={args.snap}")
    if args.compress:
        cmd.append("--net-compress")
    cmd.append(f"--net-port={args.port}")
    if args.shots:
        cmd.append(f"--net-shot={os.path.join(args.shots, 'net0_' + tag + '.png')}")
    p = subprocess.Popen(cmd, env=env, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True,
                         encoding="utf-8", errors="replace")
    p.lines = []
    p.t0 = time.time()
    t = threading.Thread(target=lambda: p.lines.extend(p.stdout), daemon=True)
    t.start()
    p.reader = t
    return p


class _Mem(ctypes.Structure):
    _fields_ = [("cb", ctypes.c_ulong), ("PageFaultCount", ctypes.c_ulong), ("PeakWorkingSetSize", ctypes.c_size_t),
                ("WorkingSetSize", ctypes.c_size_t), ("QuotaPeakPagedPoolUsage", ctypes.c_size_t),
                ("QuotaPagedPoolUsage", ctypes.c_size_t), ("QuotaPeakNonPagedPoolUsage", ctypes.c_size_t),
                ("QuotaNonPagedPoolUsage", ctypes.c_size_t), ("PagefileUsage", ctypes.c_size_t),
                ("PeakPagefileUsage", ctypes.c_size_t)]


def os_usage(p) -> dict:
    """Temps processeur total (s) et mémoire maximale (Mo) du processus terminé (Windows ; sinon vide)."""
    if os.name != "nt" or not hasattr(p, "_handle"):
        return {}
    h = ctypes.c_void_p(int(p._handle))
    c, e, k, u = (ctypes.c_ulonglong() for _ in range(4))
    if not ctypes.windll.kernel32.GetProcessTimes(h, ctypes.byref(c), ctypes.byref(e), ctypes.byref(k), ctypes.byref(u)):
        return {}
    m = _Mem()
    m.cb = ctypes.sizeof(m)
    ctypes.windll.psapi.GetProcessMemoryInfo(h, ctypes.byref(m), m.cb)
    cpu = (k.value + u.value) / 1e7
    wall = max(0.001, p.t1 - p.t0)
    return {"cpu_s": round(cpu, 1), "mur_s": round(wall, 1), "cpu_coeurs": round(cpu / wall, 2),
            "memoire_max_mo": round(m.PeakWorkingSetSize / 1048576)}


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--clients", type=int, default=1)
    ap.add_argument("--pilot", action="store_true")
    ap.add_argument("--headless", action="store_true")
    ap.add_argument("--secs", type=float, default=0.0, help="durée de mesure de chaque client (s)")
    ap.add_argument("--lag", type=int, default=0, help="aller-retour ajouté côté clients (ms)")
    ap.add_argument("--loss", type=float, default=0.0, help="paquets perdus côté clients (%%)")
    ap.add_argument("--snap", type=int, default=0)
    ap.add_argument("--compress", action="store_true")
    ap.add_argument("--port", type=int, default=24680)
    ap.add_argument("--project", help="dossier du projet Godot (défaut : game/ ; une copie propre de HEAD si d'autres sessions travaillent)")
    ap.add_argument("--json", help="ajoute les lignes [net] à ce fichier (une par instance)")
    ap.add_argument("--shots", help="dossier où chaque fenêtre écrit sa capture à 10 s (net0_<instance>.png)")
    ap.add_argument("--label", default="", help="étiquette de la mesure (dans le fichier --json)")
    args = ap.parse_args()
    tmp = tempfile.mkdtemp(prefix="net0_")
    delay = 4.0 if args.headless else 6.0
    # l'hôte vit plus longtemps que les clients (chargement des clients, départs échelonnés)
    host_secs = args.secs + delay + 1.5 * args.clients + 6.0 if args.secs and args.clients else args.secs
    procs = [("hôte", launch(["--net-host", "--net-class=warrior"], args, "host", tmp, host_secs))]
    time.sleep(delay)  # l'hôte ouvre son port avant les clients
    for i in range(args.clients):
        extra = ["--net-join=127.0.0.1"]
        if args.lag:
            extra.append(f"--net-lag={args.lag}")
        if args.loss:
            extra.append(f"--net-loss={args.loss}")
        procs.append((f"client {i + 1}", launch(extra, args, f"client{i + 1}", tmp, args.secs)))
        time.sleep(1.5)
    results = []
    for name, p in reversed(procs):
        p.wait()
        p.t1 = time.time()
        p.reader.join(5.0)
        usage = os_usage(p)
        for line in p.lines:
            line = line.rstrip("\n")
            if line.startswith("[net] {"):
                d = json.loads(line[6:])
                d["instance"] = name
                d["os"] = usage
                d["label"] = args.label
                results.append(d)
            elif line.startswith("[net]") or "SCRIPT ERROR" in line:
                print(f"{name} | {line}")
        print(f"{name} : code de sortie {p.returncode}")
    results.reverse()
    if args.json:
        with open(args.json, "a", encoding="utf-8") as f:
            for d in results:
                f.write(json.dumps(d, ensure_ascii=False) + "\n")
    for d in results:
        g = lambda k, s="med": d.get(k, {}).get(s, "—")
        o = d.get("os", {})
        print(f"{d['instance']:9} héros {d['heros']}  envoi {g('envoi_ko_s')} Ko/s  réception {g('reception_ko_s')} Ko/s"
              f"  paquets {g('paquets_envoyes_s')}/{g('paquets_recus_s')} par s  RTT {g('rtt_ms')} ms"
              f"  retard d'entrée {g('retard_entree_ms')} ms (p95 {g('retard_entree_ms', 'p95')})"
              f"  images/s {g('fps')}  instantané {g('instantane_octets')} o"
              f"  processeur {o.get('cpu_coeurs', '—')} cœur(s)  mémoire max {o.get('memoire_max_mo', '—')} Mo")
        for pid, v in d.get("vus", {}).items():
            print(f"            vu : {v['classe']:10} {'(moi)' if v['moi'] else '     '} {v['m']:7.1f} m parcourus,"
                  f" {v['anims']} animations différentes, {v['actions']} attaques / sorts")
    return 0 if results and len(results) == len(procs) else 1


if __name__ == "__main__":
    sys.exit(main())
