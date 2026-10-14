# Eden Slash — consignes pour les sessions Claude

Deux sessions travaillent sur ce dépôt : une **locale** (sur le PC, avec le client Eden Eternal,
extraction des assets) et une **cloud** (sans le client). Le joueur ne connaît pas git.

## Chantier en cours
Refonte des menus, mode dev, trophées, zones / monnaies / coffres : faite (0.1.22 à 0.1.26,
état en tête de `A_FAIRE_SESSION_CLOUD.md`) ; reste la validation des menus par le joueur.
Nuit du 14/10 (0.1.89 à 0.1.98) : duel équilibré à tout niveau (voir « Duel (JcJ) ») et mode farm
façon Megabonk (`DESIGN.md`, « Étapes et sources » et « Monnaies, coffres et zones ») : carte remplie
(objets à casser `world/breakables.gd`, sites, plateaux, camps, lieux à usage unique), coffres en
3 qualités qui proposent de l'équipement, run en 3 étapes (portail après le boss). Test :
`tests/test_farm.tscn` ; vues de la carte : `res://tools/map_shots.tscn -- <graine> [zone]`.
Reste : retours du joueur sur le rythme, l'économie de l'or et la lisibilité de la carte.

Menu Jouer (0.1.122) = activités (`scripts/ui/activities.gd`) : JcE (Survie = l'ancienne run de farm,
Tour, Donjons à venir, entraînement) et JcJ (Duel, Arènes 2v2 / 3v3 et Champ de bataille 10v10 à venir),
en étiquettes illustrées par les écrans de chargement d'Eden (`ui/loadingframe/loading_*.dds`, bande
y 112-452 recadrée en 960×320 dans `assets/ui/activities/`) ; un clic ouvre la page de l'activité
(réglages puis Lancer). Une activité nouvelle : une entrée dans `Activities.LIST`, son image, sa page
dans `lobby.gd` (`_show_menu`). La boucle de jeu (équipement choisi pour le JcJ, débloqué en JcE) est
en cours de refonte avec le joueur dans une autre session.

## Branche
Tout se passe sur la branche `claude/optimistic-gauss-p2g2pq`. Ne pas travailler sur `master`.

## Numéro de version (obligatoire à chaque envoi)
À **chaque push** :
1. augmenter de 1 le dernier chiffre de `Version.NUMBER` dans `game/scripts/core/version.gd`
   (0.1.7 → 0.1.8) ;
2. ajouter une ligne dans `CHANGELOG.md` (version, contenu en une phrase, session) ;
3. citer la version dans le message de commit (« 0.1.8 : … »).
Le numéro est affiché en bas à droite de tous les écrans : le joueur s'en sert pour savoir
s'il a la bonne version.

## Avant / après le travail
- Avant de commencer : `git pull --no-rebase` (l'autre session a pu pousser).
- Après : commit, `git pull --no-rebase`, puis `git push`. Ne jamais laisser du travail
  non poussé à la fin d'une session.
- Les fichiers `.uid` créés par l'éditeur Godot peuvent bloquer un pull : les supprimer
  s'ils existent déjà dans le dépôt distant.
- `Mettre_a_jour.bat` met de côté (`git stash -u`) les fichiers modifiés localement avant
  le pull, puis les remet (`git stash pop`). Si un `stash pop` a échoué, le travail local
  est toujours dans `git stash list` : le récupérer avant de continuer.

## Notes du joueur
Alt + clic droit sur n'importe quoi dans le jeu enregistre une note dans `feedback/<date>_note/`
(`rapport.json` : note, type, élément visé, version ; `capture.png` avec un repère rouge).
Le dossier n'est pas dans git : la session locale les lit au début du travail.

## Tests
`Godot --headless --path game res://tests/<test>.tscn` pour test_build, test_hud,
test_controls, test_cards, test_progress (et ceux ajoutés depuis). Après l'ajout d'un
script avec `class_name`, lancer une fois `--import` pour mettre à jour le cache des classes.

## IA d'entraînement (apprentissage par renforcement)
Arène `game/scenes/ml_arena.tscn` (`game/scripts/ml/`) pilotée par Python (`ia/`, voir
`ia/LISEZMOI.md`) : `IA_Entrainer.bat`, `IA_Regarder.bat`. Le héros lit `Player.bot`
(BotInput) à la place du clavier. Ajouter ou retirer une observation dans `ml_arena.gd`
rend les modèles entraînés inutilisables (`--nouveau`). Modèles, journaux et cerveaux
(`game/data/cerveaux/`) hors git. Un seul cerveau joue les 60 classes : l'ordre de
`ML_CLASSES` (ml_arena.gd) et `CLASSES` (ia/curriculum.py) est fixe, ajouter à la fin.

État (13/10) : étapes 1 à 8 réussies (chaque classe bat le hardcore scripté à 70 % ou plus),
étape 9 « Expert » en cours ; relancer `IA_Entrainer.bat` pour continuer (il reprend seul).
Cerveaux prêts dans `game/data/cerveaux/` : debutant, facile, normal, difficile, hardcore,
actuel (`IA_Duel.bat` prend le meilleur). Brancher un adversaire IA (la Tour) :
- héros ennemi = `Player.new()` avec `foe = true`, `class_id`, `level`, `kit_skills` /
  `kit_chains` (comme `MlArena._pick_kit`), `bot = BotInput.new()`, puis `add_child` ;
- cerveau = `MlBrain.load_file("res://data/cerveaux/cerveau_hardcore.json")` ; toutes les
  3 images physiques : `obs` comme `MlArena._obs_for(foe, [joueur], fiche, dernière touche, 0)`,
  `act(obs, temperature)` puis action posée comme `MlArena._apply_for` (à extraire de l'arène
  dans une classe partagée si la Tour s'en sert). `temperature` > 0 : plus faible, plus humain ;
  ~5 ms par décision. Le cerveau est entraîné au niveau 10 sans équipement.

## Duel (JcJ) et profils « opti »
Règles du duel dans `combat/pvp_caps.gd` (échelle des dégâts, défense relative, soins, acharnement,
plafonds) appliquées par `Combatant.take_damage` quand `Duel.active`. Profils générés :
`Godot --headless --path game res://tools/gen_profiles.tscn` (réécrit les profils « auto »: "opti"
de `data/build_profiles.json`, garde ceux du joueur ; `-- warrior` : essai sans écrire). Essai
d'équilibrage : arène d'IA en duel, `res://scenes/ml_arena.tscn -- --scenario=duel --brain=res://data/cerveaux/cerveau_hardcore.json
--episodes=4 --level=90 --hero-build=warrior:90 --foe-build=magician:90` (avec `--fixed-fps 60`).
Cible : 30 s à 1 min 30 par manche entre deux héros optimisés, à tout niveau.
Auto-attaque entre héros : × `PvpCaps.BASIC_MULT`, sans contrôle ni attraction (retour du joueur :
le crochet du Guerrier en boucle était imbattable). L'adversaire scripté prend la fiche d'un vrai
héros (`Duel.rival_sheet` : build opti de sa classe par défaut, × `ClassRival.DUEL_DIFF`) et
critique ; l'adversaire piloté par un cerveau (très fort) est prévu comme défi de fin de jeu.

## Musique
`scripts/core/music.gd` (autoload Music) : pistes OGG copiées du dossier `bgm` du client
(`%LOCALAPPDATA%/EdenReforged/bgm`) dans `game/assets/music/` ; piste d'une zone = colonne bgm
de `c_node` pour sa scène d'Eden (S002 → bgm007…). Ajouter une zone : sa piste dans `Music.ZONES`.

## Graphismes
Réglages d'image communs dans `game/scripts/world/gfx.gd` (qualité graphique), shaders dans
`game/shaders/` (terrain, herbe, personnages, décor, effets). Pour comparer un changement de
rendu : `res://tests/bench_gfx.tscn -- <zone> [effet]` (même vue à chaque fois).
