# R_H4b — équilibre mesuré de l'Aventure, carte par carte (lot H4b de `NIVEAU_HEROS.md`)

Versions : **0.1.270** (outils de mesure, carte I-1), **0.1.273** (époques II à IV, outil de progression recalé, textes).
Mesures sur une copie propre de HEAD (APPDATA détourné), machine partagée très chargée (jusqu'à 58 processus Godot) : **bruit
± 15 points** sur 20 combats (le tirage des graines et des classes compte plus que la charge : un même cas rejoué donne le même
résultat).

## Instruments (ce qui a changé dans la façon de mesurer)

| Outil | Rôle | Nouveau |
|---|---|---|
| `tools/boss_ttk.py` (sonde) | combat du boss seul, après une « bonne run » (cartes, trophées, trouvailles), **aide « Bot » du jeu**, coups évités 0,5 | scénario `bande+10` (avance), équipements de retard choisis par carte (`BAND_LATE`, ≈ 10 niveaux de pièce), `--repeat`, `--boss-atk-scale` |
| `tools/sim_survie.py --bot` | **partie entière** jouée par l'aide « Bot » (déplacement, sorts, cartes), entrée au boss à `--boss-after` (`world --boss-at`) | nouveau ; durée du combat (`boss_fight`) |
| pilote `--autoplay` | ancien pilote de mesure | `--ranged` : un tireur tire à sa portée (sans le drapeau : inchangé) |
| `hl_probe --calage=… --late=…` | M′ de `progression_sim` recalé sur les chances mesurées | nouveau |

L'aide « Bot » est la référence « sensation d'un joueur » (elle ne fait pas l'annulation parfaite : un joueur appliqué fait mieux).
Le pilote `--autoplay` frappe 2 à 3 fois moins et rate souvent le chemin du boss : il donne 30 % de boss battus sur I-1 avec un compte
neuf quand l'aide « Bot » en donne 95 % ; il reste un plancher, pas une cible.

**Équipement** : correct = pièces de la carte à +5, héros au haut de la bande (convention H4a) ; retard = pièces ≈ 10 niveaux plus bas,
même héros (I-2 : I-1 +5 ; II-1 : I-3 +0 ; III-2 : II-3 +5 ; IV-1 : III-2 +5 ; IV-3 : III-3 +5…), sans trouvailles ; avance = héros
10 niveaux au-dessus (90 au plus) et pièces de son niveau (IV-2 / IV-3 : pièces IV-3 +10 et gemmes).

## Tableau final (% de boss battus ; sonde : 20 combats, 10 classes × 2 ; partie entière : 10 parties, 5 classes × 2)

| Carte | Correct (sonde) | Retard 10 | Avance 10 | Partie entière, aide Bot (correct) |
|---|---|---|---|---|
| I-1 compte neuf (niveau 1, départ) | — | — | — | **55 %** débutant (coups évités 0,3) / **75 %** bon joueur (0,5), 20 parties chacun |
| I-2 | 65 % | 55 % | 100 % | 60 % |
| I-3 | 60 % | 40 % | 100 % | — |
| II-1 | 65 % (PV ×1,26) | 25 % | 100 % | 30 % (PV ×1,26) → PV ramenés à ×1,1 (non remesuré) |
| II-2 | 70 % | 15 % | 100 % | — |
| II-3 | 60 % | 0 % | 100 % | 50 % |
| III-1 | 65-75 % (deux séries) | 0-5 % | 100 % | — |
| III-2 | 60 % | 0 % | 100 % | 50 % |
| III-3 | 65 % | 20 % | 100 % | — |
| IV-1 | 65 % | 20 % | 95 % | — (série arrêtée : machine saturée) |
| IV-2 | 65 % | 5 % | 80 % (héros 90 : 5 niveaux d'avance seulement) | — |
| IV-3 | 75 % | 15 % | 85 % | — |

Avant (HEAD 0.1.254, sonde 10 combats) : correct I-1 100 %, I-2 50, I-3 50, II-1 90, II-2 90, II-3 70, III-1 100, III-2 90, III-3 90,
IV-1 80, IV-2 90, IV-3 70 ; compte neuf sur I-1 à l'aide Bot 95 % (0,5) / 85 % (0,3).

Lecture : (a) correct **60-75 %** partout ; (c) avance **80-100 %** (jamais en dessous de 80) ; (b) retard **≈ 25 % à l'époque II,
0-20 % aux époques III-IV, 40-55 % à l'époque I** : 10 niveaux de pièces valent ×1,5 à l'époque I (les stats du héros dominent) mais
×3 à ×4 aux époques III-IV (indice de l'outil et DPS mesurés) ; viser 25 % partout rendrait l'équipement correct trivial aux époques
III-IV. IV-1 en retard : 20 % (53 % avant, « trop facile »). (d) compte neuf ≈ 50 % pour un débutant ; le **chasseur neuf** ne meurt
plus vers 4-6 min : c'était le pilote, qui jouait les tireurs au contact (`--ranged`) ; à l'aide Bot il tient la carte 8 fois sur 8, mais
c'est la classe la plus faible face aux boss (1 boss d'I-1 sur 8 ; partout, 45 % de morts contre 5-15 % : PV de départ −24 % et DPS −30 %
face au guerrier, plus de dégâts subis par minute à distance) : **à traiter dans un lot de classes** (hors des tables de l'Aventure).

## Tables modifiées (époque I / II / III / IV × cartes 1-2-3)

| Table | Avant (0.1.254) | Après (0.1.273) |
|---|---|---|
| `BOSS_HP_ADJ` | I 1 / 1 / 1 ; II 0,6 / 1 / 1 ; III 0,8 / 1 / 1 ; IV 0,7 / 0,6 / 0,45 | I **1,5** / 1 / 1 ; II **1,1 / 1,61** / 1 ; III **1,6 / 1,3 / 1,5** ; IV 0,7 / **1,17 / 0,81** |
| `BOSS_ATK` | I 0,35 / 0,22 / 1,2 ; II 0,15 / 0,18 / 0,27 ; III 0,6 / 0,42 / 0,05 ; IV 0,33 / 0,18 / 0,15 | I **0,525** / 0,22 / 1,2 ; II **0,162 / 0,36** / 0,27 ; III **1,5** / 0,42 / **0,1** ; IV **0,66 / 0,3 / 0,225** |
| `MAP_ATK` | II 0,25 / 0,3 / 0,45 ; III 1,4 / 1,0 / 0,12 ; IV 1,1 / 0,6 / 0,5 | II **0,45 / 0,6** / 0,45 ; III **3,5** / 1,0 / **0,24** ; IV **2,2 / 1,2 / 0,75** (époque I inchangée) |
| `MAP_MULT`, `BOSS_HP_MAP`, `BOSS_HP_EPOCH`, rage | — | inchangés (PV fixes par carte, rage 2:30 / 3:00 / 4:00) |

`MAP_ATK` suit `BOSS_ATK` là où la sonde a été réglée avec `--atk-scale` (les renforts du boss en profitent) ; la carte n'en devient
pas mortelle : 0 mort sur la carte en 40 parties entières (I-2, II-1, II-3, III-2). Parties entières (aide Bot) : 30-60 %,
un peu sous la sonde (boss atteint à 6 min, avec moins de cartes et de trophées qu'une « bonne run »).

## Progression sur 50 h (`progression_sim --heros --refonte --plans=boss --hubvalue --bossplans`, 12 comptes, guerrier)

L'outil lisait `Epochs.MAP_MULT` du jeu comme son propre M′ (depuis H4a) : c'est un autre espace (défense plafonnée, dégâts et boss à
part) et l'Aventure y était bien trop dure (d'où ≈ 46 h pour l'équipement 80-90 correct, mesure de GX-2). Il lit maintenant
`HERO_GAME_MULT`, recalé par `hl_probe --calage` sur les chances mesurées (équipement correct et retard, deux points par carte).

| Jalon (médiane, h) | Document (§5) | Recalé, graine 1 | graine 2 | sans coffre de plans |
|---|---|---|---|---|
| époque I | 2,8 | **3,5** | — | 4,9 |
| époque II / III | 10,6 / 17,7 | **11,6 / 19,4** | — | 13,7 / 20,5 |
| époque IV | 31,2 | **30,6** | 29,9 | 27,6 |
| niveau 90 | 29,3 | **29,7** | 30,2 | 30,1 |
| équipement 80-90 correct (`kit80_ok`) | 37,4 | **39,6 (92 %)** | 38,6 (67 %) | 36,6 (58 %) |

Époques et niveau 90 dans les cibles du document (I 2-4 h, IV 27-34 h, 90 à 26-33 h). **L'équipement 80-90 correct reste vers
37-40 h, pas 30 h** : à 36 h, les 9 emplacements sont déjà légendaires 80-85 chez presque tous les comptes ; il manque le **+5 des
3 à 5 dernières pièces achetées** (comptes à 3-30 cristaux ; ceux qui ont ouvert les donjons Héroïque / Mythique en ont 600-900) et
parfois l'arme (éveillée 75 gardée). Essais : coffre de plans qui vise l'emplacement le plus en retard −1 à −3 h (dans le bruit,
pas gardé) ; 3 fois plus de coffres de récompense à l'époque IV −3 h (34-36 h, pas gardé : économie hors de ce lot). Le jalon dépend
donc des **cristaux** et de l'ouverture des donjons difficiles, pas de la difficulté de l'Aventure : leviers à trancher (lot
d'économie) : cristaux des coffres de forge de niveau 80-90, ou verrous de PE des donjons Héroïque / Mythique ; `GOLD_PER_CRYSTAL`
n'a pas été touché.

## À valider par le joueur au ressenti
- Boss d'I-1 pour un compte neuf (PV et dégâts ×1,5) : « 1re run punitive » sans être injuste ?
- Boss des époques II-IV qui frappent plus fort (morts entre 40 et 100 s quand on ne lit pas ses attaques) : lisibles ?
- Retard d'équipement : presque sans espoir aux époques III-IV (voulu : « on peut ne pas réussir sans assez de stuff »).
- Chasseur (et rôdeur) : plus faibles face aux boss.

## Reproduire
- Sonde : `python tools/boss_ttk.py --scenarios bande,bande-10,bande+10 --epochs 2 --stages 1 --human 0.5 --repeat 4`
  (`--classes` pour 10 classes ; `--extra "--boss-scale=1.2 --boss-atk-scale=0.8"` pour essayer un réglage).
- Partie entière : `python tools/sim_survie.py --bot --hub 2.1.5 --hero-level 48 --epoch 2 --stage 1 --boss-after 360 --human 0.5
  --classes warrior,magician,hunter,cleric,thief --seeds 2` (cartes 2-3 : `--extra=--start-run=17` / `27`) ; compte neuf : `--hub new`.
- Calage de l'outil : `res://tools/hl_probe.tscn -- --calage=<12 chances correct> --late=<12 chances retard>`, puis `HERO_GAME_MULT`.

## Tests
`test_h4a` (+2 vérifications : dégâts du boss à part, réglages de mesure neutres, boss d'I-1), `test_e6` (+1 : M′ de l'outil =
`HERO_GAME_MULT`), verts avec `test_p11`, `test_n2`, `test_p9`, `test_gear_run`, `test_a4`, `test_h3`, `test_h1` (copie propre).

## Pièges
- Ne pas lire `Epochs.MAP_MULT` dans `progression_sim` : un réglage de l'Aventure se recale par `hl_probe --calage` (mesures neuves).
- Un même cas de la sonde rejoué avec les mêmes graines donne le même résultat : le bruit vient des graines et des classes ; 20 combats
  au moins par cas, 10 classes.
- Fichiers partagés (`player.gd`, `progression_sim.gd`, `DESIGN.md`, `CLAUDE.md`) : index construit depuis HEAD par remplacements.
