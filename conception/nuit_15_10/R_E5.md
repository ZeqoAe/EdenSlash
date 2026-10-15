# R_E5 — Barème des insignes, puits, maîtrise des 60 classes (B5 + B6)

Tout est dans `game/scripts/core/economy.gd` (`Economy`). Test : `tests/test_e5.tscn`. Chiffres recalculés par
`res://tools/insignia_probe.tscn` (armurerie réelle : **1 810 pièces** depuis les capes d'E4).

## B5 — Insignes

**Barème** (`Economy.INSIGNIA_PER_HOUR`, vérifié par le test ; 100 % de victoires) :

| Activité | Insignes / h | Remarque |
|---|---|---|
| Survie (référence) | 360 (époque I) → 670 (époque IV) | formule déplacée dans `Economy.survival_insignia`, inchangée ; héroïque ×(1 + 0,15 × rang) |
| JcJ contre l'IA | ≈ 394 la 1re heure du jour, puis ≈ 60 | plafonds d'E2 gardés (somme des 1res victoires ≤ 450 ≤ Survie IV) |
| Donjons, Ruée, Siège, Tour | 0 | rôle = cristaux et matières (E1) |

**Armurerie à paliers** (`Economy.armory_price`, branché dans `GearShopPage.price`) : 1re pièce d'un palier (emplacement,
type d'arme, niveau, rareté, éveil) au prix plein, les autres pièces du même palier à **15 %** (autres panoplies / attributs,
utiles à d'autres classes) ; pièces des Esprits jamais remisées.

| Époque | Pièces / paliers | Collection avant | Collection après | 1 pièce par palier | Kit d'une classe | 1re pièce |
|---|---|---|---|---|---|---|
| I | 245 / 60 | 15 746 = 44 h | 5 614 = **16 h** | 11 h | 648 = 1,8 h | 50 (une défaite carte 1 = 52) |
| II | 331 / 71 | 38 850 = 84 h | 13 143 = **28 h** | 19 h | 1 800 = 3,9 h | 75 |
| III | 613 / 70 | 133 380 = 236 h | 33 359 = **59 h** | 27 h | 2 140 = 3,8 h | 210 |
| IV | 621 / 72 | 153 890 = 230 h | 38 421 = **57 h** (≈ 33 h au rang héroïque 5) | 27 h | 2 230 = 3,3 h | 240 |

Total : 341 866 → 90 537 insignes. Époques III-IV restent au-dessus de la cible 20-30 h : voulu (≈ 9 pièces par palier,
objectif de collectionneur ; l'utile, une pièce par palier, tient en 27 h).

**Puits** (sans puissance gratuite) : coffres d'apparence et d'auras (`SHOP_CHESTS` : rare 150 ×3, mythique 300 ×2, légendaire
600 ×1, aura rare 400 ×1, aura légendaire 900 ×1 par semaine = 2 950 / semaine au plus ; fermé quand la rareté est complète) ;
**leçon de maîtrise** (200 insignes → 300 points, classe en retard seulement, 3 par jour = 600 / jour). Compteurs dans
`Profile.records.insignia_shop` (semaine du lundi, jour).

## B6 — Maîtrise des 60 classes (17 480 points pour le niveau 20)

- **Rattrapage** ×1,5 en Survie (contrats compris) pour une classe à 3 niveaux ou plus sous la meilleure du compte, jusqu'au 20.
- **1re victoire de la classe** à chaque époque : +600 / 900 / 1 200 / 1 500 (`Profile.records.class_first_wins`).
- **Part de l'arbre** : 10 % de toute maîtrise gagnée (Survie, Tour, JcJ…) va aux voisines de l'arbre de déblocage (classe
  d'origine et classes qui en descendent), débloquées et plus basses ; pas de cascade, pas pour les leçons.
- **Défi de maîtrise** : les deux classes tirées au hasard sont prises parmi les classes en retard quand il y en a 2+.

| Survie victorieuse type (niv. 35, 600 monstres, 10 élites) | Avant | Après (classe en retard) |
|---|---|---|
| Gain par run | 1 365 (+ contrats ≈ 1 275, est.) = 2 640 | 3 960 |
| Runs pour le niveau 16 / 20 | 4,3 / 6,6 (12,8 sans contrats) | 2,1 / 3,6 (1re victoire IV + part de l'arbre ≈ 1 700) ; 4,0 sans part |
| 60 classes au niveau 20 | ≈ 397 runs (≈ 230 h) | ≈ 219 runs (≈ 128 h) |

## Décisions
- Remise par palier plutôt que baisse des prix : le kit d'une classe garde son coût (progression), seules les alternatives
  pour les autres classes deviennent bon marché. 15 % plutôt que 25 % (25 % : 80 h pour III-IV).
- Rattrapage relatif à la meilleure classe (pas de seuil absolu) : la 1re classe garde le rythme réglé par N1.
- Pas d'insignes pour Donjons / Tour / Siège (rôle unique) ; pas de conversion insignes → cristaux (puissance).

## Retouches hors de mes fichiers
`core/run.gd` (`finish` : rattrapage, 1re victoire, `shared_gain`, formule des insignes), `core/profile.gd` (`add_expertise(…, share)`,
`last_shared`), `core/challenge.gd` (`classes_today`), `ui/gear_shop_page.gd` (corps de `price` = 1 ligne, U5 terminé). Commit partiel
(HEAD + mes remplacements) pour `run.gd` et `DESIGN.md`, qui portent aussi le travail en cours d'E4 / U9.

## Reste (passe d'interface)
- Boutons : « Acheter » des coffres dans Coffres (`Economy.buy_chest`, `chest_left`) et « Leçon » dans Héros > Maîtrise (`buy_lesson`).
- Bilan de Survie : `Run.expertise_catchup`, `Run.first_win_bonus`, `Run.shared_gain` (déjà comptés dans `expertise_gain`, pas détaillés).
- Armurerie : montrer « palier entamé » (prix barré) dans le détail.
- E6 : mesurer au journal les contrats par run (1 275 est une estimation) et la durée réelle d'une Survie.
