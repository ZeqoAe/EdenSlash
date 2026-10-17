#!/usr/bin/env python3
"""Textures haute définition d'un héros (lot CHR-2, conception/art/R_CHR2.md) : agrandissement ×4 d'une texture d'Eden
(512 -> 2048) avec trois méthodes comparables, et peinture par masque sur les îles d'UV.

    C:\\AI\\venv_comfy\\Scripts\\python.exe tools/art/chr2_tex.py up   <texture.png> <sortie_dossier> [--prompt "..."] [--denoise 0.3]
    C:\\AI\\venv_comfy\\Scripts\\python.exe tools/art/chr2_tex.py mask <texture.png> <masque.png> <canal r|g|b> <sortie.png> --prompt "..."
    C:\\AI\\venv_comfy\\Scripts\\python.exe tools/art/chr2_tex.py lines <texture.png> <sortie.png> [--scale 4]

up : écrit <nom>_lanczos.png (×4 seul), <nom>_lines.png (×4 + traits sombres redessinés nets), <nom>_ai.png (×4, puis SDXL
     image vers image par tuiles de 1024 avec recouvrement fondu, débruitage --denoise, puis traits redessinés).
mask : SDXL (LoRA eden_style) ne repeint que l'intérieur du masque (canal choisi du masque de teinture d'Eden = îles d'UV
       d'une même matière) : le reste de l'atlas est gardé au pixel près, les coutures entre îles ne bougent pas.
lines : redessine les traits sombres (contours peints d'Eden) à l'échelle voulue : seuil doux sur une version agrandie et
        lissée, puis posés par-dessus (le « retouche à la main » d'un peintre, fait par code).
ComfyUI doit tourner (http://127.0.0.1:8188, C:\\AI\\Lancer_ComfyUI.bat) pour up (méthode ai) et mask ; carte partagée :
SDXL ≈ 7 Go de VRAM, une tuile ≈ 6 s.
"""
import io
import json
import os
import sys
import time
import urllib.request
import uuid

import numpy as np
from PIL import Image, ImageFilter

HOST = "127.0.0.1:8188"
NEG = "text, watermark, logo, signature, blurry, jpeg artifacts, noise, photo, realistic, 3d render, frame, border"


def _api(path, data=None, raw=False):
    req = urllib.request.Request("http://%s%s" % (HOST, path))
    if data is not None:
        req.data = json.dumps(data).encode()
        req.add_header("Content-Type", "application/json")
    with urllib.request.urlopen(req, timeout=120) as r:
        body = r.read()
    return body if raw else json.loads(body)


def _upload(img, name):
    buf = io.BytesIO()
    img.save(buf, "PNG")
    boundary = uuid.uuid4().hex
    body = (("--%s\r\nContent-Disposition: form-data; name=\"image\"; filename=\"%s\"\r\n"
             "Content-Type: image/png\r\n\r\n") % (boundary, name)).encode() + buf.getvalue() + \
        ("\r\n--%s\r\nContent-Disposition: form-data; name=\"overwrite\"\r\n\r\ntrue\r\n--%s--\r\n" % (boundary, boundary)).encode()
    req = urllib.request.Request("http://%s/upload/image" % HOST, data=body)
    req.add_header("Content-Type", "multipart/form-data; boundary=%s" % boundary)
    with urllib.request.urlopen(req, timeout=120) as r:
        return json.loads(r.read())["name"]


def img2img(img, prompt, denoise=0.3, seed=7, lora=0.5, mask=None, steps=24):
    """SDXL + LoRA eden_style (image vers image) ; [mask] (L, blanc = repeint) limite le débruitage à la zone."""
    name = _upload(img.convert("RGB"), "chr2_in_%s.png" % uuid.uuid4().hex[:8])
    wf = {
        "1": {"class_type": "CheckpointLoaderSimple", "inputs": {"ckpt_name": "sd_xl_base_1.0.safetensors"}},
        "2": {"class_type": "LoraLoader", "inputs": {"model": ["1", 0], "clip": ["1", 1], "lora_name": "eden_style_v0b.safetensors",
                                                      "strength_model": lora, "strength_clip": lora}},
        "3": {"class_type": "CLIPTextEncode", "inputs": {"text": "edenstyle, " + prompt, "clip": ["2", 1]}},
        "4": {"class_type": "CLIPTextEncode", "inputs": {"text": NEG, "clip": ["2", 1]}},
        "5": {"class_type": "LoadImage", "inputs": {"image": name}},
        "6": {"class_type": "VAEEncode", "inputs": {"pixels": ["5", 0], "vae": ["1", 2]}},
        "7": {"class_type": "KSampler", "inputs": {"model": ["2", 0], "positive": ["3", 0], "negative": ["4", 0], "latent_image": ["6", 0],
                                                   "seed": seed, "steps": steps, "cfg": 6.0, "sampler_name": "dpmpp_2m", "scheduler": "karras",
                                                   "denoise": denoise}},
        "8": {"class_type": "VAEDecode", "inputs": {"samples": ["7", 0], "vae": ["1", 2]}},
        "9": {"class_type": "SaveImage", "inputs": {"images": ["8", 0], "filename_prefix": "chr2/tex"}},
    }
    if mask is not None:
        mname = _upload(mask.convert("RGB"), "chr2_mask_%s.png" % uuid.uuid4().hex[:8])
        wf["10"] = {"class_type": "LoadImage", "inputs": {"image": mname}}
        wf["11"] = {"class_type": "ImageToMask", "inputs": {"image": ["10", 0], "channel": "red"}}
        wf["12"] = {"class_type": "SetLatentNoiseMask", "inputs": {"samples": ["6", 0], "mask": ["11", 0]}}
        wf["7"]["inputs"]["latent_image"] = ["12", 0]
    pid = _api("/prompt", {"prompt": wf, "client_id": "chr2"})["prompt_id"]
    t0 = time.time()
    while True:
        h = _api("/history/" + pid)
        if pid in h and h[pid].get("outputs"):
            out = h[pid]["outputs"]["9"]["images"][0]
            data = _api("/view?filename=%s&subfolder=%s&type=output" % (out["filename"], out["subfolder"]), raw=True)
            res = Image.open(io.BytesIO(data)).convert("RGB")
            print("  img2img %dx%d débruitage %.2f : %.1f s" % (img.width, img.height, denoise, time.time() - t0))
            return res
        if pid in h and h[pid].get("status", {}).get("status_str") == "error":
            raise SystemExit("ComfyUI : erreur " + json.dumps(h[pid]["status"])[:400])
        if time.time() - t0 > 600:
            raise SystemExit("ComfyUI : trop long")
        time.sleep(0.5)


def lanczos(img, scale):
    return img.resize((img.width * scale, img.height * scale), Image.LANCZOS)


def lines(src, up, scale, dark=0.30, soft=0.10):
    """Traits sombres de [src] redessinés nets à l'échelle de [up] : luminance agrandie (bicubique), lissée, seuil doux."""
    lum = np.asarray(src.convert("L").resize(up.size, Image.BICUBIC).filter(ImageFilter.GaussianBlur(scale * 0.35)), np.float32) / 255.0
    a = np.clip((dark + soft - lum) / (2 * soft), 0.0, 1.0)  # 1 = trait
    # couleur du trait : la plus sombre du voisinage dans la source (pas de noir pur sur une peau)
    col = np.asarray(src.convert("RGB").filter(ImageFilter.MinFilter(3)).resize(up.size, Image.NEAREST), np.float32)
    base = np.asarray(up.convert("RGB"), np.float32)
    out = base * (1 - a[..., None]) + np.minimum(base, col) * a[..., None]
    res = Image.fromarray(np.clip(out, 0, 255).astype(np.uint8))
    if up.mode == "RGBA":
        res.putalpha(up.getchannel("A"))
    return res


def ai_upscale(src, scale, prompt, denoise, tile=1024, overlap=128, seed=7):
    """×scale (Lanczos) puis SDXL image vers image par tuiles avec fondu ; l'alpha d'origine est gardé."""
    up = lanczos(src.convert("RGBA"), scale)
    rgb = up.convert("RGB")
    W, H = rgb.size
    acc = np.zeros((H, W, 3), np.float32)
    wsum = np.zeros((H, W, 1), np.float32)
    step = tile - overlap
    ys = list(range(0, max(H - tile, 0) + 1, step)) or [0]
    xs = list(range(0, max(W - tile, 0) + 1, step)) or [0]
    if ys[-1] + tile < H:
        ys.append(H - tile)
    if xs[-1] + tile < W:
        xs.append(W - tile)
    ramp = np.minimum(np.arange(tile) + 1, overlap) / overlap
    ramp = np.minimum(ramp, ramp[::-1])
    wtile = np.outer(ramp, ramp)[..., None].astype(np.float32)
    for y in ys:
        for x in xs:
            crop = rgb.crop((x, y, x + tile, y + tile))
            res = img2img(crop, prompt, denoise, seed)
            acc[y:y + tile, x:x + tile] += np.asarray(res, np.float32) * wtile
            wsum[y:y + tile, x:x + tile] += wtile
    out = Image.fromarray(np.clip(acc / np.maximum(wsum, 1e-6), 0, 255).astype(np.uint8))
    out.putalpha(up.getchannel("A"))
    return out


def mask_paint(src, mask_img, channel, prompt, denoise=0.55, seed=11, scale=1):
    """Repeint seulement les pixels du canal [channel] du masque d'Eden (îles d'une matière) ; le reste est gardé."""
    base = lanczos(src.convert("RGBA"), scale) if scale > 1 else src.convert("RGBA")
    m = mask_img.convert("RGB").resize(base.size, Image.NEAREST)
    ch = np.asarray(m, np.float32)[..., "rgb".index(channel)] / 255.0
    hard = Image.fromarray((ch > 0.5).astype(np.uint8) * 255)
    soft = hard.filter(ImageFilter.MaxFilter(5)).filter(ImageFilter.GaussianBlur(2))
    work = base.convert("RGB")
    size = 1024
    big = work.resize((size, size), Image.LANCZOS)
    res = img2img(big, prompt, denoise, seed, mask=hard.filter(ImageFilter.MaxFilter(9)).resize((size, size)))
    res = res.resize(base.size, Image.LANCZOS)
    a = np.asarray(soft, np.float32)[..., None] / 255.0
    out = np.asarray(work, np.float32) * (1 - a) + np.asarray(res, np.float32) * a
    img = Image.fromarray(np.clip(out, 0, 255).astype(np.uint8))
    img.putalpha(base.getchannel("A"))
    return img


def stroke(img, a, b, width, col):
    """Trait au pinceau effilé (comme ClassLook._stroke, à n'importe quelle échelle), numpy."""
    arr = np.asarray(img, np.float32).copy()
    a, b = np.array(a, np.float32), np.array(b, np.float32)
    x0, y0 = np.floor(np.minimum(a, b) - width - 2).astype(int)
    x1, y1 = np.ceil(np.maximum(a, b) + width + 2).astype(int)
    x0, y0 = max(x0, 0), max(y0, 0)
    x1, y1 = min(x1, arr.shape[1]), min(y1, arr.shape[0])
    yy, xx = np.mgrid[y0:y1, x0:x1].astype(np.float32) + 0.5
    ab = b - a
    t = np.clip(((xx - a[0]) * ab[0] + (yy - a[1]) * ab[1]) / max(ab.dot(ab), 1e-4), 0, 1)
    d = np.hypot(xx - (a[0] + ab[0] * t), yy - (a[1] + ab[1] * t))
    w = width * 0.5 * (0.35 + 0.65 * np.sin(t * np.pi))
    cover = np.clip(w + 0.6 * width / 5.0 - d, 0, 1)[..., None] * 0.9
    reg = arr[y0:y1, x0:x1, :3]
    arr[y0:y1, x0:x1, :3] = reg * (1 - cover) + np.array(col, np.float32)[:3] * cover
    return Image.fromarray(arr.clip(0, 255).astype(np.uint8), img.mode)


def face_marks(src, marks, ref=512):
    """Traits du visage (repère [ref] px, liste [x0, y0, x1, y1, épaisseur]) peints à la taille de [src]."""
    k = src.width / float(ref)
    img = src.convert("RGBA")
    for ln in marks.get("lines", []):
        img = stroke(img, (ln[0] * k, ln[1] * k), (ln[2] * k, ln[3] * k), ln[4] * k, marks.get("color", [90, 60, 50]))
    return img


def hair_texture(size, root, tip, seed=3):
    """Cheveux : dégradé racine -> pointe le long de v (lignes de l'image), mèches fines (bandes le long de v), reflet
    toon en bande, contour sombre sur les bords de la mèche (u près de 0 / 1 / 0,5 : arêtes de la section)."""
    rng = np.random.default_rng(seed)
    h, w = size
    v = np.linspace(0, 1, h)[:, None]
    u = np.linspace(0, 1, w)[None, :]
    root, tip = np.array(root, np.float32), np.array(tip, np.float32)
    base = root[None, None, :] * (1 - v[..., None] ** 0.7) + tip[None, None, :] * (v[..., None] ** 0.7)
    strands = np.zeros((1, w), np.float32)
    for f in (7, 13, 29, 53):
        strands += np.sin(u * f * 2 * np.pi + rng.uniform(0, 6.28)) * (0.5 / f ** 0.3)
    shade = 1.0 + 0.10 * strands
    band = np.exp(-((v - 0.42) / 0.07) ** 2) * (0.55 + 0.45 * np.cos(u * 4 * np.pi) ** 2)  # reflet toon
    edge = np.minimum(np.minimum(np.abs(u - 0.0), np.abs(u - 1.0)), np.abs(u - 0.5))
    rim = np.clip(1.0 - edge / 0.05, 0, 1) * 0.22
    col = base * shade[..., None] + 255 * 0.22 * band[..., None]
    col = col * (1 - rim[..., None])
    a = np.full((h, w, 1), 255, np.float32)
    return Image.fromarray(np.concatenate([col, a], 2).clip(0, 255).astype(np.uint8), "RGBA")


def band_texture(size, cloth, metal, seed=5):
    """Bandeau : moitié haute = étoffe (tissage, piqûres aux bords), moitié basse = plaque de métal lisse (dégradé,
    liseré clair au biseau, aucun symbole)."""
    rng = np.random.default_rng(seed)
    n = size
    img = np.zeros((n, n, 3), np.float32)
    yy, xx = np.mgrid[0:n, 0:n].astype(np.float32)
    top = yy < n / 2
    weave = (np.sin(xx * 2 * np.pi / 6) * np.sin(yy * 2 * np.pi / 6)) * 0.06 + rng.normal(0, 0.02, (n, n))
    cl = np.array(cloth, np.float32)
    ty = yy / (n / 2)
    stitch = ((np.abs(ty - 0.10) < 0.012) | (np.abs(ty - 0.90) < 0.012)) & ((xx // 10) % 2 == 0)
    cloth_img = cl * (1 + weave)[..., None] * (0.85 + 0.15 * np.sin(np.clip(ty, 0, 1) * np.pi))[..., None]
    cloth_img[stitch] = cl * 1.8
    mt = np.array(metal, np.float32)
    my = (yy - n / 2) / (n / 2)
    mx = xx / n
    grad = 0.75 + 0.45 * (1 - my) * (0.6 + 0.4 * np.cos((mx - 0.35) * 3.0))
    bevel = np.minimum(np.minimum(mx - 0.05, 0.95 - mx) * 9, np.minimum(my - 0.10, 0.90 - my) * 9)
    rim = np.clip(1 - np.abs(bevel) * 3, 0, 1)
    metal_img = mt * grad[..., None] + 255 * 0.35 * rim[..., None]
    img = np.where(top[..., None], cloth_img, metal_img)
    a = np.full((n, n, 1), 255, np.float32)
    return Image.fromarray(np.concatenate([img, a], 2).clip(0, 255).astype(np.uint8), "RGBA")


def main():
    a = sys.argv[1:]
    opt = {}
    pos = []
    i = 0
    while i < len(a):
        if a[i].startswith("--"):
            opt[a[i][2:]] = a[i + 1]
            i += 2
        else:
            pos.append(a[i])
            i += 1
    cmd = pos[0]
    if cmd == "up":
        src = Image.open(pos[1]).convert("RGBA")
        out = pos[2]
        os.makedirs(out, exist_ok=True)
        base = os.path.splitext(os.path.basename(pos[1]))[0]
        sc = int(opt.get("scale", 4))
        lz = lanczos(src, sc)
        lz.save(os.path.join(out, base + "_lanczos.png"))
        lines(src, lz, sc).save(os.path.join(out, base + "_lines.png"))
        if opt.get("ai", "1") != "0":
            ai = ai_upscale(src, sc, opt.get("prompt", "anime game texture, hand painted, clean"), float(opt.get("denoise", 0.3)))
            ai.save(os.path.join(out, base + "_ai_raw.png"))
            lines(src, ai, sc).save(os.path.join(out, base + "_ai.png"))
    elif cmd == "mask":
        src = Image.open(pos[1])
        img = mask_paint(src, Image.open(pos[2]), pos[3], opt.get("prompt", ""), float(opt.get("denoise", 0.55)),
                         int(opt.get("seed", 11)), int(opt.get("scale", 1)))
        img.save(pos[4])
    elif cmd == "face":  # face <visage 2048> <look.json> <sortie>
        look = json.load(open(pos[2], encoding="utf-8"))
        face_marks(Image.open(pos[1]), look.get("face_marks", {})).save(pos[3])
    elif cmd == "hair":  # hair <look.json> <sortie>
        look = json.load(open(pos[1], encoding="utf-8"))["hair"]
        hair_texture((1024, 256), look["root"], look["tip"]).save(pos[2])
    elif cmd == "band":  # band <look.json> <sortie>
        look = json.load(open(pos[1], encoding="utf-8"))["band"]
        band_texture(1024, look["cloth"], look["metal"]).save(pos[2])
    elif cmd == "lines":
        src = Image.open(pos[1]).convert("RGBA")
        sc = int(opt.get("scale", 4))
        lines(src, lanczos(src, sc), sc).save(pos[2])


if __name__ == "__main__":
    main()
