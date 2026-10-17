"""NET-A : lance une vraie partie « Jouer ensemble » (game/scenes/net_arena.tscn) avec un hôte et N clients sur cette
machine, comme des amis le feraient (arguments SANS « -- » : profil et réglages normaux, un emplacement par instance).

    python tools/net_a.py                                  # 2 fenêtres : hôte + 1 client, au clavier (ZQSD, clic, 1-4, Maj, Espace)
    python tools/net_a.py --clients 3 --pilot              # 4 héros au pilote automatique
    python tools/net_a.py --headless --pilot --secs 20 [--lag 150 --loss 5] [--snap 20] [--json mesures.jsonl]
    python tools/net_a.py ... --project <copie de game/>   # dossier de travail en chantier : une copie propre (run_tests)
    python tools/net_a.py --pilot --secs 12 --shots <dossier>   # captures des fenêtres (après 6 s à deux)

Chaque instance a son dossier utilisateur (APPDATA détourné vers un dossier temporaire neta_*) ET son emplacement de
sauvegarde (--profil=neta_<instance>) : rien n'est écrit dans le vrai profil. Avec --secs, chaque instance écrit une
ligne « [net] {json} » de mesures (débit ENet réel, paquets, aller-retour, retard d'entrée, retard ressenti, images par
seconde) ; le script ajoute le temps processeur et la mémoire maximale de chaque processus (Windows) et résume.
Modèle : tools/net_probe.py (prototype NET-0).
"""
import argparse
import json
import os
import random
import subprocess
import sys
import tempfile
import threading
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from net_probe import GODOT, ROOT, os_usage  # noqa: E402


def launch(role_args, args, tag, tmp, secs):
    env = dict(os.environ)
    appdata = os.path.join(tmp, f"neta_{tag}")
    os.makedirs(appdata, exist_ok=True)
    env["APPDATA"] = appdata
    env.pop("EDEN_PROFILE", None)
    cmd = [GODOT]
    if args.headless:
        cmd.append("--headless")
    cmd += ["--path", args.project or os.path.join(ROOT, "game"), "res://scenes/net_arena.tscn"] + role_args
    cmd += [f"--profil=neta_{tag}", f"--net-port={args.port}"]
    if args.pilot:
        cmd.append("--net-pilot")
    if secs:
        cmd.append(f"--net-secs={secs}")
    if args.snap:
        cmd.append(f"--net-snap={args.snap}")
    if args.shots:
        cmd.append(f"--net-shot={os.path.join(args.shots, 'neta_' + tag + '.png')}")
    p = subprocess.Popen(cmd, env=env, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True,
                         encoding="utf-8", errors="replace")
    p.lines = []
    p.t0 = time.time()
    t = threading.Thread(target=lambda: p.lines.extend(p.stdout), daemon=True)
    t.start()
    p.reader = t
    return p


def main() -> int:
    for flux in (sys.stdout, sys.stderr):
        try:
            flux.reconfigure(encoding="utf-8", errors="replace")
        except Exception:
            pass
    ap = argparse.ArgumentParser()
    ap.add_argument("--clients", type=int, default=1)
    ap.add_argument("--pilot", action="store_true")
    ap.add_argument("--headless", action="store_true")
    ap.add_argument("--secs", type=float, default=0.0, help="durée de mesure de chaque client à deux ou plus (s)")
    ap.add_argument("--lag", type=int, default=0, help="aller-retour ajouté côté clients (ms)")
    ap.add_argument("--loss", type=float, default=0.0, help="paquets non fiables perdus côté clients (%%)")
    ap.add_argument("--snap", type=int, default=0, help="instantanés par seconde de l'hôte (défaut 30)")
    ap.add_argument("--port", type=int, default=0, help="port de l'hôte (défaut : au hasard, pour ne gêner personne)")
    ap.add_argument("--host-class", default="warrior")
    ap.add_argument("--address", default="127.0.0.1", help="adresse que les clients rejoignent (essai par l'adresse du réseau local)")
    ap.add_argument("--project", help="dossier du projet Godot (défaut : game/)")
    ap.add_argument("--json", help="ajoute les lignes [net] à ce fichier (une par instance)")
    ap.add_argument("--shots", help="dossier où chaque fenêtre écrit sa capture (neta_<instance>.png)")
    ap.add_argument("--label", default="")
    args = ap.parse_args()
    if not args.port:
        args.port = random.randint(21000, 51000)
    tmp = tempfile.mkdtemp(prefix="neta_")
    delay = 5.0 if args.headless else 8.0
    host_secs = args.secs + delay + 2.0 * args.clients + 12.0 if args.secs and args.clients else args.secs
    procs = [("hôte", launch(["--host", f"--net-class={args.host_class}"], args, "host", tmp, host_secs))]
    time.sleep(delay)
    classes = ["magician", "hunter", "cleric", "knight", "thief", "bard", "samurai"]
    for i in range(args.clients):
        extra = [f"--join={args.address}:{args.port}", f"--net-class={classes[i % len(classes)]}"]
        if args.lag:
            extra.append(f"--net-lag={args.lag}")
        if args.loss:
            extra.append(f"--net-loss={args.loss}")
        procs.append((f"client {i + 1}", launch(extra, args, f"client{i + 1}", tmp, args.secs)))
        time.sleep(2.0)
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
        g = lambda k, s="med": (d.get(k) or {}).get(s, "—")
        o = d.get("os", {})
        print(f"{d['instance']:9} héros {d.get('heros', '?')}  envoi {g('envoi_ko_s')} Ko/s  réception {g('reception_ko_s')} Ko/s"
              f"  paquets {g('paquets_envoyes_s')}/{g('paquets_recus_s')} par s  RTT {g('rtt_ms')} ms"
              f"  retard d'entrée {g('retard_entree_ms')} ms  ressenti {g('ressenti_ms')} ms (p95 {g('ressenti_ms', 'p95')})"
              f"  images/s {g('fps')}  instantané {g('instantane_octets')} o"
              f"  processeur {o.get('cpu_coeurs', '—')} cœur(s)  mémoire max {o.get('memoire_max_mo', '—')} Mo")
        for pid, v in d.get("vus", {}).items():
            print(f"            vu : {v['classe']:10} {'(moi)' if v['moi'] else '     '} {v['m']:7.1f} m parcourus,"
                  f" {v['anims']} animations différentes, {v['actions']} attaques / sorts")
    return 0 if results and len(results) == len(procs) else 1


if __name__ == "__main__":
    sys.exit(main())
