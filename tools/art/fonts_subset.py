#!/usr/bin/env python3
"""Polices de l'interface (bible de style v2, § 4) : télécharge Mochiy Pop One et M PLUS Rounded 1c (google/fonts,
SIL OFL 1.1, aucun nom réservé), garde le latin (accents français, Œ œ Ç « », €) et les signes utilisés par le jeu
(× → ▲ ▼ ★ ✔ ✕ › …), écrit des .woff2 dans game/assets/fonts/ avec les licences.

    python tools/art/fonts_subset.py            # demande fonttools + brotli (pip install fonttools brotli)

Les fichiers complets portent les glyphes japonais (3 à 5 Mo par graisse) ; les sous-ensembles font 20 à 40 Ko.
Un signe manquant (⚔, 🔒…) est dessiné par les polices de secours (UiTheme : M PLUS Rounded, Nunito, puis le système).
"""
import shutil
import subprocess
import sys
import tempfile
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "game" / "assets" / "fonts"
BASE = "https://github.com/google/fonts/raw/main/ofl/"
# Latin, latin étendu A, ponctuation, €, symboles de lettres, flèches, maths, filets, formes, symboles, dingbats.
TEXTE = ("U+0020-007E,U+00A0-017F,U+0192,U+02C6-02DC,U+2000-206F,U+20AC,U+2100-2150,U+2190-21FF,U+2200-22FF,"
         "U+2500-257F,U+25A0-25FF,U+2600-26FF,U+2700-27BF,U+FF0B")
TITRE = "U+0020-007E,U+00A0-017F,U+0192,U+02C6-02DC,U+2000-206F,U+20AC,U+2190-2193,U+00D7"
POLICES = [
    ("mplusrounded1c/MPLUSRounded1c-Medium.ttf", "MPLUSRounded1c-Medium.woff2", TEXTE),
    ("mplusrounded1c/MPLUSRounded1c-Bold.ttf", "MPLUSRounded1c-Bold.woff2", TEXTE),
    ("mplusrounded1c/MPLUSRounded1c-ExtraBold.ttf", "MPLUSRounded1c-ExtraBold.woff2", TEXTE),
    ("mplusrounded1c/MPLUSRounded1c-Black.ttf", "MPLUSRounded1c-Black.woff2", TEXTE),
    ("mochiypopone/MochiyPopOne-Regular.ttf", "MochiyPopOne-Regular.woff2", TITRE),
]


def main() -> None:
    try:
        from fontTools import subset  # noqa: F401
    except ImportError:
        sys.exit("pip install fonttools brotli")
    tmp = Path(tempfile.mkdtemp(prefix="eden_fonts_"))
    for src, dest, plage in POLICES:
        ttf = tmp / Path(src).name
        urllib.request.urlretrieve(BASE + src, ttf)
        subprocess.run([sys.executable, "-m", "fontTools.subset", str(ttf), f"--unicodes={plage}",
                        "--layout-features=*", "--flavor=woff2", f"--output-file={OUT / dest}"], check=True)
        print(dest, (OUT / dest).stat().st_size, "octets")
    # Licences : celle de Mochiy est publiée telle quelle ; celle de M PLUS Rounded est dans la police (nom 0 et 13).
    lic = tmp / "OFL-Mochiy.txt"
    urllib.request.urlretrieve(BASE + "mochiypopone/OFL.txt", lic)
    shutil.copy(lic, OUT / "OFL-MochiyPopOne.txt")
    corps = lic.read_text(encoding="utf-8").split("\n", 1)[1]
    (OUT / "OFL-MPLUSRounded1c.txt").write_text("Copyright 2016 The Rounded M+ Project Authors.\n" + corps, encoding="utf-8")
    shutil.rmtree(tmp, ignore_errors=True)


if __name__ == "__main__":
    main()
