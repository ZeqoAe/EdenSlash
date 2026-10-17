# R_BRI2 : Battle royale, backlog P0 n° 6 à 10 (lieux, mort et spectateur, dépouille, bilan v2, cohérence)

Source : `conception/benchmark/BATTLE_ROYALE.md` (§ 6, P0 6-10 ; maquettes 2 à 5 de `battle_royale_maquettes/index.html`),
DA `conception/art/BIBLE.md` v2 (posée sur `UiTheme` v2 de UIK-0, 0.1.258). Lot parallèle : BR-I1 (HUD, mini-carte, flèches).

## Ce qui est fait
- **Lieux nommés (6)** : `ProcMap._place_royale_places` tire 6 à 8 lieux (≥ 60 à 110 m l'un de l'autre, hors plateaux), un
  décor par lieu (ruines, tour, arche, ossements, mine, campement, marché), un nom français et sa forme « à » (« aux Ruines du
  col »), une richesse (un ★★★, trois ★★, le reste ★) et ses coffres en couronne à 15-18 m (`PLACE_CHESTS` : ★ 3 dont 1 rare,
  ★★ 4 dont 2 rares + 1 doré, ★★★ 6 dont 2 rares + 2 dorés). **Totaux inchangés** (64 coffres, 18 rares, 8 dorés : les
  coffres des lieux sont pris sur ceux de la carte). Couvert : 2 murets (collision en boîte) + 1 gros rocher par lieu, 2
  rochers au large des ruines ; jamais cassables (`_build_royale_cover`). `RoyaleDirector.places()` (nom, à, ★, position,
  rayon, `aimed` = héros scriptés en l'air qui y atterrissent) et `place_at(pos)` pour la mini-carte / grande carte de BR-I1.
  Atterrir dans un lieu : « Tu atterris aux Ruines du col ★★ ». Les scriptés visent déjà les coffres dorés au saut
  (`RoyaleDrop.plan`) : ils se disputent naturellement le ★★★.
- **Mort et spectateur (7)** : `Royale.stats` (dégâts donnés / reçus entre héros via `PvpCaps.note_hit`, dernier coup reçu avec
  le sort : meta `move` posée par `ClassRival._start_attack`), `RoyaleDirector.death_recap` (avant que le tueur ne se soigne)
  et `ui/royale_recap.gd` : carte « Éliminé · 4e » (classe en tuile de sa famille, « Coup de grâce : sort · dégâts », « Il
  lui restait N PV », 3 tuiles : dégâts donnés, reçus, survécu ; « Regarder » A / Entrée, « Bilan » B / Échap ; repli seul à
  12 s), puis bandeau « [A] ◀ Tu regardes : X ▶ [D] · [F] son équipement · [Échap] bilan ». Le spectateur suit le tueur ;
  LB / RB (◀ ▶ au clavier) change de héros (`spectate_step`). Avant 2 min : carte courte « Retour dans N s », fermée au retour ;
  plus de « tu reviendras » dans le fil. Plus d'invite [F] quand on est mort (`RunDirector._update_interactions`).
- **Dépouille groupée (8)** : un sac par héros tombé (`RoyaleLoot.make_bag`, Interactable « remains », meta `items`) : un seul
  faisceau et un anneau à la couleur Bible de la meilleure rareté, icône flottante de la meilleure pièce, « Dépouille
  d'Ingénieur · 8 pièces » ; invite « [F] Fouiller — … · 8 pièces (7 ▲) ». La fenêtre de pile est la fiche d'inspection
  (`ui/royale_gear_sheet.gd`) en mode pile : cases autocollantes aux deux tons de la rareté, pastilles « ▲ mieux » / « ▼ moins »
  / « prise », carte de l'objet comparée à la tienne, « Prendre » ([F]) et « Tout le meilleur » (X, [G]) ; la pièce remplacée
  rejoint la dépouille (au plus une par emplacement). Le joueur tombé a « Ta dépouille ». Les scriptés y prennent la
  meilleure pièce (`_ground_for` -> {bag, item}).
- **Bilan v2 (9)** : `RoyaleResults` garde `ResultsPanel` et l'habille : bandeau autocollant incliné de −4° (soleil
  « N°1 · Victoire ! », lagon podium, fraise « Place N », entrée élastique 520 ms), 6 tuiles (+ dégâts), chronologie (saut avec le
  lieu en infobulle, 1re élimination, largage, mise à prix, retour, fin) sur une barre lagon, confettis des 5 bonbons (24,
  1,2 s) à la victoire ; Gagné / Gardé (coffre d'apparence) ; « Rejouer » primaire, « Menu principal ».
- **Cohérence (10)** : coffres au code de rareté de la Bible (`ProcMap.ROYALE_LOOKS` : commun `#C9C3D6`, rare lagon `#22B8F0`,
  doré soleil `#FFC928` + 12 étincelles, largage `#FFE27A`) et mêmes couleurs sur la mini-carte (`Minimap.icon_color`, seulement
  au Battle royale) ; `RoyaleLoot.NO_PASSIVES` étendu à tous les passifs « monstres » / « tuer » (Élan meurtrier, Œil du chasseur,
  Exécuteur, Lame statique, Éclat glacial, Lame du phénix), bannis aussi des cartes de niveau ; menu pause : page « Partie »,
  « Compétences (n / 12) », « Passifs », plus d'« Arme secondaire : aucune », « La partie en cours sera perdue » ; plaques des
  scriptés « PV 1 240 » au lieu d'un pourcentage ; bilan sans « lobby ». `tests/shot_m1.gd` refait (pose tout le monde au
  sol, mort après 2 min, vraies captures du spectateur et du bilan, `M1_RES`, lignes `[débord]`).

## Décisions
- **Fenêtre de pile en pause** (la maquette la voulait non bloquante) : partie solo contre des scriptés, manette sans conflit
  avec les touches de combat, même règle que le choix de carte ; « Tout le meilleur » la rend courte (un appui).
- **Mêmes totaux de coffres** : les lieux concentrent le butin sans en ajouter (équilibre inchangé, `test_royale` vérifie
  64 / 18 / 8).
- Spectateur au clavier : ◀ ▶ = Gauche / Droite (le héros est mort, ces touches sont libres) ; à la manette LB / RB.
- Le pourcentage du bandeau « Hors de l'anneau » est au lot BR-I1 (déjà retiré de son côté).

## Mesures et tests
`test_bri2` (nouveau, 56 contrôles : lieux, richesse, totaux, couvert, annonce, sac, faisceau, ▲, Tout le meilleur, reprise
par un scripté, menu pause, récapitulatif court puis complet, LB / RB, Regarder, Bilan, bilan v2 défaite et victoire,
couleurs, passifs, mots interdits). Verts sur copie propre : `test_royale`, `test_br2`, `test_br3` (mis à jour pour le sac),
`test_br4`, `test_m1`, `test_results` (« Menu principal »), `test_nav_screens`, `test_texts_fr`, `test_bri2`.

## Reste / pièges
- Les noms des lieux sur la mini-carte et la grande carte, le « N héros visent » pendant le vol : BR-I1 lit `places()`.
- Fichiers partagés retouchés au minimum : `minimap.gd` (`icon_color`), `pause_menu.gd`, `run_page.gd`, `pvp_caps.gd`
  (dégâts passés à `Royale.note_fight`), `class_rival.gd` (meta `move`), `run_director.gd` (pas d'invite mort).
- Les infobulles du Survivant (« … pendant la run ») restent dans les cartes ; à reprendre avec le vocabulaire global.
