# R_U3 — Choix de carte, coffres, roulette (lot L3 de A2, version 0.1.174)

Fichiers : `ui/card_picker.gd`, `ui/chests_page.gd`, `ui/wheel_page.gd`, `core/rewards.gd`. `ui/chest_stage.gd` : rien à changer (le coffre 3D rétrécit via `custom_minimum_size` côté page).
Retouches hors lot (minimales) : `core/wheel.gd` (la planche des gains promis, indispensable à la projection), `ui/lobby.gd` (1 ligne : le sous-titre de Coffres supprimé),
tests `test_lot18`, `test_siege`, `test_pages` (appel `_choose` à la place de `_select` + `_confirm_choice`), `test_loot` (« Coffre de joaillier »), `test_nav_screens` (Roulette et liste variée).
Captures regardées : `captures/u3/coffres_*.png` et `cartes_*.png` (outils `tests/shot_chests.tscn`, `tests/shot_cards.tscn`, APPDATA détourné).

## Fait
- **Choix de carte en un geste** : un clic, 1 / 2 / 3, ou A à la manette (vrai clic via UiNav) choisit. Plus de bouton « Valider », plus de phrase d'aide, plus d'Entrée.
  Anti-rafale 0,3 s gardé : pendant ce délai les cartes sont voilées (opacité 45 %, fondu) et ignorent clics et touches ; après une relance ou un bannissement, pas de délai.
- **Cartes d'équipement** : les lignes communes à toutes les cartes (« Emplacement libre », les `+3 Force +4 Agilité…` identiques des deux variantes d'une arme, le texte d'un trophée) sont
  dites une fois, en gras, sous la rangée ; une pièce d'armure garde 4 statistiques au plus (+ comparaison, set, passif) ; cartes à la même hauteur, jamais de ligne coupée (hauteur mesurée, 470 px au plus).
- **Coffres** : une ligne par *genre* = type + spécialité (`Rewards.kind_of`) : « Coffre de forge », « Coffre de forge · parchemins / pierres », « Coffre de joaillier » (et non plus « du joaillier »),
  « · gemmes / formules » ; pastille ronde (couleur + icône : arme, flèche d'amélioration, gemme, armure, collection, étoile) ; liseré et fond du coffre choisi bien visibles ; une phrase sans chiffre par genre ;
  le détail du contenu (avec les pourcentages) est dans l'infobulle du détail ; paragraphe de 330 caractères et 2e phrase des auras supprimés ; sous-titre de l'écran supprimé ;
  « Ouvrir tout (N) » ; titre « N coffres ouverts » et récapitulatif au bon pluriel, sans la phrase « Objets : au coffre commun… » (en infobulle) ; coffre 3D réduit une fois ouvert,
  contenu dans un panneau défilant, fiche d'objet masquée quand il n'y en a pas ; état vide en une phrase (dite une seule fois).
- **Roulette** : `Wheel.board()` donne à chaque case l'apparence qu'elle donnera (tirée à chaque lancer, sauvegardée dans `Profile.wheel.board`, jamais deux fois la même, remplacée si on l'obtient entre-temps,
  insignes si la collection du rang est complète). Elle apparaît dans la roue (icône ronde au bord de chaque case, libellé plus près du moyeu) et dans la liste « Gains » (icône, nom, rang, chance en infobulle).
  Le lancer donne l'apparence de la case désignée (pitié comprise). Le gain s'affiche en grand au centre de la roue 3 s (idée du joueur), clic pour le fermer ; la roue et la liste gardent
  l'ancienne planche pendant le lancer et l'annonce, puis passent à la nouvelle. Compteurs de pitié, paragraphe de règles et « (la largeur de la case = sa chance) » retirés (la pitié est dans l'infobulle du compteur).
- Tests : `test_u3` (31 vérifications : genres, planche, promesse tenue, pitié, pages), `test_cards` réécrit, `test_nav_screens` (Roulette 4/4, liste variée 11/11), `test_ideas`, `test_loot`, `test_lot7`, `test_lot14`, `test_pages`, `test_farm`, `test_lot18`, `test_siege` verts.

## Décisions
- Pas de confirmation par double-clic / appui long : le délai de 0,3 s suffit à protéger, et l'option d'accessibilité demanderait un réglage dans `settings_menu.gd` (lot U8, déjà poussé). À ajouter si le joueur le réclame.
- Le contenu précis (« 2-3 parchemins… 50 % de ciseaux ») n'est plus affiché en permanence mais reste dans `Rewards.preview` (infobulle, tests existants).
- Le texte des cartes d'équipement est retouché dans le sélecteur (pas dans `run_director.gd`, qui est à N1 / E4) : le sélecteur ne touche qu'aux cartes qui portent un `item`.

## Reste / pièges
- Icône de cape = gants dans le coffre doré : donnée d'objet (`data/item_icons.json`), non reproduite sur les nouvelles captures (cape et gants ont leur propre icône) ; « La Tour : ta carte de départ » en Donjon / Siège : `core/world.gd` (U9).
- La pastille « apparence » (livre) et « aura » (plus) sont les meilleures icônes existantes ; une icône de chemise / d'étoile dédiée serait mieux (session locale).
- `test_build` (« pause : compétences sur 12 lignes ») et `test_royale` (« la page Run affiche ses lignes de sorts ») échouent : `ui/run_page.gd` (U9, cases vides masquées), hors lot.
- Le tirage de la planche appelle `Profile.save_profile()` une fois par lancer (la promesse survit à un redémarrage) ; `Wheel.spin` garde la signature `spin(roll)`.
