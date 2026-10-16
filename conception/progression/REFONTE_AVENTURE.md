# Refonte « Aventure » — la progression du compte (PR1, conception, 16/10/2026, jeu 0.1.218)

Session PR1 : conception seule, aucun fichier de jeu modifié. Mesures : `res://tools/progression_sim.tscn` (12 comptes « moyen »,
guerrier, 50 h, graine 1) sur une copie de HEAD 0.1.218, et une **copie modifiée** de l'outil (drapeaux décrits en annexe, à
intégrer par le lot A7). **M** = mesuré, **E** = estimé. Le simulateur est le modèle d'E6 (±30 % en absolu, fiable en relatif).

Demande du joueur (16/10) : la Survie devient **l'Aventure**, le mode qui fait progresser la force du compte, du premier
équipement à un équipement niveau 90 optimisé ; échouer une run faute d'équipement est normal ; l'Aventure donne les plans (ce
qu'on y **découvre** devient fabricable), **les insignes servent à fabriquer**, **les Donjons donnent des plans ET des pièces
déjà fabriquées** ; un RPG où l'on devient plus fort, sans quêtes obligatoires ni « bash » de monstres inutile. Cible chiffrée :
**≈ 30 h** de l'heure 0 à un **équipement 90 correct d'une classe** (jouable sur tout le contenu) ; ensuite l'optimisation de
toutes les classes est la longue traîne (centaines d'heures).

---

## 0. En bref

1. **Colonne vertébrale gardée** : une pièce **découverte** en Aventure (`Profile.seen_gear`) **est** un plan ; l'Armurerie
   devient l'onglet **« Fabriquer »** (même page, mêmes prix d'E5 ; bouton « Fabriquer », statuts « À fabriquer / Fabriquées /
   Plans à découvrir »). Rien n'est recréé sous un autre nom.
2. **Rôles** : Aventure = **découvrir** + insignes + maîtrise ; insignes = **fabriquer** (les deux sortes de plans) ; Donjons =
   **pièces directes + plans de donjon** (pièces à panoplie de donjon) ; cristaux et Forge = **optimiser**.
3. **Plans de donjon par boss** (48), garantis à la 1re victoire contre ce boss, fabriqués **en insignes** (plus en cristaux).
4. **Le boss de chaque carte** donne un **coffre de plans** (une pièce non découverte du palier, au choix parmi 3).
5. **Donjons dès l'époque I gagnée**, zone par zone (avant : époque II) ; plus de salles de monstres seuls (≈ 7 min).
6. **Constat clé** (§2.3) : en Aventure le héros plafonne au niveau 35, donc **le niveau d'une pièce au-delà de 35 n'y compte
   pas** ; viser des pièces de haut niveau y **ralentit** même (M : époque IV 39 h au lieu de 31 h). Proposition mesurée :
   **décote de palier** + `MONSTER_MULT` **0,85 / 1,3 / 2,3 / 4,4** → **équipement 80-90 correct à 29,3 h** (M).
7. **Anti-bash** : quêtes sans insignes ni cristaux ; insignes de l'Aventure aux cartes et aux boss plus qu'aux monstres ;
   donjons sans remplissage.
8. **Renommage en dernier** (lot A9), en une passe, après N2 ; identifiants, clés de sauvegarde et tests jamais renommés.

---

## 1. Renommage « Survie » → « Aventure »

### 1.1 Ce qui change (texte lisible par le joueur seulement)

| Où | Fichier | Exemples |
|---|---|---|
| Page Jouer | `ui/activities.gd` | nom « Survie » → **« Aventure »**, sous-titre « Époques, plans et boss », `gain` « Plans, insignes, maîtrise » ; rangée `ROWS` « Aventure » → **« Progression »** (Aventure, Donjons, La Tour) ; `GROUPS` « Aventure (JcE) » → « JcE » ; le **Survivant** passe dans la rangée « Défis » (hors progression) |
| Fil d'éveil | `core/unlocks.gd` | `name` de `survival` ; conditions « Termine une première Survie », « Termine 3 Survies », « Découvre une première pièce dans un coffre de la Survie » |
| Succès | `core/achievements.gd` | `desc` « Terminer / Gagner N Survies » → « … Aventures » ; **ids et titres inchangés** (Habitué, Vétéran, Conquérant) |
| Quêtes, contrats | `core/quest_pool.gd` (12 textes `sv_*` + nom d'activité), `core/contracts.gd` | textes recalculés à l'affichage (`Quests.title`) : rien à migrer |
| Boussole, aide, Registre | `core/compass.gd`, `core/resource_help.gd`, `core/class_gear.gd` (« Survie, puis Armurerie » → « Aventure, puis Atelier »), `core/completion.gd` |
| Donjons, Atelier, coffres | `core/dungeons.gd` (`condition`), `ui/dungeon_page.gd`, `ui/gear_shop_page.gd`, `ui/chests_page.gd` |
| Guide, aide, accueil | `ui/guide.gd` (onglet « Survie », 11 textes), `ui/info_page.gd` (section « Survie »), `ui/welcome.gd`, `core/tutorial.gd`, `ui/quests_page.gd`, `ui/carnet_pages.gd`, `ui/inventory_page.gd`, `ui/merchant_ui.gd` |
| Partie, bilans | `ui/results_screen.gd`, `ui/results_panel.gd`, `ui/hud.gd`, `ui/lobby.gd`, messages de `core/run_director.gd`, `core/world.gd`, `core/craft.gd`, `world/proc_map.gd` |
| Docs | `DESIGN.md` (partie B « L'Aventure (ex-Survie, id `survival`) »), `CLAUDE.md`, nouvelles lignes de `CHANGELOG.md` |

### 1.2 Ce qui reste interne (NE PAS renommer)

Ids `"survival"` (`Activities`, `Unlocks`, `QuestPool.act`, menus `{"menu": "survival"}`, `Modes`), `Run.survival`,
`Run.start_survival`, `Profile.end_run_survival`, toutes les clés de `Profile.records` et de la sauvegarde (`seen_gear`,
`epochs_cleared`, `boss_<zone>`, `epoch_stars_*`, `heroic_best_*`, `class_first_wins`…), `Economy.INSIGNIA_PER_HOUR`
(`survie_1`…), mode `survival` du journal, scénario `survie` de `ml_arena.gd`, noms de fichiers, de scènes, d'images
(`assets/ui/activities/survival.jpg`), de tests et d'outils (`sim_survie.py`). **Jamais** : « Instinct de survie », « Survie
désespérée » (`combatant.gd`, `trophies.gd`, `data/classes.json`, `data/talents.json`), ni `data/names_fr.json` (noms d'objets).

### 1.3 Remplacement sûr (lot A9)

1. Lister : `grep -rn '"[^"]*Survie[^"]*"' game/scripts` (≈ 96 littéraux) ; exclure `data/`, `combatant.gd`, `trophies.gd`,
   `ml_arena.gd`, les clés d'`economy.gd`, et toute ligne avec « Instinct de survie » / « Survie désespérée ». Les commentaires : libre.
2. Dans les seuls littéraux retenus, **dans cet ordre** (élisions) : « de la Survie » → « de l'Aventure » ; « à la Survie » →
   « à l'Aventure » ; « la Survie » → « l'Aventure » ; « La Survie » → « L'Aventure » ; « de Survie(s) » → « d'Aventure(s) » ;
   « Survies » → « Aventures » ; « Survie » → « Aventure » (« une / ta première / en Survie » restent justes). Relire chaque ligne.
3. Tests qui comparent un texte : `test_e3` (« Survie, puis Armurerie » ×2), `test_compass`, `test_pages`, `test_nav_screens` ;
   puis toute la suite (`python tools/run_tests.py -j 4`) et `test_texts_fr`.
4. Garde-fou : un test (dans `test_texts_fr`) refuse tout littéral lisible « Survie » hors liste blanche.

---

## 2. La boucle de progression

### 2.1 Une source, un verbe (aucune nouvelle monnaie)

| Ressource | Verbe | Source principale (unique) | Sert à |
|---|---|---|---|
| **Plan d'aventure** (pièce découverte, `seen_gear`) | découvrir | **Aventure** : pièce choisie dans un coffre d'emplacement (gardée même en défaite) ; **coffre de plans** du boss de chaque carte (nouveau) ; arme choisie = l'arme du palier dans les 17 types (E4, inchangé) | Atelier > **Fabriquer** |
| **Plan de donjon** (`Profile.plans`, par boss) | découvrir | **Donjons** : 1re victoire contre chaque boss (garanti, sans doublon) | Atelier > **Plans de donjon** : pièce d'un des 2 emplacements du boss, à sa panoplie de donjon |
| **Insignes** | **fabriquer** | **Aventure** (barème E5) ; JcJ plafonné au jour | les deux sortes de plans ; puits sobres d'E5 (apparences, leçons) |
| **Pièce directe** | obtenir | **Donjons** (coffre de set : 3 pièces des 2 emplacements du boss, mythique / légendaire selon la PE, éveillée 1 sur 4 en Mythique) ; Ruée, Siège (coffre d'équipement), Tour, Panthéon (Esprits) | porter, monter |
| **Cristaux** | **optimiser** | Donjons, Ruée, Siège, Tour (E1 / E6) | Forge : +N, polir, réforger, fusion |
| **Fournitures** | optimiser | coffres de matières des activités (E1) ; Aventure au palier de l'époque (secondaire, utile avant les Donjons) | Forge |

Pourquoi deux sortes de plans : le plan d'aventure donne la **base** de chaque palier (toutes les panoplies d'origine, tous les
types d'arme, donc toutes les classes), sûre ; le plan de donjon donne une pièce qui porte **en plus** la panoplie du donjon
(bonus 2 / 4 / 6 cumulé) : le « mieux que la base », lié au boss qu'on choisit. La **pièce directe** reste utile après le plan :
elle peut être légendaire ou éveillée avant que le plan ne le permette (le plan suit la meilleure difficulté finie contre ce boss).

### 2.2 L'échelle d'équipement (paliers de l'Aventure ; prix M, `Economy.base_price`)

| Palier | Carte (zone) | Niveau armure / arme | Rareté | Kit 9 pièces | Donjon de la zone Normal / Héroïque |
|---|---|---|---|---|---|
| I-1 | Limestone | 23 / 20 | mythique | 478 | 14 / 29 |
| I-2 | Rainbowfall | 33 / 30 | mythique | 558 | 25 / 40 |
| I-3 | Beluga | 43 / 40 | mythique | 648 | 35 / 50 |
| II-1 | Wetlands | 48 / 45 | mythique | 693 | 39 / 54 |
| II-2 | Avila | 53 / 50 | mythique | 742 | 47 / 62 |
| II-3 | Arid | 60 / 60 | légendaire | 1 800 | 54 / 69 |
| III-1 | Delphi | 65 / 65 | légendaire | 1 890 | 57 / 72 |
| III-2 | Blackflame | 70 / 70 | légendaire | 1 980 | 60 / 75 |
| III-3 | Wetlands | 70 / 75 | éveillé (armure) | 2 140 | — |
| IV-1 | Avila | 80 / 80 | légendaire | 2 160 | — |
| IV-2 | Arid | 85 / 85 | légendaire | 2 250 | — |
| IV-3 | Blackflame | 80 / 90 | éveillé (armure) | 2 230 | **Mythique (tous les donjons) : 90** |

Au-dessus de la base : **+N** (×2 des stats de base à +10), **gemmes** (2, cinq qualités), **enchantement** (Lv 1-9), **panoplie
d'origine** et **panoplie de donjon** (2 / 4 / 6 chacune), jet de qualité. Verrous inchangés : époque N+1 = époque N gagnée ;
Donjon d'une zone = boss de la zone battu en Aventure ; Héroïque / Mythique = PE (`GearPower.DIFF_RATIO` 3,6 / 3,1 ; Siège 4 / 3,4).
Catalogue : 1 810 pièces à découvrir sur 273 paliers (E5), 48 plans de donjon.

**« Équipement 90 correct »** (cible des 30 h) = les 9 emplacements en pièces de l'époque IV (armure 80-85, arme jusqu'à 90),
légendaires ou éveillées, **+5 au moins**, quelques gemmes : il ouvre le Mythique (PE 55 800) et le Siège Mythique. Les pièces 90
partout (Mythique), +10, gemmes royales, enchantements 8-9 et panoplies 6 / 6 = « optimisé » = longue traîne.

### 2.3 Constat : le niveau d'une pièce ne se sent pas en Aventure → décote de palier

`Items.power_level` = min(niveau du héros, plafond de la pièce) en run, et le héros plafonne à **15 / 25 / 35** (`Epochs.CAPS`) :
toute pièce de niveau ≥ 35 vaut la même chose en Aventure à rareté égale (une légendaire 85 = une légendaire 60). Mesures (M) :
un compte qui choisit ses pièces sur leur valeur **en Aventure** (A) finit à des pièces 65-80 et ne fait jamais de Mythique en
50 h ; un compte qui vise **le niveau** (E, `--hubvalue`) progresse **moins vite** (époque IV 39 h au lieu de 31 h : chaque pièce
neuve repart de +0 sans rien gagner en Aventure) et n'a son équipement 80 correct qu'à 42 h. Le « stuff du niveau 1 au 90 » est
aujourd'hui une impasse en Aventure.

**Décision proposée (lot A6)** : en Aventure, le niveau de puissance d'une pièce est multiplié par `clamp(niveau de la pièce /
palier de la carte, 0,5, 1)` (palier = niveau d'armure ou d'arme de la carte, §2.2). Une pièce à son palier : rien ne change ;
une pièce I-3 (43) en carte IV-1 (80) compte ×0,54 en niveau (≈ ×0,3 sur ses stats). L'écart d'époque passe en partie dans la
décote : `MONSTER_MULT` **0,85 / 1,7 / 3,4 / 7 → 0,85 / 1,3 / 2,3 / 4,4** (M, colonne H du §3.1). Effet : chaque époque demande
**les pièces de son palier** (plans de l'époque + insignes, ou donjons de ses zones) ; le niveau 90 devient l'objectif réel.

### 2.4 Compte neuf, de l'heure 0 à 30 h et au-delà (refonte complète, colonne H ; heures M sauf mention)

| Heure | Ce qu'on fait | Ce qu'on gagne | Ce qui s'ouvre |
|---|---|---|---|
| 0-1 h | 1re Aventure (Premiers pas), défaites en carte 1-2 | équipement de départ (8 pièces rares), 1res découvertes I-1, ≈ 50-100 insignes par run | Coffres, Atelier > Fabriquer, Carnet |
| 1-3 h | Aventures de l'époque I ; fabriquer I-1 puis I-2 / I-3 | coffres de plans des boss, insignes | Quêtes (3 runs) ; **époque I gagnée à 3,0 h** (10 runs) |
| 3-8 h | époque II ; **Donjons de Limestone, Rainbowfall, Beluga** (Normal) ; Forge (+5) ; Tour | 1ers plans de donjon, pièces à panoplie de donjon, cristaux | Forge, Tour, Donjons ; **1er donjon à 3,1 h** (avant : 8,2 h) |
| 8-16 h | époque II gagnée (**8,3 h**) → III ; donjons de l'époque II, 1er Héroïque (**14,7 h**) ; Siège, Ruée | légendaires II-3 / III, gemmes, formules | Siège, Ruée, Héroïque |
| 16-30 h | époque III gagnée (**15,9 h**) → IV ; kits III puis IV fabriqués et montés ; Mythique ouvert (**26,7 h**) | pièces 80-90, plans de donjon Mythique | rangs héroïques, Mythique ; **époque IV gagnée 29,9 h** |
| **≈ 29-30 h** | **équipement 80-90 correct** (**29,3 h**, 75 % des comptes avant 50 h) ; kit +10 complet 29,7 h | | tout le contenu |
| 30-55 h (E) | optimiser la 1re classe : pièces 90 du Mythique, +10, gemmes royales, enchantements 8-9, panoplie de donjon 6 / 6 | | |
| 55-300 h (E) | 6 autres profils de stats, 17 armes, maîtrise 20 des 60 classes, titres, apparences, rangs héroïques | | §3.3 |

### 2.5 Ce qui est du « bash » inutile, et ce qu'on en fait

| Bash | Aujourd'hui | Décision |
|---|---|---|
| Salles de remplissage des donjons (2 salles de 44-56 monstres × PV 3,5 avant le boss, à chaque farm) | 6-10 min de joueur dont la moitié hors boss (R_M2) | salle 1 : **élites à mécanique** ; salle 2 : **lieutenant** ; salle 3 : **boss** ; ≈ 5-7 min (lot A2) |
| Insignes au nombre de monstres (monstres / 20 ≈ 40 % d'une victoire) | pousse à rester farmer | monstres / 40 ; 35 par carte atteinte (au lieu de 25) ; **+15 par boss de carte** ; total à l'heure ± 10 % (lot A5) |
| Quêtes du jour payées en insignes et cristaux (≈ 300 insignes par jour) | obligation implicite pour qui optimise | **plus d'insignes ni de cristaux** : maîtrise de la classe en retard, coffres d'apparence ; série inchangée (lot A5) |
| Rage en carte 1, monstres ordinaires | déjà plafonnés (E6) | inchangé |
| Tour : étages « monstres » | élite obligatoire à chaque étage (M3) | inchangé (Tour optionnelle) |

### 2.6 Pourquoi chaque activité vaut le coup (une raison chacune)

| Activité | Sa raison unique |
|---|---|
| **Aventure** | **découvrir** les pièces de chaque palier et gagner les **insignes** qui les fabriquent ; seule à ouvrir époques et zones |
| **Donjons** | **pièces à panoplie de donjon**, directes ou par **plan de boss** ; le boss choisi = les emplacements voulus |
| **La Tour** | **cristaux et gemmes** sans verrou de PE, une seule vie, duellistes (porte du JcJ) |
| **Ruée des boss** | **parchemins de fortification hauts et pierres** (monter à +10), titres |
| **Le Siège** | **formules d'enchantement 8-9**, apparences légendaires |
| **Duel, Ligue, Panthéon** | rangs, titres, **panoplie des Esprits** (effets de geste, toutes classes) |
| **Arènes, Gantelet, Battle royale** | titres, maîtrise, un peu d'insignes plafonnés au jour |
| **Quêtes, Défi du jour, contrats** | **maîtrise des classes en retard**, apparences ; jamais obligatoires |
| **Survivant** | apparences et titres, sans lien avec le compte |

### 2.7 Soixante classes sans tout refaire soixante fois

- Coffre commun et préréglages partagés (`Profile.vault`, `presets`) : une pièce montée sert à toutes les classes qui la portent.
  **7 profils de stats** (`data/class_profiles.json` : Puissance 4 classes, Vivacité 9, Précision 9, Rempart 10, Croisé 4,
  Arcane 15, Esprit 9) et **17 types d'arme** couvrent les 60 classes : 7 armures + 17 armes, pas 60 kits.
- **Un plan d'aventure sert tout un palier** : la 1re pièce d'un palier au prix plein, les autres variantes (autre panoplie,
  attributs, type d'armure) à **15 %** (E5) ; une arme choisie découvre les 17 types (E4). Le plan de donjon fabrique l'arme du type
  de la classe choisie. « Équiper le meilleur » et le Registre (E3, `ClassGear`) choisissent par profil et disent où trouver ce qui manque.
- Cristaux, fournitures et plans sont communs ; seule la maîtrise reste par classe (rattrapage, part de l'arbre, leçons : E5).

---

## 3. Chiffres

### 3.1 Mesures (`progression_sim`, médianes ; « — » : moins de la moitié des comptes en 50 h)

Colonnes : **A** jeu actuel ; **E** actuel, pièces choisies d'après leur niveau ; **B** refonte (Donjons dès l'époque I, plans de
donjon fabriqués en insignes, donjon 7 min) ; **D** = B + pièces choisies d'après leur niveau ; **H** = D + **décote de palier** +
`MONSTER_MULT` 0,85 / 1,3 / 2,3 / 4,4 (la proposition). G (même chose avec 0,85 / 1,4 / 2,6 / 5) encadre H.

| Jalon | A | E | B | D | G | **H** |
|---|---|---|---|---|---|---|
| époque I gagnée | 2,8 h | 2,8 | 2,9 | 2,8 | 3,0 | **3,0** |
| époque II | 8,2 | 8,6 | 8,0 | 9,3 | 9,4 | **8,3** |
| époque III | 16,8 | 21,7 | 14,0 | 22,7 | 18,9 | **15,9** |
| époque IV | 30,8 | 39,1 | 28,7 | 39,4 | 28,9 | **29,9** |
| 1er donjon (Normal) | 8,2 | 8,8 | 2,9 | 3,1 | 3,1 | **3,1** |
| 1er Héroïque ouvert | 13,5 | 16,4 | 12,8 | 17,6 | 16,8 | **14,7** |
| Mythique ouvert (PE) | 29,2 | 37,7 | 27,6 | 33,6 | 30,6 | **26,7** |
| kit +10 complet (gemmes ≥ 3, ench. ≥ 5) | 33,0 | 42,0 | 26,0 | 35,3 | 32,7 | **29,7** |
| **équipement 80-90 correct** (9 pièces ≥ 78, légendaires, +5) | — | 42,0 | — | 37,5 | 32,4 | **29,3** |
| pièces 90 partout (≥ 86) | — | — | — | — | — | — (Mythique : longue traîne) |

Lecture : la refonte avance le milieu de partie (donjons 5 h plus tôt) sans toucher le début (époque I à 3 h) ; la décote rend
le niveau des pièces utile en Aventure et ramène l'équipement 80-90 correct à **≈ 29 h** (cible 30 h) ; l'époque IV reste vers
30 h (E6). Sans décote, viser le niveau coûte 8-10 h (E, D). 25 % des comptes simulés n'ont pas leur équipement correct à 50 h
(comptes malchanceux en époque III) : à surveiller au journal réel. Le simulateur ne modélise ni le coffre de plans des boss (il
découvre 6 pièces par carte jouée) ni les quêtes : les deux ne changent que la marge.

### 3.2 Barème cible

| Élément | Valeur | Statut |
|---|---|---|
| Aventure gagnée | 35 min (3 cartes + boss) | E (E5), à confirmer au journal |
| Insignes / h (Aventure gagnée) | 360 (I) → 670 (IV) ; ≈ +30 % avec les vrais monstres | M (E5, E6), inchangé |
| Insignes gagnés à 30 h | ≈ 6 000-7 000 | M (courbes du compte 1) |
| Fabrication d'un kit par époque (I-3, II-3, III-3, IV) | 648 + 1 800 + 2 140 + 2 250 ≈ **6 850** | M (prix E5 inchangés) |
| Coffre de plans (boss de carte) | 1 pièce non découverte du palier, au choix parmi 3 ; tout découvert : 30 insignes | décision |
| Plan de donjon | 1re victoire contre le boss (48) ; jamais de doublon | décision |
| Fabrication d'un plan de donjon | `Economy.base_price` du modèle (mythique 30 + niveau, légendaire 80 + 2 × niveau) ; légendaire après un Mythique fini contre ce boss | décision (mesuré en B / D / H) |
| Pièce directe | 1 coffre de set par donjon fini (3 au choix), + 1 coffre d'équipement en Mythique | inchangé (M2) |
| Cristaux | barème E1 / E6 inchangé (Mythique ≈ 1 000 / h ; +10 d'une pièce 85 ≈ 750-1 300) | M |
| `MONSTER_MULT` (avec décote) | 0,85 / 1,3 / 2,3 / 4,4 | M (simulation) ; à confirmer par `sim_survie.py` et le journal |
| Équipement 80-90 correct d'une classe | **≈ 29-30 h** | M (H) |

Ce que change la refonte par rapport à E6 : E6 visait « équipement complet ≈ 30 h » et l'obtenait avec des pièces 65-80 (le
niveau ne comptait pas) ; la refonte garde les 30 h mais **avec des pièces de l'époque IV** (80-90) et des donjons dès 3 h. Les
insignes deviennent une vraie contrainte de la fabrication (aujourd'hui le compte simulé n'en dépense que 56 %) sans bloquer : un
kit d'époque se paie en 3-4 h d'Aventure. Si le rythme dérive, le levier est le prix (`Economy.base_price`), pas les sources.

### 3.3 Longue traîne (E, d'après E5 / E6)

| Objectif | Durée estimée |
|---|---|
| 1re classe **optimisée** (pièces 90 du Mythique, +10, gemmes royales, enchantements 8-9, panoplie de donjon 6 / 6) | +15 à +25 h (≈ 45-55 h au total) |
| un **profil de stats** de plus (variantes à 15 %, +10, gemmes) | ≈ 13 h chacun × 6 = **≈ 80 h** |
| les **16 autres armes** (+10) | ≈ 1,5 h chacune ≈ **25 h** |
| **maîtrise 20 des 60 classes** | ≈ 128 h (E5 ; en grande partie en même temps) |
| collection de l'Atelier (1 810 pièces), 48 plans de donjon, apparences, titres, rangs héroïques 10 | 150 h et plus |
| **Tout optimisé, 60 classes** | **≈ 250-350 h**, sans mur |

---

## 4. Migration (aucune perte)

| Donnée | Devient | Comment |
|---|---|---|
| `Profile.seen_gear` | plans d'aventure (même liste) | rien à convertir |
| pièces, coffre commun, préréglages, +N, gemmes, enchantements | inchangés | — |
| `Profile.plans` « `plan_<zone>` » (8) | plan du **boss d'origine de la zone** (`BossLibrary.zone_boss`), niveau = meilleure difficulté finie de la zone | conversion paresseuse et idempotente `Dungeons.migrate_plans()` (appelée par la page et par `reward`) ; `profile.gd` intact |
| records `dungeon_<zone>_<diff>`, `dgb_<boss>_<diff>` | gardés (niveau du plan converti) | — |
| insignes, cristaux, fournitures, coffres | inchangés ; la fabrication des plans de donjon passe des cristaux aux insignes, les cristaux gardés servent la Forge | — |
| Donjons fermés (époque II non gagnée) | s'ouvrent si l'époque I est gagnée et la zone battue | `Unlocks.test("dungeons")` ; jamais de reverrouillage |
| quêtes du jour déjà tirées (insignes / cristaux) | payées comme tirées ; le tirage suivant suit le nouveau barème | récompense figée dans `records.quests` |
| équipement d'un compte avancé (époques I-III encore portées) | plus faible en Aventure IV (décote) : c'est voulu ; la PE et les autres modes ne changent pas | message unique au lobby : « Tes pièces sous le palier de l'époque comptent moins en Aventure » |
| textes « Survie » | aucun texte stocké dans la sauvegarde | — |

---

## 5. Lots d'implémentation

Fichiers que N2 modifie en ce moment : `run.gd`, `run_director.gd`, `slot_chests.gd`, `epochs.gd`, `items.gd`, `profile.gd`,
`world.gd`, `tutorial.gd`, `hud.gd`, `guide.gd`, `info_page.gd`, `inventory_page.gd`, `item_widgets.gd` (BR1 : `royale*` ; S9 :
`survivor*`). **A1, A3, A5, A7 peuvent partir tout de suite et en parallèle** (fichiers disjoints entre eux et de N2) ; A2 suit A1
(même fichier) ; A4 et A6 attendent N2 ; **A9 (renommage) en dernier**, quand plus personne n'édite l'interface. Tant qu'A9 n'est
pas passé, les nouveaux textes disent encore « Survie ». Chaque lot : version +1, CHANGELOG, 2-3 lignes dans CLAUDE.md.

| Lot | Contenu | Fichiers | Après | Tests | Acceptation |
|---|---|---|---|---|---|
| **A1** Plans de donjon par boss | `reward` : `plan_<boss>` garanti à la 1re victoire contre ce boss ; `migrate_plans()` ; fabrication **en insignes** (`Economy.base_price` du modèle), 2 emplacements du boss, sa panoplie, niveau = meilleure difficulté finie contre lui ; textes « Il tombe en battant <boss> » | `core/dungeons.gd`, `ui/fabrication_page.gd`, `core/resource_help.gd` | — | nouveau `test_a1` (plan au 1er clear, sans doublon, migration `plan_limestone`, prix en insignes, 0 cristal) ; `test_m2`, `test_e2` | compteur « x / 48 » ; vieille sauvegarde sans perte |
| **A2** Donjons plus tôt, sans remplissage | `Unlocks` « dungeons » = époque I gagnée (texte) ; salles : élites, lieutenant, boss ; durée au pilote (`tools/dungeon_run`) 5-7 min | `core/unlocks.gd`, `core/dungeons.gd`, `core/tower_director.gd` | A1 | `test_m2`, `test_p4_activities -- dungeon`, `test_nav_screens` | Limestone jouable à l'époque I gagnée ; plus de salle de monstres seuls |
| **A3** « Fabriquer » lisible | onglet Armurerie → « Fabriquer », bouton « Fabriquer · N insignes », statuts « À fabriquer / Fabriquées / Plans à découvrir / Tous », ligne « Plan trouvé : <époque, carte> » ; onglet Fabrication → « Plans de donjon » ; Carnet « plans découverts » | `ui/gear_shop_page.gd`, `ui/carnet_pages.gd`, `core/completion.gd` | — | `test_pages`, `test_nav_screens`, `shot_p1` (1280×720) | mêmes prix et filtres ; plus le mot « acheter » pour une pièce |
| **A4** Coffre de plans des boss de carte | à la mort du boss d'une carte : choix de 3 pièces **non découvertes** du palier (`SlotChests.pool`, tous emplacements) → `seen_items` ; tout découvert : 30 insignes | `core/run.gd`, `core/run_director.gd` | N2 | `test_a4` (3 choix non découverts, gardé en défaite à la carte suivante, aucun doublon) | une carte gagnée = au moins un plan |
| **A5** Économie sans bash | `survival_insignia_parts` : monstres / 40, 35 par carte, +15 par boss de carte ; quêtes sans insignes ni cristaux | `core/economy.gd`, `core/quests.gd`, `core/quest_pool.gd`, `ui/results_screen.gd` (lignes du bilan) | — | `test_e5`, `test_results`, `test_quests`, `test_e6` | insignes / h d'une victoire ± 10 % ; défaite express pas plus payée |
| **A6** Décote de palier | `Items.power_level` en Aventure × clamp(niveau / palier, 0,5, 1) ; `Epochs.palier(epoch, stage, slot)` ; `MONSTER_MULT` 0,85 / 1,3 / 2,3 / 4,4 ; message de migration ; puis `sim_survie.py --hub` aux paliers (survie à 7 min ≈ celle d'E6) | `core/items.gd`, `core/epochs.gd`, `ui/lobby.gd` (message) | N2, A7 | `test_e6` (bornes : I 2-4 h, IV 26-34 h, équipement correct ≤ 33 h), `test_gear_run`, `test_p11` | équipement 80-90 correct ≈ 30 h (médiane), époque I inchangée |
| **A7** Outils de mesure | dans `progression_sim` : Donjons dès l'époque I, plans de donjon fabriqués, choix des pièces sur leur PE, jalons `kit80_ok` / `kit90_ok` / `kit90_opti` / `dungeon_0`, décote (drapeau) | `tools/progression_sim.gd`, `tests/test_e6.gd` | — | `test_e6` | les colonnes du §3.1 se reproduisent |
| **A8** Boussole et Registre | « plan à découvrir → Aventure, carte X », « Fabriquer · N insignes », « Donjon de <boss> : panoplie », « pièce sous le palier » | `core/compass.gd`, `core/class_gear.gd` | A1, A3 | `test_compass`, `test_e3` | chaque manque nomme son activité |
| **A9** Renommage | §1 | §1.1 | tous | suite complète, `test_texts_fr` | aucun « Survie » lisible ; sauvegardes et tests intacts |

Ordre : **A1 ∥ A3 ∥ A5 ∥ A7** → A2, A8 → (N2 fini) A4, A6 → **A9**.

---

## 6. Questions ouvertes (tranchées par défaut ; le joueur peut revenir dessus)

| # | Question | Recommandation appliquée |
|---|---|---|
| Q1 | Donjons dès l'époque I gagnée, alors que la réponse 1 du 14/10 disait « Donjons à l'époque II » ? | **Oui** : la demande du 16/10 lie les donjons au déblocage des zones ; à l'époque II, les donjons de l'époque I étaient déjà dépassés en s'ouvrant. |
| Q2 | Décote de palier en Aventure ? | **Oui, douce** (plancher ×0,5) : sans elle, « équipement 90 » n'a aucun effet en Aventure et le viser coûte 8-10 h. Refusé : relever le plafond de niveau du héros jusqu'à 90 (tout E6 / P11 à refaire). |
| Q3 | Fabriquer : insignes seuls, ou insignes + matières ? | **Insignes seuls** : un verbe, une monnaie ; les matières ont déjà leur puits (Forge) ; pas de pont insignes ↔ cristaux (E6). |
| Q4 | Plan de donjon par zone (8) ou par boss (48) ? | **Par boss** : chaque donjon à la carte a une raison d'être fini, et la panoplie suit le thème de butin du boss (M2). |
| Q5 | Coffre de plans du boss de carte : au choix ou au hasard ? | **Au choix parmi 3**, comme les coffres d'emplacement : le joueur vise son manque. |
| Q6 | Quêtes sans insignes ni cristaux ? | **Oui** (« pas de quêtes obligatoires ») : maîtrise des classes en retard et apparences seulement. |
| Q7 | La rangée du menu Jouer s'appelle déjà « Aventure » | **« Progression »** (Aventure, Donjons, La Tour) ; le Survivant passe en « Défis ». |
| Q8 | Transférer le +N d'une pièce à sa remplaçante (moins de « remonter de zéro ») ? | **Non pour l'instant** : c'est la longue traîne voulue ; à reconsidérer si le journal réel montre l'équipement correct au-delà de 35 h. |

---

## Annexe — reproduire les mesures

Copie de HEAD : `tools/run_tests.py` (`preparer_copie`) vers un dossier de travail. Dans la copie, `tools/progression_sim.gd` :
`--refonte` (Donjons dès l'époque I sur les zones des époques gagnées, 7 min par donjon, plan de donjon au 1er clear d'une
difficulté sinon 10 % — approximation du plan par boss —, pièces des plans fabriquées au prix `Economy.base_price`, panoplie de la
zone), `--hubvalue` (pièces choisies sur leur PE, le niveau compte), `--decote` (dans `core/items.gd` de la copie : `power_level`
× clamp(niveau / palier de la carte, 0,5, 1) pendant le calcul du rapport de puissance), `--mult=` (existant), jalons `kit80_ok`
(9 pièces ≥ 78, légendaires, +5), `kit90_ok` (≥ 86), `kit90_opti`, `dungeon_0`. Commande : `godot --headless --path <copie>
res://tools/progression_sim.tscn -- --accounts=12 --hours=50 --seed=1 --quiet --refonte --hubvalue --decote --mult=0.85,1.3,2.3,4.4`
(≈ 10 min). Le lot A7 intègre ces drapeaux à l'outil du dépôt.
