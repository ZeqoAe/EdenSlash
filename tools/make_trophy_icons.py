# Icônes des trophées (or, argent, bronze, jade) : python -I tools/make_trophy_icons.py game/assets/ui/items
import sys
from PIL import Image, ImageDraw, ImageFilter
out = sys.argv[1]
S = 256
def lerp(a, b, t): return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(len(a)))
variants = [
	((255, 214, 90), (170, 110, 20), (255, 245, 200)),   # or
	((215, 220, 235), (110, 115, 135), (255, 255, 255)),  # argent
	((230, 150, 90), (130, 70, 30), (255, 210, 170)),     # bronze
	((120, 230, 190), (30, 120, 100), (220, 255, 240)),   # jade
]
for n, (mid, dark, light) in enumerate(variants, 1):
	im = Image.new("RGBA", (S, S), (0, 0, 0, 0))
	d = ImageDraw.Draw(im)
	# cadre façon icône d'Eden : bord clair, fond gris dégradé
	d.rounded_rectangle((0, 0, S - 1, S - 1), 34, fill=(70, 74, 82, 255))
	d.rounded_rectangle((6, 6, S - 7, S - 7), 30, fill=(150, 148, 150, 255))
	for y in range(14, S - 14):
		t = (y - 14) / (S - 28)
		c = lerp((105, 104, 108), (58, 58, 62), t)
		d.line((14, y, S - 15, y), fill=c + (255,))
	mask = Image.new("L", (S, S), 0)
	ImageDraw.Draw(mask).rounded_rectangle((14, 14, S - 15, S - 15), 26, fill=255)
	bg = im.copy()
	im = Image.new("RGBA", (S, S), (0, 0, 0, 0))
	im.paste(bg, (0, 0))
	# coupe
	cup = Image.new("RGBA", (S, S), (0, 0, 0, 0))
	c = ImageDraw.Draw(cup)
	cx = S // 2
	# anses
	c.arc((cx - 92, 62, cx - 28, 140), 90, 270, fill=dark + (255,), width=16)
	c.arc((cx + 28, 62, cx + 92, 140), 270, 90, fill=dark + (255,), width=16)
	c.arc((cx - 88, 66, cx - 32, 136), 90, 270, fill=mid + (255,), width=9)
	c.arc((cx + 32, 66, cx + 88, 136), 270, 90, fill=mid + (255,), width=9)
	# vasque (dégradé horizontal)
	bowl = Image.new("RGBA", (S, S), (0, 0, 0, 0))
	bm = Image.new("L", (S, S), 0)
	ImageDraw.Draw(bm).chord((cx - 66, 0, cx + 66, 170), 0, 180, fill=255)
	ImageDraw.Draw(bm).rectangle((cx - 66, 52, cx + 66, 86), fill=255)
	grad = Image.new("RGBA", (S, S))
	gd = ImageDraw.Draw(grad)
	for x in range(S):
		t = abs((x - (cx - 22)) / 90.0)
		gd.line((x, 0, x, S), fill=lerp(light, dark, min(1.0, t)) + (255,))
	bowl.paste(grad, (0, 0), bm)
	cup.alpha_composite(bowl)
	c = ImageDraw.Draw(cup)
	c.ellipse((cx - 66, 44, cx + 66, 64), fill=dark + (255,))
	c.ellipse((cx - 60, 47, cx + 60, 61), fill=lerp(dark, (0, 0, 0), 0.4) + (255,))
	# pied
	c.rectangle((cx - 12, 168, cx + 12, 196), fill=mid + (255,))
	c.rectangle((cx - 12, 168, cx - 4, 196), fill=light + (255,))
	c.rounded_rectangle((cx - 48, 194, cx + 48, 214), 6, fill=dark + (255,))
	c.rounded_rectangle((cx - 40, 190, cx + 40, 204), 5, fill=mid + (255,))
	# étoile gravée
	import math
	pts = []
	for i in range(10):
		r = 18 if i % 2 == 0 else 8
		a = -math.pi / 2 + i * math.pi / 5
		pts.append((cx + r * math.cos(a), 118 + r * math.sin(a)))
	c.polygon(pts, fill=light + (255,), outline=dark + (255,))
	# ombre portée
	sh = cup.split()[3].filter(ImageFilter.GaussianBlur(6))
	shadow = Image.new("RGBA", (S, S), (0, 0, 0, 160))
	im.paste(shadow, (6, 8), sh)
	im.alpha_composite(cup)
	# reflet
	hl = Image.new("RGBA", (S, S), (0, 0, 0, 0))
	ImageDraw.Draw(hl).ellipse((cx - 50, 70, cx - 30, 140), fill=(255, 255, 255, 70))
	im.alpha_composite(hl.filter(ImageFilter.GaussianBlur(3)))
	im.resize((64, 64), Image.LANCZOS).save("%s/t%05d.png" % (out, n))
