# R_H4a — l'Aventure au niveau de héros, par bandes de niveau (lot H4a de `NIVEAU_HEROS.md`)

Le mot « Survie » reste dans les textes (renommage : lot A9).

## Fait (moteur, 0.1.245)

| Sujet | Règle | Où |
|---|---|---|
| Deux niveaux | `Run.hero_level` = niveau de héros, **fixé au départ** de la partie (`Run.start_survival` ; l'XP de héros n'est versée qu'au bilan) : stats de base (`Player.stat_level`), puissance des pièces (`Items.power_level` = min(niveau de héros, niveau de la pièce), jusqu'à 90), gemmes (`Craft.gem_run_factor`). `Player.level` = **niveau de run** : repart de 1, sans plafond par carte, ne donne que des cartes (or et prix de la partie le suivent comme avant). HUD : l'orbe dit « RUN », infobulle « Ton héros se bat au niveau N ». | `run.gd`, `player.gd`, `hud.gd` |
| XP de run | Un monstre rapporte ce que vaut un monstre **du niveau de run** (élite ×4, boss ×8, géant…), quel que soit son niveau de carte : le besoin reste `KILLS_PER_LEVEL` + 2,5 × niveau, en monstres. | `run_director.gd` (`_spawn_monster`) |
| Bandes | `Epochs.BANDS` (I-1 1-23 … IV-3 80-90, table du §1.4) ; monstres au niveau de héros + décalage (−1 → −0,5) **borné par la bande**, + palier du camp, +3 en rage ; boss = niveau de la carte pour le héros + 1 (`RunDirector._boss_level`, `card_level`) ; `max_level` = haut de la bande. | `epochs.gd`, `run_director.gd` |
| Force | PV × `Epochs.MAP_MULT` (M′), dégâts × `MAP_ATK` (monstres) / `BOSS_ATK` (boss), × montée dans le temps `time_ramp` (`TIME_RAMP` 2 % par minute, au plus ×2 ; pas le boss). **Défense des monstres plafonnée** à celle du niveau `DEF_LEVEL` 18 / 28 / 38 de la carte (voir Mesures). | `epochs.gd`, `run_director.gd` |
| Boss | `Epochs.boss_hp(époque, carte, niveau)` = `BOSS_HP_MAP` × `BOSS_HP_EPOCH` × `BOSS_HP_ADJ` × M′ / ancien multiplicateur × 1,1^(niveau − ancien plafond − 1) : PV fixes au niveau du boss (jamais la PE ni le niveau de run). Compte neuf sur I-1 : boss niveau 2. | `epochs.gd` |
| Supprimés | `Epochs.CAPS`, `LEVEL_BONUS`, `MONSTER_MULT`, `cap()`, `level_bonus()`, `monster_mult()` ; gardés **sans effet** pour les outils : `OLD_CAPS`, `OLD_MONSTER_MULT` (`old_cap`, `old_monster_mult` : modèle par défaut de `progression_sim`, `hl_probe`, référence des PV de boss). Décote A6 : jamais codée, rien à retirer. | `epochs.gd`, `tools/progression_sim.gd` |
| Coffres de la partie | `SlotChests.run_piece` : en Aventure, une pièce n'est **jamais au-dessus du niveau de héros** : sous le palier de la carte, la pièce du palier est ramenée au niveau du héros (même modèle, `from_level` garde le palier ; la vraie pièce reste à l'Armurerie). Coffres d'emplacement, trophées, arme secondaire, arme de départ. Titre du coffre : « niveau 12 · mythique » (`Epochs.map_text`). Plans des boss (A4) : la pièce à son vrai niveau. Butin des autels et coffres de récompense ≤ min(niveau de la carte, niveau de héros) (`loot_level`). Rang des gemmes : l'échelle d'avant (`Epochs.GEM_SCALE` selon la place du héros dans la bande). | `slot_chests.gd`, `run.gd`, `run_director.gd` |
| Port en partie | `HeroLevel.wear_block` n'exempte plus la partie (`Profile.in_run` retiré) ; en Aventure il compare à `Run.hero_level` (`wear_level`). Compte neuf : pièces de départ (exemptées) et pièces des coffres (au niveau 1) se portent. | `hero_level.gd` |
| Interface | Page de la Survie : sous l'époque choisie, ses 3 cartes : zone, « Niv. 1-23 », « PE conseillée 1 307 » colorée selon la PE du héros (`DifficultyPanel.verdict`), détail en infobulle (`Epochs.advised_power` : PE des pièces de la carte à +5 au niveau de la carte, l'équipement de départ pour I-1, `ADVISED_RATIO`). Capture 1280 × 720 regardée (compte neuf et avancé). | `lobby.gd` (`_survival_maps`) |
| Mesures | `world.tscn -- --hero-level=N --stage=N --start-run=N --mult-scale= --atk-scale= --boss-scale=` ; `sim_survie.py --hero-level --stage --extra=…` ; `boss_ttk.gd --level` = niveau de héros, scénarios `bande` / `bande-10` de `boss_ttk.py`, lignes « morts, subis, coup max » avec `--human`. | `world.gd`, `tools/` |

Autres modes : `Epochs.adventure()` (= `Run.survival` sans Survivant ni Battle royale) garde tout le reste tel quel : Survivant
(plafond par palier, courbe par minute), Battle royale (plafonds d'anneau), Tour, Donjons, Ruée, Siège (`Run.survival` faux, niveaux de
l'activité), Duel. Défi du jour : une Aventure (époque I) au niveau de héros.

## Mesures (pilote automatique, `tools/sim_survie.py`, 5 classes × 3 graines, coups évités 0,5, boss après 6 min)

**Compte neuf, carte I-1** (niveau de héros 1, équipement de départ) :

| Série | M′ I-1 | Survit 7 min | Boss atteint | Boss battu |
|---|---|---|---|---|
| N2 (0.1.229, avant) | ×0,85 (époque) | 83 % | 10 % | 3 % |
| montée 6 %/min | 0,68 | 67 % | 13 % | 0 % |
| montée 2 %/min | 0,68 | 80 % | 33 % | 13 % |
| 2 %/min | 0,5 (2 graines de séries) | 87-93 % | 20 % | 20 % |
| **2 %/min** | **0,35** | **87 %** | **53 %** | **53 %** |
| 2 %/min, pilote qui file au boss (`--rush 4`) | 0,5 | 80 % | 73 % | 73 % |

Le pilote « boss atteint » bute surtout sur le chemin (il se bat à moins de 8 m et ne marche plus quand la horde le tient) : plus il tue
vite, plus il arrive. Retenu : **M′ I-1 = 0,35**, montée **2 %/min** (6 %/min, l'estimation du document, rendait la fin de carte bien plus
dure qu'avant : le héros ne prend plus de niveau pendant la carte, les monstres non plus).

**Défense des monstres** (sonde `boss_ttk`, héros au haut de la bande, pièces de la carte +5, bonne run) : avant le plafond, les boss
d'époque III-IV ne tombaient pas en 400 s (temps estimé 1 000 à 36 000 s) : la défense d'un monstre suit ×1,1 par niveau et
100 / (100 + défense) ne laissait passer que ≈ 1 % des coups au niveau 90. Plafonnée (`DEF_LEVEL`), temps pour tuer (s, moyenne
géométrique de 5 classes) avec les M′ du document : I 23 / 55 / 47, II 39 / 38 / 20, III 22 / 13 / 56, IV 29 / 33 / 42.
M′ remis à l'échelle pour 60 / 90 / 120 s (cible P11) : `MAP_MULT` I 0,35 / 1,3 / 2,1 ; II 4,4 / 7 / 24 ; III 46 / 121 / 25 ;
IV 410 / 770 / 290 (creux des 3es cartes III et IV : pièces éveillées, comme le document).

**Dégâts des boss** : avec les dégâts = M′, le héros « correct » mourait au boss (sonde, coups évités 0,5 : 4 à 11 PV max perdus par
minute, I-1 seule à 1,1) ; au pilote (`--rush 4`) cartes I-2, II-1, III-2, IV-3 : carte tenue 80-100 %, boss battu 0-7 %. Tables à part
`BOSS_ATK` et `MAP_ATK` (même valeurs pour l'instant), visée ≈ 0,9 PV max perdu par minute : I 0,35 / 0,22 / 1,2 ; II 0,6 / 0,8 / 1,9 ;
III 9,6 / 14,7 / 3,7 ; IV 43 / 71 / 34. Sonde (coups évités 0,5) après : PV max perdus par minute I 0,9 / 1,3 / 0,9 (morts 0 / 3 / 1
sur 5), II 2,2 / 2,4 / 4,1, III 3,6 / 12 / 5,5, IV 4,5 / 6,2 / 5,1 (tous morts) : époques I-II presque réglées ; aux époques III-IV
les dégâts ne baissent presque plus avec `BOSS_ATK` (coups de 0,3 à 1 PV max : mécaniques des boss, à voir au sous-lot suivant).

## Tests
`test_h4a` (nouveau, 35 vérifications : tables, règles de la partie, coffres et port, vraie carte, autres modes). Adaptés en gardant
leur intention : `test_p9`, `test_p11` (PV au niveau du boss ; croissants d'une époque à l'autre, 3e carte au-dessus de la 1re),
`test_p15` (niveau des monstres suit `Run.hero_level`), `test_e6` (M′ par carte ; le modèle du document passé à l'outil), `test_e4`
(rang des gemmes), `test_farm` (pièces au niveau du héros), `test_build`, `test_h3` (port vérifié en partie). Verts : `test_gear_run`,
`test_n2`, `test_a4`, `test_h1`, `test_h2`, `test_h3`, `test_royale`, `test_tooltips`, `test_p4_flow`, `test_e5`, `test_results`,
`test_journal`, `test_texts_fr`.

## Reste / pièges
- Réglage fin (H4b) : `BOSS_ATK` et `MAP_ATK` par carte au pilote, retard d'équipement (≈ 25 %), époques entières.
- Chasseur au compte neuf : meurt vers 4-6 min sur I-1 dans toutes les séries (les autres classes tiennent) : à regarder (classe).
- Le pilote ne prend pas le portail : une run complète ne se mesure pas ; `--stage` + `--start-run` (cartes des niveaux d'avant).
- `Run.hero_level` en Aventure n'est plus recopié de `Player.level` : un outil qui pose `player.level` pour régler la puissance doit poser
  `Run.hero_level` (corrigé dans `progression_sim.power_index`).
- Les dossiers de brouillon `h4a_*` (APPDATA détourné) restent dans le dossier de brouillon de la session.
