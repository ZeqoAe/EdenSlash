# R_BRR1 : Battle royale, contenu et règles (backlog BM-BR P1 n° 11 à 14 et 20, P2 n° 22 à 26) — 17/10/2026

Source : `conception/benchmark/BATTLE_ROYALE.md` (§ 4, § 6, § 7, questions ouvertes § 8, recommandations validées), DA
`conception/art/BIBLE.md` v2. Lots précédents : BR-I1 (HUD), BR-I2 (lieux, mort, butin, bilan), BR-I3 (annonces, retours, accessibilité).
**Aucune règle de combat ne change** (équilibre du lot BR1 : échelle 0,055, plafonds, force des scriptés) ; mode scellé inchangé.

## Fait
- **P1-11 Page du mode v2** (`ui/royale_page.gd`, `RoyalePage`, appelée par `Lobby._menu_royale`) : une idée par bloc. 1. La partie :
  pastilles Classique / Du jour / Personnalisée, et une carte (puits d'encre) avec l'étiquette du modificateur à sa couleur et sa phrase.
  2. Les adversaires (Mélange … Hardcore) en pastilles (sélection lagon, Bible § 6). 3. Les règles en 4 lignes (le détail au survol).
  4. La Ligue royale de la saison (rang en autocollant, points, jauge vers le rang suivant, ce qu'il donne, jours restants). 5. La
  carrière (8 tuiles + la classe la plus gagnante). 6. Les apparences (voiles en pastilles de couleur, traînées, couronne). « Lancer »
  reste épinglé (« Lancer la partie personnalisée » en personnalisée). « Continuer » (HUB-1) retrouve la partie choisie (`memo` / `restore`).
- **P1-12 Modificateurs** (`core/royale_mods.gd`, `Royale.mod`) : 5 règles simples, aucune ne touche au combat. Un « du jour » tourne
  d'un cran chaque jour (`RoyaleMods.today_id` : jamais deux fois de suite, le même toute la journée), la partie classique est toujours là
  (question ouverte n° 4). Annoncé au départ (sous-titre « Battle royale ! »), sur la carte du vol (pied du panneau), au premier
  atterrissage (« Tous au sol ! » + sa phrase) et dans l'objectif (« Pluie de météores en cours »).
  - *Pluie de météores* : toutes les 9 s (± 2), deux zones fraise (Telegraph v2, 4,5 m, 1,8 s) près de deux héros tirés au hasard,
    une boule de feu qui descend ; un héros au sol encore dedans perd 12 % de ses PV max (l'esquive passe : « ESQUIVE ! »). Les
    scriptés lisent la zone selon leur difficulté (45 / 70 / 85 / 95 %) et en sortent (« esquive ») ; le pilote de mesure aussi
    (`PilotDodge`, 85 %). Élimination : « X est écrasé par un météore », récapitulatif « Un météore t'a écrasé ».
  - *Ruée vers l'or* : chaque coffre de la carte et des vagues monte d'une qualité (`RoyaleMods.chest_tier`, `ProcMap._place_pois`).
  - *Anneau pressé* : attente × 0,55, resserrement × 0,8 (6 min 08 au lieu de 9 min 50 ; `Royale.ring_at`, `total_time`).
  - *Sources de vie* : 12 fontaines au lieu de 4 ; un scripté sous 55 % de ses PV, sans adversaire au contact, va boire à moins de
    55 m (« va boire ») ; le pilote aussi.
  - *Chasse ouverte* : tous les héros sur les cartes (points fraise), +0,5 niveau par élimination, les scriptés traquent dès le
    2e anneau et 1,5 fois plus loin.
- **P1-13 Autel du gardien** (`core/royale_event.gd`, `RoyaleEvent`) : le seul événement, le même à chaque partie. Au début du
  2e anneau, un autel (socle de pierre, anneau d'or, pilier mandarine visible de loin, cercle de la zone gardée au sol, losange sur la
  mini-carte et la grande carte + ligne de légende) s'éveille dans la zone qui restera sûre jusqu'au 4e anneau. Son gardien est un
  héros scripté Hardcore d'une classe solide (Protecteur, Templier, Paladin, Berserker), 1,35 fois plus grand, niveau médian des héros
  en vie + 3, PV × 3,2, attaque × 0,55, plaque « Gardien de l'autel · niv. N », tuile de sa classe sur le cadre de cible. Il ne quitte
  jamais l'autel (13 m), attaque qui y entre et se remet (5 % des PV par seconde) quand personne n'est là : **l'ignorer ne coûte
  rien**. L'achever : +1 niveau, 25 % de PV, et le **trésor de l'autel** (coffre de largage) posé sur place, à qui le prend : c'est là
  que les autres arrivent. Au resserrement du 4e anneau, s'il tient encore, il s'en va et laisse le trésor. Hors du compteur des héros,
  jamais spectateur ni mis à prix. Les scriptés y vont s'ils sont en forme (55 % des PV), à moins de 170 m et de taille (rapport de
  forces à PV pleins ≥ 0,40 / 0,32 / 0,25 en Normal / Difficile / Hardcore ; le Facile seulement s'il passe à moins de 40 m), puis se
  battent contre lui comme contre un héros (ils ne le fuient que sous 30 % de PV). Le pilote aussi. Annonces mandarine « L'autel
  s'éveille ! », « Gardien vaincu ! », « Le gardien s'en va ! » ; « Gardien » dans la chronologie du bilan.
- **P1-14 Ligue royale** (`core/royale_league.gd`, `RoyaleLeague`) : une saison par mois du calendrier (« Saison d'octobre »), des
  points à chaque partie classée : place (14 / 10 / 8 / 5 / 4 / 3 / 2 / 1) + 2 par élimination (5 au plus) × difficulté (0,5 / 0,75 /
  1 / 1,25, mélange = Difficile) ; **jamais perdus, aucune connexion demandée** (sans corvée). Rangs Bronze (1re partie), Argent 30,
  Or 80, Platine 150 (une partie Difficile moyenne, 4e avec une élimination, vaut 7 points). Chaque rang atteint dans la saison : un
  coffre d'apparence rare / épique / légendaire (une fois par saison) ; la 1re fois de toutes : un titre (« Voltigeur d'argent / d'or /
  de platine »). Rien d'autre : aucun lien de puissance avec le compte. Ligne « Ligue royale · Argent +7 points » au bilan.
- **P1-20 Densité** : mesurée (ci-dessous) ; **ajustement de `ProcMap.generate_royale`** : les lieux nommés portent plus de coffres
  (`PLACE_CHESTS` ★ 4 dont 1 rare, ★★ 6 dont 2 rares et 1 doré, ★★★ 9 dont 3 rares et 2 dorés ; avant 3 / 4 / 6), **mêmes totaux**
  (64 coffres, 38 / 18 / 8) ; ligne `[royale] densité {json}` du pilote (`RoyaleDirector.density`) et outil `tools/royale_games.py`.
  La carte reste à 512 m et le 1er anneau à 190 m (la mesure ne le demande pas).
- **P2-22 Apparences du mode** (`core/royale_looks.gd`) : 8 voiles de planeur (soleil d'office ; lagon 3 parties, pomme 1 podium,
  fraise 15 éliminations, améthyste 1 victoire, argent / or / platine : rangs de la Ligue) et 4 traînées de chute (aucune, étoiles,
  bonbons, aurore), choisies à la page du mode ; la traînée part au saut et s'arrête au planeur. **Couronne du vainqueur** (cinq
  pointes d'or qui tournent au-dessus de la tête) portée pendant la partie qui suit une victoire.
- **P2-23 Remercier l'aigle** : à bord, [Interagir] (F ; LB sur la carte du vol, rappelé dans son aide et dans l'aide du largage) :
  « Merci l'aigle ! » (onomatopée fraise, étincelles, son), « Tu remercies l'aigle » au fil, une fois par vol ; 30 % des scriptés le
  font en sautant. Petite fête au saut : « Hop ! » et 4 étincelles.
- **P2-24 Carrière** : à la page du mode (pas dans le Carnet : `carnet_pages.gd` était en cours chez un autre lot) : parties,
  victoires, podiums, meilleure place, éliminations, record d'éliminations, dégâts, gardiens vaincus, classe la plus gagnante
  (`records.royale_podiums / royale_best_kills / royale_dealt / royale_altars / royale_class_wins`, `Royale._career`).
- **P2-25 Défis du mode dans les quêtes** (`QuestPool` : `ry_land3`, `ry_bounty`, `ry_altar`, `ry_clean`) : atterrir dans un lieu
  ★★★, éliminer le mis à prix, vaincre le gardien, gagner sans réanimation (`Royale.quest_extra`).
- **P2-26 Partie personnalisée** : modificateur au choix et graine (texte ou nombre ; même graine = même carte, mêmes adversaires,
  même anneau : `Royale.custom_seed` sème la carte, le tirage des classes et l'anneau). Sans ligue, ni insignes, ni maîtrise, ni
  quête, ni record, ni couronne (« Partie personnalisée : sans récompense » au bilan). Le nombre de scriptés n'est pas réglable
  (8 héros sont écrits en dur dans HUD, menu pause, page de partie : fichiers d'autres lots).
- Correctif : `RoyaleMap._draw_view` remplissait le journal de 7 500 erreurs « Rect2 size is negative » par partie sans fenêtre
  (taille nulle avant la mise en page).

## Décisions
- Le gardien est un **héros scripté** (et non un monstre) : les dégâts suivent la règle entre héros (échelle, plafond de 15 % par coup)
  sans autre réglage ; les scriptés savent déjà se battre contre lui. Niveau « médian + 3 » plutôt que « plafond de l'anneau − 2 » :
  au plafond, le pilote (2 fois plus de coffres qu'un scripté) l'abattait en 15 s avant que d'autres n'arrivent, et les scriptés
  n'osaient jamais.
- Modificateur « du jour » + Classique toujours possible (question ouverte n° 4) ; pas de « Nuit » (vue réduite) : elle touche au
  rendu (lot graphique en cours) et à la caméra.
- Ligue : points jamais perdus et saison au mois (pas de décroissance, pas de série quotidienne) ; un coffre par rang et par saison,
  les titres une seule fois.
- Attrait des lieux au saut (bonus d'étoiles dans `RoyaleDrop.plan`) **essayé puis retiré** : aucun effet mesurable sur les
  atterrissages (28 à 33 % dans les lieux avant comme après), la ligne de vol décide.

## Mesures
Parties complètes au pilote : `python tools/royale_games.py --projet <copie> -n N -j 2 --diff D [--mod M]` (copies propres de HEAD + ce
lot, machine chargée par d'autres agents ; « places » : combats commencés dans un lieu nommé, sur tous les combats entre héros ;
« temps mort » : part du temps, du 1er atterrissage à la fin, sans aucun combat en cours).

| Lot | Parties | Pilote 1er | Durée | 1er combat | Combats / min | Temps mort | Plus long | Combats dans les lieux | Atterr. dans les lieux |
|---|---|---|---|---|---|---|---|---|---|
| A2 Difficile, classique | 6 | 6 | 342 s | 22 s | 6,3 | 50 % | 60 s | 16 % | 25 % |
| B Hardcore, classique | 4 | 2 | 461 s | 31 s | 7,4 | 42 % | 56 s | 18 % | 37 % |
| C Difficile, lieux plus riches | 4 | 4 | 429 s | 16 s | 6,4 | 42 % | 65 s | 20 % | 22 % |
| C Hardcore, lieux plus riches | 4 | 3 | 352 s | 17 s | 6,1 | 43 % | 74 s | 35 % | 28 % |
| D Difficile, lieux plus riches + attrait au saut | 4 | 4 | 344 s | 17 s | 5,7 | 33 % | 59 s | 31 % | 28 % |
| D Hardcore, idem | 3 | 2 | 397 s | 29 s | 8,1 | 39 % | 47 s | 24 % | 33 % |
| D Normal, idem | 3 | 3 | 297 s | 10 s | 5,9 | 44 % | 53 s | 24 % | 38 % |

Lecture : le début n'est pas vide (1er combat 16 à 31 s après le 1er atterrissage, 3 à 6 combats dès la 1re minute) : **ni carte de
384 m ni 1er anneau plus serré** (question ouverte n° 1). Les lieux nommés ne voyaient que 16 à 18 % des combats : avec des lieux plus
riches, 20 à 35 % et moins de temps mort (42-50 % → 33-43 %). Gardé. Le pilote gagne encore presque tout (connu depuis BR1 : il pille
deux fois plus de coffres qu'un scripté) ; les chiffres de l'autel sont donc ceux d'un joueur très fort.

**Autel du gardien** (mêmes parties) :

| Lot | Vaincu par le pilote / un scripté / parti | 1er coup après l'éveil | Vaincu après l'éveil | Héros venus (médiane) | Morts près de l'autel |
|---|---|---|---|---|---|
| A Difficile (1er réglage : plafond − 2, PV × 2,6) | 5 / 0 / 0 | 15 s | 29 s | 2 | 0 |
| A2 Difficile (médiane + 3, PV × 3,2) | 6 / 0 / 0 | 9 s | 19 s | 2 | 0 |
| B Hardcore | 1 / 3 / 0 | 9 s | 31 s | 3 | 0 |
| Modificateurs (Hardcore, 19 parties) | 14 / 5 / 0 | 7-10 s | 20-32 s | 2 à 4,5 | 2 |

Sonde `royale_duel_probe -- --guardian --levels=8,13,18 --gear=commun,dore --diff=3` (un scripté Hardcore équipé seul contre le gardien de
son niveau + 3, 8 classes) : 30 à 36 s en médiane (15 à 52 s), le héros gagne 75 à 100 % des fois (l'Assassin perd souvent). Le gardien
est un défi d'une demi-minute pour un héros seul, assez long pour qu'un troisième arrive. Sonde sans `--guardian` (contrôle de BR1) :
duels de 22 à 26 s en médiane (15 à 32 s), comme au lot BR1 (17 à 31 s) : **équilibre de combat inchangé**.

**Modificateurs** (Hardcore, 4 parties chacun) :

| Modificateur | Pilote 1er | Durée | Combats / min | Temps mort | Effet propre |
|---|---|---|---|---|---|
| Classique (B) | 2 / 4 | 461 s | 7,4 | 42 % | — |
| Pluie de météores | 4 / 4 | 456 s | 6,6 | 45 % | 92 météores par partie, 15 touchent (2 par héros), 1 élimination en 4 parties ; « esquive » des scriptés vue dans les 4 |
| Ruée vers l'or | 3 / 4 | 369 s | 6,7 | 46 % | combats des minutes 2-3 : 9-10 / min (classique 8-9) |
| Anneau pressé | 4 / 4 | 288 s | 11,5 | 41 % | partie de 4 min 48, 14 à 18 combats / min aux minutes 2-4 ; 3,5 héros à l'autel |
| Sources de vie | 4 / 4 | 386 s | 8,4 | 49 % | « va boire » vu dans les 4 parties ; 4,5 héros à l'autel |
| Chasse ouverte | 3 / 3 | 352 s | 8,9 | 54 % | traque plus tôt : 12-13 combats / min aux minutes 3-4 ; 4 héros à l'autel |

Arrêts sans message pendant les mesures : 4 parties sur 60 (à 0, 105, 255 et 330 s), sans ligne du gestionnaire de plantage de Godot
ni événement « Application Error » de Windows : processus arrêtés de l'extérieur (machine partagée par plusieurs agents), pas des
plantages. Série de contrôle sur HEAD sans ce lot (6 parties Hardcore, en même temps) : 6 finies.

## Tests
- `test_brr1` (nouveau, 70 contrôles) : modificateurs (rotation du jour, règles), Ligue (saison, points, promotions, coffres une fois
  par saison, nouvelle saison, titres), apparences, couronne, carrière, partie personnalisée sans récompense, défis des quêtes, page du
  mode à 1600×900 et 1280×720 (sections, largeur, « Lancer » épinglé, rien ne dépasse, Du jour, Personnalisée, Continuer), partie :
  merci l'aigle, éveil de l'autel, gardien hors du compteur, zone gardée, retour à l'autel, décisions des scriptés, victoire du joueur
  (niveau, trésor, chronologie, défi), météores (lecture, impact, élimination), fontaines, chasse ouverte, densité, départ du gardien.
- Mis à jour : `test_royale` (partie classique : 4 fontaines, autel en attente, aucun météore), `test_nav_screens` (page personnalisée),
  `test_texts_fr` (annonces de l'autel et du largage, modificateurs, règles, rangs, titres, voiles).
- Verts sur copies propres de HEAD + ce lot : `test_brr1`, `test_royale`, `test_br2`, `test_br3`, `test_br4`, `test_bri1`, `test_bri2`,
  `test_bri3`, `test_m1`, `test_pages`, `test_nav_screens`, `test_texts_fr`, `test_quests`, `test_e2`, `test_hud`, `test_results`.
  `test_bri1` a échoué une fois sur trois sous forte charge (« flèche vers la zone sûre »), vert aux relances.
- Captures regardées (`tests/shot_brr1.tscn`, `BRR1_RES=1280x720`) : page (haut, bas, du jour, personnalisée), carte du vol avec le
  modificateur et « merci l'aigle », merci l'aigle, autel et gardien, grande carte avec l'autel, météore, trésor, bilan avec la Ligue.

## Reste / pièges
- Nombre de scriptés de la partie personnalisée : `Royale.PLAYERS` est lu par HUD, menu pause et page de partie (autres lots).
- Statistiques de carrière dans le Carnet : à brancher quand `carnet_pages.gd` sera libre (les records existent).
- Les mesures du pilote surestiment le joueur : le gardien et la Ligue sont réglés pour un héros moyen (sonde), à revoir avec des
  parties humaines (journal).
- Fichiers partagés touchés (crochets minces) : `ui/lobby.gd` (`_menu_royale`, `_start_royale`, « Continuer »), `world/proc_map.gd`
  (fontaines, qualités, coffres des lieux, icônes), `core/quest_pool.gd`.
