# R_BRI3 : Battle royale, reste du backlog BM-BR (P1 puis P2) et trois correctifs (17/10/2026)

Source : `conception/benchmark/BATTLE_ROYALE.md` (§ 5, § 6 P1-P2, § 7 spec v2), DA `conception/art/BIBLE.md` v2 (UiTheme v2, Mochiy Pop
One / M PLUS Rounded 1c), sons de la bibliothèque maison SND-1. Lots précédents : BR-I1 (HUD, carte, arc, repère), BR-I2 (lieux, mort,
dépouille, bilan). **Aucune règle de combat ne change** (équilibre BR1 intact) ; mode scellé inchangé.

## Correctifs demandés
- **(a) `test_royale` instable (« points d'atterrissage distincts »)** : la cause était dans `RoyaleDrop.plan`. Quand aucun coffre libre
  n'était à portée pour un héros, le repli tirait un point au hasard sous le vol sans regarder les points déjà pris : deux héros
  pouvaient viser le même endroit à 8-15 m. Nouveau repli `RoyaleDrop._free_spot` : grille de la bande atteignable (25 instants × 7
  écarts), le point le plus loin des autres (plafonné à `SPREAD` 55 m, comme pour les coffres), puis le plus proche de l'instant prévu ;
  un seul tirage à la graine (même consommation qu'avant). Mesure `test_bri3` : 60 graines, écart minimal ≥ 25 m ; sans aucun coffre
  libre (repli seul, 30 graines) ≥ 40 m, points dans la carte et sauts pendant le vol. Le test de `test_royale` n'est pas modifié.
- **(b) noms de classe** : aucune collision. `RoyaleStyle` (`ui/royale_style.gd`, bilan, pile, récapitulatif, lot BR-I2) et
  `RoyaleHudStyle` (`ui/royale_hud_style.gd`, HUD, lot BR-I1) sont deux classes distinctes ; `test_bri3` parcourt la liste des classes
  globales (aucun doublon) et vérifie les deux.
- **(c) `shot_br4` ignorait `BR4_RES`** : `Settings.reset_all()` est appelé avant la taille de fenêtre (il appliquait la résolution des
  réglages après) ; les fichiers portent le suffixe `_720` comme `shot_bri1`.

## Fait (backlog)
- **P1-18 Annonces centrales** (`ui/royale_announce.gd`, crochet d'une ligne dans `Hud.show_message`) : une seule à la fois, en haut au
  centre, bandeau autocollant incliné de −3°, titre court en Mochiy contouré, une ligne de détail ; couleur selon le sens (danger fraise,
  anneau améthyste, largage et mise à prix soleil, lieu lagon, le reste papier). File à priorités : un danger passe tout de suite, une
  information attend la fin de la courante (oubliée après 4 s), seul le dernier « N héros restants » attend, le même texte ravive.
  Textes réécrits courts : « L'anneau se resserre ! / Rejoins le cercle blanc », « Anneau 2 / 5 / Niveau max 20 ! », « Largage ! / Dans
  15 s… », « Mis à prix ! », « 3 héros restants », « Victoire ! », « Éliminé ! » ; plus de « DERNIER CERCLE » ni « RESSERREMENT » criés.
  Largeur bornée entre l'objectif et la mini-carte (1600×900 et 1280×720). Onomatopées au-dessus du héros (« K.O. ! », « Niveau ! »,
  « Critique ! », « Trésor ! ») : 600 ms, une à la fois, jamais sous le bandeau.
- **P1-18 Cadre de cible v2** (`ui/royale_target.gd`) : autocollant papier, tuile de la classe aux couleurs de sa famille, nom, niveau,
  étoile du mis à prix, jauge deux tons avec trace claire des dégâts, PV en chiffres contourés, effets en cours. Même cible que Hud
  (verrouillée, sinon le héros le plus proche) ; l'ancien cadre est caché.
- **P1-16 Force relative** : « ▲ plus fort » / « ▼ plus faible » / « = égal » (PV max × frappe, à PV pleins : niveau et équipement) sur le
  cadre et au-dessus des plaques. **P1-17 Intention** des scriptés Facile et Normal au-dessus de la plaque (« pille », « chasse », « fuit »,
  « attaque », « rejoint l'anneau », « attend le largage »), jamais en Difficile / Hardcore ; plus de flèche en spectateur.
- **Noms des lieux sur la mini-carte** : rond de richesse et nom des 3 lieux les plus proches quand il tient dans le disque, le lieu où
  l'on est en lagon (`RoyaleMap._minimap_places`) ; la grande carte les avait déjà.
- **Confort, raccourcis dessinés** : aide du largage en pastille de papier avec les touches en pastilles (`ui/royale_key_line.gd`,
  `ui/royale_drop_hint.gd`), placée au-dessus de la barre d'action (plus sur le héros) ; altimètre pendant la chute et le planeur (hauteur,
  cran d'ouverture seule du planeur) ; bandeau du spectateur aux touches dessinées (`RoyaleRecap`).
- **Accessibilité** (Paramètres > Caméra & interface > Accessibilité) : « Voir les sons » (`interface/sound_cues`, P2-21 ; arcs autour du
  héros avec le nom du son en sous-titre : coffre ouvert par un autre, combat entre deux autres héros, pas proches hors de la vue,
  largage, resserrement), « Couleurs pour daltoniens » (`interface/colorblind` : danger en mandarine et « plus faible » en lagon au lieu de
  fraise et pomme ; arc de coup reçu, chiffres subis, cadre de cible, plaques ; les formes ▲ ▼ restent), « Vibration en combat »
  (`interface/combat_vibration`, à part de celle des menus : coups donnés et reçus, saut, atterrissage, K.O.). La taille du texte du HUD
  est celle du lot HUB-1 (taille du HUD), qui s'applique au HUD du Battle royale.
- **P1-15 Premiers pas du mode** : 3 fiches (≤ 125 signes) au bon moment, une fois par profil (`records.royale_tips`, gardé après la
  partie) : le largage (en chute), l'anneau (au début du combat), les dépouilles (première élimination) ; pile à gauche, sous l'objectif.
- **Rythme des récompenses** : « Niveau ! » à chaque niveau ; au plafond de l'anneau, « Niveau max ! Le prochain anneau ouvre le niveau
  N » (une fois par anneau) ; coffre doré ou largage ouvert : anneau, étincelles et « Trésor ! ».
- **P1-19 Retours de coups et lisibilité** : chiffres sobres (`ui/royale_combat.gd`, crochet d'une ligne dans `DamageNumber.spawn`) : un
  nombre par cible et par rafale (coups et effets additionnés pendant 0,45 s), à côté de la cible (jamais sur sa plaque), M PLUS Rounded
  900 contouré, « ! » soleil pour un critique, plus de « (max) » ; réglage « Chiffres de dégâts » respecté. Coup donné : « tic » et
  courte vibration ; élimination : « K.O. ! », étoiles, vibration.
- **Son et ambiance** (`ui/royale_ambience.gd`) : portes de l'aigle, saut, planeur, atterrissage, compte à rebours 5-1 avant le
  resserrement, resserrement, danger, largage (sons SND-1) ; vent synthétisé pendant le vol (plus fort en piqué, doux sous le planeur) et
  grondement grave près du mur de l'anneau (plus fort dehors), AudioStreamGenerator, rien de calculé au repos.
- **Mots** : « Battle royale ! … choisis où sauter », « Tous au sol ! », plus de majuscules criées ; `test_texts_fr` lit toutes les
  annonces et fiches du mode (ni « run / build / lobby / spawn / loot / ping »).

## Non fait (reste du backlog, à décider)
P1-11 page du mode v2, P1-12 modificateurs de partie, P1-13 événement de milieu de partie, P1-14 ligue royale, P1-20 mesure de densité
(384 m contre 512 m) ; P2-22 apparences de planeur et couronne, P2-23 remercier l'aigle, P2-24 statistiques de carrière, P2-25 défis du
mode dans les quêtes, P2-26 partie personnalisée. Ce sont des règles ou du contenu (pas de l'habillage) : lots à part.

## Décisions
- Annonces : crochet minimal dans `Hud.show_message` (une ligne) plutôt que de toucher le bandeau commun (lot HUB-1 en cours dessus) ;
  les lignes de butin restent au fil de Hud.
- Fiches du mode dans une pile à gauche (à droite, la colonne de la mini-carte et le fil des éliminations sont pris).
- Couleurs pour daltoniens : paire orange / bleu (lisible des trois formes courantes) au lieu de recolorer toute l'interface.
- Force relative à PV pleins (niveau et équipement) : elle ne clignote pas pendant un combat.

## Mesures et tests
- Coût du HUD du Battle royale avec cible, aide, sons : **0,044-0,048 ms** par image (`test_bri3`, meilleure de 7 séries ; budget 0,3).
- `test_bri3` (nouveau, 67 contrôles : points de saut sur 60 + 30 graines, classes, réglages, touches dessinées, daltoniens, force,
  sens des annonces, fiches, aide du vol et de la chute, vent, cadre de cible, plaques, chiffres sobres, coup donné, Voir les sons,
  K.O., Niveau max, grondement, fiche une seule fois, file d'annonces, mise en page 1600×900 et 1280×720, coût) : vert.
- Verts sur une copie propre de HEAD + ce lot : `test_royale` (4 fois de suite), `test_bri1`, `test_bri2`, `test_br2`, `test_br3`,
  `test_br4`, `test_m1`, `test_nav_screens` (section Accessibilité), `test_texts_fr` (46 annonces et fiches du mode), `test_hud`,
  `test_duel_modes`, `test_controls`, `test_uik0`, `test_dng1`, `test_results`.
- Captures regardées (1600×900 et 1280×720, `tests/shot_bri3.tscn`, `BRI3_RES`) : à bord, chute (altimètre), combat (cible, plaques,
  annonce, chiffres, sons), daltoniens (hors de l'anneau, arc mandarine), spectateur (touches dessinées) ; `shot_br4` à 1280×720.
