# Survivant — spécification du mode « survivor » (S0, 15/10/2026)

Demande du joueur (15/10, mot pour mot dans le brief de l'orchestrateur) : à côté de la Survie actuelle (progression,
découverte du stuff, équipement du hub), un **vrai mode survivor à une seule boucle** où **tout passe par les cartes** :
choix et amélioration des pièces d'équipement, choix et amélioration des sorts, choix et amélioration de l'arme ; les
bonus des cartes communes ne sont plus des cartes mais le **passif de base** de chaque pièce, éveillé à **+6 / +8 / +10** ;
une pièce prise **reste à vie** dans son emplacement ; stats **aléatoires**, jet parfait possible ; un seul niveau de
pièce qui suit la run, plafonné à 90 ; pas d'arme de classe au départ.

Ce document est prêt à coder : chaque point ouvert est tranché (« **DÉCISION** » + justification). Les chiffres marqués
« (réglage) » sont des valeurs de départ que le lot d'équilibrage S7 recale par mesure ; ils vivent dans le profil
`survivor` de `ModeRules` (modifiable en mode dev, `dev_edits.json` → `modes`).

Sources lues : `CLAUDE.md`, `DESIGN.md` (« Boucle de jeu et Survie », « Étapes et sources », « Auto-attaque des armes »,
« Pacte, géants et Menace », « Boss : PV fixes »), `conception/nuit_15_10/PLAN_NUIT.md`, `RAPPORT_MATIN.md`, `R_P11.md`,
`A1_progression.md` §5.3 ; code : `core/run.gd`, `run_director.gd`, `cards.gd`, `boons.gd`, `slot_chests.gd`, `items.gd`,
`craft.gd`, `epochs.gd`, `trophies.gd`, `menace.gd`, `modes.gd`, `mode_rules.gd`, `unlocks.gd`, `economy.gd`,
`profile.gd` (`begin_run`, `end_run_survival`, `equipment_stats`), `world.gd`, `combat/weapon_attacks.gd`,
`player/player.gd` (`recalc_stats`, `_weapon_type_id`, `gain_xp`, `_start_attack`), `world/proc_map.gd`,
`world/giant_altar.gd`, `ui/card_picker.gd`, `ui/activities.gd`, `ui/lobby.gd`, `ui/results_screen.gd`,
`data/eden_catalog.json` (5 947 objets, 326 sets d'Eden, 17 types d'arme).

---

## 0. Nom, place, différence avec la Survie

**DÉCISION — nom affiché « Survivant »**, identifiant de code `survivor` (fichiers `core/survivor*.gd`, mode
`Modes.current() == "survivor"`). Justification : règle P10 « tout le jeu en français » ; « Survivant » est la traduction
directe du mot du joueur et se distingue de « Survie » par le sous-titre.

| | Survie (inchangée) | Survivant (nouveau) |
|---|---|---|
| Rôle | progression du compte, découverte des pièces d'époque, insignes de référence | une run pure façon Vampire Survivors / Megabonk : le build se fait **entièrement** aux cartes |
| Boucle | 3 cartes d'une époque, portail après chaque boss, sceaux, rage par carte | **1 carte, 20 minutes, un seul fil** : niveaux → cartes → puissance ; gardiens à 5, 10, 15 min ; boss final à 20:00 |
| Équipement | celui du hub (+N, gemmes, enchantements), coffres d'emplacement qui remplacent une pièce | **rien du hub** ; 9 emplacements vides remplis par les cartes, **chaque pièce gardée à vie** |
| Niveau des pièces | palier de l'époque (23 / 33 / 43…) | **un seul niveau : celui du héros**, plafonné à 90 |
| Cartes communes (Boons) | cartes de niveau | **plus jamais en carte** : passif de base de chaque pièce, éveillé à +6 / +8 / +10 |
| Arme | arme de classe du hub, arme secondaire trouvée | **aucune au départ** : 1re carte = choix entre 3 armes de types différents ; gardée à vie ; pas d'arme secondaire |
| Trophées, enclume ±N, fournitures, coffres de forge | oui | non (voir §6) |

Place dans le menu Jouer : activité **JcE, rangée « Aventure », 2e position** (Survie, Survivant, Donjons, La Tour).
Sous-titre : « Une run, tout se gagne aux cartes ». Gains affichés (`gives`) : `mastery`, `insignia`, `look`, `title`.

**DÉCISION — verrou** : `Unlocks.LIST["survivor"]`, condition « Termine une première Survie (quelle que soit l'issue). »
(`Profile.runs_done >= 1`, `legacy: true`). Justification : les Premiers pas (`core/tutorial.gd`) apprennent les
contrôles dans la Survie ; le Survivant s'ouvre après une seule run (5 à 10 min), donc un compte presque neuf y joue,
et sa première run y est complète (pool de départ, §7). Le mode dev ouvre tout. Tant que les lots S1 à S6 ne sont pas
tous faits, l'activité n'est visible **qu'en mode dev** (`Survivor.READY := false`, passé à `true` à la fin de S6).

---

## 1. La boucle unique

### 1.1 Déroulé (DÉCISION)

| Temps | Ce qui se passe |
|---|---|
| 0:00 (jeu en pause) | Choix 1 « Choisis ton arme » : 3 armes de 3 types différents (§4). Choix 2 « Choisis ta première compétence » : 3 sorts de la classe (comme la Survie). |
| 0:00 → 5:00 | Carte générée de la zone choisie (`ProcMap.generate_run`), horde qui monte (§8.2). Coffres, marchands, sanctuaires, enclumes, autels (§6). |
| 5:00, 10:00, 15:00 | **Gardien** : un géant (moteur `GiantMonster`, P12) surgit à 18 m du héros, annoncé 10 s avant (« Un gardien approche ! »). Vaincu : **Coffre du gardien** (§6.2). Ne monte pas la Menace. |
| 15:00 | L'entrée du donjon devient le **Portail du boss** (sans sceau) : on peut y entrer en avance (bonus « Audace », §6.4). |
| 19:00 | « Le boss arrive dans 1:00 » ; horde finale (densité maximale). |
| 20:00 | Si le héros n'est pas déjà entré : **fondu forcé vers l'arène** (`RunDirector._enter_arena`), après le choix de carte en cours éventuellement. |
| Arène | Boss de la zone (mécaniques de `BossBrain`), **PV fixes** (§8.3), renforts toutes les 14 s, **rage du boss après 4:00** (paliers `RAGE_TIERS` existants). |
| Fin | Boss vaincu = **victoire** ; héros tombé sans résurrection = **défaite** ; abandon (menu pause). Pas d'extraction. Bilan commun (`ResultsPanel`). |

Durée cible : **22 à 25 minutes** pour une victoire (20 min de carte + 1 à 4 min de boss).

**DÉCISION — pas de rage de carte** (ni paliers ×1,1 / ×2 / ×11 / ×101) : le chronomètre est le boss forcé à 20:00 ; la
pression monte par la courbe par minute (§8.2). Justification : dans une boucle unique la rage ferait doublon avec
l'arrivée du boss et punirait le joueur qui farme exactement comme le genre l'encourage.

**Mort** : 1 résurrection par run (comme la Survie : 3 s, au point de départ de la carte ou de l'arène) ; la seconde
chute termine la run. **Une seule carte** : ni portail entre étapes, ni sceaux, ni changement de zone.

### 1.2 Choix au lancement (page de l'activité)

- **Zone** : une des zones débloquées (`Profile.zone_unlocked`) ; elle donne le décor, le roster des monstres et le boss
  final. Aucune différence de difficulté entre zones (la difficulté vient du temps et du palier).
- **Palier** (lot S8) : I à V, chacun ouvert par une victoire au précédent (§8.5). Avant S8 : palier I seulement.
- Classe : celle du héros choisi au lobby (comme partout).

---

## 2. Montée de niveau : les cartes

### 2.1 Familles de cartes (DÉCISION)

| Famille | Type de carte (`type`) | Quand | Effet |
|---|---|---|---|
| **Arme** | `sv_weapon` | seulement au choix 1 (aucune arme) | équipe l'arme, gardée à vie (§4) |
| **Amélioration d'arme** | `sv_weapon_up` | arme < +10 | +2 à l'arme (stats) **et** une amélioration d'auto-attaque `WeaponAttacks.roll_upgrade` (§4.3) |
| **Nouvelle pièce** | `sv_piece` | emplacement libre (8 emplacements hors arme) | équipe la pièce dans cet emplacement, **verrouillé à vie** (§3) |
| **Amélioration de pièce** | `sv_piece_up` | pièce portée < +10 | +2 (ou mieux selon la rareté de la carte, §3.4) ; éveille le passif à +6 / +8 / +10 |
| **Nouveau sort** | `skill` / `chain` (types existants) | sorts pris < `SPELL_MAX` (6) | sort de la classe : 4 cases, puis enchaînements (logique existante de `Run`) |
| **Amélioration de sort** | `upgrade` (type existant) | sort < niveau 10 | +1 niveau ; l'effet de l'ancienne carte de classe s'ajoute (§5) |
| **Évolution** | `sv_evolution` | prérequis éveillés (§3.6) | évolution légendaire de `Boons` (Seigneur de la tempête…) |
| **Repli** | `sv_gold`, `sv_heal`, `sv_reroll` | moins de 3 cartes valides | or (30 + 6 × niveau), soin 35 % des PV, +1 relance |

Les cartes communes (`Boons`), les certificats, les trophées et les cartes de classe **ne sont jamais proposés**.

### 2.2 Tirage d'un choix de 3 cartes (`SurvivorCards.roll(3)`)

Ordre de construction (cartes distinctes : jamais deux cartes sur la même cible, emplacement ou sort) :
1. **Carte « équipement »** : tirée dans {Nouvelle pièce, Amélioration de pièce, Amélioration d'arme} si l'une existe.
2. **Carte « sort »** : tirée dans {Nouveau sort, Amélioration de sort} si l'une existe.
3. **Carte libre** : toutes familles, au poids.
4. Les cartes sont mélangées avant affichage (la place ne trahit pas la famille).

Règles dures :
- **Au plus 2 « Nouvelle pièce » par choix** : il y a toujours une autre option que prendre une pièce (souci exprimé par
  le joueur : ne pas être forcé d'utiliser un emplacement). Le bouton **Passer** (§2.4) reste aussi toujours là.
- **Jamais 3 cartes mortes** : s'il reste moins de 3 cartes valides, compléter par les cartes de repli (dans l'ordre :
  `sv_gold`, `sv_heal` si PV < 70 %, `sv_reroll`).
- **Évolution** : si une évolution est disponible et absente des 4 derniers choix, elle prend la place de la carte libre.
- **Filet « sort »** : tant que le héros a moins de 2 sorts, la carte « sort » est un Nouveau sort ; au niveau 6, s'il en
  a moins de 3, idem.

Poids (réglage, `ModeRules` profil `survivor`, clés entre crochets) :

| Candidat | Poids |
|---|---|
| Nouvelle pièce, par emplacement libre | 1,0 [`w_piece_new`] ; ×1,5 si une panoplie de la run y a déjà ≥ 2 pièces (« affinité ») |
| Amélioration de pièce, par pièce < +10 | 0,8 [`w_piece_up`] ; ×1,6 si la prochaine étape éveille le passif (+6 / +8 / +10) |
| Amélioration d'arme | 2,5 [`w_weapon_up`] |
| Nouveau sort | 3,0 si < 2 sorts, 2,0 si < 4, 1,0 sinon [`w_spell_new`] |
| Amélioration de sort, par sort < 10 | 1,1 [`w_spell_up`] |
| Évolution | 4,0 [`w_evolution`] |

**Pitié** (anti-frustration) : un candidat jamais proposé depuis 6 choix voit son poids ×2 (compteur par cible dans
`SurvivorCards._since`).

### 2.3 Rareté des cartes

Chaque carte d'amélioration (pièce, arme, sort) porte une rareté tirée par `Cards.roll_tier(luck)` (commune, rare,
épique, légendaire ; poids 60 / 27 / 10 / 3). `luck` = 0,02 × minutes écoulées (réglage `luck_per_min`) + bonus de la
source (coffre ouvragé +0,3, doré +0,6, gardien +1,0). Une carte « Nouvelle pièce » ou « Arme » porte la **rareté de
la pièce** (6 raretés d'objet, §3.2), pas une rareté de carte.

### 2.4 Relancer, bannir, passer

- **Relancer** : 2 par run (`base_rerolls`) + la statistique `rerolls` des passifs éveillés (Bonne étoile) ; les coffres et
  gardiens ont leur propre relance (1). Hook : `Run.rerolls_left()`.
- **Bannir** (3 par run) : seulement sur une carte **Nouveau sort** (le sort ne revient plus) ou une carte **Nouvelle
  pièce de panoplie** — dans ce cas c'est **la panoplie** qui est bannie : ses pièces ne sont plus proposées (celles
  portées gardent leur effet). Justification : bannir deux des trois panoplies de la run est le moyen sûr de viser « le
  torse dans le bon set ». Les améliorations ne se bannissent pas.
- **Garder** (verrou de carte de la Survie) : **retiré** en Survivant (un geste de moins, rien ne le demande).
- **Passer** : bouton sous la rangée, toujours présent sur un choix de montée de niveau ; donne 15 + 3 × niveau d'or.

---

## 3. L'équipement

### 3.1 Emplacements

Les 9 emplacements de `Items.SLOTS` : arme (§4) + tête, torse, jambes, gants, bottes, cape, collier, bague. **Une pièce
posée ne se retire ni ne se remplace jamais pendant la run** (aucune carte « Nouvelle pièce » pour un emplacement
rempli ; le menu pause n'offre aucun déséquipement). Pas d'arme secondaire, pas de trophée.

### 3.2 Fabrication d'une pièce (`SurvivorGear.make_piece(slot, ctx)`)

Champs ajoutés à l'objet (format `Items.from_template` existant) : `sv: true`, `full` (stats à 100 % de jet),
`jets` (stat → jet), `boon` ({`id`, `tier`}), `boon_stage` (0 à 3), `set` (panoplie, facultatif).

1. **Rareté** (`roll_rarity(minutes, steps)`) : table par minute, interpolée linéairement (réglage `rarity_table`) :

   | Minute | Commun | Spécial | Rare | Épique | Mythique | Légendaire |
   |---|---|---|---|---|---|---|
   | 0 | 45 | 30 | 20 | 5 | 0 | 0 |
   | 5 | 20 | 30 | 30 | 15 | 5 | 0 |
   | 10 | 5 | 15 | 35 | 30 | 12 | 3 |
   | 15 | 0 | 5 | 25 | 40 | 22 | 8 |
   | 20 | 0 | 0 | 15 | 40 | 30 | 15 |

   `steps` décale le tirage vers le haut (coffre ouvragé 1, doré 2, gardien : rareté ≥ épique). Conséquence voulue : une
   place laissée libre se remplit mieux plus tard — le choix « prendre maintenant ou attendre » est le cœur du mode.
2. **Modèle d'Eden** (apparence et nom seulement) : `SurvivorPool.template(slot, wtype, palier, rarity)` — un objet
   d'Eden de l'emplacement dont le niveau est dans [palier − 12 ; palier], `palier = clampi(10 + 2 × niveau du héros, 1, 90)`
   (niveau 1 → 12, niveau 20 → 50, niveau 40 → 90), de la même rareté si possible (sinon la plus proche), en préférant
   (×3) les modèles **déjà découverts** (`Profile.seen_gear`). On retire `item.set` (sets d'Eden) et `item.passive`
   (passifs d'arme d'Eden) posés par `from_template`. **DÉCISION** : le modèle change le look, jamais les stats
   (les ratios `r` d'Eden sont normalisés par niveau) ; les pièces de fin de run *ressemblent* à des pièces de fin de jeu.
3. **Stats aléatoires** : base = stats du modèle (`r`) × `Items._ref` × `RARITY_MULT[rareté]` (comme `from_template`),
   **plus des affixes** tirés dans `Items.AFFIX_RANGES` (sans doublon de stat) : commun 0, spécial 1, rare 1, épique 2,
   mythique 2, légendaire 3. Chaque stat (base et affixe) reçoit un **jet** dans {80, 85, 90, 95, 100 %} (tirage
   uniforme ; légendaire : {90, 95, 100 %}). `full[stat]` = valeur à 100 % ; `base[stat]` = `full × jet` ;
   `quality = 1.0`. Ainsi `Items.stats` n'a rien à savoir des jets ; les affixes sont mis dans `base` pour suivre le
   niveau et le +N comme le reste.
4. **Jet parfait** : toutes les stats à 100 % → la pièce est **parfaite** : ×1,1 sur `base` (réglage `perfect_bonus`),
   cadre doré, « ★ Jet parfait » ; compté au Carnet (§7.3). Probabilité avec 4 stats ≈ 1 / 625 au tirage ; le chemin
   normal passe par les améliorations rares (§3.4).
5. **Passif de base** : un id de `Boons.all()` tiré au poids `Boons.RARITY[...].weight`, parmi les cartes **débloquées**
   (`Cards.card_unlocked`), hors : `recall` (instantané), `glass_cannon` (malus), évolutions (`requires` non vide),
   passifs dont `max` < 2 (les passifs de saut à `max` 2 restent : leur plafond coupe la 3e étape). Rang du passif suivant la rareté de la pièce : commun / spécial → `common` (×1), rare → `rare`
   (×1,5), épique / mythique → `epic` (×2,2), légendaire → `legendary` (×3) (`Cards.tier_mult`).
6. **Panoplie** : avec 60 % de chances (`set_chance`), une des 3 panoplies de la run non bannies (§3.5), uniforme,
   ×2 pour une panoplie dont le héros porte déjà ≥ 2 pièces. `Items.make_set_piece(item, set_id)` donne le nom
   (« Plastron de la Tempête »).
7. **Niveau** : `item.level` = palier du modèle (affiché) ; **la puissance suit le héros** : crochet dans
   `Items.power_level` : `if item.get("sv", false): return clampi(Run.hero_level, 1, 90)` (hors run : 90).
   **DÉCISION** : « un seul niveau de stuff qui s'adapte au niveau de la run, capé à 90 » = la pièce n'a pas de palier
   propre, elle vaut toujours le niveau du héros. Sans ça une pièce prise au niveau 5 et gardée à vie serait morte.

### 3.3 Le +N

`item.upgrade` 0 → 10 (`Items.MAX_UPGRADE`), +10 % des stats de base par point (formule existante de `Items.stats`,
×2 à +10). Pas d'échec, pas de parchemin, pas d'or : seulement des cartes, l'enclume et le coffre de l'emplacement.

### 3.4 Carte « Amélioration de pièce » selon sa rareté (DÉCISION)

| Rareté de la carte | Effet |
|---|---|
| Commune | +2 |
| Rare | +2 et **la stat la moins bien jetée passe à 100 %** (chemin vers le jet parfait) |
| Épique | +2 et un affixe de plus (jet tiré), ou, s'il y a déjà 4 affixes, une stat à 100 % |
| Légendaire | +4 (deux étapes d'un coup) et une stat à 100 % |

Toujours plafonné à +10 (une légendaire à +8 donne +10). Justification : 5 cartes mènent une pièce à +10 (assez rare
pour obliger des choix sur 9 emplacements, assez court pour voir les paliers en une run) ; la rareté apporte la variété
et rend le jet parfait **atteignable par l'investissement**, pas seulement par la chance.

### 3.5 Panoplies de la run

**DÉCISION — les panoplies du Survivant sont les archétypes de `Items.SETS`** (Tempête, Givre éternel, Lame sanglante,
Œil du faucon, Phénix, Vent céleste, Salve, Rempart, et Esprits), bonus à **2 / 4 / 6 pièces** avec effets déclenchés,
**pas** les 326 sets du catalogue d'Eden. Justification : 326 sets (bonus de stats à 2 / 5 pièces) rendraient la
deuxième pièce d'un même set introuvable et la carte illisible ; les archétypes sont déjà les « sets façon Eden » du jeu,
lisibles et comptés par `Items.set_counts` / `active_set_bonuses` sans nouveau code.

- **3 panoplies par run** (`sets_per_run`), tirées parmi celles **ouvertes** (§7.1), montrées au départ (HUD : bandeau
  d'ouverture ; menu pause : page Build). Moins de 3 ouvertes : toutes.
- 9 emplacements dont l'arme : 6 pièces d'une panoplie demandent de lui consacrer 6 emplacements sur 9.

### 3.6 Passifs : éveil, cumul, plafonds, évolutions

- **Éveil** : quand le +N d'une pièce atteint +6, +8 puis +10, son passif gagne une étape (`boon_stage` 1, 2, 3). À chaque
  étape : `Run.passives[id] += 1` et `Run.passive_power[id] += Cards.tier_mult(tier)` — **les tables existantes de la
  run** ; `Run.passive_stats()` et `Run.passive_procs()` les lisent déjà, rien d'autre à brancher. À +10 une pièce
  légendaire vaut 9 cartes communes de son passif (3 étapes × 3) ; une commune, 3.
- **Cumul** : deux pièces au même passif s'additionnent (même entrée de `Run.passive_power`). **DÉCISION** sur « effet
  cumulable dans les runs » : cumulable **dans la run** (entre pièces et étapes) ; rien de permanent d'une run à l'autre
  (un bonus permanent casserait l'égalité de départ). La trace qui reste est le **Codex des passifs** (§7.3).
- **Plafond par passif** (`SurvivorGear.boon_cap(id)`) : en puissance (unités de carte commune), `max` de la carte pour
  les passifs à unité entière ou plafonnée (`proj`, `pierce`, `bounce`, `area`) ; 1,5 × `max` pour les autres. Au-delà,
  l'éveil ne rapporte rien (la carte le dit : « plafond atteint »). Les plafonds de `Player` restent (recharge 50 %,
  esquive 20 %, exécution 30 %, `WeaponAttacks.MAX_EXTRA_PROJ` = 4).
- **Évolutions** (`Boons` légendaires à `requires`) : la carte `sv_evolution` apparaît quand **tous** ses prérequis sont
  éveillés (puissance ≥ 1). Prise : `Run.passives[id] = 1`, puissance 1. Une fois chacune.

---

## 4. L'arme

### 4.1 Départ (DÉCISION)

Pas d'arme de classe. Le **premier choix de la run** (jeu en pause, avant le choix du sort) propose **3 armes de 3 types
différents** tirés dans `SurvivorPool.weapon_types_open()` (§7.1), chacune avec une variante d'auto-attaque au hasard
(`auto_variant` 0 ou 1), rareté tirée à la minute 0. Poids : ×2 pour le type de la classe, ×1,5 pour les types de même
nature de dégâts que la classe (`dmg_type`). Une relance. Justification : jamais de héros sans auto-attaque (pas de
« mains nues » à régler), et le joueur choisit son style dès la seconde 0.

### 4.2 Arme à vie

L'arme a les mêmes champs qu'une pièce (§3.2 : jets, affixes, passif de base, panoplie possible, +N avec éveil à
+6 / +8 / +10). Son type peut être **n'importe lequel des 17** : crochets `Run.weapon_type()` et
`Player._weapon_type_id()` → `Survivor.weapon_type()` (le `wtype` de l'arme portée, sinon celui de la classe).
Passif de base de l'arme : poids ×3 pour les passifs dont la statistique figure dans `scales` de sa variante
(`proj`, `pierce`, `bounce`, `area`, `reach`, `atk_speed`, `cast_speed`, `crit`, `dot`) ou dont un effet se déclenche sur
`basic_hit`.

**Animations** : le modèle de la classe n'a pas toujours les animations de l'arme (`WeaponAttacks.SPECS[...].anims`).
`Combatant.play` ignore déjà une animation absente ; crochet dans `Player._start_attack` : si `not has_anim(anim_name)`,
prendre les `anims` de la variante 0 du type de la classe (le rythme des coups reste celui de l'arme).

### 4.3 Amélioration d'arme (`sv_weapon_up`)

Une carte = **+2 à l'arme** (stats, éveil du passif comme une pièce ; légendaire : +4) **et** une amélioration
d'auto-attaque `WeaponAttacks.roll_upgrade(spec, tier, cur)` fusionnée par `merge_upgrade` dans `Run.weapon_ups["weapon"]`.
Après la fusion, `cur.rank` est mis au +N de l'arme ; **l'effet légendaire de la variante s'acquiert à +4**
(`SIG_RANK` = 4 inchangé : 2e carte). Plafond : +10 (5 cartes ; `WeaponAttacks.MAX_RANK` = 8 ne s'applique pas ici).
Le titre de la carte : « Taille lourde — +4 → +6 », lignes = `WeaponAttacks.upgrade_lines` + passif éveillé s'il y a lieu.

---

## 5. Les sorts

- **Pool** : sorts de la classe débloqués (`Progression.skill_unlocked`), jusqu'à **6 sorts** (`SPELL_MAX`) : les 4 cases,
  puis des enchaînements (types `skill` et `chain` existants, `Run.arrange` selon le préréglage du Grimoire).
  **DÉCISION** : 6 et non 12 (Survie) : 6 × 9 améliorations = 54 cartes possibles, déjà autant que tout l'équipement ;
  au-delà les choix se dilueraient (§9).
- **Niveau 1 à 10** : carte `upgrade` existante. `Cards.rules().max_rank` vaut déjà 10 ; `Cards.skill_upgrade(s, tier)`
  donne déjà « l'effet de la carte » de classe : dégâts (ou soins, ou durée) + recharge, et les **facettes** Puissance /
  Ferveur, Cadence, Persistance (anciennes cartes de classe, lot 6) selon la rareté, plus un bonus d'attribut au
  lancement à partir de rare ; `Run.apply_card` les cumule déjà dans l'entrée du sort. Rien à réécrire.
- **Paliers de sort** (DÉCISION) : la carte qui mène un sort au **niveau 5** est au moins **épique**, celle qui le mène au
  **niveau 10** est **légendaire** (rareté forcée en passant `tier` à `Run._describe_card`). Justification : deux moments
  forts par sort, sans nouveau système.
- Les talents de classe (`Profile.talents`) et les certificats posés sur le plateau s'appliquent comme partout (§7.2).

---

## 6. Économie de la run

### 6.1 Ce qui reste, change, disparaît

| Élément | Survivant |
|---|---|
| Or (monstres, objets à casser, défis, géants) | **reste** ; sert aux coffres et aux marchands ; perdu en fin de run |
| Clés (élites, sanctuaires) | **restent** : ouvrent un coffre sans payer |
| Coffres de la carte (30) | **changent** : coffres du Survivant (§6.2), prix existant (`chest_price`) |
| Marchands ambulants (3) | **changent** : 3 cartes du Survivant à acheter (40 + 8 × niveau d'or, rareté +1), 1 clé, 1 potion, « +1 relance » (100 + 10 × niveau) ; **ni équipement, ni fournitures** |
| Enclumes (3) | **changent** : chacune une fois, **+2 gratuit** sur une pièce portée au choix (3 cartes : les pièces les plus proches d'un éveil) |
| Fontaine, aimant | restent |
| Pacte (autel de cupidité), autels du géant, Menace | **restent** (P12 inchangé ; la Menace monte les PV des monstres, du boss final, et les insignes) |
| Stèles du défi (2) | restent : 3 élites → **Coffre doré gratuit** (§6.2) au lieu du coffre de récompense |
| Sanctuaires (10) | restent : carte du Survivant, ou 2 clés + or ; les sanctuaires « trophée » deviennent « carte » |
| Gardiens d'élite des camps | restent (clé + choix de 3 cartes) ; les sceaux ne servent plus |
| Autel du scribe, autel de la fortune | **disparaissent** (`station_count` = 0) : fournitures et insignes du hub |
| Trophées, arme secondaire, enclume ±N de la Survie | **disparaissent** |
| Lâchers de monstres : équipement, coffres de récompense (forge, joaillier), fournitures | **disparaissent** ; potions gardées (3 % monstre, 30 % élite) |
| Monstres en rage, rage de carte | disparaissent (§1.1) |

### 6.2 Coffres du Survivant (`SurvivorChests.LAYOUT`, 30 par carte)

| Coffre | Nombre | Apparence | Contenu (3 cartes, 1 relance) |
|---|---|---|---|
| Coffre de [emplacement] (tête, torse, jambes, gants, bottes, cape, collier, bague) | 2 × 8 = 16 | simple | emplacement **libre** : 3 pièces de cet emplacement (rareté +1 cran) ; **rempli** : 3 cartes « Amélioration de pièce », celle de cet emplacement en premier (+2 garanti) |
| Coffre d'arme | 2 | simple | 3 cartes d'amélioration d'arme de raretés différentes ; arme au maximum : 3 cartes au choix |
| Coffre de sort | 6 | ouvragé | 3 cartes de la famille « sort » |
| Coffre doré | 6 | doré | 3 cartes toutes familles, rareté +2 crans |
| **Coffre du gardien** (5:00, 10:00, 15:00 ; pas sur la carte) | 3 | — | 3 pièces de rareté ≥ épique pour des emplacements libres ; s'il n'y en a plus, 3 améliorations légendaires ; + 60 + 15 × niveau d'or |

« Viser la pièce qu'on veut » : le coffre de l'emplacement offre 3 pièces au choix pour **cet** emplacement, avec
l'affinité de panoplie (§3.2.6) ; les bannissements de panoplie (§2.4) resserrent le tirage.

### 6.3 Nombre de cartes d'une run (estimation, à mesurer en S7)

Montées de niveau ≈ 37 (niveau ≈ 38 à 20:00, §8.1) + 2 choix de départ + coffres ouverts ≈ 14 + sanctuaires ≈ 5 +
gardiens d'élite ≈ 4 + géants 2 + gardiens 3 + enclumes 3 + marchands ≈ 3 ⇒ **≈ 70 cartes**. Tout maximiser demande
≈ 120 cartes (8 pièces × 6 = 48, arme 6, 6 sorts × 10 = 60, + évolutions) : une run complète ≈ 60 % de l'arbre ; les
choix comptent.

### 6.4 Butin de fin de run (méta)

| Gain | Règle (réglage) |
|---|---|
| **Insignes** | participation 25 (dès 10 monstres, au prorata des 10 premières minutes, comme E6) + 2 par minute de carte tenue (40 au plus) + monstres comptés / 25 (au plus 1 500) + élites × 2 + victoire 50 ; × palier (1 / 1,2 / 1,4 / 1,6 / 1,8) ; × Menace et pacte (`Menace.add_insignia`, 1 « carte ») ; **Audace** : entrer dans l'arène avant 20:00 donne +5 % par minute d'avance (25 % au plus). Cible **≈ 450 insignes / h** au palier I (entre Survie I 360 et IV 670), ≈ 700 au palier V : ligne `"survivant_1"` dans `Economy.INSIGNIA_PER_HOUR`, contrôlée par `test_e5`. |
| **Maîtrise de classe** | formule commune de `Run.finish` (niveau × 15 + monstres / 2 + élites × 10 + victoire 200) × `mastery_mult` 0,65, puis rattrapage `Economy.catchup` ; cible : la même maîtrise à l'heure que la Survie (mesurée en S7). Pas de contrats, pas de Défi de maîtrise, pas de bonus de 1re victoire d'époque. |
| **Coffre d'apparence** | à chaque victoire : `Rewards.look_type(palier − 1)` (menu Coffres). |
| **Découvertes (Armurerie)** | les modèles d'Eden des pièces **portées en fin de run** dont le niveau ne dépasse pas le palier de la plus haute époque ouverte (`Epochs.map_def(Epochs.unlocked(), 3)` : armure / arme) rejoignent `Profile.seen_gear`. La carte de la pièce le signale (« Découverte à l'Armurerie »). Le Survivant ne fait jamais découvrir au-delà de l'époque atteinte en Survie : le rôle de la Survie (découverte des époques) reste entier. |
| **Codex, succès, titres** | §7.3. |
| Rien d'autre | ni fournitures, ni cristaux, ni coffres de forge / joaillier, ni or gardé, ni étoiles d'époque, ni rangs héroïques. |

---

## 7. Lien avec la quête commune et le hub

Principe : **le Survivant ne lit jamais l'équipement porté au hub** ; c'est la **collection du compte** qui élargit ce que
ses cartes peuvent proposer, et le Survivant rend de la collection en retour.

### 7.1 Pool qui s'ouvre avec le compte (`core/survivor_pool.gd`)

| Pool | Compte neuf | S'ouvre par |
|---|---|---|
| Panoplies | **Tempête, Lame sanglante, Phénix** | un archétype X s'ouvre si le compte possède une pièce de panoplie X (coffre ou préréglages, champ `set` ou `archetype`) **ou** a battu en Survie le boss de la zone dont le donjon porte X (`Profile.records["boss_<zone>"]`, `Dungeons.ARCHETYPES`) ; **Esprits** : une pièce de la panoplie des Esprits possédée |
| Types d'arme | katana, arc, bâton, épée, dagues, sceptre **+ le type de la classe** | un type s'ouvre dès qu'une arme de ce type est dans `Profile.seen_gear` (la Survie fait découvrir les 17 types, lot E4) |
| Passifs de base | cartes communes sans condition | les conditions existantes de `Cards.UNLOCK` (records de toutes les runs) : rien de nouveau |
| Sorts | sorts débloqués de la classe | `Progression.skill_unlocked` (maîtrise) |
| Modèles d'Eden (apparence) | tous ceux de l'emplacement | préférence ×3 pour les modèles déjà découverts |

Garde-fou : jamais moins de 3 types d'arme ni de 3 panoplies ouverts (le compte neuf a exactement ce minimum).

### 7.2 Ce qui s'applique du compte

**DÉCISION** : s'appliquent les **talents de classe** et les **certificats posés** (maîtrise de la classe : ce n'est pas de
l'équipement, et c'est la méta-progression façon Megabonk) ; **ne s'appliquent pas** : pièces, +N, gemmes, enchantements,
bonus d'archive (`Archive.bonus`), auras (`Profile.aura_stats`) — crochet dans `Player.recalc_stats` (`arc` et `aura`
vides si `Survivor.active`). Les potions de la run fonctionnent normalement.

### 7.3 Ce que le Survivant rend à la collection (lot S6)

Enregistré dans un nouveau dictionnaire `Profile.survivor` (sauvegardé) :
- **Codex des passifs** : chaque passif mené à l'étape 3 (pièce +10) au moins une fois → `codex` ; page du Carnet
  « Survivant » (x / N passifs) ; catégorie de `Completion`.
- **Panoplies accomplies** : chaque panoplie portée à 6 pièces dans une run → `sets_done`.
- **Jets parfaits** : compteur `perfect`.
- **Victoires par palier**, **meilleur temps** de victoire (`best_time`).
- **Succès** (`core/achievements.gd`, titres) : « Survivant » (1re victoire), « Jet parfait », « Panoplie accomplie »
  (6 pièces), « Codex : 10 passifs », « Codex complet », « Survivant du palier V ».

---

## 8. Équilibrage

### 8.1 Rythme du héros (réglage)

XP : `Survivor.xp_mult(level)` appliqué dans `Player.gain_xp` (à la place de `Epochs.xp_boost`) : 2,0 au niveau 1 → 1,15
au niveau 10 et au-delà (`xp_mult`). Cibles : **niveau 10 à 4:00, 20 à 9:00, 30 à 15:00, 38 (± 3) à 20:00**. Aucun
plafond de niveau par carte ; puissance des pièces plafonnée à 90.

### 8.2 Monstres par minute (`SurvivorDirector`, réglages du profil `survivor`)

- **Niveau** : `clampi(round(1 + 1,8 × minutes) + palier du camp, 1, 90)`, jamais sous `niveau du héros − 1` (comme la
  Survie) ; héros et monstres suivent tous deux ×1,1 par niveau : la courbe ci-dessous est l'écart **en plus**.
- **PV** × `hp0 × hp_growth^minutes` (0,5 × 1,12^t : ×0,5 à 0:00, ×1,55 à 10:00, ×4,8 à 20:00) ; **dégâts** ×
  `atk0 × atk_growth^t` (0,5 × 1,07^t : ×0,5 → ×1,93) ; × palier (§8.5) ; × Menace et pacte (P12, inchangés). Le
  `ZONE_DAMAGE` et la montée `EARLY_EASE` de la Survie ne s'appliquent pas (la courbe démarre déjà basse).
- **Densité** (interpolée sur 20 min) : vivants au plus 18 → 110 (`MAX_ALIVE` de rage = 110, borne de performance de P2) ;
  meute toutes les 6 → 1,8 s, de 4 → 12 monstres ; vagues alternées toutes les 45 → 25 s ; élites ponctuelles dès 8:00
  (toutes les 40 s, 20 s après 15:00) ; horde finale à 19:00.
- **Gardiens** (5:00 / 10:00 / 15:00) : `GiantMonster` aux **PV fixes** 40 000 / 150 000 / 450 000 × palier × Menace
  (`guardian_hp`) ; coups plafonnés à 30 % des PV du héros (règle du géant). Cible : 30 à 60 s pour un build moyen.

### 8.3 Boss final

PV **fixes** (règle P11 : jamais d'après le niveau ou la puissance du héros) : `boss_hp` = **1 500 000** × palier ×
Menace ; rage du boss après **4:00** (`boss_rage_at` 240 s, paliers `RAGE_TIERS`). Cibles : bonne run 1 à 2 min ; run
moyenne 2 à 4 min ; run faible n'achève pas avant la rage.

### 8.4 Cibles de résultat (compte neuf, palier I)

| Joueur (proxy pilote `--human`) | Tient 10 min | Atteint le boss | Gagne |
|---|---|---|---|
| Débutant (0,3) | 70 % | 35 % | 10 % |
| Moyen (0,5) | 85 % | 60 % | 35 % |
| Bon (0,7) | 95 % | 85 % | 65 % |

Puissance : DPS en fin de carte ≈ ×8 à ×12 celui de 1:00 à niveau égal (la courbe des monstres en demande ×9,6) ; un
build « focalisé » (une panoplie à 6, pièces +10) doit battre le boss en moins de 1:30.

### 8.5 Paliers I à V (lot S8)

Monstres, gardiens et boss × 1 / 1,5 / 2,2 / 3,2 / 4,5 (PV et dégâts) ; rareté des pièces +0 / +0,5 / +1 / +1,5 / +2 crans ;
insignes × 1 / 1,2 / 1,4 / 1,6 / 1,8. Un palier s'ouvre en gagnant le précédent (`Profile.survivor.wins[p]`). Titre au
palier V.

### 8.6 Validation

- **Pilote** : `world.tscn -- --survivor [--palier=N] --autoplay --auto-quit --human=0.5` ; choix automatiques par
  `SurvivorCards.auto_pick` (priorités : arme ; nouveau sort tant que < 4 ; amélioration qui éveille un passif ; nouvelle
  pièce rare ou mieux, ou n'importe laquelle après 12:00 ; amélioration de sort ; le reste) ; lignes `[sv]` toutes les
  60 s (minute, niveau, pièces, somme des +N, sorts et niveaux, passifs éveillés, DPS 10 s, PV des monstres).
- **`tools/sim_survivor.py`** (copie de `sim_survie.py`) : 5 classes × 3 graines × `--human` 0,3 / 0,5 / 0,7 ; tableau
  §8.4 + minutes de mort + temps des gardiens et du boss.
- **Sonde de boss** : `tools/boss_ttk` avec un scénario « build de Survivant » (pièces +10 de rareté épique, 6 sorts
  niveau 7, arme +10) pour caler `boss_hp` et `guardian_hp`.
- **Journal de run** (`RunJournal`) : champ `mode = "survivor"`, cartes prises par famille, niveau à 5 / 10 / 15 / 20 min,
  pièces à +10, panoplie la plus haute, passifs éveillés, TTK des gardiens et du boss. Règle : aucun réglage sans ≥ 5 runs
  mesurées par palier (comme la Survie).

---

## 9. Risques et garde-fous

| Risque | Garde-fou |
|---|---|
| **Combinatoire** (≈ 25 passifs × 9 panoplies × 34 variantes d'arme × 60 classes) : un empilement casse le jeu | plafonds par passif (§3.6) ; plafonds de `Player` (recharge, esquive, exécution, projectiles +4) ; évolutions une fois ; S7 mesure les 10 builds les plus forts du journal et le test S3 vérifie qu'aucune combinaison tirée ne dépasse les plafonds |
| **Dilution des cartes** (trop de familles, on ne voit jamais l'amélioration voulue) | 2 cartes garanties (équipement, sort) ; pitié à 6 choix ; 6 sorts au plus ; coffres ciblés par emplacement ; bannissement de panoplies ; mesure : part des runs où une pièce reste à +0..+4 faute d'offre |
| **Regret d'emplacement à vie** (pièce commune prise à 1:00) | rareté qui monte avec le temps (le joueur apprend à attendre) ; « Passer » ; au plus 2 pièces par choix ; carte : « 🔒 Gardée toute la run » écrit sur chaque pièce |
| **Lisibilité** des cartes de pièce (stats + jets + panoplie + passif) | 4 lignes de stats au plus (`CardPicker.MAX_STATS`) ; passif en une ligne ; détail sur Maj (comme les infobulles U6) ; panoplies limitées à 3 par run |
| **Type d'arme sans animation** sur le modèle de la classe | repli sur les animations de l'arme de la classe (§4.2) ; test S2 sur les 17 types |
| **Confusion Survie / Survivant** | noms et sous-titres distincts, page d'activité d'une phrase ; fiche de découverte au 1er lancement |
| **Fuite d'objets du Survivant vers le hub** | `Profile.begin_run` (instantané) + `end_run_survival` (restauration) déjà en place ; le Survivant pose les pièces dans `Profile.equipped` **sans** `Profile.equip` (ni préréglage, ni coffre) ; test S1 : hub identique après victoire, défaite, abandon, fermeture en pleine run |
| **Concurrence avec la Survie** (insignes, découverte) | insignes ≤ Survie IV à l'heure ; découverte limitée à l'époque ouverte ; pas de fournitures ni cristaux |
| **Chemins « hors Survie » de l'ancienne run** (`Run.survival == false` réactive le butin d'équipement des monstres, le marchand d'équipement…) | S1 audite chaque `Run.survival` / `not Run.survival` de `core/`, `ui/`, `world/` (grep) et ajoute `or Survivor.active` là où il faut ; liste dans le rapport |
| **Fichiers partagés** avec d'autres sessions | tous les crochets dans les fichiers existants sont posés par S1 (une ligne chacun) et appellent des fichiers neufs ; S2-S4 ne touchent que leurs fichiers |
| **Pilote ≠ joueur** | mesures = proxy ; le journal réel tranche |

---

## 10. Interface

Règles communes : français, phrases courtes, aucun pourcentage dans le texte permanent (infobulles), aucune mention du jeu
d'origine, 1280 × 720 sans texte coupé, manette par `UiNav` (tout en `Button`), captures regardées avant de rendre.

### 10.1 Cartes (rendu dans `CardPicker`, lot S5)

- **Nouvelle pièce** : ligne du haut « Torse · Épique » ; icône ; nom à la couleur de la rareté ; **stat principale en
  gros** (règle `Items.MAIN_STAT`) ; jusqu'à 4 lignes de stats, chacune avec son jet en 5 crans « ▮▮▮▮▯ » (vert à 100 %) ;
  ligne panoplie « Tempête 1 → 2 / 6 » (verte, palier suivant en infobulle) ; ligne passif « Passif : Lame large · s'éveille
  à +6 » ; pied « 🔒 Gardée toute la run » ; « ★ Jet parfait » sur cadre doré ; « Découverte à l'Armurerie » s'il y a lieu.
- **Amélioration de pièce** : « Bottes +4 → +6 » ; « Passif éveillé : Pas du vent » (ou « ×2 », « ×3 », « plafond
  atteint ») ; stats avant → après (2 lignes) ; effet de rareté (« Agilité : jet parfait »).
- **Arme** : format `RunDirector.weapon_card` existant (variante, description, ★ effet légendaire) + type d'arme + rareté.
- **Sorts** : rendu existant ; badge « Niv. 4 → 5 ».
- Boutons sous la rangée : Relancer (n), **Passer (+or)** ; « Bannir » seulement sur Nouveau sort et pièce de panoplie
  (libellé « Bannir la panoplie » dans ce cas) ; pas de « Garder ».

Exemples de textes : « Choisis ton arme », « Choisis ta première compétence », « Niveau 12 ! Choisis une carte »,
« Coffre de torse : choisis une pièce », « Gardien vaincu ! Choisis une pièce », « Enclume : +2 sur une pièce ».

### 10.2 Menu pause : page « Build » (`ui/survivor_build_page.gd`)

Remplace la page « Run » quand `Survivor.active`. Trois colonnes :
1. **Équipement** : l'arme en grand, puis une grille 4 × 2 des emplacements ; chaque case : icône, +N, cadenas, couleur
   de rareté, pastille verte par étape d'éveil ; case vide « Libre » ; infobulle = carte complète de la pièce.
2. **Sorts** : les 6 cases (4 + enchaînements) avec niveau « 7 / 10 » et la barre de niveau.
3. **Panoplies et passifs** : les 3 panoplies de la run (x / 6, prochain palier, bannie barrée) ; les passifs éveillés
   avec leur total (`Cards.total_text`) ; les évolutions possibles et ce qui leur manque.
Boutons : Reprendre, Abandonner, Paramètres, Guide (ceux de la page Run).

### 10.3 HUD (retouches minimes, lot S5)

- Ligne d'objectif : « 12:34 · Gardien à 15:00 » puis « Boss à 20:00 » ; arène : texte existant du boss.
- Panneau d'objectifs : « Équipement 6 / 9 · Sorts 4 / 6 ».
- Barre de sorts : petit chiffre de niveau sur chaque case.
- Bandeau d'ouverture : « Survivant · Panoplies : Tempête, Phénix, Rempart » (4 s).
- Rien d'autre de permanent (HUD épuré d'U9).

### 10.4 Lobby et bilan

- Page d'activité : bandeau, une phrase (« Vingt minutes, une carte : arme, pièces et sorts se gagnent aux cartes. »),
  choix de la zone (lignes des zones ouvertes, boss en sous-titre), palier (S8), pastilles de gains, **Lancer** épinglé.
- Bilan (`ResultsPanel`, même composant) : **Gagné** (maîtrise, succès, palier ouvert), **Gardé** (insignes avec le
  détail en infobulle, découvertes, Codex, coffre d'apparence), **Perdu** (or, clés) ; bloc « Ton build » : arme, pièces
  à +10, jets parfaits, panoplie la plus haute ; bouton **Rejouer** (même zone, même palier).
- Fiche de découverte « Survivant » au 1er lancement (`Tutorial`, carte d'information P8) : 3 lignes — pièces à vie,
  passif éveillé à +6 / +8 / +10, boss à 20:00. Entrée au Guide (F1).

---

## 11. Architecture

### 11.1 Fichiers neufs et API (signatures fixées par S1, corps remplis par chaque lot)

```
core/survivor.gd          class_name Survivor (RefCounted, état statique)       — S1
  const READY := false ; RUN_TIME := 1200.0 ; BOSS_OPEN_AT := 900.0 ; GUARDIAN_TIMES := [300.0, 600.0, 900.0]
  const SPELL_MAX := 6 ; MAX_ITEM_LEVEL := 90 ; UP_STEP := 2 ; WAKE_AT := [6, 8, 10] ; BASE_REROLLS := 2 ; BANS := 3
  static var active, palier, sets, banned_sets, bans_used, picks (famille -> n), since (cible -> choix)
  static func reset() ; start(cid: String, zone: String, palier := 1) ; owns(card: Dictionary) -> bool
  static func apply_card(card) -> void            # -> SurvivorCards.apply
  static func weapon_type() -> String             # wtype de l'arme portée, sinon celui de la classe
  static func xp_mult(level: int) -> float ; station_count(kind: String, default: int) -> int
  static func shrine_reward(default: String) -> String ; rule(key: String) -> float   # ModeRules.num(key, 0, "survivor")
core/survivor_pool.gd     class_name SurvivorPool                               — S2
  sets_open() -> Array ; draw_sets(n: int) -> Array ; weapon_types_open() -> Array ; boons_open() -> Array
  eden_palier(level: int) -> int ; template(slot, wtype, palier, rarity) -> Dictionary ; discover_cap() -> Vector2i
core/survivor_gear.gd     class_name SurvivorGear                               — S2
  roll_rarity(minutes: float, steps := 0) -> int ; make_piece(slot: String, ctx := {}) -> Dictionary
  make_weapon(wtype: String, ctx := {}) -> Dictionary ; equip(item) -> void ; free_slots() -> Array ; worn() -> Array
  upgrade(slot: String, tier: String) -> Dictionary   # {text, woke: int}, applique l'éveil
  wake(item) -> int ; boon_cap(id: String) -> float ; is_perfect(item) -> bool ; jet_steps(item, stat) -> int
core/survivor_cards.gd    class_name SurvivorCards                              — S3
  roll(n := 3, kind := "", luck := 0.0) -> Array ; chest_cards(box: String) -> Array ; apply(card) -> void
  ban(card, shown: Array) -> Dictionary ; rerolls_left() -> int ; skip_gold() -> int
  start_offers(world: Node) -> void ; auto_pick(options: Array, random := false) -> Dictionary
core/survivor_director.gd class_name SurvivorDirector (RefCounted, réf. au RunDirector)  — S4
  _init(d: RunDirector) ; update(delta) ; update_spawns(delta) ; objective_text() -> String
  monster_level(tier: int) -> int ; scale_monster(m: Monster, boss: bool) ; on_monster_died(m: Monster)
  try_enter_boss() ; open_chest(box: String) ; use_station(it: Interactable) -> bool ; capture(sh: Shrine) -> bool
  setup_boss(boss: Monster) ; boss_rage_at() -> float ; on_boss_killed()
  const LAYOUT (coffres, §6.2) ; static layout(n: int, rng) -> Array
core/survivor_rewards.gd  class_name SurvivorRewards                            — S6
  settle(res: String, counted_kills: int) -> void ; insignia_parts(...) -> Dictionary ; journal() -> Dictionary
ui/survivor_build_page.gd, ui/survivor_cards_view.gd                            — S5
```

### 11.2 Crochets dans les fichiers existants (tous posés par S1, une ligne ou un `if` chacun)

| Fichier | Endroit | Crochet |
|---|---|---|
| `core/run.gd` | `start()` | `Survivor.reset()` en tête |
| | `roll_cards()` | `if Survivor.active: return SurvivorCards.roll(n, kind)` en tête |
| | `apply_card()` | `if Survivor.owns(card): Survivor.apply_card(card); changed.emit(); return` en tête |
| | `ban_card()`, `rerolls_left()` | délégation à `SurvivorCards` si actif |
| | `weapon_type()` | `if Survivor.active: return Survivor.weapon_type()` |
| | `finish()` | maîtrise × `rule("mastery_mult")` ; `if Survivor.active: SurvivorRewards.settle(res, counted)` à la place des blocs `if survival` |
| `core/modes.gd` | `current()` | `"survivor" if Survivor.active` avant `"survival"` |
| `core/mode_rules.gd` | `PROFILES` | profil `survivor` (clés du §2.2, §3, §6.4, §8 avec leurs valeurs) |
| `core/unlocks.gd` | `LIST`, `test()` | entrée `survivor` (§0) |
| `ui/activities.gd` | `LIST` | entrée `survivor` (rangée `adventure`, après `survival`, `unlock: "survivor"`, `img: "survival"` en attendant une image) ; masquée si `not Survivor.READY` hors mode dev |
| `ui/lobby.gd` | `_show_menu`, lancement | page `_menu_survivor()` (§10.4) et `_start_survivor()` → `Survivor.start(...)` |
| `ui/results_screen.gd` | `_replay()` | `Survivor.start` si la run était un Survivant |
| `core/world.gd` | arguments | `--survivor`, `--palier=N` |
| | départ | `elif Survivor.active: SurvivorCards.start_offers(self)` avant `elif Run.skills.is_empty()` |
| `ui/card_picker.gd` | `auto_pick()` | `if Survivor.active: return SurvivorCards.auto_pick(options, random_cards)` en tête |
| `player/player.gd` | `_weapon_type_id()` | `if Survivor.active and not foe: return Survivor.weapon_type()` |
| | `recalc_stats()` | `arc` et `aura` vides si `Survivor.active` |
| | `gain_xp()` | `× Survivor.xp_mult(level)` si actif (pas `Epochs.xp_boost`) |
| | `_start_attack()` | repli d'animation (§4.2) |
| `core/items.gd` | `power_level()` | `if item.get("sv", false): return clampi(Run.hero_level if Run.active and Run.hero_level > 0 else 90, 1, 90)` |
| `world/proc_map.gd` | coffres | `if Run.active and Survivor.active and not royale: chest_boxes = SurvivorDirector.layout(...)` + apparences |
| | lieux | `count = Survivor.station_count(kind, count)` ; récompense des sanctuaires `Survivor.shrine_reward(...)` |
| `core/run_director.gd` | `start()` | `if Survivor.active: sv = SurvivorDirector.new(self)` (+ son message d'ouverture) |
| | `_process()` | `if sv: sv.update(delta)` ; rage seulement `if sv == null` ; `if sv: sv.update_spawns(delta) else: _update_spawns(delta)` |
| | `_objective_text()` | `if sv and state == "explore": return sv.objective_text()` |
| | `_monster_level()`, `max_level()` | délégation à `sv` (max 90) |
| | `_spawn_monster()` | blocs `ZONE_DAMAGE` / Survie / `EARLY_EASE` seulement `if sv == null` ; `if sv: sv.scale_monster(m, boss)` avant `add_child` |
| | `_on_monster_died()` | après l'or : `if sv: sv.on_monster_died(m); if m == _boss: _on_boss_killed(); return` |
| | `_interact()` « dungeon » | `if sv: sv.try_enter_boss(); return` |
| | `_open_slot_chest()`, `_use_station()`, `_capture()` | délégation à `sv` en tête |
| | `_enter_arena()` | `if sv: sv.setup_boss(_boss)` après la création |
| | `boss_rage_tier()` / `boss_rage_next_in()` | condition `Run.survival or sv`, seuil `sv.boss_rage_at()` |
| | `_on_boss_killed()` | `if sv: sv.on_boss_killed(); return` |
| | `next_zone_id()`, `_emit_zone()` | `""` et titre sans « étape » si `sv` |
| `ui/merchant_ui.gd` | offres | `Run.survival or Survivor.active` : ni équipement ni fournitures ; cartes du Survivant |

S1 crée aussi les **squelettes** des fichiers neufs avec ces signatures (corps neutres : `roll` renvoie les cartes de la
Survie, `scale_monster` ne fait rien, etc.) pour que le projet compile et que S2, S3, S4 puissent travailler en parallèle.

---

## 12. Plan d'implémentation (lots ordonnés)

Chaque lot suit `PLAN_NUIT.md` (tests verts, relecture « dictée », captures regardées, rapport `R_S<n>.md` dans
`conception/survivor/`, DESIGN.md mis à jour pour sa partie, version + CHANGELOG à chaque envoi).

| Lot | Objectif | Fichiers | Tests | Dépend de | Taille |
|---|---|---|---|---|---|
| **S1 Socle et crochets** | état `Survivor`, mode, verrou, profil `ModeRules`, activité (mode dev), page du lobby minimale, `--survivor`, **tous les crochets du §11.2**, squelettes des fichiers neufs, audit des `Run.survival` | neufs : `core/survivor.gd` + squelettes ; retouches : `run.gd`, `run_director.gd`, `player.gd`, `items.gd`, `world.gd`, `proc_map.gd`, `modes.gd`, `mode_rules.gd`, `unlocks.gd`, `activities.gd`, `lobby.gd`, `card_picker.gd` (auto_pick), `merchant_ui.gd`, `results_screen.gd` | `test_sv1` : `Modes.current() == "survivor"` ; `Profile.equipped` vide au départ ; hub **identique** (hash vault / loadout / presets) après victoire, défaite, abandon et `begin_run` sans fin ; activité cachée hors mode dev ; une Survie normale inchangée (`test_e6`, `test_p12`, `test_lot17` verts) | — | M |
| **S2 Pièces et arme** | §3 et §4 : pool, rareté par minute, modèle par palier, jets, affixes, jet parfait, panoplies de la run, passif de base, éveil +6 / +8 / +10 vers `Run.passive_power`, plafonds, arme de tout type, repli d'animation | `core/survivor_pool.gd`, `core/survivor_gear.gd` | `test_sv2` : 1 000 pièces par emplacement (jets dans les crans, affixes par rareté, pas de set d'Eden, panoplie ∈ run) ; `power_level` = niveau du héros ≤ 90 ; éveil : puissance 1 / 2 / 3 × rang ; plafond ; `Items.active_set_bonuses` voit les panoplies ; 17 types d'arme équipés sans erreur, auto-attaque du bon type ; compte neuf : 3 panoplies, 7 types | S1 | L |
| **S3 Cartes** | §2 et §5 : tirage à garanties, poids, pitié, évolutions, repli, bannir / relancer / passer, cartes de coffre, choix de départ, `auto_pick` | `core/survivor_cards.gd` | `test_sv3` : 10 000 tirages sur des états aléatoires : jamais 3 « Nouvelle pièce », ≥ 1 équipement et ≥ 1 sort quand possibles, cibles distinctes, jamais vide, jamais de `Boons`, sorts ≤ 6, niveau 5 ≥ épique et 10 légendaire, emplacement rempli jamais reproposé ; application de chaque type ; départ = arme puis sort | S1, S2 (signatures) | L |
| **S4 Directeur de la run** | §1, §6, §8.2-8.3 : 20 min, courbes, densité, gardiens, portail à 15:00, boss forcé à 20:00, PV fixes, rage du boss à 4:00, coffres du Survivant, enclume +2, sanctuaires, stèles, butin des monstres (potions seulement), lieux retirés | `core/survivor_director.gd` | `test_sv4` : disposition des 30 coffres ; aucune pièce ni fourniture lâchée en 60 s de pilote ; gardien à 5:00 (temps simulé) ; boss : PV = `boss_hp` × Menace, indépendants du héros ; entrée forcée à 20:00 ; scribe et fortune absents | S1, S3 | L |
| **S5 Interface en run** | §10.1-10.3 : rendu des cartes (jets, cadenas, panoplie, passif, jet parfait), Passer, Bannir la panoplie, page Build, HUD (objectifs, niveaux des sorts, bandeau) | `ui/survivor_build_page.gd`, `ui/survivor_cards_view.gd` ; retouches : `card_picker.gd`, `pause_menu.gd`, `hud.gd` | `test_sv5` (page Build construite sur un état riche, sans texte coupé) ; `test_nav_screens` (page ajoutée) ; `tests/shot_sv` : captures choix de départ, carte de pièce parfaite, amélioration qui éveille, page Build, HUD à 14:00 — **regardées** | S2, S3 | L |
| **S6 Fin de run et méta** | §6.4, §7.3, §10.4 : insignes, maîtrise, Audace, découvertes, coffre d'apparence, `Profile.survivor` (sauvegarde, migration, nouvelle partie), Codex au Carnet, succès, Completion, bilan, Rejouer, fiche de découverte, Guide, journal ; `READY = true` | `core/survivor_rewards.gd` ; retouches : `profile.gd`, `achievements.gd`, `completion.gd`, `economy.gd`, `tutorial.gd`, `run_journal.gd`, `results_panel.gd` / `results_screen.gd`, `carnet_pages.gd`, `guide.gd`, `core/survivor.gd` (`READY`) | `test_sv6` : barème (participation au prorata, plafond des monstres, palier, Menace, Audace) ; découverte bornée par l'époque ouverte ; Codex et succès ; sauvegarde → rechargement ; `test_e5` étendu (`survivant_1` ≈ 450 / h) | S1, S2, S4 | M |
| **S7 Équilibrage** | §8 : pilote (`--survivor --autoplay`), lignes `[sv]`, `tools/sim_survivor.py`, scénario de sonde de boss, recalage des réglages du profil `survivor` vers les cibles §8.4, rapport chiffré | `tools/sim_survivor.py`, `game/tools/boss_ttk.gd` (scénario), `core/mode_rules.gd` (valeurs seulement), `core/survivor_cards.gd` (`auto_pick` si besoin) | tableaux §8.4 mesurés (5 classes × 3 graines × 3 niveaux de joueur) ; `test_sv7` borne les réglages (aucun boss en < 30 s pour un build moyen, aucune mort avant 3:00 au pilote moyen) | S1-S6 | M |
| **S8 Paliers, documentation** | §8.5 : paliers I-V (lobby, multiplicateurs, ouverture, titre) ; section « Survivant » de DESIGN.md complète, 3 lignes dans CLAUDE.md (« Chantier en cours ») | `core/survivor.gd` (palier), `ui/lobby.gd` (sélecteur), `core/survivor_rewards.gd`, `DESIGN.md`, `CLAUDE.md` | `test_sv8` : ouverture des paliers, multiplicateurs, insignes ; captures du lobby | S7 | S-M |

Parallélisme possible : après S1, **S2 et S4** en parallèle (fichiers disjoints) ; S3 après S2 (il fabrique des pièces) ;
S5 et S6 en parallèle après S3 (S5 : `ui/` en run ; S6 : méta et bilan). S7 et S8 en dernier, seuls.

Taille : S ≤ un envoi simple, M = quelques fichiers, L = nouveau système (1 session).
