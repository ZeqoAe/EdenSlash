#!/usr/bin/env python3
"""Entraîne un LoRA SDXL (kohya sd-scripts) d'après un fichier de configuration TOML, et mesure le tout.

    C:\\AI\\venv_train\\Scripts\\python.exe tools/art/train_lora.py tools/art/lora_v0.toml
    ... train_lora.py tools/art/lora_v0.toml --dry-run      # affiche la commande sans lancer
    ... train_lora.py tools/art/lora_v0.toml --report-only  # relit les journaux d'un entraînement fini

Installation (hors dépôt) : C:\\AI\\sd-scripts (kohya-ss/sd-scripts) + venv C:\\AI\\venv_train (Python 3.12,
PyTorch cu128 pour la RTX 5070) ; voir conception/art/lora/R_LORA.md.
Sorties dans [sortie].dossier : <nom>.safetensors (+ étapes intermédiaires), journal train.log, mesures.json
(durée, VRAM au plus haut, perte), perte.csv et perte.png, versions des outils.
Avant de lancer, ComfyUI (s'il tourne) est prié de libérer la VRAM (/free) : il recharge ses modèles au besoin.
"""
import argparse
import json
import os
import subprocess
import sys
import threading
import time
import tomllib
import urllib.request
from pathlib import Path

SD_SCRIPTS = Path(r"C:\AI\sd-scripts")
PYTHON = Path(r"C:\AI\venv_train\Scripts\python.exe")


def vram_used_mib() -> int:
    try:
        out = subprocess.run(["nvidia-smi", "--query-gpu=memory.used", "--format=csv,noheader,nounits"],
                             capture_output=True, text=True, timeout=10).stdout
        return int(out.strip().splitlines()[0])
    except Exception:
        return -1


def comfy_free(host: str) -> None:
    try:
        req = urllib.request.Request(f"http://{host}/free", data=json.dumps({"unload_models": True, "free_memory": True}).encode(),
                                     headers={"Content-Type": "application/json"})
        urllib.request.urlopen(req, timeout=10).read()
        print(f"ComfyUI ({host}) : VRAM libérée")
    except Exception:
        pass


def versions() -> dict:
    code = ("import json,torch,accelerate,transformers,diffusers,bitsandbytes,safetensors,sys;"
            "print(json.dumps({'python':sys.version.split()[0],'torch':torch.__version__,'cuda':torch.version.cuda,"
            "'gpu':torch.cuda.get_device_name(0),'accelerate':accelerate.__version__,'transformers':transformers.__version__,"
            "'diffusers':diffusers.__version__,'bitsandbytes':bitsandbytes.__version__,'safetensors':safetensors.__version__}))")
    v = json.loads(subprocess.run([str(PYTHON), "-c", code], capture_output=True, text=True).stdout.strip().splitlines()[-1])
    git = subprocess.run(["git", "-C", str(SD_SCRIPTS), "log", "-1", "--format=%h %ci"], capture_output=True, text=True).stdout.strip()
    v["sd-scripts"] = git
    return v


def dataset_toml(cfg: dict, path: Path) -> None:
    d = cfg["donnees"]
    lines = [
        "[general]",
        "shuffle_caption = false",
        'caption_extension = ".txt"',
        f"keep_tokens = {int(d.get('keep_tokens', 1))}",
        "",
        "[[datasets]]",
        f"resolution = {int(d.get('resolution', 1024))}",
        f"batch_size = {int(d.get('batch', 1))}",
        "enable_bucket = true",
        f"min_bucket_reso = {int(d.get('min_bucket', 256))}",
        f"max_bucket_reso = {int(d.get('max_bucket', 2048))}",
        f"bucket_no_upscale = {str(bool(d.get('bucket_no_upscale', True))).lower()}",
        "",
        "  [[datasets.subsets]]",
        f"  image_dir = '{Path(d['images']).as_posix()}'",
        f"  num_repeats = {int(d.get('repetitions', 1))}",
    ]
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def command(cfg: dict, out: Path, ds: Path) -> list:
    m, r, e = cfg["modele"], cfg["reseau"], cfg["entrainement"]
    name = cfg["sortie"]["nom"]
    cmd = [str(PYTHON), str(SD_SCRIPTS / "sdxl_train_network.py"),
           "--pretrained_model_name_or_path", m["base"],
           "--dataset_config", str(ds),
           "--output_dir", str(out), "--output_name", name, "--save_model_as", "safetensors",
           "--network_module", "networks.lora",
           "--network_dim", str(r.get("rang", 32)), "--network_alpha", str(r.get("alpha", 16)),
           "--learning_rate", str(e.get("lr", 1e-4)),
           "--optimizer_type", e.get("optimiseur", "AdamW8bit"),
           "--lr_scheduler", e.get("planning", "cosine"), "--lr_warmup_steps", str(e.get("echauffement", 100)),
           "--max_train_steps", str(e.get("pas", 2000)),
           "--save_every_n_steps", str(e.get("sauver_tous_les", 500)),
           "--mixed_precision", e.get("precision", "bf16"), "--save_precision", e.get("precision_sauvegarde", "bf16"),
           "--seed", str(e.get("graine", 42)),
           "--cache_latents", "--cache_latents_to_disk",
           "--gradient_checkpointing", "--sdpa",
           "--max_data_loader_n_workers", "0",
           "--log_with", "tensorboard", "--logging_dir", str(out / "logs"),
           "--log_prefix", name + "_"]
    if m.get("vae"):
        cmd += ["--vae", m["vae"]]
    if r.get("unet_seulement", True):
        cmd += ["--network_train_unet_only", "--cache_text_encoder_outputs"]
    else:
        cmd += ["--text_encoder_lr", str(e.get("lr_te", 1e-5))]
    if e.get("min_snr_gamma"):
        cmd += ["--min_snr_gamma", str(e["min_snr_gamma"])]
    if e.get("noise_offset"):
        cmd += ["--noise_offset", str(e["noise_offset"])]
    if e.get("fp8_base"):
        cmd += ["--fp8_base"]
    if e.get("full_bf16"):
        cmd += ["--full_bf16"]
    if not e.get("half_vae", False):
        cmd += ["--no_half_vae"]
    cmd += [str(x) for x in e.get("extra", [])]
    return cmd


def read_losses(logdir: Path) -> list:
    """(pas, perte moyenne) depuis les journaux tensorboard."""
    try:
        from tensorboard.backend.event_processing.event_accumulator import EventAccumulator
    except ImportError:
        return []
    pts = []
    for ev in sorted(logdir.rglob("events.out.tfevents.*")):
        acc = EventAccumulator(str(ev))
        acc.Reload()
        tags = acc.Tags().get("scalars", [])
        tag = next((t for t in ("loss/average", "loss/current") if t in tags), None)
        if tag:
            pts += [(s.step, s.value) for s in acc.Scalars(tag)]
    return pts


def report(out: Path, meta: dict) -> dict:
    pts = read_losses(out / "logs")
    if pts:
        with open(out / "perte.csv", "w", encoding="utf-8") as f:
            f.write("pas,perte_moyenne\n")
            for s, v in pts:
                f.write(f"{s},{v:.5f}\n")
        n = len(pts)
        meta["perte"] = {"debut": round(pts[min(20, n - 1)][1], 4), "milieu": round(pts[n // 2][1], 4),
                         "fin": round(pts[-1][1], 4)}
        try:
            from PIL import Image, ImageDraw
            w, h, pad = 720, 300, 40
            im = Image.new("RGB", (w, h), (24, 22, 32))
            d = ImageDraw.Draw(im)
            vs = [v for _, v in pts]
            lo, hi = min(vs), max(vs)
            smax = max(s for s, _ in pts) or 1
            xy = [(pad + (w - 2 * pad) * s / smax, h - pad - (h - 2 * pad) * (v - lo) / max(hi - lo, 1e-6)) for s, v in pts]
            d.line(xy, fill=(235, 200, 110), width=2)
            d.rectangle((pad, pad, w - pad, h - pad), outline=(90, 90, 110))
            d.text((pad, 10), f"perte moyenne (pas 0 -> {smax}) : {hi:.3f} -> {vs[-1]:.3f}", fill=(220, 220, 230))
            im.save(out / "perte.png")
        except ImportError:
            pass
    (out / "mesures.json").write_text(json.dumps(meta, ensure_ascii=False, indent=1), encoding="utf-8")
    return meta


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("config")
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("--report-only", action="store_true")
    ap.add_argument("--comfy", default="127.0.0.1:8188")
    a = ap.parse_args()
    cfg = tomllib.loads(Path(a.config).read_text(encoding="utf-8"))
    out = Path(cfg["sortie"]["dossier"])
    out.mkdir(parents=True, exist_ok=True)
    ds = out / "dataset.toml"
    dataset_toml(cfg, ds)
    cmd = command(cfg, out, ds)
    if a.dry_run:
        print(" ".join(f'"{c}"' if " " in c else c for c in cmd))
        return 0
    if a.report_only:
        meta = json.loads((out / "mesures.json").read_text(encoding="utf-8")) if (out / "mesures.json").exists() else {}
        print(json.dumps(report(out, meta), ensure_ascii=False, indent=1))
        return 0
    comfy_free(a.comfy)
    time.sleep(3)
    meta = {"config": cfg, "versions": versions(), "vram_avant_mib": vram_used_mib(), "commande": cmd}
    peak = [meta["vram_avant_mib"]]
    stop = threading.Event()

    def poll():
        while not stop.is_set():
            peak[0] = max(peak[0], vram_used_mib())
            stop.wait(5)

    th = threading.Thread(target=poll, daemon=True)
    th.start()
    t0 = time.time()
    env = dict(os.environ, PYTHONIOENCODING="utf-8", PYTHONUTF8="1")
    with open(out / "train.log", "w", encoding="utf-8") as log:
        proc = subprocess.run(cmd, cwd=SD_SCRIPTS, stdout=log, stderr=subprocess.STDOUT, env=env)
    stop.set()
    th.join(timeout=10)
    meta.update({"code_sortie": proc.returncode, "duree_s": round(time.time() - t0), "vram_max_mib": peak[0],
                 "vram_max_note": "mémoire de toute la carte (bureau et autres programmes compris), relevée toutes les 5 s"})
    meta = report(out, meta)
    print(json.dumps({k: meta[k] for k in ("code_sortie", "duree_s", "vram_avant_mib", "vram_max_mib") if k in meta}
                     | {"perte": meta.get("perte")}, ensure_ascii=False))
    return proc.returncode


if __name__ == "__main__":
    sys.exit(main())
