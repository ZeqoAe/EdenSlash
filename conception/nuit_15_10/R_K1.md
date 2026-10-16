# R_K1 : curseurs de souris et réticule de visée

Demande du joueur : « y a-t-il d'autres curseurs que la vieille souris de base ? ». Le jeu n'avait aucun système de curseur.

## Ce qui est fait
- **Choix du curseur** : Paramètres > Caméra & interface > section « Curseur et visée ». Dix jeux : Classique (les curseurs du système)
  et neuf jeux dessinés au script (`tools/make_cursors.py`, Pillow, aucune image d'ailleurs) : Gantelet (or), Lame, Cristal, Orbe,
  Plume, Flamme, Rune, Étoile, Ombre (violet cerné de clair). Chaque jeu a 4 formes : flèche, main (`CURSOR_POINTING_HAND`, boutons),
  texte (`CURSOR_IBEAM`) et poing (`CURSOR_DRAG` et `CURSOR_CAN_DROP`, glisser), en 32 px, et en 48 px quand l'interface est à 125 %
  ou plus (ou l'écran très défini). Fichiers `game/assets/ui/cursors/<jeu>_<forme>_<32|48>.png`, points chauds dans
  `scripts/ui/cursor_hotspots.gd` (généré, grille de 48 unités). Pose : `CursorSets.apply()` (`Input.set_custom_mouse_cursor`), appelé
  par `Settings` pour les sections `interface` et `display` ; rien n'est fait sans fenêtre (tests, serveur).
- **Réticule de visée** (`ui/aim_reticle.gd`) : en jeu seulement avec la visée Curseur ou le mode Action, jamais en pause, jamais à la
  manette. Point (défaut), croix, cercle ou aucun ; taille 60 à 200 % ; couleur (or, blanc, cyan, rouge, vert, violet). Cerné de sombre pour
  se lire sur fond clair et sombre, centre vide pour la croix et le cercle, `MOUSE_FILTER_IGNORE` : ne gêne aucun clic. Un calque (100)
  créé par `Settings`.
- **Aperçu direct** (`ui/cursor_preview.gd`) : les 4 formes du jeu choisi et le réticule sur fond clair et sombre ; le vrai curseur change
  aussi tout de suite.
- **Réglages** `interface.cursor_set / reticle / reticle_size / reticle_color`, sauvegardés par `Settings` (SafeFile) ; toute valeur
  inconnue ou du mauvais type redonne le défaut (`CursorSets.current()`, `AimReticle.shape()` / `size_factor()` / `color()`).
- Manette : le curseur libre de `UiNav` (touche Y) reste le curseur du système, donc le jeu choisi. Le réticule se cache avec la manette.

## Décisions
- Le réticule est allumé par défaut en « point » (petit, au bout de la flèche) ; « Aucun » le retire.
- Les lueurs des jeux lumineux ne touchent que la flèche (les autres formes remplissent presque l'image).
- Les formes « attente » et « interdit » restent celles du système.

## Ajouter un jeu
1. Dans `tools/make_cursors.py` : une palette, une fonction de flèche et une marque de paume dans `SETS`.
2. `python tools/make_cursors.py [--sheet planche.png]` (PNG + `cursor_hotspots.gd` ; la planche montre tout sur fond clair et sombre).
3. Ajouter `["id", "Nom", "détail"]` à `CursorSets.LIST`, lancer `--import` une fois. Les `.import` des curseurs ne sont pas dans git (`.gitignore`).

## Tests
`test_k1` (34 contrôles : défauts, valeurs invalides, 9 jeux x 4 formes x 2 tailles chargés, points chauds sur la forme, application,
taille 32 / 48, persistance, réinitialisation, conditions du réticule, lignes et aperçu des Paramètres) ; `test_controls`,
`test_nav_screens`, `test_texts_fr` verts. Captures `tests/shot_k1.tscn`.
