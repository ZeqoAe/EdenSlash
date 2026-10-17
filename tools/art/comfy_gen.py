#!/usr/bin/env python3
"""Générateur de contenu : envoie un workflow à l'API locale de ComfyUI et récupère le résultat.

ComfyUI doit tourner en local (C:\\AI\\Lancer_ComfyUI.bat, http://127.0.0.1:8188).
Aucune dépendance obligatoire (bibliothèque standard) ; Pillow (présent dans le venv
C:\\AI\\venv_comfy) sert seulement à --resize / --jpg.

Exemples :
  # une image FLUX.1-schnell (1536x512), réduite au format des cartes d'activité (960x320, JPG)
  C:\\AI\\venv_comfy\\Scripts\\python.exe tools/art/comfy_gen.py --prompt "..." --seed 7 \\
      --out conception/art/essais --name essai --resize 960x320 --jpg 88

  # une série : fichier JSON [{"name":..., "prompt":..., "seed":..., "width":..., "height":...}, ...]
  ... tools/art/comfy_gen.py --batch tools/art/prompts_activites.json --out conception/art/g1_test

  # image -> objet 3D texturé (GLB), workflow Pixal3D / TRELLIS.2 natif de ComfyUI
  ... tools/art/comfy_gen.py --workflow image_to_3d_pixal3d --image epee.png --out conception/art/g1_test --name epee

Paramètres : les nœuds du workflow sont repérés par leur titre (_meta.title) : PROMPT, NEGATIVE,
SIZE, SAMPLER* (graine : la première reçoit --seed, les suivantes --seed+1, ...), IMAGE, SAVE, FACES,
TEXTURE. --set "id.entree=valeur" change n'importe quelle entrée (valeur lue en JSON si possible).
"""
import argparse
import json
import os
import sys
import time
import urllib.parse
import urllib.request
import uuid

HERE = os.path.dirname(os.path.abspath(__file__))
STYLE = ("stylized 3D fantasy MMORPG game art, anime toon shading, soft painterly lighting, "
         "rich saturated colors, midnight blue and gold palette, highly detailed, cinematic wide shot, "
         "no text, no watermark, no logo, no UI")


def api(host, path, data=None, raw=False):
    req = urllib.request.Request(f"http://{host}{path}")
    if data is not None:
        req.data = json.dumps(data).encode()
        req.add_header("Content-Type", "application/json")
    with urllib.request.urlopen(req, timeout=60) as r:
        body = r.read()
    return body if raw else json.loads(body)


def upload_image(host, path):
    """Envoie une image dans le dossier input de ComfyUI (multipart fait main)."""
    boundary = uuid.uuid4().hex
    name = os.path.basename(path)
    with open(path, "rb") as f:
        content = f.read()
    body = (f"--{boundary}\r\nContent-Disposition: form-data; name=\"image\"; filename=\"{name}\"\r\n"
            f"Content-Type: application/octet-stream\r\n\r\n").encode() + content + \
           (f"\r\n--{boundary}\r\nContent-Disposition: form-data; name=\"overwrite\"\r\n\r\ntrue\r\n"
            f"--{boundary}--\r\n").encode()
    req = urllib.request.Request(f"http://{host}/upload/image", data=body)
    req.add_header("Content-Type", f"multipart/form-data; boundary={boundary}")
    with urllib.request.urlopen(req, timeout=120) as r:
        res = json.loads(r.read())
    return (res.get("subfolder") + "/" if res.get("subfolder") else "") + res["name"]


def load_workflow(name):
    path = name if os.path.isfile(name) else os.path.join(HERE, "workflows", name + ".json")
    with open(path, encoding="utf-8") as f:
        return json.load(f)


def by_title(wf, prefix):
    return [k for k, v in wf.items() if v.get("_meta", {}).get("title", "").startswith(prefix)]


def apply_job(wf, job, host):
    for k in by_title(wf, "PROMPT"):
        if "prompt" in job:
            text = job["prompt"]
            if job.get("style", True):
                text = text.rstrip(". ") + ". " + job.get("style_text", STYLE)
            wf[k]["inputs"]["text"] = text
    for k in by_title(wf, "NEGATIVE"):
        wf[k]["inputs"]["text"] = job.get("negative", "")
    for k in by_title(wf, "SIZE"):
        for key in ("width", "height"):
            if key in job:
                wf[k]["inputs"][key] = int(job[key])
    seed = job.get("seed")
    for i, k in enumerate(sorted(by_title(wf, "SAMPLER"), key=lambda x: int(x) if x.isdigit() else 0)):
        if seed is not None:
            wf[k]["inputs"]["seed"] = int(seed) + i
        if "steps" in job and len(by_title(wf, "SAMPLER")) == 1:
            wf[k]["inputs"]["steps"] = int(job["steps"])
    for k in by_title(wf, "IMAGE"):
        if job.get("image"):
            wf[k]["inputs"]["image"] = upload_image(host, job["image"])
    for k in by_title(wf, "FACES"):
        if "faces" in job:
            wf[k]["inputs"]["target_face_count"] = int(job["faces"])
    for k in by_title(wf, "SAVE"):
        wf[k]["inputs"]["filename_prefix"] = "eden/" + job.get("name", "sortie")
    for item in job.get("set", []):
        key, _, val = item.partition("=")
        node, _, inp = key.partition(".")
        try:
            val = json.loads(val)
        except ValueError:
            pass
        wf[node]["inputs"][inp] = val
    return wf


def wait_result(host, pid, timeout):
    t0 = time.time()
    while time.time() - t0 < timeout:
        hist = api(host, f"/history/{pid}")
        if pid in hist:
            h = hist[pid]
            status = h.get("status", {})
            if status.get("status_str") == "error":
                msgs = [m for m in status.get("messages", []) if m[0] == "execution_error"]
                raise RuntimeError(f"ComfyUI : erreur d'exécution {msgs[:1]}")
            if status.get("completed", True):
                return h
        time.sleep(1.0)
    raise TimeoutError(f"pas de résultat après {timeout} s")


def fetch_outputs(host, hist, out_dir, name, resize=None, jpg=None):
    saved = []
    for node_out in hist.get("outputs", {}).values():
        for items in node_out.values():
            if not isinstance(items, list):
                continue
            for it in items:
                if not isinstance(it, dict) or "filename" not in it:
                    continue
                q = urllib.parse.urlencode({"filename": it["filename"], "subfolder": it.get("subfolder", ""),
                                            "type": it.get("type", "output")})
                data = api(host, f"/view?{q}", raw=True)
                ext = os.path.splitext(it["filename"])[1].lower()
                suffix = "" if not saved else f"_{len(saved)}"
                dst = os.path.join(out_dir, f"{name}{suffix}{ext}")
                with open(dst, "wb") as f:
                    f.write(data)
                if ext == ".png" and (resize or jpg):
                    dst = post_image(dst, resize, jpg)
                saved.append(dst)
    return saved


def post_image(path, resize, jpg):
    from PIL import Image  # Pillow : venv de ComfyUI
    im = Image.open(path).convert("RGB")
    if resize:
        w, h = (int(x) for x in resize.lower().split("x"))
        # recadre au bon rapport puis réduit (Lanczos)
        r = w / h
        if im.width / im.height > r:
            nw = int(im.height * r)
            im = im.crop(((im.width - nw) // 2, 0, (im.width - nw) // 2 + nw, im.height))
        elif im.width / im.height < r:
            nh = int(im.width / r)
            im = im.crop((0, (im.height - nh) // 2, im.width, (im.height - nh) // 2 + nh))
        im = im.resize((w, h), Image.LANCZOS)
    if jpg:
        dst = os.path.splitext(path)[0] + ".jpg"
        im.save(dst, quality=int(jpg), optimize=True)
        os.remove(path)
        return dst
    im.save(path)
    return path


def run_job(host, workflow, job, out_dir, timeout, resize, jpg, keep_full):
    wf = apply_job(load_workflow(workflow), job, host)
    stats0 = api(host, "/system_stats")
    t0 = time.time()
    try:
        pid = api(host, "/prompt", {"prompt": wf, "client_id": "eden-g1"})["prompt_id"]
    except urllib.error.HTTPError as e:
        raise RuntimeError(f"ComfyUI refuse le workflow : {e.read().decode(errors='replace')[:2000]}") from None
    hist = wait_result(host, pid, timeout)
    dt = time.time() - t0
    name = job.get("name", "sortie")
    files = []
    if keep_full:
        files += fetch_outputs(host, hist, out_dir, name + "_full")
    files += fetch_outputs(host, hist, out_dir, name, job.get("resize", resize), job.get("jpg", jpg))
    dev = api(host, "/system_stats")["devices"][0]
    used = (dev["vram_total"] - dev["vram_free"]) / 2**30
    info = {"name": name, "seed": job.get("seed"), "seconds": round(dt, 1),
            "vram_used_after_gb": round(used, 2), "files": files}
    print(json.dumps(info, ensure_ascii=False))
    return info


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--host", default="127.0.0.1:8188")
    ap.add_argument("--workflow", default="flux_schnell")
    ap.add_argument("--prompt")
    ap.add_argument("--negative", default="")
    ap.add_argument("--no-style", action="store_true", help="ne pas ajouter le suffixe de style du jeu")
    ap.add_argument("--seed", type=int)
    ap.add_argument("--width", type=int)
    ap.add_argument("--height", type=int)
    ap.add_argument("--steps", type=int)
    ap.add_argument("--image", help="image d'entrée (workflow 3D)")
    ap.add_argument("--faces", type=int, help="nombre de faces visé (workflow 3D)")
    ap.add_argument("--name", default="sortie")
    ap.add_argument("--batch", help="fichier JSON : liste de travaux")
    ap.add_argument("--out", default=".")
    ap.add_argument("--resize", help="LxH final (recadre puis réduit), ex. 960x320")
    ap.add_argument("--jpg", type=int, help="qualité JPG (sinon PNG)")
    ap.add_argument("--keep-full", action="store_true", help="garder aussi l'image pleine résolution")
    ap.add_argument("--set", action="append", default=[], help="id.entree=valeur (répétable)")
    ap.add_argument("--timeout", type=int, default=1800)
    ap.add_argument("--log", help="ajoute une ligne JSON par travail dans ce fichier")
    a = ap.parse_args()

    os.makedirs(a.out, exist_ok=True)
    if a.batch:
        with open(a.batch, encoding="utf-8") as f:
            jobs = json.load(f)
    else:
        job = {"name": a.name, "negative": a.negative, "set": a.set, "style": not a.no_style}
        for k in ("prompt", "seed", "width", "height", "steps", "image", "faces"):
            v = getattr(a, k)
            if v is not None:
                job[k] = v
        jobs = [job]
    for job in jobs:
        info = run_job(a.host, job.get("workflow", a.workflow), job, a.out, a.timeout, a.resize, a.jpg, a.keep_full)
        if a.log:
            with open(a.log, "a", encoding="utf-8") as f:
                f.write(json.dumps(info, ensure_ascii=False) + "\n")


if __name__ == "__main__":
    sys.exit(main())
