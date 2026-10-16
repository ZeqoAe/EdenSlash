# R_BR4 : largage façon Fortnite et réanimation (retours du joueur 8 et 9)

## Fait
- **Largage** (`core/royale_drop.gd`, `RoyaleDrop`) : plus de point d'apparition ni de compte à rebours. Un aigle géant
  (modèle `m092` agrandi ×4, aucun nouveau modèle) traverse la carte en ligne droite d'un bord à l'autre (direction et
  décalage tirés à la graine, 95 m au-dessus du point le plus haut de la ligne, 30 m/s : 15 à 22 s). Portes ouvertes après
  `Royale.COUNTDOWN` (6 → 3 s) ; [Sauter] (Espace / Y) saute, saut automatique en fin de vol. Chute dirigée (17 m/s),
  [Esquive] maintenue = piqué (34 contre 16 m/s), planeur ouvert seul à 26 m ([Sauter] l'ouvre plus tôt), l'atterrissage
  rend la main (physique, chacun pour soi, caméra).
- Pendant le vol : aide unique au centre en bas (« [Espace] Sauter · saut auto dans 12 s », « Dirige ta chute · [Maj]
  Piqué · [Espace] Planeur »), horloge « Largage · 3 / 8 au sol », 3 lignes d'objectif, mini-carte en vue large avec la
  ligne du vol en pointillés et l'aigle, coffres repérés à 200 m, caméra éloignée (34 m) qui revient en approchant du sol.
- **Personne n'attaque ni n'est attaquable en l'air** : un héros en l'air quitte le groupe « ffa » (identifiant gardé),
  physique coupée, ni anneau, ni coffre, ni objet cassé sous lui ; les héros à bord sont cachés (ni cadre de cible, ni point
  sur la mini-carte).
- Héros scriptés et pilote automatique : chacun vise un coffre à portée de chute (55 m au moins entre deux cibles, les
  dorés d'abord), sauts répartis sur le vol (mesure : de 4-5 s à 14-15 s), piqué dès que la chute suffit au trajet,
  atterrissage à côté du coffre (pilote : 0,2 m de sa cible), puis pillage.
- **Temps de combat** (décision) : `elapsed` (anneau, réanimation, bilan) part à l'atterrissage du dernier héros (au plus
  tard 20 s après la fin du vol : les retardataires sont posés). Ceux qui atterrissent tôt pillent et se battent déjà.
  Nouvelle horloge `clock` (depuis le départ de l'aigle) pour les coups (`PvpCaps.elapsed`, fenêtre de rafale) et le fil.
- **Réanimation** (`Royale.REVIVE_WINDOW` 120 s, `REVIVE_DELAY` 5 s, `REVIVE_SHIELD` 4 s) : éliminé avant 2 min de combat,
  on revient une fois (« Tu es éliminé : retour dans 5 s »), en planeur au-dessus du point de l'anneau (le prochain s'il se
  resserre) le plus loin des héros en vie, PV pleins, invulnérable 4 s au sol (`Player.shield_until`,
  `ClassRival._invuln_until`). Niveau, arme, sorts et cartes gardés ; **arme seule** (consigne du joueur : les pièces sont
  tombées au sol à la mort, fonction `_fall` / `_fall_player` de BR3 ; `RoyaleDirector.keep_weapon` retire le reste au
  retour, filet si une pièce n'était pas lâchée). Héros scriptés : même règle (nouveau corps, même fiche `ai_stats`).
  Pas de place tant qu'on doit revenir (compté en vie dans `alive_count`, `pending_ais` pour la place du joueur) ; chaque
  héros ne compte qu'une fois au compteur d'éliminations (sa 1re chute), l'expérience et les PV de l'élimination sont
  donnés à chaque fois. Après 2 min, ou à la 2e chute : mort définitive comme avant.

## Tests et mesures
- `test_br4` (nouveau, 35 contrôles) : vol, aide, saut à la touche, chute dirigée, piqué, planeur, atterrissage, anneau
  au dernier atterrissage, saut auto en fin de vol, pilote automatique jusqu'au coffre ; réanimation scripté et joueur
  avant 2 min (arme seule, protection, compteur d'éliminations), définitive après 2 min et à la 2e chute.
- `test_royale` adapté (largage, points d'atterrissage distincts, éliminations après 2 min) : 64 / 64 ; `test_br3`,
  `test_hud`, `test_nav_screens` verts (copie HEAD 0.1.216 + BR4).
- Partie complète `world.tscn -- --royale --autoplay --auto-quit` : se termine seule (1re place, 332 s, 43 coffres).
- Captures `tests/shot_br4.tscn` (à bord, chute, planeur, au sol, retour, revenant), regardées : aigle trop grand au
  premier essai (il couvrait l'écran) puis ×4 sous le joueur ; voile en prisme jaune remplacée par un dôme bordé.

## Pièges
- Dossier partagé : les tests ont été lancés sur une copie « HEAD + BR4 » (`mine.py` dans le brouillon de session),
  commit par l'index (`git update-index`) pour ne pas embarquer le travail en cours des autres sessions.
- HEAD 0.1.215 avait une légende de mini-carte cassée (`minimap.gd` ne se chargeait plus) : retouche minimale incluse si
  elle n'était pas déjà poussée.
- Une erreur de ma part : un `taskkill` global a arrêté 3 Godot d'autres sessions pendant la mise au point (relancer
  leurs tests s'ils ont échoué vers 16 h 50).
