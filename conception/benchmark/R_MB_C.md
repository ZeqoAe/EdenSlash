# R_MB_C : Les Deux Voies, lot MB-C — tours, Cœur, sbires, victoire

Lot MB-C du plan `conception/benchmark/MOBA.md` (§ 7.5, § 9), sur le socle MODE-0 (`R_MODE0.md`) et dans les budgets de l'essai
MB-0 (`R_MB0.md` § 6). La partie se lance et se joue de bout en bout (`world.tscn -- --moba`), avec une IA de héros simple en
attendant le lot MB-E, le niveau des héros = le niveau attendu en attendant l'XP du lot MB-D ; l'activité reste cachée
(« Bientôt ») tant que la boutique, l'IA, le HUD et le bilan ne sont pas faits.

## 1. Livré

| Élément | Fichier | Rôle |
|---|---|---|
| État et règles pures | `game/scripts/core/moba.gd` (`Moba`) | lancement (`launch`, `args_options`), temps, structures détruites, sbires tués, éliminations, vainqueur, journal ; `structure_damage`, `structure_hp`, `tower_streak`, `decide` ; `finish` (TeamMatch.end d'abord, piège 11) |
| Directeur | `game/scripts/core/moba_director.gd` (`MobaDirector`) | carte, structures, réserve de sbires, vagues, grille spatiale de 8 m, cibles des sbires et des tours, appel à l'aide, héros, réapparition, fontaine, fin, mesures (`--moba-trace`, `--moba-perf`) |
| Tours et Cœur | `game/scripts/world/moba_structure.gd` (`MobaStructure`) | hors de « heroes » / « monsters », camp = `ffa_id` de l'équipe ; points ; protections ; réparation par tiers ; tirs ; barre de PV (pomme / fraise), anneau de portée, motif d'équipe ; effondrement |
| Sbires | `game/scripts/ai/moba_minion.gd` (`MobaMinion`) | mode horde (`Monster.lite`), niveau de détail, recyclés, voie dense, coup sans zone rouge, dégâts entre sbires sans chiffres, motif d'équipe sous les pieds |
| Traits | `game/scripts/world/moba_bolt.gd` (`MobaBolt`) | tirs de tour et de tireur, recyclés, maillage partagé, sans lumière |
| Héros scriptés | `game/scripts/ai/moba_rival.gd` (`MobaRival`) | `ClassRival` au kit de partie (`MobaData.kit`, ultime au niveau 5), fiche du niveau de partie, réapparition sans recréer le modèle |
| Branchements | `core/world.gd` (`--moba`), `ui/activities.gd` (« moba », caché) | — |
| Outil | `game/tools/moba_shots.tscn` | captures en partie réelle à des instants de partie |
| Test | `game/tests/test_mb_lanes.tscn` | § 4 |

## 2. Règles codées

- **Camps** : héros, sbires et structures portent le `ffa_id` de leur équipe (TeamMatch, 100 + équipe) : tous les coups du jeu
  (zones rouges, projectiles, auto-attaques) passent par `Combatant.ffa_foes`. Sbires et structures ne sont **pas** membres de
  TeamMatch : `ClassRival._teammates` ne voit que les héros (piège 8 de R_MB0), les barres et le classement aussi. Structures hors
  des groupes « heroes » / « monsters » (piège 7). Aucun `Duel.active` ni `Royale.active`.
- **Cibles** choisies par le directeur (R_MB0 § 4.8), grille refaite à chaque image physique : un **sbire** (toutes les 0,5 s,
  décalées) vise le héros adverse qui vient de frapper un héros allié à 10 m (appel à l'aide, 2 s), sinon le sbire ennemi le plus
  proche, puis une structure, puis un héros ; il garde sa cible tant qu'elle reste à portée de recherche + 4 m. Une **tour** (toutes
  les 0,25 s) vise le héros qui frappe un héros allié à sa portée, sinon garde sa cible, sinon le sbire le plus proche, puis le héros.
- **Tirs de tour** : 10 % des PV max d'un héros (6 % pour le Cœur, 2 tirs / s), × 1,4 par tir de suite sur le même héros (× 2,2 au
  plus, remis à zéro en 5 s) ; sur un sbire, une part des PV d'un sbire **ordinaire** du moment (mêlée 2 tirs, tireur 1, bélier 4) :
  un sbire renforcé tient plus de tirs (sinon un avantage disparaît sous la tour).
- **Structures** en points (100 points = une unité = une auto-attaque du héros de référence au niveau attendu) : T1 11 000, T2 13 000,
  Cœur 19 500. Sans sbire ennemi à 12 m, un tiers des dégâts ; T1 à moitié avant 4:00 ; T2 invulnérable tant que la T1 de sa voie
  tient ; Cœur invulnérable tant que ses deux T2 tiennent (et avant la Marée, lot MB-F). **Réparation hors combat** (nouveau, § 3) :
  après 8 s sans coup, 0,2 unité par seconde jusqu'au haut du tiers de PV en cours.
- **Vagues** toutes les 30 s dès 0:40 (3 mêlées + 2 tireurs, bélier une vague sur 3 puis sur 2 dès 12:00, un géant par vague sur
  une voie dont la T2 adverse est tombée), file **entrelacée** (bleu, rouge, bleu…) et 4 apparitions par image au plus.
- **Victoire** : Cœur détruit ; à 25:00, décision (structures détruites, puis Cœur le moins entamé, puis or, puis sbires tués).
- **Héros** (provisoire) : 4 contre 4, une classe par poste (Brumes = Rempart, jungle = Ombre, tir = Traque ou Arcane, soutien =
  Ferveur), le joueur au poste de sa famille ; IA de voie simple (toutes les 0,4 s : héros adverse proche, sinon sbire, sinon
  structure assiégeable par au moins 2 sbires alliés ; jamais sous une tour adverse sans sbires alliés ; rentre sous 30 % de PV ;
  sinon 4 m derrière le front de sa vague ; le jungler soutient la voie la plus en retard) ; réapparition 7 à 29 s ; fontaine 12 % /
  s ; niveau = niveau attendu (fiche refaite un héros par image) ; ultime au niveau 5.

## 3. Calibrage des voies (vagues seules)

Mesures par parties accélérées dans un processus à part : `Godot --headless --fixed-fps 60 … world.tscn -- --moba --moba-heroes=none
--moba-speed=4 --moba-seed=N [--moba-power=1.2,1.0] [--moba-stop=tower] [--moba-tune=…]` (≈ 40-110 s par partie de 13 à 20 min ;
déterministe à graine égale : même résultat à la seconde près d'une série à l'autre). 6 parties par réglage : 3 avec le camp bleu
× 1,2 (13 min), 3 à vagues égales (20 min). 18 séries.

| Réglage | × 1,2 : 1re tour (3 graines) | Vagues égales, 20 min | Lecture |
|---|---|---|---|
| Valeurs de l'étude | aucune / aucune / aucune ; T1 rouges à 31-77 % | une T1 tombe sur 3 ; T1 à 9-54 % | les deux camps s'usent autant |
| Tours plus lentes sur les sbires | 12:16 / aucune | **T1 tombées à 9:09-9:21** | pire : tout s'use |
| Sbires créés d'abord en bleu (avant correction) | — | **les T1 rouges tombent** | biais d'ordre de traitement (§ 5) |
| Réparation 0,6 | aucune (réparé) | tout à 100 % | la poussée ne tient pas |
| Combats de sbires plus longs | 4:37 / aucune | T1 tombées à 8:19-8:21 | les vagues s'empilent : pire |
| **Combats courts (× 3)**, hasard 0,3, sans réparation | aucune ; T1 rouges à 17-43 % | 67-94 % | séparation enfin nette |
| + siège × 2,1 | 9:42 / 9:54 / 10:21 | 31-87 % | bon, mais les tours s'usent |
| + siège × 3,6 + réparation 0,2 (tours dans l'anneau) | 8:18 / 9:18 / 9:50 | 92-100 % | cible tenue ; miroir 7:46 / 9:49 / 10:41 |
| même réglage, tours sur le bord **extérieur** des voies | 8:51 / 9:12 / 7:13 | 93-100 % | un peu plus rapide |
| siège × 3,2 | 11:15 / 9:42 / 8:15 | 95-100 % | un peu lent |
| **siège × 3,4 (retenu)** | **10:47 / 9:15 / 7:14** ; miroir **9:46 / 11:17 / 9:45** | **94-100 %** | médiane 9:45 |

Ce qu'on a appris : sur une voie seule, des combats de sbires plus longs que l'intervalle des vagues (30 s) font fusionner les vagues
en grosses masses qui écrasent une tour d'un coup, d'un côté puis de l'autre (des vagues égales usent les deux T1 en 15-20 min) ; des
combats courts annulent deux vagues égales avant la suivante, et un avantage s'additionne vague après vague. La réparation par tiers
efface l'usure des sbires égarés sans rendre une poussée tenue inutile. Valeurs retenues (`MobaData`) : dégâts entre sbires × 3
(`MINIONS.*.minion`), coups de siège × 3,4 (`struct`), hasard des sbires 0,3 (`JITTER`), réparation 0,2 unité / s (`REPAIR`, après
`REPAIR_DELAY` 8 s). Les tours sont passées du côté de la jungle au bord extérieur des voies (elles tombaient dans des buissons) :
calibrage refait après ce changement (3 dernières lignes). Écart à l'étude : une vague seule contre une T1 (sans tirs) la vide en
≈ 18 s au lieu de 60 s ; une poussée avec des héros sera remesurée par MB-J (cible de l'étude : 2 héros niveau 6 + une vague en ≈ 20 s).

## 3 bis. Partie complète et coût (budgets R_MB0 § 6)

| Mesure | Valeur | Budget |
|---|---|---|
| Partie à 8 IA (Difficile, graine 21) jusqu'au bout, sans rendu, `--fixed-fps 60` | fin au temps 25:00, 1 tour tombée, 1-1 éliminations (IA de voie provisoire : MB-E) | médiane 17 min visée par MB-J |
| Image entière (scripts + moteur), même partie | p50 **3,7 ms** ; p95 41 ms et max 528 ms **sur une machine à 100 % (72 Godot ouverts)** | logique p95 ≤ 5 ms (machine libre) |
| Temps CPU du processus par image physique, 8 IA (insensible à la charge ; entre 2:00 et 8:00) | **4,07 ms** | ≤ 5 ms ; banc MB-0 `opt` : 3,6 ms |
| Même mesure, vagues seules (sans héros) | **2,11 ms** | — |
| Sbires vivants | moyenne 16, au plus 30 (vagues seules : au plus 32-45) | ≤ 60 |
| Sbires créés pendant la partie | **0** (réserve de 74 créée au chargement, recyclée) | aucun modèle |
| Nœuds de la scène au fil de la partie | 6 900-7 300, stables (aucune fuite) | — |
| Mise en place (carte, 74 sbires, 8 héros) | 1,5-3,4 s, 7,4 s sous charge extrême | écran de chargement |

Les p95 / max mesurés en temps mur sont des bornes hautes sur cette machine saturée (R_MB0 § 3.4 : × 4-5 à charge égale de
travail) ; le temps CPU par image est le chiffre fiable. Le rendu en fenêtre n'a pas été remesuré (MB-J, avec le HUD du mode).

## 4. Tests

`test_mb_lanes` (copie de HEAD + lot) : règles pures (unités, protection, garde des T1, invulnérabilités, tirs de suite, PV du Cœur,
décision au temps) ; partie réelle dans `world.tscn` (vagues seules, × 4) : directeur monté, carte prête, 10 structures hors des
groupes, T2 et Cœur invulnérables, joueur hors de tout camp, réserve préparée, deux vagues, sbire en mode horde du camp de son
équipe et hors de TeamMatch, mêlées et tireurs, fronts qui avancent, plafond tenu, aucune création en partie, combats, niveau de
détail, sortie propre ; puis deux parties accélérées dans un processus à part : **20 min de vagues égales, aucune structure ne
tombe** ; **camp bleu × 1,2 : la T1 rouge tombe à 9:15** (graine 2 ; accepté 7:30-11:00). ≈ 150-230 s selon la charge.

Suite demandée, sur une copie de HEAD 0.1.309 + ce lot (`run_tests.py -j 2`, machine à 100 %) : **test_mb_data, test_mb_map,
test_mb_lanes, test_mode0, test_texts_fr, test_nav_screens, test_pvp, test_duel_modes, test_m7, test_royale : 10 verts sur 10**
(test_mb_lanes repassé après le dernier calibrage). Sur la copie précédente (HEAD 0.1.301 + lot) : test_compass, test_lot10,
test_pages aussi verts (ils lisent `Activities.LIST`, où l'entrée « moba » est cachée). Une première copie de 0.1.308 avait des
rouges « ClassLook non déclaré » : copie incomplète (fichiers de HEAD retirés par l'ancien `run_tests.py`, corrigé par 18efea0b),
sans lien avec ce lot. Partie forcée jusqu'au Cœur (`--moba-power=4,1`, structures à 2 unités) : 4 tours puis le Cœur tombent,
fin et bilan sans erreur.

## 5. Pièges trouvés
1. **Ordre de traitement = ordre des nœuds** : quand deux coups tombent dans la même image physique, le nœud créé le premier frappe le
   premier. Une réserve créée « tous les bleus puis tous les rouges » donnait la victoire des voies au bleu à vagues égales. Création
   et file d'apparition **entrelacées**.
2. Le serveur de navigation synchronise en tâche de fond : `MobaMap.nav_ready()` avant tout chemin (MB-B).
3. `Monster._ready` vise le héros du joueur, `ClassRival._ready` aussi : un sbire ou un héros IA neuf poursuivait son propre équipier
   jusqu'à sa première décision ; `_player = null` à la naissance.
4. Un sbire mis en réserve doit quitter « monsters » et le chacun-pour-soi (`_park`), sinon il reste ciblable et entre dans l'écartement.
5. `Monster.catch_up` (rattrapage de la Survie, × 1,7 de loin) et `Monster.attack_slots` / `lite_height` (horde du Survivant, statiques)
   : neutralisés pour les sbires.
6. Un lambda sur plusieurs lignes dans un appel fait planter le parseur (piège connu) : boucle à la place (`_pick_class`).
7. Sortie d'un processus Godot lue par `OS.execute` sous Windows : accents mal décodés ; le test ne lit que des chiffres et de l'ASCII.

## 6. Pour la suite
- MB-D : XP et or (les sbires gardent `last_hitter`, le directeur `on_minion_down` / `on_hero_down`), niveaux, boutique ;
  `minion_aura` (Étendard, Bannière) ; rappel (« S'extraire »).
- MB-E : remplacer `MobaDirector._think` par `ai/moba_hero_ai.gd` (budget 150 µs par héros).
- MB-F : jungle, Gardien, Colosse, Marée (`TIDE_AT` lu par l'invulnérabilité du Cœur), géant de la Marée (`MobaData.wave(…, giants)`).
- MB-H : HUD du mode (les captures montrent encore le HUD de la Survie : minuteur 10:00, sceaux, mini-carte vide).
- MB-J : remesurer le temps d'une T1 contre 2 héros + une vague, la durée des parties, l'image sur une machine moyenne.
