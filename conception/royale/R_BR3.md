# R_BR3 — Battle royale : coffres, améliorations, pièces au sol, inspection (16/10/2026, 0.1.216)

Retours du joueur (`RETOURS_JOUEUR.md`, points 6 et 7) + deux consignes en cours de lot : pièces lâchées à la mort (sauf
l'arme) et **réutiliser le système du Survivant** pour les pièces et les améliorations.

## Fait
- **Coffres** (`core/royale_loot.gd`) : l'arme de départ (variante de la classe) est gardée, aucun coffre ne propose d'arme ;
  une pièce par emplacement vide (3 au plus, emplacements différents) ; tant que l'équipement est incomplet, une pièce pour un
  emplacement pris seulement si elle est nettement meilleure (note de classe × 1,3 et + 0,6) ; équipement complet (9
  emplacements, cape comprise) : seulement des améliorations. Plus de « 5 arcs » : rien n'arrive dans le sac.
- **Système du Survivant, partagé** : pièce de coffre → `SurvivorGear.adopt` (nouveau : jet 100-120 %, passif fixe du modèle,
  puissance au niveau du héros) ; cartes `SurvivorCards.piece_card`, `up_card` (+2, +4 légendaire, passif +6 / +8 / +10 tiré et
  affiché, jet relevé, auto-attaque de l'arme), `weapon_item_card` (extrait de `weapon_card`, même comportement),
  `spell_up_card` (sorts 1-10, niveau 5 épique, 10 légendaire) ; rendu `SurvivorCardView` (nouveau : aussi quand
  `Royale.active`). **Adapté** : `fixed_passive(e, any_model)` (modèle hors du pool de niveau 90 : rang = numéro d'Eden),
  `SurvivorGear.release` (une pièce enlevée rend ses passifs : pièce tombée ou échangée), passifs sans objet ici (Cadavres
  explosifs, Aimant) bannis au départ ; pas de « Passer », de bannir ni de garder sur ces cartes (une relance par coffre).
  Survivant inchangé : test_sv1 à test_sv8 verts, `sv7_mesures.json` non touché.
- **Montées de niveau** : sorts et bonus seulement (plus de technique d'arme : elle vient de l'amélioration d'arme).
- **Héros scriptés** : même remplissage puis améliorations internes (`RoyaleLoot.offer` : mise à niveau, rareté, forge +N, car
  leurs pièces ne suivent pas leur niveau) ; jamais une pièce moins bonne, une seule arme de leur classe.
- **Mort** : toutes les pièces au sol sauf l'arme (repère lumineux de la couleur de rareté, nom visible de près) ; [F]
  « Prendre — Tête · Rare (▲ mieux que ta pièce) » : portée, l'ancienne reste à sa place ; un scripté va chercher une pièce
  meilleure que la sienne à moins de 35 m. Joueur : ses pièces quittent l'équipement et leurs passifs la run.
- **Inspection** (`ui/royale_gear_sheet.gd`) : la dépouille garde la fiche (classe, niveau, éliminations, place, pièces) ;
  [F] près d'elle ou, en spectateur, sur le héros suivi : 9 emplacements, carte de la pièce comparée à la tienne, « au sol » /
  « déjà ramassée » / « l'arme ne tombe pas ». Pause, B / Échap / « Fermer », navigable à la manette.

## Décisions
- Le joueur a demandé de ne pas changer le niveau d'équipement des scriptés ; remplir les emplacements vides d'abord les
  équipe bien plus vite (note d'équipement à 9 coffres : +95 %). Leurs pièces comptent donc pour `Royale.AI_GEAR_SCALE` = 0,62
  dans leurs stats (`tools/br3_ai_probe`, 8 classes × 6 tirages : -26 % à 3 coffres, 0 % à 6, +23 % à 9, +3 à +10 % de 12 à
  30). Pièces au sol et fiche : les vraies pièces.
- Remplacement « nettement meilleur » gardé (consigne) mais rare en vrai : une pièce du Survivant suit déjà le niveau.

## Mesures (`world.tscn -- --royale --autoplay --auto-quit`)
Avant (0.1.214, Hardcore / Normal) : joueur 8 pièces portées + **39 dans le sac** (Normal, 46 coffres) ; scriptés de
Normal à 8-14 coffres : 4 à 6 pièces seulement. Après : voir la fin de ce fichier.

## Tests
`test_br3` (nouveau, 29 vérifications, vert 3 fois) ; `test_royale`, `test_cards`, `test_nav_screens` (+ fiche
d'équipement), `test_sv1` à `test_sv8` verts. Captures `tests/shot_br3.tscn` (BR3_RES) regardées : arme de départ,
coffre vide, coffre complet, pièces au sol, fiche.

## Pièges
- `RoyaleDirector._fall` / `_fall_player` sont appelés dans `_on_ai_died` / `player_down` (avant la réanimation de BR4 :
  le revenant repart sans ses pièces, elles sont déjà au sol).
- 0.1.215 avait trois lignes du largage égarées dans `_debug` (erreur d'analyse) : remises à leur place ici.
- Une pièce ramassée par le joueur est « adoptée » (jet ramené entre 100 et 120, passif fixe ajouté).
