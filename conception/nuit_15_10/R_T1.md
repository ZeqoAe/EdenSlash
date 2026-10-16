# R_T1 — Stabilisation des tests (sans toucher au gameplay)

Session T1. Seuls des tests ont changé (`test_br2`, `test_m1`, `test_m6`, `test_m8`, `test_p13`, `test_lot17`, `test_workshop`) ; aucun script du jeu.
Mesures : copie propre de HEAD (0.1.236) + ces correctifs, `python tools/run_tests.py`.

## Causes trouvées

| Test | Symptôme | Cause | Correctif |
|---|---|---|---|
| `test_br2` | plantage Godot (0xC0000005) au départ du test | Toutes les vérifications passent ; le crash est **à l'arrêt** : `ProcMap._setup_navigation` lance `bake_from_source_geometry_data_async` (fil du moteur) et le test quittait tout de suite après la génération des deux cartes. Reproduit avec une sonde de 10 lignes (`generate_run` seul, puis quitter : crash à chaque fois ; avec une seconde d'attente : jamais). Ce n'est ni un coffre, ni un shader, ni le rendu. | Le test attend l'événement « maillage posé » de chaque carte (`_region.navigation_mesh != null`) avant de quitter, et le vérifie. 5/5 propres. |
| `test_m1` | « sans pondération (Facile) : le plus proche » (~1 fois sur 30) | La carte est tirée au hasard : un des 64 coffres d'origine pouvait se trouver plus près (< 8 m) du point d'essai que le coffre simple posé par le test, ou valoir plus que lui. | Pendant le choix, le test met de côté les coffres de la carte (`rd._chests`) et libère les réservations ; seuls les deux coffres d'essai comptent, puis il remet tout. L'intention (pondéré = doré à 22 m, Facile = le plus proche) est intacte. 40/40 verts (1/32 rouge avant). |
| `test_m6` | « vague 1 : escouades par rôle (["melee"]) » sous charge (2/16) | Le test attendait « 8 monstres vivants » ; les escouades arrivent l'une après l'autre, donc un seul rôle était là. | Il attend l'événement : ≥ 8 vivants **et** ≥ 2 rôles **et** ≥ 2 espèces (bornes en temps de jeu). 32/32 verts à 16 en parallèle. |
| `test_p13` | « Bot : coffre d'équipement choisi seul (sac 0 -> 0) » (1/12 à 12 en parallèle) | Pas la charge : la pièce tirée est portée tout de suite (`Run.apply_card`, Survie) ; si son emplacement est vide, le sac gagne 1 puis perd 1. Le contrôle ne regardait que le sac. | Il compte sac + équipement porté. |
| `test_p13` | attentes en durée | `create_timer(6.0)` avant de regarder le héros teint ; garde-fou en temps réel (270 s) sur le pilote automatique ×3, qui manque de temps de jeu sous charge. | Attente de l'événement (héros habillé, monde prêt) ; le pilote joue jusqu'au temps de **jeu** voulu, garde-fou seulement si le jeu ne progresse plus pendant 60 s réelles. 10/10 verts à 10 en parallèle. |
| `test_m8` | « Tour : dégâts du Barde × son multiplicateur, pas en donjon » (2 fois sur 3 en `-r 3`) | Le contrôle comparait le bonus de dégâts de deux mondes tirés séparément (1,30 contre 1,18 : le bonus de départ varie d'une partie à l'autre). | Le facteur se mesure dans **un seul monde** en basculant l'indicateur « donjon » (`Tower.dungeon`), dans la Tour et dans un vrai donjon. 24/24 verts. |
| `test_lot17` | « cerveau tombé aussi : manche gagnée » (2/16) | Le premier coup au scripté pouvait tomber pendant une invulnérabilité : il restait debout et le contrôle « la manche continue » passait pour de mauvaises raisons. | On répète le coup jusqu'à ce que le scripté soit tombé et on le vérifie. 32/32 verts à 16 en parallèle. |
| `test_workshop` | « forge : Polir montre la qualité avant → après » (aléatoire) | La qualité de la pièce d'essai est tirée dans [0,7 ; 0,9] ; au plafond, la forge écrit « maximale » au lieu de « jusqu'à … ». | Qualité fixée à 0,8 dans le test. 16/16 verts. |

## Suite complète (`-j 4`, copie propre de HEAD 0.1.236 + correctifs)
96 tests (planches de captures exclues) : 95 verts, `test_workshop` rouge (aléatoire, corrigé). Passe d'instabilité `-r 3` sur 83 tests courts : `test_m8` et `test_lot17` instables (corrigés) ; `-r 2` sur les 9 tests longs (p4_activities, p18_modes, siege, e6, royale, p11, m2, pursuit, sv4) : tous verts.
Résultat final : 96 verts, 0 rouge, 0 instable. Aucun vrai bug du jeu trouvé. Seule observation : le bonus de dégâts de départ d'un héros neuf varie d'une partie à l'autre (1,10 à 1,30 pour le Barde), ce qui est attendu (équipement de départ tiré), mais le fait de le comparer entre deux mondes ne vaut rien.

## Pièges à retenir
- Un test qui génère une `ProcMap` doit **attendre son maillage de navigation** avant `quit()` (plantage moteur à l'arrêt sinon).
- Un contrôle qui compte le sac doit aussi compter ce qui est porté (la Survie équipe tout de suite).
- Un lambda sur plusieurs lignes dans un appel plante le parseur GDScript (`Expected closing ")"`) et le test reste suspendu jusqu'au délai : utiliser une méthode.
