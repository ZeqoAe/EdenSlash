#!/usr/bin/env python3
"""Jeu de données d'un LoRA de style : captures du jeu (facultatif) puis dossier d'entraînement image + légende.

    # 1. captures sans interface de notre jeu (copie propre de HEAD, dossier utilisateur à part, fenêtre Godot)
    python tools/art/lora_dataset.py --capture --shots C:/AI/lora_shots
    # 1 bis. portraits (héros en pied, bustes, monstres) : le jeu de données v0b
    python tools/art/lora_dataset.py --portraits "heros:30:0;buste:15:2;monstre:36:3" --studio C:/AI/lora_studio
    # 2. dossier d'entraînement (images + .txt) d'après la liste écrite à la main
    python tools/art/lora_dataset.py --list conception/art/lora/dataset_v0.json --shots C:/AI/lora_shots \\
        --out C:/AI/lora_data/eden_style_v0 --sheet conception/art/lora/v0/jeu_de_donnees.jpg

La liste (JSON) donne pour chaque image sa source ('carte' = game/assets/ui/activities, 'capture' = --shots,
'studio' = --studio, 'icones' = planche faite d'une liste d'icônes, 'fichier' = chemin depuis la racine du dépôt) et sa légende (commence par le mot-clé de déclenchement).
Les images ne sont pas recadrées ici : l'entraîneur les range par format (bucketing, sans agrandissement).
Pillow requis (C:\\AI\\venv_comfy ou C:\\AI\\venv_train).
"""
import argparse
import json
import os
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
GODOT = Path.home() / "Godot" / "Godot_v4.7.2-stable_win64_console.exe"


def capture(shots: Path, snap: Path, zones: str, views: str, size: str) -> None:
    sys.path.insert(0, str(ROOT / "tools"))
    import run_tests  # copie propre de HEAD (cache d'import repris)
    game = run_tests.preparer_copie(snap)
    for f in ("lora_capture.gd", "lora_capture.tscn"):
        shutil.copy2(ROOT / "tools" / "art" / "godot" / f, game / "tools" / f)
    env = dict(os.environ)
    env["APPDATA"] = str(snap / "user")  # dossier utilisateur à part : aucun profil du joueur touché
    (snap / "user").mkdir(parents=True, exist_ok=True)
    env.pop("EDEN_PROFILE", None)
    subprocess.run([str(GODOT), "--headless", "--path", str(game), "--import"], env=env, capture_output=True, timeout=3600)
    # rendu réel (pas --headless) : petite fenêtre, rendu dans un SubViewport 2x
    r = subprocess.run([str(GODOT), "--path", str(game), "--resolution", "640x360", "res://tools/lora_capture.tscn", "--",
                        str(shots), zones, size, views], env=env, capture_output=True, timeout=3600)
    out = r.stdout.decode("utf-8", "replace")
    print("\n".join(line for line in out.splitlines() if line.startswith("[lora]")))


def icon_sheet(paths: list, cols: int = 8, cell: int = 128):
    """Planche d'icônes : 64 icônes de 64 px agrandies 2x (Lanczos) sur fond sombre, 1024 x 1024."""
    from PIL import Image
    rows = (len(paths) + cols - 1) // cols
    s = Image.new("RGB", (cols * cell, rows * cell), (30, 26, 40))
    for i, p in enumerate(paths):
        im = Image.open(ROOT / p).convert("RGBA").resize((cell, cell), Image.LANCZOS)
        s.paste(im, ((i % cols) * cell, (i // cols) * cell), im)
    return s


def studio_capture(studio: Path, snap: Path, kind: str, count: int, offset: int) -> None:
    """Portraits (héros en pied, bustes, monstres) : tools/art/godot/lora_studio.gd sur une copie propre de HEAD."""
    sys.path.insert(0, str(ROOT / "tools"))
    import run_tests
    game = snap / "game"
    if not (game / "project.godot").exists():
        game = run_tests.preparer_copie(snap)
    for f in ("lora_studio.gd", "lora_studio.tscn"):
        shutil.copy2(ROOT / "tools" / "art" / "godot" / f, game / "tools" / f)
    env = dict(os.environ)
    env["APPDATA"] = str(snap / "user")
    (snap / "user").mkdir(parents=True, exist_ok=True)
    env.pop("EDEN_PROFILE", None)
    subprocess.run([str(GODOT), "--headless", "--path", str(game), "--import"], env=env, capture_output=True, timeout=3600)
    r = subprocess.run([str(GODOT), "--path", str(game), "--resolution", "640x360", "res://tools/lora_studio.tscn", "--",
                        str(studio), kind, str(count), str(offset)], env=env, capture_output=True, timeout=3600)
    print("\n".join(line for line in r.stdout.decode("utf-8", "replace").splitlines() if line.startswith("[lora]")))


def build(lst: Path, shots: Path, out: Path, sheet: Path | None, studio: Path) -> None:
    from PIL import Image
    data = json.loads(lst.read_text(encoding="utf-8"))
    img_dir = out / "img"
    if img_dir.exists():
        shutil.rmtree(img_dir)
    img_dir.mkdir(parents=True)
    paths = []
    for i, e in enumerate(data["images"]):
        stem = f"{i:03d}_{Path(e['file']).stem}"
        if e["src"] == "icones":
            im = icon_sheet(e["icons"])
        else:
            src = {"carte": ROOT / "game" / "assets" / "ui" / "activities" / e["file"],
                   "capture": shots / e["file"],
                   "studio": studio / e["file"],
                   "fichier": ROOT / e["file"]}[e["src"]]
            if not src.exists():
                sys.exit(f"image absente : {src}")
            im = Image.open(src).convert("RGB")
        im.save(img_dir / f"{stem}.png")
        (img_dir / f"{stem}.txt").write_text(e["caption"].strip() + "\n", encoding="utf-8")
        paths.append(img_dir / f"{stem}.png")
    meta = {"nom": data["nom"], "declencheur": data["declencheur"], "images": len(paths)}
    (out / "dataset.json").write_text(json.dumps(meta, ensure_ascii=False, indent=1), encoding="utf-8")
    print(f"{len(paths)} images + légendes dans {img_dir}")
    if sheet:
        cols, tw = 8, 240
        th = 164
        rows = (len(paths) + cols - 1) // cols
        s = Image.new("RGB", (cols * tw, rows * th), (20, 18, 28))
        for i, p in enumerate(paths):
            im = Image.open(p)
            im.thumbnail((tw - 4, th - 4))
            s.paste(im, ((i % cols) * tw + (tw - im.width) // 2, (i // cols) * th + (th - im.height) // 2))
        sheet.parent.mkdir(parents=True, exist_ok=True)
        s.save(sheet, quality=85)
        print("planche :", sheet)


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--capture", action="store_true", help="refaire les captures du jeu")
    ap.add_argument("--snap", default="C:/AI/lora_snap", help="copie propre de game/ pour les captures")
    ap.add_argument("--zones", default="all")
    ap.add_argument("--views", default="all", help="paysage,aerien,heros,heros2,combat,monstre")
    ap.add_argument("--size", default="1216x832")
    ap.add_argument("--shots", default="C:/AI/lora_shots")
    ap.add_argument("--portraits", help="portraits à refaire, ex. 'heros:30:0;buste:15:2;monstre:36:3' (genre:nombre:décalage)")
    ap.add_argument("--studio", default="C:/AI/lora_studio", help="dossier des portraits")
    ap.add_argument("--list", help="liste JSON des images et légendes")
    ap.add_argument("--out", help="dossier d'entraînement")
    ap.add_argument("--sheet", help="planche JPG du jeu de données")
    a = ap.parse_args()
    if a.portraits:
        for spec in a.portraits.split(";"):
            kind, count, offset = spec.split(":")
            studio_capture(Path(a.studio), Path(a.snap), kind, int(count), int(offset))
    if a.capture:
        capture(Path(a.shots), Path(a.snap), a.zones, a.views, a.size)
    if a.list:
        build(Path(a.list), Path(a.shots), Path(a.out), Path(a.sheet) if a.sheet else None, Path(a.studio))
    return 0


if __name__ == "__main__":
    sys.exit(main())
