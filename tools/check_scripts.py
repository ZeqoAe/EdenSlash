#!/usr/bin/env python3
"""Contrôle d'analyse : chaque script GDScript du jeu compile-t-il ? (≈ 1 min, sans importer les assets)

    python tools/check_scripts.py              # dossier de travail tel quel (ce que Envoyer.bat enverrait)
    python tools/check_scripts.py --head       # état de HEAD (ce qui est déjà poussé), sans le travail en cours
    python tools/check_scripts.py --projet game --scenes   # dans un projet déjà importé : charge aussi les scènes

Mode léger (défaut) : copie les seuls fichiers texte utiles (project.godot, *.gd, shaders, scènes) dans un dossier
temporaire, y écrit le cache des classes (`class_name`) recalculé à partir des sources — un `class_name` ajouté sans
`--import` ne fausse donc pas le verdict —, puis Godot y compile chaque script (`tools/check_scripts.gd`). Rien n'est
écrit dans game/ ni dans le dossier utilisateur du joueur (APPDATA détourné). Contrôles statiques en plus : chemins
res:// des scènes (ext_resource) et des preload() qui n'existent pas (ou pas avec la même casse : l'export Godot et
Linux la respectent), deux scripts qui déclarent le même class_name.

Mode complet (--projet <dossier importé> --scenes) : utilisé par l'intégration continue après `--import` : charge
aussi chaque scène de scenes/, tests/ et tools/ (dépendances comprises).

Code de sortie : 0 si tout compile, 1 sinon (liste des erreurs « fichier:ligne : message »).
--github : annotations GitHub Actions + tableau dans le résumé de l'exécution ($GITHUB_STEP_SUMMARY).
"""
import argparse
import os
import re
import shutil
import subprocess
import sys
import tempfile
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
GAME = ROOT / "game"
DRIVER = Path(__file__).resolve().parent / "check_scripts.gd"
GODOT_DEFAULT = Path.home() / "Godot" / "Godot_v4.7.2-stable_win64_console.exe"
# Fichiers copiés dans le projet léger (texte seulement : aucune ressource importée).
COPIE_EXT = (".gd", ".gdshader", ".gdshaderinc", ".tscn", ".tres")
SCENES_DIRS = ("scenes", "tests", "tools")

RE_CLASS = re.compile(r"^\s*class_name\s+([A-Za-z_]\w*)", re.M)
RE_EXTENDS = re.compile(r"^\s*(?:class_name\s+\w+\s+)?extends\s+(\"[^\"]+\"|'[^']+'|[A-Za-z_][\w.]*)", re.M)
RE_EXT_RES = re.compile(r'^\[ext_resource[^\]]*?\spath="(res://[^"]+)"', re.M)
RE_PRELOAD = re.compile(r'preload\(\s*"(res://[^"]+)"\s*\)')
# Messages d'erreur de compilation (jamais les erreurs d'exécution des autoloads : « SCRIPT ERROR: Invalid call... »).
RE_COMPILE = re.compile(r"(Parse Error|Compile Error|Failed to load script|Could not parse global class|"
                        r"Could not resolve|ECHEC_SCRIPT|ECHEC_SCENE)")
# Erreurs de chargement : comptées seulement pendant le contrôle (les autoloads tournent, eux, sans assets importés).
RE_CHARGEMENT = re.compile(r"(Failed loading resource|Cannot open file|No loader found)")
# Erreurs en cascade : conséquences d'une erreur ailleurs (affichées en résumé, après les causes).
RE_CASCADE = re.compile(r"(Failed to compile depended scripts|because of a parser error|doesn't have a set type|"
                        r"^ne se charge pas|^Failed to load script)")
RE_AT = re.compile(r"at:\s.*?\((res://[^():]+?)(?::(\d+))?\)")
RE_RES_LIGNE = re.compile(r"(res://[^\s\"'():]+)(?::(\d+))?")


def trouver_godot(arg: str | None) -> Path:
    for c in (arg, os.environ.get("GODOT")):
        if c and Path(c).exists():
            return Path(c)
    if GODOT_DEFAULT.exists():
        return GODOT_DEFAULT
    for nom in ("godot4", "godot", "Godot_v4.7.2-stable_win64_console"):
        p = shutil.which(nom)
        if p:
            return Path(p)
    sys.exit("Godot introuvable : --godot <exe> ou variable GODOT")


def git(*args: str) -> str:
    r = subprocess.run(["git", "-C", str(ROOT), *args], capture_output=True, check=False)
    return r.stdout.decode("utf-8", "replace")


def liste_des_fichiers(head: bool) -> list[str]:
    """Fichiers de game/ (chemins relatifs) : ceux de HEAD, ou ceux que Envoyer.bat enverrait (suivis non supprimés
    + non suivis non ignorés)."""
    if head:
        noms = git("ls-tree", "-r", "--name-only", "-z", "HEAD", "--", "game").split("\0")
        return [p[len("game/"):] for p in noms if p]
    noms = git("ls-files", "--cached", "--others", "--exclude-standard", "-z", "--", "game").split("\0")
    # Supprimés du dossier de travail (git diff ignore les fichiers hors d'une extraction partielle, comme en CI).
    supprimes = set(git("diff", "--name-only", "--diff-filter=D", "--no-renames", "-z", "--", "game").split("\0"))
    return [p[len("game/"):] for p in noms if p and p not in supprimes]


def contenus(rels: list[str], head: bool) -> dict[str, bytes]:
    """Contenu brut de chaque fichier (HEAD : un seul `git cat-file --batch` ; sinon le disque)."""
    if not head:
        out = {}
        for rel in rels:
            try:
                out[rel] = (GAME / rel).read_bytes()
            except OSError:
                pass
        return out
    entree = "".join(f"HEAD:game/{rel}\n" for rel in rels).encode("utf-8")
    r = subprocess.run(["git", "-C", str(ROOT), "cat-file", "--batch"], input=entree, capture_output=True, check=True)
    data, pos, out = r.stdout, 0, {}
    for rel in rels:
        fin = data.index(b"\n", pos)
        tete = data[pos:fin].split()
        pos = fin + 1
        if len(tete) < 3 or tete[1] == b"missing":
            continue
        taille = int(tete[2])
        out[rel] = data[pos:pos + taille]
        pos += taille + 1
    return out


def cache_des_classes(scripts: dict[str, str]) -> tuple[str, list[str]]:
    """Texte de .godot/global_script_class_cache.cfg recalculé à partir des sources, et doublons de class_name."""
    infos: dict[str, dict] = {}
    par_nom: dict[str, list[str]] = {}
    for rel, src in scripts.items():
        m = RE_CLASS.search(src)
        if not m:
            continue
        nom = m.group(1)
        e = RE_EXTENDS.search(src)
        tete = src[: m.start()]
        infos[rel] = {"class": nom, "base": e.group(1) if e else "RefCounted",
                      "tool": bool(re.search(r"^\s*@tool\b", tete, re.M)),
                      "abstract": bool(re.search(r"^\s*@abstract\b", tete, re.M))}
        par_nom.setdefault(nom, []).append(rel)
    chemins = {f"res://{rel}": rel for rel in infos}

    def base_native(rel: str, vus: set) -> str:
        b = infos[rel]["base"]
        if b[0] in "\"'":  # extends "res://x.gd" : base de la classe parente
            parent = chemins.get(b.strip("\"'"))
            if parent and parent not in vus:
                vus.add(parent)
                return base_native(parent, vus)
            return "RefCounted"
        return b.split(".")[0]

    blocs = []
    for rel in sorted(infos, key=lambda r: infos[r]["class"]):
        i = infos[rel]
        blocs.append("{\n" + ",\n".join([
            f'"base": &"{base_native(rel, {rel})}"', f'"class": &"{i["class"]}"', '"icon": ""',
            f'"is_abstract": {str(i["abstract"]).lower()}', f'"is_tool": {str(i["tool"]).lower()}',
            '"language": &"GDScript"', f'"path": "res://{rel}"']) + "\n}")
    doublons = [f"class_name {n} déclaré {len(v)} fois : " + ", ".join(v) for n, v in par_nom.items() if len(v) > 1]
    return "list=[" + ", ".join(blocs) + "]\n", doublons


def controles_statiques(tous: list[str], textes: dict[str, str]) -> list[tuple[str, int, str]]:
    """Chemins res:// (ext_resource des scènes, preload des scripts) introuvables ou de casse différente."""
    existants = set(tous)
    minuscules = {p.lower(): p for p in existants}
    erreurs = []
    for rel, src in textes.items():
        motif = RE_EXT_RES if rel.endswith((".tscn", ".tres")) else RE_PRELOAD
        for m in motif.finditer(src):
            cible = m.group(1)[len("res://"):]
            if cible in existants:
                continue
            ligne = src.count("\n", 0, m.start()) + 1
            vrai = minuscules.get(cible.lower())
            if vrai:
                erreurs.append((rel, ligne, f"casse différente : {m.group(1)} (le fichier est res://{vrai})"))
            else:
                erreurs.append((rel, ligne, f"fichier introuvable : {m.group(1)}"))
    return erreurs


def lancer_godot(godot: Path, projet: Path, liste: list[str], travail: Path, timeout: int) -> tuple[int, str]:
    (travail / "liste.txt").write_text("\n".join(liste) + "\n", "utf-8")
    ud = travail / "ud"
    ud.mkdir(parents=True, exist_ok=True)
    env = dict(os.environ, APPDATA=str(ud), XDG_DATA_HOME=str(ud), XDG_CONFIG_HOME=str(ud))
    env.pop("EDEN_PROFILE", None)
    cmd = [str(godot), "--headless", "--path", str(projet), "-s", str(DRIVER), "--", str(travail / "liste.txt")]
    try:
        # Une seule sortie (erreurs comprises) pour garder l'ordre : une erreur suit la ligne CHECK_FICHIER de son fichier.
        r = subprocess.run(cmd, env=env, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=timeout)
    except subprocess.TimeoutExpired as e:
        return -1, (e.stdout or b"").decode("utf-8", "replace")
    return r.returncode, r.stdout.decode("utf-8", "replace")


def lire_erreurs(sortie: str) -> list[tuple[str, int, str]]:
    """(fichier relatif à game/, ligne, message) pour chaque erreur de compilation ou de chargement."""
    lignes = sortie.splitlines()
    courant = ""
    erreurs: list[tuple[str, int, str]] = []
    vus = set()
    dans = False
    for i, l in enumerate(lignes):
        s = l.strip()
        if s.startswith("CHECK_DEBUT"):
            dans = True
        if s.startswith("CHECK_FIN"):
            dans = False
        if s.startswith("CHECK_FICHIER "):
            courant = s.split(" ", 1)[1]
            continue
        if not (RE_COMPILE.search(s) or (dans and RE_CHARGEMENT.search(s))):
            continue
        if s.startswith(("ECHEC_SCRIPT ", "ECHEC_SCENE ")):
            chemin, num, msg = s.split(" ", 1)[1], 0, "ne se charge pas (voir les erreurs ci-dessus)"
        else:
            chemin, num = (courant if dans else "(démarrage)"), 0
            suite = lignes[i + 1].strip() if i + 1 < len(lignes) else ""
            m = RE_AT.search(suite) or RE_RES_LIGNE.search(s)
            if m:
                chemin, num = m.group(1), int(m.group(2) or 0)
            msg = re.sub(r"^(SCRIPT ERROR|ERROR):\s*", "", s)
        rel = chemin[len("res://"):] if chemin.startswith("res://") else chemin
        cle = (rel, num, msg)
        if cle not in vus:
            vus.add(cle)
            erreurs.append(cle)
    # Une ligne ECHEC_* / « Failed to load script » n'apporte rien si le fichier a déjà une erreur détaillée.
    def resume(msg: str) -> bool:
        return msg.startswith(("ne se charge pas", "Failed to load script"))
    detail = {e[0] for e in erreurs if not resume(e[2])}
    return [e for e in erreurs if not (resume(e[2]) and e[0] in detail)]


def trier(erreurs):
    """(causes, cascade) : corriger les causes fait disparaître toute la cascade."""
    causes = [e for e in erreurs if not RE_CASCADE.search(e[2])]
    cascade = [e for e in erreurs if RE_CASCADE.search(e[2])]
    return (causes, cascade) if causes else (cascade, [])


def fichiers_en_cascade(cascade) -> str:
    noms = sorted({rel for rel, _, _ in cascade})
    return ", ".join(noms[:15]) + (f"… (+{len(noms) - 15})" if len(noms) > 15 else "")


def resume_github(erreurs, nb_scripts, nb_scenes, duree) -> None:
    causes, cascade = trier(erreurs)
    for rel, num, msg in causes:
        fichier = f"game/{rel}" if not rel.startswith("(") else ""
        loc = f"file={fichier},line={num}," if fichier and num else (f"file={fichier}," if fichier else "")
        print(f"::error {loc}title=Script qui ne compile pas::{msg}")
    chemin = os.environ.get("GITHUB_STEP_SUMMARY")
    if not chemin:
        return
    with open(chemin, "a", encoding="utf-8") as f:
        etat = "vert" if not erreurs else f"ROUGE, {len(causes)} erreur(s) à corriger"
        f.write(f"### Contrôle des scripts : {etat}\n\n{nb_scripts} script(s), {nb_scenes} scène(s), {duree:.0f} s.\n\n")
        if erreurs:
            f.write("| Fichier | Ligne | Erreur |\n|---|---|---|\n")
            for rel, num, msg in causes[:200]:
                f.write(f"| `{rel}` | {num or ''} | {msg.replace('|', '/')} |\n")
            f.write("\n")
            if cascade:
                f.write(f"{len(cascade)} erreur(s) en cascade (disparaissent avec les causes) dans : "
                        f"{fichiers_en_cascade(cascade)}\n\n")


def main() -> int:
    for flux in (sys.stdout, sys.stderr):
        try:
            flux.reconfigure(encoding="utf-8", errors="replace")
        except Exception:
            pass
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--head", action="store_true", help="contrôler HEAD au lieu du dossier de travail")
    ap.add_argument("--projet", help="projet Godot déjà importé à utiliser tel quel (mode complet)")
    ap.add_argument("--scenes", action="store_true", help="charger aussi les scènes (mode complet seulement)")
    ap.add_argument("--godot", help="chemin de Godot (console)")
    ap.add_argument("--timeout", type=int, default=300, help="délai maximal de Godot en secondes (défaut 300)")
    ap.add_argument("--github", action="store_true", help="annotations et résumé GitHub Actions")
    ap.add_argument("--garder", action="store_true", help="garder le dossier temporaire (journal godot.log)")
    ap.add_argument("-v", "--verbose", action="store_true", help="afficher toute la sortie de Godot")
    a = ap.parse_args()
    t0 = time.time()
    godot = trouver_godot(a.godot)

    tous = liste_des_fichiers(a.head)
    utiles = [p for p in tous if not p.startswith((".godot/", "Godot/"))
              and (p.endswith(COPIE_EXT) or p == "project.godot")]
    bruts = contenus(utiles, a.head)
    textes = {p: b.decode("utf-8", "replace") for p, b in bruts.items() if p.endswith((".gd", ".tscn", ".tres"))}
    scripts = {p: s for p, s in textes.items() if p.endswith(".gd")}
    cache, doublons = cache_des_classes(scripts)
    erreurs = controles_statiques(tous, textes)
    erreurs += [("(projet)", 0, d) for d in doublons]

    travail = Path(tempfile.mkdtemp(prefix="eden_check_"))
    nb_scenes = 0
    try:
        liste = [f"res://{p}" for p in sorted(scripts)]
        if a.projet:
            projet = Path(a.projet).resolve()
            # Cache des classes du projet en retard sur les sources (class_name ajouté sans --import) : les erreurs
            # « Identifier X not declared » qui suivent ne viennent pas du code.
            cfg = projet / ".godot" / "global_script_class_cache.cfg"
            connues = set(re.findall(r'"class": &"(\w+)"', cfg.read_text("utf-8", "replace"))) if cfg.exists() else set()
            manquantes = sorted(set(re.findall(r'"class": &"(\w+)"', cache)) - connues)
            if manquantes:
                print(f"ATTENTION : cache des classes de {projet} en retard ({len(manquantes)} class_name absent(s) : "
                      f"{', '.join(manquantes[:8])}) ; lancer Godot --headless --path game --import, ou le mode léger "
                      f"(sans --projet) qui recalcule ce cache.")
            if a.scenes:
                sc = sorted(p for p in tous if p.endswith(".tscn") and p.split("/")[0] in SCENES_DIRS)
                liste += [f"res://{p}" for p in sc]
                nb_scenes = len(sc)
        else:
            if a.scenes:
                print("--scenes demande un projet importé (--projet game) : scènes vérifiées statiquement seulement.")
            projet = travail / "projet"
            for rel, b in bruts.items():
                dest = projet / rel
                dest.parent.mkdir(parents=True, exist_ok=True)
                dest.write_bytes(b)
            (projet / ".godot").mkdir(parents=True, exist_ok=True)
            (projet / ".godot" / "global_script_class_cache.cfg").write_text(cache, "utf-8", newline="\n")
        code, sortie = lancer_godot(godot, projet, liste, travail, a.timeout)
        (travail / "godot.log").write_text(sortie, "utf-8")
        if a.verbose:
            print(sortie)
        erreurs += lire_erreurs(sortie)
        if "CHECK_FIN" not in sortie:
            raison = "délai dépassé" if code == -1 else f"code {code}"
            erreurs.append(("(godot)", 0, f"Godot s'est arrêté avant la fin du contrôle ({raison})"))
    finally:
        if a.garder:
            print(f"Dossier gardé : {travail}")
        else:
            shutil.rmtree(travail, ignore_errors=True)

    duree = time.time() - t0
    quoi = "HEAD" if a.head else (str(a.projet) if a.projet else "dossier de travail")
    if erreurs:
        causes, cascade = trier(erreurs)
        print(f"ROUGE : {len(causes)} erreur(s) à corriger dans {quoi} ({len(scripts)} scripts, {nb_scenes} scènes, "
              f"{duree:.0f} s)")
        for rel, num, msg in causes:
            print(f"  game/{rel}:{num} : {msg}" if num else f"  game/{rel} : {msg}")
        if cascade:
            print(f"  + {len(cascade)} erreur(s) en cascade (disparaissent avec les causes) dans : "
                  f"{fichiers_en_cascade(cascade)}")
    else:
        print(f"VERT : {len(scripts)} scripts compilent, {nb_scenes} scènes chargées, chemins res:// présents "
              f"({quoi}, {duree:.0f} s)")
    if a.github:
        resume_github(erreurs, len(scripts), nb_scenes, duree)
    return 1 if erreurs else 0


if __name__ == "__main__":
    sys.exit(main())
