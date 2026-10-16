# R_BR5 : tests du Battle royale remis d'aplomb (16/10/2026, 0.1.220)

Aucun changement du jeu : les 9 échecs de `test_m1` et l'instabilité de `test_br3` venaient des tests.

## test_m1 (8 échecs sur HEAD, 9 annoncés)
Cause unique en deux volets, vérifiée contrôle par contrôle :
- **Largage (BR4)** : le test forçait `phase = "fight"` alors que les héros étaient encore à bord de l'aigle (hors du groupe
  « ffa » : aucun adversaire visible) : « Hardcore dépassé au contact : il fuit » et « à force égale : il se bat » échouaient.
  Le test pose maintenant tout le monde (`rd.jump.land_all()`) avant de lancer le combat.
- **Réanimation (BR4)** : `elapsed` < 120 s, donc le joueur et les scriptés tombés revenaient au lieu d'être éliminés :
  fil « la prime tombe » (complété par « il reviendra »), spectateur, place, caméra, panneau « Tu regardes », fin de partie, bilan.
  Le test marque les héros comme déjà revenus (`_player_revived`, `st.revived`) : il suit l'élimination définitive, comme avant ;
  la réanimation reste vérifiée par `test_br4`. Spectateur, bilan et fuite fonctionnent dans le jeu.

## test_br3 instable (« joueur tombé : 0 pièces au sol »)
Reproduit 3 fois sur 30 avec 15 Godot en parallèle. Mesure ajoutée au libellé : le joueur n'était **pas mort** après le coup
de 1e9 : `Player.take_damage` tire l'esquive (`evasion_chance`) et la parade au hasard, et une pièce portée peut en donner.
Rien à voir avec la durée : le test met à zéro esquive, parade et bouclier avant le coup fatal. Même durcissement dans
`test_m1`, `test_br4` (2 coups) et `test_royale`. Second tirage au hasard : « scripté équipement complet en 9 coffres » échouait
1 fois sur 40 (un remplacement « nettement meilleur » peut passer avant le dernier emplacement vide) : accepté de 9 à 11 coffres.

## Résultats (copie propre de HEAD + tests)
`test_br3` 48 / 48 verts avec 16 en parallèle (avant : 2 à 3 échecs sur 30-48) ; `test_m1`, `test_royale`, `test_br4`, `test_hud`
verts 3 fois sur 3.
