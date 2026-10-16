# R_A4 — coffre de plans des boss de carte (refonte « Aventure », lot A4)

Lot A4 de `REFONTE_AVENTURE.md` §5 (décision Q5 : au choix parmi 3). Le mot « Survie » reste dans les textes (renommage = A9).

## Fait
- **Règle** : à la mort du boss de chaque carte (Survie, pas le Survivant), après l'amélioration d'arme garantie, un choix
  « Coffre de plans : choisis une pièce à fabriquer » propose **3 pièces non découvertes** du palier de la carte
  (`RunDirector.offer_plans`, `Run.plan_offer`, `SlotChests.plan_candidates`) : tous les coffres de pièce sauf les trophées
  (l'Atelier ne les fabrique pas), arme du type de la classe ; exclues : `Profile.seen_gear`, pièces choisies dans un coffre de la
  run (`seen_items`, `seen_family`), plans déjà pris dans la run, pièces portées. Pas de relance (choix court).
- **Acquis tout de suite** : `Run.grant_plan` écrit dans `Profile.seen_gear` et sauvegarde ; gardé même si la run est perdue ou
  abandonnée ensuite. Une arme fait aussi découvrir ses sœurs des 17 types (règle E4, comme une arme choisie dans un coffre).
- **Tout le palier découvert** : 30 insignes (`Run.PLAN_INSIGNIA`), crédités tout de suite, message, ligne « Plans des boss déjà
  trouvés » dans l'infobulle des insignes du bilan (la somme des lignes reste égale au total).
- **Carte** : `RunDirector.plan_card` = la carte d'un coffre d'emplacement, sous-titre « Plan · Casque · … », ligne
  « Se fabrique à l'Atelier · N insignes » (`Economy.base_price`, dite une fois sous la rangée si commune). Même `CardPicker`
  (clic, 1/2/3, manette : cadre sur la 1re carte, A choisit) ; `CardPicker.auto_pick` (pilote, aide « Bot ») prend le plus grand
  gain de note sur la pièce portée ; message « Plan choisi » en choix automatique.
- **Bilan** : une ligne « Plan trouvé : <pièce> » (valeur : l'emplacement) par plan, dans « Gardé ».
- **Fiche** `boss_plans` « Coffre de plans » (chapitre run, déclenchée au 1er coffre).
- Corrigé : le commentaire périmé « 25 par carte atteinte » de `Run.finish` (barème A5).

## Mesure (`progression_sim`, nouveau drapeau `--bossplans`)
Copie propre de HEAD 0.1.234 + A4 ; `--refonte --hubvalue --decote --mult=0.85,1.3,2.3,4.4 --plans=boss`, 12 comptes « moyen »,
guerrier, 50 h, graines 1 et 2. Le coffre a son propre générateur (les autres tirages restent ceux de la série sans).
Modèle : à chaque carte finie (boss vaincu), 3 pièces non découvertes au hasard, le joueur prend celle qui vaut le plus (PE).

| Jalon (médiane, h) | sans, graine 1 | avec, graine 1 | sans, graine 2 | avec, graine 2 |
|---|---|---|---|---|
| époque I | 2,6 | 2,5 | 2,7 | 2,5 |
| époque IV | 25,1 | 26,5 | 28,0 | 28,4 |
| 1er donjon | 3,0 | 3,1 | 3,1 | 2,9 |
| **équipement 80-90 correct** (`kit80_ok`) | 31,8 (75 %) | **31,1 (83 %)** | 39,8 (58 %) | **31,7 (75 %)** |

Lecture : sans le coffre, l'équipement 80-90 correct arrive vers **≈ 32-40 h** (≈ 36 h en moyenne, proche des ≈ 37 h du document) ;
avec, vers **≈ 31-32 h** (cible ≈ 30 h) et pour plus de comptes à 50 h (67 % → 79 %). L'effet tient surtout aux comptes malchanceux
(graine 2 : −8 h) : le plan visé comble le trou d'emplacement que les 6 découvertes au hasard par carte laissaient. Époque I inchangée.
Bruit de ± 3 h entre graines (12 comptes) : à confirmer au journal réel. A6 (décote réelle dans `Items`) reste à faire ; `--decote`
de l'outil devra alors être retiré.

## Tests
`test_a4` (nouveau : 3 choix non découverts et différents sur 40 tirages, ni trophée ni arme d'un autre type, plan acquis au choix,
pilote sans écran ouvert, aucun doublon entre cartes, tout découvert → +30, défaite à la carte suivante : plans gardés y compris dans
la sauvegarde relue, lignes du bilan, somme des insignes). Verts sur la copie propre : `test_gear_run`, `test_p4_flow`, `test_results`,
`test_nav_screens`, `test_cards`, `test_e5`, `test_e6`, `test_n2`, `test_texts_fr`.

## Pièges
- `run.gd` est aussi modifié par d'autres lots (H2) : commit construit depuis HEAD par remplacements de texte.
- Une copie de travail est restée dans `C:\c\Users\Nico\AppData\Local\Temp\claude\…\scratchpad\a4snap` (chemin `/c/...` mal
  converti par `run_tests.preparer_copie` sous Git Bash : passer un chemin Windows) ; la suppression a été refusée par l'outil :
  à effacer à la main.
