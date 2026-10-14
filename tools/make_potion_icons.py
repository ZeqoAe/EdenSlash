"""Icônes des 4 potions (game/assets/ui/potions/<id>.png) : fiole ronde, liquide coloré, reflet.
Dessinées en 4x puis réduites (bords lisses). Usage : python tools/make_potion_icons.py"""
import os
from PIL import Image, ImageDraw, ImageFilter

OUT = os.path.join(os.path.dirname(__file__), "..", "game", "assets", "ui", "potions")
POTIONS = {
    "heal": ((235, 60, 80), (255, 140, 150)),
    "haste": ((70, 200, 235), (170, 240, 255)),
    "frenzy": ((255, 150, 40), (255, 215, 130)),
    "keen": ((170, 90, 235), (225, 170, 255)),
}
S = 4
N = 64 * S


def lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


def draw(name, deep, light):
    im = Image.new("RGBA", (N, N), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    cx, cy, r = N // 2, int(N * 0.62), int(N * 0.30)
    # col de la fiole
    d.rounded_rectangle([cx - int(N * 0.09), int(N * 0.14), cx + int(N * 0.09), int(N * 0.40)], int(N * 0.03), fill=(210, 225, 235, 235), outline=(40, 40, 60, 255), width=S)
    # bouchon
    d.rounded_rectangle([cx - int(N * 0.11), int(N * 0.07), cx + int(N * 0.11), int(N * 0.17)], int(N * 0.03), fill=(150, 100, 60, 255), outline=(50, 30, 15, 255), width=S)
    # corps
    d.ellipse([cx - r - S, cy - r - S, cx + r + S, cy + r + S], fill=(40, 40, 60, 255))
    d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=(205, 225, 240, 255))
    # liquide : dégradé vertical dans le disque, niveau 78 %
    top = cy - int(r * 0.45)
    liq = Image.new("RGBA", (N, N), (0, 0, 0, 0))
    ld = ImageDraw.Draw(liq)
    for y in range(top, cy + r):
        t = (y - top) / max(1, (cy + r - top))
        ld.line([(0, y), (N, y)], fill=lerp(light, deep, t) + (255,))
    mask = Image.new("L", (N, N), 0)
    ImageDraw.Draw(mask).ellipse([cx - r + S, cy - r + S, cx + r - S, cy + r - S], fill=255)
    im.paste(liq, (0, 0), Image.composite(mask, Image.new("L", (N, N), 0), mask))
    d = ImageDraw.Draw(im)
    # reflet
    d.ellipse([cx - int(r * 0.62), cy - int(r * 0.35), cx - int(r * 0.30), cy + int(r * 0.15)], fill=(255, 255, 255, 150))
    # surface du liquide
    d.line([(cx - int(r * 0.8), top), (cx + int(r * 0.8), top)], fill=lerp(light, (255, 255, 255), 0.5) + (255,), width=S)
    im = im.resize((64, 64), Image.LANCZOS)
    os.makedirs(OUT, exist_ok=True)
    im.save(os.path.join(OUT, name + ".png"))


for k, (deep, light) in POTIONS.items():
    draw(k, deep, light)
print("ok", list(POTIONS))
