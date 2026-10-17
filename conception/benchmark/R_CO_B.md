# R_CO_B : Le Colisée, lot CO-B — carte, anneau de feu, fleurs de vie (17/10/2026)

Étude : `ARENA.md` § 6.3 (anneau de feu), § 6.4 (arènes) ; socle : `R_CO_A.md`. Lot = backlog n° 2.

## 1. Ce qui a été livré

| Élément | Fichier | Rôle |
|---|---|---|
| Carte | `game/scripts/world/proc_map.gd` (`generate_colisee(graine, n)`, `colisee_arenas`, constantes `COLISEE_*`) | une arène par combat simultané, en grille à **120 m** les unes des autres (3 × 2 pour 6 arènes, 2 × 2 pour 4, 3 × 3 pour 8 ; carte carrée de 360 m, 240 m en Éclair) ; chaque arène = cuvette **plate sur 24 m** de rayon, falaise au-delà de 26 m (plus de 40 m de haut à mi-chemin de la voisine : infranchissable, rien ne se voit de l'une à l'autre), 4 **piliers** à 11 m (gros blocs du biome, avec collision), 1 ou 2 points de **fleurs**, 4 torches, couronne de rochers ; piste claire à 14 m et rond central au sol (repères) ; navigation cuite pour toute la carte |
| Arène | `game/scripts/world/colisee_arena.gd` (`ColiseeArena`) | porte l'anneau et les fleurs d'un combat : `build_all(carte, parent)`, `spawn_point(camp, k)` (camps face à face à 9 m du centre), `reset`, `tick`, `set_shown` (arène cachée : rien de dessiné) |
| Anneau de feu | `game/scripts/world/colisee_ring.gd` (`ColiseeRing`) + `game/shaders/colisee_ring.gdshader` | 22 m → 16 m à 25 s → 11 m à 40 s → 6 m à 55 s → 3 m à 70 s ; chaque resserrement annoncé **4 s avant** (signal `warned`, prochain anneau en pointillés qui défilent) et fait en 2 s ; hors de l'anneau : **5 % des PV max par seconde + 2 % par seconde passée dehors** (remis à zéro en rentrant), versés par paquets de 0,25 s (sans source ni défense : le même danger pour tous), **soins reçus divisés par deux** ; dessin : bord blanc net + liseré mandarine foncé, voile mandarine dehors à 32 % au plus (BIBLE § 10) |
| Fleur de vie | `game/scripts/world/colisee_flower.gd` (`ColiseeFlower`) | le premier héros vivant dessus est soigné de **15 % de ses PV max** (la moitié des soins du JcJ est compensée) et protégé 4 s (statut « barrière », dégâts subis −40 %), puis elle repousse en **20 s** (bouton qui grossit) ; dessin autocollant : 5 pétales pomme contourés d'encre, cœur soleil, halo au sol |
| Soins réduits | `game/scripts/combat/combatant.gd` (`heal_taken`, 1 partout) | multiplicateur des soins reçus, posé par l'anneau ; 1 dans tous les autres modes (rien ne change ailleurs) |
| Test | `game/tests/test_co_b.tscn` | § 3 |
| Captures | `game/tests/shot_co_map.tscn` (`CO_MAP_N=8` : Grand tournoi) | les 6 arènes vues d'en haut, anneau à 37 s, puis la carte entière, en 1280 × 720 et 1600 × 900 |

Particularités d'arène (Ruines, Désert, Glace, Volcan, Bosquet) : **noms et clés seulement** (`ProcMap.COLISEE_KINDS`, `info.kind`) ; les
mécanismes sont au lot CO-L (P2), comme prévu par l'étude.

## 2. Choix et écarts à l'étude
- **120 m au lieu de 300 m** entre deux arènes : une seule carte `ProcMap` (terrain, navigation, mini-carte) au lieu de plateaux posés dans
  le vide comme à l'Échiquier ; à 300 m la carte ferait 900 m de côté (12 fois plus de sommets à cuire). À 120 m la falaise qui sépare
  deux arènes dépasse 40 m, la pente est infranchissable (> 55° dès 34 m du centre) ; le filtre `arena_id` (MODE-0) reste la vraie
  séparation logique (aucun ciblage d'une arène à l'autre, prouvé en jeu par `test_mode0` même à 0 m).
- **Piliers** : les deux premiers rochers du biome (des blocs) ; les rochers suivants des biomes comptent des os et des cratères décoratifs,
  et les rochers communs du jeu sont moussus (verts sur le sable, et le vert dit « gain » : la fleur).
- **Biome** : celui de l'arène du Duel (« arid ») pour toutes les arènes d'une partie (une carte = un biome) ; le voile mandarine se lit
  moins sur le sable orangé que le bord blanc : le bord fait le travail (à revoir au lot CO-G avec le HUD « Feu · n s »).
- La carte coûte 0,3 à 1,1 s à générer et 0,3 à 1,2 s de navigation (mesures du test, machine chargée) : faite pendant la présentation.

## 3. Tests et captures

`test_co_b` (≈ 45 contrôles, 22 s) : cartes de 6, 8 et 4 arènes (navigation cuite, noms, centres, piliers à 11 m, 1-2 fleurs, sol plat
jusqu'à 22 m, falaise de plus de 30 m entre voisines, 120 m d'écart, arènes posées avec anneau et fleurs, points de départ face à face
dans l'anneau, arène cachée sans rien de dessiné) ; courbe de l'anneau (22 / 19 à 26 s / 16 / 11 / 6 / 3 m, prochain resserrement) ;
dégâts dehors (1 s ≈ 6 %, la rampe : 2 s de plus ≈ 18 %, rien dedans, soins divisés par deux, compteur remis à zéro en rentrant,
annonce 4 s avant, nouvelle manche) ; fleur (soin de 15 %, barrière, une seule fois, repousse en 20 s).

Résultats (copie de HEAD 0.1.293 + CO-B, 32 Godot actifs) : `test_co_b`, `test_mode0`, `test_pvp` verts ; `check_scripts` : 540 scripts.

Captures **regardées** (`shot_co_map`, hors dépôt : `C:\AI\benchmark_refs\arena\co_b\`, 14 images) : les 6 arènes en 1280 × 720 et
1600 × 900 et la carte entière (6 cuvettes séparées). Corrigé après lecture : les piliers étaient tirés parmi tous les rochers du biome
(des os et un cratère au milieu de l'arène) puis parmi les rochers communs (moussus, verts) → les blocs du biome ; les fleurs étaient trop
petites à la hauteur de la caméra de combat (× 1,7). Reste : ombres en escalier sur la falaise dans l'outil de capture (soleil de l'outil,
pas celui du jeu ; à revoir sur les captures en partie du lot CO-C).
