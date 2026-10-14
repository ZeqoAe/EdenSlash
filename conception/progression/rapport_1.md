# Équipe Progression & déblocages — rapport 1 (jeu 0.1.130)

Périmètre : tout ce qui progresse **entre les runs** et tout ce qui **se débloque**. Le code fait foi ;
chiffres calculés sur les formules du code (les quantités de monstres tués par run sont estimées,
à mesurer par l'équipe Équilibrage). Sont intégrés les ajouts du joueur pendant le tour 1 dont
l'équipe est pilote : **contenu débloqué au fur et à mesure** (P2) et **but final « tout
collectionner » avec succès et titres** (P4), plus notre avis sur le **tutoriel passable** (P2.4).

---

## En bref

**5 constats**
1. **Rien de neuf à viser après l'époque IV.** Une fois les 4 époques finies, la Survie ne donne plus
   que des insignes, de l'expertise et des apparences au hasard. Pas de rang de difficulté, pas de défi.
2. **Les déblocages arrivent presque tous au début.** Les 18 cartes se débloquent en 3 à 5 runs.
   Chaque classe a tous ses sorts entre la maîtrise 3 et 8 (5 à 7 pour 57 classes sur 60), et ses
   2 certificats aux maîtrises 3 et 8. Ensuite, **32 niveaux de maîtrise (9 à 40) ne donnent que
   « +2 points de talent »**. À l'inverse, Forge, Tour, Duel et Armurerie sont tous ouverts dès la
   1re minute : le joueur ne découvre rien au fil du jeu.
3. **Aucun écran ne rassemble les objectifs.** Les conditions sont éparpillées dans des infobulles
   (classes, cartes, emplacements de certificat), les records cumulés ne s'affichent nulle part, et le
   vocabulaire change d'un écran à l'autre (expertise / maîtrise / « points de maîtrise » ;
   héritage / coffre commun).
4. **Chaque activité n'a pas de rôle clair.** L'équipement de l'Armurerie ne sert vraiment qu'à la
   Tour (le seul mode non normalisé) et à l'archive. Le Duel copie ton équipement par défaut. La Tour
   et le Duel ne rapportent rien d'utile au hub (ni fournitures, ni cristaux).
5. **Il y a des pièges et des incohérences.** La réserve de fournitures part en Survie et **se perd
   si le héros tombe**, alors que la forge y est bloquée. L'Armurerie vend des **trophées**
   inutilisables. **108 certificats sur 120 sont « bleus »** par défaut, ce qui vide le plateau de
   son sens. Un même passif peut se poser 3 fois. Le bilan de Survie annonce une « zone » au lieu de
   l'époque.

**Propositions phares** : P1 corrections de cohérence (**S**) · P2 contenu débloqué au fur et à mesure,
« fil d'éveil » (**M**) · P4 succès, titres et suivi de la complétion (**M**) · P5 un rôle par activité,
gains par mode (**M**) · P6 rangs héroïques et étoiles d'époque après l'époque IV (**M**) · P8 fin de
jeu, Panthéon des cerveaux (**L**).

---

## 1. État des lieux

### 1.1 La boucle entre les runs aujourd'hui

```
                 SURVIE (seule « run » jouable, Run.start_survival)
   expertise ─┐   insignes ─┐   pièces choisies ─┐   coffres ramassés ─┐   fournitures (si victoire/extraction)
              ▼             ▼                    ▼                     ▼              ▼
   maîtrise de classe   ARMURERIE  ◄── Profile.seen_gear       menu COFFRES      réserve (stash)
   (talents, sorts,       │ achat                              (forge, joaillier,      │
   certificats, classes)  ▼                                    apparences)             ▼
                     COFFRE COMMUN (vault) ──► FORGE du hub (cristaux) ──► TOUR (préréglage d'équipement)
                          │                                             ──► DUEL (inscription : arme + armure)
                          └──► ARCHIVE (paliers de bonus pour toutes les classes, apparences d'arme)
   TOUR ──► objets → coffre commun, record par difficulté, coffres d'apparence (50/100/150/200), expertise
   DUEL ──► compteurs de victoires seulement      ENTRAÎNEMENT ──► rien
```

En Survie, ce qui donne de la **puissance permanente** au héros (le reste repart de zéro) :
- les talents de la classe jouée et les certificats posés, avec les bonus du plateau (`run.gd:passive_stats`) ;
- les paliers de l'archive (`player.gd:252`, `Archive.bonus`) ;
- l'aura portée (`player.gd:255`, `Profile.aura_stats`, +3 à +8 % d'un attribut).

### 1.2 Inventaire : tout ce qui se débloque (point des systèmes pour le joueur)

#### A. Classes, sorts, maîtrise, talents, certificats

| Élément | Comment / condition | Où c'est codé | Visible ? |
|---|---|---|---|
| **5 classes de base** (Guerrier, Voleur, Chasseur, Clerc, Magicien) | jouables d'emblée | `progression.gd:START_CLASSES` | oui |
| **15 classes vertes** | par la maîtrise d'autres classes. Chevalier = Guerrier 3 ; Samouraï = Guerrier 3 **et** Voleur 3 ; Inquisiteur = Chasseur 3 ; Barde = Clerc 3 ; Luminaire = Magicien 3 et Voleur 3 ; Chevalier dragon, Artiste martial, Ingénieur, Sage, Illusionniste = une des 2 classes précédentes de la famille au niveau 5 ; Templier, Danseuse de lames, Rôdeur, Chaman, Démoniste = une des 3 précédentes au niveau 7 | `progression.gd:UNLOCKS`, `check_missions` (appelé à chaque gain de niveau) | oui : sélecteur de classe (🔒 + « Maîtrise X 3 — 1 / 3 »), message en run, bilan |
| **40 classes orange** (éveillées) | maîtrise **8** de leur classe verte (2 par classe verte) | `classes.json` → `unlock`, `Progression.requirement` | oui (idem) |
| **Maîtrise** (« expertise » dans le code) | 40 niveaux. Coût du niveau n : 120 + 80 × n points. Gain en Survie : niveau max × 15 + monstres ÷ 2 + élites × 10 + 200 (victoire) ou 60 (extraction) + 120 par étape franchie. Gain en Tour : (étages gravis × 12 + monstres ÷ 3) × 0,75 / 1 / 1,3 / 1,6 | `profile.gd:expertise_need`, `add_expertise` ; `run.gd:finish` ; `tower.gd:finish` | oui : barre au lobby, parcours de maîtrise, bilan |
| **Sorts de la classe** | les 4 premiers sorts propres d'emblée, puis un par niveau de maîtrise 2, 3, 4… ; les sorts partagés (famille, classe parente : 5 à 10) d'emblée. Les classes ont 6 à 11 sorts propres, donc **le dernier arrive à la maîtrise 5 à 7** (8 au plus) : les paliers 10, 12, 14, 16 de `SKILL_LEVELS` ne servent jamais | `progression.gd:skill_level`, `skill_unlocked` ; filtre du tirage `run.gd:roll_cards` | oui : page Classe (🔒 « maîtrise N »), parcours de maîtrise |
| **Points de talent** | 2 par niveau de maîtrise (80 au niveau 40) ; arbre d'Eden de 18 talents, **164 à 240 points pour tout remplir** (l'arbre ne se remplit jamais) ; paliers 15/20/25/30/35 points ; réinitialisation gratuite | `profile.gd:talent_points`, `talent_block` ; `data/talents.json` | oui |
| **Certificats** (2 passifs d'Eden par classe, 120 en tout) | maîtrise **3** (1er) et **8** (2e) de leur classe, utilisables par toutes les classes ; posé sur le plateau, il est acquis au départ ; non posé, il peut tomber en run (cartes, coffre de certificat), y compris ceux de la classe jouée pas encore débloqués | `profile.gd:CERT_LEVELS`, `unlocked_certificates` ; `run.gd:certificate_pool` | oui, page Classe (liste : débloqués + ceux de la classe affichée) |
| **Emplacements du plateau** | 2, puis +1 par tranche de 8 niveaux de maîtrise cumulés sur toutes les classes (7 au plus, donc 40 niveaux cumulés) | `profile.gd:certificate_slots`, `cert_board.gd:OPEN_ORDER` | à moitié : seulement dans l'infobulle du compteur |
| **Bonus du plateau** (couleurs reliées, prisme, losange) | placement ; couleur par certificat | `cert_board.gd` | oui, mais **12 certificats seulement ont une couleur** (`CERT_COLOR`), les 108 autres sont bleus par défaut (`color_of`) |

#### B. Cartes

| Élément | Condition | Où | Visible ? |
|---|---|---|---|
| 20 cartes communes de `Boons.LIST` + 11 passifs communs | d'emblée | `boons.gd:all` | Héros > Cartes |
| **18 cartes à débloquer** | records cumulés : 500 / 1 000 / 2 500 monstres ; 10 / 25 élites ; 1 à 5 boss ; 5 coffres ; 5 sanctuaires ; niveau 12 en run ; un coup de 1 500 / 4 000 ; 50 / 150 esquives ; 5 000 PV soignés | `cards.gd:UNLOCK`, `card_unlocked` ; records `profile.gd:record_add` | oui : Héros > Cartes (🔒 et avancement), bilan « Carte : … » |
| Cartes de sort de classe (puissance, cadence, persistance) | sortent seulement pour un sort pris | `cards.gd:class_cards` | en run |
| Bannir / Garder | 3 fois chacun par run, sans méta | `cards.gd:BANS_PER_RUN` | en run |

Avec 3 boss par run de Survie gagnée et ~1 000 monstres par carte, **tout est débloqué en 3 à 5 runs**.
Le joueur, à l'époque II, a probablement déjà presque tout.

#### C. Activités, époques, Tour, zones

| Élément | Condition | Où | Visible ? |
|---|---|---|---|
| Survie, Tour, Duel, Zone d'entraînement | **ouvertes d'emblée** | `activities.gd:LIST`, `lobby.gd:_show_menu` | oui |
| Donjons, Arènes 2v2 / 3v3, Champ de bataille | « Bientôt », pas jouables | `activities.gd` (`soon`) | oui |
| **Époques I → IV** (Survie) | battre le boss de la 3e map de l'époque précédente (`records.epochs_cleared`) | `epochs.gd:unlocked`, `clear` ; `run_director.gd:_on_boss_killed` | oui : page Survie (« Verrouillée : termine l'Époque I ») ; le bilan ne le dit pas |
| **Zones** (8) | vestige : `unlocked_zones` monte encore aux boss, mais la Survie choisit ses zones par époque | `profile.gd:unlock_after`, `zone_unlocked` | le cadre « zone » du lobby affiche « zone 3 / 8 · 3 débloquée(s) » ; choisir l'époque II ne change pas le décor tant que Wetlands n'est pas « débloquée » (`lobby.gd:_select_zone`) |
| **Étages de la Tour** (200 × 4 difficultés) | étage battu + 1 ; record par difficulté ; les 4 difficultés ouvertes d'emblée | `tower.gd:unlocked`, `best` | oui (page des étages) |
| Coffres d'apparence de la Tour | étages 50 / 100 / 150 / 200, une fois par difficulté (16 en tout) | `tower.gd:LOOK_FLOORS`, `finish` | **non annoncés à l'avance**, seulement au bilan |

#### D. Équipement du hub : Armurerie, coffre commun, forge, archive

| Élément | Condition | Où | Visible ? |
|---|---|---|---|
| **Armurerie** (Collection > Armurerie) | une pièce choisie au moins une fois dans un coffre d'emplacement de Survie (aussi arme secondaire et **trophées**, via `run.gd:add_trophy` → `seen_items`) devient achetable. Prix en insignes : mythique 30 + niveau, légendaire 80 + 2 × niveau, éveillée 250 | `run.gd:finish` → `Profile.seen_gear` ; `gear_shop_page.gd:price` | oui |
| Coffre commun (vault, 3 préréglages par classe) | Armurerie, objets de la Tour, coffres « équipement » / « set » (de l'autel de la fortune seulement, en Survie) | `profile.gd` | oui |
| Forge du hub (fortifier, réforger, polir, percer, sertir, enchanter, fusionner) | toujours ouverte ; payée en cristaux hors run (1 cristal = 25 or) et en fournitures de la réserve | `forge.gd:price`, `inventory_page.gd:_lobby_forge` | oui |
| **Archive** (mythiques et légendaires d'Eden) | déposer l'objet (il quitte le coffre, on peut le retirer). Paliers à 10 / 25 / 50 / 100 / 200 / 400 / 800 / 1 500 objets : au total +8 % PV, +10 % dégâts, +2 % critique, +4 % vitesse d'attaque, +5 % recharge, **actifs aussi en Survie** ; arme archivée = son apparence | `archive.gd:MILESTONES`, `skins` ; `profile.gd:archive_item` | oui (Collection) |

#### E. Coffres de récompense (menu Coffres)

| Type | Source aujourd'hui | Contenu |
|---|---|---|
| Forge (60 %) / Joaillier (40 %) | Survie : boss (100 %), élites (20 %), monstres (0,5 %), stèles du défi. Les types « équipement » et « set » sont convertis en forge ou joaillier en Survie (`run_director.gd:_drop_reward_chest`) | fournitures (réserve), cristaux 3 à 6 + niveau ÷ 10 |
| Équipement, Set | **seulement l'autel de la fortune** (étages 5 à 8) en Survie ; le mode dev | mythique / légendaire → coffre commun |
| Apparence (commun, rare, mythique, légendaire) | chaque boss de Survie (qualité = époque − 1, +1 au boss final, +1 une fois sur 5) ; Tour (paliers) | une apparence jamais obtenue, sinon 30 cristaux |
| Trophées | plus aucune source (0.1.130) | — |

Un coffre ramassé est **toujours gardé** : `run.gd:pick_up` le range tout de suite, même si le héros
tombe. Le texte de la page Coffres (« Gardés si tu t'en sors ») est faux.

#### F. Apparences

| Élément | Source | Où |
|---|---|---|
| Tenues, têtes, dos, apparences d'arme, auras (3 182 portables dans la collection d'Eden) | coffres d'apparence (boss de Survie, Tour), sommet de l'autel de la fortune (1 chance sur 8, une dorée) ; le « trésor de boss » à 25 % ne tombe plus (`if not Run.survival`, et la Survie est la seule run) | `rewards.gd:roll_look`, `fortune.gd:summit_look`, `profile.gd:collect` |
| Apparences d'arme de base, teintures, teinte d'aura | libres | `archive.gd:skins`, `hero_pages.gd` |
| Apparence d'une arme archivée | archiver l'arme | `archive.gd:skins` |

#### G. Duel, cerveaux d'IA, records

- **Duel** : inscription si le preset de sorts a ses 4 cases remplies, que tous les points de talent
  sont dépensés, les certificats posés, l'arme et les 5 pièces d'armure équipées et une tenue portée
  (`duel.gd:requirements`). Rien n'est gagné à part les compteurs `duel_wins` et
  `duel_win_<classe>_<difficulté>`, affichés seulement pour l'adversaire choisi.
- **Cerveaux d'IA** (Débutant → Hardcore, « Le plus récent ») : un simple choix dans le menu Duel,
  **sans condition ni récompense**. Les fichiers (2 Mo chacun, `game/data/cerveaux/`) sont **hors git**.
- **Records** (`Profile.records`) : kills, elite_kills, boss_kills, chests, shrines, dodges, healed,
  best_hit, best_combo, breakables, duel_*, tower_best*, epochs_cleared. **Aucune page ne les montre.**
  Les records gagnés pendant la Tour ou un Duel sont **perdus** au rechargement de la sauvegarde
  (`tower.gd:finish` → `load_profile`).

### 1.3 Ce qui reste d'une run à l'autre

| Mode, issue | Gardé |
|---|---|
| Survie, victoire | expertise, insignes (avec le bonus 60 × époque), pièces vues, fournitures du sac → réserve, coffres ramassés, époque suivante |
| Survie, extraction | idem sans le bonus de victoire (expertise +60 au lieu de +200) |
| Survie, défaite ou abandon | expertise, insignes (sans le bonus), pièces vues, coffres ramassés. **Le sac est perdu, et avec lui la réserve du hub emportée au départ** (`profile.gd:begin_run` : `bag = stash ; stash = {}`) |
| Tour (gagnée ou perdue) | objets des coffres d'étage → coffre commun, record, coffres d'apparence de palier, expertise ; les records de monstres sont perdus |
| Duel | compteur de victoires |
| Entraînement | rien |

L'or est perdu en fin de run, mais il s'échange en run contre des fournitures chez les marchands
(`merchant_ui.gd:roll_offers`), qui rejoignent la réserve en cas de victoire. C'est la seule
conversion de l'or vers le hub.

### 1.4 Monnaies et ressources gardées : sources et puits

| Ressource | Sources | Puits | Remarque |
|---|---|---|---|
| **Insignes** | fin de Survie : 25 × étape + monstres ÷ 25 + élites × 2 + 60 × époque (victoire) | Armurerie seulement | ~70 (défaite à l'étape 1) à ~270 (époque I gagnée), ~480 (époque IV gagnée) ; une fois les pièces voulues achetées, **plus rien à acheter** |
| **Cristaux** | démontage (mythique 7, légendaire 8), coffres de forge (3 à 12), apparence en double (30) | forge du hub : fortifier (1 cristal = 25 or), réforger, polir, fusionner | **+0 → +10 d'une pièce sans échec : ~1 000 cristaux (puissance 20), ~2 100 (45), ~4 000 (90)**, contre quelques dizaines par run |
| **Fournitures** (ciseaux, parchemins de puissance / garde, pierres, gemmes, parchemins d'enchantement, parchemin béni) | sac de Survie (butin, marchands, autel du scribe), coffres de forge et du joaillier | forge du hub | inutilisables en Survie (forge bloquée), perdues en cas de défaite (voir 1.3) |
| **Expertise** | Survie, Tour | maîtrise | voir 1.5 |
| Or, clés | run | run | perdus en fin de run |

### 1.5 Chiffres clés (formules du code)

Points de maîtrise cumulés nécessaires, et nombre de runs pour les obtenir. Hypothèses : ~900 points
par run moyenne et ~2 400 par époque gagnée (35 × 15 + ~2 000 monstres ÷ 2 + ~40 élites × 10 + 200 + 240).

| Maîtrise | Points cumulés | Runs à 900 | Runs à 2 400 | Ce qui arrive |
|---|---|---|---|---|
| 3 | 480 | 0,5 | 0,2 | 1er certificat, classes vertes de rang 1 |
| 5 | 1 280 | 1,4 | 0,5 | classes vertes de rang 2 ; dernier sort pour 27 classes |
| 7 | 2 400 | 2,7 | 1,0 | dernier sort pour 17 classes ; classes de rang 3 |
| 8 | 3 080 | 3,4 | 1,3 | 2e certificat, 2 classes orange |
| 20 | 17 480 | 19 | 7 | (rien de spécial) |
| 40 | 67 080 | 75 | 28 | maîtrise maximale |

- **Débloquer les 60 classes** (maîtrise 8 sur les 20 vertes) : ~61 600 points, soit **26 à 68 runs**.
- **Les 120 certificats** (maîtrise 8 sur les 60 classes) : ~185 000 points, soit ~77 runs gagnées (~45 h).
- **Toutes les classes à la maîtrise 40** : 60 × 67 080 ≈ **4 millions de points, soit ~1 700 runs
  gagnées (~1 000 h)**. À la maîtrise 20 : ~440 runs.
- **Armurerie** : une classe peut voir ~976 pièces différentes (12 maps × 7 types de coffre ; ~1 731
  pièces en comptant les 17 types d'arme). Tout acheter coûte ~328 000 insignes, soit **~1 100 runs
  gagnées**. Par run, on voit jusqu'à ~60 pièces (20 coffres d'équipement par map) mais on n'en achète
  que 2 à 5. 754 des pièces atteignables appartiennent à 154 panoplies d'Eden.
- **Apparences** : 3 182 portables ; une run gagnée en donne 3 (une par boss), la Tour 16 en tout.
  Tout collecter demande **plus de 1 000 runs**.
- **Archive** : 3 656 entrées mythiques et légendaires ; le dernier palier demande 1 500 objets archivés.

### 1.6 Fini, à moitié fait, mort, incohérent, docs obsolètes

**Fini et sain** : déblocage des classes par la maîtrise ; parcours de maîtrise (jusqu'au niveau 8) ;
époques ; étages de la Tour ; Armurerie (le principe) ; coffres d'apparence ; cartes à débloquer avec
leur page ; coffres jamais perdus.

**À moitié fait**
- Maîtrise 9 → 40 : rien d'autre que des points de talent (`progression.gd:last_reward_level` vaut 8).
- Le plateau des certificats : couleurs absentes pour 108 certificats sur 120 (`cert_board.gd:CERT_COLOR`).
- Coffres du joueur par mode (idées du 14/10) : Survie partiellement (fournitures dans le sac,
  coffres de forge et de joaillier) ; Tour et Donjons pas faits.
- Fin de jeu avec les cerveaux : rien.

**Mort (code ou données jamais atteints par le joueur)**
- La run « héritage » : `profile.gd:end_run(item)` (garder un objet), `end_run_extract()` (tout
  garder), l'écran de choix de `results_screen.gd`. La Survie est la seule run, et elle prend toujours
  la branche `end_run_survival`.
- `starter_trophy`, `Run.chests_found`, `unlocked_zones` / `selected_zone` comme progression,
  les paliers 10 à 16 de `SKILL_LEVELS`.
- Le trésor de collection sur les boss (`run_director.gd:623`, jamais en Survie).
- Les coffres de récompense « trophées ».

**Incohérent ou bogué**
1. La réserve du hub part en Survie et se perd à la défaite, alors que la forge y est bloquée
   (`profile.gd:begin_run`, `inventory_page.gd:_on_upgrade`).
2. L'Armurerie liste et vend des **trophées** (inutiles depuis 0.1.130). `owned()` ignore les objets
   archivés : une pièce archivée redevient achetable.
3. Un même passif peut être posé 3 fois sur le plateau via 3 classes : 20 passifs sont communs à une
   classe verte et ses 2 orange (ex. « Rythme entraînant », vitesse d'attaque +5 %, chez Barde, Poète du
   champ de bataille, Adorateur de la vie). Les effets s'additionnent (`run.gd:passive_stats`).
4. Le bilan de Survie affiche « Nouvelle zone débloquée : Beluga Bay » (vestige) mais **pas** l'époque
   débloquée. Il ne dit pas non plus que la réserve emportée est perdue.
5. L'autel de la fortune donne des coffres d'équipement et de set : c'est la seule voie par laquelle un
   objet mythique ou légendaire sort de la Survie, en contradiction avec « l'équipement de la run n'est
   pas gardé ».
6. L'Armurerie se présente comme utile au « JcJ non normalisé », mais ce JcJ n'existe pas : le Duel est
   normalisé (`PvpCaps`) et copie ton équipement par défaut (`Duel.gear_mode = GEAR_COPY`).
7. Les conditions du Duel parlent de « points de maîtrise » pour les points de talent ; le pied de page
   du lobby parle d'« héritage », l'Armurerie de « coffre commun ».

**Docs obsolètes**
- `DESIGN.md`, « Expertise, talents et certificats » : « 1 emplacement, +1 tous les 10 niveaux, 4 max »
  et « ils ne sortent plus en cartes ». Le code donne 2 emplacements +1 tous les 8 niveaux cumulés, 7 au
  plus, un plateau à couleurs et des certificats en cartes et en coffres. La formule d'expertise omet
  +120 par étape et +60 pour l'extraction.
- `DESIGN.md`, « Monnaies, coffres et zones » : tableau d'avant la Survie (coffres de récompense « seule
  source des mythiques », trophées « gardés comme tout objet »…).
- `DESIGN.md`, « Roguelite : héritage » et « Extraction » : n'existent plus.
- `DESIGN.md`, « Boucle de jeu et Survie » : « les armes sont de tous les types, changer d'arme change
  le combo » (faux depuis 0.1.128).
- `DESIGN.md`, « Méta-progression des cartes » : « 12 disponibles, 18 à débloquer » (aujourd'hui 20 + 11
  passifs communs, et 18 à débloquer).
- `AUDIT.md`, partie 1 : « 8 zones à débloquer dans l'ordre » (aujourd'hui des époques).
- Dans le code et l'interface : en-tête de `profile.gd` (héritage), en-tête de `rewards.gd` (« seule
  source des mythiques », trophées), `Archive.source_text` (boss 1 sur 4, marchands), `InfoPage._gear`
  (« archive : +1 / +2 / +4 attributs par entrée »), texte de `chests_page.gd`, description de la Tour
  dans `activities.gd` (« avec une arme de base » : elle part avec le préréglage d'équipement).

---

## 2. Problèmes et opportunités (du plus important au moins important)

1. **Pas de boucle long terme après l'époque IV.** Pas de difficulté au-delà, pas de défi, pas de
   récompense nouvelle. Les seuls objectifs restants sont lents et peu lisibles : maîtriser 60 classes,
   collection au hasard, Armurerie hors d'atteinte. → P6, P8, P4.
2. **Rythme de découverte absent** (demande du joueur) : tout est ouvert dès la 1re minute et les
   déblocages s'épuisent tôt (cartes en 3 à 5 runs, sorts et certificats avant la maîtrise 8), puis le
   vide. → P2, P7, P4.
3. **Lisibilité des objectifs** : pas d'écran « où j'en suis, que viser », records invisibles,
   vocabulaire flottant, conditions cachées dans des infobulles. → P3.
4. **« Tout collectionner » n'est ni atteignable ni suivi** : maîtrise 40 × 60 ≈ 1 000 h ; Armurerie
   ~1 100 runs ; apparences > 1 000 runs ; tout améliorer à +10 se compte en millions de cristaux ; aucun
   pourcentage de complétion, aucun succès, aucun titre. → P4.
5. **Rôle flou des activités et de l'équipement du hub** : la Tour est le seul vrai débouché du stuff, le
   Duel copie le stuff, et ni la Tour ni le Duel ne nourrissent le hub. L'idée du joueur (un type de gain
   par mode) structure tout. → P5.
6. **Pièges et bugs de la méta** (réserve perdue, trophées à l'Armurerie, certificats bleus, doublons de
   passifs, bilan trompeur, records de la Tour perdus). Petits à corriger, gênants au ressenti. → P1.
7. **Monnaies** : les insignes n'ont qu'un puits, les cristaux sont trop rares pour le coût du hub, et
   l'autel de la fortune fait fuir de l'équipement de la Survie. → P9, P5, question au joueur.
8. **Fin de jeu avec les cerveaux** : voulue par le joueur, rien n'existe. Les cerveaux sont en libre
   accès, sans enjeu, et leurs fichiers sont hors git. → P8.
9. **Vestiges et docs obsolètes** : héritage, zones, trésors de boss, textes faux. → P1.

---

## 3. Propositions

### P1 — Corrections de cohérence de la méta (coût S)

**Intérêt** : supprimer les pièges et les textes faux avant de construire dessus.

**Règles**
- a. **La réserve reste au hub** quand on part en Survie : le sac de Survie part vide, et rejoint la
  réserve en cas de victoire ou d'extraction, comme aujourd'hui (`profile.gd:begin_run`). Le bilan dit
  clairement « fournitures de la run : gardées / perdues ».
- b. **Armurerie** : ne plus enregistrer les trophées dans `seen_gear`, ou bien les ranger dans une
  « vitrine des trophées » séparée, réservée à l'archive (à trancher avec Builds) ; `owned()` tient
  compte de l'archive.
- c. **Couleur des 120 certificats** donnée automatiquement d'après le passif : dégâts et attaque →
  orange (puissance) ; PV, défense, parade, soins → jaune (vigueur) ; critique, vitesses, esquive,
  portée → bleu (précision). Prisme et losanges redeviennent de vrais choix.
- d. **Un passif ne se pose qu'une fois** sur le plateau, même s'il est le certificat de 3 classes ; il
  ne retombe pas non plus en run s'il est posé.
- e. **Bilan de Survie** : « Époque II débloquée ! » à la place de la zone ; insignes ; pièces
  découvertes (sans les trophées) ; fournitures gardées ou perdues.
- f. **Vestiges** : retirer la branche héritage de `results_screen.gd` et de `profile.gd` (ou la mettre
  de côté pour les Donjons s'ils en ont besoin), le cadre « zone 3 / 8 » du lobby (le remplacer par
  l'époque choisie), `starter_trophy`, `chests_found`, les textes faux de 1.6, et mettre `DESIGN.md` à jour.
- g. **Records de la Tour et du Duel** : les rajouter après le rechargement de la sauvegarde
  (`tower.gd:finish`, `duel.gd:finish`), pour qu'ils comptent pour les cartes et les succès (P4).

**Touche** : `profile.gd`, `run.gd`, `gear_shop_page.gd`, `cert_board.gd`, `results_screen.gd`,
`chests_page.gd`, `archive.gd`, `info_page.gd`, `activities.gd`, `lobby.gd`, `tower.gd`, `duel.gd`,
`DESIGN.md`. **Dépendances** : Builds (c, d, trophées en b), Interface (e, f).

### P2 — Contenu débloqué au fur et à mesure : le « fil d'éveil » (pilote, coût M)

**Intérêt** : le joueur découvre le jeu par étapes. Chaque ouverture est un petit événement avec son
explication, au lieu d'un hub plein dès la 1re minute. On ne bloque rien d'intéressant longtemps : tout
s'ouvre dans les 5 à 10 premières runs, sauf la fin de jeu.

**2.1 Ordre proposé** (conditions tirées de choses qui existent déjà)

| # | S'ouvre | Condition | Pourquoi là |
|---|---|---|---|
| 0 | Survie (époque I), Zone d'entraînement, Héros (équipement, apparence, grimoire), Paramètres ; les 5 classes de base | nouvelle partie | le cœur du jeu |
| 1 | Page Classe : talents et parcours de maîtrise | 1er niveau de maîtrise gagné (fin de la 1re run, ~200 points) | les premiers points arrivent |
| 2 | Héros > Cartes (cartes à débloquer) | fin de la 1re run, ou 1re carte débloquée | les exploits commencent à compter |
| 3 | Menu Coffres, Collection (apparences) | 1er coffre ramassé (le 1er boss de Survie donne un coffre d'apparence) | il y a quelque chose à ouvrir |
| 4 | **Armurerie** | 1re run de Survie terminée avec au moins une pièce découverte | les insignes arrivent |
| 5 | Plateau des certificats | 1er certificat débloqué (maîtrise 3 d'une classe) | il y a quelque chose à poser |
| 6 | **Forge du hub** (fortifier, gemmes, enchantements, réforge, polissage) et réserve de fournitures | **Époque I terminée** et au moins une pièce dans le coffre commun | elle n'a de sens qu'avec du stuff gardé |
| 7 | **La Tour** (Facile, Normal) | Époque I terminée | 1er débouché du stuff de l'Armurerie |
| 8 | Tour Difficile, puis Hardcore | 50 étages en Normal, puis 50 en Difficile | marches de difficulté |
| 9 | **Duel** | 3 duellistes battus dans la Tour (les étages 1, 4 et 7 sont des duels) | on apprend le 1 contre 1 dans la Tour |
| 10 | **Donjons** (à venir) | Époque II terminée | source de pièces ciblées (P5) |
| 11 | Rangs héroïques de Survie | Époque IV terminée | P6 |
| 12 | **Panthéon des cerveaux** | Duel gagné contre l'IA scriptée Hardcore, ou étage 100 de la Tour | P8, fin de jeu |
| 13 | Arènes 2v2 / 3v3, Champ de bataille | à fixer avec Modes (ex. 10 duels gagnés) | — |

Les classes vertes et orange gardent leurs règles de maîtrise.

**2.2 Comment le joueur le voit**
- Ce qui est verrouillé **reste visible** (activité grisée avec un cadenas et sa condition, comme les
  époques) : c'est un objectif, pas un mystère.
- À l'ouverture, une **fenêtre « Nouveau : la Forge »** au retour au lobby : une image, 3 lignes, un
  bouton « Voir ». Une pastille « Nouveau » reste sur le menu jusqu'à la première visite.
- La liste complète, avec les conditions et l'avancement, est dans le **Carnet de progression** (P3).

**2.3 Règles techniques**
- Une seule table `core/unlocks.gd` : identifiant, condition (record, époque, étage…), texte, page,
  chapitre de tutoriel. `Profile.seen_unlocks` mémorise les pastilles vues.
- **Sauvegardes existantes** : au chargement, tout ce dont la condition est déjà remplie s'ouvre sans
  fenêtre (le joueur, à l'époque II, garde Forge, Tour, Armurerie et Duel). On ne reverrouille jamais rien.
- Le mode dev ignore les verrous.

**2.4 Avis sur le tutoriel passable** (pilote : Interface). Ce fil d'éveil donne au tutoriel ses moments
naturels. Plutôt qu'un long tutoriel d'entrée, nous proposons :
- au début, un **tutoriel de run court** (déplacement, esquive, saut, auto-attaque, cartes, coffres
  d'emplacement), passable d'un clic ;
- une **fiche par ouverture** (enchaînements quand les 4 cases sont pleines, enclume, Forge, Tour,
  Duel…) ;
- « Passer tous les tutoriels » dès le premier écran. Passer le tutoriel **n'ouvre pas** le contenu : il
  coupe seulement les explications ;
- toutes les fiches relisibles dans l'Aide (F1).

**Touche** : nouveau `core/unlocks.gd`, `profile.gd`, `lobby.gd`, `activities.gd`, `tower.gd`
(difficultés), `results_screen.gd`. **Dépendances** : Interface (présentation, pastilles, tutoriel),
Modes (conditions de la Tour, du Duel, des Donjons, des arènes), Équilibrage (marches de la Tour).

### P3 — Carnet de progression et un seul vocabulaire (coût M)

**Intérêt** : un seul endroit pour « où j'en suis, que viser ». C'est aussi l'écran « point des
systèmes » que le joueur demande.

**Règles**
- Nouvelle entrée du lobby (ou onglet de Collection, à voir avec Interface) avec ces onglets :
  - **Objectifs** : les 3 à 5 déblocages les plus proches, calculés (« Chevalier : Guerrier 2 / 3 »,
    « Carte Écho : 3 / 5 sanctuaires », « Époque III : battre le boss d'Arid ») ;
  - **Déblocages** : le fil d'éveil (P2) ;
  - **Classes** : l'arbre des 60 classes par famille, avec maîtrise et condition ;
  - **Cartes et certificats** ;
  - **Succès et titres** (P4) ;
  - **Statistiques** : les records cumulés, enfin visibles.
- Tout repose sur l'existant (`Progression.mission_progress`, `Cards.unlock_progress`, `Epochs.unlocked`,
  `Tower.best`, `Archive.rate`).
- **Vocabulaire** : « **maîtrise** » partout (points de maîtrise = l'expertise, niveau de maîtrise) ;
  « **points de talent** » (aussi dans les conditions du Duel) ; « **coffre commun** » (plus
  « héritage ») ; « **insignes** » affichés au lobby à côté des cristaux.

**Touche** : nouvelle page UI, `lobby.gd`, `duel.gd:requirements` (textes), `results_screen.gd`.
**Dépendances** : Interface (placement, maquette).

### P4 — Succès, titres et suivi de la complétion (pilote, coût M)

**Intérêt** : donner au but « tout collectionner » une forme visible et atteignable par paliers, et des
titres à montrer.

**4.1 Succès**
- Une table de données d'environ 100 succès en 7 catégories. Chaque succès a un nom, une condition
  (presque toutes sur `Profile.records`, qui existent déjà) et une récompense (titre, apparence, insignes,
  cadre de badge).

| Catégorie | Exemples de succès (seuils à régler avec Équilibrage) |
|---|---|
| Aventure | gagner l'époque I… IV ; époque gagnée sans résurrection ; 3 étoiles sur une époque (P6) ; rang héroïque 5 / 10 |
| Combat | 10 000 / 100 000 monstres ; 100 boss ; un coup de 50 000 ; dégâts cumulés record ; 1 000 esquives |
| Classes | débloquer 10 / 30 / 60 classes ; une classe à la maîtrise 20 / 40 ; gagner une époque avec chaque famille |
| Collection | 50 / 200 / 1 000 apparences ; paliers d'archive ; une panoplie d'Eden complète ; une panoplie entière à +10 |
| Tour | étage 50 / 100 / 200 par difficulté ; 20 duellistes battus sans être touché |
| Duel et Panthéon | 10 / 100 duels gagnés ; battre chaque cerveau ; battre le cerveau Hardcore avec 5 familles |
| Exploits (cachés jusqu'à l'obtention) | sommet de l'autel de la fortune ; enclume à +10 ; 12 trophées dans une run ; boss tué avant la rage |

- **Records à ajouter** : victoires par époque et par classe ou famille, victoires sans résurrection,
  sommets de la fortune, enclumes à +9/+10, runs à 12 trophées, panoplies complètes.
- **Affichage** : bandeau « Succès : … » en run et au bilan ; onglet du Carnet avec avancement et tri
  « presque fini ».

**4.2 Titres**
- Un titre porté à la fois, choisi dans le Carnet. Il s'affiche sous le nom du héros (badge du lobby,
  plaque du Duel et de la Tour, écran de chargement).
- Sources : les succès ; les paliers de maîtrise (« Guerrier vétéran », « Maître guerrier ») ; le
  Panthéon (« Tombeur de cerveaux ») ; la collection (« Archiviste »).

**4.3 Complétion : rendre « tout collectionner » atteignable** (chiffres de 1.5)

| Catégorie | Aujourd'hui | Proposition pour la complétion |
|---|---|---|
| Classes | 60 à débloquer (26 à 68 runs) | compte tel quel |
| Maîtrise | 60 × 40 ≈ 1 000 h | la complétion compte la **maîtrise 20** (« Maître ») ; de 21 à 40, des titres de prestige. Avec un **rattrapage par famille** (P7), une nouvelle classe va plus vite tant qu'une classe de sa famille est plus avancée |
| Cartes et passifs | 18 cartes + 120 certificats | compte tel quel (plus les cartes ou trophées à débloquer de P7, si Builds les veut) |
| Équipement | 1 731 pièces, +10 inatteignable | l'unité est la **panoplie** (154 panoplies atteignables par l'Armurerie, plus celles des Donjons) ; « amélioré à fond » = des succès « panoplie entière à +10 », pas tout le catalogue |
| Apparences | 3 182 (> 1 000 runs) | **score à paliers** (50, 200, 500, 1 000…) comme le score d'archive d'Eden, pas un pourcentage ; plus une voie ciblée (P9, plans de fabrication P5) |
| Époques, Tour, Panthéon, succès | — | comptent tels quels |

- **Complétion globale** : la moyenne des catégories finies, affichée en tête du Carnet et sur l'écran
  titre (résumé de la sauvegarde). Les scores sans fin (apparences, archive) sont montrés à part.

**Touche** : nouveau `core/achievements.gd` (données et vérifications), `profile.gd` (records, titre
porté, succès obtenus), `run_director.gd` / `run.gd` (nouveaux records), UI du Carnet, `hud.gd`
(bandeau), badge du lobby. **Dépendances** : Interface (page, titres, bandeau), Builds (cartes et passifs
à débloquer), Modes (d'où vient chaque chose), Équilibrage (seuils).

### P5 — Un rôle économique par activité : gains par mode (idées du joueur, coût M)

**Intérêt** : chaque activité a une raison d'être jouée, et le hub (forge, Armurerie, archive) se
nourrit de plusieurs sources.

| Activité | Ce qu'elle rapporte en propre | Règles proposées |
|---|---|---|
| **Survie** | insignes (Armurerie) ; **fournitures de fortification** : ciseaux, parchemins de puissance / garde, pierres de sûreté, parchemin béni | déjà en partie (butin du sac, coffres de forge, marchands). Le coffre de récompense du boss devient un **coffre de forge garanti**, qui ne se perd jamais. Les fournitures du sac restent soumises à la victoire ou à l'extraction (P1a) |
| **Tour** | **joaillerie et finition** : gemmes, parchemins d'enchantement, **cristaux** (polir, réforger) | coffre du joaillier aux étages de boss (tous les 10), la 1re fois par difficulté ; cristaux par étage gravi (ex. 2 + étage ÷ 20) ; les objets d'étage, le record et les apparences de palier ne changent pas |
| **Donjons** (à venir) | **pièces mythiques, légendaires, éveillées ciblées** (une panoplie d'Eden par donjon) et **plans de fabrication** | le boss lâche une pièce de la panoplie du donjon, au niveau voulu ; parfois un plan : la recette d'un objet de la collection (pièce ou apparence), fabriqué au hub avec cristaux, insignes et « éclats de donjon » |
| **Duel** | gloire et titres | points de duel → titres ; puis le Panthéon (P8) |

Cette répartition donne aussi un sens aux 3 « monnaies du hub » : insignes (posséder), cristaux et
fournitures (améliorer), plans (cibler). **Touche** : `tower.gd:finish` et récompenses d'étage,
`run_director.gd` (coffre du boss), futur mode Donjons, `rewards.gd`. **Dépendances** : Modes (Tour,
Donjons), Équilibrage (quantités, coût de la forge du hub).

### P6 — Après l'époque IV : rangs héroïques et étoiles d'époque (coût M)

**Intérêt** : une raison de rejouer la Survie (le mode que le joueur aime) une fois les 4 époques
finies, avec des objectifs lisibles.

**Règles**
- **3 étoiles par époque**, visibles dans la page Survie :
  - ★ gagner l'époque ;
  - ★ la gagner sans résurrection ;
  - ★ réussir le défi de l'époque, fixe et affiché (ex. I : boss de la map 3 avant la rage ; II :
    12 trophées ; III : sans arme secondaire ; IV : enclume utilisée sur les 3 maps).

  Les étoiles comptent pour les succès (P4).
- **Rangs héroïques 1 à 10**, ouverts par l'époque IV et jouables sur n'importe quelle époque terminée.
  Chaque rang monte la force des monstres (en plus de `Epochs.MONSTER_MULT`) et ajoute une contrainte
  choisie dans une liste, à la façon du « pacte » de Hades (moins de relances, coffres plus chers,
  élites plus nombreuses, enclume plafonnée à +6, une seule résurrection en moins…).
- **Récompenses** : insignes × (1 + 0,15 × rang) ; coffre d'apparence d'une qualité de plus aux rangs
  3, 6 et 9 ; titre au rang 10 de chaque époque.

**Touche** : `epochs.gd`, `run_director.gd`, `run.gd:finish`, `lobby.gd:_menu_survival`.
**Dépendances** : Équilibrage (multiplicateurs, contraintes), Modes (Survie), Interface (page Survie).

### P7 — Remplir la courbe : maîtrise 9 à 40, déblocages du milieu (coût M)

**Intérêt** : les niveaux 9 à 40 et les runs 5 à 50 doivent apporter quelque chose.

**Règles**
- **Rangs de certificat** : un certificat passe au rang II à la maîtrise 15 de sa classe et au rang III
  à la maîtrise 25 (son effet × 1,5, puis × 2), affiché dans le parcours de maîtrise. Maîtriser une
  classe profite à toutes. Comme c'est de la puissance permanente en Survie, il faut un plafond fixé
  avec Équilibrage.
- **Paliers de prestige de classe** à 10, 20, 30 et 40 : titre, cadre du badge, teinte d'aura de classe,
  et au niveau 40 une variante dorée de la tenue de la classe si les assets le permettent.
- **Rattrapage par famille** : XP de maîtrise × 2 pour une classe tant qu'elle est sous la maîtrise
  d'une autre classe de sa famille (plafonné à la maîtrise 8, ou 20 si le joueur accepte P4.3).
- **Déblocages du milieu de courbe** (à décider avec Builds) : quelques cartes liées aux époques II, III
  et IV et à la Tour ; une partie des 67 effets de trophée à découvrir (ex. 40 d'emblée, 27 par succès
  ou époques).
- On garde 2 points de talent par niveau (80 au plus) : l'arbre ne se remplit jamais, c'est un choix.

**Touche** : `progression.gd:rewards_at`, `profile.gd:add_expertise`, `run.gd:passive_stats`,
`cards.gd:UNLOCK`, `trophies.gd`. **Dépendances** : Builds (rangs de certificat, cartes et trophées à
débloquer), Équilibrage (plafond de puissance en Survie), Interface (parcours de maîtrise).

### P8 — Fin de jeu : le Panthéon des cerveaux (coût L)

**Intérêt** : le « défi ultime » voulu par le joueur, avec une récompense qui se voit.

**Règles**
- **Accès** : voir P2 (Duel gagné contre l'IA scriptée Hardcore, ou étage 100 de la Tour). Les cerveaux
  quittent le menu Duel libre pour cette page.
- **Échelle** : Débutant → Facile → Normal → Difficile → Hardcore → Champion (le cerveau « actuel »).
  On n'affronte un cerveau qu'après avoir battu le précédent.
- **Égalité** : les cerveaux ont été entraînés au niveau 10 sans équipement. Le combat se joue donc à
  fiche égale : règles du duel, et l'adversaire copie ton équipement et tes bonus. Seul le jeu compte. À
  valider par Modes et Équilibrage.
- **Récompenses** (la 1re victoire contre chaque cerveau) :
  - une pièce de la **panoplie du Panthéon** (6 pièces : arme du type de ta classe, tête, torse, jambes,
    gants, bottes), légendaire, avec un bonus de panoplie à 2, 4 et 6 pièces, utilisable en Tour et dans
    les futures arènes, archivable ;
  - un titre par cerveau et une aura exclusive au Champion.
  - Battre le Hardcore avec les 5 familles donne la version **éveillée** de la panoplie : 30 victoires,
    un vrai objectif long.
- **Technique** : figer 6 fichiers de cerveaux dans git (`data/cerveaux/pantheon_*.json`, ~2 Mo
  chacun) pour qu'ils ne changent plus à chaque entraînement. Le cerveau « actuel » reste local. Les
  observations de `ml_arena.gd` ne changent pas.

**Touche** : `duel.gd`, `ml_duel_pilot.gd`, `lobby.gd` (page Panthéon), `rewards.gd` ou nouvelle
panoplie, `profile.gd` (victoires). **Dépendances** : Modes (place du Panthéon, format), Équilibrage
(égalité face au cerveau), Builds (effets de la panoplie), Interface.

### P9 — Puits pour les insignes et les cristaux (coût S à M)

- **Insignes** : en plus de l'Armurerie, une **boutique d'apparences tournante** (6 apparences pas encore
  obtenues, renouvelées à chaque run ; prix selon la rareté), et plus tard les plans des Donjons. C'est la
  voie ciblée vers la collection d'apparences (P4.3).
- **Cristaux** : nouvelles sources en Tour (P5) ; le coût de la forge du hub (1 000 à 4 000 cristaux
  pour +10) est à revoir par Équilibrage.
- **Autel de la fortune** en Survie : remplacer les coffres d'équipement et de set par des insignes et
  une apparence, ou les garder comme « gros lot » (question au joueur).

**Touche** : `gear_shop_page.gd` (ou une nouvelle page), `fortune.gd`, `forge.gd`. **Dépendances** :
Équilibrage, Interface.

---

## 4. Questions aux autres équipes

**Interface**
1. Où mettre le Carnet de progression (entrée du lobby, onglet de Collection, écran Héros) ? Où s'affiche
   le titre porté ?
2. Accord sur « activités verrouillées visibles avec leur condition » et « fenêtre Nouveau = fiche de
   tutoriel » (P2.2, P2.4) ?
3. Vocabulaire unique (maîtrise, points de talent, coffre commun) et insignes au lobby : d'accord ?
4. Coffres d'apparence de la Tour annoncés sur les étages 50 / 100 / 150 / 200 ?

**Équilibrage**
1. Pouvez-vous mesurer, en Survie, les monstres et les élites tués par map et l'expertise et les insignes
   réels d'une run (nos chiffres sont des hypothèses) ?
2. Cristaux : le coût de la forge du hub est-il voulu ? Combien de cristaux par étage de Tour ?
3. Puissance permanente en Survie (talents, certificats et plateau, archive, aura, et nos rangs de
   certificat) : quel plafond reste compatible avec la puissance normalisée ?
4. Multiplicateurs et contraintes des rangs héroïques ; prix de l'Armurerie par rapport aux insignes par run.

**Modes**
1. La Tour comme source de joaillerie et de cristaux, les Donjons comme source de pièces ciblées et de
   plans : d'accord ? Qui définit la fabrication ?
2. Ordre d'ouverture : Duel après les 3 premiers duels de la Tour, Donjons à l'époque II, arènes après X
   duels ?
3. Panthéon : quel format de duel face à un cerveau (fiche égale, niveau) ? Une page à part ou dans le Duel ?
4. Y aura-t-il un JcJ non normalisé (arènes) où le stuff de l'Armurerie compte ? Sinon, à quoi sert-il en
   dehors de la Tour ?

**Builds**
1. Règle de couleur des certificats (P1c) et interdiction des doublons de passif (P1d) : d'accord ?
2. Quelles cartes et quels effets de trophée passer en « à débloquer » (P7) ?
3. Rangs II et III des certificats : acceptable pour l'identité des classes ?
4. Effets de la panoplie du Panthéon.
5. Recouvrement entre les talents (dégâts et recharge des sorts), les cartes de sort de classe et les
   améliorations de sort : faut-il simplifier ?

---

## 5. Questions au joueur (l'indispensable)

1. **Après l'époque IV** : préfères-tu des **rangs de difficulté** (mêmes époques, plus dures, meilleures
   récompenses, défis à étoiles) ou d'**autres époques** et zones ?
2. **« Toutes les classes au maximum »** : 60 classes × maîtrise 40, c'est environ 1 000 h. D'accord pour
   que la collection compte la **maîtrise 20** (21 à 40 = titres de prestige), avec un rattrapage par
   famille ?
3. **Déblocage progressif** : d'accord avec l'ordre de P2 (Forge et Tour à la fin de l'époque I, Duel
   après les duels de la Tour, Donjons à l'époque II) ? Les 5 classes de base restent-elles ouvertes
   d'emblée ? Ta sauvegarde actuelle garde tout ce que tu as déjà.
4. **Cerveaux** : la récompense doit-elle être un **vrai équipement** (utilisable en Tour et en arènes) ou
   seulement un **cosmétique et un titre** ?
5. **Autel de la fortune** : garder ses coffres d'équipement (la seule façon de ramener une pièce
   mythique de la Survie) ou les remplacer par des insignes et des apparences ?
