# Équipe Équilibrage — rapport du tour 1 (version 0.1.130)

Périmètre : chiffres du combat et de l'économie (monstres, boss, époques, auto-attaques et leurs
cartes, cartes de build, trophées, or / clés / prix, expérience, duel, Tour). Pilote de l'ajout n°3
du joueur : **équilibrage distinct par mode** (JcJ, Survie, Donjon), traité à fond en partie 3 (E1 à E4).

Méthode : lecture du code (il fait foi) et calculs sur les données (`levels.json`, `monsters.json`,
`eden_catalog.json`, `weapon_attacks.gd:SPECS`) avec les formules du code. **Aucune run n'a été
mesurée** dans cet atelier (budget) : les chiffres « par run » sont des modèles, signalés comme tels,
et la proposition E6 fournit l'outil pour les mesurer sur les vraies parties du joueur.

---

## En bref

**5 constats**
1. **Il n'y a pas « un » équilibrage mais cinq, éparpillés et incohérents.** Survie (`Epochs`,
   `Monster.configure`, `RunDirector`), Tour (`Tower.RULES`, réglable en mode dev), Duel (`PvpCaps`),
   duels de la Tour et entraînement (`Combatant.hero_vs_hero_factor`, **autres règles que le Duel**),
   arène d'IA (sans règles du duel). Chaque mode a ses chiffres codés à un endroit différent.
2. **Les époques ne sont dures que par les monstres** : à jeu égal, l'époque IV est environ
   **2 fois plus longue à tuer et 1,75 fois plus mortelle** que l'époque I (monstres ×2,2, équipement
   du héros +8 % d'attaque, +26 % de PV). Les cartes et trophées compensent pareil à chaque époque.
3. **Le duel est sain sur la durée (53 à 88 s par manche mesurés en 0.1.118)** mais laisse passer les
   stats en % (dégâts, critique, vitesse) à plein jusqu'aux plafonds, alors que l'attaque et les PV ne
   comptent qu'en racine ; les contrôles s'enchaînent sans limite entre types ; les cerveaux d'IA sont
   entraînés **sans** ces règles.
4. **Quelques multiplicateurs cassent l'échelle en Survie** : Projectile supplémentaire (×2 à ×4 pour
   une arme à un coup, ×1 pour une arme à zone visée), Élan meurtrier sans recharge interne, trophées
   « à l'impact » permanents en horde, Lame large qui grandit tout.
5. **L'économie n'est pas mesurée** : l'or est réglé « au ressenti » (0.1.118 : moins d'or, coffres
   +18 % par ouverture), les insignes et les cristaux n'ont pas de cible, et le joueur doit encore
   donner son avis sur l'économie de l'or (CLAUDE.md).

**Propositions phares** : E1 profils de mode (**M**) · E2 contrat chiffré de chaque mode (**S**) ·
E3 JcJ complété : poids de l'équipement, contrôles, Tour et cerveaux sous les mêmes règles (**M**) ·
E4 Donjon synchronisé au niveau (**M**) · E5 courbe des époques (**S**) · E6 journal de run et banc
d'essai (**S puis M**) · E7 garde-fous de Survie (**S**).

---

## 1. État des lieux

### 1.1 Où vivent les chiffres aujourd'hui (par mode)

| Mode | Fichiers / fonctions | Ce qui est réglé |
|---|---|---|
| **Tous** | `game_data.gd` : `player_atk(L) = 45 × 1,1^(L-1)`, `player_max_hp(L) = c_level.hp × 2`, `MONSTER_DAMAGE_FACTOR 1,6`, `KILLS_PER_LEVEL 20`, `xp_to_next` ; `monster.gd:configure` : PV ×2,4 (élite ×1,6, boss ×14), attaque ×1,6 (élite ×1,25, boss ×1,5), +10 %/niveau ; `combatant.gd:take_damage` : défense `100/(100+déf)`, `CC_IMMUNITY 3 s`, `DOT_FACTOR` | socle commun |
| **Survie** | `epochs.gd` : `CAPS [15,25,35]`, `LEVEL_BONUS [0,12,22]`, `MONSTER_MULT [1 ; 1,35 ; 1,75 ; 2,2]` ; `run_director.gd` : `ZONE_DAMAGE [0,55 ; 0,8]` (par map, **toutes époques**), `EARLY_EASE 0,6` sur 3 min, rage +3 niveaux, `GREED_MONSTERS 1,25`, flux de monstres (`_update_spawns`), or (`KILL_GOLD 0,5`, `KILL_GOLD_ELITE 2,5`, `BREAK_GOLD`), coffres (`CHEST_BASE 20 + 3 × niveau`, `CHEST_GROWTH 1,18`) ; `run.gd` : enclume (`ANVIL_ROLLS`), insignes et expertise (`finish`) ; `slot_chests.gd` : pièces +0 à la puissance du héros | monstres, or, coffres, équipement de run |
| **Tour** | `tower.gd:RULES` (**réglables en mode dev**, page Tour) : niveau 0,5 / étage, force des monstres (rampe, zone, difficulté 0,7 → 1,6), duellistes (PV ×0,45, équipement généré), boss ×0,3, soin entre étages 35 % | seul mode déjà « profil » |
| **Duel** | `pvp_caps.gd` : `CAPS` (13 plafonds), `DAMAGE_SCALE 0,012`, `taken` (défense relative, 60 % max), `HEAL_MULT 0,35`, acharnement (30 s, ×2 / 20 s), `BASIC_MULT 0,7` ; `combatant.gd:PVP_HIT_CAP 0,2` ; `class_rival.gd:DUEL_DIFF [0,6 ; 0,8 ; 1 ; 1,2]` ; `duel.gd` : niveau = pièce la plus haute (`gear_level`), adversaire = copie de ton équipement par défaut | JcJ normalisé |
| **Duels de la Tour, entraînement** | `combatant.gd:hero_vs_hero_factor` (dégâts × PV/attaque du niveau, ≤ 1,2), **pas** de `PvpCaps` (`Duel.active` faux) | JcJ « non normalisé » de fait |
| **Arène d'IA** | `ml_arena.gd` : niveau 10 sans équipement ; `Duel.active` seulement pour les essais d'équilibrage (`--scenario=duel` avec niveau ou builds) | apprentissage |
| **Donjons** | n'existent pas (`monster.gd:configure(at_level)` prévu « donjons ») | — |

### 1.2 Puissance du héros : ce qui compte, mode par mode

`player.gd:recalc_stats` : attaque = (attaque du niveau × base de classe + attaque de l'arme + Force ×
0,6) × (1 + % d'attaque) ; PV = (PV du niveau + attributs) × (1 + %PV) + PV des pièces.
Les pièces suivent `1,08^(puissance-1)` (`items.gd:_level_k`), l'attaque du héros `1,1^(L-1)` :

| Niveau | Attaque du niveau | Attaque d'une arme moyenne | PV du niveau | PV des 7 pièces d'armure |
|---|---|---|---|---|
| 15 | 171 | ~45 (21 %) | 1 720 | ~640 à 900 |
| 35 | 1 150 | ~220 à 320 (19 à 28 %) | 5 272 | ~2 700 à 4 800 |
| 90 | 217 000 | ~19 000 (9 %) | 22 178 | ~360 000 (×16), ×2 à +10 |

Conséquence : **l'attaque vient du niveau, les PV viennent de l'équipement** ; plus le niveau monte,
plus l'écart se creuse (d'où les combats de 4 s ou sans fin avant 0.1.89). Les améliorations (+10 =
×2 sur la pièce : `items.gd:stats`), gemmes et enchantements ne comptent qu'en Tour et en Duel.

| Mode | Puissance de l'équipement (`Items.power_level`) | Améliorations / forge | Cartes, trophées, enclume | Méta (talents, certificats, archive, aura) |
|---|---|---|---|---|
| Survie | niveau du héros (plafonné 15/25/35) | non (+0, enclume seulement) | oui | oui |
| Tour | min(niveau de l'étage, plafond de la pièce) | oui | cartes oui, ni trophées ni enclume | oui |
| Duel | niveau = pièce la plus haute (≤ 101) | oui, puis normalisé | non | oui (copiés sur l'adversaire par défaut) |
| Entraînement | niveau choisi | oui | non | oui |

### 1.3 Survie : chiffres clés (modèle)

**Monstres face au héros en fin de map** (monstre normal du niveau, sans carte ni talent) :

| Map | Niveau | PV héros (É I → É IV) | Attaque héros | PV monstre | Attaque monstre (×`ZONE_DAMAGE`) |
|---|---|---|---|---|---|
| 1 | 15 | 2 360 → 2 620 | 216 → 237 | 1 900 × époque | 254 × 0,55 = 140 × époque |
| 2 | 25 | 4 550 → 5 450 | 547 → 594 | 3 900 × époque | 486 × 0,8 = 389 × époque |
| 3 | 35 | 7 990 → 10 040 | 1 370 → 1 474 | 7 470 × époque | 867 × époque |

(PV et attaque du héros calculés d'après la moyenne des pièces d'Eden de chaque palier ; script
d'analyse lancé sur `eden_catalog.json`, attributs et sets non comptés.)

**Écart des époques à jeu égal** (map 3) :

| Époque | Monstres | Héros : PV / attaque vs É I | Temps pour tuer | Coups encaissés avant de tomber |
|---|---|---|---|---|
| I | ×1 | — | ×1 | ×1 |
| II | ×1,35 | +11 % / +5 % | ×1,29 | ×0,82 |
| III | ×1,75 | +17 % / +6 % | ×1,65 | ×0,67 |
| IV | ×2,2 | +26 % / +8 % | ×2,04 | ×0,57 |

Seuls les **trophées** grandissent avec l'époque (`trophies.gd:level_mult` : ×0,88 au palier 23 →
×1,2 au palier 90, soit +36 %). Cartes, enclume, armes : identiques.

**Dans une map** : `ZONE_DAMAGE` fait passer les coups de ×0,55 (map 1) à ×1 (map 3) **à toutes les
époques** ; en époque IV, le saut entre la map 1 (0,55 × 2,2 = 1,21) et la map 3 (2,2) est brutal,
alors que la map 1 n'a plus à servir de tutoriel. `EARLY_EASE` (×0,6 → ×1 sur 3 min) se rejoue à
chaque map (`run_director.gd`, passage d'étape : `time = 0.0`) : voulu au départ sans équipement,
discutable aux maps 2 et 3 où le héros est déjà équipé.

**Expérience** : `xp_to_next(L) = xp d'un monstre du niveau × (20 + 2,5 L)` → ≈ **540 monstres**
pour la map 1 (niveaux 1 → 15), **690** pour la map 2, **940** pour la map 3 (élite ×4, boss ×8) :
≈ 2 200 « monstres normaux » par run gagnée, ≈ 34 niveaux, ≈ 50 choix de cartes (rapport Builds).

**Or et coffres** (par map) : revenu ≈ monstres × (1 + 0,5 × niveau) + objets cassés ×
(1 + 0,2 × niveau) × 1 à 16 ; prix du n-ième coffre = (20 + 3 × niveau) × type × 1,18^n. Avec ~700
monstres et ~400 objets cassés au niveau moyen 10 (hypothèses), ≈ 6 600 or : **≈ 19 coffres payés
en or**, plus les clés (élites, 0,6 % des objets). Les 30 coffres coûteraient ~35 000 or. La croissance
exponentielle (×1,18) fait que l'or « en plus » ouvre très peu de coffres en plus : l'or sert surtout à
**l'ordre** d'ouverture. À mesurer (E6).

**Enclume** : tirage moyen **+4,3** (somme des poids 95), soit ×1,43 sur un emplacement, 3 fois par run.

**Insignes** (`run.gd:finish`) : 25 × étape + monstres ÷ 25 + élites × 2 + 60 × époque si victoire ;
≈ 300 pour une époque I gagnée, ≈ 480 pour une époque IV. Prix de l'Armurerie (`gear_shop_page.gd:price`) :
mythique 30 + niveau (53 à 73), légendaire 80 + 2 × niveau (200 à 260), éveillé 250 → 4 à 5 pièces
par victoire en époque I, 2 en époque IV.

**Méta en Survie** : talents ≈ 1 % par point (80 points à la maîtrise 40 : de l'ordre de +20 %
d'attaque, +20 % de vitesse… selon l'arbre), archive jusqu'à +10 % dégâts / +8 % PV / +2 % critique,
aura +3 à +8 % d'un attribut, certificats (+X %), plateau. Ordre de grandeur : **×1,5 à ×1,8 de
puissance effective** pour un profil très avancé, contre ×1 pour un débutant.

### 1.4 Auto-attaques des armes : indice de dégâts mono-cible

Indice = `mult × speed × coups` (`weapon_attacks.gd:SPECS`, sans critique ni effet légendaire) et
effet de **+1 / +3 projectiles** (« Projectile supplémentaire », une carte légendaire vaut +3) :

| Variante (extrait) | Forme | Indice | +1 proj. | +3 proj. |
|---|---|---|---|---|
| Météore arcanique | zone visée | 1,20 | ×1,0 | ×1,0 |
| Dagues de lancer | 2 projectiles | 1,17 | ×1,5 | ×2,5 |
| Mitraille | 4 plombs | 1,08 | ×1,25 | ×1,75 |
| Impact (marteau), Taille lourde, Estoc | mêlée 1 coup | 1,0 à 1,04 | **×2** | **×4** |
| Rafale d'estocs | mêlée 3 coups | 0,96 | ×1,33 | ×2 |
| Flèche, Boule de feu, Obus | 1 projectile | 0,83 à 0,85 | **×2** | **×4** |
| Pluie de flèches, Éclat sacré | zone visée | 0,68 à 0,85 | ×1,0 (zones en plus autour) | ×1,0 |
| Directs, Lacération, Tourbillon, Onde sismique | mêlée rapide / onde | 0,56 à 0,67 | ×2 | ×4 |
| Malédiction | zone visée + poison | 0,45 (+ poison) | ×1,0 | ×1,0 |

Le socle est raisonnable (0,45 à 1,2, les faibles ont de la zone ou un effet sur la durée). **Ce sont
les cartes qui cassent l'échelle** : « Projectile supplémentaire » (épique, 5 cartes max, valeur ×
rareté) peut ajouter jusqu'à +5 à +15 coups ; Tempête d'acier +2 de plus. Une arme à un coup gagne
×6 à ×16, une Mitraille ×2,25 à ×4,75, une zone visée presque rien sur une cible seule.

### 1.5 Duel (JcJ) : ce que fait `pvp_caps.gd`

- **Échelle** (`damage_mult`) : part des PV retirée par un coup = `0,012 × mult du coup ×
  √(atk attaquant / atk cible) × √(PV attaquant / PV cible)` × acharnement. Deux fois plus d'attaque
  = +41 % seulement ; idem pour les PV. **Les stats en % (dégâts, critique, dégâts critiques, vitesse,
  recharge) ne sont pas ramenées**, seulement plafonnées (`CAPS` : dégâts +200 %, critique 50 %,
  dégâts critiques ×2,5, vitesse d'attaque 200 %…).
- **Défense relative** (`taken`) : 50 % à défense égale, 41 % à défense double, 60 % de réduction max.
- **Garde-fous** : 20 % des PV max par coup (`PVP_HIT_CAP`), soins ×0,35, acharnement après 30 s
  (×2 toutes les 20 s, soins ÷ autant), auto-attaque ×0,7 sans contrôle.
- **Contrôles** : rien de propre au JcJ ; chaque type a son insensibilité de 3 s, mais **6 types
  différents** (`CC_TYPES`) peuvent s'enchaîner sur la même cible.
- **Résultat mesuré** (CHANGELOG 0.1.118) : 53 à 88 s par manche au niveau 90 entre profils « opti » ;
  cible de `CLAUDE.md` : 30 s à 1 min 30 à tout niveau. **Atteint.**
- **Duels de la Tour** : `hero_vs_hero_factor` seulement (dégâts × PV/attaque du niveau) ; ni plafonds,
  ni soins réduits, ni acharnement, ni auto-attaque réduite. Un même duelliste se joue donc selon
  d'autres règles dans la Tour et dans le Duel.
- **Cerveaux d'IA** : entraînés au niveau 10 sans équipement **et sans `PvpCaps`** (`ml_arena.gd:429`) ;
  quand ils pilotent un héros en Duel, l'auto-attaque ×0,7 sans contrôle, les soins ×0,35 et
  l'acharnement changent les règles qu'ils ont apprises.

### 1.6 Tour

Niveau = 1 + 0,5 × (étage - 1) (étage 200 = niveau 100). Monstres ×(1 + 0,02 × étage dans la zone +
0,1 × zone) × difficulté (0,7 / 1 / 1,3 / 1,6) ; duellistes PV ×0,45 de l'entraînement, équipement
généré au niveau ; boss ×0,3 des PV de donjon (soit ×4,2 du monstre). L'équipement du héros vaut
min(niveau de l'étage, plafond de la pièce) : **une pièce d'Eden de niveau N sert jusqu'à l'étage ≈ 2N**
(une mythique 23 de l'époque I décroche vers l'étage 45-50). C'est le seul mode où le coffre commun,
la forge et l'Armurerie pèsent vraiment.

### 1.7 Fini / à moitié / mort / incohérent / docs en retard (équilibrage)

| État | Quoi |
|---|---|
| Fini et sain | duel normalisé (durées tenues), Tour réglable en mode dev, rampe de début de map, rage, plafonds de niveau par map, enclume, prix des coffres croissants |
| À moitié | économie (or, insignes, cristaux) sans cible ni mesure ; époques réglées par un seul multiplicateur (PV et dégâts ensemble) ; contrôles en JcJ |
| Mort | `run_director.gd:ZONE_MAX_LEVEL` (limestone 15, remplacé par `Epochs.cap`) ; branche hors Survie de `_spawn_monster` (`ZONE_DAMAGE` par zone, `tier_extra`) ; or et butin d'équipement des monstres hors Survie (`count`, `_drop_item`) |
| Incohérent | deux règles « héros contre héros » (Duel / Tour + entraînement) ; cerveaux entraînés sans les règles du duel ; `ZONE_DAMAGE` de tutoriel appliqué aux époques II à IV ; Projectile supplémentaire ×1 à ×4 selon l'arme ; % de stats non normalisés en duel |
| Docs / commentaires en retard | `pvp_caps.gd` (en-tête : « dans la Tour… rien n'est plafonné » alors que ses duels ont une autre échelle ; `BASIC_MULT` parle des « coups du combo de l'arme », supprimé en 0.1.127) ; `run_director.gd:606-608` (« seule source des mythiques ») ; `DESIGN.md`, « Pression constante » (chiffres de flux à revérifier) et « Monnaies, coffres et zones » (déjà signalé par Progression) |

---

## 2. Problèmes et opportunités (du plus important au moins important)

1. **Pas de lieu unique pour l'équilibrage d'un mode** (ajout n°3 du joueur). Pour donner au JcJ, à la
   Survie et aux futurs Donjons leurs propres stats et durées, il faut aujourd'hui toucher 6 fichiers ;
   et deux modes qui se ressemblent (Duel, duels de la Tour) ont des règles différentes sans raison.
   *Opportunité* : `Tower.RULES` + page Tour du mode dev montrent le bon modèle (table de règles nommées,
   réglables par le joueur lui-même).
2. **Pas de cible chiffrée par mode**, donc rien pour dire « c'est trop long / trop court ». Seul le
   duel a une cible (30 à 90 s). La Survie se règle au ressenti, l'économie aussi.
3. **Mur des époques III-IV probable** : ×1,65 puis ×2 sur le temps pour tuer et ×1,5 à ×1,75 sur
   les dégâts subis, alors que les outils du joueur (cartes, enclume) restent les mêmes. Le joueur
   attaque l'époque II : c'est le bon moment pour adoucir la marche avant qu'il ne bute.
4. **Multiplicateurs sans plafond en Survie** (Projectile supplémentaire, Élan meurtrier, trophées à
   l'impact, Lame large) : ils écrasent l'écart entre armes et rendent les époques faciles pour un build
   et murales pour un autre.
5. **JcJ : trois trous** — stats en % non normalisées, contrôles enchaînables, cerveaux entraînés sous
   d'autres règles. Pour les Arènes 2v2 / 3v3 et le Champ de bataille, rien n'existe (soins d'alliés,
   focus à plusieurs, réapparition).
6. **Économie sans mesure** : or (ordre des coffres plus que quantité), insignes (un seul puits),
   cristaux (+10 d'une pièce = 1 000 à 4 000 cristaux pour quelques dizaines par run, rapport
   Progression). Le joueur doit encore se prononcer sur l'or.
7. **Donjons à concevoir** : c'est l'occasion d'un mode où l'équipement du hub compte (synchronisé au
   niveau), à côté de la Survie (sans équipement) et du JcJ (normalisé).
8. **Résidus** : code mort de l'ancien équilibrage par zone, commentaires faux (1.7).

---

## 3. Propositions

Coût : S (quelques heures), M (une session), L (plusieurs). ★ = phare.

### ★ E1 — Profils de mode : un seul endroit par mode (pilote de l'ajout n°3, M)

**Intérêt pour le joueur** : chaque mode a « son » équilibrage (stats, durée des combats, ce qui
compte), lisible et réglable dans le mode dev comme la Tour aujourd'hui. Le joueur apprend une fois
son héros (mêmes sorts, mêmes armes, mêmes effets partout, avis Builds) ; seuls les **chiffres**
changent, et ils changent **à un seul endroit**.

**Règles**
- Nouveau `core/mode_rules.gd` : une table `PROFILES` (nom → règles), lue par
  `ModeRules.get("clé")` selon le mode en cours (`Run.survival`, `Tower.active`, `Duel.active`, futur
  `Dungeon.active`, `Training.active`). Valeurs par défaut = **les chiffres actuels** (rien ne change
  au premier envoi) ; surcharge en mode dev (`data/dev_edits.json → "modes"`, comme `"tower"`).
- Champs, en 4 familles :

| Famille | Champs (valeurs actuelles en exemple) |
|---|---|
| Monstres | `mob_hp` 2,4 · `mob_atk` 1,6 · `elite_hp` 1,6 · `boss_hp` 14 · `boss_atk` 1,5 · `ramp` (0,6 sur 180 s) · `stage_dmg` [0,55 ; 0,8 ; 1] · `epoch_hp` / `epoch_atk` (E5) · `enrage_after` (Donjon, E4) |
| Héros | `gear` : "run" (Survie : pièces +0 au niveau) / "sync" (Tour, Donjon : min(niveau, plafond)) / "norm" (JcJ) · `cards` (oui/non) · `trophies` · `anvil` · `meta` (part des talents, certificats, archive, aura : 1 = plein) · `res` (résurrections) |
| Héros contre héros | `dmg_scale` 0,012 · `gear_weight` 0,5 (E3) · `hit_cap` 0,2 · `mitigation_max` 0,6 · `heal_mult` 0,35 · `basic_mult` 0,7 · `basic_cc` non · `pressure_start` 30 · `pressure_step` 20 · `cc_mult` 1 · `cc_chain` (E3) · `caps` (les 13 plafonds) |
| Gains | expertise ×, insignes ×, cristaux ×, records comptés (oui/non : Progression P1g) |

- Profils : **survie**, **tour**, **tour_duel**, **donjon**, **duel**, **duel_pantheon** (cerveaux),
  **arene** (2v2/3v3), **champ** (10v10), **entrainement**. `PvpCaps` devient la lecture du profil
  JcJ en cours (ses constantes deviennent les valeurs du profil **duel**) ; `hero_vs_hero_factor`
  disparaît au profit de **tour_duel** et **entrainement**.
- Page « Modes » du mode dev (copie de la page Tour : nom, valeur, pas), avec un bouton « valeurs
  d'origine ».

**Touche** : nouveau `core/mode_rules.gd` ; `pvp_caps.gd`, `combatant.gd:take_damage/heal`,
`monster.gd:configure`, `run_director.gd:_spawn_monster`, `epochs.gd`, `tower.gd` (ses `RULES`
deviennent le profil **tour**, page du mode dev conservée), `dev_tower.gd` / `dev_pages.gd`.
**Dépendances** : Modes (liste des modes et de leurs contrats), Builds (ce qui reste identique
partout), Interface (afficher les règles du mode sur sa page : « en Duel, les soins sont réduits… »).
**Arène d'IA** : aucun ajout d'observation.

### ★ E2 — Le contrat chiffré de chaque mode (S, valeurs à valider par le joueur)

**Intérêt** : savoir ce qu'on vise, et vérifier qu'on y est (E6). Ce sont les **cibles** ; E1 fournit
les **boutons**.

| Mode | Durée d'un combat | Pression sur le héros | Ce qui doit compter le plus | Équipement |
|---|---|---|---|---|
| **Survie** | monstre normal : 1 à 3 s d'auto-attaque en début de map, < 1 s avec un build ; élite 8 à 15 s ; **boss 60 à 120 s** ; map 10 à 15 min, run 35 à 45 min | un monstre normal tue en **20 à 25 coups** (époque I) → **12 à 15** (époque IV) ; une erreur coûte, une horde ignorée tue en 5 s | le build de la run (cartes, arme, trophées) et l'esquive | aucun au départ (+0 au niveau du héros) |
| **Tour** | étage de monstres 30 à 60 s ; duelliste 20 à 45 s ; boss 60 à 90 s | croissante, une seule vie | équipement du hub (forge, Armurerie) + cartes | synchronisé au niveau de l'étage |
| **Donjon** (E4) | salle 20 à 40 s ; **boss 2 à 4 min** avec mécaniques ; donjon 10 à 15 min | moyenne, pointes aux mécaniques | équipement + maîtrise des mécaniques | synchronisé au niveau du donjon |
| **Duel** | **manche 30 à 90 s** (en place) | égale des deux côtés | jeu (esquive, contrôles, annulations), puis build | normalisé (`gear_weight`) |
| **Panthéon** (cerveaux) | manche 45 à 90 s | égale | jeu seul | niveau 10, sans équipement (conditions d'entraînement) |
| **Arènes 2v2 / 3v3** | manche 60 à 150 s | focus à plusieurs | jeu d'équipe, soins, contrôles | normalisé |
| **Champ de bataille 10v10** | un héros focalisé tient 8 à 15 s ; partie 8 à 12 min (objectifs) | réapparition 8 à 12 s | objectifs, placement | normalisé |

### ★ E3 — JcJ complet : poids de l'équipement, contrôles, mêmes règles partout (M)

Base : `pvp_caps.gd` (sain : on le garde). Six ajouts, tous des valeurs du profil (E1).

1. **Poids de l'équipement (`gear_weight`, g)** — généraliser `damage_mult` :
   part retirée = `dmg_scale × mult × (atk_att / atk_cible)^g × (PV_att / PV_cible)^g`.
   g = 0,5 = **aujourd'hui**. g = 0 : seul le jeu compte (Panthéon, futur classé) ; g = 0,75 : « duel
   libre », où l'Armurerie et la forge comptent davantage. Répond à la question de Progression
   (« à quoi sert l'Armurerie en JcJ ? ») **sans** second système : un seul curseur par mode.
2. **Stats en % ramenées** — appliquer le même g aux bonus en % : dégâts `dmg_mult^g`, et réduire les
   plafonds du profil duel : dégâts +200 % → **+100 %**, dégâts sur la durée +200 % → +100 %, zone et
   portée +100 % → +50 %. Les critiques (50 %, ×2,5) et la vitesse (200 %) restent tels quels (déjà
   mesurés en 0.1.118). But : un talent « +20 % de dégâts » ne vaut pas plus en duel que « +20 %
   d'attaque » (aujourd'hui il vaut ~2 fois plus).
3. **Contrôles en JcJ** : durée ×0,7 (`cc_mult`) et **endurance partagée** (`cc_chain`) : après un
   contrôle, quel que soit son type, le suivant dans les 5 s dure moitié moins, le 3e est refusé
   (« INSENSIBLE », déjà affiché par `combatant.gd:_cc_gate`). Monstres et Survie : inchangé (le
   joueur garde le plaisir de geler une horde).
4. **Duels de la Tour sous un vrai profil** (`tour_duel`) : mêmes règles que le Duel (échelle, plafonds,
   soins, auto-attaque ×0,7) **mais** `gear_weight` 0,75 et pas d'acharnement (la Tour est le mode de
   l'équipement), PV du duelliste ×0,45 gardés. Le joueur ne réapprend pas le 1 contre 1 entre la Tour
   et le Duel.
5. **Cerveaux d'IA** : le Panthéon (Progression P8) se joue dans le profil `duel_pantheon` = **les
   conditions d'entraînement** (niveau 10, sans équipement, g = 0, pas de `PvpCaps` sauf l'acharnement
   pour finir les manches). Le cerveau joue alors exactement le jeu qu'il a appris ; l'égalité est
   garantie. Si l'on veut plus tard les cerveaux sous les règles du duel : une étape d'entraînement de
   plus (`--scenario=duel`), sans nouvelle observation.
6. **Équipe (Arènes, Champ)** : soins ×0,5 (au lieu de 0,35 : le soigneur a un rôle), mais
   **« pris pour cible »** : un héros frappé par 2 adversaires ou plus dans les 2 dernières secondes
   reçoit ×0,8 (le focus reste fort sans être instantané) ; `hit_cap` 0,15 ; acharnement à 60 s
   (arène) ou désactivé (champ, remplacé par les objectifs) ; Champ : `dmg_scale` 0,008 et réapparition.

**Touche** : `pvp_caps.gd`, `combatant.gd` (`take_damage`, `_cc_gate`), `tower_director.gd` /
`class_rival.gd` (profil des duels de la Tour), `ml_duel_pilot.gd` (profil Panthéon), `duel_prep.gd`
(l'aperçu « un coup retire X % » lit le profil).
**Dépendances** : Modes (formats des arènes et du champ, place du Panthéon), Builds (avis : les
combos d'états doublent ×1,5 en JcJ au lieu de ×2, rapport Builds §8 — d'accord, à mettre dans le
profil), Progression (Panthéon : « fiche égale » = ce profil). **Vérification** : `ml_arena.tscn
--scenario=duel` avec les profils « opti » à 3 niveaux (25, 60, 90) après le changement, cible E2.

### ★ E4 — Donjons : l'équipement compte, synchronisé au niveau (M, avec l'équipe Modes)

**Intérêt** : un troisième équilibrage, distinct de la Survie (sans équipement, build de run) et du
JcJ (normalisé) : **le mode où l'équipement du hub et la forge paient**, avec des boss à mécaniques.

**Règles proposées (équilibrage ; le format est à l'équipe Modes)**
- **Niveau du donjon** choisi (paliers des époques : 20, 45, 65, 85) ; l'équipement vaut
  min(niveau, plafond de la pièce) (`Items.power_level`, déjà le cas en Tour) : un héros en pièces 90
  ne roule pas sur le donjon 20, et une pièce trop basse se voit (« synchronisée : 23 / 45 »).
- **Monstres plus robustes qu'en Survie mais moins nombreux** : PV ×1,6 (pas ×2,4 : pas de cartes
  pour compenser), dégâts ×1,6 ; élites ×2,5 ; **boss ×25 de PV** avec ses mécaniques
  (`boss_brain.gd`, miroir, invocations) et une **rage au bout de 4 min** (`enrage_after`, dégâts ×2
  toutes les 30 s : le « test de dégâts » qui donne son sens à la forge).
- **Cartes** : si l'équipe Modes garde des cartes en Donjon (avis Builds : mini-Survie), alors PV des
  monstres ×2,4 comme en Survie et un nombre de cartes fixe (une par salle) ; sinon, pas de cartes et
  les valeurs ci-dessus. À trancher au tour 2.
- **Contrôle de cohérence** : à équipement « attendu » (pièces du palier, +6 en moyenne), le boss doit
  tomber en 2 à 4 min ; à pièces +0, en 4 min juste avant la rage forte ; à pièces +10 gemmées, en
  1 min 30. La forge fait **gagner du temps**, pas l'accès.

**Touche** : profil `donjon` (E1), futur mode Donjon (Modes), `monster.gd:configure(at_level)`.
**Dépendances** : Modes (format), Progression (récompenses : pièces ciblées, plans), Builds (cartes ou
pas), Interface (niveau synchronisé affiché).

### ★ E5 — Survie : adoucir la marche des époques et séparer PV et dégâts (S)

**Intérêt** : les époques III et IV restent des défis sans devenir des murs ; « combats lisibles et
intenses » plutôt que « tout tue en 5 coups ».

**Règles**
- Séparer `Epochs.MONSTER_MULT` en **PV** et **dégâts** : PV [1 ; 1,35 ; 1,75 ; 2,2] (inchangé :
  les combats s'allongent, le build compte) ; dégâts **[1 ; 1,25 ; 1,5 ; 1,75]** (au lieu de 2,2 : à
  l'époque IV, le héros encaisse 0,72 fois autant de coups qu'à l'époque I, au lieu de 0,57).
- `ZONE_DAMAGE` (tutoriel 0,55 / 0,8) **seulement à l'époque I** ; époques II à IV : 0,8 / 0,9 / 1
  (marche plus douce entre les maps, la map 1 n'est plus une promenade).
- `EARLY_EASE` : seulement sur la map 1 (le héros arrive équipé aux maps 2 et 3).
- Compensation côté héros, à choisir : les **trophées** grandissent déjà de +36 % entre les époques ;
  ajouter la même idée à l'**enclume** (tirage moyen +4 à l'époque I → +5 à l'époque IV : décaler la
  table de 1 cran par époque au-delà de II).
- Ne rien changer avant d'avoir le ressenti du joueur à l'époque II **et** les mesures E6 ; ces
  valeurs sont la première proposition.

**Touche** : `epochs.gd`, `run_director.gd:_spawn_monster`, `run.gd:anvil_roll`.
**Dépendances** : Progression (rangs héroïques P6 : chaque rang = +x % de PV et +y % de dégâts, mêmes
boutons), Interface (afficher « monstres : PV ×1,75, dégâts ×1,5 » sur la page Survie).

### ★ E6 — Mesurer : journal de run, puis banc d'essai (S puis M)

**Intérêt** : régler l'or, la durée des maps, la mortalité, les insignes **sur les vraies parties du
joueur** et non sur nos modèles.

**Règles**
- **Journal de run (S)** : à chaque run (Survie, Tour, Duel), un fichier `feedback/runs/<date>_<mode>.json`
  (dossier hors git, lu par la session locale comme les notes Alt + clic droit) : par map et par minute
  — niveau, monstres / élites tués, or gagné par source (monstres, objets, défis) et dépensé (coffres,
  marchands), coffres ouverts (or ou clé), clés, PV perdus, morts / résurrections, temps du boss, DPS
  moyen, cartes prises ; en fin de run, expertise, insignes, cristaux. Aucun écran : c'est pour nous.
- **Banc d'essai (M)** : le pilote automatique existe (`world.gd:--autoplay`, `--bot-mode`,
  `--boss-after`) ; une scène `tests/bench_run.tscn -- <classe> <époque> <graine>` lance une Survie
  automatique en headless et écrit le même journal. Lancer 5 classes × 4 époques (≈ 1 h de machine,
  session locale) pour comparer les époques et les armes (E5, E7).
- Outil de lecture : `tools/run_stats.py` qui résume les journaux (moyenne par époque / classe).

**Touche** : `run.gd`, `run_director.gd` (compteurs), `tower.gd:finish`, `duel.gd:finish`, nouvelle
scène de test. **Dépendances** : Progression (mêmes compteurs que les succès P4 : on les écrit une fois).

### ★ E7 — Garde-fous des multiplicateurs de Survie (S, avec Builds B3, B8, B13)

Chiffres proposés en réponse à l'équipe Builds :

| Effet | Aujourd'hui | Proposition |
|---|---|---|
| **Projectile supplémentaire** | +1 × rareté (légendaire +3), 5 cartes ; ×2 par coup pour une arme à 1 coup, ×1,25 Mitraille, ×1 zone visée | **+1 projectile / frappe par carte quelle que soit la rareté** (la rareté ajoute +10 / 20 / 30 % de dégâts d'auto-attaque) ; chaque variante reçoit un **gain par frappe** `proj_gain` pour que +1 vaille **+40 à +60 %** partout : mêlée à 1 coup 0,5 d'une frappe, 1 projectile 0,5, Rafale d'estocs et Dagues 0,6, Mitraille 1, zone visée : la zone en plus tombe **sur** la cible avec 0,5 ; plafond **+4** (cartes + Tempête d'acier) |
| **Élan meurtrier** | -0,3 s par monstre tué, sans recharge (0,7 s en légendaire) | recharge interne **0,15 s** et **au plus 1,5 s rendues par seconde** |
| **Trophées « à l'impact » sans recharge** (Vivacité, Esprit vif, Rage du guerrier, Arcanes, Éveil, Instinct du prédateur, Double frappe) | ~100 % du temps en horde, ~45 % sur un boss | recharge **5 s** (Double frappe : 1 s) ; chance ×1,5 pour garder ~50 % du temps sur un boss |
| **Lame large** | +15 % de zone par carte, commune, 10 cartes (+150 %, × rareté) | plafond **+100 %** pour la zone venant des cartes ; reste commune |
| **Exécuteur, recharges, esquive** | cartes proposées au-delà des plafonds (30 %, 50 %, 20 %) | retirées de l'offre au plafond (B1) |
| **Combos d'états** (B4) | ×2 | ×2 en Survie, ×1,5 en JcJ (profil) |
| **Rangs de certificat** (Progression P7) | — | plafond global de la méta en Survie : **×1,6 de puissance effective à la maîtrise 20, ×1,8 au maximum** (talents + certificats + archive + aura) ; les rangs II / III comptent dans ce budget |

**Touche** : `boons.gd`, `weapon_attacks.gd` (`proj_gain`, `action_for`), `procs.gd` (recharge
interne), `trophies.gd:KINDS`, `run.gd:roll_cards`. **Vérification** : banc d'essai E6, 3 armes
(Iaï, Mitraille, Pluie de flèches) avec 0, 2 et 4 projectiles en plus.

### E8 — Économie : or, insignes, cristaux (S, chiffres à confirmer par E6)

- **Or en run** : garder la croissance ×1,18 (elle rend l'or « décisionnel » : l'ordre des coffres),
  mais **remettre le prix de base à chaque map selon le niveau** (déjà le cas) et afficher le prix du
  prochain coffre de chaque type (Interface). Cible : ouvrir **20 à 24 coffres sur 30** par map en
  jouant bien, 15 à 18 en jouant vite ; si E6 montre plus de 26, croissance ×1,18 → ×1,22 ; moins de 15,
  prix de base 20 → 15.
- **Insignes** : cible « une pièce mythique de ton époque par run gagnée **et** une légendaire toutes
  les 3 runs gagnées » ; avec les prix actuels c'est presque le cas (≈ 300 insignes en époque I). Ne
  rien changer ; ajouter le puits d'apparences de Progression (P9).
- **Cristaux** : le +10 du hub coûte 1 000 à 4 000 cristaux contre quelques dizaines par run. Cible :
  **+6 sur une pièce en ~2 sessions de Tour, +10 en ~15** ; donc coût en cristaux ÷ 3 jusqu'à +6, coût
  actuel de +7 à +10, et cristaux en Tour (Progression P5 : 2 + étage ÷ 20 par étage, soit ~450 pour
  une montée 1 → 100).
- **Rangs héroïques** (Progression P6) : chaque rang +12 % PV et +8 % dégâts des monstres, insignes
  +15 % ; le rang 10 ≈ ×2,2 PV / ×1,8 dégâts sur l'époque IV : réservé aux builds aboutis.

**Touche** : `run_director.gd:chest_price`, `forge.gd:price`, `tower.gd:finish`, `gear_shop_page.gd`.
**Dépendances** : Progression (P5, P6, P9), Interface (prix affichés).

### E9 — Ménage (S)

Retirer `ZONE_MAX_LEVEL`, la branche « par zone » de `_spawn_monster` / `_monster_level` et le butin
d'équipement des monstres hors Survie s'il ne sert plus (à confirmer avec Modes : le Donjon pourrait
le reprendre) ; corriger les commentaires de `pvp_caps.gd` et `run_director.gd:606` ; mettre `DESIGN.md`
à jour avec un tableau « profils de mode » (E1, E2).

### Ordre conseillé

1. **E6 journal** (S) et **E9** (S) : mesurer avant de toucher ;
2. **E1 profils** (M) avec les valeurs actuelles, puis **E3** (JcJ) et **E7** (garde-fous) ;
3. **E5** (époques) après le ressenti du joueur à l'époque II ;
4. **E4** (Donjons) quand l'équipe Modes a fixé le format ; **E8** avec les mesures.

---

## 4. Questions aux autres équipes

**Modes**
1. Liste définitive des modes et de leur contrat (E2) : durées et « ce qui compte » vous conviennent-ils ?
2. Donjons : avec ou sans cartes de run ? Niveau choisi ou imposé ? Groupe (IA alliées) un jour ?
3. Tour : garde-t-elle les cartes de run ? Duels de la Tour sous les règles du Duel (E3.4) : d'accord ?
4. Panthéon : d'accord pour « conditions d'entraînement » (niveau 10, sans équipement) plutôt que
   « copie de ton équipement » ?
5. Arènes / Champ : réapparition, objectifs, soins sur alliés (pour E3.6).

**Builds**
1. `proj_gain` par variante (E7) : les valeurs vous vont-elles, et la rareté qui ajoute des dégâts
   plutôt que des projectiles ?
2. Recharge interne 5 s des trophées « à l'impact » : ça casse-t-il une identité de build ?
3. Correction physique / magique des 20 classes (B5) : elle augmente fortement les dégâts de leurs
   sorts en Survie ; nous proposons de la faire **sans compensation**, puis de regarder le journal (E6).
   En duel, les profils « opti » sont à régénérer (`tools/gen_profiles`).
4. Effets sur la durée non cumulables (un par type et par cible) : nous le gardons (sinon le poison
   en horde explose) ; d'accord ?
5. Budget d'un certificat : **≈ 3 cartes communes** de la même stat (ex. +15 % d'attaque, +9 % de
   critique, +24 % de vitesse d'attaque) ; ceux à effet (procs) ≈ une carte rare au niveau 3.

**Progression**
1. Le plafond de méta en Survie (×1,6 à la maîtrise 20, ×1,8 au max) vous convient-il pour les rangs
   de certificat (P7) ?
2. Les compteurs du journal (E6) et ceux des succès (P4) : on les définit ensemble pour ne les écrire
   qu'une fois ?
3. Rangs héroïques (P6) : nos multiplicateurs (E8) vous conviennent-ils ?

**Interface**
1. Où afficher les règles d'un mode (« en Duel : soins ×0,35, acharnement après 30 s ») et le niveau
   synchronisé d'une pièce (Tour, Donjon) ?
2. Page « Modes » du mode dev (E1) : même présentation que la page Tour ?

---

## 5. Questions au joueur (l'indispensable)

1. **Durées voulues** : les cibles du tableau E2 te parlent-elles (boss de Survie 1 à 2 min, manche de
   duel 30 à 90 s, boss de donjon 2 à 4 min, arènes jusqu'à 2 min 30) ?
2. **JcJ et équipement** : en Duel, l'équipement doit-il compter **un peu** (aujourd'hui), **pas du
   tout** (seul le jeu), ou **davantage** (un « duel libre » où la forge paie) ? On peut proposer les
   trois avec un seul réglage.
3. **Époques** : à l'époque II, sens-tu que les monstres « frappent trop » ou « tiennent trop » ? Ta
   réponse choisit entre baisser leurs dégâts (E5) ou leurs PV.
4. **Or** : en Survie, ouvres-tu presque tous les coffres d'une map, ou en laisses-tu beaucoup faute
   d'or ?

---

## 6. Avis sur les autres ajouts du joueur

- **Tutoriel (n°1)** : les mêmes profils (E1) permettent un profil « tutoriel » (dégâts ×0,4, pas de
  rage) pour la première map du tout premier lancement, sans toucher à la Survie.
- **Déblocage progressif (n°2)** : d'accord avec l'ordre de Progression (Forge et Tour après l'époque I) :
  l'équipement du hub n'a de sens qu'avec un mode synchronisé (Tour, Donjon) ; ouvrir le Duel après les
  duels de la Tour est cohérent si ces duels suivent les règles du Duel (E3.4).
- **Mini-jeux (n°4)** : chaque mini-jeu = un profil (E1) avec son contrat (E2) ; coût d'équilibrage
  faible s'il réutilise le socle.
- **Tout collectionner (n°5)** : seuils de succès (Progression P4) à caler sur le journal (E6) ;
  « tout l'équipement amélioré à fond » demande la baisse du coût en cristaux (E8), sinon des milliers
  d'heures.

---

## Résumé (5 lignes)

1. **E1 Profils de mode** : un seul fichier `mode_rules.gd` (réglable en mode dev) porte les chiffres de chaque mode — Survie, Tour, Donjon, Duel, Panthéon, Arènes, Champ — au lieu de 6 fichiers et de deux règles JcJ contradictoires.
2. **E2 Contrat chiffré par mode** : durées et pression visées (boss de Survie 1-2 min, manche de duel 30-90 s, boss de donjon 2-4 min…) pour savoir quoi régler.
3. **E3 JcJ complet** à partir de `pvp_caps.gd` : un curseur « poids de l'équipement » (0 = jeu seul, 0,5 = aujourd'hui, 0,75 = duel libre), stats en % ramenées, contrôles à endurance partagée, duels de la Tour et cerveaux (Panthéon = conditions d'entraînement) sous des règles cohérentes.
4. **E4 Donjons synchronisés au niveau** (l'équipement et la forge y paient, boss 2-4 min avec rage) et **E5 époques adoucies** (dégâts des monstres séparés des PV : ×1,75 au lieu de ×2,2 à l'époque IV, tutoriel de la map 1 réservé à l'époque I).
5. **E6 Journal de run + banc d'essai** pour mesurer or, durée et mortalité sur les vraies parties, et **E7 garde-fous** (Projectile supplémentaire normalisé +40-60 % par arme, Élan meurtrier et trophées « à l'impact » avec recharge, Lame large plafonnée).
