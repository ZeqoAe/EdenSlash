# R_E1 — matières et cristaux des activités (lot E1, version 0.1.165)

Lots A4 + A1(a) + A2 de `A1_progression.md` (problèmes I1-I4, I14, compteur 154). Test : `tests/test_loot.tscn`.

## Fait

- **Nouveau `core/activity_loot.gd`** (`ActivityLoot`) : une seule table pour les cristaux et les coffres de matières de
  chaque activité hors Survie. Les coffres sont créés au niveau de l'activité, donc ses parchemins de fortification ont
  le niveau de la pièce (Lv 20 à 100) et ses formules vont jusqu'au niveau 9.
- **Spécialité de coffre** (`focus`, `Rewards.make(type, lv, boss, focus)`, `Rewards.open` et `preview` à jour) :
  `scroll` (forge : 2-3 puissance + 2-4 garde), `stone` (forge : 1+1 parchemins, 2 sûreté, 1 chanceuse, 4 pierres rares,
  pas de ciseaux), `gem` (joaillier : 3 gemmes d'un rang de plus + 1 formule), `enchant` (joaillier : 3 formules au
  niveau le plus haut + 1 gemme d'un rang de moins). Sans `focus`, contenu inchangé.
- **Butins** : Donjons (`Dungeons.reward`), Ruée (`rush_reward`), Siège (`Siege.settle`), Tour (`Tower.finish`, le
  bilan renvoie `crystals` et `chests`). Les bilans (`dungeon_results.gd`, `tower_results.gd`) affichent les nouveaux
  coffres (« Coffre de forge ×2 ») : retouche minimale, la refonte reste au lot U9.
- **Compteur d'Armurerie** : `Completion.armory_total()` calculé sur les tirages réels de `SlotChests.pool` (toutes
  époques, cartes, emplacements et types d'arme). **Résultat : 1 731 pièces** (et non 154) : 796 armes, 530 pièces
  d'armure, 132 bijoux. `armory_done()` ne compte plus les trophées de `seen_gear`.
- **Coffre « trophée » retiré** (I14) : `TYPES`, `ORDER`, `offer`, `preview`, `is_choice`. Une ancienne sauvegarde
  les voit devenir des coffres de set (`Rewards.migrate`, appelé dans `profile.gd` au chargement).

## Table cible / obtenue

Coût d'une pièce de +0 à +10 en cristaux (`Forge.GOLD_PER_CRYSTAL` 25 → **125**), chaque tentative réussie, puis avec échecs
(simulation : perte d'un niveau dès +6 sans protection ≈ ×7, avec une pierre de chance de +6 à +10 ≈ ×1,75) :

| Niveau de la pièce | Avant (25 or) | Maintenant, 1res réussites | Avec pierres de protection | Clears Mythiques (donjon 170, Siège 200, Ruée 272) |
|---|---|---|---|---|
| 20 | 1 041 | 213 | 364 | 1,3 / 1,1 / 0,8 |
| 40 | 1 874 | 379 | 656 | 2,2 / 1,9 / 1,4 |
| 60 | 2 707 | 546 | 948 | 3,2 / 2,7 / 2,0 |
| 85 | 3 748 | **755** | 1 312 | **4,4 / 3,8 / 2,8** (≈ 6-7 avec les pierres) |
| 90 | 3 956 | 796 | 1 385 | 4,7 / 4,0 / 2,9 |

Cristaux par clear (Normal / Héroïque / Mythique) : Donjon 30 / 90 / 170 (avant 20 / 40 / 60) ; Siège 30 / 90 / 200
(avant 100 / 200 / 300, trop haut pour la difficulté de l'activité) ; Ruée complète 64 / 144 / 272 (avant 120 / 240 / 360) ;
Tour 1 à 2,5 par étage monté (Facile à Hardcore ; avant 0) : 100 étages en Normal = 150. Un donjon Normal (30)
paie un +3 sur une pièce de niveau 30 (≈ 18 cristaux, test à l'appui). Démontage : 1 à 3 (avant 1 à 8) ; coffre de forge :
2-3 cristaux au niveau 30 (avant 6-9) — un cristal vaut 5 fois plus d'or, ces sources restent un complément.

Coffres de matières (niveau de l'activité) :

| Activité | Rôle | Coffres |
|---|---|---|
| Donjon | matières moyennes | Normal : forge ×1 (Lv 20-60) ; Héroïque : + joaillier (Lv 30-80) ; Mythique : forge ×2 + joaillier (Lv 90) |
| Ruée | haut niveau | 4 boss : forge ×1 ; 8 boss : parchemins (×1 Normal, ×2 sinon), pierres rares, gemmes ; niveau du dernier boss 60 / 75 / 90 |
| Siège | formules hautes | boss tombé : formules ×1 / 2 / 3 (jusqu'au niveau 9), + forge en Héroïque et Mythique |
| Tour | cristaux + gemmes | gemmes tous les 10 étages, forge tous les 50 (Lv 100 possible aux étages hauts, pour les pièces de niveau 91-100) |

Un clear Mythique de donjon donne ≈ 4 parchemins de garde Lv 90 ; une pièce à +10 en consomme une douzaine : les
parchemins limitent autant que les cristaux (4 à 5 clears aussi).

## Décisions

- Parchemins plutôt qu'or : je n'ai pas touché `Items.upgrade_cost` (l'or en Survie reste identique) ; seul le taux
  hors run change.
- Siège abaissé (300 → 200 cristaux Mythique) : l'audit visait un clear Mythique ≈ 150-200.
- Tour : un coffre de forge tous les 50 étages (non demandé) pour qu'elle donne des parchemins Lv 100.
- Armurerie : total 1 731 ; sur la page du Carnet la barre « Équipement » sera donc très basse au début (honnête ;
  U7 peut afficher « pièces découvertes » sans barre).

## Reste / pièges

- `test_nav_screens` : 1 échec (« cadre doré caché tant qu'aucune croix n'a bougé ») dû aux modifications d'`ui_nav.gd`
  d'une autre session, pas à ce lot. `carnet_pages.gd` d'une autre session n'a pas compilé un moment (ligne 352).
- La fusion de gemmes hors run coûte maintenant 1 à 2 cristaux (avant 2 à 7) : `Forge.price(fuse_cost)` arrondit ; à
  recaler avec le lot U5 (`merchant_pages.gd`, pas touché).
- Le menu Coffres (`chests_page.gd`, lot U3) montre le même nom « Coffre de forge » pour tous les `focus` : l'aperçu
  diffère, un libellé par spécialité reste à faire.
- Les fournitures de la Survie restent plafonnées au niveau 35 (lot E4 / N1, `run_director.gd` non touché).
- Version : 0.1.165 (0.1.164 est celle de N1, non poussée au moment du commit).
- Fichiers d'autres lots touchés : `profile.gd` (1 ligne : `Rewards.migrate` au chargement), `ui/dungeon_results.gd` et
  `ui/tower_results.gd` (affichage des coffres).
