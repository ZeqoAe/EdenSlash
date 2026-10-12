"""Agrandissement des textures par IA (Real-ESRGAN, modèle « anime », carte graphique Vulkan).

    python -I tools/upscale_textures.py [fx] [objects] [--dry-run]

- fx      : textures des effets (game/assets/fx/textures) de 256 px ou moins -> ×2 ;
- objects : décors et maisons (game/assets/maps/objects/textures) de 512 px ou moins -> ×2.
Les originaux sont gardés dans extracted/textures_orig/ (une texture déjà sauvegardée n'est
plus retraitée ; pour revenir en arrière, recopier l'original). Le nom du fichier ne change
pas : les modèles .glb et les effets continuent de pointer dessus.
Outil : tools/third_party/realesrgan/realesrgan-ncnn-vulkan.exe
(https://github.com/xinntao/Real-ESRGAN/releases, v0.2.5.0, non versionné).
"""
import argparse
import os
import shutil
import subprocess
import sys
import tempfile

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..')
GAME = os.path.join(ROOT, 'game')
EXE = os.path.join(ROOT, 'tools', 'third_party', 'realesrgan', 'realesrgan-ncnn-vulkan.exe')
BACKUP = os.path.join(ROOT, 'extracted', 'textures_orig')
SETS = {
    # nom : (dossier, taille max des sources, fonction taille cible)
    'fx': ('assets/fx/textures', 256, lambda w, h: (w * 2, h * 2)),
    'objects': ('assets/maps/objects/textures', 512, lambda w, h: (w * 2, h * 2)),
}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('sets', nargs='*', default=list(SETS))
    ap.add_argument('--dry-run', action='store_true')
    a = ap.parse_args()
    from PIL import Image
    if not os.path.exists(EXE):
        sys.exit('Real-ESRGAN absent : %s' % EXE)
    for name in a.sets:
        rel, max_src, target = SETS[name]
        src_dir = os.path.join(GAME, rel)
        todo = []
        for f in sorted(os.listdir(src_dir)):
            if not f.endswith('.png'):
                continue
            if os.path.exists(os.path.join(BACKUP, rel, f)):
                continue  # déjà agrandie
            w, h = Image.open(os.path.join(src_dir, f)).size
            if max(w, h) <= max_src:
                todo.append((f, target(w, h)))
        print('%s : %d textures à agrandir' % (name, len(todo)))
        if a.dry_run or not todo:
            continue
        with tempfile.TemporaryDirectory() as tmp:
            tin, tout = os.path.join(tmp, 'in'), os.path.join(tmp, 'out')
            os.makedirs(tin)
            os.makedirs(tout)
            for f, _ in todo:
                shutil.copyfile(os.path.join(src_dir, f), os.path.join(tin, f))
            subprocess.run([EXE, '-i', tin, '-o', tout, '-n', 'realesrgan-x4plus-anime', '-f', 'png'],
                           check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            os.makedirs(os.path.join(BACKUP, rel), exist_ok=True)
            done = 0
            for f, size in todo:
                up = os.path.join(tout, f)
                if not os.path.exists(up):
                    print('  ! pas de sortie pour', f)
                    continue
                shutil.copyfile(os.path.join(src_dir, f), os.path.join(BACKUP, rel, f))
                im = Image.open(up)
                if im.size != size:
                    im = im.resize(size, Image.LANCZOS)
                im.save(os.path.join(src_dir, f), optimize=True)
                done += 1
            print('  %d textures agrandies' % done)


if __name__ == '__main__':
    main()
