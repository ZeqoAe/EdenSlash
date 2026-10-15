# R_M3 — La Tour : types d'étage, élites, ombres, boss de la bibliothèque (passe M3)

Retour du joueur : « les petites vagues de monstres étaient ennuyeuses : des élites au minimum à chaque étage, des étages avec des
boss, des étages avec des "ombres" (une IA qui joue une classe) ». Règles : `DESIGN.md`, « La Tour : types d'étage ».
Test : `tests/test_m3.tscn` ; captures : `tests/shot_m3.tscn` (`user://shots/m3_*.png`, non commitées) ; mesures :
`tools/tower_run.tscn -- --from=N --floors=K --diff=D --class=C --hub=E.C.N.G [--god]` (pilote « Bot », ligne par étage).

## Fait
- **Plan par bloc de 10 étages** (`Tower.block_plan`, graine fixe) : 9 = halte, 10 = boss ; bloc 1 = duellistes 1 / 4 / 7 (fil
  d'éveil inchangé : `duelists_beaten` vaut 2 à l'étage 4, 3 à l'étage 7), élites au 5 ; ensuite 2 ombres, 1 étage d'élites,
  1 maudit (dès l'étage 21), le reste en monstres. 200 étages : 81 monstres, 20 élites, 18 maudits, 38 ombres, 3 duellistes,
  20 haltes, 20 boss. Types déterministes (vérifié par `test_m3`), modifiables étage par étage dans le mode dev (page Tour).
- **Monstres** : 3-4 espèces par étage, rôles différents (`Tower.floor_species`, rôles de P15 : `SpawnDirector.role_of` / `apply_role`),
  groupes mélangés du même côté ; **une élite au moins à chaque étage** avec une mécanique propre (11 briques de `BossBricks` sans
  invocation : cerveau `BossBrain` posé sur l'élite, coups plafonnés à 25 %, nom « Espèce · Mécanique », escorte, lancers décalés
  de 3,5 s entre élites). Étages d'élites : 3 + 1 tous les 50. Maudits : Menace / Rage / Horde, coffre rare au moins, cristaux.
- **Ombres** : `ClassRival` (moteur des duellistes) ; une sur 4 = **ton ombre** (ta classe, ton préréglage, ton équipement) ;
  **ombre éveillée** (Hardcore ≥ 100, Difficile ≥ 150, une sur deux) = `Player` piloté par `MlDuelPilot` avec le cerveau figé du
  Panthéon (repli scripté si absent) ; IA plus dure aux étages 80 / 150 ; lisible : nom « Ombre · Mage », barre « Adversaire »,
  coups annoncés, aide « Assisté » (`Player._tower_duel` couvre les ombres).
- **Boss** : `BossLibrary.spawn` (bibliothèque M2), boss de la zone de l'étage sans répétition, gardien de zone en dernier
  (20 boss, 20 différents dans l'ordre : rockfist, mori, buster, strawman, angela… wushu) ; PV fixes `boss_hp_fixed`, palier 0-2.
- **Halte** : 60 % des PV, carte, coffre. **HUD** : horloge « Étage 12/200 · Ombre » (`TowerDirector.clock_text`, le Siège
  garde la sienne), objectif par type (élites restantes, « Bats Ombre · Voleur », « Monte à l'étage 13 · Élites »), bannière
  d'entrée. **Page Tour** : icône du type par étage, légende (infobulle : ce que le type donne), « Reprendre » dit ce qui attend,
  fiche (mécaniques des élites, espèces, malédiction, mécaniques du boss, ombre, récompense du type). **Bilan** : héros battus,
  boss vaincus, cristaux des étages maudits.
- `TowerDirector` : interface documentée en tête (champs, fonctions à surcharger, outils) pour M6 ; les ajouts ne touchent que la
  Tour (`not Tower.is_dungeon()`), Donjons / Ruée / Siège inchangés.

## Mesures (pilote, `--human 0.5`, coups jamais esquivés ; un joueur est ≈ 2 à 3 fois plus lent qu'un pilote)
Réglage final (rôles de P15, PV rendus en montant 50 %, dégâts × courbe^0,6), 9 étages par run :

| Étages (classe, hub attendu) | Issue | Monstres | Élites | Maudit | Ombre / duelliste | Subis / min |
|---|---|---|---|---|---|---|
| Avant M3 : 1-9 (guerrier, mage, 1.3.5.1) | 9 / 9 | 13-24 s | 9-24 s (1 élite / 5 ét.) | — | duel 7-9 s | ≈ 0,1 |
| 1-9 guerrier (1.3.5.1) | 9 / 9 | 32-45 s | 38 s | — | duel 16-18 s | 0,44 |
| 1-9 clerc (1.3.5.1) | 9 / 9 | 39-52 s | 62 s | — | duel 14-18 s | 0,61 |
| 21-29 mage (1.3.5.1) | mort au 25 (maudit, Horde) | 23-36 s | — | — | 18 s | 1,21 |
| 61-69 mage (2.3.10.3) | mort au 64 (maudit, Menace) | 32-37 s | — | — | 8 s | 1,08 |
| 101-109 chasseur (3.3.10.4) | 9 / 9 | 31-37 s | 35 s | 31 s | 9-41 s | 0,74 |
| 141-149 guerrier (4.3.10.4) | 9 / 9 | 22-24 s | 18 s | 23 s | 4-62 s | 0,04 |

Essais intermédiaires : dégâts × courbe^1 et soin 35 % : le pilote mourait aux étages 6, 23 et 101 (usure : un étage coûtait
0,4 à 0,9 PV max pour 0,45 rendus) ; dégâts × courbe^0,3 : 0 dégât subi à partir de l'étage 100 avec l'équipement attendu.

Boss (`--god`, temps pour tuer du pilote) : courbe `BOSS_CURVE` puis 3 étages corrigés (`BOSS_FLOOR_ADJ`) : 10 : 85 s ; 20 : 50 s ;
30 : 85 s ; 40 : 52 s ; 50 : 55 s ; 70 : 83-104 s ; 90 : 99 s ; 100 (gardien, totems cassés après 8 s) : 96 s ; 130 : 62-115 s ;
140 : 63 s ; 160 : 35 s ; 190 : 89-140 s ; 200 (Wushu : le pilote frappe les illusions) : 24 s mage, > 8 min guerrier.
Avant la courbe : 4-14 s dès l'étage 70 (un boss de donjon Normal face à un équipement des époques III-IV).
Ombre éveillée (Hardcore, étage 103, 4.3.10.4) : 26-35 s (mage, chasseur, guerrier invincible) ; le guerrier qui esquive ne la
rattrape pas (83 % après 400 s : le pilote au corps à corps contre un héros qui recule et se soigne).

## Décisions
- **Ombre éveillée sans build « opti »** : hors des règles du duel, sa défense d'équipement complet absorbait 99,9 % des coups
  (46 dégâts sur 36 000) ; elle porte l'équipement de l'ombre scriptée et ses PV / dégâts (× 0,5 PV, soins − 50 %).
- **Courbe des boss par étage** plutôt qu'un multiplicateur unique : l'écart d'équipement entre époques (×5 à ×12 sur le temps pour
  tuer) dépasse la croissance par niveau des PV fixes de P11. Monstres et ombres suivent (PV × √courbe, dégâts × courbe^0,6).
- PV rendus en montant : 35 % → 50 % (plus 10 % à l'étage vidé) : les étages plus longs usaient le héros jusqu'à la mort.
- Halte juste avant le boss (et soin complet après lui, comme avant) ; ombres jamais côte à côte ; maudit à partir de l'étage 21.
- Composant d'apparition de P15 (`SpawnDirector`, poussé pendant la passe) : la Tour garde son propre mélange par étage
  (`floor_species`, déterministe, montré par la fiche) mais en prend les rôles et leurs stats (`role_of`, `apply_role`) ; ses
  escouades / événements restent à la Survie (une salle fermée de la Tour n'a ni secteurs ni anneau hors écran).

## Reste / pièges
- Écart de classes : à l'étage 141 un guerrier en 4.3.10.4 vide tout en 20 s sans dégâts ; un chasseur en 3.3.10.4 à l'étage 101
  encaisse 2 à 7 fois ses PV par étage. Le journal de run (mode « tower ») devra trancher la courbe des étages hauts.
- Hardcore à l'étage 101 : le pilote meurt en 25 s (élites ×1,6, il n'esquive pas) ; à confirmer avec un joueur.
- Étages maudits : le pilote mage (qui n'esquive pas) y meurt (Horde au 25, Menace au 64) ; si un joueur s'y casse aussi les dents,
  baisser `CURSE_HP` / `CURSE_HORDE` ou rendre l'étage maudit facultatif (escalier de contournement).
- Wushu (étage 200) et les boss à illusions restent longs pour un pilote au corps à corps.
- Fichiers d'autres lots retouchés : `ui/hud.gd` (une ligne : horloge par `clock_text`), `ui/lobby.gd` (icône de type, légende,
  ligne « Reprendre »). Le dossier partagé ne compilait pas (classe `TeamBars` de M7 avant son envoi) : tests et mesures sur une
  copie HEAD + mes fichiers (`tools/run_tests.py --snap`), commit de mes seuls morceaux.
