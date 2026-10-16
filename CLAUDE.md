# Eden Slash — consignes pour les sessions Claude

Deux sessions travaillent sur ce dépôt : une **locale** (sur le PC, avec le client Eden Eternal,
extraction des assets) et une **cloud** (sans le client). Le joueur ne connaît pas git.

Ce fichier = règles de session (à suivre telles quelles) puis **état du jeu** par système (fichier d'entrée + renvoi au
détail). Règles de jeu : `DESIGN.md` (table des matières en tête). Historique des versions : `CHANGELOG.md`. Ancien contenu
de ce fichier (historique des lots, restes datés) : `conception/HISTORIQUE_CLAUDE_MD.md`. Rapports de la nuit du 15/10 :
`conception/nuit_15_10/INDEX.md`. Une session qui finit un lot met à jour la section concernée en 2-3 lignes (pas d'historique ici).

## Branche
Tout se passe sur la branche `claude/optimistic-gauss-p2g2pq`. Ne pas travailler sur `master`.

## Numéro de version (obligatoire à chaque envoi)
À **chaque push** :
1. augmenter de 1 le dernier chiffre de `Version.NUMBER` dans `game/scripts/core/version.gd`
   (0.1.7 → 0.1.8) ;
2. ajouter une ligne dans `CHANGELOG.md` (version, contenu en une phrase, session) ;
3. citer la version dans le message de commit (« 0.1.8 : … »).
Le numéro est affiché en bas à droite de tous les écrans : le joueur s'en sert pour savoir
s'il a la bonne version.

## Avant / après le travail
- Avant de commencer : `git pull --no-rebase` (l'autre session a pu pousser).
- Après : commit, `git pull --no-rebase`, puis `git push`. Ne jamais laisser du travail
  non poussé à la fin d'une session.
- Les fichiers `.uid` créés par l'éditeur Godot peuvent bloquer un pull : les supprimer
  s'ils existent déjà dans le dépôt distant.
- `Mettre_a_jour.bat` met de côté (`git stash -u`) les fichiers modifiés localement avant
  le pull, puis les remet (`git stash pop`). Si un `stash pop` a échoué, le travail local
  est toujours dans `git stash list` : le récupérer avant de continuer.

## Notes du joueur
Alt + clic droit sur n'importe quoi dans le jeu enregistre une note dans `feedback/<date>_note/`
(`rapport.json` : note, type, élément visé, version ; `capture.png` avec un repère rouge).
Le dossier n'est pas dans git : la session locale les lit au début du travail.
Suivi lisible par le joueur : `feedback/_SUIVI.md` (une ligne par note : date, résumé, statut, version) ; y ajouter chaque nouvelle note.

## Tests
`Godot --headless --path game res://tests/<test>.tscn` pour test_build, test_hud,
test_controls, test_cards, test_progress (et ceux ajoutés depuis). Après l'ajout d'un
script avec `class_name`, lancer une fois `--import` pour mettre à jour le cache des classes.
Toute la suite d'un coup : `python tools/run_tests.py [-j 4] [-r 3] [mot du test...]` (copie propre de HEAD, un dossier utilisateur par
exécution, tableau vert / rouge ; `-r 3` cherche les tests instables ; `--reuse` garde la copie, `--live` teste le dossier de travail).
Intégration (passe P4, `conception/nuit_15_10/R_P4.md`) : `test_p4_flow` (hub de bout en bout, sans changer de scène),
`test_p4_activities` (chaque activité lancée depuis le lobby, jouée, bilan, retour ; ~7 min ; `-- duel,tower` pour un
sous-ensemble) et `test_p4_migration` (vieilles sauvegardes ; `P4_REAL_SAVES=<dossier>` charge aussi de vrais profils).
Français (passe P10) : `test_texts_fr` signale tout mot anglais lisible par le joueur (objets, passifs, sorts, talents, cartes, trophées…) ;
un nom d'Eden nouveau passe par `data/names_fr.json` (`tools/names_fr_build.py`, lexique `names_fr_extra5.py`, talents `names_fr_talents.py`).
Les tests de simulation (`test_siege`…) attendent des événements, jamais des durées (`_wait` en images de physique, cartes fermées d'office).
Tests instables (passe T1, `conception/nuit_15_10/R_T1.md`) : une carte (`ProcMap`) lance son calcul de navigation sur un fil du moteur, donc un test qui la génère attend `_region.navigation_mesh != null` avant `quit()` (plantage 0xC0000005 sinon) ; ne jamais comparer l'équipement ou le bonus de départ de deux mondes tirés au hasard (mesurer dans un seul monde) ; fixer les valeurs tirées au hasard que le contrôle lit (qualité d'une pièce, coffres d'origine de la carte) ; un lambda sur plusieurs lignes dans un appel plante le parseur (utiliser une méthode).
Plusieurs sessions dans le même dossier : lancer la suite sur une copie de `game/` avec `config/custom_user_dir_name` à part.
Captures d'écran (outils `tests/shot_*.tscn`, APPDATA détourné, variable `*_RES=1280x720`) : les écrans à pages doivent tenir dans
1280×720 (`tests/shot_p1.tscn`, `P1_STATE=neuf|avance`, lignes `[débord]`) ; un écran nouveau entre dans `test_nav_screens` et `test_pages`.

## État du jeu (16/10/2026)

Vision (`conception/nuit_15_10/PLAN_NUIT.md`) : toutes les activités servent **une quête commune** (équipement optimal des
60 classes, titres, apparences) ; chaque activité a un **rôle unique** ; jeu poli « comme un AAA » : une idée par écran, textes
français courts, aucun pourcentage dans le texte permanent (infobulle), **aucune mention du jeu Eden d'origine côté joueur**.
Conception d'origine : `conception/CONCEPT_FINAL.md` (16 lots, tous codés ; réponses du joueur `REPONSES_JOUEUR_1.md`, font foi) ;
idées du joueur : `conception/IDEES_EN_VRAC.md`.

### Activités (menu Jouer)
`ui/activities.gd` (`Activities.LIST` : rangée Aventure / Défis / Affrontements, verrou, pastilles `gives`, image
`assets/ui/activities/`), page de chaque activité dans `ui/lobby.gd` (`_show_menu` ; pages qui défilent sous `PANEL_W`, bouton
d'action épinglé `_pin` / `_pin_go`), verrous du fil d'éveil `core/unlocks.gd` (`Profile.unlocked_features`, mode dev = tout ouvert).
Une activité nouvelle : entrée dans `Activities.LIST` + image + page du lobby + `QuestPool.ACTS` + `ResourceHelp` / `gives` + cas
dans `Compass` si elle change la quête + `test_nav_screens`. Les activités « Bientôt » sont cachées. Mode courant : `Modes.current()`.

| Activité | Rôle unique (`gives`) | Ouverture | Entrée | Détail |
|---|---|---|---|---|
| Survie | pièces (découverte), maîtrise, insignes, étoiles | dès le départ | `core/run.gd`, `run_director.gd`, `epochs.gd` | DESIGN « Survie » |
| Survivant | apparences, titres (aucun lien avec le compte) | dès le départ | `core/survivor*.gd` | `conception/survivor/SPEC.md` |
| Donjons | panoplies, plans, cristaux, parchemins | époque I gagnée (A2) | `core/dungeons.gd`, `ui/dungeon_page.gd` | DESIGN « Bibliothèque de boss » |
| La Tour | cristaux, gemmes, apparences | époque I gagnée | `core/tower.gd`, `tower_director.gd` | DESIGN « La Tour » |
| Quêtes | maîtrise des classes en retard, apparences (lot A5) | 3 Survies | `core/quests.gd`, `ui/quests_page.gd` | DESIGN « Quêtes » |
| Ruée des boss | parchemins, pierres, cristaux, titres | époque II (entrée `rush`) | `core/rush.gd`, `rush_director.gd` | DESIGN « Ruée et Siège » |
| Le Siège | formules, cristaux, apparences | époque II (Normal sans PE) | `core/siege.gd`, `siege_director.gd` | DESIGN « Ruée et Siège » |
| Duel (Libre, Ligue, Panthéon, Gantelet) | rangs, titres, maîtrise, Esprits | 1er duelliste de la Tour | `core/duel.gd`, `league.gd`, `pantheon.gd` | section « Duel » ci-dessous |
| Arènes 2v2 / 3v3 | titres, maîtrise, insignes | rang Or de la Ligue | `core/duel_director.gd` | `R_M7.md` |
| Battle royale | apparences, titres, maîtrise | rang Argent de la Ligue | `core/royale.gd`, `royale_director.gd` | DESIGN « Battle royale » |

Épreuves de maîtrise : « Bientôt » (pas de moteur de leçons). Zone d'entraînement : `core/training.gd`.

### Survie (mode principal)
- Une run = 3 cartes d'une **époque** (`core/epochs.gd` : `LIST` zones / niveaux des pièces / raretés, plafonds de niveau `CAPS`
  15 / 25 / 35, monstres `MONSTER_MULT` ×0,85 / 1,7 / 3,4 / 7, rangs héroïques 1-10 après l'époque IV, étoiles d'époque).
  Lancement `Run.start_survival`, déroulé `core/run_director.gd`, monde `core/world.gd`, carte `ProcMap`.
- **Part avec l'équipement du hub** (décision du joueur du 15/10, N1, 0.1.170) : `Profile.begin_run` copie le préréglage actif et
  prend un instantané (`_hub_snapshot`) que `Profile.end_run_survival` restaure ; les trouvailles ne valent que la run.
  Compte neuf : `core/starter_gear.gd`. Détail : `conception/nuit_15_10/N1_survie_equipement.md`.
- Coffres d'emplacement (`core/slot_chests.gd`, 30 par carte, cape comprise ; arme = type de la classe ; une arme choisie fait
  découvrir les 17 types, `SlotChests.weapon_family`) ; **plus d'enclume** en Survie (N2 : le +N est celui du hub) ; une arme
  trouvée va dans le sac (`Run.bag_weapon`, HUD + [G]), auto-attaques `combat/weapon_attacks.gd` (2 variantes, 8 rangs d'amélioration),
  trophées = collection de la run (`Run.trophies`, 12 au plus, `Trophies.KINDS`, outil `tools/rework_trophies.py`).
- Coffre de plans du boss de carte (A4) : `RunDirector.offer_plans` → 1 pièce parmi 3 non découvertes du palier (`Run.plan_offer`,
  `SlotChests.plan_candidates`), acquise tout de suite (`Run.grant_plan`, gardée en défaite), sinon 30 insignes ; test `test_a4`,
  mesure `progression_sim --bossplans`, rapport `conception/progression/R_A4.md`.
- Monstres : rôles et escouades `core/spawn_director.gd` (P15, `--spawn=legacy` pour comparer), puissance selon l'indice
  d'équipement `core/monster_scaling.gd`, rage par paliers `RunDirector.RAGE_TIERS` (×1,1 / 2 / 11 / 101 par minute),
  début doux `EARLY_EASE` / `EARLY_RAMP`. Pacte, géants et **Menace** (`core/menace.gd`, +20 % de PV par cran, plafond 5,
  `world/giant_altar.gd`, `ai/giant_monster.gd`).
- **Boss à PV fixes**, jamais d'après le héros : `Epochs.boss_hp` (`BOSS_HP_MAP` × `BOSS_HP_EPOCH`) et rage du boss
  `Epochs.BOSS_RAGE_AT` (2:30 / 3:00 / 4:00) ; mécaniques `ai/boss_brain.gd`.
- Mode farm façon Megabonk : objets à casser `world/breakables.gd`, sites, plateaux, autels (fortune `core/fortune.gd`).
  Vues de la carte : `res://tools/map_shots.tscn -- <graine> [zone]` ; test `tests/test_farm.tscn`.
- Détail : DESIGN « Boucle de jeu et Survie », « Apparition des monstres », « Pacte, géants et Menace », « Boss : PV fixes ».

- **Deux armes** (N2, tous les modes, `R_N2.md`) : principale = type de la classe, secondaire = un autre type qui ne frappe jamais
  seule ; action `swap_weapon` (`Player.swap_weapon`, `hand_off`, recharge `WeaponAttacks.SWAP_CD` / `SWAP_CD_PVP`) ; en main, ses
  attaques ne servent qu'aux auto-attaques (`Player.basic_atk`), les compétences lisent toujours l'arme principale. Test `test_n2`.

### Survivant (mode à part, ouvert à tous)
`core/survivor.gd` (état, réglages en tête, paliers `Survivor.PALIERS` I à V, `HUB_KEYS` : le compte n'est jamais modifié),
`survivor_pool.gd` (13 sets de niveau 90), `survivor_gear.gd`, `survivor_cards.gd`, `survivor_director.gd` (`timeline`, `spawn_plan`),
`survivor_rewards.gd` (coffres d'apparence seulement) ; interface `ui/survivor_cards_view.gd`, `survivor_build_page.gd`, `survivor_hud.gd`.
Spécification : `conception/survivor/SPEC.md` (sa tête « Décisions finales » prime) ; rapports `R_S1` à `R_S8`.
Lancement direct : `world.tscn -- --survivor`. Tests `test_sv1` à `test_sv8` ; `test_sv7` relit `tests/sv7_mesures.json` :
changer un réglage demande de refaire les mesures (`tools/sim_survivor.py`).
S9 (`R_S9.md`) : 12 sorts au plus (`Survivor.SPELL_MAX` = la grille 4 × 3, poids des améliorations borné par `spell_up_norm`) ;
orbes : sol plein = la nouvelle reprend l'orbe la plus loin (`XpOrbs.spawn`) ; collecte réelle mesurée par `--extra=--human-magnet`, `test_sv9`.

### Boss et bibliothèque
`core/boss_library.gd` + `data/bosses.json` (48 boss, 6 par zone), mécaniques = briques `ai/boss_bricks.gd` (29, 10 familles)
lancées par `BossBrain` ; `BossLibrary.spawn(id, palier, ctx)` sert les Donjons, la Tour, la Ruée et le Siège (la Survie et le
Survivant gardent leurs boss). Coup plafonné à `BossLibrary.HIT_CAP` (40 %), `Tower.BOSS_HIT_CAP` (25 %) dans la Tour.
PV des boss hors Survie : `Dungeons.boss_hp` (fixes par niveau et difficulté). Boss sorti de la salle : `TowerDirector._rescue_boss`.
Détail : DESIGN « Bibliothèque de boss et donjons à la carte », `R_M2.md`, `R_P11.md`.

### Donjons, Tour, Ruée, Siège
- **Donjons** : `core/dungeons.gd` (un donjon par boss, `Dungeons.catalog`, archétypes `ARCHETYPES` + `Items.SETS`), moteur de
  salles de la Tour (`Tower.dungeon`), alliés IA (`ClassRival.ally`). Test `test_m2`. **Plans de donjon** (lot A1) : un par boss
  (`plan_<boss>`, 48) à la 1re victoire, fabriqués en insignes (`ui/fabrication_page.gd`, `Dungeons.plan_diff`) ; anciens `plan_<zone>`
  convertis par `Dungeons.migrate_plans()` (paresseux, idempotent). Test `test_a1`, rapport `conception/progression/R_A1.md`.
  Lot A2 : ouverts à l'époque I gagnée ; 3 salles (élites une à une, `TowerDirector._begin_dungeon_room`, lieutenant, boss), réglages
  `Dungeons.ELITE_ROOM_HP` / `LIEUTENANT_HP` mesurés par `tools/dungeon_run` (`--god=1`), PE conseillée `Dungeons.advised` ; `test_a2`.
- **La Tour** : `core/tower.gd` (`block_plan` par bloc de 10, `BOSS_CURVE`, `BOSS_FLOOR_ADJ`), `core/tower_director.gd` (interface
  documentée en tête, prolongée par `SiegeDirector`), équilibre entre classes `core/tower_balance.gd` + `data/tower_solo.json`
  (régénéré par `tools/m8_matrix.py solo`). Tests `test_m3`, `test_m8`. Rapports `R_M3.md`, `R_M8.md`.
- **Ruée** : `core/rush.gd` (8 boss tirés à graine, modificateurs), `core/rush_director.gd`. **Siège** : `core/siege.gd`
  (`Siege.boss_for`, `POWER_RATIO`), `core/siege_director.gd`, chacun pour soi (`Combatant.set_ffa`). Pages : jauge de PE
  `Lobby._pe_gauge`, estimation `ui/difficulty_panel.gd` (`Rush.ADVISED`, `Siege.ADVISED`). Rapport `R_M6.md`.

### Duel, Arènes, Battle royale
Règles opérationnelles dans la section « Duel (JcJ) » plus bas. Ligue `core/league.gd` (rangs Bronze à Platine), Panthéon
`core/pantheon.gd` (6 cerveaux figés `data/cerveaux/pantheon_<id>.json`, panoplie des Esprits `Items.SETS.pantheon`),
Arènes / Gantelet en équipes dans `core/duel_director.gd` (`Duel.make_ally`, `Duel.team_classes`, `Duel.hazards`, `ui/team_bars.gd`).
Battle royale : `core/royale.gd`, `core/royale_director.gd` (`RoyaleDirector.BRAIN`), carte `ProcMap.generate_royale` ; test
`test_royale`, partie complète `world.tscn -- --royale --autoplay [--royale-diff=0..3] [--auto-quit]` (ligne `[royale]`).
Largage et réanimation (lot BR4) : `core/royale_drop.gd` (aigle, saut, chute, planeur ; héros en l'air hors du groupe « ffa », physique
coupée ; `RoyaleDirector.phase` « drop » puis « fight » : `elapsed` part au dernier atterrissage, `clock` dès le vol) ; retour une fois
avant `Royale.REVIVE_WINDOW` (`RoyaleDirector.revives`, `_revive_player` / `_revive_ai`, arme seule) ; test `test_br4`, captures `shot_br4`.
Équilibre (lot BR1, `conception/royale/R_BR1.md`) : échelle 0,055 du profil `royale`, `Royale.kill_xp` (écart de niveau), `LEVEL_CAPS` par
anneau, force des scriptés (`AI_GEAR_SCALE`, `ai_level_factor`), `AI_EXCLUDED` ; mesures : `tools/royale_duel_probe.tscn` (durée d'un duel par
niveau et équipement, `--tournament`, essais `--scale=` / `--caps=`) et les lignes `[royale] élimination` / `[royale] force` du pilote.
Équipement du BR (lot BR3) : `core/royale_loot.gd` (emplacements vides d'abord, arme gardée, puis améliorations ; joueur = pièces et
cartes du Survivant via `SurvivorGear.adopt` / `SurvivorCards.up_card`, rendu `SurvivorCardView` ; scriptés = `RoyaleLoot.offer`,
`Royale.AI_GEAR_SCALE`, mesure `tools/br3_ai_probe`), pièces au sol à la mort et fiche `ui/royale_gear_sheet.gd` ; test `test_br3`.
Chacun pour soi général : `Combatant.ffa_id` / `set_ffa()` / `clear_ffa()`, groupe « ffa ».

### L'Échiquier (autochess, en cours)
Spécification `conception/autochess/SPEC.md` (+ annexes A, B ; lots AC-A à AC-J). Données (AC-A, `R_AC_A.md`) : `core/autochess_data.gd`
(`AutochessData` : réglages en tête ; traits, objets, atouts avec clés d'effet `effect` + `params` / `tiers`, appliquées par AC-H), 60 unités
`data/autochess_units.json` générées par `tools/autochess_units.py` (rôle, allonge, sort signature ; aucun cerveau : IA scriptée seule) ; test `test_ac_data`.
Partie (AC-B, `R_AC_B.md`) : `core/autochess.gd` (`Autochess` : machine d'étapes sans scène prep → combat → recap, actions `buy` / `sell` / `reroll` / `buy_xp` / `place` / `equip` / `choose`,
stratèges `decide` / `choose`, combat injecté `fight(a, b, ctx)`, sauvegarde `user://autochess_save.json` au début de chaque préparation), réserve `core/autochess_pool.gd` ; test `test_ac_game`.
Plateau (AC-F, `R_AC_F.md`) : `world/autochess_board.gd` (`AutochessBoard` : hexagones 7 × 8, adversaire en miroir, figurines, stratège ; `set_state` lit aussi
`Autochess.players[i]`, signaux `unit_placed` / `unit_sold` / `item_given`), bancs `world/autochess_bench.gd`, curseur `ui/autochess_cursor.gd` (cases navigables
par UiNav, calque `AutochessCursor.LAYER` à partager avec la boutique) ; démo `tools/acf_demo.tscn`, test `test_ac_board`, captures `tests/shot_acf.tscn`.
Effets (AC-H, `R_AC_H.md`) : couche pure `core/autochess_effects.gd` (`AutochessEffects` : `context`, `apply_stats`, `start` / `tick` / `attack` / `cast` /
`spell_hit`, `on_trigger`, `result` ; PV, mana, boucliers, déclencheurs, plafonds) + `autochess_items.gd` / `autochess_traits.gd` / `autochess_augments.gd`,
même code pour le simulateur (AC-C) et le vrai combat (AC-E) ; test `test_ac_effects` (mini-simulateur de test).
Interface (AC-G, `R_AC_G.md`) : écran jouable `scenes/autochess.tscn` (`ui/autochess_screen.gd`, `AutochessScreen.config` : seed, resume, autoplay ;
7 stratèges au hasard, `power_fight`), cadre `ui/autochess_hud.gd` + `autochess_shop` / `_traits` / `_players` / `_unit_card` / `_augments` / `_carousel` ; test `test_ac_ui`, captures `tests/shot_ac.tscn`.

### Économie : insignes, cristaux, fournitures
- **Insignes = acquérir** (Armurerie) : barème `core/economy.gd` (`INSIGNIA_PER_HOUR`, `survival_insignia_parts`, Armurerie à
  paliers `armory_price`, puits `SHOP_CHESTS`, leçon de maîtrise) ; participation `Run.INSIGNIA_BASE` ; JcJ plafonné au jour
  (`League.win_insignia`, `royale_insignia`). Seule la Survie en donne (lot A5, `R_A5.md` : cartes et boss de
  carte surtout, monstres / 40), plus le JcJ plafonné ; les quêtes ne paient que maîtrise et apparences.
- **Cristaux = optimiser** (Forge) : `Forge.GOLD_PER_CRYSTAL` 125 hors run ; sources hors Survie `core/activity_loot.gd`
  (Donjons, Ruée, Siège, Tour : cristaux et coffres de forge / du joaillier au niveau de l'activité).
- **Fournitures** (parchemins, gemmes, formules, pierres) : coffres de matières (`core/rewards.gd`, `focus`), en Survie au niveau
  des pièces de la carte (`RunDirector.supply_level`), gemmes `Craft.gem_run_factor`.
- Où l'obtenir / où le dépenser : `core/resource_help.gd`. Détail : DESIGN « Économie et progression » ; rapports `R_E1`, `R_E2`,
  `R_E5`, `R_E6`.

### Progression du compte
Maîtrise des classes (`Profile.add_expertise`, part de l'arbre, rattrapage), talents, certificats ; fil d'éveil `core/unlocks.gd` ;
verrous de PE `core/gear_power.gd` (`DIFF_RATIO`, `LEGEND_RATIO`, `GearPower.required`) ; profils de stats des 60 classes
`core/class_gear.gd` (`data/class_profiles.json`, `tools/gen_class_profiles.py`), Registre `ui/registry_page.gd` ; Carnet
(`ui/carnet_pages.gd`, `CarnetPages.tabs()` : ajouter un onglet à la fin, la Collection garde l'indice 4) avec succès
`core/achievements.gd` et complétion `core/completion.gd` ; Atelier (**Fabriquer** `ui/gear_shop_page.gd` : une pièce découverte
est un plan, on la fabrique en insignes, `Completion.plan_place` dit où le trouver ; **Plans de donjon** `ui/fabrication_page.gd` ; Forge
`ui/forge_bench.gd` ; bourse `ui/workshop_purse.gd` ; noms internes `_buy` / « armory » inchangés, lot A3) ; roulette `core/wheel.gd` ; potions
`core/potions.gd`. Simulation d'un compte neuf : `res://tools/progression_sim.tscn` (`--gates` : PE requise par zone).
Détail : DESIGN « Économie et progression » ; `R_E3.md`, `R_E6.md`, `R_P5.md`.
**Niveau de héros** (lot H1) : `core/hero_level.gd` (`HeroLevel` : niveau 1-90 du compte dans `records.hero_xp`, courbe, XP au kill par
`Monster._on_death` en Survie / Donjons / Tour / Ruée / Siège, versée par `Quests.end_run`, ligne du bilan `ResultsPanel.show_spec`,
migration `ensure`), jauge `ui/hero_level_gauge.gd` ; stats et monstres : lots H4-H5 (`conception/progression/NIVEAU_HEROS.md`, `R_H1.md`).
Port des pièces (H3, `R_H3.md`) : `Items.required_level`, `HeroLevel.wear_block` / `lock_text` / `lock_line` (hub seulement ; départ,
Survivant, Battle royale et trouvailles de run exemptés) ; `Profile.equip(item, force)` renvoie false si refusé ; case rouge `ItemSlot.wear_check` ; `test_h3`, `shot_h3`.
**Modes scellés** (lot H2, `R_H2.md`) : `Modes.sealed()` (Survivant, Battle royale) coupe talents, certificats, plateau, archive, auras,
sorts fermés par la maîtrise et cartes à débloquer (`Run.passive_stats` / `skill_talent` / `roll_cards` / `certificate_pool`,
`Player.recalc_stats` / `knock_immune`) ; tout nouvel effet du compte en combat passe par ce test ; `test_h2`, `hl_probe --sealed`.

### Quêtes et quête commune
`core/quests.gd` (bus unique `Quests.end_run(activité, gagné, extra)` en fin de chaque mode, `Quests.event`), pool
`core/quest_pool.gd`, état `Profile.records.quests`, carte du HUD `ui/quest_badge.gd`, contrats de classe `core/contracts.gd`,
Défi du jour `core/challenge.gd`. Boussole du lobby `core/compass.gd` (`Compass.advice()`, ligne « Ta quête » `Compass.after`),
pastilles `ui/gain_chips.gd`. Détail : DESIGN « Quêtes », « La quête commune se voit » ; `R_M5.md`, `R_P6.md`.

### Interface : composants communs
- **Navigation manette** `core/ui_nav.gd` (voir « Manette et menus ») ; écrans plein cadre `ui/page_screen.gd` (`PageScreen`,
  sous-titre `subtitle()`, `_fit_header`) ; thème `ui/ui_theme.gd` (`UiTheme.Switch`, `MIN_TEXT`) ; widgets `ui/menu_widgets.gd`.
- **Bilans** : un seul composant `ui/results_panel.gd` (`ResultsPanel.show_spec` : titre, tuiles, Gagné / Gardé / Perdu, boutons),
  étendu par `ResultsScreen`, `DuelResults`, `TowerResults`, `DungeonResults`, `RoyaleResults`.
- **Petites cartes** `ui/info_card.gd` (aucune fenêtre native : `InfoCard.in_layer` / `in_control`, `add_card`, confirmation
  destructive `InfoCard.ask`) ; fiches `Tutorial.CARDS` (`short` ≤ 125 signes, `icon`, `chapter`).
- **Choix de carte** : tout passe par `world._offer` → `ui/card_picker.gd` (un clic choisit, pause tenue `PAUSE_GROUP`,
  `CardPicker.auto_pick` pour l'aide « Bot » et `--autoplay`).
- **Objets** : `Items.describe(item, detailed)` et `ItemWidgets.item_card` (Maj déplie, comparaison ▲ / ▼).
- **HUD** `ui/hud.gd` (pile `_left`, Premiers pas et fiches seulement en Survie), pause `ui/pause_menu.gd`, Guide F1 `ui/guide.gd`
  (seule aide du jeu, 6 onglets), accueil `ui/welcome.gd`, tutoriel `core/tutorial.gd`, Paramètres `ui/settings_menu.gd`.
- **Curseurs** (K1, `R_K1.md`) : `ui/cursor_sets.gd` (`CursorSets.LIST`, 9 jeux dessinés par `tools/make_cursors.py` en 32 / 48 px, points chauds générés
  `cursor_hotspots.gd`, posés par `Settings` via `Input.set_custom_mouse_cursor`), réticule de visée `ui/aim_reticle.gd` (visée Curseur / Action), aperçu `cursor_preview.gd` ; test `test_k1`.
- **Création de personnage** (C1, `R_C1.md`) : `core/hero_look.gd` (nom, coiffure, couleurs ; `Profile.hero_name / hero_look / hero_made`),
  écran `ui/hero_creator.gd` (après l'accueil, Héros > « Personnage ») ; tout modèle du héros du joueur passe le visage à
  `EdenModel.instantiate_hero(..., look)` (et `Player._dress_model`). Masque des iris : `tools/gen_eye_mask.py`. Test `test_c1`, captures `shot_c1`.
- Rapports : `R_U1` à `R_U10`, `R_P1`, `R_P3`, `R_P8`.

### Outils de mesure et de test
| Outil | Sert à |
|---|---|
| `python tools/run_tests.py` | toute la suite (voir « Tests ») |
| `python tools/sim_survie.py` | Survie au pilote automatique en parallèle (`--hub new\|E.C.N.G`, `--human`), test `test_gear_run` |
| `res://tools/progression_sim.tscn` | compte neuf de bout en bout avec les vraies formules (`--probe`, `--mult=`, `--gates`, `--trace`), bornes `test_e6` ; refonte Aventure (A7, `R_A7.md`) : `--refonte [--plans=boss] --hubvalue --decote`, jalons `kit80_ok` / `kit90_ok` / `kit90_opti` / `dungeon_0` ; niveau de héros (H7, `R_H7.md`) : `--heros [--hero-level=N --xp=a,g --mep= --mapmult=]`, bandes, `MAP_MULT`, port selon H, jalons `hero10`…`hero90` |
| `res://tools/hl_probe.tscn` | sonde du niveau de héros : puissance par carte et M′ suggéré, retard dans la bande (`--talents` : talents et certificats) |
| `python tools/boss_ttk.py` | temps pour tuer les boss (sonde `res://tools/boss_ttk.tscn`, `--dungeons`, `--human`), test `test_p11` |
| `python tools/sim_survivor.py` | Survivant au pilote (`--palier 1,2,…`, `--probe --fight` : sonde `tools/sv_build_probe.tscn`) |
| `res://tools/sv_set_sim.tscn`, `sv_cards_sim.tscn` | tirages des panoplies et des cartes du Survivant |
| `res://tools/tower_run.tscn`, `m8_tower.tscn`, `python tools/m8_matrix.py` | Tour (`--pilot=bot`, `--dodge`), facteurs par classe |
| `res://tools/m6_run.tscn` | Ruée et Siège au pilote (PE conseillée) |
| `res://tools/power_probe.tscn`, `insignia_probe.tscn`, `gear_probe.tscn` | indice d'équipement, insignes, PE |
| `python tools/journal_report.py` | règles de décision du journal de run (voir « Journal de run ») |
| `res://tools/perf_ui.tscn` | performances headless (`PERF_ARGS`, voir « Performances ») |
| `res://tools/gen_profiles.tscn` | profils « opti » du duel (voir « Duel (JcJ) ») |

## IA d'entraînement (apprentissage par renforcement)
Arène `game/scenes/ml_arena.tscn` (`game/scripts/ml/`) pilotée par Python (`ia/`, voir
`ia/LISEZMOI.md`) : `IA_Entrainer.bat`, `IA_Regarder.bat`. Le héros lit `Player.bot`
(BotInput) à la place du clavier. Ajouter ou retirer une observation dans `ml_arena.gd`
rend les modèles entraînés inutilisables (`--nouveau`). Modèles, journaux et cerveaux
(`game/data/cerveaux/`) hors git. Un seul cerveau joue les 60 classes : l'ordre de
`ML_CLASSES` (ml_arena.gd) et `CLASSES` (ia/curriculum.py) est fixe, ajouter à la fin.

État (13/10) : étapes 1 à 8 réussies (chaque classe bat le hardcore scripté à 70 % ou plus),
étape 9 « Expert » en cours ; relancer `IA_Entrainer.bat` pour continuer (il reprend seul).
Cerveaux prêts dans `game/data/cerveaux/` : debutant, facile, normal, difficile, hardcore,
actuel (`IA_Duel.bat` prend le meilleur). Brancher un adversaire IA (la Tour) :
- héros ennemi = `Player.new()` avec `foe = true`, `class_id`, `level`, `kit_skills` /
  `kit_chains` (comme `MlArena._pick_kit`), `bot = BotInput.new()`, puis `add_child` ;
- cerveau = `MlBrain.load_file("res://data/cerveaux/cerveau_hardcore.json")` ; toutes les
  3 images physiques : `obs` comme `MlArena._obs_for(foe, [joueur], fiche, dernière touche, 0)`,
  `act(obs, temperature)` puis action posée comme `MlArena._apply_for` (à extraire de l'arène
  dans une classe partagée si la Tour s'en sert). `temperature` > 0 : plus faible, plus humain ;
  ~5 ms par décision. Le cerveau est entraîné au niveau 10 sans équipement.
Exception du `.gitignore` : les 6 cerveaux du Panthéon `data/cerveaux/pantheon_<id>.json` sont dans git (`MlDuelPilot.brain_path`).

## Duel (JcJ) et profils « opti »
Deux modes depuis 0.1.137 (`Duel.bare`, lobby > Duel) : **à l'arme** (profil `duel_a` : aucune pièce ni méta, arme de
la classe, niveau 1-100 au choix, échelle 0,030, manches de 66-81 s mesurées aux niveaux 1, 10, 50 et 90) et
**équipé** (`duel_b` : échelle 0,021, dégâts +100 % et critiques ×2 au plus, bonus en % ramenés de moitié ; mesuré
53-90 s selon la paire). Dans les deux : un coup retire 15 % des PV max au plus, 35 % sur 2 s (le reste compte
×0,25). Règles lues par `ModeRules` ; essai : `--rules=duel_a|duel_b` dans l'arène d'IA.
Règles du duel dans `combat/pvp_caps.gd` (échelle des dégâts, défense relative, soins, acharnement,
plafonds) appliquées par `Combatant.take_damage` quand `Duel.active`. Profils générés :
`Godot --headless --path game res://tools/gen_profiles.tscn` (réécrit les profils « auto »: "opti"
de `data/build_profiles.json`, garde ceux du joueur ; `-- warrior` : essai sans écrire). Essai
d'équilibrage : arène d'IA en duel, `res://scenes/ml_arena.tscn -- --scenario=duel --brain=res://data/cerveaux/cerveau_hardcore.json
--episodes=4 --level=90 --hero-build=warrior:90 --foe-build=magician:90` (avec `--fixed-fps 60`).
Cible : 30 s à 1 min 30 par manche entre deux héros optimisés, à tout niveau.
Auto-attaque entre héros : × `PvpCaps.BASIC_MULT`, sans contrôle ni attraction (retour du joueur :
le crochet du Guerrier en boucle était imbattable). L'adversaire scripté prend la fiche d'un vrai
héros (`Duel.rival_sheet` : build opti de sa classe par défaut, × `ClassRival.DUEL_DIFF`) et
critique ; l'adversaire piloté par un cerveau (très fort) est prévu comme défi de fin de jeu.
Arènes / Gantelet (passe M7, `conception/nuit_15_10/R_M7.md`) : profils `arena2` (échelle 0,026) et `arena3` (0,024) de `ModeRules`,
difficulté réglable, alliés à la fiche d'un héros (`Duel.make_ally`), équipes de familles différentes (`Duel.team_classes`), arène
piégée (`Duel.hazards`), cerveau adverse en équipe (`Duel.pilot`, `MlDuelPilot.others`), réglages du duel libre rendus
(`Duel.save_free` / `restore_free`), mort subite après 90 s (`PvpCaps.SUDDEN_AFTER`). Mesure en partie réelle :
`world.tscn -- --duel --duel-mode=arena3|gauntlet3 [--hub=2.3] --autoplay --auto-quit` (lignes `[duel] manche…`).

## Journal de run
`core/run_journal.gd` écrit une ligne JSON par carte jouée dans `user://journal.jsonl`
(`%APPDATA%/Godot/app_userdata/Eden Slash/`, hors git) : style (coffres / farm / mixte), or par source
et par usage, DPS du boss sur 10 s, dégâts subis par minute, temps pour tuer, aide au combat, version.
Règles de décision (≥ 5 cartes par style et par époque) : `conception/equilibrage/raffinement_3.md`, §2.
Aucun réglage d'époque ou d'économie avant ces mesures. Test : `res://tests/test_journal.tscn`.
Le journal réel n'avait que 2 cartes de Survie à la passe E6 (`R_E6.md`) : relancer `tools/journal_report.py` quand il en aura ≥ 5
par style et par époque (les réglages d'époque actuels viennent des simulations `progression_sim`, `sim_survie`, `boss_ttk`).

## Manette et menus
`core/ui_nav.gd` (autoload UiNav) fait naviguer TOUS les menus à la manette : cadre doré qui saute au contrôle le plus proche dans la direction
(parmi ceux du calque le plus haut), A = vrai clic de souris au centre, B = Échap, X = clic droit, LB/RB = onglets (`tab_screens`, `step_page`,
TabContainer), Y = curseur libre. Aucun écran à adapter : un nouveau menu fait de Button/BaseButton est navigable tout seul (un panneau
cliquable doit avoir un signal `gui_input` relié). Test d'atteignabilité : `tests/test_nav_screens.tscn` (ajouter les nouveaux écrans).
Le cadre n'apparaît qu'après un mouvement de croix / stick (`UiNav.shown`, `reveal()` ; A le montre sans valider) ; l'aide est une barre de
3 icônes en bas à gauche (A Valider · B Retour · LB/RB Onglets, `hint_items()`), seulement quand `Gamepad.active`. Saut explicite : meta
`nav_left|right|up|down` sur un contrôle. Paramètres (0.1.167) = `SettingsMenu extends PageScreen` : lignes titre / contrôle, interrupteurs
`UiTheme.Switch`, infobulle fixe en pied (meta `hint`), plancher de texte `UiTheme.MIN_TEXT` (14) et `UiTheme.text_size()`.
Écrans à pages : doivent tenir dans 1280×720 (colonnes et panneaux réduits sous 1500 px de large, cf. `PageScreen._fit_header`,
`InventoryPage._narrow`) ; vérifier avec `tests/shot_p1.tscn` (`P1_STATE=neuf|avance P1_RES=1280x720`, lignes `[débord]` = contrôle hors écran).
Manette réassignable : `Settings.pad_binds` (`pad_bind`, `pad_label`, `pad_layout` xbox/ps), Paramètres > Touches > Manette. Export pour
Steam Link / Apple TV : `Creer_version.bat` (zip + `Jouer_plein_ecran.bat`, argument `--fullscreen`).

## Musique
`scripts/core/music.gd` (autoload Music) : pistes OGG copiées du dossier `bgm` du client
(`%LOCALAPPDATA%/EdenReforged/bgm`) dans `game/assets/music/` ; piste d'une zone = colonne bgm
de `c_node` pour sa scène d'Eden (S002 → bgm007…). Ajouter une zone : sa piste dans `Music.ZONES`.

## Graphismes
Réglages d'image communs dans `game/scripts/world/gfx.gd` (qualité graphique), shaders dans
`game/shaders/` (terrain, herbe, personnages, décor, effets). Pour comparer un changement de
rendu : `res://tests/bench_gfx.tscn -- <zone> [effet]` (même vue à chaque fois).
Auras (P16) : `python tools/fx_aura_fix.py` relit les .nif (noms des variantes, textures bloquées, masques, panneaux face caméra,
pistes sur leur propre cycle) ; à relancer après toute reconversion d'aura. Planche + relevé : `res://tools/look_audit.tscn -- auras|weapons`.
Effets de sorts à la taille de leur zone : `EdenFx.cast_scale`, `data/fx_radius.json` (par `tools/fx_measure.tscn`) ; lisibilité
`Settings.fx_factor` (jamais les zones d'attaque).

## Performances et sauvegardes (passe P2, `conception/nuit_15_10/R_P2.md`)
Mesures headless : `PERF_ARGS="--only=boot,lobby,pages,leaks,detail,run --fat" EDEN_PROFILE=<fichier> Godot --headless --path game res://tools/perf_ui.tscn`
(options par variable d'environnement : le lobby prend tout argument `--` pour un lancement de run). Test : `test_p2`. À savoir : une case d'objet
(`ItemSlot`) n'a de `_process` que si la pièce est éveillée ; `Completion.armory_ids()` est gardé dans `user://armory_cache.json` (clé = version + empreinte des
sources du tirage) ; `Profile.collected` / `outfit_unlocked` passent par un index ; `EdenModel._toon_cache` est clé par chemin de sous-ressource (pas par
`get_instance_id`) ; le titre précharge le lobby et le lobby la scène de run en tâche de fond ; `SettingsMenu` construit ses pages une par image. **Sauvegardes sûres** : tout fichier de user://
(profil, réglages, dernier emplacement, rivaux, préréglages de sorts, dev_edits) passe par `SafeFile.write/read` (`.tmp` relu et validé, ancien fichier gardé en `.bak`, repli
automatique et message sobre au lobby si le fichier principal est abîmé) ; un nouveau fichier de sauvegarde doit faire de même.

## Noms français (lot U10)
`data/names_fr.json` (anglais exact -> français : objets, panoplies, monstres, zones, apparences) est appliqué UNE fois par
`NamesFr.apply` (appelé par `GameData._ready`) : `name` devient français, l'original reste dans `name_en`. Pièce éveillée : `GameData.is_awakened(e)`
(jamais `e.name.begins_with("Awaken ")`). La table est générée par `tools/names_fr_build.py` (lexique `names_fr_lexicon.py`, `names_fr_extra*.py` ; noms
faits à la main : `names_fr_exact.py`) ; à la main, la section « overrides » du JSON l'emporte et survit à la régénération. Test : `test_names_fr`.

## Restes connus
Épreuves de maîtrise (moteur de leçons), signatures de famille, MOBA 4v4 (conçu dans `IDEES_EN_VRAC.md`, pas codé), les 39 sorts de
`conception/fx_audit.csv`, « Triple lame », images des activités et des fiches (session locale, dont la carte Quêtes),
`tools/reparer_cache_uid.py` à lancer au calme, réglages d'époque à confirmer par le journal réel. Détail par lot : rapports `R_*.md`.
