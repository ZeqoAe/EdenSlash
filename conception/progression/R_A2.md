# R_A2 — Donjons plus tôt, sans remplissage (refonte Aventure, lot A2, 16/10/2026)

Lot A2 de `REFONTE_AVENTURE.md` §5 (inchangé par `NIVEAU_HEROS.md` §4.2). Fichiers : `core/unlocks.gd`, `core/dungeons.gd`,
`core/tower_director.gd` (édits ciblés), `ui/dungeon_page.gd`, `ui/difficulty_panel.gd` (paramètre optionnel), `tools/dungeon_run.gd` ;
retouches d'une ligne : `ui/activities.gd`, `ui/lobby.gd` (Ruée), `core/quest_pool.gd` (quêtes de la Ruée), `core/compass.gd`
(échelons), `core/boss_library.gd` (commentaire). Tests : `test_a2` (nouveau), `test_lot13`, `test_lot13b`, `test_m2` mis à jour.

## Fait
- **Ouverture** : `Unlocks` « dungeons » = **époque I gagnée** (avant : II), texte « Gagne l'époque I (boss de la 3e carte). » ;
  chaque donjon s'ouvre ensuite **zone par zone** (boss de la zone battu, ou zone d'une époque gagnée : Monts Calcaires,
  Forêt des Chutes arc-en-ciel et Baie du Béluga d'office). Jamais de reverrouillage : la liste `Profile.unlocked_features` garde tout.
- **La Ruée et le Siège gardent l'époque II** : la Ruée avait le verrou des Donjons ; elle a maintenant le sien (entrée `rush`,
  « Gagne l'époque II. », page, bouton, quêtes `rs_*`), ouvert aussi si une Ruée a déjà été jouée ; le Siège ne dépend plus de
  `test("dungeons")`. Un ancien compte (époque II gagnée) garde Donjons, Ruée et Siège ouverts.
- **Plus de salle de monstres seuls** : `Dungeons.ROOMS` = élites, lieutenant, boss (avant : monstres, élites, monstres + lieutenant,
  boss ; 44-56 monstres × PV 3,5 par salle). Salle 1 : **élites à mécanique une à la fois** (3 / 4 / 5 selon la difficulté), chacune
  une brique de `Tower.ELITE_BRICKS` tirée par donjon (jamais deux fois la même), 2 monstres d'escorte, la suivante entre quand
  elle tombe ; objectif « Salle 1 · Élite 2 / 3 ». Salle 2 : le **lieutenant seul** (« Vaincs X, lieutenant »). Salle 3 : le boss.
- **PE conseillée visible** : la page Donjons prend le bloc de la Ruée et du Siège (`DifficultyPanel`) : PE conseillée (Normal) ou
  requise, estimation (Facile → Hors de portée), récompenses (cristaux, 3 pièces, « son plan de donjon » tant qu'il manque), et en
  Normal « Trop faible ici : essaie d'abord une zone plus basse. ». `Dungeons.ADVISED` 1,3 / 3,8 / 3,3 (jamais sous la requise).
- Boussole : « Gagne l'époque I : Forge, Tour et Donjons s'ouvrent », « Gagne l'époque II : le Siège et la Ruée s'ouvrent ».
- `tools/dungeon_run` : `--god=1` (héros invincible : durée pure), victoire lue sur le dernier étage du donjon (et non plus « 4 »).

## Mesures (pilote « Bot », `tools/dungeon_run --human=0.85`, 60 images / s ; hub = équipement de la zone)
Réglage retenu : élites PV × `ELITE_ROOM_HP` 2 (en plus d'`ELITE_HP` 4), lieutenant × `LIEUTENANT_HP` 3 (sur 25 % du boss).

| Normal, invincible, 14 donjons (6 zones, 6 classes, hub 1.1.3 à 2.2.5.2) | Salle 1 | Salle 2 | Boss | Donjon |
|---|---|---|---|---|
| médiane (min – max) | 2:24 (0:54 – 4:21) | 1:14 (0:43 – 1:47) | 1:58 (0:38 – 3:09) | **5:48 (3:17 – 8:31)** |

- Avant de régler : élites ensemble × 3 → pilote mort dans la salle 1 en 15-30 s ; élites une à une × 3 → salle 1 ≈ 4:30, donjon ≈ 8 min ;
  × 1,5 et lieutenant × 2,5 → médiane 5:10 (un peu court). Retenu : 2 / 3.
- Pilote mortel (`--human=0.85`, 6 donjons) : 3 victoires (4:40, 7:55, 11:10), 3 morts (1 en salle 1, 2 au boss) ; R_M2 : 9 morts / 17.
- Héroïque (hub 3.3.10.4) et Mythique (4.3.10.4), invincible, 8 donjons : 3:45 – 9:16, médiane ≈ 4:45.
- `test_a2` borne la durée par les PV : élites ≈ 1,4 boss, lieutenant ≈ 0,7, donjon entier 2,6 à 3,6 boss (mesuré 3,1).

## Verrous de PE (vérifiés, inchangés)
PE requise (`progression_sim --gates`) : Héroïque de la 1re zone 25 272, Mythique 55 800. Un kit de l'époque I à +10 et gemmes
(1.3.10.3) fait 15 775 : l'ouverture plus tôt ne touche que le Normal ; l'Héroïque reste un palier de fin d'époque II (2.3.10.3 :
28 683), comme le modèle A7 (1er Héroïque ≈ 14,7 h). PE conseillée en Normal : Monts Calcaires 5 616 (kit I-1 +0 : 5 522,
« Équilibré »), Béluga 10 530 (« Hors de portée » avec le kit I-1, « Équilibré » avec I-3 +5 : 11 983, que le pilote bat).

## Reste / pièges
- Le pilote ne casse jamais les totems (Double-porte : boss à 13 min) et l'archer du pilote est 2 × plus lent : écartés des médianes
  (limite du pilote, déjà notée en R_M2). Un joueur sera plus lent que le pilote (R_M2 : × 1,5 à 2) : à confirmer au journal.
- Cristaux : 30 par donjon Normal de ≈ 6 min (avant ≈ 10 min) : ≈ 200-300 / h ; à surveiller avec le journal (pas de retouche).
