#!/usr/bin/env python3
"""Lance toute la suite de tests Godot (game/tests/test_*.tscn) sur une copie propre de HEAD.

    python tools/run_tests.py                  # toute la suite, 4 en parallèle, tableau vert / rouge
    python tools/run_tests.py -j 6 -r 3        # 6 en parallèle, chaque test 3 fois (détecte les tests instables)
    python tools/run_tests.py lot9 ideas       # seulement les tests dont le nom contient un de ces mots
    python tools/run_tests.py --live           # sans copie : dans le dossier de travail (modifications comprises)

La copie (dossier temporaire, `--snap` pour en choisir un) reprend game/ tel quel (cache d'import et fichiers ignorés
par git compris, dates conservées : pas de réimport complet), puis remet les fichiers suivis dans l'état de HEAD et retire
les fichiers non suivis : le travail en cours des autres sessions ne perturbe pas la mesure. Chaque exécution a son
propre dossier utilisateur (APPDATA) : aucun profil du joueur n'est lu ni écrit, aucun test n'hérite de l'état d'un autre.
Rapport : <copie>/rapport.json et <copie>/logs/<test>_<n>.log. Code de sortie 0 si tout est vert.
"""
import argparse
import concurrent.futures as cf
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import threading
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
GODOT_DEFAULT = Path.home() / "Godot" / "Godot_v4.7.2-stable_win64_console.exe"

# Planches de capture : elles attendent le rendu d'une vraie fenêtre, ce ne sont pas des tests.
OUTILS = {
    "test_aura": "planche de captures",
    "test_fx": "planche de captures",
    "test_outfit": "planche de captures",
    "test_backs": "planche de captures",
}
# Délai maximal par test (s) ; les tests longs connus ont plus.
TIMEOUT_DEFAUT = 600
TIMEOUTS = {"test_p4_activities": 1500, "test_p18_modes": 1200, "test_siege": 900, "test_p13": 900, "test_royale": 900}

VERT, ROUGE, JAUNE, GRIS, RESET = "\033[32m", "\033[31m", "\033[33m", "\033[90m", "\033[0m"
_print_lock = threading.Lock()


def log(msg: str) -> None:
    with _print_lock:
        print(msg, flush=True)


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


def git(*args: str, binaire: bool = False):
    r = subprocess.run(["git", "-C", str(ROOT), *args], capture_output=True, check=False)
    return r.stdout if binaire else r.stdout.decode("utf-8", "replace")


def preparer_copie(snap: Path) -> Path:
    """Copie de game/ puis remise de l'état de HEAD ; renvoie le dossier du projet."""
    dest = snap / "game"
    t0 = time.time()
    snap.mkdir(parents=True, exist_ok=True)
    log(f"Copie de game/ vers {dest} (1re fois : quelques minutes)...")
    if os.name == "nt":
        # /MIR : ne recopie que ce qui a changé ; dates conservées pour que Godot ne réimporte pas tout.
        r = subprocess.run(["robocopy", str(ROOT / "game"), str(dest), "/MIR", "/MT:16", "/R:1", "/W:1",
                            "/XD", str(ROOT / "game" / "Godot"), "/NFL", "/NDL", "/NJH", "/NJS", "/NP"],
                           capture_output=True)
        if r.returncode >= 8:
            sys.exit("robocopy a échoué : " + r.stdout.decode("cp850", "replace")[-500:])
    else:
        subprocess.run(["rsync", "-a", "--delete", "--exclude=Godot/", f"{ROOT / 'game'}/", f"{dest}/"], check=True)
    # Remise de l'état de HEAD : fichiers suivis modifiés / supprimés -> contenu de HEAD ; ajoutés ou non suivis -> retirés.
    modifies = [p for p in git("diff", "--name-only", "-z", "--no-renames", "HEAD", "--", "game").split("\0") if p]
    non_suivis = [p for p in git("ls-files", "--others", "--exclude-standard", "-z", "--", "game").split("\0") if p]
    rendus = retires = 0
    for p in modifies:
        cible = snap / p
        existe = subprocess.run(["git", "-C", str(ROOT), "cat-file", "-e", f"HEAD:{p}"], capture_output=True).returncode == 0
        if existe:
            cible.parent.mkdir(parents=True, exist_ok=True)
            cible.write_bytes(git("show", f"HEAD:{p}", binaire=True))
            rendus += 1
        elif cible.exists():
            cible.unlink()
            retires += 1
    for p in non_suivis:
        cible = snap / p
        if cible.is_file():
            cible.unlink()
            retires += 1
    log(f"Copie prête en {time.time() - t0:.0f} s : {rendus} fichier(s) remis à l'état de HEAD, {retires} retiré(s).")
    return dest


def env_pour(userdir: Path) -> dict:
    env = dict(os.environ)
    userdir.mkdir(parents=True, exist_ok=True)
    env["APPDATA"] = str(userdir)  # Godot range user:// sous %APPDATA%/Godot/app_userdata/<projet>
    env["XDG_DATA_HOME"] = str(userdir)
    env.pop("EDEN_PROFILE", None)
    return env


def importer(godot: Path, projet: Path, userdir: Path) -> None:
    t0 = time.time()
    log("Import des ressources (--import)...")
    subprocess.run([str(godot), "--headless", "--path", str(projet), "--import"], env=env_pour(userdir / "import"),
                   capture_output=True, timeout=3600)
    log(f"Import fini en {time.time() - t0:.0f} s.")


def tuer(proc: subprocess.Popen) -> None:
    if os.name == "nt":
        subprocess.run(["taskkill", "/F", "/T", "/PID", str(proc.pid)], capture_output=True)
    else:
        proc.kill()


# Ligne d'échec d'un test : « ÉCHEC <libellé> » ou le bilan « Échecs : N » (N > 0) ; « ÉCHECS : 0 » est un succès.
RE_ECHEC = re.compile(r"^(échec\s|echec\s|fail\b|✗|échecs?\s*:\s*[1-9]|echecs?\s*:\s*[1-9])", re.I)
# Script qui ne compile pas (le bruit « Failed loading world.tscn » de fin de test n'en est pas un).
RE_ERREUR_SCRIPT = re.compile(r"(SCRIPT ERROR: Parse Error|Failed to load script|Could not parse global class)")


def lancer_une_fois(godot: Path, projet: Path, travail: Path, nom: str, essai: int, timeout_x: float) -> dict:
    t0 = time.time()
    logf = travail / "logs" / f"{nom}_{essai}.log"
    logf.parent.mkdir(parents=True, exist_ok=True)
    env = env_pour(travail / "ud" / f"{nom}_{essai}")
    limite = TIMEOUTS.get(nom, TIMEOUT_DEFAUT) * timeout_x
    statut, code = "OK", 0
    with open(logf, "wb") as f:
        proc = subprocess.Popen([str(godot), "--headless", "--path", str(projet), f"res://tests/{nom}.tscn"], env=env,
                                stdout=f, stderr=subprocess.STDOUT)
        try:
            code = proc.wait(timeout=limite)
        except subprocess.TimeoutExpired:
            tuer(proc)
            proc.wait()
            statut, code = "DÉLAI", -1
    shutil.rmtree(travail / "ud" / f"{nom}_{essai}", ignore_errors=True)
    texte = logf.read_text("utf-8", "replace")
    lignes = texte.splitlines()
    echecs = [l.strip() for l in lignes if RE_ECHEC.match(l.strip())]
    erreurs_script = [l.strip() for l in lignes if RE_ERREUR_SCRIPT.search(l)]
    nb_erreurs = sum(1 for l in lignes if l.startswith(("ERROR:", "SCRIPT ERROR:")))
    if statut == "OK":
        if echecs or erreurs_script:
            statut = "ROUGE"
        elif code != 0:
            # Code non nul sans aucune ligne d'échec : le processus a été tué ou a planté (une autre session qui
            # nettoie ses Godot avec `taskkill`, mémoire saturée...) ; ce n'est pas le verdict du test.
            statut = "COUPÉ"
    detail = (echecs or erreurs_script or [""])[0][:110]
    if statut == "COUPÉ":
        detail = f"processus interrompu (code {code}), sans ligne d'échec"
    return {"test": nom, "essai": essai, "statut": statut, "code": code, "duree": round(time.time() - t0, 1),
            "echecs": len(echecs), "erreurs": nb_erreurs, "detail": detail, "log": str(logf)}


def lancer(godot: Path, projet: Path, travail: Path, nom: str, essai: int, timeout_x: float, relances: int = 2) -> dict:
    """Une exécution ; un processus interrompu (COUPÉ) est relancé jusqu'à `relances` fois avant d'être compté rouge."""
    for n in range(relances + 1):
        r = lancer_une_fois(godot, projet, travail, nom, essai, timeout_x)
        r["relances"] = n
        if r["statut"] != "COUPÉ":
            return r
    r["statut"] = "ROUGE"
    r["detail"] = f"interrompu {relances + 1} fois de suite (plantage ?) : " + r["detail"]
    return r


def main() -> int:
    for flux in (sys.stdout, sys.stderr):
        try:
            flux.reconfigure(encoding="utf-8", errors="replace")
        except Exception:
            pass
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("filtres", nargs="*", help="mots du nom des tests à lancer (tous si absent)")
    ap.add_argument("-j", "--jobs", type=int, default=4, help="parallélisme (défaut 4)")
    ap.add_argument("-r", "--repeat", type=int, default=1, help="exécutions par test (3 pour chercher les tests instables)")
    ap.add_argument("--snap", help="dossier de la copie (défaut : <temp>/eden_tests)")
    ap.add_argument("--reuse", action="store_true", help="réutiliser la copie telle quelle (sans la rafraîchir)")
    ap.add_argument("--live", action="store_true", help="tester le dossier de travail lui-même, sans copie")
    ap.add_argument("--godot", help="chemin de Godot (console)")
    ap.add_argument("--timeout-x", type=float, default=1.0, help="multiplicateur des délais")
    ap.add_argument("--skip", nargs="*", default=[], help="tests à ignorer")
    a = ap.parse_args()

    godot = trouver_godot(a.godot)
    if a.live:
        projet, travail = ROOT / "game", Path(tempfile.mkdtemp(prefix="eden_tests_run_"))
    else:
        travail = Path(a.snap) if a.snap else Path(tempfile.gettempdir()) / "eden_tests"
        projet = travail / "game" if a.reuse and (travail / "game").exists() else preparer_copie(travail)
    importer(godot, projet, travail)

    # Dans la copie, seuls les tests versionnés existent (ceux d'une autre session, non poussés, en sont absents).
    tous = sorted(p.stem for p in (projet / "tests").glob("test_*.tscn"))
    choisis = [t for t in tous if t not in OUTILS and t not in a.skip and (not a.filtres or any(f in t for f in a.filtres))]
    log(f"{len(choisis)} test(s) x {a.repeat}, {a.jobs} en parallèle. Outils exclus : {', '.join(sorted(OUTILS))}.")

    taches = [(t, i + 1) for i in range(a.repeat) for t in sorted(choisis, key=lambda t: -TIMEOUTS.get(t, 0))]
    resultats: list[dict] = []
    debut = time.time()

    def une(t_i):
        try:
            r = lancer(godot, projet, travail, t_i[0], t_i[1], a.timeout_x)
        except Exception as e:  # ne jamais perdre le tableau pour une erreur d'outil
            r = {"test": t_i[0], "essai": t_i[1], "statut": "OUTIL", "code": -2, "duree": 0.0, "echecs": 0, "erreurs": 0,
                 "detail": f"erreur du lanceur : {e}"[:110], "log": ""}
        couleur = VERT if r["statut"] == "OK" else ROUGE
        rel = f" (relancé {r['relances']}x)" if r.get("relances") else ""
        log(f"{couleur}{r['statut']:6}{RESET} {r['test']}#{r['essai']} {r['duree']:6.1f} s{rel}  {GRIS}{r['detail']}{RESET}")
        return r

    with cf.ThreadPoolExecutor(max_workers=a.jobs) as ex:
        for r in ex.map(une, taches):
            resultats.append(r)

    # Tableau final : une ligne par test, une colonne par exécution.
    log("\n" + "=" * 78)
    par_test: dict[str, list[dict]] = {}
    for r in resultats:
        par_test.setdefault(r["test"], []).append(r)
    rouges, instables = [], []
    for t in sorted(par_test):
        rs = sorted(par_test[t], key=lambda r: r["essai"])
        ok = sum(r["statut"] == "OK" for r in rs)
        if ok == len(rs):
            marque, c = "VERT", VERT
        elif ok == 0:
            marque, c = "ROUGE", ROUGE
            rouges.append(t)
        else:
            marque, c = "INSTABLE", JAUNE
            instables.append(t)
        cases = " ".join(("." if r["statut"] == "OK" else "X") for r in rs)
        duree = max(r["duree"] for r in rs)
        det = next((r["detail"] for r in rs if r["statut"] != "OK"), "")
        log(f"{c}{marque:8}{RESET} {t:24} {cases:8} {duree:7.1f} s  {GRIS}{det}{RESET}")
    log("=" * 78)
    total = len(par_test)
    log(f"{VERT}{total - len(rouges) - len(instables)} vert(s){RESET}, {ROUGE}{len(rouges)} rouge(s){RESET}, "
        f"{JAUNE}{len(instables)} instable(s){RESET} sur {total} tests, en {time.time() - debut:.0f} s.")
    (travail / "rapport.json").write_text(json.dumps(resultats, ensure_ascii=False, indent=1), "utf-8")
    log(f"Détail : {travail / 'rapport.json'} ; journaux : {travail / 'logs'}")
    return 1 if rouges or instables else 0


if __name__ == "__main__":
    sys.exit(main())
