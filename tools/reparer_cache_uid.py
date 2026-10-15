# -*- coding: utf-8 -*-
"""Répare les avertissements « invalid UID » des modèles de tenue (.glb) dans la console de Godot.

    python tools/reparer_cache_uid.py [--godot <Godot_console.exe>] [--projet <dossier game>] [--test]

Cause : le cache d'import local (`game/.godot/imported`, hors git) garde, pour certains .glb, l'ancien identifiant (UID) d'une texture
partagée (`assets/player/textures/*.png`) ; Godot retombe sur le chemin et rien ne manque, mais la console se remplit d'avertissements.
Un dépôt neuf (pas de dossier `.godot`) n'a pas ce problème. Ce script charge tous les modèles du héros, relève ceux qui avertissent,
supprime LEUR cache d'import (.scn + .md5) puis relance `--import` : seuls ces fichiers du cache sont refaits, rien n'est versionné.
`--test` : liste seulement les modèles concernés. À lancer quand aucune autre instance de Godot ne travaille dans le dossier.
"""
import argparse
import re
import subprocess
import sys
from pathlib import Path

PROBE = '''extends SceneTree
func _init() -> void:
	var n := 0
	for dirp in ["res://assets/player/outfits", "res://assets/player/hairs", "res://assets/player/body", "res://assets/player/backs"]:
		var dir := DirAccess.open(dirp)
		if dir == null:
			continue
		for f in dir.get_files():
			if f.ends_with(".glb"):
				load(dirp + "/" + f)
				n += 1
	print("SONDE modèles chargés : ", n)
	quit()
'''


def run_godot(exe, project, *args):
    r = subprocess.run([exe, "--headless", "--path", str(project), *args], capture_output=True, text=True, encoding="utf-8", errors="replace")
    return r.stdout + r.stderr


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--godot", default=r"C:\Users\Nico\Godot\Godot_v4.7.2-stable_win64_console.exe")
    ap.add_argument("--projet", default=str(Path(__file__).resolve().parent.parent / "game"))
    ap.add_argument("--test", action="store_true")
    a = ap.parse_args()
    project = Path(a.projet)
    probe = project / "_sonde_uid.gd"
    probe.write_text(PROBE, encoding="utf-8")
    try:
        out = run_godot(a.godot, project, "-s", "res://_sonde_uid.gd")
    finally:
        probe.unlink(missing_ok=True)
    models = sorted(set(re.findall(r"WARNING: '(res://[^']+\.glb)': [^\n]*invalid UID", out)))
    print("%d modèle(s) avec un UID périmé dans le cache d'import" % len(models))
    if a.test or not models:
        for m in models:
            print("  ", m)
        return 0
    removed = 0
    for res in models:
        imp = project / (res.replace("res://", "") + ".import")
        m = re.search(r'path="res://\.godot/imported/([^"]+)"', imp.read_text(encoding="utf-8"))
        if not m:
            continue
        for name in (m.group(1), m.group(1).replace(".scn", ".md5")):
            f = project / ".godot" / "imported" / name
            if f.exists():
                f.unlink()
                removed += 1
    print("%d fichier(s) de cache supprimé(s), réimport…" % removed)
    run_godot(a.godot, project, "--import")
    probe.write_text(PROBE, encoding="utf-8")
    try:
        out = run_godot(a.godot, project, "-s", "res://_sonde_uid.gd")
    finally:
        probe.unlink(missing_ok=True)
    left = len(set(re.findall(r"WARNING: '(res://[^']+\.glb)': [^\n]*invalid UID", out)))
    print("avertissements restants : %d" % left)
    return 0 if left == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
