# Icônes de menu (traits blancs, teintées dans le jeu) : python -I tools/make_menu_icons.py game/assets/ui/icons
import sys, math
from PIL import Image, ImageDraw
out = sys.argv[1]
S = 256
W = 16  # épaisseur du trait
WH = (255, 255, 255, 255)

def new():
	im = Image.new("RGBA", (S, S), (0, 0, 0, 0))
	return im, ImageDraw.Draw(im)

def save(im, name):
	im.resize((64, 64), Image.LANCZOS).save("%s/%s.png" % (out, name))

def poly(d, pts, fill=None, w=W):
	if fill:
		d.polygon(pts, fill=fill)
	d.line(pts + [pts[0]], fill=WH, width=w, joint="curve")

def rot(pts, ang, c=(128, 128)):
	ca, sa = math.cos(ang), math.sin(ang)
	return [(c[0] + (x - c[0]) * ca - (y - c[1]) * sa, c[1] + (x - c[0]) * sa + (y - c[1]) * ca) for x, y in pts]

# épées croisées
im, d = new()
for a in (-math.pi / 4, math.pi / 4):
	blade = [(115, 22), (141, 22), (141, 166), (128, 184), (115, 166)]
	d.polygon(rot(blade, a), fill=WH)
	guard = [(88, 168), (168, 168), (168, 188), (88, 188)]
	d.polygon(rot(guard, a), fill=WH)
	grip = [(118, 186), (138, 186), (138, 222), (118, 222)]
	d.polygon(rot(grip, a), fill=WH)
	d.ellipse([(x - 11, y - 11, x + 11, y + 11) for x, y in rot([(128, 232)], a)][0], fill=WH)
save(im, "play")

# casque
im, d = new()
d.chord((52, 40, 204, 200), 180, 360, fill=WH)
d.rectangle((52, 118, 204, 132), fill=WH)
d.rectangle((52, 118, 82, 214), fill=WH)
d.rectangle((174, 118, 204, 214), fill=WH)
d.rectangle((120, 118, 136, 196), fill=WH)
d.polygon([(120, 40), (136, 40), (140, 18), (116, 18)], fill=WH)
save(im, "class")

# sac à dos
im, d = new()
d.rounded_rectangle((58, 70, 198, 226), 34, outline=WH, width=W)
d.arc((92, 30, 164, 100), 180, 360, fill=WH, width=W)
d.rounded_rectangle((86, 140, 170, 196), 12, outline=WH, width=W)
d.line((86, 158, 170, 158), fill=WH, width=W)
save(im, "equipment")

# livre ouvert
im, d = new()
d.polygon([(128, 70), (34, 50), (34, 200), (128, 220)], outline=None)
d.line([(128, 72), (36, 52), (36, 198), (128, 218), (220, 198), (220, 52), (128, 72), (128, 218)], fill=WH, width=W, joint="curve")
for k in range(3):
	y = 92 + k * 32
	d.line((58, y - 4, 108, y + 6), fill=WH, width=8)
	d.line((148, y + 6, 198, y - 4), fill=WH, width=8)
save(im, "collection")

# info
im, d = new()
d.ellipse((30, 30, 226, 226), outline=WH, width=W)
d.rounded_rectangle((116, 110, 140, 188), 8, fill=WH)
d.ellipse((114, 66, 142, 94), fill=WH)
save(im, "info")

# engrenage
im, d = new()
teeth = []
for i in range(8):
	a = i * math.pi / 4
	teeth.append(rot([(112, 22), (144, 22), (150, 60), (106, 60)], a))
for t in teeth:
	d.polygon(t, fill=WH)
d.ellipse((50, 50, 206, 206), fill=WH)
d.ellipse((96, 96, 160, 160), fill=(0, 0, 0, 0))
save(im, "settings")

# porte et flèche
im, d = new()
d.line([(150, 70), (150, 34), (52, 34), (52, 222), (150, 222), (150, 186)], fill=WH, width=W, joint="curve")
d.polygon([(52, 34), (120, 58), (120, 238), (52, 222)], fill=WH)
d.line((140, 128, 226, 128), fill=WH, width=W)
d.polygon([(232, 128), (196, 96), (196, 160)], fill=WH)
save(im, "quit")

# repère de carte
im, d = new()
d.ellipse((56, 24, 200, 168), fill=WH)
d.polygon([(66, 124), (190, 124), (128, 236)], fill=WH)
d.ellipse((100, 68, 156, 124), fill=(0, 0, 0, 0))
save(im, "pin")

# coffre
im, d = new()
d.rounded_rectangle((36, 96, 220, 216), 14, fill=(255, 205, 90, 255), outline=(150, 95, 25, 255), width=10)
d.chord((36, 40, 220, 150), 180, 360, fill=(255, 220, 120, 255), outline=(150, 95, 25, 255), width=10)
d.rectangle((36, 92, 220, 104), fill=(150, 95, 25, 255))
d.rounded_rectangle((110, 84, 146, 136), 6, fill=(150, 95, 25, 255))
d.rectangle((120, 100, 136, 120), fill=(255, 240, 200, 255))
save(im, "chest")

# silhouette
im, d = new()
d.ellipse((84, 26, 172, 114), fill=WH)
d.chord((40, 126, 216, 330), 180, 360, fill=WH)
save(im, "user")

# horloge
im, d = new()
d.ellipse((30, 30, 226, 226), outline=WH, width=W)
d.line((128, 128, 128, 70), fill=WH, width=W)
d.line((128, 128, 172, 150), fill=WH, width=W)
save(im, "clock")

# disquette (sauvegarde)
im, d = new()
d.polygon([(40, 40), (190, 40), (216, 66), (216, 216), (40, 216)], outline=WH, width=W)
d.line([(40, 40), (190, 40), (216, 66), (216, 216), (40, 216), (40, 40)], fill=WH, width=W, joint="curve")
d.rectangle((80, 40, 176, 96), fill=WH)
d.rounded_rectangle((76, 136, 180, 216), 6, outline=WH, width=W)
save(im, "save")

# plus (nouvelle partie)
im, d = new()
d.ellipse((30, 30, 226, 226), outline=WH, width=W)
d.rectangle((118, 72, 138, 184), fill=WH)
d.rectangle((72, 118, 184, 138), fill=WH)
save(im, "new")

# flèche de lecture (continuer)
im, d = new()
d.ellipse((30, 30, 226, 226), outline=WH, width=W)
d.polygon([(104, 80), (104, 176), (180, 128)], fill=WH)
save(im, "continue")

# grimoire (livre fermé)
im, d = new()
d.rounded_rectangle((56, 30, 200, 226), 12, outline=WH, width=W)
d.line((84, 30, 84, 226), fill=WH, width=W)
d.polygon([(142, 84), (156, 116), (190, 118), (164, 140), (172, 174), (142, 156), (112, 174), (120, 140), (94, 118), (128, 116)], fill=WH)
save(im, "grimoire")

# étoile (expertise)
im, d = new()
pts = []
for i in range(10):
	r = 104 if i % 2 == 0 else 44
	a = -math.pi / 2 + i * math.pi / 5
	pts.append((128 + r * math.cos(a), 136 + r * math.sin(a)))
d.polygon(pts, fill=WH)
save(im, "expertise")
