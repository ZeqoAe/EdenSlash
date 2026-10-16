"""Masque des iris du visage du héros (création de personnage, lot C1).

Lit la texture du visage (game/assets/player/textures/lfaces01b__4c3821.png, iris bleus) et écrit
lfaces01b_eyemask.png à côté : blanc = iris (recoloré par le shader eden_character, `use_eye`),
noir = le reste (peau, blanc de l'œil, reflet, cils). Bord adouci d'un pixel.

    python tools/gen_eye_mask.py
"""
from pathlib import Path

from PIL import Image, ImageFilter

ROOT = Path(__file__).resolve().parent.parent
TEX = ROOT / "game" / "assets" / "player" / "textures"
SRC = TEX / "lfaces01b__4c3821.png"
OUT = TEX / "lfaces01b_eyemask.png"


def main() -> None:
    im = Image.open(SRC).convert("RGBA")
    w, h = im.size
    src = im.load()
    mask = Image.new("L", (w, h), 0)
    dst = mask.load()
    n = 0
    for y in range(h):
        for x in range(w):
            r, g, b, _a = src[x, y]
            # iris : le bleu domine nettement (le reflet blanc et la peau beige n'y entrent pas)
            k = (b - max(r + 20, g)) / 30.0
            if k > 0.0:
                dst[x, y] = int(min(k, 1.0) * 255)
                n += 1
    mask = mask.filter(ImageFilter.GaussianBlur(0.6))
    mask.save(OUT)
    print(f"{OUT.name} : {n} pixels d'iris sur {w}x{h}")


if __name__ == "__main__":
    main()
