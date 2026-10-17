# R_MB0 : essai technique des « Deux Voies » (MOBA 4 contre 4) — verdict GO, avec conditions

Lot MB-0 du plan `conception/benchmark/MOBA.md` (§ 8 « Risques techniques », § 9 « Plan des lots »). Question posée : la scène du
mode tient-elle **60 images par seconde** (budget ≤ 16,6 ms, p95) avec 8 héros, ~48 sbires, 10 structures qui tirent, des camps,
des projectiles et des effets, sur une carte 200 × 120 m à deux voies, et à quelles conditions ? Rien du mode n'est implémenté :
seulement un banc et des mesures. Aucun changement de comportement du jeu (fichiers dans `game/tools/`, `tools/`, `conception/`).

## 1. Verdict

**GO** pour le plan de lots MB-A à MB-K, **à condition de tenir les budgets du § 6** (sbires « horde », recyclage, aucune création
de modèle pendant la partie). Chiffres (médiane de 3 essais, machine de développement **chargée à 100 %** par 14 à 28 autres Godot) :

| Mesure | Code du jeu tel quel (`base`) | Parades (`opt`) | Cible MOBA.md § 8 |
|---|---|---|---|
| Logique seule (sans rendu), 48 sbires visés (≈ 39 vivants), p50 / p95 | 4,98 / 7,55 ms | **2,89 / 4,67 ms** | logique < 6 ms |
| Temps CPU du processus par image (insensible à la charge) | 5,70 ms | **3,59 ms** | — |
| Rendu réel 1600 × 900, qualité haute, décor d'une vraie carte : p50 / p95 | 13,0 / **19,9 ms** | 10,3 / **15,7 ms** | p95 < 16,6 ms |
| Même chose, qualité basse | — | 9,0 / 12,9 ms | — |
| GPU (RTX 5070) avec décor, qualité haute | 1,09 ms | 0,94 ms | — |
| Pic d'une vague (20 sbires créés dans la même image) | **31-37 ms** (86 ms à 120 sbires) | 3-9 ms | aucun pic > 16,6 ms |
| ≈ 100 sbires vivants (pire cas), logique p50 / p95 | 11,2 / 13,9 ms | 4,9 / 7,4 ms | — |

- Le code du jeu tel quel **ne passe pas** : p95 de 19,9 ms en fenêtre avec décor, et un à-coup de 30-37 ms à chaque vague (création
  des modèles de sbires). Les parades proposées, toutes simples, le font passer **sous 16,6 ms au p95 même sur une machine saturée**.
- La navigation, les recherches de cibles par groupes et les tours ne sont **pas** des goulots à cette échelle (§ 4).
- Les deux vrais coûts : **les sbires `Monster` complets** (move_and_slide, animation à pleine cadence : 34 µs chacun contre 15 µs
  en « horde ») et **la création des modèles pendant la partie** (1,7 ms par sbire, 190-340 ms par héros au premier chargement).
- Côté rendu, le GPU n'est pas limitant (≤ 1,1 ms, 3 ms au pire sur une vue chargée de décor) ; c'est le **CPU du rendu des unités**
  (squelettes, ombres, étiquettes) qui pèse : ≈ 3,5-4 ms d'image en plus des scripts (§ 3.3).

## 2. Le banc

- `game/tools/moba_probe.tscn` + `moba_probe.gd` (directeur, carte, mesures) ; unités : `moba_probe_hero.gd` (le `ClassRival` du jeu,
  camps natifs `Team` : bleu = `ally`, rouge = adversaire, comme le prévoit MOBA.md § 7.5), `moba_probe_minion.gd` (`Monster` du jeu
  + suivi de voie), `moba_probe_tower.gd` (tour ou Cœur, `Combatant` immobile), `moba_probe_bolt.gd` (trait de tour / de tireur).
  Aucun `class_name` (pas de `--import` nécessaire).
- **Carte** 200 × 120 m : sol, bords, deux voies en courbe (Soleil en haut, Brumes en bas, 221 m de Cœur à Cœur, 11 m de large),
  rivière, 48 rochers de jungle symétriques, deux bases. **Navigation cuite d'un coup sur le fil principal avant toute unité**
  (`bake_from_source_geometry_data`, 34-270 ms selon la charge, 490 polygones ; aucun calcul en tâche de fond : pas de plantage
  à la sortie headless).
- **Unités** : 8 héros niveau 50 (fiche `Royale.sheet`, difficulté Difficile ; Brumes : Chevalier / Guerrier, jungle : Assassin /
  Kage, Soleil : Rôdeur + Clerc / Chasseur + Barde), règles JcJ des Arènes à l'échelle 0,09 (valeur de départ du profil `moba`) ;
  sbires (3 mêlées + 2 tireurs par vague, remis au quota toutes les 10 s, 5 au plus par voie et par camp) ; 8 tours + 2 Cœurs
  indestructibles (charge constante) qui visent le sbire le plus proche puis le héros, et, banc `--busy=1`, tirent à blanc sur
  l'ennemi le plus proche à 45 m quand rien n'est à portée : **les 10 structures tirent sans arrêt** (pire cas) ; 12 monstres de
  camp. Héros morts : cachés 5 s puis remis à leur voie (pas de recréation de modèle). Caméra du mode : 22 m, plongée 55°, sur le
  tireur bleu du Soleil (ou vue large de 70 m, `--cam=wide`).
- Sanity : 5,6 héros sur 8 au combat en moyenne, ≈ 330 coups de héros, 75-90 sbires tués, 130-140 tirs de tour et 120-730 traits par
  minute mesurée. Captures : `conception/benchmark/mb0/*.jpg` (regardées : combat lisible à 22 m ; à 70 m les étiquettes d'état et
  les chiffres s'empilent, déjà prévu par P1-20).
- **Réglages** (`--preset=base|opt`, puis un réglage à la fois) : marche des sbires `--nav=path|flow|agent`, cibles
  `--target=group|grid`, `--lite`, `--lod`, `--pool`, `--light` (coup de sbire sans zone rouge), `--bolts=game|pool`, `--fx`,
  `--numbers`, `--minions`, `--quality`, `--shadows`, `--scale3d`, `--msaa`, `--decor=<biome>` (décor d'une vraie carte de Survie
  `ProcMap.generate_scenery` sous le sol plat, collisions coupées : rendu seulement), `--cam`. Détail en tête de `moba_probe.gd`.
- **Série** : `python tools/moba_probe.py [-r 3] [noms…]` : copie propre de HEAD + le banc (le dossier partagé contenait du travail
  en cours d'autres sessions qui ne compilait pas : `Modes` / `TeamMatch` du lot MODE-0), un dossier utilisateur par essai, essais
  entrelacés, **processus Godot mesuré un cran au-dessus de la priorité normale**, temps CPU du processus lu par `GetProcessTimes`
  pendant la seule fenêtre de mesure, charge notée (processus Godot ouverts, occupation du processeur). Journal :
  `conception/benchmark/mb0/mesures.jsonl` (87 essais) ; tableau complet : `conception/benchmark/mb0/tableau.md` (`--tableau`).
- Mesure : 12 s de mise en route puis 60 s (3 600 images) avec `--fixed-fps 60` (une image physique par image, aussi vite que
  possible : le temps d'une image est son coût complet), `--disable-vsync` en fenêtre ; GPU et CPU du rendu par
  `RenderingServer.viewport_get_measured_render_time_*` ; scripts par genre d'unité (leur `_physics_process` entier, chronométré) ;
  « passe physique » = de la première à la dernière passe physique des nœuds de l'image (nœud témoin de priorité 1000).

## 3. Mesures

Machine : AMD Ryzen 7 9800X3D (8 cœurs / 16 fils), 32 Go, RTX 5070, Vulkan (Forward+), Godot 4.7.2. **Charge : processeur occupé à
92-100 % pendant tous les essais, 7 à 28 autres processus Godot ouverts.** Médianes de 3 essais.

### 3.1 Logique (sans rendu)
| Réglage | sbires vivants | image p50 / p95 / max | CPU ms/image | héros | sbires | tours + traits | camps |
|---|---|---|---|---|---|---|---|
| `base` | 40 | 4,98 / 7,55 / 37 | 5,70 | 0,57 | 1,34 | 0,05 | 0,20 |
| `opt` | 38 | **2,89 / 4,67 / 18** | **3,59** | 0,53 | 0,58 | 0,03 | 0,05 |
| `opt` 24 sbires | 20 | 2,33 / 3,68 / 15 | 3,17 | 0,50 | 0,31 | 0,03 | 0,05 |
| `opt` 96 visés | 51 | 3,33 / 5,14 / 17 | 4,06 | 0,55 | 0,78 | 0,04 | 0,05 |
| `opt` 120 visés | **99** | 4,87 / 7,36 / 57 | 5,84 | 0,58 | 1,56 | 0,06 | 0,05 |
| `base` 96 visés | 63 | 7,34 / 10,03 / 48 | 8,06 | 0,59 | 2,23 | 0,06 | 0,20 |
| `base` 120 visés | 101 | 11,18 / 13,90 / **98** | 11,93 | 0,67 | 3,62 | 0,07 | 0,21 |
| `opt` sans héros | 42 | 1,36 / 1,98 / 8 | 1,97 | — | 0,65 | 0,03 | — |
| `opt` héros seuls (8) | 0 | 0,84 / 1,27 / 6 | 1,39 | 0,35 | — | — | — |

(colonnes « héros » à « camps » : ms de script par image physique, moyenne.) Le reste de l'image (≈ 2,8 ms en `base`, 1,7 ms en
`opt`) : moteur physique, animations des `Monster` complets, `_process` des zones rouges, effets et chiffres de dégâts.

**Coût par unité** (scripts, par image) : héros `ClassRival` **45-75 µs** ; sbire `Monster` complet **34-36 µs**, en « horde »
**15-16 µs** ; tour + ses traits **3-5 µs** ; monstre de camp 16 µs éveillé, ~4 µs endormi. Grille spatiale refaite à chaque image :
0,07-0,14 ms. Création d'un sbire : **1,7 ms** (modèle instancié), 0,11 ms recyclé ; d'un héros : 190-340 ms au premier
chargement sur la machine chargée.

### 3.2 Une parade à la fois (depuis `base`)
| Changement | image p50 | p95 | max | CPU ms/image | Gain |
|---|---|---|---|---|---|
| (aucun) `base` | 4,98 | 7,55 | 37,3 | 5,70 | — |
| sbires « horde » + niveau de détail (`lite`, `lod`) | **3,00** | **4,67** | 38,3 | **3,68** | **−2 ms : le gros gain** |
| recyclage des sbires (`pool`) | 4,73 | 6,77 | **19,5** | 5,52 | **supprime l'à-coup des vagues** |
| sans effets ni chiffres (`nofx`) | 4,05 | 5,03 | 33,9 | 4,57 | −0,9 ms (à plafonner, pas à couper) |
| coup de sbire sans zone rouge (`light`) | 4,64 | 6,53 | 39,3 | 5,40 | −0,3 ms |
| marche en courbe de voie (`nav=flow`) | 4,97 | 7,17 | 34,5 | 5,58 | ≈ 0 (chemins : 48 par s, 40 µs chacun) |
| NavigationAgent3D + évitement par sbire (`nav=agent`) | 5,02 | 7,27 | 44,0 | 5,88 | +0,2-0,3 ms |
| grille spatiale au lieu des groupes (`target=grid`) | 5,12 | 7,43 | 34,2 | 5,84 | ≈ 0 à 40 sbires |

### 3.3 Rendu réel (fenêtre 1600 × 900, RTX 5070)
| Réglage | image p50 / p95 / p99 | GPU moy / p95 | CPU du rendu | appels de dessin | mémoire vidéo |
|---|---|---|---|---|---|
| fenêtre vide (témoin) | 2,55 / 3,95 / 4,3 | 0,59 / 0,62 | 0,18 | 31 | 217 Mo |
| décor seul, sans unité (témoin) | 2,88 / 3,57 / 4,2 | 0,79 / 0,79 | 0,33 | 167 | 433 Mo |
| `base`, haute | 9,73 / 13,98 / 17,9 | 0,72 / 0,79 | 0,82 | 213 | 369 Mo |
| `opt`, haute | 9,29 / 13,03 / 17,1 | 0,70 / 0,77 | 0,89 | 189 | 371 Mo |
| `opt`, basse (sans ombres, MSAA coupé, rendu 3D à 75 %) | 7,88 / 11,91 / 14,5 | 0,20 / 0,25 | 0,67 | 108 | 233 Mo |
| `opt`, 52 sbires | 8,99 / 13,79 / 17,1 | 0,71 / 0,81 | 0,90 | 212 | 372 Mo |
| `opt`, vue large (70 m) | 9,08 / 13,37 / 17,5 | 0,66 / 0,70 | 1,06 | 288 | 369 Mo |
| **décor + `base`, haute** | 13,01 / **19,86** / 34,8 | 1,09 / 1,79 | 1,48 | 315 | 575 Mo |
| **décor + `opt`, haute** | 10,32 / **15,65** / 21,8 | 0,94 / 1,03 | 1,44 | 347 | 575 Mo |
| décor + `opt`, moyenne | 11,69 / 20,55 / 26,8 | 1,01 / 1,27 | 1,39 | 347 | 575 Mo |
| décor + `opt`, basse | 8,97 / 12,87 / 16,5 | 0,28 / 0,34 | 0,87 | 168 | 436 Mo |

- Le GPU reste sous 1,1 ms (vue de combat) et sous 3 ms au pire essai (premier essai du décor seul, vue chargée de relief) : comme
  le Survivant (`R_SVX1.md` : 2-5 ms à 250 monstres sur une vraie carte), il n'est pas le facteur limitant sur la machine de
  développement.
- Les unités coûtent **≈ 6,5 ms d'image en fenêtre** (9,3 contre 2,6 ms à vide) pour 2,9 ms de scripts sans rendu : ≈ 3,5-4 ms vont
  au rendu des unités côté CPU (poses des squelettes, passes d'ombre, étiquettes 3D) et à l'attente du pilote graphique sur une
  machine saturée (le processus n'occupe que 0,75-0,87 cœur en fenêtre contre 1,05-1,2 sans rendu).
- « moyenne » plus lente que « haute » au p95 (20,6 contre 15,7) : écart dans le bruit de la charge (même GPU, même CPU du rendu).

### 3.4 Effet de la charge (témoin à priorité normale)
| Réglage | image p50 / p95 / max | CPU ms/image | cœurs |
|---|---|---|---|
| `base` un cran au-dessus (série) | 4,98 / 7,55 / 37 | 5,70 | 1,05 |
| `base` priorité normale | 5,92 / **34,35** / 117 | 5,93 | 0,58 |
| `opt` un cran au-dessus (série) | 2,89 / 4,67 / 18 | 3,59 | 1,19 |
| `opt` priorité normale | 3,47 / **21,28** / 131 | 3,68 | 0,53 |

À priorité normale, le processus n'obtient qu'un demi-cœur et le p95 est multiplié par 4-5 **sans que le travail change** (le temps
CPU par image est le même à 4 % près) : les p95 / max de ce rapport sont des **bornes hautes**. Sur une machine libre, s'attendre
à des p95 plus bas et à des max sans les pics de préemption (20-50 ms ici).

## 4. Goulots et pièges identifiés

1. **Sbires `Monster` complets** : `move_and_slide`, animation à chaque image, écartement par le groupe « monsters » : 34 µs chacun et
   ≈ 1 ms de moteur en plus. Le mode « horde » du Survivant (`Monster.lite`, `lod`) divise le coût par 2,3 et suffit (les sbires
   restent sur leur voie : la collision fine ne sert à rien). **Gain majeur.**
2. **Création des modèles pendant la partie** : 1,7 ms par sbire → **une vague de 20 = 31-37 ms d'à-coup** (86 ms à 120 sbires) ;
   héros : 190-340 ms au premier chargement. **Gain majeur** : recyclage (0,11 ms) et préchargement de tous les modèles (8 héros, 2
   sbires, structures, camps) pendant l'écran de chargement ; réapparition des héros sans recréer le modèle. Même chose pour les
   effets des sorts : le premier lancer de chaque sort charge ses effets (pics de 30 ms des héros dans les premières secondes d'un
   essai court) : précharger les effets des 8 kits avec les modèles.
3. Effets de sorts + chiffres de dégâts : ≈ 0,9 ms (4-5 effets, 5-14 chiffres vivants). À tenir par les plafonds existants
   (`DamageNumber` regroupé pour les sbires, P1-20), pas à couper.
4. **Navigation : pas un goulot.** 490 polygones, `map_get_path` ≈ 40 µs, 48 chemins par seconde en `base` ; courbe de voie : même
   coût, plus simple et déterministe ; `NavigationAgent3D` + évitement pour 40 sbires : +0,2-0,3 ms (inutile : l'écartement suffit).
   Garder le maillage **précuit** (MB-B) ou cuit d'un coup avant la partie (34-270 ms), jamais en tâche de fond non attendue.
5. **Groupes (`get_nodes_in_group`) : pas un goulot à ≤ 100 unités** (0,06 ms par image pour toutes les recherches, 0,02 ms + 0,07 ms
   de construction avec une grille). La grille devient utile au-delà (0,11 → 0,21 ms de recherches à 100 sbires en `base`) et sert
   aussi l'écartement et la carte d'influence du coach (MB-G).
6. Tours, Cœurs et traits : **3-5 µs par structure** même en tirant sans arrêt ; le `Projectile` du jeu (maillage, matière et
   `OmniLight3D` neufs à chaque tir, groupes parcourus à chaque image) reste négligeable à 2-7 projectiles vivants, mais le trait
   recyclé à maillage partagé est plus sûr (0,01 ms pour 4-5 traits vivants, aucune création).
7. **Piège de MB-C** : une structure dans le groupe « monsters » fait planter `Monster._separation` (qui suppose que tout le groupe
   est un `Monster` : accès sur `null`). Les structures doivent vivre hors de « heroes » / « monsters » (ou ces boucles filtrer le type),
   et leurs dégâts passer par un chemin propre (les `Telegraph` du jeu résolvent leurs cibles par ces groupes).
8. **Piège de MB-C / MB-E** : en camps natifs, les sbires bleus doivent être dans « heroes » pour être touchés par les coups rouges ;
   alors `ClassRival._teammates()` (soins, renforts, repli) voit aussi les sbires et les structures : filtrer sur `Combatant.is_hero`.
   Côté rouge, `Monster._physics_process` ne change de cible que si le groupe en compte plus d'une (`pool.size() > 1`) : le banc
   choisit ses cibles lui-même ; MB-C doit faire de même (cible des sbires et des tours par le directeur, réévaluée toutes les 0,5 s
   décalées).
9. Mesure : `Performance.TIME_PHYSICS_PROCESS` / `TIME_PROCESS` rendent le **pire temps de la dernière seconde**, pas celui de l'image
   (inutilisables pour un p95) ; chronométrer soi-même. Sur la machine partagée, mesurer avec une priorité un cran au-dessus et lire
   le temps CPU du processus.

## 5. Parades retenues (preset `opt`, à reprendre dans le vrai code)

| Parade | Où (lot) | Effet mesuré |
|---|---|---|
| Sbires en mode « horde » (`Monster.lite`) : sans `move_and_slide`, animation à demi-cadence, écartement borné à 8 voisins | `ai/moba_minion.gd` (MB-C) | −0,7 ms de script à 40 sbires, −2 ms d'image |
| Niveau de détail : au-delà de 35 m de la caméra, une image sur 2 ; au-delà de 70 m, une sur 4 | MB-C | compris ci-dessus |
| Recyclage des sbires et des traits ; préchargement de tous les modèles au chargement ; héros réapparus sans recréation | MB-C, MB-D, MB-I | pic de vague 31-37 → 3-9 ms |
| Marche sur la courbe de voie (`Path3D`), chemin de navigation seulement en poursuite hors voie | MB-B, MB-C | ≈ 0, plus simple |
| Coup de sbire sans zone rouge (animation + coup ; le tireur lance un trait recyclé) | MB-C | −0,3 ms, et lisibilité (P1-20) |
| Cibles par le directeur, grille spatiale de 8 m refaite une fois par image (sbires, tours, héros, coach) | MB-C, MB-G | ≈ 0 à 40 sbires, prépare 100 |
| Camps endormis sans héros à 25 m (ni physique ni animation) | MB-F | −0,15 ms |
| Qualité « basse » proposée aux machines modestes (sans ombres, MSAA coupé, rendu 3D à 75 %) | MB-H / réglages | −1,4 ms d'image p50, GPU ÷ 3 |

## 6. Budgets à respecter (à vérifier par MB-J avec ce banc)

Mesurés sur la machine de développement chargée ; « machine moyenne » = processeur ≈ 2 fois plus lent par cœur, GPU ≈ 4 fois plus lent
(estimation, à confirmer sur une vraie machine).

| Poste | Budget machine de dév. | Machine moyenne (estimé) |
|---|---|---|
| Logique de l'image (scripts + moteur physique), p95 | **≤ 5 ms** (mesuré : 4,7 ms en `opt`) | ≤ 10 ms |
| Image complète en fenêtre 1600 × 900 qualité haute, décor compris, p95 | **≤ 16,6 ms** (mesuré : 15,7 ms machine saturée) | qualité « moyenne » ou « basse » proposée |
| GPU, 1600 × 900, qualité haute | ≤ 3 ms (mesuré : 0,9-1,1 ms, 3 ms au pire) | ≤ 12 ms |
| Sbires vivants | **≤ 60** (mesuré : 52 à ≤ 3,4 ms ; 99 tenus à 4,9 / 7,4 ms en `opt` : marge) | ≤ 60 |
| Un sbire (script) | ≤ 20 µs (mode « horde ») | — |
| Un héros IA (`ClassRival` + couches MOBA de MB-E / MB-G) | ≤ 150 µs (mesuré 45-75 µs sans les couches) | — |
| Une tour ou un Cœur, tirs compris | ≤ 10 µs (mesuré 3-5 µs) | — |
| Coach d'équipe (MB-G : vue, carte d'influence de 1 500 cases 2 fois par seconde) | ≤ 0,5 ms par image, étalé | — |
| Création d'objets pendant la partie | **aucun modèle** ; ≤ 2 ms de création par image (vague étalée sur plusieurs images si besoin) | — |
| Effets + chiffres vivants | ≤ 1 ms de script ; plafonds existants | — |
| Appels de dessin / mémoire vidéo | ≤ 1 000 / ≤ 1,5 Go (mesuré 350 / 575 Mo) | — |

## 7. Conséquences pour le plan de lots
- **MB-B** : carte fixe, maillage précuit (ou cuit d'un coup avant la partie), voies en `Path3D` ; décor en `MultiMesh` comme ProcMap ;
  repasser le banc avec `--decor` remplacé par la vraie carte (`scenes/moba_map.tscn`).
- **MB-C** : sbires « horde » recyclés, cibles et vagues par le directeur (pas de `Monster._hostile_pool`), structures hors des groupes
  « heroes » / « monsters », trait recyclé ; acceptation : `test_mb_lanes` + ce banc (`--preset=opt`) sous les budgets du § 6.
- **MB-D / MB-I** : préchargement des 8 kits et modèles à l'écran de chargement (création d'un héros : 190-340 ms), réapparition sans
  recréation.
- **MB-E / MB-G** : budget de 150 µs par héros IA et 0,5 ms pour le coach ; `_teammates()` filtré sur les héros.
- **MB-J** : ajouter au banc de parties IA contre IA la mesure d'image du § 6 et la refaire sur une machine moyenne (le joueur en a-t-il
  une ? sinon le profil « basse » de la machine de dév. comme garde-fou).
- Q9 (MOBA.md § 10) : `ClassRival` coûte 45-75 µs par héros : rien côté performance ne pousse vers `Player` piloté.

## 8. Limites
- Machine saturée par les autres agents pendant toutes les mesures : p95 et max sont des bornes hautes (§ 3.4) ; le temps CPU par
  image est le chiffre le plus fiable.
- Décor : celui d'une carte de Survie posé sous un sol plat (relief en partie caché, pas de buissons ni de bases habillées) ; le
  vrai décor des Deux Voies peut coûter plus (MB-B le remesurera).
- Héros nus de niveau 50 sans les couches MOBA (rôle, coach, achats) ; camps passifs (non ciblés) ; structures indestructibles ;
  Gardien et Colosse (boss de la bibliothèque) absents : à ajouter au banc par MB-F (un boss vaut quelques héros).
- Aucune mesure sur une machine moyenne : les chiffres « machine moyenne » du § 6 sont des estimations.
