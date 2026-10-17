#!/usr/bin/env python3
"""Lot PRP-1 : chaîne « idée -> image -> objet 3D -> nettoyage Blender -> GLB + fiche » (armes et ailes de dos).

Prérequis (hors dépôt) : ComfyUI lancé (C:\\AI\\Lancer_ComfyUI.bat, http://127.0.0.1:8188) avec SDXL base 1.0, le LoRA
eden_style_v0b et les modèles Pixal3D (voir conception/art/g1_test/LISEZMOI.md) ; Blender 5.2 ; le venv C:\\AI\\venv_comfy
(Pillow, numpy, scipy). Tout est reprenable : une étape déjà faite n'est pas refaite (--force pour la refaire).

  C:\\AI\\venv_comfy\\Scripts\\python.exe tools/art/prp_pipeline.py images  [--only id,id]   # 4 graines par objet + détourage
  ...                                         mesh    [--only id,id]   # Pixal3D sur la graine retenue -> GLB brut (150 000 faces)
  ...                                         clean   [--only id,id]   # Blender : retopo légère, repère de l'os, matériau, GLB + fiche
  ...                                         godot                    # contrôle d'import et rendu sur le héros (Godot 4.7, projet de brouillon)
  ...                                         sheet                    # planche de contact conception/art/prp/planche.jpg
  ...                                         all     [--only id,id]   # tout à la suite

Fiches des objets (prompt, type, rareté, dimensions par type) : tools/art/prp_assets.json. Sorties brutes : C:\\AI\\prp1_raw
(images, GLB bruts, rendus, journal mesures.jsonl) ; sorties du dépôt : conception/art/prp/candidats/<id>.glb + <id>.json,
conception/art/prp/planche.jpg, conception/art/prp/mesures.json. Procédure et pièges : conception/art/PRP.md.
"""
import argparse
import json
import os
import shutil
import subprocess
import sys
import threading
import time

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import comfy_gen  # noqa: E402
import gen_with_lora as gl  # noqa: E402

ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
RAW = r"C:\AI\prp1_raw"
OUT = os.path.join(ROOT, "conception", "art", "prp")
CAND = os.path.join(OUT, "candidats")
ASSETS = os.path.join(HERE, "prp_assets.json")
BLENDER = r"C:\Program Files\Blender Foundation\Blender 5.2\blender.exe"
GODOT = r"C:\Users\Nico\Godot\Godot_v4.7.2-stable_win64_console.exe"
HOST = "127.0.0.1:8188"

# --- image (SDXL base 1.0 + LoRA maison) -------------------------------------------------------------------------
LORA, STRENGTH, STEPS, CFG = "eden_style_v0b.safetensors", 0.5, 30, 6.5
SEEDS = [101, 102, 103, 104]
STYLE = ("centered, whole object visible, front view, orthographic, plain light grey background, game asset, "
         "vivid saturated candy colors, toon shading, clean dark outlines, simple readable shapes")
NEG = ("person, hand, character, holding, multiple objects, two swords, many weapons, collection, cropped, cut off, "
       "perspective, tilted, diagonal, shadow, floor, pedestal, text, letters, watermark, logo, frame, border, photo, "
       "photorealistic, blurry, lowres, jpeg artifacts, dark, gloomy, black background, ugly, deformed")
SIZE = {"weapon": (832, 1216), "back": (1216, 832)}
LEAD = {"weapon": "edenstyle, (single object:1.3), vertical, pointing straight up, ",
        "back": "edenstyle, (single object:1.2), "}

# --- 3D (Pixal3D, workflow G1) -------------------------------------------------------------------------------------
UPSAMPLE = {"weapon": 1536, "back": 1024}  # objets fins : 1536 (G1) ; ailes = grandes surfaces : 1024 (VRAM)
BUDGET = {"weapon": 8000, "back": 12000}   # triangles au plus (mission)
MAX_KB = 1536                              # poids d'un GLB au plus


def load_assets(only=None):
    with open(ASSETS, encoding="utf-8") as f:
        data = json.load(f)
    assets = data["assets"]
    if only:
        keep = set(only.split(","))
        assets = [a for a in assets if a["id"] in keep]
    return data["types"], assets


def log_measure(entry):
    os.makedirs(RAW, exist_ok=True)
    entry["quand"] = time.strftime("%Y-%m-%d %H:%M:%S")
    with open(os.path.join(RAW, "mesures.jsonl"), "a", encoding="utf-8") as f:
        f.write(json.dumps(entry, ensure_ascii=False) + "\n")


class VramWatch:
    """Relève la mémoire de la carte (nvidia-smi, toutes les secondes) pendant une étape : avant, au plus haut."""

    def __init__(self):
        self.peak = self.before = self._read()
        self._stop = False
        self._t = threading.Thread(target=self._loop, daemon=True)

    @staticmethod
    def _read():
        try:
            out = subprocess.run(["nvidia-smi", "--query-gpu=memory.used,memory.total", "--format=csv,noheader,nounits"],
                                 capture_output=True, text=True, timeout=10).stdout.split(",")
            return int(out[0])
        except (OSError, ValueError, IndexError, subprocess.TimeoutExpired):
            return 0

    def _loop(self):
        while not self._stop:
            self.peak = max(self.peak, self._read())
            time.sleep(1.0)

    def __enter__(self):
        self._t.start()
        return self

    def __exit__(self, *exc):
        self._stop = True
        self._t.join(timeout=5)

    def info(self):
        return {"vram_carte_avant_go": round(self.before / 1024, 2), "vram_carte_max_go": round(self.peak / 1024, 2)}


# ---------------------------------------------------------------------------------------------------------------------
# 1. Images
# ---------------------------------------------------------------------------------------------------------------------
def isolate(src, dst, kind):
    """Garde l'objet principal (fond uni) et le recentre sur un fond gris clair carré. Renvoie un score et des drapeaux.

    SDXL dessine souvent 2 ou 3 armes côte à côte malgré le prompt : on garde la plus grande composante proche du centre
    (armes) ou toutes les grandes composantes (ailes : deux moitiés séparées)."""
    import numpy as np
    from PIL import Image
    from scipy import ndimage
    im = np.asarray(Image.open(src).convert("RGB")).astype(np.int16)
    h, w, _ = im.shape
    # fond : souvent un dégradé vertical (SDXL) -> une couleur de fond par ligne (bords gauche et droit), lissée
    sides = np.concatenate([im[:, :12], im[:, -12:]], axis=1)
    bg_rows = ndimage.median_filter(np.median(sides, axis=1), size=(31, 1))
    diff = np.abs(im - bg_rows[:, None, :]).max(axis=2)
    # un fond gris un peu plus sombre au centre (vignettage) n'est pas l'objet : gris peu saturé et proche en clarté
    mx, mn = im.max(axis=2), im.min(axis=2)
    sat = (mx - mn) / np.maximum(mx, 1)
    dl = np.abs(im.mean(axis=2) - bg_rows.mean(axis=1)[:, None])
    mask = (diff > 22) & ((sat > 0.12) | (dl > 45))
    strict = mask
    mask = ndimage.binary_closing(mask, iterations=3)
    mask = ndimage.binary_fill_holes(mask)
    # trous de l'objet (anneau, garde ajourée) : le fond qu'on y voit reste du fond, sinon Pixal3D en fait un disque gris
    holes, nh = ndimage.label(mask & ~ndimage.binary_dilation(strict, iterations=2))
    if nh:
        sizes = ndimage.sum(np.ones_like(holes), holes, range(1, nh + 1))
        big_holes = [i + 1 for i, a in enumerate(sizes) if a > 300]
        mask &= ~ndimage.binary_dilation(np.isin(holes, big_holes), iterations=1)
    mask = ndimage.binary_opening(mask, iterations=2)
    lab, n = ndimage.label(mask)
    if n == 0:
        return {"ok": False, "raison": "aucun objet"}
    areas = ndimage.sum(mask, lab, range(1, n + 1))
    boxes = ndimage.find_objects(lab)
    comps = []
    for i, (a, sl) in enumerate(zip(areas, boxes)):
        cy, cx = (sl[0].start + sl[0].stop) / 2, (sl[1].start + sl[1].stop) / 2
        comps.append({"i": i + 1, "a": float(a), "sl": sl, "dc": abs(cx - w / 2) / w + abs(cy - h / 2) / h})
    big = max(c["a"] for c in comps)
    if kind == "weapon":
        cand = [c for c in comps if c["a"] > 0.25 * big]
        main = min(cand, key=lambda c: c["dc"] - c["a"] / big * 0.3)
        y0, y1, x0, x1 = main["sl"][0].start, main["sl"][0].stop, main["sl"][1].start, main["sl"][1].stop
        keep = [main["i"]]
        # petits morceaux collés à l'arme (gemme presque détachée) : à moins de 6 px ; les éclats, pétales et feuilles
        # qui flottent autour sont retirés (Pixal3D en ferait des miettes)
        near = ndimage.binary_dilation(lab == main["i"], iterations=6)
        for c in comps:
            if c["i"] != main["i"] and c["a"] < 0.2 * main["a"] and near[lab == c["i"]].any():
                keep.append(c["i"])
        others = len([c for c in comps if c["a"] > 0.25 * big]) - 1
    else:
        keep = [c["i"] for c in comps if c["a"] > 0.08 * big]
        others = 0
    sel = np.isin(lab, keep)
    ys, xs = np.nonzero(sel)
    y0, y1, x0, x1 = ys.min(), ys.max() + 1, xs.min(), xs.max() + 1
    touches = y0 <= 2 or x0 <= 2 or y1 >= h - 2 or x1 >= w - 2
    bh, bw = y1 - y0, x1 - x0
    side = int(max(bh, bw) * 1.15)
    canvas = np.empty((side, side, 3), np.uint8)
    canvas[:] = (205, 205, 205)
    crop = im[y0:y1, x0:x1].astype(np.uint8)
    m = sel[y0:y1, x0:x1]
    oy, ox = (side - bh) // 2, (side - bw) // 2
    region = canvas[oy:oy + bh, ox:ox + bw]
    region[m] = crop[m]
    alpha = np.zeros((side, side), np.uint8)
    alpha[oy:oy + bh, ox:ox + bw][m] = 255
    rgba = np.dstack([canvas, alpha])
    # RGBA : la couche alpha EST le masque donné à Pixal3D (pas de BiRefNet, qui bouchait les trous d'un anneau)
    Image.fromarray(rgba, "RGBA").resize((1024, 1024), Image.LANCZOS).save(dst)
    aspect = bh / max(bw, 1)
    fill = float(sel.sum()) / (h * w)
    score = 1.0 - 0.5 * touches - 0.15 * others + min(fill * 4, 0.4)
    if kind == "weapon":
        score += 0.3 if aspect > 2.2 else 0.0
    else:
        score += 0.3 if 1.1 < (bw / max(bh, 1)) < 2.6 else 0.0
    return {"ok": not touches, "score": round(score, 3), "coupe": bool(touches), "autres_objets": others,
            "rapport_h_l": round(aspect, 2), "remplissage": round(fill, 3)}


def flat(path, bg=(205, 205, 205)):
    """Image RGB (une image RGBA détourée est posée sur le gris du fond)."""
    from PIL import Image
    im = Image.open(path)
    if im.mode == "RGBA":
        base = Image.new("RGB", im.size, bg)
        base.paste(im, mask=im.split()[3])
        return base
    return im.convert("RGB")


def step_images(types, assets, force=False):
    from PIL import Image
    d = os.path.join(RAW, "img")
    os.makedirs(d, exist_ok=True)
    for a in assets:
        kind = a["emplacement"]
        w, h = SIZE[kind]
        prompt = LEAD[kind] + a["prompt"] + ", " + STYLE
        results = {}
        for seed in a.get("graines", SEEDS):
            name = f"{a['id']}_s{seed}"
            raw = os.path.join(d, name + ".png")
            if force or not os.path.isfile(raw):
                neg = NEG + (", " + a["negatif"] if a.get("negatif") else "")
                wf = gl.build(LORA, STRENGTH, prompt, neg, seed, w, h, STEPS, CFG, "prp1/" + name, None)
                with VramWatch() as vw:
                    path, dt = gl.run(HOST, wf, d, name, 900)
                log_measure({"etape": "image", "id": a["id"], "graine": seed, "secondes": dt, **vw.info()})
                print(f"[image] {name} {dt} s", flush=True)
            results[seed] = isolate(raw, os.path.join(d, name + "_iso.png"), kind)
        with open(os.path.join(d, a["id"] + "_variantes.json"), "w", encoding="utf-8") as f:
            json.dump({str(k): v for k, v in results.items()}, f, ensure_ascii=False, indent=1)
        # planche des variantes : brute au-dessus, détourée au-dessous
        seeds = list(results)
        sheet = Image.new("RGB", (256 * len(seeds), 512 + 24), (30, 28, 40))
        for i, s in enumerate(seeds):
            for j, suf in enumerate(("", "_iso")):
                im = flat(os.path.join(d, f"{a['id']}_s{s}{suf}.png"))
                im.thumbnail((256, 256))
                sheet.paste(im, (256 * i + (256 - im.width) // 2, 24 + 256 * j))
            from PIL import ImageDraw
            r = results[s]
            ImageDraw.Draw(sheet).text((256 * i + 6, 4), f"{s} score {r.get('score', 0)}{' COUPÉ' if r.get('coupe') else ''}",
                                       fill=(240, 220, 150))
        sheet.save(os.path.join(d, f"var_{a['id']}.jpg"), quality=85)


def chosen_seed(a):
    if a.get("graine"):
        return int(a["graine"])
    p = os.path.join(RAW, "img", a["id"] + "_variantes.json")
    with open(p, encoding="utf-8") as f:
        res = json.load(f)
    ok = {k: v for k, v in res.items() if v.get("ok")} or res
    return int(max(ok, key=lambda k: ok[k].get("score", 0)))


# ---------------------------------------------------------------------------------------------------------------------
# 2. Objet 3D (Pixal3D)
# ---------------------------------------------------------------------------------------------------------------------
def step_mesh(types, assets, force=False):
    d = os.path.join(RAW, "mesh")
    os.makedirs(d, exist_ok=True)
    for a in assets:
        seed = chosen_seed(a)
        dst = os.path.join(d, a["id"] + "_hi.glb")
        if os.path.isfile(dst) and not force:
            continue
        img = os.path.join(RAW, "img", f"{a['id']}_s{seed}_iso.png")
        kind = a["emplacement"]
        job = {"name": "prp1_" + a["id"], "image": img, "seed": int(a.get("graine_3d", 56)),
               "set": [f"94.target_resolution={a.get('upsample', UPSAMPLE[kind])}"]}
        wf = comfy_gen.apply_job(comfy_gen.load_workflow("image_to_3d_pixal3d"), job, HOST)
        # masque = alpha de notre détourage (LoadImage rend 1 - alpha : on l'inverse) au lieu du détourage BiRefNet
        wf["950"] = {"class_type": "InvertMask", "inputs": {"mask": ["122", 1]}, "_meta": {"title": "alpha"}}
        wf["312"]["inputs"]["masks"] = ["950", 0]
        wf.pop("192", None)
        wf.pop("193", None)
        t0 = time.time()
        with VramWatch() as vw:
            pid = comfy_gen.api(HOST, "/prompt", {"prompt": wf, "client_id": "eden-prp1"})["prompt_id"]
            hist = comfy_gen.wait_result(HOST, pid, 3600)
        dt = round(time.time() - t0, 1)
        files = comfy_gen.fetch_outputs(HOST, hist, d, a["id"] + "_hi")
        glb = [f for f in files if f.lower().endswith(".glb")]
        if glb and glb[0] != dst:
            shutil.move(glb[0], dst)
        log_measure({"etape": "3d", "id": a["id"], "graine_image": seed, "secondes": dt, **vw.info(),
                     "upsample": a.get("upsample", UPSAMPLE[kind])})
        print(f"[3d] {a['id']} {dt} s, VRAM max {vw.info()['vram_carte_max_go']} Go", flush=True)


# ---------------------------------------------------------------------------------------------------------------------
# 3. Nettoyage Blender
# ---------------------------------------------------------------------------------------------------------------------
def step_clean(types, assets, force=False):
    os.makedirs(CAND, exist_ok=True)
    rd = os.path.join(RAW, "render")
    os.makedirs(rd, exist_ok=True)
    for a in assets:
        dst = os.path.join(CAND, a["id"] + ".glb")
        if os.path.isfile(dst) and not force:
            continue
        kind = a["emplacement"]
        t = types[a["type"]]
        params = {"src": os.path.join(RAW, "mesh", a["id"] + "_hi.glb"), "dst": dst, "kind": kind, "type": a["type"],
                  "tri_max": int(a.get("triangles", BUDGET[kind]) * 0.96), "tex": int(a.get("texture", 1024)),
                  "max_kb": MAX_KB, "render_dir": rd, "id": a["id"],
                  "metrics": os.path.join(rd, a["id"] + "_metrics.json")}
        if kind == "weapon":
            params.update({"length": t["longueur"], "grip": t["prise"], "w1": t["w1"], "w2": t["w2"]})
        else:
            params.update({"span": a.get("envergure", t["envergure"])})
        pj = os.path.join(rd, a["id"] + "_params.json")
        with open(pj, "w", encoding="utf-8") as f:
            json.dump(params, f, ensure_ascii=False, indent=1)
        t0 = time.time()
        r = subprocess.run([BLENDER, "--background", "--factory-startup", "--python", os.path.join(HERE, "prp_blender.py"),
                            "--", pj], capture_output=True, text=True, encoding="utf-8", errors="replace")
        dt = round(time.time() - t0, 1)
        lines = [ln for ln in r.stdout.splitlines() if ln.startswith("[prp]")]
        print("\n".join(lines), flush=True)
        if r.returncode != 0 or not os.path.isfile(params["metrics"]):
            print(r.stdout[-3000:], r.stderr[-3000:])
            raise SystemExit(f"Blender a échoué pour {a['id']}")
        with open(params["metrics"], encoding="utf-8") as f:
            met = json.load(f)
        met["secondes_blender"] = dt
        write_card(a, t, met)
        log_measure({"etape": "blender", "id": a["id"], "secondes": dt, "triangles": met["triangles"],
                     "ko": met["ko"], "verdict": met["verdict"]})


RARITY = ["Commun", "Spécial", "Rare", "Épique", "Mythique", "Légendaire"]


def write_card(a, t, met):
    """Fiche JSON à côté du GLB : de quoi l'ajouter au jeu sans rouvrir le pipeline."""
    seed = chosen_seed(a)
    card = {
        "id": a["id"], "nom": a["nom"], "emplacement": a["emplacement"],
        "emplacement_nom": "Arme (apparence)" if a["emplacement"] == "weapon" else "Dos",
        "type_arme": a["type"] if a["emplacement"] == "weapon" else "",
        "type_nom": t["nom"], "rarete": a["rarete"], "rarete_nom": RARITY[a["rarete"]],
        "fichier": a["id"] + ".glb",
        "accroche": {"os": t["os"], "repere": "repère de l'os ; nœud EdenRoot remis à l'identité au chargement (EdenModel)",
                     "traine": "nœuds W1 (base de la lame) et W2 (pointe)" if a["emplacement"] == "weapon" else ""},
        "mesures": {k: met[k] for k in ("triangles", "sommets", "ko", "dimensions", "texture", "composantes",
                                         "aretes_non_manifold", "verdict", "remarques") if k in met},
        "source": {"image": "SDXL base 1.0 + LoRA eden_style_v0b à %.1f" % STRENGTH, "graine_image": seed,
                   "prompt": a["prompt"], "objet_3d": "Pixal3D (ComfyUI, workflow image_to_3d_pixal3d)",
                   "nettoyage": "tools/art/prp_blender.py"},
        "licence": "généré pour Eden Slash (SDXL CreativeML Open RAIL++-M, Pixal3D / TRELLIS.2 MIT) ; aucun modèle ni texture tiers",
    }
    with open(os.path.join(CAND, a["id"] + ".json"), "w", encoding="utf-8") as f:
        json.dump(card, f, ensure_ascii=False, indent=1)


# ---------------------------------------------------------------------------------------------------------------------
# 4. Contrôle dans Godot (projet de brouillon : import réel, accroche comme EdenModel, rendu toon du jeu)
# ---------------------------------------------------------------------------------------------------------------------
GPROJ = r"C:\AI\prp1_godot"


def step_godot(types, assets, force=False):
    game = os.path.join(ROOT, "game")
    os.makedirs(os.path.join(GPROJ, "cand"), exist_ok=True)
    os.makedirs(os.path.join(GPROJ, "body"), exist_ok=True)
    os.makedirs(os.path.join(GPROJ, "shaders"), exist_ok=True)
    # projet minimal : corps du héros par défaut et shaders du jeu copiés hors du dépôt (rien n'est écrit dans game/)
    for src, sub in (("assets/player/body/body_m.glb", "body"), ("shaders/eden_character.gdshader", "shaders"),
                     ("shaders/eden_light.gdshaderinc", "shaders")):
        s = os.path.join(game, src)
        dd = os.path.join(GPROJ, sub, os.path.basename(src))
        if not os.path.isfile(dd) or os.path.getmtime(dd) < os.path.getmtime(s):
            shutil.copy2(s, dd)
    # textures du corps (chemins relatifs ../textures/ dans le GLB)
    import struct
    with open(os.path.join(game, "assets/player/body/body_m.glb"), "rb") as f:
        b = f.read()
    gltf = json.loads(b[20:20 + struct.unpack("<I", b[12:16])[0]])
    os.makedirs(os.path.join(GPROJ, "textures"), exist_ok=True)
    for im in gltf.get("images", []):
        if "uri" in im:
            shutil.copy2(os.path.normpath(os.path.join(game, "assets/player/body", im["uri"])),
                         os.path.join(GPROJ, "textures", os.path.basename(im["uri"])))
    for a in assets:
        shutil.copy2(os.path.join(CAND, a["id"] + ".glb"), os.path.join(GPROJ, "cand", a["id"] + ".glb"))
    shutil.copy2(os.path.join(HERE, "godot", "prp_preview.gd"), os.path.join(GPROJ, "prp_preview.gd"))
    shutil.copy2(os.path.join(HERE, "godot", "prp_preview.tscn"), os.path.join(GPROJ, "prp_preview.tscn"))
    with open(os.path.join(GPROJ, "project.godot"), "w", encoding="utf-8") as f:
        f.write('config_version=5\n\n[application]\nconfig/name="prp1_apercu"\nrun/main_scene="res://prp_preview.tscn"\n'
                'config/use_custom_user_dir=true\nconfig/custom_user_dir_name="prp1_apercu"\n\n[display]\n'
                'window/size/viewport_width=512\nwindow/size/viewport_height=512\n\n[rendering]\n'
                'renderer/rendering_method="forward_plus"\n')
    jobs = [{"id": a["id"], "kind": a["emplacement"], "type": a["type"], "bone": types[a["type"]]["os"]} for a in assets]
    with open(os.path.join(GPROJ, "jobs.json"), "w", encoding="utf-8") as f:
        json.dump(jobs, f)
    t0 = time.time()
    r = subprocess.run([GODOT, "--headless", "--path", GPROJ, "--import"], capture_output=True, text=True,
                       encoding="utf-8", errors="replace", timeout=600)
    print(f"[godot] import {round(time.time() - t0, 1)} s, code {r.returncode}")
    out_dir = os.path.join(RAW, "render")
    os.makedirs(out_dir, exist_ok=True)
    r = subprocess.run([GODOT, "--path", GPROJ, "--resolution", "512x512", "--", "--out=" + out_dir],
                       capture_output=True, text=True, encoding="utf-8", errors="replace", timeout=900)
    lines = [ln for ln in r.stdout.splitlines() if ln.startswith("[prp]")]
    print("\n".join(lines) if lines else (r.stdout[-3000:] + r.stderr[-3000:]))
    with open(os.path.join(out_dir, "godot_controle.txt"), "w", encoding="utf-8") as f:
        f.write("\n".join(lines))


# ---------------------------------------------------------------------------------------------------------------------
# 5. Planche de contact et mesures
# ---------------------------------------------------------------------------------------------------------------------
def step_sheet(types, assets, force=False):
    from PIL import Image, ImageDraw, ImageFont
    rd = os.path.join(RAW, "render")
    cw, chh = 420, 470
    cols = 4
    rows = (len(assets) + cols - 1) // cols
    sheet = Image.new("RGB", (cw * cols, 56 + chh * rows), (34, 26, 58))
    d = ImageDraw.Draw(sheet)
    try:
        big = ImageFont.truetype("arialbd.ttf", 22)
        font = ImageFont.truetype("arialbd.ttf", 17)
        small = ImageFont.truetype("arial.ttf", 13)
    except OSError:
        big = font = small = ImageFont.load_default()
    d.text((14, 14), "PRP-1 : 8 apparences d'armes et 4 ailes de dos (candidats, rien dans le jeu)", fill=(255, 248, 236), font=big)
    colors = [(217, 212, 228), (143, 214, 46), (34, 184, 240), (196, 107, 245), (255, 138, 31), (255, 201, 40)]
    summary = []
    meas = {r["id"]: r for r in summarize(assets)}
    for i, a in enumerate(assets):
        x, y = cw * (i % cols), 56 + chh * (i // cols)
        with open(os.path.join(rd, a["id"] + "_metrics.json"), encoding="utf-8") as f:
            met = json.load(f)
        col = colors[a["rarete"]]
        d.rounded_rectangle((x + 6, y + 4, x + cw - 6, y + chh - 6), 14, fill=(255, 248, 236), outline=col, width=4)
        main = Image.open(os.path.join(rd, a["id"] + "_vue.png")).convert("RGB")
        main.thumbnail((290, 290))
        sheet.paste(main, (x + 14, y + 40))
        # colonne de droite : sur le héros (Godot), à la distance de la caméra du jeu, image source
        rx = x + cw - 126
        for k, (suffix, label, yy, size) in enumerate((("_godot.png", "sur le héros", 30, 112),
                                                      ("_distance.png", "taille réelle en jeu", 162, 112),
                                                      ("", "image source", 290, 52))):
            pth = os.path.join(rd, a["id"] + suffix) if suffix else                 os.path.join(RAW, "img", f"{a['id']}_s{chosen_seed(a)}_iso.png")
            if os.path.isfile(pth):
                im = flat(pth, (204, 222, 243))
                im.thumbnail((size, size))
                sheet.paste(im, (rx, y + yy + 16))
            d.text((rx, y + yy), label, fill=(110, 103, 135), font=small)
        d.text((x + 16, y + 12), a["nom"], fill=(34, 26, 58), font=font)
        d.text((x + cw - 16, y + 14), RARITY[a["rarete"]], fill=tuple(int(c * 0.7) for c in col), font=small, anchor="ra")
        t = types[a["type"]]
        verdict = met["verdict"]
        lines = [f"{t['nom']} · {met['triangles']} triangles · {met['ko']} Ko · texture {met['texture']}",
                 f"{met['dimensions'][0]:.2f} × {met['dimensions'][1]:.2f} × {met['dimensions'][2]:.2f} (repère de l'os)",
                 "Image %s s · 3D %s · VRAM %s Go · Blender %s s" % (
                     round(sum(i["secondes"] for i in meas.get(a["id"], {}).get("images", [])) /
                           len(meas[a["id"]]["images"]), 1) if meas.get(a["id"], {}).get("images") else "≈ 13",
                     fmt_min(meas.get(a["id"], {}).get("3d", {}).get("secondes")),
                     meas.get(a["id"], {}).get("3d", {}).get("vram_carte_max_go", "?"),
                     round(meas.get(a["id"], {}).get("blender", {}).get("secondes", 0))),
                 ("Contrôles OK" if verdict == "ok" else "À REVOIR : " + verdict) + (" · " + met["remarques"] if met.get("remarques") else ""),
                 a.get("avis", "")]
        for k, ln in enumerate(lines):
            color = (34, 26, 58) if k < 3 else ((62, 127, 10) if verdict == "ok" else (200, 40, 60)) if k == 3 else (11, 125, 181)
            d.text((x + 16, y + 350 + 18 * k), ln, fill=color, font=small)
        summary.append({"id": a["id"], **{k: met.get(k) for k in ("triangles", "ko", "verdict")}})
    out = os.path.join(OUT, "planche.jpg")
    q = 88
    while True:
        sheet.save(out, quality=q, optimize=True, progressive=True)
        if os.path.getsize(out) <= 500 * 1024 or q <= 50:
            break
        q -= 6
    print(f"[planche] {out} ({os.path.getsize(out) // 1024} Ko, qualité {q})")


def fmt_min(sec):
    if not sec:
        return "?"
    return f"{int(sec // 60)} min {int(sec % 60):02d}"


def summarize(assets):
    """conception/art/prp/mesures.json : une ligne par objet (temps, VRAM, triangles, poids, verdict)."""
    rows = {}
    p = os.path.join(RAW, "mesures.jsonl")
    if os.path.isfile(p):
        with open(p, encoding="utf-8") as f:
            for line in f:
                e = json.loads(line)
                r = rows.setdefault(e["id"], {"id": e["id"], "images": []})
                if e["etape"] == "image":
                    r["images"].append({"graine": e["graine"], "secondes": e["secondes"], "vram_max_go": e["vram_carte_max_go"]})
                elif e["etape"] == "3d":
                    r["3d"] = {k: e[k] for k in ("secondes", "vram_carte_avant_go", "vram_carte_max_go", "upsample", "graine_image")}
                elif e["etape"] == "blender":
                    r["blender"] = {k: e[k] for k in ("secondes", "triangles", "ko", "verdict")}
    out = [rows[a["id"]] for a in assets if a["id"] in rows]
    with open(os.path.join(OUT, "mesures.json"), "w", encoding="utf-8") as f:
        json.dump(out, f, ensure_ascii=False, indent=1)
    return out


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("step", choices=["images", "mesh", "clean", "godot", "sheet", "all"])
    ap.add_argument("--only", help="ids séparés par des virgules")
    ap.add_argument("--force", action="store_true", help="refaire même si le résultat existe")
    a = ap.parse_args()
    types, assets = load_assets(a.only)
    steps = {"images": step_images, "mesh": step_mesh, "clean": step_clean, "godot": step_godot, "sheet": step_sheet}
    order = ["images", "mesh", "clean", "godot", "sheet"] if a.step == "all" else [a.step]
    for s in order:
        if s == "sheet" and a.only:
            types, assets = load_assets(None)
        steps[s](types, assets, a.force)


if __name__ == "__main__":
    sys.exit(main())
