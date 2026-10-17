# R_MB_B : Les Deux Voies, lot MB-B — la carte

Lot MB-B du plan `conception/benchmark/MOBA.md` (§ 7.4, § 9 ; croquis `moba_maquettes/v2_carte.svg`). La carte du mode,
générée par code à partir de `ProcMap` (terrain, textures, herbe, décor en `MultiMesh`, mini-carte : les mêmes que les autres
cartes du jeu), avec un maillage de navigation **précuit**. Pas encore lançable seule (structures, sbires et lancement : MB-C).

## 1. Livré

| Élément | Fichier | Rôle |
|---|---|---|
| Carte | `game/scripts/world/moba_map.gd` (`MobaMap extends ProcMap`, `generate_moba(graine)`) | relief, sol, voies, rivière, bases, décor, murs, voies denses, disposition `moba`, navigation, mini-carte |
| Maillage précuit | `game/assets/maps/moba/navmesh.res` (16 Ko, 637 polygones) | chargé tel quel (1-8 ms) si son tampon `layout` = `MobaMap.LAYOUT_VERSION` |
| Outil | `game/tools/moba_map_tool.tscn` | `--bake` (recuit), `--measure` (voies, trajets), `--shots=<dossier> --res=1280x720` (vues) |
| Test | `game/tests/test_mb_map.tscn` | 30 contrôles (§ 4) |
| Captures | `conception/benchmark/mb_b/*.jpg` | regardées (§ 3) |

## 2. La carte

- **Aire de jeu 200 × 120 m** au centre d'un terrain de 256 m ; tout autour, des coteaux boisés (pente douce, arbres du biome) et
  des **murs invisibles** au bord de l'aire : aucune paroi noire à l'écran, rien de praticable dehors (vérifié par la navigation).
- **Bases** aux extrémités : Cœur bleu à x = −80 m, rouge à + 80 m, fontaine 10 m derrière ; parvis pavé de 13 m, sol légèrement
  teinté et **liseré de la couleur d'équipe avec son motif** (rond pour Azur, carré pour Braise : règle de la BIBLE § 3), 4 bannières,
  2 torches.
- **Voies** (courbes de Catmull-Rom, 11 m de large, pavé au centre et terre sur les bords, à plat) : Voie du Soleil en haut, Voie des
  Brumes en bas, **196,2 m de Cœur à Cœur (30,2 s à 6,5 m/s)**. Voies denses pour les sbires (`lane_wp[voie][camp]`, un point tous les
  4 m dans le sens de marche du camp, `lane_point`, `lane_index`, `lane_progress`). Tours : T2 à 11 % de la voie (angle de la base), T1
  à 30 % (`MobaData.TOWER_AT`), sur le bord extérieur de la voie.
- **Jungle** entre les voies : 26 rochers (couvert qui bloque le passage et les tirs, collisions), 24 arbres fins (couvert léger),
  14 buissons (touffes serrées de grandes plantes, sans collision ; `bush_at(p)` pour le lot MB-G), fleurs et herbes ; **rivière**
  au milieu (lit de 9 m, 0,6 m plus bas, gué partout praticable, eau claire translucide en un seul maillage) avec deux **fosses** de
  8 m de rayon : **Colosse** côté Soleil (liseré améthyste), **Gardien** côté Brumes (liseré mandarine).
- **Camps** (taches de terre) par moitié : Source, Braise, 2 petits (`moba.camps`, lot MB-F).
- **Symétrie en miroir** (x → −x) au lieu de la rotation de l'étude : avec une seule fosse de chaque côté de la rivière, la rotation
  aurait mis le Colosse du côté Soleil d'une équipe et du côté Brumes de l'autre ; en miroir, chaque équipe a la Voie du Soleil en
  haut et les mêmes trajets vers chaque objectif (vérifié : 93,3 et 93,5 m de la fontaine aux deux fosses).
- Tout est **fixe** : la graine ne change que les petits décors (plantes, arbres des coteaux), jamais le jeu ni la navigation.
- Biome de la zone « rainbowfall » (Forêt de l'arc-en-ciel : clair, BIBLE § 1). Rochers : ceux du biome (`ud00x`), sans les racines et
  troncs couchés (`ud1xx`, `ud3xx`) qui se lisaient comme des bûches ; arbres de jungle `ue302` seulement (même raison).

## 3. Navigation, trajets, coût

| Mesure | Valeur | Cible |
|---|---|---|
| Génération complète (terrain, décor, herbe, mini-carte) | 1,2-3,1 s (machine saturée) | écran de chargement |
| Maillage : précuit chargé / cuisson sur le fil principal | 1-8 ms / 31 ms (637 polygones) | jamais en tâche de fond |
| Synchronisation du serveur de navigation après la génération | 7-9 images | attendue avant tout chemin (`nav_ready()`) et avant de quitter (piège T1) |
| Cœur à Cœur par une voie | 196,2 m, **30,2 s** | 28-32 s |
| Fontaine à fontaine par la Voie du Soleil / des Brumes | 202,9 / 203,7 m, **31,2 / 31,3 s** | 28-32 s |
| Fontaine à fontaine par la jungle (le plus court) | 187,1 m, **28,8 s** | 28-32 s |

- Le maillage est **précuit** (`assets/maps/moba/navmesh.res`, tampon `LAYOUT_VERSION`) ; périmé ou absent : cuit d'un coup sur le
  fil principal (31 ms) avec un avertissement. `test_mb_map` recuit et compare au précuit (même nombre de polygones et de sommets) :
  une carte changée sans recuire est rouge. Recuire : `godot --headless --path game res://tools/moba_map_tool.tscn -- --bake`, et
  augmenter `LAYOUT_VERSION` à chaque changement de géométrie.
- Le serveur de navigation de Godot 4.7 synchronise ses cartes **en tâche de fond** : un chemin demandé dans les premières images
  après la génération revient vide. `MobaMap.nav_ready()` le dit (point le plus proche de la fontaine trouvé) ; le directeur (MB-C)
  et les tests l'attendent.
- Captures regardées (`mb_b/`, 1280 × 720 et 1600 × 900, décor sans unités) : vue de dessus lisible (deux voies en anneau, rivière et
  bassins, bases aux couleurs d'équipe), herbe et rochers du biome, eau claire ; corrigés en route : falaises sombres (devenues des
  coteaux boisés), eau en damier et doublement de transparence (un seul polygone), bûches couchées (filtrées), lit de rivière qui
  débordait sur les coteaux.

## 4. Test `test_mb_map`

Vert sur HEAD 0.1.297 + MB-B : disposition (2 Cœurs, 2 fontaines, 8 tours, 8 camps, 2 fosses du bon côté, 14 buissons, 26 rochers,
24 arbres, tout dans l'aire), symétrie en miroir, voies de même longueur, tours au bord de leur voie, T2 avant T1, 28-32 s de Cœur à
Cœur, points de voie dans les deux sens, milieu de voie au gué, `lane_progress`, aucun lieu clé dans un obstacle, rien sur les voies,
buissons, voies plates, lit plus bas, coteaux, mini-carte, maillage précuit à jour et identique à une cuisson neuve, serveur prêt,
trajets fontaine à fontaine (jungle, Soleil, Brumes) en 28-32 s, camps / fosses / tours atteignables, rocher qui bloque, aucun
chemin hors de l'aire.

## 5. Pour la suite
- MB-C : structures aux positions `moba.towers` / `moba.cores`, sbires sur `lane_wp`, joueur à `moba.fountains`.
- MB-B ne repasse pas le banc d'image de MB-0 avec ce décor : il le sera avec les unités (MB-C, `R_MB_C.md`).
- Buissons : la cachette elle-même (on n'est plus vu de l'autre camp) = lots MB-G (IA) et MB-H (mini-carte).
