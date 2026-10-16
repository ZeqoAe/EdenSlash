# R_AC_F — L'Échiquier, lot AC-F : le plateau (16/10/2026)

## Fait
- `game/scripts/world/autochess_board.gd` (`AutochessBoard`, Node3D) : grille hexagonale 7 × 8 pointe en haut, case de 2 m
  (`AutochessData.CELL`), socle bleu nuit cerclé d'or ; sa moitié (4 rangées) et la moitié adverse **en miroir** (demi-tour :
  la case (c, r) de l'adversaire est la case (c, r) tournée, testé) ; surbrillance (case visée bleu clair et bord doré
  lumineux, cases libres en bleu quand on tient une unité, en rouge sombre si le plateau est plein) ; compteur « 3 / 4 Héros
  placés » ; placement borné au niveau + Couronnes ; figurines : modèle de la classe et son arme (`EdenModel`), taille
  selon les étoiles (×1 / 1,14 / 1,3), anneau au sol de la couleur du coût (`cost_color` : gris, vert, bleu, violet, or,
  comme les raretés), étoiles ★ bronze / argent / or au-dessus, icônes des objets portés ; stratège du joueur (héros du
  hub en petit : tenue, cheveux, teintures, arme ; nom `Profile.hero_name`, sinon la classe) qui marche dans une allée à
  droite du plateau en suivant le curseur (il ne cache jamais une unité) ; stratège adverse en miroir.
- `game/scripts/world/autochess_bench.gd` (`AutochessBench`) : banc de 9 cases devant le plateau, banc de 10 objets (deux
  colonnes de 5 à gauche, icônes des passifs ou cristal pour les composants).
- `game/scripts/ui/autochess_cursor.gd` (`AutochessCursor`, CanvasLayer `LAYER` = 6) : curseur de case pour les 47 cases
  (28 + 9 + 10). Manette : un contrôle invisible par case, posé sur sa projection, `gui_input` relié, sauts `nav_*` entre
  voisines : **UiNav navigue dessus comme dans tout menu** (cadre doré, barre d'aide), A prend / pose / échange, B repose,
  X maintenu 0,5 s vend ; si UiNav ne navigue pas (un héros en jeu), le curseur lit lui-même croix, stick et A. Souris :
  clic pour prendre puis poser, ou glisser-déposer ; zone « Vendre · +N or » en bas pendant qu'une unité est tenue
  (déposer dessus vend) ; molette = zoom. Clavier : flèches, Entrée, Échap, E vend.
- `game/tools/acf_demo.tscn` : démonstration sans machine de partie (unités au hasard, R, Page haut / bas = niveau).
- Test `test_ac_board` (52 vérifications) : miroir, placement limité au niveau et Couronne, échange, banc plein, vente (objets
  rendus), objets (3 au plus), cases invalides écartées, figurines toutes sur une case, **croix (UiNav) et flèches
  atteignent les 47 cases**, aller-retour, souris (chaque case se vise, toutes à l'écran en 1280 × 720), clic, refus gardé
  en main, glisser vers le banc, glisser sur « Vendre », E, X maintenu (vrais événements de manette).
- Captures `tests/shot_acf.tscn` (1280 × 720 et 1600 × 900 : vue, unité tenue, plateau plein, zoom, manette), regardées.

## Interface pour les autres lots
Données en dictionnaires simples (JSON) : unité `{"id", "stars", "items": [ids], "uid"}` ; case `{"zone": "board", "col",
"row"}` (rangée 0 = ligne de front), `{"zone": "bench", "index"}`, `{"zone": "items", "index"}` ; état `{"level", "crowns",
"board": {"c,r": unité}, "bench": [9], "items": [10 ids ou ""]}`.
- **AC-B (partie)** : `board.set_state(état)` après chaque achat / fusion / reprise ; il lit aussi tel quel
  `Autochess.players[i]` (« board » = liste d'unités avec « cell » [c, r], banc avec null ; mêmes rangées : 0 = front) ;
  les `uid` stables gardent leurs figurines ; `board.state()` ; `add_to_bench(u)` (−1 si plein) ; signaux `unit_placed(unit, from, to)` (deux pour
  un échange), `unit_sold(unit, from)` (l'or et la réserve sont à B ; les objets sont déjà rendus au banc d'objets),
  `item_given(item, unit, from)` (le plateau ajoute l'objet ; la **combinaison** `AutochessData.combine` est à B / AC-H, puis
  `set_state`), `placement_refused(texte)`, `state_changed`. Branchement : `unit_placed` vers une case du plateau ->
  `Autochess.place(pi, uid, Vector2i(col, row))`, vers le banc -> `to_bench(pi, uid, index)` (un échange émet deux signaux ;
  `place` / `to_bench` échangent déjà : le second est alors sans effet) ; `unit_sold` -> `sell(pi, uid)` ; `item_given` ->
  `equip(pi, index, uid)` puis `set_state(players[pi])`. `set_enemy(plateau adverse, {"class_id", "name"})` le montre en
  miroir.
- **AC-E (combat)** : `cell_world_position(c, r, foe)` = case d'apparition (même miroir) ; `show_figures(false)` pendant le
  combat ; `cursor.enabled = false` ; plusieurs plateaux : un `AutochessBoard` par plateau, déplacé de `BOARD_SPACING`.
- **AC-G (interface)** : poser les panneaux de préparation sur le calque `AutochessCursor.LAYER` (UiNav ne navigue que sur
  le calque le plus haut : la croix passe alors du banc à la boutique) ; `cursor.hovered(case, unité)` pour la fiche
  d'unité ; `board.frame_camera(cam, zoom)` (0 : tout, 1 : sa moitié) et `cursor.set_zoom` ; `AutochessBoard.cost_color`
  pour les cartes de la boutique. Cadrage : plateau et bancs au-dessus de 540 px en 1280 × 720 (place pour la boutique).
  Écran à ajouter à `test_nav_screens` quand il existera (fichier partagé, non touché ici).

## Décisions
- Manette par UiNav plutôt qu'un curseur à part : même cadre doré, même barre d'aide que tout le jeu, et la boutique d'AC-G
  est atteinte sans code. Demande : pendant la préparation, `Gamepad.menu_mode()` vrai (aucun nœud du groupe « player » ;
  le stratège n'en est pas un) — sinon le repli du curseur prend la main.
- Haut / bas à la croix : même colonne, rangée voisine (léger zigzag des rangées décalées, l'aller-retour revient toujours).
- Refus au clic (plateau plein) : l'unité reste en main pour choisir une autre case ; au glisser, elle revient à sa case.
- Le stratège marche dans une allée à droite plutôt que sur les cases : 20 unités restent lisibles.

## Reste
- Barres de PV et mana au combat (lot E), fiche d'unité et boutique (lot G), combinaison des objets (B / H).
- Zoom à la manette non lié (SPEC muette) ; images d'objet propres pour les composants (cristal doré aujourd'hui).
- Pièges : ajouter le plateau à l'arbre avant `set_state` ; un `set_state` sans `uid` refait toutes les figurines.
