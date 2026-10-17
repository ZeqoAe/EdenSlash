#!/usr/bin/env python3
"""Génération en série avec un LoRA (SDXL) via l'API locale de ComfyUI, et planche de comparaison.

ComfyUI doit tourner (C:\\AI\\Lancer_ComfyUI.bat, http://127.0.0.1:8188). Pillow requis pour la planche
(venv C:\\AI\\venv_comfy). Workflow : tools/art/workflows/sdxl_lora.json (nœuds repérés par leur titre :
MODEL, LORA, PROMPT, NEGATIVE, SIZE, SAMPLER, SAVE).

Exemples :
  # planche : chaque prompt x chaque graine, sans LoRA puis aux intensités 0,5 / 0,8 / 1,0
  C:\\AI\\venv_comfy\\Scripts\\python.exe tools/art/gen_with_lora.py \\
      --lora C:/AI/lora_out/eden_style_v0/eden_style_v0.safetensors --strengths 0,0.5,0.8,1.0 \\
      --prompts tools/art/lora_prompts_v0.json --seeds 11,22 --out conception/art/lora/v0/grille --grid

  # une image
  ... gen_with_lora.py --lora eden_style_v0.safetensors --strengths 0.8 --prompt "edenstyle, a knight ..." --seeds 5

--lora : nom d'un fichier de C:\\AI\\ComfyUI\\models\\loras, ou chemin d'un .safetensors (copié dans ce dossier si
absent ou plus récent). Intensité 0 = sans LoRA (le nœud est retiré : image exacte du modèle de base).
Le mot-clé de déclenchement (« edenstyle ») est dans les prompts ; --strip-trigger le retire des images sans LoRA.
"""
import argparse
import json
import os
import shutil
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import comfy_gen  # noqa: E402  (api, load_workflow, by_title, wait_result, fetch_outputs)

LORA_DIR = r"C:\AI\ComfyUI\models\loras"
NEG_DEFAULT = ("photo, photorealistic, realistic skin, text, watermark, logo, signature, ui, blurry, lowres, "
               "jpeg artifacts, deformed, extra limbs")


def install_lora(path):
    """Renvoie le nom de fichier à donner à ComfyUI (copie dans models/loras si besoin)."""
    if not path or path.lower() == "none":
        return None
    if not os.path.isfile(path):
        if os.path.isfile(os.path.join(LORA_DIR, path)):
            return path
        sys.exit(f"LoRA introuvable : {path}")
    name = os.path.basename(path)
    dst = os.path.join(LORA_DIR, name)
    if not os.path.isfile(dst) or os.path.getmtime(dst) < os.path.getmtime(path):
        os.makedirs(LORA_DIR, exist_ok=True)
        shutil.copy2(path, dst)
    return name


def build(lora_name, strength, prompt, negative, seed, width, height, steps, cfg, prefix, ckpt):
    wf = comfy_gen.load_workflow("sdxl_lora")
    lora_id = comfy_gen.by_title(wf, "LORA")[0]
    model_id = comfy_gen.by_title(wf, "MODEL")[0]
    if ckpt:
        wf[model_id]["inputs"]["ckpt_name"] = ckpt
    if lora_name is None or strength == 0:
        # sans LoRA : on retire le nœud et on rebranche sur le modèle
        del wf[lora_id]
        for node in wf.values():
            for k, v in node["inputs"].items():
                if isinstance(v, list) and len(v) == 2 and v[0] == lora_id:
                    node["inputs"][k] = [model_id, v[1]]
    else:
        wf[lora_id]["inputs"].update({"lora_name": lora_name, "strength_model": strength, "strength_clip": strength})
    for k in comfy_gen.by_title(wf, "PROMPT"):
        wf[k]["inputs"]["text"] = prompt
    for k in comfy_gen.by_title(wf, "NEGATIVE"):
        wf[k]["inputs"]["text"] = negative
    for k in comfy_gen.by_title(wf, "SIZE"):
        wf[k]["inputs"].update({"width": width, "height": height})
    for k in comfy_gen.by_title(wf, "SAMPLER"):
        wf[k]["inputs"].update({"seed": seed, "steps": steps, "cfg": cfg})
    for k in comfy_gen.by_title(wf, "SAVE"):
        wf[k]["inputs"]["filename_prefix"] = "eden/" + prefix
    return wf


def run(host, wf, out_dir, name, timeout):
    t0 = time.time()
    pid = comfy_gen.api(host, "/prompt", {"prompt": wf, "client_id": "eden-lora"})["prompt_id"]
    hist = comfy_gen.wait_result(host, pid, timeout)
    files = comfy_gen.fetch_outputs(host, hist, out_dir, name)
    return files[0] if files else None, round(time.time() - t0, 1)


def grid(rows, cols, cells, out_path, thumb_w=384):
    """cells[(r, c)] = chemin ; rows / cols = libellés."""
    from PIL import Image, ImageDraw, ImageFont
    first = Image.open(next(iter(cells.values())))
    tw, th = thumb_w, int(thumb_w * first.height / first.width)
    lw, hh = 260, 40
    sheet = Image.new("RGB", (lw + tw * len(cols), hh + th * len(rows)), (24, 22, 32))
    d = ImageDraw.Draw(sheet)
    try:
        font = ImageFont.truetype("arial.ttf", 18)
        small = ImageFont.truetype("arial.ttf", 14)
    except OSError:
        font = small = ImageFont.load_default()
    for c, label in enumerate(cols):
        d.text((lw + c * tw + 8, 10), label, fill=(235, 215, 150), font=font)
    for r, label in enumerate(rows):
        y = hh + r * th
        words, line, lines = label.split(), "", []
        for w in words:
            if len(line) + len(w) > 30:
                lines.append(line)
                line = ""
            line += w + " "
        lines.append(line)
        d.multiline_text((8, y + 8), "\n".join(lines[:9]), fill=(220, 220, 230), font=small, spacing=3)
        for c in range(len(cols)):
            p = cells.get((r, c))
            if p:
                sheet.paste(Image.open(p).convert("RGB").resize((tw, th), Image.LANCZOS), (lw + c * tw, y))
    sheet.save(out_path, quality=88)
    return out_path


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--host", default="127.0.0.1:8188")
    ap.add_argument("--lora", help="fichier .safetensors ou nom dans models/loras ; 'none' = sans")
    ap.add_argument("--strengths", default="0,0.5,0.8,1.0", help="intensités, 0 = sans LoRA")
    ap.add_argument("--prompt", action="append", default=[], help="prompt (répétable)")
    ap.add_argument("--prompts", help="JSON : liste de prompts ou de {name, prompt, width, height}")
    ap.add_argument("--negative", default=NEG_DEFAULT)
    ap.add_argument("--seeds", default="11", help="graines séparées par des virgules")
    ap.add_argument("--width", type=int, default=1216)
    ap.add_argument("--height", type=int, default=832)
    ap.add_argument("--steps", type=int, default=30)
    ap.add_argument("--cfg", type=float, default=6.5)
    ap.add_argument("--ckpt", help="autre modèle de base (models/checkpoints)")
    ap.add_argument("--strip-trigger", default="", help="mot retiré des prompts à l'intensité 0 (ex. edenstyle)")
    ap.add_argument("--out", default=".")
    ap.add_argument("--grid", action="store_true", help="planche : lignes = prompt x graine, colonnes = intensités")
    ap.add_argument("--timeout", type=int, default=900)
    a = ap.parse_args()

    os.makedirs(a.out, exist_ok=True)
    lora_name = install_lora(a.lora)
    jobs = [{"name": f"p{i + 1}", "prompt": p} for i, p in enumerate(a.prompt)]
    if a.prompts:
        with open(a.prompts, encoding="utf-8") as f:
            for i, j in enumerate(json.load(f)):
                jobs.append(j if isinstance(j, dict) else {"name": f"p{i + 1}", "prompt": j})
    strengths = [float(s) for s in a.strengths.split(",")]
    seeds = [int(s) for s in a.seeds.split(",")]
    cells, rows, log = {}, [], []
    for job in jobs:
        for seed in seeds:
            r = len(rows)
            rows.append(f"{job['name']} / graine {seed} : {job['prompt']}")
            for c, s in enumerate(strengths):
                prompt = job["prompt"]
                if s == 0 and a.strip_trigger:
                    prompt = prompt.replace(a.strip_trigger + ", ", "").replace(a.strip_trigger, "").strip(", ")
                name = f"{job['name']}_s{seed}_l{int(round(s * 100)):03d}"
                wf = build(lora_name, s, prompt, a.negative, seed, int(job.get("width", a.width)),
                           int(job.get("height", a.height)), a.steps, a.cfg, name, a.ckpt)
                path, dt = run(a.host, wf, a.out, name, a.timeout)
                cells[(r, c)] = path
                info = {"name": name, "lora": lora_name, "strength": s, "seed": seed, "seconds": dt, "file": path}
                log.append(info)
                print(json.dumps(info, ensure_ascii=False), flush=True)
    with open(os.path.join(a.out, "generation.jsonl"), "a", encoding="utf-8") as f:
        for info in log:
            f.write(json.dumps(info, ensure_ascii=False) + "\n")
    if a.grid and cells:
        cols = ["sans LoRA" if s == 0 else f"LoRA {s:g}" for s in strengths]
        out = grid(rows, cols, cells, os.path.join(a.out, "planche.jpg"))
        print("planche :", out)


if __name__ == "__main__":
    sys.exit(main())
