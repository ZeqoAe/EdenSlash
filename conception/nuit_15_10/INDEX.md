# Index des rapports de la nuit du 15/10/2026 (et du Survivant)

Une ligne par document : ce qu'on y trouve, version publiée. Le contenu de chaque lot est aussi résumé dans `CHANGELOG.md` ;
les règles de jeu qui en sortent sont dans `DESIGN.md`, les points d'entrée du code dans `CLAUDE.md` (« État du jeu »).
Lots : N = décision du joueur, A = audits, E = économie / progression, U = interface, P = passes de peaufinage, M = modes,
S = Survivant (`conception/survivor/`).

## Pilotage
| Document | Contenu |
|---|---|
| `PLAN_NUIT.md` | règles communes des sessions de la nuit (dépôt partagé, commits ciblés, textes joueur, relecture), file des chaînes U et E |
| `STATUT_NUIT.md` | tableau des lots (exécutant, statut, version), plan de l'orchestrateur et restes |
| `RAPPORT_MATIN.md` | bilan pour le joueur des versions 0.1.165 à 0.1.185 |
| `INDEX.md` | ce fichier |

## Décision et audits
| Document | Contenu |
|---|---|
| `N1_survie_equipement.md` | la Survie part avec l'équipement du hub (instantané / restauration, `StarterGear`, enclume additive, gemmes, insignes de participation) — 0.1.170 (« 0.1.164 » dans le texte : numéro jamais publié) |
| `A1_progression.md` | audit de la « quête commune » de progression (jeu 0.1.163) : problèmes I1-I14, lots A1-A6 / B1-B6 (§5.4) |
| `A2_interface.md` | audit visuel et ergonomique (0.1.163) : texte superflu (§6), lots L1-L10 (§8) = U1-U10 |

## Chaîne E — économie et progression
| Rapport | Contenu | Version |
|---|---|---|
| `R_E1.md` | matières et cristaux des activités (`core/activity_loot.gd`, `Forge.GOLD_PER_CRYSTAL` 125, coffre de trophées retiré) | 0.1.165 |
| `R_E2.md` | maîtrise du JcJ, insignes JcJ plafonnés au jour, plans sûrs, fabrication 9 emplacements, panoplie des Esprits | 0.1.171 |
| `R_E3.md` | 7 profils de stats des 60 classes, « Équiper le meilleur », « Appliquer à la famille », Registre | 0.1.178 |
| `R_E4.md` | coffre de cape, 17 types d'arme découverts, fournitures de la Survie au niveau de la carte | 0.1.179 |
| `R_E5.md` | barème des insignes par heure (`core/economy.gd`), Armurerie à paliers, puits, maîtrise des 60 classes | 0.1.177 |
| `R_E6.md` | équilibrage global par mesure (`progression_sim`, écart d'époque ×1 / 1,7 / 3,4 / 7, gemmes en Survie, plafonds de farm) | 0.1.182 |

## Chaîne U — interface
| Rapport | Contenu | Version |
|---|---|---|
| `R_U1.md` | socle des menus du lobby (pages qui défilent, bouton épinglé, lignes à hauteur auto, pied de page) | 0.1.169 |
| `R_U2.md` | entrée du jeu : écran titre, accueil `welcome.gd`, Guide F1, tutoriel | 0.1.173 |
| `R_U3.md` | choix de carte en un geste, coffres par genre, roulette à cases promises | 0.1.174 |
| `R_U4.md` | écran Héros (préréglages, sous-onglets de classe, apparence) | 0.1.175 |
| `R_U5.md` | Atelier (bourse, Armurerie filtrable, Fabrication, Forge avant → après) et marchand | 0.1.176 |
| `R_U6.md` | infobulles d'objets (`Items.describe`, `ItemWidgets.item_card`) | 0.1.172 |
| `R_U7.md` | Carnet (`CarnetPages.tabs()`, sous-titres, vue d'ensemble) | 0.1.166 |
| `R_U8.md` | Paramètres plein écran, barre d'aide manette | 0.1.167 |
| `R_U9.md` | HUD, pause, bilans (`ResultsPanel`) | 0.1.180 |
| `R_U10.md` | noms français (`data/names_fr.json`, `NamesFr.apply`) | 0.1.168 |

## Passes P — peaufinage
| Rapport | Contenu | Version |
|---|---|---|
| `R_P1.md` | « raccords » : tous les écrans dans 1280×720 (`shot_p1`, lignes `[débord]`) | 0.1.183 |
| `R_P2.md` | performances (`tools/perf_ui`) et sauvegardes sûres (`SafeFile`) | 0.1.186 |
| `R_P3.md` | HUD en jeu : « ? Aide », bilan animé, chiffres de dégâts, cadre de boss | 0.1.181 |
| `R_P4.md` | QA d'intégration : `test_p4_flow`, `test_p4_activities`, `test_p4_migration` | 0.1.185 |
| `R_P5.md` | bilan des insignes, verrous de PE (`DIFF_RATIO`, `POWER_RATIO`, `LEGEND_RATIO`), époque I adoucie | 0.1.184 |
| `R_P6.md` | la quête commune se voit : boussole, pastilles de gains, « où l'obtenir » | 0.1.188 |
| `R_P8.md` | petites cartes d'information (`ui/info_card.gd`) | 0.1.187 |
| `R_P9.md` | notes du joueur : rage par paliers, horde qui suit son chemin, pièce portée jamais reproposée | 0.1.189 |
| `R_P10.md` | santé des tests, tout le jeu en français (`test_texts_fr`), option boussole | 0.1.190 |
| `R_P11.md` | boss à PV fixes, rage du boss, `tools/boss_ttk.py` | 0.1.192 |
| `R_P12.md` | pacte, géants et Menace | 0.1.191 |
| `R_P13.md` | trois notes du joueur : choix de carte et pause, aide « Bot », teinture | 0.1.193 |
| `R_P14.md` | suite de tests verte, `tools/run_tests.py` | 0.1.199 |
| `R_P15.md` | spawn varié (rôles, escouades, événements), niveau et puissance des monstres | 0.1.206 |
| `R_P16.md` | notes du joueur : auras d'Eden (`tools/fx_aura_fix.py`), apparence d'arme | 0.1.200 |
| `R_P17.md` | documentation : CLAUDE.md réécrit, DESIGN.md réorganisé et corrigé, CHANGELOG vérifié, cet index | 0.1.212 |
| `R_P18.md` | régression complète sur HEAD : suite verte, parcours de tous les modes (`test_p18_modes`), migrations, équilibrage, perfs | 0.1.213 |

## Passes M — modes
| Rapport | Contenu | Version |
|---|---|---|
| `R_M1.md` | Battle royale : héros scriptés (`RoyaleDirector.BRAIN`), anneau de 9 min 50, largages, mis à prix | 0.1.201 |
| `R_M2.md` | bibliothèque de boss (48 boss, 29 briques) et donjons à la carte ; API `BossLibrary.spawn` | 0.1.202 |
| `R_M3.md` | la Tour : types d'étage par bloc de 10, élites à mécanique, ombres, boss de la bibliothèque | 0.1.207 |
| `R_M5.md` | quêtes : le Défi de maîtrise devient « Défi du jour » (`core/quests.gd`) | 0.1.196 |
| `R_M6.md` | Ruée (8 boss tirés, modificateurs) et Siège sur la bibliothèque, lisibilité de la difficulté | 0.1.208 |
| `R_M7.md` | Arènes, Duel, Gantelet : alliés à la fiche d'un héros, arène piégée, mort subite | 0.1.205 |
| `R_M8.md` | la Tour : équilibre entre classes (`TowerBalance`), coups de boss plafonnés à 25 %, pilote qui esquive | 0.1.211 |

## Survivant (`conception/survivor/`)
| Document | Contenu | Version |
|---|---|---|
| `SPEC.md` | spécification du mode ; sa tête « Décisions finales » (S8) prime sur le reste | — |
| `DECISIONS_JOUEUR.md` | décisions du joueur du 15/10 (remplacées là où `SPEC.md` « Décisions finales » les contredit) | — |
| `R_S1.md` | socle et crochets (`core/survivor.gd`, `HUB_KEYS`) | 0.1.194 |
| `R_S2.md` | pièces et arme (13 sets de niveau 90, passifs fixes, verrou à vie) | 0.1.195 |
| `R_S3.md` | cartes (`SurvivorCards`, bannir / garder / Passer, pitié) | 0.1.198 |
| `R_S4.md` | déroulé de la run (gardiens 5 / 10 / 15 min, boss à 20:00, `spawn_plan`) | 0.1.197 |
| `R_S5.md` | interface en run (cartes par famille, page Build, frise du HUD) | 0.1.203 |
| `R_S6.md` | fin de run : coffres d'apparence seulement, bilan « Ton build » | 0.1.204 |
| `R_S7.md` | équilibrage par mesures (`tools/sim_survivor.py`, `tests/sv7_mesures.json`) | 0.1.209 |
| `R_S8.md` | paliers I à V, mode ouvert à tous | 0.1.210 |

Pas de rapport : P7, M4 (numéros non attribués cette nuit). Captures d'écran des passes : `captures/` (hors git).
