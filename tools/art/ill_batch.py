#!/usr/bin/env python3
"""Lot ILL-1 : illustrations candidates (cartes d'activité, titre, menu, écrans de fin) avec le LoRA eden_style_v0b à 0,5.

ComfyUI doit tourner (C:\\AI\\Lancer_ComfyUI.bat). Pillow requis (venv C:\\AI\\venv_comfy).
Étapes (toutes reprenables : une image déjà générée n'est pas refaite) :
  gen    [--only nom,nom] [--retry]  4 graines par image -> C:\\AI\\ill1_raw\\<nom>_s<graine>.png + planches de variantes (C:\\AI\\ill1_raw\\var_<nom>.jpg)
  export                   la variante choisie (CHOICES) -> conception/art/ill/<nom>.jpg (<= 400 Ko, taille finale)
  sheet                    planche de contact conception/art/ill/planche.jpg
Exemple : C:\\AI\\venv_comfy\\Scripts\\python.exe tools/art/ill_batch.py gen
Les images sont générées en 1536x512 (cartes, 3:1) ou 1344x768 (16:9) puis réduites à 960x320 / 1600x900 (export).
Aucun texte dans l'image : le négatif l'interdit et chaque variante est relue à l'oeil.
"""
import argparse
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import comfy_gen  # noqa: E402
import gen_with_lora as g  # noqa: E402

ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
RAW = r"C:\AI\ill1_raw"
OUT = os.path.join(ROOT, "conception", "art", "ill")
LORA = "eden_style_v0b.safetensors"
STRENGTH = 0.5
STEPS, CFG = 30, 6.5
N_SEEDS = 4

STYLE = ("edenstyle, colorful anime fantasy game illustration, 3D toon look, soft pastel lighting, vivid saturated colors, "
         "clean outlines, wide scenic composition, highly detailed, no text")
NEG = ("text, letters, words, writing, watermark, logo, signature, ui, interface, photo, photorealistic, blurry, lowres, "
       "jpeg artifacts, deformed, bad hands, extra fingers, extra limbs, distorted face, ugly, dark, gloomy, black background")

CARD = (1536, 512, (960, 320))   # carte d'activité
WIDE = (1344, 768, (1600, 900))  # plein écran 16:9

# (nom, format, couleur dominante de la bible, prompt). Graine de base = 1000 + 10 * rang.
IMAGES = [
    # --- cartes d'activité (ids de game/scripts/ui/activities.gd) ---
    ("survival", CARD, "Survie : lagon et pomme",
     "a small stylish hero with a sword on a grassy hill in a sunny forest valley, a horde of cute round monsters (orange bears, teal goblins, "
     "lilac jellyfish) charging toward the hero across flower meadows, a wooden cottage and big pine trees, bright blue sky, glowing treasure chests"),
    ("survivor", CARD, "Survivant : mandarine et améthyste",
     "a lone hero in the center of a grassy clearing surrounded by an endless ring of cute round monsters, swirling magic orbs and golden sparks "
     "flying around the hero, glowing blue experience gems on the ground, orange and purple sunset sky"),
    ("dungeon", CARD, "Donjons : mandarine et améthyste",
     "grand fantasy dungeon hall entrance with huge stone arch, warm torches with orange flames, red banners, a glowing treasure chest on stairs, "
     "purple crystals, a big friendly-looking monster boss silhouette in the far depth, colorful toon fantasy"),
    ("tower", CARD, "La Tour : lagon et soleil",
     "an enormous slender fantasy tower rising through the clouds into a bright blue and golden sky, spiral stairs and floating platforms, "
     "golden light at the top, seen from below, flying birds, pastel clouds"),
    ("quests", CARD, "Quêtes : soleil",
     "cozy adventurers guild notice board covered with colorful quest parchments and red wax seals, a small golden compass, a quill and an inkwell, "
     "warm lantern light, wooden beams, sunny window"),
    ("trials", CARD, "Épreuves : lagon et soleil",
     "a training stadium with colorful wooden target dummies, medals of bronze silver and gold on a rack, floating hourglass, "
     "sunny sports field, flags, bright blue sky"),
    ("rush", CARD, "Ruée des boss : fraise et mandarine",
     "a long stone arena road lined with eight huge colorful boss monsters statues, a flaming red portal at the end, "
     "sparks and flying embers, dramatic orange sunset sky, banners"),
    ("siege", CARD, "Le Siège : mandarine et fraise",
     "a fantasy castle wall under siege, waves of cute monsters pushing siege towers, a giant boss beast in the distance, "
     "catapults, cannon smoke, red and orange sky at dusk, banners"),
    ("autochess", CARD, "L'Échiquier : améthyste et soleil",
     "a magnificent golden hexagonal tactical game board floating in a circular fantasy arena at dusk, tiny glowing hero figurines "
     "and monster figurines standing on the hexagon tiles, golden runes, purple and midnight blue sky with stars, empty stone stands"),
    ("duel", CARD, "Duel : fraise et soleil",
     "two fantasy fighters facing each other from far away on a round stone dueling platform, crossed swords energy, sparks between them, "
     "cheering crowd silhouettes, red and gold banners, bright sky"),
    ("arenas", CARD, "Arènes : lagon contre fraise",
     "two teams of heroes facing each other in a grand colosseum, blue banners on the left and red banners on the right, glowing magic circle "
     "on the sand, crowds in the stands, colorful confetti, evening sky"),
    ("royale", CARD, "Battle royale : lagon et pomme",
     "high aerial view of a lush fantasy island with forests, ruins and a small village, tiny heroes parachuting and gliding down, "
     "a gigantic glowing blue magical storm wall closing from the sea, golden light beams where treasure fell, bright clouds"),
    ("training", CARD, "Entraînement : pomme",
     "a peaceful training ground with wooden practice dummies, archery targets, weapon racks and training swords, a sunny green meadow, "
     "tents, flags, soft morning light"),
    # --- écran titre et menu principal (plein écran) ---
    ("titre", WIDE, "Titre : lagon, soleil, rose",
     "epic fantasy world panorama, a lone hero with a long cape seen from behind standing on a cliff looking at a vast colorful kingdom with "
     "floating islands, a giant glowing tree, distant castle, rivers and rainbow light, golden sunrise, empty sky space on top for a logo"),
    ("menu", WIDE, "Menu principal : pastel doux",
     "a cozy fantasy town square seen from a distance in soft evening light, round-roofed colorful houses, lanterns, a fountain, "
     "bridge over a river, small birds, quiet empty foreground, calm pastel atmosphere, wide view"),
    # --- écrans de fin ---
    ("fin_victoire", WIDE, "Victoire : soleil et confettis",
     "triumphant sunrise over a green valley, golden rays of light bursting from behind distant mountains, colorful confetti and sparkles in the air, "
     "a waving victory banner and a glowing golden trophy on a stone pedestal, joyful atmosphere"),
    ("fin_defaite", WIDE, "Défaite : bleu doux, braises",
     "a quiet battlefield at dusk after the fight, a broken sword stuck in the ground, fallen banner, soft blue and lilac twilight sky, "
     "a few glowing embers, gentle melancholic but not dark mood, flowers growing between stones"),
    ("fin_record", WIDE, "Record : soleil et améthyste",
     "a glowing golden crown floating above a podium on a hilltop, magical stars and shooting stars, purple and golden sky with aurora, "
     "sparkles, ribbons, celebratory mood"),
    ("fin_boss", WIDE, "Boss vaincu : mandarine et pomme",
     "a huge defeated cute monster boss dissolving into sparkles and golden light in a ruined arena, treasure chests and gems raining down, "
     "bright orange and green glow, floating crystals"),
    ("fin_egalite", WIDE, "Fin neutre : lilas et crème",
     "a calm peaceful lake at twilight with a wooden bridge, floating lanterns reflecting in the water, soft lilac and cream sky, "
     "fireflies, gentle ending mood, quiet scenic view"),
    ("fin_etoiles", WIDE, "Étoiles d'époque : soleil et lagon",
     "a vast starry night sky full of colorful shining stars and constellations above a peaceful moonlit meadow, a golden star trail, "
     "glowing blue and gold sparkles, magical wonder mood"),
]

# Second tour (après relecture : le sujet manquait) : prompts renforcés, sujet en tête, 4 graines de plus (base + 500).
RETRY = {
    "survival": "(a horde of many cute round monsters:1.4) charging across a flower meadow toward a small hero with a glowing sword, "
                "orange bears, teal goblins and lilac jellyfish monsters, wooden cottage and pine trees behind, bright blue sky, glowing treasure chests",
    "survivor": "(a small hero in the center surrounded by a huge circle of many cute round monsters:1.4), swirling golden sparks and magic orbs, "
                "glowing blue experience gems scattered on the grass, orange and purple sunset sky, seen from a distance",
    "quests": "(a big wooden quest notice board covered with many colorful parchments and red wax seals:1.4), a golden compass, rolled scrolls "
              "and a feather quill on a table in front, in a sunny village square with a guild hall behind",
    "siege": "(a fantasy castle wall under siege by waves of many cute monsters:1.4), a giant orange boss beast roaring in front of the gate, "
             "wooden siege towers, catapults, smoke, banners, red and orange dusk sky",
    "royale": "(an enormous glowing blue magical storm wall:1.4) swallowing the edge of a lush fantasy island, tiny heroes running and gliding "
              "across forests and ruins, golden light beams from treasure chests, aerial view",
}
RETRY_OFFSET = 500

# Variante retenue (graine) par image : remplie après relecture des planches de variantes.
CHOICES = {
    "survival": 1502, "survivor": 1510, "dungeon": 1023, "tower": 1033, "quests": 1540, "trials": 1051,
    "rush": 1062, "siege": 1570, "autochess": 1081, "duel": 1092, "arenas": 1103, "royale": 1610, "training": 1122,
    "titre": 1130, "menu": 1142,
    "fin_victoire": 1151, "fin_defaite": 1161, "fin_record": 1171, "fin_boss": 1180, "fin_egalite": 1191, "fin_etoiles": 1200,
}


def info(name):
    for i, (n, fmt, col, prompt) in enumerate(IMAGES):
        if n == name:
            return i, fmt, col, prompt
    raise KeyError(name)


def seeds_for(n, retry=False):
    base = 1000 + 10 * info(n)[0] + (RETRY_OFFSET if retry else 0)
    return [base + k for k in range(N_SEEDS)]


def gen(only, host, retry=False):
    os.makedirs(RAW, exist_ok=True)
    comfy_gen.api(host, "/system_stats")
    for n, fmt, col, prompt in IMAGES:
        if (only and n not in only) or (retry and n not in RETRY):
            continue
        paths = []
        for seed in seeds_for(n, retry):
            name = f"{n}_s{seed}"
            dst = os.path.join(RAW, name + ".png")
            if not os.path.isfile(dst):
                text = (RETRY[n] + ", " + STYLE) if retry else (STYLE + ", " + prompt)
                wf = g.build(LORA, STRENGTH, text, NEG, seed, fmt[0], fmt[1], STEPS, CFG, "ill1_" + name, None)
                path, dt = g.run(host, wf, RAW, name, 900)
                with open(os.path.join(RAW, "log.jsonl"), "a", encoding="utf-8") as f:
                    f.write(json.dumps({"name": name, "seed": seed, "seconds": dt}) + "\n")
                print(name, dt, "s", flush=True)
            paths.append(dst)
        variants_sheet(n + ("_v2" if retry else ""), paths)


def variants_sheet(n, paths):
    from PIL import Image
    ims = [Image.open(p).convert("RGB") for p in paths if os.path.isfile(p)]
    if not ims:
        return
    w = 960
    ims = [im.resize((w, int(im.height * w / im.width))) for im in ims]
    cols = 2
    rows = (len(ims) + 1) // 2
    sheet = Image.new("RGB", (w * cols, ims[0].height * rows), (24, 22, 32))
    for j, im in enumerate(ims):
        sheet.paste(im, ((j % cols) * w, (j // cols) * ims[0].height))
    sheet.save(os.path.join(RAW, f"var_{n}.jpg"), quality=85)


def export():
    from PIL import Image
    os.makedirs(OUT, exist_ok=True)
    for n, seed in CHOICES.items():
        _, fmt, _, _ = info(n)
        im = Image.open(os.path.join(RAW, f"{n}_s{seed}.png")).convert("RGB").resize(fmt[2], Image.LANCZOS)
        dst = os.path.join(OUT, n + ".jpg")
        q = 90
        while True:
            im.save(dst, quality=q, optimize=True, progressive=True)
            if os.path.getsize(dst) <= 400_000 or q <= 60:
                break
            q -= 5
        print(n, seed, os.path.getsize(dst) // 1024, "Ko, q", q)


def sheet():
    from PIL import Image, ImageDraw, ImageFont
    names = [n for n in (x[0] for x in IMAGES) if os.path.isfile(os.path.join(OUT, n + ".jpg"))]
    cw, chh = 520, 292
    cols = 3
    rows = (len(names) + cols - 1) // cols
    sh = Image.new("RGB", (cols * cw, rows * (chh + 30)), (24, 22, 32))
    d = ImageDraw.Draw(sh)
    try:
        font = ImageFont.truetype("arial.ttf", 18)
    except OSError:
        font = ImageFont.load_default()
    for j, n in enumerate(names):
        im = Image.open(os.path.join(OUT, n + ".jpg")).convert("RGB")
        im.thumbnail((cw - 8, chh - 4), Image.LANCZOS)
        x, y = (j % cols) * cw, (j // cols) * (chh + 30)
        sh.paste(im, (x + 4 + (cw - 8 - im.width) // 2, y + 30))
        d.text((x + 8, y + 5), f"{n}  (graine {CHOICES.get(n)})", fill=(235, 215, 150), font=font)
    sh.save(os.path.join(OUT, "planche.jpg"), quality=56, optimize=True)
    print("planche", os.path.getsize(os.path.join(OUT, "planche.jpg")) // 1024, "Ko")


if __name__ == "__main__":
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("step", choices=["gen", "export", "sheet"])
    ap.add_argument("--only", default="")
    ap.add_argument("--retry", action="store_true", help="second tour : prompts RETRY, graines + 500")
    ap.add_argument("--host", default="127.0.0.1:8188")
    a = ap.parse_args()
    only = [s for s in a.only.split(",") if s]
    if a.step == "gen":
        gen(only, a.host, a.retry)
    elif a.step == "export":
        export()
    else:
        sheet()
