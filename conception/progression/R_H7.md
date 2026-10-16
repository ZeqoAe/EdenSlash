# R_H7 — outils de mesure du niveau de héros (16/10/2026)

Lot H7 de `NIVEAU_HEROS.md` §4.2. Fichiers : `game/tools/progression_sim.gd`, `game/tools/hl_probe.gd` / `.tscn` (nouveaux),
`game/tests/test_e6.gd`. Aucun fichier de jeu touché.

## Fait
- **`progression_sim --heros`** : le modèle `hl_sim` de PR2 intégré à l'outil (variables réglables par `test_e6`) — niveau de
  héros H (1-90) par compte, XP au kill (`xp_need` = 105 × 1,035^L, écart `xp_gap` = clamp(1,1^(monstres − H), 0,1, 3), +20 % sur
  victoire, activités ×0,6) ; **bandes** `band_lo` / `band_hi` (1-23 … 80-90), monstres au niveau `band_level` = clamp(H, bas, haut) ;
  pièces comptées **à leur niveau** (héros au niveau H, sans plafond 15 / 25 / 35 ni décote) ; `MAP_MULT` par carte
  (`HERO_PROBE_MULT` × `HERO_EPOCH_FACTOR` = table du §1.4 ; si le jeu a un jour un `Epochs.MAP_MULT`, l'outil le prend par défaut) ;
  **port limité par H** (Armurerie, plans de donjon, coffres, trouvailles de run ; pièces de départ toujours portables) ; pièces
  choisies sur leur PE ; jalons `hero10` … `hero90` (et `hl` = H médian à chaque jalon), `dungeon_0`, `kit80_ok`, `kit90_ok` déjà là.
- Drapeaux : `--heros`, `--hero-level=N` (part du niveau N, implique `--heros`), `--xp=a,g` (ou `--a=` / `--g=`), `--mep=` (facteur
  d'époque), `--mapmult=` (12 valeurs), `--epochcap`, `--sync`. Le mode est appelé `--heros` comme dans le document : `--heroic=`
  existait déjà (rapport de PE du Héroïque, lot A7) et garde ce sens.
- **Défaut inchangé** : sans `--heros`, sortie identique à l'outil de 0.1.224 (même commande, 4 comptes, 25 h, graine 3 : diff vide).
- **`tools/hl_probe`** (extends `progression_sim`) : indices bruts des kits types par niveau, R par carte (jeu actuel | refonte H |
  niveau de héros brut | avec `MAP_MULT`), **M′ suggéré** par carte, retard dans la bande, héros au-dessus de la bande ;
  `--talents` : talents et certificats (§2.2).
- `test_e6` : `_test_h7_model` (courbe d'XP du §1.3, écart, 12 bandes, `MAP_MULT` = table §1.4 à 2 %, monstres dans la bande, port,
  défaut sans niveau de héros) et `_test_h7_heros` (6 comptes, 45 h, graine 11 ; `-- --full` : la mesure du document, ± 15 %).

## Mesures (copie propre de HEAD 0.1.224 + ces fichiers ; 12 comptes, guerrier, 50 h, graine 1)
Le §5 se reproduit (le document mesurait 0.1.222 : les lots A3 et A5 sont passés depuis). Médianes, h (H = niveau de héros au jalon) :

| Jalon | moyen (document) | **moyen** | débutant (doc.) | **débutant** | bon (doc.) | **bon** |
|---|---|---|---|---|---|---|
| époque I | 2,8 (H 35) | **2,8 (H 37)** | 3,0 | **3,4** | 2,4 | **2,5** |
| époque II | 10,6 (H 64) | **10,2 (H 62)** | 11,2 | **10,7** | 9,7 | **9,2** |
| époque III | 17,7 (H 76) | **19,2 (H 77)** | 20,6 | **19,3** | 17,4 | **17,7** |
| époque IV | 31,2 (H 90) | **32,4 (H 90)** | 36,3 | **33,7** | 29,5 | **29,9** |
| 1er donjon / Héroïque / Mythique ouvert | 3,2 / 18,2 / 33,8 | **3,0 / 18,9 / 33,7** | 3,0 / 17,7 / 36,0 | **3,9 / 18,2 / 33,2** | 2,4 / 17,4 / 31,9 | **2,8 / 16,8 / 33,8** |
| niveau 90 | 29,3 | **29,7** | 30,6 | **30,4** | 28,4 | **28,9** |
| équipement 80-90 correct | 37,4 (92 %) | **37,9 (75 %)** | 40,9 | **38,6 (83 %)** | 35,5 | **36,2 (92 %)** |

Courbe (moyen) : niveau 43 à 3,5 h, 60 à 8,5 h, 80 à 20,1 h, 90 à 29,7 h (document : 3,6 / 8,5 / 19,9 / 29,3). `kit90_ok` : non atteint
en 50 h. Sonde (`hl_probe`) : M′ suggéré = `HERO_PROBE_MULT` à 1 % près sauf I-1 (0,97 contre 0,9 : le kit « 1.1.5.2 » monte au
niveau 33, au-dessus de la bande 1-23) ; retard dans la bande ×0,73-0,79 à +10 niveaux, ×0,65-0,74 à +15 ; héros au-dessus de la
bande ×1,35 / ×1,9 / ×4 à +5 / +10 / +20 : comme le §1.4. `test_e6` : vert en ≈ 2 min (copie propre et dossier de travail) ;
`-- --full` reproduit la colonne « moyen » ci-dessus à l'identique.

## Lancer chaque mesure
APPDATA détourné par processus si plusieurs tournent en parallèle ; mesurer sur une copie propre (`tools/run_tests.py`,
`preparer_copie`) : le dossier de travail contient les lots en cours des autres sessions.

| Mesure | Commande (`godot --headless --path game …`) | Durée |
|---|---|---|
| Colonne « niveau de héros » du §5 (moyen) | `res://tools/progression_sim.tscn -- --accounts=12 --hours=50 --seed=1 --quiet --heros --refonte --plans=boss --hubvalue` | 2 à 12 min selon la charge |
| Débutant / bon | idem `--skill=debutant` / `--skill=bon` | idem |
| Courbe d'XP, plafond d'époque, synchronisation | idem `--xp=120,1.03`, `--epochcap`, `--sync` | idem |
| Autre M′ | idem `--mep=1,1,1,1` (M′ brut de la sonde) ou `--mapmult=0.68,0.8,…` (12 valeurs) | idem |
| Compte migré | idem `--hero-level=43` (part du niveau 43) | idem |
| Trace d'un compte | ajouter `--trace` (une ligne par run avec le niveau de héros) | — |
| Sonde de puissance, M′ suggéré | `res://tools/hl_probe.tscn [-- --class=magician --levels=20,40,60,90]` | ≈ 1 min |
| Talents et certificats (§2.2) | `res://tools/hl_probe.tscn -- --talents` | ≈ 1 min |
| Test | `res://tests/test_e6.tscn` (`-- --full` : colonne du document à ± 15 %, plus long) | ≈ 2 min |
| Colonnes de la refonte (A7), inchangées | `res://tools/progression_sim.tscn -- --accounts=12 --hours=50 --seed=1 --quiet --refonte --hubvalue --decote --mult=0.85,1.3,2.3,4.4` | ≈ 10 min |

## Reste / pièges
- `tools/sim_survie.py --hero-level=` et `boss_ttk` aux hauts de bande (prévus au §4.2) : **pas faits** — ils pilotent le vrai jeu,
  qui n'a ni niveau de héros (H1) ni bandes (H4a) ; à faire dans H4b, quand `Epochs.band` et `Run.card_level` existeront.
  `boss_ttk.gd` est aussi modifié par la passe N2 (non poussée) : pas touché ici.
- Quand H4b posera `Epochs.MAP_MULT` dans le jeu, l'outil le lira par défaut (`--mep` / `--mapmult` le remplacent) ; quand H1
  posera `core/hero_level.gd`, aligner `HERO_XP_A` / `HERO_XP_G` / `HERO_GAP*` sur ses constantes (le test de la courbe suit le §1.3).
- Le simulateur ignore toujours talents et certificats en Aventure (×1,4 à 2 cases, §2.2) et le coffre de plans des boss (A4).
- `progression_sim.gd` du dossier de travail portait déjà la retouche de N2 (plus de `Run.slot_bonus = {}`) : gardée et poussée
  avec ce lot (sans effet sur HEAD : rien ne remplit `slot_bonus` dans la simulation).
