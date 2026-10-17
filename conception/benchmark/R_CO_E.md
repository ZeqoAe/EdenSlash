# R_CO_E : Le Colisée, lot CO-E — atouts (17/10/2026)

Étude : `ARENA.md` § 6.6 (32 atouts, raretés, offres notées, recette), § 6.9 (choix de l'IA), § 6.12 (confort) ; socle : `R_CO_A.md`,
`R_CO_C.md`, `R_MODE0.md`. Lot = backlog n° 6. Fait avec le lot CO-F (économie, `R_CO_F.md`) ; l'IA d'équipe (CO-D) est d'une autre
équipe : coordination par `choose_augment` / `choose_anvil` (`R_CO_F.md` § 4).

## 1. Ce qui a été livré

| Élément | Fichier | Rôle |
|---|---|---|
| Atouts | `game/scripts/core/colisee_augments.gd` (`ColiseeAugments`) | données (`LIST` : 32 atouts, `RARITIES`, `ROLES`), affichage (`card`, `texture`), offres notées (`offer_rarity`, `make_offer`, `reroll`, `eligible`, `score`, `role_note`, `context_for`), choix de l'IA (`choose_augment`, `offer_dicts` pour le chef d'équipe), prise (`take` : recette, Pacte de sang, Maître des sorts), effets (`effects_for`, `sheet_bonus`, couche de combat : `apply_hero`, `sheet`, `begin_fight`, `tick`, `end_fight`, `reset_round`, `stop`, crochets `pre_hit`, `absorb`, `post_hit`, `dealt_mult`, `status_time`, dégâts vrais `deal_true`, journal `counts`) |
| Crochets du combat | `game/scripts/combat/combatant.gd` (5 lignes gardées par `ColiseeAugments.active`), `game/scripts/player/player.gd` (`recalc_stats` -> `ColiseeAugments.sheet`) | rien ne change hors du Colisée (le drapeau est faux) |
| Directeur | `game/scripts/core/colisee_director.gd` | construction posée sur chaque héros qui apparaît, Bouclier d'entrée / Ombre jumelle / fleurs au début des combats, `tick` chaque image, fin (`end_fight`, `stop`) |
| Banc IA contre IA | `game/tools/colisee_aug_bench.tscn` (+ `colisee_aug_bench_director.gd`), `tools/colisee_aug_report.py` | § 3 |
| Test | `game/tests/test_co_e.tscn` | § 5 |

## 2. Les 32 atouts (valeurs de départ de l'étude ; texte de carte = une phrase sans chiffre, chiffres en infobulle)

| Rareté | Atouts | Effet codé |
|---|---|---|
| Argent (10) | Lame affûtée, Peau de chêne, Pas léger, Concentration, Première frappe, Sangsue, Bouclier d'entrée, Esquive agile, Tirelire, Main verte | auto-attaque +20 % (joueur : `basic_mult` ; héros scripté : coups d'arme seulement, son compteur de combo), PV +15 %, course +12 %, recharge −12 %, 1er coup du combat ×1,8, vol de vie 6 %, bouclier 15 % 6 s, recharge d'esquive −25 %, +4 or, fleurs ×2 |
| Or (14) | Écho, Serment, Garde rapprochée, Relève éclair, Chasseur de têtes, Coup de grâce, Contre-coup, Ronces, Marque du chasseur, Ancre, Braise, Givre, Foudre, Mise | sort de 10 s et plus : 2e coup à 50 % 0,6 s après ; allié à terre : bouclier 25 % 5 s ; alliés à 6 m −10 % (une seule garde) ; *relève (lot CO-J : jamais proposé avant)* ; K.O. ou aide (3 s) : −50 % de recharge restante ; sous 10 % après ton coup : K.O. (pas sous un bouclier, ni dans la seconde d'un Deuxième souffle) ; esquive à 5 m : riposte 60 % (2 s) ; 15 % des coups reçus de près renvoyés ; ta cible +12 % des coups de ton trio 4 s ; ni repoussé ni attiré, contrôles ÷ 2 ; brûlure 3 s ; ralenti 1,5 s ; rebond 40 % à 4 m ; +15 or sur victoire, 0 sur défaite |
| Éclat (8) | Tempête (recette), Deuxième souffle, Colosse, Maître des sorts, Ombre jumelle, Trio parfait, Roi de l'arène, Pacte de sang | Braise + Givre + Foudre × 1,5 et deux places libres ; survit à 1 PV et 1 s intouchable une fois par combat ; PV +40 %, taille × 1,3, −10 % de course ; un sort de plus ; double à 40 % 10 s ; trio de 3 familles +10 % dégâts et PV (un seul compte) ; centre : +3 %/s jusqu'à 30 % ; −15 PV d'équipe, +25 % de dégâts (pas sous 30 PV) |

- **Offres** : manches 1 (Argent, ou Or 1 fois sur 3), 4 (Or), 7 (Or, ou Éclat 2 fois sur 5), 10 (Éclat) ; Éclair 1 / 3 / 5 / 7. Trois cartes
  de la même rareté, de trois thèmes différents (coups, survie, mobilité, sorts, équipe, recette, or, arène, risque), tirées au carré de
  leur note parmi les ¾ les mieux notées ; **jamais une carte de note de rôle sous 0,3** (pas de Ronces à un tireur) ; 3 relances par
  partie, une carte à la fois ; 6 atouts au plus.
- **Note** (`score`) : note de rôle (tank, mêlée, distance, soin : fiche de l'Échiquier), +0,15 pour un atout de sorts chez un mage ;
  synergie : pièces de recette tenues (+0,35 chacune), équipiers de mêlée pour les atouts d'équipe ; état de la partie : l'or vaut plus
  tôt (Tirelire, Mise ; Mise selon le taux de victoire), la survie quand les PV d'équipe baissent, Pacte de sang moins quand ils sont bas.
- **Choix de l'IA** (`choose_augment`, comme l'étude § 6.9) : Facile au hasard, Normal note de rôle bruitée (±0,25), Difficile note +
  synergie (±0,1), Hardcore et **choix au temps écoulé du joueur** : la meilleure note, sans bruit. Le chef d'équipe du lot CO-D, s'il
  est là, choisit à la place (appel dynamique de `ColiseeCoach.choose_augment` avec `offer_dicts`).
- **Plafonds contre l'explosion de puissance** : bonus de dégâts continus (enclumes, Pacte, Trio, Roi, Marque) × 1,6 au plus, dégâts
  reçus × 0,75 au moins (Garde), PV en plus + 70 % au plus, course de −20 % à +25 %, recharge et critiques aux plafonds du profil
  « colisee » ; puis le coup plafonné à 15 % des PV et 35 % sur 2 s comme avant (Première frappe ne perce pas ce plafond).
- Les héros scriptés sont recréés à chaque manche : leurs atouts (et ceux du joueur) sont reposés par `apply_hero` à l'apparition ;
  les états de combat (première frappe, deuxième souffle, boucliers, marques, Roi) repartent à zéro à chaque combat.

## 3. Mesure de l'équilibre (banc IA contre IA)

**Méthode** : `tools/colisee_aug_bench.tscn` monte la vraie carte du Colisée (3 arènes) dans `world.tscn` et fait combattre, en même
temps et pour de vrai, un trio de trois familles **contre le même trio** (mêmes classes, mêmes places, Hardcore, 60), l'un portant
l'atout mesuré (ses trois héros), l'autre rien ; le camp porteur alterne. Le taux de victoire donne un écart de force par héros (logit ÷ 3 :
les forces s'ajoutent), puis `tools/colisee_aug_report.py` le change en **« top 3 relatif »** : écart de part de places 1-3 (moitié haute du
Classique) d'une équipe qui prend l'atout à sa manche d'offre, par rapport à un atout moyen de la même rareté, dans des parties simulées
(modèle de `Colisee.simulate`). Les atouts d'or passent par la valeur d'une pièce d'enclume (pseudo-atouts « gear:2 », « gear:5 »).
Machine du joueur saturée (30 à 34 Godot actifs) : le banc tourne à 30 images par seconde de jeu (`--hz=30 --fixed-fps 30`).

**Résultats : mesure en cours** (banc lancé, 3 × 10 combats par atout) ; chiffres, réglages et verdict au prochain envoi.

## 4. Pièges pour la suite

1. Tout nouvel effet d'atout passe par la couche `ColiseeAugments` (crochets de `Combatant`) : jamais de test `Colisee` dans un autre
   fichier. Le drapeau `ColiseeAugments.active` doit retomber à la fin (`stop` : fin de partie, abandon, sortie de l'arbre).
2. Les dégâts vrais (Ronces, Foudre, Écho, Coup de grâce) passent par `deal_true` : un coup « dot » imposé dans `absorb`, sans procs.
3. Le joueur ne subit aucun repoussement (Player) : Ancre ne sert qu'aux héros scriptés ; le Givre ralentit le joueur par sa fiche.
4. Relève éclair reste hors des offres tant que `READY_NEEDS` n'a pas « releve » (lot CO-J).

## 5. Tests

`test_co_e` (≈ 68 contrôles, 90-120 s) : données (32 atouts, raretés, phrases sans chiffre ni %, icônes Ico présentes, noms uniques,
recette, Relève éclair hors offre, données d'affichage) ; offres (60 classes × 3 raretés × 6 états : 3 cartes de la même rareté, toutes
prenables, jamais incohérentes, thèmes différents ; un soigneur voit Concentration plus que Lame affûtée ; relance d'une carte, 3 par
partie ; choix Hardcore = meilleure note, Facile au hasard ; format du chef d'équipe) ; prise (recette -> Tempête, effets × 1,5, Pacte de
sang −15 PV et interdit sous 30, Maître des sorts, 6 au plus, Trio parfait unique, plafond des PV) ; **chaque effet sur des mannequins**
(héros scriptés immobiles) : les 31 atouts de combat ; plafond des dégâts ; puis une vraie partie (constructions des 18 héros, atout et
or des IA à la manche 1, construction sur chaque héros du combat, fiche du joueur, effets en combat réel, or de la manche 2, abandon).

Résultats (copie de HEAD 0.1.306 + CO-E / CO-F, `run_tests.py --reuse -j 2`, 30 à 34 Godot actifs) : `test_co_e`, `test_co_f`,
`test_co_a`, `test_co_b`, `test_co_c`, `test_mode0`, `test_names_fr`, `test_texts_fr`, `test_pvp` : voir la ligne du journal des versions.
