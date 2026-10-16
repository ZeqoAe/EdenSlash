# R_A5 — économie sans « bash » (16/10/2026)

Lot A5 de `REFONTE_AVENTURE.md` §5 (et §2.5). Fichiers : `core/economy.gd`, `core/quests.gd`, `ui/results_screen.gd` ; tests
`test_e5`, `test_results`, `test_quests`, `test_e6`. Retouches de textes hors lot (une ligne chacune) : `ui/activities.gd` (pastilles
des Quêtes), `core/tutorial.gd` (fiche « Quêtes »), `core/resource_help.gd` (« Survie (cartes et boss) », déjà embarqué par le
commit d'A1). `core/quest_pool.gd` : rien à changer (les récompenses sont tirées dans `quests.gd`).

## Fait
- **Insignes de la Survie** (`Economy.survival_insignia_parts`, constantes nommées) : participation 25 + 25 pour la 1re carte (au
  prorata sur la 1re carte, E6), **35 par carte suivante**, **monstres / 40**, élites × 2, **15 par boss de carte** (cartes finies :
  `stage − 1`, + 1 sur victoire), victoire 60 × époque. Nouvelle ligne du bilan « Boss de carte vaincu » / « N boss de carte vaincus ».
- **Quêtes** : plus d'insignes, de cristaux ni de coffres de parchemins. Du jour : maîtrise 150 / 250 / 350 de la classe en retard
  (7 tirages sur 10), sinon coffre d'apparence (commun, rare pour les grandes quêtes). Semaine : 600 de maîtrise + apparence rare, ou
  apparence épique. Sans classe en retard, la maîtrise devient un coffre d'apparence (avant : des insignes). **Migration** : une quête
  déjà tirée garde `q.r` et `grant` la paie telle quelle (insignes, cristaux, coffre de forge) ; le tirage suivant suit le barème neuf.

## Décisions
- **La 1re carte reste à 25** (pas 35) : à 35, l'abandon à 1 min passait de 5 à 6 insignes ; or l'acceptation dit « une défaite
  express n'est pas mieux payée ». Les cartes suivantes sont à 35.
- **Victoire de référence = la victoire réelle** : `SURVIVAL_KILLS` 600 → 2 000, `SURVIVAL_ELITES` 10 → 20 (journal ≈ 2 500,
  progression_sim ≈ 1 800). À 600 monstres, le nouveau barème donnait +29 % (les 600 d'E5 sous-estimaient les monstres) ; sur une
  victoire réelle il est à ± 10 %. `INSIGNIA_PER_HOUR` survie_1 / survie_4 = 540 / 849 (la même victoire valait 514 / 823 avant).
  JcJ (400 la 1re heure, 60 ensuite) reste sous la Survie.

## Mesures (`test_e5`, barème avant / après)
| Run | Avant | Après |
|---|---|---|
| victoire I, 1 800 / 2 000 / 2 500 monstres | 290 / 300 / 325 | 310 / 315 / 327 (+7 / +5 / +1 %) |
| victoire IV, mêmes monstres | 470 / 480 / 505 | 490 / 495 / 507 (+4 / +3 / +0 %) |
| abandon 1 min · défaite 3 min · 5 min | 5 · 24 · 51 | 5 · 20 · 41 |
| défaite en carte 2 (15 min) · rage 60 min en carte 1 | 153 · 205 | 148 · 167 |

Une victoire avec peu de monstres (1 200) gagne +13 % : voulu (la progression paie plus que le nombre de monstres).
`progression_sim` (12 comptes, 50 h, graine 1) après A5 : colonne A époque I 2,9 h, IV 31,6 h (avant 2,8 / 30,8) ; colonne H
époque IV 25,6 h, équipement 80-90 correct 32,5 h pour 83 % des comptes (avant 29,3 h, 75 %) : écart dans le bruit du tirage
(les insignes changent l'ordre des achats), à remesurer avec A6.

## Reste
- Le Défi du jour garde ses insignes ×1,5 sur la Survie du jour (`core/challenge.gd`, hors lot) : à trancher (le §2.6 range le
  Défi avec les quêtes : maîtrise et apparences seulement).
- Commentaire périmé dans `core/run.gd` (« 25 par carte atteinte », fichier de N2) : à corriger au passage d'A4 / A9.
- Les textes disent encore « Survie » (renommage = lot A9).
