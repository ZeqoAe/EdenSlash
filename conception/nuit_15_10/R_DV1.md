# R_DV1 : outillage du dépôt (intégration continue, contrôle des scripts, lint, LFS)

## Ce qui est en place
| Fichier | Rôle |
|---|---|
| `tools/check_scripts.py` (+ pilote `tools/check_scripts.gd`) | Chaque script GDScript compile-t-il ? 40-60 s, sans importer les assets : copie légère des scripts, cache des `class_name` **recalculé depuis les sources** (un `class_name` ajouté sans `--import` ne fausse plus rien), compilation par Godot. Contrôles en plus : chemins `res://` des scènes et des `preload` absents ou de **casse différente** (l'export et Linux la respectent), `class_name` en double. Erreurs triées : causes d'abord, cascade résumée. `--head` : état de HEAD ; `--projet game --scenes` : charge aussi les 200 scènes dans un projet importé (sert à l'intégration continue). |
| `Envoyer.bat` | Lance `check_scripts.py` avant `git add -A` ; si rouge : « Envoyer quand même [N,O] ? » (N par défaut annule, rien n'est envoyé). Sans Python, l'envoi se fait comme avant. |
| `.github/workflows/controle.yml` (+ `.github/actions/godot/`) | Intégration continue, voir ci-dessous. |
| `tools/lint.py` + `.gdlintrc` | Rapport gdlint (gdtoolkit 4.5.0) par règle et par fichier, **informatif** ; venv dédié hors du dépôt `~/.eden_tools/gdtoolkit_venv` (`python tools/lint.py --installer`), pas celui de l'IA. Aucun `gdformat` lancé. |
| `tools/ci_summary.py` | Tableau des tests (`rapport.json` de `run_tests.py`) dans le résumé d'une exécution. |

### Intégration continue (GitHub Actions, onglet « Actions » du dépôt, flux « Contrôle »)
- **À chaque push** sur `claude/optimistic-gauss-p2g2pq` touchant `game/**`, `tools/**` (pas `conception/**` seul) ; un push plus
  récent annule le contrôle en cours de la même branche. Trois tâches :
  1. **Scripts** (≈ 2 min) : extraction partielle (scripts seulement, pas les 1,6 Go d'assets), Godot 4.7.2 Linux (SHA-512
     vérifiée, en cache), `check_scripts.py`, puis lint informatif (ne rend jamais l'exécution rouge).
  2. **Import** : cache de `game/.godot` (≈ 1,1 Go) dont la clé est l'empreinte des assets importables ; s'il existe déjà
     (cas courant), la tâche dure quelques secondes. Sinon import (incrémental à partir du dernier cache) puis enregistrement ;
     la toute première fois, import complet : long.
  3. **Tests rapides** (15 min au plus) : scènes chargées dans le projet importé, puis 12 tests courts avec `run_tests.py --live -j 3`
     (`test_build`, `test_hud`, `test_controls`, `test_cards`, `test_progress`, `test_texts_fr`, `test_names_fr`, `test_items`,
     `test_quests`, `test_compass`, `test_journal`, `test_tooltips` ; liste `TESTS_RAPIDES` en tête du flux).
- **Suite complète** : bouton « Run workflow » (champ « filtres » facultatif) et chaque dimanche 1 h UTC, `run_tests.py -j 2`
  (délais ×1,5), journaux en artefact.

## Ce qui demande une action du joueur
1. **Suite du dimanche et bouton « Run workflow »** : GitHub ne les propose que si le flux est sur la **branche par défaut**
   (aujourd'hui `master`, vieille du 12/10). Au choix : sur github.com, Settings > General > Default branch >
   `claude/optimistic-gauss-p2g2pq` (le plus simple, rien d'autre ne change), ou copier le dossier `.github/` sur `master`.
   Le contrôle à chaque push marche sans cela.
2. **Première exécution** : l'import complet des assets (14 500 fichiers) n'a jamais tourné sur une machine Linux de GitHub ;
   sa durée sera lue dans le résumé de la tâche « Import » (« Import des assets : N min »). Au-delà de 2 h 15, la tâche enregistre
   ce qui est fait et échoue (« Import des assets INACHEVÉ ») : bouton « Re-run jobs », l'import reprend où il en était.
3. `gh` (GitHub CLI) est installé mais **non connecté** (`gh auth login` pour lire les exécutions en ligne de commande :
   `gh run list`, `gh run view --log-failed`).

## Coût en minutes
Dépôt **public** : minutes illimitées et gratuites sur les machines standard de GitHub ; seule limite, 10 Go de cache par dépôt
(un cache d'import ≈ 1,1 Go, les plus vieux sont effacés seuls). Un push coûte ≈ 2 min (scripts) + quelques secondes (import en
cache) + 6-10 min (tests rapides), une suite complète 2-4 h par semaine. Si le dépôt devenait **privé** (2 000 min/mois en Free),
ces ≈ 12 min par push épuiseraient le quota en ~160 pushes : il faudrait alors garder la seule tâche « Scripts » au push
(supprimer `push` de la condition de la tâche `tests`).

## Lire une exécution rouge
- Onglet Actions > l'exécution > **Summary** : un tableau par tâche (« Contrôle des scripts », « Tests rapides »), erreurs
  rangées « fichier / ligne / erreur » ; les annotations pointent la ligne dans le fichier.
- **Scripts rouge** = un script ne compile pas : le jeu est cassé pour tout le monde ; corriger la première cause (la cascade
  disparaît avec). Même contrôle en local : `python tools/check_scripts.py`.
- **Tests rapides rouge** : colonne « Détail » = première ligne `ÉCHEC` ; journaux complets dans l'artefact `journaux-tests`.
  Un test vert chez soi mais rouge en CI vient souvent de Linux : **casse des chemins** (`res://Foo.png` pour `foo.png`) ou
  délai plus court (machine plus lente : relancer avant de corriger).
- **Import rouge** : artefact `journal-import`.
- Le lint ne rend jamais rien rouge.

## État du lint (17/10, réglages `.gdlintrc`)
989 avertissements dans 203 fichiers sur 424 : 940 lignes de plus de 160 signes, 12 noms de variables, 12 arguments inutilisés,
8 noms d'arguments, 7 fonctions à plus de 10 retours, 6 `load` en double, 2 expressions sans effet. Désactivées car trop bruyantes
pour la base existante : ordre des définitions (743), méthodes publiques par classe, `else` après `return`. 17 fichiers sont
« non analysables » par gdtoolkit (chaînes sur plusieurs lignes, BOM, `not` après `==`) : Godot les compile très bien.

## Git LFS : pas justifié aujourd'hui
Historique complet : 35 400 blobs, 1,37 Go sur disque, dont 1,12 Go de PNG (12 000 fichiers de ~90 Ko) ; le plus gros fichier
fait 16 Mo (`back_t743a.glb`), trois seulement dépassent 5 Mo (GitHub avertit à 50 Mo, refuse à 100 Mo). LFS ne réduirait pas
le clone (beaucoup de petits fichiers), ajouterait un quota de bande passante LFS (consommé aussi par chaque exécution de
l'intégration continue) et obligerait chaque machine à avoir `git lfs` installé ; migrer l'existant réécrirait l'historique.
Pas de `.gitattributes` LFS ajouté : il ne serait pas sûr pour les clones existants (un poste sans `git lfs` récupérerait des
fichiers pointeurs à la place des assets). À reconsidérer seulement si des fichiers de plus de 50 Mo arrivent (vidéos, cartes
entières) : alors `*.mp4 filter=lfs diff=lfs merge=lfs -text` pour ce seul type, sur un dossier neuf.

## Trouvé en route
- Pendant la passe, `check_scripts.py` a vu `tests/test_sv6.gd` (bloc `match` mal indenté, ligne 86) et `tools/hl_probe.gd`
  (`PackedStringArray.any()`) casser dans le dossier de travail ; corrigés par leurs sessions quelques minutes après.
- Le cache des classes du dossier partagé est souvent en retard (`AutochessRewards`, `HeroLevel`, `SurvivorCardView` absents) :
  c'est la cause des « Identifier X not declared » rouges de `run_tests.py --live` ; le mode léger de `check_scripts.py` n'en
  dépend pas, et `--projet game` le signale (« cache des classes en retard »).
