# R_P3 — Deuxième regard sur ce qu'on voit en jeu (version 0.1.181)

Fichiers : `ui/hud.gd`, `ui/pause_menu.gd`, `ui/results_panel.gd`, `ui/minimap.gd`, `ui/card_picker.gd`, `combat/damage_number.gd` ; retouches hors lot (minimales) :
`core/royale_director.gd` (objectifs), `core/run_director.gd` (bandeau du boss, minicarte d'entraînement) ; tests `test_results` (+12 contrôles), `test_pages` (pause) ;
outils `tests/shot_p3.tscn` (`stage=N boss_at=S guide_at=S` + arguments du monde, `P3_RES=1280x720`), `tests/shot_p3r.tscn` (bilan à mi-animation et à la fin), `shot_hud` (`P3_RES`).
Captures regardées une à une, 1600×900 et 1280×720, APPDATA détourné : `captures/p3/` (Survie étapes 1-3 avec foule et boss, Duel, Tour, Donjon, Siège, Ruée, Royale, Entraînement, cartes, pause, Guide, bilan).

## Fait
1. **« ? Aide » de la pause** : plus d'onglet Aide (page `InfoPage` en double) mais un bouton dans l'en-tête qui ouvre le Guide sur « Détails » (`PauseMenu.open_guide`, même parent que F1 : F1 le referme). La pause reste ouverte dessous. L'onglet « ? » du Héros le faisait déjà (R_U4).
2. **HUD par mode** (défauts vus sur captures, corrigés) :
   - Titre du panneau coupé (« NV 2' », « FORÊT DES CHUTES ARC-EN-CII ») : le nom passe à la ligne, l'étape / le niveau vont dans la ligne du dessous en police ordinaire (le « 1 » de la police des titres se lisait « I » : « La Tour · Nv I », « Étape I/3 »). `Hud.zone_parts`.
   - Entraînement : minuterie, sceaux et or d'une run alors qu'on ne court pas : titre « Entraînement » seul ; mini-carte noire : toute la zone est révélée.
   - Battle royale : 5 lignes d'objectifs dont une de 2 lignes avec un pourcentage → 3 lignes courtes (les survivants sont déjà sous le titre, les potions dans la barre).
   - Bandeau d'annonce : 860 px sur toute la largeur au milieu de l'écran, il coupait le combat et les zones d'attaque → dégradé qui s'efface sur les côtés, 600 px, remonté sous la cible ; vide sous le titre corrigé (un conteneur ne rétrécit pas : recalage une image plus tard) ; « BOSS : <Boss> Mori Mori » (étiquette interne affichée) corrigé ; conseil d'esquive du boss dit une fois (panneau d'objectifs, avec la vraie touche) ; « Potion d'élan ! » va dans le fil de butin.
   - Cadre de la cible d'un boss : plus large (560 px, 500 à 1280), barre plus haute, nom plus grand ; ne touche jamais la pile de gauche (mesuré à 1280 : 10 px de recouvrement avant correction).
   - Pendant un choix de carte la pile de gauche et la cible se retirent (elles se mêlaient au titre à 720 p).
   - Mini-carte des arènes (duel, Tour, donjon, boss) : l'arène entière dans le disque (c'était un carré gris décentré et flou).
3. **Bilan animé** : les nombres (tuiles et valeurs des blocs, ≥ 10) montent de 0 à leur valeur en 0,8 s (largeur du résultat final réservée : rien ne bouge), échelonnés (~1,6 s en tout) ; le plus gros gain « +N » du bloc Gardé (à défaut Gagné), s'il y a au moins deux gains chiffrés, est sur fond doré, valeur plus grande, éclat et petit son à l'arrivée ; une touche, un clic ou un bouton de manette montre tout de suite le résultat (`finish_now`, l'événement n'est pas consommé). Durées, décimales et textes ne comptent pas (`« 05:23 »`).
4. **Choix de carte** : couleur = rareté partout, commune comprise (gris clair) ; avant, une carte commune prenait la couleur de son *type* (amélioration = bleu = « rare », nouveau sort = orange = « légendaire »). Les cartes sans rareté (nouveau sort, enchaînement) ont un vert menthe. Pastille ronde de la touche (1 / 2 / 3), rareté + type + niveau en 17 px gras, teinte de la rareté du haut vers le bas, lueur pour rare et mieux, texte 15-16 px, boutons Bannir / Garder 14 px, bloc centré (plus de bouton Relancer sur la barre d'action à 720 p).
5. **Chiffres de dégâts** : ils se chevauchaient en mêlée (20 critiques sur 4 m²). Colonnes par cible (jamais deux chiffres successifs au même endroit), colonne propre aux dégâts subis (à gauche, 42 px), budget par 0,3 s (8 normaux, 12 critiques), plafonds 24 / 34 à l'écran, tailles qui diminuent avec la densité (les critiques restent gros), textes d'état éclaircis (rouge sur zone rouge illisible). **Zones d'attaque : non touchées.**

## Décisions
- Gagné / Gardé : le meilleur gain se cherche d'abord dans Gardé (insignes, cristaux : ce qu'on dépense), sinon dans Gagné : comparer une maîtrise de +1 791 à des insignes de +248 n'a pas de sens.
- Les chiffres coupés par le budget ne perdent rien : le compteur de dégâts cumulés les compte.
- Le bilan garde ses boutons gelés 0,45 s : l'animation ne change rien à l'anti-appui.

## Mesures
`test_results` (+ animation, meilleur gain, titres du HUD, cadre de boss, pause), `test_hud`, `test_build`, `test_royale`, `test_cards`, `test_pages` verts. `test_nav_screens` : 1 échec, « Registre : une classe ouvre Héros > Équipement » (Carnet / Héros, fichiers des sessions P1 et U4, pas de lien avec ce passage).

## Restes / pièges
- `--pause=2` du monde (commentaire « 2 Aide ») n'existe plus : la page est bornée à 1.
- Les textes de boss / de dons du bandeau viennent encore de `run_director.gd`, `tower_director.gd`, `siege_director.gd` (l'étiquette « <Boss> » est retirée à l'affichage dans `Hud.show_message`).
- Un chiffre ≥ 1 000 de ligne de bilan sans espace (« +1791 ») reste tel que l'appelant l'écrit : à uniformiser dans `results_screen.gd` si on veut « +1 791 ».
- Écrire un fichier de `ui/` avec `open(..., 'w')` échoue par moments (`Errno 22`) quand Godot tourne : réessayer ou passer par l'outil Edit.
- Des captures lancées pendant qu'une autre session casse la compilation (`GearShopPage`) donnent des « Failed to compile depended scripts » : vérifier le journal (`log.txt`) avant de juger une capture.
