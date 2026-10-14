# Équipe Builds & identité de combat — rapport du tour 1 (version 0.1.130)

Périmètre : ce qui fait un **build** (sorts et enchaînements, auto-attaque d'arme et ses améliorations,
arme secondaire, cartes de build, trophées, effets déclenchés, certificats, talents, sets) et
l'**identité** des 60 classes. Tout est lu dans le code (le code fait foi) ; les chiffres viennent de
scripts d'analyse lancés sur `game/data/classes.json`, `talents.json`, `eden_catalog.json` et des
poids de `Run.roll_cards` (aucune modification du jeu).

---

## 1. État des lieux

### 1.1 Ce qui compose un build aujourd'hui (Survie)

```
Classe (sorts d'Eden, attributs, type d'arme)            ← choisie au lobby
 ├─ 12 sorts : 4 cases × (sort principal + 2 enchaînements)   ← cartes de niveau / coffres de sort
 │    └─ rangs 1→10 (cartes d'amélioration) + cartes de classe (Puissance, Cadence, Persistance, Ferveur)
 ├─ Arme principale = arme de la classe, 1 des 2 variantes   ← choix au départ, coffres d'arme
 │    └─ améliorations d'arme 1→8 (commune → légendaire, effet légendaire de la variante)
 ├─ Arme secondaire (autre type, 60 % des dégâts)            ← élites / boss
 ├─ Cartes de build communes (38 + 11 passifs communs)       ← cartes de niveau / coffres de passif
 ├─ Trophées : collection de 12 effets différents            ← 4 coffres de trophée par map
 ├─ Équipement d'Eden +0 (sets d'Eden, passif d'arme mythique) + enclume par emplacement
 └─ Méta (hors run) : talents de la classe, plateau de 7 certificats
```

Fichiers clés : `core/run.gd` (`roll_cards`, `apply_card`, `passive_stats`, `arrange`), `core/boons.gd`,
`core/cards.gd`, `combat/weapon_attacks.gd`, `core/trophies.gd`, `combat/procs.gd`,
`core/cert_board.gd`, `core/items.gd` (sets), `core/slot_chests.gd`, `player/player.gd`
(`recalc_stats`, `_hit_monster`, `_chain_press`, `_perfect_cancel`), `core/progression.gd`.

### 1.2 Les 60 classes (`classes.json`)

- **1 015 sorts** au total (14 à 20 par classe). Types : buff **363 (36 %)**, zone au sol 162, projectile
  120, tourbillon 104, cône 88, **soin 84 (8 %)**, élan 29, rafale 25, éventail 21, téléportation 16, ligne 3.
- **Buffs ramenés à ~20 statuts** : Barrière 87 fois, Fureur 67, Hâte 51, Œil acéré 49, Frénésie 34…
  Les effets riches d'Eden (« +5 % de dégâts par esquive, 5 cumuls ») deviennent « Barrière 5 s +
  Évasion 5 s ». **140 doublons** de statut dans une même classe (le Chevalier glaciaire a 5 sorts qui
  donnent Évasion, la Danseuse élégante 4 Hâte et 3 Barrière) : le 2e sort qui donne le même statut
  n'apporte presque rien (les statuts ne se cumulent pas).
- **Part de buffs** : 50 à 55 % chez Chevalier glaciaire, Danseuse élégante, Exécuteur, Chronologiste,
  Psalmiste, Archimage. Une run de ces classes prend 5 à 7 buffs sur ses 12 sorts.
- **Soins** : 84 sorts, **3 seulement font des dégâts**. Adorateur de la vie : 11 soins sur 18 sorts,
  3 sorts d'attaque. En Survie (solo), la moitié de leur kit ne tue rien.
- **Familles** : chaque classe orange partage **9 à 10 sorts** avec sa classe parente **et** avec sa
  classe sœur ; elle n'a que **8 sorts propres** (4 au départ, les 4 autres aux maîtrises 2 à 5).
  En run (12 sorts), Guerrier, Berserker et Protecteur jouent surtout les mêmes sorts. Profil de types
  de sorts presque identique (cosinus > 0,98) : Berserker/Protecteur, Psalmiste/Orateur,
  Clerc/Chaman, Voleur/Artiste martial, Tempêtier/Envoyé obscur.
- **Combos d'états** (seule vraie synergie entre sorts, `player.gd:_hit_monster`, champ `combo`) :
  21 sorts dans **5 classes** seulement (lignées Samouraï et Voleur : saignement → cicatrice → Marduk,
  embuscade ×2 sur empoisonné). Les 55 autres n'ont aucune interaction entre leurs sorts.
- **Physique / magique incohérent : 20 classes.** La classe garde `dmg_type: phys` et
  `base.matk = 0.5` alors que ses sorts d'attaque sont surtout magiques : Lame noire (11 sorts
  magiques sur 11), Archi-élémentaliste (11/11), Envoyé obscur (9/10), Dompteur de démons,
  Chronologiste, Juge, Équilibriste, Barde, Poète, Adorateur, Chaman, Archimage, Illusionniste, Aube,
  Paladin, Dragonnier, Mecha Arès ; Chasseur de démons à l'inverse. Effets : leurs sorts partent sur
  une attaque magique de base **2,2 fois plus faible** que leur classe sœur (Lame de lumière : 1,1),
  le sélecteur de classe affiche « dégâts physiques », les bonus d'attribut des cartes de sort
  donnent Force/Agilité au lieu d'Intelligence/Sagesse (`run.gd:_describe_card`), et Lame noire
  porte deux certificats de critique **magique**… pour une base physique.
- **Armes** : axe 2 classes seulement (Guerrier, Berserker), arc / bâton / épée 6 chacune.

### 1.3 Sorts, enchaînements, presets

- 4 cases, 2 enchaînements par case (`Run.MAX_CHAIN`) : 12 sorts. Le sort enchaîné part en
  rappuyant après 0,45 s de blocage, dans une barre de 3 s : **+20 % de dégâts**.
  `player.gd:CHAIN_ZONE = Vector2(0.0, 1.0)` : **toute la barre est « bon timing »**, il n'y a pas de
  fenêtre à viser (seul l'appui trop tôt casse la chaîne).
- Sorts jouables : sorts partagés d'emblée, sorts propres 4 au départ puis maîtrise 2, 3, 4, 5, 6, 7,
  8, 10, 12, 14, 16 (`Progression.SKILL_LEVELS`).
- Améliorations de sort : rang 1 → 10, +12 % de dégâts (ou soins, ou durée) et -5 % de recharge par
  carte commune × rareté, bonus d'attribut temporaire dès rare (`Cards.skill_upgrade`).
- Cartes de classe : 2 à 3 par sort pris (Puissance / Ferveur, Cadence, Persistance).
- Presets (`spell_presets.gd`, Grimoire) : rangent les sorts obtenus à leur case, **sans influencer
  ce qui est proposé** (un preset ne rend pas ses sorts plus probables).
- Cases automatiques (Paramètres, `auto_skills`) : déjà codées, utiles pour les buffs.

### 1.4 Armes (`weapon_attacks.gd`)

- 17 types × 2 variantes = **34 auto-attaques** : 15 projectiles, 5 incantations, 14 mêlée
  (taille, estoc, impact, onde). Chaque variante a ses statistiques de prédilection (« Grandit avec »)
  et un **effet légendaire** (« tous les N coups », état à chaque coup, explosion ou foudre à l'impact).
- Améliorations d'arme (`roll_upgrade`, `Run.weapon_ups`) : 8 niveaux par emplacement ; commune
  +15 % de dégâts, rare + un bonus mineur, épique + un bonus majeur, **légendaire = l'effet légendaire**.
- Arme secondaire : 60 % des dégâts, 50 % des stats d'objet, trouvée sur boss (100 %) et élites
  (40 % / 12 %), 3 armes au choix (variante au hasard).
- **La variante de l'arme principale suit le modèle d'Eden** (`variant_index` : hachage de l'id) :
  la variante choisie au départ peut changer au coffre d'arme suivant (la carte l'affiche, mais
  « meilleures stats » et « bonne variante » entrent en conflit).

### 1.5 Cartes de build (`boons.gd`, `cards.gd`, `run.gd:roll_cards`)

- 38 cartes + 11 passifs communs (`classes.json`, recopiés par `GameData._ready`) = **49 cartes**,
  dont **31 libres d'emblée** et 18 à débloquer par records cumulés (`Cards.UNLOCK` : 500 monstres,
  50 esquives, 1 à 5 boss…). Rareté tirée à chaque offre (60 / 27 / 10 / 3 %, ×1 / 1,5 / 2,2 / 3),
  10 niveaux par passif, 4 évolutions légendaires (Seigneur de la tempête, Éclat glacial, Lame du
  phénix, Tempête d'acier). Bannir / Garder 3 fois par run, 1 relance (+ Bonne étoile).
- **Mesure de l'offre** (poids réels de `roll_cards`, 12 sorts pris, arme secondaire portée) :

| Catégorie | Part des cartes proposées |
|---|---|
| Cartes communes de build | 39 % (45 % quand tout est débloqué) |
| Cartes de classe (sorts pris) | 29 à 33 % |
| Améliorations de sort | 19 à 22 % |
| **Améliorations d'arme** | **4 %** |
| Certificats | 3 % |

  Une run de Survie fait **≈ 50 choix de 3 cartes** (34 niveaux avec les plafonds 15/25/35, 18 coffres
  de cartes, gardiens). Résultat :
  - **≈ 5 améliorations d'arme proposées par run** (sur 16 niveaux possibles) ; l'effet légendaire
    demande une carte de rareté légendaire (3 %) : **≈ 1 run sur 7 le voit**. La « signature » de la
    refonte 0.1.128 est donc rare.
  - **Projectile supplémentaire** (la carte qui change le plus l'auto-attaque) : vue au moins une fois
    dans **≈ 40 % des runs** ; Tempête d'acier (elle + Main lourde) est encore plus rare.
  - Une amélioration d'**un** sort précis : 1,7 % par carte. Impossible de construire autour d'un
    sort fétiche.

### 1.6 Trophées (`trophies.gd`, `slot_chests.gd:trophy_offer`)

- 67 effets, chacun porté par ≥ 5 trophées d'Eden (variantes de niveau). Collection de run :
  12 au plus, tous différents, tous actifs, perdus en fin de run. 4 coffres de trophée par map
  = 12 : **la collection est toujours pleine en fin de run** ; chaque coffre propose 3 effets au hasard
  parmi ceux qu'on n'a pas.
- Répartition par thème : tank / PV bas 13, critique 11, esquive et annulation parfaite 11, givre et
  contrôle 10, éliminations 10, foudre 8, sorts 7, **stats « à l'impact » sans recharge 7**,
  auto-attaque 6, effets sur la durée 6, **projectiles 0, saut 0, zone 0, enchaînements 0**.
- Les 7 effets « à l'impact, sans recharge » (Vivacité, Esprit vif, Rage du guerrier, Arcanes, Éveil,
  Instinct du prédateur, Double frappe) se déclenchent par monstre touché : avec une arme de zone en
  horde (≈ 9 impacts/s), un buff de 8 s à 5 % est **actif en permanence** ; contre un boss seul, ≈ 45 %.
- Force selon la rareté du modèle d'Eden retenu (`VALUE_MULT` 0,5 → 1,2) : à niveau égal, deux effets
  peuvent avoir une force qui varie du simple au double sans que le joueur le sache.
- Noms en double avec des cartes ou statuts : Bonne étoile, Arcanes, Frénésie, Concentration, Soif de
  sang, Élan, Braise, Moisson, Séisme, Instinct de survie.

### 1.7 Effets déclenchés (`procs.gd`)

Sain et réutilisable : 9 déclencheurs (impact, impact de sort, critique, élimination, impact
d'auto-attaque, esquive, annulation parfaite, dégâts subis, PV bas), 13 effets, profondeur de chaîne 2.
Les procs frappent sur `max(attaque, attaque magique)` × dégâts (`proc_hit`) et leur rayon suit la
**zone** (`Procs.run`). Doublons exacts entre sources : Pas du vent (carte) = set Vent céleste 4 p ;
Œil du chasseur (carte) = set Œil du faucon 4 p ; Transe guerrière ≈ set Lame sanglante 4 p ;
Second souffle ≈ Dernier rempart ≈ Phénix 4 p.

### 1.8 Certificats, plateau, talents

- **Certificats** : 2 par classe (maîtrise 3 et 8), 120 au total mais **48 effets distincts**, presque
  tous plats : +X % d'attaque (45), défense (18), vitesse d'attaque (10), esquive (10)… Budgets très
  inégaux (Battojutsu +20 % de critique, Gymnaste +8 % de vitesse de déplacement). Frères identiques
  (Psalmiste = Orateur, Lame noire = Lame de lumière, Assassin = Kage). 11 certificats promettent
  « insensible aux renversements des monstres » : **non codé** (seule la stat s'applique).
- **Plateau** (`cert_board.gd`) : 2 à 7 emplacements, bonus de liens, prisme et losange par couleur.
  `CERT_COLOR` ne colore que les 12 certificats des 6 classes faites main : **108 / 120 sont bleus
  par défaut**, le losange bleu est automatique, le prisme quasi impossible.
- **Talents** (`talents.json`) : 18 par classe, 559 effets de stat (surtout dégâts, critique, PV,
  défense) et 522 renforts de sort. Rien pour la zone, les projectiles, les effets sur la durée,
  l'esquive ou le saut.

### 1.9 Sets

- En Survie, les pièces viennent des modèles d'Eden : **sets d'Eden** (326) sur les mythiques et plus,
  bonus **de stats seulement** à 2 / 3 / 5 pièces (souvent +2 à 3 % de dégâts à 2 pièces).
- Les **6 sets de build** du jeu (Tempête, Givre éternel, Lame sanglante, Œil du faucon, Phénix,
  Vent céleste : procs de foudre, gel, esquive…) ne sortent que du générateur de secours
  (`Items.generate`, quand il n'y a pas de modèle d'Eden) : **morts en Survie**.

### 1.10 Maniabilité (« hard to master »)

Saut nerveux, saut-esquive, esquive aérienne, sorts en l'air (+10 %), annulation parfaite (0,28 s
après l'impact d'un sort : esquive gratuite, -25 % de recharge restante, **Fluidité** +10 % par palier,
4 max, 3 s). Bien fait, mais : la Fluidité n'est améliorable par **rien** ; une seule forme de
« parfait » (offensive) ; l'enchaînement n'a pas de fenêtre à viser ; le saut n'a qu'une récompense
offensive (Frappe plongeante). Le jeu automatique (Paramètres) sait faire les annulations parfaites.

### 1.11 Ce qui se débloque, et à quelle condition (builds)

| Élément | Au départ | Se débloque par |
|---|---|---|
| Classes | Guerrier, Voleur, Chasseur, Clerc, Magicien | maîtrise (`Progression.UNLOCKS`) ; orange : maîtrise 8 du parent |
| Sorts | partagés + 4 propres | maîtrise 2 → 16 de la classe |
| Talents | — | 2 points par niveau de maîtrise (40 niveaux), paliers de points dépensés |
| Certificats | — | maîtrise 3 et 8 de chaque classe ; emplacements : 2, +1 par 8 niveaux de maîtrise cumulés (7 max) |
| Cartes communes | 31 / 49 | records cumulés (`Cards.UNLOCK`) ; évolutions : 2 à 5 boss vaincus |
| Variantes d'arme | les 2 de chaque arme | rien (tout est ouvert) |
| Améliorations d'arme, trophées | — | pendant la run uniquement (Survie ; trophées aussi aux sanctuaires) |
| Sets d'Eden | — | pièces mythiques+ des coffres de Survie ; Armurerie après avoir choisi la pièce |

### 1.12 Fini, à moitié fait, mort, incohérent, docs en retard

| État | Quoi |
|---|---|
| Fini et sain | procs, combos d'états (moteur), cartes avec totaux avant → après, bannir / garder, armes à 2 variantes, collection de trophées, presets, cases automatiques |
| À moitié | identité des 54 classes générées (buffs aplatis, soins sans dégâts, peu de synergies) ; plateau de certificats (couleurs) ; améliorations d'arme (trop rares) ; presets (ne servent pas de plan) |
| Mort | les 6 sets de build en Survie ; champ `combo` des classes et de `weapon_types.json` (ancien combo d'auto-attaque) ; `tests/test_combo.gd` (teste le combo supprimé) ; « insensible aux renversements » des certificats |
| Incohérent | 20 classes physique / magique ; cartes dominées (Arcanes < Force brute : même +5 % mais Force brute compte aussi pour la magie ; Précision < Bonne étoile) ; cartes proposées sans effet (Perforation / Ricochet avec une arme de mêlée, Incantation vive et Arcanes pour une classe physique) ; cartes encore proposées au-delà des plafonds (exécution 30 %, recharges 50 %, esquive 20 %) ; variante d'arme qui change au coffre |
| Docs en retard | `DESIGN.md` : « Combos d'auto-attaque », « Classe + arme (builds exotiques) », « Grimoire » (combo coup par coup), « Sets d'équipement » (6 sets), « Expertise… certificats » (1 emplacement, 4 max → plateau de 7), « Cartes de build » (Coup de grâce → Tempête d'acier), table des monnaies (choix de trophée, coffres de récompense « trophée au choix »), « Méta-progression » (12 cartes de base → 31) ; `AUDIT.md` partie 8 (trophée de départ) |

---

## 2. Matrice axes de build × sources

Légende : ●●● bien servi · ●● correct · ● faible · ○ rien. Chiffres = nombre d'éléments.

| Axe | Cartes communes | Armes (variantes, effets légendaires, bonus) | Trophées | Certificats / plateau | Talents | Sets d'Eden (Survie) | Sorts de classe | Bilan |
|---|---|---|---|---|---|---|---|---|
| **Projectiles** (nombre, perforation, rebonds) | 4 (Projectile supp., Perforation, Ricochet, Tempête d'acier) **auto-attaque seulement** | 15 variantes à projectiles, bonus majeurs | ○ | ○ | ○ | ○ | 120 sorts projectiles **non touchés par ces cartes** | ●● auto / ○ sorts |
| **Zone** | 2 (Lame large, Tempête d'acier) | 15 variantes à zone, bonus zone | ○ (les explosions grandissent avec la zone) | 1 + losange bleu | ○ | ○ | 266 tourbillons / zones | ●● |
| **Critique** | 7 | 7 variantes | 11 | 20 + losanges | 115 | ~180 sets | 35 sorts à bonus | ●●● |
| **Effets sur la durée** | 4 | 4 variantes + 7 effets légendaires | 6 (posent, n'amplifient pas) | ○ | ○ | ○ | 69 sorts | ●● (un seul effet par type et par cible, pas de cumul) |
| **Givre / contrôle** | 3 (+ évolution) | 2 | 10 | ○ | ○ | ○ | ~120 sorts | ●● (boss insensibles au gel, insensibilité 3 s) |
| **Foudre en chaîne** | 2 | 5 effets légendaires | 8 | ○ | ○ | ○ | 20 | ●● |
| **Éliminations (horde)** | 5 | 5 effets légendaires « explosion » | 10 | ○ | ○ | ○ | — | ●●● (trop, voir Élan meurtrier) |
| **Esquive / annulation parfaite** | 3 | ○ | 11 | esquive passive seulement | ○ | esquive passive | 29 buffs Évasion | ●● trophées, Fluidité non améliorable |
| **Saut / aérien** | 5 utilitaires, 1 seule fait des dégâts | ○ | ○ | ○ | ○ | ○ | +10 % fixe en l'air | ● |
| **Sorts** (puissance, recharge) | 4 + améliorations de sort (~20 %) + cartes de classe (~30 %) | 6 variantes à incantation | 7 | 6 | 522 | ~60 sets | — | ●●● (axe par défaut) |
| **Auto-attaque** | 8 | 34 variantes + 8 niveaux (≈ 5 proposés par run) | 6 | 10 | 21 | 40 sets | — | ●● (dépend de cartes rares) |
| **Rempart** (PV, défense) | 4 | soin à l'impact (sceptre) | 13 | 28 + losange jaune | ~90 | ~220 sets | 87 Barrière, Mur du titan… | sources ●●●, **récompense ○** (rien ne transforme la défense en dégâts) |
| **Soins** | ○ | 2 (sceptre) | 4 | 1 | 18 | 34 | 84 soins (3 font des dégâts) | ● en solo |
| **Invocations** | ○ | ○ | ○ | ○ | ○ | ○ | ○ (Ingénieur, Dompteur, Dresseur sans familier) | ○ |
| **Enchaînements / Fluidité** | ○ | ○ | ○ | ○ | ○ | ○ | mécanique fixe (+20 %, +10 %/palier) | ○ |

**Lecture** : critique, sorts et éliminations débordent ; projectiles des sorts, saut, rempart offensif,
soins en solo, invocations et enchaînements / Fluidité sont des trous. Les certificats, talents et sets
ne servent que les stats générales (critique, attaque, PV) : la méta ne renforce aucun axe « exotique ».

---

## 3. Problèmes et opportunités (du plus important au moins important)

1. **On ne construit pas un build, on le subit.** ≈ 50 choix de cartes dilués dans un pool
   d'environ 100 entrées : une carte précise sort à 1-4 % par carte, l'arme à 4 %. Des cartes sans
   effet sur le build sont proposées (Perforation au Guerrier à la hache), des cartes sont dominées, et
   les trophées (3 au hasard parmi 67) ne tiennent pas compte de ce qu'on a. *Opportunité* : le moteur
   (poids, bannir, garder, rareté, évolutions) est déjà là ; il manque des **étiquettes d'axe**.
2. **L'arme « qui grandit avec les cartes » grandit peu et de façon inégale.** ≈ 5 améliorations
   d'arme proposées par run, effet légendaire vu 1 run sur 7 ; Projectile supplémentaire multiplie
   l'auto-attaque d'une arme à 1 coup bien plus que celle d'une arme à plusieurs coups (la rareté
   multiplie aussi les projectiles : une carte légendaire = +3 frappes ; Iaï ×4, Rafale d'estocs ×2,
   Mitraille ×1,75) ; la variante peut changer au coffre d'arme.
3. **Les 54 classes générées manquent d'identité jouable.** Familles à 9-10 sorts communs, 36 % de
   buffs aplatis (140 doublons), soins qui ne tuent rien, combos d'états dans 5 classes seulement,
   20 classes à la base physique / magique fausse, certificats plats et parfois identiques entre
   frères. *Opportunité* : le champ `combo` (requires / applies / double / buff) est déjà codé et
   affiché par `spell_info.gd` : il suffit de le donner aux autres lignées.
4. **Builds évidents trop forts / pièges.**
   - *Trop forts* : **Élan meurtrier** (chaque élimination réduit toutes les recharges, sans recharge
     interne : 0,3 s par monstre, 0,7 s dès une carte légendaire ; en horde, les sorts tournent en
     boucle) ; **Projectile supplémentaire** légendaire sur une arme de mêlée à 1 coup ; trophées
     « à l'impact sans recharge » permanents en horde ; **Lame large** (commune, grandit tout :
     auto-attaque, sorts de zone, rayon de tous les procs).
   - *Pièges* : Arcanes, Précision, Incantation vive / Arcanes pour une classe physique, Perforation /
     Ricochet en mêlée, cartes de saut sans récompense, cartes au-delà des plafonds, 2e buff au même
     statut, Exécuteur après 30 %.
5. **Axes orphelins** : projectiles des sorts, saut, rempart offensif, soins en solo, invocations,
   enchaînements / Fluidité (voir matrice).
6. **« Hard to master » peu récompensé par le build.** Enchaînement sans fenêtre à viser, une seule
   forme de parfait, Fluidité fixe, rien pour l'esquive défensive « au dernier moment » alors que
   toutes les attaques de monstres sont annoncées au sol (`telegraph.gd`).
7. **Sets** : les 6 sets de build sont morts en Survie, les sets d'Eden ne donnent que des stats : le
   choix d'une armure n'est jamais un choix de build. *Opportunité* : les bonus des 6 sets existent,
   il suffit de les rattacher aux sets d'Eden des paliers de Survie.
8. **Certificats et plateau** peu lisibles (108 bleus par défaut, insensibilité promise non codée,
   budgets inégaux).
9. **Trophées** : collection toujours pleine (pas de décision « garder la place »), force cachée selon
   la rareté du modèle, noms en double.
10. **Docs et données mortes** (voir 1.12).

---

## 4. Propositions

Les propositions phares sont marquées ★. Coût : S (quelques heures), M (une session), L (plusieurs).

### ★ B1 — Cartes pertinentes, cartes dominées, plafonds visibles (S)

- **Intérêt** : chaque carte proposée sert le build ; plus de carte « morte » ni de piège.
- **Règles** :
  - dans `roll_cards`, poids ×0,15 (ou retrait) d'une carte sans effet sur le build actuel :
    Perforation / Ricochet sans arme à projectiles (principale ou secondaire) ; Incantation vive sans
    arme à incantation ni sort magique ; Arcanes sans sort / arme magique ; Plaies profondes / Venin
    tenace sans source d'effet sur la durée (arme, sort, carte, trophée) ; Exécuteur, Concentration,
    esquive passive une fois le plafond atteint (30 %, 50 %, 20 %) ;
  - fusionner ou relever les cartes dominées : Arcanes → « +8 % d'attaque magique, +5 %
    d'incantation » ; Précision → +4 % ;
  - si une telle carte sort quand même (cartes gardées), mention « sans effet sur ton build » /
    « plafond atteint ».
- **Touche** : `run.gd:roll_cards`, `_describe_card` ; `boons.gd:LIST`.
- **Dépendances** : équilibrage (valeurs), interface (mention sur la carte).

### ★ B2 — Affinités de build : étiquettes d'axe et offres orientées (M)

- **Intérêt** : le joueur **construit** : après 2-3 choix dans un axe, le jeu lui en propose la suite,
  sans supprimer la surprise. Base de tout le reste (évolutions, trophées, sets, collection).
- **Règles** :
  - ~12 axes (Projectiles, Zone, Critique, Durée, Givre, Foudre, Éliminations, Esquive et parfait,
    Aérien, Sorts, Auto-attaque, Rempart) ; chaque carte, trophée, variante d'arme, certificat porte
    1 ou 2 étiquettes (table dans le code, icône d'axe sur la carte) ;
  - **offre de niveau** : si un axe compte ≥ 3 éléments, 1 des 3 cartes est tirée dans cet axe
    (« carte d'affinité ») ; les 2 autres restent libres ;
  - **coffre de trophée** : 1 effet de ton axe principal, 1 d'un axe que tu as un peu, 1 au hasard ;
  - **une évolution par axe** (au moins une légendaire à prérequis par axe, en plus des 4 actuelles :
    p. ex. Volée infinie pour Projectiles, Seigneur du ciel pour Aérien, Danse des lames pour
    Esquive, Forteresse pour Rempart, Pestilence pour Durée) ;
  - résumé du build par axe dans le menu pause et pendant le choix de cartes.
- **Touche** : `boons.gd`, `trophies.gd`, `weapon_attacks.gd` (étiquettes), `run.gd:roll_cards`,
  `slot_chests.gd:trophy_offer`, `ui/card_picker.gd`, `ui/run_page.gd`.
- **Dépendances** : interface (icônes d'axe, résumé), équilibrage (nouvelles évolutions),
  progression (déblocage des évolutions, voir section 7).

### ★ B3 — Une arme qui grandit vraiment (S)

- **Intérêt** : tenir la promesse de la refonte 0.1.127-0.1.128 ; l'effet légendaire de la variante
  devient le moment fort de chaque run.
- **Règles** :
  - améliorations d'arme plus fréquentes : poids 2,2 → ~5 (≈ 9 % des cartes, ~11 propositions par
    run) **et** une amélioration d'arme garantie à la récompense de chaque boss de map ;
  - **effet légendaire acquis au niveau 4** de l'arme (au lieu d'une carte légendaire à 3 %) ; la
    carte légendaire donne ensuite ses bonus habituels ;
  - frappes / projectiles en plus **normalisés par variante** : chaque variante a un gain par
    projectile (`proj_gain`, p. ex. Iaï +60 % par frappe, Rafale +100 % d'une frappe) pour que
    Projectile supplémentaire vaille environ +40 à 60 % pour toutes ;
  - le coffre d'arme garde la **variante actuelle** (`auto_variant`), avec la 2e variante en option
    si le joueur veut changer.
- **Touche** : `run.gd:roll_cards`, `weapon_attacks.gd` (`roll_upgrade`, `action_for`, SPECS),
  `run_director.gd` (boss), `slot_chests.gd:offer`.
- **Dépendances** : équilibrage (courbe de l'auto-attaque, DPS par variante).

### ★ B4 — Signatures de lignée (M ; L si on va jusqu'aux 60 classes)

- **Intérêt** : chaque lignée (parent + 2 classes orange) a un geste à apprendre, qui se voit et qui
  récompense l'ordre des sorts ; les enfants changent ce geste au lieu de recopier le parent.
- **Règles** : pour chacune des 20 lignées, une **marque** (état existant) posée par 2-3 sorts et
  2 sorts « finisseurs » qui la consomment (`combo` existant : `double`, `applies`, `buff` ; ajouter
  2 effets : `explode` et `heal`) ; le certificat de maîtrise 8 de chaque enfant modifie la
  signature. Pistes :

| Lignée | Signature (marque → finisseur) | Variante des enfants |
|---|---|---|
| Guerrier | Renversé → sorts de zone ×1,5 | Berserker : Fureur 2 s ; Protecteur : Barrière 2 s |
| Chevalier | Désarmé → ×1,4 | Exécuteur : exécute les désarmés < 20 % ; Glaciaire : gel |
| Templier | Purgatoire → le soin déclenche une nova sacrée | Aube : nova plus large ; Paladin : renverse |
| Chevalier dragon | Saignement → la lance perce et explose | Âme : vol de vie ; Dragonnier : saut plongeant |
| Samouraï / Voleur | déjà en place | à étendre aux sorts propres des enfants |
| Artiste martial | Renversé → enchaînement ×2 | Asura : Terreur ; Rakshasa : élan gratuit |
| Danseuse de lames | Sommeil → premier coup ×3 | Acrobate : après esquive ; Élégante : sur les buffs |
| Chasseur | Purgatoire → flèches +1 perforation | Dresseur : familier (voir B12) ; Démons : désarme |
| Rôdeur | Terreur → flèches ×1,5 | Flèche absolue : critique ; Flèche sacrée : zone |
| Inquisiteur | Saignement consommé → explosion | Faucheur : vol de vie ; Fusilier : salve |
| Ingénieur | Ralenti → obus ×1,5 | Mecha Arès : renverse ; Annihilateur : brûlure |
| Clerc | surplus de soin → dégâts sacrés | Juge : électrocute ; Équilibriste : Barrière |
| Barde | 3 notes (sorts lancés) → sort suivant ×1,5 ou soin de zone | Poète : dégâts ; Adorateur : soin |
| Sage | Ralenti → marteau ×1,5 | Psalmiste : défense ; Orateur : renverse |
| Chaman | Immobilisé → sorts ×1,5 | Druide : régénération ; Archimage : incantation |
| Magicien | Brûlure + Ralenti → choc thermique (explosion) | Archi-élémentaliste : gel ; Tempêtier : foudre |
| Démoniste | Poison + Terreur → ×2 | Envoyé : propagation ; Conjurateur : explosion |
| Illusionniste | Sommeil → ×3 (réveille) | Dompteur : familier (B12) ; Chronologiste : recharges |
| Luminaire | Désarmé / Terreur → sorts ×1,5 | Lame noire : ombre ; Lame de lumière : soin |

- **Touche** : génération des classes (`tools/build_classes.py`, `auto_spells.py`, session locale) pour
  écrire les `combo` ; `player.gd:_hit_monster` (2 effets de combo en plus) ; `spell_info.gd`,
  grimoire (afficher « pose la marque » / « consomme »).
- **Dépendances** : équilibrage ; interface (grimoire, infobulles) ; modes (les combos agissent-ils
  entre héros en duel ?) ; arène d'IA : aucun ajout d'observation (les nouveaux états ne sont pas
  observés, c'est accepté).

### B5 — Cohérence physique / magique des 20 classes (S)

- **Intérêt** : ces classes font enfin les dégâts prévus ; le sélecteur dit vrai ; les bonus de sort
  donnent le bon attribut.
- **Règles** : `dmg_type` et `base.atk / base.matk` de la classe déduits de la majorité de ses sorts
  d'attaque (règle dans l'outil de génération, ou au chargement dans `GameData._ready`) ; certificats
  de critique magique gardés seulement sur les classes magiques.
- **Touche** : `tools/auto_classes.py` (ou `game_data.gd`), `class_picker.gd`.
- **Dépendances** : équilibrage (profils « opti » du duel à régénérer avec `tools/gen_profiles`) ;
  arène d'IA : `ml_arena.gd:544` observe `base.matk` (la **valeur** change pour ces classes, pas le
  nombre d'observations) → à revérifier avec `IA_Duel.bat`.

### B6 — Buffs et soins jouables en solo (M)

- **Intérêt** : les classes de soutien (≈ 15 classes à plus de 40 % de buffs / soins) deviennent
  agréables en Survie sans perdre leur rôle en équipe plus tard.
- **Règles** :
  - un 2e buff au même statut le **renforce** au lieu de rien (Barrière -40 % → -55 %, Évasion 40 →
    55 %) ou, à défaut, il pèse ×0,3 dans les offres avec la mention « effet déjà couvert » ;
  - **soins offensifs** : un sort de soin inflige aussi une onde sacrée autour du héros (≈ 50 % du
    soin en dégâts magiques, 4 m) ; le surplus de soin devient une Barrière courte ;
  - suggérer les cases automatiques (déjà codées) pour les buffs à longue recharge.
- **Touche** : `player.gd` (application des buffs et des soins), `run.gd:roll_cards`.
- **Dépendances** : équilibrage ; modes (Arènes 2v2/3v3 : soins sur alliés plus tard) ; interface.

### ★ B7 — Maîtrise récompensée (« hard to master ») (M)

- **Intérêt** : la maniabilité impressionnante devient un **axe de build** et un plaisir d'expert,
  sans pénaliser le joueur moyen (tout ce qui marche aujourd'hui marche encore).
- **Règles** :
  - **zone dorée** dans la barre d'enchaînement (≈ 20 % de la barre, position propre à chaque sort) :
    « ENCHAÎNEMENT PARFAIT », +40 % au lieu de +20 % et +1 palier de Fluidité ; le reste de la barre
    garde +20 % ;
  - **esquive parfaite défensive** : esquiver dans les 0,15 s avant qu'une attaque annoncée frappe
    (`telegraph.gd`) → ralenti 0,4 s, déclencheur « perfect » (mêmes procs que l'annulation) ;
  - **Fluidité améliorable** : cartes « Flux » (+1 palier max, +1 s) et trophées « à 4 paliers » ;
  - **aérien** : carte « Maître du ciel » (+15 % en l'air par niveau), Frappe plongeante qui suit
    l'arme, trophée « Atterrissage » (onde à la retombée après un sort aérien).
- **Touche** : `player.gd` (`CHAIN_ZONE`, `_chain_press`, `_start_dodge`, `flow_mult`), `telegraph.gd`,
  `boons.gd`, `trophies.gd`, `hud.gd` (barre).
- **Dépendances** : interface (zone dorée, ralenti lisible) ; équilibrage ; arène d'IA (aucune
  observation ajoutée ; le cerveau garde l'enchaînement à +20 %).

### B8 — Trophées : moins de stats permanentes, plus d'axes (S → M)

- **Règles** : les 7 effets « à l'impact sans recharge » passent à une recharge de 4-6 s ou à « toutes
  les N frappes » ; renommer les doublons ; nouveaux effets pour les axes vides (projectiles :
  « un projectile sur 5 se dédouble » ; aérien ; zone ; enchaînements ; Fluidité) ; afficher la force
  (étoiles de rareté) sur la carte du trophée.
- **Touche** : `trophies.gd`, `tools/rework_trophies.py` (session locale, pour donner des modèles d'Eden
  aux nouveaux effets).
- **Dépendances** : équilibrage ; progression (collection des trophées, section 7).

### B9 — Panoplies de build en Survie (M)

- **Intérêt** : le choix d'une armure devient un choix de build (aujourd'hui seulement des stats).
- **Règles** : les sets d'Eden des paliers de Survie (une trentaine) reçoivent chacun un **archétype**
  repris des 6 sets du jeu (+ 2 nouveaux : Projectiles, Rempart) qui ajoute un proc à 3 et 5 pièces ;
  le nom d'Eden reste, l'archétype s'affiche (« Panoplie du Désert · Givre éternel »).
- **Touche** : `items.gd` (`set_bonus` fusionne l'archétype), table set → archétype, fiche d'objet.
- **Dépendances** : progression (pièces de l'Armurerie → duel), équilibrage, interface.

### B10 — Certificats et plateau lisibles (S)

- **Règles** : couleur de chaque certificat déduite de sa stat (attaque / dégâts = orange, PV / défense
  / soins = jaune, critique / vitesse / esquive / zone / portée = bleu) ; coder l'insensibilité aux
  renversements des monstres (11 certificats) ou retirer le texte ; ramener les certificats à un budget
  comparable ; les deux enfants d'une lignée ont des certificats différents (variante de B4).
- **Touche** : `cert_board.gd:color_of`, `player.gd` (insensibilité), données des classes.
- **Dépendances** : progression (rôle des certificats), équilibrage.

### B11 — Identité affichée et preset = plan de build (S)

- **Règles** : fiche de classe avec 3 étiquettes calculées (mêlée / distance, zone / cible unique,
  sorts / auto-attaque / soutien), axes conseillés et signature (B4) ; **les sorts du preset actif
  pèsent ×2** dans les offres de sort ; un « sort fétiche » marqué dans le Grimoire voit ses
  améliorations peser ×3 ; les sorts propres d'une classe orange pèsent ×1,5 (pour la distinguer de
  son parent).
- **Touche** : `class_picker.gd`, `talents_page.gd`, `grimoire.gd`, `run.gd:roll_cards`.
- **Dépendances** : interface.

### B12 — Projectiles pour les sorts, puis familiers (S, puis L)

- **Règles** : Perforation et Ricochet touchent aussi les sorts à projectiles ; Projectile supplémentaire
  ajoute +1 projectile aux sorts à projectiles toutes les 2 cartes. Plus tard (L, à discuter avec les
  Donjons) : un familier pour Ingénieur (tourelle), Dompteur de démons et Dresseur.
- **Touche** : `player.gd:_cast_skill` ; familiers : nouveau système.
- **Dépendances** : équilibrage ; modes (familiers en Donjon / JcJ).

### B13 — Garde-fous de puissance (S, chiffres à fixer par l'équilibrage)

Règles proposées : Élan meurtrier avec recharge interne (0,2 s) ou plafond de 1 s de recharge rendue
par seconde ; normalisation des frappes en plus (B3) ; recharge des trophées « à l'impact » (B8) ;
Lame large plafonnée à +100 % de rayon ou passée en rare.

### Ordre conseillé

1. B1, B5, B10, B13 (petits correctifs, gros effet de clarté) ;
2. B3 puis B2 (l'arme et les affinités : le cœur du « je construis mon build ») ;
3. B7 (maîtrise) et B4 (signatures), qui demandent la session locale pour les données ;
4. B6, B8, B9, B11, B12.

---

## 5. Questions aux autres équipes

**Progression**
- Les certificats restent-ils une couche méta (plateau) **et** une carte de run (coffre de certificat) ?
  Le doublon brouille leur rôle.
- Peut-on rattacher des déblocages de build à la maîtrise (signature améliorée, 3e variante d'arme,
  emplacement de preset) sans gonfler la puissance en duel ?
- D'accord pour que les évolutions d'axe (B2) se débloquent par des succès (« vaincre le boss d'une
  époque avec 4 cartes Givre ») qui donnent aussi des titres ?

**Équilibrage**
- Pouvez-vous mesurer le DPS des 34 variantes avec 0, 2 et 5 projectiles en plus, et l'effet réel
  d'Élan meurtrier en horde ?
- La correction physique / magique (B5) double presque les dégâts des sorts de 20 classes : faut-il
  compenser ailleurs ?
- Les effets sur la durée ne se cumulent pas (un effet par type et par cible) : est-ce voulu ?
- Quel budget commun pour un certificat (pour ramener les 48 effets à une même valeur) ?

**Interface**
- Place pour une icône d'axe sur les cartes et trophées, un résumé du build par axe pendant le choix
  de cartes, la mention « sans effet sur ton build » ?
- Zone dorée de la barre d'enchaînement et ralenti de l'esquive parfaite : comment les rendre lisibles
  au milieu des hordes ?
- Fiche de classe : étiquettes de style et signature.

**Modes**
- Tour : utilise-t-elle les trophées et les améliorations d'arme comme la Survie ? Si oui, B2 et B3
  s'y appliquent tels quels.
- Les combos d'états (B4) et l'esquive parfaite (B7) doivent-ils agir en duel ?
- Arènes 2v2 / 3v3 : les classes de soutien y trouvent leur vrai rôle ; faut-il des règles de soin sur
  alliés dès maintenant ?
- Donjons : bon endroit pour introduire les familiers (B12) ?

---

## 6. Questions au joueur (l'indispensable)

1. **Identité** : une mécanique signature par **lignée** (20, partagée parent / enfants avec une
   variante par enfant, coût M) te suffit-elle, ou en veux-tu une **par classe** (60, coût L) ?
2. **Buffs** : d'accord pour qu'un 2e buff identique renforce le premier, et pour proposer de lancer
   les buffs automatiquement (option des cases automatiques) ?
3. **Maîtrise** : d'accord pour une **zone dorée** dans la barre d'enchaînement (+40 %) et une
   **esquive parfaite défensive** avec un court ralenti ?
4. **Cartes** : d'accord pour que le jeu évite de proposer les cartes qui n'ont aucun effet sur ton
   build (Perforation avec une hache…) ?

---

## 7. Ajout du joueur : tout collectionner (cartes, passifs, variantes, trophées)

Principe : **débloquer = plus de choix, jamais plus de puissance brute**, et **rien d'indispensable
verrouillé** au départ. Chaque axe garde sa base libre dès la 1re run (aujourd'hui 31 cartes sur 49 :
c'est le bon socle, il ne faut pas en retirer). Point de vigilance : chaque carte débloquée **dilue**
le pool ; sans B1 et B2, collectionner rendrait les runs moins construites. D'où deux outils méta :
les affinités (B2) et un **grimoire des cartes** où l'on peut retirer de l'offre jusqu'à N cartes
débloquées (bannissement permanent, réversible ; S).

| Collection | Départ | Se débloque par | Récompense de collection |
|---|---|---|---|
| **Cartes** (49 → ~65 avec B2, B7, B8) | la base de chaque axe | succès **liés à l'axe** (records déjà suivis : esquives, éliminations, plus gros coup ; à ajouter : annulations et enchaînements parfaits, éliminations en l'air, dégâts sur la durée) | évolution de l'axe débloquée par « vaincre le boss d'une époque avec ≥ 4 cartes de l'axe » ; titre par axe complété ; cadre doré d'une carte prise 25 fois (cosmétique) |
| **Passifs / certificats** (120) | — | maîtrise 3 et 8 de chaque classe (en place) | codex des passifs par famille, titre par famille complète |
| **Variantes d'arme** (34 → 51) | les 2 variantes de chaque arme (ne pas les verrouiller) | une **3e variante « de maître »** par arme : gagner une époque avec cette arme en principale ou secondaire (M-L : 17 auto-attaques à créer) | effet légendaire « maîtrisé » (lueur), titre d'armurier |
| **Trophées** (67 effets, 548 modèles d'Eden) | ~40 effets simples (stats, éléments, éliminations) | les ~27 effets avancés (esquive, parfait, aérien, sorts) entrent dans le pool par succès ou époque gagnée | codex « trophées découverts 0 / 548 » (chaque modèle choisi en run est découvert), titres |
| **Classes au maximum** (60 × maîtrise 40) | 5 classes | maîtrise (en place) | aux maîtrises 20 / 30 / 40 : variante de signature (B4, change le comportement plutôt que les chiffres), emplacement de preset en plus, apparence d'arme ; aucun gain de stat brut (le duel reste juste) |

Ainsi la 1re run a déjà un build par axe, et les runs suivantes ouvrent des **variantes** (évolutions,
3e variante, trophées avancés) que le joueur va chercher en jouant l'axe concerné : la collection
pousse à essayer d'autres builds.

## 8. Ajout du joueur : équilibrage distinct par mode, vu des builds

**Avis : un build ne doit pas marcher pareil partout, mais son identité doit rester la même.**
- **Identité constante** : signature de lignée, variantes d'arme, combos, annulation parfaite agissent de
  la même façon dans tous les modes (le joueur apprend une fois). Seuls les **chiffres** changent, et
  dans **un seul endroit par mode** (comme `pvp_caps.gd` aujourd'hui : un « profil de mode » Survie /
  Tour / Donjon / JcJ avec ses multiplicateurs et plafonds).
- **Ce qui ne vit que dans la run reste dans la run** : cartes, trophées, améliorations d'arme = Survie
  et Tour. En JcJ, le build = équipement de l'Armurerie, 12 sorts, variante d'arme, talents,
  certificats. Conséquence : pour que le JcJ ait de la variété de builds, il faut des **certificats et
  des panoplies avec des effets** (B9, B10), pas seulement +X % d'attaque.
- **Les axes changent de valeur selon le mode, et c'est sain** : éliminations, explosions de cadavres,
  Élan meurtrier, zone = rois de la Survie (hordes), inutiles en duel ; critique, contrôle, esquive
  parfaite, mono-cible = rois du duel et des boss. Il faut le **montrer** (étiquette « horde » /
  « duel » sur les axes) plutôt que l'égaliser.
- **JcJ** : durée de combat voulue plus longue → contrôles raccourcis (l'insensibilité de 3 s existe
  déjà), soins réduits (déjà ×0,35), auto-attaque ×0,7 ; les combos d'états y doublent moins (×1,5 au
  lieu de ×2). Les cerveaux d'IA sont entraînés au niveau 10 sans équipement : tout profil JcJ doit être
  revérifié avec `IA_Duel.bat` (le nombre d'observations, lui, ne change pas).
- **Donjon** (à définir) : boss et élites → privilégier les axes cible unique (dégâts contre élites,
  critique, durée) ; proposer d'y garder les **cartes de run** (Donjon court = mini-Survie) plutôt
  qu'un troisième jeu de règles, avec un profil « boss » (PV ×, pas de horde).
