# R_MB_E : Les Deux Voies, lot MB-E — IA par poste

Lot MB-E du plan `conception/benchmark/MOBA.md` (§ 7.8 couches 1, 2 et 4 ; § 9), sur le lot MB-D (héros en partie, boutique)
et la jungle du lot MB-F (équipe MB-3, 0.1.320 : `MobaJungle`).
Recommandations par défaut de l'étude : validées. Le coach d'équipe (vue honnête à 25 m, carte d'influence, plans, objectifs,
repères → ordres) est le lot MB-G. Le mode reste caché (« Bientôt »).

## 1. Livré

| Élément | Fichier | Rôle |
|---|---|---|
| IA de poste | `game/scripts/ai/moba_hero_ai.gd` (`MobaHeroAi`, nouveau) | une par héros scripté (`MobaHero.ai`) ; décision posée sur le `MobaRival` (cible, but, zones interdites, plongée), rappel, potions, achats ; trace `--moba-trace-ai[=s]` |
| Héros scripté | `game/scripts/ai/moba_rival.gd` | `guard` : la course n'entre jamais dans une zone interdite (bord longé, sortie si dedans) ; coup annulé sans cible (rappel pendant un coup) |
| Directeur | `game/scripts/core/moba_director.gd` | `_think_all` → `MobaHeroAi.think` (l'IA de voie provisoire de MB-C est retirée) ; rappel de la Bannière (`MobaJungle.recall_time`, lu sans dépendance) ; causes de mort en ASCII ; Rejouer / Menu principal par `LoadScreen` (lot PERF-1) ; essai de profil `--moba-tune=dmg_scale:x` ; sonde du 1 contre 1 |
| Sonde | `game/tools/moba_duel_probe.gd` | `--moba-duel=<niveau> [--moba-duel-items=N]` : les 4 paires bleu / rouge se battent loin des voies |
| Profil de combat | `game/scripts/core/moba_data.gd` | échelle des dégâts entre héros 0,09 → **0,3** (§ 3) ; `test_mb_data` suit |
| Flaques | `game/scripts/combat/hazard.gd` (1 ligne : groupe « hazards ») | § 3 bis |
| Économie | directeur : `Moba.team_gold` tenu chaque seconde (décision aux points du lot MB-F) | — |
| Test | `game/tests/test_mb_ai_role.tscn` | § 5 |

## 2. Ce que fait l'IA

Couche 1 (micro, existante) : `ClassRival` (lecture des zones de tous les héros adverses en équipe, esquives, sorts, soins et
renforts, repli). Couche 2 (poste, ce lot), une décision toutes les 0,5 / 0,35 / 0,25 / 0,2 s (Facile → Hardcore) :

- **Tours** : zone interdite = portée + 1,8 m de chaque tour ou Cœur adverse debout, sauf si elle vise un sbire allié et qu'au
  moins 2 sbires alliés sont sous elle ; toujours interdite si elle le vise lui. La course est déviée au bord (`MobaRival.guard`),
  une cible dans une zone est abandonnée. **Une tour qui le vise : il sort de sa portée avant toute autre chose**, du côté de sa
  base. Jamais de rappel sous une tour ni moins de 1,5 s après un coup. Plongée sûre (Difficile seulement) : cible sous 22 % de
  PV, lui au-dessus de 60 %, la tour ne le vise pas, aucun autre héros adverse à côté. Erreurs de position (poursuite sous la tour
  pendant 2 s) : 30 / 12 / 4 / 0 % des occasions.
- **Sbires** : il ne frappe pas un héros au milieu de sa vague (3 sbires ou plus, plus que les siens) sauf s'il frappe déjà un
  allié ; entamé (< 50 %) et pris pour cible par 3 sbires, il recule derrière les siens.
- **Échanges** : rapport de force = Σ PV × attaque des alliés à 16 m contre celui des adversaires (× 1,5 au camp qui a sa tour à
  côté) ; il engage au-dessus de 1,1, à force égale (≥ 0,9) s'il a au moins autant de PV, achève une cible sous 25 %, recule vers
  sa tour sous 0,8.
- **Retour** : potion sous 45 % ; sous 30 % (35 % en Hardcore, 25 % en Facile) : rappel si aucun héros adverse à 12 m (à pied
  près de la base), sinon recul vers sa tour ; à la fontaine il repart à 95 % de PV. Retour d'achat dès 4:00 si l'or paie l'objet
  suivant + 300, la voie calme et sa vague pas en recul ; Facile en oublie un sur trois.
- **Postes** : *voie* (Brumes, tir) : 4 m derrière le front de sa vague, achève le sbire le plus faible à portée, frappe une tour
  occupée par 2 sbires alliés (PV ≥ 50 %) ; *soutien* : suit son tireur, se place entre lui et la menace la plus proche (sinon
  derrière lui), laisse les sbires au tireur ; *jungle* : petits camps de sa moitié d'abord (ils reviennent avant 4:00), puis les
  deux à bonus, puis le camp qui sera prêt le premier ; **pas de vol de camps avant 4:00** (après : seulement si sa moitié n'a rien
  sous 45 s et sans héros adverse à 20 m) ; attente longue (> 25 s) : il aide la voie la plus en retard et revient à temps ; un
  camp qui ne baisse plus en 12 s (inaccessible, remis à zéro) ou un monstre qu'il n'approche plus en 2,5 s est laissé ;
  embuscade : un héros adverse de son côté de la voie sous 60 % de PV à 55 m (avant 4:00 : sous 35 % à 28 m).

Couche 4 (économie) : parcours de sa famille (`MobaItems.route`, adapté à l'équipe adverse dès Difficile, fixe en Facile et
Normal), acheté entier à chaque passage à la base, 1 à 2 potions de soin gardées ; Hardcore vend ses bottes à 20:00 pour un objet
de plus. Couche 3 (coach) : lot MB-G.

## 3. Échelle des dégâts entre héros (sonde du 1 contre 1)

`--moba-duel=<niveau>` (4 paires, mêmes graines), temps jusqu'à la première chute :

| Échelle | Difficile niv. 1 / 6 / 12 | Hardcore niv. 1 / 6 / 12 |
|---|---|---|
| 0,09 (MB-A) | 70-94 s, 1 paire > 120 s / 59-74 s, 1 > 120 / 56-94 s | 25 s, 3 > 120 / 4 > 120 / 4 > 120 |
| **0,3 (retenu)** | 18-38 s / 10-44 s / 17-37 s | 32-119 s, 1 > 120 / 26-32 s, 2 > 120 / 25-81 s, 1 > 120 |
| 0,5 | 23-33 s / 19-27 s / 10-22 s | 24-87 s / 25-69 s, 1 > 120 / 31-62 s |

À 0,09 personne ne mourait (aucune élimination en 10 min sur 3 parties Hardcore). Au-delà de 0,3 le gain est faible : les
plafonds du profil (coup ≤ 22 %, rafale ≤ 50 % sur 2 s) et les esquives du Hardcore (lecture 95 %) bornent le reste. La cible
de l'étude (10-16 s) n'est pas atteinte en 1 contre 1 pur : en partie, les éliminations viennent des combats à plusieurs, des
tours et des sbires. Recalibrage complet : lot MB-J.

## 3 bis. Flaques au sol (retour du lot MB-F : le Colosse balayait l'équipe)

Les zones persistantes des boss (`Hazard` : lave, poison, givre…) entrent dans un groupe « hazards » (une ligne :
`add_to_group` dans `Hazard._ready`) ; `MobaRival` les relève 4 fois par seconde à 15 m : sa course ne les traverse jamais (même en
plongée) et, dedans, il en sort d'une esquive (chance = sa lecture des coups, 95 % en Hardcore) ou en courant. Vaut aussi pour la
sonde des objectifs du lot MB-F (elle pilote des `MobaRival`). Mesure du Colosse avec l'IA de poste et le coach : lot MB-G / MB-J.

## 4. Mesures (copie de HEAD 0.1.318 + ce lot + la jungle du lot MB-F en cours, 8 IA Hardcore, × 4)

`python tools/moba_ai_games.py --projet <copie> -n 20 -j 3 --diff 3 --until 1500 --perf`, parties complètes (fin au Cœur ou à 25:00).

| Mesure (20 parties, graines 500-519) | Valeur | Cible |
|---|---|---|
| Morts de héros | 38 (2 éliminations par partie en médiane, 0 à 5) | — |
| **Morts sous une tour adverse** | **0** | 0 (Hardcore) |
| **Morts sans héros adverse dans les 10 s** (tour, sbires seuls) | **0** | 0 |
| Jungler : camps avant 4:00 | 6 pour 38 junglers sur 40 ; 5 pour 2 (jungle envahie par deux héros adverses à 3:30) | ≥ 6 |
| Fin des parties | 17 à 25:00, 3 au Cœur ; 3 structures détruites en médiane ; niveau 12 et ≈ 7 700 or gagnés par héros | médiane 17 min (MB-J) |
| Temps CPU du processus par image physique | médiane **4,42 ms** (4,12-4,62) | logique ≤ 5 ms |
| Scripts de l'image physique, p95 (temps mur, machine chargée) | 2,88 ms (médiane des parties) | ≤ 5 ms p95 |
| Héros IA, temps mur par image | MobaRival entier 131 µs (max 180), **dont couche de poste 18 µs** (max 23) ; une décision : 60 µs | ≤ 150 µs |

Séries précédentes (même banc) : graines 300-319, avant les corrections de recul (sans menace en vue) et de vague : 70 morts, 0 sous
une tour, 1 sans héros (tireur achevé par une vague) ; graines 400-419, avant les règles « près d'une tour adverse » : 52 morts,
**1 sous une tour** (un tireur qui assiégeait une T1 occupée a continué à se battre sous elle à deux contre un : il passe de 61 à
3 % de PV en 2 s) ; d'où : siège interdit dès qu'un héros adverse défend, combat près d'une tour adverse seulement à 1,5 contre 1
ou mieux, et recul hors de la zone quand des héros adverses arrivent.

Avant les deux dernières corrections (recul sans héros adverse en vue, vague qui le cible), une première série de 20 parties
(graines 300-319) : 70 morts, **0 sous une tour adverse**, 1 sans héros adverse (un tireur achevé par une vague à 4:08 : corrigé),
jungle 6 camps avant 4:00 pour les 40 junglers, 4,46 ms CPU par image.

Jungle (avant les réglages de route, 12 parties jusqu'à 4:10) : 21 junglers sur 24 à 6 camps ; causes trouvées : embuscades
avant la fin du premier tour de camps, camps volés, camp inaccessible, attente d'un camp mal choisie ; après réglages : 32 sur 32.

## 5. Tests

- `test_mb_ai_role` (nouveau) : partie réelle Hardcore × 4 : une IA de poste par héros, zones interdites = tours adverses debout,
  aucun héros dans la portée d'une tour inoccupée, le soutien suit son tireur, le jungler joue la jungle (ou une voie sans jungle),
  achats au départ, **coût d'une décision de poste 60 µs** (≤ 150) ; puis 5 parties dans des processus à part (4 jusqu'à 4:10, une
  jusqu'à 10:00) : jungler ≥ 6 camps avant 4:00 à chaque fois (vérifié quand la jungle du lot MB-F est là), aucune mort sous une tour
  adverse ni sans héros adverse. Vert sur la copie avec la jungle (≈ 6 min).
- Suite demandée : voir § 6.

Copie de HEAD 0.1.320 + ce lot, `run_tests.py -j 2` : test_mb_data, test_mb_map, test_mb_lanes, test_mb_hero, test_mb_shop,
**test_mb_ai_role**, test_mb_objectives, test_mode0, test_pvp, test_duel_modes, test_m7, test_royale, test_texts_fr, test_perf1 :
**14 verts** (test_perf1 rouge une fois sur une image de 307 ms au changement de carte de l'Aventure, sans lien avec ce lot : vert
relancé seul). `tools/check_scripts.py` vert sur l'arbre du commit.

## 6. Pièges
1. `ClassRival` ne suit son but qu'avec une cible : un recul « sans menace en vue » laissait le héros planté sous les sbires
   (mort sans raison) ; la cible de regard par défaut est le Cœur adverse.
2. Le rappel posait la cible à `null` pendant un coup : `ClassRival._cancel_after_hit` plantait (accès à `_player`).
3. Un héros qui frappe une tour peut perdre ses sbires en un instant : la tour le vise et ses tirs de suite montent à × 2,2 ;
   d'où la sortie de portée prioritaire, et pas de siège sous 50 % de PV.
4. La sortie d'un processus lue par `OS.execute` sous Windows abîme les accents : causes de mort en ASCII dans `[moba] bilan`.
5. Deux équipes dans `moba_director.gd` : chaque envoi reconstruit sa version depuis HEAD (retraits des blocs de l'autre lot) ;
   l'IA lit la jungle sans référence statique (`get("jungle")`, `camps`, `recall_time`).

## 7. Pour la suite
- MB-G : coach (vue honnête, carte d'influence, plans GROUPER / POUSSER / DÉFENDRE, objectifs préparés 20-60 s avant, repères →
  ordres) au-dessus de `MobaHeroAi` (son `mode`, ses cibles et ses buts sont les points d'entrée).
- MB-J : durée des parties (ici la plupart vont à 25:00), or et éliminations, équilibre des postes et des familles, recalibrage
  de l'échelle des dégâts ; certaines classes nettoient lentement la jungle (Danseuse élégante, Samouraï).
- Pilote automatique du joueur (`Player.autoplay`) : encore l'IA simple de voie du lot MB-C.
