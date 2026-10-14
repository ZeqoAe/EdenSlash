"""Version à partager d'Eden Slash : un dossier prêt à jouer, zippé.

    python tools/make_release.py        (ou Creer_version.bat)

1. exporte le jeu en un paquet (game/export_presets.cfg, « Windows Desktop ») :
   build/EdenSlash/EdenSlash.pck ;
2. place à côté le moteur Godot renommé EdenSlash.exe : il charge tout seul le paquet du
   même nom (pas besoin des modèles d'export de Godot) ;
3. ajoute LISEZMOI.txt et zippe le tout : build/EdenSlash_v<version>.zip.
Le joueur dézippe et lance EdenSlash.exe : rien à installer.
"""
import os
import re
import shutil
import subprocess
import sys
import zipfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
GODOT_DIR = os.path.join(os.path.expanduser("~"), "Godot")
GODOT = os.path.join(GODOT_DIR, "Godot_v4.7.2-stable_win64.exe")
GODOT_CONSOLE = os.path.join(GODOT_DIR, "Godot_v4.7.2-stable_win64_console.exe")
OUT = os.path.join(ROOT, "build", "EdenSlash")

README = """EDEN SLASH {version}
====================

Jouer : double-clic sur EdenSlash.exe (rien à installer).

Configuration : Windows 10 ou 11 64 bits, carte graphique compatible Vulkan
(la plupart des cartes de moins de 10 ans). Si l'image est trop lourde :
Paramètres > Affichage > Qualité graphique (basse ou moyenne).

Commandes : clavier et souris (touches modifiables dans Paramètres > Touches),
ou manette entièrement (menus compris, sans souris). Les noms des boutons suivent
la manette (Xbox : A B X Y, LB RB LT RT ; PlayStation : Croix Rond Carré Triangle L1 R1 L2 R2).
  En jeu : stick gauche déplacement, stick droit caméra, RB / RT / LB / LT les 4 sorts,
  X attaque, B esquive, Y saut, A interagir, Menu pause, Vue carte, croix : zoom,
  objectifs (gauche) et équiper l'objet trouvé (droite). Tout est réassignable :
  Paramètres > Touches > Manette.
  Dans les menus : croix directionnelle ou stick gauche pour se déplacer (cadre doré),
  A valider, B retour, X clic droit, LB / RB changent d'onglet, stick droit défile,
  Y passe en curseur libre (le stick gauche déplace la souris), et inversement.
F1 en jeu : le Guide (commandes, règles, Premiers pas).

JOUER SUR APPLE TV AVEC STEAM LINK
  1. Sur le PC : Steam > Jeux > Ajouter un jeu non-Steam, choisir EdenSlash.exe.
  2. Sur l'Apple TV : installer l'app « Steam Link », l'associer au PC et brancher la manette.
  3. Lancer le jeu depuis Steam Link. Mets la manette en configuration « Manette » (Xbox)
     dans Steam si elle propose clavier / souris par défaut. Pour un jeu plein écran,
     lance plutôt Jouer_plein_ecran.bat (ajoute-le à Steam à la place de EdenSlash.exe).
  Les boutons affichés sont ceux d'une manette Xbox ; si ce n'est pas le cas :
  Paramètres > Touches > Manette > « Noms ».


Sauvegardes : %APPDATA%\\Godot\\app_userdata\\Eden Slash\\
(gardées quand on remplace le dossier du jeu par une nouvelle version).

Signaler un problème : Alt + clic droit sur ce qui ne va pas, écris ta note.
Elle est rangée dans le dossier « feedback » à côté de EdenSlash.exe :
envoie ce dossier (zippé) à Nico.

Nouvelle version : supprime l'ancien dossier, dézippe le nouveau (les
sauvegardes ne bougent pas).

Eden Slash est un projet de fan, non commercial, inspiré d'Eden Eternal ;
ne pas le redistribuer publiquement.
Moteur : Godot Engine (licence MIT, https://godotengine.org/license).
"""


def version() -> str:
    txt = open(os.path.join(ROOT, "game", "scripts", "core", "version.gd"), encoding="utf8").read()
    return re.search(r'NUMBER := "([^"]+)"', txt).group(1)


def main() -> int:
    v = version()
    print(f"Eden Slash {v} : export du paquet (quelques minutes)...")
    if os.path.isdir(OUT):
        shutil.rmtree(OUT)
    os.makedirs(OUT)
    pck = os.path.join(OUT, "EdenSlash.pck")
    r = subprocess.run([GODOT_CONSOLE, "--headless", "--path", os.path.join(ROOT, "game"),
                        "--export-pack", "Windows Desktop", pck])
    if r.returncode != 0 or not os.path.isfile(pck):
        print("Échec de l'export du paquet.")
        return 1
    shutil.copy2(GODOT, os.path.join(OUT, "EdenSlash.exe"))
    with open(os.path.join(OUT, "Jouer_plein_ecran.bat"), "w", encoding="ascii", newline="\r\n") as f:
        f.write("@echo off\nrem Lance Eden Slash en plein ecran (streaming Steam Link)\ncd /d \"%~dp0\"\nstart \"\" /wait EdenSlash.exe --fullscreen\n")
    with open(os.path.join(OUT, "LISEZMOI.txt"), "w", encoding="utf-8-sig", newline="\r\n") as f:
        f.write(README.format(version=v))
    z = os.path.join(ROOT, "build", f"EdenSlash_v{v}.zip")
    if os.path.exists(z):
        os.remove(z)
    print("Compression du zip...")
    with zipfile.ZipFile(z, "w", zipfile.ZIP_DEFLATED, compresslevel=6, allowZip64=True) as zf:
        for name in sorted(os.listdir(OUT)):
            zf.write(os.path.join(OUT, name), arcname=f"EdenSlash/{name}")
    size = os.path.getsize(z) / (1024 * 1024)
    print(f"Prêt : {z} ({size:.0f} Mo)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
