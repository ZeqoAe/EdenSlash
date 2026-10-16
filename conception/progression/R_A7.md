# R_A7 — outils de mesure de la refonte « Aventure » (16/10/2026)

Lot A7 de `REFONTE_AVENTURE.md` §5. Fichiers : `game/tools/progression_sim.gd`, `game/tests/test_e6.gd`. Aucun fichier de jeu touché.

## Fait
- Drapeaux de la copie de PR1 intégrés à l'outil du dépôt (variables, réglables par `test_e6` sans ligne de commande) :
  `--refonte` (Donjons dès l'époque I gagnée, zones des époques gagnées seulement, donjon de 7 min, plans de donjon fabriqués
  en insignes au prix `Economy.base_price` du modèle, panoplie du donjon, légendaire en Mythique), `--hubvalue` (pièces choisies
  sur leur PE), `--decote` (décote de palier), `--heroic=` / `--mythic=` (autres `GearPower.DIFF_RATIO`).
- Jalons `dungeon_0`, `kit80_ok` (9 pièces ≥ 78, légendaires, +5), `kit90_ok` (≥ 86), `kit90_opti` (≥ 86, +10, gemmes ≥ 4, ench. ≥ 7).
- Nouveau `--plans=boss` (avec `--refonte`) : un plan par boss (6 par zone, 2 emplacements chacun, panoplie du boss), sûr à la
  1re victoire contre lui, au niveau de la meilleure difficulté — le modèle du lot A1. Par défaut, l'approximation de PR1 (un plan
  par zone et difficulté pour les 9 emplacements, sûr au 1er donjon fini puis 10 %), pour reproduire le §3.1.
- `test_e6` : décote (facteur, plancher, arme, pièce sans niveau d'Eden, puissance d'une vraie pièce) et un compte « H » (6 comptes,
  45 h, graine 11) : époque I 2-4 h, 1er donjon ≤ époque I + 1 h, plans gagnés et fabriqués, équipement 80-90 correct ≤ 40 h.

## Décision
- **Décote émulée dans l'outil, pas dans `Items`** : chaque pièce d'Eden sous le palier devient, le temps du calcul de puissance,
  une copie sans « eden » avec `plevel` = min(niveau du héros, plafond) × facteur. Même résultat que la copie de PR1 (qui modifiait
  `Items.power_level`), sans toucher `items.gd` (lot N2 en cours, réglage réel = lot A6). Quand A6 aura posé la décote dans le jeu,
  `--decote` devra être retiré de l'outil (sinon elle compterait deux fois).

## Mesures (12 comptes « moyen », guerrier, 50 h, graine 1, sur une copie propre de HEAD 0.1.219)
Les six colonnes du §3.1 se reproduisent **à l'identique** (médianes, h) :

| Jalon | A | E | B | D | G | H | H, plans par boss |
|---|---|---|---|---|---|---|---|
| époque I | 2,8 | 2,8 | 2,9 | 2,8 | 3,0 | 3,0 | 3,1 |
| époque II | 8,2 | 8,6 | 8,0 | 9,3 | 9,4 | 8,3 | 8,7 |
| époque III | 16,8 | 21,7 | 14,0 | 22,7 | 18,9 | 15,9 | 15,6 |
| époque IV | 30,8 | 39,1 | 28,7 | 39,4 | 28,9 | 29,9 | 26,3 |
| 1er donjon | 8,2 | 8,8 | 2,9 | 3,1 | 3,1 | 3,1 | 3,1 |
| Héroïque ouvert | 13,5 | 16,4 | 12,8 | 17,6 | 16,8 | 14,7 | 13,0 |
| Mythique ouvert | 29,2 | 37,7 | 27,6 | 33,6 | 30,6 | 26,7 | 28,4 |
| kit +10 complet | 33,0 | 42,0 | 26,0 | 35,3 | 32,7 | 29,7 | 32,9 |
| équipement 80-90 correct | — | 42,0 | — | 37,5 | 32,4 | 29,3 | 32,9 |

Lecture de la dernière colonne : avec le vrai modèle d'A1 (2 emplacements par plan au lieu de 9), l'équipement correct arrive
≈ 3,5 h plus tard (32,9 h) ; reste dans la borne d'A6 (≤ 33 h) mais juste. À remesurer après A1 / A6 avec `--plans=boss`.

Commande : `godot --headless --path game res://tools/progression_sim.tscn -- --accounts=12 --hours=50 --seed=1 --quiet
--refonte --hubvalue --decote --mult=0.85,1.3,2.3,4.4` (≈ 10 min ; colonnes en parallèle avec un `APPDATA` par processus).

`test_e6` (colonne H, 6 comptes, 45 h, graine 11) : époque I 3,9 h, 1er donjon 3,9 h, époque IV 26,8 h, équipement correct
37,0 h (67 % des comptes), 53 plans gagnés mais **2 pièces seulement fabriquées sur plan** : dans le modèle, la pièce d'un plan
(mythique au niveau du donjon Normal, légendaire en Mythique) bat rarement la pièce de l'Armurerie déjà portée ; la panoplie de
donjon n'est pas valorisée par le choix des pièces. À regarder avec A1 / A6 (prix, niveau du plan, valeur de la panoplie).

## Pièges
- Mesurer sur une copie propre (`tools/run_tests.py` `preparer_copie`) : le dossier de travail contient les modifications non
  poussées des autres lots (N2 : `run.gd`…), qui changent les chiffres.
- Le simulateur ne modélise ni le coffre de plans des boss de carte (A4) ni les quêtes (A5 : elles ne paient plus d'insignes).
