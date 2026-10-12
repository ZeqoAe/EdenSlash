"""Génère les éléments d'interface dessinés (pas d'assets d'Eden équivalents dans le dépôt).

    python -I tools/make_ui_assets.py

Sorties (game/assets/ui/) :
  status/<effet>.png   icônes des effets sans icône d'Eden (gel, brûlure, foudre, buffs...)
                       — à remplacer par les vraies icônes du client quand elles seront extraites
                       (même nom de fichier : le jeu les prend automatiquement)
  frame/panel.png      cadre 9-slice des panneaux (fond indigo, double filet doré, coins ornés)
  frame/slot.png       cadre des emplacements (compétences, effets)
"""
import math
import os

from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.join(os.path.dirname(__file__), '..')
UI = os.path.join(ROOT, 'game', 'assets', 'ui')
S = 4  # suréchantillonnage (anticrénelage)
GOLD = (250, 200, 90)


def rgba(c, a=255):
    return (c[0], c[1], c[2], a)


def lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(len(a)))


# --- icônes d'effets ---------------------------------------------------------------------
def icon_base(top, bottom, size=64):
    n = size * S
    img = Image.new('RGBA', (n, n), (0, 0, 0, 0))
    grad = Image.new('RGBA', (n, n))
    gd = ImageDraw.Draw(grad)
    for y in range(n):
        gd.line([(0, y), (n, y)], fill=rgba(lerp(top, bottom, y / n)))
    mask = Image.new('L', (n, n), 0)
    ImageDraw.Draw(mask).rounded_rectangle([2 * S, 2 * S, n - 2 * S, n - 2 * S], radius=10 * S, fill=255)
    img.paste(grad, (0, 0), mask)
    d = ImageDraw.Draw(img)
    # reflet en haut, filet sombre et filet clair
    d.rounded_rectangle([2 * S, 2 * S, n - 2 * S, n - 2 * S], radius=10 * S, outline=(20, 12, 30, 255), width=3 * S)
    d.rounded_rectangle([5 * S, 5 * S, n - 5 * S, n - 5 * S], radius=8 * S, outline=(255, 255, 255, 70), width=S)
    hl = Image.new('RGBA', (n, n), (0, 0, 0, 0))
    ImageDraw.Draw(hl).ellipse([8 * S, 4 * S, n - 8 * S, n * 0.45], fill=(255, 255, 255, 45))
    img.alpha_composite(hl)
    return img, d, n


def glyph(img, draw_fn):
    """Dessine le symbole en blanc avec un contour sombre."""
    n = img.size[0]
    shadow = Image.new('RGBA', (n, n), (0, 0, 0, 0))
    draw_fn(ImageDraw.Draw(shadow), (30, 15, 40, 255), 1.0, 6 * S)
    shadow = shadow.filter(ImageFilter.GaussianBlur(S))
    img.alpha_composite(shadow)
    draw_fn(ImageDraw.Draw(img), (255, 255, 255, 255), 1.0, 0)


def P(n, x, y):
    return (x * n / 64.0, y * n / 64.0)


def snowflake(d, col, k, extra, n, scale=1.0):
    c = 32
    w = int(4 * S * scale) + extra
    for a in range(3):
        ang = math.radians(a * 60)
        dx, dy = math.cos(ang) * 20 * scale, math.sin(ang) * 20 * scale
        d.line([P(n, c - dx, c - dy), P(n, c + dx, c + dy)], fill=col, width=w)
        for sgn in (1, -1):
            bx, by = c + sgn * dx * 0.6, c + sgn * dy * 0.6
            for t in (1, -1):
                ang2 = ang + t * math.radians(45) + (math.pi if sgn < 0 else 0)
                d.line([P(n, bx, by), P(n, bx + math.cos(ang2) * 7 * scale, by + math.sin(ang2) * 7 * scale)], fill=col, width=max(1, w - S))
    d.ellipse([P(n, c - 4, c - 4), P(n, c + 4, c + 4)], fill=col)


def flame(d, col, k, extra, n):
    e = extra / S
    pts = []
    for i in range(40):
        t = i / 39 * math.pi * 2
        r = 15 + e
        x = 32 + math.sin(t) * r * 0.85
        y = 38 + math.cos(t) * r * 0.75
        if math.cos(t) < 0:  # pointe vers le haut
            y = 38 + math.cos(t) * (r + 14 * (1 - abs(math.sin(t)))) * 1.05
        pts.append(P(n, x, y))
    d.polygon(pts, fill=col)
    if extra == 0:
        inner = [P(n, 32 + math.sin(t) * 6, 44 + math.cos(t) * 5 - (10 * (1 - abs(math.sin(t))) if math.cos(t) < 0 else 0)) for t in [i / 29 * math.pi * 2 for i in range(30)]]
        d.polygon(inner, fill=(255, 190, 80, 255))


def bolt(d, col, k, extra, n):
    e = extra / S * 0.6
    pts = [(36 + e, 6 - e), (16 - e, 36 + e * 0.3), (30, 36), (24 - e, 58 + e), (48 + e, 26 - e * 0.3), (34, 26), (42 + e, 6 - e)]
    d.polygon([P(n, x, y) for x, y in pts], fill=col)


def swords(d, col, k, extra, n):
    w = 5 * S + extra
    d.line([P(n, 14, 50), P(n, 50, 14)], fill=col, width=w)
    d.line([P(n, 14, 14), P(n, 50, 50)], fill=col, width=w)
    for (a, b) in [((18, 38), (26, 46)), ((38, 46), (46, 38))]:
        d.line([P(n, *a), P(n, *b)], fill=col, width=w)


def eye(d, col, k, extra, n):
    e = extra / S
    top = [P(n, 8 - e + i * (48 + 2 * e) / 20, 32 - math.sin(i / 20 * math.pi) * (14 + e)) for i in range(21)]
    bot = [P(n, 56 + e - i * (48 + 2 * e) / 20, 32 + math.sin(i / 20 * math.pi) * (14 + e)) for i in range(21)]
    d.polygon(top + bot, fill=col)
    if extra == 0:
        d.ellipse([P(n, 23, 23), P(n, 41, 41)], fill=(120, 80, 20, 255))
        d.ellipse([P(n, 28, 28), P(n, 36, 36)], fill=(20, 10, 10, 255))
        d.ellipse([P(n, 30, 27), P(n, 33, 30)], fill=(255, 255, 255, 255))


def chevrons(d, col, k, extra, n):
    w = 6 * S + extra
    for off in (0, 14):
        d.line([P(n, 14 + off, 16), P(n, 30 + off, 32), P(n, 14 + off, 48)], fill=col, width=w, joint='curve')


def shield(d, col, k, extra, n):
    e = extra / S
    pts = [(32, 8 - e), (52 + e, 15 - e * 0.5), (50 + e, 34), (32, 57 + e), (14 - e, 34), (12 - e, 15 - e * 0.5)]
    d.polygon([P(n, x, y) for x, y in pts], fill=col)
    if extra == 0:
        d.line([P(n, 32, 16), P(n, 32, 48)], fill=(80, 120, 200, 255), width=4 * S)
        d.line([P(n, 20, 28), P(n, 44, 28)], fill=(80, 120, 200, 255), width=4 * S)


def fury(d, col, k, extra, n):
    e = extra / S
    # épée dressée entourée de flammes
    d.polygon([P(n, 32, 6 - e), P(n, 37 + e, 14), P(n, 36 + e, 42), P(n, 28 - e, 42), P(n, 27 - e, 14)], fill=col)
    d.rectangle([P(n, 20 - e, 42 - e), P(n, 44 + e, 47 + e)], fill=col)
    d.rectangle([P(n, 29 - e, 47), P(n, 35 + e, 58 + e)], fill=col)
    for sx in (14, 50):
        d.polygon([P(n, sx, 40), P(n, sx - 5 - e, 26), P(n, sx, 16 - e), P(n, sx + 5 + e, 26)], fill=col)


def stars(d, col, k, extra, n):
    e = extra / S
    for i in range(3):
        a = i * math.pi * 2 / 3 - math.pi / 2
        cx, cy = 32 + math.cos(a) * 14, 32 + math.sin(a) * 14
        pts = []
        for j in range(10):
            r = (8 + e) if j % 2 == 0 else (3.5 + e * 0.5)
            b = j * math.pi / 5 - math.pi / 2
            pts.append(P(n, cx + math.cos(b) * r, cy + math.sin(b) * r))
        d.polygon(pts, fill=col)


def waves(d, col, k, extra, n):
    w = 5 * S + extra
    for i, y in enumerate((22, 34, 46)):
        pts = [P(n, 10 + x, y + math.sin((x / 44) * math.pi * 2 + i) * 5) for x in range(0, 45, 3)]
        d.line(pts, fill=col, width=w, joint='curve')


def hourglass(d, col, k, extra, n):
    e = extra / S
    d.polygon([P(n, 16 - e, 10 - e), P(n, 48 + e, 10 - e), P(n, 34, 32), P(n, 48 + e, 54 + e), P(n, 16 - e, 54 + e), P(n, 30, 32)], fill=col)
    if extra == 0:
        d.polygon([P(n, 22, 16), P(n, 42, 16), P(n, 32, 28)], fill=(120, 170, 230, 255))
        d.polygon([P(n, 32, 40), P(n, 42, 50), P(n, 22, 50)], fill=(120, 170, 230, 255))


ICONS = {
    # effet : (haut, bas, symbole)
    'freeze': ((120, 210, 255), (20, 60, 140), lambda d, c, k, e, n: snowflake(d, c, k, e, n)),
    'chill': ((150, 200, 240), (40, 70, 120), hourglass),
    'burn': ((255, 170, 60), (150, 30, 10), flame),
    'shock': ((190, 160, 255), (60, 30, 140), bolt),
    'frenzy': ((255, 160, 70), (140, 50, 10), swords),
    'keen': ((255, 225, 110), (150, 90, 10), eye),
    'haste': ((140, 255, 170), (20, 110, 60), chevrons),
    'barrier': ((180, 210, 255), (40, 70, 150), shield),
    'fury': ((255, 110, 100), (120, 10, 20), fury),
    'stun': ((255, 240, 120), (150, 110, 10), stars),
    'flow': ((120, 240, 255), (10, 80, 130), waves),
}


def make_icons():
    out = os.path.join(UI, 'status')
    os.makedirs(out, exist_ok=True)
    for name, (top, bottom, fn) in ICONS.items():
        img, d, n = icon_base(top, bottom)
        glyph(img, lambda dd, col, k, extra, f=fn, nn=n: f(dd, col, k, extra, nn))
        img.resize((64, 64), Image.LANCZOS).save(os.path.join(out, name + '.png'))
    print('icônes :', ', '.join(ICONS))


# --- cadres ------------------------------------------------------------------------------
def diamond(d, cx, cy, r, fill):
    d.polygon([(cx, cy - r), (cx + r, cy), (cx, cy + r), (cx - r, cy)], fill=fill)


def make_panel():
    """Cadre 9-slice 96×96 (marges 24) : fond indigo dégradé, double filet doré, coins ornés."""
    size = 96
    n = size * S
    img = Image.new('RGBA', (n, n), (0, 0, 0, 0))
    grad = Image.new('RGBA', (n, n))
    gd = ImageDraw.Draw(grad)
    for y in range(n):
        gd.line([(0, y), (n, y)], fill=rgba(lerp((28, 22, 48), (12, 9, 22), y / n), 238))
    mask = Image.new('L', (n, n), 0)
    ImageDraw.Draw(mask).rounded_rectangle([3 * S, 3 * S, n - 3 * S, n - 3 * S], radius=12 * S, fill=255)
    img.paste(grad, (0, 0), mask)
    d = ImageDraw.Draw(img)
    d.rounded_rectangle([3 * S, 3 * S, n - 3 * S, n - 3 * S], radius=12 * S, outline=rgba(GOLD, 230), width=int(2.2 * S))
    d.rounded_rectangle([8 * S, 8 * S, n - 8 * S, n - 8 * S], radius=8 * S, outline=rgba((200, 150, 70), 110), width=S)
    for cx, cy in [(10, 10), (n / S - 10, 10), (10, n / S - 10), (n / S - 10, n / S - 10)]:
        diamond(d, cx * S, cy * S, 5 * S, rgba(GOLD, 255))
        diamond(d, cx * S, cy * S, 2 * S, (60, 30, 20, 255))
    out = os.path.join(UI, 'frame')
    os.makedirs(out, exist_ok=True)
    img.resize((size, size), Image.LANCZOS).save(os.path.join(out, 'panel.png'))


def make_slot():
    """Cadre d'emplacement 64×64 (centre transparent) : filet doré biseauté."""
    size = 64
    n = size * S
    img = Image.new('RGBA', (n, n), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rounded_rectangle([1 * S, 1 * S, n - 1 * S, n - 1 * S], radius=9 * S, outline=(20, 12, 30, 255), width=3 * S)
    d.rounded_rectangle([2 * S, 2 * S, n - 2 * S, n - 2 * S], radius=8 * S, outline=rgba(GOLD, 255), width=2 * S)
    d.rounded_rectangle([5 * S, 5 * S, n - 5 * S, n - 5 * S], radius=6 * S, outline=(255, 235, 180, 90), width=S)
    for cx, cy in [(5, 5), (59, 5), (5, 59), (59, 59)]:
        diamond(d, cx * S, cy * S, 3 * S, rgba(GOLD, 255))
    out = os.path.join(UI, 'frame')
    img.resize((size, size), Image.LANCZOS).save(os.path.join(out, 'slot.png'))


if __name__ == '__main__':
    make_icons()
    make_panel()
    make_slot()
    print('cadres : frame/panel.png, frame/slot.png')
