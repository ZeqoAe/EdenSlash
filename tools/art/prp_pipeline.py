#!/usr/bin/env python3
"""Lot PRP-1 : chaîne « idée -> image -> objet 3D -> nettoyage Blender -> GLB + fiche » (armes et ailes de dos).

Prérequis (hors dépôt) : ComfyUI lancé (C:\\AI\\Lancer_ComfyUI.bat, http://127.0.0.1:8188) avec SDXL base 1.0, le LoRA
eden_style_v0b et les modèles Pixal3D (voir conception/art/g1_test/LISEZMOI.md) ; Blender 5.2 ; le venv C:\\AI\\venv_comfy
(Pillow, numpy, scipy). Tout est reprenable : une étape déjà faite n'est pas refaite (--force pour la refaire).

  C:\\AI\\venv_comfy\\Scripts\\python.exe tools/art/prp_pipeline.py images  [--only id,id]   # 4 graines par objet + détourage
  ...                                         mesh    [--only id,id]   # Pixal3D sur la graine retenue -> GLB brut (150 000 faces)
  ...                                         clean   [--only id,id]   # Blender : retopo légère, repère de l'os, matériau, GLB + fiche
  ...                                         icon    [--only id,id]   # icônes 128 et 64 px (tuile autocollante, couleur de rareté)
  ...                                         godot                    # contrôle d'import et rendu sur le héros (Godot 4.7, projet de brouillon)
  ...                                         sheet                    # planche de contact conception/art/prp/planche2.jpg
  ...                                         game    [--only id,id]   # GLB + icônes dans game/, table game/data/prp_looks.json
  ...                                         measure                  # longueur et prise médianes des armes du jeu, par type
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
BUDGET = {"weapon": 3000, "back": 5000}    # triangles au plus (PRP-2 : 20 héros en Battle royale ; PRP-1 : 8 000 / 12 000)
MAX_KB = 600                               # poids d'un GLB au plus (PRP-1 : 1 536)
TEX = 512                                  # texture de couleur (les armes du jeu : 512)


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
                  "tri_max": int(a.get("triangles", BUDGET[kind]) * 0.96), "tex": int(a.get("texture", TEX)),
                  "max_kb": MAX_KB, "render_dir": rd, "id": a["id"],
                  "metrics": os.path.join(rd, a["id"] + "_metrics.json")}
        if kind == "weapon":
            params.update({"length": t["longueur"], "grip": t["prise"], "w1": t["w1"], "w2": t["w2"], "sens": t.get("sens")})
        else:
            params.update({"span": a.get("envergure", t["envergure"]), "up": t.get("haut", 0.10), "gap": t.get("recul", 0.0),
                           "flap": bool(t.get("battement"))})
        if a.get("une_piece"):
            params["single"] = True  # Pixal3D a doublé l'objet fin : on garde la plus grande pièce
        if a.get("couper_bas"):
            params["cut_bottom"] = float(a["couper_bas"])  # socle plat né de l'ombre de l'image
        if t.get("voxel"):
            params["voxel_res"] = int(t["voxel"])  # objet compact (sac) : 1/900 donnait 4 millions de faces, irréductibles
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
                                         "aretes_non_manifold", "verdict", "remarques", "battement") if k in met},
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
    """Planche PRP-2 (conception/art/prp/planche2.jpg, <= 500 Ko) : pour chaque création, l'objet seul (aperçu toon,
    fond du ciel du jeu), son icône, son nom, sa rareté, son type et ses mesures. Aucun rendu du héros d'Eden."""
    from PIL import Image, ImageDraw, ImageFont
    rd = os.path.join(RAW, "render")
    cw, chh, cols = 330, 400, 6
    rows = (len(assets) + cols - 1) // cols
    sheet = Image.new("RGB", (cw * cols, 70 + chh * rows), (34, 26, 58))
    d = ImageDraw.Draw(sheet)
    try:
        big = ImageFont.truetype("arialbd.ttf", 24)
        font = ImageFont.truetype("arialbd.ttf", 17)
        small = ImageFont.truetype("arial.ttf", 13)
    except OSError:
        big = font = small = ImageFont.load_default()
    nw = sum(1 for a in assets if a["emplacement"] == "weapon")
    d.text((16, 12), f"PRP-2 : {len(assets)} créations maison dans le jeu ({nw} armes, {len(assets) - nw} dos) - "
                     "armes <= 3 000 triangles, dos <= 5 000, texture 512, aplats", fill=(255, 248, 236), font=big)
    d.text((16, 44), "Héros > Apparence > Arme / Dos ; coffres d'apparence ; Coffres > Vitrine (insignes). Aucune stat.",
           fill=(200, 192, 220), font=small)
    meas = {r["id"]: r for r in summarize(assets)}
    for i, a in enumerate(assets):
        x, y = cw * (i % cols), 70 + chh * (i // cols)
        mp = os.path.join(rd, a["id"] + "_metrics.json")
        if not os.path.isfile(mp):
            continue
        with open(mp, encoding="utf-8") as f:
            met = json.load(f)
        col = RARITY_RGB[a["rarete"]]
        d.rounded_rectangle((x + 6, y + 4, x + cw - 6, y + chh - 6), 14, fill=(255, 248, 236), outline=col, width=4)
        main = Image.open(os.path.join(rd, a["id"] + "_vue.png")).convert("RGB")
        main.thumbnail((250, 250))
        sheet.paste(main, (x + (cw - main.width) // 2, y + 40))
        ic = os.path.join(rd, a["id"] + "_icone128.png")
        if os.path.isfile(ic):
            im = Image.open(ic).convert("RGBA")
            im.thumbnail((76, 76))
            sheet.paste(im, (x + cw - 92, y + 214), im)
        d.text((x + 16, y + 12), a["nom"], fill=INK, font=font)
        d.text((x + cw - 16, y + 14), RARITY[a["rarete"]], fill=tuple(int(c * 0.7) for c in col), font=small, anchor="ra")
        t = types[a["type"]]
        verdict = met["verdict"]
        three = meas.get(a["id"], {}).get("3d", {}).get("secondes")
        lines = [f"{t['nom']} · {met['triangles']} triangles · {met['ko']} Ko",
                 f"texture {met['texture']} · {met['dimensions'][0]:.2f} × {met['dimensions'][1]:.2f} × {met['dimensions'][2]:.2f}",
                 ("ailes battantes (2 moitiés)" if met.get("battement") else ("Blender %s s" % round(met.get("secondes", 0))))
                 + (" · 3D " + fmt_min(three) if three else ""),
                 "Contrôles OK" if verdict == "ok" else "À REVOIR : " + verdict,
                 (a.get("avis", "") or "")[:44]]
        for k, ln in enumerate(lines):
            color = INK if k < 3 else ((62, 127, 10) if verdict == "ok" else (200, 40, 60)) if k == 3 else (11, 125, 181)
            d.text((x + 16, y + 296 + 18 * k), ln, fill=color, font=small)
    out = os.path.join(OUT, "planche2.jpg")
    q = 88
    while True:
        sheet.save(out, quality=q, optimize=True, progressive=True)
        if os.path.getsize(out) <= 500 * 1024 or q <= 40:
            break
        q -= 6
    print(f"[planche] {out} ({os.path.getsize(out) // 1024} Ko, qualité {q})")


# ---------------------------------------------------------------------------------------------------------------------
# 6. Icônes (PRP-2) : tuile autocollante comme les icônes d'objets du jeu (bible § 1 et § 9) : carré très arrondi, dégradé
#    clair en haut à gauche -> couleur de rareté en bas à droite, rayons derrière le sujet, reflet blanc sur l'arête haute,
#    sujet contouré d'encre ; étoile à 4 branches pour mythique et légendaire. 128 et 64 px.
# ---------------------------------------------------------------------------------------------------------------------
RARITY_RGB = [(217, 212, 228), (143, 214, 46), (34, 184, 240), (196, 107, 245), (255, 138, 31), (255, 201, 40)]
INK = (34, 26, 58)


def sticker_icon(src, rarity, size=256):
    import numpy as np
    from PIL import Image, ImageDraw, ImageFilter
    col = np.array(RARITY_RGB[rarity], np.float32)
    light = col + (255 - col) * 0.72
    yy, xx = np.mgrid[0:size, 0:size] / (size - 1)
    t = np.clip((xx + yy) / 2, 0, 1)[..., None]
    tile = light * (1 - t) + col * t
    # rayons de soleil (12 secteurs clairs, centre un peu au-dessus du milieu)
    ang = np.arctan2(yy - 0.46, xx - 0.5)
    rays = (np.cos(ang * 12) > 0.35).astype(np.float32)[..., None]
    tile = tile + (255 - tile) * rays * 0.22
    tile = Image.fromarray(np.clip(tile, 0, 255).astype(np.uint8), "RGB").convert("RGBA")
    mask = Image.new("L", (size, size), 0)
    r = int(size * 0.2)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, size - 1, size - 1), r, fill=255)
    out = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    out.paste(tile, (0, 0), mask)
    d = ImageDraw.Draw(out)
    # liseré foncé de la rareté et reflet blanc sur l'arête haute
    dark = tuple(int(c * 0.55) for c in RARITY_RGB[rarity])
    d.rounded_rectangle((2, 2, size - 3, size - 3), r, outline=dark + (255,), width=max(3, size // 64))
    d.rounded_rectangle((size * 0.16, size * 0.06, size * 0.6, size * 0.12), size * 0.03, fill=(255, 255, 255, 120))
    # sujet : rendu Blender (fond transparent) recadré, contour d'encre et ombre douce
    sub = Image.open(src).convert("RGBA")
    bb = sub.getchannel("A").point(lambda v: 255 if v > 24 else 0).getbbox()
    if bb:
        sub = sub.crop(bb)
    inner = int(size * 0.8)
    sub.thumbnail((inner, inner), Image.LANCZOS)
    ow = max(3, size // 48)
    canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    canvas.paste(sub, ((size - sub.width) // 2, (size - sub.height) // 2), sub)
    a = canvas.getchannel("A").point(lambda v: 255 if v > 40 else 0)
    ring = a.filter(ImageFilter.MaxFilter(2 * ow + 1))
    shadow = ring.filter(ImageFilter.GaussianBlur(size / 64))
    sh = Image.new("RGBA", (size, size), INK + (0,))
    sh.putalpha(shadow.point(lambda v: int(v * 0.45)))
    out.alpha_composite(sh, (max(1, size // 64), max(2, size // 40)))
    ink = Image.new("RGBA", (size, size), INK + (0,))
    ink.putalpha(ring)
    out.alpha_composite(ink)
    out.alpha_composite(canvas)
    if rarity >= 4:  # étoile à 4 branches en haut à gauche
        cx, cy, rr = size * 0.2, size * 0.22, size * 0.09
        star = [(cx, cy - rr), (cx + rr * 0.22, cy - rr * 0.22), (cx + rr, cy), (cx + rr * 0.22, cy + rr * 0.22),
                (cx, cy + rr), (cx - rr * 0.22, cy + rr * 0.22), (cx - rr, cy), (cx - rr * 0.22, cy - rr * 0.22)]
        ImageDraw.Draw(out).polygon(star, fill=(255, 255, 255, 235), outline=INK + (255,))
    final = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    final.paste(out, (0, 0), mask)  # le carré arrondi découpe tout (contour du sujet compris)
    return final


def step_icon(types, assets, force=False):
    from PIL import Image
    rd = os.path.join(RAW, "render")
    for a in assets:
        src = os.path.join(rd, a["id"] + "_icone.png")
        if not os.path.isfile(src):
            print(f"[icône] {a['id']} : pas de rendu (refaire clean)")
            continue
        big = sticker_icon(src, int(a["rarete"]), 256)
        for px in (128, 64):
            big.resize((px, px), Image.LANCZOS).save(os.path.join(rd, f"{a['id']}_icone{px}.png"), optimize=True)
        print(f"[icône] {a['id']}")


# ---------------------------------------------------------------------------------------------------------------------
# 7. Entrée dans le jeu (PRP-2) : GLB, icônes et table game/data/prp_looks.json (lue par PrpLooks au chargement)
# ---------------------------------------------------------------------------------------------------------------------
GAME = os.path.join(ROOT, "game")
NUM0 = 990001  # numéro de collection = NUM0 + rang dans prp_assets.json (ajouter à la fin : les numéros restent)
PRICES = [120, 160, 220, 400, 700, 1000]  # = PrpLooks.PRICES (insignes, vitrine)
# textures intégrées en Basis Universal (gltf/embedded_image_handling=2) : aucun fichier d'image à côté du GLB
GLB_IMPORT = "\n".join([
    '[remap]', '', 'importer="scene"', 'importer_version=1', 'type="PackedScene"', '', '[deps]', '',
    'source_file="res://%s"', '', '[params]', '',
    'nodes/root_type=""', 'nodes/root_name=""', 'nodes/root_script=null', 'mesh_library/use_node_names_as_mesh_names=false',
    'array_mesh/deduplicate_surfaces=true', 'nodes/apply_root_scale=true', 'nodes/root_scale=1.0',
    'nodes/import_as_skeleton_bones=false', 'nodes/use_name_suffixes=true', 'nodes/use_node_type_suffixes=true',
    'meshes/ensure_tangents=false', 'meshes/generate_lods=true', 'meshes/create_shadow_meshes=true', 'meshes/light_baking=1',
    'meshes/lightmap_texel_size=0.2', 'meshes/force_disable_compression=false', 'skins/use_named_skins=true',
    'animation/import=false', 'animation/fps=30', 'animation/trimming=false', 'animation/remove_immutable_tracks=true',
    'animation/import_rest_as_RESET=false', 'import_script/path=""', 'materials/extract=0', 'materials/extract_format=0',
    'materials/extract_path=""', '_subresources={}', 'gltf/naming_version=2', 'gltf/embedded_image_handling=2',
    'gltf/texture_map_mode=1', ''])


def game_paths(a):
    glb = ("assets/weapons/prp/%s.glb" if a["emplacement"] == "weapon" else "assets/player/outfits/%s.glb") % a["id"]
    return glb, "assets/ui/items/%s.png" % a["id"], "assets/ui/items/%s_64.png" % a["id"]  # les id portent déjà « prp »


def step_game(types, assets, force=False):
    _, all_assets = load_assets(None)
    rd = os.path.join(RAW, "render")
    todo = {a["id"] for a in assets}
    looks = []
    for i, a in enumerate(all_assets):
        card_p = os.path.join(CAND, a["id"] + ".json")
        if a.get("garder") is False or not os.path.isfile(card_p):
            continue
        with open(card_p, encoding="utf-8") as f:
            card = json.load(f)
        if card["mesures"].get("verdict") != "ok":
            print(f"[jeu] {a['id']} écarté : {card['mesures'].get('verdict')}")
            continue
        glb, icon, icon64 = game_paths(a)
        if a["id"] in todo:
            os.makedirs(os.path.dirname(os.path.join(GAME, glb)), exist_ok=True)
            shutil.copy2(os.path.join(CAND, a["id"] + ".glb"), os.path.join(GAME, glb))
            imp = os.path.join(GAME, glb + ".import")
            if not os.path.isfile(imp):
                with open(imp, "w", encoding="utf-8", newline="\n") as f:
                    f.write(GLB_IMPORT % glb)
            for px, dst in ((128, icon), (64, icon64)):
                shutil.copy2(os.path.join(rd, f"{a['id']}_icone{px}.png"), os.path.join(GAME, dst))
        e = {"id": a["id"], "num": NUM0 + i, "slot": a["emplacement"], "name": a["nom"], "rarity": int(a["rarete"]),
             "model": "res://" + glb, "icon": "res://" + icon, "icon_64": "res://" + icon64,
             "price": PRICES[int(a["rarete"])], "triangles": card["mesures"]["triangles"], "ko": card["mesures"]["ko"]}
        if a["emplacement"] == "weapon":
            e["wtype"] = a["type"]
            e["bone"] = types[a["type"]]["os"]
        else:
            e["kind"] = a["type"]
            e["flap"] = bool(card["mesures"].get("battement"))
        looks.append(e)
    out = {"_lisezmoi": "Créations maison (lots PRP-1 / PRP-2), écrit par tools/art/prp_pipeline.py game depuis "
                        "tools/art/prp_assets.json et les fiches conception/art/prp/candidats/<id>.json ; lu par PrpLooks "
                        "(scripts/core/prp_looks.gd). num = numéro de collection (fixe), price = insignes (vitrine).",
           "looks": looks}
    with open(os.path.join(GAME, "data", "prp_looks.json"), "w", encoding="utf-8", newline="\n") as f:
        json.dump(out, f, ensure_ascii=False, indent=1)
    print(f"[jeu] {len(looks)} créations dans game/data/prp_looks.json")


# ---------------------------------------------------------------------------------------------------------------------
# Mesure des armes du jeu (longueur et prise médianes par type, repère de l'os) : de quoi remplir « types »
# ---------------------------------------------------------------------------------------------------------------------
def _node_matrix(n):
    import numpy as np
    if "matrix" in n:
        return np.array(n["matrix"]).reshape(4, 4).T
    t = np.eye(4)
    if "scale" in n:
        t = np.diag(list(n["scale"]) + [1]) @ t
    if "rotation" in n:
        x, y, z, w = n["rotation"]
        r = np.eye(4)
        r[:3, :3] = [[1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w)],
                     [2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w)],
                     [2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y)]]
        t = r @ t
    if "translation" in n:
        tr = np.eye(4)
        tr[:3, 3] = n["translation"]
        t = tr @ t
    return t


def glb_points(path):
    """Sommets d'un GLB dans le repère de l'os (EdenRoot remis à l'identité, comme EdenModel) et nœuds W1 / W2."""
    import struct
    import numpy as np
    with open(path, "rb") as f:
        b = f.read()
    jl = struct.unpack("<I", b[12:16])[0]
    js = json.loads(b[20:20 + jl])
    bl = struct.unpack("<I", b[20 + jl:24 + jl])[0]
    binb = b[28 + jl:28 + jl + bl]
    pts, marks = [], {}

    def walk(i, m, under):
        n = js["nodes"][i]
        if n.get("name") == "EdenRoot":
            m, under = np.eye(4), True
        else:
            m = m @ _node_matrix(n)
        if under and n.get("name") in ("W1", "W2"):
            marks[n["name"]] = m[:3, 3]
        if under and "mesh" in n:
            for pr in js["meshes"][n["mesh"]]["primitives"]:
                acc = js["accessors"][pr["attributes"]["POSITION"]]
                bv = js["bufferViews"][acc["bufferView"]]
                v = np.frombuffer(binb, np.float32, acc["count"] * 3, bv.get("byteOffset", 0) + acc.get("byteOffset", 0))
                pts.append((m @ np.c_[v.reshape(-1, 3), np.ones(acc["count"])].T).T[:, :3])
        for c in n.get("children", []):
            walk(c, m, under)
    for r in js["scenes"][0]["nodes"]:
        walk(r, np.eye(4), False)
    return np.concatenate(pts), marks


def step_measure(types, assets, force=False):
    import numpy as np
    with open(os.path.join(GAME, "data", "weapon_types.json"), encoding="utf-8") as f:
        wt = json.load(f)
    for k, v in wt.items():
        rows = []
        for w in v.get("weapons", []):
            p, mk = glb_points(os.path.join(GAME, w["model"].replace("res://", "")))
            lo, hi = p.min(0), p.max(0)
            ln = hi[2] - lo[2]
            rows.append([ln, -lo[2] / ln] + [(mk[n][2] - lo[2]) / ln if n in mk else float("nan") for n in ("W1", "W2")])
        a = np.array(rows)
        print(f"[mesure] {k:10s} longueur {np.median(a[:, 0]):.2f}  prise {np.median(a[:, 1]):.2f}  "
              f"W1 {np.nanmedian(a[:, 2]):.2f}  W2 {np.nanmedian(a[:, 3]):.2f}")


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
    ap.add_argument("step", choices=["images", "mesh", "clean", "godot", "icon", "sheet", "game", "measure", "all"])
    ap.add_argument("--only", help="ids séparés par des virgules")
    ap.add_argument("--force", action="store_true", help="refaire même si le résultat existe")
    a = ap.parse_args()
    types, assets = load_assets(a.only)
    steps = {"images": step_images, "mesh": step_mesh, "clean": step_clean, "godot": step_godot, "icon": step_icon,
             "sheet": step_sheet, "game": step_game, "measure": step_measure}
    order = ["images", "mesh", "clean", "icon", "godot", "sheet"] if a.step == "all" else [a.step]
    for s in order:
        if s == "sheet" and a.only:
            types, assets = load_assets(None)
        steps[s](types, assets, a.force)


if __name__ == "__main__":
    sys.exit(main())
