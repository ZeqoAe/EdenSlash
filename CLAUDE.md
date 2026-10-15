# Eden Slash — consignes pour les sessions Claude

Deux sessions travaillent sur ce dépôt : une **locale** (sur le PC, avec le client Eden Eternal,
extraction des assets) et une **cloud** (sans le client). Le joueur ne connaît pas git.

## Chantier en cours
Refonte des menus, mode dev, trophées, zones / monnaies / coffres : faite (0.1.22 à 0.1.26,
état en tête de `A_FAIRE_SESSION_CLOUD.md`) ; reste la validation des menus par le joueur.
Nuit du 14/10 (0.1.89 à 0.1.98) : duel équilibré à tout niveau (voir « Duel (JcJ) ») et mode farm
façon Megabonk (`DESIGN.md`, « Étapes et sources » et « Monnaies, coffres et zones ») : carte remplie
(objets à casser `world/breakables.gd`, sites, plateaux, camps, lieux à usage unique), coffres en
3 qualités qui proposent de l'équipement, run en 3 étapes (portail après le boss). Test :
`tests/test_farm.tscn` ; vues de la carte : `res://tools/map_shots.tscn -- <graine> [zone]`.
Reste : retours du joueur sur le rythme, l'économie de l'or et la lisibilité de la carte.

Menu Jouer (0.1.122) = activités (`scripts/ui/activities.gd`) : JcE (Survie = l'ancienne run de farm,
Tour, Donjons à venir, entraînement) et JcJ (Duel, Arènes 2v2 / 3v3 et Champ de bataille 10v10 à venir),
en étiquettes illustrées par les écrans de chargement d'Eden (`ui/loadingframe/loading_*.dds`, bande
y 112-452 recadrée en 960×320 dans `assets/ui/activities/`) ; un clic ouvre la page de l'activité
(réglages puis Lancer). Une activité nouvelle : une entrée dans `Activities.LIST`, son image, sa page
dans `lobby.gd` (`_show_menu`). La boucle de jeu (équipement choisi pour le JcJ, débloqué en JcE) est
en cours de refonte avec le joueur dans une autre session.
Lobby poli (0.1.169, lot U1 de la nuit du 15/10) : les pages d'activité défilent (`_scroll`) sous une largeur fixe (`PANEL_W`), le bouton d'action est épinglé dans `_foot` (`_pin`, `_pin_go` : la raison d'un bouton grisé s'écrit au-dessus) ; `MenuWidgets.RowButton` prend la hauteur de son texte ; pied de page sur une ligne ; les activités « Bientôt » sont cachées ; fiche d'étage de la Tour sans chiffres (`TowerPages.Sheet`). `test_pages` vérifie largeur, hauteur et bouton visible de chaque page.
Survie refondue (0.1.123 à 0.1.125, décisions dans `DESIGN.md`, « Boucle de jeu et Survie ») :
époques (`core/epochs.gd`), coffres d'emplacement (`core/slot_chests.gd`), enclume par emplacement
(`Run.slot_bonus`), Collection > Armurerie (`ui/gear_shop_page.gd`, `Profile.seen_gear`, `Profile.insignia`).
**0.1.164 : la Survie part avec l'ÉQUIPEMENT DU HUB** (elle ne part plus « sans équipement » : décision du joueur du 15/10,
détail dans `DESIGN.md` et `conception/nuit_15_10/N1_survie_equipement.md`). `Profile.begin_run` copie l'équipement du préréglage
actif et prend un instantané (`_hub_snapshot`) que `Profile.end_run_survival` restaure (`restore_hub_gear`) ; la sauvegarde en pleine
run écrit toujours le hub (reprise propre après fermeture). Les coffres d'emplacement remplacent un emplacement le temps de la run.
Compte neuf : `core/starter_gear.gd` (8 pièces d'Eden communes à rares par classe, remises une fois : `Profile.starter_done`).
Enclume additive : bonus +0 à +7 AJOUTÉ au +N du hub, total plafonné à +12 (`Run.UPGRADE_CAP`, `Run.slot_upgrade`). Gemmes : valeurs plates
suivant le niveau du héros en Survie (`Craft.gem_run_factor`). Insignes : 25 de participation (`Run.INSIGNIA_BASE`). Premiers niveaux
plus rapides (`Epochs.xp_boost`), début de carte plus doux (`EARLY_EASE` / `EARLY_RAMP`). Mesures : `tools/sim_survie.py`
(pilote automatique en parallèle, EDEN_PROFILE jetable, `--hub new|E.C.N.G`, `--human`), test `test_gear_run`.
Lot E4 (nuit du 15/10, rapport `conception/nuit_15_10/R_E4.md`) : coffre de cape (`SlotChests.BOXES.back`, enclume comprise) ; une arme
choisie en Survie découvre les armes des 17 types au palier de la carte (`SlotChests.weapon_family`, `Run.seen_family`) ; fournitures au
niveau des pièces de la carte (`RunDirector.supply_level`), gemmes +1 rang par époque (`gem_level`). Test `test_e4`.
Armes refondues (0.1.127-0.1.128, `DESIGN.md`, « Auto-attaque des armes ») : plus de combo, deux
variantes d'auto-attaque par type d'arme (`combat/weapon_attacks.gd`), arme principale = arme de la
classe, arme secondaire trouvée en jeu (`Profile.equipped.offhand`, `SlotChests.offhand_offer`,
`Player._update_offhand`), cartes d'amélioration d'arme (`Run.weapon_ups`, `WeaponAttacks.roll_upgrade`).
Trophées (0.1.130) : plus de l'équipement, collection de la run (`Run.trophies`, 12 au plus, effets
tous différents, 67 effets dans `Trophies.KINDS`, répartis sur les trophées d'Eden par
`tools/rework_trophies.py` : relancer l'outil après l'ajout d'une famille).
Reste : retours du joueur sur l'équilibrage (époque 1 gagnée « bien capé » le 14/10, il passe à l'époque 2).
Lots 1 et 2 de `conception/CONCEPT_FINAL.md` faits (0.1.132 à 0.1.134) : corrections, puis prise en main
(mémoire des touches, maintien, visée au sol aimantée, anneau d'annulation, Aide au combat en 4 niveaux).
Lots 3 et 4 faits (0.1.135-0.1.136) : journal de run (`core/run_journal.gd`) et socle des modes
(`core/modes.gd` : `Modes.current()` déduit des drapeaux ; `core/mode_rules.gd` : profils de règles, à ce jour
la famille JcJ de `PvpCaps` ; `core/modifiers.gd` : table de modificateurs ; mode dev -> `dev_edits.json`
« modes » ; arène d'IA `--rules=duel_a`). Les autres familles (monstres, héros, gains) entrent dans les
profils quand leur consommateur est branché ; les tests `Tower.active` / `Duel.active` dispersés restent.
Reste du lot 1 : « niveau minimum 10 » du Duel (`Duel.gear_level`), à faire avec le lot 5 (échelle des
dégâts en même temps) ; insensibilité aux renversements des 11 certificats (B10, non codée). Lot 5 fait (0.1.137) sauf : coups réduits par la rafale non affichés en gris, Ligue/Panthéon/Gantelet (lots 14-15).
Lot 6 fait (0.1.138) : garde-fous (Élan meurtrier 0,15 s et 1,5 s rendues par seconde, trophées « à l'impact » 5 s,
Lame large +98 % au plus, projectiles en plus normalisés et plafonnés à +4, Exécuteur retiré au plafond), classes à
majorité de sorts magiques = classes magiques (`GameData._balance_damage_types`, 20 classes), arme qui grandit (poids ×2,3,
amélioration garantie au boss, effet légendaire au niveau 4), facettes d'amélioration de sort (plus de cartes de classe).
Les profils « opti » (`gen_profiles`) n'ont PAS été régénérés (le générateur n'est pas déterministe et ça décalerait le
réglage du duel équipé) : à relancer plus tard pour les 20 classes reclassées. Lot 7 fait (0.1.139) : coffres lisibles (aperçu du contenu, « Ouvrir tout », récapitulatif, plus de pièce possédée proposée),
autel en insignes et coffres d'apparence (plus d'équipement), bilans avec « Rejouer » (Survie, Duel, Tour) et bloc Gardé / perdu.
Lot 8 fait (0.1.140) : fil d'éveil `core/unlocks.gd` (conditions, entrées gardées pour toujours dans
`Profile.unlocked_features`, migration d'une ancienne sauvegarde, mode dev = tout ouvert), boutons et cartes d'activités grisés avec
leur condition, menu Atelier (Armurerie) / Carnet (Collection), ressources dans le pied du lobby, squelette de la Ligue
(`core/league.gd`, rangs 0-4). Le Guide F1 vient avec le lot 9. Lot 9 fait (0.1.141) : `core/tutorial.gd` (10 Premiers pas validés par événements de jeu, 16 fiches à la 1re rencontre, nouveautés par
version, état dans `Profile.tutorial`), accueil `ui/welcome.gd` (3 départs, 5 classes, contrôles et aide), panneaux Premiers pas / fiche
dans le HUD, Guide `ui/guide.gd` (F1), touches rangées en 4 groupes avec test de touche. Les fiches de lieux (scribe, fontaine…) et
les images des fiches restent à écrire. Lot 10 fait (0.1.142) : page Jouer en 3 rangées (Aventure, Défis, Affrontements) avec Arènes fusionnées, Défi de maîtrise
(`core/challenge.gd` : 2 modificateurs du jour câblés en Survie, 3 classes, maîtrise ×2, +600 la 1re fois, insignes ×1,5), contrats de
classe (`core/contracts.gd`, remplis à chaque Survie), reprise de la Tour (palier de 10 étages, kit complet + cartes). Épreuves de maîtrise
restent « Bientôt » (pas de moteur de leçons ; la Ruée des boss est faite depuis 0.1.152). Lot 11 fait (0.1.143) : Carnet = Vue d'ensemble (`core/completion.gd`, 10 catégories), Succès et titres (`core/achievements.gd`, 40 succès
accordés pour le passé, titres à porter), Grimoire des cartes, Codex des trophées, Collection (`ui/carnet_pages.gd`). Pas encore : signatures de
famille, apparences/auras en onglets, statistiques. Lot 12 fait (0.1.144) : ciblage par camp (groupe « heroes » = joueur + alliés IA ; `Combatant.hostile_targets` pour les coups au sol, projectiles et
zones ; les monstres visent le héros hostile le plus proche, réévalué toutes les 0,5 s) et allié scripté (`ClassRival.ally`, soigne sous 50 % de PV,
pose ses renforts). Les cerveaux ne sont pas alliés (ils ne voient pas leurs équipiers). Lot 13 fait (0.1.145) : Donjons (`core/dungeons.gd`) : un par zone, 4 salles (monstres, élites, monstres, boss) sur le moteur de salles de la Tour
(`Tower.dungeon`, mode « dungeon »), équipement synchronisé, kit du préréglage, une carte par salle, 0 à 2 alliés IA, Normal / Héroïque (+15) /
Mythique (90), butin (coffre de set, cristaux, plan 10 %). Pas encore : panoplies-archétypes des donjons, système de fabrication des plans (ils
sont collectés), mécaniques propres à chaque boss de donjon (ceux de la Survie sont réutilisés), salle de repos. Lot 14 fait (0.1.146) : Duel en trois onglets (Libre, Ligue, Panthéon). Ligue (`core/league.gd`) : rangs Bronze à Platine, 3 victoires d'affilée par rang,
à l'arme niveau 10, aide limitée à Assisté, maîtrise par duel. Panthéon (`core/pantheon.gd`) : 6 cerveaux dans l'ordre, panoplie des Esprits
(`Items.SETS.pantheon`, effets à 2/4/6 pièces, jamais en duel à l'arme), coffres d'apparence et d'auras (`aura_rare`, `aura_legend`), titres, éveil par
les 5 familles. Pas encore : cerveaux figés dans git (ils restent hors git : `data/cerveaux/cerveau_<id>.json`), aura exclusive du Champion, Gantelet
(lot 15). Lot 15 fait (0.1.147) : Arènes 2v2 / 3v3 à alliés IA (activité Arènes, à l'arme niveau 10, `DuelDirector` en équipes : `_foes`, `_allies`, le joueur tombé
laisse ses alliés finir la manche ; profils `arena2` 0,022 et `arena3` 0,018, soins ×0,5) et Gantelet (onglet du Duel, 1 contre 2 ou 3, équipé, rang Or de la Ligue).
Un seul cerveau adverse n'est pas encore branché dans les équipes (adversaires scriptés seulement). Lot 16 fait (0.1.148) : étoiles d'époque (3 par époque : victoire, sans résurrection, défi de l'époque ; `Epochs.stars`, `Run._award_stars`), rangs
héroïques 1 à 10 après l'époque IV (monstres +12 % PV et +8 % dégâts par rang, une contrainte de plus tous les 3 rangs, insignes +15 % par rang,
coffre d'apparence aux rangs 3, 6 et 9, titre au rang 10), et `tools/journal_report.py` : applique les règles de décision du journal de run
(≥ 5 cartes par style et par époque) ; AUCUN réglage d'époque ou d'économie n'a été fait : il faut d'abord jouer des cartes en Survie.

Les 16 lots de `conception/CONCEPT_FINAL.md` sont codés. Restes traités (0.1.151) : Duel équipé dès le niveau 1 (`Duel.gear_level`), certificats
« insensible aux renversements » (`Player.knock_immune`, ignore `stun`), coups réduits par le plafond du duel affichés en gris « (max) »
(`DamageNumber.spawn(..., capped)`), profils « opti » régénérés (`gen_profiles`, les 60 classes), 6 cerveaux du Panthéon figés dans git
(`data/cerveaux/pantheon_<id>.json`, exception du `.gitignore` ; `MlDuelPilot.brain_path` les prend quand `Duel.mode == "pantheon"`),
cerveau adverse en équipe (Arènes et Gantelet : sélecteur « Premier adversaire » du lobby, `Duel.pilot`, victoire de manche seulement
quand le cerveau ET les scriptés sont à terre).
Panoplies de donjon (0.1.152, B9) : chaque donjon a un archétype (`Dungeons.ARCHETYPES` : Tempête, Givre, Lame sanglante, Faucon, Phénix, Vent,
+ `salvo` Salve et `rampart` Rempart dans `Items.SETS`) ; son coffre de set porte `archetype`, les 3 pièces proposées aussi (`item.archetype`) et
comptent pour 2 / 4 / 6 en plus du set d'Eden (`Items.set_counts`). Fabrication (Atelier, `ui/fabrication_page.gd`) : un plan de donjon
(`Profile.plans`) permet de fabriquer une pièce de la panoplie contre des cristaux (60 × difficulté), mythique (légendaire si le donjon est fini
en Mythique). Ruée des boss (0.1.152) : « zone » `Dungeons.RUSH` du moteur de donjon (`Tower.rush`) : 8 salles = les boss des 8 zones, une carte
entre deux, soin partiel ; cristaux à chaque boss, coffre d'équipement + d'apparence (1re fois) et titre à la fin (`Dungeons.rush_reward`) ; débloquée
avec les Donjons. Tests : `test_lot17` (restes), `test_lot18` (panoplies, fabrication, Ruée).
Restes : Épreuves de maîtrise (moteur de leçons), signatures de famille, images des activités et des fiches (session locale).
Idées en vrac du joueur (15/10, 0.1.153 à 0.1.158, classement et état dans `conception/IDEES_EN_VRAC.md`) : options de lisibilité des effets
(`Settings.fx_factor`, jamais les zones d'attaque), Roulette quotidienne (`core/wheel.gd`, Coffres > Roulette), puissance d'équipement
(`core/gear_power.gd` : verrous Héroïque / Mythique des donjons et butin légendaire), potions (`core/potions.gd`, touches C / V), Forge unifiée
(`ui/forge_bench.gd`, Atelier > Forge), file d'attente du Duel (`ui/duel_queue.gd`), effets de sorts mis à la taille de leur zone
(`EdenFx.cast_scale`, `data/fx_radius.json` par `tools/fx_measure.tscn`). Le Siège (0.1.161, `core/siege.gd`, `core/siege_director.gd` qui prolonge `TowerDirector`, `Tower.siege`, test `test_siege`) : joueur + 2 alliés IA,
5 vagues, boss (fureur 6 min), anneau de 20 s, cœur au centre, chacun pour soi à trois (`Combatant.set_ffa`, `Siege.ffa` = règles JcJ, profil
`siege` de `ModeRules`) ; dernier debout = coffre `look_legend`, cœur emporté = `look_epic`. Reste : Battle royale, MOBA 4v4 (conçus dans le
même fichier, pas codés), les 39 sorts de `conception/fx_audit.csv`, « Triple lame ».
Pacte, géants et Menace (0.1.191, P12, `DESIGN.md`) : `core/menace.gd` (Menace : PV des monstres et boss +20 % par géant vaincu, plafond 5,
remise à zéro dans `RunDirector.start`), `world/giant_altar.gd` (2 autels par carte, `--giants=N` pour le pilote auto), `ai/giant_monster.gd`,
`ui/menace_badge.gd` ; crochets d'une ligne dans `RunDirector` (`_spawn_monster(..., into)`, `Menace.apply`) et `Run.finish`. Test : `test_p12`.
Boss (0.1.192, P11, `DESIGN.md` « Boss : PV fixes et rage du boss », R_P11) : PV FIXES, jamais d'après le niveau ou la PE du héros
(Survie : `Epochs.boss_hp` = `BOSS_HP_MAP` × `BOSS_HP_EPOCH`, rage du boss `Epochs.BOSS_RAGE_AT` ; donjons, Ruée, Siège : `Dungeons.boss_hp`).
Mesure : `tools/boss_ttk.py` (sonde `res://tools/boss_ttk.tscn`, scénarios rush / moyenne / bonne / dorée, `--dungeons`, `--human`). Test : `test_p11`.
Battle royale (0.1.161, idée 9, détail dans `conception/IDEES_EN_VRAC.md`) : `core/royale.gd` (état, calendrier de l'anneau, héros scriptés,
récompenses) et `core/royale_director.gd` (carte `ProcMap.generate_royale`, 7 `ClassRival` qui pillent / fuient l'anneau / se battent via `ClassRival.goal`,
coffres du joueur, anneau visible). Le « chacun pour soi » est général : `Combatant.ffa_id` / `set_ffa()` / `clear_ffa()` + groupe « ffa » (le Siège s'en sert aussi).
Activité Battle royale dans JcJ (verrou `royale` : Ligue Argent). Test : `tests/test_royale.tscn` ; partie complète en pilote automatique :
`world.tscn -- --royale --autoplay` (ligne de suivi `[royale]` toutes les 15 s, `--royale-diff=0..3`).
Survivant (en chantier, lots S1-S8 de `conception/survivor/` : `SPEC.md` corrigé par `DECISIONS_JOUEUR.md` qui prime) : socle S1 (0.1.194)
`core/survivor.gd` (état, `Survivor.start`, hub jamais modifié : `HUB_KEYS` + `hub_save`) et squelettes `survivor_{pool,gear,cards,director,rewards}.gd`
branchés par des crochets `Survivor.active` / `sv` (`run_director.gd`) ; activité visible en mode dev (`Survivor.READY`) ; `world.tscn -- --survivor` ; test `test_sv1`.
S2 pièces et arme : `SurvivorPool` (13 sets de niveau 90, bonus 2/3/5 via `Items.set_def` en Survivant), `SurvivorGear` (stats d'origine, qualité 100-120 %,
passif fixe `fixed_passive` + paliers tirés à la proposition `upgrade_offer` / `apply_upgrade`, `equip` verrouillé à vie, `weapon_offers`) ; `test_sv2`, `tools/sv_set_sim.tscn`.
S3 cartes : `SurvivorCards` (`roll` : équipement + sort garantis, poids `w_*`, pitié ; `first_offer` armes / compétences ; `chest_cards` ;
bannir / garder / Passer ; `auto_pick`) ; rien du compte (talents, certificats, maîtrise) ; `test_sv3`, `tools/sv_cards_sim.tscn` (builds, 5/5).
S4 déroulé : `SurvivorDirector` (`timeline()` gardiens 5/10/15 min, portail 15:00, arène forcée 20:00 ; `spawn_plan(t)` courbe des monstres,
prise par le `spawner` de P15 s'il existe ; gardiens et boss à PV fixes ; 30 coffres `BOXES` -> `SurvivorCards.chest_cards`) ; `test_sv4`.
Matières des activités (0.1.165, lot E1 de la nuit du 15/10, `DESIGN.md` « Matières et cristaux des activités ») : `core/activity_loot.gd`
(cristaux et coffres de forge / du joaillier au niveau des Donjons, de la Ruée, du Siège et de la Tour, avec `focus` des coffres dans
`Rewards`), `Forge.GOLD_PER_CRYSTAL` = 125, compteur d'Armurerie calculé (`Completion.armory_total`), plus de coffre de trophées. Test : `test_loot`.
Lot E2 (nuit du 15/10, `DESIGN.md` « Maîtrise et insignes du JcJ… ») : maîtrise du JcJ par `League.mastery_for` / `pvp_mastery`,
insignes JcJ plafonnés au jour (`League.win_insignia`, `royale_insignia`), plan sûr au 1er donjon de chaque difficulté, fabrication sur 9
emplacements, Siège Normal sans PE ; panoplie des Esprits : modèles fixes niveau 70 dans `GameData.eden_by_id` (`Pantheon.shop_id`, `sync_seen`), éveil = `Items.SETS.pantheon.awake`.
Lot E5 (nuit du 15/10, `core/economy.gd`, `R_E5.md`) : barème des insignes (`Economy.survival_insignia`, cibles `INSIGNIA_PER_HOUR`), Armurerie à paliers
(`GearShopPage.price` = `Economy.armory_price`), puits `buy_chest` / `buy_lesson` (pas encore de bouton), maîtrise : rattrapage, 1re victoire par époque
(`Run.first_win_bonus`), part de l'arbre dans `Profile.add_expertise` (`last_shared`). Test `test_e5`, chiffres : `res://tools/insignia_probe.tscn`.
Infobulles d'objets (0.1.172, lot U6 de la nuit du 15/10) : `Items.describe(item, detailed)` (carte courte : stat principale en gros, 5 lignes, passif,
gemmes, panoplie x / N ; complète : tout) et `ItemWidgets.item_card` (suit Maj, comparaison ▲ / ▼ avec la pièce portée, enclume de Survie comprise) ;
test `test_tooltips`, captures `tests/shot_tips.tscn`.
Atelier poli (nuit du 15/10, lot U5, `conception/nuit_15_10/R_U5.md`) : bourse commune (`ui/workshop_purse.gd`), Armurerie = catalogue entier
filtrable (statut / emplacement / époque / classe, silhouettes « à découvrir », `Completion.armory_ids` donne l'époque), Fabrication en cartes par
donjon, Forge = un panneau avant → après (`ForgeBench`, `MerchantPages.ForgePage.ba_table`), fusion de gemmes au taux 25 (`Forge.fuse_price`).
Test : `tests/test_workshop.tscn` ; captures : `tests/shot_atelier.tscn`, `tests/shot_merchant.tscn`.
Passe P3 « HUD en jeu » (0.1.181, `conception/nuit_15_10/R_P3.md`) : la pause n'a plus d'onglet Aide mais un bouton « ? Aide » qui ouvre le Guide
(`PauseMenu.open_guide`) ; bilan animé (`ResultsPanel` : nombres qui montent, meilleur gain doré, `finish_now` sur une touche) ; chiffres de
dégâts rangés en colonnes avec budget par 0,3 s (`DamageNumber`) ; bandeau d'annonce en dégradé, cadre de boss large, titre du HUD en
deux morceaux (`Hud.zone_parts` : le « 1 » de la police des titres se lit comme un I) ; cartes de niveau à couleur de rareté (commune = gris).
Captures : `tests/shot_p3.tscn -- stage=N boss_at=S guide_at=S` (+ arguments du monde), variable `P3_RES=1280x720`, APPDATA détourné.
La quête commune se voit (0.1.186, passe P6, `DESIGN.md` « La quête commune se voit ») : boussole du lobby `core/compass.gd` (un conseil cliquable calculé depuis le compte, `Compass.advice()` ; ligne « Ta quête » des bilans `Compass.after`), pastilles de gains des activités (`Activities.LIST` clé `gives`, `ui/gain_chips.gd`), « où l'obtenir, où le dépenser » de chaque ressource (`core/resource_help.gd`). Test : `test_compass`. Une activité ou une ressource nouvelle : une entrée dans `ResourceHelp.KINDS` / `gives`, et un cas dans `Compass` si elle change la quête.
Quêtes (passe M5, `DESIGN.md` « Quêtes ») : le Défi de maîtrise est devenu la quête « Défi du jour » de `core/quests.gd` (pool
`core/quest_pool.gd`, page Jouer > Quêtes `ui/quests_page.gd`, carte du HUD `ui/quest_badge.gd`) : 3 quêtes par jour, 2 par semaine, relance,
série à paliers cosmétiques, contrats de classe listés dessous. Bus unique : `Quests.end_run(activité, gagné, extra)` en fin de chaque mode,
`Quests.event("zone_hit" | "chest_open")` ; état dans `Profile.records.quests`. Une activité nouvelle : une entrée dans `QuestPool.ACTS` et des quêtes.
Atelier de conception (0.1.131, dossier `conception/`) : 5 équipes, réponses du joueur dans
`REPONSES_JOUEUR_1.md` (font foi). **Référence pour coder : `conception/CONCEPT_FINAL.md`**, dont la
section 9 donne les lots dans l'ordre (lot 1 corrections, lot 2 prise en main : mémoire des touches,
aide au combat en 4 niveaux ; lot 5 Duel à l'arme / équipé…). Le détail de chaque lot est dans
`conception/<équipe>/raffinement_3.md`.

Carnet (nuit du 15/10, lot U7, rapport `conception/nuit_15_10/R_U7.md`) : onglets construits par `CarnetPages.tabs()` (en ajouter un à la fin : la
Collection garde l'indice 4) ; chaque page donne son sous-titre par `subtitle()` (lu par `PageScreen`, rétrocompatible) ; Carnet > Cartes = compteurs +
lien vers Héros > Cartes (pas de doublon) ; vue d'ensemble = bandeau + 10 cartes cliquables, plus de « Déblocages » ; plus aucune mention d'Eden côté joueur.

## Entrée du jeu et Guide (lot U2)
Écran titre sans texte de zone ; accueil `ui/welcome.gd` en 3 écrans (départ, classe avec ses 3 sorts, contrôles + aide) qui tient dans la
fenêtre à toute taille ; Guide F1 `ui/guide.gd` (un `PageScreen`) = seule aide du jeu, 6 onglets (Commandes, Cartes, Survie, Équipement, Modes,
Détails = l'ancienne `InfoPage`) bâtis depuis les touches réelles, `Tutorial.CARDS` (champ `chapter`) et `Activities.LIST` (rôles dans `Guide.ROLES`).
Premiers pas seulement en Survie (`Modes.current()`). Fiche nouvelle : une entrée de `Tutorial.CARDS` avec son chapitre ; `on: ""` + version = annoncée
aux anciennes sauvegardes. Test : `test_lot9` (tailles de fenêtre comprises), captures `tests/shot_u2.tscn` (`SHOT_TAG=1280x720`).
Petites cartes d'information (passe P8, `ui/info_card.gd`, `conception/nuit_15_10/R_P8.md`) : plus aucune fenêtre native. `InfoCard.in_layer(host)` (lobby, calque 118) /
`InfoCard.in_control(parent)` (HUD) = pile de cartes de 400 px à droite, `add_card({id, title, body, icon, kicker, buttons, duration, hint})` ; B / Échap / croix la ferment
(lobby ; en jeu L3 / R3), le cadre de `UiNav.focus()` va sur le bouton principal puis revient où il était. Confirmation destructive : `InfoCard.ask(...)` (centrée, compacte,
« Annuler » préselectionné ; `PauseMenu.Confirm` et `DevPages.confirm` l'utilisent). Une fiche : `short` (≤ 125 signes) + `icon` dans `Tutorial.CARDS` ; `Tutorial.card_spec`, `news_sorted`.
Tests : `test_p8`, `test_nav_screens` (cartes du lobby, de la confirmation et du HUD), `test_lot9` ; captures `tests/shot_p8.tscn`.

## Écran Héros (lot U4, `conception/nuit_15_10/R_U4.md`)
Équipement : `InventoryPage` + `EquipmentPage.PresetBar` (3 préréglages, « Gérer » copie / renomme ; `preset_bar.extra_actions` = point d'entrée de
« Équiper le meilleur » et « Appliquer à la famille »), fiche d'objet cachée sans sélection avec la pièce portée à côté. Classe : `TalentsPage` en
sous-onglets (`show_sub` : spells, talents, certs), un sort cliqué ouvre `Grimoire.open(classe, id)`. Apparence : « Débloqués uniquement » par défaut.
« ? » ouvre le Guide (Détails). Captures : `res://tests/shot_hero.tscn` (APPDATA détourné). Tests : `test_pages` (section Héros), `test_nav_screens`.

## Choix de carte, coffres, roulette (lot U3, `conception/nuit_15_10/R_U3.md`)
`CardPicker` : un clic / 1-2-3 choisit (`_choose`, délai anti-rafale 0,3 s, cartes voilées), plus de Valider. Coffres : `Rewards.kind_of / kind_name /
kind_blurb` (type + spécialité), pastille `_badge`. Roulette : `Wheel.board()` = l'apparence promise par chaque case (gardée dans `Profile.wheel.board`),
`WheelPage` fige la planche jusqu'à la fin de l'annonce du gain (3 s). Captures : `shot_chests.tscn`, `shot_cards.tscn` ; test : `test_u3`.

## Journal de run
`core/run_journal.gd` écrit une ligne JSON par carte jouée dans `user://journal.jsonl`
(`%APPDATA%/Godot/app_userdata/Eden Slash/`, hors git) : style (coffres / farm / mixte), or par source
et par usage, DPS du boss sur 10 s, dégâts subis par minute, temps pour tuer, aide au combat, version.
Règles de décision (≥ 5 cartes par style et par époque) : `conception/equilibrage/raffinement_3.md`, §2.
Aucun réglage d'époque ou d'économie avant ces mesures. Test : `res://tests/test_journal.tscn`.
Passe E6 (`conception/nuit_15_10/R_E6.md`, DESIGN.md « Équilibrage global ») : simulation d'un compte neuf avec les vraies formules
`res://tools/progression_sim.tscn` (`--probe`, `--mult=1,1.7,3.4,7`, `--skill=`, `--trace`) ; bornes dans `tests/test_e6`. Le journal réel
n'a encore que 2 cartes de Survie : relancer `tools/journal_report.py` quand il en aura ≥ 5 par style et par époque.
Passe P5 (`R_P5.md`) : verrous de PE recalés sur la PE simulée (`GearPower.DIFF_RATIO` 0 / 3,6 / 3,1, `Siege.POWER_RATIO` 0 / 4 / 3,4,
`LEGEND_RATIO` 1,8 ; `progression_sim -- --gates` : PE requise par zone ; jalons `open_*` / `legend_*`), époque I adoucie (monstres ×0,85),
infobulle des insignes du bilan = `Run.insignia_parts`. Jauge de PE des pages Donjon / Siège / Ruée : `Lobby._pe_gauge`.

## HUD, pause et bilans (0.1.180, lot U9)
Un seul composant de bilan, `ui/results_panel.gd` (`ResultsPanel.show_spec` : titre, tuiles, blocs Gagné / Gardé / Perdu, boutons) ; `ResultsScreen`
(Survie), `DuelResults`, `TowerResults`, `DungeonResults` (donjon, siège, ruée) et `RoyaleResults` l'étendent et ne font que bâtir la description.
HUD : pile en haut à gauche (`Hud._left` : objectifs, Premiers pas, butin), Premiers pas et fiches seulement en Survie (`_survival_mode`), « AUTO » sur case
remplie, FPS et touches de test cachés (« F1 : aide » 10 s au début). Pause : cases occupées seulement, confirmations stylées (`PauseMenu.Confirm`, `leave_texts`).

## Manette et menus
`core/ui_nav.gd` (autoload UiNav) fait naviguer TOUS les menus à la manette : cadre doré qui saute au contrôle le plus proche dans la direction
(parmi ceux du calque le plus haut), A = vrai clic de souris au centre, B = Échap, X = clic droit, LB/RB = onglets (`tab_screens`, `step_page`,
TabContainer), Y = curseur libre. Aucun écran à adapter : un nouveau menu fait de Button/BaseButton est navigable tout seul (un panneau
cliquable doit avoir un signal `gui_input` relié). Test d'atteignabilité : `tests/test_nav_screens.tscn` (ajouter les nouveaux écrans).
Choix en run (0.1.193, P13) : tout passe par `world._offer` -> `CardPicker` ; le choix tient la pause (groupe `CardPicker.PAUSE_GROUP`,
`ScreenFade` aussi : un fondu ne relance pas le jeu sous un choix), cadre de la manette sur la 1re carte ; aide « Bot » et `--autoplay` :
`CardPicker.auto_pick` (équipement compris). Teinture : `EdenModel.dress` marque chaque maillage (`meta part`), accessoires rigides compris.
Écrans à pages : doivent tenir dans 1280×720 (colonnes et panneaux réduits sous 1500 px de large, cf. `PageScreen._fit_header`,
`InventoryPage._narrow`) ; vérifier avec `tests/shot_p1.tscn` (`P1_STATE=neuf|avance P1_RES=1280x720`, lignes `[débord]` = contrôle hors écran).
Manette réassignable : `Settings.pad_binds` (`pad_bind`, `pad_label`, `pad_layout` xbox/ps), Paramètres > Touches > Manette. Export pour
Steam Link / Apple TV : `Creer_version.bat` (zip + `Jouer_plein_ecran.bat`, argument `--fullscreen`).

## Équipement des 60 classes (0.1.178, lot E3)
`core/class_gear.gd` : 7 profils de stats (`data/class_profiles.json`, régénérer avec `python tools/gen_class_profiles.py`), « Équiper le meilleur »,
« garder mes choix », « Appliquer à la famille », annulation (menu Gérer de Héros > Équipement), fiche du Registre (`ui/registry_page.gd`, dernier onglet
du Carnet ; bandeau « N / 60 classes équipées » du lobby). La PE affichée reste sans profil (`Items.rating(item)`). Test : `test_e3`.

## Branche
Tout se passe sur la branche `claude/optimistic-gauss-p2g2pq`. Ne pas travailler sur `master`.

## Numéro de version (obligatoire à chaque envoi)
À **chaque push** :
Le cadre n'apparaît qu'après un mouvement de croix / stick (`UiNav.shown`, `reveal()` ; A le montre sans valider) ; l'aide est une barre de
3 icônes en bas à gauche (A Valider · B Retour · LB/RB Onglets, `hint_items()`), seulement quand `Gamepad.active`. Saut explicite : meta
`nav_left|right|up|down` sur un contrôle. Paramètres (0.1.167) = `SettingsMenu extends PageScreen` : lignes titre / contrôle, interrupteurs
`UiTheme.Switch`, infobulle fixe en pied (meta `hint`), plancher de texte `UiTheme.MIN_TEXT` (14) et `UiTheme.text_size()`.
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
Passe P9 (0.1.189, notes) : rage en paliers ×1,1 / ×2 / ×11 / ×101 par minute (`RunDirector.RAGE_TIERS`), horde qui suit vraiment
son chemin (`Monster._path_step`, `tests/test_pursuit`), pièce portée jamais reproposée (`SlotChests.worn_eden`), cadenas des activités.

## Tests
`Godot --headless --path game res://tests/<test>.tscn` pour test_build, test_hud,
test_controls, test_cards, test_progress (et ceux ajoutés depuis). Après l'ajout d'un
script avec `class_name`, lancer une fois `--import` pour mettre à jour le cache des classes.
Intégration (passe P4, `conception/nuit_15_10/R_P4.md`) : `test_p4_flow` (hub de bout en bout, sans changer de scène),
`test_p4_activities` (chaque activité lancée depuis le lobby, jouée, bilan, retour ; ~7 min ; `-- duel,tower` pour un
sous-ensemble) et `test_p4_migration` (vieilles sauvegardes ; `P4_REAL_SAVES=<dossier>` charge aussi de vrais profils).
Français (passe P10) : `test_texts_fr` signale tout mot anglais lisible par le joueur (objets, passifs, sorts, talents, cartes, trophées…) ;
un nom d'Eden nouveau passe par `data/names_fr.json` (`tools/names_fr_build.py`, lexique `names_fr_extra5.py`, talents `names_fr_talents.py`).
Toute la suite d'un coup : `python tools/run_tests.py [-j 4] [-r 3] [mot du test...]` (copie propre de HEAD, un dossier utilisateur par
exécution, tableau vert / rouge ; `-r 3` cherche les tests instables ; `--reuse` garde la copie, `--live` teste le dossier de travail).
Les tests de simulation (`test_siege`…) attendent des événements, jamais des durées (`_wait` en images de physique, cartes fermées d'office).
Plusieurs sessions dans le même dossier : lancer la suite sur une copie de `game/` avec `config/custom_user_dir_name` à part.

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

## Musique
`scripts/core/music.gd` (autoload Music) : pistes OGG copiées du dossier `bgm` du client
(`%LOCALAPPDATA%/EdenReforged/bgm`) dans `game/assets/music/` ; piste d'une zone = colonne bgm
de `c_node` pour sa scène d'Eden (S002 → bgm007…). Ajouter une zone : sa piste dans `Music.ZONES`.

## Graphismes
Réglages d'image communs dans `game/scripts/world/gfx.gd` (qualité graphique), shaders dans
`game/shaders/` (terrain, herbe, personnages, décor, effets). Pour comparer un changement de
rendu : `res://tests/bench_gfx.tscn -- <zone> [effet]` (même vue à chaque fois).

## Performances (passe P2, `conception/nuit_15_10/R_P2.md`)
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

