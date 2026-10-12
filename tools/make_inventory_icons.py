# Icônes de l'écran Inventaire (traits blancs, teintées en or dans le jeu) :
# python -I tools/make_inventory_icons.py game/assets/ui/icons
import math
import sys

from PIL import Image, ImageDraw

out = sys.argv[1]
S = 256
W = 16
WH = (255, 255, 255, 255)


def new():
    im = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    return im, ImageDraw.Draw(im)


def save(im, name):
    im.resize((64, 64), Image.LANCZOS).save("%s/%s.png" % (out, name))


def rot(pts, ang, c=(128, 128)):
    ca, sa = math.cos(ang), math.sin(ang)
    return [(c[0] + (x - c[0]) * ca - (y - c[1]) * sa, c[1] + (x - c[0]) * sa + (y - c[1]) * ca) for x, y in pts]


def sword(d, ang, scale=1.0):
    blade = [(118, 20), (138, 20), (138, 170), (128, 188), (118, 170)]
    guard = [(92, 170), (164, 170), (164, 188), (92, 188)]
    grip = [(120, 186), (136, 186), (136, 222), (120, 222)]
    for part in (blade, guard, grip):
        d.polygon(rot(part, ang), fill=WH)
    x, y = rot([(128, 232)], ang)[0]
    d.ellipse((x - 11, y - 11, x + 11, y + 11), fill=WH)


# flèche de retour
im, d = new()
d.line([(200, 128), (64, 128)], fill=WH, width=22)
d.polygon([(40, 128), (110, 66), (110, 190)], fill=WH)
save(im, "back")

# statistiques (barres)
im, d = new()
for i, h in enumerate((70, 120, 170)):
    x = 52 + i * 58
    d.rounded_rectangle((x, 210 - h, x + 40, 210), 6, fill=WH)
d.line([(36, 222), (220, 222)], fill=WH, width=W)
save(im, "stats")

# arme (épée inclinée)
im, d = new()
sword(d, math.pi / 4)
save(im, "weapon")

# armure (plastron)
im, d = new()
d.polygon([(70, 50), (110, 40), (128, 70), (146, 40), (186, 50), (214, 100), (186, 120), (180, 216), (76, 216), (70, 120), (42, 100)],
          outline=WH, width=W)
d.line([(128, 76), (128, 210)], fill=WH, width=10)
save(im, "armor")

# accessoire (anneau avec pierre)
im, d = new()
d.ellipse((58, 86, 198, 226), outline=WH, width=20)
d.polygon([(128, 30), (164, 66), (128, 102), (92, 66)], fill=WH)
save(im, "ring")

# consommable (fiole)
im, d = new()
d.rectangle((106, 34, 150, 62), fill=WH)
d.line([(110, 62), (110, 100)], fill=WH, width=W)
d.line([(146, 62), (146, 100)], fill=WH, width=W)
d.ellipse((58, 92, 198, 228), outline=WH, width=W)
d.chord((74, 108, 182, 212), 10, 170, fill=WH)
save(im, "potion")

# matériau (gemme)
im, d = new()
d.polygon([(70, 70), (186, 70), (222, 112), (128, 222), (34, 112)], outline=WH, width=W)
d.line([(34, 112), (222, 112)], fill=WH, width=10)
d.line([(100, 70), (128, 222), (156, 70)], fill=WH, width=10)
save(im, "gem")

# divers (étoile à 4 branches)
im, d = new()
pts = []
for i in range(8):
    r = 100 if i % 2 == 0 else 34
    a = i * math.pi / 4 - math.pi / 2
    pts.append((128 + r * math.cos(a), 128 + r * math.sin(a)))
d.polygon(pts, fill=WH)
save(im, "misc")

# tous (losanges)
im, d = new()
for cx, cy in ((90, 90), (166, 90), (90, 166), (166, 166)):
    d.polygon([(cx, cy - 34), (cx + 34, cy), (cx, cy + 34), (cx - 34, cy)], fill=WH)
save(im, "all")

# recherche (loupe)
im, d = new()
d.ellipse((40, 40, 160, 160), outline=WH, width=20)
d.line([(146, 146), (216, 216)], fill=WH, width=28)
save(im, "search")

# cœur (PV)
im, d = new()
d.ellipse((40, 52, 132, 144), fill=WH)
d.ellipse((124, 52, 216, 144), fill=WH)
d.polygon([(46, 118), (210, 118), (128, 214)], fill=WH)
save(im, "heart")

# attaque (épée verticale)
im, d = new()
sword(d, math.pi / 5)
save(im, "attack")

# défense (bouclier)
im, d = new()
d.polygon([(128, 30), (210, 62), (200, 150), (128, 224), (56, 150), (46, 62)], outline=WH, width=W)
d.polygon([(128, 62), (178, 82), (172, 144), (128, 192)], fill=WH)
save(im, "defense")

# vitesse (éclair)
im, d = new()
d.polygon([(150, 24), (62, 142), (122, 142), (100, 232), (194, 108), (134, 108)], fill=WH)
save(im, "speed")

# agilité (aile)
im, d = new()
for i in range(4):
    y = 70 + i * 34
    d.chord((40 + i * 18, y - 30, 220, y + 46), 180, 360, fill=WH)
d.line([(60, 220), (210, 70)], fill=WH, width=12)
save(im, "agility")

# puissance d'équipement (emblème)
im, d = new()
pts = []
for i in range(16):
    r = 110 if i % 2 == 0 else 52
    a = i * math.pi / 8
    pts.append((128 + r * math.cos(a), 128 + r * math.sin(a)))
d.polygon(pts, fill=WH)
d.ellipse((96, 96, 160, 160), fill=(0, 0, 0, 0))
save(im, "power")

# améliorer (flèche vers le haut)
im, d = new()
d.polygon([(128, 30), (210, 120), (160, 120), (160, 220), (96, 220), (96, 120), (46, 120)], fill=WH)
save(im, "upgrade")

# démonter (flèches en cercle)
im, d = new()
d.arc((40, 40, 216, 216), 200, 340, fill=WH, width=20)
d.arc((40, 40, 216, 216), 20, 160, fill=WH, width=20)
d.polygon([(212, 92), (232, 150), (176, 136)], fill=WH)
d.polygon([(44, 164), (24, 106), (80, 120)], fill=WH)
save(im, "dismantle")

# joaillier (gemme sertie)
im, d = new()
d.polygon([(128, 40), (196, 104), (128, 216), (60, 104)], outline=WH, width=W)
d.ellipse((104, 92, 152, 140), fill=WH)
save(im, "jewel")

# accueil (maison)
im, d = new()
d.polygon([(128, 34), (226, 124), (196, 124), (196, 220), (60, 220), (60, 124), (30, 124)], outline=WH, width=W)
d.rectangle((110, 160, 146, 220), fill=WH)
save(im, "home")
print("icônes écrites dans", out)
