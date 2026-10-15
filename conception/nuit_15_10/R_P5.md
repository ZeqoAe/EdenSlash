# R_P5 — Bilan des insignes, verrous de PE, progression de bout en bout, époque I (passe P5, version 0.1.184)

Règles dans DESIGN.md, « Verrous de PE (passe P5) ». Tests : `test_results` (insignes), `test_e6` (seuils + simulation).

## 1. Bilan de la Survie : d'où viennent les insignes

`ResultsScreen.insignia_tip()` lit `Run.insignia_parts` (écrit par `Run.finish`, remis à zéro par `Run.start`) :
Participation (+50 : 25 + la 1re carte), « Carte 2 atteinte » / « Cartes 2 et 3 atteintes », Monstres et élites, Victoire,
bonus du Défi / du rang héroïque (le reste du total), Autel de la fortune. **Les lignes font exactement le total affiché**
(`insignia_lines()`, vérifié). Notes d'une ligne quand il le faut : « Vaincs 10 monstres : +25 de participation »,
« Run courte : participation selon le temps passé sur la 1re carte », « Monstres comptés : 1500 par carte au plus ».
Avant : « Participation +25 » et 25 × carte en dur, faux depuis E6 (prorata, plafond). `test_results` : 3 cas de plus
(run courte = +5, victoire d'époque II avec défi et autel = somme exacte, moins de 10 monstres).

## 2. Verrous de PE recalés sur la PE réelle (simulation)

`tools/progression_sim` note maintenant la PE et le niveau des pièces à chaque jalon, et quand chaque verrou du jeu
s'ouvre (`open_dungeon_1/2`, `open_siege_*`, `open_rush_*`, `legend_60/90`) ; `--gates` imprime la PE requise de chaque
zone et la PE d'équipements types. Constat : la PE réelle vaut 3 à 3,5 fois l'« attendue » en fin de jeu (pièces +10,
gemmes, enchantements, panoplies) ; avec 0,55 / 0,8, **tout le Mythique s'ouvrait 40 min après l'époque II** (PE 15 600,
un équipement d'époque I à +10 fait 15 800 ≥ 14 400).

| Verrou | Avant | Après | PE requise |
|---|---|---|---|
| Donjon Héroïque (`DIFF_RATIO[1]`) | 0,55 | **3,6** | 25 300 (1re zone, niv. 29) → 55 100 (dernière, niv. 75) |
| Donjon / Ruée Mythique (`DIFF_RATIO[2]`) | 0,8 | **3,1** | 55 800 (niv. 90) ; Ruée Héroïque 41 500 |
| Siège Héroïque / Mythique (`Siege.POWER_RATIO`) | 0,65 / 0,9 | **4,0 / 3,4** | 28 100 → 61 200 / 61 200 |
| Butin légendaire (`LEGEND_RATIO`) | 0,5 | **1,8** | coffre niv. 40 : 16 200 ; niv. 90 : 32 400 |

Normal reste à 0 (donjon et Siège). Plus besoin du verrou de niveau proposé par E6 : aucun équipement d'époque I ou II,
même à +10, n'atteint un Héroïque ou un Mythique (test). Pages Donjon / Siège / Ruée : **jauge** « PE requise · la tienne »
sous la difficulté (verte quand elle suffit, infobulle : comment monter sa PE) ; le résumé « PE / attendue · Redoutable »
de la difficulté Normale (trompeur) est retiré ; le pied du bouton fermé dit seulement « Puissance d'équipement
insuffisante » (plus de doublon avec la jauge). Captures regardées : `user://shots/p5/` (`tests/shot_p5.tscn`).

## 3. De bout en bout (joueur moyen, 24 comptes, 60 h, après les réglages)

| Heure (médiane) | Époque / PE | Ce qui s'ouvre |
|---|---|---|
| 0 h | compte neuf, PE 3 900 | Survie, entraînement ; Coffres, Armurerie, Carnet dès la 1re run |
| 1,5 h (5 runs) | **époque I gagnée**, PE 5 600 | Forge, Tour (puis Duel, Ligue par les duellistes) |
| 6,7 h (15 runs) | **époque II**, PE 11 300 | Donjons, Siège, Ruée en Normal |
| 11,2 h | PE 23 300 | légendaires dans les coffres de niveau 60 |
| 13,3 h | PE 26 200 | 1er donjon **Héroïque** ; Siège Héroïque à 14,9 h |
| 16,2 h (31 runs) | **époque III**, PE 28 200 | légendaires niv. 90 (16,8 h) ; Héroïques suivants zone après zone ; Ruée Héroïque 21,5 h |
| 28,0 h (52 runs) | **époque IV**, PE 52 700 | rangs héroïques ; **Mythique** (donjons, Ruée) à 28,1 h |
| 33 h | équipement complet, PE 64 400 | Siège Mythique (32,7 h) |

Pas de mur : l'écart le plus long (III → IV, 12 h) a toujours un verrou qui s'ouvre (Héroïque d'une zone toutes les 2-3 h,
Siège, Ruée). Pas de trou : jamais plus de ≈ 5 h sans nouvelle activité ou nouvelle difficulté. « Bon » / « débutant » (avant
l'adoucissement de l'époque I) : Héroïque 10,9 / 18,6 h, Mythique 24,5 / 36,7 h, toujours juste après leur époque III / IV.

## 4. Époque I : adoucie (×1 → ×0,85)

Pilote automatique (`tools/sim_survie.py --hub new --human 0.4`, 5 classes × 3 graines, compte neuf, carte 1) :

| | survit 7 min | boss de la carte 1 atteint | boss battu | morts avant 4 min |
|---|---|---|---|---|
| Avant (×1) | 53 % | 27 % (4/15) | 0 | 2/15 (chasseur) |
| **Après (×0,85)** | **73 %** | **47 % (7/15 ; 7/13 = 54 % hors 2 runs de clerc où le bot n'a jamais trouvé la porte)** | 13 % | 2/15 (chasseur) |

Simulation : 1re victoire d'époque I **13 → 5-6 runs** (cible 5-8), époque II 7,5 → 6,3-6,7 h, IV ≈ 25-28 h (inchangée
à la marge). Décision : `Epochs.MONSTER_MULT[0]` 1 → 0,85 (PV et dégâts, époque I seulement) ; II-IV intactes.

## Reste / pièges

- **Chasseur** : 0/3 au-delà de 4,5 min avant comme après (le bot ne recule pas : arme à distance au contact). À vérifier
  au jeu réel avant de toucher la classe.
- Le bot rate parfois la porte du boss (clercs en rage à 10 min) : « boss atteint » est sous-estimé.
- `GearPower.TIERS` (Faible → Redoutable, rapport à l'« attendue ») et le Registre (E3) disent « Redoutable » dès que la PE
  dépasse l'attendue, bien avant les Héroïques. Revoir `TARGET_RATING` (≈ 30 ferait coïncider l'attendue avec la PE réelle)
  demanderait de recaler le Registre et `test_ideas` : non fait.
- La simulation ne joue les Mythiques qu'avec des pièces de niveau ≥ 78 (`DUNGEON_LEVEL_SLACK`) : 29 % des comptes y vont
  avant 60 h ; le verrou du jeu, lui, s'ouvre à 28 h.
- `test_e2` : 2 échecs de maîtrise du Duel (`core/duel.gd` modifié par une autre session, sans lien).
- `Unlocks` « siege » dit encore « puis atteins une puissance d'équipement suffisante » alors que le Normal est à 0 PE
  (ligne en cours de modification par une autre session : non touchée).
- Retouches hors lot : `core/run.gd` (1 ligne), `core/rewards.gd` (commentaire), `ui/lobby.gd` (jauge, `PE_LOW`),
  `tests/test_e6.gd`, `tests/test_results.gd`, `tools/progression_sim.gd`, `core/epochs.gd`, `core/siege.gd`, `core/gear_power.gd`.
