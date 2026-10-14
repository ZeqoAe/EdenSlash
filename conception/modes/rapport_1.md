# Équipe Nouveaux modes — rapport 1 (jeu 0.1.130)

Périmètre : les modes de jeu existants (Survie, Tour, Duel, Zone d'entraînement), les modes annoncés
« Bientôt » (Donjons, Arènes 2v2 / 3v3, Champ de bataille 10v10), les nouvelles idées, et la place
des cerveaux d'IA (adversaires, alliés). L'équipe pilote l'ajout n°4 du joueur (**beaucoup de
mini-jeux et d'activités, chacun avec son intérêt**) et donne son avis sur les ajouts 1, 2, 3 et 5.

Tout est lu dans le code (le code fait foi). Godot n'a pas été lancé : les chiffres viennent des
formules et des constantes du code. Les rapports Progression et Builds ont été lus pour ne pas faire
doublon : nous renvoyons à leurs numéros (P1 à P9, B1 à B13) quand c'est leur sujet.

---

## En bref

**5 constats**
1. **Seule la Survie a une vraie boucle.** La Tour rapporte peu (des objets d'étage, un record, de la
   maîtrise), le Duel ne rapporte rien (un compteur de victoires) et sert surtout de **banc d'essai**
   (éditeur d'adversaire, multiplicateurs de PV et de dégâts, choix du cerveau). L'entraînement ne
   rapporte rien, et c'est voulu.
2. **La moitié du menu Jouer est vide** : 4 activités sur 8 sont « Bientôt ». Le Champ de bataille
   10 contre 10 n'est **pas réaliste** avec le moteur actuel (IA à une cible, cerveaux à ~5 ms la
   décision, aucun allié). Les Donjons, eux, sont aux trois quarts prêts : les 8 donjons d'Eden, leurs
   boss et une quinzaine de mécaniques de boss existent déjà.
3. **Il n'existe aucune activité courte.** Une Survie dure 30 à 45 min (3 cartes de 10 min, la rage et
   3 boss) et la Tour se joue en longues ascensions sur une seule vie. Rien ne se joue en 5 à 10 min,
   et rien ne change d'un jour à l'autre (pas de rotation ni de défi).
4. **Ajouter un mode coûte cher aujourd'hui.** Chaque mode est câblé à la main par des
   `if Training.active / Tower.active / Duel.active` dans `world.gd` (12 tests), `run_director.gd`
   (8), `hud.gd`, `pause_menu.gd`, `results_screen.gd`… Avant de multiplier les activités, il faut un
   **socle commun**.
5. **La Survie contient déjà 7 « mini-jeux »** : enclume, autel du scribe, fontaine, pierre d'aimant,
   autel de cupidité, stèle du défi et **autel de la fortune** (la pyramide de 8 étages demandée par
   le joueur en 0.1.116 est faite : `core/fortune.gd`). C'est la façon la moins chère d'ajouter de la
   variété.

**Propositions phares** : M0 socle « activité » et profil de règles par mode (**M**) · M1 Défis :
Défi du jour, Épreuves de maîtrise, Ruée des boss (**S à M chacun**) · M2 Donjons à partir des
8 donjons d'Eden (**M**) · M3 Tour : reprise sans piège, étages-épreuves, rôle de joaillerie (**S à M**)
· M4 Duel classé (Ligue puis Panthéon des cerveaux) à côté du Duel libre (**M**) · M5 nouveaux
événements de Survie (**S chacun**) · M6 Arènes avec alliés IA, plus tard (**L**) ; le Champ de
bataille retiré du menu ou remplacé.

---

## 1. État des lieux

### 1.1 Comment un mode est branché aujourd'hui

| Étage | Où | Ce qu'il fait |
|---|---|---|
| Fiche de l'activité | `ui/activities.gd:LIST` | id, groupe (JcE / JcJ / aucun), nom, sous-titre, description, `soon` ; image `assets/ui/activities/<id>.jpg` |
| Page du lobby | `ui/lobby.gd:_show_menu` → `_menu_survival`, `_menu_tower` / `_menu_tower_floors`, `_menu_duel`, `_menu_training`, `_menu_soon` | réglages, puis Lancer |
| État du mode | classes statiques `Tower`, `Duel`, `Training` (`core/`) ; la Survie : `Run.start_survival` | `start()`, règles, `finish()` / `leave()` |
| Déroulé en jeu | `core/run_director.gd:start` branche un « directeur » : `DuelDirector`, `TowerDirector` ; sinon la grande carte de la Survie | salles, vagues, objectifs, `objective_text()` |
| Cas particuliers | `core/world.gd` (12 tests de mode : abandon, mort du héros, cartes de départ, montée de niveau…), `run_director.gd` (8), `hud.gd`, `pause_menu.gd`, `grimoire.gd`, `combatant.gd`, `pvp_caps.gd` | chaque mode ajoute ses `if` |
| Bilan | `results_screen.gd` (Survie), `tower_results.gd`, `duel_results.gd` | — |
| Sauvegarde | Tour, Duel, Entraînement : **la sauvegarde n'est pas écrite pendant le mode, elle est rechargée à la sortie** (`Profile.load_profile()` dans `finish` / `leave`), puis les gains sont ajoutés | les records gagnés pendant le mode sont perdus (voir Progression, P1g) |

Tests : `test_farm` (Survie) et `test_pvp` (duel) existent ; **pas de test de la Tour**.

### 1.2 Survie (le cœur du jeu)

- **Lancement** : `Run.start_survival(cid, époque)` ; départ sans équipement, arme de la classe au
  choix entre ses 2 variantes (`run_director.gd:start_weapon_cards`).
- **Époques** (`core/epochs.gd`) : 4 époques × 3 cartes ; niveau plafonné à 15 / 25 / 35 par carte ;
  monstres × 1 / 1,35 / 1,75 / 2,2 selon l'époque ; battre le boss de la 3e carte ouvre l'époque suivante.
- **Une carte** (`run_director.gd`) : 10 min (`RUN_TIME = 600`), puis la rage ; 3 sceaux portés par
  les gardiens d'élite ouvrent le donjon, qui mène à l'arène du boss (mécaniques de `BossBrain`) ; un
  portail mène à la carte suivante. Extraction possible (10 s à survivre). Une seule résurrection.
- **Lieux de la carte** (`world/proc_map.gd`, `Interactable.STATION_VERBS`) : 3 enclumes, 2 autels
  du scribe, 3 fontaines, 2 pierres d'aimant, 1 autel de cupidité, 2 stèles du défi, 1 autel de la
  fortune ; plus les sanctuaires à capturer, les marchands ambulants, les camps d'élite, les objets à
  casser et les ~30 coffres payants (coffres d'emplacement).
- **Gains** : maîtrise, insignes, pièces vues (Armurerie), coffre d'apparence par boss, fournitures si
  victoire ou extraction, époque suivante (détails : Progression, 1.3).
- **Durée** : ~30 à 45 min pour une run complète.

### 1.3 La Tour (`core/tower.gd`, `core/tower_director.gd`, `ui/tower_pages.gd`)

- 200 étages, 4 difficultés (Facile → Hardcore : monstres × 0,7 / 1 / 1,3 / 1,6 et IA des duellistes),
  **une seule vie**, un record par difficulté. On peut repartir de n'importe quel étage déjà battu.
- Types d'étage (`default_type`) : boss tous les 10 (**20 étages**), duel un étage sur 3
  (**60 duels, un par classe**, ordre fixe tiré une fois, graine 2026), élite tous les 5 (**14**),
  vagues de monstres (**106**). Décor : une zone d'Eden tous les 25 étages, donc **chacun des 8 boss
  revient 2 ou 3 fois** (avec 30 % de ses PV de donjon, `boss_hp = 0.3`).
- Héros : niveau = 1 + 0,5 × (étage − 1) (niveau 100 à l'étage 200) ; il part avec le **préréglage
  d'équipement** de sa classe (c'est le seul mode où l'équipement du hub compte vraiment) ; **une
  carte de départ** (`world.gd`, `Run.roll_cards(6).pick_random()`), puis **une carte par étage
  vidé**. Pas de coffre d'emplacement, pas de trophée, pas d'enclume.
- Coffre d'étage : un objet (commun à épique ; mythique ou légendaire aux étages de boss), équipé
  s'il est meilleur, gardé dans le coffre commun à la fin, **gagnée ou perdue**.
- Duellistes : `ClassRival` (l'IA scriptée de l'entraînement) avec 45 % de ses PV, un équipement
  généré et 1 à 4 sorts ; **pas de règles JcJ** (`PvpCaps.active()` ne vaut que pour le Duel).
- Gains (`Tower.finish`) : objets → coffre commun ; record ; coffre d'apparence aux étages 50 / 100 /
  150 / 200 (une fois par difficulté) ; maîtrise = (étages gravis × 12 + monstres ÷ 3) × 0,75 à 1,6.
- Mode dev : tout se règle étage par étage (`ui/dev_tower.gd`, `data/dev_edits.json` → `tower`).

### 1.4 Le Duel (`core/duel.gd`, `core/duel_director.gd`, `ui/duel_prep.gd`, `ui/profile_editor.gd`)

- 1 contre 1, 2 manches gagnantes, arène à piliers (zone `arid`), 3 s de compte à rebours.
- **Inscription** (`Duel.requirements`) : preset de sorts à 4 cases, tous les points de talent
  dépensés, certificats posés, arme et 5 pièces d'armure, tenue portée. Niveau du duel = celui de
  l'équipement porté (`gear_level`, 10 au moins).
- **Adversaire** : une classe au choix ; IA scriptée (`ClassRival`, 4 difficultés) **ou** un cerveau
  (`MlDuelPilot.BRAINS` : Débutant, Facile, Normal, Difficile, Hardcore, Le plus récent) ; équipement
  « copie du tien » (par défaut), « généré à ton niveau » ou « build opti de sa classe » ; préparation
  rapide (PV ×, dégâts ×, sorts choisis) ou adversaire de l'éditeur (`RivalBuilds`).
- **Règles JcJ** (`combat/pvp_caps.gd`) : échelle des dégâts (1,2 % des PV par multiplicateur 1),
  défense relative, soins × 0,35, acharnement (dégâts × 2 toutes les 20 s après 30 s), plafonds de
  stats, auto-attaque réduite et sans contrôle. Cible : 30 s à 1 min 30 par manche.
- **Gains** : `duel_wins` et `duel_win_<classe>_<difficulté>`, rien d'autre (ni maîtrise, ni objet).
- Lecture : le Duel est aujourd'hui **un outil** (banc d'essai de builds et d'IA) plus qu'un mode avec
  un objectif.

### 1.5 La Zone d'entraînement (`core/training.gd`, `ui/training_panel.gd`)

Carte de la zone choisie, sans minuterie ni vagues ; panneau F3 (niveau, sorts, cartes, recharges,
ennemis invincibles ou passifs, monstres au choix, mannequin), compteur de DPS. Rien n'est gagné ni
perdu. **Fini et sain** ; c'est la base naturelle d'un tutoriel et d'épreuves (voir M1).

### 1.6 Les activités annoncées (« Bientôt », `_menu_soon`)

| Activité | Ce qui existe déjà | Ce qui manque |
|---|---|---|
| **Donjons** | les **8 donjons d'Eden** (`data/zones.json` → `dungeon` : Mine d'Andrew V., Antre de la sorcière, Repaire des Vileshark, Marais maudit, Cœur du volcan, Fosse du fourmilion, Laboratoire de Pross, Trône du roi sorcier) ; leurs boss et leurs mécaniques (`ai/boss_brain.gd` : renforts, flaques, clones, lasers, piétinement, totems, météores, vortex, familier, miroir, plus les coups de base) ; la salle d'arène (`world.new_arena_map`) ; le modèle de directeur de la Tour | l'enchaînement de salles, les règles de puissance, le butin propre (pièces ciblées, plans) |
| **Arène 2v2 / 3v3** | les héros ennemis pilotés (`Player` avec `foe = true` + `MlDuelPilot`) ; un cerveau déjà entraîné contre **2 adversaires** (préréglage `duo` de `ml_arena.gd`) ; les équipes `Team.PLAYER` / `Team.MONSTER` | **des alliés** : `Monster` et `ClassRival` ne visent que `_player` (le premier du groupe « player », `monster.gd:74`, `class_rival.gd:199`) ; le cerveau ne voit que **l'adversaire le plus proche** et **aucun allié** (`_obs_for`, observations figées) : il ne peut ni soigner un allié ni se coordonner |
| **Champ de bataille 10v10** | rien de plus | tout ce qui manque aux arènes, plus : 19 héros pilotés (à ~5 ms par décision toutes les 3 images, ~30 ms par image avec des cerveaux : injouable à 60 images/s), une grande carte alors que le cerveau ne connaît qu'une arène de 15 m de rayon, des objectifs que l'IA ne sait pas jouer |

### 1.7 Les cerveaux d'IA aujourd'hui

- 6 cerveaux (`game/data/cerveaux/`, **hors git**, ~2 Mo chacun), entraînés **au niveau 10, sans
  équipement**, contre l'IA scriptée ; un seul cerveau joue les 60 classes.
- Utilisés à un seul endroit : le menu Duel, en libre accès, sans condition ni récompense.
- Limites dures (contrainte du brief) : nombre et ordre des observations figés. Le cerveau voit un
  adversaire, des positions relatives au centre d'une arène, ses propres recharges et états. Il ne voit
  pas d'allié. Toute nouvelle utilisation doit donc se faire **en 1 contre 1 ou 1 contre 2 dans une
  arène**, ou accepter un comportement « chacun pour soi ».

### 1.8 Ce qui se débloque, mode par mode

| Mode | Ouvert | Se débloque dedans | Ce qu'il rapporte au hub |
|---|---|---|---|
| Survie | d'emblée (époque I) | époques II à IV (boss de la 3e carte) | maîtrise, insignes, pièces vues, apparences (boss), fournitures (si victoire) |
| Tour | d'emblée, 4 difficultés | étage suivant (record + 1) | objets d'étage, apparences (50 / 100 / 150 / 200), maîtrise |
| Duel | d'emblée, si le build est complet | rien | compteur de victoires |
| Entraînement | d'emblée | rien | rien |
| Donjons, Arènes, Champ de bataille | non jouables | — | — |

### 1.9 Fini, à moitié fait, mort, incohérent, docs obsolètes (modes)

- **Fini et sain** : boucle de Survie, lieux de la carte, autel de la fortune (note du joueur faite),
  directeur de la Tour et son éditeur, Duel et ses règles JcJ, entraînement, pilote des cerveaux.
- **À moitié fait** : la Tour (rôle et gains maigres, voir 2) ; le Duel (aucun objectif) ; les
  4 activités « Bientôt ».
- **Pièges et incohérences**
  1. **Reprendre la Tour haut = build vide.** On peut repartir de l'étage 150, mais les sorts et
     passifs ne viennent que des cartes : **une seule carte de départ**, puis une par étage. Le héros
     de l'étage 150 a donc 1 carte face à des étages pensés pour ~150 cartes. La reprise est un piège.
     (À vérifier en jeu : si la carte de départ n'est pas un sort, le héros part sans sort.)
  2. **Deux règles de 1 contre 1** : les duels de la Tour (ClassRival à 45 % de PV, sans `PvpCaps`) et
     le Duel (`PvpCaps`). Le joueur apprend deux durées de combat différentes.
  3. Description de la Tour (`activities.gd`) : « avec une arme de base » est faux, elle part avec le
     préréglage d'équipement.
  4. Le Duel copie ton équipement par défaut (`GEAR_COPY`) : l'équipement du hub n'y compte pas, alors
     que `DESIGN.md` le présente comme fait pour le « JcJ non normalisé ».
  5. Le Duel ne donne aucune maîtrise, la Tour si : jouer une classe en Duel ne la fait pas progresser.
- **Docs obsolètes** (modes) : `DESIGN.md`, « Déroulement d'une run (10 minutes + rage) » parle
  encore de « victoire ou défaite → lobby » sur une seule carte et du village ; « Boucle de jeu et
  Survie » parle du « JcJ non normalisé » qui n'existe pas. Aucune section de `DESIGN.md` ne décrit la
  Tour ni le Duel (seuls `CLAUDE.md` et les en-têtes de code le font).

---

## 2. Problèmes et opportunités (du plus important au moins important)

1. **Une seule activité a une raison d'être jouée.** La Tour et le Duel n'ont ni rôle propre ni gain
   qui compte au hub ; le joueur n'a aucune raison d'y retourner une fois la curiosité passée.
   *Opportunité* : l'idée du joueur, **un type de gain par activité** (Survie : fortification ; Tour :
   joaillerie et polissage ; Donjons : pièces ciblées et plans), reprise par Progression (P5), donne à
   chaque activité sa place. Nous la prenons comme règle de tous les modes, nouveaux compris.
2. **Pas de format court ni de renouvellement** (ajout n°4). Il manque des activités de 2 à 10 min et
   quelque chose qui change d'un jour à l'autre. *Opportunité* : la graine de run (`Run.seed`), la
   zone d'entraînement, les 8 boss et les lieux de la Survie permettent des défis courts **sans
   nouveau moteur**.
3. **Promesses affichées impossibles** : le Champ de bataille 10v10 (et, dans une moindre mesure, les
   arènes) est annoncé alors que l'IA ne connaît ni allié ni grande carte. Mieux vaut un menu
   honnête que 4 cases grises.
4. **Coût d'ajout d'un mode** : sans socle commun, chaque activité ajoute une dizaine de `if` répartis
   dans 8 fichiers, avec des oublis possibles (records perdus, mort du héros, cartes de montée de
   niveau, abandon). Multiplier les mini-jeux sans ce socle multiplierait les bogues.
5. **La Tour a des pièges de conception** : reprise haute avec un build vide, boss répétés 2 ou 3 fois,
   106 étages de vagues presque identiques, une seule vie sur une ascension de plusieurs heures.
6. **Le Duel n'a pas d'objectif** : pas d'échelle, pas de récompense ; les cerveaux sont un simple
   choix de liste. *Opportunité* : la fin de jeu voulue (« battre les cerveaux ») y trouve sa place
   naturelle (Panthéon, Progression P8).
7. **Le savoir-faire « hard to master » n'est jamais testé pour lui-même** : aucune activité ne
   demande d'enchaîner des annulations parfaites ou de sauter les ondes ; l'entraînement est un bac à
   sable sans objectif. *Opportunité* : des épreuves courtes, qui servent aussi de tutoriel (ajout n°1).
8. **Les 8 donjons et une quinzaine de mécaniques de boss ne se rejouent pas pour eux-mêmes** : on ne les voit
   qu'au bout d'une carte de Survie de 10 min ou affaiblis à 30 % dans la Tour.

---

## 3. Propositions

Coût : **S** (quelques heures), **M** (une session), **L** (plusieurs sessions). Les propositions
phares sont marquées ★.

### ★ M0 — Socle « activité » et profil de règles par mode (M, à faire en premier)

- **Intérêt pour le joueur** : indirect mais réel : chaque nouvelle activité arrive plus vite et sans
  bogue de fin de partie (records perdus, mauvaise fin, mauvaise carte proposée).
- **Règles** :
  - une fiche par activité dans `Activities.LIST`, complétée de : `mode` (script), `unlock`
    (condition, lue par le « fil d'éveil » de Progression P2), `gains` (texte court affiché sur
    l'étiquette : « Fournitures de fortification »), `duration` (« ~10 min »), `rules` (profil de
    règles) ;
  - un script de mode qui expose les mêmes points d'entrée : `start`, directeur de jeu, `on_hero_down`
    (une vie, résurrection, manche perdue…), `on_level_up` (cartes ou non), `cards_at_start`,
    `finish` (gains), `keeps_records` ; `world.gd` et `run_director.gd` appellent le mode actif au lieu
    de tester `Tower.active`, `Duel.active`… ;
  - **profil de règles du mode** (ajout n°3) : un dictionnaire par mode, au même endroit, comme
    `pvp_caps.gd` aujourd'hui : force des monstres, plafonds JcJ oui / non, soins reçus, résurrections,
    source des sorts (cartes / preset), source de l'équipement (aucun / préréglage / copie),
    niveau (normalisé / fixé), durée cible ;
  - les records gagnés pendant un mode sont toujours gardés (règle commune, corrige Progression P1g).
- **Touche** : `activities.gd`, `world.gd`, `run_director.gd`, `hud.gd`, `pause_menu.gd`,
  `tower.gd`, `duel.gd`, `training.gd`, nouveau `core/modes.gd` (ou équivalent). Aucun changement de
  comportement visible : c'est un rangement.
- **Dépendances** : Équilibrage (contenu des profils), Progression (champ `unlock`), Interface
  (étiquette : gains et durée).

### ★ M1 — Les Défis : 3 activités courtes qui réutilisent l'existant (S à M chacune)

Nouvelle rangée **« Défis »** dans le menu Jouer, entre Aventure et Affrontements. Ce sont les
premiers mini-jeux de l'ajout n°4 : courts, rejouables, chacun avec son intérêt et son gain.

**M1a — Défi du jour (S-M)**
- **Intérêt** : une partie de 10 min qui change chaque jour, qui sort le joueur de son build habituel
  et lui donne une raison de lancer le jeu.
- **Règles** : une seule carte de Survie (10 min + boss), avec **une graine fixée par la date**
  (`Run.seed` existe) : même carte, même classe imposée (tirée parmi les classes débloquées, ou au
  choix parmi 3), et **2 modificateurs** tirés dans une liste (« projectiles doublés, soins réduits de
  moitié », « élites partout », « pas d'enclume mais coffres moins chers », « une vie, dégâts × 1,5 »…).
  Le niveau et la puissance sont normalisés comme en Survie. Une tentative récompensée par jour
  (on peut rejouer pour le score). Un **Défi de la semaine** plus dur sur 3 cartes, plus tard.
- **Gains** : insignes (× 1,5 d'une run de même durée), un **cosmétique de rotation** (teinte d'aura,
  cadre de badge) pour 7 défis réussis, score personnel (meilleur temps, monstres) ; compte pour les
  succès (Progression P4).
- **Touche** : `run.gd:start_survival` (graine, 1 carte), `run_director.gd` (modificateurs, via le
  profil de M0), page du lobby. **Dépendances** : Équilibrage (liste des modificateurs), Builds
  (modificateurs qui poussent un axe B2), Interface.

**M1b — Épreuves de maîtrise (S-M)**
- **Intérêt** : apprendre et prouver le « hard to master » (saut, esquive, annulation parfaite,
  enchaînements) en 1 à 3 min ; c'est aussi **le tutoriel interactif** (ajout n°1).
- **Règles** : une liste d'épreuves dans la zone d'entraînement (`Training`), chacune avec un but
  chronométré et 3 médailles (bronze, argent, or) :
  « 10 annulations parfaites en 60 s », « esquiver 30 attaques annoncées sans être touché »
  (`telegraph.gd`), « sauter 5 ondes de choc du boss », « vaincre le mannequin en 20 s avec la classe
  imposée », « 3 enchaînements parfaits d'affilée » (si la zone dorée de Builds B7 est retenue),
  « vaincre le duelliste Normal sans sort »… Les premières épreuves (déplacement, esquive, saut,
  auto-attaque, sort, enchaînement) **forment le tutoriel** ; « passer » les valide sans médaille.
- **Gains** : titres et succès, et **cartes à débloquer** liées au geste (Builds, section 7 : « succès
  liés à l'axe »), jamais de puissance brute.
- **Touche** : `training.gd`, `training_panel.gd`, nouveaux records (`Profile.records`), page du
  lobby. **Dépendances** : Interface (tutoriel, médailles), Builds (B7, cartes débloquées),
  Progression (succès P4).

**M1c — Ruée des boss (S-M)**
- **Intérêt** : rejouer les 8 boss d'Eden et leurs mécaniques **pour elles-mêmes** (on ne les voit
  qu'au bout d'une carte), en ~12 min, avec un chrono.
- **Règles** : les boss d'une époque (3) ou les 8, à la suite, dans l'arène des donjons, à pleine
  vie ; le build est tiré comme en Survie mais **accéléré** : niveau fixé, 6 cartes au départ puis
  3 cartes entre deux boss, un coffre d'emplacement par boss. Une résurrection. Chrono et classement
  personnel par classe.
- **Gains** : un **souvenir de boss** (apparence ou titre propre à chaque boss, la 1re fois), cristaux.
- **Touche** : directeur sur le modèle de `TowerDirector` (salle, `_spawn_boss`, `BossBrain.setup`),
  page du lobby. **Dépendances** : Équilibrage (PV des boss hors Survie), Progression (souvenirs dans
  la collection).

### ★ M2 — Les Donjons (M, première nouvelle activité « longue »)

- **Intérêt** : l'activité d'Eden par excellence : un donjon nommé, des salles, un vrai boss à
  mécaniques, et un **butin choisi** (la note du joueur : pièces mythiques, légendaires, éveillées
  selon le niveau, et parfois un plan de fabrication). C'est la source des pièces **ciblées** qui
  manque à la collection (Progression P5).
- **Règles** :
  - **8 donjons**, un par zone (ceux de `zones.json`). Le donjon d'une zone **s'ouvre quand on a battu
    son boss en Survie** (le joueur le découvre en jouant, au lieu d'une condition abstraite) ;
  - **3 niveaux de difficulté** par donjon : Normal (niveau de la zone), Héroïque, Mythique (niveaux
    plus hauts, butin légendaire puis éveillé) ;
  - **déroulé de 8 à 12 min** : 3 ou 4 salles enchaînées (vagues ; salle d'élites ; salle à pièges avec
    les zones au sol de `hazard.gd` ; salle de repos avec un marchand ou une enclume), puis le boss à
    pleine force avec toutes ses mécaniques ;
  - **puissance** (question au joueur, deux options) :
    - *A, recommandée* : **l'équipement du hub** (préréglage, comme la Tour), ramené au niveau du
      donjon (puissance des objets au niveau du donjon), avec les sorts du preset et quelques cartes
      de run (une par salle). Le hub, l'Armurerie et la forge servent enfin à quelque chose hors de la
      Tour ; c'est le fonctionnement d'Eden ;
    - *B* : départ à zéro comme la Survie (mini-Survie). Plus simple, mais fait doublon avec la Survie
      et la Ruée des boss ;
  - **butin** : à chaque boss vaincu, **une pièce de la panoplie du donjon** (pièces d'Eden de la zone,
    rareté selon la difficulté), au choix parmi 2 ; des **éclats de donjon** ; et, rarement (~10 %),
    un **plan de fabrication** ;
  - **plans de fabrication** (note du joueur) : un plan = la recette d'un objet de la collection (une
    pièce d'Eden de la panoplie du donjon, ou une apparence) ; il se range dans un carnet de plans et
    se fabrique à la forge du hub contre des éclats, des cristaux et des insignes. Les plans sont la
    **voie ciblée** vers la collection : on sait quel donjon refaire pour quel objet.
- **Touche** : nouveau directeur (modèle `TowerDirector`), `boss_brain.gd` (réutilisé tel quel),
  `zones.json` (panoplie par donjon : à préparer par la session locale avec le catalogue d'Eden),
  `rewards.gd`, `forge.gd` / `craft.gd` (fabrication), page du lobby, carnet de plans.
- **Dépendances** : Progression (P5, déblocage, carnet de plans dans la collection), Équilibrage
  (niveaux, profil « Donjon », coût de fabrication), Builds (cartes de run en donjon : B2 et B3
  s'appliquent), Interface (page du donjon, carnet de plans).
- **Coût** : M pour le mode avec l'option A ; +S pour les plans ; la panoplie par donjon demande la
  session locale.

### M3 — La Tour : corriger les pièges, varier les étages, lui donner son rôle (S à M)

- **Intérêt** : faire de la Tour le défi de **puissance** (le seul mode où l'équipement du hub compte
  pleinement) et la source de **joaillerie** (note du joueur : gemmes, enchantements, pierres pour
  polir et réforger).
- **Règles** :
  - **reprise sans piège (S)** : partir de l'étage N donne d'emblée **N ÷ 5 cartes** (au moins les
    4 sorts du preset), ou les sorts du preset comme le Duel (`Run.fill_from_preset`) ; la carte de
    départ est toujours un sort ;
  - **paliers de sauvegarde (S)** : on ne repart que d'un étage en x1 (1, 11, 21…), pour que la
    reprise ait du sens et que la difficulté monte par blocs de 10 étages ;
  - **étages-épreuves (S-M)** : une partie des 106 étages de vagues devient des épreuves qui
    réutilisent les mini-jeux : « survivre 45 s à une horde », « protéger le cristal », « tuer l'élite
    marquée avant 30 s », « sol piégé » (hazards), « course à l'escalier ». Une épreuve tous les 5 étages
    environ ; les vagues simples restent majoritaires ;
  - **boss** : 20 étages de boss pour 8 boss ; aux étages 100 à 200, les boss reviennent **avec une
    mécanique en plus** (empruntée à un autre boss), pour que la 3e rencontre ne soit pas une redite ;
  - **duels** : les 60 duellistes restent l'identité de la Tour ; aux étages 50, 100, 150, 200, le
    duelliste est **piloté par un cerveau** (Débutant, Normal, Difficile, Hardcore), un avant-goût du
    Panthéon (M4) ;
  - **gains** (accord avec Progression P5) : coffre du joaillier aux étages de boss (la 1re fois par
    difficulté), cristaux par étage gravi, pierres de polissage et de réforge aux étages-épreuves ;
    les apparences de palier sont **annoncées** dans la page des étages ;
  - **trophées en Tour** : un choix de trophée tous les 10 étages (après le boss), pour que la Tour
    profite de la refonte 0.1.130 comme la Survie (question à Builds).
- **Touche** : `tower.gd` (types d'étage, reprise, gains), `tower_director.gd`, `tower_pages.gd`,
  `world.gd` (cartes de départ), `boss_brain.gd` (mécanique en plus).
- **Dépendances** : Progression (P5), Équilibrage (quantités, force des boss renforcés), Builds
  (trophées en Tour), Interface (étages-épreuves dans la page des étages).

### ★ M4 — Le Duel en deux : Duel libre et Duel classé (Ligue, puis Panthéon) (M)

- **Intérêt** : le Duel garde son rôle de banc d'essai (le joueur s'en sert pour régler ses builds),
  et gagne un **objectif** : monter une échelle jusqu'aux cerveaux, la fin de jeu voulue.
- **Règles** :
  - **Duel libre** : le Duel actuel tel quel (éditeur, préparation rapide, choix du cerveau), sans
    récompense. Ouvert tôt ;
  - **Duel classé**, une **Ligue** de 5 rangs : Bronze (IA scriptée Facile), Argent (Normal), Or
    (Difficile), Platine (Hardcore), puis le **Panthéon** des cerveaux (Progression P8 : Débutant →
    Champion, à battre dans l'ordre). Chaque rang : 5 adversaires de classes tirées au hasard, à battre
    en 2 manches gagnantes ; l'adversaire prend le **build opti de sa classe** (`GEAR_OPTI`) au niveau
    du duel ; règles JcJ (`PvpCaps`) ;
  - **à fiche égale** : en Duel classé, ton équipement compte seulement via les plafonds JcJ (comme
    aujourd'hui). Le Panthéon se joue au **niveau du cerveau** (entraîné au niveau 10 sans équipement)
    ou avec les plafonds JcJ, à valider avec Équilibrage par `IA_Duel.bat` ;
  - **gains** : un peu de maîtrise par victoire (aujourd'hui zéro), titres de rang, et au Panthéon la
    panoplie et l'aura de Progression P8.
  - **Gantelet** (variante S-M) : 1 contre 2, puis 1 contre 3 IA scriptées, ou 1 contre 2 cerveaux (le
    préréglage `duo` existe déjà côté héros) : un défi de lecture pour les experts.
- **Touche** : `duel.gd` (modes libre / classé, gains), `duel_director.gd`, `lobby.gd:_menu_duel`,
  `profile.gd` (rangs), cerveaux figés dans git (Progression P8).
- **Dépendances** : Progression (P8, titres), Équilibrage (fiche égale face au cerveau), Interface.

### M5 — Nouveaux événements de Survie (S chacun)

- **Intérêt** : le joueur aime la Survie ; de nouveaux lieux et événements la renouvellent sans
  nouvel écran. C'est la part la moins chère de l'ajout n°4.
- **Règles** (on en choisit 2 ou 3, chacun est un `kind` de plus dans `proc_map.gd` et
  `Interactable.STATION_VERBS`) :
  - **Tableau de primes** : une élite marquée à tuer en moins de 60 s → coffre du joaillier ;
  - **Course aux reliques** : 5 reliques sous le brouillard à ramasser en 90 s → cristaux ; récompense
    la mobilité (saut, esquive aérienne) ;
  - **Cristal à défendre** : tenir 45 s près d'un cristal que les monstres attaquent → fournitures
    (demande que les monstres visent un objet : M si on le fait proprement) ;
  - **Marchand masqué** : propose un échange risqué (un trophée contre deux au hasard) ;
  - **Faille** : un portail vers une petite salle d'un boss d'une autre époque (Ruée des boss en
    miniature), avec un coffre d'emplacement de la rareté supérieure.
- **Touche** : `proc_map.gd`, `interactable.gd`, `run_director.gd:_use_station`.
- **Dépendances** : Équilibrage (gains), Interface (icônes de la carte), Progression (fournitures
  gardées : P1a).

### M6 — Arènes 2v2 / 3v3 avec alliés IA, et le Champ de bataille (L, plus tard)

- **Intérêt** : le rôle des classes de soutien (Builds B6) et le jeu d'équipe ; mais c'est le
  chantier le plus cher du domaine.
- **Règles** :
  - **pré-requis (M)** : monstres et duellistes choisissent **la cible hostile la plus proche** (ou la
    plus menaçante) au lieu de `_player` ; héros alliés (`Player` côté `Team.PLAYER`, piloté par
    `ClassRival` adapté ou par un cerveau) ; soins de zone qui touchent les alliés ;
  - **Arène 2v2** : toi et un allié contre 2 héros, en 2 manches gagnantes, règles JcJ. Les cerveaux
    peuvent jouer (chacun vise l'ennemi le plus proche) mais **ne soignent pas leur allié** (ils ne le
    voient pas) : il faut une IA scriptée de soutien ou accepter des alliés « chacun pour soi » ;
  - **Arène 3v3** ensuite, même moteur ;
  - **Champ de bataille 10v10** : à **retirer du menu** (ou le remplacer par une activité JcE
    d'équipe, « Siège » : toi et 3 alliés IA tenez un bastion contre des vagues et un boss). Le 10v10
    demande 19 IA à la fois, une grande carte et des objectifs que le cerveau ne sait pas lire.
- **Touche** : `monster.gd`, `class_rival.gd`, `player.gd`, `combatant.gd` (équipes), nouveau
  directeur d'arène, `ml_duel_pilot.gd` (plusieurs pilotes).
- **Dépendances** : Builds (soins sur alliés), Équilibrage (règles à 2 et 3), Interface (cadres
  d'équipe), Progression (ce que rapportent les arènes).

### ★ M7 — Le catalogue des activités (ajout n°4, synthèse)

Principe : **chaque activité a un intérêt (ce qu'elle fait travailler), une durée, un gain propre
qu'aucune autre ne donne, et une condition d'ouverture.** On ajoute peu d'activités nouvelles, mais
chacune réutilise un système existant.

| Activité | Rangée | Durée | Intérêt (ce qu'elle fait travailler) | Gain propre | S'ouvre (avec Progression P2) | Coût |
|---|---|---|---|---|---|---|
| Survie | Aventure | 30-45 min | le build qui grandit, la pression | insignes, fournitures de fortification | d'emblée | — |
| Donjons (M2) | Aventure | 8-12 min | les mécaniques de boss, l'équipement du hub | pièces de panoplie ciblées, plans | boss de la zone battu en Survie | M |
| La Tour (M3) | Aventure | libre, par blocs de 10 étages | la puissance du hub, l'endurance | joaillerie, cristaux, apparences de palier | époque I terminée | S-M |
| Défi du jour (M1a) | Défis | ~10 min | sortir de son build, classe imposée | insignes ×, cosmétiques de rotation | 1re run de Survie terminée | S-M |
| Épreuves de maîtrise (M1b) | Défis | 1-3 min chacune | le geste : esquive, saut, annulation, enchaînement | titres, cartes à débloquer liées au geste | d'emblée (tutoriel) | S-M |
| Ruée des boss (M1c) | Défis | ~12 min | les 8 boss d'Eden, le chrono | souvenirs de boss, cristaux | époque II terminée | S-M |
| Duel libre (M4) | Affrontements | 2-4 min | tester un build, s'entraîner contre un cerveau | rien | 1er duelliste de la Tour battu | — |
| Duel classé : Ligue puis Panthéon (M4) | Affrontements | 2-4 min par duel | le 1 contre 1, la lecture de l'adversaire | titres de rang, maîtrise, panoplie du Panthéon | 3 duellistes de la Tour battus ; Panthéon : rang Platine | M |
| Gantelet (M4) | Affrontements | ~3 min | 1 contre 2 ou 3 | titres | rang Or de la Ligue | S-M |
| Arènes 2v2 / 3v3 (M6) | Affrontements | 3-5 min | le jeu d'équipe, les soutiens | à définir | rang Or de la Ligue | L |
| Zone d'entraînement | à part | libre | le bac à sable | rien | d'emblée | — |
| Événements de Survie (M5) | dans la Survie | 1-2 min | variété des cartes | joaillerie, cristaux, fournitures | — | S chacun |

**Ce que nous écartons** : les mini-jeux hors combat (pêche, cuisine, maison) ; le joueur juge au
ressenti du combat (« pression constante ») et chaque mini-jeu hors combat demande un moteur à part.
Nous les gardons pour une question au joueur. Le « Labyrinthe infini » ferait doublon avec la Tour.

**Ordre conseillé** : M0 → M1b (sert le tutoriel) et M3 « reprise sans piège » → M1a, M1c → M2 → M4 →
M5 au fil de l'eau → M6 seulement si le joueur le demande.

---

## 4. Avis de l'équipe sur les ajouts du joueur et ses notes

### Ajout n°1 — Tutoriel passable (pilote : Interface)

- Les **Épreuves de maîtrise (M1b)** sont le tutoriel interactif : les 6 premières épreuves
  (déplacement, esquive, saut, auto-attaque, sort, enchaînement) se jouent avant la 1re Survie et se
  passent d'un clic. « Passer » ne donne pas de médaille, on peut y revenir quand on veut.
- Chaque activité qui s'ouvre (fil d'éveil, Progression P2) montre **une fiche** de 3 lignes : son
  intérêt, sa durée, son gain propre (les champs de M0). Le tutoriel n'a pas à tout expliquer d'entrée.
- La 1re carte de Survie sert déjà de tutoriel (monstres × 0,55 de dégâts, `ZONE_DAMAGE`) : à garder.

### Ajout n°2 — Contenu débloqué au fur et à mesure (pilote : Progression)

- **D'accord** avec l'ordre de P2, avec ces ajustements pour les modes :
  - Zone d'entraînement et Épreuves **d'emblée** (elles enseignent) ;
  - **Duel libre** dès le 1er duelliste de la Tour battu, **Duel classé** après 3 (P2 n°9) ;
  - **Donjons** : chaque donjon s'ouvre quand son boss est battu en Survie, plutôt qu'« époque II
    terminée » : le joueur en a 3 dès l'époque I, la suite vient avec les époques ;
  - **Défi du jour** après la 1re run de Survie ; **Ruée des boss** après l'époque II ;
  - **Arènes** : rang Or de la Ligue (si elles se font) ; le Champ de bataille sort du menu.
- Les activités verrouillées restent **visibles** avec leur condition (comme les époques).

### Ajout n°3 — Équilibrage distinct par mode (pilote : Équilibrage)

- **D'accord avec Builds (section 8)** : l'identité d'un build reste la même partout, seuls les chiffres
  changent, et **à un seul endroit par mode** : c'est le « profil de règles » de M0, qui généralise
  `pvp_caps.gd`.
- Durées cibles par mode (proposition à valider par Équilibrage) : Survie 30-45 min (une carte
  ~12 min) ; Donjon 8-12 min, boss 1 min 30 à 3 min ; Tour ~1 min par étage ; manche de duel 30 s à
  1 min 30 (déjà la cible) ; Défi du jour ~10 min ; Ruée des boss ~1 min 30 par boss.
- **Une seule règle de 1 contre 1** : les duels de la Tour et le Duel devraient partager la même
  échelle (`PvpCaps`), quitte à garder un multiplicateur de PV propre à la Tour. Sinon le joueur
  apprend deux durées de combat.
- **Donjon** : profil « boss » (PV des boss pleins, pas de horde, dégâts contre élites qui comptent),
  et puissance des objets ramenée au niveau du donjon (option A de M2).

### Ajout n°5 — Tout collectionner : d'où vient chaque chose (pilote : Progression)

| À collectionner | Vient de (modes) |
|---|---|
| Équipement (le posséder) | Survie → Armurerie (insignes) ; **Donjons** (pièces ciblées, plans) ; Tour (objets d'étage) ; Panthéon (panoplie) |
| Équipement (l'améliorer à fond) | Survie (fortification) ; **Tour** (joaillerie, polissage, réforge, cristaux) ; Donjons (éclats pour la fabrication) |
| Cosmétiques | boss de Survie ; paliers de la Tour ; sommet de la fortune ; **souvenirs de la Ruée des boss** ; **rotation du Défi du jour** ; aura du Panthéon ; plans d'apparence des Donjons |
| Classes au maximum de maîtrise | tous les modes doivent donner de la maîtrise (aujourd'hui le Duel n'en donne pas : M4 corrige) |
| Cartes et passifs | records de tous les modes (records gardés partout : M0) ; cartes liées aux gestes (Épreuves M1b) |
| Titres et succès | une famille de succès par activité : médailles des Épreuves, rangs de la Ligue, chronos de la Ruée, donjons en Mythique, étages de la Tour, défis du jour réussis |

### Notes du joueur (brief)

- **Survie : ciseaux, parchemins et pierres d'amélioration** : déjà en partie dans le sac (butin,
  marchands, coffres de forge) ; à rendre fiable (le sac part vide, la réserve reste au hub : P1a) et
  lisible au bilan. D'accord avec P5.
- **Tour : gemmes, enchantements, pierres pour polir et réforger** : repris dans M3 (gains).
- **Donjons : pièces mythiques, légendaires, éveillées selon le niveau, plans de fabrication** : repris
  dans M2 (difficultés Normal / Héroïque / Mythique, plans et carnet de plans).
- **Autel de récompense en pyramide** : **fait** (`core/fortune.gd`, `ui/fortune_popup.gd`, un par
  carte de Survie). Reste une question de Progression (ses coffres d'équipement font sortir des pièces
  de la Survie).

### Place des cerveaux d'IA

- **Adversaires, oui, en 1 contre 1** : c'est leur terrain d'entraînement. Trois places : le **Duel
  libre** (comme aujourd'hui), les **duellistes-paliers de la Tour** (étages 50 / 100 / 150 / 200, M3),
  et le **Panthéon** au bout de la Ligue (M4, Progression P8). Le Gantelet 1 contre 2 cerveaux est
  possible (le cerveau a été entraîné en `duo` côté héros) mais à tester.
- **Pas de cerveau en Survie, en Donjon ni sur une grande carte** : le cerveau ne connaît qu'une arène
  de 15 m de rayon et un seul adversaire ; avec 80 à 110 monstres, il jouerait mal et coûterait cher.
- **Alliés : pas avant M6**, et avec une limite connue : un cerveau allié se bat bien mais **ne voit
  pas ses alliés**, donc ne soigne ni ne protège personne. Un allié de soutien demandera une IA
  scriptée (ou un nouveau cerveau, avec les observations figées : impossible sans un nouvel
  entraînement complet).
- **Fichiers** : les cerveaux de la fin de jeu doivent être **figés dans git** (P8), sinon le Panthéon
  change à chaque entraînement et n'existe pas sur un autre PC.

---

## 5. Questions aux autres équipes

**Progression**
1. D'accord pour que **chaque donjon s'ouvre quand son boss est battu en Survie** (au lieu d'« époque II
   terminée ») ?
2. Qui porte les **plans de fabrication** (carnet, coût de fabrication, place dans la collection) :
   vous ou nous ? Nous proposons : nous le format (où ils tombent), vous la fabrication et le coût.
3. Le **Duel classé** remplace-t-il votre condition d'accès au Panthéon (P8 : Duel gagné contre
   l'Hardcore ou étage 100) par « rang Platine de la Ligue » ?
4. Les records gagnés en Tour, Duel et Défis comptent-ils pour les cartes à débloquer (oui pour nous) ?

**Équilibrage**
1. Profil de règles par mode (M0) : quels champs vous faut-il ? Pouvez-vous fixer les durées cibles ?
2. Une seule échelle de 1 contre 1 (`PvpCaps`) pour les duels de la Tour et le Duel : d'accord ?
3. Donjons, option A (équipement du hub ramené au niveau du donjon) : faisable sans écraser la
   difficulté ? Comment se compare-t-elle à la Tour (non ramenée) ?
4. Panthéon : à quel niveau et avec quelles règles un cerveau entraîné au niveau 10 reste-t-il juste ?
5. Combien de cartes donner en reprise de Tour (N ÷ 5 ?) ; liste des modificateurs du Défi du jour.

**Builds**
1. Les **trophées en Tour** (un choix tous les 10 étages) : d'accord ? Et les cartes de run en Donjon ?
2. Quelles épreuves de maîtrise pour débloquer quelles cartes (lien avec votre section 7) ?
3. Les combos d'états (B4) et l'esquive parfaite (B7) agissent-ils en Duel ? (pour nous : oui, avec
   les chiffres du profil JcJ).
4. Arènes : faut-il prévoir dès maintenant les soins sur alliés (B6) ?

**Interface**
1. Menu Jouer à 3 rangées (Aventure, Défis, Affrontements) + Entraînement : place disponible ?
2. Étiquette d'activité avec **gain propre** et **durée** (champs de M0), et cadenas avec condition.
3. Médailles des Épreuves, classement personnel des Défis, page des rangs de la Ligue.
4. Retirer le Champ de bataille du menu (ou le remplacer) : d'accord ?

---

## 6. Questions au joueur (l'indispensable)

1. **Donjons** : tu y entres **avec ton équipement du hub** (comme dans Eden, ce qui donne un vrai
   usage à l'Armurerie et à la forge), ou **à zéro comme la Survie** ?
2. **Champ de bataille 10 contre 10** : l'IA ne sait pas jouer à 20 sur une grande carte. On le
   **retire du menu**, ou on le remplace par un « Siège » en JcE (toi et 3 alliés IA contre des vagues) ?
3. **Arènes 2v2 / 3v3 avec des alliés IA** : est-ce important pour toi ? C'est le plus gros chantier des
   modes, et les alliés ne sauront pas se soigner entre eux au début.
4. **Défi du jour** avec une **classe imposée** : ça te plaît, ou tu veux toujours choisir ta classe ?
5. **Mini-jeux hors combat** (pêche, etc.) : en veux-tu, ou tout reste centré sur le combat ?
