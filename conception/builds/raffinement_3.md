# Équipe Builds & identité de combat — raffinement (tour 3, version 0.1.130)

Lus : `00_BRIEF.md`, `SYNTHESE_v1.md`, `REPONSES_JOUEUR_1.md` (fait foi), notre `concertation_2.md`.
Code relu pour la prise en main : `game/scripts/player/player.gd`, `core/settings.gd`,
`ml/bot_input.gd`, `ml/ml_arena.gd` (`_apply_for`, `_obs_for`), `core/duel.gd`, `combat/pvp_caps.gd`,
`ui/hud.gd`. Durées d'animation mesurées dans `data/motion_keys.json` (1 015 sorts des 60 classes,
vitesse ×1,15 de `_cast_skill`, vitesse d'attaque 1).

---

## 1. Prise en main (sujet pilote)

### 1.1 Comment ça marche aujourd'hui (le code fait foi)

**Lecture des touches** — `player.gd:_wants` : les sorts, l'esquive et le saut sont lus avec
`Input.is_action_just_pressed`, **une seule image**. Un appui qui tombe à un moment où l'état du héros
ne le lit pas est **perdu**. Le seul tampon du jeu est celui du saut (`JUMP_BUFFER` 0,15 s, plus
`COYOTE_TIME` 0,12 s).

**Où chaque appui est lu** (machine à états de `_physics_process`) :

| État du héros | Sort d'une autre case | Même case (enchaînement) | Esquive | Saut |
|---|---|---|---|---|
| `idle` | lancé si la récupération est finie (`_skill_lock_until`), **sinon perdu** | `_chain_input` | oui (recharge 0,45 s) | oui |
| `attack` (auto-attaque) | lancé, coupe l'auto-attaque | oui | oui, coupe tout | oui |
| `skill` (sort en cours) | **perdu** (`_try_skill_input` n'est pas appelé) | `_chain_input` | coupe le sort (avant l'impact : sort perdu) | après l'impact |
| `dodge` | lancé à partir de 45 % de l'esquive (0,14 s) | oui | — | oui, garde l'élan |

**Les fenêtres, en ms** (médiane des 1 015 sorts ; 1er et 9e décile entre parenthèses) :

| Mesure | Valeur | Code |
|---|---|---|
| Animation d'un sort | 720 ms (580-900) | `_begin_action`, `anim_length / 1,15` |
| 1er impact après l'appui | 340 ms (240-420) | `motion_keys.json` « hit » |
| Récupération : pas d'autre sort avant | anim × 0,92 + 450 ms = **1 120 ms** (980-1 280) | `_skill_lock_until`, `SKILL_RECOVERY` |
| Enchaînement : blocage après l'appui | **450 ms** : un appui ici = « Trop tôt », **chaîne cassée** | `CHAIN_DELAY`, `_chain_press` |
| Enchaînement : barre | 3 000 ms, toute la barre est bonne (`CHAIN_ZONE` = 0..1), +20 % | `CHAIN_BAR`, `CHAIN_BONUS` |
| Annulation parfaite | esquive dans les **280 ms** après un impact de sort → Fluidité +10 % (4 paliers, 3 s), recharge du sort −25 %, esquive gratuite ×1,35 | `PERFECT_WINDOW`, `_perfect_cancel` |
| Esquive | 320 ms d'invulnérabilité, recharge 450 ms | `DODGE_TIME`, `DODGE_COOLDOWN` |

Chaque case porte jusqu'à 3 sorts (sort + 2 enchaînements, `Duel.SPELL_SLOTS` = 12) : c'est le « 3
attaques sur la touche 1 » du joueur.

**Pourquoi le joueur au clavier souffre** (relevé dans le code, pas supposé) :
1. **Appuyer deux fois vite sur 1 casse la chaîne** : le 2e appui tombe dans les 450 ms de blocage →
   « Trop tôt ». Le réflexe naturel (marteler) est puni.
2. **Appuyer sur 2 pendant le sort 1 ne fait rien** : l'appui est perdu, et il faut rappuyer après
   ~1,1 s, au bon moment.
3. **Enchaîner trop tôt coupe le sort en cours** : la barre s'ouvre à 450 ms, avant la fin de
   l'animation (720 ms) ; un sort à plusieurs coups perd ses derniers coups (`_begin_action` vide `_hits`).
4. Une esquive avant l'impact fait perdre le sort (voulu, mais sévère sans tampon).

**Ce que fait le mode auto** (préréglage « Bot », `Settings.PRESETS.bot`, réglage
`auto_combo`) : `_update_action` fait une **annulation parfaite à chaque sort**, entre 60 et 280 ms
après le dernier impact (`auto_perfect`), puis `_chain_input` relance la chaîne dès l'ouverture de la
barre et `_update_dodge` lance le sort suivant à 30 % du pas. Il joue donc comme un expert parfait :
Fluidité 4 en permanence (+40 %), recharges ×0,75 à chaque sort (≈ +33 % de lancers), toutes les
chaînes à +20 %. **Estimation : ≈ ×1,8 à ×2 sur les dégâts de sorts** face à un joueur qui casse la
moitié de ses chaînes et ne fait pas d'annulations parfaites. Le fossé « abyssal » vient de là : l'auto
n'est pas une aide, c'est un joueur parfait. (À confirmer par le journal de run E6 : annulations
parfaites et enchaînements par minute, manuel contre auto.)

**Deux anomalies trouvées** :
- `_auto_combo()` ne regarde pas `Duel.active` : **les combos parfaits automatiques marchent en Duel**.
- `_hit_pause` (à chaque annulation parfaite) met `Engine.time_scale` à 0,15 pendant 50 ms : c'est
  déjà un **micro-ralenti global** (réglage « hit_stop »), qui en Duel ralentit aussi l'adversaire.

**Contrainte de l'IA** : les cerveaux pressent les touches par `BotInput.pulse` (`_apply_for`) et
observent `chain_state` (phases « lock » / « bar », `_obs_for` l. 850-856) et `_skill_lock_until`
(l. 838). Ils ont appris que « trop tôt casse la chaîne ». **Tout ce qui suit ne vaut que pour le
héros du joueur** (`bot == null`, `not autoplay`, `not foe`, comme `_auto_combo`) : aucune observation
ajoutée, aucune règle changée pour les cerveaux.

### 1.2 PM1 — Tampon d'entrées (S-M, le cœur de la réponse)

Reprend l'idée du joueur, avec des règles exactes.

1. **Tout appui de sort est gardé** dans une file (FIFO) au lieu d'être lu une seule image.
2. **Taille** : 3 entrées au plus dans la file. Pour une même case, la file ne garde que ce que la
   chaîne peut encore absorber (sort en cours compris) : **1 appuyé 4 fois = les 3 sorts de la chaîne
   + 1 appui dans le vide**, ignoré sans pénalité (petit « × » gris sur la case, pas de texte rouge).
3. **Plus jamais « Trop tôt » pour le joueur** : un appui pendant le blocage de 450 ms est gardé et
   part à l'ouverture de la barre. « Trop tard » (barre de 3 s écoulée) reste.
4. **Moment du départ** d'une entrée :
   - même case (enchaînement) : au plus tôt à l'ouverture de la barre (450 ms) **et après le dernier
     coup du sort en cours** (on ne coupe plus les sorts à plusieurs coups) ;
   - autre case : à la fin de la récupération (`_skill_lock_until`), comme aujourd'hui, mais sans
     avoir à rappuyer ; pendant une auto-attaque : tout de suite (comme aujourd'hui).
5. **Ordre** : celui des appuis (1, 1, 2 → sort 1, enchaînement 1, puis sort 2). Le joueur décide
   l'ordre des marques et des finisseurs (signatures B4) en tapant dans l'ordre.
6. **Péremption** : une entrée meurt **1,2 s** après l'appui si elle n'a pas pu partir (sort en
   recharge, héros étourdi, mort). Un sort en recharge n'est gardé que s'il lui reste **≤ 300 ms** de
   recharge ; sinon « En recharge » comme aujourd'hui. Pas de sort qui part tout seul longtemps après.
7. **L'esquive et le saut ne sont jamais mis en file** derrière des sorts : ils partent tout de suite
   (règles actuelles) et **vident la file** des appuis faits avant eux. Les appuis faits **pendant**
   l'esquive restent et partent à 45 % du pas (le « sort, esquive, sort » de l'expert, inchangé).
8. **Visée** : prise au départ du sort, pas à l'appui (le curseur ou la cible du moment).
9. **Retour visuel** : jusqu'à 3 petites icônes « en attente » au-dessus de la barre de sorts
   (`hud.gd`), qui s'éteignent quand le sort part.
10. **Réglage** : Paramètres > Combat > « Mémoire des touches » : Activée (défaut, aussi pour ta
    sauvegarde) / Désactivée (pour qui préfère le comportement strict actuel).

Ce que ça change : marteler 1 donne la chaîne complète, au meilleur rythme possible, sans couper les
coups ; taper 1-2-3 pendant un sort fait partir les trois dans l'ordre. Ce que ça ne change pas :
l'annulation parfaite (fenêtre de 280 ms) se fait toujours à la main.

- **Touche** : `player.gd` (`_wants`, `_try_skill_input`, `_chain_input`, `_chain_press`,
  `_update_action`, `_update_dodge`, une file `_input_queue`), `settings.gd` (1 réglage),
  `settings_menu.gd`, `hud.gd` (icônes). Pas `ml_arena.gd`. Test : un `tests/test_controls` qui envoie
  des appuis simulés (1×4, 1-2-3, 1 puis esquive).
- **Coût** : S-M (≈ 120 lignes, la logique existe déjà, on change seulement *quand* elle est appelée).

### 1.3 Autres aides de prise en main

| # | Aide | Règle | Coût | Fichiers |
|---|---|---|---|---|
| PM2 | **Maintenir = chaîne complète** | tenir la touche d'une case enchaîne tout seul toute la chaîne au rythme du tampon (même résultat que marteler) ; relâcher arrête. Option, active par défaut au niveau « Assisté » | S | `player.gd` (`_wants` sur `is_action_pressed`), `settings.gd` |
| PM3 | **Plus de sort perdu par une esquive trop tôt** | si l'esquive coupe un sort **avant** son impact, la recharge est rendue à 100 % (le sort n'est pas « consommé ») | S | `player.gd:_update_action` |
| PM4 | **Visée** : on garde les 4 modes existants (`aim_mode` : intelligente, curseur, action, plus proche) et l'aimantation manette (`_pad_aim_point`, cône de 55°) ; ajout : les zones au sol (`ground`) visées à moins de 3 m d'un monstre se posent sur lui | S | `player.gd:_skill_aim` |
| PM5 | **Annonce de l'annulation parfaite** (aide à apprendre, pas une zone dorée) : un anneau bleu bref sur le héros à chaque impact de sort = « esquive maintenant ». Option, active au niveau « Assisté », coupée en JcJ classé | S | `player.gd:_resolve_hit`, `vfx.gd` |
| PM6 | **Accessibilité** : touches déjà remappables (`settings.gd`) ; ajouter « esquive = double appui sur une direction » (option), « hit_stop » coupé d'office en Duel (fin du micro-ralenti global) | S | `player.gd`, `settings.gd`, `duel_director.gd` |

Refusé exprès : agrandir la fenêtre de l'annulation parfaite (le geste d'expert doit rester le même
pour tous), ralenti, zone dorée.

### 1.4 PM7 — Position sur le mode auto : un réglage d'assistance à 4 niveaux (M)

**Réponse à la question du joueur** : non, l'« easy to play » ne doit **pas** être le mode auto, il
doit être **le jeu au clavier avec le tampon** (PM1-PM3). Le mode auto reste, mais comme **confort**,
et il ne doit plus jouer mieux qu'un bon joueur. Raison : si l'auto fait ×2 en jouant parfaitement,
apprendre à jouer à la main est une perte, et le « hard to master » disparaît (l'expert ne bat pas la
machine). On garde les réglages existants, rangés en 4 niveaux (Paramètres > Combat, et rappel sur la
page de chaque activité) :

| Niveau | Sorts | Enchaînements | Annulation parfaite | Déplacement | Autorisé |
|---|---|---|---|---|---|
| **Manuel** | à la main | à la main (tampon au choix) | à la main | à la main | partout |
| **Assisté** (défaut nouvelle partie) | à la main + tampon PM1, maintien PM2 | tampon | à la main, avec l'annonce PM5 | à la main | partout |
| **Détente** (= préréglage actuel) | automatiques | automatiques, dans l'ordre du preset | **aucune** | à la main | JcE, Duel libre |
| **Bot** | automatiques | automatiques | **aucune** | automatique | JcE, Duel libre |

- **Le changement clé** : `auto_combo` ne fait plus d'annulation parfaite (il garde les enchaînements
  à +20 %). L'auto fait alors à peu près ce que fait un joueur moyen avec le tampon ; l'écart avec
  l'expert vient de la Fluidité (+40 %) et des recharges (−25 % par parfait) : c'est le « hard to
  master ». Chiffre à vérifier avec le journal E6.
- **JcJ classé (Ligue, Panthéon)** : niveau maximal **Assisté** (le tampon est une aide d'entrée,
  pas un pilote). Le Duel libre et les duels de la Tour acceptent tout (entraînement).
- **Récompenses identiques en JcE**, quel que soit le niveau : le jeu est solo, il ne faut pas punir le
  joueur qui joue en Détente. Mais les **records de geste** (annulations parfaites, esquives, aérien)
  ne viennent que des gestes faits à la main (l'auto n'en fait plus), et les **Épreuves de maîtrise**
  se jouent en Manuel ou Assisté. Le bilan de run affiche le niveau joué (journal E6, pour comparer).
- **Coût M** : `settings.gd` (1 champ `assist` qui pilote les booléens existants, migration des
  sauvegardes), `settings_menu.gd`, `player.gd:_auto_combo` (plus de `auto_perfect`, test de
  `Duel.active` et du profil de mode), page des activités (`lobby.gd`, une ligne), journal E6.

### 1.5 Ce que l'expert gagne encore à jouer à la main (hard to master, sans ralenti ni zone dorée)

1. **Annulation parfaite** (280 ms après l'impact) : Fluidité jusqu'à +40 %, recharge −25 % par
   parfait, esquive gratuite et plus longue. Seul le manuel y a accès (PM7).
2. **Tissage** : sort → parfait → sort d'une autre case → parfait → enchaînement… L'esquive efface la
   récupération (`_start_dodge` : `_skill_lock_until = 0`), donc l'expert lance ~30 % de sorts en plus
   que la file seule, qui attend la fin des 1 120 ms.
3. **Ordre des marques et finisseurs** (signatures B4) choisi selon la situation, pas l'ordre du preset.
4. **Esquive parfaite défensive** (B7 révisée, 2.2), saut des ondes, combat aérien (+10 % en l'air).
5. **Visée et placement** (zones, lignes, élan), ce qu'aucun réglage ne fait à sa place.

---

## 2. Mises à jour de nos propositions

### 2.1 B4 — Signatures par famille (20) : confirmé (M)

Une signature (marque → finisseur) par **famille** de 3 classes, table du `rapport_1.md` (B4) gardée ;
les deux enfants la modifient par leur certificat de maîtrise 8. Lien avec PM1 : la file respecte
l'ordre des appuis, donc « 1 (marque) puis 3 (finisseur) » marche même en martelant. En Détente,
l'ordre automatique est celui du preset : le Grimoire affiche « pose la marque » / « consomme » pour
aider à ranger son preset. ×2 en JcE, ×1,5 en JcJ (profil `combo_mult`). Session locale (données des
classes). Aucune observation ajoutée à `ml_arena.gd`.

### 2.2 B7 — Maîtrise récompensée, sans ralenti ni zone dorée (S-M au lieu de M)

- **Zone dorée : abandonnée.** La barre reste entièrement bonne (`CHAIN_ZONE` = 0..1), bonus +20 %
  partout. Rien à dessiner pour l'Interface (I8 : retirer la zone dorée).
- **Esquive parfaite défensive** gardée **sans ralenti** : esquiver dans les 150 ms avant qu'une
  attaque annoncée frappe (`telegraph.gd`, où `ml_counts.dodged` est déjà compté) → éclair bleu,
  images rémanentes (déjà codées : `_afterimage`), +1 palier de Fluidité, déclencheur « perfect ».
  Aucun `Engine.time_scale` (évite les saccades que craint le joueur).
- **Carte « Cadence parfaite » remplacée par « Tissage »** : une annulation parfaite entre deux sorts
  d'une même chaîne donne +15 % au sort enchaîné suivant (cumul jusqu'à +45 % sur une chaîne de 3).
  Récompense exactement le geste d'expert de 1.5, inaccessible à l'auto.
- **Épreuve liée** (M1b) : « 3 enchaînements parfaits d'affilée » devient **« 3 chaînes tissées »**
  (une annulation parfaite entre chaque sort). Bronze ouvre « Tissage », ou en run : 150 chaînes
  tissées cumulées (double chemin gardé). Argent / or : titre « Virtuose ».
- Flux (+1 palier de Fluidité, +1 s) et Maître du ciel : inchangés.
- **Touche** : `player.gd` (`_perfect_cancel`, `_start_dodge`, `_chain_press`), `telegraph.gd`,
  `boons.gd`, `cards.gd`, `profile.gd` (records). Pas `ml_arena.gd` (le cerveau garde +20 %).

### 2.3 B14 — Facettes d'amélioration de sort : acceptée (S-M)

Règles du `concertation_2.md` §3.4 confirmées : une seule carte d'amélioration de sort, la rareté
donne le nombre de facettes (commune : rang +1 ; rare : +1 facette au choix Puissance / Cadence /
Persistance ; épique : 2 ; légendaire : 3 + bonus d'attribut) ; les cartes de classe séparées
disparaissent ; sort fétiche ×3 sur cette carte. **Touche** : `run.gd:roll_cards` / `apply_card`,
`cards.gd`, carte de choix (`ui/`). Mesure avant / après par le journal E6. Peut passer tôt (lot 2).

### 2.4 Les deux modes de duel : champs « build » du profil

Le joueur veut deux modes : **à armes nues** (« sans équipement, juste une arme », niveau 1 possible,
c'est celui de la **Ligue**, l'équipement n'y compte pas du tout) et **équipé** (équipement, armes,
certificats, maîtrise). But commun : ni duel interminable ni mort en un coup.

| Champ (profil E1) | Duel à armes nues (Ligue, Panthéon, libre) | Duel équipé (libre, Gantelet) |
|---|---|---|
| Niveau | au choix de 1 à 90 (Ligue : niveau fixé par palier ; Panthéon : 10, celui des cerveaux) | niveau du héros |
| Arme principale | arme de la classe **sans stats d'objet**, variante d'auto-attaque au choix | arme équipée (stats, effets) |
| Arme secondaire | non | oui si équipée |
| Armure, panoplies, joaillerie | non | oui, × `gear_weight` 0,5 (A2) |
| Sorts | preset complet (12) **à tout niveau** : on se bat avec son kit, pas avec son niveau | preset complet |
| Rang des sorts, talents | rang 1, sans talents | rangs et talents du héros |
| Certificats, maîtrise, archive | non | oui, × `gear_weight` |
| Signatures, combos d'états | oui (`combo_mult` 1,5) | oui (1,5) |
| Cartes de run, trophées, améliorations d'arme | non | non |
| Assistance max (PM7) | Assisté | Assisté (Bot en libre) |
| Garde-fou « pas de one-shot » | un coup (crit compris) ne retire jamais plus de **25 % des PV max** ; `PvpCaps` (acharnement, soins ×0,35) inchangés | idem |

Le plafond par coup est une proposition à chiffrer par Équilibrage (`pvp_caps.gd:damage_mult`) ; il
garantit au moins 4 coups pour tuer, même au niveau 1 où les écarts de PV sont grands. Les deux modes
utilisent la **même** identité de build (principe 1) : seules les sources de stats changent.

### 2.5 Panoplie des cerveaux (récompense du Panthéon)

Réponse du joueur : battre un cerveau donne **sa panoplie**, des **coffres d'apparence**, **un titre**
et des **coffres d'auras**. Proposition : **une panoplie par cerveau** (6 pièces : arme de la classe
jouée, tête, torse, jambes, gants, bottes), chacune liée à un geste, sans « +X % » brut :

| Cerveau | Panoplie | 2 pièces | 4 pièces | 6 pièces |
|---|---|---|---|---|
| Débutant | Élève | Fluidité +1 s | +1 palier de Fluidité max | parfait : 10 % de chance de rendre l'esquive |
| Facile | Cadence | enchaînement +10 % | la barre dure +1 s | chaîne complète : recharge de la case −20 % |
| Normal | Esquive | esquive parfaite défensive : +1 palier en plus | invulnérabilité +60 ms | esquive parfaite : prochain sort +30 % |
| Difficile | Ciel | +1 esquive aérienne | sorts en l'air +10 % | Frappe plongeante gratuite après un parfait |
| Hardcore | Signature | finisseur ×1,15 | la marque dure +2 s | finisseur sans retirer la marque, 1 fois / 10 s |
| Expert | Maître | Fluidité : chaque palier +12 % au lieu de +10 % | parfait : recharge −30 % au lieu de −25 % | 4 paliers de Fluidité : sorts enchaînés +20 % ; apparence dorée |

- **Remise** (proposition, chiffres à Progression) : 1re victoire = titre + 2 pièces + 1 coffre
  d'apparence + 1 coffre d'aura ; chaque victoire suivante = 1 pièce jusqu'à 6, puis coffres
  seulement. Pièces achetables ensuite à l'Armurerie (insignes) comme le reste.
- Utilisables en Survie (via l'Armurerie), Tour, Donjons et Duel équipé ; **jamais en Duel à armes
  nues** (Ligue, Panthéon). Ces effets récompensent les gestes manuels : ils ne servent à rien en
  Détente / Bot, ce qui est cohérent avec « battre les cerveaux = défi d'expert ».
- **Touche** : `items.gd` (6 sets), `procs.gd` / `player.gd` (effets), `duel.gd` (remise), session
  locale pour les modèles d'Eden. **Coût M**.

---

## 3. Liste finale des propositions (coût, ordre)

| Ordre | Prop. | Contenu | Coût | Avec |
|---|---|---|---|---|
| 1 | **PM1** | tampon d'entrées (file de 3, plus de « Trop tôt », départ après le dernier coup, péremption 1,2 s) | S-M | Interface (icônes) |
| 1 | **PM3, PM6** | esquive avant l'impact rend la recharge ; hit_stop coupé en Duel ; `auto_combo` coupé en JcJ classé | S | Modes |
| 1 | B1, E7, B5, B10 | (inchangés) cartes sans effet, garde-fous, physique / magique, certificats | S | Équilibrage, Progression |
| 2 | **PM7** | 4 niveaux d'assistance, l'auto sans annulation parfaite, récompenses identiques en JcE | M | Interface, Équilibrage (E6) |
| 2 | **PM2, PM4, PM5** | maintien = chaîne, zones au sol aimantées, anneau d'annonce du parfait | S | Interface |
| 2 | B3, **B14** | arme qui grandit ; facettes d'amélioration de sort | S + S-M | Équilibrage |
| 3 | B2 | 12 axes étiquetés, affinité, évolutions | M | I8, P4, M1a, M3 |
| 4 | **B7 révisée** | esquive parfaite défensive sans ralenti, carte Tissage, Flux, Maître du ciel ; plus de zone dorée | S-M | M1b (épreuve « chaînes tissées »), I8 |
| 4 | B4 | signatures par famille (20) | M | session locale |
| 5 | **Duel 2 modes** | champs du profil (2.4), plafond 25 % des PV par coup | S (données) + chiffres E | Équilibrage, Modes |
| 5 | B8, B11, B6, B12a | (inchangés) | S à M | — |
| 6 | B9 | archétypes sur les panoplies des donjons | M | M2, P5 |
| 6 | **Panthéon** | 6 panoplies de cerveaux (2.5) | M | P8, M4, session locale |
| 6 | Grimoire des cartes, codex des trophées | (inchangés) | S | I6, P4 |
| — | B12b familiers, 3e variante d'arme | reportés | L / M-L | — |

**Logique** : la prise en main passe **en tête** (PM1, PM3, PM6 dans le lot 0-2 de la synthèse) : c'est
ce que le joueur ressent à chaque seconde, ça ne touche ni l'équilibrage ni l'IA, et le journal E6
mesurera aussitôt l'écart manuel / auto avant et après PM7.

**À signaler aux autres équipes** : Interface (I8) retire la zone dorée et le ralenti, ajoute les
icônes de file et le réglage d'assistance ; Modes (M1b) remplace l'épreuve « enchaînements parfaits »
par « chaînes tissées » et interdit les niveaux Détente / Bot en Ligue et au Panthéon ; Équilibrage
chiffre le plafond par coup en duel et compare manuel / auto dans E6 ; Progression fixe la remise des
panoplies de cerveaux. Doc obsolète : l'infobulle de `hud.gd:492` (« 0,45 s de blocage, puis
rappuie ») sera fausse après PM1.

---

## 4. Résumé

1. **Code** : les sorts sont lus sur une seule image ; marteler casse la chaîne (« Trop tôt » < 450 ms), un sort d'une autre case appuyé pendant un sort est perdu (récupération ~1 120 ms), enchaîner tôt coupe les coups restants.
2. **Le fossé** vient du mode auto, qui fait une annulation parfaite à chaque sort (Fluidité +40 %, recharges −25 %) : ≈ ×2 sur les sorts ; il marche même en Duel, et le « hit_stop » est déjà un micro-ralenti global.
3. **PM1 tampon d'entrées** (file de 3, 4e appui ignoré, départ après le dernier coup, péremption 1,2 s, esquive qui vide la file), plus maintien = chaîne, esquive qui rend la recharge, aides de visée : S-M, joueur seulement, aucune observation d'IA touchée.
4. **Position** : l'« easy to play » est le clavier avec le tampon, pas l'auto ; 4 niveaux d'assistance, l'auto ne fait plus d'annulation parfaite, récompenses identiques en JcE, Assisté au plus en JcJ classé.
5. **Mises à jour** : signatures par famille confirmées ; B7 sans ralenti ni zone dorée (carte « Tissage » et épreuve « chaînes tissées ») ; B14 acceptée ; duel à armes nues / équipé avec leurs champs et un plafond de 25 % des PV par coup.
6. **Panthéon** : une panoplie de geste par cerveau (6 pièces, sans « +X % »), plus titre et coffres d'apparence et d'aura ; ordre final : prise en main et garde-fous d'abord, puis assistance et B14, puis axes, gestes, signatures, modes.
