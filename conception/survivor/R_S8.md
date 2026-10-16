# R_S8 — Survivant : paliers, mode visible, documentation (16/10/2026, version 0.1.210)

Lu : `DECISIONS_JOUEUR.md`, `SPEC.md` (§8.5, S8), `R_S1` à `R_S7`, `PLAN_NUIT.md`, `R_P15.md`, `CLAUDE.md` (pas de `R_M8` à ce moment).
Mesures : copie propre de HEAD + ce lot (`tools/run_tests.preparer_copie`), `--fixed-fps 60`, un dossier utilisateur par processus.

## Fait
- **Paliers I à V** (`Survivor.PALIERS`, `tier_rule`, `numeral`, `palier_open`, `top_palier`) : chaque palier garde les règles du
  précédent et en ajoute UNE, écrite en une phrase au lobby (détail en infobulle, sans pourcentage) :
  I Normal · II Endurci (monstres ×1,15 en vitesse) · III Implacable (soins reçus ÷ 2 : modificateur `heal_half` posé par
  `Survivor.start`, retiré par `finish`) · IV Cauchemar (Menace 2 dès le départ, une mécanique de boss en plus) · V Légende (deux
  gardiens à 15:00, deux mécaniques en plus, rage du boss après 3:00, monstres ×1,2). Mécaniques ajoutées : `Survivor.EXTRA_BRICKS`
  (Marque, Couronne d'orbes, Balayage, Bond, Ondes de choc, Nuée), jamais une famille que le boss a déjà, annoncées
  (« Palier IV · le boss gagne : Marque »). PV et dégâts × `palier_mult` = 1 / 1,45 / 1,7 / 1,75 / 2,1, **installé sur 5 minutes**
  pour les monstres ordinaires (`PALIER_RAMP`), entier pour gardiens et boss. Message d'ouverture « · palier IV : Cauchemar ».
- **Ouverture** : un palier s'ouvre en gagnant le précédent DANS CE MODE (`Profile.records["sv_rewards"].wins`, aucun lien avec le
  compte ; un ancien profil qui a la récompense « win:1 » compte une victoire) ; mode dev : tous. Bilan : « Palier II ouvert ! ».
- **Récompenses** (paramètre `tier` de S6 branché) : coffres « première fois » par palier, boss vaincu = légendaire dès le II, titre
  par palier ; bilan « gardiens x / 4 » au palier V.
- **Lobby** (`_survivor_tiers`) : 5 boutons I à V (choisi en or, fermés « 🔒 V » grisés avec « Gagne le palier IV pour l'ouvrir. »),
  la règle du palier, puis ses coffres ; palier par défaut = celui de la run qui vient de finir, sinon le plus haut gagné.
- **Mode visible** : `Survivor.READY = true` ; activité de la rangée Aventure (2e), sous-titre raccourci (« Tout se gagne aux
  cartes », coupé à 1280) ; **illustration provisoire** `assets/ui/activities/survivor.jpg` = l'écran de la Survie retourné et
  passé au crépuscule (**une illustration dédiée est à demander à la session locale**) ; quêtes « Survivant » de M5 tirables (porte
  `Survivor.visible`) ; nouveauté « Survivant » (`Tutorial.CARDS.survivor`, chapitre Modes) et entrée du Guide (`Guide.ROLES`, 4
  lignes). Premiers pas : inchangés (ils vivent dans la Survie, le Survivant a ses 3 fiches dans le choix de cartes, S5). Boussole :
  rien (elle sert la progression du compte, que le Survivant ne touche pas).
- **Pilote qui dépense son or** (`SurvivorDirector.pilot_target` / `_pilot_shop`, crochet d'une ligne dans
  `RunDirector._update_route`) : coffre payable le plus proche (toute la carte), marchands non visités (cartes au choix du Bot, puis
  clés). Cartes à 20:00 : 70 → **86**. Il garde encore ~48 000 or à la fin (tous les coffres ouverts, rien d'autre à acheter).
- **Débutant** : dégâts du boss 1 → **1,4** (`BOSS_ATK`) ; PV du boss inchangés (la sonde de S7 reste valable).
- Doc : `DESIGN.md` (Survivant, point « Paliers »), `CLAUDE.md` (3 lignes), `SPEC.md` (tête « Décisions finales », passages
  remplacés signalés), CHANGELOG. `tools/sim_survivor.py` : `--palier 1,2,3`, or restant, or dépensé aux marchands, erreurs de script.

## Mesures (pilote `--survivor --autoplay`, 5 classes ; débutant 0,3 / moyen 0,5 / bon 0,7)
| Palier I | victoire déb. / moy. / bon | boss (TTK) | cartes à 20:00 |
|---|---|---|---|
| S7 (pilote sans achats) | 40 / 40 / 60 % | 130 s | 70 |
| Pilote qui achète, boss ×1 (30 runs) | 60 / 60 / 80 % | 96 s | 85 |
| **Retenu : boss ×1,4 (30 runs)** | **30 / 60 / 70 %** (cible 10 / 35-50 / 65) | 110 s | 86 |

| Bon joueur (0,7) | essai 1 (mult. 1,3 / 1,6 / 1,9 / 2,3, sans montée) | **retenu** (montée sur 5 min) | cible |
|---|---|---|---|
| II | 40 % (5 runs) | **80 %** (1,3 : 5 runs ; 1,45 : 10 runs) | ≈ 30 % |
| III | 40 % | **20 %** (5 runs) | ≈ 20 % |
| IV | 0 % (morts dès 1:10) | **20 %** (5 runs) | ≈ 10 % |
| V | 0 % (5 morts avant 2:30) | **0 %** (5 runs, 3 atteignent le boss) | ≈ 3-5 % |
Aucune erreur de script sur 110 runs. Gardiens 30-60 s, niveau 40 à 20:00, victoires en 21-24 min.

## Décisions
- Les paliers ajoutent des règles plutôt que des PV : le pilote « bon » (×0,3 de dégâts subis) ne sent presque pas les
  multiplicateurs (II à 1,3 et 1,45 : 80 %) ; ce sont les soins ÷ 2 (III) et la pression du début (IV, V) qui le font perdre.
- Montée du multiplicateur sur 5 min : au palier V, sans elle, le héros nu mourait dans les deux premières minutes (sans intérêt).
- Le débutant reste au-dessus de sa cible (30 % pour 10 %) : le proxy « coups évités » ne rend pas ses erreurs ; le monter plus
  rendait le moyen trop bas (gradient 30 / 60 / 70 obtenu, le moyen garde 60 %, dans la borne de `test_sv7`).

## Reste
- **Palier II trop facile au pilote (80 % pour 30 %)** : à juger au journal réel ; levier prêt (`palier_mult[1]`, mode dev) ou une
  règle plus forte (soins réduits dès le II). 5 runs par palier : bruit ± 20 points.
- Illustration dédiée (session locale). Le pilote ne vise pas l'« Audace » (entrée en avance).

## Tests
`test_sv8` (nouveau, vert : paliers, ouverture, récompenses, règles, mode visible, parcours lobby → IV → victoire → V ouvert → V →
abandon, hub intact) ; verts : test_sv1 à sv7 (`sv7_mesures.json` refait : boss ×1,4, runs S8), test_nav_screens (sélecteur ajouté),
test_quests (quêtes Survivant tirées une fois le mode visible), test_lot9, test_p4_activities (`survivor+r` ajouté ; sous-ensemble
survivor / survival / training). Captures `tests/shot_sv8` regardées en 1600×900 et 1280×720 : menu Jouer, page du mode (compte neuf,
trois paliers gagnés), premier choix, carte au palier IV (Menace ×1,4), arène (mécanique annoncée), bilan.

## Retouches hors lot
`run_director.gd` (1 ligne : cible du pilote), `results_screen.gd` (annonces du bilan, gardiens x / n), `activities.gd`, `guide.gd`,
`tutorial.gd` (entrées du mode), `lobby.gd` (sélecteur ; le reste du fichier non touché), tests `test_sv4`, `test_quests`,
`test_nav_screens`, `test_p4_activities`.
