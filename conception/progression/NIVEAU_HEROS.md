# Niveau de héros — la quête du niveau 90 (PR2, conception, 16/10/2026, jeu 0.1.222)

Session PR2 : conception seule, aucun fichier de jeu modifié. Mesures sur une **copie** de HEAD 0.1.222 (dossier de travail de
la session) : `progression_sim` (lot A7) prolongé d'un modèle « niveau de héros » (`hl_sim`, annexe) et une sonde de puissance
(`hl_probe`). **M** = mesuré (simulateur d'E6 : ±30 % en absolu, fiable en relatif), **E** = estimé.

Décision du joueur (16/10) : plus de plafond au niveau 35 ; **un niveau de héros permanent (1 → 90, par compte, toutes classes)**
qui dit quelles pièces on peut porter et donne les stats de base ; **un niveau de run temporaire** (1 à chaque partie, sans plafond
par carte) qui ne donne **que des cartes** ; talents et certificats = l'« opti », liés à la classe, **jamais en Survivant ni en
Battle royale**. Modes de progression : Aventure, Donjons, Tour, Ruée, Siège. Modes scellés : Survivant, Battle royale.

---

## 0. En bref

1. **Niveau de héros H** (1-90, compte) : pièce de niveau N portable si H ≥ N ; stats de base du combat = celles du niveau H.
   Il ne redescend jamais. Gagné **seulement en mode de progression**, au kill (XP selon l'écart de niveau) ; **90 à ≈ 29 h** (M).
2. **Niveau de run** (cartes) : repart de 1, sans plafond, 1 monstre = 1 point ; mêmes cartes qu'aujourd'hui, plus aucune stat.
   En Survivant et Battle royale, il reste aussi le niveau de combat (rien du compte n'y entre).
3. **Cartes de l'Aventure = bandes de niveau** (I-1 : 1-23 … IV-3 : 80-90) : monstres au niveau du héros, bornés par la bande.
   `Epochs.CAPS`, `LEVEL_BONUS`, la **décote A6** et `MONSTER_MULT` disparaissent : une pièce compte à **son** niveau, jusqu'à 90.
4. **Activités** (Donjons, Tour, Ruée, Siège) : héros au niveau min(H, niveau de l'activité) ; réglages M2 / M3 / M6 / P11 intacts.
5. **Constat mesuré** : le **Battle royale applique aujourd'hui** talents, certificats, plateau, archive, auras, sorts fermés par la
   maîtrise et cartes débloquées (seul le Survivant les coupe). 7 certificats + plateau = **×2,2 à ×2,8** de puissance (M) : à couper.
6. **Talents et certificats** restent gagnés par la maîtrise **de la classe** (rien ne change pour eux) ; un seul interrupteur
   `Modes.sealed()` les coupe dans les modes scellés ; JcJ : coupés « à l'arme », gardés « équipé ».
7. **Migration** sans perte : H de départ d'après les époques gagnées **et** les pièces portées (aucune pièce déséquipée).
8. **Lots H1-H7** (H1, H5, H7 tout de suite ; H2-H4 après N2) ; A6 remplacé par H4 ; A8 fondu dans H6 ; A2, A4, A9 inchangés.

---

## 1. Le modèle

### 1.1 Deux niveaux

| | **Niveau de héros (H)** | **Niveau de run** |
|---|---|---|
| Portée | compte (partagé par les 60 classes) | une partie |
| Départ / plafond | 1 → **90**, ne redescend jamais | 1 à chaque partie, **sans plafond par carte** |
| Gagné | au kill, en Aventure, Donjons, Tour, Ruée, Siège (§1.3) | orbes de la partie : 1 monstre = 1 point (élite 4, boss 8), besoin = celui d'aujourd'hui en monstres (`KILLS_PER_LEVEL` + 2,5 × niveau), ×2 → ×1 du niveau 1 au 10 (`Epochs.xp_boost`) |
| Donne | **pièces portables** (niveau ≤ H) ; **stats de base** du combat (PV, attaque, défense, attributs : formules actuelles au niveau H) | **cartes seulement** (sorts, améliorations, passifs, arme) |
| Ne donne pas | points de talent, certificats (restent à la maîtrise de la classe) | aucune stat, aucun accès |
| Affiché | lobby (bandeau « Niv. 34 » + barre), page Héros, bilan (« Niveau de héros 34 → 35 ») | HUD (jauge des cartes « Run 12 »), bilan |
| Survivant, Battle royale | **ignoré** | niveau de combat **et** cartes (comme aujourd'hui) |

### 1.2 Qui utilise quoi (règle unique par mode)

| Mode | Niveau de combat | Équipement du hub | Talents | Certificats + plateau | Archive, auras | Sorts fermés par la maîtrise | XP de héros |
|---|---|---|---|---|---|---|---|
| **Aventure** | H | oui | oui | oui | oui | oui | **oui** |
| **Donjons, Ruée, Siège** | min(H, niveau de l'activité) | oui | oui | oui | oui | oui | oui |
| **La Tour** | min(H, niveau de l'étage) | oui | oui | oui | oui | oui | oui |
| **Survivant** | niveau de run | non | non | non | non | non (kit entier) | non |
| **Battle royale** | niveau de run | non | **non (oui aujourd'hui)** | **non (oui aujourd'hui)** | **non (oui aujourd'hui)** | **non (oui aujourd'hui)** | non |
| **Duel à l'arme, Ligue, Panthéon** | niveau choisi / fixé (10) | non | non | non | non | inchangé | non |
| **Duel équipé, Arènes, Gantelet** | **H** (au lieu du niveau de la plus haute pièce) | oui | oui | oui | oui | oui | non |

**JcJ, justification** : l'« à l'arme » est le duel d'adresse (déjà vidé de la méta : `Duel.start` efface talents, certificats et
plateau) et porte la Ligue et le Panthéon : on n'y touche pas. L'« équipé » est la **vitrine de l'opti** (le joueur montre son héros) :
talents et certificats y restent, l'adversaire scripté a les siens (build opti de sa classe) et `PvpCaps.soften` ramène déjà de
moitié les bonus en %. Aucune XP de héros en JcJ (règles normalisées, pas de ferme), ses récompenses ne changent pas.

### 1.3 XP de héros

| Élément | Règle |
|---|---|
| Unité | « monstre de son niveau » : un monstre ordinaire tué au niveau H vaut 1 (élite 4, boss 8, comme `xp_reward`) |
| Écart de niveau | × clamp(1,1^(niveau du monstre − H), **0,1**, **3**) : contenu 10 niveaux au-dessus ×2,6, 10 en dessous ×0,39 ; rien à gagner à écraser l'époque I |
| Victoire | +20 % de l'XP de la partie (Aventure gagnée, donjon / Ruée / Siège fini) |
| Besoin du niveau L → L+1 | **105 × 1,035^L** unités : niv. 10 : 148 (2,7 min au rythme de l'Aventure, 55 monstres / min) ; 30 : 295 (5 min) ; 43 : 462 (8 min) ; 60 : 829 (15 min) ; 80 : 1 650 (30 min) ; 89 : 2 240 (41 min) |
| Sources | Aventure (≈ 70 % de l'XP, E), Donjons, Tour, Ruée, Siège (≈ ×0,6 par minute, E : moins de monstres, boss plus payants) |
| Jamais | Survivant, Battle royale, JcJ, quêtes, Défi du jour, contrats (pas de « bash » ni d'obligation) |
| Plafond d'époque | **aucun** (l'écart de niveau suffit ; mesuré avec un plafond 43 / 60 / 75 / 90 : époques à ±1,5 h, niveau 90 3 h plus tard, et un mur d'XP en plus) |

Courbe (M, médiane, 12 comptes « moyen », 50 h) : niv. 10 à **0,5 h** · 20 à 0,9 h · 30 à 1,6 h · 43 à **3,6 h** · 50 à 5,2 h ·
60 à **8,5 h** · 70 à 13,1 h · 75 à 16,1 h · 80 à **19,9 h** · 85 à 24,0 h · **90 à 29,3 h** (débutant 30,6 h, bon 28,4 h).

### 1.4 Puissance d'une pièce et des monstres (modes de progression)

- **Pièce** : `Items.power_level` = son niveau (`power_cap`), puisqu'on ne porte que des pièces ≤ H ; stats = base × 1,08^(niveau − 1) ×
  rareté × qualité × (1 + 0,1 × +N) + gemmes (en Aventure, `Craft.gem_run_factor` lit H) + enchantement + panoplies. **Pièces de
  départ** (`StarterGear`, palier 10-30) : portables à tout niveau, puissance min(H, leur niveau). Trophées : inchangés.
- **Retard d'équipement** (remplace la décote A6, M) : même kit, héros et monstres 10 niveaux plus haut → **×0,73 à ×0,79** de
  puissance relative (15 niveaux : ×0,65-0,74). Une pièce sous le niveau du héros pèse moins, naturellement, jusqu'au niveau 90.
- **Héros au-dessus de la bande** (pas de synchronisation en Aventure, M) : +5 niveaux ×1,35, +10 ×1,9, +20 ×4.
- **Aventure** : chaque carte a une **bande** [bas, haut] ; monstres au niveau clamp(H − 1 → H − 0,5, bas, haut) (+3 en rage, boss +1) ;
  PV et dégâts × **M′ de la carte** (table, remplace `MONSTER_MULT`) × montée dans le temps (nouvelle, ≈ +6 % / min, **E**, à régler
  au pilote : le héros ne prend plus de niveaux pendant la carte, seules les cartes le font grandir) × `MonsterScaling` (bandes
  `EPOCH_BAND` à recalculer avec des pièces à leur niveau) × Menace, pacte, rage (inchangés).

| Carte | I-1 | I-2 | I-3 | II-1 | II-2 | II-3 | III-1 | III-2 | III-3 | IV-1 | IV-2 | IV-3 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Bande (bas-haut) | 1-23 | 18-33 | 28-43 | 38-48 | 43-53 | 48-60 | 55-65 | 60-70 | 65-75 | 70-80 | 75-85 | 80-90 |
| M′ (M, à confirmer au pilote) | 0,68 | 0,80 | 0,83 | 2,9 | 2,9 | 4,0 | 17 | 17,5 | 12 | 195 | 286 | 99 |

M′ paraît grand : il s'applique à des monstres de niveau 48-90 (×1,1 par niveau) au lieu de 15-35, face à des pièces qui comptent
enfin à leur niveau (un kit IV-3 +5 vaut ×132 un kit d'époque I au niveau 90, M). Ses creux (III-3, IV-3) suivent les pièces
éveillées de la 3e carte. **PV des boss** (`Epochs.BOSS_HP_EPOCH`) : à refaire par `tools/boss_ttk.py` au haut de chaque bande (E :
×1,1^(haut − 15/25/35) × M′ / ancien multiplicateur, soit ≈ ×2 700 en IV-3) ; même cible P11 (1 / 1,5 / 2 min sur une bonne run).

| Ce qui existe | Devient |
|---|---|
| `Epochs.CAPS` 15 / 25 / 35, `LEVEL_BONUS` | **supprimés** en Aventure ; `Epochs.band(époque, carte)` ; `Royale` garde ses `LEVEL_CAPS` |
| `Run.hero_level` | reste « niveau de combat de la partie » : = H en progression (min(H, niveau) en activité), = niveau de run en mode scellé |
| (nouveau) | `Run.card_level`, `card_xp` : niveau de run de l'Aventure ; `Player.gain_xp` nourrit les deux barres |
| `Items.power_level` / `power_cap` | inchangés dans leur forme ; en Aventure la pièce vaut son niveau ; `Items.required_level(item)` (0 pour les pièces de départ) |
| Décote de palier (lot A6) | **supprimée** (jamais codée) : le niveau de la pièce compte de lui-même |
| `Epochs.MONSTER_MULT` | remplacé par `Epochs.MAP_MULT` (12 valeurs) |
| `Profile.best_level` | gardé comme record du meilleur niveau de run ; `GearPower.target_level`, niveau des coffres (`Economy.chest_add`), succès `lvl_25` / `lvl_50` (inatteignable aujourd'hui) lisent **H** ; nouveau succès « Niveau 90 » |
| Or et prix en run (`40 + 12 × niveau`, coffres payants) | suivent le **niveau de run** (économie de la partie inchangée) |
| Verrous de PE (`DIFF_RATIO`, Siège, butin légendaire) | inchangés ; `GearPower.expected` au niveau de l'activité, comme aujourd'hui |

---

## 2. Talents et certificats

### 2.1 État exact (code de 0.1.222)

| Élément | Gagné | Dépensé / posé | Portée |
|---|---|---|---|
| Maîtrise (`Profile.expertise`, 40 niv.) | fin d'activité avec la classe (Aventure, JcJ, Battle royale, quêtes), part de l'arbre (`Economy.share_tree`) | — | **par classe** |
| Talents (`Profile.talents[classe]`) | **2 points par niveau de maîtrise** de la classe (80 au plus) | Héros > Classe > Talents (arbre de 18, paliers 15-35, remise gratuite) | **par classe** |
| Certificats | les 2 passifs de chaque classe, à sa maîtrise 3 et 8 | **un plateau commun** (`cert_board`, 2 cases + 1 par 8 niveaux de maîtrise cumulés, 7 au plus) ; aussi des **cartes de certificat** en run | compte |
| Sorts | 4 d'emblée, les suivants à la maîtrise 2-16 (`Progression.skill_unlocked`, filtre du tirage des cartes) | — | par classe |

Effets appliqués en combat : `Run.passive_stats` (stats des talents, certificats, plateau), `Run.skill_talent` (dégâts, recharge, durée
des sorts), `Player.knock_immune` (certificat « insensible »), `Player.recalc_stats` (archive, auras), `Run.roll_cards` (sorts
fermés, `Cards.card_unlocked`, `certificate_pool`). **Coupés aujourd'hui** : Survivant (tests `Survivor.active` à ces endroits) et
Duel à l'arme (`Duel.start` vide talents, certificats, plateau ; `_bare`). **`Survivor.HUB_KEYS` ne coupe rien** : c'est une photo
du compte remise en fin de run (il protège la sauvegarde, pas le combat). **Battle royale : tout s'applique au joueur**, rien aux
sept héros scriptés.

### 2.2 Effet mesuré (sonde `hl_probe`, indice √(PV effectifs × DPS), kit 2.3.5.3, niveaux 60 / 20 ; M)

| Classe | 80 points de talent (stats seulement) | 2 certificats (niv. 60) | 4 certificats (niv. 60) | 7 certificats + plateau (build opti) |
|---|---|---|---|---|
| Guerrier | ×1,14 / ×1,18 | ×1,37 | ×1,83 | **×2,47 / ×2,63** |
| Magicien, Chasseur, Voleur | ×1,16-1,18 / ×1,22-1,24 | ×1,39-1,40 | ×1,71-1,73 | ×2,49-2,59 / ×2,68-2,72 |
| Clerc, Sage | ×1,05-1,10 / ×1,10-1,16 | ×1,47-1,53 | ×1,85-1,93 | ×2,21-2,35 / ×2,38-2,56 |
| Chevalier, Rôdeur | ×1,16-1,17 / ×1,25-1,26 | ×1,39-1,60 | ×1,72-1,98 | ×2,49-2,54 / ×2,75-2,80 |

Les talents de sort (dégâts, recharge) ne sont pas dans l'indice : leur effet réel est plus grand. Les certificats pèsent plus que
le +10 de tout l'équipement (×1,5-1,9) : le simulateur de progression les ignore (§5).

### 2.3 Règle et crochets

- **Lien à la classe** (demande du joueur) : déjà vrai pour les talents et l'ouverture des certificats (maîtrise de la classe) ; le
  niveau de héros n'en donne pas (60 classes = la longue traîne de l'opti). Le plateau commun reste commun (Q4).
- **Un interrupteur** : `Modes.sealed()` = `current() in ["survivor", "royale"]` ; il remplace `Survivor.active` dans
  `Run.passive_stats` et `Run.skill_talent` (run.gd 589 / 615), `Player.knock_immune` (2114) et la variable `sv` d'archive / auras
  (player.gd 302 ; `Survivor.cap_hero` reste au seul Survivant) ; dans `Run.roll_cards` : sorts sans filtre de maîtrise (658 / 665),
  `Cards.card_unlocked` ignoré (685), `certificate_pool()` vide.
- **Battle royale** : gains (maîtrise, insignes plafonnés au jour) inchangés ; aucun effet du compte en combat (Q6).
- Test `test_h2` : compte avec 80 points de talent, 7 certificats, archive et auras ; en Battle royale et en Survivant, mêmes stats
  qu'un compte neuf, kit entier proposé ; en Aventure, les bonus sont là.

---

## 3. Migration des comptes existants (paresseuse, une fois, idempotente)

| Donnée | Règle |
|---|---|
| **H de départ** | max( barème des époques gagnées : 0 → `best_level` (≤ 35) ; I → **43** ; II → **60** ; III → **75** ; IV → **85**, +1 par rang héroïque fini, **90** si un donjon Mythique est fini ; **niveau de la plus haute pièce portée** dans les préréglages actifs de toutes les classes ) ; XP du niveau = 0 |
| Pièces portées | **jamais déséquipées** : H ≥ chaque pièce portée par construction |
| Pièces du coffre au-dessus de H | gardées, « Niveau N requis » en rouge ; « Équiper le meilleur » les saute |
| Talents, certificats, plateau, maîtrise | inchangés |
| Stockage | `Profile.records["hero_xp"]` (XP totale ; niveau calculé) : déjà sauvegardé, déjà dans `HUB_KEYS` (photo du Survivant), aucun champ nouveau dans `profile.gd` |
| Message | une fois au lobby : « Ton héros est niveau N. Il garde ce niveau dans toutes les classes. » |

---

## 4. Impacts et plan de lots

### 4.1 Ce qui bouge ailleurs

| Où | Changement |
|---|---|
| Lobby (`ui/lobby.gd`) | bandeau « Niv. 34 » + barre d'XP ; page Aventure : bande de chaque carte (« Niv. 18-33 ») ; Duel équipé : « niveau 34 » |
| Page Héros (`hero_screen`, `equipment_page`, `item_widgets`) | niveau en tête ; pièce non portable grisée « Niveau N requis » ; Certificats : « pas en Survivant ni en Battle royale » |
| Boussole (`core/compass.gd`) | « Monte au niveau N pour porter … (Aventure) », « Carte au-dessus de ton niveau » ; fond A8 |
| Registre (`core/class_gear.gd`) | PE attendue au niveau H ; manque « niveau » → « Monte ton niveau de héros » |
| Atelier > Fabriquer (`ui/gear_shop_page.gd`) | fabriquer reste possible au-dessus de H (Q5) ; filtre « Portables » ; ligne « Niveau N requis » |
| Bilan (`results_screen`, `results_panel`) | Gagné : « Niveau de héros 34 → 35 » (barre) ; Survivant et Battle royale : rien |
| HUD (`ui/hud.gd`) | niveau de héros sur le cadre ; jauge des cartes « Run N » (le niveau de run) |
| Tutoriel, Guide (`tutorial.gd`, `guide.gd`, `info_page.gd`) | fiche « Deux niveaux » (≤ 125 signes) ; Guide > Héros : niveau de héros, niveau de run |
| Quêtes | `sv_level` lit le niveau de run (inchangé) ; aucune quête sur le niveau de héros |
| Succès (`core/achievements.gd`) | `lvl_25`, `lvl_50` sur H (ids gardés), « Niveau 90 » en plus |
| Tests touchés | `test_p9`, `test_royale` (CAPS), `test_e6` (MULT), `test_gear_run`, `test_p15`, `test_p11`, `test_build`, `test_tooltips` (« suit ton niveau, plafond »), `test_e3`, `test_pvp`, `test_p4_migration`, `test_nav_screens`, `shot_p1` |

### 4.2 Révision du plan de REFONTE_AVENTURE.md §5

Restent : **A2** (Donjons plus tôt, sans remplissage), **A4** (coffre de plans des boss, après N2), **A9** (renommage, en dernier) :
inchangés. **A6 remplacé par H4** (décote supprimée). **A8 fondu dans H6** (mêmes fichiers). Faits : A1, A3, A5, A7.

| Lot | Contenu | Fichiers | Après | Tests | Acceptation |
|---|---|---|---|---|---|
| **H7** Outils | `progression_sim --heros` (modèle de l'annexe : H, XP, pièces portables, bandes, `MAP_MULT`, certificats comptés) ; `sim_survie.py --hero-level=` ; `boss_ttk` aux hauts de bande | `tools/progression_sim.gd`, `tools/sim_survie.py`, `tools/boss_ttk.*`, `tests/test_e6.gd` | — | `test_e6` | §5 se reproduit |
| **H1** Niveau de héros | `core/hero_level.gd` (besoin, écart, XP, niveau depuis `records.hero_xp`, migration §3) ; XP comptée à la mort d'un monstre en mode de progression, versée au bilan ; bandeau du lobby, ligne du bilan, message de migration | `core/hero_level.gd` (nouveau), `ui/lobby.gd`, `ui/results_screen.gd` | — | `test_h1` (courbe, écart ×0,1-×3, pas d'XP en Survivant / BR / JcJ, migration idempotente, aucune pièce portée > H) | vieille sauvegarde : H attendu, rien de perdu |
| **H5** Activités | héros à min(H, niveau) : Tour, Donjons, Ruée, Siège ; Duel équipé / Arènes au niveau H (`Duel.gear_level`) ; « niveau conseillé » sur les pages | `core/tower_director.gd`, `core/siege_director.gd`, `core/duel.gd`, `ui/dungeon_page.gd`, `ui/tower_pages.gd` | H1 | `test_m2`, `test_m3`, `test_m6`, `test_pvp`, `test_p4_activities` | H ≥ niveau : mêmes chiffres qu'avant |
| **H2** Modes scellés | `Modes.sealed()` et les 7 crochets du §2.3 | `core/modes.gd`, `core/run.gd`, `player/player.gd` | N2 | `test_h2`, `test_royale`, `test_sv1`-`sv3` | §2.3 ; Survivant inchangé |
| **H3** Porter selon le niveau | `Items.required_level` ; `Profile.equip` refuse > H ; « Équiper le meilleur », « Appliquer à la famille » sautent ; pièces de départ exemptées ; « Niveau N requis » | `core/items.gd`, `core/profile.gd`, `core/class_gear.gd`, `core/starter_gear.gd`, `ui/item_widgets.gd`, `ui/equipment_page.gd`, `ui/gear_shop_page.gd` | N2, H1 | `test_h3`, `test_e3`, `test_workshop`, `test_tooltips` | aucune pièce > H équipable, aucune déséquipée |
| **H4a** Aventure au niveau H | `Player.level` = H en Aventure ; `Run.card_level` + `card_xp` (cartes) ; `Epochs.band`, suppression de `CAPS` / `LEVEL_BONUS` ; `SlotChests` crée les pièces à leur niveau ; gemmes à H ; HUD « Run N » | `core/epochs.gd`, `core/run.gd`, `core/run_director.gd`, `player/player.gd`, `core/slot_chests.gd`, `ui/hud.gd` | N2, A4, H1-H3 | `test_h4`, `test_p9`, `test_build`, `test_gear_run`, `test_n2` | ≈ 35 cartes par run gagnée ; monstres dans leur bande |
| **H4b** Équilibre mesuré | `MAP_MULT`, montée dans le temps, `EPOCH_BAND`, PV des boss (`boss_ttk`) ; pilote : survie à 7 min d'N1 / E6 retrouvée à chaque carte avec le kit de la carte +5 | `core/epochs.gd`, `core/monster_scaling.gd`, `core/run_director.gd` | H4a, H7 | `test_e6` (bornes §5), `test_p11`, `test_p15`, `test_gear_run` | époque I 2-4 h, IV 27-34 h, H 90 26-33 h |
| **H6** Textes et boussole (+ A8) | §4.1 : Héros, Registre, Boussole, Guide, tutoriel, succès | `core/compass.gd`, `core/class_gear.gd`, `ui/guide.gd`, `core/tutorial.gd`, `ui/hero_screen.gd`, `core/achievements.gd` | H3, H4a, A3 | `test_compass`, `test_texts_fr`, `test_nav_screens`, `shot_p1` | chaque manque nomme son activité ; 1280×720 |

Ordre : **H7 ∥ H1 ∥ A2** → H5 → (N2 fini) **A4 → H2 ∥ H3** → **H4a → H4b** → H6 → **A9**. Tant que H4a n'est pas passé, H
existe (lobby, port des pièces, activités) mais l'Aventure garde ses plafonds : aucun état cassé entre deux lots. Chaque lot :
version +1, CHANGELOG, 2-3 lignes dans CLAUDE.md, rapport `R_H<n>.md`.

---

## 5. Chiffres

Modèle `hl_sim` (12 comptes, guerrier, graine 1, drapeaux A7 `--refonte --plans=boss --hubvalue`, pièces choisies sur leur PE et
portables seulement) : R = I(pièces, H) / (I de référence × 1,1^(niveau des monstres − 15/25/35)) / M′ ; XP du §1.3. M′ = M′ de la
sonde (kit de la carte +5 aligné sur la colonne H de REFONTE §3.1) × 0,75 / 0,7 / 0,5 / 0,8 par époque (balayage de 13 variantes).

| Jalon (médianes, h) | Refonte H (décote, plafond 35) | **Niveau de héros** (moyen) | débutant | bon |
|---|---|---|---|---|
| époque I gagnée | 3,0 | **2,8** (H 35) | 3,0 | 2,4 |
| époque II | 8,3 | **10,6** (H 64) | 11,2 | 9,7 |
| époque III | 15,9 | **17,7** (H 76) | 20,6 | 17,4 |
| époque IV | 29,9 | **31,2** (H 90) | 36,3 | 29,5 |
| 1er donjon / 1er Héroïque ouvert / Mythique ouvert | 3,1 / 14,7 / 26,7 | 3,2 / 18,2 / 33,8 | 3,0 / 17,7 / 36,0 | 2,4 / 17,4 / 31,9 |
| **niveau 90** | — | **29,3** | 30,6 | 28,4 |
| équipement 80-90 correct | 29,3 | **37,4** (92 % des comptes) | 40,9 | 35,5 |

Lecture (M) : le niveau 90 tombe à **≈ 29 h** et l'époque IV à ≈ 31 h, l'époque I ne bouge pas ; le niveau suit le contenu (H ≈ haut
de la bande à chaque époque gagnée) et rattrape les joueurs lents (XP au temps, écart ×3). **Écart** : l'équipement 80-90 correct
arrive ≈ 8 h plus tard qu'avec la décote ; ce n'est pas le niveau (80 à 20 h) mais la découverte et la fabrication des légendaires
de l'époque IV. Leviers à mesurer en H4b : coffre de plans des boss (A4, non simulé), prix de l'époque IV (`Economy.base_price`).
M′ de la sonde sans facteur d'époque : époques II / III à 12 / 22 h (milieu trop dur) ; XP 190 × 1,03^L : niveau 90 à 39 h et
époque IV à 41 h (le niveau bride tout) ; la forme de la courbe place le 90 entre 25 h (120 × 1,03^L) et 33 h (90 × 1,04^L). **Estimé (E)** : montée des monstres dans le temps (≈ +6 % / min), PV
des boss, part de l'XP des activités (×0,6), effet des certificats sur l'Aventure (ignorés par le simulateur : ×1,4 à 2 cases).

---

## 6. Questions ouvertes (celles qui changent la sensation ; défaut appliqué)

| # | Question | Recommandation par défaut |
|---|---|---|
| Q1 | Monstres de l'Aventure : suivre le héros dans la bande de la carte, ou niveau fixe par carte ? | **Bande** : un héros neuf joue I-1 au niveau 1 ; au-dessus de la bande, il écrase la carte (récompense du niveau) ; dans la bande, l'équipement fait la différence. |
| Q2 | Ramener le héros au niveau du contenu (synchronisation) ? | **Aventure : non** (revenir écraser l'époque I fait sentir le niveau ; l'XP y tombe à ×0,1). **Activités : oui, vers le bas seulement** (min(H, niveau)) : leurs boss, butins et réglages sont au niveau de l'activité. |
| Q3 | Le niveau de héros donne-t-il des points de talent ? | **Non** : talents et certificats restent à la maîtrise de la classe (lien à la classe, longue traîne des 60 classes). |
| Q4 | Plateau de certificats commun ou par classe ? | **Commun pour l'instant** ; « un plateau par classe » (copie de l'actuel, aucune perte) ajouterait de l'opti par classe : lot à part si le joueur le veut. |
| Q5 | Fabriquer une pièce au-dessus de son niveau ? | **Oui** (préparer la suite), la porter **non** : « Niveau N requis ». |
| Q6 | Battle royale : couper aussi ses gains vers le compte (maîtrise, insignes plafonnés) ? | **Non** : seuls les effets en combat sont coupés ; les gains (maîtrise, insignes au jour, titres, apparences) restent. |
| Q7 | Certificats à ×2,5 (7 + plateau) : trop forts pour l'Aventure ? | À mesurer en H4b avec les certificats dans le simulateur ; si l'époque IV tombe avant 26 h, réduire le plateau (liens) avant M′. |

---

## Annexe — reproduire

Copie de HEAD (`tools/run_tests.py`, `preparer_copie`) ; dans la copie : `tools/hl_probe.gd` (extends `progression_sim.gd` :
indices par kit et par niveau, R actuel / H / niveau de héros par carte, retard dans la bande, effet des talents et certificats avec
`--talents`) et `tools/hl_sim.gd` (extends `progression_sim.gd` : H, XP `--a=105 --g=1.035`, pièces portables, bandes,
`M_MAP` × `--mep=0.75,0.7,0.5,0.8`, options `--epochcap`, `--sync`). Commande : `godot --headless --path <copie>
res://tools/hl_sim.tscn -- --accounts=12 --hours=50 --seed=1 --quiet --refonte --plans=boss --hubvalue --a=105 --g=1.035
--mep=0.75,0.7,0.5,0.8` (≈ 12 min ; APPDATA détourné). Le lot H7 intègre ce modèle à l'outil du dépôt.
