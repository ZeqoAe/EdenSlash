# Eden Slash — consignes pour les sessions Claude

Deux sessions travaillent sur ce dépôt : une **locale** (sur le PC, avec le client Eden Eternal,
extraction des assets) et une **cloud** (sans le client). Le joueur ne connaît pas git.

## Chantier en cours
Refonte des menus, mode dev, trophées, zones / monnaies / coffres : faite (0.1.22 à 0.1.26,
état en tête de `A_FAIRE_SESSION_CLOUD.md`) ; reste la validation des menus par le joueur.

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

## Tests
`Godot --headless --path game res://tests/<test>.tscn` pour test_build, test_hud,
test_controls, test_cards, test_progress (et ceux ajoutés depuis). Après l'ajout d'un
script avec `class_name`, lancer une fois `--import` pour mettre à jour le cache des classes.

## Graphismes
Réglages d'image communs dans `game/scripts/world/gfx.gd` (qualité graphique), shaders dans
`game/shaders/` (terrain, herbe, personnages, décor, effets). Pour comparer un changement de
rendu : `res://tests/bench_gfx.tscn -- <zone> [effet]` (même vue à chaque fois).
