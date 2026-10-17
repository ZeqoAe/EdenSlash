#!/usr/bin/env python3
"""Tableau des tests (rapport.json de tools/run_tests.py) pour le résumé d'une exécution GitHub Actions.

    python tools/ci_summary.py <dossier ou rapport.json> [titre]

Écrit dans $GITHUB_STEP_SUMMARY (sinon sur la sortie) : rouges d'abord, puis verts, durée, première ligne d'échec.
"""
import json
import os
import sys
from pathlib import Path


def main() -> int:
    try:
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    except Exception:
        pass
    cible = Path(sys.argv[1]) if len(sys.argv) > 1 else Path(".")
    titre = sys.argv[2] if len(sys.argv) > 2 else "Tests"
    rapports = [cible] if cible.is_file() else sorted(cible.rglob("rapport.json"))
    resultats = []
    for r in rapports:
        try:
            resultats += json.loads(r.read_text("utf-8"))
        except (OSError, ValueError):
            pass
    par_test: dict[str, list] = {}
    for r in resultats:
        par_test.setdefault(r["test"], []).append(r)
    lignes = []
    for t, rs in par_test.items():
        ok = sum(r["statut"] == "OK" for r in rs)
        etat = "vert" if ok == len(rs) else ("ROUGE" if ok == 0 else "INSTABLE")
        det = next((r.get("detail", "") for r in rs if r["statut"] != "OK"), "")
        lignes.append((etat != "vert", t, etat, max(r["duree"] for r in rs), det))
    lignes.sort(key=lambda x: (not x[0], x[1]))
    rouges = sum(1 for x in lignes if x[0])
    texte = [f"### {titre} : " + (f"ROUGE, {rouges} test(s) sur {len(lignes)}" if rouges else
                                   f"vert, {len(lignes)} test(s)") + "\n"]
    if not lignes:
        texte = [f"### {titre} : aucun rapport trouvé (le lanceur a échoué avant les tests ?)\n"]
    else:
        texte.append("| État | Test | Durée | Détail |\n|---|---|---|---|")
        for rouge, t, etat, duree, det in lignes:
            marque = f"**{etat}**" if rouge else etat
            texte.append(f"| {marque} | `{t}` | {duree:.0f} s | {det.replace('|', '/')} |")
        texte.append("\nJournaux complets : artefact « journaux-tests » de l'exécution.\n")
    sortie = os.environ.get("GITHUB_STEP_SUMMARY")
    if sortie:
        with open(sortie, "a", encoding="utf-8") as f:
            f.write("\n".join(texte) + "\n")
    else:
        print("\n".join(texte))
    return 0


if __name__ == "__main__":
    sys.exit(main())
