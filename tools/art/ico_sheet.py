"""Planche de contact des icônes (conception/art/ico/planche.jpg) : chaque icône à 64 px sur papier, 24 px sur encre."""
import os

from PIL import Image, ImageDraw, ImageFont

from ico_core import OUT_PNG, ROOT

PAPER = (255, 248, 236)
WELL = (46, 36, 80)
INKC = (34, 26, 58)


def _font(size):
    for f in (r"C:\Windows\Fonts\arialbd.ttf", r"C:\Windows\Fonts\arial.ttf"):
        if os.path.exists(f):
            return ImageFont.truetype(f, size)
    return ImageFont.load_default()


def make(reg, groups, out=None, cols=14, size=64, quality=54, only=None):
    out = out or os.path.join(ROOT, "conception", "art", "ico", "planche.jpg")
    cw, ch = 112, 98
    f_small, f_title = _font(11), _font(17)
    ids_by_group = {}
    for i, spec in reg.items():
        if only and i not in only:
            continue
        ids_by_group.setdefault(spec["group"], []).append(i)
    height = 10
    for g in groups:
        k = len(ids_by_group.get(g, []))
        if k:
            height += 30 + ((k + cols - 1) // cols) * ch
    W = cols * cw + 20
    sheet = Image.new("RGB", (W, height + 10), PAPER)
    d = ImageDraw.Draw(sheet)
    y = 10
    for g in groups:
        ids = ids_by_group.get(g, [])
        if not ids:
            continue
        d.text((12, y + 3), "%s (%d)" % (g, len(ids)), fill=INKC, font=f_title)
        y += 30
        for k, i in enumerate(ids):
            x = 10 + (k % cols) * cw
            yy = y + (k // cols) * ch
            p64 = os.path.join(OUT_PNG, "ico_%s_64.png" % i)
            if not os.path.exists(p64):
                continue
            im = Image.open(p64).convert("RGBA")
            if size != 64:
                im = im.resize((size, size), Image.LANCZOS)
            # fond papier pour la grande, puits d'encre pour la petite
            d.rectangle([x, yy, x + 70, yy + 70], fill=(255, 255, 255))
            sheet.paste(im, (x + 3, yy + 3), im)
            d.rectangle([x + 72, yy, x + cw - 6, yy + 70], fill=WELL)
            sm = im.resize((24, 24), Image.LANCZOS)
            sheet.paste(sm, (x + 76, yy + 6), sm)
            sm2 = im.resize((16, 16), Image.LANCZOS)
            sheet.paste(sm2, (x + 76, yy + 40), sm2)
            sheet.paste(sm2, (x + 98 - 16, yy + 40) if False else (x + 96 - 16, yy + 40 + 0), sm2) if False else None
            d.text((x, yy + 73), i[:17], fill=INKC, font=f_small)
        y += ((len(ids) + cols - 1) // cols) * ch
    os.makedirs(os.path.dirname(out), exist_ok=True)
    sheet.save(out, quality=quality, optimize=True)
    print("[ico] planche %s (%d Ko)" % (out, os.path.getsize(out) // 1024))
