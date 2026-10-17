# R_PERF1 — chargements, écran de chargement, à-coups (lot PERF-1)

Ressenti du joueur : lags, chutes d'images, et surtout des écrans qui « figent » plusieurs secondes sans rien afficher.
Ce lot mesure tous les changements d'écran et les à-coups en jeu **en fenêtre** (rendu et compilation des shaders compris),
ajoute un écran de chargement commun à TOUS les changements de scène du jeu, et corrige les pires mesures sans changer le jeu.

## Outils

- `python tools/perf_loads.py [--runs 3] [--acts survival,tower…] [--no-pages] [--shots dossier] [--warm --ud nom]` : copie propre de HEAD
  (`run_tests.preparer_copie`), lance la sonde en fenêtre, relève toutes les 25 ms le temps CPU du processus du jeu **et de son fil
  principal** (Windows : `GetProcessTimes` / `GetThreadTimes` sur le vrai processus, enfant de `Godot_…_console.exe`), note la charge
  (Godot ouverts, CPU moyen et maximal de la machine), écrit `<copie>/perf_<label>.json` et un tableau Markdown.
- `game/tools/load_probe.tscn` (sonde) : reprend le pilote de `test_p4_activities` (vraies fonctions de lancement du lobby, vraie scène,
  pilote automatique, bilan, retour) et y ajoute un moniteur d'images : durée de chaque image, images > 50 / 100 / 300 ms, compilations de
  pipelines (`Performance.PIPELINE_COMPILATIONS_*`), nœuds et ressources créés dans l'image (chargement / instanciation), temps de
  process / physique de l'image, changement de scène, « prêt » = 5 images calmes après la nouvelle scène. Phases : titre, titre -> lobby,
  première et deuxième ouverture de chaque page (12 menus Jouer, 4 sections Héros, 7 onglets Carnet, 3 Atelier, 2 Coffres,
  Paramètres, Guide, Journal), puis pour chaque activité : lancer, jeu (7 s au pilote), fin -> bilan, bilan -> lobby.
  Activités : Survie, Survivant, Donjon, Tour, Ruée, Siège, Duel (file comprise), Arène 3v3, Battle royale, Échiquier, Colisée et Assaut
  (lancés comme leur ligne de commande). MOBA absent de HEAD au moment des mesures.
- `game/tests/test_perf1.tscn` (voir plus bas).

**Méthode.** « Avant » = copie de HEAD 0.1.309 (b339134e) ; « après » = même HEAD + ce lot. Trois tours entrelacés avant / après
(avant 1, après 1, avant 2…), le 1er tour avec un cache de shaders vide (premier lancement), les deux suivants avec le cache et le
dossier utilisateur du tour d'avant (lancements suivants). Synchronisation verticale coupée et 240 images/s au plus (une image
dure ce qu'elle coûte). **Charge : 35 à 59 Godot d'autres agents ouverts, CPU de la machine à 89-100 % pendant TOUTES les mesures** :
les durées murales sont 2 à 3 fois celles d'une machine calme ; on donne la médiane des trois tours, et le temps CPU du fil
principal (moins sensible à la charge ; granularité Windows 15,6 ms) — il compte aussi les images d'attente, donc il ne baisse pas
quand une attente devient animée.

## Avant / après (médiane de 3 tours, ms)

« Prêt » = de l'action à la nouvelle scène affichée et calme ; « image max » = la plus longue image figée ; « figé » = somme des
images > 50 ms. Les images > 300 ms qui restent sont **toutes sous l'écran de chargement** (vérifié par test_perf1).

| Changement d'écran | Prêt avant → après | Image max avant → après | Figé avant → après | CPU fil principal avant → après |
|---|---|---|---|---|
| titre -> lobby (1er lobby de la session) | 5 964 → 4 737 | **5 882 → 3 404** | 5 952 → 4 654 | 3 406 → 3 188 |
| lobby -> Survie (1re carte) | 3 729 → **1 434** | **3 624 → 1 311** | 3 676 → 1 363 | 2 562 → 1 188 |
| lobby -> Survivant | 1 784 → 1 347 | 1 673 → 1 141 | 1 878 → 1 388 | 1 547 → 1 125 |
| lobby -> Battle royale | 1 979 → 1 858 | 1 898 → 1 748 | 2 054 → 1 895 | 1 453 → 1 422 |
| lobby -> Duel (file d'attente comprise, ×4) | 15 633 → 12 776 | 496 → 426 | 1 064 → 605 | 5 625 → 5 047 |
| lobby -> Donjon / Tour / Ruée / Siège | 458-542 → 517-569 | 382-505 → 409-495 | 570-656 → 577-647 | ≈ |
| lobby -> Arène 3v3 / Échiquier | 710 / 842 → 729 / 824 | 662 / 504 → 653 / 504 | ≈ | ≈ |
| bilan -> lobby (7 activités) | 305-399 → 352-443 | 305-362 → 298-364 | ≈ | ≈ |
| bilan -> lobby après l'Assaut | 1 448 → 1 031 | 1 393 → 961 | 1 446 → 1 019 | 1 359 → 938 |
| lancer Colisée / Assaut (sans écran : à brancher) | 982 / 854 → 1 510 / 1 030 | 897 / 828 → 1 327 / 982 | ≈ | 828 / 734 → 969 / 844 |

Le coût fixe de l'écran de chargement : 2 images pour l'afficher, puis 3 images calmes avant de s'effacer (+40 à 90 ms sur les
changements courts : bilans, Donjons…). Colisée et Assaut ne passent pas encore par lui (fichiers d'autres équipes) : leurs écarts
sont du bruit de mesure (machine saturée), aucun de leurs fichiers n'est touché.

| Pages et menus (1re ouverture) | Image max avant → après | Figé avant → après |
|---|---|---|
| menu Donjons (48 médaillons de boss) | 337 → 327 | **835 → 383** |
| menu Tour / Ruée / Siège / Duel (juste après Donjons) | 106 / 232 / 100 / 95 → 104 / 61 / 75 / 56 | **847 / 902 / 874 / 177 → 104 / 61 / 75 / 56** |
| Carnet > Collection | 1 094 → 1 035 (pastille « Chargement… ») | idem |
| Héros > Classe | 424 → 415 (pastille) | idem |
| Coffres > Roulette | 408 → 424 (pastille) | idem |
| menu Jouer (1re fois) | 468 → 484 (pastille) | idem |
| Héros > Cartes | 254 → 235 | 307 → 235 |
| 2e ouverture de toute page | 10-149 → 10-110 | — |

| En jeu (7 s au pilote, après l'écran prêt) | Image max avant → après | Figé avant → après |
|---|---|---|
| Arène 3v3 (1ers sorts de 6 héros) | **149 → 35** | **749 → 0** |
| Duel | 71 → 48 | 80 → 0 |
| Battle royale | 40 → 33 (pire tour 67 → 42) | 0 → 0 |
| Survie, Survivant, Donjon, Tour, Ruée, Siège, Colisée, Assaut | 26-44 des deux côtés | 0 |
| Échiquier (pilote accéléré : une manche toutes les ~0,7 s) | 410 → 395 | 14 449 → 14 786 (inchangé, voir restes) |

## L'Échiquier : le gel à l'appui sur « Prêt » (retour du joueur, priorité)

Mesure : `game/tools/ac_ready_probe.tscn` (`AC_PROBE="--rounds=10 --wait=3"`, en fenêtre, partie au pilote à vitesse normale ; à chaque
préparation on attend 3 s — les préchargements de la préparation tournent — puis Prêt ; durée de l'appel, puis chaque image pendant 2 s).
10 manches de 1-1 à 3-1 (ouverture, monstres, JcJ à 28-42 unités sur 8 plateaux, gardien), machine saturée (même charge que plus haut).

Cause réelle (instrumentée) : la fin de préparation coûte < 1 ms ; c'est `AutochessDirector.begin` qui créait **d'un bloc, dans l'image
de Prêt, toutes les unités du plateau regardé** (10 à 20 `AutochessUnit` à 25-35 ms chacune : 340-390 ms), puis 3 unités par image
pour les plateaux cachés (images de 75-270 ms) ; les monstres (manches de monstres, gardien) n'étaient pas préchargés pendant la
préparation : chaque monstre lisait son modèle dans l'image (115-245 ms). S'y ajoutent `AutochessBoard.set_enemy` (figurines et
stratège adverses, 18-98 ms) et le bandeau « Combat ! ».

Correctif (`core/autochess_director.gd` seulement) : aucune unité n'est plus créée dans `begin` ; `_physics_process` les crée au fil
des images dans un budget de 6 ms (au moins une), le plateau regardé d'abord ; ses unités restent cachées et les figurines de la
préparation restent à l'écran jusqu'au départ de son combat (`_start_arena` les échange d'un coup : rien ne « pop » une à une) ;
les fichiers de chaque unité (`unit_paths` : corps, tenues, armes ; monstres : modèle et texture tirés comme `setup_unit`) sont
demandés en tâche de fond dès `begin`, et une unité n'est créée qu'une fois ses fichiers lus. Règles, tirages et couche d'effets
inchangés ; le combat regardé démarre ~0,2-0,4 s après Prêt (pendant le bandeau « Combat ! »). Serveur sans écran : pas de lecture en
tâche de fond (comme ailleurs), seul l'étalement reste.

| Échiquier, 10 manches | Avant | Après |
|---|---|---|
| Appel « Prêt » (fin de préparation + mise en place), médiane / pire | 94 / 187 ms | **28 / 112 ms** |
| Image la plus longue dans les 2 s suivantes, médiane / pire | 205 / 480 ms | **90 / 149 ms** |
| Images > 100 ms sur les 10 manches | 19 | **4** |
| 1re image après Prêt, manches de monstres | 400-470 ms | 22-74 ms |

Objectif du coordinateur (≤ 50 ms de plus que l'image normale à Prêt, aucune image > 100 ms) : atteint pour l'appel en médiane sur machine
saturée ; restent 4 images de 110-149 ms sur 10 manches (création d'une unité déjà lue : 25-60 ms d'instanciation et de matériaux,
`set_enemy` jusqu'à 98 ms). Suite possible (fichiers d'ACX-4, non touchés) : `set_enemy` étalé ou fait pendant la préparation, réserve
d'unités recyclées d'une manche à l'autre (le coût restant est l'instanciation du modèle).

## Ce qui a été fait

1. **Écran de chargement commun** `ui/load_screen.gd` (`LoadScreen`). `LoadScreen.go(tree, scène, étapes)` et `LoadScreen.to_lobby(tree)`
   remplacent **tous** les `change_scene_to_file` du jeu (lobby : 16 lancements, titre, bilans Survie / Donjons / Tour / Duel / Royale,
   `Duel.leave`, `Royale.leave`, `Tower.leave`, Entraînement, Échiquier, entraînement de boss, bouton « Jouer ensemble » du titre).
   Voile d'encre sur l'écran courant + autocollant papier « Chargement » (pastilles qui sautent, barre de progression réelle,
   libellé de l'étape, astuce courte tirée des fiches du tutoriel), curseur d'attente du système (il tourne même pendant un calcul).
   Déroulé : affiché en 2 images (49-93 ms mesurés) -> la scène se lit **en tâche de fond** (`load_threaded_request`, la barre suit, l'animation
   continue ; un préchargement déjà lancé par le titre ou le lobby est repris) -> étapes de préparation, une par image -> changement de
   scène -> attente de 3 images calmes (6 s au plus) -> fondu. Le jeu est en pause pendant le chargement (l'ancienne scène ne joue plus,
   les touches ne passent pas) et **la pause d'avant est rendue au moment du changement** : la nouvelle scène voit le même état qu'avant.
   Un double clic pendant le chargement est ignoré ; une nouvelle demande pendant l'attente d'images calmes ouvre un nouvel écran.
   Pas d'annulation : les modes sont déjà lancés (Run, Duel…) quand le changement est demandé. Captures regardées (titre -> lobby, bilan -> monde).
2. **Titre / bilan -> lobby en 3 temps** : `MapBackdrop.prepare(zone)` (le décor de la zone, ~1 à 3 s, dans sa propre image : même map, même
   graine, reprise du cache par `show_zone`) et `Completion.armory_ids()` (catalogue de l'Atelier, 0,4-0,6 s à chaque nouvelle version)
   passent avant la scène ; le plus long bloc figé du 1er lobby passe de 5,9 s à 3,4 s (médianes, machine saturée).
3. **Pastille « Chargement… » à la 1re ouverture** d'une page (`PageScreen.show_page`, `HeroScreen.show_section`, `Lobby._show_menu`) :
   `LoadScreen.hint_first` pose la pastille et dessine l'image tout de suite (`RenderingServer.force_draw`), puis la page se construit :
   l'écran figé montre le message (Collection 1 s, Roulette 0,4 s, Classe 0,4 s, Jouer 0,5 s). Le code reste synchrone (tests inchangés).
4. **Fondu de changement de carte** (`ScreenFade.run` : portail, entrée de donjon, arène du Survivant) : pastilles « Chargement de la
   carte… » sur le noir, image affichée avant le calcul (jamais de noir muet).
5. **Cartes générées plus vite, au bit près** (`ProcMap._build_heights`, `_paint_splat`) : un camp ne salit le sol qu'à 9 m, un
   sanctuaire à 8 m, un plateau au-delà de son plus grand rayon ne change rien : on ne les teste plus partout (même ordre des opérations
   pour le reste). Mesure headless sur 5 cartes : hauteurs 150 -> 85 ms, texture de sol 290 -> 50 ms par carte (lobby, chaque carte de
   Survie, Battle royale) ; empreintes SHA-256 des hauteurs et de la texture identiques avant / après (graine globale fixée).
6. **Modèles de décor préchargés** : `ProcMap.warm_models()` garde la liste des modèles des cartes jouées (`user://warm_models.json`,
   simple cache) et les lit en tâche de fond au retour au lobby. Mesure headless (même processus) : 1re carte de Survie 6,0 s dont ~4,6 s de
   lectures de modèles, 1,4 s une fois lus. En fenêtre : lobby -> Survie 2,4 s au 1er lancement (pas encore de liste), 1,3-1,4 s ensuite
   (avant : 3,5-4,2 s).
7. **Effets des sorts préparés en tâche de fond** : `EdenFx.warm_class(classe)` (appelé à la création de chaque héros : `Player._ready`,
   `ClassRival.setup`) lit .fx.json, .glb et textures des sorts de la classe sur `WorkerThreadPool` ; `_load` reprend le résultat tel quel
   (sinon son chemin habituel). Arène 3v3 : plus aucune image > 50 ms au premier sort (avant : jusqu'à 149 ms, 110-135 ressources lues
   dans l'image, 0,75 s figées sur 7 s).
8. **Médaillons de boss** (`BossPortrait`) : modèle et texture demandés en tâche de fond dès la demande (la page Donjons en demande 48) :
   les 4 à 5 s d'images de 80-100 ms après l'ouverture de la page disparaissent.
9. Serveur sans écran (tests, CI) : les préparations en tâche de fond (effets, modèles) sont coupées — son rendu factice ne crée pas de
   maillages hors du fil principal (un plantage observé une fois après 15 activités de `test_p4_activities`, non reproduit ensuite).

## test_perf1 (non-régression)

1. Structure : aucun script du jeu ne change de scène hors de `LoadScreen` (exceptions : titre lancé avec des arguments ou `--host/--join`,
   et les fichiers d'autres équipes listés « À BRANCHER », signalés sans échec).
2. Parcours réel : titre -> lobby, 1res ouvertures des pages lourdes, lobby -> Survie, carte suivante (fondu), abandon -> bilan -> lobby ;
   chien de garde : **toute image de plus de 300 ms pendant une action doit avoir un indicateur à l'écran** (écran de chargement ouvert au
   début de l'image, pastille posée pendant l'image ou fondu de carte). Vert : les 8 à 13 images > 300 ms relevées selon la charge sont toutes annoncées.
3. Pastilles posées à chaque 1re ouverture, aucune à la 2e ; pause tenue pendant le chargement ; voile affiché en moins d'une seconde.

Non-régression sur la copie « après » : 60 tests (p2, hud, hud2, nav_screens, pages, uik0, uik2, royale, sv1-sv9, svx1-3, m2, m3, m6, m7,
ac_ui, ac_rewards, ac_board, p4_flow, p4_activities, p18_modes, perf1, controls, build, progress, dng1-3, farm, tower, results,
duel_modes, siege, p13, co_c, tac1-3, br4, c1, gx6, h3, a2…). Rouges aussi sur HEAD sans ce lot : `test_bri3` (chiffres sobres),
`test_hub1` (pastille du mode dev) ; `test_p15` instable (angles d'arrivée au hasard, vert au 2e passage).

## Restes, classés (pire d'abord)

1. **Échiquier** (voir la section dédiée : gel de Prêt traité) : restent `set_enemy` (jusqu'à 98 ms dans l'image de Prêt), 25-60 ms par
   unité créée (une par image), et en fin de manche la libération de ~2 000 nœuds d'un coup ; piste : réserve d'unités recyclées.
2. **1er lobby de la session** : encore 3,4 s d'un bloc sur machine saturée (≈ 1,3 s calme), sous l'écran de chargement : `Lobby._ready`
   construit tous les écrans d'un coup (Héros 90-140 ms, pages de l'Atelier, Carnet…) + modèle du héros 110-220 ms + ~200 pipelines au
   1er rendu. Piste : écrans construits à la 1re ouverture ou une image chacun après l'affichage (touche aux tests qui lisent
   `lobby._archive` tout de suite), décor généré sur un fil (ProcMap n'est pas prévu pour : risqué).
3. **1re carte de Survie au tout premier lancement** (sans `warm_models.json`) : 2,4 s ; liste de modèles livrée avec le jeu ou
   préchargement dès le titre. Les PNJ du village (`_build_merchants`, 240-290 ms) et le modèle du héros (300 ms) ne sont pas préchargés.
4. **Pages lourdes** (maintenant annoncées) : Collection 1 s à la 1re ouverture (120 cases, 85 textures lues), Héros > Classe 0,4 s,
   Roulette 0,4 s, menu Jouer 0,5 s : textures à lire en tâche de fond / cases recyclées.
5. **Shaders** : 150-330 compilations de pipelines à chaque 1er affichage d'une scène (cache disque de Godot ensuite) ; les effets de sorts
   compilent encore leurs pipelines « mesh » à la 1re apparition (5-15, sans à-coup mesurable grâce aux ubershaders) ; un échauffement
   (effets instanciés hors champ pendant l'écran de chargement) reste possible.
6. Après le fondu de changement de carte, une image de ~0,5 s a été vue une fois en headless (hors fondu) : à surveiller (navigation
   ou première vague).
7. `ProcMap._place_pois` lit le hasard global (`randf`) : une même graine ne donne pas toujours la même carte (constaté en vérifiant les
   empreintes) ; sans effet sur ce lot.
8. `l210_ec2bc2.glb` : UID de texture périmé (déjà noté en P2), réimport par la session locale.

## À l'attention des autres équipes

- **Colisée, Assaut, MOBA, Mode amis** : remplacer `get_tree().change_scene_to_file(…)` par `LoadScreen.go(get_tree(), scène)` (et
  `LoadScreen.to_lobby(get_tree())` pour le retour au lobby) dans `colisee_page.gd:63`, `colisee_director.gd:547`,
  `assault_director.gd:1067/1072`, `moba_director.gd` (retour et Rejouer), `world/net_arena.gd:322`. `test_perf1` les signale « À BRANCHER » ;
  tout nouveau `change_scene_to_file` hors de cette liste fait échouer le test.
- Lancement d'un mode dont la 1re image est longue : passer les préparations en étapes (`LoadScreen.go(tree, scène, [["libellé", callable]])`)
  ou en tâche de fond (`EdenFx.warm_class` pour les héros, `ResourceLoader.load_threaded_request` pour les modèles).
- Les mesures de ce lot ont été faites avec 35 à 59 Godot ouverts en parallèle : une partie du ressenti « lag » du joueur peut venir de là.
