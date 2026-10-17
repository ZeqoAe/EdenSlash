#!/usr/bin/env python3
"""Rapport gdlint (GDScript Toolkit) de tous les scripts du jeu : avertissements par règle et par fichier. INFORMATIF.

    python tools/lint.py --installer        # une fois : venv dédié ~/.eden_tools/gdtoolkit_venv (gdtoolkit 4.5.0)
    python tools/lint.py                    # rapport : totaux par règle, fichiers les plus touchés
    python tools/lint.py game/scripts/core/compass.gd   # seulement ces fichiers (détail ligne par ligne)
    python tools/lint.py --json rapport.json --github   # (intégration continue) JSON + résumé de l'exécution

Réglages : `.gdlintrc` à la racine (règles trop bruyantes pour la base existante désactivées ou desserrées).
Code de sortie toujours 0 (sauf --strict) : le lint ne bloque rien. Ne lance JAMAIS gdformat sur tout le dépôt
(plusieurs sessions éditent les mêmes fichiers) ; un fichier à la fois et seulement le sien, si besoin.
Les fichiers « non analysables » utilisent une syntaxe que gdtoolkit ne connaît pas (chaîne sur plusieurs lignes...) :
Godot les compile très bien (c'est tools/check_scripts.py qui le vérifie).
"""
import argparse
import concurrent.futures as cf
import json
import os
import re
import shutil
import subprocess
import sys
from collections import Counter, defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
VENV = Path.home() / ".eden_tools" / "gdtoolkit_venv"
VERSION = "4.5.0"
RE_AVERT = re.compile(r"^(.+?\.gd):(\d+): (?:Error|Warning): (.*) \(([a-z-]+)\)\s*$")
RE_ENTETE = re.compile(r"^(\S.*\.gd):\s*$")


def exe_venv(nom: str) -> Path:
    return VENV / ("Scripts" if os.name == "nt" else "bin") / (nom + (".exe" if os.name == "nt" else ""))


def trouver_gdlint() -> str | None:
    for c in (os.environ.get("GDLINT"), str(exe_venv("gdlint"))):
        if c and Path(c).exists():
            return c
    return shutil.which("gdlint")


def installer() -> int:
    """Venv dédié hors du dépôt (pas celui de l'IA d'entraînement)."""
    py = sys.executable
    if os.name == "nt":  # Python 3.12 de préférence (gdtoolkit et ses dépendances y sont éprouvés)
        for c in (Path(os.environ.get("ProgramFiles", "C:/Program Files")) / "Python312" / "python.exe",):
            if c.exists():
                py = str(c)
    print(f"Création du venv {VENV} avec {py}...")
    VENV.parent.mkdir(parents=True, exist_ok=True)
    subprocess.run([py, "-m", "venv", str(VENV)], check=True)
    subprocess.run([str(exe_venv("python")), "-m", "pip", "install", "-q", f"gdtoolkit=={VERSION}"], check=True)
    print(f"gdtoolkit {VERSION} installé : {exe_venv('gdlint')}")
    return 0


def scripts_du_jeu() -> list[str]:
    r = subprocess.run(["git", "-C", str(ROOT), "ls-files", "--cached", "--others", "--exclude-standard", "-z",
                        "--", "game/*.gd"], capture_output=True)
    noms = [p for p in r.stdout.decode("utf-8", "replace").split("\0") if p]
    return sorted(p for p in noms if (ROOT / p).is_file() and not p.startswith(("game/.godot/", "game/Godot/")))


def lancer(gdlint: str, fichiers: list[str]) -> str:
    env = dict(os.environ, PYTHONIOENCODING="utf-8", PYTHONUTF8="1")
    r = subprocess.run([gdlint, *fichiers], cwd=ROOT, capture_output=True, env=env)
    return r.stdout.decode("utf-8", "replace") + "\n" + r.stderr.decode("utf-8", "replace")


def analyser(sortie: str, avert: list, illisibles: dict) -> None:
    lignes = sortie.splitlines()
    for i, l in enumerate(lignes):
        m = RE_AVERT.match(l.strip())
        if m:
            avert.append({"fichier": m.group(1).replace("\\", "/"), "ligne": int(m.group(2)), "message": m.group(3),
                          "regle": m.group(4)})
            continue
        m = RE_ENTETE.match(l)
        if m:  # erreur d'analyse : « fichier: » puis le message de lark
            suite = [x.strip() for x in lignes[i + 1:i + 12] if x.strip()]
            msg = next((x for x in suite if "at line" in x or x.startswith(("Unexpected", "No terminal"))),
                       suite[0] if suite else "")
            illisibles[m.group(1).replace("\\", "/")] = msg[:120]


def main() -> int:
    for flux in (sys.stdout, sys.stderr):
        try:
            flux.reconfigure(encoding="utf-8", errors="replace")
        except Exception:
            pass
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("fichiers", nargs="*", help="scripts à analyser (tous ceux du jeu si absent)")
    ap.add_argument("--installer", action="store_true", help="créer le venv dédié et y installer gdtoolkit")
    ap.add_argument("--json", help="écrire le détail dans ce fichier JSON")
    ap.add_argument("--github", action="store_true", help="tableau dans $GITHUB_STEP_SUMMARY")
    ap.add_argument("--top", type=int, default=15, help="nombre de fichiers listés (défaut 15)")
    ap.add_argument("--strict", action="store_true", help="code de sortie 1 s'il reste un avertissement")
    a = ap.parse_args()
    if a.installer:
        return installer()
    gdlint = trouver_gdlint()
    if not gdlint:
        print("gdlint introuvable : python tools/lint.py --installer (ou variable GDLINT).")
        return 0 if not a.strict else 1
    fichiers = [str(Path(f).resolve().relative_to(ROOT)).replace("\\", "/") for f in a.fichiers] or scripts_du_jeu()
    paquets = [fichiers[i:i + 25] for i in range(0, len(fichiers), 25)]
    avert: list[dict] = []
    illisibles: dict[str, str] = {}
    with cf.ThreadPoolExecutor(max_workers=max(1, (os.cpu_count() or 2) - 1)) as ex:
        for sortie in ex.map(lambda p: lancer(gdlint, p), paquets):
            analyser(sortie, avert, illisibles)

    par_regle = Counter(x["regle"] for x in avert)
    par_fichier = Counter(x["fichier"] for x in avert)
    detail = defaultdict(Counter)
    for x in avert:
        detail[x["fichier"]][x["regle"]] += 1
    print(f"gdlint ({Path(gdlint).name}, réglages .gdlintrc) : {len(avert)} avertissement(s) dans {len(par_fichier)} "
          f"fichier(s) sur {len(fichiers)} ; {len(illisibles)} non analysable(s) par gdtoolkit.")
    if a.fichiers:
        for x in sorted(avert, key=lambda x: (x["fichier"], x["ligne"])):
            print(f"  {x['fichier']}:{x['ligne']} : {x['message']} ({x['regle']})")
    print("\nPar règle :")
    for r, n in par_regle.most_common():
        print(f"  {n:6}  {r}")
    print(f"\nFichiers les plus touchés ({a.top}) :")
    for f, n in par_fichier.most_common(a.top):
        print(f"  {n:6}  {f}  ({', '.join(f'{r} {c}' for r, c in detail[f].most_common(3))})")
    if illisibles:
        print("\nNon analysables par gdtoolkit (Godot les compile ; voir check_scripts.py) :")
        for f, m in sorted(illisibles.items()):
            print(f"  {f} : {m}")
    if a.json:
        Path(a.json).write_text(json.dumps({"total": len(avert), "par_regle": dict(par_regle),
                                            "par_fichier": {f: dict(c) for f, c in detail.items()},
                                            "non_analysables": illisibles, "avertissements": avert},
                                           ensure_ascii=False, indent=1), "utf-8")
    if a.github and os.environ.get("GITHUB_STEP_SUMMARY"):
        with open(os.environ["GITHUB_STEP_SUMMARY"], "a", encoding="utf-8") as f:
            f.write(f"### Lint gdlint (informatif) : {len(avert)} avertissement(s), {len(illisibles)} fichier(s) "
                    f"non analysable(s)\n\n| Règle | Nombre |\n|---|---|\n")
            for r, n in par_regle.most_common():
                f.write(f"| {r} | {n} |\n")
            f.write("\n")
    return 1 if a.strict and (avert or illisibles) else 0


if __name__ == "__main__":
    sys.exit(main())
