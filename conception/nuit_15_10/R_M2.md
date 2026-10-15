# R_M2 — Bibliothèque de boss et donjons à la carte (passe M2)

Règles de jeu : `DESIGN.md`, « Bibliothèque de boss et donjons à la carte ». Test : `tests/test_m2.tscn` (tous les boss) ;
captures : `tests/shot_m2.tscn` (`user://shots/m2_*.png`, copies dans `captures/m2/`, non commitées) ; mesures :
`tools/boss_ttk.tscn -- --mode=dungeon --boss=<id>` (TTK) et `tools/dungeon_run.tscn` (donjon complet au pilote).

## 1. Inventaire de l'existant
- 8 boss de zone (`zones.json -> dungeon` : Mori, Angela, Ulicul, Double-porte, Meunier, Abby, Pross + Expérience 627,
  Wushu + Jiku), un par donjon, la Survie et la Ruée. Mécaniques codées en dur dans `BossBrain` (10 noms : adds, puddles,
  meteors, stomp, clones, totems, lasers, pet, vortex, reflect) + 5 attaques de base (écrasements, charge, balayage, salve, onde).
- Géants (P12, `GiantMonster`), duellistes (`ClassRival`) et cerveaux : hors bibliothèque (exclus par la consigne).
- 101 élites nommées d'Eden (rang 3) avec modèle, jamais boss : réservoir de la bibliothèque.

## 2. Ce qui est fait
- **`ai/boss_bricks.gd`** : 29 briques, 10 familles (tableau `BossBricks.DEFS` : famille, nom, conseil, sorte, rythme,
  paramètres). Zones au sol : puddles, meteors, lasers, grid (damier), sweep (lignes successives). Invocations : adds, pet,
  clones, swarm (nuée périodique), turrets (tourelles immobiles qui tirent un orbe annoncé). Fureur : enrage (30 %), frenzy
  (impatience : +12 % de dégâts toutes les 30 s après 2 min, 6 crans). Boucliers : totems, barrier (absorbe 12 % des PV, brisée
  = boss sonné 3 s, sinon il se soigne de 8 % + onde), crystals (3 cristaux qui le soignent 20 s au plus). Charges : rampage
  (3 charges), leap. Projectiles : spiral, ring_burst, fan (orbes lents, `Projectile.speed`). Arène : shrink (mur rouge qui se
  resserre de 21 à 9 m puis s'ouvre). Placement : safe_zone (cercle vert sûr, le reste explose), vortex, gale (bourrasque qui
  repousse, bord extérieur qui explose), gaze (cône de 220° : passer dans son dos), marks (marque qui suit puis se fige),
  blink. Riposte : reflect. Ondes : stomp.
- **`BossBrain`** : ordonnanceur générique (seuils, périodiques × 0,7 en 2e phase × rythme `pace`, briques de départ et
  autonomes), barrière (via `health_changed`, sans toucher `Monster`), chancellement, plafond d'un coup `hit_cap`, jeu d'attaques
  de base `kit`. Les mécaniques d'avant passent par `BossBricks.from_legacy` avec leurs paramètres d'origine : **Survie inchangée**.
- **`core/boss_library.gd` + `data/bosses.json`** : 48 boss (6 par zone : le boss d'origine + 5 élites promues), 2 à 4 briques,
  `hp` (0,88 à 1 : moins de PV aux boss à bouclier / invocations), panoplie + 2 emplacements. Chaque panoplie couvre les
  9 emplacements sur ses 6 donjons ; chaque brique sert au moins une fois.
- **Donjons à la carte** (`Dungeons.catalog/slot_pieces/lieutenant_of`, `Tower.dungeon_boss`, `TowerDirector._spawn_boss` et
  `_spawn_lieutenant`) : un donjon par boss ; salle 3 = lieutenant (boss suivant de la zone, une mécanique, 25 % des PV) ;
  coffre de set = 3 pièces des 2 emplacements à la panoplie du boss (mythique / légendaire selon la PE, éveillée 1 fois sur 4
  en Mythique pour l'armure) ; record par boss ; « Rejouer » relance le même boss. Salles plus peuplées (44 + 6 × difficulté
  monstres, PV × 3,5, 5 + difficulté élites).
- **Page Donjons** (`ui/dungeon_page.gd`, appelée par `lobby._menu_dungeon`) : donjon choisi (boss, mécaniques, pièces,
  victoires), difficulté et jauge de PE, filtres pièce / panoplie / mécanique, liste à deux colonnes, alliés, bouton épinglé.

## 3. API pour la Tour, la Ruée, le Siège, la Survie, le Survivant
```gdscript
var m := BossLibrary.spawn("latif", tier, {"director": run_director, "pos": centre, "level": niveau,
	"hp": pv_imposes,          # facultatif (sinon BossLibrary.hp(id, niveau, tier) = Dungeons.boss_hp × hp du boss)
	"hp_mult": 1.0, "atk_mult": 1.0,
	"main": true,              # devient run_director._boss (barre du HUD, cible des invocations)
	"lieutenant": false})      # mini-boss : une mécanique sans invocation, 25 % des PV
```
`spawn` passe par `RunDirector._spawn_monster` (Menace, mode, géant compris), branche les annonces (`director.message`),
le miroir et la fureur. Autres : `ids()`, `get_def(id)`, `for_zone(zid)`, `zone_boss(zid)` (boss d'origine), `full_name`,
`short_name`, `intro`, `bricks_of(id, tier)`, `brick_types`, `families_of`, `mechanic_names`, `loot(id)`, `hp(id, lvl, tier, rush)`.
Une brique de plus : une entrée de `BossBricks.DEFS` + une fonction + une ligne de `BossBricks.run` ; un boss de plus : une
entrée de `data/bosses.json` (le test M2 la vérifie seul). La Ruée peut prendre `for_zone(z)` au hasard, le Siège `zone_boss`.

## 4. Mesures (aide « Bot », équipement attendu de P11 : Normal `2.1.5.2`, Héroïque `3.3.10.4`, Mythique `4.3.10.4`)
TTK du boss (héros invincible ; guerrier / mage / chasseur), et avec `--human 0.5` (le pilote n'esquive jamais) :

| Boss (Normal) | TTK | `--human 0.5` : issue, PV max perdus / min, plus gros coup |
|---|---|---|
| Ulicul, Mori, Double-porte (zone, référence) | 45 s – 2:44 | mort 3/3 chacun, 0,7 – 3,9 / min, 3-4 % |
| Latif, Kozbane, Lanka, Halsey, Gilbert | 46 s – 2:39 | mort 2-3/3, 0,6 – 1,7 / min, 2-5 % |
| Argus, Lalo, Alonzo, Steck, B.B., Tucker | 46 s – 2:50 | tué 1-2/3, 0,3 – 1,2 / min, 1-3 % |
| Belmont (cristaux), avant correctif | 2:25 / >8 min | les cristaux soignaient 1,2 %/s sans fin |

Héroïque / Mythique (Belmont, Sapo, Galapagos, Mori, Latif, Tucker) : 22 s – 4:55, médiane ≈ 1:50 ; plus gros coup
≤ 34 % (renforts compris ; le plafond des boss est 40 %). Les nouveaux boss ne sont pas plus durs que ceux de zone ; plusieurs
sont battus par le pilote qui n'esquive pas.

Donjon complet au pilote (`tools/dungeon_run`, coups évités 0,85, temps de jeu ; 6 boss × 3 classes en Normal, 3 en Mythique) :

| Réglage des salles | Salles 1-3 | Boss | Donjon fini | Morts du pilote |
|---|---|---|---|---|
| Avant (14 + 4 × diff monstres, PV × 1,8) | 50 – 150 s | 1:20 – 2:25 | 2:15 – 3:35 | 7 / 15 (au boss) |
| 50 + 8 × diff, PV × 4 | 95 – 220 s | 1:00 – 2:40 | 2:50 – 4:20 | 11 / 15 (salles 2-3) |
| **Retenu** : 44 + 6 × diff (+8 salle 3), PV × 3,5 | 70 – 230 s | 1:05 – 2:45 | **2:15 – 6:05** (médiane ≈ 4 min) | 9 / 17 |
| Mythique (sur-équipé 4.3.10.4) | 60 s | 1:10 – 1:40 | 2:10 – 2:45 | Latif 1/2, Steck : totems jamais cassés par le pilote |

Écart avec la cible (8 – 15 min) : le pilote « Bot » vide une salle 2 à 3 fois plus vite qu'un joueur (visée parfaite, sorts
toujours prêts) et ne compte ni les choix de carte ni la lecture des mécaniques ; plus de monstres ou de PV tuaient le pilote
dans les salles sans l'allonger beaucoup. Estimation joueur : 6 – 10 min. À confirmer au journal (`run_journal`, mode « dungeon »)
avant de toucher `Dungeons.room_monsters` / `MONSTER_HP`.

## 5. Décisions
- Lieutenant plutôt qu'une salle de boss en plus : « salles mixtes » sans allonger d'une salle ; une seule mécanique, pas
  d'invocation (elles demandent le boss principal).
- 2 emplacements par donjon (8 donjons par emplacement) : assez de choix sans diluer ; les boss de zone gardent torse + jambes.
- Le Siège garde son boss de zone (`Tower.start_siege` remet `dungeon_boss` à "") ; la Ruée et la Tour aussi : à l'agent suivant.
- Cristaux : soin plafonné à 20 s (la sonde ne les vise pas ; un joueur oui) ; la sonde `boss_ttk` les casse après 8 s.
- Durée : le pilote vide les salles bien plus vite qu'un joueur ; doubler encore monstres et PV tuait le pilote dans les salles.

## 6. Reste / pièges
- `Monster.kind_override` n'existait pas en HEAD (travail P15) : les tourelles tirent par la brique, pas par le monstre.
- Un `await` dans une brique doit revérifier le boss (`BossBricks._alive`, non typé : un cerveau libéré plante un argument typé).
- Le dossier temporaire du travail est partagé avec d'autres sous-agents : une copie de test « snap » commune a été remise à
  zéro sous mes pieds ; prendre un nom propre.
- Pas encore : Tour / Ruée / Siège / Survie / Survivant sur la bibliothèque ; signatures visuelles propres à chaque brique
  (effets d'Eden) ; filtre « boss » nominatif (la liste montre les noms au survol).
