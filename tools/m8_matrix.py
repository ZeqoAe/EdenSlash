#!/usr/bin/env python3
"""Passe M8 : équilibre de la Tour entre classes. Lance res://tools/m8_tower.tscn en parallèle et range les lignes
[m8-étage] / [m8] en JSON ; --solo recalcule data/tower_solo.json (multiplicateurs de dégâts par classe, TowerBalance).

    python tools/m8_matrix.py run <sortie.json> <jobs> <projet game/> @specs.txt
        specs : une ligne « classe:étage:nb_étages:arg1,arg2 » (ex. « bard:30:1:--god,--pure,--pilot=bot »)
        Utiliser une copie propre (tools/run_tests.py --snap <dossier>) : le dossier de travail est partagé.
    python tools/m8_matrix.py solo <mesures.json> [<mesures2.json> ...]
        Mesures « --god --pure --pilot=bot » des 60 classes aux étages 30, 50 et 100 : le temps pour tuer de chaque classe (brut :
        × le multiplicateur « solo= » de la ligne s'il y en avait un), rapporté à la médiane des 60 classes de l'étage, à son pire
        étage, ramené à TARGET : mult = clamp(r / TARGET, 1, MAX).
"""
import concurrent.futures as cf
import json
import os
import re
import statistics as st
import subprocess
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
GODOT = os.environ.get("GODOT", str(Path.home() / "Godot" / "Godot_v4.7.2-stable_win64_console.exe"))
FLOORS = ["30", "50", "100"]  # boss de référence (équipement attendu : époque I aux étages 30 et 50, III au 100)
TARGET = 1.1  # temps pour tuer visé au plus : 1,1 fois la médiane des 60 classes
MAX = 1.8  # TowerBalance.MAX_MULT


def parse(line: str) -> dict:
    d = {}
    for m in re.finditer(r"(\w+)=([^ ]+)", line):
        v = m.group(2)
        try:
            v = float(v.rstrip("%"))
        except ValueError:
            pass
        d[m.group(1)] = v
    return d


def run_one(project: Path, tag: str, spec: str, idx: int) -> dict:
    cid, f, n, extra = spec.split(":", 3)
    args = [f"--class={cid}", f"--from={f}", f"--floors={n}"] + [a for a in extra.split(",") if a]
    env = dict(os.environ)
    ud = project.parent / "m8_ud" / f"{tag}_{idx}"
    ud.mkdir(parents=True, exist_ok=True)
    env["APPDATA"] = str(ud)  # profil jetable : le vrai n'est jamais touché
    env["EDEN_PROFILE"] = f"m8_{tag}_{idx}"
    t0 = time.time()
    try:
        out = subprocess.run([GODOT, "--headless", "--fixed-fps", "60", "--path", str(project), "res://tools/m8_tower.tscn", "--"] + args,
                             env=env, capture_output=True, timeout=int(os.environ.get("M8_WALL", "3600"))).stdout.decode("utf-8", "replace")
    except subprocess.TimeoutExpired:
        out = ""
    lines = out.splitlines()
    r = {"spec": spec, "floors": [parse(l) for l in lines if l.startswith("[m8-étage]")],
         "summary": next((parse(l) for l in lines if l.startswith("[m8]")), {}), "wall": round(time.time() - t0)}
    print(spec, "->", r["summary"].get("résultat", "?"), [(x.get("étage"), x.get("ttk", x.get("durée"))) for x in r["floors"]][-2:], flush=True)
    return r


def solo(files: list) -> dict:
    ttk: dict = {}
    for fn in files:
        for r in json.load(open(fn, encoding="utf-8")):
            cid, f = r["spec"].split(":")[:2]
            fl = [x for x in r["floors"] if "ttk" in x and x.get("issue") == "franchi"]
            if fl:
                ttk.setdefault(cid, {})[f] = fl[0]["ttk"] * float(fl[0].get("solo", 1.0))  # temps brut (sans multiplicateur)
    med = {f: st.median([ttk[c][f] for c in ttk if f in ttk[c]]) for f in FLOORS}
    mult = {}
    for c in sorted(ttk):
        rs = [ttk[c][f] / med[f] for f in FLOORS if f in ttk[c]]
        mult[c] = round(min(max(max(rs) / TARGET, 1.0), MAX), 2) if rs else 1.0
    return {"note": "passe M8 : multiplicateur de dégâts dans la Tour par classe (TowerBalance), tools/m8_matrix.py solo",
            "target": TARGET, "median_ttk": {f: round(med[f], 1) for f in FLOORS}, "mult": mult,
            "ttk": {c: {f: round(v, 1) for f, v in ttk[c].items()} for c in sorted(ttk)}}


if __name__ == "__main__":
    if len(sys.argv) >= 3 and sys.argv[1] == "solo":
        data = solo(sys.argv[2:])
        (ROOT / "game" / "data" / "tower_solo.json").write_text(json.dumps(data, ensure_ascii=False, indent=1) + "\n", "utf-8")
        print("data/tower_solo.json :", sum(1 for v in data["mult"].values() if v > 1.0), "classe(s) aidée(s)")
    elif len(sys.argv) >= 6 and sys.argv[1] == "run":
        out, jobs, project, specs = sys.argv[2], int(sys.argv[3]), Path(sys.argv[4]), sys.argv[5:]
        if len(specs) == 1 and specs[0].startswith("@"):
            specs = [l.strip() for l in open(specs[0][1:], encoding="utf-8") if l.strip()]
        tag = Path(out).stem
        with cf.ThreadPoolExecutor(jobs) as ex:
            res = list(ex.map(lambda si: run_one(project, tag, si[1], si[0]), enumerate(specs)))
        Path(out).write_text(json.dumps(res, ensure_ascii=False, indent=1), "utf-8")
    else:
        sys.exit(__doc__)
