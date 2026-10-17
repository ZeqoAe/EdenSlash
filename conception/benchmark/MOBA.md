# Les Deux Voies (MOBA 4 contre 4) : étude comparative et spécification v2 (BM-MOBA, 17/10/2026)

Mandat du joueur : un MOBA 4 contre 4 adapté à Eden Slash : les 60 classes jouables, 4 sorts par héros, le combat d'action en temps
réel du Duel, une carte à voies avec tours, sbires, jungle et objectifs, une boutique en partie, des équipes d'IA scriptées qui jouent
très bien (aucun cerveau neuronal), mode scellé, DA « autocollant manga », caméra et contrôles du jeu actuel. Méthode : `METHODE.md`.
DA : `art/BIBLE.md` v2. Idée d'origine : `IDEES_EN_VRAC.md` § 10. Croquis maison : `moba_maquettes/` (5 SVG, 1600 × 900 ou 1600 × 1000).
Hors dépôt : `C:\AI\benchmark_refs\moba\` (`SOURCES.txt`, nos captures `eden_slash_nous\`, rendus des croquis `_rendu_maquettes\`).
**Aucune image tierce n'a été téléchargée** (le téléchargement de fichiers attend l'accord explicite du joueur) : les références ont été
étudiées par leurs pages écrites (wikis officiels, annonces des studios, critiques) ; les pages à capturer plus tard sont listées dans
`SOURCES.txt`. Côté joueur, le mot « MOBA » est interdit (BIBLE § 12) : le mode s'appelle **Les Deux Voies** (Q11) ; « moba » reste le
nom interne des fichiers.

**Verdict en une phrase** : le jeu a déjà les deux briques les plus chères d'un MOBA (un combat de héros à 60 kits avec esquive,
enchaînements, plafonds JcJ mesurés, et une IA de héros scriptée à 4 difficultés qui lit les zones, se replie et soutient son camp) ;
il manque **tout ce qui fait la partie** : la carte à voies, les structures, les sbires, la jungle neutre, l'économie en temps réel, la
boutique, la progression 1-12 dans la partie, la **macro de l'IA** (voie, jungle, objectifs, rappel, achats) et un HUD d'équipe. C'est
un mode à part entière : **12 lots, ≈ 43 jours d'agent (55 avec la marge de risque)**, à commencer par un essai technique de 2 jours
(8 héros + 48 sbires + 10 tours à 60 images par seconde) qui décide de la suite.

---

## 1. Sources et ce qui a été vérifié

| Référence | Ce qu'on a lu (détail et liens : `SOURCES.txt`) | Statut |
|---|---|---|
| League of Legends (Riot, PC) | wiki officiel : sbires, tours, mort, repères ; annonce des nouveaux bots (14.6) | vérifié (pages consultées le 17/10/2026, chiffres du patch 26.x) |
| Wild Rift (Riot, mobile / console) | page d'aide « carte et modes » ; billet des développeurs (10/2020) | vérifié ; boutique rapide = article de 2020, **non vérifié aujourd'hui** |
| Dota 2, mode Turbo (Valve) | Sportskeeda, wiki Fandom (réapparition), Kotaku | vérifié par recoupement ; chiffres du patch actuel non vérifiés |
| Heroes of the Storm (Blizzard) | Blizzard (concepts : XP d'équipe, pas d'objets), Giant Bomb (paliers de talents), Nexus Compendium, Liquipedia | vérifié |
| Pokémon UNITE (TiMi / The Pokémon Company) | Bulbapedia (règles d'une partie), Smogon (Rayquaza), unite-db / Serebii (objets) | vérifié ; carte actuelle **non vérifiée** |
| Smite / Smite 2 (Hi-Rez) | critiques PCGamesN, PC Gamer ; guide EarlyGuides (Smite 2) | vérifié pour la caméra et la visée ; buffs de Smite 2 d'une seule source |
| Honor of Kings (TiMi) | annonce du lancement mondial (Level Infinite), guide ItemLevel | durée 15-20 min et achat partout vérifiés ; achat conseillé **non vérifié** |
| Mobile Legends (Moonton) | carte mlbbhub (Tortue 2:00, Seigneur 8:00), guides | durée **non vérifiée** (guides : 10 à 20 min) |
| Supervive (Theorycraft) | aperçu PC Gamer, PCGamesN, critique Game8 | vérifié (vue de dessus, action, esquive) |
| Vainglory (SEMC), Brawl Stars « Braquage » | Red Bull, iMore, Pocket Gamer | vérifié (1 voie + jungle à 3 contre 3 ; Braquage 2 min 30) |
| **Eden Slash** 0.1.284 (copie propre de HEAD) | 8 captures `tests/shot_m7.tscn` (Arène 3 contre 3, Gantelet) en 1600 × 900 ; code des Arènes, du Siège, du Battle royale, de l'Échiquier | constaté |

Limites : aucune partie jouée des références (ni client ni compte) ; aucune capture tierce regardée dans cette étude. Tout ce qui est
« de mémoire » est marqué **non vérifié** ; la spécification ne repose sur aucun point non vérifié.

---

## 2. Ce qui fait la qualité de chaque référence

### League of Legends : la règle de base du genre (vérifié, wiki officiel)
- **Rythme des vagues** : première vague à 0:30, puis toutes les 30 s ; toutes les 25 s dès 14:00, 20 s dès 30:00. Une vague = 3 mêlées
  + 3 lanceurs ; un sbire de siège à 1:30 puis une vague sur trois (une sur deux dès 14:00, toutes dès 25:00). Super-sbires une fois
  l'inhibiteur détruit. L'or d'une vague va de ≈ 119 (0:30) à 148 (25:00).
- **Les sbires défendent leurs héros** (« appel à l'aide ») : un héros qui frappe un héros ennemi devient leur cible prioritaire dans un
  rayon donné. Les **tours** visent dans l'ordre sbires puis héros, **sauf** le héros qui frappe un héros allié près d'elles ; chaque tir
  consécutif sur un héros fait +50 % (jusqu'à +150 %), remis à zéro après 5 s. **Protection anti-percée** : −80 % de dégâts subis par la
  tour quand aucun sbire ennemi n'est proche. 11 tours par camp (3 voies × 3 + 2 de Nexus).
- **Réapparition** : 10 s au niveau 1 à 52,5 s au niveau 18, allongée après 15:00 (plafond 78,75 s).
- **Repères** : une roue à 8 repères (Repli, Pousser, J'y vais, Tout donner, Aide, Vision, Ennemi disparu, Vision ennemie), repères
  contextuels (sur un ennemi = « vise-le », sur une structure alliée = « défends »), repères sur le HUD (recharges, objets), indicateurs
  au bord de l'écran pour les repères hors champ, limites de fréquence. Le joueur communique sans écrire une ligne.
- **Bots** : refaits en 14.6 (jungle, rotations, objectifs) pour que « Coop contre IA » ressemble à une vraie partie ; Riot reconnaît
  qu'ils restent pensés pour les nouveaux joueurs. **Le genre n'a pas de partie solo exigeante contre l'IA** : c'est notre place.

### Wild Rift : le MOBA ramené à 16-18 minutes (vérifié)
- Cible annoncée par les développeurs : **16-18 minutes** de partie, et toute la session (choix, chargement, bilan) en moins de 30 min.
- Carte plus petite, plus de buissons, **pas d'inhibiteurs** (la tour de base détruite donne des super-sbires), **le Nexus tire** sur
  les intrus (plus de tours de Nexus). Mêmes objectifs que LoL (dragons, Héraut, Baron). Mode Coop contre IA et entraînement.
- **Non vérifié** : achat rapide en fontaine seulement (article de 2020).

### Dota 2, Turbo : la preuve qu'on raccourcit sans tout refaire (vérifié par recoupement)
- XP et or doublés, réapparition −25 %, tours plus faibles, coursier rapide, aucun or perdu à la mort ; parties de **20 à 25 min**
  contre 40 et plus en classé. Leçon : la durée se règle par l'économie et la solidité des structures, pas par la taille de la carte.

### Heroes of the Storm : l'équipe avant l'individu (vérifié)
- **XP partagée par l'équipe** (un seul niveau pour les 5), **aucun objet** : à la place, des **talents** à choisir aux niveaux 1, 4, 7,
  10, 13, 16 et 20 (3 à 5 choix exclusifs), le sort héroïque au niveau 10.
- **Objectifs de carte qui forcent le combat** (tributs de la Malemort : 3 tributs = les forts ennemis ne tirent plus et leurs sbires
  tombent à 1 PV ; balises de Braxis), **camps de mercenaires** qui poussent une voie. Une carte à une voie (Grotte perdue) en mode Bagarre.

### Pokémon UNITE : 10 minutes, lisible par un enfant (vérifié)
- Partie de **10 min**, le score décide ; les **2 dernières minutes comptent double** (« Dernière ligne droite ») et un objectif final
  (Rayquaza sur la carte de Theia) donne un bouclier de but et des marques plus rapides : la fin est toujours un moment.
- Objets **tenus, choisis avant la partie** (3 au plus), objets de combat rechargeables : pas de boutique en partie.
- **Non vérifié** dans cette étude : choix d'amélioration de sort aux niveaux (connu du genre), visée automatique.

### Smite : le MOBA vu de près, tout se vise (vérifié)
- Caméra derrière le héros, déplacement au clavier, **tous les sorts visés** (réticule, rien de ciblé) : tout peut rater. Les critiques
  notent que cette vue **réduit la conscience de la carte** et rend les embuscades plus dangereuses. C'est notre situation (caméra proche).

### Honor of Kings, Mobile Legends : le standard mobile (partiellement vérifié)
- Parties de **15 à 20 min** (vérifié pour HoK) ; **achat partout sur la carte** sans revenir à la base (HoK, vérifié) ; objectifs de
  rivière à horaires fixes (MLBB : Tortue 2:00, Seigneur 8:00 qui pousse une voie avec l'équipe).

### Supervive : l'action vue de dessus avec esquive (vérifié)
- Combat de dessus façon jeu d'action, planeur, terrain qui change ; les critiques saluent le mélange et notent une **courbe
  d'apprentissage raide** et une caméra centrée qui gêne ceux qui jouent de loin. C'est le plus proche de notre ressenti de combat.

### Vainglory (1 voie + jungle à 3 contre 3) et Brawl Stars « Braquage » (2 min 30) (vérifié)
- Halcyon Fold : **une voie** et une jungle, mine d'or au milieu à 4:00 : pas de poussée séparée possible, donc **des combats
  fréquents**. Braquage : un coffre à défendre, 2 min 30, le plus de dégâts au coffre gagne. Leçon : moins de voies = plus de combats.

---

## 3. Les grands choix, référence par référence

| Question | LoL / Wild Rift | Dota Turbo | HotS | UNITE | Choix pour nous (§ 7) |
|---|---|---|---|---|---|
| Voies pour l'équipe | 3 voies, 5 héros | 3 voies, 5 | 2 à 3 selon la carte (**non vérifié**) | 2 voies + jungle centrale, 5 (**non vérifié**) | **2 voies + jungle**, 4 héros (duo, solo, jungle) |
| Durée | 30-45 min / 16-18 min | 20-25 min | ≈ 20 min (**non vérifié**) | 10 min | **médiane 17 min**, fin forcée à 25 min |
| Niveaux | par héros (18) | par héros | **partagés** | par héros (**non vérifié**) | **par héros, 1 à 12**, rattrapage |
| Dernier coup | oui | oui (+ refus) | non | non (énergie) | **non** : or partagé de proximité (bonus au dernier coup) |
| Objets | boutique, base | boutique, coursier | aucun (talents) | avant la partie | **boutique à la base** (et mort), 40 objets, 6 places, achat conseillé en un appui |
| Objectifs neutres | dragons, Héraut, Baron | Roshan | objectif de carte | Rayquaza | **Gardien** (3:00) et **Colosse** (9:00) = boss de la bibliothèque avec leurs mécaniques |
| Fin de partie | Nexus | Ancient | Nexus | score à 10 min | **Cœur** ; « Marée finale » à 18:00 ; décision aux points à 25:00 |
| Brouillard | complet + balises | complet | complet | complet | **mini-carte seulement + buissons** (la caméra proche fait le reste) |
| Communication | roue de 8 repères | roue | roue | rapide | **roue de 4 repères + contextuel ; les alliés IA obéissent** |

---

## 4. Nos modules face au genre

| Module (code) | Ce qu'il apporte aux Deux Voies | Ce qui manque ou gêne |
|---|---|---|
| **Combat des héros** (`player/player.gd`, enchaînements `kit_chain`, esquive, `combat/pvp_caps.gd`, profils `core/mode_rules.gd`) | 60 classes, 4 cases × (sort + 2 enchaînements), esquive à invulnérabilité, plafonds par coup et en rafale mesurés (arène 3 contre 3 : échelle 0,024) | aucune notion de niveau en partie qui débloque des enchaînements ; une seule stat de défense (pas de résistance magique) : la boutique s'y plie |
| **IA de héros** `ai/class_rival.gd` (4 difficultés `DIFF`, lecture des zones, esquives, `pick_target` du plus faible, repli sous 30 %, soutien de camp) | la « micro » d'un bon joueur, déjà mesurée en Arènes, Siège, Donjons, Battle royale ; 0,10 ms par unité scriptée (`R_AC2.md`, sans rendu) | pas de macro (voie, tour, rappel, achats, objectifs) ; `ClassRival` hérite de `Monster` : pas de `Procs` (les effets d'objets passent par `Player`), il lit surtout les coups du joueur |
| **Arènes / Gantelet** `core/duel_director.gd`, `Duel.make_ally`, `Duel.team_classes`, `ui/team_bars.gd` | équipes mixtes à la fiche d'un vrai héros, familles différentes, tableau de manche (dégâts, K.O.) | arène de 15 m ; aucune structure ; HUD de manche, pas de partie longue |
| **Siège / Tour / Donjons** `core/siege_director.gd`, `core/tower_director.gd`, `core/boss_library.gd` (48 boss, 29 briques) | vagues, alliés qui lisent les zones du boss, **boss à mécaniques réutilisables** (`BossLibrary.spawn(id, palier, ctx)`) : nos objectifs neutres seront plus riches qu'un dragon | les monstres visent les héros (`Monster._hostile_pool`) : un **camp neutre** (jungle) n'existe pas |
| **Battle royale** `core/royale_director.gd` (`BRAIN`, ordres toutes les 0,4 s, intentions, `Royale.power_ratio`), `Royale.sheet` / `refresh_ai`, `ui/royale_ping.gd`, `ui/minimap.gd` | 8 héros sur une grande carte, **macro d'IA par ordres** (pillage, chasse, fuite), équipement appliqué aux IA par leur fiche, repère personnel, mini-carte à marques | chacun pour soi ; repère sans effet sur l'IA |
| **L'Échiquier** `core/autochess_effects.gd`, `tools/autochess_ai_bench.tscn`, `tools/autochess_games.tscn` + `autochess_report.py` | méthode de mesure (parties IA contre IA, une ligne JSON par partie, rapport), couche d'effets pure | effets pensés pour des unités, pas pour `Player` |
| **Potions** `core/potions.gd`, **Procs** `combat/procs.gd`, **Boons** | 4 potions (touches C / V), déclencheurs d'objets (`hit`, `skill_hit`, `crit`, `kill`, `hurt`, `low_hp`…) | textes « monstre » (« en tuant un monstre ») à reformuler ; `Procs.fire` ne prend qu'un `Player` |
| **Interface** `ResultsPanel`, `InfoCard`, `UiNav`, HUD v2 (`ui/boss_bar.gd`, `ui/hud_alert.gd` à 3 niveaux, `ui/boss_timeline.gd`) | bilans communs, annonces à niveaux, frise d'objectifs, manette partout | `CardPicker` met le monde en pause : inutilisable en 4 contre 4 (le choix de niveau doit être non bloquant) |
| **Caméra** `core/camera_rig.gd` (15 m, 52°, champ 45°, zoom 7 à 28 m) ; contrôles `core/settings.gd` (4 sorts 1-4 / A E R T, RB RT LB LT, `move_order` « clic droit stratégie », `ping` molette / L3) | tout est déjà là, y compris le déplacement au clic droit façon MOBA | à 15 m on voit ≈ 24 × 13 m (mesuré sur la capture du décompte : 4 m ≈ 270 px) : moins que la portée d'une tour ; il faut 22 m par défaut |

**Ce que nos captures montrent** (0.1.284, `eden_slash_nous\m7_*.png`) :
1. **Aucun HUD en Arène 3 contre 3 ni au Gantelet** : ni barres d'équipe, ni cases, ni décompte visible (captures 20, 21, 30) ; seule
   l'étiquette « F1 : aide ». **À vérifier** : régression du HUD en Duel ou effet de l'outil de capture (qui ne masque rien dans son code).
2. **Mêlée illisible à 6 héros** : noms empilés et coupés (« Barrière · Cil… »), télégraphes en ligne qui traversent tout l'écran,
   effets de sorts superposés (capture 21). À 8 héros + sbires + tours, ce sera pire : la lisibilité est un risque de premier rang (§ 8).
3. Pause des Arènes avec le vocabulaire de la Survie (« Compétences de la partie (4 / 12) », « Arme secondaire : aucune ») et des
   pourcentages en texte permanent (« 4 % coup porté ») ; bilan « VICTOIRE ! » propre (papier v2, Gagné / Gardé, primaire soleil),
   mais tuiles en pourcentage. L'outil `shot_m7` ne referme plus la pause (captures 22 à 24 identiques) : à mettre à jour.

---

## 5. Écarts écran par écran (le genre contre ce qu'on a de plus proche)

| Écran | Le genre (vérifié sauf mention) | Nous aujourd'hui (le plus proche) | Écart |
|---|---|---|---|
| Choix des héros | poste puis champion, équipe adverse dévoilée, kit visible | file du Duel (`ui/duel_queue.gd` : recherche, match, choix de 60 s, récapitulatif) | à adapter : postes, 4 alliés IA complémentaires, sans minuteur par défaut |
| HUD de combat | score et temps en haut, mini-carte, cadres des alliés, sorts + objets + or en bas, minuteurs d'objectifs | HUD de Survie / Battle royale ; barres d'équipe des Arènes (absentes sur nos captures) | **tout le HUD d'équipe est à faire** (croquis `v2_hud.svg`) |
| Mini-carte | brouillard, alliés, sbires, tours, repères, clic pour regarder | mini-carte ronde du Battle royale, repère personnel | brouillard « vu par un allié », structures, regarder sans bouger |
| Communication | roue de repères, repères contextuels, indicateurs hors champ | repère personnel sans effet de jeu | **roue + ordres aux alliés IA** (P0) |
| Boutique | parcours conseillé, recettes, achat rapide | aucune boutique en temps réel ; choix de coffres du Battle royale (pause) | boutique entière à faire (croquis `v2_boutique.svg`) |
| Montée de niveau | point de sort / talent sans pause | `CardPicker` (pause) | choix non bloquant (Ctrl + 1/2/3, croix de la manette) |
| Mort | récapitulatif, minuteur, caméra libre, achats | Battle royale : retour en 4 s, spectateur (lot BR-I2) | récapitulatif + minuteur + boutique + regarder la carte |
| Objectifs | minuteurs, annonces, bannière d'équipe | barre de boss v2, frise « À venir », annonces à 3 niveaux (lot DNG-2) | **réutilisable presque tel quel** (point fort) |
| Bilan | tableau des 10, MVP, courbe d'or | `ResultsPanel` + tableau de manche des Arènes | tableau des 8, courbe d'écart d'or, moments (croquis `v2_bilan.svg`) |
| Tutoriel | parcours guidé, Coop contre IA | fiches `Tutorial.CARDS`, Guide F1 | partie guidée de 5 étapes (P1) |

**Ce qu'on fera mieux que le genre** : combat d'action lisible (esquive, enchaînements, télégraphes v2) au lieu du clic-cible ; des
objectifs neutres qui sont de **vrais boss à mécaniques** ; une IA solo **exigeante à 4 difficultés** qui obéit aux repères ;
manette complète ; parties de 17 min sans file d'attente ; aucune puissance achetée (mode scellé).

---

## 6. Backlog priorisé

Taille : **S** ≤ 1 jour d'agent, **M** 2-3, **L** 4-5. Fichiers sous `game/scripts/` sauf mention. Lots détaillés au § 9.

### P0 : sans ça, le mode n'existe pas ou fait « prototype »
| # | Élément | Taille | Fichiers (nouveaux en gras) | Lot |
|---|---|---|---|---|
| 1 | **Essai technique** go / no-go : 8 héros, 48 sbires, 10 tours à 60 i/s en 1600 × 900 | M | **`tools/moba_probe.tscn`** | MB-0 |
| 2 | Données et règles en un fichier (réglages en tête), profil `moba` de `ModeRules`, kits des 60 classes générés | M | **`core/moba_data.gd`**, **`tools/moba_kits.py`** → **`data/moba_kits.json`**, `core/mode_rules.gd`, `core/modes.gd` | MB-A |
| 3 | Carte à 2 voies + jungle (croquis `v2_carte.svg`), maillage de navigation précuit, voies en courbes | L | **`scenes/moba_map.tscn`** ou `world/proc_map.gd` (`generate_moba`) | MB-B |
| 4 | Tours, Cœur, sbires, vagues, protections, victoire | L | **`world/moba_tower.gd`**, **`world/moba_core.gd`**, **`ai/moba_minion.gd`**, **`core/moba.gd`**, **`core/moba_director.gd`** | MB-C |
| 5 | Héros en partie : niveaux 1-12, enchaînements et ultime débloqués, or, XP, primes, mort, réapparition, rappel, fontaine | L | `player/player.gd` (accès aux cases), **`core/moba_hero.gd`** | MB-D |
| 6 | Boutique : 40 objets, recettes, 6 places, achat / annuler / vendre, objets appliqués au joueur **et** aux IA | M | **`core/moba_items.gd`**, `core/royale.gd` (`sheet` comme modèle) | MB-D |
| 7 | IA de héros par poste (voie, jungle, soutien), respect des tours et des sbires, rappel, achats | L | **`ai/moba_hero_ai.gd`** (sur `ClassRival`) | MB-E |
| 8 | Jungle neutre (laisse, remise à zéro), Gardien, Colosse, Marée finale, fin au temps | M | **`ai/moba_camp.gd`**, `core/boss_library.gd` (contexte « moba »), `core/moba_director.gd` | MB-F |
| 9 | IA d'équipe : vue honnête, carte d'influence, plans, minuteurs ; **repères → ordres** | L | **`core/moba_coach.gd`**, `ui/royale_ping.gd` (généralisé) | MB-G |
| 10 | HUD d'équipe : tableau du haut, mini-carte, cadres des alliés, cases à plots d'enchaînements, or + objet conseillé, annonces, fil | L | **`ui/moba_hud.gd`**, `ui/minimap.gd`, `ui/hud_alert.gd`, `ui/boss_timeline.gd` | MB-H |
| 11 | Entrée et fin : activité, page, choix des postes et des héros, bilan, récompenses scellées, quêtes | M | `ui/activities.gd`, `ui/lobby.gd`, **`ui/moba_pick.gd`**, **`ui/moba_results.gd`**, `core/quests.gd`, `core/quest_pool.gd`, `core/resource_help.gd` | MB-I |
| 12 | Mesure : banc IA contre IA, durée, équilibre des postes et familles, difficulté, image | M | **`tools/moba_games.tscn`**, **`tools/moba_report.py`**, **`tests/mb_mesures.json`** | MB-J |

### P1 : ce qui fait la qualité
| # | Élément | Taille | Fichiers |
|---|---|---|---|
| 13 | Buissons et brouillard de la mini-carte (vue des alliés, 25 m), respectés par l'IA | M | `core/moba_coach.gd`, `ui/minimap.gd`, `world/moba_bush.gd` |
| 14 | Mort : récapitulatif (qui, sort, PV qui lui restaient), minuteur, boutique, regarder la carte | M | `ui/moba_hud.gd` |
| 15 | Tableau des scores (Tab / croix ←) : K / M / A, niveau, objets, réapparitions | S | `ui/moba_hud.gd` |
| 16 | « Mon kit » (préréglage de Duel de la classe) au lieu du kit généré | S | `core/moba_hero.gd`, `core/spell_presets.gd` |
| 17 | Achat automatique et choix de niveau automatique (réglages ; actifs à la 1re partie) | S | `core/settings.gd`, `core/moba_items.gd` |
| 18 | Moments manga et sons : « Premier sang ! », « Tour ! », « Colosse ! », série, Cœur qui explose | M | `ui/moba_hud.gd`, `combat/sfx.gd`, `core/ui_feel.gd` |
| 19 | Partie guidée (5 étapes) + 5 fiches `Tutorial.CARDS` + chapitre du Guide | M | `core/tutorial.gd`, `ui/guide.gd` |
| 20 | Lisibilité à 8 héros : télégraphes des alliés en contour seul, plaques courtes sans nom (nom au survol), chiffres des sbires regroupés | M | `combat/telegraph.gd`, `ai/class_rival.gd`, `combat/damage_number.gd` |
| 21 | « Alliés plus forts » (difficulté par camp) ; série de victoires qui ouvre les récompenses rares | S | `core/moba.gd`, `ui/lobby.gd` |
| 22 | Bilan riche : courbe d'écart d'or, moments, conseil (« mort 2 fois sous leur T2 ») | M | `ui/moba_results.gd`, `core/moba.gd` (journal) |

### P2 : finitions et confort
| # | Élément | Taille |
|---|---|---|
| 23 | « Escarmouche » : une voie, 10 min, petite carte (comme la Grotte perdue de HotS) | M |
| 24 | Défis du mode dans les quêtes (gagner sans mourir, voler le Colosse…) et statistiques au Carnet | S |
| 25 | Ligue des voies (points, rangs de `League`), apparence de saison | M |
| 26 | Apparences de sbires et de tours (récompenses du mode), émotes de victoire | M |
| 27 | Regarder une partie IA contre IA (spectateur, ×2) ; revoir la dernière minute | M |
| 28 | Option d'accessibilité « Voir les sons » (combats hors champ, tour qui tire) | M |

---

## 7. Spécification « version 2 »

### 7.1 Identité
- **Nom** : *Les Deux Voies*. Rangée **Affrontements** du menu Jouer. **Rôle unique** (`gives`) : apparences, titres et maîtrise de la
  classe jouée (comme le Battle royale) ; insignes plafonnés au jour comme le JcJ. **Ouverture** : dès le départ (mode scellé, comme le
  Survivant et l'Échiquier) ; la première partie propose la partie guidée.
- **Mode scellé** (`Modes.sealed()` étendu à « moba ») : aucun talent, certificat, plateau, archive, aura, pièce ni bonus du compte ;
  chaque héros part de la **fiche d'un héros de sa classe** au niveau de partie (comme `Duel.rival_sheet`), passifs de classe gardés.
  **Les 60 classes sont jouables**, même non débloquées au compte (Q6).
- **Solo contre l'IA uniquement** : aucun code réseau ; rien n'empêche plus tard un second joueur, mais aucun travail n'y est prévu.
  Pause permise (menu pause fige la partie, comme partout).

### 7.2 Déroulé d'une partie (médiane visée 17 min)
| Temps | Événement |
|---|---|
| avant | Choix du poste puis de la classe (`v2_choix_heros.svg`), difficulté, chargement (préchargement des 8 kits et des modèles, comme la file du Duel) |
| 0:00 | Les 8 héros à leur fontaine, 500 or ; boutique ouverte ; bandeau « Défendez votre Cœur ! » |
| 0:40 | Premières vagues (puis toutes les 30 s) ; or passif (2 par seconde) |
| 1:30 | Camps de la jungle (Source, Braise, petits camps) |
| 3:00 | **Gardien** dans la rivière (annonce à 3:00 − 45 s) ; revient 3 min après sa mort |
| 4:00 | Fin de la protection des T1 (dégâts subis ×0,5 avant) |
| 9:00 | **Colosse** (annonce 60 s avant) ; revient 4 min après |
| 15:00 | Réapparition +25 % |
| 18:00 | **Marée finale** : un géant de plus par vague, les Cœurs sont vulnérables même si des T2 tiennent, réapparition +50 % |
| 25:00 | **Fin au temps** : l'équipe qui a détruit le plus de structures gagne, puis le Cœur le moins entamé, puis l'or total |
| fin | Le Cœur explose (ralenti 1 s), bandeau « Victoire ! » / « Défaite », bilan (`v2_bilan.svg`) |

### 7.3 Règles chiffrées de départ (toutes dans `MobaData`, à mesurer par MB-J)
| Règle | Valeur de départ | Pourquoi |
|---|---|---|
| Héros | 4 par camp : Voie du Soleil (duo : tir + soutien), Voie des Brumes (solo : Rempart), jungle (Ombre) | 5 familles = 5 rôles ; Traque et Arcane partagent le poste de tir |
| Niveau de partie | 1 à 12 ; fiche d'un héros de la classe au niveau 30 + 5 × (niveau − 1) (30 à 85), sans pièce | un saut de puissance visible à chaque niveau |
| XP pour le niveau suivant | 120, 160, 200 … 520 (+40 par niveau ; 3 520 au total pour 12) | niveau 12 vers 15-17 min pour un solo |
| XP gagnée | sbire mêlée 30, tireur 20, bélier 60 (partagée entre les héros alliés à 15 m) ; héros 100 + 25 × son niveau ; petit camp 60, buff 100 ; Gardien 150 et Colosse 250 à chacun ; 1 par seconde pour tous | — |
| Rattrapage | +30 % d'XP et d'or des sbires sous la moyenne adverse de 2 niveaux | pas de partie perdue à 6 min |
| Or | départ 500 ; passif 2 / s dès 0:40 ; sbire mêlée 20, tireur 15, bélier 45 : **100 % au dernier coup, 60 % à chaque autre allié à 15 m, 50 % aux héros à 15 m si un sbire ou une tour l'achève** | l'action ne doit pas punir le « dernier coup » raté |
| Primes | élimination 300 (premier sang +100), aide 150 partagée ; série : +100 par élimination au-delà de 2 (prime de 700 au plus) ; tour T1 250, T2 300 à chacun | — |
| Or estimé à 17 min | ≈ 7 000 par héros (passif 2 000, sbires 2 500, combats 1 500, structures et objectifs 1 000) : 2 objets finis + bottes + composants | même rapport que LoL à 30 min |
| Réapparition | 5 + 2 × niveau s (7 à 29 s) ; +25 % dès 15:00, +50 % dès 18:00 | LoL 10-52 s, Turbo −25 % |
| Rappel | touche « S'extraire » (X / action `extract`) : 6 s de canalisation, coupée par un coup ; fontaine : 12 % des PV par seconde | — |
| Règles de dégâts entre héros | profil `moba` : échelle 0,09 (à mesurer : 1 contre 1 égal en 10-16 s), soins ×0,6, un coup ≤ 22 % des PV max, rafale ≤ 50 % sur 2 s, pas d'acharnement (les objectifs font pression) | les Arènes (0,024) visent des manches de 30 à 90 s (passe M7) : trop long pour un échange en voie ; le Battle royale (0,055) donne 17-31 s |
| Potions | les 4 de `core/potions.gd` ; 2 de soin au départ ; achat à la boutique ; 20 s de recharge par touche (C soin, V effet) | réutilisation telle quelle |

### 7.4 La carte (`moba_maquettes/v2_carte.svg`)
- **200 × 120 m**, deux bases aux extrémités (Cœur bleu à x = −88 m, rouge à +88 m), symétrie par rotation (comme Wild Rift).
- **Voie du Soleil** (haut) et **Voie des Brumes** (bas) : ≈ 200 m de Cœur à Cœur, 11 m de large, ≈ 30 s de course à 6,5 m/s.
- **Jungle** entre les voies, coupée par une **rivière** au milieu ; rochers gris = couvert non cassable qui bloque les tirs (BR1 : les
  classes à distance gagnaient presque tout en terrain nu) ; **buissons** aux entrées de jungle et près de la rivière.
- Par camp : 2 tours par voie (T1 au tiers de la voie, T2 à l'angle de la base) + le Cœur qui tire ; fontaine derrière.
- Camps : par moitié, **Source** (lagon : recharges plus rapides 90 s), **Braise** (fraise : auto-attaques qui brûlent et ralentissent
  90 s), 2 petits camps. Rivière : **Colosse** (côté Soleil) et **Gardien** (côté Brumes).
- Lumière et décor d'une zone du jeu (clair, BIBLE § 1) ; une teinte d'équipe sur le sol des bases ; aucune bordure noire.

### 7.5 Unités non-joueurs
| Unité | Comportement | Chiffres de départ |
|---|---|---|
| **Sbire mêlée / tireur** | suit la courbe de sa voie ; vise dans l'ordre : héros ennemi qui frappe un héros allié (rayon 10 m), sbire ennemi le plus proche, tour, héros le plus proche ; réévalue toutes les 0,5 s (décalées) | vague = 3 mêlées + 2 tireurs ; mêlée meurt en ≈ 4 auto-attaques d'un héros niveau 1, tireur 3 ; un coup de sbire = 3 % des PV max d'un héros |
| **Bélier** | comme un mêlée, frappe les structures ×2 | 1 vague sur 3 (une sur 2 dès 12:00) ; ≈ 10 auto-attaques |
| **Géant** | après la chute de la T2 adverse de sa voie, et à la Marée | +1 par vague ; ≈ 25 auto-attaques |
| **Tour** (T1, T2) | portée 9 m ; vise sbires d'abord, puis héros ; **bascule sur le héros qui frappe un héros allié à portée** ; chaque tir consécutif sur le même héros +40 % (×2,2 au plus), remis à zéro après 5 s ; anneau de portée affiché quand un héros ennemi approche | tir = 10 % des PV max d'un héros ; mêlée 2 tirs, tireur 1, bélier 4 ; **−66 % de dégâts subis sans sbire ennemi à 12 m** ; T2 invulnérable tant que la T1 de sa voie tient ; T1 : dégâts subis ×0,5 avant 4:00 ; T1 seule contre une vague : ≈ 60 s ; 2 héros niveau 6 + vague : ≈ 20 s |
| **Cœur** | tire sur l'intrus le plus proche (2 tirs / s, 6 % des PV max) ; vulnérable dès qu'une T2 de son camp est tombée (ou à la Marée) | PV = 1,5 × une T2 |
| **Camp de jungle** | neutre : n'attaque que celui qui l'a frappé ; **laisse** de 12 m : revient et regagne tous ses PV | petit camp : 2 monstres, ≈ 12 s pour un jungler niveau 2 ; Source / Braise : 1 grand monstre, ≈ 20 s ; reviennent 90 s (petits) / 150 s (buffs) après |
| **Gardien** | un boss de palier 1 de la bibliothèque (2 briques), **tiré à la graine** : chaque partie a son Gardien | 4 héros niveau 5 : ≈ 25 s ; donne à l'équipe un **Sceau** (+4 % de dégâts et de PV pour toute la partie, 3 au plus : 3 étoiles près du score) |
| **Colosse** | un boss de palier 3 (3-4 briques, fureur à 90 s) | 4 héros niveau 10 : ≈ 45 s ; **Bannière du Colosse** 150 s : sbires proches d'un héros porteur plus gros et plus forts (×1,5), rappel en 3 s |

Neutralité (nouveau) : un camp « neutre » qui choisit sa cible parmi ceux qui l'ont frappé et ignore le reste ; les camps de héros
passent par `Team` (bleu = `Team.PLAYER`, rouge = `Team.MONSTER`), **pas** par `ffa_id` (réservé au chacun pour soi).

### 7.6 Les héros : sorts adaptés des 60 classes sans refaire les kits
- **Kit de partie généré** par `tools/moba_kits.py` à partir de `data/classes.json` et des enchaînements existants
  (`MlDuelPilot.kit_for`) : 3 cases de base + 1 **ultime**. Règles du tri, par classe : au moins un sort de déplacement s'il existe
  (`dash`, `blink` : 45 sorts dans le jeu), au moins un sort de contrôle (`applies` : renversement, étourdissement, ralentissement),
  au moins un soin pour la Ferveur (22 classes ont des soins) ; **ultime** = le sort offensif de plus forte valeur (multiplicateur × zone)
  parmi ceux de plus de 12 s de recharge, recharge portée à 60-90 s et puissance ×1,6 (pour la Ferveur : un renfort ou un soin d'équipe).
  Une seule classe a moins de 4 sorts offensifs (`life_worshipper`, 3) : ses soins comptent. Aucun kit n'est réécrit à la main ;
  un fichier `data/moba_kits.json` relu par un test (4 cases valides par classe).
- **Le niveau fait grandir le kit** (au lieu des points de sort de LoL) : niv. 1 = sorts principaux des cases 1-3 ; niv. 2, 3, 4 = le
  **1er enchaînement** d'une case au choix ; niv. 5 = **ultime** ; niv. 6, 7, 8 = 2e enchaînement d'une case au choix ; niv. 9 =
  enchaînement de l'ultime ; niv. 10-12 = rien à choisir, la fiche monte. Choix **non bloquant** : bandeau « Niveau 4 ! » au-dessus des
  cases (Ctrl + 1 / 2 / 3, croix ← ↑ → à la manette ; choix automatique en option et à la 1re partie).
- « **Mon kit** » (P1) : la grille 4 × 3 du préréglage de Duel de la classe (`SpellPresets`), même déblocage par niveaux.
- Rôles par famille (conseil, jamais imposé) : Rempart = Brumes ; Ombre = jungle ; Traque / Arcane = tir au Soleil ; Ferveur = soutien.
  Les alliés IA complètent sans doublon de famille (`Duel.team_classes`).

### 7.7 La boutique (`moba_maquettes/v2_boutique.svg`)
Ouverte à la fontaine et pendant la mort (P / Vue) ; le jeu continue derrière (panneau sur la moitié gauche). 6 places (bottes
comprises) ; potions à part (C / V). Onglets : Conseillé, Attaque, Magie, Défense, Soutien, Bottes, Potions (LB / RB). Le **parcours
conseillé** (par famille, 2 parcours chacune) se règle selon l'équipe adverse ; « Acheter » en un appui achète la prochaine étape
possible ; **Annuler l'achat** tant qu'on n'a pas quitté la base ; vendre = maintien 0,6 s (70 % du prix). Recette : on ne paie que
la différence. Textes : effet en une phrase, sans pourcentage (chiffres en infobulle, `test_texts_fr`).
Valeurs en part de la fiche de base de la classe au niveau de partie (« +10 % d'attaque » = 10 % de l'attaque de base).

| # | Objet | Type | Prix | Recette | Effet (phrase joueur ; règle) |
|---|---|---|---|---|---|
| 1 | Lame courte | composant | 350 | — | + attaque (10 %) |
| 2 | Grimoire usé | composant | 350 | — | + magie (10 %) |
| 3 | Cotte de mailles | composant | 400 | — | + défense (12 %) |
| 4 | Gemme de vie | composant | 400 | — | + PV (10 %) |
| 5 | Gant de vitesse | composant | 450 | — | + vitesse d'attaque (12 %) |
| 6 | Œil de faucon | composant | 500 | — | + critique (8 points) |
| 7 | Sablier fêlé | composant | 500 | — | + recharges (8 %) |
| 8 | Plume de soin | composant | 450 | — | + puissance de soin (12 %) |
| 9 | Croc vampirique | composant | 550 | — | + vol de vie (5 %) |
| 10 | Bottes de marche | bottes | 300 | — | + vitesse de déplacement (8 %) |
| 11 | Lame de braise | attaque | 2 400 | 1 + 6 | « Tes critiques brûlent. » (proc `crit` → `burn`) |
| 12 | Croc du chasseur | attaque | 2 300 | 1 + 9 | « Éliminer un héros te soigne. » (`kill` → `heal`) |
| 13 | Arc-tempête | attaque | 2 600 | 5 + 6 | « Un coup sur trois fait jaillir la foudre. » (`basic_hit` → `lightning`) |
| 14 | Faux de la Lune | attaque | 2 400 | 1 + 7 | « Après un sort, ton coup suivant frappe plus fort. » |
| 15 | Brise-garde | attaque | 2 500 | 1 + 1 | « Tes coups traversent une part de la défense. » (stat nouvelle : pénétration) |
| 16 | Lame de l'exécuteur | attaque | 2 600 | 1 + 5 | « Plus fort contre les héros affaiblis. » (exécution étendue aux héros, plafonnée) |
| 17 | Orbe des marées | magie | 2 300 | 2 + 7 | « Un sort qui touche un héros te protège un instant. » (`skill_hit` → bouclier) |
| 18 | Bâton de l'éclipse | magie | 2 800 | 2 + 2 | « Ta magie grandit encore. » (+25 % de magie totale) |
| 19 | Grimoire des échos | magie | 2 600 | 2 + 6 | « Tes sorts frappent parfois deux fois. » (`skill_hit` → `echo`) |
| 20 | Sceptre du givre | magie | 2 400 | 2 + 4 | « Tes sorts ralentissent. » (`skill_hit` → `chill`) |
| 21 | Lanterne des âmes | magie | 2 300 | 2 + 9 | « Tes sorts te soignent. » |
| 22 | Égide du Rempart | défense | 2 400 | 3 + 4 | « Plus solide quand ils sont plusieurs sur toi. » |
| 23 | Cœur de pierre | défense | 2 500 | 4 + 4 | « Hors combat, tu reprends vite des forces. » |
| 24 | Cape d'épines | défense | 2 300 | 3 + 3 | « Qui te frappe se blesse. » (renvoi d'auto-attaque) |
| 25 | Bouclier du gardien | défense | 2 400 | 3 + 7 | « Au bord de la chute, un bouclier te sauve. » (`low_hp` → bouclier, 60 s) |
| 26 | Armure vivante | défense | 2 200 | 4 + 8 | « Les soins reçus sont plus forts. » |
| 27 | Heaume du colosse | défense | 2 300 | 3 + 5 | « Les contrôles te tiennent moins longtemps. » (stat nouvelle : ténacité) |
| 28 | Encensoir sacré | soutien | 2 200 | 8 + 8 | « Soigner un allié le rend plus rapide à frapper. » |
| 29 | Médaillon des aurores | soutien | 2 300 | 8 + 4 | « Ton prochain soin protège aussi. » (60 s) |
| 30 | Harpe du vent | soutien | 2 100 | 8 + 10 | « Soigner un allié l'accélère. » |
| 31 | Étendard des voies | soutien | 2 200 | 4 + 7 | « Les sbires près de toi frappent plus fort. » |
| 32 | Sablier du sage | polyvalent | 2 400 | 7 + 7 | « Une élimination raccourcit tes recharges. » (`kill` → `cdr`) |
| 33 | Bottes de l'élan | bottes | 1 000 | 10 + 5 | vitesse + vitesse d'attaque |
| 34 | Bottes du rempart | bottes | 1 000 | 10 + 3 | vitesse + défense |
| 35 | Bottes du sage | bottes | 1 000 | 10 + 7 | vitesse + recharges |
| 36 | Bottes du vent | bottes | 1 000 | 10 + 10 | vitesse, encore plus hors combat |
| 37 | Potion de soin | potion | 50 | — | `core/potions.gd` « heal » |
| 38 | Potion d'élan | potion | 75 | — | « haste » |
| 39 | Potion de rage | potion | 100 | — | « frenzy » |
| 40 | Potion d'acuité | potion | 100 | — | « keen » |

Les effets passent par `Procs` (déclencheurs existants) : `Procs.fire` doit accepter un `Combatant` (aujourd'hui `Player` seul) pour que
les IA en profitent ; les stats des IA viennent de leur fiche refaite à chaque achat (`Royale.sheet` / `refresh_ai` comme modèle). Deux
stats nouvelles (pénétration, ténacité) ; si elles coûtent trop, les objets 15 et 27 deviennent « + attaque » et « + PV » (Q13).

### 7.8 L'IA : quatre couches, aucune triche
1. **Combat** (existant, `ClassRival`) : lecture des zones et esquives, cible la plus faible, repli sous 30 %, soutien de camp. Ajouts :
   **tours** (n'entre jamais sous une tour ennemie qui ne vise pas un sbire, sauf « plongée sûre » : cible tuable en 2 s, PV ≥ 60 %,
   Difficile et plus) ; **sbires** (ne frappe pas un héros au milieu d'une vague ennemie : appel à l'aide) ; **lit les coups de tous
   les héros**, pas seulement ceux du joueur (`_read_player` élargi).
2. **Poste** (`moba_hero_ai.gd`) :
   - *voie* : se tient 4 m derrière le front de sa vague, frappe les sbires à portée, échange quand le rapport de force (`power_ratio` :
     PV, niveau, objets) dépasse 1,1, recule sous la tour sous 0,8 ; rappel sous 30 % de PV si aucun combat n'est engagé, ou dès que
     l'or permet le prochain objet + 300 et que la vague est poussée ;
   - *jungle* : parcours des camps précalculé selon les minuteurs ; attaque une voie quand le héros ennemi y est sous 60 % de PV ou
     au-delà de la rivière ; prépare les objectifs 40 s avant ;
   - *soutien* : suit le tireur, se place entre lui et la menace la plus proche, garde ses soins pour le plus bas, renforts au début du combat.
3. **Équipe** (`moba_coach.gd`, une décision par seconde, gardée 8 s au moins sauf urgence) : lit une **vue honnête** (seuls les ennemis
   vus par un allié ou une structure dans les 25 m, plus leur dernière position connue qui s'efface en 10 s) et une **carte d'influence**
   (grille de 4 m : menace des ennemis vus + portée des tours ennemies, 1 500 cases, mise à jour 2 fois par seconde). Plans : FARMER
   (par défaut), DÉFENDRE (tour attaquée), GROUPER pour un objectif (Gardien / Colosse, si 2 ennemis ou plus sont morts ou vus
   ailleurs), POUSSER (après un avantage numérique), REPLI (en infériorité), MARÉE (dès 18:00, on se regroupe). Chaque plan donne un
   ordre à chaque héros ; le joueur reçoit la même information en bulle (« Ninja : va au Gardien »).
4. **Économie** : parcours par famille (2 chacune), adapté à l'équipe adverse (2 Ombre ou plus : PV et défense d'abord ; 2 Arcane ou
   plus : Heaume ; beaucoup de soins adverses : Lame de braise) ; achète à chaque passage à la base ; ne rentre pas que pour acheter
   avant 4:00.
- **Repères du joueur = ordres** (Normal et plus) : « Attaquez ! » sur un héros → les alliés à 30 m le prennent pour cible ;
  « Objectif » sur le Gardien / Colosse / une tour → plan GROUPER sur ce point ; « Repli ! » → retour à la tour alliée la plus proche ;
  « À moi ! » → le jungler ou le soutien vient ; « J'y vais » → le coach en tient compte. L'allié répond par une bulle (« D'accord ! »)
  et un son court ; un ordre impossible (trop loin, mort) répond « Pas maintenant ». Les IA alliées posent aussi des repères
  (« Le Gardien dans 30 s », « Ennemi disparu »), une fois par 20 s au plus.
- **Difficultés** (les deux camps à la même par défaut, règle de la passe M7 ; « Alliés plus forts » en option) :

| Réglage | Facile | Normal | Difficile | Hardcore |
|---|---|---|---|---|
| Combat (`ClassRival.DIFF`) | 0 | 1 | 2 | 3 |
| Décision du coach | toutes les 3 s | 2 s | 1 s | 0,5 s |
| Objectifs | réagit à l'apparition | se prépare 20 s avant | 40 s avant | 60 s avant, tend des embuscades dans les buissons |
| Erreurs de position (plonge sous tour, poursuit trop loin) | 30 % des occasions | 12 % | 4 % | 0 |
| Rappel et achats | oublie 1 retour sur 3, parcours fixe | parcours conseillé | adapte à l'adversaire | adapte et vend les bottes en fin de partie |
| Rotations | jamais | après une tour | après une élimination ou un objectif | anticipe les absences ennemies |

- **Mesure** (comme l'Échiquier, `R_AC_J.md`) : `tools/moba_games.tscn` joue des parties IA contre IA sans joueur (rendu coupé,
  `--fixed-fps 60`), une ligne JSON par partie ; `tools/moba_report.py` vérifie : durée médiane 15-19 min, moins de 5 % de parties
  à la fin au temps, Hardcore bat Normal ≥ 85 %, Difficile bat Normal ≥ 70 %, chaque famille à son poste conseillé entre 45 et 55 %
  de victoires (≥ 400 parties), aucun blocage (héros immobile plus de 20 s). Un joueur simulé (`Player.autoplay`) remplace le joueur
  pour estimer la difficulté ressentie. Tout changement d'IA se mesure au banc avant d'être gardé (règle d'AC-U).

### 7.9 Écrans, contrôles, confort
- **HUD** (`v2_hud.svg`) : en haut au centre le tableau (8 portraits, minuteurs de réapparition sur les morts, score, temps, tours
  restantes) et dessous les minuteurs d'objectifs (Gardien mandarine, Colosse améthyste) ; **une seule annonce à la fois** (bulle lagon,
  `HudAlert`) ; en haut à droite la mini-carte (294 × 190, comme les autres modes) avec brouillard tramé, et le fil des éliminations ;
  à gauche les 3 alliés (PV, niveau, ultime prêt, **intention écrite**) ; en bas la carte du héros (anneau d'XP, niveau, PV), 4 cases
  autocollantes avec **plots d'enchaînements** (débloqués en pomme) et l'ultime cerclé de soleil, verrouillé « niv. 5 » ; esquive,
  rappel, potion ; en bas à droite l'or et l'objet conseillé avec sa barre (« 1 240 / 2 300 »). Aucun pourcentage en texte permanent.
- **Plaques** : héros = barre courte + niveau, nom au survol seulement ; allié lagon arrondi, ennemi fraise **à coins coupés** (lisible
  sans la couleur) ; sbires = barre seule quand ils ont été touchés ; tours = barre et anneau de portée en approche.
- **Caméra** : distance 22 m par défaut dans ce mode (au lieu de 15), zoom de 12 à 28 m ; **maintenir le clic sur la mini-carte**
  regarde ailleurs sans bouger, relâcher revient ; manette : Vue maintenu = grande carte.
- **Contrôles** : ceux du jeu (Settings) : ZQSD + clic, ou « clic droit (stratégie) » (`move_order`) ; sorts 1-4 / A E R T, RB RT LB LT ;
  esquive Maj / B ; boutique **P** (action nouvelle) / Vue à la base ; rappel X (`extract`) ; repères molette / L3 (appui = contextuel,
  maintien = roue) ; tableau des scores Tab / croix ← (les objectifs n'existent pas dans ce mode) ; choix de niveau Ctrl + 1/2/3 / croix.
- **Accessibilité** : couleurs de camp réglables (bleu / rouge ou bleu / orange) et formes distinctes ; télégraphes v2 hachurés ;
  « Atténuer les effets des autres héros » (réglage existant) conseillé à la 1re partie ; texte ≥ 14 px ; pause.
- **Premiers pas** : partie guidée (Facile, alliés Difficile) en 5 étapes : la vague et la tour, l'or et la boutique, le niveau et
  l'enchaînement, le Gardien, le Cœur ; 5 fiches (≤ 125 signes) ; chapitre « Les Deux Voies » du Guide F1.
- **Retours** (BIBLE § 7-8) : « Premier sang ! », « Tour ! », « Colosse ! », « Série ! » en onomatopées Mochiy 600 ms ; tour qui tombe
  = secousse et éclats ; Cœur qui explose = ralenti 1 s, traits de vitesse, confettis à la victoire ; repères et ordres = « tic » de bulle.

---

## 8. Risques techniques et parades

| Risque | Gravité | Ce qu'on sait | Parade |
|---|---|---|---|
| **Image** : 8 héros + 40-60 sbires + 10 structures + 12 monstres + effets | haute | IA scriptée 0,10 ms par unité sans rendu (`R_AC2.md`) ; création 18-48 ms par modèle ; la Survie tient des hordes grâce au `lite` et au LOD de `Monster` ; la séparation des monstres a déjà coûté 20 ms en foule dense (`R_SVX1.md`) | **MB-0 d'abord** ; sbires légers (courbe de voie, pas de chemin calculé hors poursuite, cible toutes les 0,5 s décalée, pas d'ombres, animation à demi-cadence hors écran) ; modèles préchargés au choix des héros ; pool de projectiles ; chiffres des sbires regroupés ; cible : p95 < 16,6 ms en 1600 × 900, logique < 6 ms |
| **Navigation** | moyenne | la Survie précuit son maillage sur un fil (piège T1 : quitter avant la fin plante) | carte **fixe** et maillage **précuit dans la scène** ; voies en `Path3D` ; héros et camps sur `NavigationServer3D` comme aujourd'hui |
| **IA d'équipe** : oscillations, blocages, objectifs mal joués | haute | le Battle royale a une macro par ordres qui marche (`RoyaleDirector.BRAIN`) ; le genre lui-même reconnaît des bots faibles | plans à hystérésis (8 s), carte d'influence, banc IA contre IA avec seuils (§ 7.8), journal des décisions par partie |
| **Neutralité** (jungle) | moyenne | `Monster` ne connaît que héros et monstres ; R_AC2 signale une cible figée de `Monster` avec les camps natifs | `MobaCamp` ne choisit que parmi ses agresseurs ; test de laisse et de remise à zéro |
| **Équilibre des 60 classes** | haute | à distance gagne en terrain nu (BR1) ; kits très inégaux en sorts de déplacement | couvert, tours, profil `moba` mesuré ; équilibre par **poste** et par famille (pas par classe) ; correctif par classe seulement si une classe sort de 40-60 % sur 200 parties |
| **Lisibilité** à 8 héros | haute | capture 21 : déjà illisible à 6 | P1-20 (contours alliés, plaques courtes), plafond d'effets par réglage existant, télégraphes v2 jamais atténués |
| **Durée** qui dérive | moyenne | Dota Turbo et Wild Rift règlent la durée par l'économie | Marée à 18:00, fin au temps à 25:00, mesure médiane par MB-J |
| **HUD absent en Duel** (capture) | moyenne | constaté en 0.1.284 sur `shot_m7` | à vérifier avant MB-H : le HUD d'équipe repose sur le même calque |
| **Taille du chantier** | haute | 12 lots | essai go / no-go, lots indépendants testés, `test_nav_screens` / `test_texts_fr` à chaque lot |

---

## 9. Plan des lots d'implémentation

Estimation honnête en jours d'agent (une session complète = 1 jour). Chaque lot : rapport `conception/moba/R_MB_<lot>.md`, tests, captures
regardées, BIBLE v2 + `UiTheme` v2 / `UiFeel`, aucun mot anglais côté joueur. Dossier de conception : `conception/moba/` (SPEC = ce § 7).

| Lot | Contenu | Dépend de | Jours | Test / acceptation |
|---|---|---|---|---|
| **MB-0** | Essai technique : scène plate 200 × 120, 8 `ClassRival` qui se battent, 48 sbires qui marchent sur 2 courbes, 10 tours qui tirent ; mesures fenêtré 1600 × 900 et sans rendu ; **go / no-go** et budget par unité | — | 2 | p95 < 16,6 ms ou plan de réduction chiffré |
| **MB-A** | `MobaData` (réglages, tables or / XP / réapparition, 40 objets, camps, objectifs), kits générés des 60 classes, profil `moba`, `Modes.sealed()` | — | 2 | `test_mb_data` : 60 kits valides, 40 objets, recettes cohérentes, aucun texte avec « % » |
| **MB-B** | Carte (scène fixe ou `ProcMap.generate_moba`), voies, maillage précuit, buissons, rochers, bases, décor | MB-0, MB-A | 3 | captures `map_shots` ; trajets de base à base 28-32 s |
| **MB-C** | Tours, Cœur, sbires, vagues, protections, victoire ; état `Moba` et directeur `MobaDirector` | MB-B | 4 | `test_mb_lanes` : 20 min de vagues seules sans chute ; un camp ×1,2 fait tomber T1 vers 8-10 min |
| **MB-D** | Héros en partie (niveaux, enchaînements, ultime, choix non bloquant, or, XP, primes, mort, rappel, fontaine) + boutique (logique, achat / annuler / vendre, objets sur le joueur et les IA, `Procs` sur `Combatant`) | MB-A, MB-C | 4 | `test_mb_hero` : niveau 5 = ultime ; achat → stats ; annuler rend l'or |
| **MB-E** | IA par poste (voie, jungle, soutien), tours et sbires respectés, rappel, achats | MB-C, MB-D | 5 | `test_mb_ai_role` : 0 mort sous tour en Hardcore sur 20 parties ; jungler fait ≥ 6 camps avant 4:00 |
| **MB-F** | Jungle neutre, Source / Braise, Gardien et Colosse (bibliothèque), Sceaux, Bannière, Marée, fin au temps | MB-C (MB-E pour l'IA) | 3 | `test_mb_objectives` : laisse, minuteurs, bonus appliqués, décision à 25:00 |
| **MB-G** | Coach d'équipe (vue honnête, carte d'influence, plans), repères → ordres, repères des IA ; banc `moba_games` + `moba_report.py` | MB-E, MB-F | 5 | seuils du § 7.8 sur 400 parties |
| **MB-H** | HUD et écrans en partie (tableau, mini-carte à brouillard, cadres, cases à plots, choix de niveau, boutique, roue, annonces, fil, Tab, mort) ; manette | MB-D (MB-G pour les intentions), UIK-0 | 5 | `shot_mb` 1280 × 720 et 1600 × 900 sans débord ; `test_nav_screens` |
| **MB-I** | Entrée et fin (activité, image, page, choix des postes et des héros, chargement, bilan, récompenses scellées, quêtes, aide aux ressources, boussole) | MB-H | 3 | `test_p4_activities` étendu ; `test_texts_fr` |
| **MB-J** | Mesure et calibrage (durée, postes, familles, difficulté, image) ; `tests/mb_mesures.json` relu par `test_mb_sim` | MB-F, MB-G, MB-I | 4 | médiane 15-19 min ; image tenue |
| **MB-K** | Premiers pas (partie guidée, fiches, Guide), réglages de confort, moments manga et sons | MB-I, MB-J | 3 | `test_lot9` / tutoriel ; capture de chaque moment |

**Total ≈ 43 jours d'agent**, 55 avec une marge de 30 % (l'IA d'équipe et l'équilibre se mesurent en boucles). Parallélisme : MB-0 et MB-A
ensemble ; puis MB-B → MB-C ; ensuite MB-D et MB-F en parallèle, MB-H dès MB-D ; MB-E → MB-G ; MB-I, MB-J, MB-K à la fin. Avec 2 à 3
agents : **≈ 4 à 5 semaines** calendaires. Le P1 tient dans ces lots sauf 13 (buissons : +2 j dans MB-G / MB-H) ; le P2 est hors devis.

---

## 10. Questions ouvertes (recommandation par défaut)

| # | Question | Recommandation par défaut | Pourquoi |
|---|---|---|---|
| Q1 | Combien de voies ? | **2 voies + jungle** | à 4 contre 4, 3 voies laissent des voies vides ; 1 voie (Vainglory) force le combat mais sans choix de carte ; UNITE et l'ancienne carte 3 contre 3 de LoL (retirée en 2019) avaient, de mémoire, 2 voies (**non vérifié**) |
| Q2 | Niveaux par héros ou d'équipe (HotS) ? | **Par héros**, avec rattrapage | les objets sont personnels ; un niveau d'équipe effacerait le rôle du jungler |
| Q3 | Dernier coup sur les sbires ? | **Non requis** : or partagé de proximité, bonus au dernier coup | combat d'action, caméra proche : le dernier coup raté serait une punition, pas une compétence |
| Q4 | Où acheter ? | **À la base et pendant la mort** ; achat conseillé en un appui ; achat automatique en option (actif à la 1re partie) | le retour à la base rythme la partie ; HoK achète partout, mais notre rappel est court |
| Q5 | Brouillard de guerre ? | **Mini-carte seulement + buissons** ; l'IA le respecte | la caméra proche cache déjà le reste ; le vrai brouillard coûte cher et embrouille |
| Q6 | Classes non débloquées jouables ? | **Oui, les 60** | mode scellé : vitrine des classes, aucune puissance de compte |
| Q7 | Kit de la partie ? | **Généré par classe** (3 + ultime) ; « Mon kit » en option | 60 kits sans travail manuel ; le joueur garde ses habitudes de Duel |
| Q8 | Les alliés obéissent-ils aux repères ? | **Oui, dès Normal** | c'est l'avantage du solo contre l'IA : le joueur est capitaine |
| Q9 | IA sur `ClassRival` ou `Player` piloté par un script (`BotInput`) ? | **`ClassRival`** + couches MOBA ; revoir à MB-0 si l'écart de kit est trop visible | éprouvé partout, 4 difficultés, coût mesuré ; `Player` piloté donnerait l'égalité exacte de kit mais tout est à écrire |
| Q10 | Durée ? | **Médiane 17 min**, Marée à 18:00, fin au temps à 25:00 | Wild Rift vise 16-18 min ; la fin forcée évite les parties sans fin contre l'IA |
| Q11 | Nom côté joueur ? | **« Les Deux Voies »** (autres : « La Bataille des Voies », « Le Champ des Cœurs ») | « MOBA » est interdit par la BIBLE ; le nom dit la carte |
| Q12 | Récompenses ? | **Apparences, titres, maîtrise ; insignes plafonnés au jour** ; coffres rares à partir de Difficile | même logique que le Battle royale et la Ligue |
| Q13 | Stats nouvelles (pénétration, ténacité) ? | **Oui si MB-D les tient en 1 jour**, sinon objets 15 et 27 simplifiés | deux objets seulement en dépendent |
| Q14 | Format court « Escarmouche » (1 voie, 10 min) ? | **Plus tard (P2)**, après la mesure de la vraie partie | ne pas diviser l'équilibrage tant que la carte principale n'est pas réglée |
| Q15 | Pause pendant la partie ? | **Oui** (solo) | confort ; rien à protéger |

---

## 11. Ce que cette étude n'a pas pu confirmer
Durée moyenne d'une partie de HotS et de Mobile Legends ; achat rapide actuel de Wild Rift ; achat conseillé de Honor of Kings ; carte
et objectif final actuels de Pokémon UNITE ; détail du choix d'amélioration de sort de UNITE ; buffs de la jungle de Smite 2 (une source).
Aucun de ces points ne fonde une règle de la spécification. À faire à part (hors de cette étude) : vérifier pourquoi le HUD n'apparaît
pas sur les captures des Arènes et mettre à jour `tests/shot_m7.gd` (la pause ne se referme plus).
